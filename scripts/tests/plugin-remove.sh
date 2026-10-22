#!/usr/bin/env bash
# Exercise the actual uninstall command against isolated plugin/config state.
set -euo pipefail
repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
work=$(mktemp -d /tmp/strata-plugin-remove.XXXXXXXX)
trap 'rm -rf -- "$work"' EXIT
export HOME="$work/home" STRATA_PATH="$work/share" XDG_CACHE_HOME="$work/cache"
export FIXTURE="$work"
mkdir -p "$HOME/.config/strata/plugins/test.plugin" "$HOME/.local/state/strata" "$work/bin" "$STRATA_PATH/config/strata"
export PATH="$work/bin:$repo/bin:$PATH"
cat > "$work/bin/strata-shell" <<'MOCK'
#!/bin/bash
printf '%s\n' "$*" >> "$FIXTURE/ipc"
if [[ $* == *setPluginEnabled* && -e $FIXTURE/disable-fails ]]; then echo failed; exit 1; fi
printf 'ok\n'
MOCK
chmod +x "$work/bin/strata-shell"
config="$HOME/.config/strata/shell.json"
cat > "$config" <<'JSON'
{"version":1,"bar":{"id":"test.plugin","enabled":false,"centerAnchor":"test.plugin","layout":{"left":[{"id":"test.plugin","size":12},{"id":"other.plugin"}],"center":[{"id":"test.plugin"}],"right":[{"id":"strata.indicators"}]}},"plugins":[{"id":"test.plugin","setting":42},{"id":"other.plugin","setting":99}],"disabledPlugins":["test.plugin","other.plugin"],"disabledPluginEntries":{"test.plugin":{"entry":{"id":"test.plugin"}},"other.plugin":{"entry":{"id":"other.plugin"}}},"cloneSourceRestores":["test.plugin","other.plugin"]}
JSON
cp "$config" "$work/original.json"
printf '{"id":"test.plugin"}\n' > "$HOME/.config/strata/plugins/test.plugin/manifest.json"
printf 'plugin code' > "$HOME/.config/strata/plugins/test.plugin/code.qml"
printf '{"entries":{"setup.plugin-open-test%%2Eplugin":{"count":1},"setup.plugin.entry-test%%2Eplugin":{"count":2},"custom.plugins.entry-test%%2Eplugin":{"count":1},"setup.plugin-open-other%%2Eplugin":{"count":3},"setup.theme":{"count":4}}}\n' > "$HOME/.local/state/strata/menu-usage.json"
mkdir -p "$XDG_CACHE_HOME/strata/plugin-installer/review-own" "$XDG_CACHE_HOME/strata/plugin-installer/review-other"
printf '{"id":"test.plugin"}\n' > "$XDG_CACHE_HOME/strata/plugin-installer/review-own/review.json"
printf '{"id":"other.plugin"}\n' > "$XDG_CACHE_HOME/strata/plugin-installer/review-other/review.json"
# Failure to stop the service must leave its files and settings untouched.
touch "$work/disable-fails"
if strata-plugin remove test.plugin > "$work/result" 2>&1; then echo 'Unexpected successful removal'; exit 1; fi
cmp "$config" "$work/original.json"
test -f "$HOME/.config/strata/plugins/test.plugin/code.qml"
rm "$work/disable-fails"
strata-plugin remove test.plugin > "$work/result"
jq -e '.removed == true' "$work/result" >/dev/null
test ! -e "$HOME/.config/strata/plugins/test.plugin"
jq -e 'tostring | contains("test.plugin") | not' "$config" >/dev/null
jq -e '.bar.id == null and .bar.enabled == null and .bar.centerAnchor == null and .bar.layout.left == [{"id":"other.plugin"}] and .bar.layout.center == [] and .bar.layout.right == [{"id":"strata.indicators"}] and .plugins == [{"id":"other.plugin","setting":99}] and .disabledPlugins == ["other.plugin"] and .cloneSourceRestores == ["other.plugin"] and .disabledPluginEntries["other.plugin"] != null' "$config" >/dev/null
jq -e 'tostring | contains("test%2Eplugin") | not' "$HOME/.local/state/strata/menu-usage.json" >/dev/null
jq -e '.entries["setup.theme"].count == 4 and .entries["setup.plugin-open-other%2Eplugin"].count == 3' "$HOME/.local/state/strata/menu-usage.json" >/dev/null
test ! -d "$XDG_CACHE_HOME/strata/plugin-installer/review-own"
test -d "$XDG_CACHE_HOME/strata/plugin-installer/review-other"
# Old uninstalls can be repaired even when their plugin folder is already gone.
cp "$work/original.json" "$config"
strata-plugin remove test.plugin > "$work/result"
jq -e 'tostring | contains("test.plugin") | not' "$config" >/dev/null
cp "$config" "$work/clean.json"
if strata-plugin remove test.plugin > "$work/result" 2>&1; then echo 'Repeated removal should report not found'; exit 1; fi
rg -q 'Plugin not found: test.plugin' "$work/result"
cmp "$config" "$work/clean.json"
if strata-plugin remove typo.not-real > "$work/result" 2>&1; then echo 'Unknown ID should fail'; exit 1; fi
cmp "$config" "$work/clean.json"
# A review-only or history-only leftover is real removable data.
mkdir -p "$XDG_CACHE_HOME/strata/plugin-installer/review-orphan"
printf '{"id":"test.review"}\n' > "$XDG_CACHE_HOME/strata/plugin-installer/review-orphan/review.json"
strata-plugin remove test.review > "$work/result"
test ! -e "$XDG_CACHE_HOME/strata/plugin-installer/review-orphan"
jq '.entries["setup.plugin-open-test%2Ehistory"]={count:1}' "$HOME/.local/state/strata/menu-usage.json" > "$work/usage.json"
mv "$work/usage.json" "$HOME/.local/state/strata/menu-usage.json"
strata-plugin remove test.history > "$work/result"
jq -e '.entries | has("setup.plugin-open-test%2Ehistory") | not' "$HOME/.local/state/strata/menu-usage.json" >/dev/null
if strata-plugin remove strata.spacer > "$work/result" 2>&1; then exit 1; fi
if strata-plugin remove ../outside > "$work/result" 2>&1; then exit 1; fi
mkdir -p "$work/outside"
ln -s "$work/outside" "$HOME/.config/strata/plugins/test.link"
if strata-plugin remove test.link > "$work/result" 2>&1; then exit 1; fi
mkdir -p "$HOME/.config/strata/plugins/test.wrong"
printf '{"id":"other.plugin"}\n' > "$HOME/.config/strata/plugins/test.wrong/manifest.json"
if strata-plugin remove test.wrong > "$work/result" 2>&1; then exit 1; fi
printf 'PASS: uninstall purges plugin files, all settings/placements, history and review copies; preserves other plugins; repairs stale removals, rejects unknown IDs without changes and rejects invalid targets\n'
