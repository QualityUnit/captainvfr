import 'dart:convert';
import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import '../models/safesky_beacon.dart';
import '../config/environment.dart';

/// Message for isolate communication
class IsolateMessage {
  final String type;
  final dynamic data;
  
  IsolateMessage(this.type, this.data);
}

/// Response from isolate
class IsolateResponse {
  final String type;
  final dynamic data;
  final String? error;
  
  IsolateResponse(this.type, this.data, [this.error]);
}

/// Isolate function that runs in background
void _isolateEntryPoint(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);
  
  final client = http.Client();
  Duration currentRefreshInterval = const Duration(seconds: 5);
  int consecutiveRateLimits = 0;
  
  receivePort.listen((message) async {
    if (message is IsolateMessage) {
      switch (message.type) {
        case 'fetch':
          try {
            final params = message.data as Map<String, dynamic>;
            final viewport = params['viewport'] as String;
            final baseUrl = params['baseUrl'] as String;
            
            final url = '$baseUrl/beacons?viewport=$viewport';
            
            final response = await client.get(
              Uri.parse(url),
              headers: {
                'Content-Type': 'application/json',
                'Accept': 'application/json',
              },
            ).timeout(const Duration(seconds: 30));
            
            if (response.statusCode == 200) {
              consecutiveRateLimits = 0;
              currentRefreshInterval = const Duration(seconds: 5);
              sendPort.send(IsolateResponse('beacons', response.body));
            } else if (response.statusCode == 429) {
              consecutiveRateLimits++;
              final backoffMultiplier = math.min(consecutiveRateLimits, 4);
              currentRefreshInterval = Duration(seconds: 5 * math.pow(2, backoffMultiplier).toInt());
              
              final retryAfterHeader = response.headers['retry-after'];
              final retryAfterSeconds = retryAfterHeader != null 
                  ? int.tryParse(retryAfterHeader) 
                  : null;
              
              sendPort.send(IsolateResponse('rateLimit', {
                'interval': currentRefreshInterval.inSeconds,
                'retryAfter': retryAfterSeconds,
              }));
            } else {
              sendPort.send(IsolateResponse('error', null, 'HTTP ${response.statusCode}'));
            }
          } catch (e) {
            sendPort.send(IsolateResponse('error', null, e.toString()));
          }
          break;
          
        case 'dispose':
          client.close();
          Isolate.current.kill();
          break;
      }
    }
  });
}

/// Isolate-based SafeSky service for background network operations
class SafeSkyIsolateService {
  static String get _baseUrl => Environment.safeSkyApiUrl;
  static const Duration _minRefreshInterval = Duration(seconds: 5);
  // Maximum refresh interval for rate limiting
  // static const Duration _maxRefreshInterval = Duration(seconds: 30);
  static Duration get _cacheDuration => Environment.beaconCacheDuration;
  
  Isolate? _isolate;
  SendPort? _sendPort;
  final _receivePort = ReceivePort();
  StreamSubscription? _isolateSubscription;
  
  // Cache management
  List<SafeSkyBeacon> _beaconsCache = [];
  DateTime? _lastFetch;
  LatLngBounds? _lastViewport;
  Timer? _refreshTimer;
  bool _isActive = false;
  Duration _currentRefreshInterval = _minRefreshInterval;
  
  // Stream controller for beacon updates
  final _beaconsStreamController = StreamController<List<SafeSkyBeacon>>.broadcast();
  Stream<List<SafeSkyBeacon>> get beaconsStream => _beaconsStreamController.stream;
  
  /// Initialize the isolate
  Future<void> initialize() async {
    if (_isolate != null) return;
    
    _isolate = await Isolate.spawn(_isolateEntryPoint, _receivePort.sendPort);
    
    // Get the send port from isolate
    final completer = Completer<SendPort>();
    _isolateSubscription = _receivePort.listen((message) {
      if (message is SendPort) {
        completer.complete(message);
      } else if (message is IsolateResponse) {
        _handleIsolateResponse(message);
      }
    });
    
    _sendPort = await completer.future;
  }
  
  /// Handle responses from isolate
  void _handleIsolateResponse(IsolateResponse response) {
    switch (response.type) {
      case 'beacons':
        try {
          final jsonData = json.decode(response.data);
          if (jsonData is List) {
            final beacons = jsonData
                .map((json) {
                  try {
                    return SafeSkyBeacon.fromJson(json);
                  } catch (e) {
                    return null;
                  }
                })
                .whereType<SafeSkyBeacon>()
                .where((beacon) => beacon.isRecent)
                .toList();
            
            _beaconsCache = beacons;
            _lastFetch = DateTime.now();
            _beaconsStreamController.add(beacons);
            
            // Reset refresh interval on success
            _currentRefreshInterval = _minRefreshInterval;
          }
        } catch (e) {
          debugPrint('Error parsing beacon data: $e');
        }
        break;
        
      case 'rateLimit':
        final data = response.data as Map<String, dynamic>;
        _currentRefreshInterval = Duration(seconds: data['interval']);
        debugPrint('Rate limited. New interval: ${_currentRefreshInterval.inSeconds}s');
        break;
        
      case 'error':
        debugPrint('Isolate error: ${response.error}');
        // Create mock data on error
        if (_lastViewport != null) {
          _createMockData(_lastViewport!);
        }
        break;
    }
    
    // Schedule next refresh
    _scheduleNextRefresh();
  }
  
  /// Start tracking
  Future<void> startTracking(LatLngBounds viewport) async {
    await initialize();
    
    _isActive = true;
    _lastViewport = viewport;
    _currentRefreshInterval = _minRefreshInterval;
    
    await _fetchBeacons(viewport);
    _scheduleNextRefresh();
  }
  
  /// Stop tracking
  void stopTracking() {
    _isActive = false;
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
  
  /// Update viewport
  Future<void> updateViewport(LatLngBounds viewport) async {
    if (!_isActive) return;
    
    _lastViewport = viewport;
    
    if (_shouldRefreshForViewport(viewport)) {
      await _fetchBeacons(viewport);
    }
  }
  
  /// Fetch beacons via isolate
  Future<void> _fetchBeacons(LatLngBounds viewport) async {
    if (_sendPort == null) return;
    
    // Check cache validity
    if (hasRecentData && !_shouldRefreshForViewport(viewport)) {
      return;
    }
    
    final viewportParam = '${viewport.south},${viewport.west},${viewport.north},${viewport.east}';
    
    _sendPort!.send(IsolateMessage('fetch', {
      'viewport': viewportParam,
      'baseUrl': _baseUrl,
    }));
    
    _lastViewport = viewport;
  }
  
  /// Schedule next refresh
  void _scheduleNextRefresh() {
    _refreshTimer?.cancel();
    
    if (!_isActive || _lastViewport == null) return;
    
    _refreshTimer = Timer(_currentRefreshInterval, () {
      if (_isActive && _lastViewport != null) {
        _fetchBeacons(_lastViewport!);
      }
    });
  }
  
  /// Check if should refresh for viewport
  bool _shouldRefreshForViewport(LatLngBounds newViewport) {
    if (_lastViewport == null) return true;
    
    const double tolerance = 0.1;
    
    return newViewport.south < (_lastViewport!.south - tolerance) ||
           newViewport.north > (_lastViewport!.north + tolerance) ||
           newViewport.west < (_lastViewport!.west - tolerance) ||
           newViewport.east > (_lastViewport!.east + tolerance);
  }
  
  /// Check if data is recent
  bool get hasRecentData {
    if (_lastFetch == null) return false;
    return DateTime.now().difference(_lastFetch!) < _cacheDuration;
  }
  
  /// Get current beacons
  List<SafeSkyBeacon> get beacons => List.unmodifiable(_beaconsCache);
  
  /// Create mock data for development
  void _createMockData(LatLngBounds viewport) {
    final center = viewport.center;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    
    final mockBeacons = [
      SafeSkyBeacon(
        id: 'MOCK001',
        latitude: center.latitude + 0.01,
        longitude: center.longitude + 0.01,
        altitude: 1500,
        callSign: 'VFR123',
        groundSpeed: 55,
        course: 90,
        status: 'AIRBORNE',
        lastUpdate: now - 5,
        verticalRate: 2,
        beaconType: 'JET',
        transponderType: 'ADS-B',
      ),
    ];
    
    _beaconsCache = mockBeacons;
    _lastFetch = DateTime.now();
    _beaconsStreamController.add(mockBeacons);
  }
  
  /// Dispose the service
  void dispose() {
    _isActive = false;
    _refreshTimer?.cancel();
    _sendPort?.send(IsolateMessage('dispose', null));
    _isolate?.kill(priority: Isolate.immediate);
    _isolateSubscription?.cancel();
    _receivePort.close();
    _beaconsStreamController.close();
  }
}