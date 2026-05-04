#!/usr/bin/env bash
set -euo pipefail

OCAML_VERSION="${OCAML_VERSION:-5.2.1}"

if ! command -v opam >/dev/null 2>&1; then
  echo "error: opam is not installed"
  echo "install opam first, then rerun this script"
  exit 1
fi

if [ ! -d "_opam" ]; then
  opam switch create . "$OCAML_VERSION" --deps-only
fi

eval "$(opam env --switch=. --set-switch)"

opam install . --deps-only --with-test --with-dev-setup -y
dune build
