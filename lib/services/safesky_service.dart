import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/safesky_beacon.dart';
import '../config/environment.dart';

/// Service for fetching and managing SafeSky beacon data
class SafeSkyService {
  // SafeSky backend proxy URL from configuration
  static String get _baseUrl => Environment.safeSkyApiUrl;
  static const Duration _minRefreshInterval = Duration(seconds: 5);
  static const Duration _maxRefreshInterval = Duration(seconds: 30);
  static Duration get _cacheDuration => Environment.beaconCacheDuration;
  
  final _logger = Logger(
    level: Level.warning, // Production logging level
  );
  final _client = http.Client();

  // Cache management
  List<SafeSkyBeacon> _beaconsCache = [];
  DateTime? _lastFetch;
  LatLngBounds? _lastViewport;
  Future<void>? _ongoingFetch;
  Timer? _refreshTimer;
  bool _isActive = false;
  
  // Rate limiting management
  Duration _currentRefreshInterval = _minRefreshInterval;
  int _consecutiveRateLimits = 0;
  
  // Stream controller for beacon updates
  final _beaconsStreamController = StreamController<List<SafeSkyBeacon>>.broadcast();
  Stream<List<SafeSkyBeacon>> get beaconsStream => _beaconsStreamController.stream;

  SafeSkyService();

  /// Initialize the SafeSky service
  Future<void> initialize() async {
    _logger.i('🛩️ SafeSky service initialized');
  }

  /// Start fetching beacon data for the given viewport
  Future<void> startTracking(LatLngBounds viewport) async {
    _isActive = true;
    _lastViewport = viewport;
    
    // Reset rate limiting on new tracking session
    _currentRefreshInterval = _minRefreshInterval;
    _consecutiveRateLimits = 0;
    
    // Initial fetch
    await _fetchBeacons(viewport);
    
    // Set up periodic refresh with dynamic interval
    _scheduleNextRefresh();
  }
  
  /// Schedule the next refresh based on current interval
  void _scheduleNextRefresh() {
    _refreshTimer?.cancel();
    
    if (!_isActive) return;
    
    _logger.d('🔄 Scheduling next refresh in ${_currentRefreshInterval.inSeconds} seconds');
    
    _refreshTimer = Timer(_currentRefreshInterval, () {
      if (_isActive && _lastViewport != null) {
        _fetchBeacons(_lastViewport!).then((_) {
          // Schedule next refresh after fetch completes
          _scheduleNextRefresh();
        });
      }
    });
  }

  /// Stop fetching beacon data
  void stopTracking() {
    _isActive = false;
    _refreshTimer?.cancel();
    _refreshTimer = null;
    _ongoingFetch = null;
  }

  /// Update viewport and refresh data if needed
  Future<void> updateViewport(LatLngBounds viewport) async {
    if (!_isActive) return;
    
    _lastViewport = viewport;
    
    // Check if viewport change requires new data
    if (_shouldRefreshForViewport(viewport)) {
      await _fetchBeacons(viewport);
    }
  }

  /// Get current cached beacons
  List<SafeSkyBeacon> get beacons => List.unmodifiable(_beaconsCache);

  /// Check if beacon data is recent
  bool get hasRecentData {
    if (_lastFetch == null) return false;
    final timeSinceLastFetch = DateTime.now().difference(_lastFetch!);
    return timeSinceLastFetch < _cacheDuration;
  }

  /// Check if we should refresh data based on viewport change
  bool _shouldRefreshForViewport(LatLngBounds newViewport) {
    if (_lastViewport == null) return true;
    
    // If new viewport extends significantly beyond cached viewport, refresh
    const double tolerance = 0.1; // degrees
    
    final oldSouth = _lastViewport!.south;
    final oldNorth = _lastViewport!.north;
    final oldWest = _lastViewport!.west;
    final oldEast = _lastViewport!.east;
    
    final newSouth = newViewport.south;
    final newNorth = newViewport.north;
    final newWest = newViewport.west;
    final newEast = newViewport.east;
    
    return newSouth < (oldSouth - tolerance) ||
           newNorth > (oldNorth + tolerance) ||
           newWest < (oldWest - tolerance) ||
           newEast > (oldEast + tolerance);
  }
  
  /// Handle rate limiting with exponential backoff
  void _handleRateLimit(int? retryAfterSeconds) {
    _consecutiveRateLimits++;
    
    // Calculate new interval with exponential backoff
    final backoffMultiplier = math.min(_consecutiveRateLimits, 4); // Cap at 4x
    var newInterval = _minRefreshInterval * math.pow(2, backoffMultiplier);
    
    // If server provided Retry-After header, use it as minimum
    if (retryAfterSeconds != null) {
      newInterval = Duration(seconds: math.max(
        newInterval.inSeconds, 
        retryAfterSeconds
      ));
    }
    
    // Cap at maximum interval
    _currentRefreshInterval = Duration(
      seconds: math.min(newInterval.inSeconds, _maxRefreshInterval.inSeconds)
    );
    
    _logger.w('⚠️ Rate limited. Backing off to ${_currentRefreshInterval.inSeconds}s refresh interval');
  }
  
  /// Reset rate limiting after successful request
  void _resetRateLimiting() {
    if (_consecutiveRateLimits > 0) {
      _logger.i('✅ Rate limit cleared. Resetting to normal refresh interval');
    }
    _consecutiveRateLimits = 0;
    _currentRefreshInterval = _minRefreshInterval;
  }

  /// Fetch beacon data from SafeSky API
  Future<void> _fetchBeacons(LatLngBounds viewport) async {
    // If there's already an ongoing fetch, wait for it
    if (_ongoingFetch != null) {
      await _ongoingFetch;
      return;
    }

    // Check if cache is still valid
    if (hasRecentData && !_shouldRefreshForViewport(viewport)) {
      return;
    }

    _ongoingFetch = _performFetch(viewport);
    try {
      await _ongoingFetch;
    } catch (e) {
      _logger.e('❌ Failed to fetch SafeSky beacon data: $e');
    } finally {
      _ongoingFetch = null;
    }
  }

  /// Perform the actual HTTP request to fetch beacon data
  Future<void> _performFetch(LatLngBounds viewport) async {
    try {
      _logger.d('🛩️ Fetching SafeSky beacons for viewport: $viewport');

      // Construct viewport query parameter
      final viewportParam = '${viewport.south},${viewport.west},${viewport.north},${viewport.east}';
      final url = '$_baseUrl/beacons?viewport=$viewportParam';

      _logger.d('🛩️ SafeSky API URL: $url');

      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        if (jsonData is List) {
          final beacons = jsonData
              .map((json) {
                try {
                  return SafeSkyBeacon.fromJson(json);
                } catch (e) {
                  _logger.w('⚠️ Invalid beacon data: $e');
                  return null;
                }
              })
              .whereType<SafeSkyBeacon>() // Filter out null values
              .where((beacon) => _isValidBeacon(beacon))
              .where((beacon) => beacon.isRecent) // Filter old data
              .toList();

          _beaconsCache = beacons;
          _lastFetch = DateTime.now();
          _lastViewport = viewport;
          
          // Emit to stream
          _beaconsStreamController.add(beacons);
          
          // Reset rate limiting on successful request
          _resetRateLimiting();

          _logger.i('✅ Fetched ${beacons.length} SafeSky beacons');
        } else {
          _logger.w('⚠️ Unexpected response format from SafeSky API');
        }
      } else if (response.statusCode == 429) {
        // Rate limited - extract retry-after if provided
        final retryAfterHeader = response.headers['retry-after'];
        final retryAfterSeconds = retryAfterHeader != null 
            ? int.tryParse(retryAfterHeader) 
            : null;
        
        _handleRateLimit(retryAfterSeconds);
        
        // Try to parse error message
        try {
          final errorData = json.decode(response.body);
          _logger.w('⚠️ Rate limited: ${errorData['message'] ?? 'Too many requests'}');
        } catch (e) {
          _logger.w('⚠️ Rate limited (429)');
        }
      } else if (response.statusCode == 404) {
        // API endpoint not found - likely backend not deployed yet
        _logger.w('⚠️ SafeSky backend not available (404). Using mock data for development.');
        _createMockData(viewport);
      } else {
        _logger.w('⚠️ SafeSky API error: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (e.toString().contains('Failed host lookup') || 
          e.toString().contains('Connection refused') ||
          e.toString().contains('No route to host')) {
        // Network/DNS error - likely backend not deployed yet
        _logger.w('⚠️ SafeSky backend not available. Using mock data for development.');
        _createMockData(viewport);
      } else {
        _logger.e('❌ Error fetching SafeSky beacons: $e');
        rethrow;
      }
    }
  }

  /// Create mock beacon data for development/testing purposes
  void _createMockData(LatLngBounds viewport) {
    final center = viewport.center;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    // Create a few mock beacons around the viewport center
    final mockBeacons = [
      SafeSkyBeacon(
        id: 'MOCK001',
        latitude: center.latitude + 0.01,
        longitude: center.longitude + 0.01,
        altitude: 1500, // meters
        callSign: 'VFR123',
        groundSpeed: 55, // m/s (≈110 knots)
        course: 90,
        status: 'AIRBORNE',
        lastUpdate: now - 5,
        verticalRate: 2, // climbing
        beaconType: 'JET',
        transponderType: 'ADS-B',
      ),
      SafeSkyBeacon(
        id: 'MOCK002',
        latitude: center.latitude + 0.015,
        longitude: center.longitude - 0.015,
        altitude: 1200,
        callSign: 'GLI456',
        groundSpeed: 25,
        course: 180,
        status: 'AIRBORNE',
        lastUpdate: now - 8,
        verticalRate: 0,
        beaconType: 'GLIDER',
      ),
      SafeSkyBeacon(
        id: 'MOCK003',
        latitude: center.latitude - 0.01,
        longitude: center.longitude - 0.02,
        altitude: 500,
        callSign: 'HELI99',
        groundSpeed: 35,
        course: 270,
        status: 'AIRBORNE',
        lastUpdate: now - 10,
        verticalRate: -2, // descending
        beaconType: 'HELICOPTER',
        transponderType: 'ADS-B',
      ),
      SafeSkyBeacon(
        id: 'MOCK004',
        latitude: center.latitude - 0.005,
        longitude: center.longitude - 0.01,
        altitude: 300,
        callSign: 'PARA42',
        groundSpeed: 15,
        course: 45,
        status: 'AIRBORNE',
        lastUpdate: now - 15,
        verticalRate: 0,
        beaconType: 'PARA_GLIDER',
      ),
    ];

    _beaconsCache = mockBeacons;
    _lastFetch = DateTime.now();
    _lastViewport = viewport;
    
    // Emit to stream
    _beaconsStreamController.add(mockBeacons);

    _logger.i('✅ Created ${mockBeacons.length} mock SafeSky beacons for development');
  }

  /// Get beacons within a specific radius of a point
  List<SafeSkyBeacon> getBeaconsNear(LatLng center, double radiusKm) {
    return _beaconsCache.where((beacon) {
      final distance = const Distance().as(LengthUnit.Kilometer, center, beacon.position);
      return distance <= radiusKm;
    }).toList();
  }

  /// Get beacon by ID
  SafeSkyBeacon? getBeaconById(String id) {
    try {
      return _beaconsCache.firstWhere((beacon) => beacon.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Dispose of resources
  void dispose() {
    stopTracking();
    _beaconsStreamController.close();
    _client.close();
  }

  /// Filter beacons by type
  List<SafeSkyBeacon> getBeaconsByType(String beaconType) {
    return _beaconsCache
        .where((beacon) => beacon.beaconType == beaconType)
        .toList();
  }

  /// Get statistics about current beacons
  Map<String, dynamic> getStatistics() {
    return {
      'total': _beaconsCache.length,
      'airborne': _beaconsCache.where((b) => b.status == 'AIRBORNE').length,
      'grounded': _beaconsCache.where((b) => b.status == 'GROUNDED').length,
      'byType': {
        'jets': getBeaconsByType('JET').length,
        'helicopters': getBeaconsByType('HELICOPTER').length,
        'gliders': getBeaconsByType('GLIDER').length,
        'paragliders': getBeaconsByType('PARA_GLIDER').length,
        'other': _beaconsCache.where((b) => 
          b.beaconType != 'JET' && 
          b.beaconType != 'HELICOPTER' && 
          b.beaconType != 'GLIDER' && 
          b.beaconType != 'PARA_GLIDER'
        ).length,
      },
      'lastUpdate': _lastFetch?.toIso8601String(),
      'refreshInterval': _currentRefreshInterval.inSeconds,
      'rateLimited': _consecutiveRateLimits > 0,
    };
  }

  /// Force an immediate refresh
  Future<void> refreshNow() async {
    if (_lastViewport != null) {
      _lastFetch = null; // Force cache invalidation
      await _fetchBeacons(_lastViewport!);
    }
  }
  
  /// Validate beacon data for safety
  bool _isValidBeacon(SafeSkyBeacon beacon) {
    // Check latitude is valid (-90 to 90)
    if (beacon.latitude < -90 || beacon.latitude > 90) {
      _logger.w('Invalid latitude: ${beacon.latitude}');
      return false;
    }
    
    // Check longitude is valid (-180 to 180)
    if (beacon.longitude < -180 || beacon.longitude > 180) {
      _logger.w('Invalid longitude: ${beacon.longitude}');
      return false;
    }
    
    // Check altitude is reasonable (below 60,000 feet / ~18,000 meters)
    if (beacon.altitude < -500 || beacon.altitude > 18000) {
      _logger.w('Invalid altitude: ${beacon.altitude}m');
      return false;
    }
    
    // Check ground speed is reasonable (below 700 m/s / ~1400 knots)
    if (beacon.groundSpeed < 0 || beacon.groundSpeed > 700) {
      _logger.w('Invalid ground speed: ${beacon.groundSpeed} m/s');
      return false;
    }
    
    // Check course is valid (0-360)
    if (beacon.course < 0 || beacon.course > 360) {
      _logger.w('Invalid course: ${beacon.course}');
      return false;
    }
    
    return true;
  }
}