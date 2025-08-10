import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/logbook_entry.dart';
import '../../models/model.dart' show AircraftCategory;
import '../../models/flight_plan.dart' show FlightRules;
import '../../models/pilot.dart';
import '../../services/logbook_service.dart';
import '../../services/pilot_service.dart';
import '../../services/aircraft_settings_service.dart';
import '../../services/flight_service.dart';
import '../../screens/flight_detail_screen.dart';
import '../../widgets/themed_dialog.dart';
import '../../l10n/app_localizations.dart';

class LogBookEntryDialog extends StatefulWidget {
  final LogBookEntry? entry;

  const LogBookEntryDialog({super.key, this.entry});
  
  static Future<void> show(BuildContext context, {LogBookEntry? entry}) {
    final l10n = AppLocalizations.of(context)!;
    return ThemedDialog.show(
      context: context,
      title: entry != null ? l10n.editLogBookEntry : l10n.manualEntry,
      maxWidth: 600,
      maxHeight: null,
      content: LogBookEntryDialog(entry: entry),
      actions: null, // Actions will be handled inside the dialog
    );
  }

  @override
  State<LogBookEntryDialog> createState() => _LogBookEntryDialogState();
}

class _LogBookEntryDialogState extends State<LogBookEntryDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _departureController;
  late TextEditingController _arrivalController;
  late TextEditingController _aircraftTypeController;
  late TextEditingController _aircraftIdController;
  late TextEditingController _dayTakeoffsController;
  late TextEditingController _nightTakeoffsController;
  late TextEditingController _dayLandingsController;
  late TextEditingController _nightLandingsController;
  late TextEditingController _flightTrainingController;
  late TextEditingController _groundTrainingController;
  late TextEditingController _simulatorController;
  late TextEditingController _noteController;

  // Date/Time values
  late DateTime _startDate;
  late TimeOfDay _startTime;
  late DateTime _endDate;
  late TimeOfDay _endTime;
  DateTime? _startMovingDate;
  TimeOfDay? _startMovingTime;
  DateTime? _endMovingDate;
  TimeOfDay? _endMovingTime;

  // Selection values
  String? _selectedPicId;
  String? _selectedSicId;
  String? _selectedAircraftId;
  EngineType? _engineType;
  FlightCondition? _flightCondition;
  FlightRules? _flightRules;
  bool _simulated = false;
  bool _flightReview = false;
  bool _ipc = false;
  bool _checkRide = false;
  bool _faa6158 = false;
  bool _nvgProficiency = false;
  
  // Pictures and documents
  List<String> _imagePaths = [];
  List<String> _documentPaths = [];
  String? _linkedFlightLogId;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    
    // Initialize controllers
    _departureController = TextEditingController(text: entry?.departureAirport ?? '');
    _arrivalController = TextEditingController(text: entry?.arrivalAirport ?? '');
    _aircraftTypeController = TextEditingController(text: entry?.aircraftType ?? '');
    _aircraftIdController = TextEditingController(text: entry?.aircraftIdentification ?? '');
    _dayTakeoffsController = TextEditingController(text: (entry?.dayTakeoffs ?? 0).toString());
    _nightTakeoffsController = TextEditingController(text: (entry?.nightTakeoffs ?? 0).toString());
    _dayLandingsController = TextEditingController(text: (entry?.dayLandings ?? 0).toString());
    _nightLandingsController = TextEditingController(text: (entry?.nightLandings ?? 0).toString());
    _flightTrainingController = TextEditingController(text: entry?.flightTrainingNote ?? '');
    _groundTrainingController = TextEditingController(text: entry?.groundTrainingNote ?? '');
    _simulatorController = TextEditingController(text: entry?.simulatorNote ?? '');
    _noteController = TextEditingController(text: entry?.note ?? '');

    // Initialize date/time values
    _startDate = entry?.dateTimeStarted ?? DateTime.now();
    _startTime = TimeOfDay.fromDateTime(entry?.dateTimeStarted ?? DateTime.now());
    _endDate = entry?.dateTimeFinished ?? DateTime.now();
    _endTime = TimeOfDay.fromDateTime(entry?.dateTimeFinished ?? DateTime.now());
    
    if (entry?.dateTimeStartedMoving != null) {
      _startMovingDate = entry!.dateTimeStartedMoving!;
      _startMovingTime = TimeOfDay.fromDateTime(entry.dateTimeStartedMoving!);
    }
    
    if (entry?.dateTimeFinishedMoving != null) {
      _endMovingDate = entry!.dateTimeFinishedMoving!;
      _endMovingTime = TimeOfDay.fromDateTime(entry.dateTimeFinishedMoving!);
    }

    // Initialize selection values
    _selectedPicId = entry?.pilotInCommandId ?? context.read<PilotService>().currentPilot?.id;
    _selectedSicId = entry?.secondInCommandId;
    _engineType = entry?.engineType ?? EngineType.singleEngine;
    _flightCondition = entry?.flightCondition;
    _flightRules = entry?.flightRules ?? FlightRules.vfr;
    _simulated = entry?.simulated ?? false;
    _flightReview = entry?.flightReview ?? false;
    _ipc = entry?.ipc ?? false;
    _checkRide = entry?.checkRide ?? false;
    _faa6158 = entry?.faa6158 ?? false;
    _nvgProficiency = entry?.nvgProficiency ?? false;
    
    // Initialize pictures and documents
    _imagePaths = List<String>.from(entry?.imagePaths ?? []);
    _documentPaths = List<String>.from(entry?.documentPaths ?? []);
    _linkedFlightLogId = entry?.flightLogId;
  }

  @override
  void dispose() {
    _departureController.dispose();
    _arrivalController.dispose();
    _aircraftTypeController.dispose();
    _aircraftIdController.dispose();
    _dayTakeoffsController.dispose();
    _nightTakeoffsController.dispose();
    _dayLandingsController.dispose();
    _nightLandingsController.dispose();
    _flightTrainingController.dispose();
    _groundTrainingController.dispose();
    _simulatorController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  Future<void> _saveEntry() async {
    if (_formKey.currentState!.validate()) {
      final logBookService = context.read<LogBookService>();

      // Calculate durations
      final startDateTime = _combineDateTime(_startDate, _startTime);
      final endDateTime = _combineDateTime(_endDate, _endTime);
      final trackingDuration = endDateTime.difference(startDateTime);

      Duration? movingDuration;
      if (_startMovingDate != null && _startMovingTime != null && 
          _endMovingDate != null && _endMovingTime != null) {
        final startMoving = _combineDateTime(_startMovingDate!, _startMovingTime!);
        final endMoving = _combineDateTime(_endMovingDate!, _endMovingTime!);
        movingDuration = endMoving.difference(startMoving);
      }

      final entry = LogBookEntry(
        id: widget.entry?.id,
        dateTimeStarted: startDateTime,
        dateTimeStartedMoving: _startMovingDate != null && _startMovingTime != null
            ? _combineDateTime(_startMovingDate!, _startMovingTime!)
            : null,
        departureAirport: _departureController.text.trim().isEmpty 
            ? null : _departureController.text.trim(),
        dateTimeFinished: endDateTime,
        dateTimeFinishedMoving: _endMovingDate != null && _endMovingTime != null
            ? _combineDateTime(_endMovingDate!, _endMovingTime!)
            : null,
        arrivalAirport: _arrivalController.text.trim().isEmpty 
            ? null : _arrivalController.text.trim(),
        engineType: _engineType,
        aircraftType: _aircraftTypeController.text.trim().isEmpty 
            ? null : _aircraftTypeController.text.trim(),
        aircraftIdentification: _aircraftIdController.text.trim().isEmpty 
            ? null : _aircraftIdController.text.trim(),
        pilotInCommandId: _selectedPicId,
        secondInCommandId: _selectedSicId,
        flightTrainingNote: _flightTrainingController.text.trim().isEmpty 
            ? null : _flightTrainingController.text.trim(),
        groundTrainingNote: _groundTrainingController.text.trim().isEmpty 
            ? null : _groundTrainingController.text.trim(),
        simulatorNote: _simulatorController.text.trim().isEmpty 
            ? null : _simulatorController.text.trim(),
        flightReview: _flightReview,
        ipc: _ipc,
        checkRide: _checkRide,
        faa6158: _faa6158,
        nvgProficiency: _nvgProficiency,
        flightCondition: _flightCondition,
        flightRules: _flightRules,
        simulated: _simulated,
        dayTakeoffs: int.tryParse(_dayTakeoffsController.text) ?? 0,
        nightTakeoffs: int.tryParse(_nightTakeoffsController.text) ?? 0,
        dayLandings: int.tryParse(_dayLandingsController.text) ?? 0,
        nightLandings: int.tryParse(_nightLandingsController.text) ?? 0,
        note: _noteController.text.trim().isEmpty 
            ? null : _noteController.text.trim(),
        flightLogId: _linkedFlightLogId,
        imagePaths: _imagePaths,
        documentPaths: _documentPaths,
        trackingDuration: trackingDuration,
        movingDuration: movingDuration,
        createdAt: widget.entry?.createdAt,
      );

      if (widget.entry == null) {
        await logBookService.addEntry(entry);
      } else {
        await logBookService.updateEntry(entry);
      }

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isEditing = widget.entry != null;
    final pilotService = context.watch<PilotService>();
    final aircraftService = context.watch<AircraftSettingsService>();
    final pilots = pilotService.pilots;
    final aircraft = aircraftService.aircrafts;

    return Theme(
      data: ThemeData.dark().copyWith(
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0x1A448AFF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            borderSide: BorderSide(color: Color(0x7F448AFF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            borderSide: BorderSide(color: Color(0x7F448AFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            borderSide: BorderSide(color: Color(0xFF448AFF), width: 2.0),
          ),
          labelStyle: TextStyle(color: Colors.white70, fontSize: 12),
          hintStyle: TextStyle(color: Colors.white30, fontSize: 12),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
        textTheme: const TextTheme(
          bodyLarge: TextStyle(fontSize: 13, color: Colors.white),
          bodyMedium: TextStyle(fontSize: 12, color: Colors.white),
          bodySmall: TextStyle(fontSize: 11, color: Colors.white70),
          titleLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          titleMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tab navigation
            DefaultTabController(
              length: 5,
              child: Column(
                children: [
                  TabBar(
                    isScrollable: true,
                    indicatorColor: const Color(0xFF448AFF),
                    labelColor: Colors.white,
                    unselectedLabelColor: Colors.white54,
                    labelStyle: const TextStyle(fontSize: 11),
                    tabs: [
                      Tab(text: l10n.timing),
                      Tab(text: l10n.aircraft),
                      Tab(text: l10n.pilots),
                      Tab(text: l10n.conditions),
                      Tab(text: l10n.notes),
                    ],
                  ),
                  SizedBox(
                    height: 400, // Fixed height for tab content
                    child: TabBarView(
                      children: [
                        // Timing Tab
                        _buildTimingTab(l10n),
                        // Aircraft Tab
                        _buildAircraftTab(aircraft, l10n),
                        // Pilots Tab
                        _buildPilotsTab(pilots, l10n),
                        // Conditions Tab
                        _buildConditionsTab(l10n),
                        // Notes Tab
                        _buildNotesTab(l10n),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _saveEntry,
                  child: Text(isEditing ? 'Update' : 'Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimingTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCompactDateTimeRow(
            l10n.start,
            _startDate,
            _startTime,
            (date) => setState(() => _startDate = date),
            (time) => setState(() => _startTime = time),
            required: true,
          ),
          const SizedBox(height: 12),
          _buildCompactDateTimeRow(
            l10n.startMoving,
            _startMovingDate,
            _startMovingTime,
            (date) => setState(() => _startMovingDate = date),
            (time) => setState(() => _startMovingTime = time),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _departureController,
            decoration: InputDecoration(
              labelText: l10n.departureAirport,
              hintText: l10n.icao,
              prefixIcon: Icon(Icons.flight_takeoff, size: 18),
            ),
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          _buildCompactDateTimeRow(
            l10n.end,
            _endDate,
            _endTime,
            (date) => setState(() => _endDate = date),
            (time) => setState(() => _endTime = time),
            required: true,
          ),
          const SizedBox(height: 12),
          _buildCompactDateTimeRow(
            l10n.endMoving,
            _endMovingDate,
            _endMovingTime,
            (date) => setState(() => _endMovingDate = date),
            (time) => setState(() => _endMovingTime = time),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _arrivalController,
            decoration: InputDecoration(
              labelText: l10n.arrivalAirport,
              hintText: l10n.icao,
              prefixIcon: Icon(Icons.flight_land, size: 18),
            ),
            textCapitalization: TextCapitalization.characters,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildAircraftTab(List<dynamic> aircraft, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedAircraftId,
            decoration: InputDecoration(
              labelText: l10n.selectAircraft,
              prefixIcon: Icon(Icons.airplanemode_active, size: 18),
            ),
            dropdownColor: const Color(0xF0000000),
            style: const TextStyle(fontSize: 12),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(l10n.manualEntry),
              ),
              ...aircraft.map((a) => DropdownMenuItem(
                value: a.id,
                child: Text('${a.model ?? a.name} (${a.registration ?? a.name})', 
                  style: const TextStyle(fontSize: 12)),
              )),
            ],
            onChanged: (value) {
              setState(() {
                _selectedAircraftId = value;
                if (value != null) {
                  final selectedAircraft = aircraft.firstWhere((a) => a.id == value);
                  _aircraftTypeController.text = selectedAircraft.model ?? '';
                  _aircraftIdController.text = selectedAircraft.registration ?? '';
                  _engineType = selectedAircraft.category == AircraftCategory.multiEngine
                      ? EngineType.multiEngine
                      : EngineType.singleEngine;
                }
              });
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _aircraftTypeController,
                  decoration: InputDecoration(
                    labelText: l10n.type,
                    hintText: 'C172',
                  ),
                  enabled: _selectedAircraftId == null,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _aircraftIdController,
                  decoration: InputDecoration(
                    labelText: l10n.registration,
                    hintText: 'N12345',
                  ),
                  textCapitalization: TextCapitalization.characters,
                  enabled: _selectedAircraftId == null,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<EngineType>(
            value: _engineType,
            decoration: InputDecoration(
              labelText: '${l10n.engineType} *',
              prefixIcon: Icon(Icons.settings, size: 18),
            ),
            dropdownColor: const Color(0xF0000000),
            style: const TextStyle(fontSize: 12),
            items: [
              DropdownMenuItem(
                value: EngineType.singleEngine,
                child: Text(l10n.singleEngine, style: TextStyle(fontSize: 12)),
              ),
              DropdownMenuItem(
                value: EngineType.multiEngine,
                child: Text(l10n.multiEngine, style: TextStyle(fontSize: 12)),
              ),
            ],
            onChanged: (value) => setState(() => _engineType = value),
            validator: (value) {
              if (value == null) {
                return l10n.required;
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPilotsTab(List<Pilot> pilots, AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          DropdownButtonFormField<String>(
            value: _selectedPicId,
            decoration: InputDecoration(
              labelText: l10n.pilotInCommand,
              prefixIcon: Icon(Icons.person, size: 18),
            ),
            dropdownColor: const Color(0xF0000000),
            style: const TextStyle(fontSize: 12),
            items: pilots.map((pilot) => DropdownMenuItem(
              value: pilot.id,
              child: Text(pilot.name, style: const TextStyle(fontSize: 12)),
            )).toList(),
            onChanged: (value) => setState(() => _selectedPicId = value),
            validator: (value) {
              if (value == null) {
                return l10n.required;
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _selectedSicId,
            decoration: InputDecoration(
              labelText: l10n.secondInCommand,
              prefixIcon: Icon(Icons.person_outline, size: 18),
            ),
            dropdownColor: const Color(0xF0000000),
            style: const TextStyle(fontSize: 12),
            items: [
              DropdownMenuItem(
                value: null,
                child: Text(l10n.soloFlight, style: TextStyle(fontSize: 12)),
              ),
              ...pilots
                  .where((p) => p.id != _selectedPicId)
                  .map((pilot) => DropdownMenuItem(
                value: pilot.id,
                child: Text(pilot.name, style: const TextStyle(fontSize: 12)),
              )),
            ],
            onChanged: (value) => setState(() => _selectedSicId = value),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCompactChip(l10n.flightReview, _flightReview, 
                (v) => setState(() => _flightReview = v)),
              _buildCompactChip(l10n.ipc, _ipc, 
                (v) => setState(() => _ipc = v)),
              _buildCompactChip(l10n.checkRide, _checkRide, 
                (v) => setState(() => _checkRide = v)),
              _buildCompactChip(l10n.faa6158, _faa6158, 
                (v) => setState(() => _faa6158 = v)),
              _buildCompactChip(l10n.nvgProficiency, _nvgProficiency, 
                (v) => setState(() => _nvgProficiency = v)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConditionsTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<FlightCondition>(
                  value: _flightCondition,
                  decoration: InputDecoration(
                    labelText: l10n.dayNight,
                    prefixIcon: Icon(Icons.brightness_4, size: 18),
                  ),
                  dropdownColor: const Color(0xF0000000),
                  style: const TextStyle(fontSize: 12),
                  items: [
                    DropdownMenuItem(
                      value: FlightCondition.day,
                      child: Text(l10n.day, style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem(
                      value: FlightCondition.night,
                      child: Text(l10n.night, style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  onChanged: (value) => setState(() => _flightCondition = value),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<FlightRules>(
                  value: _flightRules,
                  decoration: InputDecoration(
                    labelText: 'VFR/IFR',
                    prefixIcon: Icon(Icons.visibility, size: 18),
                  ),
                  dropdownColor: const Color(0xF0000000),
                  style: const TextStyle(fontSize: 12),
                  items: [
                    DropdownMenuItem(
                      value: FlightRules.vfr,
                      child: Text(l10n.vfr, style: TextStyle(fontSize: 12)),
                    ),
                    DropdownMenuItem(
                      value: FlightRules.ifr,
                      child: Text(l10n.ifr, style: TextStyle(fontSize: 12)),
                    ),
                  ],
                  onChanged: (value) => setState(() => _flightRules = value),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            title: Text(l10n.simulatedConditions, style: TextStyle(fontSize: 12)),
            value: _simulated,
            onChanged: (value) => setState(() => _simulated = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
          const SizedBox(height: 16),
          Text(l10n.takeoffsLandings, 
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _dayTakeoffsController,
                  decoration: InputDecoration(
                    labelText: l10n.dayTO,
                    prefixIcon: Icon(Icons.wb_sunny, size: 18),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _nightTakeoffsController,
                  decoration: InputDecoration(
                    labelText: l10n.nightTO,
                    prefixIcon: Icon(Icons.nights_stay, size: 18),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _dayLandingsController,
                  decoration: InputDecoration(
                    labelText: l10n.dayLdg,
                    prefixIcon: Icon(Icons.wb_sunny, size: 18),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _nightLandingsController,
                  decoration: InputDecoration(
                    labelText: l10n.nightLdg,
                    prefixIcon: Icon(Icons.nights_stay, size: 18),
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesTab(AppLocalizations l10n) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          TextFormField(
            controller: _flightTrainingController,
            decoration: InputDecoration(
              labelText: l10n.flightTraining,
              alignLabelWithHint: true,
            ),
            maxLines: 2,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _groundTrainingController,
            decoration: InputDecoration(
              labelText: l10n.groundTraining,
              alignLabelWithHint: true,
            ),
            maxLines: 2,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _simulatorController,
            decoration: InputDecoration(
              labelText: l10n.simulator,
              alignLabelWithHint: true,
            ),
            maxLines: 2,
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: l10n.flightNotes,
              alignLabelWithHint: true,
            ),
            maxLines: 3,
            style: const TextStyle(fontSize: 12),
          ),
          if (_linkedFlightLogId != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0x1A448AFF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0x7F448AFF)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link, size: 18, color: Color(0xFF448AFF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.linkedFlightLog, 
                          style: TextStyle(fontSize: 11, color: Colors.white70)),
                        Text('${l10n.id}: $_linkedFlightLogId',
                          style: const TextStyle(fontSize: 10, color: Colors.white54)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.open_in_new, size: 16),
                    onPressed: () async {
                      final flightService = context.read<FlightService>();
                      final flight = flightService.flights.firstWhere(
                        (f) => f.id == _linkedFlightLogId,
                        orElse: () => throw Exception('Flight not found'),
                      );
                      
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => FlightDetailScreen(flight: flight),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactDateTimeRow(
    String label,
    DateTime? date,
    TimeOfDay? time,
    Function(DateTime) onDateChanged,
    Function(TimeOfDay) onTimeChanged, {
    bool required = false,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final dateFormat = DateFormat('MMM dd');
    final hasValue = date != null && time != null;

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            required ? '$label *' : label,
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ),
        Expanded(
          flex: 3,
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: date ?? DateTime.now(),
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now().add(const Duration(days: 1)),
                    );
                    if (picked != null) {
                      onDateChanged(picked);
                      if (time == null) {
                        onTimeChanged(TimeOfDay.now());
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0x1A448AFF),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0x7F448AFF)),
                    ),
                    child: Text(
                      date != null ? dateFormat.format(date) : l10n.date,
                      style: TextStyle(
                        fontSize: 11,
                        color: date == null ? Colors.white30 : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: time ?? TimeOfDay.now(),
                    );
                    if (picked != null) {
                      onTimeChanged(picked);
                      if (date == null) {
                        onDateChanged(DateTime.now());
                      }
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0x1A448AFF),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: const Color(0x7F448AFF)),
                    ),
                    child: Text(
                      time != null ? time.format(context) : l10n.time,
                      style: TextStyle(
                        fontSize: 11,
                        color: time == null ? Colors.white30 : Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
              if (!required && hasValue)
                IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
                  onPressed: () {
                    setState(() {
                      if (label.contains('Start Moving')) {
                        _startMovingDate = null;
                        _startMovingTime = null;
                      } else if (label.contains('End Moving')) {
                        _endMovingDate = null;
                        _endMovingTime = null;
                      }
                    });
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompactChip(String label, bool selected, Function(bool) onSelected) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      selected: selected,
      onSelected: onSelected,
      selectedColor: const Color(0xFF448AFF),
      backgroundColor: const Color(0x1A448AFF),
      side: BorderSide(
        color: selected ? const Color(0xFF448AFF) : const Color(0x7F448AFF),
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}