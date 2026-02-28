import 'package:flutter/foundation.dart';
import 'dart:async';
import 'flight_service.dart';
import '../services/aircraft_settings_service.dart';

/// Service for fuel management and alerts
class FuelAlertService extends ChangeNotifier {
  final FlightService _flightService;
  final AircraftSettingsService _aircraftService;
  
  Timer? _checkTimer;
  FuelAlert? _currentAlert;
  
  // Default reserve fuel (in gallons)
  double _reserveFuel = 5.0;
  
  FuelAlertService(this._flightService, this._aircraftService) {
    _startMonitoring();
  }
  
  FuelAlert? get currentAlert => _currentAlert;
  double get reserveFuel => _reserveFuel;
  
  set reserveFuel(double value) {
    _reserveFuel = value;
    notifyListeners();
  }
  
  void _startMonitoring() {
    // Check fuel every 30 seconds during flight
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_flightService.isTracking) {
        _checkFuelLevel();
      }
    });
  }
  
  void _checkFuelLevel() {
    final aircraft = _aircraftService.selectedAircraft;
    if (aircraft == null) return;
    
    final fuelUsed = _flightService.fuelUsed;
    final fuelCapacity = aircraft.fuelCapacity;
    
    // Assume we started with full tanks
    final fuelRemaining = fuelCapacity - fuelUsed;
    final fuelPercentage = (fuelRemaining / fuelCapacity) * 100;
    
    // Determine alert level
    FuelAlertLevel? alertLevel;
    String? message;
    
    if (fuelRemaining <= _reserveFuel) {
      alertLevel = FuelAlertLevel.critical;
      message = 'FUEL CRITICAL! ${fuelRemaining.toStringAsFixed(1)} gal remaining';
    } else if (fuelRemaining <= _reserveFuel * 2) {
      alertLevel = FuelAlertLevel.warning;
      message = 'Low Fuel Warning: ${fuelRemaining.toStringAsFixed(1)} gal remaining';
    } else if (fuelPercentage <= 25) {
      alertLevel = FuelAlertLevel.caution;
      message = 'Fuel Caution: ${fuelPercentage.toStringAsFixed(0)}% remaining';
    }
    
    if (alertLevel != null && message != null) {
      _currentAlert = FuelAlert(
        level: alertLevel,
        message: message,
        fuelRemaining: fuelRemaining,
        fuelUsed: fuelUsed,
        fuelCapacity: fuelCapacity,
        fuelPercentage: fuelPercentage,
        timestamp: DateTime.now(),
      );
      notifyListeners();
    } else if (_currentAlert != null) {
      // Clear alert if fuel is sufficient
      _currentAlert = null;
      notifyListeners();
    }
  }
  
  /// Calculate estimated range based on current fuel consumption
  double calculateRange() {
    final aircraft = _aircraftService.selectedAircraft;
    if (aircraft == null) return 0.0;
    
    final fuelUsed = _flightService.fuelUsed;
    final flightDuration = _flightService.currentFlightDuration;
    
    if (flightDuration.inMinutes == 0 || fuelUsed == 0) {
      return 0.0;
    }
    
    // Calculate fuel consumption rate (gallons per hour)
    final fuelRate = fuelUsed / (flightDuration.inMinutes / 60.0);
    
    // Calculate remaining fuel
    final fuelRemaining = aircraft.fuelCapacity - fuelUsed - _reserveFuel;
    
    if (fuelRemaining <= 0 || fuelRate == 0) {
      return 0.0;
    }
    
    // Calculate endurance (hours)
    final endurance = fuelRemaining / fuelRate;
    
    // Calculate range (nautical miles)
    final groundSpeed = _flightService.currentSpeed;
    return endurance * groundSpeed;
  }
  
  /// Calculate estimated time to reserve fuel
  Duration calculateTimeToReserve() {
    final aircraft = _aircraftService.selectedAircraft;
    if (aircraft == null) return Duration.zero;
    
    final fuelUsed = _flightService.fuelUsed;
    final flightDuration = _flightService.currentFlightDuration;
    
    if (flightDuration.inMinutes == 0 || fuelUsed == 0) {
      return Duration.zero;
    }
    
    // Calculate fuel consumption rate (gallons per hour)
    final fuelRate = fuelUsed / (flightDuration.inMinutes / 60.0);
    
    // Calculate remaining fuel until reserve
    final fuelUntilReserve = aircraft.fuelCapacity - fuelUsed - _reserveFuel;
    
    if (fuelUntilReserve <= 0 || fuelRate == 0) {
      return Duration.zero;
    }
    
    // Calculate time (hours)
    final timeHours = fuelUntilReserve / fuelRate;
    return Duration(minutes: (timeHours * 60).round());
  }
  
  void clearAlert() {
    _currentAlert = null;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}

enum FuelAlertLevel {
  critical,
  warning,
  caution,
}

class FuelAlert {
  final FuelAlertLevel level;
  final String message;
  final double fuelRemaining;
  final double fuelUsed;
  final double fuelCapacity;
  final double fuelPercentage;
  final DateTime timestamp;
  
  FuelAlert({
    required this.level,
    required this.message,
    required this.fuelRemaining,
    required this.fuelUsed,
    required this.fuelCapacity,
    required this.fuelPercentage,
    required this.timestamp,
  });
}
