#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# adversarial-shard-merge-mutants/run.sh -- the mutation battery behind `adversarial-shard-merge`.
# DISTRIBUTION-ONLY (see .dist-only).
#
# Usage: run.sh [--rows <file>]
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
#   - the reap counts DECLARED scorings (read from this file's own `mutant "` lines plus the
#     control), DISPATCHED scorings and JUDGED verdicts, and requires all three equal and > 0 --
#     an emptied battery declares 0 and FAILS rather than printing PASS over nothing;
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
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
SELF="$HERE/run.sh"
NAME="adversarial-shard-merge-mutants"
ROWS=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --rows) ROWS="${2:-}"; [ -n "$ROWS" ] || { echo "usage: run.sh [--rows <file>]" >&2; exit 2; }; shift 2 ;;
    *) echo "usage: run.sh [--rows <file>]" >&2; exit 2 ;;
  esac
done
command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 not on PATH (the mutation helper)" >&2; exit 2; }
SIB="$HERE/../adversarial-shard-merge"
[ -f "$SIB/lib.sh" ] || { echo "FIXTURE BROKEN: $SIB/lib.sh is absent; no predicate exists to score a mutant against" >&2; exit 2; }
[ -f "$SIB/run.sh" ] || { echo "FIXTURE BROKEN: $SIB/run.sh is absent; the arm/P_ALL join has no subject" >&2; exit 2; }
. "$SIB/lib.sh"
if [ -n "$ROWS" ]; then : >> "$ROWS" || { echo "FIXTURE ERROR: cannot write --rows $ROWS" >&2; exit 2; }; fi

echo "$NAME:"

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
mutant() { # <label> <expected> <old> <new> [<old2> <new2>]
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
M6="$(mutdir m6b)"
if apply "$M6/merge-adversarial-shards.sh" '[ "${wrong:-0}" = "0" ] || refuse' '[ "${wrong:-0}" = "0" ] || true' 2>/dev/null \
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
mutant "XM1 one mode left single-cross" "b3 clean ceiling miss_ord miss_cross partition sha ms files_golden subj_b3 subj_miss_cross subj_xcite subj_sha subj_stems subj_art subj_elicit xfiles xelicit xmix xunknown xcomplete" \
  'bash "$XPART" --cross-groups "$K" > "$T/groups" 2> "$T/groups.err"; grc=$?' \
  'bash "$XPART" --cross-groups "$( [ -n "$DOCUMENT" ] && echo "$K" || echo 2)" > "$T/groups" 2> "$T/groups.err"; grc=$?'
# XM2: the owner rule off -- a finding two covering groups both report is summed twice. Only the
# duplicate cell of X1-X3 seeds one.
mutant "XM2 owner rule off (duplicate summed)" "xfiles xdoc xelicit" \
  '      [ "$ownk" = "$key" ] \' \
  '      true || [ "$ownk" = "$key" ] \'
# XM3: the merged tool_use_id taken from the LAST cross group read, not cross-1. Anchored on the
# EMISSION line, so only the emitted value moves: CROSS_FIRST also keys the files-mode cross
# artifact agreement, and a mutation there refused every files world for that other reason.
mutant "XM3 tool_use_id not cross-1" "doc_b3 files_golden xfiles xdoc xelicit" \
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

# ------------------------------------------------------------------------------ the reap
wait
# DECLARED is read from this file's own text: one control plus every line opening `mutant "`.
# An emptied battery declares 0, and 0 is a FAIL here, never a clean sheet.
ndecl="$(grep -c '^mutant "' "$SELF")" || ndecl=0
[ -n "${C0:-}" ] && ndecl=$((ndecl + 1))
nidx="$(grep -c . "$IDX")" || nidx=0
nd="$(ndone)"
njudged=0
while IFS='	' read -r id label want; do
  njudged=$((njudged + 1))
  if line="$(judge "$VD/$id" "$label" "$want")"; then ok "$line"; else bad "$line"; fi
  if [ -n "$ROWS" ] && [ -f "$VD/$id.v" ]; then
    IFS='	' read -r _l _n _d < "$VD/$id.v"; printf '%s\t%s\n' "$label" "$_d" >> "$ROWS"
  fi
done < "$IDX"
if [ "$ndecl" -gt 1 ] && [ "$NDISP" -eq "$ndecl" ] && [ "$nidx" -eq "$ndecl" ] && [ "$nd" -eq "$ndecl" ] && [ "$njudged" -eq "$ndecl" ]; then
  ok "MR: $ndecl scorings declared (control + mutants), $NDISP dispatched, $nidx recorded, $nd completed, $njudged judged"
else
  bad "MR: $ndecl scorings declared, $NDISP dispatched, $nidx recorded, $nd completed, $njudged judged -- want all equal and more than the control alone; a scorer was lost, never started, or the battery is empty"
fi

# THE JUDGMENT, PROBED ON A REAL VERDICT. MX1's verdict file is copied aside and judged four
# ways: its own expected set must PASS (else the probe proves nothing about a judge that always
# fails), a deliberately wrong set must FAIL, the same verdict beside a TIMEOUT marker must FAIL,
# and the same stem with the verdict file deleted must FAIL.
pv="$(awk -F'\t' 'index($2, "MX1 ") == 1 { print $1; exit }' "$IDX")"
pw="$(awk -F'\t' 'index($2, "MX1 ") == 1 { print $3; exit }' "$IDX")"
pl="$(awk -F'\t' 'index($2, "MX1 ") == 1 { print $2; exit }' "$IDX")"
if [ -z "$pv" ] || [ ! -f "$VD/$pv.v" ]; then
  bad "MJ: FIXTURE BROKEN -- no MX1 verdict file to probe the judgment with"
else
  pd="$(mktemp -d "$WORK/judge-probe.XXXXXX")" && cp "$VD/$pv.v" "$pd/p.v"
  red=0
  judge "$pd/p" "$pl" "$pw" > /dev/null || red=$((red + 100))
  judge "$pd/p" "$pl" "b3" > /dev/null || red=$((red + 1))
  : > "$pd/p.timeout"
  judge "$pd/p" "$pl" "$pw" > /dev/null || red=$((red + 1))
  rm -f "$pd/p.timeout" "$pd/p.v"
  judge "$pd/p" "$pl" "$pw" > /dev/null || red=$((red + 1))
  if [ "$red" -eq 3 ]; then
    ok "MJ: the judgment passes MX1's real verdict against its own set, and FAILS it against a wrong set, beside a TIMEOUT marker, and with the verdict file deleted"
  else
    bad "MJ: the judgment probe scored $red (want 3: real+right ok, real+wrong red, real+timeout red, deleted red; +100 means the right set failed)"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
