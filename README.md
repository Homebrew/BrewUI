# 🧑‍💻 BrewUI

<img width="1173" height="771" alt="BrewUI user interface" src="https://github.com/user-attachments/assets/4348513d-55b0-4e38-9406-46bf1a4601d3" />

Homebrew's official macOS GUI: making package management approachable for users who prefer graphical interfaces over Terminal, while maintaining complete transparency about underlying Homebrew operations.

## 💡 Motivation

Enable CLI-averse users to safely discover, install, update, and manage Homebrew packages through a native SwiftUI interface that never hides what Homebrew is doing.

## 📲 Tech

- **Swift 6.0** with strict concurrency · **SwiftUI** · **Swift Package Manager**
- **macOS Tahoe 26+**
- Data from the `brew` CLI and the [Homebrew JSON API](https://formulae.brew.sh/docs/api/)

## 📦 Installation

```bash
brew install --cask homebrew-app
```

## 🛠️ Development

After cloning:

```bash
./scripts/bootstrap
```

This installs Mint from `Brewfile`, runs `mint bootstrap` to build the SwiftFormat and SwiftLint versions pinned in `Mintfile`, enables repository git hooks, and resolves Swift package dependencies for `Homebrew.xcodeproj`.

After bootstrap, commits automatically run checks on staged Swift files:

1. `mint run swiftformat`
2. `mint run swiftlint` (with `--fix`, then strict validation)

If unresolved lint violations remain, the commit is blocked and the hook prints specific SwiftLint failures so you can fix and re-commit.

## 🚧 Status

Stable and under active development.

## 📄 Licence

[AGPL-3.0](LICENSE). If you reuse or adapt the source the AGPL terms apply, including the network-use clause.
