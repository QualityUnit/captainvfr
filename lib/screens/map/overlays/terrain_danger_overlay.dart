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
  
  // Grid resolution based on zoom level
  double get _gridResolution {
    final viewportSize = (widget.viewport.north - widget.viewport.south).abs();
    if (viewportSize < 0.1) return 0.002;  // High zoom: ~200m grid
    if (viewportSize < 0.5) return 0.005;  // Medium zoom: ~500m grid  
    if (viewportSize < 2.0) return 0.01;   // Low zoom: ~1km grid
    return 0.02; // Very low zoom: ~2km grid
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
        ((widget.currentAltitudeFt - oldWidget.currentAltitudeFt).abs() > 100 ||
         _viewportChanged(oldWidget.viewport))) {
      _updateDangerZones();
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
    _updateTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _updateDangerZones();
    });
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
    
    try {
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

    return IgnorePointer(
      child: Stack(
        children: [
          // Terrain danger zones
          ..._dangerZones.map((zone) => _buildDangerZoneMarker(zone)),
          
          // Legend
          if (_dangerZones.isNotEmpty)
            Positioned(
              bottom: 100,
              right: 16,
              child: _buildLegend(),
            ),
          
          // Loading indicator
          if (_isLoading)
            Positioned(
              top: 60,
              right: 16,
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryAccent),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDangerZoneMarker(TerrainDangerZone zone) {
    final color = _getWarningColor(zone.warningLevel);
    final opacity = _getWarningOpacity(zone.warningLevel);
    
    return MarkerLayer(
      markers: [
        Marker(
          point: zone.position,
          width: 20,
          height: 20,
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: opacity),
              shape: BoxShape.circle,
              border: Border.all(
                color: color,
                width: 1,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.dialogBackgroundColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.sectionBorderColor),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Terrain Clearance',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primaryTextColor,
            ),
          ),
          const SizedBox(height: 4),
          _buildLegendItem('Critical', TerrainWarningLevel.critical),
          _buildLegendItem('Warning', TerrainWarningLevel.warning),
          _buildLegendItem('Caution', TerrainWarningLevel.caution),
          const SizedBox(height: 4),
          Text(
            'Alt: ${widget.currentAltitudeFt.toStringAsFixed(0)}ft',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 10,
              color: AppColors.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, TerrainWarningLevel level) {
    final color = _getWarningColor(level);
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.6),
              shape: BoxShape.circle,
              border: Border.all(color: color),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontSize: 11,
              color: AppColors.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getWarningColor(TerrainWarningLevel level) {
    switch (level) {
      case TerrainWarningLevel.critical:
        return Colors.red;
      case TerrainWarningLevel.warning:
        return Colors.orange;
      case TerrainWarningLevel.caution:
        return Colors.yellow;
      case TerrainWarningLevel.safe:
        return Colors.green;
      case TerrainWarningLevel.noData:
        return Colors.grey;
    }
  }

  double _getWarningOpacity(TerrainWarningLevel level) {
    switch (level) {
      case TerrainWarningLevel.critical:
        return 0.7;
      case TerrainWarningLevel.warning:
        return 0.5;
      case TerrainWarningLevel.caution:
        return 0.3;
      case TerrainWarningLevel.safe:
        return 0.2;
      case TerrainWarningLevel.noData:
        return 0.1;
    }
  }
}

/// Custom painter for terrain contour lines
class TerrainContourPainter extends CustomPainter {
  final List<TerrainDangerZone> dangerZones;
  final double gridResolution;

  TerrainContourPainter({
    required this.dangerZones,
    required this.gridResolution,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Group zones by warning level
    final zonesByLevel = <TerrainWarningLevel, List<TerrainDangerZone>>{};
    
    for (final zone in dangerZones) {
      zonesByLevel.putIfAbsent(zone.warningLevel, () => []).add(zone);
    }
    
    // Draw contour lines for each warning level
    for (final entry in zonesByLevel.entries) {
      final paint = Paint()
        ..color = _getColorForLevel(entry.key)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      
      // Create path connecting zones of same level
      final path = ui.Path();
      bool first = true;
      
      for (final zone in entry.value) {
        // Convert LatLng to canvas coordinates
        // This is simplified - in real implementation would need proper projection
        final x = zone.position.longitude * 100;
        final y = zone.position.latitude * 100;
        
        if (first) {
          path.moveTo(x, y);
          first = false;
        } else {
          path.lineTo(x, y);
        }
      }
      
      canvas.drawPath(path, paint);
    }
  }

  Color _getColorForLevel(TerrainWarningLevel level) {
    switch (level) {
      case TerrainWarningLevel.critical:
        return Colors.red;
      case TerrainWarningLevel.warning:
        return Colors.orange;
      case TerrainWarningLevel.caution:
        return Colors.yellow;
      case TerrainWarningLevel.safe:
        return Colors.green;
      case TerrainWarningLevel.noData:
        return Colors.grey;
    }
  }

  @override
  bool shouldRepaint(TerrainContourPainter oldDelegate) {
    return dangerZones.length != oldDelegate.dangerZones.length ||
           gridResolution != oldDelegate.gridResolution;
  }
}