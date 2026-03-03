# ARCHITECTURE.md
> High-level system design for BrewUI.
> Consult this before making structural changes. Update it (or create an ADR) when the architecture evolves.

---

## Status

> ⚠️ This file is scaffolded. Populate with project-specific architecture once the prototype codebase is migrated.

---

## Overview

**BrewUI** is a native macOS GUI that surfaces Homebrew functionality without requiring users to use the Terminal. It wraps the Homebrew CLI and provides a polished, first-party graphical experience.

---

## System Diagram

```
┌─────────────────────────────────────┐
│            BrewUI (macOS App)        │
│                                     │
│  ┌──────────┐     ┌───────────────┐ │
│  │    UI    │────▶│  App Logic /  │ │
│  │  Layer   │     │  View Models  │ │
│  └──────────┘     └──────┬────────┘ │
│                          │          │
│                   ┌──────▼────────┐ │
│                   │  Homebrew     │ │
│                   │  Service Layer│ │
│                   └──────┬────────┘ │
└──────────────────────────┼──────────┘
                           │
                    ┌──────▼────────┐
                    │  brew CLI     │
                    │  (subprocess) │
                    └───────────────┘
```

> ⚠️ Diagram is illustrative and based on expected architecture. Revise once the prototype is migrated.

---

## Key Components

### UI Layer
- _[To be filled in — e.g. SwiftUI views, navigation structure]_
- Responsible for rendering state; should not contain business logic.

### App Logic / View Models
- _[To be filled in — e.g. ObservableObject classes, state management approach]_
- Mediates between the UI and the Homebrew service layer.

### Homebrew Service Layer
- Responsible for all communication with the `brew` CLI.
- Parses CLI output into structured data types.
- Handles process management (spawning subprocesses, streaming output, cancellation).
- _[To be filled in — specific design once migrated]_

---

## Data Flow

1. User triggers an action in the UI (e.g. "Install package").
2. View model calls the Homebrew service layer.
3. Service layer spawns a `brew` subprocess and streams output.
4. Results are parsed and returned to the view model as structured data.
5. UI updates reactively.

---

## Key Design Decisions

Significant decisions are captured as ADRs in `docs/adr/`. Notable ones:
- _[To be linked as ADRs are created]_

---

## Constraints & Assumptions

- Homebrew must be installed separately; BrewUI does not bundle Homebrew.
- The app targets macOS only (no iOS, no cross-platform).
- The `brew` CLI is the authoritative source of truth; BrewUI never manipulates Homebrew internals directly.
- _[Additional constraints to be filled in from prototype]_

---

## Updating This File

Update this file when:
- The component structure changes significantly.
- A new major subsystem is introduced.
- A constraint or assumption is invalidated.

For non-obvious *decisions* (why something was done a particular way), prefer creating an ADR over adding prose here.
