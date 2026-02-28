#!/bin/bash

# Append NASA Earthdata credentials to ~/.netrc
# This script reads from earthdata_credentials.txt and appends to ~/.netrc

CRED_FILE="$(dirname "$0")/earthdata_credentials.txt"

echo "🔐 Adding NASA Earthdata credentials to ~/.netrc"
echo "================================================"
echo ""

# Check if credentials file exists
if [ ! -f "$CRED_FILE" ]; then
    echo "❌ Error: $CRED_FILE not found!"
    exit 1
fi

# Check if user has replaced the template values
if grep -q "YOUR_USERNAME" "$CRED_FILE" || grep -q "YOUR_PASSWORD" "$CRED_FILE"; then
    echo "❌ Error: Please replace YOUR_USERNAME and YOUR_PASSWORD in:"
    echo "   $CRED_FILE"
    echo ""
    echo "Edit the file and replace with your actual NASA Earthdata credentials."
    exit 1
fi

# Extract the machine block from credentials file
MACHINE_BLOCK=$(grep -A 2 "machine urs.earthdata.nasa.gov" "$CRED_FILE" | grep -v "^#")

if [ -z "$MACHINE_BLOCK" ]; then
    echo "❌ Error: Could not find machine block in credentials file"
    exit 1
fi

# Check if credentials already exist in .netrc
if [ -f ~/.netrc ] && grep -q "urs.earthdata.nasa.gov" ~/.netrc; then
    echo "⚠️  NASA Earthdata entry already exists in ~/.netrc"
    echo ""
    echo "Do you want to replace it? (y/n)"
    read -r response
    if [ "$response" != "y" ]; then
        echo "Cancelled."
        exit 0
    fi
    
    # Remove existing earthdata entry
    cp ~/.netrc ~/.netrc.backup
    sed '/machine urs.earthdata.nasa.gov/,+2d' ~/.netrc.backup > ~/.netrc
    echo "✓ Removed existing entry (backup saved as ~/.netrc.backup)"
fi

# Append credentials to .netrc
echo "" >> ~/.netrc
echo "$MACHINE_BLOCK" >> ~/.netrc

# Set proper permissions
chmod 600 ~/.netrc

echo "✅ Successfully added NASA Earthdata credentials to ~/.netrc"
echo "✅ File permissions set to 600 (secure)"
echo ""

# Verify the credentials were added
if grep -q "urs.earthdata.nasa.gov" ~/.netrc; then
    echo "✓ Verified: NASA Earthdata entry found in ~/.netrc"
    echo ""
    echo "You can now run:"
    echo "  ./scripts/download_srtm_earthdata.sh"
    echo ""
    echo "To download worldwide SRTM elevation data!"
else
    echo "❌ Error: Failed to verify credentials in ~/.netrc"
    exit 1
fi

# Clean up credentials file for security
echo ""
echo "🗑️  For security, would you like to delete $CRED_FILE? (y/n)"
echo "   (The credentials are now safely in ~/.netrc)"
read -r response
if [ "$response" = "y" ]; then
    rm "$CRED_FILE"
    echo "✓ Deleted $CRED_FILE"
fi