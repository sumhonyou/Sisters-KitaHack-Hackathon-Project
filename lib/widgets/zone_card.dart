import 'package:flutter/material.dart';
import '../models/incident_model.dart';
import 'severity_legend.dart';

class ZoneCard extends StatelessWidget {
  final String zoneName;
  final List<IncidentModel> incidents;
  final VoidCallback onTap;

  const ZoneCard({
    super.key,
    required this.zoneName,
    required this.incidents,
    required this.onTap,
  });

  Severity get _worstSeverity {
    if (incidents.any((i) => i.severity == Severity.critical)) {
      return Severity.critical;
    } else if (incidents.any((i) => i.severity == Severity.high)) {
      return Severity.high;
    } else if (incidents.any((i) => i.severity == Severity.medium)) {
      return Severity.medium;
    }
    return Severity.low;
  }

  @override
  Widget build(BuildContext context) {
    final severity = _worstSeverity;
    final color = severityColor(severity);
    final bgColor = color.withValues(alpha: 0.08);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1.5),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              zoneName.toUpperCase(),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: Color(0xFF374151),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incidents.length.toString(),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const Text(
                      'Active',
                      style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: severity == Severity.low || severity == Severity.high
                        ? Colors.black
                        : color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    severity.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
