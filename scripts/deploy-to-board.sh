#!/usr/bin/env bash
# deploy-to-board.sh <board-ip> [board-user]
# Syncs the cross-compiled WPE WebKit / Cog artifacts from the sysroot built
# by build-wpe-webkit.sh onto the Jetson TK1's existing rootfs (stock L4T
# R21.8). Does NOT touch the board's kernel, X11, or Nvidia driver files.

set -euo pipefail

BOARD_IP="${1:?Usage: deploy-to-board.sh <board-ip> [user]}"
BOARD_USER="${2:-ubuntu}"
WORKDIR="${WORKDIR:-$HOME/tegrak1-toolchain}"
SYSROOT="$WORKDIR/sysroot"

if [ ! -d "$SYSROOT/usr" ]; then
  echo "ERROR: $SYSROOT/usr not found. Run build-wpe-webkit.sh first." >&2
  exit 1
fi

echo "==> Deploying cog + WPE WebKit runtime to $BOARD_USER@$BOARD_IP"

ssh "$BOARD_USER@$BOARD_IP" "sudo mkdir -p /opt/tegrak1-browser && sudo chown $BOARD_USER /opt/tegrak1-browser"

rsync -avz --progress \
  "$SYSROOT/usr/lib" \
  "$SYSROOT/usr/bin" \
  "$SYSROOT/usr/share" \
  "$BOARD_USER@$BOARD_IP:/opt/tegrak1-browser/"

echo "==> Writing launcher env wrapper on the board"
ssh "$BOARD_USER@$BOARD_IP" "cat > /opt/tegrak1-browser/run-cog.sh" <<'REMOTE_EOF'
#!/usr/bin/env bash
# run-cog.sh <url>
# Launches Cog with the correct library paths so it picks up the
# cross-compiled WPE WebKit instead of any system WebKitGTK, while still
# using the board's real Nvidia EGL/GLES driver from /usr/lib.
export LD_LIBRARY_PATH="/opt/tegrak1-browser/lib:/usr/lib/arm-linux-gnueabihf/tegra:${LD_LIBRARY_PATH:-}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export COG_PLATFORM_NAME=fdo
exec /opt/tegrak1-browser/bin/cog "${1:-https://example.com}"
REMOTE_EOF
ssh "$BOARD_USER@$BOARD_IP" "chmod +x /opt/tegrak1-browser/run-cog.sh"

echo "==> Done. Test it with:"
echo "    ssh $BOARD_USER@$BOARD_IP /opt/tegrak1-browser/run-cog.sh https://example.com"
echo "Next: install the systemd unit for kiosk-mode autostart (see"
echo "systemd/tegrak1-browser.service and docs/DEPLOY.md)"
