import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  DateTime? _fromDate;
  DateTime? _toDate;

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
      // Date range filter (from = start of day, to = end of day)
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

              // ── Incident List ────────────────────────────────────────
              _incidentList(filtered),
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
            color: Colors.black.withValues(alpha: 0.06),
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
                  'All Incidents (${docs.length})',
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
            ...docs.asMap().entries.map((entry) {
              final idx = entry.key;
              final doc = entry.value;
              final data = doc.data() as Map<String, dynamic>;
              return _incidentTile(data, idx, docs.length);
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
}
