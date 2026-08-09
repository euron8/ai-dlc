#!/usr/bin/env bash
# layer-artifact-path-prescriptions — seed a consumer whose layer entries PRESCRIBE artifact
# paths, in every form LC-R4 / W11 has to tell apart.
#
# THE SUBJECT IS PROSE, NOT A TREE. This consumer's real filenames are irrelevant to the clause
# and the seed deliberately writes none of the artifacts it names: the reported case on the
# reference consumer was a path that RESOLVED, so a fixture that made conformance depend on
# whether the file exists would be testing the check the derivation refuted.
#
# THE FIRING CASES, one per reason:
#
#   s<N>-carry-over-evaluation.md   sprint token in a basename, PLACEHOLDER form
#                                   -> the load-bearing one. The digits-only `--token-re`
#                                      matches it NOT AT ALL, and mutant M1 is that swap.
#   docs/retro/sprint-249.md        sprint token in a basename, DIGITS form, and under a
#                                   different scan root -- so a corpus that reads one root
#                                   reports one of these two and looks complete.
#   planning-artifacts/stories/     the story corpus off its declared location. Carries NO
#                                   sprint token at all, so the first arm cannot see it; its
#                                   defect is a MISSING slot rather than a misplaced one.
#
# THE SILENT CASES ARE FIVE DIFFERENT REASONS, which is why each gets its own assertion:
#
#   planning-artifacts/s<N>/stories/     the corpus, correctly slotted   -> the story arm's control
#   planning-artifacts/prd.md            an area-root durable            -> no sprint to misplace
#   _bmad-output/pipeline-snapshot.md    a root singleton                -> the grammar says it is
#                                                                           not an artifact path
#   a fenced non-conforming path         inside ``` ```                  -> the stated skip cost
#   docs/coding-conventions.md           outside every scan root         -> not this arm's subject
#
# Writes a throwaway tree under $1 (default: a mktemp dir) and echoes the path.
set -euo pipefail

ROOT="${1:-$(mktemp -d "${TMPDIR:-/tmp}/layer-apaths.XXXXXX")}"
CONS="$ROOT/consumer"
SKILL="$CONS/.claude/skills/ai-dlc"
mkdir -p "$SKILL/steps" "$SKILL/extensions/steps-domain" "$SKILL/extensions/roles" \
         "$SKILL/overrides" "$CONS/.claude/schemas" "$CONS/docs"

# A CONSUMER IS A GIT REPO. Two sibling fixtures asserted "a well-formed consumer lints clean"
# against a tree with no git in it, and E16's refusal then read as a regression.
git init -q "$CONS"
git -C "$CONS" config user.email fixture@example.invalid
git -C "$CONS" config user.name  'layer-artifact-path-prescriptions fixture'
git -C "$CONS" config commit.gpgsign false

# ROOTED AT THIS SEED'S OWN LOCATION, both layouts named. I33 fails the build on a fixture that
# reaches a core subtree by walking up from a path some other resolver produced.
HERE="$(cd "$(dirname "$0")" && pwd)"
copy_in() { # copy_in <relative-core-path> <destination>
  local rel="$1" dst="$2" c
  for c in "$HERE/../../$rel" "$HERE/../../../core/$rel" "$HERE/../../../.claude/$rel"; do
    [ -f "$c" ] && { cp "$c" "$dst"; return 0; }
  done
  return 1
}

copy_in "skills/ai-dlc/layer-contract.yaml" "$SKILL/layer-contract.yaml" \
  || { echo "SEED ERROR: cannot locate layer-contract.yaml" >&2; exit 2; }

# THE GRAMMAR AND THE SCHEMA ARE COPIED, NEVER RESTATED. The arm resolves its scan roots from
# the first and the story corpus template from the second; a seed that wrote its own copy of
# either would test the fixture's opinion of the declaration rather than the declaration.
copy_in "skills/ai-dlc/artifact-path-grammar.md" "$SKILL/artifact-path-grammar.md" \
  || { echo "SEED ERROR: cannot locate artifact-path-grammar.md" >&2; exit 2; }
copy_in "schemas/sprint-status.json" "$CONS/.claude/schemas/sprint-status.json" \
  || { echo "SEED ERROR: cannot locate schemas/sprint-status.json" >&2; exit 2; }

CV="$(awk '/^contract_version:/{print $2; exit}' "$SKILL/layer-contract.yaml")"
[ -n "$CV" ] || { echo "SEED ERROR: no contract_version in the copied layer-contract.yaml" >&2; exit 2; }

receipt() { # receipt <entry-file>
  awk -v cv="$CV" 'NR==1 && $0=="---" { print; print "conforms_to: " cv; next } { print }' "$1" > "$1.r" \
    && mv "$1.r" "$1"
}

cat > "$SKILL/SKILL.md" <<'EOF'
# ai-dlc

## Rule 27 -- Layers
Extensions are additive.
EOF

cat > "$SKILL/steps/carry-over-evaluation.md" <<'EOF'
# Carry-over evaluation

### 1. Read the backlog
EOF

cat > "$SKILL/steps/retro.md" <<'EOF'
# Retro

### 1. Gather
EOF

# --- FIRING: a sprint token in a basename, written as a PLACEHOLDER ------------------------
cat > "$SKILL/extensions/steps-domain/carry-over-domain.md" <<'EOF'
---
kind: step-domain
hooks: steps/carry-over-evaluation.md
id: carry-over-domain
---

## Carry-over evaluation, this project's shape

Write the evaluation to `_bmad-output/planning-artifacts/s<N>-carry-over-evaluation.md` and
read the previous one from the same place.
EOF
receipt "$SKILL/extensions/steps-domain/carry-over-domain.md"

# --- FIRING: a sprint token in a basename, DIGITS form, under a DIFFERENT scan root --------
# Two roots and two spellings, so a reader that covers one of either still leaves a subject
# behind. The first cut of this arm read one scan root and reported one of these two.
cat > "$SKILL/extensions/roles/qa-domain.md" <<'EOF'
---
kind: role
hooks: team-roles/qa.md
id: qa-domain
---

## Prior art

The convention was settled in `docs/retro/sprint-249.md`; read it before proposing a change.
EOF
receipt "$SKILL/extensions/roles/qa-domain.md"

# --- FIRING: the story corpus, off its declared location -----------------------------------
# NO sprint token anywhere in this path, which is what makes it invisible to the first arm.
cat > "$SKILL/extensions/roles/tea-domain.md" <<'EOF'
---
kind: role
hooks: team-roles/tea.md
id: tea-domain
---

## Context Loading

Read, in order:

1. `_bmad-output/planning-artifacts/prd.md`
2. `_bmad-output/planning-artifacts/stories/`
3. `docs/coding-conventions.md`
EOF
receipt "$SKILL/extensions/roles/tea-domain.md"

# --- SILENT: every conforming form, plus the two the grammar puts outside its scope ---------
cat > "$SKILL/overrides/steps__retro__domain-sections.md" <<'EOF'
---
kind: step-override
shadows: steps/retro.md#1. Gather
base_sha: 0000000
id: retro-domain-sections
reason: this project reads its stories from the slot and its snapshot from the root
---

## 1. Gather, this project's shape

The sprint's stories are in `_bmad-output/planning-artifacts/s<N>/stories/`, the durable brief is
`_bmad-output/planning-artifacts/prd.md`, and the live pipeline state is
`_bmad-output/pipeline-snapshot.md`.

An example of the spelling this project has RETIRED, kept as narration inside a fence so it is
not read as a prescription:

```
_bmad-output/planning-artifacts/s<N>-retro-draft.md
```
EOF
receipt "$SKILL/overrides/steps__retro__domain-sections.md"

git -C "$CONS" add -A >/dev/null 2>&1
git -C "$CONS" commit -qm "seed" >/dev/null 2>&1

printf '%s\n' "$ROOT"
