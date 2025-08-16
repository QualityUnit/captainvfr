import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/flight_service.dart';
import '../services/aircraft_settings_service.dart';
import '../services/barometer_service.dart';
import '../services/heading_service.dart';
import 'flight_dashboard/components/expanded_view.dart';
import 'flight_dashboard/components/collapsed_view.dart';
import '../l10n/app_localizations.dart';

class FlightTrackingPanel extends StatefulWidget {
  final VoidCallback? onClose;
  final bool isVisible;

  const FlightTrackingPanel({
    super.key, 
    this.onClose,
    this.isVisible = false,
  });

  @override
  State<FlightTrackingPanel> createState() => _FlightTrackingPanelState();
}

class _FlightTrackingPanelState extends State<FlightTrackingPanel> 
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  Timer? _headingCheckTimer;
  bool _hasShownPermissionDialog = false;
  static const String _permissionNotificationKey = 'has_shown_location_permission_notification';
  static const String _expandedStateKey = 'flight_tracking_panel_expanded';
  
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animation controller
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Set initial animation state based on visibility
    if (widget.isVisible) {
      _animationController.forward();
    }
    
    // Add lifecycle observer to detect when app returns from background
    WidgetsBinding.instance.addObserver(this);
    
    // Load saved preferences
    _loadPreferences();

    // Auto-select aircraft and start heading service after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSelectAircraft();
      _startHeadingService();
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
  void didUpdateWidget(FlightTrackingPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
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
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpanded() {
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
    
    // Calculate panel heights
    final collapsedHeight = 60.0 + safeAreaBottom;
    final expandedHeight = 260.0 + safeAreaBottom;
    final currentHeight = _isExpanded ? expandedHeight : collapsedHeight;
    
    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Positioned(
          left: 0,
          right: 0,
          bottom: -currentHeight * _slideAnimation.value,
          height: currentHeight,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.9),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Drag handle with recording indicator
                GestureDetector(
                  onTap: _toggleExpanded,
                  onVerticalDragUpdate: (details) {
                    // Allow dragging to expand/collapse
                    if (details.delta.dy < -10 && !_isExpanded) {
                      _toggleExpanded();
                    } else if (details.delta.dy > 10 && _isExpanded) {
                      _toggleExpanded();
                    }
                  },
                  child: Container(
                    height: 32,
                    decoration: BoxDecoration(
                      color: isTracking 
                        ? Colors.red.withValues(alpha: 0.2)
                        : Colors.transparent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                      border: isTracking 
                        ? Border.all(
                            color: Colors.red.withValues(alpha: 0.5),
                            width: 1,
                          )
                        : null,
                    ),
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Recording indicator
                          if (isTracking) ...[
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withValues(alpha: 0.5),
                                    blurRadius: 4,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'RECORDING',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          // Handle bar
                          Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isTracking 
                                ? Colors.red.withValues(alpha: 0.7)
                                : Colors.white.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Panel content
                Expanded(
                  child: _isExpanded
                    ? ExpandedView(
                        onCollapse: _toggleExpanded,
                        flightService: context.read<FlightService>(),
                        barometerService: context.read<BarometerService>(),
                      )
                    : CollapsedView(
                        onExpand: _toggleExpanded,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}