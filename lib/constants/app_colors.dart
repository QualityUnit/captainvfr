import 'package:flutter/material.dart';

/// Application color constants
class AppColors {
  // Primary colors
  static const Color primaryAccent = Color(0xFF448AFF);
  static const Color primaryAccentDim = Color(0x7F448AFF);
  static const Color primaryAccentFaint = Color(0x33448AFF);
  static const Color primaryAccentVeryFaint = Color(0x1A448AFF);
  
  // Background colors
  static const Color backgroundColor = Color(0xFF000000);
  static const Color dialogBackgroundColor = Color(0xF0000000);
  static const Color sectionBackgroundColor = Color(0xFF0A0A1A);
  static const Color sectionBorderColor = Color(0xFF1A1A2E);
  static const Color fillColorFaint = Color(0x1AFFFFFF);
  
  // Text colors
  static const Color primaryTextColor = Color(0xFFFFFFFF);
  static const Color secondaryTextColor = Color(0xFFB3B3B3);
  static const Color tertiaryTextColor = Color(0xFF999999);
  static const Color labelTextColor = Color(0xFFCCCCCC);
  static const Color hintTextColor = Color(0xFF666666);
  static const Color disabledTextColor = Color(0xFF4D4D4D);
  
  // Status colors
  static const Color errorColor = Color(0xFFFF5252);
  static const Color warningColor = Color(0xFFFFA726);
  static const Color successColor = Color(0xFF66BB6A);
  static const Color infoColor = Color(0xFF29B6F6);
  
  // Airspace colors following aviation standards
  // ICAO Airspace Classes
  static const Color airspaceClassA = Color(0xFFCC0000); // Dark Red - Most restrictive
  static const Color airspaceClassB = Color(0xFFFF4444); // Red - Very restrictive
  static const Color airspaceClassC = Color(0xFF0066CC); // Dark Blue - Controlled airspace
  static const Color airspaceClassD = Color(0xFF3399FF); // Light Blue - Controlled airspace
  static const Color airspaceClassE = Color(0xFF4CAF50); // Light Green - Least restrictive controlled
  static const Color airspaceClassF = Color(0xFF66BB6A); // Green 400 - Uncontrolled
  static const Color airspaceClassG = Color(0xFF81C784); // Green 300 - Uncontrolled
  
  // Special airspace types
  static const Color airspaceCTR = Color(0xFFFF0000); // Red - Control Zone
  static const Color airspaceATZ = Color(0xFFFF4500); // Red/Orange - Aerodrome Traffic Zone
  static const Color airspaceTMA = Color(0xFF1976D2); // Blue - Terminal Maneuvering Area
  
  // Restricted/Prohibited areas
  static const Color airspaceProhibited = Color(0xFF8B0000); // Dark Red/Purple - Prohibited
  static const Color airspaceDanger = Color(0xFF8B0000); // Dark Red/Purple - Danger
  static const Color airspaceRestricted = Color(0xFFFF8C00); // Orange - Restricted
  
  // Mandatory zones
  static const Color airspaceTransponderMandatory = Color(0xFFFFA726); // Orange - TMZ
  static const Color airspaceRadioMandatory = Color(0xFFFFC107); // Amber - RMZ
  
  // Special purpose areas
  static const Color airspaceTraining = Color(0xFF9C27B0); // Purple - Training areas
  static const Color airspaceMoa = Color(0xFF7B1FA2); // Deep Purple - Military training
  static const Color airspaceGliderProhibited = Color(0xFF4CAF50); // Green - Gliding areas
  static const Color airspaceWaveWindow = Color(0xFF00BCD4); // Cyan - Wave areas
  static const Color airspaceMATZ = Color(0xFF1565C0); // Blue 800 - Military ATZ
  
  // Information services
  static const Color airspaceFIS = Color(0xFF81C784); // Light Green - Flight Information Service
  
  // Default
  static const Color airspaceDefault = Color(0xFF616161); // Grey 700
  
  // Map feature colors
  static const Color obstacleColor = Color(0xFFD32F2F); // Red
  static const Color navaidColor = Color(0xFF1976D2); // Blue
  static const Color airportColor = Color(0xFF7B1FA2); // Purple
  
  // Opacity values as constants
  static const double highOpacity = 0.94;
  static const double mediumOpacity = 0.5;
  static const double lowOpacity = 0.2;
  static const double veryLowOpacity = 0.1;
}