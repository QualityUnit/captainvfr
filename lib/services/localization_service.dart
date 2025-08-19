import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'web_locale_helper_stub.dart'
    if (dart.library.html) 'web_locale_helper.dart';

class LocalizationService extends ChangeNotifier {
  static const String _languageKey = 'selected_language';
  static const String _manualSelectionKey = 'manual_language_selection';
  static const MethodChannel _localeChannel = MethodChannel('captainvfr/locale');
  
  // Supported languages
  static const List<Locale> supportedLocales = [
    Locale('en'), // English
    Locale('de'), // German
    Locale('fr'), // French
    Locale('es'), // Spanish
    Locale('it'), // Italian
    Locale('cs'), // Czech
    Locale('sk'), // Slovak
  ];
  
  static const Map<String, String> languageNames = {
    'en': 'English',
    'de': 'Deutsch',
    'fr': 'Français',
    'es': 'Español',
    'it': 'Italiano',
    'cs': 'Čeština',
    'sk': 'Slovenčina',
  };
  
  Locale _currentLocale = const Locale('en');
  bool _isManuallySelected = false;
  
  Locale get currentLocale => _currentLocale;
  
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isManuallySelected = prefs.getBool(_manualSelectionKey) ?? false;
    
    String languageCode;
    
    if (_isManuallySelected) {
      // User has manually selected a language, use it
      languageCode = prefs.getString(_languageKey) ?? 'en';
    } else {
      // Try to auto-detect system language
      languageCode = await _detectSystemLanguage() ?? 'en';
    }
    
    _currentLocale = _getSupportedLocale(languageCode);
    notifyListeners();
  }
  
  Future<void> setLocale(Locale locale) async {
    if (!supportedLocales.contains(locale)) return;
    
    _currentLocale = locale;
    _isManuallySelected = true;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_languageKey, locale.languageCode);
    await prefs.setBool(_manualSelectionKey, true);
    notifyListeners();
  }
  
  String getLanguageName(String languageCode) {
    return languageNames[languageCode] ?? languageCode;
  }
  
  /// Reset to auto-detection mode (clears manual selection)
  Future<void> resetToAutoDetection() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_manualSelectionKey, false);
    _isManuallySelected = false;
    
    // Re-detect system language
    final detectedLanguage = await _detectSystemLanguage() ?? 'en';
    _currentLocale = _getSupportedLocale(detectedLanguage);
    
    await prefs.setString(_languageKey, _currentLocale.languageCode);
    notifyListeners();
  }
  
  /// Check if current language was manually selected
  bool get isManuallySelected => _isManuallySelected;
  
  /// Detect system language from OS settings
  Future<String?> _detectSystemLanguage() async {
    try {
      if (kIsWeb) {
        // For web, use our helper function
        return getWebSystemLanguage();
      } else if (Platform.isAndroid) {
        // For Android, get system locale
        return await _localeChannel.invokeMethod('getSystemLanguage');
      } else if (Platform.isIOS || Platform.isMacOS) {
        // For iOS/macOS, get system locale
        return await _localeChannel.invokeMethod('getSystemLanguage');
      }
    } catch (e) {
      // If platform channel fails, fall back to English
      debugPrint('Failed to detect system language: $e');
    }
    
    return null; // Will fall back to English
  }
  
  /// Get supported locale from language code, fallback to English
  Locale _getSupportedLocale(String languageCode) {
    // Check if we support this language exactly
    final exactMatch = supportedLocales.firstWhere(
      (locale) => locale.languageCode == languageCode,
      orElse: () => const Locale('en'), // fallback to English
    );
    
    return exactMatch;
  }
}