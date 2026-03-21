# PR 2: Project Structure and CI Correctness

## Summary

Builds on PR 1 by moving the project to its intended `Brew` naming and tightening test/build workflows so PR and main-branch validation match the new target/scheme structure.

## Changes

- Migrates project and target naming from `BrewUI` to `Brew` (project, app target, unit/UI test targets, schemes, and related references).
- Adds test-suite-specific plans/schemes to separate unit and UI execution paths (`Brew-Unit`, `Brew-UI`).
- Updates workflow runner/version and signing/test invocation details for CI reliability.
- Refines PR/main test behavior in `.github/workflows/pr_build_test.yml` and `.github/workflows/ui_smoke.yml`.
- Adds/updates signing configuration integration via xcconfig for local development and CI compatibility.

## Why this split

This is mostly mechanical + CI correctness work. Keeping it separate from foundation and governance changes reduces review risk and makes regressions easier to isolate.

## Testing

- [ ] `xcodebuild -resolvePackageDependencies -project Brew.xcodeproj`
- [ ] `xcodebuild test -project Brew.xcodeproj -scheme Brew-Unit -destination "platform=macOS"`
- [ ] `xcodebuild test -project Brew.xcodeproj -scheme Brew-UI -destination "platform=macOS"`
- [ ] Validate workflow behavior:
  - [ ] Unit/build workflow on PR path changes
  - [ ] UI smoke workflow trigger behavior

## PR checklist

- [ ] Have you followed this repository's contribution and workflow guidance?
- [ ] Have you explained what changed and why this should land now?
- [ ] Have you run relevant local checks for the changed scope?
- [ ] Are changes scoped and free of unrelated modifications?

-----

- [ ] AI was used to generate or assist with generating this PR.
- [ ] If yes, describe exactly how AI was used and what manual verification was performed.

-----

## Notes for stacked review

- Base branch: `pr/01-foundation`
- Follow-up PR: `pr/03-governance-policy`
