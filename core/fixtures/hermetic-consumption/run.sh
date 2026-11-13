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
#   w9  the consumer echo sent to `> /dev/null`                         -> exit 1, names it
#   w10 a trailing space inside the consumer echo's quotes              -> exit 1, names it
#   w11 the consumer echo behind `[ -n "${UNSET:-}" ] &&`               -> exit 1, names it
#   w12 the consumer echo sent `>&2` (the runner captures 2>&1)         -> exit 0, flagged=0
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
#
# Usage: run.sh [--matrix]
#
# THE MUTANT MATRIX (fixture-mutants.md 'One run per distinct state'). The five mutants are scored on five named arms
# (probe-line, bak-seed, nonbang-seed, top-seed over fixa's world; w4 over bak's world; hc_arm below). PER PUSH a
# mutant builds only the world its deciding arm reads, which it must trip, and reads its twin from that same world,
# which it must leave GREEN; `--matrix` builds both worlds and prints `MATRIX <mutant> <arm> TRIPPED|GREEN` for all
# five arms. The rows below are the one source: hc_score reads them from this file. RE-MEASURE whenever an arm or a
# mutant is added or changed, from the repo root:
# MUTANT-MATRIX-REMEASURE bash core/fixtures/hermetic-consumption/run.sh --matrix
# MUTANT-MATRIX m1 decides=probe-line twins=bak-seed
# MUTANT-MATRIX m2 decides=bak-seed twins=top-seed
# MUTANT-MATRIX m3 decides=nonbang-seed twins=bak-seed
# MUTANT-MATRIX m4 decides=top-seed twins=nonbang-seed
# MUTANT-MATRIX m5 decides=w4 twins=- why=w4 is the only arm that reads bak's world, the one world m5 builds per push
# MUTANT-MATRIX-DYNAMIC hc_score why=hc_score passes each of m1-m5 above to mutant_killed as its first argument
set -u
MATRIX=0
for _a in "$@"; do
  case "$_a" in
    --matrix) MATRIX=1 ;;
    *) echo "FIXTURE ERROR: unknown argument '$_a' (only --matrix)" >&2; exit 2 ;;
  esac
done
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
# fx_inproc lives in lib/mutant.sh, which needs ok() and bad() first. A literal-tail path, never `. "$VAR"`: in a
# fixture opted in by an inproc: row, P1 reads an opaque source as a drive.
[ -f "$DIR/../lib/mutant.sh" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $DIR" >&2; exit 2; }
. "$DIR/../lib/mutant.sh" || { echo "FIXTURE ERROR: sourcing lib/mutant.sh failed" >&2; exit 2; }

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
    devnull)  edit "$PROD/run.sh" "$d" repl "$UE" "$UE > /dev/null" ;;
    stderr)   edit "$PROD/run.sh" "$d" repl "$UE" "$UE >&2" ;;
    tspace)   edit "$PROD/run.sh" "$d" repl "$UE" '  echo "HERMETIC-CONSUMED scripts/ai-dlc/validate-layer-entries.sh "' ;;
    andand)   edit "$PROD/run.sh" "$d" repl "$UE" '  [ -n "${AI_DLC_HC_UNSET:-}" ] && echo "HERMETIC-CONSUMED scripts/ai-dlc/validate-layer-entries.sh"' ;;
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
if [ "$RC" = 0 ] && grep -q '^self-probe: ok' <<< "$OUT" && summary_has "scanned=$want " && summary_has 'flagged=0$'; then
  ok "c: the real corpus is clean, the self-probe ran, and scanned=$want matches this fixture's own count"
else
  bad "c: want exit 0, a self-probe line, scanned=$want and flagged=0; got exit $RC: $(printf '%s\n' "$OUT" | tail -3 | tr '\n' '|')"
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
    ok "$id: $v -> exit $RC, subject named=$named, scanned=$ws"; [ "$id" != w4 ] || HC_W4_OK=1
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
w w6 override 1 y 2
w w7 base     0 n 1 dist-only
w w9 devnull  1 y 2
w w10 tspace  1 y 2
w w11 andand  1 y 2
w w12 stderr  0 n 2
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
  if [ "$RC" = 0 ] && grep -q '^self-probe: ok' <<< "$OUT" && summary_has 'scanned=2 '; then ok "k: the unmutated copy runs in the harness (exit 0, probe ok, scanned=2)"; B_K=1
  else bad "k: FIXTURE BROKEN -- the unmutated copy did not run clean in the harness; every mutant verdict below is void: exit $RC $(printf '%s\n' "$OUT" | tail -2 | tr '\n' '|')"; fi
else bad "k: FIXTURE BROKEN -- world could not be built"; fi

# THE MUTANT ARMS, each a reading of ONE world's run of a copy (GREEN = what the unmutated copy shows, k above):
#   probe-line    fixa's world: exit 0, the `self-probe: ok` line, scanned=2
#   bak-seed      fixa's world: the probe names no `d-bak` seed      nonbang-seed  ... no `e-non-bang` seed
#   top-seed      fixa's world: the probe names no `f-top` seed
#   w4            bak's world: exit 1 naming the subject (w4's own reading)
# A mutant's DECIDING arm must be TRIPPED and its twin GREEN; per push a mutant builds only the world its deciding
# arm and twin read, and `--matrix` builds both worlds and prints `MATRIX <mutant> <arm> TRIPPED|GREEN` for all five.
hc_arm() { # hc_arm <arm> -- over the OUT/RC of the world that arm reads
  case "$1" in
    probe-line)   [ "$RC" = 0 ] && grep -q '^self-probe: ok' <<< "$OUT" && summary_has 'scanned=2 ' ;;
    bak-seed)     ! grep -q 'self-probe: seeded [a-z-]* d-bak ' <<< "$OUT" ;;
    nonbang-seed) ! grep -q 'self-probe: seeded [a-z-]* e-non-bang ' <<< "$OUT" ;;
    top-seed)     ! grep -q 'self-probe: seeded [a-z-]* f-top ' <<< "$OUT" ;;
    w4)           [ "$RC" = 1 ] && names_subject ;;
    *) echo "FIXTURE BROKEN: unknown mutant arm $1" >&2; exit 2 ;;
  esac
}
hc_world_of() { case "$1" in w4) echo bak ;; *) echo fixa ;; esac; }
HC_ARMS="probe-line bak-seed nonbang-seed top-seed w4"
mx_row() { grep -m 1 -F -- "# MUTANT-MATRIX $1 decides=" "$DIR/run.sh"; }
mx_field() { local l; l="$(mx_row "$1")"; l="${l#*"$2"=}"; printf '%s' "${l%% *}"; }
# The unmutated copy's reading of every arm, with no new run: the four fixa arms over k's own OUT/RC, still current
# here, and w4 from w4's own verdict in the W section (the shipped validator over bak's world), so a mutant's
# tripped arm is the mutation's.
hc_base=0; hc_held=""
[ "${HC_W4_OK:-0}" = 1 ] && { hc_base=$((hc_base + 1)); hc_held="$hc_held w4"; }
for _a in probe-line bak-seed nonbang-seed top-seed; do hc_arm "$_a" && { hc_base=$((hc_base + 1)); hc_held="$hc_held $_a"; }; done
if [ "$hc_base" -eq 5 ]; then
  ok "baseline (unmutated copy): all five mutant arms hold (${hc_held# }), so a mutant's tripped arm is the mutation's"; B_HCBASE=1
else bad "baseline (unmutated copy): only $hc_base of five mutant arms hold (${hc_held# }) -- every mutant verdict below is void"; fi
HC_CELLS=0
# hc_score <mutant> <copy> <deciding check: a command over OUT/RC> <ok message> <bad message>
hc_score() {
  local n="$1" m="$2" chk="$3" okm="$4" badm="$5" dec tw w a cur="" t
  if [ "$MATRIX" = 1 ]; then
    for w in fixa bak; do
      d="$TMP/m.$n.$w"; world "$d" "$m" "$w" && drive "$d"
      for a in $HC_ARMS; do
        [ "$(hc_world_of "$a")" = "$w" ] || continue
        HC_CELLS=$((HC_CELLS + 1))
        if hc_arm "$a"; then printf '  MATRIX %s %s GREEN\n' "$n" "$a"; else printf '  MATRIX %s %s TRIPPED\n' "$n" "$a"; fi
      done
    done
    return 0
  fi
  [ -n "$(mx_row "$n")" ] || { bad "$n has no MUTANT-MATRIX row in this file -- a per-push run cannot know its deciding arm or its twin"; return 0; }
  dec="$(mx_field "$n" decides)"; tw="$(mx_field "$n" twins)"
  w="$(hc_world_of "$dec")"
  if [ "$tw" != - ] && [ "$(hc_world_of "$tw")" != "$w" ]; then bad "FIXTURE BROKEN: $n's twin $tw reads another world than its deciding arm $dec"; return 0; fi
  d="$TMP/m.$n"; world "$d" "$m" "$w" && drive "$d"
  HC_CELLS=$((HC_CELLS + 1)); [ "$tw" = - ] || HC_CELLS=$((HC_CELLS + 1))
  if hc_arm "$dec" || ! eval "$chk"; then bad "$badm; got exit $RC: $(printf '%s\n' "$OUT" | tail -3 | tr '\n' '|') (deciding arm $dec)"; return 0; fi
  if [ "$tw" != - ] && ! hc_arm "$tw"; then bad "$n also tripped its twin $tw -- the matrix row for this mutant moved; re-measure with --matrix"; return 0; fi
  mutant_killed "$(( ${B_K:-0} && ${B_HCBASE:-0} ))" "$n" "$okm"
}

# m1: the probe removed. The clean world still reads exit 0 -- that is exactly why c demands the
# probe's own line; here the arm demands that line VANISH, so a mutation that left the probe
# running cannot score.
if m="$(mut m1 "$M_PROBE")"; then
  hc_score m1 "$m" '[ "$RC" = 0 ] && ! grep -q "^self-probe: ok" <<< "$OUT" && summary_has "scanned=2 "' \
    "m1: probe removed -> the self-probe line is gone, which c refuses" \
    "m1: want exit 0 with no self-probe line and scanned=2"
else bad "m1: DID NOT APPLY"; fi

probe_refuses() { # probe_refuses <id> <mutant> <seed>
  local id="$1" m="$2" s="$3"
  hc_score "$id" "$m" "[ \"\$RC\" = 2 ] && grep -q \"self-probe: seeded [a-z-]* $s \" <<< \"\$OUT\" && ! summary_has 'scanned='" \
    "$id: the self-probe refuses, naming its $s seed" \
    "$id: want exit 2 and the probe naming $s before any corpus line"
}
if m="$(mut m2 "$M_NEAR")"; then probe_refuses m2 "$m" d-bak; else bad "m2: DID NOT APPLY"; fi
if m="$(mut m3 "$M_WIDE")"; then probe_refuses m3 "$m" e-non-bang; else bad "m3: DID NOT APPLY"; fi
if m="$(mut m4 "$M_AFTER")"; then probe_refuses m4 "$m" f-top; else bad "m4: DID NOT APPLY"; fi

# m5: probe gone AND near-miss relaxed. w4's world must now read CLEAN, where the original reads
# exit 1 naming the subject (w4 above) -- the two sides are asserted to differ.
if m="$(mut m5 "$M_PROBE" "$M_NEAR")"; then
  hc_score m5 "$m" '[ "$RC" = 0 ] && ! names_subject && summary_has "flagged=0$"' \
    "m5: probe gone and compare relaxed -> w4's near-miss world reads clean, so w4 is what holds the compare" \
    "m5: want w4's world to read exit 0, flagged=0 under the mutant"
else bad "m5: DID NOT APPLY"; fi
if [ "$MATRIX" = 1 ]; then
  [ "$HC_CELLS" -eq 25 ] && ok "MX matrix run measured $HC_CELLS mutant x arm cells (5 mutants x 5 arms)" \
    || bad "MX matrix run measured $HC_CELLS cells, 25 expected"
else
  [ "$HC_CELLS" -eq 9 ] && ok "MX matrix, per-push run: $HC_CELLS cells scored, each mutant's deciding arm and its twin only" \
    || bad "MX per-push run scored $HC_CELLS cells, 9 expected"
fi

if [ "$rc" = 0 ]; then echo "hermetic-consumption: PASS"; else echo "hermetic-consumption: FAIL"; fi
exit "$rc"
