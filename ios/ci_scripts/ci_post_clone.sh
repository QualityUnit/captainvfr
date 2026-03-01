#!/bin/sh

# Fail this script if any subcommand fails.
set -e

# The default execution directory of this script is the ci_scripts directory.
cd $CI_PRIMARY_REPOSITORY_PATH # change working directory to the root of your cloned repo.

echo "📱 Setting up Flutter for Xcode Cloud build..."

# Install Flutter using git.
echo "⬇️ Cloning Flutter SDK..."
git clone https://github.com/flutter/flutter.git --depth 1 -b stable $HOME/flutter
export PATH="$PATH:$HOME/flutter/bin"

# Verify Flutter installation
echo "✅ Flutter version:"
flutter --version

# Install Flutter artifacts for iOS
echo "📦 Precaching Flutter artifacts for iOS..."
flutter precache --ios

# Install Flutter dependencies.
echo "📦 Installing Flutter dependencies..."
flutter pub get

# Clean any existing build artifacts
echo "🧹 Cleaning Flutter build..."
flutter clean

# Generate necessary files
echo "🔧 Generating Flutter configuration files..."
flutter build ios --config-only --no-codesign

# Install CocoaPods using Homebrew.
echo "📦 Installing CocoaPods..."
HOMEBREW_NO_AUTO_UPDATE=1 # disable homebrew's automatic updates.
brew install cocoapods

# Clean CocoaPods cache
echo "🧹 Cleaning CocoaPods cache..."
cd ios
pod cache clean --all || true
rm -rf Pods
rm -rf Podfile.lock

# Install CocoaPods dependencies.
echo "📦 Installing CocoaPods dependencies..."
pod install --repo-update

echo "✅ Setup complete! Ready to build."

exit 0
