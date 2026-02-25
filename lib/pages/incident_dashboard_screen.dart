import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  String _timeFilter = 'All Time';
  DateTime? _fromDate;
  DateTime? _toDate;

  final AiService _aiService = AiService();
  Map<String, dynamic>? _aiInsightData;
  bool _isSummarizing = false;
  bool _isReloading = false;

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
          _severityLabel(severity) != _severityFilter)
        return false;
      if (_typeFilter != 'All' &&
          !category.toLowerCase().contains(_typeFilter.toLowerCase()))
        return false;
      if (_statusFilter != 'All' && _checkInLabel(checkIn) != _statusFilter)
        return false;

      if (_fromDate != null && ts != null && ts.isBefore(_fromDate!))
        return false;
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

      if (_timeFilter != 'All Time' && ts != null) {
        final now = DateTime.now();
        if (_timeFilter == '30 Mins' &&
            ts.isBefore(now.subtract(const Duration(minutes: 30))))
          return false;
        if (_timeFilter == '1 Hour' &&
            ts.isBefore(now.subtract(const Duration(hours: 1))))
          return false;
        if (_timeFilter == '1 Day' &&
            ts.isBefore(now.subtract(const Duration(days: 1))))
          return false;
      }

      return true;
    }).toList();
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
    setState(() => _isSummarizing = true);
    final insightData = await _aiService.summarizeIncidents(incidents);
    setState(() {
      _aiInsightData = insightData;
      _isSummarizing = false;
    });
  }

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
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            Text(
              'Real-time monitoring',
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
          if (snapshot.connectionState == ConnectionState.waiting)
            return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));

          final allDocs = snapshot.data?.docs ?? [];
          final filtered = _applyFilters(allDocs);

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _filterCard(),
              const SizedBox(height: 14),
              _aiSummarySection(filtered),
              const SizedBox(height: 14),
              const Text(
                'Filtered Incidents',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              ...filtered.map(
                (d) => _incidentTile(d.data() as Map<String, dynamic>),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filterCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: _dropdown(
                  'Severity',
                  _severityFilter,
                  ['All', 'Critical', 'High', 'Medium', 'Low'],
                  (v) => setState(() => _severityFilter = v!),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _dropdown('Status', _statusFilter, [
                  'All',
                  'Safe',
                  'Need Help',
                  'Trapped',
                ], (v) => setState(() => _statusFilter = v!)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        DropdownButton<String>(
          value: value,
          isExpanded: true,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
              .toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _aiSummarySection(List<QueryDocumentSnapshot> docs) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: Colors.blue, size: 20),
              const SizedBox(width: 8),
              const Text(
                'AI Summary',
                style: TextStyle(fontWeight: FontWeight.bold),
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
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: () => _generateAiSummary(docs),
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (_aiInsightData != null)
            Text(_aiInsightData!['summary'] ?? '')
          else
            const Text(
              'Click refresh to generate AI insights for the filtered cases.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
        ],
      ),
    );
  }

  Widget _incidentTile(Map<String, dynamic> data) {
    final severity = (data['severity'] as int?) ?? 0;
    final label = _severityLabel(severity);
    final color = _severityColor(label);
    final checkIn = data['checkIn'] as String? ?? 'safe';

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.1),
          child: Icon(Icons.warning, color: color),
        ),
        title: Text(
          data['category']?.toUpperCase() ?? 'INCIDENT',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(data['description'] ?? 'No description'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _checkInLabel(checkIn),
              style: TextStyle(color: _checkInColor(checkIn), fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}
