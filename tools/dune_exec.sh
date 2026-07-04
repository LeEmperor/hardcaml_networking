#!/usr/bin/env bash
set -euo pipefail

cd "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ "$#" -lt 1 ]; then
  echo "usage: ./tools/dune_exec.sh <dune-executable> [args...]" >&2
  echo >&2
  echo "example:" >&2
  echo "  ./tools/dune_exec.sh test/mii/tx_path_tb.exe" >&2
  exit 1
fi

EXE="$1"
shift

exec ./scripts/with-switch.sh dune exec "$EXE" -- "$@"
