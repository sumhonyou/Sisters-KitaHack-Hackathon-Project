import 'package:flutter/material.dart';
import '../models/incident_model.dart';

Color severityColor(Severity s) {
  switch (s) {
    case Severity.critical:
      return const Color(0xFFEF4444);
    case Severity.high:
      return const Color(0xFFF97316);
    case Severity.medium:
      return const Color(0xFFF59E0B);
    case Severity.low:
      return const Color(0xFF22C55E);
  }
}

Color severityColorFromString(String s) {
  switch (s.toLowerCase()) {
    case 'critical':
      return const Color(0xFFEF4444);
    case 'high':
      return const Color(0xFFF97316);
    case 'medium':
      return const Color(0xFFF59E0B);
    default:
      return const Color(0xFF22C55E);
  }
}

class SeverityLegend extends StatelessWidget {
  const SeverityLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Severity Legend',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _LegendDot(
                color: severityColor(Severity.critical),
                label: 'Critical',
              ),
              _LegendDot(color: severityColor(Severity.high), label: 'High'),
              _LegendDot(
                color: severityColor(Severity.medium),
                label: 'Medium',
              ),
              _LegendDot(color: severityColor(Severity.low), label: 'Low'),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: Color(0xFF374151)),
        ),
      ],
    );
  }
}

Widget severityBadge(String label) {
  final color = severityColorFromString(label);
  final bg = label.toLowerCase() == 'low' || label.toLowerCase() == 'high'
      ? Colors.black
      : color;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      label.toLowerCase(),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
