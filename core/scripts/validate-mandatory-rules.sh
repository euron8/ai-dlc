#!/usr/bin/env bash
# validate-mandatory-rules.sh
#
# Usage: ./scripts/ai-dlc/validate-mandatory-rules.sh <sprint-number>
# Example: ./scripts/ai-dlc/validate-mandatory-rules.sh 138
#
# Implements 6 retro-compliance checks for Rule 18 enforcement (Sprint 139
# retro Item 366 / Story 140-1). Verifies that the AI/DLC pipeline was
# structurally followed for the given sprint — not just asserted in prose.
#
# Origin: Item 366 (Rule-optionality hard rule, 5-layer implementation),
# Sprint 140 Story 140-1 (layers 2-5). Layer 1 shipped as CLAUDE.md Rule 18
# at commit cbedff11.
#
# The 6 checks:
#   Check 1: Party mode transcript exists and is SHA-cited in retro doc
#             (delegates to scripts/ai-dlc/validate-retro-evidence.sh <branch> <n>)
#   Check 2: Cycle commit count for retro artifacts
#             (delegates to validate-cycle-commits.sh; SKIP when no
#              _bmad-output/validation-cycle-log.md — per-artifact-changelog model)
#   Check 3: Sprint envelope closed (status: done + sprint_<n>_housekeeping)
#             (reads implementation-artifacts/sprint-status.yaml, written by
#              sprint-status.sh close; planning-artifacts fallback)
#   Check 4: Deploy-validate operator actions -- CONSUMER-PROVIDED
#             (scripts/validate-retro-prereq.sh; SKIP when the sibling is absent)
#   Check 5: Visual UI verification for web/** sprints (SKIP when no web change
#             or the sprint's gate-log section cannot be isolated)
#   Check 6: Dev Agent Record compliance — no "lead (self-executed" without waiver
#             (reads story files + docs/escalations/pending.md)
#   Check 7: The retro branch is not BEHIND origin/main (SKIP when no origin/main
#             ref resolves in this checkout)
#
# Exit codes:
#   0  -- all checks pass
#   1  -- one or more checks fail; error output on stderr names failing check
#   2  -- usage error (missing/wrong args, invalid sprint number)
#
# Tool dependencies: bash, grep, git, awk, sed, cut, wc, head, tail
# (coreutils only — no yq, jq, rg, or other non-standard tools)
# Compatible with bash 3.2+ (macOS default) and bash 5+ (Linux).
#
# Part of Sprint 140 Story 140-1 (Item 366 enforcement layers 2-5).
# Sibling scripts (contracts documented in Dev Agent Record):
#   - scripts/ai-dlc/validate-retro-evidence.sh  (Check 1)
#   - scripts/validate-cycle-commits.sh   (Check 2)
#   - scripts/validate-retro-prereq.sh    (Check 4)
#   - scripts/ai-dlc/validate-audit-anchors.sh   (Check 5 — --prior-sprint-sha)

set -u

# ---- Subset mode: --check-clean-tree ---------------------------------------
# A tree-state-agnostic entrypoint (no sprint number, no in-flight retro): assert
# only that the delegated toolchain is present, so a pre-push on any commit can
# confirm the validator set is installed without running the retro check series.
# The toolchain floor is the REQUIRED siblings: Check 1 hard-fails without
# validate-retro-evidence.sh, and Check 2 delegates to validate-cycle-commits.sh.
# validate-retro-prereq.sh is consumer-provided (Check 4 SKIPs when absent), so it
# is NOT part of the floor — its absence is expected on a stock install.
if [ "${1:-}" = "--check-clean-tree" ]; then
  CT_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
  ct_missing=0
  for dep in validate-retro-evidence.sh validate-cycle-commits.sh; do
    [ -f "${CT_SCRIPT_DIR}/${dep}" ] || { echo "clean-tree: sibling validator missing: ${dep}" >&2; ct_missing=1; }
  done
  if [ "$ct_missing" -ne 0 ]; then
    echo "VALIDATE-MANDATORY-RULES: FAIL (--check-clean-tree: validator toolchain incomplete)" >&2
    exit 1
  fi
  echo "VALIDATE-MANDATORY-RULES: PASS (--check-clean-tree: no in-flight sprint/retro context; toolchain present)"
  exit 0
fi

# ---- Usage check -----------------------------------------------------------
if [ $# -ne 1 ]; then
  echo "usage: ./scripts/ai-dlc/validate-mandatory-rules.sh <sprint-number>" >&2
  echo "example: ./scripts/ai-dlc/validate-mandatory-rules.sh 138" >&2
  exit 2
fi

SPRINT_N="$1"

# Sprint number must be a positive integer
case "$SPRINT_N" in
  ''|*[!0-9]*)
    echo "usage: ./scripts/ai-dlc/validate-mandatory-rules.sh <sprint-number>" >&2
    echo "error: sprint-number must be a positive integer (got: $SPRINT_N)" >&2
    exit 2
    ;;
esac

RETRO_BRANCH="ai-dlc/retro/sprint-${SPRINT_N}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FAILURES=0
SKIPPED_CHECKS=""
FAILURE_MSGS=""

# Helper: append a failure message
fail() {
  local check_name="$1"
  local msg="$2"
  FAILURES=$((FAILURES + 1))
  FAILURE_MSGS="${FAILURE_MSGS}[${check_name}] ${msg}
"
}

echo "validate-mandatory-rules.sh: Sprint ${SPRINT_N}"
echo "  retro branch: ${RETRO_BRANCH}"
echo ""

# ============================================================================
# Check 1: Party mode transcript exists and is SHA-cited
#   Delegates to scripts/ai-dlc/validate-retro-evidence.sh <retro-branch> <sprint-n>
#   Contract: args=(retro-branch sprint-number), exit 0=pass, 1=fail, 2=usage
# ============================================================================
echo "[Check 1] Party mode transcript + SHA citation..."
RETRO_EVIDENCE_SH="${SCRIPT_DIR}/validate-retro-evidence.sh"
if [ ! -f "$RETRO_EVIDENCE_SH" ]; then
  fail "Check1_PARTY_MODE" "validate-retro-evidence.sh not found at ${RETRO_EVIDENCE_SH}"
else
  C1_OUT=$("$RETRO_EVIDENCE_SH" "$RETRO_BRANCH" "$SPRINT_N" 2>&1)
  C1_EXIT=$?
  if [ $C1_EXIT -eq 0 ]; then
    echo "  CHECK 1: PASS"
  else
    echo "  CHECK 1: FAIL"
    fail "Check1_PARTY_MODE" "validate-retro-evidence.sh exited ${C1_EXIT} for Sprint ${SPRINT_N} / ${RETRO_BRANCH}. Output: $(echo "$C1_OUT" | head -5)"
  fi
fi

# ============================================================================
# Check 2: Cycle commit count >= 3 for retro artifacts
#   Delegates to scripts/validate-cycle-commits.sh <retro-branch>
#   Contract: args=(branch), exit 0=pass, 1=fail; reads _bmad-output/validation-cycle-log.md
# ============================================================================
echo "[Check 2] Cycle commit count >= 3 for retro..."
CYCLE_COMMITS_SH="${SCRIPT_DIR}/validate-cycle-commits.sh"
CYCLE_LOG="_bmad-output/validation-cycle-log.md"
if [ ! -f "$CYCLE_LOG" ]; then
  # Enablement is keyed on the PRODUCER, not the validator. Cycle evidence lives
  # either in a standalone validation-cycle-log.md (mechanically countable by the
  # sibling) or in per-artifact changelogs (freeform prose, not countable here).
  # A consumer on the changelog model ships no log; SKIP loudly rather than fail a
  # gate this cannot enforce without the log. The log's presence is the observable
  # opt-in — keying on the validator's presence instead would force-enforce on
  # every consumer once core ships the sibling.
  echo "  CHECK 2: SKIP (no ${CYCLE_LOG} — per-artifact-changelog model)"
  SKIPPED_CHECKS="$SKIPPED_CHECKS 2"
elif [ ! -f "$CYCLE_COMMITS_SH" ]; then
  echo "  CHECK 2: SKIP (validation-cycle-log.md present but no validate-cycle-commits.sh sibling)"
  SKIPPED_CHECKS="$SKIPPED_CHECKS 2"
else
  C2_OUT=$("$CYCLE_COMMITS_SH" "$RETRO_BRANCH" 2>&1)
  C2_EXIT=$?
  if [ $C2_EXIT -eq 0 ]; then
    echo "  CHECK 2: PASS"
  else
    echo "  CHECK 2: FAIL"
    fail "Check2_CYCLE_COMMITS" "validate-cycle-commits.sh exited ${C2_EXIT} for branch ${RETRO_BRANCH}. Output: $(echo "$C2_OUT" | tail -3)"
  fi
fi

# ============================================================================
# Check 3: Sprint envelope flipped to done in sprint-status.yaml
#   Reads _bmad-output/planning-artifacts/sprint-status.yaml directly
#   Checks: top-level status == done; sprint_<n>_housekeeping block with
#   envelope_status: done and non-empty closure_evidence
# ============================================================================
echo "[Check 3] Sprint envelope status in sprint-status.yaml..."
# Canonical is implementation-artifacts (PRIMARY, per sprint-status.sh + schemas/sprint-status.json
# header); planning-artifacts is a legacy second copy some consumers still carry. Prefer the
# canonical, fall back to the legacy path so a consumer that has not migrated still validates.
STATUS_YAML="_bmad-output/implementation-artifacts/sprint-status.yaml"
if [ ! -f "$STATUS_YAML" ] && [ -f "_bmad-output/planning-artifacts/sprint-status.yaml" ]; then
  STATUS_YAML="_bmad-output/planning-artifacts/sprint-status.yaml"
fi
if [ ! -f "$STATUS_YAML" ]; then
  fail "Check3_ENVELOPE" "sprint-status.yaml not found at ${STATUS_YAML}"
else
  # Read top-level status field (first occurrence of "^status:")
  TOP_STATUS_VALUE=$(grep -E '^status:[[:space:]]' "$STATUS_YAML" | head -1 | sed 's/status:[[:space:]]*//')

  if [ "$TOP_STATUS_VALUE" != "done" ]; then
    fail "Check3_ENVELOPE" "sprint-status.yaml top-level 'status:' is '${TOP_STATUS_VALUE}', expected 'done'"
  fi

  # Check sprint_<n>_housekeeping block — use grep to find the block
  HOUSEKEEPING_KEY="sprint_${SPRINT_N}_housekeeping"
  HOUSEKEEPING_FOUND=$(grep -n "^${HOUSEKEEPING_KEY}:" "$STATUS_YAML" | head -1)
  if [ -z "$HOUSEKEEPING_FOUND" ]; then
    fail "Check3_ENVELOPE" "sprint-status.yaml missing '${HOUSEKEEPING_KEY}:' block"
  else
    # Extract the block lines after the housekeeping key
    HOUSEKEEPING_LINE=$(echo "$HOUSEKEEPING_FOUND" | cut -d: -f1)
    BLOCK_TEXT=$(tail -n +$((HOUSEKEEPING_LINE + 1)) "$STATUS_YAML" | awk '/^[a-z]/{exit} {print}')

    # Check envelope_status: done
    ENVELOPE_STATUS=$(echo "$BLOCK_TEXT" | grep -E 'envelope_status:[[:space:]]' | head -1 | sed 's/.*envelope_status:[[:space:]]*//' | tr -d '"')
    if [ "$ENVELOPE_STATUS" != "done" ]; then
      fail "Check3_ENVELOPE" "${HOUSEKEEPING_KEY}.envelope_status is '${ENVELOPE_STATUS}', expected 'done'"
    fi

    # Check closure_evidence is non-empty
    CLOSURE_EVIDENCE=$(echo "$BLOCK_TEXT" | grep -E 'closure_evidence:[[:space:]]' | head -1 | sed 's/.*closure_evidence:[[:space:]]*//' | tr -d '"')
    if [ -z "$CLOSURE_EVIDENCE" ]; then
      fail "Check3_ENVELOPE" "${HOUSEKEEPING_KEY}.closure_evidence is empty"
    fi
  fi

  # Always print PASS/FAIL for Check 3 regardless of housekeeping presence
  if ! grep -q "Check3_ENVELOPE" <<<"$FAILURE_MSGS"; then
    echo "  CHECK 3: PASS"
  else
    echo "  CHECK 3: FAIL"
  fi
fi

# ============================================================================
# Check 4: Deploy-Validate gate log row present with 6/6 operator actions
#   Delegates to scripts/validate-retro-prereq.sh <sprint-n>
#   Contract: args=(sprint-number), exit 0=pass, 1=fail, 2=usage
# ============================================================================
echo "[Check 4] Deploy-validate operator actions (6/6)..."
RETRO_PREREQ_SH="${SCRIPT_DIR}/validate-retro-prereq.sh"
if [ ! -f "$RETRO_PREREQ_SH" ]; then
  # Consumer-provided check — core ships no validate-retro-prereq.sh. The deploy-validate operator
  # action set is deploy-target specific (the reference consumer's is ECS rollout / mTLS / SSM), so
  # core has no universal list to assert. A consumer with a structured deploy-action record ships its
  # own sibling and this check runs; absent it, SKIP loudly rather than fail the gate (the other half
  # of the S138 dead-delegation poison).
  echo "  CHECK 4: SKIP (no validate-retro-prereq.sh — consumer-provided)"
  SKIPPED_CHECKS="$SKIPPED_CHECKS 4"
else
  C4_OUT=$("$RETRO_PREREQ_SH" "$SPRINT_N" 2>&1)
  C4_EXIT=$?
  if [ $C4_EXIT -eq 0 ]; then
    echo "  CHECK 4: PASS"
  else
    echo "  CHECK 4: FAIL"
    fail "Check4_DEPLOY_VALIDATE" "validate-retro-prereq.sh exited ${C4_EXIT} for Sprint ${SPRINT_N}. Output: $(echo "$C4_OUT" | tail -5)"
  fi
fi

# ============================================================================
# Check 5: Visual UI verification for web/** sprints
#   For sprints where any story touched web/**, assert gate-log.md contains
#   USER-CONFIRMED OR playwright trace evidence in the Deploy Status Report row.
#   Skipped for sprints with no web/** changes.
# ============================================================================
echo "[Check 5] Visual UI verification (web/** sprints only)..."
GATE_LOG="_bmad-output/implementation-artifacts/gate-log.md"

# ---- the story corpus location is the SCHEMA's, not this file's ------------
# `stories_dir` in schemas/sprint-status.json is a TEMPLATE carrying the sprint slot, because
# artifact-path-grammar.md rule 2 moved the sprint out of the story FILENAME and into the
# DIRECTORY. This file used to restate the resolved literal, and so did the protect hook and the
# installer -- three copies, so moving the path meant finding them all from memory. I84 in
# validate-enforcement-map.sh now binds the single home.
#
# THREE CANDIDATES, AND ALL THREE ARE LOAD-BEARING -- install.sh splits what shares a parent in
# the distribution (`core/scripts/<x>` -> `scripts/ai-dlc/<x>`, `core/schemas/` ->
# `.claude/schemas/`), so no single relative shape reaches the schema in both layouts:
#
#   $SCRIPT_DIR/../schemas   the package this copy shipped in. Correct upstream
#                            (core/scripts/../schemas) and in a synthetic toolchain dir; it is
#                            NOT correct in a consumer, where it resolves to scripts/schemas.
#   .claude/schemas          the consumer, from the project root this script already runs at.
#   core/schemas             the distribution, from its root.
#
# Script-relative FIRST, for sprint-status.sh's reason: a copy should read the schema it shipped
# beside. The two cwd-relative arms are the layouts where that copy has been split away from it.
SPRINT_STATUS_SCHEMA=""
for _sch in "$SCRIPT_DIR/../schemas/sprint-status.json" \
            ".claude/schemas/sprint-status.json" \
            "core/schemas/sprint-status.json"; do
  [ -f "$_sch" ] && { SPRINT_STATUS_SCHEMA="$_sch"; break; }
done
STORIES_DIR_T=""
STORIES_SLOT=""
if [ -n "$SPRINT_STATUS_SCHEMA" ]; then
  STORIES_DIR_T="$(sed -n 's/.*"stories_dir"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$SPRINT_STATUS_SCHEMA" | head -1)"
  STORIES_SLOT="$(sed -n 's/.*"stories_dir_sprint_placeholder"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$SPRINT_STATUS_SCHEMA" | head -1)"
fi

# <sprint-number, or `*` for every sprint> -> the corpus directory. Rule 1 declares `s*` the same
# reserved slot quantified over every sprint, so one template answers both readings.
stories_dir() { printf '%s' "${STORIES_DIR_T//"$STORIES_SLOT"/$1}"; }

STORIES_DIR=""
STORIES_DIR_ALL=""
STORIES_AREA=""
if [ -n "$STORIES_DIR_T" ] && [ -n "$STORIES_SLOT" ]; then
  STORIES_DIR="$(stories_dir "$SPRINT_N")"
  STORIES_DIR_ALL="$(stories_dir '*')"
  # The AREA the slot sits under -- everything before the component carrying the slot. Derived by
  # cutting the template at its own placeholder, so it cannot disagree with the template it came
  # from. Check 6's control needs it: a corpus counted only under the DECLARED location is blind
  # to a corpus that has not moved there yet, and blind is spelled SKIP.
  STORIES_AREA="${STORIES_DIR_T%%"$STORIES_SLOT"*}"
  STORIES_AREA="${STORIES_AREA%/*}"
fi

# Diff base. This runs at retro time, on a retro branch cut from main AFTER the sprint merged
# — so the sprint's web/** changes are ancestors of main and `main..HEAD` is EMPTY. Diffing
# against main made Check 5 structurally unable to fire: it SKIPped every sprint on an empty
# range (a check that cannot fire reads exactly like one that passed). Resolve the base from
# the prior sprint's audit-anchor SHA (audit-anchors.md, a core artifact written by retro.md
# Step 5b) — the sprint's changes are exactly [prior-sprint anchor .. HEAD]. Enumerate real
# changed files, NOT prose-grepping story files (which triggers on mentions of web/** in AC
# text). If the base is unresolvable (no audit-anchors.md, no prior-sprint entry, or an
# unresolvable SHA — e.g. the first sprint), SKIP loudly: an undeterminable change set is
# "cannot check", not "no evidence". Core SKIPs here where a deploy-target-specific consumer
# may fail-close; gate-validation Check 9 is the primary visual-verification gate regardless.
#
# The resolution itself is DELEGATED, not restated. It used to be an awk here keyed on
# `$1=="-" && $2=="sprint:"` — a second grammar over an artifact whose reader is
# validate-audit-anchors.sh, and the copy that could never reach the gate that states the same
# predicate (gate-validation Check 18 told the lead to resolve this by reading the file). One home:
# `--prior-sprint-sha <file> <current-sprint-n>`, which does the minus-one, prints the resolved
# commit on stdout and its cause on stderr. The POSTURE stays this script's: a non-zero there is a
# loud SKIP here and a fail-closed at Check 18, for the reason above.
AUDIT_ANCHORS="_bmad-output/audit-anchors.md"
PRIOR_SPRINT=$((SPRINT_N - 1))
CHECK5_BASE=""
CHECK5_ANCHOR_ERR=""
AUDIT_ANCHORS_SH="${SCRIPT_DIR}/validate-audit-anchors.sh"
if [ ! -f "$AUDIT_ANCHORS_SH" ]; then
  CHECK5_ANCHOR_ERR="validate-audit-anchors.sh not found at ${AUDIT_ANCHORS_SH} — it owns the resolution"
elif [ ! -f "$AUDIT_ANCHORS" ]; then
  CHECK5_ANCHOR_ERR="audit-anchors.md not found at ${AUDIT_ANCHORS}"
else
  # stdout is the SHA and stderr is the reasoning, so they are captured apart — merging them would
  # put the resolver's own OK line into the base ref. No EXIT trap: installing one in a script that
  # pipes turned silent SIGPIPEs into pages of `write error: Broken pipe` from untouched pipelines.
  C5_ERRF="$(mktemp "${TMPDIR:-/tmp}/aidlc-check5.XXXXXX" 2>/dev/null || printf '%s' "${TMPDIR:-/tmp}/aidlc-check5.$$")"
  CHECK5_BASE="$(bash "$AUDIT_ANCHORS_SH" --prior-sprint-sha "$AUDIT_ANCHORS" "$SPRINT_N" 2>"$C5_ERRF")"
  C5_RC=$?
  if [ "$C5_RC" -ne 0 ] || [ -z "$CHECK5_BASE" ]; then
    CHECK5_BASE=""
    CHECK5_ANCHOR_ERR="$(head -3 "$C5_ERRF" 2>/dev/null | tr '\n' ' ')"
    [ -n "$CHECK5_ANCHOR_ERR" ] || CHECK5_ANCHOR_ERR="validate-audit-anchors.sh --prior-sprint-sha exited ${C5_RC} for prior sprint ${PRIOR_SPRINT} without a message"
  fi
  rm -f "$C5_ERRF"
fi

if [ -z "$CHECK5_BASE" ]; then
  echo "  CHECK 5: SKIP (cannot resolve diff base: ${CHECK5_ANCHOR_ERR})"
  SKIPPED_CHECKS="$SKIPPED_CHECKS 5"
elif [ -z "$(git diff --name-only "${CHECK5_BASE}..HEAD" -- 'web/**' 'web/src/**' 'web/tests/**' 2>/dev/null | head -20)" ]; then
  echo "  CHECK 5: SKIP (no web/** file changes in ${CHECK5_BASE}..HEAD for Sprint ${SPRINT_N})"
  SKIPPED_CHECKS="$SKIPPED_CHECKS 5"
else
  if [ ! -f "$GATE_LOG" ]; then
    fail "Check5_VISUAL_UI" "gate-log.md not found at ${GATE_LOG} (required for web/** sprint ${SPRINT_N})"
  else
    # Look for Sprint N Deploy-Validate section in gate-log.md.
    # Use [[:space:]] instead of \b for BSD awk (macOS) word-boundary compatibility.
    SPRINT_SECTION=$(awk "/^## Gate Log: Sprint ${SPRINT_N}([[:space:]]|$)/{found=1} found && /^## Gate Log: Sprint [0-9]/ && !/^## Gate Log: Sprint ${SPRINT_N}([[:space:]]|$)/{found=0} found{print}" "$GATE_LOG" 2>/dev/null | head -200)

    if [ -z "$SPRINT_SECTION" ]; then
      # Could not isolate this sprint's deploy-validate section in gate-log.md. The gate-log entry
      # header format is consumer-defined (CLAUDE.md Autonomous Gate Protocol) — core keys on
      # "## Gate Log: Sprint N", but a consumer may section its log differently, so a missing section
      # means "cannot determine", not "no visual evidence". SKIP rather than fail on an unparseable
      # format; a consumer whose gate-log uses this header still gets the real check below.
      echo "  CHECK 5: SKIP (could not isolate Sprint ${SPRINT_N} section in gate-log.md — consumer-defined format)"
      SKIPPED_CHECKS="$SKIPPED_CHECKS 5"
    else
      VISUAL_OK=0
      if grep -qi 'USER-CONFIRMED' <<<"$SPRINT_SECTION"; then
        VISUAL_OK=1
      fi
      if grep -qi 'playwright' <<<"$SPRINT_SECTION"; then
        VISUAL_OK=1
      fi

      if [ $VISUAL_OK -eq 1 ]; then
        echo "  CHECK 5: PASS"
      else
        echo "  CHECK 5: FAIL"
        fail "Check5_VISUAL_UI" "Sprint ${SPRINT_N} has web/** file changes but gate-log.md Sprint ${SPRINT_N} section contains neither 'USER-CONFIRMED' nor playwright trace evidence in Deploy Status Report"
      fi
    fi
  fi
fi

# ============================================================================
# Check 6: Dev Agent Record compliance
#   For each story-<n>-*.md, assert the Dev Agent Record does NOT contain
#   literal substring "lead (self-executed" UNLESS docs/escalations/pending.md
#   has a DECIDED_AUTONOMOUSLY or HARD_BLOCK entry naming the story ID --
#   the entry that names it, not whatever entry happens to sit nearby. See the
#   waiver predicate below for the measurement that forced that distinction.
# ============================================================================
echo "[Check 6] Dev Agent Record compliance (no lead self-execution without waiver)..."
ESCALATIONS_FILE="docs/escalations/pending.md"
CHECK6_FAILURES=0

# THE GLOB'S ZERO CARRIES A SAME-RUN CONTROL, and it is here because the zero was real.
# Measured on the reference consumer: for sprints 298 and 299 the old NAME-keyed glob
# (`story-<N>-*.md` against one flat directory) matched ZERO files, the loop body never ran,
# CHECK6_FAILURES stayed 0 and the check printed PASS -- while 73 story files for those sprints
# sat in that same directory spelled `story-S<N>-` with a capital S. Control on the same
# directory in the same read: `story-297-*` matched 11. Two closed sprints had their Dev Agent
# Record compliance verified against nothing.
#
# THE NAME-KEYED GLOB IS GONE, and that is this release's fix rather than a second patch on it.
# The selector is now the sprint's own DIRECTORY, so it is a TOTAL function of the sprint: every
# file in it belongs to this sprint whatever it is called, and no spelling of the sprint in a
# basename can hide a story from the check. A capital S cannot come back.
#
# THE CONTROL SPANS THE WHOLE AREA, NOT THE DECLARED SLOT, and that widening was forced by
# measurement rather than chosen. Counted only under the declared `s*/stories/` location, the
# control is BLIND to a tree that still holds its corpus in one flat directory -- so an
# unmigrated consumer with 988 story files reported `corpus is empty` and SKIPped, which is this
# check's own historical defect wearing the fix's clothes. Counting every `stories/` directory
# under the area sees both layouts, and the gap between the two numbers is what names the cause.
#
# So: no stories anywhere under the area is a project before its first story -- a SKIP. Stories
# under the area but none in THIS sprint's directory is either the 298/299 shape or an unmigrated
# tree, and both fail.
CHECK6_MATCHED=0
CHECK6_CORPUS=0
CHECK6_AREA_CORPUS=0
CHECK6_SKIPPED=0
CHECK6_UNRESOLVED=0
if [ -z "$STORIES_DIR" ]; then
  # Fail closed, loudly. An unresolvable corpus location makes this check unable to fire, and a
  # check that cannot fire reads exactly like one that passed.
  CHECK6_UNRESOLVED=1
else
  for _d in $STORIES_DIR_ALL; do
    [ -d "$_d" ] || continue
    for _s in "$_d"/*.md; do
      [ -f "$_s" ] && CHECK6_CORPUS=$((CHECK6_CORPUS + 1))
    done
  done
  if [ -d "$STORIES_AREA" ]; then
    CHECK6_AREA_CORPUS="$(find "$STORIES_AREA" -type d -name stories -exec find {} -maxdepth 1 -type f -name '*.md' \; 2>/dev/null | grep -c . || true)"
  fi
  for story_file in "${STORIES_DIR}"/*.md; do
    if [ ! -f "$story_file" ]; then
      continue
    fi
    CHECK6_MATCHED=$((CHECK6_MATCHED + 1))

    # The story id for the ESCALATIONS join is still sprint-qualified (`story-<N>-<M>`), because
    # that is the vocabulary docs/escalations/pending.md is written in. The FILE no longer carries
    # the sprint, so the id is COMPOSED from the sprint this run was given plus the index the
    # filename carries -- the same declared-not-searched direction as everything else here.
    story_basename=$(basename "$story_file" .md)
    story_index=$(printf '%s' "$story_basename" | sed -n 's/^story-\([0-9][0-9]*\).*/\1/p')
    if [ -n "$story_index" ]; then
      story_id="story-${SPRINT_N}-${story_index}"
    else
      story_id="$story_basename"
    fi

    # Normalize story_id to display format used in escalations file.
    # Filename format: "story-140-1" → Display format: "Story 140-1"
    # The escalations file uses "Story N-M" (capital S, space after Story).
    display_id=$(echo "$story_id" | sed 's/^story-/Story /; s/\([0-9][0-9]*\)-\([0-9]\)/\1-\2/')

    # Extract the ## Dev Agent Record section from the story file.
    # AC7 specifies: asserts the Dev Agent Record section does NOT contain
    # "lead (self-executed" — NOT the entire story file (which may mention
    # the string in AC text as a forbidden example).
    # Range: from "## Dev Agent Record" to the next "## " heading (exclusive).
    DEV_AGENT_SECTION=$(awk '/^## Dev Agent Record/{found=1; next} found && /^## [A-Za-z]/{exit} found{print}' "$story_file" 2>/dev/null)

    # Check for literal substring "lead (self-executed" only in the Dev Agent Record section
    if grep -q 'lead (self-executed' 2>/dev/null <<<"$DEV_AGENT_SECTION"; then
      # THE WAIVER MUST BE THE RECORD THAT NAMES THE STORY, AND THIS IS THE ONE PLACE
      # `DECIDED_AUTONOMOUSLY` IS GIVEN FORCE ANYWHERE IN CORE -- the force being permissive, it
      # is a KEY rather than a lock, so every looseness here hands out a key.
      #
      # The old predicate was `grep -E -A 5 <story-id>` piped into a second grep for the token: a
      # PROXIMITY match that crossed record boundaries. Measured on the reference consumer's
      # `pending-archive.md`, stories 147-1..147-4 were waived by a token 5 lines below their
      # only mention -- and that token was `**Status:** DECIDED_AUTONOMOUSLY` at `:646`, belonging
      # to the NEXT entry (`## [Sprint-147 / Scope Selection]` at `:645`), not to the waiver at
      # `:621` that actually covers them. A neighbouring record satisfied the check.
      #
      # The boundary is `^## `, which is the entry grammar core itself publishes in
      # `skills/ai-dlc/escalations.md` (`## [STORY-ID] [Teammate Name] - [Date/Time]`), so this is
      # reading the declared shape rather than inventing one. Within a record the existing
      # 5-line co-location is UNCHANGED, and that is deliberate: replacing it with record scope
      # was measured and REJECTED. Over 886 composed story ids against the consumer's two
      # escalation files, "same record, token anywhere in it" newly GRANTED the waiver to 52
      # stories and "same record, token on the record's `**Status:**` line" to 45 -- because a
      # long entry mentions many stories in passing (`## [Sprint-172 / Story-172-2 / ...]` at
      # `pending-archive.md:3221` mentions Story 172-3 in a coordination note, and would have
      # waived it). Widening the key is the opposite of what this check is for. The predicate
      # below is the only variant measured to be strictly tighter than the one it replaces:
      # newly-granted set EMPTY on both files, all 886 ids.
      #
      # The trailing-digit guard is the second half of "names THIS story": `story-147-1` used to
      # be satisfied by a record naming `story-147-10`. Isolated cost of that guard, measured on
      # the same corpus: one id (`story-170-1`).
      WAIVER_FOUND=0
      if [ -f "$ESCALATIONS_FILE" ]; then
        # Both the filename form ("story-N-M") and the display form ("Story N-M") name the story;
        # matched as LITERAL substrings, never as a regex, because the fallback id is an arbitrary
        # file basename.
        WAIVER_FOUND=$(awk -v sid="$story_id" -v did="$display_id" '
          function names(line,   n, needle, rest, p, c) {
            for (n = 1; n <= 2; n++) {
              needle = (n == 1 ? sid : did)
              rest = line
              while ((p = index(rest, needle)) > 0) {
                c = substr(rest, p + length(needle), 1)
                if (c !~ /^[0-9]$/) return 1
                rest = substr(rest, p + 1)
              }
            }
            return 0
          }
          /^## / { win = 0 }          # a new record: no window survives into it
          names($0) { win = 6 }       # this line plus the 5 after it, as grep -A 5 read them
          win > 0 {
            if (index($0, "DECIDED_AUTONOMOUSLY") || index($0, "HARD_BLOCK")) { found = 1; exit }
            win--
          }
          END { print found + 0 }
        ' "$ESCALATIONS_FILE" 2>/dev/null)
        [ -n "$WAIVER_FOUND" ] || WAIVER_FOUND=0
      fi

      if [ $WAIVER_FOUND -eq 0 ]; then
        fail "Check6_DEV_AGENT_RECORD" "story file '${story_file}' contains 'lead (self-executed' in Dev Agent Record section but no DECIDED_AUTONOMOUSLY or HARD_BLOCK waiver for '${display_id}' (or '${story_id}') found in ${ESCALATIONS_FILE}. The waiver must be the '## ' entry that NAMES this story: the token has to sit on the naming line or within the 5 lines after it, inside that same entry. A token in a neighbouring entry does not waive this story, and neither does an entry naming a longer id this one is a prefix of."
        CHECK6_FAILURES=$((CHECK6_FAILURES + 1))
      fi
    fi
  done
  if [ "$CHECK6_AREA_CORPUS" -eq 0 ]; then
    CHECK6_SKIPPED=1
  fi
fi

if [ "$CHECK6_UNRESOLVED" -eq 1 ]; then
  fail "Check6_STORIES_DIR_UNRESOLVED" "the story corpus location could not be resolved from schemas/sprint-status.json (looked for .claude/schemas/ and core/schemas/ under $(pwd); found '${SPRINT_STATUS_SCHEMA:-<no schema>}', stories_dir template '${STORIES_DIR_T:-<empty>}', slot '${STORIES_SLOT:-<empty>}'). Check 6 has no directory to read, so it verified NOTHING. This fails rather than skipping: an unresolvable subject and a clean one are the same silence."
  CHECK6_FAILURES=$((CHECK6_FAILURES + 1))
  echo "  CHECK 6: FAIL — the corpus location did not resolve"
elif [ "$CHECK6_SKIPPED" -eq 1 ]; then
  echo "  CHECK 6: SKIP — the story corpus is empty (0 story files under any stories/ directory in ${STORIES_AREA})"
  SKIPPED_CHECKS="$SKIPPED_CHECKS 6"
elif [ "$CHECK6_MATCHED" -eq 0 ]; then
  fail "Check6_GLOB_MATCHED_NOTHING" "no story file sits in '${STORIES_DIR}', but ${CHECK6_AREA_CORPUS} story file(s) sit under a stories/ directory in '${STORIES_AREA}' (${CHECK6_CORPUS} of them under the declared '${STORIES_DIR_ALL}'). Check 6 would have verified NOTHING and printed PASS. Either this sprint wrote its stories somewhere else, or the tree still holds the corpus in ONE flat directory shared across sprints and has not been migrated — run 'scripts/ai-dlc/migrate-artifact-paths.sh' (dry run), then '--apply'. Until then the sprint's Dev Agent Record compliance is unverified."
  CHECK6_FAILURES=$((CHECK6_FAILURES + 1))
  echo "  CHECK 6: FAIL — 0 of ${CHECK6_AREA_CORPUS} story file(s) sit in this sprint's directory"
elif [ $CHECK6_FAILURES -eq 0 ]; then
  echo "  CHECK 6: PASS — ${CHECK6_MATCHED} story file(s) verified"
else
  echo "  CHECK 6: FAIL"
fi

# ============================================================================
# Check 7: the retro branch is not BEHIND the integration branch
#   retro.md Step 1 cuts the retro branch from `main` after a fast-forward to
#   `origin/main`. A squash merge never fast-forwards the sprint's feature
#   branch, so a retro branch cut from that leftover ref lacks the squash commit
#   as an ancestor: its PR re-includes the whole sprint diff against a main that
#   already carries it and reports CONFLICTING at Step 7a, and the recovery is a
#   hand merge of every file both sides touched.
#
#   THE PREDICATE is `git rev-list --count HEAD..origin/main` == 0 -- the same
#   test sprint-review.md §0 runs before a review.
#
#   IT REFRESHES THE REF FIRST, AND SAYS WHETHER IT COULD. The squash's branch
#   point is an ancestor of the leftover feature branch by construction, so a
#   STALE local origin/main reads the exact defect world as 0 -- measured: the
#   defect world fails at behind-count 2 with a fresh ref and passes with the ref
#   rewound to the branch point. A fetch that lives only in the step prose is the
#   same omission class this check exists to catch. So when a remote named
#   `origin` exists the check runs `git fetch origin main` itself, non-interactive
#   and with a low-speed timeout so a stalled transfer cannot wedge the gate, and
#   the CHECK 7 line states whether the ref was refreshed. A failed fetch does not
#   fail the check -- an offline retro is live work -- but its line says the ref
#   may be stale, and a reader who sees that sentence beside PASS has not been
#   told the branch is fresh. A sandbox with no remote (every fixture here) skips
#   the fetch without touching the network.
#
#   SKIP, loudly, when origin/main does not resolve. A checkout with no such ref
#   (a fixture sandbox, a clone with no remote) cannot be measured, and an
#   unmeasurable branch is not a fresh one -- the summary counts it as a skip.
#
#   THE FIRING SET IS WIDER THAN THE DEFECT, on purpose. A branch is behind
#   origin/main either because it was cut from a leftover feature ref (the
#   defect) or because it was cut from the trunk and main moved before the PR
#   opened (benign). Measured over the reference consumer's 118 measurable
#   merged retro PRs: 16 were behind origin/main at the branch cut, the incident
#   among them. The benign class is not a defect, but the remedy the failure
#   names (`git merge origin/main`) is the merge GitHub performs for it at PR
#   time anyway, so firing on it costs one command; a predicate that separated
#   the two classes would need the sprint's squash commit, which no artifact
#   this validator reads records.
# ============================================================================
echo "[Check 7] Retro branch not behind origin/main..."
C7_REFRESH="origin/main not refreshed: no remote named origin"
if git remote get-url origin >/dev/null 2>&1; then
  if GIT_TERMINAL_PROMPT=0 git -c http.lowSpeedLimit=1000 -c http.lowSpeedTime=20 \
       fetch -q --no-tags origin main >/dev/null 2>&1; then
    C7_REFRESH="origin/main refreshed"
  else
    C7_REFRESH="origin/main NOT refreshed: fetch failed, so the local ref may be stale"
  fi
fi
if ! git rev-parse -q --verify 'refs/remotes/origin/main^{commit}' >/dev/null 2>&1; then
  echo "  CHECK 7: SKIP (no origin/main ref resolves in this checkout -- branch freshness cannot be measured here; ${C7_REFRESH})"
  SKIPPED_CHECKS="$SKIPPED_CHECKS 7"
else
  C7_BEHIND="$(git rev-list --count HEAD..origin/main 2>/dev/null)" || C7_BEHIND=""
  case "$C7_BEHIND" in
    ''|*[!0-9]*)
      fail "Check7_BRANCH_BEHIND_MAIN" "git rev-list --count HEAD..origin/main produced no count (got: '${C7_BEHIND}'). The branch's relation to origin/main is undeterminable, which is not a fresh branch."
      echo "  CHECK 7: FAIL — behind-count undeterminable (${C7_REFRESH})"
      ;;
    0)
      echo "  CHECK 7: PASS — HEAD contains origin/main (${C7_REFRESH})"
      ;;
    *)
      fail "Check7_BRANCH_BEHIND_MAIN" "HEAD is ${C7_BEHIND} commit(s) behind origin/main (${C7_REFRESH}). The retro branch was not cut from the merged trunk (retro.md Step 1: 'git fetch origin main && git checkout main && git merge --ff-only origin/main' before 'git checkout -b'), so its PR will re-include every commit origin/main has that this branch lacks. Remedy: 'git fetch origin main && git merge origin/main' on this branch, resolve in origin/main's favour for every file the retro did not touch, then re-run this validator."
      echo "  CHECK 7: FAIL — HEAD is ${C7_BEHIND} commit(s) behind origin/main (${C7_REFRESH})"
      ;;
  esac
fi

# ============================================================================
# Final summary
# ============================================================================
#
# A SKIPPED CHECK IS NOT A PASSED CHECK, AND THIS LINE USED TO SAY IT WAS.
# Checks 2, 4 and 5 each have legitimate SKIP branches -- a consumer on the
# per-artifact-changelog model ships no cycle log, `validate-retro-prereq.sh` is
# consumer-provided, and a sprint touching no `web/**` file has no UI to verify.
# None of those is a failure. But no SKIP branch touched a counter, and the summary
# read "all 6 checks passed" whether six ran or three did, on the same exit code.
#
# Measured on a reference consumer before this was fixed: two checks SKIPPED on
# EVERY sprint from 296 through 302, because the consumer never provided
# `validate-retro-prereq.sh`. The retro step accepts this validator on its exit code
# alone, so seven consecutive retros closed against a line asserting six verified
# checks when the true floor was four.
#
# The exit code does NOT change -- a skip is legitimate and blocking on it would be
# wrong. What changes is that the two roads to exit 0 no longer share one sentence.
#
# Counted by check NUMBER, de-duplicated. Checks 2 and 5 each have more than one SKIP
# branch, but those branches are `if`/`elif` arms of one chain, so no check can emit
# twice in a single run and the `sort -u` cannot fire today -- it is there so that a
# check which later grows a second, non-exclusive skip path still reports a floor
# rather than a tally. That is a deliberately dormant guard, not a live one, and this
# comment says so rather than crediting it with work it does not do.
#
# COUNTED BY WORD, NOT BY `grep -c`. The first spelling was
# `... | grep -c . || echo 0`, and on the empty (zero-skip) input `grep -c` prints "0"
# AND exits 1, so the `||` appended a SECOND "0". The variable held "0\n0", `[ -eq 0 ]`
# died with "integer expression expected" and fell through to the skip-reporting branch
# on a tree where nothing had skipped -- and then `$((6 - SKIPPED_UNIQUE))` hit a
# multi-line operand, which bash treats as a FATAL arithmetic syntax error: the shell
# aborted right there, printing no summary and never reaching `exit 0`.
#
# So the draft did not merely mis-word the clean case, it turned it into rc=1. `retro.md`
# accepts this validator on its exit code alone, which means the fix for a summary that
# could not distinguish a skip would have HARD-FAILED every retro that skipped nothing --
# the one population it was not written for. The zero-skip arm of
# `mandatory-rules-skip-accounting` is the regression lock, and the `zeroskipbug` mutant
# there restores that exact spelling and asserts the rc=1 abort.
SKIPPED_LIST="$(printf '%s\n' $SKIPPED_CHECKS | sort -u | tr '\n' ' ' | sed 's/  */ /g; s/^ //; s/ $//')"
SKIPPED_UNIQUE=0
for _skipped in $SKIPPED_LIST; do SKIPPED_UNIQUE=$((SKIPPED_UNIQUE + 1)); done
echo ""
if [ $FAILURES -eq 0 ]; then
  if [ "$SKIPPED_UNIQUE" -eq 0 ]; then
    echo "VALIDATE-MANDATORY-RULES: PASS"
    echo "  Sprint ${SPRINT_N}: all 7 checks passed"
  else
    echo "VALIDATE-MANDATORY-RULES: PASS WITH SKIPS"
    echo "  Sprint ${SPRINT_N}: $((7 - SKIPPED_UNIQUE)) of 7 checks verified; ${SKIPPED_UNIQUE} SKIPPED (check ${SKIPPED_LIST})."
    echo "  A skipped check is not a passed one. Each skip is legitimate on its own terms,"
    echo "  but the verified floor here is $((7 - SKIPPED_UNIQUE)), not 7 -- read the CHECK lines above."
  fi
  exit 0
else
  echo "VALIDATE-MANDATORY-RULES: FAIL"
  echo "  Sprint ${SPRINT_N}: ${FAILURES} check(s) failed"
  echo "" >&2
  echo "Failure details:" >&2
  printf '%s' "$FAILURE_MSGS" >&2
  exit 1
fi
