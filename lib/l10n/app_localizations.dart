import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_cs.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_it.dart';
import 'app_localizations_sk.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('cs'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('it'),
    Locale('sk'),
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'CaptainVFR'**
  String get appTitle;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Language setting label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Language selection dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// Map screen title
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// Tracking settings section
  ///
  /// In en, this message translates to:
  /// **'Tracking'**
  String get tracking;

  /// Units settings section
  ///
  /// In en, this message translates to:
  /// **'Units'**
  String get units;

  /// Map rotation setting
  ///
  /// In en, this message translates to:
  /// **'Rotate with heading'**
  String get rotateWithHeading;

  /// GPS precision setting
  ///
  /// In en, this message translates to:
  /// **'High precision GPS'**
  String get highPrecisionGps;

  /// Auto logbook creation setting
  ///
  /// In en, this message translates to:
  /// **'Auto-create logbook'**
  String get autoCreateLogbook;

  /// Unit presets label
  ///
  /// In en, this message translates to:
  /// **'Presets'**
  String get presets;

  /// Flight planning screen title
  ///
  /// In en, this message translates to:
  /// **'Flight Planning'**
  String get flightPlanning;

  /// Create trip button text
  ///
  /// In en, this message translates to:
  /// **'Create Trip'**
  String get createTrip;

  /// Trip name label
  ///
  /// In en, this message translates to:
  /// **'Trip Name'**
  String get tripName;

  /// Trip name input hint
  ///
  /// In en, this message translates to:
  /// **'Enter trip name'**
  String get enterTripName;

  /// Select flight plans label
  ///
  /// In en, this message translates to:
  /// **'Select Flight Plans'**
  String get selectFlightPlans;

  /// No flight plans selected error
  ///
  /// In en, this message translates to:
  /// **'No flight plans selected'**
  String get noFlightPlansSelected;

  /// Trip created success message
  ///
  /// In en, this message translates to:
  /// **'Trip created successfully'**
  String get tripCreated;

  /// Tooltip for center flight plan button
  ///
  /// In en, this message translates to:
  /// **'Center map on flight plan'**
  String get centerOnFlightPlan;

  /// Tooltip for clear flight plan button
  ///
  /// In en, this message translates to:
  /// **'Remove flight plan from map'**
  String get clearFlightPlan;

  /// Delete leg dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Leg'**
  String get deleteLeg;

  /// Delete leg confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete leg \"{legName}\" from the trip?'**
  String deleteLegConfirmation(String legName);

  /// Add flight plan to trip button
  ///
  /// In en, this message translates to:
  /// **'Add to Trip'**
  String get addToTrip;

  /// Replace current flight plan button
  ///
  /// In en, this message translates to:
  /// **'Replace Current'**
  String get replaceCurrent;

  /// Add flight plan to trip button text
  ///
  /// In en, this message translates to:
  /// **'Add Flight Plan to Trip'**
  String get addFlightPlanToTrip;

  /// Clear button label
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// Added to trip message prefix
  ///
  /// In en, this message translates to:
  /// **'Added to trip:'**
  String get addedTo;

  /// Weather tab label
  ///
  /// In en, this message translates to:
  /// **'Weather'**
  String get weather;

  /// Flight log screen title
  ///
  /// In en, this message translates to:
  /// **'Flight Log'**
  String get flightLog;

  /// Aircraft screen title
  ///
  /// In en, this message translates to:
  /// **'Aircraft'**
  String get aircraft;

  /// Calculators screen title
  ///
  /// In en, this message translates to:
  /// **'Calculators'**
  String get calculators;

  /// Offline data screen title
  ///
  /// In en, this message translates to:
  /// **'Offline Data'**
  String get offlineData;

  /// Licenses screen title
  ///
  /// In en, this message translates to:
  /// **'Licenses'**
  String get licenses;

  /// Checklist screen title
  ///
  /// In en, this message translates to:
  /// **'Checklist'**
  String get checklist;

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Save button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Delete button label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Edit button label
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Add button label
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Search placeholder text
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// Loading indicator text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Center button label for map
  ///
  /// In en, this message translates to:
  /// **'Center'**
  String get center;

  /// Map layers button label
  ///
  /// In en, this message translates to:
  /// **'Layers'**
  String get layers;

  /// Airports section title
  ///
  /// In en, this message translates to:
  /// **'Airports'**
  String get airports;

  /// Airspaces toggle label
  ///
  /// In en, this message translates to:
  /// **'Airspaces'**
  String get airspaces;

  /// Pilot calculators screen title
  ///
  /// In en, this message translates to:
  /// **'Pilot Calculators'**
  String get pilotCalculators;

  /// Flight detail screen title
  ///
  /// In en, this message translates to:
  /// **'Flight Detail'**
  String get flightDetail;

  /// Manufacturers screen title
  ///
  /// In en, this message translates to:
  /// **'Manufacturers'**
  String get manufacturers;

  /// Message when no aircraft are configured
  ///
  /// In en, this message translates to:
  /// **'No aircraft configured'**
  String get noAircraftConfigured;

  /// Instructions to add aircraft
  ///
  /// In en, this message translates to:
  /// **'Add aircraft in the settings'**
  String get addAircraftInSettings;

  /// Aircraft selection dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Aircraft'**
  String get selectAircraft;

  /// Cruise speed label
  ///
  /// In en, this message translates to:
  /// **'Cruise Speed'**
  String get cruiseSpeed;

  /// Fuel burn label
  ///
  /// In en, this message translates to:
  /// **'Fuel Burn'**
  String get fuelBurn;

  /// Maximum takeoff weight abbreviation
  ///
  /// In en, this message translates to:
  /// **'MTOW'**
  String get mtow;

  /// Add aircraft button label
  ///
  /// In en, this message translates to:
  /// **'Add Aircraft'**
  String get addAircraft;

  /// Edit aircraft button label
  ///
  /// In en, this message translates to:
  /// **'Edit Aircraft'**
  String get editAircraft;

  /// Delete aircraft button label
  ///
  /// In en, this message translates to:
  /// **'Delete Aircraft'**
  String get deleteAircraft;

  /// Aircraft name field label
  ///
  /// In en, this message translates to:
  /// **'Aircraft Name'**
  String get aircraftName;

  /// Aircraft registration field label
  ///
  /// In en, this message translates to:
  /// **'Registration'**
  String get registration;

  /// Manufacturer field label
  ///
  /// In en, this message translates to:
  /// **'Manufacturer'**
  String get manufacturer;

  /// Model field label
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get model;

  /// Basic information section title
  ///
  /// In en, this message translates to:
  /// **'Basic Information'**
  String get basicInformation;

  /// Performance specifications section title
  ///
  /// In en, this message translates to:
  /// **'Performance Specifications'**
  String get performanceSpecifications;

  /// Optional performance data section title
  ///
  /// In en, this message translates to:
  /// **'Optional Performance Data'**
  String get optionalPerformanceData;

  /// Takeoff and landing performance section title
  ///
  /// In en, this message translates to:
  /// **'Takeoff & Landing Performance'**
  String get takeoffLandingPerformance;

  /// V-speeds section title
  ///
  /// In en, this message translates to:
  /// **'V-Speeds'**
  String get vSpeeds;

  /// Additional performance data section title
  ///
  /// In en, this message translates to:
  /// **'Additional Performance Data'**
  String get additionalPerformanceData;

  /// Validation message for aircraft name
  ///
  /// In en, this message translates to:
  /// **'Please enter an aircraft name'**
  String get pleaseEnterAircraftName;

  /// Validation message for manufacturer selection
  ///
  /// In en, this message translates to:
  /// **'Please select a manufacturer'**
  String get pleaseSelectManufacturer;

  /// Validation message for model selection
  ///
  /// In en, this message translates to:
  /// **'Please select a model'**
  String get pleaseSelectModel;

  /// Success message for saving aircraft
  ///
  /// In en, this message translates to:
  /// **'Aircraft saved successfully'**
  String get aircraftSavedSuccessfully;

  /// Button to add first aircraft
  ///
  /// In en, this message translates to:
  /// **'Add First Aircraft'**
  String get addFirstAircraft;

  /// Add manufacturer button label
  ///
  /// In en, this message translates to:
  /// **'Add Manufacturer'**
  String get addManufacturer;

  /// Edit manufacturer button label
  ///
  /// In en, this message translates to:
  /// **'Edit Manufacturer'**
  String get editManufacturer;

  /// Delete manufacturer button label
  ///
  /// In en, this message translates to:
  /// **'Delete Manufacturer'**
  String get deleteManufacturer;

  /// Manufacturer name field label
  ///
  /// In en, this message translates to:
  /// **'Manufacturer Name'**
  String get manufacturerName;

  /// Website field label
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// Description field label
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// Validation message for manufacturer name
  ///
  /// In en, this message translates to:
  /// **'Please enter a manufacturer name'**
  String get pleaseEnterManufacturerName;

  /// Validation message for URL format
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid URL'**
  String get pleaseEnterValidUrl;

  /// Placeholder for manufacturer description
  ///
  /// In en, this message translates to:
  /// **'Brief description of the manufacturer'**
  String get briefDescriptionOfManufacturer;

  /// Success message for adding manufacturer
  ///
  /// In en, this message translates to:
  /// **'Manufacturer added successfully'**
  String get manufacturerAddedSuccessfully;

  /// Success message for updating manufacturer
  ///
  /// In en, this message translates to:
  /// **'Manufacturer updated successfully'**
  String get manufacturerUpdatedSuccessfully;

  /// Add model button label
  ///
  /// In en, this message translates to:
  /// **'Add Model'**
  String get addModel;

  /// Edit model button label
  ///
  /// In en, this message translates to:
  /// **'Edit Model'**
  String get editModel;

  /// Delete model button label
  ///
  /// In en, this message translates to:
  /// **'Delete Model'**
  String get deleteModel;

  /// Model name field label
  ///
  /// In en, this message translates to:
  /// **'Model Name'**
  String get modelName;

  /// Aircraft category field label
  ///
  /// In en, this message translates to:
  /// **'Aircraft Category'**
  String get aircraftCategory;

  /// Engine count field label
  ///
  /// In en, this message translates to:
  /// **'Engine Count'**
  String get engineCount;

  /// Maximum seats field label
  ///
  /// In en, this message translates to:
  /// **'Maximum Seats'**
  String get maximumSeats;

  /// Typical cruise speed field label
  ///
  /// In en, this message translates to:
  /// **'Typical Cruise Speed (kts)'**
  String get typicalCruiseSpeed;

  /// Service ceiling field label
  ///
  /// In en, this message translates to:
  /// **'Service Ceiling (ft)'**
  String get serviceCeiling;

  /// Fuel consumption field label
  ///
  /// In en, this message translates to:
  /// **'Fuel Consumption (gph)'**
  String get fuelConsumption;

  /// Maximum climb rate field label
  ///
  /// In en, this message translates to:
  /// **'Max Climb Rate (fpm)'**
  String get maxClimbRate;

  /// Maximum descent rate field label
  ///
  /// In en, this message translates to:
  /// **'Max Descent Rate (fpm)'**
  String get maxDescentRate;

  /// Maximum takeoff weight field label
  ///
  /// In en, this message translates to:
  /// **'Max Takeoff Weight (lbs)'**
  String get maxTakeoffWeight;

  /// Maximum landing weight field label
  ///
  /// In en, this message translates to:
  /// **'Max Landing Weight (lbs)'**
  String get maxLandingWeight;

  /// Fuel capacity field label
  ///
  /// In en, this message translates to:
  /// **'Fuel Capacity (gallons)'**
  String get fuelCapacity;

  /// Validation message for model name
  ///
  /// In en, this message translates to:
  /// **'Please enter a model name'**
  String get pleaseEnterModelName;

  /// Validation message for engine count
  ///
  /// In en, this message translates to:
  /// **'Please enter engine count'**
  String get pleaseEnterEngineCount;

  /// Validation message for valid engine count
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid engine count'**
  String get pleaseEnterValidEngineCount;

  /// Validation message for maximum seats
  ///
  /// In en, this message translates to:
  /// **'Please enter maximum seats'**
  String get pleaseEnterMaximumSeats;

  /// Validation message for valid seat count
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid seat count'**
  String get pleaseEnterValidSeatCount;

  /// Validation message for cruise speed
  ///
  /// In en, this message translates to:
  /// **'Please enter cruise speed'**
  String get pleaseEnterCruiseSpeed;

  /// Validation message for valid speed
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid speed'**
  String get pleaseEnterValidSpeed;

  /// Validation message for service ceiling
  ///
  /// In en, this message translates to:
  /// **'Please enter service ceiling'**
  String get pleaseEnterServiceCeiling;

  /// Validation message for valid ceiling
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid ceiling'**
  String get pleaseEnterValidCeiling;

  /// Success message for adding model
  ///
  /// In en, this message translates to:
  /// **'Model added successfully'**
  String get modelAddedSuccessfully;

  /// Success message for updating model
  ///
  /// In en, this message translates to:
  /// **'Model updated successfully'**
  String get modelUpdatedSuccessfully;

  /// Button to add first model
  ///
  /// In en, this message translates to:
  /// **'Add First Model'**
  String get addFirstModel;

  /// Add checklist button label
  ///
  /// In en, this message translates to:
  /// **'Add Checklist'**
  String get addChecklist;

  /// Edit checklist button label
  ///
  /// In en, this message translates to:
  /// **'Edit Checklist'**
  String get editChecklist;

  /// Delete checklist button label
  ///
  /// In en, this message translates to:
  /// **'Delete Checklist'**
  String get deleteChecklist;

  /// Checklist name field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get checklistName;

  /// Checklist description field label
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get checklistDescription;

  /// Checklist items section title
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get items;

  /// Add item button label
  ///
  /// In en, this message translates to:
  /// **'Add Item'**
  String get addItem;

  /// Edit item button label
  ///
  /// In en, this message translates to:
  /// **'Edit Item'**
  String get editItem;

  /// Target value field label
  ///
  /// In en, this message translates to:
  /// **'Target Value'**
  String get targetValue;

  /// Validation message for name field
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get pleaseEnterName;

  /// Validation message for item name
  ///
  /// In en, this message translates to:
  /// **'Please enter item name'**
  String get pleaseEnterItemName;

  /// Save checklist button label
  ///
  /// In en, this message translates to:
  /// **'Save Checklist'**
  String get saveChecklist;

  /// Search airports and navaids title
  ///
  /// In en, this message translates to:
  /// **'Search Airports & Navaids'**
  String get searchAirportsNavaids;

  /// Search input placeholder
  ///
  /// In en, this message translates to:
  /// **'Enter airport/navaid name, code, or city'**
  String get enterAirportNavaidName;

  /// Search instructions
  ///
  /// In en, this message translates to:
  /// **'Search for airports and navaids by name or code\n(e.g., \"KJFK\", \"Kennedy\", \"VOR\", \"SFO\")'**
  String get searchForAirports;

  /// Message when search history is empty
  ///
  /// In en, this message translates to:
  /// **'No recent searches'**
  String get searchHistoryEmpty;

  /// Recent searches section title
  ///
  /// In en, this message translates to:
  /// **'Recent searches'**
  String get recentSearches;

  /// Button to clear search history
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clearHistory;

  /// No search results message
  ///
  /// In en, this message translates to:
  /// **'No results found for \"{query}\"'**
  String noResultsFound(String query);

  /// Search suggestions message
  ///
  /// In en, this message translates to:
  /// **'Try searching by:\n• Airport name (e.g., \"Kennedy\")\n• ICAO code (e.g., \"KJFK\")\n• IATA code (e.g., \"JFK\")\n• Navaid ID (e.g., \"SFO\")\n• VOR/NDB name'**
  String get trySearchingBy;

  /// Airports count label
  ///
  /// In en, this message translates to:
  /// **'Airports ({count})'**
  String airportsCount(int count);

  /// Navigation aids count label
  ///
  /// In en, this message translates to:
  /// **'Navigation Aids ({count})'**
  String navigationAidsCount(int count);

  /// New flight plan button label
  ///
  /// In en, this message translates to:
  /// **'New Flight Plan'**
  String get newFlightPlan;

  /// Flight plan name field label
  ///
  /// In en, this message translates to:
  /// **'Flight Plan Name'**
  String get flightPlanName;

  /// Flight plan name input placeholder
  ///
  /// In en, this message translates to:
  /// **'Enter flight plan name'**
  String get enterFlightPlanName;

  /// Delete flight plan button label
  ///
  /// In en, this message translates to:
  /// **'Delete Flight Plan'**
  String get deleteFlightPlan;

  /// Flight plan loaded message
  ///
  /// In en, this message translates to:
  /// **'Loaded flight plan: {name}'**
  String loadedFlightPlan(String name);

  /// Flight plan duplicated message
  ///
  /// In en, this message translates to:
  /// **'Flight plan duplicated'**
  String get flightPlanDuplicated;

  /// Flight plan deleted message
  ///
  /// In en, this message translates to:
  /// **'Flight plan deleted'**
  String get flightPlanDeleted;

  /// Edit waypoint dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit Waypoint {index}'**
  String editWaypoint(int index);

  /// Delete waypoint button label
  ///
  /// In en, this message translates to:
  /// **'Delete Waypoint'**
  String get deleteWaypoint;

  /// Delete waypoint confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete waypoint \"{name}\"?'**
  String areYouSureDeleteWaypoint(String name);

  /// Position field label
  ///
  /// In en, this message translates to:
  /// **'Position'**
  String get position;

  /// Waypoint name field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get waypointName;

  /// Waypoint name input placeholder
  ///
  /// In en, this message translates to:
  /// **'Enter waypoint name'**
  String get enterWaypointName;

  /// Altitude in feet MSL field label
  ///
  /// In en, this message translates to:
  /// **'Altitude (ft MSL)'**
  String get altitudeFtMsl;

  /// Altitude in meters MSL field label
  ///
  /// In en, this message translates to:
  /// **'Altitude (m MSL)'**
  String get altitudeMetersMsl;

  /// Altitude input placeholder
  ///
  /// In en, this message translates to:
  /// **'Enter altitude in feet'**
  String get enterAltitudeInFeet;

  /// Pilot licenses screen title
  ///
  /// In en, this message translates to:
  /// **'Pilot Licenses'**
  String get pilotLicenses;

  /// Button to add first license
  ///
  /// In en, this message translates to:
  /// **'Add Your First License'**
  String get addYourFirstLicense;

  /// Delete license dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete License'**
  String get deleteLicense;

  /// Delete license confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String areYouSureDeleteLicense(String name);

  /// Assign to pilot button label
  ///
  /// In en, this message translates to:
  /// **'Assign to Pilot'**
  String get assignToPilot;

  /// License deleted success message
  ///
  /// In en, this message translates to:
  /// **'License deleted'**
  String get licenseDeletedSuccessfully;

  /// Error saving license message
  ///
  /// In en, this message translates to:
  /// **'Error saving license: {error}'**
  String errorSavingLicense(String error);

  /// Issue date field label
  ///
  /// In en, this message translates to:
  /// **'Issue Date'**
  String get issueDate;

  /// Expiration date field label
  ///
  /// In en, this message translates to:
  /// **'Expiration Date'**
  String get expirationDate;

  /// Valid from field label
  ///
  /// In en, this message translates to:
  /// **'Valid From'**
  String get validFrom;

  /// Valid to field label
  ///
  /// In en, this message translates to:
  /// **'Valid To'**
  String get validTo;

  /// Has expiration field label
  ///
  /// In en, this message translates to:
  /// **'Has Expiration'**
  String get hasExpiration;

  /// License images section title
  ///
  /// In en, this message translates to:
  /// **'License Images'**
  String get licenseImages;

  /// No images message
  ///
  /// In en, this message translates to:
  /// **'No images yet'**
  String get noImagesYet;

  /// Add license photos instruction
  ///
  /// In en, this message translates to:
  /// **'Add photos of your license'**
  String get addPhotosOfLicense;

  /// Delete flight button label
  ///
  /// In en, this message translates to:
  /// **'Delete Flight'**
  String get deleteFlight;

  /// Flight deleted success message
  ///
  /// In en, this message translates to:
  /// **'Flight deleted successfully'**
  String get flightDeletedSuccessfully;

  /// Error deleting flight message
  ///
  /// In en, this message translates to:
  /// **'Error deleting flight: {error}'**
  String errorDeletingFlight(String error);

  /// Logbook entry created success message
  ///
  /// In en, this message translates to:
  /// **'Logbook entry created successfully'**
  String get logbookEntryCreatedSuccessfully;

  /// Error creating logbook entry message
  ///
  /// In en, this message translates to:
  /// **'Error creating logbook entry: {error}'**
  String errorCreatingLogbookEntry(String error);

  /// Departure airport field label
  ///
  /// In en, this message translates to:
  /// **'Departure Airport'**
  String get departureAirport;

  /// Arrival airport field label
  ///
  /// In en, this message translates to:
  /// **'Arrival Airport'**
  String get arrivalAirport;

  /// Pilot in command field label
  ///
  /// In en, this message translates to:
  /// **'Pilot in Command'**
  String get pilotInCommand;

  /// Second in command field label
  ///
  /// In en, this message translates to:
  /// **'Second in Command'**
  String get secondInCommand;

  /// Flight summary title
  ///
  /// In en, this message translates to:
  /// **'Flight Summary'**
  String get flightSummary;

  /// Flight details title
  ///
  /// In en, this message translates to:
  /// **'Flight Details'**
  String get flightDetails;

  /// Time tracking section title
  ///
  /// In en, this message translates to:
  /// **'Time Tracking'**
  String get timeTracking;

  /// Maximum speed label
  ///
  /// In en, this message translates to:
  /// **'Max Speed'**
  String get maxSpeed;

  /// Maximum altitude label
  ///
  /// In en, this message translates to:
  /// **'Max Altitude'**
  String get maxAltitude;

  /// Distance label
  ///
  /// In en, this message translates to:
  /// **'Distance'**
  String get distance;

  /// Average speed label
  ///
  /// In en, this message translates to:
  /// **'Avg Speed'**
  String get avgSpeed;

  /// Start altitude label
  ///
  /// In en, this message translates to:
  /// **'Start Alt'**
  String get startAlt;

  /// End altitude label
  ///
  /// In en, this message translates to:
  /// **'End Alt'**
  String get endAlt;

  /// Flight segments section title
  ///
  /// In en, this message translates to:
  /// **'Flight Segments'**
  String get flightSegments;

  /// No segments data message
  ///
  /// In en, this message translates to:
  /// **'No segments data available'**
  String get noSegmentsDataAvailable;

  /// Message when no flight path data is available
  ///
  /// In en, this message translates to:
  /// **'No flight path data available'**
  String get noFlightPathDataAvailable;

  /// No speed data available message
  ///
  /// In en, this message translates to:
  /// **'No speed data available\nStart tracking to see speed changes'**
  String get noSpeedDataAvailable;

  /// No turbulence data message
  ///
  /// In en, this message translates to:
  /// **'No turbulence data available\nStart tracking to see turbulence data'**
  String get noTurbulenceDataAvailable;

  /// Density altitude calculator title
  ///
  /// In en, this message translates to:
  /// **'Density Altitude'**
  String get densityAltitude;

  /// Weight and balance calculator title
  ///
  /// In en, this message translates to:
  /// **'Weight & Balance'**
  String get weightBalance;

  /// Takeoff and landing calculator title
  ///
  /// In en, this message translates to:
  /// **'Takeoff & Landing'**
  String get takeoffLanding;

  /// Fuel burn calculator title
  ///
  /// In en, this message translates to:
  /// **'Fuel Burn'**
  String get fuelBurnCalc;

  /// Climb performance calculator title
  ///
  /// In en, this message translates to:
  /// **'Climb Performance'**
  String get climbPerformance;

  /// Cruise performance calculator title
  ///
  /// In en, this message translates to:
  /// **'Cruise Performance'**
  String get cruisePerformance;

  /// Descent performance calculator title
  ///
  /// In en, this message translates to:
  /// **'Descent Performance'**
  String get descentPerformance;

  /// Crosswind component label
  ///
  /// In en, this message translates to:
  /// **'Crosswind'**
  String get crosswind;

  /// Wind correction result label
  ///
  /// In en, this message translates to:
  /// **'Wind Correction'**
  String get windCorrection;

  /// Unit conversion calculator title
  ///
  /// In en, this message translates to:
  /// **'Unit Conversion'**
  String get unitConversion;

  /// Field elevation field label
  ///
  /// In en, this message translates to:
  /// **'Field Elevation'**
  String get fieldElevation;

  /// Altimeter setting field label
  ///
  /// In en, this message translates to:
  /// **'Altimeter Setting'**
  String get altimeterSetting;

  /// Pressure altitude field label
  ///
  /// In en, this message translates to:
  /// **'Pressure Altitude'**
  String get pressureAltitude;

  /// Temperature field label
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get temperature;

  /// Current altitude field label
  ///
  /// In en, this message translates to:
  /// **'Current Altitude'**
  String get currentAltitude;

  /// Target altitude field label
  ///
  /// In en, this message translates to:
  /// **'Target Altitude'**
  String get targetAltitude;

  /// Current weight field label
  ///
  /// In en, this message translates to:
  /// **'Current Weight'**
  String get currentWeight;

  /// Headwind component field label
  ///
  /// In en, this message translates to:
  /// **'Headwind Component'**
  String get headwindComponent;

  /// Fuel flow rate field label
  ///
  /// In en, this message translates to:
  /// **'Fuel Flow Rate'**
  String get fuelFlowRate;

  /// Flight time in hours field label
  ///
  /// In en, this message translates to:
  /// **'Flight Time (Hours)'**
  String get flightTimeHours;

  /// Minutes unit label
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get minutes;

  /// Reserve time in minutes field label
  ///
  /// In en, this message translates to:
  /// **'Reserve Time (Minutes)'**
  String get reserveTimeMinutes;

  /// Available fuel field label
  ///
  /// In en, this message translates to:
  /// **'Available Fuel'**
  String get availableFuel;

  /// Runway heading field label
  ///
  /// In en, this message translates to:
  /// **'Runway Heading (°)'**
  String get runwayHeading;

  /// Wind direction field label
  ///
  /// In en, this message translates to:
  /// **'Wind Direction (°)'**
  String get windDirection;

  /// Wind speed field label
  ///
  /// In en, this message translates to:
  /// **'Wind Speed'**
  String get windSpeed;

  /// Desired course field label
  ///
  /// In en, this message translates to:
  /// **'Desired Course (°)'**
  String get desiredCourse;

  /// True airspeed field label
  ///
  /// In en, this message translates to:
  /// **'True Airspeed'**
  String get trueAirspeed;

  /// Environmental conditions section title
  ///
  /// In en, this message translates to:
  /// **'Environmental Conditions'**
  String get environmentalConditions;

  /// Runway contamination field label
  ///
  /// In en, this message translates to:
  /// **'Runway Contamination (%)'**
  String get runwayContamination;

  /// Aircraft weight field label
  ///
  /// In en, this message translates to:
  /// **'Aircraft Weight'**
  String get aircraftWeight;

  /// Missing map tiles dialog title
  ///
  /// In en, this message translates to:
  /// **'Missing Map Tiles'**
  String get missingMapTiles;

  /// Download now button label
  ///
  /// In en, this message translates to:
  /// **'Download Now'**
  String get downloadNow;

  /// Later button label
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// Location error message
  ///
  /// In en, this message translates to:
  /// **'Could not get current location'**
  String get couldNotGetCurrentLocation;

  /// Error message for airport details
  ///
  /// In en, this message translates to:
  /// **'Error showing airport details'**
  String get errorShowingAirportDetails;

  /// Error message for navaid details
  ///
  /// In en, this message translates to:
  /// **'Error showing navaid details'**
  String get errorShowingNavaidDetails;

  /// Error message for airspace details
  ///
  /// In en, this message translates to:
  /// **'Error showing airspace details'**
  String get errorShowingAirspaceDetails;

  /// Error message for reporting point details
  ///
  /// In en, this message translates to:
  /// **'Error showing reporting point details'**
  String get errorShowingReportingPointDetails;

  /// Error message for obstacle details
  ///
  /// In en, this message translates to:
  /// **'Error showing obstacle details'**
  String get errorShowingObstacleDetails;

  /// Error message for hotspot details
  ///
  /// In en, this message translates to:
  /// **'Error showing hotspot details'**
  String get errorShowingHotspotDetails;

  /// Heliports layer label
  ///
  /// In en, this message translates to:
  /// **'Heliports'**
  String get heliports;

  /// Navaids toggle label
  ///
  /// In en, this message translates to:
  /// **'Navaids'**
  String get navaids;

  /// METAR toggle label
  ///
  /// In en, this message translates to:
  /// **'METAR'**
  String get metar;

  /// Obstacles toggle label
  ///
  /// In en, this message translates to:
  /// **'Obstacles'**
  String get obstacles;

  /// Hotspots toggle label
  ///
  /// In en, this message translates to:
  /// **'Hotspots'**
  String get hotspots;

  /// Heatmap toggle label
  ///
  /// In en, this message translates to:
  /// **'Heatmap'**
  String get heatmap;

  /// Current airspace label
  ///
  /// In en, this message translates to:
  /// **'Current Airspace'**
  String get currentAirspace;

  /// Planning mode label
  ///
  /// In en, this message translates to:
  /// **'Planning'**
  String get planning;

  /// No airspace message
  ///
  /// In en, this message translates to:
  /// **'No airspace at current position'**
  String get noAirspaceAtCurrentPosition;

  /// Current airspace section label
  ///
  /// In en, this message translates to:
  /// **'CURRENT AIRSPACE'**
  String get currentAirspaceLabel;

  /// Next airspace section label
  ///
  /// In en, this message translates to:
  /// **'NEXT AIRSPACE'**
  String get nextAirspace;

  /// Airspace exit section label
  ///
  /// In en, this message translates to:
  /// **'AIRSPACE EXIT'**
  String get airspaceExit;

  /// Exiting airspace message
  ///
  /// In en, this message translates to:
  /// **'Exiting {name}'**
  String exitingAirspace(String name);

  /// License attention required dialog title
  ///
  /// In en, this message translates to:
  /// **'License Attention Required'**
  String get licenseAttentionRequired;

  /// Immediate attention required message
  ///
  /// In en, this message translates to:
  /// **'Immediate attention required'**
  String get immediateAttentionRequired;

  /// Map settings section title
  ///
  /// In en, this message translates to:
  /// **'Map Settings'**
  String get mapSettings;

  /// Map rotation mode setting label
  ///
  /// In en, this message translates to:
  /// **'Map Rotation Mode'**
  String get mapRotationMode;

  /// Map rotation mode description
  ///
  /// In en, this message translates to:
  /// **'How map and aircraft marker should rotate'**
  String get howMapRotates;

  /// High precision mode setting label
  ///
  /// In en, this message translates to:
  /// **'High Precision Mode'**
  String get highPrecisionMode;

  /// High precision GPS description
  ///
  /// In en, this message translates to:
  /// **'Use high accuracy GPS (uses more battery)'**
  String get useHighAccuracyGps;

  /// Auto-create logbook entry setting label
  ///
  /// In en, this message translates to:
  /// **'Auto-create Logbook Entry'**
  String get autoCreateLogbookEntry;

  /// Auto-create logbook entry description
  ///
  /// In en, this message translates to:
  /// **'Automatically create logbook entry after flight'**
  String get automaticallyCreateLogbook;

  /// European aviation unit preset
  ///
  /// In en, this message translates to:
  /// **'European Aviation'**
  String get europeanAviation;

  /// US general aviation unit preset
  ///
  /// In en, this message translates to:
  /// **'US General Aviation'**
  String get usGeneralAviation;

  /// Metric preference unit preset
  ///
  /// In en, this message translates to:
  /// **'Metric Preference'**
  String get metricPreference;

  /// Mixed international unit preset
  ///
  /// In en, this message translates to:
  /// **'Mixed International'**
  String get mixedInternational;

  /// Legacy metric unit preset
  ///
  /// In en, this message translates to:
  /// **'Legacy Metric'**
  String get legacyMetric;

  /// Legacy imperial unit preset
  ///
  /// In en, this message translates to:
  /// **'Legacy Imperial'**
  String get legacyImperial;

  /// Reset to defaults button label
  ///
  /// In en, this message translates to:
  /// **'Reset to Defaults'**
  String get resetToDefaults;

  /// Reset settings dialog title
  ///
  /// In en, this message translates to:
  /// **'Reset Settings'**
  String get resetSettings;

  /// Settings reset success message
  ///
  /// In en, this message translates to:
  /// **'Settings reset to defaults'**
  String get settingsResetToDefaults;

  /// Refreshing all aviation data progress message
  ///
  /// In en, this message translates to:
  /// **'Refreshing all aviation data...'**
  String get refreshingAllAviationData;

  /// All data refreshed success message
  ///
  /// In en, this message translates to:
  /// **'All data refreshed successfully'**
  String get allDataRefreshedSuccessfully;

  /// Error refreshing data
  ///
  /// In en, this message translates to:
  /// **'Error refreshing data: {error}'**
  String errorRefreshingData(String error);

  /// Refreshing weather data progress message
  ///
  /// In en, this message translates to:
  /// **'Refreshing weather data...'**
  String get refreshingWeatherData;

  /// Weather data refreshed success message
  ///
  /// In en, this message translates to:
  /// **'Weather data refreshed successfully'**
  String get weatherDataRefreshedSuccessfully;

  /// Error refreshing weather data
  ///
  /// In en, this message translates to:
  /// **'Error refreshing weather data: {error}'**
  String errorRefreshingWeatherData(String error);

  /// Error loading cache statistics
  ///
  /// In en, this message translates to:
  /// **'Error loading cache stats: {error}'**
  String errorLoadingCacheStats(String error);

  /// Clear cache tooltip
  ///
  /// In en, this message translates to:
  /// **'Clear cache'**
  String get clearCache;

  /// Cache cleared success message
  ///
  /// In en, this message translates to:
  /// **'Cache cleared successfully'**
  String get cacheCleared;

  /// All caches cleared success message
  ///
  /// In en, this message translates to:
  /// **'All caches cleared successfully'**
  String get allCachesCleared;

  /// Error clearing cache
  ///
  /// In en, this message translates to:
  /// **'Error clearing {name} cache: {error}'**
  String errorClearingCache(String name, String error);

  /// Airport information description
  ///
  /// In en, this message translates to:
  /// **'Airport information and details'**
  String get airportInformation;

  /// VOR/NDB navigation description
  ///
  /// In en, this message translates to:
  /// **'VOR, NDB, and other navigation aids'**
  String get vorNdbNavigation;

  /// Runway information description
  ///
  /// In en, this message translates to:
  /// **'Runway information for airports'**
  String get runwayInformation;

  /// Radio frequencies description
  ///
  /// In en, this message translates to:
  /// **'Radio frequencies for airports'**
  String get radioFrequencies;

  /// Additional runway data description
  ///
  /// In en, this message translates to:
  /// **'Additional runway data'**
  String get additionalRunwayData;

  /// Additional frequency data description
  ///
  /// In en, this message translates to:
  /// **'Additional frequency data'**
  String get additionalFrequencyData;

  /// Controlled airspaces description
  ///
  /// In en, this message translates to:
  /// **'Controlled airspaces and restricted areas'**
  String get controlledAirspaces;

  /// VFR reporting points description
  ///
  /// In en, this message translates to:
  /// **'VFR reporting points for navigation'**
  String get vfrReportingPoints;

  /// Towers and obstacles description
  ///
  /// In en, this message translates to:
  /// **'Towers, buildings, and other obstacles'**
  String get towersObstacles;

  /// Thermal activity description
  ///
  /// In en, this message translates to:
  /// **'Thermal activity and gliding hotspots'**
  String get thermalActivity;

  /// Navigation aids section title
  ///
  /// In en, this message translates to:
  /// **'Navigation Aids'**
  String get navigationAids;

  /// Additional runways section title
  ///
  /// In en, this message translates to:
  /// **'Additional Runways'**
  String get additionalRunways;

  /// Additional frequencies section title
  ///
  /// In en, this message translates to:
  /// **'Additional Frequencies'**
  String get additionalFrequencies;

  /// Reporting points section title
  ///
  /// In en, this message translates to:
  /// **'Reporting Points'**
  String get reportingPoints;

  /// Photos section title
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// Documents section title
  ///
  /// In en, this message translates to:
  /// **'Documents'**
  String get documents;

  /// No photos message
  ///
  /// In en, this message translates to:
  /// **'No photos yet'**
  String get noPhotosYet;

  /// Add photos instruction
  ///
  /// In en, this message translates to:
  /// **'Add photos from gallery or take new ones'**
  String get addPhotosFromGallery;

  /// Add document button label
  ///
  /// In en, this message translates to:
  /// **'Add Document'**
  String get addDocument;

  /// Add document image button label
  ///
  /// In en, this message translates to:
  /// **'Add Document Image'**
  String get addDocumentImage;

  /// Delete document button label
  ///
  /// In en, this message translates to:
  /// **'Delete Document'**
  String get deleteDocument;

  /// Delete photo button label
  ///
  /// In en, this message translates to:
  /// **'Delete Photo'**
  String get deletePhoto;

  /// Delete photo confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this photo?'**
  String get areYouSureDeletePhoto;

  /// Take photo button label
  ///
  /// In en, this message translates to:
  /// **'Take Photo'**
  String get takePhoto;

  /// Choose from gallery button label
  ///
  /// In en, this message translates to:
  /// **'Choose from Gallery'**
  String get chooseFromGallery;

  /// Add from gallery button label
  ///
  /// In en, this message translates to:
  /// **'Add from gallery'**
  String get addFromGallery;

  /// Add picture button label
  ///
  /// In en, this message translates to:
  /// **'Add Picture'**
  String get addPicture;

  /// Error adding document message
  ///
  /// In en, this message translates to:
  /// **'Error adding document: {error}'**
  String errorAddingDocument(String error);

  /// Error deleting document message
  ///
  /// In en, this message translates to:
  /// **'Error deleting document: {error}'**
  String errorDeletingDocument(String error);

  /// Error opening document message
  ///
  /// In en, this message translates to:
  /// **'Error opening document: {error}'**
  String errorOpeningDocument(String error);

  /// Error deleting photo message
  ///
  /// In en, this message translates to:
  /// **'Error deleting photo: {error}'**
  String errorDeletingPhoto(String error);

  /// Error picking image message
  ///
  /// In en, this message translates to:
  /// **'Error picking image: {error}'**
  String errorPickingImage(String error);

  /// Error taking photo message
  ///
  /// In en, this message translates to:
  /// **'Error taking photo: {error}'**
  String errorTakingPhoto(String error);

  /// Document added success message
  ///
  /// In en, this message translates to:
  /// **'Document added successfully'**
  String get documentAddedSuccessfully;

  /// Document deleted success message
  ///
  /// In en, this message translates to:
  /// **'Document deleted'**
  String get documentDeleted;

  /// Photo added success message
  ///
  /// In en, this message translates to:
  /// **'Photo added successfully'**
  String get photoAddedSuccessfully;

  /// Photo deleted success message
  ///
  /// In en, this message translates to:
  /// **'Photo deleted'**
  String get photoDeleted;

  /// Tap to open instruction
  ///
  /// In en, this message translates to:
  /// **'Tap to open'**
  String get tapToOpen;

  /// File not found error message
  ///
  /// In en, this message translates to:
  /// **'File not found'**
  String get fileNotFound;

  /// Confirm button label
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Update button label
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// Remove button label
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// Create button label
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Reset button label
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// Open button label
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get open;

  /// View button label
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get view;

  /// Manage button label
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// Load to map button label
  ///
  /// In en, this message translates to:
  /// **'Load to Map'**
  String get loadToMap;

  /// Edit name button label
  ///
  /// In en, this message translates to:
  /// **'Edit Name'**
  String get editName;

  /// Duplicate button label
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// Set as current button label
  ///
  /// In en, this message translates to:
  /// **'Set as Current'**
  String get setAsCurrent;

  /// Retry button label
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Stop download button label
  ///
  /// In en, this message translates to:
  /// **'Stop Download'**
  String get stopDownload;

  /// Manage licenses button label
  ///
  /// In en, this message translates to:
  /// **'Manage Licenses'**
  String get manageLicenses;

  /// Set QNH button label
  ///
  /// In en, this message translates to:
  /// **'Set QNH'**
  String get setQnh;

  /// Close button label
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Zoom in tooltip
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get zoomIn;

  /// Zoom out tooltip
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get zoomOut;

  /// Maximum zoom reached tooltip
  ///
  /// In en, this message translates to:
  /// **'Maximum zoom reached'**
  String get maximumZoomReached;

  /// Minimum zoom reached tooltip
  ///
  /// In en, this message translates to:
  /// **'Minimum zoom reached'**
  String get minimumZoomReached;

  /// Refresh all data tooltip
  ///
  /// In en, this message translates to:
  /// **'Refresh all data'**
  String get refreshAllData;

  /// Clear all caches tooltip
  ///
  /// In en, this message translates to:
  /// **'Clear all caches'**
  String get clearAllCaches;

  /// Clear map cache tooltip
  ///
  /// In en, this message translates to:
  /// **'Clear map cache'**
  String get clearMapCache;

  /// Refresh weather data tooltip
  ///
  /// In en, this message translates to:
  /// **'Refresh weather data'**
  String get refreshWeatherData;

  /// Start tracking button label
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get startTracking;

  /// Stop tracking button label
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopTracking;

  /// Error saving manufacturer message
  ///
  /// In en, this message translates to:
  /// **'Error saving manufacturer: {error}'**
  String errorSavingManufacturer(String error);

  /// Error saving model message
  ///
  /// In en, this message translates to:
  /// **'Error saving model: {error}'**
  String errorSavingModel(String error);

  /// Error saving aircraft message
  ///
  /// In en, this message translates to:
  /// **'Error saving aircraft: {error}'**
  String errorSavingAircraft(String error);

  /// Error when URL cannot be launched
  ///
  /// In en, this message translates to:
  /// **'Could not launch {url}'**
  String couldNotLaunchUrl(String url);

  /// Error for invalid URL format
  ///
  /// In en, this message translates to:
  /// **'Invalid URL format'**
  String get invalidUrlFormat;

  /// Altitude abbreviation for flight dashboard
  ///
  /// In en, this message translates to:
  /// **'ALT'**
  String get alt;

  /// Speed label for flight dashboard
  ///
  /// In en, this message translates to:
  /// **'SPEED'**
  String get speed;

  /// Time label for flight dashboard
  ///
  /// In en, this message translates to:
  /// **'TIME'**
  String get time;

  /// Distance abbreviation for flight dashboard
  ///
  /// In en, this message translates to:
  /// **'DIST'**
  String get dist;

  /// Vertical speed abbreviation for flight dashboard
  ///
  /// In en, this message translates to:
  /// **'V/S'**
  String get verticalSpeed;

  /// G-force abbreviation for flight dashboard
  ///
  /// In en, this message translates to:
  /// **'G'**
  String get gForce;

  /// Next waypoint label for flight dashboard
  ///
  /// In en, this message translates to:
  /// **'NEXT'**
  String get next;

  /// Estimated time of arrival abbreviation
  ///
  /// In en, this message translates to:
  /// **'ETA'**
  String get eta;

  /// Pressure abbreviation for flight dashboard
  ///
  /// In en, this message translates to:
  /// **'PRESS'**
  String get press;

  /// QNH pressure setting abbreviation
  ///
  /// In en, this message translates to:
  /// **'QNH'**
  String get qnh;

  /// Fuel label for flight dashboard
  ///
  /// In en, this message translates to:
  /// **'FUEL'**
  String get fuel;

  /// Current status label
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get current;

  /// Recording started label
  ///
  /// In en, this message translates to:
  /// **'Recording Started'**
  String get recordingStarted;

  /// Recording stopped label
  ///
  /// In en, this message translates to:
  /// **'Recording Stopped'**
  String get recordingStopped;

  /// First movement label
  ///
  /// In en, this message translates to:
  /// **'First Movement'**
  String get firstMovement;

  /// Last movement label
  ///
  /// In en, this message translates to:
  /// **'Last Movement'**
  String get lastMovement;

  /// Total recording time label
  ///
  /// In en, this message translates to:
  /// **'Total Recording'**
  String get totalRecording;

  /// Total moving time label
  ///
  /// In en, this message translates to:
  /// **'Total Moving'**
  String get totalMoving;

  /// Departure label
  ///
  /// In en, this message translates to:
  /// **'Departure'**
  String get departure;

  /// Arrival label
  ///
  /// In en, this message translates to:
  /// **'Arrival'**
  String get arrival;

  /// Stop flight tracking dialog title
  ///
  /// In en, this message translates to:
  /// **'Stop Flight Tracking?'**
  String get stopFlightTracking;

  /// Stop flight tracking confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to stop flight tracking?'**
  String get areYouSureStopTracking;

  /// Initializing flight systems loading message
  ///
  /// In en, this message translates to:
  /// **'Initializing flight systems...'**
  String get initializingFlightSystems;

  /// App tagline
  ///
  /// In en, this message translates to:
  /// **'Your digital co-pilot for VFR flights'**
  String get yourDigitalCopilot;

  /// Load data button label
  ///
  /// In en, this message translates to:
  /// **'Load Data'**
  String get loadData;

  /// Loading airspaces message
  ///
  /// In en, this message translates to:
  /// **'Loading airspaces'**
  String get loadingAirspaces;

  /// Some data still loading message
  ///
  /// In en, this message translates to:
  /// **'Some data may still be loading...'**
  String get someDataStillLoading;

  /// No heatmap data message
  ///
  /// In en, this message translates to:
  /// **'No heatmap data yet'**
  String get noHeatmapDataYet;

  /// Please open from map instruction
  ///
  /// In en, this message translates to:
  /// **'Please open this screen from the map to download the current area'**
  String get pleaseOpenFromMap;

  /// Total hours label for logbook
  ///
  /// In en, this message translates to:
  /// **'Total Hours'**
  String get totalHours;

  /// Single engine label for logbook
  ///
  /// In en, this message translates to:
  /// **'Single Engine'**
  String get singleEngine;

  /// Multi engine label for logbook
  ///
  /// In en, this message translates to:
  /// **'Multi Engine'**
  String get multiEngine;

  /// As pilot in command label for logbook
  ///
  /// In en, this message translates to:
  /// **'As PIC'**
  String get asPic;

  /// As second in command label for logbook
  ///
  /// In en, this message translates to:
  /// **'As SIC'**
  String get asSic;

  /// Solo flight label for logbook
  ///
  /// In en, this message translates to:
  /// **'Solo'**
  String get solo;

  /// VFR (Visual Flight Rules) label
  ///
  /// In en, this message translates to:
  /// **'VFR'**
  String get vfr;

  /// IFR (Instrument Flight Rules) label
  ///
  /// In en, this message translates to:
  /// **'IFR'**
  String get ifr;

  /// Day flight label
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get day;

  /// Night flight label
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get night;

  /// Simulator VFR label for logbook
  ///
  /// In en, this message translates to:
  /// **'Simulator VFR'**
  String get simulatorVfr;

  /// Simulator IFR label for logbook
  ///
  /// In en, this message translates to:
  /// **'Simulator IFR'**
  String get simulatorIfr;

  /// Total label
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// Hours unit label
  ///
  /// In en, this message translates to:
  /// **'Hours'**
  String get hours;

  /// Takeoffs and landings section title
  ///
  /// In en, this message translates to:
  /// **'Takeoffs & Landings'**
  String get takeoffsLandings;

  /// Day/Night section title
  ///
  /// In en, this message translates to:
  /// **'Day/Night'**
  String get dayNight;

  /// VFR/IFR field label
  ///
  /// In en, this message translates to:
  /// **'VFR/IFR'**
  String get vfrIfr;

  /// Day takeoffs label
  ///
  /// In en, this message translates to:
  /// **'Day Takeoffs'**
  String get dayTakeoffs;

  /// Night takeoffs label
  ///
  /// In en, this message translates to:
  /// **'Night Takeoffs'**
  String get nightTakeoffs;

  /// Day landings label
  ///
  /// In en, this message translates to:
  /// **'Day Landings'**
  String get dayLandings;

  /// Night landings label
  ///
  /// In en, this message translates to:
  /// **'Night Landings'**
  String get nightLandings;

  /// Engine type label
  ///
  /// In en, this message translates to:
  /// **'Engine Type'**
  String get engineType;

  /// Flight training label
  ///
  /// In en, this message translates to:
  /// **'Flight Training'**
  String get flightTraining;

  /// Ground training label
  ///
  /// In en, this message translates to:
  /// **'Ground Training'**
  String get groundTraining;

  /// Simulator label
  ///
  /// In en, this message translates to:
  /// **'Simulator'**
  String get simulator;

  /// Flight notes label
  ///
  /// In en, this message translates to:
  /// **'Flight Notes'**
  String get flightNotes;

  /// View original flight log button
  ///
  /// In en, this message translates to:
  /// **'View Original Flight Log'**
  String get viewOriginalFlightLog;

  /// Flight ID label
  ///
  /// In en, this message translates to:
  /// **'Flight ID: {id}'**
  String flightId(String id);

  /// Delete entry dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Entry'**
  String get deleteEntry;

  /// Delete pilot dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Pilot'**
  String get deletePilot;

  /// Add new pilot button label
  ///
  /// In en, this message translates to:
  /// **'Add New Pilot'**
  String get addNewPilot;

  /// Add endorsement dialog title
  ///
  /// In en, this message translates to:
  /// **'Add Endorsement'**
  String get addEndorsement;

  /// Edit endorsement dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit Endorsement'**
  String get editEndorsement;

  /// Delete endorsement dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete Endorsement'**
  String get deleteEndorsement;

  /// Pilot name field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get pilotName;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Phone field label
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// Certificate number field label
  ///
  /// In en, this message translates to:
  /// **'Certificate Number'**
  String get certificateNumber;

  /// Aircraft type field label
  ///
  /// In en, this message translates to:
  /// **'Aircraft Type'**
  String get aircraftType;

  /// Aircraft ID field label
  ///
  /// In en, this message translates to:
  /// **'Aircraft ID'**
  String get aircraftId;

  /// Select category dropdown label
  ///
  /// In en, this message translates to:
  /// **'Select Category'**
  String get selectCategory;

  /// Flight review endorsement category
  ///
  /// In en, this message translates to:
  /// **'Flight Review'**
  String get flightReview;

  /// IPC checkbox label
  ///
  /// In en, this message translates to:
  /// **'IPC'**
  String get ipc;

  /// Check ride endorsement category
  ///
  /// In en, this message translates to:
  /// **'Check Ride'**
  String get checkRide;

  /// FAA 61.58 checkbox label
  ///
  /// In en, this message translates to:
  /// **'FAA 61.58'**
  String get faa6158;

  /// NVG Proficiency checkbox label
  ///
  /// In en, this message translates to:
  /// **'NVG Proficiency'**
  String get nvgProficiency;

  /// Simulated conditions section title
  ///
  /// In en, this message translates to:
  /// **'Simulated Conditions'**
  String get simulatedConditions;

  /// Endorsement title field label
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get endorsementTitle;

  /// Additional details hint
  ///
  /// In en, this message translates to:
  /// **'Additional details'**
  String get additionalDetails;

  /// Info tab label
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// Runways tab label
  ///
  /// In en, this message translates to:
  /// **'Runways'**
  String get runways;

  /// Frequencies tab label
  ///
  /// In en, this message translates to:
  /// **'Frequencies'**
  String get frequencies;

  /// NOTAMs tab label
  ///
  /// In en, this message translates to:
  /// **'NOTAMs'**
  String get notams;

  /// Visit website button label
  ///
  /// In en, this message translates to:
  /// **'Visit Website'**
  String get visitWebsite;

  /// Call airport button label
  ///
  /// In en, this message translates to:
  /// **'Call {number}'**
  String callAirport(String number);

  /// Navigate to airport button label
  ///
  /// In en, this message translates to:
  /// **'Navigate to Airport'**
  String get navigateToAirport;

  /// ICAO code label
  ///
  /// In en, this message translates to:
  /// **'ICAO'**
  String get icao;

  /// IATA code label
  ///
  /// In en, this message translates to:
  /// **'IATA'**
  String get iata;

  /// Name field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// City field label
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get city;

  /// Lighted runway indicator
  ///
  /// In en, this message translates to:
  /// **'Lighted'**
  String get lighted;

  /// Closed runway indicator
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get closed;

  /// Type field label
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// Frequency field label
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get frequency;

  /// DME frequency field label
  ///
  /// In en, this message translates to:
  /// **'DME Frequency'**
  String get dmeFrequency;

  /// DME channel field label
  ///
  /// In en, this message translates to:
  /// **'DME Channel'**
  String get dmeChannel;

  /// Elevation field label
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get elevation;

  /// Country field label
  ///
  /// In en, this message translates to:
  /// **'Country'**
  String get country;

  /// Usage field label
  ///
  /// In en, this message translates to:
  /// **'Usage'**
  String get usage;

  /// Power field label
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get power;

  /// Associated airport field label
  ///
  /// In en, this message translates to:
  /// **'Associated Airport'**
  String get associatedAirport;

  /// Coordinates field label
  ///
  /// In en, this message translates to:
  /// **'Coordinates'**
  String get coordinates;

  /// Date field label
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get date;

  /// Cruise speed in knots field label
  ///
  /// In en, this message translates to:
  /// **'Cruise Speed (kts)'**
  String get cruiseSpeedKts;

  /// Fuel consumption in gallons per hour field label
  ///
  /// In en, this message translates to:
  /// **'Fuel Consumption (GPH)'**
  String get fuelConsumptionGph;

  /// Maximum altitude in feet field label
  ///
  /// In en, this message translates to:
  /// **'Max Altitude (ft)'**
  String get maxAltitudeFt;

  /// Fuel capacity in gallons field label
  ///
  /// In en, this message translates to:
  /// **'Fuel Capacity (gal)'**
  String get fuelCapacityGal;

  /// Maximum climb rate in feet per minute field label
  ///
  /// In en, this message translates to:
  /// **'Max Climb Rate (fpm)'**
  String get maxClimbRateFpm;

  /// Maximum descent rate in feet per minute field label
  ///
  /// In en, this message translates to:
  /// **'Max Descent Rate (fpm)'**
  String get maxDescentRateFpm;

  /// Maximum takeoff weight in pounds field label
  ///
  /// In en, this message translates to:
  /// **'Max Takeoff Weight (lbs)'**
  String get maxTakeoffWeightLbs;

  /// Maximum landing weight in pounds field label
  ///
  /// In en, this message translates to:
  /// **'Max Landing Weight (lbs)'**
  String get maxLandingWeightLbs;

  /// Takeoff ground roll in feet field label
  ///
  /// In en, this message translates to:
  /// **'Takeoff Ground Roll (ft)'**
  String get takeoffGroundRollFt;

  /// Takeoff over 50 feet in feet field label
  ///
  /// In en, this message translates to:
  /// **'Takeoff Over 50ft (ft)'**
  String get takeoffOver50ftFt;

  /// Landing ground roll in feet field label
  ///
  /// In en, this message translates to:
  /// **'Landing Ground Roll (ft)'**
  String get landingGroundRollFt;

  /// Landing over 50 feet in feet field label
  ///
  /// In en, this message translates to:
  /// **'Landing Over 50ft (ft)'**
  String get landingOver50ftFt;

  /// Vs1 clean configuration speed in knots field label
  ///
  /// In en, this message translates to:
  /// **'Vs1 (Clean) (kts)'**
  String get vs1CleanKts;

  /// Vs0 landing configuration speed in knots field label
  ///
  /// In en, this message translates to:
  /// **'Vs0 (Landing) (kts)'**
  String get vs0LandingKts;

  /// Vx best angle of climb speed in knots field label
  ///
  /// In en, this message translates to:
  /// **'Vx (Best Angle) (kts)'**
  String get vxBestAngleKts;

  /// Vy best rate of climb speed in knots field label
  ///
  /// In en, this message translates to:
  /// **'Vy (Best Rate) (kts)'**
  String get vyBestRateKts;

  /// Va maneuvering speed in knots field label
  ///
  /// In en, this message translates to:
  /// **'Va (Maneuvering) (kts)'**
  String get vaManeuveringKts;

  /// Vno maximum structural cruising speed in knots field label
  ///
  /// In en, this message translates to:
  /// **'Vno (Max Structural) (kts)'**
  String get vnoMaxStructuralKts;

  /// Vne never exceed speed in knots field label
  ///
  /// In en, this message translates to:
  /// **'Vne (Never Exceed) (kts)'**
  String get vneNeverExceedKts;

  /// Service ceiling in feet field label
  ///
  /// In en, this message translates to:
  /// **'Service Ceiling (ft)'**
  String get serviceCeilingFt;

  /// Best glide speed in knots field label
  ///
  /// In en, this message translates to:
  /// **'Best Glide Speed (kts)'**
  String get bestGlideSpeedKts;

  /// Best glide ratio field label
  ///
  /// In en, this message translates to:
  /// **'Best Glide Ratio'**
  String get bestGlideRatio;

  /// Empty weight in pounds field label
  ///
  /// In en, this message translates to:
  /// **'Empty Weight (lbs)'**
  String get emptyWeightLbs;

  /// Empty weight center of gravity field label
  ///
  /// In en, this message translates to:
  /// **'Empty Weight CG (inches from datum)'**
  String get emptyWeightCg;

  /// Climb parameters section title
  ///
  /// In en, this message translates to:
  /// **'Climb Parameters'**
  String get climbParameters;

  /// Flight parameters section title
  ///
  /// In en, this message translates to:
  /// **'Flight Parameters'**
  String get flightParameters;

  /// Wind information section title
  ///
  /// In en, this message translates to:
  /// **'Wind Information'**
  String get windInformation;

  /// Input method section title
  ///
  /// In en, this message translates to:
  /// **'Input Method'**
  String get inputMethod;

  /// Category field label
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// Convert button label
  ///
  /// In en, this message translates to:
  /// **'Convert'**
  String get convert;

  /// Results section title
  ///
  /// In en, this message translates to:
  /// **'Results'**
  String get results;

  /// Quick reference section title
  ///
  /// In en, this message translates to:
  /// **'Quick Reference'**
  String get quickReference;

  /// Weight and arm inputs section title
  ///
  /// In en, this message translates to:
  /// **'Weight & Arm Inputs'**
  String get weightArmInputs;

  /// Descent parameters section title
  ///
  /// In en, this message translates to:
  /// **'Descent Parameters'**
  String get descentParameters;

  /// Example manufacturer name
  ///
  /// In en, this message translates to:
  /// **'e.g., Cessna Aircraft Company'**
  String get egCessnaAircraft;

  /// Example manufacturer website
  ///
  /// In en, this message translates to:
  /// **'e.g., https://www.cessna.com'**
  String get egCessnaWebsite;

  /// Example model name
  ///
  /// In en, this message translates to:
  /// **'e.g., C172, PA-28'**
  String get egModelC172;

  /// Example aircraft name
  ///
  /// In en, this message translates to:
  /// **'e.g., My Cessna 172'**
  String get egMyCessna172;

  /// Example aircraft registration
  ///
  /// In en, this message translates to:
  /// **'e.g., N123AB'**
  String get egN123AB;

  /// Example license types
  ///
  /// In en, this message translates to:
  /// **'e.g., PPL, CPL, IR, Medical Class 1'**
  String get egPplCplIr;

  /// Example license name
  ///
  /// In en, this message translates to:
  /// **'e.g., Private Pilot License - SEP(land)'**
  String get egPrivatePilot;

  /// Example license number
  ///
  /// In en, this message translates to:
  /// **'e.g., UK.FCL.PPL.12345'**
  String get egUkFclPpl;

  /// Name field placeholder
  ///
  /// In en, this message translates to:
  /// **'John Doe'**
  String get johnDoe;

  /// Example pilot email
  ///
  /// In en, this message translates to:
  /// **'pilot@example.com'**
  String get pilotEmail;

  /// Example phone number
  ///
  /// In en, this message translates to:
  /// **'+1 234 567 8900'**
  String get phoneNumber;

  /// Example pilot ID number
  ///
  /// In en, this message translates to:
  /// **'123456789'**
  String get pilotIdNumber;

  /// ICAO code placeholder
  ///
  /// In en, this message translates to:
  /// **'ICAO'**
  String get icaoCode;

  /// ICAO code or name placeholder
  ///
  /// In en, this message translates to:
  /// **'ICAO code or name'**
  String get icaoCodeOrName;

  /// Example aircraft type
  ///
  /// In en, this message translates to:
  /// **'e.g., Cessna 172'**
  String get egCessna172;

  /// Example aircraft ID
  ///
  /// In en, this message translates to:
  /// **'e.g., N12345'**
  String get egN12345;

  /// Training activities placeholder
  ///
  /// In en, this message translates to:
  /// **'Training activities performed'**
  String get trainingActivities;

  /// Ground training field placeholder
  ///
  /// In en, this message translates to:
  /// **'Ground training received'**
  String get groundTrainingReceived;

  /// Simulator training field placeholder
  ///
  /// In en, this message translates to:
  /// **'Simulator training details'**
  String get simulatorTrainingDetails;

  /// Flight notes placeholder
  ///
  /// In en, this message translates to:
  /// **'Additional notes about the flight'**
  String get additionalFlightNotes;

  /// Enter pilot name placeholder
  ///
  /// In en, this message translates to:
  /// **'Enter pilot name'**
  String get enterPilotName;

  /// Example endorsement title
  ///
  /// In en, this message translates to:
  /// **'e.g., Complex Aircraft'**
  String get egComplexAircraft;

  /// Target value with degree symbol
  ///
  /// In en, this message translates to:
  /// **'Target: {value}°'**
  String target(String value);

  /// North direction abbreviation
  ///
  /// In en, this message translates to:
  /// **'N'**
  String get northShort;

  /// East direction abbreviation
  ///
  /// In en, this message translates to:
  /// **'E'**
  String get eastShort;

  /// South direction abbreviation
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get southShort;

  /// West direction abbreviation
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get westShort;

  /// Knots unit abbreviation
  ///
  /// In en, this message translates to:
  /// **'kts'**
  String get kts;

  /// Feet unit abbreviation
  ///
  /// In en, this message translates to:
  /// **'ft'**
  String get ft;

  /// Pounds unit abbreviation
  ///
  /// In en, this message translates to:
  /// **'lbs'**
  String get lbs;

  /// Gallons unit abbreviation
  ///
  /// In en, this message translates to:
  /// **'gal'**
  String get gal;

  /// Gallons per hour unit abbreviation
  ///
  /// In en, this message translates to:
  /// **'gph'**
  String get gph;

  /// Feet per minute unit abbreviation
  ///
  /// In en, this message translates to:
  /// **'fpm'**
  String get fpm;

  /// CaptainVFR website URL
  ///
  /// In en, this message translates to:
  /// **'www.captainvfr.com'**
  String get captainVfrWebsite;

  /// Required field validation message
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// Invalid speed validation message
  ///
  /// In en, this message translates to:
  /// **'Invalid speed'**
  String get invalidSpeed;

  /// Invalid fuel consumption validation message
  ///
  /// In en, this message translates to:
  /// **'Invalid consumption'**
  String get invalidConsumption;

  /// Invalid altitude validation message
  ///
  /// In en, this message translates to:
  /// **'Invalid altitude'**
  String get invalidAltitude;

  /// Invalid fuel capacity validation message
  ///
  /// In en, this message translates to:
  /// **'Invalid capacity'**
  String get invalidCapacity;

  /// Invalid rate validation message
  ///
  /// In en, this message translates to:
  /// **'Invalid rate'**
  String get invalidRate;

  /// Invalid weight validation message
  ///
  /// In en, this message translates to:
  /// **'Invalid weight'**
  String get invalidWeight;

  /// Aircraft added success message
  ///
  /// In en, this message translates to:
  /// **'Aircraft \"{name}\" added successfully'**
  String aircraftAddedSuccessfully(String name);

  /// Aircraft updated success message
  ///
  /// In en, this message translates to:
  /// **'Aircraft \"{name}\" updated successfully'**
  String aircraftUpdatedSuccessfully(String name);

  /// Manufacturer saved success message
  ///
  /// In en, this message translates to:
  /// **'Manufacturer \"{name}\" saved successfully'**
  String manufacturerSavedSuccessfully(String name);

  /// Notes field label
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// Waypoint notes input placeholder
  ///
  /// In en, this message translates to:
  /// **'Enter waypoint notes'**
  String get enterWaypointNotes;

  /// Delete waypoint confirmation message with name
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete waypoint \"{name}\"?'**
  String areYouSureDeleteWaypointWithName(String name);

  /// Airport waypoint type
  ///
  /// In en, this message translates to:
  /// **'Airport'**
  String get airport;

  /// Navaid waypoint type
  ///
  /// In en, this message translates to:
  /// **'Navaid'**
  String get navaid;

  /// Fix waypoint type
  ///
  /// In en, this message translates to:
  /// **'Fix'**
  String get fix;

  /// User waypoint type
  ///
  /// In en, this message translates to:
  /// **'User Waypoint'**
  String get userWaypoint;

  /// Altitude MSL field label
  ///
  /// In en, this message translates to:
  /// **'Altitude (MSL)'**
  String get altitudeMsl;

  /// Altitude input placeholder for meters
  ///
  /// In en, this message translates to:
  /// **'Enter altitude in meters'**
  String get enterAltitudeInMeters;

  /// No search results message with query
  ///
  /// In en, this message translates to:
  /// **'No results found for \"{query}\"'**
  String noResultsFoundForQuery(String query);

  /// Airports count label with count
  ///
  /// In en, this message translates to:
  /// **'Airports ({count})'**
  String airportsCountLabel(int count);

  /// Navigation aids count label with count
  ///
  /// In en, this message translates to:
  /// **'Navigation Aids ({count})'**
  String navigationAidsCountLabel(int count);

  /// Flight planning mode title
  ///
  /// In en, this message translates to:
  /// **'Flight Planning'**
  String get flightPlanningMode;

  /// No flight plan message
  ///
  /// In en, this message translates to:
  /// **'No Flight Plan'**
  String get noFlightPlan;

  /// Waypoints and distance summary
  ///
  /// In en, this message translates to:
  /// **'{count} waypoints • {distance} {unit}'**
  String waypointsAndDistance(int count, String distance, String unit);

  /// Edit mode label
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editMode;

  /// Edit mode instruction message
  ///
  /// In en, this message translates to:
  /// **'Click on the map to add waypoints • Click green + icons on flight path to insert waypoints'**
  String get clickOnMapToAddWaypoints;

  /// Cruise speed label with colon
  ///
  /// In en, this message translates to:
  /// **'Cruise Speed:'**
  String get cruiseSpeedLabel;

  /// Aircraft label with colon
  ///
  /// In en, this message translates to:
  /// **'Aircraft:'**
  String get aircraftLabel;

  /// Speed label with colon
  ///
  /// In en, this message translates to:
  /// **'Speed:'**
  String get speedLabel;

  /// Select aircraft dropdown hint
  ///
  /// In en, this message translates to:
  /// **'Select Aircraft'**
  String get selectAircraftHint;

  /// Knots unit abbreviation
  ///
  /// In en, this message translates to:
  /// **'kts'**
  String get ktsUnit;

  /// Location permission needed message
  ///
  /// In en, this message translates to:
  /// **'Location permission needed'**
  String get locationPermissionNeeded;

  /// Enable for compass heading message
  ///
  /// In en, this message translates to:
  /// **'Enable for compass heading'**
  String get enableForCompassHeading;

  /// Settings button label
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsButton;

  /// Map rotation mode description
  ///
  /// In en, this message translates to:
  /// **'How map and aircraft marker should rotate'**
  String get mapRotationDescription;

  /// No rotation option for map rotation mode
  ///
  /// In en, this message translates to:
  /// **'No Rotation'**
  String get noRotation;

  /// Map rotates option for map rotation mode
  ///
  /// In en, this message translates to:
  /// **'Map Rotates'**
  String get mapRotates;

  /// Aircraft rotates option for map rotation mode
  ///
  /// In en, this message translates to:
  /// **'Aircraft Rotates'**
  String get aircraftRotates;

  /// Description for no rotation mode
  ///
  /// In en, this message translates to:
  /// **'Map fixed north-up, aircraft marker fixed'**
  String get noRotationDescription;

  /// Description for map rotates mode
  ///
  /// In en, this message translates to:
  /// **'Map rotates with heading, aircraft points north'**
  String get mapRotatesDescription;

  /// Description for aircraft rotates mode
  ///
  /// In en, this message translates to:
  /// **'Map fixed north-up, aircraft rotates with heading'**
  String get aircraftRotatesDescription;

  /// Flight tracking section title
  ///
  /// In en, this message translates to:
  /// **'Flight Tracking'**
  String get flightTracking;

  /// High precision mode description
  ///
  /// In en, this message translates to:
  /// **'Use high accuracy GPS (uses more battery)'**
  String get highPrecisionDescription;

  /// Auto-create logbook entry description
  ///
  /// In en, this message translates to:
  /// **'Automatically create logbook entry after flight'**
  String get autoCreateLogbookDescription;

  /// Unit settings section title
  ///
  /// In en, this message translates to:
  /// **'Unit Settings'**
  String get unitSettings;

  /// Quick presets label
  ///
  /// In en, this message translates to:
  /// **'Quick Presets'**
  String get quickPresets;

  /// Apply common unit combinations description
  ///
  /// In en, this message translates to:
  /// **'Apply common unit combinations'**
  String get applyCommonUnitCombinations;

  /// Altitude label
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get altitude;

  /// Airspeed label
  ///
  /// In en, this message translates to:
  /// **'Airspeed'**
  String get airspeed;

  /// Feet unit
  ///
  /// In en, this message translates to:
  /// **'Feet'**
  String get feet;

  /// Meters unit
  ///
  /// In en, this message translates to:
  /// **'Meters'**
  String get meters;

  /// Nautical miles unit
  ///
  /// In en, this message translates to:
  /// **'Nautical Miles'**
  String get nauticalMiles;

  /// Kilometers unit
  ///
  /// In en, this message translates to:
  /// **'Kilometers'**
  String get kilometers;

  /// Statute miles unit
  ///
  /// In en, this message translates to:
  /// **'Statute Miles'**
  String get statuteMiles;

  /// Knots unit
  ///
  /// In en, this message translates to:
  /// **'Knots'**
  String get knots;

  /// Miles per hour unit
  ///
  /// In en, this message translates to:
  /// **'Miles per Hour'**
  String get milesPerHour;

  /// Kilometers per hour unit
  ///
  /// In en, this message translates to:
  /// **'Kilometers per Hour'**
  String get kilometersPerHour;

  /// Celsius unit
  ///
  /// In en, this message translates to:
  /// **'Celsius'**
  String get celsius;

  /// Fahrenheit unit
  ///
  /// In en, this message translates to:
  /// **'Fahrenheit'**
  String get fahrenheit;

  /// Pounds unit
  ///
  /// In en, this message translates to:
  /// **'Pounds'**
  String get pounds;

  /// Kilograms unit
  ///
  /// In en, this message translates to:
  /// **'Kilograms'**
  String get kilograms;

  /// Weight label
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// Pressure label
  ///
  /// In en, this message translates to:
  /// **'Pressure'**
  String get pressure;

  /// US gallons unit
  ///
  /// In en, this message translates to:
  /// **'US Gallons'**
  String get usGallons;

  /// Liters unit
  ///
  /// In en, this message translates to:
  /// **'Liters'**
  String get liters;

  /// Inches of mercury unit
  ///
  /// In en, this message translates to:
  /// **'Inches of Mercury'**
  String get inchesOfMercury;

  /// Hectopascals unit
  ///
  /// In en, this message translates to:
  /// **'Hectopascals'**
  String get hectopascals;

  /// Reset settings confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reset all settings to their default values?'**
  String get confirmResetSettings;

  /// Aviation data caches section title
  ///
  /// In en, this message translates to:
  /// **'Aviation Data Caches'**
  String get aviationDataCaches;

  /// Offline map tiles section title
  ///
  /// In en, this message translates to:
  /// **'Offline Map Tiles'**
  String get offlineMapTiles;

  /// Map tiles label
  ///
  /// In en, this message translates to:
  /// **'Map Tiles'**
  String get mapTiles;

  /// Input method using field elevation and altimeter setting
  ///
  /// In en, this message translates to:
  /// **'Field Elevation + Altimeter'**
  String get fieldElevationAltimeter;

  /// Input method using pressure altitude directly
  ///
  /// In en, this message translates to:
  /// **'Pressure Altitude'**
  String get pressureAltitudeInput;

  /// Input section title
  ///
  /// In en, this message translates to:
  /// **'Inputs'**
  String get inputs;

  /// Calculate button label
  ///
  /// In en, this message translates to:
  /// **'Calculate'**
  String get calculate;

  /// Heading to fly result label
  ///
  /// In en, this message translates to:
  /// **'Heading to Fly'**
  String get headingToFly;

  /// Ground speed result label
  ///
  /// In en, this message translates to:
  /// **'Ground Speed'**
  String get groundSpeed;

  /// Wind type result label
  ///
  /// In en, this message translates to:
  /// **'Wind Type'**
  String get windType;

  /// Flight fuel result label
  ///
  /// In en, this message translates to:
  /// **'Flight Fuel'**
  String get flightFuel;

  /// Reserve fuel result label
  ///
  /// In en, this message translates to:
  /// **'Reserve Fuel'**
  String get reserveFuel;

  /// LogBook screen title
  ///
  /// In en, this message translates to:
  /// **'LogBook'**
  String get logBook;

  /// Summary tab title
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// Logs tab title
  ///
  /// In en, this message translates to:
  /// **'Logs'**
  String get logs;

  /// Pilots tab title
  ///
  /// In en, this message translates to:
  /// **'Pilots'**
  String get pilots;

  /// Manual entry dialog title
  ///
  /// In en, this message translates to:
  /// **'Manual Entry'**
  String get manualEntry;

  /// Solo flight checkbox label
  ///
  /// In en, this message translates to:
  /// **'Solo Flight'**
  String get soloFlight;

  /// Linked flight log section title
  ///
  /// In en, this message translates to:
  /// **'Linked Flight Log'**
  String get linkedFlightLog;

  /// Wind components label
  ///
  /// In en, this message translates to:
  /// **'Wind Components'**
  String get windComponents;

  /// Wind component: headwind
  ///
  /// In en, this message translates to:
  /// **'Headwind'**
  String get headwind;

  /// Wind component: tailwind
  ///
  /// In en, this message translates to:
  /// **'Tailwind'**
  String get tailwind;

  /// Strong crosswind warning message
  ///
  /// In en, this message translates to:
  /// **'Very strong crosswind! Check aircraft limitations.'**
  String get strongCrosswindWarning;

  /// Significant crosswind warning message
  ///
  /// In en, this message translates to:
  /// **'Significant crosswind. Use proper technique.'**
  String get significantCrosswindWarning;

  /// High density altitude warning message
  ///
  /// In en, this message translates to:
  /// **'High density altitude! Aircraft performance will be significantly reduced.'**
  String get highDensityAltitudeWarning;

  /// Hint for runway heading field
  ///
  /// In en, this message translates to:
  /// **'Magnetic heading of the runway'**
  String get magneticHeadingHint;

  /// Hint for wind direction field
  ///
  /// In en, this message translates to:
  /// **'Direction wind is coming FROM'**
  String get windDirectionFromHint;

  /// Open settings button label
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// Continue tracking button label
  ///
  /// In en, this message translates to:
  /// **'Continue tracking'**
  String get continueTracking;

  /// Stop recording confirmation message
  ///
  /// In en, this message translates to:
  /// **'Do you want to stop recording your flight?'**
  String get areYouSureStopRecording;

  /// Stop button label
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No documents message
  ///
  /// In en, this message translates to:
  /// **'No documents yet'**
  String get noDocumentsYet;

  /// Add AFM/POH documents instruction
  ///
  /// In en, this message translates to:
  /// **'Add images of AFM, POH, or other aircraft documents'**
  String get addAfmPohDocuments;

  /// Delete document confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{fileName}\"?'**
  String areYouSureDeleteDocument(String fileName);

  /// Document addition explanation
  ///
  /// In en, this message translates to:
  /// **'You can add images of your aircraft documents (AFM, POH, etc.).\n\nNote: PDF and DOC files are not supported at this time.'**
  String get youCanAddDocumentImages;

  /// No aircraft available message
  ///
  /// In en, this message translates to:
  /// **'No aircraft available. Please add an aircraft first.'**
  String get noAircraftAvailable;

  /// Enter QNH value instruction
  ///
  /// In en, this message translates to:
  /// **'Enter QNH value in {unit}'**
  String enterQnhValue(String unit);

  /// QNH unit label
  ///
  /// In en, this message translates to:
  /// **'QNH ({unit})'**
  String qnhUnitLabel(String unit);

  /// Set button label
  ///
  /// In en, this message translates to:
  /// **'Set'**
  String get set;

  /// No pilots added message
  ///
  /// In en, this message translates to:
  /// **'No pilots added yet'**
  String get noPilotsAddedYet;

  /// Add first pilot instruction
  ///
  /// In en, this message translates to:
  /// **'Add yourself as the first pilot'**
  String get addFirstPilot;

  /// Edit logbook entry dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit LogBook Entry'**
  String get editLogBookEntry;

  /// New logbook entry dialog title
  ///
  /// In en, this message translates to:
  /// **'New LogBook Entry'**
  String get newLogBookEntry;

  /// Accelerometer sensor not available notification title
  ///
  /// In en, this message translates to:
  /// **'Accelerometer Not Available'**
  String get accelerometerNotAvailable;

  /// Vibration measurement not supported on platform message
  ///
  /// In en, this message translates to:
  /// **'Vibration measurement is not supported on {platform}'**
  String vibrationMeasurementNotSupported(String platform);

  /// Vibration measurement not supported in web browsers message
  ///
  /// In en, this message translates to:
  /// **'Vibration measurement is not supported in web browsers'**
  String get vibrationMeasurementNotSupportedWeb;

  /// Barometer unavailable message
  ///
  /// In en, this message translates to:
  /// **'Barometer not available'**
  String get barometerNotAvailable;

  /// Altitude sensors not available on platform message
  ///
  /// In en, this message translates to:
  /// **'Altitude sensors are not available on {platform}'**
  String altitudeSensorsNotAvailable(String platform);

  /// Altitude and pressure sensors not available in web browsers message
  ///
  /// In en, this message translates to:
  /// **'Altitude and pressure sensors are not available in web browsers'**
  String get altitudePressureSensorsNotAvailableWeb;

  /// Offline maps not available notification title
  ///
  /// In en, this message translates to:
  /// **'Offline Maps Not Available'**
  String get offlineMapsNotAvailable;

  /// Offline map storage not supported in web browsers message
  ///
  /// In en, this message translates to:
  /// **'Offline map storage is not supported in web browsers'**
  String get offlineMapsNotSupportedWeb;

  /// Location services disabled message
  ///
  /// In en, this message translates to:
  /// **'Location services disabled'**
  String get locationServicesDisabled;

  /// Enable location services prompt
  ///
  /// In en, this message translates to:
  /// **'Enable location services'**
  String get enableLocationServices;

  /// Location permission required notification title
  ///
  /// In en, this message translates to:
  /// **'Location Permission Required'**
  String get locationPermissionRequired;

  /// Location permission permanently denied message
  ///
  /// In en, this message translates to:
  /// **'Location permission denied. Enable in device settings.'**
  String get locationPermissionDeniedPermanently;

  /// Location permission needed for navigation message
  ///
  /// In en, this message translates to:
  /// **'Location permission needed for navigation features'**
  String get locationPermissionNeededForNavigation;

  /// Location service error notification title
  ///
  /// In en, this message translates to:
  /// **'Location Service Error'**
  String get locationServiceError;

  /// Unable to access location services error message
  ///
  /// In en, this message translates to:
  /// **'Unable to access location services'**
  String get unableToAccessLocationServices;

  /// Vibration measurement features disabled message
  ///
  /// In en, this message translates to:
  /// **'Vibration measurement features will be disabled'**
  String get vibrationMeasurementFeaturesDisabled;

  /// Barometer permission required notification title
  ///
  /// In en, this message translates to:
  /// **'Barometer Permission Required'**
  String get barometerPermissionRequired;

  /// Sensor permission needed for altitude measurements message
  ///
  /// In en, this message translates to:
  /// **'Sensor permission needed for altitude measurements'**
  String get sensorPermissionNeededForAltitude;

  /// Pressure altitude features limited message
  ///
  /// In en, this message translates to:
  /// **'Pressure altitude features will be limited'**
  String get pressureAltitudeFeaturesLimited;

  /// Message explaining that licenses and endorsements can be added later
  ///
  /// In en, this message translates to:
  /// **'You can add licenses and endorsements later in the Pilots tab'**
  String get canAddLicensesEndorsementsLater;

  /// State field label
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get state;

  /// Height field label
  ///
  /// In en, this message translates to:
  /// **'Height'**
  String get height;

  /// Total height field label
  ///
  /// In en, this message translates to:
  /// **'Total Height'**
  String get totalHeight;

  /// Marking field label
  ///
  /// In en, this message translates to:
  /// **'Marking'**
  String get marking;

  /// Reliability field label
  ///
  /// In en, this message translates to:
  /// **'Reliability'**
  String get reliability;

  /// Occurrence field label
  ///
  /// In en, this message translates to:
  /// **'Occurrence'**
  String get occurrence;

  /// Conditions field label
  ///
  /// In en, this message translates to:
  /// **'Conditions'**
  String get conditions;

  /// Timing field label
  ///
  /// In en, this message translates to:
  /// **'Timing'**
  String get timing;

  /// Start label
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// End label
  ///
  /// In en, this message translates to:
  /// **'End'**
  String get end;

  /// Start moving label
  ///
  /// In en, this message translates to:
  /// **'Start Moving'**
  String get startMoving;

  /// End moving label
  ///
  /// In en, this message translates to:
  /// **'End Moving'**
  String get endMoving;

  /// Day takeoffs short label
  ///
  /// In en, this message translates to:
  /// **'Day T/O'**
  String get dayTO;

  /// Night takeoffs short label
  ///
  /// In en, this message translates to:
  /// **'Night T/O'**
  String get nightTO;

  /// Day landings short label
  ///
  /// In en, this message translates to:
  /// **'Day Ldg'**
  String get dayLdg;

  /// Night landings short label
  ///
  /// In en, this message translates to:
  /// **'Night Ldg'**
  String get nightLdg;

  /// Optional field label
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// Current pilot label
  ///
  /// In en, this message translates to:
  /// **'Current Pilot'**
  String get currentPilot;

  /// Takeoffs label
  ///
  /// In en, this message translates to:
  /// **'Takeoffs'**
  String get takeoffs;

  /// Landings label
  ///
  /// In en, this message translates to:
  /// **'Landings'**
  String get landings;

  /// Title field label
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// Example hint for complex aircraft
  ///
  /// In en, this message translates to:
  /// **'e.g., Complex Aircraft'**
  String get complexAircraftExample;

  /// Validation message for title field
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get pleaseEnterTitle;

  /// Validation message for description field
  ///
  /// In en, this message translates to:
  /// **'Please enter a description'**
  String get pleaseEnterDescription;

  /// Validation message for pilot name field
  ///
  /// In en, this message translates to:
  /// **'Please enter pilot name'**
  String get pleaseEnterPilotName;

  /// Tags field label
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get tags;

  /// Yes answer
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No answer
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// To next waypoint label
  ///
  /// In en, this message translates to:
  /// **'TO NEXT WAYPOINT'**
  String get toNextWaypoint;

  /// License number label
  ///
  /// In en, this message translates to:
  /// **'License #:'**
  String get licenseNumber;

  /// License expires label
  ///
  /// In en, this message translates to:
  /// **'Expires:'**
  String get expires;

  /// No licenses added message
  ///
  /// In en, this message translates to:
  /// **'No licenses added yet'**
  String get noLicensesAddedYet;

  /// Dismiss button label
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismiss;

  /// Loading message for runway data
  ///
  /// In en, this message translates to:
  /// **'Loading runway data...'**
  String get loadingRunwayData;

  /// Loading message for wind data
  ///
  /// In en, this message translates to:
  /// **'Loading wind data...'**
  String get loadingWindData;

  /// Loading message for frequency data
  ///
  /// In en, this message translates to:
  /// **'Loading frequency data...'**
  String get loadingFrequencyData;

  /// Error when no aircraft selected
  ///
  /// In en, this message translates to:
  /// **'Please select an aircraft'**
  String get pleaseSelectAircraft;

  /// Error when aircraft has no performance data
  ///
  /// In en, this message translates to:
  /// **'Selected aircraft lacks performance data'**
  String get aircraftLacksPerformanceData;

  /// Calculate climb performance button label
  ///
  /// In en, this message translates to:
  /// **'Calculate Climb Performance'**
  String get calculateClimbPerformance;

  /// Calculate descent performance button label
  ///
  /// In en, this message translates to:
  /// **'Calculate Descent Performance'**
  String get calculateDescentPerformance;

  /// Calculate cruise performance button label
  ///
  /// In en, this message translates to:
  /// **'Calculate Cruise Performance'**
  String get calculateCruisePerformance;

  /// Loading weather data message
  ///
  /// In en, this message translates to:
  /// **'Loading weather data...'**
  String get loadingWeatherData;

  /// Refresh weather button label
  ///
  /// In en, this message translates to:
  /// **'Refresh Weather'**
  String get refreshWeather;

  /// No weather data available message
  ///
  /// In en, this message translates to:
  /// **'No weather data available for {icao}'**
  String noWeatherDataAvailable(String icao);

  /// GPS location acquisition message
  ///
  /// In en, this message translates to:
  /// **'Getting location...'**
  String get gettingLocation;

  /// GPS position acquisition status
  ///
  /// In en, this message translates to:
  /// **'Acquiring GPS position'**
  String get acquiringGpsPosition;

  /// App tagline
  ///
  /// In en, this message translates to:
  /// **'Your digital co-pilot for VFR flights'**
  String get appTagline;

  /// Initializing message
  ///
  /// In en, this message translates to:
  /// **'Initializing...'**
  String get initializing;

  /// No internet connection message
  ///
  /// In en, this message translates to:
  /// **'No internet connection. Some features may be limited.'**
  String get noInternetConnection;

  /// Segment number
  ///
  /// In en, this message translates to:
  /// **'Segment {number}'**
  String segmentNumber(int number);

  /// Waypoints count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No waypoints} =1{1 waypoint} other{{count} waypoints}}'**
  String waypointsCount(int count);

  /// Remove last waypoint tooltip
  ///
  /// In en, this message translates to:
  /// **'Remove last waypoint'**
  String get removeLastWaypoint;

  /// No waypoints added message
  ///
  /// In en, this message translates to:
  /// **'No waypoints added yet'**
  String get noWaypointsAdded;

  /// Default waypoint name
  ///
  /// In en, this message translates to:
  /// **'WP{number}'**
  String defaultWaypointName(int number);

  /// No runway data available message
  ///
  /// In en, this message translates to:
  /// **'No runway data available for this airport'**
  String get noRunwayDataAvailable;

  /// Runways count
  ///
  /// In en, this message translates to:
  /// **'Runways ({count})'**
  String runwaysCount(int count);

  /// Best runway indicator
  ///
  /// In en, this message translates to:
  /// **'BEST'**
  String get best;

  /// Width label
  ///
  /// In en, this message translates to:
  /// **'Width'**
  String get width;

  /// Surface label
  ///
  /// In en, this message translates to:
  /// **'Surface'**
  String get surface;

  /// Not available indicator
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get notAvailable;

  /// North compass direction
  ///
  /// In en, this message translates to:
  /// **'N'**
  String get north;

  /// East compass direction
  ///
  /// In en, this message translates to:
  /// **'E'**
  String get east;

  /// South compass direction
  ///
  /// In en, this message translates to:
  /// **'S'**
  String get south;

  /// West compass direction
  ///
  /// In en, this message translates to:
  /// **'W'**
  String get west;

  /// Target heading
  ///
  /// In en, this message translates to:
  /// **'Target: {degrees}°'**
  String targetHeading(String degrees);

  /// Required name field label
  ///
  /// In en, this message translates to:
  /// **'Name *'**
  String get nameRequired;

  /// Length field label
  ///
  /// In en, this message translates to:
  /// **'Length'**
  String get length;

  /// Heading field label
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get heading;

  /// GPS signal lost message
  ///
  /// In en, this message translates to:
  /// **'GPS signal lost'**
  String get gpsSignalLost;

  /// GPS tracking active status
  ///
  /// In en, this message translates to:
  /// **'Tracking GPS position'**
  String get trackingGpsPosition;

  /// Compass calibration message
  ///
  /// In en, this message translates to:
  /// **'Calibrating compass...'**
  String get calibratingCompass;

  /// Compass calibration instruction
  ///
  /// In en, this message translates to:
  /// **'Move device in figure 8'**
  String get moveDeviceFigureEight;

  /// Device compatibility check prompt
  ///
  /// In en, this message translates to:
  /// **'Check device compatibility'**
  String get checkDeviceCompatibility;

  /// Speed with unit label
  ///
  /// In en, this message translates to:
  /// **'Speed ({unit})'**
  String speedUnit(String unit);

  /// Turbulence in G-force label
  ///
  /// In en, this message translates to:
  /// **'Turbulence (g)'**
  String get turbulenceG;

  /// Error message when deleting license fails
  ///
  /// In en, this message translates to:
  /// **'Error deleting license: {error}'**
  String errorDeletingLicense(String error);

  /// Compass calibration requested message
  ///
  /// In en, this message translates to:
  /// **'Compass calibration requested'**
  String get compassCalibrationRequested;

  /// Success message after clearing all caches
  ///
  /// In en, this message translates to:
  /// **'All caches cleared successfully'**
  String get allCachesClearedSuccessfully;

  /// Error clearing caches
  ///
  /// In en, this message translates to:
  /// **'Error clearing caches: {error}'**
  String errorClearingCaches(String error);

  /// Message when download area is not available
  ///
  /// In en, this message translates to:
  /// **'Please open this screen from the map to download the current area'**
  String get pleaseOpenFromMapToDownload;

  /// Error adding picture
  ///
  /// In en, this message translates to:
  /// **'Failed to add picture: {error}'**
  String failedToAddPicture(String error);

  /// Error adding document
  ///
  /// In en, this message translates to:
  /// **'Failed to add document: {error}'**
  String failedToAddDocument(String error);

  /// Success message after adding pilot
  ///
  /// In en, this message translates to:
  /// **'Added pilot: {name}'**
  String addedPilot(String name);

  /// Warning dialog title for large downloads
  ///
  /// In en, this message translates to:
  /// **'Large Download Warning'**
  String get largeDownloadWarning;

  /// Downloading map tiles message
  ///
  /// In en, this message translates to:
  /// **'Downloading {count} map tiles for flight plan...'**
  String downloadingMapTiles(int count);

  /// Confirmation message for deleting checklist
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this checklist?'**
  String get areYouSureDeleteChecklist;

  /// Message when trying to select pilot without any pilots
  ///
  /// In en, this message translates to:
  /// **'Add a pilot first'**
  String get addPilotFirst;

  /// Email field placeholder
  ///
  /// In en, this message translates to:
  /// **'pilot@example.com'**
  String get pilotExampleEmail;

  /// Phone field placeholder
  ///
  /// In en, this message translates to:
  /// **'+1 234 567 8900'**
  String get phoneExample;

  /// Certificate number placeholder
  ///
  /// In en, this message translates to:
  /// **'123456789'**
  String get certificateNumberExample;

  /// Aircraft type field placeholder
  ///
  /// In en, this message translates to:
  /// **'e.g., Cessna 172'**
  String get aircraftTypeExample;

  /// Registration field placeholder
  ///
  /// In en, this message translates to:
  /// **'e.g., N12345'**
  String get registrationExample;

  /// Training activities field placeholder
  ///
  /// In en, this message translates to:
  /// **'Training activities performed'**
  String get trainingActivitiesPerformed;

  /// Additional notes field placeholder
  ///
  /// In en, this message translates to:
  /// **'Additional notes about the flight'**
  String get additionalNotesAboutFlight;

  /// Short aircraft type placeholder
  ///
  /// In en, this message translates to:
  /// **'C172'**
  String get aircraftShortExample;

  /// Short registration placeholder
  ///
  /// In en, this message translates to:
  /// **'N12345'**
  String get registrationShortExample;

  /// Wind direction helper text
  ///
  /// In en, this message translates to:
  /// **'Use negative value for tailwind'**
  String get useNegativeForTailwind;

  /// Wind speed helper text
  ///
  /// In en, this message translates to:
  /// **'Positive = tailwind, Negative = headwind'**
  String get positiveTailwindNegativeHeadwind;

  /// True course field label
  ///
  /// In en, this message translates to:
  /// **'True course to destination'**
  String get trueCourseToDestination;

  /// Fuel consumption field label
  ///
  /// In en, this message translates to:
  /// **'Average cruise fuel consumption'**
  String get averageCruiseFuelConsumption;

  /// FAA minimum reserve helper text
  ///
  /// In en, this message translates to:
  /// **'FAA minimum: 30 min VFR, 45 min IFR'**
  String get faaMinimumReserve;

  /// Total fuel field label
  ///
  /// In en, this message translates to:
  /// **'Total usable fuel on board'**
  String get totalUsableFuelOnBoard;

  /// Runway condition helper text
  ///
  /// In en, this message translates to:
  /// **'0 = Dry, 100 = Standing water/slush'**
  String get runwayConditionHelper;

  /// Download current area button label
  ///
  /// In en, this message translates to:
  /// **'Download Current Area'**
  String get downloadCurrentArea;

  /// Add license tooltip
  ///
  /// In en, this message translates to:
  /// **'Add License'**
  String get addLicense;

  /// Refresh data tooltip
  ///
  /// In en, this message translates to:
  /// **'Refresh {title}'**
  String refreshData(String title);

  /// Aircraft selection section title
  ///
  /// In en, this message translates to:
  /// **'Aircraft Selection'**
  String get aircraftSelection;

  /// Weight and arm inputs section title
  ///
  /// In en, this message translates to:
  /// **'Weight & Arm Inputs'**
  String get weightAndArmInputs;

  /// Edit flight plan name dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit Flight Plan Name'**
  String get editFlightPlanName;

  /// Download map tiles section title
  ///
  /// In en, this message translates to:
  /// **'Download Map Tiles'**
  String get downloadMapTiles;

  /// Right crosswind label
  ///
  /// In en, this message translates to:
  /// **'Right Crosswind'**
  String get rightCrosswind;

  /// Left crosswind label
  ///
  /// In en, this message translates to:
  /// **'Left Crosswind'**
  String get leftCrosswind;

  /// Light variable wind label
  ///
  /// In en, this message translates to:
  /// **'Light Variable'**
  String get lightVariable;

  /// License issued date label
  ///
  /// In en, this message translates to:
  /// **'Issued:'**
  String get issued;

  /// Engine type selection prompt
  ///
  /// In en, this message translates to:
  /// **'Please select engine type'**
  String get pleaseSelectEngineType;

  /// Pilot experience section title
  ///
  /// In en, this message translates to:
  /// **'Pilot Experience'**
  String get pilotExperience;

  /// Pilot in command selection prompt
  ///
  /// In en, this message translates to:
  /// **'Please select pilot in command'**
  String get pleaseSelectPilotInCommand;

  /// Conditions of flight section title
  ///
  /// In en, this message translates to:
  /// **'Conditions of Flight'**
  String get conditionsOfFlight;

  /// Departures and landings section title
  ///
  /// In en, this message translates to:
  /// **'Departures and Landings'**
  String get departuresAndLandings;

  /// Pictures and documents section title
  ///
  /// In en, this message translates to:
  /// **'Pictures and Documents'**
  String get picturesAndDocuments;

  /// Pictures count label
  ///
  /// In en, this message translates to:
  /// **'Pictures ({count})'**
  String picturesCount(int count);

  /// Documents count label
  ///
  /// In en, this message translates to:
  /// **'Documents ({count})'**
  String documentsCount(int count);

  /// Edit pilot title
  ///
  /// In en, this message translates to:
  /// **'Edit Pilot'**
  String get editPilot;

  /// Add pilot title
  ///
  /// In en, this message translates to:
  /// **'Add Pilot'**
  String get addPilot;

  /// Date of birth field label
  ///
  /// In en, this message translates to:
  /// **'Date of Birth'**
  String get dateOfBirth;

  /// Not set label
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get notSet;

  /// Contact information section title
  ///
  /// In en, this message translates to:
  /// **'Contact Information'**
  String get contactInformation;

  /// Invalid email validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email'**
  String get pleaseEnterValidEmail;

  /// Certificate information section title
  ///
  /// In en, this message translates to:
  /// **'Certificate Information'**
  String get certificateInformation;

  /// Set as current pilot checkbox label
  ///
  /// In en, this message translates to:
  /// **'Set as current pilot'**
  String get setAsCurrentPilot;

  /// Default pilot description
  ///
  /// In en, this message translates to:
  /// **'This pilot will be selected by default in new entries'**
  String get defaultPilotDescription;

  /// Update pilot button label
  ///
  /// In en, this message translates to:
  /// **'Update Pilot'**
  String get updatePilot;

  /// Certificate label
  ///
  /// In en, this message translates to:
  /// **'Certificate:'**
  String get certificate;

  /// Age label
  ///
  /// In en, this message translates to:
  /// **'Age: {age} years'**
  String age(int age);

  /// Years label
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get years;

  /// Licenses count
  ///
  /// In en, this message translates to:
  /// **'{count} Licenses'**
  String licensesCount(int count);

  /// Endorsements count
  ///
  /// In en, this message translates to:
  /// **'{count} Endorsements'**
  String endorsementsCount(int count);

  /// Confirm delete pilot
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {name}?'**
  String confirmDeletePilot(String name);

  /// No licenses added message
  ///
  /// In en, this message translates to:
  /// **'No licenses added'**
  String get noLicensesAdded;

  /// Endorsements section title
  ///
  /// In en, this message translates to:
  /// **'Endorsements'**
  String get endorsements;

  /// No endorsements added message
  ///
  /// In en, this message translates to:
  /// **'No endorsements added'**
  String get noEndorsementsAdded;

  /// Confirm delete license
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this license?'**
  String get confirmDeleteLicense;

  /// Confirm delete endorsement
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this endorsement?'**
  String get confirmDeleteEndorsement;

  /// Download map tiles description
  ///
  /// In en, this message translates to:
  /// **'Download map tiles for offline use'**
  String get downloadMapTilesDescription;

  /// Flight plan download map tiles option
  ///
  /// In en, this message translates to:
  /// **'Flight Plan Download Map Tiles'**
  String get flightPlanDownloadMapTiles;

  /// Automatically download flight plan tiles option
  ///
  /// In en, this message translates to:
  /// **'Automatically download map tiles for flight plans'**
  String get automaticallyDownloadFlightPlanTiles;

  /// Validate tiles on startup option
  ///
  /// In en, this message translates to:
  /// **'Validate Tiles on Startup'**
  String get validateTilesOnStartup;

  /// Check missing tiles on startup description
  ///
  /// In en, this message translates to:
  /// **'Check for missing tiles when app starts'**
  String get checkMissingTilesOnStartup;

  /// Minimum zoom level label
  ///
  /// In en, this message translates to:
  /// **'Min Zoom Level'**
  String get minZoom;

  /// Maximum zoom level label
  ///
  /// In en, this message translates to:
  /// **'Max Zoom Level'**
  String get maxZoom;

  /// Download progress tiles
  ///
  /// In en, this message translates to:
  /// **'{current}/{total} tiles'**
  String progressTiles(int current, int total);

  /// Downloaded tiles count
  ///
  /// In en, this message translates to:
  /// **'Downloaded: {count} tiles'**
  String downloadedTiles(int count);

  /// Skipped tiles count
  ///
  /// In en, this message translates to:
  /// **'Skipped: {count} tiles'**
  String skippedTiles(int count);

  /// Downloaded and skipped tiles message
  ///
  /// In en, this message translates to:
  /// **'Downloaded {downloaded} tiles, skipped {skipped}'**
  String downloadedTilesWithSkipped(int downloaded, int skipped);

  /// Downloaded tiles successfully message
  ///
  /// In en, this message translates to:
  /// **'Downloaded {count} tiles successfully'**
  String downloadedTilesSuccessfully(int count);

  /// Download cancelled message
  ///
  /// In en, this message translates to:
  /// **'Download cancelled'**
  String get downloadCancelled;

  /// Download failed message
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String downloadFailed(String error);

  /// Supplemental data label
  ///
  /// In en, this message translates to:
  /// **'Supplemental data'**
  String get supplementalData;

  /// Large download warning description
  ///
  /// In en, this message translates to:
  /// **'This will download approximately {count} map tiles. This may take a while and use significant data. Continue?'**
  String largeDownloadDescription(int count);

  /// Continue button text
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get continueText;

  /// Map layers section title
  ///
  /// In en, this message translates to:
  /// **'Map Layers'**
  String get mapLayers;

  /// Loading airports message
  ///
  /// In en, this message translates to:
  /// **'Loading airports...'**
  String get loadingAirports;

  /// Loading runways message
  ///
  /// In en, this message translates to:
  /// **'Loading runways...'**
  String get loadingRunways;

  /// Loading navaids message
  ///
  /// In en, this message translates to:
  /// **'Loading navaids...'**
  String get loadingNavaids;

  /// Loading frequencies message
  ///
  /// In en, this message translates to:
  /// **'Loading frequencies...'**
  String get loadingFrequencies;

  /// Data loading complete message
  ///
  /// In en, this message translates to:
  /// **'Data loading complete'**
  String get dataLoadingComplete;

  /// Confirm delete model dialog
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String confirmDeleteModel(String name);

  /// Model deleted success message
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{name}\"'**
  String deletedModel(String name);

  /// Confirm delete aircraft dialog
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"?'**
  String confirmDeleteAircraft(String name);

  /// Aircraft deleted success message
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{name}\"'**
  String deletedAircraft(String name);

  /// Manufacturer deleted success message
  ///
  /// In en, this message translates to:
  /// **'Deleted \"{name}\"'**
  String deletedManufacturer(String name);

  /// Confirm delete manufacturer dialog
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{name}\"? This will also delete all associated models.'**
  String confirmDeleteManufacturer(String name);

  /// Cache cleared success message
  ///
  /// In en, this message translates to:
  /// **'{name} cache cleared successfully'**
  String clearedCache(String name);

  /// ID label
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get id;

  /// Confirm delete logbook entry
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this logbook entry?'**
  String get confirmDeleteEntry;

  /// Navigation menu section title
  ///
  /// In en, this message translates to:
  /// **'Navigation'**
  String get navigation;

  /// Auto-centering countdown display
  ///
  /// In en, this message translates to:
  /// **'Auto in: {time}'**
  String autoInTime(String time);

  /// Stats menu item label
  ///
  /// In en, this message translates to:
  /// **'Stats'**
  String get stats;

  /// Flight menu item label
  ///
  /// In en, this message translates to:
  /// **'Flight'**
  String get flight;

  /// Checklists menu item label
  ///
  /// In en, this message translates to:
  /// **'Checklists'**
  String get checklists;

  /// Aircrafts menu item label
  ///
  /// In en, this message translates to:
  /// **'Aircrafts'**
  String get aircrafts;

  /// Flight plan tab label
  ///
  /// In en, this message translates to:
  /// **'Flight Plan'**
  String get flightPlan;

  /// Altitude profile tab label
  ///
  /// In en, this message translates to:
  /// **'Altitude Profile'**
  String get altitudeProfile;

  /// Airspace crossings section title
  ///
  /// In en, this message translates to:
  /// **'Airspace Crossings'**
  String get airspaceCrossings;

  /// Loading message when analyzing airspace profile
  ///
  /// In en, this message translates to:
  /// **'Analyzing airspace profile...'**
  String get analyzingAirspaceProfile;

  /// Message when no airspace profile is available
  ///
  /// In en, this message translates to:
  /// **'No airspace profile available'**
  String get noAirspaceProfileAvailable;

  /// Button label to analyze flight path
  ///
  /// In en, this message translates to:
  /// **'Analyze Flight Path'**
  String get analyzeFlightPath;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'cs',
    'de',
    'en',
    'es',
    'fr',
    'it',
    'sk',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'cs':
      return AppLocalizationsCs();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'it':
      return AppLocalizationsIt();
    case 'sk':
      return AppLocalizationsSk();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
