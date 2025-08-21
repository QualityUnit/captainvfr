import 'package:hive/hive.dart';

part 'airspace_frequency.g.dart';

@HiveType(typeId: 31)
class AirspaceFrequency extends HiveObject {
  @HiveField(0)
  final double frequency;

  @HiveField(1)
  final String type;

  @HiveField(2)
  final String? description;

  @HiveField(3)
  final String? callsign;

  AirspaceFrequency({
    required this.frequency,
    required this.type,
    this.description,
    this.callsign,
  });

  /// Create from JSON data (OpenAIP format)
  factory AirspaceFrequency.fromJson(Map<String, dynamic> json) {
    return AirspaceFrequency(
      frequency: _parseFrequency(json['frequency']),
      type: _mapFrequencyType(json['type']?.toString() ?? ''),
      description: json['description']?.toString() ?? json['name']?.toString(),
      callsign: json['callsign']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'frequency': frequency,
      'type': type,
      'description': description,
      'callsign': callsign,
    };
  }

  /// Parse frequency from various formats
  static double _parseFrequency(dynamic frequency) {
    if (frequency == null) return 0.0;

    if (frequency is num) {
      return frequency.toDouble();
    }

    if (frequency is String) {
      // Remove any non-numeric characters except decimal point
      final cleaned = frequency.replaceAll(RegExp(r'[^\d.]'), '');
      return double.tryParse(cleaned) ?? 0.0;
    }

    return 0.0;
  }

  /// Map frequency types to standard aviation types
  static String _mapFrequencyType(String type) {
    switch (type.toUpperCase()) {
      case 'AFIS':
        return 'AFIS';
      case 'APP':
      case 'APPROACH':
        return 'APP';
      case 'CTR':
      case 'CONTROL':
      case 'CENTRE':
      case 'CENTER':
        return 'CTR';
      case 'DEL':
      case 'DELIVERY':
        return 'DEL';
      case 'DEP':
      case 'DEPARTURE':
        return 'DEP';
      case 'FIS':
        return 'FIS';
      case 'GND':
      case 'GROUND':
        return 'GND';
      case 'INFO':
        return 'INFO';
      case 'RADAR':
        return 'RADAR';
      case 'RADIO':
        return 'RADIO';
      case 'TML':
      case 'TERMINAL':
        return 'TML';
      case 'TWR':
      case 'TOWER':
        return 'TWR';
      case 'UNICOM':
        return 'UNICOM';
      default:
        return type.toUpperCase();
    }
  }

  /// Validate that frequency is in VHF aviation range
  bool get isValidAviationFrequency {
    return frequency >= 118.000 && frequency <= 136.975;
  }

  /// Format frequency for display (3 decimal places)
  String get formattedFrequency {
    return '${frequency.toStringAsFixed(3)} MHz';
  }

  /// Get display name for frequency type
  String get displayType {
    switch (type) {
      case 'AFIS':
        return 'AFIS';
      case 'APP':
        return 'Approach';
      case 'CTR':
        return 'Control';
      case 'DEL':
        return 'Delivery';
      case 'DEP':
        return 'Departure';
      case 'FIS':
        return 'Flight Info';
      case 'GND':
        return 'Ground';
      case 'INFO':
        return 'Information';
      case 'RADAR':
        return 'Radar';
      case 'RADIO':
        return 'Radio';
      case 'TML':
        return 'Terminal';
      case 'TWR':
        return 'Tower';
      case 'UNICOM':
        return 'UNICOM';
      default:
        return type;
    }
  }

  /// Get display text combining callsign and description
  String get displayName {
    if (callsign != null && description != null) {
      return '$callsign - $description';
    }
    return callsign ?? description ?? displayType;
  }

  @override
  String toString() {
    return 'AirspaceFrequency(frequency: $frequency, type: $type, description: $description, callsign: $callsign)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AirspaceFrequency &&
        (frequency - other.frequency).abs() < 0.001 &&
        type == other.type &&
        description == other.description &&
        callsign == other.callsign;
  }

  @override
  int get hashCode {
    return Object.hash(frequency, type, description, callsign);
  }
}