#!/usr/bin/env bash
# Seed the check-1c-bypass fixture.
#
# THIS FIXTURE BUILDS A REAL GIT REPO AND REAL PRDs. It used to be five `echo`
# statements describing, in English, a commit subject and a PRD that were never
# created. Nothing was established, so nothing could fail — the fixture read exactly
# like a passing test for as long as it existed. Same shape the check-manifest-bypass
# and check-h1-recursion seeds were rewritten out of.
#
# Scenario (Check 1c, research-invocation enforcement, dual-arm OR):
#
#   arm (a) commit-subject marker, anchored:
#     ^Sprint [0-9]+ (research-requirements|technical.*research|research.*technical|bmad-technical-research)
#   arm (b) PRD content proxy: a "Research Findings" section AND >=1 marker matching
#     ^(- |### )?\*{0,2}R[0-9]+\s+[—–-]\s
#
# Two branches are seeded, and the SECOND one is what makes this fixture able to fail:
#
#   bypass/  — the adversary. A commit subject carrying the literal word `research` in
#              unrelated prose, and a PRD that HAS a "Research Findings" heading but no
#              conforming R-marker (it carries `R1: ...` with a colon, which a loose
#              marker regex accepts and the anchored one does not). Both naive forms
#              match; both anchored arms must not. Check 1c must FAIL this branch.
#
#   honest/  — the positive control. A real research commit and a real PRD with real
#              R-markers. Check 1c must PASS this branch.
#
# Without `honest/`, an arm regex mutated to match nothing at all would still look
# correct here: the adversary would be rejected for the wrong reason and the fixture
# would report success. The control is the mutant-detector.
#
# Check 1c is `adjudication: llm` in enforcement-map.yaml with `enforcer: []` — there
# is no validator script to drive, so run.sh evaluates the check's OWN PUBLISHED
# REGEXES against this seed. That tests the fixture's claim (the seeded artifacts do
# exhibit the bypass; the anchored form catches what the naive form misses), NOT the
# adjudicator's behaviour. See run.sh's header for the limits of what that proves.
#
# Usage: seed.sh [OUT_DIR]   (prints the seeded repo path on stdout)

set -euo pipefail

OUT="${1:-${OUT:-$(mktemp -d)}}"
mkdir -p "$OUT"
REPO="$OUT/repo"
rm -rf "$REPO"                     # idempotent re-seed
mkdir -p "$REPO"

(
  cd "$REPO"
  git init -q .
  git config user.email fixture@ai-dlc.local
  git config user.name  "check-1c-bypass fixture"
  git commit -q --allow-empty -m "base"
  git branch -M main

  # ---- the adversary --------------------------------------------------------
  # mkdir on EVERY branch: the base commit is empty, so git tracks no directory to
  # restore on checkout and the tree is bare each time.
  git checkout -q -b bypass
  mkdir -p _bmad-output/planning-artifacts
  cat > _bmad-output/planning-artifacts/prd.md <<'EOF'
# Sprint 42 PRD

## Research Findings

The heading above is real. What follows is not a research marker — it is a
plain list whose items begin with an R and a colon. A marker regex that looks
for "R<digits>" anywhere on the line accepts these; Check 1c's anchored form
requires a dash delimiter after whitespace and rejects them.

R1: noop cleanup, no research performed
R2: renamed a helper

## Requirements

- Ship the noop cleanup.
EOF
  git add -A
  git commit -q -m "Sprint 42 fix: research findings about noop"

  # ---- the positive control -------------------------------------------------
  git checkout -q main
  git checkout -q -b honest
  mkdir -p _bmad-output/planning-artifacts
  cat > _bmad-output/planning-artifacts/prd.md <<'EOF'
# Sprint 43 PRD

## Research Findings

**R1 — Connection pooling** is required before the read path can be widened;
the handshake cost dominates at the observed request rate.

**R2 — The queue driver** must be pinned to >=2.4 for the ack semantics this
sprint depends on.

## Requirements

- Widen the read path behind a pool.
EOF
  git add -A
  git commit -q -m "Sprint 43 technical research: pooling and queue driver"
) >/dev/null                       # stdout only — a seed that dies must SAY SO on stderr

echo "$REPO"
