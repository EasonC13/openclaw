#!/usr/bin/env bash
set -euo pipefail

REPO="https://github.com/EasonC13/openclaw.git"
BRANCH="release-3.12-patched"
TMPDIR="${TMPDIR:-/tmp}/openclaw-patched"

rm -rf "$TMPDIR"
git clone --branch "$BRANCH" --depth 1 "$REPO" "$TMPDIR"
cd "$TMPDIR"
npm install --omit=dev --ignore-scripts
npm install -g .

echo ""
echo "Installed: $(openclaw --version 2>/dev/null || echo 'openclaw not in PATH')"
rm -rf "$TMPDIR"
