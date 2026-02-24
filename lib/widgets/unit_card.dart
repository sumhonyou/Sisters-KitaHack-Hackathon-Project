import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/reporter_model.dart';
import 'severity_legend.dart';

class UnitCard extends StatelessWidget {
  final ReporterModel reporter;
  const UnitCard({super.key, required this.reporter});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Future<void> _makeCall(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: Text('Call ${reporter.reporterName}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.phone, size: 48, color: Color(0xFF1A56DB)),
            const SizedBox(height: 12),
            Text(
              reporter.phone,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              reporter.locationLabel,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.phone, size: 16),
            label: const Text('Call'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF16A34A),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final uri = Uri(scheme: 'tel', path: reporter.phone);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = severityColorFromString(reporter.severity);
    final bgColor = color.withValues(alpha: 0.07);

    return GestureDetector(
      onTap: () => _makeCall(context),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Unit ID + SOS Badge
              Row(
                children: [
                  Text(
                    reporter.unitId,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(width: 8),
                  severityBadge(reporter.severity),
                  const Spacer(),
                  if (reporter.hasSOS)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'SOS',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    )
                  else
                    Icon(Icons.warning_amber_rounded, color: color, size: 20),
                ],
              ),
              const SizedBox(height: 6),
              // Location
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    size: 13,
                    color: Color(0xFFEF4444),
                  ),
                  const SizedBox(width: 3),
                  Expanded(
                    child: Text(
                      reporter.locationLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              // Reporter name
              Text(
                reporter.reporterName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 4),
              // Phone
              GestureDetector(
                onTap: () => _makeCall(context),
                child: Row(
                  children: [
                    const Icon(Icons.phone, size: 13, color: Color(0xFF1A56DB)),
                    const SizedBox(width: 4),
                    Text(
                      reporter.phone,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1A56DB),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // People affected + time
              Row(
                children: [
                  const Icon(Icons.people, size: 13, color: Color(0xFF6B7280)),
                  const SizedBox(width: 4),
                  Text(
                    reporter.peopleAffected.toString(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _timeAgo(reporter.timestamp),
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
      ),
    );
  }
}
