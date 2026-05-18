---
name: pr-description-to-scratchpad
description: Generates a pull request description from the current branch diff against its base, formats it using .github/PULL_REQUEST_TEMPLATE.md, and appends the final PR body to .ai/scratchpad.md. Use when the user asks for a PR description, PR body, pull request write-up, or asks to use the PR template/scratchpad workflow.
disable-model-invocation: true
---

# PR Description To Scratchpad

## Purpose

Create a complete PR description using:

- `.github/PULL_REQUEST_TEMPLATE.md` as the structure.
- Branch diff from base (`main...HEAD`) as the source of truth.
- `.ai/scratchpad.md` as the default output location.

## Workflow

1. Determine the current branch and compare scope against `main`.
   - Use:
     - `git rev-parse --abbrev-ref HEAD`
     - `git log --oneline --no-merges main...HEAD`
     - `git diff --stat main...HEAD`
     - `git diff --name-only main...HEAD`

2. Read `.github/PULL_REQUEST_TEMPLATE.md`.

3. Draft the PR body from the template:
   - Fill all major sections (`Summary`, `Changes`, `Testing`, `PR checklist`, AI disclosure).
   - Keep the content grounded in actual branch changes.
   - If tests/checks were run, list exact commands.
   - If unknown, use unchecked checklist items or explicit TODO wording.

4. AI disclosure rule:
   - Assume AI was used for most changes unless the user says otherwise.
   - Include a concise note on manual verification/editing performed.

5. Write output to `.ai/scratchpad.md`:
   - Append under heading: `## PR body (<branch-name> branch)`.
   - Do not overwrite existing scratchpad content.
   - Keep the generated section self-contained and copy-paste ready.

6. Return to the user:
   - Confirm the PR body was appended to `.ai/scratchpad.md`.
   - Provide the same PR body in chat unless the user asks for file-only output.

## Style Constraints

- Be concise, concrete, and reviewer-friendly.
- Do not invent issue links, checks, or behaviors.
- Keep terminology consistent with repository naming.
