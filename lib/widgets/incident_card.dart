import 'package:flutter/material.dart';
import '../models/incident_model.dart';
import 'severity_legend.dart';

class IncidentCard extends StatelessWidget {
  final IncidentModel incident;
  final VoidCallback onViewDetails;

  const IncidentCard({
    super.key,
    required this.incident,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final color = severityColor(incident.severity);
    final bgColor = color.withValues(alpha: 0.08);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + severity badge
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    incident.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    incident.severity.name,
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
              incident.location,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
            const Divider(height: 16),
            // Grid of details
            Row(
              children: [
                _DetailItem(label: 'Incident ID', value: incident.id),
                const SizedBox(width: 20),
                _DetailItem(label: 'Zone', value: incident.zone),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _DetailItem(
                  label: 'People Affected',
                  value: incident.peopleAffected.toString(),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Status',
                      style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 2),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Text(
                        incident.status,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Description',
              style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 3),
            Text(
              incident.description,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF374151),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onViewDetails,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF111827),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'View Details & Coordinate Response',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  const _DetailItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
