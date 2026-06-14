#!/bin/bash
set -e

##
# fuzzers/agent/build.sh -- runs at image-build time.
#
# The "agent" slot has no fuzzer of its own to build.  We only compile the
# standalone replay driver, so the canary oracle (linked by instrument.sh) can
# be invoked as `<program> <input-file>`.
#
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
# - env OUT:    path to directory where artifacts are stored
# - env CXX:    C++ compiler (gcc/g++ at this stage; canary flags not yet set)
##

# compile the standalone fuzz-target replay driver
$CXX $CXXFLAGS -std=c++11 -c "$FUZZER/src/driver.cpp" -fPIC \
    -o "$OUT/driver.o"
