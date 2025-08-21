import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Utility functions for converting OpenAIP airspace numeric values to human-readable text
class AirspaceUtils {
  /// Convert numeric airspace type to human-readable text
  static String getAirspaceTypeName(String? type) {
    if (type == null) return 'Unknown';

    // If it's already a string name, return it
    if (!RegExp(r'^\d+$').hasMatch(type)) {
      return type;
    }

    // Convert numeric values to airspace types
    // Note: These mappings are based on common OpenAIP conventions
    // The exact mapping should be verified with OpenAIP documentation
    switch (type) {
      case '0':
        return 'CTR'; // Control Zone
      case '1':
        return 'TMA'; // Terminal Maneuvering Area
      case '2':
        return 'TMZ'; // Transponder Mandatory Zone
      case '3':
        return 'RMZ'; // Radio Mandatory Zone
      case '4':
        return 'ATZ'; // Aerodrome Traffic Zone
      case '5':
        return 'DANGER'; // Danger Area
      case '6':
        return 'PROHIBITED'; // Prohibited Area
      case '7':
        return 'RESTRICTED'; // Restricted Area
      case '8':
        return 'GLIDING'; // Gliding Area
      case '9':
        return 'WAVE'; // Wave Area
      case '10':
        return 'TSA'; // Temporary Segregated Area
      case '11':
        return 'TRA'; // Temporary Reserved Area
      case '12':
        return 'MATZ'; // Military Aerodrome Traffic Zone
      case '13':
        return 'AERIAL_SPORTING_RECREATIONAL';
      case '14':
        return 'WARNING';
      case '15':
        return 'TRAINING';
      case '16':
        return 'INFO'; // Flight Information Region
      default:
        return 'Type $type';
    }
  }

  /// Convert numeric ICAO class to letter designation
  static String getIcaoClassName(String? icaoClass) {
    if (icaoClass == null) return 'Unclassified';

    // If it's already a letter, return it
    if (!RegExp(r'^\d+$').hasMatch(icaoClass)) {
      return icaoClass;
    }

    // Convert numeric values to ICAO classes
    switch (icaoClass) {
      case '0':
        return 'A';
      case '1':
        return 'B';
      case '2':
        return 'C';
      case '3':
        return 'D';
      case '4':
        return 'E';
      case '5':
        return 'F';
      case '6':
        return 'G';
      default:
        return 'Class $icaoClass';
    }
  }

  /// Convert numeric activity type to human-readable text
  static String getActivityName(String? activity) {
    if (activity == null) return 'No specific activity';

    // If it's already a string name, return it
    if (!RegExp(r'^\d+$').hasMatch(activity)) {
      return activity;
    }

    // Convert numeric values to activity types
    // Note: These are estimated based on common aviation activities
    switch (activity) {
      case '0':
        return 'None';
      case '1':
        return 'Parachuting';
      case '2':
        return 'Hang gliding';
      case '3':
        return 'Paragliding';
      case '4':
        return 'Ballooning';
      case '5':
        return 'Gliding';
      case '6':
        return 'Aerobatics';
      case '7':
        return 'Model flying';
      case '8':
        return 'UAV/Drone operations';
      case '9':
        return 'Military operations';
      case '10':
        return 'Training';
      case '11':
        return 'Test flying';
      case '12':
        return 'Other aerial work';
      default:
        return 'Activity $activity';
    }
  }

  /// Get a description for the airspace type
  static String getAirspaceTypeDescription(String? type) {
    final typeName = getAirspaceTypeName(type);

    switch (typeName) {
      case 'CTR':
        return 'Control Zone - Controlled airspace around an airport';
      case 'TMA':
        return 'Terminal Maneuvering Area - Controlled airspace for approach/departure';
      case 'TMZ':
        return 'Transponder Mandatory Zone - Transponder required';
      case 'RMZ':
        return 'Radio Mandatory Zone - Radio contact required';
      case 'ATZ':
        return 'Aerodrome Traffic Zone - Traffic pattern area';
      case 'DANGER':
        return 'Danger Area - Activities dangerous to aircraft';
      case 'PROHIBITED':
        return 'Prohibited Area - Flight prohibited';
      case 'RESTRICTED':
        return 'Restricted Area - Permission required';
      case 'GLIDING':
        return 'Gliding Area - Glider operations';
      case 'WAVE':
        return 'Wave Area - Mountain wave soaring';
      case 'TSA':
        return 'Temporary Segregated Area';
      case 'TRA':
        return 'Temporary Reserved Area';
      case 'MATZ':
        return 'Military Aerodrome Traffic Zone';
      default:
        return typeName;
    }
  }

  /// Get the display name for altitude reference
  static String getAltitudeReferenceName(String? reference) {
    if (reference == null) return '';

    switch (reference.toUpperCase()) {
      case 'MSL':
      case '0':
      case '1':
        return 'MSL'; // Mean Sea Level
      case 'AGL':
      case '2':
        return 'AGL'; // Above Ground Level
      case 'FL':
      case '3':
        return 'FL'; // Flight Level
      default:
        return reference;
    }
  }

  /// Get color for airspace type and ICAO class following aviation standards.
  /// 
  /// This method handles string-based type values (e.g., "CTR", "ATZ", "DANGER")
  /// which are commonly used in airspace data sources.
  /// 
  /// [type] - The airspace type as a string (e.g., "CTR", "TMA", "ATZ")
  /// [icaoClass] - The ICAO classification if available (e.g., "A", "B", "C")
  /// 
  /// Returns a Color following aviation conventions:
  /// - Red tones for restrictive airspace (CTR, prohibited, danger)
  /// - Blue tones for controlled airspace (TMA, Class C/D)
  /// - Green tones for less restrictive areas (gliding, Class E)
  /// - Orange/amber for special requirements (TMZ, RMZ, restricted)
  /// 
  /// Falls back to light blue for unknown types to maintain visibility.
  static Color getAirspaceColorByString(String? type, String? icaoClass) {
    // Handle string type values (like "CTR", "ATZ", "DANGER")
    if (type != null) {
      switch (type.toUpperCase()) {
        case 'CTR': // Control Zone
          return AppColors.airspaceCTR;
        case 'TMA': // Terminal Maneuvering Area
          return AppColors.airspaceTMA;
        case 'TMZ': // Transponder Mandatory Zone
          return AppColors.airspaceTransponderMandatory;
        case 'RMZ': // Radio Mandatory Zone
          return AppColors.airspaceRadioMandatory;
        case 'ATZ': // Aerodrome Traffic Zone
          return AppColors.airspaceATZ;
        case 'DANGER':
        case 'D':
          return AppColors.airspaceDanger;
        case 'PROHIBITED':
        case 'P':
          return AppColors.airspaceProhibited;
        case 'RESTRICTED':
        case 'R':
          return AppColors.airspaceRestricted;
        case 'GLIDING':
        case 'GLIDER':
          return AppColors.airspaceGliderProhibited;
        case 'WAVE':
          return AppColors.airspaceWaveWindow;
        case 'TSA': // Temporary Segregated Area
        case 'TRA': // Temporary Reserved Area
        case 'TRAINING':
          return AppColors.airspaceTraining;
        case 'MATZ': // Military Aerodrome Traffic Zone
        case 'MTMA': // Military Terminal Maneuvering Area
          return AppColors.airspaceMATZ;
        case 'SPORT':
        case 'AERIAL_SPORTING':
        case 'RECREATIONAL':
          return AppColors.airspaceGliderProhibited;
        case 'WARNING':
          return AppColors.airspaceDanger;
        case 'FIR': // Flight Information Region
        case 'UIR': // Upper Information Region
          return AppColors.airspaceClassE; // Light green with transparency
        case 'OTHER':
          return AppColors.airspaceClassD; // Light blue for other/unknown
      }
    }
    
    // Check ICAO class if available
    if (icaoClass != null) {
      switch (icaoClass.toUpperCase()) {
        case 'A':
          return AppColors.airspaceClassA;
        case 'B':
          return AppColors.airspaceClassB;
        case 'C':
          return AppColors.airspaceClassC;
        case 'D':
          return AppColors.airspaceClassD;
        case 'E':
          return AppColors.airspaceClassE;
        case 'F':
          return AppColors.airspaceClassF;
        case 'G':
          return AppColors.airspaceClassG;
      }
    }
    
    // Default to light blue for unknown types
    return AppColors.airspaceClassD;
  }
  
  /// Get color for airspace type and ICAO class (numeric version).
  /// 
  /// This method handles numeric type codes used by some data sources.
  /// It converts numeric codes to their string equivalents and delegates
  /// to the string-based method to avoid code duplication.
  /// 
  /// [type] - The airspace type as a numeric code (0-16)
  /// [icaoClass] - The ICAO classification as a numeric code (0-6)
  /// 
  /// Returns a Color following aviation conventions.
  static Color getAirspaceColor(int type, int icaoClass) {
    // Convert numeric type to string equivalent
    String? typeString;
    switch (type) {
      case 0: typeString = 'CTR'; break;
      case 1: typeString = 'TMA'; break;
      case 2: typeString = 'TMZ'; break;
      case 3: typeString = 'RMZ'; break;
      case 4: typeString = 'ATZ'; break;
      case 5: typeString = 'DANGER'; break;
      case 6: typeString = 'PROHIBITED'; break;
      case 7: typeString = 'RESTRICTED'; break;
      case 8: typeString = 'GLIDING'; break;
      case 9: typeString = 'WAVE'; break;
      case 10: typeString = 'TSA'; break;
      case 11: typeString = 'TRA'; break;
      case 12: typeString = 'MATZ'; break;
      case 13: typeString = 'SPORT'; break;
      case 14: typeString = 'WARNING'; break;
      case 15: typeString = 'TRAINING'; break;
      case 16: typeString = 'FIR'; break;
    }
    
    // Convert numeric ICAO class to string equivalent
    String? icaoString;
    if (icaoClass >= 0 && icaoClass <= 6) {
      icaoString = String.fromCharCode('A'.codeUnitAt(0) + icaoClass);
    }
    
    // Delegate to string-based method
    return getAirspaceColorByString(typeString, icaoString);
  }

}
