#!/usr/bin/env bash
# Pin the carry-over clauses in sprint-review.md §3 (Fix and Re-Validate), and the
# two evidence bullets in team-roles/dev.md's pre-submission self-check (item 15).
#
# SUBJECT. §3 lets a genuinely environmental integration seam defer, and binds that
# deferral to an OPEN carry-over item owned by `carry-over-evaluation.md`. §3 also
# carries the "Un-exercised decision branch." paragraph: a shipped decision branch no
# live event has taken gets a passive, organic-trigger carry-over filed at this step.
# No script reads either clause; the executing lead reads this prose, so the prose is
# the mechanism and this fixture pins it.
#
# KEYED ON POSITION, NOT THE FILE. The deferral duty must sit in the SAME sentence as
# the environmental permission, and the decision-branch paragraph must sit inside §3's
# body (heading `### 3. Fix and Re-Validate` up to the next `### ` heading) and name
# the carry-over owner. `carry-over` occurs elsewhere in the file, so a whole-file grep
# proves nothing.
#
# Exit 0 iff every arm holds; 1 on a finding; 2 (FIXTURE BROKEN) when a subject file
# cannot be located. An absent subject is never green: a consumer that pulled this
# fixture ahead of the step file must see the gap.
#
# Usage: run.sh ; --probe-only is the fixture's own cwd re-invocation, never an operator flag.
set -u
case "${1:-}" in
  ""|--probe-only) ;;
  *) echo "review-carry-over-clauses: usage: run.sh" >&2; exit 2 ;;
esac
DIR="$(cd "$(dirname "$0")" && pwd)"

locate() { # <in-repo rel from core/> <installed rel from project root>
  local c
  for c in "$DIR/../../$1" "$DIR/../../../$2"; do
    [ -f "$c" ] && { printf '%s\n' "$c"; return 0; }
  done
  return 1
}
STEP="$(locate skills/ai-dlc/steps/sprint-review.md .claude/skills/ai-dlc/steps/sprint-review.md)" || {
  echo "review-carry-over-clauses: FIXTURE BROKEN -- could not locate sprint-review.md in either layout. An absent subject is not a passing one." >&2
  exit 2
}

rc=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; rc=1; }

ROLE="$(locate team-roles/dev.md .claude/team-roles/dev.md)" || {
  echo "review-carry-over-clauses: FIXTURE BROKEN -- could not locate team-roles/dev.md in either layout. An absent subject is not a passing one." >&2
  exit 2
}

echo "review-carry-over-clauses: sprint-review subject $STEP"
echo "review-carry-over-clauses: dev role subject $ROLE"

sec3() { # <file> -> §3 body, heading line excluded
  awk '/^### 3\. Fix and Re-Validate/{on=1; next} on && /^### /{exit} on{print}' "$1"
}
para() { # <bold-label-regex> -> stdin paragraph opening with that label, to the blank line
  awk -v re="$1" '$0 ~ re {on=1} on && /^[[:space:]]*$/{exit} on{print}'
}
flat() { # stdin -> one line, runs of whitespace collapsed, bold markers dropped
  tr '\n' ' ' | sed -e 's/\*\*//g' -e 's/[[:space:]][[:space:]]*/ /g'
}

# check_review <file> -> one line per failing arm; nothing when every arm holds.
# Presence-shaped throughout, so an empty §3 fails every arm rather than passing any.
check_review() {
  local f="$1" body fl br
  body="$(sec3 "$f")"
  if [ -z "$body" ]; then echo "SECTION: §3 could not be isolated"; return; fi
  fl="$(flat <<<"$body")"
  # ENV: the duty is in the permission's own sentence -- the text between the
  # permission and the next sentence end must name the carry-over owner.
  case "$fl" in
    *'Only a genuinely environmental seam MAY defer, and the lead files each deferred seam as an OPEN carry-over item in '*'(ID grammar and `Status: OPEN` floor owned by `carry-over-evaluation.md`)'*) : ;;
    *) echo "ENV: the environmental-seam permission in §3 carries no carry-over duty in the same sentence" ;;
  esac
  br="$(para '^\*\*Un-exercised decision branch\.\*\*' <<<"$body" | flat)"
  if [ -z "$br" ]; then
    echo "BRANCH: §3 has no 'Un-exercised decision branch.' paragraph"
  else
    case "$br" in *'carry-over-evaluation.md'*'first organic event that takes the branch'*) : ;;
      *) echo "BRANCH: the decision-branch paragraph does not file a carry-over under carry-over-evaluation.md reopened by the first organic event" ;;
    esac
  fi
}

# --- dev.md: the pre-submission self-check (Workflow item 15) ------------------
# Two checklist bullets must sit INSIDE item 15's list (from `15. ` to `16. `): the
# edit-already-present check and the wall-clock ordering evidence rule. `git diff`
# already occurs elsewhere in item 15, so the arm reads each bullet's own body.
item15() { # <file> -> item 15's body, from its opening line up to item 16
  awk '/^15\. /{on=1} on && /^16\. /{exit} on{print}' "$1"
}
bullet() { # <label> -> stdin checklist bullet opening `- [ ] **<label>`, to the next bullet or dedent
  awk -v lab="- [ ] **$1" 'index($0, lab){on=1; print; next} on && (/^[[:space:]]*- /||/^[^[:space:]]/){exit} on{print}'
}
check_role() {
  local f="$1" body b
  body="$(item15 "$f")"
  if [ -z "$body" ]; then echo "ITEM15: Workflow item 15 could not be isolated"; return; fi
  b="$(bullet 'Edit-already-present check.' <<<"$body" | flat)"
  case "$b" in *'run `git diff` and read whether the intended change is already in the working tree'*'do not apply it a second time'*) : ;;
    *) echo "EDIT: item 15 has no edit-already-present bullet requiring a git diff read before re-issuing an edit" ;;
  esac
  b="$(bullet 'Wall-clock ordering evidence.' <<<"$body" | flat)"
  case "$b" in *'wall-clock ordering of concurrent processes'*'N≥10 real-process runs, every one clean'*'Mocked-timing unit tests and a single live run do not satisfy the AC'*) : ;;
    *) echo "ORDER: item 15 has no wall-clock ordering bullet requiring N≥10 clean real-process runs" ;;
  esac
}

# --- the subjects ------------------------------------------------------------
out="$(check_review "$STEP")"
if [ -z "$out" ]; then
  ok "§3 binds the environmental deferral to a carry-over and carries the decision-branch carry-over paragraph"
else
  while IFS= read -r l; do bad "$l"; done <<<"$out"
fi
out="$(check_role "$ROLE")"
if [ -z "$out" ]; then
  ok "dev.md item 15 carries the edit-already-present and wall-clock ordering bullets"
else
  while IFS= read -r l; do bad "$l"; done <<<"$out"
fi

# --- cwd invariance: the resolver keys on \$DIR, never on the process cwd ------
[ "${1:-}" = "--probe-only" ] && exit "$rc"
if ( cd / && bash "$DIR/run.sh" --probe-only ) >/dev/null 2>&1; then
  ok "CWD: the fixture resolves its subjects from / as well as from the repo root"
else
  bad "CWD: run from / the fixture could not resolve or pass its subjects"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "review-carry-over-clauses: PASS"
else
  echo "review-carry-over-clauses: FAILED" >&2
fi
exit $rc
