#!/usr/bin/env bash
#
# bootstrap-engines.sh — build the pinned BMC engines (btormc, Pono) into the
# shared install prefix, so fv-engine (P1.6) can invoke them as subprocesses.
# Reproducible: the two top-level pins come from the flagship versions.txt;
# each engine's own contrib scripts transitively pin its solver deps.
#
# Usage:
#   scripts/bootstrap-engines.sh [--prefix DIR] [--src DIR] [--jobs N]
#
# Defaults:
#   --prefix  $OPENFV_DEPS_PREFIX or ./.openfv-deps/install
#   --src     ./.openfv-deps/engines
#   --jobs    nproc
#
# System packages required (Ubuntu 22.04/24.04):
#   cmake ninja-build build-essential meson pkg-config \
#   libgmp-dev libmpfr-dev bison flex
# (meson/gmp/mpfr are for Bitwuzla; bison/flex for cvc5 — both pulled in by
#  Pono's smt-switch setup. A clean Pono build needs an EMPTY
#  .openfv-deps/engines/pono/deps tree: the upstream setup scripts refuse to
#  reconfigure over a partial tree.)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSIONS_FILE="${OPENFV_VERSIONS_FILE:-$REPO_ROOT/versions.txt}"

DEPS_ROOT="$REPO_ROOT/.openfv-deps"
PREFIX="${OPENFV_DEPS_PREFIX:-$DEPS_ROOT/install}"
SRC="$DEPS_ROOT/engines"
JOBS="$(nproc 2>/dev/null || echo 4)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;;
    --src)    SRC="$2";    shift 2 ;;
    --jobs)   JOBS="$2";   shift 2 ;;
    -h|--help) sed -n '2,22p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 10 ;;
  esac
done

get_pin() {
  local v
  v="$(grep -E "^$1=" "$VERSIONS_FILE" | head -1 | cut -d= -f2- | tr -d '[:space:]')"
  [[ -n "$v" ]] || { echo "missing $1 in $VERSIONS_FILE" >&2; exit 10; }
  echo "$v"
}
BOOLECTOR_TAG="$(get_pin BOOLECTOR_TAG)"
PONO_SHA="$(get_pin PONO_SHA)"
echo "==> pins: boolector=$BOOLECTOR_TAG pono=$PONO_SHA"

for t in cmake make meson pkg-config; do
  command -v "$t" >/dev/null || { echo "missing build tool: $t (see header for apt list)" >&2; exit 10; }
done

mkdir -p "$SRC" "$PREFIX/bin"

# --- btormc (Boolector) ----------------------------------------------------
# contrib/setup-cadical.sh + setup-btor2tools.sh transitively pin the SAT
# solver + BTOR2 lib that match this Boolector tag.
if [[ ! -x "$PREFIX/bin/btormc" ]]; then
  echo "==> building btormc (Boolector $BOOLECTOR_TAG)"
  [[ -d "$SRC/boolector" ]] || git clone --depth 1 --branch "$BOOLECTOR_TAG" \
      https://github.com/Boolector/boolector.git "$SRC/boolector"
  cd "$SRC/boolector"
  ./contrib/setup-cadical.sh
  ./contrib/setup-btor2tools.sh
  ./configure.sh
  ( cd build && make -j"$JOBS" )
  cp build/bin/btormc build/bin/boolector "$PREFIX/bin/"
else
  echo "==> btormc already installed, skipping"
fi

# --- Pono ------------------------------------------------------------------
# Default smt-switch backend is Bitwuzla (MIT). Do NOT pass --with-msat /
# --with-yices2 (non-BSD licenses, excluded per plan §1.3).
if [[ ! -x "$PREFIX/bin/pono" ]]; then
  echo "==> building Pono ($PONO_SHA)"
  if [[ ! -d "$SRC/pono" ]]; then
    git clone https://github.com/stanford-centaur/pono.git "$SRC/pono"
    git -C "$SRC/pono" checkout --detach "$PONO_SHA"
  fi
  cd "$SRC/pono"
  ./contrib/setup-smt-switch.sh        # default backends: Bitwuzla (MIT) + cvc5 (BSD-3)
  ./contrib/setup-btor2tools.sh
  ./configure.sh
  ( cd build && make -j"$JOBS" )
  cp build/pono "$PREFIX/bin/"
else
  echo "==> pono already installed, skipping"
fi

# --- stamp -----------------------------------------------------------------
mkdir -p "$PREFIX/share/openfv"
printf 'boolector=%s\npono=%s\n' "$BOOLECTOR_TAG" "$PONO_SHA" \
  > "$PREFIX/share/openfv/engines-pin.txt"

echo "==> done. engines installed at $PREFIX/bin:"
echo "    btormc: $("$PREFIX/bin/btormc" --version 2>&1 | head -1)"
echo "    pono:   $("$PREFIX/bin/pono" --version 2>&1 | head -1 || echo built)"
