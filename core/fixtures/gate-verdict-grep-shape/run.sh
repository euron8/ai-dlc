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

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

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

# --- Assertion 4: MUTANT — the fixture must fail on the historical defect ----
# The pattern that shipped, verbatim. If this fixture cannot tell it from the current one,
# it proves nothing: a green run would mean only that the assertions cannot fire.
OLD='^(Verdict|Decision):'
if matches "$OLD" "$HEADING"; then
  bad "MUTANT NOT DETECTED: the historical pattern '$OLD' matches '$HEADING', so assertion 1 cannot distinguish the defect from the fix"
else
  ok "the historical pattern '$OLD' fails on the template heading (assertion 1 can fire)"
fi

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
  a6=present
else
  bad "\`### Missing Pre-Deploy Field Verification\` carries no \`**Evidence required:**\` clause — every other rule in its contiguous severity run does. Without one a reviewer who observes the trigger is told nothing about what to record, and the classification cannot be checked by anyone downstream"
  a6=absent
fi

# --- Assertion 7: MUTANT — assertion 6 must fail on the historical defect ----
# ASSERTION 6 OWNS THE ABSENT CASE and this arm stands down for it. A mutation that deletes a
# clause already missing changes no bytes, and reporting that as a broken mutant on top of the
# real finding prints two failures for one defect — which is how a battery starts looking
# entangled. Measured against the true pre-fix file at 941021d^, where both fired.
if [ "$a6" = absent ]; then
  ok "MUTANT stands down — assertion 6 already reports the clause absent, and it owns that case"
else
  # A COPY, never an in-place edit, guarded by `cmp -s` so a sed that matched nothing cannot
  # pass as a mutation. The clause is deleted as a range because it spans two lines; keying the
  # range end on `in the review doc.` is safe only because the search runs FORWARD from the
  # start line — an identical tail sits earlier in the file, at Evidence/Assertion Separation.
  MUT="$(mktemp)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
  trap 'rm -f "$MUT"' EXIT
  cp "$ROLE" "$MUT"
  LC_ALL=C sed -i.bak '/^\*\*Evidence required:\*\* Include the query diff, the added field names, and$/,/^the deployed-schema source consulted, in the review doc\.$/d' "$MUT"
  rm -f "$MUT.bak"
  if cmp -s "$ROLE" "$MUT"; then
    bad "MUTANT changed no bytes — its sed matched nothing, so an unmutated copy would score as a kill and assertion 6 would be proving nothing"
  elif grep -qF '**Evidence required:**' <<<"$(RULE_SEC "$MUT")"; then
    bad "MUTANT NOT DETECTED: with the clause deleted, assertion 6 still reads it as present — the extraction is picking up an \`**Evidence required:**\` from a neighbouring rule, so a green assertion 6 means nothing"
  else
    ok "with the clause deleted from a copy, assertion 6 goes red (it can fire)"
  fi
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
# end-of-file and lets Check 12's own write site satisfy the grep from 1800 lines away.
#
# THE ENTRY'S RECEIPT NOW CARRIES A SPAN-LENGTH BOUND, AND IT COVERS EXACTLY ONE OF THOSE.
# Scored here against the seeds below, each `cmp -s`-asserted to have applied, with the
# tip as the positive control at rc=0:
#
#   tip                           rc=0   closes, correctly
#   comment                       rc=0   FALSE CLOSE  <- an arm below owns it
#   bare-mention                  rc=0   FALSE CLOSE  <- an arm below owns it
#   read-commented                rc=0   FALSE CLOSE  <- an arm below owns it
#   no-fail-condition             rc=0   FALSE CLOSE  <- an arm below owns it
#   no-write                      rc=0   FALSE CLOSE  <- an arm below owns it
#   no-read                       rc=1   the one text shape the receipt does see
#   no-anchor6                    rc=2   THE BOUND FIRING — refuses, does not close
#   no-anchor13                   rc=0   FALSE CLOSE  <- the bound cannot see it
#
# The bound is REAL and it is not re-invented here: `no-anchor6` is the case it was added
# for, and it now exits 2 rather than closing. What it cannot reach is everything else.
# A Check 13 anchor deletion leaves the Check 5 awk range at 106 lines — well under the
# 200 the receipt tests — while running Check 12's span to EOF, so the WRITE side of the
# join would be answered from the rest of the file and the receipt reads a clean close.
# A bound on one span is structurally blind to the other span's anchor, which is why arm
# A10 below bounds BOTH and why the five text shapes are pinned here rather than there.
#
# WHAT THE ARMS KEY ON, AND WHY IT IS NOT A SPELLING. `story_status` appears in none of
# them. The predicate is a JOIN between the two spans: some field token read on a
# NON-COMMENT line of Check 5, inside a top-level bullet region that states a gate-failure
# condition on a non-comment line, and written as a schema bullet in Check 12. That is the
# `steering_violations:` shape this file already uses — a field Check 12 writes because a
# later check reads it — and keying on the shape rather than the name means a rename that
# keeps the join intact stays green, which arm A12 asserts directly.
#
# THE BOUNDS RUN BEFORE THE JOIN AND REFUSE IT. A span whose closing anchor is gone runs
# to EOF, and every join question then has the whole file to answer from. Measured at this
# tip: Check 5 is 105 lines and Check 12 is 150; with their closers deleted they are 2456
# and 2233. The ceilings sit at roughly twice the live lengths, so ordinary growth does not
# trip them, and a blown bound reports MEASURED NOTHING — a third verdict that is neither
# the pass nor the finding, because a span that was never delimited has not been read.
# BOTH spans are bounded deliberately: bounding only Check 5 is the receipt's own gap, and
# a Check 13 deletion leaves Check 5 at its normal length while emptying the join's other
# side.
GV_WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$GV_WORK"; rm -f "${MUT:-}" "${MUT:-}.bak"' EXIT

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

# The seed builder. Every seed is located by the SAME derivation the oracle uses -- the
# joined field, its bullet region, the anchors -- so none of them is keyed on a spelling,
# and a rename moves every seed with the file.
cat > "$GV_WORK/seed.py" <<'GVSEEDPY'
import re
import sys

src, dst, mode = sys.argv[1], sys.argv[2], sys.argv[3]
L = open(src, encoding="utf-8").read().split("\n")
SCHEMA_RE = re.compile(r"^- `([a-z][a-z0-9_]*):", re.M)
FIELD_RE = re.compile(r"`([a-z][a-z0-9_]*):")


def at(n):
    w = "<!-- CHECK_LOADED: %d -->" % n
    for i, ln in enumerate(L):
        if ln.strip() == w:
            return i
    raise SystemExit("FIXTURE STALE: no CHECK_LOADED: %d anchor" % n)


i5, i6, i12, i13 = at(5), at(6), at(12), at(13)
write = set(SCHEMA_RE.findall("\n".join(L[i12:i13])))


def joined_field():
    for j in range(i5, i6):
        if L[j].lstrip().startswith("<!--"):
            continue
        for f in FIELD_RE.findall(L[j]):
            if f in write:
                return f, j
    raise SystemExit("FIXTURE STALE: no joined field in the Check 5 span")


def region(j):
    # The SAME walk the oracle uses, including the clause that stops at a column-0
    # non-bullet line. A seed built with a different region than the one the oracle reads
    # deletes a span nobody was scoring.
    if L[j] and not L[j][0].isspace() and not L[j].startswith("- "):
        return j, j + 1
    st = j
    while st > i5 and not L[st].startswith("- "):
        if L[st] and not L[st][0].isspace():
            return j, j + 1
        st -= 1
    if not L[st].startswith("- "):
        return j, j + 1
    en = st + 1
    while en < i6 and not L[en].startswith("- "):
        if L[en] and not L[en][0].isspace():
            break
        en += 1
    return st, en


out = None
if mode == "comment":
    # THE FALSE CLOSE THE RECEIPT MEASURED, AND IT IS A REPLACEMENT RATHER THAN AN
    # INSERTION. Adding a comment BESIDE a correct comparand leaves the comparand
    # correct, so the arm rightly stays green and the seed tests nothing. The state the
    # receipt could not tell from the fix is the one where the comment is ALL there is:
    # the reader's bullet region is gone and an HTML comment naming the file, the field
    # and the failure sits in its place. The receipt's grep closes on it; nobody is
    # instructed by it.
    f, j = joined_field()
    st, en = region(j)
    out = L[:st] + [
        "<!-- see also gate-log.md, `%s:` and Gate FAILS -->" % f
    ] + L[en:]
elif mode == "bare-mention":
    # The other measured false close, replacing the comparand for the same reason: a
    # prose sentence naming the file and the field, stating no condition.
    f, j = joined_field()
    st, en = region(j)
    out = L[:st] + [
        "The gate log records `%s:` for each story of the sprint, at "
        "`_bmad-output/implementation-artifacts/gate-log.md`." % f
    ] + L[en:]
elif mode == "read-commented":
    # Both halves survive; the READ is demoted to a comment. This is the seed that
    # separates "the token is in the span" from "an executor is instructed".
    f, _ = joined_field()
    out = list(L)
    for j in range(i5, i6):
        if ("`%s:" % f) in out[j] and not out[j].lstrip().startswith("<!--"):
            out[j] = "<!-- " + out[j].strip() + " -->"
elif mode == "no-fail-condition":
    # Both halves survive and the read is prose; nothing FAILS the gate. A comparand
    # nobody is told to act on is the unreachable-criterion shape.
    out = list(L)
    for j in range(i5, i6):
        if re.search(r"gate\s+fails", out[j], re.I):
            out[j] = re.sub(r"[Gg]ate FAILS", "the lead is warned", out[j])
elif mode == "no-read":
    # Delete the reader half: the comparand's whole bullet region in Check 5.
    _, j = joined_field()
    st, en = region(j)
    out = L[:st] + L[en:]
elif mode == "no-write":
    # Delete the writer half: the schema bullet in Check 12. The read then consults a
    # field no gate writes, which is the unreachable criterion the fix exists to avoid.
    f, _ = joined_field()
    st = None
    for j in range(i12, i13):
        if re.match(r"^- `%s:" % re.escape(f), L[j]):
            st = j
            break
    if st is None:
        raise SystemExit("FIXTURE STALE: no Check 12 schema bullet for '%s'" % f)
    en = st + 1
    while en < i13 and not L[en].startswith("- "):
        en += 1
    out = L[:st] + L[en:]
elif mode == "no-anchor6":
    out = [ln for j, ln in enumerate(L) if j != i6]
elif mode == "no-anchor13":
    out = [ln for j, ln in enumerate(L) if j != i13]
elif mode == "nm-unrelated":
    # NEAR MISS. A non-comment line added to Check 5 that says nothing about any field.
    out = L[:i5 + 1] + ["Record the operator who ran this gate."] + L[i5 + 1:]
elif mode == "nm-rename":
    # NEAR MISS, and the one that proves the arms are not keyed on a spelling: the field
    # is renamed on BOTH sides. The join is intact, so this must stay GREEN.
    f, _ = joined_field()
    out = [ln.replace("`%s:" % f, "`%s_renamed:" % f) for ln in L]
    out = [ln.replace("%s comparand" % f, "%s_renamed comparand" % f) for ln in out]
else:
    raise SystemExit("FIXTURE ERROR: unknown seed mode %s" % mode)

open(dst, "w", encoding="utf-8").write("\n".join(out))
GVSEEDPY

gv_join() { python3 "$GV_WORK/join.py" "$1" join; }

# --- Assertion 8: THE POSITIVE CONTROL, and it runs first -------------------
# Every arm below reads a verdict off a seeded copy. If the oracle cannot return GREEN on
# the real file, every RED beside it is a broken program rather than a finding.
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

# --- Assertion 9: the MUTANTS, each asserted to have applied ----------------
# Six seeds, each built as a COPY and compared against the original in the same run, so a
# builder that matched nothing cannot score as a kill. The first two are the measured
# false closes; the middle two are the near-miss shapes a looser predicate would admit;
# the last two delete one half of the join each.
while IFS='|' read -r gvm gvwant gvwhy; do
  [ -n "$gvm" ] || continue
  python3 "$GV_WORK/seed.py" "$GATE" "$GV_WORK/$gvm.md" "$gvm" || {
    bad "SEED $gvm did not build — the arm below scores nothing"
    continue
  }
  if cmp -s "$GATE" "$GV_WORK/$gvm.md"; then
    bad "SEED $gvm changed no bytes, so an unmutated copy would score as a kill and the arm proves nothing"
    continue
  fi
  gvgot="$(gv_join "$GV_WORK/$gvm.md")"
  case "$gvgot" in
    "$gvwant"*) ok "MUTANT $gvm reads $gvwant — $gvwhy" ;;
    *) bad "MUTANT $gvm reads '${gvgot%% *}', expected $gvwant — $gvwhy. The arm cannot tell this from the shipped file, so a green run over it means nothing: $gvgot" ;;
  esac
done <<'GVMUTANTS'
comment|RED|an HTML comment naming the file, the field and the failure closes the entry's grep and instructs nobody
bare-mention|RED|a prose sentence naming the field states no condition an executor can act on
read-commented|RED|both halves present, the READ demoted to a comment — the token is in the span and no executor is instructed
no-fail-condition|RED|both halves present, prose, and nothing FAILS the gate — a comparand with no verdict attached
no-read|RED|the reader half deleted: Check 12 writes a field Check 5 never consults
no-write|RED|the writer half deleted: Check 5 reads a field no gate ever writes, which is an unreachable criterion
GVMUTANTS

# --- Assertion 10: THE SPAN BOUNDS, and a blown bound is not a pass ---------
# A deleted closing anchor runs the span to EOF. BOTH spans are bounded, because a Check
# 13 anchor deletion is invisible to a Check 5 bound: the join's WRITE side would then be
# answered from the rest of the file, and Check 5's own prose names the field.
while IFS='|' read -r gvm gvwhy; do
  [ -n "$gvm" ] || continue
  python3 "$GV_WORK/seed.py" "$GATE" "$GV_WORK/$gvm.md" "$gvm" || {
    bad "SEED $gvm did not build — the bound below scores nothing"
    continue
  }
  if cmp -s "$GATE" "$GV_WORK/$gvm.md"; then
    bad "SEED $gvm changed no bytes — the anchor it deletes was already gone, so the bound proves nothing"
    continue
  fi
  gvgot="$(gv_join "$GV_WORK/$gvm.md")"
  case "$gvgot" in
    BLOWN*) ok "MUTANT $gvm reports MEASURED NOTHING — $gvwhy" ;;
    GREEN*) bad "MUTANT $gvm reads GREEN — $gvwhy. An undelimited span answers from the whole file, and that reads exactly like a check that passed: $gvgot" ;;
    *) bad "MUTANT $gvm reads '${gvgot%% *}', expected BLOWN — $gvwhy: $gvgot" ;;
  esac
done <<'GVBOUNDS'
no-anchor6|Check 5's span would run to EOF and Check 12's own write site would satisfy it from 1800 lines away
no-anchor13|Check 12's span would run to EOF and every later schema in the file would count as a field this gate writes
GVBOUNDS

# --- Assertion 11: THE NEAR MISSES — the arms must stay quiet ---------------
# An arm that reds every edit discriminates against nothing. `nm-rename` is the
# load-bearing one: it renames the field on BOTH sides, so the join survives and only a
# predicate keyed on the literal token `story_status` would go red on it.
while IFS='|' read -r gvm gvwhy; do
  [ -n "$gvm" ] || continue
  python3 "$GV_WORK/seed.py" "$GATE" "$GV_WORK/$gvm.md" "$gvm" || {
    bad "NEAR MISS $gvm did not build"
    continue
  }
  if cmp -s "$GATE" "$GV_WORK/$gvm.md"; then
    bad "NEAR MISS $gvm changed no bytes, so it is the positive control again and not a near miss"
    continue
  fi
  gvgot="$(gv_join "$GV_WORK/$gvm.md")"
  case "$gvgot" in
    GREEN*) ok "NEAR MISS $gvm stays GREEN — $gvwhy" ;;
    *) bad "NEAR MISS $gvm reads '${gvgot%% *}' — $gvwhy. The arm reds an edit that preserves the join, so its findings above are not attributable: $gvgot" ;;
  esac
done <<'GVNEARMISS'
nm-unrelated|an unrelated non-comment line in Check 5 names no field and must not move the verdict
nm-rename|the comparand renamed on BOTH sides keeps the join intact, so the arms are keyed on the shape and not on one spelling
GVNEARMISS

# --- Assertion 12: WHAT THE ENTRY'S RECEIPT STILL CANNOT SEE ----------------
# THE DIVISION OF LABOUR IS ASSERTED, NOT WRITTEN DOWN. The comment at the top of this
# block states which seeds the backlog receipt closes on and which its span bound refuses;
# a comment goes stale in silence, and the next hand to widen the receipt would read these
# arms as redundant. So the receipt is RUN, here, over the same seeds, and each case is
# checked against what this fixture claims about it.
#
# The receipt is DERIVED from the entry, never restated: its `verify:` line is read out of
# `docs/backlog.md` and executed. A hardcoded copy here would be a second definition, and
# the two would drift exactly as the grep and the template did above.
#
# THE ARM STANDS DOWN RATHER THAN FAILING when the entry is gone. Once BL-040 rotates its
# receipt is archived and inert while this fixture still runs, and a fixture that lost its
# subject is not a tree defect.
GV_BL="$(find_one ../docs/backlog.md 2>/dev/null)"
[ -n "$GV_BL" ] && [ -f "$GV_BL" ] || GV_BL="${ROOT:-}/docs/backlog.md"
GV_RCPT=""
if [ -f "$GV_BL" ]; then
  GV_RCPT="$(LC_ALL=C sed -n "s/^verify: sh \(S=.*CHECK_LOADED: 5 .*gate-log.*\)$/\1/p" "$GV_BL" | head -1)"
fi
if [ -z "$GV_RCPT" ]; then
  ok "receipt-coverage arm stands down — no BL-040 \`verify:\` line naming the Check 5 span is in docs/backlog.md (rotated, or this is a consumer tree that has no backlog)"
else
  # Score it on the LIVE file first. A receipt that does not close on the shipped fix is a
  # broken receipt, and every rc beside it would be unattributable.
  gv_rcpt_run() { # gv_rcpt_run <gate-validation.md>
    ( cd "$GV_WORK" && cp "$1" gv-subject.md \
      && mkdir -p core/skills/ai-dlc/steps \
      && cp gv-subject.md core/skills/ai-dlc/steps/gate-validation.md \
      && bash -c "$GV_RCPT" >/dev/null 2>&1 )
    printf '%s' "$?"
  }
  gv_live_rc="$(gv_rcpt_run "$GATE")"
  if [ "$gv_live_rc" != "0" ]; then
    bad "the entry's receipt does NOT close on the shipped file (rc=$gv_live_rc). Either the fix regressed or the receipt is keyed on something the file no longer carries; until it closes here, nothing can be concluded from how it scores a seed"
  else
    ok "the entry's receipt CLOSES on the shipped file (rc=0), so the codes below are attributable"
    # THE DIVISION IS DERIVED, NOT HAND-LISTED. Which seeds the receipt catches is a
    # property of whatever `verify:` line the entry carries TODAY, and that line has
    # already gained a span bound once. A hardcoded expectation here would fail the push
    # on the commit that STRENGTHENS the receipt, which reads exactly like a regression.
    #
    # So both sides are computed and joined: for every seed, the receipt's rc and this
    # fixture's own verdict. A seed the receipt CLOSES (rc=0) while the oracle says RED or
    # BLOWN is a case this fixture must own, and the arm fails if the oracle agrees with
    # the close. A seed the receipt refuses needs nothing from here.
    gv_blind=0; gv_covered=0
    for gvm in comment bare-mention read-commented no-fail-condition no-read no-write no-anchor6 no-anchor13; do
      [ -f "$GV_WORK/$gvm.md" ] || continue
      gvrc="$(gv_rcpt_run "$GV_WORK/$gvm.md")"
      gvv="$(gv_join "$GV_WORK/$gvm.md")"; gvv="${gvv%% *}"
      if [ "$gvrc" = "0" ]; then
        gv_blind=$((gv_blind + 1))
        if [ "$gvv" = "GREEN" ]; then
          bad "receipt coverage — $gvm: the entry's receipt CLOSES (rc=0) and this fixture reads GREEN too. Nothing in the tree can tell this seed from the shipped fix, which is the state both channels exist to prevent"
        else
          ok "receipt coverage — $gvm: the receipt closes (rc=0) and this fixture reads $gvv — the arm above is what covers it"
        fi
      else
        gv_covered=$((gv_covered + 1))
        ok "receipt coverage — $gvm: the entry's receipt refuses it itself (rc=$gvrc); these arms do not re-invent that"
      fi
    done
    # AND THE FIXTURE MUST BE LOAD-BEARING. If the receipt caught every seed, this whole
    # block would be a second copy of it — the state `mechanism-design.md` calls a vacuous
    # guard. Measured as a number rather than asserted in a comment.
    if [ "$gv_blind" -gt 0 ]; then
      ok "receipt coverage — $gv_blind of the seeds close the entry's receipt while shipping nothing, and $gv_covered are refused by it; these arms are what stands between the $gv_blind and a green tree"
    else
      bad "receipt coverage — the entry's receipt now refuses EVERY seed here, so these arms cover nothing the receipt does not. Either the seeds stopped discriminating or this block is now redundant with the receipt and should be retired rather than left as a check that cannot fire"
    fi
  fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "gate-verdict-grep-shape: PASS"; exit 0; fi
echo "gate-verdict-grep-shape: $fails assertion(s) FAILED" >&2
exit 1
