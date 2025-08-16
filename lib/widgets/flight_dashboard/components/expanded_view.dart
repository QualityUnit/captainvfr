import 'package:flutter/material.dart';
import '../../../services/flight_service.dart';
import '../../../services/barometer_service.dart';
import '../constants/flight_panel_constants.dart';
import 'main_indicators.dart';
import 'secondary_indicators.dart';
import 'additional_indicators.dart';
import 'aircraft_selector.dart';

/// Expanded view of the flight dashboard showing all flight information
class ExpandedView extends StatelessWidget {
  final VoidCallback onCollapse;
  final FlightService flightService;
  final BarometerService barometerService;

  const ExpandedView({
    super.key,
    required this.onCollapse,
    required this.flightService,
    required this.barometerService,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(FlightPanelConstants.defaultPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main indicators with fixed height (increased for larger display)
          SizedBox(
            height: FlightPanelConstants.mainIndicatorsHeight,
            child: MainIndicators(
              flightService: flightService,
              barometerService: barometerService,
            ),
          ),
          SizedBox(height: FlightPanelConstants.mediumSpacing),
          // Secondary indicators
          SecondaryIndicators(
            flightService: flightService,
            barometerService: barometerService,
          ),
          SizedBox(height: FlightPanelConstants.mediumSpacing),
          // Additional indicators
          AdditionalIndicators(
            flightService: flightService,
            barometerService: barometerService,
          ),
          SizedBox(height: FlightPanelConstants.largeSpacing),
          // Aircraft selector at the bottom
          Center(
            child: AircraftSelector(flightService: flightService),
          ),
        ],
      ),
    );
  }
}