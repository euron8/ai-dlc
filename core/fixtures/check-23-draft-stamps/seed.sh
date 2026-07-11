#!/usr/bin/env bash
# Seed four throwaway project trees for the check-23 fixture.
# Usage: seed.sh <dest-dir>
set -eu

DEST="${1:?usage: seed.sh <dest-dir>}"

PA="_bmad-output/planning-artifacts"
EXT=".claude/skills/ai-dlc/extensions/steps-domain"
STEPS=".claude/skills/ai-dlc/steps"

# --- bad-disk: an unstamped draft on disk. The prior sprint's evaluation is
#     already gone; the validator's disk half must catch this.
mkdir -p "$DEST/bad-disk/$PA"
cat > "$DEST/bad-disk/$PA/carry-over-evaluation.md" <<'EOF'
# Carry-Over Evaluation — Sprint 288

Written to the unstamped path. Sprint 287's evaluation, which lived at this
same path, no longer exists outside git.
EOF

# --- bad-layer: core is correct (stamped draft on disk), but a step-domain
#     extension restates Section 0 with the UNSTAMPED write path. This is the
#     real graph consumer's carry-over-evaluation-domain.md shape verbatim: the
#     layer wins in the rendered pipeline, so the stamp is silently reverted.
mkdir -p "$DEST/bad-layer/$PA" "$DEST/bad-layer/$EXT"
cat > "$DEST/bad-layer/$PA/s288-carry-over-evaluation.md" <<'EOF'
# Carry-Over Evaluation — Sprint 288
EOF
cat > "$DEST/bad-layer/$EXT/carry-over-evaluation-domain.md" <<'EOF'
---
kind: step-domain
hooks: steps/carry-over-evaluation.md
id: carry-over-evaluation-domain
push_candidate: false
---

### 0. Exploration dispatch — domain inspection clause

Spawn an `analyst` subagent scoped to those reading sections — it loads the
backlog/brief/PRD and audit anchor, evaluates each item, and writes a draft
evaluation to
`_bmad-output/planning-artifacts/carry-over-evaluation.md`, returning
only `{artifact_path, summary, gaps}`. Then resume at section 3.
EOF

# --- good: stamped draft, and a layer that restates the stamped path.
mkdir -p "$DEST/good/$PA" "$DEST/good/$EXT"
cat > "$DEST/good/$PA/s288-carry-over-evaluation.md" <<'EOF'
# Carry-Over Evaluation — Sprint 288
EOF
cat > "$DEST/good/$PA/s288-research-notes.md" <<'EOF'
# Research Notes — Sprint 288
EOF
cat > "$DEST/good/$EXT/carry-over-evaluation-domain.md" <<'EOF'
---
kind: step-domain
hooks: steps/carry-over-evaluation.md
id: carry-over-evaluation-domain
push_candidate: false
---

### 0. Exploration dispatch — domain inspection clause

Spawn an `analyst` subagent — it evaluates each item and writes a draft
evaluation to
`_bmad-output/planning-artifacts/s<N>-carry-over-evaluation.md` (Rule 24
sprint stamp), returning only `{artifact_path, summary, gaps}`.
EOF

# --- decoy: everything that a naive basename grep would wrongly flag.
#     (a) A step file whose routing table names the STEP `carry-over-evaluation.md`.
#         Every step file's own name collides with its artifact's name.
#     (b) The one-shot ONBOARDING artifacts, which are deliberately out of scope:
#         they are written once, read by path downstream, and have no sprint key.
#     (c) bug-analysis.md — bug-keyed, not sprint-keyed; also out of scope.
#     None of these may fail the check.
mkdir -p "$DEST/decoy/$PA" "$DEST/decoy/$STEPS"
cat > "$DEST/decoy/$PA/s288-carry-over-evaluation.md" <<'EOF'
# Carry-Over Evaluation — Sprint 288
EOF
cat > "$DEST/decoy/$PA/codebase-analysis.md" <<'EOF'
# Codebase Analysis
One-shot onboarding artifact. Unstamped by design — out of scope.
EOF
cat > "$DEST/decoy/$PA/brownfield-inventory.md" <<'EOF'
# Brownfield Inventory
One-shot onboarding artifact. Unstamped by design — out of scope.
EOF
cat > "$DEST/decoy/$PA/doc-reconciliation.md" <<'EOF'
# Doc Reconciliation
One-shot onboarding artifact. Unstamped by design — out of scope.
EOF
cat > "$DEST/decoy/$PA/bug-analysis.md" <<'EOF'
# Bug Analysis — L1 rebalance repeatedly hits "partial burn"
Bug-keyed, not sprint-keyed. Out of scope.
EOF
cat > "$DEST/decoy/$STEPS/route.md" <<'EOF'
| Variant | Pipeline Sequence | First Step |
|---------|------------------|------------|
| carry-over | carry-over-evaluation -> discovery -> ... | `carry-over-evaluation.md` |
EOF

echo "seeded: bad-disk bad-layer good decoy"
