#!/bin/bash

##
# fuzzers/agent/oracle.sh -- reach/trigger oracle for a single input.
#
# Runs the canary-instrumented oracle ($OUT/$PROGRAM) on one test case under
# Magma's `monitor`, and reports which bug canaries were *reached* and
# *triggered*, plus the process exit status.
#
# Magma's monitor forks $FUZZER/runonce.sh under a private MAGMA_STORAGE file,
# so every invocation is isolated -- no canary state leaks between inputs.
#
# Usage:   oracle.sh <input-file> [program]
#   <program> defaults to $PROGRAM, else the first entry of the target configrc.
#
# Output:  human-readable summary on stdout.
# Exit:    0 if at least one canary TRIGGERED, 1 if not, 2 on usage/setup error.
##

set -u

INPUT="${1:-}"
if [ -z "$INPUT" ]; then
    echo "usage: oracle.sh <input-file> [program]" >&2
    exit 2
fi
if [ ! -f "$INPUT" ]; then
    echo "oracle.sh: no such file: $INPUT" >&2
    exit 2
fi
INPUT="$(realpath "$INPUT")"

PROGRAM="${2:-${PROGRAM:-}}"
if [ -z "$PROGRAM" ]; then
    # shellcheck disable=SC1090,SC1091
    source "$TARGET/configrc"
    PROGRAM="${PROGRAMS[0]}"
fi
export PROGRAM

if [ ! -x "$OUT/$PROGRAM" ]; then
    echo "oracle.sh: missing/!exec oracle binary: $OUT/$PROGRAM" >&2
    avail=$(find "$OUT" -maxdepth 1 -type f -executable ! -name monitor \
            -printf '%f ' 2>/dev/null)
    echo "oracle.sh: available programs in \$OUT ($OUT): ${avail:-(none)}" >&2
    exit 2
fi

# monitor needs a writable cwd (it creates a temp MAGMA_STORAGE file there).
cd "$SHARED"

report="$("$OUT/monitor" --fetch watch --dump human \
            "$FUZZER/runonce.sh" "$INPUT")"
exit_code=$?

# monitor --dump human prints one line per canary:  "<name> reached R triggered T"
reached=()
triggered=()
while read -r name _ r _ t; do
    [ -z "${name:-}" ] && continue
    if [ "${r:-0}" -ne 0 ] 2>/dev/null; then reached+=("$name"); fi
    if [ "${t:-0}" -ne 0 ] 2>/dev/null; then triggered+=("$name"); fi
done <<< "$report"

verdict="NOT-REACHED"
if   [ "${#triggered[@]}" -gt 0 ]; then verdict="TRIGGERED"
elif [ "${#reached[@]}"   -gt 0 ]; then verdict="REACHED"
fi

signal_note=""
if [ "$exit_code" -gt 128 ]; then
    signal_note="  (killed by signal $((exit_code - 128)))"
fi

echo "program   : $PROGRAM"
echo "input     : $INPUT"
echo "exit_code : ${exit_code}${signal_note}"
echo "reached   : ${reached[*]:-<none>}"
echo "triggered : ${triggered[*]:-<none>}"
echo "verdict   : $verdict"

[ "${#triggered[@]}" -gt 0 ]
