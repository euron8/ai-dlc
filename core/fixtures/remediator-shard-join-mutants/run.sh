#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# remediator-shard-join-mutants/run.sh -- the JX mutation battery behind `remediator-shard-join`.
# DISTRIBUTION-ONLY (see .dist-only).
#
# Usage: run.sh [--rows <file>]
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
#   - the number of mutants JUDGED must equal the number DECLARED in this file, and be > 0, so a
#     battery whose mutant calls were deleted fails rather than reporting a clean control;
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
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="remediator-shard-join-mutants"
ROWS=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --rows) ROWS="${2:-}"; [ -n "$ROWS" ] || { echo "usage: run.sh [--rows <file>]" >&2; exit 2; }; shift 2 ;;
    *) echo "usage: run.sh [--rows <file>]" >&2; exit 2 ;;
  esac
done
command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 not on PATH (the mutation helper)" >&2; exit 2; }
SIB="$HERE/../remediator-shard-join"
[ -f "$SIB/lib.sh" ] || { echo "FIXTURE BROKEN: $SIB/lib.sh is absent; no predicate exists to score a mutant against" >&2; exit 2; }
[ -f "$SIB/run.sh" ] || { echo "FIXTURE BROKEN: $SIB/run.sh is absent; the arm/P_ALL join has no subject" >&2; exit 2; }
. "$SIB/lib.sh"
# lib.sh's WORK is created after its argument parse ran here, so the rows file is opened only now.
if [ -n "$ROWS" ]; then : >> "$ROWS" || { echo "FIXTURE ERROR: cannot write --rows $ROWS" >&2; exit 2; }; fi

echo "$NAME:"

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
mutant() { # <label> <expected> <old> <new>
  local d; d="$(mutdir "${1%% *}")" || { bad "$1: FIXTURE BROKEN -- the sandbox could not be built"; return; }
  if ! apply "$d/join-remediator-shards.sh" "$3" "$4"; then
    bad "$1: FIXTURE STALE -- the mutation anchor is not in the join exactly once; re-anchor it, never relax the assertion"; return
  fi
  cmp -s "$JOIN" "$d/join-remediator-shards.sh" && { bad "$1: FIXTURE STALE -- the mutated copy is byte-identical"; return; }
  bash -n "$d/join-remediator-shards.sh" 2>/dev/null || { bad "$1: FIXTURE BROKEN -- the mutated join does not parse"; return; }
  dispatch "$1" "$d/join-remediator-shards.sh" "$2"
}
mutant2() { # <label> <expected> <old1> <new1> <old2> <new2> -- two layers reverted together
  local d; d="$(mutdir "${1%% *}")" || { bad "$1: FIXTURE BROKEN -- the sandbox could not be built"; return; }
  if ! apply "$d/join-remediator-shards.sh" "$3" "$4" || ! apply "$d/join-remediator-shards.sh" "$5" "$6"; then
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

# ---- BEGIN JX MUTANTS. The reap counts the `mutant`/`mutant2` calls between these two markers in
# this file as the DECLARED set, and requires every one of them judged.
# J2's world ALSO trips other refusals, so this mutant still exits 2 there; the kill is the
# missing overlap SENTENCE, which is the only thing that names the defect to the lead.
mutant "JX1 the >1-writer refusal removed" "overlap docoverlap sjspec2" \
  'if [ -n "$OVERLAPS" ]; then' \
  'if false; then'
mutant "JX2 the uncited-file refusal removed" "missing" \
  '      if (!(p in cov)) print "UNCITED\t" p "\t" wr[p]' \
  '      if (0) print "UNCITED\t" p "\t" wr[p]'
mutant "JX3 the shards/ exclusion removed" "shardrow" \
  '   | select($doc == "1" or ((.path | startswith($sh + "/")) | not))' \
  '   | select(true)'
# JX4 is the defect this mode exists to close: the files-mode filter applied in document mode drops
# every section row, so the join sees no write at all.
# partydoc is a document join too, and dies with the others. sjpartysrc does NOT: its subject keeps
# whole-file part rows outside shards/, so the join still reaches the source check and refuses by name.
mutant "JX4 section rows dropped in document mode (the pre-BL-372 file set)" "docjoin docoverlap asmrefuse sjoin sjnames sjgate sjnest partydoc" \
  '   | select($doc == "1" or ((.path | startswith($sh + "/")) | not))' \
  '   | select((.path | startswith($sh + "/")) | not)'
mutant "JX5 the assembly skipped" "docjoin asmrefuse partydoc" \
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
  'tok = substr(line, RSTART, RLENGTH); gsub(/\/\/+/, "/", tok); print tok' \
  'tok = substr(line, RSTART, RLENGTH); print tok'
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
IDONLY_OLD='      if (!((b SUBSEP id) in has)) {'
IDONLY_NEW='      if (!(id in who)) {'
PROBE_OLD='src_probe() {'
PROBE_NEW='src_probe() { return 0; }
src_probe_disabled() {'
# JX18: the id-only key with the self-probe IN PLACE -- the probe refuses before any corpus is read,
# so every party run stops at it: the arms that expect a party join or a NAMED refusal all die.
mutant "JX18 source keyed on the id alone (self-probe in place)" "sjnames party partyunres partynosrc partyforeign partydoc sjpartysrc srcok srcunres" \
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
mutant "JX22 files/document mode not a party repair for <name>-party" "partyunres partynosrc partyforeign" \
  'case "$ARTIFACT" in *-party) PARTY=1 ;; esac' \
  'case "$ARTIFACT" in *-never-a-name) PARTY=1 ;; esac'
mutant "JX23 subject --pass party not a party repair" "sjpartysrc" \
  '[ "$SUBJMODE" = 1 ] && [ "$PASS" = party ] && [ -z "$ARTIFACT" ] && PARTY=1' \
  'false && PARTY=1'
mutant "JX24 --sources reports refusals and exits 0" "srcunres" \
  '  [ "$refuse_n" -eq 0 ] || exit 2
  echo "SOURCES:' \
  '  true || exit 2
  echo "SOURCES:'
# ---- END JX MUTANTS.

# ------------------------------------------------------------------------------ the reap
wait
nidx="$(grep -c . "$IDX")" || nidx=0
nd="$(ndone)"
# DECLARED is read off this file's own source, between the markers; JUDGED is counted below as the
# reap walks the index. A control alone is NOT a battery: with every mutant call deleted the
# control still dispatches, still holds, and the run would otherwise read PASS.
ndecl="$(awk '/^# ---- BEGIN JX MUTANTS/ { on = 1; next } /^# ---- END JX MUTANTS/ { on = 0 } on && /^mutant2? "/' "$HERE/run.sh" | grep -c .)" || ndecl=0
if [ "$NDISP" -ge 2 ] && [ "$nidx" -eq "$NDISP" ] && [ "$nd" -eq "$NDISP" ]; then
  ok "MR: $NDISP scorers dispatched, $nidx recorded, $nd completed"
else
  bad "MR: $NDISP scorers dispatched, $nidx recorded, $nd completed -- a scorer was lost or never started"
fi
njudged=0
while IFS='	' read -r id label want; do
  [ "$want" = "NONE" ] || njudged=$((njudged + 1))
  if line="$(judge "$VD/$id" "$label" "$want")"; then ok "$line"; else bad "$line"; fi
  if [ -n "$ROWS" ] && [ -f "$VD/$id.v" ]; then
    IFS='	' read -r _l _n _d < "$VD/$id.v"; printf '%s\t%s\n' "$label" "$_d" >> "$ROWS"
  fi
done < "$IDX"
if [ "$ndecl" -gt 0 ] && [ "$njudged" -eq "$ndecl" ]; then
  ok "MC: $ndecl mutant(s) declared in this file, $njudged judged"
else
  bad "MC: $ndecl mutant(s) declared in this file, $njudged judged -- an emptied battery or a mutant that never reached the judge is never a pass"
fi

# THE JUDGMENT, PROBED ON A REAL VERDICT. JX1's verdict file is copied aside and judged four ways
# against a scratch counter: its own expected set must PASS (else the probe proves nothing about a
# judge that always fails), a deliberately wrong set must FAIL, a TIMEOUT marker beside it must
# FAIL, and the same stem with the verdict file deleted must FAIL.
pv="$(awk -F'\t' 'index($2, "JX1 ") == 1 { print $1; exit }' "$IDX")"
pw="$(awk -F'\t' 'index($2, "JX1 ") == 1 { print $3; exit }' "$IDX")"
pl="$(awk -F'\t' 'index($2, "JX1 ") == 1 { print $2; exit }' "$IDX")"
if [ -z "$pv" ] || [ ! -f "$VD/$pv.v" ]; then
  bad "MJ: FIXTURE BROKEN -- no JX1 verdict file to probe the judgment with"
else
  pd="$(mktemp -d "$WORK/judge-probe.XXXXXX")" && cp "$VD/$pv.v" "$pd/p.v"
  red=0
  judge "$pd/p" "$pl" "$pw" > /dev/null || red=$((red + 100))
  judge "$pd/p" "$pl" "overlap" > /dev/null || red=$((red + 1))
  : > "$pd/p.timeout"
  judge "$pd/p" "$pl" "$pw" > /dev/null || red=$((red + 1))
  rm -f "$pd/p.timeout" "$pd/p.v"
  judge "$pd/p" "$pl" "$pw" > /dev/null || red=$((red + 1))
  if [ "$red" -eq 3 ]; then
    ok "MJ: the judgment passes JX1's real verdict against its own set, and FAILS it against a wrong set, beside a TIMEOUT marker, and with the verdict file deleted"
  else
    bad "MJ: the judgment probe scored $red (want 3: real+right ok, real+wrong red, real+timeout red, deleted red; +100 means the right set failed)"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
