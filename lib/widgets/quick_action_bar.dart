import 'package:flutter/material.dart';

/// Quick action bar for common pilot actions
/// Positioned at bottom of map for easy thumb access
class QuickActionBar extends StatelessWidget {
  final VoidCallback onCenterMap;
  final VoidCallback onStartFlight;
  final VoidCallback onEmergency;
  final VoidCallback onLayers;
  final VoidCallback onFlightPlan;
  final bool isTracking;
  final bool hasFlightPlan;
  
  const QuickActionBar({
    super.key,
    required this.onCenterMap,
    required this.onStartFlight,
    required this.onEmergency,
    required this.onLayers,
    required this.onFlightPlan,
    required this.isTracking,
    required this.hasFlightPlan,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildActionButton(
            icon: Icons.my_location,
            label: 'Center',
            onTap: onCenterMap,
            color: Colors.blue,
          ),
          const SizedBox(width: 4),
          _buildActionButton(
            icon: isTracking ? Icons.stop : Icons.flight_takeoff,
            label: isTracking ? 'Stop' : 'Start',
            onTap: onStartFlight,
            color: isTracking ? Colors.red : Colors.green,
            isLarge: true,
          ),
          const SizedBox(width: 4),
          _buildActionButton(
            icon: Icons.route,
            label: 'Plan',
            onTap: onFlightPlan,
            color: hasFlightPlan ? Colors.orange : Colors.grey,
          ),
          const SizedBox(width: 4),
          _buildActionButton(
            icon: Icons.layers,
            label: 'Layers',
            onTap: onLayers,
            color: Colors.purple,
          ),
          const SizedBox(width: 4),
          _buildActionButton(
            icon: Icons.warning,
            label: 'SOS',
            onTap: onEmergency,
            color: Colors.red.shade700,
          ),
        ],
      ),
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
    bool isLarge = false,
  }) {
    final size = isLarge ? 64.0 : 56.0;
    final iconSize = isLarge ? 28.0 : 24.0;
    final fontSize = isLarge ? 11.0 : 10.0;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(size / 2),
          border: Border.all(
            color: color.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: iconSize,
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
