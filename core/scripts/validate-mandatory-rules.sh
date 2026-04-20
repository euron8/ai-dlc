#!/usr/bin/env bash
# validate-mandatory-rules.sh
#
# Usage: ./scripts/validate-mandatory-rules.sh <sprint-number>
# Example: ./scripts/validate-mandatory-rules.sh 138
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
#             (delegates to scripts/validate-retro-evidence.sh <branch> <n>)
#   Check 2: Cycle commit count >= 3 for retro artifacts
#             (delegates to scripts/validate-cycle-commits.sh <retro-branch>)
#   Check 3: Sprint envelope flipped to done (sprint-status.yaml)
#             (reads _bmad-output/planning-artifacts/sprint-status.yaml)
#   Check 4: Deploy-Validate gate log row present with all 6 operator actions
#             (delegates to scripts/validate-retro-prereq.sh <sprint-n>)
#   Check 5: Visual UI verification for web/** sprints
#             (reads _bmad-output/implementation-artifacts/gate-log.md)
#   Check 6: Dev Agent Record compliance — no "lead (self-executed" without waiver
#             (reads story files + docs/escalations/pending.md)
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
#   - scripts/validate-retro-evidence.sh  (Check 1)
#   - scripts/validate-cycle-commits.sh   (Check 2)
#   - scripts/validate-retro-prereq.sh    (Check 4)

set -u

# ---- Usage check -----------------------------------------------------------
if [ $# -ne 1 ]; then
  echo "usage: ./scripts/validate-mandatory-rules.sh <sprint-number>" >&2
  echo "example: ./scripts/validate-mandatory-rules.sh 138" >&2
  exit 2
fi

SPRINT_N="$1"

# Sprint number must be a positive integer
case "$SPRINT_N" in
  ''|*[!0-9]*)
    echo "usage: ./scripts/validate-mandatory-rules.sh <sprint-number>" >&2
    echo "error: sprint-number must be a positive integer (got: $SPRINT_N)" >&2
    exit 2
    ;;
esac

RETRO_BRANCH="ai-dlc/retro/sprint-${SPRINT_N}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FAILURES=0
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
#   Delegates to scripts/validate-retro-evidence.sh <retro-branch> <sprint-n>
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
if [ ! -f "$CYCLE_COMMITS_SH" ]; then
  fail "Check2_CYCLE_COMMITS" "validate-cycle-commits.sh not found at ${CYCLE_COMMITS_SH}"
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
STATUS_YAML="_bmad-output/planning-artifacts/sprint-status.yaml"
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
  if ! echo "$FAILURE_MSGS" | grep -q "Check3_ENVELOPE"; then
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
  fail "Check4_DEPLOY_VALIDATE" "validate-retro-prereq.sh not found at ${RETRO_PREREQ_SH}"
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
STORIES_DIR="_bmad-output/planning-artifacts/stories"

# Determine if any file actually changed under web/** for this sprint branch.
# Use git diff --name-only against main to enumerate real changed files,
# NOT prose-grepping story files (which triggers on mentions of web/** in AC text).
# Falls back to HAS_WEB_STORIES=0 if git is unavailable or the branch is unknown.
HAS_WEB_STORIES=0
WEB_CHANGED_FILES=$(git diff --name-only main..HEAD -- 'web/**' 'web/src/**' 'web/tests/**' 2>/dev/null | head -20)
if [ -n "$WEB_CHANGED_FILES" ]; then
  HAS_WEB_STORIES=1
fi

if [ $HAS_WEB_STORIES -eq 0 ]; then
  echo "  CHECK 5: SKIP (no web/** file changes detected for Sprint ${SPRINT_N} branch)"
else
  if [ ! -f "$GATE_LOG" ]; then
    fail "Check5_VISUAL_UI" "gate-log.md not found at ${GATE_LOG} (required for web/** sprint ${SPRINT_N})"
  else
    # Look for Sprint N Deploy-Validate section in gate-log.md.
    # Use [[:space:]] instead of \b for BSD awk (macOS) word-boundary compatibility.
    SPRINT_SECTION=$(awk "/^## Gate Log: Sprint ${SPRINT_N}([[:space:]]|$)/{found=1} found && /^## Gate Log: Sprint [0-9]/ && !/^## Gate Log: Sprint ${SPRINT_N}([[:space:]]|$)/{found=0} found{print}" "$GATE_LOG" 2>/dev/null | head -200)

    VISUAL_OK=0
    if echo "$SPRINT_SECTION" | grep -qi 'USER-CONFIRMED'; then
      VISUAL_OK=1
    fi
    if echo "$SPRINT_SECTION" | grep -qi 'playwright'; then
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

# ============================================================================
# Check 6: Dev Agent Record compliance
#   For each story-<n>-*.md, assert the Dev Agent Record does NOT contain
#   literal substring "lead (self-executed" UNLESS docs/escalations/pending.md
#   has a DECIDED_AUTONOMOUSLY or HARD_BLOCK entry naming the story ID.
# ============================================================================
echo "[Check 6] Dev Agent Record compliance (no lead self-execution without waiver)..."
ESCALATIONS_FILE="docs/escalations/pending.md"
CHECK6_FAILURES=0

if [ -d "$STORIES_DIR" ]; then
  for story_file in "${STORIES_DIR}/story-${SPRINT_N}-"*.md; do
    if [ ! -f "$story_file" ]; then
      continue
    fi

    # Extract story ID from filename (story-<n>-<slug>) — filename format
    story_basename=$(basename "$story_file" .md)
    story_id=$(echo "$story_basename" | grep -o "story-${SPRINT_N}-[0-9]*" | head -1)
    if [ -z "$story_id" ]; then
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
    if echo "$DEV_AGENT_SECTION" | grep -q 'lead (self-executed' 2>/dev/null; then
      # Check if there's a waiver in escalations file using BOTH filename and display format
      WAIVER_FOUND=0
      if [ -f "$ESCALATIONS_FILE" ]; then
        # Look for DECIDED_AUTONOMOUSLY or HARD_BLOCK entry naming this story ID.
        # Search for both "story-N-M" (filename) and "Story N-M" (display) formats.
        if grep -qE "${story_id}|${display_id}" "$ESCALATIONS_FILE" 2>/dev/null; then
          # Check if the entry containing story_id also has DECIDED_AUTONOMOUSLY or HARD_BLOCK
          STORY_CONTEXT=$(grep -E -A 5 "${story_id}|${display_id}" "$ESCALATIONS_FILE" 2>/dev/null)
          if echo "$STORY_CONTEXT" | grep -q 'DECIDED_AUTONOMOUSLY\|HARD_BLOCK'; then
            WAIVER_FOUND=1
          fi
        fi
      fi

      if [ $WAIVER_FOUND -eq 0 ]; then
        fail "Check6_DEV_AGENT_RECORD" "story file '${story_file}' contains 'lead (self-executed' in Dev Agent Record section but no DECIDED_AUTONOMOUSLY or HARD_BLOCK waiver for '${display_id}' (or '${story_id}') found in ${ESCALATIONS_FILE}"
        CHECK6_FAILURES=$((CHECK6_FAILURES + 1))
      fi
    fi
  done
fi

if [ $CHECK6_FAILURES -eq 0 ]; then
  echo "  CHECK 6: PASS"
else
  echo "  CHECK 6: FAIL"
fi

# ============================================================================
# Final summary
# ============================================================================
echo ""
if [ $FAILURES -eq 0 ]; then
  echo "VALIDATE-MANDATORY-RULES: PASS"
  echo "  Sprint ${SPRINT_N}: all 6 checks passed"
  exit 0
else
  echo "VALIDATE-MANDATORY-RULES: FAIL"
  echo "  Sprint ${SPRINT_N}: ${FAILURES} check(s) failed"
  echo "" >&2
  echo "Failure details:" >&2
  printf '%s' "$FAILURE_MSGS" >&2
  exit 1
fi
