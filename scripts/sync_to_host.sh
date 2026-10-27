#!/bin/sh
# Copy the Witness OTP modules and their tests into a host Erlang app (LoWisa's edge, or your own).
#   scripts/sync_to_host.sh path/to/host/app        (the app folder holding src/ and test/)
# This repository stays the source of truth: change Witness here, then sync.
set -e
host="$1"
[ -d "$host/src" ] && [ -d "$host/test" ] || { echo "usage: $0 path/to/app (with src/ and test/)"; exit 1; }
here="$(cd "$(dirname "$0")/.." && pwd)"
cp "$here"/witness/src/witness_*.erl "$host/src/"
cp "$here"/witness/test/witness_*_tests.erl "$host/test/"
echo "synced $(ls "$here"/witness/src/witness_*.erl | wc -l) modules and $(ls "$here"/witness/test/witness_*_tests.erl | wc -l) test modules into $host"
