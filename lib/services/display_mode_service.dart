import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_colors.dart';

/// Display modes optimized for different flight conditions
enum DisplayMode {
  normal,   // Current dark theme - good for general use
  cockpit,  // High contrast for bright daylight cockpit use
  night,    // Red lighting to preserve night vision
}

/// Service to manage display mode for optimal cockpit visibility
class DisplayModeService extends ChangeNotifier {
  static const String _keyDisplayMode = 'display_mode';
  
  DisplayMode _mode = DisplayMode.normal;
  late SharedPreferences _prefs;
  bool _initialized = false;
  
  DisplayMode get mode => _mode;
  bool get isInitialized => _initialized;
  
  /// Initialize service and load saved preference
  Future<void> init() async {
    if (_initialized) return;
    
    _prefs = await SharedPreferences.getInstance();
    final savedMode = _prefs.getString(_keyDisplayMode);
    
    if (savedMode != null) {
      switch (savedMode) {
        case 'cockpit':
          _mode = DisplayMode.cockpit;
          break;
        case 'night':
          _mode = DisplayMode.night;
          break;
        default:
          _mode = DisplayMode.normal;
      }
    }
    
    _initialized = true;
    notifyListeners();
  }
  
  /// Set display mode and persist preference
  Future<void> setMode(DisplayMode mode) async {
    if (_mode == mode) return;
    
    _mode = mode;
    
    final modeString = mode == DisplayMode.cockpit
        ? 'cockpit'
        : mode == DisplayMode.night
            ? 'night'
            : 'normal';
    
    await _prefs.setString(_keyDisplayMode, modeString);
    notifyListeners();
  }
  
  /// Get theme data for current display mode
  ThemeData getTheme() {
    switch (_mode) {
      case DisplayMode.cockpit:
        return _cockpitTheme;
      case DisplayMode.night:
        return _nightTheme;
      default:
        return _normalTheme;
    }
  }
  
  /// Get text style for critical flight data (altitude, speed, heading)
  TextStyle getCriticalDataStyle() {
    switch (_mode) {
      case DisplayMode.cockpit:
        return const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Color(0xFFFFFFFF),
          letterSpacing: 1.2,
        );
      case DisplayMode.night:
        return const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: Color(0xFFFF0000),
          letterSpacing: 1.2,
        );
      default:
        return const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: Color(0xFFFFFFFF),
        );
    }
  }
  
  /// Get text style for secondary flight data
  TextStyle getSecondaryDataStyle() {
    switch (_mode) {
      case DisplayMode.cockpit:
        return const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFFFFFFFF),
        );
      case DisplayMode.night:
        return const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFFCC0000),
        );
      default:
        return const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w500,
          color: Color(0xFFCCCCCC),
        );
    }
  }
  
  /// Get text style for labels
  TextStyle getLabelStyle() {
    switch (_mode) {
      case DisplayMode.cockpit:
        return const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFFCCCCCC),
          letterSpacing: 0.5,
        );
      case DisplayMode.night:
        return const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF880000),
          letterSpacing: 0.5,
        );
      default:
        return const TextStyle(
          fontSize: 12,
          color: Color(0xFF999999),
        );
    }
  }
  
  /// Normal theme (current dark theme)
  static final ThemeData _normalTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: AppColors.primaryAccent,
    scaffoldBackgroundColor: AppColors.backgroundColor,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryAccent,
      secondary: AppColors.primaryAccent,
      surface: AppColors.sectionBackgroundColor,
      error: AppColors.errorColor,
    ),
  );
  
  /// Cockpit theme - High contrast for daylight visibility
  /// Meets WCAG AAA standards (7:1 contrast ratio)
  static final ThemeData _cockpitTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFFFFFFFF),
    scaffoldBackgroundColor: const Color(0xFF000000),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFFFFFFF),
      secondary: Color(0xFF00FF00),
      surface: Color(0xFF000000),
      error: Color(0xFFFF0000),
      onPrimary: Color(0xFF000000),
      onSecondary: Color(0xFF000000),
      onSurface: Color(0xFFFFFFFF),
      onError: Color(0xFFFFFFFF),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF)),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF)),
      displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFFFFFF)),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFFFFFFFF)),
      bodyLarge: TextStyle(fontSize: 18, color: Color(0xFFFFFFFF)),
      bodyMedium: TextStyle(fontSize: 16, color: Color(0xFFFFFFFF)),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFFCCCCCC)),
    ),
    iconTheme: const IconThemeData(
      color: Color(0xFFFFFFFF),
      size: 28,
    ),
  );
  
  /// Night theme - Red lighting to preserve night vision
  /// Uses wavelengths > 600nm to minimize rhodopsin bleaching
  static final ThemeData _nightTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: const Color(0xFFFF0000),
    scaffoldBackgroundColor: const Color(0xFF000000),
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFFFF0000),
      secondary: Color(0xFFCC0000),
      surface: Color(0xFF000000),
      error: Color(0xFFFF6666),
      onPrimary: Color(0xFF000000),
      onSecondary: Color(0xFF000000),
      onSurface: Color(0xFFFF0000),
      onError: Color(0xFF000000),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFFF0000)),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFFF0000)),
      displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFFF0000)),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFFCC0000)),
      bodyLarge: TextStyle(fontSize: 18, color: Color(0xFFCC0000)),
      bodyMedium: TextStyle(fontSize: 16, color: Color(0xFFCC0000)),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Color(0xFF880000)),
    ),
    iconTheme: const IconThemeData(
      color: Color(0xFFFF0000),
      size: 28,
    ),
  );
  
  /// Get background color for current mode
  Color getBackgroundColor() {
    return const Color(0xFF000000); // Pure black for all modes
  }
  
  /// Get primary text color for current mode
  Color getPrimaryTextColor() {
    switch (_mode) {
      case DisplayMode.cockpit:
        return const Color(0xFFFFFFFF);
      case DisplayMode.night:
        return const Color(0xFFFF0000);
      default:
        return AppColors.primaryTextColor;
    }
  }
  
  /// Get warning color for current mode
  Color getWarningColor() {
    switch (_mode) {
      case DisplayMode.cockpit:
        return const Color(0xFFFFFF00); // Yellow for high visibility
      case DisplayMode.night:
        return const Color(0xFFFF6666); // Light red
      default:
        return AppColors.warningColor;
    }
  }
  
  /// Get critical/error color for current mode
  Color getCriticalColor() {
    return const Color(0xFFFF0000); // Red for all modes (universal danger color)
  }
  
  /// Get success/OK color for current mode
  Color getSuccessColor() {
    switch (_mode) {
      case DisplayMode.cockpit:
        return const Color(0xFF00FF00); // Bright green
      case DisplayMode.night:
        return const Color(0xFFFF0000); // Red (no green in night mode)
      default:
        return AppColors.successColor;
    }
  }
}
