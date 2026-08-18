# Live end-to-end canaries (Tier 3)

A small suite that runs the app with **production wiring** against **real Homebrew** and the **real
network**. Everything else in `BrewUITests` stubs the two process boundaries and is deterministic;
this does not, and is deliberately kept off the per-PR path.

Run it with `scripts/test-e2e` (test plan `Brew-E2E`). `scripts/test-ui` (test plan `Brew-UI`) is the
per-PR suite and skips these tests by name.

## What it is for

A **contract canary**. If Homebrew changes its JSON shape or CLI output and breaks a feature's happy
path, this suite goes red while the deterministic Tier 2 suite — which is answering from fixtures —
stays green. It is not here to broaden coverage; it is here to notice when the fixtures have started
lying.

Covered: install · uninstall · config · search · navigation · console.

Not covered, on purpose:

- **upgrade** — needs a deterministically outdated installed package, which a live machine cannot be
  guaranteed to have without brittle bottle pinning.
- **doctor** — output is entirely machine-state dependent, so there is no stable happy path.
- **error cases** — all of them belong at Tier 2, where a failure is a fixture rather than an outage.

## It mutates this machine

`InstallUninstallE2ETests` **installs and uninstalls the formula `hello`** (GNU Hello: no
dependencies, pours in seconds). It force-uninstalls it before and after every test, so a run leaves
no residue even if it fails part way.

**`hello` is owned by this suite.** Nothing — no fixture, no other test, no developer setup — may
depend on it being installed. If you need a canary package for something else, pick a different one
and document it here.

Ephemeral CI runners are the intended home for this. On a developer machine it is safe but not
invisible: it will uninstall a `hello` you installed yourself.

## Assertions are shape, not values

Versions, dependency counts and `brew config` values drift constantly, and a canary that fails on a
version bump gets muted within a week. So:

| Flow | What is asserted |
| --- | --- |
| Search | a result row for the package *exists* (catalogue fetched and decoded) |
| Config | a `HOMEBREW_VERSION` / `HOMEBREW_PREFIX` row is *present* (`brew config` still parses) |
| Install / uninstall | presence/absence *transitions*, console streamed non-empty output ending in success |
| Navigation | each screen root loads with real data behind it |

## How state isolation works

Responsibilities are split: **arrange and clean up by shelling out to real brew** (`Brew.run` /
`Brew.forceUninstall`, a `Process` helper that is a fixture actuator and never the code under test);
**act through the app's UI** using the same page objects the stubbed suite uses. A broken arrange then
reads as a fixture failure rather than as a red assertion inside the flow under test.

## Requirements

- Homebrew installed (`/opt/homebrew/bin/brew` or `/usr/local/bin/brew`) — the suite fails by name in
  `setUp` if it is missing rather than failing slowly on a missing element.
- Network egress to `formulae.brew.sh` and `ghcr.io`.
- The same Accessibility/Automation permissions the deterministic UI suite needs — see
  `../TROUBLESHOOTING.md`.

## Schedule

- **Nightly** via `.github/workflows/e2e_nightly.yml` (cron, plus manual dispatch).
- **Before cutting a release**, by hand: `scripts/test-e2e`. That is the moment you most want to know
  brew has not shifted under the app. The release workflow itself is deliberately not wired to it.

The plan runs serially with generous per-test timeouts and retry-on-failure = 1 — enough to absorb a
transient network blip, low enough that it cannot mask a real contract break.
