#!/usr/bin/env bash
set -euo pipefail

cd "$BUILD_WORKSPACE_DIRECTORY"

exec ./scripts/with-switch.sh dune runtest
