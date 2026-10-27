#!/usr/bin/env bash
# snapshot-update-stamps/run.sh — drive the REAL snapshot-update.sh against seeded snapshots and
# prove that it writes a valid update and writes NOTHING when the stamp check refuses.
#
# THE SUBJECT. A write of pipeline-snapshot.md made from a Bash call reaches no PostToolUse hook,
# so the derivation-capture hook's `validate-artifact-budget.sh --stamps-only` never sees it.
# snapshot-update.sh runs that mode itself, on the lines it adds, before it writes. The failure
# this fixture exists for is the program writing a stamp the hook would have named: a check that
# cannot fire reads exactly like one that passed, so every refusal arm asserts BOTH the exit code
# AND that the snapshot is byte-identical afterwards.
#
# ARMS
#   VALID      four ops in one call (activity, set, row-status, close-item) -> exit 0 and each
#              change is present in the file
#   PIPED      the same row update on a snapshot whose table is written `| a | b |` -> exit 0 and
#              the row keeps its pipes (the second spelling of an In-Flight row)
#   FUTURE     an activity line stamped two hours ahead -> exit 1, FUTURE named, file unchanged
#   FUTUREROW  a row whose dispatched-at is two hours ahead -> exit 1, file unchanged
#   MALFORMED  `T10:2xZ` -> exit 1, MALFORMED named, file unchanged
#   NEARMISS   `T1x:00Z` (the declared placeholder form) and `~2026-...` -> exit 0: the program
#              refuses what the validator refuses and nothing else
#   OLDLINE    a FUTURE stamp already in the snapshot is not re-judged when an unrelated line is
#              added -> exit 0 (only the added lines are the payload)
#   AMBIG      a target matching zero or two lines, a wrong cell count -> exit 2, file unchanged
#   NOVAL      the program copied without its sibling validator -> exit 2, file unchanged
# MUTANTS (each a copy of the program beside a copy of the validator; each must flip its arm):
#   m-nocheck  the validator call replaced by success -> FUTURE accepted
#   m-nopay    the payload left empty -> FUTURE accepted (nothing judged)
#   m-early    the move over the snapshot done BEFORE the check -> FUTURE changes the file
#   m-rc1      exit 1 from the validator ignored -> FUTURE accepted
# A control drives the UNMUTATED copy through the same harness first and requires VALID and
# FUTURE to score as on the shipped program, so a copy that cannot run is not read as a kill.
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
PROG=""; VAL=""
for d in "$ROOT/core/scripts" "$ROOT/scripts/ai-dlc"; do
  if [ -f "$d/snapshot-update.sh" ] && [ -f "$d/validate-artifact-budget.sh" ]; then
    PROG="$d/snapshot-update.sh"; VAL="$d/validate-artifact-budget.sh"; break
  fi
done
[ -n "$PROG" ] || { echo "FIXTURE ERROR: snapshot-update.sh and validate-artifact-budget.sh not found together in either layout" >&2; exit 2; }
# Both layouts print the resolved absolute paths: the runner maps a consumer's declared path and
# accepts it prefixed by the sandbox root, so a sentinel printed in one layout only fails the other.
printf 'HERMETIC-CONSUMED %s\nHERMETIC-CONSUMED %s\n' "$PROG" "$VAL"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/snapshot-update-stamps.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }

NOW=1792964000                      # 2026-10-25T21:33:20Z, pinned so the arms do not race the clock
export AI_DLC_SNAPSHOT_NOW_EPOCH="$NOW"
T_OK="2026-10-25T21:30Z"
T_FUT="2026-10-25T23:40Z"           # ~2 h ahead of NOW, past the validator's 600 s slack

# seed <dir> <piped 0|1> -> a project root with .claude/ and a snapshot; prints the snapshot path
seed() {
  local p="$1" bar="" end=""
  [ "$2" = 1 ] && { bar="| "; end=" |"; }
  mkdir -p "$p/.claude" "$p/_bmad-output"
  {
    printf '# Pipeline Snapshot\n\n## Pipeline Position\n- current_step: implementation\n- last_gate_passed: none\n\n'
    printf '## Recent Activity\n- 2026-10-25T20:00Z older entry\n- 2026-10-25T23:59Z an old line already carrying a future stamp\n\n'
    printf '## Open Items\n- fan-out round story-1 since 2026-10-25T19:00Z\n- fan-out round story-2 since 2026-10-25T19:05Z\n\n'
    printf '## In-Flight Teammates\n'
    printf '%sagent | role | deliverable | dispatched-at | status%s\n' "$bar" "$end"
    printf '%s--- | --- | --- | --- | ---%s\n' "$bar" "$end"
    printf '%sa1111111111111111 | dev | /w/a.md | 2026-10-25T19:00:00Z | in-flight%s\n' "$bar" "$end"
  } > "$p/_bmad-output/pipeline-snapshot.md"
  printf '%s' "$p/_bmad-output/pipeline-snapshot.md"
}

RC=""; OUT=""
# drive <program> <snapshot> <ops...>
drive() { local pr="$1" s="$2"; shift 2
  OUT="$(AI_DLC_PROJECT_ROOT="${s%/_bmad-output/*}" bash "$pr" --snapshot "$s" "$@" 2>&1)"; RC=$?; }

# arms <program> <tag> -> runs the refusal-critical arms; prints one verdict word per arm
arms() {
  local pr="$1" t="$2" s c
  s="$(seed "$WORK/$t-valid" 0)"
  drive "$pr" "$s" --activity "$T_OK gate PASS" --set last_gate_passed implementation \
    --row-status a1111111111111111 delivered-reachable --close-item story-1
  if [ "$RC" = 0 ] && grep -qF -- "- $T_OK gate PASS" "$s" && grep -qx -- '- last_gate_passed: implementation' "$s" \
     && grep -q 'delivered-reachable$' "$s" && ! grep -q 'story-1' "$s"; then echo VALID=pass; else echo VALID=fail; fi
  s="$(seed "$WORK/$t-future" 0)"; c="$(cksum < "$s")"
  drive "$pr" "$s" --activity "$T_FUT planned"
  if [ "$RC" = 1 ] && grep -q '^FUTURE ' <<<"$OUT" && [ "$(cksum < "$s")" = "$c" ]; then echo FUTURE=refused
  else echo "FUTURE=accepted(rc=$RC,changed=$([ "$(cksum < "$s")" = "$c" ] && echo no || echo yes))"; fi
}

echo "snapshot-update-stamps:"

# --- shipped program --------------------------------------------------------
v="$(arms "$PROG" ship)"
case "$v" in *VALID=pass*) ok "VALID: four ops in one call are written" ;; *) bad "VALID: $v" ;; esac
case "$v" in *FUTURE=refused*) ok "FUTURE: a stamp two hours ahead is refused and the file is unchanged" ;; *) bad "FUTURE: $v" ;; esac

s="$(seed "$WORK/piped" 1)"
drive "$PROG" "$s" --row-status a1111111111111111 delivered-reachable \
  --row-add "a2222222222222222 | qa | /w/b.md | 2026-10-25T21:00:00Z | in-flight"
if [ "$RC" = 0 ] && grep -qx '| a1111111111111111 | dev | /w/a.md | 2026-10-25T19:00:00Z | delivered-reachable |' "$s" \
   && grep -qx '| a2222222222222222 | qa | /w/b.md | 2026-10-25T21:00:00Z | in-flight |' "$s"; then
  ok "PIPED: a row update on a \`| a | b |\` table keeps its pipes"
else bad "PIPED: rc=$RC $(sed -n '/In-Flight/,$p' "$s" | tr '\n' ' ')"; fi

s="$(seed "$WORK/futrow" 0)"; c="$(cksum < "$s")"
drive "$PROG" "$s" --row-add "a2222222222222222 | qa | /w/b.md | 2026-10-25T23:40:00Z | in-flight"
[ "$RC" = 1 ] && [ "$(cksum < "$s")" = "$c" ] && ok "FUTUREROW: a future dispatched-at is refused, file unchanged" \
  || bad "FUTUREROW: rc=$RC"

s="$(seed "$WORK/malformed" 0)"; c="$(cksum < "$s")"
drive "$PROG" "$s" --activity "2026-10-25T21:2xZ placeholder"
[ "$RC" = 1 ] && grep -q '^MALFORMED ' <<<"$OUT" && [ "$(cksum < "$s")" = "$c" ] \
  && ok "MALFORMED: \`T21:2xZ\` is refused, file unchanged" || bad "MALFORMED: rc=$RC"

s="$(seed "$WORK/nearmiss" 0)"
drive "$PROG" "$s" --activity "2026-10-25T2x:xxZ declared placeholder" --open-item "~2026-10-25T21:30Z approximate"
[ "$RC" = 0 ] && grep -qF 'declared placeholder' "$s" && grep -qF -- '- ~2026-10-25T21:30Z approximate' "$s" \
  && ok "NEARMISS: the declared placeholder and a \`~\` approximation are written" || bad "NEARMISS: rc=$RC $OUT"

s="$(seed "$WORK/oldline" 0)"
drive "$PROG" "$s" --activity "$T_OK unrelated"
[ "$RC" = 0 ] && grep -qF "$T_OK unrelated" "$s" \
  && ok "OLDLINE: a future stamp already in the file is not re-judged" || bad "OLDLINE: rc=$RC $OUT"

for spec in "zero|--close-item|no-such-item" "two|--close-item|fan-out round" "cells|--row-add|a3 | qa | in-flight"; do
  name="${spec%%|*}"; rest="${spec#*|}"; flag="${rest%%|*}"; arg="${rest#*|}"
  s="$(seed "$WORK/ambig-$name" 0)"; c="$(cksum < "$s")"
  drive "$PROG" "$s" "$flag" "$arg"
  [ "$RC" = 2 ] && [ "$(cksum < "$s")" = "$c" ] && ok "AMBIG/$name: refused with exit 2, file unchanged" \
    || bad "AMBIG/$name: rc=$RC"
done

mkdir -p "$WORK/lone"; cp "$PROG" "$WORK/lone/snapshot-update.sh"
s="$(seed "$WORK/noval" 0)"; c="$(cksum < "$s")"
drive "$WORK/lone/snapshot-update.sh" "$s" --activity "$T_OK x"
[ "$RC" = 2 ] && [ "$(cksum < "$s")" = "$c" ] && ok "NOVAL: no sibling validator is exit 2, nothing written" \
  || bad "NOVAL: rc=$RC"

left="$(ls -a "$WORK"/*/_bmad-output 2>/dev/null)"
n_out="$(grep -c 'pipeline-snapshot\.md$' <<<"$left")" || n_out=0
if grep -q '\.candidate\.\|\.payload\.' <<<"$left"; then bad "LEFTOVER: a candidate or payload file survived a run"
elif [ "$n_out" -lt 10 ]; then bad "LEFTOVER: the listing saw $n_out snapshot(s), so it read no seeded project"
else ok "LEFTOVER: no candidate or payload file survives across $n_out seeded projects"; fi

# --- mutants ----------------------------------------------------------------
# mkmut <name> <old> <new>: a copy of the program beside a copy of the validator, one literal
# line replaced; cmp -s guards a replacement that matched nothing. The spec below splits on `|`,
# so no old or new text may carry one: an anchor holding `||` is cut short and mutates the wrong
# text (measured: the first m-early spelling did, and survived for that reason).
mkmut() {
  local d="$WORK/mut-$1"; mkdir -p "$d"
  cp "$VAL" "$d/validate-artifact-budget.sh" || return 1
  MM_OLD="$2" MM_NEW="$3" awk 'BEGIN { o = ENVIRON["MM_OLD"]; n = ENVIRON["MM_NEW"] }
    { if (!done && index($0, o)) { i = index($0, o); $0 = substr($0, 1, i - 1) n substr($0, i + length(o)); done = 1 } print }' \
    "$PROG" > "$d/snapshot-update.sh"
  cmp -s "$PROG" "$d/snapshot-update.sh" && { echo "DID NOT APPLY"; return 1; }
  printf '%s' "$d/snapshot-update.sh"
}
mkdir -p "$WORK/mut-control"; cp "$VAL" "$WORK/mut-control/validate-artifact-budget.sh"; cp "$PROG" "$WORK/mut-control/snapshot-update.sh"
cv="$(arms "$WORK/mut-control/snapshot-update.sh" control)"
case "$cv" in *VALID=pass*FUTURE=refused*) ok "control: the unmutated copy writes VALID and refuses FUTURE" ;;
  *) bad "control: the unmutated copy scored '$cv' -- no mutant verdict below can be read"; ;; esac

for m in \
  'm-nocheck|VOUT="$(AI_DLC_PROJECT_ROOT=|VOUT="$(true || AI_DLC_PROJECT_ROOT=' \
  'm-nopay|else if ($0 != "") print }|else if (0) print }' \
  'm-early|VOUT="$(AI_DLC_PROJECT_ROOT=|cp "$CAND" "$SNAP"; VOUT="$(AI_DLC_PROJECT_ROOT=' \
  'm-rc1|if [ "$VRC" -eq 1 ]; then|VRC=0; if false; then'; do
  name="${m%%|*}"; rest="${m#*|}"; old="${rest%%|*}"; new="${rest#*|}"
  mp="$(mkmut "$name" "$old" "$new")" || { bad "$name: mutation did not apply"; continue; }
  mv_="$(arms "$mp" "$name")"
  case "$mv_" in
    *FUTURE=refused*) bad "$name: SURVIVED -- FUTURE still refused ($mv_)" ;;
    *FUTURE=accepted*) ok "$name: killed -- $(printf '%s' "$mv_" | grep -o 'FUTURE=[^ ]*')" ;;
    *) bad "$name: no FUTURE verdict ($mv_)" ;;
  esac
done

if [ "$fails" -eq 0 ]; then echo "snapshot-update-stamps: PASS"; exit 0; fi
echo "snapshot-update-stamps: $fails assertion(s) FAILED" >&2
exit 1
