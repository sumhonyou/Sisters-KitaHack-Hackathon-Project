import 'package:flutter/material.dart';
import 'package:kitahack/pages/report_from_screen.dart';

class ReportCategoryScreen extends StatelessWidget {
  const ReportCategoryScreen({super.key});

  static const _categories = [
    // Flood
    _Category('Flood', Icons.water, Color(0xFF1565C0), Color(0xFFEDF4FB)),
    // Fire
    _Category(
      'Fire',
      Icons.local_fire_department,
      Color(0xFFB71C1C),
      Color(0xFFFDF0F0),
    ),
    // Storm
    _Category(
      'Storm',
      Icons.thunderstorm,
      Color(0xFF4527A0),
      Color(0xFFF2F0FB),
    ),
    // Earthquake
    _Category(
      'Earthquake',
      Icons.crisis_alert,
      Color(0xFF6D4C41),
      Color(0xFFF8F3EE),
    ),
    // Tsunami
    _Category('Tsunami', Icons.waves, Color(0xFF00696D), Color(0xFFEDF8F9)),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Report Incident',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select disaster type',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.separated(
                itemCount: _categories.length,
                separatorBuilder: (_, s) => const SizedBox(height: 14),
                itemBuilder: (context, i) {
                  final cat = _categories[i];
                  return _CategoryCard(
                    category: cat,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ReportFormScreen(
                          category: cat.label,
                          categoryIcon: cat.icon,
                          categoryColor: cat.color,
                          categoryBg: cat.bg,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Data class ─────────────────────────────────────────────────────────────

class _Category {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;

  const _Category(this.label, this.icon, this.color, this.bg);
}

// ─── Card widget ────────────────────────────────────────────────────────────

class _CategoryCard extends StatelessWidget {
  final _Category category;
  final VoidCallback onTap;

  const _CategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: category.bg,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        splashColor: category.color.withValues(alpha: 0.15),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: category.color.withValues(alpha: 0.25),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: category.color.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon bubble — white circle so icon pops on coloured bg
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(category.icon, color: category.color, size: 30),
              ),
              const SizedBox(width: 18),
              // Label
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.label,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: category.color,
                      ),
                    ),
                    Text(
                      _subtitle(category.label),
                      style: TextStyle(
                        fontSize: 12,
                        color: category.color.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: category.color.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(String label) {
    switch (label) {
      case 'Flood':
        return 'Rising water levels, inundation';
      case 'Fire':
        return 'Building fire, wildfire, smoke';
      case 'Storm':
        return 'Heavy rain, strong winds';
      case 'Earthquake':
        return 'Ground shaking, tremors';
      case 'Tsunami':
        return 'Coastal wave surge';
      default:
        return '';
    }
  }
}
