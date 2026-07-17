#!/usr/bin/env bash
# relabel-theirs-collision/seed.sh — build a fake distribution (theirs) whose core adds `### 26.`
# and a consumer whose INSTALLED core lacks it but whose extension already defines `### 26.`.
# That is a NEW-THIS-PULL collision: invisible to a plain dry-run, visible only with --theirs.
# Idempotent: fresh temp tree each call.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh" ]; then
  SCRIPT="$D_ROOT/core/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/.claude/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh" ]; then
  SCRIPT="$C_ROOT/.claude/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh"
else
  echo "FIXTURE ERROR: relabel-extension-checks.sh not found in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/relabel-theirs.XXXXXX")" || exit 2
DIST="$WORK/dist"
CONSUMER="$WORK/consumer"
GV="skills/ai-dlc/steps/gate-validation.md"
RETRO="skills/ai-dlc/steps/retro.md"
mkdir -p "$DIST/core/skills/ai-dlc/steps" \
         "$CONSUMER/.claude/skills/ai-dlc/steps" \
         "$CONSUMER/.claude/skills/ai-dlc/extensions/checks" \
         "$CONSUMER/.claude/skills/ai-dlc/extensions/steps-domain" \
         "$CONSUMER/.claude/team-roles"

# THEIRS (incoming core) — adds `### 26.`, and carries `### H1.`, the letter-id form that
# lives in the real gate-validation.md and that the old numeric-only grammar could not see.
cat > "$DIST/core/$GV" <<'CORE'
# Gate validation (fixture)
### 25. Existing universal check.
### 26. Core gate-check adjudication verdict.
### H1. Harness meta-check — each phase-specific check has a self-test fixture.
CORE

# A second core file, so a step-domain extension has a step-numbered file to collide in.
cat > "$DIST/core/$RETRO" <<'CORE'
# Retro (fixture)
### 3. Write Retro Document
CORE
git -C "$DIST" init -q
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m theirs
THEIRS="$(git -C "$DIST" rev-parse HEAD)"

# CONSUMER installed core — the PRE-APPLY state, without 26.
cat > "$CONSUMER/.claude/$GV" <<'CORE'
# Gate validation (fixture)
### 25. Existing universal check.
### H1. Harness meta-check — each phase-specific check has a self-test fixture.
CORE
cat > "$CONSUMER/.claude/$RETRO" <<'CORE'
# Retro (fixture)
### 3. Write Retro Document
CORE

# CONSUMER extension — already defines `### 26.`, unlabelled.
cat > "$CONSUMER/.claude/skills/ai-dlc/extensions/checks/mydomain.md" <<'EXT'
---
kind: check
id: mydomain
hooks: steps/gate-validation.md
---
### 26. Ext deployed-ranges consistency gate.
EXT

# B1 — a step-domain extension colliding on a core STEP number. The `= check` filter
# skipped this kind entirely, so the tool printed "no unlabelled collisions" over it.
cat > "$CONSUMER/.claude/skills/ai-dlc/extensions/steps-domain/retro-push.md" <<'EXT'
---
kind: step-domain
id: retro-push
hooks: steps/retro.md
---
### 3. Ext retro push-candidate harvest.
EXT

# B2 — a check extension colliding on the LETTER anchor `H1`. The numeric-only grammar
# yielded no anchor for core's `### H1.`, so this collision was unrelabellable even
# after B1. The em-dash in the title (not the separator) must survive the rewrite.
cat > "$CONSUMER/.claude/skills/ai-dlc/extensions/checks/harness-ext.md" <<'EXT'
---
kind: check
id: harness-ext
hooks: steps/gate-validation.md
---
### H1. Ext harness meta-check — consumer fixtures.
EXT

# MUTANT GUARD — a kind with no numbered-heading namespace. Widening the filter to
# `check|step-domain` must NOT become "widen to everything": this must stay skipped.
cat > "$CONSUMER/.claude/skills/ai-dlc/extensions/checks/roleish.md" <<'EXT'
---
kind: role
id: roleish
hooks: steps/gate-validation.md
---
### 25. Ext role-shaped entry that must never be relabelled.
EXT

cat > "$WORK/env.sh" <<ENV
SCRIPT="$SCRIPT"
DIST="$DIST"
THEIRS="$THEIRS"
CONSUMER="$CONSUMER"
EXT="$CONSUMER/.claude/skills/ai-dlc/extensions/checks/mydomain.md"
EXT_STEP="$CONSUMER/.claude/skills/ai-dlc/extensions/steps-domain/retro-push.md"
EXT_H1="$CONSUMER/.claude/skills/ai-dlc/extensions/checks/harness-ext.md"
EXT_ROLE="$CONSUMER/.claude/skills/ai-dlc/extensions/checks/roleish.md"
ENV

printf '%s\n' "$WORK"
