# CONVENTIONS.md

> Coding conventions for BrewUI — **BrewUI-specific** naming, habits, and pointers. **Does not** repeat stack, layers, constraints, or folder layout; see [`ARCHITECTURE.md`](ARCHITECTURE.md) (**Tech Stack**, **Constraints & decisions**, **File organisation**). Expand this file as real code appears. Durable **why** lives in [`.ai/memory.md`](.ai/memory.md).

## Language & platform

Stack, targets, and product constraints: [`ARCHITECTURE.md`](ARCHITECTURE.md) — **Tech Stack** and **Constraints & decisions**.

## Naming

Follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) and project **SwiftLint / SwiftFormat** config (`.swiftlint.yml`, `.swiftformat`).

**Layer naming** (roles in [`ARCHITECTURE.md`](ARCHITECTURE.md) — **Core components**):

- **Repositories:** protocol `FormulaRepository`; concrete `BrewFormulaRepository`; tests `MockFormulaRepository`. Installed inventory: `InstalledPackagesRepository` / `BrewInstalledPackagesRepository` (see **Testing** for boundary fakes).
- **Services:** subprocess execution via protocol `BrewCommandRunning` and `BrewCommandService`; resolve `brew` with `BrewExecutableLocator` conforming to `BrewExecutableLocating` (default prefix order matches product constraints in [`ARCHITECTURE.md`](ARCHITECTURE.md)).
- **Interactors:** protocol `…Interacting`; type `…Interactor`; mock `Mock…Interactor`. Skip a `Brew` prefix when the name is already clear.
- **ViewModels:** named for screen or tab (e.g. `InstalledViewModel`).

## Code style

- **Formatting / lint:** `.swiftformat`, `.swiftlint.yml` are authoritative for mechanical rules.
- **Concurrency:** do not turn off strict concurrency; protect shared mutable state (`@MainActor`, actors, `Sendable`).
- **Paths:** no hard-coded install paths — locate `brew` via `ProcessInfo` / `FileManager` (see `AGENTS.md`).
- Otherwise prefer idiomatic Swift; use Apple’s language and SwiftUI docs for general patterns.

## Design system

UI in `Brew/` uses **semantic tokens** under [`Brew/Theme/`](Brew/Theme/) (`BrewColors`, `BrewSpacing` / `BrewLayout` / `BrewRadius`, `BrewFonts`). Do not hard-code colours, spacing, or typography in feature views — **add or extend tokens** in Theme when new semantics appear. Cursor agents: see [`.cursor/rules/design-system.mdc`](.cursor/rules/design-system.mdc).

## Implementation notes

**Errors:** Prefer typed `Error` enums with associated values where useful. Separate **user-facing** copy from **technical** detail; log or preserve detail; do not swallow errors silently.

**SwiftUI:** See [SwiftUI documentation](https://developer.apple.com/documentation/swiftui). UI work on **`@MainActor`**; prefer **`.task`** over `.onAppear` for async work tied to view lifetime.

**MVVM boundary:** Keep views as passive as practical. Put view-facing UI policy, derived flags, and decision/branching logic in ViewModels (for example, split/detail visibility booleans and action-routing decisions). Views should primarily bind/render and forward actions. Keep view-layer branching limited to simple presentation branches (for example, loading/error/empty content blocks) and avoid embedding cross-state decision trees in views. Add unit tests for non-trivial ViewModel-derived UI state.

**Loadable UI state:** For screens/panels that are expected to load asynchronously and can fail, model presentation state as a single enum on the ViewModel (for example: `.loading`, `.loaded(Data)`, `.error(String)`) instead of separate `isLoading`/`data`/`error` fields. This keeps states mutually exclusive, reduces invalid combinations, and gives views a single `switch`-based rendering path.

**Documentation:** Use [DocC](https://www.swift.org/documentation/docc/) / Xcode doc comments for non-obvious `public` / `internal` API. Inline `//` explains **why**, not **what**.

**Accessibility:** Meaningful labels (and hints where needed) on interactive controls; keyboard shortcuts where it matters. **UI test IDs:** shared constants in `Utilities/AccessibilityIdentifiers.swift` — see [`ARCHITECTURE.md`](ARCHITECTURE.md) — **File organisation**; do not duplicate strings in the test target.

**Testing:** Prefer [Swift Testing](https://developer.apple.com/documentation/testing/); XCTest is fine. **Never** invoke real `brew` in tests — mock/stub only **boundaries**: `BrewCommandRunning` (subprocess) and, when needed, `BrewExecutableLocating` (e.g. `MissingBrewExecutableLocator` for “brew not found”). Prefer **slice tests** that use the real `BrewInstalledPackagesRepository` (and thus real parsing) with those fakes; shared helpers live under [`BrewTests/TestSupport/`](BrewTests/TestSupport/). Pure presentation tests may use `InstalledViewModel`’s `init(testing…)` without a repository. Cover errors and async paths, not only happy paths. See [`ARCHITECTURE.md`](ARCHITECTURE.md) for layer flow.

**Test shape:** Prefer **one logical behavior per `@Test`** — typically a **single `#expect`**, or **one** equality check on a small `Equatable` snapshot (e.g. expected rows + errors + flags) so related outcomes stay one assertion. **`BrewInstalledPackagesRepository.live()`** is not a unit-test target: it wires real `BrewCommandService` and filesystem discovery; rely on slice tests with fakes and UI/manual smoke if needed.

## Dependencies

- Prefer Foundation / SwiftUI. Add packages sparingly; justify in `Package.swift` and lock versions.

## Git & commits

- Imperative subject lines (*Add …*, not *Added …*). One logical change per commit when practical.

## Updating this file

Add patterns when they stabilize in code. Cross-cutting decisions go in `.ai/memory.md`.
