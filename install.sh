#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/EasonC13/openclaw.git"
BRANCH="release-3.12-patched"
DIR="${TMPDIR:-/tmp}/openclaw-patched"

rm -rf "$DIR"
git clone --branch "$BRANCH" --depth 1 "$REPO" "$DIR"
cd "$DIR"
npm install --omit=dev --ignore-scripts
npm install -g --ignore-scripts=false .

echo ""
echo "Installed: $(openclaw --version 2>/dev/null || echo 'openclaw not in PATH')"
rm -rf "$DIR"
