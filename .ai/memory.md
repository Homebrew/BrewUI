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
- **JSON API schema drift:** Handle via optional decoding — never crash on unknown fields.

## 2026-03-11 — Developer Hook Workflow

- **Pre-commit enforcement:** Repository-managed pre-commit hook runs staged Swift files through Mint (`mint run swiftformat`, then `mint run swiftlint` with `--fix`, then strict `mint run swiftlint`). See **2026-04-12 — Mint for SwiftFormat and SwiftLint**.
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
- App bundle/package identifier remains unchanged for compatibility (`sh.brew.BrewUI`), while test bundle identifiers were updated to match renamed targets (`sh.brew.BrewTests` and `sh.brew.BrewUITests`).

## 2026-03-15 — Actionlint Policy-Compliant Pattern

- GitHub workflow linting should avoid `uses: docker://...` because org allowlist policy can reject it.
- Preferred pattern for this repo is Homebrew-influenced and allowlist-friendly:
  - use `Homebrew/actions/setup-homebrew@main`
  - use `Homebrew/actions/cache-homebrew-prefix@main` to install `actionlint`/`shellcheck`
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
