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
# ARMS (each is a CELL: it takes a program and answers pass or fail)
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
#              (three cells: AMBIG-zero, AMBIG-two, AMBIG-cells)
#   NOVAL      the program copied without its sibling validator -> exit 2, file unchanged
# MUTANTS (each a copy of the program beside a copy of the validator; each must flip its arm):
#   m-nocheck  the validator call replaced by success -> FUTURE accepted
#   m-nopay    the payload left empty -> FUTURE accepted (nothing judged)
#   m-early    the move over the snapshot done BEFORE the check -> FUTURE changes the file
#   m-rc1      exit 1 from the validator ignored -> FUTURE accepted
# A control drives the UNMUTATED copy through the same harness first and requires VALID and
# FUTURE to score as on the shipped program, so a copy that cannot run is not read as a scored mutant.
#
# THE MUTANT MATRIX. Each mutant is scored per push on its DECIDING cell (FUTURE) and its named TWIN (VALID),
# which the mutant must leave GREEN: it breaks the refusal and not the write path. `run.sh --matrix` scores each
# mutant against every cell and prints one MATRIX line per mutant. The matrix is re-measured whenever an arm or a
# mutant is added or changed, by the REMEASURE command below, run from the repo root.
# also trips: m-nocheck -> FUTUREROW,MALFORMED
# also trips: m-nopay -> FUTUREROW,MALFORMED
# also trips: m-early -> VALID,PIPED,FUTUREROW,MALFORMED,NEARMISS,OLDLINE
# also trips: m-rc1 -> FUTUREROW,MALFORMED
# MUTANT-MATRIX m-nocheck decides=FUTURE twins=VALID
# MUTANT-MATRIX m-nopay decides=FUTURE twins=VALID
# MUTANT-MATRIX m-early decides=FUTURE twins=NOVAL
# MUTANT-MATRIX m-rc1 decides=FUTURE twins=VALID
# MUTANT-MATRIX-CONTROL control why=the unmutated copy must write VALID and refuse FUTURE through the mutant harness so a mutant verdict is attributable to the mutation
# The four mutants are a loop over a spec list, so the name reaches mutant_killed as a variable:
# MUTANT-MATRIX-DYNAMIC mutants why=loops over the four mutant specs and every name keeps its own row
# MUTANT-MATRIX-REMEASURE bash core/fixtures/snapshot-update-stamps/run.sh --matrix
set -uo pipefail

MODE=plain
case "${1:-}" in
  "") ;;
  --matrix) MODE=matrix ;;
  *) echo "snapshot-update-stamps: usage: run.sh [--matrix]" >&2; exit 2 ;;
esac

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
MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

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

# cell <CELL> <program> <tag> -> 0 when the cell holds on that program (GREEN), 1 when it fails (RED).
# CELL_MSG carries the detail of a failure. Each cell seeds its own project under $WORK/<tag>-<cell>.
CELL_MSG=""
cell() {
  local c="$1" pr="$2" t="$3" s cs
  CELL_MSG=""
  case "$c" in
    VALID)
      s="$(seed "$WORK/$t-valid" 0)"
      drive "$pr" "$s" --activity "$T_OK gate PASS" --set last_gate_passed implementation \
        --row-status a1111111111111111 delivered-reachable --close-item story-1
      if [ "$RC" = 0 ] && grep -qF -- "- $T_OK gate PASS" "$s" && grep -qx -- '- last_gate_passed: implementation' "$s" \
         && grep -q 'delivered-reachable$' "$s" && ! grep -q 'story-1' "$s"; then return 0; fi
      CELL_MSG="rc=$RC"; return 1 ;;
    FUTURE)
      s="$(seed "$WORK/$t-future" 0)"; cs="$(cksum < "$s")"
      drive "$pr" "$s" --activity "$T_FUT planned"
      if [ "$RC" = 1 ] && grep -q '^FUTURE ' <<<"$OUT" && [ "$(cksum < "$s")" = "$cs" ]; then return 0; fi
      CELL_MSG="rc=$RC,changed=$([ "$(cksum < "$s")" = "$cs" ] && echo no || echo yes)"; return 1 ;;
    PIPED)
      s="$(seed "$WORK/$t-piped" 1)"
      drive "$pr" "$s" --row-status a1111111111111111 delivered-reachable \
        --row-add "a2222222222222222 | qa | /w/b.md | 2026-10-25T21:00:00Z | in-flight"
      if [ "$RC" = 0 ] && grep -qx '| a1111111111111111 | dev | /w/a.md | 2026-10-25T19:00:00Z | delivered-reachable |' "$s" \
         && grep -qx '| a2222222222222222 | qa | /w/b.md | 2026-10-25T21:00:00Z | in-flight |' "$s"; then return 0; fi
      CELL_MSG="rc=$RC $(sed -n '/In-Flight/,$p' "$s" | tr '\n' ' ')"; return 1 ;;
    FUTUREROW)
      s="$(seed "$WORK/$t-futrow" 0)"; cs="$(cksum < "$s")"
      drive "$pr" "$s" --row-add "a2222222222222222 | qa | /w/b.md | 2026-10-25T23:40:00Z | in-flight"
      if [ "$RC" = 1 ] && [ "$(cksum < "$s")" = "$cs" ]; then return 0; fi
      CELL_MSG="rc=$RC"; return 1 ;;
    MALFORMED)
      s="$(seed "$WORK/$t-malformed" 0)"; cs="$(cksum < "$s")"
      drive "$pr" "$s" --activity "2026-10-25T21:2xZ placeholder"
      if [ "$RC" = 1 ] && grep -q '^MALFORMED ' <<<"$OUT" && [ "$(cksum < "$s")" = "$cs" ]; then return 0; fi
      CELL_MSG="rc=$RC"; return 1 ;;
    NEARMISS)
      s="$(seed "$WORK/$t-nearmiss" 0)"
      drive "$pr" "$s" --activity "2026-10-25T2x:xxZ declared placeholder" --open-item "~2026-10-25T21:30Z approximate"
      if [ "$RC" = 0 ] && grep -qF 'declared placeholder' "$s" && grep -qF -- '- ~2026-10-25T21:30Z approximate' "$s"; then return 0; fi
      CELL_MSG="rc=$RC $OUT"; return 1 ;;
    OLDLINE)
      s="$(seed "$WORK/$t-oldline" 0)"
      drive "$pr" "$s" --activity "$T_OK unrelated"
      if [ "$RC" = 0 ] && grep -qF "$T_OK unrelated" "$s"; then return 0; fi
      CELL_MSG="rc=$RC $OUT"; return 1 ;;
    AMBIG-zero|AMBIG-two|AMBIG-cells)
      s="$(seed "$WORK/$t-$c" 0)"; cs="$(cksum < "$s")"
      case "$c" in
        AMBIG-zero)  drive "$pr" "$s" --close-item "no-such-item" ;;
        AMBIG-two)   drive "$pr" "$s" --close-item "fan-out round" ;;
        AMBIG-cells) drive "$pr" "$s" --row-add "a3 | qa | in-flight" ;;
      esac
      if [ "$RC" = 2 ] && [ "$(cksum < "$s")" = "$cs" ]; then return 0; fi
      CELL_MSG="rc=$RC"; return 1 ;;
    NOVAL)
      mkdir -p "$WORK/$t-lone"; cp "$pr" "$WORK/$t-lone/snapshot-update.sh"
      s="$(seed "$WORK/$t-noval" 0)"; cs="$(cksum < "$s")"
      drive "$WORK/$t-lone/snapshot-update.sh" "$s" --activity "$T_OK x"
      if [ "$RC" = 2 ] && [ "$(cksum < "$s")" = "$cs" ]; then return 0; fi
      CELL_MSG="rc=$RC"; return 1 ;;
    *) echo "MATRIX BROKEN unknown cell $c" >&2; exit 2 ;;
  esac
}
CELLS="VALID FUTURE PIPED FUTUREROW MALFORMED NEARMISS OLDLINE AMBIG-zero AMBIG-two AMBIG-cells NOVAL"

echo "snapshot-update-stamps:"

# --- shipped program --------------------------------------------------------
# VALID and FUTURE are the control cells every mutant is read through, so each sets its same-run flag in its passing branch.
if cell VALID "$PROG" ship; then ok "VALID: four ops in one call are written"; B_ship_valid=1; else bad "VALID: $CELL_MSG"; fi
if cell FUTURE "$PROG" ship; then ok "FUTURE: a stamp two hours ahead is refused and the file is unchanged"; B_ship_future=1; else bad "FUTURE: $CELL_MSG"; fi
if cell PIPED "$PROG" ship; then ok "PIPED: a row update on a \`| a | b |\` table keeps its pipes"; else bad "PIPED: $CELL_MSG"; fi
if cell FUTUREROW "$PROG" ship; then ok "FUTUREROW: a future dispatched-at is refused, file unchanged"; else bad "FUTUREROW: $CELL_MSG"; fi
if cell MALFORMED "$PROG" ship; then ok "MALFORMED: \`T21:2xZ\` is refused, file unchanged"; else bad "MALFORMED: $CELL_MSG"; fi
if cell NEARMISS "$PROG" ship; then ok "NEARMISS: the declared placeholder and a \`~\` approximation are written"; else bad "NEARMISS: $CELL_MSG"; fi
if cell OLDLINE "$PROG" ship; then ok "OLDLINE: a future stamp already in the file is not re-judged"; else bad "OLDLINE: $CELL_MSG"; fi
for c in zero two cells; do
  if cell "AMBIG-$c" "$PROG" ship; then ok "AMBIG/$c: refused with exit 2, file unchanged"; else bad "AMBIG/$c: $CELL_MSG"; fi
done
if cell NOVAL "$PROG" ship; then ok "NOVAL: no sibling validator is exit 2, nothing written"; else bad "NOVAL: $CELL_MSG"; fi

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
# The control drives the unmutated copy through the same cells: VALID passes and FUTURE refuses.
if cell VALID "$WORK/mut-control/snapshot-update.sh" control && cell FUTURE "$WORK/mut-control/snapshot-update.sh" control; then
  ok "control: the unmutated copy writes VALID and refuses FUTURE"; B_ctl=1
else bad "control: the unmutated copy fails VALID or FUTURE ($CELL_MSG) -- no mutant verdict below can be read"; fi

# ---- matrix plumbing. The header rows are the only source of a mutant's deciding cell and twin. ----
MXL="$WORK/mx.ledger"; : > "$MXL"
mx_row() { # <mutant> <decides|twins> -> that field of the mutant's single header row
  local n="$1" f="$2" l w c=0 v=""
  while IFS= read -r l; do
    case "$l" in
      "# MUTANT-MATRIX $n "*)
        c=$((c + 1))
        for w in ${l#"# MUTANT-MATRIX $n "}; do case "$w" in "$f="*) v="${w#"$f="}" ;; esac; done ;;
    esac
  done < "$HERE/run.sh"
  [ "$c" -eq 1 ] && printf '%s' "$v"
}
mx_count() { local k="$1" l n=0; while IFS= read -r l; do case "$l" in "$k "*) n=$((n + 1)) ;; esac; done < "$MXL"; printf '%s' "$n"; }

for m in \
  'm-nocheck|VOUT="$(AI_DLC_PROJECT_ROOT=|VOUT="$(true || AI_DLC_PROJECT_ROOT=' \
  'm-nopay|else if ($0 != "") print }|else if (0) print }' \
  'm-early|VOUT="$(AI_DLC_PROJECT_ROOT=|cp "$CAND" "$SNAP"; VOUT="$(AI_DLC_PROJECT_ROOT=' \
  'm-rc1|if [ "$VRC" -eq 1 ]; then|VRC=0; if false; then'; do
  name="${m%%|*}"; rest="${m#*|}"; old="${rest%%|*}"; new="${rest#*|}"
  mp="$(mkmut "$name" "$old" "$new")" || { bad "$name: mutation did not apply"; continue; }
  dec="$(mx_row "$name" decides)"; tw="$(mx_row "$name" twins)"
  if [ -z "$dec" ] || [ -z "$tw" ]; then bad "$name: no single MUTANT-MATRIX row names its deciding cell and twin"; continue; fi
  printf 'dec %s %s\n' "$name" "$dec" >> "$MXL"; printf 'dec %s %s\n' "$name" "$tw" >> "$MXL"
  if cell "$dec" "$mp" "$name"; then d=GREEN; dmsg=""; else d=RED; dmsg="$CELL_MSG"; fi
  if cell "$tw" "$mp" "$name"; then t=GREEN; else t=RED; fi
  if [ "$d" = RED ]; then
    mutant_killed "${B_ctl:-0}" "$name" "$name: scored by $dec ($dec failed on the mutant: $dmsg) with twin $tw GREEN"
  else
    bad "$name: SURVIVED -- $dec still holds on the mutant"
  fi
  if [ "$t" = RED ]; then bad "$name: its twin $tw also failed -- the mutant is not confined to its own cell"; fi
  if [ "$MODE" = matrix ]; then # mx-all-cells
    g=0; tot=0; rd=""
    for a in $CELLS; do
      if [ "$a" = "$dec" ] || [ "$a" = "$tw" ]; then continue; fi
      printf 'mx %s %s\n' "$name" "$a" >> "$MXL"
      tot=$((tot + 1)); if cell "$a" "$mp" "$name"; then g=$((g + 1)); else rd="$rd,$a"; fi
    done
    u=""
    if [ "$d" = GREEN ]; then u=" UNEXPECTED=$dec:GREEN"; fi
    if [ "$t" = RED ]; then u="$u UNEXPECTED=$tw:RED"; fi
    printf 'MATRIX %s decides=%s:%s twins=%s:%s others=%d/%d%s%s\n' "$name" "$dec" "$d" "$tw" "$t" "$g" "$tot" "${rd:+ red=${rd#,}}" "$u"
  fi
done

# RULE 9: a plain run executes NO matrix-only cell. The deciding and twin cells write the same ledger, so
# an empty matrix count cannot come from a ledger nothing writes.
mx_only="$(mx_count mx)"; mx_ctl="$(mx_count dec)"
if [ "$MODE" = plain ]; then
  if [ "$mx_ctl" -eq 0 ]; then bad "rule-9: the matrix ledger control is EMPTY, so a zero count of matrix-only cells means nothing"
  elif [ "$mx_only" -ne 0 ]; then bad "rule-9: a plain run executed $mx_only matrix-only cell(s) -- the --matrix measurement leaked into the per-push run"
  else ok "rule-9: a plain run executed no matrix-only cell, while $mx_ctl deciding or twin cell(s) wrote the same ledger"; fi
else
  echo "MATRIX-SUMMARY $mx_only matrix-only cell(s) ran"
fi

if [ "$fails" -eq 0 ]; then echo "snapshot-update-stamps: PASS"; exit 0; fi
echo "snapshot-update-stamps: $fails assertion(s) FAILED" >&2
exit 1
