import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:captainvfr/utils/weather_color_utils.dart';
import 'package:captainvfr/models/airport.dart';
import 'package:latlong2/latlong.dart';

void main() {
  group('WeatherColorUtils', () {
    test('returns grey for null airport', () {
      final color = WeatherColorUtils.getWeatherColor(null);
      expect(color, Colors.grey);
    });

    test('returns grey for airport without weather data', () {
      final airport = Airport(
        icao: 'TEST',
        name: 'Test Airport',
        city: 'Test City',
        country: 'Test Country',
        position: LatLng(40.0, -74.0),
        type: 'large_airport',
      );
      final color = WeatherColorUtils.getWeatherColor(airport);
      expect(color, Colors.grey);
    });

    test('identifies VFR conditions correctly', () {
      final airport = Airport(
        icao: 'TEST',
        name: 'Test Airport',
        city: 'Test City',
        country: 'Test Country',
        position: LatLng(40.0, -74.0),
        type: 'large_airport',
      );
      airport.updateWeather('METAR TEST 121853Z 24008KT 10SM FEW250 22/14 A3012');

      final category = WeatherColorUtils.getWeatherCategory(airport);
      expect(category, WeatherCategory.vfr);

      final color = WeatherColorUtils.getWeatherColor(airport);
      expect(color, Colors.green.shade600);
    });

    test('identifies MVFR conditions from ceiling', () {
      final airport = Airport(
        icao: 'TEST',
        name: 'Test Airport',
        city: 'Test City',
        country: 'Test Country',
        position: LatLng(40.0, -74.0),
        type: 'large_airport',
      );
      // BKN020 = broken clouds at 2000ft (MVFR)
      airport.updateWeather('METAR TEST 121853Z 24008KT 10SM BKN020 22/14 A3012');

      final category = WeatherColorUtils.getWeatherCategory(airport);
      expect(category, WeatherCategory.mvfr);

      final color = WeatherColorUtils.getWeatherColor(airport);
      expect(color, Colors.yellow.shade700);
    });

    test('identifies IFR conditions from ceiling', () {
      final airport = Airport(
        icao: 'TEST',
        name: 'Test Airport',
        city: 'Test City',
        country: 'Test Country',
        position: LatLng(40.0, -74.0),
        type: 'large_airport',
      );
      // OVC008 = overcast at 800ft (IFR)
      airport.updateWeather('METAR TEST 121853Z 24008KT 10SM OVC008 22/14 A3012');

      final category = WeatherColorUtils.getWeatherCategory(airport);
      expect(category, WeatherCategory.ifr);

      final color = WeatherColorUtils.getWeatherColor(airport);
      expect(color, Colors.red.shade600);
    });

    test('identifies LIFR conditions from ceiling', () {
      final airport = Airport(
        icao: 'TEST',
        name: 'Test Airport',
        city: 'Test City',
        country: 'Test Country',
        position: LatLng(40.0, -74.0),
        type: 'large_airport',
      );
      // OVC003 = overcast at 300ft (LIFR)
      airport.updateWeather('METAR TEST 121853Z 24008KT 10SM OVC003 22/14 A3012');

      final category = WeatherColorUtils.getWeatherCategory(airport);
      expect(category, WeatherCategory.lifr);

      final color = WeatherColorUtils.getWeatherColor(airport);
      expect(color, Colors.black87);
    });

    test('identifies MVFR conditions from visibility', () {
      final airport = Airport(
        icao: 'TEST',
        name: 'Test Airport',
        city: 'Test City',
        country: 'Test Country',
        position: LatLng(40.0, -74.0),
        type: 'large_airport',
      );
      // 4SM = 4 statute miles visibility (MVFR)
      airport.updateWeather('METAR TEST 121853Z 24008KT 4SM FEW250 22/14 A3012');

      final category = WeatherColorUtils.getWeatherCategory(airport);
      expect(category, WeatherCategory.mvfr);
    });

    test('identifies IFR conditions from visibility', () {
      final airport = Airport(
        icao: 'TEST',
        name: 'Test Airport',
        city: 'Test City',
        country: 'Test Country',
        position: LatLng(40.0, -74.0),
        type: 'large_airport',
      );
      // 2SM = 2 statute miles visibility (IFR)
      airport.updateWeather('METAR TEST 121853Z 24008KT 2SM FEW250 22/14 A3012');

      final category = WeatherColorUtils.getWeatherCategory(airport);
      expect(category, WeatherCategory.ifr);
    });

    test('identifies LIFR conditions from visibility', () {
      final airport = Airport(
        icao: 'TEST',
        name: 'Test Airport',
        city: 'Test City',
        country: 'Test Country',
        position: LatLng(40.0, -74.0),
        type: 'large_airport',
      );
      // 1/2SM = 0.5 statute miles visibility (LIFR)
      airport.updateWeather('METAR TEST 121853Z 24008KT 1/2SM FEW250 22/14 A3012');

      final category = WeatherColorUtils.getWeatherCategory(airport);
      expect(category, WeatherCategory.lifr);
    });

    test('uses lowest ceiling when multiple cloud layers', () {
      final airport = Airport(
        icao: 'TEST',
        name: 'Test Airport',
        city: 'Test City',
        country: 'Test Country',
        position: LatLng(40.0, -74.0),
        type: 'large_airport',
      );
      // BKN008 at 800ft is lowest ceiling (IFR)
      airport.updateWeather('METAR TEST 121853Z 24008KT 10SM BKN008 OVC020 22/14 A3012');

      final category = WeatherColorUtils.getWeatherCategory(airport);
      expect(category, WeatherCategory.ifr);
    });

    test('getCategoryName returns correct names', () {
      expect(WeatherColorUtils.getCategoryName(WeatherCategory.vfr), 'VFR');
      expect(WeatherColorUtils.getCategoryName(WeatherCategory.mvfr), 'MVFR');
      expect(WeatherColorUtils.getCategoryName(WeatherCategory.ifr), 'IFR');
      expect(WeatherColorUtils.getCategoryName(WeatherCategory.lifr), 'LIFR');
      expect(WeatherColorUtils.getCategoryName(WeatherCategory.unknown), 'Unknown');
    });

    test('getCategoryDescription returns correct descriptions', () {
      expect(
        WeatherColorUtils.getCategoryDescription(WeatherCategory.vfr),
        'Visual Flight Rules',
      );
      expect(
        WeatherColorUtils.getCategoryDescription(WeatherCategory.mvfr),
        'Marginal VFR',
      );
      expect(
        WeatherColorUtils.getCategoryDescription(WeatherCategory.ifr),
        'Instrument Flight Rules',
      );
      expect(
        WeatherColorUtils.getCategoryDescription(WeatherCategory.lifr),
        'Low IFR',
      );
      expect(
        WeatherColorUtils.getCategoryDescription(WeatherCategory.unknown),
        'Weather data unavailable',
      );
    });

    test('getCategoryColor returns correct colors', () {
      expect(
        WeatherColorUtils.getCategoryColor(WeatherCategory.vfr),
        Colors.green.shade600,
      );
      expect(
        WeatherColorUtils.getCategoryColor(WeatherCategory.mvfr),
        Colors.yellow.shade700,
      );
      expect(
        WeatherColorUtils.getCategoryColor(WeatherCategory.ifr),
        Colors.red.shade600,
      );
      expect(
        WeatherColorUtils.getCategoryColor(WeatherCategory.lifr),
        Colors.black87,
      );
      expect(
        WeatherColorUtils.getCategoryColor(WeatherCategory.unknown),
        Colors.grey,
      );
    });

    test('uses airport flightCategory when available', () {
      final airport = Airport(
        icao: 'TEST',
        name: 'Test Airport',
        city: 'Test City',
        country: 'Test Country',
        position: LatLng(40.0, -74.0),
        type: 'large_airport',
      );
      // Set raw METAR with explicit flight category
      airport.updateWeather('METAR TEST 121853Z 24008KT 10SM VFR FEW250 22/14 A3012');

      final category = WeatherColorUtils.getWeatherCategory(airport);
      expect(category, WeatherCategory.vfr);
    });
  });
}
