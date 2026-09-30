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
# proves nothing; the MOVE mutant below proves this arm is not one.
#
# Exit 0 iff every arm holds; 1 on a finding; 2 (FIXTURE BROKEN) when a subject file
# cannot be located. An absent subject is never green: a consumer that pulled this
# fixture ahead of the step file must see the gap.
set -u
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

WORK="$(mktemp -d "${TMPDIR:-/tmp}/review-co-clauses.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
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

# --- mutants -----------------------------------------------------------------
# Each is a COPY of the resolved subject; `cmp -s` refuses a mutation that matched
# nothing, and each must produce ITS OWN finding and no other.
CTL="$WORK/review-control.md"; cp "$STEP" "$CTL"
if [ -z "$(check_review "$CTL")" ] && [ -n "$(sec3 "$CTL")" ]; then
  ok "CONTROL: an unmutated sprint-review copy passes and §3 is non-empty"
else
  bad "CONTROL: an unmutated sprint-review copy fails -- every mutant verdict below is uninterpretable"
fi

mutant() { # <checker> <subject> <name> <awk-program> <expected-finding-prefix> <label>
  local m="$WORK/$3.md" res others
  awk "$4" "$2" > "$m"
  if cmp -s "$2" "$m"; then bad "FIXTURE ERROR: mutation '$3' matched nothing"; return; fi
  res="$("$1" "$m")"
  if ! grep -qF -- "$5" <<<"$res"; then
    bad "MUTATION '$3' SURVIVED -- $6"
    return
  fi
  others="$(grep -vF -- "$5" <<<"$res")"
  if [ -n "$others" ]; then
    bad "MUTATION '$3' fired other arms too ($others) -- the arms are entangled"
  else
    ok "MUTATION '$3' killed by its own arm only: $6"
  fi
}

# ENV: the permission survives, its duty is cut -- the pre-fix text.
mutant check_review "$STEP" "env-no-duty" \
  '/^environmental seam MAY defer, and the lead files each deferred seam as an$/{print "environmental seam MAY defer."; skip=4; next} skip>0{skip--; next} {print}' \
  "ENV:" "cutting the carry-over duty from the environmental permission is caught"

mutant check_review "$STEP" "del-branch" \
  '/^\*\*Un-exercised decision branch\.\*\*/{d=1} d && /^[[:space:]]*$/{d=0; next} d{next} {print}' \
  "BRANCH:" "deleting the decision-branch paragraph is caught"

# MOVE: the paragraph leaves §3 and reappears verbatim at the top of §4. A whole-file
# grep still finds it; the section-keyed arm must not.
mutant check_review "$STEP" "move-branch" \
  '/^\*\*Un-exercised decision branch\.\*\*/{d=1} d{held=held $0 "\n"; if ($0 ~ /^[[:space:]]*$/) d=0; next} /^### 4\./{print; print ""; printf "%s", held; next} {print}' \
  "BRANCH:" "moving the decision-branch paragraph out of §3 (into §4) is caught"

mutant check_review "$STEP" "branch-no-owner" \
  '/^\*\*Un-exercised decision branch\.\*\*/{d=1} d{gsub(/`carry-over-evaluation\.md`/, "the backlog")} d && /^[[:space:]]*$/{d=0} {print}' \
  "BRANCH:" "a decision-branch paragraph that no longer names the carry-over owner is caught"

mutant check_review "$STEP" "no-section" \
  '/^### 3\. Fix and Re-Validate/{print "### 3. Rework"; next} {print}' \
  "SECTION:" "an unisolatable §3 is a finding, not an empty pass"

RCTL="$WORK/role-control.md"; cp "$ROLE" "$RCTL"
if [ -z "$(check_role "$RCTL")" ] && [ -n "$(item15 "$RCTL")" ]; then
  ok "CONTROL: an unmutated dev.md copy passes and item 15 is non-empty"
else
  bad "CONTROL: an unmutated dev.md copy fails -- every role mutant verdict below is uninterpretable"
fi

# A bullet runs from its `- [ ] **<label>` line to the next line opening with `- ` or at column 0.
DELB='index($0, "- [ ] **" lab){d=1; next} d && (/^[[:space:]]*- /||/^[^[:space:]]/){d=0} d{next} {print}'
mutant check_role "$ROLE" "del-edit" "BEGIN{lab=\"Edit-already-present check.\"} $DELB" \
  "EDIT:" "deleting the edit-already-present bullet is caught"
mutant check_role "$ROLE" "del-order" "BEGIN{lab=\"Wall-clock ordering evidence.\"} $DELB" \
  "ORDER:" "deleting the wall-clock ordering bullet is caught"
# MOVE: the bullet leaves item 15 and reappears verbatim under `## Communication`. A
# whole-file grep still finds it; the item-keyed arm must not.
mutant check_role "$ROLE" "move-order" \
  'BEGIN{lab="- [ ] **Wall-clock ordering evidence."} index($0, lab){d=1; held=$0 "\n"; next} d && (/^[[:space:]]*- /||/^[^[:space:]]/){d=0} d{held=held $0 "\n"; next} /^## Communication$/{print; print ""; printf "%s", held; next} {print}' \
  "ORDER:" "moving the wall-clock ordering bullet out of item 15 (into Communication) is caught"
mutant check_role "$ROLE" "no-item15" \
  '/^15\. /{sub(/^15\. /, "15) ")} {print}' \
  "ITEM15:" "an unisolatable item 15 is a finding, not an empty pass"

echo
if [ "$rc" -eq 0 ]; then
  echo "review-carry-over-clauses: PASS"
else
  echo "review-carry-over-clauses: FAILED" >&2
fi
exit $rc
