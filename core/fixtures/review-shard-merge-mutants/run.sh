#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# review-shard-merge-mutants/run.sh -- the mutation battery behind `review-shard-merge`.
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
# mutant -- arms x mutants, serially -- and the fixture's loaded cost went 731s -> 1738s in one
# batch as both factors grew. The battery mutates copies of core's own `partition-review-diff.sh`
# and `merge-review-shards.sh`, which a consumer is denied editing, so proving the arms can fail is
# a question about files only this repository changes. The consumer keeps every behavioural arm.
#
# ONE COPY OF THE PREDICATES. Both fixtures source `review-shard-merge/lib.sh`, so a mutant is
# scored by the very predicate bodies the shipped arms run. The join below asserts the shipped
# fixture's `arm` names and P_ALL are the same set, so a predicate added to one and not the other
# cannot leave an arm unproven or a mutant scored against an arm nobody runs.
#
# SCORED IN PARALLEL, AND THE SILENT LOSS IS THE FAILURE MODE THIS SHAPE HAS TO CLOSE. A pool that
# drops a scorer reports fewer verdicts, and fewer verdicts read exactly like fewer failures. So:
#   - each scorer runs in its own subshell under `$WORK/mut-<id>/`, with WORK and every fixed
#     scratch path (`bind_scratch`: MO, PO, PE, RERUN_KEEP) rebound there, and RC/PRC its own;
#   - it writes ONE verdict file, temp-then-mv, carrying the number of predicates it evaluated;
#   - the parent counts verdicts against dispatches, and judges each with `judge`, which treats a
#     missing verdict, a STALL record, or an evaluated count other than |P_ALL| as a FAIL;
#   - `judge` itself is probed every run, on a real verdict file, in both directions.
# The pool is a FIXED width of 8 (no knob); completion is read from sentinel files the scorers
# write, never from the process table.
#
# THE WATCHDOG IS KEYED ON NO PROGRESS, NEVER ON ELAPSED TIME. bash 3.2 has no `wait -n`, so each
# scorer runs under a slot that polls it. Every SCORER_POLL seconds the slot asks whether the
# scorer has ADVANCED since its last advance -- rewritten its stage file `$VD/<id>.at` (one write
# per predicate) or written any file under its own scratch `$WORK/mut-<id>/` (every partition and
# merge run writes PO/PE/MO there) -- with `find -newer` against a mark the slot rotates on every
# advance. Only a scorer that has neither exited nor advanced for SCORER_IDLE seconds is stopped:
# the slot writes a `.stalled` record and kills the scorer's whole process tree (stopped first,
# then children before parents, so nothing reparents to init and keeps spinning), and the reap
# REFUSES the fixture, exit 2, naming the scorer and the marker. A stall is a harness that wedged,
# not a verdict about a mutant, so it is never a FAIL row. A slow scorer on a loaded box keeps
# writing and is never touched, however long it runs: the fixed 900s wall bound this replaced,
# sized against a loaded cost, turned more load into a red row, which is self-inflicted.
# SCORER_IDLE is sized to the longest single step that writes nothing -- one partition or merge
# run -- and that is seconds; the 300s window is deliberately two orders of magnitude over it: a margin over one observed step, not a measurement; a refusal costs a re-run, never a verdict. THE TRADE: a scorer that writes forever never stalls, and the pool's
# dispatch wait then waits on it; the bound on that wait is that every slot ends, by exit or by
# this refusal.
#
# THE SHARDS (BL-485). The pre-push suite is POLE-BOUND: its makespan tracks its single longest
# DIRECTORY, and this battery, 66 mutants in one unit, was that directory at 1481s loaded. So the
# mutant set is dealt across three units, this directory (shard a) and the one-line drivers
# `review-shard-merge-mutants-b` and `-c`, each `exec bash "$IMPL" --group <x>`, the shape
# `fold-architect-ledger-join-mutants` carries. Every scorer runs every predicate, but the cost per
# mutant is NOT uniform: a scorer whose world builders are byte-identical to SRCDIR's clones the
# parent's world templates (THE TEMPLATES below), and a mutant of a builder-run script -- the 14
# partition mutants -- rebuilds every world. So the partition mutants are dealt as evenly as the shards
# allow (5/5/4) and the merge mutants fill each shard to 22.
# Every shard pays the unmutated control MX0, the J1 join and the MJ probe itself, because a shard
# that skipped them could report a kill against a harness that never ran.
#
# THE SHARD ARRIVES AS AN ARGUMENT, never from the environment: the scrub below unsets AI_DLC_*,
# and a fallback-to-'a' design would run shard a three times and report three green fixtures.
#
# THE COVERAGE JOIN [J0] runs in every shard before any mutant is dispatched: the declared set is
# DERIVED from this file's own `mutant "<id> ` lines, the dealt lists must be disjoint and their
# union must equal it exactly, and every declared shard must have a driver directory naming it.
# The join proves it can fire, on a seeded duplicate and a seeded omission, before it is trusted.
# After the reap, [J2] asserts this shard dispatched exactly the mutants dealt to it.
SHARDS="a b c"
MUTANTS_a="MX1 MX2 MX3 MX4 MX5 MX6 MX7 MX8 MX9 MX10 MX11 MX12 MX13 MX14 MX15 MX16 MX17 MX18 MX22 MH8 MH10 MH11"
MUTANTS_b="MX23 MX24 MX25 MX26 MX27 MQ1 MQ2 MQ3 MQ4 MQ5 MQ6 MQ7 MQ8 MQ9 MH1 MH2 MH3 MH4 MH5 MH6 MH7 MH12"
MUTANTS_c="MX19 MX20 MX21 MX28 MH13 MH14 MH9 MG1 MG2 MG3 MC1 MC2 MC3 MC4 MC11 MC12 MC5 MC6 MC7 MC8 MC9 MC10 MF1"
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset AI_DLC_REVIEW_SHARD_MIN_FILES

HERE="$(cd "$(dirname "$0")" && pwd)"
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
NAME="review-shard-merge-mutants"
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
JW="$(mktemp -d "${TMPDIR:-/tmp}/rsm-join.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
printf '%s\n' MX1 MX2 MX3 > "$JW/pd"; printf '%s\n' MX1 MX2 MX2 MX3 > "$JW/pdup"
printf '%s\n' MX1 MX3 > "$JW/pmiss"; printf '%s\n' MX3 MX1 MX2 > "$JW/pok"
if partition_ok "$JW/pd" "$JW/pdup" >/dev/null || partition_ok "$JW/pd" "$JW/pmiss" >/dev/null \
   || ! partition_ok "$JW/pd" "$JW/pok" >/dev/null; then
  echo "FIXTURE BROKEN: the coverage join's self-probe did not discriminate (duplicate, omission, exact)" >&2; exit 2
fi
sed -n 's/^mutant "\([A-Z][A-Z0-9]*\) .*/\1/p' "$SELF" > "$JW/declared"
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
  drv="$HERE/../review-shard-merge-mutants-$s/run.sh"
  # Anchored on the whole exec line, `^exec bash "$IMPL" --group <s>$`: a comment or any other
  # line merely mentioning `--group <s>` does not drive the shard.
  if [ ! -f "$drv" ] || ! grep -qxF -- "exec bash \"\$IMPL\" --group $s" "$drv"; then
    echo "FIXTURE BROKEN: shard '$s' is declared but $drv does not drive it" >&2; exit 2
  fi
done
nmine=0; for _m in $MINE; do nmine=$((nmine+1)); done
JOIN_LINE="[J0] coverage join: $ndecl mutants derived from mutant lines, dealt disjointly across {$SHARDS}, union exact; this shard runs $nmine: {$MINE}"
command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 not on PATH (the mutation helper)" >&2; exit 2; }
SIB="$HERE/../review-shard-merge"
[ -f "$SIB/lib.sh" ] || { echo "FIXTURE BROKEN: $SIB/lib.sh is absent; no predicate exists to score a mutant against" >&2; exit 2; }
[ -f "$SIB/run.sh" ] || { echo "FIXTURE BROKEN: $SIB/run.sh is absent; the arm/P_ALL join has no subject" >&2; exit 2; }
. "$SIB/lib.sh"
echo "HERMETIC-CONSUMED core/scripts/partition-review-diff.sh"
echo "HERMETIC-CONSUMED core/scripts/merge-review-shards.sh"
# lib.sh's WORK is created after its argument parse ran here, so the rows file is opened only now.
if [ -n "$ROWS" ]; then : >> "$ROWS" || { echo "FIXTURE ERROR: cannot write --rows $ROWS" >&2; exit 2; }; fi

echo "$NAME:"
ok "$JOIN_LINE"
seed_controls

# THE JOIN: every predicate the shipped fixture names in an `arm` call is scored here, and every
# predicate scored here is one the shipped fixture runs. Read from the shipped run.sh's own `arm`
# lines, so the shipped set is never restated.
ARMS="$(sed -n 's/^arm \([a-z0-9_][a-z0-9_]*\) .*/\1/p' "$SIB/run.sh" | sort)"
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
mutdir() { # <name> -> a dir holding both subjects and the scan-root sibling
  local d s
  d="$(mktemp -d "$WORK/mut-$1.XXXXXX")" || return 1
  for s in partition-review-diff.sh merge-review-shards.sh artifact-path-config.sh partition-document.sh; do cp "$SRCDIR/$s" "$d/"; done
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

# One scorer: every predicate against <script-dir>, in P_ALL order, in its own scratch.
scorer() { # <id> <label> <script-dir>
  trap - EXIT
  local id="$1" label="$2" sd="$3" sw p n=0 dead=""
  sw="$WORK/mut-$id"; mkdir -p "$sw" || exit 1
  WORK="$sw"; bind_scratch "$sw"; RC=""; PRC=""
  if tpl_eligible "$sd"; then RSM_TPL_HITS="$sw/tpl.hits"; : > "$RSM_TPL_HITS"; echo yes > "$sw/tpl.elig"
  else RSM_TPL=""; echo no > "$sw/tpl.elig"; fi
  for p in $P_ALL; do n=$((n + 1)); printf '%s\n' "$p" > "$VD/$id.at"; "p_$p" "$sd" || dead="$dead $p"; done
  dead="${dead# }"
  printf '%s\t%s\t%s\n' "$label" "$n" "$dead" > "$VD/$id.tmp" && mv "$VD/$id.tmp" "$VD/$id.v"
}
killtree() { # <pid>: stop it, take its children down first, then it
  local c
  kill -STOP "$1" 2>/dev/null
  for c in $(pgrep -P "$1" 2>/dev/null); do killtree "$c"; done
  kill -9 "$1" 2>/dev/null
}
slot() { # <id> <label> <script-dir>: the scorer under its no-progress watchdog, then the completion sentinel
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
dispatch() { # <label> <script-dir> <expected dead set | NONE>
  local id
  while [ "$((NDISP - $(ndone)))" -ge "$POOL" ]; do sleep 1; done
  NDISP=$((NDISP + 1)); id="$(printf '%03d' "$NDISP")"
  printf '%s\t%s\t%s\n' "$id" "$1" "$3" >> "$IDX"
  slot "$id" "$1" "$2" &
}
# THE JUDGMENT, factored so it can be probed: no global is read or written but its arguments and
# the three constants; it prints its one line and returns 0 (ok) or 1 (FAIL).
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
NSEEN=0
mutant() { # <label> <file> <expected> <old> <new> [<old2> <new2>]
  local label="$1" f="$2" want="$3" d
  case " $MINE " in *" ${label%% *} "*) ;; *) return 0 ;; esac
  NSEEN=$((NSEEN + 1))
  d="$(mutdir "${label%% *}")"
  if ! apply "$d/$f" "$4" "$5" || { [ $# -ge 7 ] && ! apply "$d/$f" "$6" "$7"; }; then
    bad "$label: FIXTURE STALE -- the mutation anchor is not in $f exactly once; re-anchor it, never relax the assertion"; return
  fi
  if cmp -s "$SRCDIR/$f" "$d/$f"; then bad "$label: FIXTURE STALE -- the mutated copy is byte-identical"; return; fi
  bash -n "$d/$f" 2>/dev/null || { bad "$label: FIXTURE BROKEN -- the mutated $f does not parse"; return; }
  dispatch "$label" "$d" "$want"
}

# ------------------------------------------------------------------------------ THE TEMPLATES
# The world builders (new_world, kworld, xshards) run only partition-review-diff.sh, the
# artifact-path-config.sh it calls and partition-document.sh -- never the merge. So for every scorer
# whose copies of those three are byte-identical to SRCDIR's (the 52 merge mutants and MX0), each world
# it builds is byte-identical to one built from SRCDIR. The parent builds each such world ONCE, here,
# serially, before any dispatch; an eligible scorer clones it into its own fresh directory. A scorer
# with any builder-run script mutated never sees the templates and rebuilds every world as before.
# A world whose arguments no fill call below names is simply built: a missing template costs time,
# never a verdict. MX0 runs on the templates, so the cached path has its unmutated control; the
# uncached path has the shipped fixture's every-push run.
tpl_eligible() { # <script-dir>: 0 when its three builder-run scripts are byte-identical to SRCDIR's
  local s
  for s in partition-review-diff.sh artifact-path-config.sh partition-document.sh; do cmp -s "$SRCDIR/$s" "$1/$s" || return 1; done
}
RSM_TPL="$WORK/tpl"; mkdir -p "$RSM_TPL" || { echo "FIXTURE ERROR: cannot create $RSM_TPL" >&2; exit 2; }
RSM_TPL_FILL=1
tpl_fill() {
  local SHARD_SHA
  world4 "$SRCDIR" APPROVED APPROVED APPROVED APPROVED > /dev/null \
  && qworld "$SRCDIR" PASS PASS PASS PASS > /dev/null \
  && qworld "$SRCDIR" PASS PASS PASS PASS -p2 > /dev/null \
  && new_world "$SRCDIR" "$REPO_B" code-review -p3 > /dev/null \
  && kworld "$SRCDIR" "$REPO_E" "$E_BASE" "$E_SHA" 8 code-review APPROVED > /dev/null \
  && { SHARD_SHA="$F_SHA"; kworld "$SRCDIR" "$REPO_F" "$F_BASE" "$F_SHA" 2 code-review APPROVED > /dev/null; } \
  && kworld "$SRCDIR" "$REPO_F" "$F_BASE" "$F_SHA" 2 "$QA_SFX" PASS qa > /dev/null
}
tpl_fill || { echo "FIXTURE BROKEN: building the world templates from SRCDIR failed" >&2; exit 2; }
RSM_TPL_FILL=""
# MT0: the seven world keys the fill names are each present, recomputed here from their argument tuples,
# and the cross-group templates are exactly one per distinct part count those seven worlds' manifests hold.
_tw=""; _tm=0
for _k in "nw $REPO_B $B_BASE $B_SHA 4 3 code-review " "nw $REPO_B $B_BASE $B_SHA 4 3 $QA_SFX " \
          "nw $REPO_B $B_BASE $B_SHA 4 3 $QA_SFX -p2" "nw $REPO_B $B_BASE $B_SHA 4 3 code-review -p3" \
          "kw $REPO_E $E_BASE $E_SHA 4 8 code-review" "kw $REPO_F $F_BASE $F_SHA 4 2 code-review" \
          "kw $REPO_F $F_BASE $F_SHA 4 2 $QA_SFX"; do
  set -f; set -- $_k; set +f
  [ "$1" = nw ] && [ $# -eq 7 ] && set -- "$@" ""
  _h="$(tpl_key "$@")"
  if [ -d "$RSM_TPL/$_h" ]; then _tw="$_tw $_h"; else _tm=$((_tm + 1)); fi
done
_kset="$(for _h in $_tw; do awk -F'\t' '$1 == "part" { n++ } END { print n + 0 }' "$RSM_TPL/$_h"/*/.manifest; done | sort -u)"
_nk="$(grep -c . <<<"$_kset")" || _nk=0
_nall="$(find "$RSM_TPL" -mindepth 1 -maxdepth 1 -type d | grep -c .)" || _nall=0
if [ "$_tm" -eq 0 ] && [ "$_nk" -ge 1 ] && [ "$_nall" -eq $((7 + _nk)) ]; then
  ok "MT0: the parent built 7 world templates and $_nk cross-group templates (K = $(tr '\n' ' ' <<<"$_kset")) from SRCDIR before any dispatch"
else bad "MT0: $_tm of 7 world templates missing; $_nall templates on disk, want $((7 + _nk)) (K = $(tr '\n' ' ' <<<"$_kset"))"; fi
# MT1 -- ELIGIBILITY, both directions: a one-byte change to any builder-run script makes a copy
# ineligible; a one-byte change to the merge alone does not.
_te=0
for _s in partition-review-diff.sh artifact-path-config.sh partition-document.sh merge-review-shards.sh; do
  _d="$(mutdir "te-${_s%%.*}")" || { _te=99; break; }
  printf '#\n' >> "$_d/$_s"
  if tpl_eligible "$_d"; then [ "$_s" = merge-review-shards.sh ] || _te=$((_te + 1))
  else [ "$_s" = merge-review-shards.sh ] && _te=$((_te + 1)); fi
done
_d="$(mutdir te-none)" && tpl_eligible "$_d" || _te=$((_te + 1))
if [ "$_te" -eq 0 ]; then ok "MT1: a one-byte change to each builder-run script makes a copy ineligible; the merge alone and no change leave it eligible"
else bad "MT1: the eligibility probe misjudged $_te of five copies"; fi
# MT2 -- CLONE FIDELITY: per builder, a world cloned from the templates equals one built fresh from SRCDIR,
# byte for byte and file for file, and the clone path is the one taken.
_tf=0; _th="$WORK/tpl.probe.hits"
for _b in w4 kw; do
  : > "$_th"
  case "$_b" in
    w4) _fr="$(RSM_TPL=""; world4 "$SRCDIR" APPROVED APPROVED APPROVED APPROVED)" \
        && _cl="$(RSM_TPL_HITS="$_th"; world4 "$SRCDIR" APPROVED APPROVED APPROVED APPROVED)" || _tf=$((_tf + 10)) ;;
    kw) _fr="$(RSM_TPL=""; kworld "$SRCDIR" "$REPO_E" "$E_BASE" "$E_SHA" 8 code-review APPROVED)" \
        && _cl="$(RSM_TPL_HITS="$_th"; kworld "$SRCDIR" "$REPO_E" "$E_BASE" "$E_SHA" 8 code-review APPROVED)" || _tf=$((_tf + 10)) ;;
  esac
  [ "$(grep -c . "$_th")" -eq 2 ] || _tf=$((_tf + 1))
  [ "$(dirname "$_fr")" != "$(dirname "$_cl")" ] && diff -r "$(dirname "$_fr")" "$(dirname "$_cl")" > /dev/null 2>&1 || _tf=$((_tf + 1))
done
if [ "$_tf" -eq 0 ]; then ok "MT2: a cloned world4 and kworld each equal a fresh build from SRCDIR (diff -r), and each took two template hits (world + cross groups)"
else bad "MT2: the clone-fidelity probe scored $_tf (want 0)"; fi

C0="$(mutdir m0)"
if [ -f "$C0/partition-review-diff.sh" ] && [ -f "$C0/merge-review-shards.sh" ] && [ -f "$C0/artifact-path-config.sh" ] \
   && [ -f "$C0/partition-document.sh" ]; then
  ok "MX-pre: the sandbox carries the merge, the partition it re-runs, the scan-root resolver the partition calls, and the cross-group speller the merge calls"
  dispatch "MX0 control (unmutated copy)" "$C0" NONE
else
  bad "MX-pre: FIXTURE BROKEN -- the sandbox lacks a subject or its sibling"
fi

WORST_LINE='if [ "$r" -gt "$WORST_R" ]; then WORST_R="$r"; WORST="$v"; fi'
HDR_LINE="  printf '# %s: %s (merged from %s shards)\\n\\n' \"\$TITLE\" \"\$IDX\" \"\$((K + G))\""
# The worst-of line is SHARED by both gates, so each wrong rule dies in gate 1 (V1) and gate 2 (Q1).
# MX1 kills H4 too, and both findings are true: its majority recompute sits after the hand-over
# join, so it discards the forced NEEDS_REWORK as well as the worst-of.
mutant "MX1 verdict by majority count" merge-review-shards.sh "worst q_worst q_ho_force cr_ho_ok" \
  "$WORST_LINE" 'TALLY="${TALLY:-} $v"' \
  "$HDR_LINE" "  WORST=\"\$(printf '%s\\n' \$TALLY | sort | uniq -c | sort -k1,1nr -k2,2 | awk 'NR == 1 { print \$2 }')\"
$HDR_LINE"
mutant "MX2 verdict = the cross shards'" merge-review-shards.sh "worst q_worst" \
  "$WORST_LINE" 'if is_cross "$key"; then WORST_R="$r"; WORST="$v"; fi'
mutant "MX3 verdict = the last part read" merge-review-shards.sh "worst q_worst" \
  "$WORST_LINE" 'if ! is_cross "$key"; then WORST_R="$r"; WORST="$v"; fi'
# Short union: the owed-set check removed AND a missing shard skipped, so the mutant MERGES.
mutant "MX4 accepts a short union" merge-review-shards.sh "miss_ord miss_cross" \
  'for idx in $ORDINALS $CROSS_KEYS; do' 'for idx in ; do' \
  "  sf=\"\$(awk -F'\\t' -v k=\"\$key\" '\$1 == k { print \$2; exit }' \"\$T/shards\")\"" \
  "  sf=\"\$(awk -F'\\t' -v k=\"\$key\" '\$1 == k { print \$2; exit }' \"\$T/shards\")\"
  [ -n \"\$sf\" ] || continue"
# A second Check-1-matching line, added at the WRITE, downstream of the merge's own count guard.
# R10 dies too, and both findings are true: the file this mutant writes is not the merge it
# recomputes, so R10's identical re-merge reads a differing review and is refused, not UNCHANGED.
mutant "MX5 emits a second Check-1 line" merge-review-shards.sh "c1 rerun q_table" \
  'cp "$T/out" "$OUT.merge-tmp.$$" && mv' \
  '{ cat "$T/out"; printf '"'"'**Verdict:** %s\n'"'"' "$WORST"; } > "$OUT.merge-tmp.$$" && mv'
# MF1: the fence length rule dropped at the shard parse -- a ```` fence closes on the inner bare ``` and
# the fenced '#### ' finding is counted. Only R20 seeds a nested fence.
mutant "MF1 fence length rule dropped in the shard parse" merge-review-shards.sh "fence_nested" \
  '&& length(frr) >= fln) { fence = 0; next } }' \
  ') { fence = 0; next } }'
mutant "MX6 skips the manifest re-derivation" merge-review-shards.sh "moved" \
  'bash "$PART" --map "$M_WT" "$M_BASE" "$M_SHA" --min-files "$M_MIN" --max-parts "$M_MAX" > "$T/map" 2> "$T/map.err"; prc=$?' \
  'cp "$T/mfmap" "$T/map"; prc=$?'
mutant "MX7 first-path-component group key (no adaptive split)" partition-review-diff.sh "part" \
  'if (GW[g] * K <= tot) continue' 'continue'
# The merge's Check-1 count guard alone owns R9; C1 is the mirror one stage later (MX5).
mutant "MX8 Check-1 count guard disabled" merge-review-shards.sh "a3" \
  '[ "$n1" = "1" ] || refuse' '[ "$n1" = "1" ] || true'
mutant "MX9 an existing differing review is overwritten" merge-review-shards.sh "rerun" \
  '  refuse "$OUT already exists and differs from this merge; a review file is never overwritten"' '  :'
mutant "MX10 the ancestor check removed" partition-review-diff.sh "anc" \
  'git -C "$WT_ABS" merge-base --is-ancestor "$BASE_FULL" "$SHA_FULL" \' 'true \'
mutant "MX11 the cross shard's reviewed-sha is not checked" merge-review-shards.sh "cross_sha" \
  '  [ "${2:-}" = "$M_SHA" ] || refuse' '  is_cross "$key" || [ "${2:-}" = "$M_SHA" ] || refuse'
mutant "MX12 an unranked verdict is accepted" merge-review-shards.sh "bad_verdict q_rank" \
  '[ "$r" -gt 0 ] || refuse' '[ "$r" -ge 0 ] || refuse'
mutant "MX13 a finding with no parts: is skipped" merge-review-shards.sh "noparts" \
  '    [ "$nlines" = "1" ] || refuse' '    [ "$nlines" = "0" ] && continue; [ "$nlines" = "1" ] || refuse'
mutant "MX14 the existing-manifest check removed" partition-review-diff.sh "manifest" \
  '  if [ -e "$SDIR/.manifest" ]; then' '  if false; then'
mutant "MX15 two reviewed-sha lines accepted" merge-review-shards.sh "two_sha" \
  "[ \"\${1:-0}\" = \"1\" ] || refuse \"\$sf carries \${1:-0} 'reviewed-sha:'" \
  "[ \"\${1:-0}\" -ge 1 ] || refuse \"\$sf carries \${1:-0} 'reviewed-sha:'"
mutant "MX16 default part ceiling 2" partition-review-diff.sh "default_k" \
  '[ -n "$MAXP" ] || MAXP=4' '[ -n "$MAXP" ] || MAXP=2'
mutant "MX17 a stray parts: line is not refused" merge-review-shards.sh "stray" \
  '  [ "${sl:-0}" = "0" ] \' '  true \'
mutant "MX18 a shard without ## Findings is not refused" merge-review-shards.sh "nofind" \
  "  [ \"\$(awk '\$1 == \"F\" { print \$2 }' \"\$P\")\" = \"1\" ] \\" '  true \'
mutant "MX19 the 9-digit cap removed" partition-review-diff.sh "knob" \
  'case "$MINF" in ??????????*) refuse' 'case "$MINF" in NEVER) refuse' \
  'case "$MAXP" in ??????????*) refuse' 'case "$MAXP" in NEVER) refuse'
mutant "MX20 the 64-part ceiling removed" partition-review-diff.sh "knob" \
  '[ "$MAXP" -le 64 ] || refuse' '[ "$MAXP" -le 64 ] || true'
# THE DEFAULT-ON THRESHOLD. Each mutant is a wrong build the contract names; the boundary one
# dies only because P2b's seed sits at exactly the default.
DFLT_LINE="REVIEW_SHARD_DEFAULT_MIN_FILES=$DFLT"
mutant "MX21 default 0 (always serial)" partition-review-diff.sh "dflt_lo dflt_hi dmerge" \
  "$DFLT_LINE" 'REVIEW_SHARD_DEFAULT_MIN_FILES=0'
mutant "MX22 default 1 (always shards)" partition-review-diff.sh "dflt_lo" \
  "$DFLT_LINE" 'REVIEW_SHARD_DEFAULT_MIN_FILES=1'
mutant "MX23 the boundary is exclusive (-le)" partition-review-diff.sh "dflt_hi" \
  'if [ "$NF_REV" -lt "$MINF" ]; then' 'if [ "$NF_REV" -le "$MINF" ]; then'
mutant "MX24 a zero threshold refuses" partition-review-diff.sh "off" \
  'echo "SERIAL: review sharding is disabled -- $MINF_SRC is 0"; exit 3' 'refuse "$MINF_SRC is 0"'
mutant "MX25 a zero threshold means the default" partition-review-diff.sh "off" \
  'MINF=$((10#$MINF))' 'MINF=$((10#$MINF)); [ "$MINF" -ne 0 ] || MINF="$REVIEW_SHARD_DEFAULT_MIN_FILES"'
mutant "MX26 a set-but-empty key reads as unset" partition-review-diff.sh "refuse_val" \
  'elif [ -n "${AI_DLC_REVIEW_SHARD_MIN_FILES+set}" ]; then' 'elif [ -n "${AI_DLC_REVIEW_SHARD_MIN_FILES:-}" ]; then'
# Two arms, both true: prec sees the partition answer move, dmerge's flagged world sees the
# manifest record the key's number instead of the flag's, which the merge would hand back.
mutant "MX27 the key overrides --min-files" partition-review-diff.sh "prec dmerge" \
  'if [ "$MINF_SET" -eq 1 ]; then' 'if [ "$MINF_SET" -eq 1 ] && [ -z "${AI_DLC_REVIEW_SHARD_MIN_FILES+set}" ]; then'
mutant "MX28 the manifest records the default's SOURCE, not its number" partition-review-diff.sh "dmerge" \
  '  MINF="$REVIEW_SHARD_DEFAULT_MIN_FILES"' '  MINF="$REVIEW_SHARD_DEFAULT_MIN_FILES"; MREC=default' \
  "printf 'min-files\\t%s\\n' \"\$MINF\"" "printf 'min-files\\t%s\\n' \"\${MREC:-\$MINF}\""
# GATE 2 (--gate qa). Each is a wrong build the contract names.
# H4 dies too, and both findings are true: the forced floor only RAISES a verdict ranked below
# NEEDS_REWORK, and with the rank inverted every PASS shard already sits above it.
mutant "MQ1 the qa rank inverted (PASS worst)" merge-review-shards.sh "q_worst q_ho_force" \
  '    qa:PASS) echo 1 ;;' '    qa:PASS) echo 2 ;;' \
  '    qa:NEEDS_REWORK) echo 2 ;;' '    qa:NEEDS_REWORK) echo 1 ;;'
# x_actable dies too, and both findings are true: the per-AC refusal for a non-first cross shard
# sits inside the same qa-only block.
mutant "MQ2 the qa section refusals removed" merge-review-shards.sh "q_part_ac q_part_def q_cross_noac q_cross_twoac q_cross_twodef q_secvar x_actable" \
  '  if [ "$GATE" = "qa" ]; then' '  if false; then'
mutant "MQ3 QA's verdict set lifted from code-reviewer.md" merge-review-shards.sh "q_vset" \
  'ROLE_NAME="qa.md"; DSUF="qa-validation"' 'ROLE_NAME="code-reviewer.md"; DSUF="qa-validation"' \
  'WANT_VSET="NEEDS_REWORK PASS "' 'WANT_VSET="APPROVED BLOCKED NEEDS_REWORK "'
mutant "MQ4 the pass-marker check removed" merge-review-shards.sh "q_pm" \
  '[ "$OPASS" = "$DPASS" ] \' 'true \'
mutant "MQ5 gate-1 output changed (title)" merge-review-shards.sh "q_title" \
  'DSUF="code-review"; TITLE="Code Review"' 'DSUF="code-review"; TITLE="Code-Review"'
mutant "MQ6 an unknown gate is merged as qa" merge-review-shards.sh "q_gate" \
  '  qa)          ROLE_NAME=' '  *)          ROLE_NAME='
mutant "MQ7 the shard dir suffix is not the gate's" merge-review-shards.sh "q_suffix" \
  '  *-"$DSUF-$S12") IDX="${SB%-"$DSUF-$S12"}" ;;' '  *-*-"$S12") IDX="${SB%%-*}" ;;'
# The section counts, both directions: reverted to the exact-case `## ` match, and widened to
# every heading level (a `#### ` finding then counts as a section).
SEC_AC='    lc ~ /^###?[ \t]+acceptance criteria/ { nac++ }'
SEC_DEF='    lc ~ /^###?[ \t]+deferred/ { nda++ }'
mutant "MQ8 the section counts reverted to the exact '## ' heading" merge-review-shards.sh "q_secvar" \
  "$SEC_AC" '    /^## Acceptance Criteria[ \t]*$/ || /^## Acceptance Criteria[ \t]/ { nac++ }' \
  "$SEC_DEF" '    /^## Deferred ACs[ \t]*$/ || /^## Deferred ACs[ \t]/ { nda++ }'
mutant "MQ9 the section counts widened to every heading level" merge-review-shards.sh "q_secvar" \
  "$SEC_AC" '    lc ~ /^##+[ \t]+acceptance criteria/ { nac++ }' \
  "$SEC_DEF" '    lc ~ /^##+[ \t]+deferred/ { nda++ }'
# HAND-OVERS. Each is a wrong build the contract names.
mutant "MH1 the hand-over match check dropped" merge-review-shards.sh "q_ho_unm q_ho_orph cr_ho_unm" \
  '  d1="$(comm -23 "$T/hand.s" "$T/runs.s" | head -1)"' '  d1=""' \
  '  d1="$(comm -13 "$T/hand.s" "$T/runs.s" | head -1)"' '  d1=""'
mutant "MH2 an unmet replay does not force NEEDS_REWORK" merge-review-shards.sh "q_ho_force cr_ho_ok" \
  '  if [ -n "$FORCE" ] && [ "$WORST_R"' '  if false && [ "$WORST_R"'
# Fenced lines leak ONLY for the hand-over grammar, so every other fence arm stays green.
mutant "MH3 fenced hand-over lines counted" merge-review-shards.sh "q_ho_fenced" \
  '    fence { next }' '    fence && !/^handover/ { next }'
# Each refusal disabled alone; every world above MERGES PASS without it (MH4's world merged PASS on
# the release before H9 existed, with AC8's replay run by nobody).
mutant "MH4 a two-AC hand-over line accepted" merge-review-shards.sh "q_ho_multi" \
  '          [ -z "${a2:-}" ] || refuse' '          true || refuse'
mutant "MH5 two hand-over lines in one finding accepted" merge-review-shards.sh "q_ho_twoline" \
  '    [ "${nho:-0}" -le 1 ] || refuse' '    true || refuse'
mutant "MH6 a duplicate hand-over accepted" merge-review-shards.sh "q_ho_dup" \
  '  d1="$(sort "$T/hand" | uniq -d | head -1)"' '  d1=""'
# The widened malformed-line pattern reverted, one alternation family at a time: the decorated
# label back to the old stray pattern alone, then the column-0 no-colon forms dropped.
HM_DECO='    lc ~ /^[ \t>*_`+-]*([0-9]+\.[ \t]*)?[ \t>*_`+-]*hand[- ]?over(-run)?[*_` \t]*:/ \'
HM_NC='      || lc ~ /^([0-9]+\.[ \t]+)?hand-?over[^a-z0-9]+[a-z0-9][a-z0-9._-]*[0-9][a-z0-9._-]*([^a-z0-9._-]|$)/ \'
HM_NCR='      || lc ~ /^([0-9]+\.[ \t]+)?hand-?over-run[^a-z0-9]+[0-9]+[^a-z0-9]+[a-z0-9]/ { if (!hbad) hbad = NR }'
# The decorated family off kills H12 and, through `1. **handover:**`, H24's list cell.
mutant "MH7 the decorated hand-over label not refused" merge-review-shards.sh "q_ho_deco q_ho_widen" \
  "$HM_DECO" '    lc ~ /^NEVER-A-HAND-OVER$/ \'
mutant "MH8 a column-0 hand-over missing its colon not refused" merge-review-shards.sh "q_ho_nocolon q_ho_widen" \
  "$HM_NCR" '      { if (!hbad) hbad = NR }' \
  "$HM_NC" '      || 0 \'
# THE WIDENING REVERTED: the three alternations back to the pre-widening text. Every H12/H13 form
# is still refused by the old text, so H24 alone dies -- and the declared count does NOT rescue
# it, because H24 declares 0 and parses 0.
HM_DECO_OLD='    lc ~ /^[ \t>*_`+-]*hand[- ]?over(-run)?[*_` \t]*:/ \'
mutant "MH10 the malformed-line widening reverted" merge-review-shards.sh "q_ho_widen" \
  "$HM_DECO" "$HM_DECO_OLD" \
  "$HM_NC
$HM_NCR" '      || lc ~ /^hand-?over[ \t]+(-[ \t]+)?[a-z0-9][a-z0-9._-]*[0-9][a-z0-9._-]*[ \t]*$/ \
      || lc ~ /^hand-?over-run[ \t]+(-[ \t]+)?[0-9]+[ \t]+[a-z0-9]/ { if (!hbad) hbad = NR }'
# THE DECLARED COUNT. Dropping the equality lets H16 reach the malformed-line refusal (another
# message), H17's hidden forms merge, and H18 merge PASS.
mutant "MH11 the declared-count equality dropped" merge-review-shards.sh "q_hc_dash q_hc_hidden q_hc_zero" \
  '      [ "$((10#$hdv))" -eq "$nho_s" ] \' '      true \'
# A missing line read as a valid 0: both the line count relaxed and the absent value defaulted,
# or the non-integer refusal would still catch the `-` an absent value parses to.
mutant "MH12 a missing handovers: line accepted as 0" merge-review-shards.sh "q_hc_missing cr_hc_missing" \
  '      [ "$nhd" = "1" ] \' '      [ "$nhd" -le 1 ] \' \
  '    nhd="${nhd:-0}"; hdv="${hdv:--}"' '    nhd="${nhd:-0}"; hdv="${hdv:-0}"'
# The width guard alone: 2^64 wraps to 0 in bash 3.2's arithmetic, so only the guard refuses it.
mutant "MH13 the hand-over count's width guard dropped" merge-review-shards.sh "q_hc_nonint" \
  '      case "$hdv" in *[!0-9]*|??????????*) refuse' '      case "$hdv" in *[!0-9]*) refuse'
# The word-split read restored: `?` and `[1]` glob to a valid count in a cwd holding 0 and 1.
mutant "MH14 the hand-over count read by word-splitting" merge-review-shards.sh "q_hc_nonint" \
  '    read -r nhd hdv <<<"$(awk '"'"'$1 == "N" { print $2, $3 }'"'"' "$P")"' '    set -- $(awk '"'"'$1 == "N" { print $2, $3 }'"'"' "$P"); nhd="$1"; hdv="${2:-}"'
mutant "MH9 an <AC-id> may begin with any of its characters" merge-review-shards.sh "q_ho_acid" \
  "RE_AC='^[A-Za-z0-9][A-Za-z0-9._-]*\$'" "RE_AC='^[A-Za-z0-9._-]+\$'"
# GATE-1 HAND-OVERS. MG1 reverts the read to --gate qa only (the pre-sharding build, where a
# code-review part shard executed nothing): every gate-1 arm dies, each for its own reason --
# G1/G2 on the replay finding that then names no run, G3 and G5 by merging, G4 by the same.
mutant "MG1 hand-over lines read under --gate qa only" merge-review-shards.sh "cr_ho_ok cr_ho_block cr_ho_unm cr_ho_runtwice cr_hc_missing" \
  '  { # HAND-OVERS, read under both gates (header)' '  if [ "$GATE" = qa ]; then' \
  '  } # end HAND-OVERS' '  fi'
mutant "MG2 a hand-over replayed twice accepted" merge-review-shards.sh "cr_ho_runtwice" \
  '  d1="$(sort "$T/runs" | uniq -d | head -1)"' '  d1=""'
mutant "MG3 an unmet replay lowers a BLOCKED review" merge-review-shards.sh "cr_ho_block" \
  '  if [ -n "$FORCE" ] && [ "$WORST_R" -lt "$(rank NEEDS_REWORK)" ]; then' '  if [ -n "$FORCE" ]; then'
# THE SHARDED CROSS REVIEWER. Each is a wrong build the contract names, each refusal disabled
# alone so the world it guards MERGES (or reaches a refusal with another message) without it.
mutant "MC1 one cross.md accepted where the cross groups are owed" merge-review-shards.sh "x_only" \
  '[ "$x_plain" -eq 1 ] && [ "$G" -gt 1 ] \' '[ "$x_plain" -eq 1 ] && false \'
mutant "MC2 cross.md beside cross-<g>.md not refused as a mix" merge-review-shards.sh "x_mix" \
  '[ "$x_plain" -eq 1 ] && [ "$x_num" -eq 1 ] \' '[ "$x_plain" -eq 1 ] && false \'
mutant "MC3 a cross group the table does not print accepted" merge-review-shards.sh "x_unknown" \
  'case " $CROSS_KEYS " in *" $xk "*) ;; *) refuse' 'case " $CROSS_KEYS " in *) ;; NEVER) refuse'
mutant "MC4 the owner rule dropped" merge-review-shards.sh "x_owner" \
  '      if [ "$ownk" != "$key" ]; then' '      if false; then'
# MC11: the pre-v4 rule -- every finding outside its owner's shard refused, identical or not; X5's
# 1, 2, 7 finding held only by cross-3 is then refused.
mutant "MC11 non-owner refused whatever its owner carries" merge-review-shards.sh "x_owner" \
  '        ! same_set "$osf" parts "$distinct" \' '        false \'
# MC12: the marker's findings=<n> not compared -- X9's truncated shard merges.
mutant "MC12 the seat-complete count unchecked" merge-review-shards.sh "x_seat" \
  '  [ -z "$scn" ] || [ "$scn" = "${nf:-0}" ] \' '  true \'
mutant "MC5 the per-AC table and deferred record accepted outside the first cross shard" merge-review-shards.sh "x_actable" \
  '    elif is_cross "$key"; then' '    elif is_cross "$key"; then :; elif false; then'
mutant "MC6 a hand-over replay accepted from any cross shard" merge-review-shards.sh "x_horun" \
  '          [ "$key" = "$CROSS_FIRST" ] \' '          true \'
mutant "MC7 the seat-complete refusal dropped" merge-review-shards.sh "x_seat" \
  'if grep -q '"'"'^Y'"'"' "$T/sc" && grep -q '"'"'^N'"'"' "$T/sc"; then' 'if false; then'
mutant "MC8 the seat-complete marker kept in the merged body" merge-review-shards.sh "x_seat" \
  "  awk '!/^seat-complete: /' \"\$sf\" >> \"\$T/body\"" "  cat \"\$sf\" >> \"\$T/body\""
mutant "MC9 the title counts one cross shard" merge-review-shards.sh "q_title x_k8" \
  "$HDR_LINE" "  printf '# %s: %s (merged from %s shards)\\n\\n' \"\$TITLE\" \"\$IDX\" \"\$((K + 1))\""
# At G=1 the shard is named cross-1: X8's cross.md is refused as missing cross-1, and X4's
# cross-1.md at K=2 reaches the owner refusal instead of the table refusal.
mutant "MC10 the single cross shard is named cross-1" merge-review-shards.sh "x_unknown x_k2" \
  'if [ "$G" -eq 1 ]; then CROSS_KEYS="cross"' 'if false; then CROSS_KEYS="cross"'

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
# The control is one dispatch; every other dispatch is a mutant dealt to this shard.
if [ "$NSEEN" -eq "$nmine" ] && [ "$((NDISP - 1))" -eq "$nmine" ]; then
  ok "[J2] shard '$GROUP' reached $NSEEN mutants and dispatched $((NDISP - 1)), of $nmine dealt"
else
  bad "[J2] shard '$GROUP' reached $NSEEN mutants and dispatched $((NDISP - 1)), of $nmine dealt -- a dealt mutant never ran"
fi
# MT3 -- THE TEMPLATES WERE USED, AND ONLY WHERE ELIGIBLE. The ineligible count is derived from this
# file's own `mutant` lines (the ones dealt here whose subject is not the merge), independently of the
# scorers' cmp; every eligible scorer, MX0 among them, must have cloned at least once, and no
# ineligible one may have.
_want_no=0
for _m in $MINE; do
  _f="$(sed -n "s/^mutant \"$_m [^\"]*\" \([a-z-]*\.sh\) .*/\1/p" "$SELF")"
  [ -n "$_f" ] && [ "$_f" != merge-review-shards.sh ] && _want_no=$((_want_no + 1))
done
_no=0; _bad=""; _hits=0; _c0=""
while IFS='	' read -r id label want; do
  _e="$(cat "$WORK/mut-$id/tpl.elig" 2>/dev/null)"; _h="$(grep -c . "$WORK/mut-$id/tpl.hits" 2>/dev/null)" || _h=0
  case "$_e" in
    yes) [ "$_h" -gt 0 ] || _bad="$_bad ${label%% *}(eligible,0 hits)"; _hits=$((_hits + _h)) ;;
    no)  _no=$((_no + 1)); [ "$_h" -eq 0 ] || _bad="$_bad ${label%% *}(ineligible,$_h hits)" ;;
    *)   _bad="$_bad ${label%% *}(no eligibility record)" ;;
  esac
  case "$label" in "MX0 "*) _c0="$_e/$_h" ;; esac
done < "$IDX"
if [ -z "$_bad" ] && [ "$_no" -eq "$_want_no" ] && [ "${_c0%%/*}" = yes ] && [ "${_c0#*/}" -gt 0 ]; then
  ok "MT3: $_no scorer(s) rebuilt every world (the $_want_no dealt here mutate a builder-run script); every other scorer, MX0 among them ($_c0 hits), cloned the templates, $_hits clones in all"
else bad "MT3: ineligible $_no (want $_want_no), MX0 $_c0, offenders:${_bad:- none}"; fi
while IFS='	' read -r id label want; do
  if line="$(judge "$VD/$id" "$label" "$want")"; then ok "$line"; else bad "$line"; fi
  if [ -n "$ROWS" ] && [ -f "$VD/$id.v" ]; then
    IFS='	' read -r _l _n _d < "$VD/$id.v"; printf '%s\t%s\n' "$label" "$_d" >> "$ROWS"
  fi
done < "$IDX"

# THE JUDGMENT, PROBED ON A REAL VERDICT. The first MUTANT verdict this shard dispatched (the first
# row whose expected set is not the control's NONE) is copied aside and judged four ways against a
# scratch counter: its own expected set must PASS (else the probe proves nothing about a judge that
# always fails), a deliberately wrong set must FAIL, a STALL record beside it must FAIL, and the
# same stem with the verdict file deleted must FAIL. The wrong set is a predicate name no P_ALL member carries, so it can equal no mutant's.
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
