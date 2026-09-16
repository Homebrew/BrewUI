# 🧑‍💻 BrewUI

<img width="1336" height="844" alt="BrewUI user interface" src="https://github.com/user-attachments/assets/3969e6b2-3054-4127-be5c-847aa1d98c01" />

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

## Homebrew configuration

BrewUI always launches Homebrew through `/bin/zsh`, including app self-upgrades. It disables
optional user and system shell startup files with `--no-rcs --no-global-rcs` and supplies a clean environment.
`PATH` contains only the directory of the located `brew` executable and its sibling `sbin`, followed by `/usr/bin:/bin`.
Your login shell, shell aliases, exported variables and custom `PATH` do not configure Homebrew in BrewUI.

**Put your Homebrew configuration variables in `brew.env` files.** Homebrew reads these itself:

| Scope | File |
| --- | --- |
| User | `~/.homebrew/brew.env` |
| Installation | `<Homebrew prefix>/etc/homebrew/brew.env` |
| System | `/etc/homebrew/brew.env` |

For example, add this line to `~/.homebrew/brew.env`:

```text
HOMEBREW_NO_ENV_HINTS=1
```

Use literal `NAME=value` lines without `export`, shell expansion or command substitution.
User settings normally override installation settings, which override system settings.
`HOMEBREW_SYSTEM_ENV_TAKES_PRIORITY=1` in the system file makes that file take precedence.
See [Homebrew's environment documentation](https://docs.brew.sh/Manpage#environment).
An `XDG_CONFIG_HOME` exported by your shell is also ignored; use the user file above.

Relaunch BrewUI after changing configuration, then check the Configuration tab. Its report and
Doctor describe Homebrew's environment in the app and may differ from Terminal. BrewUI still
sets output controls for its console and self-upgrade log.

System zsh always reads `/etc/zshenv`, if present; its execution cannot be disabled.
BrewUI clears the environment again afterwards and discards startup output so banners do not
reach Homebrew's reports or the console. If startup fails before Homebrew runs, its diagnostics are retained.
See [zsh's startup-file documentation](https://zsh.sourceforge.io/Doc/Release/Files.html).

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
