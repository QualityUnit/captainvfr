import 'package:hive/hive.dart';
import 'flight_plan.dart';

part 'trip.g.dart';

@HiveType(typeId: 14)
class Trip extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  DateTime createdAt;

  @HiveField(3)
  DateTime? modifiedAt;

  @HiveField(4)
  List<String> flightPlanIds; // References to flight plans in order

  @HiveField(5)
  String? aircraftId; // Default aircraft for the trip

  Trip({
    required this.id,
    required this.name,
    required this.createdAt,
    this.modifiedAt,
    required this.flightPlanIds,
    this.aircraftId,
  });

  // Calculate total trip distance from all legs
  double getTotalDistance(List<FlightPlan> flightPlans) {
    double total = 0.0;
    for (final planId in flightPlanIds) {
      final plan = flightPlans.where((fp) => fp.id == planId).firstOrNull;
      if (plan != null) {
        total += plan.totalDistance;
      }
    }
    return total;
  }

  // Calculate total trip flight time from all legs
  double getTotalFlightTime(List<FlightPlan> flightPlans) {
    double total = 0.0;
    for (final planId in flightPlanIds) {
      final plan = flightPlans.where((fp) => fp.id == planId).firstOrNull;
      if (plan != null) {
        total += plan.totalFlightTime;
      }
    }
    return total;
  }

  // Get number of legs
  int get legCount => flightPlanIds.length;
}