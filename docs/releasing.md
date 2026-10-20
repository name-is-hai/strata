# Releasing Strata

A GitHub release has its own version in `VERSION`. Each RPM spec has an
independent Version and Release. A release can combine newly built RPMs with
verified, unchanged RPMs from the previous stable release. Reused RPMs keep
their original versions and checksums; they are never renamed or relabeled.

## Start a release

1. Update only the packages that changed. For example, after changing shell
   code, bump config with `bin/strata-package-version config 1.1.2 -m "Fix greeter scaling"`.
   To rebuild a package without changing its upstream version, keep that version:
   `bin/strata-package-version ghostty 1.3.1 -m "Fix packaging"` increments
   its RPM Release. Use `--release NUMBER` to choose a release explicitly.
   Updating Ghostty to a new upstream version is similarly
   `bin/strata-package-version ghostty NEW_VERSION -m "Update Ghostty"`.
   Only that target's spec and changelog change. Config also updates
   `runtime-version`, which identifies the installed config package.
2. Run `bin/strata-release-version 1.1.2 -m "Describe this release"`.
   This changes only `VERSION` and `.github/release-notes.md`; it never bumps
   RPMs. Repeat `-m` for additional release-note bullets. Package changelogs
   belong to `strata-package-version -m`, while release notes describe the
   GitHub release. Editing only `VERSION` and running the release command
   without a version also works. Omitting `-m` preserves existing matching notes.
3. Commit and push the source changes. CI uses committed inputs, not local
   build output. Create and push the matching new tag:

   ```bash
   git tag -a v1.1.2 -m 'Strata 1.1.2'
   git push origin v1.1.2
   ```

The release tag must match `VERSION` and the release-note heading.
`runtime-version` must match `strata-config.spec`, independently of the tag.
Every final RPM must match its own spec's Epoch, Version, Release and architecture.
Local builds and CI validate these relationships before publishing.
Changing package source without increasing its RPM Version or Release will not
make DNF recognize a new update; bump the changed package before tagging.

The **Build Strata release** workflow can also be started manually with an
existing matching tag. All jobs use the same resolved commit. Planning runs
on Node.js 24, and workflow actions use Node.js 24 runtimes.

## Reusing unchanged packages

CI downloads the most recently published stable release other than the requested
tag. It verifies the repository archive and manifest against `SHA256SUMS`.
Missing or invalid baseline assets cause a full build. Each reused RPM is
checked individually against its recorded digest.

| Target | Build inputs and outputs |
| --- | --- |
| Config | Config spec, shell, commands, defaults, themes, documentation, native and vendored code, runtime version and casting service files. Builds config and its casting backends together. |
| Desktop | Dependency metapackage spec and its local license. No application compilation. |
| Ghostty | Standalone `packaging/ghostty.spec`. |
| UWSM | Standalone `packaging/uwsm.spec`. |
| Lock auth | PAM spec, policy and license. |
| Hyprland | Compositor, portal and GUI utility spec. |
| Utilities | Utility spec; Hypridle, Hyprpicker and Hyprsunset remain one target. |
| Fonts | Font spec. |

`VERSION` and release notes do not affect RPM fingerprints. A Ghostty spec
update rebuilds only Ghostty; it does not rebuild config, desktop, Zen or UWSM.
The config source archive includes only its casting packaging assets, not other
packages' specs. Its installed documentation and commands remain build inputs.

Reuse operates per target, so a config change still rebuilds its casting
backends, and a utilities change rebuilds its grouped utilities.

Build ownership is declared in `packaging/build/targets.json`: each target tracks
its own definition, spec, local sources and optional source-preparation recipe.
Add new patches and local sources to their target's inputs; unassigned packaging
files stop planning with an error. Changing one target's definition affects only
that target. CI takes its target matrix from this list.

`packaging/build/common.sh` controls shared compiler/dependency setup, and
`packaging/build/environment.sh` defines the Fedora image. Changes to either
invalidate all targets. Put shared build behavior in these files so reuse tracks
it. The Podman wrapper and `packaging/build/run.sh` only dispatch builds and
collect artifacts. Planner and workflow edits do not invalidate binary inputs.
The wrapper still affects config because config ships the commands in `bin/`.
CI image overrides must be recorded in the shared environment file.

Zen is an optional per-user installation from the official tarball and updates itself; it
is not an RPM target. See [Zen installation](zen.md) for fresh installs and
migration from the former browser RPMs.

The first release using the scoped-input manifest (schema 3) performs a full build
because the manifest format changed. Later releases can reuse unchanged targets. Enable
**force_full** in a manual run to rebuild all targets deliberately.

## Build and verification

The workflow requires matching runtime RPMs for every package defined in the
specs under `packaging/`, either built now or verified for reuse. It checks RPM digests, exact source versions, missing packages,
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
