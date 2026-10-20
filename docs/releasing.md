# Releasing Strata

GitHub prepares Fedora 44 x86_64 RPMs when a version tag is pushed. It builds
changed `config`, `desktop`, `hyprland`, `utilities` and `fonts` targets on
separate runners and reuses verified unchanged targets from the previous stable
release, then combines their runtime packages. Debug and source RPMs are excluded from
the public repository. The `config` target also builds `strata-lock-auth`
from its own small spec; its PAM policy keeps Fedora’s login authentication
stack and preserves local changes on upgrade. No package is taken from Git.

## Start a release

1. Run `bin/strata-release-version 1.1.2 -m "Fix greeter display scaling"`
   with the new version and changelog message. Repeat `-m` for additional bullets;
   the messages go into each spec's new release entry when its version changes.
   Without `-m`, the command supplies a generic version update message. This updates
   `VERSION`, `runtime-version`, and the Strata versions in the config, desktop
   and utilities specs, resets their releases to 1 and adds changelog entries.
   Alternatively, edit only `VERSION`
   and run `bin/strata-release-version` to synchronize the remaining files.
   RPM epochs and upstream package versions remain unchanged. Local builds and
   CI check consistency before starting compilation.
2. Commit and push the source changes, including the workflows. CI builds new
   runtime RPMs; there is no need to copy local build output into Git.
3. Create and push the matching tag, for example:

   ```bash
   git tag -a v1.0.1 -m 'Strata 1.0.1'
   git push origin v1.0.1
   ```

The **Build Strata release** workflow can also be started manually from
GitHub Actions with an existing tag. The tag must match `VERSION` and
`runtime-version`. Every build uses the same resolved commit.

Release planning scripts explicitly run on Node.js 24. Workflow actions use
current stable versions with Node.js 24 runtimes, including the Pages actions.

## Reusing unchanged packages

Before building, CI downloads the most recently published stable release other
than the requested tag. It checks the archive and `release-manifest.json`
against `SHA256SUMS`. An older release without a manifest, a failed download,
or an invalid checksum causes a full build.

The planner fingerprints tracked Git file contents and modes for each target:

| Target | Inputs |
| --- | --- |
| Config | Everything copied into its source archive: scripts, shell, config, defaults, themes, docs, native and vendored sources, packaging and licenses. This includes lock-auth inputs. |
| Desktop | Desktop spec, Zen launcher/desktop file and local license. |
| Hyprland | Hyprland spec, including its pinned upstream dependency versions. |
| Utilities | Utilities spec and pinned upstream versions. |
| Fonts | Font spec and upstream version. |

Builder, planner or release-workflow changes rebuild every target. Unmapped
packaging files, including patches, also invalidate every target conservatively.
Changed or deleted files and spec versions change the fingerprint. Each reused
RPM must still exist and match the digest recorded by the previous build;
otherwise its entire target is rebuilt.

Reuse operates per build target, not individual subpackage. Changing the desktop
spec rebuilds Ghostty, UWSM, Zen and the desktop packages together. Config's
archive includes packaging files, so a spec change also rebuilds config.

To rebuild everything, manually run **Build Strata release** with an existing
tag and enable **force_full**. Use this when you want fresh Fedora build
dependencies or need to refresh upstream downloads even though tracked inputs
are unchanged. The first release after adding this feature performs a full
build to establish the manifest.

## Build and verification

The workflow requires matching runtime RPMs for every package defined in the
six specs, either built now or verified for reuse. It checks RPM digests, exact source versions, missing packages,
duplicates, file sizes and regenerated DNF metadata. It also resolves a fresh
Fedora dependency transaction with weak dependencies disabled, Quickshell's
COPR and RPM Fusion Free enabled. That check does not install the desktop.

On success it creates a **draft GitHub release** containing the runtime RPMs,
`SHA256SUMS`, `release-manifest.json`, and `strata-repository-f44-x86_64.tar.gz`. The archive contains a
complete DNF repository, including metadata, `strata.repo` and the bootstrap
installer at its existing `bin/strata-install-desktop` URL. Build artifacts
are retained in Actions for seven days; assets attached to the release remain
there independently of Actions retention. Every release archive is complete;
it never requires older releases to install or deploy. The manifest records
the input fingerprints and package checksums for the next release's planner.

Download the draft artifacts and test installation and upgrade in a Fedora 44
VM. Check login, locking, audio, capture, clipboard, themes and update detection.
Then publish the draft release in GitHub. Re-running a tag with an existing
release fails rather than replacing its assets; delete a failed draft before
retrying when appropriate.

## Deploy the DNF repository

Publishing a stable release triggers **Publish Strata repository**. It checks
out the release tag, downloads the repository archive, checks its checksum,
verifies its RPM versions and deploys only public repository files to Pages.
The repository must have GitHub Pages configured to use **GitHub Actions**.

Ordinary pushes to `main` do not deploy packages. To retry deployment, manually
run the Pages workflow with the required published tag. Both automatic and
manual deployments download release assets; there is no fallback to committed
RPMs. `packages/` and `repodata/` are ignored build products.

The `github-pages` environment must allow release tags: under repository
Settings → Environments → github-pages → Deployment branches and tags, add
a Tag rule for `v*`. A branch rule for `main` alone does not allow a release
event whose ref is a tag.

Creating a draft does not change the live DNF repository. Publishing the draft
starts deployment; installed systems discover updates through the existing
DNF update checker after the Pages deployment finishes.
