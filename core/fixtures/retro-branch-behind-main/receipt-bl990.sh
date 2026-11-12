#!/usr/bin/env bash
# receipt-bl990.sh [retro.md] -- the BL-990 receipt, both subjects, each a world built here and
# the shipping block extracted from retro.md and RUN in it (never a grep of the prose).
#
#   carry  retro.md Step 1 on a sprint branch RESET onto its squash and committed on three times
#          (the re-pointed shape): no sprint tree equals a trunk tree, so only gh can name the PR head.
#          A gh stub on PATH answers the block's exact `gh pr list` argv with the real producer's
#          row shape, `<number> <40 hex> <40 hex>`, for PR #7. PASS when the block prints exactly
#          `CARRY: 3 commit(s) past PR head <P> (merged PR #7, from gh) carried onto the retro branch`.
#   land   retro.md 7a-post step 1 in a clone whose `main` is checked out in a LINKED worktree.
#          PASS when the `# retro 7a-post step 1:` block prints the LAND HARD_BLOCK naming that
#          worktree and HEAD is not main. No such block (the bare fetch/checkout/ff chain, which
#          refuses nothing and prints no verdict) is FAIL: that is the defect reproducing.
#   merge  retro.md 7a with an argv-strict gh stub where `pr merge 42` exits 1 (local cleanup
#          failed after the remote squash) and `pr view 42` prints MERGED. PASS on exactly
#          `MERGE: merged — gh's local cleanup failed; 7a-post lands explicitly`. No `# retro 7a:`
#          block is FAIL.
#
# Exit 0 when all three cells PASS, 1 when any FAILs, 9 when it cannot measure: no retro.md, no
# Step 1 block in it, or a world that did not build. The retro.md is $1, else the one found by
# walking up from this file in either layout (core/skills/... upstream, .claude/skills/... in a
# consumer). Invoked by run.sh, which passes the retro.md it resolved.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

HERE="$(cd "$(dirname "$0")" && pwd)"
RETRO="${1:-}"
if [ -z "$RETRO" ]; then
  d="$HERE"
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    for c in "$d/core/skills/ai-dlc/steps/retro.md" "$d/.claude/skills/ai-dlc/steps/retro.md"; do
      [ -f "$c" ] && { RETRO="$c"; break 2; }
    done
    d="$(dirname "$d")"
  done
fi
[ -n "$RETRO" ] && [ -f "$RETRO" ] || { echo "receipt-bl990: no retro.md (given: ${1:-none}; none found above $HERE)" >&2; exit 9; }
grep -q '^# retro Step 1: cut the retro branch' "$RETRO" || { echo "receipt-bl990: $RETRO has no '# retro Step 1:' block" >&2; exit 9; }
command -v git >/dev/null 2>&1 || { echo "receipt-bl990: git not on PATH" >&2; exit 9; }

W="$(mktemp -d)" || exit 9
W="$(cd "$W" && pwd -P)"
trap 'rm -rf "$W"' EXIT
SB=ai-dlc/sprint-900
fail=0
die() { echo "receipt-bl990: $1" >&2; exit 9; }
gi() { git -c init.defaultBranch=main init -q "$1" && git -C "$1" config user.email r@example.com \
       && git -C "$1" config user.name Receipt && git -C "$1" config commit.gpgsign false; }
cm() { git -C "$1" add -A && git -C "$1" commit -q -m "$2"; }

# ---- carry ------------------------------------------------------------------------------------
s="$W/c-src"; mkdir -p "$s/gl" || exit 9
gi "$s" || die "carry: init failed"
printf 'REVISION 1\n' > "$s/gl/log.md"; cm "$s" C1 || die "carry: C1"
git -C "$s" checkout -q -b "$SB" || die "carry: branch"
printf 'REVISION 1\nREVISION 2\n' > "$s/gl/log.md"; cm "$s" "PR head" || die "carry: P"
P="$(git -C "$s" rev-parse HEAD)"
git -C "$s" checkout -q main && git -C "$s" merge -q --squash "$SB" >/dev/null 2>&1 && cm "$s" "squash" || die "carry: squash"
M="$(git -C "$s" rev-parse HEAD)"
git -C "$s" checkout -q "$SB" && git -C "$s" reset -q --hard "$M" || die "carry: re-point"
for k in 1 2 3; do echo "$k" > "$s/post-$k.txt"; cm "$s" "post-squash $k" || die "carry: post $k"; done
git -C "$s" checkout -q main && echo t > "$s/t.txt" && cm "$s" "trunk after" || die "carry: trunk"
git -C "$s" update-ref refs/keep/p "$P" || die "carry: keep ref"
git clone -q --bare "$s" "$W/c-remote.git" 2>/dev/null || die "carry: bare clone"
git clone -q "file://$W/c-remote.git" "$W/c" 2>/dev/null || die "carry: clone"
git -C "$W/c" config user.email r@example.com; git -C "$W/c" config user.name Receipt; git -C "$W/c" config commit.gpgsign false
git -C "$W/c" checkout -q -b "$SB" "origin/$SB" || die "carry: sprint checkout"
git -C "$W/c" fetch -q "file://$s" refs/keep/p 2>/dev/null && git -C "$W/c" cat-file -e "$P^{commit}" || die "carry: PR head not local"
mkdir -p "$W/gh" || exit 9
cat > "$W/gh/gh" <<'STUB'
#!/bin/bash
h="$(dirname "$0")"
T='.[] | "\(.number) \(.headRefOid) \(.mergeCommit.oid)"'
if [ "$#" = 10 ] && [ "$1 $2 $3 $4 $5 $6 $7 $8 $9" = "pr list --head ai-dlc/sprint-900 --state merged --json number,headRefOid,mergeCommit --jq" ] \
   && [ "${10}" = "$T" ]; then cat "$h/rows"; exit 0; fi
exit 97
STUB
chmod +x "$W/gh/gh" || exit 9
printf '7 %s %s\n' "$P" "$M" > "$W/gh/rows"
awk '/^### 1\. Context Loading/{s=1} s && /^### 2\./{exit}
     s && /^# retro Step 1:/{on=1} on && /^```$/{exit} on{print}' "$RETRO" \
  | sed -e "s@<sprint-branch>@$SB@g" -e 's@<N>@900@g' > "$W/step1.sh"
[ -s "$W/step1.sh" ] || die "the Step 1 block did not extract from $RETRO"
cout="$( cd "$W/c" && PATH="$W/gh:$PATH" bash "$W/step1.sh" 2>&1 )"
want="CARRY: 3 commit(s) past PR head $P (merged PR #7, from gh) carried onto the retro branch"
if grep -qxF "$want" <<<"$cout"; then
  echo "CELL carry PASS the re-pointed sprint branch carries its 3 post-squash commits from the PR head gh names"
else
  echo "CELL carry FAIL $(grep -m1 '^CARRY: ' <<<"$cout" || echo 'no CARRY line')"; fail=1
fi

# ---- land -------------------------------------------------------------------------------------
s="$W/l-src"; mkdir -p "$s" || exit 9
gi "$s" || die "land: init failed"
echo c1 > "$s/a.txt"; cm "$s" C1 || die "land: C1"
git clone -q --bare "$s" "$W/l-remote.git" 2>/dev/null || die "land: bare clone"
git clone -q "file://$W/l-remote.git" "$W/l" 2>/dev/null || die "land: clone"
git -C "$W/l" config user.email r@example.com; git -C "$W/l" config user.name Receipt; git -C "$W/l" config commit.gpgsign false
git -C "$W/l" checkout -q -b ai-dlc/retro/sprint-900 || die "land: retro branch"
git -C "$W/l" worktree add -q "$W/holder" main 2>/dev/null || die "land: worktree add"
echo merged > "$s/r.txt"; cm "$s" "retro (squashed)" || die "land: merged retro"
git -C "$W/l-remote.git" fetch -q "$s" +main:main 2>/dev/null || die "land: remote advance"
awk '/^# retro 7a-post step 1: land on the merged trunk$/{on=1} on && /^```$/{exit} on{print}' "$RETRO" > "$W/land.sh"
if [ ! -s "$W/land.sh" ]; then
  echo "CELL land FAIL $RETRO has no '# retro 7a-post step 1:' block: the bare chain refuses nothing"; fail=1
else
  lout="$( cd "$W/l" && bash "$W/land.sh" 2>&1 )"
  hd="$(git -C "$W/l" symbolic-ref -q --short HEAD)"
  if grep -qxF "LAND: HARD_BLOCK — not on main at origin/main; main is checked out in worktree: $W/holder" <<<"$lout" && [ "$hd" != main ]; then
    echo "CELL land PASS the LAND block refuses a main held by a linked worktree and names it"
  else
    echo "CELL land FAIL head=$hd $(grep -m1 '^LAND: ' <<<"$lout" || echo 'no LAND line')"; fail=1
  fi
fi
# ---- merge ------------------------------------------------------------------------------------
# 7a on the measured gh 2.103.3 shape: `gh pr merge` exits 1 after the remote squash because its
# local cleanup failed, and `gh pr view --json state --jq .state` prints MERGED. The stub answers
# exactly those two argv lists (PR 42) and refuses anything else with 97.
mkdir -p "$W/m" "$W/mcwd" || exit 9
cat > "$W/m/gh" <<'STUB'
#!/bin/bash
if [ "$*" = "pr merge 42 --squash --delete-branch" ]; then echo "failed to run git: fatal: main is already checked out" >&2; exit 1; fi
if [ "$*" = "pr view 42 --json state --jq .state" ]; then echo MERGED; exit 0; fi
exit 97
STUB
chmod +x "$W/m/gh" || exit 9
awk '/^# retro 7a: merge the retro PR, then read its state from GitHub$/{on=1} on && /^```$/{exit} on{print}' "$RETRO" \
  | sed -e 's@<pr-number>@42@g' > "$W/merge.sh"
if [ ! -s "$W/merge.sh" ]; then
  echo "CELL merge FAIL $RETRO has no '# retro 7a:' block: a merge whose local cleanup failed is decided on gh's exit alone"; fail=1
else
  mout="$( cd "$W/mcwd" && PATH="$W/m:$PATH" bash "$W/merge.sh" 2>&1 )"
  if grep -qxF "MERGE: merged — gh's local cleanup failed; 7a-post lands explicitly" <<<"$mout"; then
    echo "CELL merge PASS a merge that exits 1 after GitHub merged the PR is read as merged from the PR state"
  else
    echo "CELL merge FAIL $(grep -m1 '^MERGE: ' <<<"$mout" || echo 'no MERGE line')"; fail=1
  fi
fi
exit "$fail"
