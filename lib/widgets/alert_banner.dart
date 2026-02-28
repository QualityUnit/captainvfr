import 'package:flutter/material.dart';
import '../services/terrain_alert_service.dart';
import '../services/airspace_alert_service.dart';
import '../services/fuel_alert_service.dart';
import '../utils/haptic_utils.dart';

/// Banner widget for displaying critical alerts
class AlertBanner extends StatelessWidget {
  final TerrainAlert? terrainAlert;
  final List<AirspaceAlert> airspaceAlerts;
  final FuelAlert? fuelAlert;
  final VoidCallback? onDismiss;
  
  const AlertBanner({
    super.key,
    this.terrainAlert,
    this.airspaceAlerts = const [],
    this.fuelAlert,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    // Prioritize alerts: Terrain > Fuel > Airspace
    if (terrainAlert != null) {
      return _buildTerrainAlert(context, terrainAlert!);
    }
    
    if (fuelAlert != null) {
      return _buildFuelAlert(context, fuelAlert!);
    }
    
    if (airspaceAlerts.isNotEmpty) {
      return _buildAirspaceAlert(context, airspaceAlerts.first);
    }
    
    return const SizedBox.shrink();
  }
  
  Widget _buildTerrainAlert(BuildContext context, TerrainAlert alert) {
    Color color;
    IconData icon;
    
    switch (alert.level) {
      case TerrainAlertLevel.critical:
        color = Colors.red.shade900;
        icon = Icons.warning;
        HapticUtils.criticalAlert();
        break;
      case TerrainAlertLevel.warning:
        color = Colors.orange.shade800;
        icon = Icons.warning_amber;
        HapticUtils.warning();
        break;
      case TerrainAlertLevel.caution:
        color = Colors.yellow.shade800;
        icon = Icons.info;
        break;
    }
    
    return _buildAlertContainer(
      context,
      color: color,
      icon: icon,
      message: alert.message,
      details: 'Terrain: ${alert.terrainElevation.toInt()} ft | Alt: ${alert.altitude.toInt()} ft',
    );
  }
  
  Widget _buildAirspaceAlert(BuildContext context, AirspaceAlert alert) {
    Color color;
    IconData icon;
    
    switch (alert.level) {
      case AirspaceAlertLevel.critical:
        color = Colors.red.shade800;
        icon = Icons.airplanemode_active;
        HapticUtils.heavyImpact();
        break;
      case AirspaceAlertLevel.warning:
        color = Colors.orange.shade700;
        icon = Icons.flight;
        HapticUtils.mediumImpact();
        break;
      case AirspaceAlertLevel.caution:
        color = Colors.blue.shade700;
        icon = Icons.info_outline;
        break;
    }
    
    return _buildAlertContainer(
      context,
      color: color,
      icon: icon,
      message: alert.message,
      details: '${alert.distance.toStringAsFixed(1)} nm away',
    );
  }
  
  Widget _buildFuelAlert(BuildContext context, FuelAlert alert) {
    Color color;
    IconData icon;
    
    switch (alert.level) {
      case FuelAlertLevel.critical:
        color = Colors.red.shade800;
        icon = Icons.local_gas_station;
        HapticUtils.criticalAlert();
        break;
      case FuelAlertLevel.warning:
        color = Colors.orange.shade700;
        icon = Icons.local_gas_station_outlined;
        HapticUtils.warning();
        break;
      case FuelAlertLevel.caution:
        color = Colors.yellow.shade700;
        icon = Icons.info;
        break;
    }
    
    return _buildAlertContainer(
      context,
      color: color,
      icon: icon,
      message: alert.message,
      details: '${alert.fuelPercentage.toStringAsFixed(0)}% of ${alert.fuelCapacity.toStringAsFixed(0)} gal',
    );
  }
  
  Widget _buildAlertContainer(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String message,
    required String details,
  }) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.5),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white,
            size: 32,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  details,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}
