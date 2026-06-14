#!/bin/bash
set -e

##
# fuzzers/agent/preinstall.sh -- runs as root at image-build time.
#
# The "agent" slot is NOT a fuzzer.  It installs the toolchain & runtimes an
# LLM agent needs to work *entirely inside* the container:
#   - LLVM / Clang 14 : re-instrumenting the scratch copy (llvm-cov, profdata)
#   - Node.js 20      : Claude Code and other Node-based generic agents
#   - Python 3.12     : DrillAgent (its source uses PEP 701, needs 3.12+)
#   - debug/analysis  : gdb, ripgrep, strace, ...
#
# The agent's own *code* is bind-mounted at `docker run` time, not installed
# here.  See ../../AGENT.md.
##

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y --no-install-recommends \
    ca-certificates curl wget gnupg git patch \
    build-essential make pkg-config \
    gdb ripgrep strace ltrace file less vim nano tmux jq \
    software-properties-common

# --- LLVM / Clang 14 : source-based coverage (llvm-cov, llvm-profdata) ------
apt-get install -y --no-install-recommends clang-14 llvm-14 lld-14
update-alternatives \
    --install /usr/bin/clang     clang     /usr/bin/clang-14 100 \
    --slave   /usr/bin/clang++   clang++   /usr/bin/clang++-14 \
    --slave   /usr/bin/clang-cpp clang-cpp /usr/bin/clang-cpp-14
update-alternatives \
    --install /usr/bin/llvm-config    llvm-config    /usr/bin/llvm-config-14 100 \
    --slave   /usr/bin/llvm-cov       llvm-cov       /usr/bin/llvm-cov-14 \
    --slave   /usr/bin/llvm-profdata  llvm-profdata  /usr/bin/llvm-profdata-14

# --- Node.js 20 + Claude Code CLI ------------------------------------------
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt-get install -y nodejs
npm install -g @anthropic-ai/claude-code || \
    echo "[preinstall] WARNING: 'claude-code' global install failed -- " \
         "install it at run time inside the container if needed."

# --- Python 3.12 + pip : DrillAgent ----------------------------------------
add-apt-repository -y ppa:deadsnakes/ppa
apt-get update
apt-get install -y --no-install-recommends \
    python3.12 python3.12-venv python3.12-dev
curl -fsSL https://bootstrap.pypa.io/get-pip.py | python3.12 -
# DrillAgent's own Python dependencies (claude-agent-sdk, ...) are NOT baked
# in: install them at run time, or mount a prepared site-packages. See AGENT.md.

apt-get clean
rm -rf /var/lib/apt/lists/*
