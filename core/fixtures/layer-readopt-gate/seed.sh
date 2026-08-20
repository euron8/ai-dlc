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

## Rule 13 -- Escalation

Multi-paragraph by design. An override shadowing `#Rule 13` replaces ALL of it, so a
body that rewrites one paragraph and says the rest still governs is false about its
own effect. Unchanged across the range, so the drift arm stays quiet and the survival
claim is the only thing that can speak.

The adjudication order, the freeze semantics, and the record format live here, in the
paragraphs an override of this rule silently drops.

## Rule 14 -- Budget

Shadowed by an override whose survival claim is about the rest of the FILE, which is
TRUE for a single-section shadow. The control for the noun restriction.

## Rule 15 -- Gating

Shadowed by an override whose survival vocabulary names a DIFFERENT unit (Rule 9) and
its own body. The control for the measured false-positive class.

## Rule 16 -- Recording

Multi-paragraph, shadowed by an override whose survival claim WRAPS across a newline --
the shape that returns a false zero to any line-based predicate.

The ordering guarantee and the retention window live here, in the paragraphs that entry
silently drops.

## Rule 17 -- Reserved For The Duplicate Pair

Claimed by TWO override entries at once, and by nothing else in this fixture. Every other
rule here is shadowed by an entry some later assertion writes, so a duplicate seeded on one
of those counts a claimant the seed never declared -- which is exactly how the first draft
of the double-shadow assertion read 3 rows where it wanted 2.

## Rule 18 -- Close-Out

Claimed by ONE entry whose body carries a SECOND same-level section that no anchor names.
Unchanged base..theirs, so the entry stays OVERRIDE-OK and the unclaimed row cannot be
mistaken for a drift row.

## Rule 19 -- Sweep

The near-miss for the same arm: its override nests a sub-heading INSIDE the claimed section.
A heading-set difference would report that child; a span-based claim does not.
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

## Rule 13 -- Escalation

Multi-paragraph by design. An override shadowing `#Rule 13` replaces ALL of it, so a
body that rewrites one paragraph and says the rest still governs is false about its
own effect. Unchanged across the range, so the drift arm stays quiet and the survival
claim is the only thing that can speak.

The adjudication order, the freeze semantics, and the record format live here, in the
paragraphs an override of this rule silently drops.

## Rule 14 -- Budget

Shadowed by an override whose survival claim is about the rest of the FILE, which is
TRUE for a single-section shadow. The control for the noun restriction.

## Rule 15 -- Gating

Shadowed by an override whose survival vocabulary names a DIFFERENT unit (Rule 9) and
its own body. The control for the measured false-positive class.

## Rule 16 -- Recording

Multi-paragraph, shadowed by an override whose survival claim WRAPS across a newline --
the shape that returns a false zero to any line-based predicate.

The ordering guarantee and the retention window live here, in the paragraphs that entry
silently drops.

## Rule 17 -- Reserved For The Duplicate Pair

Claimed by TWO override entries at once, and by nothing else in this fixture. Every other
rule here is shadowed by an entry some later assertion writes, so a duplicate seeded on one
of those counts a claimant the seed never declared -- which is exactly how the first draft
of the double-shadow assertion read 3 rows where it wanted 2.

## Rule 18 -- Close-Out

Claimed by ONE entry whose body carries a SECOND same-level section that no anchor names.
Unchanged base..theirs, so the entry stays OVERRIDE-OK and the unclaimed row cannot be
mistaken for a drift row.

## Rule 19 -- Sweep

The near-miss for the same arm: its override nests a sub-heading INSIDE the claimed section.
A heading-set difference would report that child; a span-based claim does not.
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

# --- LC-O16 / OVERRIDE-BODY-UNCLAIMED -------------------------------------------------
# THE OFFENDER. Two same-level sections in the body, ONE anchor. The appendix is what an
# LC-O15 narrowing leaves behind when it removes an anchor and keeps the text: applied by
# nothing, and still reading as live consumer machinery.
cat > "$CONS/.claude/skills/ai-dlc/overrides/SKILL__Rule-18-unclaimed.md" <<EOF
---
shadows: SKILL.md#Rule 18
base_sha: ${BASE}
reason: consumer close-out machinery; the appendix below is claimed by no anchor.
---

## Rule 18 -- Close-Out (CONSUMER OVERRIDE)

Consumer close-out rules, replacing core's Rule 18 for this project.

## Rule 18 Appendix -- consumer-only sweep

Same heading level as the claimed section above, named by no anchor in \`shadows:\`, so the
body is sliced past it and nothing ever applies it.
EOF

# THE NEAR-MISS. A sub-heading NESTED inside the claimed section. It is inside that anchor's
# span and at a level no claimed heading uses, so both narrowings must hold it silent.
# Without this the offender assertion passes for an arm that reports every child heading.
cat > "$CONS/.claude/skills/ai-dlc/overrides/SKILL__Rule-19-nested.md" <<EOF
---
shadows: SKILL.md#Rule 19
base_sha: ${BASE}
reason: consumer sweep rules; nests a detail heading inside its own claimed section.
---

## Rule 19 -- Sweep (CONSUMER OVERRIDE)

Consumer sweep rules, replacing core's Rule 19.

### a nested detail this claimed section owns

Inside the span the anchor claims, so it is claimed with it.
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

# --- OVERRIDE-ASSERTS-SHADOW-SURVIVES ------------------------------------------------
# THE DEFECT. This body rewrites ONE paragraph of the section it shadows and states that the
# rest of that section still governs. Precedence replaces the whole span, so the sentence is
# false about the entry's own effect. Like the delegation pair above, this shadows an
# UNCHANGED section and is therefore OVERRIDE-OK on the drift arm -- both of the real
# instances were, which is why the question has to be asked separately.
#
# The claim sits entirely on ONE line here, so this entry stays reportable whether or not
# the detector flattens. That keeps it independent of the wrap entry below -- otherwise one
# mutation would fail two assertions and one of them would be vacuous.
cat > "$CONS/.claude/skills/ai-dlc/overrides/SKILL__Rule-13-survives.md" <<EOF
---
shadows: SKILL.md#Rule 13
base_sha: ${BASE}
reason: consumer-specific escalation threshold; the rest of the rule is core's.
---

## Rule 13 -- Escalation (CONSUMER OVERRIDE)

The escalation-threshold paragraph of Rule 13 is replaced for this consumer: escalate at
three failures rather than two.

The rest of the section is unchanged and still governs.
EOF

# THE WRAP, ISOLATED IN ITS OWN ENTRY. The claim splits across a newline between "Every
# other part of" and "Rule 16", exactly where the reference consumer's second instance
# splits. Layer bodies are hard-wrapped at ~72 columns, so a line-based predicate returns
# ZERO on the real shape -- an absence indistinguishable from compliance. This entry is the
# only thing that fails if the detector stops flattening the body.
cat > "$CONS/.claude/skills/ai-dlc/overrides/SKILL__Rule-16-wrapped.md" <<EOF
---
shadows: SKILL.md#Rule 16
base_sha: ${BASE}
reason: consumer-specific record format; claim deliberately wrapped across a newline.
---

## Rule 16 -- Recording (CONSUMER OVERRIDE)

The record-format paragraph of Rule 16 is replaced for this consumer. Every other part of
Rule 16 — the ordering guarantee and the retention window — is core's and is unchanged.
EOF

# CONTROL 1 — the shape the grain warning names as LEGITIMATE. An override that shadows one
# section and says the rest of the FILE is unchanged is telling the truth, and it uses the
# same survival vocabulary. It must stay SILENT. Without this the noun restriction is
# untested and could be widened to any survival claim with every assertion still green.
cat > "$CONS/.claude/skills/ai-dlc/overrides/SKILL__Rule-14-file-claim.md" <<EOF
---
shadows: SKILL.md#Rule 14
base_sha: ${BASE}
reason: consumer-specific budget; scoped claim is about the rest of the FILE, which is true.
---

## Rule 14 -- Budget (CONSUMER OVERRIDE)

This consumer raises the budget ceiling. The rest of the file is unchanged and still
governs; only this rule is replaced.
EOF

# CONTROL 2 — survival vocabulary whose subject is a DIFFERENT named unit. This is the
# measured false-positive class: on the reference consumer, "(Rule 5 fast-track still
# applies)" inside an override of Rule 8. Must stay SILENT.
cat > "$CONS/.claude/skills/ai-dlc/overrides/SKILL__Rule-15-other-unit.md" <<EOF
---
shadows: SKILL.md#Rule 15
base_sha: ${BASE}
reason: consumer-specific gating; references a neighbouring rule that is untouched.
---

## Rule 15 -- Gating (CONSUMER OVERRIDE)

This consumer gates on the adversarial pass only. Rule 9 still applies unchanged, and the
audit basis recorded below holds unchanged for this consumer.
EOF

# LOOSE ANCHOR — the anchor CONTAINS the heading rather than the other way round, so it
# resolves only by the REVERSE arm and silently widens the shadow to the WHOLE of Rule 11.
# E7 errors on this at authoring time; that validator is consumer-run and SKIPPABLE, and the
# pull is not, which is the only reason the pull-time counterpart exists.
#
# NO COMMA IN THE ANCHOR. `shadows:` is comma-separated, so "…Shadow, second paragraph" would
# parse as a second TARGET FILE named `second paragraph` and this entry would test the wrong
# thing while still looking like a loose anchor to a reader.
cat > "$CONS/.claude/skills/ai-dlc/overrides/SKILL__Rule-11-loose.md" <<EOF
---
shadows: SKILL.md#Rule 11 -- Outside The Shadow and its second paragraph
base_sha: ${BASE}
reason: consumer wants only the second paragraph; the anchor names something finer than a heading.
---

## Rule 11 -- Outside The Shadow (CONSUMER OVERRIDE)

The consumer's replacement for one paragraph of Rule 11.
EOF

# DOUBLE SHADOW — two entries claiming ONE (file, anchor). Each is well-formed alone; only the
# PAIR is the finding, which is why the check runs across entries after the loop. Rule 7 is
# unchanged base..theirs, so both stay OVERRIDE-OK on the drift arm and the new status cannot be
# mistaken for a drift row.
#
# Both bodies are deliberately plain: a backticked construct would also trip the delegation arm
# and survival vocabulary would trip the assertion arm, and either would make one mutation fail
# two assertions.
cat > "$CONS/.claude/skills/ai-dlc/overrides/SKILL__Rule-7-dup-a.md" <<EOF
---
shadows: SKILL.md#Rule 17
base_sha: ${BASE}
reason: consumer narrows rule seven; the first of two entries claiming this anchor.
---

## Rule 7 -- Something Else (CONSUMER OVERRIDE A)

The consumer's replacement text for rule seven.
EOF

cat > "$CONS/.claude/skills/ai-dlc/overrides/SKILL__Rule-7-dup-b.md" <<EOF
---
shadows: SKILL.md#Rule 17
base_sha: ${BASE}
reason: consumer adds a second condition to rule seven; the second entry claiming this anchor.
---

## Rule 7 -- Something Else (CONSUMER OVERRIDE B)

A second replacement text for rule seven, from a different entry.
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
