#!/usr/bin/env bash
# Exercise validate-spec-join.sh (gate-validation Check 30).
#
# Exit 0 iff:
#   - the healthy spec set              PASSES (0)  -- over-fire control
#   - an LR citing no capability        FAILS (1)   -- join (1)
#   - a CAP absent from the map         FAILS (1)   -- join (2)
#   - a story citing an unknown CAP     FAILS (1)   -- join (3)
#   - a story with no capabilities:     FAILS (1)   -- the link is the field
#   - a zero-capability kernel          DISARMS (2) -- every join would close vacuously
#   - a PRD with no FR Coverage Map     DISARMS (2) -- skipping join (2) silently is the defect
#   - lint_spine ad_fields findings     FAILS (1)   -- the borrowed verdict, decided
#   - a clean lint_spine JSON           PASSES (0)  -- over-fire control
#   - trace verdict FAIL                FAILS (1)
#   - trace verdict CONCERNS            PASSES (0) and PRINTS a note (recorded, not dropped)
#   - three MUTATION controls hold      -- one per mechanical join; one mutant
#                                          licenses only one FAIL
#   - a QUALIFIED capability memlog     PASSES (0)  -- `(capability by <who>)` is the
#                                          same entry type as `(capability)`
#   - qualified + an uncited LR         FAILS (1)   -- the widened entries FEED join (1)
#   - qualified NON-capability tags     DISARMS (2) -- the widening is not vacuous
#   - `(capability-review by <who>)`    DISARMS (2) -- and is not over-wide either
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

V=""
for cand in \
  "$DIR/../../scripts/validate-spec-join.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-spec-join.sh" \
  "$DIR/../../core/scripts/validate-spec-join.sh"; do
  [ -f "$cand" ] && V="$cand" && break
done
[ -n "$V" ] || { echo "run.sh: could not locate validate-spec-join.sh" >&2; exit 2; }

R="$(bash "$DIR/seed.sh")"
trap 'rm -rf "$R"' EXIT

rc=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; rc=1; }
# Run, then read $?. Never `out=$(...)` for a verdict.
want() { # <expected-rc> <label> <args...>
  local exp="$1" lab="$2"; shift 2
  bash "$V" "$@" >/dev/null 2>&1
  local g=$?
  [ "$g" -eq "$exp" ] && ok "$lab" || bad "$lab (expected rc=$exp, got rc=$g)"
}

echo "spec-join-integrity:"
# The candidate list above spans BOTH install layouts and takes the first that exists, so
# the file this unit actually loads is not necessarily the one an author just edited.
# Print it: a mutant applied to the other copy leaves every arm green and reads exactly
# like an arm that cannot fire.
echo "spec-join-integrity: resolved subject = $(cd "$(dirname "$V")" && pwd)/$(basename "$V")"

want 0 "OVER-FIRE CONTROL: a healthy spec set passes every join" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --story "$R/story-ok.md"

want 1 "join (1): a locked requirement citing no capability FAILS" \
  --spec "$R/orphan-lr" --prd "$R/prd-ok.md"

want 1 "join (2): a capability no FR entry cites FAILS" \
  --spec "$R/ok" --prd "$R/prd-missing-cap.md"

want 1 "join (3): a story citing an undefined CAP FAILS" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --story "$R/story-dangling.md"

want 1 "a story with no capabilities: field FAILS (the field IS the link)" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --story "$R/story-nofield.md"

want 2 "DISARM: a zero-capability kernel exits 2, never 0" \
  --spec "$R/no-caps" --prd "$R/prd-ok.md"

want 2 "DISARM: a PRD with no FR identifiers exits 2, never 0" \
  --spec "$R/ok" --prd "$R/prd-no-fr.md"

# OVER-FIRE PIN. The CAP citation lives on the FR ENTRY, never in BMAD's FR Coverage
# Map. The strings `CAP` and `LR-` appear NOWHERE in bmad-create-epics-and-stories,
# and its instructed output is literally `FR1: Epic 1 - [Brief description]`. One
# observed run emitted `FR-S300-1 (CAP-1): ...`, but that was the author's discretion,
# not the tool's contract -- so the map's content is non-deterministic and a check
# reading it would pass or fail on who wrote the map. This pin is what keeps join (2)
# independent of it.
want 0 "PIN: BMAD's literal FR-Coverage-Map format (no CAP token) still PASSES" \
  --spec "$R/ok" --prd "$R/prd-real-map.md" --story "$R/story-ok.md"

# REAL lint_spine.py envelopes. Severity comes from the script: any `high` fails,
# `low` is reported. `ad_id` ("id reused" / "non-monotonic") is in the bad payload and
# was IGNORED by the first version, which hand-listed two of the four categories --
# while ID stability is the premise every join here rests on.
want 1 "borrowed verdict: high-severity lint_spine findings FAIL the gate" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine-lint "$R/spine-bad.json"

want 0 "low-severity-only lint findings are RECORDED, not gating" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine-lint "$R/spine-low.json"
# POSITIVE CONJUNCT. rc=0 is also what a subject replaced by `exit 0` produces, and this
# arm passed against one until it was measured. The NOTE is the thing being claimed.
says "low-severity findings are RECORDED — the note is what makes this arm non-vacuous" \
  "low-severity finding(s)" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine-lint "$R/spine-low.json"

want 2 "DISARM: a file that is not a lint_spine envelope exits 2, never 0" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine-lint "$R/story-ok.md"

want 0 "OVER-FIRE CONTROL: a clean lint_spine JSON passes" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine-lint "$R/spine-ok.json"

want 1 "borrowed verdict: gate_status FAIL fails the gate" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --trace-verdict "$R/trace-fail.json"

# FALSE-POSITIVE PIN. gate_status is CONCERNS while p1_status is FAIL, in the same
# file. A whole-file grep for FAIL fails a gate the tool passed.
want 0 "PIN: gate_status CONCERNS with p1_status FAIL does NOT fail the gate" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --trace-verdict "$R/trace-concerns.json"

want 0 "gate_status PASS passes" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --trace-verdict "$R/trace-pass.json"

want 2 "DISARM: a trace file with no gate_status exits 2, never 0 (NOT_EVALUATED)" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --trace-verdict "$R/trace-notevaluated.json"

if bash "$V" --spec "$R/ok" --prd "$R/prd-ok.md" --trace-verdict "$R/trace-concerns.json" 2>&1 | grep -q 'note'; then
  ok "CONCERNS is RECORDED with the matrix cited, not dropped"
else
  bad "a CONCERNS trace verdict passed with no note — the concern is silently discarded"
fi

# --- REAL bmad-spec shape, and the self-report regression pin ------------------
# These three run against payloads reproducing what bmad-spec actually writes,
# frontmatter and `(event)` verdict lines included.
want 0 "REAL SHAPE: actual bmad-spec output passes every join" \
  --spec "$R/real" --prd "$R/prd-real.md" --story "$R/story-real.md"

# THE PIN. CAP-2's `(capability)` entry is severed while the Self-Validate `(event)`
# line still reads "LR-S300-2 -> CAP-2". A join that scans every memlog line
# mentioning the LR is satisfied by that summary and reports PASS — reading the
# spec's own claim that the join holds as evidence that it holds, which is the
# self-declared verdict Rule 30 forbids adopting. Measured against a real run: the
# first version of this check passed here.
want 1 "PIN: a severed capability entry FAILS even though the (event) verdict still names the mapping" \
  --spec "$R/real-severed" --prd "$R/prd-real.md" --story "$R/story-real.md"

want 2 "DISARM: no (capability) entries at all exits 2, never 0" \
  --spec "$R/real-untyped" --prd "$R/prd-real.md" --story "$R/story-real.md"

# --- real bmad-prd FR shape, both sides of the PM enrichment pass ---------------
# Raw bmad-prd output cannot satisfy join (2): H4-heading FRs with no CAP token, from a
# skill that has no capability concept at all. The check must CATCH that rather than
# excuse it, and must pass once the citations are added to the heading lines.
want 1 "raw bmad-prd output (H4 FRs, no CAP token) FAILS join (2)" \
  --spec "$R/ok" --prd "$R/prd-bmad-raw.md"

want 0 "the same PRD with (CAP-n) added to its H4 FR headings PASSES" \
  --spec "$R/ok" --prd "$R/prd-bmad-enriched.md"

# --- (2a) the CAP -> AD join, against bmad-architecture's real spine shape ------
want 0 "OVER-FIRE CONTROL: a spine whose AD binds 'all' covers every capability" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-all.md"
says "OVER-FIRE CONTROL: and the spine-wide close is ANNOUNCED, not silent" \
  "declares '**Binds:** all'" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-all.md"

want 1 "join (2a): a capability no AD binds FAILS" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-cap1only.md"

want 2 "DISARM: a file with no '- **Binds:**' entries exits 2, never 0" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/prd-ok.md"

# --- the capabilities: TRICHOTOMY (v0.254.0) ----------------------------------
# EXIT CODE IS NOT THE ASSERTION FOR TWO OF THESE. key-absent and empty-without-why
# both FAIL(1) before and after, so a fixture checking only rc scores a FALSE PASS
# against the collapsed version -- this repo's own defect class, reproduced inside the
# test written to catch it. Assert on the SENTENCE.
says() { # <label> <must-contain> <args...>
  local lab="$1" want_s="$2"; shift 2
  local out; out="$(bash "$V" "$@" 2>&1)"
  if grep -qF -- "$want_s" <<<"$out"; then ok "$lab"
  else bad "$lab (message missing: \"$want_s\")"; fi
}

says "trichotomy: key ABSENT says the field is absent" \
  "carries no 'capabilities:' frontmatter field at all" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --story "$R/story-nofield.md"

says "trichotomy: key EMPTY says the field IS present" \
  "The field IS present" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --story "$R/story-empty.md"

# The over-fire control for the sentence above: the empty case must NOT be told the
# field is missing. That is the exact false statement this release removes.
ASSERT_OUT="$(bash "$V" --spec "$R/ok" --prd "$R/prd-ok.md" --story "$R/story-empty.md" 2>&1)"
if grep -qF "carries no 'capabilities:' frontmatter field at all" <<<"$ASSERT_OUT"; then
  bad "trichotomy: the EMPTY case is still told the field is absent — the false diagnosis survives"
elif ! grep -qF "The field IS present" <<<"$ASSERT_OUT"; then
  bad "trichotomy: neither sentence is present — this absence arm would pass against a subject that emits nothing"
else
  ok "trichotomy: the EMPTY case is NOT told the field is absent, and IS told the field is present"
fi

want 0 "trichotomy: EMPTY + capabilities_rationale is a declared disposition, not a failure" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --story "$R/story-empty-declared.md"

says "trichotomy: the declared disposition is RECORDED, not silent" \
  "declares no capability, with a rationale" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --story "$R/story-empty-declared.md"

# --- --baseline, and the arm that stops it outliving its cause (v0.254.0) ------
want 1 "baseline control: the orphan LR fails with no baseline" \
  --spec "$R/orphan-lr" --prd "$R/prd-ok.md"

want 0 "baseline: a live entry suppresses the failure it names" \
  --spec "$R/orphan-lr" --prd "$R/prd-ok.md" --baseline "$R/baseline-live.txt"

want 1 "baseline: an entry that STOPS REPRODUCING is itself a FAIL — a baseline must not outlive its cause" \
  --spec "$R/orphan-lr" --prd "$R/prd-ok.md" --baseline "$R/baseline-stale.txt"

says "baseline: the stale entry is named, so the remedy is one deletable line" \
  "did NOT reproduce this run" \
  --spec "$R/orphan-lr" --prd "$R/prd-ok.md" --baseline "$R/baseline-stale.txt"

want 2 "baseline: an unreadable baseline DISARMS rather than reporting every failure as new" \
  --spec "$R/orphan-lr" --prd "$R/prd-ok.md" --baseline "$R/nonexistent-baseline.txt"

# THE CASE THAT DECIDES WHETHER --baseline IS A LEDGER OR A MUTE BUTTON is the pair
# above: same tree, same failure, one file — suppressed when the cause is live, FAILED
# when it is gone. Either half alone is satisfied by a validator that always suppresses.

# --- MUTATION controls: one per mechanical join -------------------------------
# Copy, then `cmp -s` to prove the edit matched. A sed matching nothing yields a
# mutant identical to the subject, which "fails as expected" for the wrong reason.
# Substitution is on a LITERAL substring via perl \Q…\E, not a hand-escaped sed
# regex. The first draft here used sed expressions quoted through two layers and all
# three matched nothing; the `cmp -s` guard caught it, which is the only reason three
# vacuous assertions did not report themselves as passing mutation controls.
mut() { # <name> <literal-from> <literal-to> <expect-rc> <label> <args...>
  local n="$1" from="$2" to="$3" exp="$4" lab="$5"; shift 5
  local m="$R/mutant-$n.sh"
  cp "$V" "$m"
  FROM="$from" TO="$to" perl -pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$m"
  if cmp -s "$V" "$m"; then
    bad "FIXTURE ERROR: mutation '$n' matched nothing — its assertion would prove nothing"
    return
  fi
  bash "$m" "$@" >/dev/null 2>&1
  local g=$?
  [ "$g" -eq "$exp" ] && ok "$lab" || bad "$lab (mutant exited $g, expected $exp — the guard under test is not what produced the FAIL)"
}

mut lr-off 'grep -qE "$CAP_GRAMMAR"' "true" \
  0 "MUTATION: neutering join (1) turns the orphan-LR case green" \
  --spec "$R/orphan-lr" --prd "$R/prd-ok.md"

mut cap-off 'grep -qE "(^|[^A-Za-z0-9-])$cap([^A-Za-z0-9-]|\$)"' "true" \
  0 "MUTATION: neutering join (2) turns the missing-CAP map green" \
  --spec "$R/ok" --prd "$R/prd-missing-cap.md"

mut story-off 'grep -qx -- "$r"' "true" \
  0 "MUTATION: neutering join (3) turns the dangling-CAP story green" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --story "$R/story-dangling.md"

# --- MUTATION controls for the v0.254.0 arms ----------------------------------
# `mut` asserts on rc, which is the wrong instrument for the trichotomy: collapsing it
# leaves every case exiting 1. This one asserts on the SENTENCE, and it is guarded the
# same way — `cmp -s` proves the edit landed, plus `bash -n` proves the mutant is still
# a program, because a mutant that dies on a syntax error emits nothing and nothing
# reads as a kill.
mut_says() { # <name> <literal-from> <literal-to> <must-contain> <label> <args...>
  local n="$1" from="$2" to="$3" want_s="$4" lab="$5"; shift 5
  local m="$R/mutant-$n.sh"
  cp "$V" "$m"
  FROM="$from" TO="$to" perl -pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$m"
  if cmp -s "$V" "$m"; then
    bad "FIXTURE ERROR: mutation '$n' matched nothing — its assertion would prove nothing"; return
  fi
  if ! bash -n "$m" 2>/dev/null; then
    bad "FIXTURE ERROR: mutant '$n' is not a valid shell script — its silence is not a kill"; return
  fi
  local out; out="$(bash "$m" "$@" 2>&1)"
  if grep -qF -- "$want_s" <<<"$out"; then ok "$lab"
  else bad "$lab (mutant did not produce: \"$want_s\")"; fi
}

# THE SHIPPED DEFECT ON DEMAND. Sever the present-vs-absent discrimination and the
# EMPTY story is told again that it carries no field — the false sentence this release
# exists to remove. Both sides of one predicate flip together; that is the predicate,
# not two entangled guards.
mut_says tri-collapse 'if ! grep -q '"'"'^capabilities:'"'"' "$s"; then' 'if true; then' \
  "carries no 'capabilities:' frontmatter field at all" \
  "MUTATION: collapsing the trichotomy tells the EMPTY story its field is missing again" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --story "$R/story-empty.md"

mut tri-rationale-off 'elif [ -n "$cap_rationale" ]; then' 'elif false; then' \
  1 "MUTATION: dropping the rationale branch fails the declared disposition" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --story "$R/story-empty-declared.md"

# Without this arm --baseline is a mute button: the entry outlives its cause and stands
# ready to suppress the next real instance of the same id, silently.
mut baseline-forever 'if ! grep -qxF -- "$bk" <<<"$BASELINE_HIT"; then' 'if false; then' \
  0 "MUTATION: dropping the did-not-reproduce arm turns the STALE baseline green" \
  --spec "$R/orphan-lr" --prd "$R/prd-ok.md" --baseline "$R/baseline-stale.txt"

# UNMUTATED CONTROL. Every mutant above is a copy in $R; if a copy misbehaves there for
# any reason other than its mutation, each of those assertions is vacuous.
cp "$V" "$R/control-unmutated.sh"
bash "$R/control-unmutated.sh" --spec "$R/orphan-lr" --prd "$R/prd-ok.md" --baseline "$R/baseline-stale.txt" >/dev/null 2>&1
[ $? -eq 1 ] && ok "CONTROL: an unmutated copy in \$R still FAILS the stale baseline" \
             || bad "CONTROL: an unmutated copy misbehaves in \$R — every mutation above is vacuous"

# --- the memlog tag QUALIFIER, and the DISARM that sits above every join --------
# THIS BLOCK MUST STAY ABOVE `exit $rc`. An earlier attempt at these arms appended them
# BELOW it, reported rc=0 and PASS, and executed none of them -- "a check that cannot
# fire reads exactly like one that passed", landing on the guard for this very entry.
# $QUAL_ARMS is the answer to that: every arm here goes through a counting wrapper and
# the last arm asserts the count, so a truncated or unreachable block reports itself.
#
# THE SUBJECT. memlog.py renders `(<type>)` or `(<type> by <who>)` and the qualifier is
# decided PER APPEND. `CAP_ENTRIES` required `)` immediately after the type, so a memlog
# whose capability entries are qualified -- the reference consumer's s302, every entry --
# yielded an EMPTY set and hit `exit 2`. That exit is ABOVE joins (1), (2), (2a) and (3),
# so the whole of Check 30 dies, not just the LR->CAP leg.
QUAL_ARMS=0
q_want() { QUAL_ARMS=$((QUAL_ARMS+1)); want "$@"; }
q_says() { QUAL_ARMS=$((QUAL_ARMS+1)); says "$@"; }
q_mut()  { QUAL_ARMS=$((QUAL_ARMS+1)); mut  "$@"; }

# (a) the observed qualified forms PASS. rc=0 alone is what a subject replaced by
# `exit 0` also produces, so the PASS LINE and its counts are asserted beside it: those
# counts are readable only if the memlog was actually parsed.
q_want 0 "QUALIFIER: '(capability by bmad-spec)' / '(capability by pm-escalated)' entries PASS every join" \
  --spec "$R/real-qualified" --prd "$R/prd-real.md" --story "$R/story-real.md"
q_says "QUALIFIER: the qualified memlog is COUNTED, not merely tolerated" \
  "PASS (2 locked requirement(s), 2 capability(ies)" \
  --spec "$R/real-qualified" --prd "$R/prd-real.md" --story "$R/story-real.md"

# (b) THE ARM THAT PROVES THE WIDENED ENTRIES FEED THE JOIN. Qualified entries exist, so
# the emptiness test is satisfied; LR-S300-2 is cited only by a `(note ...)`. A widening
# that collected the entries and never handed them to the loop passes (a) and exits 0
# here. Exit 2 here would mean the DISARM merely moved.
q_want 1 "QUALIFIER: an uncited LR in a QUALIFIED memlog FAILS at join (1) — it does not DISARM" \
  --spec "$R/real-qualified-orphan" --prd "$R/prd-real.md" --story "$R/story-real.md"
q_says "QUALIFIER: the failing LR is NAMED, so the widening is feeding join (1)" \
  "LR-S300-2 appears in the memlog but no capability entry cites it" \
  --spec "$R/real-qualified-orphan" --prd "$R/prd-real.md" --story "$R/story-real.md"

# (c) NEGATIVE CONTROL. Every tag qualified, none a capability. Dropping the type anchor
# would read the `(event ...)` self-report as a capability entry and close join (1) on
# the spec's own verdict -- the exact defect the `real-severed` pin exists for, reachable
# a second way through the qualifier. Holds under both the narrow and the widened
# predicate; the mutant below is what proves it can fire at all.
q_want 2 "NEGATIVE CONTROL: qualified NON-capability tags only still DISARMS at exit 2" \
  --spec "$R/real-qualified-noncap" --prd "$R/prd-real.md" --story "$R/story-real.md"
q_says "NEGATIVE CONTROL: the DISARM says why, rather than exiting 2 mutely" \
  "contains no '(capability)' entries" \
  --spec "$R/real-qualified-noncap" --prd "$R/prd-real.md" --story "$R/story-real.md"

# (d) the TIGHTNESS boundary. `(capability-review by lead)` shares a prefix and is a
# different type. The `[[:space:]]` opening the optional group is the whole of what
# excludes it.
q_want 2 "TIGHTNESS: '(capability-review by lead)' is a DIFFERENT type and still DISARMS" \
  --spec "$R/real-hyphen-type" --prd "$R/prd-real.md" --story "$R/story-real.md"
q_says "TIGHTNESS: the hyphenated neighbour is reported as no capability entries at all" \
  "contains no '(capability)' entries" \
  --spec "$R/real-hyphen-type" --prd "$R/prd-real.md" --story "$R/story-real.md"

# (e) `--by` is free text and the real corpus proves it: `(correction by lead, CAP-10
# pointer clause at 01:57:27Z)` carries commas, digits and a colon through the same code
# path that builds a capability tag.
q_want 0 "QUALIFIER: a rich '--by' qualifier (commas, digits, a colon) PASSES" \
  --spec "$R/real-qualifier-rich" --prd "$R/prd-real.md" --story "$R/story-real.md"
q_says "QUALIFIER: the rich-qualifier memlog is COUNTED, not merely tolerated" \
  "PASS (2 locked requirement(s), 2 capability(ies)" \
  --spec "$R/real-qualifier-rich" --prd "$R/prd-real.md" --story "$R/story-real.md"

# MUTATION: the pre-fix predicate, restored exactly by deleting the optional group. This
# is the ONE mutant that reproduces the shipped defect, and every arm above under (a),
# (b) and (e) goes red against it -- the block's reason for existing.
q_mut qual-narrow "([[:space:]][^)]*)?" "" \
  2 "MUTATION: reverting the qualifier group DISARMS the qualified memlog at exit 2" \
  --spec "$R/real-qualified" --prd "$R/prd-real.md" --story "$R/story-real.md"

# MUTATION: the widening gone VACUOUS. Drop the type anchor and (c) exits 0 on a memlog
# with no capability entry in it. This is what makes (c) an arm rather than a formality.
q_mut qual-typeless '\((capability|capabilities)([[:space:]][^)]*)?\)' '\([^)]*\)' \
  0 "MUTATION: dropping the TYPE anchor closes join (1) on a memlog with no capability entry" \
  --spec "$R/real-qualified-noncap" --prd "$R/prd-real.md" --story "$R/story-real.md"

# MUTATION: the `[[:space:]]` deleted, the rest of the group kept. (d) exits 0, which is
# the measurement behind calling that one character load-bearing.
q_mut qual-hyphen "([[:space:]][^)]*)?" "([^)]*)?" \
  0 "MUTATION: dropping the [[:space:]] swallows '(capability-review)' as a capability entry" \
  --spec "$R/real-hyphen-type" --prd "$R/prd-real.md" --story "$R/story-real.md"

# ARMS-RAN. Non-zero and exact. A block that never executed, or one truncated by an early
# `exit`, cannot produce this row -- and the count is what distinguishes it from a block
# that ran halfway.
if [ "$QUAL_ARMS" -eq 13 ]; then
  ok "ARMS-RAN: all 13 qualifier arms EXECUTED (counted $QUAL_ARMS)"
else
  bad "ARMS-RAN: expected 13 qualifier arms, counted $QUAL_ARMS — the block is unreachable, truncated, or short-circuited"
fi


# --- v0.388.0: five behaviours, and the counter that proves this block ran ------
# THIS BLOCK MUST STAY ABOVE `exit $rc`, for the reason the QUALIFIER block above
# records: arms appended below it execute never and report PASS. $NEW_ARMS is the answer,
# asserted exactly at the end.
#
# WHAT IS UNDER TEST, none of it seeded from the reader's accept-set:
#   (G) CAP_GRAMMAR accepts one lowercase suffix, and a token it cannot spell IN FULL
#       DISARMs instead of leaving the capability set in silence
#   (S) the story-citation arm routes through fail_join, so --baseline can reach it, on a
#       key the coarse `story:` key cannot stand in for
#   (B) the `- **Binds:**` reader folds wrapped continuation lines into their bullet
#   (N) `- **No-AD:** CAP-n — REASON: <why>` is join (2a)'s third disposition
#   (D) `- (disposition) LR-n NO-CAPABILITY <reason>` is join (1)'s third disposition
# A LAYERED FIX NEEDS A LAYERED MUTANT. Reverting one layer of a two-layer guard leaves
# the other still failing the run, and `mut` then reports "expected 0, got 1" -- which
# reads as a broken mutant rather than as an incomplete revert. Each layer gets its own
# `cmp` guard, so a layer whose literal has moved is named.
# THREE LAYERS NOW COVER THE CAPABILITY SET: the id grammar, the declaration-shape
# assertion, and the looks-declarative join. Reverting any two leaves the third catching
# the seed, which reads as a broken mutant rather than as an incomplete revert.
mut3() { # <name> <f1> <t1> <f2> <t2> <f3> <t3> <expect-rc> <label> <args...>
  local n="$1" f1="$2" t1="$3" f2="$4" t2="$5" f3="$6" t3="$7" exp="$8" lab="$9"; shift 9
  _mut3_build "$n" "$f1" "$t1" "$f2" "$t2" "$f3" "$t3" || return
  bash "$R/mutant-$n.sh" "$@" >/dev/null 2>&1
  local g=$?
  [ "$g" -eq "$exp" ] && ok "$lab" || bad "$lab (mutant exited $g, expected $exp — a layer is still doing the job)"
}
mut3_says() { # <name> <f1> <t1> <f2> <t2> <f3> <t3> <must-contain> <label> <args...>
  local n="$1" f1="$2" t1="$3" f2="$4" t2="$5" f3="$6" t3="$7" want_s="$8" lab="$9"; shift 9
  _mut3_build "$n" "$f1" "$t1" "$f2" "$t2" "$f3" "$t3" || return
  local out; out="$(bash "$R/mutant-$n.sh" "$@" 2>&1)"
  if grep -qF -- "$want_s" <<<"$out"; then ok "$lab"
  else bad "$lab (mutant did not produce: \"$want_s\")"; fi
}
_mut3_build() { # <name> <f1> <t1> <f2> <t2> <f3> <t3>  -- each layer guarded on its own
  local n="$1" m="$R/mutant-$1.sh" i prev
  cp "$V" "$m"
  for i in 1 2 3; do
    prev="$m.prev"; cp "$m" "$prev"
    case "$i" in 1) FROM="$2" TO="$3" ;; 2) FROM="$4" TO="$5" ;; 3) FROM="$6" TO="$7" ;; esac
    export FROM TO; perl -pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$m"
    if cmp -s "$prev" "$m"; then
      bad "FIXTURE ERROR: mutation '$n' LAYER $i matched nothing — its assertion would prove nothing"; return 1
    fi
  done
  if ! bash -n "$m" 2>/dev/null; then
    bad "FIXTURE ERROR: mutant '$n' is not a valid shell script — its silence is not a kill"; return 1
  fi
  return 0
}

# NOTHING IN THIS BATTERY ASSERTED THAT THE FOLD ENDS, and the fold is an accumulator.
# Measured on this subject: its first version added a RELATIVE offset to an absolute
# cursor and walked backwards forever, and the only reason it surfaced is that an
# unrelated probe happened to be running under a timeout. A hang is not a failure -- it is
# a fixture that never reports -- so termination needs its own instrument.
#
# THE POLL MUST GRANT REAL WALL CLOCK. A `while kill -0` loop with no `sleep` spins
# thousands of iterations in microseconds and calls a healthy run a hang; that is a
# measured mistake from this same session, not a hypothetical.
# A PIN WHOSE PROPERTY IS STRUCTURAL CANNOT HAVE A MUTANT, and pretending otherwise is
# worse than saying so. `decl_run` only ever considers text inside an emphasis or code run,
# so an ordinary prose bullet is not reachable by any switchable guard -- the bad state is
# UNCONSTRUCTIBLE rather than checked for, which `mechanism-design.md` prefers. What still
# has to be established is that the pin DISCRIMINATES, and the instrument for that is a
# seeded offender in the SAME container measured in the SAME run: quiet here, DISARM there.
# A subject that emits nothing gives 0 and 0 and fails this by construction.
# KILL THE WHOLE TREE, LEAVES FIRST. `kill -9` on the backgrounded wrapper leaves its
# grandchildren running: they are reparented to init and keep burning a core for the rest
# of the session. Measured while building this arm — 21 leaked `awk` processes at ~90% CPU
# after a handful of runs, and under the 16-way fixture pool that is sixteen per run. One
# level of `pkill -P` was not enough either, because the chain is wrapper -> subshell ->
# awk; two survived. Recursion is what makes it complete, and children must die before
# their parent, since once the parent is gone `pgrep -P` can no longer find them.
_kill_tree() { # <pid>
  local kid
  for kid in $(pgrep -P "$1" 2>/dev/null); do _kill_tree "$kid"; done
  kill -9 "$1" 2>/dev/null
}

discriminates() { # <label> <quiet-spec-dir> <offender-spec-dir> <prd>
  local lab="$1" q="$2" o="$3" pr="$4" a b
  bash "$V" --spec "$q" --prd "$pr" >/dev/null 2>&1; a=$?
  bash "$V" --spec "$o" --prd "$pr" >/dev/null 2>&1; b=$?
  if [ "$a" -eq 0 ] && [ "$b" -eq 2 ]; then ok "$lab"
  else bad "$lab (pin exited $a and offender exited $b — expected 0 and 2 in the same run)"; fi
}

run_bounded() { # <seconds> <script> <args...>  -- rc 0 completed, 1 killed at the bound
  local secs="$1" prog="$2"; shift 2
  bash "$prog" "$@" >/dev/null 2>&1 &
  local pid=$! deadline
  deadline=$(( $(date +%s) + secs ))
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$(date +%s)" -ge "$deadline" ]; then
      _kill_tree "$pid"; wait "$pid" 2>/dev/null
      return 1
    fi
    sleep 1
  done
  wait "$pid" 2>/dev/null
  return 0
}

mut2_says() { # <name> <from1> <to1> <from2> <to2> <must-contain> <label> <args...>
  local n="$1" f1="$2" t1="$3" f2="$4" t2="$5" want_s="$6" lab="$7"; shift 7
  local m="$R/mutant-$n.sh"
  cp "$V" "$m"
  FROM="$f1" TO="$t1" perl -pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$m"
  if cmp -s "$V" "$m"; then bad "FIXTURE ERROR: mutation '$n' LAYER 1 matched nothing"; return; fi
  cp "$m" "$m.layer1"
  FROM="$f2" TO="$t2" perl -pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$m"
  if cmp -s "$m.layer1" "$m"; then bad "FIXTURE ERROR: mutation '$n' LAYER 2 matched nothing"; return; fi
  if ! bash -n "$m" 2>/dev/null; then bad "FIXTURE ERROR: mutant '$n' is not a valid shell script"; return; fi
  local out; out="$(bash "$m" "$@" 2>&1)"
  if grep -qF -- "$want_s" <<<"$out"; then ok "$lab"
  else bad "$lab (mutant did not produce: \"$want_s\")"; fi
}

mut2() { # <name> <from1> <to1> <from2> <to2> <expect-rc> <label> <args...>
  local n="$1" f1="$2" t1="$3" f2="$4" t2="$5" exp="$6" lab="$7"; shift 7
  local m="$R/mutant-$n.sh"
  cp "$V" "$m"
  FROM="$f1" TO="$t1" perl -pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$m"
  if cmp -s "$V" "$m"; then
    bad "FIXTURE ERROR: mutation '$n' LAYER 1 matched nothing — its assertion would prove nothing"; return
  fi
  cp "$m" "$m.layer1"
  FROM="$f2" TO="$t2" perl -pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$m"
  if cmp -s "$m.layer1" "$m"; then
    bad "FIXTURE ERROR: mutation '$n' LAYER 2 matched nothing — only one layer was reverted"; return
  fi
  if ! bash -n "$m" 2>/dev/null; then
    bad "FIXTURE ERROR: mutant '$n' is not a valid shell script — its silence is not a kill"; return
  fi
  bash "$m" "$@" >/dev/null 2>&1
  local g=$?
  [ "$g" -eq "$exp" ] && ok "$lab" || bad "$lab (mutant exited $g, expected $exp — a layer is still doing the job)"
}

NEW_ARMS=0
n_want()     { NEW_ARMS=$((NEW_ARMS+1)); want     "$@"; }
n_says()     { NEW_ARMS=$((NEW_ARMS+1)); says     "$@"; }
n_mut()      { NEW_ARMS=$((NEW_ARMS+1)); mut      "$@"; }
n_mut2()     { NEW_ARMS=$((NEW_ARMS+1)); mut2     "$@"; }
n_mut2_says(){ NEW_ARMS=$((NEW_ARMS+1)); mut2_says "$@"; }
n_mut3()     { NEW_ARMS=$((NEW_ARMS+1)); mut3     "$@"; }
n_mut3_says(){ NEW_ARMS=$((NEW_ARMS+1)); mut3_says "$@"; }
n_discrim()  { NEW_ARMS=$((NEW_ARMS+1)); discriminates "$@"; }
n_mut_says() { NEW_ARMS=$((NEW_ARMS+1)); mut_says "$@"; }

# --- (G) the alphabetic capability suffix --------------------------------------
# rc=0 is also what a subject replaced by `exit 0` produces, so the PASS LINE and its
# CAPABILITY COUNT are asserted beside it: `3 capability(ies)` is readable only if CAP-1a
# entered the set, and it is exactly 2 under the pre-fix grammar.
n_want 0 "SUFFIX: a kernel defining CAP-1a alongside CAP-1 and CAP-2 passes every join" \
  --spec "$R/real-suffixed" --prd "$R/prd-suffixed.md" --story "$R/story-suffixed.md" --spine "$R/spine-suffixed.md"
n_says "SUFFIX: CAP-1a is COUNTED into the capability set, not merely tolerated" \
  "PASS (2 locked requirement(s), 3 capability(ies), 1 story(ies), 0 recorded note(s), 0 baselined)" \
  --spec "$R/real-suffixed" --prd "$R/prd-suffixed.md" --story "$R/story-suffixed.md" --spine "$R/spine-suffixed.md"

# THE ARMS THAT PROVE THE SUFFIXED ID FEEDS THE JOINS. A widening that parsed CAP-1a and
# never handed it to the per-capability loops passes both arms above and exits 0 here.
n_want 1 "SUFFIX: join (2) FAILS when no FR cites CAP-1a — the suffixed id is not exempt" \
  --spec "$R/real-suffixed" --prd "$R/prd-suffixed-nocap1a.md" --story "$R/story-suffixed-no1a.md"
n_says "SUFFIX: join (2) NAMES CAP-1a, so the finding is actionable" \
  "CAP-1a is defined in SPEC.md but no functional requirement in" \
  --spec "$R/real-suffixed" --prd "$R/prd-suffixed-nocap1a.md" --story "$R/story-suffixed-no1a.md"
n_want 1 "SUFFIX: join (2a) FAILS when no AD binds CAP-1a" \
  --spec "$R/real-suffixed" --prd "$R/prd-suffixed.md" --story "$R/story-suffixed.md" --spine "$R/spine-suffixed-no1a.md"
n_says "SUFFIX: join (2a) NAMES CAP-1a" \
  "CAP-1a is defined in SPEC.md but no architecture decision in" \
  --spec "$R/real-suffixed" --prd "$R/prd-suffixed.md" --story "$R/story-suffixed.md" --spine "$R/spine-suffixed-no1a.md"

# DISTINCTNESS. A PRD citing CAP-1a and NOT CAP-1 must fail for CAP-1. Without the
# boundary class `CAP-1` matches inside `CAP-1a` and the two collapse into one id, which
# is the failure mode a suffix grammar invites and the reason `sort -u -V` alone is not
# enough.
n_says "SUFFIX: CAP-1 and CAP-1a are DISTINCT ids — citing the suffixed one does not cover the bare one" \
  "CAP-1 is defined in SPEC.md but no functional requirement in" \
  --spec "$R/real-suffixed" --prd "$R/prd-suffixed-only1a.md" --story "$R/story-suffixed.md"

# THE RESIDUE PARTITION. Two shapes one character outside the accepted form, each beside
# two ids the grammar DOES parse -- so the zero-capability DISARM cannot be what catches
# them, and a silent drop is the only other outcome available.
n_want 2 "RESIDUE: a kernel carrying CAP-1ab DISARMS at exit 2 rather than dropping it" \
  --spec "$R/cap-residue" --prd "$R/prd-ok.md"
n_says "RESIDUE: the DISARM ECHOES the offending definition line, so the remedy is one edit" \
  "CAP-1ab" \
  --spec "$R/cap-residue" --prd "$R/prd-ok.md"
n_says "RESIDUE: an UPPERCASE suffix is caught too — the partition is the class, not one shape" \
  "CAP-1A" \
  --spec "$R/cap-residue-upper" --prd "$R/prd-ok.md"

# THE RESIDUE OVER-FIRE PIN. `CAP-<n>` and `CAP-N` are how this repo and BMAD both write
# a capability in prose. A residue class that caught them would DISARM every real kernel
# whose text explains its own id scheme -- a hard block on correct input.
n_want 0 "RESIDUE PIN: template tokens CAP-<n> and CAP-N are NOT residue" \
  --spec "$R/cap-template" --prd "$R/prd-ok.md" --story "$R/story-ok.md"
n_says "RESIDUE PIN: and they are not counted as capabilities either" \
  "PASS (2 locked requirement(s), 2 capability(ies), 1 story(ies), 0 recorded note(s), 0 baselined)" \
  --spec "$R/cap-template" --prd "$R/prd-ok.md" --story "$R/story-ok.md"

# MUTATION: the pre-fix grammar, restored exactly. THE DROP DOES NOT SURFACE AS A MISSING
# CAPABILITY -- it surfaces as an ACCUSATION AGAINST THE STORY AUTHOR, about an id sitting
# defined in the kernel. Note that reverting CAP_GRAMMAR alone is the whole revert: the
# residue expression is a SEPARATE literal that still accepts `CAP-1a`, so layer two does
# not catch what layer one stopped parsing.
# THE CAPABILITY SET IS NO LONGER A FREE GREP -- it is the well-formed subset of the
# DEFINITION bullets, so the grammar that decides membership is this `grep -xE`, not
# `$CAP_GRAMMAR`. Narrowing it alone is the whole revert: the residue filter beside it
# still accepts `CAP-1a`, so nothing downstream catches what this stopped parsing.
n_mut2_says grammar-narrow "grep -xE 'CAP-[0-9]+[a-z]?'" "grep -xE 'CAP-[0-9]+'" \
  'if [ -n "$CAP_DECL_MALFORMED" ]; then' 'if false; then' \
  "cites 'CAP-1a' and" \
  "MUTATION: the old grammar accuses the STORY of citing an id the kernel defines" \
  --spec "$R/real-suffixed" --prd "$R/prd-suffixed.md" --story "$R/story-suffixed.md" --spine "$R/spine-suffixed.md"

# MUTATION, the same revert against a corpus with no story citing CAP-1a: the capability
# is exempt from joins (2) and (2a) and the run exits 0 in SILENCE. This is the arm that
# makes "a parser that cannot spell an id does not report a gap" a measurement.
n_mut2 grammar-narrow-silent "grep -xE 'CAP-[0-9]+[a-z]?'" "grep -xE 'CAP-[0-9]+'" \
  'if [ -n "$CAP_DECL_MALFORMED" ]; then' 'if false; then' \
  0 "MUTATION: under the old grammar the UNCITED CAP-1a exits 0 — the gap is not reported" \
  --spec "$R/real-suffixed" --prd "$R/prd-suffixed-nocap1a.md" --story "$R/story-suffixed-no1a.md"

# THE MALFORMED ARM IS WHAT CATCHES EVERY REAL DEFINITION BULLET. Its subject here is an
# emphasis form the `**CAP-<n>**` anchor cannot see at all, so nothing downstream is left
# to catch it: with this arm off the id leaves the capability set in silence.
n_mut decl-malformed-off-emph 'if [ -n "$CAP_DECL_MALFORMED" ]; then' 'if false; then' \
  0 "MUTATION: dropping the declaration assertion lets '- _CAP-1a_' vanish and the run exit 0" \
  --spec "$R/cap-emph-underscore" --prd "$R/prd-ok.md"

n_mut cap-boundary-loose \
  'if ! grep -qE "(^|[^A-Za-z0-9-])$cap([^A-Za-z0-9-]|\$)" <<<"$FR_LINES"; then' \
  'if ! grep -qE "$cap" <<<"$FR_LINES"; then' \
  0 "MUTATION: dropping the id boundary lets CAP-1a's citation stand in for CAP-1" \
  --spec "$R/real-suffixed" --prd "$R/prd-suffixed-only1a.md" --story "$R/story-suffixed.md"

# --- (S) the story citation, reachable by --baseline ---------------------------
n_want 0 "STORY-CAP: a baseline naming story-cap:<file>:<CAP> suppresses the dangling citation" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --story "$R/story-dangling.md" --baseline "$R/baseline-story-cap.txt"
n_says "STORY-CAP: the suppression is REPORTED with the key, not silent" \
  "BASELINED  story-cap:story-dangling.md:CAP-9" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --story "$R/story-dangling.md" --baseline "$R/baseline-story-cap.txt"

# THE KEY THAT MUST NOT WORK. `story:<basename>` is join (3)'s FIELD key. If it also
# reached the citation arm, one baseline line would excuse a missing field and every
# dangling citation in the same file at once.
n_want 1 "STORY-CAP: the COARSE story:<file> key does NOT suppress a dangling citation" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --story "$R/story-dangling.md" --baseline "$R/baseline-story-coarse.txt"
n_says "STORY-CAP: and the coarse entry is reported as NOT REPRODUCING, so it cannot sit there unused" \
  "baseline entry 'story:story-dangling.md' in" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --story "$R/story-dangling.md" --baseline "$R/baseline-story-coarse.txt"

n_mut story-cap-coarse-key \
  'fail_join "story-cap:$(basename "$s"):$r"' 'fail_join "story:$(basename "$s")"' \
  0 "MUTATION: keying the citation arm on the coarse story:<file> lets one line excuse both defects" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --story "$R/story-dangling.md" --baseline "$R/baseline-story-coarse.txt"

# MUTATION: the pre-fix routing, restored -- a bare echo setting rc directly. The arm then
# registers no key at all and the baseline cannot reach it, which is the state the
# reference consumer's own baseline file documents in a comment as unreachable.
n_mut story-cap-unrouted \
  'fail_join "story-cap:$(basename "$s"):$r" "' 'rc=1; echo "FAIL: ' \
  1 "MUTATION: reverting the arm to a bare echo puts it out of --baseline's reach again" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --story "$R/story-dangling.md" --baseline "$R/baseline-story-cap.txt"

# --- (B) the wrapped Binds bullet ----------------------------------------------
n_want 0 "FOLD: a spine whose Binds bullet WRAPS its capability onto a continuation line binds it" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-wrapped.md"
n_says "FOLD: and the run reports a real PASS, not an empty one" \
  "PASS (2 locked requirement(s), 2 capability(ies), 0 story(ies), 0 recorded note(s), 0 baselined)" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-wrapped.md"

# THE OVER-FIRE PIN FOR THE FOLD. `CAP-2` sits in a `- **Prevents:**` bullet, which is
# where the real spine mentions eight capabilities it does not bind. Folding stops at the
# list item; widening the grep would close the join on text that binds nothing.
n_want 1 "FOLD PIN: a CAP named only in a neighbouring Prevents bullet is NOT bound" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-neighbour.md"
n_says "FOLD PIN: and the unbound capability is NAMED" \
  "CAP-2 is defined in SPEC.md but no architecture decision in" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-neighbour.md"

n_mut_says binds-fold-off 'acc = acc " " unindent($0)' 'acc = acc' \
  "CAP-2 is defined in SPEC.md but no architecture decision in" \
  "MUTATION: dropping the accumulation accuses the wrapped spine of not binding CAP-2" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-wrapped.md"

n_mut binds-widen 'BINDS="$(printf ' 'BINDS="$(grep -E CAP- "$SPINE_MD" || true)"; IGNORED1="$(printf ' \
  0 "MUTATION: widening the reader to any CAP-bearing line closes join (2a) on a Prevents bullet" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-neighbour.md"

# --- (N) `- **No-AD:**`, join (2a)'s third disposition -------------------------
n_want 0 "NO-AD: a capability dispositioned '- **No-AD:** CAP-2 — REASON: ...' passes join (2a)" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad.md"
n_says "NO-AD: the disposition is RECORDED as a note naming the capability" \
  "CAP-2 is dispositioned No-AD in" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad.md"
n_says "NO-AD: and it COUNTS in the note total — passed visibly, not in silence" \
  "PASS (2 locked requirement(s), 2 capability(ies), 0 story(ies), 1 recorded note(s), 0 baselined)" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad.md"

# ONE FOLD, TWO READERS. The No-AD bullet wraps for the same reason Binds does, and its
# REASON: lands on the continuation line. This is the arm that makes the shared
# accumulator a requirement rather than a convenience.
n_want 0 "NO-AD: a WRAPPED No-AD bullet whose REASON is on the continuation line is read" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-wrapped.md"
n_says "NO-AD: the wrapped disposition is recorded for the right capability" \
  "CAP-2 is dispositioned No-AD in" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-wrapped.md"

n_want 1 "NO-AD NEAR MISS: a No-AD bullet with no REASON: is an unexplained blank and still FAILS" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-noreason.md"
n_want 1 "NO-AD NEAR MISS: the same decision written as PROSE is not a disposition" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-prose.md"
# THE DISARM SITS ABOVE THE DISPOSITION. A spine of nothing but No-AD bullets declares no
# AD at all; if the disposition reader could satisfy the emptiness test, a file that is
# not a spine would close join (2a) by declining it wholesale.
n_want 2 "NO-AD NEAR MISS: a spine with No-AD bullets and NO Binds still DISARMS at exit 2" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-only.md"

n_mut noad-off 'if [ -n "$NO_AD" ]; then' 'if false; then' \
  1 "MUTATION: dropping the No-AD reader fails the dispositioned capability" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad.md"
# THE REASON REQUIREMENT IS READ TWICE -- once by the hatch that excuses, once by the
# malformed-bullet arm -- and both read the SAME regex, so one substitution reverts both
# layers. Reverting only the hatch leaves the malformed arm still failing the run, which
# would score as a kill the mutation did not earn.
n_mut noad-reason-loose '  r="$(printf '"'"'%s'"'"' "$1" | sed '"'"'s/^[[:space:]]*//; s/[[:space:]]*$//'"'"')"' '  return 0' \
  0 "MUTATION: dropping the reason-carries-text requirement (BOTH readers) excuses an empty REASON:" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-emptyreason.md"
# THE MALFORMED BULLET IS REPORTED AS ITSELF. Here the capability it names IS bound, so
# the ad: arm cannot fire and this is the only arm left that can say anything at all --
# without it an author who wrote a No-AD bullet is told about an id, never about their
# bullet.
n_want 1 "NO-AD FORM: a No-AD bullet with no REASON: is reported even when the capability IS bound" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-malformed-bound.md"
n_says "NO-AD FORM: the malformed bullet is named, with the correct form" \
  "bullet with no 'REASON:' at all" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-malformed-bound.md"
n_says "NO-AD FORM: the no-REASON payload gets the same bullet-level diagnosis, not only the id-level one" \
  "bullet with no 'REASON:' at all" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-noreason.md"
n_want 1 "NO-AD FORM: 'REASON:' present but EMPTY is still an unexplained blank" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-emptyreason.md"
n_says "NO-AD FORM: and the empty reason is diagnosed at the bullet — a present-but-empty REASON is its own state" \
  "whose 'REASON:' has no text" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-emptyreason.md"
n_mut noad-malformed-off \
  '        *REASON:*)' \
  '        *)' \
  0 "MUTATION: dropping the malformed-bullet arm leaves a reasonless bullet reported by nothing" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-malformed-bound.md"

# THE ID SEGMENT. A capability MENTIONED inside the reason is not disposed by it.
n_want 1 "NO-AD SEGMENT: a CAP named only inside the REASON text is NOT dispositioned" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-reasonmention.md"
n_says "NO-AD SEGMENT: the merely-mentioned capability still FAILS join (2a)" \
  "CAP-2 is defined in SPEC.md but no architecture decision in" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-reasonmention.md"
n_says "NO-AD SEGMENT: while the capability in the ID segment IS dispositioned — the arm discriminates" \
  "CAP-1 is dispositioned No-AD in" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-reasonmention.md"
n_mut noad-idsegment-loose \
  'printf '"'"'%s\n'"'"' "${1%%REASON:*}" | grep -ohE "$CAP_GRAMMAR" || true' \
  'printf '"'"'%s\n'"'"' "$1" | grep -ohE "$CAP_GRAMMAR" || true' \
  0 "MUTATION: reading ids from the whole bullet lets the REASON text dispose CAP-2" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-reasonmention.md"

n_mut_says noad-marker-loose 'NO_AD="$(printf ' 'NO_AD="$(grep -E No-AD "$SPINE_MD" || true)"; IGNORED2="$(printf ' \
  "Offending bullet: No-AD:" \
  "MUTATION: dropping the bullet marker picks the PROSE sentence up as a No-AD bullet" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-prose.md"
n_mut noad-fold-off 'acc = acc " " unindent($0)' 'acc = acc' \
  1 "MUTATION: dropping the accumulation loses the WRAPPED No-AD bullet's REASON" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-wrapped.md"

# --- (D) `- (disposition) LR-n NO-CAPABILITY <reason>`, join (1)'s third state --
n_want 0 "DISPOSITION: an LR dispositioned NO-CAPABILITY with a reason passes join (1)" \
  --spec "$R/disp-ok" --prd "$R/prd-ok.md" --story "$R/story-ok.md"
n_says "DISPOSITION: the LR is NAMED in the note, so the decision is visible" \
  "LR-S304-6 is dispositioned NO-CAPABILITY in" \
  --spec "$R/disp-ok" --prd "$R/prd-ok.md" --story "$R/story-ok.md"
n_says "DISPOSITION: and it COUNTS in the note total" \
  "PASS (3 locked requirement(s), 2 capability(ies), 1 story(ies), 1 recorded note(s), 0 baselined)" \
  --spec "$R/disp-ok" --prd "$R/prd-ok.md" --story "$R/story-ok.md"
# The producer's qualifier is decided per append, exactly as for `(capability by ...)`.
n_want 0 "DISPOSITION: '(disposition by lead)' is the SAME entry type and is read" \
  --spec "$R/disp-qualified" --prd "$R/prd-ok.md" --story "$R/story-ok.md"
n_says "DISPOSITION: the qualified entry produces the SAME note — rc=0 alone is what a subject that emits nothing also gives" \
  "LR-S304-6 is dispositioned NO-CAPABILITY in" \
  --spec "$R/disp-qualified" --prd "$R/prd-ok.md" --story "$R/story-ok.md"

n_want 1 "DISPOSITION NEAR MISS: NO-CAPABILITY with no reason after it still FAILS" \
  --spec "$R/disp-noreason" --prd "$R/prd-ok.md" --story "$R/story-ok.md"
n_says "DISPOSITION NEAR MISS: and the FAIL names the LR and the remedy" \
  "LR-S304-6 appears in the memlog but no capability entry cites it" \
  --spec "$R/disp-noreason" --prd "$R/prd-ok.md" --story "$R/story-ok.md"
# THE SHAPE THE REFERENCE CONSUMER HAS ON DISK is `(decision)`, and the accepted type set
# now carries it. This arm is what stops that widening being silently reverted.
n_want 0 "DISPOSITION: '(decision)' — the type the reference consumer actually wrote — is READ" \
  --spec "$R/disp-wrongtype" --prd "$R/prd-ok.md" --story "$R/story-ok.md"
n_says "DISPOSITION: and it produces the note, so the consumer's existing entry parses" \
  "LR-S304-6 is dispositioned NO-CAPABILITY in" \
  --spec "$R/disp-wrongtype" --prd "$R/prd-ok.md" --story "$R/story-ok.md"
n_want 1 "DISPOSITION NEAR MISS: an UNTYPED bullet naming the LR and the token still FAILS" \
  --spec "$R/disp-untyped" --prd "$R/prd-ok.md" --story "$R/story-ok.md"
n_says "DISPOSITION NEAR MISS: untyped prose gets the ordinary join (1) FAIL" \
  "LR-S304-6 appears in the memlog but no capability entry cites it" \
  --spec "$R/disp-untyped" --prd "$R/prd-ok.md" --story "$R/story-ok.md"

n_mut disp-off 'if [ -n "$DISP_ENTRIES" ] && printf' 'if false && printf' \
  1 "MUTATION: dropping the hatch fails the dispositioned LR — the arm has a subject" \
  --spec "$R/disp-ok" --prd "$R/prd-ok.md" --story "$R/story-ok.md"
# --- (N2) the No-AD that outlived its cause -----------------------------------
# The hatch is consulted only where it EXCUSES, so until this arm the ids a No-AD bullet
# names were validated nowhere. Both states below pass in silence without it.
n_want 1 "NO-AD LIFETIME: a capability that is dispositioned No-AD AND bound by an AD FAILS" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-stale.md"
n_says "NO-AD LIFETIME: the contradiction names the id and the one-line remedy" \
  "disposition for 'CAP-2' AND an architecture decision that binds it" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-stale.md"
n_want 1 "NO-AD LIFETIME: a disposition for an id SPEC.md does not define FAILS" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-unknown.md"
n_says "NO-AD LIFETIME: the undefined id is NAMED" \
  "disposition for 'CAP-9', which" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-unknown.md"
# THE CASE THE PER-CAPABILITY LOOP CANNOT REACH. `Binds: all` short-circuits that loop
# entirely, so a No-AD sitting beside a spine-wide AD is contradicted by a binding no
# per-capability search would ever compare it against.
n_want 1 "NO-AD LIFETIME: a No-AD beside a spine-wide 'Binds: all' FAILS, though the cap loop never runs" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-bindsall.md"
n_says "NO-AD LIFETIME: and it is reported as the same contradiction" \
  "disposition for 'CAP-2' AND an architecture decision that binds it" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-bindsall.md"

n_mut noad-unknown-off 'if ! grep -qx -- "$nid" <<<"$CAPS"; then' 'if false; then' \
  0 "MUTATION: dropping the defined-id check lets a No-AD for an undefined id pass" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-unknown.md"
n_mut noad-contradiction-off \
  'elif [ "$binds_all" -eq 1 ] || grep -qE "(^|[^A-Za-z0-9-])$nid([^A-Za-z0-9-]|\$)" <<<"$BINDS"; then' \
  'elif false; then' \
  0 "MUTATION: dropping the contradiction check lets a stale No-AD sit beside its own AD" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-stale.md"
n_mut noad-bindsall-blind '[ "$binds_all" -eq 1 ] || grep -qE' '[ 0 -eq 1 ] || grep -qE' \
  0 "MUTATION: dropping the binds_all disjunct makes the spine-wide AD invisible to this arm" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-bindsall.md"

# --- (R) the residue scan's POPULATION: definition bullets, in the kernel only --
# THE SAME TOKEN, EVERYWHERE BUT THE KERNEL. Without this pair the scoping claim is
# untested in the direction that costs a consumer its gate: a `CAP-1ab` in a transcript,
# a PRD note, a story body and a Prevents bullet, all at once.
n_want 0 "RESIDUE SCOPE: a residue-shaped token in the memlog, PRD, story and spine does NOT disarm" \
  --spec "$R/residue-elsewhere" --prd "$R/prd-residue-token.md" --story "$R/story-residue-token.md" --spine "$R/spine-residue-token.md"
n_says "RESIDUE SCOPE: and the run is a real PASS, not an empty one" \
  "PASS (2 locked requirement(s), 2 capability(ies), 1 story(ies), 1 recorded note(s), 0 baselined)" \
  --spec "$R/residue-elsewhere" --prd "$R/prd-residue-token.md" --story "$R/story-residue-token.md" --spine "$R/spine-residue-token.md"

# `_` AND `-` ARE WORD CHARACTERS, so `\bCAP-[0-9]+[a-z]?\b` matches neither id in full.
# A residue class narrower than the complement of `\b` extracts the well-formed `CAP-1`
# out of each and silently defines a DIFFERENT capability than the one written.
n_want 2 "RESIDUE CLASS: 'CAP-1_a' as a DEFINITION disarms — the class is the complement of \\b" \
  --spec "$R/cap-residue-underscore" --prd "$R/prd-ok.md"
n_says "RESIDUE CLASS: the underscore id is NAMED, not silently reduced to CAP-1" \
  "CAP-1_a" \
  --spec "$R/cap-residue-underscore" --prd "$R/prd-ok.md"
n_want 2 "RESIDUE CLASS: 'CAP-1-x' as a DEFINITION disarms" \
  --spec "$R/cap-residue-hyphen" --prd "$R/prd-ok.md"
n_says "RESIDUE CLASS: the hyphenated id is NAMED" \
  "CAP-1-x" \
  --spec "$R/cap-residue-hyphen" --prd "$R/prd-ok.md"

# A KERNEL DOCUMENTING ITS OWN ID GRAMMAR. Disarming here blocks the gate on correct
# content, with "delete the documentation" as the only remedy.
n_want 0 "FENCE: a definition-shaped line inside a fenced example block is an illustration, not a declaration" \
  --spec "$R/cap-fenced" --prd "$R/prd-ok.md" --story "$R/story-ok.md"
n_says "FENCE: and the fenced CAP ids are not counted as capabilities either" \
  "PASS (2 locked requirement(s), 2 capability(ies), 1 story(ies), 0 recorded note(s), 0 baselined)" \
  --spec "$R/cap-fenced" --prd "$R/prd-ok.md" --story "$R/story-ok.md"

# MENTIONS BUT DEFINES NONE is not the same state as ZERO CAPABILITIES, and the two must
# not print the same sentence -- one is a malformed kernel, the other a real spec.
n_want 2 "DEFINITION GRAMMAR: a kernel that MENTIONS ids but declares none in the bullet shape disarms" \
  --spec "$R/cap-mentions-none" --prd "$R/prd-ok.md"
n_says "DEFINITION GRAMMAR: and it is told which of the two states it is in" \
  "mentions CAP-<n> identifiers but DEFINES none" \
  --spec "$R/cap-mentions-none" --prd "$R/prd-ok.md"

n_want 0 "DEFINITION GRAMMAR: a prose MENTION of CAP-3 does not define it" \
  --spec "$R/cap-prose-mention" --prd "$R/prd-ok.md" --story "$R/story-ok.md"
n_says "DEFINITION GRAMMAR: the mentioned id is not required of any FR or AD" \
  "PASS (2 locked requirement(s), 2 capability(ies), 1 story(ies), 0 recorded note(s), 0 baselined)" \
  --spec "$R/cap-prose-mention" --prd "$R/prd-ok.md" --story "$R/story-ok.md"

# TWO PARTITIONS COVER THIS ID DELIBERATELY, and that overlap is the fix for the prefix
# shadow: the malformed-definition set catches it as a bad DEFINITION, and the
# looks-declarative join catches it as a declaration that never parsed. Reverting either
# alone leaves the other still catching it, so only reverting BOTH shows what the pair is
# worth -- a silent drop, and a story citing the id accused of citing one that does not exist.
n_mut decl-malformed-off-underscore 'if [ -n "$CAP_DECL_MALFORMED" ]; then' 'if false; then' \
  0 "MUTATION: dropping the declaration assertion lets CAP-1_a vanish and the run exit 0" \
  --spec "$R/cap-residue-underscore" --prd "$R/prd-ok.md"
n_mut fenced-strip-off 'KERNEL_PROSE="$(awk ' 'KERNEL_PROSE="$(cat "$KERNEL" || true)"; IGNORED4="$(awk ' \
  2 "MUTATION: not stripping fences disarms the gate on a kernel that documents its own grammar" \
  --spec "$R/cap-fenced" --prd "$R/prd-ok.md" --story "$R/story-ok.md"
# Both states exit 2, so rc cannot tell them apart -- the SENTENCE is the assertion.
n_mut_says mentions-none-collapse 'if [ -z "$CAPS" ] && grep -qE' 'if false && grep -qE' \
  "defines ZERO capabilities" \
  "MUTATION: collapsing the two empty-set states tells a malformed kernel it has no capabilities" \
  --spec "$R/cap-mentions-none" --prd "$R/prd-ok.md"

# --- (A) `all` must be the WHOLE value, on the MARKER line ---------------------
# The single most dangerous string in the file: it switches join (2a) off for every
# capability at once and prints identically to a spine that closes the join for real.
# This continuation says the AD binds NOTHING.
n_want 1 "BINDS-ALL: a continuation line beginning 'all ...' does NOT switch join (2a) off" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-binds-all-prose.md"
n_says "BINDS-ALL: the capabilities are still checked individually and still FAIL" \
  "CAP-1 is defined in SPEC.md but no architecture decision in" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-binds-all-prose.md"
n_says "BINDS-ALL: a real spine-wide AD says so out loud, with the count it is closing" \
  "declares '**Binds:** all', so join (2a) closes spine-wide for all 2 capability(ies)" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-all.md"
n_mut binds-all-folded \
  "if grep -qiE '^[[:space:]]*[-*][[:space:]]*\\*\\*Binds:\\*\\*[[:space:]]*all[[:space:]]*\\.?[[:space:]]*\$' \"\$SPINE_MD\"; then" \
  "if grep -qiE '\\*\\*Binds:\\*\\*[[:space:]]*all' <<<\"\$BINDS\"; then" \
  0 "MUTATION: reading 'all' off the FOLDED bullet lets prose switch join (2a) off entirely" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-binds-all-prose.md"

# --- (N3) the placeholder, the neighbouring bullet, and bound-wins -------------
# Both hatches print `<why>` / `<reason>` into their own FAIL messages. Accepting that
# literal back is a predicate satisfied by the instruction that produced it.
n_want 1 "PLACEHOLDER: 'REASON: <why>' -- the string this check's own message prints -- is not a reason" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-placeholder.md"
n_says "PLACEHOLDER: and the bullet is diagnosed as carrying no reason text" \
  "whose 'REASON:' has no text" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-placeholder.md"
n_mut noad-placeholder-loose '  r="$(printf '"'"'%s'"'"' "$1" | sed '"'"'s/^[[:space:]]*//; s/[[:space:]]*$//'"'"')"' '  return 0' \
  0 "MUTATION: accepting any reason text lets the placeholder excuse the capability" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-placeholder.md"

# THE REAL DEFERRED BULLET, under its own bold key. This is the form the consumer's spine
# has today and the narrowness arm most likely to rot: the disposition is only readable
# from the bullet the reader is anchored on.
n_want 1 "NARROWNESS: the same decision under a DIFFERENT bold key is not a No-AD bullet" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-otherbullet.md"
n_says "NARROWNESS: the capability it names still FAILS join (2a)" \
  "CAP-2 is defined in SPEC.md but no architecture decision in" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-otherbullet.md"

# BOUND WINS, AND NO NOTE IS EMITTED. Ordering, not a predicate: the `continue` for a
# bound capability sits above the hatch. A note here would say the spine dispositioned a
# capability it in fact binds -- the contradiction reported one arm down, restated as an
# excuse. Absence-shaped, so the mutant below is what proves it discriminates.
NEW_ARMS=$((NEW_ARMS+1))
BW_OUT="$(bash "$V" --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-stale.md" 2>&1)"
if grep -qF "CAP-2 is dispositioned No-AD in" <<<"$BW_OUT"; then
  bad "BOUND WINS: a BOUND capability was also reported as dispositioned No-AD — the hatch runs above the bound check"
elif ! grep -qF "disposition for 'CAP-2' AND an architecture decision that binds it" <<<"$BW_OUT"; then
  bad "BOUND WINS: the contradiction FAIL is missing — this arm's absence half would pass against a subject that emits nothing"
else
  ok "BOUND WINS: a bound capability gets no No-AD note, and DOES get the contradiction FAIL"
fi
n_mut_says bound-wins-off 'if grep -qE "(^|[^A-Za-z0-9-])$cap([^A-Za-z0-9-]|\$)" <<<"$BINDS"; then' 'if false; then' \
  "CAP-2 is dispositioned No-AD in" \
  "MUTATION: dropping the bound check makes the hatch note a capability an AD binds" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-stale.md"

# --- (D2) the memlog hatch: the SUBJECT anchor and the placeholder -------------
n_want 1 "PLACEHOLDER: 'NO-CAPABILITY <reason>' is the message's own placeholder, not a reason" \
  --spec "$R/disp-placeholder" --prd "$R/prd-ok.md" --story "$R/story-ok.md"
n_says "PLACEHOLDER: the LR still gets the ordinary join (1) FAIL" \
  "LR-S304-6 appears in the memlog but no capability entry cites it" \
  --spec "$R/disp-placeholder" --prd "$R/prd-ok.md" --story "$R/story-ok.md"
n_mut disp-placeholder-loose '  r="$(printf '"'"'%s'"'"' "$1" | sed '"'"'s/^[[:space:]]*//; s/[[:space:]]*$//'"'"')"' '  return 0' \
  0 "MUTATION: accepting any reason text lets the placeholder excuse the requirement" \
  --spec "$R/disp-placeholder" --prd "$R/prd-ok.md" --story "$R/story-ok.md"

# THE LR MUST BE THE SUBJECT. One entry, two ids, neither dispositioned NO-CAPABILITY:
# LR-S304-6 is SUPERSEDED and LR-S304-9 is merely named as its superseder. An unanchored
# pair of greps -- "a line naming this LR", then "a line containing the token" -- excuses
# BOTH, and neither of them is what the entry says.
n_want 1 "SUBJECT ANCHOR: an entry naming the token but dispositioning the LR as something else excuses neither id" \
  --spec "$R/disp-notsubject" --prd "$R/prd-ok.md" --story "$R/story-ok.md"
n_says "SUBJECT ANCHOR: the dispositioned-as-something-else id still FAILS" \
  "LR-S304-6 appears in the memlog but no capability entry cites it" \
  --spec "$R/disp-notsubject" --prd "$R/prd-ok.md" --story "$R/story-ok.md"
n_says "SUBJECT ANCHOR: and so does the id merely named as its superseder" \
  "LR-S304-9 appears in the memlog but no capability entry cites it" \
  --spec "$R/disp-notsubject" --prd "$R/prd-ok.md" --story "$R/story-ok.md"
n_mut disp-anchor-loose '$lr[[:space:]]+NO-CAPABILITY' 'NO-CAPABILITY' \
  0 "MUTATION: unanchoring the token from the id excuses BOTH ids in that entry" \
  --spec "$R/disp-notsubject" --prd "$R/prd-ok.md" --story "$R/story-ok.md"

# TWO LAYERS DECIDE THE BARE TOKEN -- the guard's own "and something after it", and
# `is_reason`. Reverting either alone leaves the other still failing the run, which would
# score as a kill the mutation did not earn.
n_mut2 disp-noreason-loose \
  'NO-CAPABILITY[[:space:]]+[^[:space:]]"' 'NO-CAPABILITY"' \
  '  r="$(printf '"'"'%s'"'"' "$1" | sed '"'"'s/^[[:space:]]*//; s/[[:space:]]*$//'"'"')"' '  return 0' \
  0 "MUTATION: dropping BOTH reason layers accepts a bare NO-CAPABILITY" \
  --spec "$R/disp-noreason" --prd "$R/prd-ok.md" --story "$R/story-ok.md"

# --- (R2) definitions the bold anchor cannot see, and the delimiter that bounds it
n_want 2 "EMPHASIS: '- _CAP-1a_' is a definition ATTEMPT the bold anchor cannot see, and it DISARMS" \
  --spec "$R/cap-emph-underscore" --prd "$R/prd-ok.md"
n_says "EMPHASIS: the offending declaration LINE is echoed, so the author sees which bullet" \
  "- _CAP-1a_ intent" \
  --spec "$R/cap-emph-underscore" --prd "$R/prd-ok.md"
n_want 2 "EMPHASIS: a code-marker definition '- \`CAP-1a\`' DISARMS too" \
  --spec "$R/cap-emph-code" --prd "$R/prd-ok.md"

# THE FALSE-POSITIVE PIN. Measured against the five real kernels with the subject's own
# expression: 0 findings each, against 10/10/14/11/18 canonical definitions. Without the
# emphasis-delimiter requirement this bullet shape is a finding, and the real kernels
# carry 18 of them.
n_want 0 "EMPHASIS PIN: a prose bullet that merely OPENS with a capability id is not a definition attempt" \
  --spec "$R/cap-prose-bullet" --prd "$R/prd-ok.md" --story "$R/story-ok.md"
n_says "EMPHASIS PIN: and the mentioned id does not enter the capability set" \
  "PASS (2 locked requirement(s), 2 capability(ies), 1 story(ies), 0 recorded note(s), 0 baselined)" \
  --spec "$R/cap-prose-bullet" --prd "$R/prd-ok.md" --story "$R/story-ok.md"
# `decl-opener-loose` RETIRED HERE, deliberately and with its reason. It widened the
# opener test so an ordinary prose bullet would be read as a declaration. Measured at this
# pin: that bullet carries NO emphasis marker at all, so `decl_run`'s while-match loop
# never executes and the widened test is unreachable -- three separate layer combinations
# left it at rc=0. That is not a mutant that survived; it is an arm whose subject stopped
# being constructible, and the honest instrument is the discrimination arm below.
n_discrim "EMPHASIS PIN DISCRIMINATES: the prose bullet is quiet while a two-id run in the SAME container DISARMS" \
  "$R/cap-prose-bullet" "$R/decl-bullet" "$R/prd-ok.md"

# --- (D3) the accepted TYPE SET, and its boundary -----------------------------
n_want 1 "TYPE SET: a '(note)' entry carrying the anchored token is NOT a disposition" \
  --spec "$R/disp-notype" --prd "$R/prd-ok.md" --story "$R/story-ok.md"
n_says "TYPE SET: the untyped-for-this-purpose entry produces the ordinary join (1) FAIL" \
  "LR-S304-6 appears in the memlog but no capability entry cites it" \
  --spec "$R/disp-notype" --prd "$R/prd-ok.md" --story "$R/story-ok.md"

# --- (N4) the id segment, and a marker a Binds bullet ate ---------------------
n_want 1 "ID SEGMENT: a parenthetical naming another capability makes the segment a mixed one, and it is REFUSED" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-mixedseg.md"
n_says "ID SEGMENT: the diagnosis says where commentary belongs" \
  "id segment is not an id list" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-mixedseg.md"
# The only new hard edge in the hatch, and the code says it is baselineable. An arm that
# never exercises the key cannot tell a routed finding from an unroutable one.
n_want 0 "ID SEGMENT: the no-ad-form: key is reachable by --baseline, as its own comment claims" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-mixedseg.md" --baseline "$R/baseline-noad-form.txt"
n_says "ID SEGMENT: and the suppression names the key" \
  "BASELINED  no-ad-form:spine-noad-mixedseg.md" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-mixedseg.md" --baseline "$R/baseline-noad-form.txt"
# THE WRONG DIRECTION IS THE ONE THAT COSTS A CONSUMER ITS GATE. With both segment readers
# off, `CAP-1` -- named only inside the parenthetical -- is treated as DISPOSED and then
# reported as contradicting the AD that binds it: a hard, unbaselineable FAIL on a spine
# that is correct. That is the failure the partition exists to make unconstructible, so it
# is what this mutant asserts rather than a bare rc.
n_mut2_says noad-segment-off \
  'elif ! no_ad_id_segment_ok "$nad_line"; then' 'elif false; then' \
  '  no_ad_id_segment_ok "$1" || return' '  :' \
  "disposition for 'CAP-1' AND an architecture decision that binds it" \
  "MUTATION: dropping BOTH segment readers makes a merely-mentioned CAP-1 contradict its own AD" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-mixedseg.md"

# A MARKER THAT IS NOT AT BULLET START is folded into the Binds bullet, and every
# capability it names then reads as BOUND -- silence from a sentence that says the
# opposite. rc alone cannot see it: with the arm off the run is a clean PASS.
n_want 1 "EATEN MARKER: a '**No-AD:**' inside a Binds bullet is reported, not silently read as a binding" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-eaten.md"
n_says "EATEN MARKER: the diagnosis says the disposition must start its own bullet" \
  "names a capability AFTER a second '**<Key>:**' marker inside a '- **Binds:**' bullet" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-eaten.md"
# TWO LAYERS: the arm that REPORTS the eaten marker, and the truncation that stops the
# capabilities after it being counted as bound. Reverting the report alone leaves the
# truncation still failing them, which would score as a kill the mutation did not earn.
n_mut2 noad-eaten-off \
  'if [ -n "$BINDS_EATEN" ]; then' 'if false; then' \
  '      if (match(rest, /\*\*[A-Za-z][A-Za-z-]*:\*\*/)) { print substr($0, 1, h + 9 + RSTART - 1); next }' '      if (0) { next }' \
  0 "MUTATION: dropping BOTH the report and the truncation makes CAP-2 read as BOUND, silently" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-eaten.md"
# THE NARROWING PIN. A second marker with no id after it loses nothing to the truncation,
# and the wrapped form of that sentence is what the fold exists to support.
n_want 0 "EATEN MARKER PIN: a second '**<Key>:**' marker with NO capability after it does not fire" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-marker-noid.md"
n_says "EATEN MARKER PIN: and both capabilities still read as bound" \
  "PASS (2 locked requirement(s), 2 capability(ies), 0 story(ies), 0 recorded note(s), 0 baselined)" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-marker-noid.md"
n_says "EATEN MARKER: the capabilities after the eaten marker are NOT counted as bound" \
  "CAP-2 is defined in SPEC.md but no architecture decision in" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-eaten.md"

# --- (R3) declarations the definition reader cannot see -----------------------
# Each shape below is a real markdown declaration the `- **CAP-<n>**` reader does not
# parse. Narrowing the population is how the silence came back once already, so the two
# sets are derived separately and their DISAGREEMENT is the finding.
n_want 2 "LOOKS-DECLARATIVE: a heading declaration '### CAP-3' disarms rather than vanishing" \
  --spec "$R/cap-heading" --prd "$R/prd-ok.md"
n_says "LOOKS-DECLARATIVE: the heading-declared id is echoed" \
  "### CAP-3" \
  --spec "$R/cap-heading" --prd "$R/prd-ok.md"

# THE SHAPE THE JOIN STRUCTURALLY CANNOT SEE IF ITS TWO SIDES SHARE A GRAMMAR. The
# well-formed PREFIX of `CAP-1ab` is `CAP-1a`, and here that prefix is itself defined --
# so a looks-declarative probe extracting with the well-formed grammar cancels against
# CAPS and the malformed definition is dropped in silence. Measured as a live regression
# once; this arm is what stops it returning.
n_want 2 "PREFIX SHADOW: a malformed definition whose well-formed PREFIX is also defined still disarms" \
  --spec "$R/cap-prefix-defined" --prd "$R/prd-prefix-defined.md"
n_says "PREFIX SHADOW: and it is the malformed id that is named, not its prefix" \
  "CAP-1ab" \
  --spec "$R/cap-prefix-defined" --prd "$R/prd-prefix-defined.md"

# --- (T) a definition bullet that declares TWO capabilities --------------------
# THE SHAPE THE CROSS-CHECK CANNOT EXPRESS. It joins two ID sets; this bullet's defect is
# that one definition STRING holds two ids, and `CAP-2` — sitting mid-run with no emphasis
# marker before it — never reaches the looks-declarative side at all. Nothing disagrees,
# so nothing fires. The definition-shape assertion is the only guard whose subject is the
# string rather than the ids.
n_want 2 "TWO-ID DEFINITION: a bullet declaring two capabilities DISARMS rather than crediting one" \
  --spec "$R/cap-twoid" --prd "$R/prd-ok.md"
n_says "TWO-ID DEFINITION: the malformed declaration STRING is echoed, not just an id" \
  "**CAP-1 and CAP-2 together**" \
  --spec "$R/cap-twoid" --prd "$R/prd-ok.md"
# WHICH GUARD OWNS IT. Same bullet, leading id changed to one nothing else defines: now the
# CROSS-CHECK sees it, because `CAP-9` is not cancelled on the parsed side. The pair is
# what shows the two guards cover different populations rather than one being redundant.
n_want 2 "TWO-ID DEFINITION: an undefined leading id in the same bullet shape also DISARMS" \
  --spec "$R/cap-twoid-undefined" --prd "$R/prd-ok.md"
# WHICH GUARD OWNS WHICH. The definition-shape assertion runs first and claims both, so the
# boundary is only visible with it disarmed: then the CROSS-CHECK still catches the
# undefined leading id, and (the mutant above) does NOT catch the defined one. That pair is
# the measurement behind keeping both guards.
n_mut_says twoid-def-off-undefined 'if [ -n "$CAP_DECL_MALFORMED" ]; then' 'if false; then' \
  "PASS (2 locked requirement(s), 1 capability(ies)" \
  "MUTATION: with the assertion off the undefined-leading-id variant ALSO drops its second id in silence" \
  --spec "$R/cap-twoid-undefined" --prd "$R/prd-ok.md"
# rc alone cannot see this one: with the assertion off the run is a clean PASS. The
# CAPABILITY COUNT is the whole finding -- two declared, one seen.
n_mut_says twoid-def-off 'if [ -n "$CAP_DECL_MALFORMED" ]; then' 'if false; then' \
  "PASS (2 locked requirement(s), 1 capability(ies)" \
  "MUTATION: dropping the definition-shape assertion silently credits two capabilities to one" \
  --spec "$R/cap-twoid" --prd "$R/prd-ok.md"

# --- (S) the No-AD staleness key is baselineable -------------------------------
# The comment above that arm says so, and a comment is not a mechanism. This is the only
# thing that can tell a routed finding from an unroutable one.
n_want 0 "NO-AD STALE: the no-ad-stale:<CAP-id> key is reachable by --baseline" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-stale.md" --baseline "$R/baseline-noad-stale.txt"
n_says "NO-AD STALE: and the suppression names the per-capability key, not a file-level one" \
  "BASELINED  no-ad-stale:CAP-2" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-stale.md" --baseline "$R/baseline-noad-stale.txt"

# --- (I) is_reason, the whole accept/reject matrix ------------------------------
# THE REJECTS ARE THE STRINGS THIS CHECK'S OWN MESSAGES TELL AUTHORS TO WRITE, plus the
# words an author writes when they mean to come back. The ACCEPTS are the reason that
# fooled the first version of the wrapper test: a real justification written entirely
# inside brackets or emphasis. Both halves are needed — a predicate that rejects
# everything passes the reject rows and fails no gate until it blocks a correct spine.
n_want 1 "REASON REJECT: the bare placeholder '<why>'" --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/reason-reject-1.md"
n_want 1 "REASON REJECT: the placeholder in a code span" --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/reason-reject-2.md"
n_want 1 "REASON REJECT: the placeholder in parentheses — the test runs on the CONTENT" --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/reason-reject-3.md"
n_want 1 "REASON REJECT: '[reason]' reduces to a placeholder WORD once brackets are stripped" --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/reason-reject-4.md"
n_want 1 "REASON REJECT: '{why}' likewise" --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/reason-reject-5.md"
n_want 1 "REASON REJECT: '(why)' likewise" --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/reason-reject-6.md"
n_want 1 "REASON REJECT: the bare word 'reason'" --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/reason-reject-7.md"
n_want 1 "REASON REJECT: TODO" --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/reason-reject-8.md"
n_want 1 "REASON REJECT: TBD" --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/reason-reject-9.md"
n_want 1 "REASON REJECT: n/a" --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/reason-reject-10.md"
n_want 0 "REASON ACCEPT: a real justification written entirely in parentheses" --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/reason-accept-1.md"
n_says "REASON ACCEPT: and it is recorded as a note rather than passed in silence" \
  "CAP-2 is dispositioned No-AD in" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/reason-accept-1.md"
n_want 0 "REASON ACCEPT: a bracketed citation followed by prose" --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/reason-accept-2.md"
n_says "REASON ACCEPT: the bracketed-citation reason is RECORDED, not passed in silence" \
  "CAP-2 is dispositioned No-AD in" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/reason-accept-2.md"

n_want 0 "REASON ACCEPT: emphasis around a real reference" --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/reason-accept-3.md"
n_says "REASON ACCEPT: the emphasised reason is RECORDED" \
  "CAP-2 is dispositioned No-AD in" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/reason-accept-3.md"

n_want 0 "REASON ACCEPT: a sentence that merely CONTAINS the word 'reason'" --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/reason-accept-4.md"
n_says "REASON ACCEPT: the word list matches the WHOLE trimmed string, so a sentence containing it is RECORDED" \
  "CAP-2 is dispositioned No-AD in" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/reason-accept-4.md"


# THE STRIP IS LOAD-BEARING IN THE ACCEPT DIRECTION, which is the one a reject-everything
# predicate passes. Remove it and a real justification written in parentheses is a hard
# failure on a correct spine.
n_mut reason-strip-off \
  "      '('*')'|'['*']'|'{'*'}')" "      'zzz')" \
  0 "MUTATION: not stripping brackets lets '(<why>)' through — the placeholder test runs on the CONTENT" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/reason-reject-3.md"
n_mut reason-wordlist-off \
  "    reason|why|rationale|explanation|justification|reasons) return 1 ;;" "    zzzz) return 1 ;;" \
  0 "MUTATION: dropping the placeholder-word list accepts a bare '[reason]'" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/reason-reject-4.md"

# --- (E) the eaten-marker matrix ----------------------------------------------
# FIRES ON AN ACTUAL ID LOSS, NOT ON THE PRESENCE OF A MARKER. The two no-loss rows below
# were hard failures until this was narrowed, and the first of them is ordinary writing.
n_want 1 "EATEN MARKER: a parenthetical marker BEFORE a later id truncates that id away" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/binds-loss-parenthetical.md"
n_says "EATEN MARKER: the loss is reported against the bullet" \
  "names a capability AFTER a second '**<Key>:**' marker" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/binds-loss-parenthetical.md"
n_want 1 "EATEN MARKER: a foreign key marker BETWEEN two ids truncates the second" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/binds-loss-midlist.md"
n_want 0 "EATEN MARKER PIN: a trailing marker with every id BEFORE it loses nothing and must not fire" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/binds-noloss-trailing.md"
n_says "EATEN MARKER PIN: and both capabilities still read as bound" \
  "PASS (2 locked requirement(s), 2 capability(ies), 0 story(ies), 0 recorded note(s), 0 baselined)" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/binds-noloss-trailing.md"
n_want 0 "EATEN MARKER PIN: '**AD-7:**' carries a digit and is not a key marker at all" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/binds-noloss-digitkey.md"
n_says "EATEN MARKER PIN: and both capabilities still read as bound past the digit-bearing key" \
  "PASS (2 locked requirement(s), 2 capability(ies), 0 story(ies), 0 recorded note(s), 0 baselined)" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/binds-noloss-digitkey.md"


# --- (C) one malformed run, six containers ------------------------------------
# THE CONTROL RUNS FIRST. A clean second declaration in the identical file shape must
# still be two capabilities and a PASS -- otherwise every DISARM below is the file shape
# rather than the malformed run.
n_want 0 "CONTAINER CONTROL: a clean second declaration in the same file shape passes" \
  --spec "$R/decl-clean" --prd "$R/prd-ok.md"
n_says "CONTAINER CONTROL: and BOTH capabilities are in the set" \
  "PASS (2 locked requirement(s), 2 capability(ies), 0 story(ies), 0 recorded note(s), 0 baselined)" \
  --spec "$R/decl-clean" --prd "$R/prd-ok.md"

# SIX RECONSTRUCTIONS, ONE CAUSE. Each is the SAME two-id run; only the container differs.
# The predicate is keyed on the emphasis run, so all six take the same exit.
n_want 2 "CONTAINER: a two-id run in a dash bullet DISARMS" \
  --spec "$R/decl-bullet" --prd "$R/prd-ok.md"
n_want 2 "CONTAINER: in a NUMBERED item" \
  --spec "$R/decl-numbered" --prd "$R/prd-ok.md"
n_want 2 "CONTAINER: in a TABLE row" \
  --spec "$R/decl-table" --prd "$R/prd-ok.md"
n_want 2 "CONTAINER: in a BLOCKQUOTE bullet" \
  --spec "$R/decl-quote" --prd "$R/prd-ok.md"
n_want 2 "CONTAINER: in a HEADING" \
  --spec "$R/decl-heading" --prd "$R/prd-ok.md"
n_want 2 "CONTAINER: as a plain PARAGRAPH" \
  --spec "$R/decl-para" --prd "$R/prd-ok.md"
n_want 2 "CONTAINER: with an inner emphasis marker inside the bold run" \
  --spec "$R/decl-innerstar" --prd "$R/prd-ok.md"
n_says "CONTAINER: the offending RUN is echoed, so the author sees which text is wrong" \
  "**CAP-1 and CAP-2 together**" \
  --spec "$R/decl-table" --prd "$R/prd-ok.md"

# THE MUTANT USES A NON-BULLET CONTAINER ON PURPOSE. With the declaration assertion off,
# the cross-check cannot reach this: `CAP-1` is cancelled by the clean declaration and
# `CAP-2` sits mid-run with no marker before it, so it is absent from BOTH sides of the
# join. rc stays 0 and the only trace is the capability count.
n_mut_says decl-malformed-off 'if [ -n "$CAP_DECL_MALFORMED" ]; then' 'if false; then' \
  "PASS (2 locked requirement(s), 1 capability(ies)" \
  "MUTATION: with the declaration assertion off, a table-row two-id run drops CAP-2 in silence" \
  --spec "$R/decl-table" --prd "$R/prd-ok.md"

# THE NEGATIVE CONTROL, AND WHAT IT IS ACTUALLY A CONTROL FOR. A bolded clause that
# MENTIONS two ids opens with a backtick, not an id, so the declaration arm is right to
# stay quiet. The FILE is quiet only because those ids are declared elsewhere -- the
# cross-check reads a backticked id as declarative. Both halves are armed because a
# single-sided control here would credit the declaration arm with a quietness the
# surrounding kernel is providing.
n_want 0 "CLAUSE PIN: a bolded clause MENTIONING ids it does not declare is not a declaration" \
  --spec "$R/decl-clause-defined" --prd "$R/prd-decl-clause.md"
n_says "CLAUSE PIN: and all three declared capabilities are in the set" \
  "PASS (1 locked requirement(s), 3 capability(ies), 0 story(ies), 0 recorded note(s), 0 baselined)" \
  --spec "$R/decl-clause-defined" --prd "$R/prd-decl-clause.md"
# THE rc=2 HALF IS RETIRED, and the reason is a rule change rather than a regression.
# It fired because ANY run opening with a CAP id counted as a declaration. DEFECT 33
# overturned that -- a capability whose intent cites a neighbouring spec was hard-DISARMING
# -- so only an item FIRST run can declare and everything after it is prose. This clause
# opens `**` then a backtick, so the item declares nothing and the ids inside it are prose
# mentions, which is exactly what DEFECT 33 says must not fire.
#
# THE COST IS NAMED RATHER THAN HIDDEN: a genuinely undeclared id that appears ONLY inside
# prose now goes unreported. That is the right trade -- the alternative was measured at 18
# false positives across five real kernels, four of which it would have DISARMED -- but it
# is a real hole and this arm is where a future reader will find it stated.
n_want 0 "CLAUSE PIN: with those ids UNDECLARED the clause is STILL quiet — prose beats declaration after the first run" \
  --spec "$R/decl-clause-undefined" --prd "$R/prd-decl-clause.md"
n_says "CLAUSE PIN: and the kernel keeps exactly the ONE capability it really declares" \
  "PASS (1 locked requirement(s), 1 capability(ies), 0 story(ies), 0 recorded note(s), 0 baselined)" \
  --spec "$R/decl-clause-undefined" --prd "$R/prd-decl-clause.md"

# --- (U) an UNCLOSED emphasis run, and a correct kernel that documents itself -------
# THE EIGHTH RECONSTRUCTION. An unclosed `**` is an ordinary hand-edit typo, and the
# definition reader needs a CLOSING marker — so the run is captured by nothing and every id
# on the line leaves the set in silence. Three openers, because the opener is the key.
n_want 2 "UNCLOSED: a bold run that never closes DISARMS rather than dropping its ids" \
  --spec "$R/unclosed-bold" --prd "$R/prd-unclosed.md"
n_says "UNCLOSED: the offending line is echoed" \
  "- **CAP-2 and CAP-9 together intent" \
  --spec "$R/unclosed-bold" --prd "$R/prd-unclosed.md"
n_want 2 "UNCLOSED: an unclosed single-asterisk run too" \
  --spec "$R/unclosed-em" --prd "$R/prd-unclosed.md"
n_want 2 "UNCLOSED: an unclosed code run too" \
  --spec "$R/unclosed-code" --prd "$R/prd-unclosed.md"

# THE DISCRIMINATING CONTROL, and the one that decides whether the arm keys on the RUN or
# on the LOSS. Same unclosed line, every id it names declared properly above it: nothing is
# dropped, so nothing may fire.
n_want 0 "UNCLOSED PIN: the same unclosed line with every id DECLARED elsewhere stays quiet" \
  --spec "$R/unclosed-declared" --prd "$R/prd-unclosed.md"
n_says "UNCLOSED PIN: and all three capabilities are in the set" \
  "PASS (2 locked requirement(s), 3 capability(ies), 0 story(ies), 0 recorded note(s), 0 baselined)" \
  --spec "$R/unclosed-declared" --prd "$R/prd-unclosed.md"

# THE POSITIVE CONTROL KERNEL. Canonical declarations AND prose about them: a heading per
# capability, a heading naming two, and a bolded sentence citing both. Nothing is dropped,
# so a kernel that documents itself must pass. Without this arm an assertion that flags any
# non-id emphasis run reads as green while hard-blocking every kernel written this way.
n_want 0 "PROSE-RICH KERNEL: capability headings and a bolded sentence about them still PASS" \
  --spec "$R/kernel-prose-rich" --prd "$R/prd-ok.md"
n_says "PROSE-RICH KERNEL: and the prose neither adds to nor removes from the capability set" \
  "PASS (2 locked requirement(s), 2 capability(ies), 0 story(ies), 0 recorded note(s), 0 baselined)" \
  --spec "$R/kernel-prose-rich" --prd "$R/prd-ok.md"

n_mut unclosed-off 'if [ -n "$CAP_DECL_MALFORMED" ]; then' 'if false; then' \
  0 "MUTATION: with the assertion off the unclosed run drops CAP-2 and CAP-9 and the run exits 0" \
  --spec "$R/unclosed-bold" --prd "$R/prd-unclosed.md"

# --- (W) a declaration that WRAPS ---------------------------------------------
# THE DEFECT SPANS TWO INNOCENT LINES. The first opens a run and drops nothing; the second
# carries the dropped id and opens no run. A line-scoped reader sees neither.
n_want 2 "WRAPPED: a two-id declaration split across two lines DISARMS" \
  --spec "$R/b31-wrapped" --prd "$R/prd-ok.md"
# WHICH ARM CLAIMED IT, not merely that something did: this seed is reachable by the
# declaration assertion only, and the dropped-id list is what names it.
n_says "WRAPPED: the declaration arm claims it, and names the id that was dropped" \
  "drop these capability ids: CAP-2" \
  --spec "$R/b31-wrapped" --prd "$R/prd-ok.md"
# THE LOAD-BEARING HALF. Byte-identical content on ONE line. Revert the fold and this arm
# stays green while the wrapped one goes silent — so the pair localises the regression to
# the fold rather than to the declaration predicate.
n_want 2 "WRAPPED CONTROL: the byte-identical ONE-LINE form DISARMS too" \
  --spec "$R/b31-oneline" --prd "$R/prd-ok.md"
n_says "WRAPPED CONTROL: and it is the same arm and the same dropped id" \
  "drop these capability ids: CAP-2" \
  --spec "$R/b31-oneline" --prd "$R/prd-ok.md"
n_want 2 "WRAPPED: the wrapped form with an UNDECLARED leading id DISARMS as well" \
  --spec "$R/b31-wrapped-undef" --prd "$R/prd-ok.md"
# THE MUTANT KILLS ONE HALF OF THE PAIR AND NOT THE OTHER, which is the pair's whole point:
# reading the unfolded prose leaves the wrapped declaration invisible while the one-line
# form still DISARMs.
n_mut fold-off 'printf '"'"'%s\n'"'"' "$KERNEL_ITEMS"; }' 'printf '"'"'%s\n'"'"' "$KERNEL_PROSE"; }' \
  0 "MUTATION: reading unfolded prose lets the WRAPPED declaration drop CAP-2 in silence" \
  --spec "$R/b31-wrapped" --prd "$R/prd-ok.md"

# --- (F) the fold's BOUND -----------------------------------------------------
# THE FOLD IS BOUNDED BY AN OPEN RUN THAT OPENED WITH A CAP ID, not by the list item and
# not by any odd asterisk count. Each arm below is a CORRECT kernel that a wider bound
# hard-DISARMS, which is the failure mode this file has met three times.
n_want 0 "FOLD BOUND: an unclosed '**' in a DESCRIPTION does not drag the next line into the declaration" \
  --spec "$R/d32-unclosed-desc" --prd "$R/prd-ok.md"
n_says "FOLD BOUND: and the cross-spec id on that line is not read as dropped" \
  "PASS (2 locked requirement(s), 2 capability(ies), 0 story(ies), 0 recorded note(s), 0 baselined)" \
  --spec "$R/d32-unclosed-desc" --prd "$R/prd-ok.md"
n_want 0 "FOLD BOUND: the same line with the bold CLOSED also passes — the bound cannot be widened back" \
  --spec "$R/d32-closed-desc" --prd "$R/prd-ok.md"
n_want 0 "FOLD BOUND: a CLOSED declaration whose description cites another spec's id passes" \
  --spec "$R/bound-closed-desc" --prd "$R/prd-ok.md"
n_says "FOLD BOUND: and that description contributes nothing to the capability set" \
  "PASS (2 locked requirement(s), 2 capability(ies), 0 story(ies), 0 recorded note(s), 0 baselined)" \
  --spec "$R/bound-closed-desc" --prd "$R/prd-ok.md"
# `fold-bound-wide` RETIRED for the same measured reason: with the fold bound widened AND
# the first-run rule widened, both bound pins stay at rc=0, because a cross-spec id inside
# a description opens no run and `decl_run` reports only a run-opening id. The bound is
# held by the shape of the reader, not by a guard that can be switched off.
n_discrim "FOLD BOUND DISCRIMINATES: a description citing another spec is quiet while a WRAPPED declaration DISARMS" \
  "$R/bound-closed-desc" "$R/b31-wrapped" "$R/prd-ok.md"
n_discrim "FOLD BOUND DISCRIMINATES: and so is an unclosed bold inside a description" \
  "$R/d32-unclosed-desc" "$R/b31-wrapped" "$R/prd-ok.md"

# --- (T) the fold TERMINATES --------------------------------------------------
# A HANG IS NOT A FAILURE. Every other arm here reads an exit code or a message, and an
# accumulator that never returns produces neither.
NEW_ARMS=$((NEW_ARMS+1))
if ! run_bounded 5 "$V" --spec "$R/fold-heavy" --prd "$R/prd-ok.md"; then
  bad "TERMINATION: the fold did NOT complete within 5s on a fold-heavy kernel — an accumulator that never returns"
elif ! bash "$V" --spec "$R/fold-heavy" --prd "$R/prd-ok.md" 2>&1 | grep -qF "PASS (2 locked requirement(s), 2 capability(ies)"; then
  bad "TERMINATION: it completed but produced no verdict — completing is what a subject that emits nothing also does"
else
  ok "TERMINATION: the fold completes on a 600-line fold-heavy kernel within 5s AND reports its verdict"
fi
# THE ARM NEEDS A SUBJECT. A non-terminating fold must be killed by the bound, or this
# assertion is one that cannot fire — the exact shape it exists to catch.
NEW_ARMS=$((NEW_ARMS+1))
HANG_M="$R/mutant-fold-hang.sh"
cp "$V" "$HANG_M"
FROM='  DECL_RUN = ""; DECL_FOUND = 0; DECL_OPEN = 0' TO='  DECL_RUN = ""; DECL_FOUND = 0; DECL_OPEN = 0; while (1) { }' \
  perl -pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$HANG_M"
if cmp -s "$V" "$HANG_M"; then
  bad "FIXTURE ERROR: the fold-hang mutation matched nothing — the termination arm proves nothing"
elif ! bash -n "$HANG_M" 2>/dev/null; then
  bad "FIXTURE ERROR: the fold-hang mutant is not a valid shell script"
elif run_bounded 5 "$HANG_M" --spec "$R/fold-heavy" --prd "$R/prd-ok.md"; then
  bad "MUTATION: a non-terminating fold COMPLETED — the termination arm cannot fire"
else
  ok "MUTATION: a non-terminating fold is caught by the bound, so the arm above has a subject"
fi

# --- (33) after the first run, an item is PROSE -------------------------------
n_want 0 "DEFECT 33: an intent citing a neighbouring spec id is prose, not a second declaration" \
  --spec "$R/bullet-foreign-id" --prd "$R/prd-ok.md"
n_says "DEFECT 33: and the cited id does not enter the capability set" \
  "PASS (2 locked requirement(s), 2 capability(ies), 0 story(ies), 0 recorded note(s), 0 baselined)" \
  --spec "$R/bullet-foreign-id" --prd "$R/prd-ok.md"
# An item whose FIRST run is not an id declares nothing at all -- the comment beside that
# rule names this exact shape, so it gets an arm rather than a citation.
n_want 0 "DEFECT 33: a Note bullet declares nothing, so an undeclared id inside it is quiet" \
  --spec "$R/note-bullet" --prd "$R/prd-ok.md"
n_says "DEFECT 33: and the two real declarations are still both counted" \
  "PASS (2 locked requirement(s), 2 capability(ies), 0 story(ies), 0 recorded note(s), 0 baselined)" \
  --spec "$R/note-bullet" --prd "$R/prd-ok.md"

# THE ACCEPTED COST, ARMED ON BOTH SIDES. A heading has no closing delimiter, so its whole
# text is the run and a heading CITING a foreign id DISARMS -- while the identical citation
# in an intent bullet is prose and is quiet. The asymmetry is deliberate; arming only the
# side that fires would let the other drift into silence unnoticed, and arming neither
# would leave a hard block on correct input undocumented.
n_want 2 "ACCEPTED COST: a HEADING citing a foreign id DISARMS — a heading has no delimiter to end its run" \
  --spec "$R/head-foreign-id" --prd "$R/prd-ok.md"
n_discrim "ACCEPTED COST: the identical citation is quiet in a BULLET and firing in a HEADING, in one run" \
  "$R/bullet-foreign-id" "$R/head-foreign-id" "$R/prd-ok.md"

# --- (M) container x declaration-shape, in the LONE-ID shape -------------------
# THE FAMILY THAT WAS MISSING, AND WHY ITS ABSENCE WAS INVISIBLE. Every container arm
# above seeds a TWO-ID run, which is non-bare and is taken by the stronger-run path
# WITHOUT EVER CONSULTING the leading test. A regression that put a lone `| **CAP-9** |`
# and `> - **CAP-9**` back into silence lived in that leading test, and this battery
# stayed green straight through it. WHEN A GUARD HAS TWO ACCEPTANCE PATHS, EVERY SEED
# FAMILY NEEDS A CASE ON EACH — otherwise the family covers one branch and reads as
# though it covered the guard.
#
# THE EXPECTATION SPLITS THREE WAYS, and that is the load-bearing part: an arm asserting
# "every container DISARMS" would be WRONG about the two the reader correctly takes.

# READ. The reader takes these, so CAP-9 joins the set — asserted on the COUNT, because
# rc=0 alone is what a subject that emits nothing also gives.
n_want 0 "MATRIX/READ: a canonical dash bullet is taken as a declaration" \
  --spec "$R/mx-read-dash" --prd "$R/prd-matrix.md"
n_says "MATRIX/READ: and CAP-9 is IN the capability set" \
  "PASS (1 locked requirement(s), 2 capability(ies)" \
  --spec "$R/mx-read-dash" --prd "$R/prd-matrix.md"
n_want 0 "MATRIX/READ: an INDENTED bullet is still a bullet" \
  --spec "$R/mx-read-indent" --prd "$R/prd-matrix.md"
n_says "MATRIX/READ: and its id is IN the set too" \
  "PASS (1 locked requirement(s), 2 capability(ies)" \
  --spec "$R/mx-read-indent" --prd "$R/prd-matrix.md"

n_want 2 "MATRIX/FLAG: a lone declaration in a NUMBERED item DISARMS" \
  --spec "$R/mx-flag-numbered" --prd "$R/prd-matrix.md"
n_want 2 "MATRIX/FLAG: a lone declaration in a PLUS-marker bullet DISARMS" \
  --spec "$R/mx-flag-plus" --prd "$R/prd-matrix.md"
n_want 2 "MATRIX/FLAG: a lone declaration in a BLOCKQUOTE DISARMS" \
  --spec "$R/mx-flag-quote" --prd "$R/prd-matrix.md"
n_want 2 "MATRIX/FLAG: a lone declaration in a BLOCKQUOTE BULLET DISARMS" \
  --spec "$R/mx-flag-quotebul" --prd "$R/prd-matrix.md"
n_want 2 "MATRIX/FLAG: a lone declaration in a TABLE cell DISARMS" \
  --spec "$R/mx-flag-table" --prd "$R/prd-matrix.md"
n_want 2 "MATRIX/FLAG: a lone declaration in a HEADING DISARMS" \
  --spec "$R/mx-flag-heading" --prd "$R/prd-matrix.md"
n_want 2 "MATRIX/FLAG: a lone declaration in a bare PARAGRAPH DISARMS" \
  --spec "$R/mx-flag-para" --prd "$R/prd-matrix.md"
n_want 2 "MATRIX/FLAG: a lone declaration in underscore EMPHASIS DISARMS" \
  --spec "$R/mx-flag-em" --prd "$R/prd-matrix.md"
n_want 2 "MATRIX/FLAG: a lone declaration in a CODE run DISARMS" \
  --spec "$R/mx-flag-code" --prd "$R/prd-matrix.md"
n_want 2 "MATRIX/FLAG: a lone declaration in DOUBLE-UNDERSCORE emphasis DISARMS" \
  --spec "$R/mx-flag-dunder" --prd "$R/prd-matrix.md"
n_says "MATRIX/FLAG: and the unreadable id is NAMED, so the author is told which one" \
  "CAP-9" \
  --spec "$R/mx-flag-table" --prd "$R/prd-matrix.md"

# QUIET. Prose. The id must NOT join the set and nothing may fire — the third expectation,
# and the one an "everything DISARMS" arm would get backwards.
n_want 0 "MATRIX/QUIET: a prose bullet citing an id upstream is not a declaration" \
  --spec "$R/mx-quiet-see" --prd "$R/prd-matrix.md"
n_says "MATRIX/QUIET: and the cited id stays OUT of the capability set" \
  "PASS (1 locked requirement(s), 1 capability(ies)" \
  --spec "$R/mx-quiet-see" --prd "$R/prd-matrix.md"
n_want 0 "MATRIX/QUIET: a Note bullet citing an id upstream is not a declaration either" \
  --spec "$R/mx-quiet-note" --prd "$R/prd-matrix.md"
n_says "MATRIX/QUIET: and its id stays out too" \
  "PASS (1 locked requirement(s), 1 capability(ies)" \
  --spec "$R/mx-quiet-note" --prd "$R/prd-matrix.md"

# --- (40) the membership gate has THREE states, not two -----------------------
# A bolded phrase LATE in an item is a foreign citation when NONE of its ids is declared,
# and a dropped declaration when SOME are. Only the middle state fires. Holding the two
# ends without the middle lets a widening pass in silence; holding the middle without the
# ends lets the gate be deleted.
n_want 0 "MEMBERSHIP: a late bolded phrase whose ids are ALL declared is quiet" \
  --spec "$R/mem-all-known" --prd "$R/prd-mixed.md"
n_says "MEMBERSHIP: and the kernel keeps its three real declarations" \
  "PASS (1 locked requirement(s), 3 capability(ies)" \
  --spec "$R/mem-all-known" --prd "$R/prd-mixed.md"
n_want 0 "MEMBERSHIP: a late bolded phrase whose ids are NONE declared is a foreign citation" \
  --spec "$R/mem-none-known" --prd "$R/prd-mixed.md"
n_says "MEMBERSHIP: and it does not beat the real declaration" \
  "PASS (1 locked requirement(s), 3 capability(ies)" \
  --spec "$R/mem-none-known" --prd "$R/prd-mixed.md"
n_want 2 "MEMBERSHIP: MIXED — one id declared and one not — is a real drop and FIRES" \
  --spec "$R/mem-mixed" --prd "$R/prd-mixed.md"
n_says "MEMBERSHIP: and the mixed phrase is reported" \
  "CAP-9" \
  --spec "$R/mem-mixed" --prd "$R/prd-mixed.md"
# POSITION STILL WINS OVER MEMBERSHIP when the phrase is the item FIRST run: that is a
# declaration attempt whatever its ids are, so both membership states fire.
n_want 2 "MEMBERSHIP: as the FIRST run, a mixed phrase fires on position regardless" \
  --spec "$R/mem-first-mixed" --prd "$R/prd-mixed.md"
n_want 2 "MEMBERSHIP: and so does a wholly-foreign phrase in first position" \
  --spec "$R/mem-first-none" --prd "$R/prd-mixed.md"
n_mut membership-gate-off '        if (!strict || leading || known(run)) {' '        if (1) {' \
  2 "MUTATION: dropping the membership gate makes a foreign citation beat the real declaration" \
  --spec "$R/mem-none-known" --prd "$R/prd-mixed.md"

# --- the DOCUMENTED irreducible limit ------------------------------------------
# A short prefix before a declaration naming exactly ONE id is structurally identical to a
# citation, and the id drops in SILENCE. This is armed as the behaviour it IS, with the
# COUNT as the discriminator — 3 against the control 4. An arm expecting a fix would be
# asserting a decision nobody took; an arm asserting rc alone would see nothing at all,
# because both sides exit 0.
n_says "DOCUMENTED LIMIT: a prefixed lone-id declaration is DROPPED — three capabilities, not four" \
  "PASS (1 locked requirement(s), 3 capability(ies)" \
  --spec "$R/limit-prefixed" --prd "$R/prd-limit.md"
n_says "DOCUMENTED LIMIT CONTROL: the same declaration WITHOUT the prefix is taken — four" \
  "PASS (1 locked requirement(s), 4 capability(ies)" \
  --spec "$R/limit-control" --prd "$R/prd-limit.md"

# UNMUTATED CONTROL for this block's subjects.
# THIS CONTROL IS WHAT SEPARATES A BROKEN SUBJECT FROM WRONG ARMS, and it earned that
# during this release: one run came back with EVERY arm exiting 2 and this line firing.
# That is the signal that the subject is mid-edit or broken, not that 190 arms need
# rebasing — without it the next author spends an hour rebasing against a state that no
# longer exists. A battery this large needs one arm whose only job is to say "not you". The control above runs the orphan-LR
# corpus; these mutants run five corpora it never touches, and a copy that misbehaved on
# any of them would make their assertions vacuous. Positive conjunct: the PASS LINE must
# be THERE, because rc=0 with nothing printed is what a subject replaced by `exit 0` also
# produces.
NEW_ARMS=$((NEW_ARMS+1))
CTRL_OUT="$(bash "$R/control-unmutated.sh" --spec "$R/real-suffixed" --prd "$R/prd-suffixed.md" \
              --story "$R/story-suffixed.md" --spine "$R/spine-suffixed.md" 2>&1)"
if grep -qF "PASS (2 locked requirement(s), 3 capability(ies)" <<<"$CTRL_OUT"; then
  ok "CONTROL: an unmutated copy in \$R still reports the suffixed PASS line"
else
  bad "CONTROL: an unmutated copy misbehaves in \$R — every mutation in this block is vacuous"
fi

# ARMS-RAN. Non-zero and exact, for the reason the block above states.
if [ "$NEW_ARMS" -eq 238 ]; then
  ok "ARMS-RAN: all 238 v0.388.0 arms EXECUTED (counted $NEW_ARMS)"
else
  bad "ARMS-RAN: expected 238 v0.388.0 arms, counted $NEW_ARMS — the block is unreachable, truncated, or short-circuited"
fi

# =============================================================================
# v0.389.0 — a continuation line joins as TEXT, and ONE container set
# =============================================================================
# Counted separately from the 238 above so that block stays exact.
#
# AUTHORSHIP NOTE, STATED BECAUSE IT IS A DEPARTURE. The rule in
# `.claude/rules/fixture-mutants.md` is to keep the battery author different from the arm
# author, precisely so the two cannot encode one understanding twice. These arms were
# written by the hand that wrote the change. The mitigation is that every arm below is
# PRESENCE-shaped and every one carries a committed mutant, and that the behaviour claim
# is carried by a differential against the previous release rather than by these arms --
# but a reviewer should read them knowing the independent check was not taken.
U_ARMS=0
u_want()     { U_ARMS=$((U_ARMS+1)); want     "$@"; }
u_says()     { U_ARMS=$((U_ARMS+1)); says     "$@"; }
u_mut()      { U_ARMS=$((U_ARMS+1)); mut      "$@"; }
u_mut_says() { U_ARMS=$((U_ARMS+1)); mut_says "$@"; }

# --- (U1) the join drops the source indentation, at BOTH folds -----------------
# The defect was reported by a consumer reading gate output: a wrapped No-AD reason
# rendered with the continuation line's own indentation embedded mid-sentence. It flips no
# verdict -- every terminator test runs on the raw line BEFORE the append, and the id
# readers strip ids and test the residue for alphanumerics -- so no rc arm can see it and
# only a text arm can.
u_says "UNINDENT (spine): a wrapped No-AD reason joins with ONE space at the wrap" \
  "already establishes and introduces no new mechanism class" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-wrapped.md"

u_says "UNINDENT (kernel): a wrapped declaration is echoed with ONE space at the wrap" \
  "- **CAP-1 and CAP-2 together**" \
  --spec "$R/b31-wrapped" --prd "$R/prd-ok.md"

# BOTH DIRECTIONS ON THE REAL SUBJECT. A presence arm alone is satisfied by output that
# carries the fixed form somewhere and the broken form as well; the claim is that the
# indented form is GONE, and an absence needs the presence stated in the same run or it
# passes against a subject that emits nothing.
U_ARMS=$((U_ARMS+1))
U_OUT="$(bash "$V" --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-wrapped.md" 2>&1)"
if grep -qF "establishes and   introduces" <<<"$U_OUT"; then
  bad "UNINDENT: the source indentation is STILL embedded in the note"
elif ! grep -qF "establishes and introduces" <<<"$U_OUT"; then
  bad "UNINDENT: neither form is present — this absence arm would pass against a subject that emits nothing"
else
  ok "UNINDENT: the indented form is absent AND the joined form is present, in one run"
fi

# ONE PREDICATE, TWO EMISSION SITES. The same literal appears at the kernel fold and at
# both spine appends, so one mutation reverts all three -- which is what makes these two
# arms one predicate rather than two entangled guards. Each asserts its own site.
u_mut_says unindent-spine 'acc = acc " " unindent($0)' 'acc = acc " " $0' \
  "establishes and   introduces" \
  "MUTATION: dropping the unindent puts the source indentation back into the NOTE" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-noad-wrapped.md"

u_mut_says unindent-kernel 'acc = acc " " unindent($0)' 'acc = acc " " $0' \
  "**CAP-1 and   CAP-2 together**" \
  "MUTATION: dropping the unindent puts it back into the DISARM echo too" \
  --spec "$R/b31-wrapped" --prd "$R/prd-ok.md"

# --- (U2) ONE container set across both folds (BL-084) -------------------------
# The spine fold now derives its container test from CONTAINER instead of carrying its own
# list-marker regex. CONTAINER holds `>` and `|` as well, so the unconditional terminators
# are tested FIRST; a reroute that did not would send an indented blockquote or table row
# to the more-indented rule and CONTINUE the Binds item, absorbing a capability that line
# only MENTIONS. That closes join (2a) at rc=0 against text that binds nothing.
u_want 1 "CONTAINER (spine): an indented BLOCKQUOTE ends the Binds item, so the CAP it names is unbound" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-cont-quote.md"
u_says "CONTAINER (spine): and the unbound capability is named, so the finding is actionable" \
  "CAP-2 is defined in" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-cont-quote.md"

u_want 1 "CONTAINER (spine): an indented TABLE ROW ends the Binds item" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-cont-table.md"

u_want 1 "CONTAINER (spine): a THEMATIC BREAK ends the Binds item" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-cont-thematic.md"

# THE CONTINUATION SIDE, without which the three arms above are satisfied by a fold that
# terminates on everything -- which would silently unbind every nested-list binding.
u_want 0 "CONTAINER (spine): a more-indented NESTED LIST continues the item, so both CAPs bind" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-cont-nested.md"
u_says "CONTAINER (spine): the nested binding reaches the PASS line, not an empty rc=0" \
  "PASS (2 locked requirement(s), 2 capability(ies)" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-cont-nested.md"

# THE MUTANT IS THE REORDER ITSELF: test the containers first and the three terminators
# become continuations. All three flip 1 -> 0, which is the false-BIND direction.
u_mut cont-reorder-quote 'if ($0 ~ /^#/ || $0 ~ /^[[:space:]]*>/ || $0 ~ /^[[:space:]]*\|/ || $0 ~ /^[[:space:]]*(---|===|___|\*\*\*)/) {' 'if ($0 ~ /^#/) {' \
  0 "MUTATION: dropping the unconditional terminators makes a BLOCKQUOTE bind CAP-2" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-cont-quote.md"

u_mut cont-reorder-table 'if ($0 ~ /^#/ || $0 ~ /^[[:space:]]*>/ || $0 ~ /^[[:space:]]*\|/ || $0 ~ /^[[:space:]]*(---|===|___|\*\*\*)/) {' 'if ($0 ~ /^#/) {' \
  0 "MUTATION: and makes a TABLE ROW bind CAP-2" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-cont-table.md"

u_mut cont-reorder-thematic 'if ($0 ~ /^#/ || $0 ~ /^[[:space:]]*>/ || $0 ~ /^[[:space:]]*\|/ || $0 ~ /^[[:space:]]*(---|===|___|\*\*\*)/) {' 'if ($0 ~ /^#/) {' \
  0 "MUTATION: and makes text after a THEMATIC BREAK bind CAP-2" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-cont-thematic.md"

# THE SHARED PREDICATE ITSELF. Deleting container_start from the spine fold must not be
# survivable: with it always false, a nested list item stops continuing the Binds bullet
# and the idiomatic multi-capability binding silently unbinds.
# THE SHARED PREDICATE ITSELF, mutated on the case it actually decides. Falling through
# the container branch CONTINUES the item anyway, so a nested-list seed cannot kill this
# mutant -- the first attempt at this arm did exactly that and came back green. What
# container_start decides is TERMINATION on a same-or-less-indented sibling bullet: with
# it off, the `- **Prevents:**` bullet folds into `- **Binds:**` and every capability that
# bullet merely mentions reads as BOUND. The seed carries no second `**<Key>:**` marker,
# so the eaten-marker guard cannot own the case and kill the mutant by the wrong arm.
u_want 1 "CONTAINER (spine): a same-indent SIBLING bullet ends the item, so the CAP it names is unbound" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-cont-sibling.md"
u_mut cont-predicate-off 'if (container_start($0)) {' 'if (0) {' \
  0 "MUTATION: with the shared container predicate off, a sibling bullet folds in and binds CAP-2" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine "$R/spine-cont-sibling.md"

# --- (U3) the widened --baseline diagnostic ------------------------------------
# The exit code was already armed. What is new is that ONE exit 2 has two opposite
# remedies, and the message has to carry both or it sends half its readers the wrong way.
u_want 2 "BASELINE DISARM: an unreadable baseline still exits 2" \
  --spec "$R/orphan-lr" --prd "$R/prd-ok.md" --baseline "$R/nonexistent-baseline.txt"
u_says "BASELINE DISARM: names the DELETE remedy for a ledger that reached zero" \
  "the terminal state is to DELETE the file and stop passing" \
  --spec "$R/orphan-lr" --prd "$R/prd-ok.md" --baseline "$R/nonexistent-baseline.txt"
u_says "BASELINE DISARM: names the TRACKING remedy for a file that should exist" \
  "check it is COMMITTED" \
  --spec "$R/orphan-lr" --prd "$R/prd-ok.md" --baseline "$R/nonexistent-baseline.txt"

# ARMS-RAN for this block, exact and non-zero, for the reason the 238 block states.
if [ "$U_ARMS" -eq 19 ]; then
  ok "ARMS-RAN: all 19 v0.389.0 arms EXECUTED (counted $U_ARMS)"
else
  bad "ARMS-RAN: expected 19 v0.389.0 arms, counted $U_ARMS — the block is unreachable, truncated, or short-circuited"
fi

# =============================================================================
# BL-079 — join (1)'s population is DECLARED, and the block grammar is BORROWED
# =============================================================================
# THIS BLOCK MUST STAY ABOVE `exit $rc`, for the reason the two blocks above record.
# $LRJ_ARMS is the answer and it is asserted exactly at the end.
#
# WHAT IS UNDER TEST. `--locked-requirements FILE` replaces join (1)'s population —
# "every LR-<...> token anywhere in the memlog" — with "the ids DECLARED inside that
# file's LOCKED_REQUIREMENTS block". The motivating defect is that the memlog is the
# spec's SELF-REPORT, and a self-report can contain an id that exists precisely BECAUSE
# it does not exist: the reference consumer's s302 memlog records "an id-presence sweep
# run with an absent-id control (LR-S999-9) that returned zero", and the gate convicted
# that consumer of dropping a locked requirement for writing its own control token down.
#
# THE DISARM TRAP THIS BATTERY EXISTS FOR. Every remedy for that defect that narrows the
# MEMLOG predicate also silences genuine orphans, and the two are indistinguishable by rc
# alone: both produce a green run. So the arms here are built in PAIRS — one input the
# check must stay quiet on and one it must still convict, wherever possible in the SAME
# corpus and, for the central pair, in the SAME invocation.
#
# AND THE POPULATION-SOURCE PAIRING GENERALISES. Every "quiet under the flag" arm below
# has a partner that omits the flag and watches the same id FAIL. Without that partner,
# rc=0 is equally what a corpus containing nothing produces, and the arm certifies an
# empty tree rather than a discrimination.
#
# AUTHORSHIP. Written by a hand that did not write the change, as
# `.claude/rules/fixture-mutants.md` requires, and every seed below is taken from what
# the PRODUCER emits — the reference consumer's five real locked-requirements.md files
# and its s302 spec memlog — never from the regexes in the subject.
LRJ_ARMS=0
j_want()     { LRJ_ARMS=$((LRJ_ARMS+1)); want     "$@"; }
j_says()     { LRJ_ARMS=$((LRJ_ARMS+1)); says     "$@"; }
j_mut()      { LRJ_ARMS=$((LRJ_ARMS+1)); mut      "$@"; }
j_mut_says() { LRJ_ARMS=$((LRJ_ARMS+1)); mut_says "$@"; }

# THE MUTANT'S SIBLING, AND WHY THIS `cp` IS AN ASSERTION RATHER THAN SETUP. The subject
# no longer owns the LOCKED_REQUIREMENTS marker grammar; validate-locked-anchor.sh does,
# and the subject resolves it by `dirname "$0"`. `mut` builds every mutant as a lone copy
# in $R, where that sibling does not exist — so WITHOUT this line every `--locked-requirements`
# mutant below DISARMs at exit 2 for the wrong reason, and a battery of mutants that all
# died by one unrelated arm reads exactly like a battery that works.
cp "$(cd "$(dirname "$V")" && pwd)/validate-locked-anchor.sh" "$R/validate-locked-anchor.sh" 2>/dev/null || true
LRJ_ARMS=$((LRJ_ARMS+1))
if [ -f "$R/validate-locked-anchor.sh" ]; then
  ok "SETUP: validate-locked-anchor.sh is beside the mutants in \$R — the mutation arms below can reach the block grammar"
else
  bad "SETUP: validate-locked-anchor.sh is NOT in \$R — every --locked-requirements mutation below DISARMs for the wrong reason and proves nothing"
fi

# UNMUTATED CONTROL, with a POSITIVE CONJUNCT. A copy in $R that misbehaves for any reason
# other than its mutation makes every mutation arm vacuous, and rc=0-with-nothing-said is
# exactly what a subject replaced by `exit 0` produces — so the population COUNT is
# asserted here, not merely the exit code.
cp "$V" "$R/control-lr-unmutated.sh"
LRJ_ARMS=$((LRJ_ARMS+1))
LRJ_CTL="$(bash "$R/control-lr-unmutated.sh" --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-decl.md" 2>&1)"
if ! grep -qF "join (1) reads 3 locked requirement(s) from" <<<"$LRJ_CTL"; then
  bad "CONTROL: an unmutated copy in \$R does not read the declared population — every mutation below is vacuous"
else
  ok "CONTROL: an unmutated copy in \$R reads all 3 declared requirements"
fi

# --- (1) THE DEFECT, AND THE DISARM THAT LOOKS LIKE ITS REMEDY -----------------
# rc=0 alone is what `exit 0` produces, so the COUNT and the PASS LINE are asserted beside
# it: `3 locked requirement(s)` is readable only if the block was parsed, and it is exactly
# 2 under a bold-only declaration anchor and 4 under the memlog scan.
j_want 0 "DECLARED: a spec whose three declared requirements all reach a capability PASSES" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-decl.md"
j_says "DECLARED: the population SOURCE and its size are announced, so which reader ran is never inferred from silence" \
  "join (1) reads 3 locked requirement(s) from" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-decl.md"
j_says "DECLARED: all THREE declaration grammars are counted into the population, not merely tolerated" \
  "PASS (3 locked requirement(s), 2 capability(ies), 0 story(ies), 0 recorded note(s), 0 baselined)" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-decl.md"

# THE FLAG OMITTED. Unchanged behaviour is a CLAIM and it needs the old defect reproduced,
# not merely an rc. The same tree, the same memlog, no flag: the control token is adopted
# and convicts the spec, which is the state a consumer that has not updated its call site
# is still in.
j_want 1 "FALLBACK: with the flag OMITTED the memlog scan still runs, and the same corpus still FAILS" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md"
j_says "FALLBACK: and the id it convicts is the ABSENT-ID CONTROL TOKEN — the defect, reproduced on demand" \
  "LR-S999-9 appears in the memlog but no capability entry cites it" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md"
j_says "FALLBACK: the scan announces ITSELF as the population, so a silent fallback is not a thing that can happen" \
  "(every LR-<...> identifier appearing anywhere in it)" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md"

# THE ARM THAT SEPARATES A FIX FROM A DISARM. One corpus carries BOTH inputs: the control
# token quoted in `(event by bmad-spec)` prose, and LR-S303-2 declared, journalled and
# cited by nothing. A remedy that silenced the memlog exits 0 here and passes every arm
# above it. Every candidate remedy for this defect was one.
j_want 1 "DECLARED: an uncited DECLARED requirement still FAILS — the population narrowed, the join did not" \
  --spec "$R/lr-decl-orphan" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-decl.md"
j_says "DECLARED: and the failing requirement is NAMED, so the declared population is feeding join (1)" \
  "LR-S303-2 appears in the memlog but no capability entry cites it" \
  --spec "$R/lr-decl-orphan" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-decl.md"

# BOTH DIRECTIONS, ONE INVOCATION. Split across two runs this is two claims about two
# programs; in one run it is the discrimination itself. The positive conjunct is what stops
# it passing against a subject that emits nothing — an absence and a silence are the same
# bytes.
LRJ_ARMS=$((LRJ_ARMS+1))
LRJ_OUT="$(bash "$V" --spec "$R/lr-decl-orphan" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-decl.md" 2>&1)"
if grep -qF "LR-S999-9" <<<"$LRJ_OUT"; then
  bad "DISCRIMINATION: the absent-id CONTROL TOKEN is STILL reported under a declared population — the defect survives"
elif ! grep -qF "LR-S303-2 appears in the memlog but no capability entry cites it" <<<"$LRJ_OUT"; then
  bad "DISCRIMINATION: the genuine orphan is NOT named either — this absence arm would pass against a subject that emits nothing"
else
  ok "DISCRIMINATION: the control token is NOT reported AND the genuine orphan IS, in one run over one corpus"
fi

# THE PAIR THAT MAKES THE ARM ABOVE A MEASUREMENT. Same corpus, no flag: the scan reports
# BOTH. Without this, "LR-S999-9 is absent from the output" is equally satisfied by a token
# that was never reachable in that corpus at all.
j_want 1 "DISCRIMINATION CONTROL: the same corpus under the SCAN convicts both ids" \
  --spec "$R/lr-decl-orphan" --prd "$R/prd-ok.md"
j_says "DISCRIMINATION CONTROL: including the control token, so it WAS reachable and the silence above is a decision" \
  "LR-S999-9 appears in the memlog but no capability entry cites it" \
  --spec "$R/lr-decl-orphan" --prd "$R/prd-ok.md"

# --- (2) THE BLOCK BOUNDARY, and the two roads to an empty extraction ----------
# NO MARKER PAIR and AN OPENER WITH NO CLOSER are different LINES in the subject and
# different EXIT PATHS in the borrowed grammar: --emit-blocks returns 0 with empty output
# for the first and non-zero for the second. A fix to either leaves the other, so both are
# armed and each asserts its own sentence.
j_want 2 "BOUNDARY: a declarations file with NO marker pair DISARMS at exit 2, never 0" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-nomarkers.md"
j_says "BOUNDARY: the no-block case says the block is what declares the population" \
  "yielded no LOCKED_REQUIREMENTS block CONTENT" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-nomarkers.md"

j_want 2 "BOUNDARY: an OPENER WITH NO CLOSER DISARMS at exit 2 — it does NOT run to EOF" \
  --spec "$R/lr-decl-addenda" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-unclosed.md"
j_says "BOUNDARY: the dangling-opener case is reported as an EXTRACTION failure, a different line from the empty one" \
  "could not extract LOCKED_REQUIREMENTS blocks from" \
  --spec "$R/lr-decl-addenda" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-unclosed.md"

# THE SPRINT-INTERPOLATED CLOSER. s299 closes with `<!-- END S299 LOCKED_REQUIREMENTS -->`
# and four other sprints with the bare form; the owning grammar's own census records SIX
# spellings. THIS IS THE ARM THAT PROVES THE DELEGATION WORKS, and it is the one that must
# go red if anybody re-inlines a narrow local matcher here. The file carries Tier 2 addenda
# BELOW that closer, so a matcher that cannot see it does not merely DISARM — it runs on
# and adopts them, which is an observable rather than a silence.
j_want 0 "SPRINT CLOSER: '<!-- END S303 LOCKED_REQUIREMENTS -->' closes the block, and the run PASSES" \
  --spec "$R/lr-decl-addenda" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-end-sprint.md"
j_says "SPRINT CLOSER: and it closes THERE — the population is 3, not the 5 an unterminated block would read" \
  "join (1) reads 3 locked requirement(s) from" \
  --spec "$R/lr-decl-addenda" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-end-sprint.md"

# IDS BELOW THE CLOSER ARE NOT ADOPTED. s304's real file carries LR-S304-8/-9 under a
# paragraph saying they are not operator-locked; a whole-file scan produces two findings
# against a gate that is green. The paragraph here spells `LOCKED_REQUIREMENTS` in
# backticks, as s304's does, because a marker match that is not anchored at line start
# takes it for a marker.
j_want 0 "BELOW-MARKER: Tier 2 addenda under the closer are NOT adopted into the population" \
  --spec "$R/lr-decl-addenda" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-below-marker.md"
j_says "BELOW-MARKER: the population stays at the 3 the block declares" \
  "join (1) reads 3 locked requirement(s) from" \
  --spec "$R/lr-decl-addenda" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-below-marker.md"

# THE PAIR. Both addenda ids are journalled and cited by nothing in this corpus, so the two
# quiet arms above are DISCRIMINATIONS. Drop this and they are satisfied by a memlog in
# which those ids do not appear at all.
j_want 1 "BELOW-MARKER CONTROL: under the SCAN the same two addenda ids are convicted" \
  --spec "$R/lr-decl-addenda" --prd "$R/prd-ok.md"
j_says "BELOW-MARKER CONTROL: LR-S303-8 IS reachable in this memlog — the silence above is a decision, not an empty tree" \
  "LR-S303-8 appears in the memlog but no capability entry cites it" \
  --spec "$R/lr-decl-addenda" --prd "$R/prd-ok.md"

# --- (3) THE DECLARATION GRAMMAR ----------------------------------------------
# A BLOCK THAT MENTIONS IDS AND DECLARES NONE is a producer whose grammar moved. Scoring it
# as "this sprint locked zero requirements" prints a PASS line byte-identical to a spec that
# closed the join for real, and that is the whole reason this exits 2.
j_want 2 "GRAMMAR: a block that MENTIONS ids but declares none in the anchored shape DISARMS at exit 2" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-mentions-only.md"
j_says "GRAMMAR: and it says the GRAMMAR has moved, which is the remedy — not that the sprint locked nothing" \
  "mentions LR-<...> identifiers but DECLARES none" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-mentions-only.md"

# THE NEAR-MISS FOR THE SENTENCE ABOVE. Same empty population, no LR- token in the block at
# all. Both exit 2, so rc is the wrong instrument for this pair; the SENTENCES are the
# assertion, and telling this file its grammar has moved would be a false diagnosis.
j_want 2 "GRAMMAR: a block that declares NOTHING AT ALL also DISARMS at exit 2" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-empty-block.md"
j_says "GRAMMAR: and it gets the OTHER sentence — the two empty populations are not one finding" \
  "declares no locked requirements at all" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-empty-block.md"

# A PROSE MENTION INSIDE THE BLOCK IS NOT A DECLARATION. s299's block cites `LR-S177-2` in
# a parenthetical on a continuation line under a real bullet. The id belongs to a PRIOR
# sprint, so adopting it convicts this sprint of dropping work it never owned.
j_want 0 "SUBJECT ANCHOR: a prose mention on a continuation line INSIDE the block is not adopted" \
  --spec "$R/lr-decl-prior" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-prose-mention.md"
j_says "SUBJECT ANCHOR: the population is the 3 BULLET SUBJECTS, not the 4 ids the block contains" \
  "join (1) reads 3 locked requirement(s) from" \
  --spec "$R/lr-decl-prior" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-prose-mention.md"
j_want 1 "SUBJECT ANCHOR CONTROL: under the SCAN the prior-sprint id IS convicted" \
  --spec "$R/lr-decl-prior" --prd "$R/prd-ok.md"
j_says "SUBJECT ANCHOR CONTROL: LR-S177-2 is reachable and uncited here, so the quiet arm above discriminates" \
  "LR-S177-2 appears in the memlog but no capability entry cites it" \
  --spec "$R/lr-decl-prior" --prd "$R/prd-ok.md"

# --- (4) AN UNREADABLE DECLARATION IS NOT AN EMPTY ONE -------------------------
j_want 2 "UNREADABLE: --locked-requirements naming a file that does not exist DISARMS at exit 2" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-no-such-file.md"
j_says "UNREADABLE: and says so, rather than reporting the borrowed grammar's failure to parse a file it never opened" \
  "names an unreadable file" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-no-such-file.md"

# --- (5) DECLARED AND NEVER JOURNALLED IS A NOTE ------------------------------
# A class the memlog scan cannot construct: an id the memlog never mentions. On the
# reference consumer both live instances sit on GREEN gates, so failing them reddens a
# passing consumer over evidence this join does not have — which is how a correct check
# gets switched off. rc=0 is asserted WITH the note text and the note COUNT, because rc=0
# and silence is also what dropping the id entirely produces.
j_want 0 "NOTE: a requirement declared in the file and journalled NOWHERE is a note, and the run still exits 0" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-decl-never.md"
j_says "NOTE: the never-journalled requirement is NAMED — a note nobody can see is not a note" \
  "LR-S303-7 is declared in" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-decl-never.md"
j_says "NOTE: it stays IN the population and is counted as a recorded note, not dropped from the tally" \
  "PASS (4 locked requirement(s), 2 capability(ies), 0 story(ies), 1 recorded note(s), 0 baselined)" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-decl-never.md"

# --- (6) THE DELEGATION ITSELF ------------------------------------------------
# The marker grammar is validate-locked-anchor.sh's and is not re-derived here. With the
# sibling ABSENT the flag must DISARM and NAME it — it must not fall back to a local match,
# and it must not close join (1). `want`/`says` run $V and cannot express this, so the arms
# below name their own program. The copy lives inside $R, which is already a mktemp -d; no
# real tree is touched.
mkdir -p "$R/lr-no-anchor"
cp "$V" "$R/lr-no-anchor/validate-spec-join.sh"
p_want() { # <prog> <expected-rc> <label> <args...>
  local prog="$1" exp="$2" lab="$3"; shift 3
  LRJ_ARMS=$((LRJ_ARMS+1))
  bash "$prog" "$@" >/dev/null 2>&1
  local g=$?
  [ "$g" -eq "$exp" ] && ok "$lab" || bad "$lab (expected rc=$exp, got rc=$g)"
}
p_says() { # <prog> <label> <must-contain> <args...>
  local prog="$1" lab="$2" want_s="$3"; shift 3
  LRJ_ARMS=$((LRJ_ARMS+1))
  local out; out="$(bash "$prog" "$@" 2>&1)"
  if grep -qF -- "$want_s" <<<"$out"; then ok "$lab"
  else bad "$lab (message missing: \"$want_s\")"; fi
}

p_want "$R/lr-no-anchor/validate-spec-join.sh" 2 \
  "DELEGATION: with validate-locked-anchor.sh absent, --locked-requirements DISARMS at exit 2 rather than matching markers locally" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-decl.md"
p_says "$R/lr-no-anchor/validate-spec-join.sh" \
  "DELEGATION: and the DISARM names the owner, so the remedy is the install rather than a third marker grammar" \
  "validate-locked-anchor.sh not found beside this script" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-decl.md"

# THE ARM WITHOUT WHICH THE TWO ABOVE MEAN "THIS COPY IS BROKEN". Same copy, no flag: it
# runs the memlog scan and convicts the control token, exactly as $V does. The DISARM is
# scoped to the flag, not to a dead file.
p_want "$R/lr-no-anchor/validate-spec-join.sh" 1 \
  "DELEGATION CONTROL: the SAME sibling-less copy still runs the scan when the flag is omitted — it is not simply broken" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md"

# AND THE NEAR-MISS: restore the sibling beside that copy and it PASSES. One directory, one
# file, two verdicts — which is what makes the DISARM attributable to the sibling.
cp "$R/validate-locked-anchor.sh" "$R/lr-no-anchor/validate-locked-anchor.sh"
p_want "$R/lr-no-anchor/validate-spec-join.sh" 0 \
  "DELEGATION NEAR-MISS: with the sibling restored beside it, the same copy reads the block and PASSES" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-decl.md"
# THE POSITIVE CONJUNCT FOR THE ARM ABOVE, and it was added because it was MEASURED
# missing: rc=0 alone is what `exit 0` produces, and against a subject replaced by `exit 0`
# that arm was one of seven in this block still printing `ok`. The COUNT is readable only
# if the borrowed grammar was actually invoked from this directory.
p_says "$R/lr-no-anchor/validate-spec-join.sh" \
  "DELEGATION NEAR-MISS: and it reads the block for real — the population COUNT is what the restored sibling produced" \
  "join (1) reads 3 locked requirement(s) from" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-decl.md"

# --- MUTATION controls --------------------------------------------------------
# THE MOST VALUABLE MUTANT IN THIS SET, and the one that guards the single-source decision:
# the delegation replaced by a re-inlined local marker regex recognising exactly ONE closer
# spelling. That is not a strawman — it is what this script did one revision ago, and what
# any future author reaching for `awk` here will write.
j_mut lr-local-regex \
  'bash "$LR_ANCHOR" "$LOCKED_REQS" --emit-blocks' \
  "awk '/^<!--[[:space:]]*LOCKED_REQUIREMENTS/{f=1;next} /^<!-- END LOCKED_REQUIREMENTS -->/{f=0;next} f' \"\$LOCKED_REQS\"" \
  1 "MUTATION: a re-inlined local marker regex cannot see the SPRINT-INTERPOLATED closer, runs past it and FAILS the run" \
  --spec "$R/lr-decl-addenda" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-end-sprint.md"
j_mut_says lr-local-regex \
  'bash "$LR_ANCHOR" "$LOCKED_REQS" --emit-blocks' \
  "awk '/^<!--[[:space:]]*LOCKED_REQUIREMENTS/{f=1;next} /^<!-- END LOCKED_REQUIREMENTS -->/{f=0;next} f' \"\$LOCKED_REQS\"" \
  "LR-S303-8 appears in the memlog but no capability entry cites it" \
  "MUTATION: and the ids it swallows are the Tier 2 addenda — the failure is attributable, not incidental" \
  --spec "$R/lr-decl-addenda" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-end-sprint.md"
# THE SAME MUTANT, SECOND OBSERVABLE. An unterminated block under a local matcher does not
# DISARM — it runs to EOF, silently widening the population. This is the arm that makes
# "do NOT run to EOF" a measurement rather than a claim about a code path.
j_mut lr-local-regex-eof \
  'bash "$LR_ANCHOR" "$LOCKED_REQS" --emit-blocks' \
  "awk '/^<!--[[:space:]]*LOCKED_REQUIREMENTS/{f=1;next} /^<!-- END LOCKED_REQUIREMENTS -->/{f=0;next} f' \"\$LOCKED_REQS\"" \
  1 "MUTATION: under a local matcher an UNCLOSED block runs to EOF and FAILS instead of DISARMing at 2" \
  --spec "$R/lr-decl-addenda" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-unclosed.md"
# AND THE ARM THAT PROVES IT DIES BY THE RIGHT ONE. A mutant that fails everything scores
# kills it did not earn. Against the BARE closer the local matcher is correct, and it must
# stay green there — otherwise the three arms above are attributing a general breakage to a
# specific closer spelling.
j_mut lr-local-regex-baseform \
  'bash "$LR_ANCHOR" "$LOCKED_REQS" --emit-blocks' \
  "awk '/^<!--[[:space:]]*LOCKED_REQUIREMENTS/{f=1;next} /^<!-- END LOCKED_REQUIREMENTS -->/{f=0;next} f' \"\$LOCKED_REQS\"" \
  0 "MUTATION SCOPE: the same local matcher is still GREEN on the BARE closer — it dies by the sprint-closer arm, not by everything" \
  --spec "$R/lr-decl-addenda" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-below-marker.md"

# THE DECLARATION ANCHOR WIDENED TO A WHOLE-BLOCK SCAN. Its subject is the prose mention,
# which no other guard here can see.
j_mut lr-anchor-wide \
  "'^[[:space:]]*[-*][[:space:]]+(\*\*|__)?LR-[A-Za-z0-9]+-[0-9]+[a-z]?'" \
  "'LR-[A-Za-z0-9]+-[0-9]+[a-z]?'" \
  1 "MUTATION: widening the declaration anchor to a whole-block scan adopts the block's PROSE MENTION and fails the run" \
  --spec "$R/lr-decl-prior" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-prose-mention.md"
j_mut_says lr-anchor-wide \
  "'^[[:space:]]*[-*][[:space:]]+(\*\*|__)?LR-[A-Za-z0-9]+-[0-9]+[a-z]?'" \
  "'LR-[A-Za-z0-9]+-[0-9]+[a-z]?'" \
  "LR-S177-2 appears in the memlog but no capability entry cites it" \
  "MUTATION: and it convicts this sprint of dropping a PRIOR sprint's requirement" \
  --spec "$R/lr-decl-prior" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-prose-mention.md"

# THE ANCHOR NARROWED TO REQUIRE EMPHASIS. `?` is the whole of what admits s305's
# `- LR-S305-1: "..."`, and the failure is SILENT: the id leaves the population and the run
# goes green. The seed puts the plain-shape declaration on the ORPHAN, so the mutant flips
# a FAIL to a PASS rather than merely changing a count.
j_mut lr-anchor-bold '(\*\*|__)?LR-[A-Za-z0-9]' '(\*\*|__)LR-[A-Za-z0-9]' \
  0 "MUTATION: a bold-only anchor drops the plain '- LR-<id>:' shape, and the uncited requirement goes UNREPORTED" \
  --spec "$R/lr-decl-orphan" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-decl.md"
j_mut_says lr-anchor-bold '(\*\*|__)?LR-[A-Za-z0-9]' '(\*\*|__)LR-[A-Za-z0-9]' \
  "join (1) reads 2 locked requirement(s) from" \
  "MUTATION: and the drop is visible in the announced population — 2 read where 3 are declared" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-decl.md"

# THE FLAG MADE INERT. The declared population is computed and then overwritten by the scan.
# Every arm that asserts a COUNT still passes under this — the source line even keeps naming
# the declared file — and the only thing that changes is that the control token comes back.
j_mut_says lr-flag-inert 'if [ -z "$LOCKED_REQS" ]; then' 'if true; then' \
  "LR-S999-9 appears in the memlog but no capability entry cites it" \
  "MUTATION: letting the scan overwrite the declared population brings the control token back — the shipped defect on demand" \
  --spec "$R/lr-decl-orphan" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-decl.md"

# THE TWO EMPTY-POPULATION DIAGNOSES COLLAPSED. Both exit 2 before and after, so rc is
# blind to this and only the sentence can see it: a producer whose grammar moved is told
# it locked nothing, and the next author deletes the flag instead of fixing the reader.
j_mut_says lr-grammar-moved-collapsed \
  "grep -qE '\bLR-[A-Za-z0-9]+-[0-9]+[a-z]?\b'" "grep -qE 'ZZ-NO-SUCH-DECLARATION-TOKEN'" \
  "declares no locked requirements at all" \
  "MUTATION: collapsing the empty-population discrimination tells a MOVED GRAMMAR that it locked nothing" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-mentions-only.md"

# THE `carries no LOCKED_REQUIREMENTS block` LINE, given its own subject. With it off, a
# file with no markers falls through to the declares-nothing message — still exit 2, and
# still a false statement about a file that has no block at all.
j_mut_says lr-emptyblock-silent 'if [ -z "$LR_BLOCK" ]; then' 'if false; then' \
  "declares no locked requirements at all" \
  "MUTATION: dropping the empty-extraction arm tells a file with NO BLOCK that its block declares nothing" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-nomarkers.md"

# THE UNREADABLE-FILE GUARD CHANGES NO VERDICT — the borrowed grammar exits non-zero on a
# missing file either way — so it is armed on the DIAGNOSIS, which is the only thing it
# decides. Arming it on rc would be an arm that cannot fire.
j_mut_says lr-unreadable-tolerated '[ -f "$LOCKED_REQS" ] || {' '[ -n "$PROG" ] || {' \
  "could not extract LOCKED_REQUIREMENTS blocks from" \
  "MUTATION: without the readability guard a MISSING FILE is reported as a parse failure of the block grammar" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-no-such-file.md"

# THE NEVER-JOURNALLED NOTE, TURNED BACK INTO A FAILURE. This is the direction that reddens
# a green consumer.
j_mut lr-note-fails 'if [ -n "$LOCKED_REQS" ] && ! grep -qE' 'if false && ! grep -qE' \
  1 "MUTATION: dropping the never-journalled branch FAILS a requirement this join has no evidence about" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-decl-never.md"

# THE NOTE TURNED INTO A SILENT SKIP. rc stays 0 and the tally still says `1 recorded
# note(s)`, so neither `mut` nor `mut_says` can express this: the claim is that a LINE
# DISAPPEARS. An absence needs its positive conjunct in the same run, and the PASS line is
# it — a mutant that died on a syntax error also prints no note.
LRJ_ARMS=$((LRJ_ARMS+1))
LRJ_M="$R/mutant-lr-note-silent.sh"
cp "$V" "$LRJ_M"
FROM='echo "  note  $lr is declared in $LOCKED_REQS' TO=': "  note  $lr is declared in $LOCKED_REQS' \
  perl -pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$LRJ_M"
if cmp -s "$V" "$LRJ_M"; then
  bad "FIXTURE ERROR: mutation 'lr-note-silent' matched nothing — its assertion would prove nothing"
elif ! bash -n "$LRJ_M" 2>/dev/null; then
  bad "FIXTURE ERROR: mutant 'lr-note-silent' is not a valid shell script — its silence is not a kill"
else
  LRJ_NS="$(bash "$LRJ_M" --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-decl-never.md" 2>&1)"
  if ! grep -qF "1 recorded note(s)" <<<"$LRJ_NS"; then
    bad "MUTATION: the note-silencing mutant produced no PASS line at all — this arm cannot tell a silenced note from a dead script"
  elif grep -qF "LR-S303-7 is declared in" <<<"$LRJ_NS"; then
    bad "MUTATION: silencing the note echo changed nothing — the note text is emitted from somewhere else, so the arm asserting it is not keyed on this line"
  else
    ok "MUTATION: silencing the note echo makes the requirement vanish from the output while the tally still counts it — the note line is load-bearing"
  fi
fi

# THE SIBLING-PRESENCE GUARD. Like the readability guard it decides a MESSAGE, not a
# verdict: without it the missing sibling surfaces as a parse failure of a grammar that was
# never invoked. It cannot be exercised by `mut`, whose mutants live in $R where the
# sibling exists, so it is built in the sibling-less directory instead.
LRJ_ARMS=$((LRJ_ARMS+1))
LRJ_MS="$R/lr-no-anchor-mutant"
mkdir -p "$LRJ_MS"
cp "$V" "$LRJ_MS/validate-spec-join.sh"
FROM='if [ ! -f "$LR_ANCHOR" ]; then' TO='if false; then' \
  perl -pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$LRJ_MS/validate-spec-join.sh"
if cmp -s "$V" "$LRJ_MS/validate-spec-join.sh"; then
  bad "FIXTURE ERROR: mutation 'lr-sibling-unchecked' matched nothing — its assertion would prove nothing"
elif ! bash -n "$LRJ_MS/validate-spec-join.sh" 2>/dev/null; then
  bad "FIXTURE ERROR: mutant 'lr-sibling-unchecked' is not a valid shell script — its silence is not a kill"
else
  LRJ_SB="$(bash "$LRJ_MS/validate-spec-join.sh" --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-decl.md" 2>&1)"
  if grep -qF "could not extract LOCKED_REQUIREMENTS blocks from" <<<"$LRJ_SB"; then
    ok "MUTATION: without the sibling-presence guard a MISSING OWNER is misreported as a failure to parse the declarations file"
  else
    bad "MUTATION: dropping the sibling-presence guard produced neither diagnosis — the arm asserting it is not keyed on that check"
  fi
fi

# --- (7) THE THREE DEFECTS AN INDEPENDENT HAND FOUND IN THE FIRST CUT ----------
# Each returned a WRONG ANSWER rather than an error, so each gets an arm that would have
# caught it and, where the arm is absence-shaped, a mutant.

# MULTI-BLOCK: the owner joins block bodies with a FORM FEED. Grepping the join glues one
# block's last line to the next block's first, so the head declaration of every block after
# the first cannot match its bullet anchor. THE DIFFERENTIAL IS THE POINT: the two files
# declare the same three requirements and must yield the same population, and the pair is
# asserted to DIFFER as files first, because a differential whose sides are the same file
# establishes nothing.
LRJ_ARMS=$((LRJ_ARMS+1))
if cmp -s "$R/lr-twoblocks.md" "$R/lr-oneblock.md"; then
  bad "FIXTURE ERROR: the two-block and one-block declaration files are byte-identical — the multi-block differential below compares a file with itself"
else
  ok "MULTI-BLOCK: the two-block and one-block declaration files differ, so the comparison below is a real differential"
fi
j_says "MULTI-BLOCK: a file whose declarations span TWO blocks yields all three, not the first block's one" \
  "join (1) reads 3 locked requirement(s)" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-twoblocks.md"
j_says "MULTI-BLOCK CONTROL: the same three declarations in ONE block yield the same population" \
  "join (1) reads 3 locked requirement(s)" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-oneblock.md"
# THE MUTANT IS MANDATORY HERE. `reads 3` is a presence assertion, but the defect it guards
# is a SILENT NARROWING that cannot disarm, so nothing else in this file would notice the
# split coming back out. Reverting the split must move the count and nothing else.
j_mut_says lr-formfeed-unsplit \
  'LR_BLOCK="$(tr '"'"'\014'"'"' '"'"'\n'"'"' <<<"$LR_RAW")"' 'LR_BLOCK="$LR_RAW"' \
  "join (1) reads 2 locked requirement(s)" \
  "MUTATION: leaving the form-feed join unsplit GLUES the blocks and silently drops the head declaration of the second" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-twoblocks.md"

# CHECKED-SET VACUITY: a declared population every one of whose ids is absent from the
# memlog takes the never-journalled note on every iteration, never touches `rc`, and prints
# PASS having joined nothing. The DISARM above it guards what was DECLARED; this guards what
# was CHECKED, and the note branch is what made those two different sets.
j_want 2 "VACUITY: a declared population NONE of whose ids the memlog mentions DISARMS — it does not PASS having checked nothing" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-wrong-sprint.md"
j_says "VACUITY: the diagnosis names the likely cause, which is --locked-requirements pointed at another sprint" \
  "The usual cause is --locked-requirements naming a different sprint's file" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-wrong-sprint.md"
# THE NEAR-MISS. One declared id IS journalled and joins, so the checked set is 1, not 0.
# An arm that fires on the presence of notes rather than on an empty checked set convicts
# this corpus too, and every real consumer sprint carrying a note with it.
j_want 0 "VACUITY NEAR-MISS: one journalled id among two unjournalled ones is a CHECKED set of 1 — the arm stays silent" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-wrong-sprint-partial.md"
j_mut lr-vacuity-tolerated 'if [ -n "$LOCKED_REQS" ] && [ "$lr_checked" -eq 0 ]; then' 'if false; then' \
  0 "MUTATION: without the checked-set guard a join that examined NOTHING reports PASS" \
  --spec "$R/lr-decl" --prd "$R/prd-ok.md" --locked-requirements "$R/lr-wrong-sprint.md"

# THE EMPTY FLAG VALUE. Every gate downstream tests `[ -n "$LOCKED_REQS" ]`, so an empty
# value was byte-indistinguishable from omitting the flag: it reverted to the memlog scan
# and reported the control token again, while the caller believed it had declared a
# population. Both arms run on the corpus where the two answers differ.
j_want 2 "EMPTY VALUE: --locked-requirements '' is REFUSED, not silently treated as omission" \
  --spec "$R/lr-decl-orphan" --prd "$R/prd-ok.md" --locked-requirements ""
j_says "EMPTY VALUE: the refusal says what omission would have done instead" \
  "was given an EMPTY value" \
  --spec "$R/lr-decl-orphan" --prd "$R/prd-ok.md" --locked-requirements ""
# THE DISCRIMINATION CONTROL: omitting the flag on the SAME corpus reaches the scan and
# convicts the control token. Without it, "exit 2" above is equally satisfied by a build in
# which that corpus could never have produced anything else.
j_says "EMPTY VALUE CONTROL: OMITTING the flag on the same corpus reaches the scan and reports the control token" \
  "LR-S999-9 appears in the memlog but no capability entry cites it" \
  --spec "$R/lr-decl-orphan" --prd "$R/prd-ok.md"

# ARMS-RAN. Non-zero and exact, for the reason the two blocks above state.
if [ "$LRJ_ARMS" -eq 67 ]; then
  ok "ARMS-RAN: all 67 BL-079 arms EXECUTED (counted $LRJ_ARMS)"
else
  bad "ARMS-RAN: expected 67 BL-079 arms, counted $LRJ_ARMS — the block is unreachable, truncated, or short-circuited"
fi

# --- (8) CORPUS IDENTITY on the PASS line --------------------------------------
# THE DEFECT. Every input this check joins is caller-supplied — a spec DIRECTORY, a PRD,
# and zero or more story files — and the PASS line reported only a TALLY:
# `PASS (3 locked requirement(s), 4 capability(ies), 1 story(ies), ...)`. Two runs over two
# different trees holding identical bytes were therefore BYTE-IDENTICAL, and a gate that
# joined last sprint's spec against this sprint's PRD printed the same green line as one
# that got both right. A count is not an identity.
#
# THE ARM IS KEYED ON DISCRIMINATION, NOT ON A SPELLING. The set is driven twice over two
# mktemp corpora seeded with the same bytes; the outputs must DIFFER **and** each must
# carry ITS OWN six paths. Those halves are separate requirements, and the second is the
# load-bearing one — a nonce, a PID or a timestamp makes two runs differ while naming
# nothing, and mutant `ident-nonce` below is exactly that fix. Nothing greps a label, so
# re-wording `spec:` leaves this working; what is demanded is the resolved path, and the
# roots are mktemp names, so no implementation can hardcode the literal it needs.
#
# IT IS PRESENCE-SHAPED — six paths must APPEAR in a run that reached the PASS emitter —
# so a subject replaced by `exit 0` fails it by construction.
#
# THE `oa = ob` CONJUNCT CANNOT FIRE ON THIS SUBJECT TODAY, AND THAT IS A MEASUREMENT, NOT
# AN OVERSIGHT. Driven over two corpora with all three identity lines deleted, the two runs
# still DIFFER: `join (1) reads N locked requirement(s) from <spec>/.memlog.md` already
# carried the spec directory before this release. So of the six paths the fix adds, only
# the PRD and the stories were previously unnamed, and a differ-only arm would have scored
# green against the unfixed validator here. The NAMING conjunct is what kills the mutants
# below; the differ conjunct is kept because it is the half that dies first if that memlog
# line is ever silenced, and it costs one comparison.
# THE `echo "$@"` ATTACK, AND THE HALF OF IT THAT NO ARM HERE CAN CLOSE. A fix that dumps the
# argument vector instead of the values it RESOLVED satisfies "the outputs differ" and "the
# path appears" without the validator ever disclosing a resolution. Measured against a mutant
# that replaced all six identity lines with one `echo "  argv: $@"`: this fixture goes RED, two
# cells, because the arm requires all SIX paths BY NAME and a collapsed dump carries one.
# Control in the same run: the unmutated copy is green and the two trees were asserted to
# differ first.
#
# What survives is narrower and is a property of the SUBJECT, not a hole in the arm: every
# input here is a required flag with no defaulted form, so `$2` and the resolved variable hold
# the same string and no observation can separate them. It becomes a real gap the moment any
# of these flags gains a default -- `validate-scope-confirmation.sh` already has one, and its
# fixture closes this by driving that validator with NO path arguments at all. If a default
# lands here, add that arm; until then there is nothing for it to discriminate.
SJ_IDENT_WHY=""
sj_ident_corpus() {   # -> prints a fresh corpus root holding all SIX inputs
  local d
  d="$(mktemp -d "$R/ident.XXXXXX")" || return 1
  cp -R "$R/ok" "$d/spec"           || return 1
  cp "$R/prd-ok.md"    "$d/prd.md"   || return 1
  cp "$R/story-ok.md"  "$d/story.md" || return 1
  cp "$R/spine-all.md" "$d/spine.md" || return 1
  cp "$R/spine-ok.json" "$d/lint.json" || return 1
  cp "$R/trace-pass.json" "$d/trace.json" || return 1
  printf '%s\n' "$d"
}
# sj_ident_holds <validator> — 0 iff the run reached PASS, the two runs are
# distinguishable, and each names ALL SIX inputs it actually read.
#
# SIX, NOT THE THREE THIS RELEASE STARTED WITH. `--spine-lint` and `--trace-verdict` are
# BORROWED VERDICTS: the gate adopts another tool's finding as its own. Measured before they
# were named, two runs over two different lint envelopes holding identical bytes were
# byte-identical, so a gate that adopted the wrong tool's verdict printed the same PASS line
# as one that adopted the right tool's. That is the worst member of this defect class,
# because the corpus it cannot identify is the one whose CONTENT it is deferring to.
sj_ident_holds() {
  local v="$1" a b oa ob ra rb
  SJ_IDENT_WHY=""
  a="$(sj_ident_corpus)" || { SJ_IDENT_WHY="could not build corpus A"; return 1; }
  b="$(sj_ident_corpus)" || { SJ_IDENT_WHY="could not build corpus B"; return 1; }
  oa="$(bash "$v" --spec "$a/spec" --prd "$a/prd.md" --story "$a/story.md" \
          --spine "$a/spine.md" --spine-lint "$a/lint.json" \
          --trace-verdict "$a/trace.json" 2>&1)"; ra=$?
  ob="$(bash "$v" --spec "$b/spec" --prd "$b/prd.md" --story "$b/story.md" \
          --spine "$b/spine.md" --spine-lint "$b/lint.json" \
          --trace-verdict "$b/trace.json" 2>&1)"; rb=$?
  if [ "$ra" != "0" ] || [ "$rb" != "0" ]; then
    SJ_IDENT_WHY="rc=$ra/$rb, expected 0/0 — the run never reached the PASS emitter"; return 1
  fi
  if ! grep -qF ': PASS (' <<<"$oa"; then
    SJ_IDENT_WHY="no PASS line — this arm did not reach the emitter it claims to guard"; return 1
  fi
  if [ "$oa" = "$ob" ]; then
    SJ_IDENT_WHY="two different trees holding identical bytes produced byte-identical output"
    return 1
  fi
  if ! grep -qF "$a/spec" <<<"$oa" || ! grep -qF "$a/prd.md" <<<"$oa" \
     || ! grep -qF "$a/story.md" <<<"$oa" || ! grep -qF "$a/spine.md" <<<"$oa" \
     || ! grep -qF "$a/lint.json" <<<"$oa" || ! grep -qF "$a/trace.json" <<<"$oa"; then
    SJ_IDENT_WHY="run A does not name all six of the spec dir, PRD, story, spine, lint envelope and trace verdict"
    return 1
  fi
  if ! grep -qF "$b/spec" <<<"$ob" || ! grep -qF "$b/prd.md" <<<"$ob" \
     || ! grep -qF "$b/story.md" <<<"$ob" || ! grep -qF "$b/spine.md" <<<"$ob" \
     || ! grep -qF "$b/lint.json" <<<"$ob" || ! grep -qF "$b/trace.json" <<<"$ob"; then
    SJ_IDENT_WHY="run B does not name all six of the spec dir, PRD, story, spine, lint envelope and trace verdict"
    return 1
  fi
  if grep -qF "$b" <<<"$oa"; then
    SJ_IDENT_WHY="run A's output carries run B's root — the paths are not the ones it resolved"
    return 1
  fi
  return 0
}

if sj_ident_holds "$V"; then
  ok "IDENTITY: the PASS line names all six inputs it joined — spec dir, PRD, story, spine, lint envelope and trace verdict — and two identical corpora in different trees are distinguishable"
else
  bad "IDENTITY: the PASS line carries no corpus identity — $SJ_IDENT_WHY. A join against another sprint's spec reports the same green tally as one against this sprint's"
fi

# THE UNMUTATED CONTROL, with a positive conjunct. The mutants below are copies placed in
# $R; a copy that could not run would emit nothing, and "no output" would otherwise score
# as a kill. `sj_ident_holds` demands a PASS line and three paths, so this control cannot
# pass against a copy replaced by `exit 0`.
SJ_CTL="$R/ident-control.sh"; cp "$V" "$SJ_CTL"
SJ_CTL_OK=0
if sj_ident_holds "$SJ_CTL"; then
  ok "IDENTITY CONTROL: an unmutated copy reproduces the identity lines, so a mutant's silence below means mutation and not breakage"
  SJ_CTL_OK=1
else
  bad "IDENTITY CONTROL FAILED ($SJ_IDENT_WHY) — the two identity mutants below are uninterpretable"
fi

if [ "$SJ_CTL_OK" = "1" ]; then
  # MUTANT ident-drop: the identity BLOCK deleted — the state this release replaced.
  #
  # ANCHORED ON THE PASS LINE, NOT ON THE SIX LABELS. Three of the six sit at column 0 and
  # three are indented two spaces, so a label-keyed deletion needs six literals and six
  # uniqueness guards, every one of which goes stale on a respacing. The verdict sentence is
  # the emitter's own text and is unique to this site, so the mutation follows the block
  # however the labels move — and the count guard below is what stops the block silently
  # shrinking under the arms that assert all six.
  SJ_MD="$R/ident-mutant-drop.sh"
  sj_av=': PASS ($NLRS locked requirement(s)'
  sj_nid="$(grep -cE '^ *echo "  ' "$V")"
  if [ "$(grep -cF "$sj_av" "$V")" != "1" ]; then
    bad "FIXTURE ERROR: mutation 'ident-drop' has a non-unique anchor — the deletion could land on another emitter"
  elif [ "$sj_nid" -lt 6 ]; then
    bad "FIXTURE ERROR: only $sj_nid identity lines follow the PASS verdict, expected 6 — the block this fixture guards has shrunk and the IDENTITY arm may be asserting a subset"
  else
    awk -v A="$sj_av" '
      index($0, A)          { print; hit=1; next }
      hit && /^ *echo "  /  { next }
                            { hit=0; print }
    ' "$V" > "$SJ_MD"
    if cmp -s "$V" "$SJ_MD"; then
      bad "FIXTURE ERROR: mutation 'ident-drop' matched nothing — its assertion would prove nothing"
    elif ! bash -n "$SJ_MD" 2>/dev/null; then
      bad "FIXTURE ERROR: mutant 'ident-drop' is not a valid shell script — its silence is not a kill"
    else
      if sj_ident_holds "$SJ_MD"; then
        bad "MUTATION 'ident-drop' SURVIVED — a validator naming no corpus still satisfies the IDENTITY arm, so that arm is not testing the identity lines"
      else
        ok "MUTATION 'ident-drop': deleting the identity lines makes two different trees indistinguishable ($SJ_IDENT_WHY) — the IDENTITY arm has teeth"
      fi
      # The lines are additive. Every verdict arm above must survive their removal, or the
      # IDENTITY arm is entangled with the joins that carry this check.
      bash "$SJ_MD" --spec "$R/ok" --prd "$R/prd-ok.md" --story "$R/story-ok.md" >/dev/null 2>&1
      sj_g1=$?
      bash "$SJ_MD" --spec "$R/ok" --prd "$R/prd-ok.md" --story "$R/story-dangling.md" >/dev/null 2>&1
      sj_g2=$?
      bash "$SJ_MD" --spec "$R/no-caps" --prd "$R/prd-ok.md" >/dev/null 2>&1
      sj_g3=$?
      if [ "$sj_g1" -eq 0 ] && [ "$sj_g2" -eq 1 ] && [ "$sj_g3" -eq 2 ]; then
        ok "MUTATION 'ident-drop' leaves the PASS, FAIL and DISARM verdicts intact — corpus identity is asserted by an arm no join arm covers"
      else
        bad "MUTATION 'ident-drop' ALSO moved a verdict (rc=$sj_g1/$sj_g2/$sj_g3) — the identity lines are not additive and the IDENTITY arm is entangled"
      fi
    fi
  fi

  # MUTANT ident-nonce: identity replaced by a per-run nonce — THE FIX THAT DISCRIMINATES
  # WITHOUT NAMING. `$$-$RANDOM` is evaluated by the mutant at run time, so its two runs
  # differ exactly as the real validator's do while naming no file at all. An arm keyed
  # only on "the outputs differ" passes against it; this one must not.
  SJ_MN="$R/ident-mutant-nonce.sh"
  awk -v A="$sj_av" '
    index($0, A)          { print; hit=1; next }
    hit && /^ *echo "  /  { print "echo \"  nonce: $$-$RANDOM\""; next }
                          { hit=0; print }
  ' "$V" > "$SJ_MN"
  if cmp -s "$V" "$SJ_MN"; then
    bad "FIXTURE ERROR: mutation 'ident-nonce' matched nothing — the IDENTITY arm's nonce-resistance is unproved"
  elif ! bash -n "$SJ_MN" 2>/dev/null; then
    bad "FIXTURE ERROR: mutant 'ident-nonce' is not a valid shell script — its silence is not a kill"
  else
    if sj_ident_holds "$SJ_MN"; then
      bad "MUTATION 'ident-nonce' SURVIVED — a per-run nonce naming no corpus satisfies the IDENTITY arm, so that arm is a differ-check and not a naming check"
    else
      ok "MUTATION 'ident-nonce': a per-run nonce varies the output exactly as the real paths do and still fails the IDENTITY arm ($SJ_IDENT_WHY) — the arm demands the corpus be NAMED"
    fi
  fi
fi

echo
if [ "$rc" -eq 0 ]; then echo "spec-join-integrity: PASS"; else echo "spec-join-integrity: FAILED" >&2; fi
exit $rc
