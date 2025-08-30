# Captain VFR

Mobile application for VFR pilots to plan their flights, check the weather, and get notified about TFRs.

Website: https://captainvfr.com

Web App: https://captainvfr.com/app/

iOS: https://apps.apple.com/ca/app/captainvfr/id6748603359?uo=2

Android: https://play.google.com/store/apps/details?id=com.captainvfr.captainvfr

MacOs Download: https://captainvfr.com/download/

## Features
- Flight planning
- Weather information (Translation of TAF and METAR to human-readable format)
- Airport information
- TFR notifications
- Flight tracking

## Development

### Regenerating Global Elevation Data

If you need to regenerate the global elevation TIN (Triangulated Irregular Network) data from scratch:

1. **Download source elevation data:**
   ```bash
   dart scripts/download_global_elevation_data.dart all
   ```
   This downloads SRTM data from multiple sources and skips ocean tiles automatically for optimal storage.

2. **Generate optimized TIN bundles:**
   ```bash
   dart scripts/generate_5min_elevation_bundles_tin.dart generate
   ```
   This creates 5-arcminute TIN bundles with 92% interpolation accuracy, skipping ocean areas.

3. **Upload to CDN:**
   ```bash
   aws s3 sync assets/data/tiles/elevation_5min_tin/ s3://captainvfr-assets-eu/assets/data/tiles/elevation_5min_tin/
   ```

**Note:** The elevation system automatically handles missing ocean tiles by returning 0m sea level, so ocean areas don't need to be stored.

## Proof of AI
The code in this repository was written by AI, most of the time at the beginning I have used SWE model from Windsurf and later Sonnet4 from Github Copilot, now I use purely Claude Code.

This is a proof of concept, I will try to improve the code quality and add more features in the future. 
Project was started to document AI development processes in QualityUnit.com company (or AIMingle.cz), but as it is getting traction from pilots, I will continue with development.

It is also a proof, that anyone can build application of this complexity with AI assistance.
