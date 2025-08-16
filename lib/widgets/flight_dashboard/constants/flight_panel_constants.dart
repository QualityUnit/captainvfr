/// Constants for flight tracking panel dimensions and styling
class FlightPanelConstants {
  // Panel dimensions
  static const double expandedHeight = 340.0;
  static const double collapsedHeight = 48.0;
  static const double handleHeight = 46.0; // Account for 1px border
  
  // Panel widths for different screen sizes
  static const double phoneMaxWidth = 600.0;
  static const double tabletMaxWidth = 800.0;
  static const double smallTabletMinWidth = 400.0;
  static const double smallTabletMaxWidth = 600.0;
  
  // Main indicators
  static const double mainIndicatorsHeight = 110.0;
  static const double compassSize = 70.0;
  static const double mainIndicatorFontSize = 28.0;
  static const double mainIndicatorUnitFontSize = 16.0;
  static const double mainIndicatorIconSize = 20.0;
  static const double mainIndicatorLabelFontSize = 12.0;
  
  // Handle elements
  static const double handleBarWidth = 36.0;
  static const double handleBarHeight = 3.0;
  static const double handleIconSize = 18.0;
  static const double handleTitleFontSize = 10.0;
  static const double recordingIndicatorSize = 6.0;
  
  // Tracking button
  static const double trackingButtonSize = 40.0;
  static const double trackingButtonIconSize = 20.0;
  static const double trackingButtonBorderWidth = 2.0;
  
  // Animation
  static const Duration panelAnimationDuration = Duration(milliseconds: 300);
  
  // Drag thresholds
  static const double dragExpandThreshold = -10.0;
  static const double dragCollapseThreshold = 10.0;
  
  // Spacing
  static const double defaultPadding = 8.0;
  static const double smallSpacing = 4.0;
  static const double mediumSpacing = 8.0;
  static const double largeSpacing = 12.0;
  
  // Border radius
  static const double panelBorderRadius = 16.0;
  static const double handleBarBorderRadius = 1.5;
  static const double trackingButtonBorderRadius = 20.0;
  
  // Opacity values
  static const double handleBarOpacity = 0.3;
  static const double panelBorderOpacity = 0.2;
  static const double trackingBorderOpacity = 0.3;
  static const double trackingActiveOpacity = 0.8;
  static const double iconInactiveOpacity = 0.8;
  static const double backgroundOverlayOpacity = 0.1;
  static const double trackingButtonBackgroundOpacity = 0.5;
  
  // Colors
  static const int panelBackgroundColor = 0xE6000000;
  
  // Private constructor to prevent instantiation
  FlightPanelConstants._();
}