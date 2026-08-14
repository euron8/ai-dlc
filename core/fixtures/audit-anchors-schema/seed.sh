#!/usr/bin/env bash
# audit-anchors-schema/seed.sh — resolve the REAL validate-audit-anchors.sh (which loads the REAL
# schemas/audit-anchors.json) so run.sh can prove the header is rendered from the schema, drift is
# caught, and entries are validated against it. Prints the WORK dir. Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# core/fixtures/<name>/ upstream, tests/fixtures/<name>/ in a consumer — BOTH three dirs below root.
D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if   [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/scripts/validate-audit-anchors.sh" ]; then
  VALIDATOR="$D_ROOT/core/scripts/validate-audit-anchors.sh"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/scripts/ai-dlc/validate-audit-anchors.sh" ]; then
  VALIDATOR="$C_ROOT/scripts/ai-dlc/validate-audit-anchors.sh"
else
  echo "FIXTURE ERROR: validate-audit-anchors.sh not found in either layout" >&2
  exit 2
fi

# The schema itself, resolved the way the validator resolves it: $SCRIPT_DIR/../schemas first (the
# package this copy shipped in — core/schemas upstream), then the consumer's .claude/schemas.
# Needed whole, because one arm proves the enum is read FROM it by mutating a COPY of it.
V_DIR="$(cd "$(dirname "$VALIDATOR")" && pwd)"
if   [ -f "$V_DIR/../schemas/audit-anchors.json" ]; then
  SCHEMA="$(cd "$V_DIR/../schemas" && pwd)/audit-anchors.json"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/.claude/schemas/audit-anchors.json" ]; then
  SCHEMA="$C_ROOT/.claude/schemas/audit-anchors.json"
else
  echo "FIXTURE ERROR: audit-anchors.json not found in either layout" >&2
  exit 2
fi

command -v git >/dev/null 2>&1 || { echo "FIXTURE ERROR: git not on PATH" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/audit-anchors-schema.XXXXXX")" || exit 2
WORK="$(cd "$WORK" && pwd)"

# A malformed schema JSON — used to prove the reader fails CLOSED, never degrades to no-schema.
printf '{ "fields": { "sprint": }, BROKEN\n' > "$WORK/bad-schema.json"

# `mut/` holds mutant COPIES of the validator; `schemas/` sits beside it because the validator
# resolves its schema at $SCRIPT_DIR/../schemas first, which is the shape both shipped layouts
# have. A mutant that cannot find its schema exits 1 on every arm and scores a kill it did not earn.
mkdir -p "$WORK/mut" "$WORK/schemas" || exit 2
cp "$SCHEMA" "$WORK/schemas/audit-anchors.json" || exit 2

# --- the fixture's OWN git repository ----------------------------------------
# `--close-record` RESOLVES its <sha> argument with `git rev-parse` in the process CWD before it
# will write anything. Borrowing whichever tree the suite was launched from would make every
# close-record arm cwd-dependent — green from the repo root and asserting nothing anywhere else —
# so the fixture carries a repository of its own and runs the writer inside it.
REPO="$WORK/repo"
mkdir -p "$REPO" || exit 2
(
  cd "$REPO" || exit 2
  git -c init.defaultBranch=main init -q . 2>/dev/null || exit 2
  git config user.email fixture@example.com
  git config user.name  Fixture
  git config commit.gpgsign false
  echo seed > seed.txt
  git add -A && git commit -q -m "close-record anchor"
  # A ref whose NAME contains PENDING. --close-record checks "does this sha resolve" BEFORE it
  # checks "is this a PENDING placeholder", so the placeholder arm is reachable only through a
  # placeholder that also resolves. Without this tag that arm cannot be exercised at all.
  git tag PENDING-S901-RETRO HEAD
) || { echo "FIXTURE ERROR: could not build the fixture git repo" >&2; exit 2; }
REPO_SHA="$(cd "$REPO" && git rev-parse HEAD)" || exit 2
[ -n "$REPO_SHA" ] || { echo "FIXTURE ERROR: no HEAD in the fixture git repo" >&2; exit 2; }

cat > "$WORK/env.sh" <<ENV
VALIDATOR="$VALIDATOR"
SCHEMA="$SCHEMA"
WORK="$WORK"
BAD_SCHEMA="$WORK/bad-schema.json"
REPO="$REPO"
REPO_SHA="$REPO_SHA"
PENDING_REF="PENDING-S901-RETRO"
ENV

printf '%s\n' "$WORK"
