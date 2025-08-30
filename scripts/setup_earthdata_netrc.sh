#!/bin/bash

# Setup NASA Earthdata credentials in .netrc
# This is the standard method for authentication

echo "🔐 NASA Earthdata Authentication Setup"
echo "======================================"
echo ""
echo "This will store your credentials in ~/.netrc"
echo "This is the standard location used by wget and curl"
echo ""

# Check if .netrc already exists
if [ -f ~/.netrc ]; then
    echo "⚠️  ~/.netrc already exists"
    
    # Check if it already has earthdata credentials
    if grep -q "urs.earthdata.nasa.gov" ~/.netrc; then
        echo "✅ NASA Earthdata credentials already configured in ~/.netrc"
        echo ""
        echo "To update credentials, edit ~/.netrc or delete the earthdata section"
        exit 0
    else
        echo "Adding NASA Earthdata credentials to existing .netrc..."
    fi
else
    echo "Creating new ~/.netrc file..."
fi

# Get credentials
echo ""
read -p "Enter your NASA Earthdata username: " username
read -s -p "Enter your NASA Earthdata password: " password
echo ""
echo ""

# Add to .netrc (append if exists)
cat >> ~/.netrc << EOF

machine urs.earthdata.nasa.gov
    login $username
    password $password
    
EOF

# CRITICAL: Set proper permissions (must be 600 or 400)
chmod 600 ~/.netrc

echo "✅ Credentials saved to ~/.netrc with secure permissions (600)"
echo ""
echo "The credentials are stored in:"
echo "  📁 ~/.netrc"
echo ""
echo "This file is used automatically by:"
echo "  • wget with --netrc or -n flag"
echo "  • curl with --netrc or -n flag"
echo "  • Most NASA Earthdata download scripts"
echo ""
echo "Security notes:"
echo "  • File permissions are set to 600 (only you can read/write)"
echo "  • Never commit .netrc to git repositories"
echo "  • The file is in your home directory, not the project"