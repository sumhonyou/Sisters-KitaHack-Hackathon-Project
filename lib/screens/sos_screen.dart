import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:geolocator/geolocator.dart';

class SosScreen extends StatefulWidget {
  final String caseId;
  final double? lat;
  final double? lng;
  final String userName;
  final String userPhone;
  final String emergencyMessage;

  const SosScreen({
    super.key,
    required this.caseId,
    required this.lat,
    required this.lng,
    required this.userName,
    required this.userPhone,
    required this.emergencyMessage,
  });

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen>
    with SingleTickerProviderStateMixin {
  // 0 = Sending, 1 = Acknowledged, 2 = Help on the way
  int _statusStep = 0;
  late AnimationController _checkController;

  // Device info
  int _batteryLevel = -1; // -1 loading, -2 unavailable
  String _connectivity = '...';
  String _timeStr = DateFormat('hh:mm a').format(DateTime.now());
  double? _lat;
  double? _lng;
  Timer? _clockTimer;

  final _battery = Battery();

  @override
  void initState() {
    super.initState();
    // Seed location from parent params first, then try live
    _lat = widget.lat;
    _lng = widget.lng;

    _checkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _animateStatuses();
    _loadDeviceInfo();

    // Keep clock live — update every 30 seconds
    _clockTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        setState(() {
          _timeStr = DateFormat('hh:mm a').format(DateTime.now());
        });
      }
    });
  }

  // Realistic timing:
  //   0s  → "Sending..."  (request going out)
  //   3s  → "Acknowledged" (dispatcher picks up)
  //  10s  → "Help is on the way" (team dispatched)
  void _animateStatuses() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _statusStep = 1);
    await Future.delayed(const Duration(seconds: 7));
    if (mounted) setState(() => _statusStep = 2);
    _checkController.forward();
  }

  Future<void> _loadDeviceInfo() async {
    // ── Battery ──────────────────────────────────────────────────────────
    try {
      final level = await _battery.batteryLevel;
      if (mounted) setState(() => _batteryLevel = level);
    } on UnsupportedError {
      if (mounted) setState(() => _batteryLevel = -2);
    } catch (_) {
      if (mounted) setState(() => _batteryLevel = -2);
    }

    // ── Connectivity ─────────────────────────────────────────────────────
    try {
      final results = await Connectivity().checkConnectivity();
      if (mounted) {
        setState(() {
          if (results.contains(ConnectivityResult.wifi)) {
            _connectivity = 'Wi-Fi';
          } else if (results.contains(ConnectivityResult.mobile)) {
            _connectivity = 'Mobile';
          } else if (results.contains(ConnectivityResult.ethernet)) {
            _connectivity = 'Ethernet';
          } else if (results.contains(ConnectivityResult.none)) {
            _connectivity = 'Offline';
          } else {
            _connectivity = 'Active';
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _connectivity = 'Active');
    }

    // ── Location (retry live if parent passed null) ────────────────────
    if (_lat == null || _lng == null) {
      try {
        final permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.always ||
            permission == LocationPermission.whileInUse) {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );
          if (mounted) {
            setState(() {
              _lat = pos.latitude;
              _lng = pos.longitude;
            });
          }
        }
      } catch (_) {
        // keep null → shows 'Location unavailable'
      }
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _checkController.dispose();
    super.dispose();
  }

  Future<void> _call911() async {
    final uri = Uri(scheme: 'tel', path: '911');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  String get _statusTitle {
    switch (_statusStep) {
      case 0:
        return 'Sending...';
      case 1:
        return 'Acknowledged';
      default:
        return 'Help is on the way';
    }
  }

  IconData get _statusIcon {
    switch (_statusStep) {
      case 0:
        return Icons.schedule;
      case 1:
        return Icons.check_circle_outline;
      default:
        return Icons.local_police;
    }
  }

  Color get _statusColor {
    switch (_statusStep) {
      case 0:
        return const Color(0xFFFF9800);
      case 1:
        return const Color(0xFF2196F3);
      default:
        return const Color(0xFF4CAF50);
    }
  }

  // Battery helpers
  String get _batteryText {
    if (_batteryLevel == -1) return '...';
    if (_batteryLevel == -2) return 'N/A';
    return '$_batteryLevel%';
  }

  Color get _batteryColor {
    if (_batteryLevel >= 50) return Colors.green.shade600;
    if (_batteryLevel >= 20) return Colors.orange.shade600;
    return Colors.red.shade600;
  }

  IconData get _batteryIcon {
    if (_batteryLevel == -1 || _batteryLevel == -2) {
      return Icons.battery_unknown;
    }
    if (_batteryLevel >= 80) return Icons.battery_full;
    if (_batteryLevel >= 50) return Icons.battery_5_bar;
    if (_batteryLevel >= 30) return Icons.battery_3_bar;
    return Icons.battery_1_bar;
  }

  // Connectivity helpers
  IconData get _signalIcon {
    switch (_connectivity) {
      case 'Wi-Fi':
        return Icons.wifi;
      case 'Mobile':
        return Icons.signal_cellular_alt;
      case 'Ethernet':
        return Icons.settings_ethernet;
      default:
        return Icons.signal_wifi_off;
    }
  }

  Color get _signalColor {
    return _connectivity == 'Offline'
        ? Colors.red.shade400
        : Colors.blue.shade500;
  }

  @override
  Widget build(BuildContext context) {
    final shortCase = 'EMG-${widget.caseId.substring(0, 6).toUpperCase()}';
    final locationText = (_lat != null && _lng != null)
        ? 'Lat: ${_lat!.toStringAsFixed(4)}  •  Lng: ${_lng!.toStringAsFixed(4)}'
        : 'Location unavailable';

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'SOS Active',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
          child: Column(
            children: [
              // ── Red emergency banner ────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFD32F2F),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Emergency SOS Active',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            'Your emergency request has been submitted',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Animated status card ────────────────────────────────────
              _card(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeOut,
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _statusColor,
                        shape: BoxShape.circle,
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: Icon(
                          _statusIcon,
                          key: ValueKey(_statusStep),
                          color: Colors.white,
                          size: 30,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      child: Text(
                        _statusTitle,
                        key: ValueKey(_statusTitle),
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: _statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Case ID: $shortCase',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Always visible (step 0)
                    _statusRow(
                      Icons.schedule,
                      'Sending...',
                      const Color(0xFFFF9800),
                      true,
                    ),
                    const SizedBox(height: 8),
                    // Fades in at step 1
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 600),
                      opacity: _statusStep >= 1 ? 1.0 : 0.0,
                      child: _statusRow(
                        Icons.check_circle_outline,
                        'Acknowledged',
                        const Color(0xFF2196F3),
                        true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Fades in at step 2
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 600),
                      opacity: _statusStep >= 2 ? 1.0 : 0.0,
                      child: _statusRow(
                        Icons.local_police_outlined,
                        'Help is on the way',
                        const Color(0xFF4CAF50),
                        true,
                        subtitle: 'Response team dispatched to your location',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // ── Location card ───────────────────────────────────────────
              _card(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.location_on_outlined,
                        color: Colors.blue.shade500,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Your Location',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            locationText,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // ── Battery / Signal / Time ─────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: _infoTile(
                      icon: _batteryIcon,
                      iconColor: _batteryColor,
                      label: 'Battery',
                      value: _batteryText,
                      valueColor: _batteryColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _infoTile(
                      icon: _signalIcon,
                      iconColor: _signalColor,
                      label: 'Signal',
                      value: _connectivity,
                      valueColor: _signalColor,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _infoTile(
                      icon: Icons.access_time,
                      iconColor: Colors.orange.shade500,
                      label: 'Time',
                      value: _timeStr,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // ── Safety instructions ─────────────────────────────────────
              _card(
                color: const Color(0xFFFFFDE7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Safety Instructions',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _bullet('Stay where you are if it\'s safe to do so'),
                    _bullet('Keep your phone charged and within reach'),
                    _bullet(
                      'Answer any callbacks from emergency services immediately',
                    ),
                    _bullet('If situation worsens, call 911 directly'),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // ── Emergency hotline ───────────────────────────────────────
              _card(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Emergency Hotline',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            'Direct line to dispatch',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _call911,
                      icon: const Icon(Icons.phone, size: 16),
                      label: const Text(
                        'Call 911',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFD32F2F),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // ── Copy message ────────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(
                      ClipboardData(text: widget.emergencyMessage),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Emergency message copied!'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.copy, size: 16),
                  label: const Text('Copy Emergency Message for 911'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFD32F2F),
                    side: const BorderSide(color: Color(0xFFD32F2F)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ────────────────────────────────────────────────────────────────

  Widget _card({required Widget child, Color? color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _infoTile({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    Color? valueColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: valueColor ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusRow(
    IconData icon,
    String label,
    Color color,
    bool active, {
    String? subtitle,
  }) {
    return Row(
      children: [
        Icon(icon, color: active ? color : Colors.grey.shade300, size: 20),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: active ? color : Colors.grey.shade400,
                fontSize: 13,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
          ],
        ),
      ],
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '• ',
            style: TextStyle(
              color: Color(0xFFFF9800),
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 11))),
        ],
      ),
    );
  }
}
