import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/map_constants.dart';

class MapStateController extends ChangeNotifier {
  // Preference keys for layer states
  static const String _keyShowNavaids = 'map_show_navaids';
  static const String _keyShowMetar = 'map_show_metar';
  static const String _keyShowStats = 'map_show_stats';
  static const String _keyShowHeliports = 'map_show_heliports';
  static const String _keyShowAirspaces = 'map_show_airspaces';
  static const String _keyShowObstacles = 'map_show_obstacles';
  static const String _keyShowHotspots = 'map_show_hotspots';
  static const String _keyShowHeatmap = 'map_show_heatmap';
  static const String _keyShowSafeSky = 'map_show_safesky';
  static const String _keyShowTerrain = 'map_show_terrain';
  static const String _keyShowElevation = 'map_show_elevation';
  
  late SharedPreferences _prefs;
  bool _prefsInitialized = false;

  // Location and map state
  Position? _currentPosition;
  LatLng? _selectedWaypoint;
  
  // Auto-centering control
  bool _autoCenteringEnabled = false;
  Timer? _autoCenteringTimer;
  Timer? _countdownTimer;
  int _autoCenteringCountdown = 0;
  
  // Position tracking control
  bool _positionTrackingEnabled = false;
  Timer? _positionUpdateTimer;
  
  // UI state
  bool _locationLoading = true;
  bool _isDraggingWaypoint = false;
  
  // Layer visibility states
  bool _showNavaids = false;
  bool _showMetar = true;  // Default to showing weather
  bool _showStats = false;
  bool _showHeliports = false;
  bool _showAirspaces = true;  // Default to showing airspaces
  bool _showObstacles = false;
  bool _showHotspots = false;
  bool _showHeatmap = false;  // Flight tracking heatmap (default OFF)
  bool _showSafeSky = true;  // SafeSky aircraft beacons (default ON for safety)
  bool _showTerrain = false;  // Terrain danger zones (default OFF, performance impact)
  bool _showElevation = false;  // Elevation grid (default OFF, performance impact)
  
  // Menu panel state
  bool _isMenuPanelOpen = false;

  // Getters
  Position? get currentPosition => _currentPosition;
  LatLng? get selectedWaypoint => _selectedWaypoint;
  bool get autoCenteringEnabled => _autoCenteringEnabled;
  int get autoCenteringCountdown => _autoCenteringCountdown;
  bool get positionTrackingEnabled => _positionTrackingEnabled;
  bool get locationLoading => _locationLoading;
  bool get isDraggingWaypoint => _isDraggingWaypoint;
  
  // Layer visibility getters
  bool get showNavaids => _showNavaids;
  bool get showMetar => _showMetar;
  bool get showStats => _showStats;
  bool get showHeliports => _showHeliports;
  bool get showAirspaces => _showAirspaces;
  bool get showObstacles => _showObstacles;
  bool get showHotspots => _showHotspots;
  bool get showHeatmap => _showHeatmap;
  bool get showSafeSky => _showSafeSky;
  bool get showTerrain => _showTerrain;
  bool get showElevation => _showElevation;
  bool get isMenuPanelOpen => _isMenuPanelOpen;
  
  // Initialize and load saved preferences
  Future<void> init() async {
    if (_prefsInitialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    
    // Load saved states with defaults
    _showNavaids = _prefs.getBool(_keyShowNavaids) ?? false;
    _showMetar = _prefs.getBool(_keyShowMetar) ?? true;
    _showStats = _prefs.getBool(_keyShowStats) ?? false;
    _showHeliports = _prefs.getBool(_keyShowHeliports) ?? false;
    _showAirspaces = _prefs.getBool(_keyShowAirspaces) ?? true;
    _showObstacles = _prefs.getBool(_keyShowObstacles) ?? false;
    _showHotspots = _prefs.getBool(_keyShowHotspots) ?? false;
    _showHeatmap = _prefs.getBool(_keyShowHeatmap) ?? false;
    _showSafeSky = _prefs.getBool(_keyShowSafeSky) ?? true;  // Default to true for new users
    _showTerrain = _prefs.getBool(_keyShowTerrain) ?? false;  // Default to false for performance
    _showElevation = _prefs.getBool(_keyShowElevation) ?? false;  // Default to false for performance
    
    _prefsInitialized = true;
    notifyListeners();
  }

  // Update current position
  void updatePosition(Position position) {
    _currentPosition = position;
    _locationLoading = false;
    notifyListeners();
  }

  // Set selected waypoint
  void setSelectedWaypoint(LatLng? waypoint) {
    _selectedWaypoint = waypoint;
    notifyListeners();
  }

  // Set dragging waypoint state
  void setDraggingWaypoint(bool isDragging) {
    _isDraggingWaypoint = isDragging;
    notifyListeners();
  }

  // Toggle layer visibility
  void toggleNavaids() {
    _showNavaids = !_showNavaids;
    if (_prefsInitialized) {
      _prefs.setBool(_keyShowNavaids, _showNavaids);
    }
    notifyListeners();
  }

  void toggleMetar() {
    _showMetar = !_showMetar;
    if (_prefsInitialized) {
      _prefs.setBool(_keyShowMetar, _showMetar);
    }
    notifyListeners();
  }

  void toggleStats() {
    _showStats = !_showStats;
    if (_prefsInitialized) {
      _prefs.setBool(_keyShowStats, _showStats);
    }
    notifyListeners();
  }

  void toggleHeliports() {
    _showHeliports = !_showHeliports;
    if (_prefsInitialized) {
      _prefs.setBool(_keyShowHeliports, _showHeliports);
    }
    notifyListeners();
  }

  void toggleAirspaces() {
    _showAirspaces = !_showAirspaces;
    if (_prefsInitialized) {
      _prefs.setBool(_keyShowAirspaces, _showAirspaces);
    }
    notifyListeners();
  }

  void toggleObstacles() {
    _showObstacles = !_showObstacles;
    if (_prefsInitialized) {
      _prefs.setBool(_keyShowObstacles, _showObstacles);
    }
    notifyListeners();
  }

  void toggleHotspots() {
    _showHotspots = !_showHotspots;
    if (_prefsInitialized) {
      _prefs.setBool(_keyShowHotspots, _showHotspots);
    }
    notifyListeners();
  }

  void toggleHeatmap() {
    _showHeatmap = !_showHeatmap;
    if (_prefsInitialized) {
      _prefs.setBool(_keyShowHeatmap, _showHeatmap);
    }
    notifyListeners();
  }

  void toggleSafeSky() {
    _showSafeSky = !_showSafeSky;
    if (_prefsInitialized) {
      _prefs.setBool(_keyShowSafeSky, _showSafeSky);
    }
    notifyListeners();
  }

  void toggleTerrain() {
    _showTerrain = !_showTerrain;
    if (_prefsInitialized) {
      _prefs.setBool(_keyShowTerrain, _showTerrain);
    }
    notifyListeners();
  }

  void toggleElevation() {
    _showElevation = !_showElevation;
    if (_prefsInitialized) {
      _prefs.setBool(_keyShowElevation, _showElevation);
    }
    notifyListeners();
  }

  // Menu panel methods
  void toggleMenuPanel() {
    _isMenuPanelOpen = !_isMenuPanelOpen;
    notifyListeners();
  }

  void closeMenuPanel() {
    _isMenuPanelOpen = false;
    notifyListeners();
  }

  void openMenuPanel() {
    _isMenuPanelOpen = true;
    notifyListeners();
  }

  // Auto-centering methods
  void enableAutoCentering() {
    _autoCenteringEnabled = true;
    _autoCenteringCountdown = 0;
    _cancelAutoCenteringTimers();
    notifyListeners();
  }

  void disableAutoCentering() {
    _autoCenteringEnabled = false;
    notifyListeners();
  }

  void startAutoCenteringCountdown() {
    _autoCenteringTimer?.cancel();
    _countdownTimer?.cancel();
    
    // Start countdown
    _autoCenteringCountdown = MapConstants.autoCenteringDelay.inSeconds;
    notifyListeners();
    
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_autoCenteringCountdown > 0) {
        _autoCenteringCountdown--;
        notifyListeners();
      }
    });
    
    // Enable auto-centering after delay
    _autoCenteringTimer = Timer(MapConstants.autoCenteringDelay, () {
      enableAutoCentering();
    });
  }

  void _cancelAutoCenteringTimers() {
    _autoCenteringTimer?.cancel();
    _countdownTimer?.cancel();
    _autoCenteringTimer = null;
    _countdownTimer = null;
  }

  // Position tracking methods
  void enablePositionTracking() {
    _positionTrackingEnabled = true;
    _autoCenteringEnabled = true;
    notifyListeners();
  }

  void disablePositionTracking() {
    _positionTrackingEnabled = false;
    _autoCenteringEnabled = false;
    _cancelAutoCenteringTimers();
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = null;
    notifyListeners();
  }

  void togglePositionTracking() {
    if (_positionTrackingEnabled) {
      disablePositionTracking();
    } else {
      enablePositionTracking();
    }
  }

  void pauseAllTimers() {
    _positionUpdateTimer?.cancel();
    _autoCenteringTimer?.cancel();
    _countdownTimer?.cancel();
  }

  void resumeAllTimers() {
    // Resume timers if they were active
    if (_positionTrackingEnabled && _positionUpdateTimer == null) {
      // Restart position update timer
      // Note: The actual timer setup should be handled by the map screen
    }
    if (_autoCenteringCountdown > 0) {
      startAutoCenteringCountdown();
    }
  }

  @override
  void dispose() {
    _cancelAutoCenteringTimers();
    _positionUpdateTimer?.cancel();
    super.dispose();
  }
}