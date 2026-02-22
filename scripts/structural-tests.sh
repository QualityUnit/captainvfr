#!/usr/bin/env bash
# ============================================================================
# Structural Tests — Architectural Boundary Validation
#
# Reads architectural boundaries from harness.config.json and validates that
# import dependencies between lib/ modules respect the declared rules.
#
# Exit 0: all boundaries respected.
# Exit 1: one or more violations found.
# ============================================================================
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
LIB_DIR="${REPO_ROOT}/lib"
CONFIG_FILE="${REPO_ROOT}/harness.config.json"
VIOLATIONS=0

# ============================================================================
# Step 1: Read boundaries from harness.config.json (single source of truth)
# ============================================================================
if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "::error::harness.config.json not found at ${CONFIG_FILE}"
  exit 1
fi

# Extract module names and their allowed imports from the config using Node.js
BOUNDARIES_JSON="$(node -e "
  const config = JSON.parse(require('fs').readFileSync('${CONFIG_FILE}', 'utf8'));
  const b = config.architecturalBoundaries || {};
  const out = {};
  for (const [mod, def] of Object.entries(b)) {
    out[mod] = Array.isArray(def) ? def.join(' ') : (def.allowedImports || []).join(' ');
  }
  console.log(JSON.stringify(out));
")"

# Parse into bash associative array
declare -A ALLOWED
MODULES=()

while IFS='=' read -r key val; do
  ALLOWED["$key"]="$val"
  MODULES+=("$key")
done < <(node -e "
  const b = JSON.parse(process.argv[1]);
  for (const [k, v] of Object.entries(b)) {
    console.log(k + '=' + v);
  }
" "$BOUNDARIES_JSON")

if (( ${#MODULES[@]} == 0 )); then
  echo "::error::No architectural boundaries found in ${CONFIG_FILE}"
  exit 1
fi

# ============================================================================
# Step 2: Scan each module for cross-module imports
# ============================================================================
echo "╔═════════════════════════════════════════════════╗"
echo "║     Architectural Boundary Validation            ║"
echo "╚═════════════════════════════════════════════════╝"
echo ""
echo "Boundaries loaded from: harness.config.json (${#MODULES[@]} modules)"
echo ""

for module in "${MODULES[@]}"; do
  dir="${LIB_DIR}/${module}"
  [[ -d "$dir" ]] || continue

  allowed="${ALLOWED[$module]}"
  module_violations=0

  while IFS= read -r -d '' file; do
    # Find lines containing cross-module imports: import 'package:captainvfr/<target>/...'
    while IFS= read -r line; do
      target=""

      # Extract target module from: import 'package:captainvfr/<module>/...'
      if [[ "$line" =~ import\ +[\'\"](package:captainvfr|\.\.)/([a-z_]+)/ ]]; then
        target="${BASH_REMATCH[2]}"
      fi

      [[ -z "$target" ]] && continue
      [[ "$target" == "$module" ]] && continue

      # Verify target is a known module (skip unknown relative paths)
      is_known=false
      for m in "${MODULES[@]}"; do
        [[ "$target" == "$m" ]] && { is_known=true; break; }
      done
      $is_known || continue

      # Check if the import is in the allowed list
      if [[ " $allowed " != *" $target "* ]]; then
        rel="${file#"$REPO_ROOT"/}"
        echo "::error file=${rel}::${module}/ cannot import from ${target}/ (allowed: ${allowed:-none})"
        ((VIOLATIONS++))
        ((module_violations++))
      fi
    done < <(grep -E "import\s+['\"]" "$file" 2>/dev/null || true)
  done < <(find "$dir" -name '*.dart' -type f -print0)

  if (( module_violations == 0 )); then
    echo "  ✔ ${module}/ → allowed: [${allowed:-none}]"
  else
    echo "  ✘ ${module}/ → ${module_violations} violation(s)"
  fi
done

# ============================================================================
# Step 3: Report results
# ============================================================================
echo ""
if (( VIOLATIONS > 0 )); then
  echo "✘ Found ${VIOLATIONS} architectural boundary violation(s)"
  echo ""
  echo "To fix: either update the import to use an allowed module, or update"
  echo "architecturalBoundaries in harness.config.json if the dependency is intentional."
  exit 1
else
  echo "✔ All architectural boundaries respected (${#MODULES[@]} modules checked)"
fi
