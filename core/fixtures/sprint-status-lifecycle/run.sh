#!/usr/bin/env bash
# sprint-status-lifecycle/run.sh — prove sprint_id is derived MECHANICALLY (not by prose), that the
# freeze+roll is atomic/idempotent/byte-faithful, and that the grammar cannot repeat the reference
# consumer's collision.
#
# THE DEFECT THIS EXISTS TO CATCH. sprint_id had no mechanical source: route.md Step 6 was ~25 lines
# of prose the model executed by hand, with four rules — absent->1, done->N+1, else->N, copies
# disagree->HARD_BLOCK. None of them match a canonical that EXISTS but carries no `sprint:` key,
# which is exactly the state a rotate-at-close leaves behind. The likeliest reading of the prose in
# that state is "greenfield -> 1", which re-stamps a live project's drafts from sprint 1 and,
# per route.md's own warning, silently destroys the prior sprint's work.
#
# AND THE GRAMMAR COLLISION. The reference consumer's rotation tool matches sprint blocks with
# ^sprint[_-]([0-9]+)...: — which matches ZERO lines of the real single-sprint canonical (so its
# --close-sweep no-ops and exits 0 reporting success) while DOES matching `sprint_291_housekeeping:`
# and yielding 291. Arms H8/H9 are the regression lock: our keys must not repeat either half.
#
# SHAPE. Every question is an ARM: a function that builds its own tiny world, drives the tool it
# is handed ONCE per distinct state, and prints `<id> PASS|FAIL` lines. The shipping tool runs
# every arm.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"
echo "HERMETIC-CONSUMED core/scripts/sprint-status.sh"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE BROKEN: cannot source lib/inproc.sh" >&2; exit 2; }

# PRE-WRAP CONSUMER GATE. A core fixture ships ahead of its subject: a present subject with neither wrap half (the
# `ss_main() {` line, the column-0 source guard) predates the in-process wrap, and sourcing it would run its whole body:
# SKIP (FIXTURE BROKEN in the distribution). Exactly one half is a respelled subject this fixture cannot drive: FAIL.
# An unreadable subject is FIXTURE ERROR, rc 2. Nothing below sources or runs the subject before this gate.
_wd=0; _wg=0
grep -qxF 'ss_main() {' "$TOOL"; _x=$?
[ "$_x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $TOOL (grep exit $_x)" >&2; exit 2; }
[ "$_x" -ne 0 ] || _wd=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$TOOL"; _x=$?
[ "$_x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $TOOL (grep exit $_x)" >&2; exit 2; }
[ "$_x" -ne 0 ] || _wg=1
case "$_wd$_wg" in
  11) : ;;
  00) echo "SKIP: sprint-status-lifecycle: $TOOL predates the in-process wrap"; fx_skip_exit "$HERE" ;;
  *) bad "$TOOL carries one half of the in-process wrap (entry line, column-0 source guard: $_wd$_wg) -- a respelled subject this fixture cannot drive"
     report_end sprint-status-lifecycle ;;
esac
inproc_load "$TOOL" || { echo "FIXTURE BROKEN: cannot load $TOOL in process" >&2; exit 2; }


P="$WORK/proj"
IMPL="$P/_bmad-output/implementation-artifacts"
PLAN="$P/_bmad-output/planning-artifacts"

reset_tree() {
  rm -rf "$IMPL" "$PLAN"
  mkdir -p "$IMPL/sprint-status" "$PLAN/sprint-status"
}
put() { printf '%s\n' "$2" > "$1"; }

# rt: the shipping tool resolves its own schema; a copy lives outside core/scripts/ and would
# resolve a different schema (or none), so it is handed the schema explicitly. rte: always explicit.
# IN PROCESS: every arm asks ss_main through inproc_run (loaded once above); the programs run only in the cli cells at the end.
rt() { local t="$1"; shift; [ "$t" = "$TOOL" ] || { echo "FIXTURE BROKEN: rt was handed $t, not the subject" >&2; return 125; }; inproc_run "$TOOL" ss_main "$@"; }
rte() { local t="$1"; shift; ( export AI_DLC_SPRINT_STATUS_SCHEMA="$SCHEMA"; rt "$t" "$@" ); }
sid() { rt "$1" sprint-id --root "$P" 2>/dev/null; }

# Each arm appends `<id> PASS|FAIL` to RES in THE CURRENT SHELL (never a command substitution), so
# a memo an arm keeps survives into the next arm.
RES=""
res() { RES="$RES$1 $2"$'\n'; }
chk() { local id="$1"; shift; if "$@"; then res "$id" PASS; else res "$id" FAIL; fi; }

# ===== PART 1 — sprint-id, roll, grammar ========================================================

a_P0() { # --render is non-empty and deterministic (two renders are the question)
  local r1 r2
  r1="$(rt "$1" --render)"; r2="$(rt "$1" --render)"
  if [ -n "$r1" ] && [ "$r1" = "$r2" ]; then res P0 PASS; else res P0 FAIL; fi
}
a_P1() { reset_tree; if [ "$(sid "$1")" = "1" ]; then res P1 PASS; else res P1 FAIL; fi; }
a_P2() {
  reset_tree; put "$IMPL/sprint-status.yaml" 'sprint: 290
status: done'
  if [ "$(sid "$1")" = "291" ]; then res P2 PASS; else res P2 FAIL; fi
}
a_P3() {
  reset_tree; put "$IMPL/sprint-status.yaml" 'sprint: 291
status: in_progress'
  if [ "$(sid "$1")" = "291" ]; then res P3 PASS; else res P3 FAIL; fi
}

# THE PROPERTY — the answer with archives EQUALS the answer with none, per canonical state. The current
# sprint is read ONLY from the canonical's own `sprint:` + `status:` record. Frozen archives (legacy
# `sprint-status/sprint-<N>.yaml` AND the grammar's `s<N>/sprint-status.yaml`) are history, and
# deleting history must change nothing. Each state is seeded WITH both archive spellings and again
# with every archive deleted; stdout AND exit code must match across the pair AND equal the stated
# expectation, so two wrong answers that agree cannot pass. A canonical that exists with no `sprint:`
# key REFUSES (exit 1, empty stdout, stderr names the file) — never 1, never max+1.
seed_state() { # <state> <archives 0|1>
  reset_tree
  case "$1" in
    preamble)  put "$IMPL/sprint-status.yaml" '# Sprint Status
# (preamble-only: what a rotate-at-close leaves behind)' ;;
    empty)     : > "$IMPL/sprint-status.yaml" ;;
    done6)     put "$IMPL/sprint-status.yaml" 'sprint: 6
status: done' ;;
    inprog7)   put "$IMPL/sprint-status.yaml" 'sprint: 7
status: in_progress' ;;
    none)      : ;;
    implpre)   put "$IMPL/sprint-status.yaml" '# Sprint Status
# (preamble-only)'
               put "$PLAN/sprint-status.yaml" 'sprint: 6
status: in_progress' ;;
  esac
  if [ "$2" = 1 ]; then
    mkdir -p "$IMPL/s289" "$IMPL/s290"
    put "$IMPL/sprint-status/sprint-289.yaml" 'sprint: 289
status: done'
    put "$IMPL/sprint-status/sprint-290.yaml" 'sprint: 290
status: done'
    put "$IMPL/s289/sprint-status.yaml" 'sprint: 289
status: done'
    put "$IMPL/s290/sprint-status.yaml" 'sprint: 290
status: done'
  else
    rm -rf "$IMPL/s289" "$IMPL/s290" "$IMPL/sprint-status" "$PLAN/sprint-status" "$PLAN/s289" "$PLAN/s290"
  fi
}
# prints "<stdout>|<rc>"; stderr is left in $WORK/err
sid_rc() { # <tool>
  local o rc
  o="$(rte "$1" sprint-id --root "$P" 2>"$WORK/err")"; rc=$?
  printf '%s|%s' "$o" "$rc"
}
TBL_MSG=""
tb_state() { # <tool> <state>
  local st="$2" exp withA noA errA errN f=0
  case "$st" in
    preamble|empty|implpre) exp="|1" ;;
    done6|inprog7)          exp="7|0" ;;
    none)                   exp="1|0" ;;
  esac
  seed_state "$st" 1; withA="$(sid_rc "$1")"; errA="$(cat "$WORK/err")"
  seed_state "$st" 0; noA="$(sid_rc "$1")";   errN="$(cat "$WORK/err")"
  printf -v "TBWA_$st" %s "$withA"; printf -v "TBWN_$st" %s "$noA"
  if [ "$withA" != "$noA" ]; then f=1; TBL_MSG="$TBL_MSG [$st: archives='$withA' none='$noA']"; fi
  if [ "$withA" != "$exp" ] || [ "$noA" != "$exp" ]; then f=1; TBL_MSG="$TBL_MSG [$st: expected '$exp' got archives='$withA' none='$noA']"; fi
  if [ "$exp" = "|1" ]; then
    case "$errA" in *sprint-status.yaml*) : ;; *) f=1; TBL_MSG="$TBL_MSG [$st: stderr (archives) does not name the file]" ;; esac
    case "$errN" in *sprint-status.yaml*) : ;; *) f=1; TBL_MSG="$TBL_MSG [$st: stderr (none) does not name the file]" ;; esac
  fi
  if [ "$f" = 0 ]; then res "TB_$st" PASS; else res "TB_$st" FAIL; fi
}

a_P5() { # copies disagree -> HARD_BLOCK exit 3 (route rule 5)
  reset_tree
  put "$IMPL/sprint-status.yaml" 'sprint: 291
status: done'
  put "$PLAN/sprint-status.yaml" 'sprint: 290
status: done'
  rt "$1" sprint-id --root "$P" >/dev/null 2>&1
  if [ $? -eq 3 ]; then res P5 PASS; else res P5 FAIL; fi
}

# roll freezes BYTE-FAITHFULLY, then rolls forward, then a re-run must not re-freeze (idempotent):
# one world, one roll plus the re-run. The reference consumer's ADR called idempotency a data-loss
# guard: a second run that re-freezes a pruned canonical overwrites the real archive with an empty one.
a_roll() {
  local BODY SLOTTED LEGACY_FROZEN FROZEN B
  reset_tree
  BODY='sprint: 291
status: done
stories:
  story-291-1:
    status: done'
  put "$IMPL/sprint-status.yaml" "$BODY"
  rt "$1" roll --sprint 292 --root "$P" >/dev/null 2>&1
  # Resolve the freeze WHEREVER it landed, so the byte-faithfulness and idempotency arms test BYTES
  # and not location. The destination has its own arm; an arm that tests two things cannot say which
  # of them failed.
  SLOTTED="$IMPL/s291/sprint-status.yaml"
  LEGACY_FROZEN="$IMPL/sprint-status/sprint-291.yaml"
  FROZEN="$SLOTTED"; [ -f "$FROZEN" ] || FROZEN="$LEGACY_FROZEN"
  if [ -f "$FROZEN" ] && [ "$(cat "$FROZEN")" = "$BODY" ]; then res R6a PASS; else res R6a FAIL; fi
  # THE DEFECT R6b EXISTS FOR. `roll` composed the PRE-MIGRATION `sprint-status/sprint-<N>.yaml`
  # while `validate-artifact-paths.sh` BLOCKS on exactly that path; R6a passed throughout, on the
  # wrong destination.
  if [ -f "$SLOTTED" ] && [ ! -e "$LEGACY_FROZEN" ]; then res R6b PASS; else res R6b FAIL; fi
  if grep -q '^sprint: 292' "$IMPL/sprint-status.yaml" && grep -q '^status: in_progress' "$IMPL/sprint-status.yaml"; then res R6c PASS; else res R6c FAIL; fi
  if [ "$(sid "$1")" = "292" ]; then res R6d PASS; else res R6d FAIL; fi
  B="$(cat "$FROZEN" 2>/dev/null)"
  rt "$1" roll --sprint 292 --root "$P" >/dev/null 2>&1
  if [ "$(cat "$FROZEN" 2>/dev/null)" = "$B" ]; then res R7 PASS; else res R7 FAIL; fi
}

# idempotency SURVIVES THE MIGRATION BOUNDARY. On a consumer that has NOT migrated, the only freeze
# on disk is under the old spelling. A writer that knows one path treats that as absent and writes a
# SECOND archive of the same sprint in the slot — two records of one sprint. The freeze already
# there is honoured where it lies, and nothing new is written.
LEGACY_BODY='sprint: 291
status: done
stories:
  story-291-1:
    status: done'
a_legacy() {
  reset_tree
  put "$IMPL/sprint-status.yaml" "$LEGACY_BODY"
  put "$IMPL/sprint-status/sprint-291.yaml" "$LEGACY_BODY"
  rt "$1" roll --sprint 292 --root "$P" >/dev/null 2>&1
  if [ ! -e "$IMPL/s291/sprint-status.yaml" ]; then res R7a1 PASS; else res R7a1 FAIL; fi
  if [ "$(cat "$IMPL/sprint-status/sprint-291.yaml" 2>/dev/null)" = "$LEGACY_BODY" ]; then res R7a2 PASS; else res R7a2 FAIL; fi
  if grep -q '^sprint: 292' "$IMPL/sprint-status.yaml"; then res R7a3 PASS; else res R7a3 FAIL; fi
}
# A freeze that DIFFERS still HARD_BLOCKs. Without this, "no twin was minted" passes on a writer that
# skips the freeze unconditionally. The divergent freeze is seeded under BOTH spellings on purpose:
# seeded under only one, the arm also fails whenever the writer changes WHICH spelling it
# consults, and then it is a second reading of the destination arm.
a_divergent() {
  local DIVERGENT
  reset_tree
  mkdir -p "$IMPL/s291"
  put "$IMPL/sprint-status.yaml" "$LEGACY_BODY"
  DIVERGENT='sprint: 291
status: done
# edited by hand after the freeze'
  put "$IMPL/s291/sprint-status.yaml" "$DIVERGENT"
  put "$IMPL/sprint-status/sprint-291.yaml" "$DIVERGENT"
  rt "$1" roll --sprint 292 --root "$P" >/dev/null 2>&1
  if [ $? -eq 3 ]; then res R7ac PASS; else res R7ac FAIL; fi
}
a_greenroll() { # roll CREATES the file on greenfield, and mints no twin
  reset_tree
  rm -f "$IMPL/sprint-status.yaml" "$PLAN/sprint-status.yaml"
  rt "$1" roll --sprint 1 --root "$P" >/dev/null 2>&1
  if [ -f "$IMPL/sprint-status.yaml" ]; then res R7b1 PASS; else res R7b1 FAIL; fi
  if [ ! -f "$PLAN/sprint-status.yaml" ]; then res R7b2 PASS; else res R7b2 FAIL; fi
}
# `sprint_291_housekeeping:` matches the reference tool's sprint-block regex and yields 291. If our
# grammar ever repeats that, a housekeeping block alone would look like a sprint envelope.
a_H8() {
  reset_tree
  put "$IMPL/sprint-status.yaml" 'sprint_291_housekeeping:
  envelope_status: done
  closure_evidence: "x"'
  if [ "$(sid "$1")" != "291" ]; then res H8 PASS; else res H8 FAIL; fi
}
# The inverse: once the close envelope exists, `sprint:` must still win and the housekeeping key must
# not shadow it.
a_H9() {
  reset_tree
  put "$IMPL/sprint-status.yaml" 'sprint: 290
status: done
stories:
  story-290-1:
    status: done
sprint_290_housekeeping:
  envelope_status: done
  closure_evidence: "merged, deployed, validated"'
  if [ "$(sid "$1")" = "291" ]; then res H9 PASS; else res H9 FAIL; fi
}
a_R10() { # roll REFUSES to roll over a sprint that is not closed
  reset_tree
  put "$IMPL/sprint-status.yaml" 'sprint: 291
status: in_progress'
  rt "$1" roll --sprint 292 --root "$P" >/dev/null 2>&1
  if [ $? -eq 3 ]; then res R10 PASS; else res R10 FAIL; fi
}
a_R11() { # fail-closed on an unreadable schema
  reset_tree
  put "$IMPL/sprint-status.yaml" 'sprint: 291
status: in_progress'
  # A NON-EXISTENT override path falls back to the real schema by design (the resolver skips it), so
  # that would prove nothing. Point it at a REAL but corrupt file — the state that actually fails.
  printf 'not json{' > "$WORK/corrupt.json"
  if ( export AI_DLC_SPRINT_STATUS_SCHEMA="$WORK/corrupt.json"; rt "$1" sprint-id --root "$P" ) >/dev/null 2>&1; then res R11 FAIL; else res R11 PASS; fi
}

# ===== PART 1b — BL-938: a BMAD copy in the freeze slot, and roll decides every view before a write ==
# The reference consumer's BMAD planner wrote its own sprint-status into planning-artifacts/s321/, the
# slot `roll` freezes into. roll read it as a divergent freeze, exited 3 AFTER rolling the
# implementation view, and left a tree sprint-id HARD_BLOCKs. Each world below is built from the seed
# files once, `roll --sprint 322` runs once over it (rr), and the arm reads that one run. rr leaves
# rc/out/err and a path+mode+md5 listing of the whole _bmad-output before and after in
# $RWD/<tool>/<tag>/, which receipt-bl938.sh reads for the shipping tool. A "no write" arm compares the
# two listings whole; it never names the files it expects untouched.
SD="$WORK/sd"; RWD="$WORK/rw"; mkdir -p "$SD" "$RWD"
put "$SD/impl321" 'sprint: 321
status: done
gate1: pending
stories:
  story-321-1:
    status: done'
put "$SD/plan321" 'sprint: 321
status: done
stories:
  story-321-1:
    status: done'
put "$SD/impl322" 'sprint: 322
status: in_progress'
put "$SD/impl323" 'sprint: 323
status: in_progress'
put "$SD/plan320" 'sprint: 320
status: done'
put "$SD/inprog321" 'sprint: 321
status: in_progress'
put "$SD/preamble" '# Sprint Status
# (preamble-only)'
put "$SD/div" 'sprint: 321
status: done
# edited by hand after the freeze'
# R12's seed: the REAL producer's bytes (graph fb6f198e7:_bmad-output/planning-artifacts/s321/
# sprint-status.yaml), trimmed to its header comment block, its top-level keys and the first two
# development_status entries. Pasted, never read from the consumer at run time.
cat > "$SD/bmad" <<'BMADEOF'
# STATUS DEFINITIONS:
# ==================
# Epic Status:
#   - backlog: Epic not yet started
#   - in-progress: Epic actively being worked on
#   - done: All stories in epic completed

# Story Status:
#   - backlog: Story only exists in epic file
#   - ready-for-dev: Story file created, ready for development
#   - in-progress: Developer actively working on implementation
#   - review: Implementation complete, ready for review
#   - done: Story completed

# Retrospective Status:
#   - optional: Can be completed but not required
#   - done: Retrospective has been completed

# Action Item Status:
#   - open: Committed during a retrospective, not yet addressed
#   - in-progress: Actively being worked on
#   - done: Completed

# WORKFLOW NOTES:
# ===============
# - Epic transitions to 'in-progress' automatically when its first story starts (via build's sprint sync)
# - Stories can be worked in parallel if team capacity allows
# - Developer typically creates the next story after the previous one is 'done' to incorporate learnings
# - Dev moves story to 'review', then runs code-review (fresh context, different LLM recommended)
# - Retrospective appends its action items to action_items; the status view surfaces open ones
generated: 11-04-2026 06:31
last_updated: 11-04-2026 06:31
project: graph
project_key: NOKEY
tracking_system: file-system
story_location: _bmad-output/planning-artifacts/s321/stories
planned_close: 2026-11-11T00:00:00Z
development_status:
  epic-1: backlog
  1-1-feasibility-gate-and-the-matic-unchanged-replay-fixture: done
BMADEOF
# R12crlf: the same bytes, CRLF. R17: a BMAD copy that differs from the slot's by its stamp.
awk '{ printf "%s\r\n", $0 }' "$SD/bmad" > "$SD/bmadcrlf"
sed 's/^generated: .*/generated: 11-05-2026 09:00/' "$SD/bmad" > "$SD/bmadother"
# R12e: the inline-empty `development_status: {}` form. A HAND-WRITTEN or FOREIGN-TOOL shape, NOT
# producer output: the BMAD planner refuses an empty entry list and writes one key per entry.
put "$SD/bmadempty" '# hand-written sprint-status (foreign tool)
generated: 11-04-2026 06:31
project: graph
development_status: {}'
# R13: a slot file carrying BOTH keys — a freeze, whatever else it holds — that differs.
put "$SD/r13" 'sprint: 321
status: done
development_status:
  epic-1: backlog'
# R13b: a real sprint-less slot shape, `sprint_<N>_housekeeping:` first. At graph 5596361ce, 75 of 144
# slot files carry no top-level `sprint:`, 57 of those carry a housekeeping key and 22 open with one;
# this is the smallest of them (implementation-artifacts/s188/sprint-status.yaml, renumbered to s321).
cat > "$SD/hk" <<'HKEOF'
sprint_321_housekeeping:
  envelope_status: in-progress
  variant: feature
  branch: ai-dlc/feature/sweep-wallet-expansion
# ============================================================
# SPRINT 192: IL accuracy pipeline fix (bug → feature scope)
# Branch: ai-dlc/bug/impermanent-loss-accuracy
# ============================================================
HKEOF
for _s in impl321 plan321 bmad bmadcrlf bmadother bmadempty r13 hk; do
  [ -s "$SD/$_s" ] || { echo "FIXTURE ERROR: seed $_s was not written" >&2; exit 2; }
done
cmp -s "$SD/bmad" "$SD/bmadcrlf" && { echo "FIXTURE ERROR: the CRLF seed equals the LF seed" >&2; exit 2; }
cmp -s "$SD/bmad" "$SD/bmadother" && { echo "FIXTURE ERROR: the differing BMAD seed equals the slot seed" >&2; exit 2; }

ls_tree() { # every file under _bmad-output as `<relpath> <mode> <md5>`, sorted
  python3 -I -c 'import os, sys, hashlib
r = sys.argv[1]; out = []
for d, _, fs in os.walk(r):
    for f in fs:
        p = os.path.join(d, f)
        out.append("%s %o %s" % (os.path.relpath(p, r), os.stat(p).st_mode & 0o777, hashlib.md5(open(p, "rb").read()).hexdigest()))
print("\n".join(sorted(out)))' "$P/_bmad-output"
}
rr() { # <tool> <tag>: ONE `roll --sprint 322` over the world on disk -> RD, RRC
  RD="$RWD/${1##*/}/$2"; mkdir -p "$RD"
  ls_tree > "$RD/before.ls"
  rt "$1" roll --sprint 322 --root "$P" > "$RD/out" 2> "$RD/err"; echo "$?" > "$RD/rc"
  ls_tree > "$RD/after.ls"
  read -r RRC < "$RD/rc"
}
unchanged() { [ -s "$RD/before.ls" ] && cmp -s "$RD/before.ls" "$RD/after.ls"; }
remedy() { grep -q 'Remedy:' "$RD/err"; }
w() { # <seed> <dest>: place one seed file into the world
  mkdir -p "${2%/*}" && cp "$SD/$1" "$2"
}
rolled() { grep -q '^sprint: 322$' "$IMPL/sprint-status.yaml" && grep -q '^sprint: 322$' "$PLAN/sprint-status.yaml"; }

a_R12() { # BMAD in the PLANNING slot: relocated byte-for-byte, the real freeze written into the slot
  reset_tree; w impl321 "$IMPL/sprint-status.yaml"; w plan321 "$PLAN/sprint-status.yaml"; w bmad "$PLAN/s321/sprint-status.yaml"
  rr "$1" R12
  if [ "$RRC" = 0 ] && rolled && cmp -s "$PLAN/s321/sprint-status.yaml" "$SD/plan321" \
     && cmp -s "$PLAN/s321/bmad-sprint-status.yaml" "$SD/bmad" && cmp -s "$IMPL/s321/sprint-status.yaml" "$SD/impl321"; then
    res R12 PASS; else res R12 FAIL; fi
}
a_R12i() { # the same copy in the IMPLEMENTATION slot: the predicate is per view
  reset_tree; w impl321 "$IMPL/sprint-status.yaml"; w plan321 "$PLAN/sprint-status.yaml"; w bmad "$IMPL/s321/sprint-status.yaml"
  rr "$1" R12i
  if [ "$RRC" = 0 ] && rolled && cmp -s "$IMPL/s321/sprint-status.yaml" "$SD/impl321" \
     && cmp -s "$IMPL/s321/bmad-sprint-status.yaml" "$SD/bmad"; then res R12i PASS; else res R12i FAIL; fi
}
a_R12e() { # the inline-empty `development_status: {}` form is a BMAD copy too
  reset_tree; w impl321 "$IMPL/sprint-status.yaml"; w plan321 "$PLAN/sprint-status.yaml"; w bmadempty "$PLAN/s321/sprint-status.yaml"
  rr "$1" R12e
  if [ "$RRC" = 0 ] && cmp -s "$PLAN/s321/sprint-status.yaml" "$SD/plan321" \
     && cmp -s "$PLAN/s321/bmad-sprint-status.yaml" "$SD/bmadempty"; then res R12e PASS; else res R12e FAIL; fi
}
a_R12crlf() { # a CRLF copy, mode 0640: moved, not rewritten — bytes AND mode survive
  reset_tree; w impl321 "$IMPL/sprint-status.yaml"; w plan321 "$PLAN/sprint-status.yaml"; w bmadcrlf "$PLAN/s321/sprint-status.yaml"
  chmod 0640 "$PLAN/s321/sprint-status.yaml"
  rr "$1" R12crlf
  if [ "$RRC" = 0 ] && cmp -s "$PLAN/s321/bmad-sprint-status.yaml" "$SD/bmadcrlf" \
     && grep -q '^planning-artifacts/s321/sprint-status.yaml 640 ' "$RD/before.ls" \
     && grep -q '^planning-artifacts/s321/bmad-sprint-status.yaml 640 ' "$RD/after.ls" \
     && cmp -s "$PLAN/s321/sprint-status.yaml" "$SD/plan321"; then res R12crlf PASS; else res R12crlf FAIL; fi
}
a_R12leg() { # an identical LEGACY freeze beside a BMAD slot: relocate, write nothing into the slot
  reset_tree; w impl321 "$IMPL/sprint-status.yaml"; w plan321 "$PLAN/sprint-status.yaml"
  w plan321 "$PLAN/sprint-status/sprint-321.yaml"; w bmad "$PLAN/s321/sprint-status.yaml"
  rr "$1" R12leg
  if [ "$RRC" = 0 ] && [ ! -e "$PLAN/s321/sprint-status.yaml" ] && cmp -s "$PLAN/s321/bmad-sprint-status.yaml" "$SD/bmad" \
     && cmp -s "$PLAN/sprint-status/sprint-321.yaml" "$SD/plan321" && rolled; then res R12leg PASS; else res R12leg FAIL; fi
}
# The refusal worlds below put the implementation view at 322 (the half-rolled shape) wherever the
# arm's subject is a single view, so no OTHER view is writable; R14 and R15 are the atomicity arms.
a_R13() { # near-miss: `sprint:` AND `development_status:`, differing -> the divergent-freeze refusal
  reset_tree; w impl322 "$IMPL/sprint-status.yaml"; w plan321 "$PLAN/sprint-status.yaml"; w r13 "$PLAN/s321/sprint-status.yaml"
  rr "$1" R13
  if [ "$RRC" = 3 ] && unchanged && remedy && grep -q 'DIFFERS from the canonical' "$RD/err"; then res R13 PASS; else res R13 FAIL; fi
}
a_R13b() { # near-miss: housekeeping-first, neither key -> not recognisably BMAD, the divergent refusal
  reset_tree; w impl322 "$IMPL/sprint-status.yaml"; w plan321 "$PLAN/sprint-status.yaml"; w hk "$PLAN/s321/sprint-status.yaml"
  rr "$1" R13b
  if [ "$RRC" = 3 ] && unchanged && remedy && grep -q 'DIFFERS from the canonical' "$RD/err"; then res R13b PASS; else res R13b FAIL; fi
}
a_R14() { # atomicity: a divergent PLANNING freeze (the view iterated second) -> nothing written anywhere
  reset_tree; w impl321 "$IMPL/sprint-status.yaml"; w plan321 "$PLAN/sprint-status.yaml"; w div "$PLAN/s321/sprint-status.yaml"
  rr "$1" R14
  if [ "$RRC" = 3 ] && unchanged && remedy && grep -q '^  - planning: ' "$RD/err" \
     && grep -qF "planning-artifacts/s321/sprint-status.yaml" "$RD/err"; then res R14 PASS; else res R14 FAIL; fi
}
a_R15() { # atomicity: implementation done + planning in_progress -> nothing written anywhere
  reset_tree; w impl321 "$IMPL/sprint-status.yaml"; w inprog321 "$PLAN/sprint-status.yaml"
  rr "$1" R15
  if [ "$RRC" = 3 ] && unchanged && remedy; then res R15 PASS; else res R15 FAIL; fi
}
a_R16() { # recovery: the tree the old engine half-rolled is completed by one re-run
  reset_tree; w impl322 "$IMPL/sprint-status.yaml"; w impl321 "$IMPL/s321/sprint-status.yaml"
  w plan321 "$PLAN/sprint-status.yaml"; w bmad "$PLAN/s321/sprint-status.yaml"
  rr "$1" R16
  rt "$1" sprint-id --root "$P" > "$RD/sid.out" 2>/dev/null; echo "$?" > "$RD/sid.rc"
  local sr so=""; read -r sr < "$RD/sid.rc"; read -r so < "$RD/sid.out"
  if [ "$RRC" = 0 ] && [ "$sr" = 0 ] && [ "$so" = 322 ]; then res R16 PASS; else res R16 FAIL; fi
}
a_R17() { # the relocation target exists and DIFFERS -> refused, nothing written
  reset_tree; w impl322 "$IMPL/sprint-status.yaml"; w plan321 "$PLAN/sprint-status.yaml"
  w bmad "$PLAN/s321/sprint-status.yaml"; w bmadother "$PLAN/s321/bmad-sprint-status.yaml"
  rr "$1" R17
  if [ "$RRC" = 3 ] && unchanged && remedy && grep -q 'relocation target' "$RD/err"; then res R17 PASS; else res R17 FAIL; fi
}
a_R18() { # BMAD in the impl slot + planning in_progress -> no eager relocation: nothing moves
  reset_tree; w impl321 "$IMPL/sprint-status.yaml"; w bmad "$IMPL/s321/sprint-status.yaml"; w inprog321 "$PLAN/sprint-status.yaml"
  rr "$1" R18
  if [ "$RRC" = 3 ] && unchanged && remedy; then res R18 PASS; else res R18 FAIL; fi
}
a_R19() { # both slots divergent -> one run names BOTH
  reset_tree; w impl321 "$IMPL/sprint-status.yaml"; w div "$IMPL/s321/sprint-status.yaml"
  w plan321 "$PLAN/sprint-status.yaml"; w div "$PLAN/s321/sprint-status.yaml"
  rr "$1" R19
  if [ "$RRC" = 3 ] && unchanged && remedy && grep -qF "implementation-artifacts/s321/sprint-status.yaml" "$RD/err" \
     && grep -qF "planning-artifacts/s321/sprint-status.yaml" "$RD/err"; then res R19 PASS; else res R19 FAIL; fi
}
a_R20() { # the identical relocation target already exists: the slot copy goes, the target is untouched
  reset_tree; w impl321 "$IMPL/sprint-status.yaml"; w plan321 "$PLAN/sprint-status.yaml"
  w bmad "$PLAN/s321/sprint-status.yaml"; w bmad "$PLAN/s321/bmad-sprint-status.yaml"
  rr "$1" R20
  if [ "$RRC" = 0 ] && rolled && cmp -s "$PLAN/s321/sprint-status.yaml" "$SD/plan321" \
     && cmp -s "$PLAN/s321/bmad-sprint-status.yaml" "$SD/bmad"; then res R20 PASS; else res R20 FAIL; fi
}
a_R21() { # E: a view AHEAD of the target -> refused, never rolled backward
  reset_tree; w impl323 "$IMPL/sprint-status.yaml"
  rr "$1" R21
  if [ "$RRC" = 3 ] && unchanged && remedy && grep -q 'AHEAD of the target' "$RD/err"; then res R21 PASS; else res R21 FAIL; fi
}
a_R22() { # F: the views disagree, both behind the target -> refused with rule 5's words
  reset_tree; w impl321 "$IMPL/sprint-status.yaml"; w plan320 "$PLAN/sprint-status.yaml"
  rr "$1" R22
  if [ "$RRC" = 3 ] && unchanged && remedy && grep -q 'copies disagree' "$RD/err"; then res R22 PASS; else res R22 FAIL; fi
}
a_R22b() { # F: a view AT the target beside a view TWO behind is no half-roll -> the target view joins rule 5
  reset_tree; w impl322 "$IMPL/sprint-status.yaml"; w plan320 "$PLAN/sprint-status.yaml"
  rr "$1" R22b
  if [ "$RRC" = 3 ] && unchanged && remedy && grep -q 'copies disagree' "$RD/err" \
     && grep -qF 'implementation=322' "$RD/err"; then res R22b PASS; else res R22b FAIL; fi
}
a_R23() { # C: a preamble-only view beside a view still to roll -> exit 1, sprint-id's restore text
  reset_tree; w preamble "$IMPL/sprint-status.yaml"; w plan321 "$PLAN/sprint-status.yaml"
  rr "$1" R23
  if [ "$RRC" = 1 ] && unchanged && grep -q 'Restore `sprint: <N>`' "$RD/err"; then res R23 PASS; else res R23 FAIL; fi
}
a_R24() { # the BMAD relocation target is a DIRECTORY -> refused in phase 1, exit 3, nothing written
  reset_tree; w impl322 "$IMPL/sprint-status.yaml"; w plan321 "$PLAN/sprint-status.yaml"
  w bmad "$PLAN/s321/sprint-status.yaml"; mkdir -p "$PLAN/s321/bmad-sprint-status.yaml"
  rr "$1" R24
  if [ "$RRC" = 3 ] && unchanged && remedy && [ -d "$PLAN/s321/bmad-sprint-status.yaml" ] \
     && grep -q 'relocation target .* exists and is not a regular file' "$RD/err"; then res R24 PASS; else res R24 FAIL; fi
}
a_R24s() { # the planning FREEZE SLOT is a DIRECTORY -> refused in phase 1, exit 3, nothing written
  reset_tree; w impl321 "$IMPL/sprint-status.yaml"; w plan321 "$PLAN/sprint-status.yaml"
  mkdir -p "$PLAN/s321/sprint-status.yaml"
  rr "$1" R24s
  if [ "$RRC" = 3 ] && unchanged && remedy && [ -d "$PLAN/s321/sprint-status.yaml" ] \
     && grep -q 'the freeze slot .* exists and is not a regular file' "$RD/err"; then res R24s PASS; else res R24s FAIL; fi
}
a_R24p() { # the planning slot's PARENT s321 is a regular FILE -> refused in phase 1, exit 3, nothing written
  reset_tree; w impl321 "$IMPL/sprint-status.yaml"; w plan321 "$PLAN/sprint-status.yaml"
  : > "$PLAN/s321"
  rr "$1" R24p
  if [ "$RRC" = 3 ] && unchanged && remedy && [ -f "$PLAN/s321" ] \
     && grep -q 's321 exists and is not a directory' "$RD/err"; then res R24p PASS; else res R24p FAIL; fi
}

# ===== PART 2 — Check 5, `check-stories` =========================================================
# gate-validation.md Check 5 said "compare status values programmatically" and core shipped no
# program, so the comparison was done by hand at every gate. Three consumer-authored versions of it
# each went vacuously green at least once — a story-id glob that matched none of the corpus, a field
# set compared zero times, a body-header grammar the story files no longer carried — and each
# printed its zero beside a success line. So each arm asserts the COUNTS and the STATES, not just
# the verdict.

CS="$WORK/cs"
CSTORIES="$CS/_bmad-output/planning-artifacts/s291/stories"
CIMPL="$CS/_bmad-output/implementation-artifacts"
CPLAN="$CS/_bmad-output/planning-artifacts"

cs_reset() { rm -rf "$CS"; mkdir -p "$CSTORIES" "$CIMPL" "$CPLAN"; }
story_fm()  { printf -- '---\nstatus: %s\nsprint: 291\n---\n\n# story\n' "$2" > "$CSTORIES/$1.md"; }
story_hdr() { printf -- '# story\n\n**Status:** %s\n' "$2"              > "$CSTORIES/$1.md"; }

cs_run() { # <tool> [extra args] -> CS_OUT CS_RC
  local t="$1"; shift
  CS_OUT="$(rte "$t" check-stories "$@" --root "$CS" 2>&1)"
  CS_RC=$?
}
ENV1='sprint: 291
status: in_progress
stories:
  story-291-1:
    file: stories/story-1.md
    status: done'

a_A13() { # a consistent tree PASSES, and says how many comparisons it made
  cs_reset; story_fm story-1 done; put "$CIMPL/sprint-status.yaml" "$ENV1"
  cs_run "$1"
  if [ "$CS_RC" -eq 0 ] && grep -q 'PASS — 1 comparison(s)' <<<"$CS_OUT"; then res A13 PASS; else res A13 FAIL; fi
}
a_A14() { # a mismatch is REPORTED, not absorbed
  cs_reset; story_fm story-1 review; put "$CIMPL/sprint-status.yaml" "$ENV1"
  cs_run "$1"
  if [ "$CS_RC" -eq 1 ] && grep -q 'STATUS MISMATCH' <<<"$CS_OUT"; then res A14 PASS; else res A14 FAIL; fi
}
a_A15() { # a story file with NO frontmatter is read through its `**Status:**` header and COUNTED
  # 726 of the reference consumer's 988 story files carry only this spelling; a reader that knows
  # only frontmatter skips them and reports the skip as nothing to do.
  cs_reset; story_hdr story-1 'done (all three gates green)'; put "$CIMPL/sprint-status.yaml" "$ENV1"
  cs_run "$1"
  if [ "$CS_RC" -eq 0 ] && grep -q 'PASS — 1 comparison(s)' <<<"$CS_OUT"; then res A15 PASS; else res A15 FAIL; fi
}
a_A16() { # THE VACUITY FLOOR. A canonical with no `stories:` key compared nothing: its own exit code.
  cs_reset; story_fm story-1 done
  put "$CIMPL/sprint-status.yaml" 'sprint: 291
status: in_progress'
  cs_run "$1"
  if [ "$CS_RC" -eq 4 ]; then res A16 PASS; else res A16 FAIL; fi
}
a_A17() { # an EMPTY `stories:` block is what `roll` itself writes, so it must not be a finding
  cs_reset
  put "$CIMPL/sprint-status.yaml" 'sprint: 291
status: in_progress
stories:
  # populated at stories-test-strategy. A MAPPING keyed by story id
  # (story-291-<M>:), never a list — a list form matches no reader.'
  cs_run "$1"
  if ! grep -q 'FINDING' <<<"$CS_OUT"; then res A17 PASS; else res A17 FAIL; fi
}
a_A18() { # the LIST form: the reference consumer's tool compared ZERO fields and reported success
  cs_reset; story_fm story-1 done
  put "$CIMPL/sprint-status.yaml" 'sprint: 291
status: in_progress
stories:
  - id: story-291-1
    status: done'
  cs_run "$1"
  if [ "$CS_RC" -eq 1 ] && grep -q 'LIST form' <<<"$CS_OUT"; then res A18 PASS; else res A18 FAIL; fi
}
a_A19() { # an entry naming a story file that is not there is a FINDING
  cs_reset; put "$CIMPL/sprint-status.yaml" "$ENV1"
  cs_run "$1"
  if [ "$CS_RC" -eq 1 ] && grep -q 'names no readable story file' <<<"$CS_OUT"; then res A19 PASS; else res A19 FAIL; fi
}
a_A20() { # two entries under one id: whichever a reader takes, the other is unenforced
  cs_reset; story_fm story-1 done
  put "$CIMPL/sprint-status.yaml" 'sprint: 291
status: in_progress
stories:
  story-291-1:
    file: stories/story-1.md
    status: done
  story-291-1:
    file: stories/story-1.md
    status: review'
  cs_run "$1"
  if [ "$CS_RC" -eq 1 ] && grep -q 'duplicate story key' <<<"$CS_OUT"; then res A20 PASS; else res A20 FAIL; fi
}
a_A21() { # the two canonical copies are BOTH authoritative: route.md Step 6 rule 5 one grain down
  cs_reset; story_fm story-1 done
  put "$CIMPL/sprint-status.yaml" "$ENV1"
  put "$CPLAN/sprint-status.yaml" 'sprint: 291
status: in_progress
stories:
  story-291-1:
    file: stories/story-1.md
    status: review'
  cs_run "$1"
  if [ "$CS_RC" -eq 1 ] && grep -q 'canonical copies disagree' <<<"$CS_OUT"; then res A21 PASS; else res A21 FAIL; fi
}
a_A22() { # index-prefix collision: `story-291-1` must never resolve to `story-10-...`
  # Asserted on the identity of the file the tool read, not on the finding text A19 also carries.
  # THE KEY STILL SPELLS THE SPRINT AND THE FILE NO LONGER DOES: the declared sprint is stripped from
  # the key to give the index, so `story-291-1` looks for `story-1-*.md` inside `s291/stories/`.
  cs_reset; story_fm story-10-late-arrival review
  put "$CIMPL/sprint-status.yaml" 'sprint: 291
status: in_progress
stories:
  story-291-1:
    status: done'
  cs_run "$1"
  if ! grep -q 'story-10-late-arrival' <<<"$CS_OUT"; then res A22 PASS; else res A22 FAIL; fi
}
# The review/review tree under --require-done is the A23 flag capture AND the A24 `review` twin: one
# world, one drive, shared by both arms for the same tool (the subject's output for that state is
# identical, so a second drive would only repeat it).
RDR_TOOL=""; RDR_OUT=""; RDR_RC=""
rd_review() { # <tool>
  [ "$RDR_TOOL" = "$1" ] && return 0
  cs_reset; story_fm story-1 review
  put "$CIMPL/sprint-status.yaml" 'sprint: 291
status: in_progress
stories:
  story-291-1:
    file: stories/story-1.md
    status: review'
  cs_run "$1" --require-done; RDR_OUT="$CS_OUT"; RDR_RC=$CS_RC; RDR_TOOL="$1"
}
a_A23() { # --require-done: a story still `review`, consistent everywhere, is a NOT DONE finding
  # Its two near-misses ride in the same arm, so one id carries the flag's whole property: the
  # SAME tree without the flag passes (the flag is what fires, not a mismatch), and a `done` story
  # under the flag passes (the flag keys on status).
  local a23_plain a23_done
  rd_review "$1"
  cs_run "$1"; a23_plain=$CS_RC
  cs_reset; story_fm story-1 done; put "$CIMPL/sprint-status.yaml" "$ENV1"
  cs_run "$1" --require-done; a23_done=$CS_RC
  if [ "$RDR_RC" -eq 1 ] && grep -q 'NOT DONE — status `review`' <<<"$RDR_OUT" \
     && [ "$a23_plain" -eq 0 ] && [ "$a23_done" -eq 0 ] && grep -q 'PASS — 1 comparison(s)' <<<"$CS_OUT"; then
    res A23 PASS; else res A23 FAIL; fi
}
a_A24() { # the --require-done REMEDY is scoped to `review`
  # Only a `review` story is past gate 3 with its closing writes owed; telling the operator to
  # dispatch the closing writer for any other status (an in-flight story, or an extension status such
  # as `done-pending-liveness` the schema leaves un-enumerated) is a wrong instruction. Every twin is
  # one view, file and yaml agreeing unless the twin says otherwise, each asserted on ITS OWN line:
  #   review                    — exactly one NOT DONE line, exactly one remedy, on that line;
  #   done-pending-liveness, in-progress, in-review (the substring near-miss), review-pending (the
  #   prefix near-miss), Review (the case near-miss) — the line is there, rc 1, it carries the
  #                               no-remedy sentence for ITS status, and no closing-writer remedy;
  #   file `review`, yaml `in-progress` — the branch keys on the YAML status, so no remedy.
  # "No closing-writer remedy" is three tokens, not the one review-branch phrase: a REWORDED remedy on
  # a non-`review` status is the same wrong instruction. The PRESENCE of "prescribes no remedy for
  # `<s>`" keeps the arm from passing a build that simply says nothing. A24 stands down only when NO
  # twin produced any NOT DONE line: the flag never firing, which A23 owns.
  # SEVEN drives, one per status spelling (substring, prefix, case, file/yaml split).
  local a24_rem='dispatch its closing writer' a24_nd=0 a24_ok=1 a24_twin a24_f a24_y a24_line a24_out a24_rc a24_n a24_r
  for a24_twin in review:review done-pending-liveness:done-pending-liveness in-progress:in-progress \
                  in-review:in-review review-pending:review-pending Review:Review review:in-progress; do
    a24_f="${a24_twin%%:*}"; a24_y="${a24_twin##*:}"
    if [ "$a24_twin" = review:review ]; then
      rd_review "$1"; a24_out="$RDR_OUT"; a24_rc=$RDR_RC
    else
      cs_reset
      story_fm story-1 "$a24_f"
      put "$CIMPL/sprint-status.yaml" "sprint: 291
status: in_progress
stories:
  story-291-1:
    file: stories/story-1.md
    status: $a24_y"
      a24_out="$(rte "$1" check-stories --require-done --root "$CS" 2>&1)"; a24_rc=$?
    fi
    a24_n="$(grep -c 'NOT DONE' <<<"$a24_out")" || a24_n=0
    a24_nd=$((a24_nd + a24_n))
    a24_line="$(grep -F "NOT DONE — status \`$a24_y\`" <<<"$a24_out")" || a24_line=''
    if [ "$a24_rc" -ne 1 ] || [ -z "$a24_line" ]; then a24_ok=0; continue; fi
    if [ "$a24_twin" = review:review ]; then
      a24_r="$(grep -oF "$a24_rem" <<<"$a24_out" | wc -l | tr -d ' ')"
      if [ "$a24_n" -ne 1 ] || [ "$a24_r" -ne 1 ] || ! grep -qF "$a24_rem" <<<"$a24_line"; then a24_ok=0; fi
    else
      if ! grep -qF "this check prescribes no remedy for \`$a24_y\`" <<<"$a24_line" \
         || grep -qF "$a24_rem" <<<"$a24_out" \
         || grep -qF 'closing writ' <<<"$a24_out" || grep -qF 'section 3, item 4' <<<"$a24_out"; then a24_ok=0; fi
    fi
  done
  if [ "$a24_nd" -eq 0 ] || [ "$a24_ok" -eq 1 ]; then res A24 PASS; else res A24 FAIL; fi
}

# ===== PART 3 — `deferred_acs`: a `done` story still owing ACs to deploy-validate §4b ============
# Before this field a story that closed `done` at gate-3 with ACs deferred to production read as
# fully closed, and `close` stamped the sprint over it. ONE spelling is accepted — a single-line
# inline list — because this file's line parser reads a block list as '' and a wrapped flow list as
# `[AC5,`; D3/D4 pin that neither is ever read as empty. The seeds are written as the reviewer
# writes them (code-reviewer.md), two views each, and the close arms compare BYTES of both views.

story_layered() {   # <name> <status> <live_ops> <manual_operator>
  printf -- '---\nstatus: %s\nsprint: 291\nlayered_ac_count:\n  unit: 2\n  integration: 0\n  e2e: 0\n  live_ops: %s\n  manual_operator: %s\n---\n\n# story\n' \
    "$2" "$3" "$4" > "$CSTORIES/$1.md"
}
env_one() { # one envelope with story-291-1 done; $1 is the entry's extra field line(s), '' for none
  printf 'sprint: 291\nstatus: in_progress\nstories:\n  story-291-1:\n    file: stories/story-1.md\n    status: done\n%s' "$1"
}
cl_run() {
  CL_OUT="$(rte "$1" close --evidence "fixture" --root "$CS" 2>&1)"
  CL_RC=$?
}

a_D1() { # the inline list parses, is printed as DEFERRED with its ids, and is a state, not a finding
  cs_reset; story_fm story-1 done
  env_one '    deferred_acs: [AC5, AC6]
' > "$CIMPL/sprint-status.yaml"
  env_one '    deferred_acs: [AC6, AC5]  # reviewer order differs
' > "$CPLAN/sprint-status.yaml"
  cs_run "$1"
  if [ "$CS_RC" -eq 0 ] && grep -q 'DEFERRED \[story-291-1\] status `done`, 2 AC(s) .*AC5, AC6' <<<"$CS_OUT" \
     && ! grep -q 'FINDING' <<<"$CS_OUT"; then res D1 PASS; else res D1 FAIL; fi
}
a_D2() { # `[]` in one view and ABSENT in the other are the same value: no finding, no DEFERRED
  cs_reset; story_fm story-1 done
  env_one '    deferred_acs: []
' > "$CIMPL/sprint-status.yaml"
  env_one '' > "$CPLAN/sprint-status.yaml"
  cs_run "$1"
  if [ "$CS_RC" -eq 0 ] && grep -q 'PASS — 2 comparison(s)' <<<"$CS_OUT" \
     && ! grep -q 'DEFERRED\|FINDING' <<<"$CS_OUT"; then res D2 PASS; else res D2 FAIL; fi
}
a_D3() { # the BLOCK form: the line parser hands the field over as ''; read as empty it would report the deferral discharged
  cs_reset; story_fm story-1 done
  env_one '    deferred_acs:
      - AC5
' > "$CIMPL/sprint-status.yaml"
  cs_run "$1"
  if [ "$CS_RC" -eq 1 ] && grep -q 'FINDING \[implementation/story-291-1\] `deferred_acs` is not one single-line inline list: empty value' <<<"$CS_OUT"; then
    res D3 PASS; else res D3 FAIL; fi
}
a_D4() { # a flow list wrapped onto a second line: the parser sees `[AC5,`
  cs_reset; story_fm story-1 done
  env_one '    deferred_acs: [AC5,
      AC6]
' > "$CIMPL/sprint-status.yaml"
  cs_run "$1"
  if [ "$CS_RC" -eq 1 ] && grep -q 'FINDING \[implementation/story-291-1\] `deferred_acs` is not one single-line inline list: `\[AC5,`' <<<"$CS_OUT"; then
    res D4 PASS; else res D4 FAIL; fi
}
a_D5() { # one view owes an AC the other has cleared: `close` would see the deferral from one side
  cs_reset; story_fm story-1 done
  env_one '    deferred_acs: [AC5]
' > "$CIMPL/sprint-status.yaml"
  env_one '    deferred_acs: []
' > "$CPLAN/sprint-status.yaml"
  cs_run "$1"
  if [ "$CS_RC" -eq 1 ] && grep -q 'disagree on `deferred_acs`' <<<"$CS_OUT"; then res D5 PASS; else res D5 FAIL; fi
}
a_D6() { # the writer-forgot REPORT: three stories, the exit code must not move (a REPORT is not a finding)
  cs_reset
  story_layered story-1 done 1 0
  story_layered story-2 done 2 1
  story_layered story-3 done 0 0
  put "$CIMPL/sprint-status.yaml" 'sprint: 291
status: in_progress
stories:
  story-291-1:
    file: stories/story-1.md
    status: done
  story-291-2:
    file: stories/story-2.md
    status: done
    deferred_acs: []
  story-291-3:
    file: stories/story-3.md
    status: done'
  cs_run "$1"
  if [ "$CS_RC" -eq 0 ] && grep -q 'REPORT \[story-291-1\] `done` with 1 live_ops/manual_operator' <<<"$CS_OUT" \
     && [ "$(grep -c 'REPORT \[' <<<"$CS_OUT")" = "1" ]; then res D6 PASS; else res D6 FAIL; fi
}
a_D7() { # `close` REFUSES while an id is owed, and writes NEITHER view (owed id in the PLANNING view only)
  # The planning view is the one the write loop reaches SECOND — so a refusal made inside the loop
  # would already have stamped the implementation view `done`. Both views compared as bytes.
  cs_reset; story_fm story-1 done
  env_one '    deferred_acs: []
' > "$CIMPL/sprint-status.yaml"
  env_one '    deferred_acs: [AC5]
' > "$CPLAN/sprint-status.yaml"
  cp "$CIMPL/sprint-status.yaml" "$CS/impl.before"; cp "$CPLAN/sprint-status.yaml" "$CS/plan.before"
  cl_run "$1"
  if [ "$CL_RC" -eq 3 ] && grep -q 'refusing to close:.*\[planning/story-291-1\] deferred_acs AC5' <<<"$CL_OUT" \
     && cmp -s "$CIMPL/sprint-status.yaml" "$CS/impl.before" \
     && cmp -s "$CPLAN/sprint-status.yaml" "$CS/plan.before"; then res D7 PASS; else res D7 FAIL; fi
}
a_D8() { # a MALFORMED value refuses too (a token that is no AC id), rather than closing over it
  cs_reset; story_fm story-1 done
  env_one '    deferred_acs: [AC5 AC6]
' > "$CIMPL/sprint-status.yaml"
  cp "$CIMPL/sprint-status.yaml" "$CS/impl.before"
  cl_run "$1"
  if [ "$CL_RC" -eq 3 ] && grep -q 'unreadable' <<<"$CL_OUT" \
     && cmp -s "$CIMPL/sprint-status.yaml" "$CS/impl.before"; then res D8 PASS; else res D8 FAIL; fi
}
a_D9() { # cleared (`[]`) and legacy-absent both CLOSE: the refusal is keyed on owed ids, not on the field's presence
  cs_reset; story_fm story-1 done
  env_one '    deferred_acs: []
' > "$CIMPL/sprint-status.yaml"
  env_one '' > "$CPLAN/sprint-status.yaml"
  cl_run "$1"
  if [ "$CL_RC" -eq 0 ] && grep -q '^status: done' "$CIMPL/sprint-status.yaml" \
     && grep -q '^status: done' "$CPLAN/sprint-status.yaml"; then res D9 PASS; else res D9 FAIL; fi
}
# D10/D11 — `deferred_acs` at a NON-FIELD indent, after `status:`. The relative-indent parser keeps
# only lines at the entry's first field indent, so this line was DROPPED: check-stories 0, close 0, the
# sprint stamped over an owed AC. Each is a FINDING in check-stories and a refusal in close with both
# views byte-unchanged. D10 is six spaces under four-space fields, D11 a tab; the second story is a
# clean entry, so a parser that stopped reading at the bad line shows up too.
d_misindent() { # <tool> <D10|D11>
  local d="$2" n csok=0 clok=0
  if [ "$d" = D10 ]; then n='      '; else n="$(printf '\t')"; fi
  cs_reset; story_fm story-1 done; story_fm story-2 done
  printf 'sprint: 291\nstatus: in_progress\nstories:\n  story-291-1:\n    file: stories/story-1.md\n    status: done\n%sdeferred_acs: [AC5]\n  story-291-2:\n    file: stories/story-2.md\n    status: done\n' "$n" \
    > "$CIMPL/sprint-status.yaml"
  cp "$CIMPL/sprint-status.yaml" "$CPLAN/sprint-status.yaml"
  cp "$CIMPL/sprint-status.yaml" "$CS/impl.before"; cp "$CPLAN/sprint-status.yaml" "$CS/plan.before"
  cs_run "$1"
  if [ "$CS_RC" -eq 1 ] \
     && grep -q 'FINDING \[implementation/story-291-1\] `deferred_acs` is not one single-line inline list: `deferred_acs` on line 7 sits at indent' <<<"$CS_OUT" \
     && grep -q 'FINDING \[planning/story-291-1\] `deferred_acs`' <<<"$CS_OUT" \
     && grep -q '2 comparison(s) over 2 entries\|4 comparison(s) over 4 entries' <<<"$CS_OUT"; then csok=1; fi
  cl_run "$1"
  if [ "$CL_RC" -eq 3 ] && grep -q 'refusing to close:.*\[implementation/story-291-1\] `deferred_acs` unreadable' <<<"$CL_OUT" \
     && cmp -s "$CIMPL/sprint-status.yaml" "$CS/impl.before" \
     && cmp -s "$CPLAN/sprint-status.yaml" "$CS/plan.before"; then clok=1; fi
  if [ "$csok$clok" = 11 ]; then res "$d" PASS; else res "$d" FAIL; fi
}
a_D10() { d_misindent "$1" D10; }
a_D11() { d_misindent "$1" D11; }

# J1 — a `done` story whose AC carries `defers_to:` that `deferred_acs` does not list (BL-840). A REPORT in
# writer_forgot's tier: it never moves the exit code, compares AC ids exactly (case-sensitive) and never the CO
# value, and fires only when `deferred_acs` parsed ok. The id list comes from the sibling validator's
# --list-defers, read from the sibling validator beside the tool.
story_defers() { # <name> <live_ops> <CO>: AC4 carries defers_to, AC5 does not
  printf -- '---\nstatus: done\nsprint: 291\nlayered_ac_count:\n  unit: 2\n  live_ops: %s\n  manual_operator: 0\n---\n\n# story\n\n- **AC4 (unit).** thing\n  defers_to: %s\n- **AC5 (unit).** other\n' "$2" "$3" > "$CSTORIES/$1.md"
}
j1_world() { # <tool> <deferred_acs field line(s) or ''> <live_ops> <CO> -> CS_OUT CS_RC, both views alike
  cs_reset; story_defers story-1 "$3" "$4"
  env_one "$2" > "$CIMPL/sprint-status.yaml"
  env_one "$2" > "$CPLAN/sprint-status.yaml"
  cs_run "$1"
}
a_J1() { # AC4 defers, `deferred_acs: []`: J1 names AC4 only (never AC5), and the exit code equals the same world without the defers_to line
  j1_world "$1" '    deferred_acs: []
' 0 CO-S1-x
  local out="$CS_OUT" rc="$CS_RC"
  cs_reset; story_fm story-1 done
  env_one '    deferred_acs: []
' > "$CIMPL/sprint-status.yaml"; cp "$CIMPL/sprint-status.yaml" "$CPLAN/sprint-status.yaml"
  cs_run "$1"
  if [ "$rc" -eq "$CS_RC" ] && [ "$rc" -eq 0 ] \
     && grep -q 'REPORT \[story-291-1\] `done` with 1 AC(s) carrying `defers_to` in story-1.md that `deferred_acs` does not list: AC4 ' <<<"$out" \
     && ! grep -q 'list: AC4, AC5\|AC5 —' <<<"$out" \
     && ! grep -q 'carrying `defers_to`' <<<"$CS_OUT"; then res J1 PASS; else res J1 FAIL; fi
}
a_J1N() { # near-miss: AC4 is listed, so no J1 line
  j1_world "$1" '    deferred_acs: [AC4]
' 0 CO-S1-x
  if [ "$CS_RC" -eq 0 ] && grep -q 'DEFERRED \[story-291-1\]' <<<"$CS_OUT" && ! grep -q 'carrying `defers_to`' <<<"$CS_OUT"; then res J1N PASS; else res J1N FAIL; fi
}
a_J1X() { # near-miss: AC4 is listed and its CO is a different id from J1's other worlds: the join is on the AC id, never the CO
  j1_world "$1" '    deferred_acs: [AC4]
' 0 CO-S1-other
  if [ "$CS_RC" -eq 0 ] && grep -q 'DEFERRED \[story-291-1\]' <<<"$CS_OUT" && ! grep -q 'carrying `defers_to`' <<<"$CS_OUT"; then res J1X PASS; else res J1X FAIL; fi
}
a_J1ABS() { # no `deferred_acs` field: writer_forgot's REPORT only, never J1 (J1 needs a parsed deferred_acs)
  j1_world "$1" '' 1 CO-S1-x
  if [ "$CS_RC" -eq 0 ] && grep -q 'REPORT \[story-291-1\] `done` with 1 live_ops/manual_operator' <<<"$CS_OUT" \
     && ! grep -q 'carrying `defers_to`' <<<"$CS_OUT"; then res J1ABS PASS; else res J1ABS FAIL; fi
}
a_J1CASE() { # `[ac4]` against `AC4`: ids are compared case-sensitively, so J1 still fires
  j1_world "$1" '    deferred_acs: [ac4]
' 0 CO-S1-x
  if [ "$CS_RC" -eq 0 ] && grep -q 'REPORT \[story-291-1\] `done` with 1 AC(s) carrying `defers_to` in story-1.md that `deferred_acs` does not list: AC4 ' <<<"$CS_OUT"; then res J1CASE PASS; else res J1CASE FAIL; fi
}

# ===== PART 4 — `list-stories`: the implementation view's entries, one tab-separated line each ====
# The mode exists so a validator never parses the yaml itself. Every arm is PRESENCE-shaped on
# stdout or on the exit code, so a subject that prints nothing fails L1, L2 and L4 by construction.
# L1 and L2 seed BOTH views identically, so a wrong-view read cannot reach them; L4 is the
# near-miss where the views differ, and only it may die when the wrong view is read.
ls_run() {
  LS_OUT="$(rte "$1" list-stories --root "$CS" 2>"$CS.err")"
  LS_RC=$?
  LS_ERR="$(cat "$CS.err")"
}
TAB="$(printf '\t')"
# L1 — three entries, three lines, key/status/file in yaml order (not sorted: 3 before 1).
a_L1() {
  cs_reset
  put "$CIMPL/sprint-status.yaml" 'sprint: 291
status: in_progress
stories:
  story-291-3:
    file: stories/story-3.md
    status: review
  story-291-1:
    file: stories/story-1.md
    status: done
  story-291-2:
    status: in-progress
    file: stories/story-2.md'
  cp "$CIMPL/sprint-status.yaml" "$CPLAN/sprint-status.yaml"
  ls_run "$1"
  local want="story-291-3${TAB}review${TAB}stories/story-3.md
story-291-1${TAB}done${TAB}stories/story-1.md
story-291-2${TAB}in-progress${TAB}stories/story-2.md"
  if [ "$LS_RC" -eq 0 ] && [ "$LS_OUT" = "$want" ]; then res L1 PASS; else res L1 FAIL; fi
}
# L2 — an entry with no `file:` prints `-` in that column, and its sibling keeps its file.
a_L2() {
  cs_reset
  put "$CIMPL/sprint-status.yaml" 'sprint: 291
status: in_progress
stories:
  story-291-1:
    status: done
  story-291-2:
    file: stories/story-2.md
    status: review'
  cp "$CIMPL/sprint-status.yaml" "$CPLAN/sprint-status.yaml"
  ls_run "$1"
  local want="story-291-1${TAB}done${TAB}-
story-291-2${TAB}review${TAB}stories/story-2.md"
  if [ "$LS_RC" -eq 0 ] && [ "$LS_OUT" = "$want" ]; then res L2 PASS; else res L2 FAIL; fi
}
# L3 — no yaml at all: exit 2, ONE stderr line, nothing on stdout. Never a silent empty 0.
a_L3() {
  cs_reset
  ls_run "$1"
  if [ "$LS_RC" -eq 2 ] && [ -z "$LS_OUT" ] && [ -n "$LS_ERR" ] && [ "${LS_ERR%%$'\n'*}" = "$LS_ERR" ]; then
    res L3 PASS; else res L3 FAIL; fi
}
# L4 — the near-miss: the PLANNING view carries an entry, and a status, the implementation view
# does not. Only the implementation view's two lines may appear.
a_L4() {
  cs_reset
  put "$CIMPL/sprint-status.yaml" 'sprint: 291
status: in_progress
stories:
  story-291-1:
    file: stories/story-1.md
    status: review
  story-291-2:
    file: stories/story-2.md
    status: in-progress'
  put "$CPLAN/sprint-status.yaml" 'sprint: 291
status: in_progress
stories:
  story-291-1:
    file: stories/story-1.md
    status: ready-for-dev
  story-291-2:
    file: stories/story-2.md
    status: ready-for-dev
  story-291-9:
    file: stories/story-9.md
    status: backlog'
  ls_run "$1"
  local want="story-291-1${TAB}review${TAB}stories/story-1.md
story-291-2${TAB}in-progress${TAB}stories/story-2.md"
  if [ "$LS_RC" -eq 0 ] && [ "$LS_OUT" = "$want" ]; then res L4 PASS; else res L4 FAIL; fi
}

# ===== registry: keys (one function each) and the ids they print =================================
ALL_KEYS="P0 P1 P2 P3 TB_preamble TB_empty TB_done6 TB_inprog7 TB_none TB_implpre P5 roll legacy divergent greenroll H8 H9 R10 R11 R12 R12i R12e R12crlf R12leg R13 R13b R14 R15 R16 R17 R18 R19 R20 R21 R22 R22b R23 R24 R24s R24p A13 A14 A15 A16 A17 A18 A19 A20 A21 A22 A23 A24 D1 D2 D3 D4 D5 D6 D7 D8 D9 D10 D11 J1 J1N J1X J1ABS J1CASE L1 L2 L3 L4"
ids_of() { case "$1" in roll) echo "R6a R6b R6c R6d R7" ;; legacy) echo "R7a1 R7a2 R7a3" ;; divergent) echo "R7ac" ;; greenroll) echo "R7b1 R7b2" ;; *) echo "$1" ;; esac; }
ALL_IDS=""
for _k in $ALL_KEYS; do for _i in $(ids_of "$_k"); do ALL_IDS="$ALL_IDS $_i"; done; done
arm() { # <key> <tool>
  case "$1" in
    TB_*) tb_state "$2" "${1#TB_}" ;;
    *)    "a_$1" "$2" ;;
  esac
}
sets_from() { # <RES text> -> PASS_OUT FAIL_OUT, space padded; no forks
  local i v
  PASS_OUT=" "; FAIL_OUT=" "
  while read -r i v; do
    [ -n "$i" ] || continue
    case "$v" in PASS) PASS_OUT="$PASS_OUT$i " ;; FAIL) FAIL_OUT="$FAIL_OUT$i " ;; esac
  done <<<"$1"
}
in_set() { case "$2" in *" $1 "*) return 0 ;; esac; return 1; }

okmsg() { case "$1" in
  P0) echo "--render is non-empty and deterministic" ;;
  P1) echo "greenfield (no canonical) -> 1" ;;
  P2) echo "status: done -> N+1 (rule 3)" ;;
  P3) echo "in-flight -> N (rule 4, a re-plan not a new sprint)" ;;
  P5) echo "copies disagree -> exit 3 HARD_BLOCK (never guesses)" ;;
  R6a) echo "roll freezes the closed sprint byte-faithfully (no-loss)" ;;
  R6b) echo "the freeze lands in the s<N>/ slot, not the pre-migration path a validator blocks on" ;;
  R6c) echo "roll writes the new envelope (sprint 292, in_progress)" ;;
  R6d) echo "round-trip: sprint-id after roll -> 292" ;;
  R7) echo "roll is idempotent (re-run does not re-freeze/destroy)" ;;
  R7a1) echo "a legacy freeze is honoured, not duplicated into the slot (no twin archive)" ;;
  R7a2) echo "the legacy freeze is left byte-untouched" ;;
  R7a3) echo "the roll still completes over a legacy freeze" ;;
  R7ac) echo "control: a freeze that DIFFERS from the canonical -> exit 3" ;;
  R7b1) echo "roll creates the canonical on greenfield (the missing creator)" ;;
  R7b2) echo "greenfield creation mints NO second copy" ;;
  H8) echo "a housekeeping block alone is NOT parsed as sprint 291" ;;
  H9) echo "canonical WITH housekeeping still derives N+1 correctly" ;;
  R10) echo "roll refuses an unclosed sprint (exit 3) — never freezes live state" ;;
  R11) echo "fail-closed on an unreadable schema (never guesses the grammar)" ;;
  R12) echo "BL-938: a BMAD copy in the planning slot is relocated byte-for-byte and the real freeze lands in the slot" ;;
  R12i) echo "BL-938: the same BMAD copy in the implementation slot is relocated (the predicate is per view)" ;;
  R12e) echo "BL-938: the inline-empty development_status: {} form is a BMAD copy too" ;;
  R12crlf) echo "BL-938: a CRLF BMAD copy at mode 0640 is moved with its bytes and mode intact" ;;
  R12leg) echo "BL-938: beside an identical legacy freeze the BMAD copy is relocated and nothing is written into the slot" ;;
  R13) echo "BL-938: a slot file with sprint: AND development_status: is a freeze that differs -> exit 3, nothing written" ;;
  R13b) echo "BL-938: a housekeeping-first slot file with neither key is not BMAD -> exit 3" ;;
  R14) echo "BL-938: a divergent PLANNING freeze -> exit 3 with the implementation view untouched (no half-roll)" ;;
  R15) echo "BL-938: implementation done + planning in_progress -> exit 3, nothing written" ;;
  R16) echo "BL-938: the half-rolled tree is completed by one re-run, and sprint-id then answers 322" ;;
  R17) echo "BL-938: a relocation target with DIFFERENT bytes -> exit 3, nothing written" ;;
  R18) echo "BL-938: a BMAD impl slot beside an unclosed planning view is not relocated before the refusal" ;;
  R19) echo "BL-938: both slots divergent -> one refusal names BOTH paths" ;;
  R20) echo "BL-938: an identical relocation target is kept and the slot copy removed" ;;
  R21) echo "BL-938: a view AHEAD of the target -> exit 3, never rolled backward" ;;
  R22) echo "BL-938: views behind the target that disagree -> exit 3 with rule 5 words" ;;
  R22b) echo "BL-938: a view at the target beside one two behind is not a half-roll -> exit 3 with rule 5 words naming both" ;;
  R23) echo "BL-938: a preamble-only view beside a view still to roll -> exit 1 with the restore text, nothing written" ;;
  R24) echo "BL-938: a BMAD relocation target that is a directory -> exit 3 in phase 1, nothing written" ;;
  R24s) echo "BL-938: a freeze slot that is a directory -> exit 3 in phase 1, nothing written" ;;
  R24p) echo "BL-938: a slot parent s<N> that is a regular file -> exit 3 in phase 1, nothing written" ;;
  A*) echo "$1 consistent-status battery" ;;
  D*) echo "$1 deferred_acs battery" ;;
  J1*) echo "$1 defers_to join battery" ;;
  L*) echo "$1 list-stories battery" ;;
esac; }
badmsg() { case "$1" in
  P0) echo "--render is empty or non-deterministic" ;;
  P1) echo "greenfield did not resolve to 1" ;;
  P2) echo "closed sprint did not resolve to N+1" ;;
  P3) echo "in-flight sprint did not resolve to N" ;;
  P5) echo "disagreeing copies did not HARD_BLOCK with exit 3" ;;
  R6a) echo "roll did not freeze byte-faithfully" ;;
  R6b) echo "freeze destination wrong — the freeze did not land in the s<N>/ slot or the legacy path exists" ;;
  R6c) echo "roll did not write the new envelope" ;;
  R6d) echo "roll does not round-trip" ;;
  R7) echo "re-running roll overwrote the frozen archive — data loss" ;;
  R7a1) echo "roll minted a second archive of sprint 291 beside the legacy one" ;;
  R7a2) echo "roll rewrote the legacy freeze" ;;
  R7a3) echo "roll did not advance the canonical" ;;
  R7ac) echo "a divergent freeze did not HARD_BLOCK — the skip is unconditional" ;;
  R7b1) echo "roll did not create the canonical on greenfield" ;;
  R7b2) echo "greenfield creation minted a planning twin — the two-view drift, seeded fresh" ;;
  H8) echo "housekeeping block parsed AS a sprint envelope — the reference tool's exact collision" ;;
  H9) echo "housekeeping block broke sprint_id derivation" ;;
  R10) echo "roll froze a sprint that was still in flight" ;;
  R11) echo "a corrupt schema did not fail closed" ;;
  R1[2-9]*|R2[0-4]*) echo "$1 (BL-938 roll) failed on the SHIPPING tool: rc=$(cat "$RWD/sprint-status.sh/$1/rc" 2>/dev/null) $(sed -n '1,3p' "$RWD/sprint-status.sh/$1/err" 2>/dev/null | tr '\n' ' ')" ;;
  *) echo "$1 failed on the SHIPPING tool" ;;
esac; }

# ===== the shipping tool: every arm ===============================================================
echo "sprint-status-lifecycle:"
RES=""
for k in $ALL_KEYS; do arm "$k" "$TOOL"; done
sets_from "$RES"; SHIP_PASS="$PASS_OUT"; SHIP_FAIL="$FAIL_OUT"
for i in $ALL_IDS; do
  case "$i" in TB_*) continue ;; esac
  if in_set "$i" "$SHIP_PASS"; then ok "$(okmsg "$i")"
  elif in_set "$i" "$SHIP_FAIL"; then bad "$(badmsg "$i")"
  else bad "$i printed no verdict on the shipping tool — an arm that produced nothing"; fi
done
tb_bad=""
for i in TB_preamble TB_empty TB_done6 TB_inprog7 TB_none TB_implpre; do in_set "$i" "$SHIP_PASS" || tb_bad="$tb_bad $i"; done
if [ -z "$tb_bad" ]; then
  ok "sprint-id is identical with and without archives, and equals the stated answer, for all 6 canonical states (preamble-only, empty and implementation-preamble refuse exit 1)"
else
  bad "sprint-id property broken on the real tool:$TBL_MSG"
fi
cs_bad=""; for i in A13 A14 A15 A16 A17 A18 A19 A20 A21 A22 A23 A24; do in_set "$i" "$SHIP_PASS" || cs_bad="$cs_bad $i"; done
if [ -z "$cs_bad" ]; then ok "check-stories: all 12 assertions pass on the shipping tool"; else bad "check-stories battery failed on the SHIPPING tool:$cs_bad"; fi
# A FAIL-only aggregate stays green over an arm that printed nothing; A24 must be PRESENT.
if in_set A24 "$SHIP_PASS"; then ok "check-stories: A24 reported PASS on the shipping tool"; else bad "check-stories: A24 printed no PASS line on the shipping tool"; fi
ds_bad=""; for i in D1 D2 D3 D4 D5 D6 D7 D8 D9 D10 D11; do in_set "$i" "$SHIP_PASS" || ds_bad="$ds_bad $i"; done
if [ -z "$ds_bad" ]; then ok "deferred_acs: all 11 assertions pass on the shipping tool"; else bad "deferred_acs battery failed on the SHIPPING tool:$ds_bad"; fi
j1_bad=""; for i in J1 J1N J1X J1ABS J1CASE; do in_set "$i" "$SHIP_PASS" || j1_bad="$j1_bad $i"; done
if [ -z "$j1_bad" ]; then ok "defers_to join: all 5 assertions pass on the shipping tool"; else bad "defers_to join battery failed on the SHIPPING tool:$j1_bad"; fi
ls_bad=""; for i in L1 L2 L3 L4; do in_set "$i" "$SHIP_PASS" || ls_bad="$ls_bad $i"; done
if [ -z "$ls_bad" ]; then ok "list-stories: all 4 assertions pass on the shipping tool"; else bad "list-stories battery failed on the SHIPPING tool:$ls_bad"; fi
# The BL-938 receipt reads what the R12-R23 worlds left for the shipping tool; it starts no subject.
bash "$HERE/receipt-bl938.sh" "$RWD/sprint-status.sh" "$SD" > "$WORK/r938.out" 2>&1; r938=$?
case "$r938" in
  0) sed -n '1p' "$WORK/r938.out"; ok "BL-938 receipt: a BMAD slot copy is relocated and frozen over, a divergent planning freeze writes nothing, the half-rolled tree recovers, a preamble view refuses exit 1" ;;
  9) echo "FIXTURE BROKEN: receipt-bl938.sh refused to measure: $(head -1 "$WORK/r938.out")" >&2; exit 2 ;;
  *) bad "BL-938 receipt exited $r938: $(tr '\n' ' ' < "$WORK/r938.out")" ;;
esac

# ===== THE CLI CELLS (cells.decl): the tool as a PROGRAM once per distinct CLI outcome, each compared with the in-process
# call on the same read-only input: stdout, stderr and exit byte for byte. Each cell also asserts its own exit code and a
# line of output, so two runs that both printed nothing cannot read as equivalent.
EQ="$WORK/eq"; mkdir -p "$EQ" || { echo "FIXTURE ERROR: mkdir eq" >&2; exit 2; }
eqv() { # eqv <cell-id> <args...> -> $EQ/<id>.{ip,cl}.{out,err,rc}; 0 when all three agree
  local id="$1"; shift
  rt "$TOOL" "$@" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" bash "$TOOL" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(head -1 "$EQ/$1.ip.out")" "$(head -1 "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(head -1 "$EQ/$1.cl.out")" "$(head -1 "$EQ/$1.cl.err")"; }
reset_tree; put "$IMPL/sprint-status.yaml" 'sprint: 290
status: done'
if eqv cli-sprint-id sprint-id --root "$P" && [ "$(cat "$EQ/cli-sprint-id.cl.rc")" = 0 ] && [ "$(cat "$EQ/cli-sprint-id.cl.out")" = 291 ]; then
  ok "cli-sprint-id: the program answers sprint-id 291 for a closed sprint 290, exit 0, exactly as the in-process call does"
else bad "cli-sprint-id: the program and the in-process call differ, or the outcome is not exit 0 printing 291 ($(eq_twin cli-sprint-id))"; fi
reset_tree; put "$IMPL/sprint-status.yaml" '# preamble only, no sprint key'
if eqv cli-sprint-id-refuse sprint-id --root "$P" && [ "$(cat "$EQ/cli-sprint-id-refuse.cl.rc")" = 1 ] \
   && [ -s "$EQ/cli-sprint-id-refuse.cl.err" ] && [ ! -s "$EQ/cli-sprint-id-refuse.cl.out" ]; then
  ok "cli-sprint-id-refuse: the program refuses a canonical with no sprint key on stderr, exit 1, no id, exactly as the in-process call does"
else bad "cli-sprint-id-refuse: the program and the in-process call differ, or the outcome is not the exit-1 refusal ($(eq_twin cli-sprint-id-refuse))"; fi
if eqv cli-usage && [ -s "$EQ/cli-usage.cl.err" ] && grep -q '^usage: sprint-status.sh' "$EQ/cli-usage.cl.err" && [ "$(cat "$EQ/cli-usage.cl.rc")" != 0 ]; then
  ok "cli-usage: the program prints the usage line on stderr and exits non-zero with no mode, exactly as the in-process call does"
else bad "cli-usage: the program and the in-process call differ, or no usage refusal ($(eq_twin cli-usage))"; fi

# J1 reads its ids through the sibling validator beside the tool.
J1_SIB="$(dirname "$TOOL")/validate-ac-falsifiability.sh"
echo "HERMETIC-CONSUMED core/scripts/validate-ac-falsifiability.sh"
[ -f "$J1_SIB" ] || { echo "FIXTURE ERROR: validate-ac-falsifiability.sh is not beside $TOOL; J1 has no id source" >&2; exit 2; }

echo
report_end sprint-status-lifecycle
