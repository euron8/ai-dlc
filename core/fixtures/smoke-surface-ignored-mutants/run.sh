#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# smoke-surface-ignored-mutants/run.sh -- the MUTATION BATTERY behind smoke-surface-ignored, the shipped fixture for
# BL-845's SMOKE-SURFACE-IGNORED arm of validate-handoff-evidence.sh. Distribution-only (its .dist-only says why): every
# mutant edits a copy of core's own validator.
#
# THE ARMS ARE THE SHIPPED FIXTURE'S. This file SOURCES smoke-surface-ignored/run.sh, whose BASH_SOURCE guard returns
# after it has seeded and checked its worlds and defined runworlds, armfail, ARMS and the control tree ($T, $HECTL);
# nothing about a world or a row is restated here. Each mutant is written beside record-only-diff.sh in that control
# tree, so it finds every sibling the real validator does, and is asked in process (he-inproc.sh's he_run).
# The unmutated arms run once here first, as the control: each sets its B_ flag only in its passing branch, and a mutant
# is scored only through mutant_killed on that flag.
#
# THE MUTANT MATRIX. Each mutant runs on its deciding arm and its twin; the twin must stay green, the deciding arm must
# fail. The full mutant x arm matrix is printed by `--matrix` (one MATRIX row per cell, fails=yes|no). The matrix
# is re-measured as .claude/rules/fixture-mutants.md clause 2 ("One run per distinct state") requires.
# Measured (--matrix): forced-true, forced-false, frozen-set and init-below-smoke trip all seven arms; cache-unkeyed
# trips ig-d alone (dF's frozen-first handoff row), v-decides ig-e and ig-g (the neg and dstarn negation worlds), and
# dirs-one-call ig-g alone, through BOTH of its firing worlds (measured with ig-g split in two: dstar trips through the
# trailing slash, deep through the two-path call git refuses with exit 128).
# MUTANT-MATRIX sm-ign-forced-true decides=ig-a twins=- why=every arm trips: a WARN on every absent surface, its provenance never computed
# MUTANT-MATRIX sm-ign-forced-false decides=ig-a twins=- why=every arm carries a firing world, so every arm trips
# MUTANT-MATRIX sm-ign-frozen-set decides=ig-d twins=- why=every arm trips: the WARN text reads a chain scratch never written
# MUTANT-MATRIX sm-ign-cache-unkeyed decides=ig-d twins=ig-a
# MUTANT-MATRIX sm-ign-init-below-smoke decides=ig-a twins=- why=every arm has --smoke rows, and --smoke exits on the unset name
# MUTANT-MATRIX sm-ign-v-decides decides=ig-e twins=ig-a
# MUTANT-MATRIX sm-ign-dirs-one-call decides=ig-g twins=ig-a
# MUTANT-MATRIX-DYNAMIC mscore why=each name reaches mutant_killed as mscore's literal first argument, rowed above
# MUTANT-MATRIX-REMEASURE bash core/fixtures/smoke-surface-ignored-mutants/run.sh --matrix
#
# Exit: 0 every arm and every mutant passed, 1 one did not, 2 the fixture could not run.
set -uo pipefail
MDIR="$(cd "$(dirname "$0")" && pwd)"
MATRIX=0; [ "${1:-}" = --matrix ] && MATRIX=1
SSI="$MDIR/../smoke-surface-ignored/run.sh"
[ -f "$SSI" ] || { echo "smoke-surface-ignored-mutants: FIXTURE BROKEN -- $SSI is absent, so there are no arms to score a mutant against" >&2; exit 2; }
# shellcheck source=/dev/null
. "$SSI" || { echo "smoke-surface-ignored-mutants: FIXTURE BROKEN -- sourcing smoke-surface-ignored/run.sh failed" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/smoke-surface-ignored/run.sh"
# mutant.sh needs ok() and bad(), which the sourced file defines.
MUT_LIB="$MDIR/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "smoke-surface-ignored-mutants: FIXTURE BROKEN -- lib/mutant.sh is absent" >&2; exit 2; }
# shellcheck source=/dev/null
. "$MUT_LIB" || exit 2
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
# The sourced file must have handed over its arms and its control tree; an empty ARMS scores nothing.
{ [ -n "${ARMS:-}" ] && [ -f "${HECTL:-}" ] && [ -f "$T/scripts/record-only-diff.sh" ] && declare -F armfail >/dev/null && declare -F runworlds >/dev/null; } \
  || { echo "smoke-surface-ignored-mutants: FIXTURE BROKEN -- smoke-surface-ignored/run.sh did not define its arms, armfail/runworlds or the control tree" >&2; exit 2; }

# mkmut <name> <from> <to> [<from2> <to2>] -> path of the mutant, written beside record-only-diff.sh in the control
# tree; each literal replaced at its FIRST occurrence and guarded by cmp -s (a literal that matched nothing is an error).
mkmut() {
  local m="$T/scripts/he-mut-$1.sh" src="$HECTL"
  FROM="$2" TO="$3" awk 'BEGIN{f=ENVIRON["FROM"]; t=ENVIRON["TO"]} !done && (p=index($0,f)) {$0=substr($0,1,p-1) t substr($0,p+length(f)); done=1} {print}' "$src" > "$m.tmp"
  cmp -s "$src" "$m.tmp" && { rm -f "$m.tmp"; return 1; }
  if [ -n "${4:-}" ]; then
    FROM="$4" TO="$5" awk 'BEGIN{f=ENVIRON["FROM"]; t=ENVIRON["TO"]} !done && (p=index($0,f)) {$0=substr($0,1,p-1) t substr($0,p+length(f)); done=1} {print}' "$m.tmp" > "$m.tmp2"
    cmp -s "$m.tmp" "$m.tmp2" && { rm -f "$m.tmp" "$m.tmp2"; return 1; }
    mv "$m.tmp2" "$m.tmp"; rm -f "$m.tmp2"
  fi
  mv "$m.tmp" "$m" && printf '%s\n' "$m"
}
# The seven mutants: name, then the from/to literal pairs.
mut_spec() {
  case "$1" in
    sm-ign-forced-true)  MS1='if ignored_at_rev "$srev" "$SMOKE_SURFACE"; then'; MT1='if true; then'; MS2=''; MT2='' ;;
    sm-ign-forced-false) MS1='if ignored_at_rev "$srev" "$SMOKE_SURFACE"; then'; MT1='if false; then'; MS2=''; MT2='' ;;
    sm-ign-frozen-set)   MS1='have="" sub="chain-$1"'; MT1='have="" sub="chain-$1"; ignored_at_frozen "$2"; return'; MS2=''; MT2='' ;;
    # One scratch dir for every rev (the IGN_DIR trap): only the frozen-first handoff row of dF can see it.
    sm-ign-cache-unkeyed) MS1='have="" sub="chain-$1"'; MT1='have="" sub="full"'; MS2='sub="chain-$2"'; MT2='sub="full"' ;;
    # B1: the chain state initialised below the --smoke block, so set -u exits --smoke and handoff still passes.
    sm-ign-init-below-smoke) MS1='IGN_CHAIN=" "'; MT1=':'; MS2='GATE2=0'; MT2='GATE2=0; IGN_CHAIN=" "' ;;
    sm-ign-v-decides)    MS1='ign_ask "$sub" -q -- "$p"'; MT1='ign_ask "$sub" -v -- "$p" >/dev/null'; MS2=''; MT2='' ;;
    # Both layers of the excluded-ancestor walk reverted: every ancestor in ONE -q call, each with a trailing slash.
    sm-ign-dirs-one-call) MS1='mkdir -p "$IGN_ROOT/$sub/$d" 2>/dev/null; if ign_ask "$sub" -q -- "$d"; then dirs=1; break; fi ;;'; MT1='dirs="$dirs$TAB$d/" ;;'
                          MS2='if [ -n "$dirs" ]; then'; MT2='if [ -n "$dirs" ] && (IFS="$TAB"; set -f; ign_ask "$sub" -q -- ${dirs#"$TAB"}); then' ;;
  esac
}
MUTANTS="sm-ign-forced-true sm-ign-forced-false sm-ign-frozen-set sm-ign-cache-unkeyed sm-ign-init-below-smoke sm-ign-v-decides sm-ign-dirs-one-call"

if [ "$MATRIX" = 1 ]; then
  runworlds "$HECTL" $ARMS
  for a in $ARMS; do [ -z "$(armfail "$a")" ] || { echo "MATRIX BROKEN: the unmutated $a fails" >&2; exit 2; }; done
  for mu in $MUTANTS; do
    mut_spec "$mu"; m="$(mkmut "$mu" "$MS1" "$MT1" "$MS2" "$MT2")" || { echo "MATRIX BROKEN: $mu matched nothing" >&2; exit 2; }
    runworlds "$m" $ARMS; tripped=""
    for a in $ARMS; do
      if [ -n "$(armfail "$a")" ]; then echo "MATRIX $mu $a fails=yes"; tripped="$tripped $a"; else echo "MATRIX $mu $a fails=no"; fi
    done
    echo "MATRIX-ROW $mu tripped=[${tripped# }]"
  done
  exit 0
fi

echo "smoke-surface-ignored-mutants:"
runworlds "$HECTL" $ARMS
for a in $ARMS; do
  f="$(armfail "$a")"
  if [ -z "$f" ]; then
    # The arm's baseline flag, set only in its passing branch; mscore's callers pass these and nothing else.
    case "$a" in ig-a) B_ig_a=1 ;; ig-c) B_ig_c=1 ;; ig-d) B_ig_d=1 ;; ig-e) B_ig_e=1 ;; ig-f) B_ig_f=1 ;; ig-u) B_ig_u=1 ;; ig-g) B_ig_g=1 ;; esac
    ok "$a: the unmutated validator answers every row of $(armworlds "$a" | tr ' ' '+')"
  else bad "$a: the unmutated validator: $(tr '\n' ' ' <<<"$f")"; fi
done
# mscore <name> <deciding arm> <twin arm> <base flag> <label>: the deciding arm must fail under the mutant and the twin
# stay green. <base flag> is the deciding arm's B_ flag, times the twin's when there is one.
mscore() {
  local mu="$1" dec="$2" tw="$3" base="$4" m fd ft
  mut_spec "$mu"
  m="$(mkmut "$mu" "$MS1" "$MT1" "$MS2" "$MT2")" || { bad "FIXTURE ERROR: mutation '$mu' matched nothing"; return; }
  # A twin of `-` (the matrix row's twins=-): every arm trips under that mutant, so no arm can stand green beside it.
  if [ "$tw" = - ]; then runworlds "$m" "$dec"; ft=""; else runworlds "$m" "$dec" "$tw"; ft="$(armfail "$tw")"; fi
  fd="$(armfail "$dec")"
  if [ -n "$ft" ]; then bad "MUTATION '$mu' moved its twin $tw: $(tr '\n' ' ' <<<"$ft")"
  elif [ -n "$fd" ]; then mutant_killed "$base" "$mu" "MUTATION '$mu' failed $dec ($(wc -l <<<"$fd" | tr -d ' ') row(s)), twin $tw: $5"
  else bad "MUTATION '$mu' SURVIVED: $dec did not fail -- $5"; fi
}
mscore sm-ign-forced-true ig-a - "${B_ig_a:-0}" "the ignored predicate forced true, so a surface no .gitignore matches WARNs"
mscore sm-ign-forced-false ig-a - "${B_ig_a:-0}" "the ignored predicate forced false, so an ignored surface is the silent SKIP again"
mscore sm-ign-frozen-set ig-d - "${B_ig_d:-0}" "the surface asked of <frozen>'s ignore set, so the verdict follows frozen in both orders"
mscore sm-ign-cache-unkeyed ig-d ig-a "$(( ${B_ig_d:-0} && ${B_ig_a:-0} ))" "the ignore cache shared across revs, so frozen's docs/.gitignore answers for base"
mscore sm-ign-init-below-smoke ig-a - "${B_ig_a:-0}" "the ignore state initialised below the --smoke block, so --smoke exits on an unset name"
mscore sm-ign-v-decides ig-e ig-a "$(( ${B_ig_e:-0} && ${B_ig_a:-0} ))" "check-ignore -v decides, which answers 0 on a negation match"
mscore sm-ign-dirs-one-call ig-g ig-a "$(( ${B_ig_g:-0} && ${B_ig_a:-0} ))" "every ancestor asked in one -q call with a trailing slash, so docs/* reads as an excluded directory and a two-level chain as none"
if [ "$rc" = 0 ]; then echo "PASS smoke-surface-ignored-mutants"; else echo "FAIL smoke-surface-ignored-mutants"; fi
exit "$rc"
