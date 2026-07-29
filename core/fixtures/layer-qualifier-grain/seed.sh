#!/usr/bin/env bash
# seed.sh — a REAL distribution git repo and a REAL consumer tree for the
# `extends:` / `kind: qualifier` grain.
#
# Everything below is written to disk and committed. A seed that PRINTS a
# description of a fixture instead of writing one cannot fail, and v0.48.0
# shipped three of those.
#
# The distribution carries two commits:
#
#   BASE    steps/demo.md defines Alpha, Beta, Gamma, Delta
#   THEIRS  ONLY Gamma's body changes, and Delta's HEADING is renamed
#
# That shape is what makes the load-bearing assertion possible: an entry
# anchored to Alpha must go quiet across a range in which the file it hooks
# demonstrably changed. If the seed changed the whole file, "no anchor drift"
# would be unprovable, and if it changed nothing, the assertion would pass
# against a classifier that had simply stopped running.
#
# Prints the sandbox root on stdout.
set -euo pipefail

ROOT="$(mktemp -d)"
DIST="$ROOT/dist"
CONS="$ROOT/consumer"

SKILL_REL="core/skills/ai-dlc"
mkdir -p "$DIST/$SKILL_REL/steps"
git -C "$DIST" init -q
git -C "$DIST" config user.email f@x
git -C "$DIST" config user.name f

# ---------------------------------------------------------------------------
# The distribution at BASE.
# ---------------------------------------------------------------------------
# `Beta` exists purely as a heading for the REVERSE-arm assertion: an anchor
# that CONTAINS this heading resolves only by the reverse containment arm, which
# silently widens the span to the whole section.
cat > "$DIST/$SKILL_REL/steps/demo.md" <<'EOF'
# Demo step

## Alpha gate

Alpha's body. UNCHANGED across BASE..THEIRS on purpose: this is the span the
load-bearing assertion anchors to, so if anything here moved the assertion
would be proving nothing.

## Beta

Beta's body. The heading is deliberately short so an anchor that contains it
resolves by the reverse arm.

## Gamma review

Gamma's body at BASE.

## Delta handoff

Delta's body. Its HEADING is renamed at THEIRS, which is how a declared anchor
stops resolving upstream.
EOF

git -C "$DIST" add -A
git -C "$DIST" commit -qm "base"

# ---------------------------------------------------------------------------
# The distribution at THEIRS: Gamma's body changes, Delta's heading is renamed.
# Alpha and Beta are byte-identical.
# ---------------------------------------------------------------------------
cat > "$DIST/$SKILL_REL/steps/demo.md" <<'EOF'
# Demo step

## Alpha gate

Alpha's body. UNCHANGED across BASE..THEIRS on purpose: this is the span the
load-bearing assertion anchors to, so if anything here moved the assertion
would be proving nothing.

## Beta

Beta's body. The heading is deliberately short so an anchor that contains it
resolves by the reverse arm.

## Gamma review

Gamma's body at THEIRS — REWRITTEN. This is the only body that moves.

## Epsilon handoff

Delta's body. Its HEADING is renamed at THEIRS, which is how a declared anchor
stops resolving upstream.
EOF

git -C "$DIST" add -A
git -C "$DIST" commit -qm "theirs: rewrite Gamma, rename Delta -> Epsilon"

# ---------------------------------------------------------------------------
# The consumer. Core files are the BASE copies, as an installed tree would have.
# ---------------------------------------------------------------------------
CSKILL="$CONS/.claude/skills/ai-dlc"
mkdir -p "$CSKILL/extensions" "$CSKILL/overrides" "$CSKILL/steps" "$CONS/.claude/team-roles"
git -C "$DIST" show "HEAD~1:$SKILL_REL/steps/demo.md" > "$CSKILL/steps/demo.md"

# A team-role core file, for the "extends: names a file hooks: does not" arm.
cat > "$CONS/.claude/team-roles/dev.md" <<'EOF'
# Dev

## Identity

Dev identity prose.
EOF

ext() { # ext <basename> <frontmatter-body>
  local n="$1"; shift
  { printf -- '---\n'; printf '%s\n' "$1"; printf -- '---\n\n'
    printf '### 901. [ext:%s] Consumer entry.\n\nBody.\n' "$n"
  } > "$CSKILL/extensions/$n.md"
}

# --- the four pull-time subjects -------------------------------------------
# Anchored AWAY from the change. THE LOAD-BEARING ONE.
ext anchored-elsewhere "kind: step-domain
hooks: steps/demo.md
id: anchored-elsewhere
push_candidate: false
extends: '#Alpha gate'"

# Anchored AT the change.
ext anchored-at-change "kind: step-domain
hooks: steps/demo.md
id: anchored-at-change
push_candidate: false
extends: '#Gamma review'"

# No anchor at all — file grain must be preserved for entries that declare none.
ext no-anchor "kind: step-domain
hooks: steps/demo.md
id: no-anchor
push_candidate: false"

# Anchor that stops resolving upstream.
ext anchor-vanished "kind: step-domain
hooks: steps/demo.md
id: anchor-vanished
push_candidate: false
extends: '#Delta handoff'"

# A well-formed qualifier. The DISCRIMINATION CONTROL for every authoring arm:
# it declares every new key correctly and must draw no error at all.
ext good-qualifier "kind: qualifier
hooks: steps/demo.md
id: good-qualifier
push_candidate: false
extends: '#Alpha gate'
position: append"

# ---------------------------------------------------------------------------
# A SECOND consumer, carrying one malformed entry per authoring arm.
#
# Separate from the first on purpose. The clean tree above has to be assertable
# as "zero errors" — that is the only thing that proves these arms discriminate
# rather than firing on every entry that declares the new keys. Mixing the two
# would make the clean assertion unwritable.
# ---------------------------------------------------------------------------
BAD="$ROOT/bad-consumer"
BSKILL="$BAD/.claude/skills/ai-dlc"
mkdir -p "$BSKILL/extensions" "$BSKILL/overrides" "$BSKILL/steps" "$BAD/.claude/team-roles"
cp "$CSKILL/steps/demo.md" "$BSKILL/steps/demo.md"
cp "$CONS/.claude/team-roles/dev.md" "$BAD/.claude/team-roles/dev.md"

bad_ext() { # bad_ext <basename> <frontmatter-body>
  local n="$1"; shift
  { printf -- '---\n'; printf '%s\n' "$1"; printf -- '---\n\n'
    printf '### 902. [ext:%s] Consumer entry.\n\nBody.\n' "$n"
  } > "$BSKILL/extensions/$n.md"
}

# E10 — a kind the loader routes nowhere. Spelled as a plausible TYPO of a real
# kind, because that is the shape this arm actually meets.
bad_ext bad-kind "kind: qualifer
hooks: steps/demo.md
id: bad-kind
push_candidate: false"

# E11 — anchor matches no heading.
bad_ext extends-nomatch "kind: step-domain
hooks: steps/demo.md
id: extends-nomatch
push_candidate: false
extends: '#No Such Heading Anywhere'"

# E11 — anchor resolves ONLY by the reverse arm: it CONTAINS core's '## Beta'.
bad_ext extends-reverse "kind: step-domain
hooks: steps/demo.md
id: extends-reverse
push_candidate: false
extends: '#Beta plus words core does not have'"

# E11 — the anchor's file is not the file this entry hooks.
bad_ext extends-otherfile "kind: role
hooks: team-roles/dev.md
id: extends-otherfile
push_candidate: false
extends: 'steps/demo.md#Alpha gate'"

# E11 — two anchors, so the entry would have two drift subjects.
bad_ext extends-two "kind: step-domain
hooks: steps/demo.md
id: extends-two
push_candidate: false
extends: '#Alpha gate, #Gamma review'"

# E11 — a file with no '#anchor' narrows nothing while reading as though it did.
bad_ext extends-noanchor "kind: step-domain
hooks: steps/demo.md
id: extends-noanchor
push_candidate: false
extends: 'steps/demo.md'"

# E12 — a qualifier declaring neither of the two keys its grain requires.
bad_ext qualifier-bare "kind: qualifier
hooks: steps/demo.md
id: qualifier-bare
push_candidate: false"

# E12 — position: on a kind that does not render inside a core section.
bad_ext position-on-step "kind: step-domain
hooks: steps/demo.md
id: position-on-step
push_candidate: false
position: append"

# E14 — gate_types: on a kind nothing loads from a GATE_MANIFEST row. Seeded on a
# DIFFERENT kind from position-on-step above, so a linter arm that keyed on the kind
# rather than on the key would fail one of the two.
bad_ext gate-types-on-role "kind: role
hooks: team-roles/dev.md
id: gate-types-on-role
push_candidate: false
gate_types: retro"

# E13 — a position outside the two-value vocabulary.
bad_ext position-bad "kind: qualifier
hooks: steps/demo.md
id: position-bad
push_candidate: false
extends: '#Alpha gate'
position: middle"

printf '%s\n' "$ROOT"
