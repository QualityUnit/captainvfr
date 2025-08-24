# CaptainVFR Terrain Altitude System

## Overview

The Terrain Altitude System provides comprehensive terrain awareness for VFR flight planning and navigation. It combines high-precision LiDAR elevation data for Europe with global SRTM coverage, offering pilots critical terrain clearance information.

## Features

### 1. Terrain Danger Overlay (Map View)

The terrain danger overlay displays color-coded zones on the map based on your current altitude and terrain clearance:

- **🔴 Critical** (Red): Less than 100ft clearance
- **🟠 Warning** (Orange): 100-500ft clearance  
- **🟡 Caution** (Yellow): 500-1000ft clearance
- **🟢 Safe** (Green): More than 1000ft clearance

#### How to Use:
1. Open the map view
2. Tap the menu button (☰) 
3. Toggle "Terrain" to enable/disable the overlay
4. The overlay updates automatically based on your current altitude

### 2. Terrain Profile Chart (Flight Planning)

The altitude profile chart now includes terrain elevation visualization:

- **Brown gradient fill**: Shows terrain elevation along your route
- **Visual clearance**: Gap between flight altitude line and terrain
- **Automatic scaling**: Chart adjusts to show both terrain and flight altitude

#### How to View:
1. Create or open a flight plan
2. Navigate to the altitude profile section
3. Terrain is automatically displayed if elevation data is available

### 3. Real-time Terrain Warnings

When terrain danger overlay is active and you're flying:

- **Automatic warnings**: Notifications when entering critical terrain zones
- **Visual alerts**: Red warning banner for terrain proximity
- **Audio alerts**: (Future feature) Configurable terrain warning sounds

## Data Sources

### Sonny's LiDAR Data (Europe)
- **Coverage**: Most European countries
- **Resolution**: 1 arc-second (~30m)
- **Accuracy**: Superior in mountainous terrain, forests, valleys
- **Source**: https://sonny.4lima.de/
- **License**: CC BY 4.0

### SRTM Data (Global)
- **Coverage**: Between 60°N and 56°S globally
- **Resolution**: 3 arc-seconds (~90m)
- **Accuracy**: Good for general terrain
- **Source**: NASA/OpenElevation
- **License**: Public Domain

### Data Priority
The system automatically selects the best available data:
1. Sonny's LiDAR (if available for region)
2. SRTM (global fallback)
3. OpenElevation API (online fallback)

## Setup Instructions

### 1. Quick Test Setup

For development and testing with sample data:

```bash
# Install dependencies
flutter pub get

# Setup test elevation data
dart scripts/setup_test_elevation_data.dart setup

# Verify installation
dart scripts/setup_test_elevation_data.dart verify
```

This creates test tiles covering:
- Swiss/Austrian Alps
- French Alps (Mont Blanc)
- Yosemite/Sierra Nevada
- Grand Canyon

### 2. Download Real Elevation Data

#### For European Coverage (Sonny's LiDAR):

```bash
# Download specific countries (example: Austria, Switzerland, Germany)
dart scripts/download_sonny_elevation.dart AT CH DE

# Download all European countries
dart scripts/download_sonny_elevation.dart all
```

Country codes:
- AT: Austria
- CH: Switzerland
- DE: Germany
- FR: France
- IT: Italy
- ES: Spain
- PT: Portugal
- GB: United Kingdom
- And more...

#### For Global Coverage (SRTM):

SRTM data is fetched automatically via OpenElevation API when needed. For offline use, you can pre-download tiles:

1. Visit https://dwtkns.com/srtm30m/
2. Download needed tiles
3. Place .hgt files in `elevation_data/srtm/`

### 3. Directory Structure

```
elevation_data/
├── sonny_lidar/          # High-precision European data
│   ├── at/               # Austria
│   ├── ch/               # Switzerland
│   └── .../              # Other countries
├── srtm/                 # Global SRTM tiles
│   ├── N47E010.hgt       # Individual tile files
│   └── .../
├── srtm_test/            # Test data for development
└── cache/                # Runtime cache
```

## Performance Optimization

### Caching Strategy
- **Memory cache**: Up to 50 tiles kept in memory
- **Disk cache**: Processed tiles stored for quick access
- **Viewport loading**: Only loads data for visible area

### Grid Resolution
The terrain overlay adjusts detail based on zoom:
- **High zoom** (< 0.1°): ~200m grid resolution
- **Medium zoom** (< 0.5°): ~500m grid resolution
- **Low zoom** (< 2.0°): ~1km grid resolution
- **Very low zoom**: ~2km grid resolution

## Configuration

### Settings Location
Settings → Data Sources & Attribution → Terrain Elevation Data

### Adjustable Parameters

In `lib/services/terrain_elevation_service.dart`:

```dart
// Adjust warning thresholds (feet)
TerrainWarningLevel.critical: < 100ft
TerrainWarningLevel.warning: 100-500ft
TerrainWarningLevel.caution: 500-1000ft
TerrainWarningLevel.safe: > 1000ft

// Cache settings
final int _maxCacheSize = 50; // Maximum tiles in memory
```

## Troubleshooting

### No Terrain Data Showing

1. **Check data files exist**:
   ```bash
   ls -la elevation_data/
   ```

2. **Verify file permissions**:
   ```bash
   chmod -R 755 elevation_data/
   ```

3. **Check console for errors**:
   Look for elevation service errors in debug console

### Performance Issues

1. **Reduce grid resolution**: Increase values in `_gridResolution` getter
2. **Decrease cache size**: Lower `_maxCacheSize` value
3. **Disable terrain layer**: Toggle off when not needed

### Incorrect Elevation Values

1. **Verify data source**: Check which source is being used (LiDAR vs SRTM)
2. **Check coordinate system**: Ensure correct lat/lon interpretation
3. **Validate HGT files**: Use verification script

## API Reference

### TerrainElevationService

```dart
// Get elevation at a point
Future<double?> getElevation(LatLng point)

// Get elevation profile along path
Future<List<ElevationPoint>> getElevationProfile(
  List<LatLng> path,
  {double? sampleDistance}
)

// Get terrain clearance
Future<TerrainClearance> getTerrainClearance(
  LatLng position,
  double altitudeFt,
)

// Get danger zones in viewport
Future<List<TerrainDangerZone>> getTerrainDangerZones(
  LatLngBounds viewport,
  double currentAltitudeFt,
  {double gridResolution = 0.01}
)
```

## Future Enhancements

### Planned Features
- [ ] Minimum safe altitude calculation for routes
- [ ] Terrain following suggestions
- [ ] 3D terrain visualization
- [ ] Configurable warning thresholds
- [ ] Audio terrain warnings
- [ ] Terrain database auto-updates
- [ ] Offline tile pre-loading for planned routes

### Data Improvements
- [ ] Integration with more regional high-precision sources
- [ ] Support for 0.5" resolution in critical areas
- [ ] Dynamic data source selection based on flight phase

## Attribution

When using this system, proper attribution is required:

**In-app**: Settings → Data Sources & Attribution

**Documentation**: 
- Elevation data by Sonny (https://sonny.4lima.de) - CC BY 4.0
- SRTM data courtesy of NASA/USGS
- OpenElevation API for online fallback

## Support

For issues or questions about the terrain system:
1. Check this documentation
2. Review the troubleshooting section
3. Report issues on GitHub: https://github.com/QualityUnit/captainvfr/issues

## License

The terrain altitude system code is part of CaptainVFR and follows the project license.
Elevation data sources have their own licenses:
- Sonny's LiDAR: CC BY 4.0
- SRTM: Public Domain
- OpenElevation: Open Source