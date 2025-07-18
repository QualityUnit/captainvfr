import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../services/flight_plan_service.dart';
import '../services/flight_service.dart';
import '../services/aircraft_settings_service.dart';
import '../services/settings_service.dart';
import '../models/flight.dart';
import '../services/barometer_service.dart';
import 'themed_dialog.dart';
import 'compass_widget.dart';

// Custom icons for the flight dashboard
class FlightIcons {
  // Compass icon that can be rotated
  static Widget compass(double? heading, {double size = 24}) {
    return Transform.rotate(
      angle: (heading ?? 0) * (pi / 180) * -1,
      child: Icon(Icons.explore, size: size, color: Colors.blueAccent),
    );
  }

  // Altitude icon
  static const IconData altitude = Icons.terrain;

  // Speed icon
  static const IconData speed = Icons.speed;

  // Time icon
  static const IconData time = Icons.timer;

  // Distance icon
  static const IconData distance = Icons.terrain;

  // Vertical speed icon
  static const IconData verticalSpeed = Icons.linear_scale;

  // Baro icon
  static const IconData baro = Icons.speed;
}

class FlightDashboard extends StatefulWidget {
  final bool? isExpanded;
  final Function(bool)? onExpandedChanged;

  const FlightDashboard({super.key, this.isExpanded, this.onExpandedChanged});

  @override
  State<FlightDashboard> createState() => _FlightDashboardState();
}

class _FlightDashboardState extends State<FlightDashboard> {
  late bool _isExpanded;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded ?? true;

    // Auto-select aircraft after frame is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoSelectAircraft();
    });
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
          // Since Flight model doesn't have aircraftId, we can't implement this yet
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

  void _toggleExpanded(bool expanded) {
    setState(() {
      _isExpanded = expanded;
    });
    widget.onExpandedChanged?.call(expanded);
  }

  @override
  Widget build(BuildContext context) {
    final flightService = Provider.of<FlightService>(context);
    final barometerService = Provider.of<BarometerService>(context);

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
        minHeight: _isExpanded ? 160 : 60,
        maxHeight: _isExpanded ? 260 : 60,
        minWidth: 300,
        maxWidth: maxWidth,
      ),
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(_isExpanded ? 12.0 : 8.0),
          decoration: BoxDecoration(
            color: const Color(0xB3000000), // Black with 0.7 opacity
            borderRadius: BorderRadius.circular(12.0),
            border: Border.all(
              color: const Color(0x7F448AFF),
              width: 1.0,
            ), // Blue accent with 0.5 opacity
          ),
          child: _isExpanded
              ? _buildExpandedView(context, flightService, barometerService)
              : _buildCollapsedView(context, flightService, barometerService),
        ),
      ),
    );
  }

  Widget _buildExpandedView(
    BuildContext context,
    FlightService flightService,
    BarometerService barometerService,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with fixed height
        SizedBox(height: 40, child: _buildHeader(context, flightService)),
        const SizedBox(height: 8),
        // Main indicators with fixed height
        SizedBox(
          height: 90,
          child: _buildMainIndicators(context, flightService, barometerService),
        ),
        const SizedBox(height: 8),
        // Secondary indicators
        _buildSecondaryIndicators(context, flightService, barometerService),
        const SizedBox(height: 8),
        // Additional indicators
        _buildAdditionalIndicators(context, flightService, barometerService),
      ],
    );
  }

  Widget _buildCollapsedView(
    BuildContext context,
    FlightService flightService,
    BarometerService barometerService,
  ) {
    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        final isMetric = settings.units == 'metric';
        final altitude = flightService.barometricAltitude ?? 0;
        final displayAltitude = isMetric
            ? altitude
            : altitude * 3.28084; // Convert m to ft
        final altitudeUnit = isMetric ? 'm' : 'ft';

        return LayoutBuilder(
          builder: (context, constraints) {
            // Calculate dynamic sizes based on available width
            final availableWidth = constraints.maxWidth;

            // Base sizes that scale with available width
            double iconSize = 12.0;
            double fontSize = 12.0;
            double buttonSize = 28.0;
            double spacing = 2.0;

            if (availableWidth > 400) {
              iconSize = 14.0;
              fontSize = 13.0;
              buttonSize = 32.0;
              spacing = 4.0;
            } else if (availableWidth < 300) {
              iconSize = 10.0;
              fontSize = 11.0;
              buttonSize = 24.0;
              spacing = 1.0;
            }

            // Convert speed based on units
            final speedMs = flightService.currentSpeed;
            final displaySpeed = isMetric
                ? speedMs *
                      3.6 // Convert m/s to km/h
                : speedMs * 1.94384; // Convert m/s to knots
            final speedUnit = isMetric ? 'km/h' : 'kt';

            return Row(
              children: [
                // Expand button
                SizedBox(
                  width: buttonSize,
                  height: buttonSize,
                  child: IconButton(
                    icon: Icon(
                      Icons.expand_more,
                      color: const Color(0xFF448AFF),
                      size: iconSize + 4,
                    ),
                    onPressed: () => _toggleExpanded(true),
                    padding: EdgeInsets.zero,
                  ),
                ),
                SizedBox(width: spacing * 2),
                // Speed
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FlightIcons.speed,
                        color: Colors.blueAccent,
                        size: iconSize,
                      ),
                      SizedBox(width: spacing),
                      Flexible(
                        child: Text(
                          '${displaySpeed.toStringAsFixed(0)} $speedUnit',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Altitude
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FlightIcons.altitude,
                        color: Colors.blueAccent,
                        size: iconSize,
                      ),
                      SizedBox(width: spacing),
                      Flexible(
                        child: Text(
                          '${displayAltitude.toStringAsFixed(0)} $altitudeUnit',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Heading
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.navigation,
                        color: Colors.blueAccent,
                        size: iconSize,
                      ),
                      SizedBox(width: spacing),
                      Flexible(
                        child: Text(
                          '${(flightService.currentHeading ?? 0).toStringAsFixed(0)}°',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                // Tracking button
                SizedBox(
                  width: buttonSize,
                  height: buttonSize,
                  child: IconButton(
                    icon: Icon(
                      flightService.isTracking ? Icons.stop : Icons.play_arrow,
                      color: flightService.isTracking
                          ? Colors.red
                          : Colors.green,
                      size: iconSize + 4,
                    ),
                    onPressed: () {
                      if (flightService.isTracking) {
                        flightService.stopTracking();
                      } else {
                        flightService.startTracking();
                      }
                    },
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, FlightService flightService) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left side: Collapse button and title
        Expanded(
          child: Row(
            children: [
              // Collapse button
              IconButton(
                icon: const Icon(
                  Icons.expand_less,
                  color: Color(0xFF448AFF),
                  size: 20,
                ),
                onPressed: () => _toggleExpanded(false),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
              const SizedBox(width: 8),
              // Title aligned to left
              const Text(
                'FLIGHT',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        // Right side: Aircraft selector and tracking button
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Compact aircraft selection
            _buildCompactAircraftSelector(context, flightService),
            const SizedBox(width: 8),
            // Larger tracking button for better visibility
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                icon: Icon(
                  flightService.isTracking ? Icons.stop : Icons.play_arrow,
                  color: flightService.isTracking ? Colors.red : Colors.green,
                  size: 24,
                ),
                onPressed: () {
                  if (flightService.isTracking) {
                    flightService.stopTracking();
                  } else {
                    flightService.startTracking();
                  }
                },
                tooltip: flightService.isTracking
                    ? 'Stop Tracking'
                    : 'Start Tracking',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompactAircraftSelector(
    BuildContext context,
    FlightService flightService,
  ) {
    return Consumer<AircraftSettingsService>(
      builder: (context, aircraftService, child) {
        // Hide aircraft selector if no aircraft are defined
        if (aircraftService.aircrafts.isEmpty) {
          return const SizedBox.shrink();
        }

        final selectedAircraft = aircraftService.selectedAircraft;

        return InkWell(
          onTap: () => _showAircraftSelectionDialog(
            context,
            aircraftService,
            flightService,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: Colors.blueAccent.withValues(alpha: 0.5),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.flight, color: Colors.blueAccent, size: 12),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    selectedAircraft?.name ?? 'Select',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(
                  Icons.arrow_drop_down,
                  color: Colors.blueAccent,
                  size: 14,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAircraftSelectionDialog(
    BuildContext context,
    AircraftSettingsService aircraftService,
    FlightService flightService,
  ) {
    ThemedDialog.show(
      context: context,
      title: 'Select Aircraft',
      content: SizedBox(
        width: double.maxFinite,
        child: aircraftService.aircrafts.isEmpty
            ? const Text(
                'No aircraft available. Please add an aircraft first.',
                style: TextStyle(color: Colors.white70),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: aircraftService.aircrafts.length,
                itemBuilder: (context, index) {
                  final aircraft = aircraftService.aircrafts[index];
                  final isSelected =
                      aircraft.id == aircraftService.selectedAircraft?.id;

                  return Container(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0x1A448AFF)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0x7F448AFF)
                            : Colors.transparent,
                      ),
                    ),
                    child: ListTile(
                      leading: Icon(
                        Icons.flight,
                        color: isSelected
                            ? const Color(0xFF448AFF)
                            : Colors.white54,
                      ),
                      title: Text(
                        aircraft.name,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        '${aircraft.manufacturer} ${aircraft.model}',
                        style: const TextStyle(color: Colors.white54),
                      ),
                      trailing: isSelected
                          ? const Icon(
                              Icons.check_circle,
                              color: Color(0xFF448AFF),
                            )
                          : null,
                      onTap: () {
                        // Select the aircraft by ID
                        aircraftService.aircraftService.selectAircraft(
                          aircraft.id,
                        );
                        // Set aircraft in flight service
                        flightService.setAircraft(aircraft);
                        Navigator.of(context).pop();
                      },
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  Widget _buildMainIndicators(
    BuildContext context,
    FlightService flightService,
    BarometerService barometerService,
  ) {
    final flightPlanService = Provider.of<FlightPlanService>(context);
    final currentFlightPlan = flightPlanService.currentFlightPlan;

    // Calculate target heading if flight plan is active
    double? targetHeading;
    if (currentFlightPlan != null && currentFlightPlan.waypoints.length >= 2) {
      // For now, just show heading from first to second waypoint
      // In a real implementation, we'd track the active segment
      final firstWaypoint = currentFlightPlan.waypoints[0];
      final secondWaypoint = currentFlightPlan.waypoints[1];

      // Calculate bearing between waypoints
      final distance = Distance();
      targetHeading = distance.bearing(
        LatLng(firstWaypoint.latitude, firstWaypoint.longitude),
        LatLng(secondWaypoint.latitude, secondWaypoint.longitude),
      );
      // Convert from [-180, 180] to [0, 360]
      if (targetHeading < 0) targetHeading += 360;
    }

    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        final isMetric = settings.units == 'metric';
        final altitude = flightService.barometricAltitude ?? 0;
        final displayAltitude = isMetric
            ? altitude
            : altitude * 3.28084; // Convert m to ft
        final altitudeUnit = isMetric ? 'm' : 'ft';

        // Convert speed based on units
        final speedMs = flightService.currentSpeed;
        final displaySpeed = isMetric
            ? speedMs *
                  3.6 // Convert m/s to km/h
            : speedMs * 1.94384; // Convert m/s to knots
        final speedUnit = isMetric ? 'km/h' : 'kt';

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: _buildIndicator(
                'ALT',
                displayAltitude.toStringAsFixed(0),
                altitudeUnit,
                FlightIcons.altitude,
              ),
            ),
            Expanded(
              child: _buildIndicator(
                'SPEED',
                displaySpeed.toStringAsFixed(0),
                speedUnit,
                FlightIcons.speed,
              ),
            ),
            Expanded(
              child: Center(
                child: CompassWidget(
                  heading: flightService.currentHeading ?? 0,
                  targetHeading: targetHeading,
                  size: 50,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSecondaryIndicators(
    BuildContext context,
    FlightService flightService,
    BarometerService barometerService,
  ) {
    final hasFlightPlan =
        Provider.of<FlightPlanService>(
          context,
          listen: false,
        ).currentFlightPlan !=
        null;

    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        final isMetric = settings.units == 'metric';
        final distanceMeters = flightService.totalDistance;
        final displayDistance = isMetric
            ? distanceMeters /
                  1000 // Convert to km
            : distanceMeters * 0.000621371; // Convert to miles
        final distanceUnit = isMetric ? 'km' : 'mi';

        // Convert vertical speed based on units
        final verticalSpeedFpm = flightService.verticalSpeed;
        final displayVerticalSpeed = isMetric
            ? verticalSpeedFpm *
                  0.00508 // Convert fpm to m/s
            : verticalSpeedFpm;
        final verticalSpeedUnit = isMetric ? 'm/s' : 'fpm';
        final verticalSpeedStr = isMetric
            ? displayVerticalSpeed.toStringAsFixed(1)
            : displayVerticalSpeed.toStringAsFixed(0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: _buildSmallIndicator(
                'TIME',
                flightService.formattedFlightTime,
                FlightIcons.time,
              ),
            ),
            Expanded(
              child: _buildSmallIndicator(
                'DIST',
                '${displayDistance.toStringAsFixed(1)}$distanceUnit',
                FlightIcons.distance,
              ),
            ),
            Expanded(
              child: _buildSmallIndicator(
                'V/S',
                '$verticalSpeedStr $verticalSpeedUnit',
                FlightIcons.verticalSpeed,
              ),
            ),
            Expanded(
              child: _buildSmallIndicator(
                'G',
                '${flightService.currentGForce.toStringAsFixed(2)}g',
                Icons.speed,
              ),
            ),
            if (hasFlightPlan)
              Expanded(
                child: _buildSmallIndicator(
                  'NEXT',
                  _buildNextWaypointInfo(flightService, context),
                  Icons.flag,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAdditionalIndicators(
    BuildContext context,
    FlightService flightService,
    BarometerService barometerService,
  ) {
    return Consumer2<SettingsService, AircraftSettingsService>(
      builder: (context, settings, aircraftService, child) {
        // Convert pressure based on user preference
        final pressureValue = flightService.currentPressure;
        final displayPressure = settings.pressureUnit == 'inHg'
            ? pressureValue *
                  0.02953 // Convert hPa to inHg
            : pressureValue;
        final pressureStr = settings.pressureUnit == 'inHg'
            ? displayPressure.toStringAsFixed(2)
            : displayPressure.toStringAsFixed(0);

        // Check if aircraft is selected
        final hasAircraft = aircraftService.selectedAircraft != null;

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Expanded(
              child: _buildSmallIndicator(
                'PRESS',
                '$pressureStr ${settings.pressureUnit}',
                Icons.compress,
              ),
            ),
            if (hasAircraft)
              Expanded(
                child: _buildSmallIndicator(
                  'FUEL',
                  settings.units == 'metric'
                      ? '${(flightService.fuelUsed * 3.78541).toStringAsFixed(1)} L'
                      : '${flightService.fuelUsed.toStringAsFixed(1)} gal',
                  Icons.local_gas_station,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildIndicator(
    String label,
    String value,
    String unit,
    IconData icon,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Dynamic sizing based on available width
        final availableWidth = constraints.maxWidth;
        final iconSize = availableWidth < 80
            ? 12.0
            : (availableWidth < 120 ? 14.0 : 16.0);
        final valueFontSize = availableWidth < 80
            ? 16.0
            : (availableWidth < 120 ? 18.0 : 20.0);
        final unitFontSize = availableWidth < 80
            ? 10.0
            : (availableWidth < 120 ? 11.0 : 12.0);
        final labelFontSize = availableWidth < 80
            ? 8.0
            : (availableWidth < 120 ? 9.0 : 10.0);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Icon(icon, color: Colors.blueAccent, size: iconSize),
                    const SizedBox(width: 2),
                    Flexible(
                      child: Text(
                        value,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: valueFontSize,
                          fontWeight: FontWeight.bold,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 1),
                    Text(
                      unit,
                      style: TextStyle(
                        color: Colors.blueAccent,
                        fontSize: unitFontSize,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: labelFontSize,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSmallIndicator(String label, String value, IconData icon) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Dynamic sizing for small indicators
        final availableWidth = constraints.maxWidth;
        final availableHeight = constraints.maxHeight;

        // Adjust sizes based on available space
        final iconSize = availableHeight < 32
            ? 10.0
            : (availableWidth < 60
                  ? 10.0
                  : (availableWidth < 80 ? 12.0 : 14.0));
        final valueFontSize = availableHeight < 32
            ? 9.0
            : (availableWidth < 60
                  ? 10.0
                  : (availableWidth < 80 ? 11.0 : 12.0));
        final labelFontSize = availableHeight < 32
            ? 7.0
            : (availableWidth < 60 ? 8.0 : 9.0);

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.blueAccent, size: iconSize),
                    const SizedBox(width: 1),
                    Flexible(
                      child: Text(
                        value,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: valueFontSize,
                          fontWeight: FontWeight.w500,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: labelFontSize,
                    letterSpacing: 0.2,
                  ),
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Compute distance/time to next waypoint if a plan is loaded
  String _buildNextWaypointInfo(
    FlightService flightService,
    BuildContext context,
  ) {
    final planSvc = Provider.of<FlightPlanService>(context, listen: false);
    final settingsSvc = Provider.of<SettingsService>(context, listen: false);
    final plan = planSvc.currentFlightPlan;
    // Check for all required conditions: plan exists, has waypoints, and flight path has data
    if (plan == null ||
        plan.waypoints.isEmpty ||
        flightService.flightPath.isEmpty) {
      return '--';
    }

    try {
      final currentPos = flightService.flightPath.last.toLatLng();
      final wp = plan.waypoints.first;
      final dest = LatLng(wp.latitude, wp.longitude);
      final meterDist = const Distance().as(LengthUnit.Meter, currentPos, dest);

      final isMetric = settingsSvc.units == 'metric';
      final displayDistance = isMetric
          ? meterDist /
                1000 // km
          : meterDist * 0.000621371; // miles
      final distanceUnit = isMetric ? 'km' : 'mi';

      final speedKmh = flightService.currentSpeed * 3.6;
      final etaMin = speedKmh > 0
          ? (displayDistance / (isMetric ? speedKmh : speedKmh * 0.621371)) * 60
          : 0;
      return '${displayDistance.toStringAsFixed(1)}$distanceUnit/${etaMin.toStringAsFixed(0)}min';
    } catch (e) {
      // Fallback in case of any unexpected errors
      return '--';
    }
  }
}
