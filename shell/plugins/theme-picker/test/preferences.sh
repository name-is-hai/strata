#!/bin/bash
# Exercise actual persistence and failure behavior using isolated state.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
export XDG_STATE_HOME=$work/state
path=$XDG_STATE_HOME/strata/swatch/preferences.json
run() { "$here/preferences.sh" "$@"; }
refuse() { if run "$@" > "$work/result" 2> "$work/error"; then echo "Unexpected success: $*" >&2; exit 1; fi; }
run read | jq -e '.favorites == [] and .hidden == {}' >/dev/null
[[ ! -e $path ]]
run favorite tokyo-night true >/dev/null
run hidden tokyo-night true theme:wallpaper.webp >/dev/null
run read | jq -e '.favorites == ["tokyo-night"] and .hidden == {"tokyo-night":["theme:wallpaper.webp"]}' >/dev/null
run hidden tokyo-night false theme:wallpaper.webp >/dev/null
run favorite tokyo-night false | jq -e '.favorites == [] and .hidden == {}' >/dev/null
[[ $(stat -c %a "$path") == 600 ]]
cp "$path" "$work/before"
refuse favorite ../escape true
refuse favorite $'newline\n' true
refuse hidden good true theme:../escape
refuse hidden good true theme:
cmp "$path" "$work/before"
for raw in broken '{}' '{"version":1,"favorites":[],"hidden":{},"extra":0}' '{"version":1,"favorites":[42],"hidden":{}}'; do
 printf '%s' "$raw" > "$path"
 cp "$path" "$work/before"
 refuse favorite good true
 cmp "$path" "$work/before"
done
head -c 131073 /dev/zero > "$path"
cp "$path" "$work/before"
refuse read
cmp "$path" "$work/before"
rm "$path"
printf untouched > "$work/target"
ln -s "$work/target" "$path"
refuse favorite good true
[[ $(cat "$work/target") == untouched ]]
rm "$path"
mkfifo "$path"
refuse read
rm "$path"
run favorite one true > "$work/one" & first=$!
run favorite two true > "$work/two" & second=$!
run favorite three true > "$work/three" & third=$!
wait "$first"; wait "$second"; wait "$third"
run read | jq -e '(.favorites | sort) == ["one","three","two"]' >/dev/null
[[ -z $(find "${path%/*}" -name '.preferences-*' -print -quit) ]]
# The curation directory itself may not redirect state writes elsewhere.
mv "${path%/*}" "$work/saved"
ln -s "$work/saved" "${path%/*}"
refuse favorite four true
jq -e '(.favorites | sort) == ["one","three","two"]' "$work/saved/preferences.json" >/dev/null
echo 'PASS: preference persistence, validation, atomic writes, concurrency and unsafe-file refusal'
