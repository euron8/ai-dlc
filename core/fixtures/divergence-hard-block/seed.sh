#!/usr/bin/env bash
# Seed a consumer-shaped tree with one adversarial pass artifact.
#   seed.sh <verdict> [pass-n]   -> prints the WORK dir
set -eu
V="${1:?verdict}"; N="${2:-15}"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/divergence-XXXXXX")"
mkdir -p "$WORK/_bmad-output/planning-artifacts"
touch "$WORK/_bmad-output/pipeline-snapshot.md"
cat > "$WORK/_bmad-output/planning-artifacts/s1-brief-adversarial-p${N}.md" <<EOF
# Adversarial pass ${N}

<!-- SKILL_INVOCATION_PROVENANCE v1
skill: bmad-review-adversarial-general
mode: subagent
findings_critical: 1
findings_critical_prior_scope: 1
findings_major: 0
findings_minor: 2
verdict: ${V}
SKILL_INVOCATION_PROVENANCE_END -->
EOF
printf '%s\n' "$WORK"
