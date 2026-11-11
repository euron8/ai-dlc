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

# --- BL-945: the one batched walk, against the merge and rename shapes it must agree on -------
# Each new reconcile carries its OWN stamp (0.5.0, 0.6.0), so no eligible set above moves, and
# each new sprint commit's core blob differs from RECONCILE's, so the content arm acquits none.
# EVIL: neither side touches verdict.sh; the MERGE rewrites it. Listed only with -c.
branch_from_base evil-side
printf 'print("evil side")\n' > "$PROJ/server/app.py"
commit "feat(s1): side edits the app" || exit 2
branch_from_base evil
printf 'print("other")\n' > "$PROJ/server/other.py"
commit "feat(s1): main adds a module" || exit 2
g merge -q --no-ff --no-commit evil-side >/dev/null 2>&1 || exit 2
printf '#!/usr/bin/env bash\necho evil\n' > "$PROJ/scripts/ai-dlc/verdict.sh"
commit "Merge branch evil-side" || exit 2
EVIL="$(g rev-parse HEAD)"
# NOFF: a reconcile on its update branch, merged --no-ff under a PR subject. The merge equals
# its second parent at verdict.sh, so -c does not list it; -m lists it against the first.
branch_from_base ai-dlc-update/noff
printf '0.5.0\n' > "$PROJ/.claude/.ai-dlc-version"
printf '#!/usr/bin/env bash\necho v10\n' > "$PROJ/scripts/ai-dlc/verdict.sh"
commit "chore(ai-dlc-update): reconcile distribution 0.1.0 -> 0.5.0" || exit 2
NOFF_REC="$(g rev-parse HEAD)"
branch_from_base noff
printf 'print("app noff")\n' > "$PROJ/server/app.py"
commit "feat(s1): main moves on" || exit 2
g merge -q --no-ff --no-edit -m "Merge pull request #7 from ai-dlc-update/noff" ai-dlc-update/noff >/dev/null 2>&1 || exit 2
NOFF="$(g rev-parse HEAD)"
# RENREW: a core path renamed out of core, then the new file rewritten, so the range diff sees
# a deletion of the core path. With renames on, the rename commit names only the new path.
branch_from_base renrew
mkdir -p "$PROJ/server"
g mv .claude/hooks/ai-dlc-a.sh server/moved.sh >/dev/null 2>&1 || exit 2
commit "fix(s1): move the hook out of core" || exit 2
RENREW_T="$(g rev-parse HEAD)"
printf 'print("rewritten %s")\n' one two three four five six > "$PROJ/server/moved.sh"
commit "fix(s1): rewrite the moved module" || exit 2
RENREW="$(g rev-parse HEAD)"
# CASEB: the DECLARED DIVERGENCE. One identical edit of verdict.sh on both sides: a sprint
# commit X on the side branch and a reconcile R on the first-parent line. The per-path walk's
# history simplification follows R alone; the batched walk lists X too.
branch_from_base caseb-side
printf '#!/usr/bin/env bash\necho caseb\n' > "$PROJ/scripts/ai-dlc/verdict.sh"
commit "feat(s1): hand-apply the caseb helper" || exit 2
CASEB_X="$(g rev-parse HEAD)"
branch_from_base caseb
printf '0.6.0\n' > "$PROJ/.claude/.ai-dlc-version"
printf '#!/usr/bin/env bash\necho caseb\n' > "$PROJ/scripts/ai-dlc/verdict.sh"
commit "chore(ai-dlc-update): reconcile distribution 0.1.0 -> 0.6.0" || exit 2
CASEB_R="$(g rev-parse HEAD)"
g merge -q --no-edit -m "Merge branch caseb-side" caseb-side >/dev/null 2>&1 || exit 2
CASEB="$(g rev-parse HEAD)"
# NOMAN: a layered base with NO manifest at the ref, so the working-tree fallback answers.
branch_from_base noman
g rm -q .claude/skills/ai-dlc/core-manifest.md >/dev/null 2>&1 || exit 2
commit "chore: drop the manifest" || exit 2
NOMAN="$(g rev-parse HEAD)"
printf '#!/usr/bin/env bash\necho noman\n' > "$PROJ/scripts/ai-dlc/verdict.sh"
commit "fix(s1): edit the helper with no manifest at base" || exit 2
NOMAN_DIRTY="$(g rev-parse HEAD)"
# UNREL: an unrelated-history ROOT that adds a core path, merged --allow-unrelated-histories.
# The merge equals its second parent at the path, so -c does not list it; only the root commit
# names the path, and log.showRoot=false hides a root's file list unless the walk says --root.
ub="$(printf 'orphan\n' | g hash-object -w --stdin)" || exit 2
GIT_INDEX_FILE="$WORK/unrel.idx" g update-index --add --cacheinfo "100644,$ub,scripts/ai-dlc/new.sh" || exit 2
ut="$(GIT_INDEX_FILE="$WORK/unrel.idx" g write-tree)" || exit 2
UNREL_ROOT="$(g commit-tree "$ut" -m "feat: unrelated root")" || exit 2
branch_from_base unrel || exit 2
g merge -q --allow-unrelated-histories --no-edit -m "Merge unrelated" "$UNREL_ROOT" >/dev/null 2>&1 || exit 2
UNREL="$(g rev-parse HEAD)"

# --- BL-951: renames and quoted paths in CHANGED ----------------------------------------------
# Non-ASCII names are spelled in octal so this file stays ASCII. Branch names avoid the ones the
# BL-951 receipt creates on this seed (ro, dl, na, as).
NA_P="$(printf 'scripts/ai-dlc/v\303\251rdict.sh')"
RON_P="$(printf 'server/m\303\251.sh')"
QQ_P='scripts/ai-dlc/q"x.sh'
BS_P='scripts/ai-dlc/b\x.sh'
TB_P="$(printf 'scripts/ai-dlc/t\tx.sh')"
QN1_P='server/q"x.sh'
QN2_P="$(printf 'server/t\tx.sh')"
# RENOUT: a core path renamed out of core in one commit; with renames on the range lists only
# the new, non-core name.
branch_from_base renout
g mv .claude/hooks/ai-dlc-a.sh server/moved.sh >/dev/null 2>&1 || exit 2
commit "fix(s1): move the hook out of core" || exit 2
RENOUT="$(g rev-parse HEAD)"
# RENOUTNA: the same rename, to a non-ASCII non-core name.
branch_from_base renout-na
g mv .claude/hooks/ai-dlc-a.sh "$RON_P" >/dev/null 2>&1 || exit 2
commit "fix(s1): move the hook out to a non-ascii name" || exit 2
RENOUTNA="$(g rev-parse HEAD)"
# NAADD: a non-ASCII core path added by an ordinary commit.
branch_from_base na-add
printf 'x\n' > "$PROJ/$NA_P" || exit 2
commit "fix(s1): add a non-ascii core script" || exit 2
NAADD="$(g rev-parse HEAD)"
# RR: a core-to-core rename.
branch_from_base core-rename
g mv scripts/ai-dlc/verdict.sh scripts/ai-dlc/verdict2.sh >/dev/null 2>&1 || exit 2
commit "fix(s1): rename the verdict helper within core" || exit 2
RR="$(g rev-parse HEAD)"
# QQ, BS, TB: a core path git C-quotes even under core.quotePath=false.
branch_from_base quote-dq
printf 'x\n' > "$PROJ/$QQ_P" || exit 2
commit "fix(s1): add a core script with a double quote" || exit 2
QQ="$(g rev-parse HEAD)"
branch_from_base quote-bs
printf 'x\n' > "$PROJ/$BS_P" || exit 2
commit "fix(s1): add a core script with a backslash" || exit 2
BS="$(g rev-parse HEAD)"
branch_from_base quote-tab
printf 'x\n' > "$PROJ/$TB_P" || exit 2
commit "fix(s1): add a core script with a tab" || exit 2
TB="$(g rev-parse HEAD)"
# QNEAR: the near-miss, the same two quoting bytes on NON-core paths.
branch_from_base quote-near
printf 'x\n' > "$PROJ/$QN1_P" || exit 2
printf 'x\n' > "$PROJ/$QN2_P" || exit 2
commit "feat(s1): add two consumer files with quoting bytes" || exit 2
QNEAR="$(g rev-parse HEAD)"
# NAREC: a reconcile adding the non-ASCII core path, stamp 0.8.0; NASQ its tree squashed (passes
# by the content arm); NASQB the same squash one byte off on that path (flags).
branch_from_base ai-dlc-update/na8
printf '0.8.0\n' > "$PROJ/.claude/.ai-dlc-version"
printf 'y\n' > "$PROJ/$NA_P" || exit 2
commit "chore(ai-dlc-update): reconcile distribution 0.1.0 -> 0.8.0" || exit 2
NAREC="$(g rev-parse HEAD)"
from_tree nasq "$NAREC" || exit 2
commit "feat: ai-dlc update 0.8.0 (#202)" || exit 2
NASQ="$(g rev-parse HEAD)"
from_tree nasqb "$NAREC" || exit 2
printf 'z\n' > "$PROJ/$NA_P" || exit 2
commit "feat: ai-dlc update 0.8.0 (#203)" || exit 2
NASQB="$(g rev-parse HEAD)"
# NFDADD: NAREC's tree plus an NFD-spelled core path, by an ordinary commit on base. Built through
# a scratch index with precomposition off, so the NFD bytes are what the tree stores. NAREC is
# eligible (same stamp) and lacks the path, so a path read back as ABSENT is acquitted.
NFD_P="$(printf 'scripts/ai-dlc/ve\314\201rdict9.sh')"
nb="$(printf 'nfd\n' | g hash-object -w --stdin)" || exit 2
GIT_INDEX_FILE="$WORK/nfd.idx" g read-tree "$NAREC" || exit 2
GIT_INDEX_FILE="$WORK/nfd.idx" g -c core.precomposeunicode=false update-index --add --cacheinfo "100644,$nb,$NFD_P" || exit 2
nt="$(GIT_INDEX_FILE="$WORK/nfd.idx" g write-tree)" || exit 2
NFDADD="$(g commit-tree "$nt" -p "$BASE" -m "feat: add an nfd-named core script")" || exit 2
g update-ref refs/heads/nfd-add "$NFDADD" || exit 2
# PRECOMPOSE=1 when this git rewrites an NFD command-line pathspec under precomposeunicode=true
# (macOS); elsewhere the setting is inert and mutation 24 has no observable to kill.
n_on="$(g -c core.precomposeunicode=true ls-tree -r --full-tree "$NFDADD" -- "$NFD_P" | wc -l | tr -d ' ')"
n_off="$(g -c core.precomposeunicode=false ls-tree -r --full-tree "$NFDADD" -- "$NFD_P" | wc -l | tr -d ' ')"
[ "$n_off" -eq 1 ] || { echo "seed: the NFD path does not list under precomposeunicode=false ($n_off)" >&2; exit 2; }
if [ "$n_on" -eq 0 ]; then PRECOMPOSE=1; else PRECOMPOSE=0; fi

# SEED ASSERTIONS: every content cell's discriminating input exists, or the seed refuses.
seedfail() { echo "seed: $1" >&2; exit 2; }
# UNREL: the root has no parent, and the merge does not differ from it at new.sh.
[ -z "$(g rev-list --parents -n1 "$UNREL_ROOT" | cut -s -d' ' -f2)" ] && [ "$(blob "$UNREL" scripts/ai-dlc/new.sh)" = "$ub" ] \
  || seedfail "UNREL is not a merged parentless root adding scripts/ai-dlc/new.sh"
# BL-945 cells: each shape the walk's flags decide is present.
[ "$(g rev-list --parents -1 "$EVIL" | wc -w | tr -d ' ')" -eq 3 ] || seedfail "EVIL is not a merge"
[ -z "$(g log --format=%H "${BASE}..${EVIL}^1" -- scripts/ai-dlc/verdict.sh)" ] && [ -z "$(g log --format=%H "${BASE}..${EVIL}^2" -- scripts/ai-dlc/verdict.sh)" ] \
  || seedfail "a side of EVIL touches verdict.sh, so only the merge must"
[ "$(blob "$NOFF" scripts/ai-dlc/verdict.sh)" = "$(blob "$NOFF_REC" scripts/ai-dlc/verdict.sh)" ] && [ "$(blob "${NOFF}^1" scripts/ai-dlc/verdict.sh)" != "$(blob "$NOFF" scripts/ai-dlc/verdict.sh)" ] \
  || seedfail "NOFF's merge does not equal its reconcile parent at verdict.sh and differ from its first parent"
rr_diff="$(g diff --name-only "${BASE}...${RENREW}")"; rr_log="$(g log -1 --format= --name-only "$RENREW_T")"
grep -qxF .claude/hooks/ai-dlc-a.sh <<<"$rr_diff" || seedfail "RENREW's range diff does not name the core path"
grep -qxF .claude/hooks/ai-dlc-a.sh <<<"$rr_log" && seedfail "with renames on, RENREW_T names the core path, so --no-renames decides nothing"
grep -qxF server/moved.sh <<<"$rr_log" || seedfail "RENREW_T's rename-on listing lacks the new path (control)"
cb="$(g log --format=%H "${BASE}..${CASEB}" -- scripts/ai-dlc/verdict.sh)"
[ "$cb" = "$CASEB_R" ] || seedfail "the per-path walk over CASEB does not list R alone ($cb), so case B diverges nowhere"
[ "$(g rev-parse "${CASEB}^1")" = "$CASEB_R" ] || seedfail "CASEB's first parent is not R"
[ -z "$(blob "$NOMAN" .claude/skills/ai-dlc/core-manifest.md)" ] && [ -n "$(blob "$NOMAN" .claude/skills/ai-dlc/overrides/README.md)" ] \
  || seedfail "NOMAN is not a layered base without a manifest"
# BL-951 cells: each defect's input is present at git's defaults, and each quoted cell is still
# quoted with core.quotePath=false while the non-ASCII cells are not.
dflt() { g -c core.quotePath=true -c diff.renames=true diff --name-only "${BASE}...${1}"; }
fixd() { g -c core.quotePath=false diff --no-renames --name-only "${BASE}...${1}"; }
[ "$(dflt "$RENOUT")" = server/moved.sh ] || seedfail "RENOUT's default diff does not list only the new name"
grep -qxF .claude/hooks/ai-dlc-a.sh <<<"$(fixd "$RENOUT")" || seedfail "RENOUT's rename-free diff lacks the old core path (control)"
grep -qxF .claude/hooks/ai-dlc-a.sh <<<"$(dflt "$RENOUTNA")" && seedfail "RENOUTNA's default diff names the old core path"
case "$(dflt "$NAADD")" in '"'*) ;; *) seedfail "NAADD's default diff is not C-quoted" ;; esac
[ "$(fixd "$NAADD")" = "$NA_P" ] || seedfail "NAADD's quotePath=false diff is not the raw-byte path"
[ "$(dflt "$RR")" = scripts/ai-dlc/verdict2.sh ] || seedfail "RR's default diff does not list only the new name"
for c in "$QQ" "$BS" "$TB"; do
  case "$(fixd "$c")" in '"scripts/ai-dlc/'*) ;; *) seedfail "a quoted core cell is not C-quoted under quotePath=false" ;; esac
done
[ "$(fixd "$QNEAR" | grep -c '^"server/')" -eq 2 ] || seedfail "QNEAR does not carry two C-quoted non-core lines"
[ "$(g rev-parse "${NASQ}^{tree}")" = "$(g rev-parse "${NAREC}^{tree}")" ] || seedfail "NASQ is not NAREC's tree"
[ -n "$(blob "$NASQB" "$NA_P")" ] && [ "$(blob "$NASQB" "$NA_P")" != "$(blob "$NAREC" "$NA_P")" ] \
  && [ "$(blob "$NASQB" .claude/.ai-dlc-version)" = "$(blob "$NAREC" .claude/.ai-dlc-version)" ] \
  || seedfail "NASQB is not NAREC's tree with the non-ASCII path's blob changed"
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
EVIL="$EVIL"
NOFF="$NOFF"
RENREW="$RENREW"
RENREW_T="$RENREW_T"
CASEB="$CASEB"
CASEB_X="$CASEB_X"
CASEB_R="$CASEB_R"
NOMAN="$NOMAN"
NOMAN_DIRTY="$NOMAN_DIRTY"
UNREL="$UNREL"
UNREL_ROOT="$UNREL_ROOT"
DELPATH=".claude/hooks/ai-dlc-a.sh"
RENOUT="$RENOUT"
RENOUTNA="$RENOUTNA"
NAADD="$NAADD"
RR="$RR"
QQ="$QQ"
BS="$BS"
TB="$TB"
QNEAR="$QNEAR"
NAREC="$NAREC"
NASQ="$NASQ"
NASQB="$NASQB"
NFDADD="$NFDADD"
PRECOMPOSE="$PRECOMPOSE"
ENVEOF

echo "$WORK"
