# Agent Instructions

Read this file before working in the repository. It is the single source of agent guidance.
[`CLAUDE.md`](CLAUDE.md) is a relative symlink to this file.

Project overview, motivation, technology, installation, development and status live in
[`README.md`](README.md). System structure and Homebrew configuration live in [`ARCHITECTURE.md`](ARCHITECTURE.md). Contributor
workflows, coding conventions, testing and the [design system](#design-system) live here. Update the
relevant document when those change. Do not create separate memory logs, progress templates,
tool-specific rule files or a documentation site.

## Working rules

- Read relevant files before editing and preserve user edits and comments. Consult the
  [architecture](ARCHITECTURE.md) and [coding conventions](#coding-conventions)
  before introducing patterns or changing structure.
- Keep diffs small, focused and independently useful. Avoid speculative abstractions and unrelated
  refactoring. Check active issues and the requested deliverable before implementing future work.
- Surface ambiguous requirements and conflicts with documented decisions rather than guessing silently.
- For bugs and regressions, use red-green TDD and change the fewest lines needed.
- Prefer self-documenting code and brief comments for non-obvious behaviour. Code examples should
  compile, include required imports and handle errors unless pseudocode is explicitly requested.
- Use UK spelling without Oxford commas or em dashes, gender-neutral language and one space after
  sentences. Use title case for document titles and sentence case for section headings. Use relative
  Markdown links for repository documentation.
- Keep session notes out of PR diffs. Record current decisions in the relevant documentation section,
  without accumulating a chronological session history.
- Inspect `git diff` and run checks appropriate to the change before reporting completion. Summarise
  what changed, why, validation results and anything not checked.

## Verify changing values

Before choosing or changing a scheduled or versioned value, web-search current authoritative sources.
This includes CI runner tags, OS/SDK deployment targets, Xcode and Swift toolchains, GitHub Actions,
Homebrew formulae/taps and third-party dependencies. Read repository pins before changing them;
do not infer versions from training knowledge.

## Setup and quality gates

Follow [development setup](#development-setup) before opening the project.
CI workflows and git hooks are the source of truth for executable enforcement.

- After changing Swift sources or formatting/lint tooling (`.swiftlint.yml`, `.swiftformat`,
  `Mintfile`, `Brewfile`, `scripts/pre-commit`, `scripts/bootstrap`), run all
  [Swift quality checks](#swift-quality), after bootstrap or `mint bootstrap`.
- Run `scripts/test` and confirm exit status 0 **before every agent-created commit**.
  The pre-commit hook does not run package tests.
- Also run `scripts/test` before reporting completion when changing Swift sources under `Sources/`,
  `Tests/`, `Homebrew/` or `Tools/BrewUILint/`, or changing `Package.swift`,
  `Package.resolved` or `.github/workflows/pr_build_test.yml`. It is optional for other documentation
  and non-Swift changes when no commit is being made.
- For UI changes, run `scripts/test-ui` and review the manual checks in [testing](#testing).
- Never run `scripts/test-e2e` unless explicitly asked. It uses real Homebrew and the network and
  installs and uninstalls `hello`. `scripts/test-ui` is the deterministic suite.
- Fix failing checks before committing. Surface unrelated regressions or environment blockers;
  never hide failures with disabled tests or filter exclusions.

## Pull requests

When asked for a PR description, inspect the branch diff and commits against its base and use
[the PR template](.github/PULL_REQUEST_TEMPLATE.md). Describe the final change, list actual checks
and results and disclose AI assistance accurately. Do not invent issue links or validation.
Return the description in chat unless the user requests a file. Include before and after screenshots
for visible changes; explain when screenshots do not apply. Keep the template short.

## Guardrails

- Do not modify `LICENSE` or commit secrets, credentials or the local signing configuration.
- Keep strict concurrency enabled and use the existing command, repository and presentation boundaries.
- Never invoke real Homebrew in unit tests or deterministic UI tests. Fake the external boundaries.
- Do not widen production symbol visibility just for tests, except initialisers needed for construction.
- Do not hard-code executable paths at call sites. Use `BrewExecutableLocating` and the existing
  `ProcessInfo`/`FileManager` discovery boundary.
- Keep errors visible to users and preserve technical details for diagnosis.
- Keep blank GitHub issues enabled while released apps use the crash-report `issues/new?title=…&body=…`
  route. Changing it requires compatibility with reports from older releases.

## Instruction precedence

1. The user's explicit request in the current conversation.
2. The nearest nested `AGENTS.md` for the edited file.
3. This root `AGENTS.md`.

## Development setup

After cloning, run:

```bash
./scripts/bootstrap
```

This installs tooling from [Brewfile](Brewfile), resolves the tools pinned in [Mintfile](Mintfile),
enables repository git hooks and resolves Swift packages for `Homebrew.xcodeproj`.
It also creates `Configurations/Signing.local.xcconfig` from the committed example.
Replace `YOUR_TEAM_ID_HERE` with your 10-character Apple Team ID before opening the project.
The local signing file is gitignored and must not be committed.

The pre-commit hook formats staged Swift files with SwiftFormat, applies SwiftLint fixes and runs
strict SwiftLint validation. It also runs BrewUILint over the production tree. It only re-stages
fully staged files that the tools changed; if formatting changes a partially staged file, it blocks
so that unstaged work is not accidentally committed. Package tests remain a separate check.

Use [the PR template](.github/PULL_REQUEST_TEMPLATE.md), report actual validation and include before
and after screenshots for visible changes. Keep each commit focused with an imperative subject.

## Coding conventions

Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
[.swiftformat](.swiftformat) and [.swiftlint.yml](.swiftlint.yml) own mechanical style.

### Naming and boundaries

- Repositories: `FormulaRepository`, `BrewFormulaRepository`, `MockFormulaRepository`.
  Interactors: `…Interacting`, `…Interactor`, `Mock…Interactor`. Name ViewModels for their screen/tab.
- Keep strict concurrency enabled. Use `@MainActor` for UI state, actors for shared mutable state and
  `Sendable` contracts across isolation boundaries. Do not share decoder/formatter instances unless
  shared state is required and concurrency-safe.
- Repositories fetch, parse and map source data. Put hard-coded guidance and display-only derived
  strings in presentation layers. Domain models must not acquire UI-facing extensions.
- Keep AppKit bridges in the view layer; ViewModels do not import AppKit.
- Extract repeated call sequences only when they express one shared operation at multiple call sites.
  Name the function for its intent and make component functions private when they have no other callers.
- Prefer Foundation and SwiftUI; justify additional packages in `Package.swift` and lock versions.

### Presentation and errors

- Views bind, render and forward actions. Expose one ViewModel property for each UI decision instead
  of composing multiple raw flags in a view. Unit-test non-trivial derived state.
- Extract co-changing presentation mappings into feature `*Item` types. Keep independently changing
  async operation state on the top-level ViewModel.
- Model async/failable content with a single load-state enum rather than separate loading/data/error
  flags. Preserve existing data during background refreshes where appropriate.
- Prefer view-lifetime `.task` for async reads. ViewModels own mutation tasks that must survive
  navigation away from a view.
- Use typed errors, separate user-facing copy from technical details and preserve the latter for
  diagnostics. Never use force unwraps or `try!`, including in tests; use `#require` or `XCTUnwrap`.
- Render web URLs as tappable `Link` controls that also show the literal URL.
- Use DocC comments for non-obvious APIs and brief inline comments explaining why.

### Previews, theme and accessibility

Use shared [preview support](Sources/BrewRepositoryInterfaces/PreviewSupport/PreviewSupport.swift)
and fixtures in `BrewCoreTestSupport` rather than inline mock repositories. Keep `#Preview` blocks
at the bottom of their view file.

Use the [theme](Sources/BrewUIComponents/Theme/BrewColors.swift) for colours, typography, layout, spacing, radii and
shadows. Extend semantic tokens and matching colour assets instead of introducing raw colours or
magic numbers in views. See the [design system](#design-system).

`AXID` in `BrewAccessibilityID` is the shared source of UI-test identifiers. Attach identifiers with
`.axid(_:)`; do not duplicate literal strings in views or tests. Labels remain separate VoiceOver
semantics. SwiftUI `.searchable` fields cannot carry the custom identifier at the modifier site;
query `app.searchFields` until using a custom field.

## Testing

```bash
scripts/test
scripts/test-ui
```

`scripts/test` runs both Swift packages, BrewKit and BrewUILint, matching CI. `scripts/test-ui`
runs the deterministic `Brew-UI` plan. It opens real windows: keep the screen unlocked and avoid
using the keyboard or mouse during the run. See [troubleshooting UI tests](#test-troubleshooting).
For visible changes, also check keyboard navigation, VoiceOver, light/dark appearance and the relevant
manual workflow. Include actual results and any checks not run in the PR.

Prefer Swift Testing; XCTest is also supported. Test one logical behaviour per test, usually with
one assertion or one equality check on an `Equatable` snapshot. Exercise errors and async paths.
Do not widen symbol visibility to reach implementation details from tests; use production entry
points. Initialisers may be made accessible for isolated construction.

Unit tests fake external boundaries such as `BrewCommandRunning`, `BrewExecutableLocating` and HTTP
responses through `URLProtocol`. Prefer slice tests with real repositories and parsing.
Shared fakes live in `BrewCoreTestSupport` and `BrewServicesTestSupport`. Live factories wire real
process/filesystem access and are not unit-test targets. Drive timeout tests from explicit readiness
signals and injected clocks rather than short wall-clock deadlines.

Deterministic UI tests use a fake executable and HTTP fixtures while exercising real application
layers. The compressed fixture payload travels in the launch environment and is installed inside
the app's own temporary directory. Cache roots and all new defaults-backed state must support
per-run isolation. Missing fixtures must never fall through to real Homebrew. Activate the app and
wait for a foreground window before querying accessibility elements.

The separate [live canaries](#live-end-to-end-canaries) use real Homebrew and mutate `hello`.
They must be requested explicitly when run by an agent.

## Swift quality

After `scripts/bootstrap` or `mint bootstrap`, run from the repository root:

```bash
mint run swiftformat --lint .
mint run swiftlint lint --strict
swift build --package-path Tools/BrewUILint -c release --enable-experimental-prebuilts
BREWUILINT="$(swift build --package-path Tools/BrewUILint -c release --show-bin-path)/BrewUILint"
find Homebrew HomebrewUpgradeHelper Sources -name '*.swift' -print0 | xargs -0 "$BREWUILINT"
```

Run BrewUILint over the whole production tree in one invocation: its `nonisolated` extension rule
needs to see all declarations. Tests are excluded. Keep `Tools/BrewUILint/.build` between runs to
avoid rebuilding SwiftSyntax.

## Dead-code analysis

CI runs [Periphery](https://github.com/peripheryapp/periphery), pinned in `Mintfile`, against the
Xcode project using [.periphery.yml](.periphery.yml). Reusing the app build's index store includes
app consumers of package APIs and avoids an extra build.

The gate uses `--strict --baseline .periphery-baseline.json`, failing only on newly unused code.
When the baseline is absent, CI uploads a `periphery-baseline` artifact without gating; download
and commit it to activate the gate. To intentionally regenerate it, build `Brew-Unit` with
`-derivedDataPath DerivedData` on a machine where the app builds, then run:

```bash
mint run periphery scan --index-store-path DerivedData/Index.noindex/DataStore --skip-build --write-baseline .periphery-baseline.json
```

SwiftUI previews, Codable properties and assign-only properties are already retained by configuration.
For individual implicit uses, prefer `// periphery:ignore` (or `// periphery:ignore:all` for a type)
to broadening the baseline. Agent sandboxes may not support the required Xcode app build.

## Test troubleshooting

Environment and accessibility issues encountered while running `BrewUITests` on real Macs.

### What was actually wrong

1. **Terminal/Xcode lacked Accessibility, Automation and Screen Recording permissions.**
   Running `xcodebuild test` from the command line (rather than Xcode's ⌘U) needs these granted to
   whichever app hosts the shell – otherwise the app under test never gets real focus, and you can't
   screenshot to see why. Not a code problem; a one-time machine setup step
   (System Settings → Privacy & Security).

2. **`XCUIApplication.launch()` can produce a frontmost, menu-bar-populated process with *zero
   windows*.** Confirmed by hand: `open`-launching the built app gets a window immediately;
   `XCUIApplication.launch()` (and a raw `exec`) don't, on this OS build. `BrewApp.activate()` now
   detects `windows.count == 0` after activating and sends the same "reopen" AppleEvent a Dock-icon
   click sends, via `NSWorkspace`. **Watch for:** this targets the running instance whose
   `executableURL` lives under `/DerivedData/` – if the app is ever installed for real at
   `/Applications` on the machine running these tests (it shares the same bundle ID), a naive
   `open -b <bundle id>` will reopen *that* copy and steal focus instead.

3. **Tests leaked app processes across runs.** `BrewUITestCase` now terminates whatever it launched
   in `tearDown()`. Without this, a wedged instance from one test can block the next test's
   `launch()` outright (`Failed to activate application ... current state: Running Background`).

4. **The screen locking mid-run reproduces the exact same symptoms as #2.** macOS won't grant real
   window focus to anything while locked, so a locked screen looks identical to a harness bug.
   If failures suddenly cluster on *every* test with foreground/window errors, check this before
   debugging code.

5. **`List` row text (and `.accessibilityElement(children: .combine)` content) exposes through the
   accessibility *value*, not the *label*, on macOS.** `NSPredicate(format: "label CONTAINS %@")`
   silently never matches console output lines or the console status strip, even though the content
   is genuinely on screen. Confirmed by dumping the live accessibility tree
   (`element.debugDescription`) – `StaticText … value: ==> Fetching ripgrep`, no label at all.
   **Watch for:** any new assertion reading text out of a `List`/`Outline` row or a `.combine`d
   accessibility element should match `label CONTAINS %@ OR value CONTAINS %@`, not `label` alone.

6. **A button below the fold in a scrollable detail pane exists in the tree but never becomes
   `isHittable`.** The Uninstall button sits low enough in the detail pane that the default test
   window height clips it. `exists == true`, `isEnabled == true`, `isHittable == false` – forever,
   not just slow. Fixed with a scroll (`element.scroll(byDeltaX:deltaY:)`) before the tap.
   **Watch for:** any new affordance added near the bottom of a scrollable detail/settings pane.

7. **A project-relative `-derivedDataPath` makes the test runner hang for ~5 minutes before failing
   with "The test runner hung before establishing connection."** Reproduced twice, on two different
   `-only-testing:` scopes, both timing out at the same ~330s mark. The identical run against the
   default `~/Library/Developer/Xcode/DerivedData/...` location passes in seconds. Root cause not
   chased further than that; `scripts/test-ui` and CI both just avoid passing `-derivedDataPath` for
   this scheme. **Watch for:** any future script wired to a custom derived-data path (to reuse a
   build across steps, for instance) needs to be tested end-to-end on a real Mac before trusting it –
   the failure mode gives no clue it's about the path.

8. **`CODE_SIGNING_ALLOWED=NO` leaves the test runner with a signature that no longer matches its
   contents, and macOS calls that "damaged".** The symptom is a Gatekeeper dialog – *"BrewUITests-Runner
   is damaged and can't be opened. You should move it to the Bin."* – followed ~300s later by
   `The test runner hung before establishing connection.` The dialog is the cause; the hang is just
   xcodebuild waiting on a runner macOS refused to start.

   `BrewUITests-Runner.app` is a copy of Xcode's `XCTRunner.app` template, which arrives **already
   signed by Apple** (`codesign -dvv` on a broken one reports `Identifier=com.apple.XCTRunner`). The
   build then inserts our `.xctest` into `Contents/PlugIns` and, with signing disallowed, never
   re-signs – so the retained seal is invalid: `codesign -v --deep --strict` says *"code has no
   resources but signature indicates they must be present"*. Allowing signing with
   `CODE_SIGN_IDENTITY=-` fixes it: the runner is ad-hoc signed as `sh.brew.BrewUITests.xctrunner`
   with a valid seal, and ad-hoc needs no identity, team or profile, so it works on CI too.

   **Watch for:** `scripts/test-ui` and the `ui-test` CI job still pass `CODE_SIGNING_ALLOWED=NO`.
   That is the same latent defect – if the deterministic suite ever starts failing this way, drop
   the flag there as well rather than hunting the hang.

### Debugging gotcha specific to this environment

Running a diagnostic shell command (even a quick `osascript` query) *while* a test is polling
`isHittable` can itself bring Terminal frontmost and cover the app, producing a false failure that
has nothing to do with the code. If a failure only reproduces when you're actively poking at the
Mac alongside the test run, let the run finish completely undisturbed before trusting the result.

### General advice for new tests

- If a new test fails with "app running but not in foreground" or "app running but has no window",
  suspect environment (#1, #2, #4) before suspecting the test.
- If a new text assertion can't find content you can see on screen, check `value` as well as
  `label` before assuming the identifier or content is wrong.
- If a new button/control never becomes hittable despite existing, check whether it's below the
  fold in a scroll view at the default window size.
- Keep runs short while iterating (`-only-testing:` a single test, with a wall-clock budget) – a
  hung launch here doesn't fail fast, it eats the full 60s `BrewUITestTimeout.launch` per attempt.

## Live end-to-end canaries

A small suite that runs the app with **production wiring** against **real Homebrew** and the **real
network**. Everything else in `BrewUITests` stubs the two process boundaries and is deterministic;
this does not.

Run it with `scripts/test-e2e` (test plan `Brew-E2E`). It runs on every pull request as its own job,
separate from the deterministic suite: `scripts/test-ui` (test plan `Brew-UI`) skips these tests by
name, so a live failure never reads as a failure of the fixture-backed suite.

### What it is for

A **contract canary**. If Homebrew changes its JSON shape or CLI output and breaks a feature's happy
path, this suite goes red while the deterministic Tier 2 suite – which is answering from fixtures –
stays green. It is not here to broaden coverage; it is here to notice when the fixtures have started
lying.

Covered: install · uninstall · config · search · navigation · console.

Not covered, on purpose:

- **upgrade** – needs a deterministically outdated installed package, which a live machine cannot be
  guaranteed to have without brittle bottle pinning.
- **doctor** – output is entirely machine-state dependent, so there is no stable happy path.
- **error cases** – all of them belong at Tier 2, where a failure is a fixture rather than an outage.

### It mutates this machine

`InstallUninstallE2ETests` **installs and uninstalls the formula `hello`** (GNU Hello: no
dependencies, pours in seconds). It force-uninstalls it before and after every test, so a run leaves
no residue even if it fails part way.

**`hello` is owned by this suite.** Nothing – no fixture, no other test, no developer setup – may
depend on it being installed. If you need a canary package for something else, pick a different one
and document it here.

Ephemeral CI runners are the intended home for this. On a developer machine it is safe but not
invisible: it will uninstall a `hello` you installed yourself.

### Assertions are shape, not values

Versions, dependency counts and `brew config` values drift constantly, and a canary that fails on a
version bump gets muted within a week. So:

| Flow | What is asserted |
| --- | --- |
| Search | a result row for the package *exists* (catalogue fetched and decoded) |
| Config | a `HOMEBREW_VERSION` / `HOMEBREW_PREFIX` row is *present* (`brew config` still parses) |
| Install / uninstall | presence/absence *transitions*, console streamed non-empty output ending in success |
| Navigation | each screen root loads with real data behind it |

### How state isolation works

Responsibilities are split: **arrange and clean up by shelling out to real brew** (`Brew.run` /
`Brew.forceUninstall`, a `Process` helper that is a fixture actuator and never the code under test);
**act through the app's UI** using the same page objects the stubbed suite uses. A broken arrange then
reads as a fixture failure rather than as a red assertion inside the flow under test.

The app ignores inherited Homebrew variables. [CI](.github/workflows/e2e.yml) writes the
fixture settings to `~/.homebrew/brew.env`. For equivalent manual runs, merge those settings into
your configuration and restore it afterwards. The test harness does not edit your configuration.

### Requirements

- Homebrew installed (`/opt/homebrew/bin/brew` or `/usr/local/bin/brew`) – the suite fails by name in
  `setUp` if it is missing rather than failing slowly on a missing element.
- Network egress to `formulae.brew.sh` and `ghcr.io`.
- The same Accessibility/Automation permissions the deterministic UI suite needs – see
  [troubleshooting UI tests](#test-troubleshooting).

### When it runs

- **On every pull request** via `.github/workflows/e2e.yml`, plus manual dispatch.
- **Before cutting a release**, by hand: `scripts/test-e2e`. That is the moment you most want to know
  brew has not shifted under the app. The release workflow itself is deliberately not wired to it.

The plan runs serially with generous per-test timeouts and retries a failing test twice (three runs
in all), which absorbs a transient network blip.

### When a retry hides something

A retry that turns red into green is exactly how a real contract break gets mistaken for weather, so
a passing run says when it needed one. `scripts/annotate-flaky-tests` reads the result bundle after
every run and names any test that took more than one run to pass – as a `::warning::` annotation on
the GitHub run, and as plain text locally. It never fails a run by itself.

The evidence lives in the result bundle: `BrewUITestCase.record(_:)` attaches a screenshot of the
whole screen to every failure. Both it and the plan use the `keepAlways` lifetime, because the
interesting screenshot belongs to a failed *attempt* of a test that ultimately passed, and
`deleteOnSuccess` prunes exactly that. The job uploads the bundle when the run fails **and**
when a test only passed on a retry, so that screenshot is not thrown away with the green run.

## Design system

> Theme implementations and colour assets are authoritative: [BrewUIComponents](Sources/BrewUIComponents/Theme/BrewColors.swift).
> Derived from the [brew.sh](https://brew.sh) visual identity.
> Adapted for a native macOS SwiftUI application in light and dark modes.

---

### 1. Design principles

| Principle | Description |
|---|---|
| **Faithful to Homebrew** | Amber/golden brand colour, dark surfaces, monospaced code – carry the brew.sh identity into the app. |
| **macOS-native first** | Respect HIG conventions: vibrancy, semantic roles, system fonts as the base. |
| **Progressive disclosure** | Hierarchy through colour weight and surface depth, not decoration. |
| **Terminal roots** | Code blocks and command output retain a terminal-like aesthetic as a first-class element. |
| **System accent + brand layer** | Standard system controls (checkboxes, toggles, focus rings) use the user's chosen system accent colour via SwiftUI's `.tint()`. Homebrew amber is applied only to fully custom BrewUI components where `.tint()` would not apply. See Section 5 for the explicit boundary. |

---

### 2. Brand palette (source colours)

These are the raw named colours extracted from the brew.sh visual identity. They are the foundation from which semantic tokens below are derived. Do not use these directly in components – use the semantic tokens in Section 4.

```text
Amber 500    #FBB040   // Primary brand – beer amber, Homebrew logo
Amber 400    #FCC96B   // Lighter amber for highlights / hover
Amber 600    #E8971C   // Deeper amber for pressed states; amber foreground in dark mode
Amber 700    #98620F   // Darkest amber – amber foreground on light surfaces (AA)
Amber 100    #FEF3DC   // Very pale amber – light mode tinted surface

Hops Dark    #1A1A1A   // Near-black background (brew.sh page bg)
Hops 900     #222222   // Slightly lifted dark surface
Hops 800     #2D2D2D   // Card / sidebar dark surface
Hops 700     #3A3A3A   // Elevated surface / popover dark
Hops 600     #4A4A4A   // Border / divider dark
Hops 300     #A8A8A8   // Tertiary text / placeholder dark (AA on every dark surface)
Hops 150     #C7C7C7   // Secondary text dark
Hops 100     #D4D4D4   // Quaternary text dark

Cellar White  #F5F5F0  // Warm off-white (light mode base – avoids stark pure white)
Cellar 50     #FAFAF7  // Lightest surface (elevated card in light)
Cellar 100    #EFEFEA  // Standard surface light
Cellar 200    #E2E2DC  // Grouped / recessed surface light
Cellar 500    #65655F  // Tertiary text light (AA on every light surface)
Cellar 700    #4A4A46  // Secondary text light
Cellar 900    #1A1A18  // Primary text light (warm near-black)

Green OK      #297C4E   // Success / installed (light) – #52C98A in dark
Red Error     #CD312C   // Error / destructive (light) – #EE918E in dark
Amber Warn    #9B600D   // Warning text (light) – #F5C26B in dark
Yellow Warn   #F0AD4E   // Warning icons, dots and fills (light) – #F5C26B in dark
Blue Info     #2D71AE   // Informational / link (light) – #7AB3E0 in dark
```

---

### 3. Typography

#### 3.1 Type scale

The brew.sh site uses a clean sans-serif for prose and a monospaced font for all code/commands. The macOS app follows the same two-family split, but anchors to system fonts for native rendering quality.

| Role | Font | macOS Token | Fallback / Note |
|---|---|---|---|
| **Display** | SF Pro Display | `.title` / `.largeTitle` | Used for app name, empty states |
| **Heading** | SF Pro Display Semibold | `.title2`, `.title3` | Section headers, panel titles |
| **Body** | SF Pro Text Regular | `.body` | Standard readable text |
| **Body Emphasized** | SF Pro Text Semibold | `.body.weight(.semibold)` | List row titles – ranks the row's name above its secondary and metadata lines |
| **Label** | SF Pro Text Medium | `.callout`, `.subheadline` | List row labels, form labels |
| **Caption** | SF Pro Text Regular | `.caption`, `.caption2` | Metadata, timestamps, version strings |
| **Code / Command** | SF Mono Regular | `.body` with `.monospaced()` | Command output, brew commands |
| **Code Bold** | SF Mono Semibold | `.body` with `.monospaced()` | Command verb highlight (e.g. `brew install`) |

#### 3.2 Size ramp

| Token | Size (pt) | Line Height | Usage |
|---|---|---|---|
| `fontSize.largeTitle` | 28 | 34 | Empty state headings |
| `fontSize.title1` | 22 | 28 | Page/section title |
| `fontSize.title2` | 17 | 22 | Panel header |
| `fontSize.title3` | 15 | 20 | Sub-section header |
| `fontSize.body` | 13 | 18 | Standard body text (macOS default) |
| `fontSize.bodyEmphasized` | 13 | 18 | List row titles – same size as body, semibold weight |
| `fontSize.callout` | 12 | 16 | Secondary info rows |
| `fontSize.caption` | 11 | 14 | Metadata, badges |
| `fontSize.code` | 12 | 18 | Terminal / command output (SF Mono) |
| `fontSize.codeSmall` | 11 | 16 | Inline code references |

---

### 4. Semantic colour tokens

All component and layout work should reference these tokens only. Values are given for both **light** and **dark** modes.

> **Two palettes.** Each token below may also carry a **high-contrast** value, used automatically when the user turns on *System Settings → Accessibility → Display → Increase contrast*. The standard palette is the Homebrew palette as designed and several of its pairings sit below 4.5:1; the high-contrast palette is the one that meets WCAG AA throughout. Where the table gives one value, both palettes share it. Tokens are held to this by `BrewColorTokenContrastTests`, which asserts AA in the high-contrast appearances and asserts that high contrast never renders a pairing *worse* than standard.

#### 4.1 Backgrounds

| Token | Light | Dark | Usage |
|---|---|---|---|
| `color.background.windowBase` | `Cellar White #F5F5F0` | `Hops Dark #1A1A1A` | Root window background |
| `color.background.surface` | `Cellar 50 #FAFAF7` | `Hops 900 #222222` | Cards, panels, list backgrounds |
| `color.background.surfaceElevated` | `#FFFFFF` | `Hops 800 #2D2D2D` | Popovers, sheets, floating panels |
| `color.background.surfaceRecessed` | `Cellar 200 #E2E2DC` | `Hops Dark #1A1A1A` | Grouped table background, sidebar |
| `color.background.terminal` | `#1E1E1E` | `#141414` | Command console / log output (always near-black). **Not** used by `CommandBlockView` – see §5 |

#### 4.2 Text

| Token | Light | Dark | Usage |
|---|---|---|---|
| `color.text.primary` | `Cellar 900 #1A1A18` | `#F0F0ED` | Main content text |
| `color.text.secondary` | `Cellar 600 #5C5C58` → HC `#4A4A46` | `Hops 200 #B0B0B0` → HC `#C7C7C7` | Supporting text, subtitles |
| `color.text.tertiary` | `Cellar 400 #9C9C96` → HC `#64645E` | `Hops 400 #6B6B6B` → HC `#A9A9A9` | Placeholders, disabled labels |
| `color.text.link` | `Blue Info #5B9BD5` → HC `#2D71AF` | `#7AB3E0` | Hyperlinks, tappable secondary actions |
| `color.text.brand` | `Amber 600 #E8971C` → HC `Amber 700 #9A6310` | `Amber 600 #E8971C` | Amber text and small foreground marks drawn **on** app surfaces |
| `color.text.onBrand` | `#1A1A1A` | `#1A1A1A` | Text placed on amber brand surfaces (always dark) |
| `color.text.onWarning` | `#FFFFFF` → HC `#1A1A1A` | `#222222` | Knockout on `color.status.warningBold` where the yellow should stay light – the upgrades count badge |
| `color.text.codeDefault` | `#D4D4D4` | `#D4D4D4` | Default terminal/code text (always light on dark terminal bg) |
| `color.text.codeCommand` | `Amber 400 #FCC96B` | `Amber 400 #FCC96B` | brew command verbs in console |
| `color.text.codeArgument` | `#A8D8A8` | `#A8D8A8` | Formula/cask names in console |
| `color.text.codeOutput` | `#C8C8C8` | `#C8C8C8` | Standard stdout in console |
| `color.text.codeError` | `#FF7B72` | `#FF7B72` | stderr / error output in console |
| `color.text.magenta` | `#CB30E0` → HC `#BA1FCF` | `#DB34F2` → HC `#E25AF4` | ANSI magenta in console output – no semantic role |
| `color.text.cyan` | `#00C0E8` → HC `#007A93` | `#3CD3FE` | ANSI cyan in console output – no semantic role |

#### 4.3 Brand / accent

> **Accent colour strategy:** macOS does not expose whether a user has customised their system accent colour, so it is not possible to fall back to amber only when the system default is active. Instead, BrewUI uses a deliberate split: **system accent for all standard SwiftUI controls** (applied via `.tint()` at the root), and **Homebrew amber for fully custom BrewUI-owned components** where `.tint()` has no effect. This respects user preference on system controls while applying clear brand identity where BrewUI has full ownership. See Section 5 for the per-component breakdown.

| Token | Light | Dark | Usage |
|---|---|---|---|
| `color.brand.primary` | `Amber 500 #FBB040` | `Amber 500 #FBB040` | Custom BrewUI components only – progress bars, console cursor, sidebar indicator, install action button |
| `color.brand.primaryHover` | `Amber 400 #FCC96B` | `Amber 400 #FCC96B` | Hover state on custom brand elements |
| `color.brand.primaryPressed` | `Amber 600 #E8971C` | `Amber 600 #E8971C` | Pressed/active state on custom brand elements |
| `color.brand.tint` | `Amber 100 #FEF3DC` | `rgba(251,176,64, 0.12)` | Sidebar selected item background, package row highlight |

> **Fill vs foreground:** `color.brand.primary` and its hover/pressed states are **filled surfaces** – the pairing that has to hold for them is `color.text.onBrand` knocked out of the fill. Amber drawn *on* an app surface (a badge label, a version string, the selected sidebar item) uses `color.text.brand` instead, which is darkened in light mode; the brand amber only reaches 2.4:1 on white.

#### 4.4 Semantic status

| Token | Light | Dark | Usage |
|---|---|---|---|
| `color.status.success` | `Green OK #3CB371` → HC `#2A7D4F` | `#52C98A` | Installed badge, success alert |
| `color.status.successSubtle` | `#EBF7F1` | `rgba(60,179,113,0.15)` | Success row tint |
| `color.status.warning` | `Yellow Warn #F0AD4E` → HC `#9D610D` | `#F5C26B` | Warning **text** |
| `color.status.warningBold` | `Yellow Warn #F0AD4E` | `#F5C26B` | Warning **icons, dots and filled badges** – always pair with `color.text.onBrand`, either as knocked-out label text or as the inner mark of a two-layer symbol (`Image.brewWarningGlyphStyle()`) |
| `color.status.warningSubtle` | `#FEF8EC` | `rgba(240,173,78,0.15)` | Warning row tint |
| `color.status.error` | `Red Error #D9534F` → HC `#CB302C` | `#E87370` → HC `#ED908E` | Failed install, error alert |
| `color.status.errorSubtle` | `#FDECEB` | `rgba(217,83,79,0.15)` | Error row tint |
| `color.status.info` | `Blue Info #5B9BD5` → HC `#2D71AF` | `#7AB3E0` | Info alerts, update notifications |
| `color.status.infoSubtle` | `#EBF3FB` | `rgba(91,155,213,0.15)` | Info row tint |

#### 4.5 Borders & separators

| Token | Light | Dark | Usage |
|---|---|---|---|
| `color.border.default` | `rgba(0,0,0,0.08)` | `rgba(255,255,255,0.08)` | Standard card/panel border |
| `color.border.strong` | `rgba(0,0,0,0.16)` | `rgba(255,255,255,0.16)` | Focused input ring, prominent divider |
| `color.border.brand` | `Amber 500 #FBB040` | `Amber 500 #FBB040` | Focused field brand ring |
| `color.border.separator` | `rgba(0,0,0,0.06)` | `rgba(255,255,255,0.06)` | List row separator |

---

### 5. Component tokens

System accent vs. Homebrew amber – the boundary

| Uses system accent (`.tint()`) | Uses Homebrew amber (`color.brand.primary`) |
|---|---|
| `Toggle` on-state | Install/upgrade `ProgressView` fill |
| `Checkbox` / `Toggle` in forms | Console cursor & progress indicator |
| `Picker` selection | Sidebar selected item indicator |
| Text selection highlight | Primary action `Button` (custom style) |
| Default SwiftUI focus ring | Active tab / filter bar indicator |
| `DatePicker`, `Slider` thumb | Package row selected background tint |
| Any control using `.buttonStyle(.borderedProminent)` by default | SF Symbol tint on selected sidebar items |

In SwiftUI, apply `.tint(Color.accentColor)` at the root `WindowGroup` level and do not override it on standard controls. Apply `color.brand.primary` explicitly only on the custom components listed above.

#### 5.1 Buttons

BrewUI uses a fully custom primary button style – this is one of the components where amber applies. Secondary and destructive buttons use system-standard styling.

| Token | Light | Dark | Note |
|---|---|---|---|
| `button.primary.background` | `Amber 500 #FBB040` | `Amber 500 #FBB040` | **Custom amber** – not system accent |
| `button.primary.backgroundHover` | `Amber 400 #FCC96B` | `Amber 400 #FCC96B` | |
| `button.primary.backgroundPressed` | `Amber 600 #E8971C` | `Amber 600 #E8971C` | |
| `button.primary.foreground` | `#1A1A1A` | `#1A1A1A` | Always dark – amber fails contrast with white |
| `button.secondary.background` | `Cellar 100 #EFEFEA` | `Hops 700 #3A3A3A` | Standard bordered style |
| `button.secondary.backgroundHover` | `Cellar 200 #E2E2DC` | `Hops 600 #4A4A4A` | |
| `button.secondary.foreground` | `Cellar 900 #1A1A18` | `#F0F0ED` | |
| `button.destructive.background` | `Red Error #CD312C` | `#EE918E` | Explicit red – never amber |
| `button.destructive.foreground` | `#FFFFFF` | `#FFFFFF` | |
| `button.cornerRadius` | `6pt` | `6pt` | |

#### 5.2 Text fields / search

Text fields use the system focus ring (system accent) rather than an amber override. The border token is used for the unfocused state only.

| Token | Light | Dark | Note |
|---|---|---|---|
| `textField.background` | `#FFFFFF` | `Hops 800 #2D2D2D` | |
| `textField.backgroundFocused` | `#FFFFFF` | `Hops 700 #3A3A3A` | |
| `textField.border` | `rgba(0,0,0,0.12)` | `rgba(255,255,255,0.12)` | Unfocused border only |
| `textField.borderFocused` | **system accent** | **system accent** | Let macOS render the focus ring – do not override |
| `textField.placeholder` | `Cellar 500 #65655F` | `Hops 300 #A8A8A8` | |
| `textField.cornerRadius` | `6pt` | `6pt` | |

#### 5.3 List rows

Standard `List` selection uses the system accent. The amber tint is applied only to custom package rows with a distinct "selected for action" state (e.g. queued for batch install).

| Token | Light | Dark | Note |
|---|---|---|---|
| `listRow.background` | `#FFFFFF` | `Hops 900 #222222` | |
| `listRow.backgroundHover` | `Cellar 100 #EFEFEA` | `Hops 800 #2D2D2D` | |
| `listRow.backgroundSelected` | **system accent (auto)** | **system accent (auto)** | Standard `List` selection – respect system |
| `listRow.backgroundQueued` | `Amber 100 #FEF3DC` | `rgba(251,176,64,0.15)` | **Custom amber** – "queued for action" state, distinct from selection |
| `listRow.separatorColor` | `rgba(0,0,0,0.06)` | `rgba(255,255,255,0.06)` | |

#### 5.4 Sidebar

The sidebar active item indicator is a custom drawn element – amber applies here.

| Token | Light | Dark | Note |
|---|---|---|---|
| `sidebar.background` | `Cellar 200 #E2E2DC` | `Hops Dark #1A1A1A` | |
| `sidebar.itemDefault` | `Cellar 900 #1A1A18` | `#D4D4D4` | |
| `sidebar.itemSelected.background` | `Amber 100 #FEF3DC` | `rgba(251,176,64,0.18)` | **Custom amber** – fully custom component |
| `sidebar.itemSelected.foreground` | `Amber 700 #98620F` | `Amber 600 #E8971C` | **Custom amber** (`color.text.brand`) |
| `sidebar.itemSelected.indicator` | `Amber 500 #FBB040` | `Amber 500 #FBB040` | Leading edge pill/bar indicator |

#### 5.5 Progress & install state

Progress indicators during install/upgrade operations are a core BrewUI-branded moment – amber applies.

| Token | Value | Note |
|---|---|---|
| `progress.trackColor` | `rgba(0,0,0,0.08)` light / `rgba(255,255,255,0.08)` dark | Background track |
| `progress.fillColor` | `Amber 500 #FBB040` | **Custom amber** – `.tint(color.brand.primary)` on `ProgressView` |
| `progress.indeterminate` | `Amber 500 #FBB040` | Spinner during brew command execution |

#### 5.6 Badges

| Token | Light | Dark |
|---|---|---|
| `badge.installed.background` | `color.status.successSubtle` | `color.status.successSubtle` |
| `badge.installed.foreground` | `Green OK #297C4E` | `#52C98A` |
| `badge.outdated.background` | `color.status.warningSubtle` | `color.status.warningSubtle` |
| `badge.outdated.foreground` | `Amber Warn #9B600D` | `#F5C26B` |
| `badge.cornerRadius` | `4pt` | `4pt` |
| `badge.fontSize` | `fontSize.caption (11pt)` | `fontSize.caption (11pt)` |

#### 5.7 Command console

The console is intentionally always dark – this is the "terminal roots" principle in action. It does not invert to a light surface in light mode. It uses a fixed palette.

| Token | Value | Usage |
|---|---|---|
| `console.background` | `#1E1E1E` | Console pane background |
| `console.backgroundInset` | `#141414` | Inner scroll area |
| `console.border` | `rgba(255,255,255,0.08)` | Console panel border |
| `console.textDefault` | `#C8C8C8` | General output text |
| `console.textCommand` | `Amber 400 #FCC96B` | brew command and verb |
| `console.textArgument` | `#A8D8A8` | Formula / cask name argument |
| `console.textSuccess` | `#52C98A` | Success confirmation lines |
| `console.textWarning` | `Amber Warn #9B600D` light / `#F5C26B` dark | Warning lines |
| `console.textError` | `#FF7B72` | Error / stderr lines |
| `console.textDimmed` | `#6B6B6B` | Verbose / debug lines |
| `console.cursorColor` | `Amber 500 #FBB040` | **Custom amber** – animated cursor / progress indicator |
| `console.fontFamily` | `SF Mono` | – |
| `console.fontSize` | `12pt` | – |
| `console.lineHeight` | `18pt` | – |

---

### 6. Spacing & layout

Follows an 8pt base grid, with a 4pt half-step for tight internal spacing.

| Token | Value | Usage |
|---|---|---|
| `spacing.xxs` | `2pt` | Icon-to-label gap, badge padding |
| `spacing.xs` | `4pt` | Tight internal padding |
| `spacing.sm` | `8pt` | Standard internal padding, row insets |
| `spacing.md` | `12pt` | Section internal padding |
| `spacing.lg` | `16pt` | Panel padding, card insets |
| `spacing.xl` | `24pt` | Between sections |
| `spacing.xxl` | `32pt` | Empty state vertical margins |
| `layout.sidebarWidth` | `220pt` | Default sidebar width |
| `layout.inspectorWidth` | `280pt` | Detail inspector panel width |
| `layout.minWindowWidth` | `800pt` | Minimum supported window width |
| `layout.minWindowHeight` | `520pt` | Minimum supported window height |

---

### 7. Corner radii

| Token | Value | Usage |
|---|---|---|
| `radius.sm` | `4pt` | Badges, tags, small chips |
| `radius.md` | `6pt` | Buttons, text fields, cards |
| `radius.lg` | `10pt` | Panels, sheets, popovers |
| `radius.xl` | `14pt` | Modal windows, onboarding cards |

---

### 8. Elevation & shadow

macOS uses vibrancy and material layers rather than heavy shadows. Use `.ultraThinMaterial` / `.regularMaterial` SwiftUI modifiers where possible. The tokens below are for contexts where explicit shadows are required (e.g. floating panels in non-vibrancy contexts).

| Token | Light Value | Dark Value | Usage |
|---|---|---|---|
| `shadow.sm` | `0 1pt 3pt rgba(0,0,0,0.10)` | `0 1pt 4pt rgba(0,0,0,0.40)` | Cards resting on surface |
| `shadow.md` | `0 4pt 12pt rgba(0,0,0,0.12)` | `0 4pt 16pt rgba(0,0,0,0.50)` | Popovers, dropdown menus |
| `shadow.lg` | `0 8pt 24pt rgba(0,0,0,0.14)` | `0 8pt 32pt rgba(0,0,0,0.60)` | Sheets, modal windows |

---

### 9. Iconography

- Use **SF Symbols** throughout. Minimum symbol weight: **Regular**; use **Medium** for toolbar icons.
- Primary icon tint: `color.brand.primary` (amber) for selected/active states; `color.text.secondary` for default.
- Do not use multicolour symbols except for the app icon itself.
- Recommended symbols per context:

| Context | SF Symbol |
|---|---|
| Package / Formula | `shippingbox` |
| Cask / App | `app.badge` |
| Install | `arrow.down.circle` |
| Uninstall | `trash` |
| Upgrade | `arrow.triangle.2.circlepath` |
| Upgrade All | `arrow.up.circle.fill` |
| Search | `magnifyingglass` |
| Console / Log | `terminal` |
| Settings | `gearshape` |
| Outdated | `exclamationmark.triangle` |
| Tap | `externaldrive.connected.to.line.below` |
| Info | `info.circle` |

---

### 10. Motion & animation

Follow macOS standard animation curves. Avoid custom spring configs unless matching system defaults.

| Token | Value | Usage |
|---|---|---|
| `animation.fast` | `0.15s easeOut` | Button state changes, badge updates |
| `animation.standard` | `0.25s easeInOut` | Panel transitions, list insertions |
| `animation.slow` | `0.35s easeInOut` | Sheet presentation, modal entrance |
| `animation.spring` | `spring(response: 0.35, dampingFraction: 0.75)` | Sidebar expand/collapse |

---

### 11. Accessibility targets

| Requirement | Value |
|---|---|
| Minimum text contrast (WCAG AA) | 4.5:1 for body text |
| Brand amber on dark bg contrast | `#FBB040` on `#1A1A1A` → **8.1:1** ✓ |
| Brand amber on white contrast | `#FBB040` on `#FFFFFF` → **2.7:1** – use dark text on amber surfaces, never amber text on white |
| Minimum tap / click target | `44 × 44pt` |
| Focus ring colour | **System accent** (do not override – macOS renders this automatically) |
| Support Dynamic Type | Yes – use relative SwiftUI font styles, not fixed sizes |
| Reduce Motion support | Yes – check `accessibilityReduceMotion` |
