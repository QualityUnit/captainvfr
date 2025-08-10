import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../l10n/app_localizations.dart';

class SimpleLoadingScreen extends StatelessWidget {
  const SimpleLoadingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    debugPrint('🎯 SimpleLoadingScreen build called');
    
    // Use fallback text since localization may not be available yet
    final l10n = AppLocalizations.of(context);
    final initializingText = l10n?.initializing ?? 'Initializing...';
    
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.blue[50],
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Simple icon instead of image asset
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.blue[100],
                    borderRadius: AppTheme.defaultRadius,
                  ),
                  child: const Icon(
                    Icons.flight_takeoff,
                    size: 80,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 40),
                const Text(
                  'CaptainVFR',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  initializingText,
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.blue[700],
                  ),
                ),
                const SizedBox(height: 40),
                const CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}