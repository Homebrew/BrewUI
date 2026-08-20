# UI test suite: what was wrong, and what to watch for

Notes from getting the 26-test `BrewUITests` suite from "never successfully run end-to-end" to
green on a real Mac. Kept here because every cause below will bite again if the conditions recur.

## What was actually wrong

1. **Terminal/Xcode lacked Accessibility, Automation, and Screen Recording permissions.**
   Running `xcodebuild test` from the command line (rather than Xcode's ⌘U) needs these granted to
   whichever app hosts the shell — otherwise the app under test never gets real focus, and you can't
   screenshot to see why. Not a code problem; a one-time machine setup step
   (System Settings → Privacy & Security).

2. **`XCUIApplication.launch()` can produce a frontmost, menu-bar-populated process with *zero
   windows*.** Confirmed by hand: `open`-launching the built app gets a window immediately;
   `XCUIApplication.launch()` (and a raw `exec`) don't, on this OS build. `BrewApp.activate()` now
   detects `windows.count == 0` after activating and sends the same "reopen" AppleEvent a Dock-icon
   click sends, via `NSWorkspace`. **Watch for:** this targets the running instance whose
   `executableURL` lives under `/DerivedData/` — if the app is ever installed for real at
   `/Applications` on the machine running these tests (it shares the same bundle ID), a naive
   `open -b <bundle id>` will reopen *that* copy and steal focus instead.

3. **Tests leaked app processes across runs.** `BrewUITestCase` now terminates whatever it launched
   in `tearDown()`. Without this, a wedged instance from one test can block the next test's
   `launch()` outright (`Failed to activate application ... current state: Running Background`).

4. **The screen locking mid-run reproduces the exact same symptoms as #2.** macOS won't grant real
   window focus to anything while locked, so a locked screen looks identical to a harness bug.
   If failures suddenly cluster on *every* test with foreground/window errors, check this before
   debugging code.

5. **`List` row text (and `.accessibilityElement(children: .combine)` content) exposes through the
   accessibility *value*, not the *label*, on macOS.** `NSPredicate(format: "label CONTAINS %@")`
   silently never matches console output lines or the console status strip, even though the content
   is genuinely on screen. Confirmed by dumping the live accessibility tree
   (`element.debugDescription`) — `StaticText … value: ==> Fetching ripgrep`, no label at all.
   **Watch for:** any new assertion reading text out of a `List`/`Outline` row or a `.combine`d
   accessibility element should match `label CONTAINS %@ OR value CONTAINS %@`, not `label` alone.

6. **A button below the fold in a scrollable detail pane exists in the tree but never becomes
   `isHittable`.** The Uninstall button sits low enough in the detail pane that the default test
   window height clips it. `exists == true`, `isEnabled == true`, `isHittable == false` — forever,
   not just slow. Fixed with a scroll (`element.scroll(byDeltaX:deltaY:)`) before the tap.
   **Watch for:** any new affordance added near the bottom of a scrollable detail/settings pane.

7. **A project-relative `-derivedDataPath` makes the test runner hang for ~5 minutes before failing
   with "The test runner hung before establishing connection."** Reproduced twice, on two different
   `-only-testing:` scopes, both timing out at the same ~330s mark. The identical run against the
   default `~/Library/Developer/Xcode/DerivedData/...` location passes in seconds. Root cause not
   chased further than that; `scripts/test-ui` and CI both just avoid passing `-derivedDataPath` for
   this scheme. **Watch for:** any future script wired to a custom derived-data path (to reuse a
   build across steps, for instance) needs to be tested end-to-end on a real Mac before trusting it —
   the failure mode gives no clue it's about the path.

8. **`CODE_SIGNING_ALLOWED=NO` leaves the test runner with a signature that no longer matches its
   contents, and macOS calls that "damaged".** The symptom is a Gatekeeper dialog — *"BrewUITests-Runner
   is damaged and can't be opened. You should move it to the Bin."* — followed ~300s later by
   `The test runner hung before establishing connection.` The dialog is the cause; the hang is just
   xcodebuild waiting on a runner macOS refused to start.

   `BrewUITests-Runner.app` is a copy of Xcode's `XCTRunner.app` template, which arrives **already
   signed by Apple** (`codesign -dvv` on a broken one reports `Identifier=com.apple.XCTRunner`). The
   build then inserts our `.xctest` into `Contents/PlugIns` and, with signing disallowed, never
   re-signs — so the retained seal is invalid: `codesign -v --deep --strict` says *"code has no
   resources but signature indicates they must be present"*. Allowing signing with
   `CODE_SIGN_IDENTITY=-` fixes it: the runner is ad-hoc signed as `sh.brew.BrewUITests.xctrunner`
   with a valid seal, and ad-hoc needs no identity, team or profile, so it works on CI too.

   **Watch for:** `scripts/test-ui` and the `ui-test` CI job still pass `CODE_SIGNING_ALLOWED=NO`.
   That is the same latent defect — if the deterministic suite ever starts failing this way, drop
   the flag there as well rather than hunting the hang.

## Debugging gotcha specific to this environment

Running a diagnostic shell command (even a quick `osascript` query) *while* a test is polling
`isHittable` can itself bring Terminal frontmost and cover the app, producing a false failure that
has nothing to do with the code. If a failure only reproduces when you're actively poking at the
Mac alongside the test run, let the run finish completely undisturbed before trusting the result.

## General advice for new tests

- If a new test fails with "app running but not in foreground" or "app running but has no window",
  suspect environment (#1, #2, #4) before suspecting the test.
- If a new text assertion can't find content you can see on screen, check `value` as well as
  `label` before assuming the identifier or content is wrong.
- If a new button/control never becomes hittable despite existing, check whether it's below the
  fold in a scroll view at the default window size.
- Keep runs short while iterating (`-only-testing:` a single test, with a wall-clock budget) — a
  hung launch here doesn't fail fast, it eats the full 60s `BrewUITestTimeout.launch` per attempt.
