import 'dart:async';
import 'dart:io' show Platform, SocketException;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:latlong2/latlong.dart';
import '../models/flight.dart';
import '../models/flight_point.dart';
import '../models/aircraft.dart';
import '../models/flight_segment.dart';
import 'barometer_service.dart';
import 'heading_service.dart';
import 'watch_connectivity_service.dart';
import 'flight/helpers/analytics_wrapper.dart';
import 'flight/models/flight_state.dart';
import 'flight/models/flight_constants.dart';
import 'flight/sensors/sensor_manager.dart';
import 'flight/calculations/flight_calculator.dart';
import 'flight/tracking/location_tracker.dart';
import 'flight/tracking/segment_tracker.dart';
import 'flight/storage/flight_history_manager.dart';
import 'logbook_service.dart';
import 'settings_service.dart';
import 'airport_service.dart';

class FlightService with ChangeNotifier {
  // Core components
  final FlightState _flightState = FlightState();
  late final SensorManager _sensorManager;
  late final LocationTracker _locationTracker;
  late final SegmentTracker _segmentTracker;
  final FlightHistoryManager _historyManager = FlightHistoryManager();
  
  // Services
  final BarometerService? _barometerService;
  final HeadingService? _headingService;
  final LogBookService? _logBookService;
  final AirportService? _airportService;
  final WatchConnectivityService _watchService = WatchConnectivityService();
  
  // Subscriptions
  StreamSubscription? _barometerSubscription;
  StreamSubscription<bool>? _watchTrackingSubscription;
  
  // Throttling
  DateTime? _lastNotifyTime;
  Timer? _notifyTimer;
  
  // Callback for flight path updates
  final Function()? onFlightPathUpdated;
  
  // Track initialization state
  bool _isBarometerInitialized = false;
  
  // Current GPS position for altitude fallback
  Position? _currentGpsPosition;
  StreamSubscription<Position>? _gpsPositionSubscription;
  
  // Elevation API caching with enhanced error handling
  Position? _lastElevationFetchPosition;
  DateTime? _lastElevationFetchTime;
  double? _lastElevationValue; // Store the actual elevation value
  static const double _elevationCacheRadius = 250.0; // meters
  static const Duration _elevationCacheTimeout = Duration(minutes: 10);
  static const Duration _elevationApiMinInterval = Duration(seconds: 5); // Rate limiting
  DateTime? _lastElevationApiCall;
  int _elevationApiRetryCount = 0;
  static const int _maxElevationApiRetries = 3;
  
  // Initialize method for compatibility
  Future<void> initialize() async {
    await _initializeStorage();
    // Initialize barometer service to provide altitude data even when not tracking
    await initializeBarometerService();
  }
  
  // Constructor
  FlightService({
    this.onFlightPathUpdated,
    BarometerService? barometerService,
    HeadingService? headingService,
    LogBookService? logBookService,
    AirportService? airportService,
  }) : _barometerService = barometerService ?? BarometerService(),
       _headingService = headingService,
       _logBookService = logBookService,
       _airportService = airportService {
    _initializeComponents();
    _initializeStorage();
    _initializeWatchConnectivity();
  }
  
  void _initializeComponents() {
    // Initialize sensor manager (compass handled by HeadingService)
    _sensorManager = SensorManager(
      onSensorDataUpdated: () {
        _throttledNotifyListeners();
      },
    );
    
    // Listen to heading updates from HeadingService if available
    if (_headingService != null) {
      _headingService.addListener(_onHeadingServiceUpdate);
    }
    
    // Initialize location tracker
    _locationTracker = LocationTracker(
      onLocationUpdate: (flightPoint) {
        _handleLocationUpdate(flightPoint);
      },
      onError: (error) {
        // Location errors are handled by LocationTracker internally
      },
    );
    
    // Initialize segment tracker
    _segmentTracker = SegmentTracker(flightState: _flightState);
  }
  
  void _onHeadingServiceUpdate() {
    // Update flight state with heading from HeadingService
    if (_headingService != null) {
      final heading = _headingService.currentHeading;
      _flightState.setCurrentHeading(heading);
    }
  }
  
  Future<void> _initializeStorage() async {
    await _historyManager.initialize();
    notifyListeners();
  }
  
  void _initializeWatchConnectivity() {
    if (!kIsWeb && Platform.isIOS) {
      _watchTrackingSubscription = _watchService.trackingStateStream.listen((shouldTrack) {
        if (shouldTrack && !_flightState.isTracking) {
          startTracking();
        } else if (!shouldTrack && _flightState.isTracking) {
          stopTracking();
        }
      });
    }
  }
  
  // Public getters delegating to components
  List<FlightPoint> get flightPath => _flightState.flightPath;
  List<Flight> get flights => _historyManager.flights;
  bool get isTracking => _flightState.isTracking;
  double get fuelUsed => FlightCalculator.calculateFuelUsed(
    _flightState.selectedAircraft,
    movingTime,
  );
  
  // Additional getters for compatibility
  List<FlightSegment> get flightSegments => _flightState.flightSegments;
  String get formattedFlightTime => formattedMovingTime;
  
  // Time and duration getters
  Duration get flightDuration => movingTime;
  Duration get movingTime => FlightCalculator.calculateMovingTime(
    _flightState.startTime,
    _flightState.flightPath,
    _flightState.isTracking,
  );
  String get formattedMovingTime => FlightCalculator.formatDuration(movingTime);
  
  // Speed and distance getters
  double get totalDistance => FlightCalculator.calculateTotalDistance(_flightState.flightPath);
  double get maxSpeed => FlightCalculator.getMaxSpeed(_flightState.flightPath);
  double get currentSpeed => _flightState.flightPath.isEmpty ? 0.0 : _flightState.flightPath.last.speed;
  double get averageSpeed => FlightCalculator.calculateAverageSpeed(_flightState.flightPath);
  double get verticalSpeed => FlightCalculator.calculateVerticalSpeed(_flightState.flightPath);
  
  // Sensor data getters
  double? get currentHeading => _headingService?.currentHeading ?? _flightState.currentHeading;
  double? get barometricAltitude => _flightState.currentBaroAltitude;
  double? get barometricPressure => _barometerService?.pressureHPa;
  double get currentGForce => _sensorManager.currentGForce;
  double get currentPressure => _barometerService?.lastPressure ?? FlightConstants.defaultPressureHPa;
  
  // Aircraft management
  void setAircraft(Aircraft aircraft) {
    _flightState.setAircraft(aircraft);
  }
  
  // Flight tracking control
  Future<void> startTracking() async {
    if (_flightState.isTracking) return;
    
    // Enable wakelock to keep screen on
    WakelockPlus.enable();
    
    // Reset state
    _flightState.reset();
    
    // Set tracking state
    _flightState.setTracking(true);
    _flightState.setStartTime(DateTime.now());
    _flightState.setRecordingStarted(DateTime.now().toUtc());
    
    // Start sensors
    _sensorManager.startSensors();
    
    // Ensure barometer is initialized and listening
    // The initializeBarometerService method handles redundancy checking
    await initializeBarometerService();
    
    // Start location tracking
    await _locationTracker.startTracking();
    
    // Notify listeners
    notifyListeners();
    
    // Track analytics
    AnalyticsWrapper.track('flight_tracking_started');
  }
  
  Future<Flight?> stopTracking() async {
    if (!_flightState.isTracking) return null;
    
    // Disable wakelock
    WakelockPlus.disable();
    
    // Set recording stopped time
    _flightState.setRecordingStopped(DateTime.now().toUtc());
    
    // Complete any open segments
    final lastPoint = _flightState.flightPath.isNotEmpty ? _flightState.flightPath.last : null;
    _segmentTracker.completeOpenSegments(lastPoint);
    
    // Stop tracking
    _locationTracker.stopTracking();
    _sensorManager.stopSensors();
    
    // Don't stop barometer service completely - keep it running for altitude display
    // Just cancel the subscription during tracking to avoid duplicate listeners
    // The barometer will continue running independently
    
    _flightState.setTracking(false);
    
    // Save flight if there's data
    Flight? savedFlight;
    if (_flightState.flightPath.length > 1) {
      savedFlight = await _saveCurrentFlight();
    }
    
    notifyListeners();
    
    // Track analytics
    AnalyticsWrapper.track('flight_tracking_stopped');
    
    return savedFlight;
  }
  
  void _handleLocationUpdate(FlightPoint point) {
    if (!_flightState.isTracking) return;
    
    // Update pressure if available
    if (_barometerService != null) {
      point = FlightPoint(
        latitude: point.latitude,
        longitude: point.longitude,
        altitude: point.altitude,
        speed: point.speed,
        heading: point.heading,
        timestamp: point.timestamp,
        accuracy: point.accuracy,
        pressure: _barometerService.lastPressure ?? 0.0,
      );
    }
    
    // Add point to flight path
    _flightState.addFlightPoint(point);
    
    // Process segments
    _segmentTracker.processFlightPoint(point);
    
    // Calculate vertical speed for watch
    final verticalSpeedMps = _flightState.flightPath.length > 1
        ? (point.altitude - _flightState.flightPath[_flightState.flightPath.length - 2].altitude) /
          point.timestamp.difference(_flightState.flightPath[_flightState.flightPath.length - 2].timestamp).inSeconds
        : 0.0;
    
    // Send data to watch
    _sendDataToWatch(point, verticalSpeedMps);
    
    // Notify listeners
    _throttledNotifyListeners();
    onFlightPathUpdated?.call();
  }
  
  Future<Flight?> _saveCurrentFlight() async {
    if (_flightState.flightPath.isEmpty) return null;
    
    // Detect departure and arrival airports
    String? departureAirportCode;
    String? arrivalAirportCode;
    
    if (_airportService != null && _flightState.flightPath.isNotEmpty) {
      // Find departure airport (from first position)
      final firstPoint = _flightState.flightPath.first;
      final departurePosition = LatLng(firstPoint.latitude, firstPoint.longitude);
      final departureAirport = _airportService.findNearestAirport(departurePosition);
      
      if (departureAirport != null) {
        // Check if within reasonable distance (5km) of the airport
        final distance = departurePosition.distanceTo(departureAirport.position);
        if (distance <= 5.0) {
          departureAirportCode = departureAirport.icao;
        }
      }
      
      // Find arrival airport (from last position)
      final lastPoint = _flightState.flightPath.last;
      final arrivalPosition = LatLng(lastPoint.latitude, lastPoint.longitude);
      final arrivalAirport = _airportService.findNearestAirport(arrivalPosition);
      
      if (arrivalAirport != null) {
        // Check if within reasonable distance (5km) of the airport
        final distance = arrivalPosition.distanceTo(arrivalAirport.position);
        if (distance <= 5.0) {
          arrivalAirportCode = arrivalAirport.icao;
        }
      }
    }
    
    final flight = Flight(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      startTime: _flightState.startTime!,
      endTime: DateTime.now(),
      path: _flightState.flightPath,
      distanceTraveled: totalDistance,
      movingTime: movingTime,
      averageSpeed: averageSpeed,
      maxSpeed: maxSpeed,
      maxAltitude: _flightState.flightPath.map((p) => p.altitude).reduce((a, b) => a > b ? a : b),
      recordingStartedZulu: _flightState.recordingStartedZulu!,
      recordingStoppedZulu: _flightState.recordingStoppedZulu,
      movingStartedZulu: _flightState.movingStartedZulu,
      movingStoppedZulu: _flightState.movingStoppedZulu,
      movingSegments: _flightState.movingSegments,
      flightSegments: _flightState.flightSegments,
      departureAirportCode: departureAirportCode,
      arrivalAirportCode: arrivalAirportCode,
    );
    
    await _historyManager.saveFlight(flight);
    
    // Create logbook entry from flight if option is enabled
    try {
      final settingsService = SettingsService();
      if (settingsService.autoCreateLogbookEntry) {
        // This will be injected from the app's provider context
        if (_logBookService != null) {
          await _logBookService.createEntryFromFlight(flight);
        }
      }
    } catch (e) {
      debugPrint('Failed to create logbook entry: $e');
    }
    
    return flight;
  }
  
  // Flight history management
  Future<void> deleteFlight(int index) async {
    await _historyManager.deleteFlight(index);
    notifyListeners();
  }
  
  Future<String> exportFlight(Flight flight, {String format = 'gpx'}) async {
    return _historyManager.exportFlight(flight, format: format);
  }
  
  void _sendDataToWatch(FlightPoint point, double verticalSpeed) {
    // Convert units for watch display
    final altitudeFeet = point.altitude * FlightConstants.metersToFeet;
    final speedKnots = point.speed * FlightConstants.metersPerSecondToKnots;
    final verticalSpeedFpm = verticalSpeed * FlightConstants.metersPerSecondToFeetPerMinute;
    final pressureInHg = point.pressure * FlightConstants.hPaToInHg;
    
    _watchService.sendFlightData(
      altitude: altitudeFeet,
      groundSpeed: speedKnots,
      heading: point.heading,
      track: point.heading,
      verticalSpeed: verticalSpeedFpm,
      pressure: pressureInHg,
    );
  }
  
  void _throttledNotifyListeners() {
    final now = DateTime.now();
    if (_lastNotifyTime == null ||
        now.difference(_lastNotifyTime!).inMilliseconds > FlightConstants.notifyThrottleMs) {
      _lastNotifyTime = now;
      notifyListeners();
    } else {
      // Schedule a delayed notification if we're throttling
      _notifyTimer?.cancel();
      _notifyTimer = Timer(
        const Duration(milliseconds: FlightConstants.notifyThrottleMs),
        () {
          _lastNotifyTime = DateTime.now();
          notifyListeners();
        },
      );
    }
  }
  
  /// Fetch elevation from online service for platforms where GPS altitude is not available
  /// This includes macOS and Web platforms where GPS/barometer altitude data is often missing
  Future<void> _fetchElevationForPosition(Position position) async {
    // Check if we have a cached elevation for a nearby position
    if (_shouldUseCachedElevation(position)) {
      // Use cached elevation - position hasn't changed significantly
      if (_lastElevationValue != null) {
        // Update position but keep cached elevation
        _currentGpsPosition = _createPositionWithElevation(
          position, 
          _lastElevationValue!
        );
      }
      return;
    }
    
    // Rate limiting - don't call API too frequently
    if (_lastElevationApiCall != null &&
        DateTime.now().difference(_lastElevationApiCall!) < _elevationApiMinInterval) {
      return; // Too soon since last API call
    }
    
    try {
      // Use Open-Elevation API (free, no API key required)
      final lat = position.latitude;
      final lon = position.longitude;
      
      _lastElevationApiCall = DateTime.now();
      
      final url = Uri.parse(
        'https://api.open-elevation.com/api/v1/lookup?locations=$lat,$lon'
      );
      
      final response = await http.get(url).timeout(
        const Duration(seconds: 3),
        onTimeout: () => http.Response('', 408),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final elevation = data['results'][0]['elevation']?.toDouble();
          if (elevation != null && elevation >= -500 && elevation <= 9000) {
            // Validate elevation is within reasonable bounds
            // Create new position with elevation
            _currentGpsPosition = _createPositionWithElevation(position, elevation);
            
            // Update cache
            _lastElevationFetchPosition = position;
            _lastElevationFetchTime = DateTime.now();
            _lastElevationValue = elevation;
            _elevationApiRetryCount = 0; // Reset retry count on success
          }
        }
      } else if (response.statusCode == 429) {
        // Rate limit exceeded - implement exponential backoff
        _elevationApiRetryCount++;
        final backoffSeconds = 5 * (1 << _elevationApiRetryCount); // 5, 10, 20, 40...
        _lastElevationApiCall = DateTime.now().add(Duration(seconds: backoffSeconds));
      } else if (response.statusCode == 408 || response.statusCode >= 500) {
        // Timeout or server error - retry with backoff
        _elevationApiRetryCount++;
        if (_elevationApiRetryCount <= _maxElevationApiRetries) {
          final backoffSeconds = 2 * _elevationApiRetryCount;
          await Future.delayed(Duration(seconds: backoffSeconds));
          // Recursive retry
          await _fetchElevationForPosition(position);
        }
      }
    } on SocketException {
      // Network error - use cached value if available
      if (_lastElevationValue != null) {
        _currentGpsPosition = _createPositionWithElevation(position, _lastElevationValue!);
      }
    } on TimeoutException {
      // Timeout - retry if under limit
      _elevationApiRetryCount++;
      if (_elevationApiRetryCount <= _maxElevationApiRetries) {
        await Future.delayed(Duration(seconds: 2));
        await _fetchElevationForPosition(position);
      }
    } on FormatException {
      // Invalid JSON response - don't retry
      _elevationApiRetryCount = _maxElevationApiRetries + 1;
    } catch (e) {
      // Other errors - use cached value if available
      if (_lastElevationValue != null) {
        _currentGpsPosition = _createPositionWithElevation(position, _lastElevationValue!);
      }
    }
  }
  
  /// Check if we should use cached elevation instead of fetching new data
  bool _shouldUseCachedElevation(Position position) {
    // No cache available
    if (_lastElevationFetchPosition == null || 
        _lastElevationFetchTime == null ||
        _lastElevationValue == null) {
      return false;
    }
    
    // Check if cache is too old
    if (DateTime.now().difference(_lastElevationFetchTime!) > _elevationCacheTimeout) {
      // Clear stale cache
      _lastElevationFetchPosition = null;
      _lastElevationFetchTime = null;
      _lastElevationValue = null;
      return false;
    }
    
    // Calculate distance from last fetch position
    final distance = Geolocator.distanceBetween(
      _lastElevationFetchPosition!.latitude,
      _lastElevationFetchPosition!.longitude,
      position.latitude,
      position.longitude,
    );
    
    // Use cache if within radius
    return distance <= _elevationCacheRadius;
  }
  
  /// Create a new Position object with updated elevation (for macOS and Web)
  Position _createPositionWithElevation(Position original, double elevation) {
    return Position(
      latitude: original.latitude,
      longitude: original.longitude,
      timestamp: original.timestamp,
      altitude: elevation,
      altitudeAccuracy: 10.0, // Approximate accuracy for elevation API
      accuracy: original.accuracy,
      heading: original.heading,
      headingAccuracy: original.headingAccuracy,
      speed: original.speed,
      speedAccuracy: original.speedAccuracy,
      floor: original.floor,
      isMocked: original.isMocked,
    );
  }
  
  /// Initialize GPS position monitoring for altitude fallback
  Future<void> _initializeGpsMonitoring() async {
    try {
      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      if (permission == LocationPermission.denied || 
          permission == LocationPermission.deniedForever) {
        return;
      }
      
      // Get current position once
      try {
        _currentGpsPosition = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: Duration(seconds: 5),
          ),
        );
        
        // On macOS and Web, altitude might be 0 - try to get elevation from online service
        if (_currentGpsPosition != null && 
            _currentGpsPosition!.altitude == 0 &&
            (kIsWeb || (!kIsWeb && Platform.isMacOS))) {
          // Fetch elevation from API for platforms without GPS altitude
          await _fetchElevationForPosition(_currentGpsPosition!);
        }
      } catch (e) {
        // Timeout or error getting current position
      }
      
      // Start monitoring position for altitude updates
      const LocationSettings locationSettings = LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 50, // Update less frequently for altitude monitoring
      );
      
      _gpsPositionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) async {
          // On macOS and Web, check if altitude is 0 and fetch elevation
          if (position.altitude == 0 && (kIsWeb || (!kIsWeb && Platform.isMacOS))) {
            await _fetchElevationForPosition(position);
          } else {
            _currentGpsPosition = position;
          }
          
          // Notify listeners if altitude changed significantly (more than 5 meters)
          if (_currentGpsPosition != null && 
              (position.altitude - (_currentGpsPosition?.altitude ?? 0)).abs() > 5) {
            _throttledNotifyListeners();
          }
        },
        onError: (error) {
          // GPS errors are non-critical for altitude display
        },
      );
    } catch (e) {
      // GPS initialization errors are non-critical
    }
  }
  
  /// Initialize barometer service independently of flight tracking
  /// This allows altitude to be displayed even when not tracking
  Future<void> initializeBarometerService() async {
    // Prevent redundant initialization
    if (_isBarometerInitialized) {
      return;
    }
    
    if (_barometerService == null) {
      return;
    }
    
    // Don't reinitialize if already listening
    if (_barometerService.isListening) {
      _isBarometerInitialized = true;
      return;
    }
    
    try {
      await _barometerService.initialize();
      
      // Check if barometer is available before starting
      if (!_barometerService.isBarometerAvailable) {
        // Barometer not available - will use fallback data
        // Start listening anyway for simulated data
      }
      
      await _barometerService.startListening();
      
      // Cancel existing subscription if any and create new one
      await _barometerSubscription?.cancel();
      _barometerSubscription = _barometerService.onBarometerUpdate.listen(
        (reading) {
          _flightState.setCurrentBaroAltitude(reading.altitude);
          _flightState.setCurrentPressure(reading.pressure);
          _throttledNotifyListeners();
        },
        onError: (error) {
          // Barometer errors are handled internally by the service
          // Don't cancel subscription on errors - let barometer service handle fallback
        },
      );
      
      _isBarometerInitialized = true;
    } catch (e) {
      // Failed to initialize - this is a non-critical service
      // Will fall back to GPS altitude
    }
    
    // Also initialize GPS monitoring for altitude fallback
    await _initializeGpsMonitoring();
  }
  
  /// Stop barometer service independently of flight tracking
  Future<void> stopBarometerService() async {
    if (_barometerService != null && _barometerService.isListening) {
      try {
        await _barometerService.stopListening();
        _barometerSubscription?.cancel();
        _barometerSubscription = null;
        _isBarometerInitialized = false;
      } catch (e) {
        // Error stopping barometer service - non-critical
      }
    }
  }
  
  /// Get altitude with proper fallback hierarchy: GPS > barometric > 0
  /// 
  /// Priority order:
  /// 1. GPS altitude (widely available and doesn't fluctuate)
  /// 2. Barometric altitude (more accurate but can fluctuate)
  /// 3. Sea level (0.0) as final fallback
  /// 
  /// Returns altitude in meters
  double get currentAltitude {
    // First try GPS altitude from current position (more stable)
    if (_currentGpsPosition != null) {
      final gpsAlt = _currentGpsPosition!.altitude;
      if (!gpsAlt.isNaN && gpsAlt.isFinite) {
        return gpsAlt;
      }
    }
    
    // Try GPS altitude from flight path if tracking
    if (_flightState.flightPath.isNotEmpty) {
      final gpsAltitude = _flightState.flightPath.last.altitude;
      if (!gpsAltitude.isNaN && gpsAltitude.isFinite) {
        return gpsAltitude;
      }
    }
    
    // Fall back to barometric altitude if GPS not available
    // Only use if it's reasonable (between -500m and 9000m)
    if (barometricAltitude != null && 
        !barometricAltitude!.isNaN && 
        barometricAltitude!.isFinite &&
        barometricAltitude! > -500 && 
        barometricAltitude! < 9000) {
      return barometricAltitude!;
    }
    
    // Final fallback to 0 (sea level)
    return 0.0;
  }

  @override
  void dispose() {
    // Remove heading listener if it was added
    if (_headingService != null) {
      _headingService.removeListener(_onHeadingServiceUpdate);
    }
    _sensorManager.dispose();
    _locationTracker.dispose();
    _barometerSubscription?.cancel();
    _barometerService?.dispose();
    _gpsPositionSubscription?.cancel();
    _notifyTimer?.cancel();
    _watchTrackingSubscription?.cancel();
    _watchService.dispose();
    WakelockPlus.disable();
    super.dispose();
  }
}