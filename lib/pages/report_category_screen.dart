import 'package:flutter/material.dart';
import 'package:kitahack/pages/report_from_screen.dart';

class ReportCategoryScreen extends StatelessWidget {
  const ReportCategoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // List of disaster categories
    final List<_Category> categories = [
      const _Category(
        'Flood',
        Icons.water,
        Color(0xFF1976D2),
        Color(0xFFE3F2FD),
      ),
      const _Category(
        'Fire',
        Icons.local_fire_department,
        Color(0xFFD32F2F),
        Color(0xFFFFEBEE),
      ),
      const _Category(
        'Storm',
        Icons.thunderstorm,
        Color(0xFF7B1FA2),
        Color(0xFFF3E5F5),
      ),
      const _Category(
        'Earthquake',
        Icons.crisis_alert,
        Color(0xFF5D4037),
        Color(0xFFEFEBE9),
      ),
      const _Category(
        'Tsunami',
        Icons.waves,
        Color(0xFF0097A7),
        Color(0xFFE0F7FA),
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'Report Disaster',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What happened?',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a category to start your report.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView.separated(
                itemCount: categories.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 16),
                itemBuilder: (context, index) {
                  final cat = categories[index];
                  return _buildCategoryCard(context, cat);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(BuildContext context, _Category cat) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ReportFormScreen(category: cat.label),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
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
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cat.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(cat.icon, color: cat.color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                cat.label,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }
}

class _Category {
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;

  const _Category(this.label, this.icon, this.color, this.bg);
}
