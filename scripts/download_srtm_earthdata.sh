#!/bin/bash

# Download SRTM tiles using NASA Earthdata credentials from ~/.netrc
# Requires: NASA Earthdata account configured in ~/.netrc

echo "🌍 SRTM Worldwide Download Script"
echo "================================="
echo ""

# Check authentication setup
if [ ! -f ~/.netrc ]; then
    echo "❌ Error: ~/.netrc not found!"
    echo ""
    echo "Please run: ./scripts/setup_earthdata_netrc.sh"
    echo "Or manually create ~/.netrc with:"
    echo ""
    echo "machine urs.earthdata.nasa.gov"
    echo "    login YOUR_USERNAME"
    echo "    password YOUR_PASSWORD"
    echo ""
    exit 1
fi

if ! grep -q "urs.earthdata.nasa.gov" ~/.netrc; then
    echo "❌ NASA Earthdata credentials not found in ~/.netrc"
    echo "Please run: ./scripts/setup_earthdata_netrc.sh"
    exit 1
fi

echo "✅ NASA Earthdata credentials found in ~/.netrc"
echo ""

cd /Users/viktorzeman/work/captainvfr/elevation_data

# Create cookie file for session
COOKIE_FILE=~/.urs_cookies
touch $COOKIE_FILE
chmod 600 $COOKIE_FILE

# Base URL for SRTM GL1 (30m resolution)
BASE_URL="https://e4ftl01.cr.usgs.gov/MEASURES/SRTMGL1.003/2000.02.11"

# Function to download a tile with authentication
download_srtm_tile() {
    local tile=$1
    local filename="${tile}.SRTMGL1.hgt.zip"
    
    # Skip if already exists
    if [ -f "${tile}.hgt" ]; then
        echo "  ✓ ${tile}.hgt exists"
        return 0
    fi
    
    echo -n "  Downloading ${tile}... "
    
    # Download using curl with .netrc authentication
    if curl -s -S -f -n \
            -c $COOKIE_FILE \
            -b $COOKIE_FILE \
            -L \
            -o "${filename}" \
            "${BASE_URL}/${filename}" 2>/dev/null; then
        
        # Extract HGT file from zip
        if unzip -q -o "${filename}" 2>/dev/null; then
            # Remove zip and rename if needed
            rm -f "${filename}"
            if [ -f "${tile}.SRTMGL1.hgt" ]; then
                mv "${tile}.SRTMGL1.hgt" "${tile}.hgt"
            fi
            echo "✓"
            return 0
        else
            rm -f "${filename}"
            echo "✗ (unzip failed)"
            return 1
        fi
    else
        echo "✗ (not available - likely ocean)"
        return 1
    fi
}

# Counter variables
downloaded=0
skipped=0
failed=0
total=0

echo "Starting download of SRTM tiles..."
echo "Coverage: 60°N to 56°S (SRTM coverage area)"
echo ""

# Function to process a region
process_region() {
    local region_name=$1
    local lat_start=$2
    local lat_end=$3
    local lon_start=$4
    local lon_end=$5
    
    echo "📍 $region_name"
    echo "-----------------------------------"
    
    for lat in $(seq $lat_start -1 $lat_end); do
        for lon in $(seq $lon_start 1 $lon_end); do
            # Format tile name
            if [ $lat -ge 0 ]; then
                lat_prefix="N"
                lat_str=$(printf "%02d" $lat)
            else
                lat_prefix="S"
                lat_str=$(printf "%02d" ${lat#-})
            fi
            
            if [ $lon -ge 0 ]; then
                lon_prefix="E"
                lon_str=$(printf "%03d" $lon)
            else
                lon_prefix="W"
                lon_str=$(printf "%03d" ${lon#-})
            fi
            
            tile="${lat_prefix}${lat_str}${lon_prefix}${lon_str}"
            
            ((total++))
            
            if download_srtm_tile "$tile"; then
                if [ -f "${tile}.hgt" ]; then
                    ((downloaded++))
                else
                    ((skipped++))
                fi
            else
                ((failed++))
            fi
            
            # Progress update every 20 tiles
            if [ $((total % 20)) -eq 0 ]; then
                echo "    Progress: Downloaded=$downloaded, Skipped=$skipped, Failed=$failed"
            fi
        done
    done
    echo ""
}

# Download major regions
# Adjust ranges as needed - these cover main populated areas

# Europe (already have good coverage)
process_region "Europe" 60 35 -11 40

# North America
process_region "North America - West" 49 32 -125 -104
process_region "North America - East" 49 25 -104 -66

# Asia
process_region "Asia - East" 50 20 100 145
process_region "Asia - South" 35 5 65 95
process_region "Asia - Middle East" 40 12 26 63

# South America
process_region "South America" 12 -56 -82 -34

# Africa
process_region "Africa" 37 -35 -18 52

# Australia & Oceania
process_region "Australia" -10 -44 112 154
process_region "New Zealand" -34 -47 166 179

echo ""
echo "================================="
echo "📊 Download Complete"
echo "================================="
echo "✅ Downloaded: $downloaded tiles"
echo "⏭️  Skipped: $skipped existing tiles"  
echo "🌊 Ocean/No data: $failed tiles"
echo "📦 Total SRTM tiles: $(ls *.hgt 2>/dev/null | wc -l)"
echo ""

if [ $downloaded -gt 0 ]; then
    echo "✅ Successfully downloaded new SRTM tiles!"
    echo "Next step: Generate TIN bundles with:"
    echo "  dart scripts/generate_5min_elevation_bundles_tin.dart generate"
elif [ $failed -gt $((total / 2)) ]; then
    echo "⚠️  Many downloads failed. Please check:"
    echo "  1. Your NASA Earthdata credentials in ~/.netrc"
    echo "  2. Your internet connection"
    echo ""
    echo "To test your credentials:"
    echo "  curl -n https://urs.earthdata.nasa.gov/api/users/tokens"
fi