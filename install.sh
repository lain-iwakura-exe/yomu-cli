#!/usr/bin/env bash
#
# install.sh — installs yomu-cli and its prerequisites, then places
# `yomu-cli` on your PATH so it can be run like any other command:
#
#   yomu-cli "one piece"
#
set -euo pipefail

REPO_RAW="https://raw.githubusercontent.com/lain-iwakura-exe/yomu-cli/main"
INSTALL_DIR="/usr/local/bin"
BIN_NAME="yomu-cli"

die() {
  echo "Error: $*" >&2
  exit 1
}

echo "==> Detecting package manager..."

if command -v pacman >/dev/null 2>&1; then
  echo "==> Arch-based distro detected (Arch / CachyOS / EndeavourOS)"
  sudo pacman -Sy --needed --noconfirm curl jq fzf chafa
elif command -v apt >/dev/null 2>&1; then
  echo "==> Debian-based distro detected (Debian / Ubuntu / Mint)"
  sudo apt update
  sudo apt install -y curl jq fzf chafa
elif command -v dnf >/dev/null 2>&1; then
  echo "==> Fedora-based distro detected (Fedora / Nobara)"
  sudo dnf install -y curl jq fzf chafa
else
  die "unsupported distro — install curl, jq, fzf, and chafa manually, then re-run this script."
fi

echo "==> Downloading yomu-cli..."
curl -fsSL "$REPO_RAW/yomu-cli.sh" -o /tmp/yomu-cli.sh || die "download failed."

echo "==> Installing to $INSTALL_DIR/$BIN_NAME (sudo required)"
sudo install -m 755 /tmp/yomu-cli.sh "$INSTALL_DIR/$BIN_NAME"
rm -f /tmp/yomu-cli.sh

echo "==> Done. Try it now:"
echo "    yomu-cli \"one piece\""
