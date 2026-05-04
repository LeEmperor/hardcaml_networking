#!/usr/bin/env bash
set -euo pipefail

SWITCH="${OPAM_SWITCH:-5.2.0+ox}"
REQUIRED_OCAML_PREFIX="${REQUIRED_OCAML_PREFIX:-5.2}"
BAZELISK_VERSION="${BAZELISK_VERSION:-v1.22.1}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS_BIN="$ROOT/.tools/bin"
BAZEL="$TOOLS_BIN/bazel"

die() {
  echo "error: $*" >&2
  exit 1
}

detect_platform() {
  local os arch

  case "$(uname -s)" in
    Linux) os="linux" ;;
    Darwin) os="darwin" ;;
    *) die "unsupported OS: $(uname -s)" ;;
  esac

  case "$(uname -m)" in
    x86_64|amd64) arch="amd64" ;;
    arm64|aarch64) arch="arm64" ;;
    *) die "unsupported architecture: $(uname -m)" ;;
  esac

  echo "${os}-${arch}"
}

install_bazelisk() {
  mkdir -p "$TOOLS_BIN"

  if [ -x "$BAZEL" ]; then
    echo "Using repo-local bazel: $BAZEL"
    return
  fi

  local platform url
  platform="$(detect_platform)"
  url="https://github.com/bazelbuild/bazelisk/releases/download/${BAZELISK_VERSION}/bazelisk-${platform}"

  echo "Installing repo-local bazel launcher..."
  echo "  $url"
  echo "  -> $BAZEL"

  if command -v curl >/dev/null 2>&1; then
    curl -L "$url" -o "$BAZEL"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$BAZEL" "$url"
  else
    die "need curl or wget to download Bazelisk"
  fi

  chmod +x "$BAZEL"
}

check_opam() {
  command -v opam >/dev/null 2>&1 || die "opam is not installed"

  if ! opam var root >/dev/null 2>&1; then
    echo "Initializing opam..."
    opam init --bare --disable-sandboxing -y
  fi
}

check_oxcaml_switch() {
  if ! opam switch list --short | grep -qx "$SWITCH"; then
    cat >&2 <<EOF
error: required opam switch '$SWITCH' was not found.

Create it once on this machine with:

  opam update --all
  opam switch create $SWITCH 5.2.0+ox \\
    --repos ox=git+https://github.com/oxcaml/opam-repository.git,default

Then rerun:

  ./bootstrap.sh
EOF
    exit 1
  fi

  local version compiler
  version="$(opam exec --switch="$SWITCH" -- ocamlc -version)"
  compiler="$(opam exec --switch="$SWITCH" -- which ocamlc)"

  case "$version" in
    "$REQUIRED_OCAML_PREFIX"*) ;;
    *)
      die "switch '$SWITCH' has OCaml version '$version', expected prefix '$REQUIRED_OCAML_PREFIX'"
      ;;
  esac

  echo "Using opam switch: $SWITCH"
  echo "OCaml version: $version"
  echo "Compiler: $compiler"
}

write_env_file() {
  cat > "$ROOT/env.sh" <<EOF
# Source this file from the repo root:
#   source ./env.sh

export OPAM_SWITCH="${SWITCH}"
export PATH="${TOOLS_BIN}:\$PATH"
EOF

  echo "Wrote env.sh"
}

install_deps() {
  echo "Installing repo dependencies into opam switch '$SWITCH'..."
  opam install . \
    --switch="$SWITCH" \
    --deps-only \
    --with-test \
    -y
}

main() {
  cd "$ROOT"

  install_bazelisk
  check_opam
  check_oxcaml_switch
  write_env_file
  install_deps

  echo
  echo "Bootstrap complete."
  echo
  echo "To enable repo-local bazel in this shell, run:"
  echo
  echo "  source ./env.sh"
  echo
  echo "Then:"
  echo
  echo "  bazel run //tools:build"
  echo "  bazel run //tools:test"
}

main "$@"
