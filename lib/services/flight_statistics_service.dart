import 'package:flutter/foundation.dart';
import '../models/flight.dart';
import 'flight_service.dart';

/// Service for calculating and managing flight statistics
class FlightStatisticsService extends ChangeNotifier {
  final FlightService _flightService;
  
  FlightStatisticsService(this._flightService) {
    _flightService.addListener(_onFlightsUpdated);
  }
  
  void _onFlightsUpdated() {
    notifyListeners();
  }
  
  /// Get total flight hours
  double get totalHours {
    return _flightService.flights.fold<double>(
      0.0,
      (sum, flight) => sum + flight.duration.inMinutes / 60.0,
    );
  }
  
  /// Get total distance flown (in nautical miles)
  double get totalDistance {
    return _flightService.flights.fold<double>(
      0.0,
      (sum, flight) => sum + flight.distance,
    );
  }
  
  /// Get total number of flights
  int get totalFlights => _flightService.flights.length;
  
  /// Get unique airports visited
  Set<String> get airportsVisited {
    final airports = <String>{};
    for (final flight in _flightService.flights) {
      if (flight.departureAirport != null) {
        airports.add(flight.departureAirport!);
      }
      if (flight.arrivalAirport != null) {
        airports.add(flight.arrivalAirport!);
      }
    }
    return airports;
  }
  
  /// Get flights this month
  List<Flight> get flightsThisMonth {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    
    return _flightService.flights.where((flight) {
      return flight.startTime.isAfter(startOfMonth);
    }).toList();
  }
  
  /// Get flights this year
  List<Flight> get flightsThisYear {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    
    return _flightService.flights.where((flight) {
      return flight.startTime.isAfter(startOfYear);
    }).toList();
  }
  
  /// Get hours this month
  double get hoursThisMonth {
    return flightsThisMonth.fold<double>(
      0.0,
      (sum, flight) => sum + flight.duration.inMinutes / 60.0,
    );
  }
  
  /// Get hours this year
  double get hoursThisYear {
    return flightsThisYear.fold<double>(
      0.0,
      (sum, flight) => sum + flight.duration.inMinutes / 60.0,
    );
  }
  
  /// Get average flight duration
  Duration get averageFlightDuration {
    if (_flightService.flights.isEmpty) return Duration.zero;
    
    final totalMinutes = _flightService.flights.fold<int>(
      0,
      (sum, flight) => sum + flight.duration.inMinutes,
    );
    
    return Duration(minutes: totalMinutes ~/ _flightService.flights.length);
  }
  
  /// Get longest flight
  Flight? get longestFlight {
    if (_flightService.flights.isEmpty) return null;
    
    return _flightService.flights.reduce((a, b) {
      return a.duration > b.duration ? a : b;
    });
  }
  
  /// Get highest altitude reached
  double get highestAltitude {
    return _flightService.flights.fold<double>(
      0.0,
      (max, flight) => flight.maxAltitude > max ? flight.maxAltitude : max,
    );
  }
  
  /// Get fastest speed reached
  double get fastestSpeed {
    return _flightService.flights.fold<double>(
      0.0,
      (max, flight) => flight.maxSpeed > max ? flight.maxSpeed : max,
    );
  }
  
  /// Get flights by month for the current year
  Map<int, List<Flight>> get flightsByMonth {
    final now = DateTime.now();
    final flightsByMonth = <int, List<Flight>>{};
    
    for (int month = 1; month <= 12; month++) {
      flightsByMonth[month] = [];
    }
    
    for (final flight in flightsThisYear) {
      final month = flight.startTime.month;
      flightsByMonth[month]!.add(flight);
    }
    
    return flightsByMonth;
  }
  
  /// Get hours by month for the current year
  Map<int, double> get hoursByMonth {
    final flightsByMonth = this.flightsByMonth;
    final hoursByMonth = <int, double>{};
    
    for (final entry in flightsByMonth.entries) {
      hoursByMonth[entry.key] = entry.value.fold<double>(
        0.0,
        (sum, flight) => sum + flight.duration.inMinutes / 60.0,
      );
    }
    
    return hoursByMonth;
  }
  
  /// Get recent flights (last 10)
  List<Flight> get recentFlights {
    final flights = List<Flight>.from(_flightService.flights);
    flights.sort((a, b) => b.startTime.compareTo(a.startTime));
    return flights.take(10).toList();
  }
  
  /// Get total fuel used
  double get totalFuelUsed {
    return _flightService.flights.fold<double>(
      0.0,
      (sum, flight) => sum + flight.fuelUsed,
    );
  }
  
  @override
  void dispose() {
    _flightService.removeListener(_onFlightsUpdated);
    super.dispose();
  }
}
