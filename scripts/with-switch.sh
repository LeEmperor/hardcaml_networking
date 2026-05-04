#!/usr/bin/env bash
set -euo pipefail

SWITCH="${OPAM_SWITCH:-5.2.0+ox}"

if ! command -v opam >/dev/null 2>&1; then
  echo "error: opam is not installed" >&2
  exit 1
fi

if ! opam switch list --short | grep -qx "$SWITCH"; then
  echo "error: opam switch '$SWITCH' not found" >&2
  echo "run ./bootstrap.sh or create the switch manually" >&2
  exit 1
fi

exec opam exec --switch="$SWITCH" -- "$@"
