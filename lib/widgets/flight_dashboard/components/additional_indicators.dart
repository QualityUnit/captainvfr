import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:battery_plus/battery_plus.dart';
import 'package:intl/intl.dart';
import '../../../services/flight_service.dart';
import '../../../services/barometer_service.dart';
import '../../../services/settings_service.dart';
import '../../../services/aircraft_settings_service.dart';
import '../../../widgets/themed_dialog.dart';
import 'small_indicator_widget.dart';
import '../../../l10n/app_localizations.dart';

/// Additional indicators showing pressure, QNH, fuel, battery, time, and GPS accuracy
class AdditionalIndicators extends StatefulWidget {
  final FlightService flightService;
  final BarometerService barometerService;

  const AdditionalIndicators({
    super.key,
    required this.flightService,
    required this.barometerService,
  });

  @override
  State<AdditionalIndicators> createState() => _AdditionalIndicatorsState();
}

class _AdditionalIndicatorsState extends State<AdditionalIndicators> {
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  Timer? _updateTimer;
  
  @override
  void initState() {
    super.initState();
    _updateBatteryLevel();
    // Update battery every 30 seconds
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
    // Get current time
    final now = DateTime.now().toUtc();
    final timeFormat = DateFormat('HH:mm');
    final utcTime = timeFormat.format(now);
    final localTime = timeFormat.format(now.toLocal());
    
    // Get GPS accuracy from flight path
    final flightPath = widget.flightService.flightPath;
    final currentPosition = flightPath.isNotEmpty ? flightPath.last : null;
    final accuracy = currentPosition?.accuracy?.toInt() ?? 0;
    
    return Consumer2<SettingsService, AircraftSettingsService>(
      builder: (context, settings, aircraftService, child) {
        // Convert pressure based on user preference
        final pressureValue = widget.flightService.currentPressure;
        final displayPressure = settings.pressureUnit == 'inHg'
            ? pressureValue * 0.02953 // Convert hPa to inHg
            : pressureValue;
        final pressureStr = settings.pressureUnit == 'inHg'
            ? displayPressure.toStringAsFixed(2)
            : displayPressure.toStringAsFixed(0);

        // Convert QNH based on user preference
        final qnhValue = widget.barometerService.seaLevelPressure;
        final displayQNH = settings.pressureUnit == 'inHg'
            ? qnhValue * 0.02953 // Convert hPa to inHg
            : qnhValue;
        final qnhStr = settings.pressureUnit == 'inHg'
            ? displayQNH.toStringAsFixed(2)
            : displayQNH.toStringAsFixed(0);

        // Check if aircraft is selected
        final hasAircraft = aircraftService.selectedAircraft != null;

        return Column(
          children: [
            // First row: Pressure, QNH, Fuel
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: SmallIndicatorWidget(
                    label: 'PRESS',
                    value: '$pressureStr ${settings.pressureUnit}',
                    icon: Icons.compress,
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => _showQNHDialog(context, widget.barometerService, settings),
                    child: SmallIndicatorWidget(
                      label: 'QNH',
                      value: '$qnhStr ${settings.pressureUnit}',
                      icon: Icons.settings_input_antenna,
                    ),
                  ),
                ),
                if (hasAircraft)
                  Expanded(
                    child: SmallIndicatorWidget(
                      label: 'FUEL',
                      value: settings.units == 'metric'
                          ? '${(widget.flightService.fuelUsed * 3.78541).toStringAsFixed(1)} L'
                          : '${widget.flightService.fuelUsed.toStringAsFixed(1)} gal',
                      icon: Icons.local_gas_station,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Second row: Battery, GPS Accuracy, Time
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: SmallIndicatorWidget(
                    label: 'BAT',
                    value: '$_batteryLevel%',
                    icon: _getBatteryIcon(),
                    valueColor: _batteryLevel > 20
                        ? Colors.green
                        : _batteryLevel > 10
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
                Expanded(
                  child: SmallIndicatorWidget(
                    label: 'GPS',
                    value: '${accuracy}m',
                    icon: Icons.gps_fixed,
                    valueColor: accuracy < 10
                        ? Colors.green
                        : accuracy < 30
                            ? Colors.orange
                            : Colors.red,
                  ),
                ),
                Expanded(
                  child: SmallIndicatorWidget(
                    label: 'TIME',
                    value: 'UTC $utcTime\nLOC $localTime',
                    icon: Icons.access_time,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
  
  IconData _getBatteryIcon() {
    if (_batteryLevel > 90) return Icons.battery_full;
    if (_batteryLevel > 70) return Icons.battery_6_bar;
    if (_batteryLevel > 50) return Icons.battery_5_bar;
    if (_batteryLevel > 30) return Icons.battery_3_bar;
    if (_batteryLevel > 10) return Icons.battery_2_bar;
    return Icons.battery_alert;
  }

  void _showQNHDialog(
    BuildContext context,
    BarometerService barometerService,
    SettingsService settings,
  ) {
    final TextEditingController qnhController = TextEditingController();
    final currentQNH = barometerService.seaLevelPressure;
    final displayQNH = settings.pressureUnit == 'inHg'
        ? currentQNH * 0.02953 // Convert hPa to inHg
        : currentQNH;
    qnhController.text = settings.pressureUnit == 'inHg'
        ? displayQNH.toStringAsFixed(2)
        : displayQNH.toStringAsFixed(0);

    ThemedDialog.show(
      context: context,
      title: AppLocalizations.of(context)!.setQnh,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            AppLocalizations.of(context)!.enterQnhValue(settings.pressureUnit),
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: qnhController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.qnhUnitLabel(settings.pressureUnit),
              labelStyle: const TextStyle(color: Colors.white54),
              border: const OutlineInputBorder(),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.blueAccent),
              ),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.white54),
              ),
            ),
            autofocus: true,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(AppLocalizations.of(context)!.cancel),
        ),
        TextButton(
          onPressed: () {
            final qnhText = qnhController.text.trim();
            if (qnhText.isNotEmpty) {
              final qnhValue = double.tryParse(qnhText);
              if (qnhValue != null) {
                // Convert to hPa if needed
                final qnhInHPa = settings.pressureUnit == 'inHg'
                    ? qnhValue / 0.02953 // Convert inHg to hPa
                    : qnhValue;
                barometerService.setSeaLevelPressure(qnhInHPa);
                Navigator.of(context).pop();
              }
            }
          },
          child: Text(AppLocalizations.of(context)!.set),
        ),
      ],
    );
  }
}