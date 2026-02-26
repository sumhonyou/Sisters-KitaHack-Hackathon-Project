import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kitahack/services/ai_service.dart';
import 'package:intl/intl.dart';

class CasesPage extends StatefulWidget {
  const CasesPage({super.key});

  @override
  State<CasesPage> createState() => _CasesPageState();
}

class _CasesPageState extends State<CasesPage> {
  final AiService _aiService = AiService();
  Map<String, dynamic>? _aiInsightData;
  bool _isSummarizing = false;
  List<Map<String, dynamic>> _lastAnalyzedIncidents = [];
  final Map<String, String> _areaNames = {};

  // Filter states
  String _selectedSeverity = 'All';
  String _selectedType = 'All';
  String _selectedStatus = 'All';
  String _selectedTime = 'All Time';
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _loadAreaNames();
  }

  Future<void> _loadAreaNames() async {
    final snapshot = await FirebaseFirestore.instance.collection('Areas').get();
    for (var doc in snapshot.docs) {
      final name = doc.data()['name'] as String?;
      if (name != null) {
        setState(() {
          _areaNames[doc.id] = name;
        });
      }
    }
  }

  String _getAreaName(String areaId) {
    return _areaNames[areaId] ?? areaId;
  }

  Future<void> _syncDisastersToFirestore(List<dynamic> groups) async {
    final db = FirebaseFirestore.instance;
    for (var group in groups) {
      final disasterId = group['disasterId'] as String?;
      if (disasterId == null) continue;

      final docRef = db.collection('disasters').doc(disasterId);
      final doc = await docRef.get();

      if (!doc.exists) {
        // Only add if it doesn't exist
        await docRef.set({
          'disasterID': disasterId,
          'Type': group['Type'] ?? 'Unknown',
          'severity': group['severity'] ?? 'Medium',
          'title': group['title'] ?? 'New Disaster',
          'description': group['description'] ?? '',
          'affectedAreaIds': group['affectedAreaIds'] ?? [],
          'Status': group['Status'] ?? 'Active',
          'updatedAt': group['updatedAt'] != null
              ? Timestamp.fromDate(DateTime.parse(group['updatedAt']))
              : FieldValue.serverTimestamp(),
          'incidentCount': group['incidentCount'] ?? 0,
          'totalAffected': group['totalAffected'] ?? 0,
        });
      }
    }
  }

  Future<void> _generateAiSummary(List<QueryDocumentSnapshot> docs) async {
    if (docs.isEmpty) return;

    final incidents = docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();

    // Avoid redundant calls
    if (_aiInsightData != null &&
        incidents.length == _lastAnalyzedIncidents.length) {
      return;
    }

    setState(() => _isSummarizing = true);

    try {
      final insightData = await _aiService.summarizeIncidents(
        incidents,
        _areaNames,
      );

      if (mounted) {
        setState(() {
          _aiInsightData = insightData;
          _isSummarizing = false;
          _lastAnalyzedIncidents = incidents;
        });

        // Sync to disasters collection
        if (insightData['groups'] != null) {
          _syncDisastersToFirestore(insightData['groups']);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSummarizing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Container(
              color: const Color(0xFF1A56DB),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Row(
                children: [
                  const Text(
                    'My Cases',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () {
                      _aiInsightData = null; // Reset to force refresh
                      setState(() {});
                    },
                  ),
                ],
              ),
            ),
            // Content
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('reported_cases')
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  final allDocs = snapshot.data?.docs ?? [];

                  // Apply Filters
                  final filteredDocs = allDocs.where((doc) {
                    final data = doc.data() as Map<String, dynamic>;

                    // Severity
                    if (_selectedSeverity != 'All') {
                      final sev = (data['severity'] as int?) ?? 0;
                      if (_selectedSeverity == 'Critical' && sev < 9) {
                        return false;
                      }
                      if (_selectedSeverity == 'High' &&
                          (sev < 7 || sev >= 9)) {
                        return false;
                      }
                      if (_selectedSeverity == 'Medium' &&
                          (sev < 4 || sev >= 7)) {
                        return false;
                      }
                      if (_selectedSeverity == 'Low' && sev >= 4) {
                        return false;
                      }
                    }

                    // Type
                    if (_selectedType != 'All' &&
                        (data['category'] as String?)
                                .toString()
                                .toLowerCase() !=
                            _selectedType.toLowerCase()) {
                      return false;
                    }

                    // Status
                    if (_selectedStatus != 'All' &&
                        (data['checkIn'] as String?).toString().toLowerCase() !=
                            _selectedStatus.toLowerCase()) {
                      return false;
                    }

                    // Date Range
                    final timestamp = (data['timestamp'] as Timestamp?)
                        ?.toDate();
                    if (_selectedDateRange != null && timestamp != null) {
                      if (timestamp.isBefore(_selectedDateRange!.start) ||
                          timestamp.isAfter(
                            _selectedDateRange!.end.add(
                              const Duration(days: 1),
                            ),
                          )) {
                        return false;
                      }
                    } else if (_selectedTime != 'All Time' &&
                        timestamp != null) {
                      final now = DateTime.now();
                      if (_selectedTime == 'Today' &&
                          !DateUtils.isSameDay(timestamp, now)) {
                        return false;
                      }
                      if (_selectedTime == 'Last 7 Days' &&
                          timestamp.isBefore(
                            now.subtract(const Duration(days: 7)),
                          )) {
                        return false;
                      }
                      if (_selectedTime == 'Last 30 Days' &&
                          timestamp.isBefore(
                            now.subtract(const Duration(days: 30)),
                          )) {
                        return false;
                      }
                    }

                    return true;
                  }).toList();

                  // Statistics
                  int totalIncidents = allDocs.length;
                  int criticalCases = allDocs
                      .where(
                        (doc) =>
                            ((doc.data() as Map)['severity'] as int? ?? 0) >= 9,
                      )
                      .length;
                  int peopleTrapped = allDocs.fold(0, (acc, doc) {
                    final d = doc.data() as Map;
                    if (d['status'] == 'need_assistance' ||
                        d['checkIn'] == 'need_assistance') {
                      return acc + (d['peopleAffected'] as int? ?? 0);
                    }
                    return acc;
                  });
                  int totalAffected = allDocs.fold(
                    0,
                    (acc, doc) =>
                        acc +
                        ((doc.data() as Map)['peopleAffected'] as int? ?? 0),
                  );

                  // Trigger automatic AI analysis if not already doing it
                  if (!_isSummarizing &&
                      (_aiInsightData == null ||
                          allDocs.length != _lastAnalyzedIncidents.length)) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _generateAiSummary(allDocs);
                    });
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Stats Section
                      _buildStatsGrid(
                        totalIncidents,
                        criticalCases,
                        peopleTrapped,
                        totalAffected,
                      ),
                      const SizedBox(height: 16),

                      // Filter Section
                      _buildFilterSection(),
                      const SizedBox(height: 20),

                      // AI Summary Section
                      _buildAiSummarySection(),
                      const SizedBox(height: 20),

                      const Text(
                        'Reported Incidents',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 12),

                      if (filteredDocs.isEmpty)
                        _buildEmptyState()
                      else
                        ...filteredDocs.map((doc) => _buildIncidentCard(doc)),

                      const SizedBox(height: 20),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiSummarySection() {
    if (_isSummarizing) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
        ),
        child: const Column(
          children: [
            CircularProgressIndicator(strokeWidth: 2),
            SizedBox(height: 12),
            Text(
              'AI is analyzing recent incidents...',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_aiInsightData == null) return const SizedBox.shrink();

    final summary = _aiInsightData!['summary'] ?? '';
    final groups = _aiInsightData!['groups'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    size: 18,
                    color: Color(0xFF1A56DB),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'AI Intelligence Summary',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1A56DB),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(summary, style: const TextStyle(fontSize: 13, height: 1.5)),
            ],
          ),
        ),
        if (groups.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text(
            'Analyzed Disasters',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          ...groups.map((g) => _buildDisasterGroupCard(g)),
        ],
      ],
    );
  }

  Widget _buildDisasterGroupCard(Map<String, dynamic> group) {
    final areaIds = group['affectedAreaIds'] as List? ?? [];
    final areaName = areaIds.isNotEmpty
        ? _getAreaName(areaIds[0])
        : (group['area'] ?? 'Unknown Area');
    final severity = group['severity'] ?? 'Medium';
    final severityColor = _getSeverityColor(severity);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: severityColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.location_on, size: 14, color: severityColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    areaName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: severityColor,
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
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group['title'] ?? 'Incident Group',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  group['analysis'] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _miniStat(
                      Icons.article_outlined,
                      '${group['incidentCount']} Cases',
                    ),
                    const SizedBox(width: 16),
                    _miniStat(
                      Icons.people_outline,
                      '${group['totalAffected']} Affected',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncidentCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final category = data['category'] ?? 'General';
    final areaId = data['areaId'] ?? '';
    final areaName = _getAreaName(areaId);
    final timestamp = (data['timestamp'] as Timestamp?)?.toDate();
    final timeStr = timestamp != null
        ? DateFormat('MMM dd, hh:mm a').format(timestamp)
        : '';
    final severity = (data['severity'] as int?) ?? 0;

    Color categoryColor = const Color(0xFF1A56DB);
    if (category.toLowerCase().contains('flood')) {
      categoryColor = Colors.blue.shade700;
    } else if (category.toLowerCase().contains('fire')) {
      categoryColor = Colors.red.shade700;
    } else if (category.toLowerCase().contains('storm')) {
      categoryColor = Colors.indigo.shade700;
    } else if (category.toLowerCase().contains('earthquake')) {
      categoryColor = Colors.brown.shade700;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: categoryColor.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: categoryColor.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: categoryColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.emergency_outlined,
                  size: 16,
                  color: categoryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.toUpperCase(),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: categoryColor,
                      ),
                    ),
                    Text(
                      areaName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              _buildSeverityIndicator(severity),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            data['description'] ?? 'No description provided',
            style: const TextStyle(fontSize: 13, color: Colors.black87),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                timeStr,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              Text(
                'Status: ${data['checkIn'] ?? 'Reported'}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: categoryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityIndicator(int severity) {
    Color color = Colors.green;
    if (severity >= 9) {
      color = Colors.red;
    } else if (severity >= 7) {
      color = Colors.orange;
    } else if (severity >= 4) {
      color = Colors.yellow.shade700;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        'Level $severity',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.inbox_outlined, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text(
              'No cases reported yet',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
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

  Widget _buildStatsGrid(int total, int critical, int trapped, int affected) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.6,
      children: [
        _buildStatsCard(
          'Total Incidents',
          '$total',
          'Active reports',
          Icons.article_outlined,
          Colors.blue.shade700,
          Colors.blue.shade50,
        ),
        _buildStatsCard(
          'Critical Cases',
          '$critical',
          'Immediate attention',
          Icons.warning_amber_rounded,
          Colors.red.shade700,
          Colors.red.shade50,
        ),
        _buildStatsCard(
          'People Trapped',
          '$trapped',
          'Rescue needed',
          Icons.hail_rounded,
          Colors.orange.shade700,
          Colors.orange.shade50,
        ),
        _buildStatsCard(
          'People Affected',
          '$affected',
          'Across all incidents',
          Icons.people_outline_rounded,
          Colors.indigo.shade700,
          Colors.indigo.shade50,
        ),
      ],
    );
  }

  Widget _buildStatsCard(
    String title,
    String value,
    String sub,
    IconData icon,
    Color color,
    Color bg,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 14, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: color.withValues(alpha: 0.8),
                    fontWeight: FontWeight.bold,
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
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color.withValues(alpha: 0.9),
            ),
          ),
          Text(
            sub,
            style: TextStyle(
              fontSize: 10,
              color: color.withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.tune, size: 18, color: Colors.grey),
              const SizedBox(width: 10),
              const Text(
                'Filter Incidents',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  'Severity',
                  _selectedSeverity,
                  ['All', 'Critical', 'High', 'Medium', 'Low'],
                  (val) => setState(() => _selectedSeverity = val!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown('Type', _selectedType, [
                  'All',
                  'Flood',
                  'Fire',
                  'Storm',
                  'Earthquake',
                  'Other',
                ], (val) => setState(() => _selectedType = val!)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildFilterDropdown(
                  'Status',
                  _selectedStatus,
                  ['All', 'Reported', 'Need_assistance', 'Rescued', 'Safe'],
                  (val) => setState(() => _selectedStatus = val!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildFilterDropdown('Time', _selectedTime, [
                  'All Time',
                  'Today',
                  'Last 7 Days',
                  'Last 30 Days',
                ], (val) => setState(() => _selectedTime = val!)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Date Range',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final range = await showDateRangePicker(
                      context: context,
                      firstDate: DateTime(2024),
                      lastDate: DateTime.now(),
                    );
                    if (range != null) {
                      setState(() => _selectedDateRange = range);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _selectedDateRange == null
                              ? 'From'
                              : DateFormat(
                                  'MM/dd',
                                ).format(_selectedDateRange!.start),
                          style: TextStyle(
                            fontSize: 12,
                            color: _selectedDateRange == null
                                ? Colors.grey
                                : Colors.black87,
                          ),
                        ),
                        const Spacer(),
                        const Text('→', style: TextStyle(color: Colors.grey)),
                        const Spacer(),
                        Text(
                          _selectedDateRange == null
                              ? 'To'
                              : DateFormat(
                                  'MM/dd',
                                ).format(_selectedDateRange!.end),
                          style: TextStyle(
                            fontSize: 12,
                            color: _selectedDateRange == null
                                ? Colors.grey
                                : Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_selectedDateRange != null)
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _selectedDateRange = null),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> items,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              icon: const Icon(Icons.expand_more, size: 18),
              style: const TextStyle(fontSize: 13, color: Colors.black87),
              items: items.map((String item) {
                return DropdownMenuItem<String>(value: item, child: Text(item));
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.red.shade900;
      case 'high':
        return Colors.red.shade700;
      case 'medium':
        return Colors.orange.shade700;
      default:
        return Colors.green.shade700;
    }
  }
}
