# Strata Notification

Strata's notification service owns `org.freedesktop.Notifications`. It shows popups, actions, inline replies, snoozed sources, and Do Not Disturb. Its center uses [Foamy Notification Center](https://github.com/foamrider/foamy-notification-center) for app stacks, search, unread badges, and integrated settings. The plugin ID is `strata.notifications`; its helpers are private to `shell/plugins/notifications/bin`.

Configure the bar widget in `~/.config/strata/shell.json` and use its notification panel for quick controls. The service stores history, quiet state, retention policy, resolved icons, and reply data under `~/.local/state/strata/notifications/`. A one-time migration copies these from the earlier Omapager state path; it leaves the original files for verification. Custom application icons are migrated to `~/.config/strata/notifications/icons/`.

Use `strata-shell notifications.debug probe` to inspect the service, `strata-shell notifications dnd` to toggle Do Not Disturb, and `strata-shell shell toggle strata.notifications` to open the panel. `bin/notification-demo --list` lists the optional demo scenes.

This service was adapted from [Omapager](https://github.com/njpatel/omapager) for Strata. Its original copyright and license are retained in [LICENSE](LICENSE). Strata's integration, settings, runtime paths, and commands are maintained here.

Open the bell → More (⋯) → Settings for both center and popup preferences. All
preferences retain the `strata.notifications` entry in `shell.json`; no reset
or separate Foamy configuration is needed. Existing history and quiet state
stay in the same store. Retention stays at your existing hours setting; the
center can also set the maximum entry count (default 100). X removes an entry
from live popups and history; clearing the center does the same for all entries.
Right-clicking the bell still toggles Do Not Disturb. The center header also
has a Silence notifications switch. More offers timed snooze; while anything
is snoozed, a small clock button appears in the header. Its compact popup lists
snoozed sources with their remaining time and lets you resume one source or all of them. The normal
popup cards and their actions are unchanged.

Settings are organized into Center, Popups, and Quiet & privacy tabs, with
grouped controls and automatic saving. The header and tabs stay visible while
scrolling; long option labels wrap within the panel.

The adapted UI and its upstream revision/licenses are in `center/`. It uses
Strata's shared service, output-aware panel geometry, fonts and theme colors.
There is no extra notification daemon, archive watcher, or popup-settings
helper process. Fresh RPM installs include it through the existing shell tree.

The options and snooze buttons share one themed popup, avoiding nested
platform menus.
