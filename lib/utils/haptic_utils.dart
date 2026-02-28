import 'package:flutter/services.dart';

/// Utility class for consistent haptic feedback throughout the app
class HapticUtils {
  /// Light impact for button taps
  static void lightImpact() {
    HapticFeedback.lightImpact();
  }
  
  /// Medium impact for important actions
  static void mediumImpact() {
    HapticFeedback.mediumImpact();
  }
  
  /// Heavy impact for critical actions
  static void heavyImpact() {
    HapticFeedback.heavyImpact();
  }
  
  /// Selection feedback for toggles and switches
  static void selectionClick() {
    HapticFeedback.selectionClick();
  }
  
  /// Vibrate for warnings
  static void warning() {
    HapticFeedback.vibrate();
  }
  
  /// Success pattern (light-light)
  static Future<void> success() async {
    HapticFeedback.lightImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.lightImpact();
  }
  
  /// Error pattern (heavy-heavy)
  static Future<void> error() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 150));
    HapticFeedback.heavyImpact();
  }
  
  /// Critical alert pattern (heavy-heavy-heavy)
  static Future<void> criticalAlert() async {
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();
    await Future.delayed(const Duration(milliseconds: 100));
    HapticFeedback.heavyImpact();
  }
}
