import 'package:flutter/material.dart';
import '../../models/airport.dart';
import '../../constants/app_colors.dart';
import '../../services/weather_interpretation_service.dart';
import '../common/loading_widget.dart';
import '../common/error_widget.dart' as custom;
import '../../l10n/app_localizations.dart';

class AirportWeatherTab extends StatelessWidget {
  final Airport airport;
  final bool isLoading;
  final String? error;
  final VoidCallback onRetry;
  final WeatherInterpretationService weatherInterpretationService;

  const AirportWeatherTab({
    super.key,
    required this.airport,
    required this.isLoading,
    this.error,
    required this.onRetry,
    required this.weatherInterpretationService,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (isLoading) {
      return LoadingWidget(message: l10n.loadingWeatherData);
    }

    if (error != null) {
      return custom.ErrorWidget(error: error!, onRetry: onRetry);
    }

    // Display weather data if available
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // METAR Section
          if (airport.rawMetar != null) ...[
            _buildMetarSection(context),
            const SizedBox(height: 16),
          ],

          // TAF Section
          if (airport.taf != null) ...[
            _buildTafSection(context),
            const SizedBox(height: 16),
          ],

          // Last updated info
          if (airport.lastWeatherUpdate != null) ...[
            _buildLastUpdatedSection(context),
            const SizedBox(height: 16),
          ],

          // No weather data message
          if (airport.rawMetar == null && airport.taf == null) ...[
            _buildNoDataSection(context),
          ],
        ],
      ),
    );
  }

  Widget _buildMetarSection(BuildContext context) {
    final theme = Theme.of(context);
    final hasDangerousWeather = weatherInterpretationService
        .hasDangerousWeatherInMetar(airport.rawMetar!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'METAR',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: hasDangerousWeather ? Colors.red.shade700 : Colors.green,
              ),
            ),
            if (airport.metarSource == 'safesky') ...[
              const SizedBox(width: 8),
              _buildSafeSkyIndicator(context),
            ],
          ],
        ),
        const SizedBox(height: 8),

        // Human-readable interpretation
        _buildInterpretationCard(
          context,
          interpretation: weatherInterpretationService.interpretMetar(
            airport.rawMetar!,
          ),
          isDangerous: hasDangerousWeather,
          dangerousConditions: hasDangerousWeather
              ? weatherInterpretationService.getDangerousWeatherInMetar(
                  airport.rawMetar!,
                )
              : [],
          color: hasDangerousWeather ? Colors.red.shade700 : Colors.green,
        ),
        const SizedBox(height: 12),

        // Raw METAR data
        _buildRawDataCard(context, 'Raw METAR', airport.rawMetar!),
      ],
    );
  }

  Widget _buildTafSection(BuildContext context) {
    final theme = Theme.of(context);
    final hasDangerousWeather = weatherInterpretationService
        .hasDangerousWeatherInTaf(airport.taf!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'TAF',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: hasDangerousWeather ? Colors.red.shade700 : Colors.blue,
              ),
            ),
            if (airport.tafSource == 'safesky') ...[
              const SizedBox(width: 8),
              _buildSafeSkyIndicator(context),
            ],
          ],
        ),
        const SizedBox(height: 8),

        // Human-readable interpretation
        _buildInterpretationCard(
          context,
          interpretation: weatherInterpretationService.interpretTaf(
            airport.taf!,
          ),
          isDangerous: hasDangerousWeather,
          dangerousConditions: hasDangerousWeather
              ? weatherInterpretationService.getDangerousWeatherInTaf(
                  airport.taf!,
                )
              : [],
          color: hasDangerousWeather ? Colors.red.shade700 : Colors.blue,
        ),
        const SizedBox(height: 12),

        // Raw TAF data
        _buildRawDataCard(context, 'Raw TAF', airport.taf!),
      ],
    );
  }

  Widget _buildInterpretationCard(
    BuildContext context, {
    required String interpretation,
    required bool isDangerous,
    required List<String> dangerousConditions,
    required Color color,
  }) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDangerous ? Colors.red.shade900.withValues(alpha: 0.3) : color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDangerous
              ? Colors.red.shade300
              : color.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isDangerous ? Icons.warning_amber_outlined : Icons.info_outline,
                size: 16,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isDangerous
                      ? 'CAUTION'
                      : 'Interpretation',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            interpretation,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDangerous ? Colors.red.shade200 : AppColors.primaryTextColor,
            ),
          ),
          // Add dangerous weather explanations if present
          if (isDangerous) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Dangerous Conditions ${dangerousConditions.length > 5 ? 'Forecasted:' : 'Detected:'}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            ...dangerousConditions.map(
              (condition) => Padding(
                padding: const EdgeInsets.only(bottom: 4.0),
                child: Text(
                  '• $condition',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.red.shade700,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRawDataCard(BuildContext context, String title, String data) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.sectionBackgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.sectionBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontSize: 13,
              color: AppColors.primaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastUpdatedSection(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Last Updated',
          style: theme.textTheme.labelMedium?.copyWith(color: AppColors.secondaryTextColor),
        ),
        const SizedBox(height: 4),
        Text(
          airport.lastWeatherUpdate!.toLocal().toString().substring(0, 19),
          style: theme.textTheme.bodySmall?.copyWith(color: AppColors.secondaryTextColor),
        ),
      ],
    );
  }

  Widget _buildNoDataSection(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Center(
      child: Column(
        children: [
          Icon(Icons.cloud_off, size: 48, color: AppColors.secondaryTextColor),
          const SizedBox(height: 16),
          Text(
            l10n.noWeatherDataAvailable(airport.icao),
            style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.secondaryTextColor),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            child: Text(l10n.refreshWeather),
          ),
        ],
      ),
    );
  }

  Widget _buildSafeSkyIndicator(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: Colors.orange.withValues(alpha: 0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_sync_outlined,
            size: 12,
            color: Colors.orange.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            'SafeSky',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.orange.shade700,
              fontWeight: FontWeight.bold,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
