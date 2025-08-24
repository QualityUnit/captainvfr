import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math' as math;
import 'dart:ui' as ui;
import '../models/airspace_profile.dart';
import '../models/airspace.dart';
import '../l10n/app_localizations.dart';
import '../utils/airspace_utils.dart';
import 'airspace_frequency_display.dart';

class AltitudeProfileChart extends StatefulWidget {
  final AirspaceProfile airspaceProfile;
  final Function(ProfilePoint, List<AirspaceCrossing>)? onPointSelected;
  final Function(LatLng)? onMapFocus;
  final Function(Airspace)? onAirspaceSelected;
  final double? currentDistanceNm; // For tracking position
  final bool showMetric;
  final int? selectedLegIndex; // For highlighting specific leg in multi-leg trips
  
  const AltitudeProfileChart({
    super.key,
    required this.airspaceProfile,
    this.onPointSelected,
    this.onMapFocus,
    this.onAirspaceSelected,
    this.currentDistanceNm,
    this.showMetric = false,
    this.selectedLegIndex,
  });
  
  @override
  State<AltitudeProfileChart> createState() => _AltitudeProfileChartState();
}

class _AltitudeProfileChartState extends State<AltitudeProfileChart> {
  ProfilePoint? _selectedPoint;
  List<AirspaceCrossing> _airspacesAtSelectedPoint = [];
  AirspaceCrossing? _selectedAirspace;
  
  // Colors for different airspace types
  static const Map<String, Color> airspaceColors = {
    '0': Color(0xFF8B0000),  // PROHIBITED - Dark Red
    '1': Color(0xFFFF4500),  // RESTRICTED - Orange Red  
    '2': Color(0xFFFF8C00),  // DANGER - Dark Orange
    '3': Color(0xFF4169E1),  // CTR - Royal Blue
    '4': Color(0xFF1E90FF),  // TMZ - Dodger Blue
    '5': Color(0xFF00CED1),  // RMZ - Dark Turquoise
    '6': Color(0xFF32CD32),  // TMA - Lime Green
    '7': Color(0xFF9370DB),  // TRA - Medium Purple
    '8': Color(0xFFFF69B4),  // TSA - Hot Pink
    '9': Color(0xFFFFD700),  // FIR - Gold
    '10': Color(0xFF87CEEB), // UIR - Sky Blue
    '11': Color(0xFFDDA0DD), // ADIZ - Plum
    '12': Color(0xFF20B2AA), // ATZ - Light Sea Green
    '13': Color(0xFFFFB6C1), // MATZ - Light Pink
    '14': Color(0xFF778899), // NO_FIR - Light Slate Gray
    '15': Color(0xFFB0C4DE), // AIRWAY - Light Steel Blue
    '16': Color(0xFF8FBC8F), // MTR - Dark Sea Green
    '17': Color(0xFFFFA500), // ALERT_AREA - Orange
    '18': Color(0xFFFF1493), // WARNING_AREA - Deep Pink
    '19': Color(0xFF7B68EE), // PROTECTED - Medium Slate Blue
    '20': Color(0xFF48D1CC), // HTZ - Medium Turquoise
    '21': Color(0xFF6B8E23), // GLIDER_SECTOR - Olive Drab
    '22': Color(0xFFD2691E), // TRP - Chocolate
    '23': Color(0xFFCD5C5C), // TIZ - Indian Red
    '24': Color(0xFFBC8F8F), // TIA - Rosy Brown
    '25': Color(0xFF8B4513), // MTA - Saddle Brown
    '26': Color(0xFFA0522D), // CTA - Sienna
    '27': Color(0xFF708090), // ACC_SECTOR - Slate Gray
    '28': Color(0xFF2F4F4F), // AERIAL_SPORTING_RECREATIONAL - Dark Slate Gray
    '29': Color(0xFF696969), // OVERFLIGHT_RESTRICTION - Dim Gray
    '30': Color(0xFF808080), // MRT - Gray
  };
  
  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    final profile = widget.airspaceProfile;
    
    if (profile.profilePoints.isEmpty) {
      return Container(
        height: 250,
        color: Colors.black,
        child: Center(
          child: Text(
            localizations?.noFlightPathDataAvailable ?? 'No flight path data available',
            style: TextStyle(color: Colors.grey[400]),
          ),
        ),
      );
    }
    
    // Remove fixed height container - use full available space from parent
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Chart title and info
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                localizations?.altitudeProfile ?? 'Altitude Profile',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_selectedPoint != null)
                Text(
                  _formatPointInfo(_selectedPoint!),
                  style: TextStyle(
                    color: Colors.orange[300],
                    fontSize: 12,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          
          // The chart with custom paint for airspaces
          Expanded(
            flex: 3, // Give more space to the chart
            child: Stack(
              children: [
                // Custom painter for airspace rectangles
                CustomPaint(
                  painter: AirspaceRectanglePainter(
                    profile: profile,
                    showMetric: widget.showMetric,
                    airspaceColors: airspaceColors,
                    selectedAirspace: _selectedAirspace,
                  ),
                  child: Container(),
                ),
                // Custom painter for terrain profile
                CustomPaint(
                  painter: TerrainProfilePainter(
                    profile: profile,
                    showMetric: widget.showMetric,
                  ),
                  child: Container(),
                ),
                // The line chart on top
                GestureDetector(
                  onTapDown: (details) {
                    _handleChartTap(details.localPosition);
                  },
                  child: LineChart(
                    _buildChartData(),
                  ),
                ),
              ],
            ),
          ),
          
          // Show all airspaces at selected point
          if (_airspacesAtSelectedPoint.isNotEmpty && _selectedPoint != null)
            Expanded(
              flex: 2, // Give more space to the airspace list
              child: Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.grey[600]!,
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header row (fixed)
                    Row(
                      children: [
                        Icon(Icons.layers, color: Colors.orange[400], size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Airspaces at ${_selectedPoint!.distanceNm.toStringAsFixed(1)} nm, ${_selectedPoint!.altitudeFt.toStringAsFixed(0)} ft',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Scrollable list (uses remaining space)
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: _buildAirspaceList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  void _handleChartTap(Offset localPosition) {
    final profile = widget.airspaceProfile;
    final RenderBox box = context.findRenderObject() as RenderBox;
    final size = box.size;
    
    // Calculate chart maximum altitude (same as in _buildChartData)
    final double chartMaxAltitude = math.min(
      60000,
      math.max(
        6000,
        profile.maxAltitudeFt * 2.0,
      ),
    );
    
    // Calculate chart area (accounting for padding and labels)
    const leftPadding = 50.0;
    const rightPadding = 20.0;
    const topPadding = 40.0;
    const bottomPadding = 50.0;
    
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;
    
    // Convert tap position to chart coordinates
    final x = localPosition.dx - leftPadding;
    final y = localPosition.dy - topPadding;
    
    if (x < 0 || x > chartWidth || y < 0 || y > chartHeight) {
      return;
    }
    
    // Convert to data coordinates
    final distanceNm = (x / chartWidth) * profile.totalDistanceNm;
    final altitudeFt = ((chartHeight - y) / chartHeight) * chartMaxAltitude;
    
    // Find airspace at this point
    AirspaceCrossing? tappedAirspace;
    for (final crossing in profile.airspaceCrossings) {
      if (distanceNm >= crossing.entryDistanceNm && 
          distanceNm <= crossing.exitDistanceNm) {
        final lowerLimit = crossing.airspace.lowerLimitFt ?? 0;
        final upperLimit = crossing.airspace.upperLimitFt ?? 99999;
        if (altitudeFt >= lowerLimit && altitudeFt <= upperLimit) {
          tappedAirspace = crossing;
          break;
        }
      }
    }
    
    setState(() {
      _selectedAirspace = tappedAirspace;
    });
    
    if (tappedAirspace != null) {
      // Notify about airspace selection
      widget.onAirspaceSelected?.call(tappedAirspace.airspace);
      
      // Focus map on airspace center
      final centerDistance = (tappedAirspace.entryDistanceNm + tappedAirspace.exitDistanceNm) / 2;
      final centerPoint = profile.findNearestPoint(centerDistance);
      if (centerPoint != null) {
        widget.onMapFocus?.call(centerPoint.position);
      }
    }
  }
  
  LineChartData _buildChartData() {
    final profile = widget.airspaceProfile;
    
    // Calculate chart maximum altitude
    // Show at least 2x the flight altitude, minimum 6000ft, maximum 60000ft
    final double chartMaxAltitude = math.min(
      60000,
      math.max(
        6000,
        profile.maxAltitudeFt * 2.0,
      ),
    );
    
    // Create main altitude line
    final altitudeSpots = profile.profilePoints.map((point) {
      return FlSpot(point.distanceNm, point.altitudeFt);
    }).toList();
    
    // Create lines for each leg (different colors for multi-leg trips)
    List<LineChartBarData> lines = [];
    
    if (profile.legCount > 1) {
      // Multi-leg trip - create separate line for each leg
      for (int legIndex = 0; legIndex < profile.legCount; legIndex++) {
        final legPoints = profile.getPointsForLeg(legIndex);
        if (legPoints.isEmpty) continue;
        
        final legSpots = legPoints.map((point) {
          return FlSpot(point.distanceNm, point.altitudeFt);
        }).toList();
        
        lines.add(LineChartBarData(
          spots: legSpots,
          isCurved: false,
          color: _getLegColor(legIndex),
          barWidth: widget.selectedLegIndex == legIndex ? 3 : 2,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              // Show dots only for waypoints
              final point = legPoints[index];
              if (point.waypointId != null) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: _getLegColor(legIndex),
                );
              }
              return FlDotCirclePainter(radius: 0);
            },
          ),
          belowBarData: BarAreaData(show: false),
        ));
      }
    } else {
      // Single flight plan
      lines.add(LineChartBarData(
        spots: altitudeSpots,
        isCurved: false,
        color: Colors.cyan,
        barWidth: 2,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, percent, barData, index) {
            final point = profile.profilePoints[index];
            if (point.waypointId != null) {
              return FlDotCirclePainter(
                radius: 4,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: Colors.cyan,
              );
            }
            return FlDotCirclePainter(radius: 0);
          },
        ),
        belowBarData: BarAreaData(
          show: false, // Don't show area under line
        ),
      ));
    }
    
    // Add current position indicator if tracking
    if (widget.currentDistanceNm != null) {
      final altitude = profile.getAltitudeAtDistance(widget.currentDistanceNm!);
      if (altitude != null) {
        lines.add(LineChartBarData(
          spots: [FlSpot(widget.currentDistanceNm!, altitude)],
          isCurved: false,
          color: Colors.red,
          barWidth: 0,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 6,
                color: Colors.red,
                strokeWidth: 2,
                strokeColor: Colors.white,
              );
            },
          ),
        ));
      }
    }
    
    return LineChartData(
      minX: 0,
      maxX: profile.totalDistanceNm,
      minY: 0,
      maxY: chartMaxAltitude.roundToDouble(),
      lineBarsData: lines,
      backgroundColor: Colors.transparent,
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
          axisNameWidget: Text(
            widget.showMetric ? 'Altitude (m)' : 'Altitude (ft)',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final displayValue = widget.showMetric 
                ? (value * 0.3048).round()
                : value.round();
              return Text(
                '$displayValue',
                style: TextStyle(color: Colors.grey[400], fontSize: 10),
              );
            },
            reservedSize: 50,
          ),
        ),
        bottomTitles: AxisTitles(
          axisNameWidget: Text(
            widget.showMetric ? 'Distance (km)' : 'Distance (nm)',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
          sideTitles: SideTitles(
            showTitles: true,
            getTitlesWidget: (value, meta) {
              final displayValue = widget.showMetric
                ? (value * 1.852).toStringAsFixed(1)
                : value.toStringAsFixed(1);
              return Text(
                displayValue,
                style: TextStyle(color: Colors.grey[400], fontSize: 10),
              );
            },
            reservedSize: 30,
          ),
        ),
        rightTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
      ),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: true,
        drawHorizontalLine: true,
        getDrawingHorizontalLine: (value) {
          return FlLine(
            color: Colors.grey[800]!,
            strokeWidth: 0.5,
          );
        },
        getDrawingVerticalLine: (value) {
          // Draw lines at leg boundaries for multi-leg trips
          if (profile.legCount > 1) {
            for (final startDistance in profile.legStartDistances) {
              if ((value - startDistance).abs() < 0.1) {
                return FlLine(
                  color: Colors.orange[600]!,
                  strokeWidth: 1,
                  dashArray: [5, 5],
                );
              }
            }
          }
          return FlLine(
            color: Colors.grey[800]!,
            strokeWidth: 0.5,
          );
        },
      ),
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: Colors.grey[700]!, width: 1),
      ),
      lineTouchData: LineTouchData(
        enabled: true,
        touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
          if (event is FlTapUpEvent && response != null && response.lineBarSpots != null) {
            for (final spot in response.lineBarSpots!) {
              final nearestPoint = profile.findNearestPoint(spot.x);
              if (nearestPoint != null) {
                setState(() {
                  _selectedPoint = nearestPoint;
                  _airspacesAtSelectedPoint = profile.getAirspacesAtDistance(spot.x);
                });
                
                // Notify callbacks - only call onPointSelected, not onMapFocus
                // The onPointSelected will handle calling onMapFocus with proper parameters
                if (widget.onPointSelected != null) {
                  widget.onPointSelected!(nearestPoint, _airspacesAtSelectedPoint);
                }
                break;
              }
            }
          }
        },
        touchTooltipData: LineTouchTooltipData(
          getTooltipItems: (spots) {
            return spots.map((spot) {
              final point = profile.findNearestPoint(spot.x);
              if (point != null) {
                String text = '';
                if (point.waypointName != null) {
                  text = '${point.waypointName}\n';
                }
                text += '${spot.y.toStringAsFixed(0)} ft';
                if (widget.showMetric) {
                  text += ' (${(spot.y * 0.3048).toStringAsFixed(0)} m)';
                }
                return LineTooltipItem(
                  text,
                  const TextStyle(color: Colors.white, fontSize: 12),
                );
              }
              return null;
            }).toList();
          },
        ),
      ),
    );
  }
  
  Color _getLegColor(int legIndex) {
    // Use consistent colors for legs
    final colors = [
      Colors.cyan,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.pink,
      Colors.teal,
    ];
    return colors[legIndex % colors.length];
  }
  
  String _formatPointInfo(ProfilePoint point) {
    String info = '${point.distanceNm.toStringAsFixed(1)} nm';
    if (widget.showMetric) {
      info += ' (${(point.distanceNm * 1.852).toStringAsFixed(1)} km)';
    }
    info += ', ${point.altitudeFt.toStringAsFixed(0)} ft';
    if (widget.showMetric) {
      info += ' (${(point.altitudeFt * 0.3048).toStringAsFixed(0)} m)';
    }
    if (point.waypointName != null) {
      info = '${point.waypointName}: $info';
    }
    if (widget.airspaceProfile.legCount > 1 && point.legIndex != null) {
      info += ' [Leg ${point.legIndex! + 1}]';
    }
    return info;
  }
  
  List<Widget> _buildAirspaceList() {
    if (_selectedPoint == null || _airspacesAtSelectedPoint.isEmpty) {
      return [];
    }
    
    final List<Widget> widgets = [];
    final flightAltitude = _selectedPoint!.altitudeFt;
    
    // Sort airspaces by lower limit (highest first)
    final sortedAirspaces = List<AirspaceCrossing>.from(_airspacesAtSelectedPoint)
      ..sort((a, b) {
        final aLower = a.airspace.lowerLimitFt ?? 0;
        final bLower = b.airspace.lowerLimitFt ?? 0;
        return bLower.compareTo(aLower);
      });
    
    for (final crossing in sortedAirspaces) {
      final airspace = crossing.airspace;
      final lowerLimit = airspace.lowerLimitFt ?? 0;
      final upperLimit = airspace.upperLimitFt ?? 99999;
      
      // Determine if flight path intersects this airspace
      final isIntersecting = flightAltitude >= lowerLimit && flightAltitude <= upperLimit;
      
      // Determine position relative to flight
      String position = '';
      Color positionColor = Colors.grey[400]!;
      if (isIntersecting) {
        position = 'INTERSECTING';
        positionColor = Colors.orange;
      } else if (lowerLimit > flightAltitude) {
        position = 'ABOVE';
        positionColor = Colors.blue[300]!;
      } else {
        position = 'BELOW';
        positionColor = Colors.green[300]!;
      }
      
      widgets.add(
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: isIntersecting 
              ? Colors.orange.withValues(alpha: 0.1)
              : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isIntersecting 
                ? Colors.orange
                : airspaceColors[airspace.type] ?? Colors.grey,
              width: isIntersecting ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: airspaceColors[airspace.type] ?? Colors.grey,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            airspace.name,
                            style: TextStyle(
                              color: isIntersecting ? Colors.orange : Colors.white,
                              fontWeight: isIntersecting ? FontWeight.bold : FontWeight.normal,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: positionColor.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4),
                            border: Border.all(color: positionColor, width: 1),
                          ),
                          child: Text(
                            position,
                            style: TextStyle(
                              color: positionColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${AirspaceUtils.getAirspaceTypeName(airspace.type)} | '
                      '${lowerLimit.toStringAsFixed(0)}-${upperLimit.toStringAsFixed(0)} ft',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 10,
                      ),
                    ),
                    if (airspace.hasFrequencyInfo) ...[
                      const SizedBox(height: 4),
                      AirspaceFrequencyDisplay(
                        airspace: airspace,
                        showDetails: false,
                        showCallsign: true,
                      ),
                    ],
                    if (isIntersecting) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Flight at ${flightAltitude.toStringAsFixed(0)} ft',
                        style: TextStyle(
                          color: Colors.orange[300],
                          fontSize: 10,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    return widgets;
  }
  
}

/// Custom painter to draw airspace rectangles
class AirspaceRectanglePainter extends CustomPainter {
  final AirspaceProfile profile;
  final bool showMetric;
  final Map<String, Color> airspaceColors;
  final AirspaceCrossing? selectedAirspace;
  
  AirspaceRectanglePainter({
    required this.profile,
    required this.showMetric,
    required this.airspaceColors,
    this.selectedAirspace,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Calculate chart maximum altitude (same logic as in chart)
    final double chartMaxAltitude = math.min(
      60000,
      math.max(
        6000,
        profile.maxAltitudeFt * 2.0,
      ),
    );
    
    // Calculate chart area (accounting for padding and labels)
    const leftPadding = 50.0;
    const rightPadding = 20.0;
    const topPadding = 40.0;
    const bottomPadding = 50.0;
    
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;
    
    if (chartWidth <= 0 || chartHeight <= 0) return;
    
    // Save canvas state
    canvas.save();
    
    // Clip to chart area
    canvas.clipRect(Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight));
    
    // Draw airspace rectangles
    for (final crossing in profile.airspaceCrossings) {
      final color = airspaceColors[crossing.airspace.type] ?? Colors.grey;
      
      // Calculate rectangle position
      final x1 = leftPadding + (crossing.entryDistanceNm / profile.totalDistanceNm) * chartWidth;
      final x2 = leftPadding + (crossing.exitDistanceNm / profile.totalDistanceNm) * chartWidth;
      
      final lowerLimitFt = crossing.airspace.lowerLimitFt ?? 0;
      final upperLimitFt = crossing.airspace.upperLimitFt ?? chartMaxAltitude;
      
      final y1 = topPadding + chartHeight - 
                (upperLimitFt / chartMaxAltitude) * chartHeight;
      final y2 = topPadding + chartHeight - 
                (lowerLimitFt / chartMaxAltitude) * chartHeight;
      
      // Draw filled rectangle
      final rect = Rect.fromLTRB(x1, y1, x2, y2);
      
      // Determine opacity and border based on selection and conflict
      final isSelected = selectedAirspace == crossing;
      final hasConflict = crossing.checkAltitudeConflict();
      final opacity = isSelected ? 0.3 : (hasConflict ? 0.2 : 0.15);
      final borderWidth = isSelected ? 2.0 : (hasConflict ? 2.0 : 1.0);
      
      // Fill
      final fillPaint = Paint()
        ..color = hasConflict
          ? Colors.orange.withValues(alpha: opacity)
          : color.withValues(alpha: opacity)
        ..style = PaintingStyle.fill;
      
      canvas.drawRect(rect, fillPaint);
      
      // Border - orange for intersecting airspaces
      final borderPaint = Paint()
        ..color = hasConflict
          ? Colors.orange.withValues(alpha: 0.8)
          : color.withValues(alpha: 0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth;
      
      canvas.drawRect(rect, borderPaint);
      
      // Draw airspace name if rectangle is large enough
      if (x2 - x1 > 50 && y2 - y1 > 20) {
        final textPainter = TextPainter(
          text: TextSpan(
            text: crossing.airspace.name.length > 10 
              ? '${crossing.airspace.name.substring(0, 10)}...'
              : crossing.airspace.name,
            style: TextStyle(
              color: hasConflict 
                ? Colors.white.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.7),
              fontSize: hasConflict ? 11 : 10,
              fontWeight: hasConflict ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout(maxWidth: x2 - x1 - 4);
        textPainter.paint(canvas, Offset(x1 + 2, y1 + 2));
      }
    }
    
    // Restore canvas state
    canvas.restore();
  }
  
  @override
  bool shouldRepaint(AirspaceRectanglePainter oldDelegate) {
    return oldDelegate.selectedAirspace != selectedAirspace ||
           oldDelegate.profile != profile;
  }
}

/// Custom painter to draw terrain profile
class TerrainProfilePainter extends CustomPainter {
  final AirspaceProfile profile;
  final bool showMetric;
  
  TerrainProfilePainter({
    required this.profile,
    required this.showMetric,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Get terrain points (filter out nulls)
    final terrainPoints = <ProfilePoint>[];
    for (final point in profile.profilePoints) {
      if (point.terrainElevationFt != null) {
        terrainPoints.add(point);
      }
    }
    
    if (terrainPoints.isEmpty) return;
    
    // Calculate chart maximum altitude (same logic as in chart)
    final double chartMaxAltitude = math.min(
      60000,
      math.max(
        6000,
        profile.maxAltitudeFt * 2.0,
      ),
    );
    
    // Calculate chart area (accounting for padding and labels)
    const leftPadding = 50.0;
    const rightPadding = 20.0;
    const topPadding = 40.0;
    const bottomPadding = 50.0;
    
    final chartWidth = size.width - leftPadding - rightPadding;
    final chartHeight = size.height - topPadding - bottomPadding;
    
    if (chartWidth <= 0 || chartHeight <= 0) return;
    
    // Create terrain fill path
    final terrainPath = ui.Path();
    bool firstPoint = true;
    
    for (final point in terrainPoints) {
      final x = leftPadding + (point.distanceNm / profile.totalDistanceNm) * chartWidth;
      final y = topPadding + chartHeight - (point.terrainElevationFt! / chartMaxAltitude) * chartHeight;
      
      if (firstPoint) {
        terrainPath.moveTo(x, y);
        firstPoint = false;
      } else {
        terrainPath.lineTo(x, y);
      }
    }
    
    // Close the path to fill the area
    if (terrainPoints.isNotEmpty) {
      // Add bottom right corner
      final lastX = leftPadding + (terrainPoints.last.distanceNm / profile.totalDistanceNm) * chartWidth;
      terrainPath.lineTo(lastX, topPadding + chartHeight);
      
      // Add bottom left corner
      final firstX = leftPadding + (terrainPoints.first.distanceNm / profile.totalDistanceNm) * chartWidth;
      terrainPath.lineTo(firstX, topPadding + chartHeight);
      
      // Close path
      terrainPath.close();
    }
    
    // Save canvas state
    canvas.save();
    
    // Clip to chart area
    canvas.clipRect(Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight));
    
    // Draw terrain fill with gradient
    final terrainPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.brown.withOpacity(0.6),
          Colors.brown.withOpacity(0.3),
        ],
      ).createShader(Rect.fromLTWH(leftPadding, topPadding, chartWidth, chartHeight))
      ..style = PaintingStyle.fill;
    
    canvas.drawPath(terrainPath, terrainPaint);
    
    // Draw terrain outline
    final outlinePaint = Paint()
      ..color = Colors.brown
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawPath(terrainPath, outlinePaint);
    
    // Restore canvas state
    canvas.restore();
  }
  
  @override
  bool shouldRepaint(TerrainProfilePainter oldDelegate) {
    return oldDelegate.profile != profile ||
           oldDelegate.showMetric != showMetric;
  }
}