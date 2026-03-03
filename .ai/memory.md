# AI Memory — BrewUI

> Long-term knowledge about this project. Append new entries; do not delete history.
> Format: `## YYYY-MM-DD — Topic`

---

## 2026-03-03 — Project Initialised

- **Project:** BrewUI — Homebrew's official macOS GUI
- **Stage:** Early / scaffolding. AI config layer created. Prototype context migrated from separate repo.
- **Primary agents in use:** Claude, Cursor. Designed to be agent-agnostic.
- **AI config files created:** `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `CONVENTIONS.md`, `ARCHITECTURE.md`, `docs/adr/`, `.ai/` directory.
- **Key rule:** All agents must read `AGENTS.md` at the start of each session and update `.ai/progress.md` at the end.

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
