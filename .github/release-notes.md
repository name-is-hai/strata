# Strata 1.1.19

- Add fingerprint unlock and greeter login with fprintd and fprintd-pam installed by default
- Offer Use fingerprint at login, with a five-second scan window and Fedora password fallback
- Migrate managed greeter configurations with backups while preserving custom PAM policies and auto-login setups
- Fingerprint login may still require a password to unlock the login keyring; physical reader testing remains necessary
