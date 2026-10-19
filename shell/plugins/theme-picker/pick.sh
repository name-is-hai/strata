#!/bin/bash
# Print a chosen theme name, or wallpaper path with --background; exit 1 on cancel.
# Drop-in for `theme=$(strata-theme-switcher)` — nothing is applied.
dir=$(mktemp -d) || exit 1
trap 'rm -rf -- "$dir"' EXIT
mode=themes
case ${1:-} in
  --background) mode=backgrounds ;;
  '') ;;
  *) echo 'Usage: pick.sh [--background]' >&2; exit 2 ;;
esac
reply=$(strata-shell shell summon strata.theme-picker "$(jq -cn --arg d "$dir" --arg mode "$mode" '{dir: $d, mode: $mode}')") || exit 1
[[ $reply == ok ]] || exit 1
while [[ ! -e $dir/done ]]; do sleep 0.02; done
[[ -s $dir/selection ]] && head -c 1024 -- "$dir/selection" || exit 1
