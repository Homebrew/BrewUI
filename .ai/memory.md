# AI Memory — BrewUI

> Long-term knowledge about this project. Append new entries; do not delete history.
> Format: `## YYYY-MM-DD — Topic`

---

## 2026-03-03 — Project Initialised

- **Project:** BrewUI — Homebrew's official macOS GUI
- **Stage:** Early / scaffolding. AI config layer created. Prototype context migrated from separate repo.
- **Primary agents in use:** Claude, Cursor. Designed to be agent-agnostic.
- **AI config files created:** `AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `CONVENTIONS.md`, `ARCHITECTURE.md`, `.ai/` directory.
- **Key rule:** All agents must read `AGENTS.md` at the start of each session and update `.ai/progress.md` at the end.
- **Next step:** Migrate project-specific context from prototype repo. Update placeholder sections in `CONVENTIONS.md`, `ARCHITECTURE.md`, and this file.

## 2026-03-03 — Tech Stack & Architecture Confirmed

- **Language:** Swift 6.0, strict concurrency mode enabled
- **UI:** SwiftUI (pure — AppKit only when SwiftUI cannot meet the requirement)
- **State:** `@Observable` (Swift 5.9+); `async`/`await` throughout
- **Package manager:** Swift Package Manager
- **macOS targets:** Tahoe 26, Sequoia 15, Sonoma 14 — minimum Tahoe 26
- **Data sources:** `brew` CLI subprocess + Homebrew JSON API (formulae.brew.sh)
- **Architecture pattern decided:** Views → ViewModels → Repositories/Interactors → Services → external (brew CLI / JSON API)
- **Repository naming:** protocol = `*Repository`, real impl = `Brew*Repository`, mock = `Mock*Repository`
- **Interactor naming:** protocol = `*Interacting`, impl = `*Interactor`, mock = `Mock*Interactor`
- **Formatter:** `swift-format` (official Swift project tool)
- **Test framework:** Swift Testing (preferred) or XCTest
- **No `try!` or force-unwrap anywhere** — not in production, not in tests. Use `#require`/`XCTUnwrap` in tests.
- **Accessibility identifiers:** single source of truth in `Utilities/AccessibilityIdentifiers.swift`, shared between app and UI test targets

## 2026-03-03 — Additional Decisions

- **Sandboxing:** App is unsandboxed. No entitlements needed for subprocess execution.
- **Homebrew detection:** Check `/opt/homebrew/bin/brew` (Apple Silicon) then `/usr/local/bin/brew` (Intel). Degrade gracefully if neither found.
- **JSON API schema drift:** Prefer tolerant handling for unknown fields; required-field policy is endpoint-specific (see 2026-05-18 strict catalogue decoding entry).

## 2026-03-11 — Developer Hook Workflow

- **Pre-commit enforcement:** Repository-managed pre-commit hook runs staged Swift files through Mint (`mint run swiftformat`, then `mint run swiftlint` with `--fix`, then strict `mint run swiftlint`). See **2026-04-12 — Mint for SwiftFormat and SwiftLint**. After format/lint it only `git add`s fully staged files whose **worktree** blob changed; partially staged files are blocked only when format/lint actually changed the file on disk (not merely because index ≠ worktree).
- **Bootstrap integration:** `./scripts/bootstrap` installs git hooks automatically via `scripts/install-git-hooks` to minimize manual setup for contributors.

## 2026-04-12 — Mint for SwiftFormat and SwiftLint

- **Version pins:** SwiftFormat and SwiftLint versions live in root `Mintfile` (`nicklockwood/SwiftFormat`, `realm/SwiftLint`).
- **Install path:** Homebrew (`Brewfile`) installs **Mint** only; `./scripts/bootstrap` runs `mint bootstrap` so pinned tools are built once and cached under Mint.
- **Enforcement:** Pre-commit and `swift_quality` CI invoke tools via `mint run swiftformat` / `mint run swiftlint` from the repo root (Mintfile discovery), not global Homebrew formulae for those binaries.

## 2026-03-11 — Lint/Format Baseline Config

- **Pinned Swift version for tooling:** Added root `.swift-version` with `6.2` (aligned to latest installed stable Swift 6.2.4) for deterministic SwiftFormat behavior.
- **Project formatter config:** Added root `.swiftformat` with explicit Swift version and baseline whitespace/line-ending settings.
- **Project linter config:** Added root `.swiftlint.yml` with scoped includes/excludes and practical early-stage defaults for `line_length` and `identifier_name`.

## 2026-03-11 — PR CI Baseline

- **PR checks policy:** Required PR checks are lightweight and path-scoped for fast feedback.
- **Workflow split:** CI is separated into focused workflows (`swift_quality`, `pr_build_test`, `actionlint`, `ui_smoke`) instead of a monolithic pipeline.
- **Optional heavy check:** UI smoke testing is explicitly opt-in via manual `workflow_dispatch` (`ui_smoke.yml`) and is not required by default.

## 2026-03-14 — Project Naming Renamed To Brew

- Xcode project/scheme/targets were renamed from `BrewUI` to `Brew` for clarity.
- Test targets now map as:
  - `BrewTests` = unit tests
  - `BrewUITests` = UI tests
- Repository root folder remains `BrewUI` (part of a larger parent project layout).
- App bundle identifier and installer package identifier changed to `sh.brew.app` (was `sh.brew.BrewUI`). Test bundle identifiers track renamed targets (`sh.brew.BrewTests` and `sh.brew.BrewUITests`).

## 2026-03-15 — Actionlint Policy-Compliant Pattern

- GitHub workflow linting should avoid `uses: docker://...` because org allowlist policy can reject it.
- Preferred pattern for this repo is Homebrew-influenced and allowlist-friendly:
  - use `Homebrew/actions/setup-homebrew@1f8e202ffddf94def7f42f6fa3a482e821489f9c # 2026.07.10.1`
  - use `Homebrew/actions/cache-homebrew-prefix@1f8e202ffddf94def7f42f6fa3a482e821489f9c # 2026.07.10.1` to install `actionlint`/`shellcheck`
  - run `actionlint` via a `run:` step
- Actionlint remains path-scoped to workflow changes for low CI overhead.

## 2026-03-20 — Decision logging (no ADRs)

- **No `docs/adr/`:** Architecture Decision Records are not used in this repo.
- **Where “why” lives:** Durable decisions, constraints, and rationale go in `.ai/memory.md` (dated entries, append-only history).
- **`ARCHITECTURE.md`:** Describes structure and how pieces fit; add extra explanation only when something is unusual or easy to misread.

## 2026-03-21 — Documentation ownership (ARCHITECTURE vs CONVENTIONS)

- **`ARCHITECTURE.md`** is the single source of truth for system shape, layers, data flow, file/folder layout, tech stack baseline, and where `AccessibilityIdentifiers.swift` lives.
- **`CONVENTIONS.md`** owns naming rules, implementation patterns, and contributor-facing how-to; it should **reference** architecture instead of repeating topology or the stack table.

## 2026-03-21 — PR template stays minimal

- **Do not** add standing checklist items to `.github/PULL_REQUEST_TEMPLATE.md` for doc deduplication (or similar); the template should stay short and not grow indefinitely.
- **Doc duplication:** rely on `Document scope` / ownership matrix in `CONVENTIONS.md`, cross-links in `ARCHITECTURE.md`, and review judgment — not extra PR checkboxes.

## 2026-03-22 — Lightweight ARCHITECTURE / CONVENTIONS

- **`ARCHITECTURE.md` and `CONVENTIONS.md` are intentionally minimal** for the early scaffolding phase; grow them as real code and patterns appear.
- **Product / platform constraints** live under **Constraints & decisions** in `ARCHITECTURE.md` only (not duplicated in `CONVENTIONS.md`).
- **`CONVENTIONS.md`** holds BrewUI-specific naming deltas, tooling pointers, and short implementation notes; generic Swift/SwiftUI guidance defers to Apple docs + SwiftLint/SwiftFormat.
- **Doc deduplication:** use the opening blockquotes and cross-links between the two files; the old standalone “ownership matrix” in `CONVENTIONS.md` was removed in favour of that lighter approach.

## 2026-03-27 — Relative doc links rule

- Added `.cursor/rules/doc-relative-links.mdc` to require relative Markdown links for intra-repo doc references (avoid absolute GitHub blob URLs in docs).

## 2026-04-03 — Design system enforcement

- **Where it lives:** `Brew/Theme/` (`BrewColors`, `BrewSpacing` / `BrewLayout` / `BrewRadius`, `BrewFonts`) is the single source for UI semantics; `CONVENTIONS.md` has a **Design system** section; agents use `.cursor/rules/design-system.mdc` (globs `Brew/**/*.swift`) alongside `swift-implementation.mdc`.
- **Rule:** Extend Theme when adding new semantics — avoid raw hex or magic numbers in feature views (already stated in `BrewColors.swift` comments).

## 2026-04-03 — InstalledViewModel dummy data (Swift 6)

- **`InstalledViewModelDummyData`** lives in its own file with static sample arrays. **`InstalledViewModel.init`** takes optional row arrays and applies `?? InstalledViewModelDummyData.*` **in the initializer body** — do not use `= InstalledViewModelDummyData.formulae` as default parameter values, or Swift 6 reports main-actor / default-argument isolation issues.

## 2026-04-04 — Installed packages fetch layer

- **Flow:** `InstalledViewModel` → `InstalledPackagesRepository` → `BrewCommandRunning` + `BrewExecutableLocator`. Parsing is pure `InstalledPackagesParser` on `brew list --versions --formula|cask` stdout (`ARCHITECTURE.md` — tolerant CLI handling).
- **Tests:** Mock `BrewCommandRunning` with a `[[String]: CommandOutput]` map; never run real `brew` in unit tests (`CONVENTIONS.md` **Testing**). `BrewExecutableLocator(overrideURL:)` exists for tests only.

## 2026-04-04 — App Sandbox disabled on Brew target

- **Drift:** Xcode had `ENABLE_APP_SANDBOX = YES` while `ARCHITECTURE.md` specifies an **unsandboxed** app (`2026-03-03 — Additional Decisions`). Sandboxing prevented seeing/executing `/opt/homebrew/bin/brew` and writing session logs under the repo `.cursor/` path.
- **Fix:** `ENABLE_APP_SANDBOX = NO` for the Brew app target (Debug and Release). Revisit sandbox + entitlements only if distribution constraints require it.

## 2026-04-04 — Installed packages slice tests

- **Pattern:** `InstalledViewModelTests` and `BrewInstalledPackagesRepositoryTests` use the real `BrewInstalledPackagesRepository` with boundary fakes only: `MockBrewCommandRunner` + `BrewExecutableLocator(overrideURL:)` or `MissingBrewExecutableLocator` (`BrewExecutableLocating`). Shared helpers: `BrewTests/TestSupport/InstalledPackagesRepositoryTestSupport.swift`. Documented in `CONVENTIONS.md` **Testing**.

## 2026-04-04 — Main window / sidebar VM (deferred)

- When **`SidebarItem`** gains a second case (e.g. Discover), introduce a **`MainWindowViewModel`** (or `AppShellViewModel`) to own selection and any tab rules; keep **`ContentView`’s** `switch` only for constructing child views. Presentation for sidebar rows can move there for unit tests.

## 2026-04-25 — Main window: three-column `NavigationSplitView`

- **Layout:** The main window uses the three-column `NavigationSplitView` initializer: **sidebar** (`ShellSidebarView`), **content** (`InstalledShellView` — list + chrome only), **detail** (`InstalledPackageDetailView` / `InstalledPackageDetailPlaceholder`). The previous `HSplitView` inside the detail region is removed; column widths use `BrewLayout` tokens including `installedListColumn*` and `installedDetailColumn*`. **`minWindowWidth`** is the sum of sidebar, list, and detail minimum column widths. Installed data loading runs from `ContentView` via `.task(id: selectedSidebarItem)` when the Installed tab is selected.

## 2026-04-26 — App shell decomposition (MVVM-C lightweight)

- Added `MainWindowView` + `MainWindowViewModel` so shell layout/navigation selection/load policy are separated from feature views.
- `InstalledColumns` now owns Installed feature column composition (`contentColumn`, `detailColumn`) and related width modifiers.
- `BrewApp` now presents `MainWindowView` directly; `ContentView` remains a thin compatibility wrapper for previews/incremental migration.

## 2026-04-26 — Loadable view state convention

- For async/failable view-model data that drives UI rendering, prefer a single enum state (for example `.loading`, `.loaded(Data)`, `.error(String)`) over separate `isLoading`/`data`/`error` properties.
- This pattern is now used by `InstalledDetailsViewModel` via `InstalledDetailsLoadState`, and documented in `CONVENTIONS.md` under **Implementation notes**.

## 2026-04-27 — Installed list source migrated to brew info JSON

- `BrewInstalledPackagesRepository` now hydrates installed list data from a single `brew info --installed --json=v2` call instead of `brew list --versions` text output.
- Existing Installed list UI contract remains stable because repository output is still `InstalledPackagesSnapshot`, mapped/sorted before `InstalledViewModel` row mapping.
- Tests now validate mixed formula/cask JSON payloads, optional/missing fields, command failure behavior, and invalid JSON decode failures for installed list loading.

## 2026-04-27 — Brew command pipe-drain fix

- `BrewCommandService` now starts concurrent stdout/stderr readers immediately after process launch and only then waits for process termination, avoiding wait-before-read deadlocks on large command output.
- Added `BrewCommandServiceTests` including a large output regression case (250k chars on each stream) to protect command execution paths used for installed list and details loading.

## 2026-05-11 — Noop command center + main window VM wiring

- **`NoopBrewCommandCenter`:** keep the existing **`preview()`** and **`forTesting()`** helpers; avoid renaming preview/test helpers during visibility-only sweeps.
- **`BrewCommandExecutionContext`:** keep **`noopForTestingAndPreviews()`** for existing noop subprocess wiring.
- **Main window:** keep sidebar selection as local `@State` in **`MainWindowView`**; **`InstalledColumnsRoot`** remains the dependency-composition boundary per `CONVENTIONS.md`.
- **Encapsulation:** **`upgradeOperationPhase`** is **`private`** on list/detail VMs where only **`isUpgrading`** / **`showsUpgradeBusy`** are user-facing.

## 2026-05-03 — BrewCommandCenter + operation IDs

- **Protocol `BrewCommandCenter`:** `actor` protocol — `submit(id:command:)`, `phase(for:)`, `phaseByID()` (full snapshot map), `isActive(id:)` (all `async` from callers).
- **`BrewMutatingCommand`:** `Sendable` command pattern — `var operationKind`, `func run(in: BrewCommandExecutionContext) async throws` (no caller closures; kind is not duplicated at `submit`).
- **`BrewCommandExecutionContext`:** `commandRunner` (`BrewCommandRunning`) + `brewExecutableURL()` via `locator` (`BrewExecutableLocating`).
- **`SerialBrewCommandCenter`:** `actor`; **`SerialBrewWorkQueue`** inner actor ensures **one mutating command at a time** across `await`; duplicate **`BrewOperationID`** coalesces via shared **`Task`** handle.
- **`OperationFailure`:** `Sendable` `enum` (`.brewCommand`, `.brewLaunchFailed`, `.brewExecutableNotFound`, `.generic`) for **`BrewOperationPhase.failed(reason:)`**; `init(catching:)` maps `BrewCommandError`, `BrewLookupError`, and other errors to cases; **`userFacingMessage`** is a derived line for UI.
- **Transport types (`BrewOperationModels.swift`):** `BrewOperationKind`, `BrewOperationID`, `BrewOperationPhase`.
- **Domain package discriminator:** `HomebrewPackageKind`; `InstalledPackageKind` typealias; **`BrewOperationID.init(kind:name:)`** in **`BrewOperationID+Homebrew.swift`**.
- **Composition:** **`BrewApp`** holds **`SerialBrewCommandCenter(executionContext: .live())`** and applies **`.environment(\.brewCommandCenter, center)`** to **`MainWindowView`**. **`MainWindowView`** keeps sidebar selection in local `@State` and embeds **`InstalledColumnsRoot()`**. The root view owns dependency composition for the Installed surface by reading **`@Environment(\.brewCommandCenter)`** and constructing **`InstalledColumns(repository:brewCommandCenter:)`**. Previews use **`NoopBrewCommandCenter.preview()`** and **`.environment(\.brewCommandCenter, …)`**; unit tests construct **`SerialBrewCommandCenter`**, **`NoopBrewCommandCenter.forTesting()`**, or **`RecordingSerialBrewCommandCenter`** as needed.

## 2026-05-04 — Installed package upgrades via command center

- **Upgrade path:** **`InstalledDetailsViewModel`** calls **`await brewCommandCenter.submit(id:command:)`** with **`BrewOperationID(row: selectedRow)`** and **`PackageUpgradeCommand(row: selectedRow)`** (same **`kind:name`** as **`InstalledPackageRow/id`**; **`PackageUpgradeCommand`** implements **`BrewMutatingCommand`** with **`BrewCommandExecutionContext`**; mirrors **`brew upgrade` / `brew upgrade --cask`** argv split). **`BrewOperationID.init(row:)`** delegates to **`init(kind:name:)`**.
- **`InstalledViewModel`** takes **`brewCommandCenter: any BrewCommandCenter`** in **`init(repository:brewCommandCenter:)`**; **`BrewApp`** passes the same **`SerialBrewCommandCenter`** instance as for **`.environment(\.brewCommandCenter, …)`**. Removed **`PackageUpgradeRunning`** / **`BrewPackageUpgradeService`**.

## 2026-05-04 — Detail-upgrade task lifetime

- `InstalledDetailsViewModel.upgradeSelectedPackage()` now starts and owns an unstructured task (`upgradeTask`) so upgrade execution via `brewCommandCenter.submit` is not canceled by a view-scoped caller task when navigating away from detail UI.
- `InstalledPackageDetailView` invokes `upgradeSelectedPackage()` directly (no view-level `Task { ... }` wrapper), keeping task-lifetime policy in the view model.

## 2026-05-05 — Per-ID `phaseChanges` + list row VM

- **`BrewCommandCenter`:** added **`phaseChanges(for: BrewOperationID) async -> AsyncStream<BrewOperationPhase>`** — multicast per id in **`SerialBrewCommandCenter`** with **`continuation.onTermination`** cleanup; **`NoopBrewCommandCenter`** yields **`BrewOperationPhase.idle`** once; **`RecordingSerialBrewCommandCenter`** forwards to **`inner`**.
- **Use `AsyncStream<Element>(bufferingPolicy: .unbounded) { … }`** to pick the continuation-based initializer (plain **`AsyncStream { … }`** can resolve to **`unfolding`** under default actor isolation).
- **Installed list:** **`InstalledListRowViewModel`** (`observeRowUpdates`) + **`InstalledListRowRoot`** with **`.task(id: row.id)`**; removed parent **`upgradeBusyRowIDs`** polling loop from **`InstalledViewModel`** / **`InstalledPackagesView`**.

## 2026-05-06 — Installed repository narrow single-package read

- **`InstalledPackagesRepository`:** added **`loadInstalledPackage(kind:named:) async throws -> InstalledPackageInfo`** plus shared error **`InstalledPackagesRepositoryError.packageNotFound(kind:name:)`**.
- **Default protocol behavior:** repository extension falls back to `loadInstalledPackages()` + section/name lookup so existing test doubles remain source-compatible until they adopt specialized implementations.
- **`BrewInstalledPackagesRepository`:** narrow read now executes `brew info --json=v2 --formula|--cask <name>` and maps only the requested section (`formulae` or `casks`) by exact name/token.
- **Tests:** added dedicated lookup coverage in `BrewInstalledPackagesRepositorySinglePackageTests` and new command-fixture helper `InstalledPackagesTestSupport.packageInfoJSONResponse(...)`.

## 2026-05-06 — Installed row-driven catalog patch after upgrades

- **Row ownership:** `InstalledListRowViewModel` now owns mutable `InstalledPackageRow` snapshot state (beyond phase) so UI labels can update from narrow refreshes without full-list reloads.
- **Refresh trigger:** Row VM watches `phaseChanges(for:)` and performs a narrow repository refresh when a row operation transitions `running -> idle`, then emits `onRowUpdated` for parent catalog merge.
- **View wiring:** `InstalledPackagesView` wires `InstalledListRowRoot` with explicit closures (`refreshedInstalledRow`, `mergeInstalledRow`) so row refresh coordination remains in view/view-model boundaries rather than nested VM factories.
- **Detail upgrade path:** `InstalledViewModel` `onUpgradeSuccess` now refreshes and merges only the selected row instead of calling full-list `refreshInstalledPackagesPreservingUI()`.

## 2026-05-06 — Installed refresh simplification (full background snapshot)

- Reverted the row-level refresh/patch architecture to reduce complexity: `InstalledListRowViewModel` now observes `phaseChanges(for:)` for progress only, and no longer owns row-refresh callbacks or repository fetch logic.
- Upgrade completion now uses `InstalledViewModel.refreshInstalledPackagesPreservingUI()` as the single refresh path (full snapshot, no `.loading` transition), preserving smooth list UX without skeleton flicker.
- Kept DI/wiring improvements: view-layer wiring still creates/injects child VMs (`InstalledColumns` for details VM, `InstalledPackagesView` for row roots / command-center environment injection); list VM does not create child VMs.
- Removed narrow single-package repository API (`loadInstalledPackage(kind:named:)`) and dedicated lookup tests introduced solely for the abandoned row-refresh approach.

## 2026-05-06 — Concurrency isolation policy (Swift 6 default actor isolation)

- Project build setting `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` is enabled for the app target, so non-UI infra code can require explicit actor-neutral annotations.
- `SwiftLint` rule `unneeded_synthesized_initializer` is disabled in `.swiftlint.yml` to allow intentional explicit empty `init`/`deinit` declarations when carrying concurrency-isolation intent.
- Preferred style: use member-level `nonisolated` first (for initializers/factories/helpers/protocol requirements), and avoid type-level `nonisolated` unless a full type-level actor-neutral contract is clearly needed.

## 2026-05-07 — Installed model unification to BrewPackage

- Collapsed Installed feature data models into a single domain model: `BrewPackage` now backs list rows, detail payloads, and repository contracts.
- Repositories now map `brew info --json=v2` through shared `BrewInfoJSON+Mapping` helpers and return `BrewPackage` values (`InstalledPackagesRepository` returns `[BrewPackage]`, `PackageDetailsRepository` returns `BrewPackage`).
- Installed list/detail presentation formatting moved to feature view models (`InstalledListRowViewModel`, `InstalledDetailsViewModel`) plus `InstalledBrewVersionFormatting`; models are now presentation-agnostic.
- Removed legacy Installed models (`InstalledPackageInfo`, `InstalledPackageRow`, `InstalledPackageDetails`) and dead parser path (`InstalledPackagesParser` + parser tests).

## 2026-05-08 — Installed feature single-source-of-truth

- **`InstalledViewModel` owns the catalog** and observes **`BrewCommandCenter.allPhaseChanges()`** to refresh after mutating operations complete (`running → idle`).
- **Detail and row view models** no longer fetch from a repository; **`PackageDetailsRepository`** and related infrastructure are removed.
- **Detail and list rows** stay in sync by propagating injected **`BrewPackage`** from the parent via **`onChange(of: package)`** → **`update(package:)`** on the child view models.
- **Detail-upgrade phase observer caveat:** the detail VM still polls phase around submit rather than subscribing to a stream for concurrent operations on the same id; acceptable for now.

## 2026-05-08 — Root-view dependency ownership policy

- Feature `*Root` views are the dependency composition boundary for that surface: they read app-level dependencies (for example `@Environment`), construct/inject content-view dependencies, and own view-model lifecycle boundaries.
- Content views should receive dependencies from their root and focus on rendering and behavior; avoid direct app-level dependency acquisition in content views when a root wrapper exists.
- Treat optional content view models introduced solely to compensate for misplaced dependency acquisition as an anti-pattern.

## 2026-05-08 — Installed list scroll preservation policy

- Keep the Installed list mounted under a stable parent container (`HSplitView`) across selection changes; switching between list-only and split layouts can remount the list and reset scroll position.
- Prefer native `List(selection:)` for Installed row selection state, with view-model-backed selection binding (`setSelection(_:)`) and row tags by stable package id.

## 2026-05-11 — Installed detail uninstall actions

- Installed detail mutations now support both **upgrade** and **uninstall** through the shared `BrewCommandCenter` pipeline; uninstall uses `PackageUninstallCommand` with new `BrewOperationKind` cases (`uninstallFormula`, `uninstallCask`).
- `InstalledPackageDetailView` now treats the footer as a general package-actions area: show upgrade chrome only when `package.outdated`, but always show uninstall chrome with a native confirmation dialog and copyable user-facing `brew uninstall ...` command.

## 2026-05-13 — Vale docs job and `docs/Gemfile`

- **Symptom:** `vale docs/` fails with `lstat docs/../Gemfile: no such file or directory` when `docs/Gemfile` is missing.
- **Cause:** Vale 3 treats `Rakefile` and `Brewfile` (among others) as Ruby-format prose under `[formats] rb = md` in `.vale.ini`. For those paths it expects a resolvable `Gemfile` next to the Ruby project layout; this repo had `docs/Gemfile.lock` and Jekyll binstubs but no `docs/Gemfile`, unlike `Homebrew/brew` where `docs/` is a full Jekyll tree including `Gemfile`.
- **Fix:** Commit `docs/Gemfile` (matching upstream brew docs, consistent with the lockfile) and `docs/.ruby-version` so Vale and later `bundle exec` steps in `.github/workflows/docs.yml` both succeed.

## 2026-05-13 — Installed inventory cache

- **Cache:** In-memory `InstalledInventoryCache` actor stores `InstalledInventorySnapshot` (packages + `PackageDependencyGraph`) populated by `BrewInstalledPackagesRepository` after successful `brew info --installed --json=v2`. `BrewApp` creates one cache per app lifetime and injects it via SwiftUI environment (`InstalledInventoryEnvironment.swift`); feature roots construct `BrewInstalledPackagesRepository` / `BrewInstalledDependentsRepository` from that shared cache. Previews and tests construct isolated caches with `InstalledInventoryCache()` when needed.
- **TTL:** Snapshots are stale after 3600 seconds; `load()` may return cached packages when fresh; `refresh()` passes `forceRefresh: true` to bypass TTL after mutating brew work.
- **Used by:** Detail dependents come from reverse dependency edges among installed packages; per-selection `brew uses` was removed.

## 2026-05-15 — Installed inventory visibility (tests-only pass)

- **Visibility:** New inventory types are module-internal; graph storage and JSON mapping helpers are `private`. Protocols `InstalledDependentsRepository` / `InstalledInventoryReading` stay internal as DI boundaries.
- **Follow-up (production, separate PR):** `InstalledInventoryCache.packages()` has no call sites (prefer `cachedPackages()`). `EmptyInstalledDependentsRepository` / `EmptyInstalledInventoryReading` are unused in production — used only from `makeInstalledDetailsViewModel` in BrewTests; decide whether to delete, wire in previews, or keep for tests only.
- **Tests:** `makeInstalledDetailsViewModel` in `InstalledDetailsViewModelTestsSupport` supplies empty repo defaults for non-inventory tests; production inits remain four explicit parameters.

## 2026-05-15 — Dead-symbol cleanup applied

- Removed dead installed-inventory API surface from app target: `InstalledInventoryCache.packages()`, `InstalledInventoryReading.installedPackages(for:)`, `BrewInstalledPackagesRepository.installedPackages(for:)`, and `BrewPackage.reference`.
- Moved test-only empty inventory/dependents stubs out of `Brew/Repositories` into `BrewTests/TestSupport` (`EmptyInstalledInventoryReading`, `EmptyInstalledDependentsRepository`) so production DI paths remain explicit.
- Pruned unused test support helpers `localizedHomebrewCommandFailedMessage()` and `packageInfoJSONResponse(...)` from `InstalledPackagesRepositoryTestSupport`.

## 2026-05-16 — Domain/presentation mapping boundary

- Installed uninstall presentation mapping now uses a feature-layer `UninstallPackageItem` initialized from `BrewPackage`, instead of adding uninstall UI properties directly on `BrewPackage`.
- Team convention clarified: domain model types stay presentation-agnostic; map to UI properties through feature ViewModels (top-level surfaces) or feature `*Item` types (subview/action presentation).

## 2026-05-17 — Passive view enforcement for presentation state

- Strengthened `CONVENTIONS.md` and `.cursor/rules/swift-implementation.mdc` with an explicit MVVM guardrail: views must not compose multiple ViewModel state primitives inline to derive a single presentation decision.
- Preferred pattern: expose one derived ViewModel property per UI concern (for example one spinner-driving busy flag), and have the view bind directly to it.

## 2026-05-18 — Installed detail itemization boundary

- Installed detail now uses feature-layer item mappings for co-changing presentation groups: `PackageDetailMetadataItem`, `UpgradePackageItem`, and `UninstallPackageItem`, all exposed from `InstalledDetailsViewModel` for VM-driven subviews.
- For this surface, independently changing async state streams (`isUpgrading`, `isUninstalling`, `isMutatingPackage`) remain on the top-level ViewModel and are not folded into item types.
- Detail-presentation extensions on `BrewPackage` were removed (`BrewPackage+Presentation.swift` deleted); presentation mapping lives in ViewModel/feature item types only.

## 2026-05-18 — Installed naming consistency (minimal pass)

- Installed detail ViewModel naming now aligns with the package-detail view family: `InstalledDetailsViewModel` was renamed to `InstalledPackageDetailViewModel` and moved to `InstalledPackageDetailViewModel.swift`.
- Feature-local helper names should stay scoped but respect lint type-length limits (`SwiftLint` `type_name` max 40): renamed detail command console helper to `InstalledDetailMutationConsole` and mutation-parity test suite/file to `InstalledDetailMutationParityTests`.
- Installed list row presentation value type renamed from `RowVersionPresentation` to `InstalledListRowVersionPresentation` to keep local naming explicit.

## 2026-05-18 — Folder boundary reorganization

- Feature folders now use explicit subdirectories: `Features/<Feature>/Views` and `Features/<Feature>/ViewModels`.
- `Models/` is now enforced as domain-only; non-domain types moved out:
  - Installed presentation/UI types moved to `Features/Installed/ViewModels`.
  - Brew command JSON/operation helpers moved to `Services/BrewCommand` (with command JSON under `Services/BrewCommand/JSON`).
  - Installed inventory snapshot moved to `Services/InstalledInventory`.
- Service infra is now grouped by boundary: brew command layer in `Services/BrewCommand`, inventory infra in `Services/InstalledInventory`.
- Added durable guidance in `CONVENTIONS.md`, `ARCHITECTURE.md`, and `.cursor/rules/folder-boundaries.mdc` so future agents keep the same placement policy.

## 2026-05-18 — Centralized preview support policy

- Shared preview samples and lightweight preview fakes now live in a single source of truth: `Brew/PreviewSupport/AppPreviewSupport.swift`.
- Previews should consume centralized support types (`AppPreviewSupport`, preview fakes) instead of defining one-off inline mock services/repositories per view.
- Preview blocks are colocated at the bottom of their view files; standalone `+Previews.swift` files for those views were removed.
- Enforcement guidance is documented in `CONVENTIONS.md` and `.cursor/rules/previews-centralized.mdc` (linked from `swift-implementation.mdc`).

## 2026-05-18 — Package display labels vs canonical IDs

- `BrewPackage` now carries `displayName` for UI labels while keeping `name` as the canonical Homebrew identifier used for IDs and CLI commands.
- Installed mapping from `brew info --json=v2` now uses richer display fields with fallback:
  - formula: `full_name` (fallback `name`)
  - cask: first `name` entry (fallback `token`)
- `HomebrewPackageReference` remains identity-first (`.formula(name:)` / `.cask(token:)`) and still uses canonical values for `packageID`; dependency-only contexts may continue showing token/name when richer metadata is not present.

## 2026-05-18 — PR descriptions location preference

- User preference: place generated PR descriptions in `.ai/scratchpad.md` by default.

## 2026-05-18 — PR description project skill

- Added project skill at `.cursor/skills/pr-description-to-scratchpad/SKILL.md`.
- Skill contract: build PR bodies from `main...HEAD`, follow `.github/PULL_REQUEST_TEMPLATE.md`, and append to `.ai/scratchpad.md`.

## 2026-05-18 — Discover analytics data-access slice

- Added a dedicated Homebrew analytics network boundary:
  - `BrewAPIClient` protocol + `URLSessionBrewAPIClient` in `Brew/Services/BrewAPIClient.swift`.
  - Endpoint-specific APIs for Discover:
    - `fetchFormulaInstallOnRequestAnalytics(window:)`
    - `fetchCaskInstallAnalytics(window:)`
- Added resilient analytics decoding model `BrewAnalyticsJSON`:
  - tolerant top-level decode with `formulae`/`casks` bucket fallback
  - count parsing supports both numeric and comma-separated string forms
  - normalized `BrewAnalyticsPackageCount` output for repository mapping
- Added `DiscoverPackagesRepository` + `BrewDiscoverPackagesRepository` returning one combined `DiscoverTopPackagesSnapshot` (`topFormulae` + `topCasks`) with limit/window parameters (defaults: top 10, 30d).

## 2026-05-18 — Package-domain lookup identity rule

- Package-domain representations should expose `HomebrewPackageReference` as their lookup identity (formulae map to `.formula(name:)`, casks map to `.cask(token:)`).
- `BrewPackage` now exposes `reference` again as a computed property from `kind` + `name`.
- Discover models now carry typed references:
  - `BrewAnalyticsPackageCount.reference`
  - `DiscoverTopPackage.reference`
- Added `.cursor/rules/package-domain-reference.mdc` and mirrored the rule in `CONVENTIONS.md` to keep the requirement persistent for future domain models.

## 2026-05-18 — URLSessionProtocol testing seam for API client

- Added `URLSessionProtocol` (`data(for:)`) in `Brew/Services/URLSessionProtocol.swift` with `URLSession` conformance.
- `URLSessionBrewAPIClient` now supports dependency injection via `init(session: any URLSessionProtocol, ...)`, enabling deterministic unit tests with a mock session implementation instead of closure-only stubbing.

## 2026-05-18 — Discover analytics strict decoding policy

- Discover analytics decoding now fails fast for required non-optional fields rather than defaulting to empty/zero values.
- `BrewAnalyticsJSON` requires valid `category`, `total_items`, `total_count`, `start_date`, `end_date`, and at least one analytics bucket container (`formulae` or `casks`).
- Malformed per-entry `count` values now throw during decode (no fallback `0`), and unresolved package references are treated as decode failures instead of being silently filtered out.

## 2026-05-18 — Discover analytics decoder simplification

- Simplified `BrewAnalyticsJSON` strict decoder by removing fallback identity inference:
  - no fallback from bucket key
  - no fallback from `category` inferred kind
- Analytics rows now require explicit identity in payload (`formula` xor `cask`), which keeps failure behavior deterministic when server payloads are incomplete/ambiguous.

## 2026-05-18 — API client tests use URLProtocol stubs

- Replaced `URLSessionProtocol` abstraction tests with integration-style tests that use a real `URLSession` configured with `URLProtocol` stubbing.
- `URLSessionBrewAPIClient` session init now takes concrete `URLSession`.
- `BrewAPIClientTests` use host-scoped stub queues/recording in `StubURLProtocol` to keep tests deterministic under concurrent execution.

## 2026-05-18 — Deferred Installed search adaptation

- Installed search still filters on canonical `BrewPackage.name` rather than `displayName`.
- User requested this remain unchanged for now and be revisited during discovery search work.
- Keep this as an explicit follow-up so label-search behavior can be aligned intentionally later.

## 2026-05-18 — Catalogue decode strictness

- Catalogue transport decoding (`FormulaCatalogueJSON` / `CaskCatalogueJSON`) now treats `desc`, `homepage`, `versions.stable`, and `analytics.install["30d"]` as required fields.
- Catalogue array decoding is now lossy per item: invalid entries are skipped, and decode failures are captured with item index + error string so callers can handle partial failures without dropping valid items.

## 2026-05-19 — Catalogue cache + repository split

- Split catalogue responsibilities into two boundaries:
  - `CatalogueCache` actor owns only in-memory state, disk persistence, and ETag storage.
  - `BrewCatalogueRepository` owns TTL, stale-while-revalidate policy, refresh orchestration, and in-flight task deduplication.
- `CatalogueCache` currently preloads cache on async init:
  - `init(...) async` loads formula/cask cache files immediately (missing/corrupt files are swallowed);
  - read/write methods operate on preloaded in-memory state (no separate warm-up method).
- `BrewCatalogueRepository` behavior:
  - one refresh `Task` per catalogue kind is shared across concurrent callers;
  - stale cached data returns immediately while background refresh runs;
  - cold start (no cache) blocks on refresh and surfaces errors;
  - `304` updates only last-refresh timestamp;
  - background refresh failures are swallowed.

## 2026-05-19 — Transport models must not cross repo/service APIs

- `CatalogueRepository` now maps cached/network catalogue transport payloads to domain `BrewPackage` arrays before returning.
- Durable rule: `Codable` transport types (`*JSON`, DTO/wire models) must stay behind service/repository boundaries and not appear in service/repository protocol return types.
- Enforcement/docs:
  - Added `CONVENTIONS.md` note under **Transport boundary**.
  - Added `.cursor/rules/codable-boundary.mdc` (always apply) and linked guidance in `.cursor/rules/swift-implementation.mdc`.

## 2026-05-19 — Installed model split (`InstalledBrewPackage` vs `BrewPackage`)

- Installed-only state moved out of shared package domain:
  - `InstalledBrewPackage` composes a `BrewPackage` (`package`) plus `installedVersions` and `outdated`.
  - Public fields shared with `BrewPackage` are exposed as wrapper properties; identity (`id`, `reference`) derives from `package`.
  - `BrewPackage` is slim/shared for catalogue/discover-prep fields only.
- Boundary rule:
  - installed repositories/inventory/graph/view-model surfaces use `InstalledBrewPackage`,
  - catalogue repository surfaces remain `[BrewPackage]` and must not reintroduce installed-only fields.
- Command/convenience identity behavior remains stable via `kind:name` IDs:
  - `BrewOperationID(package:)` now takes `InstalledBrewPackage`,
  - `HomebrewPackageReference` gained `init(installedPackage:)` (delegates to `init(package:)`),
  - package ID/reference semantics remain canonical and unchanged.

## 2026-05-20 — Discover wrapper domain contract

- Discover top-list domain rows now use `DiscoveryBrewPackage` (`package: BrewPackage` + `thirtyDayInstallCount`) instead of reference/count-only payloads.
- `DiscoverTopPackagesSnapshot` now carries `[DiscoveryBrewPackage]` for formula/cask sections; downstream list/detail mapping should read package metadata from `DiscoveryBrewPackage.package` and ranking from `DiscoveryBrewPackage.thirtyDayInstallCount`.

## 2026-05-20 — Discover repository owns catalogue enrichment

- `BrewDiscoverPackagesRepository` fetches analytics via `BrewAPIClient`, then resolves each ranked analytics row through `CatalogueRepository.package(for:)` (per-reference lookup, not whole-catalogue loads).
- `CatalogueRepository` public API is `package(for: HomebrewPackageReference) -> BrewPackage?`; whole-catalogue fetch/map/cache refresh stays private inside `BrewCatalogueRepository`.
- On `package(for:)`, if the kind’s catalogue is uncached or TTL-stale, `BrewCatalogueRepository` fetches the full catalogue once, updates cache, and serves lookups from an in-memory ID index (deduped in-flight refresh preserved).
- Analytics rows with no catalogue match are dropped silently; the limit applies to matched rows only.
- `DiscoverViewModel` no longer loads catalogues; it consumes enriched `DiscoveryBrewPackage` rows from the discover repository.

## 2026-05-21 — Installed and Discover list selection UI

- **Selection chrome:** Both `InstalledPackagesView` and `DiscoverPackagesView` use a plain `List` (not `List(selection:)`), row taps via `.onTapGesture` + `viewModel.setSelection`, and `.listRowBackground(selected ? Color.brewBrandTint : Color.clear)`. Avoid `List(selection:)` — it applies system accent selection on top of the brand tint.
- **Column backgrounds:** List column header, list body, and detail inherit window/split chrome; do not wrap Discover/Installed columns in `.background(Color.brewSurface)` unless product asks for explicit surface fills everywhere.
- **Scroll:** Both lists use `ScrollViewReader` + `scrollToSelection` on appear/selection/row-id changes (`.brewFast` animation).

## 2026-05-27 — Console command-job projection layer

- **Console UI is fed by a registry, not by `BrewCommandCenter` directly.** `JobRegistry` (`@Observable @MainActor`) projects center operation state for console views; it never mutates the center. Subscribes to `allPhaseChanges()` once at app launch via `BrewApp .task { jobRegistry.startObserving(commandCenter) }`. Injection mirrors `BrewCommandCenterEnvironment` — `@Entry var jobRegistry: JobRegistry`.
- **`CommandJob` reuses `BrewOperationID`** (do not mint a parallel UUID). Carries phase, output buffer (50k-line cap, FIFO eviction), and a derived `exitCode: Int32?`. `isTerminal == (exitCode != nil)`.
- **Exit code derivation from phase transitions** (since `BrewOperationPhase` doesn't carry one): `.running → .idle` ⇒ exit 0; `.failed(.brewCommand(exitCode, _))` ⇒ that exit code; other `.failed(...)` cases ⇒ `-1` sentinel. An `.idle → .idle` (initial replay or noop) does not back-fill an exit code.
- **Job materialization is lazy and ID-derived.** Registry only creates a `CommandJob` when it sees a `.running(kind)` phase for an unknown id; the user-facing command string and `JobScope` are synthesized from `BrewOperationID.rawValue` (parsed as `"<kind>:<name>"`) plus the running `BrewOperationKind`. This avoids extending `BrewMutatingCommand` with metadata for slice 1.
- **`JobScope`:** `.package(name:)` for per-package ops, `.global` for `brew update`/`doctor`/`cleanup`, `.batch(names:)` for multi-package upgrades. Used to filter jobs in detail panes vs show globally in the console.
- **Files live in `Brew/Features/Console/Models/`** (`BrewCommandOutputLine`, `JobScope`, `CommandJob`, `JobRegistry`, `JobRegistryEnvironment`). Future console UI will live alongside in `Brew/Features/Console/Views/`.

## 2026-05-27 — Output streaming in BrewCommandCenter

- **`BrewCommandCenter` adds `outputChanges(for:)` and `allOutputChanges()`** mirroring the existing phase API shape exactly — per-id stream yields buffered-on-subscribe lines, all-output stream yields each new `(id, line)` with no replay. Both clean up via `AsyncStream.Continuation.onTermination`.
- **Output sink plumbing uses a TaskLocal** (`BrewCommandOutputContext.sink`) rather than threading a closure through `BrewMutatingCommand` / `BrewCommandRunning`. `SerialBrewCommandCenter.submit(id:command:)` sets the sink via `withValue(...)` for the duration of the submit; `BrewCommandService` reads it once at the top of `run(...)`. Commands are untouched — they still call `context.commandRunner.run(...)`.
- **`BrewCommandService` streams via chunked `availableData` + manual `\n` splitting**, not `FileHandle.bytes.lines` and not `readabilityHandler`. Rationale: preserves byte-exact `CommandOutput.standardOutput`/`standardError` (the existing buffered path's contract — tests rely on it). When `sink == nil` the splitting is skipped (no overhead). Lines whose bytes are not valid UTF-8 are dropped from the stream (still kept in the verbatim byte return).
- **Ordering across actor boundary uses an internal `AsyncStream` buffer.** The non-actor sink closure yields lines to a continuation; a per-submit drain Task pulls them in FIFO order onto the actor and broadcasts to per-id and all-output listeners. Drains until `lineContinuation.finish()` is called when the submit task settles. Across stdout/stderr the order is inherently non-deterministic (separate POSIX streams).
- **`NoopBrewCommandCenter` / `RecordingSerialBrewCommandCenter`** stub or forward the new methods. Output streams from `NoopBrewCommandCenter` finish immediately (no work to observe).
- **No 16ms batching yet** — each line emits to listeners as it arrives. Sufficient for typical brew chatter; batching deferred to console-polish (Slice 6).

## 2026-05-27 — Console UI surfaces (collapsed strip)

- **Root layout:** `MainWindowView` wraps `NavigationSplitView` in a `VStack` (`spacing: 0`) with `Divider() + ConsolePanel` at the bottom. The console spans the full window width (under sidebar + detail) — IDE convention, signals that it reflects all brew activity.
- **`@SceneStorage("consoleExpanded")`** stores the expand/collapse boolean per window. Survives quit-and-relaunch. Do not use `@AppStorage` (cross-window pollution).
- **Console layout tokens** live in `BrewLayout`: `consoleCollapsedHeight` (36), `consoleMinExpandedHeight` (120), `consoleMaxExpandedHeight` (600), `consoleDefaultExpandedHeight` (240). No new color literals at call sites — all colors flow through `BrewColors` (`brewTerminal`, `brewBrandPrimary`, `brewStatusSuccess`, `brewStatusError`, `brewTextSecondary`, `brewTextTertiary`, `brewCodeDefault`, `brewCodeError`).
- **MVVM separation:** `ConsoleStatusPresentation.from(registry:)` projects the registry into a view-passive struct (DotState + Summary + isRunning); the view renders that snapshot. Mirrors the existing `*BusyPresentation` pattern in Discover/Installed.
- **Phase short labels** live as `BrewOperationPhase.shortLabel` extension (`done` / `running` / `failed`). Coarser than brew stdout markers (`fetching`/`pouring`/`linking`) because the center's phase enum doesn't expose those — sub-phase granularity would require stdout parsing. Single source of truth for status-bar + future inline-card text.
- **Status dot palette** (design-system rule — BrewUI-owned components use amber for in-progress; terminal states use semantic colors): running = `brewBrandPrimary`, succeeded = `brewStatusSuccess`, failed = `brewStatusError`, idle = `brewTextTertiary`.
- **Slice 3 ships the collapsed strip only.** The expand toggle is wired but the expanded body comes in slice 4 — the chevron currently toggles state with no visible effect.

## 2026-05-27 — Expanded console body, toolbar, resize, and shortcut

- **`ConsolePanel` is a state machine.** Collapsed → just `ConsoleStatusBar`. Expanded → `VStack` of `ConsoleResizeHandle` + `ConsoleToolbar` + `Divider` + `ConsoleBody`. Animates `.frame(height:)` with `.brewFast` (0.15s easeOut) to keep the `List` above from clipping (see ARCHITECTURE/CONSOLE_IMPLEMENTATION_PLAN §7).
- **Resize state:** `@SceneStorage("consoleHeight") consoleHeight: Double = consoleDefaultExpandedHeight`. Per-window, survives quit-and-relaunch. Drag is clamped between `consoleMinExpandedHeight` (120) and `consoleMaxExpandedHeight` (600). The handle's cursor uses `NSCursor.resizeUpDown.push()/.pop()` in `onHover` so it doesn't leak when the view disappears mid-hover.
- **`⌘\`` toggle uses `FocusedBinding<Bool>` plumbing.** `FocusedValues.consoleExpanded: Binding<Bool>?` is published by `MainWindowView` via `.focusedSceneValue(\.consoleExpanded, $consoleExpanded)`; `ConsoleCommands` reads it with `@FocusedBinding(\.consoleExpanded)` so the menu command targets the active window's scene-storage. The menu button label flips between "Show Console" / "Hide Console" based on the current state; disabled when no focused window publishes the value.
- **Commands are added in two `.commands` blocks** on `WindowGroup` — the always-on `ConsoleCommands` and (DEBUG-only) `DebugMenuCommands`. Two adjacent `.commands` modifiers merge; this avoids `#if DEBUG` inside a `@CommandsBuilder`.
- **Toolbar = selected-job pill + actions + collapse chevron.** Pill = `ConsoleStatusDot` + monospace command on a `brewBrandTint` rounded rect (sm radius). Save uses `NSSavePanel` defaulting to `~/Downloads` with filename `brewui-<sanitized-command>-<yyyy-MM-dd-HHmmss>.log`; Copy uses `NSPasteboard.general`. Both consume `CommandJob.formattedOutputForExport()` which `[stderr] `-prefixes error lines so a downstream reader can disambiguate.
- **Clear** calls `registry.clearCompleted()` directly with no confirmation dialog. `clearCompleted` already preserves in-flight jobs, so there's no destructive case to confirm — deviation from CONSOLE_IMPLEMENTATION_PLAN §3.4 which suggested a dialog when running jobs exist. Revisit if user feedback wants the call-out.
- **`ConsoleBody`** is a `List` over `selectedJob.output` with `.listStyle(.plain) + .scrollContentBackground(.hidden) + .background(Color.brewTerminal)`. Auto-pin-to-bottom on `.onChange(of: job.output.count)`. User scroll-lock when scrolled up is deferred to console polish. stderr lines use `brewCodeError`; stdout uses `brewCodeDefault`. Text uses `.textSelection(.enabled)` so individual lines can be copied. Empty state = `ContentUnavailableView` (macOS 14+).
- **No ANSI / color parsing in v1** — raw monospace text. Tracked for the polish slice.

## 2026-05-27 — Console split into BrewCommandJobsRepository + ConsoleViewModel (supersedes earlier registry note)

- **Supersedes** the 2026-05-27 "Console command-job projection layer" entry. `JobRegistry` and `\.jobRegistry` no longer exist. The decision to call the layer a "Registry" pre-dated a full survey of the codebase's MVVM + Repository conventions; the conflation of translation/cache, screen-local state, and presentation projections inside one type drifted from how Discover/Installed are structured.
- **New layer split** mirrors `BrewInstalledPackagesRepository` + `InstalledViewModel`:
  - **`BrewCommandJobsRepository`** (`Brew/Repositories/`, `@Observable @MainActor`, conforms to `CommandJobsObserving`) is the single source of truth for cached command-center operation state. Subscribes to `commandCenter.allPhaseChanges()` and `.allOutputChanges()` in `init` via `@ObservationIgnored` `Task`s (no `startObserving(_:)` call from `BrewApp` — pattern matches `BrewInstalledPackagesRepository.completionObserverTask`). Owns `jobs`/`orderedIDs`; exposes `remove(id:)` and `clearCompleted()`. `handlePhase`/`handleOutput` are internal seams kept around for unit tests.
  - **`ConsoleViewModel`** (`Brew/Features/Console/ViewModels/`, `@Observable @MainActor`) owns the per-window `selectedID` (screen state — does not belong on a Repository). Exposes derived `orderedJobs`, `selectedJob`, `activeJob`, `statusPresentation`, and `jobs(for packageName:)`. Intent methods (`select`, `dismiss`, `clearCompleted`) clean up selection before forwarding to the repository.
- **Wiring:** `\.commandJobsRepository` env key replaces `\.jobRegistry`. `ConsolePanelRoot` reads the env value and constructs a `@State` `ConsoleViewModel` per-window (mirrors `InstalledColumnsRoot`). `ConsolePanel`/`ConsoleToolbar`/`ConsoleBody`/`ConsoleStatusBar` consume the VM directly (`@Bindable`/`let`) — no environment-key reads inside console views.
- **AppKit isolation:** `NSSavePanel`/`NSPasteboard` calls live in a view-layer namespace `Brew/Features/Console/Views/ConsoleOutputExport.swift` rather than in views or the VM. Rule: ViewModels do not import AppKit; AppKit bridges sit at the view layer. `CommandJob.formattedOutputForExport()` and `.suggestedExportFilename()` remain on the domain model (pure data).
- **File placement:** `CommandJob.swift` moved from `Console/Models/` to `Console/ViewModels/` — it's `@Observable @MainActor` with presentation-shaped helpers, which CONVENTIONS.md says doesn't belong under `Models/`. `Console/Models/` now holds only the pure value types `BrewCommandOutputLine` and `JobScope`.
- **Tests:** `BrewCommandJobsRepositoryTests` covers cache mechanics (phase/output materialization, `remove`, `clearCompleted`). `ConsoleViewModelTests` covers selection/projection/intent forwarding. `ConsoleStatusPresentationTests` constructs a `(repository, viewModel)` fixture and asserts against `viewModel.statusPresentation`.

## 2026-05-29 — BrewOperationID generalized for maintenance work (Doctor feature)

- **`BrewOperationID` is now an enum** (`BrewCore/Operations/BrewOperationModels.swift`): `.package(HomebrewPackageID)` and `.maintenance(token:displayCommand:)`. Was a package-only struct. Maintenance ops (a `brew doctor` fix like `brew link`/`brew cleanup`) aren't package-scoped, so they carry their own `token` for identity plus the user-facing `displayCommand`. Backward-compatible: the existing `init(kind:name:)` / `init(package:)` / `init(packageID:)` inits still build `.package`, so all install/upgrade/uninstall call sites were untouched. `packageID` is now an **optional** accessor (`nil` for maintenance).
- **`BrewOperationKind.doctorFix`** added. `CommandJob.materialize` branches on the id: package ids synthesize the command from kind+name (existing path); maintenance ids use the id's stored `displayCommand` verbatim. This is why a doctor fix shows up correctly in the bottom console with no extra wiring.
- **`DoctorFixCommand`** (`BrewCLI`) runs an arbitrary `brew` argv with `operationKind = .doctorFix`; vended via the new `BrewMutatingCommandFactory.doctorFixCommand(arguments:)` port (Live/Stub/Unimplemented impls updated).
- **`DoctorRepository` is an app-scoped `@Observable @MainActor` port** (mirrors `InstalledInventoryObserving`/`BrewInstalledPackagesRepository`), NOT a stateless one-shot — it holds `state: LoadState<DoctorReport, any Error>` + `isRefreshing` and exposes `load()`. Long-lived (injected once in `BrewApp`) so the report **persists across leaving/returning to the Doctor tab**. `load()` is **stale-while-revalidate**: an existing report stays on screen (`isRefreshing` flips on) while the re-check runs; only the first load shows `.loading`; a failed refresh keeps the prior report (logs). Runs `brew doctor` read-only (via the command center); **a non-zero exit means warnings were found, not a failure**, so the exit code is ignored and both stdout+stderr are parsed. Concurrent `load()`s coalesce onto one in-flight `Task`.
- **Follow-up (still open):** migrate install/upgrade/uninstall display strings to read from the command rather than re-synthesizing in `materialize`, now that maintenance ops carry `displayCommand`.

## 2026-05-30 — Doctor parser overhaul + CommandBlockView + console pill

- **`DoctorIssue` is modeled as an ordered list of typed blocks** (`Sources/BrewCore/Models/DoctorReport.swift`): `severity`, `blocks: [DoctorBlock]` (with `.prose` / `.command` / `.data` / `.link` content), per-block `caption` + `precededByBlankLine`, and `rawBody` as the verbatim fallback.
- **Block classification is by first member, not per-line allowlist** (per the addendum). A colon-terminated un-indented line opens a *pending block*; its first indented member decides whether the whole block is `.command` / `.data` / `.link`. The allowlist is consulted once per block (first-member command test) plus as a `.prose` fallback for stray commands under prose.
- **Run Fix is intentionally narrow.** `DoctorBlock.isRunnable` is true only for a single-step, non-admin `brew` command (multi-step and `sudo` blocks are copy-only).
- **`CommandBlockView`** (`Sources/BrewUIComponents/Views/CommandBlockView.swift`) replaces `PackageDetailCommandConsole` — same single-command API plus a `commands: [String]` init that renders a numbered list with one "Copy all". Used by Installed (upgrade + uninstall), Discover (install), and Doctor (per fix sequence). The old name is gone.
- **`brew doctor` runs through `BrewCommandCenter`** via `BrewOperationKind.doctorRead` + a `DoctorReadCommand` actor (`Sources/BrewCLI/`). `BrewDoctorRepository` now takes `commandCenter: any BrewCommandCenter` and submits a stable maintenance id (`token "doctor"`, `displayCommand "brew doctor"`) on every `load()` — the bottom console picks up the pill + streams output from the existing `BrewCommandJobsRepository` projection, and re-submits on the same id update the existing `CommandJob` instead of spawning new pills. `DoctorReadCommand` is an actor because it owns mutable `capturedOutput` mutated by `run(in:)` and read by the repo after submit returns; `nonisolated let operationKind` satisfies the `BrewMutatingCommand` requirement. This **loosens the center's "mutating only" framing** — documented at the enum case. The serial queue is shared so doctor reads queue behind active mutations; acceptable.

## 2026-06-02 — Doctor severity model: Tier 1 is unreachable by construction

- **`DoctorSeverity.info` does not exist.** The enum is `caution / danger / unsupported` only. Tier 1 is **unreachable from any `Warning:` block in real `brew doctor` output**: Homebrew's `support_tier_message` (Ruby) starts with `return if tier.to_s == "1"`, so a Tier 1 configuration produces no callout text at all. "Tier 1" means "fully supported, no editorial needed" — brew doesn't print anything about it. The parser's regex is intentionally narrowed to `/This is a Tier ([23]) configuration:/` to make this guarantee visible at the source.
- **Why this is a source-level guarantee, not a fixture-coverage gap:** when the `.ai/plans/brew-doctor-console.txt` fixture (which is the "all possible warnings" sample) produces no Tier 1 callouts, the first instinct is "fixture is incomplete." It isn't — there is no such callout anywhere in brew's source to capture. Don't re-add `.info` thinking the next fixture expansion will exercise it. If anyone wants a Tier 1-style "info" affordance in the UI, it has to come from a different source (e.g. an `add_info`/`ohai` capture from `brew config`), not the doctor warning stream.
- **`.unsupported` is still real.** `support_tier_message` does emit "This is an Unsupported configuration:" for the `unsupported` slug (prerelease / outdated-macOS paths in `check_for_unsupported_macos` resolve there). The fixture happens not to include such a case; the unit test `unsupported configuration trumps any tier` exercises the parser branch.

## 2026-06-23 — Brew is spawned through the user's login + interactive shell

- **The problem.** A GUI process launched from Finder/Dock/launchd inherits a stripped environment: missing `PATH` entries and `HOMEBREW_*` vars that `brew shellenv` installs into the user's profile files (`~/.zprofile`). Running `brew config` / `brew doctor` against that stripped env produced output that didn't match what the user sees in Terminal, which destroys trust in the diagnostics.
- **The fix.** All brew invocations now route through `LoginShellBrewCommandRunner` (`Sources/BrewCLI/`), which rewrites `run(executableURL: brew, arguments: [...])` into `<login-shell> -l -i -c "<brew> <quoted args>"`. The login shell is resolved by `LoginShellResolver` from `getpwuid(getuid())->pw_shell` (Directory Services) with a `/bin/zsh` fallback. **`$SHELL` is intentionally not consulted** — it can be stale or absent in a GUI launch.
- **Why `-l` AND `-i`.** `-l` sources `.zprofile` / `.bash_profile` (Homebrew's documented install writes `brew shellenv` to `.zprofile`). `-i` additionally sources interactive rc files (`.zshrc` / `.bashrc`) so users who put their brew setup in those files also get parity. The tradeoff is real and accepted: interactive rc files may print banners or expect a TTY (we run with `/dev/null` stdin, so any TTY-dependent code in rc files will surface as warnings on stderr). If we ever see that as a meaningful noise source for users, the dial is `-l` only.
- **Single spawning route.** Quoting is handled by `LoginShellBrewCommandRunner.singleQuoted` (POSIX `'…'` with `'\''` for embedded apostrophes), so package names and flags survive the shell parse intact. The three production `live()` factories (`BrewCommandExecutionContext.live()`, `BrewConfigRepository.live()`, `BrewInstalledPackagesRepository.live()`) all now construct `LoginShellBrewCommandRunner()`. Tests still use `BrewCommandService()` directly for raw-process plumbing tests — that's correct; the shell wrap is a live-wiring concern.
- **Out of scope (tracked separately).** `brew.env` file parsing and `BrewEnvFileLocator` assume brew sees the same world the user does, which they now do — but parser/locator changes are their own work.

## 2026-08-05 — UI-test identity module + composition-root seams (PR 1 of the UI testing plan)

- **`BrewAccessibilityID` is the single source of truth for testable element identity**, superseding the never-created `Utilities/AccessibilityIdentifiers.swift` noted in the 2026-03-01 entry. It is a dependency-free SwiftPM target linked by **both** the app and the `BrewUITests` target (`Homebrew.xcodeproj` → `packageProductDependencies` on each), so an identifier string is spelled exactly once, in `AXID.rawValue`. Views attach identity with `.axid(_:)` (`Sources/BrewUIComponents/Views/View+AXID.swift`), never `accessibilityIdentifier` with a literal. `Tests/BrewAccessibilityIDTests` pins the wire format so drift breaks a unit test rather than a UI test.
- **Parameterised cases carry the package token** (`installedRow(token:)`, `discoverRow(token:)`) — the token is the Homebrew name/token that `HomebrewPackageID.name` yields, so rows are addressable without label or index matching.
- **`.searchable` fields cannot carry a custom accessibility identifier.** SwiftUI injects the field into the window toolbar; an `.axid` at the call site lands on the modified content and overwrites the screen's own identifier. `AXID.installedSearchField` / `.discoverSearchField` therefore exist but are unattached — query `app.searchFields` until the field is a custom view.
- **Two process-boundary seams, both public and both inert in production:** `URLSessionBrewAPIClient.stubbed(protocolClasses:baseURL:)` sets protocol classes on one ephemeral session's configuration (never `URLProtocol.registerClass`, which would also capture `.shared`), and `BrewCommandExecutionContext.uiTesting(brewURL:)` uses the **real** `BrewCommandService` with `BrewExecutableLocator(overrideURL:)` and deliberately **no** `LoginShellBrewCommandRunner` — wrapping a fake brew in the user's login shell would re-introduce dotfile dependence (see 2026-06-23).
- **`BrewApp.init()` branches once, on `BrewUITestingLaunchConfiguration.current()`**, which returns `nil` unless the `-uiTesting` launch argument is present. Both seams are a single `guard` away from the untouched `.live()` wiring; being in UI-test mode is never threaded further into the app.

## 2026-08-08 — Page Object Model + deterministic UI suite (PR 2 of the UI testing plan)

- **The suite mocks two process boundaries and nothing else.** Every layer of our own code runs for real: the real `BrewCommandService` spawns a real subprocess and drains real pipes; the real `URLSessionBrewAPIClient` builds requests, negotiates ETag/304, decodes and caches. That is what makes error cases worth writing — a 500 becomes `BrewAPIClientError.httpStatus` through the actual client, not a stubbed error value.
- **One fixture tree feeds both seams.** `FakeBrew.install(scenario:)` writes a per-run temp directory containing `<scenario>/brew` (fake-brew fixtures) and `<scenario>/http` (response bodies), and hands the app the paths via launch environment. The HTTP responder lives **in the app** (`BrewUITestingStubURLProtocol`), not in `BrewUITests`: a `URLProtocol` registered in the test target runs in the *test* process and would never see the app's traffic. PR 2's plan offered both wirings; this is the one chosen.
- **HTTP fixtures are addressed by request path**, `/` → `_` (`/api/formula.json` → `api_formula.json`), with optional sibling `.status` and `.etag` files. A matching `If-None-Match` gets a real 304, so the client's conditional-request branch is exercised rather than stubbed away.
- **fake-brew is a lookup table, not a `case` over subcommands.** Files are `<argv joined by _>.stdout` / `.stderr` / `.exitcode` / `.next-info`. Adding a command to a scenario is adding a file. `.next-info` is the one piece of state: on a successful mutating run it becomes the answer to every later `brew info`, which is what lets an uninstall actually remove the row (the repository force-refreshes off the command center's running→idle transition and must see a changed world).
- **PR 1 left two repositories outside the shell seam.** `BrewInstalledPackagesRepository.live()` and `BrewConfigRepository.live()` each constructed their own `LoginShellBrewCommandRunner` + `BrewExecutableLocator`, so the Installed list and Configuration tab ran **real brew** under `-uiTesting`. Both now take a `BrewCommandExecutionContext`, and `BrewApp` builds exactly one context for the whole process. `live()` still means the same wiring it always did.
- **`BrewCommandExecutionContext.uiTesting(brewURL:)` now takes an optional.** `nil` installs a locator that always throws `BrewLookupError.executableNotFound` — that is how the `brewNotFound` scenario is expressed, and it also closes a hole: a `-uiTesting` launch that named no fake used to fall through to `.live()` and could have driven the developer's real Homebrew.
- **UI-test runs are state-isolated even though PR 2's plan defers "state isolation" to PR 3.** `CatalogueCache` / `DiscoverAnalyticsCache` are given the run's scratch container and a `UITesting.`-prefixed `UserDefaults` namespace (cleared at launch). Without this, run *N*'s fixture catalogue decides run *N+1*'s behaviour and the fixtures overwrite the real app's Application Support cache on the same machine. PR 3's isolation is about real-brew/real-network runs; this is the minimum that makes "deterministic across ≥20 runs" mean anything.
- **The console's expand/collapse state is read from the toggle button's accessibility label** ("Show console" when collapsed, "Hide console" when expanded — exactly one is mounted). The app auto-expands the panel by itself when a command starts, so a read-then-decide-then-click sequence races it; `ConsoleScreen.setExpanded(_:)` waits for the state it wants *before* concluding it needs to click.
- **`AXID` gained the shared failure chrome** (`errorState` / `errorRetryButton` on `AsyncContentView`'s error branch, `brewNotFoundState` on Configuration). It is screen-agnostic by design — every loadable surface renders the same view — so screens scope the query to their own root to say which surface failed.
- **Upgrades rows got their own identity** (`upgradesList` / `upgradesRow(token:)`) rather than reusing the Installed row ids. The same package is legitimately in both lists at once, and sharing ids would let an Upgrades assertion be satisfied by an Installed row.

## 2026-08-08 — UI-test fixtures travel in the launch environment, not on disk

- **The failure.** The obvious design — the test runner writes a fixture tree, the app reads it — needs one directory two different processes are both allowed to use, and on this machine there isn't one. `FileManager.temporaryDirectory` resolves per process, so the runner's temp dir gave the app `EPERM` when it tried to spawn the fake `brew` from it; `/private/tmp` then gave the *runner* `EPERM` creating directories. Neither cause was ever established (the runner has `ENABLE_APP_SANDBOX = NO` and Xcode's `XCTRunner.app` template carries no entitlements), and two rounds of guessing at the OS policy cost more than the redesign.
- **The fix is to delete the question.** `BrewUITestContract` (a dependency-free SwiftPM target linked by both the app and `BrewUITests`, exactly like `BrewAccessibilityID`) carries `BrewUITestingFixturePayload` — a bag of relative paths to bytes plus which one is the executable — JSON, raw-DEFLATE, base64, passed in one launch-environment variable. `BrewUITestingFixtureInstaller` writes it into the **app's own** temp directory at launch, chmods the fake, and `setenv`s the resulting paths so the stub `URLProtocol` (which runs on `URLSession` threads) and the fake `brew` subprocess (which inherits its environment) can both find them. One process creates the files, runs them, and owns them.
- **The payload is budgeted, not unbounded.** `BrewApp.launch` rejects anything over 512 KB; the tree compresses ~20× because fixture JSON is highly repetitive, so the large-inventory scenario lands well under it. If a scenario ever breaches the budget, shrink the scenario — the environment is shared with everything else the launch needs.
- **`XCUIApplication.launch()` does not reliably foreground the app on macOS.** The runner keeps focus, and a backgrounded app's window has an **empty accessibility tree** — so every element query fails with "does not exist" and the only cure is clicking the Dock icon. `BrewApp.launch` calls `activate()` and waits for `.runningForeground`. This is load-bearing, not cosmetic.
- **Element-not-found failures carry a diagnosis.** `BrewUITestDiagnostics` reports whether the app is running, foregrounded, has a window, and which identifiers are actually in the tree. "Expected installed.screen to exist within 60s" is true and explains nothing; distinguishing "never opened a window" from "wrong identifier" is the difference between a five-minute fix and a day.
- **Assertions gated on a subprocess use the command timeout, not the render timeout.** `DoctorReport.placeholder.isHealthy` is `false`, so while `brew doctor` is in flight the Doctor screen shows the redacted *issues* skeleton and the healthy text does not exist yet. Same for Configuration, whose cards only exist once `brew config` has been parsed.

## 2026-08-18 — Live end-to-end canaries (PR 3 of the UI testing plan)

- **Tier 3 is a contract canary, not coverage.** `BrewUITests/E2E/` launches the app with **no** `-uiTesting` argument, so `BrewApp.init()` takes `.live()` on both seams — real login shell, real `brew`, real `URLSession.shared`, real bottles from ghcr.io. Its job is to go red when Homebrew changes its JSON shape or CLI output while the fixture-fed Tier 2 suite stays green. It runs on the `Brew-E2E` test plan (`scripts/test-e2e`), nightly via `.github/workflows/e2e_nightly.yml` plus manually before a release, and is **skipped by name** in `Brew-UI.xctestplan` so the per-PR pipeline is never gated on live flake. Both plans hang off the one `Brew-UI` scheme; `xcodebuild -testPlan` needs the plan listed there.
- **State isolation is a split of responsibilities, not a sandbox.** Tests **arrange and clean up by shelling out** to the machine's real brew (`E2E/Brew.swift`, a `Process` helper that is a fixture actuator and never the code under test) and **act through the UI** with PR 2's page objects unchanged. A broken arrange then reads as a fixture failure instead of as a red assertion inside the flow under test. `Brew.run` throws with brew's own output attached; `Brew.forceUninstall` is best-effort because uninstalling what isn't installed exits non-zero, which is what "already clean" looks like.
- **`hello` is the canary package and this suite owns it.** GNU Hello: no dependencies, pours in seconds, and nothing on a developer machine legitimately depends on its presence. Force-uninstalled in `setUp` *and* in `tearDown` (after `super.tearDown()` has terminated the app, so cleanup never contends with a running app for Homebrew's lock). Nothing else in the repo may depend on it being installed or absent.
- **Assertions are shape, not values.** A row for the package *exists*; a `HOMEBREW_VERSION` row is *present*; install/uninstall are presence/absence *transitions* with a console that streamed non-empty output ending in success. No version, count, or machine-specific path is asserted — a formula bump must not turn a canary red, or it gets muted within a week.
- **Real lists virtualize, so live assertions filter first.** On a machine with hundreds of formulae the Installed row for `hello` may never render, and `waitToExist` would fail on a package that is genuinely installed. The live tests type into the search field before asserting on a row. The deterministic suite never had to care — its fixtures are short.
- **Determinism environment travels through the launch environment.** `Brew.determinismEnvironment` (`HOMEBREW_NO_AUTO_UPDATE`, `_NO_ANALYTICS`, `_NO_INSTALL_CLEANUP`, `_NO_ENV_HINTS`) is set on `XCUIApplication.launchEnvironment` and on the fixture actuator's own subprocess. `BrewCommandService` runs with `Environment.inherit`, and a login shell adds to exported variables rather than clearing them, so they survive `-l -i`. If a dotfile is ever found to stomp one, the fallback is an `-e2e` argument that makes `BrewCommandService` merge the keys explicitly (the same hook that conditionally sets colour env) — not needed so far.
- **upgrade and doctor are excluded by design.** Upgrade needs a deterministically outdated installed package, which a live machine cannot guarantee without brittle bottle pinning; doctor's output is entirely machine-state dependent, so it has no stable happy path. Both stay at Tier 2 with fixtures. Error cases stay at Tier 2 too — at Tier 3 an "error" is usually an outage.

## 2026-08-27 — The console assembler keeps a window of revisable rows, not a single line

- **The bug.** On a multi-cask `brew upgrade` the console repeated the whole download block every tick instead of updating it. Homebrew's parallel download queue (`download_queue.rb`) draws N rows, deliberately leaves the last one **without** a newline, then rewinds with `Tty.move_cursor_up_beginning` → `ESC[<n>F` (CPL). `TerminalLineAssembler` handled `m`/`K`/`G`/`C`/`D` and dropped everything else, so the rewind was lost. Both reported symptoms came from that one gap: the block repeated, *and* the newline-less last row spliced into the next frame's first row.
- **A single line of cells was the wrong shape**, and the old doc comment said so. The fix keeps `windowDepth` rows of history addressable rather than only the row being written. **Depth = the pty's row count**, because that *is* the screen — a terminal cannot address above it. Brew's block is `min(concurrency, Tty.height)` and `Tty.height` reads that same pty (`PseudoTerminal.defaultRows`, 40); default concurrency is `CPU cores × 2`, so 40 always covers it.
- **The non-obvious part is `\n`.** Inside a block it must **step the cursor down** (decrement `rowCursor`, reset column), *not* open a new row — only at `rowCursor == 0` does it commit. Without that the window fills with duplicates and nothing is actually fixed.
- **`windowDepth` is injected, not read.** `TerminalLineAssembler` is in `BrewCore`; `PseudoTerminal` is in `BrewCLI`, which depends on `BrewCore` and not the reverse. `BrewCLI` passes its own value in; `defaultWindowDepth` mirrors it with a comment saying why it can't reference it.
- **Rows carry a serial** so revisions coalesce per row across a chunk even when a commit shifts every position along. Offsets count **from the end**, which is what keeps them valid after `CommandJob.maxOutputLines` trims the front.
- **Over-scroll degrades to appending rather than clamping.** A move above the window is ignored — the pre-window behaviour, which looks wrong but never writes to the *wrong* row. Deliberate escape hatch for sequences this model doesn't cover (`ESC[H`, `ESC[J`, scroll regions, alt screen — brew's download queue uses none of them).
- **Trailing-newline-ness is a property of how a row ended, not of `isComplete`.** Conflating them regressed `BrewCommandServicePseudoTerminalTests`: a child that ends with `printf 'tty'` (no newline) must not gain one in `standardOutput`. `TerminalTranscript` tracks `endsWithNewline` separately so the returned transcript holds settled rows without inventing terminators.
- **Rejected: adopting SwiftTerm.** Its `Terminal` models a fixed grid + scrollback; the console models a variable-length transcript with stable row identities for SwiftUI diffing. Using the engine headless means diffing a grid to infer which rows changed — plausibly more code than this, and it fights `CONVENTIONS.md`'s "add packages sparingly". Revisit only if the app ever needs to run arbitrary interactive commands (a shell, a pager, anything using the alt screen), where hand-rolling stops being viable.

## 2026-08-30 — Colour tokens are held to WCAG AA by a calculated audit

- **The audit is a unit test over the asset catalogue, not a rendering check.** `Tests/BrewUIComponentsTests/Support/` parses `Media.xcassets` from source and computes WCAG 2.1 relative luminance / contrast ratios. It reads the JSON rather than resolving `NSColor(named:bundle:)` because **SwiftPM copies `.xcassets` into the test bundle uncompiled** — there is no `Assets.car`, so a runtime lookup silently returns `nil` under `swift test`. Do not "fix" the test by switching it to `NSColor`; it will pass vacuously.
- **The (foreground, background) pairs are hand-maintained, deliberately.** A full cross-product would demand success green stay legible on the error tint, which no screen renders, and buying that costs real chroma across the palette. When a view puts a token on a new surface, add the pair to `BrewColorTokenContrastTests.requirements`.
- **Translucent background tokens are measured over both `Surface` and `SurfaceElevated`.** The dark-mode `BrandTint` is 12% alpha, so what a selected row's text actually sits on depends on the panel behind it; the worse of the two has to pass. This is what forced the last few tenths on tertiary text and dark-mode error red.
- **Brand amber is split by role.** `color.brand.primary` stays the undiluted Homebrew amber and is **fill-only** — the pairing that must hold for it is dark `color.text.onBrand` knocked out of the fill. Amber drawn *on* an app surface uses the new `color.text.brand` (`Color.brewTextBrand`), which is darkened to `#98620F` in light mode because the brand amber is 2.4:1 on white. Reaching for `brewBrandPrimary` as a `foregroundStyle` is the mistake this split exists to prevent.
- **`CommandBlockView` deliberately does not use `Color.brewTerminal`.** Light-on-dark text under the system selection highlight is 1.01:1, and SwiftUI exposes no way to restyle that highlight. The command well is `brewSurface` (the sidebar's surface) with `brewTextPrimary`; the header and footer are `brewSurfaceRecessed`. Selection is therefore dark-on-light, which the system draws correctly, and moving the block back to the terminal surface reintroduces the defect. The console hit the same wall and solved it the other way, with an `NSTextView` (see 2026-08-31) — that route would allow the terminal look here at the cost of owning the text view.
- **Vivid colours survive as fills and glyphs, not as text.** After the AA pass the warning colour was too dark to read as a warning, so it split the same way the brand amber did: `color.status.warning` (#9B600D) is text-only, `color.status.warningBold` (#F0AD4E) is icons, dots and filled badges. The bold yellow is **deliberately** 1.95:1 as a bare glyph on white — under WCAG 1.4.11's 3:1 for non-text — because none of those glyphs carry meaning alone; each sits beside text saying the same thing. Do not "fix" it back.
- **A filled surface is audited by what is knocked out of it, not by the fill.** `BrandPrimary`, its hover/pressed states and `StatusWarningBold` are asserted against `TextOnBrand`.
- **The package-kind icon chip is an outline, not a fill.** The accent draws the glyph and a 1pt ring; the row shows through. A filled version was tried and rejected — it was the third arrangement of this chip, after a pale tint that did not separate from the row. Both parts are non-text graphics, so the chip is held to 3:1, not 4.5:1; it clears 4.5 anyway because the accent doubles as the kind badge's label colour.
- **There are two palettes, and only the high-contrast one is held to WCAG AA.** Colour sets carry High Contrast variants, which macOS swaps in on System Settings → Accessibility → Display → Increase contrast. The standard palette is the Homebrew palette as designed and several pairings sit below 4.5:1 on purpose — do not "fix" them. `BrewColorTokenContrastTests` asserts AA in the high-contrast appearances and, for the standard ones, only that high contrast never renders a pairing *worse*.
- **AppKit's fallback for a missing high-contrast variant is not observable with the system setting off.** A probe that resolves `NSColor(named:)` under `NSAppearance(named: .accessibilityHighContrastAqua)` returns the *standard* value, so it looks like a confirmed fallback order when it has confirmed nothing. Every colour set that varies by luminosity therefore states its high-contrast dark value outright, enforced by a test, and the reader only ever does exact-match-or-universal. Verify variants with `assetutil --info` on the compiled `Assets.car`, not with a runtime probe.
- **Borders are knowingly outside the audit.** `BorderDefault`/`Strong`/`Separator` sit at 1.1–1.7:1 against their surfaces. WCAG 1.4.11 wants 3:1 only for boundaries *required* to identify a control; these are decorative card edges, and raising them is a visible restyle rather than a conformance fix.

## 2026-08-31 — The console body is a text view, not a list of rows

- **What was wrong.** A `List` with one `Text` per line gives every line its own selection scope. Dragging across lines selected nothing, ⌘A had no document to select, the gaps between rows (row insets, and the empty area below the last line) weren't text at all so clicks there did nothing, and the pointer alternated between an arrow and an I-beam depending on which of those it was over. All four are the same defect: there was no document.
- **`NSTextView` is the fix, and it stays inside View + ViewModel.** `ConsoleTextView` (an `NSViewRepresentable` in `BrewFeatureConsole/Views/`) hosts a TextKit 1 text view — selectable, not editable, `isRichText = false` so ⌘C yields plain text. `ANSIConsoleText` now renders `NSAttributedString`; colours are still named on the SwiftUI token palette and bridged with `NSColor(_:)`, so the design system remains the source and light/dark still resolve. A colour-scheme flip re-renders the whole document (tracked with `@Environment(\.colorScheme)` as a *stored* dependency — reading `context.environment` inside `updateNSView` isn't a reliable invalidation trigger).
- **Streaming is a diff, not a rebuild.** `ConsoleTranscript` (ViewModels) holds the rendered lines plus their cached UTF-16 lengths and returns the minimal edit — every change `brew` makes lands in a suffix, so it is "replace from the first line that differs to the end". Rebuilding per line would be quadratic over a run **and** would drop the user's selection each time. Lines compare on stream + text only; identity is deliberately ignored because a redrawn progress row keeps its id (see 2026-08-27).
- **The renderer and the transcript must agree character-for-character.** Offsets address the rendered text, so `ConsoleTranscript.text(of:)` and `ANSIConsoleText.attributed(for:)` both emit spans-joined + `"\n"`. A unit test pins the invariant (`rendered length == transcript.length`) because nothing else would catch drift.
- **Follow-the-tail is owned by a scroll observer, not by the update.** `ConsoleOutputTextView` gives up following when the user scrolls away and takes it back when they return to the end — growing the document doesn't move the clip view, so the bounds-change notification only ever fires for a real scroll. The pin also runs from `layout()`: SwiftUI hands over the first batch of output *before* the scroll view has any size, and a scroll issued then goes nowhere (symptom: opening the console on a finished job showed the top of the log).
- **Verified by driving the real app** (DYLD-injected driver, see the 2026-08-25 note): drag across lines selects four lines; `selectAll:` validates on the first responder and selects the whole document; hit-testing the bottom edge of the output area lands on the text view (no arrow-cursor dead zone); a 200-character selection survives ~1100 characters of streamed output; scrolling away leaves the reader in place. Menu-routed ⌘A could **not** be exercised — a bare exec never becomes the key app — so that path rests on the responder validating `selectAll:`.

## 2026-08-31 — The outdated check answers from `brew info`, which brew never auto-updates

- **`brew info` is not an auto-update command.** `Library/Homebrew/utils/auto-update.sh` lists `install`, `outdated`, `upgrade`, `bundle`, `release` (plus `tap` with args). `brew info --installed --json=v2` — the app's only source of outdated state — is not among them. With the JSON API in play that is harmless: brew re-fetches `api/formula.jws.json` on its own TTL whenever a command reads it. Under **`HOMEBREW_NO_INSTALL_FROM_API` there is no such refresh** — formula and cask data come from tap git clones, so the app reported whatever the taps held the last time the user ran `brew update` by hand, forever. `BrewInstalledPackagesRepository.updateTapsIfNeeded` now runs `brew update --auto-update --quiet` (the same command `brew upgrade` runs) ahead of the info fetch, on Homebrew's own 300s interval for this mode.
- **The app cannot read `HOMEBREW_*` from its own process.** It is launched by Finder, not from a shell, so a profile-exported variable is invisible to `ProcessInfo` while being fully in effect for every brew invocation the app makes through `LoginShellBrewCommandRunner` (see 2026-06-23). `BrewConfigEnvironmentReader` asks brew instead: `brew config` prints `HOMEBREW_NO_INSTALL_FROM_API: set` **only when it is set**, so presence of the row is the signal. Probed once per process — changing it means editing a shell profile, which does not take effect for a running app anyway — and it falls back to the API path whenever `brew config` cannot be run or exits non-zero.
- **A failed tap update is deliberately not fatal.** The taps keep their previous contents, and the `brew info` fetch is what decides whether the check produced an answer at all. The *attempt* is timestamped whether or not it succeeded, so a persistently failing `brew update` cannot stall every fetch behind it (each mutating operation reconciles with a forced fetch).
- **`state` alone cannot express "the check failed".** The repository deliberately keeps cached packages `.loaded` when a refresh fails, so a surface reading only `state` presents a stale zero as fact — the app claiming "everything is up to date" when it never found out. `InstalledInventoryObserving.refreshFailure` carries the last failure, **cleared only by a fetch that completes**: clearing it in `apply(_:)` would have let a cache-first repaint (which fetches nothing) silently turn "couldn't check" back into "nothing to upgrade".
- **A revision bump moves `revision`, not `versions.stable`.** Reading `versions.stable` alone made the Upgrades tab advertise a target identical to the installed keg (ffmpeg `9.0.1` revision 1 rendered "v9.0.1 → v9.0.1"). `HomebrewPkgVersion` renders Homebrew's own `PkgVersion` (`version_revision` when the revision is non-zero) and both the `brew info` mapping and the formula catalogue go through it.
