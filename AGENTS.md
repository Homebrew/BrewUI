# AGENTS.md
> **For any AI agent, model, or tool working in this repository.**
> Read this file fully before starting any task. It is the authoritative source of rules, workflow expectations, and memory conventions.

---

## Project Overview

**BrewUI** is Homebrew's official macOS GUI — a native macOS application that provides a graphical interface for managing Homebrew packages, casks, and updates.

> ⚠️ This file contains placeholder sections. When project-specific context is migrated from the prototype repo, update the relevant sections and remove this notice.

---

## Core Rules

1. **Read before writing.** Before editing any file, understand its current state and purpose. Check `ARCHITECTURE.md` and relevant ADRs if your change touches structure or design.
2. **Update memory when context changes.** If you learn something important about the project (a decision, a pattern, a constraint), add it to `.ai/memory.md` before ending the session.
3. **Update progress at session end.** Before finishing any work session, update `.ai/progress.md` with what was completed and what remains.
4. **Respect existing conventions.** Consult `CONVENTIONS.md` before introducing new patterns, file structures, or naming schemes.
5. **Document significant decisions.** Any non-obvious architectural or design decision should be captured as an ADR in `docs/adr/`. Use the template at `docs/adr/0000-template.md`.
6. **Do not guess at intent.** If requirements are ambiguous, note the ambiguity in `.ai/scratchpad.md` and surface it to the user rather than making assumptions silently.
7. **Prefer small, focused commits.** Each change should do one thing and have a clear commit message.
8. **Never remove or overwrite memory files.** `.ai/memory.md` and `.ai/progress.md` are append-and-update files. Do not wipe their history.

---

## Memory & Progress System

| File | Purpose | When to update |
|---|---|---|
| `.ai/memory.md` | Long-term project knowledge, decisions, constraints | When you learn something durable about the project |
| `.ai/progress.md` | Current and recent work status | At the end of every work session |
| `.ai/scratchpad.md` | Transient working notes | During a session; contents may be cleared between sessions |

---

## Workflow

1. **Start of session:** Read `.ai/memory.md` and `.ai/progress.md` to orient yourself.
2. **During work:** Use `.ai/scratchpad.md` for working notes. Consult `ARCHITECTURE.md` and `docs/adr/` for context on design decisions.
3. **End of session:** Update `.ai/progress.md`. If anything belongs in long-term memory, update `.ai/memory.md`.

---

## What Lives Where

```
AGENTS.md           ← you are here; rules for all agents
CLAUDE.md           ← Claude-specific extensions (thin)
.cursorrules        ← Cursor-specific extensions (thin)
CONVENTIONS.md      ← code style, naming, patterns
ARCHITECTURE.md     ← high-level system design
docs/adr/           ← architecture decision records
.ai/
  memory.md         ← long-term persistent knowledge
  progress.md       ← current work state
  scratchpad.md     ← ephemeral working notes (gitignored)
```

---

## Out of Scope for Agents

- Do not modify `LICENSE`.
- Do not commit secrets, API keys, or credentials.
- Do not alter ADR files that are marked `Status: Accepted` without creating a superseding ADR.
