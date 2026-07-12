#!/usr/bin/env bash
# layer-catalog-collision — seed a synthetic consumer whose extension catalog
# collides with core's in every way that matters.
#
# Writes a throwaway tree under $1 (default: a mktemp dir) shaped like a real
# consumer, and echoes the path. run.sh drives the detectors against it.
#
# Idempotent: re-running overwrites the seeded files in place.
set -euo pipefail

ROOT="${1:-$(mktemp -d "${TMPDIR:-/tmp}/layer-catalog-collision.XXXXXX")}"
SKILL="$ROOT/.claude/skills/ai-dlc"
mkdir -p "$SKILL/steps" "$SKILL/extensions/checks" "$SKILL/overrides"

# --- the core file the extension hooks ---------------------------------------
# Note check 24's heading is written the CORRECT way (`### 24.`). The variant that
# broke everything (`### Check 24.`) is exercised by run.sh, not baked in here.
cat > "$SKILL/steps/gate-validation.md" <<'CORE'
---
name: gate-validation
description: synthetic core catalog for the layer-catalog-collision fixture
---

# Synthetic gate-validation catalog

### 5. Story status consistency?
<!-- CHECK_LOADED: 5 -->
Core's story-status check.

### 7. Artifact consistency?
<!-- CHECK_LOADED: 7 -->
Core-only; the extension does not touch it.

### 9. Smoke test coverage for user-facing changes? (Implementation gates only)
<!-- CHECK_LOADED: 9 -->
THE TRAP. Shares {smoke, test} with the extension's check 30, which is a
different check entirely. A title matcher loose enough to pair these would
propose deleting a live deploy-validate check.

### 21. Test-strategy deliverable presence (sprint-review gate).
<!-- CHECK_LOADED: 21 -->
**Graph→distribution number mapping.** Absorbed from the consumer's Check 33;
recorded so a future reconciliation does not re-flag it as new. The consumer
still carries its copy at 33 — a duplicate no number-keyed join can see.

### 24. The adversarial cycle CONVERGED (Rule 8).
<!-- CHECK_LOADED: 24 -->
Core's check 24. The consumer's check 24 is a completely different check.
CORE

# --- the consumer's extension catalog ----------------------------------------
cat > "$SKILL/extensions/checks/domain.md" <<'EXT'
---
kind: check
hooks: steps/gate-validation.md
id: domain
push_candidate: false
---

### 5. Story status consistency?
Same number, same title as core → a RESTATEMENT (Rule 27(c)).

### 24. Financial-display ground-truth live-verify (deploy-validate gate only).
Same number as core, ENTIRELY different check → a COLLISION. Both render into one
merged list under one integer, and `Check 24: PASSED` in the gate log stops having
a referent.

### 30. Smoke test evidence (deploy-validate gate only).
Extension-only. Shares {smoke, test} with core's check 9 and is NOT that check.
Matching these two is the false-absorption regression this fixture guards.

### 33. Cross-story test-strategy deliverable presence (sprint-review gate only).
Core absorbed this as its check 21 — same check, DIFFERENT number. Invisible to a
number-keyed join, which is how it survived unreported.
EXT

printf '%s\n' "$ROOT"
