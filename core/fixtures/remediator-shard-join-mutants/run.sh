#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# remediator-shard-join-mutants/run.sh -- the JX mutation battery behind `remediator-shard-join`.
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
# mutant -- arms x mutants, serially -- and BL-462's eight party predicates took the unsplit fixture
# from 266s to 694s wall solo. The battery mutates copies of core's own `join-remediator-shards.sh`,
# which a consumer is denied editing, so proving the arms can fail is a question about files only
# this repository changes. The consumer keeps every behavioural arm.
#
# ONE COPY OF THE PREDICATES. Both fixtures source `remediator-shard-join/lib.sh`, so a mutant is
# scored by the very predicate bodies the shipped arms run. The join below asserts the shipped
# fixture's `p_<name> "$JOIN"` arm calls and P_ALL are the same set, so a predicate added to one
# and not the other cannot leave an arm unproven or a mutant scored against an arm nobody runs.
#
# SCORED IN PARALLEL, AND THE SILENT LOSS IS THE FAILURE MODE THIS SHAPE HAS TO CLOSE. A pool that
# drops a scorer reports fewer verdicts, and fewer verdicts read exactly like fewer failures. So:
#   - each scorer runs in its own subshell under `$WORK/mut-<id>/`, with WORK and the join's
#     output path (`bind_scratch`: JO) rebound there, and RC its own;
#   - it writes ONE verdict file, temp-then-mv, carrying the number of predicates it evaluated;
#   - the parent counts verdicts against dispatches, and judges each with `judge`, which treats a
#     missing verdict, a TIMEOUT, or an evaluated count other than |P_ALL| as a FAIL;
#   - the mutants DECLARED in this file are dealt across the shards and joined before dispatch
#     ([J0], below), and the number this shard dispatches must equal the number dealt to it ([J2]),
#     so a battery whose mutant calls were deleted fails rather than reporting a clean control;
#   - `judge` itself is probed every run, on a real verdict file, in both directions.
# The pool is a FIXED width of 8 (no knob); completion is read from sentinel files the scorers
# write, never from the process table.
#
# THE WATCHDOG. bash 3.2 has no `wait -n`, so each scorer runs under a slot that polls it and,
# past SCORER_BOUND seconds, writes a TIMEOUT marker and kills the scorer's whole process tree
# (stopped first, then children before parents, so nothing reparents to init and keeps spinning).
# The unsplit fixture measured 528 CPU-s solo for 25 scorings plus the arms, about 20s a scoring;
# a unit under the gate's pool has measured 4x its solo time. 900s is roughly 45x the per-scoring
# figure.
#
# THE SHARDS. The pre-push suite is POLE-BOUND: its makespan tracks its single longest DIRECTORY,
# and this battery, 63 mutants in one unit, was that directory at 1051s loaded (404s solo). So the
# mutant set is dealt across three units, this directory (shard a) and the one-line drivers
# `remediator-shard-join-mutants-b` and `-c`, each `exec bash "$IMPL" --group <x>`, the shape
# `review-shard-merge-mutants` carries. Every scorer runs every predicate, so the cost per mutant
# is roughly uniform and an equal count balances: 21 each, in declaration order by family.
# Every shard pays the unmutated control JX0, the J1 join and the MJ probe itself, because a shard
# that skipped them could report a kill against a harness that never ran.
#
# THE SHARD ARRIVES AS AN ARGUMENT, never from the environment: the scrub below unsets AI_DLC_*,
# and a fallback-to-'a' design would run shard a three times and report three green fixtures.
#
# THE COVERAGE JOIN [J0] runs in every shard before any mutant is dispatched: the declared set is
# DERIVED from this file's own `mutant`/`mutant2`/`mutant3` lines between the JX markers, the dealt
# lists must be disjoint and their union must equal it exactly, and every declared shard must have
# a driver directory naming it. The join proves it can fire, on a seeded duplicate and a seeded
# omission, before it is trusted. After the reap, [J2] asserts this shard dispatched exactly the
# mutants dealt to it.
SHARDS="a b c"
MUTANTS_a="JX1 JX2 JX3 JX4 JX5 JX6 JX7 JX8 JX10 JX9 JX11 JX12 JX13 JX14 JX15 JX16 JX17 JX18 JX19 JX20 JX21"
MUTANTS_b="JX22 JX23 JX24 JX25 JX26 JX27 JX28 JX29 JX30 JX36 JX37 JX38 JX42 JX43 JX44 JX45 JX46 JX47 JX48 JX49 JX39"
MUTANTS_c="JX40 JX41 JX31 JX32 JX33 JX34 JX35 JX50 JX51 JX52 JX53 JX54 JX55 JX56 JX57 JX58 JX59 JX60 JX61 JX62 JX63"
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
# lib.sh rebinds HERE to ITS directory (it reads the seeds from there), so this file's own path is
# captured now: the coverage join reads the DECLARED mutant set from it.
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
NAME="remediator-shard-join-mutants"
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
JW="$(mktemp -d "${TMPDIR:-/tmp}/rsj-join.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
printf '%s\n' JX1 JX2 JX3 > "$JW/pd"; printf '%s\n' JX1 JX2 JX2 JX3 > "$JW/pdup"
printf '%s\n' JX1 JX3 > "$JW/pmiss"; printf '%s\n' JX3 JX1 JX2 > "$JW/pok"
if partition_ok "$JW/pd" "$JW/pdup" >/dev/null || partition_ok "$JW/pd" "$JW/pmiss" >/dev/null \
   || ! partition_ok "$JW/pd" "$JW/pok" >/dev/null; then
  echo "FIXTURE BROKEN: the coverage join's self-probe did not discriminate (duplicate, omission, exact)" >&2; exit 2
fi
# The declared set: every `mutant`, `mutant2` or `mutant3` call between the JX markers, its id the
# label's first word. All three spellings, or a multi-layer mutant dealt to no shard is invisible.
awk '/^# ---- BEGIN JX MUTANTS/ { on = 1; next } /^# ---- END JX MUTANTS/ { on = 0 }
     on && /^mutant[23]? "/ { sub(/^mutant[23]? "/, ""); sub(/ .*/, ""); print }' "$SELF" > "$JW/declared"
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
  drv="$HERE/../remediator-shard-join-mutants-$s/run.sh"
  # Anchored on the whole exec line, `^exec bash "$IMPL" --group <s>$`: a comment or any other
  # line merely mentioning `--group <s>` does not drive the shard.
  if [ ! -f "$drv" ] || ! grep -qxF -- "exec bash \"\$IMPL\" --group $s" "$drv"; then
    echo "FIXTURE BROKEN: shard '$s' is declared but $drv does not drive it" >&2; exit 2
  fi
done
nmine=0; for _m in $MINE; do nmine=$((nmine+1)); done
JOIN_LINE="[J0] coverage join: $ndecl mutants derived from mutant lines, dealt disjointly across {$SHARDS}, union exact; this shard runs $nmine: {$MINE}"
command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 not on PATH (the mutation helper)" >&2; exit 2; }
SIB="$HERE/../remediator-shard-join"
[ -f "$SIB/lib.sh" ] || { echo "FIXTURE BROKEN: $SIB/lib.sh is absent; no predicate exists to score a mutant against" >&2; exit 2; }
[ -f "$SIB/run.sh" ] || { echo "FIXTURE BROKEN: $SIB/run.sh is absent; the arm/P_ALL join has no subject" >&2; exit 2; }
. "$SIB/lib.sh"
echo "HERMETIC-CONSUMED $JOIN"
echo "HERMETIC-CONSUMED $HOOK"
# lib.sh's WORK is created after its argument parse ran here, so the rows file is opened only now.
if [ -n "$ROWS" ]; then : >> "$ROWS" || { echo "FIXTURE ERROR: cannot write --rows $ROWS" >&2; exit 2; }; fi

echo "$NAME:"
ok "$JOIN_LINE"

# THE JOIN: every predicate the shipped fixture calls as an arm is scored here, and every predicate
# scored here is one the shipped fixture runs. Read from the shipped run.sh's own arm lines, so
# the shipped set is never restated.
ARMS="$(sed -n 's/^p_\([a-z0-9_]*\) "\$JOIN".*/\1/p' "$SIB/run.sh" | sort)"
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
mutdir() { # <name> -> the join and the siblings it evals and shells out to
  local d; d="$(mktemp -d "$WORK/mut-$1.XXXXXX")" || return 1
  cp "$JOIN" "$CONV" "$PARTITION" "$SRCDIR/partition-subject.sh" "$d/" || return 1
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

# One scorer: every predicate against <join>, in P_ALL order, in its own scratch.
scorer() { # <id> <label> <join>
  trap - EXIT
  local id="$1" label="$2" j="$3" sw p n=0 dead=""
  sw="$WORK/mut-$id"; mkdir -p "$sw" || exit 1
  WORK="$sw"; bind_scratch "$sw"; RC=""
  for p in $P_ALL; do n=$((n + 1)); "p_$p" "$j" || dead="$dead $p"; done
  dead="${dead# }"
  printf '%s\t%s\t%s\n' "$label" "$n" "$dead" > "$VD/$id.tmp" && mv "$VD/$id.tmp" "$VD/$id.v"
}
killtree() { # <pid>: stop it, take its children down first, then it
  local c
  kill -STOP "$1" 2>/dev/null
  for c in $(pgrep -P "$1" 2>/dev/null); do killtree "$c"; done
  kill -9 "$1" 2>/dev/null
}
slot() { # <id> <label> <join>: the scorer under its watchdog, then the completion sentinel
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
dispatch() { # <label> <join> <expected dead set | NONE>
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
# Called by all three spellings, so a multi-layer mutant is filtered and counted like any other.
NSEEN=0
mine() {
  case " $MINE " in *" ${1%% *} "*) NSEEN=$((NSEEN + 1)); return 0 ;; esac
  return 1
}
mutant() { # <label> <expected> <old> <new>
  mine "$1" || return 0
  local d; d="$(mutdir "${1%% *}")" || { bad "$1: FIXTURE BROKEN -- the sandbox could not be built"; return; }
  if ! apply "$d/join-remediator-shards.sh" "$3" "$4"; then
    bad "$1: FIXTURE STALE -- the mutation anchor is not in the join exactly once; re-anchor it, never relax the assertion"; return
  fi
  cmp -s "$JOIN" "$d/join-remediator-shards.sh" && { bad "$1: FIXTURE STALE -- the mutated copy is byte-identical"; return; }
  bash -n "$d/join-remediator-shards.sh" 2>/dev/null || { bad "$1: FIXTURE BROKEN -- the mutated join does not parse"; return; }
  dispatch "$1" "$d/join-remediator-shards.sh" "$2"
}
mutant2() { # <label> <expected> <old1> <new1> <old2> <new2> -- two layers reverted together
  mine "$1" || return 0
  local d; d="$(mutdir "${1%% *}")" || { bad "$1: FIXTURE BROKEN -- the sandbox could not be built"; return; }
  if ! apply "$d/join-remediator-shards.sh" "$3" "$4" || ! apply "$d/join-remediator-shards.sh" "$5" "$6"; then
    bad "$1: FIXTURE STALE -- a mutation anchor is not in the join exactly once; re-anchor it, never relax the assertion"; return
  fi
  cmp -s "$JOIN" "$d/join-remediator-shards.sh" && { bad "$1: FIXTURE STALE -- the mutated copy is byte-identical"; return; }
  bash -n "$d/join-remediator-shards.sh" 2>/dev/null || { bad "$1: FIXTURE BROKEN -- the mutated join does not parse"; return; }
  dispatch "$1" "$d/join-remediator-shards.sh" "$2"
}
mutant3() { # <label> <expected> <old1> <new1> <old2> <new2> <old3> <new3> -- three layers reverted together
  mine "$1" || return 0
  local d; d="$(mutdir "${1%% *}")" || { bad "$1: FIXTURE BROKEN -- the sandbox could not be built"; return; }
  if ! apply "$d/join-remediator-shards.sh" "$3" "$4" || ! apply "$d/join-remediator-shards.sh" "$5" "$6" \
     || ! apply "$d/join-remediator-shards.sh" "$7" "$8"; then
    bad "$1: FIXTURE STALE -- a mutation anchor is not in the join exactly once; re-anchor it, never relax the assertion"; return
  fi
  cmp -s "$JOIN" "$d/join-remediator-shards.sh" && { bad "$1: FIXTURE STALE -- the mutated copy is byte-identical"; return; }
  bash -n "$d/join-remediator-shards.sh" 2>/dev/null || { bad "$1: FIXTURE BROKEN -- the mutated join does not parse"; return; }
  dispatch "$1" "$d/join-remediator-shards.sh" "$2"
}

C0="$(mutdir jx0)"
if [ -f "$C0/join-remediator-shards.sh" ] && [ -f "$C0/validate-adversarial-convergence.sh" ] \
   && [ -f "$C0/partition-document.sh" ] && [ -f "$C0/partition-subject.sh" ]; then
  ok "JX-pre: the sandbox carries the join, the sibling it extracts repair_field() from, and both splitters it assembles through"
  dispatch "JX0 control (unmutated copy)" "$C0/join-remediator-shards.sh" NONE
else
  bad "JX-pre: FIXTURE BROKEN -- the sandbox lacks the join or a sibling"
fi

# ---- BEGIN JX MUTANTS. The coverage join [J0] reads the `mutant`/`mutant2`/`mutant3` calls between
# these two markers in this file as the DECLARED set, and requires each dealt to exactly one shard.
# J2's world ALSO trips other refusals, so this mutant still exits 2 there; the kill is the
# missing overlap SENTENCE, which is the only thing that names the defect to the lead.
# rrgraph, rrfiles and rrsubj assert the overlap sentence on their no-rerun half, rrspan on the
# re-run writer's second section, alnokeys on a keyless ledger.
mutant "JX1 the >1-writer refusal removed" "overlap docoverlap sjspec2 rrgraph rrspan rrfiles rrsubj alnokeys" \
  'if [ -n "$OVERLAPS" ]; then' \
  'if false; then'
mutant "JX2 the uncited-file refusal removed" "missing" \
  '      if (!(p in cov)) print "UNCITED\t" p "\t" wr[p]' \
  '      if (0) print "UNCITED\t" p "\t" wr[p]'
# The shards/ filter is spelled twice since the re-run join: in ROWS and in the detailed DROWS read.
# JX3 and JX4 revert BOTH, each anchored on the line after it that tells the two apart.
SHF='| select($doc == "1" or ((.path | startswith($sh + "/")) | not))'
SHF_ROWS='   | [.path, .agent_id]] | unique | .[] | @tsv'
SHF_DROWS='     | [.path, .agent_id, .ts, (.session | d), (.tool_use_id | d), (.transcript_path | d),'
mutant2 "JX3 the shards/ exclusion removed" "shardrow" \
  "   $SHF
$SHF_ROWS" \
  "   | select(true)
$SHF_ROWS" \
  "     $SHF
$SHF_DROWS" \
  "     | select(true)
$SHF_DROWS"
# JX4 is the defect this mode exists to close: the files-mode filter applied in document mode drops
# every section row, so the join sees no write at all.
# partydoc is a document join too, and dies with the others. sjpartysrc does NOT: its subject keeps
# whole-file part rows outside shards/, so the join still reaches the source check and refuses by name.
# sibdoc (BL-508) dies too: with no section rows the join refuses on the empty ledger before its siblings arm.
# The document- and subject-mode re-run arms die too: with no section rows nothing is re-run.
mutant2 "JX4 section rows dropped in document mode (the pre-BL-372 file set)" "docjoin docoverlap asmrefuse sjoin sjnames sjgate sjnest partydoc sibdoc rrgraph rrout rrlate rrlatein rrsame rrspan rrsubj" \
  "   $SHF
$SHF_ROWS" \
  "   | select((.path | startswith(\$sh + \"/\")) | not)
$SHF_ROWS" \
  "     $SHF
$SHF_DROWS" \
  "     | select((.path | startswith(\$sh + \"/\")) | not)
$SHF_DROWS"
# rrgraph asserts the re-run writer's edit reached the assembled document.
mutant "JX5 the assembly skipped" "docjoin asmrefuse partydoc rrgraph" \
  '  ASM_LINE="$(bash "$PARTITION" --assemble "$SHARD_DIR" 2>&1)" || {' \
  '  ASM_LINE="skipped" || {'
mutant "JX6 the assembler's refusal ignored" "asmrefuse" \
  '  ASM_LINE="$(bash "$PARTITION" --assemble "$SHARD_DIR" 2>&1)" || {' \
  '  ASM_LINE="$(bash "$PARTITION" --assemble "$SHARD_DIR" 2>&1)"; false && {'
mutant "JX7 files mode accepts a section-split dir" "filesguard" \
  '  [ -e "$MANIFEST" ] && die' \
  '  false && die'
# JX8/JX9: the absolute-citation strip removed, and widened to any `.../<state-dir-name>/...` --
# the second acquits a foreign root, which only A2 sees.
STRIP='    _t="${_t#"$STATE_PARENT"}"; _t="${_t#"$STATE_PARENT_P"}"'
mutant "JX8 the state-parent strip removed" "absroot absnested absslash absdouble" \
  "$STRIP" \
  '    :'
mutant "JX10 the cited token's slash squeeze removed" "absdouble" \
  'tok = substr(line, RSTART, RLENGTH); gsub(/\/\/+/, "/", tok); tk[++nt] = tok' \
  'tok = substr(line, RSTART, RLENGTH); tk[++nt] = tok'
mutant "JX9 any .../<state-dir-name>/... rewritten to <state-dir-name>/..." "absforeign" \
  "$STRIP" \
  "$STRIP"'
    case "$_t" in */"${STATE##*/}"/*) _t="${STATE##*/}/${_t#*/"${STATE##*/}"/}" ;; esac'

mutant "JX11 subject in-place write to a sectioned file not refused" "sjoos" \
  '        S) refuse "${_p} was written IN PLACE' \
  '        S) : "${_p} was written IN PLACE'
mutant "JX12 subject part-less file write not refused" "sjnopart" \
  '        O) refuse "${_p} has no part' \
  '        O) : "${_p} has no part'
mutant "JX13 subject --base assertion removed" "sjbase" \
  '    [ -n "$_bf" ] && [ "$_bf" = "$SUBJ_MF_BASE" ] || die' \
  '    true || die'
mutant "JX14 subject assembly skipped" "sjoin sjnest" \
  '  ASM_LINE="$(bash "$PSUBJ" --assemble "$SHARD_DIR" 2>&1)" || {' \
  '  ASM_LINE="skipped" || {'
# The document-mode link triple (BL-460): the after line dropped, the after taken off the split's
# sha (an identity link J2 discards), and the root strip removed (an absolute artifact: path).
mutant "JX15 document-mode after sha not written" "docjoin" \
  '    echo "- artifact_sha_after: ${DOC_AFTER}"' \
  '    :'
mutant "JX16 document-mode after sha = the split's sha" "docjoin" \
  '    echo "- artifact_sha_after: ${DOC_AFTER}"' \
  '    echo "- artifact_sha_after: ${DOC_BEFORE}"'
mutant "JX17 document-mode artifact not root-relative" "docjoin" \
  '  [ -n "$_rootp" ] && case "$DOC_ABS" in "$_rootp"/*) DOC_REL="${DOC_ABS#"$_rootp"/}" ;; esac' \
  '  :'

# ---- BL-462 party-source mutants. A finding id collides across seats, so the key is (file, id).
# RENUMBERED AT THE MERGE: BL-462 shipped these as JX15..JX21, and BL-460's document-mode sha
# mutants above took JX15..JX17 on the other branch. The BL-460 ids stand; these moved, each
# killed set unchanged: JX15->JX18, JX16->JX19, JX17->JX20, JX18->JX21, JX19->JX22, JX20->JX23,
# JX21->JX24.
IDONLY_OLD='      if (!((b SUBSEP id) in has)) {'
IDONLY_NEW='      if (!(id in who)) {'
PROBE_OLD='src_probe() {'
PROBE_NEW='src_probe() { return 0; }
src_probe_disabled() {'
# JX18: the id-only key with the self-probe IN PLACE -- the probe refuses before any corpus is read,
# so every party run stops at it: the arms that expect a party join or a NAMED refusal all die.
# srcsetaside, srcpending, srcera and srcclosed (BL-508/519) die too: each is a --sources run, and the
# probe stops every one before its arm.
mutant "JX18 source keyed on the id alone (self-probe in place)" "sjnames party partyunres partynosrc partyforeign partydoc sjpartysrc srcok srcunres partymarked partyunmarked partyx1 partyx4 srcsetaside srcpending srcera srcclosed srchalf srccross" \
  "$IDONLY_OLD" "$IDONLY_NEW"
# JX19: the same key AND the probe removed -- now only the arms that seed an id another seat carries see it.
mutant2 "JX19 source keyed on the id alone, self-probe removed" "partyunres srcunres" \
  "$IDONLY_OLD" "$IDONLY_NEW" "$PROBE_OLD" "$PROBE_NEW"
mutant "JX20 an entry with no source line not refused" "partynosrc" \
  '      NOSOURCE)   refuse' \
  '      NOSOURCE)   :'
mutant "JX21 a source outside party-mode/s<N> not refused" "partyforeign" \
  '      if (!ok) { print "FOREIGN\t" $2 "\t" t; next }' \
  '      if (0) { print "FOREIGN\t" $2 "\t" t; next }'
# partyunmarked and partyx1 die too: with no party gate the seat-complete belt (BL-464) never runs.
mutant "JX22 files/document mode not a party repair for <name>-party" "partyunres partynosrc partyforeign partyunmarked partyx1" \
  'case "$ARTIFACT" in *-party) PARTY=1 ;; esac' \
  'case "$ARTIFACT" in *-never-a-name) PARTY=1 ;; esac'
mutant "JX23 subject --pass party not a party repair" "sjpartysrc" \
  '[ "$SUBJMODE" = 1 ] && [ "$PASS" = party ] && [ -z "$ARTIFACT" ] && PARTY=1' \
  'false && PARTY=1'
# srcsetaside and srcera die too: each refusal is reported and then acquitted by the same exit 0.
mutant "JX24 --sources reports refusals and exits 0" "srcunres srcsetaside srcera" \
  '  [ "$refuse_n" -eq 0 ] || exit 2
  [ "$SRCMODE" = 1 ] && echo "SOURCES:' \
  '  true || exit 2
  [ "$SRCMODE" = 1 ] && echo "SOURCES:'
# ---- BL-464 seat-complete belt: removed, and widened from the CITED seat files to the whole dir.
mutant "JX25 the seat-complete belt removed" "partyunmarked partyx1" \
  '  [ -n "$steps" ] || return 0' \
  '  return 0'
# JX26: the era decided over the CITED set only (the pre-batch-204 shape) -- X1 joins.
mutant "JX26 the marker era decided over the cited seat files only" "partyx1" \
  '  for f in "$sd"/*.md; do' \
  '  for f in $(printf '"'"'%s\n'"'"' "$cited" | sed "s@^@$sd/@"); do'
# JX27: the era not per step -- any marker anywhere holds every cited seat, so X4 refuses.
mutant "JX27 the marker era not decided per step" "partyx4" \
  '      case "$b" in "$st"-*)' \
  '      case "$b" in *)'
# ---- BL-508 / BL-519 entry contract. The self-probe refuses before any corpus is read, so a
# mutant the probe sees kills every join; those that reach a single arm are paired with the probe
# removed (mutant2), as JX19 is.
CTPROBE_OLD='contract_probe() {'
CTPROBE_NEW='contract_probe() { return 0; }
contract_probe_disabled() {'
mutant "JX28 the --sources siblings PENDING line not printed" "srcpending" \
  '    echo "PENDING: ${npend} repaired edit(s)' \
  '    : "PENDING: ${npend} repaired edit(s)'
# sibprose dies too: the word in prose, no field, is the same missing field.
mutant "JX29 a repaired edit with no siblings: not refused" "sibtotal sibmissing srcera sibdoc sibprose" \
  '    refuse "${r}: the ${d} entry is repaired with an edit and carries no' \
  '    : "${r}: the ${d} entry is repaired with an edit and carries no'
mutant "JX30 the set-aside refusal removed" "setaside srcsetaside setasideshard setasidenr" \
  '      SETASIDE) refuse' \
  '      SETASIDE) :'
# JX36 (D1): the era decided over the parts again -- parts mode binds only once some entry carries the
# field, so TOTAL omission reads PENDING and joins. sibmissing survives it: its parts 01/02 carry the field.
# sibdoc dies: its omitting part 1.md is read BEFORE the carriers 2.md and 3.md.
# sibprose dies too: its one part carries no field anywhere, so nothing opens the era.
mutant2 "JX36 parts mode era-gated on a carrier, self-probe removed" "sibtotal sibdoc sibprose" \
  '          else if (src == 0 || era) print "NOSIB\t" cf "\t" cur' \
  '          else if (era) print "NOSIB\t" cf "\t" cur' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
# JX37 (D3): no escalated entry is ever closed in --sources mode.
CLOSE_LINE='          for (k = 1; k <= ncl; k++) for (i = 1; i <= nesc; i++) if (cl[k] == ef[i] " " en[i]) ex[i] = 1'
# escopen and escclosed (--escalations) die too: one closure, two modes.
mutant2 "JX37 --sources closure removed, self-probe removed" "srcclosed srccross escopen escclosed" \
  "$CLOSE_LINE" \
  '          for (k = 1; k <= ncl; k++) for (i = 1; i <= nesc; i++) if (0) ex[i] = 1' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
# JX38 (D3): closure not order-keyed -- a `closes:` line written BEFORE the escalated entry closes
# it. Built by recording every repaired entry's closes: values and applying them at the end. Three
# layers: the self-probe's early closes: refuses every join under it, so the probe is removed to
# show srchalf owns the property on its own.
mutant3 "JX38 closure not order-keyed (an earlier closes: line closes), self-probe removed" "srchalf" \
  '        if (disp == "repaired" && src == 1)
'"$CLOSE_LINE" \
  '        if (disp == "repaired" && src == 1)
          for (k = 1; k <= ncl; k++) rcl[cl[k]] = 1' \
  "      for (i = 1; i <= nesc; i++) print (ex[i] ? \"X\" : \"E\") \"\\t\" ef[i] \"\\t\" en[i]" \
  "      for (i = 1; i <= nesc; i++) if ((ef[i] \" \" en[i]) in rcl) ex[i] = 1
      for (i = 1; i <= nesc; i++) print (ex[i] ? \"X\" : \"E\") \"\\t\" ef[i] \"\\t\" en[i]" \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
# JX42 (D2, the regression the second tip adversary named): closure keyed on the `source:` token
# again -- any LATER repaired entry carrying the escalation's token, cut to its basename as the
# f0d0af91 join cut it, closes it. srchalf is graph's dev-05#F-3 shape; srccross dies too, because
# the serial entry shares the token of BOTH parts' escalations.
mutant3 "JX42 closure keyed on the source: token, self-probe removed" "srchalf srccross escopen escclosed" \
  '        if (disp ~ /^escalat/) { nesc++; ef[nesc] = part; en[nesc] = cur; ex[nesc] = 0 }
        if (disp == "repaired" && src == 1)
'"$CLOSE_LINE" \
  '        if (disp ~ /^escalat/) { nesc++; ef[nesc] = part; en[nesc] = cur; ex[nesc] = 0; es[nesc] = st }
        if (disp == "repaired" && src == 1)
          for (i = 1; i <= nesc; i++) if (st != "" && es[i] == st) ex[i] = 1
        st = ""' \
  '    /^[[:space:]-]*[*_`]*closes[*_`]*:/ {' \
  '    /^[[:space:]-]*[*_`]*source[*_`]*:/ { v = $0; sub(/^[^:]*:/, "", v); sub(/.*\//, "", v); st = trim(v); inclaim = 0; next }
    /^[[:space:]-]*[*_`]*closes[*_`]*:/ {' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
# JX43: the closes: key reads the heading alone, so naming one part's escalation closes every part's.
mutant2 "JX43 closure keyed on the heading alone (part ignored), self-probe removed" "srccross" \
  "$CLOSE_LINE" \
  '          for (k = 1; k <= ncl; k++) for (i = 1; i <= nesc; i++) if (substr(cl[k], index(cl[k], " ") + 1) == en[i]) ex[i] = 1' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
mutant "JX44 ESCALATED-CLOSED lines not printed" "srcclosed srccross escopen escclosed" \
  '  printf '"'"'%s'"'"' "$ESC_CLOSED"' \
  '  :'
# ---- the BLOCKER: SERIAL-REQUIRED, the count that dispatches the serial remediator for the
# cross-file sibling grep and moved cites no shard can run.
mutant "JX45 SERIAL-REQUIRED not printed" "docjoin sibok handoff" \
  'echo "SERIAL-REQUIRED: ${SERIAL_N}"' \
  ':'
# JX46: counted over every repaired entry, `edit: n/a` included -- sibok reads 6, not 3.
mutant2 "JX46 SERIAL-REQUIRED counts repaired entries with no edit, self-probe removed" "sibok" \
  '        if (disp == "repaired" && edt) nrep++' \
  '        if (disp == "repaired") nrep++' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
# ---- the NOSIB remedy and the siblings arm's reach.
mutant "JX47 the pre-install re-dispatch remedy dropped" "sibtotal sibdoc" \
  '  [ "$srcm" = 0 ] && remedy=' \
  '  false && remedy='
mutant "JX48 the pre-install remedy printed in --sources mode too" "srcera" \
  '  [ "$srcm" = 0 ] && remedy=' \
  '  remedy='
mutant "JX49 the siblings arm applied in files mode only" "sibdoc" \
  '    [ -n "$r" ] || continue
    refuse "${r}: the ${d} entry is repaired with an edit' \
  '    [ -n "$r" ] || continue
    [ "$DOCMODE$SUBJMODE" = 00 ] || continue
    refuse "${r}: the ${d} entry is repaired with an edit'
# JX39/JX40 (N1): the set-aside regex cut to ONE half each; the probe's offender carries both halves.
mutant "JX39 set-aside regex cut to 'not required' only" "setasideshard" \
  'claim ~ /outside (this|my|the) (shard|part|section)|not required/' \
  'claim ~ /not required/'
mutant "JX40 set-aside regex cut to the shard phrase only" "setasidenr" \
  'claim ~ /outside (this|my|the) (shard|part|section)|not required/' \
  'claim ~ /outside (this|my|the) (shard|part|section)/'
mutant "JX41 --sources prints no ESCALATED-COUNT line" "srcclosed srchalf srccross escopen escclosed" \
  '  echo "ESCALATED-COUNT: ${ESC_N} (${ESC_X} closed' \
  '  : "ESCALATED-COUNT: ${ESC_N} (${ESC_X} closed'
mutant2 "JX31 the set-aside hand-off exemption removed, self-probe removed" "handoff" \
  '            && claim !~ /escalat|serial remediator/) print "SETASIDE' \
  '            ) print "SETASIDE' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
# escclosed dies too: its serial entry, edit: n/a, then reads as a repaired edit with no siblings: after a carrier.
mutant2 "JX32 an n/a edit read as a real edit, self-probe removed" "sibok escclosed" \
  '      if (match(v, /[A-Za-z0-9_.\/-]+[.](md|json|jsonl|yaml|yml|txt|csv)/)) edt = 1' \
  '      edt = 1' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
mutant2 "JX33 every heading read as MAJOR, self-probe removed" "sibok" \
  '                 sev = (h ~ /(^|[^A-Z])(CRITICAL|MAJOR)([^A-Z]|$)/); next }' \
  '                 sev = 1; next }' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
mutant "JX34 the joined run prints no ESCALATED: lines" "sibok handoff escpath" \
  '# "Adversarial repair dispatch").
printf '"'"'%s'"'"' "$ESC_LINES"' \
  '# "Adversarial repair dispatch").
:'
# escopen and escclosed die too: --escalations runs the same record_tail.
mutant "JX35 --sources does not apply the entry contract" "srcsetaside srcpending srcera srcclosed srchalf srccross escopen escclosed" \
  '  contract_refusals 1 "$(contract_check 1 "$1")"' \
  '  ESC_LINES=""; ESC_CLOSED=""; ESC_N=0; ESC_X=0'
# ---- the four siblings forms, the point-in-time fence, escalated citations, --escalations.
SIBREAD='    /^[[:space:]-]*[*_`]*siblings[*_`]*:/ { sibf = 1; v = $0; sub(/^[^:]*:/, "", v); v = vtrim(v); if (v == "") sibw = 1; else if (v in SIBNA) sib = 1; inclaim = 0; next }'
# JX50: the tip adversary's m508 -- the siblings reader loosened to any line mentioning the word.
mutant2 "JX50 siblings read off any line mentioning the word, self-probe removed" "srcera sibforms sibprose sibnever" \
  "$SIBREAD" \
  '    /[Ss]iblings?/ { sib = 1 }' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
# JX51: the field's PRESENCE read as the field (the reader this branch shipped first).
mutant2 "JX51 any siblings: spelling accepted, self-probe removed" "sibforms sibnever" \
  "$SIBREAD" \
  '    /^[[:space:]-]*[*_`]*siblings[*_`]*:/ { sibf = 1; sib = 1; inclaim = 0; next }' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
mutant2 "JX52 a derived siblings fence accepted as the text form, self-probe removed" "sibforms" \
  '                            if (b == "```text") {' \
  '                            if (b == "```text" || b == "```derived") {' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
mutant "JX53 the siblings control not counted at the join" "sibnever" \
  '      CTL) sib_control "$r" "$d" "$l" "$m" ;;' \
  '      CTL) : ;;'
mutant "JX54 an escalated entry's edit: path counted as a shard citation" "escpath" \
  '    function emit(   i) { if (disp !~ /^escalat/) for (i = 1; i <= nt; i++) print tk[i]; nt = 0; disp = "" }' \
  '    function emit(   i) { for (i = 1; i <= nt; i++) print tk[i]; nt = 0; disp = "" }'
mutant "JX55 --escalations runs as --sources (needs a seat dir)" "escopen escclosed" \
  '    --escalations) SRC_REC="${2:-}"; SRCMODE=2; shift 2 ;;' \
  '    --escalations) SRC_REC="${2:-}"; SRCMODE=1; shift 2 ;;'
# ---- the re-run window (--rerun <part>.md@<ISO>). Expected sets are the measured kills; the
# re-run predicates' ALLOW twins (rrgraph, rrfiles, rrsubj) run in the same battery. JX59 is killed
# only by rrlate's second spelling: outside F_P the OUT line fires beside LATE, so no verdict moves.
# JX58 kills rrlate too, for the same reason. JX60 kills rrsame on VERDICT: narrowed, the same id
# leaves one writer and the mutant joins. JX63 kills alresult too: a shared path aliases it.
RR_DROP='          if ((f in fp) && t < S[fp[f]]) {
            p = fp[f]; drop[i] = 1; sw[p, a] = 1'
# JX56: no narrowing -- nothing is superseded, so the re-run part keeps every writer.
mutant "JX56 --rerun narrows nothing" "rrgraph rrout rrlate rrlatein rrsame rrfiles rrsubj" \
  "$RR_DROP" \
  '          if (0) {
            p = fp[f]; drop[i] = 1; sw[p, a] = 1'
# JX57: S_P applied to every part's files, not only to the re-run part's.
mutant "JX57 the re-run start applied to every part" "rrgraph rrspan rrfiles rrsubj" \
  "$RR_DROP" \
  '          if (t < S[PP[1]]) {
            p = PP[1]; drop[i] = 1; sw[p, a] = 1'
mutant "JX58 refusal 3 removed (a superseded writer outside F_P)" "rrout rrlate" \
  '        OUT)  refuse' \
  '        OUT)  :'
mutant "JX59 refusal 4 removed (a superseded writer still writing)" "rrlate" \
  '        LATE) refuse' \
  '        LATE) :'
mutant "JX60 the new-id rule removed" "rrlatein rrsame" \
  '        SAME) refuse' \
  '        SAME) :'
# ---- the alias rule. Clause 2 is two layers -- the recorded agent_transcript and the join-time
# file test -- and both are reverted.
mutant2 "JX61 alias clause 2 dropped (A may have a transcript)" "alown" \
  '[ "$_tuid" != "-" ] && [ "$_atr" = false ] && [ "$_tpath" != "-" ]' \
  '[ "$_tuid" != "-" ] && [ "$_tpath" != "-" ]' \
  '      [ -e "${_sd}/subagents/agent-${_A}.jsonl" ] && continue' \
  '      :'
# JX62: clause 3 by grep -- any line of B's transcript carrying the id, a tool_result included,
# read as one Edit of the file, so the later name and path checks still pass.
mutant "JX62 alias clause 3 by grep, not a parsed tool_use" "alresult" \
  '        _blk="$(tu_blocks "${_sd}/subagents/agent-${_B}.jsonl" "$_tuid")"' \
  '        _blk="$(grep -qF -- "$_tuid" "${_sd}/subagents/agent-${_B}.jsonl" 2>/dev/null && printf "Edit\t%s\n" "$_f")"'
# JX63: a shared transcript_path read as one writer -- clause 3 and its name/path checks replaced.
# Single-quoted literals, never a quoted heredoc inside $( ): bash 3.2 expands that body.
_T="$(printf '\t')"; _Q="'"
AL_C3='        _blk="$(tu_blocks "${_sd}/subagents/agent-${_B}.jsonl" "$_tuid")"
        [ "$(printf '"$_Q"'%s\n'"$_Q"' "$_blk" | grep -c .)" = 1 ] || continue
        _bn="${_blk%%'"$_T"'*}"; _bfp="${_blk#*'"$_T"'}"
        case "$_bn" in Edit|Write|MultiEdit) ;; *) continue ;; esac
        [ "$(hook_norm "$_bfp")" = "$_f" ] || continue'
AL_TP='        _btp="$(printf '"$_Q"'%s\n'"$_Q"' "$DROWS" | awk -F'"$_Q"'\t'"$_Q"' -v f="$_f" -v b="$_B" '"$_Q"'$1 == f && $2 == b { print $6; exit }'"$_Q"')"
        [ "$_btp" = "$_tpath" ] || continue'
mutant "JX63 alias on a shared transcript_path" "alresult alsecond" "$AL_C3" "$AL_TP"
# ---- END JX MUTANTS.

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

# THE JUDGMENT, PROBED ON A REAL VERDICT. The first MUTANT verdict this shard dispatched (the first
# row whose expected set is not the control's NONE) is copied aside and judged four ways against a
# scratch counter: its own expected set must PASS (else the probe proves nothing about a judge that
# always fails), a deliberately wrong set must FAIL, a TIMEOUT marker beside it must FAIL, and the
# same stem with the verdict file deleted must FAIL. The wrong set is a predicate name no P_ALL
# member carries, so it can equal no mutant's.
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
