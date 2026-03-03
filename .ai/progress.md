# Progress — BrewUI

> Current and recent work status. Update at the end of every session.
> Format: `## YYYY-MM-DD — Session summary`

---

## 2026-03-03 — Repository scaffolding

**Completed:**
- Created AI agent configuration layer:
  - `AGENTS.md` — primary rules for all agents
  - `CLAUDE.md` — Claude-specific thin extension
  - `.cursorrules` — Cursor-specific thin extension
  - `CONVENTIONS.md` — code style & patterns (scaffolded, awaiting migration)
  - `ARCHITECTURE.md` — high-level design (scaffolded, awaiting migration)
  - `docs/adr/README.md` and `docs/adr/0000-template.md`
  - `.ai/memory.md`, `.ai/progress.md`, `.ai/scratchpad.md`
  - `.gitignore` updated to exclude `.ai/scratchpad.md`

**In progress / Blocked:**
- Awaiting migration of project-specific context from prototype repo.

**Up next:**
- Once prototype is migrated: populate `CONVENTIONS.md`, `ARCHITECTURE.md`, and `.ai/memory.md` with real project context.
- Create first real ADR(s) based on decisions already made in prototype.
