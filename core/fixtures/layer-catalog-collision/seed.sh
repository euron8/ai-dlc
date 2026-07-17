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
mkdir -p "$SKILL/steps" "$SKILL/extensions/checks" "$SKILL/extensions/steps-domain" "$SKILL/overrides"

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

# --- a core STEP file whose step numbers a prose list can shadow ---------------
cat > "$SKILL/steps/retro.md" <<'CORERETRO'
---
name: retro
description: synthetic core step list for the layer-catalog-collision fixture
---

# Synthetic retro

### 1. Context Loading
Core's step 1.

### 2. Party Mode Retro
Core's step 2.

### 7a-post. Announce the retro outcome.
Core's 7a-post — an ENTIRELY different section from the extension's bold
`**7a-post. Log Rotation …**`. This pair is the positive control: it can only
be reported if the bold anchor was extracted at all, so it fails the moment the
bold tolerance is narrowed too far.
CORERETRO

# --- the bold-prose-list trap --------------------------------------------------
# A `**7a-post. Title**` bold ANCHOR is a real section heading and must be seen.
# A `**1. Narrative drift.** Rule text continues...` list ITEM is prose and must
# NOT be. The two are told apart by what follows the closing `**`: an anchor is
# the whole line, a list item is followed by its sentence.
#
# Reading the list items as anchors reports collisions against core's step 1/2 —
# the extension defines no such steps, and the advice the message then gives
# ("label the heading `### 1. [ext:prose]`") is nonsense applied to a sentence.
cat > "$SKILL/extensions/steps-domain/prose.md" <<'PROSE'
---
kind: step-domain
hooks: steps/retro.md
id: prose
push_candidate: true
---

### 0. Real Section
The only section this extension actually defines.

**7a-post. Log Rotation — gate log + compaction log (post-retro-merge
follow-up).** A genuine bold anchor: the bold span is the heading itself.

The rule-weakness triage list. These are PROSE, not sections:

**1. Narrative drift.** Rule text contains sprint/story references,
so it reads as history rather than instruction.

**2. Rule weakness.** Rule text uses "should", "try to", "consider",
none of which are enforceable.
PROSE

# --- the unterminated-frontmatter trap ----------------------------------------
# ONE `---`, no closing delimiter. Every reader scans to EOF for its keys, so
# `shadows`/`base_sha` still parse and the entry passes every other check — while
# its body sits inside the YAML block, where `### …` is a comment. Shipped real:
# a consumer's newest override carried exactly this shape and linted clean.
#
# base_sha is a real distribution sha so the E2/E3 arms stay quiet and this case
# tests the terminator and nothing else.
cat > "$SKILL/overrides/steps__retro__unterminated.md" <<'BAD'
---
shadows: steps/retro.md#1. Context Loading
base_sha: 6798096
reason: |
  A block scalar that runs to the end of the file because nothing closes the
  frontmatter. The heading below is inside it.

### 1. Context Loading — CONSUMER OVERRIDE

This body is unreachable as a body.
BAD

# The control: a well-formed override on the same target must stay silent, or the
# new check is just erroring on every override.
cat > "$SKILL/overrides/steps__retro__terminated.md" <<'GOOD'
---
shadows: steps/retro.md#2. Party Mode Retro
base_sha: 6798096
reason: one line, block closed
---

### 2. Party Mode Retro — CONSUMER OVERRIDE

A well-formed override body.
GOOD

printf '%s\n' "$ROOT"
