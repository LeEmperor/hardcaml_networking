#!/usr/bin/env bash
set -euo pipefail

cd "$BUILD_WORKSPACE_DIRECTORY"

if [ "$#" -lt 1 ]; then
  echo "usage: bazel run //tools:exec -- <dune-executable> [args...]" >&2
  echo >&2
  echo "example:" >&2
  echo "  bazel run //tools:exec -- ./bin/main.exe" >&2
  exit 1
fi

EXE="$1"
shift

exec ./scripts/with-switch.sh dune exec "$EXE" -- "$@"
