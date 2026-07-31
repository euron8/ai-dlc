#!/usr/bin/env bash
# layer-retired-id-crosswalk — seed a consumer whose GIT HISTORY carries a renumber.
#
# E16's subject cannot be seen in a working tree. At HEAD, an id that was renamed into
# the band and an id that never existed look exactly the same: absent. Only the history
# says one of them used to be there, and only the history says a gate log written last
# year cites it. So the seed is a history, not a tree.
#
#   c1  the consumer's layer, before any migration
#         checks/domain.md   33.  34.  5.   933.
#         checks/sibling.md  70.
#   c2  the migration, and it produces all three cases E16 has to tell apart
#         domain.md  33. -> 933.   RETIRED and unresolvable  -> ERROR, no crosswalk row
#         domain.md  34. dropped   but sibling.md picks it up -> resolvable, silent
#         domain.md  5.  dropped   but CORE defines 5         -> resolvable, silent
#
# The two silent cases are the whole reason this fixture exists. A first cut of E16 asked
# "did an id leave THIS entry" and reported 32 subjects on the reference consumer, 25 of
# them wrong — every one an entry that had stopped restating a core section. A citation
# of an id core still defines resolves; that is core being the source of truth, not an
# exclusion from it.
#
# Writes a throwaway tree under $1 (default: a mktemp dir) and echoes the path.
set -euo pipefail

ROOT="${1:-$(mktemp -d "${TMPDIR:-/tmp}/layer-retired-id.XXXXXX")}"
CONS="$ROOT/consumer"
SKILL="$CONS/.claude/skills/ai-dlc"
mkdir -p "$SKILL/steps" "$SKILL/extensions/checks" "$SKILL/overrides"

git init -q "$CONS"
git -C "$CONS" config user.email fixture@example.invalid
git -C "$CONS" config user.name  'layer-retired-id fixture'
git -C "$CONS" config commit.gpgsign false
commit() { GIT_AUTHOR_DATE="$1" GIT_COMMITTER_DATE="$1" \
  git -C "$CONS" -c user.email=fixture@example.invalid -c user.name=fixture \
    commit -q --no-verify -m "$2"; }

# THE CONSUMER CARRIES THE CONTRACT, because an installed one always does — install.sh copies
# layer-contract.yaml beside SKILL.md. E17 reads each entry's `conforms_to` receipt against that
# file's contract_version, and a seed without it would make this fixture assert "a well-formed
# consumer lints clean" against a shape no consumer has. It is COPIED from the shipping file and
# the version is READ back out of the copy, so neither can drift from the real contract.
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

# The entry bodies below are quoted heredocs on purpose — every id in them is literal and must
# stay that way. The receipt is therefore injected after the fact rather than interpolated in.
receipt() { # receipt <entry-file>
  awk -v cv="$CV" 'NR==1 && $0=="---" { print; print "conforms_to: " cv; next } { print }' "$1" > "$1.r" \
    && mv "$1.r" "$1"
}

cat > "$SKILL/steps/gate-validation.md" <<'CORE'
---
name: gate-validation
description: synthetic core catalog for the layer-retired-id-crosswalk fixture
---

# Synthetic gate-validation catalog

### 5. Story status consistency?
<!-- CHECK_LOADED: 5 -->
Core's check 5. It is defined HERE, so an entry that stops defining its own 5 has
retired nothing: the citation still lands, on core.

### 7. Artifact consistency?
<!-- CHECK_LOADED: 7 -->
Core-only.
CORE

cat > "$SKILL/extensions/README.md" <<'RM'
# extensions/ — synthetic entry contract for the layer-retired-id-crosswalk fixture

## Catalog crosswalk table (every namespace)

| your id | label | title | resolves a bare citation written before | notes |
|---|---|---|---|---|
| 70 | `[ext:sibling]` | A row that already exists | (seeded) | present so the reader is proven to parse a table that HAS rows |
RM

cat > "$SKILL/extensions/checks/domain.md" <<'EXT'
---
kind: check
hooks: steps/gate-validation.md
id: domain
push_candidate: false
---

### 33. Cross-story test-strategy deliverable presence.
Allocated below the band. The migration renames it to 933, and every gate log written
while it was live cites a bare "Check 33" that no rename can reach.

### 34. Passive-monitor carry-over ceilings.
The migration drops it here and a SIBLING entry picks it up, so the citation still lands.

### 5. Story status consistency, domain sub-clauses.
The migration drops it here and CORE still defines 5, so the citation still lands.

### 933. In-band allocation, present from the start.
Never retired. The control that keeps "everything reports" from scoring as a pass.
EXT
receipt "$SKILL/extensions/checks/domain.md"

cat > "$SKILL/extensions/checks/sibling.md" <<'SIB'
---
kind: check
hooks: steps/gate-validation.md
id: sibling
push_candidate: false
---

### 70. A sibling entry's own allocation.
SIB
receipt "$SKILL/extensions/checks/sibling.md"

git -C "$CONS" add -A
commit '2026-02-04T09:00:00+00:00' 'layer: the consumer catalog before any migration'

# --- c2: the migration ---------------------------------------------------------
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
This IS the old 33, renamed into the band. The old id is now a dangling citation.
EXT2
receipt "$SKILL/extensions/checks/domain.md"

cat > "$SKILL/extensions/checks/sibling.md" <<'SIB2'
---
kind: check
hooks: steps/gate-validation.md
id: sibling
push_candidate: false
---

### 70. A sibling entry's own allocation.

### 34. Passive-monitor carry-over ceilings.
Moved here from domain.md. The id never left the rulebook, so nothing is retired.
SIB2
receipt "$SKILL/extensions/checks/sibling.md"

git -C "$CONS" add -A
commit '2026-05-19T09:00:00+00:00' 'layer: migrate 33 into the band, move 34 to the sibling, drop the core restatement'

printf '%s\n' "$ROOT"
