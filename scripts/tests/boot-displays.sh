#!/usr/bin/env bash
# Isolated hardware and boot-image fixtures; no actual boot files or root use.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d /tmp/strata-boot-displays-test.XXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$work/bin" "$work/boot" "$work/etc/plymouth" "$work/etc/modprobe.d" "$work/run/lock" "$work/dracut" "$work/modules"
mkdir -p "$work/themes/custom-theme" "$work/plugins/renderers"
printf '[Plymouth Theme]\nModuleName=two-step\n' > "$work/themes/custom-theme/custom-theme.plymouth"
touch "$work/plugins/two-step.so" "$work/plugins/renderers/drm.so"
sed -e '/^if (( EUID == 0 )); then export PATH=/d' -e 's/EUID/STRATA_TEST_EUID/g' \
 -e "s@/sys/class/drm@$work/drm@g" -e "s@/sys/bus/pci/devices@$work/pci@g" \
 -e "s@/usr/lib/dracut/dracut.conf.d@$work/dracut@g" \
 -e "s@/usr/share/plymouth/themes@$work/themes@g" \
 -e "s@/etc/strata@$work/etc/strata@g" -e "s@/etc/plymouth@$work/etc/plymouth@g" \
 -e "s@/etc/modprobe.d@$work/etc/modprobe.d@g" -e "s@/run/@$work/run/@g" \
 -e "s@/var/lib/strata@$work/state@g" -e "s@/boot/@$work/boot/@g" \
 "$repo/bin/strata-boot-displays" > "$work/setup"
chmod +x "$work/setup"
cat > "$work/bin/modinfo" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
kernel=$2
module=${!#}
file="$STRATA_TEST_DATA/modules/$kernel/$module"
[[ -f $file ]] || exit 1
if [[ $* == *'-F filename'* ]]; then printf '%s\n' "$file"; fi
MOCK
cat > "$work/bin/uname" <<'MOCK'
#!/usr/bin/env bash
printf '1.0-test\n'
MOCK
cat > "$work/bin/modprobe" <<'MOCK'
#!/usr/bin/env bash
exit 1
MOCK
cat > "$work/bin/dracut" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf 'build\n' >> "$STRATA_TEST_DATA/builds"
[[ ! -f $STRATA_TEST_DATA/fail-build ]] || exit 1
while (( $# )); do
 if [[ $1 == --kver ]]; then kernel=$2; shift 2; else image=$1; shift; fi
done
drivers=$("$STRATA_TEST_DATA/setup" --drivers "$kernel")
for driver in $drivers; do printf '/modules/%s.ko.xz\n' "${driver//_/-}"; done > "$image"
if [[ ! -f $STRATA_TEST_DATA/omit-renderer ]]; then
 printf '/usr/lib64/plymouth/renderers/drm.so\n' >> "$image"
fi
printf '/usr/lib64/plymouth/two-step.so\n/usr/share/plymouth/themes/custom-theme/custom-theme.plymouth\n' >> "$image"
MOCK
printf '#!/usr/bin/env bash\nprintf "custom-theme\\n"\n' > "$work/bin/plymouth-set-default-theme"
printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$STRATA_TEST_DATA/plugins"\n' > "$work/bin/plymouth"
cat > "$work/bin/lsinitrd" <<'MOCK'
#!/usr/bin/env bash
cat "$1"
MOCK
printf '#!/usr/bin/env bash\nexit 0\n' > "$work/bin/restorecon"
printf '#!/usr/bin/env bash\nexit 0\n' > "$work/bin/chown"
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH" STRATA_TEST_DATA="$work" STRATA_TEST_EUID=0
cp "$repo/defaults/dracut/60-strata-early-graphics.conf" "$work/dracut/60-strata-early-graphics.conf"
sed -e "s@/etc/strata@$work/etc/strata@g" \
 -e "s@/usr/share/strata/bin/strata-boot-displays@$work/setup@g" \
 "$repo/defaults/dracut/60-strata-early-graphics.conf" > "$work/policy"
printf 'original-image\n' > "$work/boot/initramfs-1.0-test.img"
printf '[Daemon]\nTheme=custom-theme\nUseSimpledrm=1\n' > "$work/etc/plymouth/plymouthd.conf"
reset_devices() { rm -rf "$work/drm" "$work/pci"; mkdir -p "$work/drm" "$work/pci"; }
add_card() {
 local index=$1 driver=$2
 mkdir -p "$work/drm/card$index/device/driver" "$work/module-names/$driver" "$work/modules/1.0-test"
 ln -s "$work/module-names/$driver" "$work/drm/card$index/device/driver/module"
 printf 'module %s\n' "$driver" > "$work/modules/1.0-test/$driver"
}
reset_devices
"$work/setup" --apply > "$work/result"
[[ ! -f $work/etc/strata/early-graphics && ! -f $work/builds ]]
force_drivers="" kernel=1.0-test
source "$work/policy"
[[ -z $force_drivers ]]
for driver in amdgpu radeon i915 xe nouveau virtio_gpu vmwgfx qxl bochs ast mgag200; do
 reset_devices
 add_card 0 "$driver"
 [[ $("$work/setup" --drivers 1.0-test) == "$driver" ]]
done
# Two non-NVIDIA GPUs are kept just like an AMD/NVIDIA hybrid.
reset_devices
add_card 0 amdgpu
add_card 1 i915
[[ $("$work/setup" --drivers 1.0-test | tr '\n' ' ') == 'amdgpu i915 ' ]]
# Hybrid laptop: include both GPUs, and expand only a present NVIDIA driver.
reset_devices
add_card 0 amdgpu
add_card 1 nvidia
printf 'modeset\n' > "$work/modules/1.0-test/nvidia_modeset"
printf 'drm\n' > "$work/modules/1.0-test/nvidia_drm"
[[ $("$work/setup" --drivers 1.0-test | tr '\n' ' ') == 'amdgpu nvidia nvidia_drm nvidia_modeset ' ]]
# A new kernel without its optional module build must not force missing drivers.
[[ -z $("$work/setup" --drivers 2.0-new-kernel) ]]
# Fresh NVIDIA install can still have Nouveau bound until its first reboot.
reset_devices
add_card 0 nouveau
mkdir -p "$work/pci/gpu/driver"
printf '0x030000\n' > "$work/pci/gpu/class"
printf '0x10de\n' > "$work/pci/gpu/vendor"
ln -s "$work/module-names/nouveau" "$work/pci/gpu/driver/module"
printf 'blacklist nouveau\n' > "$work/etc/modprobe.d/strata-nvidia.conf"
[[ $("$work/setup" --drivers 1.0-test | tr '\n' ' ') == 'nvidia nvidia_drm nvidia_modeset ' ]]
rm "$work/etc/modprobe.d/strata-nvidia.conf"
reset_devices
add_card 0 amdgpu
# Minimal installations must fail before changing settings or the boot image.
rm "$work/plugins/renderers/drm.so"
if "$work/setup" --apply > "$work/result" 2>&1; then echo 'Missing graphical renderer accepted' >&2; exit 1; fi
[[ ! -f $work/etc/strata/early-graphics && ! -f $work/builds ]]
touch "$work/plugins/renderers/drm.so"
"$work/setup" --apply > "$work/result"
grep -q '^Theme=custom-theme$' "$work/etc/plymouth/plymouthd.conf"
grep -q '^UseSimpledrm=0$' "$work/etc/plymouth/plymouthd.conf"
[[ -f $work/etc/strata/early-graphics && $(wc -l < "$work/builds") == 1 ]]
force_drivers="" kernel=1.0-test
source "$work/policy"
[[ $force_drivers == ' amdgpu ' ]]
force_drivers="" kernel=2.0-new-kernel
source "$work/policy"
[[ -z ${force_drivers// /} ]]
"$work/setup" --sync 1.0-test > "$work/result"
[[ $(wc -l < "$work/builds") == 1 ]]
printf 'updated module\n' > "$work/modules/1.0-test/amdgpu"
"$work/setup" --sync 1.0-test > "$work/result"
[[ $(wc -l < "$work/builds") == 2 ]]
# Failed candidate creation preserves both the installed image and settings.
cp "$work/boot/initramfs-1.0-test.img" "$work/previous-image"
cp "$work/etc/plymouth/plymouthd.conf" "$work/previous-plymouth"
touch "$work/fail-build"
if "$work/setup" --apply > "$work/result" 2>&1; then echo 'Failed build was accepted' >&2; exit 1; fi
cmp "$work/previous-image" "$work/boot/initramfs-1.0-test.img"
cmp "$work/previous-plymouth" "$work/etc/plymouth/plymouthd.conf"
rm "$work/fail-build"
touch "$work/omit-renderer"
if "$work/setup" --apply > "$work/result" 2>&1; then echo 'Image without DRM renderer accepted' >&2; exit 1; fi
cmp "$work/previous-image" "$work/boot/initramfs-1.0-test.img"
cmp "$work/previous-plymouth" "$work/etc/plymouth/plymouthd.conf"
if "$work/setup" --drivers '../invalid' > "$work/result" 2>&1; then echo 'Invalid kernel accepted' >&2; exit 1; fi
echo 'PASS: AMD, Intel, Nouveau, NVIDIA hybrid, fresh-driver transitions, virtual/headless systems, missing modules, refresh and failed-build preservation'
