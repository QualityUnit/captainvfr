import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:captainvfr/utils/terrain_color_utils.dart';

void main() {
  group('TerrainColorUtils', () {
    test('returns black for below terrain', () {
      final color = TerrainColorUtils.getTerrainColor(-50.0);
      expect(color, Colors.black);
    });

    test('returns red for danger clearance (< 200ft)', () {
      final color = TerrainColorUtils.getTerrainColor(150.0);
      expect(color, Colors.red.shade700);
    });

    test('returns orange for warning clearance (200-500ft)', () {
      final color = TerrainColorUtils.getTerrainColor(350.0);
      expect(color, Colors.orange.shade600);
    });

    test('returns yellow for caution clearance (500-1000ft)', () {
      final color = TerrainColorUtils.getTerrainColor(750.0);
      expect(color, Colors.yellow.shade700);
    });

    test('returns green for safe clearance (> 1000ft)', () {
      final color = TerrainColorUtils.getTerrainColor(1500.0);
      expect(color, Colors.green.shade600);
    });

    test('getTerrainColorWithOpacity applies opacity correctly', () {
      final color = TerrainColorUtils.getTerrainColorWithOpacity(1500.0, 0.5);
      expect(color.alpha, closeTo(0.5 * 255, 1));
    });

    test('getTerrainCategory returns correct categories', () {
      expect(
        TerrainColorUtils.getTerrainCategory(-50.0),
        TerrainCategory.critical,
      );
      expect(
        TerrainColorUtils.getTerrainCategory(150.0),
        TerrainCategory.danger,
      );
      expect(
        TerrainColorUtils.getTerrainCategory(350.0),
        TerrainCategory.warning,
      );
      expect(
        TerrainColorUtils.getTerrainCategory(750.0),
        TerrainCategory.caution,
      );
      expect(
        TerrainColorUtils.getTerrainCategory(1500.0),
        TerrainCategory.safe,
      );
    });

    test('getCategoryName returns correct names', () {
      expect(
        TerrainColorUtils.getCategoryName(TerrainCategory.safe),
        'Safe',
      );
      expect(
        TerrainColorUtils.getCategoryName(TerrainCategory.caution),
        'Caution',
      );
      expect(
        TerrainColorUtils.getCategoryName(TerrainCategory.warning),
        'Warning',
      );
      expect(
        TerrainColorUtils.getCategoryName(TerrainCategory.danger),
        'Danger',
      );
      expect(
        TerrainColorUtils.getCategoryName(TerrainCategory.critical),
        'CRITICAL',
      );
    });

    test('getCategoryDescription returns correct descriptions', () {
      expect(
        TerrainColorUtils.getCategoryDescription(TerrainCategory.safe),
        'Terrain clearance > 1000ft',
      );
      expect(
        TerrainColorUtils.getCategoryDescription(TerrainCategory.caution),
        'Terrain clearance 500-1000ft',
      );
      expect(
        TerrainColorUtils.getCategoryDescription(TerrainCategory.warning),
        'Terrain clearance 200-500ft',
      );
      expect(
        TerrainColorUtils.getCategoryDescription(TerrainCategory.danger),
        'Terrain clearance < 200ft',
      );
      expect(
        TerrainColorUtils.getCategoryDescription(TerrainCategory.critical),
        'BELOW TERRAIN!',
      );
    });

    test('calculateMSA adds 1000ft buffer for day', () {
      final msa = TerrainColorUtils.calculateMSA(2000.0, isNight: false);
      expect(msa, 3000.0);
    });

    test('calculateMSA adds 2000ft buffer for night', () {
      final msa = TerrainColorUtils.calculateMSA(2000.0, isNight: true);
      expect(msa, 4000.0);
    });

    test('calculateMSA handles zero terrain elevation', () {
      final msaDay = TerrainColorUtils.calculateMSA(0.0, isNight: false);
      expect(msaDay, 1000.0);

      final msaNight = TerrainColorUtils.calculateMSA(0.0, isNight: true);
      expect(msaNight, 2000.0);
    });

    test('calculateMSA handles high terrain elevation', () {
      final msaDay = TerrainColorUtils.calculateMSA(10000.0, isNight: false);
      expect(msaDay, 11000.0);

      final msaNight = TerrainColorUtils.calculateMSA(10000.0, isNight: true);
      expect(msaNight, 12000.0);
    });

    test('boundary conditions for clearance categories', () {
      // Test exact boundaries
      expect(
        TerrainColorUtils.getTerrainCategory(0.0),
        TerrainCategory.danger, // 0ft is danger
      );
      expect(
        TerrainColorUtils.getTerrainCategory(200.0),
        TerrainCategory.warning, // Exactly 200ft is warning
      );
      expect(
        TerrainColorUtils.getTerrainCategory(500.0),
        TerrainCategory.caution, // Exactly 500ft is caution
      );
      expect(
        TerrainColorUtils.getTerrainCategory(1000.0),
        TerrainCategory.safe, // Exactly 1000ft is safe
      );
    });
  });
}
