#!/usr/bin/env bash
set -euo pipefail

cd "$BUILD_WORKSPACE_DIRECTORY"

if [ "$#" -lt 1 ]; then
  echo "usage: open_wave.sh <vcd-file>" >&2
  exit 1
fi

VCD="$1"

if [ ! -f "$VCD" ]; then
  echo "error: VCD file does not exist: $VCD" >&2
  echo "run the matching testbench first" >&2
  exit 1
fi

exec gtkwave "$VCD"
