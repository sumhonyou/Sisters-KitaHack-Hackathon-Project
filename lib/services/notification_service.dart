import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../models/alert_model.dart';
import '../pages/alert_detail_page.dart';
import '../services/firestore_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<void> init() async {
    // Android initialization settings
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS initialization settings
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsIOS,
        );

    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create High Importance Channel for Android
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'emergency_alerts',
      'Emergency Alerts',
      description: 'Critical notifications for disaster alerts',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    // Start background listener for new reports
    startAutomatedListener();
  }

  // To avoid duplicate notifications
  final Set<String> _notifiedCaseIds = {};
  final DateTime _appStartTime = DateTime.now();

  void startAutomatedListener() {
    debugPrint('NotificationService: Starting automated Firestore listener...');

    FirestoreService().reportedCasesStream().listen((cases) {
      for (final c in cases) {
        // Only notify if:
        // 1. It happened after the app started (to avoid spamming old history)
        // 2. We haven't notified for this ID yet
        // 3. It's a high/critical severity (level 4 or 5)
        if (c.timestamp.isAfter(
              _appStartTime.subtract(const Duration(seconds: 5)),
            ) &&
            !_notifiedCaseIds.contains(c.id) &&
            c.severityLevel >= 4) {
          _notifiedCaseIds.add(c.id);

          showEmergencyAlert(
            title:
                '\u26A0\uFE0F ${c.category.toUpperCase()} ALERT: ${c.locationLabel}',
            body: c.description,
            alertId: c.id,
          );
        }
      }
    });
  }

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      final Map<String, dynamic> data = jsonDecode(response.payload!);
      final String alertId = data['alertId'];
      final String? title = data['title'];
      final String? body = data['body'];

      // Try to find the alert in mock data or construct a temporary model
      AlertModel alert;
      try {
        alert = mockAlerts.firstWhere((a) => a.id == alertId);
      } catch (_) {
        // Construct from payload if it's a real database alert
        alert = AlertModel(
          id: alertId,
          title: title ?? 'Emergency Alert',
          description: body ?? '',
          type: 'warning',
          severity: 'high',
          shortAdvice: body ?? '',
          locationName: 'Local Area',
          distanceKm: 0.0,
          issuedAt: DateTime.now(),
          lat: 0.0,
          lng: 0.0,
          recommendedActions: const [],
          nearbyShelters: const [],
          officialSource: 'CityGuard',
        );
      }

      navigatorKey.currentState?.push(
        MaterialPageRoute(builder: (_) => AlertDetailPage(alert: alert)),
      );
    }
  }

  Future<void> showEmergencyAlert({
    required String title,
    required String body,
    required String alertId,
  }) async {
    debugPrint('NotificationService: Showing emergency alert: $title');
    try {
      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
            'emergency_alerts',
            'Emergency Alerts',
            channelDescription: 'Critical notifications for disaster alerts',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker',
            color: Colors.red,
            icon: '@mipmap/ic_launcher',
          );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
      );

      final int id = DateTime.now().millisecondsSinceEpoch % 100000;
      debugPrint('NotificationService: Internal ID: $id');

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: jsonEncode({'alertId': alertId, 'title': title, 'body': body}),
      );
      debugPrint('NotificationService: Notification shown successfully.');
    } catch (e) {
      debugPrint('NotificationService: Error showing notification: $e');
    }
  }

  Future<void> requestPermissions() async {
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
  }
}
