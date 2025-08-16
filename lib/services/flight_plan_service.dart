import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive/hive.dart';
import '../models/flight_plan.dart';
import '../models/trip.dart';
import '../models/airport.dart';
import '../models/navaid.dart';
import '../models/aircraft.dart';
import '../models/reporting_point.dart';
import '../constants/trip_colors.dart';
import '../services/aircraft_service.dart';
import '../services/flight_plan_tile_download_service.dart';

class FlightPlanService extends ChangeNotifier {
  FlightPlan? _currentFlightPlan;
  bool _isPlanning = false;
  bool _isFlightPlanVisible = true;
  int _waypointCounter = 1;
  List<FlightPlan> _savedFlightPlans = [];
  Box<FlightPlan>? _flightPlanBox;
  List<Trip> _savedTrips = [];
  Box<Trip>? _tripBox;
  Trip? _currentTrip;
  final List<FlightPlan> _currentTripPlans = []; // All flight plans in current trip
  final AircraftService? _aircraftService;
  FlightPlanTileDownloadService? _tileDownloadService;
  BuildContext? _context;
  
  // Callback for when a flight plan is loaded
  void Function(FlightPlan)? onFlightPlanLoaded;

  FlightPlan? get currentFlightPlan => _currentFlightPlan;
  bool get isPlanning => _isPlanning;
  bool get isFlightPlanVisible => _isFlightPlanVisible;
  List<Waypoint> get waypoints => _currentFlightPlan?.waypoints ?? [];
  List<FlightPlan> get savedFlightPlans => _savedFlightPlans;
  List<Trip> get savedTrips => _savedTrips;
  Trip? get currentTrip => _currentTrip;
  List<FlightPlan> get currentTripPlans => _currentTripPlans;

  FlightPlanService({AircraftService? aircraftService})
    : _aircraftService = aircraftService;

  // Set the tile download service for automatic map tile downloads
  void setTileDownloadService(FlightPlanTileDownloadService service) {
    _tileDownloadService = service;
  }

  // Set the context for showing notifications
  void setContext(BuildContext context) {
    _context = context;
  }

  // Initialize Hive boxes for flight plans and trips
  Future<void> initialize() async {
    try {
      _flightPlanBox = await Hive.openBox<FlightPlan>('flight_plans');
      _tripBox = await Hive.openBox<Trip>('trips');
      _loadSavedFlightPlans();
      _loadSavedTrips();
    } catch (e) {
      // debugPrint('Error initializing flight plan service: $e');
    }
  }

  // Load saved flight plans from storage
  void _loadSavedFlightPlans() {
    if (_flightPlanBox != null) {
      _savedFlightPlans = _flightPlanBox!.values.toList();
      _savedFlightPlans.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    }
  }

  // Load saved trips from storage
  void _loadSavedTrips() {
    if (_tripBox != null) {
      _savedTrips = _tripBox!.values.toList();
      _savedTrips.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    }
  }

  // Save current flight plan to storage
  Future<void> saveCurrentFlightPlan({String? customName}) async {
    if (_currentFlightPlan == null || _flightPlanBox == null) return;

    if (customName != null && customName.isNotEmpty) {
      _currentFlightPlan!.name = customName;
    }

    _currentFlightPlan!.modifiedAt = DateTime.now();

    try {
      await _flightPlanBox!.put(_currentFlightPlan!.id, _currentFlightPlan!);
      _loadSavedFlightPlans();
      // debugPrint('Flight plan saved: ${_currentFlightPlan!.name}');
      
      // Trigger automatic tile download if service is available
      if (_tileDownloadService != null && _context != null && _currentFlightPlan!.waypoints.isNotEmpty) {
        _tileDownloadService!.downloadTilesForFlightPlan(
          flightPlan: _currentFlightPlan!,
          context: _context!,
        );
      }
    } catch (e) {
      // debugPrint('Error saving flight plan: $e');
    }
  }

  // Load a flight plan from storage
  void loadFlightPlan(String flightPlanId) {
    final flightPlan = _savedFlightPlans.firstWhere(
      (fp) => fp.id == flightPlanId,
      orElse: () => throw Exception('Flight plan not found'),
    );

    _currentFlightPlan = flightPlan;
    // Clear trip data when loading a single flight plan
    _currentTrip = null;
    _currentTripPlans.clear();
    // Planning mode is NOT automatically enabled when loading a flight plan
    // Users must explicitly enable it if they want to edit
    _isPlanning = false;
    _waypointCounter = flightPlan.waypoints.length + 1;
    notifyListeners();
    
    // Call the callback if it's set (to focus map on first waypoint)
    if (onFlightPlanLoaded != null) {
      onFlightPlanLoaded!(flightPlan);
    }
  }

  // Delete a flight plan from storage
  Future<void> deleteFlightPlan(String flightPlanId) async {
    if (_flightPlanBox == null) return;

    try {
      await _flightPlanBox!.delete(flightPlanId);
      _loadSavedFlightPlans();

      // If the deleted flight plan is currently loaded, clear it
      if (_currentFlightPlan?.id == flightPlanId) {
        clearFlightPlan();
      }

      // debugPrint('Flight plan deleted: $flightPlanId');
    } catch (e) {
      // debugPrint('Error deleting flight plan: $e');
    }
  }

  // Duplicate a flight plan
  Future<void> duplicateFlightPlan(String flightPlanId) async {
    final originalPlan = _savedFlightPlans.firstWhere(
      (fp) => fp.id == flightPlanId,
      orElse: () => throw Exception('Flight plan not found'),
    );

    final duplicatedPlan = FlightPlan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: '${originalPlan.name} (Copy)',
      createdAt: DateTime.now(),
      waypoints: originalPlan.waypoints
          .map(
            (wp) => Waypoint(
              id: DateTime.now().millisecondsSinceEpoch.toString() + wp.id,
              latitude: wp.latitude,
              longitude: wp.longitude,
              altitude: wp.altitude,
              name: wp.name,
              notes: wp.notes,
              type: wp.type,
            ),
          )
          .toList(),
      aircraftId: originalPlan.aircraftId,
      cruiseSpeed: originalPlan.cruiseSpeed,
      flightRules: originalPlan.flightRules,
      fuelConsumptionRate: originalPlan.fuelConsumptionRate,
    );

    if (_flightPlanBox != null) {
      try {
        await _flightPlanBox!.put(duplicatedPlan.id, duplicatedPlan);
        _loadSavedFlightPlans();
        // debugPrint('Flight plan duplicated: ${duplicatedPlan.name}');
      } catch (e) {
        // debugPrint('Error duplicating flight plan: $e');
      }
    }
  }

  // Add a flight plan to an existing trip or create a new trip
  Future<void> addFlightPlanToTrip(FlightPlan newFlightPlan) async {
    if (_currentTrip != null) {
      // Add to existing trip
      debugPrint('Adding flight plan ${newFlightPlan.id} to existing trip ${_currentTrip!.id}');
      
      // Set trip properties on the new flight plan
      newFlightPlan.tripId = _currentTrip!.id;
      newFlightPlan.legNumber = _currentTripPlans.length;
      newFlightPlan.legColor = TripColors.getColorValueForLeg(_currentTripPlans.length);
      newFlightPlan.modifiedAt = DateTime.now();
      
      // Add to trip's flight plan list
      _currentTrip!.flightPlanIds.add(newFlightPlan.id);
      
      // Save the updated flight plan
      if (_flightPlanBox != null) {
        await _flightPlanBox!.put(newFlightPlan.id, newFlightPlan);
      }
      
      // Save the updated trip
      if (_tripBox != null) {
        await _tripBox!.put(_currentTrip!.id, _currentTrip!);
      }
      
      // Add to current trip plans
      _currentTripPlans.add(newFlightPlan);
      
      debugPrint('Trip ${_currentTrip!.id} now has ${_currentTripPlans.length} legs');
      
      // Reload to refresh the UI
      _loadSavedTrips();
      _loadSavedFlightPlans();
      notifyListeners();
      
    } else if (_currentFlightPlan != null && _currentFlightPlan!.waypoints.isNotEmpty) {
      // Create a new trip from current flight plan and the new one
      debugPrint('Creating new trip from current flight plan ${_currentFlightPlan!.id} and new flight plan ${newFlightPlan.id}');
      
      // Save current flight plan first if it has changes
      await saveCurrentFlightPlan();
      
      // Create trip name from the two flight plan names
      final tripName = '${_currentFlightPlan!.name} + ${newFlightPlan.name}';
      
      // Create a new trip with both flight plans
      await createTripFromFlightPlans([_currentFlightPlan!, newFlightPlan], tripName);
    } else {
      // No current flight plan, just load the new one
      debugPrint('No current flight plan, loading new flight plan ${newFlightPlan.id}');
      loadFlightPlan(newFlightPlan.id);
    }
  }

  // Create trip from multiple flight plans
  Future<Trip> createTripFromFlightPlans(
    List<FlightPlan> flightPlans, 
    String tripName,
  ) async {
    if (flightPlans.isEmpty) {
      throw Exception('Cannot create trip from empty flight plans');
    }

    final trip = Trip(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: tripName,
      createdAt: DateTime.now(),
      flightPlanIds: [],
      aircraftId: flightPlans.first.aircraftId,
    );

    // Update flight plans to be part of the trip and assign colors
    debugPrint('Creating trip with ${flightPlans.length} flight plans');
    for (int i = 0; i < flightPlans.length; i++) {
      final plan = flightPlans[i];
      plan.tripId = trip.id;
      plan.legNumber = i;
      plan.legColor = TripColors.getColorValueForLeg(i);
      plan.modifiedAt = DateTime.now();
      
      trip.flightPlanIds.add(plan.id);
      debugPrint('Added flight plan ${plan.id} (${plan.name}) to trip as leg $i');
      
      // Save updated flight plan
      if (_flightPlanBox != null) {
        await _flightPlanBox!.put(plan.id, plan);
      }
    }
    debugPrint('Trip ${trip.id} now has ${trip.flightPlanIds.length} flight plans');

    // Save trip
    if (_tripBox != null) {
      await _tripBox!.put(trip.id, trip);
      debugPrint('Saved trip to Hive with ${trip.flightPlanIds.length} flight plan IDs');
      _loadSavedTrips();
      _loadSavedFlightPlans();
      
      // Verify the trip was saved correctly
      final savedTrip = _tripBox!.get(trip.id);
      if (savedTrip != null) {
        debugPrint('Verified saved trip has ${savedTrip.flightPlanIds.length} flight plans');
      }
    }

    // Load the newly created trip so it's displayed on the map
    debugPrint('Loading newly created trip ${trip.id}');
    loadTrip(trip.id);

    return trip;
  }

  // Load a trip and its associated flight plans
  void loadTrip(String tripId) {
    final trip = _savedTrips.firstWhere(
      (t) => t.id == tripId,
      orElse: () => throw Exception('Trip not found'),
    );

    _currentTrip = trip;
    
    // Load all flight plans associated with the trip
    _currentTripPlans.clear();
    debugPrint('Loading trip ${trip.id} with ${trip.flightPlanIds.length} flight plans');
    for (final planId in trip.flightPlanIds) {
      final plan = _savedFlightPlans.firstWhere(
        (fp) => fp.id == planId,
        orElse: () => throw Exception('Flight plan $planId not found'),
      );
      _currentTripPlans.add(plan);
      debugPrint('Loaded flight plan ${plan.id} (${plan.name}) for trip');
    }
    debugPrint('Trip loaded with ${_currentTripPlans.length} flight plans');

    // Set the first flight plan as the current one for editing/viewing
    if (_currentTripPlans.isNotEmpty) {
      _currentFlightPlan = _currentTripPlans.first;
      _isPlanning = false;
      notifyListeners();
      
      // Call the callback if set
      if (onFlightPlanLoaded != null) {
        onFlightPlanLoaded!(_currentTripPlans.first);
      }
    }
  }

  // Start creating a new flight plan
  void startNewFlightPlan({String? name, bool enablePlanning = true}) {
    _currentFlightPlan = FlightPlan(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name ?? 'Flight Plan ${DateTime.now().day}/${DateTime.now().month}',
      createdAt: DateTime.now(),
      waypoints: [],
    );
    _isPlanning = enablePlanning;
    _waypointCounter = 1;
    notifyListeners();
  }

  // Create a new flight plan with a generic sequential name
  void createNewFlightPlan({bool enablePlanning = false}) {
    // Count existing flight plans to generate a unique number
    int planNumber = _savedFlightPlans.length + 1;
    String planName = 'Flight Plan $planNumber';

    // Check if name already exists and increment if needed
    while (_savedFlightPlans.any((fp) => fp.name == planName)) {
      planNumber++;
      planName = 'Flight Plan $planNumber';
    }

    startNewFlightPlan(name: planName, enablePlanning: enablePlanning);
  }

  // Add a waypoint by clicking on the map
  void addWaypoint(LatLng position, {double? altitude}) {
    if (_currentFlightPlan == null || !_isPlanning) {
      // Don't add waypoints if there's no flight plan or planning mode is disabled
      return;
    }

    // If altitude not specified, use previous waypoint's altitude or default
    double waypointAltitude =
        altitude ??
        (_currentFlightPlan!.waypoints.isNotEmpty
            ? _currentFlightPlan!.waypoints.last.altitude
            : 3000.0);

    final waypoint = Waypoint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: waypointAltitude,
      name: 'WP${_waypointCounter++}',
      type: WaypointType.user,
    );

    _currentFlightPlan!.waypoints.add(waypoint);
    _currentFlightPlan!.modifiedAt = DateTime.now();
    notifyListeners();
  }

  // Insert a waypoint at a specific index in the flight path
  void insertWaypointAt(int index, LatLng position, {double? altitude}) {
    if (_currentFlightPlan == null || !_isPlanning) {
      return;
    }

    // Clamp index to valid range
    final clampedIndex = index.clamp(0, _currentFlightPlan!.waypoints.length);

    // Calculate altitude based on neighboring waypoints if not specified
    double waypointAltitude = altitude ?? 3000.0;
    if (altitude == null && _currentFlightPlan!.waypoints.isNotEmpty) {
      if (clampedIndex == 0) {
        // Insert at beginning - use first waypoint's altitude
        waypointAltitude = _currentFlightPlan!.waypoints.first.altitude;
      } else if (clampedIndex >= _currentFlightPlan!.waypoints.length) {
        // Insert at end - use last waypoint's altitude
        waypointAltitude = _currentFlightPlan!.waypoints.last.altitude;
      } else {
        // Insert in middle - interpolate between adjacent waypoints
        final prevAlt = _currentFlightPlan!.waypoints[clampedIndex - 1].altitude;
        final nextAlt = _currentFlightPlan!.waypoints[clampedIndex].altitude;
        waypointAltitude = (prevAlt + nextAlt) / 2;
      }
    }

    final waypoint = Waypoint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      latitude: position.latitude,
      longitude: position.longitude,
      altitude: waypointAltitude,
      name: 'WP${_waypointCounter++}',
      type: WaypointType.user,
    );

    _currentFlightPlan!.waypoints.insert(clampedIndex, waypoint);
    _currentFlightPlan!.modifiedAt = DateTime.now();
    notifyListeners();
  }

  // Add waypoint from airport
  void addAirportWaypoint(Airport airport, {double altitude = 3000.0}) {
    if (_currentFlightPlan == null || !_isPlanning) {
      // Don't add waypoints if there's no flight plan or planning mode is disabled
      return;
    }

    final waypoint = Waypoint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      latitude: airport.position.latitude,
      longitude: airport.position.longitude,
      altitude: altitude,
      name: airport.name,
      notes: airport.icaoCode?.isNotEmpty == true
          ? airport.icaoCode!
          : (airport.iataCode ?? airport.icao),
      type: WaypointType.airport,
    );

    _currentFlightPlan!.waypoints.add(waypoint);
    _currentFlightPlan!.modifiedAt = DateTime.now();
    notifyListeners();
  }

  // Add waypoint from navaid
  void addNavaidWaypoint(Navaid navaid, {double altitude = 3000.0}) {
    if (_currentFlightPlan == null || !_isPlanning) {
      // Don't add waypoints if there's no flight plan or planning mode is disabled
      return;
    }

    final waypoint = Waypoint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      latitude: navaid.position.latitude,
      longitude: navaid.position.longitude,
      altitude: altitude,
      name: navaid.name,
      notes: navaid.ident,
      type: WaypointType.navaid,
    );

    _currentFlightPlan!.waypoints.add(waypoint);
    _currentFlightPlan!.modifiedAt = DateTime.now();
    notifyListeners();
  }

  // Add waypoint from reporting point
  void addReportingPointWaypoint(ReportingPoint reportingPoint, {double altitude = 3000.0}) {
    if (_currentFlightPlan == null || !_isPlanning) {
      // Don't add waypoints if there's no flight plan or planning mode is disabled
      return;
    }

    final waypoint = Waypoint(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      latitude: reportingPoint.position.latitude,
      longitude: reportingPoint.position.longitude,
      altitude: altitude,
      name: reportingPoint.displayName,
      notes: reportingPoint.type ?? 'Reporting Point',
      type: WaypointType.reportingPoint,
    );

    _currentFlightPlan!.waypoints.add(waypoint);
    _currentFlightPlan!.modifiedAt = DateTime.now();
    notifyListeners();
  }

  // Remove a waypoint by index
  void removeWaypoint(int index) {
    if (_currentFlightPlan != null &&
        index >= 0 &&
        index < _currentFlightPlan!.waypoints.length) {
      _currentFlightPlan!.waypoints.removeAt(index);
      _currentFlightPlan!.modifiedAt = DateTime.now();
      notifyListeners();
    }
  }

  // Remove the last waypoint from the current flight plan
  void removeLastWaypoint() {
    if (_currentFlightPlan != null &&
        _currentFlightPlan!.waypoints.isNotEmpty) {
      _currentFlightPlan!.waypoints.removeLast();
      _currentFlightPlan!.modifiedAt = DateTime.now();
      notifyListeners();
    }
  }

  // Update waypoint altitude (without validation - use updateWaypointAltitudeWithValidation for validated updates)
  void updateWaypointAltitude(int index, double altitude) {
    if (_currentFlightPlan != null &&
        index >= 0 &&
        index < _currentFlightPlan!.waypoints.length) {
      _currentFlightPlan!.waypoints[index].altitude = altitude;
      _currentFlightPlan!.modifiedAt = DateTime.now();
      notifyListeners();
    }
  }

  // Update waypoint name
  void updateWaypointName(int index, String? name) {
    if (_currentFlightPlan != null &&
        index >= 0 &&
        index < _currentFlightPlan!.waypoints.length) {
      _currentFlightPlan!.waypoints[index].name = name;
      _currentFlightPlan!.modifiedAt = DateTime.now();
      notifyListeners();
    }
  }

  // Update waypoint notes
  void updateWaypointNotes(int index, String? notes) {
    if (_currentFlightPlan != null &&
        index >= 0 &&
        index < _currentFlightPlan!.waypoints.length) {
      _currentFlightPlan!.waypoints[index].notes = notes;
      _currentFlightPlan!.modifiedAt = DateTime.now();
      notifyListeners();
    }
  }
  
  /// Update waypoint type (airport, navaid, user, etc.)
  void updateWaypointType(int index, WaypointType type) {
    if (_currentFlightPlan != null &&
        index >= 0 &&
        index < _currentFlightPlan!.waypoints.length) {
      _currentFlightPlan!.waypoints[index].type = type;
      _currentFlightPlan!.modifiedAt = DateTime.now();
      notifyListeners();
    }
  }

  // Update waypoint position (for drag and drop on map)
  void updateWaypointPosition(int index, LatLng newPosition, {bool isDragging = false}) {
    if (_currentFlightPlan != null &&
        index >= 0 &&
        index < _currentFlightPlan!.waypoints.length) {
      _currentFlightPlan!.waypoints[index].latitude = newPosition.latitude;
      _currentFlightPlan!.waypoints[index].longitude = newPosition.longitude;
      
      // Only update modified time when drag is complete
      if (!isDragging) {
        _currentFlightPlan!.modifiedAt = DateTime.now();
      }
      
      notifyListeners();
    }
  }

  // Update cruise speed
  void updateCruiseSpeed(double speed) {
    if (_currentFlightPlan != null) {
      _currentFlightPlan!.cruiseSpeed = speed;
      _currentFlightPlan!.modifiedAt = DateTime.now();
      notifyListeners();
    }
  }

  // Update fuel consumption rate
  void updateFuelConsumptionRate(double rate) {
    if (_currentFlightPlan != null) {
      _currentFlightPlan!.fuelConsumptionRate = rate;
      _currentFlightPlan!.modifiedAt = DateTime.now();
      notifyListeners();
    }
  }

  // Update aircraft and automatically set cruise speed and fuel consumption
  void updateAircraft(String? aircraftId) {
    final currentPlan = _currentFlightPlan;
    if (currentPlan != null) {
      currentPlan.aircraftId = aircraftId;

      // If we have an aircraft service and a valid aircraft ID, update the flight plan parameters
      if (_aircraftService != null && aircraftId != null) {
        final aircraft = _aircraftService.getAircraftById(aircraftId);
        if (aircraft != null) {
          currentPlan.cruiseSpeed = aircraft.cruiseSpeed.toDouble();
          currentPlan.fuelConsumptionRate = aircraft.fuelConsumption;
        }
      }

      currentPlan.modifiedAt = DateTime.now();
      notifyListeners();
    }
  }

  // Clear current flight plan
  void clearFlightPlan() {
    _currentFlightPlan = null;
    _currentTrip = null;
    _currentTripPlans.clear();
    _isPlanning = false;
    _waypointCounter = 1;
    notifyListeners();
  }

  // Toggle planning mode
  void togglePlanningMode() {
    _isPlanning = !_isPlanning;
    if (!_isPlanning && (_currentFlightPlan?.waypoints.isEmpty ?? true)) {
      clearFlightPlan();
    }
    notifyListeners();
  }

  // Toggle flight plan visibility on map
  void toggleFlightPlanVisibility() {
    _isFlightPlanVisible = !_isFlightPlanVisible;
    notifyListeners();
  }

  // Set flight plan visibility directly
  void setFlightPlanVisibility(bool visible) {
    if (_isFlightPlanVisible != visible) {
      _isFlightPlanVisible = visible;
      notifyListeners();
    }
  }

  // Get formatted flight plan summary
  String getFlightPlanSummary() {
    if (_currentFlightPlan == null || _currentFlightPlan!.waypoints.isEmpty) {
      return 'No flight plan';
    }

    final distance = _currentFlightPlan!.totalDistance;
    final time = _currentFlightPlan!.totalFlightTime;

    String summary = '${_currentFlightPlan!.waypoints.length} waypoints, ';
    summary += '${distance.toStringAsFixed(1)} NM';

    if (time > 0) {
      final hours = (time / 60).floor();
      final minutes = (time % 60).round();
      summary += ', ${hours}h ${minutes}m';
    }

    final fuelConsumption = _currentFlightPlan!.totalFuelConsumption;
    if (fuelConsumption > 0) {
      summary += ', ${fuelConsumption.toStringAsFixed(1)} gal';
    }

    return summary;
  }

  // Reorder waypoints (for drag and drop functionality)
  void reorderWaypoints(int oldIndex, int newIndex) {
    if (_currentFlightPlan != null &&
        oldIndex >= 0 &&
        oldIndex < _currentFlightPlan!.waypoints.length &&
        newIndex >= 0 &&
        newIndex < _currentFlightPlan!.waypoints.length) {
      // Adjust newIndex if moving down the list
      if (oldIndex < newIndex) {
        newIndex -= 1;
      }

      final waypoint = _currentFlightPlan!.waypoints.removeAt(oldIndex);
      _currentFlightPlan!.waypoints.insert(newIndex, waypoint);
      _currentFlightPlan!.modifiedAt = DateTime.now();
      notifyListeners();
    }
  }

  // Get the current aircraft for the flight plan
  Aircraft? _getCurrentAircraft() {
    final aircraftId = _currentFlightPlan?.aircraftId;
    if (aircraftId == null || _aircraftService == null) {
      return null;
    }
    return _aircraftService.getAircraftById(aircraftId);
  }

  // Calculate altitude change required between two waypoints based on aircraft climb/descent rates
  // Returns the altitude at the end waypoint considering the time to climb/descend
  double calculateAltitudeChange({
    required double startAltitude,
    required double targetAltitude,
    required double distanceNM,
    required double cruiseSpeedKnots,
    double? maxClimbRate,
    double? maxDescentRate,
  }) {
    // Calculate time available for altitude change (in minutes)
    final timeAvailableMinutes = (distanceNM / cruiseSpeedKnots) * 60;

    // Calculate altitude difference
    final altitudeDifference = targetAltitude - startAltitude;

    if (altitudeDifference > 0) {
      // Climbing
      if (maxClimbRate == null || maxClimbRate <= 0) {
        return targetAltitude; // No climb rate limit
      }

      // Calculate maximum altitude gain possible in available time
      final maxAltitudeGain = maxClimbRate * timeAvailableMinutes;

      // Return the achievable altitude
      return startAltitude +
          (altitudeDifference > maxAltitudeGain
              ? maxAltitudeGain
              : altitudeDifference);
    } else if (altitudeDifference < 0) {
      // Descending
      if (maxDescentRate == null || maxDescentRate <= 0) {
        return targetAltitude; // No descent rate limit
      }

      // Calculate maximum altitude loss possible in available time
      final maxAltitudeLoss = maxDescentRate * timeAvailableMinutes;

      // Return the achievable altitude (remember altitudeDifference is negative)
      return startAltitude -
          ((-altitudeDifference) > maxAltitudeLoss
              ? maxAltitudeLoss
              : (-altitudeDifference));
    }

    return targetAltitude; // No altitude change needed
  }

  // Cap altitude based on aircraft maximum altitude (service ceiling)
  double capAltitudeToServiceCeiling(
    double requestedAltitude, {
    double? serviceCeiling,
  }) {
    if (serviceCeiling == null || serviceCeiling <= 0) {
      return requestedAltitude; // No ceiling restriction
    }

    return requestedAltitude > serviceCeiling
        ? serviceCeiling
        : requestedAltitude;
  }

  // Validate and update waypoint altitude with aircraft performance constraints
  void updateWaypointAltitudeWithValidation(
    int index,
    double requestedAltitude,
  ) {
    if (_currentFlightPlan == null ||
        index < 0 ||
        index >= _currentFlightPlan!.waypoints.length) {
      return;
    }

    final aircraft = _getCurrentAircraft();
    double validatedAltitude = requestedAltitude;

    // First, cap the altitude to the service ceiling
    if (aircraft != null) {
      validatedAltitude = capAltitudeToServiceCeiling(
        requestedAltitude,
        serviceCeiling: aircraft.maximumAltitude.toDouble(),
      );
    }

    // If not the first waypoint, check if altitude change is achievable
    if (index > 0 && aircraft != null) {
      final previousWaypoint = _currentFlightPlan!.waypoints[index - 1];
      final currentWaypoint = _currentFlightPlan!.waypoints[index];

      // Calculate distance between waypoints
      final distance = previousWaypoint.distanceTo(currentWaypoint);

      // Use flight plan cruise speed or aircraft cruise speed
      final cruiseSpeed =
          _currentFlightPlan!.cruiseSpeed ?? aircraft.cruiseSpeed.toDouble();

      if (cruiseSpeed > 0 && distance > 0) {
        validatedAltitude = calculateAltitudeChange(
          startAltitude: previousWaypoint.altitude,
          targetAltitude: validatedAltitude,
          distanceNM: distance,
          cruiseSpeedKnots: cruiseSpeed,
          maxClimbRate: aircraft.maximumClimbRate.toDouble(),
          maxDescentRate: aircraft.maximumDescentRate.toDouble(),
        );
      }
    }

    // Update the waypoint altitude
    _currentFlightPlan!.waypoints[index].altitude = validatedAltitude;
    _currentFlightPlan!.modifiedAt = DateTime.now();
    notifyListeners();
  }

  // Calculate achievable altitudes for all waypoints based on aircraft performance
  void recalculateAllWaypointAltitudes() {
    if (_currentFlightPlan == null || _currentFlightPlan!.waypoints.isEmpty) {
      return;
    }

    final aircraft = _getCurrentAircraft();
    if (aircraft == null) {
      return; // Can't validate without aircraft data
    }

    final cruiseSpeed =
        _currentFlightPlan!.cruiseSpeed ?? aircraft.cruiseSpeed.toDouble();
    if (cruiseSpeed <= 0) {
      return; // Need valid cruise speed
    }

    // Process each waypoint after the first one
    for (int i = 1; i < _currentFlightPlan!.waypoints.length; i++) {
      final previousWaypoint = _currentFlightPlan!.waypoints[i - 1];
      final currentWaypoint = _currentFlightPlan!.waypoints[i];

      // Calculate distance between waypoints
      final distance = previousWaypoint.distanceTo(currentWaypoint);

      if (distance > 0) {
        // First cap to service ceiling
        var targetAltitude = capAltitudeToServiceCeiling(
          currentWaypoint.altitude,
          serviceCeiling: aircraft.maximumAltitude.toDouble(),
        );

        // Then calculate achievable altitude based on climb/descent rates
        targetAltitude = calculateAltitudeChange(
          startAltitude: previousWaypoint.altitude,
          targetAltitude: targetAltitude,
          distanceNM: distance,
          cruiseSpeedKnots: cruiseSpeed,
          maxClimbRate: aircraft.maximumClimbRate.toDouble(),
          maxDescentRate: aircraft.maximumDescentRate.toDouble(),
        );

        currentWaypoint.altitude = targetAltitude;
      }
    }

    _currentFlightPlan!.modifiedAt = DateTime.now();
    notifyListeners();
  }

  // Set aircraft for the flight plan
  void setAircraftForFlightPlan(String aircraftId) {
    if (_currentFlightPlan == null) return;

    _currentFlightPlan!.aircraftId = aircraftId;

    // Update cruise speed from aircraft if not already set
    final aircraft = _getCurrentAircraft();
    if (aircraft != null &&
        (_currentFlightPlan!.cruiseSpeed == null ||
            _currentFlightPlan!.cruiseSpeed == 0)) {
      _currentFlightPlan!.cruiseSpeed = aircraft.cruiseSpeed.toDouble();
    }

    _currentFlightPlan!.modifiedAt = DateTime.now();

    // Recalculate altitudes with new aircraft performance data
    recalculateAllWaypointAltitudes();

    notifyListeners();
  }

  @override
  void dispose() {
    // Close Hive boxes if open
    try {
      if (_flightPlanBox != null && _flightPlanBox!.isOpen) {
        _flightPlanBox!.close();
      }
      if (_tripBox != null && _tripBox!.isOpen) {
        _tripBox!.close();
      }
    } catch (e) {
      // Ignore errors during disposal
    }
    super.dispose();
  }
}
