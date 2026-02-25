import 'package:flutter/material.dart';
import '../models/area_model.dart';
import '../models/reported_case_model.dart';
import '../models/severity.dart'; // Severity + severityColor
import '../widgets/severity_legend.dart';
import 'case_detail_page.dart';

class AreaCasesPage extends StatefulWidget {
  final AreaModel area;
  final List<ReportedCase> cases;

  const AreaCasesPage({super.key, required this.area, required this.cases});

  @override
  State<AreaCasesPage> createState() => _AreaCasesPageState();
}

class _AreaCasesPageState extends State<AreaCasesPage> {
  String _search = '';
  String _filterSeverity = 'All';
  String _sortBy = 'Newest';

  static const _severities = ['All', 'critical', 'high', 'medium', 'low'];
  static const _sorts = ['Newest', 'Most Affected', 'Severity'];

  List<ReportedCase> get _filtered {
    var list = widget.cases.where((c) {
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        if (!c.category.toLowerCase().contains(q) &&
            !c.description.toLowerCase().contains(q) &&
            !c.caseId.toLowerCase().contains(q)) {
          return false;
        }
      }
      if (_filterSeverity != 'All' && c.severity.name != _filterSeverity) {
        return false;
      }
      return true;
    }).toList();

    switch (_sortBy) {
      case 'Newest':
        list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
        break;
      case 'Most Affected':
        list.sort((a, b) => b.peopleAffected.compareTo(a.peopleAffected));
        break;
      case 'Severity':
        const order = ['critical', 'high', 'medium', 'low'];
        list.sort(
          (a, b) => order
              .indexOf(a.severity.name)
              .compareTo(order.indexOf(b.severity.name)),
        );
        break;
    }
    return list;
  }

  Widget _buildSummary() {
    final total = widget.cases.fold<int>(0, (s, c) => s + c.peopleAffected);
    final critCount = widget.cases
        .where((c) => c.severity == Severity.critical)
        .length;
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
            value: widget.cases.length.toString(),
            label: 'Cases',
            icon: Icons.folder_open,
          ),
          _StatChip(
            value: total.toString(),
            label: 'Affected',
            icon: Icons.people,
          ),
          _StatChip(
            value: critCount.toString(),
            label: 'Critical',
            icon: Icons.warning_amber,
            color: const Color(0xFFEF4444),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;

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
              widget.area.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
            Text(
              '${widget.cases.length} case${widget.cases.length != 1 ? 's' : ''} reported',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // Summary stats
          SliverToBoxAdapter(child: _buildSummary()),

          // Filters card
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Search
                  TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Search cases…',
                      hintStyle: const TextStyle(fontSize: 12),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Severity filter
                  _DropDown<String>(
                    value: _filterSeverity,
                    items: _severities,
                    onChanged: (v) => setState(() => _filterSeverity = v!),
                  ),
                  const SizedBox(height: 8),
                  // Sort
                  _DropDown<String>(
                    value: _sortBy,
                    items: _sorts,
                    onChanged: (v) => setState(() => _sortBy = v!),
                    prefix: const Icon(Icons.swap_vert, size: 16),
                  ),
                ],
              ),
            ),
          ),

          // Header row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
              child: Text(
                '${widget.area.name} Cases (${filtered.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF111827),
                ),
              ),
            ),
          ),

          // Cases list
          if (filtered.isEmpty)
            const SliverFillRemaining(
              child: Center(
                child: Text(
                  'No cases found',
                  style: TextStyle(color: Color(0xFF9CA3AF)),
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (ctx, i) => _CaseTile(
                  reportedCase: filtered[i],
                  onTap: () => Navigator.push(
                    ctx,
                    MaterialPageRoute(
                      builder: (_) => CaseDetailPage(reportedCase: filtered[i]),
                    ),
                  ),
                ),
                childCount: filtered.length,
              ),
            ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }
}

// ── Case tile ─────────────────────────────────────────────────────────────

class _CaseTile extends StatelessWidget {
  final ReportedCase reportedCase;
  final VoidCallback onTap;
  const _CaseTile({required this.reportedCase, required this.onTap});

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  @override
  Widget build(BuildContext context) {
    final rc = reportedCase;
    final color = severityColor(rc.severity);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      color: color.withValues(alpha: 0.05),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail or icon
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: rc.media.isNotEmpty
                    ? Image.network(
                        rc.media.first,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            _defaultIcon(color),
                      )
                    : _defaultIcon(color),
              ),
              const SizedBox(width: 12),
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            rc.category.toUpperCase(),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            rc.severity.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      rc.description.isNotEmpty ? rc.description : '—',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.people_outline,
                          size: 12,
                          color: Color(0xFF9CA3AF),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${rc.peopleAffected} affected',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _timeAgo(rc.timestamp),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _defaultIcon(Color color) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.warning_amber_rounded, color: color, size: 28),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────

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
