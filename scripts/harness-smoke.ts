#!/usr/bin/env node
import { readFileSync, existsSync, statSync } from 'fs';
import { join } from 'path';

const REPO_ROOT = process.cwd();
let exitCode = 0;

function error(msg: string) {
  console.error(`❌ ${msg}`);
  exitCode = 1;
}

function success(msg: string) {
  console.log(`✔ ${msg}`);
}

function warn(msg: string) {
  console.warn(`⚠ ${msg}`);
}

// Validate harness.config.json schema
try {
  const configPath = join(REPO_ROOT, 'harness.config.json');
  const config = JSON.parse(readFileSync(configPath, 'utf8'));

  const required = ['version', 'riskTiers', 'commands', 'shaDiscipline', 'architecturalBoundaries'];
  const missing = required.filter(k => !(k in config));
  if (missing.length) {
    error(`Missing required keys: ${missing.join(', ')}`);
  }

  for (const tier of ['tier1', 'tier2', 'tier3']) {
    if (!config.riskTiers[tier]) {
      error(`Missing risk tier: ${tier}`);
      continue;
    }
    const t = config.riskTiers[tier];
    if (!t.patterns || !Array.isArray(t.patterns)) {
      error(`${tier} missing patterns array`);
    }
    if (!t.requiredChecks || !Array.isArray(t.requiredChecks)) {
      error(`${tier} missing requiredChecks array`);
    }
  }

  if (typeof config.shaDiscipline?.enabled !== 'boolean') {
    error('shaDiscipline.enabled must be boolean');
  }

  const modules = Object.keys(config.architecturalBoundaries || {});
  if (modules.length === 0) {
    error('architecturalBoundaries must define at least one module');
  }

  if (exitCode === 0) {
    success(`harness.config.json schema valid (${modules.length} modules, 3 tiers)`);
  }

  // Validate commands
  const cmds = config.commands || {};
  for (const [key, cmd] of Object.entries(cmds)) {
    if (cmd) {
      success(`${key}: ${cmd}`);
    } else {
      warn(`${key}: not configured`);
    }
  }
} catch (e) {
  error(`Failed to validate harness.config.json: ${e}`);
}

// Check KIRO.md
const kiroPath = join(REPO_ROOT, 'KIRO.md');
if (!existsSync(kiroPath) || statSync(kiroPath).size === 0) {
  error('KIRO.md is missing or empty');
} else {
  const lines = readFileSync(kiroPath, 'utf8').split('\n').length;
  success(`KIRO.md present (${lines} lines)`);
}

// Check critical project files
const criticalFiles = [
  'pubspec.yaml',
  'analysis_options.yaml',
  'harness.config.json',
  'lib/main.dart'
];

for (const file of criticalFiles) {
  if (!existsSync(join(REPO_ROOT, file))) {
    error(`Missing: ${file}`);
  }
}
if (exitCode === 0) {
  success(`All ${criticalFiles.length} critical files present`);
}

// Check CI workflow files
const workflows = [
  '.github/workflows/ci.yml',
  '.github/workflows/structural-tests.yml',
  '.github/workflows/harness-smoke.yml'
];

for (const workflow of workflows) {
  if (!existsSync(join(REPO_ROOT, workflow))) {
    error(`Missing workflow: ${workflow}`);
  }
}
if (exitCode === 0) {
  success(`All ${workflows.length} workflow files present`);
}

// Check risk-policy-gate script
if (!existsSync(join(REPO_ROOT, 'scripts/risk-policy-gate.sh'))) {
  error('scripts/risk-policy-gate.sh not found');
} else {
  success('Risk policy gate script present');
}

// Check structural-tests script
if (!existsSync(join(REPO_ROOT, 'scripts/structural-tests.sh'))) {
  error('scripts/structural-tests.sh not found');
} else {
  success('Structural tests script present');
}

process.exit(exitCode);
