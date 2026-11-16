#!/usr/bin/env bash
# Clone, configure, and build a pinned Emacs for the bytecode tracer.
# Usage: scripts/setup-emacs.sh [tag]   (default: emacs-30.1)
set -euo pipefail

TAG="${1:-emacs-30.1}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIR="$ROOT/emacs"

if [ ! -d "$DIR" ]; then
  echo ">> cloning Emacs @ $TAG"
  git clone --depth 1 --branch "$TAG" \
    https://git.savannah.gnu.org/git/emacs.git "$DIR"
else
  echo ">> $DIR already exists, skipping clone"
fi

cd "$DIR"

if [ ! -f configure ]; then
  echo ">> running autogen"
  ./autogen.sh
fi

if [ ! -f Makefile ]; then
  echo ">> configuring (no native-comp: everything must go through exec_byte_code)"
  ./configure \
    --without-native-compilation \
    --without-ns --without-x \
    --with-gnutls=ifavailable
fi

echo ">> building (this is the slow part)"
make -j"$(sysctl -n hw.ncpu)"

echo ">> done: $DIR/src/emacs"
"$DIR/src/emacs" --version | head -1
