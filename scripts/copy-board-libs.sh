#!/usr/bin/env bash
# copy-board-libs.sh <board-ip> [board-user]
# Copies the Nvidia proprietary GL/EGL/tegra libraries and headers from the
# TK1 (running stock L4T R21.8) into the local cross-compile sysroot, so we
# link against the real hardware-accelerated driver instead of a stub.
#
# Confirmed on real hardware (L4T R21.8, kernel 3.10.40, Ubuntu 14.04):
#   - EGL/GLES driver libs live in /usr/lib/arm-linux-gnueabihf/tegra-egl/
#     (libEGL.so -> libEGL.so.1, libGLESv2.so.2, libGLESv1_CM.so.1)
#   - NVRM/multimedia libs live in /usr/lib/arm-linux-gnueabihf/tegra/
#   These are TWO SEPARATE directories -- both are needed.

set -euo pipefail

BOARD_IP="${1:?Usage: copy-board-libs.sh <board-ip> [user]}"
BOARD_USER="${2:-ubuntu}"
WORKDIR="${WORKDIR:-$HOME/tegrak1-toolchain}"
SYSROOT="$WORKDIR/sysroot"

LIB_PATHS=(
  /usr/lib/arm-linux-gnueabihf/tegra
  /usr/lib/arm-linux-gnueabihf/tegra-egl
  /usr/include/EGL
  /usr/include/GLES2
  /usr/include/GLES3
  /usr/include/KHR
)

for p in "${LIB_PATHS[@]}"; do
  DEST_PARENT="$SYSROOT$(dirname "$p")"
  mkdir -p "$DEST_PARENT"
  echo "==> Syncing $p"
  rsync -avL --ignore-missing-args "$BOARD_USER@$BOARD_IP:$p" "$DEST_PARENT/" || \
    echo "    (skipped, not found on board -- check path)"
done

EGL_DIR="$SYSROOT/usr/lib/arm-linux-gnueabihf/tegra-egl"

if [ -f "$EGL_DIR/libGLESv2.so.2" ] && [ ! -e "$EGL_DIR/libGLESv2.so" ]; then
  echo "==> Creating missing libGLESv2.so -> libGLESv2.so.2 symlink"
  ln -s libGLESv2.so.2 "$EGL_DIR/libGLESv2.so"
fi
if [ -f "$EGL_DIR/libGLESv1_CM.so.1" ] && [ ! -e "$EGL_DIR/libGLESv1_CM.so" ]; then
  echo "==> Creating missing libGLESv1_CM.so -> libGLESv1_CM.so.1 symlink"
  ln -s libGLESv1_CM.so.1 "$EGL_DIR/libGLESv1_CM.so"
fi

echo "==> Done. Verify these exist under $EGL_DIR:"
echo "    libEGL.so -> libEGL.so.1"
echo "    libGLESv2.so -> libGLESv2.so.2"
echo "And under $SYSROOT/usr/lib/arm-linux-gnueabihf/tegra:"
echo "    libnvrm.so, libnvos.so, libnvmm.so, etc."
echo ""
echo "IMPORTANT: point pkg-config / CMAKE_LIBRARY_PATH at BOTH"
echo "  $SYSROOT/usr/lib/arm-linux-gnueabihf/tegra-egl"
echo "  $SYSROOT/usr/lib/arm-linux-gnueabihf/tegra"
echo "when building WPEBackend-fdo and WebKit."
