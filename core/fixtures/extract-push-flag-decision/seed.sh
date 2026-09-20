#!/usr/bin/env bash
# extract-push-flag-decision/seed.sh — build a throwaway tree holding a SELF-PROBE corpus
# and echo the workspace path.
#
# The probe corpus is what makes this fixture's zeros readable. The scanner below is run
# against seeded bullet lists BEFORE it is run against the real SKILL.md, in both
# directions and in the SAME run: one list whose `domain-local` bullet writes no flag (the
# shipping defect, which must be REPORTED) and one whose bullet writes it (a near-miss,
# which must stay QUIET). A scanner that flags everything and a scanner that discriminates
# are the same output on the offender alone, which is why the near-miss sits beside it.
#
# Both probe files carry the SAME `un-pushed-innovation` bullet, verbatim. That is the
# arm's whole difficulty: a whole-list grep for `push_candidate` is satisfied by that
# bullet four lines below the subject, and a scanner keyed on the list rather than on the
# bullet scores the shipping defect as clean. The probe would pass such a scanner on the
# offender and fail it on nothing — so the near-miss is not decoration here, it is the
# only input that separates a bullet-scoped predicate from a list-scoped one.
set -euo pipefail

WORK="$(mktemp -d)"
mkdir -p "$WORK/probe"

# --- OFFENDER: the pre-fix shipping text, reproduced ---------------------------------
# `domain-local` routes to extensions/ and writes NO flag; `un-pushed-innovation` writes
# it one bullet below. The asymmetry IS the defect, and it is what the arm must report.
cat > "$WORK/probe/offender.md" <<'EOF'
Per classify bucket, act:
- **rewording** → discard the consumer's version; core is restored to
  `theirs` at that block (rewording is by definition already-upstream in
  substance).
- **domain-local** → extract the block to `extensions/`, then restore core to
  `theirs` at that block.
- **un-pushed-innovation** → extract to `extensions/` with `push_candidate:
  true`, then restore core to `theirs`.
- **conflict** → extract to `overrides/` with `shadows: <file>#<id>` and
  `base_sha: <current stamp sha>`, then restore core to `theirs`.

Then apply the **mask/reinject transform** to every manifest-listed file.
EOF

# --- NEAR-MISS: the bullet writes the flag, in a wording that shares NO sentence with
# the shipped fix. A scanner that can only spell the committed phrasing passes its own
# subject and fails this, which is the direction that reads as a working check.
cat > "$WORK/probe/nearmiss.md" <<'EOF'
Per classify bucket, act:
- **rewording** → discard the consumer's version; core is restored to
  `theirs` at that block (rewording is by definition already-upstream in
  substance).
- **domain-local** → extract the block to `extensions/`, recording
  `push_candidate: false` on the entry as a derived claim rather than a
  default, then restore core to `theirs` at that block.
- **un-pushed-innovation** → extract to `extensions/` with `push_candidate:
  true`, then restore core to `theirs`.
- **conflict** → extract to `overrides/` with `shadows: <file>#<id>` and
  `base_sha: <current stamp sha>`, then restore core to `theirs`.

Then apply the **mask/reinject transform** to every manifest-listed file.
EOF

# --- NEAR-MISS 2: the flag is written, but into the PROSE BELOW the bullet list rather
# than into the bullet. This is the input that separates a bullet-scoped extractor from
# one that reads to the end of the section, and the shape the fix hand's first draft had.
cat > "$WORK/probe/belowlist.md" <<'EOF'
Per classify bucket, act:
- **rewording** → discard the consumer's version; core is restored to
  `theirs` at that block.
- **domain-local** → extract the block to `extensions/`, then restore core to
  `theirs` at that block.
- **un-pushed-innovation** → extract to `extensions/` with `push_candidate:
  true`, then restore core to `theirs`.
- **conflict** → extract to `overrides/` with `shadows: <file>#<id>`.

Then apply the **mask/reinject transform**. Note that a domain-local block is
written with `push_candidate: false` when it is extracted.
EOF

cat > "$WORK/env.sh" <<EOF
PROBE="$WORK/probe"
export PROBE
EOF

echo "$WORK"
