# CLAUDE.md
> Claude-specific extensions to `AGENTS.md`. Read `AGENTS.md` first — this file only adds Claude-specific behaviour on top of it.

---

## Memory Tools

When working in Cowork mode or Claude Code, use the todo list tool to track multi-step tasks within a session. This complements (does not replace) `.ai/progress.md`, which is the persistent cross-session record.

## Session Discipline

- At the **start** of a session: read `.ai/memory.md` and `.ai/progress.md`.
- At the **end** of a session: update `.ai/progress.md` and, if anything durable was learned, `.ai/memory.md`.
- Use `.ai/scratchpad.md` freely for working notes.

## Clarification Before Action

If a task is ambiguous or underspecified, ask one focused clarifying question before proceeding — do not make silent assumptions on consequential decisions.

## Code Generation

- Prefer editing existing files over creating new ones unless a new file is clearly needed.
- When creating files, match the conventions in `CONVENTIONS.md` exactly.
- After writing or editing code, briefly summarise what changed and why.

## ADR Creation

When you make or confirm a significant design decision, proactively suggest creating an ADR. Use `docs/adr/0000-template.md` as the template and number it sequentially.
