#!/usr/bin/env bash
# gate-verdict-grep-shape — the mandated verdict grep must match the mandated review template.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# `gate-validation.md` Check 1 forbids the lead from asserting a gate verdict and names a
# grep to source it from the review file instead. `code-reviewer.md` defines the template
# that writes those files. Nothing joined the two, and they disagreed about shape: the grep
# required `Verdict:` at column 0 while the template emits `## Verdict` with the value on
# the next line. Measured on the reference consumer: 14 of 1011 real review files matched.
#
# The lead therefore ran the mandated command, got nothing, and had no specified fallback —
# landing back on the recollection the paragraph exists to forbid. A grep that matches
# nothing reads exactly like a verdict that is absent.
#
# Both halves are load-bearing. A pattern that misses the template silently un-gates every
# review; a pattern loose enough to hit any prose mention of the word "verdict" sources the
# gate answer from a sentence. This fixture derives the pattern from the rule file and the
# heading from the role file, so a future edit to either that breaks the join fails here
# rather than on a consumer's gate months later.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

find_one() { # find_one <core-relative-path>
  local rel="$1"
  if [ -n "$ROOT" ] && [ -f "$ROOT/core/$rel" ]; then printf '%s' "$ROOT/core/$rel"
  elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/$rel" ]; then printf '%s' "$ROOT/.claude/$rel"
  fi
}

GATE="$(find_one skills/ai-dlc/steps/gate-validation.md)"
ROLE="$(find_one team-roles/code-reviewer.md)"
[ -n "$GATE" ] || { echo "FIXTURE ERROR: gate-validation.md not found in either layout" >&2; exit 2; }
[ -n "$ROLE" ] || { echo "FIXTURE ERROR: code-reviewer.md not found in either layout" >&2; exit 2; }

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }

# --- Derive, never hardcode -------------------------------------------------
# The pattern is read out of the rule file's own `grep -inE '<pattern>'` directive. A
# hardcoded copy here would be a second definition, and the two would drift exactly as the
# grep and the template did.
PAT="$(sed -n "s/.*grep -inE '\(.*\)' <review-file>.*/\1/p" "$GATE" | head -1)"
[ -n "$PAT" ] || {
  echo "FIXTURE STALE: no \`grep -inE '<pattern>' <review-file>\` directive in gate-validation.md" >&2
  exit 2
}

# The heading is read out of the role file's review-document template.
HEADING="$(sed -n '/^## Review Document Template/,/^```$/p' "$ROLE" \
           | grep -iE '^#+[[:space:]]*verdict' | head -1)"
[ -n "$HEADING" ] || {
  echo "FIXTURE STALE: no verdict heading in code-reviewer.md's Review Document Template" >&2
  exit 2
}

matches() { grep -qiE "$1" <<<"$2"; }

# A SECOND SUBJECT IN THE SAME ROLE FILE, HOSTED HERE BECAUSE THIS FIXTURE ALREADY RESOLVES IT.
#
# `### Missing Pre-Deploy Field Verification` classifies a PRODUCER-side condition — a change
# that adds a field to an API query — and for the whole life of the rule it was the only one in
# its contiguous severity run carrying no `**Evidence required:**` clause. A reviewer who made
# the observation was told nothing about what to record, so the classification was
# unfalsifiable. Absent in 21 of 21 revisions in which the rule existed, through a prose sweep
# that deleted from this file's Mandatory Severity section without noticing the gap beside it.
#
# WHAT IS DELIBERATELY NOT ASSERTED. The same fix added a query-shape step to the procedure at
# `## Field Verification`, and NO arm here covers it. An arm was built and measured: keyed on
# the word "query" plus a closed list of send verbs, 3 of 5 legitimate rewordings that fully
# preserved the instruction came back red — the wording "request shape", "transmits" and
# "introduces" all defeat it. Widening the alternation is guessing the synonym space, which
# leaves a false-positive set that is an open class of legitimate English: neither empty nor
# enumerable, so it fails CLAUDE.md's precondition. That half is UNGUARDED and this fixture's
# green line must not be read as covering it.
#
# `**Evidence required:**` is different in kind — a literal structural convention the file uses
# verbatim at 5 sites, not a phrase chosen to match prose. It survived all 5 rewordings.
RULE_SEC() { LC_ALL=C awk '/^### Missing Pre-Deploy Field Verification/{g=1;next} g&&/^### /{exit} g' "$1"; }

[ -n "$(RULE_SEC "$ROLE")" ] || {
  echo "FIXTURE STALE: no \`### Missing Pre-Deploy Field Verification\` rule in code-reviewer.md." >&2
  echo "  Either the heading moved — re-point RULE_SEC — or the rule was RETIRED, in which case" >&2
  echo "  this assertion retires with it. A fixture that lost its subject is not a tree defect," >&2
  echo "  and the two must not print the same verdict." >&2
  exit 2
}

# --- Assertion 1: THE JOIN --------------------------------------------------
# The whole point. The pattern the gate mandates must match the heading the template emits.
if matches "$PAT" "$HEADING"; then
  ok "the mandated grep matches the mandated template heading ($HEADING)"
else
  bad "the mandated grep does NOT match '$HEADING' — the gate cannot read the verdict of any review file the template produces, and a zero-match reads as an absent verdict"
fi

# --- Assertion 2: the shapes real review files actually use ------------------
# Sampled from the reference consumer's corpus. Each was a live miss under the old pattern.
while IFS='|' read -r label line; do
  if matches "$PAT" "$line"; then
    ok "matches $label"
  else
    bad "does NOT match $label — a real review-file shape the gate cannot read: $line"
  fi
done <<'SHAPES'
bare heading|## Verdict
inline heading|## Verdict: APPROVED
uppercase inline|## VERDICT: APPROVED
qualified heading|## Overall Verdict
qa-qualified heading|## QA Verdict
bold field|**Verdict:** REJECT
bold list item|- **Verdict:** APPROVED
column-zero field|Verdict:
trailing whitespace|## Verdict
deeper heading|### Verdict: PASS
SHAPES

# --- Assertion 3: precision — prose must NOT source a gate answer ------------
# A pattern loose enough to match a sentence turns narrative into a verdict. These are real
# lines from the consumer's corpus that must stay unmatched.
while IFS='|' read -r label line; do
  if matches "$PAT" "$line"; then
    bad "WRONGLY matches $label — the gate would source its answer from prose: $line"
  else
    ok "ignores $label"
  fi
done <<'PROSE'
mid-sentence mention|nor gate-2's QA verdict cites the map
trailing-clause mention|that would not have changed my verdict — DEPLOY_SAFE
unrelated heading|## Test Coverage Assessment
table header|RESPONSE field? | Verdict |
prose with decision|the decision to defer for one sprint was recorded
PROSE

# --- Assertion 5: the second half of the fix ---------------------------------
# Widening the pattern alone leaves the hole open: an unmatched file still falls back to
# recollection, just less often. The rule must make a zero-match terminal.
if grep -qiE 'zero matches? +fails? this check' "$GATE"; then
  ok "a zero-match is declared a FAIL, not a fallback"
else
  bad "gate-validation.md no longer declares zero matches a FAIL — a review file the pattern misses silently returns to the lead's recollection, which is the defect the check exists to prevent"
fi

# --- Assertion 6: the producer-side severity rule states its evidence --------
if grep -qF '**Evidence required:**' <<<"$(RULE_SEC "$ROLE")"; then
  ok "the Missing Pre-Deploy Field Verification rule carries an \`**Evidence required:**\` clause"
else
  bad "\`### Missing Pre-Deploy Field Verification\` carries no \`**Evidence required:**\` clause — every other rule in its contiguous severity run does. Without one a reviewer who observes the trigger is told nothing about what to record, and the classification cannot be checked by anyone downstream"
fi

# --- CHECK 5's COMPARAND IS A FIELD CHECK 12 WRITES, AND THE SPANS ARE BOUNDED -------
#
# A SECOND SUBJECT IN THE SAME RULE FILE, HOSTED HERE BECAUSE THIS FIXTURE ALREADY
# RESOLVES `gate-validation.md` IN BOTH LAYOUTS. Building a directory for it would add a
# fixture whose whole read set is a file this one already reads.
#
# THE DEFECT THIS EXISTS TO CATCH. Check 5 compared a story file's `status:` against its
# `sprint-status.yaml` entry, and the declared repair for a disagreement REGENERATES that
# entry from the story file. The two comparands are a record and a derivation of that
# record, so a status wrong at the source is copied into every canonical copy and the
# check passes. The repair is a third comparand — a field the PREVIOUS gate-log entry
# recorded — and it is only reachable if some gate WRITES that field, which makes the edit
# two spans rather than one.
#
# AND THE RECEIPT THAT WAS SUPPOSED TO PIN IT CANNOT. Measured against the pre-fix file,
# each seed asserted to have applied by comparing bytes in the same run: the backlog
# entry's `grep -q 'gate-log\.md'` over the awk-extracted Check 5 span returned 0 — a
# CLOSE — for an inserted `<!-- see also gate-log.md -->`, for a bare prose sentence
# naming the file, AND for a deleted `CHECK_LOADED: 6` anchor, which runs the awk range to
# end-of-file and lets Check 12's own write site, later in the file, satisfy the grep.
# Three ways to close a receipt while shipping nothing, so the pin has to be here.
#
# WHAT THE ARMS KEY ON, AND WHY IT IS NOT A SPELLING. `story_status` appears in none of
# them. The predicate is a JOIN between the two spans: some field token read on a
# NON-COMMENT line of Check 5, inside a top-level bullet region that states a gate-failure
# condition on a non-comment line, and written as a schema bullet in Check 12. That is the
# `steering_violations:` shape this file already uses — a field Check 12 writes because a
# later check reads it — and keying on the shape rather than the name means a rename that
# keeps the join intact stays green.
#
# THE BOUNDS RUN BEFORE THE JOIN AND REFUSE IT. A span whose closing anchor is gone runs
# to EOF, and every join question then has the whole file to answer from. The ceilings
# (CEIL below) sit well above the live span lengths, which the GREEN verdict prints as
# `s5=` and `s12=`, and far below a span run to end of file, so ordinary growth does not
# trip them, and a blown bound reports MEASURED NOTHING — a third verdict that is neither
# the pass nor the finding, because a span that was never delimited has not been read.
GV_WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$GV_WORK"' EXIT

# The join oracle. One program, three verdicts: GREEN (the join holds), RED (it does not),
# BLOWN (a span was not delimited, so nothing was measured).
cat > "$GV_WORK/join.py" <<'GVJOINPY'
import re
import sys

ANCHOR = "<!-- CHECK_LOADED: %d -->"
CEIL = {5: 240, 12: 320}
FAIL_RE = re.compile(r"gate\s+fails", re.I)
FIELD_RE = re.compile(r"`([a-z][a-z0-9_]*):")
SCHEMA_RE = re.compile(r"^- `([a-z][a-z0-9_]*):", re.M)


def anchor_at(lines, n):
    want = ANCHOR % n
    for i, ln in enumerate(lines):
        if ln.strip() == want:
            return i
    return None


def span(lines, a, b):
    i = anchor_at(lines, a)
    if i is None:
        return None
    j = anchor_at(lines, b)
    return (i, len(lines), False) if j is None else (i, j, True)


def noncomment(ln):
    return not ln.lstrip().startswith("<!--")


def opens_region(ln):
    """A top-level bullet opens a region; any other column-0 line ENDS the one above it.

    The walk without that second clause is wrong in the direction that reads as a pass.
    Measured while building this arm: a bare prose sentence dropped at column 0 after a
    bullet was absorbed INTO that bullet's region and inherited its failure condition, so
    a seed that replaced the comparand with a sentence scored GREEN. A column-0 line that
    is not a bullet is not part of the bullet above it.
    """
    return ln.startswith("- ")


def region_of(block, idx):
    # A line that is itself at column 0 and is not a bullet BELONGS TO NOTHING, and
    # walking back from it into the bullet above is the error that made a bare prose
    # sentence inherit that bullet's failure condition.
    if block[idx] and not block[idx][0].isspace() and not opens_region(block[idx]):
        return idx, idx + 1
    st = idx
    while st > 0 and not opens_region(block[st]):
        if block[st] and not block[st][0].isspace():
            return idx, idx + 1
        st -= 1
    if not opens_region(block[st]):
        return idx, idx + 1
    en = st + 1
    while en < len(block) and not opens_region(block[en]):
        if block[en] and not block[en][0].isspace():
            break
        en += 1
    return st, en


def bounds(lines):
    notes = []
    for a, b in ((5, 6), (12, 13)):
        sp = span(lines, a, b)
        if sp is None:
            return "BLOWN", "Check %d carries no CHECK_LOADED anchor at all" % a
        st, en, closed = sp
        n = en - st
        if not closed:
            return "BLOWN", (
                "Check %d has no closing CHECK_LOADED: %d anchor, so its span runs to "
                "EOF at %d lines and every question below would be answered from the "
                "whole file" % (a, b, n)
            )
        if n > CEIL[a]:
            return "BLOWN", (
                "Check %d's span is %d lines, past the %d ceiling" % (a, n, CEIL[a])
            )
        notes.append("s%d=%d" % (a, n))
    return "OK", " ".join(notes)


def join(lines):
    v, why = bounds(lines)
    if v != "OK":
        return "BLOWN", why
    i5, e5, _ = span(lines, 5, 6)
    i12, e12, _ = span(lines, 12, 13)
    b5 = lines[i5:e5]
    write = set(SCHEMA_RE.findall("\n".join(lines[i12:e12])))
    for idx, ln in enumerate(b5):
        if not noncomment(ln):
            continue
        for fld in FIELD_RE.findall(ln):
            if fld not in write:
                continue
            st, en = region_of(b5, idx)
            if any(FAIL_RE.search(r) and noncomment(r) for r in b5[st:en]):
                return "GREEN", (
                    "'%s' is read on non-comment Check-5 line %d, its bullet region "
                    "[%d..%d] states a gate-failure condition on a non-comment line, "
                    "and Check 12's schema writes it (%s)"
                    % (fld, idx + 1, st + 1, en, why)
                )
    return "RED", (
        "no field is BOTH read under a stated failure condition in Check 5 AND written "
        "as a Check 12 schema field; Check 12 writes: %s (%s)"
        % (", ".join(sorted(write)) or "nothing", why)
    )


lines = open(sys.argv[1], encoding="utf-8").read().split("\n")
mode = sys.argv[2]
v, why = join(lines) if mode == "join" else bounds(lines)
print("%s %s" % (v, why))
GVJOINPY

gv_join() { python3 "$GV_WORK/join.py" "$1" join; }

# --- Assertion 8: the spans are bounded, and the join holds on the live file ----
GV_BOUNDS="$(python3 "$GV_WORK/join.py" "$GATE" bounds)"
case "$GV_BOUNDS" in
  OK*) ok "the Check 5 and Check 12 spans are both delimited and within bounds (${GV_BOUNDS#OK })" ;;
  *)   bad "the spans are not measurable, so nothing below is measuring anything: $GV_BOUNDS" ;;
esac
GV_LIVE="$(gv_join "$GATE")"
case "$GV_LIVE" in
  GREEN*) ok "Check 5's comparand is a field Check 12's schema writes — ${GV_LIVE#GREEN }" ;;
  *) bad "Check 5 states no comparand that Check 12 writes: ${GV_LIVE}. Its two remaining comparands are a record and a derivation of that record — the repair for a disagreement regenerates the second FROM the first — so a status wrong at the source agrees with itself and the check passes" ;;
esac


echo
report_end gate-verdict-grep-shape
