import 'package:flutter/material.dart';
import 'home_page.dart';
import 'map_page.dart';
import 'community_page.dart';
import 'alerts_page.dart';
import 'cases_page.dart';
import 'phone_home_screen.dart';
import '../widgets/demo_navigation_bar.dart';
import '../widgets/disaster_banner_overlay.dart';
import 'alert_detail_page.dart';
import '../models/alert_model.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  String _demoView = 'Home';
  bool _showBanner = false;
  bool _isPhoneHomeScreen = false;

  void _navigateTo(int index) {
    setState(() {
      _currentIndex = index;
      _demoView = 'Home';
      _isPhoneHomeScreen = false;
    });
  }

  void _handleDemoViewChange(String view) {
    setState(() {
      _demoView = view;
      _isPhoneHomeScreen = (view == 'Phone Home Screen');

      if (view == 'Banner Popup' || view == 'Phone Home Screen') {
        _showBanner = true;
      } else {
        _showBanner = false;
      }

      if (view == 'Alerts List') {
        _currentIndex = 3;
      } else if (view == 'Home') {
        _currentIndex = 0;
      }
    });

    if (view == 'Alert Detail') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AlertDetailPage(
            alert: mockAlerts.firstWhere((a) => a.severity == 'high'),
          ),
        ),
      ).then((_) {
        setState(() => _demoView = 'Home');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          DemoNavigationBar(
            currentView: _demoView,
            onViewChanged: _handleDemoViewChange,
          ),
          Expanded(
            child: DisasterBannerOverlay(
              forceShow: _showBanner,
              onDismiss: () => setState(() => _showBanner = false),
              child: _isPhoneHomeScreen
                  ? const PhoneHomeScreen()
                  : IndexedStack(
                      index: _currentIndex,
                      children: [
                        HomePage(
                          onNavigateToMap: () => _navigateTo(1),
                          onNavigateToAlerts: () => _navigateTo(3),
                        ),
                        const MapPage(),
                        const CommunityPage(),
                        const AlertsPage(),
                        const CasesPage(),
                      ],
                    ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _isPhoneHomeScreen
          ? null
          : BottomNavigationBar(
              currentIndex: _currentIndex,
              onTap: _navigateTo,
              type: BottomNavigationBarType.fixed,
              backgroundColor: Colors.white,
              selectedItemColor: const Color(0xFF1A56DB),
              unselectedItemColor: const Color(0xFF9CA3AF),
              selectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 11,
              ),
              elevation: 12,
              items: const [
                BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.map_outlined),
                  activeIcon: Icon(Icons.map),
                  label: 'Map',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.forum_outlined),
                  activeIcon: Icon(Icons.forum),
                  label: 'Community',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.notifications_outlined),
                  activeIcon: Icon(Icons.notifications),
                  label: 'Alerts',
                ),
                BottomNavigationBarItem(
                  icon: Icon(Icons.list_alt_outlined),
                  activeIcon: Icon(Icons.list_alt),
                  label: 'Cases',
                ),
              ],
            ),
    );
  }
}
