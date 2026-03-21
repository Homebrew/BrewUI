# ARCHITECTURE.md
> High-level system design for BrewUI.
> Consult this before making structural changes. Update it when the layout of the system changes. Describe *what* exists and how it fits; add brief rationale only for *unusual* choices. Record durable decisions and their full rationale in `.ai/memory.md`.

---

## Overview

**BrewUI** is a native macOS GUI that makes Homebrew approachable for users who prefer graphical interfaces over Terminal, while maintaining complete transparency about underlying Homebrew operations.

**Mission:** Enable CLI-averse users to safely discover, install, update, and manage Homebrew packages through a native SwiftUI interface that never hides what Homebrew is doing.

---

## Tech Stack

| Concern | Choice |
|---|---|
| Language | Swift 6.0 (strict concurrency mode) |
| UI Framework | SwiftUI — pure; use AppKit only when SwiftUI cannot meet a requirement |
| State management | `@Observable` (Swift 5.9+) |
| Concurrency | `async`/`await` throughout; actor isolation for shared mutable state |
| Package manager | Swift Package Manager |
| macOS targets | Tahoe 26, Sequoia 15, Sonoma 14 — **minimum: Tahoe 26** |
| Data sources | Homebrew JSON API (`formulae.brew.sh`) + `brew` CLI subprocess |
| Deployment | Unsandboxed macOS app (default Homebrew prefix) |

---

## System Diagram

```
┌──────────────────────────────────────────────────────────────┐
│                    BrewUI (macOS App)                        │
│                                                              │
│  ┌──────────────┐        ┌──────────────────────────────┐   │
│  │    Views     │───────▶│  ViewModels (presentation)   │   │
│  │  (SwiftUI)   │        └──────────┬───────────────────┘   │
│  └──────────────┘                   │                        │
│                          ┌──────────┴──────────┐            │
│                          ▼                     ▼            │
│               ┌────────────────┐   ┌────────────────────┐   │
│               │  Repositories  │   │    Interactors     │   │
│               │  (CRUD / data) │   │    (use cases)     │   │
│               └───────┬────────┘   └─────────┬──────────┘   │
│                       │                      │               │
│                  ┌────┴──────────────────────┴────┐         │
│                  │           Services              │         │
│                  │  BrewCommandService             │         │
│                  │  JSONAPIService                 │         │
│                  └────────────────┬───────────────┘         │
└───────────────────────────────────┼────────────────────────-┘
                                    │
              ┌─────────────────────┴──────────────────────┐
              │  External                                   │
              │  ├── brew CLI (subprocess)                  │
              │  └── formulae.brew.sh JSON API              │
              └─────────────────────────────────────────────┘
```

---

## Core Components

### Views (SwiftUI layer)
- Thin. Bind to ViewModel state and invoke ViewModel actions. No business logic or parsing.
- Extract subviews when a view body exceeds ~100 lines.
- One primary View per feature/screen (e.g. `InstalledView`, `DiscoverView`).
- Reusable components (shared across features) live in `Views/`.

### ViewModels (Presentation layer)
- Hold state the View needs; map data to UI-ready representations.
- Own transient UI state (e.g. `searchQuery`, `isLoading`, `selection`, sheet visibility) when Repositories cannot own it.
- Properties and function names map directly to View components (e.g. `toolbarTitle`, `packageRows`, `onPackageTapped`).
- **Business logic does not live here** — it belongs in Interactors or Models.
- Keep testable logic in the ViewModel, not in the View; Views remain thin and declarative.
- One ViewModel per tab/screen: `InstalledViewModel`, `DiscoverViewModel`, etc.

### Repositories (Data / CRUD layer)
- Abstract **CRUD operations on a data source** — the contract you'd swap if the backing store changed.
- Implementations may be: CLI (via `BrewCommandService`, treating output as fetched/cached data), JSON API (via `JSONAPIService`), SwiftData/UserDefaults, or in-memory.
- Caching and cache invalidation are implementation details of the repository.
- Can expose async sequences or callbacks for live updates.

### Interactors (Use-case layer)
- Carry out **a single use case** that is not a CRUD operation on a stored data source.
- Examples: running `brew doctor` and mapping its output to structured issues; running `brew config` and returning key/value pairs.
- Defined by a protocol per use case so implementations can be swapped (real vs. mock) for testing.
- May call Services and Repositories; return a typed domain result.
- Do **not** use a Repository for run-and-return workflows with no notion of persistence.

### Services
- Low-level infrastructure shared by Repositories and Interactors.
- **`BrewCommandService`**: spawns and manages `brew` subprocesses, streams stdout/stderr line-by-line, handles cancellation, exposes `CommandJob`.
- **`JSONAPIService`**: fetches and decodes Homebrew JSON API responses.

### Models
- Shared domain types: `Formula`, `CommandJob`, `BrewConfig`, etc.
- May encapsulate domain rules and pure functions (e.g. parsing `brew list` output into `[Formula]`).
- Keep Views and ViewModels free of parsing and validation details.

---

## File Organisation

```
Features/         ← One folder per major feature (Installed, Discover, Updates, Doctor, Config, …)
│                   Each may contain: View, ViewModel, and optionally a feature-local Interactor.
Models/           ← Shared domain types (Formula, CommandJob, BrewConfig, …)
Repositories/     ← Protocols + implementations for CRUD on a data source
Interactors/      ← Protocols + implementations for use cases
Services/         ← BrewCommandService, JSONAPIService
Views/            ← Reusable UI components shared across features
Utilities/        ← Extensions, helpers, constants
└── AccessibilityIdentifiers.swift  ← single source of truth for accessibility IDs;
                                       compiled into both the app and UI test targets
```

---

## Data Flow

1. User triggers an action in the UI (e.g. "Install package").
2. View calls ViewModel action.
3. ViewModel delegates to Repository or Interactor.
4. Repository/Interactor calls `BrewCommandService` (or `JSONAPIService`).
5. Service streams output line-by-line; updates `CommandJob` state.
6. ViewModel receives structured result and updates published properties.
7. View re-renders reactively via `@Observable`.

---

## Command Execution Pattern

All Homebrew commands are executed asynchronously with streamed output via `Process`. Commands are cancellable; status is tracked as `queued / running / success / failure`. stdout and stderr are parsed separately. Full output is always preserved for session logs and user transparency.

```swift
// Step 1: build command array
let args = ["brew", "info", "wget"]

// Step 2: create Process with stdout/stderr pipes
// Step 3: stream output line-by-line into CommandJob.output
// Step 4: parse exit code for success/failure
// Step 5: update UI state on @MainActor
// Step 6: preserve full command string and output for logs

@Observable
class CommandJob: Identifiable {
    let id = UUID()
    let command: String
    var status: JobStatus
    var output: [String]
    var exitCode: Int32?
}
```

---

## JSON API Integration

- Endpoints: `https://formulae.brew.sh/api/formula.json` and `cask.json`
- Decode incrementally for large datasets (consider a streaming parser if performance requires it)
- Cache with timestamp; invalidate on `brew update`
- Merge with `brew info` output for live install status and version data
- Handle schema changes gracefully via optional decoding — do not crash on unknown fields

Reference: [Homebrew JSON API docs](https://formulae.brew.sh/docs/api/)

---

## UX Principles

These are first-class architectural constraints — they determine what guarantees the app must uphold at every layer, not just what the UI looks like.

**Approachable First** — Plain language in UI strings; no jargon; SF Symbols for affordance; tooltips for technical terms; "what this does" explanations before destructive actions.

**Safe by Default** — Confirmation dialogs for install/uninstall/upgrade; disable conflicting actions during ongoing operations; show command preview before execution; validate exit codes with user-friendly error messages.

**Transparent** — Always show the underlying `brew` command being run; live output console available for every operation; session logs with copy/export; no "magic" behind the scenes.

**Progressive Disclosure** — Simple primary actions visible by default; advanced options in disclosure groups; technical details (JSON, exit codes) available but not prominent; command output collapsed by default after success, expandable on demand.

---

## Constraints & Decisions

- **macOS-only.** No iOS, iPadOS, or cross-platform considerations.
- **Default Homebrew prefix only.** `/opt/homebrew` (Apple Silicon) or `/usr/local` (Intel). No custom prefix support initially.
- **No custom taps initially.** Scope limited to the core Homebrew tap.
- **`brew` is the source of truth.** BrewUI never manipulates Homebrew internals directly.
- **Transparency is non-negotiable.** Command execution is always visible to the user.
- **Homebrew must be installed separately.** BrewUI detects it and degrades gracefully if absent; it does not bundle Homebrew.
- **Homebrew detection.** Locate `brew` by checking known standard paths: `/opt/homebrew/bin/brew` (Apple Silicon) and `/usr/local/bin/brew` (Intel).
- **Open source.** Code must be well-commented and follow consistent patterns suitable for public contributors.

### Platform constraints that affect implementation

- **Homebrew output drift**: `brew` text output is not a strict API; parsers need tolerant handling and fallback behavior.
- **JSON API schema drift**: API contracts can evolve; decoding must have explicit resilience paths.
- **UI test stability on macOS**: asynchronous command output and sheet/dialog timing can make UI tests flaky without deliberate synchronization.
- **Accessibility for desktop workflows**: keyboard navigation/shortcuts and VoiceOver semantics need explicit validation, not just labels.

---

## Resources

- [Homebrew JSON API](https://formulae.brew.sh/docs/api/)
- [Homebrew Man Pages](https://docs.brew.sh/Manpage)
- [Homebrew Formula Cookbook](https://docs.brew.sh/Formula-Cookbook)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)

---

## Updating This File

Update this file when the component structure changes significantly, a new major subsystem is introduced, or a constraint or assumption is invalidated. Add extra narrative here only when something is non-obvious or easy to misread from the sections above. Record broader or contentious decisions in `.ai/memory.md`.
