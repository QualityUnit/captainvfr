import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import '../constants/app_theme.dart';
import '../l10n/app_localizations.dart';

class MapZoomControls extends StatelessWidget {
  final MapController mapController;
  final double minZoom;
  final double maxZoom;
  final double zoomStep;
  final VoidCallback? onZoomChanged;
  final bool isCompact;
  
  const MapZoomControls({
    super.key,
    required this.mapController,
    required this.minZoom,
    required this.maxZoom,
    this.zoomStep = 0.5,
    this.onZoomChanged,
    this.isCompact = false,
  });

  void _zoomIn() {
    final currentZoom = mapController.camera.zoom;
    if (currentZoom < maxZoom) {
      HapticFeedback.lightImpact();
      mapController.move(
        mapController.camera.center,
        currentZoom + zoomStep,
      );
      // Trigger the same update logic as gesture-based zoom
      onZoomChanged?.call();
    }
  }

  void _zoomOut() {
    final currentZoom = mapController.camera.zoom;
    if (currentZoom > minZoom) {
      HapticFeedback.lightImpact();
      mapController.move(
        mapController.camera.center,
        currentZoom - zoomStep,
      );
      // Trigger the same update logic as gesture-based zoom
      onZoomChanged?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return StreamBuilder(
      stream: mapController.mapEventStream,
      builder: (context, snapshot) {
        final currentZoom = mapController.camera.zoom;
        final canZoomIn = currentZoom < maxZoom;
        final canZoomOut = currentZoom > minZoom;
        
        return Container(
          decoration: BoxDecoration(
            color: isCompact 
              ? Colors.black.withValues(alpha: 0.7)
              : Colors.white.withValues(alpha: 0.95),
            borderRadius: isCompact ? BorderRadius.circular(6) : AppTheme.defaultRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: isCompact ? 2 : 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildZoomButton(
                icon: Icons.add,
                tooltip: canZoomIn ? l10n.zoomIn : l10n.maximumZoomReached,
                semanticLabel: l10n.zoomIn,
                enabled: canZoomIn,
                onTap: _zoomIn,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(isCompact ? 6 : AppTheme.borderRadiusDefault),
                  bottomLeft: Radius.circular(isCompact ? 6 : AppTheme.borderRadiusDefault),
                ),
              ),
              if (!isCompact) ...[
                Container(
                  width: 1,
                  height: 20,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                // Zoom level indicator
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    currentZoom.toStringAsFixed(1),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
              Container(
                width: 1,
                height: isCompact ? 16 : 20,
                color: isCompact 
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.white.withValues(alpha: 0.3),
              ),
              _buildZoomButton(
                icon: Icons.remove,
                tooltip: canZoomOut ? l10n.zoomOut : l10n.minimumZoomReached,
                semanticLabel: l10n.zoomOut,
                enabled: canZoomOut,
                onTap: _zoomOut,
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(isCompact ? 6 : AppTheme.borderRadiusDefault),
                  bottomRight: Radius.circular(isCompact ? 6 : AppTheme.borderRadiusDefault),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildZoomButton({
    required IconData icon,
    required String tooltip,
    required String semanticLabel,
    required bool enabled,
    required VoidCallback onTap,
    required BorderRadius borderRadius,
  }) {
    final iconColor = isCompact 
      ? (enabled ? Colors.white : Colors.white.withValues(alpha: 0.3))
      : (enabled ? Colors.black87 : Colors.white);
    
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          label: semanticLabel,
          button: true,
          enabled: enabled,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: borderRadius,
            child: Container(
              padding: EdgeInsets.all(isCompact ? 6 : 8),
              child: Icon(
                icon,
                size: isCompact ? 16 : 20,
                color: iconColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}