# Risk Policy Gate System

The risk-policy-gate is a preflight CI system that classifies pull requests by risk tier and determines which checks must pass before merge.

## How It Works

Every PR is automatically classified into one of three risk tiers based on which files changed:

### Tier 1 (Low Risk)
- **Files**: Documentation (*.md, docs/), LICENSE, .gitignore, hugo/
- **Required Checks**: lint, harness-smoke
- **Merge Policy**: No approval required, self-merge allowed

### Tier 2 (Medium Risk)
- **Files**: Source code (lib/, test/), scripts, assets, platform code (ios/, android/, macos/)
- **Required Checks**: lint, test, build, harness-smoke
- **Merge Policy**: 1 approval required

### Tier 3 (High Risk)
- **Files**: Dependencies (pubspec.yaml, Podfile), CI config (.github/workflows/), build scripts, security config
- **Required Checks**: lint, test, build, structural-tests, harness-smoke, manual-approval
- **Merge Policy**: 2 approvals required, manual environment approval

## Files

- **scripts/risk-policy-gate.sh** — Main gate script that classifies PRs
- **scripts/structural-tests.sh** — Validates architectural boundaries
- **.github/workflows/risk-policy-gate.yml** — CI workflow that runs the gate
- **harness.config.json** — Configuration defining tier patterns and rules

## Running Locally

Test the risk gate on your current branch:

```bash
bash scripts/risk-policy-gate.sh
```

Test structural boundaries:

```bash
bash scripts/structural-tests.sh
```

## SHA Discipline

The gate enforces SHA discipline — all CI checks run on the exact commit SHA that was reviewed. This prevents time-of-check-time-of-use (TOCTOU) races where code changes between review and merge.

## Docs Drift Detection

When `STRICTNESS=standard` or `strict`, the gate warns or fails if source code changes without corresponding documentation updates. Currently set to `relaxed` (disabled).

## Manual Approval (Tier 3)

Tier 3 PRs require approval of the `tier3-approval` GitHub environment. Configure this in your repository settings:

1. Go to Settings → Environments
2. Create environment: `tier3-approval`
3. Add required reviewers (maintainers)

## Customization

Edit `harness.config.json` to:
- Add/remove files from tier patterns
- Change required checks per tier
- Adjust docs drift rules
- Modify architectural boundaries

## Architecture

The gate follows these principles:

1. **Evidence-Based**: Classifications based on actual file changes, never assumptions
2. **Fail-Fast**: Higher risk = more scrutiny
3. **SHA-Pinned**: All actions use commit SHAs, not version tags (supply-chain security)
4. **Layered Defense**: Multiple independent checks, each with clear purpose
