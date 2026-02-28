import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Service to manage background flight tracking with persistent notification
class BackgroundTrackingService {
  static final BackgroundTrackingService _instance = BackgroundTrackingService._internal();
  factory BackgroundTrackingService() => _instance;
  BackgroundTrackingService._internal();
  
  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;
  bool _isTrackingActive = false;
  
  static const String _channelId = 'flight_tracking_channel';
  static const String _channelName = 'Flight Tracking';
  static const String _channelDescription = 'Tracks your flight position in the background';
  static const int _notificationId = 888;
  
  /// Initialize the notification system
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    // Only initialize on mobile platforms
    if (kIsWeb || Platform.isMacOS) {
      _isInitialized = true;
      return;
    }
    
    try {
      // Android initialization
      if (Platform.isAndroid) {
        const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
        
        // Create notification channel
        const androidChannel = AndroidNotificationChannel(
          _channelId,
          _channelName,
          description: _channelDescription,
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        );
        
        await _notifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
            ?.createNotificationChannel(androidChannel);
        
        await _notifications.initialize(
          const InitializationSettings(
            android: androidSettings,
          ),
        );
      }
      
      // iOS initialization
      if (Platform.isIOS) {
        const iosSettings = DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );
        
        await _notifications.initialize(
          const InitializationSettings(
            iOS: iosSettings,
          ),
        );
      }
      
      _isInitialized = true;
      debugPrint('✅ Background tracking service initialized');
    } catch (e) {
      debugPrint('⚠️ Failed to initialize background tracking service: $e');
      _isInitialized = true; // Mark as initialized to avoid repeated attempts
    }
  }
  
  /// Start background tracking with persistent notification
  Future<void> startTracking({
    String? flightName,
    Duration? duration,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    if (_isTrackingActive) return;
    
    // Only show notification on Android (iOS handles background differently)
    if (Platform.isAndroid) {
      await _showTrackingNotification(
        flightName: flightName,
        duration: duration,
      );
    }
    
    _isTrackingActive = true;
    debugPrint('✅ Background tracking started');
  }
  
  /// Update tracking notification with current flight info
  Future<void> updateTracking({
    String? flightName,
    Duration? duration,
    double? altitude,
    double? speed,
    double? distance,
  }) async {
    if (!_isTrackingActive || !Platform.isAndroid) return;
    
    await _showTrackingNotification(
      flightName: flightName,
      duration: duration,
      altitude: altitude,
      speed: speed,
      distance: distance,
    );
  }
  
  /// Stop background tracking and remove notification
  Future<void> stopTracking() async {
    if (!_isTrackingActive) return;
    
    if (Platform.isAndroid) {
      await _notifications.cancel(_notificationId);
    }
    
    _isTrackingActive = false;
    debugPrint('✅ Background tracking stopped');
  }
  
  /// Show or update the tracking notification
  Future<void> _showTrackingNotification({
    String? flightName,
    Duration? duration,
    double? altitude,
    double? speed,
    double? distance,
  }) async {
    try {
      // Build notification content
      final title = flightName ?? 'Flight Tracking Active';
      final contentParts = <String>[];
      
      if (duration != null) {
        final hours = duration.inHours;
        final minutes = duration.inMinutes.remainder(60);
        contentParts.add('Time: ${hours}h ${minutes}m');
      }
      
      if (altitude != null) {
        contentParts.add('Alt: ${altitude.toInt()} ft');
      }
      
      if (speed != null) {
        contentParts.add('Speed: ${speed.toInt()} kts');
      }
      
      if (distance != null) {
        contentParts.add('Dist: ${distance.toStringAsFixed(1)} nm');
      }
      
      final content = contentParts.isNotEmpty
          ? contentParts.join(' • ')
          : 'Tracking your flight position';
      
      // Android notification
      const androidDetails = AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDescription,
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,  // Can't be dismissed by user
        autoCancel: false,
        playSound: false,
        enableVibration: false,
        showWhen: true,
        usesChronometer: true,
        chronometerCountDown: false,
        icon: '@mipmap/launcher_icon',
        color: Color(0xFF448AFF),
        // Actions for quick access
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction(
            'stop_tracking',
            'Stop Tracking',
            showsUserInterface: true,
          ),
        ],
      );
      
      await _notifications.show(
        _notificationId,
        title,
        content,
        const NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('⚠️ Failed to show tracking notification: $e');
    }
  }
  
  /// Check if tracking is currently active
  bool get isTrackingActive => _isTrackingActive;
  
  /// Request notification permission (Android 13+)
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;
    
    try {
      final androidImplementation = _notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidImplementation != null) {
        final granted = await androidImplementation.requestNotificationsPermission();
        return granted ?? false;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to request notification permission: $e');
    }
    
    return false;
  }
}
