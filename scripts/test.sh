#!/bin/sh
# Every unit and route test, from a fresh clone (Erlang/OTP 27 or later; no key, no network).
#   sh scripts/test.sh
set -e
here="$(cd "$(dirname "$0")/.." && pwd)"
out="$here/_build/default/lib/witness/ebin"
mkdir -p "$out"
# the library first, so the test host finds the witness_host behaviour it implements
erlc -o "$out" "$here"/witness/src/*.erl
erlc -pa "$out" -o "$out" "$here"/witness/test/*.erl
mods=$(cd "$out" && ls witness_*_tests.beam | sed 's/\.beam$//' | paste -sd, -)
erl -noshell -pa "$out" -eval "case eunit:test([$mods], []) of ok -> halt(0); _ -> halt(1) end."
