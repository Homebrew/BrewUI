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
| `HomebrewAskpassHelper/` | Administrator password prompt for `SUDO_ASKPASS` |
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

Window titles use the unmodified native macOS style without static instructional subtitles.
`MainWindowView.showsContentTopSeparator` controls one full-width boundary above the main content.
It defaults to visible and does not depend on the selected page, scrolling or console expansion.
The divider overlays the content without changing its layout, hit testing or accessibility.
Its contextual system background prevents the translucent split divider from being composited twice.
The background stays within the divider bounds and does not extend into the toolbar safe area.
It changes neither the native separator colour nor the content's alignment.
Ordinary content dividers use the unmodified system appearance.
`PackageDetailSectionDivider` adds no colour overlay.
Native lists and split views retain their separator drawing.
The console retains its existing toolbar divider, split chrome and drag affordance.
SwiftUI hides the window toolbar background, whose automatic boundary otherwise follows scroll content.
This prevents a second line without changing native window properties, titles or controls.
`BrewLayout.paneContentInset` owns the 20-point horizontal content inset across all six pages.
It also sets the gap from the top content boundary to the centre pane's standard first row.
The shared first-row layout shifts the sidebar, pane header and detail content by the same amount.
It preserves their relative alignment without moving the toolbar or the split boundaries.
List content, headings, Configuration and detail content use the same value on both sides.
Thus the list and detail panes have four equal horizontal gutters at the default window size.
The inset list's native 16-point margin stays in place; `brewPaneListRowInsets()` supplies the difference.
Native row and section separators end at the shared content inset.
Content lists share `brewPaneListRowSelection(isSelected:)` for their rounded brand-tint background.
The background has a 10-point inset on each side, matching the filter-to-first-row gap in Upgrades.
The inset does not change row height, content alignment or hit targets.
Native window-title styling remains unchanged; no one-sided compensation moves content toward it.
Structural dividers and trailing scrollbars retain their full-width native layout.
List pages use `PaneHeader` for a count or current state in the existing panel-heading style, followed by filters.
Configuration uses its environment and diagnostics heading in the same position.
Its heading and data share an 880-point content limit, increased by the default window's 80-point
width change. Card insets and the 240-point field-label column remain unchanged.
Other panes retain their 800-point content limit.
The loaded Discover landing keeps Trending and Popular section names.
Its original 30-day ranking explanation sits beside Trending as read-only secondary text.
The original copy and translations remain unchanged.
Search, loading and error states keep their existing subtitle position.
Discover and Doctor share the existing plain pinned-header appearance through
`brewPlainListSectionHeader()` in `BrewUIComponents`.
`DiscoverSectionHeader` retains its existing call sites and appearance.
The modifier keeps native list pinning while suppressing the floating edge.
Native section separators do not read row alignment guides. The modifier covers the excess at each
end without redrawing the system separator or changing row layout.
It derives pinning from native row positions and listens to clip-view bounds notifications.
It observes native floating-state redraws so resizing or collapsing the console does not restore the edge.
The pinned heading and separator ends use tint-aware AppKit window backgrounds.
The pinned background covers scrolled content without a flat colour band in dark appearance.
The bridge restores row appearance on removal and does not replace the list delegate or change selection.
If the native table or scroll notifications are unavailable, it leaves native appearance unchanged.
Installed places its existing dependency filter switch beside the package count; the kind filter
remains below the header.
The default upgrades heading uses “Available” under the Upgrades window title and leaves the
package count to the bulk-action button.
The up-to-date state keeps that heading and the original command block.
Its existing central status carries the success checkmark instead of a second status row in the header.
Doctor and the up-to-date state share the seal checkmark, success colour and 44-point badge size.
The preferred default window width is 1080 points. This fits six languages with a three-digit upgrade count.
SwiftUI sizes a new window to the available display if it is narrower and still restores saved window sizes.
The minimum remains 820 points. The column constraints remain unchanged.
Upgrades, Doctor, Configuration and Services wrap titles beside their action buttons first.
If the horizontal controls do not fit, the controls stack beside the title and align with its first line.
Only a vertical pair of buttons shares the wider button's natural width.
The full group moves below the title only when neither side-by-side layout fits.
Services has one action, so Refresh stays beside the first line until the count and button cannot fit side by side.
Page headings remain available
to VoiceOver without repeating the window title visually. Bulk-upgrade and service-inventory commands
remain expanded. When a command block precedes a list filter, the header leaves 24 points before
the filter. Command blocks next to their own actions do not use this section gap.
Configuration guidance and the verbatim Doctor warning preamble remain in their original
blue callouts above the data. Doctor retains the native window title without an extra toolbar help item.
Doctor keeps all five original status strings as panel headings.
Its severity sections retain the inset separator below the heading, matching Popular sections.
They add neither a full-width floating edge nor a custom divider.
Its last-check time uses the existing subheadline and secondary text tokens.
Doctor uses the independent `PaneHeader` metadata row across the full content width.
Its status wraps in the space left by the native-width actions.
Actions align with the first title line, so neither title wrapping nor the time moves them down.
The inline layout measures the existing heading token without fixing a text height.
Only a column too narrow for the stacked actions and one title line box moves the actions below.
Other `PaneHeader` callers retain their action-stacking behaviour.
`LastUpdatedLabel` accepts presentation tokens; other callers keep its caption defaults.
The status heading and actions share one minimum gap before falling back to a stacked layout.
The first heading aligns its text-box centre with the sidebar's first row, not its text baseline.
A measured `brewBody` reference defines that axis without changing typography.
A fixed-height action slot keeps timestamps from moving the axis.
`brewDetailTopAnchor()` marks the leading logo or severity badge in a detail header.
`brewDetailPaneContent()` aligns that anchor with the heading text box top without rearranging its content.
The layout measures the existing `brewTitle2` line height; buttons do not define the detail start.
The layout clamps top padding at zero so long content never clips above the scroll view.
The detail start stays stable when a narrow header stacks its actions.
UI tests can request light or dark appearance through `BrewUITestingEnvironmentKey.appearance`.
The override applies only to the fixture process. Without a request, the app follows the system.

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

## Administrator authentication

Live brew commands receive `Contents/Helpers/HomebrewAskpassHelper` as `SUDO_ASKPASS`. Homebrew runs
`sudo -A`, and the helper shows an unprivileged prompt: "Homebrew wants to make changes. Enter your
password to allow this." It writes a submitted password to stdout or returns non-zero on cancel. The
prompt lives in the helper and its copy lives in the app string catalog. Sudo validates the password.
The helper refuses to prompt unless its parent is `/usr/bin/sudo`, so another process cannot launch it
to read a password from stdout. Cancelling the brew command also ends an open prompt. When
`/etc/pam.d/sudo_local` or `/etc/pam.d/sudo` has an uncommented `auth sufficient pam_tid.so` line, the runner leaves
`SUDO_ASKPASS` unset so sudo can use Touch ID, because `pam_tid` skips its UI in askpass mode. The
self-upgrade runner sets no askpass, because it runs only after the app has quit and brew is
replacing the bundle that contains the helper.
The app build checks that the helper is present, verifies its signature when signing is enabled and
confirms it can load that copy.

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
- The services repository caches the service inventory for the app lifetime. Services change outside
  the app, so the cache is shown immediately and re-read on each visit and app activation; a failed
  refresh keeps the cached data.

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
