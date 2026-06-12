cmake_minimum_required(VERSION 3.20)
project(sva-frontend LANGUAGES C CXX)

# --- locate the openfv flagship (single source of pins + shared cmake) ------
# When this repo is an openfv submodule, the flagship is the parent dir.
set(OPENFV_FLAGSHIP_DIR "${CMAKE_CURRENT_SOURCE_DIR}/.." CACHE PATH
    "Path to the openfv flagship checkout (versions.txt + cmake/)")
set(OPENFV_VERSIONS_FILE "${OPENFV_FLAGSHIP_DIR}/versions.txt" CACHE FILEPATH
    "Path to the flagship versions.txt")
set(OPENFV_CMAKE_DIR "${OPENFV_FLAGSHIP_DIR}/cmake")
list(APPEND CMAKE_MODULE_PATH "${OPENFV_CMAKE_DIR}")

include(OpenfvVersions)
openfv_read_versions("${OPENFV_VERSIONS_FILE}")

# Finds the pinned CIRCT/MLIR/LLVM install, verifies the pin, wires ccache.
include(OpenfvCIRCT)

add_subdirectory(tools/sva-frontend-opt)

enable_testing()
# sva-frontend's MLIR FileCheck/lit tests (P1.1+) are added here as passes land.
