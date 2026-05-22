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

## Folder boundaries

- **Feature layout:** Each feature folder uses `Views/` and `ViewModels/`. Place feature `*Item` types and viewmodel-local presentation helpers in `ViewModels/`.
- **Domain models only:** `Models/` is for domain value types/relationships only. Do not place UI/presentation helpers, command/API transport payloads, or infrastructure cache snapshots there.
- **UI-related types:** Put feature-specific UI/presentation types in the relevant feature folder (`Features/<Feature>/Views` or `Features/<Feature>/ViewModels`), not in `Models/`.
- **Brew command transport/state:** Keep brew command execution, command-center types, command operation models, and `brew info` command JSON decoding under `Services/BrewCommand/`.
- **Networking transport:** Keep API client and its transport payloads/errors grouped together under a dedicated services networking boundary (for example `Services/API/` when introduced).
- **DB transport:** Keep DB models/mappers alongside DB access layer types under one DB boundary folder (for example `Services/Database/` or `Repositories/Database/`), not in `Models/`.

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

**Repository boundary:** Repositories are data-access adapters. They fetch/parse/map source data and expose that data to the app, but they do not invent extra informational or presentation values beyond what the source provides. Any hardcoded informational text, user guidance, or display-only derived strings belong in ViewModel/View layers (or another presentation-oriented layer), not repositories.

**Transport boundary:** Do not expose `Codable` transport payload types (`*JSON`, DTOs, wire models) from service or repository APIs. Decode transport payloads at the boundary, then map to app-facing domain models (`Models/`) or explicit feature-layer data contracts before returning.

**Command transparency:** When the UI exposes a Homebrew command, render a **copyable, user-facing command** that a person can run in Terminal (for example, `brew info <name>`). Do not display internal implementation flags used only for app parsing/workflow (for example, `--json=v2`) in user-visible command text.

**MVVM boundary:** Keep views as passive as practical. Put view-facing UI policy, derived flags, and decision/branching logic in ViewModels (for example, split/detail visibility booleans and action-routing decisions). Views should primarily bind/render and forward actions. Keep view-layer branching limited to simple presentation branches (for example, loading/error/empty content blocks) and avoid embedding cross-state decision trees in views. Add unit tests for non-trivial ViewModel-derived UI state.

**Passive view enforcement:** A view must not compose multiple ViewModel booleans (or other raw state primitives) inline to derive a single UI concern. If a UI element has one presentation state (for example, showing one spinner), expose one ViewModel property for that state and bind directly to it.

**ViewModel itemization:** When a ViewModel grows with mapped presentation fields that broadly change together, extract that co-changing mapping into feature-layer `*Item` types and expose those items from the ViewModel for subviews to consume. Keep independently-changing async stream state (for example, `isUpgrading` / `isUninstalling`) on the top-level ViewModel.

**Domain-to-presentation mapping boundary:** Do not add UI-facing presentation properties/extensions directly on domain model types. Map domain models into presentation in one of two places only: (1) feature ViewModels for top-level surfaces, or (2) feature `*Item` types for subview/action-specific presentation data.

**Package-domain lookup identity:** Any domain model that represents a Homebrew package (or list item directly backed by one) must expose a `HomebrewPackageReference` property for stable formula/cask lookup (`.formula(name:)` for formulae, `.cask(token:)` for casks).

**Root view dependency ownership:** When a feature defines a `*Root` view wrapper, the root is the dependency-composition boundary for that surface. Root views must read app-level dependencies (for example `@Environment` values), construct and inject content-view dependencies, and own view-model lifecycle boundaries. Content views must focus on rendering and behavior and must not acquire those app-level dependencies directly when a root exists.

**Anti-pattern to avoid:** Do not make a content view model optional only to work around dependency acquisition inside the content view. Keep dependency resolution in the root and inject non-optional dependencies into the content view.

**URL presentation:** Any user-facing web URL (`http`/`https`) shown in the UI should be rendered as a tappable `Link` that opens the default browser, while still showing the literal URL text for transparency.

**Loadable UI state:** For screens/panels that are expected to load asynchronously and can fail, model presentation state as a single enum on the ViewModel (for example: `.loading`, `.loaded(Data)`, `.error(String)`) instead of separate `isLoading`/`data`/`error` fields. This keeps states mutually exclusive, reduces invalid combinations, and gives views a single `switch`-based rendering path.

**Previews:** Use centralized preview data/mocks from `Brew/PreviewSupport/AppPreviewSupport.swift`; do not define one-off inline mock repositories/services in preview blocks. Add new preview sample data and lightweight preview fakes to that file so it remains the single source of truth.

**Preview placement:** Keep each view’s `#Preview` blocks at the bottom of the same file as that view, not in standalone `+Previews.swift` files.

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
