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
# A second core path, the one a reconcile DELETES in the content-arm deletion cells.
printf '#!/usr/bin/env bash\necho hook\n' > "$PROJ/.claude/hooks/ai-dlc-a.sh"
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

# --- the CONTENT arm: squash-merged pulls (BL-939) ----------------------------
# A consumer that squash-merges its update PR lands the reconcile's TREE on main under the
# PR's own subject; the reconcile commit survives only on its update ref. Each cell below
# is a branch from base whose tip is that shape or one property away from it. Stamps are
# distinct per reconcile so each cell's eligible set R(t) is exactly the one it names.
from_tree() { g checkout -q -B "$1" "$BASE" >/dev/null 2>&1 && g read-tree -u --reset "$2" >/dev/null 2>&1; }
blob() { g rev-parse -q --verify "${1}:${2}" 2>/dev/null; }
mode() { g ls-tree "$1" -- "$2" 2>/dev/null | awk '{ print $1 }'; }

# X: the reconcile on its side branch, stamp 0.2.0.
branch_from_base ai-dlc-update/x
printf '0.2.0\n' > "$PROJ/.claude/.ai-dlc-version"
printf '#!/usr/bin/env bash\necho v5\n' > "$PROJ/scripts/ai-dlc/verdict.sh"
commit "chore(ai-dlc-update): reconcile distribution 0.1.0 -> 0.2.0" || exit 2
XREC="$(g rev-parse HEAD)"

# OLDREC: an older reconcile on its own side branch, stamp 0.1.5, verdict v8.
branch_from_base ai-dlc-update/old
printf '0.1.5\n' > "$PROJ/.claude/.ai-dlc-version"
printf '#!/usr/bin/env bash\necho v8\n' > "$PROJ/scripts/ai-dlc/verdict.sh"
commit "chore(ai-dlc-update): reconcile distribution 0.1.0 -> 0.1.5" || exit 2
OLDREC="$(g rev-parse HEAD)"

# YREC: a reconcile that DELETES the hook and edits verdict.sh, stamp 0.4.0.
branch_from_base ai-dlc-update/y
printf '0.4.0\n' > "$PROJ/.claude/.ai-dlc-version"
printf '#!/usr/bin/env bash\necho v9\n' > "$PROJ/scripts/ai-dlc/verdict.sh"
rm -f "$PROJ/.claude/hooks/ai-dlc-a.sh"
commit "chore(ai-dlc-update): reconcile distribution 0.1.0 -> 0.4.0" || exit 2
YREC="$(g rev-parse HEAD)"

# Cell 1 SQUASH: X's tree, parent base, a non-reconcile subject. Passes by content.
from_tree squash "$XREC" || exit 2
commit "feat: ai-dlc update 0.2.0 (#101)" || exit 2
SQUASH="$(g rev-parse HEAD)"

# Cell 2 BYTE: X's tree with verdict.sh one byte off.
from_tree byte "$XREC" || exit 2
printf '#!/usr/bin/env bash\necho v6\n' > "$PROJ/scripts/ai-dlc/verdict.sh"
commit "feat: ai-dlc update 0.2.0 (#102)" || exit 2
BYTE="$(g rev-parse HEAD)"

# Cell 5 CHMOD: X's tree with verdict.sh's mode changed, bytes identical.
from_tree chmod "$XREC" || exit 2
g update-index --chmod=+x scripts/ai-dlc/verdict.sh >/dev/null 2>&1 || exit 2
g commit -q -m "feat: ai-dlc update 0.2.0 (#103)" >/dev/null 2>&1 || exit 2
g checkout -q -f chmod >/dev/null 2>&1 || exit 2
CHMOD="$(g rev-parse HEAD)"

# Cell 6 OLDBLOB: the CURRENT stamp (X's 0.2.0) with OLDREC's verdict.sh restored.
from_tree oldblob "$XREC" || exit 2
printf '#!/usr/bin/env bash\necho v8\n' > "$PROJ/scripts/ai-dlc/verdict.sh"
commit "feat: ai-dlc update 0.2.0 (#104)" || exit 2
OLDBLOB="$(g rev-parse HEAD)"

# Cell 8 DELMATCH: Y's tree squashed; the hook deletion matches Y's own. Passes by content.
from_tree delmatch "$YREC" || exit 2
commit "feat: ai-dlc update 0.4.0 (#105)" || exit 2
DELMATCH="$(g rev-parse HEAD)"

# Cell 7 DELKEEP: Y's tree, but verdict.sh -- which Y KEPT -- deleted too.
from_tree delkeep "$YREC" || exit 2
rm -f "$PROJ/scripts/ai-dlc/verdict.sh"
commit "feat: ai-dlc update 0.4.0 (#106)" || exit 2
DELKEEP="$(g rev-parse HEAD)"

# Cell INRANGE: a hand-made copy, then a reconcile carrying the same content, in ONE range.
# The in-range reconcile must not acquit the commit before it (R excludes BASE..HEAD).
branch_from_base inrange
printf '0.3.0\n' > "$PROJ/.claude/.ai-dlc-version"
printf '#!/usr/bin/env bash\necho v7\n' > "$PROJ/scripts/ai-dlc/verdict.sh"
commit "feat: hand-copy the 0.3.0 verdict helper" || exit 2
INRANGE_T="$(g rev-parse HEAD)"
printf 'print("app v3")\n' > "$PROJ/server/app.py"
commit "chore(ai-dlc-update): reconcile distribution 0.1.0 -> 0.3.0" || exit 2
INRANGE="$(g rev-parse HEAD)"

# SEED ASSERTIONS: every content cell's discriminating input exists, or the seed refuses.
seedfail() { echo "seed: $1" >&2; exit 2; }
V=scripts/ai-dlc/verdict.sh; S=.claude/.ai-dlc-version
[ "$(g rev-parse "${SQUASH}^{tree}")" = "$(g rev-parse "${XREC}^{tree}")" ] || seedfail "SQUASH is not X's tree"
[ "$(g log -1 --format=%s "$SQUASH")" = "feat: ai-dlc update 0.2.0 (#101)" ] || seedfail "SQUASH subject"
g cat-file blob "$(blob "$BYTE" "$V")" > "$WORK/byte.b" 2>/dev/null || seedfail "BYTE blob unreadable"
g cat-file blob "$(blob "$XREC" "$V")" > "$WORK/x.b" 2>/dev/null || seedfail "X blob unreadable"
[ "$(wc -c < "$WORK/byte.b")" -eq "$(wc -c < "$WORK/x.b")" ] && [ "$(cmp -l "$WORK/byte.b" "$WORK/x.b" | wc -l)" -eq 1 ] \
  || seedfail "BYTE is not a one-byte difference from X"
[ "$(blob "$CHMOD" "$V")" = "$(blob "$XREC" "$V")" ] && [ "$(mode "$CHMOD" "$V")" != "$(mode "$XREC" "$V")" ] \
  || seedfail "CHMOD does not differ from X in mode alone"
[ "$(blob "$OLDBLOB" "$S")" = "$(blob "$XREC" "$S")" ] && [ "$(blob "$OLDBLOB" "$V")" = "$(blob "$OLDREC" "$V")" ] \
  && [ "$(blob "$OLDREC" "$S")" != "$(blob "$XREC" "$S")" ] || seedfail "OLDBLOB is not OLDREC's blob under X's stamp"
[ -z "$(blob "$YREC" .claude/hooks/ai-dlc-a.sh)" ] && [ -n "$(blob "$YREC" "$V")" ] && [ -z "$(blob "$DELKEEP" "$V")" ] \
  && [ -z "$(blob "$DELMATCH" .claude/hooks/ai-dlc-a.sh)" ] || seedfail "the deletion cells lack their deletions"
[ "$(blob "$INRANGE_T" "$V")" = "$(blob "$INRANGE" "$V")" ] && [ "$(blob "$INRANGE_T" "$S")" = "$(blob "$INRANGE" "$S")" ] \
  || seedfail "INRANGE's reconcile does not carry the hand-copy's stamp and blob"
for c in "$SQUASH" "$BYTE" "$CHMOD" "$OLDBLOB" "$INRANGE"; do
  g merge-base --is-ancestor "$XREC" "$c" && seedfail "X is an ancestor of $c, so deleting its ref cannot empty R"
done
# Mutation 3 must stay killable: no reconcile outside BASE..RECONCILE carries RECONCILE's stamp.
n="$(g log --branches --format='%H %s' | awk -v k="$RECONCILE" '$1 != k && index($0, "chore(ai-dlc-update):") { print $1 }' \
  | while IFS= read -r r; do [ "$(blob "$r" "$S")" = "$(blob "$RECONCILE" "$S")" ] && echo "$r"; done)"
[ -z "$n" ] || seedfail "another reconcile carries RECONCILE's stamp: $n"
# Positive control for the loop above, same pipeline minus the exclusion: it must find exactly
# RECONCILE, so its zero above is a search that could fire.
pc="$(g log --branches --format='%H %s' | awk 'index($0, "chore(ai-dlc-update):") { print $1 }' \
  | while IFS= read -r r; do [ "$(blob "$r" "$S")" = "$(blob "$RECONCILE" "$S")" ] && echo "$r"; done)"
[ "$pc" = "$RECONCILE" ] || seedfail "the stamp-uniqueness search did not find RECONCILE itself ($pc)"

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

# The citation arm DELEGATES to a sibling — it asks validate-escalation-resolution.sh whether
# the file carries an operator citation rather than restating that script's grammar. The
# control copy and every mutant copy live in $WORK, so the sibling has to be there too or all
# of them take the "delegate missing" exit-2 branch and every mutant scores as a kill at once.
# Take it from the SAME directory the resolver was found in — walking up a second time could
# resolve a different tree, and resolving it relative to $RESOLVER is the sibling-in-one-dir
# case install.sh preserves in both layouts, not the walk-up I33 forbids.
ESR_SRC="$(dirname "$RESOLVER")/validate-escalation-resolution.sh"
[ -f "$ESR_SRC" ] || { echo "seed: no validate-escalation-resolution.sh beside $RESOLVER" >&2; exit 2; }
cp "$ESR_SRC" "$WORK/validate-escalation-resolution.sh" || exit 2

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
XREC="$XREC"
OLDREC="$OLDREC"
YREC="$YREC"
SQUASH="$SQUASH"
BYTE="$BYTE"
CHMOD="$CHMOD"
OLDBLOB="$OLDBLOB"
DELMATCH="$DELMATCH"
DELKEEP="$DELKEEP"
INRANGE="$INRANGE"
DELPATH=".claude/hooks/ai-dlc-a.sh"
ENVEOF

echo "$WORK"
