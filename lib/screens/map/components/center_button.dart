import 'package:flutter/material.dart';
import '../../../constants/app_theme.dart';

class CenterButton extends StatelessWidget {
  final bool positionTrackingEnabled;
  final bool autoCenteringEnabled;
  final int autoCenteringCountdown;
  final VoidCallback onToggle;

  const CenterButton({
    super.key,
    required this.positionTrackingEnabled,
    required this.autoCenteringEnabled,
    required this.autoCenteringCountdown,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final bool showCountdown = positionTrackingEnabled && 
                              !autoCenteringEnabled && 
                              autoCenteringCountdown > 0;
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.9),
            borderRadius: AppTheme.largeRadius,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: IconButton(
            icon: Icon(
              positionTrackingEnabled 
                  ? Icons.my_location 
                  : Icons.location_searching,
              color: positionTrackingEnabled 
                  ? (autoCenteringEnabled 
                      ? Colors.blue 
                      : (showCountdown ? Colors.orange : Colors.white))
                  : Colors.white,
              size: 24,
            ),
            onPressed: onToggle,
            tooltip: positionTrackingEnabled
                ? (autoCenteringEnabled 
                    ? 'Map centering active (tap to disable)'
                    : showCountdown
                        ? 'Auto-centering in ${_formatCountdown(autoCenteringCountdown)}'
                        : 'Map centering paused (tap to disable)')
                : 'Enable map centering',
          ),
        ),
        if (showCountdown)
          Positioned(
            right: -5,
            top: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: AppTheme.extraLargeRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                _formatCountdown(autoCenteringCountdown),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _formatCountdown(int seconds) {
    if (seconds >= 60) {
      final minutes = seconds ~/ 60;
      final remainingSeconds = seconds % 60;
      if (remainingSeconds == 0) {
        return '${minutes}m';
      }
      return '${minutes}m ${remainingSeconds}s';
    }
    return '${seconds}s';
  }
}