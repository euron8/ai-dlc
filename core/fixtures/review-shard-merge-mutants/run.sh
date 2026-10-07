#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# review-shard-merge-mutants/run.sh -- the mutation battery behind `review-shard-merge`.
# DISTRIBUTION-ONLY (see .dist-only).
#
# Usage: run.sh [--rows <file>]
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
#     missing verdict, a TIMEOUT, or an evaluated count other than |P_ALL| as a FAIL;
#   - `judge` itself is probed every run, on a real verdict file, in both directions.
# The pool is a FIXED width of 8 (no knob); completion is read from sentinel files the scorers
# write, never from the process table.
#
# THE WATCHDOG. bash 3.2 has no `wait -n`, so each scorer runs under a slot that polls it and,
# past SCORER_BOUND seconds, writes a TIMEOUT marker and kills the scorer's whole process tree
# (stopped first, then children before parents, so nothing reparents to init and keeps spinning).
# The bound is sized against the LOADED cost, not the solo one: the unsplit fixture's loaded cost
# was 1738s for 52 scorings plus the arms, about 33s a scoring, and a unit under the gate's pool
# has measured 4x its solo time. 900s is roughly 27x that per-scoring figure.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset AI_DLC_REVIEW_SHARD_MIN_FILES

HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="review-shard-merge-mutants"
ROWS=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --rows) ROWS="${2:-}"; [ -n "$ROWS" ] || { echo "usage: run.sh [--rows <file>]" >&2; exit 2; }; shift 2 ;;
    *) echo "usage: run.sh [--rows <file>]" >&2; exit 2 ;;
  esac
done
command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 not on PATH (the mutation helper)" >&2; exit 2; }
SIB="$HERE/../review-shard-merge"
[ -f "$SIB/lib.sh" ] || { echo "FIXTURE BROKEN: $SIB/lib.sh is absent; no predicate exists to score a mutant against" >&2; exit 2; }
[ -f "$SIB/run.sh" ] || { echo "FIXTURE BROKEN: $SIB/run.sh is absent; the arm/P_ALL join has no subject" >&2; exit 2; }
. "$SIB/lib.sh"
# lib.sh's WORK is created after its argument parse ran here, so the rows file is opened only now.
if [ -n "$ROWS" ]; then : >> "$ROWS" || { echo "FIXTURE ERROR: cannot write --rows $ROWS" >&2; exit 2; }; fi

echo "$NAME:"
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
SCORER_BOUND=900
VD="$WORK/verdicts"; mkdir -p "$VD" || { echo "FIXTURE ERROR: cannot create $VD" >&2; exit 2; }
IDX="$WORK/dispatch.tsv"; : > "$IDX"
NDISP=0

# One scorer: every predicate against <script-dir>, in P_ALL order, in its own scratch.
scorer() { # <id> <label> <script-dir>
  trap - EXIT
  local id="$1" label="$2" sd="$3" sw p n=0 dead=""
  sw="$WORK/mut-$id"; mkdir -p "$sw" || exit 1
  WORK="$sw"; bind_scratch "$sw"; RC=""; PRC=""
  for p in $P_ALL; do n=$((n + 1)); "p_$p" "$sd" || dead="$dead $p"; done
  dead="${dead# }"
  printf '%s\t%s\t%s\n' "$label" "$n" "$dead" > "$VD/$id.tmp" && mv "$VD/$id.tmp" "$VD/$id.v"
}
killtree() { # <pid>: stop it, take its children down first, then it
  local c
  kill -STOP "$1" 2>/dev/null
  for c in $(pgrep -P "$1" 2>/dev/null); do killtree "$c"; done
  kill -9 "$1" 2>/dev/null
}
slot() { # <id> <label> <script-dir>: the scorer under its watchdog, then the completion sentinel
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
mutant() { # <label> <file> <expected> <old> <new> [<old2> <new2>]
  local label="$1" f="$2" want="$3" d; d="$(mutdir "${label%% *}")"
  if ! apply "$d/$f" "$4" "$5" || { [ $# -ge 7 ] && ! apply "$d/$f" "$6" "$7"; }; then
    bad "$label: FIXTURE STALE -- the mutation anchor is not in $f exactly once; re-anchor it, never relax the assertion"; return
  fi
  if cmp -s "$SRCDIR/$f" "$d/$f"; then bad "$label: FIXTURE STALE -- the mutated copy is byte-identical"; return; fi
  bash -n "$d/$f" 2>/dev/null || { bad "$label: FIXTURE BROKEN -- the mutated $f does not parse"; return; }
  dispatch "$label" "$d" "$want"
}

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
mutant "MQ1 the qa rank inverted (PASS worst)" merge-review-shards.sh "q_worst" \
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
nidx="$(grep -c . "$IDX")" || nidx=0
nd="$(ndone)"
if [ "$NDISP" -ge 2 ] && [ "$nidx" -eq "$NDISP" ] && [ "$nd" -eq "$NDISP" ]; then
  ok "MR: $NDISP scorers dispatched, $nidx recorded, $nd completed"
else
  bad "MR: $NDISP scorers dispatched, $nidx recorded, $nd completed -- a scorer was lost or never started"
fi
while IFS='	' read -r id label want; do
  if line="$(judge "$VD/$id" "$label" "$want")"; then ok "$line"; else bad "$line"; fi
  if [ -n "$ROWS" ] && [ -f "$VD/$id.v" ]; then
    IFS='	' read -r _l _n _d < "$VD/$id.v"; printf '%s\t%s\n' "$label" "$_d" >> "$ROWS"
  fi
done < "$IDX"

# THE JUDGMENT, PROBED ON A REAL VERDICT. MX1's verdict file is copied aside and judged three
# ways against a scratch counter: its own expected set must PASS (else the probe proves nothing
# about a judge that always fails), a deliberately wrong set must FAIL, and the same stem with the
# verdict file deleted must FAIL.
pv="$(awk -F'\t' 'index($2, "MX1 ") == 1 { print $1; exit }' "$IDX")"
pw="$(awk -F'\t' 'index($2, "MX1 ") == 1 { print $3; exit }' "$IDX")"
pl="$(awk -F'\t' 'index($2, "MX1 ") == 1 { print $2; exit }' "$IDX")"
if [ -z "$pv" ] || [ ! -f "$VD/$pv.v" ]; then
  bad "MJ: FIXTURE BROKEN -- no MX1 verdict file to probe the judgment with"
else
  pd="$(mktemp -d "$WORK/judge-probe.XXXXXX")" && cp "$VD/$pv.v" "$pd/p.v"
  red=0
  judge "$pd/p" "$pl" "$pw" > /dev/null || red=$((red + 100))
  judge "$pd/p" "$pl" "worst" > /dev/null || red=$((red + 1))
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
