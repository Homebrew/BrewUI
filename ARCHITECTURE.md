# Architecture

BrewUI uses [Clean Architecture](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html) and [MVVM](https://en.wikipedia.org/wiki/Model-view-viewmodel) on the presentation layers.

```text
View → ViewModel → Repository or Interactor → Services → brew CLI or JSON API
```

Views render state and forward actions. ViewModels own presentation state and mapping.
Repositories adapt data sources; Interactors represent individual use cases. Services isolate
external integrations. Domain models remain independent of UI frameworks and transport formats.
Navigation and composition belong in the app shell. Prefer the smallest pattern that solves the
current problem and extend it when real usage warrants it.

## Modules and ownership

| Location | Responsibility |
| --- | --- |
| `Homebrew/` | App entry point, shell, dependency composition and app-only integrations |
| `Sources/BrewCore/` | Domain models, command contracts and shared value types |
| `Sources/BrewCLI/` | Executable discovery, subprocess execution and brew command transport |
| `Sources/BrewNetworking/` | JSON API client and network transport |
| `Sources/BrewRepositoryInterfaces/` | Repository contracts and shared preview support |
| `Sources/BrewRepositories/` | Data access, mapping, inventory and catalogue caches |
| `Sources/BrewAppEnvironment/` | Shared environment dependencies and composition slots |
| `Sources/BrewFeature*/` | Feature views, ViewModels and presentation items |
| `Sources/BrewUIComponents/` | Shared UI, theme tokens and colour assets |
| `Sources/BrewAccessibilityID/`, `Sources/BrewUITestContract/` | Dependency-free contracts shared by the app and UI tests |
| `HomebrewUpgradeHelper/`, `Sources/BrewSelfUpgrade*/` | Self-upgrade executable, contract and testable helper core |
| `Tests/`, `BrewTests/`, `BrewUITests/` | Package, hosted and UI tests |
| `Tools/BrewUILint/` | Project-specific Swift lint rules |

Features do not import sibling features. The shell composes them through shared abstractions,
such as `PackageListBanner` in `BrewAppEnvironment`. Feature `*Root` views acquire app-level
environment dependencies, inject non-optional dependencies into content views and own ViewModel
lifetimes. Content views concentrate on rendering; they do not work around misplaced dependency
acquisition with optional ViewModels.

Feature folders use `Views/` and `ViewModels/`; feature `*Item` types belong in `ViewModels/`.
`Models/` contains domain value types and relationships only. Command JSON, API payloads,
database mappings and cache snapshots stay with their infrastructure boundary.

## Command execution

`BrewCommandCenter` is an actor protocol. `SerialBrewCommandCenter` serialises scheduled work,
coalesces duplicate operation IDs and publishes phase/output streams. Mutating commands go through
this shared pipeline; feature executors remain thin. Repositories own read/parsing work such as
installed inventory. Doctor reads also use the centre so their output appears in the console.

Commands run asynchronously with cancellation and preserved or streamed stdout/stderr. Production
execution, including self-upgrades, uses `ZshBrewCommandRunner` and the
[isolated system zsh environment](#homebrew-configuration). Arguments and environment assignments
travel as literal argv rather than interpolated shell code. Startup markers filter `/etc/zshenv`
output on both streams, including when terminal allocation falls back to pipes; startup failures
retain their diagnostics.

Subprocess cancellation tears down the whole process group and awaits completion before returning.
On Darwin, keep the pseudo-terminal replica open until output draining has finished, including
cancellation and launch failure. Closing it when the child exits can discard unread output.

Show copyable Terminal commands to users and preserve execution output. User-facing command text
omits parsing-only flags such as `--json=v2`. Treat CLI text as unstable: tolerate unknown keys and
format changes rather than assuming a fixed transcript.

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

## Data and storage

- `HomebrewPackageID` is the canonical package identity, including `Identifiable.id` on package-backed
  types. Construct `.formula(name:)` or `.cask(token:)` at transport boundaries. Display names may
  differ from canonical names used in commands and lookups.
- `BrewPackage` contains shared package metadata. `InstalledBrewPackage` adds installed state;
  `DiscoveryBrewPackage` adds analytics. Do not leak installed-only fields into catalogue models.
- Decode transport payloads inside infrastructure boundaries and return domain models or explicit
  feature contracts. Ignore unknown JSON fields, but do not silently default required values.
  Catalogue arrays may skip malformed entries while recording their decode failures; analytics
  decoding rejects malformed required fields and counts.
- The installed repository owns the shared inventory and dependency graph. Refresh after mutations
  while retaining visible data. Keep refresh failures visible until a fetch actually succeeds;
  replaying a cached snapshot must not imply a successful check.
- Catalogue caches own storage and ETags; repositories own freshness, stale-while-revalidate policy
  and in-flight request coalescing. Cold-load failures surface; background failures can retain cached
  data. Discover repositories enrich analytics through catalogue lookups.
- Storage is namespaced as `<root>/sh.brew.app/…`. Rebuildable catalogue and analytics data belong in
  `~/Library/Caches`; transcripts belong in `~/Library/Logs`. Keep these roots separate by
  recoverability. Crash reports are not written by the app: it reads the ones macOS writes to
  `~/Library/Logs/DiagnosticReports` on the next launch and remembers the last one acknowledged.

## Self-upgrades and console

The app's `homebrew-app` cask is excluded from package lists, counts and bulk upgrades, while the raw
inventory retains it for self-upgrade detection. Use Homebrew's `outdated` flag rather than comparing
version strings. Say **upgrade** for installing a newer version; **update** refers to refreshing taps.

The banner coordinates a helper handoff: wait for app exit, upgrade, record the outcome, then relaunch.
Refuse the handoff while a mutating command is running. Resolve the executable and argv before quitting
and pass the contract as a JSON file. If waiting for exit times out, abandon the run. The helper uses
the same command runner as the app and writes `~/Library/Logs/sh.brew.app/self-upgrade.log`.
Consume its outcome from the app's named defaults suite before constructing caches and show success
or failure through one alert. Banner dismissal is per version; the debug banner cannot upgrade an
installed copy of the app.

`BrewCommandJobsRepository` projects command state; `ConsoleViewModel` owns per-window selection.
Console expansion and height use `@SceneStorage`. The console uses a selectable `NSTextView` so
selection spans lines, applies transcript suffix edits to preserve selection and follows output only
while the reader remains at the end. Terminal assembly keeps revisable rows bounded by terminal
height and preserves whether the final line actually ended in a newline.

## Product constraints

- macOS only, using SwiftUI with AppKit bridges when SwiftUI cannot meet a requirement.
- Unsandboxed, with Homebrew installed separately. Detect missing Homebrew and degrade gracefully.
- Default prefixes only: discover `/opt/homebrew/bin/brew` before `/usr/local/bin/brew` through the
  executable locator. No custom prefix or custom-tap management initially.
- Homebrew remains the source of truth. Do not modify its internals or hide operations and errors.
- Preserve keyboard navigation and VoiceOver semantics as well as visible labels.
- One String Catalog per UI target, with English copy as the key. The app follows the macOS language
  and falls back to English for each untranslated string. Non-UI layers carry no copy.
  See [localisation](AGENTS.md#localisation).
