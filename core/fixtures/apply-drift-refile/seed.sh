#!/usr/bin/env bash
# apply-drift-refile/seed.sh — a consumer that added a skill to provenance-block.json's known_skills
# IN PLACE (the exact "migrate the drift" chore). run.sh proves apply.sh refiles it to the extension
# and reverts the core schema automatically — no manual step. Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  APPLY="$D_ROOT/core/skills/ai-dlc-update/reconcile/apply.sh"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/.claude/skills/ai-dlc-update/reconcile/apply.sh" ]; then
  APPLY="$C_ROOT/.claude/skills/ai-dlc-update/reconcile/apply.sh"
else
  echo "FIXTURE ERROR: apply.sh not found in either layout" >&2; exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/apply-drift.XXXXXX")" || exit 2
DIST="$WORK/dist"; CONSUMER="$WORK/consumer"
mkdir -p "$DIST/core/schemas" "$CONSUMER/.claude/schemas" \
         "$DIST/core/session-driver" "$CONSUMER/.claude/session-driver" \
         "$DIST/core/scripts"
# A real distribution ALWAYS ships core validators, and since v0.160.0 the manifest
# claims them as `core/scripts/ai-dlc/*` -- one entry apply.sh expands against THEIRS'
# tree. A synthetic DIST shipping none makes that expansion empty, which apply.sh
# reports as manifest-unreadable and withholds the re-stamp for, correctly. This
# fixture used to pass through that hole: the old 27-name enumeration produced 27
# individual cat-file misses, and 27 misses read as "nothing to relocate".
printf '#!/usr/bin/env bash\necho v\n' > "$DIST/core/scripts/validate-synthetic.sh"

cat > "$DIST/core/schemas/provenance-block.json" <<'JSON'
{
  "schema_id": "SKILL_INVOCATION_PROVENANCE v1",
  "known_skills": [
    "bmad-party-mode"
  ]
}
JSON
# A core/ subtree OUTSIDE the paths apply.sh happened to hand-list. The consumer's copy is
# untouched, so the pull's only job is to overwrite it: the plainest UPSTREAM-ONLY there is.
printf '#!/usr/bin/env bash\n# driver v1\n' > "$DIST/core/session-driver/ai-dlc-session-driver.sh"
printf '9.9.9\n' > "$DIST/VERSION"
git -C "$DIST" init -q
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"

# THEIRS changes the driver's CONTENT. The real defect hid behind a mode-only delta the
# consumer already had, so a content delta is what makes the miss observable at all.
printf '#!/usr/bin/env bash\n# driver v2 UPSTREAM\n' > "$DIST/core/session-driver/ai-dlc-session-driver.sh"
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m theirs
THEIRS="$(git -C "$DIST" rev-parse HEAD)"

# Consumer sits at v1, unmodified — nothing for the operator to decide.
printf '#!/usr/bin/env bash\n# driver v1\n' > "$CONSUMER/.claude/session-driver/ai-dlc-session-driver.sh"

# Consumer added its own persona skill to the core list, in place — the drift.
cat > "$CONSUMER/.claude/schemas/provenance-block.json" <<'JSON'
{
  "schema_id": "SKILL_INVOCATION_PROVENANCE v1",
  "known_skills": [
    "bmad-party-mode",
    "my-persona-skill"
  ]
}
JSON
printf 'version: 0.0.1\ncommit: %s\n' "$BASE" > "$CONSUMER/.claude/.ai-dlc-version"

cat > "$WORK/env.sh" <<ENV
APPLY="$APPLY"
DIST="$DIST"
BASE="$BASE"
THEIRS="$THEIRS"
CONSUMER="$CONSUMER"
EXT="$CONSUMER/.claude/skills/ai-dlc/extensions/known-skills.json"
SCHEMA="$CONSUMER/.claude/schemas/provenance-block.json"
STAMP="$CONSUMER/.claude/.ai-dlc-version"
DRIVER="$CONSUMER/.claude/session-driver/ai-dlc-session-driver.sh"
ENV

printf '%s\n' "$WORK"
