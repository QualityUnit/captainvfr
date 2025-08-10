import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/settings_service.dart';
import '../../constants/app_colors.dart';
import '../../utils/runway_wind_calculator.dart';
import '../../utils/form_theme_helper.dart';
import '../../l10n/app_localizations.dart';

class CrosswindCalculator extends StatefulWidget {
  const CrosswindCalculator({super.key});

  @override
  State<CrosswindCalculator> createState() => _CrosswindCalculatorState();
}

class _CrosswindCalculatorState extends State<CrosswindCalculator> {
  final _runwayHeadingController = TextEditingController();
  final _windDirectionController = TextEditingController();
  final _windSpeedController = TextEditingController();

  double? _headwindComponent;
  double? _crosswindComponent;
  String? _windType;

  @override
  void dispose() {
    _runwayHeadingController.dispose();
    _windDirectionController.dispose();
    _windSpeedController.dispose();
    super.dispose();
  }

  void _calculate() {
    final runwayHeading = double.tryParse(_runwayHeadingController.text);
    final windDirection = double.tryParse(_windDirectionController.text);
    final windSpeed = double.tryParse(_windSpeedController.text);

    if (runwayHeading == null || windDirection == null || windSpeed == null) {
      return;
    }

    try {
      // Use RunwayWindCalculator for consistent calculations
      final windComponent = RunwayWindCalculator.calculateWindComponents(
        runwayHeading,
        windDirection,
        windSpeed,
        'RWY', // Dummy designation for calculator
      );

      setState(() {
        _headwindComponent = windComponent.headwindAbs;
        _crosswindComponent = windComponent.crosswind;
        final l10n = AppLocalizations.of(context)!;
        _windType = windComponent.isHeadwind ? l10n.headwind : l10n.tailwind;
      });
    } catch (e) {
      // Handle validation errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildResultCard() {
    final settingsService = context.read<SettingsService>();
    final isImperial = settingsService.units == 'imperial';
    final speedUnit = isImperial ? 'kts' : 'km/h';
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: FormThemeHelper.getSectionDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              l10n.windComponents,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryTextColor).copyWith(
                color: AppColors.primaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Column(
                  children: [
                    Icon(
                      _windType == l10n.headwind
                          ? Icons.arrow_downward
                          : Icons.arrow_upward,
                      size: 40,
                      color: _windType == l10n.headwind
                          ? Colors.green
                          : Colors.orange,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _windType ?? '',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.primaryTextColor,
                      ),
                    ),
                    Text(
                      '${_headwindComponent!.toStringAsFixed(1)} $speedUnit',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryAccent,
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Icon(
                      Icons.compare_arrows,
                      size: 40,
                      color: _crosswindComponent! > 20
                          ? Colors.red
                          : Colors.blue,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.crosswind,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.primaryTextColor,
                      ),
                    ),
                    Text(
                      '${_crosswindComponent!.toStringAsFixed(1)} $speedUnit',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (_crosswindComponent! > 15) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _crosswindComponent! > 25
                          ? l10n.strongCrosswindWarning
                          : l10n.significantCrosswindWarning,
                      style: const TextStyle(color: Colors.orange),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
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
          l10n.crosswind,
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
              title: l10n.windInformation,
              children: [
                FormThemeHelper.buildFormField(
                  controller: _runwayHeadingController,
                  labelText: l10n.runwayHeading,
                  hintText: l10n.magneticHeadingHint,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 16),
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
            if (_headwindComponent != null && _crosswindComponent != null) ...[
              const SizedBox(height: 24),
              _buildResultCard(),
              const SizedBox(height: 16),
              FormThemeHelper.buildSection(
                title: l10n.quickReference,
                children: [
                  Text('• 15° off runway: ~25% crosswind', style: TextStyle(color: AppColors.primaryTextColor)),
                  Text('• 30° off runway: ~50% crosswind', style: TextStyle(color: AppColors.primaryTextColor)),
                  Text('• 45° off runway: ~70% crosswind', style: TextStyle(color: AppColors.primaryTextColor)),
                  Text('• 60° off runway: ~85% crosswind', style: TextStyle(color: AppColors.primaryTextColor)),
                  Text('• 90° off runway: 100% crosswind', style: TextStyle(color: AppColors.primaryTextColor)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
