import 'dart:async';
import 'package:flutter/material.dart';
import '../models/alert_model.dart';
import '../models/disaster_model.dart';
import '../services/firestore_service.dart';
import '../pages/alert_detail_page.dart';

/// A full-screen overlay widget that shows a disaster alert banner
/// sliding down from the top when a high-severity alert is active.
///
/// Wrap your app content with this widget:
/// ```dart
/// DisasterBannerOverlay(
///   child: YourContent(),
/// )
/// ```
class DisasterBannerOverlay extends StatefulWidget {
  final Widget child;
  final bool forceShow;
  final VoidCallback? onDismiss;

  const DisasterBannerOverlay({
    super.key,
    required this.child,
    this.forceShow = false,
    this.onDismiss,
  });

  @override
  State<DisasterBannerOverlay> createState() => _DisasterBannerOverlayState();
}

class _DisasterBannerOverlayState extends State<DisasterBannerOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;
  Timer? _autoDismissTimer;
  bool _dismissed = false;
  final FirestoreService _fs = FirestoreService();

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, -1), end: Offset.zero).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );
  }

  void _checkAndShowBanner(DisasterModel? alert) {
    if ((alert != null || widget.forceShow) && !_dismissed) {
      if (_slideController.status == AnimationStatus.dismissed) {
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted && !_dismissed) {
            _slideController.forward();
            _startAutoDismiss();
          }
        });
      }
    } else if (alert == null &&
        !widget.forceShow &&
        _slideController.status == AnimationStatus.completed) {
      _dismiss();
    }
  }

  @override
  void didUpdateWidget(covariant DisasterBannerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.forceShow && !oldWidget.forceShow) {
      _dismissed = false;
      _slideController.forward();
      _startAutoDismiss();
    }
  }

  void _startAutoDismiss() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 8), () {
      _dismiss();
    });
  }

  void _dismiss() {
    if (!_dismissed && mounted) {
      _dismissed = true;
      _autoDismissTimer?.cancel();
      _slideController.reverse();
      widget.onDismiss?.call();
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DisasterModel>>(
      stream: _fs.disastersStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) return widget.child;
        if (snapshot.connectionState == ConnectionState.waiting)
          return widget.child;

        final disasters = snapshot.data ?? [];
        DisasterModel? activeHighDisaster;
        try {
          activeHighDisaster = disasters.firstWhere(
            (d) =>
                d.status == 'active' &&
                (d.severity == 'high' || d.severity == 'critical'),
          );
        } catch (_) {
          activeHighDisaster = null;
        }

        // Trigger animation logic
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _checkAndShowBanner(activeHighDisaster);
        });

        if (activeHighDisaster == null && !widget.forceShow) {
          return widget.child;
        }

        // Create a temporary AlertModel for the banner UI
        final alert = AlertModel(
          id: activeHighDisaster?.id ?? 'temp',
          title: activeHighDisaster?.title ?? 'Emergency Alert',
          description: activeHighDisaster?.description ?? '',
          type: activeHighDisaster?.type ?? 'warning',
          severity: activeHighDisaster?.severity ?? 'high',
          shortAdvice: activeHighDisaster?.description ?? '',
          locationName: 'Local Area',
          distanceKm: 1.5,
          issuedAt: activeHighDisaster?.createdAt ?? DateTime.now(),
          lat: activeHighDisaster?.center?.latitude ?? 0,
          lng: activeHighDisaster?.center?.longitude ?? 0,
          recommendedActions: const [],
          nearbyShelters: const [],
          officialSource: 'CityGuard',
        );

        return Stack(
          children: [
            widget.child,

            // Banner
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SlideTransition(
                position: _slideAnimation,
                child: _BannerCard(
                  alert: alert,
                  onTap: () {
                    _dismiss();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AlertDetailPage(alert: alert),
                      ),
                    );
                  },
                  onClose: _dismiss,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner card widget
// ─────────────────────────────────────────────────────────────────────────────

class _BannerCard extends StatelessWidget {
  final AlertModel alert;
  final VoidCallback onTap;
  final VoidCallback onClose;

  const _BannerCard({
    required this.alert,
    required this.onTap,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return GestureDetector(
      onTap: onTap,
      // Swipe up to dismiss
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) < -200) {
          onClose();
        }
      },
      child: Container(
        margin: EdgeInsets.only(top: topPadding + 4, left: 12, right: 12),
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 14),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.35),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Top row: icon + app name + "now" + close
            Row(
              children: [
                // App icon
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
                const SizedBox(width: 8),
                // App name + title
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
                        '${alert.title} – ${alert.severity[0].toUpperCase()}${alert.severity.substring(1)}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                // "now" label
                const Padding(
                  padding: EdgeInsets.only(right: 4),
                  child: Text(
                    'now',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
                  ),
                ),
                // Close button
                GestureDetector(
                  onTap: onClose,
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(
                      Icons.close,
                      color: Color(0xFF9CA3AF),
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Short advice text
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  alert.shortAdvice.length > 60
                      ? 'Avoid low-lying areas. Seek higher ground immediately.'
                      : alert.shortAdvice,
                  style: const TextStyle(
                    color: Color(0xFFD1D5DB),
                    fontSize: 13,
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
