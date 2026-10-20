# Building Strata RPMs

For automated builds and publication from version tags, see [Releasing Strata](releasing.md).

Use the rootless Podman builder so compiler and `-devel` dependencies do not
change the installed Strata system:

```bash
bin/strata-build-rpms config
bin/strata-build-rpms desktop
```

The `desktop` target builds only the desktop dependency metapackages.
Use `bin/strata-build-rpms ghostty`, `zen` or `uwsm` to build each application
independently. The `zen` target produces both the browser and matching engine RPM.

Use `all` to build every source package. Results are written to
`build-output/RPMS/`. Test those RPMs in a VM. Publication uses CI-built
release assets; generated RPMs and metadata are excluded from Git.

The `config` target uses one source spec, `packaging/strata-config.spec`, to build
five runtime RPMs: `strata-config`, `strata-casting`, `strata-waycast`,
`strata-doubletake` and `strata-cast`. The desktop and backends share one
release version and source archive while remaining separately installable.
Use `bin/strata-build-rpms lock-auth` for the independent password PAM policy
package. Use `config` for casting builds as well;
there is no separate `casting` target.

These tools live in `bin/` and are also installed as `strata build rpms`,
`strata repo refresh`, and `strata repo verify`. Installed developer commands
must run from a Strata checkout, or with `STRATA_REPO_DIR` set to its path.

The installer calls the RPM-provided `strata-setup-greeter` command when
`--enable-greetd` is selected. Greeter setup uses installed files under
`/usr/share/strata`; it does not copy application files from a source checkout.

Rust dependencies are pinned by the vendored lockfiles and downloaded in the
build container; runtime installs do not build code. The Waycast/Doubletake
release archives are checksum verified. Corresponding Doubletake source is
included under `third_party/doubletake`. The installer enables RPM Fusion Free
for the Miracast x264 GStreamer encoder and media transcoding codec library.

The `utilities` target packages the Hyprland utilities group. It also requires
Fedora’s `hyprcursor` package for cursor-theme tools; `strata-config` also
requires it directly for fresh installs.
The public tools do not replace Hyprland’s private Hyprcursor runtime library.

## Preparing the 1.0 release

The source release is `1.0.1`. Build the changed targets together:

```bash
bin/strata-build-rpms config desktop utilities
```

The Strata config, desktop and casting packages use RPM Epoch 1 so that
`1:1.0.0-1` upgrades existing `4.0.0~alpha` development installations. Keep
that epoch in subsequent releases. UWSM, Ghostty and Zen keep epoch 0 and their
upstream versions; the utilities meta-package uses 1.0.0 while its upstream
Hyprland tools keep their own versions. Zen's packaging release is 3 and the
desktop source package uses XZ payload compression to reduce the large browser RPM.
The engine is packaged separately so neither browser RPM exceeds the per-file
limit. Use `bin/strata-build-rpms zen` to repackage only Zen, without rebuilding
Ghostty or UWSM.

GitHub builds changed targets, reuses verified unchanged RPMs from the previous
release, assembles a complete runtime repository, verifies it
and attaches it to a draft release. Publishing the draft deploys that repository
to Pages. The manual Pages action requires a published tag too; it never uses
committed RPMs. See [Releasing Strata](releasing.md).

For local assembly testing, build all targets into a clean output directory:

```bash
STRATA_BUILD_OUTPUT="$PWD/build-output/local-release" bin/strata-build-rpms all
```

Then assemble and verify the result in Fedora 44:

```bash
podman run --rm --user 0 -v "$PWD:/repo:Z" -w /repo \
  registry.fedoraproject.org/fedora:44 bash -euc '
    dnf install -y --setopt=install_weak_deps=False createrepo_c rpm-build
    bash .github/scripts/assemble-release.sh build-output/local-release/RPMS
  '
```

Local assembly requires matching RPMs for all specs under `packaging/`. It generates
ignored `packages/` and `repodata/` directories, plus release assets under
`build-output/release/`. It does not publish anything or install packages
on the host. The generated repository can also be checked with
`bin/strata-repo-refresh` and `bin/strata-repo-verify` when the required
Fedora tools are available.
