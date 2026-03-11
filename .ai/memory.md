# AI Memory — BrewUI

> Long-term knowledge about this project. Append new entries; do not delete history.
> Format: `## YYYY-MM-DD — Topic`

---

## 2026-03-03 — Project Initialised

- **Project:** BrewUI — Homebrew's official macOS GUI
- **Stage:** Early / scaffolding. AI config layer created. Prototype context migrated from separate repo.
- **Primary agents in use:** Claude, Cursor. Designed to be agent-agnostic.
- **AI config files created:** `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `CONVENTIONS.md`, `ARCHITECTURE.md`, `.ai/` directory.
- **Key rule:** All agents must read `AGENTS.md` at the start of each session and update `.ai/progress.md` at the end.
- **Next step:** Migrate project-specific context from prototype repo. Update placeholder sections in `CONVENTIONS.md`, `ARCHITECTURE.md`, and this file.

## 2026-03-03 — Tech Stack & Architecture Confirmed

- **Language:** Swift 6.0, strict concurrency mode enabled
- **UI:** SwiftUI (pure — AppKit only when SwiftUI cannot meet the requirement)
- **State:** `@Observable` (Swift 5.9+); `async`/`await` throughout
- **Package manager:** Swift Package Manager
- **macOS targets:** Tahoe 26, Sequoia 15, Sonoma 14 — minimum Tahoe 26
- **Data sources:** `brew` CLI subprocess + Homebrew JSON API (formulae.brew.sh)
- **Architecture pattern decided:** Views → ViewModels → Repositories/Interactors → Services → external (brew CLI / JSON API)
- **Repository naming:** protocol = `*Repository`, real impl = `Brew*Repository`, mock = `Mock*Repository`
- **Interactor naming:** protocol = `*Interacting`, impl = `*Interactor`, mock = `Mock*Interactor`
- **Formatter:** `swift-format` (official Swift project tool)
- **Test framework:** Swift Testing (preferred) or XCTest
- **No `try!` or force-unwrap anywhere** — not in production, not in tests. Use `#require`/`XCTUnwrap` in tests.
- **Accessibility identifiers:** single source of truth in `Utilities/AccessibilityIdentifiers.swift`, shared between app and UI test targets

## 2026-03-03 — Additional Decisions

- **Sandboxing:** App is unsandboxed. No entitlements needed for subprocess execution.
- **Homebrew detection:** Check `/opt/homebrew/bin/brew` (Apple Silicon) then `/usr/local/bin/brew` (Intel). Degrade gracefully if neither found.
- **JSON API schema drift:** Handle via optional decoding — never crash on unknown fields.

## 2026-03-11 — Developer Hook Workflow

- **Pre-commit enforcement:** Repository-managed pre-commit hook runs staged Swift files through `swiftformat`, then `swiftlint --fix`, then strict `swiftlint` validation.
- **Bootstrap integration:** `./scripts/bootstrap` installs git hooks automatically via `scripts/install-git-hooks` to minimize manual setup for contributors.

## 2026-03-11 — Lint/Format Baseline Config

- **Pinned Swift version for tooling:** Added root `.swift-version` with `6.2` (aligned to latest installed stable Swift 6.2.4) for deterministic SwiftFormat behavior.
- **Project formatter config:** Added root `.swiftformat` with explicit Swift version and baseline whitespace/line-ending settings.
- **Project linter config:** Added root `.swiftlint.yml` with scoped includes/excludes and practical early-stage defaults for `line_length` and `identifier_name`.

## 2026-03-11 — PR CI Baseline

- **PR checks policy:** Required PR checks are lightweight and path-scoped for fast feedback.
- **Workflow split:** CI is separated into focused workflows (`swift_quality`, `pr_build_test`, `actionlint`, `ui_smoke`) instead of a monolithic pipeline.
- **Optional heavy check:** UI smoke testing is explicitly opt-in via manual `workflow_dispatch` (`ui_smoke.yml`) and is not required by default.

## 2026-03-20 — Decision logging (no ADRs)

- **No `docs/adr/`:** Architecture Decision Records are not used in this repo.
- **Where “why” lives:** Durable decisions, constraints, and rationale go in `.ai/memory.md` (dated entries, append-only history).
- **`ARCHITECTURE.md`:** Describes structure and how pieces fit; add extra explanation only when something is unusual or easy to misread.

## 2026-03-21 — Documentation ownership (ARCHITECTURE vs CONVENTIONS)

- **`ARCHITECTURE.md`** is the single source of truth for system shape, layers, data flow, file/folder layout, tech stack baseline, and where `AccessibilityIdentifiers.swift` lives.
- **`CONVENTIONS.md`** owns naming rules, implementation patterns, and contributor-facing how-to; it should **reference** architecture instead of repeating topology or the stack table.

## 2026-03-21 — PR template stays minimal

- **Do not** add standing checklist items to `.github/PULL_REQUEST_TEMPLATE.md` for doc deduplication (or similar); the template should stay short and not grow indefinitely.
- **Doc duplication:** rely on `Document scope` / ownership matrix in `CONVENTIONS.md`, cross-links in `ARCHITECTURE.md`, and review judgment — not extra PR checkboxes.

## 2026-03-22 — Lightweight ARCHITECTURE / CONVENTIONS

- **`ARCHITECTURE.md` and `CONVENTIONS.md` are intentionally minimal** for the early scaffolding phase; grow them as real code and patterns appear.
- **Product / platform constraints** live under **Constraints & decisions** in `ARCHITECTURE.md` only (not duplicated in `CONVENTIONS.md`).
- **`CONVENTIONS.md`** holds BrewUI-specific naming deltas, tooling pointers, and short implementation notes; generic Swift/SwiftUI guidance defers to Apple docs + SwiftLint/SwiftFormat.
- **Doc deduplication:** use the opening blockquotes and cross-links between the two files; the old standalone “ownership matrix” in `CONVENTIONS.md` was removed in favour of that lighter approach.
