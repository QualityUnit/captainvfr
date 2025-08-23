import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../models/airspace.dart';
import '../services/spatial_airspace_service.dart';
import '../utils/airspace_utils.dart';
import '../constants/app_theme.dart';

/// Optimized airspace overlay with proper debouncing and performance improvements
class OptimizedSpatialAirspacesOverlay extends StatefulWidget {
  // Constants for altitude-based opacity calculations
  static const double altitudeChangeThreshold = 100.0; // Rebuild threshold in feet
  static const double fadeStartDistance = 500.0; // Start fading after this distance
  static const double fadeEndDistance = 5000.0; // Minimum opacity at this distance
  static const double minAltitudeOpacity = 0.2; // Minimum 20% opacity for distant airspaces
  
  final SpatialAirspaceService spatialService;
  final bool showAirspacesLayer;
  final Function(Airspace) onAirspaceTap;
  final double currentAltitude;
  final Set<int>? typeFilter;

  const OptimizedSpatialAirspacesOverlay({
    super.key,
    required this.spatialService,
    required this.showAirspacesLayer,
    required this.onAirspaceTap,
    this.currentAltitude = 0,
    this.typeFilter,
  });

  @override
  State<OptimizedSpatialAirspacesOverlay> createState() =>
      _OptimizedSpatialAirspacesOverlayState();
}

class _OptimizedSpatialAirspacesOverlayState
    extends State<OptimizedSpatialAirspacesOverlay> {
  List<Airspace> _visibleAirspaces = [];
  LatLngBounds? _lastBounds;
  double? _lastZoom;
  bool _isLoading = false;
  Timer? _updateTimer;
  Timer? _loadingIndicatorTimer;
  bool _showLoadingIndicator = false;
  
  // Performance tuning constants
  static const Duration _updateDebounceDelay = Duration(milliseconds: 300);
  static const Duration _loadingIndicatorDelay = Duration(milliseconds: 500);
  static const double _zoomChangeThreshold = 0.5;
  static const double _boundsChangeThreshold = 0.01; // ~1km

  @override
  void initState() {
    super.initState();
    // Schedule initial load after first frame
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _checkAndUpdateAirspaces();
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    _loadingIndicatorTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(OptimizedSpatialAirspacesOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (!widget.showAirspacesLayer && oldWidget.showAirspacesLayer) {
      // Clear airspaces when layer is hidden
      setState(() {
        _visibleAirspaces.clear();
        _isLoading = false;
        _showLoadingIndicator = false;
      });
      _updateTimer?.cancel();
      _loadingIndicatorTimer?.cancel();
    } else if (widget.showAirspacesLayer && !oldWidget.showAirspacesLayer) {
      // Load airspaces when layer is shown
      _checkAndUpdateAirspaces();
    }
    
    // Rebuild polygons if altitude changed significantly
    if (widget.showAirspacesLayer && 
        (widget.currentAltitude - oldWidget.currentAltitude).abs() > 
        OptimizedSpatialAirspacesOverlay.altitudeChangeThreshold) {
      setState(() {
        // Triggers rebuild to update altitude-based opacity values
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showAirspacesLayer) {
      return const SizedBox.shrink();
    }

    final mapController = MapCamera.maybeOf(context);
    if (mapController == null) {
      return const SizedBox.shrink();
    }

    // Schedule bounds check after build completes
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _checkBoundsChanged(mapController);
    });

    // Build polygons with performance optimizations
    final polygons = _buildOptimizedPolygons(mapController.zoom);
    
    if (polygons.isEmpty && !_showLoadingIndicator) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        if (polygons.isNotEmpty)
          PolygonLayer(
            polygons: polygons,
            polygonCulling: true, // Enable culling for better performance
          ),
        if (_showLoadingIndicator)
          Positioned(
            top: 10,
            right: 10,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 200),
              builder: (context, value, child) {
                return Opacity(
                  opacity: value,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.7),
                      borderRadius: AppTheme.circularRadius,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Loading airspaces',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _checkBoundsChanged(MapCamera mapController) {
    final bounds = mapController.visibleBounds;
    final zoom = mapController.zoom;

    if (_shouldUpdateAirspaces(bounds, zoom)) {
      _scheduleUpdate(bounds, zoom);
    }
  }

  bool _shouldUpdateAirspaces(LatLngBounds bounds, double zoom) {
    if (_lastBounds == null || _lastZoom == null) {
      return true;
    }

    // Check if zoom changed significantly
    if ((zoom - _lastZoom!).abs() > _zoomChangeThreshold) {
      return true;
    }

    // Check if bounds changed significantly
    final latDiff = (bounds.center.latitude - _lastBounds!.center.latitude).abs();
    final lngDiff = (bounds.center.longitude - _lastBounds!.center.longitude).abs();

    return latDiff > _boundsChangeThreshold || lngDiff > _boundsChangeThreshold;
  }

  void _scheduleUpdate(LatLngBounds bounds, double zoom) {
    // Cancel any pending update
    _updateTimer?.cancel();

    // Schedule new update with debounce
    _updateTimer = Timer(_updateDebounceDelay, () {
      _updateVisibleAirspaces(bounds, zoom);
    });
  }

  void _checkAndUpdateAirspaces() {
    final mapController = MapCamera.maybeOf(context);
    if (mapController != null) {
      final bounds = mapController.visibleBounds;
      final zoom = mapController.zoom;
      _updateVisibleAirspaces(bounds, zoom);
    }
  }

  Future<void> _updateVisibleAirspaces(LatLngBounds bounds, double zoom) async {
    _lastBounds = bounds;
    _lastZoom = zoom;

    // Start loading
    if (!_isLoading) {
      setState(() {
        _isLoading = true;
      });

      // Show loading indicator only if loading takes longer than expected
      _loadingIndicatorTimer?.cancel();
      _loadingIndicatorTimer = Timer(_loadingIndicatorDelay, () {
        if (_isLoading && mounted) {
          setState(() {
            _showLoadingIndicator = true;
          });
        }
      });
    }

    try {
      // Add padding to bounds for smoother scrolling with proper longitude wrapping
      final padding = _calculateBoundsPadding(zoom);
      final paddedBounds = LatLngBounds(
        LatLng(
          bounds.southWest.latitude - padding, 
          (bounds.southWest.longitude - padding).clamp(-180.0, 180.0),
        ),
        LatLng(
          bounds.northEast.latitude + padding, 
          (bounds.northEast.longitude + padding).clamp(-180.0, 180.0),
        ),
      );

      // Use spatial service for ultra-fast queries
      // Don't pass currentAltitude to show all airspaces regardless of altitude
      final airspaces = await widget.spatialService.getAirspacesInBounds(
        paddedBounds,
        typeFilter: widget.typeFilter,
      );

      if (mounted) {
        setState(() {
          _visibleAirspaces = airspaces;
          _isLoading = false;
          _showLoadingIndicator = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading airspaces: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showLoadingIndicator = false;
        });
      }
    } finally {
      _loadingIndicatorTimer?.cancel();
    }
  }

  double _calculateBoundsPadding(double zoom) {
    // More padding at lower zoom levels
    if (zoom < 8) return 0.5;
    if (zoom < 10) return 0.3;
    if (zoom < 12) return 0.2;
    return 0.1;
  }

  List<Polygon> _buildOptimizedPolygons(double zoom) {
    // Sort airspaces to render FIS layers below other airspaces
    // This ensures large FIS polygons don't obscure important airspace information
    final sortedAirspaces = List<Airspace>.from(_visibleAirspaces);
    sortedAirspaces.sort((a, b) {
      final typeA = a.type?.toUpperCase();
      final typeB = b.type?.toUpperCase();
      
      // FIS/INFO airspaces should be rendered first (lower priority)
      final isFISA = typeA == 'FIS' || typeA == 'INFO' || typeA == 'FIR' || typeA == 'UIR';
      final isFISB = typeB == 'FIS' || typeB == 'INFO' || typeB == 'FIR' || typeB == 'UIR';
      
      if (isFISA && !isFISB) return -1;
      if (!isFISA && isFISB) return 1;
      
      // For non-FIS airspaces, maintain original order
      return 0;
    });
    
    return sortedAirspaces
        .map((airspace) => _buildPolygon(airspace, zoom))
        .toList();
  }

  Polygon _buildPolygon(Airspace airspace, double zoom) {
    // Use string-based color selection since the data contains string type values
    final color = AirspaceUtils.getAirspaceColorByString(airspace.type, airspace.icaoClass);
    final baseOpacity = _calculateFillOpacity(airspace);
    final altitudeOpacity = _calculateAltitudeBasedOpacity(airspace);
    final finalOpacity = baseOpacity * altitudeOpacity;
    final borderOpacity = _calculateBorderOpacity(airspace) * (0.5 + altitudeOpacity * 0.5); // Borders also fade but remain visible

    return Polygon(
      points: airspace.geometry,
      color: color.withValues(alpha: finalOpacity), 
      borderColor: color.withValues(alpha: borderOpacity),
      borderStrokeWidth: zoom > 12 ? 2.0 : 1.5,
      hitValue: airspace,
    );
  }

  double _calculateFillOpacity(Airspace airspace) {
    // Special handling for Class E airspaces - make them more transparent
    if (airspace.icaoClass == '4' || airspace.icaoClass?.toUpperCase() == 'E') {
      return 0.12; // 12% opacity for Class E airspaces (was 15%)
    }
    
    // Different opacity based on airspace type (string values)
    final type = airspace.type?.toUpperCase();
    if (type == 'CTR' || type == 'ATZ') { // Control zones
      return 0.28; // 28% opacity for control zones (was 35%)
    }
    if (type == 'DANGER' || type == 'PROHIBITED' || type == 'RESTRICTED') { // Danger areas
      return 0.32; // 32% opacity for danger areas (was 40%)
    }
    if (type == 'FIS' || type == 'FIR' || type == 'UIR' || type == 'INFO') { // Flight Information Service/Regions
      return 0.03; // 3% opacity for FIS/FIR (ultra-transparent to avoid map obstruction)
    }
    if (type == 'GLIDING' || type == 'SPORT') { // Sporting/recreational areas
      return 0.20; // 20% opacity (was 25%)
    }
    
    // Regular fill opacity for other airspaces
    return 0.24; // 24% opacity for better visibility (was 30%)
  }
  
  double _calculateBorderOpacity(Airspace airspace) {
    // Softer borders for all airspaces to reduce visual clutter
    return 0.7; // 70% opacity for borders (was 90%)
  }
  
  /// Calculates opacity based on vertical distance from the airspace.
  /// 
  /// This creates a smooth fade effect where:
  /// - Airspaces at current altitude are fully visible (100% opacity)
  /// - Airspaces within 500ft are fully visible
  /// - Airspaces 500-5000ft away fade gradually
  /// - Airspaces beyond 5000ft maintain minimum visibility (20% opacity)
  /// 
  /// This helps pilots focus on relevant airspaces while maintaining
  /// situational awareness of all surrounding airspace.
  double _calculateAltitudeBasedOpacity(Airspace airspace) {
    // If no altitude limits are defined, show at full opacity
    if (airspace.lowerLimitFt == null || airspace.upperLimitFt == null) {
      return 1.0;
    }
    
    final currentAlt = widget.currentAltitude;
    final lowerLimit = airspace.lowerLimitFt!;
    final upperLimit = airspace.upperLimitFt!;
    
    // If current altitude is within the airspace, full opacity
    if (currentAlt >= lowerLimit && currentAlt <= upperLimit) {
      return 1.0;
    }
    
    // Calculate distance from airspace
    double distanceFromAirspace;
    if (currentAlt < lowerLimit) {
      // Below the airspace
      distanceFromAirspace = lowerLimit - currentAlt;
    } else {
      // Above the airspace
      distanceFromAirspace = currentAlt - upperLimit;
    }
    
    // Calculate opacity based on distance using class constants
    if (distanceFromAirspace <= OptimizedSpatialAirspacesOverlay.fadeStartDistance) {
      return 1.0; // Full opacity within fade start distance
    } else if (distanceFromAirspace >= OptimizedSpatialAirspacesOverlay.fadeEndDistance) {
      return OptimizedSpatialAirspacesOverlay.minAltitudeOpacity; // Minimum opacity beyond fade end distance
    } else {
      // Linear interpolation between fadeStartDistance and fadeEndDistance
      final fadeRange = OptimizedSpatialAirspacesOverlay.fadeEndDistance - 
                       OptimizedSpatialAirspacesOverlay.fadeStartDistance;
      final fadeProgress = (distanceFromAirspace - OptimizedSpatialAirspacesOverlay.fadeStartDistance) / fadeRange;
      return 1.0 - (fadeProgress * (1.0 - OptimizedSpatialAirspacesOverlay.minAltitudeOpacity));
    }
  }
}