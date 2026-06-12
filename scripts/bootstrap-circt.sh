#!/usr/bin/env bash
#
# bootstrap-circt.sh — build the pinned CIRCT/MLIR/LLVM ONCE into a shared
# install prefix, with ccache, so every openfv repo can find_package against it.
# This is the "fetch/build against exactly those pins + ccache wiring" half of
# task P0.3. Reproducible: all SHAs come from the flagship versions.txt.
#
# Usage:
#   scripts/bootstrap-circt.sh [--prefix DIR] [--src DIR] [--build DIR] [--jobs N]
#
# Defaults:
#   --prefix  $OPENFV_DEPS_PREFIX or ./.openfv-deps/install
#   --src     ./.openfv-deps/circt
#   --build   ./.openfv-deps/build
#   --jobs    nproc
#
# Idempotent: re-running with the same pin is a no-op rebuild (ccache-fast).
# Changing versions.txt and re-running rebuilds against the new pin.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSIONS_FILE="${OPENFV_VERSIONS_FILE:-$REPO_ROOT/versions.txt}"

DEPS_ROOT="$REPO_ROOT/.openfv-deps"
PREFIX="${OPENFV_DEPS_PREFIX:-$DEPS_ROOT/install}"
SRC="$DEPS_ROOT/circt"
BUILD="$DEPS_ROOT/build"
JOBS="$(nproc 2>/dev/null || echo 4)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --prefix) PREFIX="$2"; shift 2 ;;
    --src)    SRC="$2";    shift 2 ;;
    --build)  BUILD="$2";  shift 2 ;;
    --jobs)   JOBS="$2";   shift 2 ;;
    -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
    *) echo "unknown arg: $1" >&2; exit 10 ;;
  esac
done

# ---- read pins ------------------------------------------------------------
get_pin() {  # get_pin KEY
  local v
  v="$(grep -E "^$1=" "$VERSIONS_FILE" | head -1 | cut -d= -f2- | tr -d '[:space:]')"
  if [[ -z "$v" ]]; then echo "missing $1 in $VERSIONS_FILE" >&2; exit 10; fi
  echo "$v"
}
CIRCT_SHA="$(get_pin CIRCT_SHA)"
LLVM_SHA="$(get_pin LLVM_SHA)"
SLANG_TAG="$(get_pin SLANG_TAG)"
echo "==> pins: CIRCT=$CIRCT_SHA LLVM=$LLVM_SHA slang=$SLANG_TAG"

command -v cmake  >/dev/null || { echo "cmake not found"  >&2; exit 10; }
command -v ninja  >/dev/null || { echo "ninja not found"  >&2; exit 10; }
command -v git    >/dev/null || { echo "git not found"    >&2; exit 10; }
if ! command -v ccache >/dev/null; then
  echo "WARNING: ccache not found; the CIRCT build will be slow." >&2
fi

# ---- fetch CIRCT @ pin (with its llvm submodule @ LLVM_SHA) ---------------
if [[ ! -d "$SRC/.git" ]]; then
  git clone https://github.com/llvm/circt.git "$SRC"
fi
git -C "$SRC" fetch --tags origin
git -C "$SRC" checkout --detach "$CIRCT_SHA"
git -C "$SRC" submodule update --init --recursive llvm

# Sanity: the llvm submodule must match the independently-recorded LLVM pin.
ACTUAL_LLVM="$(git -C "$SRC/llvm" rev-parse HEAD)"
if [[ "$ACTUAL_LLVM" != "$LLVM_SHA" ]]; then
  echo "ERROR: CIRCT@$CIRCT_SHA pins LLVM $ACTUAL_LLVM but versions.txt says" \
       "$LLVM_SHA. Fix versions.txt (LLVM_SHA is derived, not chosen)." >&2
  exit 10
fi

# ---- configure + build + install ------------------------------------------
CCACHE_ARGS=()
if command -v ccache >/dev/null; then
  CCACHE_ARGS=(-DLLVM_CCACHE_BUILD=ON)
fi

# LLVM link steps are multi-GB each; uncapped parallel links OOM hosts with
# modest RAM (e.g. 16GB WSL VMs) long before compile parallelism is the limit.
# lld also uses far less memory than GNU ld. Override via OPENFV_LINK_JOBS.
LINKER_ARGS=(-DLLVM_PARALLEL_LINK_JOBS="${OPENFV_LINK_JOBS:-2}")
if command -v ld.lld >/dev/null; then
  LINKER_ARGS+=(-DLLVM_USE_LINKER=lld)
fi

# We build LLVM+MLIR (CIRCT's in-tree llvm) and CIRCT together. slang frontend
# ON so circt-verilog (P0.7) and the slang lib are available; CIRCT fetches
# slang $SLANG_TAG itself.
cmake -G Ninja -S "$SRC/llvm/llvm" -B "$BUILD" \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS=mlir \
  -DLLVM_EXTERNAL_PROJECTS=circt \
  -DLLVM_EXTERNAL_CIRCT_SOURCE_DIR="$SRC" \
  -DLLVM_TARGETS_TO_BUILD=host \
  -DLLVM_ENABLE_ASSERTIONS=ON \
  -DLLVM_INSTALL_UTILS=ON \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCIRCT_SLANG_FRONTEND_ENABLED=ON \
  -DCIRCT_SLANG_BUILD_FROM_SOURCE=ON \
  "${CCACHE_ARGS[@]}" \
  "${LINKER_ARGS[@]}"

cmake --build "$BUILD" -j "$JOBS"
cmake --build "$BUILD" --target install -j "$JOBS"

# ---- record the pin so consumers can verify (OpenfvCIRCT.cmake) -----------
mkdir -p "$PREFIX/share/openfv"
printf '%s\n' "$CIRCT_SHA" > "$PREFIX/share/openfv/circt-pin.txt"

echo "==> done. CIRCT installed at: $PREFIX"
echo "    export OPENFV_DEPS_PREFIX=$PREFIX   # then configure each repo"
