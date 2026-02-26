import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:kitahack/services/ai_service.dart';

class IncidentDashboardScreen extends StatefulWidget {
  const IncidentDashboardScreen({super.key});

  @override
  State<IncidentDashboardScreen> createState() =>
      _IncidentDashboardScreenState();
}

class _IncidentDashboardScreenState extends State<IncidentDashboardScreen> {
  String _severityFilter = 'All';
  String _typeFilter = 'All';
  String _statusFilter = 'All';
  String _timeFilter = 'All Time'; // New state
  DateTime? _fromDate;
  DateTime? _toDate;

  final AiService _aiService = AiService();
  Map<String, dynamic>? _aiInsightData;
  bool _isSummarizing = false;
  bool _isReloading = false; // New state
  List<Map<String, dynamic>> _lastAnalyzedIncidents = [];

  // ─── Helpers ────────────────────────────────────────────────────────────────

  String _severityLabel(int s) {
    if (s >= 9) return 'Critical';
    if (s >= 7) return 'High';
    if (s >= 4) return 'Medium';
    return 'Low';
  }

  Color _severityColor(String label) {
    switch (label) {
      case 'Critical':
        return const Color(0xFFB71C1C);
      case 'High':
        return const Color(0xFF212121);
      case 'Medium':
        return const Color(0xFF7B5E00);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  String _checkInLabel(String checkIn) {
    switch (checkIn) {
      case 'need_assistance':
        return 'Need Help';
      case 'trapped':
        return 'Trapped';
      default:
        return 'Safe';
    }
  }

  Color _checkInColor(String checkIn) {
    switch (checkIn) {
      case 'trapped':
        return const Color(0xFFE53935);
      case 'need_assistance':
        return const Color(0xFFF57C00);
      default:
        return const Color(0xFF43A047);
    }
  }

  List<QueryDocumentSnapshot> _applyFilters(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final severity = (data['severity'] as int?) ?? 0;
      final category = (data['category'] as String?) ?? '';
      final checkIn = (data['checkIn'] as String?) ?? 'safe';
      final ts = (data['timestamp'] as Timestamp?)?.toDate();

      if (_severityFilter != 'All' &&
          _severityLabel(severity) != _severityFilter) {
        return false;
      }
      if (_typeFilter != 'All' &&
          !category.toLowerCase().contains(_typeFilter.toLowerCase())) {
        return false;
      }
      if (_statusFilter != 'All' && _checkInLabel(checkIn) != _statusFilter) {
        return false;
      }
      // Date range filter
      if (_fromDate != null && ts != null && ts.isBefore(_fromDate!)) {
        return false;
      }
      if (_toDate != null && ts != null) {
        final endOfDay = DateTime(
          _toDate!.year,
          _toDate!.month,
          _toDate!.day,
          23,
          59,
          59,
        );
        if (ts.isAfter(endOfDay)) return false;
      }

      // Time period filter
      if (_timeFilter != 'All Time' && ts != null) {
        final now = DateTime.now();
        if (_timeFilter == '30 Mins' &&
            ts.isBefore(now.subtract(const Duration(minutes: 30)))) {
          return false;
        }
        if (_timeFilter == '1 Hour' &&
            ts.isBefore(now.subtract(const Duration(hours: 1)))) {
          return false;
        }
        if (_timeFilter == '1 Day' &&
            ts.isBefore(now.subtract(const Duration(days: 1)))) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Future<void> _pickDate({
    required bool isFrom,
    required DateTime? current,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: isFrom ? 'Select From Date' : 'Select To Date',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: Color(0xFF1565C0),
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _fromDate = picked;
          // If new from > to, clear to
          if (_toDate != null && picked.isAfter(_toDate!)) {
            _toDate = null;
          }
        } else {
          _toDate = picked;
          // If new to < from, clear from
          if (_fromDate != null && picked.isBefore(_fromDate!)) {
            _fromDate = null;
          }
        }
      });
    }
  }

  Future<void> _generateAiSummary(List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) {
      setState(
        () => _aiInsightData = {
          "summary": "No incidents to analyze.",
          "groups": [],
        },
      );
      return;
    }

    final incidents = docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();

    // Simple check to avoid redundant calls if data hasn't changed much
    if (_aiInsightData != null &&
        incidents.length == _lastAnalyzedIncidents.length) {
      // Potentially skip if count is same
    }

    setState(() {
      _isSummarizing = true;
    });

    final insightData = await _aiService.summarizeIncidents(incidents);

    setState(() {
      _aiInsightData = insightData;
      _isSummarizing = false;
      _lastAnalyzedIncidents = incidents;
    });
  }

  Future<void> _reloadDisasters() async {
    setState(() => _isReloading = true);
    try {
      final result = await FirebaseFunctions.instanceFor(
        region: 'us-central1',
      ).httpsCallable('reaggregateDisasters').call();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Activity refreshed via AI!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('❌ Reload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isReloading = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Incident Dashboard',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            Text(
              'Real-time monitoring of all reported incidents',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('reported_cases')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final allDocs = snapshot.data?.docs ?? [];

          // Sort in-code: severity desc, then timestamp desc (avoids composite index)
          allDocs.sort((a, b) {
            final da = a.data() as Map<String, dynamic>;
            final db = b.data() as Map<String, dynamic>;
            final sa = (da['severity'] as int?) ?? 0;
            final sb = (db['severity'] as int?) ?? 0;
            if (sb != sa) return sb.compareTo(sa);
            final ta =
                (da['timestamp'] as Timestamp?)?.toDate() ?? DateTime(2000);
            final tb =
                (db['timestamp'] as Timestamp?)?.toDate() ?? DateTime(2000);
            return tb.compareTo(ta);
          });

          final filtered = _applyFilters(allDocs);

          // Summary stats
          final total = allDocs.length;
          final critical = allDocs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return ((data['severity'] as int?) ?? 0) >= 9;
          }).length;
          final trapped = allDocs.where((d) {
            final data = d.data() as Map<String, dynamic>;
            return (data['checkIn'] as String?) == 'trapped';
          }).length;
          final affected = allDocs.fold<int>(0, (acc, d) {
            final data = d.data() as Map<String, dynamic>;
            return acc + ((data['peopleAffected'] as int?) ?? 0);
          });

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ── Summary Grid ─────────────────────────────────────────
              _summaryGrid(total, critical, trapped, affected),
              const SizedBox(height: 14),

              // ── Filter Card ──────────────────────────────────────────
              _filterCard(),
              const SizedBox(height: 14),

              // ── AI Summary Section ──────────────────────────────────────────
              _aiSummarySection(filtered),
              const SizedBox(height: 14),

              // ── Incident List ────────────────────────────────────────
              _incidentList(filtered),

              const SizedBox(height: 14),

              // ── Recent Activity (Last 2 Days) ────────────────────────
              _recentActivityCard(),

              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  // ─── Summary Grid ────────────────────────────────────────────────────────

  Widget _summaryGrid(int total, int critical, int trapped, int affected) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.65,
      children: [
        _statCard(
          label: 'Total Incidents',
          value: '$total',
          sub: 'Active reports',
          icon: Icons.article_outlined,
          iconColor: Colors.blueGrey.shade600,
          valueColor: Colors.black87,
        ),
        _statCard(
          label: 'Critical Cases',
          value: '$critical',
          sub: 'Immediate attention',
          icon: Icons.warning_amber_rounded,
          iconColor: const Color(0xFFE53935),
          valueColor: const Color(0xFFE53935),
          bgColor: const Color(0xFFFFF5F5),
        ),
        _statCard(
          label: 'People Trapped',
          value: '$trapped',
          sub: 'Rescue needed',
          icon: Icons.person_off_outlined,
          iconColor: const Color(0xFFF57C00),
          valueColor: const Color(0xFFF57C00),
          bgColor: const Color(0xFFFFF8F0),
        ),
        _statCard(
          label: 'People Affected',
          value: '$affected',
          sub: 'Across all incidents',
          icon: Icons.people_outline,
          iconColor: const Color(0xFF1565C0),
          valueColor: const Color(0xFF1565C0),
          bgColor: const Color(0xFFEDF4FF),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required String sub,
    required IconData icon,
    required Color iconColor,
    required Color valueColor,
    Color bgColor = Colors.white,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: valueColor,
              height: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  // ─── Filter Card ─────────────────────────────────────────────────────────

  Widget _filterCard() {
    final hasActive =
        _severityFilter != 'All' ||
        _typeFilter != 'All' ||
        _statusFilter != 'All' ||
        _timeFilter != 'All Time' ||
        _fromDate != null ||
        _toDate != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.filter_list, size: 15, color: Colors.grey.shade700),
              const SizedBox(width: 6),
              const Text(
                'Filter Incidents',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const Spacer(),
              if (hasActive)
                GestureDetector(
                  onTap: () => setState(() {
                    _severityFilter = 'All';
                    _typeFilter = 'All';
                    _statusFilter = 'All';
                    _timeFilter = 'All Time';
                    _fromDate = null;
                    _toDate = null;
                  }),
                  child: const Text(
                    'Clear Filters',
                    style: TextStyle(
                      color: Color(0xFF1565C0),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _dropdown(
                  label: 'Severity',
                  value: _severityFilter,
                  items: ['All', 'Critical', 'High', 'Medium', 'Low'],
                  onChanged: (val) => setState(() => _severityFilter = val!),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _dropdown(
                  label: 'Type',
                  value: _typeFilter,
                  items: [
                    'All',
                    'Flood',
                    'Fire',
                    'Storm',
                    'Earthquake',
                    'Tsunami',
                  ],
                  onChanged: (val) => setState(() => _typeFilter = val!),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _dropdown(
                  label: 'Status',
                  value: _statusFilter,
                  items: ['All', 'Safe', 'Need Help', 'Trapped'],
                  onChanged: (val) => setState(() => _statusFilter = val!),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _dropdown(
                  label: 'Time',
                  value: _timeFilter,
                  items: ['All Time', '30 Mins', '1 Hour', '1 Day'],
                  onChanged: (val) => setState(() => _timeFilter = val!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Date range ────────────────────────────────────────────────
          Text(
            'Date Range',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _dateTile(
                  label: _fromDate == null
                      ? 'From'
                      : '${_fromDate!.day}/${_fromDate!.month}/${_fromDate!.year}',
                  icon: Icons.calendar_today_outlined,
                  active: _fromDate != null,
                  onTap: () => _pickDate(isFrom: true, current: _fromDate),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  '→',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 16),
                ),
              ),
              Expanded(
                child: _dateTile(
                  label: _toDate == null
                      ? 'To'
                      : '${_toDate!.day}/${_toDate!.month}/${_toDate!.year}',
                  icon: Icons.calendar_today_outlined,
                  active: _toDate != null,
                  onTap: () => _pickDate(isFrom: false, current: _toDate),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade500,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            border: Border.all(color: Colors.grey.shade200),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              items: items
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateTile({
    required String label,
    required IconData icon,
    required bool active,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active
              ? const Color(0xFF1565C0).withValues(alpha: 0.08)
              : const Color(0xFFF7F8FA),
          border: Border.all(
            color: active
                ? const Color(0xFF1565C0).withValues(alpha: 0.4)
                : Colors.grey.shade200,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 14,
              color: active ? const Color(0xFF1565C0) : Colors.grey.shade400,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.w600 : FontWeight.normal,
                  color: active
                      ? const Color(0xFF1565C0)
                      : Colors.grey.shade500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Incident List ────────────────────────────────────────────────────────

  Widget _incidentList(List<QueryDocumentSnapshot> docs) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  docs.length > 20
                      ? 'All Incidents (Showing top 20 of ${docs.length})'
                      : 'All Incidents (${docs.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                Text(
                  'Sorted by severity, most critical first',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Rows
          if (docs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(36),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.inbox_outlined,
                      size: 40,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No incidents match your filters',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            )
          else
            ...docs.take(20).toList().asMap().entries.map((entry) {
              final idx = entry.key;
              final doc = entry.value;
              final data = doc.data() as Map<String, dynamic>;
              return _incidentTile(
                data,
                idx,
                docs.length > 20 ? 20 : docs.length,
              );
            }),
        ],
      ),
    );
  }

  Widget _incidentTile(Map<String, dynamic> data, int idx, int total) {
    final caseId = (data['caseId'] as String?) ?? '';
    final shortId = caseId.length >= 6
        ? 'INC-${caseId.substring(0, 6).toUpperCase()}'
        : 'INC-???';
    final category = (data['category'] as String?) ?? 'unknown';
    final severity = (data['severity'] as int?) ?? 0;
    final checkIn = (data['checkIn'] as String?) ?? 'safe';
    final areaId = (data['areaId'] as String?) ?? 'Unknown';
    final affected = (data['peopleAffected'] as int?) ?? 0;
    final timestamp = data['timestamp'] as Timestamp?;

    final sevLabel = _severityLabel(severity);
    final sevColor = _severityColor(sevLabel);
    final statusLabel = _checkInLabel(checkIn);
    final statusColor = _checkInColor(checkIn);
    final timeAgo = timestamp != null ? _timeAgo(timestamp.toDate()) : '—';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Row 1: ID · Type · Severity badge
              Row(
                children: [
                  Text(
                    shortId,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey.shade500,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    _categoryIcon(category),
                    size: 13,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _capitalize(category),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  _badge(sevLabel, sevColor, filled: true),
                ],
              ),
              const SizedBox(height: 7),

              // Row 2: Location · People affected
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 12,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      areaId,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    Icons.people_outline,
                    size: 12,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    '$affected',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              const SizedBox(height: 7),

              // Row 3: Status badge · Time
              Row(
                children: [
                  _badge(statusLabel, statusColor, filled: false),
                  const Spacer(),
                  Icon(
                    Icons.access_time_outlined,
                    size: 11,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    timeAgo,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (idx < total - 1)
          const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }

  // ─── Small helpers ────────────────────────────────────────────────────────

  Widget _badge(String label, Color color, {required bool filled}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? color : color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: filled ? Colors.white : color,
        ),
      ),
    );
  }

  IconData _categoryIcon(String cat) {
    switch (cat.toLowerCase()) {
      case 'flood':
        return Icons.water;
      case 'fire':
        return Icons.local_fire_department;
      case 'storm':
        return Icons.thunderstorm;
      case 'earthquake':
        return Icons.crisis_alert;
      case 'tsunami':
        return Icons.waves;
      default:
        return Icons.warning_amber;
    }
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 30) return '${diff.inDays}d ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  Widget _aiSummarySection(List<QueryDocumentSnapshot> filteredDocs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome, size: 18, color: Color(0xFF1565C0)),
            const SizedBox(width: 8),
            const Text(
              'Recent Activities (AI Summary)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const Spacer(),
            if (_isSummarizing)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              IconButton(
                icon: const Icon(
                  Icons.refresh,
                  size: 18,
                  color: Color(0xFF1565C0),
                ),
                onPressed: () => _generateAiSummary(filteredDocs),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_aiInsightData == null && !_isSummarizing)
          _generateEmptyState(filteredDocs)
        else if (_aiInsightData != null)
          _buildInsightContent()
        else if (_isSummarizing)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text(
                'AI is analyzing data and grouping cases...',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ),
      ],
    );
  }

  Widget _generateEmptyState(List<QueryDocumentSnapshot> filteredDocs) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          const Icon(Icons.insights, size: 40, color: Color(0xFFBBDEFB)),
          const SizedBox(height: 12),
          const Text(
            'Ready to analyze the dashboard data',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Group related incidents and spot trends automatically.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => _generateAiSummary(filteredDocs),
            icon: const Icon(Icons.auto_awesome, size: 16),
            label: const Text('Generate AI Insights'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightContent() {
    final String summary = _aiInsightData?['summary'] ?? '';
    final List groups = _aiInsightData?['groups'] ?? [];
    final String trends = _aiInsightData?['disasterTrends'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Summary Card
        _insightCard(
          title: 'Overall Summary',
          content: summary,
          icon: Icons.summarize_outlined,
          color: const Color(0xFF1565C0),
        ),
        const SizedBox(height: 12),

        // Group Cards
        if (groups.isNotEmpty) ...[
          const Text(
            'Area-Specific Insights',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          ...groups.map((g) {
            final String area = g['area'] ?? 'Unknown';
            final int count = g['incidentCount'] ?? 0;
            final int affected = g['totalAffected'] ?? 0;
            final String sev = g['collectiveSeverity'] ?? 'Unknown';
            final String analysis = g['analysis'] ?? '';
            final String similarity = g['similarCasesTracked'] ?? '';

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _areaInsightCard(
                area: area,
                count: count,
                affected: affected,
                severity: sev,
                analysis: analysis,
                similarity: similarity,
              ),
            );
          }),
        ],

        // Trends Card
        if (trends.isNotEmpty)
          _insightCard(
            title: 'Disaster Trends & Analysis',
            content: trends,
            icon: Icons.trending_up,
            color: const Color(0xFF2E7D32),
          ),
      ],
    );
  }

  Widget _insightCard({
    required String title,
    required String content,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: Colors.black87,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _areaInsightCard({
    required String area,
    required int count,
    required int affected,
    required String severity,
    required String analysis,
    required String similarity,
  }) {
    Color sevColor;
    switch (severity.toLowerCase()) {
      case 'critical':
      case 'high':
        sevColor = const Color(0xFFE53935);
        break;
      case 'medium':
        sevColor = const Color(0xFFF57C00);
        break;
      default:
        sevColor = const Color(0xFF43A047);
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    area,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                _badge(severity, sevColor, filled: true),
              ],
            ),
          ),
          // Stats Row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                _miniStat(Icons.article_outlined, '$count Cases'),
                const SizedBox(width: 16),
                _miniStat(Icons.people_outline, '$affected Affected'),
              ],
            ),
          ),
          const Divider(height: 1),
          // Analysis
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SITUATION ANALYSIS',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  analysis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                    height: 1.4,
                  ),
                ),
                if (similarity.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  const Text(
                    'SIMILARITY TRENDS',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    similarity,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recentActivityCard() {
    final oneDayAgo = DateTime.now().subtract(const Duration(days: 1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              const Icon(Icons.show_chart, size: 20, color: Colors.black87),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Recent Activity',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      'Latest updates and incident reports',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (_isReloading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20, color: Colors.blue),
                  onPressed: _reloadDisasters,
                  tooltip: "Re-run AI Grouping",
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('disasters')
              .where(
                'updatedAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(oneDayAgo),
              )
              .orderBy('updatedAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final allRecentDocs = snapshot.data?.docs ?? [];
            final docs = allRecentDocs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final cases = data['caseCount'] ?? 0;
              return cases > 5;
            }).toList();

            if (docs.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    'No active disasters with >5 cases in the last 24h.',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                ),
              );
            }

            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docs.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final data = docs[index].data() as Map<String, dynamic>;
                  return _recentActivityTile(data);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _recentActivityTile(Map<String, dynamic> data) {
    final type = (data['type'] as String?)?.toUpperCase() ?? 'OTHER';
    final severity = (data['severity'] as String?)?.toLowerCase() ?? 'low';
    final title = data['title'] ?? 'Generic Incident';
    final desc = data['description'] ?? '';
    final location = data['locationLabel'] ?? 'Unknown Area';
    final affected = data['affectedCount'] ?? 0;
    final ts = data['updatedAt'] as Timestamp?;
    final timeAgo = ts != null ? _timeAgo(ts.toDate()) : '—';

    IconData icon;
    Color iconColor;
    Color iconBg;

    switch (type) {
      case 'FLOOD':
        icon = Icons.tsunami_outlined;
        iconColor = Colors.blue.shade700;
        iconBg = Colors.blue.shade50;
        break;
      case 'FIRE':
        icon = Icons.local_fire_department_outlined;
        iconColor = Colors.red.shade700;
        iconBg = Colors.red.shade50;
        break;
      case 'EARTHQUAKE':
        icon = Icons.vibration_outlined;
        iconColor = Colors.brown.shade700;
        iconBg = Colors.brown.shade50;
        break;
      default:
        icon = Icons.warning_amber_outlined;
        iconColor = Colors.orange.shade700;
        iconBg = Colors.orange.shade50;
    }

    Color sevColor;
    switch (severity) {
      case 'critical':
        sevColor = const Color(0xFFB71C1C);
        break;
      case 'high':
        sevColor = const Color(0xFF212121);
        break;
      default:
        sevColor = const Color(0xFF78909C);
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: sevColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            severity,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _activityMeta(Icons.location_on_outlined, location),
                        const SizedBox(width: 12),
                        _activityMeta(
                          Icons.people_outline,
                          '$affected affected',
                        ),
                        const SizedBox(width: 12),
                        _activityMeta(Icons.access_time, timeAgo),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _activityMeta(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 13, color: Colors.grey.shade400),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
        ),
      ],
    );
  }

  Widget _miniStat(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}
