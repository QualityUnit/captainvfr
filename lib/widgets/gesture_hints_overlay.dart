import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Gesture hints overlay for first-time users
/// Shows helpful tips on how to interact with the map
class GestureHintsOverlay extends StatefulWidget {
  final VoidCallback onDismiss;
  
  const GestureHintsOverlay({
    super.key,
    required this.onDismiss,
  });
  
  /// Check if hints should be shown (first time only)
  static Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool('gesture_hints_shown') ?? false;
    return !shown;
  }
  
  /// Mark hints as shown
  static Future<void> markAsShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('gesture_hints_shown', true);
  }
  
  @override
  State<GestureHintsOverlay> createState() => _GestureHintsOverlayState();
}

class _GestureHintsOverlayState extends State<GestureHintsOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    _controller.forward();
    
    // Auto-dismiss after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        _dismiss();
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  Future<void> _dismiss() async {
    await _controller.reverse();
    await GestureHintsOverlay.markAsShown();
    widget.onDismiss();
  }
  
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: GestureDetector(
        onTap: _dismiss,
        child: Container(
          color: Colors.black.withValues(alpha: 0.7),
          child: Center(
            child: Container(
              margin: const EdgeInsets.all(32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.touch_app,
                    size: 48,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Map Gestures',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildHint(
                    Icons.pan_tool,
                    'Drag',
                    'Pan the map',
                  ),
                  const SizedBox(height: 12),
                  _buildHint(
                    Icons.zoom_in,
                    'Pinch',
                    'Zoom in/out',
                  ),
                  const SizedBox(height: 12),
                  _buildHint(
                    Icons.touch_app,
                    'Tap',
                    'Select airports, waypoints, airspaces',
                  ),
                  const SizedBox(height: 12),
                  _buildHint(
                    Icons.add_location,
                    'Tap (Planning)',
                    'Add waypoint to flight plan',
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Tap anywhere to dismiss',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  
  Widget _buildHint(IconData icon, String gesture, String description) {
    return Row(
      children: [
        Icon(
          icon,
          size: 24,
          color: Colors.blue.shade700,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                gesture,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                description,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
