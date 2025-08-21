import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:latlong2/latlong.dart';
import '../services/flight_plan_service.dart';
import '../services/aircraft_settings_service.dart';
import '../services/settings_service.dart';
import '../screens/flight_plans_screen.dart';
import 'waypoint_table_widget.dart';
import 'altitude_profile_chart.dart';
import '../constants/app_theme.dart';
import '../l10n/app_localizations.dart';

class FlightPlanningPanel extends StatefulWidget {
  final VoidCallback? onClose;
  final Function(int)? onWaypointFocus;
  final VoidCallback? onCenterFlightPlan;
  final Function(LatLng, {double? altitude, double? distance})? onMapFocus;

  const FlightPlanningPanel({
    super.key,
    this.onClose,
    this.onWaypointFocus,
    this.onCenterFlightPlan,
    this.onMapFocus,
  });

  @override
  State<FlightPlanningPanel> createState() => _FlightPlanningPanelState();
}

class _FlightPlanningPanelState extends State<FlightPlanningPanel> with SingleTickerProviderStateMixin {
  bool _isEditMode = false;
  final TextEditingController _cruiseSpeedController = TextEditingController();
  String? _selectedAircraftId;
  int? _selectedWaypointIndex;
  Timer? _autosaveTimer;
  Timer? _cruiseSpeedDebouncer;
  bool _isWaypointTableExpanded = false; // Track waypoint table expanded state - default collapsed
  late TabController _tabController;
  
  static const String _waypointTableExpandedKey = 'waypoint_table_expanded';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    
    // Add listener to analyze flight path only when altitude profile tab is selected
    _tabController.addListener(() {
      if (_tabController.index == 1 && !_tabController.indexIsChanging) {
        // Altitude Profile tab is selected
        final flightPlanService = context.read<FlightPlanService>();
        if (flightPlanService.currentAirspaceProfile == null && 
            !flightPlanService.isAnalyzingProfile &&
            flightPlanService.currentFlightPlan != null &&
            flightPlanService.currentFlightPlan!.waypoints.isNotEmpty) {
          // Analyze the flight path if not already analyzed
          flightPlanService.analyzeCurrentFlightPath();
        }
      }
    });
    
    _loadWaypointTableState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final flightPlanService = context.read<FlightPlanService>();
      final aircraftService = context.read<AircraftSettingsService>();
      final flightPlan = flightPlanService.currentFlightPlan;

      // Always sync edit mode with planning mode state
      // This ensures the panel reflects the actual planning state
      if (flightPlanService.isPlanning != _isEditMode) {
        setState(() {
          _isEditMode = flightPlanService.isPlanning;
        });
      }

      if (flightPlan != null) {
        _selectedAircraftId = flightPlan.aircraftId;
        if (flightPlan.cruiseSpeed != null) {
          _cruiseSpeedController.text = flightPlan.cruiseSpeed!.toStringAsFixed(
            0,
          );
        }
      }

      // Auto-select aircraft if not already selected
      if (_selectedAircraftId == null && aircraftService.aircrafts.isNotEmpty) {
        final aircrafts = aircraftService.aircrafts;

        // Try to use the currently selected aircraft in aircraft service
        if (aircraftService.selectedAircraft != null) {
          setState(() {
            _selectedAircraftId = aircraftService.selectedAircraft!.id;
          });
          _updateAircraft(
            flightPlanService,
            aircraftService,
            aircraftService.selectedAircraft!.id,
          );
        } else if (aircrafts.length == 1) {
          // Only one aircraft - auto-select it
          setState(() {
            _selectedAircraftId = aircrafts.first.id;
          });
          _updateAircraft(
            flightPlanService,
            aircraftService,
            aircrafts.first.id,
          );
        }
        // Note: When multiple aircraft exist and none is selected, let user choose
        // had an aircraftId field in the future
      }
    });
  }

  @override
  void dispose() {
    _cruiseSpeedController.dispose();
    _autosaveTimer?.cancel();
    _cruiseSpeedDebouncer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flightPlanService = Provider.of<FlightPlanService>(context);

    // Get screen dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;

    // Responsive margins
    final horizontalMargin = isPhone ? 8.0 : 16.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalMargin,
        vertical: 8.0,
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
            children: [
              // Header with edit mode toggle
              _buildHeader(context, flightPlanService),
              // Expanded view takes all available space
              Expanded(
                child: _buildExpandedView(context, flightPlanService),
              ),
            ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    FlightPlanService flightPlanService,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final flightPlan = flightPlanService.currentFlightPlan;
    final isPlanning = flightPlanService.isPlanning;

    return Container(
      decoration: BoxDecoration(
        color: _isEditMode ? const Color(0x33448AFF) : Colors.transparent,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 12.0,
        vertical: 8.0,
      ),
      child: Row(
        children: [
          // Title and stats - now has more space without icons
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        // Show trip name if a trip is loaded, otherwise flight plan name
                        flightPlanService.currentTrip != null
                            ? flightPlanService.currentTrip!.name
                            : (flightPlan?.name ??
                                (isPlanning ? l10n.flightPlanningMode : l10n.noFlightPlan)),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                Consumer<SettingsService>(
                  builder: (context, settings, child) {
                      final isMetric = settings.units == 'metric';
                      
                      // Calculate total distance and waypoints
                      double totalDistance = 0;
                      int totalWaypoints = 0;
                      
                      if (flightPlanService.currentTrip != null && 
                          flightPlanService.currentTripPlans.isNotEmpty) {
                        // Trip: sum all plans
                        for (final plan in flightPlanService.currentTripPlans) {
                          totalDistance += plan.totalDistance;
                          totalWaypoints += plan.waypoints.length;
                        }
                        
                        final displayDistance = isMetric
                            ? totalDistance * 1.852
                            : totalDistance;
                        final unit = isMetric ? 'km' : 'nm';
                        
                        return Text(
                          '${flightPlanService.currentTripPlans.length} legs, $totalWaypoints waypoints, ${displayDistance.toStringAsFixed(0)} $unit',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        );
                      } else if (flightPlan != null && flightPlan.waypoints.isNotEmpty) {
                        // Single flight plan
                        final distance = flightPlan.totalDistance;
                        final displayDistance = isMetric
                            ? distance * 1.852
                            : distance;
                        final unit = isMetric ? 'km' : 'nm';
                        return Text(
                          l10n.waypointsAndDistance(flightPlan.waypoints.length, displayDistance.toStringAsFixed(0), unit),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
                          overflow: TextOverflow.ellipsis,
                        );
                      }
                      
                      return const SizedBox.shrink();
                    },
                  ),
              ],
            ),
          ),

          // Spacer to push controls to the right
          const Spacer(),

          // Control buttons row
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Center button with label
              if ((flightPlan != null && flightPlan.waypoints.isNotEmpty) || 
                  flightPlanService.currentTripPlans.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.center_focus_strong,
                          size: 20,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        onPressed: widget.onCenterFlightPlan,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 32,
                          minHeight: 32,
                        ),
                        tooltip: l10n.centerOnFlightPlan,
                      ),
                      Text(
                        'Center',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Edit mode toggle with label
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Transform.scale(
                      scale: 0.8,
                      child: Switch(
                        value: _isEditMode,
                        onChanged: (value) {
                          debugPrint('Edit mode switch changed to: $value');
                          debugPrint('Current isPlanning: ${flightPlanService.isPlanning}');
                          setState(() {
                            _isEditMode = value;
                          });
                          if (value && !flightPlanService.isPlanning) {
                            debugPrint('Enabling planning mode...');
                            flightPlanService.togglePlanningMode();
                          } else if (!value && flightPlanService.isPlanning) {
                            debugPrint('Disabling planning mode...');
                            flightPlanService.togglePlanningMode();
                          }
                          debugPrint('After toggle - isPlanning: ${flightPlanService.isPlanning}');
                        },
                        activeColor: const Color(0xFF448AFF),
                        activeTrackColor: const Color(0x66448AFF),
                        inactiveThumbColor: Colors.white,
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                      ),
                    ),
                    Text(
                      l10n.editMode,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.6),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExpandedView(
    BuildContext context,
    FlightPlanService flightPlanService,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final flightPlan = flightPlanService.currentFlightPlan;
    final hasFlightPlan = flightPlan != null || flightPlanService.currentTripPlans.isNotEmpty;

    // If no flight plan, show the flight plan tab content directly
    if (!hasFlightPlan) {
      return _buildFlightPlanTab(context, flightPlanService);
    }

    return Column(
      children: [
        // Tab bar
        Container(
          color: Colors.black.withValues(alpha: 0.8),
          child: TabBar(
            controller: _tabController,
            indicatorColor: Colors.orange,
            labelColor: Colors.orange,
            unselectedLabelColor: Colors.grey[400],
            tabs: [
              Tab(
                icon: const Icon(Icons.route, size: 20),
                text: l10n.flightPlan,
              ),
              Tab(
                icon: const Icon(Icons.terrain, size: 20),
                text: l10n.altitudeProfile,
              ),
            ],
          ),
        ),
        // Tab content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildFlightPlanTab(context, flightPlanService),
              _buildAltitudeProfileTab(context, flightPlanService),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFlightPlanTab(
    BuildContext context,
    FlightPlanService flightPlanService,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final flightPlan = flightPlanService.currentFlightPlan;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Aircraft selection and cruise speed
          _buildAircraftSection(flightPlanService),

          // Edit mode hint
          if (_isEditMode)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0x1A448AFF),
                borderRadius: AppTheme.mediumRadius,
                border: Border.all(color: const Color(0x33448AFF)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: Colors.blue.shade400,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l10n.clickOnMapToAddWaypoints,
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0x4DFFFFFF),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Show "Load Flight Plan" button when no waypoints exist
          if (flightPlan == null && flightPlanService.currentTripPlans.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 16),
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () => _openFlightPlansScreen(context),
                  icon: const Icon(Icons.folder_open, size: 20),
                  label: Text(l10n.loadToMap),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF448AFF),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.mediumRadius,
                    ),
                  ),
                ),
              ),
            ),

          // Waypoint table - show all waypoints from trip or single flight plan
          if (flightPlan != null || flightPlanService.currentTripPlans.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              child: Consumer<AircraftSettingsService>(
                builder: (context, aircraftService, child) {
                  final selectedAircraft = _selectedAircraftId != null
                      ? aircraftService.aircrafts.firstWhere(
                          (a) => a.id == _selectedAircraftId,
                          orElse: () => aircraftService.aircrafts.first,
                        )
                      : null;
                  
                  // If we have a trip loaded, show all waypoints from all plans
                  debugPrint('Current trip plans count: ${flightPlanService.currentTripPlans.length}');
                  debugPrint('Current trip: ${flightPlanService.currentTrip?.name}');
                  if (flightPlanService.currentTrip != null && flightPlanService.currentTripPlans.isNotEmpty) {
                    debugPrint('Showing waypoint tables for trip with ${flightPlanService.currentTripPlans.length} legs');
                    // Create multiple waypoint tables for each leg
                    return Column(
                      children: [
                        for (int i = 0; i < flightPlanService.currentTripPlans.length; i++)
                          if (flightPlanService.currentTripPlans[i].waypoints.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Leg header with delete button
                                  Container(
                                    padding: const EdgeInsets.only(left: 12, right: 4, top: 4, bottom: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0x1A448AFF),
                                      borderRadius: AppTheme.smallRadius,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'Leg ${i + 1}: ${flightPlanService.currentTripPlans[i].name}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white.withValues(alpha: 0.9),
                                            ),
                                          ),
                                        ),
                                        // Delete leg button - only show if more than one leg
                                        if (flightPlanService.currentTripPlans.length > 1)
                                          IconButton(
                                            icon: Icon(
                                              Icons.delete_outline,
                                              size: 16,
                                              color: Colors.red.withValues(alpha: 0.7),
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 24,
                                              minHeight: 24,
                                            ),
                                            onPressed: () => _showDeleteLegConfirmation(
                                              context,
                                              flightPlanService,
                                              i,
                                              flightPlanService.currentTripPlans[i].name,
                                            ),
                                            tooltip: 'Delete this leg',
                                          ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Waypoint table for this leg
                                  WaypointTableWidget(
                                    flightPlan: flightPlanService.currentTripPlans[i],
                                    selectedAircraft: selectedAircraft,
                                    selectedWaypointIndex: flightPlanService.currentTripPlans[i] == flightPlan 
                                        ? _selectedWaypointIndex 
                                        : -1,
                                    isExpanded: _isWaypointTableExpanded,
                                    onExpandedChanged: (expanded) {
                                      setState(() {
                                        _isWaypointTableExpanded = expanded;
                                      });
                                      _saveWaypointTableState(expanded);
                                    },
                                    onWaypointSelected: (index) {
                                      // Only allow selection for the current flight plan
                                      if (flightPlanService.currentTripPlans[i] == flightPlan) {
                                        setState(() {
                                          _selectedWaypointIndex = index;
                                        });
                                        // Focus map on selected waypoint
                                        widget.onWaypointFocus?.call(index);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                      ],
                    );
                  } else if (flightPlan != null && flightPlan.waypoints.isNotEmpty) {
                    debugPrint('Showing single waypoint table for flight plan');
                    // Single flight plan
                    return WaypointTableWidget(
                      flightPlan: flightPlan,
                      selectedAircraft: selectedAircraft,
                      selectedWaypointIndex: _selectedWaypointIndex,
                      isExpanded: _isWaypointTableExpanded,
                      onExpandedChanged: (expanded) {
                        setState(() {
                          _isWaypointTableExpanded = expanded;
                        });
                        _saveWaypointTableState(expanded);
                      },
                      onWaypointSelected: (index) {
                        setState(() {
                          _selectedWaypointIndex = index;
                        });
                        // Focus map on selected waypoint
                        widget.onWaypointFocus?.call(index);
                      },
                    );
                  } else {
                    return const SizedBox.shrink();
                  }
                },
              ),
            ),
            
          // Add to Trip button - shown when there are waypoints
          if (flightPlan != null || flightPlanService.currentTripPlans.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 12),
              child: Center(
                child: ElevatedButton.icon(
                  onPressed: () => _openFlightPlansForTrip(context, flightPlanService),
                  icon: const Icon(Icons.add_road, size: 20),
                  label: Text(l10n.addFlightPlanToTrip),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4CAF50),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.mediumRadius,
                    ),
                  ),
                ),
              ),
            ),
            
          // Clear flight plan button - placed below waypoint table
          if (flightPlan != null || flightPlanService.currentTrip != null)
            Container(
              margin: const EdgeInsets.only(top: 16),
              child: ElevatedButton.icon(
                onPressed: () => _showClearConfirmationDialog(context, flightPlanService),
                icon: const Icon(Icons.delete_outline, size: 20),
                label: Text(l10n.clearFlightPlan),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.8),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppTheme.mediumRadius,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAltitudeProfileTab(
    BuildContext context,
    FlightPlanService flightPlanService,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final settings = Provider.of<SettingsService>(context);
    final profile = flightPlanService.currentAirspaceProfile;
    final isAnalyzing = flightPlanService.isAnalyzingProfile;

    if (isAnalyzing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              l10n.analyzingAirspaceProfile,
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
      );
    }

    if (profile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.terrain, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              l10n.noAirspaceProfileAvailable,
              style: TextStyle(color: Colors.grey[400], fontSize: 16),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                flightPlanService.analyzeCurrentFlightPath();
              },
              icon: const Icon(Icons.refresh, size: 20),
              label: Text(l10n.analyzeFlightPath),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.withValues(alpha: 0.8),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // Use the full available height without scrolling
    return AltitudeProfileChart(
      airspaceProfile: profile,
      showMetric: settings.altitudeUnit == 'meters',
            onPointSelected: (point, airspaces) {
              // Handle point selection and notify map
              debugPrint('Selected point at ${point.distanceNm} nm, ${point.altitudeFt} ft');
              if (airspaces.isNotEmpty) {
                debugPrint('Airspaces at point: ${airspaces.map((a) => a.airspace.name).join(', ')}');
              }
              // Pass the selected point to the map with altitude and distance info
              widget.onMapFocus?.call(
                point.position,
                altitude: point.altitudeFt,
                distance: point.distanceNm,
              );
            },
            onMapFocus: (position) {
              // Simple map focus without selection
              widget.onMapFocus?.call(position);
            },
            onAirspaceSelected: (airspace) {
              // Handle airspace selection from chart
              debugPrint('Selected airspace: ${airspace.name}');
              // TODO: Highlight airspace on map
            },
          );
  }
  
  // Open flight plans screen to load a flight plan
  void _openFlightPlansScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FlightPlansScreen(),
      ),
    );
  }

  // Open flight plans screen to add another flight plan to the trip
  void _openFlightPlansForTrip(BuildContext context, FlightPlanService flightPlanService) {
    // Save current flight plan first if it has waypoints
    if (flightPlanService.currentFlightPlan != null && 
        flightPlanService.currentFlightPlan!.waypoints.isNotEmpty) {
      flightPlanService.saveCurrentFlightPlan();
    }
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const FlightPlansScreen(),
      ),
    ).then((_) {
      // When returning, check if a new flight plan was loaded
      // If so, we could create a trip from both plans
      // This is handled by the FlightPlansScreen when user selects a plan
    });
  }

  // Show confirmation dialog before clearing flight plan
  void _showDeleteLegConfirmation(
    BuildContext context,
    FlightPlanService flightPlanService,
    int legIndex,
    String legName,
  ) {
    final l10n = AppLocalizations.of(context)!;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xE6000000),
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.largeRadius,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
          title: Text(
            l10n.deleteLeg,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            l10n.deleteLegConfirmation(legName),
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                l10n.cancel,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                flightPlanService.removeLegFromTrip(legIndex);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
  }

  void _showClearConfirmationDialog(BuildContext context, FlightPlanService flightPlanService) {
    final l10n = AppLocalizations.of(context)!;
    final planName = flightPlanService.currentTrip != null 
        ? flightPlanService.currentTrip!.name
        : (flightPlanService.currentFlightPlan?.name ?? 'flight plan');
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color(0xE6000000),
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.largeRadius,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
          title: Text(
            l10n.clearFlightPlan,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            'Are you sure you want to clear "$planName" from the map?',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.9)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                l10n.cancel,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                flightPlanService.clearFlightPlan();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(l10n.clear),
            ),
          ],
        );
      },
    );
  }

  Widget _buildAircraftSection(FlightPlanService flightPlanService) {
    final l10n = AppLocalizations.of(context)!;
    
    return Consumer<AircraftSettingsService>(
      builder: (context, aircraftService, child) {
        final aircrafts = aircraftService.aircrafts;

        // If no aircraft defined, only show cruise speed input
        if (aircrafts.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0x1A448AFF),
              border: Border.all(color: const Color(0x33448AFF)),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.speed, size: 16, color: Color(0xFF448AFF)),
                const SizedBox(width: 4),
                Text(
                  l10n.cruiseSpeedLabel,
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _cruiseSpeedController,
                    enabled: _isEditMode,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '120',
                      hintStyle: const TextStyle(color: Colors.white30),
                      suffix: Text(
                        l10n.ktsUnit,
                        style: const TextStyle(fontSize: 10, color: Colors.white70),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      filled: true,
                      fillColor: const Color(0x1A448AFF),
                      border: OutlineInputBorder(
                        borderRadius: AppTheme.mediumRadius,
                        borderSide: const BorderSide(color: Color(0x33448AFF)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: AppTheme.mediumRadius,
                        borderSide: const BorderSide(color: Color(0x33448AFF)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: AppTheme.mediumRadius,
                        borderSide: const BorderSide(color: Color(0xFF448AFF)),
                      ),
                      disabledBorder: OutlineInputBorder(
                        borderRadius: AppTheme.mediumRadius,
                        borderSide: const BorderSide(color: Color(0x1A666666)),
                      ),
                    ),
                    onChanged: (value) => _onCruiseSpeedChanged(value, flightPlanService),
                  ),
                ),
              ],
            ),
          );
        }

        // Show full aircraft section when aircraft are available
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0x1A448AFF),
            border: Border.all(color: const Color(0x33448AFF)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              // Aircraft selection
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    const Icon(
                      Icons.airplanemode_active,
                      size: 16,
                      color: Color(0xFF448AFF),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      l10n.aircraftLabel,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedAircraftId,
                        isExpanded: true,
                        isDense: true,
                        hint: Text(
                          l10n.selectAircraftHint,
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                        dropdownColor: const Color(0xE6000000),
                        underline: const SizedBox(),
                        onChanged: (String? aircraftId) {
                          setState(() {
                            _selectedAircraftId = aircraftId;
                          });
                          if (aircraftId != null) {
                            _updateAircraft(
                              flightPlanService,
                              aircraftService,
                              aircraftId,
                            );
                          }
                        },
                        items: aircrafts.map((aircraft) {
                          final model = aircraftService.models.firstWhere(
                            (m) => m.id == aircraft.modelId,
                            orElse: () => aircraftService.models.first,
                          );
                          final manufacturer = aircraftService.manufacturers
                              .firstWhere(
                                (m) => m.id == model.manufacturerId,
                                orElse: () =>
                                    aircraftService.manufacturers.first,
                              );

                          return DropdownMenuItem<String>(
                            value: aircraft.id,
                            child: Text(
                              '${aircraft.registration} - ${manufacturer.name} ${model.name}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Cruise speed input
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    const Icon(Icons.speed, size: 16, color: Color(0xFF448AFF)),
                    const SizedBox(width: 4),
                    Text(
                      l10n.speedLabel,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: TextField(
                        controller: _cruiseSpeedController,
                        enabled: _isEditMode,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          hintText: '120',
                          hintStyle: const TextStyle(color: Colors.white30),
                          suffix: Text(
                            l10n.ktsUnit,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          ),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          filled: true,
                          fillColor: const Color(0x1A448AFF),
                          border: OutlineInputBorder(
                            borderRadius: AppTheme.mediumRadius,
                            borderSide: const BorderSide(
                              color: Color(0x33448AFF),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: AppTheme.mediumRadius,
                            borderSide: const BorderSide(
                              color: Color(0x33448AFF),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: AppTheme.mediumRadius,
                            borderSide: const BorderSide(
                              color: Color(0xFF448AFF),
                            ),
                          ),
                          disabledBorder: OutlineInputBorder(
                            borderRadius: AppTheme.mediumRadius,
                            borderSide: const BorderSide(
                              color: Color(0x1A666666),
                            ),
                          ),
                        ),
                        onChanged: (value) => _onCruiseSpeedChanged(value, flightPlanService),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _updateAircraft(
    FlightPlanService flightPlanService,
    AircraftSettingsService aircraftService,
    String aircraftId,
  ) {
    final aircraft = aircraftService.aircrafts.firstWhere(
      (a) => a.id == aircraftId,
      orElse: () => aircraftService.aircrafts.first,
    );

    final model = aircraftService.models.firstWhere(
      (m) => m.id == aircraft.modelId,
      orElse: () => aircraftService.models.first,
    );

    // Update flight plan with aircraft
    if (flightPlanService.currentFlightPlan != null) {
      flightPlanService.currentFlightPlan!.aircraftId = aircraftId;

      // Update cruise speed from aircraft/model if available
      double cruiseSpeed = aircraft.cruiseSpeed > 0
          ? aircraft.cruiseSpeed.toDouble()
          : model.typicalCruiseSpeed.toDouble();
      if (cruiseSpeed > 0) {
        _cruiseSpeedController.text = cruiseSpeed.toStringAsFixed(0);
        flightPlanService.updateCruiseSpeed(cruiseSpeed);
      }

      // Checklist selection removed - user can access checklists manually if needed

      // Autosave
      _autosaveFlightPlan(flightPlanService);
    }
  }

  void _autosaveFlightPlan(FlightPlanService flightPlanService) {
    // Cancel any existing timer
    _autosaveTimer?.cancel();

    // Set a new timer to save after 1 second of inactivity
    _autosaveTimer = Timer(const Duration(seconds: 1), () {
      if (flightPlanService.currentFlightPlan != null) {
        flightPlanService.saveCurrentFlightPlan();
      }
    });
  }

  void _onCruiseSpeedChanged(String value, FlightPlanService flightPlanService) {
    // Cancel any existing debouncer
    _cruiseSpeedDebouncer?.cancel();
    
    // Only update after user stops typing for 500ms
    _cruiseSpeedDebouncer = Timer(const Duration(milliseconds: 500), () {
      final speed = double.tryParse(value);
      if (speed != null && speed > 0) {
        flightPlanService.updateCruiseSpeed(speed);
        _autosaveFlightPlan(flightPlanService);
      }
    });
  }

  Future<void> _loadWaypointTableState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isExpanded = prefs.getBool(_waypointTableExpandedKey) ?? false;
      if (mounted) {
        setState(() {
          _isWaypointTableExpanded = isExpanded;
        });
      }
    } catch (e) {
      // Keep default state if loading fails
    }
  }

  Future<void> _saveWaypointTableState(bool isExpanded) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_waypointTableExpandedKey, isExpanded);
    } catch (e) {
      // Ignore save errors
    }
  }

}
