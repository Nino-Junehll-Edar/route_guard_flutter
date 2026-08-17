import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:route_guard/services/performance_monitoring_service.dart';

class NotificationService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final PerformanceMonitoringService _perfService = PerformanceMonitoringService();

  // Stream controller for real-time notifications
  final _notificationStreamController =
      StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationStreamController.stream;

  // Subscription to the broadcast channel
  late final RealtimeChannel _broadcastChannel;

  NotificationService();

  /// Initialize notification service
  Future<void> initialize() async {
    await _perfService.logDuration('InitializeNotificationService', () async {
      // Initialize Firebase Messaging
      await _firebaseMessaging.requestPermission();

      // Get FCM token for debugging
      final token = await _firebaseMessaging.getToken();
      debugPrint('FCM Token: $token');

      // Initialize local notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      await _localNotifications.initialize(settings: initializationSettings);

      // Setup Supabase real-time channel for notifications
      await _setupRealtimeNotifications();
    });
  }

  /// Setup Supabase real-time channel for receiving notifications
  Future<void> _setupRealtimeNotifications() async {
    // Listen to a broadcast channel for notifications
    final channel = _supabase.channel('public:notifications');
    _broadcastChannel = channel;

    channel.onBroadcast(
      event: 'new_notification',
      callback: (payload) => _notificationStreamController.add(payload),
    );

    channel.subscribe();
  }

  /// Show a notification (Android focused)
  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _perfService.logDuration('ShowNotification', () async {
      // Show local notification for Android
      await showLocalNotification(
        title: title,
        body: body,
        payload: data,
      );

      // Also broadcast via Supabase so all clients get it (in-app notifications)
      await _broadcastNotification(title, body, data);
    });
  }

  /// Show local notification using flutter_local_notifications
  Future<void> showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    await _perfService.logDuration('ShowLocalNotification', () async {
      const AndroidNotificationDetails androidPlatformChannelSpecifics =
          AndroidNotificationDetails(
        'hazard_channel',
        'Hazard Notifications',
        channelDescription: 'Notifications for nearby hazards',
        importance: Importance.max,
        priority: Priority.high,
        ticker: 'ticker',
      );
      const NotificationDetails platformChannelSpecifics =
          NotificationDetails(android: androidPlatformChannelSpecifics);

      await _localNotifications.show(
        id: DateTime.now().millisecondsSinceEpoch.remainder(100000), // Generate unique ID
        title: title,
        body: body,
        payload: payload?.toString() ?? '',
        notificationDetails: platformChannelSpecifics,
      );
    });
  }

  
  /// Broadcast notification via Supabase Realtime
  Future<void> _broadcastNotification(
    String title,
    String body,
    Map<String, dynamic>? data,
  ) async {
    final channel = _supabase.channel('public:notifications');
    await channel.sendBroadcastMessage(
      event: 'new_notification',
      payload: {
        'title': title,
        'body': body,
        'data': data ?? {},
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Get notification stream for listening to incoming notifications
  Stream<Map<String, dynamic>> getNotifications() => notificationStream;

  /// Dispose resources
  void dispose() {
    _notificationStreamController.close();
    _supabase.removeChannel(_broadcastChannel);
  }
}