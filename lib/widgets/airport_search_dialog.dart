import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import '../models/airport.dart';
import '../models/navaid.dart';
import '../models/search_history_item.dart';
import '../services/airport_service.dart';
import '../services/navaid_service.dart';
import '../services/search_history_service.dart';
import '../constants/app_colors.dart';
import '../constants/app_theme.dart';
import '../l10n/app_localizations.dart';

class AirportSearchDialog extends StatefulWidget {
  final AirportService airportService;
  final NavaidService? navaidService;
  final SearchHistoryService searchHistoryService;
  final Function(Airport) onAirportSelected;
  final Function(Navaid)? onNavaidSelected;

  const AirportSearchDialog({
    super.key,
    required this.airportService,
    this.navaidService,
    required this.searchHistoryService,
    required this.onAirportSelected,
    this.onNavaidSelected,
  });

  @override
  State<AirportSearchDialog> createState() => _AirportSearchDialogState();
}

class _AirportSearchDialogState extends State<AirportSearchDialog> {
  final _searchController = TextEditingController();
  List<Airport> _airportResults = [];
  List<Navaid> _navaidResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _airportResults = [];
        _navaidResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _airportResults = widget.airportService.searchAirports(query);
      
      // Search navaids if service is available
      if (widget.navaidService != null) {
        _navaidResults = widget.navaidService!.searchNavaids(query);
      }
      
      _isSearching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Dialog(
      backgroundColor: AppColors.dialogBackgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: AppTheme.extraLargeRadius,
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.8,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.searchAirportsNavaids,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            // Search field
            TextField(
              controller: _searchController,
              autofocus: true,
              style: TextStyle(color: AppColors.primaryTextColor),
              decoration: InputDecoration(
                labelText: l10n.search,
                hintText: l10n.enterAirportNavaidName,
                labelStyle: TextStyle(color: AppColors.secondaryTextColor),
                hintStyle: TextStyle(color: AppColors.secondaryTextColor.withValues(alpha: 0.5)),
                prefixIcon: Icon(Icons.search, color: AppColors.secondaryTextColor),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, color: AppColors.secondaryTextColor),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primaryAccent.withValues(alpha: 0.3)),
                  borderRadius: AppTheme.extraLargeRadius,
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: AppColors.primaryAccent),
                  borderRadius: AppTheme.extraLargeRadius,
                ),
                fillColor: AppColors.fillColorFaint,
                filled: true,
              ),
            ),
            const SizedBox(height: 16),
            // Results
            Expanded(
              child: _buildSearchResults(),
            ),
            const SizedBox(height: 16),
            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.secondaryTextColor,
                  ),
                  child: Text(l10n.cancel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final l10n = AppLocalizations.of(context)!;
    
    if (_searchController.text.isEmpty) {
      return _buildSearchHistorySection();
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasResults = _airportResults.isNotEmpty || _navaidResults.isNotEmpty;
    
    if (!hasResults) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: AppColors.secondaryTextColor),
            const SizedBox(height: 16),
            Text(
              l10n.noResultsFoundForQuery(_searchController.text),
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.trySearchingBy,
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryTextColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: _airportResults.length + _navaidResults.length + (_airportResults.isNotEmpty && _navaidResults.isNotEmpty ? 2 : (_airportResults.isNotEmpty || _navaidResults.isNotEmpty ? 1 : 0)),
      itemBuilder: (context, index) {
        int currentIndex = 0;
        
        // Airports section
        if (_airportResults.isNotEmpty) {
          if (index == currentIndex) {
            return _buildSectionHeader(l10n.airportsCountLabel(_airportResults.length));
          }
          currentIndex++;
          
          if (index < currentIndex + _airportResults.length) {
            final airport = _airportResults[index - currentIndex];
            return _buildAirportTile(context, airport);
          }
          currentIndex += _airportResults.length;
        }
        
        // Navaids section
        if (_navaidResults.isNotEmpty) {
          if (index == currentIndex) {
            return _buildSectionHeader(l10n.navigationAidsCountLabel(_navaidResults.length));
          }
          currentIndex++;
          
          if (index < currentIndex + _navaidResults.length) {
            final navaid = _navaidResults[index - currentIndex];
            return _buildNavaidTile(context, navaid);
          }
        }
        
        return const SizedBox.shrink();
      },
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: AppColors.secondaryTextColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildAirportTile(BuildContext context, Airport airport) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.sectionBackgroundColor,
        borderRadius: AppTheme.defaultRadius,
        border: Border.all(color: AppColors.sectionBorderColor),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primaryAccent.withValues(alpha: 0.1),
            borderRadius: AppTheme.defaultRadius,
          ),
          child: Icon(
            Icons.flight_takeoff,
            color: AppColors.primaryAccent,
          ),
        ),
        title: Text(
          airport.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryTextColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${airport.icao}${airport.iata != null && airport.iata!.isNotEmpty ? ' • ${airport.iata}' : ''}',
              style: TextStyle(
                color: AppColors.primaryAccent,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (airport.municipality != null && airport.municipality!.isNotEmpty)
              Text(
                '${airport.municipality}, ${airport.country}',
                style: TextStyle(
                  color: AppColors.secondaryTextColor,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        trailing: Icon(
          Icons.location_on,
          color: AppColors.secondaryTextColor,
        ),
        onTap: () {
          // Add to search history
          widget.searchHistoryService.addAirport(airport);
          widget.onAirportSelected(airport);
        },
      ),
    );
  }
  
  Widget _buildNavaidTile(BuildContext context, Navaid navaid) {
    // Get appropriate icon based on navaid type
    IconData getNavaidIcon(String type) {
      switch (type.toUpperCase()) {
        case 'VOR':
        case 'VOR-DME':
        case 'VORTAC':
          return Icons.radio_button_checked;
        case 'NDB':
        case 'NDB-DME':
          return Icons.wb_iridescent;
        case 'DME':
          return Icons.track_changes;
        case 'TACAN':
          return Icons.gps_fixed;
        default:
          return Icons.navigation;
      }
    }
    
    // Format frequency based on type
    String formatFrequency(double freqKhz, String type) {
      if (type.toUpperCase().contains('NDB')) {
        // NDB frequencies in kHz
        return '${freqKhz.toStringAsFixed(0)} kHz';
      } else {
        // VOR/DME frequencies in MHz
        final freqMhz = freqKhz / 1000;
        return '${freqMhz.toStringAsFixed(2)} MHz';
      }
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.sectionBackgroundColor,
        borderRadius: AppTheme.defaultRadius,
        border: Border.all(color: AppColors.sectionBorderColor),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: AppTheme.defaultRadius,
          ),
          child: Icon(
            getNavaidIcon(navaid.type),
            color: Colors.blue,
            size: 20,
          ),
        ),
        title: Text(
          navaid.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryTextColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  navaid.ident,
                  style: TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  navaid.type.toUpperCase(),
                  style: TextStyle(
                    color: AppColors.secondaryTextColor,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            Text(
              formatFrequency(navaid.frequencyKhz, navaid.type),
              style: TextStyle(
                color: AppColors.secondaryTextColor,
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: Icon(
          Icons.navigation,
          color: AppColors.secondaryTextColor,
          size: 20,
        ),
        onTap: () {
          if (widget.onNavaidSelected != null) {
            // Add to search history
            widget.searchHistoryService.addNavaid(navaid);
            widget.onNavaidSelected!(navaid);
          }
        },
      ),
    );
  }

  /// Build the search history section when search field is empty
  Widget _buildSearchHistorySection() {
    final l10n = AppLocalizations.of(context)!;
    
    if (!widget.searchHistoryService.isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final historyItems = widget.searchHistoryService.historyItems;
    
    if (historyItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: AppColors.secondaryTextColor),
            const SizedBox(height: 16),
            Text(
              l10n.searchHistoryEmpty,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.searchForAirports,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: AppColors.secondaryTextColor),
            ),
          ],
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.recentSearches,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryTextColor,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                widget.searchHistoryService.clearHistory();
              },
              child: Text(
                l10n.clearHistory,
                style: TextStyle(
                  color: AppColors.primaryAccent,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Expanded(
          child: ListView.builder(
            itemCount: historyItems.length,
            itemBuilder: (context, index) {
              final item = historyItems[index];
              return _buildHistoryItem(context, item);
            },
          ),
        ),
      ],
    );
  }

  /// Build a history item tile
  Widget _buildHistoryItem(BuildContext context, SearchHistoryItem item) {
    IconData getIcon() {
      if (item.type == SearchHistoryItemType.airport) {
        return Icons.flight_takeoff;
      } else {
        // Navaid icon based on frequency for different types
        if (item.frequencyKhz != null && item.frequencyKhz! < 1000) {
          return Icons.wb_iridescent; // NDB
        } else {
          return Icons.radio_button_checked; // VOR/DME
        }
      }
    }
    
    Color getIconColor() {
      return item.type == SearchHistoryItemType.airport 
          ? AppColors.primaryAccent 
          : Colors.blue;
    }
    
    String getSubtitle() {
      if (item.type == SearchHistoryItemType.airport) {
        final parts = <String>[item.code];
        if (item.municipality != null && item.municipality!.isNotEmpty) {
          parts.add('${item.municipality}, ${item.country ?? ''}');
        }
        return parts.join(' • ');
      } else {
        final parts = <String>[item.code];
        if (item.frequencyKhz != null) {
          if (item.frequencyKhz! < 1000) {
            parts.add('${item.frequencyKhz!.toStringAsFixed(0)} kHz');
          } else {
            final freqMhz = item.frequencyKhz! / 1000;
            parts.add('${freqMhz.toStringAsFixed(2)} MHz');
          }
        }
        return parts.join(' • ');
      }
    }
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.sectionBackgroundColor,
        borderRadius: AppTheme.defaultRadius,
        border: Border.all(color: AppColors.sectionBorderColor),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: getIconColor().withValues(alpha: 0.1),
            borderRadius: AppTheme.defaultRadius,
          ),
          child: Icon(
            getIcon(),
            color: getIconColor(),
          ),
        ),
        title: Text(
          item.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.primaryTextColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          getSubtitle(),
          style: TextStyle(
            color: AppColors.secondaryTextColor,
            fontSize: 12,
          ),
        ),
        trailing: Icon(
          Icons.history,
          color: AppColors.secondaryTextColor,
          size: 18,
        ),
        onTap: () => _onHistoryItemSelected(item),
      ),
    );
  }

  /// Handle selection of a history item
  Future<void> _onHistoryItemSelected(SearchHistoryItem item) async {
    if (item.type == SearchHistoryItemType.airport) {
      // Try to find the full airport object
      final airports = widget.airportService.searchAirports(item.code);
      final airport = airports.firstWhere(
        (a) => a.icao == item.id,
        orElse: () => Airport(
          icao: item.code,
          name: item.name,
          city: item.municipality ?? '',
          country: item.country ?? '',
          position: const LatLng(0.0, 0.0),
          elevation: 0,
        ),
      );
      
      // Update history with new timestamp
      await widget.searchHistoryService.addAirport(airport);
      widget.onAirportSelected(airport);
    } else if (item.type == SearchHistoryItemType.navaid && widget.onNavaidSelected != null) {
      // Try to find the full navaid object
      final navaids = widget.navaidService?.searchNavaids(item.code) ?? [];
      final navaid = navaids.firstWhere(
        (n) => n.ident == item.id,
        orElse: () => Navaid(
          id: 0,
          filename: '',
          ident: item.code,
          name: item.name,
          type: 'VOR', // Default type
          frequencyKhz: item.frequencyKhz ?? 0.0,
          position: const LatLng(0.0, 0.0),
          elevationFt: 0,
          isoCountry: '',
          dmeFrequencyKhz: 0.0,
          dmeChannel: '',
          dmeLatitudeDeg: 0,
          dmeLongitudeDeg: 0,
          dmeElevationFt: 0,
          slavedVariationDeg: 0.0,
          magneticVariationDeg: 0.0,
          usageType: '',
          power: 0.0,
          associatedAirport: '',
        ),
      );
      
      // Update history with new timestamp
      await widget.searchHistoryService.addNavaid(navaid);
      widget.onNavaidSelected!(navaid);
    }
  }
}