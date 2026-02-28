import 'package:flutter/material.dart';
import '../models/airport.dart';

/// Utility class for weather-based color coding
/// Provides VFR/MVFR/IFR/LIFR color indicators
class WeatherColorUtils {
  /// Get weather category color based on Airport weather data
  /// 🟢 Green: VFR (> 3000ft ceiling, > 5mi vis)
  /// 🟡 Yellow: MVFR (1000-3000ft, 3-5mi)
  /// 🔴 Red: IFR (500-1000ft, 1-3mi)
  /// ⚫ Black: LIFR (< 500ft, < 1mi)
  static Color getWeatherColor(Airport? airport) {
    if (airport == null || airport.rawMetar == null) {
      return Colors.grey; // No weather data
    }
    
    final category = getWeatherCategory(airport);
    return getCategoryColor(category);
  }
  
  /// Get weather category from Airport
  static WeatherCategory getWeatherCategory(Airport airport) {
    // Use the airport's built-in flight category if available
    final flightCat = airport.flightCategory;
    if (flightCat != null) {
      switch (flightCat.toUpperCase()) {
        case 'VFR':
          return WeatherCategory.vfr;
        case 'MVFR':
          return WeatherCategory.mvfr;
        case 'IFR':
          return WeatherCategory.ifr;
        case 'LIFR':
          return WeatherCategory.lifr;
      }
    }
    
    // Parse ceiling and visibility from raw METAR
    final ceilingFt = _parseCeiling(airport.rawMetar);
    final visibilityMiles = _parseVisibility(airport.rawMetar);
    
    // Determine category based on FAA definitions
    if (ceilingFt != null && ceilingFt < 500 || visibilityMiles != null && visibilityMiles < 1) {
      return WeatherCategory.lifr; // Low IFR
    } else if (ceilingFt != null && ceilingFt < 1000 || visibilityMiles != null && visibilityMiles < 3) {
      return WeatherCategory.ifr; // IFR
    } else if (ceilingFt != null && ceilingFt < 3000 || visibilityMiles != null && visibilityMiles < 5) {
      return WeatherCategory.mvfr; // Marginal VFR
    } else {
      return WeatherCategory.vfr; // VFR
    }
  }
  
  /// Get color for weather category
  static Color getCategoryColor(WeatherCategory category) {
    switch (category) {
      case WeatherCategory.vfr:
        return Colors.green.shade600; // VFR - Green
      case WeatherCategory.mvfr:
        return Colors.yellow.shade700; // MVFR - Yellow
      case WeatherCategory.ifr:
        return Colors.red.shade600; // IFR - Red
      case WeatherCategory.lifr:
        return Colors.black87; // LIFR - Black
      case WeatherCategory.unknown:
        return Colors.grey; // Unknown - Grey
    }
  }
  
  /// Get category name
  static String getCategoryName(WeatherCategory category) {
    switch (category) {
      case WeatherCategory.vfr:
        return 'VFR';
      case WeatherCategory.mvfr:
        return 'MVFR';
      case WeatherCategory.ifr:
        return 'IFR';
      case WeatherCategory.lifr:
        return 'LIFR';
      case WeatherCategory.unknown:
        return 'Unknown';
    }
  }
  
  /// Get category description
  static String getCategoryDescription(WeatherCategory category) {
    switch (category) {
      case WeatherCategory.vfr:
        return 'Visual Flight Rules';
      case WeatherCategory.mvfr:
        return 'Marginal VFR';
      case WeatherCategory.ifr:
        return 'Instrument Flight Rules';
      case WeatherCategory.lifr:
        return 'Low IFR';
      case WeatherCategory.unknown:
        return 'Weather data unavailable';
    }
  }
  
  /// Parse ceiling from raw METAR string
  static double? _parseCeiling(String? rawMetar) {
    if (rawMetar == null) return null;
    
    final raw = rawMetar.toUpperCase();
    
    // Look for cloud layers (BKN, OVC indicate ceiling)
    final cloudPattern = RegExp(r'(BKN|OVC)(\d{3})');
    final matches = cloudPattern.allMatches(raw);
    
    if (matches.isNotEmpty) {
      // Find lowest ceiling
      double? lowestCeiling;
      for (final match in matches) {
        final heightCode = match.group(2);
        if (heightCode != null) {
          final heightFt = int.parse(heightCode) * 100.0; // Height in hundreds of feet
          if (lowestCeiling == null || heightFt < lowestCeiling) {
            lowestCeiling = heightFt;
          }
        }
      }
      return lowestCeiling;
    }
    
    return null; // No ceiling found
  }
  
  /// Parse visibility from raw METAR string
  static double? _parseVisibility(String? rawMetar) {
    if (rawMetar == null) return null;
    
    // Look for visibility in statute miles (e.g., "10SM", "1/2SM", "P6SM")
    final visPattern = RegExp(r'(\d+/?(\d+)?SM|P6SM)');
    final match = visPattern.firstMatch(rawMetar);
    
    if (match != null) {
      final visStr = match.group(1);
      if (visStr != null) {
        if (visStr == 'P6SM') {
          return 10.0; // Greater than 6SM, assume 10SM
        } else if (visStr.contains('/')) {
          // Fractional visibility (e.g., "1/2SM")
          final parts = visStr.replaceAll('SM', '').split('/');
          if (parts.length == 2) {
            final numerator = double.tryParse(parts[0]);
            final denominator = double.tryParse(parts[1]);
            if (numerator != null && denominator != null && denominator != 0) {
              return numerator / denominator;
            }
          }
        } else {
          // Whole number visibility
          final vis = double.tryParse(visStr.replaceAll('SM', ''));
          if (vis != null) return vis;
        }
      }
    }
    
    return null; // No visibility found
  }
}

/// Weather category enum
enum WeatherCategory {
  vfr,    // Visual Flight Rules
  mvfr,   // Marginal VFR
  ifr,    // Instrument Flight Rules
  lifr,   // Low IFR
  unknown // No data
}
