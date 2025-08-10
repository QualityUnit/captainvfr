import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';
import '../services/offline_map_service.dart';
import '../services/cache_service.dart';
import '../services/airport_service.dart';
import '../services/navaid_service.dart';
import '../services/weather_service.dart';
import '../services/tiled_data_loader.dart';
import '../constants/app_colors.dart';
import '../l10n/app_localizations.dart';
import 'offline_data/controllers/offline_data_state_controller.dart';
import 'offline_data/components/cache_card.dart';
import 'offline_data/components/weather_cache_card.dart';
import 'offline_data/components/map_tiles_cache_card.dart';
import 'offline_data/sections/download_map_tiles_section.dart';
import 'offline_data/dialogs/clear_cache_dialog.dart';
import 'offline_data/helpers/date_formatter.dart';
import 'offline_data/helpers/cache_statistics_helper.dart';

/// Screen for managing all offline data and caches
class OfflineDataScreen extends StatefulWidget {
  final LatLngBounds? currentMapBounds;
  final OfflineDataStateController? stateController;
  
  const OfflineDataScreen({
    super.key,
    this.currentMapBounds,
    this.stateController,
  });

  @override
  State<OfflineDataScreen> createState() => _OfflineDataScreenState();
}

class _OfflineDataScreenState extends State<OfflineDataScreen> {
  final OfflineMapService _offlineMapService = OfflineMapService();
  final CacheService _cacheService = CacheService();
  final AirportService _airportService = AirportService();
  final NavaidService _navaidService = NavaidService();
  final WeatherService _weatherService = WeatherService();
  final TiledDataLoader _tiledDataLoader = TiledDataLoader();
  
  final ScrollController _scrollController = ScrollController();
  late final OfflineDataStateController _stateController;

  @override
  void initState() {
    super.initState();
    _stateController = widget.stateController ?? OfflineDataStateController();
    _loadAllCacheStats();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Only dispose if we created the controller
    if (widget.stateController == null) {
      _stateController.dispose();
    }
    super.dispose();
  }


  Future<void> _loadAllCacheStats({bool preserveScroll = false}) async {
    double? scrollPosition;
    if (preserveScroll && _scrollController.hasClients) {
      scrollPosition = _scrollController.offset;
    }

    if (!preserveScroll) {
      _stateController.setLoading(true);
    }

    try {
      await _cacheService.initialize();
      await _weatherService.initialize();

      final mapStats = await _offlineMapService.getCacheStatistics();
      final stats = await CacheStatisticsHelper.getCacheStatistics(_weatherService);

      _stateController.setMapCacheStats(mapStats);
      _stateController.setCacheStats(stats);
      _stateController.setLoading(false);

      if (scrollPosition != null && _scrollController.hasClients) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollController.animateTo(
            scrollPosition!,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        });
      }
    } catch (e) {
      _stateController.setLoading(false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)?.errorLoadingCacheStats(e.toString()) ?? 'Error loading cache stats: $e')),
        );
      }
    }
  }

  Future<void> _refreshAllData() async {
    final l10n = AppLocalizations.of(context)!;
    _stateController.setRefreshing(true);

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(l10n.refreshingAllAviationData)),
              ],
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }

      final futures = [
        _airportService.refreshData(),
        _navaidService.refreshData(),
        _weatherService.forceReload(),
      ];

      // OpenAIP data is now pre-downloaded offline

      await Future.wait(futures);
      await _loadAllCacheStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.allDataRefreshedSuccessfully),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorRefreshingData(e.toString())),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      _stateController.setRefreshing(false);
    }
  }


  Future<void> _refreshWeatherData() async {
    final l10n = AppLocalizations.of(context)!;
    _stateController.setRefreshing(true);

    try {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(l10n.refreshingWeatherData)),
              ],
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      await _weatherService.forceReload();
      await _loadAllCacheStats();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.weatherDataRefreshedSuccessfully),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorRefreshingWeatherData(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      _stateController.setRefreshing(false);
    }
  }

  Future<void> _clearSpecificCache(String cacheName) async {
    final confirm = await ClearCacheDialog.show(
      context: context,
      cacheName: cacheName,
    );

    if (confirm == true) {
      try {
        switch (cacheName) {
          case 'Airports':
            await _cacheService.clearAirportsCache();
            break;
          case 'Navaids':
            await _cacheService.clearNavaidsCache();
            break;
          case 'Runways':
            await _cacheService.clearRunwaysCache();
            break;
          case 'Frequencies':
            await _cacheService.clearFrequenciesCache();
            break;
          case 'Airspaces':
            await _cacheService.clearAirspacesCache();
            break;
          case 'Reporting Points':
            await _cacheService.clearReportingPointsCache();
            break;
          case 'Weather':
            await _cacheService.clearWeatherCache();
            break;
          case 'Map Tiles':
            await _offlineMapService.clearCache();
            break;
          case 'Obstacles':
            _tiledDataLoader.clearCacheForType('obstacles');
            break;
          case 'Hotspots':
            _tiledDataLoader.clearCacheForType('hotspots');
            break;
        }
        await _loadAllCacheStats();
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.clearedCache(cacheName)),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.errorClearingCache(cacheName, e.toString()))),
          );
        }
      }
    }
  }

  Future<void> _clearAllCaches() async {
    final confirm = await ClearCacheDialog.show(
      context: context,
      cacheName: '',
      isAllCaches: true,
    );

    if (confirm == true) {
      try {
        await Future.wait([
          _cacheService.clearAllCaches(),
          _offlineMapService.clearCache(),
        ]);
        // Clear tiled data caches
        _tiledDataLoader.clearCache();
        await _loadAllCacheStats();
        if (mounted) {
          final l10n = AppLocalizations.of(context)!;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.allCachesCleared),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(AppLocalizations.of(context)?.errorClearingCaches(e.toString()) ?? 'Error clearing caches: $e')),
          );
        }
      }
    }
  }

  Future<void> _downloadCurrentArea() async {
    if (widget.currentMapBounds == null) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.pleaseOpenFromMap),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    await _downloadArea(
      northEast: widget.currentMapBounds!.northEast,
      southWest: widget.currentMapBounds!.southWest,
    );
  }

  Future<void> _downloadArea({
    required LatLng northEast,
    required LatLng southWest,
  }) async {
    _stateController.setDownloading(true);
    _stateController.resetDownloadState();

    // Log download area for debugging
    debugPrint('Starting download for area: NE: ${northEast.latitude}, ${northEast.longitude}, SW: ${southWest.latitude}, ${southWest.longitude}');
    debugPrint('Zoom levels: ${_stateController.minZoom} to ${_stateController.maxZoom}');

    try {
      await _offlineMapService.downloadAreaTiles(
        bounds: LatLngBounds(northEast, southWest),
        minZoom: _stateController.minZoom,
        maxZoom: _stateController.maxZoom,
        onProgress: (current, total, skipped, downloaded) {
          _stateController.updateDownloadProgress(current, total, skipped, downloaded);
          
          // Update cache statistics every 25 tiles, preserving scroll position
          if (current % 25 == 0 || current == total) {
            _loadAllCacheStats(preserveScroll: true);
          }
        },
      );

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        final message = _stateController.skippedTiles > 0
            ? l10n.downloadedTilesWithSkipped(_stateController.downloadedTiles, _stateController.skippedTiles)
            : l10n.downloadedTilesSuccessfully(_stateController.downloadedTiles);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final isUserCancelled = e.toString().contains('cancelled by user');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isUserCancelled 
                ? (AppLocalizations.of(context)?.downloadCancelled ?? 'Download cancelled') 
                : (AppLocalizations.of(context)?.downloadFailed(e.toString()) ?? 'Download failed: $e'),
            ),
            backgroundColor: isUserCancelled ? Colors.orange : Colors.red,
          ),
        );
      }
    } finally {
      _stateController.resetDownloadState();
      await _loadAllCacheStats(preserveScroll: true);
    }
  }

  void _stopDownload() {
    _offlineMapService.cancelDownload();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.offlineData,
          style: const TextStyle(color: AppColors.primaryTextColor),
        ),
        backgroundColor: AppColors.dialogBackgroundColor,
        foregroundColor: AppColors.primaryTextColor,
        actions: [
          ListenableBuilder(
            listenable: _stateController,
            builder: (context, child) {
              return IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: _stateController.isRefreshing ? null : _refreshAllData,
                tooltip: l10n.refreshAllData,
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_forever),
            onPressed: _clearAllCaches,
            tooltip: l10n.clearAllCaches,
          ),
        ],
      ),
      backgroundColor: AppColors.backgroundColor,
      body: ListenableBuilder(
        listenable: _stateController,
        builder: (context, child) {
          if (_stateController.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () => _loadAllCacheStats(),
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Data Caches Section
                  Text(
                    AppLocalizations.of(context)?.aviationDataCaches ?? 'Aviation Data Caches',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Airports cache
                  CacheCard(
                    title: l10n.airports,
                    icon: Icons.flight_land,
                    count: _stateController.cacheStats['airports']?['count'] ?? 0,
                    lastFetch: DateFormatter.formatLastFetch(
                      _stateController.cacheStats['airports']?['lastFetch'],
                    ),
                    onClear: () => _clearSpecificCache('Airports'),
                    subtitle: l10n.airportInformation,
                    isRefreshing: _stateController.isRefreshing,
                  ),

                  const SizedBox(height: 8),

                  // Navaids cache
                  CacheCard(
                    title: l10n.navigationAids,
                    icon: Icons.radar,
                    count: _stateController.cacheStats['navaids']?['count'] ?? 0,
                    lastFetch: DateFormatter.formatLastFetch(
                      _stateController.cacheStats['navaids']?['lastFetch'],
                    ),
                    onClear: () => _clearSpecificCache('Navaids'),
                    subtitle: l10n.vorNdbNavigation,
                    isRefreshing: _stateController.isRefreshing,
                  ),

                  const SizedBox(height: 8),

                  // Runways cache
                  CacheCard(
                    title: l10n.runways,
                    icon: Icons.horizontal_rule,
                    count: _stateController.cacheStats['runways']?['count'] ?? 0,
                    lastFetch: DateFormatter.formatLastFetch(
                      _stateController.cacheStats['runways']?['lastFetch'],
                    ),
                    onClear: () => _clearSpecificCache('Runways'),
                    subtitle: l10n.runwayInformation,
                    isRefreshing: _stateController.isRefreshing,
                  ),

                  const SizedBox(height: 8),

                  // Frequencies cache
                  CacheCard(
                    title: l10n.frequencies,
                    icon: Icons.radio,
                    count: _stateController.cacheStats['frequencies']?['count'] ?? 0,
                    lastFetch: DateFormatter.formatLastFetch(
                      _stateController.cacheStats['frequencies']?['lastFetch'],
                    ),
                    onClear: () => _clearSpecificCache('Frequencies'),
                    subtitle: l10n.radioFrequencies,
                    isRefreshing: _stateController.isRefreshing,
                  ),

                  const SizedBox(height: 8),
                  
                  // Additional Runways cache
                  if (_stateController.cacheStats['openaip_runways'] != null &&
                      (_stateController.cacheStats['openaip_runways']?['count'] ?? 0) > 0)
                    CacheCard(
                      title: l10n.additionalRunways,
                      icon: Icons.flight_takeoff,
                      count: _stateController.cacheStats['openaip_runways']?['count'] ?? 0,
                      lastFetch: l10n.supplementalData,
                      onClear: () {}, // OpenAIP data is tiled
                      subtitle: l10n.additionalRunwayData,
                      isRefreshing: _stateController.isRefreshing,
                    ),
                  
                  if (_stateController.cacheStats['openaip_runways'] != null &&
                      (_stateController.cacheStats['openaip_runways']?['count'] ?? 0) > 0)
                    const SizedBox(height: 8),
                  
                  // Additional Frequencies cache
                  if (_stateController.cacheStats['openaip_frequencies'] != null &&
                      (_stateController.cacheStats['openaip_frequencies']?['count'] ?? 0) > 0)
                    CacheCard(
                      title: l10n.additionalFrequencies,
                      icon: Icons.settings_input_antenna,
                      count: _stateController.cacheStats['openaip_frequencies']?['count'] ?? 0,
                      lastFetch: l10n.supplementalData,
                      onClear: () {}, // OpenAIP data is tiled
                      subtitle: l10n.additionalFrequencyData,
                      isRefreshing: _stateController.isRefreshing,
                    ),
                  
                  if (_stateController.cacheStats['openaip_frequencies'] != null &&
                      (_stateController.cacheStats['openaip_frequencies']?['count'] ?? 0) > 0)
                    const SizedBox(height: 8),

                  // Airspaces cache
                  CacheCard(
                    title: l10n.airspaces,
                    icon: Icons.layers,
                    count: _stateController.cacheStats['airspaces']?['count'] ?? 0,
                    lastFetch: DateFormatter.formatLastFetch(
                      _stateController.cacheStats['airspaces']?['lastFetch'],
                    ),
                    onClear: () => _clearSpecificCache('Airspaces'),
                    subtitle: l10n.controlledAirspaces,
                    onRefresh: null, // OpenAIP data is now pre-downloaded offline
                    isRefreshing: _stateController.isRefreshing,
                  ),

                  const SizedBox(height: 8),

                  // Reporting points cache
                  CacheCard(
                    title: l10n.reportingPoints,
                    icon: Icons.location_on,
                    count: _stateController.cacheStats['reportingPoints']?['count'] ?? 0,
                    lastFetch: DateFormatter.formatLastFetch(
                      _stateController.cacheStats['reportingPoints']?['lastFetch'],
                    ),
                    onClear: () => _clearSpecificCache('Reporting Points'),
                    subtitle: l10n.vfrReportingPoints,
                    onRefresh: null, // OpenAIP data is now pre-downloaded offline
                    isRefreshing: _stateController.isRefreshing,
                  ),

                  const SizedBox(height: 8),

                  // Obstacles cache
                  CacheCard(
                    title: l10n.obstacles,
                    icon: Icons.warning,
                    count: _stateController.cacheStats['obstacles']?['count'] ?? 0,
                    lastFetch: DateFormatter.formatLastFetch(
                      _stateController.cacheStats['obstacles']?['lastFetch'],
                    ),
                    onClear: () => _clearSpecificCache('Obstacles'),
                    subtitle: l10n.towersObstacles,
                    onRefresh: null, // OpenAIP data is now pre-downloaded offline
                    isRefreshing: _stateController.isRefreshing,
                  ),

                  const SizedBox(height: 8),

                  // Hotspots cache
                  CacheCard(
                    title: l10n.hotspots,
                    icon: Icons.local_fire_department,
                    count: _stateController.cacheStats['hotspots']?['count'] ?? 0,
                    lastFetch: DateFormatter.formatLastFetch(
                      _stateController.cacheStats['hotspots']?['lastFetch'],
                    ),
                    onClear: () => _clearSpecificCache('Hotspots'),
                    subtitle: l10n.thermalActivity,
                    onRefresh: null, // OpenAIP data is now pre-downloaded offline
                    isRefreshing: _stateController.isRefreshing,
                  ),

                  const SizedBox(height: 8),

                  // Weather cache
                  WeatherCacheCard(
                    metarCount: _stateController.cacheStats['weather']?['metars'] ?? 0,
                    tafCount: _stateController.cacheStats['weather']?['tafs'] ?? 0,
                    lastFetch: DateFormatter.formatLastFetch(
                      _stateController.cacheStats['weather']?['lastFetch'],
                    ),
                    onClear: () => _clearSpecificCache('Weather'),
                    onRefresh: _refreshWeatherData,
                    isRefreshing: _stateController.isRefreshing,
                  ),

                  const SizedBox(height: 24),

                  // Offline Map Tiles Section
                  Text(
                    l10n.offlineMapTiles,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  MapTilesCacheCard(
                    cacheStats: _stateController.mapCacheStats,
                    onClear: () => _clearSpecificCache('Map Tiles'),
                  ),

                  const SizedBox(height: 16),

                  // Download controls
                  DownloadMapTilesSection(
                    controller: _stateController,
                    onDownload: _downloadCurrentArea,
                    onStopDownload: _stopDownload,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}