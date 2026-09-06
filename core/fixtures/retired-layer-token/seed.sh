#!/usr/bin/env bash
# retired-layer-token/seed.sh — build two throwaway dist repos, two consumer trees, a
# neutral cwd and a TRAP cwd, then echo the workspace path. The detector resolves its
# rulebook and program lists from its OWN directory, so the seeded dists must place files
# at the real declared paths (`setup-sites.md`'s `rulebook:` list and the script's own
# `program_globs`), not at invented ones.
set -euo pipefail

# Resolve the PROJECT ROOT and then name the full path in each layout — never walk up from
# here into a core subtree (I33). Done before any `cd`, or a relative invocation breaks it.
HERE="$(cd "$(dirname "$0")" && pwd)"
D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/skills/ai-dlc-update/reconcile/retired-layer-token.sh" ]; then
  SCRIPT="$D_ROOT/core/skills/ai-dlc-update/reconcile/retired-layer-token.sh"
elif [ -n "$D_ROOT" ] && [ -f "$D_ROOT/.claude/skills/ai-dlc-update/reconcile/retired-layer-token.sh" ]; then
  SCRIPT="$D_ROOT/.claude/skills/ai-dlc-update/reconcile/retired-layer-token.sh"
else
  echo "FIXTURE ERROR: retired-layer-token.sh not found in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d)"
WORK="$(cd "$WORK" && pwd)"
DIST="$WORK/dist"
DIST2="$WORK/dist-no-programs"
CONS="$WORK/consumer"
CLEANC="$WORK/clean-consumer"
NEUTRAL="$WORK/neutral"
TRAP_CWD="$WORK/trap-cwd"

mkdir -p "$DIST/core/skills/ai-dlc/steps" "$DIST/core/team-roles" \
         "$DIST/core/scripts" "$DIST/core/hooks" \
         "$DIST/core/skills/ai-dlc-update/reconcile" "$NEUTRAL"
git -C "$DIST" init -q . 2>/dev/null
git -C "$DIST" config user.email f@f
git -C "$DIST" config user.name f

# --- BASE ------------------------------------------------------------------------------
# SKILL.md is a NON-GLOB rulebook entry carrying a word present at both refs. It is what
# keeps the base set non-empty when the two GLOB entries resolve to nothing, so the `set -f`
# world lands on the silent "retired NO token" branch rather than on the refusal — the
# quiet state that actually reads as coverage.
cat > "$DIST/core/skills/ai-dlc/SKILL.md" <<'EOF'
# Engine skill

The lead ALWAYS records the verdict before dispatching.

The `MOVER-TOKEN` is recorded once the sprint closes.
EOF

# VACUOUS is written BARE — no code span — because that is how the motivating base wrote
# it, and it is why the derivation cannot key on backticks. Every OTHER word here is
# backticked, so the backtick mutant flips the two incident arms and nothing else.
cat > "$DIST/core/skills/ai-dlc/steps/demo.md" <<'EOF'
# Demo step

## Verdicts

When the corpus is empty the run is VACUOUS (exit 78) and the gate stops there.

An `APPROVED-WITH-FIXES` verdict is written by the reviewer before the sprint closes.

A `DEFERRED` item is carried to the next sprint.

`NEVER` promote a plan that has not been rehearsed.

A `STALE` entry is dropped by the rotator.

The `LEDGER-ROW` is appended once the gate is green.

This threshold was MEASURED on the reference consumer and is not a guess.

The MEASURED floor holds across every release band.

Status ABC is short but printed by the gate.
EOF

cat > "$DIST/core/team-roles/role.md" <<'EOF'
# Reviewer role

The reviewer reads the ledger and reports.
EOF

# THE WITNESS. A core program prints the status word in a NON-COMMENT line at base and a
# different one at theirs, which is what separates a status from a shout. It also prints the
# THREE-letter word, so the grammar's four-character floor is the only thing keeping that
# word out of the retired set — a floor with no program behind it is acquitted anyway and
# proves nothing about the floor.
cat > "$DIST/core/scripts/validate-ci-gates.sh" <<'EOF'
#!/bin/bash
# gate summary
n=0
echo "VACUOUS: $n scanned" >&2
echo "DEFERRED: $n carried" >&2
echo "MEASURED: $n floor" >&2
echo "ABC: $n short" >&2
EOF

# THE UNION REFUTATION. A second program keeps printing the same word at BOTH refs in an
# unrelated sense. Under the shipped per-file witness it contributes nothing; under a union
# at theirs it un-retires the very token this detector exists for.
cat > "$DIST/core/skills/ai-dlc-update/reconcile/readopt-override.sh" <<'EOF'
#!/bin/bash
echo "a VACUOUS anchor is not a finding"
EOF

# A program that names a dropped word only in a COMMENT. Comments are stripped, so this
# witnesses nothing and the word is acquitted as emphasis.
cat > "$DIST/core/hooks/gate.sh" <<'EOF'
#!/bin/bash
# STALE is the old verdict name
exit 0
EOF

git -C "$DIST" add -A
git -C "$DIST" commit -qm base
BASE="$(git -C "$DIST" rev-parse HEAD)"

# --- THEIRS ----------------------------------------------------------------------------
# VACUOUS renamed, and its program witness renames the emitted word too -> RETIRED.
# APPROVED-WITH-FIXES dropped, no program ever carried it -> retired on the JOINED shape.
# DEFERRED dropped, and at theirs the program names it only in a COMMENT -> still RETIRED,
#   because a header documenting a retirement is not an emission.
# NEVER dropped with no program mention anywhere -> acquitted as emphasis.
# STALE dropped, and the only program that ever named it did so in a COMMENT -> acquitted.
# LEDGER-ROW MOVES to another rulebook file, so it is present at theirs and NOT dropped.
# One MEASURED sentence is deleted and the other survives, so a thinned emphasis word is
#   not dropped either. ABC is deleted but is three characters, so the grammar never derived
#   it -- and a core program PRINTS it, so only the floor keeps it out.
cat > "$DIST/core/skills/ai-dlc/steps/demo.md" <<'EOF'
# Demo step

## Verdicts

When the corpus is empty the run EXAMINED NOTHING (exit 78) and the gate stops there.

The MEASURED floor holds across every release band.
EOF

cat > "$DIST/core/team-roles/role.md" <<'EOF'
# Reviewer role

The reviewer reads the ledger and reports.

The `LEDGER-ROW` is appended once the gate is green.
EOF

# SKILL.md loses the second moved token, which lands in a rulebook file that does not exist
# at base. A theirs-side file list taken from the BASE tree cannot see this file, and the
# token then reads as retired — the two moved-token worlds differ by exactly that: one lands
# in a file both refs have, the other in one only theirs has.
cat > "$DIST/core/skills/ai-dlc/SKILL.md" <<'EOF'
# Engine skill

The lead ALWAYS records the verdict before dispatching.
EOF
cat > "$DIST/core/skills/ai-dlc/steps/new-step.md" <<'EOF'
# New step

The `MOVER-TOKEN` is recorded once the sprint closes.
EOF

cat > "$DIST/core/scripts/validate-ci-gates.sh" <<'EOF'
#!/bin/bash
# gate summary
# DEFERRED was renamed this release
# ABC too
n=0
echo "EXAMINED NOTHING: $n scanned" >&2
EOF

cat > "$DIST/core/hooks/gate.sh" <<'EOF'
#!/bin/bash
exit 0
EOF

git -C "$DIST" add -A
git -C "$DIST" commit -qm theirs
THEIRS="$(git -C "$DIST" rev-parse HEAD)"

# --- a dist whose base carries NO program file at all -------------------------------------
# Nothing can witness, and "no witness" must read as UNDECIDED rather than as an acquittal.
# It also drops a JOINED token, so the retired set is NOT empty and the acquittal is carried
# by the DENOMINATOR note — the quiet state that is not the one the base==theirs arm reads.
# Sharing one message between the two arms would make a mutation of that message flip both.
mkdir -p "$DIST2/core/skills/ai-dlc"
git -C "$DIST2" init -q . 2>/dev/null
git -C "$DIST2" config user.email f@f
git -C "$DIST2" config user.name f
# `ALWAYS` is backticked at BOTH refs so this dist's theirs side is non-empty under every
# grammar a mutant below can impose. A theirs side that empties trips the theirs guard, and
# this world would then be measuring that guard instead of the acquittal it exists for.
cat > "$DIST2/core/skills/ai-dlc/SKILL.md" <<'EOF'
# Engine skill

The lead `ALWAYS` records the verdict, and the run is VACUOUS when the corpus is empty.

`NEVER` promote a plan that has not been rehearsed.

The `SPRINT-CLOSE` gate runs last.
EOF
git -C "$DIST2" add -A
git -C "$DIST2" commit -qm base
BASE2="$(git -C "$DIST2" rev-parse HEAD)"
cat > "$DIST2/core/skills/ai-dlc/SKILL.md" <<'EOF'
# Engine skill

The lead `ALWAYS` records the verdict.
EOF
git -C "$DIST2" add -A
git -C "$DIST2" commit -qm theirs
THEIRS2="$(git -C "$DIST2" rev-parse HEAD)"

# --- the consumer's layer files ----------------------------------------------------------
mkdir -p "$CONS/.claude/skills/ai-dlc/overrides" "$CONS/.claude/skills/ai-dlc/extensions"
OV="$CONS/.claude/skills/ai-dlc/overrides"
EX="$CONS/.claude/skills/ai-dlc/extensions"

# TRUE POSITIVE 1 — the incident's first line: the RENDERED body the lead obeys still names
# the retired status word, in the consumer's OWN prose. No core line is reproduced, so the
# passage sibling cannot see it; no contract shape is present, so the contract sibling
# cannot either.
cat > "$OV/body.md" <<'EOF'
---
name: gate-body
---

# Gate body

The rendered body the lead obeys: run the validator, or stock exits 78 VACUOUS; then stop.
EOF

# TRUE POSITIVE 2 — the incident's second line: a grep control in the FRONTMATTER, above
# the closing `---`, citing the same word as a term core carries.
cat > "$EX/front.md" <<'EOF'
---
name: front-control
reason: a grep control shows core still cites VACUOUS as a live term
---

# Front control

This entry's body names no retired word.
EOF

# TRUE POSITIVE 3 — a JOINED token no core program ever printed. Prose emphasis is never
# hyphenated, so the shape alone is the witness.
cat > "$EX/joined.md" <<'EOF'
# Verdict extension

Our reviewer still writes APPROVED-WITH-FIXES on a partial close.
EOF

# TRUE POSITIVE 4 — the word survives at theirs only inside a program COMMENT, which is
# where a retirement gets documented. It is still retired.
cat > "$OV/deferred.md" <<'EOF'
# Carry-over

A DEFERRED item is moved to our own backlog instead.
EOF

# NEAR-MISSES, one per file so a single row cannot cover two of them.
cat > "$OV/nm-lower.md" <<'EOF'
# Lowercase

The run is vacuous when the corpus is empty.
EOF
cat > "$OV/nm-embed.md" <<'EOF'
# Embedded

Our helper fooVACUOUS returns the code, and VACUOUS_X names the file it writes.

fooVACUOUSbar
EOF
cat > "$OV/nm-hyphen.md" <<'EOF'
# Hyphen joined

The label x-VACUOUS is our own, not core's.
EOF
# The three-letter word gets its OWN file: it is excluded by the grammar's floor, where the
# three above are excluded by the word split, and a mutation of one must not score against
# the other.
cat > "$OV/nm-short.md" <<'EOF'
# Short word

Status ABC is quoted here by our own gate wrapper.
EOF

# NOT RETIRED — the token MOVED between rulebook files and is present at theirs.
cat > "$EX/moved.md" <<'EOF'
# Moved token

The LEDGER-ROW is appended by our own wrapper.
EOF

# NOT RETIRED — the same, except the file it moved INTO is created at theirs.
cat > "$OV/mover.md" <<'EOF'
# Moved into a new file

Our sprint still records the MOVER-TOKEN by hand.
EOF

# NOT RETIRED — an emphasis word the release removed from one sentence and still carries.
cat > "$OV/emphasis.md" <<'EOF'
# Emphasis

This floor was MEASURED on our own corpus.
EOF

# NOT RETIRED — a plain word that left the rulebook with no program witness at all. It is
# read as emphasis, and the quiet NOTE has to say so out loud.
cat > "$OV/never.md" <<'EOF'
# Emphasis carried over

We NEVER promote a plan that has not been rehearsed.
EOF

# NOT RETIRED — a plain word whose only program mention at base was a COMMENT.
cat > "$OV/stale.md" <<'EOF'
# Rotator note

A STALE entry is dropped by our own rotator.
EOF

# The em-dash world: the flagged line carries a multibyte character, and the row must still
# name that line under a C locale, which is what the detector forces.
cat > "$OV/emdash.md" <<'EOF'
# Em dash body

Our gate — the one the lead reads — still exits 78 VACUOUS here.
EOF

# A JSON layer file is scanned; a .txt one is not. It carries a word from EACH witness
# branch, so the arm asserting the .json half is about the file EXTENSION and does not fall
# whenever a mutant un-retires one token.
cat > "$EX/layer.json" <<'EOF'
{
  "note": "stock exits 78 VACUOUS after APPROVED-WITH-FIXES"
}
EOF
cat > "$OV/notes.txt" <<'EOF'
stock exits 78 VACUOUS
EOF

# --- a consumer that is SCANNED and matches nothing ---------------------------------------
mkdir -p "$CLEANC/.claude/skills/ai-dlc/overrides"
cat > "$CLEANC/.claude/skills/ai-dlc/overrides/plain.md" <<'EOF'
# Plain override

This entry names no word core dropped in this release.
EOF

# --- the TRAP cwd -------------------------------------------------------------------------
# `set -f` is load-bearing: the rulebook entries are PATHSPECS and an unquoted expansion is
# subject to pathname expansion first. A cwd carrying files that match those globs under
# DIFFERENT names than the dist's makes the difference observable — the globs resolve to
# paths the dist tree does not have, and the two GLOB rulebook entries silently drop out.
mkdir -p "$TRAP_CWD/core/skills/ai-dlc/steps" "$TRAP_CWD/core/team-roles"
printf '# decoy\n' > "$TRAP_CWD/core/skills/ai-dlc/steps/decoy-a.md"
printf '# decoy\n' > "$TRAP_CWD/core/team-roles/decoy-b.md"

# --- line numbers are DERIVED, never counted by hand --------------------------------------
line_of() {  # file token -> first line carrying it
  local n
  n="$(grep -n "$2" "$1" | head -1 | cut -d: -f1)"
  [ -n "$n" ] || { echo "FIXTURE ERROR: seed could not locate $2 in $1" >&2; exit 2; }
  printf '%s' "$n"
}
BODY_LINE="$(line_of "$OV/body.md" VACUOUS)"
FRONT_LINE="$(line_of "$EX/front.md" VACUOUS)"
JOINED_LINE="$(line_of "$EX/joined.md" APPROVED-WITH-FIXES)"
DEFERRED_LINE="$(line_of "$OV/deferred.md" DEFERRED)"
EMDASH_LINE="$(line_of "$OV/emdash.md" VACUOUS)"
JSON_LINE="$(line_of "$EX/layer.json" VACUOUS)"

cat > "$WORK/env.sh" <<EOF
DIST="$DIST"
DIST2="$DIST2"
BASE="$BASE"
THEIRS="$THEIRS"
BASE2="$BASE2"
THEIRS2="$THEIRS2"
CONSUMER="$CONS"
CLEANC="$CLEANC"
NEUTRAL="$NEUTRAL"
TRAP_CWD="$TRAP_CWD"
SCRIPT="$SCRIPT"
BODY_LINE="$BODY_LINE"
FRONT_LINE="$FRONT_LINE"
JOINED_LINE="$JOINED_LINE"
DEFERRED_LINE="$DEFERRED_LINE"
EMDASH_LINE="$EMDASH_LINE"
JSON_LINE="$JSON_LINE"
EOF

echo "$WORK"
