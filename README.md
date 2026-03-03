# BrewUI

Homebrew's official macOS GUI — making package management approachable for users who prefer graphical interfaces over Terminal, while maintaining complete transparency about underlying Homebrew operations.

## Mission

Enable CLI-averse users to safely discover, install, update, and manage Homebrew packages through a native SwiftUI interface that never hides what Homebrew is doing.

## Tech

- **Swift 6.0** with strict concurrency · **SwiftUI** · **Swift Package Manager**
- **macOS Tahoe 26+** (also supports Sequoia 15, Sonoma 14)
- Data from the `brew` CLI and the [Homebrew JSON API](https://formulae.brew.sh/docs/api/)

## Status

Early development — currently building the app foundation (D1). See `.ai/progress.md` for the current deliverable checklist.

## Contributing

This project will be open source. Contribution guidelines, issue templates, and a getting started guide are coming as part of the initial setup work. In the meantime, see `AGENTS.md` for project conventions and workflow, and `ARCHITECTURE.md` for design detail.
