#!/usr/bin/env bash
# Exercise approval/removal against fixture devices. No root or real udev writes.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d /tmp/strata-mouse-setup-test.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin" "$work/input" "$work/hidraw" "$work/rules"
# Redirect fixed production paths only in the disposable test copy. Production
# deliberately exposes no environment override for privileged destinations.
sed -e '/^if (( EUID == 0 )); then export PATH=/d' \
  -e 's/EUID/STRATA_TEST_EUID/g' \
  -e "s@/sys/class/input@$work/input@g" \
  -e "s@/sys/class/hidraw@$work/hidraw@g" \
  -e "s@/etc/udev/rules.d@$work/rules@g" \
  -e "s@/usr/share/strata/bin/strata-mouse-setup@$work/setup@g" \
  "$repo/bin/strata-mouse-setup" > "$work/setup"
chmod +x "$work/setup"
cat > "$work/bin/udevadm" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ $1 == info ]]; then
  for argument in "$@"; do
    if [[ $argument == --path=* ]]; then cat "${argument#--path=}/properties"; exit; fi
  done
  exit 1
fi
printf '%s\n' "$*" >> "$STRATA_TEST_DATA/udev-calls"
MOCK
cat > "$work/bin/pkexec" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$STRATA_TEST_DATA/approval-calls"
export STRATA_TEST_EUID=0
exec "$@"
MOCK
printf '#!/usr/bin/env bash\nexit 0\n' > "$work/bin/restorecon"
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH" STRATA_TEST_DATA="$work" STRATA_TEST_EUID=1000
mkdir -p "$work/input/event0/device" "$work/input/event1/device" "$work/input/event2/device"
printf 'Test "Mouse"\n' > "$work/input/event0/device/name"
printf 'Keyboard\n' > "$work/input/event1/device/name"
printf 'Keyboard mouse emulation\n' > "$work/input/event2/device/name"
printf 'ID_INPUT_MOUSE=1\nID_BUS=usb\nID_VENDOR_ID=1532\nID_MODEL_ID=00c0\n' > "$work/input/event0/properties"
printf 'ID_INPUT_KEYBOARD=1\nID_BUS=usb\nID_VENDOR_ID=373b\nID_MODEL_ID=1044\n' > "$work/input/event1/properties"
printf 'ID_INPUT_MOUSE=1\nID_BUS=usb\nID_VENDOR_ID=373b\nID_MODEL_ID=1044\n' > "$work/input/event2/properties"
for index in 0 1 2; do
  mkdir -p "$work/hidraw/hidraw$index"
  cp "$work/input/event0/properties" "$work/hidraw/hidraw$index/properties"
done
mkdir -p "$work/hidraw/hidraw3"
cp "$work/input/event2/properties" "$work/hidraw/hidraw3/properties"
"$work/setup" list | jq -e 'length == 2 and all(.[]; .connected and (.configured|not))' >/dev/null
[[ ! -e $work/approval-calls ]]
for invalid in invalid 1532:00c00 '1532:00c0/../../x'; do
  if "$work/setup" enable "$invalid" >"$work/error" 2>&1; then echo 'Invalid ID was accepted' >&2; exit 1; fi
  [[ ! -e $work/approval-calls ]]
done
if "$work/setup" enable dead:beef >"$work/error" 2>&1; then echo 'Absent mouse was accepted' >&2; exit 1; fi
if "$work/setup" remove dead:beef >"$work/error" 2>&1; then echo 'Absent approval was removed' >&2; exit 1; fi
[[ ! -e $work/approval-calls ]]
"$work/setup" enable 1532:00C0 >"$work/output"
rule=$work/rules/70-strata-mouse-1532-00c0.rules
[[ -f $rule && ! -e $work/rules/70-strata-mouse-373b-1044.rules ]]
grep -Fq 'ATTRS{idVendor}=="1532", ATTRS{idProduct}=="00c0", TAG+="uaccess"' "$rule"
[[ $(grep -c '^trigger ' "$work/udev-calls") == 3 ]]
if grep -q 'hidraw3' "$work/udev-calls"; then echo 'Unapproved keyboard was refreshed' >&2; exit 1; fi
"$work/setup" list | jq -e 'map(select(.id=="1532:00c0"))[0].configured == true' >/dev/null
# A disconnected approved device retains its name and can still be removed.
mv "$work/input/event0" "$work/unplugged"
"$work/setup" list | jq -e 'map(select(.id=="1532:00c0"))[0] | .configured and (.connected|not) and .name=="Test \"Mouse\""' >/dev/null
printf '# unrelated user rule\n' > "$work/rules/70-other.rules"
"$work/setup" remove 1532:00c0 >"$work/output"
[[ ! -e $rule && -f $work/rules/70-other.rules ]]
"$work/setup" list | jq -e 'all(.[]; .id!="1532:00c0")' >/dev/null
if "$work/setup" remove 1532:00c0 >"$work/error" 2>&1; then echo 'Repeated removal reported success' >&2; exit 1; fi
echo 'PASS: mouse discovery, explicit approval, exact HID scope, invalid IDs, unplugged removal and unrelated-rule preservation'
