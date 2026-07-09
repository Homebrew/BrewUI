# Releasing BrewUI

BrewUI uses a two-stage release pipeline so that nothing is ever released
without having already been built and notarised successfully.

1. **Build (`.github/workflows/build.yml`)** — runs on every push to `main`.
   It builds, signs, **notarises** and staples the app, packages it into a
   signed `.pkg`, generates a build attestation, and uploads fixed-name artifacts
   (`Homebrew-pkg` for the website download and `Homebrew-app` for the cask). Pull
   requests run the same build as a signed-but-not-notarised dry run (no upload)
   to save notary quota.

2. **Release (`.github/workflows/release.yml`)** — a manual **"Run workflow"**
   step that promotes the most recent successful `main` build to a release.

The marketing version lives in `Configurations/Version.xcconfig`
(`MARKETING_VERSION`), which is the single source of truth for the version
baked into every build.

---

## Cutting a release

1. Make sure the change you want to release is merged to `main` and its **Build**
   run went green (that produced the notarised artifact).
2. Go to **Actions → Release → Run workflow** and run it against `main`.

> **First release after this pipeline lands.** The Release workflow downloads an
> existing successful **Build** artifact from `main` — it never builds. So the
> very first time, the order is: merge → wait for **Build** on `main` to go green
> → *then* run **Release**. There is no `main` artifact to promote until that
> first build finishes.

The Release workflow then:

1. Reads the version from `Version.xcconfig` and forms the tag `v<version>`
   (fails if that tag already exists — see immutable tags below).
2. Downloads the most recent successful **Build** artifact from `main` and
   checks its filename matches the version.
3. Creates the GitHub Release with `gh release create --target`, which creates
   the tag `v<version>` at the released commit **as part of** creating the
   Release, and attaches the notarised `.pkg` and app zip with auto-generated
   notes. Because the tag and Release are created together, a failed run never
   leaves a dangling tag.
4. Opens a **version bump PR** against `main` bumping `Version.xcconfig` to the
   next minor version (e.g. `0.2.0` → `0.3.0`). `main` is branch-protected, so this
   is a PR rather than a direct push — review and merge it.
5. Opens a **`brew bump-cask-pr`** PR against `Homebrew/homebrew-cask` bumping
   the `homebrew-app` cask to the released version with the app zip's `sha256`.

Editing `release.yml` triggers a **dry run** (on `push`) that resolves the
version, checks the tag is free, and exercises permissions — without
downloading an artifact or creating a tag or release. Because the dry run never
touches artifacts, it passes even before any `main` build exists (e.g. on this
workflow's own introducing PR and on the first merge to `main`).

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
- **Version format.** `Version.xcconfig` uses three-part semver (e.g. `0.2.0`).
  The automated bump increments the minor and zeroes the patch
  (`0.2.0` → `0.3.0`); do patch and major bumps by hand.
- **Artifact retention.** Build artifacts are kept for 90 days. If you promote
  more than 90 days after the last `main` build, re-run **Build** (via its
  "Run workflow" button) first.

---

## Future: patch releases

Patch releases (hotfixes) are not yet automated. The intended shape: branch off
the last minor release tag, apply the fix, bump the **patch** component of
`Version.xcconfig` on that branch, and run the same promote path from there. A
dedicated patch-release workflow is a follow-up.
