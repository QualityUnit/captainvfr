import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:logger/logger.dart';
import 'package:archive/archive.dart';
import 'cache_service.dart';
import 'cors_proxy_service.dart';

/// Service for fetching and managing weather data for airports

class WeatherService {
  static const String _metarUrl =
      'https://aviationweather.gov/data/cache/metars.cache.csv.gz';
  static const String _tafUrl =
      'https://aviationweather.gov/data/cache/tafs.cache.csv.gz';
  static const Duration cacheDuration = Duration(
    minutes: 5,
  ); // Keep for backwards compatibility

  final _logger = Logger(
    level: Level.warning, // Only log warnings and errors in production
  );
  final _client = http.Client();
  final _cacheService = CacheService();

  Map<String, String> _metarCache = {};
  Map<String, String> _tafCache = {};
  final Map<String, DateTime> _metarTimestamps =
      {}; // Track when each METAR was fetched
  final Map<String, DateTime> _tafTimestamps =
      {}; // Track when each TAF was fetched
  DateTime? _lastFetch;
  Future<void>? _ongoingFetch;
  bool _isReloading = false; // Prevent multiple simultaneous reloads

  WeatherService();

  /// Initialize the weather service and load cached data
  Future<void> initialize() async {
    await _cacheService.initialize();
    await _loadCachedData();
  }

  /// Load cached weather data from persistent storage
  Future<void> _loadCachedData() async {
    try {
      final cachedMetars = await _cacheService.getCachedMetars();
      final cachedTafs = await _cacheService.getCachedTafs();
      final lastFetch = await _cacheService.getWeatherLastFetch();

      if (cachedMetars.isNotEmpty || cachedTafs.isNotEmpty) {
        _metarCache = cachedMetars;
        _tafCache = cachedTafs;
        _lastFetch = lastFetch;
      }
    } catch (e) {
      _logger.w('⚠️ Failed to load cached weather data: $e');
    }
  }

  /// Fetch all METARs and TAFs if cache is expired (30+ minute cache with graceful degradation)
  Future<void> _fetchAllWeatherIfNeeded() async {
    // If there's already an ongoing fetch, wait for it and return
    if (_ongoingFetch != null) {
      await _ongoingFetch;
      return;
    }

    // Load from persistent cache if in-memory cache is empty
    if (_metarCache.isEmpty && _tafCache.isEmpty) {
      await _loadCachedData();
    }

    // Use more aggressive caching - only fetch if data is very old or missing
    if (_metarCache.isNotEmpty && _tafCache.isNotEmpty && _lastFetch != null) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetch!);
      // Extended cache time to 30 minutes to reduce network requests
      if (timeSinceLastFetch < const Duration(minutes: 30)) {
        return;
      }
    }

    // Only fetch if we have no data at all or data is very stale (30+ minutes)
    _ongoingFetch = _fetchAllWeather();
    try {
      await _ongoingFetch;
    } catch (e) {
      _logger.e('❌ Failed to fetch weather data, using cached data: $e');
      // Continue with cached data even if fetch fails
    } finally {
      _ongoingFetch = null;
    }
  }

  Future<void> _fetchAllWeather() async {
    try {

      // Use CORS proxy for web platform
      final metarUrl = CorsProxyService.wrapUrl(_metarUrl);
      final tafUrl = CorsProxyService.wrapUrl(_tafUrl);
      
      final metarResp = await _client.get(Uri.parse(metarUrl));
      final tafResp = await _client.get(Uri.parse(tafUrl));

      if (metarResp.statusCode == 200) {
        _metarCache = _parseGzCsv(metarResp.bodyBytes, isMetar: true);
      }

      if (tafResp.statusCode == 200) {
        _tafCache = _parseGzCsv(tafResp.bodyBytes, isMetar: false);
      }

      _lastFetch = DateTime.now();

      // Save to persistent cache
      await _saveToPersistentCache();
    } catch (e, st) {
      _logger.e('❌ Error fetching global weather', error: e, stackTrace: st);
    }
  }

  /// Save weather data to persistent cache
  Future<void> _saveToPersistentCache() async {
    try {
      // Combine METAR and TAF data into a single map
      final weatherData = <String, dynamic>{};
      _metarCache.forEach((icao, metar) {
        weatherData[icao] = {'metar': metar};
      });
      _tafCache.forEach((icao, taf) {
        if (weatherData.containsKey(icao)) {
          weatherData[icao]['taf'] = taf;
        } else {
          weatherData[icao] = {'taf': taf};
        }
      });
      await _cacheService.cacheWeatherBulk(weatherData);
    } catch (e) {
      _logger.w('⚠️ Failed to save weather data to cache: $e');
    }
  }

  Map<String, String> _parseGzCsv(List<int> gzBytes, {required bool isMetar}) {
    try {
      final archive = GZipDecoder().decodeBytes(gzBytes);
      final csv = utf8.decode(archive);
      final lines = csv.split('\n');
      final map = <String, String>{};

      // Skip header lines and find where actual data starts
      int dataStartIndex = 0;
      for (int i = 0; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        // Look for lines that start with 4-letter ICAO codes
        if (RegExp(r'^[A-Z]{4}[\s,]').hasMatch(line)) {
          dataStartIndex = i;
          break;
        }
      }

      // Parse actual weather data lines
      for (int i = dataStartIndex; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        String? icao;
        String? weatherText;

        // Try different parsing approaches
        if (line.contains(',')) {
          // CSV format parsing - based on logs, raw_text is the first column
          final parts = line.split(',');
          if (parts.isNotEmpty) {
            // The first column should be the raw_text (weather data)
            final rawText = parts[0].trim().replaceAll('"', '');

            // Extract ICAO from the raw text
            final icaoMatch = RegExp(r'^([A-Z]{4})[\s\d]').firstMatch(rawText);
            if (icaoMatch != null) {
              icao = icaoMatch.group(1);
              weatherText = rawText;
            }
          }
        } else {
          // Single line format - extract ICAO from the beginning
          final match = RegExp(r'^([A-Z]{4})\s+(.+)').firstMatch(line);
          if (match != null) {
            icao = match.group(1);
            weatherText = line; // Use the whole line as weather text
          }
        }

        if (icao != null && weatherText != null && weatherText.isNotEmpty) {
          map[icao.toUpperCase()] = weatherText;
        }
      }

      return map;
    } catch (e) {
      _logger.e('❌ Error parsing ${isMetar ? 'METAR' : 'TAF'} CSV', error: e);
      return {};
    }
  }

  /// Get METAR for ICAO code - returns cached data immediately and triggers reload if needed
  Future<String?> getMetar(String icaoCode) async {
    final icaoUpper = icaoCode.toUpperCase();

    // First, try to get cached data
    String? cachedMetar = _metarCache[icaoUpper];

    // If no cached data, try loading from persistent storage
    if (cachedMetar == null && _metarCache.isEmpty) {
      await _loadCachedData();
      cachedMetar = _metarCache[icaoUpper];
    }

    // Check if we need to reload data in background
    final shouldReload = _shouldReloadWeatherData(icaoUpper, isMetar: true);

    if (shouldReload && !_isReloading) {
      // Trigger background reload but don't wait for it
      _triggerBackgroundReload();
    }

    // If primary data is not available or invalid, try SafeSky as fallback
    if (cachedMetar == null || _isWeatherDataInvalid(cachedMetar)) {
      try {
        final safeSkyMetar = await _fetchMetarFromSafeSky(icaoUpper);
        if (safeSkyMetar != null) {
          // Successfully got SafeSky data - mark it in cache to avoid repeated calls
          return safeSkyMetar;
        }
      } catch (e) {
        _logger.w('⚠️ SafeSky METAR fallback failed for $icaoUpper: $e');
      }
    }

    // Return primary cached data (even if invalid/expired) or null if nothing available
    return cachedMetar;
  }

  /// Get TAF for ICAO code - returns cached data immediately and triggers reload if needed
  Future<String?> getTaf(String icaoCode) async {
    final icaoUpper = icaoCode.toUpperCase();

    // First, try to get cached data
    String? cachedTaf = _tafCache[icaoUpper];

    // If no cached data, try loading from persistent storage
    if (cachedTaf == null && _tafCache.isEmpty) {
      await _loadCachedData();
      cachedTaf = _tafCache[icaoUpper];
    }

    // Check if we need to reload data in background
    final shouldReload = _shouldReloadWeatherData(icaoUpper, isMetar: false);

    if (shouldReload && !_isReloading) {
      // Trigger background reload but don't wait for it
      _triggerBackgroundReload();
    }

    // If primary data is not available or invalid, try SafeSky as fallback
    if (cachedTaf == null || _isWeatherDataInvalid(cachedTaf)) {
      try {
        final safeSkyTaf = await _fetchTafFromSafeSky(icaoUpper);
        if (safeSkyTaf != null) {
          // Successfully got SafeSky data - mark it in cache to avoid repeated calls
          return safeSkyTaf;
        }
      } catch (e) {
        _logger.w('⚠️ SafeSky TAF fallback failed for $icaoUpper: $e');
      }
    }

    // Return primary cached data (even if invalid/expired) or null if nothing available
    return cachedTaf;
  }

  /// Check if weather data should be reloaded
  bool _shouldReloadWeatherData(String icaoCode, {required bool isMetar}) {
    final cache = isMetar ? _metarCache : _tafCache;
    final timestamps = isMetar ? _metarTimestamps : _tafTimestamps;

    // If no data at all, need to reload
    if (cache[icaoCode] == null) {
      return true;
    }

    // If data is invalid, need to reload
    if (_isWeatherDataInvalid(cache[icaoCode]!)) {
      return true;
    }

    // If data is expired (older than 15 minutes), need to reload
    final timestamp = timestamps[icaoCode];
    if (timestamp != null) {
      final age = DateTime.now().difference(timestamp);
      if (age > const Duration(minutes: 15)) {
        return true;
      }
    } else {
      // No timestamp means data is from persistent cache, likely old
      return true;
    }

    return false;
  }

  /// Check if weather data is invalid
  bool _isWeatherDataInvalid(String weatherData) {
    if (weatherData.trim().isEmpty) return true;

    // Check for common invalid patterns
    if (weatherData.contains('ERROR') ||
        weatherData.contains('INVALID') ||
        weatherData.contains('NO DATA') ||
        weatherData.contains('TIMEOUT')) {
      return true;
    }

    // For METAR: Should start with 4-letter ICAO code followed by date/time
    if (!RegExp(r'^[A-Z]{4}\s+\d{6}Z?').hasMatch(weatherData.trim())) {
      return true;
    }

    return false;
  }

  /// Trigger background reload of weather data
  void _triggerBackgroundReload() {
    if (_isReloading) {
      return;
    }

    _isReloading = true;

    // Start background reload
    _backgroundReload()
        .then((_) {
          _isReloading = false;
        })
        .catchError((error) {
          _isReloading = false;
          _logger.e('❌ Background weather data reload failed: $error');
        });
  }

  /// Background reload of weather data
  Future<void> _backgroundReload() async {
    try {
      await _fetchAllWeather();

      // Update timestamps for all fetched data
      final fetchTime = DateTime.now();
      for (final icao in _metarCache.keys) {
        _metarTimestamps[icao] = fetchTime;
      }
      for (final icao in _tafCache.keys) {
        _tafTimestamps[icao] = fetchTime;
      }
    } catch (e, st) {
      _logger.e(
        '❌ Error in background weather reload',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Get cached METAR without fetching
  String? getCachedMetar(String icaoCode) {
    return _metarCache[icaoCode.toUpperCase()];
  }

  /// Get cached TAF without fetching
  String? getCachedTaf(String icaoCode) {
    return _tafCache[icaoCode.toUpperCase()];
  }

  /// Force reload (always reloads regardless of cache state)
  Future<void> forceReload() async {
    if (_ongoingFetch != null) {
      await _ongoingFetch;
    }
    _ongoingFetch = _fetchAllWeather();
    await _ongoingFetch;
    _ongoingFetch = null;
  }

  DateTime? get lastFetch => _lastFetch;

  /// Get cache statistics
  Map<String, dynamic> getCacheStatistics() {
    return {
      'metars': _metarCache.length,
      'tafs': _tafCache.length,
      'lastFetch': _lastFetch,
    };
  }

  /// Legacy method for backward compatibility
  Future<String?> fetchMetar(String icaoCode) async {
    return await getMetar(icaoCode);
  }

  /// Legacy method for backward compatibility
  Future<String?> fetchTaf(String icaoCode) async {
    return await getTaf(icaoCode);
  }

  // SafeSky API integration constants
  static const String _safeSkyBaseUrl = 'https://imuwdhmbde.execute-api.eu-central-1.amazonaws.com/prod';
  static const Duration _safeSkyTimeout = Duration(seconds: 30);
  static const Duration _safeSkyRequestCooldown = Duration(seconds: 2); // Prevent rapid requests
  final Map<String, DateTime> _safeSkyLastRequests = {}; // Track last request times for rate limiting

  /// Fetch METAR from SafeSky API as fallback
  /// Returns the METAR text if successful, null otherwise
  Future<String?> _fetchMetarFromSafeSky(String icaoCode) async {
    try {
      final icaoUpper = icaoCode.toUpperCase();
      
      // Check rate limiting - prevent requests too close together
      final lastRequest = _safeSkyLastRequests[icaoUpper];
      if (lastRequest != null) {
        final timeSinceLastRequest = DateTime.now().difference(lastRequest);
        if (timeSinceLastRequest < _safeSkyRequestCooldown) {
          _logger.d('⏳ SafeSky METAR request for $icaoUpper rate limited, waiting ${_safeSkyRequestCooldown.inSeconds}s');
          return null;
        }
      }

      _logger.d('🛩️ Fetching METAR from SafeSky for $icaoUpper');
      _safeSkyLastRequests[icaoUpper] = DateTime.now();

      final url = '$_safeSkyBaseUrl/metar/$icaoUpper';
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(_safeSkyTimeout);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        // Extract METAR text from SafeSky response
        String? metarText;
        if (jsonData is Map<String, dynamic>) {
          metarText = jsonData['raw']?.toString() ?? 
                     jsonData['raw_text']?.toString() ?? 
                     jsonData['metar']?.toString() ?? 
                     jsonData['text']?.toString();
        } else if (jsonData is String) {
          metarText = jsonData;
        }

        if (metarText != null && metarText.trim().isNotEmpty) {
          // Validate the METAR format
          if (_isValidMetarFormat(metarText)) {
            _logger.i('✅ SafeSky METAR fetched for $icaoUpper: ${metarText.length} chars');
            
            // Cache the SafeSky METAR with appropriate timestamp
            _metarCache[icaoUpper] = metarText;
            _metarTimestamps[icaoUpper] = DateTime.now();
            
            return metarText;
          } else {
            _logger.w('⚠️ Invalid METAR format from SafeSky for $icaoUpper: $metarText');
          }
        }
      } else if (response.statusCode == 404) {
        _logger.d('🔍 No METAR data available from SafeSky for $icaoUpper');
      } else if (response.statusCode == 429) {
        _logger.w('⚠️ SafeSky API rate limited for METAR $icaoUpper');
      } else {
        _logger.w('⚠️ SafeSky METAR API error for $icaoUpper: ${response.statusCode}');
      }
    } catch (e) {
      _logger.w('⚠️ SafeSky METAR fetch error for $icaoCode: $e');
    }
    
    return null;
  }

  /// Fetch TAF from SafeSky API as fallback
  Future<String?> _fetchTafFromSafeSky(String icaoCode) async {
    try {
      final icaoUpper = icaoCode.toUpperCase();
      
      // Check rate limiting - prevent requests too close together
      final lastRequest = _safeSkyLastRequests[icaoUpper];
      if (lastRequest != null) {
        final timeSinceLastRequest = DateTime.now().difference(lastRequest);
        if (timeSinceLastRequest < _safeSkyRequestCooldown) {
          _logger.d('⏳ SafeSky TAF request for $icaoUpper rate limited, waiting ${_safeSkyRequestCooldown.inSeconds}s');
          return null;
        }
      }

      _logger.d('🛩️ Fetching TAF from SafeSky for $icaoUpper');
      _safeSkyLastRequests[icaoUpper] = DateTime.now();

      final url = '$_safeSkyBaseUrl/taf/$icaoUpper';
      final response = await _client.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(_safeSkyTimeout);

      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        
        // Extract TAF text from SafeSky response
        String? tafText;
        if (jsonData is Map<String, dynamic>) {
          tafText = jsonData['raw']?.toString() ?? 
                   jsonData['raw_text']?.toString() ?? 
                   jsonData['taf']?.toString() ?? 
                   jsonData['text']?.toString();
        } else if (jsonData is String) {
          tafText = jsonData;
        }

        if (tafText != null && tafText.trim().isNotEmpty) {
          // Validate the TAF format
          if (_isValidTafFormat(tafText)) {
            _logger.i('✅ SafeSky TAF fetched for $icaoUpper: ${tafText.length} chars');
            
            // Cache the SafeSky TAF with appropriate timestamp
            _tafCache[icaoUpper] = tafText;
            _tafTimestamps[icaoUpper] = DateTime.now();
            
            return tafText;
          } else {
            _logger.w('⚠️ Invalid TAF format from SafeSky for $icaoUpper: $tafText');
          }
        }
      } else if (response.statusCode == 404) {
        _logger.d('🔍 No TAF data available from SafeSky for $icaoUpper');
      } else if (response.statusCode == 429) {
        _logger.w('⚠️ SafeSky API rate limited for TAF $icaoUpper');
      } else {
        _logger.w('⚠️ SafeSky TAF API error for $icaoUpper: ${response.statusCode}');
      }
    } catch (e) {
      _logger.w('⚠️ SafeSky TAF fetch error for $icaoCode: $e');
    }
    
    return null;
  }

  /// Validate METAR format
  bool _isValidMetarFormat(String metar) {
    if (metar.trim().isEmpty) return false;
    
    // Basic METAR validation - should start with 4-letter ICAO code and contain timestamp
    final metarPattern = RegExp(r'^[A-Z]{4}\s+\d{6}Z?\s+');
    return metarPattern.hasMatch(metar.trim());
  }

  /// Validate TAF format
  bool _isValidTafFormat(String taf) {
    if (taf.trim().isEmpty) return false;
    
    // Basic TAF validation - should start with TAF and 4-letter ICAO code
    final tafPattern = RegExp(r'^TAF\s+[A-Z]{4}\s+\d{6}Z?');
    return tafPattern.hasMatch(taf.trim());
  }

  /// Get METAR with source information
  Future<({String? data, String source})> getMetarWithSource(String icaoCode) async {
    final icaoUpper = icaoCode.toUpperCase();

    // First, try to get cached data
    String? cachedMetar = _metarCache[icaoUpper];

    // If no cached data, try loading from persistent storage
    if (cachedMetar == null && _metarCache.isEmpty) {
      await _loadCachedData();
      cachedMetar = _metarCache[icaoUpper];
    }

    // Check if we need to reload data in background
    final shouldReload = _shouldReloadWeatherData(icaoUpper, isMetar: true);

    if (shouldReload && !_isReloading) {
      // Trigger background reload but don't wait for it
      _triggerBackgroundReload();
    }

    // If primary data is available and valid, return it
    if (cachedMetar != null && !_isWeatherDataInvalid(cachedMetar)) {
      return (data: cachedMetar, source: 'primary');
    }

    // Try SafeSky as fallback
    try {
      final safeSkyMetar = await _fetchMetarFromSafeSky(icaoUpper);
      if (safeSkyMetar != null) {
        return (data: safeSkyMetar, source: 'safesky');
      }
    } catch (e) {
      _logger.w('⚠️ SafeSky METAR fallback failed for $icaoUpper: $e');
    }

    // Return primary cached data (even if invalid) if available, otherwise null
    return (data: cachedMetar, source: 'primary');
  }

  /// Get TAF with source information
  Future<({String? data, String source})> getTafWithSource(String icaoCode) async {
    final icaoUpper = icaoCode.toUpperCase();

    // First, try to get cached data
    String? cachedTaf = _tafCache[icaoUpper];

    // If no cached data, try loading from persistent storage
    if (cachedTaf == null && _tafCache.isEmpty) {
      await _loadCachedData();
      cachedTaf = _tafCache[icaoUpper];
    }

    // Check if we need to reload data in background
    final shouldReload = _shouldReloadWeatherData(icaoUpper, isMetar: false);

    if (shouldReload && !_isReloading) {
      // Trigger background reload but don't wait for it
      _triggerBackgroundReload();
    }

    // If primary data is available and valid, return it
    if (cachedTaf != null && !_isWeatherDataInvalid(cachedTaf)) {
      return (data: cachedTaf, source: 'primary');
    }

    // Try SafeSky as fallback
    try {
      final safeSkyTaf = await _fetchTafFromSafeSky(icaoUpper);
      if (safeSkyTaf != null) {
        return (data: safeSkyTaf, source: 'safesky');
      }
    } catch (e) {
      _logger.w('⚠️ SafeSky TAF fallback failed for $icaoUpper: $e');
    }

    // Return primary cached data (even if invalid) if available, otherwise null
    return (data: cachedTaf, source: 'primary');
  }

  /// Disposes of resources
  void dispose() {
    _client.close();
  }

  /// Fetch weather data ONLY from cached/bulk data - NO individual API requests
  /// This method is optimized to minimize network requests and serve from local memory
  Future<Map<String, String>> getMetarsForAirports(
    List<String> icaoCodes,
  ) async {
    if (icaoCodes.isEmpty) {
      return {};
    }

    // Load from persistent cache if in-memory cache is empty
    if (_metarCache.isEmpty) {
      await _loadCachedData();
    }

    // Trigger bulk data refresh in background if needed (but don't wait for it)
    await _fetchAllWeatherIfNeeded();

    final results = <String, String>{};

    // Get data from cache for all requested airports
    for (final icao in icaoCodes) {
      final icaoUpper = icao.toUpperCase();
      final cachedMetar = _metarCache[icaoUpper];

      if (cachedMetar != null) {
        results[icao] = cachedMetar;
      }
    }

    return results;
  }

  /// Get TAFs for specific airports - ONLY from cached/bulk data
  Future<Map<String, String>> getTafsForAirports(List<String> icaoCodes) async {
    if (icaoCodes.isEmpty) return {};
    // Load from persistent cache if in-memory cache is empty
    if (_tafCache.isEmpty) {
      await _loadCachedData();
    }

    // Trigger bulk data refresh in background if needed (but don't wait for it)
    await _fetchAllWeatherIfNeeded();

    final results = <String, String>{};

    // Get data from cache for all requested airports
    for (final icao in icaoCodes) {
      final icaoUpper = icao.toUpperCase();
      final cachedTaf = _tafCache[icaoUpper];

      if (cachedTaf != null) {
        results[icao] = cachedTaf;
      }
    }

    return results;
  }
}
