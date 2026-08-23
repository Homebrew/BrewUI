# AGENTS.md
> **For any AI agent, model, or tool working in this repository.**
> Read this file fully before starting any task. It is the authoritative source of rules, workflow expectations, and memory conventions.

---

## Always Web-Search Versioned or Scheduled Values

Before using any value that changes on a regular or unpredictable schedule, always perform a web search rather than relying on training knowledge. This includes but is not limited to:

- CI runner tags and OS versions (e.g. `macos-latest`, `macos-26`, `ubuntu-latest`)
- Xcode and Swift toolchain version strings
- GitHub Actions action versions (e.g. `actions/checkout@v4`)
- Homebrew formula versions or tap names
- Apple SDK / deployment target version numbers
- Any third-party dependency version that may have had releases

Training data has a cutoff and will silently be wrong about these. A web search takes seconds; a wrong version can waste hours.

---

## First-time Setup

Run `scripts/bootstrap` before opening the project. It installs tooling, resolves Swift packages, and creates `Configurations/Signing.local.xcconfig` from the committed example file. Open that file and replace `YOUR_TEAM_ID_HERE` with your 10-character Apple Team ID — Xcode resolves signing automatically after that.

`Configurations/Signing.local.xcconfig` is gitignored. Do not commit it.

---

## Project Overview

**BrewUI** is Homebrew's official macOS GUI — a native macOS application that makes Homebrew approachable for users who prefer graphical interfaces over Terminal, while maintaining complete transparency about underlying operations.

**Mission:** Enable CLI-averse users to safely discover, install, update, and manage Homebrew packages through a native SwiftUI interface that never hides what Homebrew is doing.

**Stack:** Swift 6.0 · SwiftUI · Swift Package Manager · macOS Tahoe 26+ (also Sequoia 15, Sonoma 14)

See `ARCHITECTURE.md` for full design detail.

---

## Core Rules

1. **Read before writing.** Before editing any file, understand its current state and purpose. If your change touches structure or design, check `ARCHITECTURE.md` and `.ai/memory.md` for prior decisions and constraints.
2. **Update memory when context changes.** If you learn something important about the project (a decision, a pattern, a constraint), add it to `.ai/memory.md` before ending the session.
3. **Track local progress as needed.** Use local `.ai/progress.md` notes for active session continuity; keep PRs focused on product and project-documentation changes.
4. **Respect existing conventions.** Consult `CONVENTIONS.md` before introducing new patterns, file structures, or naming schemes.
5. **Document significant decisions.** Any non-obvious architectural or design decision should be captured in `.ai/memory.md` (append a dated entry with context and rationale).
6. **Do not guess at intent.** If requirements are ambiguous, note the ambiguity in `.ai/scratchpad.md` and surface it to the user rather than making assumptions silently.
7. **Stay in scope for the current deliverable.** Check active roadmap docs/issues and local progress notes before implementation. Do not implement features from later phases. Each deliverable should be independently useful before the next begins.
8. **Work in small, focused stories.** Each task should be a single user story or feature. After completing one, run the quality gates before starting the next (see Workflow).
9. **Prefer small, focused commits.** Each change should do one thing and have a clear commit message.
10. **Never remove or overwrite durable memory files.** `.ai/memory.md` is append-and-update. Do not wipe its history.

---

## Memory & Progress System

| File | Purpose | When to update |
|---|---|---|
| `.ai/memory.md` | Long-term project knowledge, decisions, constraints | When you learn something durable about the project |
| `.ai/progress.md` (gitignored) | Local per-developer session notes | Optional; update at meaningful milestones |
| `.ai/scratchpad.md` | Transient working notes | During a session; contents may be cleared between sessions |

---

## Workflow

1. **Start of session:** Read `.ai/memory.md`; also read local `.ai/progress.md` if present.
2. **During work:** Use `.ai/scratchpad.md` for working notes. Consult `ARCHITECTURE.md` and `.ai/memory.md` for structure and prior decisions.
3. **After each story/feature:** Run quality gates before marking it complete and moving on:
   - Unit tests pass
   - UI tests pass
   - Manual pre-merge checklist reviewed
   - PR/review ready
4. **End of session:** Update local `.ai/progress.md` if useful for continuity. If anything belongs in long-term shared memory, update `.ai/memory.md`.

### Swift quality (local parity with CI)

When you change Swift sources or anything that affects Swift formatting or linting (`.swiftlint.yml`, `.swiftformat`, `Mintfile`, `Brewfile`, `scripts/pre-commit`, `scripts/bootstrap`), run the same commands as `.github/workflows/swift_quality.yml` from the repo root after `scripts/bootstrap` / `mint bootstrap` (so Mint resolves tools from `Mintfile`):

1. `mint run swiftformat --lint .`
2. `mint run swiftlint lint --strict`
3. BrewUILint (matches CI; first build is slow because it compiles `swift-syntax`):
   - `swift build --package-path Tools/BrewUILint -c release --enable-experimental-prebuilts`
   - `"$(swift build --package-path Tools/BrewUILint -c release --show-bin-path)/BrewUILint" $(find Brew Sources -name '*.swift')`
   - BrewUILint lints `Brew` + `Sources` (the whole production tree, all packages); `Tests` is excluded. It must run over all files in one pass — the `nonisolated`-extension rule needs to see every `nonisolated` type declaration to flag a bad extension on it.
   - Keep `Tools/BrewUILint/.build` between runs; deleting it forces a full rebuild (~2+ minutes).

The pre-commit hook formats and lints **staged** Swift files (SwiftFormat/SwiftLint) and additionally runs **BrewUILint over the whole tree** on every commit; these manual commands validate the whole tree like CI and catch drift in unstaged paths.

### Tests (local parity with CI)

`scripts/test` runs `swift test` for both packages — `BrewKit` (root `Package.swift`) and `BrewUILint` (`Tools/BrewUILint/Package.swift`) — matching what `.github/workflows/pr_build_test.yml` runs in CI.

**Agents must run `scripts/test` and confirm it exits 0 at both of these points:**

1. **Before any `git commit` you make.** Tests are intentionally **not** enforced by the pre-commit git hook (too slow to run on every staged-file commit during interactive work), so the responsibility moves to the agent. If `scripts/test` fails, fix it before committing — do not commit with failures, and do not skip the run.
2. **Before reporting a code-changing turn complete to the user,** when that turn modified Swift sources under `Sources/`, `Tests/`, `Brew/`, or `Tools/BrewUILint/`, *or* changed `Package.swift` / `Package.resolved` / `.github/workflows/pr_build_test.yml`. For turns that only touch docs, YAML unrelated to tests, or other non-Swift files, the run is optional.

If a test failure surfaces a real regression that's out of scope for the current turn, surface it to the user rather than silently skipping it — never paper over a red test with `.disabled` or `--filter` exclusions without flagging.

### Live end-to-end canaries (`scripts/test-e2e`) — never run unasked

`scripts/test-e2e` (test plan `Brew-E2E`, sources in `BrewUITests/E2E/`) runs the app against **real Homebrew and the real network**, and **installs and uninstalls the formula `hello` on the machine it runs on**. CI runs it on an ephemeral runner for every pull request, and it is run by hand before a release. Do not run it to "check the UI tests" — that's `scripts/test-ui`, which is deterministic and touches nothing. See `BrewUITests/E2E/README.md`.

### Dead-code analysis (Periphery)

`.github/workflows/pr_build_test.yml` runs [Periphery](https://github.com/peripheryapp/periphery) (pinned in `Mintfile`) after the Xcode build, reusing that build's index store (`--index-store-path DerivedData/Index.noindex/DataStore --skip-build`) so it adds no second build. It scans the **Xcode project** (config in `.periphery.yml`) so the `Homebrew/` app counts as a consumer of the SwiftPM modules — this reports unused code across the whole program, including dead `public` API, which a package-only scan cannot.

The check is **baseline-gated**: it fails a PR only on dead code **not** already recorded in `.periphery-baseline.json` (via `--strict --baseline`). This grandfathers the existing tail so only newly introduced dead code blocks a merge.

- **Seeding / regenerating the baseline:** it can't be generated in the agent sandbox (needs a working `xcodebuild` app build). If `.periphery-baseline.json` is absent, the CI step writes one and uploads it as the `periphery-baseline` artifact without gating — download it, commit it, and the gate activates. To refresh it intentionally (after a deliberate change to the unused set), regenerate on a machine/CI where the app builds: build `Brew-Unit` with `-derivedDataPath DerivedData`, then `mint run periphery scan --index-store-path DerivedData/Index.noindex/DataStore --skip-build --write-baseline .periphery-baseline.json`.
- **Known-implicit usage is already retained** via `.periphery.yml` (`retain_swift_ui_previews`, `retain_codable_properties`, `retain_assign_only_properties`). For a genuine one-off that Periphery still can't see, annotate the declaration with `// periphery:ignore` (or `// periphery:ignore:all` for a type and its members) rather than widening the baseline.

---

## What Lives Where

```
AGENTS.md           ← you are here; rules for all agents
CLAUDE.md           ← Claude-specific extensions (thin)
.cursor/rules/      ← Cursor-specific rule files (thin, scoped)
CONVENTIONS.md      ← code style, naming, patterns
ARCHITECTURE.md     ← high-level system design (structure; brief context only when unusual)
.ai/
  memory.md         ← long-term persistent knowledge
  progress.md       ← local current work state (gitignored)
  scratchpad.md     ← ephemeral working notes (gitignored)
```

---

## Instruction Precedence

When guidance conflicts, resolve in this order:

1. Explicit user request in the current conversation
2. Nearest nested `AGENTS.md` to the file being edited
3. Root `AGENTS.md`
4. Tool-specific overlays (`CLAUDE.md`, `.cursor/rules/*`)

Use executable checks (CI workflows and git hooks) as the source of truth for mandatory enforcement.

---

## Out of Scope for Agents

- Do not modify `LICENSE`.
- Do not commit secrets, API keys, or credentials.
- Do not contradict `ARCHITECTURE.md` or durable decisions recorded in `.ai/memory.md` without explicitly flagging the conflict.
- Do not implement features from a future deliverable phase while the current one is incomplete.
- Do not hard-code file paths — use `ProcessInfo` or `FileManager` to locate `brew`.
- Do not hide errors from the user — surface them appropriately.
