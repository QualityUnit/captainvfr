// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'dart:math' as math;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:logger/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'flight_log_screen.dart';
import 'aircraft_settings_screen.dart';
import 'checklist_settings_screen.dart';
import 'calculators_screen.dart';
import 'settings_screen.dart';
import 'logbook/logbook_screen.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';
import '../models/airport.dart';
import '../models/runway.dart';
import '../models/navaid.dart';
import '../models/obstacle.dart';
import '../models/hotspot.dart';
import '../models/flight_segment.dart' as flight_seg;
import '../models/flight_plan.dart';
import '../services/airport_service.dart';
import '../services/tiled_data_loader.dart';
import '../services/runway_service.dart';
import '../services/navaid_service.dart';
import '../services/search_history_service.dart';
import '../services/flight_service.dart';
import '../services/heading_service.dart';
import '../services/location_service.dart';
import '../services/weather_service.dart';
import '../services/safesky_service.dart';
import '../models/safesky_beacon.dart';
import '../services/offline_map_service.dart';
import '../services/offline_tile_provider.dart';
import '../services/flight_plan_service.dart';
import '../services/flight_plan_tile_download_service.dart';
import '../screens/offline_data/controllers/offline_data_state_controller.dart';
import '../widgets/navaid_marker.dart';
import '../widgets/optimized_marker_layer.dart';
import '../widgets/optimized_heatmap_layer.dart';
import '../services/flight_heatmap_processor.dart';
import '../widgets/airport_info_sheet.dart';
import 'map/components/center_button.dart';
import '../widgets/flight_tracking_panel.dart';
import '../widgets/airport_search_dialog.dart';
import '../widgets/metar_overlay.dart';
import 'map/overlays/animated_safesky_overlay.dart';
import 'map/overlays/terrain_danger_overlay.dart';
import 'map/overlays/terrain_relief_overlay.dart';
import 'map/overlays/simple_airspaces_3d_overlay.dart';
import 'map/overlays/obstacles_3d_overlay.dart';
import 'map/overlays/safesky_3d_overlay.dart';
import '../widgets/flight_plan_overlay.dart';
import '../widgets/flight_planning_panel.dart';
import '../widgets/license_warning_widget.dart';
import '../widgets/floating_waypoint_panel.dart';
import '../widgets/optimized_spatial_airspaces_overlay.dart';
import '../widgets/airspace_flight_info.dart';
import '../widgets/airspace_frequency_display.dart';
import '../utils/frame_aware_scheduler.dart';
import '../widgets/sensor_notification_widget.dart';
import '../utils/performance_monitor.dart';
import '../services/openaip_service.dart';
import '../services/analytics_service.dart';
import '../services/spatial_airspace_service.dart';
import '../services/settings_service.dart';
import '../models/airspace.dart';
import '../models/reporting_point.dart';
import '../utils/airspace_utils.dart';
import '../widgets/loading_progress_bar.dart';
import '../widgets/themed_dialog.dart';
import '../widgets/map_zoom_controls.dart';
import '../widgets/terrain_warning_display.dart';
import '../services/cache_service.dart';
import '../services/notam_service_v3.dart';
import '../services/terrain_elevation_service.dart';
import '../widgets/emergency_panel.dart';
import '../widgets/gesture_hints_overlay.dart';
import '../widgets/map_overlay_indicators.dart';

// Extracted components
import 'map/constants/map_constants.dart';
import 'map/controllers/map_state_controller.dart';
import 'package:flutter/foundation.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver, RouteAware {
  // UI Constants
  static const double _airspacePanelHeight = 250.0;
  static const double _airspacePanelBottomOffset = 350.0;
  static const double _minPanelVisibility = 50.0;
  static const double _menuButtonWidth = 48.0;
  static const double _menuButtonMargin = 16.0;
  static const double _buttonSpacing = 12.0;
  
  // Logger
  final Logger _logger = Logger(level: Level.warning);
  
  // Controllers
  late MapStateController _mapStateController;
  
  // Services
  late final FlightService _flightService;
  late final HeadingService _headingService;
  late final AirportService _airportService;
  late final RunwayService _runwayService;
  late final NavaidService _navaidService;
  late final LocationService _locationService;
  late final WeatherService _weatherService;
  late final SafeSkyService _safeSkyService;
  OfflineMapService?
  _offlineMapService; // Make nullable to prevent LateInitializationError
  late final FlightPlanService _flightPlanService;
  FlightPlanTileDownloadService? _tileDownloadService;
  OfflineDataStateController? _offlineDataController;
  OpenAIPService? _openAIPService;
  SpatialAirspaceService? _spatialAirspaceService;
  late final MapController _mapController;
  late final CacheService _cacheService;
  Timer? _performanceReportTimer;

  // Getter to ensure OpenAIPService is available
  OpenAIPService get openAIPService {
    if (_openAIPService == null && mounted) {
      try {
        _openAIPService = Provider.of<OpenAIPService>(context, listen: false);
      } catch (e) {
        // debugPrint('⚠️ OpenAIPService still not available, using singleton');
        _openAIPService =
            OpenAIPService(); // This returns the singleton instance
      }
    }
    return _openAIPService!;
  }

  // Getter to ensure SpatialAirspaceService is available
  SpatialAirspaceService get spatialAirspaceService {
    _spatialAirspaceService ??= SpatialAirspaceService(openAIPService);
    return _spatialAirspaceService!;
  }

  final GlobalKey _mapKey = GlobalKey();

  // State variables
  bool _isLocationLoaded = false; // Track if location has been loaded
  bool _locationNotificationShown = false; // Track if we've shown the location notification
  bool _servicesInitialized = false;
  bool _isInitializing = false; // Guard against concurrent initialization
  bool _showFlightPlanning = false; // Toggle for integrated flight planning
  MapRotationMode? _previousRotationMode; // Track rotation mode changes
  double _mapTilt = 0.0; // 3D tilt angle (0 = flat, 45 = tilted)
  Timer? _debounceTimer;
  Timer? _airspaceDebounceTimer;
  Timer? _notamPrefetchTimer;
  bool _waypointJustTapped =
      false; // Flag to prevent airspace popup when waypoint is tapped
  int _notamFetchGeneration =
      0; // Track NOTAM fetch generations to cancel outdated requests

  // Flight tracking panel state is now handled internally by FlightTrackingPanel

  // Airspace panel visibility and position
  bool _showCurrentAirspacePanel =
      false; // Control visibility of current airspace panel
  Offset? _airspacePanelPosition; // Will be calculated dynamically to center initially


  // Flight planning panel position and state
  Offset _flightPlanningPanelPosition = const Offset(
    16,
    100,
  ); // Default position
  bool _flightPlanningExpanded =
      false; // Track expanded state of flight planning panel (default collapsed)
  Size? _lastFlightPlanningScreenSize; // Track screen size for position adjustment

  // Waypoint selection state
  int? _selectedWaypointIndex;
  bool _isDraggingWaypoint = false;
  
  // Altitude profile selection state
  LatLng? _profileSelectedPoint;
  double? _profileSelectedAltitude;
  // Note: _profileSelectedDistance is stored but not currently used in the UI
  // It could be used to show distance info on the map in the future
  // ignore: unused_field
  double? _profileSelectedDistance; // Distance along the flight path
  
  // Emergency panel and gesture hints state
  bool _showEmergencyPanel = false;
  bool _showGestureHints = false;

  // Location and map state
  Position? _currentPosition;
  double? _cachedHeading; // Cache current heading to avoid repeated property access
  List<LatLng> _flightPathPoints = [];
  List<flight_seg.FlightSegment> _flightSegments = [];
  List<Airport> _airports = [];
  Map<String, List<Runway>> _airportRunways = {};
  List<Navaid> _navaids = [];
  List<ReportingPoint> _reportingPoints = [];
  List<Obstacle> _obstacles = [];
  List<Hotspot> _hotspots = [];

  // UI state
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Map settings are now in MapConstants

  // Auto-centering control
  bool _autoCenteringEnabled = false;  // Start with auto-centering disabled
  Timer? _autoCenteringTimer;
  // Auto-centering delay is now in MapConstants
  bool _wasTracking = false;
  
  // Countdown display for auto-centering
  int _autoCenteringCountdown = 0;
  Timer? _countdownTimer;
  
  // Position tracking control
  bool _positionTrackingEnabled = true;  // Default to enabled
  Timer? _positionUpdateTimer;
  // Position update interval is now in MapConstants

  // Helper to check if any input field has focus
  bool get _hasInputFocus {
    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus == null) return false;
    
    // Check if the focused widget is a text input
    final focusedWidget = primaryFocus.context?.widget;
    return focusedWidget is EditableText || 
           primaryFocus.context?.widget.toString().contains('TextField') == true ||
           primaryFocus.context?.widget.toString().contains('TextFormField') == true;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize controllers
    _mapController = MapController();
    _mapStateController = MapStateController();
    
    // Initialize map state controller preferences
    _mapStateController.init().then((_) {
      // After preferences are loaded, check if SafeSky should be started
      if (_mapStateController.showSafeSky) {
        // Wait for map to be ready before starting SafeSky
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _servicesInitialized) {
            _startSafeSkyTracking();
          }
        });
      }
    });

    // Load flight planning panel state from SharedPreferences
    _loadFlightPlanningPanelState();

    // Start location loading in background without blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showLocationLoadingNotification();
      _initLocationInBackground();
      
      // Check if gesture hints should be shown
      _checkGestureHints();
      
      // Log screen view
      final analytics = Provider.of<AnalyticsService>(context, listen: false);
      analytics.logScreenView(screenName: 'map_screen');
    });
  }
  
  // Check and show gesture hints for first-time users
  Future<void> _checkGestureHints() async {
    final shouldShow = await GestureHintsOverlay.shouldShow();
    if (shouldShow && mounted) {
      // Delay showing hints to let map load first
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showGestureHints = true;
          });
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialize services from Provider to ensure they're properly initialized
    if (!_servicesInitialized) {
      try {
        _flightService = Provider.of<FlightService>(context, listen: false);
        _headingService = Provider.of<HeadingService>(context, listen: false);
        _locationService = Provider.of<LocationService>(context, listen: false);
        _airportService = Provider.of<AirportService>(context, listen: false);
        _runwayService = RunwayService();
        // Initialize runway service
        _runwayService.initialize();
        _navaidService = Provider.of<NavaidService>(context, listen: false);
        _weatherService = Provider.of<WeatherService>(context, listen: false);
        _safeSkyService = SafeSkyService();
        // Initialize SafeSky service
        _safeSkyService.initialize();
        _flightPlanService = Provider.of<FlightPlanService>(
          context,
          listen: false,
        );
        
        
        // Set up callback to fit entire flight plan when loaded
        _flightPlanService.onFlightPlanLoaded = (flightPlan) {
          if (flightPlan.waypoints.isNotEmpty) {
            // Fit the entire flight plan in view
            _fitFlightPlanBounds();
            
            // Load data for the new area
            _loadAirports();
            if (_mapStateController.showNavaids) {
              _loadNavaids();
            }
            if (_mapStateController.showAirspaces) {
              _loadAirspaces();
              _loadReportingPoints();
            }
            if (_mapStateController.showMetar) {
              _loadWeatherForVisibleAirports();
            }
          }
        };
        
        _cacheService = Provider.of<CacheService>(context, listen: false);

        // Try to get OpenAIPService, but don't fail if it's not available yet
        try {
          _openAIPService = Provider.of<OpenAIPService>(context, listen: false);
        } catch (e) {
          // debugPrint('⚠️ OpenAIPService not available yet, will retry later');
          // We'll initialize it later in the build cycle
        }

        // Initialize services with caching
        _initializeServices();
        
        
        // Start performance monitoring (only in debug mode)
        if (kDebugMode) {
          _performanceReportTimer = Timer.periodic(const Duration(seconds: 30), (_) {
            PerformanceMonitor().printPerformanceReport();
          });
        }

        // Listen to flight service updates
        _setupFlightServiceListener();

        // Listen to cache updates
        _setupCacheListener();

        // Start loading data in background if location is already available
        if (_currentPosition != null && !_isLocationLoaded) {
          _onLocationLoaded();
        }

        // Start position tracking if enabled (default is true)
        if (_positionTrackingEnabled && _positionUpdateTimer == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startPositionTracking();
          });
        }

        _servicesInitialized = true;
      } catch (e) {
        // debugPrint('Error initializing services: $e');
      }
    }
  }

  // Setup listener for cache updates
  void _setupCacheListener() {
    _cacheService.addListener(_onCacheUpdated);
  }

  // Handle cache updates
  void _onCacheUpdated() {
    // Refresh airspaces if they're enabled
    if (_mapStateController.showAirspaces && mounted) {
      _refreshAirspacesDisplay();
      _refreshReportingPointsDisplay();
    }

    // Could also refresh other data types here if needed
  }

  // Setup listener for flight service updates
  void _setupFlightServiceListener() {
    _flightService.addListener(_onFlightPathUpdated);
    _flightPlanService.addListener(_onFlightPlanUpdated);
    _headingService.addListener(_onHeadingUpdated);
  }

  // Handle flight path updates from the flight service
  void _onFlightPathUpdated() {
    if (mounted && !_hasInputFocus) {
      setState(() {
        // Check if tracking just started
        if (_flightService.isTracking && !_wasTracking) {
          // Re-enable auto-centering when tracking starts
          _autoCenteringEnabled = true;
          _autoCenteringTimer?.cancel();
          _countdownTimer?.cancel();
          _autoCenteringCountdown = 0;
        }
        _wasTracking = _flightService.isTracking;

        // Convert flight points to LatLng for map visualization
        _flightPathPoints = _flightService.flightPath
            .map((point) => LatLng(point.latitude, point.longitude))
            .toList();

        // Update flight segments for visualization
        _flightSegments = _flightService.flightSegments;

        // Update current position if tracking
        if (_flightService.isTracking && _flightPathPoints.isNotEmpty) {
          final lastPoint = _flightService.flightPath.last;
          _currentPosition = Position(
            latitude: lastPoint.latitude,
            longitude: lastPoint.longitude,
            timestamp: DateTime.now(),
            accuracy: lastPoint.accuracy,
            altitude: lastPoint.altitude,
            heading: _flightService.currentHeading ?? lastPoint.heading,
            speed: lastPoint.speed,
            speedAccuracy: lastPoint.speedAccuracy,
            altitudeAccuracy: lastPoint.verticalAccuracy,
            headingAccuracy: lastPoint.headingAccuracy,
          );

          // Update map position and rotation during tracking only if auto-centering is enabled
          if (_autoCenteringEnabled) {
            final settings = Provider.of<SettingsService>(
              context,
              listen: false,
            );
            
            // Handle different map rotation modes
            switch (settings.mapRotationMode) {
              case MapRotationMode.mapRotates:
                // Map rotates, aircraft marker points north
                _mapController.moveAndRotate(
                  LatLng(lastPoint.latitude, lastPoint.longitude),
                  _mapController.camera.zoom,
                  -(_flightService.currentHeading ??
                      lastPoint.heading), // Negate for map rotation
                );
                break;
              case MapRotationMode.aircraftRotates:
              case MapRotationMode.none:
                // Map fixed north-up, aircraft marker rotates
                _mapController.move(
                  LatLng(lastPoint.latitude, lastPoint.longitude),
                  _mapController.camera.zoom,
                );
                break;
            }
          }
        } else if (!_flightService.isTracking && _currentPosition != null) {
          // When not tracking, still update heading from HeadingService for always-on heading
          _updateCachedHeading();
          if (_cachedHeading != null &&
              (_currentPosition!.heading - _cachedHeading!).abs() > 1.0) {
            _currentPosition = Position(
              latitude: _currentPosition!.latitude,
              longitude: _currentPosition!.longitude,
              timestamp: _currentPosition!.timestamp,
              accuracy: _currentPosition!.accuracy,
              altitude: _currentPosition!.altitude,
              heading: _cachedHeading!,
              speed: _currentPosition!.speed,
              speedAccuracy: _currentPosition!.speedAccuracy,
              altitudeAccuracy: _currentPosition!.altitudeAccuracy,
              headingAccuracy: _currentPosition!.headingAccuracy,
            );
          }
        }
      });
    }
  }

  /// Update cached heading to avoid repeated property accesses
  void _updateCachedHeading() {
    final headingServiceHeading = _headingService.currentHeading;
    final flightServiceHeading = _flightService.currentHeading;
    _cachedHeading = headingServiceHeading ?? flightServiceHeading;
  }

  /// Handle heading updates from HeadingService
  void _onHeadingUpdated() {
    if (!mounted) return;
    
    // Update cached heading
    _updateCachedHeading();
    
    // Always update position with new heading if we have a position
    if (_currentPosition != null && _cachedHeading != null) {
      // Skip if flight is tracking (flight service handles updates in that case)
      if (_flightService.isTracking) return;
      
      setState(() {
        // Update the current position with new heading
        _currentPosition = Position(
          latitude: _currentPosition!.latitude,
          longitude: _currentPosition!.longitude,
          timestamp: _currentPosition!.timestamp,
          accuracy: _currentPosition!.accuracy,
          altitude: _currentPosition!.altitude,
          heading: _cachedHeading!,
          speed: _currentPosition!.speed,
          speedAccuracy: _currentPosition!.speedAccuracy,
          altitudeAccuracy: _currentPosition!.altitudeAccuracy,
          headingAccuracy: _currentPosition!.headingAccuracy,
        );
      });
      
      // DON'T move the map here - let position update timer handle it
      // This prevents the map from jumping every time heading changes
    }
  }

  // Handle flight plan updates from the flight plan service
  void _onFlightPlanUpdated() {
    if (mounted && !_hasInputFocus) {
      setState(() {
        // Don't automatically show the panel - let user control panel visibility
        // Only refresh the UI to show waypoints on map
        // The panel should remain in its current state (open or closed)
      });

      // Prefetch NOTAMs for airports in the flight plan when it changes
      if (_flightPlanService.currentFlightPlan != null) {
        _prefetchFlightPlanNotams();
      }
    }
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();
    // Handle screen size changes (orientation changes)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _handleOrientationChange();
      }
    });
  }

  void _handleOrientationChange() {
    final screenSize = MediaQuery.of(context).size;
    
    setState(() {
      // Adjust airspace panel position for screen size changes
      if (_airspacePanelPosition != null) {
        final panelWidth = screenSize.width < 600 ? screenSize.width - 16 : 600;
        final panelHeight = _airspacePanelHeight;
        
        // Clamp position to keep panel visible after screen resize
        double newX = _airspacePanelPosition!.dx;
        double newY = _airspacePanelPosition!.dy;
        
        // Adjust horizontal position if needed
        if (newX + panelWidth > screenSize.width) {
          newX = (screenSize.width - panelWidth).clamp(0, screenSize.width - panelWidth);
        }
        
        // Adjust vertical position if needed
        if (newY + panelHeight > screenSize.height) {
          newY = (screenSize.height - panelHeight).clamp(0, screenSize.height - panelHeight);
        }
        
        _airspacePanelPosition = Offset(newX, newY);
      }
      
      // Adjust flight planning panel position
      _adjustFlightPlanningPanelPosition(screenSize);
      
      // Note: Flight tracking panel now handles its own positioning (sticks to bottom)
      // No need to manually adjust its position anymore
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // Pause all timers when app is not active
        _pauseAllTimers();
        break;
      case AppLifecycleState.resumed:
        // Resume timers when app is active
        _resumeAllTimers();
        break;
      case AppLifecycleState.detached:
        break;
    }
  }
  
  void _pauseAllTimers() {
    _positionUpdateTimer?.cancel();
    _autoCenteringTimer?.cancel();
    _countdownTimer?.cancel();
    _airspaceDebounceTimer?.cancel();
    _locationStreamSubscription?.pause();
    
    // Pause SafeSky updates when app loses focus
    if (_mapStateController.showSafeSky && _servicesInitialized) {
      _safeSkyService.stopTracking();
    }
  }
  
  void _resumeAllTimers() {
    // Resume position updates if tracking was enabled
    if (_positionTrackingEnabled && !_flightService.isTracking) {
      _startPositionTracking();
    }
    
    // Resume location stream
    _locationStreamSubscription?.resume();
    
    // Resume SafeSky updates when app regains focus
    if (_mapStateController.showSafeSky && _servicesInitialized) {
      final bounds = _mapController.camera.visibleBounds;
      _safeSkyService.startTracking(bounds);
      // Force immediate refresh when regaining focus
      _safeSkyService.refreshNow();
    }
  }

  /// Validate flight plan tiles on startup
  Future<void> _validateFlightPlanTiles() async {
    // Wait a bit to ensure UI is ready and flight plans are loaded
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted || _tileDownloadService == null || _offlineDataController == null) {
      return;
    }
    
    // Check if validation is enabled
    if (!_offlineDataController!.validateTilesOnStartup) {
      return;
    }
    
    try {
      // Ensure flight plan service is initialized
      await _flightPlanService.initialize();
      
      // Get all saved flight plans
      final flightPlans = _flightPlanService.savedFlightPlans;
      if (flightPlans.isEmpty) return;
      
      // Show non-modal notification at the bottom
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: const [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
              SizedBox(width: 16),
              Flexible(
                child: Text(
                  'Checking flight plan map tiles...',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.sectionBackgroundColor.withAlpha(230),
          duration: const Duration(seconds: 5),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
      }
      
      // Validate all flight plans
      final validationResults = await _tileDownloadService!.validateAllFlightPlans(flightPlans);
      
      // Hide the notification
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
      
      // If there are missing tiles, show dialog
      if (validationResults.isNotEmpty && mounted) {
        await _showMissingTilesDialog(validationResults);
      }
    } catch (e) {
      // Hide the notification if still showing
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }
    }
  }
  
  /// Show dialog for missing tiles with download option
  Future<void> _showMissingTilesDialog(List<FlightPlanValidationResult> validationResults) async {
    final totalMissing = validationResults.fold<int>(0, (sum, result) => sum + result.missingTiles);
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.dialogRadius,
        ),
        title: Text(AppLocalizations.of(context)!.missingMapTiles),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Some flight plans are missing offline map tiles. '
                'Would you like to download them now?',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                'Total missing tiles: $totalMissing',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...validationResults.map((result) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.flight, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${result.flightPlan.name}: ${result.missingTiles} tiles '
                        '(${result.percentageMissing.toStringAsFixed(1)}% missing)',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ),
              )),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.later),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context)!.downloadNow),
          ),
        ],
      ),
    );
    
    if (result == true) {
      // Download missing tiles for all flight plans
      for (final validationResult in validationResults) {
        if (mounted) {
          await _tileDownloadService!.downloadTilesForFlightPlan(
            flightPlan: validationResult.flightPlan,
            context: context,
          );
        }
      }
    }
  }

  // Helper method to get extended bounds when map is tilted
  LatLngBounds _getExtendedBounds() {
    var bounds = _mapController.camera.visibleBounds;
    
    // Extend bounds significantly when map is tilted to load more data
    if (_mapTilt > 0) {
      // Much more aggressive extension for tilted view
      final extendFactor = (_mapTilt / 60.0) * 2.0; // 0 to 2 based on tilt
      final latExtension = (bounds.north - bounds.south) * extendFactor;
      final lonExtension = (bounds.east - bounds.west) * extendFactor;
      
      // Extend more to the north (top of screen) for perspective view
      bounds = LatLngBounds(
        LatLng(bounds.south - latExtension * 0.5, bounds.west - lonExtension),
        LatLng(bounds.north + latExtension * 1.5, bounds.east + lonExtension),
      );
    }
    
    return bounds;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Cancel all scheduled operations
    FrameAwareScheduler().cancelAll();
    _performanceReportTimer?.cancel();
    _locationRetryTimer?.cancel();
    _locationStreamSubscription?.cancel();
    
    // Cancel any active tile downloads
    _tileDownloadService?.cancelAllDownloads();
    
    _flightService.removeListener(_onFlightPathUpdated);
    _flightPlanService.removeListener(_onFlightPlanUpdated);
    _headingService.removeListener(_onHeadingUpdated);
    _cacheService.removeListener(_onCacheUpdated);
    _debounceTimer?.cancel();
    _airspaceDebounceTimer?.cancel();
    _notamPrefetchTimer?.cancel();
    _autoCenteringTimer?.cancel();
    _countdownTimer?.cancel();
    _positionUpdateTimer?.cancel();
    _mapController.dispose();
    _flightService.dispose();
    _spatialAirspaceService?.dispose();
    _offlineDataController?.dispose();
    _safeSkyService.dispose();
    super.dispose();
  }

  // Initialize location in background without blocking the UI
  Timer? _locationRetryTimer;
  StreamSubscription<Position>? _locationStreamSubscription;
  
  Future<void> _initLocationInBackground() async {
    try {
      final position = await _locationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          // Automatically enable position tracking when location permission is granted
          _positionTrackingEnabled = true;
          _autoCenteringEnabled = true;
        });

        // Location loaded successfully, handle the rest
        _onLocationLoaded();
        // Start listening for location updates
        _startLocationStream();
        // Start position tracking since we have permission
        await _startPositionTracking();
      }
    } catch (e) {
      // Don't show error popup, just use default location silently
      if (mounted) {
        setState(() {
          // Use a default position if location fails
          _currentPosition = Position(
            latitude: 37.7749,
            longitude: -122.4194,
            timestamp: DateTime.now(),
            accuracy: 0,
            altitude: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0,
            altitudeAccuracy: 0,
            headingAccuracy: 0,
          );
        });

        // Still trigger loading with default position
        _onLocationLoaded();
        // Don't retry automatically - wait for user to enable position tracking
      }
    }
  }
  
  // Add location stream subscription
  void _startLocationStream() {
    _locationStreamSubscription?.cancel();
    _locationStreamSubscription = _locationService.getPositionStream().listen(
      (Position position) {
        if (mounted && !_hasInputFocus) {
          setState(() {
            _currentPosition = position;
          });
        }
      },
      onError: (error) {
        // Handle stream errors silently
      },
    );
  }

  // Show location loading notification
  void _showLocationLoadingNotification() {
    if (_locationNotificationShown) return;
    _locationNotificationShown = true;
    
    // Show location loading notification at the bottom
    if (mounted) {
      setState(() {
        // Flag to show the notification
      });
    }
    
    // Auto-dismiss after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _dismissLocationNotification();
      }
    });
  }
  
  // Dismiss location loading notification
  void _dismissLocationNotification() {
    if (mounted) {
      setState(() {
        _locationNotificationShown = false;
      });
    }
  }

  // Load flight planning panel expanded state from SharedPreferences
  Future<void> _loadFlightPlanningPanelState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isExpanded = prefs.getBool(MapConstants.keyFlightPlanningExpanded) ?? false; // Default collapsed
      if (mounted) {
        setState(() {
          _flightPlanningExpanded = isExpanded;
        });
      }
    } catch (e) {
      // If there's an error loading, keep the default state (collapsed)
    }
  }

  // Load airspace panel position from SharedPreferences
  Future<void> _loadAirspacePanelPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final x = prefs.getDouble(MapConstants.keyAirspacePanelPositionX);
      final y = prefs.getDouble(MapConstants.keyAirspacePanelPositionY);
      
      if (x != null && y != null && mounted) {
        setState(() {
          _airspacePanelPosition = Offset(x, y);
        });
      }
    } catch (e) {
      // If there's an error loading, use default position
    }
  }

  // Save airspace panel position to SharedPreferences
  Future<void> _saveAirspacePanelPosition(Offset position) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(MapConstants.keyAirspacePanelPositionX, position.dx);
      await prefs.setDouble(MapConstants.keyAirspacePanelPositionY, position.dy);
    } catch (e) {
      // Silently fail if unable to save
    }
  }


  // Adjust flight planning panel position for screen size changes (orientation)
  void _adjustFlightPlanningPanelPosition(Size newScreenSize) {
    if (_lastFlightPlanningScreenSize != null && 
        (_lastFlightPlanningScreenSize!.width != newScreenSize.width || 
         _lastFlightPlanningScreenSize!.height != newScreenSize.height)) {
      
      // Calculate relative position as percentages
      final relativeX = _flightPlanningPanelPosition.dx / _lastFlightPlanningScreenSize!.width;
      final relativeY = _flightPlanningPanelPosition.dy / _lastFlightPlanningScreenSize!.height;
      
      // Determine panel dimensions based on screen size and orientation
      final isPhone = newScreenSize.width < 600;
      final panelWidth = isPhone ? newScreenSize.width - 16 : 600.0;
      final panelHeight = _flightPlanningExpanded ? 600.0 : 60.0;
      
      // Apply to new screen size and ensure panel stays visible
      // Ensure the clamp bounds are valid (min <= max)
      final maxX = math.max(0.0, newScreenSize.width - panelWidth);
      final maxY = math.max(0.0, newScreenSize.height - panelHeight);
      
      final newX = (relativeX * newScreenSize.width).clamp(0.0, maxX);
      final newY = (relativeY * newScreenSize.height).clamp(0.0, maxY);
      
      final newPosition = Offset(newX, newY);
      
      // Use post-frame callback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _flightPlanningPanelPosition = newPosition;
          });
        }
      });
    }
    _lastFlightPlanningScreenSize = newScreenSize;
  }

  // Handle actions after location is loaded
  void _onLocationLoaded() {
    if (_isLocationLoaded) return; // Prevent duplicate calls
    _isLocationLoaded = true;
    
    // Dismiss location loading notification
    _dismissLocationNotification();

    // Wait for the next frame to ensure FlutterMap is rendered before using MapController
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _currentPosition != null) {
        try {
          final settings = Provider.of<SettingsService>(context, listen: false);
          
          // Handle different map rotation modes
          if (_flightService.isTracking && settings.mapRotationMode == MapRotationMode.mapRotates) {
            _updateCachedHeading();
            if (_cachedHeading != null) {
              _mapController.moveAndRotate(
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                MapConstants.initialZoom,
                -_cachedHeading!,
              );
            } else {
              _mapController.move(
                LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
                MapConstants.initialZoom,
              );
            }
          } else {
            _mapController.move(
              LatLng(_currentPosition!.latitude, _currentPosition!.longitude),
              MapConstants.initialZoom,
            );
          }
        } catch (e) {
          // debugPrint('Error moving map: $e');
          // Fallback: try again after a short delay
          Future.delayed(const Duration(milliseconds: 100), () {
            if (mounted && _currentPosition != null) {
              try {
                _mapController.move(
                  LatLng(
                    _currentPosition!.latitude,
                    _currentPosition!.longitude,
                  ),
                  MapConstants.initialZoom,
                );
              } catch (e) {
                // debugPrint('Error moving map (retry): $e');
              }
            }
          });
        }

        // Start loading data progressively after a short delay to ensure map is fully initialized
        Future.delayed(const Duration(milliseconds: 500), () {
          if (!mounted) return;
          
          _loadAirports();

          // Load navaids if they should be shown
          if (_mapStateController.showNavaids) {
            _loadNavaids();
          }

          // Load airspaces if they should be shown
          if (_mapStateController.showAirspaces) {
            _loadAirspaces();
            _loadReportingPoints();
          }
          
          // Load obstacles if they should be shown
          if (_mapStateController.showObstacles) {
            _loadObstacles();
          }
          
          // Load hotspots if they should be shown
          if (_mapStateController.showHotspots) {
            _loadHotspots();
          }
        });
      }
    });
  }

  // Load airports in the current map view with debouncing
  Future<void> _loadAirports() async {
    return MapProfiler.profileMapOperation('loadAirports', () async {
    // Cancel any pending debounce timer
    _debounceTimer?.cancel();

    // Set a new debounce timer (500ms delay for better performance)
    _debounceTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;

      try {
        // Check if map controller is ready
        if (!mounted) {
          // debugPrint('📍 _loadAirports: Widget not mounted, returning');
          return;
        }

        final bounds = _getExtendedBounds();
        final zoom = _mapController.camera.zoom;

        // First, load runway data for the extended visible area
        await _runwayService.loadRunwaysForArea(
          minLat: bounds.southWest.latitude,
          maxLat: bounds.northEast.latitude,
          minLon: bounds.southWest.longitude,
          maxLon: bounds.northEast.longitude,
        );

        // Get airports from TiledDataLoader (these have runway data)
        List<Airport> airports;
        try {
          airports = await TiledDataLoader().loadAirportsForArea(
            minLat: bounds.southWest.latitude,
            maxLat: bounds.northEast.latitude,
            minLon: bounds.southWest.longitude,
            maxLon: bounds.northEast.longitude,
          );
          // Debug: Count airports by type
          final typeCount = <String, int>{};
          for (final airport in airports) {
            typeCount[airport.type] = (typeCount[airport.type] ?? 0) + 1;
          }
        } catch (e) {
          // Fall back to AirportService if TiledDataLoader fails
          debugPrint('TiledDataLoader failed, falling back to AirportService: $e');
          airports = await _airportService.getAirportsInBounds(
            bounds.southWest,
            bounds.northEast,
          );
        }

        // Get runway data for airports if zoom level is appropriate
        final runwayDataMap = <String, List<Runway>>{};
        if (zoom >= 10) {
          for (final airport in airports) {
            // Always pass OpenAIP runway data to properly handle embedded runways
            final runways = _runwayService.getRunwaysForAirport(
              airport.icao.isNotEmpty ? airport.icao : airport.name,
              openAIPRunways: airport.openAIPRunways,
              airportLat: airport.position.latitude,
              airportLon: airport.position.longitude,
            );
            if (runways.isNotEmpty) {
              // Use a unique key: ICAO if available, otherwise use name
              final key = airport.icao.isNotEmpty ? airport.icao : airport.name;
              runwayDataMap[key] = runways;
            }
          }
        }

        if (mounted) {
          setState(() {
            _airports = airports;
            _airportRunways = runwayDataMap;
          });

          // Refresh weather data for visible airports if METAR overlay is enabled
          if (_mapStateController.showMetar) {
            _refreshWeatherForVisibleAirports(airports);
          }

          // If we're at a high zoom level, also load nearby airports just outside the view
          if (zoom > 10) {
            final radiusKm = _calculateRadiusForZoom(zoom);
            _loadNearbyAirports(bounds.center, radiusKm * 1.5);
          }
        }
      } catch (e) {
        // debugPrint('Error loading airports: $e');
        // Don't show error popup for failed airport loading
      }
    });
    });
  }

  /// Refresh weather data for visible airports when map focus changes
  Future<void> _refreshWeatherForVisibleAirports(List<Airport> airports) async {
    if (!_mapStateController.showMetar || airports.isEmpty) return;

    try {
      // Filter airports that should have weather data (medium/large airports)
      final airportsNeedingWeather = airports.where((airport) {
        return _shouldFetchWeatherForAirport(airport);
      }).toList();

      if (airportsNeedingWeather.isEmpty) return;

      // Get ICAO codes for airports that need weather refresh
      final icaoCodes = airportsNeedingWeather.map((a) => a.icao).toList();

      // debugPrint('🌤️ Refreshing weather for ${icaoCodes.length} visible airports');

      // Fetch weather data for visible airports
      final metarData = await _weatherService.getMetarsForAirports(icaoCodes);
      final tafData = await _weatherService.getTafsForAirports(icaoCodes);

      // Update airports with fresh weather data
      for (final airport in airportsNeedingWeather) {
        final metar = metarData[airport.icao];
        final taf = tafData[airport.icao];

        if (metar != null) {
          airport.updateWeather(metar, taf: taf);
        }
      }

      // Trigger UI update to show fresh weather data
      if (mounted) {
        setState(() {
          // Update the airports list to reflect new weather data
          _airports = [...airports];
        });
      }

      // debugPrint('✅ Weather refresh completed for visible airports');
    } catch (e) {
      // debugPrint('❌ Error refreshing weather for visible airports: $e');
    }
  }

  /// Check if weather data should be fetched for this airport type
  bool _shouldFetchWeatherForAirport(Airport airport) {
    // Only fetch weather for medium and large airports
    // Small airports, heliports, seaplane bases typically don't have weather stations
    switch (airport.type.toLowerCase()) {
      case 'large_airport':
      case 'medium_airport':
        return true;
      case 'small_airport':
      case 'heliport':
      case 'seaplane_base':
      case 'closed':
        return false;
      default:
        // For unknown types, check if it has an ICAO code
        // Airports with proper ICAO codes are more likely to have weather data
        return airport.icao.length == 4 &&
            RegExp(r'^[A-Z]{4}$').hasMatch(airport.icao);
    }
  }

  // Calculate radius in kilometers based on zoom level
  double _calculateRadiusForZoom(double zoom) {
    // These values can be adjusted based on testing
    if (zoom > 14) return 20.0; // Very close zoom
    if (zoom > 12) return 50.0; // Close zoom
    if (zoom > 9) return 100.0; // Medium zoom
    return 200.0; // Far zoom
  }

  // Load additional nearby airports that might be just outside the current view
  Future<void> _loadNearbyAirports(LatLng center, double radiusKm) async {
    try {
      final nearbyAirports = _airportService.findAirportsNearby(
        center,
        radiusKm: radiusKm,
      );

      // Filter out airports we already have
      final newAirports = nearbyAirports
          .where((a) => !_airports.any((existing) => existing.icao == a.icao))
          .toList();

      if (newAirports.isNotEmpty && mounted) {
        setState(() {
          _airports = [..._airports, ...newAirports];
        });
      }
    } catch (e) {
      // debugPrint('Error loading nearby airports: $e');
    }
  }

  // Load navaids in the current map view
  Future<void> _loadNavaids() async {
    return MapProfiler.profileMapOperation('loadNavaids', () async {
      if (!_mapStateController.showNavaids) {
        return;
      }

      try {
        // Check if map controller is ready
        if (!mounted) {
          return;
        }

        final bounds = _getExtendedBounds();
        
        // Load navaids for the extended visible area
        await _navaidService.loadNavaidsForArea(
          minLat: bounds.southWest.latitude,
          maxLat: bounds.northEast.latitude,
          minLon: bounds.southWest.longitude,
          maxLon: bounds.northEast.longitude,
        );

        final navaids = _navaidService.getNavaidsInBounds(
          bounds.southWest,
          bounds.northEast,
        );

        if (mounted) {
          setState(() {
            _navaids = navaids;
          });
        }
      } catch (e) {
        // debugPrint('❌ Error loading navaids: $e');
      }
    });
  }

  // Load airspaces in the current map view
  Future<void> _loadAirspaces() async {
    return MapProfiler.profileMapOperation('loadAirspaces', () async {
      if (!_mapStateController.showAirspaces) {
        return;
      }

      // Cancel any pending debounce timer
      _airspaceDebounceTimer?.cancel();

      // Set a new debounce timer (500ms delay for airspaces)
      _airspaceDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
        await _loadAirspacesDebounced();
      });
    });
  }

  Future<void> _loadAirspacesDebounced() async {

    try {
      // First, load from cache for immediate display
      final cachedAirspaces = await openAIPService.getCachedAirspaces();

      if (cachedAirspaces.isNotEmpty) {
        // Spatial index will be built automatically by the service
      }

      // Then progressively load data for current bounds
      final bounds = _getExtendedBounds();

      // Load airspaces for extended map bounds
      await openAIPService.loadAirspacesForBounds(
        minLat: bounds.southWest.latitude,
        minLon: bounds.southWest.longitude,
        maxLat: bounds.northEast.latitude,
        maxLon: bounds.northEast.longitude,
        onDataLoaded: () {
          // Refresh the display when new data is loaded
          if (mounted) {
            _refreshAirspacesDisplay();
          }
        },
      );
    } catch (e) {
      // Silently ignore errors during data loading initialization
    }
  }

  // Refresh airspaces display when new data is available
  Future<void> _refreshAirspacesDisplay() async {
    try {
      await openAIPService.getCachedAirspaces();
      if (mounted) {
        // Rebuild spatial index with new data
        await spatialAirspaceService.rebuildIndex();
      }
    } catch (e) {
      // Silently ignore errors during airspace refresh
      // This is non-critical functionality
    }
  }

  // Load reporting points in the current map view
  Future<void> _loadReportingPoints() async {
    return MapProfiler.profileMapOperation('loadReportingPoints', () async {
      if (!_mapStateController.showAirspaces) {
        return;
      }

      try {
        final bounds = _mapController.camera.visibleBounds;
        
        // Try fast in-memory filtering first (similar to airports)
        final pointsInBounds = openAIPService.getReportingPointsInBounds(
          minLat: bounds.southWest.latitude,
          minLon: bounds.southWest.longitude,
          maxLat: bounds.northEast.latitude,
          maxLon: bounds.northEast.longitude,
        );
        
        if (pointsInBounds.isNotEmpty) {
          // Fast path - data already in memory
          if (mounted) {
            setState(() {
              _reportingPoints = pointsInBounds;
            });
          }
          return; // Done - no need for async operations
        }
        
        // Fallback: Load from cache/network if not in memory
        await openAIPService.loadReportingPointsForBounds(
          minLat: bounds.southWest.latitude,
          minLon: bounds.southWest.longitude,
          maxLat: bounds.northEast.latitude,
          maxLon: bounds.northEast.longitude,
          onDataLoaded: () {
            // Refresh the display when new data is loaded
            if (mounted) {
              _refreshReportingPointsDisplay();
            }
          },
        );
      } catch (e) {
        // debugPrint('❌ Error loading reporting points: $e');
      }
    });
  }

  // Refresh reporting points display when new data is available
  Future<void> _refreshReportingPointsDisplay() async {
    try {
      final bounds = _getExtendedBounds();
      
      // Use optimized in-memory filtering
      final pointsInBounds = openAIPService.getReportingPointsInBounds(
        minLat: bounds.southWest.latitude,
        minLon: bounds.southWest.longitude,
        maxLat: bounds.northEast.latitude,
        maxLon: bounds.northEast.longitude,
      );
      
      if (mounted) {
        setState(() {
          _reportingPoints = pointsInBounds;
        });
      }
    } catch (e) {
      // debugPrint('❌ Error refreshing reporting points display: $e');
    }
  }
  
  // Load obstacles within the current map bounds
  Future<void> _loadObstacles() async {
    return MapProfiler.profileMapOperation('loadObstacles', () async {
      if (!_mapStateController.showObstacles) {
        return;
      }

      try {
        final bounds = _getExtendedBounds();
        
        // Load obstacles from tiled data
        final obstacles = await openAIPService.getObstaclesForArea(
          minLat: bounds.southWest.latitude,
          minLon: bounds.southWest.longitude,
          maxLat: bounds.northEast.latitude,
          maxLon: bounds.northEast.longitude,
        );
        
        // Loaded ${obstacles.length} obstacles for area
        
        if (mounted) {
          setState(() {
            _obstacles = obstacles;
          });
        }
      } catch (e) {
        debugPrint('❌ Error loading obstacles: $e');
      }
    });
  }
  
  // Load hotspots within the current map bounds
  Future<void> _loadHotspots() async {
    return MapProfiler.profileMapOperation('loadHotspots', () async {
      if (!_mapStateController.showHotspots) {
        return;
      }

      try {
        final bounds = _getExtendedBounds();
        
        // Load hotspots from tiled data
        final hotspots = await openAIPService.getHotspotsForArea(
          minLat: bounds.southWest.latitude,
          minLon: bounds.southWest.longitude,
          maxLat: bounds.northEast.latitude,
          maxLon: bounds.northEast.longitude,
        );

        if (mounted) {
          setState(() {
            _hotspots = hotspots;
          });
        }
      } catch (e) {
        // debugPrint('❌ Error loading hotspots: $e');
      }
    });
  }

  // Start auto-centering countdown
  void _startAutoCenteringCountdown() {
    setState(() {
      _autoCenteringCountdown = MapConstants.autoCenteringDelay.inSeconds;
    });
    
    // Cancel any existing timers
    _autoCenteringTimer?.cancel();
    _countdownTimer?.cancel();
    
    // Start countdown timer that updates every second
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted && !_hasInputFocus) {
        setState(() {
          _autoCenteringCountdown--;
        });
        
        if (_autoCenteringCountdown <= 0) {
          timer.cancel();
          _countdownTimer = null;
        }
      }
    });
    
    // Start the actual auto-centering timer
    _autoCenteringTimer = Timer(MapConstants.autoCenteringDelay, () {
      if (mounted && (_flightService.isTracking || _positionTrackingEnabled)) {
        setState(() {
          _autoCenteringEnabled = true;
          _autoCenteringCountdown = 0;
        });
      }
    });
  }
  
  // Handle zoom button changes to trigger map updates
  void _onZoomButtonPressed() {
    // Use frame-aware scheduler for staggered loading (same as gesture-based zoom)
    final scheduler = FrameAwareScheduler();
    
    // Load airports first (highest priority)
    scheduler.scheduleOperation(
      id: 'load_airports',
      operation: _loadAirports,
      debounce: const Duration(milliseconds: 300),
      highPriority: true,
    );
    
    // Load navaids with delay
    if (_mapStateController.showNavaids) {
      scheduler.scheduleOperation(
        id: 'load_navaids',
        operation: _loadNavaids,
        debounce: const Duration(milliseconds: 600),
      );
    }
    
    // Reporting points with more delay
    if (_mapStateController.showAirspaces) {
      scheduler.scheduleOperation(
        id: 'load_reporting_points',
        operation: _loadReportingPoints,
        debounce: const Duration(milliseconds: 800),
      );
    }
    
    // Obstacles with delay
    if (_mapStateController.showObstacles) {
      scheduler.scheduleOperation(
        id: 'load_obstacles',
        operation: _loadObstacles,
        debounce: const Duration(milliseconds: 900),
      );
    }
    
    // Hotspots with delay  
    if (_mapStateController.showHotspots) {
      scheduler.scheduleOperation(
        id: 'load_hotspots',
        operation: _loadHotspots,
        debounce: const Duration(milliseconds: 950),
      );
    }
  }

  // Toggle position tracking
  Future<void> _togglePositionTracking() async {
    setState(() {
      _positionTrackingEnabled = !_positionTrackingEnabled;
    });

    if (_positionTrackingEnabled) {
      // Start position tracking
      await _startPositionTracking();
    } else {
      // Stop position tracking
      _stopPositionTracking();
    }
  }

  // Start position tracking
  Future<void> _startPositionTracking() async {
    // First, center on current location
    try {
      final position = await _locationService.getLastKnownOrCurrentLocation();
      if (mounted) {
        setState(() {
          _currentPosition = position;
          _autoCenteringEnabled = true;
          _autoCenteringCountdown = 0;
        });

        // Cancel any existing timers
        _autoCenteringTimer?.cancel();
        _countdownTimer?.cancel();
        
        // Retry starting HeadingService now that we have location permission
        if (!_headingService.isRunning) {
          await _headingService.retryStart();
        }

        // Handle different map rotation modes
        if (!mounted) return;
        final settingsService = context.read<SettingsService>();
        switch (settingsService.mapRotationMode) {
          case MapRotationMode.mapRotates:
            // Update cached heading from HeadingService
            _updateCachedHeading();
            final heading = _cachedHeading ?? position.heading;
            _mapController.moveAndRotate(
              LatLng(position.latitude, position.longitude),
              _mapController.camera.zoom,
              -heading,
            );
            break;
          case MapRotationMode.aircraftRotates:
          case MapRotationMode.none:
            _mapController.move(
              LatLng(position.latitude, position.longitude),
              _mapController.camera.zoom,
            );
            break;
        }
        _loadAirports();
      }
    } catch (e) {
      // Keep _positionTrackingEnabled as true even on error
      // so it will automatically start working when permission is granted
      
      if (mounted) {
        // Check if it's a permission error
        if (e.toString().contains('denied') || e.toString().contains('permission')) {
          // Permission denied - OS already showed the permission dialog
          // Just fail silently as the user denied permission
        } else {
          // Other location errors
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)!.couldNotGetCurrentLocation)),
          );
        }
        return;
      }
    }

    // Start periodic position updates
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = Timer.periodic(MapConstants.positionUpdateInterval, (_) async {
      if (_positionTrackingEnabled && _autoCenteringEnabled && !_flightService.isTracking) {
        await _updateCurrentPosition();
      }
    });
  }

  // Stop position tracking
  void _stopPositionTracking() {
    _positionUpdateTimer?.cancel();
    _positionUpdateTimer = null;
    _autoCenteringTimer?.cancel();
    _countdownTimer?.cancel();
    setState(() {
      _autoCenteringCountdown = 0;
    });
  }

  // Update current position
  Future<void> _updateCurrentPosition() async {
    try {
      final position = await _locationService.getLastKnownOrCurrentLocation();
      if (mounted && _positionTrackingEnabled && _autoCenteringEnabled && !_hasInputFocus) {
        setState(() {
          _currentPosition = position;
        });

        final settingsService = context.read<SettingsService>();
        
        // Handle different map rotation modes
        switch (settingsService.mapRotationMode) {
          case MapRotationMode.mapRotates:
            // Update cached heading from HeadingService
            _updateCachedHeading();
            final heading = _cachedHeading ?? position.heading;
            _mapController.moveAndRotate(
              LatLng(position.latitude, position.longitude),
              _mapController.camera.zoom,
              -heading,
            );
            break;
          case MapRotationMode.aircraftRotates:
          case MapRotationMode.none:
            _mapController.move(
              LatLng(position.latitude, position.longitude),
              _mapController.camera.zoom,
            );
            break;
        }
      }
    } catch (e) {
      // Silently ignore errors during periodic updates
    }
  }

  // Calculate centered position for airspace panel
  Offset _getCenteredAirspacePanelPosition(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isPhone = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1200;
    
    // Calculate panel width based on constraints from the UI
    final panelWidth = isPhone
        ? screenSize.width - 16
        : (isTablet ? 500 : 600);
    
    // Center horizontally
    final leftPosition = (screenSize.width - panelWidth) / 2;
    
    // Position from top - place it near bottom of screen
    final topPosition = screenSize.height - _airspacePanelBottomOffset;
    
    final centeredPosition = Offset(leftPosition, topPosition);
    
    return centeredPosition;
  }


  // Toggle heliport visibility
  void _toggleHeliports() {
    setState(() {
      _mapStateController.toggleHeliports();
    });
  }
  
  // Toggle navaids visibility
  void _toggleNavaids() {
    setState(() {
      _mapStateController.toggleNavaids();
    });
    
    if (_mapStateController.showNavaids) {
      // Load navaids when enabled
      _loadNavaids();
    }
  }


  // Toggle airspaces visibility
  void _toggleAirspaces() {
    setState(() {
      _mapStateController.toggleAirspaces();
    });
    
    if (_mapStateController.showAirspaces) {
      // Load/refresh data if needed
      _loadAirspaces();
      _loadReportingPoints();
    }
  }
  
  // Toggle obstacles visibility
  void _toggleObstacles() {
    setState(() {
      _mapStateController.toggleObstacles();
    });
    
    if (_mapStateController.showObstacles) {
      // Load obstacles if needed
      _loadObstacles();
    }
  }
  
  // Toggle hotspots visibility
  void _toggleHotspots() {
    setState(() {
      _mapStateController.toggleHotspots();
    });
    
    if (_mapStateController.showHotspots) {
      // Load hotspots if needed
      _loadHotspots();
    }
  }

  void _toggleHeatmap() {
    setState(() {
      _mapStateController.toggleHeatmap();
    });
  }

  void _toggleSafeSky() {
    setState(() {
      _mapStateController.toggleSafeSky();
    });
    
    if (_mapStateController.showSafeSky) {
      // Start SafeSky tracking if enabled
      _startSafeSkyTracking();
    } else {
      // Stop SafeSky tracking if disabled
      _stopSafeSkyTracking();
    }
  }

  void _toggleTerrain() {
    setState(() {
      _mapStateController.toggleTerrain();
    });
  }

  void _toggleElevation() {
    setState(() {
      _mapStateController.toggleElevation();
    });
  }

  void _startSafeSkyTracking() {
    if (_servicesInitialized) {
      final bounds = _mapController.camera.visibleBounds;
      _safeSkyService.startTracking(bounds);
    }
  }

  void _stopSafeSkyTracking() {
    if (_servicesInitialized) {
      _safeSkyService.stopTracking();
    }
  }

  void _updateSafeSkyViewport() {
    if (_servicesInitialized && 
        _mapStateController.showSafeSky) {
      final bounds = _mapController.camera.visibleBounds;
      _safeSkyService.updateViewport(bounds);
    }
  }
  
  // Toggle METAR weather display
  void _toggleMetar() {
    setState(() {
      _mapStateController.toggleMetar();
      if (_mapStateController.showMetar) {
        // Load weather data when enabled
        _loadWeatherForVisibleAirports();
      }
    });
  }


  // Handle map tap - updated to support flight planning and airspace selection
  void _onMapTapped(TapPosition tapPosition, LatLng point) async {
    // If a waypoint was just tapped, ignore this map tap
    if (_waypointJustTapped) {
      return;
    }

    // Debug output
    debugPrint('Map tapped - isPlanning: ${_flightPlanService.isPlanning}, currentFlightPlan: ${_flightPlanService.currentFlightPlan?.name}');

    // If in flight planning mode, add waypoint
    // Allow adding waypoints when in edit mode, regardless of panel visibility
    if (_flightPlanService.isPlanning) {
      debugPrint('Planning mode is active, checking for flight plan...');
      // Check if there's a current flight plan
      if (_flightPlanService.currentFlightPlan == null) {
        debugPrint('No current flight plan, creating new one...');
        // Create a new flight plan if none exists
        _flightPlanService.startNewFlightPlan(enablePlanning: true);
      }
      debugPrint('Adding waypoint at: ${point.latitude}, ${point.longitude}');
      _flightPlanService.addWaypoint(point);
      debugPrint('Waypoint added. Total waypoints: ${_flightPlanService.currentFlightPlan?.waypoints.length}');
      return;
    } else {
      debugPrint('Not in planning mode, ignoring tap');
    }

    // Check if any airspaces contain the tapped point
    if (_mapStateController.showAirspaces) {
      // Use spatial service to find airspaces at the tapped point
      final tappedAirspaces = await spatialAirspaceService.getAirspacesAtPoint(point);

      if (tappedAirspaces.isNotEmpty) {
        _showAirspacesAtPoint(tappedAirspaces, point);
        return;
      }
    }

    // Otherwise, close any open dialogs or menus
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  // Handle flight path segment tap for waypoint insertion
  void _onFlightPathSegmentTapped(int segmentIndex, LatLng position) {
    if (!_flightPlanService.isPlanning || !_showFlightPlanning) {
      return;
    }

    // Insert waypoint at the specified position in the flight path
    _flightPlanService.insertWaypointAt(segmentIndex, position);
    
    // Select the newly inserted waypoint
    setState(() {
      _selectedWaypointIndex = segmentIndex;
    });
  }

  // Show list of airspaces at a given point
  // Prefetch NOTAMs for airports in flight plan
  Future<void> _prefetchFlightPlanNotams() async {
    final flightPlan = _flightPlanService.currentFlightPlan;
    if (flightPlan == null) return;

    final airportIcaos = <String>[];
    for (final waypoint in flightPlan.waypoints) {
      if (waypoint.type == WaypointType.airport && waypoint.name != null) {
        // Extract ICAO code from waypoint name (usually in format "ICAO - Airport Name")
        final parts = waypoint.name!.split(' - ');
        if (parts.isNotEmpty && parts[0].length == 4) {
          airportIcaos.add(parts[0]);
        }
      }
    }

    if (airportIcaos.isNotEmpty) {
      // debugPrint('Prefetching NOTAMs for flight plan airports: $airportIcaos');
      try {
        final notamService = NotamServiceV3(); // Using V3 as primary
        await notamService.prefetchNotamsForAirports(airportIcaos);
      } catch (e) {
        // debugPrint('Error prefetching flight plan NOTAMs: $e');
      }
    }
  }

  // Prefetch NOTAMs for visible airports with debouncing
  void _schedulePrefetchVisibleAirportNotams() {
    // Cancel any existing timer
    _notamPrefetchTimer?.cancel();

    // Increment generation to cancel any pending fetches
    _notamFetchGeneration++;

    // Only prefetch NOTAMs when zoomed in enough (zoom > 11)
    if (_mapController.camera.zoom <= 11) {
      // debugPrint('Skipping NOTAM prefetch - zoom level too low: ${_mapController.camera.zoom}');
      return;
    }

    // Schedule a new prefetch after 5 seconds of inactivity (increased from 2)
    final currentGeneration = _notamFetchGeneration;
    _notamPrefetchTimer = Timer(const Duration(seconds: 5), () async {
      // Only proceed if this is still the latest generation
      if (currentGeneration == _notamFetchGeneration) {
        await _prefetchVisibleAirportNotams(currentGeneration);
      }
    });
  }

  // Prefetch NOTAMs for visible airports
  Future<void> _prefetchVisibleAirportNotams(int generation) async {
    if (_airports.isEmpty) return;

    // Check if this generation is still current
    if (generation != _notamFetchGeneration) {
      // debugPrint('Cancelling outdated NOTAM prefetch (generation $generation != $_notamFetchGeneration)');
      return;
    }

    final bounds = _mapController.camera.visibleBounds;

    // Filter visible airports and prioritize by type
    final visibleAirports = _airports.where((airport) {
      return bounds.contains(airport.position);
    }).toList();

    // Sort by priority: large > medium > small > heliport > closed
    visibleAirports.sort((a, b) {
      const priorities = {
        'large_airport': 0,
        'medium_airport': 1,
        'small_airport': 2,
        'heliport': 3,
        'closed': 4,
      };
      final aPriority = priorities[a.type] ?? 5;
      final bPriority = priorities[b.type] ?? 5;
      return aPriority.compareTo(bPriority);
    });

    // Limit to 10 airports (reduced from 20) and exclude small airports, heliports and closed airports
    final priorityAirports = visibleAirports
        .where(
          (a) =>
              a.type != 'small_airport' &&
              a.type != 'heliport' &&
              a.type != 'closed',
        )
        .take(10)
        .toList();

    if (priorityAirports.isNotEmpty) {
      // Final check before making the request
      if (generation != _notamFetchGeneration) {
        // debugPrint('Cancelling NOTAM prefetch before request (generation $generation != $_notamFetchGeneration)');
        return;
      }

      final icaoCodes = priorityAirports.map((a) => a.icao).toList();
      // debugPrint('Prefetching NOTAMs for ${icaoCodes.length} large/medium airports at zoom ${_mapController.camera.zoom}');
      try {
        final notamService = NotamServiceV3(); // Using V3 as primary
        await notamService.prefetchNotamsForAirports(icaoCodes);

        // Check one more time after the async operation
        if (generation != _notamFetchGeneration) {
          // debugPrint('NOTAM prefetch completed but is now outdated (generation $generation != $_notamFetchGeneration)');
        }
      } catch (e) {
        // debugPrint('Error prefetching visible airport NOTAMs: $e');
      }
    }
  }

  void _showAirspacesAtPoint(List<Airspace> airspaces, LatLng point) async {
    if (!mounted) return;

    // Get current altitude if available
    final currentAltitudeFt = _currentPosition?.altitude != null
        ? _currentPosition!.altitude * 3.28084 // Convert meters to feet
        : null;
    
    // Get ground elevation at this point
    double? groundElevationFt;
    try {
      final elevationMeters = await TerrainElevationService.getElevation(point);
      if (elevationMeters != null) {
        groundElevationFt = elevationMeters * 3.28084; // Convert meters to feet
      }
    } catch (e) {
      // Ignore errors getting elevation
    }

    // Check if widget is still mounted after async operation
    if (!mounted) return;

    // Sort airspaces by altitude (lower first)
    airspaces.sort((a, b) {
      final altA = a.lowerLimitFt ?? 0;
      final altB = b.lowerLimitFt ?? 0;
      return altA.compareTo(altB);
    });

    // If only one airspace, show it directly
    if (airspaces.length == 1) {
      _onAirspaceSelected(airspaces.first);
      return;
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;
    final fontSize = isPhone ? 11.0 : 12.0;
    final titleFontSize = isPhone ? 10.0 : 11.0;

    // Show selection dialog for multiple airspaces
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isPhone ? screenWidth * 0.9 : 400,
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.87),
              borderRadius: BorderRadius.circular(8.0),
              border: Border.all(color: AppColors.warningColor.withValues(alpha: AppColors.mediumOpacity)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8.0),
                      topRight: Radius.circular(8.0),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'AIRSPACES AT LOCATION',
                        style: TextStyle(
                          color: AppColors.warningColor,
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: AppColors.secondaryTextColor, size: 16),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                      ),
                    ],
                  ),
                ),
                // Current altitude and ground elevation indicator
                if (currentAltitudeFt != null || groundElevationFt != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                    color: Colors.black.withValues(alpha: 0.2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (currentAltitudeFt != null)
                          Row(
                            children: [
                              Icon(
                                Icons.flight,
                                size: 14,
                                color: AppColors.infoColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Current altitude: ${currentAltitudeFt.round()} ft',
                                style: TextStyle(
                                  fontSize: fontSize,
                                  color: AppColors.secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        if (groundElevationFt != null) ...[
                          if (currentAltitudeFt != null) const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(
                                Icons.terrain,
                                size: 14,
                                color: Colors.brown,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Ground elevation: ${groundElevationFt.round()} ft',
                                style: TextStyle(
                                  fontSize: fontSize,
                                  color: AppColors.secondaryTextColor,
                                ),
                              ),
                              if (currentAltitudeFt != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '(AGL: ${(currentAltitudeFt - groundElevationFt).round()} ft)',
                                  style: TextStyle(
                                    fontSize: fontSize,
                                    color: AppColors.infoColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                // Airspaces list
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: airspaces.map<Widget>((airspace) {
                        // Check if current altitude is within this airspace
                        final isAtCurrentAltitude = currentAltitudeFt != null &&
                            airspace.isAtAltitude(currentAltitudeFt);

                        return Container(
                          decoration: isAtCurrentAltitude
                              ? BoxDecoration(
                                  color: AppColors.warningColor.withValues(alpha: AppColors.veryLowOpacity),
                                  border: Border.all(
                                    color: AppColors.warningColor,
                                    width: 2,
                                  ),
                                  borderRadius: AppTheme.defaultRadius,
                                )
                              : BoxDecoration(
                                  border: Border.all(
                                    color: AppColors.primaryTextColor.withValues(alpha: AppColors.lowOpacity),
                                    width: 1,
                                  ),
                                  borderRadius: AppTheme.defaultRadius,
                                ),
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: AppTheme.defaultRadius,
                              onTap: () {
                                Navigator.of(context).pop();
                                _onAirspaceSelected(airspace);
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      _getAirspaceIcon(airspace.type),
                                      color: _getAirspaceColor(
                                        airspace.type,
                                        airspace.icaoClass,
                                      ),
                                      size: isPhone ? 20 : 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _getAirspaceDisplayName(airspace),
                                            style: TextStyle(
                                              color: AppColors.primaryTextColor,
                                              fontSize: fontSize,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            AirspaceUtils.getAirspaceTypeName(airspace.type),
                                            style: TextStyle(
                                              color: AppColors.secondaryTextColor,
                                              fontSize: isPhone ? 10 : 11,
                                            ),
                                          ),
                                          Text(
                                            airspace.altitudeRange,
                                            style: TextStyle(
                                              color: isAtCurrentAltitude 
                                                  ? AppColors.warningColor 
                                                  : AppColors.disabledTextColor,
                                              fontSize: isPhone ? 10 : 11,
                                              fontWeight: isAtCurrentAltitude 
                                                  ? FontWeight.bold 
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right, 
                                      color: AppColors.primaryTextColor.withValues(alpha: 0.3),
                                      size: isPhone ? 18 : 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _getAirspaceIcon(String? type) {
    if (type == null) return Icons.layers;

    switch (type.toUpperCase()) {
      case 'CTR':
      case 'ATZ':
        return Icons.flight_land;
      case 'D':
      case 'DANGER':
      case 'P':
      case 'PROHIBITED':
        return Icons.warning;
      case 'R':
      case 'RESTRICTED':
        return Icons.block;
      case 'TMA':
        return Icons.flight_takeoff;
      case 'TMZ':
      case 'RMZ':
        return Icons.radio;
      default:
        return Icons.layers;
    }
  }

  Color _getAirspaceColor(String? type, String? icaoClass) {
    // Use string-based color mapping since data contains string values
    return AirspaceUtils.getAirspaceColorByString(type, icaoClass);
  }
  
  String _getAirspaceDisplayName(Airspace airspace) {
    final icaoClass = AirspaceUtils.getIcaoClassName(airspace.icaoClass);
    if (airspace.icaoClass != null && icaoClass != 'Unclassified') {
      return '${airspace.name} (Class $icaoClass)';
    }
    return airspace.name;
  }

  // Handle waypoint tap for selection
  void _onWaypointTapped(int index) {
    final flightPlan = _flightPlanService.currentFlightPlan;
    if (flightPlan != null &&
        index >= 0 &&
        index < flightPlan.waypoints.length) {
      setState(() {
        _selectedWaypointIndex = _selectedWaypointIndex == index ? null : index;
        _waypointJustTapped = true;
      });
      // Reset the flag after a short delay
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() {
            _waypointJustTapped = false;
          });
        }
      });
    }
  }

  // Handle waypoint move via drag and drop
  void _onWaypointMoved(int index, LatLng newPosition, {bool isDragging = false}) {
    final flightPlan = _flightPlanService.currentFlightPlan;
    if (flightPlan != null &&
        index >= 0 &&
        index < flightPlan.waypoints.length) {
      // Update waypoint position with drag state
      _flightPlanService.updateWaypointPosition(index, newPosition, isDragging: isDragging);
      
      // When dropping (not dragging), check if dropped on a marker
      if (!isDragging) {
        _checkAndUpdateWaypointForMarker(index, newPosition);
      }
    }
  }
  
  /// Find the closest item within search radius from a list of items with positions
  T? _findClosestItemWithinRadius<T>({
    required List<T> items,
    required LatLng dropPosition,
    required double searchRadiusMeters,
    required LatLng Function(T) getPosition,
  }) {
    T? closestItem;
    double minDistance = double.infinity;
    
    for (final item in items) {
      final distance = Distance().as(LengthUnit.Meter, dropPosition, getPosition(item));
      if (distance <= searchRadiusMeters && distance < minDistance) {
        minDistance = distance;
        closestItem = item;
      }
    }
    
    return closestItem;
  }

  /// Check if waypoint was dropped on an airport or navaid and update its name/type accordingly
  void _checkAndUpdateWaypointForMarker(int waypointIndex, LatLng dropPosition) {
    debugPrint('Checking for markers near dropped waypoint at: ${dropPosition.latitude}, ${dropPosition.longitude}');
    try {
      // Calculate search radius based on zoom level
      // At zoom 10: ~1000m radius, at zoom 15: ~31m radius
      final zoom = _mapController.camera.zoom;
      final zoomInt = zoom.round();
      
      // Use lookup table for common zoom levels, fallback to calculation for others
      final searchRadiusMeters = MapConstants.searchRadiusLookup[zoomInt] ?? 
          MapConstants.baseSearchRadius * math.pow(MapConstants.searchRadiusZoomFactor, zoom - MapConstants.searchRadiusZoomBase);
      
      // Get all airports in the current view
      final bounds = _mapController.camera.visibleBounds;
    final airports = _airports.where((airport) {
      final lat = airport.position.latitude;
      final lng = airport.position.longitude;
      return lat >= bounds.south && 
             lat <= bounds.north && 
             lng >= bounds.west && 
             lng <= bounds.east;
    }).toList();
    
    // Find the closest airport within search radius
    final closestAirport = _findClosestItemWithinRadius<Airport>(
      items: airports,
      dropPosition: dropPosition,
      searchRadiusMeters: searchRadiusMeters,
      getPosition: (airport) => airport.position,
    );
    
    if (closestAirport != null) {
      debugPrint('Found airport nearby: ${closestAirport.name} (${closestAirport.icao})');
      // Update waypoint with airport information
      _flightPlanService.updateWaypointName(waypointIndex, closestAirport.name);
      _flightPlanService.updateWaypointNotes(waypointIndex, 
        closestAirport.icaoCode?.isNotEmpty == true 
          ? closestAirport.icaoCode! 
          : (closestAirport.iataCode ?? closestAirport.icao));
      // Update waypoint type to airport
      _flightPlanService.updateWaypointType(waypointIndex, WaypointType.airport);
      debugPrint('Waypoint renamed to: ${closestAirport.name}');
      return;
    }
    
    // If no airport found, check navaids
    final navaids = _navaids.where((navaid) {
      final lat = navaid.position.latitude;
      final lng = navaid.position.longitude;
      return lat >= bounds.south && 
             lat <= bounds.north && 
             lng >= bounds.west && 
             lng <= bounds.east;
    }).toList();
    
    // Find the closest navaid within search radius
    final closestNavaid = _findClosestItemWithinRadius<Navaid>(
      items: navaids,
      dropPosition: dropPosition,
      searchRadiusMeters: searchRadiusMeters,
      getPosition: (navaid) => navaid.position,
    );
    
    if (closestNavaid != null) {
      debugPrint('Found navaid nearby: ${closestNavaid.name} (${closestNavaid.ident})');
      // Update waypoint with navaid information
      _flightPlanService.updateWaypointName(waypointIndex, closestNavaid.name);
      _flightPlanService.updateWaypointNotes(waypointIndex, closestNavaid.ident);
      // Update waypoint type to navaid
      _flightPlanService.updateWaypointType(waypointIndex, WaypointType.navaid);
      debugPrint('Waypoint renamed to: ${closestNavaid.name}');
      return;
    }
    
    // If no navaid found, check reporting points
    if (_reportingPoints.isNotEmpty) {
      // Find the closest reporting point within search radius
      final closestPoint = _findClosestItemWithinRadius<ReportingPoint>(
        items: _reportingPoints,
        dropPosition: dropPosition,
        searchRadiusMeters: searchRadiusMeters,
        getPosition: (point) => point.position,
      );
      
      if (closestPoint != null) {
        debugPrint('Found reporting point nearby: ${closestPoint.displayName}');
        // Update waypoint with reporting point information
        _flightPlanService.updateWaypointName(waypointIndex, closestPoint.displayName);
        _flightPlanService.updateWaypointNotes(waypointIndex, closestPoint.type ?? 'Reporting Point');
        // Update waypoint type to reporting point
        _flightPlanService.updateWaypointType(waypointIndex, WaypointType.reportingPoint);
        debugPrint('Waypoint renamed to: ${closestPoint.displayName}');
        return;
      }
    }
    
    // If no marker found at drop position, keep it as a user waypoint
    // The position has already been updated by updateWaypointPosition
    debugPrint('No markers found nearby - keeping original waypoint name');
    } catch (e) {
      // Handle cases where map controller is not ready
      // Position update already happened, just skip marker detection
    }
  }

  // Handle terrain warning
  void _onTerrainWarning() {
    // No longer needed - terrain warning is displayed at the top of the screen
    // The TerrainDangerOverlay widget handles its own display
  }

  // Handle SafeSky beacon selection
  void _onSafeSkyBeaconTapped(SafeSkyBeacon beacon) {
    if (!mounted) return;
    
    final l10n = AppLocalizations.of(context)!;
    
    // Show a simple info dialog for the beacon
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black87,
        title: Row(
          children: [
            Icon(
              beacon.beaconType == 'HELICOPTER' ? Icons.toys :
              beacon.beaconType == 'JET' ? Icons.flight :
              beacon.beaconType == 'GLIDER' ? Icons.sailing :
              beacon.beaconType == 'PARA_GLIDER' ? Icons.paragliding :
              Icons.airplanemode_active,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(
              beacon.callSign ?? beacon.id,
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(l10n.type, beacon.beaconTypeDisplay),
            _buildInfoRow(l10n.altitude, beacon.altitudeString),
            _buildInfoRow(l10n.speed, beacon.groundSpeedString),
            _buildInfoRow(l10n.heading, beacon.courseString),
            if (beacon.verticalRate != null && beacon.verticalRate != 0)
              _buildInfoRow(
                l10n.verticalSpeed,
                '${(beacon.verticalRate! * 196.85).round()} fpm',
              ),
            _buildInfoRow(l10n.state, beacon.statusString),
            if (beacon.transponderType != null)
              _buildInfoRow('Transponder', beacon.transponderType!),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close, style: const TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Handle airport selection
  Future<void> _onAirportSelected(Airport airport) async {
    // If the airport doesn't have complete data, try to load it from tiles
    Airport fullAirport = airport;
    
    // Check if essential fields are missing
    final needsFullData = (airport.runways == null || airport.runways!.isEmpty) || 
        (airport.frequencies == null || airport.frequencies!.isEmpty) ||
        airport.name.isEmpty || airport.name == 'Unknown Airport' ||
        airport.city.isEmpty || airport.city == 'Unknown' ||
        airport.country.isEmpty || airport.country == 'Unknown';
    
    if (needsFullData) {
      try {
        // Load the area around the airport to ensure we have full data
        final airports = await TiledDataLoader().loadAirportsForArea(
          minLat: airport.position.latitude - 0.1,
          maxLat: airport.position.latitude + 0.1,
          minLon: airport.position.longitude - 0.1,
          maxLon: airport.position.longitude + 0.1,
        );
        
        // Find the airport with matching ICAO
        final tiledAirport = airports.firstWhere(
          (a) => a.icao == airport.icao,
          orElse: () => airport,
        );
        
        if (tiledAirport.icao == airport.icao) {
          fullAirport = tiledAirport;
        } else {
          debugPrint('No matching airport found for ${airport.icao} in ${airports.length} loaded airports');
        }
      } catch (e) {
        // Failed to load full data, continue with partial data
      }
    }
    debugPrint('_onAirportSelected called for ${airport.icao} - ${airport.name}');

    // If in flight planning mode, add airport as waypoint instead of showing details
    if (_flightPlanService.isPlanning) {
      debugPrint('Flight planning mode active - adding airport as waypoint');
      // Check if there's a current flight plan
      if (_flightPlanService.currentFlightPlan == null) {
        debugPrint('No current flight plan, creating new one...');
        _flightPlanService.startNewFlightPlan(enablePlanning: true);
      }
      _flightPlanService.addAirportWaypoint(fullAirport);
      debugPrint('Added airport waypoint: ${airport.icao} - ${airport.name}');
      return;
    }

    if (!mounted) {
      // debugPrint('Context not mounted, returning early');
      return;
    }

    try {
      // debugPrint('Showing bottom sheet for ${airport.icao}');
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) => AirportInfoSheet(
          airport: fullAirport,
          weatherService: _weatherService,
          onClose: () {
            // debugPrint('Closing bottom sheet for ${airport.icao}');
            Navigator.of(context).pop();
          },
        ),
      );
      // debugPrint('Bottom sheet closed for ${airport.icao}');
    } catch (e) {
      // debugPrint('Error showing bottom sheet for ${airport.icao}: $e');
      // debugPrint('Stack trace: $stackTrace');
      // Try to show error to user
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorShowingAirportDetails)),
        );
      }
    }
  }

  // Handle airport selection from search
  void _onAirportSelectedFromSearch(Airport airport) {
    // Close the search dialog first
    Navigator.of(context).pop();
    
    // Debug logging
    
    // Focus map on the selected airport
    _mapController.move(
      airport.position,
      14.0, // Zoom level for airport focus
    );

    // Handle auto-centering state the same way as manual map movement
    if (_autoCenteringEnabled && _positionTrackingEnabled) {
      setState(() {
        _autoCenteringEnabled = false;
      });
      // Cancel any existing timer
      _autoCenteringTimer?.cancel();
      _countdownTimer?.cancel();
      
      // Handle differently based on tracking mode
      if (_flightService.isTracking) {
        // During flight tracking, re-enable after 3 minutes
        _startAutoCenteringCountdown();
      } else if (_positionTrackingEnabled) {
        // During position tracking (without flight tracking), re-enable after delay
        _startAutoCenteringCountdown();
      }
      // For non-tracking mode, auto-centering stays disabled until manually re-enabled
    }

    // Load airports in the new area
    _loadAirports();

    // Load navaids if they're enabled
    if (_mapStateController.showNavaids) {
      _loadNavaids();
    }

    // Load airspaces and reporting points if they're enabled
    if (_mapStateController.showAirspaces) {
      _loadAirspaces();
      _loadReportingPoints();
    }

    // Load weather data for new airports if METAR overlay is enabled
    if (_mapStateController.showMetar) {
      _loadWeatherForVisibleAirports();
    }

    // Show airport info sheet
    _onAirportSelected(airport);
  }
  
  // Handle navaid selection from search
  void _onNavaidSelectedFromSearch(Navaid navaid) {
    // Close the search dialog first
    Navigator.of(context).pop();
    
    // Focus map on the selected navaid
    _mapController.move(
      navaid.position,
      14.0, // Zoom level for navaid focus
    );

    // Handle auto-centering state the same way as manual map movement
    if (_autoCenteringEnabled && _positionTrackingEnabled) {
      setState(() {
        _autoCenteringEnabled = false;
      });
      // Cancel any existing timer
      _autoCenteringTimer?.cancel();
      _countdownTimer?.cancel();
      
      // Handle differently based on tracking mode
      if (_flightService.isTracking) {
        // During flight tracking, re-enable after 3 minutes
        _startAutoCenteringCountdown();
      } else if (_positionTrackingEnabled) {
        // During position tracking (without flight tracking), re-enable after delay
        _startAutoCenteringCountdown();
      }
    }

    // Load data for the new area
    _loadAirports();
    // Load navaids if they're enabled
    if (_mapStateController.showNavaids) {
      _loadNavaids();
    }
    // Load airspaces and reporting points if they're enabled
    if (_mapStateController.showAirspaces) {
      _loadAirspaces();
      _loadReportingPoints();
    }
    // Load weather data for new airports if METAR overlay is enabled
    if (_mapStateController.showMetar) {
      _loadWeatherForVisibleAirports();
    }
    
    // If in flight planning mode, add navaid as waypoint
    if (_flightPlanService.isPlanning) {
      _flightPlanService.addNavaidWaypoint(navaid);
    }
  }

  // Show airport search
  void _showAirportSearch() async {
    // Load navaids for a wider area around the current map center before showing search
    final center = _mapController.camera.center;
    const searchRadius = 2.0; // degrees - wider area for search
    
    await _navaidService.loadNavaidsForArea(
      minLat: center.latitude - searchRadius,
      maxLat: center.latitude + searchRadius,
      minLon: center.longitude - searchRadius,
      maxLon: center.longitude + searchRadius,
    );
    
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AirportSearchDialog(
        airportService: _airportService,
        navaidService: _navaidService,
        searchHistoryService: Provider.of<SearchHistoryService>(context, listen: false),
        onAirportSelected: _onAirportSelectedFromSearch,
        onNavaidSelected: _onNavaidSelectedFromSearch,
      ),
    );
  }

  /// Focuses the map on a specific waypoint by index.
  /// Maintains current zoom level and disables auto-centering.
  void _focusOnWaypoint(int waypointIndex) {
    final flightPlan = _flightPlanService.currentFlightPlan;
    if (flightPlan == null || 
        waypointIndex < 0 || 
        waypointIndex >= flightPlan.waypoints.length) {
      return;
    }
    
    try {

    final waypoint = flightPlan.waypoints[waypointIndex];
    _mapController.move(
      waypoint.latLng,
      _mapController.camera.zoom, // Keep current zoom level
    );

    // Disable auto-centering when focusing on waypoint
    _disableAutoCentering();
    } catch (e) {
      // Handle cases where map controller is not ready
    }
  }

  /// Disables auto-centering mode and cancels related timers.
  /// Used when user manually interacts with the map.
  void _disableAutoCentering() {
    if (_autoCenteringEnabled) {
      setState(() {
        _autoCenteringEnabled = false;
      });
      _autoCenteringTimer?.cancel();
      _countdownTimer?.cancel();
    }
  }

  /// Centers the map on the current flight plan or trip.
  /// For trips, includes all waypoints from all flight plans.
  void _centerOnFlightPlan() {
    // Get all flight plans to center on (either from trip or single plan)
    final List<FlightPlan> plansToCenter;
    if (_flightPlanService.currentTripPlans.isNotEmpty) {
      plansToCenter = _flightPlanService.currentTripPlans;
    } else if (_flightPlanService.currentFlightPlan != null) {
      plansToCenter = [_flightPlanService.currentFlightPlan!];
    } else {
      return;
    }

    // Collect all waypoints from all plans
    final allWaypoints = <LatLng>[];
    for (final plan in plansToCenter) {
      allWaypoints.addAll(plan.waypoints.map((w) => w.latLng));
    }

    if (allWaypoints.isEmpty) {
      return;
    }

    try {
      // Use built-in method for better performance
      final bounds = LatLngBounds.fromPoints(allWaypoints);
      
      // Handle edge case: all waypoints at same location
      if (bounds.north == bounds.south && bounds.east == bounds.west) {
        // Single point or all waypoints at same location
        _mapController.move(
          LatLng(bounds.north, bounds.east),
          MapConstants.singlePointZoom,
        );
        _disableAutoCentering();
        return;
      }
      
      // Calculate padding based on bounds size
      final latPadding = (bounds.north - bounds.south) * MapConstants.boundsPaddingFactor;
      final lngPadding = (bounds.east - bounds.west) * MapConstants.boundsPaddingFactor;
      
      // Create padded bounds
      final paddedBounds = LatLngBounds(
        LatLng(bounds.south - latPadding, bounds.west - lngPadding),
        LatLng(bounds.north + latPadding, bounds.east + lngPadding),
      );

      // Fit bounds with animation
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: paddedBounds,
          maxZoom: MapConstants.maxFitZoom,
          padding: EdgeInsets.all(MapConstants.fitPadding),
        ),
      );

      // Disable auto-centering when fitting flight plan
      _disableAutoCentering();
    } catch (e) {
      // Handle cases where map controller is not ready
    }
  }

  /// Fits the entire flight plan in view with appropriate padding.
  /// Calculates bounds of all waypoints and adds 10% padding.
  /// Handles edge cases like single waypoint or same-location waypoints.
  void _fitFlightPlanBounds() {
    final flightPlan = _flightPlanService.currentFlightPlan;
    if (flightPlan == null || flightPlan.waypoints.isEmpty) {
      return;
    }
    
    try {

    // Use built-in method for better performance
    final bounds = LatLngBounds.fromPoints(
      flightPlan.waypoints.map((w) => w.latLng).toList(),
    );
    
    // Handle edge case: all waypoints at same location
    if (bounds.north == bounds.south && bounds.east == bounds.west) {
      // Single point or all waypoints at same location
      _mapController.move(
        LatLng(bounds.north, bounds.east),
        MapConstants.singlePointZoom,
      );
      _disableAutoCentering();
      return;
    }
    
    // Calculate padding based on bounds size
    final latPadding = (bounds.north - bounds.south) * MapConstants.boundsPaddingFactor;
    final lngPadding = (bounds.east - bounds.west) * MapConstants.boundsPaddingFactor;
    
    // Create padded bounds
    final paddedBounds = LatLngBounds(
      LatLng(bounds.south - latPadding, bounds.west - lngPadding),
      LatLng(bounds.north + latPadding, bounds.east + lngPadding),
    );

    // Fit bounds with animation
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: paddedBounds,
        maxZoom: MapConstants.maxFitZoom,
        padding: EdgeInsets.all(MapConstants.fitPadding),
      ),
    );

    // Disable auto-centering when fitting flight plan
    _disableAutoCentering();
    } catch (e) {
      // Handle cases where map controller is not ready
    }
  }

  // Handle navaid selection
  Future<void> _onNavaidSelected(Navaid navaid) async {
    debugPrint('_onNavaidSelected called for ${navaid.ident} - ${navaid.name}');

    // If in flight planning mode, add navaid as waypoint instead of showing details
    if (_flightPlanService.isPlanning) {
      debugPrint('Flight planning mode active - adding navaid as waypoint');
      // Check if there's a current flight plan
      if (_flightPlanService.currentFlightPlan == null) {
        debugPrint('No current flight plan, creating new one...');
        _flightPlanService.startNewFlightPlan(enablePlanning: true);
      }
      _flightPlanService.addNavaidWaypoint(navaid);
      debugPrint('Added navaid waypoint: ${navaid.ident} - ${navaid.name}');
      return;
    }

    if (!mounted) {
      // debugPrint('Context not mounted, returning early');
      return;
    }

    try {
      // debugPrint('Showing bottom sheet for ${navaid.ident}');
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (BuildContext context) => NavaidInfoSheet(
          navaid: navaid,
          onClose: () {
            Navigator.of(context).pop();
          },
        ),
      );
      // debugPrint('Bottom sheet closed for ${navaid.ident}');
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorShowingNavaidDetails)),
        );
      }
    }
  }

  // Handle airspace selection
  Future<void> _onAirspaceSelected(Airspace airspace) async {
    if (!mounted) {
      return;
    }

    try {
      final l10n = AppLocalizations.of(context)!;
      // Create a themed dialog to show airspace information
      // Include ICAO class in title if available
      final icaoClass = AirspaceUtils.getIcaoClassName(airspace.icaoClass);
      final titleText = airspace.icaoClass != null && icaoClass != 'Unclassified'
          ? '${airspace.name} (Class $icaoClass)'
          : airspace.name;
      
      await ThemedDialog.show(
        context: context,
        title: titleText,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (airspace.type != null)
              _buildThemedInfoRow(
                'Type',
                AirspaceUtils.getAirspaceTypeName(airspace.type),
              ),
            if (airspace.icaoClass != null)
              _buildThemedInfoRow(
                'ICAO Class',
                AirspaceUtils.getIcaoClassName(airspace.icaoClass),
              ),
            if (airspace.activity != null)
              _buildThemedInfoRow(
                'Activity',
                AirspaceUtils.getActivityName(airspace.activity),
              ),
            _buildThemedInfoRow(l10n.altitude, airspace.altitudeRange),
            if (airspace.country != null)
              _buildThemedInfoRow(l10n.country, airspace.country!),
            // Display frequency information using the new widget
            if (airspace.hasFrequencyInfo) ...[
              const SizedBox(height: 8),
              AirspaceFrequencyDisplay(
                airspace: airspace,
                showDetails: true,
                showCallsign: true,
              ),
            ] else if (airspace.remarks != null &&
                _extractFrequency(airspace.remarks!) != null)
              // Fallback to old frequency extraction from remarks
              _buildThemedInfoRow(
                'Frequency',
                _extractFrequency(airspace.remarks!)!,
              ),
            if (airspace.onDemand == true)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  '⚠️ On Demand',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.warningColor,
                  ),
                ),
              ),
            if (airspace.onRequest == true)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  '⚠️ On Request',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.warningColor,
                  ),
                ),
              ),
            if (airspace.byNotam == true)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  '⚠️ By NOTAM',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.warningColor,
                  ),
                ),
              ),
            if (airspace.remarks != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Remarks:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryAccent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      airspace.remarks!,
                      style: TextStyle(color: AppColors.secondaryTextColor),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        ],
      );
    } catch (e) {
      // debugPrint('Error showing airspace details: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorShowingAirspaceDetails)),
        );
      }
    }
  }

  // Handle reporting point selection
  Future<void> _onReportingPointSelected(ReportingPoint point) async {
    debugPrint('_onReportingPointSelected called for ${point.name}');
    
    // If in flight planning mode, add reporting point as waypoint instead of showing details
    if (_flightPlanService.isPlanning) {
      debugPrint('Flight planning mode active - adding reporting point as waypoint');
      // Check if there's a current flight plan
      if (_flightPlanService.currentFlightPlan == null) {
        debugPrint('No current flight plan, creating new one...');
        _flightPlanService.startNewFlightPlan(enablePlanning: true);
      }
      _flightPlanService.addReportingPointWaypoint(point);
      debugPrint('Added reporting point waypoint: ${point.name}');
      return;
    }
    
    if (!mounted) {
      return;
    }

    try {
      final l10n = AppLocalizations.of(context)!;
      // Create a themed dialog to show reporting point information
      await ThemedDialog.show(
        context: context,
        title: point.displayName,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemedInfoRow(l10n.name, point.name),
            if (point.type != null) _buildThemedInfoRow(l10n.type, point.type!),
            if (point.elevationString.isNotEmpty)
              _buildThemedInfoRow(l10n.elevation, point.elevationString),
            if (point.country != null)
              _buildThemedInfoRow(l10n.country, point.country!),
            if (point.state != null) _buildThemedInfoRow(l10n.state, point.state!),
            if (point.airportName != null)
              _buildThemedInfoRow(l10n.airport, point.airportName!),
            if (point.description != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Description:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryAccent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      point.description!,
                      style: TextStyle(color: AppColors.secondaryTextColor),
                    ),
                  ],
                ),
              ),
            if (point.remarks != null)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Remarks:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryAccent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      point.remarks!,
                      style: TextStyle(color: AppColors.secondaryTextColor),
                    ),
                  ],
                ),
              ),
            if (point.tags != null && point.tags!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${l10n.tags}:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryAccent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      point.tags!.join(', '),
                      style: TextStyle(color: AppColors.secondaryTextColor),
                    ),
                  ],
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
        ],
      );
    } catch (e) {
      // debugPrint('Error showing reporting point details: $e');
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorShowingReportingPointDetails),
          ),
        );
      }
    }
  }
  
  // Handle obstacle selection
  Future<void> _onObstacleSelected(Obstacle obstacle) async {
    if (!mounted) {
      return;
    }
    try {
      final l10n = AppLocalizations.of(context)!;
      // Create a themed dialog to show obstacle information
      await ThemedDialog.show(
        context: context,
        title: obstacle.displayName,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemedInfoRow(l10n.name, obstacle.name),
            if (obstacle.type != null)
              _buildThemedInfoRow(l10n.type, obstacle.type!),
            if (obstacle.heightFt != null)
              _buildThemedInfoRow(l10n.height, '${obstacle.heightFt} ft'),
            if (obstacle.elevationFt != null)
              _buildThemedInfoRow(l10n.elevation, '${obstacle.elevationFt} ft'),
            _buildThemedInfoRow(l10n.totalHeight, '${obstacle.totalHeightFt} ft MSL'),
            _buildThemedInfoRow(l10n.lighted, obstacle.lighted ? l10n.yes : l10n.no),
            if (obstacle.marking != null && obstacle.marking!.isNotEmpty)
              _buildThemedInfoRow(l10n.marking, obstacle.marking!),
            if (obstacle.country != null)
              _buildThemedInfoRow(l10n.country, obstacle.country!),
            const SizedBox(height: 8),
            Text(
              'Position: ${obstacle.latitude.toStringAsFixed(5)}, ${obstacle.longitude.toStringAsFixed(5)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorShowingObstacleDetails),
          ),
        );
      }
    }
  }
  
  // Handle hotspot selection
  Future<void> _onHotspotSelected(Hotspot hotspot) async {
    if (!mounted) {
      return;
    }
    try {
      final l10n = AppLocalizations.of(context)!;
      // Create a themed dialog to show hotspot information
      await ThemedDialog.show(
        context: context,
        title: hotspot.displayName,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemedInfoRow(l10n.name, hotspot.name),
            if (hotspot.type != null)
              _buildThemedInfoRow(l10n.type, hotspot.type!),
            if (hotspot.elevationFt != null)
              _buildThemedInfoRow(l10n.elevation, hotspot.elevationString),
            if (hotspot.reliability != null)
              _buildThemedInfoRow(l10n.reliability, hotspot.reliabilityString),
            if (hotspot.occurrence != null && hotspot.occurrence!.isNotEmpty)
              _buildThemedInfoRow(l10n.occurrence, hotspot.occurrence!),
            if (hotspot.conditions != null && hotspot.conditions!.isNotEmpty)
              _buildThemedInfoRow(l10n.conditions, hotspot.conditions!),
            if (hotspot.description != null && hotspot.description!.isNotEmpty)
              _buildThemedInfoRow(l10n.description, hotspot.description!),
            if (hotspot.country != null)
              _buildThemedInfoRow(l10n.country, hotspot.country!),
            const SizedBox(height: 8),
            Text(
              'Position: ${hotspot.latitude.toStringAsFixed(5)}, ${hotspot.longitude.toStringAsFixed(5)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorShowingHotspotDetails),
          ),
        );
      }
    }
  }

  Widget _buildThemedInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryAccent,
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: AppColors.secondaryTextColor)),
          ),
        ],
      ),
    );
  }

  /// Extract frequency information from remarks or other text
  String? _extractFrequency(String text) {
    // Common frequency patterns:
    // - 123.456 MHz
    // - 123.45 MHz
    // - 123.4 MHz
    // - FREQ: 123.456
    // - Frequency: 123.456
    // - Tower 123.456
    // - APP 123.456
    final frequencyPattern = RegExp(
      r'(?:freq(?:uency)?|tower|app|ground|atis|approach|departure|center|control|radio)?\s*:?\s*(\d{3}\.\d{1,3})(?:\s*mhz)?',
      caseSensitive: false,
    );

    final match = frequencyPattern.firstMatch(text);
    if (match != null) {
      final freq = match.group(1);
      return '$freq MHz';
    }

    return null;
  }

  /// Initialize services with cached data
  Future<void> _initializeServices() async {
    // Guard against concurrent initialization
    if (_isInitializing) return;

    _isInitializing = true; // Set the guard flag

    try {
      await _airportService.initialize();
      await _navaidService.initialize();
      
      // Initialize runway service
      await _runwayService.initialize();
      
      // Initialize flight heatmap processor
      await FlightHeatmapProcessor.init();
      
      // Connect SpatialAirspaceService to FlightPlanService
      if (_openAIPService != null) {
        _flightPlanService.setSpatialAirspaceService(spatialAirspaceService);
      }

      // Initialize offline map service only on supported platforms
      if (!kIsWeb && (Platform.isIOS || Platform.isAndroid)) {
        try {
          _offlineMapService = OfflineMapService();
          await _offlineMapService!.initialize();
          
          // Initialize tile download service for flight plans
          _offlineDataController = OfflineDataStateController();
          _tileDownloadService = FlightPlanTileDownloadService(
            offlineMapService: _offlineMapService!,
            offlineDataController: _offlineDataController!,
          );
          
          // Connect tile download service to flight plan service
          _flightPlanService.setTileDownloadService(_tileDownloadService!);
          if (mounted) {
            _flightPlanService.setContext(context);
          }
          
          // Don't validate here - services might not be fully ready
        } catch (e) {
          // Handle initialization errors gracefully
          _logger.w('Offline maps not available: ${e.toString().split('(')[0]}');
          // Continue without offline maps - they're optional
        }
      }

      // Only set servicesInitialized to true after all async initialization completes
      if (mounted) {
        setState(() {
          _servicesInitialized = true;
        });
        
        // Validate flight plan tiles after all services are initialized
        if (_tileDownloadService != null) {
          _validateFlightPlanTiles();
        }
      }
    } catch (e) {
      // debugPrint('⚠️ Error initializing services: $e');
      // Don't set _servicesInitialized = true if initialization failed
    } finally {
      _isInitializing = false; // Reset the guard flag
    }
  }

  // Load weather data for airports currently visible on the map
  Future<void> _loadWeatherForVisibleAirports() async {
    if (_airports.isEmpty) return;

    await MapProfiler.profileMapOperation('loadWeatherForVisibleAirports', () async {
    try {
      // Get the current map bounds
      final bounds = _mapController.camera.visibleBounds;
      
      // Get only the airports that are actually visible on the map (same filtering as markers)
      final visibleAirports = _airports.where((airport) {
        // Small airports are always shown (filtered by zoom level automatically)
        // Filter closed airports (use correct lowercase "closed" check)
        if (airport.type.toLowerCase() == 'closed') {
          return false;
        }

        // First check if airport is within visible bounds
        if (!bounds.contains(airport.position)) {
          return false;
        }
        
        // Filter heliports and balloonports based on toggle
        if ((airport.type == 'heliport' || airport.type == 'balloonport') && !_mapStateController.showHeliports) {
          return false;
        }
        // Show medium and large airports always, and show small airports/heliports based on toggles
        return true;
      }).toList();

      if (visibleAirports.isEmpty) return;

      // Get only the ICAOs of airports that are actually visible
      final visibleAirportIcaos = visibleAirports
          .map((airport) => airport.icao)
          .toList();

      // Fetch weather data for visible airports
      await _weatherService.initialize();
      final metarData = await _weatherService.getMetarsForAirports(
        visibleAirportIcaos,
      );
      final tafData = await _weatherService.getTafsForAirports(
        visibleAirportIcaos,
      );

      // Update only the visible airports with weather data
      bool hasUpdates = false;
      for (final airport in visibleAirports) {
        final metar = metarData[airport.icao];
        final taf = tafData[airport.icao];
        if (metar != null) {
          airport.updateWeather(metar, taf: taf);
          hasUpdates = true;
        }
      }

      // Trigger UI update if we got new weather data
      if (hasUpdates && mounted) {
        setState(() {
          // Force rebuild to show updated weather data
        });
      }
    } catch (e) {
      // debugPrint('❌ Error loading weather for visible airports: $e');
    }
    });
  }

  
  @override
  Widget build(BuildContext context) {
    return _buildContent(context);
  }
  
  Widget _buildContent(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      key: _scaffoldKey,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            fit: StackFit.expand,
            children: [
              // Map layer with 3D tilt support
              // Keep bottom edge fixed, extend only upward for tilted view
              ClipRect(
                child: OverflowBox(
                  maxWidth: constraints.maxWidth * (1 + _mapTilt / 30.0), // Slight width extension
                  maxHeight: constraints.maxHeight * (2 + _mapTilt / 20.0), // Extend height for perspective view
                  alignment: Alignment.bottomCenter, // Keep bottom edge anchored
                  child: Transform(
                    alignment: Alignment.bottomCenter, // Rotate around bottom edge
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001) // Stronger perspective for more natural 3D
                      ..rotateX(-_mapTilt * math.pi / 180) // Negative rotation tilts top away
                      ..scale(1.0 + _mapTilt / 60.0), // Gentler scaling
                    child: Stack(
                      children: [
                        FlutterMap(
                    key: _mapKey,
                    mapController: _mapController,
                    options: MapOptions(
              initialCenter: _currentPosition != null
                  ? LatLng(
                      _currentPosition!.latitude,
                      _currentPosition!.longitude,
                    )
                  : const LatLng(
                      37.7749,
                      -122.4194,
                    ), // Default to San Francisco
              initialZoom: MapConstants.initialZoom,
              minZoom: MapConstants.minZoom,
              maxZoom: MapConstants.maxZoom,
              interactionOptions: InteractionOptions(
                flags: _isDraggingWaypoint
                    ? InteractiveFlag
                          .none // Disable all map interactions when dragging waypoint
                    : InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
              onTap: (tapPosition, point) => _onMapTapped(tapPosition, point),
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  // Disable auto-centering when user manually moves the map
                  if (_autoCenteringEnabled) {
                    setState(() {
                      _autoCenteringEnabled = false;
                    });

                    // Cancel any existing timer
                    _autoCenteringTimer?.cancel();
                    _countdownTimer?.cancel();

                    // Handle differently based on tracking mode
                    if (_flightService.isTracking) {
                      // During flight tracking, re-enable after 3 minutes
                      _startAutoCenteringCountdown();
                    } else if (_positionTrackingEnabled) {
                      // During position tracking, re-enable after delay
                      _startAutoCenteringCountdown();
                    }
                  }
                }

                // Always load data when map position changes (regardless of gesture)
                // This ensures data loads on initial map setup and programmatic moves
                // Use frame-aware scheduler for staggered loading
                final scheduler = FrameAwareScheduler();
                
                // Load airports first (highest priority)
                scheduler.scheduleOperation(
                  id: 'load_airports',
                  operation: _loadAirports,
                  debounce: const Duration(milliseconds: 300),
                  highPriority: true,
                );
                
                // Load navaids with delay
                if (_mapStateController.showNavaids) {
                  scheduler.scheduleOperation(
                    id: 'load_navaids',
                    operation: _loadNavaids,
                    debounce: const Duration(milliseconds: 600),
                  );
                }
                
                // Reporting points with more delay
                if (_mapStateController.showAirspaces) {
                  scheduler.scheduleOperation(
                    id: 'load_reporting_points',
                    operation: _loadReportingPoints,
                    debounce: const Duration(milliseconds: 800),
                  );
                }
                
                // Obstacles with delay
                if (_mapStateController.showObstacles) {
                  scheduler.scheduleOperation(
                    id: 'load_obstacles',
                    operation: _loadObstacles,
                    debounce: const Duration(milliseconds: 900),
                  );
                }
                
                // Hotspots with delay  
                if (_mapStateController.showHotspots) {
                  scheduler.scheduleOperation(
                    id: 'load_hotspots',
                    operation: _loadHotspots,
                    debounce: const Duration(milliseconds: 950),
                  );
                }
                
                // Weather data with even more delay
                if (_mapStateController.showMetar) {
                  scheduler.scheduleOperation(
                    id: 'load_weather',
                    operation: _loadWeatherForVisibleAirports,
                    debounce: const Duration(milliseconds: 1000),
                  );
                }
                
                // NOTAMs with lowest priority
                scheduler.scheduleOperation(
                  id: 'prefetch_notams',
                  operation: _schedulePrefetchVisibleAirportNotams,
                  debounce: const Duration(milliseconds: 1500),
                );
                
                // Update SafeSky viewport if active
                if (_mapStateController.showSafeSky && hasGesture) {
                  _updateSafeSkyViewport();
                }
              },
            ),
            children: [
              // Tile layer with offline support
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.captainvfr',
                tileProvider: _servicesInitialized && _offlineMapService != null
                    ? OfflineTileProvider(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        offlineMapService: _offlineMapService!,
                        userAgentPackageName: 'com.example.captainvfr',
                      )
                    : null,
              ),
              // Elevation terrain with Swiss-style hillshading - BEFORE AIRSPACES
              if (_mapStateController.showElevation)
                const TerrainReliefOverlay(
                  isVisible: true,
                  opacity: 0.6,
                ),
              // 3D terrain relief overlay when tilted
              if (_mapTilt > 0)
                TerrainReliefOverlay(
                  isVisible: true,
                  opacity: math.min(0.8, _mapTilt / 45.0), // Increase opacity with tilt
                ),
              // Airspaces overlay - only show 2D version when map is flat
              if (_mapStateController.showAirspaces && _mapTilt == 0)
                OptimizedSpatialAirspacesOverlay(
                  spatialService: spatialAirspaceService,
                  showAirspacesLayer: _mapStateController.showAirspaces,
                  onAirspaceTap: _onAirspaceSelected,
                  currentAltitude: _currentPosition?.altitude ?? 0,
                ),
              // Reporting points overlay (optimized)
              if (_mapStateController.showAirspaces && _reportingPoints.isNotEmpty)
                OptimizedReportingPointsLayer(
                  reportingPoints: _reportingPoints,
                  onReportingPointTap: _onReportingPointSelected,
                ),
              // Obstacles overlay - only show 2D version when map is flat
              if (_mapStateController.showObstacles && _obstacles.isNotEmpty && _mapTilt == 0)
                OptimizedObstaclesLayer(
                  obstacles: _obstacles,
                  onObstacleTap: _onObstacleSelected,
                ),
              // Hotspots overlay (optimized)  
              if (_mapStateController.showHotspots && _hotspots.isNotEmpty)
                OptimizedHotspotsLayer(
                  hotspots: _hotspots,
                  onHotspotTap: _onHotspotSelected,
                ),
              
              // Flight heatmap overlay
              if (_mapStateController.showHeatmap)
                OptimizedHeatmapLayer(
                  opacity: 0.6,
                  enabled: _mapStateController.showHeatmap,
                ),
              // Airport markers with tap handling (optimized)
              Consumer<SettingsService>(
                builder: (context, settings, child) {
                  final filteredAirports = _airports.where((airport) {
                    // Filter heliports and balloonports based on toggle
                    if ((airport.type == 'heliport' || airport.type == 'balloonport') && !_mapStateController.showHeliports) {
                      return false;
                    }
                    // Small airports are always shown (filtered by zoom level automatically)
                    // Show medium and large airports always, and show small airports/heliports based on toggles
                    return true;
                  }).toList();
                  
                  return OptimizedAirportMarkersLayer(
                    airports: filteredAirports,
                    airportRunways: _airportRunways,
                    onAirportTap: _onAirportSelected,
                    showHeliports: _mapStateController.showHeliports,
                    distanceUnit: settings.distanceUnit,
                    showLabels: true,
                  );
                },
              ),
              // Navaid markers (optimized)
              if (_mapStateController.showNavaids && _navaids.isNotEmpty)
                OptimizedNavaidMarkersLayer(
                  navaids: _navaids,
                  onNavaidTap: _onNavaidSelected,
                  showLabels: true,
                ),
              // METAR overlay
              if (_mapStateController.showMetar)
                MetarOverlay(
                  airports: _airports,
                  showMetarLayer: _mapStateController.showMetar,
                  onAirportTap: _onAirportSelected,
                ),
              // SafeSky overlay - only show 2D version when map is flat
              if (_mapStateController.showSafeSky && _mapTilt == 0)
                AnimatedSafeSkyOverlay(
                  safeSkyService: _safeSkyService,
                  showSafeSkyLayer: _mapStateController.showSafeSky,
                  onBeaconTap: _onSafeSkyBeaconTapped,
                  currentPosition: _currentPosition,
                ),
              // Terrain danger overlay showing altitude-based terrain warnings
              if (_mapStateController.showTerrain && _currentPosition != null)
                TerrainDangerOverlay(
                  currentAltitudeFt: _currentPosition?.altitude ?? 0.0,
                  viewport: _mapController.camera.visibleBounds,
                  isVisible: _mapStateController.showTerrain,
                  onTerrainWarning: _onTerrainWarning,
                ),
              // Flight plan overlays - add before current position marker
              Consumer<FlightPlanService>(
                builder: (context, flightPlanService, child) {
                  // Get all flight plans to display (either from trip or single plan)
                  final List<FlightPlan> plansToDisplay;
                  if (flightPlanService.currentTripPlans.isNotEmpty) {
                    // Display all trip plans
                    plansToDisplay = flightPlanService.currentTripPlans;
                    debugPrint('Displaying trip with ${plansToDisplay.length} flight plans');
                  } else if (flightPlanService.currentFlightPlan != null) {
                    // Display single flight plan
                    plansToDisplay = [flightPlanService.currentFlightPlan!];
                  } else {
                    return const SizedBox.shrink();
                  }

                  if (!flightPlanService.isFlightPlanVisible) {
                    return const SizedBox.shrink();
                  }

                  // Build polylines for all flight plans
                  final allPolylines = <Polyline>[];
                  for (final flightPlan in plansToDisplay) {
                    if (flightPlan.waypoints.isNotEmpty) {
                      allPolylines.addAll(
                        FlightPlanOverlay.buildClickableFlightPath(
                          flightPlan,
                          _onFlightPathSegmentTapped,
                          flightPlanService.isPlanning,
                        ),
                      );
                    }
                  }
                  
                  // Add red transfer lines between flight plans in a trip
                  if (flightPlanService.currentTripPlans.length > 1) {
                    for (int i = 0; i < flightPlanService.currentTripPlans.length - 1; i++) {
                      final currentPlan = flightPlanService.currentTripPlans[i];
                      final nextPlan = flightPlanService.currentTripPlans[i + 1];
                      
                      if (currentPlan.waypoints.isNotEmpty && nextPlan.waypoints.isNotEmpty) {
                        final lastWaypoint = currentPlan.waypoints.last;
                        final firstWaypoint = nextPlan.waypoints.first;
                        
                        // Only add transfer line if waypoints are different
                        if (lastWaypoint.latitude != firstWaypoint.latitude ||
                            lastWaypoint.longitude != firstWaypoint.longitude) {
                          allPolylines.add(
                            Polyline(
                              points: [lastWaypoint.latLng, firstWaypoint.latLng],
                              strokeWidth: 3.0,
                              color: Colors.red.withValues(alpha: 0.7),
                              // Use pattern to create a dashed line effect
                              pattern: StrokePattern.dashed(segments: [10, 10]),
                            ),
                          );
                        }
                      }
                    }
                  }

                  return Stack(
                    children: [
                      // Flight plan route lines
                      PolylineLayer(
                        polylines: allPolylines,
                      ),
                      // Highlight next segment when tracking (only for current flight plan)
                      if (_flightService.isTracking && 
                          _currentPosition != null &&
                          flightPlanService.currentFlightPlan != null)
                        PolylineLayer(
                          polylines: FlightPlanOverlay.buildNextSegment(
                            flightPlanService.currentFlightPlan!,
                            LatLng(
                              _currentPosition!.latitude,
                              _currentPosition!.longitude,
                            ),
                          ),
                        ),
                      // Build markers for all flight plans
                      ...plansToDisplay.expand((flightPlan) => [
                        // Flight path segment click markers (for waypoint insertion)
                        if (flightPlan == flightPlanService.currentFlightPlan)
                          MarkerLayer(
                            markers: FlightPlanOverlay.buildSegmentClickMarkers(
                              flightPlan,
                              _onFlightPathSegmentTapped,
                              flightPlanService.isPlanning,
                            ),
                          ),
                        // Waypoint markers
                        MarkerLayer(
                          markers: FlightPlanOverlay.buildWaypointMarkers(
                            flightPlan,
                            flightPlan == flightPlanService.currentFlightPlan ? _onWaypointTapped : (index) {},
                            flightPlan == flightPlanService.currentFlightPlan ? _onWaypointMoved : (index, pos, {isDragging = false}) {},
                            flightPlan == flightPlanService.currentFlightPlan ? _selectedWaypointIndex : -1,
                            flightPlan == flightPlanService.currentFlightPlan ? (isDragging) {
                              setState(() {
                                _isDraggingWaypoint = isDragging;
                              });
                            } : (isDragging) {},
                            _mapKey,
                            flightPlan == flightPlanService.currentFlightPlan && flightPlanService.isPlanning,
                          ),
                        ),
                        // Waypoint name labels (only show when zoomed in)
                        if (_mapController.camera.zoom > 11)
                          MarkerLayer(
                            markers: FlightPlanOverlay.buildWaypointLabels(
                              flightPlan,
                              flightPlan == flightPlanService.currentFlightPlan ? _selectedWaypointIndex : -1,
                            ),
                          ),
                      ]),
                      // Segment labels (distance, heading, time) for all flight plans
                      ...plansToDisplay.map((flightPlan) => 
                        Builder(
                          builder: (context) {
                            return MarkerLayer(
                              markers: FlightPlanOverlay.buildSegmentLabels(
                                flightPlan,
                                context,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
              // Flight path layer - moved here to be above airspaces
              if (_flightPathPoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _flightPathPoints,
                      color: AppColors.errorColor,
                      strokeWidth: 6.0,
                      borderColor: Colors.white,
                      borderStrokeWidth: 2.0,
                    ),
                  ],
                ),
              // Flight segment markers
              if (_flightSegments.isNotEmpty)
                MarkerLayer(
                  markers: _flightSegments
                      .map(
                        (segment) => [
                          // Start marker
                          Marker(
                            point: segment.startLatLng,
                            width: 16,
                            height: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _getSegmentColor(segment.type),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                _getSegmentIcon(segment.type),
                                size: 8,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          // End marker
                          Marker(
                            point: segment.endLatLng,
                            width: 16,
                            height: 16,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _getSegmentColor(
                                  segment.type,
                                ).withValues(alpha: 0.7),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 2,
                                ),
                              ),
                              child: Icon(
                                Icons.flag,
                                size: 8,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      )
                      .expand((markers) => markers)
                      .toList(),
                ),
              // Current position marker
              if (_currentPosition != null)
                Consumer<SettingsService>(
                  builder: (context, settings, child) {
                    // Check if rotation mode changed and reset map if needed
                    if (_previousRotationMode != null && 
                        _previousRotationMode != settings.mapRotationMode) {
                      // Mode changed
                      if (settings.mapRotationMode != MapRotationMode.mapRotates) {
                        // Switching from map rotates to another mode - reset map to north
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (_mapController.camera.rotation != 0) {
                            _mapController.rotate(0);
                          }
                        });
                      }
                    }
                    _previousRotationMode = settings.mapRotationMode;
                    
                    // Calculate aircraft marker rotation based on map rotation mode
                    double markerRotation;
                    _updateCachedHeading();
                    final currentHeading = _cachedHeading ?? _currentPosition?.heading ?? 0;
                    
                    switch (settings.mapRotationMode) {
                      case MapRotationMode.mapRotates:
                        // Map rotates, aircraft marker must counter-rotate to stay pointing up
                        // Get the current map rotation and rotate marker in opposite direction
                        final mapRotation = _mapController.camera.rotation;
                        // Counter-rotate: if map rotates clockwise, marker rotates counter-clockwise
                        markerRotation = -mapRotation * math.pi / 180;
                        break;
                      case MapRotationMode.aircraftRotates:
                      case MapRotationMode.none:
                        // Map fixed north-up, aircraft marker rotates to show heading
                        // Icons.navigation points up by default (north)
                        markerRotation = currentHeading * math.pi / 180;
                        break;
                    }
                    
                    return MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          ),
                          width: 30,
                          height: 30,
                          child: Transform.rotate(
                            angle: markerRotation,
                            child: const Icon(
                              Icons.navigation,
                              color: Colors.blue,
                              size: 30,
                              shadows: [
                                Shadow(
                                  offset: Offset(1, 1),
                                  blurRadius: 2,
                                  color: Colors.black54,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              
              // Profile selected point marker - blue marker showing selected point from altitude chart
              if (_profileSelectedPoint != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _profileSelectedPoint!,
                      width: 80,
                      height: 80,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // Outer pulsing circle for better visibility
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.3),
                                width: 2,
                              ),
                            ),
                          ),
                          // Middle ring
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.3),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.6),
                                width: 2,
                              ),
                            ),
                          ),
                          // Center marker
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade600,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.4),
                                  blurRadius: 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                          ),
                          // Altitude label on top
                          if (_profileSelectedAltitude != null)
                            Positioned(
                              top: -10,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade800,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.white, width: 2),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.3),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '${_profileSelectedAltitude!.toStringAsFixed(0)} ft',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
                        // 3D overlays rendered on top of the map when tilted
                        if (_mapTilt > 0) ...[
                          // 3D Airspaces overlay
                          if (_mapStateController.showAirspaces)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: SimpleAirspaces3DOverlay(
                                  spatialService: spatialAirspaceService,
                                  showAirspacesLayer: _mapStateController.showAirspaces,
                                  onAirspaceTap: _onAirspaceSelected,
                                  currentAltitude: _currentPosition?.altitude ?? 0,
                                  mapTilt: _mapTilt,
                                  mapController: _mapController,
                                ),
                              ),
                            ),
                          // 3D Obstacles overlay
                          if (_mapStateController.showObstacles && _obstacles.isNotEmpty)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Obstacles3DOverlay(
                                  obstacles: _obstacles,
                                  mapTilt: _mapTilt,
                                  onObstacleTap: _onObstacleSelected,
                                  currentAltitude: _currentPosition?.altitude ?? 0,
                                  mapController: _mapController,
                                ),
                              ),
                            ),
                          // 3D SafeSky overlay
                          if (_mapStateController.showSafeSky)
                            Positioned.fill(
                              child: IgnorePointer(
                                child: SafeSky3DOverlay(
                                  beacons: _safeSkyService.beacons,
                                  mapTilt: _mapTilt,
                                  onBeaconTap: _onSafeSkyBeaconTapped,
                                  currentAltitude: _currentPosition?.altitude ?? 0,
                                  currentPosition: _currentPosition != null
                                    ? LatLng(_currentPosition!.latitude, _currentPosition!.longitude)
                                    : null,
                                  mapController: _mapController,
                                ),
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
          
          // Terrain warning text display - shows at top when terrain is dangerous
          if (_servicesInitialized)
            Builder(
              builder: (context) {
                LatLngBounds? viewport;
                try {
                  viewport = _mapController.camera.visibleBounds;
                } catch (e) {
                  // Map controller not ready yet
                  viewport = null;
                }
                return TerrainWarningDisplay(
                  currentAltitudeFt: _currentPosition?.altitude,
                  viewport: viewport,
                  isVisible: _mapStateController.showTerrain,
                );
              },
            ),
          
          // Emergency button - top right, below menu button
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            right: 16,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showEmergencyPanel = !_showEmergencyPanel;
                });
              },
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.red.shade700,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white,
                    width: 3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: Colors.red.withValues(alpha: 0.5),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.warning,
                      color: Colors.white,
                      size: 28,
                    ),
                    SizedBox(height: 2),
                    Text(
                      'SOS',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Emergency panel - full screen overlay
          if (_showEmergencyPanel)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.5),
                child: Column(
                  children: [
                    const Spacer(),
                    EmergencyPanel(
                      onClose: () {
                        setState(() {
                          _showEmergencyPanel = false;
                        });
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Flight tracking panel - always visible on bottom right
          const FlightTrackingPanel(),
          
          // Airspace information panel
          if (_showCurrentAirspacePanel) ...[
            Builder(
              builder: (context) {
                final position = _airspacePanelPosition ?? _getCenteredAirspacePanelPosition(context);
                return Positioned(
                  left: position.dx,
                  top: position.dy,
                  child: Draggable<String>(
                data: 'airspace_panel',
                feedback: Material(
                  color: Colors.transparent,
                  child: Container(
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width < 600
                          ? MediaQuery.of(context).size.width - 16
                          : MediaQuery.of(context).size.width < 1200
                          ? 500
                          : 600,
                    ),
                    child: Builder(
                      builder: (context) {
                        // Always show airspace panel
                        LatLng position;
                        double altitude = 0.0;
                        double heading = 0.0;
                        double speed = 0.0;
                        
                        if (_currentPosition != null) {
                          // Use actual GPS position if available
                          position = LatLng(
                            _currentPosition!.latitude,
                            _currentPosition!.longitude,
                          );
                          altitude = _currentPosition!.altitude;
                          heading = _currentPosition!.heading;
                          speed = _currentPosition!.speed;
                        } else {
                          // Use map center as position
                          final mapController = MapController.maybeOf(context);
                          if (mapController != null) {
                            try {
                              position = mapController.camera.center;
                            } catch (e) {
                              // Default position if map not ready
                              position = LatLng(50.0, 14.0); // Default to central Europe
                            }
                          } else {
                            position = LatLng(50.0, 14.0); // Default to central Europe
                          }
                        }
                        
                        return AirspaceFlightInfo(
                          currentPosition: position,
                          currentAltitude: altitude,
                          currentHeading: heading,
                          currentSpeed: speed,
                          openAIPService: openAIPService,
                          onAirspaceSelected: _onAirspaceSelected,
                        );
                      },
                    ),
                  ),
                ),
                childWhenDragging: Container(), // Empty container when dragging
                onDragEnd: (details) {
                  setState(() {
                    // Calculate new position based on drag end position
                    final screenSize = MediaQuery.of(context).size;
                    final isPhone = screenSize.width < 600;
                    final isTablet =
                        screenSize.width >= 600 && screenSize.width < 1200;

                    double newX = details.offset.dx;
                    double newY = details.offset.dy;

                    // Get panel dimensions based on device type
                    final panelWidth = isPhone
                        ? screenSize.width - 16
                        : (isTablet ? 500 : 600);
                    final panelHeight = _airspacePanelHeight;

                    // Allow free horizontal movement on all devices
                    // Constrain to keep panel visible on screen
                    newX = newX.clamp(
                      -panelWidth + _minPanelVisibility, // Allow partial off-screen to the left
                      screenSize.width - _minPanelVisibility, // Allow partial off-screen to the right
                    );

                    // Allow free vertical movement
                    // Constrain to keep panel visible on screen
                    newY = newY.clamp(
                      -panelHeight + _minPanelVisibility, // Allow partial off-screen at top
                      screenSize.height - _minPanelVisibility, // Allow partial off-screen at bottom
                    );

                    _airspacePanelPosition = Offset(newX, newY);
                    // Save position to SharedPreferences
                    _saveAirspacePanelPosition(_airspacePanelPosition!);
                  });
                },
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width < 600
                        ? MediaQuery.of(context).size.width - 16
                        : MediaQuery.of(context).size.width < 1200
                        ? 500
                        : 600,
                  ),
                  child: Builder(
                    builder: (context) {
                      // Always show airspace panel
                      LatLng position;
                      double altitude = 0.0;
                      double heading = 0.0;
                      double speed = 0.0;
                      
                      if (_currentPosition != null) {
                        // Use actual GPS position if available
                        position = LatLng(
                          _currentPosition!.latitude,
                          _currentPosition!.longitude,
                        );
                        altitude = _currentPosition!.altitude;
                        heading = _currentPosition!.heading;
                        speed = _currentPosition!.speed;
                      } else {
                        // Use map center as position
                        final mapController = MapController.maybeOf(context);
                        if (mapController != null) {
                          try {
                            position = mapController.camera.center;
                          } catch (e) {
                            // Default position if map not ready
                            position = LatLng(50.0, 14.0); // Default to central Europe
                          }
                        } else {
                          position = LatLng(50.0, 14.0); // Default to central Europe
                        }
                      }

                      return AirspaceFlightInfo(
                        currentPosition: position,
                        currentAltitude: altitude,
                        currentHeading: heading,
                        currentSpeed: speed,
                        openAIPService: openAIPService,
                        onAirspaceSelected: _onAirspaceSelected,
                        onClose: () {
                          setState(() {
                            _showCurrentAirspacePanel = false;
                          });
                        },
                      );
                    },
                  ),
                ),
              ),
                );
              },
            ),
          
          ],

          // OpenStreetMap attribution - centered horizontally, behind all controls
          Positioned(
            top: MediaQuery.of(context).padding.top + 8, // Same as zoom controls
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5), // More visible
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: InkWell(
                    onTap: () async {
                      const url = 'https://openstreetmap.org/copyright';
                      if (await canLaunchUrl(Uri.parse(url))) {
                        await launchUrl(Uri.parse(url));
                      }
                    },
                    child: Text(
                      '© OpenStreetMap',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withValues(alpha: 0.7), // More visible white text
                        decoration: TextDecoration.none, // Remove underline for cleaner look
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Grouped control buttons (Center, 3D, Search) in a single container for proper spacing
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: _menuButtonMargin + _menuButtonWidth + _buttonSpacing,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.9),
                borderRadius: AppTheme.largeRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Center button
                  Container(
                    padding: const EdgeInsets.all(4),
                    child: CenterButton(
                      positionTrackingEnabled: _positionTrackingEnabled,
                      autoCenteringEnabled: _autoCenteringEnabled,
                      autoCenteringCountdown: _autoCenteringCountdown,
                      onToggle: _togglePositionTracking,
                    ),
                  ),

                  // Search button
                  GestureDetector(
                    onTap: () {
                      _showAirportSearch();
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: const Icon(
                        Icons.search,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Menu button in top-right corner
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 16,
            child: GestureDetector(
              onTap: () {
                debugPrint('Menu button tapped');
                _mapStateController.toggleMenuPanel();
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.9),
                  borderRadius: AppTheme.largeRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.menu,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),

          // Unified sliding menu panel from right side
          ListenableBuilder(
            listenable: _mapStateController,
            builder: (context, child) {
              if (!_mapStateController.isMenuPanelOpen) {
                return const SizedBox.shrink();
              }
              return Positioned(
                top: 0,
                right: 0,
                bottom: 0,
                child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _mapStateController.closeMenuPanel();
                },
                child: Container(
                  color: Colors.black.withValues(alpha: 0.3), // Overlay
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: Row(
                    children: [
                      // Spacer that handles taps to close
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _mapStateController.closeMenuPanel();
                          },
                          child: Container(color: Colors.transparent),
                        ),
                      ),
                      // The actual panel - wrap in GestureDetector to prevent closing
                      GestureDetector(
                        onTap: () {}, // Prevent tap from propagating to close
                        child: Container(
                        width: math.min(MediaQuery.of(context).size.width * 0.8, 300),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.9),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 16,
                              offset: const Offset(-4, 0),
                            ),
                          ],
                        ),
                        child: SafeArea(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Panel header
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.white.withValues(alpha: 0.2),
                                      width: 1,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.menu,
                                      color: Colors.white,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Menu',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      icon: const Icon(Icons.close, color: Colors.white),
                                      onPressed: () {
                                        _mapStateController.closeMenuPanel();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              // Scrollable content
                              Expanded(
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildUnifiedMenuContent(l10n),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      ), // Close GestureDetector for panel
                    ],
                  ),
                ),
              ),
            );
            },
          ),

          // License warning widget - only show when not tracking
          if (!_flightService.isTracking)
            const Positioned(
              top: 100,
              left: 16,
              right: 16,
              child: LicenseWarningWidget(),
            ),

          // Flight planning UI panels
          Consumer<FlightPlanService>(
            builder: (context, flightPlanService, child) {
              return Stack(
                children: [
                  // Flight Planning Panel - left-side sliding panel
                  if (_showFlightPlanning)
                    Positioned(
                      left: 0,
                      top: MediaQuery.of(context).padding.top + 60,
                      bottom: 60,
                      width: (_flightPlanningExpanded 
                          ? (MediaQuery.of(context).size.width < 600 
                              ? MediaQuery.of(context).size.width * 0.85
                              : 400.0)
                          : 60.0),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        width: (_flightPlanningExpanded 
                            ? (MediaQuery.of(context).size.width < 600 
                                ? MediaQuery.of(context).size.width * 0.85
                                : 400.0)
                            : 60.0),
                        decoration: BoxDecoration(
                          color: const Color(0xE6000000),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
                          border: Border(
                            top: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                            right: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                            bottom: BorderSide(
                              color: Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                            // No left border - connected to edge
                          ),
                        ),
                        child: FlightPlanningPanel(
                          onWaypointFocus: _focusOnWaypoint,
                          onCenterFlightPlan: _centerOnFlightPlan,
                          onMapFocus: (position, {altitude, distance}) {
                            // Focus on the selected position from altitude profile
                            _mapController.move(position, _mapController.camera.zoom);
                            
                            // If altitude and distance are provided, this is a profile point selection
                            if (altitude != null && distance != null) {
                              setState(() {
                                _profileSelectedPoint = position;
                                _profileSelectedAltitude = altitude;
                                _profileSelectedDistance = distance;
                              });
                            } else {
                              // Clear selection if just focusing without selection
                              setState(() {
                                _profileSelectedPoint = null;
                                _profileSelectedAltitude = null;
                                _profileSelectedDistance = null;
                              });
                            }
                          },
                          onClose: () {
                            setState(() {
                              _showFlightPlanning = false;
                              // Clear profile selection when panel is closed
                              _profileSelectedPoint = null;
                              _profileSelectedAltitude = null;
                              _profileSelectedDistance = null;
                            });
                            // Don't stop planning mode - let it persist when panel is hidden
                            // User can add waypoints on the map even with panel hidden
                          },
                        ),
                      ),
                    ),
                  
                  // Toggle button - always visible, centered vertically
                  Positioned(
                    left: _showFlightPlanning
                        ? (_flightPlanningExpanded 
                            ? (MediaQuery.of(context).size.width < 600 
                                ? MediaQuery.of(context).size.width * 0.85
                                : 400.0)
                            : 60.0)
                        : 0,
                    top: (MediaQuery.of(context).size.height - 100) / 2, // Center vertically
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _showFlightPlanning = !_showFlightPlanning;
                          if (_showFlightPlanning && !_flightPlanningExpanded) {
                            // Auto-expand when opening from collapsed state
                            _flightPlanningExpanded = true;
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 36,
                        height: 100,
                        decoration: BoxDecoration(
                          // Show orange background when in edit mode
                          color: flightPlanService.isPlanning 
                              ? const Color(0xFFFF6B35) // Orange for edit mode
                              : const Color(0xE6000000), // Black when not editing
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(8),
                            bottomRight: Radius.circular(8),
                            // No left rounded corners - always connected to edge
                          ),
                          border: Border(
                            top: BorderSide(
                              color: flightPlanService.isPlanning 
                                  ? const Color(0xFFFF8C55) // Lighter orange border when editing
                                  : Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                            right: BorderSide(
                              color: flightPlanService.isPlanning 
                                  ? const Color(0xFFFF8C55) // Lighter orange border when editing
                                  : Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                            bottom: BorderSide(
                              color: flightPlanService.isPlanning 
                                  ? const Color(0xFFFF8C55) // Lighter orange border when editing
                                  : Colors.white.withValues(alpha: 0.2),
                              width: 1,
                            ),
                            left: _showFlightPlanning 
                              ? BorderSide.none  // No left border when panel is open
                              : BorderSide(      // Left border when panel is closed
                                  color: flightPlanService.isPlanning 
                                      ? const Color(0xFFFF8C55)
                                      : Colors.white.withValues(alpha: 0.2),
                                  width: 1,
                                ),
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.route,
                              color: flightPlanService.isPlanning
                                  ? Colors.white // White icon when in edit mode (orange background)
                                  : (flightPlanService.currentFlightPlan != null || 
                                      flightPlanService.currentTrip != null)
                                      ? const Color(0xFF448AFF)
                                      : Colors.white.withValues(alpha: 0.7),
                              size: 20,
                            ),
                            const SizedBox(height: 4),
                            Icon(
                              _showFlightPlanning
                                  ? Icons.chevron_left
                                  : Icons.chevron_right,
                              color: flightPlanService.isPlanning
                                  ? Colors.white // White chevron when in edit mode
                                  : Colors.white.withValues(alpha: 0.8),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Floating waypoint panel for selected waypoint
                  if (_selectedWaypointIndex != null &&
                      flightPlanService.currentFlightPlan != null &&
                      _selectedWaypointIndex! <
                          flightPlanService.currentFlightPlan!.waypoints.length)
                    FloatingWaypointPanel(
                      waypointIndex: _selectedWaypointIndex!,
                      isEditMode: flightPlanService.isPlanning,
                      onClose: () {
                        setState(() {
                          _selectedWaypointIndex = null;
                        });
                      },
                    ),
                ],
              );
            },
          ),

          // Location loading notification
          if (_locationNotificationShown)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: SensorNotification(
                    sensorName: l10n.gettingLocation,
                    message: l10n.acquiringGpsPosition,
                    icon: Icons.location_searching,
                    backgroundColor: const Color(0xFFE3F2FD), // Light blue
                    iconColor: const Color(0xFF1976D2), // Blue
                    autoDismissAfter: const Duration(seconds: 3),
                    onDismiss: _dismissLocationNotification,
                  ),
                ),
              ),
            ),
          // Loading progress bar at the bottom center
          const Positioned(
            bottom: 60, // Above map controls
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: false, // Allow interaction with the close button
              child: LoadingProgressBar(),
            ),
          ),
          
          // Gesture hints overlay for first-time users
          if (_showGestureHints)
            Positioned.fill(
              child: GestureHintsOverlay(
                onDismiss: () {
                  setState(() {
                    _showGestureHints = false;
                  });
                },
              ),
            ),
          
          // Zoom control buttons in top left corner, aligned with menu button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8, // Same as menu button
            left: 12,
            child: MapZoomControls(
              mapController: _mapController,
              minZoom: MapConstants.minZoom,
              maxZoom: MapConstants.maxZoom,
              onZoomChanged: _onZoomButtonPressed,
              isCompact: true, // Make controls smaller
            ),
          ),
          
          // Map overlay indicators (north arrow, zoom level, scale bar)
          MapOverlayIndicators(
            camera: _mapController.camera,
          ),
            ],
          );
        },
      ),
    ); // Closing Scaffold
  }

  
  // Show dialog to open app settings



  Color _getSegmentColor(String segmentType) {
    return SegmentUtils.getSegmentColor(segmentType);
  }

  IconData _getSegmentIcon(String segmentType) {
    return SegmentUtils.getSegmentIcon(segmentType);
  }

  Widget _buildUnifiedMenuContent(AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Layer Toggles Section
        Text(
          l10n.mapLayers,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Responsive toggle buttons layout
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _buildMenuToggleButton(
              icon: FontAwesomeIcons.helicopter,
              label: 'Heliports',
              isActive: _mapStateController.showHeliports,
              onPressed: _toggleHeliports,
            ),
            _buildMenuToggleButton(
              icon: _mapStateController.showNavaids
                  ? Icons.navigation
                  : Icons.navigation_outlined,
              label: l10n.navaids,
              isActive: _mapStateController.showNavaids,
              onPressed: _toggleNavaids,
            ),
            _buildMenuToggleButton(
              icon: _mapStateController.showMetar
                  ? Icons.cloud
                  : Icons.cloud_outlined,
              label: l10n.metar,
              isActive: _mapStateController.showMetar,
              onPressed: _toggleMetar,
            ),
            _buildMenuToggleButton(
              icon: _mapStateController.showAirspaces
                  ? Icons.layers
                  : Icons.layers_outlined,
              label: l10n.airspaces,
              isActive: _mapStateController.showAirspaces,
              onPressed: _toggleAirspaces,
            ),
            _buildMenuToggleButton(
              icon: Icons.warning_amber_rounded,
              label: l10n.obstacles,
              isActive: _mapStateController.showObstacles,
              onPressed: _toggleObstacles,
            ),
            _buildMenuToggleButton(
              icon: Icons.location_on,
              label: l10n.hotspots,
              isActive: _mapStateController.showHotspots,
              onPressed: _toggleHotspots,
            ),
            _buildMenuToggleButton(
              icon: _mapStateController.showHeatmap
                  ? Icons.whatshot
                  : Icons.whatshot_outlined,
              label: l10n.heatmap,
              isActive: _mapStateController.showHeatmap,
              onPressed: _toggleHeatmap,
            ),
            _buildMenuToggleButton(
              icon: _mapStateController.showSafeSky
                  ? Icons.airplanemode_active
                  : Icons.airplanemode_inactive,
              label: l10n.safeSky,
              isActive: _mapStateController.showSafeSky,
              onPressed: _toggleSafeSky,
            ),
            _buildMenuToggleButton(
              icon: _mapStateController.showTerrain
                  ? Icons.terrain
                  : Icons.terrain_outlined,
              label: 'Terrain',
              isActive: _mapStateController.showTerrain,
              onPressed: _toggleTerrain,
            ),
            _buildMenuToggleButton(
              icon: _mapStateController.showElevation
                  ? Icons.landscape
                  : Icons.landscape_outlined,
              label: 'Elevation',
              isActive: _mapStateController.showElevation,
              onPressed: _toggleElevation,
            ),
            _buildMenuToggleButton(
              icon: _showCurrentAirspacePanel
                  ? Icons.account_tree
                  : Icons.account_tree_outlined,
              label: l10n.currentAirspace,
              isActive: _showCurrentAirspacePanel,
              onPressed: () {
                setState(() {
                  _showCurrentAirspacePanel = !_showCurrentAirspacePanel;
                  if (_showCurrentAirspacePanel) {
                    // Load saved position when showing panel
                    _loadAirspacePanelPosition();
                  }
                });
              },
            ),
          ],
        ),
        
        const SizedBox(height: 24),
        
        // Divider
        Container(
          height: 1,
          color: Colors.white.withValues(alpha: 0.2),
        ),
        
        const SizedBox(height: 24),
        
        // Menu Items Section
        Text(
          l10n.navigation,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildMenuItem(
          icon: Icons.flight_takeoff,
          label: l10n.flightLog,
          onPressed: () {
            _mapStateController.closeMenuPanel();
            _pauseAllTimers();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FlightLogScreen(),
              ),
            ).then((_) => _resumeAllTimers());
          },
        ),
        _buildMenuItem(
          icon: Icons.menu_book,
          label: l10n.logBook,
          onPressed: () {
            _mapStateController.closeMenuPanel();
            _pauseAllTimers();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LogBookScreen(),
              ),
            ).then((_) => _resumeAllTimers());
          },
        ),
        _buildMenuItem(
          icon: Icons.checklist,
          label: l10n.checklists,
          onPressed: () {
            _mapStateController.closeMenuPanel();
            _pauseAllTimers();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ChecklistSettingsScreen(),
              ),
            ).then((_) => _resumeAllTimers());
          },
        ),
        _buildMenuItem(
          icon: Icons.airplanemode_active,
          label: l10n.aircrafts,
          onPressed: () {
            _mapStateController.closeMenuPanel();
            _pauseAllTimers();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AircraftSettingsScreen(),
              ),  
            ).then((_) => _resumeAllTimers());
          },
        ),
        _buildMenuItem(
          icon: Icons.calculate,
          label: l10n.calculators,
          onPressed: () {
            _mapStateController.closeMenuPanel();
            _pauseAllTimers();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CalculatorsScreen(),
              ),
            ).then((_) => _resumeAllTimers());
          },
        ),
        _buildMenuItem(
          icon: Icons.settings,
          label: l10n.settings,
          onPressed: () {
            _mapStateController.closeMenuPanel();
            _pauseAllTimers();
            SettingsDialog.show(
              context,
              currentMapBounds: _mapController.camera.visibleBounds,
            ).then((_) => _resumeAllTimers());
          },
        ),
        _buildMenuItem(
          icon: Icons.language,
          label: 'www.captainvfr.com',
          onPressed: () {
            _mapStateController.closeMenuPanel();
            launchUrl(Uri.parse('https://www.captainvfr.com'));
          },
        ),
        
        const SizedBox(height: 24),
        
        // Divider
        Container(
          height: 1,
          color: Colors.white.withValues(alpha: 0.2),
        ),
        
        const SizedBox(height: 24),

      ],
    );
  }

  Widget _buildMenuToggleButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onPressed,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: AppTheme.defaultRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isActive 
              ? Colors.orange.withValues(alpha: 0.2)
              : Colors.white.withValues(alpha: 0.1),
          borderRadius: AppTheme.defaultRadius,
          border: Border.all(
            color: isActive 
                ? Colors.orange
                : Colors.white.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.orange : Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.orange : Colors.white,
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    String? subtitle,
  }) {
    return InkWell(
      onTap: onPressed,
      borderRadius: AppTheme.defaultRadius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: AppTheme.defaultRadius,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: Colors.white,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.orange.shade300,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 16,
              color: Colors.white,
            ),
          ],
        ),
      ),
    );
  }
}
