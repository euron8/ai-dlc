#!/usr/bin/env bash
# validate-escalation-status-vocabulary.sh — an escalation's Status token must be in the
# closed set escalations.md publishes. Anything else fails closed.
#
# WHY THIS EXISTS
# gate-validation.md Check 2 is three branches with no else. It blocks on HARD_BLOCK,
# passes over DECIDED_AUTONOMOUSLY as informational, and scopes DEFERRAL_REQUEST to the
# deferred item. An entry whose status is none of those satisfies no branch: Check 2 does
# not block on it, does not surface it, and does not record it. It is silently skipped.
#
# The failure is not a wrong verdict — it is an entry no verdict was ever computed for, and
# the gate reports Check 2 as passing either way. That is the check-that-cannot-fire class:
# a PASS byte-identical to never having examined anything.
#
# Measured on the reference consumer: docs/escalations/pending.md carried 8 entries on
# tokens core never defined (FILED x5, OPEN x3), accumulated across the sprints they were
# written in, and every gate in that window reported Check 2 passing.
#
# WHY IT DERIVES THE SET INSTEAD OF LISTING IT
# A hand-listed copy of a published set is the defect this repo keeps finding (the
# Invariant-3 `uni` array, apply.sh's private consumer_path table). So the vocabulary is
# read from escalations.md itself, from the two lines that publish it:
#
#   1. the `**Status:**` line inside the entry-format code block  — authorship tokens
#   2. the `**Terminal statuses**` line beneath it                — resolution tokens
#
# Every token lives in exactly one of them. Adding a token to the pipeline means editing
# escalations.md, which is the correct place for it to be a visible decision.
#
# If escalations.md cannot be found or neither line parses, this script REFUSES (exit 2)
# rather than falling back to a built-in set. A validator that guesses its own vocabulary
# when it cannot read the source has reintroduced the hand-listed copy, silently.
#
# SCOPE. Every `**Status:**` entry in the file, regardless of sprint. Deliberately wider
# than validate-escalation-resolution.sh, which scopes to the current sprint because it
# verifies citations against THIS session's transcript. A malformed token is malformed
# whenever it was written, and the drift this catches accumulates precisely in the entries
# old enough that nobody re-reads them.
#
# ORTHOGONAL TO Check 2a. validate-escalation-resolution.sh asserts that a
# RESOLVED/OVERRIDDEN HARD_BLOCK cites a verified operator message. It parses the status
# token only to SELECT entries and never validates it against the published set. This is
# the second, cheaper arm beside it.
#
# USAGE
#   validate-escalation-status-vocabulary.sh <pending.md> [escalations.md]
#
# EXIT
#   0  every Status token is in the derived vocabulary (or no escalations file exists)
#   1  at least one entry carries an out-of-vocabulary Status token
#   2  bad arguments, or the vocabulary source could not be read — see above, this is a
#      refusal, not a pass
set -u

ESCALATIONS="${1:-}"
if [ -z "$ESCALATIONS" ]; then
  echo "FAIL: usage: validate-escalation-status-vocabulary.sh <pending.md> [escalations.md]" >&2
  exit 2
fi

# ---- 1. Locate the vocabulary source ---------------------------------------
ES_SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ES_ROOT="${CLAUDE_PROJECT_DIR:-$(pwd)}"
SPEC="${2:-${AI_DLC_ESCALATIONS_MD:-}}"
if [ -z "$SPEC" ]; then
  for cand in \
      "$ES_ROOT/core/skills/ai-dlc/escalations.md" \
      "$ES_ROOT/.claude/skills/ai-dlc/escalations.md" \
      "$ES_SCRIPT_DIR/../skills/ai-dlc/escalations.md"; do
    [ -f "$cand" ] && { SPEC="$cand"; break; }
  done
fi
if [ -z "$SPEC" ] || [ ! -f "$SPEC" ]; then
  echo "FAIL: escalations.md not found. The status vocabulary is DERIVED from it; this" >&2
  echo "      validator has no built-in set and will not guess. Reinstall ai-dlc." >&2
  exit 2
fi

# ---- 2. Derive the closed set ----------------------------------------------
# Both source lines carry their tokens as a `|`-separated run of ALL-CAPS words. Take the
# text after the label, strip backticks, and keep every [A-Z_] word.
VOCAB="$(awk '
  /^\*\*Status:\*\*/ || /^\*\*Terminal statuses\*\*/ {
    s = $0
    sub(/^[^:]*:[[:space:]]*/, "", s)
    gsub(/`/, "", s)
    n = split(s, parts, /[|]/)
    for (i = 1; i <= n; i++) {
      t = parts[i]
      gsub(/[^A-Z_]/, "", t)
      if (t != "") print t
    }
  }
' "$SPEC" | sort -u)"

# Two lines, so fewer than two distinct tokens means a parse failure, not a small
# vocabulary. Refuse rather than validate against a set that lost most of itself.
if [ "$(printf '%s\n' "$VOCAB" | grep -c .)" -lt 2 ]; then
  echo "FAIL: could not derive the status vocabulary from $SPEC." >&2
  echo "      Expected a '**Status:**' line and a '**Terminal statuses**' line; got:" >&2
  printf '        %s\n' ${VOCAB:-"(nothing)"} >&2
  echo "      Refusing to validate against a set this script did not read." >&2
  exit 2
fi

# No escalations file is a legitimate clean state — nothing to adjudicate.
[ -f "$ESCALATIONS" ] || {
  echo "OK: no escalations file ($ESCALATIONS); nothing to check."
  exit 0
}

# ---- 3. Extract one <header>\t<STATUS> record per entry ---------------------
# Same flush-on-header / first-ALL-CAPS-word-after-label idiom as
# validate-escalation-resolution.sh:82-100. The Status field is matched anywhere in the
# entry, not only at line start: a token in a non-canonical position is exactly the one a
# naive line-anchored regex misses, and it is no less invisible to Check 2 for being there.
RECORDS="$(awk '
  function flush() {
    if (header != "" && status != "") printf "%s\t%s\n", header, status
  }
  /^#{2,3} / { flush(); header = $0; status = ""; next }
  /\*\*[Ss]tatus:\*\*/ {
    if (status != "") next            # first Status line in an entry wins
    s = $0
    sub(/^.*\*\*[Ss]tatus:\*\*[[:space:]]*/, "", s)
    if (match(s, /[A-Z_]+/)) status = substr(s, RSTART, RLENGTH)
    next
  }
  END { flush() }
' "$ESCALATIONS")"

if [ -z "$RECORDS" ]; then
  echo "OK: n=[] no **Status:** entries found in $ESCALATIONS."
  exit 0
fi

# ---- 4. Compare ------------------------------------------------------------
bad=0
n=0
while IFS="$(printf '\t')" read -r header status; do
  [ -n "${status:-}" ] || continue
  n=$((n + 1))
  if ! printf '%s\n' "$VOCAB" | grep -qx "$status"; then
    bad=$((bad + 1))
    echo "FAIL: out-of-vocabulary status '$status'" >&2
    echo "      entry: $header" >&2
    echo "      Check 2 branches on the published set and has no else, so this entry is" >&2
    echo "      neither blocked, surfaced nor recorded — no verdict is computed for it." >&2
  fi
done <<EOF
$RECORDS
EOF

if [ "$bad" -gt 0 ]; then
  echo "FAIL: $bad of $n escalation entries carry a status outside the closed set." >&2
  echo "      Vocabulary derived from $SPEC: $(printf '%s ' $VOCAB)" >&2
  echo "      Either correct the entry, or add the token to escalations.md and teach" >&2
  echo "      Check 2 how to branch on it. A token Check 2 cannot branch on is a silent skip." >&2
  exit 1
fi

echo "OK: n=$n all escalation status tokens are in the derived set ($(printf '%s ' $VOCAB))."
exit 0
