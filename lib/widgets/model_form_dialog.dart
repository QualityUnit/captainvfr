import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/aircraft_settings_service.dart';
import '../models/model.dart';
import '../models/manufacturer.dart';
import '../constants/app_colors.dart';
import '../utils/form_theme_helper.dart';
import '../l10n/app_localizations.dart';

class ModelFormDialog extends StatefulWidget {
  final Model? model;
  final Manufacturer? manufacturer;

  const ModelFormDialog({super.key, this.model, this.manufacturer});

  @override
  State<ModelFormDialog> createState() => _ModelFormDialogState();
}

class _ModelFormDialogState extends State<ModelFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _engineCountController = TextEditingController();
  final _maxSeatsController = TextEditingController();
  final _typicalCruiseSpeedController = TextEditingController();
  final _typicalServiceCeilingController = TextEditingController();
  final _fuelConsumptionController = TextEditingController();
  final _maximumClimbRateController = TextEditingController();
  final _maximumDescentRateController = TextEditingController();
  final _maxTakeoffWeightController = TextEditingController();
  final _maxLandingWeightController = TextEditingController();
  final _fuelCapacityController = TextEditingController();

  AircraftCategory _selectedCategory = AircraftCategory.singleEngine;
  String? _selectedManufacturerId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedManufacturerId = widget.manufacturer?.id;

    if (widget.model != null) {
      _populateFields();
    }
  }

  void _populateFields() {
    final type = widget.model!;
    _nameController.text = type.name;
    _descriptionController.text = type.description ?? '';
    _engineCountController.text = type.engineCount.toString();
    _maxSeatsController.text = type.maxSeats.toString();
    _typicalCruiseSpeedController.text = type.typicalCruiseSpeed.toString();
    _typicalServiceCeilingController.text = type.typicalServiceCeiling
        .toString();
    _fuelConsumptionController.text = type.fuelConsumption?.toString() ?? '';
    _maximumClimbRateController.text = type.maximumClimbRate?.toString() ?? '';
    _maximumDescentRateController.text =
        type.maximumDescentRate?.toString() ?? '';
    _maxTakeoffWeightController.text = type.maxTakeoffWeight?.toString() ?? '';
    _maxLandingWeightController.text = type.maxLandingWeight?.toString() ?? '';
    _fuelCapacityController.text = type.fuelCapacity?.toString() ?? '';
    _selectedCategory = type.category;
    _selectedManufacturerId = type.manufacturerId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _engineCountController.dispose();
    _maxSeatsController.dispose();
    _typicalCruiseSpeedController.dispose();
    _typicalServiceCeilingController.dispose();
    _fuelConsumptionController.dispose();
    _maximumClimbRateController.dispose();
    _maximumDescentRateController.dispose();
    _maxTakeoffWeightController.dispose();
    _maxLandingWeightController.dispose();
    _fuelCapacityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return FormThemeHelper.buildDialog(
      context: context,
      title: widget.model == null ? l10n.addModel : l10n.editModel,
      width: MediaQuery.of(context).size.width * 0.9,
      height: MediaQuery.of(context).size.height * 0.8,
      content: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FormThemeHelper.buildSection(
                title: l10n.basicInformation,
                children: [
                FormThemeHelper.buildFormField(
                  controller: _nameController,
                  labelText: '${l10n.modelName} *',
                  hintText: l10n.egModelC172,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return l10n.pleaseEnterModelName;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                Consumer<AircraftSettingsService>(
                  builder: (context, service, child) {
                    return FormThemeHelper.buildDropdownField<String>(
                      value: _selectedManufacturerId,
                      labelText: '${l10n.manufacturer} *',
                      items: service.manufacturers.map((manufacturer) {
                        return DropdownMenuItem(
                          value: manufacturer.id,
                          child: Text(manufacturer.name, style: TextStyle(color: AppColors.primaryTextColor)),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedManufacturerId = value;
                        });
                      },
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return l10n.pleaseSelectManufacturer;
                        }
                        return null;
                      },
                    );
                  },
                ),
                const SizedBox(height: 16),
                FormThemeHelper.buildDropdownField<AircraftCategory>(
                  value: _selectedCategory,
                  labelText: '${l10n.aircraftCategory} *',
                  items: AircraftCategory.values.map((category) {
                    return DropdownMenuItem(
                      value: category,
                      child: Text(_getCategoryDisplayName(category), style: TextStyle(color: AppColors.primaryTextColor)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedCategory = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FormThemeHelper.buildFormField(
                        controller: _engineCountController,
                        labelText: '${l10n.engineCount} *',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.pleaseEnterEngineCount;
                          }
                          final count = int.tryParse(value);
                          if (count == null || count < 1) {
                            return l10n.pleaseEnterValidEngineCount;
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FormThemeHelper.buildFormField(
                        controller: _maxSeatsController,
                        labelText: '${l10n.maximumSeats} *',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.pleaseEnterMaximumSeats;
                          }
                          final seats = int.tryParse(value);
                          if (seats == null || seats < 1) {
                            return l10n.pleaseEnterValidSeatCount;
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: FormThemeHelper.buildFormField(
                        controller: _typicalCruiseSpeedController,
                        labelText: '${l10n.typicalCruiseSpeed} *',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.pleaseEnterCruiseSpeed;
                          }
                          final speed = int.tryParse(value);
                          if (speed == null || speed < 1) {
                            return l10n.pleaseEnterValidSpeed;
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: FormThemeHelper.buildFormField(
                        controller: _typicalServiceCeilingController,
                        labelText: '${l10n.serviceCeiling} *',
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return l10n.pleaseEnterServiceCeiling;
                          }
                          final ceiling = int.tryParse(value);
                          if (ceiling == null || ceiling < 1) {
                            return l10n.pleaseEnterValidCeiling;
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                FormThemeHelper.buildFormField(
                  controller: _descriptionController,
                  labelText: l10n.description,
                  maxLines: 3,
                ),
              ],
              ),
              const SizedBox(height: 16),
              FormThemeHelper.buildSection(
                title: l10n.optionalPerformanceData,
                children: [
                  FormThemeHelper.buildFormField(
                    controller: _fuelConsumptionController,
                    labelText: l10n.fuelConsumption,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FormThemeHelper.buildFormField(
                          controller: _maximumClimbRateController,
                          labelText: l10n.maxClimbRate,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FormThemeHelper.buildFormField(
                          controller: _maximumDescentRateController,
                          labelText: l10n.maxDescentRate,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FormThemeHelper.buildFormField(
                          controller: _maxTakeoffWeightController,
                          labelText: l10n.maxTakeoffWeight,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FormThemeHelper.buildFormField(
                          controller: _maxLandingWeightController,
                          labelText: l10n.maxLandingWeight,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  FormThemeHelper.buildFormField(
                    controller: _fuelCapacityController,
                    labelText: l10n.fuelCapacity,
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
          ],
        ),
      ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          style: FormThemeHelper.getSecondaryButtonStyle(),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveModel,
          style: FormThemeHelper.getPrimaryButtonStyle(),
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(widget.model == null ? l10n.add : l10n.save),
        ),
      ],
    );
  }

  Future<void> _saveModel() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    final l10n = AppLocalizations.of(context)!;

    try {
      final service = Provider.of<AircraftSettingsService>(
        context,
        listen: false,
      );

      if (widget.model == null) {
        // Adding a new model - use the method with individual parameters
        await service.addModel(
          _nameController.text.trim(),
          _selectedManufacturerId!,
          _selectedCategory,
          engineCount: int.parse(_engineCountController.text),
          maxSeats: int.parse(_maxSeatsController.text),
          typicalCruiseSpeed: int.parse(_typicalCruiseSpeedController.text),
          typicalServiceCeiling: int.parse(
            _typicalServiceCeilingController.text,
          ),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          fuelConsumption: _fuelConsumptionController.text.trim().isEmpty
              ? null
              : double.tryParse(_fuelConsumptionController.text),
          maximumClimbRate: _maximumClimbRateController.text.trim().isEmpty
              ? null
              : int.tryParse(_maximumClimbRateController.text),
          maximumDescentRate: _maximumDescentRateController.text.trim().isEmpty
              ? null
              : int.tryParse(_maximumDescentRateController.text),
          maxTakeoffWeight: _maxTakeoffWeightController.text.trim().isEmpty
              ? null
              : int.tryParse(_maxTakeoffWeightController.text),
          maxLandingWeight: _maxLandingWeightController.text.trim().isEmpty
              ? null
              : int.tryParse(_maxLandingWeightController.text),
          fuelCapacity: _fuelCapacityController.text.trim().isEmpty
              ? null
              : int.tryParse(_fuelCapacityController.text),
        );
      } else {
        // Updating existing model - create Model object
        final model = Model(
          id: widget.model!.id,
          name: _nameController.text.trim(),
          manufacturerId: _selectedManufacturerId!,
          category: _selectedCategory,
          engineCount: int.parse(_engineCountController.text),
          maxSeats: int.parse(_maxSeatsController.text),
          typicalCruiseSpeed: int.parse(_typicalCruiseSpeedController.text),
          typicalServiceCeiling: int.parse(
            _typicalServiceCeilingController.text,
          ),
          description: _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
          createdAt: widget.model!.createdAt,
          updatedAt: DateTime.now(),
          fuelConsumption: _fuelConsumptionController.text.trim().isEmpty
              ? null
              : double.tryParse(_fuelConsumptionController.text),
          maximumClimbRate: _maximumClimbRateController.text.trim().isEmpty
              ? null
              : int.tryParse(_maximumClimbRateController.text),
          maximumDescentRate: _maximumDescentRateController.text.trim().isEmpty
              ? null
              : int.tryParse(_maximumDescentRateController.text),
          maxTakeoffWeight: _maxTakeoffWeightController.text.trim().isEmpty
              ? null
              : int.tryParse(_maxTakeoffWeightController.text),
          maxLandingWeight: _maxLandingWeightController.text.trim().isEmpty
              ? null
              : int.tryParse(_maxLandingWeightController.text),
          fuelCapacity: _fuelCapacityController.text.trim().isEmpty
              ? null
              : int.tryParse(_fuelCapacityController.text),
        );

        await service.updateModel(model);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.model == null
                  ? l10n.modelAddedSuccessfully
                  : l10n.modelUpdatedSuccessfully,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorSavingModel(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getCategoryDisplayName(AircraftCategory category) {
    final l10n = AppLocalizations.of(context)!;
    switch (category) {
      case AircraftCategory.singleEngine:
        return l10n.singleEngine;
      case AircraftCategory.multiEngine:
        return l10n.multiEngine;
      case AircraftCategory.jet:
        return 'Jet';
      case AircraftCategory.helicopter:
        return 'Helicopter';
      case AircraftCategory.glider:
        return 'Glider';
      case AircraftCategory.turboprop:
        return 'Turboprop';
    }
  }
}
