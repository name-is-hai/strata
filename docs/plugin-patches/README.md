# Optional plugin patches

## Isobar card border

`isobar-card-border.patch` replaces the native Rectangle border on Isobar's
place cards with Strata's `BorderOverlay`. This avoids the missing left edge
seen inside the clipped Places viewport. It was prepared for
`atsokolas.isobar` version 1.1.1.

The patch is supplied for review and manual application. Strata does not
modify installed third-party plugins during package updates. A subsequent
Isobar update may replace this local change.

From this directory, check the patch against the installed plugin first:

```bash
patch --dry-run -p1 -d ~/.config/strata/plugins/atsokolas.isobar < isobar-card-border.patch
```

If the check succeeds, apply it with a backup:

```bash
patch --backup --suffix=.before-strata-border-fix -p1 \
  -d ~/.config/strata/plugins/atsokolas.isobar < isobar-card-border.patch
strata-restart-shell
```

The `patch` utility is needed only to apply this optional patch. Skip it if the
plugin already contains the fix. The shared visible-page header fix ships as
part of Strata's UI and needs no plugin patch.
