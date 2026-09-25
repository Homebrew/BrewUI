# 🧑‍💻 BrewUI

<img width="1336" height="844" alt="BrewUI user interface" src="https://github.com/user-attachments/assets/3969e6b2-3054-4127-be5c-847aa1d98c01" />

Homebrew's official macOS GUI: making package management approachable for users who prefer graphical interfaces over Terminal, while maintaining complete transparency about underlying Homebrew operations.

## 💡 Motivation

Enable CLI-averse users to safely discover, install, update and manage Homebrew packages through a native SwiftUI interface that never hides what Homebrew is doing.

## 📲 Tech

- **Swift** with strict concurrency · **SwiftUI** · **Swift Package Manager**
- Toolchain and macOS requirements: [Package.swift](Package.swift), [.swift-version](.swift-version) and [Xcode project](Homebrew.xcodeproj/project.pbxproj)
- Data from the `brew` CLI and the [Homebrew JSON API](https://formulae.brew.sh/docs/api/)

## 📦 Installation

```bash
brew install --cask homebrew-app
```

## Homebrew configuration

Put Homebrew options in `brew.env` and relaunch BrewUI after changing them. Shell aliases and
exported variables do not configure the app. See [Homebrew configuration](ARCHITECTURE.md#homebrew-configuration).

## 🛠️ Development

After cloning:

```bash
./scripts/bootstrap
```

This installs Mint from `Brewfile`, runs `mint bootstrap` to build the SwiftFormat and SwiftLint versions pinned in `Mintfile`, enables repository git hooks and resolves Swift package dependencies for `Homebrew.xcodeproj`.

After bootstrap, commits automatically run checks on staged Swift files:

1. `mint run swiftformat`
2. `mint run swiftlint` (with `--fix`, then strict validation)

The hook also runs BrewUILint over the production tree. If unresolved lint violations remain, the commit is blocked and the hook prints the failures so you can fix and re-commit.

See [development setup](AGENTS.md#development-setup) for signing configuration, [conventions and testing](AGENTS.md#coding-conventions)
for contributor guidance and [architecture](ARCHITECTURE.md) for system design.

## 🌍 Translations

Translations are community-sourced and a partial one is welcome: any string without a translation
falls back to English. Copy lives in one `Localizable.xcstrings` catalog per UI target, `Homebrew/`
for the window, sidebar and menus, and `Resources/` in `BrewUIComponents` and each `BrewFeature*`
package. Edit a catalog in Xcode. See [localisation](AGENTS.md#localisation) for the reasoning
behind the steps below.

### Adding a language

1. Open `Homebrew/Localizable.xcstrings`, press `+`, pick the language and translate at least one
   string there. macOS only lists a language in the per-app picker under *Applications* in System
   Settings when the app bundle ships it, so a language that exists only in a package catalog never
   loads and `scripts/localize verify` fails. Adding it also records the language in `knownRegions`
   in `Homebrew.xcodeproj`; commit that.
2. Add the language to each package catalog you want to translate and do as much of it as you like.
3. Never leave a translation blank. An empty value renders as empty text rather than falling back to
   English, so delete the entry instead of clearing it. `verify` fails on a blank.
4. Run `scripts/localize verify`, then `scripts/localize status` to see how far the language has got.

### Translating a string

1. Find the catalog that holds it:
   `grep -rl "Run Again" Homebrew/Localizable.xcstrings Sources/*/Resources/Localizable.xcstrings`.
2. Read the comment before translating. It says where the string appears and what each `%@` or
   `%lld` stands for.
3. Keep every format specifier the English has, and number them (`%1$@`, `%2$lld`) if your language
   needs a different order. Nothing checks this for you and a mismatch shows the wrong value at
   runtime.
4. English needs only two plural forms, so the code picks between two keys itself (`1 package` and
   `%lld packages`). A language with more categories varies the `%lld` key by plural
   (*Vary By Plural* in Xcode) and translates `1 package` as well.
5. Mark the string as reviewed once you are happy with it. One left in *Needs Review* still ships,
   so the state is a note to yourself rather than a gate.
6. Run `scripts/localize verify`.

### Changing English copy

The key is the English text, so rewording a string makes a new entry rather than editing one.

1. Change the literal in the Swift source, keeping `bundle: #bundle` and updating the `comment:` if
   the meaning moved.
2. Run `scripts/localize sync`, which an Xcode build does for you. It adds the new key and marks the
   old one `"extractionState" : "stale"`, keeping its translations.
3. Carry each translation over to the new key where the wording still means the same thing. Where it
   does not, leave it behind so the string falls back to English until someone translates it again.
4. Delete the stale entry once its translations have been carried over or discarded. Nothing fails
   while one lingers, but a catalog full of them buries the entries still worth rescuing.
5. Commit the `.xcstrings` changes with the code. CI compares the catalogs against the built sources
   and fails if they have drifted.

## 🚧 Status

Stable and under active development.

The read-only Services tab shows installed formula services, their status and owner. Filter by All,
Running or Stopped and inspect login registration and service/log paths. Starting, stopping and configuring
services remain in Terminal.

## 📄 Licence

[AGPL-3.0](LICENSE). If you reuse or adapt the source the AGPL terms apply, including the network-use clause.
