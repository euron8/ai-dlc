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
#   LOCKWAIT   FORCED interleave, never a race: the fixture holds the lock with its own live pid,
#              starts a writer in the background, blocks on the writer's own ops file (a CONDITION
#              the writer creates before it tries the lock), asserts the writer has neither written
#              nor exited, writes a row as the holder, releases the lock and `wait`s on the writer's
#              pid -> exit 0 and BOTH rows present. The writer's wait (3600 s) is a ceiling no
#              assertion reads: the verdict comes from the `wait`, not from a clock.
#   LOCKSTALE  a lock whose pid file names a reaped (dead) pid -> broken, exit 0, the line written
#   LOCKTIMEOUT the lock held for the WHOLE run, AI_DLC_SNAPSHOT_LOCK_TENTHS=1 -> exit 3, LOCK
#              TIMEOUT named, file unchanged. Its verdict holds at any load: the lock is never free.
#   BLOCKSET   `--set user_request_verbatim x` on the scrubbed live snapshot's block -> exit 2, unchanged
#   BLOCKCONTENT `--set-block` content carrying `- current step: x.md` -> exit 2, unchanged; on
#              graph-skeleton.md (no position bullet) content `the current step is x` -> exit 2 naming
#              --set current_step_file, unchanged; the same content on live-snapshot.md is written
#   STATUSVOC  `--row-set A status 'in-flight (join: x)'` and `--row-status A delivered` -> exit 2, unchanged
#   READERS    an op-only snapshot (`--init`, `--set current_step_file`, `--set-block` on Pipeline
#              Position) read by the SHIPPED continue hook (`Current step: route.md.`), recover hook
#              (`step_file=route.md`) and the dispatch guard's sprint_id sed, extracted from the guard
#              by its anchor and evaluated (42). The count grammar is never copied here (I113).
#   SETBOLD    `--set current_step_file` on a `- **current_step_file:**` seed rewrites it canonical
#              in place (one bullet), and the continue hook reads the new value
#   LIVE       every NONE class of the s319-s321 walk as ops, in one call, on live-snapshot.md: a row
#              cell rewrite, a row replace (delete + add), the `(none in flight ...)` placeholder
#              retired by --line-delete, a Recent Activity rewrite (--line-replace) and trim
#              (--move-to-history), a key add (--set ... <section>) and a key delete, an Open Items
#              bullet rewrite, a Locked Decisions append, handoff finalisation (a row set `stopped`,
#              --open-item-file) and the block rewrite (--set-block); the initial write (--init) is
#              READERS'. Each is asserted, and the prose above the In-Flight header is kept byte for byte.
#   SECADD     --section-add on graph-skeleton.md (the reference consumer's reset-skeleton heredoc,
#              extracted read-only): In-Flight Teammates with its header and a declared extra, both
#              before Context Reminders; the suffixed `Deploy Baseline (...)` heading resolves to its
#              declared name, so a second add is refused; `Deploy Baselines` (undeclared) is refused;
#              Sprint Context lands between Pipeline Position and Recent Activity
#   SECMOVE    --section-move-to-history moves an invented section whole, history first; Open Items refused
#   SWALLOW    swallowed-row.md (graph c3c00660f's tail, scrubbed: a row ending `| in-flight## Context
#              Reminders`) repaired by --row-replace then --section-add 'Context Reminders'
#   ROWREPLACE --row-replace rewrites one row; bad cell count and non-member status exit 2; an identical
#              --row-add is exit 0 with no change; a differing one is exit 2 naming --row-replace
#   WRAPPED    a bullet with continuation lines is taken whole by --close-item, --line-replace,
#              --line-delete and --move-to-history
#   KEYLINE    `- is_ui_epic: true` (a non-position key, so guard() cannot be what refuses it) by
#              --line-add into Sprint Context and a bold key by --line-replace into Pipeline Position:
#              exit 2; the same line into Locked Decisions is written
#   SETCREATE  --set create on graph-skeleton.md: a render_skeleton key (pipeline_variant) and an extra
#              allowlist key (is_ui_epic) are created; `lorem_key` and `current_branch` (the skeleton
#              key is `branch`) are refused
#   SECADD also refuses a declared extra named `Open Items Archive` (it begins with one of the seven)
#   ROWIDDUP   --row-replace whose new agent cell carries ANOTHER row's id is exit 2, unchanged; the
#              hit row's own id kept (a toolu_ id added) is written
#   HDRREMEDY  a row op on an In-Flight section with no header names `--line-add 'In-Flight Teammates'
#              '<header>'`, and that op, run as named, writes the header
#   SECDUP     two `## Open Items`: an op on the section is refused; --section-move-to-history moves
#              the LAST copy to history; the ops work again; validate-artifact-budget.sh --only
#              pipeline-snapshot.md exits 0 with no SCHEMA line (it cannot see a duplicate, so this is a
#              regression check only) and the continue, recover and Check 8 readers read route.md
#   POSLINE    with no dash position bullet, `* current_step_file:` and bare `current_step_file:` into
#              Pipeline Position, the bare one into Recent Activity, and `* pipeline_variant:` into
#              Pipeline Position, and `- <stamp> the current step is x: note` into Recent Activity while Pipeline
#              Position holds no dash bullet (the hooks' whole-file fallback reads it) are each exit 2,
#              unchanged; the SHIPPED continue hook, recover hook and
#              validate-mandatory-rules.sh Check 8 read no `wrong.md` (Check 8 SKIP as the control); a
#              dated activity line with a colon is written (near-miss); after the --set create all
#              three read route.md, the same activity line is then written (the counted state), and
#              `* current_step_file: wrong.md` into Recent Activity is still exit 2
#   IFADDREFUSE  --line-add into In-Flight Teammates of a row whose status is free text or `done`: exit 2,
#              the value named, unchanged (BL-963)
#   IFADDWRITE   the twin: a member-status row and a --- rule are written by --line-add there; a header
#              into a header-less section is HDRREMEDY's applied half
#   IFADDDUPHDR  a second header line-added beside the present one: exit 2, unchanged
#   m-noifadd  --line-add into In-Flight Teammates without the status check -> IFADDREFUSE; its anchor
#              `ifstatus_chk(B, 0)` is asserted to occur once
# CLOCK AND BACKGROUND, per arm: only LOCKWAIT runs a background process, and it blocks on the
# writer's own file and on `wait`, never on a sleep's length; its poll loop is bounded by the writer
# being alive. LOCKSTALE's dead pid is a subshell reaped before the lock is seeded. No arm reads the
# wall clock for its verdict: AI_DLC_SNAPSHOT_NOW_EPOCH pins the stamp check's "now".
# live-snapshot.md is a copy of a reference consumer's live snapshot, words scrubbed to `lorem`
# and `LOREM`, every structural byte kept: the 7 headings, the unpiped table, two prose paragraphs
# above its header, an agent cell with trailing words, a 5-paragraph block scalar with blank lines.
# MUTANTS (each a copy of the program beside a copy of the validator; each must flip its arm):
#   m-nocheck  the validator call replaced by success -> FUTURE accepted
#   m-nopay    the payload left empty -> FUTURE accepted (nothing judged)
#   m-early    the move over the snapshot done BEFORE the check -> FUTURE changes the file
#   m-rc1      exit 1 from the validator ignored -> FUTURE accepted
#   m-nolock   no lock: the mkdir loop never runs -> LOCKTIMEOUT writes through a held lock
#   m-blockline  a block scalar read as one line -> BLOCKSET rewrites the key, orphaning its block
#   m-blockcontent  --set-block without its content check -> BLOCKCONTENT writes a position bullet
#   m-nomember the status membership dropped at BOTH layers (status_ok, statuscell_ok) -> STATUSVOC writes
#   m-initheading  --init renders `##Pipeline Position` -> READERS: the ops after --init refuse
#              (the --set guard and --set-block find no Pipeline Position); the readers alone would
#              still resolve it through their whole-file fallback, so the kill is the ops'
#   m-setappend  --set appends a canonical bullet beside a bold-form match -> SETBOLD: two bullets
#              naming two step files, which the continue hook resolves to nothing
#   m-secorder --section-add always appends at the end -> SECADD order
#   m-secmovecanon  --section-move-to-history moves one of the seven -> SECMOVE
#   m-swallowtail   Context Reminders re-added at the file end, not under the last row -> SWALLOW
#   m-rowdiff  a differing --row-add dedupes silently -> ROWREPLACE
#   m-wrapend  the line ops act on the bullet line alone -> WRAPPED (continuations orphaned)
#   m-nokey    the two sections accept a `- key:` line by --line-add/--line-replace -> KEYLINE
#   m-allowall --set creates any key there -> SETCREATE (lorem_key written)
#   m-noskelallow   the allowlist loses its render_skeleton half -> SETCREATE (pipeline_variant refused)
#   m-rowiddup --row-replace skips the other-row id check -> ROWIDDUP
#   m-secprefix  an extra beginning with one of the seven is added -> SECADD
#   m-hdrremedy  the header-less refusal names --section-add again -> HDRREMEDY
#   m-secdup   a duplicated one of the seven is refused by --section-move-to-history -> SECDUP
#   m-curbranch  current_branch back in the create allowlist -> SETCREATE
#   m-posdash  the position-bullet refusal narrowed to a dash bullet -> POSLINE (in the counted state,
#              where the fallback guard is off, `* current_step_file:` into Recent Activity is written)
#   m-keydash  the key-line refusal narrowed to a dash bullet -> POSLINE (`* pipeline_variant:` written)
#   m-nofallback  the fallback-state refusal dropped -> POSLINE (the dated activity line is written and
#              the continue and recover hooks read `31Z the current step is x: note` as the position)
#   m-blockfb  --set-block content naming the key accepted in the fallback state -> BLOCKCONTENT
# A control drives the UNMUTATED copy through the same harness first and requires VALID and
# FUTURE to score as on the shipped program, so a copy that cannot run is not read as a scored mutant.
#
# THE MUTANT MATRIX. Each mutant is scored per push on its DECIDING cell (FUTURE) and its named TWIN (VALID),
# which the mutant must leave GREEN: it breaks the refusal and not the write path. `run.sh --matrix` scores each
# mutant against every cell and prints one MATRIX line per mutant. The matrix is re-measured as
# .claude/rules/fixture-mutants.md clause 2 ("One run per distinct state") requires. Run the REMEASURE command
# below, from the repo root.
# also trips: m-nocheck -> FUTUREROW,MALFORMED
# also trips: m-nopay -> FUTUREROW,MALFORMED
# also trips: m-early -> VALID,FUTUREROW,MALFORMED,NEARMISS,OLDLINE,LOCKSTALE,READERS,LIVE,SECADD,SECMOVE,SWALLOW,WRAPPED,KEYLINE,HDRREMEDY,SECDUP,POSLINE,IFLINEWRITE,IFADDWRITE
# also trips: m-rc1 -> FUTUREROW,MALFORMED
# also trips: m-setappend -> READERS
# also trips: m-nomember -> ROWREPLACE,IFLINEREFUSE,IFADDREFUSE,IFADDDUPHDR
# also trips: m-initheading -> SETCREATE,SECDUP,POSLINE
# also trips: m-nokey -> POSLINE
# also trips: m-noskelallow -> POSLINE
# also trips: m-ifhdrany -> IFADDDUPHDR
# also trips: m-ifrefuseall -> IFADDWRITE
# also trips: m-noifadd -> IFADDDUPHDR
# also trips: m-nolock, m-blockline, m-blockcontent -> none
# also trips: m-secorder, m-secmovecanon, m-swallowtail, m-rowdiff, m-wrapend, m-allowall -> none
# also trips: m-rowiddup, m-secprefix, m-hdrremedy, m-secdup, m-curbranch, m-posdash, m-keydash, m-nofallback, m-blockfb -> none
# also trips: m-noifguard, m-ifsepwide -> none
# MUTANT-MATRIX m-nocheck decides=FUTURE twins=VALID
# MUTANT-MATRIX m-nopay decides=FUTURE twins=VALID
# MUTANT-MATRIX m-early decides=FUTURE twins=NOVAL
# MUTANT-MATRIX m-rc1 decides=FUTURE twins=VALID
# MUTANT-MATRIX m-nolock decides=LOCKTIMEOUT twins=LOCKSTALE
# MUTANT-MATRIX m-blockline decides=BLOCKSET twins=VALID
# MUTANT-MATRIX m-blockcontent decides=BLOCKCONTENT twins=READERS
# MUTANT-MATRIX m-nomember decides=STATUSVOC twins=PIPED
# MUTANT-MATRIX m-initheading decides=READERS twins=SETBOLD
# MUTANT-MATRIX m-setappend decides=SETBOLD twins=LOCKSTALE
# MUTANT-MATRIX m-secorder decides=SECADD twins=SECMOVE
# MUTANT-MATRIX m-secmovecanon decides=SECMOVE twins=SECADD
# MUTANT-MATRIX m-swallowtail decides=SWALLOW twins=ROWREPLACE
# MUTANT-MATRIX m-rowdiff decides=ROWREPLACE twins=SWALLOW
# MUTANT-MATRIX m-wrapend decides=WRAPPED twins=KEYLINE
# MUTANT-MATRIX m-nokey decides=KEYLINE twins=SETCREATE
# MUTANT-MATRIX m-allowall decides=SETCREATE twins=KEYLINE
# MUTANT-MATRIX m-noskelallow decides=SETCREATE twins=WRAPPED
# MUTANT-MATRIX m-rowiddup decides=ROWIDDUP twins=ROWREPLACE
# MUTANT-MATRIX m-secprefix decides=SECADD twins=SECMOVE
# MUTANT-MATRIX m-hdrremedy decides=HDRREMEDY twins=SWALLOW
# MUTANT-MATRIX m-secdup decides=SECDUP twins=SECMOVE
# MUTANT-MATRIX m-curbranch decides=SETCREATE twins=KEYLINE
# MUTANT-MATRIX m-posdash decides=POSLINE twins=READERS
# MUTANT-MATRIX m-keydash decides=POSLINE twins=KEYLINE
# MUTANT-MATRIX m-nofallback decides=POSLINE twins=READERS
# MUTANT-MATRIX m-blockfb decides=BLOCKCONTENT twins=READERS
# MUTANT-MATRIX m-noifguard decides=IFLINEREFUSE twins=IFLINEWRITE
# MUTANT-MATRIX m-ifrefuseall decides=IFLINEWRITE twins=IFLINEREFUSE
# MUTANT-MATRIX m-ifhdrany decides=IFLINEREFUSE twins=IFLINEWRITE
# MUTANT-MATRIX m-ifsepwide decides=IFLINEREFUSE twins=IFLINEWRITE
# MUTANT-MATRIX m-noifadd decides=IFADDREFUSE twins=IFADDWRITE
# MUTANT-MATRIX-CONTROL control why=the unmutated copy must write VALID and refuse FUTURE through the mutant harness so a mutant verdict is attributable to the mutation
# The four mutants are a loop over a spec list, so the name reaches mutant_killed as a variable:
# MUTANT-MATRIX-DYNAMIC mutants why=one scoring function takes every mutant name as an argument and every name keeps its own row
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
# The shipped position and sprint readers (READERS, SETBOLD), in either layout.
hookpick() { local c; for c in "$ROOT/core/hooks/$1" "$ROOT/.claude/hooks/$1"; do [ -f "$c" ] && { printf '%s' "$c"; return 0; }; done; return 1; }
CONT_HOOK="$(hookpick ai-dlc-continue.sh)" && RECOVER_HOOK="$(hookpick ai-dlc-recover.sh)" && GUARD="$(hookpick ai-dlc-dispatch-guard.sh)" \
  || { echo "FIXTURE ERROR: ai-dlc-continue.sh, ai-dlc-recover.sh or ai-dlc-dispatch-guard.sh not found in either layout" >&2; exit 2; }
# The guard's sprint_id read, taken from the guard itself by its anchor: exactly one line, never retyped here.
GUARD_SPRINT_LINE="$(grep -F 'SPAWN_SPRINT="$(sed -n' "$GUARD")"
[ "$(printf '%s\n' "$GUARD_SPRINT_LINE" | grep -c .)" = 1 ] \
  || { echo "FIXTURE ERROR: ai-dlc-dispatch-guard.sh carries $(printf '%s\n' "$GUARD_SPRINT_LINE" | grep -c .) SPAWN_SPRINT sed line(s), not one" >&2; exit 2; }
printf 'HERMETIC-CONSUMED %s\nHERMETIC-CONSUMED %s\nHERMETIC-CONSUMED %s\n' "$CONT_HOOK" "$RECOVER_HOOK" "$GUARD"
# The third shipped position reader (POSLINE): Check 8 of validate-mandatory-rules.sh, beside the program.
VMR="${PROG%/*}/validate-mandatory-rules.sh"
[ -f "$VMR" ] || { echo "FIXTURE ERROR: validate-mandatory-rules.sh is not beside $PROG" >&2; exit 2; }
printf 'HERMETIC-CONSUMED %s\n' "$VMR"
LIVE="$(cd "$(dirname "$0")" && pwd)/live-snapshot.md"
[ -s "$LIVE" ] || { echo "FIXTURE ERROR: live-snapshot.md is missing beside run.sh" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/snapshot-update-stamps.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
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

# seed_live <dir> -> a project root holding the scrubbed copy of graph's live snapshot, with one
# `(none in flight ...)` placeholder line seeded above the In-Flight header; prints the snapshot path
seed_live() {
  local p="$1"
  mkdir -p "$p/.claude" "$p/_bmad-output"
  awk '/^agent \| role \|/ && !d { print "(none in flight -- every teammate joined)"; d = 1 } { print }' "$LIVE" > "$p/_bmad-output/pipeline-snapshot.md"
  printf '%s' "$p/_bmad-output/pipeline-snapshot.md"
}

# seed_copy <dir> <file> -> a project root holding <file> as its snapshot; prints the snapshot path
seed_copy() {
  mkdir -p "$1/.claude" "$1/_bmad-output"; cp "$2" "$1/_bmad-output/pipeline-snapshot.md"
  printf '%s' "$1/_bmad-output/pipeline-snapshot.md"
}
# sect <file> <heading prefix> -> the section's lines, heading included
sect() { awk -v h="## $2" 'index($0, h) == 1 { f = 1; print; next } /^## / { f = 0 } f' "$1"; }
GSKEL="$HERE/graph-skeleton.md"; SWALLOW="$HERE/swallowed-row.md"
[ -s "$GSKEL" ] && [ -s "$SWALLOW" ] || { echo "FIXTURE ERROR: graph-skeleton.md or swallowed-row.md is missing beside run.sh" >&2; exit 2; }
XSEC="Deploy Baseline,Operator Identity"

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
    LOCKWAIT)
      # FORCED INTERLEAVE, never a race: this fixture holds the lock (its own live pid), starts the
      # writer in the background with a wait far longer than the arm needs, blocks on a CONDITION --
      # the writer's own ops file, which it creates before it tries the lock -- then asserts the
      # writer has neither written nor exited, writes a row itself as the holder, releases the lock
      # and `wait`s on the writer's pid. Both rows must be present: the writer read the file the
      # holder left, not the one it found when it started.
      s="$(seed "$WORK/$t-lockwait" 0)"; cs="$(cksum < "$s")"
      local lk="${s%/*}/.pipeline-snapshot.md.lock" wt="$WORK/$t-lockwait/tmp" wp f seen=0
      mkdir -p "$wt" "$lk" && printf '%s\n' "$$" > "$lk/pid"
      AI_DLC_PROJECT_ROOT="${s%/_bmad-output/*}" AI_DLC_SNAPSHOT_LOCK_TENTHS=36000 TMPDIR="$wt" \
        bash "$pr" --snapshot "$s" --row-add "a2222222222222222 | qa | /w/b.md | 2026-10-25T21:00:00Z | in-flight" \
        > "$WORK/$t-lockwait/out" 2>&1 &
      wp=$!
      while kill -0 "$wp" 2>/dev/null; do
        for f in "$wt"/snapshot-update-ops.*; do [ -e "$f" ] && seen=1; done
        [ "$seen" = 1 ] && break
        sleep 0.05
      done
      if [ "$seen" != 1 ] || ! kill -0 "$wp" 2>/dev/null || [ "$(cksum < "$s")" != "$cs" ]; then
        rm -f "$lk/pid"; rmdir "$lk" 2>/dev/null; wait "$wp"
        CELL_MSG="the writer did not block behind the held lock (sentinel=$seen, rc=$?): $(cat "$WORK/$t-lockwait/out")"; return 1
      fi
      printf '%s\n' "a3333333333333333 | pm | /w/c.md | 2026-10-25T21:10:00Z | in-flight" >> "$s"
      rm -f "$lk/pid"; rmdir "$lk"
      # A release that did not take (measured: rmdir absent from the sandbox) would leave the writer
      # waiting out its whole ceiling. Stop it by the pid this cell recorded, and say why.
      if [ -d "$lk" ]; then
        kill "$wp" 2>/dev/null; wait "$wp"
        CELL_MSG="FIXTURE BROKEN: the held lock could not be released (rmdir failed), so the writer was stopped"; return 1
      fi
      wait "$wp"; RC=$?
      if [ "$RC" = 0 ] && grep -q '^a2222222222222222 ' "$s" && grep -q '^a3333333333333333 ' "$s" && [ ! -d "$lk" ]; then return 0; fi
      CELL_MSG="rc=$RC $(cat "$WORK/$t-lockwait/out")"; return 1 ;;
    LOCKSTALE)
      # A lock whose recorded holder is dead is broken and the write proceeds. The dead pid is a
      # subshell this fixture started and reaped, so it is dead by construction.
      s="$(seed "$WORK/$t-lockstale" 0)"
      local lk2="${s%/*}/.pipeline-snapshot.md.lock" dp
      ( exit 0 ) & dp=$!; wait "$dp"
      mkdir -p "$lk2" && printf '%s\n' "$dp" > "$lk2/pid"
      drive "$pr" "$s" --activity "$T_OK after a stale lock"
      if [ "$RC" = 0 ] && grep -qF -- "- $T_OK after a stale lock" "$s" && [ ! -d "$lk2" ]; then return 0; fi
      CELL_MSG="rc=$RC $OUT"; return 1 ;;
    LOCKTIMEOUT)
      # The lock is held by this fixture's live pid for the WHOLE run, so the writer can never take
      # it; a one-tenth wait makes it give up on its second look. Exit 3, nothing read or written.
      s="$(seed "$WORK/$t-locktimeout" 0)"; cs="$(cksum < "$s")"
      local lk3="${s%/*}/.pipeline-snapshot.md.lock"
      mkdir -p "$lk3" && printf '%s\n' "$$" > "$lk3/pid"
      OUT="$(AI_DLC_PROJECT_ROOT="${s%/_bmad-output/*}" AI_DLC_SNAPSHOT_LOCK_TENTHS=1 bash "$pr" --snapshot "$s" --activity "$T_OK blocked" 2>&1)"; RC=$?
      rm -f "$lk3/pid"; rmdir "$lk3" 2>/dev/null
      if [ "$RC" = 3 ] && grep -q 'LOCK TIMEOUT' <<<"$OUT" && [ "$(cksum < "$s")" = "$cs" ]; then return 0; fi
      CELL_MSG="rc=$RC changed=$([ "$(cksum < "$s")" = "$cs" ] && echo no || echo yes)"; return 1 ;;
    BLOCKSET)
      # graph's real block shape (the scrubbed live snapshot): `--set` on a block scalar is refused.
      s="$(seed_live "$WORK/$t-blockset")"; cs="$(cksum < "$s")"
      drive "$pr" "$s" --set user_request_verbatim x
      if [ "$RC" = 2 ] && [ "$(cksum < "$s")" = "$cs" ]; then return 0; fi
      CELL_MSG="rc=$RC $OUT"; return 1 ;;
    BLOCKCONTENT)
      s="$(seed_live "$WORK/$t-blockcontent")"; cs="$(cksum < "$s")"
      printf 'the request\n- current step: x.md\n' > "$WORK/$t-blockcontent/blk"
      drive "$pr" "$s" --set-block "Pipeline Position" user_request_verbatim "$WORK/$t-blockcontent/blk"
      { [ "$RC" = 2 ] && [ "$(cksum < "$s")" = "$cs" ]; } || { CELL_MSG="rc=$RC $OUT"; return 1; }
      # The fallback state (graph-skeleton.md: no position bullet): content merely NAMING the key is
      # refused, the remedy naming --set current_step_file; one property apart, the same content into
      # a world WITH a position bullet (live-snapshot.md) is written.
      local wf="$WORK/$t-blockfb" sf
      sf="$(seed_copy "$wf" "$GSKEL")"; cs="$(cksum < "$sf")"
      printf 'the current step is x\n' > "$wf/blk"
      AI_DLC_SNAPSHOT_EXTRA_SECTIONS="$XSEC" drive "$pr" "$sf" --set-block "Pipeline Position" user_request_verbatim "$wf/blk"
      { [ "$RC" = 2 ] && grep -qF -- '--set current_step_file' <<<"$OUT" && [ "$(cksum < "$sf")" = "$cs" ]; } || { CELL_MSG="fallback rc=$RC $OUT"; return 1; }
      AI_DLC_SNAPSHOT_NOW_EPOCH=1793923200 drive "$pr" "$s" --set-block "Pipeline Position" user_request_verbatim "$wf/blk"
      { [ "$RC" = 0 ] && grep -qx '    the current step is x' "$s"; } || { CELL_MSG="counted-twin rc=$RC $OUT"; return 1; }
      return 0 ;;
    STATUSVOC)
      s="$(seed "$WORK/$t-statusvoc" 0)"; cs="$(cksum < "$s")"
      drive "$pr" "$s" --row-set a1111111111111111 status 'in-flight (join: x)'; local r1="$RC"
      drive "$pr" "$s" --row-status a1111111111111111 delivered
      if [ "$r1" = 2 ] && [ "$RC" = 2 ] && [ "$(cksum < "$s")" = "$cs" ]; then return 0; fi
      CELL_MSG="row-set rc=$r1, row-status rc=$RC"; return 1 ;;
    READERS)
      # bl913: an op-only snapshot is read by the SHIPPED readers -- the continue hook's position
      # parse, the recover hook's step_file, and the dispatch guard's sprint_id sed (extracted from
      # the guard by its anchor and evaluated, never retyped).
      local w="$WORK/$t-readers" cont
      mkdir -p "$w/_bmad-output" "$w/.claude" "$w/home"; s="$w/_bmad-output/pipeline-snapshot.md"
      printf 'the request, line one\n\nline two\n' > "$w/blk"
      drive "$pr" "$s" --init steps-x.md 42 --set current_step_file route.md --set-block "Pipeline Position" user_request_verbatim "$w/blk"
      [ "$RC" = 0 ] || { CELL_MSG="the ops refused: rc=$RC $OUT"; return 1; }
      cont="$(printf '{"session_id":"t","transcript_path":""}' | HOME="$w/home" CLAUDE_PROJECT_DIR="$w" bash "$CONT_HOOK" 2>/dev/null)"
      printf '{"source":"compact","session_id":"t","transcript_path":""}' | HOME="$w/home" CLAUDE_PROJECT_DIR="$w" bash "$RECOVER_HOOK" > /dev/null 2>&1
      local SPAWN_SNAPSHOT="$s" SPAWN_SPRINT=""; eval "$GUARD_SPRINT_LINE"
      if grep -qF 'Current step: route.md.' <<<"$cont" && grep -qx 'step_file=route.md' "$w/_bmad-output/.recover-fired" 2>/dev/null \
         && [ "$SPAWN_SPRINT" = 42 ]; then return 0; fi
      CELL_MSG="continue=[$(grep -o 'Current step: [^ ]*' <<<"$cont")] recover=[$(grep '^step_file=' "$w/_bmad-output/.recover-fired" 2>/dev/null)] guard sprint=[$SPAWN_SPRINT]"; return 1 ;;
    SETBOLD)
      # A bold `- **current_step_file:**` seed is rewritten in place, canonical, never appended:
      # two bullets naming two step files resolve to NOTHING in the readers.
      local w="$WORK/$t-setbold" cont
      mkdir -p "$w/_bmad-output" "$w/.claude" "$w/home"; s="$w/_bmad-output/pipeline-snapshot.md"
      printf '# Pipeline Snapshot\n\n## Pipeline Position\n- **current_step_file:** old.md\n- last_gate_passed: none\n\n## Sprint Context\n- sprint_id: 7\n' > "$s"
      drive "$pr" "$s" --set current_step_file route.md
      cont="$(printf '{"session_id":"t","transcript_path":""}' | HOME="$w/home" CLAUDE_PROJECT_DIR="$w" bash "$CONT_HOOK" 2>/dev/null)"
      if [ "$RC" = 0 ] && grep -qF 'Current step: route.md.' <<<"$cont" && grep -qx -- '- current_step_file: route.md' "$s" \
         && [ "$(grep -c 'current_step_file' "$s")" = 1 ]; then return 0; fi
      CELL_MSG="rc=$RC continue=[$(grep -o 'Current step: [^ ]*' <<<"$cont")] bullets=$(grep -c 'current_step_file' "$s")"; return 1 ;;
    LIVE)
      # Every NONE class of the s319-s321 walk, as ops, on a scrubbed copy of graph's live snapshot:
      # unpiped rows, prose paragraphs above the In-Flight header, agent cells with trailing words, and
      # the multi-line user_request_verbatim with blank lines inside it. Stamps there run to
      # 2026-11-05, so this cell pins the stamp check's "now" to 2026-11-06.
      s="$(seed_live "$WORK/$t-live")"; local w="$WORK/$t-live" prose
      prose="$(awk '/^## In-Flight Teammates/{f=1;next} f && /^agent \|/{exit} f && !/^[(]none in flight/' "$s" | cksum)"
      printf 'the handoff item one\nthe handoff item two\n' > "$w/items"
      printf 'the request, rewritten\n\nwith a second paragraph\n' > "$w/blk"
      AI_DLC_SNAPSHOT_NOW_EPOCH=1793923200 drive "$pr" "$s" \
        --row-set a459c61a43cd916a8 deliverable s321/rewritten.md \
        --row-add "a0000000000000001 toolu_01old | dev | s321/a.md | 2026-11-05T00:30:00Z | in-flight" \
        --row-delete a0000000000000001 \
        --row-add "a0000000000000002 toolu_01new | dev | s321/a.md | 2026-11-05T00:31:00Z | in-flight" \
        --line-delete "In-Flight Teammates" "(none in flight" \
        --line-replace "Recent Activity" "2026-11-04T19:55:30Z" "- 2026-11-04T19:55:30Z rewritten in place" \
        --move-to-history "Recent Activity" "2026-10-30 (" \
        --set last_imminent_fire_turns 0 "Context Reminders" \
        --key-delete "Context Reminders" "hard_block_class[]" \
        --line-replace "Open Items" "1793774009" "- fan-out round since 1793774009 consumed" \
        --line-add "Locked Decisions" "- a second locked decision" --bottom \
        --set-block "Pipeline Position" user_request_verbatim "$w/blk" \
        --row-set a0000000000000002 status stopped \
        --open-item-file "$w/items"
      [ "$RC" = 0 ] || { CELL_MSG="the ops refused: rc=$RC $OUT"; return 1; }
      local miss=""
      grep -q '^a459c61a43cd916a8 (lorem a459c61a43cd916a8) | lorem | s321/rewritten.md | 2026-11-04T23:34:15Z | stopped$' "$s" || miss="$miss row-cell-rewrite"
      { ! grep -q '^a0000000000000001 ' "$s" && grep -qx 'a0000000000000002 toolu_01new | dev | s321/a.md | 2026-11-05T00:31:00Z | stopped' "$s"; } || miss="$miss row-replace+stopped"
      ! grep -qF '(none in flight' "$s" || miss="$miss placeholder"
      { grep -qx -- '- 2026-11-04T19:55:30Z rewritten in place' "$s" && [ "$(grep -c '2026-11-04T19:55:30Z' "$s")" = 1 ]; } || miss="$miss activity-rewrite"
      { ! grep -qF '2026-10-30 (' "$s" && grep -qF '2026-10-30 (' "${s%/*}/pipeline-snapshot-history.md" 2>/dev/null; } || miss="$miss activity-trim"
      grep -qx -- '- last_imminent_fire_turns: 0' <<<"$(awk '/^## Context Reminders/{f=1;next} /^## /{f=0} f' "$s")" || miss="$miss key-add"
      ! grep -qF 'hard_block_class[]' "$s" || miss="$miss key-delete"
      grep -qx -- '- fan-out round since 1793774009 consumed' "$s" || miss="$miss open-item-rewrite"
      [ "$(awk '/^## Locked Decisions/{f=1;next} /^## /{f=0} f && NF' "$s" | tail -1)" = "- a second locked decision" ] || miss="$miss locked-append"
      [ "$(awk '/^## Open Items/{f=1;next} f && NF {print; if (++n == 2) exit}' "$s" | tr '\n' '|')" = "- the handoff item one|- the handoff item two|" ] || miss="$miss open-item-file"
      { grep -qx '    with a second paragraph' "$s" && ! grep -q '^    I lorem' "$s" && grep -qx -- '- user_request_cite: d24ed24ee6bbc0d3edf01e5ab78c8d5df82b9212e05ea50fbb847f561bce6aad' "$s"; } || miss="$miss block-rewrite"
      { [ "$(grep -c '^## ' "$s")" = 7 ] && grep -qx -- '- current_step_file: lorem-lorem-lorem.md' "$s" \
          && [ "$(awk '/^## In-Flight Teammates/{f=1;next} f && /^agent \|/{exit} f && !/^[(]none in flight/' "$s" | cksum)" = "$prose" ]; } || miss="$miss shape-kept"
      [ -z "$miss" ] && return 0
      CELL_MSG="not expressed:$miss"; return 1 ;;
    SECADD)
      # E1. On the reference consumer's reset skeleton (no In-Flight section, a suffixed declared
      # extra heading): In-Flight Teammates is added with its table header, before Context Reminders;
      # a declared extra is added; the suffixed `Deploy Baseline (...)` heading is found by its
      # declared name and a second one refused; an undeclared near-miss name is refused. On seed(),
      # Sprint Context lands in canonical order, before Recent Activity.
      local w="$WORK/$t-secadd" miss="" r1 r2 r3 r4
      s="$(seed_copy "$w" "$GSKEL")"
      AI_DLC_SNAPSHOT_EXTRA_SECTIONS="$XSEC" drive "$pr" "$s" --section-add "In-Flight Teammates" --section-add "Operator Identity"; r1="$RC"
      cs="$(cksum < "$s")"
      AI_DLC_SNAPSHOT_EXTRA_SECTIONS="$XSEC" drive "$pr" "$s" --section-add "Deploy Baseline"; r2="$RC"
      AI_DLC_SNAPSHOT_EXTRA_SECTIONS="$XSEC" drive "$pr" "$s" --section-add "Deploy Baselines"; r3="$RC"
      [ "$r1" = 0 ] || miss="$miss add-rc=$r1"
      [ "$(grep -A1 '^## In-Flight Teammates$' "$s" | tail -1)" = "agent | role | deliverable | dispatched-at | status" ] || miss="$miss header"
      [ "$(grep '^## ' "$s" | tail -3 | tr '\n' '|')" = "## In-Flight Teammates|## Operator Identity|## Context Reminders|" ] || miss="$miss order"
      # D3: a declared extra whose name begins with one of the seven is refused.
      AI_DLC_SNAPSHOT_EXTRA_SECTIONS="Open Items Archive" drive "$pr" "$s" --section-add "Open Items Archive"; r4="$RC"
      { [ "$r2" = 2 ] && [ "$r3" = 2 ] && [ "$r4" = 2 ] && [ "$(cksum < "$s")" = "$cs" ]; } || miss="$miss refusals=$r2,$r3,$r4"
      s="$(seed "$w/b" 0)"; drive "$pr" "$s" --section-add "Sprint Context"
      { [ "$RC" = 0 ] && [ "$(grep '^## ' "$s" | head -3 | tr '\n' '|')" = "## Pipeline Position|## Sprint Context|## Recent Activity|" ]; } || miss="$miss canonical-order rc=$RC"
      [ -z "$miss" ] && return 0
      CELL_MSG="$miss"; return 1 ;;
    SECMOVE)
      # E2. An invented section moves to history whole, history first; one of the seven is refused.
      local w="$WORK/$t-secmove" miss=""
      s="$(seed "$w" 0)"
      printf '\n## Teammate Ledger (detail)\n- lorem ledger line one\n- lorem ledger line two\n' >> "$s"
      drive "$pr" "$s" --section-move-to-history "Teammate Ledger"
      { [ "$RC" = 0 ] && ! grep -q 'Teammate Ledger\|lorem ledger' "$s"; } || miss="$miss moved rc=$RC"
      [ "$(grep -cE '^## Teammate Ledger \(detail\)$|^- lorem ledger line' "${s%/*}/pipeline-snapshot-history.md" 2>/dev/null)" = 3 ] || miss="$miss history"
      cs="$(cksum < "$s")"; drive "$pr" "$s" --section-move-to-history "Open Items"
      { [ "$RC" = 2 ] && [ "$(cksum < "$s")" = "$cs" ]; } || miss="$miss canonical-refused rc=$RC"
      [ -z "$miss" ] && return 0
      CELL_MSG="$miss"; return 1 ;;
    SWALLOW)
      # E3. The measured shape (graph, a row line ending `| in-flight## Context Reminders`, so the
      # Context Reminders keys read as In-Flight rows' neighbours): --row-replace rewrites the row
      # without the tail and --section-add puts the heading back directly under it.
      local w="$WORK/$t-swallow" miss="" row="aca6a74f6452df2c7 | pm | lorem/s321/lorem.md (lorem p2 lorem) | 2026-11-04T06:29:01Z | in-flight"
      s="$(seed_copy "$w" "$SWALLOW")"
      AI_DLC_SNAPSHOT_NOW_EPOCH=1793923200 drive "$pr" "$s" --row-replace aca6a74f6452df2c7 "$row" --section-add "Context Reminders"
      [ "$RC" = 0 ] || miss="$miss rc=$RC"
      grep -qx -- "$row" "$s" || miss="$miss row"
      [ "$(sect "$s" "Context Reminders" | grep -c '^- ')" = 7 ] || miss="$miss reminders-body"
      [ "$(sect "$s" "In-Flight Teammates" | grep -c '|')" = 2 ] || miss="$miss inflight-body"
      [ -z "$miss" ] && return 0
      CELL_MSG="$miss $OUT"; return 1 ;;
    ROWREPLACE)
      # E4. --row-replace rewrites the one row (cell count and status membership hold); an identical
      # --row-add is a no-op exit 0; the same id with different cells is exit 2 naming --row-replace.
      local w="$WORK/$t-rowrep" miss="" r1 r2 r3
      s="$(seed "$w" 0)"
      drive "$pr" "$s" --row-replace a1111111111111111 "a1111111111111111 | dev | /w/a2.md | 2026-10-25T19:00:00Z | in-flight"
      { [ "$RC" = 0 ] && grep -qx 'a1111111111111111 | dev | /w/a2.md | 2026-10-25T19:00:00Z | in-flight' "$s" && [ "$(grep -c '^a1111111111111111 ' "$s")" = 1 ]; } || miss="$miss replace rc=$RC"
      cs="$(cksum < "$s")"
      drive "$pr" "$s" --row-replace a1111111111111111 "a1111111111111111 | dev | in-flight"; r1="$RC"
      drive "$pr" "$s" --row-replace a1111111111111111 "a1111111111111111 | dev | /w/a2.md | 2026-10-25T19:00:00Z | delivered"; r2="$RC"
      drive "$pr" "$s" --row-add "a1111111111111111 | dev | /w/a2.md | 2026-10-25T19:00:00Z | in-flight"; r3="$RC"
      { [ "$r1" = 2 ] && [ "$r2" = 2 ] && [ "$r3" = 0 ] && [ "$(cksum < "$s")" = "$cs" ]; } || miss="$miss shape=$r1,$r2,same-readd=$r3"
      drive "$pr" "$s" --row-add "a1111111111111111 | qa | /w/a3.md | 2026-10-25T19:00:00Z | in-flight"
      { [ "$RC" = 2 ] && grep -qF -- '--row-replace' <<<"$OUT" && [ "$(cksum < "$s")" = "$cs" ]; } || miss="$miss differing-readd rc=$RC"
      [ -z "$miss" ] && return 0
      CELL_MSG="$miss"; return 1 ;;
    WRAPPED)
      # E5. A bullet with continuation lines is acted on whole by --close-item, --line-replace,
      # --line-delete and --move-to-history; nothing is orphaned.
      local w="$WORK/$t-wrapped" miss=""
      s="$(seed "$w" 0)"
      awk '{ print }
        /^## Recent Activity$/ { print "- 2026-10-25T20:30Z lorem wrapped one"; print "    lorem cont one"
          print "- 2026-10-25T20:20Z lorem wrapped two"; print "    lorem cont two"
          print "- 2026-10-25T20:10Z lorem wrapped three"; print "    lorem cont three" }
        /^## Open Items$/ { print "- lorem item wrapped since 2026-10-25T19:10Z"; print "    lorem cont four" }' "$s" > "$w/x" && mv "$w/x" "$s"
      drive "$pr" "$s" --close-item "lorem item wrapped" \
        --line-replace "Recent Activity" "lorem wrapped one" "- 2026-10-25T20:30Z lorem one line" \
        --line-delete "Recent Activity" "lorem wrapped two" \
        --move-to-history "Recent Activity" "lorem wrapped three"
      [ "$RC" = 0 ] || miss="$miss rc=$RC"
      ! grep -q 'lorem cont\|lorem wrapped\|lorem item' "$s" || miss="$miss orphaned"
      grep -qx -- '- 2026-10-25T20:30Z lorem one line' "$s" || miss="$miss replaced"
      grep -qx '    lorem cont three' "${s%/*}/pipeline-snapshot-history.md" 2>/dev/null || miss="$miss history"
      [ -z "$miss" ] && return 0
      CELL_MSG="$miss $OUT"; return 1 ;;
    KEYLINE)
      # E6. In Pipeline Position and Sprint Context a `- key:` line (bold or not) is refused by
      # --line-add and --line-replace; the same line into Locked Decisions is written.
      local w="$WORK/$t-keyline" miss="" r1 r2
      s="$(seed_copy "$w" "$GSKEL")"; cs="$(cksum < "$s")"
      AI_DLC_SNAPSHOT_EXTRA_SECTIONS="$XSEC" drive "$pr" "$s" --line-add "Sprint Context" "- is_ui_epic: true"; r1="$RC"
      AI_DLC_SNAPSHOT_EXTRA_SECTIONS="$XSEC" drive "$pr" "$s" --line-replace "Pipeline Position" "<!-- FILL" "- **pipeline_variant:** full"; r2="$RC"
      { [ "$r1" = 2 ] && [ "$r2" = 2 ] && [ "$(cksum < "$s")" = "$cs" ]; } || miss="$miss refused=$r1,$r2"
      AI_DLC_SNAPSHOT_EXTRA_SECTIONS="$XSEC" drive "$pr" "$s" --line-add "Locked Decisions" "- is_ui_epic: true" --bottom
      { [ "$RC" = 0 ] && [ "$(sect "$s" "Locked Decisions" | grep -c '^- is_ui_epic: true$')" = 1 ]; } || miss="$miss twin rc=$RC"
      [ -z "$miss" ] && return 0
      CELL_MSG="$miss"; return 1 ;;
    SETCREATE)
      # E6. --set <key> <value> <section> creates in Pipeline Position / Sprint Context exactly the
      # keys of the create allowlist: a render_skeleton key (pipeline_variant, absent from the reset
      # skeleton) and an extra key (is_ui_epic) are created; a key in neither is refused.
      local w="$WORK/$t-setcreate" miss=""
      s="$(seed_copy "$w" "$GSKEL")"
      AI_DLC_SNAPSHOT_EXTRA_SECTIONS="$XSEC" drive "$pr" "$s" --set pipeline_variant full "Pipeline Position" --set is_ui_epic TBD "Sprint Context"
      { [ "$RC" = 0 ] && [ "$(sect "$s" "Pipeline Position" | grep -c '^- pipeline_variant: full$')" = 1 ] \
          && [ "$(sect "$s" "Sprint Context" | grep -c '^- is_ui_epic: TBD$')" = 1 ]; } || miss="$miss created rc=$RC $OUT"
      cs="$(cksum < "$s")"
      AI_DLC_SNAPSHOT_EXTRA_SECTIONS="$XSEC" drive "$pr" "$s" --set lorem_key x "Sprint Context"
      { [ "$RC" = 2 ] && [ "$(cksum < "$s")" = "$cs" ]; } || miss="$miss unlisted rc=$RC"
      # N1: the skeleton key for the branch is `branch`; a second key for it is not admitted.
      AI_DLC_SNAPSHOT_EXTRA_SECTIONS="$XSEC" drive "$pr" "$s" --set current_branch x "Pipeline Position"
      { [ "$RC" = 2 ] && [ "$(cksum < "$s")" = "$cs" ]; } || miss="$miss current_branch rc=$RC"
      [ -z "$miss" ] && return 0
      CELL_MSG="$miss"; return 1 ;;
    ROWIDDUP)
      # B1. --row-replace refuses a new agent cell carrying an id ANOTHER row carries (two rows the
      # dedupe and the lookups would take for one); the hit row's own id, kept, is written.
      local w="$WORK/$t-rowiddup" miss=""
      s="$(seed "$w" 0)"
      printf '%s\n' 'agentabc123 | dev | /w/a.md | 2026-10-25T19:00:00Z | in-flight' 'agentxyz999 | qa | /w/b.md | 2026-10-25T19:00:00Z | in-flight' >> "$s"
      cs="$(cksum < "$s")"
      drive "$pr" "$s" --row-replace agentabc123 'agentxyz999 | dev | /w/a.md | 2026-10-25T19:00:00Z | in-flight'
      { [ "$RC" = 2 ] && grep -qF 'agentxyz999' <<<"$OUT" && [ "$(cksum < "$s")" = "$cs" ]; } || miss="$miss shared-id rc=$RC"
      drive "$pr" "$s" --row-replace agentabc123 'agentabc123 toolu_01q | dev | /w/a9.md | 2026-10-25T19:00:00Z | in-flight'
      { [ "$RC" = 0 ] && grep -qx 'agentabc123 toolu_01q | dev | /w/a9.md | 2026-10-25T19:00:00Z | in-flight' "$s"; } || miss="$miss own-id rc=$RC $OUT"
      [ -z "$miss" ] && return 0
      CELL_MSG="$miss"; return 1 ;;
    HDRREMEDY)
      # D4. The section exists without its header: a row op's refusal names the op that writes the
      # header, and that op, run exactly as named, writes it.
      local w="$WORK/$t-hdrremedy" miss="" rem
      mkdir -p "$w/.claude" "$w/_bmad-output"; s="$w/_bmad-output/pipeline-snapshot.md"
      printf '# Pipeline Snapshot\n\n## Pipeline Position\n- current_step_file: a.md\n\n## In-Flight Teammates\n' > "$s"
      drive "$pr" "$s" --row-status a1111111111111111 in-flight
      rem="--line-add 'In-Flight Teammates' 'agent | role | deliverable | dispatched-at | status'"
      { [ "$RC" = 2 ] && grep -qF -- "$rem" <<<"$OUT"; } || miss="$miss remedy rc=$RC [$OUT]"
      drive "$pr" "$s" --line-add 'In-Flight Teammates' 'agent | role | deliverable | dispatched-at | status'
      { [ "$RC" = 0 ] && [ "$(sect "$s" "In-Flight Teammates" | grep -cx 'agent | role | deliverable | dispatched-at | status')" = 1 ]; } || miss="$miss applied rc=$RC"
      [ -z "$miss" ] && return 0
      CELL_MSG="$miss"; return 1 ;;
    SECDUP)
      # D5. A duplicated canonical heading (Check 14 SCHEMA) is repairable: its LAST occurrence moves
      # to history whole, the first stays, the section ops work again, and the stamp validator and the
      # shipped continue hook read the result clean.
      local w="$WORK/$t-secdup" miss="" cont vout c8
      mkdir -p "$w/.claude" "$w/_bmad-output" "$w/home"; s="$w/_bmad-output/pipeline-snapshot.md"
      drive "$pr" "$s" --init route.md 5 --open-item 'lorem first item'
      printf '\n## Open Items\n- lorem dup item\n' >> "$s"
      drive "$pr" "$s" --open-item 'lorem refused'; [ "$RC" = 2 ] || miss="$miss pre-dup-op rc=$RC"
      drive "$pr" "$s" --section-move-to-history 'Open Items'
      { [ "$RC" = 0 ] && [ "$(grep -c '^## Open Items' "$s")" = 1 ] && grep -qx -- '- lorem first item' "$s" && ! grep -q 'lorem dup item' "$s"; } || miss="$miss moved rc=$RC $OUT"
      grep -qx -- '- lorem dup item' "$w/_bmad-output/pipeline-snapshot-history.md" 2>/dev/null || miss="$miss history"
      drive "$pr" "$s" --open-item 'lorem after'; [ "$RC" = 0 ] || miss="$miss post-op rc=$RC"
      # The discriminators are the refused op before the move and the working op after it. The
      # validator does not detect a duplicate heading, so its clean run is a regression check only.
      vout="$(AI_DLC_PROJECT_ROOT="$w" bash "$VAL" --root "$w" --only pipeline-snapshot.md 2>&1)"; local vrc=$?
      { [ "$vrc" = 0 ] && ! grep -q 'SCHEMA' <<<"$vout"; } || miss="$miss validator rc=$vrc"
      cont="$(printf '{"session_id":"t","transcript_path":""}' | HOME="$w/home" CLAUDE_PROJECT_DIR="$w" bash "$CONT_HOOK" 2>/dev/null | grep -o 'Current step: [^ ]*')"
      printf '{"source":"compact","session_id":"t","transcript_path":""}' | HOME="$w/home" CLAUDE_PROJECT_DIR="$w" bash "$RECOVER_HOOK" > /dev/null 2>&1
      c8="$(cd "$w" && HOME="$w/home" bash "$VMR" 900 2>&1 | grep 'CHECK 8:')"
      { grep -qF 'Current step: route.md.' <<<"$cont" && grep -qx 'step_file=route.md' "$w/_bmad-output/.recover-fired" 2>/dev/null && grep -qF 'at route.md' <<<"$c8"; } || miss="$miss readers=[$cont][$c8]"
      [ -z "$miss" ] && return 0
      CELL_MSG="$miss"; return 1 ;;
    POSLINE)
      # N6. With no dash position bullet in Pipeline Position, every shipped reader falls back to a
      # looser grammar: the continue and recover hooks to the first line anywhere naming the key,
      # Check 8 to the first such line in the section, and all three read a `* key:` or a bare
      # `key:` line. So outside --set/--init a `* current_step_file:` or bare `current_step_file:`
      # line is refused in any section, and a `* key:` line in Pipeline Position. The SHIPPED readers
      # then run on what is on disk: none may read wrong.md. Positive half: the --set create the
      # refusals name is written and all three read route.md.
      local w="$WORK/$t-posline" miss="" rr="" cont c8 rec
      mkdir -p "$w/.claude" "$w/_bmad-output" "$w/home"; s="$w/_bmad-output/pipeline-snapshot.md"
      printf '# Pipeline Snapshot\n\n## Pipeline Position\n- last_gate_passed: none\n\n## Sprint Context\n- sprint_id: 7\n\n## Recent Activity\n- 2026-10-25T20:00Z older entry\n' > "$s"
      cs="$(cksum < "$s")"
      drive "$pr" "$s" --line-add 'Pipeline Position' '* current_step_file: wrong.md'; rr="$rr $RC"
      drive "$pr" "$s" --line-add 'Pipeline Position' 'current_step_file: wrong.md'; rr="$rr $RC"
      drive "$pr" "$s" --line-add 'Recent Activity' 'current_step_file: wrong.md' --bottom; rr="$rr $RC"
      drive "$pr" "$s" --line-add 'Pipeline Position' '* pipeline_variant: full'; rr="$rr $RC"
      drive "$pr" "$s" --line-add 'Recent Activity' '- 2026-10-25T21:31Z the current step is x: note' --bottom; rr="$rr $RC"
      { [ "$rr" = " 2 2 2 2 2" ] && [ "$(cksum < "$s")" = "$cs" ]; } || miss="$miss refused=[$rr]"
      posread() {
        cont="$(printf '{"session_id":"t","transcript_path":""}' | HOME="$w/home" CLAUDE_PROJECT_DIR="$w" bash "$CONT_HOOK" 2>/dev/null | grep -o 'Current step: [^ ]*')"
        rm -f "$w/_bmad-output/.recover-fired"
        printf '{"source":"compact","session_id":"t","transcript_path":""}' | HOME="$w/home" CLAUDE_PROJECT_DIR="$w" bash "$RECOVER_HOOK" > /dev/null 2>&1
        rec="$(grep '^step_file=' "$w/_bmad-output/.recover-fired" 2>/dev/null)"
        c8="$(cd "$w" && HOME="$w/home" bash "$VMR" 900 2>&1 | grep 'CHECK 8:')"
      }
      posread
      ! grep -qE 'wrong\.md|is x' <<<"$cont $rec $c8" || miss="$miss readers-read-wrong=[$cont][$rec][$c8]"
      grep -qF 'CHECK 8: SKIP' <<<"$c8" || miss="$miss c8-control=[$c8]"
      drive "$pr" "$s" --line-add 'Recent Activity' '- 2026-10-25T21:30Z lorem note: done' --bottom; [ "$RC" = 0 ] || miss="$miss nearmiss rc=$RC"
      drive "$pr" "$s" --set current_step_file route.md 'Pipeline Position'; [ "$RC" = 0 ] || miss="$miss set rc=$RC $OUT"
      # With the position bullet written, the readers count it and the same activity line is fine.
      drive "$pr" "$s" --line-add 'Recent Activity' '- 2026-10-25T21:32Z the current step is x: note' --bottom; [ "$RC" = 0 ] || miss="$miss counted-state rc=$RC"
      # In the counted state the fallback guard is off, so the position-bullet shape alone must
      # still refuse a `*` bullet outside Pipeline Position (m-posdash's own subject).
      cs="$(cksum < "$s")"
      drive "$pr" "$s" --line-add 'Recent Activity' '* current_step_file: wrong.md' --bottom
      { [ "$RC" = 2 ] && [ "$(cksum < "$s")" = "$cs" ]; } || miss="$miss counted-star rc=$RC"
      posread
      { grep -qF 'Current step: route.md.' <<<"$cont" && [ "$rec" = step_file=route.md ] && grep -qF 'at route.md' <<<"$c8"; } || miss="$miss readers-after-set=[$cont][$rec][$c8]"
      [ -z "$miss" ] && return 0
      CELL_MSG="$miss"; return 1 ;;
    IFLINEREFUSE)
      # BL-953. --line-replace into In-Flight Teammates applies the status vocabulary to a table row it
      # writes: free text and `done` are exit 2 with the cell VALUE named in quotes, file unchanged.
      local w="$WORK/$t-iflr" miss="" st row
      s="$(seed "$w" 0)"; cs="$(cksum < "$s")"
      for st in "in-flight (join: x)" done; do
        row="a1111111111111111 | dev | /w/a.md | 2026-10-25T19:00:00Z | $st"
        AI_DLC_SNAPSHOT_NOW_EPOCH="$NOW" drive "$pr" "$s" --line-replace "In-Flight Teammates" a1111111111111111 "$row"
        [ "$RC" = 2 ] || miss="$miss rc=$RC($st)"
        grep -qF "the status cell '$st' is not in-flight" <<<"$OUT" || miss="$miss msg($st)=$OUT"
        [ "$(cksum < "$s")" = "$cs" ] || miss="$miss changed($st)"
      done
      # A `dispatched-at` decoy cell is not the header, and a row of bare `-` cells is not a table rule.
      for st in "WIP" "-"; do
        if [ "$st" = WIP ]; then row="a1111111111111111 | dev | dispatched-at | 2026-10-25T19:00:00Z | WIP"
        else row="- | - | - | - | -"; fi
        AI_DLC_SNAPSHOT_NOW_EPOCH="$NOW" drive "$pr" "$s" --line-replace "In-Flight Teammates" a1111111111111111 "$row"
        [ "$RC" = 2 ] || miss="$miss rc=$RC($st)"
        grep -qF "the status cell '$st' is not in-flight" <<<"$OUT" || miss="$miss msg($st)=$OUT"
        [ "$(cksum < "$s")" = "$cs" ] || miss="$miss changed($st)"
      done
      [ -z "$miss" ] && return 0
      CELL_MSG="$miss"; return 1 ;;
    IFLINEWRITE)
      # BL-953 twin. A member status written by --line-replace into In-Flight Teammates is rc 0 and
      # written (the guard is not refuse-all); a Recent Activity --line-replace is written; the
      # header text and the --- rule are no row, so they are not judged (here: the rule is rewritten).
      local w="$WORK/$t-iflw" miss="" row="a1111111111111111 | dev | /w/a.md | 2026-10-25T19:00:00Z | delivered-reachable"
      s="$(seed "$w" 0)"
      AI_DLC_SNAPSHOT_NOW_EPOCH="$NOW" drive "$pr" "$s" --line-replace "In-Flight Teammates" a1111111111111111 "$row"
      { [ "$RC" = 0 ] && grep -qxF -- "$row" "$s"; } || miss="$miss member rc=$RC $OUT"
      AI_DLC_SNAPSHOT_NOW_EPOCH="$NOW" drive "$pr" "$s" --line-replace "Recent Activity" "older entry" "- 2026-10-25T20:00Z rewritten by line-replace"
      { [ "$RC" = 0 ] && grep -qxF -- "- 2026-10-25T20:00Z rewritten by line-replace" "$s"; } || miss="$miss activity rc=$RC $OUT"
      AI_DLC_SNAPSHOT_NOW_EPOCH="$NOW" drive "$pr" "$s" --line-replace "In-Flight Teammates" "--- | ---" "---- | ---- | ---- | ---- | ----"
      { [ "$RC" = 0 ] && grep -qxF -- "---- | ---- | ---- | ---- | ----" "$s"; } || miss="$miss rule rc=$RC $OUT"
      # A rewrite of the header LINE itself, which names dispatched-at, is written.
      AI_DLC_SNAPSHOT_NOW_EPOCH="$NOW" drive "$pr" "$s" --line-replace "In-Flight Teammates" "agent | role" "agent  |  role | deliverable | dispatched-at | status"
      { [ "$RC" = 0 ] && grep -qxF -- "agent  |  role | deliverable | dispatched-at | status" "$s"; } || miss="$miss header rc=$RC $OUT"
      [ -z "$miss" ] && return 0
      CELL_MSG="$miss"; return 1 ;;
    IFADDREFUSE)
      # BL-963. --line-add into In-Flight Teammates applies the status vocabulary to the row it adds:
      # free text and `done` are exit 2 with the cell VALUE named in quotes, file unchanged.
      local w="$WORK/$t-ifar" miss="" st
      s="$(seed "$w" 0)"; cs="$(cksum < "$s")"
      for st in "18/19 delivered (still out: x)" done; do
        drive "$pr" "$s" --line-add "In-Flight Teammates" "a2222222222222222 | qa | /w/b.md | 2026-10-25T21:00:00Z | $st" --bottom
        [ "$RC" = 2 ] || miss="$miss rc=$RC($st)"
        grep -qF "the status cell '$st' is not in-flight" <<<"$OUT" || miss="$miss msg($st)=$OUT"
        [ "$(cksum < "$s")" = "$cs" ] || miss="$miss changed($st)"
      done
      [ -z "$miss" ] && return 0
      CELL_MSG="$miss"; return 1 ;;
    IFADDWRITE)
      # BL-963 twin. A member-status row added by --line-add into In-Flight Teammates is rc 0 and
      # written (the guard is not refuse-all), and so is a --- rule.
      local w="$WORK/$t-ifaw" miss="" row="a2222222222222222 | qa | /w/b.md | 2026-10-25T21:00:00Z | in-flight"
      s="$(seed "$w" 0)"
      drive "$pr" "$s" --line-add "In-Flight Teammates" "$row" --bottom
      { [ "$RC" = 0 ] && grep -qxF -- "$row" "$s"; } || miss="$miss member rc=$RC $OUT"
      drive "$pr" "$s" --line-add "In-Flight Teammates" "---- | ---- | ---- | ---- | ----" --bottom
      { [ "$RC" = 0 ] && grep -qxF -- "---- | ---- | ---- | ---- | ----" "$s"; } || miss="$miss rule rc=$RC $OUT"
      [ -z "$miss" ] && return 0
      CELL_MSG="$miss"; return 1 ;;
    IFADDDUPHDR)
      # BL-963. A second header line-added beside the one present is a row whose status cell reads
      # `status`: exit 2, file unchanged, one header. (A header into a header-less section is written:
      # HDRREMEDY's applied half.)
      local w="$WORK/$t-ifdh" miss=""
      s="$(seed "$w" 0)"; cs="$(cksum < "$s")"
      drive "$pr" "$s" --line-add "In-Flight Teammates" "agent | role | deliverable | dispatched-at | status" --bottom
      { [ "$RC" = 2 ] && grep -qF "the status cell 'status' is not in-flight" <<<"$OUT" && [ "$(cksum < "$s")" = "$cs" ]; } || miss="$miss rc=$RC $OUT"
      [ -z "$miss" ] && return 0
      CELL_MSG="$miss"; return 1 ;;
    *) echo "MATRIX BROKEN unknown cell $c" >&2; exit 2 ;;
  esac
}
CELLS="VALID FUTURE PIPED FUTUREROW MALFORMED NEARMISS OLDLINE AMBIG-zero AMBIG-two AMBIG-cells NOVAL LOCKWAIT LOCKSTALE LOCKTIMEOUT BLOCKSET BLOCKCONTENT STATUSVOC READERS SETBOLD LIVE SECADD SECMOVE SWALLOW ROWREPLACE WRAPPED KEYLINE SETCREATE ROWIDDUP HDRREMEDY SECDUP POSLINE IFLINEREFUSE IFLINEWRITE IFADDREFUSE IFADDWRITE IFADDDUPHDR"

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
if cell LOCKWAIT "$PROG" ship; then ok "LOCKWAIT: a writer behind a held lock neither writes nor exits; released, it writes on top of the holder's row"; else bad "LOCKWAIT: $CELL_MSG"; fi
if cell LOCKSTALE "$PROG" ship; then ok "LOCKSTALE: a lock whose holder is dead is broken and the write proceeds"; else bad "LOCKSTALE: $CELL_MSG"; fi
if cell LOCKTIMEOUT "$PROG" ship; then ok "LOCKTIMEOUT: a lock held for the whole run is exit 3, LOCK TIMEOUT named, file unchanged"; else bad "LOCKTIMEOUT: $CELL_MSG"; fi
if cell BLOCKSET "$PROG" ship; then ok "BLOCKSET: --set on the live multi-line user_request_verbatim is exit 2, file unchanged"; else bad "BLOCKSET: $CELL_MSG"; fi
if cell BLOCKCONTENT "$PROG" ship; then ok "BLOCKCONTENT: --set-block content carrying \`- current step: x.md\` is exit 2, file unchanged"; else bad "BLOCKCONTENT: $CELL_MSG"; fi
if cell STATUSVOC "$PROG" ship; then ok "STATUSVOC: --row-set status 'in-flight (join: x)' and --row-status delivered are exit 2, file unchanged"; else bad "STATUSVOC: $CELL_MSG"; fi
if cell READERS "$PROG" ship; then ok "READERS: an op-only snapshot (--init, --set, --set-block) resolves route.md in the continue and recover hooks and sprint 42 in the guard's sed"; else bad "READERS: $CELL_MSG"; fi
if cell SETBOLD "$PROG" ship; then ok "SETBOLD: --set on a bold current_step_file rewrites it canonical in place, and the continue hook reads it"; else bad "SETBOLD: $CELL_MSG"; fi
if cell LIVE "$PROG" ship; then ok "LIVE: every NONE class of the walk is expressed as ops on the scrubbed live snapshot, its shape kept"; else bad "LIVE: $CELL_MSG"; fi
if cell SECADD "$PROG" ship; then ok "SECADD: --section-add writes In-Flight with its header and a declared extra before Context Reminders, Sprint Context in canonical order, and refuses the suffixed extra twice and an undeclared name"; else bad "SECADD: $CELL_MSG"; fi
if cell SECMOVE "$PROG" ship; then ok "SECMOVE: --section-move-to-history moves an invented section whole to history and refuses one of the seven"; else bad "SECMOVE: $CELL_MSG"; fi
if cell SWALLOW "$PROG" ship; then ok "SWALLOW: --row-replace plus --section-add 'Context Reminders' repairs a row that swallowed the heading"; else bad "SWALLOW: $CELL_MSG"; fi
if cell ROWREPLACE "$PROG" ship; then ok "ROWREPLACE: --row-replace rewrites one row; a bad shape or status is refused; an identical re-add is a no-op and a differing one names --row-replace"; else bad "ROWREPLACE: $CELL_MSG"; fi
if cell WRAPPED "$PROG" ship; then ok "WRAPPED: --close-item, --line-replace, --line-delete and --move-to-history take a wrapped bullet whole"; else bad "WRAPPED: $CELL_MSG"; fi
if cell KEYLINE "$PROG" ship; then ok "KEYLINE: a - key: line is refused by --line-add/--line-replace in Sprint Context/Pipeline Position and written in Locked Decisions"; else bad "KEYLINE: $CELL_MSG"; fi
if cell SETCREATE "$PROG" ship; then ok "SETCREATE: --set creates a skeleton key and an allowlisted extra key in the two sections and refuses an unlisted key"; else bad "SETCREATE: $CELL_MSG"; fi
if cell ROWIDDUP "$PROG" ship; then ok "ROWIDDUP: --row-replace refuses an agent cell carrying another row's id, and keeps the hit row's own id"; else bad "ROWIDDUP: $CELL_MSG"; fi
if cell HDRREMEDY "$PROG" ship; then ok "HDRREMEDY: a row op on a header-less In-Flight section names the --line-add that writes the header, and that op writes it"; else bad "HDRREMEDY: $CELL_MSG"; fi
if cell SECDUP "$PROG" ship; then ok "SECDUP: a duplicated Open Items heading loses its last copy to history; the ops, the validator and the continue hook read the result clean"; else bad "SECDUP: $CELL_MSG"; fi
if cell POSLINE "$PROG" ship; then ok "POSLINE: \`* current_step_file:\` and bare \`current_step_file:\` lines are refused, and the shipped continue, recover and Check 8 readers read no wrong position"; else bad "POSLINE: $CELL_MSG"; fi
if cell IFLINEREFUSE "$PROG" ship; then ok "IFLINEREFUSE: --line-replace into In-Flight Teammates refuses a free-text and a done status cell, names the value, file unchanged"; else bad "IFLINEREFUSE: $CELL_MSG"; fi
if cell IFLINEWRITE "$PROG" ship; then ok "IFLINEWRITE: --line-replace writes a member status row, a Recent Activity line and a rewritten --- rule"; else bad "IFLINEWRITE: $CELL_MSG"; fi
if cell IFADDREFUSE "$PROG" ship; then ok "IFADDREFUSE: --line-add into In-Flight Teammates refuses a free-text and a done status cell, names the value, file unchanged"; else bad "IFADDREFUSE: $CELL_MSG"; fi
if cell IFADDWRITE "$PROG" ship; then ok "IFADDWRITE: --line-add into In-Flight Teammates writes a member status row and a --- rule"; else bad "IFADDWRITE: $CELL_MSG"; fi
if cell IFADDDUPHDR "$PROG" ship; then ok "IFADDDUPHDR: --line-add of a second header beside the present one is refused, file unchanged"; else bad "IFADDDUPHDR: $CELL_MSG"; fi

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

# mkmutn <name> <old> <new> [<old> <new> ...]: as mkmut, for a mutation that must change SEVERAL
# literals (a layered property, every layer reverted) or whose text carries `|`. An <old> beginning
# `=` matches a WHOLE line. Each replacement must change the copy, or the mutant is refused.
mkmutn() {
  local d="$WORK/mut-$1" cur nxt; shift
  mkdir -p "$d"; cp "$VAL" "$d/validate-artifact-budget.sh" || return 1
  cur="$d/cur"; nxt="$d/nxt"; cp "$PROG" "$cur" || return 1
  while [ $# -ge 2 ]; do
    MM_OLD="$1" MM_NEW="$2" awk 'BEGIN { o = ENVIRON["MM_OLD"]; n = ENVIRON["MM_NEW"]; whole = (substr(o, 1, 1) == "="); if (whole) o = substr(o, 2) }
      { if (!done && whole && $0 == o) { $0 = n; done = 1 }
        else if (!done && !whole && index($0, o)) { i = index($0, o); $0 = substr($0, 1, i - 1) n substr($0, i + length(o)); done = 1 }
        print }' "$cur" > "$nxt" || return 1
    cmp -s "$cur" "$nxt" && { echo "DID NOT APPLY" >&2; return 1; }
    mv "$nxt" "$cur"; shift 2
  done
  mv "$cur" "$d/snapshot-update.sh" && printf '%s' "$d/snapshot-update.sh"
}

# score <name> <mutant path>: the deciding cell and the twin, read from the header row.
score() {
  local name="$1" mp="$2" dec tw d t dmsg
  dec="$(mx_row "$name" decides)"; tw="$(mx_row "$name" twins)"
  if [ -z "$dec" ] || [ -z "$tw" ]; then bad "$name: no single MUTANT-MATRIX row names its deciding cell and twin"; return; fi
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
}

for m in \
  'm-nocheck|VOUT="$(AI_DLC_PROJECT_ROOT=|VOUT="$(true || AI_DLC_PROJECT_ROOT=' \
  'm-nopay|else if ($0 != "") print }|else if (0) print }' \
  'm-early|VOUT="$(AI_DLC_PROJECT_ROOT=|cp "$CAND" "$SNAP"; VOUT="$(AI_DLC_PROJECT_ROOT=' \
  'm-rc1|if [ "$VRC" -eq 1 ]; then|VRC=0; if false; then'; do
  name="${m%%|*}"; rest="${m#*|}"; old="${rest%%|*}"; new="${rest#*|}"
  mp="$(mkmut "$name" "$old" "$new")" || { bad "$name: mutation did not apply"; continue; }
  score "$name" "$mp"
done

# The BL-912a ops mutants. Each is built by mkmutn (several literals, or text carrying `|`).
# m-nolock: no lock at all -- the mkdir loop never runs, so a held lock is walked past.
mp="$(mkmutn m-nolock 'while ! mkdir "$LOCK" 2>/dev/null; do' 'while false; do')" && score m-nolock "$mp" || bad "m-nolock: mutation did not apply"
# m-blockline: a block scalar read as one line -- the key's continuation lines are not its block.
mp="$(mkmutn m-blockline 'function isblk(i) { return (KV ~ /^[|>][-+]?$/) || blockend(i) > i }' 'function isblk(i) { return 0 }')" \
  && score m-blockline "$mp" || bad "m-blockline: mutation did not apply"
# m-blockcontent: --set-block without the content check on reader-shaped lines.
mp="$(mkmutn m-blockcontent 'if (hasbullet(ln) || hassp(ln)) die(7' 'if (0) die(7')" && score m-blockcontent "$mp" || bad "m-blockcontent: mutation did not apply"
# m-nomember: the status membership test dropped at BOTH layers -- the argument-time status_ok and
# the awk statuscell_ok the row ops apply.
mp="$(mkmutn m-nomember 'bad = 1 } END { exit bad }' 'bad = 0 } END { exit 0 }' \
  'function statuscell_ok(v) { return (v == "in-flight"' 'function statuscell_ok(v) { return 1 || (v == "in-flight"')" \
  && score m-nomember "$mp" || bad "m-nomember: mutation did not apply"
# m-initheading: --init writes `##Pipeline Position` -- the skeleton's heading loses its space.
mp="$(mkmutn m-initheading '=## Pipeline Position' '##Pipeline Position')" && score m-initheading "$mp" || bad "m-initheading: mutation did not apply"
# m-setappend: --set appends a canonical line after a bold-form match instead of rewriting it.
mp="$(mkmutn m-setappend 'L[HIT] = ind "- " A ": " B; guard(L[HIT], OKP, OKS)' 'insafter(HIT, ind "- " A ": " B); guard(ind "- " A ": " B, OKP, OKS)')" \
  && score m-setappend "$mp" || bad "m-setappend: mutation did not apply"

# The BL-912b ops mutants.
# m-secorder: --section-add ignores the canonical position and always appends at the end.
mp="$(mkmutn m-secorder 'if (j ? t > j : t == crx) at = i' 'if (0) at = i')" && score m-secorder "$mp" || bad "m-secorder: mutation did not apply"
# m-secmovecanon: --section-move-to-history moves one of the seven too.
mp="$(mkmutn m-secmovecanon 'if (m == 1 && iscore(headtext(HS))) die(7' 'if (0) die(7')" && score m-secmovecanon "$mp" || bad "m-secmovecanon: mutation did not apply"
# m-swallowtail: Context Reminders re-added at the file end, not under the last In-Flight row.
mp="$(mkmutn m-swallowtail 'if (lr) insafter(lr, "\n" blk)' 'if (0) insafter(lr, "\n" blk)')" && score m-swallowtail "$mp" || bad "m-swallowtail: mutation did not apply"
# m-rowdiff: a --row-add deduped onto a row with different cells is a silent no-op again.
mp="$(mkmutn m-rowdiff 'if (o != r) die(7' 'if (0) die(7')" && score m-rowdiff "$mp" || bad "m-rowdiff: mutation did not apply"
# m-wrapend: the four line ops act on the bullet line alone, orphaning its continuation lines.
mp="$(mkmutn m-wrapend 'function itemend(h) { return (L[h] ~ /^[ \t]*-[ \t]/) ? blockend(h) : h }' 'function itemend(h) { return h }')" \
  && score m-wrapend "$mp" || bad "m-wrapend: mutation did not apply"
# m-nokey: --line-add/--line-replace stop refusing a key line in the two sections.
mp="$(mkmutn m-nokey 'Sprint Context/) && keyshaped(s))' 'Sprint Context/) && 0)')" && score m-nokey "$mp" || bad "m-nokey: mutation did not apply"
# m-allowall: --set creates any key in the two sections.
mp="$(mkmutn m-allowall 'if (!(B in ALLOW)) die(7' 'if (0) die(7')" && score m-allowall "$mp" || bad "m-allowall: mutation did not apply"
# m-noskelallow: the allowlist loses its render_skeleton half.
mp="$(mkmutn m-noskelallow 'ALLOW[substr(SK[j], 3, RLENGTH - 3)] = 1' 'nop = 1')" && score m-noskelallow "$mp" || bad "m-noskelallow: mutation did not apply"

# The BL-912b fix-K mutants.
# m-rowiddup: --row-replace no longer checks the new agent cell's ids against the other rows.
mp="$(mkmutn m-rowiddup 'if (i != hit && L[i] ~ /\|/' 'if (0 && L[i] ~ /\|/')" && score m-rowiddup "$mp" || bad "m-rowiddup: mutation did not apply"
# m-secprefix: a declared extra that begins with one of the seven is added again.
mp="$(mkmutn m-secprefix 'if (!j && iscore(A)) die(7' 'if (0) die(7')" && score m-secprefix "$mp" || bad "m-secprefix: mutation did not apply"
# m-hdrremedy: the header-less refusal names --section-add again, which refuses a section that exists.
mp="$(mkmutn m-hdrremedy 'the section exists, so write the header with --line-add \047In-Flight Teammates\047 \047" IFHDR "\047")' '--section-add In-Flight Teammates writes it")')" \
  && score m-hdrremedy "$mp" || bad "m-hdrremedy: mutation did not apply"
# m-secdup: --section-move-to-history refuses one of the seven even when it is duplicated.
mp="$(mkmutn m-secdup 'if (m == 1 && iscore(headtext(HS))) die(7' 'if (iscore(headtext(HS))) die(7')" && score m-secdup "$mp" || bad "m-secdup: mutation did not apply"
# m-curbranch: current_branch is back in the create allowlist.
mp="$(mkmutn m-curbranch "SU_SETCREATE_EXTRA='is_ui_epic stories" "SU_SETCREATE_EXTRA='is_ui_epic current_branch stories")" && score m-curbranch "$mp" || bad "m-curbranch: mutation did not apply"
# m-posdash: the position-bullet refusal is a dash bullet only again.
mp="$(mkmutn m-posdash 'return (t ~ /^[^:]*(current_step_file' 'return (t ~ /^[ \t]*-[^:]*(current_step_file')" && score m-posdash "$mp" || bad "m-posdash: mutation did not apply"
# m-keydash: the key-line refusal is a dash bullet only again.
mp="$(mkmutn m-keydash 'if (!match(s, /^[ \t]*[-*+][ \t]+/)) return 0' 'if (!match(s, /^[ \t]*-[ \t]+/)) return 0')" \
  && score m-keydash "$mp" || bad "m-keydash: mutation did not apply"
# m-nofallback: the fallback-state refusal dropped, so a dated activity line naming the key is written.
mp="$(mkmutn m-nofallback 'if (FB && haskey(line) && !okpos) die(7' 'if (0) die(7')" && score m-nofallback "$mp" || bad "m-nofallback: mutation did not apply"
# m-blockfb: --set-block content naming the key is written in the fallback state.
mp="$(mkmutn m-blockfb 'if (FB && haskey(ln)) die(7' 'if (0) die(7')" && score m-blockfb "$mp" || bad "m-blockfb: mutation did not apply"

# The BL-953 mutants.
# m-noifguard: --line-replace into In-Flight Teammates no longer applies the status vocabulary.
mp="$(mkmutn m-noifguard 'if (SECT[HS] ~ /^In-Flight Teammates/) ifstatus_chk(C, h)' 'if (0) ifstatus_chk(C, h)')" && score m-noifguard "$mp" || bad "m-noifguard: mutation did not apply"
# m-ifhdrany: the header exemption widened back to any text with a dispatched-at cell (a decoy row is written).
mp="$(mkmutn m-ifhdrany 'if (tgt == hd) return' 'k = cells(txt, cc); for (j2 = 1; j2 <= k; j2++) if (trim(cc[j2]) == "dispatched-at") return')" \
  && score m-ifhdrany "$mp" || bad "m-ifhdrany: mutation did not apply"
# m-ifsepwide: the rule exemption widened back to any text of dashes, colons, spaces and bars (a `- | -` row is written).
mp="$(mkmutn m-ifsepwide 'if (cc[j2] !~ /^[ \t]*:?---+:?[ \t]*$/) rule = 0' 'if (cc[j2] !~ /^[ \t:-]*$/) rule = 0')" \
  && score m-ifsepwide "$mp" || bad "m-ifsepwide: mutation did not apply"
# m-ifrefuseall: the guard refuses every In-Flight table row, member or not (killed by the member-status arm).
mp="$(mkmutn m-ifrefuseall 'if (!statuscell_ok(v)) die(7, "refused: the status cell \047" v' 'if (1) die(7, "refused: the status cell \047" v')" \
  && score m-ifrefuseall "$mp" || bad "m-ifrefuseall: mutation did not apply"

# The BL-963 mutant. m-noifadd: --line-add into In-Flight Teammates no longer applies the status
# vocabulary. Its anchor is the --line-add call alone (m-noifguard's is the --line-replace one), so the
# anchor must occur exactly once in the program, or the mutation could land on another site.
n_ifadd="$(grep -cF 'ifstatus_chk(B, 0)' "$PROG")" || n_ifadd=0
n_ifrep="$(grep -cF 'ifstatus_chk(C, h)' "$PROG")" || n_ifrep=0
if [ "$n_ifadd" = 1 ] && [ "$n_ifrep" = 1 ]; then ok "m-noifadd anchor: ifstatus_chk(B, 0) occurs once, beside the one m-noifguard anchor"
else bad "m-noifadd anchor: ifstatus_chk(B, 0) occurs $n_ifadd time(s) and ifstatus_chk(C, h) $n_ifrep, not once each"; fi
mp="$(mkmutn m-noifadd 'ifstatus_chk(B, 0)' 'nop = 0')" && score m-noifadd "$mp" || bad "m-noifadd: mutation did not apply"

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

report_end snapshot-update-stamps
