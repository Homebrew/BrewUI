# BrewUI

Homebrew's official macOS GUI — making package management approachable for users who prefer graphical interfaces over Terminal, while maintaining complete transparency about underlying Homebrew operations.

## Mission

Enable CLI-averse users to safely discover, install, update, and manage Homebrew packages through a native SwiftUI interface that never hides what Homebrew is doing.

## Tech

- **Swift 6.0** with strict concurrency · **SwiftUI** · **Swift Package Manager**
- **macOS Tahoe 26+** (also supports Sequoia 15, Sonoma 14)
- Data from the `brew` CLI and the [Homebrew JSON API](https://formulae.brew.sh/docs/api/)

## Status

Early development — currently building the app foundation (D1). Project rules and architecture live in [`AGENTS.md`](./AGENTS.md) and [`ARCHITECTURE.md`](./ARCHITECTURE.md); durable decisions and constraints are recorded in [`.ai/memory.md`](./.ai/memory.md).

Optional local session tracking (for agents or developers; [`.ai/progress.md`](./.ai/progress.md) is gitignored):

```bash
cp .ai/progress.template.md .ai/progress.md
```

## Quickstart (Development)

After cloning:

```bash
./scripts/bootstrap
```

This installs Mint from `Brewfile`, runs `mint bootstrap` to build the SwiftFormat and SwiftLint versions pinned in `Mintfile`, enables repository git hooks, and resolves Swift package dependencies for `Brew.xcodeproj`.

### Pre-commit formatting and linting

After bootstrap, commits automatically run checks on staged Swift files:

1. `mint run swiftformat`
2. `mint run swiftlint` (with `--fix`, then strict validation)

If unresolved lint violations remain, the commit is blocked and the hook prints specific SwiftLint failures so you can fix and re-commit.

## Contributing

This project will be open source. Contribution guidelines, issue templates, and a getting started guide are coming as part of the initial setup work. In the meantime, see `CONVENTIONS.md` for project conventions and workflow, and `ARCHITECTURE.md` for design detail.
