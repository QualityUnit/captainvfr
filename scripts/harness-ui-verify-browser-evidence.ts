#!/usr/bin/env node
/**
 * Browser Evidence Verifier
 *
 * Validates evidence manifest meets requirements.
 *
 * Usage:
 *   npx tsx scripts/harness-ui-verify-browser-evidence.ts [--dir DIR] [--max-age-hours HOURS]
 *
 * Exit codes:
 *   0  All assertions pass
 *   1  Assertions failed
 *   2  Configuration error
 */

import { existsSync, readFileSync, statSync } from 'node:fs';
import { resolve } from 'node:path';
import { execSync } from 'node:child_process';

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
  captureMode: string;
  flows: FlowResult[];
}

function parseArgs(): { dir: string; maxAgeHours: number } {
  const args = process.argv.slice(2);
  let dir = '.harness/evidence';
  let maxAgeHours = 1;

  for (let i = 0; i < args.length; i++) {
    if (args[i] === '--dir' && args[i + 1]) dir = args[++i];
    if (args[i] === '--max-age-hours' && args[i + 1]) maxAgeHours = parseInt(args[++i], 10);
  }

  return { dir: resolve(dir), maxAgeHours };
}

function getHeadSha(): string {
  try {
    return execSync('git rev-parse HEAD', { encoding: 'utf8' }).trim();
  } catch {
    return 'unknown';
  }
}

function main(): void {
  const { dir, maxAgeHours } = parseArgs();
  const manifestPath = resolve(dir, 'manifest.json');

  if (!existsSync(manifestPath)) {
    console.error('ERROR: manifest.json not found at ' + manifestPath);
    console.error('Run: npx tsx scripts/harness-ui-capture-browser-evidence.ts');
    process.exit(2);
  }

  let manifest: EvidenceManifest;
  try {
    manifest = JSON.parse(readFileSync(manifestPath, 'utf8'));
  } catch (err) {
    console.error('ERROR: Failed to parse manifest: ' + (err instanceof Error ? err.message : String(err)));
    process.exit(2);
  }

  let failures = 0;

  // Check SHA match
  const currentSha = getHeadSha();
  if (manifest.headSha !== currentSha) {
    console.error(`  ✗ SHA mismatch: manifest=${manifest.headSha.slice(0, 7)} current=${currentSha.slice(0, 7)}`);
    failures++;
  } else {
    console.log(`  ✓ SHA matches: ${currentSha.slice(0, 7)}`);
  }

  // Check age
  const capturedAt = new Date(manifest.capturedAt);
  const ageMs = Date.now() - capturedAt.getTime();
  const ageHours = ageMs / (1000 * 60 * 60);
  if (ageHours > maxAgeHours) {
    console.error(`  ✗ Evidence too old: ${ageHours.toFixed(1)}h (max: ${maxAgeHours}h)`);
    failures++;
  } else {
    console.log(`  ✓ Evidence age: ${ageHours.toFixed(1)}h`);
  }

  // Check flows
  if (manifest.flows.length === 0) {
    console.error('  ✗ No flows captured');
    failures++;
  }

  for (const flow of manifest.flows) {
    if (!existsSync(flow.screenshot)) {
      console.error(`  ✗ Missing screenshot: ${flow.screenshot}`);
      failures++;
      continue;
    }

    const stat = statSync(flow.screenshot);
    if (stat.size === 0) {
      console.error(`  ✗ Empty screenshot: ${flow.screenshot}`);
      failures++;
      continue;
    }

    if (flow.consoleErrors.length > 0) {
      console.error(`  ✗ Console errors in ${flow.name}: ${flow.consoleErrors.join(', ')}`);
      failures++;
      continue;
    }

    console.log(`  ✓ ${flow.name}: ${flow.screenshot} (${(stat.size / 1024).toFixed(1)}KB)`);
  }

  if (failures > 0) {
    console.error(`\n${failures} assertion(s) failed`);
    process.exit(1);
  }

  console.log(`\nAll ${manifest.flows.length} flow(s) verified`);
}

main();
