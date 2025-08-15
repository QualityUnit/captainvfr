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
                  return [
                    PopupMenuItem(
                      value: 'load',
                      child: Row(
                        children: [
                          Icon(Icons.map, size: 20, color: AppColors.primaryTextColor),
                          const SizedBox(width: 8),
                          Text(l10n.loadToMap, style: TextStyle(color: AppColors.primaryTextColor)),
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
    flightPlanService.loadFlightPlan(flightPlan.id);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.loadedFlightPlan(flightPlan.name)),
        duration: const Duration(seconds: 2),
      ),
    );
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
}