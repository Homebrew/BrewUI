# CONVENTIONS.md

> Coding conventions for BrewUI — **BrewUI-specific** naming, habits, and pointers. **Does not** repeat stack, layers, constraints, or folder layout; see [`ARCHITECTURE.md`](ARCHITECTURE.md) (**Tech Stack**, **Constraints & decisions**, **File organisation**). Expand this file as real code appears. Durable **why** lives in [`.ai/memory.md`](.ai/memory.md).

## Language & platform

Stack, targets, and product constraints: [`ARCHITECTURE.md`](ARCHITECTURE.md) — **Tech Stack** and **Constraints & decisions**.

## Naming

Follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/) and project **SwiftLint / SwiftFormat** config (`.swiftlint.yml`, `.swiftformat`).

**Layer naming** (roles in [`ARCHITECTURE.md`](ARCHITECTURE.md) — **Core components**):

- **Repositories:** protocol `FormulaRepository`; concrete `BrewFormulaRepository`; tests `MockFormulaRepository`.
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

**Documentation:** Use [DocC](https://www.swift.org/documentation/docc/) / Xcode doc comments for non-obvious `public` / `internal` API. Inline `//` explains **why**, not **what**.

**Accessibility:** Meaningful labels (and hints where needed) on interactive controls; keyboard shortcuts where it matters. **UI test IDs:** shared constants in `Utilities/AccessibilityIdentifiers.swift` — see [`ARCHITECTURE.md`](ARCHITECTURE.md) — **File organisation**; do not duplicate strings in the test target.

**Testing:** Prefer [Swift Testing](https://developer.apple.com/documentation/testing/); XCTest is fine. **Never** invoke real `brew` in tests — mock/stub subprocesses. Cover errors and async paths, not only happy paths. Unit tests can target parsing/decoding and view models with mocked repositories per [`ARCHITECTURE.md`](ARCHITECTURE.md).

## Dependencies

- Prefer Foundation / SwiftUI. Add packages sparingly; justify in `Package.swift` and lock versions.

## Git & commits

- Imperative subject lines (*Add …*, not *Added …*). One logical change per commit when practical.

## Updating this file

Add patterns when they stabilize in code. Cross-cutting decisions go in `.ai/memory.md`.
