#!/bin/sh
# Copy the Exam Desk into a LoWisa IDE checkout as one renderer part.
#   scripts/sync_desk.sh path/to/ide        (the folder holding src/renderer-parts/)
set -e
ide="$1"
[ -d "$ide/src/renderer-parts" ] || { echo "usage: $0 path/to/ide (with src/renderer-parts/)"; exit 1; }
here="$(cd "$(dirname "$0")/.." && pwd)"
cp "$here/desk/witness-desk.js" "$ide/src/renderer-parts/27-witness-desk.js"
echo "synced the Exam Desk into $ide/src/renderer-parts/27-witness-desk.js"
