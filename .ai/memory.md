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

## 2026-05-03 — BrewCommandCenter + operation IDs

- **Protocol `BrewCommandCenter`:** `actor` protocol — `submit(id:command:)`, `phase(for:)`, `phaseByID()` (full snapshot map), `isActive(id:)` (all `async` from callers).
- **`BrewMutatingCommand`:** `Sendable` command pattern — `var operationKind`, `func run(in: BrewCommandExecutionContext) async throws` (no caller closures; kind is not duplicated at `submit`).
- **`BrewCommandExecutionContext`:** `commandRunner` (`BrewCommandRunning`) + `brewExecutableURL()` via `locator` (`BrewExecutableLocating`).
- **`SerialBrewCommandCenter`:** `actor`; **`SerialBrewWorkQueue`** inner actor ensures **one mutating command at a time** across `await`; duplicate **`BrewOperationID`** coalesces via shared **`Task`** handle.
- **`OperationFailure`:** `Sendable` `enum` (`.brewCommand`, `.brewLaunchFailed`, `.brewExecutableNotFound`, `.generic`) for **`BrewOperationPhase.failed(reason:)`**; `init(catching:)` maps `BrewCommandError`, `BrewLookupError`, and other errors to cases; **`userFacingMessage`** is a derived line for UI.
- **Transport types (`BrewOperationModels.swift`):** `BrewOperationKind`, `BrewOperationID`, `BrewOperationPhase`.
- **Domain package discriminator:** `HomebrewPackageKind`; `InstalledPackageKind` typealias; **`BrewOperationID.init(kind:name:)`** in **`BrewOperationID+Homebrew.swift`**.
- **Composition:** **`BrewApp`** holds **`SerialBrewCommandCenter(executionContext: .live())`** and applies **`.environment(\.brewCommandCenter, center)`** (SwiftUI **`@Entry`** on **`EnvironmentValues.brewCommandCenter`**, type **`(any BrewCommandCenter)?`**, default `nil`) to **`MainWindowView`**. Feature views and view models that need the center should read **`@Environment(\.brewCommandCenter)`** (or take it in **`init`** from a parent that reads the environment). Previews use **`.environment(\.brewCommandCenter, NoopBrewCommandCenter.preview())`**; command-center unit tests still construct **`SerialBrewCommandCenter`**, **`NoopBrewCommandCenter.forTesting()`**, or **`RecordingSerialBrewCommandCenter`** directly (or the same **`.environment`** when hosting SwiftUI).
