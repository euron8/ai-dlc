#!/usr/bin/env bash
# setup-config-drift/seed.sh — build a fake distribution git repo + a consumer tree, so run.sh
# can prove unregistered-drift.sh distinguishes a declared setup-config region (exempt) from an
# in-place edit to the rest of the setup wizard (HARD drift). Idempotent: fresh temp tree each call.
#
# The fake core file carries the REAL heading (`## Ownership`) and the REAL terminator
# (`## Responsibilities`) of setup-sites.md's `dev-ownership-paths` site, so the ACTUAL
# declaration applies to it — this tests the real manifest entry, not a stand-in. Rename
# either anchor and the fixture breaks loudly, exactly as the real site would.
#
# Retargeted in v0.174.0. It previously replicated `setup-model-strategy`, a heading-block
# over ai-dlc-setup/SKILL.md STEP 2 that exempted the operator's model-strategy choice.
# That site is retired: model strings moved to the consumer-owned `aiDlcModels` block in
# settings.json, so STEP 2 no longer carries a consumer-specific span to exempt. The
# machinery under test is unchanged — a declared heading-block region is exempt, everything
# outside it is HARD drift, and an unresolvable terminator must fail CLOSED rather than
# widen the span to EOF — so the fixture moves to a surviving heading-block site rather
# than being deleted.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# Resolve the REAL unregistered-drift.sh (its sibling setup-sites.md is the site manifest it reads).
D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/skills/ai-dlc-update/reconcile/unregistered-drift.sh" ]; then
  SCRIPT="$D_ROOT/core/skills/ai-dlc-update/reconcile/unregistered-drift.sh"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/.claude/skills/ai-dlc-update/reconcile/unregistered-drift.sh" ]; then
  SCRIPT="$C_ROOT/.claude/skills/ai-dlc-update/reconcile/unregistered-drift.sh"
else
  echo "FIXTURE ERROR: unregistered-drift.sh not found in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/setup-config-drift.XXXXXX")" || exit 2
DIST="$WORK/dist"
CONSUMER="$WORK/consumer"
STALE="$WORK/consumer-stale"
REL="team-roles/dev.md"
mkdir -p "$DIST/core/team-roles" "$CONSUMER/.claude/team-roles" \
         "$DIST/core/schemas" "$CONSUMER/.claude/schemas"
SCHEMA_REL="schemas/fixture-schema.json"

cat > "$DIST/core/$REL" <<'ROLE'
# Role: Developer (fixture)

**Model and effort: Set at the start of your session.**
- `/effort medium`
- Model: `sonnet` — a key in `aiDlcModels` (`.claude/settings.json`).

## Ownership

Directories this teammate owns.

- `src/` (application source code)

## Responsibilities

Fixed rulebook prose. A consumer MUST NOT edit this in place — it is
upstream-owned and `apply` overwrites it.

## Constraints

More fixed rulebook prose, after the terminator.
ROLE

# A schema — an LLM-loaded, overwrite-on-pull core file with NO {token} and no config region, so
# any consumer edit is silent drift the scan must flag HARD.
cat > "$DIST/core/$SCHEMA_REL" <<'SCHEMA'
{
  "schema_id": "FIXTURE v1",
  "rule": "the-strict-original"
}
SCHEMA

# A distribution is a git repo; unregistered-drift.sh reads core@base with `git show`.
#
# TWO COMMITS, NOT ONE. The first is an OLD release; the second is base. A consumer whose copy
# is frozen at the old one — because a per-entry acceptance excluded it from every apply — must
# be distinguishable from a consumer that edited base. With a single-commit history the
# distinction cannot exist, which is why it went unnoticed for three pulls on the reference
# consumer: the base-relative diff grows with staleness and reads as a fork that grew on its own.
git -C "$DIST" init -q
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
GIT_AUTHOR_DATE='2026-01-02T00:00:00Z' GIT_COMMITTER_DATE='2026-01-02T00:00:00Z' \
  git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m old-release
OLD="$(git -C "$DIST" rev-parse HEAD)"
OLD_BODY="$(cat "$DIST/core/$REL")"

# Upstream then rewrites STEP 2 substantially — the change a stale consumer never took.
cat >> "$DIST/core/$REL" <<'LATER'

## Escalation Protocol

Upstream added this section after the old release. A consumer frozen at the
old release lacks it, and that absence is upstream's change, not the
consumer's edit.

## Handoff Notes

Also added after the old release. Together these make the base-relative
diff large while the ancestor-relative diff stays small.
LATER
git -C "$DIST" -c user.email=f@f -c user.name=fixture add -A
GIT_AUTHOR_DATE='2026-06-02T00:00:00Z' GIT_COMMITTER_DATE='2026-06-02T00:00:00Z' \
  git -C "$DIST" -c user.email=f@f -c user.name=fixture commit -q -m base
BASE="$(git -C "$DIST" rev-parse HEAD)"

cp "$DIST/core/$REL" "$CONSUMER/.claude/$REL"
cp "$DIST/core/$SCHEMA_REL" "$CONSUMER/.claude/$SCHEMA_REL"

# A SECOND consumer, frozen at the old release plus one addition of its own — the shape the
# reference consumer was actually in. Its base-relative diff is dominated by upstream's two
# added sections; its ancestor-relative diff is the one line it really owns.
mkdir -p "$STALE/.claude/$(dirname "$REL")"
{ printf '%s\n' "$OLD_BODY"; printf '\n%s\n' "A line this consumer genuinely added on top of the old release."; } \
  > "$STALE/.claude/$REL"

cat > "$WORK/env.sh" <<ENV
SCRIPT="$SCRIPT"
DIST="$DIST"
BASE="$BASE"
OLD="$OLD"
CONSUMER="$CONSUMER"
STALE="$STALE"
REL="$REL"
SCHEMA_REL="$SCHEMA_REL"
ENV

printf '%s\n' "$WORK"
