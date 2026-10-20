#!/usr/bin/env bash
# Exercise the real installer function without changing host repositories.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d /tmp/strata-quickshell-repository.XXXXXXXX)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/bin" "$work/repos" "$work/tmp"
cat > "$work/official.repo" <<'REPO'
[copr:copr.fedorainfracloud.org:errornointernet:quickshell]
baseurl=https://download.copr.fedorainfracloud.org/results/errornointernet/quickshell/fedora-$releasever-$basearch/
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/errornointernet/quickshell/pubkey.gpg
enabled=1
REPO
cat > "$work/bin/rpm" <<'MOCK'
#!/usr/bin/env bash
printf '44\n'
MOCK
cat > "$work/bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$FIXTURE/request"
while (( $# )); do
  if [[ $1 == --output ]]; then destination=$2; break; fi
  shift
done
if [[ ${MODE:-success} == failure ]]; then printf 'partial' > "$destination"; exit 22; fi
cp "$FIXTURE/official.repo" "$destination"
MOCK
cat > "$work/bin/install" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ $1 == -d ]]; then exit 0; fi
[[ ${@: -1} == /etc/yum.repos.d/_copr:copr.fedorainfracloud.org:errornointernet:quickshell.repo ]]
/usr/bin/install -m 0644 "${@: -2:1}" "$FIXTURE/repos/quickshell.repo"
MOCK
chmod +x "$work/bin/"*
export PATH="$work/bin:$PATH" FIXTURE="$work" TMPDIR="$work/tmp"
# Only load the named function; the full installer must never run in tests.
eval "$(awk '/^install_quickshell_repository\(\)/,/^}/' "$repo/bin/strata-install-desktop")"
install_quickshell_repository
cmp "$work/official.repo" "$work/repos/quickshell.repo"
grep -Fxq 'https://copr.fedorainfracloud.org/coprs/errornointernet/quickshell/repo/fedora-44/errornointernet-quickshell-fedora-44.repo' "$work/request"
[[ $(stat -c '%a' "$work/repos/quickshell.repo") == 644 ]]
if MODE=failure install_quickshell_repository 2>/dev/null; then echo 'Download failure was ignored' >&2; exit 1; fi
cmp "$work/official.repo" "$work/repos/quickshell.repo"
[[ -z $(find "$work/tmp" -type f -print -quit) ]]
printf 'PASS: official COPR config, retained GPG settings, safe replacement, failed download and temporary cleanup\n'
