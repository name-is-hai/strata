#!/bin/bash
# Read only our bounded, no-follow metadata, never an image or theme file.
set -u
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
[[ ${2:-} =~ ^[0-9a-f]{16}$ && -n ${1:-} ]] || exit 1
read_bounded "$1/size-$2.json" 256
