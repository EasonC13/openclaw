#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/EasonC13/openclaw.git"
BRANCH="release-3.13-patched"

# Detect npm global prefix (works on macOS + Linux, nvm/Homebrew/system)
NPM_PREFIX="$(npm prefix -g 2>/dev/null)"
INSTALL_DIR="$NPM_PREFIX/lib/node_modules/openclaw"
BIN_DIR="$NPM_PREFIX/bin"

echo "Installing to: $INSTALL_DIR"
echo "Bin link: $BIN_DIR/openclaw"

# Clean previous install
rm -rf "$INSTALL_DIR"
rm -f "$BIN_DIR/openclaw"

# Clone
git clone --branch "$BRANCH" --depth 1 "$REPO" "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Install production deps only, skip problematic preinstall scripts
npm install --omit=dev --ignore-scripts

# Create bin symlink
ln -sf "$INSTALL_DIR/openclaw.mjs" "$BIN_DIR/openclaw"
chmod +x "$INSTALL_DIR/openclaw.mjs"

echo ""
openclaw --version 2>/dev/null && echo "Install OK" || echo "ERROR: openclaw not in PATH (check that $BIN_DIR is in your PATH)"

# Cleanup git metadata to save space
rm -rf "$INSTALL_DIR/.git"
