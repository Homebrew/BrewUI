# PR 1: Foundation and Contributor Baseline

## Summary

Establishes the initial BrewUI repository foundation so contributors can clone, bootstrap, and run consistent formatting/linting checks locally and in CI. This PR intentionally focuses on "first runnable baseline" and contributor ergonomics before structural refactors.

## Changes

- Adds core project docs and governance baseline (`AGENTS.md`, `CLAUDE.md`, `ARCHITECTURE.md`, `CONVENTIONS.md`, README updates).
- Adds initial macOS app scaffold and test targets from Xcode project generation.
- Adds tooling bootstrap and developer dependencies (`Brewfile`, `scripts/bootstrap`).
- Adds repository-managed git hooks and local quality enforcement (`scripts/install-git-hooks`, `scripts/pre-commit`, `.swiftformat`, `.swiftlint.yml`, `.swift-version`).
- Adds initial CI workflow baseline for PR checks and release plumbing (`.github/workflows/*`, `scripts/postinstall`).

## Why this split

This is the minimum independently useful baseline for new contributors: clone -> bootstrap -> build/lint/test with a shared toolchain and conventions.

## Testing

- [ ] `./scripts/bootstrap`
- [ ] `swiftformat --lint .`
- [ ] `swiftlint lint --strict`
- [ ] `xcodebuild -resolvePackageDependencies -project BrewUI.xcodeproj`
- [ ] Verify workflows parse and trigger as expected for changed paths

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

- Base branch: `main`
- Follow-up PR: `pr/02-structure-ci`
