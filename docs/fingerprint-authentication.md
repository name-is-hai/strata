# Fingerprint authentication

When strata-config is installed or updated, Strata checks for a reader supported
by fprintd. If one is present, it enables `with-fingerprint` on the current Fedora
authselect profile. This makes fingerprint authentication available to `sudo`
and `pkexec`, with password fallback. Other services using `system-auth` also
inherit the feature. No fingerprint is enrolled automatically.

Enroll your own finger as your normal user:

```bash
fprintd-enroll
```

Then test in a terminal:

```bash
sudo -k
sudo true
```

Fedora's PAM stack tries the fingerprint first, then falls back to a password
after an unsuccessful scan or timeout. It does not offer both simultaneously.

Machines without a supported reader keep password authentication. If a reader
is added later, rerun the check:

```bash
sudo /usr/share/strata/bin/strata-fingerprint-configure
```

The setup preserves the selected profile and its other features, skips profiles
without fingerprint support, and refuses to overwrite modified PAM files.
Authselect makes a backup before enabling the feature. To disable it:

```bash
sudo authselect disable-feature with-fingerprint
```

An install or upgrade will enable it again if a supported reader is detected.
