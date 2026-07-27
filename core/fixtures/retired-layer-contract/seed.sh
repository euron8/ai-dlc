#!/usr/bin/env bash
# retired-layer-contract/seed.sh — build a fake distribution git repo (base + theirs,
# where theirs RETIRES a rulebook line shape) plus a consumer carrying layer files that
# still speak it. Idempotent: fresh temp tree each call.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$D_ROOT"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/skills/ai-dlc-update/reconcile/retired-layer-contract.sh" ]; then
  SCRIPT="$D_ROOT/core/skills/ai-dlc-update/reconcile/retired-layer-contract.sh"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/.claude/skills/ai-dlc-update/reconcile/retired-layer-contract.sh" ]; then
  SCRIPT="$C_ROOT/.claude/skills/ai-dlc-update/reconcile/retired-layer-contract.sh"
else
  echo "FIXTURE ERROR: retired-layer-contract.sh not found in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/retired-layer-contract.XXXXXX")" || exit 2
DIST="$WORK/dist"
CONSUMER="$WORK/consumer"
mkdir -p "$DIST/core/team-roles" "$DIST/core/skills/ai-dlc-update/reconcile"

# The detector derives its rulebook file set from setup-sites.md's `rulebook:` list,
# so the fake dist must carry one. Only the list matters here.
cat > "$DIST/core/skills/ai-dlc-update/reconcile/setup-sites.md" <<'SITES'
# fixture setup-sites
```yaml
rulebook:
  - core/team-roles/*.md
```
SITES

# BASE: the role file carries the labelled-directive shape that THEIRS retires.
cat > "$DIST/core/team-roles/architect.md" <<'ROLE'
# Role: Architect (fixture)

**Model and effort.**
- `/effort high`
- Personal: `/model claude-opus-5[1m]`
- Bedrock: `/model global.anthropic.claude-opus-4-6-v1`
ROLE

git -C "$DIST" init -q
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
GIT_AUTHOR_DATE='2026-01-02T00:00:00Z' GIT_COMMITTER_DATE='2026-01-02T00:00:00Z' \
  git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"

# THEIRS: the two labelled directives are retired in favour of a key.
cat > "$DIST/core/team-roles/architect.md" <<'ROLE'
# Role: Architect (fixture)

**Model and effort.**
- `/effort high`
- Model: `opus` — a key in `aiDlcModels`.
ROLE
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
GIT_AUTHOR_DATE='2026-06-02T00:00:00Z' GIT_COMMITTER_DATE='2026-06-02T00:00:00Z' \
  git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m theirs
THEIRS="$(git -C "$DIST" rev-parse HEAD)"

L="$CONSUMER/.claude/skills/ai-dlc"
mkdir -p "$L/overrides" "$L/extensions/steps-domain"

# (1) A layer file carrying the retired shape on a LIVE line — must be flagged.
cat > "$L/overrides/team-roles__tea__consumer.md" <<'OV'
---
shadows: team-roles/tea.md#Identity
---
- `/effort high`
- Personal: `/model claude-opus-5[1m]`
- Bedrock: `/model global.anthropic.claude-opus-4-6-v1`
OV

# (2) A layer file carrying it INDENTED and BACKSLASH-ESCAPED inside a fenced command —
# the shape an extension takes when it greps core and pastes the output. Anchoring the
# matcher at line start missed exactly this on the reference consumer.
cat > "$L/extensions/steps-domain/bug-investigation-push.md" <<'EX'
# Extension: push-mode bug investigation

Literal output of
`grep -oE '^- Personal: \`/model [^\`]+\`' .claude/team-roles/<role>.md`:

    analyst:   - Personal: `/model claude-sonnet-5[1m]`
    adversary: - Personal: `/model claude-opus-5[1m]`
EX

# (3) A layer file that paraphrases WITHOUT the literal shape — must NOT be flagged.
# This is the documented limit; asserting it keeps the matcher from silently widening
# into every reworded sentence.
cat > "$L/overrides/team-roles__analyst__effort.md" <<'OV'
---
shadows: team-roles/analyst.md#Identity
---
This override changes the effort line only. The model lines in the same section
are configuration and are not part of this override.
- `/effort high`
OV

# (4) A layer file with no core-contract reference at all — the silent control.
cat > "$L/extensions/steps-domain/retro-domain.md" <<'EX'
# Extension: domain retro sections
Add a domain-specific section to the retro.
EX

cat > "$WORK/env.sh" <<ENV
SCRIPT="$SCRIPT"
DIST="$DIST"
BASE="$BASE"
THEIRS="$THEIRS"
CONSUMER="$CONSUMER"
ENV

printf '%s\n' "$WORK"
