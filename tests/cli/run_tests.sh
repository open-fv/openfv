#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Self-contained test script for the openfv CLI skeleton (P0.7).
#
# Usage:
#   tests/cli/run_tests.sh [openfv-binary]
#
# The optional argument overrides the default (bin/openfv relative to the
# repo root, detected from this script's location).
#
# Dependencies: bash, python3 (stdlib only), circt-verilog reachable via
#   OPENFV_DEPS_PREFIX (default: /home/achat/git/openfv/.openfv-deps/install)
#
# Exit: 0 = all pass, 1 = at least one failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

OPENFV="${1:-${REPO_ROOT}/bin/openfv}"
FIXTURES="${SCRIPT_DIR}/fixtures"

PASS=0
FAIL=0

# -----------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------

run_case() {
    local name="$1"
    local want_exit="$2"
    shift 2
    local actual_exit=0

    # Capture stderr to check for tracebacks.
    local stderr_tmp
    stderr_tmp="$(mktemp)"

    # We do NOT use set -e inside this subshell — we need to capture the code.
    python3 "${OPENFV}" "$@" 2>"${stderr_tmp}" || actual_exit=$?

    if [[ "${actual_exit}" -ne "${want_exit}" ]]; then
        echo "FAIL [${name}]: expected exit ${want_exit}, got ${actual_exit}"
        echo "  stderr: $(cat "${stderr_tmp}")"
        FAIL=$((FAIL + 1))
    else
        echo "PASS [${name}]: exit ${actual_exit} (expected ${want_exit})"
        PASS=$((PASS + 1))
    fi
    rm -f "${stderr_tmp}"
}

run_case_no_traceback() {
    local name="$1"
    local want_exit="$2"
    shift 2
    local actual_exit=0

    local stderr_tmp
    stderr_tmp="$(mktemp)"

    python3 "${OPENFV}" "$@" 2>"${stderr_tmp}" || actual_exit=$?

    local stderr_content
    stderr_content="$(cat "${stderr_tmp}")"

    local fail=0

    if [[ "${actual_exit}" -ne "${want_exit}" ]]; then
        echo "FAIL [${name}]: expected exit ${want_exit}, got ${actual_exit}"
        fail=1
    fi

    # A Python traceback contains "Traceback (most recent call last):"
    if echo "${stderr_content}" | grep -q "Traceback (most recent call last)"; then
        echo "FAIL [${name}]: Python traceback found in stderr"
        echo "  traceback: ${stderr_content}"
        fail=1
    fi

    if [[ "${fail}" -eq 0 ]]; then
        echo "PASS [${name}]: exit ${actual_exit} (expected ${want_exit}), no traceback"
        PASS=$((PASS + 1))
    else
        FAIL=$((FAIL + 1))
    fi
    rm -f "${stderr_tmp}"
}

# -----------------------------------------------------------------------
# Test cases
# -----------------------------------------------------------------------

echo "=== openfv CLI skeleton tests (P0.7) ==="
echo "Binary: ${OPENFV}"
echo "Fixtures: ${FIXTURES}"
echo ""

# T1: Good input via .f filelist — exit 0
run_case "T1: parse-only good .f" 0 \
    run "${FIXTURES}/tiny.f" --top tiny --parse-only

# T2: Good input via direct .sv file — exit 0
run_case "T2: parse-only good .sv" 0 \
    run "${FIXTURES}/tiny.sv" --top tiny --parse-only

# T3: Broken syntax via .f filelist — exit 11, no Python traceback
run_case_no_traceback "T3: parse-only broken .f → exit 11, no traceback" 11 \
    run "${FIXTURES}/broken.f" --top broken --parse-only

# T4: Missing --top flag — exit 10 (usage error)
run_case "T4: missing --top → exit 10" 10 \
    run "${FIXTURES}/tiny.f" --parse-only

# T5: Unknown flag — exit 10
run_case "T5: unknown flag → exit 10" 10 \
    run "${FIXTURES}/tiny.f" --top tiny --parse-only --unknown-flag-xyz

# T6: Missing input file — exit 10
run_case "T6: missing input file → exit 10" 10 \
    run "/tmp/nonexistent_does_not_exist_xyz.f" --top foo --parse-only

# T7: No command given — exit 10
run_case "T7: no command → exit 10" 10

# T8: --emit-only not implemented until M1 — exit 13
run_case "T8: emit-only → exit 13 (not implemented)" 13 \
    run "${FIXTURES}/tiny.f" --top tiny --emit-only

# T9: Full verification (no --parse-only) — exit 13 (not implemented until M1)
run_case "T9: full verify → exit 13 (not implemented)" 13 \
    run "${FIXTURES}/tiny.f" --top tiny

# T10: Invalid --depth → exit 10
run_case "T10: bad --depth → exit 10" 10 \
    run "${FIXTURES}/tiny.f" --top tiny --parse-only --depth 0

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------

echo ""
echo "=== Results: ${PASS} passed, ${FAIL} failed ==="

if [[ "${FAIL}" -gt 0 ]]; then
    exit 1
fi
exit 0
