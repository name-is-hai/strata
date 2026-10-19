# Building Strata RPMs

For automated builds and publication from version tags, see [Releasing Strata](releasing.md).

Use the rootless Podman builder so compiler and `-devel` dependencies do not
change the installed Strata system:

```bash
bin/strata-build-rpms config
bin/strata-build-rpms desktop
```

The `desktop` target includes the Zen Browser and matching engine RPMs. It downloads the pinned
official Zen Linux archive during the build and writes `zen-browser` plus
`zen-browser-engine` beside the
other desktop RPMs.

Use `all` to build every source package. Results are written to
`build-output/RPMS/`. Test those RPMs in a VM before copying the selected,
tested files into `packages/` for publication.

The `config` target uses one source spec, `packaging/strata-config.spec`, to build
five runtime RPMs: `strata-config`, `strata-casting`, `strata-waycast`,
`strata-doubletake` and `strata-cast`. The desktop and backends share one
release version and source archive while remaining separately installable.
Use `config` for casting builds as well; there is no separate `casting` target.

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

The source release is `1.0.0`. Build the changed targets together:

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

The 1.0 runtime RPMs are staged in `packages/`. For subsequent builds, test
the build in a VM and replace each affected package in `packages/` with its new
runtime RPM. Include the four desktop packages, the four casting packages,
`strata-config`, `hyprland-utilities` and both rebuilt Zen RPMs. Keep the required
unchanged Hyprland, portal, fonts, authentication and other dependency RPMs.
Debug and source RPMs belong in build output rather than the public runtime set.

Before publication, regenerate and verify metadata:

```bash
bin/strata-repo-refresh
bin/strata-repo-verify
```

Run these on Fedora 44 with `createrepo_c`, DNF and `rpm-build` available.
The verifier rejects missing, duplicate or oversized RPMs and compares public
versions against the source specs. Pages runs this gate before deployment.
Publishing a stable GitHub release deploys its CI-built repository; manual
Pages runs can still deploy the committed packages. Source pushes alone do not deploy.
No Git tag, push, GitHub release or publication is part of release preparation.

If the host lacks `createrepo_c`, run metadata generation and verification in
a disposable Fedora 44 Podman container with `createrepo_c` and `rpm-build`.
The public packages must be staged before regenerating metadata; building alone
only updates `build-output/RPMS/`.

For metadata checks without installing host tools:

```bash
podman run --rm --user 0 -v "$PWD:/repo:Z" -w /repo \
  registry.fedoraproject.org/fedora:44 bash -euc '
    dnf install -y --setopt=install_weak_deps=False createrepo_c rpm-build
    bin/strata-repo-refresh
    bin/strata-repo-verify
  '
```
