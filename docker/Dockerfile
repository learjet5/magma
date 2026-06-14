##
# Magma agent-evaluation image.
#
# Unlike the stock Magma Dockerfile (which bakes a fuzzer into the image and
# runs a fuzzing campaign), this image is a *workbench* for LLM agents
# (Claude Code, DrillAgent, ...) to generate and validate Proof-of-Vulnerability
# inputs on Magma bugs.  See ../AGENT.md for the full design.
#
# Key differences vs the stock Magma docker/Dockerfile:
#   - base bumped to ubuntu:22.04 (modern Node.js / Python 3.12 / LLVM toolchain)
#   - the "agent" fuzzer slot installs agent runtimes instead of a real fuzzer;
#     the agent's own code is NOT baked in -- it is bind-mounted at run time
#   - a clean, patched-but-UNCOMPILED copy of the target is snapshotted to
#     /magma_src so the agent can freely edit it / re-instrument it (llvm-cov)
#     / insert feedback predicates -- without touching the canary oracle
#   - no ENTRYPOINT (no campaign): the container is long-lived and driven by
#     the agent / eval harness over `docker exec`
##
FROM ubuntu:22.04

RUN DEBIAN_FRONTEND=noninteractive apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y sudo

## Magma directory hierarchy
# magma_root is relative to the docker-build's working directory.
# The image must be built with the magma-agent root as build context.
ARG magma_root=.

## Path variables inside the container
ENV MAGMA_R=/magma
ENV OUT=/magma_out
ENV SHARED=/magma_shared
# Clean, patched-but-uncompiled scratch copy of the target (agent extension).
ENV MAGMA_SRC=/magma_src

ENV CC=/usr/bin/gcc
ENV CXX=/usr/bin/g++
ENV LD=/usr/bin/ld
ENV AR=/usr/bin/ar
ENV AS=/usr/bin/as
ENV NM=/usr/bin/nm
ENV RANLIB=/usr/bin/ranlib

ARG USER_ID=1000
ARG GROUP_ID=1000
RUN mkdir -p /home && \
	groupadd -g ${GROUP_ID} magma && \
	useradd -l -u ${USER_ID} -K UMASK=0000 -d /home -g magma magma && \
	chown magma:magma /home
# Passwordless sudo: an agent may need to apt-install extra tooling at run time.
RUN echo "magma:magma" | chpasswd && usermod -a -G sudo magma && \
	echo "magma ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/magma && \
	chmod 0440 /etc/sudoers.d/magma

RUN mkdir -p ${SHARED} ${OUT} ${MAGMA_SRC} && \
	chown magma:magma ${SHARED} ${OUT} ${MAGMA_SRC} && \
	chmod 0755 ${SHARED} ${OUT} ${MAGMA_SRC}

## Magma support files
ARG magma_path=magma
ENV MAGMA=${MAGMA_R}/${magma_path}
USER root:root
RUN mkdir -p ${MAGMA} && chown magma:magma ${MAGMA}
COPY --chown=magma:magma ${magma_root}/${magma_path} ${MAGMA}/
RUN DEBIAN_FRONTEND=noninteractive ${MAGMA}/preinstall.sh
USER magma:magma
RUN ${MAGMA}/prebuild.sh

## "agent" fuzzer slot -- installs the agent toolchain & runtimes.
# fetch.sh / build.sh are deliberately minimal: the agent's code is mounted at
# run time, not baked in.  preinstall.sh is where the real work happens.
ARG fuzzer_name=agent
ARG fuzzer_path=fuzzers/${fuzzer_name}
ENV FUZZER=${MAGMA_R}/${fuzzer_path}
USER root:root
RUN mkdir -p ${FUZZER} && chown magma:magma ${FUZZER}
COPY --chown=magma:magma ${magma_root}/${fuzzer_path} ${FUZZER}/
RUN DEBIAN_FRONTEND=noninteractive ${FUZZER}/preinstall.sh
USER magma:magma
RUN ${FUZZER}/fetch.sh
RUN ${FUZZER}/build.sh

## Target program
ARG target_name
ARG target_path=targets/${target_name}
ENV TARGET=${MAGMA_R}/${target_path}
USER root:root
RUN mkdir -p ${TARGET} && chown magma:magma ${TARGET}
COPY --chown=magma:magma ${magma_root}/${target_path} ${TARGET}/
RUN DEBIAN_FRONTEND=noninteractive ${TARGET}/preinstall.sh
USER magma:magma
RUN ${TARGET}/fetch.sh
RUN ${MAGMA}/apply_patches.sh

## --- agent extension: snapshot a clean, patched, UNCOMPILED target copy ---
# Taken AFTER apply_patches.sh but BEFORE instrument.sh, so the snapshot holds
# pristine patched source (no autoreconf droppings / object files).  The agent
# may freely edit /magma_src, re-instrument it, insert predicates, etc. --
# without touching the canary oracle in /magma_out.
RUN cp -a ${TARGET}/. ${MAGMA_SRC}/
# Initialize a fresh git repo if the target's fetch.sh didn't produce one
# (e.g. sqlite3 uses curl+tar, not git clone).  This way every target's
# scratch copy supports the same `git diff` workflow regardless of how the
# source was fetched.
RUN cd ${MAGMA_SRC}/repo && \
	if [ ! -d .git ]; then \
		git -c user.name=magma -c user.email=magma@localhost init -q -b main && \
		echo "[snapshot] initialized fresh .git (no native upstream history)"; \
	fi && \
	git -c user.name=magma -c user.email=magma@localhost add -A && \
	git -c user.name=magma -c user.email=magma@localhost commit -q \
	    -m "magma: patched baseline (setup + bug patches)"

## Canary configuration parameters.
# NOTE: `isan` / mode are still under discussion (see AGENT.md). Defaults here:
#   canaries -> enabled by build_agent_image.sh (the oracle needs canaries)
#   isan / harden / fixes -> off unless passed as --build-arg
ARG isan
ARG harden
ARG canaries
ARG fixes

ARG ISAN_FLAG=${isan:+-DMAGMA_FATAL_CANARIES}
ARG HARDEN_FLAG=${harden:+-DMAGMA_HARDEN_CANARIES}
ARG CANARIES_FLAG=${canaries:+-DMAGMA_ENABLE_CANARIES}
ARG FIXES_FLAG=${fixes:+-DMAGMA_ENABLE_FIXES}
ARG BUILD_FLAGS="-include ${MAGMA}/src/canary.h ${CANARIES_FLAG} ${FIXES_FLAG} ${ISAN_FLAG} ${HARDEN_FLAG} -g -O0"

ENV CFLAGS=${BUILD_FLAGS}
ENV CXXFLAGS=${BUILD_FLAGS}
ENV LIBS="-l:magma.o -lrt"
ENV LDFLAGS="-L${OUT} -g"

## Build the canary-instrumented ORACLE into /magma_out.
RUN ${FUZZER}/instrument.sh

## Reset build flags so the agent's own run-time builds start from a clean
## slate (cov_build.sh etc. set their own flags explicitly).
ENV CFLAGS=""
ENV CXXFLAGS=""
ENV LIBS=""
ENV LDFLAGS=""

WORKDIR ${SHARED}
# No ENTRYPOINT: the eval harness keeps the container alive (e.g. `docker run
# -dit ... sleep infinity`) and drives the agent via `docker exec`.
CMD ["/bin/bash"]
