import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/flight_plan.dart';
import '../services/flight_plan_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';
import '../utils/form_theme_helper.dart';
import '../l10n/app_localizations.dart';

class FlightPlansScreen extends StatefulWidget {
  const FlightPlansScreen({super.key});

  @override
  State<FlightPlansScreen> createState() => _FlightPlansScreenState();
}

class _FlightPlansScreenState extends State<FlightPlansScreen> {
  @override
  void initState() {
    super.initState();
    // Initialize flight plan service if not already done
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final flightPlanService = Provider.of<FlightPlanService>(
        context,
        listen: false,
      );
      flightPlanService.initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.flightPlanning,
          style: const TextStyle(color: AppColors.primaryTextColor),
        ),
        backgroundColor: AppColors.dialogBackgroundColor,
        foregroundColor: AppColors.primaryTextColor,
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            color: AppColors.dialogBackgroundColor,
            onSelected: (value) => _handleAppBarMenuAction(context, value),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'new_flight_plan',
                child: Row(
                  children: [
                    Icon(Icons.add, size: 20, color: AppColors.primaryTextColor),
                    const SizedBox(width: 8),
                    Text(l10n.newFlightPlan, style: TextStyle(color: AppColors.primaryTextColor)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'create_trip',
                child: Row(
                  children: [
                    Icon(Icons.alt_route, size: 20, color: AppColors.primaryTextColor),
                    const SizedBox(width: 8),
                    Text(l10n.createTrip, style: TextStyle(color: AppColors.primaryTextColor)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      backgroundColor: AppColors.backgroundColor,
      body: Consumer<FlightPlanService>(
        builder: (context, flightPlanService, child) {
          final flightPlans = flightPlanService.savedFlightPlans;

          if (flightPlans.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flight_takeoff, size: 64, color: AppColors.secondaryTextColor),
                  const SizedBox(height: 16),
                  Text(
                    'No flight plans yet', // TODO: Add to localization
                    style: TextStyle(fontSize: 18, color: AppColors.secondaryTextColor),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first flight plan to get started', // TODO: Add to localization
                    style: TextStyle(color: AppColors.secondaryTextColor),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: flightPlans.length,
            itemBuilder: (context, index) {
              final flightPlan = flightPlans[index];
              return _buildFlightPlanCard(
                context,
                flightPlan,
                flightPlanService,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildFlightPlanCard(
    BuildContext context,
    FlightPlan flightPlan,
    FlightPlanService flightPlanService,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.sectionBackgroundColor,
        borderRadius: AppTheme.extraLargeRadius,
        border: Border.all(color: AppColors.sectionBorderColor),
      ),
      child: InkWell(
        borderRadius: AppTheme.extraLargeRadius,
        onTap: () => _loadFlightPlanAndNavigateBack(
          context,
          flightPlan,
          flightPlanService,
        ),
        onLongPress: () => _showFlightPlanOptionsDialog(
          context,
          flightPlan,
          flightPlanService,
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryAccent,
                  borderRadius: AppTheme.extraLargeRadius,
                ),
                child: const Icon(Icons.flight_takeoff, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      flightPlan.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getFlightPlanSummary(flightPlan),
                      style: TextStyle(color: AppColors.secondaryTextColor),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Created: ${_formatDate(flightPlan.createdAt)}',
                      style: TextStyle(color: AppColors.secondaryTextColor, fontSize: 12),
                    ),
                    if (flightPlan.modifiedAt != null)
                      Text(
                        'Modified: ${_formatDate(flightPlan.modifiedAt!)}',
                        style: TextStyle(color: AppColors.secondaryTextColor, fontSize: 12),
                      ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                color: AppColors.dialogBackgroundColor,
                icon: Icon(Icons.more_vert, color: AppColors.secondaryTextColor),
                onSelected: (value) =>
                    _handleMenuAction(context, value, flightPlan, flightPlanService),
                itemBuilder: (context) {
                  final l10n = AppLocalizations.of(context)!;
                  final hasCurrentFlightPlan = flightPlanService.currentFlightPlan != null && 
                                               flightPlanService.currentFlightPlan!.waypoints.isNotEmpty;
                  final hasCurrentTrip = flightPlanService.currentTrip != null;
                  
                  return [
                    PopupMenuItem(
                      value: 'load',
                      child: Row(
                        children: [
                          Icon(
                            hasCurrentFlightPlan || hasCurrentTrip ? Icons.add_road : Icons.map, 
                            size: 20, 
                            color: AppColors.primaryTextColor
                          ),
                          const SizedBox(width: 8),
                          Text(
                            hasCurrentFlightPlan || hasCurrentTrip ? 'Add to Trip' : l10n.loadToMap, 
                            style: TextStyle(color: AppColors.primaryTextColor)
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 20, color: AppColors.primaryTextColor),
                          const SizedBox(width: 8),
                          Text(l10n.editName, style: TextStyle(color: AppColors.primaryTextColor)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'duplicate',
                      child: Row(
                        children: [
                          Icon(Icons.copy, size: 20, color: AppColors.primaryTextColor),
                          const SizedBox(width: 8),
                          Text(l10n.duplicate, style: TextStyle(color: AppColors.primaryTextColor)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          const Icon(Icons.delete, size: 20, color: Colors.red),
                          const SizedBox(width: 8),
                          Text(l10n.delete, style: const TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getFlightPlanSummary(FlightPlan flightPlan) {
    final distance = flightPlan.totalDistance;
    final time = flightPlan.totalFlightTime;

    String summary = '${flightPlan.waypoints.length} waypoints, ';
    summary += '${distance.toStringAsFixed(1)} NM';

    if (time > 0) {
      final hours = (time / 60).floor();
      final minutes = (time % 60).round();
      summary += ', ${hours}h ${minutes}m';
    }

    return summary;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

  void _handleAppBarMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'new_flight_plan':
        _showNewFlightPlanDialog(context);
        break;
      case 'create_trip':
        _showCreateTripDialog(context);
        break;
    }
  }

  void _handleMenuAction(
    BuildContext context,
    String action,
    FlightPlan flightPlan,
    FlightPlanService flightPlanService,
  ) {
    switch (action) {
      case 'load':
        _loadFlightPlanAndNavigateBack(context, flightPlan, flightPlanService);
        break;
      case 'edit':
        _showEditNameDialog(context, flightPlan, flightPlanService);
        break;
      case 'duplicate':
        _duplicateFlightPlan(flightPlan, flightPlanService);
        break;
      case 'delete':
        _showDeleteConfirmDialog(context, flightPlan, flightPlanService);
        break;
    }
  }

  void _loadFlightPlanAndNavigateBack(
    BuildContext context,
    FlightPlan flightPlan,
    FlightPlanService flightPlanService,
  ) {
    final l10n = AppLocalizations.of(context)!;
    
    // Check if we have an existing trip or flight plan
    if (flightPlanService.currentTrip != null || 
        (flightPlanService.currentFlightPlan != null && 
         flightPlanService.currentFlightPlan!.waypoints.isNotEmpty)) {
      // We have an existing trip or flight plan - add this as a new leg
      debugPrint('Adding flight plan ${flightPlan.id} to existing trip/creating new trip');
      flightPlanService.addFlightPlanToTrip(flightPlan);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${flightPlan.name} to trip'),
          duration: const Duration(seconds: 2),
        ),
      );
    } else {
      // No existing flight plan - just load it normally
      flightPlanService.loadFlightPlan(flightPlan.id);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.loadedFlightPlan(flightPlan.name)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showNewFlightPlanDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Generate default name with random number
    final randomNum = DateTime.now().millisecondsSinceEpoch % 1000;
    final defaultName = 'Flight Plan $randomNum';
    final controller = TextEditingController(text: defaultName);

    // Select all text when dialog opens
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );

    showDialog(
      context: context,
      builder: (context) => FormThemeHelper.buildDialog(
        context: context,
        title: l10n.newFlightPlan,
        content: Padding(
          padding: const EdgeInsets.all(16),
          child: FormThemeHelper.buildFormField(
            controller: controller,
            labelText: l10n.flightPlanName,
            hintText: l10n.enterFlightPlanName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FormThemeHelper.getSecondaryButtonStyle(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              final flightPlanService = Provider.of<FlightPlanService>(
                context,
                listen: false,
              );
              flightPlanService.startNewFlightPlan(
                name: controller.text.trim(),
              );
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // Go back to map
            },
            style: FormThemeHelper.getPrimaryButtonStyle(),
            child: Text(l10n.create),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(
    BuildContext context,
    FlightPlan flightPlan,
    FlightPlanService flightPlanService,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: flightPlan.name);
    showDialog(
      context: context,
      builder: (context) => FormThemeHelper.buildDialog(
        context: context,
        title: 'Edit Flight Plan Name',
        content: Padding(
          padding: const EdgeInsets.all(16),
          child: FormThemeHelper.buildFormField(
            controller: controller,
            labelText: l10n.flightPlanName,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FormThemeHelper.getSecondaryButtonStyle(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isNotEmpty) {
                flightPlan.name = controller.text.trim();
                flightPlan.modifiedAt = DateTime.now();
                await flightPlanService.saveCurrentFlightPlan();
              }
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            style: FormThemeHelper.getPrimaryButtonStyle(),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
  }

  void _duplicateFlightPlan(
    FlightPlan flightPlan,
    FlightPlanService flightPlanService,
  ) {
    final l10n = AppLocalizations.of(context)!;
    flightPlanService.duplicateFlightPlan(flightPlan.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.flightPlanDuplicated),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showDeleteConfirmDialog(
    BuildContext context,
    FlightPlan flightPlan,
    FlightPlanService flightPlanService,
  ) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => FormThemeHelper.buildDialog(
        context: context,
        title: l10n.deleteFlightPlan,
        content: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Are you sure you want to delete "${flightPlan.name}"?',
            style: TextStyle(color: AppColors.primaryTextColor),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            style: FormThemeHelper.getSecondaryButtonStyle(),
            child: Text(l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              flightPlanService.deleteFlightPlan(flightPlan.id);
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.flightPlanDeleted),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }

  void _showFlightPlanOptionsDialog(
    BuildContext context,
    FlightPlan flightPlan,
    FlightPlanService flightPlanService,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final hasCurrentFlightPlan = flightPlanService.currentFlightPlan != null && 
                                 flightPlanService.currentFlightPlan!.waypoints.isNotEmpty;
    final hasCurrentTrip = flightPlanService.currentTrip != null;
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          backgroundColor: const Color(0xE6000000),
          shape: RoundedRectangleBorder(
            borderRadius: AppTheme.largeRadius,
            side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
          ),
          title: Text(
            flightPlan.name,
            style: const TextStyle(color: Colors.white),
          ),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(context).pop();
                _loadFlightPlanAndNavigateBack(context, flightPlan, flightPlanService);
              },
              child: Row(
                children: [
                  Icon(
                    hasCurrentFlightPlan || hasCurrentTrip ? Icons.add_road : Icons.map, 
                    size: 20, 
                    color: AppColors.primaryTextColor
                  ),
                  const SizedBox(width: 8),
                  Text(
                    hasCurrentFlightPlan || hasCurrentTrip ? 'Add to Trip' : l10n.loadToMap,
                    style: TextStyle(color: AppColors.primaryTextColor),
                  ),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.of(context).pop();
                // Force replace - clear current and load new
                flightPlanService.clearFlightPlan();
                flightPlanService.loadFlightPlan(flightPlan.id);
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(l10n.loadedFlightPlan(flightPlan.name)),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              child: Row(
                children: [
                  Icon(Icons.replay, size: 20, color: AppColors.primaryTextColor),
                  const SizedBox(width: 8),
                  Text(
                    'Replace Current',
                    style: TextStyle(color: AppColors.primaryTextColor),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _showCreateTripDialog(BuildContext context) {
    final flightPlanService = Provider.of<FlightPlanService>(context, listen: false);
    final flightPlans = flightPlanService.savedFlightPlans;
    
    if (flightPlans.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Need at least 2 flight plans to create a trip'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => _CreateTripDialog(flightPlans: flightPlans),
    );
  }
}

class _CreateTripDialog extends StatefulWidget {
  final List<FlightPlan> flightPlans;

  const _CreateTripDialog({required this.flightPlans});

  @override
  State<_CreateTripDialog> createState() => _CreateTripDialogState();
}

class _CreateTripDialogState extends State<_CreateTripDialog> {
  final _tripNameController = TextEditingController();
  final Set<String> _selectedPlanIds = {};

  @override
  void initState() {
    super.initState();
    // Generate default trip name
    final randomNum = DateTime.now().millisecondsSinceEpoch % 1000;
    _tripNameController.text = 'Trip $randomNum';
    _tripNameController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _tripNameController.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return FormThemeHelper.buildDialog(
      context: context,
      title: l10n.createTrip,
      content: SizedBox(
        width: 400,
        height: 500,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trip name input
            Padding(
              padding: const EdgeInsets.all(16),
              child: FormThemeHelper.buildFormField(
                controller: _tripNameController,
                labelText: l10n.tripName,
                hintText: l10n.enterTripName,
              ),
            ),
            
            // Flight plans selection
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                l10n.selectFlightPlans,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryTextColor,
                ),
              ),
            ),
            
            // Flight plans list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: widget.flightPlans.length,
                itemBuilder: (context, index) {
                  final flightPlan = widget.flightPlans[index];
                  final isSelected = _selectedPlanIds.contains(flightPlan.id);
                  
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedPlanIds.add(flightPlan.id);
                        } else {
                          _selectedPlanIds.remove(flightPlan.id);
                        }
                      });
                    },
                    title: Text(
                      flightPlan.name,
                      style: TextStyle(color: AppColors.primaryTextColor),
                    ),
                    subtitle: Text(
                      _getFlightPlanSummary(flightPlan),
                      style: TextStyle(color: AppColors.secondaryTextColor),
                    ),
                    activeColor: AppColors.primaryAccent,
                    checkColor: Colors.white,
                    tileColor: AppColors.sectionBackgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppTheme.mediumRadius,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _selectedPlanIds.isEmpty ? null : () => _createTrip(context),
          child: Text(l10n.create),
        ),
      ],
    );
  }

  void _createTrip(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final flightPlanService = Provider.of<FlightPlanService>(context, listen: false);
    
    if (_selectedPlanIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.noFlightPlansSelected),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    // Get selected flight plans in order
    final selectedPlans = widget.flightPlans
        .where((fp) => _selectedPlanIds.contains(fp.id))
        .toList();
    
    debugPrint('Selected ${selectedPlans.length} flight plans for trip: ${selectedPlans.map((p) => p.name).join(", ")}');
    
    try {
      await flightPlanService.createTripFromFlightPlans(
        selectedPlans,
        _tripNameController.text.trim(),
      );
      
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Close the dialog
      
      if (!context.mounted) return;
      Navigator.of(context).pop(); // Go back to map screen
      
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.tripCreated),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating trip: $e'),
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  String _getFlightPlanSummary(FlightPlan flightPlan) {
    final distance = flightPlan.totalDistance;
    final time = flightPlan.totalFlightTime;

    String summary = '${flightPlan.waypoints.length} waypoints, ';
    summary += '${distance.toStringAsFixed(1)} NM';

    if (time > 0) {
      final hours = (time / 60).floor();
      final minutes = (time % 60).round();
      summary += ', ${hours}h ${minutes}m';
    }

    return summary;
  }
}