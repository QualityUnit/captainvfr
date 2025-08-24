/// Environment configuration for the app
class Environment {
  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
  
  /// SafeSky API configuration
  static String get safeSkyApiUrl {
    // In production, use production URL
    // For development/testing, can override with environment variable
    const defaultUrl = 'https://imuwdhmbde.execute-api.eu-central-1.amazonaws.com/prod';
    
    // Allow override via environment variable for testing
    return const String.fromEnvironment(
      'SAFESKY_API_URL',
      defaultValue: defaultUrl,
    );
  }
  
  /// Weather service configuration  
  static String get weatherApiUrl => safeSkyApiUrl; // Use same endpoint for weather
  
  /// API timeouts
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration weatherCacheDuration = Duration(minutes: 30);
  static const Duration beaconCacheDuration = Duration(seconds: 5);
  
  /// Rate limiting
  static const Duration apiCooldown = Duration(seconds: 2);
  static const int maxBeaconsToDisplay = 100;
  
  /// Unit conversion constants
  static const double metersToFeet = 3.28084;
  static const double knotsToKmh = 1.852;
  static const double knotsToMph = 1.15078;
  
  /// Collision detection thresholds
  static const double collisionWarningDistanceKm = 5.0;
  static const double collisionWarningAltitudeFt = 1000.0;
  static const double collisionDangerDistanceKm = 2.0;
  static const double collisionDangerAltitudeFt = 500.0;
}