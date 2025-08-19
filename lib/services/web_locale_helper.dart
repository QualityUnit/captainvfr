// This file is only imported on web platforms
// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'package:flutter/foundation.dart' show debugPrint;

String? getWebSystemLanguage() {
  try {
    // Get browser language preference using dart:html
    final navigator = html.window.navigator;
    final language = navigator.language;
    
    // Extract just the language code (e.g., "en-US" becomes "en")
    final languageCode = language.split('-')[0];
    debugPrint('🌍 Web System language detected: $languageCode');
    return languageCode;
  } catch (e) {
    debugPrint('Error detecting web language: $e');
    return 'en'; // Fallback to English
  }
}