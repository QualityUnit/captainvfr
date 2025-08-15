import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/flight_plan_service.dart';
import '../services/aircraft_settings_service.dart';
import '../services/settings_service.dart';
import 'waypoint_table_widget.dart';
import '../constants/app_theme.dart';
import '../l10n/app_localizations.dart';

class FlightPlanningPanel extends StatefulWidget {
  final bool? isExpanded;
  final Function(bool)? onExpandedChanged;
  final VoidCallback? onClose;
  final Function(int)? onWaypointFocus;
  final VoidCallback? onCenterFlightPlan;

  const FlightPlanningPanel({
    super.key,
    this.isExpanded,
    this.onExpandedChanged,
    this.onClose,
    this.onWaypointFocus,
    this.onCenterFlightPlan,
  });

  @override
  State<FlightPlanningPanel> createState() => _FlightPlanningPanelState();
}

class _FlightPlanningPanelState extends State<FlightPlanningPanel> {
  late bool _isExpanded;
  bool _isEditMode = false;
  final TextEditingController _cruiseSpeedController = TextEditingController();
  String? _selectedAircraftId;
  int? _selectedWaypointIndex;
  Timer? _autosaveTimer;
  Timer? _cruiseSpeedDebouncer;
  bool _isWaypointTableExpanded = false; // Track waypoint table expanded state - default collapsed
  
  static const String _waypointTableExpandedKey = 'waypoint_table_expanded';

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded ?? true;
    _loadWaypointTableState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final flightPlanService = context.read<FlightPlanService>();
      final aircraftService = context.read<AircraftSettingsService>();
      final flightPlan = flightPlanService.currentFlightPlan;

      // Sync edit mode with planning mode - only sync if planning mode is true
      // This prevents turning off planning mode when the panel is first opened
      if (flightPlanService.isPlanning &&
          flightPlanService.isPlanning != _isEditMode) {
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
    super.dispose();
  }

  void _toggleExpanded(bool expanded) {
    setState(() {
      _isExpanded = expanded;
    });
    widget.onExpandedChanged?.call(expanded);
  }

  @override
  Widget build(BuildContext context) {
    final flightPlanService = Provider.of<FlightPlanService>(context);

    // Get screen dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final isPhone = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;

    // Responsive margins and width
    final horizontalMargin = isPhone ? 8.0 : 16.0;
    final maxWidth = isPhone ? double.infinity : (isTablet ? 600.0 : 800.0);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: horizontalMargin,
        vertical: 16.0,
      ),
      constraints: BoxConstraints(
        minHeight: _isExpanded ? 200 : 60,
        maxHeight: _isExpanded ? 600 : 60,
        minWidth: 300,
        maxWidth: maxWidth,
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with edit mode toggle
              _buildHeader(context, flightPlanService),
              if (_isExpanded)
                Flexible(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 550, // Leave some space for header
                    ),
                    child: _buildExpandedView(context, flightPlanService),
                  ),
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

    // If collapsed, show minimal UI
    if (!_isExpanded) {
      return GestureDetector(
        onTap: () => _toggleExpanded(true),
        child: Container(
          height: double.infinity,
          width: double.infinity,
          color: Colors.transparent,
          child: Center(
            child: Icon(
              Icons.route,
              color: (flightPlan != null || flightPlanService.currentTrip != null)
                  ? const Color(0xFF448AFF)
                  : Colors.white70,
              size: 24,
            ),
          ),
        ),
      );
    }

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
          // Collapse button
          IconButton(
            icon: const Icon(
              Icons.chevron_left,
              color: Color(0xFF448AFF),
              size: 24,
            ),
            onPressed: () => _toggleExpanded(false),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
          ),

          // Flight planning icon
          Icon(
            isPlanning || _isEditMode ? Icons.flight_takeoff : Icons.map,
            color: isPlanning || _isEditMode
                ? const Color(0xFF448AFF)
                : Colors.white70,
            size: 20,
          ),
          const SizedBox(width: 8),

          // Title and stats
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
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: _isExpanded ? 14 : 13,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Center flight plan button
                    if ((flightPlan != null && flightPlan.waypoints.isNotEmpty) || 
                        flightPlanService.currentTripPlans.isNotEmpty)
                      IconButton(
                        icon: Icon(
                          Icons.center_focus_strong,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        onPressed: widget.onCenterFlightPlan,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        tooltip: l10n.centerOnFlightPlan,
                      ),
                    // Clear flight plan button
                    if (flightPlan != null || flightPlanService.currentTrip != null)
                      IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: 18,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        onPressed: () {
                          // Clear the flight plan from the map
                          final flightPlanService = context.read<FlightPlanService>();
                          flightPlanService.clearFlightPlan();
                          // Close the panel if onClose is provided
                          widget.onClose?.call();
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(
                          minWidth: 28,
                          minHeight: 28,
                        ),
                        tooltip: l10n.clearFlightPlan,
                      ),
                  ],
                ),
                if (_isExpanded)
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

          // Edit mode toggle slider
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Text(
                  l10n.editMode,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(width: 8),
                Transform.scale(
                  scale: 0.8,
                  child: Switch(
                    value: _isEditMode,
                    onChanged: (value) {
                      setState(() {
                        _isEditMode = value;
                      });
                      if (value && !flightPlanService.isPlanning) {
                        flightPlanService.togglePlanningMode();
                      } else if (!value && flightPlanService.isPlanning) {
                        flightPlanService.togglePlanningMode();
                      }
                    },
                    activeColor: const Color(0xFF448AFF),
                    activeTrackColor: const Color(0x66448AFF),
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),

          // Close button
          if (widget.onClose != null)
            IconButton(
              icon: Icon(
                Icons.close,
                size: _isExpanded ? 20 : 18,
                color: Colors.white.withValues(alpha: 0.7),
              ),
              onPressed: widget.onClose,
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(
                minWidth: _isExpanded ? 32 : 28,
                minHeight: _isExpanded ? 32 : 28,
              ),
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
                                  // Leg header
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0x1A448AFF),
                                      borderRadius: AppTheme.smallRadius,
                                    ),
                                    child: Text(
                                      'Leg ${i + 1}: ${flightPlanService.currentTripPlans[i].name}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white.withValues(alpha: 0.9),
                                      ),
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
        ],
      ),
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
