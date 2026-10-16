#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# adversarial-shard-merge-mutants/run.sh -- the mutation battery behind `adversarial-shard-merge`.
# DISTRIBUTION-ONLY (see .dist-only).
#
# Usage: run.sh [--group <shard>] [--rows <file>]
#        --group run only the mutants dealt to <shard> (default a); see THE SHARDS below.
#        --rows  append one `<label>TAB<killed set>` row per scored mutant, in dispatch order, the
#                killed set in P_ALL order and space-joined (empty for a mutant that killed nothing).
# Exit:  0 = every mutant killed exactly its expected set and the control killed nothing,
#        1 = an assertion failed, 2 = fixture broken.
#
# WHY THIS IS SPLIT OUT. Held inside the shipped fixture, `score()` ran every predicate for every
# mutant -- arms x mutants, serially -- and the BL-460/461 arms took the fixture from 317 to 354
# CPU-seconds solo, projecting it past the suite pole. The battery mutates copies of core's own
# `merge-adversarial-shards.sh` and its siblings, which a consumer is denied editing, so proving
# the arms can fail is a question about files only this repository changes. The consumer keeps
# every behavioural arm.
#
# ONE COPY OF THE PREDICATES. Both fixtures source `adversarial-shard-merge/lib.sh`, so a mutant
# is scored by the very predicate bodies the shipped arms run. The join J1 asserts the shipped
# fixture's `p_<name> "$MERGE"` arm calls and P_ALL are the same set, so a predicate added to one
# and not the other cannot leave an arm unproven or a mutant scored against an arm nobody runs.
#
# SCORED IN PARALLEL, AND THE SILENT LOSS IS THE FAILURE MODE THIS SHAPE HAS TO CLOSE. A pool that
# drops a scorer reports fewer verdicts, and fewer verdicts read exactly like fewer failures. So:
#   - each scorer runs in its own subshell under `$WORK/mut-<id>/`, with WORK and every fixed
#     scratch path (`bind_scratch`: MO, CO) rebound there, and RC its own;
#   - it writes ONE verdict file, temp-then-mv, carrying the number of predicates it evaluated;
#   - the mutants DECLARED in this file are dealt across the shards and joined before dispatch
#     ([J0], below), and the number this shard reaches, dispatches and judges must each equal the
#     number dealt to it ([J2]), so an emptied battery FAILS rather than printing PASS over nothing;
#   - `judge` treats a missing verdict, a TIMEOUT, or an evaluated count other than |P_ALL| as a
#     FAIL, and is itself probed every run, on a real verdict file, in both directions.
# The pool is a FIXED width of 8 (no knob); completion is read from sentinel files the scorers
# write, never from the process table.
#
# THE WATCHDOG. bash 3.2 has no `wait -n`, so each scorer runs under a slot that polls it and,
# past SCORER_BOUND seconds, writes a TIMEOUT marker and kills the scorer's whole process tree
# (stopped first, then children before parents, so nothing reparents to init and keeps spinning).
# One scoring is |P_ALL| predicates (32 since the cross groups), about 22 CPU-seconds solo at 26;
# a unit under the gate's pool has measured 4x its solo time, and 900s is roughly 10x that figure.
#
# THE SHARDS. The pre-push suite is POLE-BOUND: its makespan tracks its single longest DIRECTORY.
# Unsharded, this battery ran 326s solo and 1043s loaded, the suite's second-highest pole, before
# the derived-dispatch-id mutants (TM1-TM6) and their ten predicates were added. So the mutant set
# is dealt across six units, this directory (shard a) and the one-line drivers
# `adversarial-shard-merge-mutants-b` .. `-f`, each `exec bash "$IMPL" --group <x>`, the shape
# `remediator-shard-join-mutants` carries. Every scorer runs every predicate, so a mutant's cost is
# roughly uniform, and the pool is 8 wide: a shard of at most 7 mutants plus the control is ONE
# wave of scorers, so the deal is 7, 7, 7, 6, 6, 5 in declaration order by family. Shard f carries
# the basename, probe-over-meta, two-role and --rerun mutants (TM7-TM9, RM1-RM2), added with six
# predicates that raised every scorer's cost, so they are a unit of their own, not a second wave. The
# BL-536 mutants (RM3, TM10-TM13) are dealt by measured COST, not count. Per-shard CPU at 07dfcbfa
# (loaded, load ~30-37), divided by that shard's scorers (mutants + control) gives a per-scorer
# cost: a 1320/8=165, b 1329/8=166, c 1165/8=146, d 1130/7=161, e 1158/7=165, f 1046/6=174. Each new
# mutant goes to the shard whose projected CPU (its CPU plus its per-scorer cost per added mutant) is
# lowest, never to f, whose wall clock was the longest (359s against 180-231s) despite the lowest CPU.
# That gives c+2 (TM11 TM12) -> 1456, d+2 (RM3 TM13) -> 1453, e+1 (TM10) -> 1323, a 1320, b 1329,
# f 1046. c (10 scorers) and d (9) exceed the pool of 8 and so run a second wave. The deal is
# 7, 7, 9, 8, 7, 5. The owner re-times it along with POOL and SCORER_BOUND. Every shard pays
# the unmutated control MX0, the J1 join and the MJ probe itself, because a shard that skipped them
# could report a kill against a harness that never ran. MX6b, an assertion and not a scoring, runs
# in shard a only.
#
# THE SHARD ARRIVES AS AN ARGUMENT, never from the environment: the scrub below unsets AI_DLC_*,
# and a fallback-to-'a' design would run shard a five times and report five green fixtures.
#
# THE COVERAGE JOIN [J0] runs in every shard before any mutant is dispatched: the declared set is
# DERIVED from this file's own `mutant "` lines between the MX markers, the dealt lists must be
# disjoint and their union must equal it exactly, and every declared shard must have a driver
# directory naming it. The join proves it can fire, on a seeded duplicate and a seeded omission,
# before it is trusted. After the reap, [J2] asserts this shard dispatched exactly the mutants dealt
# to it.
SHARDS="a b c d e f"
MUTANTS_a="MX1 MX2 MX3 MX4 MX5 MX6 MX7"
MUTANTS_b="MX8 MX9 MX10 MX11 MX12 MX13 MX14"
MUTANTS_c="MX15 XM1 XM2 XM7 XM8 XM3 XM4 TM11 TM12"
MUTANTS_d="XM5 XM6 SM1 SM2 SM3 SM4 RM3 TM13"
MUTANTS_e="TM1 TM2 TM3 TM4 TM5 TM6 TM10"
MUTANTS_f="TM7 TM8 TM9 RM1 RM2"
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
# lib.sh does not rebind HERE, but SELF is captured now all the same: the coverage join reads the
# DECLARED mutant set from it.
SELF="$HERE/run.sh"
ROWS=""; GROUP=a
USAGE="usage: run.sh [--group <shard>] [--rows <file>]"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --group) GROUP="${2:-}"; [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }; shift 2 ;;
    --rows) ROWS="${2:-}"; [ -n "$ROWS" ] || { echo "$USAGE" >&2; exit 2; }; shift 2 ;;
    *) echo "$USAGE" >&2; exit 2 ;;
  esac
done
case " $SHARDS " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac
eval "MINE=\"\${MUTANTS_$GROUP:-}\""
[ -n "$MINE" ] || { echo "FIXTURE ERROR: shard '$GROUP' has no MUTANTS_$GROUP list; a shard dealt nothing passes everything it never checked" >&2; exit 2; }
NAME="adversarial-shard-merge-mutants"
[ "$GROUP" = a ] || NAME="$NAME-$GROUP"
[ -f "$SELF" ] || { echo "FIXTURE ERROR: cannot read $SELF for the coverage join" >&2; exit 2; }

# partition_ok <declared ids file> <dealt ids file> -> 0 when dealt is disjoint and covers declared
# exactly; prints the offending ids otherwise.
partition_ok() {
  local dup miss extra
  dup="$(sort "$2" | uniq -d | tr '\n' ' ')"
  miss="$(sort -u "$2" | comm -23 <(sort -u "$1") - | tr '\n' ' ')"
  extra="$(sort -u "$2" | comm -13 <(sort -u "$1") - | tr '\n' ' ')"
  [ -z "$dup$miss$extra" ] && return 0
  echo "dealt twice: {${dup% }} dealt to no shard: {${miss% }} dealt but not declared: {${extra% }}"
  return 1
}
JW="$(mktemp -d "${TMPDIR:-/tmp}/asm-join.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
printf '%s\n' MX1 MX2 MX3 > "$JW/pd"; printf '%s\n' MX1 MX2 MX2 MX3 > "$JW/pdup"
printf '%s\n' MX1 MX3 > "$JW/pmiss"; printf '%s\n' MX3 MX1 MX2 > "$JW/pok"
if partition_ok "$JW/pd" "$JW/pdup" >/dev/null || partition_ok "$JW/pd" "$JW/pmiss" >/dev/null \
   || ! partition_ok "$JW/pd" "$JW/pok" >/dev/null; then
  echo "FIXTURE BROKEN: the coverage join's self-probe did not discriminate (duplicate, omission, exact)" >&2; exit 2
fi
# The declared set: every `mutant "` call between the MX markers, its id the label's first word.
awk '/^# ---- BEGIN MX MUTANTS/ { on = 1; next } /^# ---- END MX MUTANTS/ { on = 0 }
     on && /^mutant "/ { sub(/^mutant "/, ""); sub(/ .*/, ""); print }' "$SELF" > "$JW/declared"
for s in $SHARDS; do eval "printf '%s\n' \${MUTANTS_$s}"; done | grep . > "$JW/dealt"
ndecl="$(grep -c . "$JW/declared")" || ndecl=0
ndupdecl="$(sort "$JW/declared" | uniq -d | grep -c .)" || ndupdecl=0
if [ "$ndecl" -eq 0 ] || [ "$ndupdecl" -ne 0 ]; then
  echo "FIXTURE BROKEN: $ndecl mutant ids derived from $SELF ($ndupdecl declared twice)" >&2; exit 2
fi
if ! why="$(partition_ok "$JW/declared" "$JW/dealt")"; then
  echo "FIXTURE BROKEN: the shard partition does not cover the declared mutants exactly -- $why" >&2; exit 2
fi
for s in $SHARDS; do
  [ "$s" = a ] && continue
  drv="$HERE/../adversarial-shard-merge-mutants-$s/run.sh"
  # Anchored on the whole exec line, `^exec bash "$IMPL" --group <s>$`: a comment or any other
  # line merely mentioning `--group <s>` does not drive the shard.
  if [ ! -f "$drv" ] || ! grep -qxF -- "exec bash \"\$IMPL\" --group $s" "$drv"; then
    echo "FIXTURE BROKEN: shard '$s' is declared but $drv does not drive it" >&2; exit 2
  fi
done
rm -rf "$JW"
nmine=0; for _m in $MINE; do nmine=$((nmine+1)); done
JOIN_LINE="[J0] coverage join: $ndecl mutants derived from mutant lines, dealt disjointly across {$SHARDS}, union exact; this shard runs $nmine: {$MINE}"
command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 not on PATH (the mutation helper)" >&2; exit 2; }
SIB="$HERE/../adversarial-shard-merge"
[ -f "$SIB/lib.sh" ] || { echo "FIXTURE BROKEN: $SIB/lib.sh is absent; no predicate exists to score a mutant against" >&2; exit 2; }
[ -f "$SIB/run.sh" ] || { echo "FIXTURE BROKEN: $SIB/run.sh is absent; the arm/P_ALL join has no subject" >&2; exit 2; }
. "$SIB/lib.sh"
if [ -n "$ROWS" ]; then : >> "$ROWS" || { echo "FIXTURE ERROR: cannot write --rows $ROWS" >&2; exit 2; }; fi

echo "$NAME:"
echo "HERMETIC-CONSUMED core/scripts/merge-adversarial-shards.sh"
ok "$JOIN_LINE"

# THE JOIN: every predicate the shipped fixture calls as an arm is scored here, and every predicate
# scored here is one the shipped fixture runs. Read from the shipped run.sh's own arm calls.
ARMS="$(sed -n 's/^p_\([a-z0-9_][a-z0-9_]*\) "\$MERGE".*/\1/p' "$SIB/run.sh" | sort -u)"
PSET="$(printf '%s\n' $P_ALL | sort)"
na="$(grep -c . <<<"$ARMS")" || na=0
np="$(grep -c . <<<"$PSET")" || np=0
if [ "$na" -eq 0 ] || [ "$np" -eq 0 ]; then
  bad "J1: FIXTURE BROKEN -- read $na arm name(s) from the shipped run.sh and $np from P_ALL; an empty side agrees with anything"
elif [ "$ARMS" = "$PSET" ]; then
  ok "J1: the shipped fixture's $na arm predicates and the $np in P_ALL are the same set"
else
  printf '%s\n' "$ARMS" > "$WORK/j1.arms"; printf '%s\n' "$PSET" > "$WORK/j1.pset"
  bad "J1: arms not in P_ALL [$(comm -23 "$WORK/j1.arms" "$WORK/j1.pset" | tr '\n' ' ')], P_ALL not an arm [$(comm -13 "$WORK/j1.arms" "$WORK/j1.pset" | tr '\n' ' ')]"
fi
set -- $P_ALL; N_ALL=$#

# ------------------------------------------------------------------------------ the mutants
# A copy of the merge AND its siblings, one literal edit asserted to apply exactly once.
mutdir() { # <name> -> a dir holding the merge and the siblings it and the predicates resolve
  local d s
  d="$(mktemp -d "$WORK/mut-$1.XXXXXX")" || return 1
  for s in merge-adversarial-shards.sh validate-adversarial-convergence.sh validate-steering-budget.sh partition-document.sh partition-subject.sh; do
    [ -f "$SRCDIR/$s" ] && cp "$SRCDIR/$s" "$d/"
  done
  printf '%s' "$d"
}
apply() { # <file> <old> <new>: exactly one occurrence, else exit 3
  M_OLD="$2" M_NEW="$3" python3 - "$1" <<'PY'
import os, sys
p = sys.argv[1]; old, new = os.environ["M_OLD"], os.environ["M_NEW"]
t = open(p, encoding="utf-8").read()
n = t.count(old)
if n != 1:
    sys.stderr.write("ANCHOR MATCHED %d TIMES, EXPECTED 1\n" % n); sys.exit(3)
open(p, "w", encoding="utf-8").write(t.replace(old, new))
PY
}

POOL=8
SCORER_BOUND=900
VD="$WORK/verdicts"; mkdir -p "$VD" || { echo "FIXTURE ERROR: cannot create $VD" >&2; exit 2; }
IDX="$WORK/dispatch.tsv"; : > "$IDX"
NDISP=0

# One scorer: every predicate against <merge>, in P_ALL order, in its own scratch.
scorer() { # <id> <label> <merge-script>
  trap - EXIT
  local id="$1" label="$2" m="$3" sw p n=0 dead=""
  sw="$WORK/mut-$id"; mkdir -p "$sw" || exit 1
  WORK="$sw"; bind_scratch "$sw"; RC=""
  for p in $P_ALL; do n=$((n + 1)); "p_$p" "$m" || dead="$dead $p"; done
  dead="${dead# }"
  printf '%s\t%s\t%s\n' "$label" "$n" "$dead" > "$VD/$id.tmp" && mv "$VD/$id.tmp" "$VD/$id.v"
}
killtree() { # <pid>: stop it, take its children down first, then it
  local c
  kill -STOP "$1" 2>/dev/null
  for c in $(pgrep -P "$1" 2>/dev/null); do killtree "$c"; done
  kill -9 "$1" 2>/dev/null
}
slot() { # <id> <label> <merge-script>: the scorer under its watchdog, then the completion sentinel
  trap - EXIT
  local id="$1" s t=0
  ( scorer "$@" ) &
  s=$!
  while kill -0 "$s" 2>/dev/null; do
    if [ "$t" -ge "$SCORER_BOUND" ]; then : > "$VD/$id.timeout"; killtree "$s"; break; fi
    sleep 1; t=$((t + 1))
  done
  wait "$s" 2>/dev/null
  : > "$VD/$id.done"
}
ndone() { set -- "$VD"/*.done; [ -e "$1" ] && echo "$#" || echo 0; }
dispatch() { # <label> <merge-script> <expected dead set | NONE>
  local id
  while [ "$((NDISP - $(ndone)))" -ge "$POOL" ]; do sleep 1; done
  NDISP=$((NDISP + 1)); id="$(printf '%03d' "$NDISP")"
  printf '%s\t%s\t%s\n' "$id" "$1" "$3" >> "$IDX"
  slot "$id" "$1" "$2" &
}
# THE JUDGMENT, factored so it can be probed: no global is read or written but its arguments and
# the two constants; it prints its one line and returns 0 (ok) or 1 (FAIL).
judge() { # <verdict-stem> <label> <expected dead set | NONE>
  local stem="$1" label="$2" want="$3" lab n dead
  if [ -e "$stem.timeout" ]; then printf '%s: TIMEOUT -- the scorer ran past %ss and was killed; no verdict\n' "$label" "$SCORER_BOUND"; return 1; fi
  if [ ! -f "$stem.v" ]; then printf '%s: NO VERDICT -- the scorer wrote nothing; a lost scorer is never a pass\n' "$label"; return 1; fi
  IFS='	' read -r lab n dead < "$stem.v"
  if [ "$lab" != "$label" ]; then printf '%s: the verdict file carries the label [%s]\n' "$label" "$lab"; return 1; fi
  if [ "$n" != "$N_ALL" ]; then printf '%s: the scorer evaluated %s of %s predicates\n' "$label" "$n" "$N_ALL"; return 1; fi
  if [ "$want" = "NONE" ]; then
    if [ -z "$dead" ]; then printf '%s: every predicate HOLDS on the unmutated sandbox copy, so each kill below is the mutation'"'"'s\n' "$label"; return 0; fi
    printf '%s: the UNMUTATED copy failed [%s]; every mutant verdict below is about a broken harness\n' "$label" "$dead"; return 1
  fi
  if [ -z "$dead" ]; then printf '%s SURVIVED -- no arm watches the line it edits\n' "$label"; return 1; fi
  if [ "$dead" = "$want" ]; then printf '%s: KILLED by [%s] and nothing else\n' "$label" "$want"; return 0; fi
  printf '%s killed [%s], expected exactly [%s] -- an arm is entangled or does not own this property\n' "$label" "$dead" "$want"; return 1
}
# mine <label>: 0 when the mutant is dealt to this shard (and counts it as reached), 1 otherwise.
NSEEN=0
mine() {
  case " $MINE " in *" ${1%% *} "*) NSEEN=$((NSEEN + 1)); return 0 ;; esac
  return 1
}
mutant() { # <label> <expected> <old> <new> [<old2> <new2>]
  mine "$1" || return 0
  local label="$1" want="$2" d; d="$(mutdir "${label%% *}")"
  if ! apply "$d/merge-adversarial-shards.sh" "$3" "$4" || { [ $# -ge 6 ] && ! apply "$d/merge-adversarial-shards.sh" "$5" "$6"; }; then
    bad "$label: FIXTURE STALE -- the mutation anchor is not in the merge exactly once; re-anchor it, never relax the assertion"; return
  fi
  if cmp -s "$MERGE" "$d/merge-adversarial-shards.sh"; then bad "$label: FIXTURE STALE -- the mutated copy is byte-identical"; return; fi
  bash -n "$d/merge-adversarial-shards.sh" 2>/dev/null || { bad "$label: FIXTURE BROKEN -- the mutated merge does not parse"; return; }
  dispatch "$label" "$d/merge-adversarial-shards.sh" "$want"
}

C0="$(mutdir m0)"
if [ -f "$C0/validate-adversarial-convergence.sh" ] && [ -f "$C0/merge-adversarial-shards.sh" ] && [ -f "$C0/partition-document.sh" ]; then
  ok "MX-pre: the sandbox carries the merge, the convergence validator it reads its ceilings from, and the partition section mode reads its --map from"
  dispatch "MX0 control (unmutated copy)" "$C0/merge-adversarial-shards.sh" NONE
else
  bad "MX-pre: FIXTURE BROKEN -- the sandbox lacks the merge or its sibling"
fi

# ---- BEGIN MX MUTANTS. The coverage join [J0] reads the `mutant "` calls between these two
# markers in this file as the DECLARED set, and requires each dealt to exactly one shard.

# Two worlds own this, by construction: B3 (every shard MET, residue 6) and its mirror (every
# shard NOT_MET, residue at the ceiling). A worst-shard merge is wrong in both directions. The
# section-mode B3 (D1) and the files-mode golden (D6) are the same property in the other mode and
# in bytes, so they die with it.
mutant "MX1 verdict = worst shard verdict, not recomputed" "b3 clean doc_b3 files_golden subj_b3" \
  'elif [ "$S_CRIT" -le "$CRIT_CEIL" ] && [ "$BLOCKING" -le "$MAJOR_CEIL" ]; then VERDICT="EXIT_CONDITION_MET"' \
  'elif [ "${WORST_NOT_MET:-0}" -eq 0 ]; then VERDICT="EXIT_CONDITION_MET"' \
  '    EXIT_CONDITION_MET|EXIT_CONDITION_NOT_MET) ;;' \
  '    EXIT_CONDITION_MET) ;;
    EXIT_CONDITION_NOT_MET) WORST_NOT_MET=1 ;;'
mutant "MX2 ceiling hard-coded, not read" "ceiling" \
  'MAJOR_CEIL="$(read_ceiling MAJOR_EXIT_CEILING)"' \
  'MAJOR_CEIL=3'
mutant "MX3 missing-shard check removed" "miss_ord miss_cross subj_miss_cross" \
  'for idx in $ORDINALS $CROSS_KEYS; do' \
  'for idx in ; do'
mutant "MX4 earliest shard by raw string, not by time" "ms" \
  'if [ -z "$EARLIEST" ] || [[ "$AT_KEY" < "$EARLIEST_KEY" ]]; then' \
  'if [ -z "$EARLIEST" ] || [[ "$at" < "$EARLIEST" ]]; then'
mutant "MX5 invoked_at fraction refused" "ms" \
  ':[0-9]{2}(\.[0-9]{1,9})?Z$' \
  ':[0-9]{2}Z$'
# Section mode. D2's seed carries exactly one sections: line, so with the guard gone the finding
# passes the one-citation count and the merge SUCCEEDS -- the kill is D2's alone.
mutant "MX6 wrong-axis guard removed" "doc_axis" \
  '[ "${wrong:-0}" = "0" ] || refuse' \
  '[ "${wrong:-0}" = "0" ] || true'
# MX6b: the kill above would ALSO be scored if some other rule refused D2's seed, so assert what
# separates them: with the guard gone the same seed MERGES (exit 0), i.e. nothing else refuses it.
if [ "$GROUP" != a ]; then :
elif M6="$(mutdir m6b)" && apply "$M6/merge-adversarial-shards.sh" '[ "${wrong:-0}" = "0" ] || refuse' '[ "${wrong:-0}" = "0" ] || true' 2>/dev/null \
   && ! cmp -s "$MERGE" "$M6/merge-adversarial-shards.sh"; then
  d="$(doc_b3_world)"; dshard "$d" 2 2 EXIT_CONDITION_MET 2 "" "" "stories: 2"
  run_doc_merge "$M6/merge-adversarial-shards.sh" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" \
    && ok "MX6b: without the axis guard D2's seed MERGES (exit 0) -- no other rule refuses it, so the guard alone owns the refusal" \
    || bad "MX6b: without the axis guard D2's seed still did not merge (rc=$RC) -- another rule refuses it first and D2 cannot see the guard: $(cat "$MO")"
else
  bad "MX6b: FIXTURE STALE -- the axis-guard anchor is not in the merge exactly once"
fi
mutant "MX7 whole-document sha check removed" "doc_sha" \
  '[ "$sha" = "$DOC_SHA" ] || refuse' \
  '[ "$sha" = "$DOC_SHA" ] || true'
mutant "MX8 artifact-path check removed" "doc_path" \
  '[ "$ART_ABS" = "$DOCUMENT" ] \' \
  'true || [ "$ART_ABS" = "$DOCUMENT" ] \'
# Subject mode.
mutant "MX9 per-stem sha check removed" "subj_sha" \
  '[ "$sv" = "$want" ] || refuse' \
  '[ "$sv" = "$want" ] || true'
mutant "MX10 four-stem count check removed" "subj_stems" \
  '[ "$nt" -eq 4 ] && [' \
  'true || ['
mutant "MX11 subject artifact check removed" "subj_art" \
  '[ "$ART_ABS" = "$SUBJ_MF" ] \' \
  'true || [ "$ART_ABS" = "$SUBJ_MF" ] \'
mutant "MX12 elicitation verdict line written" "subj_elicit" \
  '  [ "$ELICIT" -eq 1 ] || printf '"'"'verdict: %s\n'"'"' "$VERDICT"' \
  '  printf '"'"'verdict: %s\n'"'"' "$VERDICT"'
mutant "MX13 B4 refusal removed" "subj_b4" \
  'if [ -z "$SUBJECT" ] && [ "$ARTIFACT" = "requirements" ]; then' \
  'if false; then'
# B4 by document. MX14: the widened guard never entered. MX15: it refuses every --document in a
# manifest sprint (the row compare dropped) -- only the not-named twin U11 can see that. The guard's
# own `[ -f manifest ]` conjunct has no killing world: with it removed, a sprint with no manifest
# finds no first row, resolves no root and refuses nothing, so U10 holds either way (covered by the
# `[ -n "$B4_ROOT" ]` below it, recorded rather than mutated).
mutant "MX14 B4-by-document guard removed" "b4doc" \
  'if [ -n "$DOCUMENT" ] && [ -f "$SPRINT_DIR/requirements-subject.md" ]; then' \
  'if false; then'
# MX15 dies on TWO arms, both genuinely: U11 sees a refusal where none is owed, and U9 sees the
# refusal name the wrong stem -- an always-true compare refuses at the manifest's FIRST row, so it
# tells the lead `--document prd.md` is the 'product-brief' file. The stand-down the mutant rule
# prescribes is NOT taken: the only arm that could stand down is U9's stem-name conjunct, which is
# there because prd is seeded NOT first in the manifest, and a refusal naming the wrong file is the
# costlier failure -- it is the remedy text the lead acts on.
mutant "MX15 B4-by-document refuses every document" "b4doc b4doc_other" \
  '    [ "$(cd "$(dirname "$B4_ROOT/$b4_rel")" && pwd -P)/${b4_rel##*/}" = "$DOCUMENT" ] \' \
  '    true \'
# The cross groups (BL-464). XM1: files and --subject left single-cross -- the groups are read only
# in --document mode, the wrong build "merge sharded in one mode only". Every files and subject arm
# that seeds cross-<g> dies; the --document arms hold.
mutant "XM1 one mode left single-cross" "b3 clean ceiling miss_ord miss_cross partition sha ms files_golden subj_b3 subj_miss_cross subj_xcite subj_sha subj_stems subj_art subj_elicit xfiles xelicit xmix xunknown xcomplete tuid_main tuid_norow tuid_nometa tuid_selfdiff tuid_role tuid_twowriters tuid_oneagent tuid_nospawn tuid_session tuid_pre tuid_basename tuid_probemeta tuid_tworoles rerun_join rerun_other rerun_same rerun_role xdir probe_disagree probe_absent rerun_residual" \
  'bash "$XPART" --cross-groups "$K" > "$T/groups" 2> "$T/groups.err"; grc=$?' \
  'bash "$XPART" --cross-groups "$( [ -n "$DOCUMENT" ] && echo "$K" || echo 2)" > "$T/groups" 2> "$T/groups.err"; grc=$?'
# XM2: the owner rule off -- a finding two covering groups both report is summed twice. Only the
# duplicate cell of X1-X3 seeds one.
mutant "XM2 owner rule off (duplicate summed)" "xfiles xdoc xelicit" \
  '      if [ "$ownk" != "$key" ]; then' \
  '      if false; then'
# XM7: the pre-v4 rule -- every finding outside its owner's shard refused, identical or not. The
# (1, 2, K-1) finding only a non-owner holds is then lost, which is the defect; only that cell dies.
mutant "XM7 non-owner refused whatever its owner carries" "xfiles xdoc xelicit" \
  '        ! same_set "$osf" "$CITE" "$distinct" \' \
  '        false \'
# XM8: the marker's findings=<n> not compared -- a truncated shard merges. Only X6's partial cell.
mutant "XM8 seat-complete count unchecked" "xcomplete" \
  '    [ "$scn" = "$nfx" ] \' \
  '    true \'
# XM3: the merged tool_use_id taken from the LAST cross group read, not cross-1. Anchored on the
# EMISSION line, so only the emitted value moves: CROSS_FIRST also keys the files-mode cross
# artifact agreement, and a mutation there refused every files world for that other reason.
mutant "XM3 tool_use_id not cross-1" "doc_b3 files_golden xfiles xdoc xelicit tuid_main tuid_session" \
  "  printf 'tool_use_id: %s\\n' \"\$CROSS_ID\"" \
  "  printf 'tool_use_id: %s\\n' \"\${ID_LIST##*=}\""
# XM4: the mix guard gone. cross.md beside cross-<g>.md at G>1 is then refused by the wrong-shape
# guard instead, so the kill is X4's message alone.
mutant "XM4 cross.md/cross-<g>.md mix accepted" "xmix" \
  '[ "$x_plain" -eq 1 ] && [ "$x_num" -eq 1 ] \' \
  'false && [ "$x_num" -eq 1 ] \'
# XM5: a cross-<g> the table does not print accepted. X5 sees cross-7 merge silently; X1 and X2's
# K=2 cell sees `cross-1.md` refused as missing `cross` rather than named as unprinted -- both true.
mutant "XM5 unknown cross group accepted" "xfiles xdoc xunknown" \
  '      case " $CROSS_KEYS " in *" $xk "*) ;; *) refuse' \
  '      case " $CROSS_KEYS " in *) ;; *" $xk "*) refuse'
# XM6: the seat-complete belt gone -- an unfinished shard beside a finished one merges.
mutant "XM6 seat-complete refusal removed" "xcomplete" \
  "if grep -q '^Y' \"\$T/sc\" && grep -q '^N' \"\$T/sc\"; then" \
  'if false; then'
# The series-stem refusal. SM1 widens the suffix to the word anywhere -- only S3's near-miss dies.
SR_LINE='case "$ARTIFACT" in *-adversarial) refuse "shard directory $SHARD_BASE names the series'
mutant "SM1 series refusal matches adversarial anywhere" "stem_near" \
  "$SR_LINE" \
  'case "$ARTIFACT" in *adversarial*) refuse "shard directory $SHARD_BASE names the series'
# SM2: the refusal moved below the write. S1 sees the record written; S4's files cell is refused
# by the stories-dir check first and its --map cell exits before the write, so neither names the series.
mutant "SM2 series refusal placed after the write" "stem_series stem_files" \
  "$SR_LINE" \
  'case "$ARTIFACT" in *-adversarial-no-such-stem) refuse "shard directory $SHARD_BASE names the series' \
  'cp "$T/out" "$OUT.merge-tmp.$$" && mv "$OUT.merge-tmp.$$" "$OUT" || refuse "writing $OUT failed"' \
  'cp "$T/out" "$OUT.merge-tmp.$$" && mv "$OUT.merge-tmp.$$" "$OUT" || refuse "writing $OUT failed"
case "$ARTIFACT" in *-adversarial) refuse "shard directory $SHARD_BASE names the series, not the artifact" ;; esac'
# SM3: the refusal in the --document branch only -- files mode and --map then take another path.
mutant "SM3 series refusal in --document mode only" "stem_files" \
  "$SR_LINE" \
  'case "$ARTIFACT" in *-adversarial) [ -n "$DOCUMENT" ] && refuse "shard directory $SHARD_BASE names the series'
# SM4: a refusal that also fires on graph's real, correct coe-p1 -- only S2's coe cell sees it.
mutant "SM4 series refusal also fires on coe-p1" "stem_control" \
  "$SR_LINE" \
  'case "$ARTIFACT" in *-adversarial|coe) refuse "shard directory $SHARD_BASE names the series'
# The DERIVED dispatch id. Each mutant reverts one refusal or one hop of the join, and each dies on
# the one tuid cell built to separate it.
# TM1: the self-report used when the ledger has no row -- T2's shard carries a toolu_-prefixed
# forged id, so with the fallback it MERGES; a NOT_ACCESSIBLE self id would refuse either way.
mutant "TM1 no-row shard falls back to the self-report" "tuid_norow" \
  '  [ -n "$tid" ] || refuse "$sf has no row in $REC_WRITES;' \
  '  [ -n "$tid" ] || tid="$(field "$P" tool_use_id)"; [ -n "$tid" ] || refuse "$sf has no row in $REC_WRITES;'
# TM2: the role hop skipped. T5's remediator-only shard merges; its adversary+remediator shard is
# then refused as two adversaries, which is the wrong reason, so the cell's token dies with it.
mutant "TM2 writer role not checked" "tuid_role tuid_tworoles" \
  '        if (R[j] != "adversary") no(' \
  '        if (0) no('
# TM3: the real-shaped self id never compared. Only T4 seeds one that differs.
mutant "TM3 self-reported id never compared" "tuid_selfdiff" \
  '  if [[ $self =~ $RE_REAL_TUID ]] && [ "$self" != "$tid" ]; then' \
  '  if false; then'
# TM4: the first of two adversary writers taken. Only T6 seeds two.
mutant "TM4 first of two adversary writers taken" "tuid_twowriters" \
  '      if (did != "") no(sf " was written by more than one adversary dispatch' \
  '      if (did != "") continue; if (0) no(sf " was written by more than one adversary dispatch'
# TM5: the meta file located by the payload's SESSION, the key the consumer census used, instead of
# by the row's own transcript_path. Every world whose session is the transcript's stem still merges;
# T9, whose session is not, finds no meta file.
mutant "TM5 meta file keyed by session, not by the row" "tuid_session" \
  '          else (.transcript_path | rtrimstr(".jsonl")) + "/subagents/agent-" + .agent_id + ".meta.json" end)]]' \
  '          else (.transcript_path | sub("/[^/]*$"; "")) + "/" + (.session // "") + "/subagents/agent-" + .agent_id + ".meta.json" end)]]'
# TM6: the pre-upgrade refusal removed -- a writer with no transcript_path and no probe row is
# skipped. T10's second cell then refuses for another reason (no row), and its token dies.
mutant "TM6 pre-upgrade refusal removed" "tuid_pre" \
  '      else no(sf " was written by agent " a " in a row that predates transcript_path' \
  '      else continue; if (0) no(sf " was written by agent " a " in a row that predates transcript_path'
# TM7: write rows keyed by BASENAME over any shard dir -- T11's rows for 2.md under another shard dir
# and another sprint then join to this shard, and it merges. XD1 dies with it, genuinely: its worlds
# carry rows under stories-p2/, -p3/ and -p10/, which then join this dir's shard 1 as second writers,
# so the join refuses every cell (its MERGED twins included) before the cross-dir check is reached.
mutant "TM7 write rows keyed by basename, any shard dir" "tuid_basename xdir" \
  '| select((.path // "") | type == "string" and startswith($p)) | select((.agent_id // "") != "")
      | [(.path | ltrimstr($p)), .agent_id,' \
  '| select((.path // "") | type == "string" and test("/shards/[^/]+/[^/]+$")) | select((.agent_id // "") != "")
      | [(.path | sub(".*/"; "")), .agent_id,'
# TM8: the probe ledger preferred over the meta file. The meta branch is then never entered, so the
# BL-536 D4 corroboration goes with it: T12's two-id agent and PR2's forged meta each take the probe's
# id and merge (PR2's remediator cell is refused by role instead). Both cells watch the meta/probe
# agreement, so the overlap is genuine; PR1 holds, its no-row writers falling back to the meta branch.
# RR5's refusing twin (a superseded remediator WITH its probe row, meta forged) is refused only by
# that agreement too, so with the probe id taken it is set aside as an adversary and merges.
mutant "TM8 probe ledger preferred over the meta file" "tuid_probemeta probe_disagree rerun_residual" \
  '      if (a in am) {' \
  '      if (a in probe) id = probe[a]; else if (a in am) {'
# TM9: the role checked only on a dispatch id with ONE spawn row -- T13's id carries two.
mutant "TM9 role checked only on single-row ids" "tuid_tworoles" \
  '        if (R[j] != "adversary") no(' \
  '        if (R[j] != "adversary" && r == 1) no('
# RM1: --rerun without the superseded-writer-wrote-elsewhere refusal -- RR2's cross-shard write merges.
mutant "RM1 rerun superseded-other-row check removed" "rerun_other" \
  '          if (f[i] != p && f[i] != p ".draft") { print "OUT' \
  '          if (0) { print "OUT'
# RM2: --rerun without the new-dispatch rule -- RR3's superseded writer re-runs itself and merges.
mutant "RM2 rerun new-dispatch rule removed" "rerun_same" \
  '          if (t[i] >= S[p]) { print "SAME' \
  '          if (0) { print "SAME'
# BL-536. RM3 (D1): the role loop skipped for a SUPERSEDED writer (i > n) -- both of its no() lines,
# since skipping only the --rerun-specific one leaves the generic role refusal firing on the same
# writer. RR4's superseded remediator is then set aside and the set merges.
mutant "RM3 superseded writer's role never checked" "rerun_role" \
  '      r = split(role[id], R, "\t")' \
  '      if (i > n) continue; r = split(role[id], R, "\t")'
# TM10 (D2): the cross-dir select matches nothing. Every XD1 refusal (p2, p10, under --rerun) merges.
mutant "TM10 cross-shard-dir check never fires" "xdir" \
  '        | select($d != null and $d != $p)' \
  '        | select($d != null and $d != $p and false)'
# TM11 (D4 presence): an absent probe row is treated as one that AGREES -- not merely its no() removed,
# which would leave the equality line refusing the same writer with the wrong message. PR1's
# legitimate no-row writer merges; the meta-only forged remediator then resolves to an adversary too.
mutant "TM11 probe-row presence not required" "probe_absent" \
  '        if (!(a in probe)) no(' \
  '        if (!(a in probe)) pall[a] = "\t" id; if (0) no('
# TM12 (D4 equality): the probe ids never compared with the meta's. T12's two-id agent and PR2's forged
# metas take the meta's id and merge, and so does RR5's refusing twin, the superseded remediator whose
# probe row is the only thing that contradicts its forged meta; PR1 holds, its refusal is presence.
mutant "TM12 probe ids never compared with the meta" "tuid_probemeta probe_disagree rerun_residual" \
  '        if (pall[a] != "\t" id) {' \
  '        if (0) {'
# TM13: probe-row presence re-applied to SUPERSEDED writers -- the fold's defect. A stalled adversary
# never reached SubagentStop, so every --rerun world whose superseded writer has no probe row refuses
# 'has not stopped': RR1's contracted path, RR4's adversary twin (and its remediator cell, refused on
# presence before the role is read), and RR5's acquitted residual, which this closes. All three seed
# the real producer's no-row stall, so the overlap is genuine; no credited-writer cell moves.
mutant "TM13 probe-row presence required of superseded writers" "rerun_join rerun_role rerun_residual" \
  '        if (i <= n || (a in probe)) {' \
  '        if (1) {'
# ---- END MX MUTANTS

# ------------------------------------------------------------------------------ the reap
wait
nidx="$(grep -c . "$IDX")" || nidx=0
nd="$(ndone)"
if [ "$NDISP" -ge 2 ] && [ "$nidx" -eq "$NDISP" ] && [ "$nd" -eq "$NDISP" ]; then
  ok "MR: $NDISP scorers dispatched, $nidx recorded, $nd completed"
else
  bad "MR: $NDISP scorers dispatched, $nidx recorded, $nd completed -- a scorer was lost or never started"
fi
# The control is one dispatch; every other dispatch is a mutant dealt to this shard. JUDGED is
# counted as the reap walks the index. A control alone is NOT a battery: with every mutant call
# deleted the control still dispatches, still holds, and the run would otherwise read PASS.
njudged=0
while IFS='	' read -r id label want; do
  [ "$want" = "NONE" ] || njudged=$((njudged + 1))
  if line="$(judge "$VD/$id" "$label" "$want")"; then ok "$line"; else bad "$line"; fi
  if [ -n "$ROWS" ] && [ -f "$VD/$id.v" ]; then
    IFS='	' read -r _l _n _d < "$VD/$id.v"; printf '%s\t%s\n' "$label" "$_d" >> "$ROWS"
  fi
done < "$IDX"
if [ "$NSEEN" -eq "$nmine" ] && [ "$((NDISP - 1))" -eq "$nmine" ] && [ "$njudged" -eq "$nmine" ]; then
  ok "[J2] shard '$GROUP' reached $NSEEN mutants, dispatched $((NDISP - 1)) and judged $njudged, of $nmine dealt ($ndecl declared across {$SHARDS})"
else
  bad "[J2] shard '$GROUP' reached $NSEEN mutants, dispatched $((NDISP - 1)) and judged $njudged, of $nmine dealt -- a dealt mutant never ran"
fi

# THE JUDGMENT, PROBED ON A REAL VERDICT. The first MUTANT verdict this shard dispatched is copied
# aside and judged four ways: its own expected set must PASS (else the probe proves nothing about a
# judge that always fails), a deliberately wrong set must FAIL, the same verdict beside a TIMEOUT
# marker must FAIL, and the same stem with the verdict file deleted must FAIL. The wrong set is a
# predicate name no P_ALL member carries, so it can equal no mutant's.
pv="$(awk -F'\t' '$3 != "NONE" { print $1; exit }' "$IDX")"
pw="$(awk -F'\t' '$3 != "NONE" { print $3; exit }' "$IDX")"
pl="$(awk -F'\t' '$3 != "NONE" { print $2; exit }' "$IDX")"
if [ -z "$pv" ] || [ ! -f "$VD/$pv.v" ]; then
  bad "MJ: FIXTURE BROKEN -- no mutant verdict file to probe the judgment with"
else
  pd="$(mktemp -d "$WORK/judge-probe.XXXXXX")" && cp "$VD/$pv.v" "$pd/p.v"
  red=0
  judge "$pd/p" "$pl" "$pw" > /dev/null || red=$((red + 100))
  judge "$pd/p" "$pl" "no_such_predicate" > /dev/null || red=$((red + 1))
  : > "$pd/p.timeout"
  judge "$pd/p" "$pl" "$pw" > /dev/null || red=$((red + 1))
  rm -f "$pd/p.timeout" "$pd/p.v"
  judge "$pd/p" "$pl" "$pw" > /dev/null || red=$((red + 1))
  if [ "$red" -eq 3 ]; then
    ok "MJ: the judgment passes ${pl%% *}'s real verdict against its own set, and FAILS it against a wrong set, beside a TIMEOUT marker, and with the verdict file deleted"
  else
    bad "MJ: the judgment probe scored $red (want 3: real+right ok, real+wrong red, real+timeout red, deleted red; +100 means the right set failed)"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
