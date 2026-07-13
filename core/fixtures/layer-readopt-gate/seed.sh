#!/usr/bin/env bash
# seed.sh — build a REAL distribution git repo and a REAL consumer tree on disk.
#
# Not an `echo` describing a fixture. v0.48.0 shipped three of those: seed scripts
# that printed English prose about files they never wrote, so the check read a
# DESCRIPTION of a test and adjudicated it. It could not fail, and it never did.
# Everything below is written to disk and committed.
#
# Prints the sandbox root on stdout.
set -euo pipefail

ROOT="$(mktemp -d)"
DIST="$ROOT/dist"
CONS="$ROOT/consumer"

# ---------------------------------------------------------------------------
# The distribution, at BASE.
# ---------------------------------------------------------------------------
mkdir -p "$DIST/core/skills/ai-dlc/steps" "$DIST/core/team-roles"
git -C "$DIST" init -q
git -C "$DIST" config user.email f@x
git -C "$DIST" config user.name f

cat > "$DIST/core/skills/ai-dlc/SKILL.md" <<'EOF'
# AI/DLC

## Rule 7 -- Something Else

Untouched across the range. Present so the fixture proves the gate is
section-scoped and not merely file-scoped.

## Rule 8 -- Validation Depth

**Divergence is a HARD_BLOCK, not a reason for another pass.** If pass N+1
reports more CRITICALs than pass N, the repair step is injecting defects faster
than review removes them; another pass only finds the next wave. STOP.

## Rule 9 -- Trailing

Tail section.
EOF

# NOTE the trailing unchanged section. The template tokens must NOT be the last
# lines of the file: with substitution at EOF, a trailing-newline bug in the
# classifier hides inside the hunk the substitution already creates, and the
# fixture cannot see it. Real core files end with unchanged prose, which is what
# turns a stripped trailing newline into a NEW, token-less hunk -- and every
# substituted file then reads as unregistered drift. Verified by mutation: with
# the tokens at EOF this fixture passes against the bug.
cat > "$DIST/core/team-roles/dev.md" <<'EOF'
# Role: Developer

## Identity

You are a Dev teammate.

**Model and effort.**
- Personal: `/model {dev_model_personal}`
- Bedrock: `/model {dev_model_bedrock}`

## Workflow Per Task

Read the story. Implement. Run the tests. Report.
EOF

cat > "$DIST/core/team-roles/tea.md" <<'EOF'
# Role: TEA

## Identity

You are the TEA teammate -- the Test Architect. You carry the
quality-and-testability lens.
EOF

git -C "$DIST" add -A
git -C "$DIST" commit -qm base
BASE="$(git -C "$DIST" rev-parse --short HEAD)"

# ---------------------------------------------------------------------------
# The distribution, at THEIRS. Rule 8's divergence clause is REWRITTEN --
# exactly the v0.52.0 change: the bare count comparison becomes scope-relative.
# Rule 7 and Rule 9 are left alone.
# ---------------------------------------------------------------------------
cat > "$DIST/core/skills/ai-dlc/SKILL.md" <<'EOF'
# AI/DLC

## Rule 7 -- Something Else

Untouched across the range. Present so the fixture proves the gate is
section-scoped and not merely file-scoped.

## Rule 8 -- Validation Depth

**Divergence is a HARD_BLOCK, not a reason for another pass.** If pass N+1
reports more CRITICALs IN THE SCOPE THE PRIOR PASS ALSO REVIEWED
(`findings_critical_prior_scope`) than pass N reported in total, the repair step
is injecting defects. CRITICALs in scope the sprint ADDED are NOT divergence.

## Rule 9 -- Trailing

Tail section.
EOF

git -C "$DIST" add -A
git -C "$DIST" commit -qm theirs
THEIRS="$(git -C "$DIST" rev-parse --short HEAD)"

# ---------------------------------------------------------------------------
# The consumer, installed at BASE.
# ---------------------------------------------------------------------------
mkdir -p "$CONS/.claude/skills/ai-dlc/steps" \
         "$CONS/.claude/skills/ai-dlc/overrides" \
         "$CONS/.claude/team-roles"
git -C "$CONS" init -q
git -C "$CONS" config user.email f@x
git -C "$CONS" config user.name f

# core, as installed from BASE
git -C "$DIST" show "${BASE}:core/skills/ai-dlc/SKILL.md" > "$CONS/.claude/skills/ai-dlc/SKILL.md"

# team-roles/dev.md -- template tokens SUBSTITUTED by install.sh. This is
# sanctioned; it must NOT read as unregistered drift.
sed -e 's/{dev_model_personal}/claude-sonnet-5/' \
    -e 's/{dev_model_bedrock}/global.anthropic.claude-sonnet-4-6/' \
    <(git -C "$DIST" show "${BASE}:core/team-roles/dev.md") > "$CONS/.claude/team-roles/dev.md"

# team-roles/tea.md -- a WHOLESALE consumer rewrite, in place, with no override
# entry. The live graph case. This MUST read as unregistered drift.
cat > "$CONS/.claude/team-roles/tea.md" <<'EOF'
# Role: TEA

## Identity

You are the Test Architect teammate (Murat). You own test strategy, risk-based
test design, and quality-gate decisions for this project. You decide WHAT must
be tested and to what depth.
EOF

# The override that shadows Rule 8 and COPIES the old divergence clause verbatim.
# The lead obeys this file, not core.
cat > "$CONS/.claude/skills/ai-dlc/overrides/SKILL__Rule-8.md" <<EOF
---
shadows: SKILL.md#Rule 8
base_sha: ${BASE}
reason: consumer-specific validation-intensity table keyed to this repo's service paths.
---

## Rule 8 -- Validation Depth

Validation intensity by path: service/ and infra/ are FULL; scripts/ and docs/ are LIGHT.

**Divergence is a HARD_BLOCK, not a reason for another pass.** If pass N+1
reports more CRITICALs than pass N, the repair step is injecting defects faster
than review removes them; another pass only finds the next wave. STOP.
EOF

git -C "$CONS" add -A
git -C "$CONS" commit -qm installed

printf '%s\n' "$ROOT"
