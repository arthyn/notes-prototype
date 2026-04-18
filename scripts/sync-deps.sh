#!/usr/bin/env bash
# scripts/sync-deps.sh
# Vendor %base (urbit/urbit) and %landscape (tloncorp/landscape) desk
# dependencies into desk/lib, desk/mar, desk/sur using peru.
# Run this once after cloning the repo, before building or rsync'ing to a ship.

set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v peru >/dev/null 2>&1; then
  cat >&2 <<'EOF'
peru is not installed. Install it:
  pip install peru         # via pip
  brew install peru        # via homebrew
See https://github.com/buildinspace/peru
EOF
  exit 1
fi

peru sync
echo "Desk dependencies synced."
