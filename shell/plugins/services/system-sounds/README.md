# Strata system sounds

This first-party service adapts [omarchy-system-sounds](https://github.com/Dielerorn/omarchy-system-sounds) under its MIT license. The bundled Glass and Classic themes and the event logic come from that project. The settings icon in Strata's Audio header opens a separate panel view with the System sounds switch, sound volume, theme picker, and per-event switches and previews.

Settings live in `~/.config/strata/sounds.json`. Place overrides in `~/.config/strata/sounds/<theme>/`, with files named for events such as `notification.ogg` or `device-added.wav`. A Strata desktop theme can supply a `sounds/` directory. Use `strata-sounds state` to inspect the active setup and `strata-sounds preview notification` to test a cue.

Strata's notification service triggers the notification, screenshot, reminder, and crash cues when it shows a new popup. It respects Strata's Do Not Disturb and notification sound switch, so a notification plays at most one system cue. The system-sounds service handles volume, bell, device, Bluetooth, theme, battery, power, startup, shutdown, authentication, and trash events.
