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
# WHAT IT ASSERTS. The generated-region carve-out exempts core's own taught example, the homes are
# read from the schema, and an empty subject vocabulary refuses to run rather than reporting PASS on
# every tree there is.
#
# The other half is not about what a block SAYS but about where the caller says the file IS. The
# homes are matched against the candidate path as a string, so the answer depends on how the path
# was spelled — and that goes wrong in both directions, silently in one of them. The S-arms below
# are that half; their section header states the two shapes and which branch of the validator each
# one reaches. The home match must stay a PREFIX, because a substring match turns every file of a
# project checked out at docs/retro/<name>/ into a home (S7, S7b).
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
# The case-sensitive arm may ATTACH a disk image under $WORK. Detach it before the tree is
# removed: an rm walking into a live mount is not a cleanup.
CS_MNT=""; HFS_MNT=""
cleanup() {
  local m
  for m in "$CS_MNT" "$HFS_MNT"; do
    [ -n "$m" ] || continue
    hdiutil detach "$m" >/dev/null 2>&1 || hdiutil detach -force "$m" >/dev/null 2>&1
  done
  rm -rf "$WORK"
}
trap cleanup EXIT
# bash skips the EXIT trap on an untrapped TERM, and a pool timeout would leak an attached image.
trap 'exit 130' INT TERM

# image_unavailable <arm> <what failed> -- hdiutil is PRESENT and could not build the world.
# In the distribution that is a broken fixture, not a skip: this host is known to build both
# images, and a SKIP here would leave S10-C/S10-H unchecked while the suite reads green. On a
# consumer the host is not ours to assume (a sandboxed CI may refuse disk images), so it SKIPs,
# naming the arm it leaves unchecked and hdiutil's own words.
image_unavailable() {
  local why; why="$(tail -1 "$WORK/hdiutil.err" 2>/dev/null)"
  [ "$LAYOUT" = dist ] && broken "$1: $2 (hdiutil: ${why:-no stderr})"
  ok "$1 SKIP: $2 on this consumer host (hdiutil: ${why:-no stderr})"
}
# IMG-BUILD-BEGIN
# img_build <image> <mountpoint> <cs-apfs|hfs> -- the named kind of volume, writable and mounted at
# the mountpoint, built WITHOUT formatting anything on this run (BL-868 item 11).
#
# Formatting is the step that races. Two `hdiutil create -fs` released together from one fifo
# barrier fail `create failed - Directory not empty` or `- Operation not permitted` at a few
# percent, with unique volnames, unique TMPDIRs and SPARSE images alike; a hand-rolled mkfile +
# `attach -nomount` + newfs_apfs/newfs_hfs path failed the same way (`newfs_*: /dev/rdiskN:
# Operation not permitted`, 5/240 HFS+ builds, and 1/240 cs while creates ran beside it). Either
# way the arms read BROKEN in dist or green by what else the pool was running.
#
# So the volume is formatted ONCE, off-line, and committed: `<kind>.dmg.b64` is a read-only
# compressed (UDZO) image, base64 so it diffs and greps as text. This run decodes a private copy
# and attaches it with a private -shadow file, so every write lands in the shadow and two runs
# share no file at all. Measured on THIS function, extracted between the IMG-BUILD markers and
# raced in pairs under the barrier: 0/240 cs and 0/240 HFS+ failures, interleaved round by round
# with create pairs that failed 8/240 (cs) and 4/240 (HFS+) in the same run. Rebuild an asset with
#   hdiutil create -fs 'Case-sensitive APFS' -size 8m -volname bl082cs rw.dmg   (HFS+: -fs 'HFS+' -size 4m -volname bl082hfs)
#   hdiutil convert rw.dmg -format UDZO -imagekey zlib-level=9 -o cs.dmg && base64 -b 76 -i cs.dmg -o cs-apfs.dmg.b64
# and the S10-C / S10-H premise checks below say whether the volume is the kind it claims to be.
# Every step writes $WORK/hdiutil.err, so image_unavailable names the step that failed.
img_build() {
  local img="$1" mnt="$2" kind="$3"
  [ -f "$HERE/$kind.dmg.b64" ] || broken "img_build: the committed image $HERE/$kind.dmg.b64 is absent"
  base64 -D -i "$HERE/$kind.dmg.b64" -o "$img" 2>"$WORK/hdiutil.err" || return 1
  mkdir -p "$mnt" || return 1
  hdiutil attach -nobrowse -shadow "$img.shadow" -mountpoint "$mnt" "$img" >/dev/null 2>"$WORK/hdiutil.err"
}
# IMG-BUILD-END
# shellcheck source=/dev/null
. "$WORK/env.sh"

OUT="$WORK/out.txt"
ERR="$WORK/err.txt"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
broken() { printf '  FAIL  %s\n' "$1" >&2; echo; echo "stray-party-mode-provenance: FIXTURE BROKEN" >&2; exit 2; }

# scan <validator> <schema> <ext-or-empty> [<explicit path>...]
# The schema is swapped into the seeded project because the resolver has no schema override, and
# restored to the control copy afterwards so no assertion can inherit the previous one's schema.
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

# Reported/not-reported are asked about ONE path, never about the finding count, so an unrelated
# file's verdict cannot satisfy another arm's assertion.
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
echo "HERMETIC-CONSUMED core/scripts/validate-provenance-block.sh"

# --- Assertion 0: the baseline ---
# The shipped script on the seeded tree reports exactly the two service-file strays; every negative
# assertion below is unreadable until it has.
scan "$VALIDATOR" "$CONTROL_SCHEMA" ""
[ "$RC" -eq 1 ] || broken "the validator exited $RC on the seeded tree, want 1"
reported "server/handler.py"   || broken "the validator did not report server/handler.py; every negative assertion below would pass vacuously"
reported "server/commented.py" || broken "the validator did not report server/commented.py"
[ "$(findings)" -eq 2 ] || broken "the validator reported $(findings) finding(s), want exactly 2"
ok "the validator reports exactly the two service-file strays (exit 1)"

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

# --- a declared home is removed from the schema ------------------------------
scan "$VALIDATOR" "$SCHEMA_NO_RETRO" ""
reported "docs/retro/sprint-1.md" \
  && ok "docs/retro/** removed from homes: the retro document is reported — the homes list is read from the schema, not assumed" \
  || bad "removing docs/retro/** from homes did not make the retro document a finding"

# --- the subject vocabulary is emptied ---------------------------------------
scan "$VALIDATOR" "$SCHEMA_NO_SKILLS" ""
{ [ "$RC" -eq 2 ] && grep -qF "vacuous" "$ERR"; } \
  && ok "party_mode_skills emptied: the scan refuses to run rather than reporting PASS on a tree it cannot judge" \
  || bad "an empty subject vocabulary produced rc=$RC instead of a loud refusal"

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
scan_at "$NESTED" "$NESTED" "$VALIDATOR" "$CONTROL_SCHEMA" "" server/x.py
{ [ "$RC" -eq 1 ] && reported_any "server/x.py"; } \
  || broken "SELF-PROBE (positive): the validator did not report the nested stray it was pointed at (rc=$RC); the path-spelling arms cannot fire"
scan_at "$PROJ" "$PROJ" "$VALIDATOR" "$CONTROL_SCHEMA" "" docs/retro/sprint-1.md
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
# checkout. Green today.
scan_at "$NESTED" "$NESTED" "$VALIDATOR" "$CONTROL_SCHEMA" "" "$NESTED/server/x.py"
{ [ "$RC" -eq 1 ] && reported_any "server/x.py"; } \
  && ok "S7 a stray in a checkout that LIVES at docs/retro/<name>/ is reported (the home is a location, not a substring)" \
  || bad "S7 FALSE PASS: a stray under a checkout at docs/retro/<name>/ was accepted as a home (rc=$RC)"

# --- S7b: a directory INSIDE the repo spelled like a home, but not at one ----
# `vendor/docs/retro/inner.md` contains the home pattern and does not begin with it. Unlike S7
# this survives normalisation — after the caller's paths are resolved to repo-relative form the
# nested checkout's stray no longer carries a home substring, and this one still does. It is the
# subject that keeps separating prefix from substring on a FIXED validator.
scan_at "$NESTED" "$NESTED" "$VALIDATOR" "$CONTROL_SCHEMA" "" "$NESTED/vendor/docs/retro/inner.md"
{ [ "$RC" -eq 1 ] && reported_any "vendor/docs/retro/inner.md"; } \
  && { ok "S7b a stray under vendor/docs/retro/ is reported; a home is a place the path STARTS, not one it contains"; } \
  || bad "S7b FALSE PASS: vendor/docs/retro/inner.md was accepted as a home (rc=$RC) — the home pattern was found mid-path"

# --- S10: case-variant spellings, on BOTH kinds of filesystem (BL-082) -------
# `realpath` resolves symlinks and `..` and does NOT restore case, so where the filesystem folds
# case `DOCS/retro/sprint-1.md` -- the same file as the home -- kept the caller's spelling, missed
# `docs/retro/**`, and was reported as a stray. The validator now respells each component as its
# parent directory LISTS it, and only to an entry that is the same directory entry.
#
# THE OBVIOUS REMEDY IS FORBIDDEN AND THIS SECTION IS WHAT HOLDS IT OUT. Folding case in the home
# match closes the false stray exactly as the respelling does, so NO arm on a folding filesystem
# can tell the two apart (S10-F5 records that). On a case-sensitive filesystem `DOCS/retro/` can
# be a genuinely distinct directory, and folding accepts it as the home: a false PASS on the
# platform a consumer's CI runs. S10-C is that world, and the folding remedy is rejected there.
#
# Two worlds, each built fresh here rather than in seed.sh so no whole-tree count above moves.
# Files are copied from seeded ones, so this file spells no complete block either.
case_proj() { # <root> -- the home, a near-miss stray beside it, and a service stray
  mkdir -p "$1/.claude/schemas" "$1/docs/retro" "$1/docs/retros" "$1/server" || broken "case_proj: mkdir under $1"
  cp "$CONTROL_SCHEMA" "$1/.claude/schemas/provenance-block.json" \
    && cp "$PROJ/docs/retro/sprint-1.md" "$1/docs/retro/sprint-1.md" \
    && cp "$PROJ/server/handler.py" "$1/docs/retros/stray.md" \
    && cp "$PROJ/server/handler.py" "$1/server/handler.py" || broken "case_proj: seeding $1"
}

# S10-F: the FOLDING world, on whatever filesystem $WORK sits on.
CI="$WORK/case-fold/proj"
case_proj "$CI"
if [ ! -e "$WORK/case-fold/PROJ/DOCS/retro/sprint-1.md" ]; then
  ok "S10-F SKIP: the filesystem under \$WORK does not fold case, so a case variant names nothing (no subject; S10-C covers this host)"
else
  scan_at "$CI" "$CI" "$VALIDATOR" "$CONTROL_SCHEMA" "" "DOCS/retro/sprint-1.md"
  { [ "$RC" -eq 0 ] && [ "$(scanned_count)" = "1" ]; } \
    && { ok "S10-F1 a declared home spelled DOCS/retro/ on a case-folding filesystem is not a stray (and was scanned)"; } \
    || bad "S10-F1 DOCS/retro/sprint-1.md -- the same file as the home here -- was reported as a stray (rc=$RC, scanned='$(scanned_count)')"
  # The near-miss: a stray whose name is one letter from the home, case-varied. Respelling must
  # land on ITS OWN entry and report it under its on-disk name, never collapse onto the home.
  scan_at "$CI" "$CI" "$VALIDATOR" "$CONTROL_SCHEMA" "" "DOCS/RETROS/stray.md"
  { [ "$RC" -eq 1 ] && reported "docs/retros/stray.md"; } \
    && ok "S10-F2 a stray at docs/retros/ spelled DOCS/RETROS/ is reported, under its on-disk spelling" \
    || bad "S10-F2 DOCS/RETROS/stray.md was not reported as docs/retros/stray.md (rc=$RC) -- the respelling accepted or misnamed a near-miss"
  scan_at "$CI" "$CI" "$VALIDATOR" "$CONTROL_SCHEMA" "" "SERVER/handler.py"
  { [ "$RC" -eq 1 ] && reported "server/handler.py"; } \
    && ok "S10-F3 a service stray spelled SERVER/ is still reported (a case variant is not a pass)" \
    || bad "S10-F3 SERVER/handler.py was not reported as server/handler.py (rc=$RC)"
fi

# S10-C: the CASE-SENSITIVE world. Native where $WORK already is one (a Linux consumer's CI);
# otherwise a case-sensitive APFS image under $WORK; otherwise SKIP with the reason.
CS_BASE=""; CS_WHY=""
mkdir -p "$WORK/cs-native/probe" || broken "S10-C: mkdir cs-native"
if [ ! -e "$WORK/cs-native/PROBE" ]; then
  CS_BASE="$WORK/cs-native"; CS_WHY="native case-sensitive filesystem"
elif command -v hdiutil >/dev/null 2>&1; then
  if img_build "$WORK/cs.dmg" "$WORK/cs-mnt" cs-apfs; then
    CS_MNT="$WORK/cs-mnt"; CS_BASE="$CS_MNT"; CS_WHY="case-sensitive APFS disk image"
  else
    CS_WHY="-"
    image_unavailable "S10-C" "hdiutil could not create or attach a case-sensitive APFS image -- S10-C is UNCHECKED"
  fi
else
  CS_WHY="the filesystem folds case and hdiutil is not available to build one that does not"
fi
if [ -z "$CS_BASE" ]; then
  [ "$CS_WHY" = "-" ] || ok "S10-C SKIP: $CS_WHY -- S10-C is UNCHECKED on this run"
else
  CS="$CS_BASE/proj"
  case_proj "$CS"
  mkdir -p "$CS/DOCS/retro" && cp "$PROJ/server/handler.py" "$CS/DOCS/retro/sprint-1.md" || broken "S10-C: seeding DOCS/retro"
  # Premise: the two directories are genuinely distinct here, or this world is the folding one.
  [ "$(ls "$CS" | grep -c -x -e docs -e DOCS)" = "2" ] || broken "S10-C premise ($CS_WHY): docs/ and DOCS/ are not two entries"
  scan_at "$CS" "$CS" "$VALIDATOR" "$CONTROL_SCHEMA" "" "DOCS/retro/sprint-1.md"
  { [ "$RC" -eq 1 ] && reported "DOCS/retro/sprint-1.md"; } \
    && { ok "S10-C1 ($CS_WHY) a DISTINCT DOCS/retro/ is a stray, not the declared home"; } \
    || bad "S10-C1 FALSE PASS ($CS_WHY): DOCS/retro/sprint-1.md is a different file from the home and came back rc=$RC"
  scan_at "$CS" "$CS" "$VALIDATOR" "$CONTROL_SCHEMA" "" "docs/retro/sprint-1.md"
  { [ "$RC" -eq 0 ] && [ "$(scanned_count)" = "1" ]; } \
    && ok "S10-C2 ($CS_WHY) the real home beside it still passes (and was scanned)" \
    || bad "S10-C2 ($CS_WHY) docs/retro/sprint-1.md was not PASS-over-1 (rc=$RC, scanned='$(scanned_count)')"
  scan_at "$CS" "$CS" "$VALIDATOR" "$CONTROL_SCHEMA" ""
  { [ "$RC" -eq 1 ] && reported "DOCS/retro/sprint-1.md" && ! reported "docs/retro/sprint-1.md"; } \
    && ok "S10-C3 ($CS_WHY) the whole-tree scan reports DOCS/retro/ and not docs/retro/" \
    || bad "S10-C3 ($CS_WHY) the whole-tree scan did not separate DOCS/retro/ from docs/retro/ (rc=$RC)"
fi

# S10-H: the world where the SAMESTAT check decides. HFS+ folds case more narrowly than python's
# casefold: `docs` and `doc<U+017F>` (long s) are two DISTINCT entries there, and both casefold
# to `docs`. A respelling that picked by casefold alone would take whichever is listed first --
# so of the two spellings below, one lands on the wrong directory whatever the listing order,
# and when it lands on the home that is a false PASS. Only an HFS+ volume holds this world:
# APFS folds the long s, and a case-sensitive filesystem never reaches the respelling at all.
LS="$(printf 'doc\305\277')"
if ! command -v hdiutil >/dev/null 2>&1; then
  ok "S10-H SKIP: hdiutil is not available to build an HFS+ volume -- S10-H is UNCHECKED on this run"
elif ! img_build "$WORK/hfs.dmg" "$WORK/hfs-mnt" hfs; then
  image_unavailable "S10-H" "hdiutil could not create or attach an HFS+ image -- S10-H is UNCHECKED"
else
  HFS_MNT="$WORK/hfs-mnt"
  HP="$HFS_MNT/proj"
  case_proj "$HP"
  mkdir -p "$HP/$LS/retro" && cp "$PROJ/server/handler.py" "$HP/$LS/retro/sprint-1.md" || broken "S10-H: seeding the long-s directory"
  [ -e "$HP/DOCS/retro/sprint-1.md" ] || broken "S10-H premise: the HFS+ volume does not fold ASCII case"
  cmp -s "$HP/docs/retro/sprint-1.md" "$HP/$LS/retro/sprint-1.md" && broken "S10-H premise: docs/ and the long-s directory are one entry here"
  H_UP="$(printf 'DOC\305\277')"
  scan_at "$HP" "$HP" "$VALIDATOR" "$CONTROL_SCHEMA" "" "DOCS/retro/sprint-1.md"
  h_home=0; { [ "$RC" -eq 0 ] && [ "$(scanned_count)" = "1" ]; } && h_home=1
  scan_at "$HP" "$HP" "$VALIDATOR" "$CONTROL_SCHEMA" "" "$H_UP/retro/sprint-1.md"
  h_stray=0; { [ "$RC" -eq 1 ] && reported "$LS/retro/sprint-1.md"; } && h_stray=1
  { [ "$h_home" -eq 1 ] && [ "$h_stray" -eq 1 ]; } \
    && { ok "S10-H (HFS+ image) DOCS/ respells to the home and DOC<long-s>/ to its own distinct directory, which is reported"; } \
    || bad "S10-H (HFS+ image) two casefold-equal entries were not told apart (home-passes=$h_home, long-s-reported=$h_stray)"
fi

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
# later assertions running against a swapped schema, which is the entanglement that makes one
# assertion vacuous.
cmp -s "$CONTROL_SCHEMA" "$SCHEMA" \
  && ok "the seeded project's schema is byte-identical to the control after every swap" \
  || bad "the seeded schema was left swapped; assertions after the first swap were not testing what they claim"
cmp -s "$CONTROL_SCHEMA" "$NESTED/.claude/schemas/provenance-block.json" \
  && ok "the nested checkout's schema is byte-identical to the control after every swap" \
  || bad "the nested checkout's schema was left swapped; S7 and S7b were not testing what they claim"

echo
report_end stray-party-mode-provenance
