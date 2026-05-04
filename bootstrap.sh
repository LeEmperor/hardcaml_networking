#!/usr/bin/env bash
set -euo pipefail

SWITCH="${OPAM_SWITCH:-oxcaml-5.2-hardcaml}"
REQUIRED_OCAML_PREFIX="${REQUIRED_OCAML_PREFIX:-5.2}"
BAZELISK_VERSION="${BAZELISK_VERSION:-v1.22.1}"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BAZEL_DIR="$ROOT/third_party/bazel"
BAZEL="$BAZEL_DIR/bazel"

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

download_bazelisk() {
  mkdir -p "$BAZEL_DIR"

  if [ -x "$BAZEL" ]; then
    echo "Using repo-local Bazel launcher: $BAZEL"
    return
  fi

  local platform url
  platform="$(detect_platform)"
  url="https://github.com/bazelbuild/bazelisk/releases/download/${BAZELISK_VERSION}/bazelisk-${platform}"

  echo "Installing repo-local Bazelisk:"
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

Create the shared OxCaml switch once on this machine, for example:

  opam update --all
  opam switch create $SWITCH 5.2.0+ox \\
    --repos ox=git+https://github.com/oxcaml/opam-repository.git,default

Then rerun:

  ./bootstrap.sh

Or use a different existing switch:

  OPAM_SWITCH=<switch-name> ./bootstrap.sh
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
  echo "OCaml compiler: $compiler"
}

install_ocaml_deps() {
  echo "Installing repo OCaml dependencies into switch '$SWITCH'..."
  opam install . \
    --switch="$SWITCH" \
    --deps-only \
    --with-test \
    --with-dev-setup \
    -y
}

main() {
  cd "$ROOT"

  download_bazelisk
  check_opam
  check_oxcaml_switch
  install_ocaml_deps

  echo "Bazel version:"
  "$BAZEL" version

  echo "Running Bazel-mediated build..."
  OPAM_SWITCH="$SWITCH" "$BAZEL" run //tools:build
}

main "$@"
