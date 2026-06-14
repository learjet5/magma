#!/bin/bash
set -e

##
# fuzzers/agent/cov_report.sh -- merge .profraw files and print a coverage
# report for a binary built by cov_build.sh.
#
# Generate .profraw first by running the coverage binary with LLVM_PROFILE_FILE:
#     LLVM_PROFILE_FILE=/magma_src/cov-out/run1.profraw \
#         /magma_src/cov-out/<program> <input>
#
# Usage:   cov_report.sh <cov-binary> <file.profraw> [more.profraw ...]
##

if [ "$#" -lt 2 ]; then
    echo "usage: cov_report.sh <cov-binary> <file.profraw> [more.profraw ...]" >&2
    exit 1
fi

BIN="$1"; shift
if [ ! -x "$BIN" ]; then
    echo "cov_report.sh: no such binary: $BIN" >&2
    exit 1
fi

merged="$(dirname "$BIN")/$(basename "$BIN").profdata"
llvm-profdata merge -sparse "$@" -o "$merged"

echo "=== llvm-cov report : $BIN ==="
llvm-cov report "$BIN" -instr-profile="$merged"
echo
echo "# line-level detail for one source file:"
echo "#   llvm-cov show '$BIN' -instr-profile='$merged' <source-file>"
