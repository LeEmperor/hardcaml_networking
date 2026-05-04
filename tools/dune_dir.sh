#!/usr/bin/env bash
set -euo pipefail

cd "$BUILD_WORKSPACE_DIRECTORY"

if [ "$#" -lt 2 ]; then
  echo "usage: dune_dir.sh <build|test|fmt|exec> <target> [args...]" >&2
  exit 1
fi

CMD="$1"
TARGET="$2"
shift 2

case "$CMD" in
  build)
    exec ./scripts/with-switch.sh dune build "$TARGET" "$@"
    ;;

  test)
    exec ./scripts/with-switch.sh dune runtest "$TARGET" "$@"
    ;;

  fmt)
    exec ./scripts/with-switch.sh dune fmt "$TARGET" "$@"
    ;;

  exec)
    exec ./scripts/with-switch.sh dune exec "$TARGET" -- "$@"
    ;;

  *)
    echo "unknown command: $CMD" >&2
    echo "expected one of: build, test, fmt, exec" >&2
    exit 1
    ;;
esac
