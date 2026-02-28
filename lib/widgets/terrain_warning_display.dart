import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../services/terrain_elevation_service.dart';

/// Widget that displays terrain warning when dangerous terrain is detected
class TerrainWarningDisplay extends StatefulWidget {
  final double? currentAltitudeFt;
  final LatLngBounds? viewport;
  final bool isVisible;
  
  const TerrainWarningDisplay({
    super.key,
    required this.currentAltitudeFt,
    required this.viewport,
    required this.isVisible,
  });
  
  @override
  State<TerrainWarningDisplay> createState() => _TerrainWarningDisplayState();
}

class _TerrainWarningDisplayState extends State<TerrainWarningDisplay> {
  bool _hasCritical = false;
  bool _hasWarning = false;
  
  @override
  void initState() {
    super.initState();
    if (widget.isVisible) {
      _checkTerrain();
    }
  }
  
  @override
  void didUpdateWidget(TerrainWarningDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isVisible && 
        (widget.currentAltitudeFt != oldWidget.currentAltitudeFt ||
         widget.viewport != oldWidget.viewport)) {
      _checkTerrain();
    }
  }
  
  Future<void> _checkTerrain() async {
    if (widget.currentAltitudeFt == null || widget.viewport == null) {
      if (mounted) {
        setState(() {
          _hasCritical = false;
          _hasWarning = false;
        });
      }
      return;
    }
    
    try {
      final zones = await TerrainElevationService.getTerrainDangerZones(
        widget.viewport!,
        widget.currentAltitudeFt!,
        gridResolution: 0.025, // Coarse resolution for quick check
      );
      
      if (mounted) {
        setState(() {
          _hasCritical = zones.any(
            (z) => z.warningLevel == TerrainWarningLevel.critical
          );
          _hasWarning = zones.any(
            (z) => z.warningLevel == TerrainWarningLevel.warning
          );
        });
      }
    } catch (e) {
      // Ignore errors
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (!widget.isVisible || (!_hasCritical && !_hasWarning)) {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      top: MediaQuery.of(context).padding.top + 40, // Position below the OpenStreetMap attribution
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning,
                color: _hasCritical ? Colors.red : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'Terrain',
                style: TextStyle(
                  color: _hasCritical ? Colors.red : Colors.orange,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}