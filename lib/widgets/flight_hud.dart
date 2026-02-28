import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import '../services/flight_service.dart';
import '../services/display_mode_service.dart';
import '../services/settings_service.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:intl/intl.dart';

/// Heads-Up Display showing critical flight parameters
/// Optimized for quick glance readability in cockpit
class FlightHUD extends StatefulWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  
  const FlightHUD({
    super.key,
    required this.isExpanded,
    required this.onToggle,
  });
  
  @override
  State<FlightHUD> createState() => _FlightHUDState();
}

class _FlightHUDState extends State<FlightHUD> {
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  Timer? _updateTimer;
  
  @override
  void initState() {
    super.initState();
    _updateBatteryLevel();
    // Update battery every 30 seconds (not every frame for efficiency)
    _updateTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _updateBatteryLevel();
    });
  }
  
  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _updateBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      if (mounted) {
        setState(() {
          _batteryLevel = level;
        });
      }
    } catch (e) {
      // Battery API not available on some platforms
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final flightService = Provider.of<FlightService>(context);
    final displayMode = Provider.of<DisplayModeService>(context);
    final settings = Provider.of<SettingsService>(context);
    
    // Get current position from flight path
    final flightPath = flightService.flightPath;
    final currentPosition = flightPath.isNotEmpty ? flightPath.last : null;
    final isTracking = flightService.isTracking;
    
    return GestureDetector(
      onTap: widget.onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: displayMode.getPrimaryTextColor().withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: widget.isExpanded
            ? _buildExpandedHUD(
                context,
                flightService,
                currentPosition,
                displayMode,
                settings,
                isTracking,
              )
            : _buildCollapsedHUD(
                context,
                flightService,
                currentPosition,
                displayMode,
                isTracking,
              ),
      ),
    );
  }
  
  Widget _buildCollapsedHUD(
    BuildContext context,
    FlightService flightService,
    dynamic currentPosition,
    DisplayModeService displayMode,
    bool isTracking,
  ) {
    final altitude = currentPosition?.altitude?.toInt() ?? 0;
    final speed = flightService.currentSpeed.toInt();
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Altitude
        _buildCompactDataItem(
          'ALT',
          '$altitude',
          'ft',
          displayMode,
          Icons.flight_takeoff,
        ),
        const SizedBox(width: 16),
        // Speed
        _buildCompactDataItem(
          'SPD',
          '$speed',
          'kts',
          displayMode,
          Icons.speed,
        ),
        const SizedBox(width: 8),
        // Expand indicator
        Icon(
          Icons.expand_more,
          color: displayMode.getPrimaryTextColor().withValues(alpha: 0.6),
          size: 20,
        ),
      ],
    );
  }
  
  Widget _buildExpandedHUD(
    BuildContext context,
    FlightService flightService,
    dynamic currentPosition,
    DisplayModeService displayMode,
    SettingsService settings,
    bool isTracking,
  ) {
    final altitude = currentPosition?.altitude?.toInt() ?? 0;
    final speed = flightService.currentSpeed.toInt();
    final heading = (flightService.currentHeading ?? 0).toInt();
    final verticalSpeed = flightService.verticalSpeed.toInt();
    final accuracy = currentPosition?.accuracy?.toInt() ?? 0;
    
    // Calculate AGL if terrain data available (not currently exposed by FlightService)
    final int? agl = null; // TODO: Add AGL calculation when available
    
    // Format time
    final now = DateTime.now().toUtc();
    final timeFormat = DateFormat('HH:mm');
    final utcTime = timeFormat.format(now);
    final localTime = timeFormat.format(now.toLocal());
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top row: Primary flight data
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Altitude
            _buildDataItem(
              'ALTITUDE',
              '$altitude',
              'ft MSL',
              displayMode,
              Icons.flight_takeoff,
              subtitle: agl != null ? '$agl ft AGL' : null,
            ),
            _buildDivider(displayMode),
            // Speed
            _buildDataItem(
              'SPEED',
              '$speed',
              'kts',
              displayMode,
              Icons.speed,
            ),
            _buildDivider(displayMode),
            // Heading
            _buildDataItem(
              'HEADING',
              '$heading°',
              _getCardinalDirection(heading),
              displayMode,
              Icons.explore,
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Middle row: Secondary flight data
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            // Vertical Speed
            _buildSmallDataItem(
              'V/S',
              verticalSpeed >= 0 ? '+$verticalSpeed' : '$verticalSpeed',
              'fpm',
              displayMode,
              verticalSpeed >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
              color: verticalSpeed >= 0
                  ? displayMode.getSuccessColor()
                  : displayMode.getWarningColor(),
            ),
            // GPS Accuracy
            _buildSmallDataItem(
              'GPS',
              '$accuracy',
              'm',
              displayMode,
              Icons.gps_fixed,
              color: accuracy < 10
                  ? displayMode.getSuccessColor()
                  : accuracy < 30
                      ? displayMode.getWarningColor()
                      : displayMode.getCriticalColor(),
            ),
            // Battery
            _buildSmallDataItem(
              'BAT',
              '$_batteryLevel',
              '%',
              displayMode,
              _getBatteryIcon(),
              color: _batteryLevel > 20
                  ? displayMode.getSuccessColor()
                  : _batteryLevel > 10
                      ? displayMode.getWarningColor()
                      : displayMode.getCriticalColor(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Bottom row: Time
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'UTC $utcTime',
              style: displayMode.getLabelStyle(),
            ),
            const SizedBox(width: 16),
            Text(
              'LOCAL $localTime',
              style: displayMode.getLabelStyle(),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // Collapse indicator
        Icon(
          Icons.expand_less,
          color: displayMode.getPrimaryTextColor().withValues(alpha: 0.6),
          size: 20,
        ),
      ],
    );
  }
  
  Widget _buildDataItem(
    String label,
    String value,
    String unit,
    DisplayModeService displayMode,
    IconData icon, {
    String? subtitle,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: displayMode.getPrimaryTextColor().withValues(alpha: 0.7),
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: displayMode.getLabelStyle(),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: displayMode.getCriticalDataStyle(),
        ),
        Text(
          unit,
          style: displayMode.getLabelStyle(),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: displayMode.getLabelStyle().copyWith(fontSize: 11),
          ),
        ],
      ],
    );
  }
  
  Widget _buildCompactDataItem(
    String label,
    String value,
    String unit,
    DisplayModeService displayMode,
    IconData icon,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: displayMode.getPrimaryTextColor().withValues(alpha: 0.7),
          size: 18,
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: displayMode.getLabelStyle().copyWith(fontSize: 10),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  value,
                  style: displayMode.getCriticalDataStyle().copyWith(fontSize: 20),
                ),
                const SizedBox(width: 2),
                Text(
                  unit,
                  style: displayMode.getLabelStyle().copyWith(fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildSmallDataItem(
    String label,
    String value,
    String unit,
    DisplayModeService displayMode,
    IconData icon, {
    Color? color,
  }) {
    final textColor = color ?? displayMode.getPrimaryTextColor();
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: textColor.withValues(alpha: 0.9),
          size: 16,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: displayMode.getLabelStyle().copyWith(fontSize: 10),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              value,
              style: displayMode.getSecondaryDataStyle().copyWith(
                    fontSize: 16,
                    color: textColor,
                  ),
            ),
            const SizedBox(width: 2),
            Text(
              unit,
              style: displayMode.getLabelStyle().copyWith(fontSize: 10),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildDivider(DisplayModeService displayMode) {
    return Container(
      width: 1,
      height: 60,
      color: displayMode.getPrimaryTextColor().withValues(alpha: 0.2),
    );
  }
  
  String _getCardinalDirection(int heading) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((heading + 22.5) / 45).floor() % 8;
    return directions[index];
  }
  
  IconData _getBatteryIcon() {
    if (_batteryLevel > 90) return Icons.battery_full;
    if (_batteryLevel > 70) return Icons.battery_6_bar;
    if (_batteryLevel > 50) return Icons.battery_5_bar;
    if (_batteryLevel > 30) return Icons.battery_3_bar;
    if (_batteryLevel > 10) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }
}
