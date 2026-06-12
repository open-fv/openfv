# OpenfvCIRCT.cmake — locate the pinned CIRCT/MLIR/LLVM install and wire ccache.
#
# Build model (see docs/BUILDING.md): CIRCT is built ONCE, at the SHA in
# versions.txt, into a shared install prefix by scripts/bootstrap-circt.sh.
# Each CIRCT-dependent repo (rtl-lowering, sva-frontend, btor2-emit) then does
# `find_package` against that prefix rather than rebuilding CIRCT. This keeps
# warm CI builds fast (P0.4 budget) and guarantees all repos use the same pin.
#
# Inputs (cache / -D):
#   OPENFV_DEPS_PREFIX  install prefix produced by bootstrap-circt.sh.
#                       Defaults to $ENV{OPENFV_DEPS_PREFIX}.
#   OPENFV_REQUIRE_PIN_MATCH  (default ON) hard-fail if the installed CIRCT's
#                       recorded SHA differs from versions.txt. Turn OFF only
#                       for local experimentation, never in CI.
#
# Effect: calls find_package(MLIR)/find_package(CIRCT), sets up include/link
# via the standard LLVM/MLIR/CIRCT exported targets, and enables ccache as the
# compiler launcher if ccache is on PATH.

include_guard(GLOBAL)

# ---- ccache wiring --------------------------------------------------------
# Applied to the *consuming* repo's own compilation. (CIRCT itself is built
# with ccache by bootstrap-circt.sh.) Harmless if ccache is absent.
find_program(OPENFV_CCACHE_PROGRAM ccache)
if(OPENFV_CCACHE_PROGRAM)
  foreach(_lang C CXX)
    if(NOT CMAKE_${_lang}_COMPILER_LAUNCHER)
      set(CMAKE_${_lang}_COMPILER_LAUNCHER "${OPENFV_CCACHE_PROGRAM}"
          CACHE STRING "openfv: ccache launcher for ${_lang}" FORCE)
    endif()
  endforeach()
  message(STATUS "openfv: ccache enabled (${OPENFV_CCACHE_PROGRAM})")
else()
  message(STATUS "openfv: ccache not found; building without it")
endif()

# ---- locate the pinned CIRCT install --------------------------------------
if(NOT OPENFV_DEPS_PREFIX AND DEFINED ENV{OPENFV_DEPS_PREFIX})
  set(OPENFV_DEPS_PREFIX "$ENV{OPENFV_DEPS_PREFIX}" CACHE PATH
      "Prefix containing the pinned CIRCT/MLIR/LLVM install")
endif()

if(OPENFV_DEPS_PREFIX)
  # Let find_package discover the *Config.cmake files under the prefix.
  list(PREPEND CMAKE_PREFIX_PATH "${OPENFV_DEPS_PREFIX}")
endif()

find_package(MLIR REQUIRED CONFIG)
find_package(CIRCT REQUIRED CONFIG)

list(APPEND CMAKE_MODULE_PATH "${MLIR_CMAKE_DIR}" "${LLVM_CMAKE_DIR}")
include(TableGen)
include(AddLLVM)
include(AddMLIR)
include(HandleLLVMOptions)

include_directories(SYSTEM
  ${LLVM_INCLUDE_DIRS} ${MLIR_INCLUDE_DIRS} ${CIRCT_INCLUDE_DIRS})
separate_arguments(LLVM_DEFINITIONS_LIST NATIVE_COMMAND "${LLVM_DEFINITIONS}")
add_definitions(${LLVM_DEFINITIONS_LIST})

# ---- verify the install matches the pin -----------------------------------
# bootstrap-circt.sh drops this stamp recording the CIRCT_SHA it built.
option(OPENFV_REQUIRE_PIN_MATCH "Fail if installed CIRCT != versions.txt pin" ON)
set(_stamp "${OPENFV_DEPS_PREFIX}/share/openfv/circt-pin.txt")
if(EXISTS "${_stamp}")
  file(STRINGS "${_stamp}" _installed_sha LIMIT_COUNT 1)
  string(STRIP "${_installed_sha}" _installed_sha)
  if(NOT _installed_sha STREQUAL "${OPENFV_CIRCT_SHA}")
    set(_msg "openfv: installed CIRCT (${_installed_sha}) != pin "
             "(${OPENFV_CIRCT_SHA}). Re-run scripts/bootstrap-circt.sh.")
    if(OPENFV_REQUIRE_PIN_MATCH)
      message(FATAL_ERROR ${_msg})
    else()
      message(WARNING ${_msg})
    endif()
  endif()
else()
  message(WARNING
    "openfv: no pin stamp at ${_stamp}; cannot verify CIRCT matches "
    "versions.txt. (Was CIRCT installed by bootstrap-circt.sh?)")
endif()
