import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/search_history_item.dart';
import '../models/airport.dart';
import '../models/navaid.dart';

/// Service for managing search history functionality
class SearchHistoryService extends ChangeNotifier {
  static const String _keySearchHistory = 'search_history';
  static const int _maxHistoryItems = 10;

  late SharedPreferences _prefs;
  bool _isInitialized = false;
  List<SearchHistoryItem> _historyItems = [];

  /// Gets the current search history items, sorted by most recent first
  List<SearchHistoryItem> get historyItems => List.unmodifiable(_historyItems);

  /// Whether the service has been initialized
  bool get isInitialized => _isInitialized;

  SearchHistoryService() {
    _init();
  }

  /// Initialize the service and load existing history
  Future<void> _init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadHistory();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Failed to initialize SearchHistoryService: $e');
      _isInitialized = true;
      _historyItems = [];
      notifyListeners();
    }
  }

  /// Load history from SharedPreferences
  Future<void> _loadHistory() async {
    try {
      final List<String>? historyStrings = _prefs.getStringList(_keySearchHistory);
      if (historyStrings != null) {
        _historyItems = historyStrings
            .map((jsonString) {
              try {
                return SearchHistoryItem.fromJsonString(jsonString);
              } catch (e) {
                debugPrint('Failed to parse history item: $e');
                return null;
              }
            })
            .where((item) => item != null)
            .cast<SearchHistoryItem>()
            .toList();

        // Sort by most recent first
        _historyItems.sort((a, b) => b.lastSelected.compareTo(a.lastSelected));
      }
    } catch (e) {
      debugPrint('Failed to load search history: $e');
      _historyItems = [];
    }
  }

  /// Save history to SharedPreferences
  Future<void> _saveHistory() async {
    try {
      final List<String> historyStrings = _historyItems
          .map((item) => item.toJsonString())
          .toList();
      await _prefs.setStringList(_keySearchHistory, historyStrings);
    } catch (e) {
      debugPrint('Failed to save search history: $e');
    }
  }

  /// Add an airport to search history
  Future<void> addAirport(Airport airport) async {
    final historyItem = SearchHistoryItem.fromAirport(airport);
    await _addHistoryItem(historyItem);
  }

  /// Add a navaid to search history
  Future<void> addNavaid(Navaid navaid) async {
    final historyItem = SearchHistoryItem.fromNavaid(navaid);
    await _addHistoryItem(historyItem);
  }

  /// Add a history item, handling duplicates and size limits
  Future<void> _addHistoryItem(SearchHistoryItem newItem) async {
    if (!_isInitialized) {
      return;
    }

    // Remove existing item if it already exists
    _historyItems.removeWhere((item) => item.id == newItem.id && item.type == newItem.type);

    // Add new item at the beginning
    _historyItems.insert(0, newItem);

    // Limit to maximum items
    if (_historyItems.length > _maxHistoryItems) {
      _historyItems = _historyItems.take(_maxHistoryItems).toList();
    }

    await _saveHistory();
    notifyListeners();
  }

  /// Remove a specific item from history
  Future<void> removeHistoryItem(SearchHistoryItem item) async {
    if (!_isInitialized) {
      return;
    }

    _historyItems.removeWhere((historyItem) => 
        historyItem.id == item.id && historyItem.type == item.type);
    
    await _saveHistory();
    notifyListeners();
  }

  /// Clear all search history
  Future<void> clearHistory() async {
    if (!_isInitialized) {
      return;
    }

    _historyItems.clear();
    await _saveHistory();
    notifyListeners();
  }

  /// Get history items filtered by type
  List<SearchHistoryItem> getHistoryByType(SearchHistoryItemType type) {
    return _historyItems.where((item) => item.type == type).toList();
  }

  /// Get airport history items only
  List<SearchHistoryItem> get airportHistory => getHistoryByType(SearchHistoryItemType.airport);

  /// Get navaid history items only
  List<SearchHistoryItem> get navaidHistory => getHistoryByType(SearchHistoryItemType.navaid);

  /// Check if a specific item exists in history
  bool hasHistoryItem(String id, SearchHistoryItemType type) {
    return _historyItems.any((item) => item.id == id && item.type == type);
  }
}