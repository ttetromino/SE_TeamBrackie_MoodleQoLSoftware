// lib/services/notification_service.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  Timer? _pollingTimer;
  bool _isPolling = false;

  // Callback for deep linking
  Function(String courseId, String activityId, String activityUrl)? onNotificationTap;

  // Initialize notifications
  Future<void> initialize() async {
    // Initialize for Android
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialize for iOS
    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(settings, onDidReceiveNotificationResponse: _onNotificationTap);
  }

  // Handle notification tap for deep linking
  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && onNotificationTap != null) {
      final data = jsonDecode(payload);
      onNotificationTap!(
        data['courseId'] ?? '',
        data['activityId'] ?? '',
        data['activityUrl'] ?? '',
      );
    }
  }

  // US-09-T-03: Get notification preferences
  Future<Map<String, bool>> getPreferences(String email) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return {
        'enabled24h': prefs.getBool('notify_24h_$email') ?? true,
        'enabled3h': prefs.getBool('notify_3h_$email') ?? true,
      };
    } catch (e) {
      return {'enabled24h': true, 'enabled3h': true};
    }
  }

  // US-09-T-03: Save notification preferences
  Future<void> savePreferences(String email, bool enabled24h, bool enabled3h) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notify_24h_$email', enabled24h);
    await prefs.setBool('notify_3h_$email', enabled3h);

    // Also save to backend
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/api/notifications/preference'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'enabled24h': enabled24h,
          'enabled3h': enabled3h,
        }),
      );
    } catch (e) {
      print('Save preference to backend error: $e');
    }
  }

  // Start polling for notifications (every minute)
  void startPolling(String email) {
    if (_isPolling) return;
    _isPolling = true;

    _pollingTimer = Timer.periodic(const Duration(minutes: 1), (timer) async {
      await checkAndSendNotifications(email);
    });

    // Immediate check
    checkAndSendNotifications(email);
  }

  // Stop polling
  void stopPolling() {
    _pollingTimer?.cancel();
    _isPolling = false;
  }

  // US-09-T-01 & US-09-T-02: Check and send notifications
  Future<void> checkAndSendNotifications(String email) async {
    try {
      // Get pending notifications from backend
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/notifications/pending/$email'),
      );

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);
      final List<dynamic> notifications = data['notifications'] ?? [];

      // Get local sent logs to prevent duplicates
      final prefs = await SharedPreferences.getInstance();
      final sentLogs = prefs.getStringList('sent_notifications_$email') ?? [];

      for (final notif in notifications) {
        final notificationId = notif['id'];

        // Skip if already sent
        if (sentLogs.contains(notificationId)) continue;

        // US-09-T-02: Send with deep linking payload
        await _showNotification(
          id: notificationId.hashCode,
          title: notif['title'],
          body: notif['body'],
          payload: jsonEncode({
            'courseId': notif['courseId'],
            'activityId': notif['activityId'],
            'activityUrl': notif['activityUrl'],
            'courseName': notif['courseName'],
          }),
        );

        // Mark as sent in logs
        sentLogs.add(notificationId);
        await prefs.setStringList('sent_notifications_$email', sentLogs);

        // Mark as sent in backend
        await http.post(
          Uri.parse('${ApiConfig.baseUrl}/api/notifications/mark-sent'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'itemId': notif['itemId'],
            'scheduledAt': notif['scheduledAt'],
          }),
        );
      }

    } catch (e) {
      print('Check notifications error: $e');
    }
  }

  // Show local notification
  Future<void> _showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'deadline_channel',
      'Deadline Alerts',
      channelDescription: 'Notifications for upcoming deadlines',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _notifications.show(id, title, body, details, payload: payload);
  }

  // Show in-app toast notification (for when app is open)
  void showInAppNotification(BuildContext context, String title, String body, {VoidCallback? onTap}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(body, style: const TextStyle(fontSize: 12)),
          ],
        ),
        backgroundColor: const Color(0xFF9D2BD1),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: onTap != null
            ? SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: onTap,
        )
            : null,
      ),
    );
  }
}