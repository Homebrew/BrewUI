# CONVENTIONS.md
> Coding conventions, naming standards, and patterns for BrewUI.
> All agents and contributors should follow these. Update this file when new patterns are established — don't let it fall out of sync.

---

## Language & Platform

- **Platform:** macOS (native)
- **Primary language:** Swift / SwiftUI
- **Minimum macOS version:** _[To be confirmed once prototype is migrated]_
- **Dependency manager:** Swift Package Manager (SPM)

---

## Naming Conventions

> **Source of truth:** [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
> The following summarises the most relevant rules. When in doubt, defer to the official guidelines.

### Files
- Named after the primary type they define, in `UpperCamelCase` — e.g. `PackageListView.swift`, `BrewService.swift`.
- One primary type per file. Small supporting types (e.g. a private helper struct) may live in the same file if they exist solely to support it.
- Test files mirror their source counterpart with a `Tests` suffix — e.g. `BrewServiceTests.swift`.

### Types (classes, structs, enums, protocols, typealiases)
- `UpperCamelCase` — e.g. `Package`, `InstallState`, `BrewServiceProtocol`.
- Protocols describing what something **is** use nouns — e.g. `Collection`, `Publisher`.
- Protocols describing a **capability** use `-able`, `-ible`, or `-ing` suffixes — e.g. `Equatable`, `ProgressReporting`.
- Enum cases: `lowerCamelCase` — e.g. `case notInstalled`, `case installing`.

### Functions & Methods
- `lowerCamelCase` — e.g. `fetchInstalledPackages()`, `uninstall(_ package: Package)`.
- Name for **clarity at the point of use**, not brevity at the point of definition.
- Mutating/non-mutating pairs should be consistent: non-mutating returns a new value (`sorted()`), mutating modifies in place (`sort()`).
- Boolean methods and properties read as assertions — e.g. `isEmpty`, `isInstalled`, `canUpdate`.
- Omit needless words; don't repeat type information already visible from context.

### Variables & Constants
- `lowerCamelCase` for both — e.g. `let packageName`, `var installedPackages`.
- Use `let` by default; reach for `var` only when mutation is genuinely needed.
- No Hungarian notation or type suffixes in variable names — not `packageArray`, `nameString`.
- Avoid abbreviations unless they are universally understood (e.g. `url`, `id` are fine; `pkg`, `mgr` are not).

---

## Code Style

> **Official formatter:** [`swift-format`](https://github.com/swiftlang/swift-format) (the Swift project's own tool — prefer this over third-party linters as the primary style enforcer).

- **Indentation:** 4 spaces (Xcode and `swift-format` default).
- **Line length:** 100 characters (a reasonable default; adjust in `.swift-format` config if needed once the project structure is confirmed).
- Prefer clarity over brevity — this is a first-party principle from the Swift API Design Guidelines.
- Avoid magic numbers and magic strings — use named constants with a comment if the name alone isn't self-explanatory.
- Prefer value types (`struct`, `enum`) over reference types (`class`) unless you need reference semantics, inheritance, or `@Observable`/Combine integration.
- Use `guard` for early exits rather than deeply nested `if` statements.

---

## Error Handling

> Swift's error handling model: [The Swift Programming Language — Error Handling](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/errorhandling/)

- Define typed errors using `enum` conforming to `Error`, with associated values where appropriate.
- Never use `try!` anywhere — production or tests. In production, handle or propagate errors properly. In tests, a thrown error should fail the test cleanly, not crash the process mid-run.
- Never use force-unwrap (`!`) anywhere — production or tests. Use unwrapping assertions instead: `XCTUnwrap` in XCTest, or [`#require`](https://developer.apple.com/documentation/testing/require(_:_:sourceLocation:)-5l63q) in Swift Testing. These fail the test with a clear message rather than crashing.
- Reserve `try?` for cases where failure is genuinely uninteresting and you have explicitly decided to discard the error — add a comment explaining that decision.
- Never silently swallow errors. At minimum, log; ideally surface meaningfully to the user.

---

## Documentation Comments

> **Source of truth:** [DocC documentation](https://www.swift.org/documentation/docc/) and [Xcode doc comment format](https://developer.apple.com/documentation/xcode/writing-symbol-documentation-in-your-source-files)

- Use `///` (triple-slash) for all documentation comments — Xcode and DocC recognise this format.
- Document all `public` and `internal` types, methods, and properties unless they are trivially self-evident.
- Use structured markup for parameters, return values, and thrown errors:

```swift
/// Fetches the list of packages currently installed via Homebrew.
///
/// - Returns: An array of ``Package`` values representing installed formulae.
/// - Throws: ``BrewError.notInstalled`` if Homebrew cannot be located.
func fetchInstalledPackages() async throws -> [Package]
```

- Inline comments (`//`) should explain **why**, not **what**. The code itself should make the *what* obvious.
- Mark technical debt and workarounds clearly:

```swift
// TODO: Replace with structured JSON output once brew supports --json here
// FIXME: This crashes if brew exits with code 127 on some M1 setups (#42)
```

---

## Testing

> **Framework:** [Swift Testing](https://developer.apple.com/documentation/testing/) (preferred for new tests) or XCTest.
> Swift Testing is the modern Apple-first framework introduced at WWDC 2024.

- Test files live in a `Tests/` target within the Swift package.
- Test names should read as sentences describing the behaviour under test — e.g. `testFetchReturnsEmptyArrayWhenBrewNotInstalled`.
- Mock/stub Homebrew CLI interactions — tests should never invoke real `brew` subprocesses.
- Never use `try!` or force-unwrap (`!`) in tests — a crashing test gives no useful failure message and can prevent other tests from running. Use `XCTUnwrap` (XCTest) or `#require` (Swift Testing) to unwrap optionals and propagate thrown errors as clean test failures.
- _[Further testing conventions to be filled in once prototype is migrated]_

---

## Git & Commits

- Commit messages: imperative mood — "Add package list view", not "Added" or "Adding".
- One logical change per commit. Do not mix feature changes with refactors.
- Branch naming: _[To be confirmed — e.g. `feature/`, `fix/`, `chore/`]_

---

## Updating This File

When a new pattern or convention is established, add it here with a rationale if non-obvious. If the decision is significant, create an ADR in `docs/adr/` and link to it from the relevant section.
