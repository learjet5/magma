#!/bin/bash

##
# fuzzers/agent/runonce.sh -- run the oracle binary once on a single input.
#
# This is the command Magma's `monitor --fetch watch` execs (see oracle.sh).
# It runs $OUT/$PROGRAM on the test case and propagates the *real* exit status,
# so a crash surfaces as 128+signal (e.g. 139 = SIGSEGV).
#
# Pre-requirements:
# - $1: path to the test case
# - env OUT:     directory containing the oracle binary
# - env PROGRAM: name of the binary to run (found in $OUT)
# + env ARGS:    program arguments; the token "@@" is replaced by the test case
# + env TIMELIMIT:  wall-clock limit (default: 60s)
# + env MEMLIMIT_MB: address-space limit in MiB (default: 0 = unlimited)
##

TIMELIMIT="${TIMELIMIT:-60s}"
MEMLIMIT_MB="${MEMLIMIT_MB:-0}"

run_limited()
{
    if [ "${MEMLIMIT_MB:-0}" -gt 0 ]; then
        ulimit -Sv $((MEMLIMIT_MB << 10))
    fi
    exec "$@"
}
export -f run_limited

# substitute "@@" in ARGS with the test-case path; default to a trailing arg
args="${ARGS/@@/"'$1'"}"
if [ -z "$args" ]; then
    args="'$1'"
fi

timeout -s KILL --preserve-status "$TIMELIMIT" \
    bash -c "run_limited '$OUT/$PROGRAM' $args"
