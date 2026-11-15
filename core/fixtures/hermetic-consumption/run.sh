#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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
#   c   the real corpus: exit 0, `scanned=` equal to this fixture's own
#       count of shipped dirs whose inputs.decl has a `!` line, `flagged=0`
#   w1  fix A (the consumer branch echoes its consumer path)             -> exit 0, flagged=0
#   w2  fix B (the declared spelling after the chain's fi)              -> exit 0, flagged=0
#   w3  the consumer-branch echo removed (the shipped defect)            -> exit 1, names it
#   w4  the consumer-branch echo spelled `.bak` (a near-miss path)       -> exit 1, names it
#   w5  the consumer echo moved ABOVE the resolution, top of file       -> exit 1, names it
#   w7  w3 plus a `.dist-only` marker on the subject                    -> exit 0, scanned=1
#   w8  no shipped fixture marks an input `!`                           -> exit 2, zero scanned
#   w9  the consumer echo sent to `> /dev/null`                         -> exit 1, names it
#   w10 a trailing space inside the consumer echo's quotes              -> exit 1, names it
#   w11 the consumer echo behind `[ -n "${UNSET:-}" ] &&`               -> exit 1, names it
#   w12 the consumer echo sent `>&2` (the runner captures 2>&1)         -> exit 0, flagged=0
#   w13 e: an UNMARKED input (`core/skills/ai-dlc/`, appended to the subject's inputs.decl) echoed in
#       its core branch only, beside the fixed `!` input -- quiet only because keying is on `!` lines
#                                                                       -> exit 0, flagged=0
#   w14 m: a branch naming the consumer path in a `grep -qF`, not as a file-test operand
#                                                                       -> exit 0, flagged=0
#   w15 o: a second, layout-detecting chain whose sentinel is emitted later through `$LAY`
#                                                                       -> exit 0, flagged=0
#   w16 p: w3 plus a heredoc body after the chain carrying both sentinels at column 0
#                                                                       -> exit 1, names it
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
[ -f "$DIR/../lib/report.sh" ] || { echo "FIXTURE ERROR: lib/report.sh not found beside $DIR" >&2; exit 2; }
. "$DIR/../lib/report.sh" || { echo "FIXTURE ERROR: sourcing lib/report.sh failed" >&2; exit 2; }
# fx_inproc lives in lib/mutant.sh, which needs ok() and bad() first. A literal-tail path, never `. "$VAR"`: in a
# fixture opted in by an inproc: row, P1 reads an opaque source as a drive.
[ -f "$DIR/../lib/mutant.sh" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $DIR" >&2; exit 2; }
. "$DIR/../lib/mutant.sh" || { echo "FIXTURE ERROR: sourcing lib/mutant.sh failed" >&2; exit 2; }

# The producer's lines, as the shipped file carries them.
CE='  echo "HERMETIC-CONSUMED core/scripts/validate-layer-entries.sh"'
UE='  echo "HERMETIC-CONSUMED scripts/ai-dlc/validate-layer-entries.sh"'
SETU='set -uo pipefail'
ERRL='validate-layer-entries.sh not found in either layout'
SKC='  SRC="$ROOT/core/skills/ai-dlc"'

# edit <src> <dst> <op> <anchor> [text] -- one exact-line edit of a copy. ops: del, repl, after,
# afterfi (insert after the first `fi` that follows the line CONTAINING the anchor). The anchor
# must occur exactly once and the copy must differ, or the world is refused as broken. The text
# reaches awk through ENVIRON, never `-v`, so a multi-line text keeps its newlines and its bytes.
edit() {
  local src="$1" dst="$2" op="$3" an="$4" tx="${5:-}" n
  if [ "$op" = afterfi ]; then n="$(grep -cF -e "$an" "$src")" || n=0
  else n="$(grep -cxF -e "$an" "$src")" || n=0; fi
  [ "$n" = "1" ] || { echo "FIXTURE BROKEN: anchor matches $n lines, not 1, in $src: $an" >&2; return 2; }
  HC_TX="$tx" awk -v op="$op" -v an="$an" '
    BEGIN { tx = ENVIRON["HC_TX"] }
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
    devnull)  edit "$PROD/run.sh" "$d" repl "$UE" "$UE > /dev/null" ;;
    stderr)   edit "$PROD/run.sh" "$d" repl "$UE" "$UE >&2" ;;
    tspace)   edit "$PROD/run.sh" "$d" repl "$UE" '  echo "HERMETIC-CONSUMED scripts/ai-dlc/validate-layer-entries.sh "' ;;
    andand)   edit "$PROD/run.sh" "$d" repl "$UE" '  [ -n "${AI_DLC_HC_UNSET:-}" ] && echo "HERMETIC-CONSUMED scripts/ai-dlc/validate-layer-entries.sh"' ;;
    fixb)     edit "$PROD/run.sh" "$t" del "$UE" && edit "$t" "$t.2" del "$CE" && edit "$t.2" "$d" afterfi "$ERRL" 'echo "HERMETIC-CONSUMED core/scripts/validate-layer-entries.sh"' ;;
    nonbang)  edit "$PROD/run.sh" "$d" after "$SKC" '  echo "HERMETIC-CONSUMED core/skills/ai-dlc"' ;;
    grepq)    edit "$PROD/run.sh" "$d" after "$UE" 'elif grep -qF "scripts/ai-dlc/validate-layer-entries.sh" "$ROOT/manifest.txt"; then
  VAL="$ROOT/manifest.txt"' ;;
    varlater) edit "$PROD/run.sh" "$d" afterfi "$ERRL" 'if [ -f "$ROOT/core/scripts/validate-layer-entries.sh" ]; then
  LAY=core/scripts
elif [ -f "$ROOT/scripts/ai-dlc/validate-layer-entries.sh" ]; then
  LAY=scripts/ai-dlc
fi
echo "HERMETIC-CONSUMED $LAY/validate-layer-entries.sh"' ;;
    heredoc)  edit "$PROD/run.sh" "$t" del "$UE" && edit "$t" "$d" afterfi "$ERRL" 'cat > /dev/null <<EOF
echo "HERMETIC-CONSUMED scripts/ai-dlc/validate-layer-entries.sh"
echo "HERMETIC-CONSUMED core/scripts/validate-layer-entries.sh"
EOF' ;;
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
  # nonbang's unmarked input: its directory row is the one path whose consumer location the producer's
  # second chain tests as a file-test operand. Refused if the producer already declares it.
  if [ "$v" = nonbang ]; then
    grep -qxF -e 'core/skills/ai-dlc/' "$PROD/inputs.decl" && { echo "FIXTURE BROKEN: $PROD/inputs.decl already declares core/skills/ai-dlc/" >&2; return 2; }
    printf '%s\n' 'core/skills/ai-dlc/' >> "$w/core/fixtures/b-subject/inputs.decl" || return 2
  fi
  [ "$mark" != dist-only ] || printf '%s\n' 'seeded: not shipped' > "$w/core/fixtures/b-subject/.dist-only"
  return 0
}

# IN PROCESS (BL-878). drive SOURCES the world's own validator copy once into this shell (its guard returns after
# defining vhc_main; one fx_inproc pass per world) and calls vhc_main in the `$( )` that captures it, so its `exit`,
# EXIT trap and LC_ALL stay there. Inside vhc_main BASH_SOURCE[0] is that copy, so its VERSION walk-up finds the
# world, exactly as running the copy did. drive runs in this shell, never inside a `$( )`, so a failed source is
# FIXTURE BROKEN and never reads as the copy's own exit. Every copy sits at <world>/scripts/<name>, the subject's
# relative path, so each pass is counted under the inproc: row.
VHC_SOURCED=""
src_vhc() { # src_vhc <copy>
  unset -f vhc_main
  fx_inproc "$1"
  . "$1" || { echo "FIXTURE BROKEN: sourcing $1 failed" >&2; exit 2; }
  declare -F vhc_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $1 defined no vhc_main" >&2; exit 2; }
  VHC_SOURCED="$1"
}
# drive <dir> -- runs the world's own validator copy in process; sets OUT and RC.
drive() { src_vhc "$1/scripts/validate-hermetic-consumption.sh"; OUT="$(vhc_main 2>&1)"; RC=$?; }

# --- the cli cells (cells.decl): the validator run as a PROGRAM once per distinct CLI outcome -----------------
# Outcomes, by exit: 0 clean (cli-pass, over w1's world), 1 a finding naming the subject (cli-finding, over w3's
# world), 2 a usage refusal (cli-usage, the shipped validator given an unknown argument; its usage line names the
# program through BASH_SOURCE[0], so this cell is the proof of the $0 port). One `FXCELL=<id> bash <copy>` start
# each, compared byte for byte (stdout, stderr, exit) with vhc_main of the SAME copy, sourced last, called in process.
EQ="$TMP/eq"; mkdir -p "$EQ"
eqv() { # eqv <cell-id> <copy> <args...> -- <copy> must be the copy src_vhc sourced last
  local id="$1" c="$2"; shift 2
  [ "$c" = "$VHC_SOURCED" ] || { echo "FIXTURE BROKEN: cli cell $id against $c while ${VHC_SOURCED:-nothing} is sourced" >&2; exit 2; }
  ( vhc_main "$@" ) > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" bash "$c" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_rc() { cat "$EQ/$1.cl.rc"; }
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(tail -c 300 "$EQ/$1.ip.out")" "$(tail -c 300 "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(tail -c 300 "$EQ/$1.cl.out")" "$(tail -c 300 "$EQ/$1.cl.err")"; }
summary_has() { grep -q "^hermetic-consumption: .*$1" <<< "$OUT"; }
names_subject() { grep -q '^FAIL: core/fixtures/b-subject: REQUIRED input core/scripts/validate-layer-entries.sh ' <<< "$OUT"; }

echo "== c: the real corpus"
want="$(cd "$ROOT/core/fixtures" && n=0 && for d in */; do d="${d%/}"; [ -f "$d/.dist-only" ] && continue; [ -f "$d/inputs.decl" ] && grep -q '^!' "$d/inputs.decl" && n=$((n + 1)); done; echo "$n")"
src_vhc "$VALIDATOR"
OUT="$(vhc_main 2>&1)"; RC=$?
case "$want" in ''|0|*[!0-9]*) bad "c: this fixture derived '$want' shipped \`!\` fixtures -- the derivation is broken, so nothing below means anything" ;; esac
if [ "$RC" = 0 ] && summary_has "scanned=$want " && summary_has 'flagged=0$'; then
  ok "c: the real corpus is clean, and scanned=$want matches this fixture's own count"
else
  bad "c: want exit 0, scanned=$want and flagged=0; got exit $RC: $(printf '%s\n' "$OUT" | tail -3 | tr '\n' '|')"
fi
if eqv cli-usage "$VALIDATOR" --no-such-arg && [ "$(eq_rc cli-usage)" = 2 ] && [ ! -s "$EQ/cli-usage.cl.out" ] \
   && [ "$(cat "$EQ/cli-usage.cl.err")" = "usage: validate-hermetic-consumption.sh [--quiet]" ]; then
  ok "cli-usage: the program refuses an unknown argument exactly as the in-process call does, naming itself (stderr, exit 2)"
else bad "cli-usage: the program and the in-process call differ, or the outcome is not exit 2 with its own usage line ($(eq_twin cli-usage))"; fi

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
if eqv cli-pass "$TMP/w.w1/scripts/validate-hermetic-consumption.sh" && [ "$(eq_rc cli-pass)" = 0 ] \
   && grep -q '^hermetic-consumption: .*flagged=0$' "$EQ/cli-pass.cl.out"; then
  ok "cli-pass: the program reads w1's world clean exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-pass: the program and the in-process call differ, or the outcome is not exit 0 with flagged=0 ($(eq_twin cli-pass))"; fi
w w2 fixb     0 n 2
w w3 base     1 y 2
if eqv cli-finding "$TMP/w.w3/scripts/validate-hermetic-consumption.sh" && [ "$(eq_rc cli-finding)" = 1 ] \
   && grep -q '^FAIL: core/fixtures/b-subject: REQUIRED input core/scripts/validate-layer-entries.sh ' "$EQ/cli-finding.cl.err"; then
  ok "cli-finding: the program names w3's subject exactly as the in-process call does (stdout, stderr, exit 1)"
else bad "cli-finding: the program and the in-process call differ, or the outcome is not exit 1 naming the subject ($(eq_twin cli-finding))"; fi
if ! cmp -s "$EQ/cli-pass.cl.rc" "$EQ/cli-finding.cl.rc" && ! cmp -s "$EQ/cli-finding.cl.rc" "$EQ/cli-usage.cl.rc" \
   && ! cmp -s "$EQ/cli-pass.cl.err" "$EQ/cli-finding.cl.err"; then
  ok "cli cells discriminate: pass, finding and usage exit 0, 1 and 2, and only the finding names the subject on stderr"
else bad "cli cells do not discriminate: two of cli-pass, cli-finding, cli-usage share an exit, or pass and finding share stderr"; fi
w w4 bak      1 y 2
w w5 top      1 y 2
w w7 base     0 n 1 dist-only
w w9 devnull  1 y 2
w w10 tspace  1 y 2
w w11 andand  1 y 2
w w12 stderr  0 n 2
w w13 nonbang 0 n 2
w w14 grepq   0 n 2
w w15 varlater 0 n 2
w w16 heredoc 1 y 2
d="$TMP/w.w8"
if world "$d" "$VALIDATOR" none; then
  drive "$d"
  if [ "$RC" = 2 ] && grep -q 'zero scanned is a refusal' <<< "$OUT"; then ok "w8: no \`!\` input anywhere -> exit 2, refused as zero scanned"
  else bad "w8: want exit 2 and the zero-scanned refusal; got exit $RC: $(printf '%s\n' "$OUT" | tail -2 | tr '\n' '|')"; fi
else bad "w8: FIXTURE BROKEN -- world could not be built"; fi

report_end hermetic-consumption 20
