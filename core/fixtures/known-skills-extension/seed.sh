#!/usr/bin/env bash
# known-skills-extension/seed.sh — an artifact whose provenance block cites a CONSUMER skill
# (not in the core known_skills list), plus a consumer known-skills.json that registers it, plus a
# malformed extension. run.sh proves: without the extension the skill is unknown (FAIL); with it,
# the block passes; a broken extension fails closed. Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/scripts/validate-provenance-block.sh" ]; then
  VALIDATOR="$D_ROOT/core/scripts/validate-provenance-block.sh"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/scripts/ai-dlc/validate-provenance-block.sh" ]; then
  VALIDATOR="$C_ROOT/scripts/ai-dlc/validate-provenance-block.sh"
else
  echo "FIXTURE ERROR: validate-provenance-block.sh not found in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/known-skills.XXXXXX")" || exit 2

# A well-formed provenance block citing a consumer-only skill.
#
# It carries findings_* because rules.counts_always keys on membership in
# known_skills, and registering an extension skill PUTS IT IN that set — so a
# consumer evaluation owes its residue exactly as a core one does. That is
# deliberate: exempting the extension would make "register your own skill name"
# a way to opt out of being measured, which is the one loophole the rule cannot
# afford. No verdict: this is not a Rule 8 convergence pass.
cat > "$WORK/artifact.md" <<'ART'
# Consumer party-mode transcript (fixture)

<!-- SKILL_INVOCATION_PROVENANCE v1
skill: bmad-agent-tea-tea
invoked_at: 2026-07-16T12:00:00Z
tool_use_id: toolu_fixtureABC123
mode: subagent
lead_role: retro.md
findings_critical: 0
findings_major: 1
findings_minor: 0
SKILL_INVOCATION_PROVENANCE_END -->
ART

# The layer-correct registration — object form.
printf '{ "known_skills": ["bmad-agent-tea-tea"] }\n' > "$WORK/known-skills.json"
# Bare-array form (the other accepted shape).
printf '["bmad-agent-tea-tea"]\n' > "$WORK/known-skills-array.json"
# Malformed — must fail the gate closed, never silently degrade to core-only.
printf '{ this is not valid json\n' > "$WORK/known-skills-malformed.json"

cat > "$WORK/env.sh" <<ENV
VALIDATOR="$VALIDATOR"
ARTIFACT="$WORK/artifact.md"
EXT="$WORK/known-skills.json"
EXT_ARRAY="$WORK/known-skills-array.json"
MALFORMED="$WORK/known-skills-malformed.json"
ENV

printf '%s\n' "$WORK"
