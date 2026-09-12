#!/usr/bin/env bash
# build-wpe-webkit.sh
# Cross-compiles libwpe, WPE WebKit, and the Cog launcher for the Jetson TK1,
# targeting the armhf sysroot built by setup-toolchain.sh / copy-board-libs.sh.
#
# This gets you a current WebKit engine with EGL/GLES2 hardware compositing
# on the TK1's Kepler GPU, without touching the board's kernel or Nvidia
# driver. See docs/BUILD.md for background.

set -euo pipefail

WORKDIR="${WORKDIR:-$HOME/tegrak1-toolchain}"
SYSROOT="$WORKDIR/sysroot"
SRC="$WORKDIR/src"
TOOLCHAIN_FILE="$WORKDIR/armhf-toolchain.cmake"
JOBS="${JOBS:-$(nproc)}"

mkdir -p "$SRC"
cd "$SRC"

cat > "$TOOLCHAIN_FILE" <<EOF
set(CMAKE_SYSTEM_NAME Linux)
set(CMAKE_SYSTEM_PROCESSOR arm)
set(CMAKE_C_COMPILER arm-linux-gnueabihf-gcc)
set(CMAKE_CXX_COMPILER arm-linux-gnueabihf-g++)
set(CMAKE_SYSROOT ${SYSROOT})
set(CMAKE_FIND_ROOT_PATH ${SYSROOT})
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)
set(CMAKE_C_FLAGS "-march=armv7-a -mtune=cortex-a15 -mfpu=neon-vfpv4 -mfloat-abi=hard")
set(CMAKE_CXX_FLAGS "\${CMAKE_C_FLAGS}")
EOF

clone_if_missing () {
  local url="$1" dir="$2" tag="$3"
  if [ ! -d "$dir" ]; then
    git clone --depth 1 --branch "$tag" "$url" "$dir"
  fi
}

echo "==> Fetching sources"
clone_if_missing https://github.com/WebPlatformForEmbedded/libwpe.git libwpe main
clone_if_missing https://github.com/WebPlatformForEmbedded/WPEBackend-fdo.git WPEBackend-fdo master
clone_if_missing https://github.com/WebKit/WebKit.git WebKit main
clone_if_missing https://github.com/Igalia/cog.git cog master

build_cmake_project () {
  local dir="$1"; shift
  echo "==> Building $dir"
  cmake -S "$dir" -B "$dir/build" -G Ninja \
    -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
    -DCMAKE_INSTALL_PREFIX="$SYSROOT/usr" \
    -DCMAKE_BUILD_TYPE=Release \
    "$@"
  ninja -C "$dir/build" -j"$JOBS"
  ninja -C "$dir/build" install
}

build_cmake_project libwpe
build_cmake_project WPEBackend-fdo

echo "==> Building WPE WebKit (this is the long step -- expect hours on a"
echo "    laptop-class host; do NOT attempt this natively on the TK1 itself)"
cmake -S WebKit -B WebKit/build -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$TOOLCHAIN_FILE" \
  -DCMAKE_INSTALL_PREFIX="$SYSROOT/usr" \
  -DPORT=WPE \
  -DCMAKE_BUILD_TYPE=Release \
  -DENABLE_MINIBROWSER=OFF \
  -DUSE_GSTREAMER=OFF
ninja -C WebKit/build -j"$JOBS"
ninja -C WebKit/build install

build_cmake_project cog -DCOG_PLATFORM_FDO=ON

echo "==> Build complete. Cross-compiled artifacts are under:"
echo "    $SYSROOT/usr"
echo "Copy $SYSROOT/usr/{lib,bin,share} onto the TK1 (e.g. via rsync) and run:"
echo "    cog https://example.com"
