#!/usr/bin/env bash
##
# build_agent_image.sh -- build a Magma agent-evaluation image for one target.
#
# Produces the image  magma/agent/<target>  using docker/Dockerfile and the
# "agent" fuzzer slot.  Naming mirrors the upstream Magma convention
# (magma/<fuzzer>/<target>, e.g. magma/aflplusplus/libpng) and PBFuzz.
# See AGENT.md for the design.
#
# Usage:
#   ./build_agent_image.sh <target> [extra docker-build args...]
#
#   <target>  one of: libpng lua libsndfile libtiff libxml2 openssl php
#                     poppler sqlite3
#
# Examples:
#   ./build_agent_image.sh libpng
#   ./build_agent_image.sh libpng --build-arg isan=         # disable fatal canaries (default ON)
#   ./build_agent_image.sh libpng --no-cache
##
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "$#" -lt 1 ]; then
    grep -E '^#( |$)' "$0" | sed -E 's/^# ?//'
    exit 1
fi

TARGET="$1"; shift || true

if [ ! -d "$ROOT/targets/$TARGET" ]; then
    echo "[ERR] unknown target: $TARGET" >&2
    echo "      available: $(cd "$ROOT/targets" && echo *)" >&2
    exit 1
fi

TAG="magma/agent/$TARGET"

echo "[build] $TAG  (context: $ROOT)"
docker build \
    -f "$ROOT/docker/Dockerfile" \
    --build-arg fuzzer_name=agent \
    --build-arg target_name="$TARGET" \
    --build-arg canaries=1 \
    --build-arg isan=1 \
    --build-arg USER_ID="$(id -u)" \
    --build-arg GROUP_ID="$(id -g)" \
    -t "$TAG" \
    "$@" \
    "$ROOT"

echo "[done] built $TAG"
echo
echo "Run it (long-lived, agent driven over docker exec):"
echo "  docker run -dit --name ${TARGET}-agent \\"
echo "    --cap-add=SYS_PTRACE --security-opt seccomp=unconfined \\"
echo "    -v \"\$PWD/results:/magma_shared\" \\"
echo "    -v \"/path/to/agent-code:/agent\" \\"
echo "    $TAG sleep infinity"
echo "  docker exec -it ${TARGET}-agent bash"
