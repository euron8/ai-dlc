#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# mandatory-rules-snapshot-position — the snapshot that OUTLIVES a sprint must not say the
# sprint is still pending deploy work, and validate-mandatory-rules.sh Check 8 is what says so
# before the retro commits.
#
# THE DEFECT THIS EXISTS TO CATCH. `_bmad-output/pipeline-snapshot.md`'s `## Pipeline Position`
# fields are written by gate-validation.md Check 14 at each GATE passage, and the last gate a
# sprint runs is `sprint-review`. `deploy-validate.md` and `retro.md` run no gate-validation.md
# gate, so nothing advanced the position past `deploy-validate.md`: once the retro merged, the
# last thing on disk said `current_step_file: deploy-validate.md` and a later session read a
# SHIPPED sprint as pending deploy work. Measured on the reference consumer at sprint 310 —
# the retro squash carries a snapshot at `deploy-validate.md` while the sprint-status envelope
# in that same commit reads `status: done`.
#
# CHECK 8 RUNS AT retro.md STEP 5c, BEFORE THE MERGE, so its subject is deploy-validate.md's
# routing write (position advanced to `retro.md`) and NOT retro.md's own terminal write, which
# happens at Step 8 after this gate. That is why arm (a) demands the bare value `retro.md` and
# no arm here asserts anything about a closed-sprint spelling.
#
# WHY THE SKIP ARMS ARE HALF THIS FILE. Three inputs are "cannot check" rather than "wrong":
# no snapshot at all, a snapshot carrying no `current_step_file:` field under a
# `## Pipeline Position` section, and a field whose value names no step file. The reference
# consumer's own archive holds ten of that third kind — `none` (4), `CLOSED` (4), `STOP` (2) —
# hand-written terminal spellings. A check that FAILED those would block a retro on a snapshot
# format predating the field, which is a gate that can never pass rather than a gate. Each of
# the three has its own arm asserting the SKIP is counted in the summary line, because a skip
# that does not reach the accounting is the sibling fixture's whole subject.
#
# WHY THE SPELLING ARMS ARE SEEDED FROM THE PRODUCER, NEVER FROM THE EXTRACTOR. The consumer
# does not write a bare value. MEASURED over all 510 historical revisions of its
# `_bmad-output/pipeline-snapshot.md`: a strict `current_step_file:` key resolves on 167, the
# key alternation `core/hooks/ai-dlc-recover.sh:72` publishes resolves on 496, and the dominant
# spelling the strict key cannot see is `- **Current step file:** deploy-validate.md` — the
# DEFECT itself. The archive also holds a backtick-wrapped KEY, a backticked value, trailing
# em-dash prose and a fully qualified `.claude/skills/ai-dlc/steps/` path. Assertion 5 drives
# all six real PASS spellings and both real FAIL spellings against the shipping validator, so a
# narrowing of the grammar cannot pass this file.
#
# WHY ARM (f) IS THE ONE THAT MATTERS FOR `widened`. Whole-file matching is the obvious wrong
# implementation, and the seed that kills it must sit where the real ones do: 31 revisions carry
# `current_step_file: deploy-validate.md` with `retro.md` named in the Pipeline Position
# section's OWN prose a few lines below. Arm (f) is that shape. A seed that put `retro.md` in
# Recent Activity would be killed by the section anchor alone and would say nothing about a
# grammar that reads the whole section.
#
# CHECKS 1, 2 AND 4 ARE DRIVEN THROUGH STUBBED SIBLINGS, as in the sibling fixtures: this
# fixture's subject is Check 8, and the contract those three publish is an exit code. The
# unmutated CONTROL battery proves the stubs are live, and every arm is PRESENCE-shaped — each
# demands a `  CHECK 8: ` verdict word parsed out of the output — so a subject that emits
# nothing scores NONE and fails every arm rather than passing any.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
# ROOT AT THE FIXTURE'S OWN LOCATION — three levels up is the project root in BOTH layouts
# (core/fixtures/<name>/ here, tests/fixtures/<name>/ on a consumer), with the distribution and
# consumer toolchain candidates named side by side. NOT a walk up for `VERSION`: install.sh
# ships no VERSION file, a consumer's stamp is `.claude/.ai-dlc-version`, and a shipping fixture
# that walked for VERSION would exit 2 on every consumer it reached and refuse the push that
# landed it. I106 fails this repo's push on that walk.
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if   [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-mandatory-rules.sh" ]; then
  VMR="$ROOT/core/scripts/validate-mandatory-rules.sh"
  VAA="$ROOT/core/scripts/validate-audit-anchors.sh"
  SS="$ROOT/core/scripts/sprint-status.sh"
  ANCHOR_SCHEMA="$ROOT/core/schemas/audit-anchors.json"
  STATUS_SCHEMA="$ROOT/core/schemas/sprint-status.json"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/validate-mandatory-rules.sh" ]; then
  VMR="$ROOT/scripts/ai-dlc/validate-mandatory-rules.sh"
  VAA="$ROOT/scripts/ai-dlc/validate-audit-anchors.sh"
  SS="$ROOT/scripts/ai-dlc/sprint-status.sh"
  ANCHOR_SCHEMA="$ROOT/.claude/schemas/audit-anchors.json"
  STATUS_SCHEMA="$ROOT/.claude/schemas/sprint-status.json"
else
  echo "FIXTURE ERROR: validate-mandatory-rules.sh not found in either layout" >&2
  exit 2
fi
for f in "$VMR" "$VAA" "$SS" "$ANCHOR_SCHEMA" "$STATUS_SCHEMA"; do
  [ -f "$f" ] || { echo "FIXTURE ERROR: required file not found: $f" >&2; exit 2; }
done
command -v git >/dev/null 2>&1 || { echo "FIXTURE ERROR: git not on PATH" >&2; exit 2; }
# Hermeticity (I10/I87): a fixture inheriting the operator's AI_DLC_* tunables tests the CONFIG.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
asserted=0
ok()  { printf '  ok    %s\n' "$1"; asserted=$((asserted+1)); }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserted=$((asserted+1)); }

echo "mandatory-rules-snapshot-position:"

# ============================================================================
# THE PROJECT TREE. One git repo shaped so that with every OTHER input present checks 1-7 run
# and pass, leaving Check 8 as the only thing any arm below moves. `schemas/` sits beside the
# toolchain dir because validate-audit-anchors.sh and Check 6 both resolve their schema at
# $SCRIPT_DIR/../schemas — the relative shape both shipped layouts have.
# ============================================================================
mkdir -p "$WORK/schemas" "$WORK/proj/_bmad-output/implementation-artifacts"
cp "$ANCHOR_SCHEMA" "$WORK/schemas/audit-anchors.json"
cp "$STATUS_SCHEMA" "$WORK/schemas/sprint-status.json"

P="$WORK/proj"
export AI_DLC_SPRINT_STATUS_SCHEMA="$STATUS_SCHEMA"
bash "$SS" roll  --sprint 900 --intensity full --root "$P" >/dev/null 2>&1
bash "$SS" close --evidence "fixture: PR merged, deploy green, smoke pass" --root "$P" >/dev/null 2>&1
[ -f "$P/_bmad-output/implementation-artifacts/sprint-status.yaml" ] \
  || { echo "FIXTURE ERROR: sprint-status.sh did not write the envelope Check 3 reads" >&2; exit 2; }
unset AI_DLC_SPRINT_STATUS_SCHEMA

git -c init.defaultBranch=main init -q "$P" 2>/dev/null \
  || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }
g() { git -C "$P" "$@"; }
g config user.email f@example.com
g config user.name Fixture
g config commit.gpgsign false

mkdir -p "$P/_bmad-output/planning-artifacts/s900/stories"
printf '# Story 900-1\n\n## Dev Agent Record\n\ndev (delegated) implemented this.\n' \
  > "$P/_bmad-output/planning-artifacts/s900/stories/story-1-fixture.md"
g add -A && g commit -q -m "prior sprint boundary"
PRIOR_SHA="$(g rev-parse HEAD)"

mkdir -p "$P/web/src"; echo "console.log('ui')" > "$P/web/src/app.js"
g add -A && g commit -q -m "Sprint 900 web change"
# Check 7 reads origin/main. No remote here, so the ref is minted at the trunk commit the retro
# branch is cut from: Check 7 runs its live PASS path and every arm below stays about Check 8.
g update-ref refs/remotes/origin/main HEAD
g checkout -q -b ai-dlc/retro/sprint-900

printf '## Gate Log: Sprint 900\n\n| Gate | Result | Notes |\n|------|--------|-------|\n| Deploy Status Report | PASS | USER-CONFIRMED visual verification captured |\n' \
  > "$P/_bmad-output/implementation-artifacts/gate-log.md"
printf -- '- sprint: 899\n  sha: %s\n- sprint: 900\n  sha: <PENDING-S900-RETRO>\n' "$PRIOR_SHA" \
  > "$P/_bmad-output/audit-anchors.md"
printf '# Validation Cycle Log\n\n- sprint 900: three cycles\n' \
  > "$P/_bmad-output/validation-cycle-log.md"

SNAP="$P/_bmad-output/pipeline-snapshot.md"

# ============================================================================
# THE SNAPSHOT WORLDS. Each is a WHOLE snapshot file written from scratch — a world that only
# edited the position line would leave the previous world's other sections on disk, and the next
# arm would then read a shape nobody seeded.
#
# `last_completed_step_file` is the schema's field name (gate-validation.md's Check 14 section
# names it); the seeds spell it as the producer does so this file cannot teach a wrong one.
# ============================================================================
snap_none() { rm -f "$SNAP"; }

# A snapshot whose Pipeline Position carries <1> VERBATIM as its position line — the whole line,
# key spelling included, so an arm can seed a real consumer spelling rather than a value this
# file invented. <2>, when given, is an extra line INSIDE the same section: the shape 31 real
# revisions carry, and the only thing a section-wide grammar reads differently.
snap_line() { # snap_line <verbatim-position-line> [extra-line-in-the-same-section]
  {
    printf '# Pipeline Snapshot\n\n## Pipeline Position\n'
    printf -- '- pipeline_variant: sprint\n'
    printf '%s\n' "$1"
    [ -n "${2:-}" ] && printf '%s\n' "$2"
    printf -- '- last_completed_step_file: deploy-validate.md\n'
    printf -- '- last_gate_passed: sprint-review — Sprint 900\n'
    printf -- '- git_branch: ai-dlc/retro/sprint-900\n'
    printf '\n## Sprint Context\n- sprint_id: 900\n'
    printf '\n## Recent Activity\n- deploy-validate.md production checkpoint validated.\n'
    printf '\n## Open Items\n- none\n'
  } > "$SNAP"
}

# The canonical spelling, for the arms whose subject is not the spelling.
snap_at() { snap_line "- current_step_file: $1" "${2:-}"; }

# A snapshot with the section but NO current_step_file field: the older format.
snap_nofield() {
  {
    printf '# Pipeline Snapshot\n\n## Pipeline Position\n'
    printf -- '- pipeline_variant: sprint\n'
    printf -- '- last_gate_passed: sprint-review — Sprint 900\n'
    printf '\n## Recent Activity\n- retro.md is where this sprint is headed.\n'
  } > "$SNAP"
}

# ============================================================================
# A toolchain dir per script under test: the real validator plus the three siblings whose
# published contract is an exit code, plus the real audit-anchor resolver Check 5 needs.
# ============================================================================
toolchain() { # <dir> <script-to-install-as-validate-mandatory-rules.sh>
  mkdir -p "$1"
  cp "$2" "$1/validate-mandatory-rules.sh"
  cp "$VAA" "$1/validate-audit-anchors.sh"
  printf '#!/bin/sh\nexit 0\n' > "$1/validate-cycle-commits.sh"
  printf '#!/bin/sh\nexit 0\n' > "$1/validate-retro-evidence.sh"
  printf '#!/bin/sh\nexit 0\n' > "$1/validate-retro-prereq.sh"
  chmod +x "$1"/*.sh
}

# battery <toolchain-dir> -> six space-separated tokens, one per arm.
#
# TOKEN: <arm>:<verdict>/<names-the-value>/<summary-class>/<rc>
#   verdict  PASS | FAIL | SKIP | NONE (no CHECK 8 line at all) | OTHER[<line>]
#   names    d if the CHECK 8 line names `deploy-validate.md`, else -
#   summary  all8 | skip8 (the check-8 skip sentence) | nosumm | other[<sentence>]
# Every field is a fact the check EMITS, so a subject printing nothing scores NONE/-/nosumm and
# fails every arm by construction; silence cannot score as a kill anywhere in this file.
SKIP8_SUMMARY="Sprint 900: 7 of 8 checks verified; 1 SKIPPED (check 8)."
ALL8_SUMMARY="Sprint 900: all 8 checks passed"

battery() {
  local D="$1" out rc t=""
  run()  { out="$( cd "$P" && bash "$D/validate-mandatory-rules.sh" 900 2>&1 )"; rc=$?; }
  c8()   { awk '/^  CHECK 8: /{ sub(/^[ ]+/,""); print; exit }' <<<"$out"; }
  summ() { awk '/checks (passed|verified)/{ sub(/^[ ]+/,""); print; exit }' <<<"$out"; }
  tok() {
    local line vd nm sm
    line="$(c8)"
    case "$line" in
      "CHECK 8: PASS"*) vd=PASS ;;
      "CHECK 8: FAIL"*) vd=FAIL ;;
      "CHECK 8: SKIP"*) vd=SKIP ;;
      "")               vd=NONE ;;
      *)                vd="OTHER[$line]" ;;
    esac
    case "$line" in *deploy-validate.md*) nm=d ;; *) nm="-" ;; esac
    sm="$(summ)"
    case "$sm" in
      "$ALL8_SUMMARY")  sm=all8 ;;
      "$SKIP8_SUMMARY") sm=skip8 ;;
      "")               sm=nosumm ;;
      *)                sm="other[$sm]" ;;
    esac
    printf '%s/%s/%s/%s' "$vd" "$nm" "$sm" "$rc"
  }

  # a — the position deploy-validate.md advanced to. Check 8 passes and nothing skips.
  snap_at 'retro.md';                         run; t="a:$(tok)"
  # b — THE DEFECT: the position nobody advanced. FAIL, rc 1, and the line names the value.
  snap_at 'deploy-validate.md';               run; t="$t b:$(tok)"
  # c — the section is there and the field is not: an older snapshot format. SKIP, counted.
  snap_nofield;                               run; t="$t c:$(tok)"
  # d — no snapshot at all. SKIP, counted, exit unaffected.
  snap_none;                                  run; t="$t d:$(tok)"
  # e — the consumer's REAL spelling, trailing em-dash prose and all (s309). Must PASS.
  snap_at 'retro.md — Steps 1/2/3 COMPLETE, retro doc written, PR open'; run; t="$t e:$(tok)"
  # f — the defect WITH `retro.md` named INSIDE the same Pipeline Position section, which is the
  #     shape 31 real revisions carry. A section-wide or file-wide grammar acquits this and only
  #     this; it is the arm the `widened` mutant dies on.
  snap_at 'deploy-validate.md' '- routing to retro.md (Step 7) next.'
  run; t="$t f:$(tok)"

  snap_at 'retro.md'
  printf '%s' "$t"
}

EXPECTED="a:PASS/-/all8/0 b:FAIL/d/nosumm/1 c:SKIP/-/skip8/0 d:SKIP/-/skip8/0 e:PASS/-/all8/0 f:FAIL/d/nosumm/1"

# --- 1. the shipping validator answers every arm ------------------------------
toolchain "$WORK/bin" "$VMR"
GOT="$(battery "$WORK/bin")"
if [ "$GOT" = "$EXPECTED" ]; then
  ok "all six arms: a position at retro.md PASSes (bare and with trailing prose), a position at deploy-validate.md FAILs at rc=1 naming the value it found, a missing field and a missing snapshot each SKIP and are counted in the summary, and \`retro.md\` sitting in another section does not acquit the defect"
else
  bad "battery: expected [$EXPECTED], got [$GOT]"
fi

# --- 2. the FAIL names its remedy, not just its verdict ------------------------
# retro.md accepts this validator on its exit code, and an operator reads the text. A FAIL that
# says only "wrong" leaves the reader to rediscover which field to write and where.
snap_at 'deploy-validate.md'
OUT="$( cd "$P" && bash "$WORK/bin/validate-mandatory-rules.sh" 900 2>&1 )"; RC=$?
if [ "$RC" -eq 1 ] && grep -q '^VALIDATE-MANDATORY-RULES: FAIL$' <<<"$OUT" \
   && grep -q 'Check8_SNAPSHOT_POSITION' <<<"$OUT" \
   && grep -q 'current_step_file: retro.md' <<<"$OUT" \
   && grep -q 'last_completed_step_file: deploy-validate.md' <<<"$OUT"; then
  ok "the FAIL carries the named check, the field to write and the value to write — an operator can act on it without reading the validator"
else
  bad "the Check 8 failure did not carry its remedy — rc=$RC, got: $OUT"
fi

# --- 3. a Check 8 SKIP does not change the exit code ---------------------------
# A skip is legitimate. Blocking a retro because the consumer's snapshot predates the field
# would be a gate that can never pass on that tree.
snap_none
OUT="$( cd "$P" && bash "$WORK/bin/validate-mandatory-rules.sh" 900 2>&1 )"; RC=$?
if [ "$RC" -eq 0 ] && grep -q '^VALIDATE-MANDATORY-RULES: PASS WITH SKIPS$' <<<"$OUT" \
   && grep -q 'the verified floor here is 7, not 8' <<<"$OUT"; then
  ok "a Check 8 skip reports the floor and still exits 0 — the accounting bought a truer sentence, not a harder gate"
else
  bad "a Check 8 skip did not keep exit 0 under the PASS WITH SKIPS headline — rc=$RC, got: $OUT"
fi

# --- 4. the terminal spellings the consumer actually writes SKIP, never FAIL ----
# Every one of these is a whole position line taken from the reference consumer's own snapshot
# history. None names a step file; a check that FAILED them would fire on a closed sprint's own
# record, and the `✅` and `NONE —` lines both carry the word `retro.md` further along, so they
# are also the inputs a value test keyed on containment would wrongly PASS.
t4=""
for v in \
  '- current_step_file: STOP -- sprint 900 fully closed. Retro merged.' \
  '- current_step_file: CLOSED (Sprint 900 pipeline complete)' \
  '- **Current step file:** NONE — **`retro.md` COMPLETE, Steps 1 through 7d. SPRINT CLOSED.**' \
  '- **Current step file:** ✅ **NONE — SPRINT 900 IS CLOSED.** `retro.md` reached **STOP**.' \
  '- current_step_file: (none — pipeline finished)' ; do
  snap_line "$v"
  OUT="$( cd "$P" && bash "$WORK/bin/validate-mandatory-rules.sh" 900 2>&1 )"; RC=$?
  L="$(awk '/^  CHECK 8: /{ sub(/^[ ]+/,""); print; exit }' <<<"$OUT")"
  case "$L" in "CHECK 8: SKIP"*) [ "$RC" -eq 0 ] && t4="$t4 ok" || t4="$t4 rc$RC" ;; *) t4="$t4 [$L]" ;; esac
done
if [ "$t4" = " ok ok ok ok ok" ]; then
  ok "the five terminal position spellings taken from the consumer's own history (STOP / CLOSED / NONE / a leading ✅ / '(none …)') SKIP at rc=0 rather than failing a sprint for having closed — and the two that name retro.md in their own prose are not thereby acquitted"
else
  bad "a terminal position spelling did not SKIP cleanly:$t4"
fi

# --- 5. every REAL key and value spelling, PASS side and FAIL side --------------
# Seeded from what the PRODUCER emits. The strict `current_step_file:` key resolves on only 167
# of the consumer's 510 snapshot revisions and the hook's alternation on 496, so the rows below
# are the ones a narrowed grammar silently stops reading — and the dominant unread spelling,
# `- **Current step file:** deploy-validate.md`, is the DEFECT. A check blind to it reports a
# skip floor where it owes a failure, which is indistinguishable from a clean tree.
t5=""
verdict8() { # verdict8 <verbatim-position-line> -> PASS|FAIL|SKIP|NONE
  snap_line "$1"
  local o l
  o="$( cd "$P" && bash "$WORK/bin/validate-mandatory-rules.sh" 900 2>&1 )"
  l="$(awk '/^  CHECK 8: /{ sub(/^[ ]+/,""); print; exit }' <<<"$o")"
  case "$l" in
    "CHECK 8: PASS"*) printf 'PASS' ;;
    "CHECK 8: FAIL"*) printf 'FAIL' ;;
    "CHECK 8: SKIP"*) printf 'SKIP' ;;
    *)                printf 'NONE' ;;
  esac
}
for v in \
  '- current_step_file: retro.md' \
  '- current_step_file: retro.md — Steps 1/2/3 COMPLETE' \
  '- current_step_file: `retro.md`.' \
  '- **`current_step_file`:** `retro.md`, Step 4a in flight' \
  '- current_step_file: `.claude/skills/ai-dlc/steps/retro.md`' \
  '- **Current step file:** retro.md' ; do
  t5="$t5 $(verdict8 "$v")"
done
for v in \
  '- **Current step file:** deploy-validate.md' \
  '- **`current_step_file`:** `deploy-validate.md`' ; do
  t5="$t5 $(verdict8 "$v")"
done
if [ "$t5" = " PASS PASS PASS PASS PASS PASS FAIL FAIL" ]; then
  ok "all six real retro spellings PASS (bare, em-dash prose, backticked value, backticked KEY, fully qualified steps/ path, and the prose 'Current step file:' key) and both real deploy-validate spellings FAIL — including the prose key, which is the dominant spelling in the consumer's history and the one the defect is written in"
else
  bad "the real-spelling battery did not answer [PASS x6, FAIL x2]:$t5"
fi

# ============================================================================
# MUTANTS. Each is a COPY of the validator in its OWN toolchain directory, guarded by `cmp -s`
# so a `sed` that matched nothing cannot pass as a mutation, and scored beside an UNMUTATED
# CONTROL built the same way — a copy that cannot resolve ../schemas emits nothing, and "no
# output" would otherwise score as a kill for every mutant at once.
#
# Each mutant declares the EXACT battery it produces. No two share a moved-set.
# ============================================================================
toolchain "$WORK/mut-control" "$VMR"
CTL="$(battery "$WORK/mut-control")"
if [ "$CTL" = "$EXPECTED" ]; then
  ok "CONTROL: an unmutated copy in its own toolchain dir reproduces all six baseline rows (so a mutant's silence below is the mutation, not the copy)"
else
  echo "FIXTURE ERROR: the unmutated control does not reproduce the battery — expected [$EXPECTED], got [$CTL]." >&2
  echo "  Every mutant verdict below would be meaningless." >&2
  exit 2
fi

mutate() {  # <tag> <sed-program> <expected-battery> <what-it-proves>
  local tag="$1" prog="$2" want="$3" claim="$4"
  local D="$WORK/mut-$tag" M="$WORK/staged-$tag.sh" got
  if ! sed "$prog" "$VMR" > "$M"; then
    bad "MUTANT $tag DID NOT APPLY: sed failed, so no mutant existed and its arms scored nothing"
    return
  fi
  if cmp -s "$VMR" "$M"; then
    echo "FIXTURE ERROR: mutant '$tag' matched nothing — the line it targets was renamed, so it proves nothing." >&2
    exit 2
  fi
  toolchain "$D" "$M"
  got="$(battery "$D")"
  if [ "$got" = "$want" ]; then
    ok "MUTANT $tag: $claim"
  elif [ "$got" = "$EXPECTED" ]; then
    bad "MUTANT $tag SURVIVED: $claim — every arm unchanged, so nothing here can catch it"
  else
    bad "MUTANT $tag ($claim): expected battery [$want], got [$got]"
  fi
}

# disabled — the check disabled outright: the snapshot is never opened, so every arm takes the
# missing-snapshot road. The defect arms (b, f) fall from FAIL to a counted SKIP, which is the
# whole finding: a tree that ships a stale position reports PASS WITH SKIPS.
mutate disabled \
  's@^SNAPSHOT_MD="_bmad-output/pipeline-snapshot.md"$@SNAPSHOT_MD="_bmad-output/no-such-snapshot.md"@' \
  'a:SKIP/-/skip8/0 b:SKIP/-/skip8/0 c:SKIP/-/skip8/0 d:SKIP/-/skip8/0 e:SKIP/-/skip8/0 f:SKIP/-/skip8/0' \
  "pointing the check at a path nothing writes makes every arm take the absent-snapshot SKIP — the defect arms report PASS WITH SKIPS over a stale position, which is the pre-fix state wearing a floor"

# widened — THE CONTAINMENT TEST. The extraction is left alone and the VERDICT is widened: the
# equality against the resolved position becomes "does the snapshot contain `retro.md` anywhere".
# That is the wrong implementation this check is most likely to be rewritten into, and arm f is
# the ONLY cell that moves — position at deploy-validate.md with `retro.md` named in the section
# a few lines below, the shape 31 real revisions carry. Arm b is the same defect WITHOUT that
# mention and stays FAIL, which is what makes f's flip attributable to the widening rather than
# to the defect going undetected generally.
#
# ANCHORED ON THE EQUALITY, NOT ON THE MULTI-LINE EXTRACTION. The first spelling of this mutant
# keyed on `C8_POS="$(awk ...` and replaced only that line of a five-line continuation, leaving
# a dangling `| grep ...` — the copy died at parse time and every arm scored NONE/rc=2, which is
# a mutant that never existed reading as a kill of all six cells at once. `cmp -s` cannot see
# that: the mutation applied cleanly, to a program that no longer runs. The battery's NONE token
# is what caught it.
mutate widened \
  's@^      if \[ "\$C8_POS" = "retro.md" \]; then$@      if grep -qi "retro[.]md" "$SNAPSHOT_MD"; then@' \
  'a:PASS/-/all8/0 b:FAIL/d/nosumm/1 c:SKIP/-/skip8/0 d:SKIP/-/skip8/0 e:PASS/-/all8/0 f:PASS/-/all8/0' \
  "widening the verdict from 'the resolved position IS retro.md' to 'the file mentions retro.md' ACQUITS a snapshot whose position is deploy-validate.md and whose own section says 'routing to retro.md next' — the exact shape 31 of the consumer's revisions carry"

# skipispass — the SKIP branch for a field-less snapshot turned into a PASS. Only arm c moves: it is the
# only world with the section and no field. The finding is that "cannot check" is reported as
# "checked and correct", which is this repo's recurring class stated in one cell.
# BOTH LINES OF THE BRANCH, because reverting one layer of a two-line change produces a mutant
# that proves the layer left in place. Replacing only the `echo` left the counter behind, so the
# run printed PASS and still reported a floor — a self-contradicting output no implementation
# would ever produce, and an expected battery written against it would have been asserting about
# a world that cannot exist.
mutate skipispass \
  "/^      echo \"  CHECK 8: SKIP (\${SNAPSHOT_MD} carries no /{ s@.*@      echo \"  CHECK 8: PASS\"@; n; /SKIPPED_CHECKS 8/d; }" \
  'a:PASS/-/all8/0 b:FAIL/d/nosumm/1 c:PASS/-/all8/0 d:SKIP/-/skip8/0 e:PASS/-/all8/0 f:FAIL/d/nosumm/1' \
  "turning the field-less SKIP into a PASS reports an unreadable position as a verified one and drops it from the skip accounting — a check that cannot fire reading exactly like one that passed"

# nocount — the counter. The branch still SKIPs and still says so on its own line, but the summary
# stops knowing: arms c and d fall back to `all 8 checks passed` while two checks did not run.
# This is the sibling fixture's subject asserted for the new check, and it is the only mutant
# that moves the SUMMARY without moving a CHECK 8 verdict.
# KEYED ON THE SUBJECT'S OWN PREDICATE, NOT ON ONE INDENT. Check 8 has THREE skip branches and
# they are not indented alike — the absent-snapshot one sits two spaces in, the other two six.
# A mutation anchored on the six-space spelling stripped two of three, arm d kept its counter,
# and the surviving cell read as a wrong prediction rather than as an insufficient mutation. A
# hand-written site list goes vacuous the release somebody adds a site; this matches every
# assignment of that counter whatever its indent.
mutate nocount \
  '/^[[:blank:]]*SKIPPED_CHECKS="\$SKIPPED_CHECKS 8"$/d' \
  'a:PASS/-/all8/0 b:FAIL/d/nosumm/1 c:SKIP/-/all8/0 d:SKIP/-/all8/0 e:PASS/-/all8/0 f:FAIL/d/nosumm/1' \
  "not counting Check 8's skip returns both skipping arms to the unqualified 'all 8 checks passed' while the CHECK 8 line still says SKIP — the two roads to exit 0 sharing one sentence again"

echo
# Liveness: a harness that silently stopped running assertions reads exactly like a clean pass.
if [ "$asserted" -ne 10 ]; then
  echo "mandatory-rules-snapshot-position: FIXTURE ERROR — ran $asserted assertions, expected 10" >&2
  exit 2
fi
if [ "$fails" -eq 0 ]; then
  echo "mandatory-rules-snapshot-position: PASS ($asserted assertions)"
  exit 0
fi
echo "mandatory-rules-snapshot-position: FAIL ($fails of $asserted assertion(s))" >&2
exit 1
