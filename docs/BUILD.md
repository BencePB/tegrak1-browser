# Build notes: why we cross-compile against the stock L4T kernel

The Jetson TK1's GPU acceleration comes from Nvidia's proprietary driver,
which is only validated against the last official release for this board:
**L4T R21.8** (kernel 3.10.40, Ubuntu 14.04-based userspace).

Nvidia never ported the Tegra K1 GPU kernel module to newer kernels. Real
world attempts to boot a mainline 4.x kernel on the TK1 lose the Nvidia
driver entirely and fall back to the open-source `nouveau` driver, which
means **software-only rendering** -- no hardware EGL/GLES compositing, no
CUDA. A multi-year community effort to port the TK1 GPU driver to modern
LTS kernels is still ongoing and incomplete.

## The strategy this repo uses

1. **Never touch the board's kernel or Nvidia driver.** Keep it on stock
   L4T R21.8.
2. **Cross-compile modern userspace software** (WPE WebKit + Cog) on an
   x86_64 host, targeting an armhf sysroot that mirrors the board's actual
   libraries -- including the real Nvidia `libEGL`/`libGLESv2`/tegra libs
   pulled off the board itself (see `scripts/copy-board-libs.sh`).
3. **Deploy only the resulting binaries** to the TK1's existing rootfs.
   The kernel, X11 ABI, and GPU driver are never modified, so hardware
   acceleration is preserved.

## Why WPE WebKit + Cog

- Built specifically for embedded/low-power Linux ARM devices (used in
  set-top boxes, infotainment, kiosks).
- Uses EGL/GLES2 directly for hardware-accelerated compositing -- no need
  for a full desktop compositor stack.
- Actively maintained by Igalia, tracking current WebKit, unlike stock
  WebKitGTK builds frozen at Ubuntu 14.04 vintage.
- Cog is a minimal launcher/shell around libwpe, ideal for a
  single-purpose kiosk-style browser on constrained hardware.

## Steps

```
scripts/setup-toolchain.sh              # sets up cross-compiler + base sysroot
scripts/copy-board-libs.sh <board-ip>   # pulls real Nvidia EGL/GLES libs from the TK1
scripts/build-wpe-webkit.sh             # cross-compiles libwpe, WPEBackend-fdo, WebKit, cog
```

Then rsync `$SYSROOT/usr/{lib,bin,share}` onto the board and run:

```
cog https://example.com
```

## Fallback if hardware EGL linking fails

If the Nvidia EGL libraries can't be linked against cleanly in this setup,
fall back to a software rendering path (Mesa llvmpipe or nouveau's software
GL) for basic page rendering. Expect JS-heavy sites to be slow under
software rendering -- this is a last resort, not the target configuration.
