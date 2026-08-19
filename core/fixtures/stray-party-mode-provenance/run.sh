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
#
# The fourth way is not about what a block SAYS but about where the caller says the file IS. The
# homes are matched against the candidate path as a string, so the answer depends on how the path
# was spelled — and that goes wrong in both directions, silently in one of them. The S-arms below
# are that half; their section header states the two shapes and which branch of the validator each
# one reaches. MUT-E defends the arm that is green today: the home match must stay a PREFIX, because
# a substring match turns every file of a project checked out at docs/retro/<name>/ into a home.
# MUT-E's subject was chosen the hard way -- an earlier version of it went vacuous against a
# candidate fix and reported MUTANT SURVIVED. The paragraph beside it says why, and says not to
# re-aim it; read that before simplifying it.
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

# scan_at <cwd> <root> <validator> <schema> <ext-or-empty> [<explicit path>...]
# scan() fixes both the project root and the caller's working directory. Path spelling is the
# subject here, and a spelling only means something relative to a cwd and a root, so those two
# have to be arguments. The cd is subshelled: the Bash tool's shell carries a cd across calls
# and a leaked one would relocate every later assertion.
scan_at() {
  local c="$1" r="$2" v="$3" s="$4" e="$5"; shift 5
  local sch="$r/.claude/schemas/provenance-block.json"
  cp "$s" "$sch" || broken "could not stage schema $s into $r"
  if [ "$#" -gt 0 ]; then
    ( cd "$c" && AI_DLC_PROJECT_ROOT="$r" AI_DLC_KNOWN_SKILLS_EXT="$e" bash "$v" --strays "$@" ) >"$OUT" 2>"$ERR"
  else
    ( cd "$c" && AI_DLC_PROJECT_ROOT="$r" AI_DLC_KNOWN_SKILLS_EXT="$e" bash "$v" --strays ) >"$OUT" 2>"$ERR"
  fi
  RC=$?
  cp "$CONTROL_SCHEMA" "$sch" || broken "could not restore the control schema in $r"
}

# Reported/not-reported are asked about ONE path, never about the finding count, so a mutant that
# changes an unrelated file's verdict cannot satisfy another mutant's assertion.
reported()     { grep -qF "STRAY PARTY-MODE PROVENANCE: $1 [skill:" "$ERR"; }
# reported_any asks whether the finding NAMES this file, whatever spelling the scanner echoed
# back. `reported` anchors on the message prefix and so answers NO for a correctly-reported
# stray that was named through `..` or an absolute path — which is the very thing the
# path-spelling arms below are asking about, and anchoring there would have them assert a
# spelling instead of a verdict.
reported_any() { grep -qF "$1 [skill:" "$ERR"; }
# The count in the PASS line is the only observable that separates "scanned it and it was a
# home" from "resolved to nothing and had nothing to say". Every rc=0 arm below carries it,
# because rc=0-with-no-findings is exactly what a subject replaced by `exit 0` produces.
scanned_count() { sed -n 's/^--strays: PASS (.*; \([0-9][0-9]*\) file(s) carried the envelope)$/\1/p' "$OUT"; }
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

# =============================================================================
# PATH-SPELLING. The homes are judged against the candidate path as a STRING, and the only
# normalisation anywhere is a leading `./`. That makes the answer a property of how the caller
# SPELLED the path rather than of which file it is, and it goes wrong in BOTH directions:
#
#   FALSE STRAY  a declared home named absolutely, or with a doubled slash, misses every home
#                and is reported as out of place.
#   FALSE PASS   a genuine stray reached through `..`, or named from a subdirectory, is either
#                accepted as a home or resolves to nothing — and the scan answers PASS.
#
# The second is the one that matters and it is the one that was not filed. The default
# whole-tree branch forces the scan root to `.` under a comment naming this exact hazard, so it
# is the ONE branch where the hazard cannot bite; the explicit-path branch hands the caller's
# paths to grep verbatim. Every arm below drives the shipping validator against a seeded tree
# and reads its verdict — none of them greps the script for a normalising call, which a comment
# satisfies and a rename defeats.
#
# CWD. `scan_at` takes the caller's working directory as an argument because a relative spelling
# has no meaning without one, and the validator cds to its own resolved root before globbing —
# so a caller's relative path is resolved against the ROOT, not against the caller. The arms
# that depend on a cwd say which one; S8 asserts that the arms which should NOT depend on one
# do not.
# =============================================================================

# --- SELF-PROBE: these helpers can produce a finding, in both directions -------
# Runs before any path-spelling assertion. A probe on the seeded corpus alone would be the
# corpus answering for itself; this fires the two helpers the section is built on — one that
# must SEE a stray and one that must count a scanned home — and refuses to continue if either
# is silent. Both directions, because a helper that reports everything and a helper that
# discriminates read identically from one call.
[ -d "$NESTED" ] || broken "the nested checkout was not seeded; every substring arm below would be vacuous"
scan_at "$NESTED" "$NESTED" "$CONTROL_VALIDATOR" "$CONTROL_SCHEMA" "" server/x.py
{ [ "$RC" -eq 1 ] && reported_any "server/x.py"; } \
  || broken "SELF-PROBE (positive): the control copy did not report the nested stray it was pointed at (rc=$RC); the path-spelling arms cannot fire"
scan_at "$PROJ" "$PROJ" "$CONTROL_VALIDATOR" "$CONTROL_SCHEMA" "" docs/retro/sprint-1.md
{ [ "$RC" -eq 0 ] && [ "$(scanned_count)" = "1" ]; } \
  || broken "SELF-PROBE (negative): a relatively-spelled home did not come back PASS-over-1-file (rc=$RC, count='$(scanned_count)'); the quiet direction is unreadable"
ok "SELF-PROBE: the arm can produce a finding, and can count a file it scanned and cleared"

# --- S1: a declared home named ABSOLUTELY is not a stray ----------------------
# The filed direction. `$PROJ` is a mktemp path, which on Darwin is under /var/folders — a
# SYMLINK to /private/var. That symlink is an input to this defect, not noise: S1 spells the
# root and the candidate the same way, S2 spells them differently, and a fix that resolves one
# side only closes exactly one of them.
[ -f "$PROJ/docs/retro/sprint-1.md" ] || broken "S1 premise: the home file is not where the arm thinks it is"
scan_at "$PROJ" "$PROJ" "$VALIDATOR" "$CONTROL_SCHEMA" "" "$PROJ/docs/retro/sprint-1.md"
{ [ "$RC" -eq 0 ] && [ "$(scanned_count)" = "1" ]; } \
  && ok "S1 a declared home named by absolute path is not a stray (and the file was actually scanned)" \
  || bad "S1 a declared home named ABSOLUTELY was reported as a stray (rc=$RC, scanned='$(scanned_count)') — the home match reads the spelling, not the file"

# --- S2: the two spellings of one mktemp path must agree ----------------------
PHYS="$(cd "$PROJ" && pwd -P)"
[ -n "$PHYS" ] || broken "S2 premise: could not resolve the physical path of the seeded project"
if [ "$PHYS" = "$PROJ" ]; then
  ok "S2 SKIP: \$TMPDIR is not symlinked on this host, so the two spellings are one (no subject)"
else
  scan_at "$PROJ" "$PROJ" "$VALIDATOR" "$CONTROL_SCHEMA" "" "$PHYS/docs/retro/sprint-1.md"
  { [ "$RC" -eq 0 ] && [ "$(scanned_count)" = "1" ]; } \
    && ok "S2 a home named through the PHYSICAL path of a symlinked root is not a stray" \
    || bad "S2 a home named /private/... under a root spelled /var/... was reported as a stray (rc=$RC, scanned='$(scanned_count)') — a fix that resolves the candidate but not the root leaves this open"
  scan_at "$PHYS" "$PHYS" "$VALIDATOR" "$CONTROL_SCHEMA" "" "$PROJ/docs/retro/sprint-1.md"
  { [ "$RC" -eq 0 ] && [ "$(scanned_count)" = "1" ]; } \
    && ok "S2b and the same disagreement the other way round (root physical, candidate symlinked)" \
    || bad "S2b a home named /var/... under a root spelled /private/... was reported as a stray (rc=$RC, scanned='$(scanned_count)')"
fi

# --- S3: a doubled slash inside a home spelling -------------------------------
scan_at "$PROJ" "$PROJ" "$VALIDATOR" "$CONTROL_SCHEMA" "" "docs//retro/sprint-1.md"
{ [ "$RC" -eq 0 ] && [ "$(scanned_count)" = "1" ]; } \
  && ok "S3 a home named with a doubled slash is not a stray" \
  || bad "S3 docs//retro/sprint-1.md was reported as a stray (rc=$RC, scanned='$(scanned_count)') — one redundant separator moves a file out of its own home"

# --- S4: a genuine stray reached through `..` is STILL REPORTED ---------------
# THE FALSE-PASS DIRECTION. `docs/retro/../../server/handler.py` is server/handler.py, and it
# begins with the `docs/retro/` prefix, so the home match accepts it and the scan answers PASS
# over a stray that is sitting right there. A fix that only widens the home match to close S1
# leaves this open, or widens it further and makes it worse.
[ -f "$PROJ/docs/retro/../../server/handler.py" ] || broken "S4 premise: the traversal does not reach the stray"
scan_at "$PROJ" "$PROJ" "$VALIDATOR" "$CONTROL_SCHEMA" "" "docs/retro/../../server/handler.py"
{ [ "$RC" -ne 0 ] && reported_any "server/handler.py"; } \
  && ok "S4 a stray reached through a home-prefixed .. traversal is still reported" \
  || bad "S4 FALSE PASS: a genuine stray named docs/retro/../../server/handler.py was declared clean (rc=$RC) — the home prefix was matched against a path that only passes THROUGH the home"

# --- S4b: the SAME traversal through a NON-home prefix ------------------------
# S4's control, and it is what makes S4 a statement about the home match rather than about `..`.
# Before the paths were resolved these two spellings of one file gave OPPOSITE answers — through
# `docs/retro/` it was excused, through `server/` it was reported — so a fixture carrying only
# one of them cannot tell "the home prefix excused it" from "traversal breaks the scanner".
scan_at "$PROJ" "$PROJ" "$VALIDATOR" "$CONTROL_SCHEMA" "" "server/../server/handler.py"
{ [ "$RC" -ne 0 ] && reported_any "server/handler.py"; } \
  && ok "S4b the same file reached through a NON-home prefix is reported too (S4 is about the home match, not about ..)" \
  || bad "S4b a stray named server/../server/handler.py was not reported (rc=$RC) — S4 cannot be read as a statement about the home prefix"

# --- S4c: the traversal through a SECOND declared home ------------------------
# One home entry being wrong is a typo; every home entry being wrong is the match itself. This
# uses `_bmad-output/**`, which is a different schema entry reached by the same code path.
scan_at "$PROJ" "$PROJ" "$VALIDATOR" "$CONTROL_SCHEMA" "" "_bmad-output/../server/handler.py"
{ [ "$RC" -ne 0 ] && reported_any "server/handler.py"; } \
  && ok "S4c a stray reached through a SECOND declared home is reported (the defect was the match, not one entry)" \
  || bad "S4c FALSE PASS: a genuine stray named _bmad-output/../server/handler.py was declared clean (rc=$RC)"

# --- S5: a caller in a subdirectory must not get a silent clean run -----------
# The validator cds to its own root before globbing, so a path spelled relative to the CALLER's
# directory resolves to nothing, grep is silenced by 2>/dev/null, and the summary reports PASS
# over zero files. The script refuses exactly this for the root ("a corpus scan with no corpus
# reports PASS on everything; refusing to") and does not refuse it per path. Either verdict is
# acceptable here — report the stray, or fail loudly — and PASS is not.
[ -f "$PROJ/docs/../server/handler.py" ] || broken "S5 premise: ../server/handler.py does not resolve from \$PROJ/docs"
scan_at "$PROJ/docs" "$PROJ" "$VALIDATOR" "$CONTROL_SCHEMA" "" "../server/handler.py"
{ [ "$RC" -ne 0 ] && grep -qE 'handler\.py|FAIL' "$ERR"; } \
  && ok "S5 a stray named relative to the caller's own directory does not come back PASS" \
  || bad "S5 FALSE PASS: a caller in \$PROJ/docs named ../server/handler.py — a real stray at that cwd — and got rc=$RC over $(scanned_count) file(s); a scan told to look at named subjects and finding none of them must not answer clean"

# --- S6: a genuine stray named ABSOLUTELY is still reported -------------------
# The negative control for the whole section. Without it every arm above is satisfied by a fix
# that stops reporting anything, which is what "normalise the paths" looks like when it is
# implemented as "accept them".
scan_at "$PROJ" "$PROJ" "$VALIDATOR" "$CONTROL_SCHEMA" "" "$PROJ/server/handler.py"
{ [ "$RC" -eq 1 ] && reported_any "server/handler.py"; } \
  && ok "S6 a genuine stray named by absolute path is still reported (the fix is not a disarm)" \
  || bad "S6 an absolutely-named genuine stray was NOT reported (rc=$RC) — the scan has been widened into silence"

# --- S7: a project checked out UNDER a home-spelled path ---------------------
# `$WORK/docs/retro/nested-checkout` is its own project root. Nothing in it is a home: its
# repo-relative layout is server/ and lib/. Its ABSOLUTE path contains `docs/retro/` before the
# root even starts, so a home match that looks for the pattern anywhere accepts the whole
# checkout. Green today; MUT-E below is what proves it can fire.
scan_at "$NESTED" "$NESTED" "$VALIDATOR" "$CONTROL_SCHEMA" "" "$NESTED/server/x.py"
{ [ "$RC" -eq 1 ] && reported_any "server/x.py"; } \
  && ok "S7 a stray in a checkout that LIVES at docs/retro/<name>/ is reported (the home is a location, not a substring)" \
  || bad "S7 FALSE PASS: a stray under a checkout at docs/retro/<name>/ was accepted as a home (rc=$RC)"

# --- S7b: a directory INSIDE the repo spelled like a home, but not at one ----
# `vendor/docs/retro/inner.md` contains the home pattern and does not begin with it. Unlike S7
# this survives normalisation — after the caller's paths are resolved to repo-relative form the
# nested checkout's stray no longer carries a home substring, and this one still does. It is the
# subject MUT-E needs in order to keep guarding a FIXED validator rather than a broken one.
scan_at "$NESTED" "$NESTED" "$VALIDATOR" "$CONTROL_SCHEMA" "" "$NESTED/vendor/docs/retro/inner.md"
{ [ "$RC" -eq 1 ] && reported_any "vendor/docs/retro/inner.md"; } \
  && ok "S7b a stray under vendor/docs/retro/ is reported; a home is a place the path STARTS, not one it contains" \
  || bad "S7b FALSE PASS: vendor/docs/retro/inner.md was accepted as a home (rc=$RC) — the home pattern was found mid-path"

# --- (no S10) case-variant spellings are a FILED DEFECT, not an arm ----------
# `DOCS/retro/sprint-1.md` and `docs/retro/sprint-1.md` are ONE FILE where the filesystem folds
# case, and this repo's development host is one. `realpath` resolves symlinks and `..` and does
# NOT fold case, so the case-variant spelling of a declared home keeps the caller's spelling,
# misses the home, and is reported as a stray. Measured, with the correct-case spelling as the
# control in the same run. Filed as BL-082; deliberately not asserted here.
#
# THE OBVIOUS REMEDY IS FORBIDDEN. Folding case in the home match closes it on a case-folding
# filesystem and OPENS A FALSE PASS on a case-sensitive one, where `DOCS/retro/` can be a
# genuinely distinct directory that would then be accepted as the declared home — a false STRAY
# traded for a false PASS, on the platform a consumer's CI actually runs. A per-component
# case-canonicalising walk is only correct on the folding filesystem, so no remedy is right on
# both. That is what makes it a filed defect rather than a fix, and it is why there is a gap
# here instead of an arm.

# --- S9: a SYMLINK named on the command line -----------------------------------
# The last member of the zero-candidate class, and the one an existence test cannot see. A test
# for existence FOLLOWS a symlink, so a link to a real file passes it; `grep -rlI` does not
# descend a symlink it was handed, so the scan gets no candidate and answers PASS over a stray it
# was pointed directly at. The two instruments disagree about whether there was anything to scan
# and the disagreement resolves to "clean". The control is in the same invocation shape: the same
# stray named through the symlink's TARGET is reported, so this is a property of the spelling.
[ -L "$NESTED/link-to-stray.py" ] || broken "S9 premise: the file symlink was not seeded"
scan_at "$NESTED" "$NESTED" "$VALIDATOR" "$CONTROL_SCHEMA" "" "server/x.py"
{ [ "$RC" -eq 1 ] && reported_any "server/x.py"; } \
  || broken "S9 control: the symlink's TARGET is not reported by name, so S9 cannot distinguish a spelling from a clean tree"
scan_at "$NESTED" "$NESTED" "$VALIDATOR" "$CONTROL_SCHEMA" "" "link-to-stray.py"
{ [ "$RC" -ne 0 ] && grep -qE 'x\.py|FAIL' "$ERR"; } \
  && ok "S9 a stray named through a symlink does not come back PASS" \
  || bad "S9 FALSE PASS: link-to-stray.py points at a reported stray in the same project and came back rc=$RC over $(scanned_count) file(s) — an existence test follows the link and the scanner does not, and the disagreement resolves to clean"

# --- S9b: the same, for a symlink to a DIRECTORY ------------------------------
[ -L "$NESTED/link-to-serverdir" ] || broken "S9b premise: the directory symlink was not seeded"
scan_at "$NESTED" "$NESTED" "$VALIDATOR" "$CONTROL_SCHEMA" "" "link-to-serverdir"
{ [ "$RC" -ne 0 ] && grep -qE 'x\.py|FAIL' "$ERR"; } \
  && ok "S9b a directory named through a symlink does not come back PASS" \
  || bad "S9b FALSE PASS: link-to-serverdir is the server/ directory and came back rc=$RC over $(scanned_count) file(s); naming server/ directly reports its stray"

# --- MUTATION 5: the home match widens from a prefix to a substring ----------
# The tempting wrong fix for S1: "the absolute path contains the home, so it is a home." Two
# runs, because the kill is absence-shaped and an absence is also what a dead copy produces.
# The first asks that the widening swallowed S7b's subject; the second asks, from the SAME
# mutant, that a stray no home substring can reach is still reported — which a copy that died
# on its own preamble cannot satisfy.
#
# DO NOT RE-AIM THIS MUTANT AT S7. It was written against S7 first and that version SURVIVED,
# measured against a candidate fix before the shipped one landed, and the three parts of that
# are worth more than the arm itself:
#
#   WHAT IT WAS.  The mutation was the same one it is now -- `rel.startswith(prefix)` widened to
#     `prefix in rel` -- but the subject was the nested checkout's `server/x.py`, named by its
#     ABSOLUTE path. That path contains `docs/retro/` because of where the checkout SITS, so
#     under the widening it was accepted and the kill scored.
#   WHY THE FIX MADE IT VACUOUS.  The fix resolves every candidate to a root-relative path before
#     the home match sees it, and that is exactly the step that removes `docs/retro/` from the
#     nested checkout's spelling. Post-fix the mutation flips no verdict on that subject, so the
#     arm reports MUTANT SURVIVED -- and had the arm been written the other way round it would
#     have reported a clean kill it did not earn. A guard turned into a tautology by the very
#     change it exists to guard, going green while claiming to defend it.
#   WHAT THE RETARGET IS KEYED ON.  `vendor/docs/retro/inner.md` is a path whose root-relative
#     form CONTAINS a home pattern and does not BEGIN with one. Canonicalisation cannot remove
#     that -- it is where the file actually is -- so prefix and substring disagree about it
#     before and after any normalisation anyone adds later.
#
# The rule that generalises: a mutant keyed on a SPELLING is only as durable as the spelling, and
# a fix that normalises spellings will disarm it silently. Key it on a LOCATION instead.
scan_at "$NESTED" "$NESTED" "$MUT_SUBSTR" "$CONTROL_SCHEMA" "" "$NESTED/vendor/docs/retro/inner.md"
mut_e_accepted=1; { [ "$RC" -eq 0 ] && ! reported_any "vendor/docs/retro/inner.md"; } || mut_e_accepted=0
scan_at "$PROJ" "$PROJ" "$MUT_SUBSTR" "$CONTROL_SCHEMA" "" "server/handler.py"
mut_e_alive=0; { [ "$RC" -eq 1 ] && reported_any "server/handler.py"; } && mut_e_alive=1
{ [ "$mut_e_accepted" -eq 1 ] && [ "$mut_e_alive" -eq 1 ]; } \
  && ok "MUTANT (home match widened to a substring): vendor/docs/retro/inner.md is swallowed while a stray carrying no home substring is still caught — S7b is what stops that fix" \
  || bad "MUTANT SURVIVED: widening the home match to a substring did not change the nested checkout's verdict (accepted=$mut_e_accepted, still-alive=$mut_e_alive)"

# --- S8: the arms that must not depend on a cwd, do not ----------------------
# A fixture green only from one directory may be asserting nothing there. The whole-tree scan
# takes no path, so its answer is a property of the root alone; run it from two unrelated
# working directories and require the same verdict and the same finding count.
scan_at "/" "$PROJ" "$VALIDATOR" "$CONTROL_SCHEMA" ""
s8_rc_root="$RC"; s8_n_root="$(findings)"
scan_at "$PROJ/server" "$PROJ" "$VALIDATOR" "$CONTROL_SCHEMA" ""
{ [ "$RC" -eq "$s8_rc_root" ] && [ "$(findings)" -eq "$s8_n_root" ] && [ "$s8_n_root" -eq 2 ]; } \
  && ok "S8 the whole-tree scan gives the same verdict and the same 2 findings from / and from \$PROJ/server" \
  || bad "S8 the whole-tree scan is cwd-dependent: / gave rc=$s8_rc_root/$s8_n_root finding(s), \$PROJ/server gave rc=$RC/$(findings)"

# --- Assertion 9: the tree the fixture ran against is unchanged --------------
# The schema is swapped in and out around every scan; a restore that silently failed would leave
# later assertions running against a mutant's schema, which is the entanglement that makes one
# assertion vacuous.
cmp -s "$CONTROL_SCHEMA" "$SCHEMA" \
  && ok "the seeded project's schema is byte-identical to the control after every swap" \
  || bad "the seeded schema was left mutated; assertions after the first mutation were not testing what they claim"
cmp -s "$CONTROL_SCHEMA" "$NESTED/.claude/schemas/provenance-block.json" \
  && ok "the nested checkout's schema is byte-identical to the control after every swap" \
  || bad "the nested checkout's schema was left mutated; S7 and MUT-E were not testing what they claim"

echo
if [ "$fails" -eq 0 ]; then echo "stray-party-mode-provenance: PASS"; exit 0; fi
echo "stray-party-mode-provenance: $fails assertion(s) FAILED" >&2
exit 1
