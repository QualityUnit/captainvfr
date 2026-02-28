import 'package:flutter/material.dart';

/// Utility class for terrain clearance color coding
/// Provides visual indication of terrain clearance levels
class TerrainColorUtils {
  /// Get terrain color based on clearance
  /// 🟢 Green: > 1000ft clearance (safe)
  /// 🟡 Yellow: 500-1000ft clearance (caution)
  /// 🟠 Orange: 200-500ft clearance (warning)
  /// 🔴 Red: < 200ft clearance (danger)
  /// ⚫ Black: Below terrain! (critical)
  static Color getTerrainColor(double clearanceFeet) {
    if (clearanceFeet < 0) {
      return Colors.black; // Below terrain - CRITICAL
    } else if (clearanceFeet < 200) {
      return Colors.red.shade700; // Danger
    } else if (clearanceFeet < 500) {
      return Colors.orange.shade600; // Warning
    } else if (clearanceFeet < 1000) {
      return Colors.yellow.shade700; // Caution
    } else {
      return Colors.green.shade600; // Safe
    }
  }
  
  /// Get terrain color with opacity for overlay
  static Color getTerrainColorWithOpacity(double clearanceFeet, double opacity) {
    final color = getTerrainColor(clearanceFeet);
    return color.withValues(alpha: opacity);
  }
  
  /// Get terrain category
  static TerrainCategory getTerrainCategory(double clearanceFeet) {
    if (clearanceFeet < 0) {
      return TerrainCategory.critical;
    } else if (clearanceFeet < 200) {
      return TerrainCategory.danger;
    } else if (clearanceFeet < 500) {
      return TerrainCategory.warning;
    } else if (clearanceFeet < 1000) {
      return TerrainCategory.caution;
    } else {
      return TerrainCategory.safe;
    }
  }
  
  /// Get category name
  static String getCategoryName(TerrainCategory category) {
    switch (category) {
      case TerrainCategory.safe:
        return 'Safe';
      case TerrainCategory.caution:
        return 'Caution';
      case TerrainCategory.warning:
        return 'Warning';
      case TerrainCategory.danger:
        return 'Danger';
      case TerrainCategory.critical:
        return 'CRITICAL';
    }
  }
  
  /// Get category description
  static String getCategoryDescription(TerrainCategory category) {
    switch (category) {
      case TerrainCategory.safe:
        return 'Terrain clearance > 1000ft';
      case TerrainCategory.caution:
        return 'Terrain clearance 500-1000ft';
      case TerrainCategory.warning:
        return 'Terrain clearance 200-500ft';
      case TerrainCategory.danger:
        return 'Terrain clearance < 200ft';
      case TerrainCategory.critical:
        return 'BELOW TERRAIN!';
    }
  }
  
  /// Calculate minimum safe altitude (MSA)
  /// Returns MSA in feet based on highest terrain + buffer
  static double calculateMSA(double highestTerrainFeet, {bool isNight = false}) {
    // FAA recommends 1000ft above highest obstacle within 5nm (day)
    // 2000ft above highest obstacle (night)
    final buffer = isNight ? 2000.0 : 1000.0;
    return highestTerrainFeet + buffer;
  }
}

/// Terrain clearance category
enum TerrainCategory {
  safe,     // > 1000ft clearance
  caution,  // 500-1000ft clearance
  warning,  // 200-500ft clearance
  danger,   // < 200ft clearance
  critical  // Below terrain
}
