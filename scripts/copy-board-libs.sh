#!/usr/bin/env bash
# copy-board-libs.sh <board-ip> [board-user]
# Copies the Nvidia proprietary GL/EGL/tegra libraries and headers from the
# TK1 (running stock L4T R21.8) into the local cross-compile sysroot, so we
# link against the real hardware-accelerated driver instead of a stub.

set -euo pipefail

BOARD_IP="${1:?Usage: copy-board-libs.sh <board-ip> [user]}"
BOARD_USER="${2:-ubuntu}"
WORKDIR="${WORKDIR:-$HOME/tegrak1-toolchain}"
SYSROOT="$WORKDIR/sysroot"

LIB_PATHS=(
  /usr/lib/arm-linux-gnueabihf
  /usr/lib/arm-linux-gnueabihf/tegra
  /usr/include/EGL
  /usr/include/GLES2
  /usr/include/GLES3
  /usr/include/KHR
)

for p in "${LIB_PATHS[@]}"; do
  echo "==> Syncing $p"
  rsync -avL --ignore-missing-args "$BOARD_USER@$BOARD_IP:$p" "$SYSROOT$(dirname "$p")/" || \
    echo "    (skipped, not found on board -- check path)"
done

echo "==> Done. Verify libEGL.so / libGLESv2.so / libnvrm*.so exist under:"
echo "    $SYSROOT/usr/lib/arm-linux-gnueabihf"
