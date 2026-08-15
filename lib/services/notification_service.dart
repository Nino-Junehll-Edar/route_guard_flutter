import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
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
      await _localNotifications.initialize(initializationSettings);

      // Setup Supabase real-time channel for notifications
      await _setupRealtimeNotifications();
    });
  }

  /// Setup Supabase real-time channel for receiving notifications
  Future<void> _setupRealtimeNotifications() async {
    // Listen to a broadcast channel for notifications
    final channel = _supabase.channel('public:notifications');
    _broadcastChannel = channel;

    channel.on(
      RealtimeListenTypes.broadcast,
      ChannelFilter(event: 'new_notification'),
      (payload, [ref]) => _notificationStreamController.add(payload as Map<String, dynamic>),
    );

    channel.subscribe();
  }

  /// Show a notification (platform-aware)
  Future<void> showNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    await _perfService.logDuration('ShowNotification', () async {
      if (Platform.isIOS || Platform.isAndroid) {
        // Show local notification for mobile
        await showLocalNotification(
          title: title,
          body: body,
          payload: data,
        );
      } else if (kIsWeb) {
        // Show web notification using Firebase Messaging or browser notifications
        await _showWebNotification(title, body, data);
      }

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
        DateTime.now().millisecondsSinceEpoch.remainder(100000), // Generate unique ID
        title,
        body,
        platformChannelSpecifics,
        payload: payload?.toString() ?? '',
      );
    });
  }

  /// Show web notification using Firebase Messaging
  Future<void> _showWebNotification(
    String title,
    String body,
    Map<String, dynamic>? data,
  ) async {
    try {
      // For web, we can use Firebase Messaging to send a notification
      // This will work when the app is in background or not focused
      await _firebaseMessaging.requestPermission();

      // Send a data message that will be handled by the service worker
      // Note: For a complete implementation, you'd need a Firebase service worker
      // that handles background messages and displays notifications
      // For now, we'll rely on the Supabase real-time system for in-app notifications
      // and log the notification for demonstration
      debugPrint('Web notification (FCM): $title - $body');
    } catch (e) {
      debugPrint('Could not show web notification via FCM: $e');
      // Fallback to logging
      debugPrint('Web notification: $title - $body');
    }
  }

  /// Broadcast notification via Supabase Realtime
  Future<void> _broadcastNotification(
    String title,
    String body,
    Map<String, dynamic>? data,
  ) async {
    final channel = _supabase.channel('public:notifications');
    await channel.send(
      type: RealtimeListenTypes.broadcast,
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