+++
date = "2024-12-01"
title = "Weather Visualization"
description = "Color-coded airport markers showing VFR, MVFR, IFR, and LIFR conditions at a glance"
keywords = ["weather visualization", "VFR", "MVFR", "IFR", "LIFR", "flight category", "weather colors", "METAR", "TAF"]
+++

# Weather Visualization

See weather conditions at a glance with color-coded airport markers. CaptainVFR automatically analyzes METAR data and displays flight categories using intuitive colors, helping you make quick go/no-go decisions.

## Flight Category Colors

### 🟢 VFR (Visual Flight Rules)
**Green Markers**

- **Ceiling**: ≥ 3,000 feet AGL
- **Visibility**: ≥ 5 statute miles
- **Conditions**: Excellent for VFR flight
- **Meaning**: Clear skies, good visibility

**Example METAR:**
```
METAR KJFK 121853Z 24008KT 10SM FEW250 22/14 A3012
```

### 🟡 MVFR (Marginal VFR)
**Yellow Markers**

- **Ceiling**: 1,000 - 2,999 feet AGL
- **Visibility**: 3 - 4 statute miles
- **Conditions**: Marginal for VFR
- **Meaning**: Caution advised, monitor weather

**Example METAR:**
```
METAR KJFK 121853Z 24008KT 4SM BKN020 22/14 A3012
```

### 🔴 IFR (Instrument Flight Rules)
**Red Markers**

- **Ceiling**: 500 - 999 feet AGL
- **Visibility**: 1 - 2 statute miles
- **Conditions**: IFR required
- **Meaning**: Not suitable for VFR flight

**Example METAR:**
```
METAR KJFK 121853Z 24008KT 2SM OVC008 22/14 A3012
```

### ⚫ LIFR (Low IFR)
**Black Markers**

- **Ceiling**: < 500 feet AGL
- **Visibility**: < 1 statute mile
- **Conditions**: Low IFR
- **Meaning**: Very poor conditions, extreme caution

**Example METAR:**
```
METAR KJFK 121853Z 24008KT 1/2SM OVC003 22/14 A3012
```

## How It Works

### Automatic METAR Analysis
1. **Data Collection**: Fetches latest METAR for each airport
2. **Parsing**: Analyzes ceiling and visibility
3. **Category Determination**: Applies FAA definitions
4. **Color Assignment**: Updates marker color
5. **Real-Time Updates**: Refreshes periodically

### Intelligent Parsing
- Reads cloud layers (FEW, SCT, BKN, OVC)
- Identifies lowest ceiling
- Parses visibility (SM, meters, fractions)
- Handles special conditions
- Accounts for remarks

## Visual Display

### Airport Markers
- **Color**: Indicates flight category
- **Size**: Based on airport type
- **Border**: Highlights selection
- **Label**: Shows ICAO code

### Map Integration
- Seamless overlay on map
- Zoom-responsive
- Touch to view full METAR
- Tap for detailed weather

### Weather Overlay Toggle
- Quick Action Bar button
- Show/hide all weather
- Persists preference
- Instant update

## Detailed Weather Information

### Tap for Full METAR
```
METAR KJFK 121853Z 24008KT 10SM FEW250 22/14 A3012 RMK AO2
```

**Decoded:**
- **Time**: 1853 Zulu
- **Wind**: 240° at 8 knots
- **Visibility**: 10 statute miles
- **Clouds**: Few at 25,000 feet
- **Temperature**: 22°C
- **Dewpoint**: 14°C
- **Altimeter**: 30.12 inHg

### TAF Forecasts
- Terminal Aerodrome Forecast
- 24-hour outlook
- Trend information
- Change groups
- Probability indicators

## Use Cases

### Pre-Flight Planning

#### Route Weather Check
1. Enable weather overlay
2. Scan route for colors
3. Identify problem areas
4. Plan alternates

#### Destination Weather
- Check destination color
- Review nearby alternates
- Monitor trends
- Make go/no-go decision

### En-Route Monitoring

#### Weather Deterioration
- Watch for color changes
- Yellow → Red: Divert consideration
- Red → Black: Immediate action
- Green → Yellow: Monitor closely

#### Alternate Selection
- Find green airports
- Check distance
- Verify facilities
- Plan diversion route

### Emergency Situations

#### Weather Diversion
1. Enable weather overlay
2. Find nearest green airport
3. Check distance and bearing
4. Declare emergency if needed
5. Navigate to alternate

## Advanced Features

### Weather Age Indicator
- Shows data freshness
- Warns of stale data
- Updates automatically
- Color-coded age

### Trend Analysis
- Improving conditions: ↗️
- Deteriorating conditions: ↘️
- Stable conditions: →
- Rapid changes: ⚠️

### Multiple Data Sources
- Primary: CheckWX API
- Backup: SafeSky
- Fallback: Cached data
- Offline: Last known

## Best Practices

### Pre-Flight
1. Check weather along entire route
2. Identify potential problem areas
3. Note alternate airports
4. Monitor trends

### In-Flight
1. Refresh weather periodically
2. Watch for deteriorating conditions
3. Have alternates ready
4. Don't hesitate to divert

### Decision Making
- **All Green**: Good to go
- **Some Yellow**: Monitor closely
- **Any Red**: Reconsider VFR
- **Any Black**: IFR or divert

## Weather Minimums

### Personal Minimums
Set your own limits:
- Minimum ceiling
- Minimum visibility
- Crosswind limits
- Night restrictions

### Regulatory Minimums
- **VFR Day**: 1,000 ft ceiling, 3 SM visibility
- **VFR Night**: Higher minimums recommended
- **Special VFR**: 1 SM visibility, clear of clouds
- **IFR**: Approach minimums apply

## Integration

### Works With
- **Flight Planning**: Route weather analysis
- **Quick Action Bar**: Toggle weather display
- **Airport Info**: Detailed METAR/TAF
- **Nearest Airport**: Weather-aware search

### Data Sources
- CheckWX API (primary)
- SafeSky (backup)
- NOAA Aviation Weather
- Local weather stations

## Limitations

### Important Notes
- ⚠️ Weather data may be delayed
- ⚠️ Not all airports have METAR
- ⚠️ Conditions can change rapidly
- ⚠️ Use official briefing sources

### Recommendations
- Get official weather briefing
- Check NOTAMs
- Monitor ATIS/AWOS
- Use multiple sources
- Trust your judgment

## Troubleshooting

### No Weather Colors
1. Enable weather overlay
2. Check internet connection
3. Verify data source
4. Refresh manually

### Incorrect Colors
1. Check METAR age
2. Verify parsing
3. Report issues
4. Use backup source

### Missing Airports
- Not all airports report weather
- Small airports may lack METAR
- Use nearby airports
- Check AWOS/ASOS frequencies

---

Weather visualization in CaptainVFR transforms complex METAR data into intuitive color-coded markers, helping you make quick, informed decisions about flight safety. One glance tells you everything you need to know about weather conditions along your route.

**Remember**: Always obtain an official weather briefing before flight. CaptainVFR's weather visualization is a supplementary tool, not a replacement for proper flight planning and weather analysis.
