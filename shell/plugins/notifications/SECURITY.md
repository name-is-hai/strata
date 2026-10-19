# Notification security

Notification text, identities, images, hints, URLs, actions, and phone messages are untrusted. The service validates executable actions, bounds helper input, and can require Bubblewrap isolation through the Notification settings. Run `strata-shell notifications.debug probe` to inspect the active helper mode.

Report vulnerabilities through the Strata project's private reporting channel when available. Include the commit, Qt/Python versions, a synthetic reproduction, expected and actual behavior, and a redacted sandbox probe. Do not post real notification history or credentials in public issues.

The service was adapted from [Omapager](https://github.com/njpatel/omapager); its original [MIT license](LICENSE) is retained.
