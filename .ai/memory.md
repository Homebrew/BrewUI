# AI Memory — BrewUI

> Long-term knowledge about this project. Append new entries; do not delete history.
> Format: `## YYYY-MM-DD — Topic`

---

## 2026-03-03 — Project Initialised

- **Project:** BrewUI — Homebrew's official macOS GUI
- **Stage:** Early / scaffolding. Prototype exists in a separate repo and will be migrated.
- **Primary agents in use:** Claude, Cursor. Designed to be agent-agnostic.
- **AI config files created:** `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `CONVENTIONS.md`, `ARCHITECTURE.md`, `.ai/` directory.
- **Key rule:** All agents must read `AGENTS.md` at the start of each session and update `.ai/progress.md` at the end.
- **Next step:** Migrate project-specific context from prototype repo. Update placeholder sections in `CONVENTIONS.md`, `ARCHITECTURE.md`, and this file.

---

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

## 2026-03-27 — Relative doc links rule

- Added `.cursor/rules/doc-relative-links.mdc` to require relative Markdown links for intra-repo doc references (avoid absolute GitHub blob URLs in docs).
