# Menu extensions

Strata reads shipped menu rows from `defaults/strata/strata-menu.jsonc`, then
merges `~/.config/strata/extensions/strata-menu.jsonc` over them. The personal
file is watched for changes. Updating the shipped menu does not rewrite it.

The extension format follows Omarchy: object keys are row IDs, dotted IDs infer
their parent submenu, and reusing an ID overrides that row. Only fields present
in the extension replace shipped fields. For example, an action-only override
keeps the original label, icon and search aliases:

```jsonc
{
  "style.theme": {"action":"strata-shell shell toggle strata.theme-picker"},
  "personal": {"icon":"", "label":"Personal"},
  "personal.files": {"label":"Documents", "action":"uwsm-app -- nautilus ~/Documents"},
}
```

Strata ships a Python-free Swatch port as its default theme picker, with the
ID `strata.theme-picker`. The example toggles that picker directly.

Supported row fields are `icon`, `iconFont`, `label`, `title`, `description`,
`action`, `target`, `parent`, `provider`, `aliases`, `when`, `checked`, `disabled`
and `plugin`. `target` links to an existing submenu. `aliases` accepts a string
or array and contributes routes and search terms. `when`, `checked` and
`disabled` are shell conditions. `plugin` gates a row on an enabled plugin;
bare `strata-shell shell summon` and `toggle` actions infer that ID automatically.
Explicit empty fields clear inherited values. Clearing `action` makes a row a
submenu, or a link when `target` is supplied.

Providers must already exist in the shell; a JSONC file cannot define executable
providers. Strata includes fonts, applications, plugins and tray sources.
Line comments, block comments and trailing commas are accepted outside strings.

## Menu routes

These supported features use Omarchy's route names directly in the shipped
menu. IDs, explicit parents and link targets are used literally; there is no
translation table for older Strata names. Extensions must use the current IDs.

| Feature | Route |
| --- | --- |
| Themes & backgrounds | `style.theme` |
| Fonts | `style.font` |
| Install theme | `install.style.theme` |
| Install web app | `install.webapp` |
| Remove web app | `remove.webapp` |
| Remove theme | `remove.theme` |
| Plugins | `setup.plugin` |
| Install plugin | `setup.plugin.add` |
| Input method | `setup.typing.input` |
| Display layout | `setup.monitors` |
| Hyprland config | `setup.config.hyprland` |
| Color picker | `trigger.capture.color` |
| Menu bar | `trigger.appearance.top-bar` |

Strata retains its own menu labels and Fedora commands. Omarchy features absent
from Strata are not added as empty menu entries. Existing personal files are not
rewritten; any overrides using retired IDs must be updated explicitly.

Shared route names and JSONC syntax do not provide universal plugin runtime
compatibility. An extension using `omarchy-shell`, other `omarchy-*` commands,
Omarchy configuration/state paths, Arch package tools or unavailable shell APIs
still needs adaptation. Commands are executed as written, with no automatic
prefix or path substitution. Check plugin dependencies separately.

Run the host-side regression checks with `node scripts/tests/menu-extensions.js`.
