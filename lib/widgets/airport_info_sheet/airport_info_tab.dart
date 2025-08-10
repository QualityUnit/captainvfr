import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../models/airport.dart';
import '../../services/settings_service.dart';
import '../common/info_row.dart';
import '../common/action_button.dart';
import '../utils/url_launcher_utils.dart';

class AirportInfoTab extends StatelessWidget {
  final Airport airport;
  final VoidCallback? onNavigate;

  const AirportInfoTab({super.key, required this.airport, this.onNavigate});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Consumer<SettingsService>(
      builder: (context, settings, child) {
        final isMetric = settings.units == 'metric';
        final elevation = airport.elevation;
        final elevationStr = isMetric
            ? '${(elevation * 0.3048).toStringAsFixed(0)} m'
            : '$elevation ft';

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Information
              InfoRow(label: l10n.icao, value: airport.icao),
              if (airport.iata != null && airport.iata!.isNotEmpty)
                InfoRow(label: l10n.iata, value: airport.iata!),
              InfoRow(label: l10n.name, value: airport.name),
              InfoRow(label: l10n.city, value: airport.city),
              InfoRow(label: l10n.country, value: airport.country),
              InfoRow(
                label: l10n.type,
                value: airport.type.replaceAll('_', ' ').toUpperCase(),
              ),
              InfoRow(label: l10n.elevation, value: elevationStr),
              InfoRow(
                label: l10n.coordinates,
                value:
                    '${airport.position.latitude.toStringAsFixed(6)}, ${airport.position.longitude.toStringAsFixed(6)}',
              ),

              const SizedBox(height: 16),

              // Action Buttons
              if (airport.website != null && airport.website!.isNotEmpty)
                ActionButton(
                  icon: Icons.language,
                  label: l10n.visitWebsite,
                  onPressed: () =>
                      UrlLauncherUtils.launch(context, airport.website!),
                ),

              if (airport.phone != null && airport.phone!.isNotEmpty)
                ActionButton(
                  icon: Icons.phone,
                  label: l10n.callAirport(airport.phone!),
                  onPressed: () =>
                      UrlLauncherUtils.launch(context, 'tel:${airport.phone}'),
                ),

              if (onNavigate != null)
                ActionButton(
                  icon: Icons.navigation,
                  label: l10n.navigateToAirport,
                  onPressed: onNavigate!,
                ),
            ],
          ),
        );
      },
    );
  }
}
