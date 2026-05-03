# ARCHITECTURE.md

> High-level system design for BrewUI. Update when structure changes. **Owns:** layers, data flow, folder layout, integrations (Homebrew CLI / JSON API), and product constraints. **Defers** naming and day-to-day coding patterns to [`CONVENTIONS.md`](CONVENTIONS.md). Record durable rationale in [`.ai/memory.md`](.ai/memory.md).

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

## System shape

Flow: **View → ViewModel → Repository *or* Interactor → Services →** `brew` CLI **or** JSON API.

Guiding patterns:

- **MVVM-C (lightweight):** Views stay declarative; ViewModels own presentation state; coordination/navigation policy is centralized in small coordinator-style shell types when needed.
- **Clean Architecture principles:** Depend inward on abstractions, keep use cases in Interactors/Repositories, isolate infrastructure in Services, and keep UI/framework concerns out of domain decisions.
- **Emergent architecture:** Prefer the smallest pattern that solves today’s problem; evolve structure incrementally as features and complexity grow.

```
┌──────────────────────────────────────────────────────────────┐
│                    BrewUI (macOS App)                        │
│  Views (SwiftUI) ──▶ ViewModels                              │
│         │                    │                               │
│         │          Repositories    Interactors               │
│         │                 └────┬────┘                        │
│         │                      Services (brew + JSON API)   │
└────────────────────────────────┼─────────────────────────────┘
                                 ▼
              brew CLI (subprocess) · formulae.brew.sh JSON API
```

## Core components

- **Views:** SwiftUI; thin — bind state, forward actions. Shared pieces in `Views/`.
- **ViewModels:** Presentation state and mapping; delegate work downward. Keep domain rules in Interactors or Models, not here.
- **Repositories:** CRUD-shaped access to a **data source** (CLI output, API, storage, in-memory). Swap the implementation, keep the contract.
- **Interactors:** One **use case** each — not generic CRUD (e.g. doctor run, config snapshot). Prefer protocols + real/mock impls for tests.
- **Services:** Infrastructure — e.g. `BrewCommandService` (subprocess, streaming, cancellation), `JSONAPIService` (fetch/decode).
- **Command center:** `BrewCommandCenter` (actor protocol; app default `SerialBrewCommandCenter`) — **serializes** mutating `brew` work, tracks **in-flight / failed** **operation** state (`BrewOperationID` + `BrewOperationPhase`) for UI across surfaces, and runs **small `BrewMutatingCommand` types** that call `BrewCommandRunning` + the brew locator. It does **not** own **read/parsing** of `brew list` / `brew info` output — that stays in **repositories**. Feature-scoped executors (e.g. upgrade helpers) should stay **thin** and be invoked **from** commands the center schedules, not as a second parallel pipeline.
- **Models:** Shared types (`Formula`, jobs, config, …) and pure parsing/helpers where it keeps UI layers thin.

## File organisation

```
Features/          ← per feature: View, ViewModel, optional local Interactor
Models/
Repositories/
Interactors/
Services/
Views/             ← reusable UI across features
Utilities/
└── AccessibilityIdentifiers.swift  ← shared with UI tests; single source for IDs
```

## Command execution

Run Homebrew commands **asynchronously** via subprocess; support **cancellation**; **stream or preserve** stdout/stderr for transparency and logs. Always make the **exact command** visible to the user; treat **CLI text output as unstable** (tolerant parsing, fallbacks).

## JSON API

Use the [Homebrew JSON API](https://formulae.brew.sh/docs/api/) where it helps. Prefer **optional / resilient decoding** — schema can change; **never crash** on unknown fields. Combine with CLI only as needed when the app grows.

## Constraints & decisions

- **macOS-only.** No iOS / iPadOS / cross-platform for now.
- **Default Homebrew prefix only:** `/opt/homebrew` (Apple Silicon) or `/usr/local` (Intel). No custom prefix initially.
- **No custom taps initially** — core tap scope.
- **`brew` is the source of truth** — BrewUI does not poke Homebrew internals.
- **Transparency** — users see what runs; no hidden commands.
- **Homebrew is separate** — detect and degrade if missing; do not bundle Homebrew.
- **Detection:** try `/opt/homebrew/bin/brew` then `/usr/local/bin/brew`.
- **Open source** — patterns should stay contributor-friendly.

### Platform constraints

- **CLI drift:** `brew` text is not a stable API — parsers must be tolerant.
- **JSON drift:** decoding must stay resilient as the API evolves.
- **UI tests:** async output and sheets need deliberate sync; avoid flakiness.
- **Accessibility:** desktop workflows need keyboard and VoiceOver semantics, not only labels.

## Resources

- [`CONVENTIONS.md`](CONVENTIONS.md)
- [Homebrew JSON API](https://formulae.brew.sh/docs/api/)
- [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [SwiftUI](https://developer.apple.com/documentation/swiftui)

## Updating this file

Change when layers, folders, or major assumptions shift. Put **why** in `.ai/memory.md` when it is non-obvious or contentious.
