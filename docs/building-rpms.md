# Building Strata RPMs

Use the rootless Podman builder so compiler and `-devel` dependencies do not
change the installed Strata system:

```bash
scripts/build-rpms-podman config
scripts/build-rpms-podman desktop
```

The `desktop` target includes the Zen Browser RPM. It downloads the pinned
official Zen Linux archive during the build and writes `zen-browser` beside the
other desktop RPMs.

Use `all` to build every source package. Results are written to
`build-output/RPMS/`. Test those RPMs in a VM before copying the selected,
tested files into `packages/` for publication.

Wireless display and media-casting backends have a separate build target:

```sh
scripts/build-rpms-podman casting
```

Build/publish its `strata-casting`, `strata-waycast`, `strata-doubletake`, and
`strata-cast` RPMs before the new `strata-config`, which requires them. The
`all` target builds casting automatically. Rust dependencies are pinned by the
vendored lockfiles and downloaded in the build container; runtime installs do
not build code. The Waycast/Doubletake release archives are checksum verified.
Corresponding Doubletake source is included under `third_party/doubletake`.
The installer enables RPM Fusion Free for the Miracast x264 GStreamer encoder
and media transcoding codec library.

The `utilities` target packages the Hyprland utilities group. It also requires
Fedora’s `hyprcursor` package for cursor-theme tools; `strata-config` also
requires it directly for fresh installs.
The public tools do not replace Hyprland’s private Hyprcursor runtime library.
