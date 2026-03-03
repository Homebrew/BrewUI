# Progress — BrewUI

> Current and recent work status. Update at the end of every session.
> Format: `## YYYY-MM-DD — Session summary`

---

## 2026-03-03 — Repository scaffolding + prototype migration

**Completed:**
- AI agent configuration layer created (`AGENTS.md`, `CLAUDE.md`, `.cursorrules`, `CONVENTIONS.md`, `ARCHITECTURE.md`, `docs/adr/`, `.ai/`)
- Prototype context migrated from separate repo into all config files
- `ARCHITECTURE.md` fully populated (tech stack, components, patterns, UX principles, constraints)
- `CONVENTIONS.md` fully populated (Swift 6.0, naming, SwiftUI, error handling, accessibility, testing, dependencies)
- Swift official conventions applied and linked throughout `CONVENTIONS.md`
- `.gitignore` created with macOS/Xcode/Swift defaults

**Remaining M0 scope (not yet started):**
- Configure branch strategy and protection policy
- CI workflow: basic build on push/PR
- CI workflow: lint + test integration hooks
- CI reliability pass (cache, retries)
- Signing/internal release strategy and secrets plan
- Open-source baseline docs (getting started guide, contribution guide)
- Issue templates + CODEOWNERS
- Definition of Done checklist/gates in repo
- Clickable prototype/mockups for review

---

## Deliverable Roadmap

> Scope only. Phases are sequential; do not start a later phase while the current is incomplete.

### Current focus → M1 / D1: App Foundation + Safe Command Console

**Goal:** Usable viewer for discovery and installed packages — users can browse, search, and see what's installed, with all operations showing the underlying `brew` command and live output.

**D1 checklist:**

- [ ] **Project structure**
  - [ ] Create Xcode project with correct targets
  - [ ] Set up folder structure (`Features/`, `Models/`, `Repositories/`, `Interactors/`, `Services/`, `Views/`, `Utilities/`)
  - [ ] Configure Swift 6.0 strict concurrency

- [ ] **Command execution foundation**
  - [ ] `CommandJob` model (`id`, `command`, `status`, `output`, `exitCode`)
  - [ ] `BrewCommandService` with `Process` execution
  - [ ] stdout/stderr streaming line-by-line
  - [ ] Exit code handling
  - [ ] Basic typed error types (`BrewCommandError`)

- [ ] **UI shell**
  - [ ] Main window with sidebar navigation
  - [ ] Tab/navigation structure (Search, Installed, Maintenance)
  - [ ] `CommandOutputView` component (collapsible console)
  - [ ] Status indicators (running / success / failure)

- [ ] **Read-only command wrappers**
  - [ ] `brew search <query>`
  - [ ] `brew info <formula>`
  - [ ] `brew list`
  - [ ] Parse output into structured types where possible

- [ ] **Basic views**
  - [ ] `SearchView` with text input and results list
  - [ ] `PackageDetailView` showing `brew info` output
  - [ ] `InstalledView` showing `brew list` results

**D1 success criteria:**
- User can search for packages and see results
- User can view detailed info about a package
- User can see what's currently installed
- All operations show the underlying `brew` command
- Live output visible for all commands
- No crashes on common operations
- Clear status indication (running / success / failure)

---

### D2: Core Package Actions

**Goal:** Complete package lifecycle without Terminal.

- [ ] `brew install` with guided flow and confirmation dialog
- [ ] `brew uninstall` with confirmation dialog
- [ ] Post-action state refresh
- [ ] Safeguards against concurrent conflicting operations

---

### D3: JSON-Backed Discovery

**Goal:** Discovery-first experience beyond raw CLI.

- [ ] Formula + cask catalog from Homebrew JSON API (`formulae.brew.sh`)
- [ ] Advanced search, sort, and filter UI
- [ ] Rich detail cards with full metadata
- [ ] Incremental decoding / performance optimisations for large datasets
- [ ] Cache with timestamp; invalidate on `brew update`

---

### D4: Maintenance Centre

**Goal:** Routine maintenance accessible without memorising commands.

- [ ] One-click `brew update`
- [ ] One-click `brew upgrade` with preview
- [ ] Health panel: `brew doctor` with plain-language guidance and issue mapping
- [ ] Environment panel: `brew config` with key/value display

---

### D5: Help & Learnability

**Goal:** Reduced anxiety for new and CLI-averse users.

- [ ] `man brew` integration (in-app or system viewer)
- [ ] "What this does" explanations inline
- [ ] First-run onboarding flow
- [ ] In-app terminology help

---

### D6: Reliability & Guardrails

**Goal:** Fewer dead ends, clearer recovery paths.

- [ ] Robust error mapping (exit codes → user-facing messages with suggested recovery)
- [ ] Retry and recovery flows
- [ ] Preflight checks (Homebrew installed? Default prefix detected?)
- [ ] Improved cancellation handling

---

### D7: Release Readiness

**Goal:** Stable public release candidate.

- [ ] Accessibility hardening pass (VoiceOver, keyboard navigation, focus order, labels)
- [ ] Integration test suite for command wrappers and parsers
- [ ] Open-source documentation (README, contributing guide, getting started)
- [ ] Support bundle generation

---

### Stretch D8: Services UI
- [ ] `brew services` status and actions
- [ ] Service logs and troubleshooting aids

### Stretch D9: Tap Insights
- [ ] `brew tap-info` viewer
- [ ] Tap metadata and discovery UI
