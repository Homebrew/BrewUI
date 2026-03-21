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
