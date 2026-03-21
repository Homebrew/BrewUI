# BrewUI

Homebrew's official macOS GUI — making package management approachable for users who prefer graphical interfaces over Terminal, while maintaining complete transparency about underlying Homebrew operations.

## Mission

Enable CLI-averse users to safely discover, install, update, and manage Homebrew packages through a native SwiftUI interface that never hides what Homebrew is doing.

## Tech

- **Swift 6.0** with strict concurrency · **SwiftUI** · **Swift Package Manager**
- **macOS Tahoe 26+** (also supports Sequoia 15, Sonoma 14)
- Data from the `brew` CLI and the [Homebrew JSON API](https://formulae.brew.sh/docs/api/)

## Status

Early development — currently building the app foundation (D1). Project rules and architecture live in `AGENTS.md` and `ARCHITECTURE.md`; durable decisions and constraints are recorded in `.ai/memory.md`.

Optional local session tracking (for agents or developers; `.ai/progress.md` is gitignored):

```bash
cp .ai/progress.template.md .ai/progress.md
```
