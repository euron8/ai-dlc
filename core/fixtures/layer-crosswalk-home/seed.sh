#!/usr/bin/env bash
# layer-crosswalk-home — seed a consumer with ONE retired id and NO crosswalk row anywhere.
#
# The subject is where the row LIVES, so the seed's job is to produce a tree in which the row
# is absent from both candidate locations and the id is genuinely retired. Everything the
# fixture asserts is then a function of which file the row is written into.
#
# E16's subject cannot be seen in a working tree — at HEAD, an id renamed into the band and
# an id that never existed are both simply absent. Only the history distinguishes them, so
# this is a history rather than a tree:
#
#   c1  checks/domain.md defines 33 (below the band) and 933
#   c2  33 is renamed to 934; the citation "Check 33" in every gate log is now dangling
#
# The consumer is left with NO row in either location. That is the fixture's zero, and every
# assertion moves it by writing one row somewhere.
#
# Writes a throwaway tree under $1 (default: a mktemp dir) and echoes the path.
set -euo pipefail

ROOT="${1:-$(mktemp -d "${TMPDIR:-/tmp}/layer-crosswalk-home.XXXXXX")}"
CONS="$ROOT/consumer"
SKILL="$CONS/.claude/skills/ai-dlc"
mkdir -p "$SKILL/steps" "$SKILL/extensions/checks" "$SKILL/overrides"

git init -q "$CONS"
git -C "$CONS" config user.email fixture@example.invalid
git -C "$CONS" config user.name  'layer-crosswalk-home fixture'
git -C "$CONS" config commit.gpgsign false
commit() { GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1" \
  git -C "$CONS" -c user.email=fixture@example.invalid -c user.name=fixture \
    commit -q --no-verify -m "$2"; }

# THE CONSUMER CARRIES THE CONTRACT, and here that is load-bearing twice over rather than
# once. E17 reads each entry's `conforms_to` receipt against `contract_version`, as in every
# sibling fixture — and as of contract version 11 the same file also declares
# `consumer_crosswalk_file:`, which is the path this whole fixture is about. Copying the
# shipping contract rather than writing a synthetic one is what keeps the fixture's notion of
# where the table lives from drifting away from the distribution's.
#
# Rooted at this seed's OWN location with both layouts named, never derived from another
# resolved path: I33 fails the build on the second shape, and this fixture runs in both trees.
HERE="$(cd "$(dirname "$0")" && pwd)"
for _lc in "$HERE/../../skills/ai-dlc/layer-contract.yaml" \
           "$HERE/../../../core/skills/ai-dlc/layer-contract.yaml" \
           "$HERE/../../../.claude/skills/ai-dlc/layer-contract.yaml"; do
  [ -f "$_lc" ] && { cp "$_lc" "$SKILL/layer-contract.yaml"; break; }
done
[ -f "$SKILL/layer-contract.yaml" ] || { echo "SEED ERROR: cannot locate layer-contract.yaml" >&2; exit 2; }
CV="$(awk '/^contract_version:/{print $2; exit}' "$SKILL/layer-contract.yaml")"
[ -n "$CV" ] || { echo "SEED ERROR: no contract_version in the copied layer-contract.yaml" >&2; exit 2; }

# The declared path, read from the copy the consumer will actually be linted against. The
# seed does NOT know this string; if it did, the fixture would assert against its own literal
# and pass on a tree where the declaration had moved.
CW_REL="$(sed -n 's/^consumer_crosswalk_file:[[:space:]]*//p' "$SKILL/layer-contract.yaml" | head -1 | sed 's/[[:space:]]*$//')"
[ -n "$CW_REL" ] || { echo "SEED ERROR: the copied layer-contract.yaml declares no consumer_crosswalk_file:" >&2; exit 2; }
mkdir -p "$CONS/$(dirname "$CW_REL")"

receipt() { # receipt <entry-file>
  awk -v cv="$CV" 'NR==1 && $0=="---" { print; print "conforms_to: " cv; next } { print }' "$1" > "$1.r" \
    && mv "$1.r" "$1"
}

cat > "$SKILL/steps/gate-validation.md" <<'CORE'
---
name: gate-validation
description: synthetic core catalog for the layer-crosswalk-home fixture
---

# Synthetic gate-validation catalog

### 7. Artifact consistency?
<!-- CHECK_LOADED: 7 -->
Core-only. Present so the hooked file resolves and the rendered rulebook is non-empty.
CORE

# THE RETIRED LOCATION, SEEDED AS CORE SHIPS IT — a documented table with NO data row, and
# the worked example fenced. This is the state a consumer that has never written a row is in,
# and it is what makes "a row found here is consumer-authored" true by construction rather
# than by subtraction. The fixture mutates this file to prove both halves of that claim.
cat > "$SKILL/extensions/README.md" <<'RM'
# extensions/ — synthetic entry contract for the layer-crosswalk-home fixture

## Catalog crosswalk table

The table does not live in this file. A worked example follows, fenced, because the reader
harvests column 1 of every pipe table it is given and a fenced example must contribute
nothing.

```markdown
| your id | label | title | resolves a bare citation written before | notes |
|---|---|---|---|---|
| 24 | `[ext:example]` | A worked example that must NOT resolve anything | (illustration) | fenced |
```
RM

cat > "$SKILL/extensions/checks/domain.md" <<'EXT'
---
kind: check
hooks: steps/gate-validation.md
id: domain
push_candidate: false
---

### 33. Cross-story test-strategy deliverable presence.
Allocated below the band. The migration renames it to 934, and every gate log written
while it was live cites a bare "Check 33" that no rename can reach.

### 933. In-band allocation, present from the start.
Never retired. The control that keeps "everything reports" from scoring as a pass.
EXT
receipt "$SKILL/extensions/checks/domain.md"

git -C "$CONS" add -A
commit '2026-03-02T09:00:00+00:00' 'layer: the consumer catalog before the migration'

# --- c2: the migration, with NO crosswalk row written anywhere ------------------
cat > "$SKILL/extensions/checks/domain.md" <<'EXT2'
---
kind: check
hooks: steps/gate-validation.md
id: domain
push_candidate: false
---

### 933. In-band allocation, present from the start.
Never retired.

### 934. Cross-story test-strategy deliverable presence.
This IS the old 33, renamed into the band. The old id is now a dangling citation and no
row resolves it — in either location.
EXT2
receipt "$SKILL/extensions/checks/domain.md"

git -C "$CONS" add -A
commit '2026-06-11T09:00:00+00:00' 'layer: migrate 33 into the band, writing no crosswalk row'

printf '%s\n' "$ROOT"
