import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../constants/app_colors.dart';
import '../../utils/form_theme_helper.dart';
import '../../l10n/app_localizations.dart';
import 'dart:math' as math;

class WindCorrectionCalculator extends StatefulWidget {
  const WindCorrectionCalculator({super.key});

  @override
  State<WindCorrectionCalculator> createState() =>
      _WindCorrectionCalculatorState();
}

class _WindCorrectionCalculatorState extends State<WindCorrectionCalculator> {
  final _courseController = TextEditingController();
  final _windDirectionController = TextEditingController();
  final _windSpeedController = TextEditingController();
  final _trueAirspeedController = TextEditingController();

  // Results
  double? _windCorrectionAngle;
  double? _groundSpeed;
  double? _headingToFly;
  String? _windType;

  @override
  void dispose() {
    _courseController.dispose();
    _windDirectionController.dispose();
    _windSpeedController.dispose();
    _trueAirspeedController.dispose();
    super.dispose();
  }

  void _calculate() {
    final course = double.tryParse(_courseController.text);
    final windDirection = double.tryParse(_windDirectionController.text);
    final windSpeed = double.tryParse(_windSpeedController.text);
    final trueAirspeed = double.tryParse(_trueAirspeedController.text);

    if (course == null ||
        windDirection == null ||
        windSpeed == null ||
        trueAirspeed == null) {
      return;
    }

    // Convert to radians
    final windDirRad = windDirection * math.pi / 180;

    // Calculate wind angle relative to course
    double windAngle = windDirection - course;
    while (windAngle > 180) {
      windAngle -= 360;
    }
    while (windAngle < -180) {
      windAngle += 360;
    }
    final windAngleRad = windAngle * math.pi / 180;

    // Calculate crosswind component
    final crosswind = windSpeed * math.sin(windAngleRad);

    // Calculate wind correction angle (WCA)
    double wca = 0;
    if (trueAirspeed > 0) {
      wca = math.asin(crosswind / trueAirspeed) * 180 / math.pi;
    }

    // Calculate heading to fly
    double heading = course + wca;
    while (heading >= 360) {
      heading -= 360;
    }
    while (heading < 0) {
      heading += 360;
    }

    // Calculate groundspeed using vector math
    // Wind components in x,y coordinates
    final windX = windSpeed * math.sin(windDirRad);
    final windY = windSpeed * math.cos(windDirRad);

    // Aircraft velocity components (with WCA applied)
    final headingRad = heading * math.pi / 180;
    final aircraftX = trueAirspeed * math.sin(headingRad);
    final aircraftY = trueAirspeed * math.cos(headingRad);

    // Ground velocity components
    final groundX = aircraftX + windX;
    final groundY = aircraftY + windY;

    // Ground speed
    final groundSpeed = math.sqrt(groundX * groundX + groundY * groundY);

    // Determine wind type
    final l10n = AppLocalizations.of(context)!;
    final headwind = windSpeed * math.cos(windAngleRad);
    String windType;
    if (headwind > 5) {
      windType = l10n.headwind;
    } else if (headwind < -5) {
      windType = l10n.tailwind;
    } else if (crosswind.abs() > 5) {
      windType = crosswind > 0 ? l10n.rightCrosswind : l10n.leftCrosswind;
    } else {
      windType = l10n.lightVariable;
    }

    setState(() {
      _windCorrectionAngle = wca;
      _groundSpeed = groundSpeed;
      _headingToFly = heading;
      _windType = windType;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settingsService = context.watch<SettingsService>();
    final isImperial = settingsService.units == 'imperial';
    final speedUnit = isImperial ? 'kts' : 'km/h';
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.dialogBackgroundColor,
        title: Text(
          l10n.windCorrection,
          style: const TextStyle(color: AppColors.primaryTextColor),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryTextColor),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FormThemeHelper.buildSection(
              title: l10n.flightParameters,
              children: [
                FormThemeHelper.buildFormField(
                  controller: _courseController,
                  labelText: l10n.desiredCourse,
                  hintText: l10n.trueCourseToDestination,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 16),
                FormThemeHelper.buildFormField(
                  controller: _trueAirspeedController,
                  labelText: '${l10n.trueAirspeed} ($speedUnit)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FormThemeHelper.buildSection(
              title: l10n.windInformation,
              children: [
                FormThemeHelper.buildFormField(
                  controller: _windDirectionController,
                  labelText: '${l10n.windDirection} (°)',
                  hintText: l10n.windDirectionFromHint,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 16),
                FormThemeHelper.buildFormField(
                  controller: _windSpeedController,
                  labelText: '${l10n.windSpeed} ($speedUnit)',
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _calculate,
              style: FormThemeHelper.getPrimaryButtonStyle().copyWith(
                minimumSize: WidgetStateProperty.all(const Size(double.infinity, 48)),
              ),
              child: Text(l10n.calculate, style: const TextStyle(fontSize: 16)),
            ),
            if (_windCorrectionAngle != null) ...[
              const SizedBox(height: 24),
              Container(
                decoration: FormThemeHelper.getSectionDecoration(),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        l10n.results,
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryTextColor).copyWith(
                          color: AppColors.primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Icon(Icons.explore, size: 40, color: AppColors.primaryAccent),
                              const SizedBox(height: 8),
                              Text(l10n.headingToFly, style: const TextStyle(color: AppColors.primaryTextColor)),
                              Text(
                                '${_headingToFly!.toStringAsFixed(0)}°',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryAccent,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Icon(Icons.rotate_left, size: 40, color: AppColors.primaryAccent),
                              const SizedBox(height: 8),
                              Text(l10n.windCorrection, style: const TextStyle(color: AppColors.primaryTextColor)),
                              Text(
                                '${_windCorrectionAngle! > 0 ? "+" : ""}${_windCorrectionAngle!.toStringAsFixed(1)}°',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryAccent,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Divider(height: 32, color: AppColors.primaryAccent),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Column(
                            children: [
                              Icon(Icons.speed, size: 32, color: AppColors.primaryAccent),
                              const SizedBox(height: 4),
                              Text(l10n.groundSpeed, style: const TextStyle(color: AppColors.primaryTextColor)),
                              Text(
                                '${_groundSpeed!.toStringAsFixed(0)} $speedUnit',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primaryAccent,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            children: [
                              Icon(Icons.air, size: 32, color: AppColors.primaryAccent),
                              const SizedBox(height: 4),
                              Text(l10n.windType, style: const TextStyle(color: AppColors.primaryTextColor)),
                              Text(
                                _windType!,
                                style: TextStyle(fontSize: 16, color: AppColors.primaryTextColor),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.fillColorFaint,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.primaryAccent),
                        ),
                        child: Column(
                          children: [
                            Text(
                              l10n.summary,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryAccent,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'To maintain course ${_courseController.text}°, fly heading ${_headingToFly!.toStringAsFixed(0)}°',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.primaryTextColor),
                            ),
                            if (_windCorrectionAngle!.abs() > 20) ...[
                              const SizedBox(height: 8),
                              const Text(
                                'Large wind correction angle - verify wind data',
                                style: TextStyle(
                                  color: Colors.orange,
                                  fontSize: 12,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
