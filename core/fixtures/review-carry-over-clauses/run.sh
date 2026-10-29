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
#
# THE MUTANT MATRIX. Each mutant is a copy of a subject read by ONE checker (check_review: ENV, BRANCH,
# SECTION; check_role: ITEM15, EDIT, ORDER), so its cells are that checker's arms. PER PUSH a mutant is
# scored on its DECIDING arm (its finding must be present) and its named TWIN (a different arm of the same
# checker, which must stay GREEN); `run.sh --matrix` scores it against every arm of its checker and prints
# one MATRIX line. The arms of the other checker read the other subject, which the mutation never touches, so
# they are not cells of this mutant. The matrix is re-measured whenever an arm or a mutant is added or changed,
# by the REMEASURE command below, run from the repo root.
# MUTANT-MATRIX env-no-duty decides=ENV twins=BRANCH
# MUTANT-MATRIX del-branch decides=BRANCH twins=ENV
# MUTANT-MATRIX move-branch decides=BRANCH twins=ENV
# MUTANT-MATRIX branch-no-owner decides=BRANCH twins=ENV
# MUTANT-MATRIX no-section decides=SECTION twins=ENV
# MUTANT-MATRIX del-edit decides=EDIT twins=ORDER
# MUTANT-MATRIX del-order decides=ORDER twins=EDIT
# MUTANT-MATRIX move-order decides=ORDER twins=EDIT
# MUTANT-MATRIX no-item15 decides=ITEM15 twins=EDIT
# MUTANT-MATRIX-CONTROL CONTROL-review why=an unmutated sprint-review copy must pass check_review so a mutant finding is attributable to the mutation
# MUTANT-MATRIX-CONTROL CONTROL-role why=an unmutated dev.md copy must pass check_role so a mutant finding is attributable to the mutation
# The one helper that scores every mutant receives the mutant name as a positional parameter:
# MUTANT-MATRIX-DYNAMIC mutant why=reads the nine mutant names from its callers as a variable and every name keeps its own row
# MUTANT-MATRIX-REMEASURE bash core/fixtures/review-carry-over-clauses/run.sh --matrix
#
# Usage: run.sh [--matrix] ; --probe-only is the fixture's own cwd re-invocation, never an operator flag.
set -u
MODE=plain
case "${1:-}" in
  ""|--probe-only) ;;
  --matrix) MODE=matrix ;;
  *) echo "review-carry-over-clauses: usage: run.sh [--matrix]" >&2; exit 2 ;;
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
MUT_LIB="$DIR/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "review-carry-over-clauses: FIXTURE ERROR -- lib/mutant.sh not found beside $DIR" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
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
  ok "CONTROL-review: an unmutated sprint-review copy passes and §3 is non-empty"; B_ctl_review=1
else
  bad "CONTROL-review: an unmutated sprint-review copy fails -- every mutant verdict below is uninterpretable"
fi

# ---- matrix plumbing. The header rows are the only source of a mutant's deciding arm and twin. ----
MXL="$WORK/mx.ledger"; : > "$MXL"
mx_row() { # <mutant> <decides|twins> -> that field of the mutant's single header row
  local n="$1" f="$2" l w c=0 v=""
  while IFS= read -r l; do
    case "$l" in
      "# MUTANT-MATRIX $n "*)
        c=$((c + 1))
        for w in ${l#"# MUTANT-MATRIX $n "}; do case "$w" in "$f="*) v="${w#"$f="}" ;; esac; done ;;
    esac
  done < "$DIR/run.sh"
  [ "$c" -eq 1 ] && printf '%s' "$v"
}
mx_count() { local k="$1" l n=0; while IFS= read -r l; do case "$l" in "$k "*) n=$((n + 1)) ;; esac; done < "$MXL"; printf '%s' "$n"; }
arm_red() { grep -q -- "^$1:" <<<"$2"; } # <arm> <checker output> -> 0 when that arm printed a finding (RED)

# mutant <checker> <subject> <name> <awk-program> <expected-finding-prefix> <label> <base-pass flag>
# The flag is a positional parameter; every caller passes "${B_ctl_review:-0}" or "${B_ctl_role:-0}".
mutant() {
  local m="$WORK/$3.md" res dec tw a arms g=0 tot=0 d t u="" cerr="$WORK/$3.err"
  awk "$4" "$2" > "$m"
  if cmp -s "$2" "$m"; then bad "FIXTURE ERROR: mutation '$3' matched nothing"; return; fi
  res="$("$1" "$m" 2>"$cerr")"
  case "$(cat "$cerr")" in
    *"unbound variable"*|*"command not found"*|*"syntax error"*)
      if [ "$MODE" = matrix ]; then echo "MATRIX BROKEN $3"; exit 2; fi
      bad "FIXTURE BROKEN: mutation '$3' crashed the checker, which reads as no finding"; return ;;
  esac
  case "$1" in check_review) arms="ENV BRANCH SECTION" ;; *) arms="ITEM15 EDIT ORDER" ;; esac
  dec="$(mx_row "$3" decides)"; tw="$(mx_row "$3" twins)"
  if [ -z "$dec" ] || [ -z "$tw" ] || [ "${5%:}" != "$dec" ]; then
    bad "FIXTURE ERROR: the MUTANT-MATRIX row of '$3' is missing or names a deciding arm other than ${5%:}"; return
  fi
  printf 'dec %s %s\n' "$3" "$dec" >> "$MXL"; printf 'dec %s %s\n' "$3" "$tw" >> "$MXL"
  if arm_red "$dec" "$res"; then d=RED; else d=GREEN; fi
  if arm_red "$tw" "$res"; then t=RED; else t=GREEN; fi
  if [ "$d" = RED ]; then
    mutant_killed "$7" "$3" "MUTATION '$3' scored by its deciding arm $dec with its twin $tw GREEN: $6"
  else
    bad "MUTATION '$3' SURVIVED -- $6"
  fi
  if [ "$t" = RED ]; then bad "MUTATION '$3' tripped its twin arm $tw too -- the arms are entangled"; fi
  if [ "$MODE" = matrix ]; then # mx-all-arms
    rd=""
    for a in $arms; do
      if [ "$a" = "$dec" ] || [ "$a" = "$tw" ]; then continue; fi
      printf 'mx %s %s\n' "$3" "$a" >> "$MXL"
      tot=$((tot + 1)); if arm_red "$a" "$res"; then rd="$rd,$a"; else g=$((g + 1)); fi
    done
    if [ "$d" = GREEN ]; then u=" UNEXPECTED=$dec:GREEN"; fi
    if [ "$t" = RED ]; then u="$u UNEXPECTED=$tw:RED"; fi
    printf 'MATRIX %s decides=%s:%s twins=%s:%s others=%d/%d%s%s\n' "$3" "$dec" "$d" "$tw" "$t" "$g" "$tot" "${rd:+ red=${rd#,}}" "$u"
  fi
}

# ENV: the permission survives, its duty is cut -- the pre-fix text.
mutant check_review "$STEP" "env-no-duty" \
  '/^environmental seam MAY defer, and the lead files each deferred seam as an$/{print "environmental seam MAY defer."; skip=4; next} skip>0{skip--; next} {print}' \
  "ENV:" "cutting the carry-over duty from the environmental permission is caught" "${B_ctl_review:-0}"

mutant check_review "$STEP" "del-branch" \
  '/^\*\*Un-exercised decision branch\.\*\*/{d=1} d && /^[[:space:]]*$/{d=0; next} d{next} {print}' \
  "BRANCH:" "deleting the decision-branch paragraph is caught" "${B_ctl_review:-0}"

# MOVE: the paragraph leaves §3 and reappears verbatim at the top of §4. A whole-file
# grep still finds it; the section-keyed arm must not.
mutant check_review "$STEP" "move-branch" \
  '/^\*\*Un-exercised decision branch\.\*\*/{d=1} d{held=held $0 "\n"; if ($0 ~ /^[[:space:]]*$/) d=0; next} /^### 4\./{print; print ""; printf "%s", held; next} {print}' \
  "BRANCH:" "moving the decision-branch paragraph out of §3 (into §4) is caught" "${B_ctl_review:-0}"

mutant check_review "$STEP" "branch-no-owner" \
  '/^\*\*Un-exercised decision branch\.\*\*/{d=1} d{gsub(/`carry-over-evaluation\.md`/, "the backlog")} d && /^[[:space:]]*$/{d=0} {print}' \
  "BRANCH:" "a decision-branch paragraph that no longer names the carry-over owner is caught" "${B_ctl_review:-0}"

mutant check_review "$STEP" "no-section" \
  '/^### 3\. Fix and Re-Validate/{print "### 3. Rework"; next} {print}' \
  "SECTION:" "an unisolatable §3 is a finding, not an empty pass" "${B_ctl_review:-0}"

RCTL="$WORK/role-control.md"; cp "$ROLE" "$RCTL"
if [ -z "$(check_role "$RCTL")" ] && [ -n "$(item15 "$RCTL")" ]; then
  ok "CONTROL-role: an unmutated dev.md copy passes and item 15 is non-empty"; B_ctl_role=1
else
  bad "CONTROL-role: an unmutated dev.md copy fails -- every role mutant verdict below is uninterpretable"
fi

# A bullet runs from its `- [ ] **<label>` line to the next line opening with `- ` or at column 0.
DELB='index($0, "- [ ] **" lab){d=1; next} d && (/^[[:space:]]*- /||/^[^[:space:]]/){d=0} d{next} {print}'
mutant check_role "$ROLE" "del-edit" "BEGIN{lab=\"Edit-already-present check.\"} $DELB" \
  "EDIT:" "deleting the edit-already-present bullet is caught" "${B_ctl_role:-0}"
mutant check_role "$ROLE" "del-order" "BEGIN{lab=\"Wall-clock ordering evidence.\"} $DELB" \
  "ORDER:" "deleting the wall-clock ordering bullet is caught" "${B_ctl_role:-0}"
# MOVE: the bullet leaves item 15 and reappears verbatim under `## Communication`. A
# whole-file grep still finds it; the item-keyed arm must not.
mutant check_role "$ROLE" "move-order" \
  'BEGIN{lab="- [ ] **Wall-clock ordering evidence."} index($0, lab){d=1; held=$0 "\n"; next} d && (/^[[:space:]]*- /||/^[^[:space:]]/){d=0} d{held=held $0 "\n"; next} /^## Communication$/{print; print ""; printf "%s", held; next} {print}' \
  "ORDER:" "moving the wall-clock ordering bullet out of item 15 (into Communication) is caught" "${B_ctl_role:-0}"
mutant check_role "$ROLE" "no-item15" \
  '/^15\. /{sub(/^15\. /, "15) ")} {print}' \
  "ITEM15:" "an unisolatable item 15 is a finding, not an empty pass" "${B_ctl_role:-0}"

# RULE 9: a plain run executes NO matrix-only cell. The deciding and twin cells write the same ledger, so
# an empty matrix count cannot come from a ledger nothing writes.
mx_only="$(mx_count mx)"; mx_ctl="$(mx_count dec)"
if [ "$MODE" = plain ]; then
  if [ "$mx_ctl" -eq 0 ]; then bad "rule-9: the matrix ledger control is EMPTY, so a zero count of matrix-only cells means nothing"
  elif [ "$mx_only" -ne 0 ]; then bad "rule-9: a plain run executed $mx_only matrix-only cell(s) -- the --matrix measurement leaked into the per-push run"
  else ok "rule-9: a plain run executed no matrix-only cell, while $mx_ctl deciding or twin cell(s) wrote the same ledger"; fi
else
  echo "MATRIX-SUMMARY $mx_only matrix-only cell(s) ran"
fi

echo
if [ "$rc" -eq 0 ]; then
  echo "review-carry-over-clauses: PASS"
else
  echo "review-carry-over-clauses: FAILED" >&2
fi
exit $rc
