# Cutting a release

The Sakura LSL toolchain ships as five **independent** projects, each
versioned and released on its own cadence. This document is the
operational checklist for releasing any one of them — and, every so
often, for cutting a coordinated "toolchain" release across all five.

> The release engineer for every repo is **Shiho Sakura**
> ([@ShihoSakura](https://github.com/ShihoSakura)), publishing on
> behalf of **Sakura Studios, IKE**.

## Versioning

We follow [SemVer](https://semver.org/). Tags are always `vMAJOR.MINOR.PATCH`,
e.g. `v1.0.0`. Pre-releases use `v1.0.0-rc.1`.

The five projects are version-independent. The toolchain meta-repo
(`sakura-lsl-toolchain`) tags a release only when we want to mark a
known-good *combination* of the five submodules — typically aligned to
a major version bump on any single tool.

## Required GitHub secrets

Each repo's `.github/workflows/ci.yml` consumes a different set of
secrets at tag-push time. Configure these under
**Settings → Secrets and variables → Actions** before the first tag.

### All four C / Python repos (lslc, slemu, lsldb, lsltest)

| Secret | Purpose | How to obtain |
|---|---|---|
| `AUR_SSH_KEY` | Push updates to the AUR repo for `sakura-<tool>` and `sakura-<tool>-git` | Generate an ed25519 key, add the public half to your AUR account at <https://aur.archlinux.org/account/> |

The AUR step uses `continue-on-error: true`, so a missing secret won't
fail the release — the GitHub Release will still publish.

### sakura-lsltest (additionally)

PyPI publishing uses **trusted publishing via OIDC**, no secret needed.
Configure the trusted publisher once at
<https://pypi.org/manage/account/publishing/>:

- PyPI Project Name: `sakura-lsltest`
- Owner: `Sakura-Studios-IKE`
- Repository name: `sakura-lsltest`
- Workflow name: `ci.yml`
- Environment name: *(leave blank)*

### sakura-intellij-lsl (additionally)

| Secret | Purpose |
|---|---|
| `JETBRAINS_MARKETPLACE_TOKEN` | Permanent token from <https://plugins.jetbrains.com/author/me/tokens> |
| `JETBRAINS_CERTIFICATE_CHAIN` | Plugin signing cert chain (PEM) |
| `JETBRAINS_PRIVATE_KEY` | Plugin signing private key (PEM) |
| `JETBRAINS_PRIVATE_KEY_PASSWORD` | Passphrase for the private key |

See [JetBrains docs on plugin signing](https://plugins.jetbrains.com/docs/intellij/plugin-signing.html)
for generating the cert/key pair.

## Release checklist (per repo)

1. **Pre-flight on `main`:**
   - `git switch main && git pull`
   - `make test` (or the repo's equivalent) is green
   - `CHANGELOG.md` `[Unreleased]` section has every user-visible
     change for the version
2. **Promote `[Unreleased]` → `[X.Y.Z] - YYYY-MM-DD`** in
   `CHANGELOG.md`. Add a fresh empty `[Unreleased]` block at the top.
3. **Bump the version**:
   - C tools: bump `VERSION` macro in `src/main.c` (or wherever it
     lives) plus `PKGBUILD`'s `pkgver=`.
   - Python: bump `pyproject.toml`'s `version`.
   - Plugin: bump `pluginVersion` in `gradle.properties`.
4. **Commit & tag:**
   ```sh
   git add -A
   git commit -m "Release vX.Y.Z."
   git tag -a vX.Y.Z -m "Release vX.Y.Z."
   git push origin main --tags
   ```
5. **CI does the rest:**
   - Matrix build on Linux / macOS / Windows
   - GitHub Release auto-created with built artefacts attached
   - AUR repo bumped (PKGBUILD pkgver+pkgrel updated, .SRCINFO regenerated)
   - PyPI publish (lsltest only)
   - Marketplace publish (plugin only)
6. **Verify:**
   - GitHub Release page shows the artefacts
   - `yay -Syu` picks up the new `sakura-<tool>` version (AUR repos)
   - `pip install --upgrade sakura-lsltest` returns the new version
   - JetBrains Marketplace listing shows the new build with the
     correct change-notes (auto-pulled from `CHANGELOG.md`)

## Coordinated toolchain release

When you want to publish a "blessed combination" across the whole
toolchain:

1. Release each tool individually as above, in this order:
   `sakura-lslc` → `sakura-slemu` → `sakura-lsldb` → `sakura-lsltest`
   → `sakura-intellij-lsl`. (Plugin last — it depends on the other
   four through its run/debug machinery.)
2. In `sakura-lsl-toolchain`:
   ```sh
   git submodule update --remote
   git add .
   git commit -m "Bump submodules to <date> blessed combo."
   git tag -a vX.Y.Z -m "Toolchain release vX.Y.Z."
   git push origin main --tags
   ```
3. The meta-repo's release just bundles the submodule SHAs — no
   artefacts of its own.

## Hot-fix procedure

For a critical fix on a single tool:

1. Branch from the latest tag: `git switch -c hotfix/vX.Y.(Z+1) vX.Y.Z`
2. Apply the fix + a regression test
3. Bump patch version, update `CHANGELOG.md`
4. Tag `vX.Y.(Z+1)` from the hotfix branch
5. Merge `hotfix/...` back into `main`

## Yanking a bad release

- GitHub Release: mark it as "Pre-release" or delete the release
  (keep the tag so users who pulled it can still reproduce).
- AUR: open a TUR (Trusted User Request) only if the package is
  fundamentally broken; for ordinary bugs, just publish a `.Z+1`.
- PyPI: `pip-yank sakura-lsltest X.Y.Z` (the project itself cannot
  delete a release older than 1 day).
- Marketplace: in the plugin's
  [Versions tab](https://plugins.jetbrains.com/plugin/manage), click
  the release and "Hide".

## Author / Attribution

Releases are signed and published by **Shiho Sakura**
([@ShihoSakura](https://github.com/ShihoSakura)) — on behalf of
**Sakura Studios, IKE**. The Git author identity used for release
commits is configured via the `github-shiho` SSH host alias and the
matching `user.email` set per-repo.
