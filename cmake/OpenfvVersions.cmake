# OpenfvVersions.cmake — parse the flagship versions.txt into CMake variables.
#
# Usage from a repo's CMakeLists.txt:
#     list(APPEND CMAKE_MODULE_PATH "${OPENFV_CMAKE_DIR}")
#     include(OpenfvVersions)
#     openfv_read_versions("${OPENFV_VERSIONS_FILE}")
#   -> defines cache vars: OPENFV_CIRCT_SHA, OPENFV_LLVM_SHA,
#                          OPENFV_SLANG_TAG, OPENFV_SLANG_SHA
#
# This is the *only* place that parses versions.txt. Every consumer reads the
# resulting variables so the pin stays single-sourced (P0.3).

# Map versions.txt KEY -> CMake cache variable name. The separator is '|', not
# ';', because ';' is CMake's list separator and would flatten these pairs.
set(_openfv_version_keys
  "CIRCT_SHA|OPENFV_CIRCT_SHA"
  "LLVM_SHA|OPENFV_LLVM_SHA"
  "SLANG_TAG|OPENFV_SLANG_TAG"
  "SLANG_SHA|OPENFV_SLANG_SHA"
)

function(openfv_read_versions versions_file)
  if(NOT EXISTS "${versions_file}")
    message(FATAL_ERROR
      "openfv: versions.txt not found at '${versions_file}'. "
      "Point OPENFV_VERSIONS_FILE at the flagship's versions.txt.")
  endif()

  # ENCODING UTF-8: without it, file(STRINGS) treats multibyte characters
  # (e.g. an em-dash in a comment) as binary and splits lines at them.
  file(STRINGS "${versions_file}" _lines ENCODING UTF-8)
  foreach(_line IN LISTS _lines)
    # Skip blanks and comments.
    string(STRIP "${_line}" _line)
    if(_line STREQUAL "" OR _line MATCHES "^#")
      continue()
    endif()
    if(NOT _line MATCHES "^([A-Za-z0-9_]+)=(.*)$")
      message(FATAL_ERROR "openfv: malformed line in versions.txt: '${_line}'")
    endif()
    set(_key "${CMAKE_MATCH_1}")
    set(_val "${CMAKE_MATCH_2}")
    string(STRIP "${_val}" _val)
    foreach(_pair IN LISTS _openfv_version_keys)
      string(REPLACE "|" ";" _pair_list "${_pair}")
      list(GET _pair_list 0 _txt_key)
      list(GET _pair_list 1 _cmake_var)
      if(_key STREQUAL _txt_key)
        set(${_cmake_var} "${_val}" CACHE STRING "openfv pin: ${_key}" FORCE)
      endif()
    endforeach()
  endforeach()

  foreach(_pair IN LISTS _openfv_version_keys)
    string(REPLACE "|" ";" _pair_list "${_pair}")
    list(GET _pair_list 1 _cmake_var)
    if(NOT DEFINED ${_cmake_var} OR "${${_cmake_var}}" STREQUAL "")
      list(GET _pair_list 0 _txt_key)
      message(FATAL_ERROR
        "openfv: required key '${_txt_key}' missing from ${versions_file}")
    endif()
  endforeach()

  message(STATUS "openfv pins: CIRCT=${OPENFV_CIRCT_SHA} "
                 "LLVM=${OPENFV_LLVM_SHA} slang=${OPENFV_SLANG_TAG}")
endfunction()
