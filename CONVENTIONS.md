# CONVENTIONS.md
> Coding conventions, naming standards, and patterns for BrewUI.
> All agents and contributors should follow these. Update this file when new patterns are established — don't let it fall out of sync.

## Document scope

- **This file owns:** naming conventions, implementation patterns, error-handling and testing practices, documentation comment expectations, and git/commit habits.
- **This file does not own:** layer topology, data flow, folder layout, or platform/toolchain baseline — see [`ARCHITECTURE.md`](ARCHITECTURE.md).
- **Cross-reference:** when guidance would duplicate `ARCHITECTURE.md`, add a short pointer instead of copying the text.

## Documentation ownership matrix

| Topic | Canonical location |
|---|---|
| Layers, responsibilities, data flow | [`ARCHITECTURE.md`](ARCHITECTURE.md) |
| Tech stack, macOS targets, deployment | [`ARCHITECTURE.md`](ARCHITECTURE.md) |
| File/folder layout; accessibility ID file location | [`ARCHITECTURE.md`](ARCHITECTURE.md) |
| Naming rules, style, testing/accessibility *how-to* | This file (`CONVENTIONS.md`) |
| Durable rationale and decision history | [`.ai/memory.md`](.ai/memory.md) |

---

## Language & Platform

For **macOS targets**, **Swift** version and concurrency mode, **SwiftUI** vs AppKit, **SPM**, **data sources**, and **deployment** assumptions, see [`ARCHITECTURE.md`](ARCHITECTURE.md) — **Tech Stack** and **Constraints & Decisions**.

---

## Naming Conventions

> **Source of truth:** [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
> The following summarises the most relevant rules. When in doubt, defer to the official guidelines.

### Files
- One primary type per file. Small supporting types (e.g. a private helper struct) may live in the same file if they exist solely to support it.
- Test files mirror their source counterpart with a `Tests` suffix — e.g. `BrewCommandServiceTests.swift`.

### Types (classes, structs, enums, protocols, typealiases)
- Protocols describing what something **is** use nouns — e.g. `Collection`, `Publisher`.
- Protocols describing a **capability** use `-able`, `-ible`, or `-ing` suffixes — e.g. `Equatable`, `ProgressReporting`.

### Architecture-specific naming

Layer roles and where each kind of type lives are defined in [`ARCHITECTURE.md`](ARCHITECTURE.md) — **Core Components** and **File Organisation**. Apply these **naming** rules on top of that structure:

- **Repository protocols** are named for the resource (e.g. `FormulaRepository`). The `Brew` prefix belongs on the concrete implementation (e.g. `BrewFormulaRepository`). Test doubles use the `Mock` prefix (e.g. `MockFormulaRepository`).
- **Interactor protocols** use the `-Interacting` suffix; implementations use `-Interactor` (e.g. `RunDoctorInteracting` / `RunDoctorInteractor` / `MockRunDoctorInteractor`). No `Brew` prefix when the type name is already self-explanatory.
- **ViewModels** are named after the screen or tab they serve (e.g. `InstalledViewModel`, `DiscoverViewModel`).
- Keep names concise and self-documenting — prefer `RunDoctorInteractor` over `BrewRunDoctorInteractor` when the context is clear.

### Functions & Methods
- Name for **clarity at the point of use**, not brevity at the point of definition.
- Mutating/non-mutating pairs: non-mutating returns a new value (`sorted()`), mutating modifies in place (`sort()`).
- Boolean methods and properties read as assertions — e.g. `isEmpty`, `isInstalled`, `canUpdate`.
- Omit needless words; don't repeat type information already visible from context.

### Variables & Constants
- Use `let` by default; reach for `var` only when mutation is genuinely needed.
- No Hungarian notation or type suffixes — not `formulaArray`, `nameString`.
- Avoid abbreviations unless universally understood — `url` and `id` are fine; `pkg`, `fml`, `mgr` are not.

---

## Code Style

> **Formatting and linting:** Enforce mechanically checkable style in tool config (`.swiftformat`, `.swiftlint.yml`) rather than duplicating those rules here.

Concurrency targets and async I/O expectations are set in [`ARCHITECTURE.md`](ARCHITECTURE.md) — **Tech Stack** and **Data Flow**. In code:

- **Concurrency:** All shared mutable state must be protected — via actors, `@MainActor`, or `Sendable` conformances. Do not disable concurrency checks.
- **Async/await:** Use `async`/`await` for all I/O and command execution. Avoid completion handlers. Never block the main thread.
- Prefer value types (`struct`, `enum`) over reference types (`class`) unless reference semantics, inheritance, or `@Observable` integration require it.
- Use `guard` for early exits rather than deeply nested `if` statements.
- Avoid magic numbers and magic strings — use named constants with a comment if the name alone is not self-explanatory.
- Prefer clarity over brevity — this is a first-party principle from the Swift API Design Guidelines.
- Avoid global mutable state — prefer environment objects or injected dependencies.
- Hard-coded paths are forbidden — use `ProcessInfo.processInfo.environment` or `FileManager` to locate `brew`.

---

## Error Handling

> Swift's error handling model: [The Swift Programming Language — Error Handling](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/)

- Define typed errors using `enum` conforming to `Error`, with associated values where appropriate. Domain-specific types include `BrewCommandError`, `JSONParseError`, `InstallationError`.
- User-facing error messages must be separate from technical details. Show a friendly message to the user; log the full technical error internally.
- Provide suggested recovery actions in error UI where possible.
- Reserve `try?` for cases where failure is genuinely uninteresting and you have explicitly decided to discard the error — add a comment explaining that decision.
- Never silently swallow errors. At minimum, log; ideally surface meaningfully to the user.

---

## SwiftUI Best Practices

> Reference: [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)

View thinness and when to extract subviews are described in [`ARCHITECTURE.md`](ARCHITECTURE.md) — **Core Components** (Views).

- Use `@ViewBuilder` for conditional view logic.
- Prefer `.task {}` over `.onAppear {}` for async work — `.task` is lifecycle-aware and cancels automatically.
- Use custom view modifiers for repeated styling rather than duplicating modifiers inline.
- Use environment objects for cross-feature state.
- Annotate all UI-touching code with `@MainActor`.

---

## Documentation Comments

> **Source of truth:** [DocC documentation](https://www.swift.org/documentation/docc/) and [Xcode doc comment format](https://developer.apple.com/documentation/xcode/writing-symbol-documentation-in-your-source-files)

- Document all `public` and `internal` types, methods, and properties unless they are trivially self-evident.
- Use structured markup for parameters, return values, and thrown errors:

```swift
/// Fetches the list of formulae currently installed via Homebrew.
///
/// - Returns: An array of ``Formula`` values representing installed formulae.
/// - Throws: ``BrewCommandError.notFound`` if Homebrew cannot be located.
func fetchInstalledFormulae() async throws -> [Formula]
```

- Inline comments (`//`) should explain **why**, not **what**. The code itself should make the *what* obvious.
- Mark technical debt and workarounds clearly:

```swift
// TODO: Replace with structured JSON output once brew supports --json here
// FIXME: This crashes if brew exits with code 127 on some M1 setups (#42)
```

---

## Accessibility

> Reference: [Apple Accessibility Guidelines](https://developer.apple.com/documentation/accessibility)

- **All interactive UI elements** must have accessibility labels (and hints where they clarify behaviour) so VoiceOver and other assistive technologies describe them correctly. Use `.accessibilityLabel(_:)` and `.accessibilityHint(_:)`.
- Use semantic SwiftUI controls (`Button`, `NavigationLink`, `Toggle`) so the accessibility tree stays meaningful — avoid recreating native behaviour with custom gestures.
- Provide **standard keyboard shortcuts** where applicable (e.g. ⌘R for refresh, Escape to cancel). Use `.keyboardShortcut(_:)` and document shortcuts in tooltips or help text.
- Aim for a VoiceOver-friendly view hierarchy: logical order, no redundant elements, grouped content with `.accessibilityElement(children: .combine)` where appropriate.
- Ensure sufficient colour contrast and support Dynamic Type where feasible.

### Accessibility identifiers for UI tests
- All elements used in UI tests must have an accessibility identifier set via `.accessibilityIdentifier(_:)`.
- **Single source of truth for file location and target wiring:** see [`ARCHITECTURE.md`](ARCHITECTURE.md) — **File Organisation** (`Utilities/AccessibilityIdentifiers.swift`). Do not duplicate identifier strings in the test target — import the shared constants.
- Use stable, semantic IDs that survive copy and layout changes — e.g. `sidebar.installed`, `toolbar.search`, `doctor.runButton`.
- When adding a new screen or primary control, add its identifier to the shared constants first, then set it on the view.

---

## Testing

> **Framework:** [Swift Testing](https://developer.apple.com/documentation/testing/) (preferred for new tests) or XCTest.
> Swift Testing is the modern Apple-first framework introduced at WWDC 2024.

- Test files live in a `Tests/` target within the Swift package.
- Test names should read as sentences describing the behaviour under test — e.g. `testFetchReturnsEmptyArrayWhenBrewNotInstalled`.
- **Unit tests cover:** command/output parsing (in Interactors or Models), JSON decoding, and ViewModels (with mocked Repositories). Mock Repositories — not just `BrewCommandService` — so that ViewModel presentation logic is isolated from data concerns.
- **UI tests:** use the shared accessibility identifier constants (see [`ARCHITECTURE.md`](ARCHITECTURE.md) — **File Organisation**). Do not hard-code identifier strings in the test target.
- Test async flows using Swift Concurrency testing support.
- Test error paths and edge cases explicitly — not just the happy path.
- Mock and stub all `brew` CLI interactions — tests must never invoke real `brew` subprocesses.

---

## Dependencies

- Avoid external dependencies where possible. Foundation and SwiftUI cover most needs.
- If a dependency is needed, prefer well-maintained packages from Apple or the Swift open-source community.
- Every dependency must have a documented justification — add a comment in `Package.swift` explaining why it is needed.
- Version-lock all dependencies for build stability.

---

## Git & Commits

- Commit messages: imperative mood — "Add package list view", not "Added" or "Adding".
- One logical change per commit. Do not mix feature changes with refactors.

---

## Updating This File

When a new pattern or convention is established, add it here with a rationale if non-obvious. If the decision is significant or cross-cutting, also record it in `.ai/memory.md` and link or reference that entry from the relevant section if helpful.
