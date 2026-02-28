---
name: Harness Gap Report
about: Convert a production regression into a harness improvement
title: "[HARNESS GAP] "
labels: harness-gap, quality
assignees: ''
---

## Incident Summary

<!-- What happened in production? Include date, severity, and user impact. -->

## Root Cause

<!-- Why did this happen? What was the underlying defect? -->

## What Should Have Caught It

Which harness layer should have prevented this regression?

- [ ] Pre-commit hooks
- [ ] Risk policy gate
- [ ] CI pipeline (lint / test / build)
- [ ] Review agent
- [ ] Browser evidence
- [ ] Architectural linter (boundary violations)
- [ ] Structural tests (harness smoke)
- [ ] Other: ___

## Proposed Harness Improvement

<!-- What specific check, test, rule, or gate should be added or strengthened? -->

## Affected Critical Paths

<!-- Which paths from harness.config.json are affected? Check all that apply. -->

- [ ] `pubspec.yaml`
- [ ] `pubspec.lock`
- [ ] `package.json`
- [ ] `package-lock.json`
- [ ] `android/build.gradle.kts`
- [ ] `ios/Podfile`
- [ ] `macos/Podfile`
- [ ] `.github/workflows/**`
- [ ] `lib/main.dart`
- [ ] `lib/services/**`
- [ ] `lib/models/**`
- [ ] `lib/screens/**`
- [ ] `lib/widgets/**`
- [ ] `analysis_options.yaml`
- [ ] `build_release.sh`
- [ ] `release_ios.sh`
- [ ] `release_android.sh`
- [ ] None of the above (new critical path needed)

## SLO Target

- [ ] **P0**: Within 24 hours (active production breakage)
- [ ] **P1**: Within 1 week (high-risk gap, could recur)
- [ ] **P2**: Within 1 sprint (medium-risk, workaround exists)
- [ ] **P3**: Next planning cycle (low-risk, defense-in-depth)

## Test Case Specification

Describe the test that would catch this regression going forward:

- **Input / preconditions**: <!-- e.g., "A PR that modifies lib/services/weather_service.dart without updating tests" -->
- **Expected behavior**: <!-- e.g., "CI fails at test step with coverage check" -->
- **Actual behavior**: <!-- e.g., "PR merged without catching the missing test coverage" -->
- **Files to test**: <!-- e.g., "lib/services/weather_service.dart, test/services/weather_service_test.dart" -->

## Evidence

<!-- Links to incident reports, error logs, screenshots, or related PRs/issues. -->

---

> **Process**: After filing this issue, add a priority label (`P0`/`P1`/`P2`/`P3`) and update [docs/harness-gaps.md](../../docs/harness-gaps.md). See the [incident-to-harness loop process](../../docs/harness-gaps.md#process) for next steps.
