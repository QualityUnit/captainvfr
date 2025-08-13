import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'dart:math' as math;
import '../models/airport.dart';
import '../models/runway.dart';
import 'unified_runway_painter.dart';
import '../utils/geo_constants.dart';

class AirportMarker extends StatelessWidget {
  final Airport airport;
  final List<Runway>? runways;
  final VoidCallback? onTap;
  final double size;
  final bool showLabel;
  final bool isSelected;
  final double mapZoom;
  final String? distanceUnit;

  const AirportMarker({
    super.key,
    required this.airport,
    this.runways,
    this.onTap,
    this.size = 24.0,
    this.showLabel = true,
    this.isSelected = false,
    this.mapZoom = 10,
    this.distanceUnit,
  });

  @override
  Widget build(BuildContext context) {
    final icon = _getAirportIcon(airport.type);
    final color = _getAirportColor(airport.type);
    final borderColor = isSelected ? Colors.amber : color;
    // Adjust border width based on zoom level - thinner at lower zoom levels
    final borderWidth = isSelected ? 1.5 : 1.0;


    // The visual size of the marker based on zoom
    // Size hierarchy: large_airport = 100%, medium_airport = 75%, small_airport = 50%
    double sizeMultiplier = 1.0;
    switch (airport.type) {
      case 'large_airport':
        sizeMultiplier = 1.0;
        break;
      case 'medium_airport':
        sizeMultiplier = 0.75;
        break;
      case 'small_airport':
      case 'heliport':
      case 'seaplane_base':
      case 'balloonport':
        sizeMultiplier = 0.5;
        break;
      default:
        sizeMultiplier = 0.6;
    }
    
    // Slightly reduce size for airports without ICAO codes (they use abbreviated names)
    if (airport.icao.isEmpty) {
      sizeMultiplier *= 0.9;
    }
    
    final double baseSize = size * sizeMultiplier;
    final double visualSize = math.min(30.0, math.max(10.0, baseSize));

    // Calculate runway visualization size based on actual runway dimensions
    double runwayVisualizationSize = 0.0;
    if (mapZoom >= GeoConstants.minZoomForRunways) {
      // Calculate meters per pixel at this zoom and latitude
      final double metersPerPixel = GeoConstants.metersPerPixel(airport.position.latitude, mapZoom);
      
      // Find the longest runway
      double maxLengthM = 0;
      if (runways != null && runways!.isNotEmpty) {
        for (final runway in runways!) {
          final lengthM = runway.lengthFt * GeoConstants.metersPerFoot; // Convert feet to meters
          if (lengthM > maxLengthM) maxLengthM = lengthM;
        }
      } else if (airport.openAIPRunways.isNotEmpty) {
        // For OpenAIP runways
        for (final runway in airport.openAIPRunways) {
          final lengthM = runway.lengthM?.toDouble();
          if (lengthM != null && lengthM > maxLengthM) maxLengthM = lengthM;
        }
      }
      
      // Set size based on longest runway
      if (maxLengthM > 0 && metersPerPixel > 0) {
        // Calculate pixel size for runway visualization
        final calculatedSize = (maxLengthM / metersPerPixel);
        
        // Ensure the size is valid (not NaN or infinite)
        if (calculatedSize.isFinite && calculatedSize > 0) {
          // Limit runway size at lower zoom levels to prevent oversized visualizations
          runwayVisualizationSize = calculatedSize;
        } else {
          runwayVisualizationSize = visualSize * 2.5; // Default size
        }
      } else {
        runwayVisualizationSize = visualSize * 2.5; // Default size
      }
    }

    // Determine if label should be shown based on zoom
    // Show labels for all airports
    final shouldShowLabel = showLabel;
    final fontSize = 9.0;
    
    // Get label text: ICAO if available, otherwise first 6 letters of name
    final labelText = airport.icao.isNotEmpty 
        ? airport.icao 
        : (airport.name.length > 6 
            ? airport.name.substring(0, 6).toUpperCase() 
            : airport.name.toUpperCase());

    return GestureDetector(
      onTap: () {
        onTap?.call();
      },
      child: FittedBox(
        fit: BoxFit.contain,
        child: IntrinsicHeight(
          child: IntrinsicWidth(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              // Stack for marker and runway visualization
              Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                // Runway visualization (behind the marker)
                if (mapZoom >= GeoConstants.minZoomForRunways && runwayVisualizationSize > 0)
                  if (runways != null && runways!.isNotEmpty)
                    UnifiedRunwayVisualization(
                      runways: runways!,
                      airportIdent: airport.icao.isNotEmpty ? airport.icao : airport.name,
                      zoom: mapZoom,
                      size: runwayVisualizationSize,
                      runwayColor: isSelected ? Colors.amber : Colors.black87,
                      latitude: airport.position.latitude,
                      longitude: airport.position.longitude,
                      distanceUnit: distanceUnit,
                    )
                  else if (airport.openAIPRunways.isNotEmpty)
                    UnifiedRunwayVisualization(
                      openAIPRunways: airport.openAIPRunways,
                      airportIdent: airport.icao.isNotEmpty ? airport.icao : airport.name,
                      zoom: mapZoom,
                      size: runwayVisualizationSize,
                      runwayColor: isSelected ? Colors.amber : Colors.black87,
                      latitude: airport.position.latitude,
                      longitude: airport.position.longitude,
                      distanceUnit: distanceUnit,
                    ),
                
                // Main marker
                Container(
                  width: visualSize,
                  height: visualSize,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.amber.withValues(alpha: 0.2)
                        : Colors.white.withValues(alpha: 0.9),
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: borderWidth),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0x33000000),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: airport.type == 'heliport' 
                        ? Center(
                            child: Container(
                              width: visualSize * 0.6,
                              height: visualSize * 0.6,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  'H',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: visualSize * 0.3,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : airport.type == 'balloonport'
                        ? Center(
                            child: Icon(Icons.air, size: visualSize * 0.5, color: color),
                          )
                        : Icon(icon, size: visualSize * 0.6, color: color),
                ),
              ],
            ),
            // Show label when zoomed in enough
            if (shouldShowLabel)
              Container(
                margin: const EdgeInsets.only(top: 2),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(4),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  labelText,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Get appropriate icon based on airport type
  IconData _getAirportIcon(String type) {
    switch (type) {
      case 'heliport':
        return Icons.circle; // Circle represents helipad landing area
      case 'balloonport':
        return Icons.air_outlined; // Hot air balloon icon for balloonports
      case 'seaplane_base':
        return Icons.water; // Water icon for seaplane bases
      case 'closed':
        return Icons.block; // Block icon for closed airports
      case 'large_airport':
        return Icons.flight; // Large plane icon for major airports
      case 'medium_airport':
        return Icons.flight_takeoff; // Taking off plane for medium airports
      case 'small_airport':
        return Icons.flight_land; // Landing plane for small airports
      default:
        return Icons.local_airport; // Generic airport icon
    }
  }

  // Get color based on flight category or airport type
  Color _getAirportColor(String type) {
    // If we have weather data, use the flight category color
    final category = airport.flightCategory;
    if (category != null) {
      switch (category) {
        case 'VFR':
          return Colors.green;
        case 'MVFR':
          return Colors.blue;
        case 'IFR':
          return Colors.red;
        case 'LIFR':
          return Colors.purple;
        default:
          break;
      }
      return Colors.orange;
    }

    // Fall back to airport type if no weather data
    switch (type) {
      case 'large_airport':
        return Colors.blue[700]!;
      case 'medium_airport':
        return Colors.green[600]!;
      case 'heliport':
        return Colors.purple[600]!;
      case 'seaplane_base':
        return Colors.cyan[600]!;
      case 'small_airport':
        return Colors.orange[600]!;
      case 'closed':
        return Colors.red[800]!;  // Dark red for closed airports
      case 'balloonport':
        return Colors.pink[400]!;
      default:
        return Colors.orange[600]!;  // Default to orange for better visibility
    }
  }
}

// Airport marker layer for the map
class AirportMarkersLayer extends StatelessWidget {
  final List<Airport> airports;
  final Map<String, List<Runway>>? airportRunways;
  final ValueChanged<Airport>? onAirportTap;
  final bool showLabels;
  final double markerSize;
  final double mapZoom;
  final String? distanceUnit;

  const AirportMarkersLayer({
    super.key,
    required this.airports,
    this.airportRunways,
    this.onAirportTap,
    this.showLabels = true,
    this.markerSize = 24.0,
    this.mapZoom = 10,
    this.distanceUnit,
  });

  @override
  Widget build(BuildContext context) {
    final markers = airports.map((airport) {
      // Size hierarchy based on airport type
      double sizeMultiplier = 1.0;
      switch (airport.type) {
        case 'large_airport':
          sizeMultiplier = 1.0;
          break;
        case 'medium_airport':
          sizeMultiplier = 0.75;
          break;
        case 'small_airport':
        case 'heliport':
        case 'seaplane_base':
        case 'balloonport':
          sizeMultiplier = 0.5;
          break;
        default:
          sizeMultiplier = 0.6;
      }
      
      // Slightly reduce size for airports without ICAO codes (they use abbreviated names)
      if (airport.icao.isEmpty) {
        sizeMultiplier *= 0.9;
      }
      
      final double adjustedSize = markerSize * sizeMultiplier;
      final double airportMarkerSize = math.min(30.0, math.max(10.0, adjustedSize));

      // Get runway data for this airport (use ICAO if available, otherwise name)
      final key = airport.icao.isNotEmpty ? airport.icao : airport.name;
      final runways = airportRunways?[key];

      // Calculate runway visualization bounds separately from marker size
      double runwayVisualizationBounds = 0;
      if (mapZoom >= GeoConstants.minZoomForRunways) {
        // Calculate meters per pixel at this zoom and latitude
        final double metersPerPixel = GeoConstants.metersPerPixel(airport.position.latitude, mapZoom);
        
        // Find the longest runway
        double maxLengthM = 0;
        
        // Check OurAirports runway data
        if (runways != null && runways.isNotEmpty) {
          for (final runway in runways) {
            final lengthM = runway.lengthFt * GeoConstants.metersPerFoot;
            if (lengthM > maxLengthM) maxLengthM = lengthM;
          }
        }
        
        // Check OpenAIP runway data
        if (airport.openAIPRunways.isNotEmpty) {
          for (final runway in airport.openAIPRunways) {
            final lengthM = runway.lengthM?.toDouble() ?? 0;
            if (lengthM > maxLengthM) maxLengthM = lengthM;
          }
        }
        
        if (maxLengthM > 0 && metersPerPixel > 0) {
          // Calculate pixel size for runway visualization with small buffer (10%)
          runwayVisualizationBounds = (maxLengthM / metersPerPixel) * 1.1;
        }
      }

      // Determine the actual bounds for the Marker widget
      // Always include space for the marker icon and label
      double markerWidgetBounds = airportMarkerSize;
      
      // Add space for label if shown
      if (showLabels) {
        markerWidgetBounds += 20; // Add space for label below marker
      }
      
      // If we have runway visualization, ensure bounds are large enough
      if (runwayVisualizationBounds > 0) {
        markerWidgetBounds = math.max(markerWidgetBounds, runwayVisualizationBounds);
      }

      return Marker(
        width: markerWidgetBounds,
        height: markerWidgetBounds,
        point: airport.position,
        child: AirportMarker(
          airport: airport,
          runways: runways,
          onTap: onAirportTap != null ? () => onAirportTap!(airport) : null,
          size: airportMarkerSize,  // This is the actual icon size, not the bounds
          showLabel: showLabels,
          isSelected:
              false, // Default to false, can be set based on selection state
          mapZoom: mapZoom,
          distanceUnit: distanceUnit,
        ),
      );
    }).toList();

    return MarkerLayer(markers: markers);
  }
}