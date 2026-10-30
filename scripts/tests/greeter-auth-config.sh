#!/usr/bin/env bash
# Exercise the actual config migration on temporary files, without root/PAM.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d /tmp/strata-greeter-auth.XXXXXXXX)
trap 'rm -rf "$work"' EXIT
eval "$(awk '/^configure_greeter_auth\(\)/,/^}/' "$repo/bin/strata-greeter-auth-configure")"
eval "$(awk '/^greeter_config_value\(\)/,/^}/' "$repo/bin/strata-greeter-auth-configure")"
restorecon() { :; }
file=$work/config.toml
cat >"$file" <<'CONFIG'
[terminal]
vt = 3
[default_session]
command = "/usr/share/strata/bin/strata-greeter-session"
user = "greetd"
CONFIG
cp "$file" "$work/original"
configure_greeter_auth "$file"
[[ $(greeter_config_value "$file" general service) == strata-greetd ]]
[[ $(greeter_config_value "$file" default_session service) == greetd-greeter ]]
grep -qx 'vt = 3' "$file"
cmp "$work/original" "$file.before-strata-fingerprint"
cp "$file" "$work/configured"
configure_greeter_auth "$file"
cmp "$work/configured" "$file"
cmp "$work/original" "$file.before-strata-fingerprint"
for policy in custom-login greetd strata-greetd; do
  printf '[general]\nservice = "%s"\nsource_profile = false\n' "$policy" >"$file"
  cat "$work/original" >>"$file"
  cp "$file" "$work/before"
  configure_greeter_auth "$file"
  if [[ $policy == custom-login ]]; then cmp "$work/before" "$file"
  else
    [[ $(greeter_config_value "$file" general service) == strata-greetd ]]
    grep -qx 'source_profile = false' "$file"
  fi
done
printf '[ general ] # Existing policy\nservice = "greetd"\n' >"$file"
cat "$work/original" >>"$file"
configure_greeter_auth "$file"
[[ $(greeter_config_value "$file" general service) == strata-greetd ]]
[[ $(grep -c '^service = "strata-greetd"$' "$file") == 1 ]]
printf '["general"]\nservice = "custom-login"\n' >"$file"
cat "$work/original" >>"$file"
cp "$file" "$work/before"
configure_greeter_auth "$file"
cmp "$work/before" "$file"
printf '[general]\n"service" = "custom-login"\n' >"$file"
cat "$work/original" >>"$file"
cp "$file" "$work/before"
configure_greeter_auth "$file"
cmp "$work/before" "$file"
cp "$work/original" "$file"
printf 'service = "custom-greeter"\n' >>"$file"
cp "$file" "$work/before"
configure_greeter_auth "$file"
cmp "$work/before" "$file"
sed 's|/usr/share/strata/bin/strata-greeter-session|/custom/greeter|' "$work/original" >"$file"
cp "$file" "$work/before"
configure_greeter_auth "$file"
cmp "$work/before" "$file"
cp "$work/original" "$file"
printf '\n[initial_session]\ncommand = "custom-session"\nuser = "someone"\n' >>"$file"
cp "$file" "$work/before"
configure_greeter_auth "$file"
cmp "$work/before" "$file"
rm "$file"
ln -s "$work/original" "$file"
configure_greeter_auth "$file"
[[ -L $file ]]
grep -qx 'auth        sufficient  pam_fprintd.so max-tries=1 timeout=5' "$repo/packaging/strata-greetd"
grep -qx 'auth        include     greetd' "$repo/packaging/strata-greetd"
printf 'PASS: login/greeter policy separation, preserved settings, backups, idempotence and custom-policy protection\n'
