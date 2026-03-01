import 'dart:convert';
import 'dart:developer' as developer;
import '../models/notam.dart';
import 'cache_service.dart';

/// NOTAM service using alternative data sources
class NotamServiceV3 {
  static final NotamServiceV3 _instance = NotamServiceV3._internal();
  factory NotamServiceV3() => _instance;
  NotamServiceV3._internal();

  final CacheService _cacheService = CacheService();
  static const Duration _cacheExpiry = Duration(hours: 6);

  /// Prefetch NOTAMs for multiple airports in parallel
  Future<void> prefetchNotamsForAirports(List<String> icaoCodes) async {
    if (icaoCodes.isEmpty) return;

    developer.log('📋 V3: Prefetching NOTAMs for ${icaoCodes.length} airports');

    // Process in batches to avoid overwhelming the cache
    const batchSize = 10; // V3 is just mock data, so we can handle more
    for (int i = 0; i < icaoCodes.length; i += batchSize) {
      final batch = icaoCodes.skip(i).take(batchSize).toList();

      // Fetch NOTAMs in parallel for this batch
      await Future.wait(
        batch.map(
          (icao) =>
              getNotamsForAirport(icao, forceRefresh: false).catchError((e) {
                developer.log('⚠️ V3: Failed to prefetch NOTAMs for $icao: $e');
                return <Notam>[];
              }),
        ),
      );
    }

    developer.log('✅ V3: Prefetch complete for ${icaoCodes.length} airports');
  }

  /// Mock NOTAM data for demonstration
  /// In a real implementation, this would fetch from ICAO API or other sources
  Future<List<Notam>> getNotamsForAirport(
    String icaoCode, {
    bool forceRefresh = false,
  }) async {
    developer.log('📋 Fetching NOTAMs for $icaoCode using V3 service');

    // Try cache first
    if (!forceRefresh) {
      try {
        final cachedNotams = await _getCachedNotams(icaoCode);
        if (cachedNotams.isNotEmpty && _isCacheValid(cachedNotams)) {
          developer.log('✅ Using cached NOTAMs for $icaoCode');
          return cachedNotams;
        }
      } catch (e) {
        developer.log('⚠️ Cache error: $e');
      }
    }

    // Generate realistic NOTAMs for demonstration
    // In production, replace this with actual API calls
    final notams = _generateRealisticNotams(icaoCode);

    // Cache the results
    if (notams.isNotEmpty) {
      await _cacheNotams(icaoCode, notams);
    }

    return notams;
  }

  /// Generate realistic NOTAM data for demonstration
  List<Notam> _generateRealisticNotams(String icaoCode) {
    final now = DateTime.now().toUtc();
    final notams = <Notam>[];

    // Generate at least 1-3 NOTAMs for any airport to demonstrate the feature
    final random = icaoCode.hashCode % 100; // Deterministic "random" based on ICAO code
    final notamCount = 1 + (random % 3); // 1-3 NOTAMs

    // Common NOTAM scenarios that apply to most airports
    final scenarios = [
      // Taxiway closure
      {
        'category': NotamCategory.taxiway,
        'template': 'TWY {letter} BTN TWY {letter2} AND TWY {letter3} CLSD',
        'decoded': 'Taxiway {letter} between Taxiway {letter2} and Taxiway {letter3} closed',
        'schedule': 'DLY 0600-1400',
        'days': 5,
      },
      // Runway maintenance
      {
        'category': NotamCategory.runway,
        'template': 'RWY {rwy} CLSD DUE TO MAINT',
        'decoded': 'Runway {rwy} closed due to maintenance',
        'schedule': 'DLY 2200-0600',
        'days': 7,
      },
      // Navaid issue
      {
        'category': NotamCategory.navaid,
        'template': 'ILS RWY {rwy} GLIDE SLOPE U/S',
        'decoded': 'ILS Runway {rwy} glide slope unserviceable',
        'schedule': '',
        'days': null, // Permanent
      },
      // Obstacle
      {
        'category': NotamCategory.obstacle,
        'template': 'CRANE ERECTED {dist}FT {dir} OF RWY {rwy} THR, {height}FT AGL, LGTD',
        'decoded': 'Crane erected {dist} feet {dir} of Runway {rwy} threshold, {height} feet above ground level, lighted',
        'schedule': 'MON-FRI 1300-2100',
        'days': 14,
      },
      // Apron closure
      {
        'category': NotamCategory.apron,
        'template': 'APRON STAND {stands} CLSD',
        'decoded': 'Apron stands {stands} closed',
        'schedule': '',
        'days': 2,
      },
      // Lighting issue
      {
        'category': NotamCategory.services,
        'template': 'RWY {rwy} EDGE LIGHTS U/S',
        'decoded': 'Runway {rwy} edge lights unserviceable',
        'schedule': 'DLY 1800-0600',
        'days': 3,
      },
    ];

    // Generate NOTAMs based on airport code
    for (int i = 0; i < notamCount; i++) {
      final scenarioIndex = (random + i) % scenarios.length;
      final scenario = scenarios[scenarioIndex];
      
      // Generate NOTAM ID
      final notamNumber = 2000 + (random + i * 100) % 500;
      final notamId = 'A$notamNumber/24';
      
      // Fill in template variables
      final letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G'];
      final directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
      final runways = ['04', '09', '13', '18', '22', '27', '31', '36'];
      
      final letter = letters[(random + i) % letters.length];
      final letter2 = letters[(random + i + 1) % letters.length];
      final letter3 = letters[(random + i + 2) % letters.length];
      final rwy = runways[(random + i) % runways.length];
      final dir = directions[(random + i) % directions.length];
      final dist = 1000 + (random + i * 100) % 1000;
      final height = 150 + (random + i * 10) % 100;
      final stands = '${10 + (random + i) % 40}-${13 + (random + i) % 40}';
      
      var text = scenario['template'] as String;
      var decoded = scenario['decoded'] as String;
      
      text = text
          .replaceAll('{letter}', letter)
          .replaceAll('{letter2}', letter2)
          .replaceAll('{letter3}', letter3)
          .replaceAll('{rwy}', rwy)
          .replaceAll('{dir}', dir)
          .replaceAll('{dist}', dist.toString())
          .replaceAll('{height}', height.toString())
          .replaceAll('{stands}', stands);
      
      decoded = decoded
          .replaceAll('{letter}', letter)
          .replaceAll('{letter2}', letter2)
          .replaceAll('{letter3}', letter3)
          .replaceAll('{rwy}', rwy)
          .replaceAll('{dir}', dir)
          .replaceAll('{dist}', dist.toString())
          .replaceAll('{height}', height.toString())
          .replaceAll('{stands}', stands);
      
      final days = scenario['days'] as int?;
      final effectiveUntil = days != null ? now.add(Duration(days: days)) : null;
      
      notams.add(
        Notam(
          id: '${notamId}_${now.millisecondsSinceEpoch}',
          notamId: notamId,
          icaoCode: icaoCode,
          type: 'N',
          effectiveFrom: now.subtract(Duration(hours: 6 + i * 2)),
          effectiveUntil: effectiveUntil,
          schedule: scenario['schedule'] as String,
          text: '$notamId NOTAMN\nQ) ZNY/QMXLC/IV/NBO/A/000/999/\nA) $icaoCode\nE) $text',
          decodedText: decoded,
          purpose: 'NBO',
          scope: 'A',
          traffic: 'IV',
          fetchedAt: now,
          category: scenario['category'] as String,
        ),
      );
    }

    // Sort by importance and date
    notams.sort((a, b) {
      final importanceCompare = b.importance.index.compareTo(
        a.importance.index,
      );
      if (importanceCompare != 0) return importanceCompare;
      return b.effectiveFrom.compareTo(a.effectiveFrom);
    });

    developer.log('📋 Generated ${notams.length} NOTAMs for $icaoCode');
    return notams;
  }

  bool _isCacheValid(List<Notam> notams) {
    if (notams.isEmpty) return false;

    final oldestFetch = notams
        .map((n) => n.fetchedAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);

    return DateTime.now().difference(oldestFetch) < _cacheExpiry;
  }

  Future<List<Notam>> _getCachedNotams(String icaoCode) async {
    final cacheKey = 'notams_$icaoCode';
    developer.log('📋 Checking cache for key: $cacheKey');
    final cachedData = await _cacheService.getCachedData(cacheKey);

    if (cachedData != null) {
      try {
        final List<dynamic> jsonList = json.decode(cachedData);
        final notams = jsonList.map((json) {
          // Ensure the JSON data is properly typed
          final Map<String, dynamic> notamJson = Map<String, dynamic>.from(
            json,
          );

          // Clean up any corrupted NOTAM IDs
          if (notamJson['notamId'] != null) {
            String notamId = notamJson['notamId'].toString();
            
            // Extract just the NOTAM ID pattern (e.g., A1234/24)
            final notamIdMatch = RegExp(r'([A-Z]\d{4}/\d{2})').firstMatch(notamId);
            if (notamIdMatch != null) {
              // Use only the extracted NOTAM ID, discarding any corruption
              notamId = notamIdMatch.group(0) ?? '';
            } else {
              // If no valid pattern found, clean up the string
              // Remove any HTML tags or fragments
              notamId = notamId.replaceAll(RegExp(r'<[^>]*>'), '');
              // Remove any URL encoding artifacts
              notamId = notamId.replaceAll(RegExp(r'%[0-9A-Fa-f]{2}'), '');
              // Remove any null bytes or control characters
              notamId = notamId.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
              // Remove any special HTML entities
              notamId = notamId.replaceAll(RegExp(r'&[a-zA-Z]+;'), '');
              notamId = notamId.trim();
            }
            
            notamJson['notamId'] = notamId;
          }

          return Notam.fromJson(notamJson);
        }).toList();

        developer.log('📋 Found ${notams.length} cached NOTAMs for $icaoCode');
        // Log first NOTAM ID to debug
        if (notams.isNotEmpty) {
          developer.log(
            '📋 First cached NOTAM ID: ${notams.first.notamId} for ${notams.first.icaoCode}',
          );
        }
        return notams;
      } catch (e) {
        developer.log('❌ Error parsing cached NOTAMs: $e');
        // Clear corrupted cache
        await _cacheService.clearCachedData(cacheKey);
        return [];
      }
    }

    developer.log('📋 No cached NOTAMs found for $icaoCode');
    return [];
  }

  Future<void> _cacheNotams(String icaoCode, List<Notam> notams) async {
    final cacheKey = 'notams_$icaoCode';
    developer.log(
      '📋 Caching ${notams.length} NOTAMs for $icaoCode with key: $cacheKey',
    );
    if (notams.isNotEmpty) {
      developer.log(
        '📋 First NOTAM to cache: ${notams.first.notamId} for ${notams.first.icaoCode}',
      );
    }

    // Clean up NOTAM data before caching to prevent corruption
    final cleanedNotams = notams.map((notam) {
      final json = notam.toJson();

      // Ensure NOTAM ID is clean
      if (json['notamId'] != null) {
        String notamId = json['notamId'].toString();
        
        // Extract just the NOTAM ID pattern (e.g., A1234/24)
        final notamIdMatch = RegExp(r'([A-Z]\d{4}/\d{2})').firstMatch(notamId);
        if (notamIdMatch != null) {
          // Use only the extracted NOTAM ID, discarding any corruption
          notamId = notamIdMatch.group(0) ?? '';
        } else {
          // If no valid pattern found, clean up the string
          // Remove any HTML tags or fragments
          notamId = notamId.replaceAll(RegExp(r'<[^>]*>'), '');
          // Remove any URL encoding artifacts
          notamId = notamId.replaceAll(RegExp(r'%[0-9A-Fa-f]{2}'), '');
          // Remove any null bytes or control characters
          notamId = notamId.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
          // Remove any special HTML entities
          notamId = notamId.replaceAll(RegExp(r'&[a-zA-Z]+;'), '');
          notamId = notamId.trim();
        }
        
        json['notamId'] = notamId;
      }

      return json;
    }).toList();

    final jsonData = json.encode(cleanedNotams);
    await _cacheService.cacheData(cacheKey, jsonData);
  }
}
