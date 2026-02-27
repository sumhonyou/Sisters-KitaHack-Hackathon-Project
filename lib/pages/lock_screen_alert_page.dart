import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/alert_model.dart';
import 'alert_detail_page.dart';

/// Simulates a phone lock screen with a disaster alert notification.
/// Tap the notification card to expand/collapse it.
class LockScreenAlertPage extends StatefulWidget {
  final bool initialExpanded;
  const LockScreenAlertPage({super.key, this.initialExpanded = false});

  @override
  State<LockScreenAlertPage> createState() => _LockScreenAlertPageState();
}

class _LockScreenAlertPageState extends State<LockScreenAlertPage>
    with SingleTickerProviderStateMixin {
  late bool _expanded;

  // Demo alert for simulation
  AlertModel get _alert => AlertModel(
    id: 'demo-alert',
    title: 'Flash Flood Warning',
    description:
        'Heavy rainfall has caused flash flooding in your area. Seek higher ground.',
    type: 'flood',
    severity: 4,
    status: 'active',
    country: 'Malaysia',
    district: 'Kuala Lumpur',
    keywords: ['flood', 'rain', 'danger'],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initialExpanded;
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
      value: _expanded ? 1.0 : 0.0,
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  void _toggleExpand() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _expandController.forward();
    } else {
      _expandController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final timeStr = DateFormat('HH:mm').format(now);
    final dateStr = DateFormat('EEEE, MMMM d').format(now);

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          // ── Main content ──
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),

                // ── Fake status bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('h:mm').format(now),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Row(
                        children: [
                          _dot(Colors.white.withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          _dot(Colors.white.withValues(alpha: 0.5)),
                          const SizedBox(width: 4),
                          _dot(Colors.white),
                          const SizedBox(width: 4),
                          _dot(Colors.white),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 40),

                // ── Clock ──
                Text(
                  timeStr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 72,
                    fontWeight: FontWeight.w200,
                    letterSpacing: 2,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 18,
                    fontWeight: FontWeight.w400,
                  ),
                ),

                const SizedBox(height: 36),

                // ── Notification card ──
                GestureDetector(
                  onTap: _toggleExpand,
                  child: AnimatedBuilder(
                    animation: _expandAnimation,
                    alert: _alert,
                    expanded: _expanded,
                    onDismiss: () {
                      _toggleExpand(); // collapse
                    },
                    onViewDetails: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => AlertDetailPage(alert: _alert),
                        ),
                      );
                    },
                  ),
                ),

                const Spacer(),

                // ── Swipe up to unlock ──
                Column(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_up,
                        color: Colors.white.withValues(alpha: 0.5),
                        size: 24,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Swipe up to unlock',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Home indicator
                    Container(
                      width: 134,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ],
            ),
          ),

          // ── Back button (for demo navigation) ──
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(
                Icons.arrow_back_ios_new,
                color: Colors.white54,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Notification card with animated expand/collapse
// ─────────────────────────────────────────────────────────────────────────────

class AnimatedBuilder extends StatelessWidget {
  final Animation<double> animation;
  final AlertModel alert;
  final bool expanded;
  final VoidCallback onDismiss;
  final VoidCallback onViewDetails;

  const AnimatedBuilder({
    super.key,
    required this.animation,
    required this.alert,
    required this.expanded,
    required this.onDismiss,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Header (always visible) ──
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                // CG icon
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A56DB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text(
                      'CG',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CITY GUARD',
                        style: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${alert.title} – ${alert.severity >= 4 ? 'High' : (alert.severity >= 2 ? 'Medium' : 'Low')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const Text(
                  'now',
                  style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                ),
              ],
            ),
          ),

          // ── Collapsed: short text ──
          if (!expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(56, 0, 14, 14),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${alert.description}. Tap for more details.',
                  style: const TextStyle(
                    color: Color(0xFFD1D5DB),
                    fontSize: 13,
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),

          // ── Expanded: full details ──
          SizeTransition(
            sizeFactor: animation,
            axisAlignment: -1,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Divider
                Container(
                  height: 0.5,
                  color: Colors.white.withValues(alpha: 0.1),
                ),

                // Description
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
                  child: Text(
                    'Heavy rainfall has caused flash flooding in ${alert.district ?? 'your area'} and surrounding areas. Water levels are rising rapidly.',
                    style: const TextStyle(
                      color: Color(0xFFD1D5DB),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),

                // Distance + severity row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text('📍', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(
                            '1.5 km from your location',
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Text('🚨', style: TextStyle(fontSize: 13)),
                          const SizedBox(width: 6),
                          Text(
                            'Severity: ${alert.severity >= 4 ? 'High' : (alert.severity >= 2 ? 'Medium' : 'Low')}',
                            style: const TextStyle(
                              color: Color(0xFF9CA3AF),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Warning box
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7F1D1D).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('⚠️', style: TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          alert.severity >= 4
                              ? '${alert.description}. Avoid low-lying areas and flooded roads.'
                              : 'Follow official safety guidelines.',
                          style: const TextStyle(
                            color: Color(0xFFFCA5A5),
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: onDismiss,
                          child: const Center(
                            child: Text(
                              'Dismiss',
                              style: TextStyle(
                                color: Color(0xFF60A5FA),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 0.5,
                        height: 20,
                        color: Colors.white.withValues(alpha: 0.15),
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: onViewDetails,
                          child: const Center(
                            child: Text(
                              'View Details',
                              style: TextStyle(
                                color: Color(0xFF60A5FA),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
