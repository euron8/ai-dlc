#!/usr/bin/env bash
# dispatch-story.sh -- one call per dev dispatch: gh auth pre-flight, the story's worktree, the dispatch record,
# the dispatch transition row, and the brief skeleton the Agent call sends. Run from the lead checkout.
#
# usage:
#   dispatch-story.sh <s<N>-<story-index>> <base> [--teammate <name>]
#   <s<N>-<story-index>>  the record name; the index joins its parts with '-' (story 3.1 of sprint 323: s323-3-1).
#   <base>                the commit the worktree is cut from: the sprint-branch HEAD, or -- for a story that depends on
#                         a predecessor's CONTENT -- the predecessor's dev branch tip (branch name or sha), so it
#                         starts before the predecessor merges and gates.
#
# 1. `gh auth status` must succeed (HARD_BLOCK otherwise: exit 2, nothing created).
# 2. `git worktree add <repo>-s<N>-story-<index> -b dev/sprint-<N>/story-<index> <base sha>`.
# 3. `merge-review-shards.sh --record-dispatch <name> <base sha>` (a re-dispatch keeps the first value).
# 4. The dispatch transition row, through story-transition.sh --no-seam: ready-for-dev->in-progress, one --activity line.
#    No SEAM-C line is printed: the lead's per-transition Seam C check runs after the Agent call.
#    The In-Flight Teammates ROW is not written here: its agent cell needs the agentId the Agent call returns,
#    and ai-dlc-inflight-row.sh writes it from the brief's `Deliverable:` line.
# 5. The brief skeleton on stdout, opening with the `Deliverable: <path>` line the dispatch guard requires, then
#    the worktree line and the standing lines. The lead appends the story's route and delta and sends it.
#
# exit 0 dispatched (the brief follows the `BRIEF:` line); 2 refused, nothing created past the failing step.
set -u
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
refuse() { printf 'dispatch-story.sh: %s\n' "$*" >&2; exit 2; }

[ "$#" -ge 2 ] || refuse "usage: dispatch-story.sh <s<N>-<story-index>> <base> [--teammate <name>]"
NAME="$1"; BASE="$2"; shift 2
TEAMMATE="dev"
if [ "$#" -gt 0 ]; then
  [ "$#" -eq 2 ] && [ "$1" = "--teammate" ] && [ -n "$2" ] || refuse "unexpected arguments: $*"
  TEAMMATE="$2"
fi
case "$NAME" in
  s[0-9]*-?*) ;;
  *) refuse "'$NAME' is not s<N>-<story-index> (story 3.1 of sprint 323 is s323-3-1)" ;;
esac
N="${NAME%%-*}"; N="${N#s}"; IDX="${NAME#*-}"
case "$N" in '' | *[!0-9]*) refuse "'$NAME': the sprint id '$N' is not digits" ;; esac
case "$IDX" in '' | -* | *[!A-Za-z0-9_-]*) refuse "'$NAME': the story index '$IDX' may carry only letters, digits, _ and -" ;; esac
MRS="$SELF_DIR/merge-review-shards.sh"; ST="$SELF_DIR/story-transition.sh"
[ -f "$MRS" ] && [ -f "$ST" ] || refuse "merge-review-shards.sh and story-transition.sh must sit beside this program ($SELF_DIR)"

gh auth status > /dev/null 2>&1 < /dev/null || refuse "HARD_BLOCK: gh auth status failed (environment not authenticated); nothing created"
SHA="$(git --no-replace-objects rev-parse -q --verify "${BASE}^{commit}" 2> /dev/null < /dev/null)" \
  || refuse "<base> '$BASE' is not a commit in $(pwd); nothing created"
TOP="$(git rev-parse --show-toplevel 2> /dev/null < /dev/null)" || refuse "$(pwd) is not in a git repository"
WT="${TOP}-s${N}-story-${IDX}"
BR="dev/sprint-${N}/story-${IDX}"
[ ! -e "$WT" ] || refuse "$WT exists; a rework re-dispatch reuses it and runs only: bash $MRS --record-dispatch $NAME $SHA"

git worktree add "$WT" -b "$BR" "$SHA" > /dev/null 2>&1 < /dev/null || refuse "git worktree add $WT -b $BR $SHA failed"
bash "$MRS" --record-dispatch "$NAME" "$SHA" || refuse "--record-dispatch failed; the worktree $WT stands"
bash "$ST" "$NAME" ready-for-dev in-progress "$TEAMMATE" --no-seam || refuse "story-transition.sh failed; the worktree and record stand"

cat <<EOF
BRIEF:
Deliverable: ${WT}/_bmad-output/implementation-artifacts/dev-${NAME}.md
Worktree: ${WT} (branch ${BR}, cut from ${SHA}). Every absolute path in this brief is that worktree or inside it.
Every git command is \`git -C ${WT} <cmd>\`, or \`cd\` into the worktree on EVERY Bash call.
Never run \`git stash\` or \`git stash pop\` inside this worktree; for a before/after base compare use \`git worktree add --detach <base>\`.
Work only story ${NAME}; never claim another from a task list. Finished early: SendMessage to "main" and go idle.
Read at most 15 files before the first code write; commit signatures and file structure before filling bodies.
EOF
