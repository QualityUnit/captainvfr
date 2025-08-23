import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../models/safesky_beacon.dart';

/// Service for fetching and managing SafeSky beacon data
class SafeSkyService {
  // SafeSky backend proxy URL
  static const String _baseUrl = 'https://imuwdhmbde.execute-api.eu-central-1.amazonaws.com/prod';
  static const Duration _cacheDuration = Duration(seconds: 20);
  static const Duration _refreshInterval = Duration(seconds: 20);
  
  final _logger = Logger(
    level: Level.warning, // Only log warnings and errors in production
  );
  final _client = http.Client();

  // Cache management
  List<SafeSkyBeacon> _beaconsCache = [];
  DateTime? _lastFetch;
  LatLngBounds? _lastViewport;
  Future<void>? _ongoingFetch;
  Timer? _refreshTimer;
  bool _isActive = false;
  
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
    
    // Initial fetch
    await _fetchBeacons(viewport);
    
    // Set up periodic refresh
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (timer) {
      if (_isActive && _lastViewport != null) {
        _fetchBeacons(_lastViewport!);
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
              .map((json) => SafeSkyBeacon.fromJson(json))
              .where((beacon) => beacon.isRecent) // Filter old data
              .toList();

          _beaconsCache = beacons;
          _lastFetch = DateTime.now();
          _lastViewport = viewport;
          
          // Emit to stream
          _beaconsStreamController.add(beacons);

          _logger.i('✅ Fetched ${beacons.length} SafeSky beacons');
        } else {
          _logger.w('⚠️ Unexpected response format from SafeSky API');
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
        lastUpdate: now,
        verticalRate: 3, // climbing
        beaconType: 'MOTORPLANE',
        transponderType: 'ADS-B',
      ),
      SafeSkyBeacon(
        id: 'MOCK002',
        latitude: center.latitude - 0.015,
        longitude: center.longitude + 0.005,
        altitude: 2000,
        callSign: 'GLIDER1',
        groundSpeed: 25,
        course: 180,
        status: 'AIRBORNE',
        lastUpdate: now - 5,
        verticalRate: 1,
        beaconType: 'GLIDER',
      ),
      SafeSkyBeacon(
        id: 'MOCK003',
        latitude: center.latitude + 0.005,
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
        .where((beacon) => beacon.beaconType?.toUpperCase() == beaconType.toUpperCase())
        .toList();
  }

  /// Filter beacons by status
  List<SafeSkyBeacon> getBeaconsByStatus(String status) {
    return _beaconsCache
        .where((beacon) => beacon.status?.toUpperCase() == status.toUpperCase())
        .toList();
  }

  /// Get only airborne beacons
  List<SafeSkyBeacon> get airborneBeacons {
    return _beaconsCache.where((beacon) => beacon.isAirborne).toList();
  }

  /// Get statistics about current beacon data
  Map<String, dynamic> get statistics {
    final total = _beaconsCache.length;
    final airborne = airborneBeacons.length;
    final grounded = _beaconsCache.where((b) => b.isGrounded).length;
    final inactive = _beaconsCache.where((b) => b.isInactive).length;
    
    final typeStats = <String, int>{};
    for (final beacon in _beaconsCache) {
      final type = beacon.beaconType ?? 'UNKNOWN';
      typeStats[type] = (typeStats[type] ?? 0) + 1;
    }

    return {
      'total': total,
      'airborne': airborne,
      'grounded': grounded,
      'inactive': inactive,
      'types': typeStats,
      'lastUpdate': _lastFetch,
      'isActive': _isActive,
    };
  }

  /// Force refresh beacon data
  Future<void> forceRefresh() async {
    if (_lastViewport != null) {
      _lastFetch = null; // Force cache invalidation
      await _fetchBeacons(_lastViewport!);
    }
  }
}