#!/usr/bin/env bash
# stray-party-mode-provenance/run.sh — prove the corpus-wide party-mode floor.
#
# WHY THIS EXISTS. Every other reader of SKILL_INVOCATION_PROVENANCE is handed ONE artifact by a
# gate that already decided the artifact is in scope, and the scope rule deliberately forgives
# historical informational blocks so an ever-growing tree does not brick every sprint. A party-mode
# block RELOCATED to a file with no pipeline-validation purpose — the shape that evades the retro's
# transcript-SHA match — is invisible to all of them, precisely because the file it moved to is
# never in anyone's scope. `--strays` is the floor under that carve-out.
#
# WHAT THE MUTANTS DEFEND. Three of this check's four ways to go quiet are silent: the
# generated-region carve-out can stop matching (and then core's own taught example reports as a
# forgery, which trains the operator to switch the scan off), the trailing-comment rule can be
# dropped (and then every block copied from the taught example stops being recognised at all), and
# the subject vocabulary can go empty (and then the scan reports PASS on every tree there is).
# None of the three changes the exit code on a clean tree.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

OUT="$WORK/out.txt"
ERR="$WORK/err.txt"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
broken() { printf '  FAIL  %s\n' "$1" >&2; echo; echo "stray-party-mode-provenance: FIXTURE BROKEN" >&2; exit 2; }

# scan <validator> <schema> <ext-or-empty> [<explicit path>...]
# The schema is swapped into the seeded project because the resolver has no schema override, and
# restored to the control copy afterwards so no assertion can inherit the previous one's mutation.
scan() {
  local v="$1" s="$2" e="$3"; shift 3
  cp "$s" "$SCHEMA" || broken "could not stage schema $s"
  if [ "$#" -gt 0 ]; then
    AI_DLC_PROJECT_ROOT="$PROJ" AI_DLC_KNOWN_SKILLS_EXT="$e" bash "$v" --strays "$@" >"$OUT" 2>"$ERR"
  else
    AI_DLC_PROJECT_ROOT="$PROJ" AI_DLC_KNOWN_SKILLS_EXT="$e" bash "$v" --strays >"$OUT" 2>"$ERR"
  fi
  RC=$?
  cp "$CONTROL_SCHEMA" "$SCHEMA" || broken "could not restore the control schema"
}

# Reported/not-reported are asked about ONE path, never about the finding count, so a mutant that
# changes an unrelated file's verdict cannot satisfy another mutant's assertion.
reported()     { grep -qF "STRAY PARTY-MODE PROVENANCE: $1 [skill:" "$ERR"; }
findings()     { grep -cF "STRAY PARTY-MODE PROVENANCE: " "$ERR" 2>/dev/null || true; }

echo "stray-party-mode-provenance:"

# --- Assertion 0: the UNMUTATED CONTROL COPY behaves like the in-tree script ---
# A lone copy that dies sourcing its own preamble emits nothing, and "no output" scores as a kill
# for every mutant at once. This runs the control first and refuses to believe any mutant until it
# has produced the exact baseline.
scan "$CONTROL_VALIDATOR" "$CONTROL_SCHEMA" ""
[ "$RC" -eq 1 ] || broken "the unmutated control copy exited $RC on the seeded tree, want 1 — the mutants below would score its silence as a kill"
reported "server/handler.py"   || broken "the control copy did not report server/handler.py; every negative assertion below would pass vacuously"
reported "server/commented.py" || broken "the control copy did not report server/commented.py"
[ "$(findings)" -eq 2 ] || broken "the control copy reported $(findings) finding(s), want exactly 2"
ok "the unmutated control copy reports exactly the two service-file strays (exit 1)"

# --- Assertion 1: a party-mode block in each declared home is NOT a finding ----
scan "$VALIDATOR" "$CONTROL_SCHEMA" ""
h_bad=""
for h in docs/retro/sprint-1.md _bmad-output/party-mode-transcripts/s1-retro.md docs/reviews/adversarial-1.md; do
  reported "$h" && h_bad="$h_bad $h"
done
[ -z "$h_bad" ] && ok "a party-mode block in a declared home (retro, party-mode-transcripts, reviews) is not a finding" \
  || bad "declared homes reported as strays:$h_bad"

# --- Assertion 2: an INFORMATIONAL block outside every home is NOT a finding ---
reported "server/informational.py" \
  && bad "an informational (non-party-mode) block was reported — the scan is re-litigating the current-scope carve-out it exists to sit under" \
  || ok "an informational block in a service file is not a finding (only party-mode is in the subject set)"

# --- Assertion 3: a party-mode block inside a GENERATED REGION is not a finding -
reported "docs/taught.md" \
  && bad "the rendered taught example was reported as a stray" \
  || ok "a party-mode block inside a generated region is not a finding (the region IS the schema)"

# --- Assertion 4: a fixture home is a home under a default whole-tree scan -----
reported "tests/fixtures/forgery-corpus/forged.md" \
  && bad "a fixture's deliberately-forged block was reported by the default scan" \
  || ok "a forged block under a fixture home is not a finding in a default scan (forgeries ARE the test data)"

# --- Assertion 5: naming a fixture path EXPLICITLY drops the fixture exclusion -
scan "$VALIDATOR" "$CONTROL_SCHEMA" "" "tests/fixtures/forgery-corpus/forged.md"
{ [ "$RC" -eq 1 ] && reported "tests/fixtures/forgery-corpus/forged.md"; } \
  && ok "an explicitly-named fixture path IS scanned (a test can point the scanner at a crafted stray and get an answer)" \
  || bad "an explicitly-named fixture path was still excluded (rc=$RC)"

# --- Assertion 6: the consumer extension adds a home --------------------------
scan "$VALIDATOR" "$CONTROL_SCHEMA" "$EXT_ADDS_SERVER"
[ "$RC" -eq 0 ] && ok "extensions/known-skills.json 'party_mode_homes' adds a home; the tree comes back PASS" \
  || bad "the consumer home extension did not take effect (rc=$RC)"

# --- Assertion 7: a malformed party_mode_homes FAILS CLOSED -------------------
scan "$VALIDATOR" "$CONTROL_SCHEMA" "$EXT_MALFORMED_TYPE"
{ [ "$RC" -eq 2 ] && grep -qF "party_mode_homes" "$ERR"; } \
  && ok "a party_mode_homes that is not a list of patterns fails closed (exit 2), never degrades to core-only homes" \
  || bad "a malformed party_mode_homes did not fail closed (rc=$RC)"

# --- Assertion 8: an unsupported pattern form FAILS CLOSED -------------------
scan "$VALIDATOR" "$CONTROL_SCHEMA" "$EXT_BAD_GLOB"
{ [ "$RC" -eq 2 ] && grep -qF "unsupported home pattern" "$ERR"; } \
  && ok "a home pattern that is neither '<dir>/**' nor an exact path is an error, not a silent non-match" \
  || bad "an unsupported home pattern did not fail closed (rc=$RC)"

# --- MUTATION 1: the generated-region marker drifts ---------------------------
# Asserts on the TAUGHT FILE alone. The two service strays are reported either way, so this cannot
# be satisfied by a mutant that merely breaks the scan.
scan "$MUT_REGION" "$CONTROL_SCHEMA" ""
reported "docs/taught.md" \
  && ok "MUTANT (region marker drifts to a second spelling): the rendered taught example is reported as a forgery — the carve-out is what stops that" \
  || bad "MUTANT SURVIVED: the region marker drifted and the taught example was still exempt; the carve-out is not doing the work"

# --- MUTATION 2: the trailing-comment rule is dropped -------------------------
# Asserts the comment-carrying stray goes UNSEEN while the bare one is still seen. The second half
# is what separates this mutant from one that simply kills the scan.
scan "$MUT_COMMENT" "$CONTROL_SCHEMA" ""
{ ! reported "server/commented.py" && reported "server/handler.py"; } \
  && ok "MUTANT (trailing-comment rule dropped): a block copied from the taught example goes unseen while a bare one is still caught — the strip is what reaches the copied form" \
  || bad "MUTANT SURVIVED: dropping the trailing-comment rule changed nothing about the comment-carrying stray"

# --- MUTATION 3: a declared home is removed from the schema ------------------
scan "$VALIDATOR" "$SCHEMA_NO_RETRO" ""
reported "docs/retro/sprint-1.md" \
  && ok "MUTANT (docs/retro/** removed from homes): the retro document is reported — the homes list is read from the schema, not assumed" \
  || bad "MUTANT SURVIVED: removing docs/retro/** from homes did not make the retro document a finding"

# --- MUTATION 4: the subject vocabulary is emptied ---------------------------
scan "$VALIDATOR" "$SCHEMA_NO_SKILLS" ""
{ [ "$RC" -eq 2 ] && grep -qF "vacuous" "$ERR"; } \
  && ok "MUTANT (party_mode_skills emptied): the scan refuses to run rather than reporting PASS on a tree it cannot judge" \
  || bad "MUTANT SURVIVED: an empty subject vocabulary produced rc=$RC instead of a loud refusal"

# --- Assertion 9: the tree the fixture ran against is unchanged --------------
# The schema is swapped in and out around every scan; a restore that silently failed would leave
# later assertions running against a mutant's schema, which is the entanglement that makes one
# assertion vacuous.
cmp -s "$CONTROL_SCHEMA" "$SCHEMA" \
  && ok "the seeded project's schema is byte-identical to the control after every swap" \
  || bad "the seeded schema was left mutated; assertions after the first mutation were not testing what they claim"

echo
if [ "$fails" -eq 0 ]; then echo "stray-party-mode-provenance: PASS"; exit 0; fi
echo "stray-party-mode-provenance: $fails assertion(s) FAILED" >&2
exit 1
