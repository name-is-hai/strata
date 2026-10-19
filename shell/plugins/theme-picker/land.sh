#!/bin/bash
# Strata has no compositor theme-intro protocol; report the selected wallpaper's landing.
set -u
state=${XDG_STATE_HOME:-$HOME/.local/state}/strata/current
current=$(readlink -f -- "$state/background" 2>/dev/null || true)
printf '%s\n' "$current"
readlink -f -- "${1:-}" 2>/dev/null || echo
echo ready
status=$(timeout 1s strata-shell background ready "$current" 2>/dev/null || true)
if [[ $status == ready ]]; then echo ready; else echo waiting; fi
