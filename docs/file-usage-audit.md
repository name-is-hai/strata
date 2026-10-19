# File usage audit — 2026-10-19

The audit inventoried 1,129 non-generated project and vendored files. It checked
text references, plugin manifests, QML module exports and imports, dynamic
indicator loading, command discovery, default configuration loading, RPM specs,
source archive construction, installation scripts and Cargo module boundaries.
It did not treat a missing literal reference as proof that a file is unused.

## Removed

- `shell/plugins/menu/strata-mark.svg`: old logo with no remaining consumer;
  the menu uses the Fedora font glyph.
- `config/hypr/hyprlock.conf`: unused alternative lock-screen template. The
  configured lock command uses the Quickshell lock plugin. The independently
  packaged Hyprlock utility is retained.
- Three generated notification Python bytecode files under `__pycache__`.

The Rust CLI prototype and its 19 workspace/source/configuration files were
restored at the user's request. It remains available for continued development.
The remaining cleanup removes two unused source/configuration files and three
generated files. Stale indicator documentation and a comment referring to the removed
notification implementation were corrected.

## Retained deliberately

| Files | Why they remain |
| --- | --- |
| Top-level Rust CLI workspace (`crates/`, Cargo files, `mise.toml`) | Restored at the user's request for continued development; currently a prototype. |
| `bin/` commands | Public commands discovered from executable names and metadata, including commands without menu references. |
| Plugin manifests and their entry points | Discovered and loaded dynamically by the shell. |
| `shell/Ui/MultiSelect.qml` and other exported UI types | Part of the `qs.Ui` module available to external plugins. |
| Optional indicators such as `Dnd.qml` | Still loadable through explicit indicator settings; absence from defaults does not make them dead code. |
| `config/hypr/hyprsunset.conf` | Loaded implicitly by the Hyprsunset service, which autostart and the night-light helper start. |
| Generic image picker | Used by the shell's image-selection IPC. The theme picker does not replace arbitrary scripted image selection. |
| 341 vendored files | Casting, screenshot and cursor-monitor source trees, their tests, platform variants, build metadata and licenses. |
| Cursor assets and aliases, themes and templates | Selected by name or scanned by directories; these need no individual source reference. |
| Package licenses | Some identical license text must be shipped with different packages. |
| `packages/`, `repodata/` and repository publishing files | The distributable DNF repository, not disposable source leftovers. |
| Ignored `build-output/` | Build artifacts and reusable build outputs; not classified as unused runtime source. |
| Private configuration and developer metadata | Outside this cleanup. No files in the user's `.config` were changed. |

The casting backends retain their own Cargo manifests and lockfiles under
`third_party/waycast` and `third_party/strata-cast`; their RPM build commands
explicitly target those independent workspaces.

## Validation

- All 180 manifest entry points, clone paths, relative QML imports and module
  exports resolve after deletion.
- Syntax checks passed for 233 shell scripts.
- Menu-extension, update-checker, theme model and background-application checks
  passed.
- The active Bash CLI still renders its command help.
- Both casting Cargo workspaces resolve independently with offline metadata.
- Config, desktop and casting RPM specs parse successfully.
- The restored Rust workspace compiles. Its CLI command actions remain
  unfinished; restoring it does not replace the active Bash CLI.

The command metadata checker reports 30 pre-existing missing summaries in
retained commands. These are documentation gaps, not evidence that the commands
are unused; those command files were not changed by this cleanup.

No installed system files, running services, published RPMs or private
configuration were changed. A full RPM rebuild and interactive desktop test
were not performed for this source cleanup.
