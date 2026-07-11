# Releasing BrewUI

BrewUI uses a two-stage release pipeline so that nothing is ever released
without having already been built and notarised successfully.

1. **Build (`.github/workflows/build.yml`)** — runs on every push to `main`.
   It builds, signs, **notarises** and staples the app, packages it into a
   signed `.pkg`, zips the bare app for the cask, and uploads them as fixed-name
   `Homebrew-pkg` / `Homebrew-app` artifacts. Pull requests run the same build as
   a signed-but-not-notarised dry run (no upload) to save notary quota.

2. **Release (`.github/workflows/release.yml`)** — a manual **"Run workflow"**
   step that promotes the most recent successful `main` build to a release.

## Versioning

Versions are **derived from git — never checked in or hand-bumped.**

- **Marketing version** (`CFBundleShortVersionString`) is a function of the
  nearest reachable `v*` tag and how many commits `HEAD` is past it:
  - on a tag (distance 0) → the tag verbatim (a freshly-cut major/hotfix);
  - past a tag on `main` → last release **+ minor**, patch reset to 0;
  - past a tag on a `release/*` branch → last release **+ patch**.
- **Build number** (`CFBundleVersion`) is the git commit count
  (`git rev-list --count HEAD`) — monotonic, no judgement.

Both are computed by `scripts/derive-version` / `scripts/derive-build-number`
and stamped into the app by the **"Stamp app version"** Xcode build phase
(`scripts/stamp-app-version`), which runs on **every** build — local and CI —
so a local debug `Homebrew.app` shows the same real version CI ships.
`Configurations/Version.xcconfig` holds only inert placeholders.

Because the version is derived, the routine minor release never involves a code
change: `promote-minor` reads the version out of the built app and tags it.

---

## Cutting a release

1. Make sure the change you want to release is merged to `main` and its **Build**
   run went green (that produced the notarised artifact).
2. Go to **Actions → Release → Run workflow** and run it against `main`.

> **First release after this pipeline lands.** The Release workflow downloads an
> existing successful **Build** artifact from `main` — it never builds. So the
> very first time, the order is: merge → wait for **Build** on `main` to go green
> → *then* run **Release**. There is no `main` artifact to promote until that
> first build finishes. With `v0.1.0` already tagged, the first release derives
> `0.2.0`.

The Release workflow then:

1. Downloads the most recent successful **Build** artifact from `main` and reads
   the marketing version straight out of the app bundle's `Info.plist` — the
   bundle names the tag. It also captures that build's commit (`headSha`).
2. Fails if `v<version>` already exists (see immutable tags below).
3. Creates the GitHub Release with `gh release create --target <headSha>`, which
   creates the tag `v<version>` **on the built commit** as part of creating the
   Release, and attaches the notarised `.pkg` and app zip with auto-generated
   notes. Because the tag and Release are created together, a failed run never
   leaves a dangling tag; and because it targets `headSha`, the tag points at the
   exact bytes shipped (not wherever `main` has moved to).
4. Opens a **`brew bump-cask-pr`** PR against `Homebrew/homebrew-cask` bumping
   the `homebrew-app` cask to the released version with the app zip's `sha256`.

There is **no version-bump PR** — the next commit to `main` already derives the
next minor automatically.

Editing `release.yml` triggers a **dry run** (on `push`) that exercises
permissions without downloading an artifact or creating a tag or release, so it
passes even before any `main` build exists.

---

## Required repository secrets

Signing and notarisation (already configured, used by `build.yml`):

- `APP_APPLE_SIGNING_CERTIFICATE_BASE64` / `APP_APPLE_SIGNING_CERTIFICATE_PASSWORD`
- `PKG_APPLE_SIGNING_CERTIFICATE_BASE64` / `PKG_APPLE_SIGNING_CERTIFICATE_PASSWORD`
- `PKG_APPLE_DEVELOPER_TEAM_ID`
- `PKG_APPLE_ID_EMAIL`
- `PKG_APPLE_ID_APP_SPECIFIC_PASSWORD`

Cask PR (used by `release.yml`):

- `HOMEBREW_GITHUB_API_TOKEN` — a personal access token that can fork
  `Homebrew/homebrew-cask` and open a pull request. The default `GITHUB_TOKEN`
  cannot push to another repository, so this must be a separate PAT.

---

## Notes and caveats

- **Immutable tags.** Enable immutable tags on the repository. Creating the tag
  together with the Release (via `gh release create --target`) already avoids
  leaving behind broken tags; never delete and recreate a tag — Git and
  Homebrew both handle that badly.
- **First-time cask.** `brew bump-cask-pr` only updates an *existing* cask. The
  very first `homebrew-app` submission to `homebrew-cask` is a manual one-off; every
  release after that is automated.
- **Version format.** Three-part semver, derived from the last `v*` tag. The
  routine `promote-minor` bumps the minor and zeroes the patch (`0.2.0` →
  `0.3.0`). Major and patch releases are deliberate, gated actions (see below).
- **Artifact retention.** Build artifacts are kept for 90 days. If you promote
  more than 90 days after the last `main` build, re-run **Build** (via its
  "Run workflow" button) first.

---

## Major and hotfix releases

The routine minor release is automatic; the two cases that need human judgement
stay manual and are **not part of this base pipeline** (they land as separate,
cherry-pickable commits):

- **`cut-major`** — a deliberate `X.0.0`. Computes the next major, tags `main`'s
  HEAD, builds that tagged commit fresh (distance 0 → it carries `X.0.0`), and
  publishes it.
- **`cut-hotfix`** — patch a shipped release. Dispatched against a `release/*`
  branch cut from the old tag; computes `patch+1`, tags the branch HEAD, builds
  fresh, and publishes as a non-`latest` release.

Both are the same shape (compute → tag → build fresh → release); only routine
minor releases skip the rebuild by promoting existing bytes.
