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
#     missing verdict, a STALL record, or an evaluated count other than |P_ALL| as a FAIL;
#   - the mutants DECLARED in this file are dealt across the shards and joined before dispatch
#     ([J0], below), and the number this shard dispatches must equal the number dealt to it ([J2]),
#     so a battery whose mutant calls were deleted fails rather than reporting a clean control;
#   - `judge` itself is probed every run, on a real verdict file, in both directions.
# The pool is a FIXED width of 8 (no knob); completion is read from sentinel files the scorers
# write, never from the process table.
#
# THE WATCHDOG IS KEYED ON NO PROGRESS, NEVER ON ELAPSED TIME. bash 3.2 has no `wait -n`, so each
# scorer runs under a slot that polls it. Every SCORER_POLL seconds the slot asks whether the
# scorer has ADVANCED since its last advance -- rewritten its stage file `$VD/<id>.at` (one write
# per predicate) or written any file under its own scratch `$WORK/mut-<id>/` (every join run
# writes JO there) -- with `find -newer` against a mark the slot rotates on every advance. Only a
# scorer that has neither exited nor advanced for SCORER_IDLE seconds is stopped: the slot writes a
# `.stalled` record and kills the scorer's whole process tree (stopped first, then children before
# parents, so nothing reparents to init and keeps spinning), and the reap REFUSES the fixture, exit
# 2, naming the scorer and the marker. A stall is a harness that wedged, not a verdict about a
# mutant, so it is never a FAIL row. A slow scorer on a loaded box keeps writing and is never
# touched, however long it runs: the fixed 900s wall bound this replaced turned load into a red
# row, which is self-inflicted. SCORER_IDLE is sized to the longest single step that writes
# nothing -- one join run -- and that is seconds; the 300s window is deliberately two orders of magnitude over it: a margin over one observed step, not a measurement; a refusal costs a re-run, never a verdict. THE TRADE: a scorer that writes forever never
# stalls, and the pool's dispatch wait then waits on it; the bound on that wait is that every slot
# ends, by exit or by this refusal.
#
# THE SHARDS. The pre-push suite is POLE-BOUND: its makespan tracks its single longest DIRECTORY,
# and this battery, 63 mutants in one unit, was that directory at 1051s loaded (404s solo). So the
# mutant set is dealt across five units, this directory (shard a) and the one-line drivers
# `remediator-shard-join-mutants-b`, `-c`, `-d` and `-e`, each `exec bash "$IMPL" --group <x>`, the shape
# `review-shard-merge-mutants` carries. Every scorer runs every predicate, so the cost per mutant
# is roughly uniform and an equal count balances: 18-20 each, in declaration order by family. Shard d
# was added when 72 mutants over three shards measured 245-295s solo each, and shard e when the
# declared set grew past 90.
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
SHARDS="a b c d e"
MUTANTS_a="JX1 JX2 JX3 JX4 JX5 JX6 JX7 JX8 JX10 JX9 JX11 JX12 JX13 JX14 JX15 JX16 JX17 JX18 JX110"
MUTANTS_b="JX19 JX20 JX21 JX22 JX23 JX24 JX25 JX26 JX27 JX28 JX29 JX30 JX36 JX37 JX38 JX42 JX43 JX44 JX95"
MUTANTS_c="JX45 JX46 JX47 JX48 JX49 JX39 JX40 JX41 JX31 JX32 JX33 JX34 JX35 JX50 JX51 JX52 JX53 JX54 JX93 JX94"
MUTANTS_d="JX55 JX56 JX57 JX58 JX59 JX60 JX61 JX62 JX63 JX64 JX65 JX66 JX67 JX68 JX69 JX70 JX71 JX72 JX73 JX111 JX112"
MUTANTS_e="JX74 JX75 JX76 JX77 JX78 JX79 JX80 JX81 JX82 JX83 JX84 JX85 JX86 JX87 JX88 JX89 JX90 JX91 JX92 JX96 JX97"
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
SCORER_POLL=5
SCORER_IDLE=300
VD="$WORK/verdicts"; mkdir -p "$VD" || { echo "FIXTURE ERROR: cannot create $VD" >&2; exit 2; }
IDX="$WORK/dispatch.tsv"; : > "$IDX"
NDISP=0

# One scorer: every predicate against <join>, in P_ALL order, in its own scratch.
scorer() { # <id> <label> <join>
  trap - EXIT
  local id="$1" label="$2" j="$3" sw p n=0 dead=""
  sw="$WORK/mut-$id"; mkdir -p "$sw" || exit 1
  WORK="$sw"; bind_scratch "$sw"; RC=""
  for p in $P_ALL; do n=$((n + 1)); printf '%s\n' "$p" > "$VD/$id.at"; "p_$p" "$j" || dead="$dead $p"; done
  dead="${dead# }"
  printf '%s\t%s\t%s\n' "$label" "$n" "$dead" > "$VD/$id.tmp" && mv "$VD/$id.tmp" "$VD/$id.v"
}
killtree() { # <pid>: stop it, take its children down first, then it
  local c
  kill -STOP "$1" 2>/dev/null
  for c in $(pgrep -P "$1" 2>/dev/null); do killtree "$c"; done
  kill -9 "$1" 2>/dev/null
}
slot() { # <id> <label> <join>: the scorer under its no-progress watchdog, then the completion sentinel
  trap - EXIT
  local id="$1" s t=0 idle=0 mk="$VD/$1.mark" sc="$WORK/mut-$1"
  : > "$mk"
  ( scorer "$@" ) &
  s=$!
  while kill -0 "$s" 2>/dev/null; do
    sleep 1; t=$((t + 1))
    [ "$((t % SCORER_POLL))" -eq 0 ] || continue
    : > "$mk.next"
    if [ -n "$(find "$VD/$id.at" "$sc" -newer "$mk" -print -quit 2>/dev/null)" ]; then
      mv "$mk.next" "$mk"; idle=0
    else
      idle=$((idle + SCORER_POLL))
      if [ "$idle" -ge "$SCORER_IDLE" ]; then
        printf '%s: the scorer neither exited nor advanced its progress marker (%s, or any file under %s) for %ss; its tree was killed\n' \
          "$2" "$VD/$id.at" "$sc" "$SCORER_IDLE" > "$VD/$id.stalled"
        killtree "$s"; break
      fi
    fi
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
  if [ -e "$stem.stalled" ]; then printf '%s: STALLED -- the scorer made no progress for %ss and was killed; no verdict\n' "$label" "$SCORER_IDLE"; return 1; fi
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
mutant "JX1 the >1-writer refusal removed" "overlap docoverlap sjspec2 rrgraph rrspan rrfiles rrsubj alnokeys nested" \
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
# rrfiles dies too: its re-run writer's part-record Write becomes a written file no part cites.
mutant2 "JX3 the shards/ exclusion removed" "shardrow rrfiles" \
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
# sjspecfresh and sjspecnone die for sjoin's reason: each is a subject join that must JOIN, and its prd
# section parts cite copies under shards/ whose rows are now dropped, so they read UNWRITTEN. sjspecstale
# does NOT: the join still reaches the SPEC render arm and refuses the stale memlog by name, as it expects.
mutant2 "JX4 section rows dropped in document mode (the pre-BL-372 file set)" "docjoin docoverlap asmrefuse sjoin sjnames sjgate sjnest partydoc sibdoc rrgraph rrout rrlate rrlatein rrsame rrspan rrprlate rrprout rrprforeign rrprnone rrreuse rrsubj rronly sjspecfresh sjspecnone" \
  "   $SHF
$SHF_ROWS" \
  "   | select((.path | startswith(\$sh + \"/\")) | not)
$SHF_ROWS" \
  "     $SHF
$SHF_DROWS" \
  "     | select((.path | startswith(\$sh + \"/\")) | not)
$SHF_DROWS"
# rrgraph asserts the re-run writer's edit reached the assembled document.
mutant "JX5 the assembly skipped" "docjoin asmrefuse partydoc rrgraph rronly" \
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
mutant "JX18 source keyed on the id alone (self-probe in place)" "sjnames party partyunres partynosrc partyforeign partydoc sjpartysrc srcok srcunres partymarked partyunmarked partyx1 partyx4 srcsetaside srcpending srcera srcclosed srchalf srccross srcparts fencenest" \
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
mutant "JX24 --sources reports refusals and exits 0" "srcunres srcsetaside srcera dispkey dispvocab dispruling chkrec rulingedit rulingtab chkjoined specstale specunread chkserial supchain" \
  '  [ "$refuse_n" -eq 0 ] || exit 2
  printf '"'"'%s\n'"'"' "$SPEC_LINE"
  exit 0
}' \
  '  true || exit 2
  printf '"'"'%s\n'"'"' "$SPEC_LINE"
  exit 0
}'
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
mutant "JX29 a repaired edit with no siblings: not refused" "sibtotal sibmissing srcera sibdoc sibprose rulingedit partsilent" \
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
# supchain dies too (BY READING): its fold cell asserts `1 closed`, which no closure can give.
mutant2 "JX37 --sources closure removed, self-probe removed" "srcclosed srccross escopen escclosed specfresh spechand specnone spectwo specother specunread supchain" \
  "$CLOSE_LINE" \
  '          for (k = 1; k <= ncl; k++) for (i = 1; i <= nesc; i++) if (0) ex[i] = 1' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
# JX38 (D3): closure not order-keyed -- a `closes:` line written BEFORE the escalated entry closes
# it. Built by recording every repaired entry's closes: values and applying them at the end. Three
# layers: the self-probe's early closes: refuses every join under it, so the probe is removed to
# show srchalf owns the property on its own.
# supchain dies too (MEASURED on a copy with all three layers): closure applied after the chain resolves
# reads `ESCALATED-COUNT: 0` and drops CHAIN-OPEN, hiding the open part member -- BL-565's own property.
mutant3 "JX38 closure not order-keyed (an earlier closes: line closes), self-probe removed" "srchalf supchain" \
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
# supchain dies too (BY READING): its fold entry carries no source: line, so a token closure closes nothing.
mutant3 "JX42 closure keyed on the source: token, self-probe removed" "srchalf srccross escopen escclosed specfresh spechand specnone spectwo specother specunread supchain" \
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
# supchain dies too (MEASURED): ESCALATED-SUPERSEDED lines are appended to $ESC_CLOSED, so they go with it.
mutant "JX44 ESCALATED-CLOSED lines not printed" "srcclosed srccross escopen escclosed supchain" \
  '  printf '"'"'%s'"'"' "$ESC_CLOSED"' \
  '  :'
# ---- the BLOCKER: SERIAL-REQUIRED, the count that dispatches the serial remediator for the
# cross-file sibling grep and moved cites no shard can run.
mutant "JX45 SERIAL-REQUIRED not printed" "docjoin sibok handoff" \
  'echo "SERIAL-REQUIRED: ${SERIAL_N}"' \
  ':'
# JX46: counted over every repaired entry, `edit: n/a` included -- sibok reads 6, not 3.
mutant2 "JX46 SERIAL-REQUIRED counts repaired entries with no edit, self-probe removed" "sibok" \
  '        if (rp && edt) nrep++' \
  '        if (rp) nrep++' \
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
mutant "JX41 --sources prints no ESCALATED-COUNT line" "srcclosed srchalf srccross escopen escclosed gapfill rulingedit specfresh spechand specnone spectwo specother specunread chkserial supchain gaploc fencenest" \
  '  echo "ESCALATED-COUNT: ${ESC_N} (${ESC_X} closed' \
  '  : "ESCALATED-COUNT: ${ESC_N} (${ESC_X} closed'
mutant2 "JX31 the set-aside hand-off exemption removed, self-probe removed" "handoff" \
  '            && claim !~ /escalat|serial remediator/) print "SETASIDE' \
  '            ) print "SETASIDE' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
# escclosed dies too: its serial entry, edit: n/a, then reads as a repaired edit with no siblings: after a carrier.
mutant2 "JX32 an n/a edit read as a real edit, self-probe removed" "sibok escclosed rulingedit" \
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
mutant "JX35 --sources does not apply the entry contract" "srcsetaside srcpending srcera srcclosed srchalf srccross escopen escclosed dispkey dispvocab dispruling gapfill rulingedit rulingtab chkjoined specfresh spechand specnone spectwo specother specunread chkserial supchain gaploc fencenest" \
  '  contract_refusals 1 "$(contract_check 1 "$1")"' \
  '  ESC_LINES=""; ESC_CLOSED=""; ESC_N=0; ESC_X=0'
# ---- the four siblings forms, the point-in-time fence, escalated citations, --escalations.
SIBREAD='    /^[[:space:]-]*[*_`]*siblings[*_`]*:/ { sibf = 1; v = $0; sub(/^[^:]*:/, "", v); v = vtrim(v); if (v == "") sibw = 1; else if (v in SIBNA) sib = 1; inclaim = 0; next }'
# JX50: the tip adversary's m508 -- the siblings reader loosened to any line mentioning the word.
mutant2 "JX50 siblings read off any line mentioning the word, self-probe removed" "srcera sibforms sibprose sibnever dispvocab rulingedit" \
  "$SIBREAD" \
  '    /[Ss]iblings?/ { sib = 1 }' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
# JX51: the field's PRESENCE read as the field (the reader this branch shipped first).
mutant2 "JX51 any siblings: spelling accepted, self-probe removed" "sibforms sibnever" \
  "$SIBREAD" \
  '    /^[[:space:]-]*[*_`]*siblings[*_`]*:/ { sibf = 1; sib = 1; inclaim = 0; next }' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
mutant2 "JX52 a derived siblings fence accepted as the text form, self-probe removed" "sibforms" \
  '                  if (b == "```text") {' \
  '                  if (b == "```text" || b == "```derived") {' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
mutant "JX53 the siblings control not counted at the join" "sibnever" \
  '      CTL) sib_control "$r" "$d" "$l" "$m" ;;' \
  '      CTL) : ;;'
mutant "JX54 an escalated entry's edit: path counted as a shard citation" "escpath" \
  '    function emit(   i) { if (disp !~ /^escalat/) for (i = 1; i <= nt; i++) print tk[i]; nt = 0; disp = "" }' \
  '    function emit(   i) { for (i = 1; i <= nt; i++) print tk[i]; nt = 0; disp = "" }'
mutant "JX55 --escalations runs as --sources (needs a seat dir)" "escopen escclosed dispkey dispvocab dispruling gapfill chkrec rulingedit rulingtab chkjoined specstale specfresh spechand specnone spectwo specother specunread chkserial supchain gaploc fencenest" \
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
# rrprlate and rrprout die too: with nothing superseded the original is no superseded writer.
mutant "JX56 --rerun narrows nothing" "rrgraph rrout rrlate rrlatein rrsame rrprlate rrprout rrfiles rrsubj rronly" \
  "$RR_DROP" \
  '          if (0) {
            p = fp[f]; drop[i] = 1; sw[p, a] = 1'
# JX57: S_P applied to every part's files, not only to the re-run part's.
mutant "JX57 the re-run start applied to every part" "rrgraph rrspan rrfiles rrsubj rronly" \
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
# altwo and altool die too: the grep stand-in reads one Edit whatever the count or the tool name.
mutant "JX62 alias clause 3 by grep, not a parsed tool_use" "alresult altwo altool" \
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
mutant "JX63 alias on a shared transcript_path" "alresult alsecond altwo altool" "$AL_C3" "$AL_TP"
# The three clauses the tip adversary found untestable (its W6, W7, W9), each now owned by one arm.
mutant "JX64 alias clause 1 session match dropped" "alsess" \
  '        [ "$_bs" = "$_sess" ] || continue' \
  '        :'
mutant "JX65 alias clause 3 exactly-one relaxed to at-least-one" "altwo" \
  '        [ "$(printf '"$_Q"'%s\n'"$_Q"' "$_blk" | grep -c .)" = 1 ] || continue' \
  '        [ -n "$_blk" ] || continue; _blk="$(printf '"$_Q"'%s\n'"$_Q"' "$_blk" | head -1)"'
mutant "JX66 alias clause 3 tool-name check dropped" "altool" \
  '        case "$_bn" in Edit|Write|MultiEdit) ;; *) continue ;; esac' \
  '        :'
# ---- the part-record refusals: the account's author, read off rows under the repair dir.
mutant "JX67 a superseded writer's part-record row after S_P not refused" "rrprlate" \
  '        PRLATE) refuse' \
  '        PRLATE) :'
mutant "JX68 a superseded writer's row on another part's record not refused" "rrprout" \
  '        PROUT) refuse' \
  '        PROUT) :'
mutant "JX69 a foreign row on the re-run part's own record after S_P not refused" "rrprforeign" \
  '        PRFOREIGN) refuse' \
  '        PRFOREIGN) :'
mutant "JX70 a re-run with no row on its own part record not refused" "rrprnone rronly" \
  '        PRNONE) refuse' \
  '        PRNONE) :'
mutant "JX71 a re-run writer with rows outside its part not refused" "rrreuse" \
  '        RWOUT) refuse' \
  '        RWOUT) :'
# JX72: only the part-record half of the re-run writer's reach removed; rrreuse asserts both spellings.
mutant "JX72 a re-run writer's row on another part's record not refused" "rrreuse" \
  '            if (((p, a) in rw) && b != p && !((p, a, b, "R") in pq)) {' \
  '            if (0) {'
# ---- BL-542: the renamed key, the vocabulary, the operator-ruling cite. The self-probe sees each, so
# each is paired with the probe removed (mutant2), as JX36 is.
mutant2 "JX73 an edit: entry with no disposition: not refused, self-probe removed" "dispkey" \
  '      if (disp == "" && edf) print "NODISP\t" cf "\t" cur' \
  '      if (0) print "NODISP\t" cf "\t" cur' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
mutant2 "JX74 a value outside the vocabulary not refused, self-probe removed" "dispvocab" \
  '        if ((src == 0 || era) && !(dfull in VOC)) print "BADDISP\t" cf "\t" cur "\t" draw' \
  '        if (0) print "BADDISP\t" cf "\t" cur "\t" draw' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
mutant "JX75 an operator-ruling cite not resolved" "dispruling" \
  '  [ "$n" -ge 1 ] || refuse "${r}: the ${d} entry'"'"'s ruling cite' \
  '  true || refuse "${r}: the ${d} entry'"'"'s ruling cite'
# ---- BL-561: the part-token refusal removed; BL-556: the gap-fill tripwire removed (probe paired off).
mutant "JX76 --sources on a part-token record not refused" "srcparts" \
  '  [ "$(src_kind "$SRC_REC")" = PART ] \' \
  '  [ "$(src_kind "$SRC_REC")" = NEVER ] \'
mutant2 "JX77 the gap-fill tripwire removed, self-probe removed" "gapfill gaploc fencenest" \
  '        if (disp == "repaired" && claim ~ /gap[- ]?fill|veto/) print "GAPFILL\t" cf "\t" cur' \
  '        if (0) print "GAPFILL\t" cf "\t" cur' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
# ---- BL-557: the parts-mode call removed; the record-mode era removed (every record binds). The
# self-probe sees the second, so it is paired off. JX79's set is WIDE BY CONSTRUCTION: the era is the
# only line letting a record that writes neither field pass, and every --sources and --escalations
# world here writes neither, so removing it refuses each of them. That breadth is the property --
# one predicate's death would mean the era guarded one world -- and chkrec is the arm that owns it
# (its first half is a field-less record that must pass). gapfill dies too: since the gap-fill
# tripwire reports instead of refusing, its record must exit 0, and it writes neither field.
mutant "JX78 the check fields not read in parts mode" "chkpart" \
  '  checks_refusals "$(checks_field 0 "$p")"' \
  '  :'
mutant2 "JX79 the record-mode era removed (a record with neither field binds), self-probe removed" "srcok srcpending srcclosed srchalf srccross escopen escclosed dispruling srcparts gapfill chkrec rulingtab chkjoined specfresh spechand specnone spectwo specother chkserial supchain gaploc fencenest" \
  '      if (mode == "E" && sa + sd == 0) return' \
  '      if (0) return' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
# JX80: the gap-fill report turned back into a refusal (the shape that hid s319's escalations): the
# record exits 2 before its count, which p_gapfill's rc 0 and ESCALATED-COUNT assertions see.
mutant "JX80 the gap-fill report made a refusal again" "gapfill gaploc fencenest" \
  '      GAPFILL) GAP_N=$((GAP_N + 1)); GAP_LINES=' \
  '      GAPFILL) refuse "gap fill"; GAP_N=$((GAP_N + 1)); GAP_LINES='
# ---- the third tip adversary's four. JX81: a ruling held to nothing again (keyed on repaired alone);
# the self-probe sees no operator-ruling entry, so it stays in place.
mutant "JX81 an operator-ruling edit escapes the repaired-edit checks" "rulingedit" \
  '        rp = (disp == "repaired" || dfull == "operator-ruling")' \
  '        rp = (disp == "repaired")'
mutant "JX82 a TAB in a heading kept, so it splits the finding's fields" "rulingtab" \
  'sub(/^#+[ \t]+/, "", cur); gsub(/[\t\r]/, " ", cur); cur = trim(cur)' \
  'sub(/^#+[ \t]+/, "", cur); cur = trim(cur)'
mutant "JX83 a CR kept on a ruling cite" "rulingtab" \
  '    function vtrim(v) { gsub(/^[ \t*_`\r]+|[ \t*_`\r]+$/, "", v); return v }' \
  '    function vtrim(v) { gsub(/^[ \t*_`]+|[ \t*_`]+$/, "", v); return v }'
# JX84 is paired off: with the markers ignored, the serial self-probe cell sernt.md reads as an unmarked
# record and the probe dies in every join.
mutant2 "JX84 the check fields judged per file again, not per shard segment, self-probe removed" "chkjoined" \
  '    rec == 1 && /^<!-- shard: [^ ]+ -->[ \t]*$/ { brk("M");' \
  '    rec == 1 && /^<!-- shard: [^ ]+ -->[ \t]*$/ { next; brk("M");' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
# JX85: a refused parts join prints the escalation report before its exit, as record mode does.
mutant "JX85 a refused parts join prints the escalation report" "partsilent" \
  '[ "$refuse_n" -eq 0 ] || exit 2

# --- document mode' \
  '[ "$refuse_n" -eq 0 ] || { printf '"'"'%s'"'"' "$ESC_LINES"; echo "ESCALATED-COUNT: ${ESC_N}"; exit 2; }

# --- document mode'
# ---- the SPEC render arm (BL-546/560). SELF-PROBE CONVENTION: a mutant the spec_render_probe sees dies
# `die`-ing in every join, so every predicate would fail and the kill would be the probe's, not the
# arm's. Following JX19/JX36/JX37, such a mutant (JX86, JX88) is mutant2 with the probe removed, so the
# named arm owns the property on its own; JX87 and JX89 sit below the probe and need no pairing.
SPROBE_OLD='spec_render_probe() {'
SPROBE_NEW='spec_render_probe() { return 0; }
spec_render_probe_disabled() {'
# JX86: the Render key loses its phrase test, so a hand edit's unphrased Render reads as a render and
# the decision after it is refused. Only spechand holds an unphrased Render.
mutant2 "JX86 an unphrased Render line counted as a render, self-probe removed" "spechand" \
  '(event([[:space:]][^)]*)?\)[[:space:]]+Render/ && index($0, ph) {' \
  '(event([[:space:]][^)]*)?\)[[:space:]]+Render/ {' \
  "$SPROBE_OLD" "$SPROBE_NEW"
# JX87: the no-render SKIP refuses. Only the unphrased-Render world reaches that branch with a memlog
# (specnone and spectwo take the empty-memlog branch above it, which this leaves alone).
mutant "JX87 a memlog with no phrased Render refused instead of skipped" "spechand" \
  '    SPEC_LINE="SPEC-RENDER: SKIP -- ${m} carries no' \
  '    refuse "SKIP -- ${m} carries no'
# JX88: the order test inverted -- decisions BEFORE the render are counted and a render no longer resets
# them. stale reports 2 at line 1, fresh is refused outright; a non-empty-set pair, one per direction.
# THREE layers, so mutant3: the two order anchors AND the self-probe. As mutant2 it carried only the two
# anchors, its label's "self-probe removed" was false, the probe read the inverted scan and `die`d in
# every join that reached it, and the mutant killed every predicate there (25 beyond its set).
mutant3 "JX88 the order test inverted (decisions before the render counted), self-probe removed" "specstale specfresh sjspecstale sjspecfresh" \
  '{ r = NR; n = 0; f = 0; next }' \
  '{ r = NR; next }' \
  '/^[[:space:]]*[-*][[:space:]]*\(decision([[:space:]][^)]*)?\)/ { if (r) {' \
  '/^[[:space:]]*[-*][[:space:]]*\(decision([[:space:]][^)]*)?\)/ { if (!r) {' \
  "$SPROBE_OLD" "$SPROBE_NEW"
# JX89: record_tail runs the render check and then restores refuse_n, discarding whatever the call refused (the JX91 shape,
# so an earlier refusal stands). specstale and specunread both expect a refusal FROM THAT CALL, so both die: one call
# site, two refusals. The SPEC-RENDER line is still printed for the rest.
mutant "JX89 the record_tail SPEC render refusal discarded" "specstale specunread" \
  '    spec_render_check "$SPEC_MEMLOG" "$SPEC_WHY"' \
  '    _rn0=$refuse_n; spec_render_check "$SPEC_MEMLOG" "$SPEC_WHY"; refuse_n=$_rn0'
# JX90: the empty-memlog SKIP (no memlog, or several) refuses instead. specnone and spectwo reach that
# branch; spechand has a memlog and takes the no-render branch JX87 owns.
mutant "JX90 an absent or ambiguous spec memlog refused instead of skipped" "specnone spectwo" \
  '  if [ -z "$m" ]; then SPEC_LINE="SPEC-RENDER: SKIP -- $2"; return 0; fi' \
  '  if [ -z "$m" ]; then refuse "SKIP -- $2"; return 0; fi'
# JX91: subject mode discards the SPEC render refusal. Only sjspecstale expects a refusal from the subject-mode
# call; the SPEC-RENDER line is still set, so sjspecfresh and sjspecnone read the same.
mutant "JX91 the subject-mode SPEC render refusal discarded" "sjspecstale" \
  '  if [ -n "$_sm" ]; then spec_render_check "${STATE_PARENT}${_sm}" ""' \
  '  if [ -n "$_sm" ]; then _rn0=$refuse_n; spec_render_check "${STATE_PARENT}${_sm}" ""; refuse_n=$_rn0'
# JX92: spec_render_check's unreadable-memlog refusal deleted, so a memlog awk cannot open reads as no render and SKIPs.
# Only specunread seeds an unreadable memlog. Under uid 0 its chmod has no effect and the arm passes on SKIP, so this
# mutant SURVIVES for a root runner (the fixture is not meant to run there).
mutant "JX92 an unreadable spec memlog not refused" "specunread" \
  ' || { refuse "${m}: the memlog could not be read; no render verdict"; return 0; }' \
  ''
# ---- --agent-writes (BL-579): the agent filter, and the order of dedupe against it.
mutant "JX93 --agent-writes with no agent filter" "agentwrites" \
  '.kind == "artifact-write" and .agent_id == $a and (.path | type)' \
  '.kind == "artifact-write" and (.path | type)'
# JX94 dedupes by path BEFORE the agent filter (slurp, then unique_by): the joined
# writer's earlier row on D wins the path, so the subject's D is lost.
mutant "JX94 --agent-writes dedupes by path before the agent filter" "agentwrites" \
  '[inputs | select(type == "object") | select(.kind == "artifact-write" and .agent_id' \
  '[[inputs | select(type == "object")] | unique_by(.path)[] | select(.kind == "artifact-write" and .agent_id'
# JX95 restores the piped, unchecked read: a malformed ledger line then prints the trailer alone, rc 0.
mutant "JX95 --agent-writes read piped through sort with no parse check" "agentwrites" \
  '    _aw="$(jq -rn --arg a "$AGENT_ID" --arg s "$SINCE" '"'"'[inputs | select(type == "object") | select(.kind == "artifact-write" and .agent_id == $a and (.path | type) == "string" and ($s == "" or .ts >= $s)) | .path] | unique | .[]'"'"' "$LEDGER" 2>/dev/null)" \
      || die "the write ledger ${LEDGER} does not parse as JSON lines"' \
  '    _aw="$(jq -r --arg a "$AGENT_ID" --arg s "$SINCE" '"'"'select(.kind == "artifact-write" and .agent_id == $a and ($s == "" or .ts >= $s)) | .path'"'"' "$LEDGER" 2>/dev/null | sort -u)"'
# JX96: the nested-writer fold resolves nothing, so a subagent's row on its dispatcher's file is a second writer.
# rronly dies too: its fifth cell is the re-run writer's subagent editing sections/5.md.
mutant "JX96 a nested writer not folded into its dispatcher" "nested rronly" \
  '  FOLD_MAP="$(printf '"$_Q"'%s\n'"$_Q"' "$_fres" | sed -n '"$_Q"'s/^F	//p'"$_Q"')"' \
  '  FOLD_MAP=""'
# JX97: no part is ever record-only, so a re-run that rewrote only its record has no re-run writer again.
mutant "JX97 a record-only re-run not recognised" "rronly" \
  '          if (p in post) continue' \
  '          continue'
# ---- BL-557 serial blocks. JX110: a block closed by `repair-complete: serial` judged under the era like a
# part, so a serial block writing neither line owes nothing (receipt regression 3). The self-probe's ser.md
# sees it, so it is paired off.
mutant2 "JX110 a serial block exempt via the era, self-probe removed" "chkserial" \
  '{ judge(lo, j, blk(j), (ts[j] ? "S" : "V"),' \
  '{ judge(lo, j, blk(j), (ts[j] ? "E" : "V"),' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
# ---- BL-565 supersedes chain. JX111: no dedupe (supersedes read but never linked), so seed a reads 2
# (receipt regression r1''). The self-probe sees it, so it is paired off. EXPECTED SET IS AN UNRUN
# PREDICTION (supchain alone), scored by the owner in a slot.
mutant2 "JX111 a supersedes chain not deduped, self-probe removed" "supchain" \
  '          for (i = 1; i < nesc; i++) if (sp[k] == ef[i] " " en[i]) { nlk++; la[nlk] = i; lb[nlk] = nesc; mh = 1 }' \
  '          for (i = 1; i < nesc; i++) if (sp[k] == ef[i] " " en[i]) { mh = 1 }' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
# ---- BL-556 gap-fill location. JX112: the section bound dropped, the token test scans the whole file, so
# the adjacent-section near-miss reads a decision (receipt regression r2). The self-probe sees it, so it is
# paired off. EXPECTED SET IS AN UNRUN PREDICTION (gaploc alone), scored by the owner in a slot.
mutant2 "JX112 the gap-fill token test scans the whole file, self-probe removed" "gaploc" \
  '      s = (hs ? hs : lo); e = (he ? he : (NR < hi ? NR : hi)); tok = ""' \
  '      s = lo; e = (NR < hi ? NR : hi); tok = ""' \
  "$CTPROBE_OLD" "$CTPROBE_NEW"
# ---- END JX MUTANTS.

# ------------------------------------------------------------------------------ the reap
wait
# THE STALL IS A REFUSAL, read before any verdict: a scorer the watchdog stopped produced no
# verdict about its mutant, and scoring the rest beside it would report a battery with a hole.
nstall=0
for _st in "$VD"/*.stalled; do
  [ -e "$_st" ] || continue
  nstall=$((nstall + 1)); printf '%s: FIXTURE BROKEN: %s\n' "$NAME" "$(cat "$_st")" >&2
done
[ "$nstall" -eq 0 ] || { echo "$NAME: FIXTURE BROKEN: $nstall scorer(s) stalled; no verdict is readable" >&2; exit 2; }
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
# always fails), a deliberately wrong set must FAIL, a STALL record beside it must FAIL, and the
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
  : > "$pd/p.stalled"
  judge "$pd/p" "$pl" "$pw" > /dev/null || red=$((red + 1))
  rm -f "$pd/p.stalled" "$pd/p.v"
  judge "$pd/p" "$pl" "$pw" > /dev/null || red=$((red + 1))
  if [ "$red" -eq 3 ]; then
    ok "MJ: the judgment passes ${pl%% *}'s real verdict against its own set, and FAILS it against a wrong set, beside a STALL record, and with the verdict file deleted"
  else
    bad "MJ: the judgment probe scored $red (want 3: real+right ok, real+wrong red, real+stalled red, deleted red; +100 means the right set failed)"
  fi
fi

# THE WATCHDOG, PROBED. The real slot() runs, unmodified, over two stub scorers in a private verdict
# directory and scratch tree (ids MW-*, so no join above reads them): one advances its progress marker
# for about twice the idle bound and must finish unstalled, one writes nothing and must be stalled and
# killed. SCORER_POLL=1 and SCORER_IDLE=4 are set in the probe subshell only. A watchdog that stalls
# slow-but-advancing work, or one that never fires, fails here on every push.
if [ "$GROUP" = a ]; then
  mwd="$(mktemp -d "$WORK/mw-probe.XXXXXX")" || { echo "FIXTURE ERROR: cannot create the [MW] scratch directory" >&2; exit 2; }
  mwr="$(
    VD="$mwd/verdicts"; WORK="$mwd"; mkdir -p "$VD"
    SCORER_POLL=1; SCORER_IDLE=4
    scorer() { local i; for i in 1 2 3 4 5 6 7 8 9; do printf '%s\n' "$i" > "$VD/$1.at"; sleep 1; done; : > "$VD/$1.v"; }
    SECONDS=0; slot MW-prog MW-prog x > /dev/null 2>&1; pe=$SECONDS
    # The recorded pid is the own subshell of the scorer (the PPID that bash -c reads), the process
    # slot() waits on and so reaps: a killed background child would sit as a zombie until launchd reaps it, and kill -0
    # succeeds on a zombie, which would make this reading depend on load.
    scorer() { bash -c 'echo "$PPID"' > "$VD/$1.pid"; sleep 30; }
    SECONDS=0; slot MW-hung MW-hung x > /dev/null 2>&1; he=$SECONDS
    pdn=0; pst=0; hdn=0; hst=0
    [ -e "$VD/MW-prog.done" ] && pdn=1; [ -e "$VD/MW-prog.stalled" ] && pst=1
    [ -e "$VD/MW-hung.done" ] && hdn=1; [ -e "$VD/MW-hung.stalled" ] && hst=1
    hpid="$(cat "$VD/MW-hung.pid" 2>/dev/null)"; hkd=0
    case "$hpid" in (''|*[!0-9]*) hkd=x ;; (*) kill -0 "$hpid" 2>/dev/null || hkd=1 ;; esac
    echo "$pdn $pst $pe $hdn $hst $he $hkd"
  )"
  rm -rf "$mwd"
  read -r mpd mps mpe mhd mhs mhe mhk <<< "$mwr"
  [ -n "${mhk:-}" ] && [ "$mhk" != x ] || { echo "$NAME: FIXTURE BROKEN: the [MW] probe reported no result line or no hung-stub pid, so its slot() drive is unreadable; a refusal is re-run, never scored" >&2; exit 2; }
  mwbad=""
  # The progressing run must outlast the 4s idle bound (else it proves nothing), finish, and carry no stall record.
  [ "${mpe:-0}" -ge 5 ] 2>/dev/null || mwbad="$mwbad the progressing stub ran ${mpe:-?}s, not past the 4s bound, so the probe cannot discriminate;"
  [ "${mpd:-0}" = 1 ] && [ "${mps:-1}" = 0 ] || mwbad="$mwbad a scorer that advanced for ${mpe:-?}s past a 4s idle bound was stalled or never finished (done=${mpd:-?} stalled=${mps:-?});"
  # The hung run must be stalled, and the stub's recorded pid dead once slot() returns -- binary facts,
  # never a wall-clock bound, which under a loaded pool reds with no defect (the bug BL-592 removes).
  [ "${mhs:-0}" = 1 ] && [ "${mhd:-0}" = 1 ] && [ "${mhk:-0}" = 1 ] || mwbad="$mwbad a scorer that made no progress was not stalled with its process dead (done=${mhd:-?} stalled=${mhs:-?} pid-dead=${mhk:-?});"
  if [ -z "$mwbad" ]; then
    ok "[MW] the watchdog lets a scorer that advanced for ${mpe}s past a 4s idle bound finish, and stalls one that made no progress (stalled, its process dead; ${mhe}s, information only)"
  else
    bad "[MW] the scorer watchdog probe failed:$mwbad"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
