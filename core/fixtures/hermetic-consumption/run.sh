#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# Exercise scripts/validate-hermetic-consumption.sh -- a shipped fixture's REQUIRED (`!`) input
# must emit its HERMETIC-CONSUMED sentinel in the consumer layout, not only in the distribution
# layout.
#
# THIS FIXTURE IS THE ONLY THING THAT RUNS THE VALIDATOR AT A PUSH. It is not an arm in the
# enforcement map and no hook calls it, so if this fixture stops scanning the real corpus the
# binding is prose. Arm C runs it over the real `core/fixtures/` and derives the scanned count
# independently.
#
# SEEDS COME FROM THE REAL PRODUCER. Every world below is built by editing a copy of the shipped
# `consumer-machinery-inventory/run.sh` -- the fixture that shipped this defect -- at anchors
# asserted unique, never from text written to match the validator's grammar. Each world holds
# TWO fixtures, a quiet one first (`extract-push-flag-decision`, copied unchanged) and the
# subject second, so a scan that judged only the first member cannot pass a firing world.
#
#   c   the real corpus: exit 0, `self-probe: ok`, `scanned=` equal to this fixture's own
#       count of shipped dirs whose inputs.decl has a `!` line, `flagged=0`
#   w1  fix A (the consumer branch echoes its consumer path)             -> exit 0, flagged=0
#   w2  fix B (the declared spelling after the chain's fi)              -> exit 0, flagged=0
#   w3  the consumer-branch echo removed (the shipped defect)            -> exit 1, names it
#   w4  the consumer-branch echo spelled `.bak` (a near-miss path)       -> exit 1, names it
#   w5  the consumer echo moved ABOVE the resolution, top of file       -> exit 1, names it
#   w6  the only sentinel moved into the override branch                -> exit 1, names it
#   w7  w3 plus a `.dist-only` marker on the subject                    -> exit 0, scanned=1
#   w8  no shipped fixture marks an input `!`                           -> exit 2, zero scanned
#   k   the unmutated copy over w1, in the mutants' harness             -> exit 0, `self-probe: ok`
#   m1  the self-probe call removed            -> the `self-probe: ok` line must VANISH (c reads it)
#   m2  the whole-token compare relaxed to a prefix (the near-miss check removed)
#                                              -> exit 2, the probe names its `.bak` seed
#   m3  widened to key every decl line, not only `!` lines
#                                              -> exit 2, the probe names its non-`!` seed
#   m4  the after-`fi` position check removed (any depth-0 sentinel accepted)
#                                              -> exit 2, the probe names its top-of-file seed
#   m5  m1 and m2 together -- the probe gone AND the near-miss relaxed
#                                              -> w4 must read exit 0: the seeded corpus alone
#                                                 cannot tell this mutant from the original
#                                                 unless a world carries the near-miss, and w4 does
#
# m5 IS WHY THE SEEDED WORLDS EXIST BESIDE THE SELF-PROBE. With the probe gone, the only thing
# between a relaxed compare and a green run is a corpus world holding the near-miss; m5 asserts
# that w4's world reads differently under it, so w4 is load-bearing and not a restatement of the
# probe.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

# Both layouts named, never a single walk-up (I33c). The subject is distribution-only.
ROOT=""
for cand in "$DIR/../../.." "$DIR/../.."; do
  if [ -f "$cand/scripts/validate-hermetic-consumption.sh" ] && [ -f "$cand/VERSION" ]; then
    ROOT="$(cd "$cand" && pwd)"; break
  fi
done
[ -n "$ROOT" ] || { echo "FIXTURE ERROR: could not locate scripts/validate-hermetic-consumption.sh from $DIR" >&2; exit 2; }
VALIDATOR="$ROOT/scripts/validate-hermetic-consumption.sh"
echo "HERMETIC-CONSUMED scripts/validate-hermetic-consumption.sh"
CP="$ROOT/core/scripts/core-paths.sh"
PROD="$ROOT/core/fixtures/consumer-machinery-inventory"
QUIET="$ROOT/core/fixtures/extract-push-flag-decision"
for f in "$CP" "$PROD/run.sh" "$PROD/inputs.decl" "$QUIET/run.sh" "$QUIET/inputs.decl"; do
  [ -f "$f" ] || { echo "FIXTURE ERROR: $f not found -- no world can be seeded from the real producer" >&2; exit 2; }
done

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
rc=0
ok()  { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*"; rc=1; }

# The producer's lines, as the shipped file carries them.
CE='  echo "HERMETIC-CONSUMED core/scripts/validate-layer-entries.sh"'
UE='  echo "HERMETIC-CONSUMED scripts/ai-dlc/validate-layer-entries.sh"'
OV='  VAL="${AI_DLC_CMI_VALIDATOR}"'
SETU='set -uo pipefail'
ERRL='validate-layer-entries.sh not found in either layout'

# edit <src> <dst> <op> <anchor> [text] -- one exact-line edit of a copy. ops: del, repl, after,
# afterfi (insert after the first `fi` that follows the line CONTAINING the anchor). The anchor
# must occur exactly once and the copy must differ, or the world is refused as broken.
edit() {
  local src="$1" dst="$2" op="$3" an="$4" tx="${5:-}" n
  if [ "$op" = afterfi ]; then n="$(grep -cF -e "$an" "$src")" || n=0
  else n="$(grep -cxF -e "$an" "$src")" || n=0; fi
  [ "$n" = "1" ] || { echo "FIXTURE BROKEN: anchor matches $n lines, not 1, in $src: $an" >&2; return 2; }
  awk -v op="$op" -v an="$an" -v tx="$tx" '
    op == "afterfi" { print; if (index($0, an) > 0) seen = 1; else if (seen == 1 && $0 == "fi") { print tx; seen = 2 }; next }
    $0 == an && op == "del" { next }
    $0 == an && op == "repl" { print tx; next }
    $0 == an && op == "after" { print; print tx; next }
    { print }' "$src" > "$dst" || return 2
  cmp -s "$src" "$dst" && { echo "FIXTURE BROKEN: edit $op did not change $src" >&2; return 2; }
  return 0
}

# variant <name> <dst run.sh> -- the subject's run.sh for one world.
variant() {
  local v="$1" d="$2" t="$TMP/v.$$.$1"
  case "$v" in
    fixa)     cp "$PROD/run.sh" "$d" ;;
    base)     edit "$PROD/run.sh" "$d" del "$UE" ;;
    bak)      edit "$PROD/run.sh" "$d" repl "$UE" '  echo "HERMETIC-CONSUMED scripts/ai-dlc/validate-layer-entries.sh.bak"' ;;
    top)      edit "$PROD/run.sh" "$t" del "$UE" && edit "$t" "$d" after "$SETU" 'echo "HERMETIC-CONSUMED scripts/ai-dlc/validate-layer-entries.sh"' ;;
    override) edit "$PROD/run.sh" "$t" del "$UE" && edit "$t" "$t.2" del "$CE" && edit "$t.2" "$d" after "$OV" "$CE" ;;
    fixb)     edit "$PROD/run.sh" "$t" del "$UE" && edit "$t" "$t.2" del "$CE" && edit "$t.2" "$d" afterfi "$ERRL" 'echo "HERMETIC-CONSUMED core/scripts/validate-layer-entries.sh"' ;;
    *) return 2 ;;
  esac
}

# world <dir> <validator src> <variant|none> [dist-only] -- a mini distribution: VERSION, the mapper,
# the validator copy, the quiet fixture first and the subject second.
world() {
  local w="$1" vs="$2" v="$3" mark="${4:-}"
  mkdir -p "$w/scripts" "$w/core/scripts" "$w/core/fixtures/a-quiet" "$w/core/fixtures/b-subject" || return 2
  echo "0.0.0" > "$w/VERSION"
  cp "$CP" "$w/core/scripts/core-paths.sh" || return 2
  cp "$vs" "$w/scripts/validate-hermetic-consumption.sh" || return 2
  cp "$QUIET/run.sh" "$QUIET/inputs.decl" "$w/core/fixtures/a-quiet/" || return 2
  if [ "$v" = none ]; then
    grep -v '^!' "$QUIET/inputs.decl" > "$w/core/fixtures/a-quiet/inputs.decl"
    grep -v '^!' "$PROD/inputs.decl" > "$w/core/fixtures/b-subject/inputs.decl"
    cp "$PROD/run.sh" "$w/core/fixtures/b-subject/run.sh"
  else
    cp "$PROD/inputs.decl" "$w/core/fixtures/b-subject/inputs.decl" || return 2
    variant "$v" "$w/core/fixtures/b-subject/run.sh" || return 2
  fi
  [ "$mark" != dist-only ] || printf '%s\n' 'seeded: not shipped' > "$w/core/fixtures/b-subject/.dist-only"
  return 0
}

# drive <dir> -- runs the world's own validator copy; sets OUT and RC.
drive() { OUT="$(bash "$1/scripts/validate-hermetic-consumption.sh" 2>&1)"; RC=$?; }
summary_has() { grep -q "^hermetic-consumption: .*$1" <<< "$OUT"; }
names_subject() { grep -q '^FAIL: core/fixtures/b-subject: REQUIRED input core/scripts/validate-layer-entries.sh ' <<< "$OUT"; }

echo "== c: the real corpus"
want="$(cd "$ROOT/core/fixtures" && n=0 && for d in */; do d="${d%/}"; [ -f "$d/.dist-only" ] && continue; [ -f "$d/inputs.decl" ] && grep -q '^!' "$d/inputs.decl" && n=$((n + 1)); done; echo "$n")"
OUT="$(bash "$VALIDATOR" 2>&1)"; RC=$?
case "$want" in ''|0|*[!0-9]*) bad "c: this fixture derived '$want' shipped \`!\` fixtures -- the derivation is broken, so nothing below means anything" ;; esac
if [ "$RC" = 0 ] && grep -q '^self-probe: ok' <<< "$OUT" && summary_has "scanned=$want " && summary_has 'flagged=0$'; then
  ok "c: the real corpus is clean, the self-probe ran, and scanned=$want matches this fixture's own count"
else
  bad "c: want exit 0, a self-probe line, scanned=$want and flagged=0; got exit $RC: $(printf '%s\n' "$OUT" | tail -3 | tr '\n' '|')"
fi

echo "== W: seeded worlds from the real producer"
w() { # w <id> <variant> <want rc> <want subject named: y|n> <want scanned> [dist-only]
  local id="$1" v="$2" wr="$3" wn="$4" ws="$5" mk="${6:-}" d="$TMP/w.$1" named=n
  world "$d" "$VALIDATOR" "$v" "$mk" || { bad "$id: FIXTURE BROKEN -- world $v could not be built"; return; }
  drive "$d"
  names_subject && named=y
  if [ "$RC" = "$wr" ] && [ "$named" = "$wn" ] && summary_has "scanned=$ws "; then
    ok "$id: $v -> exit $RC, subject named=$named, scanned=$ws"
  else
    bad "$id: $v -> want exit $wr named=$wn scanned=$ws; got exit $RC named=$named: $(printf '%s\n' "$OUT" | tail -2 | tr '\n' '|')"
  fi
}
w w1 fixa     0 n 2
w w2 fixb     0 n 2
w w3 base     1 y 2
w w4 bak      1 y 2
w w5 top      1 y 2
w w6 override 1 y 2
w w7 base     0 n 1 dist-only
d="$TMP/w.w8"
if world "$d" "$VALIDATOR" none; then
  drive "$d"
  if [ "$RC" = 2 ] && grep -q 'zero scanned is a refusal' <<< "$OUT"; then ok "w8: no \`!\` input anywhere -> exit 2, refused as zero scanned"
  else bad "w8: want exit 2 and the zero-scanned refusal; got exit $RC: $(printf '%s\n' "$OUT" | tail -2 | tr '\n' '|')"; fi
else bad "w8: FIXTURE BROKEN -- world could not be built"; fi

echo "== M: mutants of the validator"
# mut <name> <sed program> [<sed program>...] -- a copy of the validator; refused if sed dies or
# changes nothing.
mut() {
  local n="$1" dst="$TMP/mut.$1.sh"; shift
  local args=() e
  for e in "$@"; do args+=(-e "$e"); done
  if ! sed "${args[@]}" "$VALIDATOR" > "$dst"; then echo "MUTANT $n DID NOT APPLY: sed failed" >&2; return 2; fi
  if cmp -s "$VALIDATOR" "$dst"; then echo "MUTANT $n DID NOT APPLY: no change" >&2; return 2; fi
  printf '%s\n' "$dst"
}
M_PROBE='s/^self_probe || {/true || {/'
M_NEAR='s/^function same(tok, p) { return tok == p || tok == p "\/" }$/function same(tok, p) { return index(tok, p) == 1 }/'
M_WIDE="s/^BANG_RE='^!'\$/BANG_RE='^[^#]'/"
M_AFTER='s/sdep\[j\] == 0 \&\& cend\[c\] > 0 \&\& sline\[j\] > cend\[c\]/sdep[j] == 0/g'

# k: the unmutated validator through the same harness, so a harness that cannot run a copy
# reports BROKEN instead of scoring every mutant as a kill.
d="$TMP/m.K"
if world "$d" "$VALIDATOR" fixa; then
  drive "$d"
  if [ "$RC" = 0 ] && grep -q '^self-probe: ok' <<< "$OUT" && summary_has 'scanned=2 '; then ok "k: the unmutated copy runs in the harness (exit 0, probe ok, scanned=2)"
  else bad "k: FIXTURE BROKEN -- the unmutated copy did not run clean in the harness; every mutant verdict below is void: exit $RC $(printf '%s\n' "$OUT" | tail -2 | tr '\n' '|')"; fi
else bad "k: FIXTURE BROKEN -- world could not be built"; fi

# m1: the probe removed. The clean world still reads exit 0 -- that is exactly why c demands the
# probe's own line; here the arm demands that line VANISH, so a mutation that left the probe
# running cannot score.
if m="$(mut m1 "$M_PROBE")"; then
  d="$TMP/m.m1"; world "$d" "$m" fixa && drive "$d"
  if [ "$RC" = 0 ] && ! grep -q '^self-probe: ok' <<< "$OUT" && summary_has 'scanned=2 '; then ok "m1: probe removed -> the self-probe line is gone, which c refuses"
  else bad "m1: want exit 0 with no self-probe line and scanned=2; got exit $RC: $(printf '%s\n' "$OUT" | tail -2 | tr '\n' '|')"; fi
else bad "m1: DID NOT APPLY"; fi

probe_refuses() { # probe_refuses <id> <mutant> <seed>
  local id="$1" m="$2" s="$3" d="$TMP/m.$1"
  world "$d" "$m" fixa && drive "$d"
  if [ "$RC" = 2 ] && grep -q "self-probe: seeded [a-z-]* $s " <<< "$OUT" && ! summary_has 'scanned='; then
    ok "$id: the self-probe refuses, naming its $s seed"
  else bad "$id: want exit 2 and the probe naming $s before any corpus line; got exit $RC: $(printf '%s\n' "$OUT" | tail -3 | tr '\n' '|')"; fi
}
if m="$(mut m2 "$M_NEAR")"; then probe_refuses m2 "$m" d-bak; else bad "m2: DID NOT APPLY"; fi
if m="$(mut m3 "$M_WIDE")"; then probe_refuses m3 "$m" e-non-bang; else bad "m3: DID NOT APPLY"; fi
if m="$(mut m4 "$M_AFTER")"; then probe_refuses m4 "$m" f-top; else bad "m4: DID NOT APPLY"; fi

# m5: probe gone AND near-miss relaxed. w4's world must now read CLEAN, where the original reads
# exit 1 naming the subject (w4 above) -- the two sides are asserted to differ.
if m="$(mut m5 "$M_PROBE" "$M_NEAR")"; then
  d="$TMP/m.m5"; world "$d" "$m" bak && drive "$d"
  if [ "$RC" = 0 ] && ! names_subject && summary_has 'flagged=0$'; then ok "m5: probe gone and compare relaxed -> w4's near-miss world reads clean, so w4 is what holds the compare"
  else bad "m5: want w4's world to read exit 0, flagged=0 under the mutant; got exit $RC: $(printf '%s\n' "$OUT" | tail -2 | tr '\n' '|')"; fi
else bad "m5: DID NOT APPLY"; fi

if [ "$rc" = 0 ]; then echo "hermetic-consumption: PASS"; else echo "hermetic-consumption: FAIL"; fi
exit "$rc"
