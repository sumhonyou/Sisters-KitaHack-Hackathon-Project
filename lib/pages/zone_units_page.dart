import 'package:flutter/material.dart';
import '../models/reporter_model.dart';
import '../models/incident_model.dart';
import '../services/firestore_service.dart';
import '../widgets/unit_card.dart';

class ZoneUnitsPage extends StatefulWidget {
  final String zoneName;
  final List<IncidentModel> incidents;

  const ZoneUnitsPage({
    super.key,
    required this.zoneName,
    required this.incidents,
  });

  @override
  State<ZoneUnitsPage> createState() => _ZoneUnitsPageState();
}

class _ZoneUnitsPageState extends State<ZoneUnitsPage> {
  final FirestoreService _service = FirestoreService();
  String _search = '';
  String _filterSeverity = 'All Severities';
  String _sortBy = 'Severity';
  final Set<String> _selected = {};

  List<ReporterModel> _applyFilters(List<ReporterModel> all) {
    var list = all;
    if (_search.isNotEmpty) {
      list = list
          .where(
            (r) =>
                r.reporterName.toLowerCase().contains(_search.toLowerCase()) ||
                r.unitId.toLowerCase().contains(_search.toLowerCase()),
          )
          .toList();
    }
    if (_filterSeverity != 'All Severities') {
      list = list
          .where(
            (r) => r.severity.toLowerCase() == _filterSeverity.toLowerCase(),
          )
          .toList();
    }
    if (_sortBy == 'Severity') {
      const order = ['critical', 'high', 'medium', 'low'];
      list.sort(
        (a, b) => order.indexOf(a.severity) - order.indexOf(b.severity),
      );
    } else if (_sortBy == 'Time') {
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    } else if (_sortBy == 'People') {
      list.sort((a, b) => b.peopleAffected - a.peopleAffected);
    }
    return list;
  }

  Widget _buildSummaryStats(List<ReporterModel> reporters) {
    final total = reporters.fold<int>(0, (s, r) => s + r.peopleAffected);
    final sos = reporters.where((r) => r.hasSOS).length;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _StatChip(
            value: reporters.length.toString(),
            label: 'Units',
            icon: Icons.group,
          ),
          _StatChip(
            value: total.toString(),
            label: 'Affected',
            icon: Icons.people,
          ),
          _StatChip(
            value: sos.toString(),
            label: 'SOS',
            icon: Icons.sos,
            color: const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF111827)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.zoneName,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            Text(
              '${widget.incidents.length} active incident${widget.incidents.length != 1 ? 's' : ''}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
      body: StreamBuilder<List<ReporterModel>>(
        stream: _service.reportersStream(zone: widget.zoneName),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final allReporters = snap.data ?? [];
          final filtered = _applyFilters(allReporters);

          return RefreshIndicator(
            onRefresh: () async {},
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(child: _buildSummaryStats(allReporters)),
                // Filters
                SliverToBoxAdapter(
                  child: Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.filter_list,
                              size: 16,
                              color: Color(0xFF6B7280),
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Filters & Controls',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            const Spacer(),
                            _ActionChip(
                              icon: Icons.refresh,
                              label: 'Auto',
                              onTap: () => setState(() {}),
                            ),
                            const SizedBox(width: 8),
                            _ActionChip(
                              icon: Icons.download,
                              label: '',
                              onTap: () {},
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          onChanged: (v) => setState(() => _search = v),
                          decoration: InputDecoration(
                            hintText: 'Search units...',
                            hintStyle: const TextStyle(fontSize: 12),
                            prefixIcon: const Icon(Icons.search, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Colors.grey.shade300,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 8,
                            ),
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _DropDown<String>(
                          value: _filterSeverity,
                          items: const [
                            'All Severities',
                            'critical',
                            'high',
                            'medium',
                            'low',
                          ],
                          onChanged: (v) =>
                              setState(() => _filterSeverity = v!),
                        ),
                        const SizedBox(height: 8),
                        _DropDown<String>(
                          value: _sortBy,
                          items: const ['Severity', 'Time', 'People'],
                          onChanged: (v) => setState(() => _sortBy = v!),
                          prefix: const Icon(Icons.swap_vert, size: 16),
                        ),
                      ],
                    ),
                  ),
                ),
                // Header
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                    child: Row(
                      children: [
                        Text(
                          '${widget.zoneName} Units (${filtered.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const Spacer(),
                        if (_selected.isNotEmpty)
                          TextButton(
                            onPressed: () => setState(() => _selected.clear()),
                            child: const Text(
                              'Clear Selection',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Unit cards
                if (filtered.isEmpty)
                  const SliverFillRemaining(
                    child: Center(
                      child: Text(
                        'No units found',
                        style: TextStyle(color: Color(0xFF9CA3AF)),
                      ),
                    ),
                  )
                else
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) => UnitCard(reporter: filtered[i]),
                      childCount: filtered.length,
                    ),
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 20)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _StatChip({
    required this.value,
    required this.label,
    required this.icon,
    this.color = const Color(0xFF1A56DB),
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: color,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: Color(0xFF6B7280)),
        ),
      ],
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: const Color(0xFF374151)),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DropDown<T> extends StatelessWidget {
  final T value;
  final List<T> items;
  final ValueChanged<T?> onChanged;
  final Widget? prefix;
  const _DropDown({
    required this.value,
    required this.items,
    required this.onChanged,
    this.prefix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          if (prefix != null) ...[prefix!, const SizedBox(width: 6)],
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<T>(
                value: value,
                isExpanded: true,
                style: const TextStyle(fontSize: 12, color: Color(0xFF374151)),
                items: items
                    .map(
                      (i) => DropdownMenuItem<T>(
                        value: i,
                        child: Text(
                          i.toString(),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: onChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
