# Building Strata RPMs

Use the rootless Podman builder so compiler and `-devel` dependencies do not
change the installed Strata system:

```bash
scripts/build-rpms-podman config
scripts/build-rpms-podman desktop
```

Use `all` to build every source package. Results are written to
`build-output/RPMS/`. Test those RPMs in a VM before copying the selected,
tested files into `packages/` for publication.
