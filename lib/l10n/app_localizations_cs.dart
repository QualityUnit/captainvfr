// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Czech (`cs`).
class AppLocalizationsCs extends AppLocalizations {
  AppLocalizationsCs([String locale = 'cs']) : super(locale);

  @override
  String get appTitle => 'CaptainVFR';

  @override
  String get settings => 'Nastavení';

  @override
  String get language => 'Jazyk';

  @override
  String get selectLanguage => 'Vybrat jazyk';

  @override
  String get map => 'Mapa';

  @override
  String get tracking => 'Sledování';

  @override
  String get units => 'Jednotky';

  @override
  String get rotateWithHeading => 'Otáčet s kurzem';

  @override
  String get highPrecisionGps => 'Vysoce přesné GPS';

  @override
  String get autoCreateLogbook => 'Automaticky vytvořit záznam v deníku';

  @override
  String get presets => 'Předvolby';

  @override
  String get flightPlanning => 'Plánování letu';

  @override
  String get createTrip => 'Vytvořit cestu';

  @override
  String get tripName => 'Název cesty';

  @override
  String get enterTripName => 'Zadejte název cesty';

  @override
  String get selectFlightPlans => 'Vyberte letové plány';

  @override
  String get noFlightPlansSelected => 'Nejsou vybrány žádné letové plány';

  @override
  String get tripCreated => 'Cesta byla úspěšně vytvořena';

  @override
  String get centerOnFlightPlan => 'Vycentrovat mapu na letový plán';

  @override
  String get clearFlightPlan => 'Odstranit letový plán z mapy';

  @override
  String get deleteLeg => 'Smazat úsek';

  @override
  String deleteLegConfirmation(String legName) {
    return 'Opravdu chcete smazat úsek \"$legName\" z cesty?';
  }

  @override
  String get addToTrip => 'Přidat do cesty';

  @override
  String get replaceCurrent => 'Nahradit aktuální';

  @override
  String get addFlightPlanToTrip => 'Přidat letový plán do cesty';

  @override
  String get clear => 'Vymazat';

  @override
  String get addedTo => 'Přidáno do cesty:';

  @override
  String get weather => 'Počasí';

  @override
  String get flightLog => 'Letový deník';

  @override
  String get aircraft => 'Letadlo';

  @override
  String get calculators => 'Kalkulačky';

  @override
  String get offlineData => 'Offline data';

  @override
  String get licenses => 'Licence';

  @override
  String get checklist => 'Kontrolní seznam';

  @override
  String get cancel => 'Zrušit';

  @override
  String get save => 'Uložit';

  @override
  String get delete => 'Smazat';

  @override
  String get edit => 'Upravit';

  @override
  String get add => 'Přidat';

  @override
  String get search => 'Hledat';

  @override
  String get loading => 'Načítání...';

  @override
  String get center => 'Vystředit';

  @override
  String get layers => 'Vrstvy';

  @override
  String get airports => 'Letiště';

  @override
  String get airspaces => 'Vzdušné prostory';

  @override
  String get pilotCalculators => 'Pilotské kalkulačky';

  @override
  String get flightDetail => 'Detail letu';

  @override
  String get manufacturers => 'Výrobci';

  @override
  String get noAircraftConfigured => 'Žádné letadlo není nakonfigurováno';

  @override
  String get addAircraftInSettings => 'Přidejte letadlo v nastaveních';

  @override
  String get selectAircraft => 'Vybrat letadlo';

  @override
  String get cruiseSpeed => 'Cestovní rychlost';

  @override
  String get fuelBurn => 'Spotřeba paliva';

  @override
  String get mtow => 'MTOW';

  @override
  String get addAircraft => 'Přidat letadlo';

  @override
  String get editAircraft => 'Upravit letadlo';

  @override
  String get deleteAircraft => 'Smazat letadlo';

  @override
  String get aircraftName => 'Název letadla';

  @override
  String get registration => 'Registrace';

  @override
  String get manufacturer => 'Výrobce';

  @override
  String get model => 'Model';

  @override
  String get basicInformation => 'Základní informace';

  @override
  String get performanceSpecifications => 'Specifikace výkonu';

  @override
  String get optionalPerformanceData => 'Volitelné údaje o výkonu';

  @override
  String get takeoffLandingPerformance => 'Výkon vzletu a přistání';

  @override
  String get vSpeeds => 'V-rychlosti';

  @override
  String get additionalPerformanceData => 'Dodatečné údaje o výkonu';

  @override
  String get pleaseEnterAircraftName => 'Prosím zadejte název letadla';

  @override
  String get pleaseSelectManufacturer => 'Prosím vyberte výrobce';

  @override
  String get pleaseSelectModel => 'Prosím vyberte model';

  @override
  String get aircraftSavedSuccessfully => 'Letadlo úspěšně uloženo';

  @override
  String get addFirstAircraft => 'Přidat první letadlo';

  @override
  String get addManufacturer => 'Přidat výrobce';

  @override
  String get editManufacturer => 'Upravit výrobce';

  @override
  String get deleteManufacturer => 'Smazat výrobce';

  @override
  String get manufacturerName => 'Název výrobce';

  @override
  String get website => 'Webová stránka';

  @override
  String get description => 'Popis';

  @override
  String get pleaseEnterManufacturerName => 'Prosím zadejte název výrobce';

  @override
  String get pleaseEnterValidUrl => 'Prosím zadejte platnou URL';

  @override
  String get briefDescriptionOfManufacturer => 'Krátký popis výrobce';

  @override
  String get manufacturerAddedSuccessfully => 'Výrobce úspěšně přidán';

  @override
  String get manufacturerUpdatedSuccessfully => 'Výrobce úspěšně aktualizován';

  @override
  String get addModel => 'Přidat model';

  @override
  String get editModel => 'Upravit model';

  @override
  String get deleteModel => 'Smazat model';

  @override
  String get modelName => 'Název modelu';

  @override
  String get aircraftCategory => 'Kategorie letadla';

  @override
  String get engineCount => 'Počet motorů';

  @override
  String get maximumSeats => 'Maximální počet sedadel';

  @override
  String get typicalCruiseSpeed => 'Typická cestovní rychlost (kts)';

  @override
  String get serviceCeiling => 'Provozní dostup (ft)';

  @override
  String get fuelConsumption => 'Spotřeba paliva (gph)';

  @override
  String get maxClimbRate => 'Max. stoupavost (fpm)';

  @override
  String get maxDescentRate => 'Max. klesavost (fpm)';

  @override
  String get maxTakeoffWeight => 'Max. vzletová hmotnost (lbs)';

  @override
  String get maxLandingWeight => 'Max. přistávací hmotnost (lbs)';

  @override
  String get fuelCapacity => 'Kapacita paliva (galony)';

  @override
  String get pleaseEnterModelName => 'Prosím zadejte název modelu';

  @override
  String get pleaseEnterEngineCount => 'Prosím zadejte počet motorů';

  @override
  String get pleaseEnterValidEngineCount =>
      'Prosím zadejte platný počet motorů';

  @override
  String get pleaseEnterMaximumSeats =>
      'Prosím zadejte maximální počet sedadel';

  @override
  String get pleaseEnterValidSeatCount => 'Prosím zadejte platný počet sedadel';

  @override
  String get pleaseEnterCruiseSpeed => 'Prosím zadejte cestovní rychlost';

  @override
  String get pleaseEnterValidSpeed => 'Prosím zadejte platnou rychlost';

  @override
  String get pleaseEnterServiceCeiling => 'Prosím zadejte provozní dostup';

  @override
  String get pleaseEnterValidCeiling => 'Prosím zadejte platný dostup';

  @override
  String get modelAddedSuccessfully => 'Model úspěšně přidán';

  @override
  String get modelUpdatedSuccessfully => 'Model úspěšně aktualizován';

  @override
  String get addFirstModel => 'Přidat první model';

  @override
  String get addChecklist => 'Přidat kontrolní seznam';

  @override
  String get editChecklist => 'Upravit kontrolní seznam';

  @override
  String get deleteChecklist => 'Smazat kontrolní seznam';

  @override
  String get checklistName => 'Název';

  @override
  String get checklistDescription => 'Popis';

  @override
  String get items => 'Položky';

  @override
  String get addItem => 'Přidat položku';

  @override
  String get editItem => 'Upravit položku';

  @override
  String get targetValue => 'Cílová hodnota';

  @override
  String get pleaseEnterName => 'Prosím zadejte název';

  @override
  String get pleaseEnterItemName => 'Prosím zadejte název položky';

  @override
  String get saveChecklist => 'Uložit kontrolní seznam';

  @override
  String get searchAirportsNavaids => 'Hledat letiště a navigační pomůcky';

  @override
  String get enterAirportNavaidName =>
      'Zadejte název, kód nebo město letiště/navigační pomůcky';

  @override
  String get searchForAirports =>
      'Hledejte letiště a navigační pomůcky podle názvu nebo kódu\n(např. \"KJFK\", \"Kennedy\", \"VOR\", \"SFO\")';

  @override
  String get searchHistoryEmpty => 'Žádné nedávné vyhledávání';

  @override
  String get recentSearches => 'Nedávné vyhledávání';

  @override
  String get clearHistory => 'Vymazat';

  @override
  String noResultsFound(String query) {
    return 'Žádné výsledky nenalezeny pro \"$query\"';
  }

  @override
  String get trySearchingBy =>
      'Zkuste hledat podle:\n• Název letiště (např. \"Kennedy\")\n• ICAO kód (např. \"KJFK\")\n• IATA kód (např. \"JFK\")\n• ID navigační pomůcky (např. \"SFO\")\n• Název VOR/NDB';

  @override
  String airportsCount(int count) {
    return 'Letiště ($count)';
  }

  @override
  String navigationAidsCount(int count) {
    return 'Navigační pomůcky ($count)';
  }

  @override
  String get newFlightPlan => 'Nový letů plán';

  @override
  String get flightPlanName => 'Název letů plánu';

  @override
  String get enterFlightPlanName => 'Zadejte název letů plánu';

  @override
  String get deleteFlightPlan => 'Smazat letů plán';

  @override
  String loadedFlightPlan(String name) {
    return 'Načten letů plán: $name';
  }

  @override
  String get flightPlanDuplicated => 'Letů plán duplikovan';

  @override
  String get flightPlanDeleted => 'Letů plán smazán';

  @override
  String editWaypoint(int index) {
    return 'Upravit waypoint $index';
  }

  @override
  String get deleteWaypoint => 'Smazat waypoint';

  @override
  String areYouSureDeleteWaypoint(String name) {
    return 'Jste si jisti, že chcete smazat waypoint \"$name\"?';
  }

  @override
  String get position => 'Pozice';

  @override
  String get waypointName => 'Název';

  @override
  String get enterWaypointName => 'Zadejte název waypoint';

  @override
  String get altitudeFtMsl => 'Výška (ft MSL)';

  @override
  String get altitudeMetersMsl => 'Výška (m MSL)';

  @override
  String get enterAltitudeInFeet => 'Zadejte výšku v stopách';

  @override
  String get pilotLicenses => 'Pilotské licence';

  @override
  String get addYourFirstLicense => 'Přidejte svou první licenci';

  @override
  String get deleteLicense => 'Smazat licenci';

  @override
  String areYouSureDeleteLicense(String name) {
    return 'Jste si jisti, že chcete smazat \"$name\"?';
  }

  @override
  String get assignToPilot => 'Přiřadit pilotovi';

  @override
  String get licenseDeletedSuccessfully => 'Licence smazána';

  @override
  String errorSavingLicense(String error) {
    return 'Chyba při ukládání licence: $error';
  }

  @override
  String get issueDate => 'Datum vydání';

  @override
  String get expirationDate => 'Datum expirace';

  @override
  String get validFrom => 'Platné od';

  @override
  String get validTo => 'Platné do';

  @override
  String get hasExpiration => 'Má expiraci';

  @override
  String get licenseImages => 'Obrázky licence';

  @override
  String get noImagesYet => 'Zatím žádné obrázky';

  @override
  String get addPhotosOfLicense => 'Přidejte fotografie své licence';

  @override
  String get deleteFlight => 'Smazat let';

  @override
  String get flightDeletedSuccessfully => 'Let úspěšně smazán';

  @override
  String errorDeletingFlight(String error) {
    return 'Chyba při mazání letu: $error';
  }

  @override
  String get logbookEntryCreatedSuccessfully =>
      'Záznam v deníku úspěšně vytvořen';

  @override
  String errorCreatingLogbookEntry(String error) {
    return 'Chyba při vytváření záznamu v deníku: $error';
  }

  @override
  String get departureAirport => 'Letiště odletu';

  @override
  String get arrivalAirport => 'Letiště příletu';

  @override
  String get pilotInCommand => 'Velitel letadla';

  @override
  String get secondInCommand => 'Druhý pilot';

  @override
  String get flightSummary => 'Souhrn letu';

  @override
  String get flightDetails => 'Detaily letu';

  @override
  String get timeTracking => 'Sledování času';

  @override
  String get maxSpeed => 'Max. rychlost';

  @override
  String get maxAltitude => 'Max. výška';

  @override
  String get distance => 'Vzdálenost';

  @override
  String get avgSpeed => 'Prům. rychlost';

  @override
  String get startAlt => 'Počáteční výška';

  @override
  String get endAlt => 'Konečná výška';

  @override
  String get flightSegments => 'Segmenty letu';

  @override
  String get noSegmentsDataAvailable => 'Žádná data segmentů nejsou dostupná';

  @override
  String get noFlightPathDataAvailable =>
      'Žádná data drahý letu nejsou dostupná';

  @override
  String get noSpeedDataAvailable =>
      'Žádná data rychlosti nejsou dostupná\nSpusťte sledování pro zobrazení změn rychlosti';

  @override
  String get noTurbulenceDataAvailable =>
      'Žádná data turbulence nejsou dostupná\nSpusťte sledování pro zobrazení dat turbulence';

  @override
  String get densityAltitude => 'Hustotín výška';

  @override
  String get weightBalance => 'Váha a vyvazování';

  @override
  String get takeoffLanding => 'Vzlet a přistání';

  @override
  String get fuelBurnCalc => 'Spotřeba paliva';

  @override
  String get climbPerformance => 'Výkon stoupání';

  @override
  String get cruisePerformance => 'Výkon cestovní rychlosti';

  @override
  String get descentPerformance => 'Výkon klesání';

  @override
  String get crosswind => 'Boční vítr';

  @override
  String get windCorrection => 'Korekce větru';

  @override
  String get unitConversion => 'Převod jednotek';

  @override
  String get fieldElevation => 'Nadmořská výška letiště';

  @override
  String get altimeterSetting => 'Nastavení výškoměru';

  @override
  String get pressureAltitude => 'Tlaková výška';

  @override
  String get temperature => 'Teplota';

  @override
  String get currentAltitude => 'Aktuální výška';

  @override
  String get targetAltitude => 'Cílová výška';

  @override
  String get currentWeight => 'Aktuální váha';

  @override
  String get headwindComponent => 'Složka protivětru';

  @override
  String get fuelFlowRate => 'Průtok paliva';

  @override
  String get flightTimeHours => 'Čas letu (hodiny)';

  @override
  String get minutes => 'Minuty';

  @override
  String get reserveTimeMinutes => 'Rezervní čas (minuty)';

  @override
  String get availableFuel => 'Dostupné palivo';

  @override
  String get runwayHeading => 'Kurz dráhy (°)';

  @override
  String get windDirection => 'Směr větru (°)';

  @override
  String get windSpeed => 'Rychlost větru';

  @override
  String get desiredCourse => 'Žádaný kurz (°)';

  @override
  String get trueAirspeed => 'Skutečná rychlost';

  @override
  String get environmentalConditions => 'Podmínky prostředí';

  @override
  String get runwayContamination => 'Kontaminace drahý (%)';

  @override
  String get aircraftWeight => 'Váha letadla';

  @override
  String get missingMapTiles => 'Chybí dlaždice mapy';

  @override
  String get downloadNow => 'Stáhnout nyní';

  @override
  String get later => 'Později';

  @override
  String get couldNotGetCurrentLocation => 'Nelze získat aktuální polohu';

  @override
  String get errorShowingAirportDetails =>
      'Chyba při zobrazení detailů letiště';

  @override
  String get errorShowingNavaidDetails =>
      'Chyba při zobrazení detailů navigační pomůcky';

  @override
  String get errorShowingAirspaceDetails =>
      'Chyba při zobrazení detailů vzdušného prostoru';

  @override
  String get errorShowingReportingPointDetails =>
      'Chyba při zobrazení detailů hlášení bodu';

  @override
  String get errorShowingObstacleDetails =>
      'Chyba při zobrazení detailů překážky';

  @override
  String get errorShowingHotspotDetails =>
      'Chyba při zobrazení detailů hotspotu';

  @override
  String get heliports => 'Heliporty';

  @override
  String get navaids => 'Navigační pomůcky';

  @override
  String get metar => 'METAR';

  @override
  String get obstacles => 'Překážky';

  @override
  String get hotspots => 'Hotspoty';

  @override
  String get heatmap => 'Tepelná mapa';

  @override
  String get currentAirspace => 'Aktuální vzdušný prostor';

  @override
  String get planning => 'Plánování';

  @override
  String get noAirspaceAtCurrentPosition =>
      'Žádný vzdušný prostor na aktuální pozici';

  @override
  String get currentAirspaceLabel => 'AKTUÁLNÍ VZDUŠNÝ PROSTOR';

  @override
  String get nextAirspace => 'DALŠÍ VZDUŠNÝ PROSTOR';

  @override
  String get airspaceExit => 'VÝSTUP ZE VZDUŠNÉHO PROSTORU';

  @override
  String exitingAirspace(String name) {
    return 'Opouštění $name';
  }

  @override
  String get licenseAttentionRequired => 'Licence vyžaduje pozornost';

  @override
  String get immediateAttentionRequired => 'Vyžaduje okamžitou pozornost';

  @override
  String get mapSettings => 'Nastavení mapy';

  @override
  String get mapRotationMode => 'Režim rotace mapy';

  @override
  String get howMapRotates => 'Jak se má mapa a značka letadla otáčet';

  @override
  String get highPrecisionMode => 'Režim vysoké přesnosti';

  @override
  String get useHighAccuracyGps =>
      'Použít vysoce přesné GPS (spotřebuje více baterie)';

  @override
  String get autoCreateLogbookEntry => 'Automaticky vytvořit záznam v deníku';

  @override
  String get automaticallyCreateLogbook =>
      'Automaticky vytvořit záznam v deníku po letu';

  @override
  String get europeanAviation => 'Evropské letectví';

  @override
  String get usGeneralAviation => 'Americké obecné letectví';

  @override
  String get metricPreference => 'Metrické preference';

  @override
  String get mixedInternational => 'Smíšené mezinárodní';

  @override
  String get legacyMetric => 'Zastarálé metrické';

  @override
  String get legacyImperial => 'Zastarálé imperální';

  @override
  String get resetToDefaults => 'Obnovit výchozí';

  @override
  String get resetSettings => 'Obnovit nastavení';

  @override
  String get settingsResetToDefaults => 'Nastavení obnoveno na výchozí';

  @override
  String get refreshingAllAviationData => 'Obnovování všech leteckých dat...';

  @override
  String get allDataRefreshedSuccessfully => 'Všechna data úspěšně obnovena';

  @override
  String errorRefreshingData(String error) {
    return 'Chyba při obnovování dat: $error';
  }

  @override
  String get refreshingWeatherData => 'Obnovování meteorologických dat...';

  @override
  String get weatherDataRefreshedSuccessfully =>
      'Meteorologická data úspěšně obnovena';

  @override
  String errorRefreshingWeatherData(String error) {
    return 'Chyba při obnovování meteorologických dat: $error';
  }

  @override
  String errorLoadingCacheStats(String error) {
    return 'Chyba při načítání statistik cache: $error';
  }

  @override
  String get clearCache => 'Vymazat cache';

  @override
  String get cacheCleared => 'Cache úspěšně vymazána';

  @override
  String get allCachesCleared => 'Všechny cache úspěšně vymazány';

  @override
  String errorClearingCache(String name, String error) {
    return 'Chyba při mazání cache: $error';
  }

  @override
  String get airportInformation => 'Informace a detaily letišť';

  @override
  String get vorNdbNavigation => 'VOR, NDB a další navigační pomůcky';

  @override
  String get runwayInformation => 'Informace o drahách letišť';

  @override
  String get radioFrequencies => 'Rádiové frekvence letišť';

  @override
  String get additionalRunwayData => 'Dodatečné údaje o drahách';

  @override
  String get additionalFrequencyData => 'Dodatečné údaje o frekvencích';

  @override
  String get controlledAirspaces =>
      'Kontrolované vzdušné prostory a zakázané oblasti';

  @override
  String get vfrReportingPoints => 'VFR hlášení body pro navigaci';

  @override
  String get towersObstacles => 'Věže, budovy a další překážky';

  @override
  String get thermalActivity => 'Termická činnost a kluzákové hotspoty';

  @override
  String get navigationAids => 'Navigační pomůcky';

  @override
  String get additionalRunways => 'Dodatečné drahy';

  @override
  String get additionalFrequencies => 'Dodatečné frekvence';

  @override
  String get reportingPoints => 'Hlášení body';

  @override
  String get photos => 'Fotografie';

  @override
  String get documents => 'Dokumenty';

  @override
  String get noPhotosYet => 'Zatím žádné fotografie';

  @override
  String get addPhotosFromGallery =>
      'Přidejte fotografie z galerie nebo nafotěte nové';

  @override
  String get addDocument => 'Přidat dokument';

  @override
  String get addDocumentImage => 'Přidat obrázek dokumentu';

  @override
  String get deleteDocument => 'Smazat dokument';

  @override
  String get deletePhoto => 'Smazat fotografii';

  @override
  String get areYouSureDeletePhoto =>
      'Jste si jisti, že chcete smazat tuto fotografii?';

  @override
  String get takePhoto => 'Vyfotit';

  @override
  String get chooseFromGallery => 'Vybrat z galerie';

  @override
  String get addFromGallery => 'Přidat z galerie';

  @override
  String get addPicture => 'Přidat obrázek';

  @override
  String errorAddingDocument(String error) {
    return 'Chyba při přidávání dokumentu: $error';
  }

  @override
  String errorDeletingDocument(String error) {
    return 'Chyba při mazání dokumentu: $error';
  }

  @override
  String errorOpeningDocument(String error) {
    return 'Chyba při otevírání dokumentu: $error';
  }

  @override
  String errorDeletingPhoto(String error) {
    return 'Chyba při mazání fotografie: $error';
  }

  @override
  String errorPickingImage(String error) {
    return 'Chyba při výběru obrázku: $error';
  }

  @override
  String errorTakingPhoto(String error) {
    return 'Chyba při fotografování: $error';
  }

  @override
  String get documentAddedSuccessfully => 'Dokument úspěšně přidán';

  @override
  String get documentDeleted => 'Dokument smazán';

  @override
  String get photoAddedSuccessfully => 'Fotografie úspěšně přidána';

  @override
  String get photoDeleted => 'Fotografie smazána';

  @override
  String get tapToOpen => 'Klepnutím otevřete';

  @override
  String get fileNotFound => 'Soubor nenalezen';

  @override
  String get confirm => 'Potvrdit';

  @override
  String get update => 'Aktualizovat';

  @override
  String get remove => 'Odebrat';

  @override
  String get create => 'Vytvořit';

  @override
  String get reset => 'Obnovit';

  @override
  String get open => 'Otevřít';

  @override
  String get view => 'Zobrazit';

  @override
  String get manage => 'Spravovat';

  @override
  String get loadToMap => 'Načíst na mapu';

  @override
  String get editName => 'Upravit název';

  @override
  String get duplicate => 'Duplikovat';

  @override
  String get setAsCurrent => 'Nastavit jako aktuální';

  @override
  String get retry => 'Zkusit znovu';

  @override
  String get stopDownload => 'Zastavit stahování';

  @override
  String get manageLicenses => 'Spravovat licence';

  @override
  String get setQnh => 'Nastavit QNH';

  @override
  String get close => 'Zavřít';

  @override
  String get zoomIn => 'Přiblížit';

  @override
  String get zoomOut => 'Oddálit';

  @override
  String get maximumZoomReached => 'Maximální přiblížení dosaženo';

  @override
  String get minimumZoomReached => 'Minimální přiblížení dosaženo';

  @override
  String get refreshAllData => 'Obnovit všechna data';

  @override
  String get clearAllCaches => 'Vymazat všechny mezipaměti';

  @override
  String get clearMapCache => 'Vymazat mezipaměť mapy';

  @override
  String get refreshWeatherData => 'Obnovit meteorologická data';

  @override
  String get startTracking => 'Spustit';

  @override
  String get stopTracking => 'Zastavit';

  @override
  String errorSavingManufacturer(String error) {
    return 'Chyba při ukládání výrobce: $error';
  }

  @override
  String errorSavingModel(String error) {
    return 'Chyba při ukládání modelu: $error';
  }

  @override
  String errorSavingAircraft(String error) {
    return 'Chyba při ukládání letadla: $error';
  }

  @override
  String couldNotLaunchUrl(String url) {
    return 'Nelze otevřít $url';
  }

  @override
  String get invalidUrlFormat => 'Neplatný formát URL';

  @override
  String get alt => 'VÝŠ';

  @override
  String get speed => 'RYCHL';

  @override
  String get time => 'ČAS';

  @override
  String get dist => 'VZDA';

  @override
  String get verticalSpeed => 'V/S';

  @override
  String get gForce => 'G';

  @override
  String get next => 'DALŠÍ';

  @override
  String get eta => 'ETA';

  @override
  String get press => 'TLAK';

  @override
  String get qnh => 'QNH';

  @override
  String get fuel => 'PALIVO';

  @override
  String get current => 'Aktuální';

  @override
  String get recordingStarted => 'Nahrávání spuštěno';

  @override
  String get recordingStopped => 'Nahrávání zastaveno';

  @override
  String get firstMovement => 'První pohyb';

  @override
  String get lastMovement => 'Poslední pohyb';

  @override
  String get totalRecording => 'Celkové nahrávání';

  @override
  String get totalMoving => 'Celkový pohyb';

  @override
  String get departure => 'Odlet';

  @override
  String get arrival => 'Přílet';

  @override
  String get stopFlightTracking => 'Zastavit sledování letu?';

  @override
  String get areYouSureStopTracking =>
      'Jste si jisti, že chcete zastavit sledování letu?';

  @override
  String get initializingFlightSystems => 'Inicializace letových systémů...';

  @override
  String get yourDigitalCopilot => 'Váš digitální kopilot pro VFR lety';

  @override
  String get loadData => 'Načíst data';

  @override
  String get loadingAirspaces => 'Načítání vzdušných prostorů';

  @override
  String get someDataStillLoading => 'Některá data se možná stále načítají...';

  @override
  String get noHeatmapDataYet => 'Zatím žádná data tepelné mapy';

  @override
  String get pleaseOpenFromMap =>
      'Otevřete tuto obrazovku z mapy pro stažení aktuální oblasti';

  @override
  String get totalHours => 'Celkové hodiny';

  @override
  String get singleEngine => 'Jednomotor';

  @override
  String get multiEngine => 'Vícemotor';

  @override
  String get asPic => 'Jako PIC';

  @override
  String get asSic => 'Jako SIC';

  @override
  String get solo => 'Solo';

  @override
  String get vfr => 'VFR';

  @override
  String get ifr => 'IFR';

  @override
  String get day => 'Den';

  @override
  String get night => 'Noc';

  @override
  String get simulatorVfr => 'Simulátor VFR';

  @override
  String get simulatorIfr => 'Simulátor IFR';

  @override
  String get total => 'Celkem';

  @override
  String get hours => 'Hodiny';

  @override
  String get takeoffsLandings => 'Vzlety a přistání';

  @override
  String get dayNight => 'Den/Noc';

  @override
  String get vfrIfr => 'VFR/IFR';

  @override
  String get dayTakeoffs => 'Denní vzlety';

  @override
  String get nightTakeoffs => 'Noční vzlety';

  @override
  String get dayLandings => 'Denní přistání';

  @override
  String get nightLandings => 'Noční přistání';

  @override
  String get engineType => 'Typ motoru';

  @override
  String get flightTraining => 'Letový výcvik';

  @override
  String get groundTraining => 'Pozemí výcvik';

  @override
  String get simulator => 'Simulátor';

  @override
  String get flightNotes => 'Poznámky k letu';

  @override
  String get viewOriginalFlightLog => 'Zobrazit originální letový záznam';

  @override
  String flightId(String id) {
    return 'ID letu: $id';
  }

  @override
  String get deleteEntry => 'Smazat záznam';

  @override
  String get deletePilot => 'Smazat pilota';

  @override
  String get addNewPilot => 'Přidat nového pilota';

  @override
  String get addEndorsement => 'Přidat oprávnění';

  @override
  String get editEndorsement => 'Upravit oprávnění';

  @override
  String get deleteEndorsement => 'Smazat oprávnění';

  @override
  String get pilotName => 'Jméno';

  @override
  String get email => 'E-mail';

  @override
  String get phone => 'Telefon';

  @override
  String get certificateNumber => 'Číslo certifikátu';

  @override
  String get aircraftType => 'Typ letadla';

  @override
  String get aircraftId => 'ID letadla';

  @override
  String get selectCategory => 'Vybrat kategorii';

  @override
  String get flightReview => 'Letová kontrola';

  @override
  String get ipc => 'IPC';

  @override
  String get checkRide => 'Zkušební let';

  @override
  String get faa6158 => 'FAA 61.58';

  @override
  String get nvgProficiency => 'Způsobilost NVG';

  @override
  String get simulatedConditions => 'Simulované podmínky';

  @override
  String get endorsementTitle => 'Název';

  @override
  String get additionalDetails => 'Dodatečné detaily';

  @override
  String get info => 'Info';

  @override
  String get runways => 'Drahy';

  @override
  String get frequencies => 'Frekvence';

  @override
  String get notams => 'NOTAMy';

  @override
  String get visitWebsite => 'Navštívit webové stránky';

  @override
  String callAirport(String number) {
    return 'Volat $number';
  }

  @override
  String get navigateToAirport => 'Navigovat na letiště';

  @override
  String get icao => 'ICAO';

  @override
  String get iata => 'IATA';

  @override
  String get name => 'Název';

  @override
  String get city => 'Město';

  @override
  String get lighted => 'Osvětlené';

  @override
  String get closed => 'Zavřeno';

  @override
  String get type => 'Typ';

  @override
  String get frequency => 'Frekvence';

  @override
  String get dmeFrequency => 'DME frekvence';

  @override
  String get dmeChannel => 'DME kanál';

  @override
  String get elevation => 'Nadmořská výška';

  @override
  String get country => 'Země';

  @override
  String get usage => 'Použití';

  @override
  String get power => 'Výkon';

  @override
  String get associatedAirport => 'Přidružené letiště';

  @override
  String get coordinates => 'Souřadnice';

  @override
  String get date => 'Datum';

  @override
  String get cruiseSpeedKts => 'Cestovní rychlost (kts)';

  @override
  String get fuelConsumptionGph => 'Spotřeba paliva (GPH)';

  @override
  String get maxAltitudeFt => 'Max. výška (ft)';

  @override
  String get fuelCapacityGal => 'Kapacita paliva (gal)';

  @override
  String get maxClimbRateFpm => 'Max. stoupavost (fpm)';

  @override
  String get maxDescentRateFpm => 'Max. klesavost (fpm)';

  @override
  String get maxTakeoffWeightLbs => 'Max. vzletová hmotnost (lbs)';

  @override
  String get maxLandingWeightLbs => 'Max. přistávací hmotnost (lbs)';

  @override
  String get takeoffGroundRollFt => 'Vzletový dobet (ft)';

  @override
  String get takeoffOver50ftFt => 'Vzlet přes 50ft (ft)';

  @override
  String get landingGroundRollFt => 'Přistávací dobet (ft)';

  @override
  String get landingOver50ftFt => 'Přistání přes 50ft (ft)';

  @override
  String get vs1CleanKts => 'Vs1 (Čistá) (kts)';

  @override
  String get vs0LandingKts => 'Vs0 (Přistání) (kts)';

  @override
  String get vxBestAngleKts => 'Vx (Nejlepší úhel) (kts)';

  @override
  String get vyBestRateKts => 'Vy (Nejlepší stoupavost) (kts)';

  @override
  String get vaManeuveringKts => 'Va (Manévrování) (kts)';

  @override
  String get vnoMaxStructuralKts => 'Vno (Max. konstrukční) (kts)';

  @override
  String get vneNeverExceedKts => 'Vne (Nikdy nepřekročit) (kts)';

  @override
  String get serviceCeilingFt => 'Provozní dostup (ft)';

  @override
  String get bestGlideSpeedKts => 'Nejlepší rychlost klouzavého letu (kts)';

  @override
  String get bestGlideRatio => 'Nejlepší klouzavost';

  @override
  String get emptyWeightLbs => 'Prázdná hmotnost (lbs)';

  @override
  String get emptyWeightCg => 'Těžiště prázdné hmotnosti (palce od datumu)';

  @override
  String get climbParameters => 'Parametry stoupání';

  @override
  String get flightParameters => 'Parametry letu';

  @override
  String get windInformation => 'Informace o větru';

  @override
  String get inputMethod => 'Metoda vstupu';

  @override
  String get category => 'Kategorie';

  @override
  String get convert => 'Převést';

  @override
  String get results => 'Výsledky';

  @override
  String get quickReference => 'Rychlá referece';

  @override
  String get weightArmInputs => 'Vstupy váhy a ramene';

  @override
  String get descentParameters => 'Parametry klesání';

  @override
  String get egCessnaAircraft => 'např. Cessna Aircraft Company';

  @override
  String get egCessnaWebsite => 'např. https://www.cessna.com';

  @override
  String get egModelC172 => 'např. C172, PA-28';

  @override
  String get egMyCessna172 => 'např. Má Cessna 172';

  @override
  String get egN123AB => 'např. N123AB';

  @override
  String get egPplCplIr => 'např. PPL, CPL, IR, Lékařské vysvyemčení Třídy 1';

  @override
  String get egPrivatePilot => 'např. Licence soukromého pilota - SEP(země)';

  @override
  String get egUkFclPpl => 'např. UK.FCL.PPL.12345';

  @override
  String get johnDoe => 'Jan Novák';

  @override
  String get pilotEmail => 'pilot@priklad.cz';

  @override
  String get phoneNumber => '+420 123 456 789';

  @override
  String get pilotIdNumber => '123456789';

  @override
  String get icaoCode => 'ICAO';

  @override
  String get icaoCodeOrName => 'ICAO kód nebo název';

  @override
  String get egCessna172 => 'např. Cessna 172';

  @override
  String get egN12345 => 'např. N12345';

  @override
  String get trainingActivities => 'Provedené výcviké činnosti';

  @override
  String get groundTrainingReceived => 'Obdržený pozemí výcvik';

  @override
  String get simulatorTrainingDetails => 'Detaily výcviku na simulátoru';

  @override
  String get additionalFlightNotes => 'Dodatečné poznámky k letu';

  @override
  String get enterPilotName => 'Zadejte jméno pilota';

  @override
  String get egComplexAircraft => 'např. Komplexní letadlo';

  @override
  String target(String value) {
    return 'Cíl: $value°';
  }

  @override
  String get northShort => 'S';

  @override
  String get eastShort => 'V';

  @override
  String get southShort => 'J';

  @override
  String get westShort => 'Z';

  @override
  String get kts => 'kts';

  @override
  String get ft => 'ft';

  @override
  String get lbs => 'lbs';

  @override
  String get gal => 'gal';

  @override
  String get gph => 'gph';

  @override
  String get fpm => 'fpm';

  @override
  String get captainVfrWebsite => 'www.captainvfr.com';

  @override
  String get required => 'Povinné';

  @override
  String get invalidSpeed => 'Neplatná rychlost';

  @override
  String get invalidConsumption => 'Neplatná spotřeba';

  @override
  String get invalidAltitude => 'Neplatná výška';

  @override
  String get invalidCapacity => 'Neplatná kapacita';

  @override
  String get invalidRate => 'Neplatná rychlost';

  @override
  String get invalidWeight => 'Neplatná hmotnost';

  @override
  String aircraftAddedSuccessfully(String name) {
    return 'Letadlo \"$name\" bylo úspěšně přidáno';
  }

  @override
  String aircraftUpdatedSuccessfully(String name) {
    return 'Letadlo \"$name\" bylo úspěšně aktualizováno';
  }

  @override
  String manufacturerSavedSuccessfully(String name) {
    return 'Výrobce \"$name\" byl úspěšně uložen';
  }

  @override
  String get notes => 'Poznámky';

  @override
  String get enterWaypointNotes => 'Zadejte poznámky k waypoint';

  @override
  String areYouSureDeleteWaypointWithName(String name) {
    return 'Jste si jisti, že chcete smazat waypoint \"$name\"?';
  }

  @override
  String get airport => 'Letiště';

  @override
  String get navaid => 'Navigační pomůcka';

  @override
  String get fix => 'Bod';

  @override
  String get userWaypoint => 'Uživatelský waypoint';

  @override
  String get altitudeMsl => 'Výška (MSL)';

  @override
  String get enterAltitudeInMeters => 'Zadejte výšku v metrech';

  @override
  String noResultsFoundForQuery(String query) {
    return 'Nebyl nalezen žádný výsledek pro \"$query\"';
  }

  @override
  String airportsCountLabel(int count) {
    return 'Letiště ($count)';
  }

  @override
  String navigationAidsCountLabel(int count) {
    return 'Navigační pomůcky ($count)';
  }

  @override
  String get flightPlanningMode => 'Plánování letu';

  @override
  String get noFlightPlan => 'Žádný plán letu';

  @override
  String waypointsAndDistance(int count, String distance, String unit) {
    return '$count waypointů • $distance $unit';
  }

  @override
  String get editMode => 'Upravit';

  @override
  String get clickOnMapToAddWaypoints =>
      'Klikněte na mapu pro přidání waypointů • Klikněte na zelené + ikony na trase letu pro vložení waypointů';

  @override
  String get cruiseSpeedLabel => 'Cestovní rychlost:';

  @override
  String get aircraftLabel => 'Letadlo:';

  @override
  String get speedLabel => 'Rychlost:';

  @override
  String get selectAircraftHint => 'Vybrat letadlo';

  @override
  String get ktsUnit => 'kts';

  @override
  String get locationPermissionNeeded => 'Je potřeba oprávnění k poloze';

  @override
  String get enableForCompassHeading => 'Povolit pro směr kompasu';

  @override
  String get settingsButton => 'Nastavení';

  @override
  String get mapRotationDescription => 'Jak se má otáčet mapa a značka letadla';

  @override
  String get noRotation => 'Bez otáčení';

  @override
  String get mapRotates => 'Mapa se otáčí';

  @override
  String get aircraftRotates => 'Letadlo se otáčí';

  @override
  String get noRotationDescription =>
      'Mapa pevně na sever, značka letadla pevná';

  @override
  String get mapRotatesDescription =>
      'Mapa se otáčí s kurzem, letadlo směřuje na sever';

  @override
  String get aircraftRotatesDescription =>
      'Mapa pevně na sever, letadlo se otáčí s kurzem';

  @override
  String get flightTracking => 'Sledování letu';

  @override
  String get highPrecisionDescription =>
      'Použít vysoce přesný GPS (spotřebovává více baterie)';

  @override
  String get autoCreateLogbookDescription =>
      'Automaticky vytvořit záznam do letové knihy po letu';

  @override
  String get unitSettings => 'Nastavení jednotek';

  @override
  String get quickPresets => 'Rychlé přednastavení';

  @override
  String get applyCommonUnitCombinations => 'Použít běžné kombinace jednotek';

  @override
  String get altitude => 'Výška';

  @override
  String get airspeed => 'Rychlost letu';

  @override
  String get feet => 'Stopy';

  @override
  String get meters => 'Metry';

  @override
  String get nauticalMiles => 'Námořní míle';

  @override
  String get kilometers => 'Kilometry';

  @override
  String get statuteMiles => 'Pozemní míle';

  @override
  String get knots => 'Uzly';

  @override
  String get milesPerHour => 'Míle za hodinu';

  @override
  String get kilometersPerHour => 'Kilometry za hodinu';

  @override
  String get celsius => 'Celsius';

  @override
  String get fahrenheit => 'Fahrenheit';

  @override
  String get pounds => 'Libry';

  @override
  String get kilograms => 'Kilogramy';

  @override
  String get weight => 'Hmotnost';

  @override
  String get pressure => 'Tlak';

  @override
  String get usGallons => 'US galony';

  @override
  String get liters => 'Litry';

  @override
  String get inchesOfMercury => 'Palce rtuti';

  @override
  String get hectopascals => 'Hektopascaly';

  @override
  String get confirmResetSettings =>
      'Jste si jisti, že chcete obnovit všechna nastavení na výchozí hodnoty?';

  @override
  String get aviationDataCaches => 'Mezipaměti leteckých dat';

  @override
  String get offlineMapTiles => 'Offline mapové dlaždice';

  @override
  String get mapTiles => 'Mapové dlaždice';

  @override
  String get fieldElevationAltimeter => 'Výška letiště + výškoměr';

  @override
  String get pressureAltitudeInput => 'Tlakové výška';

  @override
  String get inputs => 'Vstupy';

  @override
  String get calculate => 'Vypočítat';

  @override
  String get headingToFly => 'Kurz k letu';

  @override
  String get groundSpeed => 'Rychlost nad zemí';

  @override
  String get windType => 'Typ větru';

  @override
  String get flightFuel => 'Palivo letu';

  @override
  String get reserveFuel => 'Rezervní palivo';

  @override
  String get logBook => 'Letový deník';

  @override
  String get summary => 'Shrnutí';

  @override
  String get logs => 'Záznamy';

  @override
  String get pilots => 'Piloti';

  @override
  String get manualEntry => 'Ruční zadání';

  @override
  String get soloFlight => 'Samostatný let';

  @override
  String get linkedFlightLog => 'Propojený letový záznam';

  @override
  String get windComponents => 'Složky větru';

  @override
  String get headwind => 'Protivítr';

  @override
  String get tailwind => 'Vítr ze zadu';

  @override
  String get strongCrosswindWarning =>
      'Velmi silný boční vítr! Zkontrolujte omezení letadla.';

  @override
  String get significantCrosswindWarning =>
      'Výrazný boční vítr. Použijte správnou techniku.';

  @override
  String get highDensityAltitudeWarning =>
      'Vysoká hustotní výška! Výkon letadla bude výrazně snížen.';

  @override
  String get magneticHeadingHint => 'Magnetický kurz dráhy';

  @override
  String get windDirectionFromHint => 'Směr, odkud vítr fouká';

  @override
  String get openSettings => 'Otevřít nastavení';

  @override
  String get continueTracking => 'Pokračovat v sledování';

  @override
  String get areYouSureStopRecording =>
      'Chcete zastavit nahrávání vašeho letu?';

  @override
  String get stop => 'Zastavit';

  @override
  String get noDocumentsYet => 'Zatím žádné dokumenty';

  @override
  String get addAfmPohDocuments =>
      'Přidat obrázky AFM, POH nebo jiných dokumentů letadla';

  @override
  String areYouSureDeleteDocument(String fileName) {
    return 'Jste si jisti, že chcete smazat \"$fileName\"?';
  }

  @override
  String get youCanAddDocumentImages =>
      'Můžete přidat obrázky dokumentů vašeho letadla (AFM, POH, atd.).\n\nPoznámka: Soubory PDF a DOC nejsou v současnosti podporovány.';

  @override
  String get noAircraftAvailable =>
      'Žádná letadla nejsou k dispozici. Nejprve prosím přidejte letadlo.';

  @override
  String enterQnhValue(String unit) {
    return 'Zadejte hodnotu QNH v $unit';
  }

  @override
  String qnhUnitLabel(String unit) {
    return 'QNH ($unit)';
  }

  @override
  String get set => 'Nastavit';

  @override
  String get noPilotsAddedYet => 'Zatím nejsou přidáni žádní piloti';

  @override
  String get addFirstPilot => 'Přidejte se jako první pilot';

  @override
  String get editLogBookEntry => 'Upravit záznam letové knihy';

  @override
  String get newLogBookEntry => 'Nový záznam v deníku';

  @override
  String get accelerometerNotAvailable => 'Akcelerometr nedostupný';

  @override
  String vibrationMeasurementNotSupported(String platform) {
    return 'Měření vibrací není podporováno na $platform';
  }

  @override
  String get vibrationMeasurementNotSupportedWeb =>
      'Měření vibrací není podporováno ve webových prohlížečích';

  @override
  String get barometerNotAvailable => 'Barometr nedostupný';

  @override
  String altitudeSensorsNotAvailable(String platform) {
    return 'Výškové senzory nejsou dostupné na $platform';
  }

  @override
  String get altitudePressureSensorsNotAvailableWeb =>
      'Výškové a tlakové senzory nejsou dostupné ve webových prohlížečích';

  @override
  String get offlineMapsNotAvailable => 'Offline mapy nedostupné';

  @override
  String get offlineMapsNotSupportedWeb =>
      'Ukládání offline map není podporováno ve webových prohlížečích';

  @override
  String get locationServicesDisabled => 'Služby polohy zakázány';

  @override
  String get enableLocationServices =>
      'Povolte služby polohy pro navigaci a sledování letu';

  @override
  String get locationPermissionRequired => 'Vyžadováno povolení polohy';

  @override
  String get locationPermissionDeniedPermanently =>
      'Povolení polohy bylo zamítnuto. Povolte v nastavení zařízení.';

  @override
  String get locationPermissionNeededForNavigation =>
      'Povolení polohy je potřeba pro navigační funkce';

  @override
  String get locationServiceError => 'Chyba služby polohy';

  @override
  String get unableToAccessLocationServices =>
      'Nelze přistoupit ke službám polohy';

  @override
  String get vibrationMeasurementFeaturesDisabled =>
      'Funkce měření vibrací budou zakázány';

  @override
  String get barometerPermissionRequired => 'Vyžadováno povolení barometru';

  @override
  String get sensorPermissionNeededForAltitude =>
      'Povolení senzoru je potřeba pro měření výšky';

  @override
  String get pressureAltitudeFeaturesLimited =>
      'Funkce tlakové výšky budou omezeny';

  @override
  String get canAddLicensesEndorsementsLater =>
      'Licence a potvrzení můžete přidat později na kartě Piloti';

  @override
  String get state => 'Stát';

  @override
  String get height => 'Výška';

  @override
  String get totalHeight => 'Celková výška';

  @override
  String get marking => 'Označení';

  @override
  String get reliability => 'Spolehlivost';

  @override
  String get occurrence => 'Výskyt';

  @override
  String get conditions => 'Podmínky';

  @override
  String get timing => 'Načasování';

  @override
  String get start => 'Start';

  @override
  String get end => 'Konec';

  @override
  String get startMoving => 'Začátek pohybu';

  @override
  String get endMoving => 'Konec pohybu';

  @override
  String get dayTO => 'Denní vzlet';

  @override
  String get nightTO => 'Noční vzlet';

  @override
  String get dayLdg => 'Denní přistání';

  @override
  String get nightLdg => 'Noční přistání';

  @override
  String get optional => 'Volitelné';

  @override
  String get currentPilot => 'Současný pilot';

  @override
  String get takeoffs => 'Vzlety';

  @override
  String get landings => 'Přistání';

  @override
  String get title => 'Název';

  @override
  String get complexAircraftExample => 'např. složité letadlo';

  @override
  String get pleaseEnterTitle => 'Zadejte prosím název';

  @override
  String get pleaseEnterDescription => 'Zadejte prosím popis';

  @override
  String get pleaseEnterPilotName => 'Zadejte prosím jméno pilota';

  @override
  String get tags => 'Značky';

  @override
  String get yes => 'Ano';

  @override
  String get no => 'Ne';

  @override
  String get toNextWaypoint => 'K DALŠÍMU BODU';

  @override
  String get licenseNumber => 'Č. licence:';

  @override
  String get expires => 'Vyprší:';

  @override
  String get noLicensesAddedYet => 'Zatím nejsou přidány žádné licence';

  @override
  String get dismiss => 'Zavřít';

  @override
  String get loadingRunwayData => 'Načítání dat drah...';

  @override
  String get loadingWindData => 'Načítání údajů o větru...';

  @override
  String get loadingFrequencyData => 'Načítání frekvencí...';

  @override
  String get pleaseSelectAircraft => 'Prosím vyberte letadlo';

  @override
  String get aircraftLacksPerformanceData =>
      'Vybrané letadlo nemá výkonnostní data';

  @override
  String get calculateClimbPerformance => 'Vypočítat výkonnost stoupání';

  @override
  String get calculateDescentPerformance => 'Vypočítat výkonnost klesání';

  @override
  String get calculateCruisePerformance => 'Vypočítat cestovní výkonnost';

  @override
  String get loadingWeatherData => 'Načítání meteorologických dat...';

  @override
  String get refreshWeather => 'Obnovit počasí';

  @override
  String noWeatherDataAvailable(String icao) {
    return 'Pro $icao nejsou dostupná meteorologická data';
  }

  @override
  String get gettingLocation => 'Získávání polohy...';

  @override
  String get acquiringGpsPosition => 'Získávání GPS pozice';

  @override
  String get appTagline => 'Váš digitální druhý pilot pro VFR lety';

  @override
  String get initializing => 'Inicializace...';

  @override
  String get noInternetConnection =>
      'Žádné internetové připojení. Některé funkce mohou být omezené.';

  @override
  String segmentNumber(int number) {
    return 'Segment $number';
  }

  @override
  String waypointsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bodů',
      few: '$count body',
      one: '1 bod',
      zero: 'Žádné body',
    );
    return '$_temp0';
  }

  @override
  String get removeLastWaypoint => 'Odstranit poslední bod';

  @override
  String get noWaypointsAdded => 'Zatím nebyly přidány žádné body';

  @override
  String defaultWaypointName(int number) {
    return 'WP$number';
  }

  @override
  String get noRunwayDataAvailable =>
      'Pro toto letiště nejsou dostupná data drah';

  @override
  String runwaysCount(int count) {
    return 'Dráhy ($count)';
  }

  @override
  String get best => 'NEJLEPŠÍ';

  @override
  String get width => 'Šířka';

  @override
  String get surface => 'Povrch';

  @override
  String get notAvailable => 'N/A';

  @override
  String get north => 'S';

  @override
  String get east => 'V';

  @override
  String get south => 'J';

  @override
  String get west => 'Z';

  @override
  String targetHeading(String degrees) {
    return 'Cíl: $degrees°';
  }

  @override
  String get nameRequired => 'Název *';

  @override
  String get length => 'Délka';

  @override
  String get heading => 'Kurz';

  @override
  String get gpsSignalLost => 'Ztráta GPS signálu';

  @override
  String get trackingGpsPosition => 'Sledování GPS pozice';

  @override
  String get calibratingCompass => 'Kalibrace kompasu...';

  @override
  String get moveDeviceFigureEight => 'Pohybujte zařízením ve tvaru osmičky';

  @override
  String get checkDeviceCompatibility => 'Zkontrolovat kompatibilitu zařízení';

  @override
  String speedUnit(String unit) {
    return 'Rychlost ($unit)';
  }

  @override
  String get turbulenceG => 'Turbulence (g)';

  @override
  String errorDeletingLicense(String error) {
    return 'Chyba při mazání licence: $error';
  }

  @override
  String get compassCalibrationRequested => 'Požadována kalibrace kompasu';

  @override
  String get allCachesClearedSuccessfully => 'Všechny cache úspěšně vymazány';

  @override
  String errorClearingCaches(String error) {
    return 'Chyba při mazání cache: $error';
  }

  @override
  String get pleaseOpenFromMapToDownload =>
      'Pro stažení aktuální oblasti otevřete tuto obrazovku z mapy';

  @override
  String failedToAddPicture(String error) {
    return 'Nepodařilo se přidat obrázek: $error';
  }

  @override
  String failedToAddDocument(String error) {
    return 'Nepodařilo se přidat dokument: $error';
  }

  @override
  String addedPilot(String name) {
    return 'Přidán pilot: $name';
  }

  @override
  String get largeDownloadWarning => 'Varování velkého stahování';

  @override
  String downloadingMapTiles(int count) {
    return 'Stahování $count mapových dlaždic pro letový plán...';
  }

  @override
  String get areYouSureDeleteChecklist =>
      'Opravdu chcete smazat tento kontrolní seznam?';

  @override
  String get addPilotFirst => 'Nejprve přidejte pilota';

  @override
  String get pilotExampleEmail => 'pilot@example.com';

  @override
  String get phoneExample => '+420 123 456 789';

  @override
  String get certificateNumberExample => '123456789';

  @override
  String get aircraftTypeExample => 'např. Cessna 172';

  @override
  String get registrationExample => 'např. OK-ABC';

  @override
  String get trainingActivitiesPerformed => 'Provedené výcvikové aktivity';

  @override
  String get additionalNotesAboutFlight => 'Dodatečné poznámky k letu';

  @override
  String get aircraftShortExample => 'C172';

  @override
  String get registrationShortExample => 'OK-ABC';

  @override
  String get useNegativeForTailwind =>
      'Pro zadní vítr použijte zápornou hodnotu';

  @override
  String get positiveTailwindNegativeHeadwind =>
      'Kladné = zadní vítr, Záporné = protivítr';

  @override
  String get trueCourseToDestination => 'Skutečný kurz k cíli';

  @override
  String get averageCruiseFuelConsumption =>
      'Průměrná cestovní spotřeba paliva';

  @override
  String get faaMinimumReserve => 'FAA minimum: 30 min VFR, 45 min IFR';

  @override
  String get totalUsableFuelOnBoard => 'Celkové použitelné palivo na palubě';

  @override
  String get runwayConditionHelper => '0 = Suchá, 100 = Stojící voda/břečka';

  @override
  String get downloadCurrentArea => 'Stáhnout aktuální oblast';

  @override
  String get addLicense => 'Přidat licenci';

  @override
  String refreshData(String title) {
    return 'Obnovit $title';
  }

  @override
  String get aircraftSelection => 'Výběr letadla';

  @override
  String get weightAndArmInputs => 'Hmotnost a vyvažení';

  @override
  String get editFlightPlanName => 'Upravit název letového plánu';

  @override
  String get downloadMapTiles => 'Stáhnout mapové dlaždice';

  @override
  String get rightCrosswind => 'Pravý boční vítr';

  @override
  String get leftCrosswind => 'Levý boční vítr';

  @override
  String get lightVariable => 'Slabý proměnný';

  @override
  String get issued => 'Vydáno:';

  @override
  String get pleaseSelectEngineType => 'Prosím vyberte typ motoru';

  @override
  String get pilotExperience => 'Zkušenosti pilota';

  @override
  String get pleaseSelectPilotInCommand => 'Prosím vyberte velícího pilota';

  @override
  String get conditionsOfFlight => 'Podmínky letu';

  @override
  String get departuresAndLandings => 'Vzlety a přistání';

  @override
  String get picturesAndDocuments => 'Obrázky a dokumenty';

  @override
  String picturesCount(int count) {
    return 'Obrázky ($count)';
  }

  @override
  String documentsCount(int count) {
    return 'Dokumenty ($count)';
  }

  @override
  String get editPilot => 'Upravit pilota';

  @override
  String get addPilot => 'Přidat pilota';

  @override
  String get dateOfBirth => 'Datum narození';

  @override
  String get notSet => 'Nenastaveno';

  @override
  String get contactInformation => 'Kontaktní informace';

  @override
  String get pleaseEnterValidEmail => 'Zadejte prosím platný email';

  @override
  String get certificateInformation => 'Informace o certifikátu';

  @override
  String get setAsCurrentPilot => 'Nastavit jako současného pilota';

  @override
  String get defaultPilotDescription =>
      'Tento pilot bude vybrán jako výchozí v nových záznamech';

  @override
  String get updatePilot => 'Aktualizovat pilota';

  @override
  String get certificate => 'Certifikát:';

  @override
  String age(int age) {
    return 'Věk: $age let';
  }

  @override
  String get years => 'let';

  @override
  String licensesCount(int count) {
    return '$count Licencí';
  }

  @override
  String endorsementsCount(int count) {
    return '$count Oprávnění';
  }

  @override
  String confirmDeletePilot(String name) {
    return 'Opravdu chcete smazat $name?';
  }

  @override
  String get noLicensesAdded => 'Žádné licence nebyly přidány';

  @override
  String get endorsements => 'Oprávnění';

  @override
  String get noEndorsementsAdded => 'Žádná oprávnění nebyla přidána';

  @override
  String get confirmDeleteLicense => 'Opravdu chcete smazat tuto licenci?';

  @override
  String get confirmDeleteEndorsement =>
      'Opravdu chcete smazat toto oprávnění?';

  @override
  String get downloadMapTilesDescription =>
      'Stáhnout mapové dlaždice pro offline použití';

  @override
  String get flightPlanDownloadMapTiles =>
      'Stažení mapových dlaždic letového plánu';

  @override
  String get automaticallyDownloadFlightPlanTiles =>
      'Automaticky stahovat mapové dlaždice pro letové plány';

  @override
  String get validateTilesOnStartup => 'Ověřit dlaždice při spuštění';

  @override
  String get checkMissingTilesOnStartup =>
      'Zkontrolovat chybějící dlaždice při spuštění aplikace';

  @override
  String get minZoom => 'Minimální úroveň přiblížení';

  @override
  String get maxZoom => 'Maximální úroveň přiblížení';

  @override
  String progressTiles(int current, int total) {
    return '$current/$total dlaždic';
  }

  @override
  String downloadedTiles(int count) {
    return 'Staženo: $count dlaždic';
  }

  @override
  String skippedTiles(int count) {
    return 'Přeskočeno: $count dlaždic';
  }

  @override
  String downloadedTilesWithSkipped(int downloaded, int skipped) {
    return 'Staženo $downloaded dlaždic, přeskočeno $skipped';
  }

  @override
  String downloadedTilesSuccessfully(int count) {
    return 'Úspěšně staženo $count dlaždic';
  }

  @override
  String get downloadCancelled => 'Stahování zrušeno';

  @override
  String downloadFailed(String error) {
    return 'Stahování selhalo: $error';
  }

  @override
  String get supplementalData => 'Doplňková data';

  @override
  String largeDownloadDescription(int count) {
    return 'Tímto se stáhne přibližně $count mapových dlaždic. Může to chvíli trvat a spotřebovat značné množství dat. Pokračovat?';
  }

  @override
  String get continueText => 'Pokračovat';

  @override
  String get mapLayers => 'Mapové vrstvy';

  @override
  String get loadingAirports => 'Načítání letišť...';

  @override
  String get loadingRunways => 'Načítání drah...';

  @override
  String get loadingNavaids => 'Načítání navigačních pomůcek...';

  @override
  String get loadingFrequencies => 'Načítání frekvencí...';

  @override
  String get dataLoadingComplete => 'Načítání dat dokončeno';

  @override
  String confirmDeleteModel(String name) {
    return 'Opravdu chcete smazat \"$name\"?';
  }

  @override
  String deletedModel(String name) {
    return 'Smazáno \"$name\"';
  }

  @override
  String confirmDeleteAircraft(String name) {
    return 'Opravdu chcete smazat \"$name\"?';
  }

  @override
  String deletedAircraft(String name) {
    return 'Smazáno \"$name\"';
  }

  @override
  String deletedManufacturer(String name) {
    return 'Smazáno \"$name\"';
  }

  @override
  String confirmDeleteManufacturer(String name) {
    return 'Opravdu chcete smazat \"$name\"? Tímto se také smažou všechny přidružené modely.';
  }

  @override
  String clearedCache(String name) {
    return '$name cache úspěšně vymazána';
  }

  @override
  String get id => 'ID';

  @override
  String get confirmDeleteEntry =>
      'Opravdu chcete smazat tento záznam z deníku?';

  @override
  String get navigation => 'Navigace';

  @override
  String autoInTime(String time) {
    return 'Auto za: $time';
  }

  @override
  String get stats => 'Statistiky';

  @override
  String get flight => 'Let';

  @override
  String get checklists => 'Kontrolní seznamy';

  @override
  String get aircrafts => 'Letadla';

  @override
  String get flightPlan => 'Letový plán';

  @override
  String get altitudeProfile => 'Výškový profil';

  @override
  String get airspaceCrossings => 'Průlety vzdušnými prostory';

  @override
  String get analyzingAirspaceProfile =>
      'Analyzování profilu vzdušného prostoru...';

  @override
  String get noAirspaceProfileAvailable =>
      'Profil vzdušného prostoru není k dispozici';

  @override
  String get analyzeFlightPath => 'Analyzovat letovou trasu';

  @override
  String get communicationFrequencies => 'Komunikační frekvence';

  @override
  String get groundStation => 'Pozemní stanice';

  @override
  String get primaryFrequency => 'Primární frekvence';

  @override
  String get secondaryFrequency => 'Sekundární frekvence';

  @override
  String get noFrequencyAvailable => 'Frekvence není k dispozici';

  @override
  String get copyFrequency => 'Frekvence zkopírována';
}
