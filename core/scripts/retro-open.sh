#!/usr/bin/env bash
# retro-open.sh <sprint-branch> <N> -- retro Step 1: land on the merged trunk, cut the retro branch
# ai-dlc/retro/sprint-<N> from origin/main, and carry onto it every sprint commit made after the
# sprint PR's head. Every outcome prints one `CARRY: ` line (steps/retro.md Step 1 states what each
# outcome means and what to do on it).
#
# exit: 0 the carry line is a count or `none`; 2 `HARD_BLOCK on-disk` (nothing moved, ON-DISK lines
#       name the paths); 3 `HARD_BLOCK unresolved`, `underivable` or `conflict`; 64 bad usage.
# It writes no snapshot, gate-log or escalation record: the retro step-entry snapshot write is the
# step prose's first action, and the Tier 1 HARD_BLOCK escalation on a HARD_BLOCK line is the lead's.
# Runs from inside the repository (cwd); it locates no sibling file.
SPRINT_BRANCH="${1:-}"; SPRINT_N="${2:-}"
case "$SPRINT_N" in ''|*[!0-9]*) echo "usage: retro-open.sh <sprint-branch> <N>" >&2; exit 64 ;; esac
[ -n "$SPRINT_BRANCH" ] || { echo "usage: retro-open.sh <sprint-branch> <N>" >&2; exit 64; }
OPEN_RC=0
# retro Step 1: cut the retro branch from the trunk, then carry the post-squash sprint commits
SPRINT_TIP="$(git rev-parse --verify -q "${SPRINT_BRANCH}^{commit}")"
git fetch origin main
TRUNK_HOLD="$( cd "$(git rev-parse --show-toplevel)" || exit
  { git rev-parse -q --verify refs/heads/main >/dev/null && git diff -z --name-only --no-renames HEAD main
    git diff -z --name-only --no-renames HEAD origin/main; } | sort -zu |
  while IFS= read -r -d '' p; do
    if ! git cat-file -e "HEAD:$p" 2>/dev/null && { [ -e "$p" ] || [ -L "$p" ]; }; then echo "ON-DISK $p"; fi
  done )"
if [ -n "$TRUNK_HOLD" ]; then
  echo "CARRY: HARD_BLOCK on-disk — main at origin/main tracks these paths, HEAD does not, and a file is on disk at each; move each aside and re-run the block"
  printf '%s\n' "$TRUNK_HOLD"
  OPEN_RC=2
else
git checkout main && git merge --ff-only origin/main
git rev-list --count HEAD..origin/main   # MUST be 0
git checkout -b ai-dlc/retro/sprint-${SPRINT_N} origin/main
if [ -z "$SPRINT_TIP" ]; then
  echo "CARRY: HARD_BLOCK unresolved — the sprint branch does not resolve, so its post-squash commits cannot be located"
  OPEN_RC=3
elif git merge-base --is-ancestor "$SPRINT_TIP" origin/main; then
  echo "CARRY: none — the sprint tip is already on origin/main"
else
  SPRINT_CHAIN="$(git rev-list --first-parent "$SPRINT_TIP")"
  FORK="$(while read -r c; do if git merge-base --is-ancestor "$c" origin/main; then echo "$c"; break; fi; done <<<"$SPRINT_CHAIN")"
  PR_HEAD=""; REC_SRC=""; REC_WHY=""
  REC="$(git show "${SPRINT_TIP}:${AI_DLC_STATE_DIR:-_bmad-output}/implementation-artifacts/s${SPRINT_N}/sprint-pr-merge.txt" 2>/dev/null)"
  if [ -n "$REC" ]; then
    if [ "$(grep -c '' <<<"$REC")" != 1 ] || grep -vqxE '[0-9]+ [0-9a-f]{40} [0-9a-f]{40}' <<<"$REC"; then
      REC_WHY="the record is not one line: PR number, head sha, squash sha"
    else
      read -r R_N R_H R_M <<<"$REC"
      if ! git merge-base --is-ancestor "$R_M" origin/main 2>/dev/null; then
        REC_WHY="squash $R_M of #$R_N is not on origin/main"
      elif ! git cat-file -e "${R_H}^{commit}" 2>/dev/null \
          && ! { git fetch -q origin "pull/$R_N/head" 2>/dev/null && git cat-file -e "${R_H}^{commit}" 2>/dev/null; }; then
        REC_WHY="PR head $R_H of #$R_N not local and not fetchable"
      elif git merge-base --is-ancestor "$R_H" "$SPRINT_TIP" 2>/dev/null || [ "$R_M" = "$FORK" ]; then
        PR_HEAD="$R_H"; REC_SRC=" (merged PR #$R_N, from the sprint-merge record)"
      else
        REC_WHY="PR head $R_H of #$R_N is not an ancestor of the sprint tip and squash $R_M is not its fork point"
      fi
    fi
  fi
  if [ -z "$REC" ] && [ -n "$FORK" ]; then
    TRUNK_TREES="$(git log --format=%T origin/main --not "$FORK")"
    SPRINT_ROWS="$(git log --first-parent --format='%T %H' "$SPRINT_TIP" --not "$FORK")"
    PR_HEAD="$(while read -r t h; do if grep -qxF "$t" <<<"$TRUNK_TREES"; then echo "$h"; break; fi; done <<<"$SPRINT_ROWS")"
  fi
  PR_SRC="$REC_SRC"; GH_WHY=""
  [ -n "$REC" ] && FORK=""
  if [ -z "$PR_HEAD" ] && [ -n "$FORK" ]; then
    if ! command -v gh >/dev/null 2>&1; then
      GH_WHY="gh unavailable"
    elif ! GH_ROWS="$(gh pr list --head "$SPRINT_BRANCH" --state merged --json number,headRefOid,mergeCommit \
        --jq '.[] | "\(.number) \(.headRefOid) \(.mergeCommit.oid)"')"; then
      GH_WHY="gh pr list exited non-zero"
    elif [ -z "$GH_ROWS" ]; then
      GH_WHY="gh lists no merged PR from $SPRINT_BRANCH"
    elif grep -vqE '^[0-9]+ [0-9a-f]{40} [0-9a-f]{40}$' <<<"$GH_ROWS"; then
      GH_WHY="gh printed a row that is not: PR number, head sha, merge sha"
    elif [ "$(awk -v f="$FORK" '$3 == f {n++} END {print n+0}' <<<"$GH_ROWS")" != 1 ]; then
      GH_WHY="not exactly one merged PR from $SPRINT_BRANCH has merge commit $FORK"
    else
      read -r GH_N GH_H GH_M <<<"$(awk -v f="$FORK" '$3 == f' <<<"$GH_ROWS")"
      GH_NEWER="$(while read -r n h m; do
          [ "$m" = "$GH_M" ] && continue
          git merge-base --is-ancestor "$GH_M" "$m" 2>/dev/null; r=$?
          [ "$r" = 1 ] || printf ' #%s' "$n"
        done <<<"$GH_ROWS")"
      if [ -n "$GH_NEWER" ]; then
        GH_WHY="merged PR(s)$GH_NEWER from $SPRINT_BRANCH descend from #$GH_N or cannot be compared with it"
      elif ! git cat-file -e "${GH_H}^{commit}" 2>/dev/null \
          && ! { git fetch -q origin "pull/$GH_N/head" 2>/dev/null && git cat-file -e "${GH_H}^{commit}" 2>/dev/null; }; then
        GH_WHY="PR head $GH_H of #$GH_N not local and not fetchable"
      elif [ "$(git rev-parse "${GH_H}^{tree}")" != "$(git rev-parse "${GH_M}^{tree}")" ]; then
        GH_WHY="the tree of PR head $GH_H differs from the tree of merge commit $GH_M of #$GH_N"
      else
        PR_HEAD="$GH_H"; PR_SRC=" (merged PR #$GH_N, from gh)"
      fi
    fi
  fi
  if [ -z "$PR_HEAD" ]; then
    [ -n "$REC_WHY" ] && echo "CARRY: HARD_BLOCK underivable — the sprint-merge record at the sprint tip is refused: $REC_WHY"
    [ -z "$REC_WHY" ] && echo "CARRY: HARD_BLOCK underivable — no sprint commit's tree equals a trunk commit's tree, so the squash's PR head is unknown${GH_WHY:+; gh fallback: $GH_WHY}"
    OPEN_RC=3
  else
    CARRY_N="$(git rev-list --count --no-merges "$SPRINT_TIP" --not "$PR_HEAD" origin/main)"
    if [ "$CARRY_N" = 0 ]; then
      echo "CARRY: none — no sprint commit follows PR head $PR_HEAD$PR_SRC"
    elif git cherry-pick --no-merges "$SPRINT_TIP" --not "$PR_HEAD" origin/main; then
      echo "CARRY: $CARRY_N commit(s) past PR head $PR_HEAD$PR_SRC carried onto the retro branch"
    else
      git cherry-pick --abort
      echo "CARRY: HARD_BLOCK conflict — a carried commit did not apply; the pick was aborted and the retro branch is back at origin/main"
      OPEN_RC=3
    fi
  fi
fi
fi
exit "$OPEN_RC"
