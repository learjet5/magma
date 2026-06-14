#!/bin/bash
set -e

##
# fuzzers/agent/cov_build.sh -- build the SCRATCH copy with LLVM source-based
# coverage instrumentation.
#
# Operates on the clean, patched copy at $MAGMA_SRC (/magma_src) -- it does NOT
# touch the canary oracle in /magma_out.  Coverage binaries go to
# $MAGMA_SRC/cov-out by default.  This is a *starting point*: the agent may
# copy/adapt it freely (it is just env + a call to the target's own build.sh).
#
# Usage:   cov_build.sh
#
# Knobs (env):
#   SRC_TARGET   target dir to build      (default: $MAGMA_SRC)
#   COV_OUT      output dir for binaries  (default: $MAGMA_SRC/cov-out)
#   WITH_CANARY  1 = also link Magma canaries (coverage + oracle in one binary)
#                0 = pure coverage build, no canary           (default: 0)
##

SRC_TARGET="${SRC_TARGET:-$MAGMA_SRC}"
COV_OUT="${COV_OUT:-$MAGMA_SRC/cov-out}"
WITH_CANARY="${WITH_CANARY:-0}"

if [ ! -d "$SRC_TARGET/repo" ]; then
    echo "cov_build.sh: no repo at $SRC_TARGET/repo" >&2
    exit 1
fi
mkdir -p "$COV_OUT"

export CC=clang
export CXX=clang++
export TARGET="$SRC_TARGET"
export OUT="$COV_OUT"

COV_FLAGS="-fprofile-instr-generate -fcoverage-mapping -g -O0"
export CFLAGS="$COV_FLAGS"
export CXXFLAGS="$COV_FLAGS"
export LDFLAGS="-L$COV_OUT -g -fprofile-instr-generate -fcoverage-mapping"
export LIBS=""

if [ "$WITH_CANARY" = "1" ]; then
    export CFLAGS="$CFLAGS -include $MAGMA/src/canary.h -DMAGMA_ENABLE_CANARIES"
    export CXXFLAGS="$CXXFLAGS -include $MAGMA/src/canary.h -DMAGMA_ENABLE_CANARIES"
    "$MAGMA/build.sh"                       # -> $COV_OUT/magma.o
    export LIBS="$LIBS -l:magma.o -lrt"
fi

# standalone replay driver (rebuilt with clang for the coverage build)
clang++ -std=c++11 -c "$FUZZER/src/driver.cpp" -fPIC -o "$COV_OUT/driver.o"
export LIBS="$LIBS -l:driver.o -lstdc++"

"$TARGET/build.sh"

echo "[cov_build] coverage binaries -> $COV_OUT"
echo "[cov_build] run one input, then report coverage, e.g.:"
echo "    LLVM_PROFILE_FILE=$COV_OUT/run1.profraw $COV_OUT/<program> <input>"
echo "    $FUZZER/cov_report.sh $COV_OUT/<program> $COV_OUT/*.profraw"
