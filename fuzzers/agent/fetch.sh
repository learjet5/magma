#!/bin/bash
set -e

##
# fuzzers/agent/fetch.sh -- intentionally (almost) empty.
#
# A real Magma fuzzer fetches its own source here.  The "agent" slot has
# nothing to fetch: the agent's code is bind-mounted at `docker run` time, not
# baked into the image.  See ../../AGENT.md.
##

echo "[agent/fetch.sh] nothing to fetch (agent code is mounted at run time)."
