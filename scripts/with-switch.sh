#!/usr/bin/env bash
set -euo pipefail

SWITCH="${OPAM_SWITCH:-5.2.0+ox}"

if ! opam switch list --short | grep -qx "$SWITCH"; then
  echo "error: opam switch '$SWITCH' not found" >&2
  exit 1
fi

exec opam exec --switch="$SWITCH" -- "$@"
