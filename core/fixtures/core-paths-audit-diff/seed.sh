#!/usr/bin/env bash
# core-paths-audit-diff/seed.sh — build a synthetic LAYERED CONSUMER git repo with one
# branch per verdict `core-paths.sh --audit-diff` can reach, and echo the work dir.
#
# Why a real repo and not a stub: the mode's whole subject is git history — which commit
# touched which path, and what the manifest said BEFORE that commit. A stub that hands it
# a path list would exercise the glob loop `--is-core` already covers and none of the four
# things this mode adds.
#
# THE WORKING TREE STAYS AT `base` FOR EVERY RUN. Ranges are named by ref, never checked
# out, so the working-tree manifest equals the base-ref manifest on every branch except by
# deliberate construction. That is what lets the base-ref-resolution mutant fail exactly one
# assertion instead of shifting the classification under all of them.
set -uo pipefail

WORK="$(mktemp -d)" || exit 2
PROJ="$WORK/proj"
mkdir -p "$PROJ" || exit 2

export GIT_AUTHOR_NAME=fixture GIT_AUTHOR_EMAIL=fixture@example.invalid
export GIT_COMMITTER_NAME=fixture GIT_COMMITTER_EMAIL=fixture@example.invalid

g() { git -C "$PROJ" "$@"; }
commit() { g add -A >/dev/null 2>&1; g commit -q -m "$1" >/dev/null 2>&1 || return 1; }

g init -q >/dev/null 2>&1 || exit 2
g config commit.gpgsign false >/dev/null 2>&1

# --- pre-layer-split commit: no stamp, no overrides/, no extensions/ ----------
# The DORMANT subject. A distribution checkout reaches the same state by a different
# route, and both must be distinguishable from "scanned, found nothing".
mkdir -p "$PROJ/server"
printf 'print("app")\n' > "$PROJ/server/app.py"
commit "feat: pre-layer-split consumer" || exit 2
PRESPLIT="$(g rev-parse HEAD)"

# --- base: a layered consumer ------------------------------------------------
mkdir -p "$PROJ/.claude/skills/ai-dlc/overrides" \
         "$PROJ/.claude/skills/ai-dlc/extensions" \
         "$PROJ/scripts/ai-dlc" \
         "$PROJ/.claude/hooks"
printf '0.1.0\n' > "$PROJ/.claude/.ai-dlc-version"
printf '# overrides\n' > "$PROJ/.claude/skills/ai-dlc/overrides/README.md"
printf '# extensions\n' > "$PROJ/.claude/skills/ai-dlc/extensions/README.md"
# The manifest grammar is the real one: parse_manifest() reads the `core_manifest:` list
# and to_consumer_glob() maps each entry. Three entries, one per mapping arm this fixture
# needs — the scripts arm, the hooks arm, and the default (skill-relative) arm.
cat > "$PROJ/.claude/skills/ai-dlc/core-manifest.md" <<'MANIFEST'
# core-manifest

```yaml
core_manifest:
  - scripts/ai-dlc/*
  - hooks/ai-dlc-*.sh
  - core-manifest.md
```
MANIFEST
printf '#!/usr/bin/env bash\necho v1\n' > "$PROJ/scripts/ai-dlc/verdict.sh"
commit "chore: adopt the ai-dlc layer split" || exit 2
BASE="$(g rev-parse HEAD)"

branch_from_base() { g checkout -q -b "$1" "$BASE" >/dev/null 2>&1; }

# --- clean: consumer-owned file only -----------------------------------------
branch_from_base clean
printf 'print("app v2")\n' > "$PROJ/server/app.py"
commit "feat(s1): consumer change only" || exit 2
CLEAN="$(g rev-parse HEAD)"

# --- dirty: a core file edited in place by an ordinary sprint commit ----------
branch_from_base dirty
printf '#!/usr/bin/env bash\necho v2\n' > "$PROJ/scripts/ai-dlc/verdict.sh"
commit "fix(s1): tweak the verdict helper in place" || exit 2
DIRTY="$(g rev-parse HEAD)"

# --- reconcile: the same edit, authored by a pull -----------------------------
# /ai-dlc-update EDITS core in place; that is what it is for. The subject convention is
# the one ai-dlc-update/SKILL.md writes.
branch_from_base reconcile
printf '#!/usr/bin/env bash\necho v3\n' > "$PROJ/scripts/ai-dlc/verdict.sh"
commit "chore(ai-dlc-update): reconcile distribution 0.1.0 -> 0.2.0" || exit 2
RECONCILE="$(g rev-parse HEAD)"

# --- shrink: the diff un-claims the file it edits, in the same commit ---------
# The manifest edit is itself a core edit and would be reported either way, so the
# assertion this branch carries is about the OTHER path — the one only a base-ref
# manifest can still see.
branch_from_base shrink
printf '#!/usr/bin/env bash\necho v4\n' > "$PROJ/scripts/ai-dlc/verdict.sh"
cat > "$PROJ/.claude/skills/ai-dlc/core-manifest.md" <<'MANIFEST'
# core-manifest

```yaml
core_manifest:
  - hooks/ai-dlc-*.sh
  - core-manifest.md
```
MANIFEST
commit "fix(s1): tidy the manifest and the verdict helper" || exit 2
SHRINK="$(g rev-parse HEAD)"

g checkout -q "$BASE" >/dev/null 2>&1 || exit 2

# --- the script under test, plus an unmutated control copy -------------------
# Resolve upstream by walking UP for either layout, never by walking up from a sibling
# core file (I33).
HERE="$(cd "$(dirname "$0")" && pwd)"
RESOLVER=""
d="$HERE"
while [ "$d" != "/" ]; do
  if [ -f "$d/core/scripts/core-paths.sh" ]; then RESOLVER="$d/core/scripts/core-paths.sh"; break
  elif [ -f "$d/scripts/ai-dlc/core-paths.sh" ]; then RESOLVER="$d/scripts/ai-dlc/core-paths.sh"; break; fi
  d="$(dirname "$d")"
done
[ -n "$RESOLVER" ] || { echo "seed: no core-paths.sh found walking up from $HERE" >&2; exit 2; }
cp "$RESOLVER" "$WORK/control-core-paths.sh" || exit 2

cat > "$WORK/env.sh" <<ENVEOF
PROJ="$PROJ"
VALIDATOR="$RESOLVER"
CONTROL_VALIDATOR="$WORK/control-core-paths.sh"
WORKDIR="$WORK"
PRESPLIT="$PRESPLIT"
BASE="$BASE"
CLEAN="$CLEAN"
DIRTY="$DIRTY"
RECONCILE="$RECONCILE"
SHRINK="$SHRINK"
ENVEOF

echo "$WORK"
