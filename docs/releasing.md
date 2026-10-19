# Releasing Strata

GitHub builds Fedora 44 x86_64 RPMs when a version tag is pushed. It builds
`config`, `desktop`, `hyprland`, `utilities` and `fonts` on separate runners,
then combines their runtime packages. Debug and source RPMs are excluded from
the public repository. The existing `strata-lock-auth` RPM is retained because
it has no source spec in this checkout.

## Start a release

1. Update `VERSION`, `runtime-version` and the Strata versions/releases in the
   config, desktop and utilities specs. Update their `%changelog` sections.
   Keep RPM Epoch 1 for config, casting and desktop packages. Upstream package
   versions remain independent.
2. Commit and push the source changes, including the workflows. CI builds new
   runtime RPMs; there is no need to copy local build output into Git.
3. Create and push the matching tag, for example:

   ```bash
   git tag -a v1.0.0 -m 'Strata 1.0.0'
   git push origin v1.0.0
   ```

The **Build Strata release** workflow can also be started manually from
GitHub Actions with an existing tag. The tag must match `VERSION` and
`runtime-version`. Every build uses the same resolved commit.

## Build and verification

The workflow requires fresh runtime builds for every package defined in the
five specs. It checks RPM digests, exact source versions, missing packages,
duplicates, file sizes and regenerated DNF metadata. It also resolves a fresh
Fedora dependency transaction with weak dependencies disabled, Quickshell's
COPR and RPM Fusion Free enabled. That check does not install the desktop.

On success it creates a **draft GitHub release** containing the runtime RPMs,
`SHA256SUMS`, and `strata-repository-f44-x86_64.tar.gz`. The archive contains a
complete DNF repository, including metadata, `strata.repo` and the bootstrap
installer at its existing `bin/strata-install-desktop` URL. Build artifacts
are retained in Actions for seven days; assets attached to the release remain
there independently of Actions retention.

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

Ordinary pushes to `main` no longer deploy the committed RPMs over a release.
To retry deployment, manually run the Pages workflow with the published tag.
For the legacy local-build path, leave that field empty to verify and deploy
the committed `packages/` set from the selected branch.

Creating a draft does not change the live DNF repository. Publishing the draft
starts deployment; installed systems discover updates through the existing
DNF update checker after the Pages deployment finishes.
