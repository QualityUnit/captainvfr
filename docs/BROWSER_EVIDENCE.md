# Browser Evidence System

Automated screenshot capture and verification for UI changes in the Flutter web build.

## Overview

The browser evidence system captures visual proof that UI changes work correctly before merging. It runs automatically on PRs that touch UI-related files.

## Components

### 1. Capture Script (`scripts/harness-ui-capture-browser-evidence.ts`)

Captures screenshots of defined UI flows using Playwright.

**Usage:**
```bash
npx tsx scripts/harness-ui-capture-browser-evidence.ts [options]
```

**Options:**
- `--base-url URL` - Base URL of running app (default: http://localhost:8080)
- `--flows FLOWS` - Comma-separated flow names or "all" (default: all)

**Flows:**
- `home` - Landing page (/)
- `map` - Main map view (/app)

### 2. Verification Script (`scripts/harness-ui-verify-browser-evidence.ts`)

Validates captured evidence meets requirements.

**Usage:**
```bash
npx tsx scripts/harness-ui-verify-browser-evidence.ts [options]
```

**Options:**
- `--dir DIR` - Evidence directory (default: .harness/evidence)
- `--max-age-hours HOURS` - Maximum evidence age (default: 1)

**Checks:**
- Manifest exists and is valid JSON
- All required flows captured
- Screenshots exist and are non-empty
- Captured SHA matches current HEAD
- No console errors in flows
- Evidence is fresh (within age threshold)

### 3. GitHub Workflow (`.github/workflows/browser-evidence.yml`)

Automated CI integration that:
1. Builds Flutter web app
2. Starts local web server
3. Captures screenshots
4. Verifies evidence
5. Uploads artifacts
6. Posts summary to PR

**Triggers:** PRs touching:
- `lib/screens/**/*.dart`
- `lib/widgets/**/*.dart`
- `web/**`
- `assets/**`

## Local Development

### Prerequisites

```bash
npm install
npx playwright install chromium
```

### Capture Evidence Locally

1. Build and serve Flutter web:
```bash
flutter build web --release --web-renderer canvaskit
cd build/web
python3 -m http.server 8080
```

2. In another terminal, capture evidence:
```bash
npx tsx scripts/harness-ui-capture-browser-evidence.ts
```

3. Verify evidence:
```bash
npx tsx scripts/harness-ui-verify-browser-evidence.ts
```

### Adding New Flows

Edit `scripts/harness-ui-capture-browser-evidence.ts` and add to the `FLOWS` array:

```typescript
const FLOWS: FlowDefinition[] = [
  { name: 'home', path: '/', waitForSelector: 'body' },
  { name: 'map', path: '/app', waitForSelector: 'canvas' },
  { name: 'new-flow', path: '/new-path', waitForSelector: '.my-selector' },
];
```

## Evidence Manifest

Captured evidence is stored in `.harness/evidence/manifest.json`:

```json
{
  "capturedAt": "2026-02-22T20:00:00.000Z",
  "headSha": "abc123...",
  "captureMode": "puppeteer",
  "flows": [
    {
      "name": "home",
      "entrypoint": "/",
      "screenshot": ".harness/evidence/screenshots/home.png",
      "consoleErrors": [],
      "finalUrl": "http://localhost:8080/",
      "accountIdentity": null,
      "durationMs": 1234
    }
  ]
}
```

## CI Integration

The workflow runs automatically on UI-related PRs. Evidence artifacts are retained for 14 days and can be downloaded from the Actions tab.

## Troubleshooting

**"playwright not installed"**
```bash
npm install -D playwright
npx playwright install chromium
```

**"manifest.json not found"**
Run the capture script first before verification.

**"SHA mismatch"**
Evidence was captured for a different commit. Re-run capture script.

**"Evidence too old"**
Evidence is stale. Re-run capture script.

## Architecture Notes

- Uses Playwright for browser automation (not Puppeteer, despite MCP server name)
- Designed for Flutter web builds (not native mobile)
- Screenshots stored locally, not committed to git
- Evidence directory (`.harness/evidence/`) is gitignored
- SHA discipline ensures evidence matches exact commit under test
