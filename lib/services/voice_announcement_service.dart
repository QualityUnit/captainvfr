import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/flight_plan.dart'; // For Waypoint
import '../models/airspace.dart';

/// Service for voice announcements during flight
/// Provides hands-free audio alerts for waypoints, airspaces, terrain, etc.
class VoiceAnnouncementService extends ChangeNotifier {
  final FlutterTts _tts = FlutterTts();
  
  // Settings
  bool _isEnabled = true;
  double _volume = 0.8;
  double _speechRate = 0.5; // 0.0 to 1.0 (slower to faster)
  double _pitch = 1.0; // 0.5 to 2.0
  
  // Announcement tracking to prevent duplicates
  final Set<String> _announcedWaypoints = {};
  final Set<String> _announcedAirspaces = {};
  String? _lastTerrainWarning;
  DateTime? _lastTerrainWarningTime;
  
  // Proximity thresholds (in meters)
  static const double waypointProximityThreshold = 1852.0; // 1 nautical mile
  static const double airspaceProximityThreshold = 9260.0; // 5 nautical miles
  
  // Cooldown periods (to prevent repeated announcements)
  static const Duration terrainWarningCooldown = Duration(seconds: 30);
  
  bool get isEnabled => _isEnabled;
  double get volume => _volume;
  double get speechRate => _speechRate;
  double get pitch => _pitch;
  
  VoiceAnnouncementService() {
    _initializeTTS();
    _loadSettings();
  }
  
  Future<void> _initializeTTS() async {
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(_speechRate);
      await _tts.setVolume(_volume);
      await _tts.setPitch(_pitch);
      
      // Set voice quality
      if (!kIsWeb) {
        await _tts.setVoice({'name': 'en-US-language', 'locale': 'en-US'});
      }
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
    }
  }
  
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isEnabled = prefs.getBool('voice_announcements_enabled') ?? true;
      _volume = prefs.getDouble('voice_volume') ?? 0.8;
      _speechRate = prefs.getDouble('voice_speech_rate') ?? 0.5;
      _pitch = prefs.getDouble('voice_pitch') ?? 1.0;
      
      await _tts.setVolume(_volume);
      await _tts.setSpeechRate(_speechRate);
      await _tts.setPitch(_pitch);
      
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading voice settings: $e');
    }
  }
  
  Future<void> setEnabled(bool enabled) async {
    _isEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('voice_announcements_enabled', enabled);
    notifyListeners();
  }
  
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, 1.0);
    await _tts.setVolume(_volume);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('voice_volume', _volume);
    notifyListeners();
  }
  
  Future<void> setSpeechRate(double rate) async {
    _speechRate = rate.clamp(0.0, 1.0);
    await _tts.setSpeechRate(_speechRate);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('voice_speech_rate', _speechRate);
    notifyListeners();
  }
  
  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.5, 2.0);
    await _tts.setPitch(_pitch);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('voice_pitch', _pitch);
    notifyListeners();
  }
  
  Future<void> _speak(String text) async {
    if (!_isEnabled) return;
    
    try {
      // Stop any current speech
      await _tts.stop();
      // Speak the text
      await _tts.speak(text);
    } catch (e) {
      debugPrint('Error speaking: $e');
    }
  }
  
  /// Announce waypoint proximity
  Future<void> announceWaypointProximity(
    Waypoint waypoint,
    double distanceMeters,
  ) async {
    if (!_isEnabled) return;
    
    // Check if already announced
    final key = '${waypoint.name}_${waypoint.latitude}_${waypoint.longitude}';
    if (_announcedWaypoints.contains(key)) return;
    
    // Check if within proximity threshold
    if (distanceMeters <= waypointProximityThreshold) {
      final distanceNm = (distanceMeters / 1852.0).toStringAsFixed(1);
      final name = waypoint.name ?? 'waypoint';
      await _speak('Approaching $name, $distanceNm nautical miles');
      _announcedWaypoints.add(key);
    }
  }
  
  /// Announce waypoint reached
  Future<void> announceWaypointReached(Waypoint waypoint) async {
    if (!_isEnabled) return;
    
    final name = waypoint.name ?? 'waypoint';
    await _speak('Reached $name');
  }
  
  /// Announce airspace entry
  Future<void> announceAirspaceEntry(Airspace airspace) async {
    if (!_isEnabled) return;
    
    // Check if already announced
    final key = airspace.id;
    if (_announcedAirspaces.contains(key)) return;
    
    final type = airspace.type ?? 'airspace';
    final name = airspace.name;
    await _speak('Entering $type, $name');
    _announcedAirspaces.add(key);
  }
  
  /// Announce airspace proximity
  Future<void> announceAirspaceProximity(
    Airspace airspace,
    double distanceMeters,
  ) async {
    if (!_isEnabled) return;
    
    // Check if already announced
    final key = '${airspace.id}_proximity';
    if (_announcedAirspaces.contains(key)) return;
    
    // Check if within proximity threshold
    if (distanceMeters <= airspaceProximityThreshold) {
      final distanceNm = (distanceMeters / 1852.0).toStringAsFixed(1);
      final type = airspace.type ?? 'airspace';
      final name = airspace.name;
      await _speak('Approaching $type, $name, $distanceNm nautical miles');
      _announcedAirspaces.add(key);
    }
  }
  
  /// Announce terrain warning
  Future<void> announceTerrainWarning(double clearanceFeet) async {
    if (!_isEnabled) return;
    
    // Check cooldown period
    if (_lastTerrainWarningTime != null) {
      final elapsed = DateTime.now().difference(_lastTerrainWarningTime!);
      if (elapsed < terrainWarningCooldown) return;
    }
    
    String message;
    if (clearanceFeet < 200) {
      message = 'PULL UP, PULL UP'; // Critical
    } else if (clearanceFeet < 300) {
      message = 'Terrain, terrain'; // Warning
    } else if (clearanceFeet < 500) {
      message = 'Terrain'; // Caution
    } else {
      return; // No warning needed
    }
    
    // Only announce if message changed or cooldown expired
    if (_lastTerrainWarning != message || 
        _lastTerrainWarningTime == null ||
        DateTime.now().difference(_lastTerrainWarningTime!) > terrainWarningCooldown) {
      await _speak(message);
      _lastTerrainWarning = message;
      _lastTerrainWarningTime = DateTime.now();
    }
  }
  
  /// Announce weather update
  Future<void> announceWeatherUpdate(String airportIcao) async {
    if (!_isEnabled) return;
    await _speak('Weather update available for $airportIcao');
  }
  
  /// Announce fuel reserve
  Future<void> announceFuelReserve() async {
    if (!_isEnabled) return;
    await _speak('Fuel reserve reached');
  }
  
  /// Announce custom message
  Future<void> announce(String message) async {
    if (!_isEnabled) return;
    await _speak(message);
  }
  
  /// Reset announcement tracking (e.g., when starting a new flight)
  void resetTracking() {
    _announcedWaypoints.clear();
    _announcedAirspaces.clear();
    _lastTerrainWarning = null;
    _lastTerrainWarningTime = null;
  }
  
  /// Test voice announcement
  Future<void> testVoice() async {
    await _speak('Voice announcements are working correctly');
  }
  
  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }
}
