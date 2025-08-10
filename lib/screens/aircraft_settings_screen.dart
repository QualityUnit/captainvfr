import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/aircraft_settings_service.dart';
import '../models/aircraft.dart';
import '../models/model.dart';
import '../models/manufacturer.dart';
import '../widgets/aircraft_form_dialog.dart';
import '../widgets/manufacturer_form_dialog.dart';
import 'aircraft_detail_screen.dart';
import 'manufacturer_detail_screen.dart';
import '../constants/app_theme.dart';
import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';

class AircraftSettingsScreen extends StatefulWidget {
  const AircraftSettingsScreen({super.key});

  @override
  State<AircraftSettingsScreen> createState() => _AircraftSettingsScreenState();
}

class _AircraftSettingsScreenState extends State<AircraftSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late AircraftSettingsService _aircraftService;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _aircraftService = Provider.of<AircraftSettingsService>(
      context,
      listen: false,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.aircraft,
          style: const TextStyle(color: AppColors.primaryTextColor),
        ),
        backgroundColor: AppColors.dialogBackgroundColor,
        foregroundColor: AppColors.primaryTextColor,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryAccent,
          labelColor: AppColors.primaryTextColor,
          unselectedLabelColor: AppColors.secondaryTextColor,
          tabs: [
            Tab(icon: const Icon(Icons.airplanemode_active), text: l10n.aircraft),
            Tab(icon: const Icon(Icons.business), text: l10n.manufacturers),
          ],
        ),
      ),
      backgroundColor: AppColors.backgroundColor,
      body: TabBarView(
        controller: _tabController,
        children: [_buildAircraftTab(), _buildManufacturersTab()],
      ),
    );
  }

  Widget _buildAircraftTab() {
    return Consumer<AircraftSettingsService>(
      builder: (context, service, child) {
        final l10n = AppLocalizations.of(context)!;
        if (service.aircrafts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.airplanemode_inactive,
                  size: 64,
                  color: Colors.white54,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.noAircraftConfigured,
                  style: const TextStyle(fontSize: 18, color: Colors.white70),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAircraftForm(),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addFirstAircraft),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF448AFF),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${service.aircrafts.length} aircraft configured',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showAircraftForm(),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addAircraft),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF448AFF),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: service.aircrafts.length,
                itemBuilder: (context, index) {
                  final aircraft = service.aircrafts[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0x1A448AFF),
                      borderRadius: AppTheme.extraLargeRadius,
                      border: Border.all(color: const Color(0x7F448AFF)),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF448AFF),
                        child: Text(
                          aircraft.name.isNotEmpty
                              ? aircraft.name[0].toUpperCase()
                              : 'A',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        aircraft.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getAircraftDisplayText(aircraft, service),
                            style: const TextStyle(color: Colors.white70),
                          ),
                          Text(
                            '${_getCategoryDisplayName(context, aircraft.category)} • ${aircraft.cruiseSpeed} kts',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                      trailing: PopupMenuButton<String>(
                        iconColor: Colors.white70,
                        color: const Color(0xE6000000),
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showAircraftForm(aircraft: aircraft);
                          } else if (value == 'delete') {
                            _confirmDeleteAircraft(aircraft);
                          }
                        },
                        itemBuilder: (context) {
                          final l10n = AppLocalizations.of(context)!;
                          return [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  const Icon(Icons.edit, size: 20, color: Colors.white70),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.edit,
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(Icons.delete, size: 20, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.delete,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ];
                        },
                      ),
                      onTap: () => _showAircraftDetails(aircraft),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildManufacturersTab() {
    return Consumer<AircraftSettingsService>(
      builder: (context, service, child) {
        final l10n = AppLocalizations.of(context)!;
        if (service.manufacturers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.business,
                  size: 64,
                  color: AppColors.primaryAccent.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'No manufacturers configured', // TODO: Add to localization
                  style: TextStyle(
                    fontSize: 18,
                    color: AppColors.primaryTextColor,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => _showManufacturerForm(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.addManufacturer),
                ),
              ],
            ),
          );
        }

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${service.manufacturers.length} manufacturer(s) configured',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.primaryTextColor,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showManufacturerForm(),
                    style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryAccent,
                    foregroundColor: Colors.white,
                  ),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addManufacturer),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: service.manufacturers.length,
                itemBuilder: (context, index) {
                  final manufacturer = service.manufacturers[index];
                  return Container(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.sectionBackgroundColor,
                      borderRadius: AppTheme.extraLargeRadius,
                      border: Border.all(color: AppColors.sectionBorderColor),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: AppColors.primaryAccent,
                        child: Text(
                          manufacturer.name.isNotEmpty
                              ? manufacturer.name[0].toUpperCase()
                              : 'M',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        manufacturer.name,
                        style: TextStyle(
                          color: AppColors.primaryTextColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        '${manufacturer.models.length} models',
                        style: TextStyle(color: AppColors.secondaryTextColor),
                      ),
                      trailing: PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert,
                          color: AppColors.primaryTextColor,
                        ),
                        color: AppColors.dialogBackgroundColor,
                        onSelected: (value) {
                          if (value == 'edit') {
                            _showManufacturerForm(manufacturer: manufacturer);
                          } else if (value == 'delete') {
                            _confirmDeleteManufacturer(manufacturer);
                          }
                        },
                        itemBuilder: (context) {
                          final l10n = AppLocalizations.of(context)!;
                          return [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(Icons.edit, size: 20, color: AppColors.primaryTextColor),
                                  const SizedBox(width: 8),
                                  Text(l10n.edit, style: TextStyle(color: AppColors.primaryTextColor)),
                                ],
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  const Icon(Icons.delete, size: 20, color: Colors.red),
                                  const SizedBox(width: 8),
                                  Text(
                                    l10n.delete,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ],
                              ),
                            ),
                          ];
                        },
                      ),
                      onTap: () => _showManufacturerDetails(manufacturer),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAircraftForm({Aircraft? aircraft}) {
    showDialog(
      context: context,
      builder: (context) => AircraftFormDialog(aircraft: aircraft),
    );
  }

  void _showManufacturerForm({Manufacturer? manufacturer}) {
    showDialog(
      context: context,
      builder: (context) => ManufacturerFormDialog(manufacturer: manufacturer),
    );
  }

  void _showAircraftDetails(Aircraft aircraft) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AircraftDetailScreen(aircraft: aircraft),
      ),
    );
  }

  void _confirmDeleteAircraft(Aircraft aircraft) {
    showDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.deleteAircraft),
          content: Text(l10n.confirmDeleteAircraft(aircraft.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                _aircraftService.deleteAircraft(aircraft.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.deletedAircraft(aircraft.name))),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
  }

  void _confirmDeleteManufacturer(Manufacturer manufacturer) {
    showDialog(
      context: context,
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.deleteManufacturer),
          content: Text(
            l10n.confirmDeleteManufacturer(manufacturer.name),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () {
                _aircraftService.deleteManufacturer(manufacturer.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.deletedManufacturer(manufacturer.name))),
                );
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l10n.delete),
            ),
          ],
        );
      },
    );
  }

  void _showManufacturerDetails(Manufacturer manufacturer) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            ManufacturerDetailScreen(manufacturer: manufacturer),
      ),
    );
  }

  String _getAircraftDisplayText(
    Aircraft aircraft,
    AircraftSettingsService service,
  ) {
    final manufacturer = service.manufacturers.firstWhere(
      (m) => m.id == aircraft.manufacturerId,
      orElse: () => Manufacturer.empty(),
    );
    return '${manufacturer.name} ${aircraft.model}';
  }

  String _getCategoryDisplayName(BuildContext context, AircraftCategory? category) {
    final l10n = AppLocalizations.of(context)!;
    if (category == null) return 'Unknown'; // TODO: Add to localization
    switch (category) {
      case AircraftCategory.singleEngine:
        return l10n.singleEngine;
      case AircraftCategory.multiEngine:
        return l10n.multiEngine;
      case AircraftCategory.jet:
        return 'Jet'; // TODO: Add to localization
      case AircraftCategory.helicopter:
        return 'Helicopter'; // TODO: Add to localization
      case AircraftCategory.glider:
        return 'Glider'; // TODO: Add to localization
      case AircraftCategory.turboprop:
        return 'Turboprop'; // TODO: Add to localization
    }
  }
}
