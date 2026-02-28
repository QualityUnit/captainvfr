## Agent-Generated PR

**Agent**: <!-- agent name and version (e.g., Claude Code, Kiro CLI, remediation-bot) -->
**Trigger**: <!-- what triggered this PR: remediation, feature request, scheduled task -->
**Head SHA**: `<!-- exact commit SHA this PR was generated at -->`

## Summary
<!-- Auto-generated summary describing all changes -->

## Risk Assessment
- **Detected Risk Tier**: <!-- auto-populated by risk-policy-gate -->
- **Critical paths touched**: <!-- list any: pubspec.yaml, pubspec.lock, lib/main.dart, build configs, CI workflows -->
- **Confidence level**: <!-- high/medium/low — how confident the agent is in the changes -->

## Changes Made
<!-- Complete list of every file modified, with brief explanation for each -->
| File | Change Type | Description |
|------|-------------|-------------|
| | added / modified / deleted | |

## Validation Results
| Check | Status | Command |
|-------|--------|---------|
| Analyze | <!-- PASS/FAIL --> | `flutter analyze` |
| Format | <!-- PASS/FAIL --> | `dart format --set-exit-if-changed .` |
| Tests | <!-- PASS/FAIL --> | `flutter test` |
| Build (iOS) | <!-- PASS/FAIL --> | `flutter build ios --no-codesign` |
| Build (Android) | <!-- PASS/FAIL --> | `flutter build apk` |
| Build (Web) | <!-- PASS/FAIL --> | `flutter build web` |

## Review Agent Status
- [ ] Review agent has analyzed this PR
- [ ] No unresolved blocking findings
- [ ] Review SHA matches current HEAD
- **Verdict**: <!-- APPROVE / REQUEST_CHANGES / PENDING -->

## Human Review Required
- [ ] Required for Tier 3 (high-risk) changes
- [ ] Optional but recommended for Tier 2 changes

## Remediation History
<!-- Only applicable if this PR was created by the remediation agent -->
- **Original PR**: #<!-- number -->
- **Remediation attempt**: <!-- 1/2/3 -->
- **Findings fixed**: <!-- count -->
- **Findings skipped**: <!-- count with brief reasons -->
- **Validation after fix**: <!-- all passed / partial — specify which failed -->
