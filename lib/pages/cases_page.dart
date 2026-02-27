import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class CasesPage extends StatefulWidget {
  const CasesPage({super.key});

  @override
  State<CasesPage> createState() => _CasesPageState();
}

class _CasesPageState extends State<CasesPage> {
  // Toggle states
  bool _showAllIncidents = false;

  // Filter states
  String _selectedSeverity = 'All';
  String _selectedType = 'All';
  String _selectedStatus = 'All';
  String _selectedTime = 'All Time';
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
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
                      else ...[
                        ...filteredDocs
                            .take(_showAllIncidents ? filteredDocs.length : 2)
                            .map((doc) => _buildIncidentCard(doc)),
                        if (filteredDocs.length > 2)
                          Center(
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  _showAllIncidents = !_showAllIncidents;
                                });
                              },
                              child: Text(
                                _showAllIncidents ? 'Show less' : 'Show all',
                                style: const TextStyle(
                                  color: Color(0xFF1A56DB),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],

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

  Widget _buildIncidentCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final category = data['category'] ?? 'General';
    final areaId = data['areaId'] ?? '';
    final areaName = areaId.isEmpty ? 'Unknown Area' : 'Area $areaId';
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
        border: Border.all(color: categoryColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: categoryColor.withOpacity(0.04),
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
                  color: categoryColor.withOpacity(0.1),
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5)),
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
        border: Border.all(color: color.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
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
                  color: Colors.white.withOpacity(0.6),
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
                    color: color.withOpacity(0.8),
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
              color: color.withOpacity(0.9),
            ),
          ),
          Text(
            sub,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.6),
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
}
