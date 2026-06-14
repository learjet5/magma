#!/bin/bash
set -e

# AGENT-IMAGE ADAPTATION (Ubuntu 22.04): the legacy `python` package no longer
# exists in jammy (Python 2 retired).  libsndfile's autogen.sh expects a
# `python` command, so we install python3 and symlink it into place -- same
# pattern as magma-pbfuzz.

apt-get update && \
    apt-get install -y git make autoconf autogen automake build-essential libasound2-dev \
  libflac-dev libogg-dev libtool libvorbis-dev libopus-dev libmp3lame-dev \
  libmpg123-dev pkg-config python3

ln -sf /usr/bin/python3 /usr/bin/python
