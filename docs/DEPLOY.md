# Deploying the browser to the board

After `scripts/build-wpe-webkit.sh` finishes, the cross-compiled runtime
lives in `$SYSROOT/usr/{lib,bin,share}` on your build host. This step gets
it onto the TK1 and running.

## 1. Copy the runtime over

```
scripts/deploy-to-board.sh <board-ip> [user]
```

This installs everything under `/opt/tegrak1-browser/` on the board --
**not** into `/usr`, so the stock Nvidia driver files and system libraries
are left untouched. It also writes a small `run-cog.sh` wrapper on the
board that sets `LD_LIBRARY_PATH` to prefer our freshly built WPE WebKit
libs while still pointing at the board's real
`/usr/lib/arm-linux-gnueabihf/tegra` for the Nvidia EGL/GLES driver.

## 2. Test it manually first

```
ssh <user>@<board-ip> /opt/tegrak1-browser/run-cog.sh https://example.com
```

Confirm you get hardware-accelerated rendering (check for reasonable
scroll/paint performance) before wiring up autostart. If it falls back to
software rendering, double check `copy-board-libs.sh` actually pulled the
real Nvidia libraries and not stubs.

## 3. Install as a kiosk service (optional)

Copy `systemd/tegrak1-browser.service` onto the board and enable it:

```
scp systemd/tegrak1-browser.service <user>@<board-ip>:/tmp/
ssh <user>@<board-ip> "sudo mv /tmp/tegrak1-browser.service /etc/systemd/system/ \
  && sudo systemctl daemon-reload \
  && sudo systemctl enable --now tegrak1-browser"
```

Edit the `ExecStart` URL in the unit file before installing if you want a
different start page than `https://example.com`.

## Troubleshooting

- **Black screen / crash on start**: check `journalctl -u tegrak1-browser`
  on the board. Most often this is a missing or mismatched
  `libEGL`/`libGLESv2` symlink -- re-run `copy-board-libs.sh`.
- **Runs but very slow / high CPU**: likely fell back to software
  rendering. Verify `COG_PLATFORM_NAME=fdo` is set and that WPEBackend-fdo
  was built against the board's real EGL headers, not generic Mesa ones.
