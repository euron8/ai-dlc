#!/usr/bin/env bash
# Seed for the anchor-declaration checks in core/scripts/validate-layer-entries.sh (E7/E8/E9)
# and for the per-comma-part widening of E3.
#
# Builds a throwaway CONSUMER tree: a core rulebook with known headings, plus override and
# extension entries that differ ONLY in how they declare their target. Every entry carries a
# well-formed `base_sha` that resolves nowhere, so E1/E2 stay silent and each assertion below is
# attributable to the one thing its entry gets wrong.
#
# THE DIFFERENTIAL. `ok-forward` and `bad-reverse` shadow the SAME core section. One names the
# heading by a prefix of it (the legitimate grain: `Rule 8` for `Rule 8 -- long title`); the other
# names something that CONTAINS the heading (`Escalation Protocol` where core says `Escalation`).
# They must classify differently, and the only difference between them is the direction the
# containment match resolves. A checker that accepts either direction calls both fine.
#
# Usage: seed.sh -> prints the consumer root on one line.
set -eu

TMP="$(mktemp -d "${TMPDIR:-/tmp}/layer-anchor-XXXXXX")"
CONS="$TMP/consumer"
SK="$CONS/.claude/skills/ai-dlc"
mkdir -p "$SK/steps" "$SK/overrides" "$SK/extensions" "$CONS/.claude/team-roles"

# A git repo, because the base_sha check asks whether the sha resolves HERE. Without a repo that
# question is unanswerable and the entries would be exercising a different code path than a real
# consumer's.
git -C "$CONS" init -q
git -C "$CONS" config user.email seed@fixture
git -C "$CONS" config user.name seed

cat > "$SK/SKILL.md" <<'EOF'
# SKILL

### Rule 8 -- Run the validation cycle per declared intensity

Core text for rule eight.

### Rule 9 -- Something else

Core text for rule nine.
EOF

cat > "$SK/steps/retro.md" <<'EOF'
# Retro

### Empirical gate validation

Core text under the empirical heading.

### 4a. Close-Out Sweep

Core text under the sweep heading.
EOF

cat > "$CONS/.claude/team-roles/tea.md" <<'EOF'
# TEA

## Identity

Core identity text.

## Escalation

Core escalation text.
EOF

# --- overrides -----------------------------------------------------------------------
# FORWARD, the control: the heading CONTAINS the anchor. Must not error.
cat > "$SK/overrides/SKILL__Rule-8.md" <<'EOF'
---
shadows: SKILL.md#Rule 8
base_sha: abc1234
reason: the control — a legitimate id-prefix anchor
---
Replacement body for rule eight.
EOF

# REVERSE-ONLY: the anchor CONTAINS the heading. Resolves only by the reverse arm, which widens
# the shadow to the whole section without saying so.
cat > "$SK/overrides/team-roles__tea__escalation.md" <<'EOF'
---
shadows: team-roles/tea.md#Escalation Protocol
base_sha: abc1234
reason: names a heading core does not have
---
Replacement body for escalation.
EOF

# NO MATCH AT ALL: the override shadows nothing, so its body never reaches the lead.
cat > "$SK/overrides/steps__retro__ghost.md" <<'EOF'
---
shadows: steps/retro.md#No Such Heading Anywhere
base_sha: abc1234
reason: anchor matches no heading
---
Replacement body that can never render.
EOF

# MULTI-ANCHOR, and the defect is in part TWO. This is the blind spot: the old code ran
# `sed 's/,.*//'` and validated only the first part, so an entry could declare four more anchors
# and none of them was ever checked. Part one is deliberately VALID so the entry looks fine to a
# first-part-only reader.
cat > "$SK/overrides/steps__retro__multi.md" <<'EOF'
---
shadows: steps/retro.md#4a. Close-Out Sweep, steps/retro.md#Empirical gate validation (the paragraph)
base_sha: abc1234
reason: first anchor valid, second anchor reverse-only
---
Replacement body spanning two anchors.
EOF

# FILE-INHERITING MULTI-ANCHOR, and the defect is again in part TWO. `multi` above repeats the
# file on every part; this one states it once and lets the later parts inherit it. Both spellings
# are live on the reference consumer, and only the repeated one survived the per-part widening:
# `${part%%#*}` is EMPTY for a bare `#anchor`, so the emptiness skip fired BEFORE any anchor check
# ran. Part one is deliberately VALID, so an entry-level reader still sees nothing wrong.
cat > "$SK/overrides/steps__retro__inherit.md" <<'EOF'
---
shadows: steps/retro.md#4a. Close-Out Sweep, #No Such Inherited Heading
base_sha: abc1234
reason: file stated once, second anchor inherits it and matches nothing
---
Replacement body spanning two anchors, one file.
EOF

# NOTHING TO INHERIT: the FIRST part is a bare anchor, so no part ever names a file. Every file
# and anchor check on this entry was skipped in silence — the same disappearance one step earlier.
cat > "$SK/overrides/steps__retro__orphan.md" <<'EOF'
---
shadows: #Orphan Anchor With No File
base_sha: abc1234
reason: no comma-part names a target file
---
Replacement body with no resolvable target.
EOF

# MISSING `reason:` — the key the contract required and nothing read.
cat > "$SK/overrides/SKILL__Rule-9.md" <<'EOF'
---
shadows: SKILL.md#Rule 9
base_sha: abc1234
---
Replacement body with no stated reason.
EOF

# --- extensions ----------------------------------------------------------------------
cat > "$SK/extensions/ok-extension.md" <<'EOF'
---
kind: step-domain
hooks: steps/retro.md
id: ok-extension
push_candidate: false
---
### 900. [ext:ok-extension] An additive consumer rule.
EOF

# MISSING `push_candidate:` — invisible to the push queue in both directions.
cat > "$SK/extensions/no-flag.md" <<'EOF'
---
kind: step-domain
hooks: steps/retro.md
id: no-flag
---
### 901. [ext:no-flag] Another additive consumer rule.
EOF

printf '%s\n' "$CONS"
