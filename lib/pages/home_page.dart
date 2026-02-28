import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/disaster_model.dart';
import '../models/shelter_model.dart';
import '../services/firestore_service.dart';
import 'alert_detail_page.dart';
import 'profile_page.dart';
import 'report_category_screen.dart';
import 'sos_screen.dart';
import 'safety_route_navigation.dart';
import '../services/notification_service.dart';

class HomePage extends StatefulWidget {
  final VoidCallback? onNavigateToMap;
  const HomePage({super.key, this.onNavigateToMap});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final PageController _pageCtrl = PageController(
    viewportFraction: 0.88,
    initialPage: 0,
  );
  int _currentAlertPage = 0;
  bool _isSafe = false;
  final FirestoreService _fs = FirestoreService();

  // ── Country selector ──────────────────────────────────────────────────────
  String _selectedCountry = 'Malaysia';
  static const List<Map<String, String>> _countries = [
    {'name': 'Malaysia', 'flag': '\u{1F1F2}\u{1F1FE}'},
    {'name': 'Singapore', 'flag': '\u{1F1F8}\u{1F1EC}'},
    {'name': 'Indonesia', 'flag': '\u{1F1EE}\u{1F1E9}'},
    {'name': 'Thailand', 'flag': '\u{1F1F9}\u{1F1ED}'},
    {'name': 'Philippines', 'flag': '\u{1F1F5}\u{1F1ED}'},
    {'name': 'Vietnam', 'flag': '\u{1F1FB}\u{1F1F3}'},
    {'name': 'Myanmar', 'flag': '\u{1F1F2}\u{1F1F2}'},
    {'name': 'Cambodia', 'flag': '\u{1F1F0}\u{1F1ED}'},
    {'name': 'Brunei', 'flag': '\u{1F1E7}\u{1F1F3}'},
    {'name': 'Laos', 'flag': '\u{1F1F1}\u{1F1E6}'},
  ];

  // ── Notifications ─────────────────────────────────────────────────────────
  late final List<Map<String, dynamic>> _notifications = [
    {
      'icon': Icons.warning_amber_rounded,
      'color': const Color(0xFFEF4444),
      'title': 'Flood Advisory \u2014 Klang Valley',
      'body':
          'Water levels rising. Residents in low-lying areas advised to evacuate.',
      'time': '2 min ago',
      'read': false,
    },
    {
      'icon': Icons.home_outlined,
      'color': const Color(0xFF1A56DB),
      'title': 'Shelter Opened \u2014 Wangsa Maju',
      'body':
          'Pusat Komuniti Wangsa Maju is now accepting flood victims. Capacity: 300.',
      'time': '15 min ago',
      'read': false,
    },
    {
      'icon': Icons.health_and_safety_outlined,
      'color': const Color(0xFF22C55E),
      'title': 'Safety Check-In Reminder',
      'body':
          'Let your community know you are safe. Tap "I\'m Safe" on the home screen.',
      'time': '1 hr ago',
      'read': false,
    },
    {
      'icon': Icons.directions_car_outlined,
      'color': const Color(0xFFF59E0B),
      'title': 'Road Closure \u2014 Jalan Ipoh Underpass',
      'body':
          'Underpass fully submerged. Use Jalan Kuching as alternative route.',
      'time': '2 hr ago',
      'read': true,
    },
    {
      'icon': Icons.campaign_outlined,
      'color': const Color(0xFF7C3AED),
      'title': 'Community Post \u2014 Volunteers Needed',
      'body': 'Boat rescue at Sg Besi. Meet at Petronas Sg Besi at 4PM.',
      'time': '3 hr ago',
      'read': true,
    },
    {
      'icon': Icons.build_outlined,
      'color': const Color(0xFF0891B2),
      'title': 'Infrastructure Update',
      'body':
          'Pump station on Jalan Pahang now operational. Water receding by 11PM.',
      'time': '5 hr ago',
      'read': true,
    },
  ];

  // ── Notification Logic ───────────────────────────────────────────────────
  final NotificationService _notificationService = NotificationService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initNotifications();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _triggerSystemNotifications();
    }
  }

  Future<void> _initNotifications() async {
    await _notificationService.init();
  }

  void _triggerSystemNotifications() {
    for (int i = 0; i < _notifications.length; i++) {
      final n = _notifications[i];
      if (n['read'] == false) {
        _notificationService.showNotification(
          id: i,
          title: n['title'],
          body: n['body'],
        );
      }
    }
  }

  // ── Colors ──────────────────────────────────────────────────────────────────
  static const _blue = Color(0xFF1A56DB);
  static const _bgGray = Color(0xFFF9FAFB);

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageCtrl.dispose();
    super.dispose();
  }

  IconData _disasterIcon(String category) {
    switch (category) {
      case 'Flood':
        return Icons.water_drop;
      case 'Fire':
        return Icons.local_fire_department;
      case 'Earthquake':
        return Icons.vibration;
      case 'Storm':
        return Icons.cyclone;
      case 'Tsunami':
        return Icons.waves;
      case 'Landslide':
        return Icons.landscape;
      default:
        return Icons.warning_amber_rounded;
    }
  }

  Color _severityColor(String s) {
    switch (s.toLowerCase()) {
      case 'critical':
        return const Color(0xFFEF4444);
      case 'high':
        return const Color(0xFFF97316);
      case 'medium':
        return const Color(0xFFF59E0B);
      case 'low':
        return const Color(0xFF22C55E);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _actionLabel(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return 'Evacuate';
      case 'high':
        return 'Stay Alert';
      case 'medium':
        return 'Monitor';
      default:
        return 'Inform';
    }
  }

  String _timeAgo(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  Future<void> _callNumber(String number) async {
    final uri = Uri(scheme: 'tel', path: number);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgGray,
      body: StreamBuilder<List<DisasterModel>>(
        stream: _fs.disastersStream(),
        builder: (ctx, disasterSnap) {
          return StreamBuilder<List<ShelterModel>>(
            stream: _fs.sheltersStream(),
            builder: (ctx, shelterSnap) {
              final disasters = disasterSnap.data ?? [];
              final shelters = shelterSnap.data ?? [];
              final activeDisasters = disasters
                  .where((d) => d.status == 'active')
                  .toList();
              final openShelters = shelters
                  .where((s) => s.status == 'open')
                  .toList();
              final totalAffected = disasters.fold<int>(
                0,
                (sum, d) => sum + (d.affectedAreaIds.length * 850),
              );

              return Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildAlertsSection(activeDisasters),
                          const SizedBox(height: 16),
                          _buildSafetyCheckIn(),
                          const SizedBox(height: 16),
                          _buildQuickStats(
                            activeDisasters.length,
                            openShelters.length,
                            totalAffected,
                          ),
                          const SizedBox(height: 16),
                          _buildCategories(context, shelters),
                          const SizedBox(height: 16),
                          _buildPopularServices(),
                          const SizedBox(height: 16),
                          _buildEmergencyContacts(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ── Country Picker ────────────────────────────────────────────────────────
  void _showCountryPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Select Country',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _countries.length,
                itemBuilder: (_, i) {
                  final c = _countries[i];
                  final isSelected = c['name'] == _selectedCountry;
                  return ListTile(
                    leading: Text(
                      c['flag']!,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(
                      c['name']!,
                      style: TextStyle(
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: isSelected
                            ? const Color(0xFF1A56DB)
                            : const Color(0xFF111827),
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check, color: Color(0xFF1A56DB))
                        : null,
                    onTap: () {
                      setState(() => _selectedCountry = c['name']!);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ── Notifications Panel ───────────────────────────────────────────────────
  void _showNotificationsPanel() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setInner) => DraggableScrollableSheet(
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          minChildSize: 0.4,
          builder: (_, scrollCtrl) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFB),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
                  child: Row(
                    children: [
                      const Text(
                        'Notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            for (final n in _notifications) {
                              n['read'] = true;
                            }
                          });
                          _notificationService.cancelAll();
                          setInner(() {});
                        },
                        child: const Text(
                          'Mark all read',
                          style: TextStyle(
                            color: Color(0xFF1A56DB),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                // Notification list
                Expanded(
                  child: ListView.separated(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _notifications.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, indent: 72),
                    itemBuilder: (_, i) {
                      final n = _notifications[i];
                      final isRead = n['read'] as bool;
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _notifications[i]['read'] = true;
                            _notificationService.cancelNotification(i);
                          });
                          setInner(() {});
                        },
                        child: Container(
                          color: isRead
                              ? Colors.transparent
                              : const Color(0xFFEFF6FF),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Icon circle
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: (n['color'] as Color).withValues(
                                    alpha: 0.12,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  n['icon'] as IconData,
                                  color: n['color'] as Color,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Text
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            n['title'] as String,
                                            style: TextStyle(
                                              fontWeight: isRead
                                                  ? FontWeight.w500
                                                  : FontWeight.bold,
                                              fontSize: 14,
                                              color: const Color(0xFF111827),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          n['time'] as String,
                                          style: const TextStyle(
                                            color: Color(0xFF9CA3AF),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      n['body'] as String,
                                      style: const TextStyle(
                                        color: Color(0xFF6B7280),
                                        fontSize: 13,
                                        height: 1.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isRead)
                                Container(
                                  margin: const EdgeInsets.only(
                                    top: 6,
                                    left: 8,
                                  ),
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1A56DB),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).then((_) {
      // Refresh the red dot on the bell after closing panel
      setState(() {});
    });
  }

  // ── Header ───────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return SafeArea(
      bottom: false,
      child: Container(
        color: _blue,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            // Location row + bell
            Row(
              children: [
                // Country selector button
                GestureDetector(
                  onTap: _showCountryPicker,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedCountry,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 20,
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // Profile avatar icon
                GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  ),
                  child: Container(
                    width: 34,
                    height: 34,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
                // Notification bell
                Stack(
                  children: [
                    IconButton(
                      onPressed: _showNotificationsPanel,
                      icon: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    if (_notifications.any((n) => n['read'] == false))
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: Color(0xFFEF4444),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Search bar
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const TextField(
                      decoration: InputDecoration(
                        hintText: 'Search emergency info...',
                        hintStyle: TextStyle(
                          color: Color(0xFF9CA3AF),
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Color(0xFF9CA3AF),
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.tune, color: Colors.white, size: 22),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Alerts Section ───────────────────────────────────────────────────────────

  Widget _buildAlertsSection(List<DisasterModel> disasters) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.notifications_active_outlined,
                    color: _blue,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Alerts For You',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => widget.onNavigateToMap?.call(),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'See All',
                  style: TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (disasters.isEmpty)
          _buildEmptyAlerts()
        else ...[
          SizedBox(
            height: 210,
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                },
              ),
              child: PageView.builder(
                controller: _pageCtrl,
                physics: const BouncingScrollPhysics(),
                itemCount: disasters.length,
                onPageChanged: (i) => setState(() => _currentAlertPage = i),
                itemBuilder: (_, i) => _buildAlertCard(disasters[i]),
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (disasters.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 8,
                  activeTrackColor: _blue,
                  inactiveTrackColor: const Color(0xFFD1D5DB),
                  thumbColor: _blue,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 10,
                    elevation: 4,
                  ),
                  overlayColor: _blue.withValues(alpha: 0.12),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 20,
                  ),
                  trackShape: const RoundedRectSliderTrackShape(),
                ),
                child: Slider(
                  value: _currentAlertPage.toDouble().clamp(
                    0.0,
                    (disasters.length - 1).toDouble(),
                  ),
                  min: 0,
                  max: (disasters.length - 1).toDouble(),
                  divisions: disasters.length - 1,
                  onChanged: (value) {
                    _pageCtrl.animateToPage(
                      value.toInt(),
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  },
                ),
              ),
            ),
          // Location + status row for current card
          if (disasters.isNotEmpty && _currentAlertPage < disasters.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: Color(0xFF6B7280),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    disasters[_currentAlertPage].affectedAreaIds
                        .join(', ')
                        .replaceAll('area-', '')
                        .toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.circle, size: 8, color: Color(0xFF22C55E)),
                  const SizedBox(width: 4),
                  Text(
                    disasters[_currentAlertPage].status.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildEmptyAlerts() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      height: 160,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Color(0xFF22C55E),
              size: 36,
            ),
            SizedBox(height: 8),
            Text(
              'No active alerts in your area',
              style: TextStyle(
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertCard(DisasterModel d) {
    final action = _actionLabel(d.severity);
    final sevColor = _severityColor(d.severity);

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlertDetailPage(disasterId: d.id),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          image: DecorationImage(
            image: NetworkImage(
              d.imageUrl ?? _fallbackImageUrl(d.category, d.id),
            ),
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(
                alpha: 0.2,
              ), // Lightened for better visibility
              BlendMode.darken,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Gradient Overlay for text readability
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
            // Background icon
            Positioned(
              right: -20,
              bottom: -20,
              child: Icon(
                _disasterIcon(d.category),
                size: 120,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top badges row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Limited time!',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: sevColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          d.severity.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  // Title
                  Text(
                    d.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 10),
                  // Action label + time
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: sevColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          action,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(d.createdAt),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 11,
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

  String _fallbackImageUrl(String category, String id) {
    // Generate a stable random index based on the ID string
    int hash = 0;
    for (int i = 0; i < id.length; i++) {
      hash = id.codeUnitAt(i) + ((hash << 5) - hash);
    }

    final int index = hash.abs();

    switch (category) {
      case 'Flood':
        final images = [
          'https://images.unsplash.com/photo-1547683908-21aa538c716b?q=80&w=800&auto=format&fit=crop', // River flood
          'https://images.unsplash.com/photo-1468413922365-e3766a17da9e?q=80&w=800&auto=format&fit=crop', // Deep water
          'https://images.unsplash.com/photo-1511055853222-6d35505d9884?q=80&w=800&auto=format&fit=crop', // Flooded street
          'https://images.unsplash.com/photo-1545048702-793e24bb1d1f?q=80&w=800&auto=format&fit=crop', // Aerial flood
          'https://images.unsplash.com/photo-1590098455532-613d9406593a?q=80&w=800&auto=format&fit=crop', // Submerged car
          'https://images.unsplash.com/photo-1574492405051-248981452441?q=80&w=800&auto=format&fit=crop', // Heavy rain on road
          'https://images.unsplash.com/photo-1605723511530-dc1e98829871?q=80&w=800&auto=format&fit=crop', // Water rescue
          'https://images.unsplash.com/photo-1579483017726-16e76e5d85e7?q=80&w=800&auto=format&fit=crop', // Residential flooding
        ];
        return images[index % images.length];
      case 'Fire':
        final images = [
          'https://images.unsplash.com/photo-1516533075015-a3838414c3ca?q=80&w=800&auto=format&fit=crop', // Forest fire
          'https://images.unsplash.com/photo-1524334228333-0f6db392f8a1?q=80&w=800&auto=format&fit=crop', // Building fire
          'https://images.unsplash.com/photo-1506755594442-54264846f59d?q=80&w=800&auto=format&fit=crop', // Intense flames
          'https://images.unsplash.com/photo-1580516091765-36177215f16d?q=80&w=800&auto=format&fit=crop', // Night fire
          'https://images.unsplash.com/photo-1599427303058-f173243f65b6?q=80&w=800&auto=format&fit=crop', // Smoke
          'https://images.unsplash.com/photo-1501618669935-18b6ecb13d6d?q=80&w=800&auto=format&fit=crop', // Firefighter
          'https://images.unsplash.com/photo-1544033339-da5462cfdd31?q=80&w=800&auto=format&fit=crop', // Forest smoke
          'https://images.unsplash.com/photo-1621252328704-ccf5be02ed3e?q=80&w=800&auto=format&fit=crop', // Ember
        ];
        return images[index % images.length];
      case 'Storm':
        final images = [
          'https://images.unsplash.com/photo-1562155847-c05f7386b204?q=80&w=800&auto=format&fit=crop', // Lightning
          'https://images.unsplash.com/photo-1534274988757-a28bf1f539cf?q=80&w=800&auto=format&fit=crop', // Dark clouds
          'https://images.unsplash.com/photo-1511283919504-ca05ee700099?q=80&w=800&auto=format&fit=crop', // Heavy rain
          'https://images.unsplash.com/photo-1504639725590-34d0984388bd?q=80&w=800&auto=format&fit=crop', // Stormy sky
          'https://images.unsplash.com/photo-1533062604082-7798383e5860?q=80&w=800&auto=format&fit=crop', // Hurricane-like
          'https://images.unsplash.com/photo-1516912481808-3b043c1aad95?q=80&w=800&auto=format&fit=crop', // Rain on window
          'https://images.unsplash.com/photo-1428592953211-077101b2021b?q=80&w=800&auto=format&fit=crop', // Dramatic clouds
          'https://images.unsplash.com/photo-1463171359979-aa440628885c?q=80&w=800&auto=format&fit=crop', // Wet street
        ];
        return images[index % images.length];
      case 'Earthquake':
        final images = [
          'https://images.unsplash.com/photo-1541093113199-a2e9d264421b?q=80&w=800&auto=format&fit=crop', // Rubble
          'https://images.unsplash.com/photo-1582213707521-af9c1e21950d?q=80&w=800&auto=format&fit=crop', // Cracked road
          'https://images.unsplash.com/photo-1521747116042-5a810fda9664?q=80&w=800&auto=format&fit=crop', // Debris
          'https://images.unsplash.com/photo-1454496522488-7a8e488e8606?q=80&w=800&auto=format&fit=crop', // Mountains
          'https://images.unsplash.com/photo-1578351006275-100207bf1aa3?q=80&w=800&auto=format&fit=crop', // City damage
          'https://images.unsplash.com/photo-1585822765324-ee545524316c?q=80&w=800&auto=format&fit=crop', // Destruction
          'https://images.unsplash.com/photo-1621252179027-94459d278660?q=80&w=800&auto=format&fit=crop', // Cracked earth
        ];
        return images[index % images.length];
      case 'Tsunami':
        final images = [
          'https://images.unsplash.com/photo-1524231757912-21f4fe3a7200?q=80&w=800&auto=format&fit=crop', // Big wave
          'https://images.unsplash.com/photo-1502675135487-e75f0c0907ca?q=80&w=800&auto=format&fit=crop', // Coastline
          'https://images.unsplash.com/photo-1518837697219-45260031d48b?q=80&w=800&auto=format&fit=crop', // Deep ocean
          'https://images.unsplash.com/photo-1455588722283-9366453f637b?q=80&w=800&auto=format&fit=crop', // Powerful water
          'https://images.unsplash.com/photo-1545048702-793e24bb1d1f?q=80&w=800&auto=format&fit=crop', // Flooded coast
          'https://images.unsplash.com/photo-1594191344933-22879010355f?q=80&w=800&auto=format&fit=crop', // Stormy sea
          'https://images.unsplash.com/photo-1533062604082-7798383e5860?q=80&w=800&auto=format&fit=crop', // Giant surge
        ];
        return images[index % images.length];
      case 'Landslide':
        final images = [
          'https://images.unsplash.com/photo-1541183011993-3760443a5099?q=80&w=800&auto=format&fit=crop', // Muddy hill
          'https://images.unsplash.com/photo-1546271876-af6caec1fa95?q=80&w=800&auto=format&fit=crop', // Rockfall
          'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?q=80&w=800&auto=format&fit=crop', // Mountain cliff
          'https://images.unsplash.com/photo-1465146344425-f00d5f5c8f07?q=80&w=800&auto=format&fit=crop', // Dense forest slopes
          'https://images.unsplash.com/photo-1541183011303-adfa2ca954a0?q=80&w=800&auto=format&fit=crop', // Eroded soil
        ];
        return images[index % images.length];
      default:
        return 'https://images.unsplash.com/photo-1464822759023-fed622ff2c3b?q=80&w=800&auto=format&fit=crop';
    }
  }

  // ── Safety Check-In ──────────────────────────────────────────────────────────

  Widget _buildSafetyCheckIn() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _isSafe
              ? const Color(0xFF22C55E).withValues(alpha: 0.1)
              : const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isSafe ? const Color(0xFF22C55E) : const Color(0xFFBBF7D0),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _isSafe
                    ? const Color(0xFF22C55E)
                    : const Color(0xFF22C55E).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isSafe ? Icons.check : Icons.people_alt_outlined,
                color: _isSafe ? Colors.white : const Color(0xFF22C55E),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isSafe ? 'You\'re marked safe' : 'Safety Check-In',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isSafe
                        ? 'Your community has been notified'
                        : 'Let your community know you\'re safe',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () {
                setState(() => _isSafe = !_isSafe);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _isSafe
                          ? '✅ Safety status shared with your community'
                          : 'Safety check-in cleared',
                    ),
                    backgroundColor: _isSafe
                        ? const Color(0xFF22C55E)
                        : Colors.grey,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _isSafe
                      ? const Color(0xFF22C55E)
                      : const Color(0xFF16A34A),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Text(
                  _isSafe ? '✓ Safe' : "I'm Safe",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Quick Stats ───────────────────────────────────────────────────────────────

  Widget _buildQuickStats(
    int activeDisasters,
    int openShelters,
    int totalAffected,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _statChip(
            icon: Icons.warning_amber_rounded,
            value: '$activeDisasters',
            label: 'Active',
            color: const Color(0xFFEF4444),
          ),
          const SizedBox(width: 8),
          _statChip(
            icon: Icons.house,
            value: '$openShelters',
            label: 'Shelters',
            color: const Color(0xFF22C55E),
          ),
          const SizedBox(width: 8),
          _statChip(
            icon: Icons.people,
            value: '${(totalAffected / 1000).toStringAsFixed(1)}K',
            label: 'Affected',
            color: const Color(0xFFF97316),
          ),
        ],
      ),
    );
  }

  Widget _statChip({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: Color(0xFF111827),
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Categories ────────────────────────────────────────────────────────────────

  Widget _buildCategories(BuildContext context, List<ShelterModel> shelters) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Categories',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _LongPressSosButton(
                onTrigger: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const SosScreen())),
              ),
              _categoryButton(
                icon: Icons.edit_document,
                label: 'Report',
                color: const Color(0xFF1A56DB),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ReportCategoryScreen(),
                  ),
                ),
              ),
              _categoryButton(
                icon: Icons.near_me,
                label: 'Shelter',
                color: const Color(0xFF16A34A),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const SafetyRouteNavigationScreen(),
                  ),
                ),
              ),
              _categoryButton(
                icon: Icons.map,
                label: 'Map',
                color: const Color(0xFF7C3AED),
                onTap: () => widget.onNavigateToMap?.call(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _categoryButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),
        ],
      ),
    );
  }

  // ── Popular Services ──────────────────────────────────────────────────────────

  Widget _buildPopularServices() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Popular Services',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              TextButton(
                onPressed: () {},
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    color: _blue,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                _serviceRow(
                  icon: Icons.groups,
                  iconColor: const Color(0xFF1A56DB),
                  title: 'Community Updates',
                  subtitle: 'Connect with 234 members • 45 active now',
                  tags: ['12 new', 'Social'],
                  tagColor: const Color(0xFF1A56DB),
                  rating: '4.9',
                  isLast: false,
                ),
                _serviceRow(
                  icon: Icons.assignment_outlined,
                  iconColor: const Color(0xFF7C3AED),
                  title: 'My Cases',
                  subtitle: 'Track your incident reports and submissions',
                  tags: ['3 active', 'Reports'],
                  tagColor: const Color(0xFF7C3AED),
                  rating: '4.8',
                  isLast: false,
                ),
                _serviceRow(
                  icon: Icons.medical_services_outlined,
                  iconColor: const Color(0xFFEF4444),
                  title: 'First Aid Guides',
                  subtitle: 'Emergency procedures for common disasters',
                  tags: ['Offline', 'Health'],
                  tagColor: const Color(0xFFEF4444),
                  rating: '4.7',
                  isLast: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _serviceRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<String> tags,
    required Color tagColor,
    required String rating,
    required bool isLast,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      children: tags
                          .map(
                            (t) => Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: tagColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                t,
                                style: TextStyle(
                                  color: tagColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ),
              ),
              Column(
                children: [
                  const Icon(Icons.star, color: Color(0xFFF59E0B), size: 14),
                  const SizedBox(height: 2),
                  Text(
                    rating,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: const Color(0xFFE5E7EB), indent: 78),
      ],
    );
  }

  // ── Emergency Contacts ───────────────────────────────────────────────────────

  Widget _buildEmergencyContacts() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Emergency Contacts',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _emergencyContactBtn(
                label: 'Police',
                number: '999',
                icon: Icons.local_police,
                color: const Color(0xFF1A56DB),
              ),
              const SizedBox(width: 8),
              _emergencyContactBtn(
                label: 'Fire',
                number: '994',
                icon: Icons.local_fire_department,
                color: const Color(0xFFEF4444),
              ),
              const SizedBox(width: 8),
              _emergencyContactBtn(
                label: 'Ambulance',
                number: '999',
                icon: Icons.medical_services,
                color: const Color(0xFF22C55E),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emergencyContactBtn({
    required String label,
    required String number,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _callNumber(number),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Color(0xFF374151),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                number,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LongPressSosButton extends StatefulWidget {
  final VoidCallback onTrigger;

  const _LongPressSosButton({required this.onTrigger});

  @override
  State<_LongPressSosButton> createState() => _LongPressSosButtonState();
}

class _LongPressSosButtonState extends State<_LongPressSosButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  bool _isHolding = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _onHoldComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onHoldComplete() {
    if (_isHolding) {
      widget.onTrigger();
      _cancelHold();
    }
  }

  void _startHold() {
    setState(() => _isHolding = true);
    _controller.forward(from: 0);
  }

  void _cancelHold() {
    if (_isHolding) {
      setState(() => _isHolding = false);
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    const color = Color(0xFFEF4444);

    return GestureDetector(
      onTapDown: (_) => _startHold(),
      onTapUp: (_) => _cancelHold(),
      onTapCancel: () => _cancelHold(),
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              '⚠️ Please hold the SOS button for 3 seconds to trigger rescue.',
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              // Border Slide Progress
              if (_isHolding)
                SizedBox(
                  width: 76,
                  height: 76,
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _BorderProgressPainter(
                          progress: _controller.value,
                          color: color,
                        ),
                      );
                    },
                  ),
                ),
              // Button
              AnimatedScale(
                scale: _isHolding ? 1.05 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 12,
              fontWeight: _isHolding ? FontWeight.bold : FontWeight.w500,
              color: _isHolding ? color : const Color(0xFF374151),
            ),
            child: Text(_isHolding ? 'Hold for 3s...' : 'SOS'),
          ),
        ],
      ),
    );
  }
}

class _BorderProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  _BorderProgressPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final backgroundPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(4, 4, size.width - 8, size.height - 8),
      const Radius.circular(22), // Slightly larger radius for the outer border
    );

    canvas.drawRRect(rect, backgroundPaint);

    final path = Path()..addRRect(rect);
    final metrics = path.computeMetrics().first;
    final extractPath = metrics.extractPath(0, metrics.length * progress);

    canvas.drawPath(extractPath, paint);
  }

  @override
  bool shouldRepaint(_BorderProgressPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
