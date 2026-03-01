# Xcode Cloud CI Scripts

This directory contains scripts that run during Xcode Cloud builds.

## ci_post_clone.sh

This script runs after Xcode Cloud clones the repository and before the build starts.

### What it does:

1. **Installs Flutter SDK** - Clones the stable Flutter SDK
2. **Precaches iOS artifacts** - Downloads necessary Flutter iOS build tools
3. **Installs dependencies** - Runs `flutter pub get` to install Dart packages
4. **Generates configuration** - Runs `flutter build ios --config-only` to generate:
   - `ios/Flutter/Generated.xcconfig` (required by Xcode)
   - `ios/Flutter/flutter_export_environment.sh`
   - Other Flutter-generated files
5. **Installs CocoaPods** - Installs CocoaPods via Homebrew
6. **Installs Pod dependencies** - Runs `pod install` to set up native iOS dependencies

### Why this is needed:

Flutter projects generate several configuration files during the build process that are not committed to git (they're in `.gitignore`). Xcode Cloud needs these files to build the iOS app, so this script generates them before Xcode tries to compile.

### Common issues this fixes:

- ❌ `could not find included file 'Generated.xcconfig' in search paths`
- ❌ `Unable to load contents of file list: 'Pods-Runner-frameworks-Release-input-files.xcfilelist'`
- ❌ Missing Flutter framework errors

### Xcode Cloud Environment Variables:

The script uses these Xcode Cloud environment variables:
- `$CI_PRIMARY_REPOSITORY_PATH` - Path to the cloned repository
- `$HOME` - Home directory for installing Flutter SDK

### Testing locally:

You can test this script locally (though it's designed for Xcode Cloud):

```bash
cd ios/ci_scripts
CI_PRIMARY_REPOSITORY_PATH=../.. ./ci_post_clone.sh
```

### References:

- [Xcode Cloud Documentation](https://developer.apple.com/documentation/xcode/xcode-cloud)
- [Flutter CI/CD Documentation](https://docs.flutter.dev/deployment/cd)
- [Custom Build Scripts for Xcode Cloud](https://developer.apple.com/documentation/xcode/writing-custom-build-scripts)
