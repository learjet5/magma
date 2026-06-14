#!/bin/bash

apt-get update && \
    apt-get install -y git make autoconf automake libtool pkg-config cmake \
        zlib1g-dev libjpeg-dev libopenjp2-7-dev libpng-dev libcairo2-dev \
        libtiff-dev liblcms2-dev libboost-dev libbrotli-dev
# AGENT-IMAGE ADAPTATION (Ubuntu 22.04):
# 1) libbrotli-dev: freetype's WOFF2 module needs brotli at link time.
# 2) ld.lld symlink: poppler's cmake build uses `-fuse-ld=lld` so that the
#    static archive order for brotli vs libfreetype.a doesn't matter (GNU ld
#    is strict left-to-right; lld is multi-pass).  We have lld-14 from the
#    agent preinstall but no unversioned `ld.lld`; gcc's `-fuse-ld=lld` looks
#    for that exact name.
ln -sf /usr/bin/ld.lld-14 /usr/bin/ld.lld