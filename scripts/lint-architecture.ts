#!/usr/bin/env node
/**
 * Architectural Boundary Linter for Dart/Flutter
 *
 * Enforces module dependency direction rules by statically analyzing import
 * statements across the Dart codebase. Rules are loaded from (in priority order):
 *
 *   1. scripts/lint-architecture-config.json  (dedicated override)
 *   2. harness.config.json → architecturalBoundaries  (canonical source)
 *   3. Built-in defaults matching Flutter best practices
 *
 * Uses regex-based import extraction (zero AST dependencies) and fast-glob
 * for file discovery. Designed to run in < 2 s on a ~1 000-file project.
 *
 * Usage:
 *   npx tsx scripts/lint-architecture.ts [options]
 *
 * Options:
 *   --json       Output violations as JSON array
 *   --summary    Output violation counts per layer pair only
 *   --fix        Print refactoring hints for each violation
 *   --verbose    Print every scanned file and its layer assignment
 *
 * Exit codes:
 *   0  No violations
 *   1  One or more violations found
 *   2  Configuration or runtime error
 */

import { readFileSync, existsSync } from 'node:fs';
import { dirname, join, relative, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import fg from 'fast-glob';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface LayerRule {
  /** Layer name matching a directory under srcRoot (e.g. "services"). */
  name: string;
  /** Glob patterns matching files in this layer. */
  patterns: string[];
  /** Layer names this layer is allowed to import from. */
  canDependOn: string[];
}

interface Violation {
  /** File path relative to repo root. */
  file: string;
  /** 1-based line number where the illegal import appears. */
  line: number;
  /** Raw import specifier (e.g. "../models/airport.dart"). */
  importPath: string;
  /** Layer the importing file belongs to. */
  fromLayer: string;
  /** Layer the import target resolves to. */
  toLayer: string;
  /** Human-readable description of the violated rule. */
  rule: string;
}

interface LintResult {
  violations: Violation[];
  filesScanned: number;
  /** Number of source files discovered per layer. */
  layerCounts: Record<string, number>;
}

interface LintConfig {
  layers: LayerRule[];
  ignorePatterns: string[];
  /** Comment token that exempts a line from checking. */
  exemptComment: string;
  /** Directory under repo root containing layer directories (default "lib"). */
  srcRoot: string;
}

// ---------------------------------------------------------------------------
// CLI argument parsing (no deps — just process.argv)
// ---------------------------------------------------------------------------

const args = new Set(process.argv.slice(2));
const FLAG_JSON = args.has('--json');
const FLAG_SUMMARY = args.has('--summary');
const FLAG_FIX = args.has('--fix');
const FLAG_VERBOSE = args.has('--verbose');

// ---------------------------------------------------------------------------
// Repo root discovery
// ---------------------------------------------------------------------------

function findRepoRoot(): string {
  let dir = process.cwd();
  while (dir !== dirname(dir)) {
    if (existsSync(join(dir, 'pubspec.yaml'))) return dir;
    dir = dirname(dir);
  }
  return process.cwd();
}

const REPO_ROOT = findRepoRoot();

// ---------------------------------------------------------------------------
// Configuration loading (three-tier fallback)
// ---------------------------------------------------------------------------

function loadConfig(): LintConfig {
  // --- Priority 1: dedicated config in scripts/ ---
  const overridePath = join(REPO_ROOT, 'scripts', 'lint-architecture-config.json');
  if (existsSync(overridePath)) {
    try {
      const raw = JSON.parse(readFileSync(overridePath, 'utf8'));
      return {
        layers: raw.layers,
        ignorePatterns: raw.ignorePatterns ?? defaultIgnore(),
        exemptComment: raw.exemptComment ?? 'arch-exempt',
        srcRoot: raw.srcRoot ?? 'lib',
      };
    } catch (err) {
      fatal(`Failed to parse ${overridePath}: ${errMsg(err)}`);
    }
  }

  // --- Priority 2: harness.config.json (canonical) ---
  const harnessPath = join(REPO_ROOT, 'harness.config.json');
  if (existsSync(harnessPath)) {
    try {
      const raw = JSON.parse(readFileSync(harnessPath, 'utf8'));
      const boundaries: Record<string, { allowedImports?: string[] }> =
        raw.architecturalBoundaries ?? {};
      const layers: LayerRule[] = Object.entries(boundaries).map(([name, def]) => ({
        name,
        patterns: [`lib/${name}/**`],
        canDependOn: def.allowedImports ?? [],
      }));
      if (layers.length === 0) {
        fatal('harness.config.json has no architecturalBoundaries entries');
      }
      return {
        layers,
        ignorePatterns: defaultIgnore(),
        exemptComment: 'arch-exempt',
        srcRoot: 'lib',
      };
    } catch (err) {
      fatal(`Failed to parse ${harnessPath}: ${errMsg(err)}`);
    }
  }

  // --- Priority 3: built-in defaults (Flutter best practices) ---
  return {
    layers: [
      { name: 'screens', patterns: ['lib/screens/**'], canDependOn: ['widgets', 'services', 'models', 'utils', 'constants', 'config', 'l10n'] },
      { name: 'widgets', patterns: ['lib/widgets/**'], canDependOn: ['models', 'utils', 'constants', 'services', 'l10n'] },
      { name: 'services', patterns: ['lib/services/**'], canDependOn: ['models', 'utils', 'config', 'adapters', 'constants'] },
      { name: 'models', patterns: ['lib/models/**'], canDependOn: ['adapters', 'utils'] },
      { name: 'utils', patterns: ['lib/utils/**'], canDependOn: ['constants'] },
      { name: 'constants', patterns: ['lib/constants/**'], canDependOn: [] },
      { name: 'config', patterns: ['lib/config/**'], canDependOn: ['constants'] },
      { name: 'adapters', patterns: ['lib/adapters/**'], canDependOn: [] },
      { name: 'l10n', patterns: ['lib/l10n/**'], canDependOn: [] },
    ],
    ignorePatterns: defaultIgnore(),
    exemptComment: 'arch-exempt',
    srcRoot: 'lib',
  };
}

function defaultIgnore(): string[] {
  return ['**/*.g.dart', '**/*.freezed.dart', '**/test/**', '**/*_test.dart'];
}

// ---------------------------------------------------------------------------
// Layer resolution
// ---------------------------------------------------------------------------

/**
 * Determine which architectural layer a file belongs to.
 *
 * Matches the first path segment after srcRoot/ against declared layer names.
 * Returns null for files outside all layers (e.g. lib/main.dart).
 */
function resolveFileLayer(filePath: string, layers: LayerRule[], srcRoot: string): string | null {
  for (const layer of layers) {
    if (filePath.startsWith(`${srcRoot}/${layer.name}/`)) return layer.name;
  }
  return null;
}

/**
 * Resolve a relative import specifier to its target layer.
 *
 * Given file="lib/screens/map_screen.dart" and importPath="../services/location_service.dart",
 * joins the file's directory with the import, normalizes the result, and
 * checks which layer the resolved path falls into.
 *
 * Returns null for:
 *   - Non-relative imports (package imports like "package:flutter/material.dart")
 *   - Imports that resolve outside all declared layers
 */
function resolveImportLayer(
  importPath: string,
  importingFile: string,
  layers: LayerRule[],
  srcRoot: string,
): string | null {
  // Skip package imports — only analyze relative imports
  if (!importPath.startsWith('.') && !importPath.startsWith('../')) return null;

  // path.join normalizes ".." segments:
  //   join("lib/screens", "../services/location_service.dart") → "lib/services/location_service.dart"
  const resolved = join(dirname(importingFile), importPath);
  return resolveFileLayer(resolved, layers, srcRoot);
}

// ---------------------------------------------------------------------------
// Import extraction (regex — no AST dependency)
// ---------------------------------------------------------------------------

// Matches Dart import statements:
//   import '../path/file.dart';
//   import 'path/file.dart';
// Captures only relative imports (starting with . or ..)
const RE_IMPORT = /^\s*import\s+['"](\.\.?\/[^'"]+)['"]/;

// Matches Dart export statements (treated same as imports for architecture):
//   export '../path/file.dart';
const RE_EXPORT = /^\s*export\s+['"](\.\.?\/[^'"]+)['"]/;

const IMPORT_REGEXES = [RE_IMPORT, RE_EXPORT];

interface ExtractedImport {
  path: string;
  line: number;
}

/**
 * Extract all relative import specifiers from a Dart source string.
 * Scans line-by-line with two regex patterns — fast and dependency-free.
 */
function extractImports(source: string): ExtractedImport[] {
  const results: ExtractedImport[] = [];
  const lines = source.split('\n');

  for (let i = 0; i < lines.length; i++) {
    const lineText = lines[i];
    for (const re of IMPORT_REGEXES) {
      const match = re.exec(lineText);
      if (match) {
        results.push({ path: match[1], line: i + 1 });
      }
    }
  }

  return results;
}

// ---------------------------------------------------------------------------
// Core lint engine
// ---------------------------------------------------------------------------

async function lint(config: LintConfig): Promise<LintResult> {
  const violations: Violation[] = [];
  const layerCounts: Record<string, number> = {};

  for (const layer of config.layers) {
    layerCounts[layer.name] = 0;
  }

  // Pre-compute allow-set per layer for O(1) lookup
  const allowMap = new Map<string, Set<string>>();
  for (const layer of config.layers) {
    allowMap.set(layer.name, new Set(layer.canDependOn));
  }

  // Set of known layer names for target validation
  const knownLayers = new Set(config.layers.map((l) => l.name));

  // Discover .dart files under each declared layer directory
  const globs = config.layers.map((l) => `${config.srcRoot}/${l.name}/**/*.dart`);

  const files = await fg(globs, {
    cwd: REPO_ROOT,
    ignore: ['node_modules/**', 'build/**', '.dart_tool/**', '.git/**', ...config.ignorePatterns],
    absolute: false,
  });

  for (const file of files) {
    const fromLayer = resolveFileLayer(file, config.layers, config.srcRoot);
    if (!fromLayer) continue;

    layerCounts[fromLayer]++;

    if (FLAG_VERBOSE) {
      process.stderr.write(`  [${fromLayer}] ${file}\n`);
    }

    const absPath = join(REPO_ROOT, file);
    const source = readFileSync(absPath, 'utf8');
    const imports = extractImports(source);
    const lines = source.split('\n');
    const allowed = allowMap.get(fromLayer)!;

    for (const imp of imports) {
      // Check for inline exemption comment
      const lineText = lines[imp.line - 1] ?? '';
      if (lineText.includes(`// ${config.exemptComment}`)) continue;

      const toLayer = resolveImportLayer(imp.path, file, config.layers, config.srcRoot);

      // Skip: external import, unresolved, or same-layer
      if (!toLayer) continue;
      if (toLayer === fromLayer) continue;

      // Skip if the target isn't a known layer
      if (!knownLayers.has(toLayer)) continue;

      if (!allowed.has(toLayer)) {
        const allowedList = [...allowed].sort().join(', ') || 'none';
        violations.push({
          file,
          line: imp.line,
          importPath: imp.path,
          fromLayer,
          toLayer,
          rule: `"${fromLayer}" cannot import from "${toLayer}" (allowed: [${allowedList}])`,
        });
      }
    }
  }

  return { violations, filesScanned: files.length, layerCounts };
}

// ---------------------------------------------------------------------------
// Output formatters
// ---------------------------------------------------------------------------

function printHumanReadable(result: LintResult, config: LintConfig): void {
  const { violations, filesScanned, layerCounts } = result;

  console.log('╔══════════════════════════════════════════════════╗');
  console.log('║   Architectural Boundary Linter (Dart/Flutter)   ║');
  console.log('╚══════════════════════════════════════════════════╝');
  console.log();
  console.log(`Files scanned: ${filesScanned}`);
  console.log(
    `Layers: ${Object.entries(layerCounts)
      .map(([k, v]) => `${k} (${v})`)
      .join(', ')}`,
  );
  console.log();

  if (violations.length === 0) {
    console.log(`✔ All architectural boundaries respected (${config.layers.length} layers checked)`);
    return;
  }

  console.log(`✘ Found ${violations.length} violation(s):\n`);

  for (const v of violations) {
    console.log(`  VIOLATION: ${v.file}:${v.line}`);
    console.log(`    Import: ${v.importPath}`);
    console.log(`    Rule:   ${v.rule}`);
    if (FLAG_FIX) {
      console.log(`    Fix:    ${suggestFix(v, config)}`);
    }
    console.log();
  }

  console.log('To fix: update the import to use an allowed module, or update');
  console.log('architecturalBoundaries in harness.config.json if the dependency is intentional.');
  console.log('To exempt a single line, add: // arch-exempt: <reason>');
}

function printSummary(result: LintResult): void {
  const { violations } = result;
  if (violations.length === 0) {
    console.log('✔ No violations.');
    return;
  }

  // Group by fromLayer → toLayer
  const counts = new Map<string, number>();
  for (const v of violations) {
    const key = `${v.fromLayer} → ${v.toLayer}`;
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }

  console.log(`✘ ${violations.length} violation(s) across ${counts.size} layer pair(s):\n`);
  for (const [pair, count] of [...counts.entries()].sort()) {
    console.log(`  ${pair}: ${count}`);
  }
}

function printJson(result: LintResult): void {
  console.log(JSON.stringify(result.violations, null, 2));
}

// ---------------------------------------------------------------------------
// Fix suggestions
// ---------------------------------------------------------------------------

/**
 * Generate a human-readable refactoring hint for a violation.
 *
 * Strategies suggested (in order of preference):
 *   1. Route through an intermediary layer that both sides can access.
 *   2. Extract shared types/interfaces into the lowest common layer.
 *   3. Widen the boundary rule if the dependency is architecturally sound.
 */
function suggestFix(v: Violation, config: LintConfig): string {
  const fromRule = config.layers.find((l) => l.name === v.fromLayer);
  const toRule = config.layers.find((l) => l.name === v.toLayer);
  if (!fromRule || !toRule) return 'Review the import and update layer rules.';

  // Check if there's an intermediary: a layer that fromLayer CAN depend on
  // and that itself CAN depend on toLayer.
  const intermediaries: string[] = [];
  for (const allowed of fromRule.canDependOn) {
    const intermediary = config.layers.find((l) => l.name === allowed);
    if (intermediary && intermediary.canDependOn.includes(v.toLayer)) {
      intermediaries.push(allowed);
    }
  }

  if (intermediaries.length > 0) {
    return (
      `Route through "${intermediaries[0]}" layer — move the logic that depends on ` +
      `"${v.toLayer}" into ${config.srcRoot}/${intermediaries[0]}/ ` +
      `and import from there instead.`
    );
  }

  const fromAllowedStr = fromRule.canDependOn.join(', ') || 'none';
  return (
    `Either extract shared types into a layer both "${v.fromLayer}" and "${v.toLayer}" ` +
    `can access (e.g. "models" or "utils"), or add "${v.toLayer}" to ` +
    `${v.fromLayer}.canDependOn in harness.config.json ` +
    `(currently: [${fromAllowedStr}]).`
  );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function errMsg(err: unknown): string {
  return err instanceof Error ? err.message : String(err);
}

function fatal(message: string): never {
  console.error(`ERROR: ${message}`);
  process.exit(2);
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

async function main(): Promise<void> {
  const config = loadConfig();

  if (FLAG_VERBOSE) {
    console.error(`Config loaded: ${config.layers.length} layers, srcRoot="${config.srcRoot}"`);
    for (const l of config.layers) {
      console.error(`  ${l.name} → canDependOn: [${l.canDependOn.join(', ')}]`);
    }
    console.error();
  }

  const result = await lint(config);

  if (FLAG_JSON) {
    printJson(result);
  } else if (FLAG_SUMMARY) {
    printSummary(result);
  } else {
    printHumanReadable(result, config);
  }

  process.exit(result.violations.length > 0 ? 1 : 0);
}

main().catch((err) => {
  fatal(errMsg(err));
});
