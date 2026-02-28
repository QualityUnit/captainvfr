#!/usr/bin/env node
/**
 * Browser Evidence Capture for Flutter Web
 *
 * Captures screenshots of UI flows after changes. Designed for Claude agent
 * using Chrome DevTools MCP server or standalone CI execution.
 *
 * Usage:
 *   npx tsx scripts/harness-ui-capture-browser-evidence.ts [--base-url URL] [--flows FLOWS]
 *
 * Options:
 *   --base-url   Base URL (default: http://localhost:8080)
 *   --flows      Comma-separated flow names or "all" (default: all)
 *
 * Exit codes:
 *   0  Success
 *   1  Capture failures
 *   2  Configuration error
 */

import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { execSync } from 'node:child_process';

interface FlowDefinition {
  name: string;
  path: string;
  waitForSelector?: string;
}

interface FlowResult {
  name: string;
  entrypoint: string;
  screenshot: string;
  consoleErrors: string[];
  finalUrl: string;
  accountIdentity: string | null;
  durationMs: number;
}

interface EvidenceManifest {
  capturedAt: string;
  headSha: string;
  captureMode: 'mcp' | 'puppeteer';
  flows: FlowResult[];
}

const FLOWS: FlowDefinition[] = [
  { name: 'home', path: '/', waitForSelector: 'body' },
  { name: 'map', path: '/app', waitForSelector: 'canvas' },
];

function parseArgs(): { baseUrl: string; flows: string[] } {
  const args = process.argv.slice(2);
  let baseUrl = 'http://localhost:8080';
  let flows: string[] = [];

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--base-url' && args[i + 1]) baseUrl = args[++i];
    if (args[i] === '--flows' && args[i + 1]) {
      const flowArg = args[++i];
      flows = flowArg === 'all' ? FLOWS.map((f) => f.name) : flowArg.split(',');
    }
  }

  if (flows.length === 0) flows = FLOWS.map((f) => f.name);
  return { baseUrl, flows };
}

function getHeadSha(): string {
  try {
    return execSync('git rev-parse HEAD', { encoding: 'utf8' }).trim();
  } catch {
    return 'unknown';
  }
}

async function captureWithPuppeteer(
  baseUrl: string,
  flowNames: string[],
  outDir: string
): Promise<FlowResult[]> {
  let chromium: typeof import('playwright').chromium;
  try {
    const pw = await import('playwright');
    chromium = pw.chromium;
  } catch {
    console.error('ERROR: playwright not installed. Run: npm add -D playwright');
    process.exit(2);
  }

  const browser = await chromium.launch({ headless: true });
  const context = await browser.newContext({ viewport: { width: 1280, height: 720 } });
  const page = await context.newPage();

  const consoleErrors: string[] = [];
  page.on('console', (msg) => {
    if (msg.type() === 'error') consoleErrors.push(msg.text());
  });

  const results: FlowResult[] = [];

  for (const flowName of flowNames) {
    const flow = FLOWS.find((f) => f.name === flowName);
    if (!flow) {
      console.error(`  SKIP: unknown flow "${flowName}"`);
      continue;
    }

    const url = baseUrl.replace(/\/$/, '') + flow.path;
    const screenshotPath = join(outDir, 'screenshots', `${flow.name}.png`);
    const start = Date.now();

    try {
      await page.goto(url, { waitUntil: 'networkidle', timeout: 30_000 });
      if (flow.waitForSelector) {
        await page.waitForSelector(flow.waitForSelector, { timeout: 10_000 });
      }
      await page.screenshot({ path: screenshotPath, fullPage: true });

      results.push({
        name: flow.name,
        entrypoint: flow.path,
        screenshot: screenshotPath,
        consoleErrors: [...consoleErrors],
        finalUrl: page.url(),
        accountIdentity: null,
        durationMs: Date.now() - start,
      });

      console.log(`  ✓ ${flow.name} -> ${screenshotPath}`);
      consoleErrors.length = 0;
    } catch (err) {
      console.error(`  ✗ ${flow.name}: ${err instanceof Error ? err.message : String(err)}`);
    }
  }

  await browser.close();
  return results;
}

async function main(): Promise<void> {
  const { baseUrl, flows } = parseArgs();
  const outDir = resolve('.harness/evidence');
  const screenshotDir = join(outDir, 'screenshots');

  if (!existsSync(screenshotDir)) {
    mkdirSync(screenshotDir, { recursive: true });
  }

  console.log(`Capturing ${flows.length} flow(s) from ${baseUrl}...`);

  const results = await captureWithPuppeteer(baseUrl, flows, outDir);

  const manifest: EvidenceManifest = {
    capturedAt: new Date().toISOString(),
    headSha: getHeadSha(),
    captureMode: 'puppeteer',
    flows: results,
  };

  const manifestPath = join(outDir, 'manifest.json');
  writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
  console.log(`\nManifest: ${manifestPath}`);

  const failures = flows.length - results.length;
  if (failures > 0) {
    console.error(`${failures} flow(s) failed`);
    process.exit(1);
  }
}

main().catch((err) => {
  console.error('ERROR: ' + (err instanceof Error ? err.message : String(err)));
  process.exit(2);
});
