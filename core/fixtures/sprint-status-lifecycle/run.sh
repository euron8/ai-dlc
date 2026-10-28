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
# every arm. A mutant is a copy of the tool; per push it drives only its DECIDING arm(s) plus one
# named TWIN that the measured matrix shows green.
#
# MUTANT MATRIX. "A mutant fails only its own assertion" (.claude/rules/fixture-mutants.md) is a
# test-quality property, measured ONCE for every mutant against EVERY arm and recorded below; per
# push each mutant runs its deciding arm(s) (must flip) and one twin (must stay green). The matrix
# is re-measured whenever an arm or a mutant is added or changed, with the REMEASURE command below.
# A co-tripping cell is folded into the mutant's decides list. Outside its declared decides set, each
# mutant co-trips no other arm, measured at authoring.
# MUTANT-MATRIX 4d-degenerate-pre-change decides=TB_preamble,TB_empty,TB_implpre twins=TB_done6
# MUTANT-MATRIX a16-compared-nothing-exits-0 decides=A16 twins=A13
# MUTANT-MATRIX a17-empty-block-as-finding decides=A17 twins=A13
# MUTANT-MATRIX a14-mismatch-disabled decides=A14 twins=A13
# MUTANT-MATRIX a15-header-reader-removed decides=A15 twins=A13
# MUTANT-MATRIX a18-list-form-as-empty decides=A18 twins=A13
# MUTANT-MATRIX a19-unresolvable-skipped decides=A19 twins=A13
# MUTANT-MATRIX a20-duplicate-detection-removed decides=A20 twins=A13
# MUTANT-MATRIX a21-cross-view-removed decides=A21 twins=A13
# MUTANT-MATRIX a22-glob-prefix-widened decides=A22 twins=A13
# MUTANT-MATRIX a23-require-done-never-fires decides=A23 twins=A13
# MUTANT-MATRIX a24-remedy-unscoped decides=A24 twins=A13
# MUTANT-MATRIX a24-remedy-substring decides=A24 twins=A13
# MUTANT-MATRIX a24-remedy-deleted decides=A24 twins=A13
# MUTANT-MATRIX a24-remedy-prefix decides=A24 twins=A13
# MUTANT-MATRIX a24-remedy-case-folded decides=A24 twins=A13
# MUTANT-MATRIX a24-remedy-reworded decides=A24 twins=A13
# MUTANT-MATRIX a24-closing-writes-appended decides=A24 twins=A13
# MUTANT-MATRIX a24-section-cite-appended decides=A24 twins=A13
# MUTANT-MATRIX d1-owed-ids-never-printed decides=D1 twins=D2
# MUTANT-MATRIX d2-absent-and-empty-differ decides=D2 twins=D1
# MUTANT-MATRIX d3-block-form-read-as-empty decides=D3 twins=D4
# MUTANT-MATRIX d4-unclosed-bracket-accepted decides=D4 twins=D3
# MUTANT-MATRIX d5-cross-view-join-removed decides=D5 twins=D2
# MUTANT-MATRIX d6-writer-forgot-report-removed decides=D6 twins=D1
# MUTANT-MATRIX d7-refusal-reads-first-view-only decides=D7 twins=D9
# MUTANT-MATRIX d8-close-skips-malformed decides=D8,D10,D11 twins=D9
# MUTANT-MATRIX d9-close-refuses-on-empty decides=D9 twins=D7
# MUTANT-MATRIX d10-d11-misindent-dropped-again decides=D10,D11 twins=D9
# MUTANT-MATRIX d10-only-tab-caught decides=D10 twins=D11
# MUTANT-MATRIX d11-only-deeper-spaces-caught decides=D11 twins=D10
# MUTANT-MATRIX-REMEASURE bash core/fixtures/sprint-status-lifecycle/run.sh --matrix
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"
echo "HERMETIC-CONSUMED core/scripts/sprint-status.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
# shellcheck source=/dev/null
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

# --matrix is an ARGV flag (never an env var, never via hermetic-run.sh): it replaces the per-push
# mutant stage with the full mutant x arm matrix. A plain run executes no matrix-only cell.
MATRIX=0; [ "${1:-}" = "--matrix" ] && MATRIX=1
MX_FULL_RUNS=0     # incremented ONLY by matrix-only cells; a plain run must leave it at 0
if [ "$MATRIX" = 1 ]; then echo "MODE FULL (--matrix)"; else echo "MODE PUSH"; fi

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
rt() { local t="$1"; shift; if [ "$t" = "$TOOL" ]; then bash "$t" "$@"; else AI_DLC_SPRINT_STATUS_SCHEMA="$SCHEMA" bash "$t" "$@"; fi; }
rte() { local t="$1"; shift; AI_DLC_SPRINT_STATUS_SCHEMA="$SCHEMA" bash "$t" "$@"; }
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
  # of them a mutant broke.
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
# seeded under only one, the arm also fails whenever a mutant changes WHICH spelling the writer
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
  if AI_DLC_SPRINT_STATUS_SCHEMA="$WORK/corrupt.json" bash "$1" sprint-id --root "$P" >/dev/null 2>&1; then res R11 FAIL; else res R11 PASS; fi
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
  # Its two near-misses ride in the same arm, because the mutant must flip THIS id and no other: the
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
  # SEVEN drives, none cuttable: each of the eight A24 mutants keys on a DIFFERENT status spelling
  # (substring, prefix, case, file/yaml split), so no subset of the shapes decides them all.
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

# ===== registry: keys (one function each) and the ids they print =================================
ALL_KEYS="P0 P1 P2 P3 TB_preamble TB_empty TB_done6 TB_inprog7 TB_none TB_implpre P5 roll legacy divergent greenroll H8 H9 R10 R11 A13 A14 A15 A16 A17 A18 A19 A20 A21 A22 A23 A24 D1 D2 D3 D4 D5 D6 D7 D8 D9 D10 D11"
ids_of() { case "$1" in roll) echo "R6a R6b R6c R6d R7" ;; legacy) echo "R7a1 R7a2 R7a3" ;; divergent) echo "R7ac" ;; greenroll) echo "R7b1 R7b2" ;; *) echo "$1" ;; esac; }
ALL_IDS=""; ID_KEY=" "
for _k in $ALL_KEYS; do for _i in $(ids_of "$_k"); do ALL_IDS="$ALL_IDS $_i"; ID_KEY="$ID_KEY$_i:$_k "; done; done
key_of() { local e; for e in $ID_KEY; do [ "${e%%:*}" = "$1" ] && { printf '%s' "${e#*:}"; return 0; }; done; return 1; }
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
  H8) echo "MUTANT: a housekeeping block alone is NOT parsed as sprint 291" ;;
  H9) echo "MUTANT: canonical WITH housekeeping still derives N+1 correctly" ;;
  R10) echo "roll refuses an unclosed sprint (exit 3) — never freezes live state" ;;
  R11) echo "fail-closed on an unreadable schema (never guesses the grammar)" ;;
  A*) echo "$1 consistent-status battery" ;;
  D*) echo "$1 deferred_acs battery" ;;
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

# ===== mutants ====================================================================================
# Each is a COPY (never an in-place edit), guarded by `cmp -s` so a sed that matched nothing cannot
# pass as a mutation. Name | decides arms | twin arm | sed program. The decides list holds every arm
# the measured matrix shows tripping; the twin is an arm the matrix shows green that the mutant could
# plausibly co-trip (the same branch of the tool).
MN=(); MD=(); MT=(); MP=(); NM=0
defm() { MN[$NM]="$1"; MD[$NM]="$2"; MT[$NM]="$3"; MP[$NM]="$4"; NM=$((NM+1)); }

DMI='            if dm is not None and dm.group(2) == "deferred_acs" and indent != field_indent:$'

# 4d: the control that the property table CAN FAIL. A copy whose degenerate branch is replaced by the
# PRE-CHANGE behaviour (max frozen archive + 1, else 1), built as a copy and guarded with cmp -s so an
# anchor that matched nothing cannot pass as a mutation (a sandbox has no history, so this does not
# depend on `git show`). It must break the preamble-only row: 291 with archives, 1 without.
defm 4d-degenerate-pre-change TB_preamble,TB_empty,TB_implpre TB_done6 @py4d
# A16: collapse "compared nothing" into a pass. The single most important mutation here.
defm a16-compared-nothing-exits-0 A16 A13 's/^        return 4$/        return 0/'
# A17: treat an empty `stories:` block as a content-bearing one, so `roll` output reports a finding.
defm a17-empty-block-as-finding A17 A13 's/return ("no-entries" if content else "empty", \[\])/return ("no-entries", [])/'
# A14: never report a mismatch.
defm a14-mismatch-disabled A14 A13 's/            if fstatus != ystatus:/            if False:/'
# A15: drop the `**Status:**` fallback, so a file with no frontmatter yields nothing.
defm a15-header-reader-removed A15 A13 's/^    m = HDR_STATUS_RE.search(text)$/    m = None/'
# A18: report a keyless block as empty instead of as a finding.
defm a18-list-form-as-empty A18 A13 's/^    if entries:$/    if True:/'
# A19: skip an entry whose file will not resolve.
defm a19-unresolvable-skipped A19 A13 's/^            if resolved is None:$/            if False and resolved is None:/'
# A20: stop detecting a repeated key.
defm a20-duplicate-detection-removed A20 A13 's/^            if key in seen:$/            if False:/'
# A21: drop the cross-view comparison.
defm a21-cross-view-removed A21 A13 's/^        if len(vals) > 1 and len(set(vals.values())) > 1:$/        if False:/'
# A22: widen the index glob to `<stem>*`, the collision that compares story-1 against story-10.
defm a22-glob-prefix-widened A22 A13 's/stories.glob(stem + "-\*.md")/stories.glob(stem + "*.md")/'
# A23: the --require-done branch disabled, so a story past gate 3 still `review` deploys.
defm a23-require-done-never-fires A23 A13 's/^            if os.environ.get("REQUIRE_DONE") and ystatus != "done":$/            if False:/'
# A24: the closing-writer remedy given for every non-`done` status.
defm a24-remedy-unscoped A24 A13 's/^                if ystatus == "review":$/                if True:/'
# A24: the remedy keyed on a substring, so `in-review` is told to dispatch a closing writer.
defm a24-remedy-substring A24 A13 's/^                if ystatus == "review":$/                if "review" in ystatus:/'
# A24: the remedy deleted from the `review` branch too, so no status is ever told what to do.
defm a24-remedy-deleted A24 A13 's/writes: dispatch its closing writer (implementation.md section 3, "/writes: bring it to done ("/'
# A24: the remedy keyed on a prefix, so `review-pending` is told to dispatch a closing writer.
defm a24-remedy-prefix A24 A13 's/^                if ystatus == "review":$/                if ystatus.startswith("review"):/'
# A24: the remedy keyed case-insensitively, so `Review` is told to dispatch a closing writer.
defm a24-remedy-case-folded A24 A13 's/^                if ystatus == "review":$/                if ystatus.lower() == "review":/'
# A24: the remedy REWORDED onto the else branch in place of the no-remedy sentence, so the exact
# review-branch phrase is absent (killed by the presence conjunct).
defm a24-remedy-reworded A24 A13 's/^                                    "prescribes no remedy for `%s`: bring the story to `done` under "$/                                    "owes its closing writes (implementation.md section 3, item 4) for `%s`: bring it to `done` under "/'
# A24: the no-remedy sentence KEPT and a closing-writes remedy appended, so presence holds and only
# the `closing writ` absence can kill it.
defm a24-closing-writes-appended A24 A13 's/^                                    "the step or extension that defines `%s`, then re-run."$/                                    "the step or extension that defines `%s`, or finish its closing writes, then re-run."/'
# A24: the same, citing only the section, so only the `section 3, item 4` absence can kill it.
defm a24-section-cite-appended A24 A13 's/^                                    "the step or extension that defines `%s`, then re-run."$/                                    "the step or extension that defines `%s` (implementation.md section 3, item 4), then re-run."/'
defm d1-owed-ids-never-printed D1 D2 's/^                if dids:$/                if False:/'
defm d2-absent-and-empty-differ D2 D1 's/deferred_view.setdefault(key, {})\[view\] = ", ".join(sorted(dids))/deferred_view.setdefault(key, {})[view] = dstate + ", ".join(sorted(dids))/'
defm d3-block-form-read-as-empty D3 D4 's/^        return ("malformed", "empty value/        return ("ok", []) or ("malformed", "empty value/'
defm d4-unclosed-bracket-accepted D4 D3 's/if not (v.startswith("\[") and v.endswith("\]")):/if not v.startswith("["):/'
defm d5-cross-view-join-removed D5 D2 's/^        if len(set(vals.values())) > 1:$/        if False:/'
defm d6-writer-forgot-report-removed D6 D1 's/^                if owed_n:$/                if False:/'
# D7: the pre-write scan reads only the FIRST view — the shape of a refusal made inside the write
# loop, which has stamped the implementation view before it reads the planning one.
defm d7-refusal-reads-first-view-only D7 D9 '/^    owed = \[\]$/,/^    if owed:$/s/in existing:$/in existing[:1]:/'
# D8 owns D10 and D11's CLOSE half too, by design rather than entanglement: a misindented
# `deferred_acs` reaches close as a malformed value, so skipping malformed values in close closes
# over it as well. The parser guard D10/D11 exist for is isolated by their own three mutants below.
defm d8-close-skips-malformed D8,D10,D11 D9 's/^            if state == "malformed":$/            if False:/'
defm d9-close-refuses-on-empty D9 D7 's/^            elif state == "ok" and ids:$/            elif True:/'
# D10/D11: the misindented-key guard. The full revert restores the drop and must fail both; the two
# partial fixes each handle one indent form, and each must fail only the other form's cell.
defm d10-d11-misindent-dropped-again D10,D11 D9 "s/^${DMI}/            if False:/"
defm d10-only-tab-caught D10 D11 "s/^\\(${DMI%:\$}\\):\$/\\1 and \"\\\\t\" in dm.group(1):/"
defm d11-only-deeper-spaces-caught D11 D10 "s/^\\(${DMI%:\$}\\):\$/\\1 and \"\\\\t\" not in dm.group(1):/"

MUT="$WORK/mut"; mkdir -p "$MUT"
mk_4d() { # the PRE-CHANGE behaviour: the degenerate branch returns max frozen archive + 1, else 1
  cp "$TOOL" "$1"
  python3 - "$1" <<'PYEOF'
import sys
p = sys.argv[1]
t = open(p).read()
anchor = "    degenerate = sorted(v for v, r in seen.items() if r[0] is None)\n"
ins = anchor + (
    "    if degenerate:\n"
    "        import re as _re\n"
    "        ns = []\n"
    "        for _v in VIEWS:\n"
    "            _b = VIEWS[_v].parent\n"
    "            for _p in list(_b.glob('s*/sprint-status.yaml')) + list(_b.glob('sprint-status/sprint-*.yaml')):\n"
    "                _m = _re.search(r'(\\d+)', _p.parent.name if _p.name == 'sprint-status.yaml' else _p.stem)\n"
    "                if _m:\n"
    "                    ns.append(int(_m.group(1)))\n"
    "        return (max(ns) + 1) if ns else 1\n")
if t.count(anchor) == 1:
    open(p, "w").write(t.replace(anchor, ins))
PYEOF
}
# build every mutant copy once; a copy that did not apply is a FAIL, never a silent skip
MUT_OK=" "
mut_i=0
while [ "$mut_i" -lt "$NM" ]; do
  _m="$MUT/${MN[$mut_i]}.sh"
  if [ "${MP[$mut_i]}" = "@py4d" ]; then mk_4d "$_m"; else sed "${MP[$mut_i]}" "$TOOL" > "$_m" 2>/dev/null; fi
  if cmp -s "$TOOL" "$_m"; then
    bad "FIXTURE BROKEN — MUTANT ${MN[$mut_i]} changed nothing; the mutation never happened"
  else
    MUT_OK="$MUT_OK${MN[$mut_i]} "
  fi
  mut_i=$((mut_i+1))
done

# --- Unmutated control -------------------------------------------------------
# A copy beside the mutants, mutated not at all. If the harness itself breaks a copy — a resolver
# that only works in core/scripts/, a schema it cannot find — every mutant "passes" for a reason that
# has nothing to do with its mutation. Per push the control drives exactly the arms the mutants
# drive (their decides and twins); under --matrix it drives all of them.
CTRL="$WORK/mutant-control.sh"
cp "$TOOL" "$CTRL"
want_keys=" "
if [ "$MATRIX" = 1 ]; then want_keys=" $ALL_KEYS "; else
  mut_i=0
  while [ "$mut_i" -lt "$NM" ]; do
    for _a in ${MD[$mut_i]//,/ } ${MT[$mut_i]//,/ }; do
      _k="$(key_of "$_a")" || { bad "FIXTURE BROKEN — mutant ${MN[$mut_i]} names unknown arm $_a"; continue; }
      case "$want_keys" in *" $_k "*) ;; *) want_keys="$want_keys$_k " ;; esac
    done
    mut_i=$((mut_i+1))
  done
fi
RES=""
for k in $ALL_KEYS; do case "$want_keys" in *" $k "*) arm "$k" "$CTRL" ;; esac; done
sets_from "$RES"; CTRL_PASS="$PASS_OUT"; CTRL_FAIL="$FAIL_OUT"
if [ "$CTRL_FAIL" = " " ] && [ "$CTRL_PASS" != " " ]; then
  ok "CONTROL: an unmutated copy beside the mutants passes every arm the mutants drive"
else
  bad "CONTROL: an unmutated copy failed [$CTRL_FAIL] — the mutant harness, not the mutations, is what those mutants proved"
fi

base_ok() { in_set "$1" "$SHIP_PASS" && in_set "$1" "$CTRL_PASS"; } # the arm passed unmutated, in THIS run, on both the shipping tool and the copy

mut_witness() { # <mutant> -> 0 when the mutant's extra observable holds
  case "$1" in
    4d-degenerate-pre-change) [ "$TBWA_preamble" = "291|0" ] && [ "$TBWN_preamble" = "1|0" ] ;;   # preamble-only: 291 with archives, 1 without
    *) return 0 ;;
  esac
}

join_set() { local o="" x; for x in "$@"; do o="$o,$x"; done; printf '%s' "${o#,}"; }

if [ "$MATRIX" = 1 ]; then
  # FULL MATRIX: every mutant driven against EVERY arm; every cell printed, 1 = the arm FAILS under
  # the mutant. Row format: MATRIX <mutant> decides=<declared> cells=<id:0|1,...> tripped=[..] declared=<match|DIFFERS>.
  mut_i=0
  while [ "$mut_i" -lt "$NM" ]; do
    n="${MN[$mut_i]}"
    case "$MUT_OK" in *" $n "*) ;; *) mut_i=$((mut_i+1)); continue ;; esac
    RES=""; MX_FULL_RUNS=$((MX_FULL_RUNS + 1))
    for k in $ALL_KEYS; do arm "$k" "$MUT/$n.sh"; done
    sets_from "$RES"
    cells=""; tripped=""
    for i in $ALL_IDS; do
      if in_set "$i" "$FAIL_OUT"; then cells="$cells,$i:1"; tripped="$tripped $i"; else cells="$cells,$i:0"; fi
    done
    decl="$(printf '%s' " ${MD[$mut_i]//,/ } " | tr ' ' '\n' | grep . | sort | tr '\n' ' ')"
    meas="$(printf '%s' "$tripped" | tr ' ' '\n' | grep . | sort | tr '\n' ' ')"
    st=match; [ "$decl" = "$meas" ] || st=DIFFERS
    tw=green; for _t in ${MT[$mut_i]//,/ }; do in_set "$_t" "$FAIL_OUT" && tw=TRIPPED; done
    printf 'MATRIX %s decides=%s cells=%s tripped=[%s] declared=%s twins=%s\n' "$n" "${MD[$mut_i]}" "${cells#,}" "$(join_set $tripped)" "$st" "$tw"
    mut_i=$((mut_i+1))
  done
else
  # PER PUSH: each mutant drives its DECIDING arm(s) and its measured-green TWIN only.
  mut_i=0
  while [ "$mut_i" -lt "$NM" ]; do
    n="${MN[$mut_i]}"
    case "$MUT_OK" in *" $n "*) ;; *) mut_i=$((mut_i+1)); continue ;; esac
    dec=" ${MD[$mut_i]//,/ } "; twn=" ${MT[$mut_i]//,/ } "
    flag=1
    for a in $dec $twn; do base_ok "$a" || flag=0; done
    keys=" "
    for a in $twn $dec; do _k="$(key_of "$a")"; case "$keys" in *" $_k "*) ;; *) keys="$keys$_k " ;; esac; done
    RES=""
    for k in $keys; do arm "$k" "$MUT/$n.sh"; done
    sets_from "$RES"
    wrong=""
    for a in $dec; do in_set "$a" "$FAIL_OUT" || wrong="$wrong $a-did-not-flip"; done
    for i in $FAIL_OUT; do case "$dec" in *" $i "*) ;; *) wrong="$wrong $i-tripped-outside-decides" ;; esac; done
    for a in $twn; do in_set "$a" "$PASS_OUT" || wrong="$wrong $a-twin-not-green"; done
    if [ -n "$wrong" ]; then
      if [ "$flag" = 1 ]; then bad "MUTANT $n scored [$wrong ], wanted decides=[${MD[$mut_i]}] and twin=[${MT[$mut_i]}] green"; else need_base "$flag" "$n" || true; fi
    elif ! mut_witness "$n"; then
      bad "MUTANT $n flipped its arm but its witness did not hold (archives='${TBWA_preamble:-}' none='${TBWN_preamble:-}')"
    else
      mutant_killed "$flag" "$n" "MUTANT $n dies on [${MD[$mut_i]}]; twin [${MT[$mut_i]}] stays green"
    fi
    mut_i=$((mut_i+1))
  done
  if [ "$MX_FULL_RUNS" -eq 0 ]; then ok "a plain run executed no matrix-only cell (MX_FULL_RUNS=0)"
  else bad "a plain run executed $MX_FULL_RUNS matrix-only cell(s)"; fi
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "sprint-status-lifecycle: PASS"
  exit 0
fi
echo "sprint-status-lifecycle: FAIL ($fails)"
exit 1
