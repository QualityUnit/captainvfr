import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:async';
import 'dart:ui' as ui;
import '../../../services/terrain_elevation_service.dart';
import '../../../constants/app_colors.dart';

/// Overlay showing terrain danger zones based on current altitude
class TerrainDangerOverlay extends StatefulWidget {
  final double currentAltitudeFt;
  final LatLngBounds viewport;
  final bool isVisible;
  final VoidCallback? onTerrainWarning;

  const TerrainDangerOverlay({
    super.key,
    required this.currentAltitudeFt,
    required this.viewport,
    this.isVisible = true,
    this.onTerrainWarning,
  });

  @override
  State<TerrainDangerOverlay> createState() => _TerrainDangerOverlayState();
}

class _TerrainDangerOverlayState extends State<TerrainDangerOverlay> {
  final TerrainElevationService _terrainService = TerrainElevationService();
  List<TerrainDangerZone> _dangerZones = [];
  Timer? _updateTimer;
  bool _isLoading = false;
  LatLngBounds? _lastViewport;
  double? _lastAltitude;
  
  // Grid resolution based on zoom level - optimized for performance
  double get _gridResolution {
    final viewportSize = (widget.viewport.north - widget.viewport.south).abs();
    if (viewportSize < 0.05) return 0.003;  // Very high zoom: ~300m grid
    if (viewportSize < 0.2) return 0.008;   // High zoom: ~800m grid
    if (viewportSize < 0.5) return 0.015;   // Medium zoom: ~1.5km grid  
    if (viewportSize < 2.0) return 0.025;   // Low zoom: ~2.5km grid
    return 0.04; // Very low zoom: ~4km grid - coarser for better performance
  }

  @override
  void initState() {
    super.initState();
    if (widget.isVisible) {
      _startUpdating();
    }
  }

  @override
  void didUpdateWidget(TerrainDangerOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _startUpdating();
      } else {
        _stopUpdating();
      }
    }
    
    // Update if altitude or viewport changed significantly
    if (widget.isVisible && 
        ((widget.currentAltitudeFt - oldWidget.currentAltitudeFt).abs() > 200 ||
         _viewportChanged(oldWidget.viewport))) {
      // Debounce updates to avoid too frequent calls
      _updateTimer?.cancel();
      _updateTimer = Timer(const Duration(milliseconds: 500), () {
        _updateDangerZones();
      });
    }
  }

  bool _viewportChanged(LatLngBounds oldViewport) {
    const threshold = 0.01; // degrees
    return (widget.viewport.north - oldViewport.north).abs() > threshold ||
           (widget.viewport.south - oldViewport.south).abs() > threshold ||
           (widget.viewport.east - oldViewport.east).abs() > threshold ||
           (widget.viewport.west - oldViewport.west).abs() > threshold;
  }

  void _startUpdating() {
    _updateDangerZones();
    _updateTimer?.cancel();
    // Reduced update frequency for better performance
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      // Only update if viewport or altitude changed significantly
      if (_hasSignificantChange()) {
        _updateDangerZones();
      }
    });
  }
  
  bool _hasSignificantChange() {
    if (_lastViewport == null || _lastAltitude == null) return true;
    
    // Check altitude change
    if ((widget.currentAltitudeFt - _lastAltitude!).abs() > 200) return true;
    
    // Check viewport change
    const threshold = 0.02; // degrees
    return (widget.viewport.north - _lastViewport!.north).abs() > threshold ||
           (widget.viewport.south - _lastViewport!.south).abs() > threshold ||
           (widget.viewport.east - _lastViewport!.east).abs() > threshold ||
           (widget.viewport.west - _lastViewport!.west).abs() > threshold;
  }

  void _stopUpdating() {
    _updateTimer?.cancel();
    _updateTimer = null;
  }

  Future<void> _updateDangerZones() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
    });
    
    // Store current viewport and altitude
    _lastViewport = widget.viewport;
    _lastAltitude = widget.currentAltitudeFt;
    
    try {
      // Use optimized batch processing
      final zones = await _terrainService.getTerrainDangerZones(
        widget.viewport,
        widget.currentAltitudeFt,
        gridResolution: _gridResolution,
      );
      
      // Check for critical terrain warnings
      final hasCritical = zones.any(
        (z) => z.warningLevel == TerrainWarningLevel.critical
      );
      
      if (hasCritical && widget.onTerrainWarning != null) {
        widget.onTerrainWarning!();
      }
      
      if (mounted) {
        setState(() {
          _dangerZones = zones;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _stopUpdating();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible || _dangerZones.isEmpty) {
      return const SizedBox.shrink();
    }

    // Return only the map markers layer
    // The warning text will be handled separately in TerrainWarningText widget
    return IgnorePointer(
      child: MarkerLayer(
        markers: _dangerZones
            .where((zone) => zone.warningLevel == TerrainWarningLevel.critical || 
                             zone.warningLevel == TerrainWarningLevel.warning)
            .map((zone) => Marker(
                  point: zone.position,
                  width: 15,  // Small markers
                  height: 15,
                  child: Container(
                    decoration: BoxDecoration(
                      color: zone.warningLevel == TerrainWarningLevel.critical
                          ? Colors.red.withValues(alpha: 0.08)  // Very transparent red
                          : Colors.orange.withValues(alpha: 0.06), // Very transparent orange
                      shape: BoxShape.circle,
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
  
  // Expose danger zones for external use
  bool get hasCriticalTerrain => _dangerZones.any(
    (z) => z.warningLevel == TerrainWarningLevel.critical
  );
  
  bool get hasWarningTerrain => _dangerZones.any(
    (z) => z.warningLevel == TerrainWarningLevel.warning
  );
}

