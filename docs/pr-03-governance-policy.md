# PR 3: Governance and Policy Alignment

## Summary

Finalizes the stack by aligning agent/governance docs and workflow lint policy with Homebrew-style maintenance practices while keeping product/runtime behavior unchanged.

## Changes

- Updates agent instruction set and reduces/modernizes AI config surface (`AGENTS.md`, `CLAUDE.md`, `.cursor/rules/*`, `.ai/*` updates).
- Replaces legacy Cursor rule file usage with scoped rule files.
- Adds policy reminder to verify versioned/scheduled values via web search in contributor guidance.
- Updates actionlint workflow to Homebrew-org-friendly setup and execution pattern.
- Refreshes documentation references to match current workflow and local progress-file policy.

## Why this split

This is policy/process work and should be reviewed independently from app/CI mechanics. Separating it minimizes noise and keeps governance decisions explicit.

## Testing

- [ ] Confirm docs/rules are internally consistent and non-contradictory
- [ ] Validate `.github/workflows/actionlint.yml` syntax and trigger scope
- [ ] Run `actionlint` locally (if available) or verify via CI

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

- Base branch: `pr/02-structure-ci`
- Final PR in stack
