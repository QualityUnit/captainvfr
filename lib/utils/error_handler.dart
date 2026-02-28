import 'package:flutter/material.dart';

/// User-friendly error handler with recovery suggestions
class ErrorHandler {
  /// Show user-friendly error message with recovery suggestions
  static void showError(
    BuildContext context,
    String error, {
    String? title,
    String? suggestion,
    VoidCallback? onRetry,
  }) {
    final friendlyMessage = _getFriendlyMessage(error);
    final recoverySuggestion = suggestion ?? _getRecoverySuggestion(error);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title ?? 'Error'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(friendlyMessage),
            if (recoverySuggestion.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Suggestion:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(recoverySuggestion),
            ],
          ],
        ),
        actions: [
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                onRetry();
              },
              child: const Text('Retry'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  /// Show error snackbar for non-critical errors
  static void showSnackbar(
    BuildContext context,
    String error, {
    Duration duration = const Duration(seconds: 4),
  }) {
    final friendlyMessage = _getFriendlyMessage(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(friendlyMessage),
        duration: duration,
        action: SnackBarAction(
          label: 'Dismiss',
          onPressed: () {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
          },
        ),
      ),
    );
  }
  
  /// Convert technical error to user-friendly message
  static String _getFriendlyMessage(String error) {
    final lowerError = error.toLowerCase();
    
    if (lowerError.contains('network') || lowerError.contains('connection')) {
      return 'Unable to connect. Please check your internet connection.';
    }
    
    if (lowerError.contains('permission')) {
      return 'Permission required. Please grant the necessary permissions in Settings.';
    }
    
    if (lowerError.contains('location') || lowerError.contains('gps')) {
      return 'Unable to get your location. Please enable location services.';
    }
    
    if (lowerError.contains('timeout')) {
      return 'Request timed out. Please try again.';
    }
    
    if (lowerError.contains('not found') || lowerError.contains('404')) {
      return 'The requested data could not be found.';
    }
    
    if (lowerError.contains('storage') || lowerError.contains('disk')) {
      return 'Not enough storage space. Please free up some space.';
    }
    
    if (lowerError.contains('format') || lowerError.contains('parse')) {
      return 'Data format error. The data may be corrupted.';
    }
    
    // Return original error if no match found
    return error;
  }
  
  /// Get recovery suggestion based on error type
  static String _getRecoverySuggestion(String error) {
    final lowerError = error.toLowerCase();
    
    if (lowerError.contains('network') || lowerError.contains('connection')) {
      return 'Check your WiFi or cellular connection and try again.';
    }
    
    if (lowerError.contains('permission')) {
      return 'Go to Settings > CaptainVFR > Permissions and enable required permissions.';
    }
    
    if (lowerError.contains('location') || lowerError.contains('gps')) {
      return 'Enable Location Services in your device settings.';
    }
    
    if (lowerError.contains('timeout')) {
      return 'Check your connection speed and try again.';
    }
    
    if (lowerError.contains('storage') || lowerError.contains('disk')) {
      return 'Delete unused files or apps to free up storage space.';
    }
    
    return 'Please try again. If the problem persists, restart the app.';
  }
  
  /// Log error for debugging (in production, this could send to analytics)
  static void logError(String error, {StackTrace? stackTrace}) {
    // In debug mode, print to console
    debugPrint('ERROR: $error');
    if (stackTrace != null) {
      debugPrint('STACK TRACE: $stackTrace');
    }
    
    // In production, this could send to Firebase Crashlytics or similar
  }
}
