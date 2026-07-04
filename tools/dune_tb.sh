#!/usr/bin/env bash
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "$#" -lt 1 ]; then
  echo "usage: dune_tb.sh <dune-executable> [args...]" >&2
  exit 1
fi

EXE="$1"
shift

mkdir -p waves

exec ./scripts/with-switch.sh dune exec "$EXE" -- "$@"

