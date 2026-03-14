#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/EasonC13/openclaw.git"
BRANCH="release-3.13-patched"
INSTALL_DIR="/usr/lib/node_modules/openclaw"

# Clean previous install
rm -rf "$INSTALL_DIR" /usr/bin/openclaw

# Clone
git clone --branch "$BRANCH" --depth 1 "$REPO" "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Install production deps only, skip problematic preinstall scripts
npm install --omit=dev --ignore-scripts

# Create bin symlink
ln -sf "$INSTALL_DIR/openclaw.mjs" /usr/bin/openclaw
chmod +x "$INSTALL_DIR/openclaw.mjs"

echo ""
openclaw --version 2>/dev/null && echo "Install OK" || echo "ERROR: openclaw not working"

# Cleanup git metadata to save space
rm -rf "$INSTALL_DIR/.git"
