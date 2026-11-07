#!/usr/bin/env bash
# Test key preparation and firmware enrollment decisions without root access.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
fixture=$(mktemp -d)
trap 'rm -rf -- "$fixture"' EXIT
mkdir -p "$fixture/akmods/"{certs,private} "$fixture/efi"
mkdir -p "$fixture/pci/device"
functions=$(awk '/^has_nvidia_hardware\(\)/,/^}/' "$repo/bin/strata-install-desktop")
functions=${functions//\/sys\/bus\/pci\/devices/$fixture/pci}
eval "$functions"
printf '0x030000\n' > "$fixture/pci/device/class"
for vendor in 0x1002 0x8086; do
  printf '%s\n' "$vendor" > "$fixture/pci/device/vendor"
  if has_nvidia_hardware; then echo 'FAIL: detected AMD/Intel as NVIDIA'; exit 1; fi
done
printf '0x10de\n' > "$fixture/pci/device/vendor"
has_nvidia_hardware
printf '0x040300\n' > "$fixture/pci/device/class"
if has_nvidia_hardware; then echo 'FAIL: detected NVIDIA audio device as a GPU'; exit 1; fi
functions=$(awk '/^prepare_nvidia_signing_key\(\)/,/^}/; /^enroll_nvidia_signing_key\(\)/,/^}/' "$repo/bin/strata-install-desktop")
functions=${functions//\/etc\/pki\/akmods/$fixture/akmods}
functions=${functions//\/sys\/firmware\/efi/$fixture/efi}
eval "$functions"
dnf() { echo dnf >> "$fixture/events"; }
kmodgenca() {
  echo generate >> "$fixture/events"
  printf cert > "$fixture/akmods/certs/public_key.der"
  printf key > "$fixture/akmods/private/private_key.priv"
}
openssl() { echo 'sha1 Fingerprint=AA:BB:CC'; }
mokutil() {
  case $1 in
    --sb-state) echo "SecureBoot $boot_state" ;;
    --test-key) echo 'key is not enrolled'; return 0 ;;
    --list-enrolled) [[ $fixture_enrolled == yes ]] && echo 'SHA1 Fingerprint: aa:bb:cc'; return 0 ;;
    --list-new) [[ $fixture_pending == yes ]] && echo 'SHA1 Fingerprint: aa:bb:cc'; return 0 ;;
    --import) echo import >> "$fixture/events" ;;
    *) return 1 ;;
  esac
}
prepare_nvidia_signing_key
prepare_nvidia_signing_key
[[ $(grep -c '^generate$' "$fixture/events") == 1 ]]
rm "$fixture/akmods/private/private_key.priv"
if (prepare_nvidia_signing_key) >/dev/null 2>&1; then echo 'FAIL: replaced incomplete key pair'; exit 1; fi
printf key > "$fixture/akmods/private/private_key.priv"
boot_state=disabled fixture_enrolled=no fixture_pending=no
enroll_nvidia_signing_key > "$fixture/output"
grep -q 'Secure Boot is disabled' "$fixture/output"
boot_state=enabled fixture_enrolled=yes
enroll_nvidia_signing_key > "$fixture/output"
grep -q 'already enrolled' "$fixture/output"
fixture_enrolled=no fixture_pending=yes
enroll_nvidia_signing_key > "$fixture/output"
grep -q 'enrollment is pending' "$fixture/output"
fixture_pending=no
if enroll_nvidia_signing_key </dev/null > "$fixture/output" 2>&1; then
  echo 'FAIL: noninteractive setup claimed enrollment was ready'; exit 1
fi
grep -q 'sudo mokutil --import' "$fixture/output"
! grep -q '^import$' "$fixture/events"
rmdir "$fixture/efi"
enroll_nvidia_signing_key > "$fixture/output"
grep -q 'Legacy BIOS' "$fixture/output"

# Exercise the driver setup sequence with unsigned and already signed modules.
functions=$(awk '/^install_nvidia_driver\(\)/,/^}/' "$repo/bin/strata-install-desktop")
functions=${functions//\/etc\/modprobe.d/$fixture/modprobe.d}
eval "$functions"
prepare_nvidia_signing_key() { echo prepare >> "$fixture/events"; }
enroll_nvidia_signing_key() { echo enroll >> "$fixture/events"; }
rpm() { return 0; }
dracut() { echo dracut >> "$fixture/events"; }
modinfo() { [[ $module_signed == yes ]] && echo 'Test signing key'; }
akmods() {
  echo "akmods $*" >> "$fixture/events"
  if [[ $* == *--rebuild* && $repair_signs == yes ]]; then module_signed=yes; fi
  return 0
}
module_signed=no repair_signs=yes
: > "$fixture/events"
install_nvidia_driver > "$fixture/output"
grep -q '^akmods .*--rebuild' "$fixture/events"
grep -q '^enroll$' "$fixture/events"
module_signed=yes
: > "$fixture/events"
install_nvidia_driver > "$fixture/output"
! grep -q '^akmods .*--rebuild' "$fixture/events"
module_signed=no repair_signs=no
if (install_nvidia_driver) > "$fixture/output" 2>&1; then
  echo 'FAIL: unsigned modules reported as ready'; exit 1
fi
grep -q 'module signing failed' "$fixture/output"
echo 'PASS: key preservation, Secure Boot states and enrollment guidance; unsigned module repair, signed module reuse and signing failure'
