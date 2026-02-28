import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import '../services/airport_service.dart';
import '../services/flight_service.dart';
import '../services/display_mode_service.dart';
import '../models/airport.dart';
import '../l10n/app_localizations.dart';

/// Emergency assistance panel for in-flight emergencies
/// Provides quick access to nearest airports, emergency frequencies, and position
class EmergencyPanel extends StatefulWidget {
  final VoidCallback onClose;
  
  const EmergencyPanel({
    super.key,
    required this.onClose,
  });
  
  @override
  State<EmergencyPanel> createState() => _EmergencyPanelState();
}

class _EmergencyPanelState extends State<EmergencyPanel> {
  List<Airport> _nearestAirports = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _findNearestAirports();
  }
  
  Future<void> _findNearestAirports() async {
    final flightService = Provider.of<FlightService>(context, listen: false);
    final airportService = Provider.of<AirportService>(context, listen: false);
    
    // Get current position from flight path
    final flightPath = flightService.flightPath;
    if (flightPath.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    
    final lastPoint = flightPath.last;
    final currentPos = LatLng(lastPoint.latitude, lastPoint.longitude);
    
    try {
      // Calculate bounds for 50nm radius (approximately 0.83 degrees)
      const radiusDegrees = 0.83;
      final southWest = LatLng(
        currentPos.latitude - radiusDegrees,
        currentPos.longitude - radiusDegrees,
      );
      final northEast = LatLng(
        currentPos.latitude + radiusDegrees,
        currentPos.longitude + radiusDegrees,
      );
      
      // Get airports within bounds
      final airports = await airportService.getAirportsInBounds(
        southWest,
        northEast,
      );
      
      // Sort by distance
      airports.sort((a, b) {
        final distA = _calculateDistance(
          currentPos.latitude,
          currentPos.longitude,
          a.latitude,
          a.longitude,
        );
        final distB = _calculateDistance(
          currentPos.latitude,
          currentPos.longitude,
          b.latitude,
          b.longitude,
        );
        return distA.compareTo(distB);
      });
      
      setState(() {
        _nearestAirports = airports.take(5).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const distance = Distance();
    return distance.as(
      LengthUnit.Meter,
      LatLng(lat1, lon1),
      LatLng(lat2, lon2),
    ) / 1852.0; // Convert meters to nautical miles
  }
  
  int _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    const distance = Distance();
    return distance.bearing(
      LatLng(lat1, lon1),
      LatLng(lat2, lon2),
    ).round();
  }
  
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayMode = Provider.of<DisplayModeService>(context);
    final flightService = Provider.of<FlightService>(context);
    
    // Get current position from flight path
    final flightPath = flightService.flightPath;
    final position = flightPath.isNotEmpty ? flightPath.last : null;
    
    return Container(
      decoration: BoxDecoration(
        color: displayMode.getCriticalColor().withValues(alpha: 0.95),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'EMERGENCY',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 2,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: widget.onClose,
                  iconSize: 28,
                ),
              ],
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Emergency Frequency
                  _buildEmergencyFrequency(displayMode),
                  
                  const SizedBox(height: 16),
                  
                  // Current Position
                  if (position != null)
                    _buildCurrentPosition(position, displayMode),
                  
                  const SizedBox(height: 16),
                  
                  // Nearest Airports
                  _buildNearestAirports(position, displayMode, l10n),
                  
                  const SizedBox(height: 16),
                  
                  // Emergency Checklist
                  _buildEmergencyChecklist(displayMode, l10n),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEmergencyFrequency(DisplayModeService displayMode) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: Column(
        children: [
          const Text(
            'EMERGENCY FREQUENCY',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '121.5 MHz',
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'International Distress Frequency',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(const ClipboardData(text: '121.5'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Frequency copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('COPY FREQUENCY'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCurrentPosition(dynamic position, DisplayModeService displayMode) {
    final lat = position.latitude.toStringAsFixed(6);
    final lon = position.longitude.toStringAsFixed(6);
    final alt = position.altitude.toInt();
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CURRENT POSITION',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Latitude',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    Text(
                      '$lat°',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Longitude',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                    Text(
                      '$lon°',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Altitude: $alt ft MSL',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: '$lat, $lon'));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Position copied to clipboard'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy),
            label: const Text('COPY POSITION'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNearestAirports(
    dynamic position,
    DisplayModeService displayMode,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'NEAREST AIRPORTS',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.white),
            )
          else if (_nearestAirports.isEmpty)
            const Text(
              'No airports found within 50nm',
              style: TextStyle(color: Colors.white70),
            )
          else
            ..._nearestAirports.map((airport) {
              if (position == null) return const SizedBox.shrink();
              
              final distance = _calculateDistance(
                position.latitude,
                position.longitude,
                airport.latitude,
                airport.longitude,
              );
              final bearing = _calculateBearing(
                position.latitude,
                position.longitude,
                airport.latitude,
                airport.longitude,
              );
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              airport.icao,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              airport.name,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.white70,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '${distance.toStringAsFixed(1)} nm',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            '$bearing°',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
  
  Widget _buildEmergencyChecklist(DisplayModeService displayMode, AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'EMERGENCY CHECKLIST',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 12),
          _buildChecklistItem('1. Aviate - Maintain aircraft control'),
          _buildChecklistItem('2. Navigate - Fly to nearest suitable airport'),
          _buildChecklistItem('3. Communicate - Contact ATC on 121.5 MHz'),
          _buildChecklistItem('4. Squawk 7700 (Emergency transponder code)'),
          _buildChecklistItem('5. Prepare for emergency landing if needed'),
        ],
      ),
    );
  }
  
  Widget _buildChecklistItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Colors.white,
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
