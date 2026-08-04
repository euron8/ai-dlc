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
else
  ok "trichotomy: the EMPTY case is NOT told the field is absent"
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

mut lr-off "grep -qE '\\bCAP-[0-9]+\\b'" "true" \
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

echo
if [ "$rc" -eq 0 ]; then echo "spec-join-integrity: PASS"; else echo "spec-join-integrity: FAILED" >&2; fi
exit $rc
