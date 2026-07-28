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

## Rule 10 -- Reporting

Reporting rules for this pipeline.

### `## Audit Ledger` — one table, not five transcriptions

Every scan reports into ONE `## Audit Ledger` table. This sub-heading makes the
construct a delegation target living INSIDE Rule 10: an override shadowing
`#Rule 10` deletes it. Unchanged across the range, so the drift arm stays quiet
and only OVERRIDE-DELEGATES-INTO-SHADOW can speak here.

## Rule 11 -- Outside The Shadow

### `## Escalation Log` — the control

Defined OUTSIDE any shadowed section. An override may delegate here freely and the
detector MUST stay silent, or it fires on every legitimate cross-section pointer.

## Rule 12 -- Handoff (configurable via `handoff_mode`)

The backticked term is in the ANCHOR heading itself, not in a construct nested
under it. An override shadowing `#Rule 12` and naming `handoff_mode` is describing
what it overrides, not delegating into it. This is the measured false positive
(1 of 13 on the reference consumer) that the anchor-heading exclusion removes.
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

mkdir -p "$DIST/core/hooks"
cat > "$DIST/core/hooks/guard.sh" <<'EOF'
#!/usr/bin/env bash
# A core hook the consumer will harden in place.
set -uo pipefail
echo "core baseline behaviour, unchanged across the range"
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

## Rule 10 -- Reporting

Reporting rules for this pipeline.

### `## Audit Ledger` — one table, not five transcriptions

Every scan reports into ONE `## Audit Ledger` table. This sub-heading makes the
construct a delegation target living INSIDE Rule 10: an override shadowing
`#Rule 10` deletes it. Unchanged across the range, so the drift arm stays quiet
and only OVERRIDE-DELEGATES-INTO-SHADOW can speak here.

## Rule 11 -- Outside The Shadow

### `## Escalation Log` — the control

Defined OUTSIDE any shadowed section. An override may delegate here freely and the
detector MUST stay silent, or it fires on every legitimate cross-section pointer.

## Rule 12 -- Handoff (configurable via `handoff_mode`)

The backticked term is in the ANCHOR heading itself, not in a construct nested
under it. An override shadowing `#Rule 12` and naming `handoff_mode` is describing
what it overrides, not delegating into it. This is the measured false positive
(1 of 13 on the reference consumer) that the anchor-heading exclusion removes.
EOF

# THEIRS absorbs the consumer's hardening (the v0.55.0 handoff-guard case).
cat > "$DIST/core/hooks/guard.sh" <<'EOF'
#!/usr/bin/env bash
# A core hook the consumer will harden in place.
set -uo pipefail
echo "core baseline behaviour, unchanged across the range"
# ---- upstreamed from the reference consumer ----
CONSUMER_GUARD_ANCHOR_ONE="a substantive line the consumer added first"
CONSUMER_GUARD_ANCHOR_TWO="a second substantive line the consumer added"
CONSUMER_GUARD_ANCHOR_THREE="a third substantive line the consumer added"
CONSUMER_GUARD_ANCHOR_FOUR="a fourth substantive line the consumer added"
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

# Two more overrides, for OVERRIDE-DELEGATES-INTO-SHADOW. Both shadow a section
# that is UNCHANGED across the range, so both are OVERRIDE-OK on the drift arm --
# which is the point: the two questions are independent, and the real consumer's
# instances were both reported OVERRIDE-OK while delegating into their own shadow.
cat > "$CONS/.claude/skills/ai-dlc/overrides/SKILL__Rule-10.md" <<EOF
---
shadows: SKILL.md#Rule 10
base_sha: ${BASE}
reason: consumer-specific reporting rules.
---

## Rule 10 -- Reporting (CONSUMER OVERRIDE)

Consumer reporting rules. Record every verdict in core's \`## Audit Ledger\` table.

That table is defined INSIDE Rule 10, which this entry replaces at load time, so
the delegation cannot resolve. This entry MUST be reported.
EOF

# THE CONTROL. Same shape, same shadow, but it delegates to a construct defined
# OUTSIDE the shadowed span. It must stay SILENT. Without this, the assertion
# above passes for a detector that flags every override carrying a backtick.
cat > "$CONS/.claude/skills/ai-dlc/overrides/SKILL__Rule-10-control.md" <<EOF
---
shadows: SKILL.md#Rule 9
base_sha: ${BASE}
reason: consumer-specific trailing section; delegates OUTSIDE its own shadow.
---

## Rule 9 -- Trailing (CONSUMER OVERRIDE)

Consumer tail. Record every verdict in core's \`## Escalation Log\`, which is
defined under Rule 11 — outside this entry's shadow — so it remains reachable.
EOF

# THE SECOND CONTROL — the measured false positive. The backticked term lives in the
# ANCHOR heading itself, so naming it is self-description, not delegation. Must be
# SILENT. Without this the anchor-heading exclusion is untested and can be deleted
# with every assertion still green.
cat > "$CONS/.claude/skills/ai-dlc/overrides/SKILL__Rule-12-anchor.md" <<EOF
---
shadows: SKILL.md#Rule 12
base_sha: ${BASE}
reason: consumer-specific handoff configuration.
---

## Rule 12 -- Handoff (CONSUMER OVERRIDE)

This consumer sets \`handoff_mode\` to always-on. Naming the term that appears in
the heading being overridden is self-description, not a delegation into the shadow.
EOF

# The consumer's IN-PLACE hook hardening — no override entry (hooks have no grain).
mkdir -p "$CONS/.claude/hooks"
cat > "$CONS/.claude/hooks/guard.sh" <<'EOF'
#!/usr/bin/env bash
# A core hook the consumer will harden in place.
set -uo pipefail
echo "core baseline behaviour, unchanged across the range"
CONSUMER_GUARD_ANCHOR_ONE="a substantive line the consumer added first"
CONSUMER_GUARD_ANCHOR_TWO="a second substantive line the consumer added"
CONSUMER_GUARD_ANCHOR_THREE="a third substantive line the consumer added"
CONSUMER_GUARD_ANCHOR_FOUR="a fourth substantive line the consumer added"
EOF

git -C "$CONS" add -A
git -C "$CONS" commit -qm installed

printf '%s\n' "$ROOT"
