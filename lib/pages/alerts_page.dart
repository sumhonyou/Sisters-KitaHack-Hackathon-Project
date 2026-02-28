import 'package:flutter/material.dart';
import '../models/disaster_model.dart';
import '../services/alerts_service.dart';
import 'alert_detail_page.dart';

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  final AlertsService _alertsService = AlertsService();
  String _searchQuery = '';
  String _selectedCategory = 'All';
  bool _filterNearby = false;
  bool _filterHighSeverity = false;
  bool _filterLast24Hours = false;

  final List<String> _categories = [
    'All',
    'Flood',
    'Fire',
    'Storm',
    'Earthquake',
    'Tsunami',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Alerts',
          style: TextStyle(
            color: Color(0xFF111827),
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildCategoryChips(),
          _buildFilterPills(),
          Expanded(
            child: StreamBuilder<List<DisasterModel>>(
              stream: _alertsService.streamActiveDisasters(),
              builder: (context, disasterSnapshot) {
                return StreamBuilder<Map<String, dynamic>>(
                  stream: _alertsService.streamAreaMap(),
                  builder: (context, areaSnapshot) {
                    if (disasterSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final disasters = disasterSnapshot.data ?? [];
                    final areaMap = areaSnapshot.data ?? {};
                    final filteredDisasters = _filterDisasters(disasters);

                    if (filteredDisasters.isEmpty) {
                      return _buildEmptyState();
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: filteredDisasters.length,
                      itemBuilder: (context, index) {
                        final disaster = filteredDisasters[index];
                        String areaName = 'Unknown Location';
                        if (disaster.affectedAreaIds.isNotEmpty) {
                          final firstAreaId = disaster.affectedAreaIds.first;
                          areaName =
                              areaMap[firstAreaId]?['name'] ?? firstAreaId;
                        }
                        return _buildAlertCard(disaster, areaName);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: TextField(
          onChanged: (value) => setState(() => _searchQuery = value),
          decoration: const InputDecoration(
            hintText: 'Search location or keyword',
            hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
            prefixIcon: Icon(Icons.search, color: Color(0xFF9CA3AF)),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          final isSelected = _selectedCategory == category;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                setState(() => _selectedCategory = category);
              },
              selectedColor: const Color(0xFF1A56DB),
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF4B5563),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? Colors.transparent
                      : const Color(0xFFE5E7EB),
                ),
              ),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterPills() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            _filterPill(
              'Nearby',
              _filterNearby,
              (val) => setState(() => _filterNearby = val),
            ),
            _filterPill(
              'High Severity',
              _filterHighSeverity,
              (val) => setState(() => _filterHighSeverity = val),
            ),
            _filterPill(
              'Last 24 Hours',
              _filterLast24Hours,
              (val) => setState(() => _filterLast24Hours = val),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterPill(String label, bool isSelected, Function(bool) onToggle) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => onToggle(!isSelected),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFEBF5FF) : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF1A56DB)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: isSelected
                      ? const Color(0xFF1A56DB)
                      : const Color(0xFF4B5563),
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: 4),
                const Icon(Icons.close, size: 14, color: Color(0xFF1A56DB)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAlertCard(DisasterModel disaster, String areaName) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlertDetailPage(disasterId: disaster.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildCategoryIcon(disaster.category),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    disaster.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                _buildSeverityPill(disaster.severity),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  "$areaName • ${timeAgo(disaster.updatedAt)}",
                  style: const TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              disaster.description,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFF4B5563), fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryIcon(String category) {
    IconData iconData;
    Color color;

    switch (category) {
      case 'Flood':
        iconData = Icons.water_drop;
        color = Colors.blue;
        break;
      case 'Fire':
        iconData = Icons.local_fire_department;
        color = Colors.orange;
        break;
      case 'Earthquake':
        iconData = Icons.vibration;
        color = Colors.brown;
        break;
      case 'Storm':
        iconData = Icons.cyclone;
        color = Colors.indigo;
        break;
      case 'Tsunami':
        iconData = Icons.waves;
        color = Colors.teal;
        break;
      case 'Landslide':
        iconData = Icons.landscape;
        color = Colors.green;
        break;
      default:
        iconData = Icons.warning_amber_rounded;
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, color: color, size: 24),
    );
  }

  Widget _buildSeverityPill(String severity) {
    Color bg;
    Color text;
    String label = severity;

    if (severity.toLowerCase() == 'high') {
      bg = const Color(0xFFFEE2E2);
      text = const Color(0xFFEF4444);
    } else if (severity.toLowerCase() == 'medium') {
      bg = const Color(0xFFFFEDD5);
      text = const Color(0xFFF97316);
    } else {
      bg = const Color(0xFFDCFCE7);
      text = const Color(0xFF22C55E);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: text,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<DisasterModel> _filterDisasters(List<DisasterModel> disasters) {
    return disasters.where((d) {
      final matchesSearch =
          _searchQuery.isEmpty ||
          d.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          d.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          d.type.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesCategory =
          _selectedCategory == 'All' || d.category == _selectedCategory;

      final matchesSeverity =
          !_filterHighSeverity || d.severity.toLowerCase() == 'high';

      final matchesTime =
          !_filterLast24Hours ||
          d.updatedAt.isAfter(
            DateTime.now().subtract(const Duration(hours: 24)),
          );

      return matchesSearch && matchesCategory && matchesSeverity && matchesTime;
    }).toList();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_off_outlined,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No active alerts found',
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ],
      ),
    );
  }

  String timeAgo(DateTime dateTime) {
    final difference = DateTime.now().difference(dateTime);
    if (difference.inDays >= 1) return '${difference.inDays}d ago';
    if (difference.inHours >= 1) return '${difference.inHours}h ago';
    if (difference.inMinutes >= 1) return '${difference.inMinutes}m ago';
    return 'Just now';
  }
}
