#!/usr/bin/env bash
# setup-toolchain.sh
# Prepares an x86_64 host to cross-compile for the Jetson TK1 (Tegra K1),
# targeting the STOCK L4T R21.8 environment (kernel 3.10.40, armhf, glibc from
# Ubuntu 14.04) so the proprietary Nvidia GPU driver / EGL stack stays intact.
#
# DO NOT run this on the board itself and DO NOT upgrade the board's kernel.
# See docs/BUILD.md for why.

set -euo pipefail

WORKDIR="${WORKDIR:-$HOME/tegrak1-toolchain}"
SYSROOT="$WORKDIR/sysroot"
mkdir -p "$WORKDIR" "$SYSROOT"

echo "==> Installing cross-compiler (armhf, hard-float, Cortex-A15 capable)"
sudo apt-get update
sudo apt-get install -y \
    gcc-arm-linux-gnueabihf \
    g++-arm-linux-gnueabihf \
    qemu-user-static \
    binfmt-support \
    debootstrap \
    rsync \
    git \
    cmake \
    ninja-build \
    pkg-config

echo "==> Building an armhf sysroot matching the board's userspace (trusty/14.04)"
# We debootstrap a matching armhf root so headers/libs (glibc, libEGL stubs,
# X11) line up with what's actually on the TK1. Copy the REAL libEGL/libGLES
# and Nvidia tegra libs off the board into this sysroot afterwards (see
# copy-board-libs.sh) -- do not use Mesa/generic EGL headers instead.
sudo debootstrap --arch=armhf --foreign trusty "$SYSROOT" http://ports.ubuntu.com/ubuntu-ports

echo "==> Sysroot prepared at $SYSROOT"
echo "Next: run scripts/copy-board-libs.sh <board-ip> to pull the Nvidia"
echo "EGL/GLES/tegra libs from the TK1 into the sysroot, then run"
echo "scripts/build-wpe-webkit.sh"
