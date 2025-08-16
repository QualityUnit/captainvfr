import 'package:flutter/material.dart';

/// Color palette for multi-leg flight plan trips
/// Each leg gets a different color for visual distinction
class TripColors {
  static const List<Color> legColors = [
    Color(0xFF4CAF50), // Green
    Color(0xFF2196F3), // Blue  
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFFF44336), // Red
    Color(0xFF00BCD4), // Cyan
    Color(0xFF8BC34A), // Light Green
    Color(0xFF3F51B5), // Indigo
    Color(0xFFFF5722), // Deep Orange
    Color(0xFFE91E63), // Pink
  ];

  /// Get color for a specific leg number (0-based)
  static Color getColorForLeg(int legNumber) {
    return legColors[legNumber % legColors.length];
  }

  /// Get color value (int) for storage
  static int getColorValueForLeg(int legNumber) {
    final color = getColorForLeg(legNumber);
    // Convert to ARGB format for storage
    int alpha = (color.a * 255).round();
    int red = (color.r * 255).round();
    int green = (color.g * 255).round();
    int blue = (color.b * 255).round();
    return (alpha << 24) | (red << 16) | (green << 8) | blue;
  }

  /// Convert stored color value back to Color
  static Color colorFromValue(int colorValue) {
    return Color(colorValue);
  }

  /// Get a darker shade of the leg color for better contrast
  static Color getDarkerColorForLeg(int legNumber) {
    final color = getColorForLeg(legNumber);
    return Color.lerp(color, Colors.black, 0.2)!;
  }

  /// Get a lighter shade of the leg color
  static Color getLighterColorForLeg(int legNumber) {
    final color = getColorForLeg(legNumber);
    return Color.lerp(color, Colors.white, 0.2)!;
  }

  /// Default color for single flight plans (not part of a trip)
  static const Color defaultFlightPlanColor = Color(0xFF4CAF50); // Green
}