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
elif [ ! -f "$CYCLE_COMMITS_SH" ]; then
  echo "  CHECK 2: SKIP (validation-cycle-log.md present but no validate-cycle-commits.sh sibling)"
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
  # Consumer-provided check — core ships no validate-retro-prereq.sh. The deploy-validate operator
  # action set is deploy-target specific (the reference consumer's is ECS rollout / mTLS / SSM), so
  # core has no universal list to assert. A consumer with a structured deploy-action record ships its
  # own sibling and this check runs; absent it, SKIP loudly rather than fail the gate (the other half
  # of the S138 dead-delegation poison).
  echo "  CHECK 4: SKIP (no validate-retro-prereq.sh — consumer-provided)"
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
AUDIT_ANCHORS="_bmad-output/audit-anchors.md"
PRIOR_SPRINT=$((SPRINT_N - 1))
CHECK5_BASE=""
CHECK5_ANCHOR_ERR=""
if [ ! -f "$AUDIT_ANCHORS" ]; then
  CHECK5_ANCHOR_ERR="audit-anchors.md not found at ${AUDIT_ANCHORS}"
else
  PRIOR_ANCHOR_RAW=$(awk -v s="$PRIOR_SPRINT" '$1=="-" && $2=="sprint:" && $3==s {f=1; next} f && $1=="sha:" {print $2; exit}' "$AUDIT_ANCHORS")
  if [ -z "$PRIOR_ANCHOR_RAW" ]; then
    CHECK5_ANCHOR_ERR="no audit-anchor entry for prior sprint ${PRIOR_SPRINT} in ${AUDIT_ANCHORS}"
  else
    CHECK5_BASE=$(git rev-parse --verify -q "${PRIOR_ANCHOR_RAW}^{commit}" 2>/dev/null || true)
    [ -z "$CHECK5_BASE" ] && CHECK5_ANCHOR_ERR="prior-sprint (${PRIOR_SPRINT}) audit-anchor '${PRIOR_ANCHOR_RAW}' does not resolve to a commit"
  fi
fi

if [ -z "$CHECK5_BASE" ]; then
  echo "  CHECK 5: SKIP (cannot resolve diff base: ${CHECK5_ANCHOR_ERR})"
elif [ -z "$(git diff --name-only "${CHECK5_BASE}..HEAD" -- 'web/**' 'web/src/**' 'web/tests/**' 2>/dev/null | head -20)" ]; then
  echo "  CHECK 5: SKIP (no web/** file changes in ${CHECK5_BASE}..HEAD for Sprint ${SPRINT_N})"
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
    else
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
