#!/bin/bash
set -e

##
# fuzzers/agent/instrument.sh -- runs at image-build time.
#
# Builds the canary-instrumented ORACLE into $OUT.  At this point CFLAGS /
# CXXFLAGS already carry the Magma canary flags (set in docker/Dockerfile).
# CC/CXX stay gcc/g++, i.e. the oracle is a plain canary build with NO coverage
# instrumentation -- the agent does its own coverage builds on the scratch copy
# (/magma_src) at run time via cov_build.sh.
#
# Pre-requirements:
# - env FUZZER: path to fuzzer work dir
# - env TARGET: path to target work dir
# - env MAGMA:  path to Magma support files
# - env OUT:    path to directory where artifacts are stored
# - env CFLAGS/CXXFLAGS: must carry the Magma canary instrumentation
##

# link the standalone replay driver into the target program
export LIBS="$LIBS -l:driver.o -lstdc++"

"$MAGMA/build.sh"
"$TARGET/build.sh"

# NOTE: $OUT is passed straight to the target build.sh -- the artifact itself
#       (a libFuzzer-style harness + replay driver) is the oracle binary.
