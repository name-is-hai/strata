# Strata 1.0.0 release review

This records the earlier local-build review. The repository now builds all
RPMs from source in CI, including lock authentication; generated packages and
metadata have been removed from Git. See [Releasing Strata](releasing.md)
for the current publication process. The results below describe the earlier
24-RPM set, before this migration.

Reviewed 2026-10-19 against the current working tree. The release RPMs have been built and staged in `packages/`. Repository metadata verification and the fresh Fedora dependency transaction both pass. No host package installation, login-manager switch, commit, tag, or deployment was performed.

## Corrections made during review

- Pages now runs repository verification after generating metadata and before deployment. Failed verification stops publication.
- `strata-repo-verify` now checks actual RPM presence, duplicate package names, the 100 MiB per-file limit, required desktop packages, and published EVRs against source specs. It needs Fedora 44, DNF and `rpm-build`.
- Added an isolated regression test: matching versions pass; old versions, duplicates, oversized RPMs, missing files and incomplete metadata fail. It runs no real DNF transaction.
- Fixed missing or misplaced CLI metadata headers. All 212 commands now pass `bin/strata commands --check`.

## Source and packaging results

| Area | Result |
| --- | --- |
| Version files | `VERSION` and `runtime-version` both contain `1.0.0`. |
| Config and desktop | Epoch 1, version `1.0.0`, release `1.fc44`. Epoch preserves upgrade ordering from development builds. |
| Casting packages | All four use `1:1.0.0-1.fc44` and build from the combined config spec. Internal exact-version requirements agree. |
| Utilities collection | `0:1.0.0-1.fc44`; individual Hyprland utilities retain upstream versions. |
| Zen | `0:1.23b-3.fc44`; browser and required engine are separate RPMs, approximately 54 MiB and 53 MiB. Both fit the 100 MiB publication limit. |
| Other upstream packages | Hyprland, portal, fonts, Ghostty and UWSM retain upstream versions. |
| Removed requirements | Hyprlock, Playerctl, Pavucontrol, Buildah, Skopeo and libvips tools are absent from default direct requirements. |
| Native helpers | C++ font-outline sizing remains. The mouse-specific HID helper and rule are removed; the cursor-shake rule remains in use. |
| Mouse settings | Menu-only panel and background battery service. The shipped layout has no Mouse bar entry. |
| Defaults | One source `defaults/` tree. Existing installed paths remain, including Hyprland's `default.hypr.*` namespace. |
| Source archive | Exercised the actual builder's archive functions without running build steps. Required defaults, commands, C++ helper and casting lockfiles are present. Git metadata, backups and build caches are excluded. |
| Plugins and assets | First-party entry points exist. No broken symlinks in defaults, config, shell or vendored sources. |
| Developer commands | Moved commands are discoverable. Mocked Podman dispatch and installed-command checkout discovery pass. |
| Spec structure | All five specs parse. Combined config/casting file ownership retains the `strata-castd` exclusion from the config package. |

The restored top-level Rust CLI remains a development prototype at its own `0.1.0` workspace version. It is not the production shell or an RPM build target; this review leaves that independent prototype version alone.

## Checks completed

- Bash syntax validation for 212 scripts under `bin/` and `scripts/`.
- CLI metadata validation for 212 commands.
- Doctor, menu-extension, update-checker and ImageMagick image-tool tests.
- Shared lock/greeter input interactions, power signals and identical rendering using the existing offscreen QML fixture. No real authentication or power actions.
- Theme-picker model, preferences, background selection, current selection, framing and hostile-input suites. The hostile suite ended with `ALL OK`.
- Publication-verifier positive and negative regression cases.
- Offline parsing of both casting Cargo workspace manifests with lockfiles. This does not compile dependencies or run Rust tests; those run during the RPM build.
- All five RPM specs and working-tree whitespace validation.

## Post-build package staging

The public set now contains 24 RPMs. Nineteen runtime RPMs were staged from the completed builds; unchanged dependency packages were retained. Superseded packages were backed up under ignored `backups/packages-before-1.0-*` directories. All public RPM digest checks pass, and each file is below 100 MiB. Metadata was regenerated in a disposable Fedora 44 container; `strata-repo-verify` passes against the 24-package public set.

The initial errors came from checking the old `packages/` set while the new builds remained in `build-output/RPMS/`. The missing host `createrepo_c` is handled for this validation by a disposable Fedora container.

Zen initially exceeded the publication limit even with XZ compression. Its engine is now a required, exactly versioned subpackage. A new `zen` build target packages only Zen and avoids rebuilding Ghostty/UWSM; it preserves the full desktop source RPM by building binary RPMs only.

A disposable Fedora 44 container also resolved the complete `hyprland-desktop strata-config` transaction with weak dependencies disabled, RPM Fusion Free and the Quickshell COPR enabled. DNF proposed 737 packages; `--assumeno` deliberately prevented installation. This confirms dependency resolution, not a real desktop installation or upgrade.

## Build and publication sequence

From the checkout, build the changed targets:

```bash
bin/strata-build-rpms config desktop utilities
```

Test the built runtime RPMs in a fresh Fedora 44 VM before publication. Check dependency resolution with weak dependencies disabled, installation with `--enable-greetd`, login, lock/unlock, menu-only Mouse settings, clipboard paste, capture, audio, theme/background selection and update detection. Also test an upgrade from an existing Strata installation. Greeter setup was checked for syntax, help and its root guard; it was not used to switch a real login manager during this review.

For subsequent releases, use the automated [release workflow](releasing.md).
It builds fresh RPMs from a version tag and creates a draft release. Publishing
that draft deploys its repository to Pages. Source pushes do not deploy
packages, and manual Pages runs also require release assets.
