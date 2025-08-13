import 'dart:convert';
import 'airport.dart';
import 'navaid.dart';

/// Represents an item in the search history that can be either an airport or navaid
class SearchHistoryItem {
  final String id;
  final String name;
  final String code;
  final SearchHistoryItemType type;
  final String? country;
  final String? municipality;
  final double? frequencyKhz; // For navaids
  final DateTime lastSelected;

  const SearchHistoryItem({
    required this.id,
    required this.name,
    required this.code,
    required this.type,
    this.country,
    this.municipality,
    this.frequencyKhz,
    required this.lastSelected,
  });

  /// Creates a SearchHistoryItem from an Airport
  factory SearchHistoryItem.fromAirport(Airport airport) {
    return SearchHistoryItem(
      id: airport.icao,
      name: airport.name,
      code: airport.icao,
      type: SearchHistoryItemType.airport,
      country: airport.country,
      municipality: airport.municipality,
      lastSelected: DateTime.now(),
    );
  }

  /// Creates a SearchHistoryItem from a Navaid
  factory SearchHistoryItem.fromNavaid(Navaid navaid) {
    return SearchHistoryItem(
      id: navaid.ident,
      name: navaid.name,
      code: navaid.ident,
      type: SearchHistoryItemType.navaid,
      frequencyKhz: navaid.frequencyKhz,
      lastSelected: DateTime.now(),
    );
  }

  /// Creates a SearchHistoryItem from JSON
  factory SearchHistoryItem.fromJson(Map<String, dynamic> json) {
    return SearchHistoryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      code: json['code'] as String,
      type: SearchHistoryItemType.values.byName(json['type'] as String),
      country: json['country'] as String?,
      municipality: json['municipality'] as String?,
      frequencyKhz: json['frequencyKhz'] as double?,
      lastSelected: DateTime.parse(json['lastSelected'] as String),
    );
  }

  /// Converts the item to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'code': code,
      'type': type.name,
      'country': country,
      'municipality': municipality,
      'frequencyKhz': frequencyKhz,
      'lastSelected': lastSelected.toIso8601String(),
    };
  }

  /// Creates a SearchHistoryItem from JSON string
  factory SearchHistoryItem.fromJsonString(String jsonString) {
    return SearchHistoryItem.fromJson(json.decode(jsonString));
  }

  /// Converts the item to JSON string
  String toJsonString() {
    return json.encode(toJson());
  }

  /// Updates the last selected timestamp
  SearchHistoryItem copyWithNewTimestamp() {
    return SearchHistoryItem(
      id: id,
      name: name,
      code: code,
      type: type,
      country: country,
      municipality: municipality,
      frequencyKhz: frequencyKhz,
      lastSelected: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SearchHistoryItem &&
        other.id == id &&
        other.type == type;
  }

  @override
  int get hashCode => id.hashCode ^ type.hashCode;

  @override
  String toString() {
    return 'SearchHistoryItem(id: $id, name: $name, code: $code, type: $type)';
  }
}

/// Types of items that can be stored in search history
enum SearchHistoryItemType {
  airport,
  navaid,
}