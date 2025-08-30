import 'package:flutter/material.dart';

/// Simple terrain warning text widget that appears at the top of the screen
class TerrainWarningText extends StatelessWidget {
  final bool hasCritical;
  final bool hasWarning;
  
  const TerrainWarningText({
    super.key,
    required this.hasCritical,
    required this.hasWarning,
  });
  
  @override
  Widget build(BuildContext context) {
    if (!hasCritical && !hasWarning) {
      return const SizedBox.shrink();
    }
    
    return Positioned(
      top: 50, // Position below the OpenStreetMap attribution
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
                color: hasCritical ? Colors.red : Colors.orange,
                size: 20,
              ),
              const SizedBox(width: 6),
              Text(
                'Terrain',
                style: TextStyle(
                  color: hasCritical ? Colors.red : Colors.orange,
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