# Architectural Linter for Captain VFR

This directory contains architectural boundary enforcement tools for the Captain VFR Flutter/Dart codebase.

## Overview

The architectural linter enforces dependency direction rules between architectural layers to maintain clean architecture and prevent circular dependencies.

## Detected Layers

The following architectural layers have been identified in the codebase:

- **screens** - UI screens (presentation layer)
- **widgets** - Reusable UI components
- **services** - Business logic and external integrations
- **models** - Data models and domain entities
- **utils** - Utility functions and helpers
- **constants** - Application constants
- **config** - Configuration files
- **adapters** - Data adapters (e.g., for Hive)
- **l10n** - Localization/internationalization (generated)

## Dependency Rules

The default rules follow Flutter best practices:

```
screens     → widgets, services, models, utils, constants, config, l10n
widgets     → models, utils, constants, services, l10n
services    → models, utils, config, adapters, constants
models      → adapters, utils
utils       → constants
constants   → (no dependencies)
config      → constants
adapters    → (no dependencies)
l10n        → (no dependencies)
```

## Usage

### Run the linter

```bash
npx tsx scripts/lint-architecture.ts
```

### Output modes

```bash
# Default: human-readable output with violation details
npx tsx scripts/lint-architecture.ts

# Summary: violation counts per layer pair
npx tsx scripts/lint-architecture.ts --summary

# JSON: machine-readable output for CI integration
npx tsx scripts/lint-architecture.ts --json

# Fix suggestions: show refactoring hints
npx tsx scripts/lint-architecture.ts --fix

# Verbose: show all scanned files
npx tsx scripts/lint-architecture.ts --verbose
```

### Exit codes

- `0` - No violations found
- `1` - Violations found (with details printed)
- `2` - Configuration or runtime error

## Configuration

The linter loads configuration from (in priority order):

1. `scripts/lint-architecture-config.json` (dedicated override)
2. `harness.config.json` → `architecturalBoundaries` (canonical source)
3. Built-in defaults (Flutter best practices)

### Customizing rules

Edit `scripts/lint-architecture-config.json` to customize layer rules:

```json
{
  "srcRoot": "lib",
  "layers": [
    {
      "name": "services",
      "patterns": ["lib/services/**"],
      "canDependOn": ["models", "utils", "config", "adapters", "constants"]
    }
  ],
  "ignorePatterns": [
    "**/*.g.dart",
    "**/*.freezed.dart",
    "**/test/**",
    "**/*_test.dart"
  ],
  "exemptComment": "arch-exempt"
}
```

### Exempting specific imports

Add an inline comment to exempt a single import from checking:

```dart
import '../screens/some_screen.dart'; // arch-exempt: legacy code, will refactor
```

## Current Violations

As of the last run, the codebase has **13 violations** across **7 layer pairs**:

- `widgets → screens`: 4 violations
- `utils → models`: 3 violations
- `services → l10n`: 2 violations
- `services → screens`: 1 violation
- `services → widgets`: 1 violation
- `models → config`: 1 violation
- `utils → config`: 1 violation

### Common fixes

1. **widgets importing screens**: Extract navigation logic to a service or use callbacks
2. **utils importing models**: Move utility functions into the model class or create a shared helper
3. **services importing l10n**: Pass localized strings from the UI layer or use a localization service
4. **models importing config**: Pass configuration values as constructor parameters

## Integration with CI

Add to your CI pipeline:

```yaml
- name: Check architectural boundaries
  run: npx tsx scripts/lint-architecture.ts --json
```

The script will exit with code 1 if violations are found, failing the CI build.

## Performance

The linter is designed to be fast:
- Uses regex-based import extraction (no AST parsing)
- Uses fast-glob for file discovery
- Runs in < 2 seconds on ~1000 files

Current performance: **272 files scanned** across **9 layers**

## Dependencies

- `fast-glob` - Fast file discovery
- `tsx` - TypeScript execution (already in project)

Install dependencies:

```bash
npm install --save-dev fast-glob
```
