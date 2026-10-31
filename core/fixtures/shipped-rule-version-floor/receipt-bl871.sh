#!/usr/bin/env bash
# BL-871 receipt. Usage: bash core/fixtures/shipped-rule-version-floor/receipt-bl871.sh   (run from the repo root)
# Runs NO fixture. It reads the fixture's key rows from the hook's own composer
# (`hermetic-run.sh --key-only shipped-rule-version-floor`) and requires that the WHOLE core/fixtures/
# directory is keyed: its own listing row (so a NEW shipping directory moves the key) and at least one
# file of a shipping fixture that is neither lib/ nor this fixture (so a byte or shape change there does).
# A comment line in inputs.decl is not a row, so prose cannot satisfy it.
# It self-probes FIRST, on a copy of the fixture directory passed as `--fixture-dir`: a copy narrowed to
# `core/fixtures/lib/` must REFUSE, and a copy declaring `core/fixtures/` must PASS.
# 0 = both rows are present (and the probe fired both ways).
# 1 = the listing row or the other-fixture row is absent, or the composer rejected the declaration.
# 2 = the receipt could not run (not at the distribution root, no scratch dir, a probe that did not fire).
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
FX=shipped-rule-version-floor
FXD=core/fixtures/$FX
[ -f core/scripts/hermetic-run.sh ] && [ -f "$FXD/inputs.decl" ] || { echo "REFUSED: run from the distribution root" >&2; exit 2; }

# judge_rows <rows> -> 0 pass, 1 refuse. Pure: takes the composer's row text (path<TAB>hash per line), runs no tool.
judge_rows() {
  local rows="$1" paths
  paths="$(cut -f1 <<<"$rows")"
  grep -qxF 'core/fixtures/' <<<"$paths" \
    || { echo "REFUSED: no core/fixtures/ listing row -- a new shipping directory would not move the key" >&2; return 1; }
  grep -q '^core/fixtures/' <<<"$(grep -v -e '^core/fixtures/$' -e '^core/fixtures/lib/' -e "^$FXD/" <<<"$paths")" \
    || { echo "REFUSED: no row for a shipping fixture other than lib/ and $FX" >&2; return 1; }
  return 0
}

# judge [fixture dir override] -> 0 pass, 1 refuse. Obtains the rows from the composer, then judges them.
judge() {
  local rows
  rows="$(bash core/scripts/hermetic-run.sh ${1:+--fixture-dir "$1"} --key-only "$FX" 2>/dev/null)" \
    || { echo "REFUSED: the key composer rejected the declaration" >&2; return 1; }
  judge_rows "$rows"
}

# Row-set probes: judge_rows on seeded rows in the composer's shape, bypassing the composer, so clause 2 is shown
# able to fire. A miss is PROBE DEAD.
TAB="$(printf '\t')"
H=0000000000000000000000000000000000000000000000000000000000000000
row() { printf '%s%s%s\n' "$1" "$TAB" "$H"; }
probe_rows() { # <label> <expected rc> <rows>
  local rc
  judge_rows "$3" 2>/dev/null; rc=$?
  [ "$rc" -eq "$2" ] || { echo "PROBE DEAD: row probe '$1' gave rc $rc, expected $2" >&2; exit 2; }
}
LR="$(row /bin/bash)
$(row core/fixtures/)"
probe_rows "listing + lib/ + own fixture" 1 "$LR
$(row core/fixtures/lib/mutant.sh)
$(row "$FXD/run.sh")"
probe_rows "listing + another fixture" 0 "$LR
$(row core/fixtures/lib/mutant.sh)
$(row core/fixtures/other-fixture/run.sh)"
probe_rows "no listing row" 1 "$(row core/fixtures/other-fixture/run.sh)"
probe_rows "empty" 1 ""

T="$(mktemp -d)" || exit 2
trap 'rm -f "$T/fx/"* "$T/fx/."[!.]* 2>/dev/null; rmdir "$T/fx" 2>/dev/null; rmdir "$T" 2>/dev/null' EXIT
cp -R "$FXD" "$T/fx" || exit 2
# Both probe copies are built from the live declaration with every whole-core/fixtures/ line dropped, then ONE line
# appended: lib/ (must refuse) or core/fixtures/ (must pass). They differ by that line alone, and neither depends on
# whether the live tree is already narrowed, so a narrowed tree still gets a live probe and its corpus verdict reads 1.
probe_decl() { # <appended line>
  awk -v a="$1" '{ l = $0; sub(/^[!+]+/, "", l) } l == "core/fixtures/" || l == "core/fixtures" { next } { print }
       END { print a }' "$FXD/inputs.decl" > "$T/fx/inputs.decl"
}
probe_decl core/fixtures/lib/ || exit 2
judge "$T/fx" 2>/dev/null; rc=$?
[ "$rc" -eq 1 ] || { echo "PROBE DEAD: a lib/-only declaration was not refused (rc $rc)" >&2; exit 2; }
probe_decl core/fixtures/ || exit 2
judge "$T/fx" 2>/dev/null; rc=$?
[ "$rc" -eq 0 ] || { echo "PROBE DEAD: the core/fixtures/ copy did not pass (rc $rc)" >&2; exit 2; }

judge; rc=$?
[ "$rc" -eq 0 ] && exit 0
[ "$rc" -eq 1 ] && exit 1
exit 2
