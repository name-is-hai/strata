# Pending design discussions

## Removing and restoring built-in plugins

Recorded on 2026-10-18. Deferred at the user's request; no implementation decision yet.

Desired possibility: treat built-in plugins like other plugins, allowing Remove
to delete their files cleanly and Restore to bring them back later.

Current behavior: Delete offers Disable for built-ins, preserving their files
and settings. Only user-installed plugins can be uninstalled. Built-in files
are owned by the Strata RPM under `/usr/share/strata`.

Discuss before implementing:

- What Remove should delete: plugin files, saved settings, and related state.
- How Restore obtains the files and whether it restores previous settings.
- Whether package updates or reinstalls should restore removed defaults, or
  preserve removal choices using a persistent record.
- What a fresh installation or replacement config should do. Replacing config
  alone currently does not reinstall deleted package-owned plugin files.
- How removal and restoration should interact with RPM ownership and required
  privileges, and with dependencies between plugins.

The user wants time to consider the behavior before proceeding. Keep the
current built-in Disable behavior until the discussion resumes.
