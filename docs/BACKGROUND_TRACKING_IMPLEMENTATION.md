# Background Flight Tracking Implementation

## Problem Statement

Current implementation doesn't properly track flight when:
1. Phone screen is locked
2. App is in background
3. User switches to another app

This is critical for VFR flight tracking as pilots need continuous tracking throughout the flight.

## Root Causes

1. **Wakelock Only**: Current implementation only uses `wakelock_plus` which keeps screen on but doesn't guarantee background execution
2. **No Foreground Service**: Android requires a foreground service with notification for background location
3. **iOS Background Modes**: While configured, not properly utilized with location updates
4. **No Background Task Management**: No proper handling of app lifecycle events

## Solution Architecture

### 1. Android Foreground Service
- Create persistent notification during flight tracking
- Use foreground service to keep location updates running
- Handle service lifecycle properly

### 2. iOS Background Location
- Use `allowsBackgroundLocationUpdates` flag
- Implement proper location manager configuration
- Handle background task expiration

### 3. Flutter Background Execution
- Use `flutter_background_service` or `workmanager` for background tasks
- Implement proper app lifecycle handling
- Ensure location stream continues in background

## Implementation Plan

### Phase 1: Add Required Dependencies

```yaml
dependencies:
  flutter_background_service: ^5.0.0  # For background execution
  flutter_local_notifications: ^17.0.0  # For foreground service notification
```

### Phase 2: Create Background Service

Create `lib/services/background_flight_service.dart`:
- Initialize background service
- Create persistent notification
- Handle location updates in background
- Store flight data even when app is closed

### Phase 3: Update FlightService

Modify `lib/services/flight_service.dart`:
- Start background service when flight tracking starts
- Stop background service when flight tracking stops
- Handle app lifecycle events (paused, resumed, detached)
- Ensure location stream continues in all states

### Phase 4: Platform-Specific Configuration

**Android**:
- Add foreground service to AndroidManifest.xml
- Configure notification channel
- Handle Android 12+ restrictions

**iOS**:
- Enable background location updates
- Configure location manager for background
- Handle background task expiration

### Phase 5: Testing

- Test with screen locked
- Test with app in background
- Test with app killed (Android)
- Test battery impact
- Test data accuracy

## Detailed Implementation

### 1. Background Service Configuration

```dart
// lib/services/background_flight_service.dart
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class BackgroundFlightService {
  static const String notificationChannelId = 'flight_tracking_channel';
  static const int notificationId = 888;
  
  static Future<void> initialize() async {
    final service = FlutterBackgroundService();
    
    // Create notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      notificationChannelId,
      'Flight Tracking',
      description: 'Tracks your flight position in the background',
      importance: Importance.low,
      playSound: false,
    );
    
    final FlutterLocalNotificationsPlugin notifications = 
        FlutterLocalNotificationsPlugin();
    
    await notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    
    // Configure background service
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: notificationChannelId,
        initialNotificationTitle: 'Flight Tracking Active',
        initialNotificationContent: 'Tracking your flight position',
        foregroundServiceNotificationId: notificationId,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
  }
  
  @pragma('vm:entry-point')
  static void onStart(ServiceInstance service) async {
    // This runs in background isolate
    // Set up location tracking
    // Store data to local storage
  }
  
  @pragma('vm:entry-point')
  static bool onIosBackground(ServiceInstance service) {
    // iOS background task
    return true;
  }
}
```

### 2. Update FlightService

```dart
// In lib/services/flight_service.dart

Future<void> startFlight() async {
  if (_flightState.isTracking) return;
  
  // Enable wakelock
  WakelockPlus.enable();
  
  // Start background service
  await BackgroundFlightService.start();
  
  // Start location tracking with background mode
  await _locationTracker.startTracking(
    onLocationUpdate: _handleLocationUpdate,
    backgroundMode: true,  // NEW: Enable background mode
  );
  
  // ... rest of existing code
}

Future<Flight?> stopFlight() async {
  if (!_flightState.isTracking) return null;
  
  // Stop background service
  await BackgroundFlightService.stop();
  
  // Disable wakelock
  WakelockPlus.disable();
  
  // ... rest of existing code
}
```

### 3. Update LocationTracker

```dart
// In lib/services/flight/tracking/location_tracker.dart

class LocationTracker {
  StreamSubscription<Position>? _positionSubscription;
  bool _backgroundMode = false;
  
  Future<void> startTracking({
    required Function(Position) onLocationUpdate,
    bool backgroundMode = false,
  }) async {
    _backgroundMode = backgroundMode;
    
    // Configure location settings for background
    final locationSettings = LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      distanceFilter: 5,
      // Android specific
      timeLimit: null,  // No time limit
      // iOS specific  
      activityType: ActivityType.airborne,  // Optimize for flight
    );
    
    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      onLocationUpdate,
      onError: (error) {
        debugPrint('Location error: $error');
      },
      cancelOnError: false,  // Keep stream alive on errors
    );
  }
}
```

### 4. Android Manifest Updates

```xml
<!-- android/app/src/main/AndroidManifest.xml -->

<!-- Add foreground service permission -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.WAKE_LOCK" />

<application>
  <!-- Add foreground service -->
  <service
      android:name="id.flutter.flutter_background_service.BackgroundService"
      android:foregroundServiceType="location"
      android:exported="false" />
</application>
```

### 5. iOS Configuration Updates

```swift
// ios/Runner/AppDelegate.swift

import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Enable background location updates
    if #available(iOS 9.0, *) {
      UIApplication.shared.setMinimumBackgroundFetchInterval(
        UIApplication.backgroundFetchIntervalMinimum
      )
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // Handle background location updates
  override func applicationDidEnterBackground(_ application: UIApplication) {
    // Keep location updates running
  }
}
```

## Alternative: Simpler Approach Using Geolocator Only

If full background service is too complex, we can use a simpler approach:

### 1. Update Location Settings

```dart
// Use more aggressive location settings
final locationSettings = LocationSettings(
  accuracy: LocationAccuracy.bestForNavigation,
  distanceFilter: 5,
  timeLimit: null,  // No timeout
);

// On iOS, enable background updates
if (Platform.isIOS) {
  final locationManager = CLLocationManager();
  locationManager.allowsBackgroundLocationUpdates = true;
  locationManager.pausesLocationUpdatesAutomatically = false;
  locationManager.activityType = .airborne;
}
```

### 2. Handle App Lifecycle

```dart
class FlightService with ChangeNotifier, WidgetsBindingObserver {
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        // App in background - ensure tracking continues
        _ensureBackgroundTracking();
        break;
      case AppLifecycleState.resumed:
        // App back in foreground
        _resumeForegroundTracking();
        break;
      case AppLifecycleState.detached:
        // App being killed - save state
        _saveFlightState();
        break;
      default:
        break;
    }
  }
  
  void _ensureBackgroundTracking() {
    if (!_flightState.isTracking) return;
    
    // Keep wakelock
    WakelockPlus.enable();
    
    // Ensure location stream is active
    if (_positionSubscription == null || _positionSubscription!.isPaused) {
      _startLocationTracking();
    }
  }
}
```

### 3. Add Notification (Android Only)

```dart
// Show persistent notification on Android
if (Platform.isAndroid) {
  await _showTrackingNotification();
}

Future<void> _showTrackingNotification() async {
  final notifications = FlutterLocalNotificationsPlugin();
  
  const androidDetails = AndroidNotificationDetails(
    'flight_tracking',
    'Flight Tracking',
    channelDescription: 'Tracking your flight position',
    importance: Importance.low,
    priority: Priority.low,
    ongoing: true,  // Can't be dismissed
    autoCancel: false,
    playSound: false,
    enableVibration: false,
  );
  
  await notifications.show(
    888,
    'Flight Tracking Active',
    'Tracking your position',
    const NotificationDetails(android: androidDetails),
  );
}
```

## Recommended Approach

**Start with Simpler Approach**:
1. Add `flutter_local_notifications` for Android notification
2. Update location settings for background mode
3. Add app lifecycle handling
4. Test thoroughly

**If needed, upgrade to Full Background Service**:
1. Add `flutter_background_service`
2. Implement background isolate
3. Handle data synchronization
4. More complex but more reliable

## Testing Checklist

- [ ] Test with screen locked (5+ minutes)
- [ ] Test with app in background (switch to other apps)
- [ ] Test with app killed (Android only)
- [ ] Test battery drain over 1 hour
- [ ] Test location accuracy in background
- [ ] Test data persistence
- [ ] Test on Android 12+
- [ ] Test on iOS 15+
- [ ] Test with low battery mode
- [ ] Test with airplane mode toggle

## Battery Optimization

To minimize battery drain:
1. Use `distanceFilter: 5` (only update every 5 meters)
2. Use `ActivityType.airborne` on iOS (optimized for flight)
3. Stop sensors when not needed (accelerometer, etc.)
4. Batch data writes to storage
5. Use low-priority notification (no sound/vibration)

## Known Limitations

1. **Android Doze Mode**: May delay updates when device is stationary
2. **iOS Background Time Limit**: iOS may suspend after extended background time
3. **Battery Saver Mode**: May restrict background location
4. **Manufacturer Restrictions**: Some Android manufacturers aggressively kill background apps

## Mitigation Strategies

1. **User Education**: Inform users to disable battery optimization for the app
2. **Notification**: Show persistent notification explaining tracking is active
3. **Periodic Checks**: Verify tracking is still active and restart if needed
4. **Data Recovery**: Implement gap detection and interpolation
5. **User Feedback**: Show clear indication when tracking is interrupted

## Next Steps

1. Implement simpler approach first
2. Test thoroughly on multiple devices
3. Gather user feedback
4. Upgrade to full background service if needed
5. Document battery impact
6. Add user controls for background tracking preferences
