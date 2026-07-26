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

want 1 "join (2): a capability absent from the FR Coverage Map FAILS" \
  --spec "$R/ok" --prd "$R/prd-missing-cap.md"

want 1 "join (3): a story citing an undefined CAP FAILS" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --story "$R/story-dangling.md"

want 1 "a story with no capabilities: field FAILS (the field IS the link)" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --story "$R/story-nofield.md"

want 2 "DISARM: a zero-capability kernel exits 2, never 0" \
  --spec "$R/no-caps" --prd "$R/prd-ok.md"

want 2 "DISARM: a PRD with no FR Coverage Map exits 2, never 0" \
  --spec "$R/ok" --prd "$R/prd-no-map.md"

want 1 "borrowed verdict: lint_spine ad_fields findings FAIL the gate" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine-lint "$R/spine-bad.json"

want 0 "OVER-FIRE CONTROL: a clean lint_spine JSON passes" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --spine-lint "$R/spine-ok.json"

want 1 "borrowed verdict: a trace decision of FAIL fails the gate" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --trace-verdict "$R/trace-fail.txt"

want 0 "a trace decision of CONCERNS passes" \
  --spec "$R/ok" --prd "$R/prd-ok.md" --trace-verdict "$R/trace-concerns.txt"

if bash "$V" --spec "$R/ok" --prd "$R/prd-ok.md" --trace-verdict "$R/trace-concerns.txt" 2>&1 | grep -q 'note'; then
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

echo
if [ "$rc" -eq 0 ]; then echo "spec-join-integrity: PASS"; else echo "spec-join-integrity: FAILED" >&2; fi
exit $rc
