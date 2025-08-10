import 'package:flutter/material.dart';
import '../constants/app_theme.dart';
import '../l10n/app_localizations.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Add debug print to verify LoadingScreen is being built
    debugPrint('🏗️ Building LoadingScreen...');
    
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App logo with fade animation
              FadeTransition(
                opacity: _fadeAnimation,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: isDarkMode ? const Color(0xFF424242) : const Color(0xFFF5F5F5),
                    borderRadius: AppTheme.extraLargeRadius,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: AppTheme.extraLargeRadius,
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        debugPrint('❌ Failed to load app icon: $error');
                        // Show a placeholder icon if image fails to load
                        return Icon(
                          Icons.flight_takeoff,
                          size: 80,
                          color: isDarkMode ? Colors.white70 : Colors.blue,
                        );
                      },
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 40),
            // App name
            Text(
              'CaptainVFR',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDarkMode ? Colors.white : const Color(0xFF1E88E5),
              ),
            ),
            const SizedBox(height: 20),
            // Loading text
            Text(
              l10n.initializingFlightSystems,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: isDarkMode ? const Color(0x66FFFFFF) : const Color(0x99FFFFFF),
              ),
            ),
            const SizedBox(height: 40),
            // Progress indicator
            SizedBox(
              width: 50,
              height: 50,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDarkMode
                      ? const Color(0xFF90CAF9)
                      : const Color(0xFF1E88E5),
                ),
              ),
            ),
            const SizedBox(height: 80),
            // Aviation-themed tagline
            Text(
              l10n.appTagline,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: isDarkMode ? const Color(0x80FFFFFF) : const Color(0xB3FFFFFF),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      ),
    );
  }
}
