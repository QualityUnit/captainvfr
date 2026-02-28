// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import '../l10n/app_localizations.dart';
import '../widgets/themed_dialog.dart';
import '../services/settings_service.dart';
import '../services/localization_service.dart';
import '../services/offline_map_service.dart';
import '../services/cache_service.dart';
import '../services/airport_service.dart';
import '../services/navaid_service.dart';
import '../services/weather_service.dart';
import '../services/tiled_data_loader.dart';
import '../services/srtm_elevation_service.dart';
import '../constants/app_theme.dart';
import '../constants/app_colors.dart';
import 'offline_data/controllers/offline_data_state_controller.dart';
import 'offline_data/sections/download_map_tiles_section.dart';
import 'offline_data/dialogs/clear_cache_dialog.dart';
import 'offline_data/helpers/date_formatter.dart';
import 'offline_data/helpers/cache_statistics_helper.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n?.settings ?? 'Settings'),
        backgroundColor: AppColors.dialogBackgroundColor,
        foregroundColor: AppColors.primaryTextColor,
      ),
      backgroundColor: AppColors.backgroundColor,
      body: Consumer2<SettingsService, LocalizationService>(
        builder: (context, settings, localizationService, child) {
          final l10n = AppLocalizations.of(context);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSection(
                title: l10n?.language ?? 'Language',
                children: [
                  ListTile(
                    title: Text(
                      l10n?.language ?? 'Language',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      LocalizationService.languageNames[localizationService.currentLocale.languageCode] ?? 'English',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
                    onTap: () => _showLanguageDialog(context, localizationService),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: l10n?.mapSettings ?? 'Map Settings',
                children: [
                  _buildDropdownTile<MapRotationMode>(
                    title: l10n?.mapRotationMode ?? 'Map Rotation Mode',
                    subtitle: l10n?.mapRotationDescription ?? 'How map and aircraft marker should rotate',
                    value: settings.mapRotationMode,
                    items: {
                      MapRotationMode.none: l10n?.noRotation ?? 'No Rotation',
                      MapRotationMode.mapRotates: l10n?.mapRotates ?? 'Map Rotates',
                      MapRotationMode.aircraftRotates: l10n?.aircraftRotates ?? 'Aircraft Rotates',
                    },
                    descriptions: {
                      MapRotationMode.none: l10n?.noRotationDescription ?? 'Map fixed north-up, aircraft marker fixed',
                      MapRotationMode.mapRotates: l10n?.mapRotatesDescription ?? 'Map rotates with heading, aircraft points north',
                      MapRotationMode.aircraftRotates: l10n?.aircraftRotatesDescription ?? 'Map fixed north-up, aircraft rotates with heading',
                    },
                    onChanged: (value) => settings.setMapRotationMode(value!),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: l10n?.flightTracking ?? 'Flight Tracking',
                children: [
                  _buildSwitchTile(
                    title: l10n?.highPrecisionMode ?? 'High Precision Mode',
                    subtitle: l10n?.highPrecisionDescription ?? 'Use high accuracy GPS (uses more battery)',
                    value: settings.highPrecisionTracking,
                    onChanged: (value) =>
                        settings.setHighPrecisionTracking(value),
                  ),
                  _buildSwitchTile(
                    title: l10n?.autoCreateLogbookEntry ?? 'Auto-create Logbook Entry',
                    subtitle: l10n?.autoCreateLogbookDescription ?? 'Automatically create logbook entry after flight',
                    value: settings.autoCreateLogbookEntry,
                    onChanged: (value) =>
                        settings.setAutoCreateLogbookEntry(value),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: l10n?.unitSettings ?? 'Unit Settings',
                children: [
                  // Legacy unit selector for quick presets
                  ListTile(
                    title: Text(
                      l10n?.quickPresets ?? 'Quick Presets',
                      style: const TextStyle(color: Colors.white),
                    ),
                    subtitle: Text(
                      l10n?.applyCommonUnitCombinations ?? 'Apply common unit combinations',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    trailing: DropdownButton<String>(
                      value: settings.units,
                      dropdownColor: const Color(0xE6000000),
                      style: const TextStyle(color: Colors.white),
                      items: [
                        DropdownMenuItem(
                          value: 'european_aviation',
                          child: Text(l10n?.europeanAviation ?? 'European Aviation'),
                        ),
                        DropdownMenuItem(
                          value: 'us_general_aviation',
                          child: Text(l10n?.usGeneralAviation ?? 'US General Aviation'),
                        ),
                        DropdownMenuItem(
                          value: 'metric_preference',
                          child: Text(l10n?.metricPreference ?? 'Metric Preference'),
                        ),
                        DropdownMenuItem(
                          value: 'mixed_international',
                          child: Text(l10n?.mixedInternational ?? 'Mixed International'),
                        ),
                        DropdownMenuItem(
                          value: 'metric',
                          child: Text(l10n?.legacyMetric ?? 'Legacy Metric'),
                        ),
                        DropdownMenuItem(
                          value: 'imperial',
                          child: Text(l10n?.legacyImperial ?? 'Legacy Imperial'),
                        ),
                      ],
                      onChanged: (value) async {
                        if (value != null) {
                          await _applyUnitPreset(settings, value);
                        }
                      },
                    ),
                  ),
                  const Divider(color: Colors.white24),
                  
                  // Individual unit controls
                  _buildUnitDropdown(
                    l10n?.altitude ?? 'Altitude',
                    settings.altitudeUnit,
                    const ['ft', 'm'],
                    [l10n?.feet ?? 'Feet', l10n?.meters ?? 'Meters'],
                    settings.setAltitudeUnit,
                  ),
                  _buildUnitDropdown(
                    l10n?.distance ?? 'Distance',
                    settings.distanceUnit,
                    const ['nm', 'km', 'mi'],
                    [l10n?.nauticalMiles ?? 'Nautical Miles', l10n?.kilometers ?? 'Kilometers', l10n?.statuteMiles ?? 'Statute Miles'],
                    settings.setDistanceUnit,
                  ),
                  _buildUnitDropdown(
                    l10n?.airspeed ?? 'Airspeed',
                    settings.speedUnit,
                    const ['kt', 'mph', 'km/h'],
                    [l10n?.knots ?? 'Knots', l10n?.milesPerHour ?? 'Miles per Hour', l10n?.kilometersPerHour ?? 'Kilometers per Hour'],
                    settings.setSpeedUnit,
                  ),
                  _buildUnitDropdown(
                    l10n?.windSpeed ?? 'Wind Speed',
                    settings.windUnit,
                    const ['kt', 'mph', 'km/h'],
                    [l10n?.knots ?? 'Knots', l10n?.milesPerHour ?? 'Miles per Hour', l10n?.kilometersPerHour ?? 'Kilometers per Hour'],
                    settings.setWindUnit,
                  ),
                  _buildUnitDropdown(
                    l10n?.temperature ?? 'Temperature',
                    settings.temperatureUnit,
                    const ['C', 'F'],
                    [l10n?.celsius ?? 'Celsius', l10n?.fahrenheit ?? 'Fahrenheit'],
                    settings.setTemperatureUnit,
                  ),
                  _buildUnitDropdown(
                    l10n?.weight ?? 'Weight',
                    settings.weightUnit,
                    const ['lbs', 'kg'],
                    [l10n?.pounds ?? 'Pounds', l10n?.kilograms ?? 'Kilograms'],
                    settings.setWeightUnit,
                  ),
                  _buildUnitDropdown(
                    l10n?.fuel ?? 'Fuel',
                    settings.fuelUnit,
                    const ['gal', 'L'],
                    [l10n?.usGallons ?? 'US Gallons', l10n?.liters ?? 'Liters'],
                    settings.setFuelUnit,
                  ),
                  _buildUnitDropdown(
                    l10n?.pressure ?? 'Pressure',
                    settings.pressureUnit,
                    const ['inHg', 'hPa'],
                    [l10n?.inchesOfMercury ?? 'Inches of Mercury', l10n?.hectopascals ?? 'Hectopascals'],
                    settings.setPressureUnit,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                title: 'Data Sources & Attribution',
                children: [
                  ListTile(
                    leading: const Icon(Icons.terrain, color: Colors.white70),
                    title: const Text(
                      'Terrain Elevation Data',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'SRTM (Shuttle Radar Topography Mission)\n30m precise data + 500m visualization tiles',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    onTap: () => _launchUrl('https://www2.jpl.nasa.gov/srtm/'),
                  ),
                  const Divider(color: Colors.white24),
                  ListTile(
                    leading: const Icon(Icons.map, color: Colors.white70),
                    title: const Text(
                      'Map Data',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      '© OpenStreetMap contributors',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    onTap: () => _launchUrl('https://www.openstreetmap.org/copyright'),
                  ),
                  const Divider(color: Colors.white24),
                  ListTile(
                    leading: const Icon(Icons.flight, color: Colors.white70),
                    title: const Text(
                      'Aviation Data',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'OpenAIP, OurAirports',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    onTap: () => _launchUrl('https://www.openaip.net/'),
                  ),
                  const Divider(color: Colors.white24),
                  ListTile(
                    leading: const Icon(Icons.cloud, color: Colors.white70),
                    title: const Text(
                      'Weather Data',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'CheckWX API, SafeSky',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    onTap: () => _launchUrl('https://www.checkwxapi.com/'),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Center(
                child: ElevatedButton(
                  onPressed: () => _showResetDialog(context, settings),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(l10n?.resetToDefaults ?? 'Reset to Defaults'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0x1A448AFF),
        borderRadius: AppTheme.defaultRadius,
        border: Border.all(color: const Color(0x7F448AFF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          ...children,
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return SwitchListTile(
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70)),
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF448AFF),
    );
  }

  Widget _buildDropdownTile<T>({
    required String title,
    required String subtitle,
    required T value,
    required Map<T, String> items,
    required Map<T, String> descriptions,
    required Function(T?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: Text(title, style: const TextStyle(color: Colors.white)),
          subtitle: Text(subtitle, style: const TextStyle(color: Colors.white70)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFF424242),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF448AFF), width: 1),
            ),
            child: DropdownButton<T>(
              value: value,
              onChanged: onChanged,
              dropdownColor: const Color(0xFF424242),
              style: const TextStyle(color: Colors.white),
              underline: Container(),
              isExpanded: true,
              hint: Text(
                'Select $title',
                style: const TextStyle(color: Colors.white70),
                semanticsLabel: 'Select $title option',
              ),
              items: items.entries.map((entry) {
                return DropdownMenuItem<T>(
                  value: entry.key,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (descriptions.containsKey(entry.key))
                        Text(
                          descriptions[entry.key]!,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showResetDialog(BuildContext context, SettingsService settings) {
    final l10n = AppLocalizations.of(context);
    ThemedDialog.showConfirmation(
      context: context,
      title: l10n?.resetSettings ?? 'Reset Settings',
      message:
          l10n?.confirmResetSettings ?? 'Are you sure you want to reset all settings to their default values?',
      confirmText: l10n?.reset ?? 'Reset',
      cancelText: l10n?.cancel ?? 'Cancel',
      destructive: true,
    ).then((confirmed) {
      if (confirmed == true) {
        settings.resetToDefaults();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n?.settingsResetToDefaults ?? 'Settings reset to defaults'),
              backgroundColor: const Color(0xE6000000),
            ),
          );
        }
      }
    });
  }

  Widget _buildUnitDropdown(
    String title,
    String currentValue,
    List<String> values,
    List<String> displayNames,
    Future<void> Function(String) onChanged,
  ) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(color: Colors.white),
      ),
      trailing: DropdownButton<String>(
        value: currentValue,
        dropdownColor: const Color(0xE6000000),
        style: const TextStyle(color: Colors.white),
        hint: Text(
          'Select unit for $title',
          semanticsLabel: 'Select unit for $title',
        ),
        items: values.asMap().entries.map((entry) {
          final index = entry.key;
          final value = entry.value;
          return DropdownMenuItem(
            value: value,
            child: Text(displayNames[index]),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            onChanged(value);
          }
        },
      ),
    );
  }

  /// Apply unit preset combinations to reduce code duplication
  static Future<void> _applyUnitPreset(SettingsService settings, String preset) async {
    await settings.setUnits(preset);
    
    switch (preset) {
      case 'european_aviation':
        await settings.setAltitudeUnit('ft');
        await settings.setDistanceUnit('km');
        await settings.setSpeedUnit('kt');
        await settings.setTemperatureUnit('C');
        await settings.setWeightUnit('kg');
        await settings.setFuelUnit('L');
        await settings.setWindUnit('kt');
        await settings.setPressureUnit('hPa');
        break;
      case 'us_general_aviation':
        await settings.setAltitudeUnit('ft');
        await settings.setDistanceUnit('nm');
        await settings.setSpeedUnit('kt');
        await settings.setTemperatureUnit('F');
        await settings.setWeightUnit('lbs');
        await settings.setFuelUnit('gal');
        await settings.setWindUnit('kt');
        await settings.setPressureUnit('inHg');
        break;
      case 'metric_preference':
        await settings.setAltitudeUnit('m');
        await settings.setDistanceUnit('km');
        await settings.setSpeedUnit('km/h');
        await settings.setTemperatureUnit('C');
        await settings.setWeightUnit('kg');
        await settings.setFuelUnit('L');
        await settings.setWindUnit('km/h');
        await settings.setPressureUnit('hPa');
        break;
      case 'mixed_international':
        await settings.setAltitudeUnit('ft');
        await settings.setDistanceUnit('nm');
        await settings.setSpeedUnit('kt');
        await settings.setTemperatureUnit('C');
        await settings.setWeightUnit('kg');
        await settings.setFuelUnit('L');
        await settings.setWindUnit('kt');
        await settings.setPressureUnit('hPa');
        break;
      case 'metric':
        await settings.setAltitudeUnit('m');
        await settings.setDistanceUnit('km');
        await settings.setSpeedUnit('km/h');
        await settings.setTemperatureUnit('C');
        await settings.setWeightUnit('kg');
        await settings.setFuelUnit('L');
        await settings.setWindUnit('km/h');
        await settings.setPressureUnit('hPa');
        break;
      case 'imperial':
        await settings.setAltitudeUnit('ft');
        await settings.setDistanceUnit('nm');
        await settings.setSpeedUnit('kt');
        await settings.setTemperatureUnit('C');
        await settings.setWeightUnit('lbs');
        await settings.setFuelUnit('gal');
        await settings.setWindUnit('kt');
        await settings.setPressureUnit('inHg');
        break;
    }
  }
  
  void _showLanguageDialog(BuildContext context, LocalizationService localizationService) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ThemedDialog(
          title: l10n?.selectLanguage ?? 'Select Language',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: LocalizationService.supportedLocales.map((locale) {
              final languageName = LocalizationService.languageNames[locale.languageCode];
              final isSelected = locale.languageCode == localizationService.currentLocale.languageCode;
              
              return ListTile(
                title: Text(
                  languageName ?? locale.languageCode,
                  style: TextStyle(
                    color: isSelected ? AppColors.primaryAccent : AppColors.primaryTextColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected 
                  ? const Icon(Icons.check, color: AppColors.primaryAccent)
                  : null,
                onTap: () async {
                  await localizationService.setLocale(locale);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n?.cancel ?? 'Cancel'),
            ),
          ],
        );
      },
    );
  }
}

/// Settings dialog that can be shown as a modal
class SettingsDialog extends StatefulWidget {
  final LatLngBounds? currentMapBounds;
  
  const SettingsDialog({
    super.key,
    this.currentMapBounds,
  });

  static Future<void> show(BuildContext context, {LatLngBounds? currentMapBounds}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.87),
      builder: (BuildContext context) {
        return SettingsDialog(currentMapBounds: currentMapBounds);
      },
    );
  }

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final OfflineMapService _offlineMapService = OfflineMapService();
  final CacheService _cacheService = CacheService();
  final AirportService _airportService = AirportService();
  final NavaidService _navaidService = NavaidService();
  final WeatherService _weatherService = WeatherService();
  final TiledDataLoader _tiledDataLoader = TiledDataLoader();
  final OfflineDataStateController _stateController = OfflineDataStateController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadAllCacheStats();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _loadAllCacheStats() async {
    _stateController.setLoading(true);

    try {
      await _cacheService.initialize();
      await _weatherService.initialize();
      await _offlineMapService.initialize();

      final mapStats = await _offlineMapService.getCacheStatistics();
      final stats = await CacheStatisticsHelper.getCacheStatistics(_weatherService);
      
      // Get SRTM elevation cache statistics
      final elevationCacheSize = await SrtmElevationService.getCacheSize();
      final elevationFileCount = await SrtmElevationService.getCacheFileCount();
      
      // Add elevation stats to the cache statistics
      stats['elevation'] = {
        'count': elevationFileCount,
        'sizeBytes': elevationCacheSize,
        'lastFetch': null, // SRTM data is downloaded on demand
      };

      _stateController.setMapCacheStats(mapStats);
      _stateController.setCacheStats(stats);
      _stateController.setLoading(false);
    } catch (e) {
      _stateController.setLoading(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.errorLoadingCacheStats(e.toString()) ?? 'Error loading cache stats: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isLandscape = screenSize.width > screenSize.height;
    
    final responsiveWidth = isLandscape ? 
      (screenSize.width * 0.9).clamp(600.0, 900.0) :
      (screenSize.width * 0.9).clamp(350.0, 600.0);
    
    final responsiveHeight = screenSize.height * 0.8;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: responsiveWidth,
        height: responsiveHeight,
        decoration: BoxDecoration(
          color: AppColors.dialogBackgroundColor,
          borderRadius: AppTheme.dialogRadius,
          border: Border.all(
            color: AppColors.primaryAccentDim,
            width: 1.0,
          ),
        ),
        child: Column(
          children: [
            // Header with tabs
            Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: AppColors.primaryAccentFaint,
                    width: 1.0,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.primaryAccent,
                      labelColor: AppColors.primaryAccent,
                      unselectedLabelColor: AppColors.secondaryTextColor,
                      tabs: [
                        Tab(
                          child: Text(
                            AppLocalizations.of(context)?.settings ?? 'Settings',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Tab(
                          child: Text(
                            AppLocalizations.of(context)?.offlineData ?? 'Offline Data',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.primaryTextColor),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Settings Tab
                  _buildSettingsTab(),
                  // Offline Data Tab
                  _buildOfflineDataTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTab() {
    return Consumer2<SettingsService, LocalizationService>(
      builder: (context, settings, localizationService, child) {
        final l10n = AppLocalizations.of(context);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildCompactSection(
                title: l10n?.language ?? 'Language',
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            LocalizationService.languageNames[localizationService.currentLocale.languageCode] ?? 'English',
                            style: const TextStyle(color: Colors.white70, fontSize: 11),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.language, size: 18),
                          onPressed: () => _showLanguageDialog(context, localizationService),
                          color: const Color(0xFF448AFF),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(maxHeight: 24, maxWidth: 24),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildCompactSection(
                title: l10n?.map ?? 'Map',
                children: [
                  _buildCompactSwitch(
                    l10n?.rotateWithHeading ?? 'Rotate with heading',
                    settings.rotateMapWithHeading,
                    (value) => settings.setRotateMapWithHeading(value),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildCompactSection(
                title: l10n?.tracking ?? 'Tracking',
                children: [
                  _buildCompactSwitch(
                    l10n?.highPrecisionGps ?? 'High precision GPS',
                    settings.highPrecisionTracking,
                    (value) => settings.setHighPrecisionTracking(value),
                  ),
                  _buildCompactSwitch(
                    l10n?.autoCreateLogbook ?? 'Auto-create logbook',
                    settings.autoCreateLogbookEntry,
                    (value) => settings.setAutoCreateLogbookEntry(value),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildCompactSection(
                title: l10n?.units ?? 'Units',
                children: [
                  // Quick Presets
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          l10n?.presets ?? 'Presets',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        SizedBox(
                          height: 28,
                          child: DropdownButton<String>(
                            value: settings.units,
                            dropdownColor: const Color(0xE6000000),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                            ),
                            isDense: true,
                            items: [
                              DropdownMenuItem(
                                value: 'european_aviation',
                                child: Text(l10n?.europeanAviation ?? 'European Aviation'),
                              ),
                              DropdownMenuItem(
                                value: 'us_general_aviation',
                                child: Text(l10n?.usGeneralAviation ?? 'US General Aviation'),
                              ),
                              DropdownMenuItem(
                                value: 'metric_preference',
                                child: Text(l10n?.metricPreference ?? 'Metric Preference'),
                              ),
                              DropdownMenuItem(
                                value: 'mixed_international',
                                child: Text(l10n?.mixedInternational ?? 'Mixed International'),
                              ),
                              DropdownMenuItem(
                                value: 'metric',
                                child: Text(l10n?.legacyMetric ?? 'Legacy Metric'),
                              ),
                              DropdownMenuItem(
                                value: 'imperial',
                                child: Text(l10n?.legacyImperial ?? 'Legacy Imperial'),
                              ),
                            ],
                            onChanged: (value) async {
                              if (value != null) {
                                await _applyUnitPreset(settings, value);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Individual unit controls
                  _buildCompactUnitDropdown('Altitude', settings.altitudeUnit, 
                    ['ft', 'm'], settings.setAltitudeUnit),
                  _buildCompactUnitDropdown('Distance', settings.distanceUnit, 
                    ['nm', 'km', 'mi'], settings.setDistanceUnit),
                  _buildCompactUnitDropdown('Speed', settings.speedUnit, 
                    ['kt', 'mph', 'km/h'], settings.setSpeedUnit),
                  _buildCompactUnitDropdown('Wind', settings.windUnit, 
                    ['kt', 'mph', 'km/h'], settings.setWindUnit),
                  _buildCompactUnitDropdown('Temperature', settings.temperatureUnit, 
                    ['C', 'F'], settings.setTemperatureUnit),
                  _buildCompactUnitDropdown('Weight', settings.weightUnit, 
                    ['lbs', 'kg'], settings.setWeightUnit),
                  _buildCompactUnitDropdown('Fuel', settings.fuelUnit, 
                    ['gal', 'L'], settings.setFuelUnit),
                  _buildCompactUnitDropdown('Pressure', settings.pressureUnit, 
                    ['inHg', 'hPa'], settings.setPressureUnit),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOfflineDataTab() {
    return ListenableBuilder(
      listenable: _stateController,
      builder: (context, child) {
        if (_stateController.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Aviation Data Caches Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)?.aviationDataCaches ?? 'Aviation Data Caches',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryTextColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: _stateController.isRefreshing ? null : _refreshAllData,
                        tooltip: AppLocalizations.of(context)?.refreshAllData ?? 'Refresh all data',
                        color: AppColors.primaryAccent,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(maxHeight: 32, maxWidth: 32),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_forever, size: 20),
                        onPressed: _clearAllCaches,
                        tooltip: AppLocalizations.of(context)?.clearAllCaches ?? 'Clear all caches',
                        color: Colors.red,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(maxHeight: 32, maxWidth: 32),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Cache cards in a more compact format
              _buildCompactCacheCard(
                title: 'Airports',
                icon: Icons.flight_land,
                count: _stateController.cacheStats['airports']?['count'] ?? 0,
                lastFetch: DateFormatter.formatLastFetch(_stateController.cacheStats['airports']?['lastFetch']),
                onClear: () => _clearSpecificCache('Airports'),
              ),
              _buildCompactCacheCard(
                title: 'Navigation Aids',
                icon: Icons.radar,
                count: _stateController.cacheStats['navaids']?['count'] ?? 0,
                lastFetch: DateFormatter.formatLastFetch(_stateController.cacheStats['navaids']?['lastFetch']),
                onClear: () => _clearSpecificCache('Navaids'),
              ),
              _buildCompactCacheCard(
                title: 'Runways',
                icon: Icons.horizontal_rule,
                count: _stateController.cacheStats['runways']?['count'] ?? 0,
                lastFetch: DateFormatter.formatLastFetch(_stateController.cacheStats['runways']?['lastFetch']),
                onClear: () => _clearSpecificCache('Runways'),
              ),
              _buildCompactCacheCard(
                title: 'Frequencies',
                icon: Icons.radio,
                count: _stateController.cacheStats['frequencies']?['count'] ?? 0,
                lastFetch: DateFormatter.formatLastFetch(_stateController.cacheStats['frequencies']?['lastFetch']),
                onClear: () => _clearSpecificCache('Frequencies'),
              ),
              _buildCompactCacheCard(
                title: 'Airspaces',
                icon: Icons.layers,
                count: _stateController.cacheStats['airspaces']?['count'] ?? 0,
                lastFetch: DateFormatter.formatLastFetch(_stateController.cacheStats['airspaces']?['lastFetch']),
                onClear: () => _clearSpecificCache('Airspaces'),
              ),
              _buildCompactCacheCard(
                title: 'Reporting Points',
                icon: Icons.location_on,
                count: _stateController.cacheStats['reportingPoints']?['count'] ?? 0,
                lastFetch: DateFormatter.formatLastFetch(_stateController.cacheStats['reportingPoints']?['lastFetch']),
                onClear: () => _clearSpecificCache('Reporting Points'),
              ),
              _buildCompactCacheCard(
                title: 'Obstacles',
                icon: Icons.warning,
                count: _stateController.cacheStats['obstacles']?['count'] ?? 0,
                lastFetch: DateFormatter.formatLastFetch(_stateController.cacheStats['obstacles']?['lastFetch']),
                onClear: () => _clearSpecificCache('Obstacles'),
              ),
              _buildCompactCacheCard(
                title: 'Hotspots',
                icon: Icons.local_fire_department,
                count: _stateController.cacheStats['hotspots']?['count'] ?? 0,
                lastFetch: DateFormatter.formatLastFetch(_stateController.cacheStats['hotspots']?['lastFetch']),
                onClear: () => _clearSpecificCache('Hotspots'),
              ),
              _buildCompactCacheCard(
                title: 'Weather',
                icon: Icons.cloud,
                count: (_stateController.cacheStats['weather']?['metars'] ?? 0) + 
                       (_stateController.cacheStats['weather']?['tafs'] ?? 0),
                lastFetch: DateFormatter.formatLastFetch(_stateController.cacheStats['weather']?['lastFetch']),
                onClear: () => _clearSpecificCache('Weather'),
                onRefresh: _refreshWeatherData,
              ),
              FutureBuilder<Map<String, dynamic>>(
                future: _getElevationCacheStats(),
                builder: (context, snapshot) {
                  final stats = snapshot.data ?? {};
                  final total30m = stats['cache_30m'] ?? 0;
                  final total500m = stats['cache_500m'] ?? 0;
                  final totalFiles = stats['total_files'] ?? (total30m + total500m);
                  final cacheSize = stats['cache_size'] ?? 0;
                  
                  String subtitle = 'Downloaded on demand';
                  if (totalFiles > 0) {
                    final sizeInGB = (cacheSize / 1024 / 1024 / 1024).toStringAsFixed(2);
                    subtitle = '$total30m precise, $total500m visual • ${sizeInGB}GB';
                  }
                  
                  return _buildCompactCacheCard(
                    title: 'Elevation Data',
                    icon: Icons.terrain,
                    count: totalFiles,
                    lastFetch: subtitle,
                    onClear: () => _clearSpecificCache('Elevation'),
                  );
                },
              ),

              const SizedBox(height: 16),

              // Offline Map Tiles Section
              Text(
                AppLocalizations.of(context)?.offlineMapTiles ?? 'Offline Map Tiles',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),

              // Map tiles cache card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0x1A448AFF),
                  borderRadius: AppTheme.defaultRadius,
                  border: Border.all(color: AppColors.primaryAccentFaint),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.map, color: AppColors.primaryAccent, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Map Tiles: ${(_stateController.mapCacheStats?['totalTiles'] as int?) ?? 0}',
                                style: const TextStyle(
                                  color: AppColors.primaryTextColor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _formatFileSize((_stateController.mapCacheStats?['totalSizeBytes'] as int?) ?? 0),
                                style: const TextStyle(
                                  color: AppColors.secondaryTextColor,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 18),
                          onPressed: () => _clearSpecificCache('Map Tiles'),
                          color: Colors.red,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(maxHeight: 28, maxWidth: 28),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Download controls
                    DownloadMapTilesSection(
                      controller: _stateController,
                      onDownload: _downloadCurrentArea,
                      onStopDownload: _stopDownload,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactCacheCard({
    required String title,
    required IconData icon,
    required int count,
    required String lastFetch,
    required VoidCallback onClear,
    VoidCallback? onRefresh,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0x1A448AFF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primaryAccentFaint),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primaryAccent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title: $count',
                  style: const TextStyle(
                    color: AppColors.primaryTextColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  lastFetch,
                  style: const TextStyle(
                    color: AppColors.secondaryTextColor,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
          if (onRefresh != null)
            IconButton(
              icon: const Icon(Icons.refresh, size: 16),
              onPressed: _stateController.isRefreshing ? null : onRefresh,
              color: AppColors.primaryAccent,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(maxHeight: 24, maxWidth: 24),
            ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 16),
            onPressed: onClear,
            color: Colors.red,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(maxHeight: 24, maxWidth: 24),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unitIndex = 0;
    
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    
    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  Future<void> _refreshAllData() async {
    if (!mounted) return;
    
    _stateController.setRefreshing(true);

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(AppLocalizations.of(context)?.refreshingAllAviationData ?? 'Refreshing all aviation data...')),
              ],
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }

      final futures = [
        _airportService.refreshData(),
        _navaidService.refreshData(),
        _weatherService.forceReload(),
      ];

      await Future.wait(futures);
      
      if (mounted) {
        await _loadAllCacheStats();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.allDataRefreshedSuccessfully ?? 'All data refreshed successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.errorRefreshingData(e.toString()) ?? 'Error refreshing data: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        _stateController.setRefreshing(false);
      }
    }
  }

  Future<void> _refreshWeatherData() async {
    if (!mounted) return;
    
    _stateController.setRefreshing(true);

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(AppLocalizations.of(context)?.refreshingWeatherData ?? 'Refreshing weather data...')),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      await _weatherService.forceReload();
      
      if (mounted) {
        await _loadAllCacheStats();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.weatherDataRefreshedSuccessfully ?? 'Weather data refreshed successfully'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.errorRefreshingWeatherData(e.toString()) ?? 'Error refreshing weather data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        _stateController.setRefreshing(false);
      }
    }
  }

  Future<void> _clearSpecificCache(String cacheName) async {
    final confirm = await ClearCacheDialog.show(
      context: context,
      cacheName: cacheName,
    );

    if (confirm == true) {
      try {
        switch (cacheName) {
          case 'Airports':
            await _cacheService.clearAirportsCache();
            break;
          case 'Navaids':
            await _cacheService.clearNavaidsCache();
            break;
          case 'Runways':
            await _cacheService.clearRunwaysCache();
            break;
          case 'Frequencies':
            await _cacheService.clearFrequenciesCache();
            break;
          case 'Airspaces':
            await _cacheService.clearAirspacesCache();
            break;
          case 'Reporting Points':
            await _cacheService.clearReportingPointsCache();
            break;
          case 'Weather':
            await _cacheService.clearWeatherCache();
            break;
          case 'Map Tiles':
            await _offlineMapService.clearCache();
            break;
          case 'Obstacles':
            _tiledDataLoader.clearCacheForType('obstacles');
            break;
          case 'Hotspots':
            _tiledDataLoader.clearCacheForType('hotspots');
            break;
          case 'Elevation':
            await SrtmElevationService.clearCacheStatic();
            break;
        }
        await _loadAllCacheStats();
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.clearedCache(cacheName)),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorClearingCache(cacheName, e.toString()))),
          );
        }
      }
    }
  }

  Future<void> _clearAllCaches() async {
    final confirm = await ClearCacheDialog.show(
      context: context,
      cacheName: '',
      isAllCaches: true,
    );

    if (confirm == true) {
      try {
        await Future.wait([
          _cacheService.clearAllCaches(),
          _offlineMapService.clearCache(),
        ]);
        // Clear tiled data caches
        _tiledDataLoader.clearCache();
        await _loadAllCacheStats();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)?.allCachesClearedSuccessfully ?? 'All caches cleared successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)?.errorClearingCaches(e.toString()) ?? 'Error clearing caches: $e')),
          );
        }
      }
    }
  }

  Future<void> _downloadCurrentArea() async {
    if (widget.currentMapBounds == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)?.pleaseOpenFromMapToDownload ?? 'Please open this screen from the map to download the current area'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    await _downloadArea(
      northEast: widget.currentMapBounds!.northEast,
      southWest: widget.currentMapBounds!.southWest,
    );
  }

  Future<void> _downloadArea({
    required LatLng northEast,
    required LatLng southWest,
  }) async {
    if (!mounted) return;
    
    _stateController.setDownloading(true);
    _stateController.resetDownloadState();

    try {
      await _offlineMapService.downloadAreaTiles(
        bounds: LatLngBounds(northEast, southWest),
        minZoom: _stateController.minZoom,
        maxZoom: _stateController.maxZoom,
        onProgress: (current, total, skipped, downloaded) {
          if (!mounted) return;
          _stateController.updateDownloadProgress(current, total, skipped, downloaded);
          
          if (current % 25 == 0 || current == total) {
            if (mounted) {
              _loadAllCacheStats();
            }
          }
        },
      );

      if (mounted) {
        final message = _stateController.skippedTiles > 0
            ? 'Downloaded ${_stateController.downloadedTiles} new tiles, skipped ${_stateController.skippedTiles} cached tiles'
            : 'Downloaded ${_stateController.downloadedTiles} tiles successfully!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final isUserCancelled = e.toString().contains('cancelled by user');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUserCancelled ? 'Download cancelled' : 'Download failed: $e',
            ),
            backgroundColor: isUserCancelled ? Colors.orange : Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        _stateController.resetDownloadState();
        await _loadAllCacheStats();
      }
    }
  }

  void _stopDownload() {
    if (!mounted) return;
    _offlineMapService.cancelDownload();
  }

  /// Get SRTM elevation cache statistics
  Future<Map<String, dynamic>> _getElevationCacheStats() async {
    try {
      // Get actual file counts from disk
      final fileCount = await SrtmElevationService.getCacheFileCount();
      final cacheSize = await SrtmElevationService.getCacheSize();
      
      // Count 30m and 500m files separately if possible
      final appDir = await getApplicationDocumentsDirectory();
      final cacheDir = Directory(path.join(appDir.path, 'srtm_cache'));
      int count30m = 0;
      int count500m = 0;
      
      if (await cacheDir.exists()) {
        // Count 30m files
        final dir30m = Directory(path.join(cacheDir.path, '30m'));
        if (await dir30m.exists()) {
          await for (final file in dir30m.list(recursive: true)) {
            if (file is File && (file.path.endsWith('.hgt') || file.path.endsWith('.tif'))) {
              count30m++;
            }
          }
        }
        
        // Count 500m files
        final dir500m = Directory(path.join(cacheDir.path, '500m'));
        if (await dir500m.exists()) {
          await for (final file in dir500m.list(recursive: true)) {
            if (file is File && file.path.endsWith('.hgt')) {
              count500m++;
            }
          }
        }
      }
      
      return {
        'cache_30m': count30m,
        'cache_500m': count500m,
        'total_files': fileCount,
        'cache_size': cacheSize,
      };
    } catch (e) {
      debugPrint('Error getting SRTM cache stats: $e');
      return {};
    }
  }

  static Widget _buildCompactSection({
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Color(0xFF448AFF),
          ),
        ),
        const SizedBox(height: 4),
        ...children,
      ],
    );
  }

  static Widget _buildCompactSwitch(
    String label,
    bool value,
    Function(bool) onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ),
        Transform.scale(
          scale: 0.75,
          child: Switch(
            value: value,
            onChanged: onChanged,
            activeColor: const Color(0xFF448AFF),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  static Widget _buildCompactUnitDropdown(
    String label,
    String currentValue,
    List<String> values,
    Future<void> Function(String) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 28,
            child: DropdownButton<String>(
              value: currentValue,
              dropdownColor: const Color(0xE6000000),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
              ),
              isDense: true,
              hint: Text(
                'Select unit for $label',
                semanticsLabel: 'Select unit for $label',
                style: const TextStyle(fontSize: 11),
              ),
              items: values.map((value) {
                return DropdownMenuItem(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  onChanged(value);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Apply unit preset combinations to reduce code duplication
  static Future<void> _applyUnitPreset(SettingsService settings, String preset) async {
    await settings.setUnits(preset);
    
    switch (preset) {
      case 'european_aviation':
        await settings.setAltitudeUnit('ft');
        await settings.setDistanceUnit('km');
        await settings.setSpeedUnit('kt');
        await settings.setTemperatureUnit('C');
        await settings.setWeightUnit('kg');
        await settings.setFuelUnit('L');
        await settings.setWindUnit('kt');
        await settings.setPressureUnit('hPa');
        break;
      case 'us_general_aviation':
        await settings.setAltitudeUnit('ft');
        await settings.setDistanceUnit('nm');
        await settings.setSpeedUnit('kt');
        await settings.setTemperatureUnit('F');
        await settings.setWeightUnit('lbs');
        await settings.setFuelUnit('gal');
        await settings.setWindUnit('kt');
        await settings.setPressureUnit('inHg');
        break;
      case 'metric_preference':
        await settings.setAltitudeUnit('m');
        await settings.setDistanceUnit('km');
        await settings.setSpeedUnit('km/h');
        await settings.setTemperatureUnit('C');
        await settings.setWeightUnit('kg');
        await settings.setFuelUnit('L');
        await settings.setWindUnit('km/h');
        await settings.setPressureUnit('hPa');
        break;
      case 'mixed_international':
        await settings.setAltitudeUnit('ft');
        await settings.setDistanceUnit('nm');
        await settings.setSpeedUnit('kt');
        await settings.setTemperatureUnit('C');
        await settings.setWeightUnit('kg');
        await settings.setFuelUnit('L');
        await settings.setWindUnit('kt');
        await settings.setPressureUnit('hPa');
        break;
      case 'metric':
        await settings.setAltitudeUnit('m');
        await settings.setDistanceUnit('km');
        await settings.setSpeedUnit('km/h');
        await settings.setTemperatureUnit('C');
        await settings.setWeightUnit('kg');
        await settings.setFuelUnit('L');
        await settings.setWindUnit('km/h');
        await settings.setPressureUnit('hPa');
        break;
      case 'imperial':
        await settings.setAltitudeUnit('ft');
        await settings.setDistanceUnit('nm');
        await settings.setSpeedUnit('kt');
        await settings.setTemperatureUnit('C');
        await settings.setWeightUnit('lbs');
        await settings.setFuelUnit('gal');
        await settings.setWindUnit('kt');
        await settings.setPressureUnit('inHg');
        break;
    }
  }
  
  void _showLanguageDialog(BuildContext context, LocalizationService localizationService) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return ThemedDialog(
          title: l10n?.selectLanguage ?? 'Select Language',
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: LocalizationService.supportedLocales.map((locale) {
              final languageName = LocalizationService.languageNames[locale.languageCode];
              final isSelected = locale.languageCode == localizationService.currentLocale.languageCode;
              
              return ListTile(
                title: Text(
                  languageName ?? locale.languageCode,
                  style: TextStyle(
                    color: isSelected ? AppColors.primaryAccent : AppColors.primaryTextColor,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                trailing: isSelected 
                  ? const Icon(Icons.check, color: AppColors.primaryAccent)
                  : null,
                onTap: () async {
                  await localizationService.setLocale(locale);
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n?.cancel ?? 'Cancel'),
            ),
          ],
        );
      },
    );
  }
}
