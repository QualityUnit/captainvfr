import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/flight_service.dart';
import '../services/aircraft_settings_service.dart';
import '../services/barometer_service.dart';
import '../services/heading_service.dart';
import 'flight_dashboard/components/expanded_view.dart';
import 'flight_dashboard/components/stop_tracking_dialog.dart';
import 'flight_dashboard/constants/flight_panel_constants.dart';
import '../screens/flight_detail_screen.dart';
import '../l10n/app_localizations.dart';

class FlightTrackingPanel extends StatefulWidget {
  final VoidCallback? onClose;

  const FlightTrackingPanel({
    super.key, 
    this.onClose,
  });

  @override
  State<FlightTrackingPanel> createState() => _FlightTrackingPanelState();
}

class _FlightTrackingPanelState extends State<FlightTrackingPanel> 
    with WidgetsBindingObserver {
  bool _isExpanded = false;
  Timer? _headingCheckTimer;
  bool _hasShownPermissionDialog = false;
  static const String _permissionNotificationKey = 'has_shown_location_permission_notification';
  static const String _expandedStateKey = 'flight_tracking_panel_expanded';
  
  // Remove animation controller - panel is always visible

  @override
  void initState() {
    super.initState();
    
    // Panel is always visible, no need for animation controller
    
    // Add lifecycle observer to detect when app returns from background
    WidgetsBinding.instance.addObserver(this);
    
    // Load saved preferences
    _loadPreferences();

    // Auto-select aircraft and start services after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSelectAircraft();
      _startHeadingService();
      _startBarometerService();
      _startPeriodicHeadingCheck();
    });
  }
  
  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _hasShownPermissionDialog = prefs.getBool(_permissionNotificationKey) ?? false;
    final savedExpanded = prefs.getBool(_expandedStateKey) ?? false;
    if (mounted) {
      setState(() {
        _isExpanded = savedExpanded;
      });
    }
  }
  
  Future<void> _saveExpandedState(bool expanded) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_expandedStateKey, expanded);
  }
  
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App returned from background - refresh heading service
      // This happens when user returns from Settings
      _startHeadingService();
    }
  }

  void _autoSelectAircraft() {
    final aircraftService = context.read<AircraftSettingsService>();
    final flightService = context.read<FlightService>();

    // Only auto-select if no aircraft is currently selected
    if (aircraftService.selectedAircraft == null &&
        aircraftService.aircrafts.isNotEmpty) {
      if (aircraftService.aircrafts.length == 1) {
        // Only one aircraft - auto-select it
        aircraftService.aircraftService.selectAircraft(
          aircraftService.aircrafts.first.id,
        );
        if (flightService.isTracking) {
          flightService.setAircraft(aircraftService.aircrafts.first);
        }
      } else if (aircraftService.aircrafts.length > 1) {
        // Multiple aircraft - try to select the last used one
        final flights = flightService.flights;
        if (flights.isNotEmpty) {
          // For now, just select the first aircraft
          aircraftService.aircraftService.selectAircraft(
            aircraftService.aircrafts.first.id,
          );
          if (flightService.isTracking) {
            flightService.setAircraft(aircraftService.aircrafts.first);
          }
        }
      }
    }
  }

  void _startHeadingService() async {
    try {
      // Start heading service when panel is shown
      final headingService = context.read<HeadingService>();
      
      // Always try to start/restart the service
      await headingService.retryStart();
      
      // Only show permission notification once and only if permission is actually denied
      if (!_hasShownPermissionDialog && mounted) {
        // Check actual permission status
        final whenInUseStatus = await Permission.locationWhenInUse.status;
        final alwaysStatus = await Permission.locationAlways.status;
        
        // Only show notification if permission is truly denied or permanently denied
        if ((whenInUseStatus.isDenied || whenInUseStatus.isPermanentlyDenied) &&
            (alwaysStatus.isDenied || alwaysStatus.isPermanentlyDenied)) {
          _hasShownPermissionDialog = true;
          _showPermissionDeniedNotification();
        }
      }
    } catch (e) {
      // Handle permission check errors gracefully (e.g., in simulator)
      // Permission check error - non-critical
    }
  }
  
  void _startBarometerService() async {
    try {
      // Initialize barometer service to provide altitude data even when not tracking
      final flightService = context.read<FlightService>();
      await flightService.initializeBarometerService();
    } catch (e) {
      // Barometer initialization errors are non-critical
      // The app will fall back to GPS altitude
    }
  }
  
  void _startPeriodicHeadingCheck() {
    // Check heading service every 2 seconds to ensure it's running
    _headingCheckTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      final headingService = context.read<HeadingService>();
      if (!headingService.isRunning && !headingService.hasError) {
        headingService.retryStart();
      }
    });
  }

  void _showPermissionDeniedNotification() async {
    if (!mounted) return;
    
    final l10n = AppLocalizations.of(context)!;
    
    // Save that we've shown the notification
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_permissionNotificationKey, true);
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.location_off,
              color: Colors.orange,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                l10n.locationPermissionNeeded,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: l10n.openSettings,
          onPressed: () {
            openAppSettings();
          },
        ),
        duration: const Duration(seconds: 6),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _headingCheckTimer?.cancel();
    super.dispose();
  }

  void _toggleExpanded() {
    // Add haptic feedback for better user experience
    HapticFeedback.lightImpact();
    setState(() {
      _isExpanded = !_isExpanded;
    });
    _saveExpandedState(_isExpanded);
  }

  @override
  Widget build(BuildContext context) {
    final safeAreaBottom = MediaQuery.of(context).padding.bottom;
    final flightService = Provider.of<FlightService>(context);
    final isTracking = flightService.isTracking;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Calculate panel width based on screen size
    // On small screens (phones), use most of the width
    // On larger screens (tablets/desktop), cap at max width
    double panelWidth;
    if (screenWidth < FlightPanelConstants.phoneMaxWidth) {
      // Phone: use full width
      panelWidth = screenWidth;
    } else if (screenWidth < 1200) {
      // Small tablet: max 600px
      panelWidth = screenWidth.clamp(
        FlightPanelConstants.smallTabletMinWidth, 
        FlightPanelConstants.smallTabletMaxWidth,
      );
    } else {
      // Large tablet/desktop: fixed width
      panelWidth = FlightPanelConstants.tabletMaxWidth;
    }
    
    // Panel slides from bottom to top
    return Positioned(
      left: (screenWidth - panelWidth) / 2, // Center horizontally
      right: (screenWidth - panelWidth) / 2,
      bottom: 0,
      child: AnimatedContainer(
        duration: FlightPanelConstants.panelAnimationDuration,
        curve: Curves.fastOutSlowIn, // More natural animation curve
        height: _isExpanded 
          ? FlightPanelConstants.expandedHeight + safeAreaBottom 
          : FlightPanelConstants.collapsedHeight + safeAreaBottom,
        width: panelWidth,
        decoration: BoxDecoration(
          color: const Color(FlightPanelConstants.panelBackgroundColor),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(FlightPanelConstants.panelBorderRadius),
            topRight: Radius.circular(FlightPanelConstants.panelBorderRadius),
          ),
          border: Border.all(
            color: isTracking 
              ? Colors.red.withValues(alpha: FlightPanelConstants.trackingBorderOpacity)
              : Colors.white.withValues(alpha: FlightPanelConstants.panelBorderOpacity),
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          child: Column(
            children: [
              // Handle at the top with compass icon
              Semantics(
                label: _isExpanded 
                  ? 'Collapse flight panel' 
                  : 'Expand flight panel',
                hint: 'Double tap to toggle',
                button: true,
                child: GestureDetector(
                  onTap: _toggleExpanded,
                  onVerticalDragUpdate: (details) {
                    // Allow dragging to expand/collapse
                    if (details.delta.dy < FlightPanelConstants.dragExpandThreshold && !_isExpanded) {
                      _toggleExpanded();
                    } else if (details.delta.dy > FlightPanelConstants.dragCollapseThreshold && _isExpanded) {
                      _toggleExpanded();
                    }
                  },
                  child: Container(
                    height: FlightPanelConstants.handleHeight,
                    decoration: BoxDecoration(
                      color: isTracking 
                        ? Colors.red.withValues(alpha: FlightPanelConstants.backgroundOverlayOpacity)
                        : Colors.transparent,
                    ),
                  child: Stack(
                    children: [
                      // Center content
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Drag handle bar
                            Container(
                              width: FlightPanelConstants.handleBarWidth,
                              height: FlightPanelConstants.handleBarHeight,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: FlightPanelConstants.handleBarOpacity),
                                borderRadius: BorderRadius.circular(FlightPanelConstants.handleBarBorderRadius),
                              ),
                            ),
                            SizedBox(width: FlightPanelConstants.largeSpacing),
                            // Compass icon
                            Icon(
                              Icons.explore,
                              color: isTracking 
                                ? Colors.red 
                                : Colors.white.withValues(alpha: FlightPanelConstants.iconInactiveOpacity),
                              size: FlightPanelConstants.handleIconSize,
                            ),
                            const SizedBox(width: 6),
                            // Title
                            Text(
                              isTracking ? 'TRACKING' : 'FLIGHT DATA',
                              style: TextStyle(
                                color: isTracking 
                                  ? Colors.red
                                  : Colors.white.withValues(alpha: FlightPanelConstants.iconInactiveOpacity),
                                fontSize: FlightPanelConstants.handleTitleFontSize,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                            // Recording indicator
                            if (isTracking) ...[
                              SizedBox(width: FlightPanelConstants.mediumSpacing),
                              Container(
                                width: FlightPanelConstants.recordingIndicatorSize,
                                height: FlightPanelConstants.recordingIndicatorSize,
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                            SizedBox(width: FlightPanelConstants.largeSpacing),
                            // Drag handle bar (right side)
                            Container(
                              width: FlightPanelConstants.handleBarWidth,
                              height: FlightPanelConstants.handleBarHeight,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: FlightPanelConstants.handleBarOpacity),
                                borderRadius: BorderRadius.circular(FlightPanelConstants.handleBarBorderRadius),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Tracking button on the right if expanded
                      if (_isExpanded)
                        Positioned(
                          right: FlightPanelConstants.defaultPadding,
                          top: 3,
                          child: Semantics(
                            label: flightService.isTracking 
                              ? 'Stop tracking' 
                              : 'Start tracking',
                            button: true,
                            child: Container(
                              width: FlightPanelConstants.trackingButtonSize,
                              height: FlightPanelConstants.trackingButtonSize,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: FlightPanelConstants.trackingButtonBackgroundOpacity),
                                border: Border.all(
                                  color: flightService.isTracking
                                      ? Colors.red.withValues(alpha: FlightPanelConstants.trackingActiveOpacity)
                                      : Colors.green.withValues(alpha: FlightPanelConstants.trackingActiveOpacity),
                                  width: FlightPanelConstants.trackingButtonBorderWidth,
                                ),
                                borderRadius: BorderRadius.circular(FlightPanelConstants.trackingButtonBorderRadius),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                borderRadius: BorderRadius.circular(FlightPanelConstants.trackingButtonBorderRadius),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(FlightPanelConstants.trackingButtonBorderRadius),
                                  onTap: () async {
                                    // Add haptic feedback
                                    HapticFeedback.mediumImpact();
                                  if (flightService.isTracking) {
                                    // Show confirmation dialog
                                    final shouldStop = await StopTrackingDialog.show(context);
                                    if (shouldStop == true) {
                                      final savedFlight = await flightService.stopTracking();
                                      
                                      // Navigate to flight detail if a flight was saved
                                      if (savedFlight != null && context.mounted) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => FlightDetailScreen(flight: savedFlight),
                                          ),
                                        );
                                      }
                                    }
                                  } else {
                                    flightService.startTracking();
                                  }
                                },
                                  child: Center(
                                    child: Icon(
                                      flightService.isTracking ? Icons.stop : Icons.play_arrow,
                                      color: flightService.isTracking ? Colors.red : Colors.green,
                                      size: FlightPanelConstants.trackingButtonIconSize,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              ),
              // Panel content
              if (_isExpanded)
                Expanded(
                  child: ExpandedView(
                    onCollapse: _toggleExpanded,
                    flightService: context.read<FlightService>(),
                    barometerService: context.read<BarometerService>(),
                  ),
                ),
              if (!_isExpanded)
                SizedBox(height: safeAreaBottom),
            ],
          ),
        ),
      ),
    );
  }
}