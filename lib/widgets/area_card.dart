import 'package:flutter/material.dart';
import '../models/area_model.dart';
import '../models/reported_case_model.dart';
import '../models/incident_model.dart'; // for Severity + severityColor
import '../widgets/severity_legend.dart';

class AreaCard extends StatelessWidget {
  final AreaModel area;
  final List<ReportedCase> cases;
  final String? thumbnailUrl;
  final VoidCallback onTap;

  const AreaCard({
    super.key,
    required this.area,
    required this.cases,
    required this.onTap,
    this.thumbnailUrl,
  });

  Severity get _worstSeverity {
    if (cases.any((c) => c.severity == Severity.critical)) {
      return Severity.critical;
    }
    if (cases.any((c) => c.severity == Severity.high)) {
      return Severity.high;
    }
    if (cases.any((c) => c.severity == Severity.medium)) {
      return Severity.medium;
    }
    return Severity.low;
  }

  @override
  Widget build(BuildContext context) {
    final severity = cases.isEmpty ? Severity.low : _worstSeverity;
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
        child: Stack(
          children: [
            // Thumbnail in top-right corner
            if (thumbnailUrl != null)
              Positioned(
                top: 8,
                right: 8,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    thumbnailUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Area name (leave room for thumbnail)
                  SizedBox(
                    width: thumbnailUrl != null ? 90 : double.infinity,
                    child: Text(
                      area.name.toUpperCase(),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF374151),
                        letterSpacing: 0.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cases.length.toString(),
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF111827),
                            ),
                          ),
                          const Text(
                            'Cases',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cases.isEmpty ? Colors.grey : color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          cases.isEmpty ? 'clear' : severity.name,
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
          ],
        ),
      ),
    );
  }
}
