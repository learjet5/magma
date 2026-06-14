#!/bin/bash

##
# fuzzers/agent/run.sh -- there is no fuzzing campaign in the agent image.
#
# The agent image is a workbench, not a fuzzer.  Drive the agent over
# `docker exec`, and use the helper scripts in this directory:
#   - oracle.sh      : run the canary oracle on one input (reach/trigger)
#   - cov_build.sh   : build the scratch copy with llvm-cov instrumentation
#   - cov_report.sh  : merge .profraw and print a coverage report
# See ../../AGENT.md.
##

echo "agent image: no fuzzer included -- this is an agent-evaluation workbench." >&2
echo "Use \$FUZZER/oracle.sh, cov_build.sh, cov_report.sh; see AGENT.md."        >&2
exit 1
