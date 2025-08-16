import 'package:flutter/material.dart';
import '../../../services/flight_service.dart';
import '../../../screens/flight_detail_screen.dart';
import 'stop_tracking_dialog.dart';

/// Header component for the flight dashboard with tracking button
class DashboardHeader extends StatelessWidget {
  final FlightService flightService;

  const DashboardHeader({
    super.key,
    required this.flightService,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // Tracking button aligned to the right
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            border: Border.all(
              color: flightService.isTracking
                  ? Colors.red.withValues(alpha: 0.8)
                  : Colors.green.withValues(alpha: 0.8),
              width: 2.0,
            ),
            borderRadius: BorderRadius.circular(20),
            // Subtle shadow for depth
            boxShadow: [
              BoxShadow(
                color: (flightService.isTracking ? Colors.red : Colors.green)
                    .withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () async {
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
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}