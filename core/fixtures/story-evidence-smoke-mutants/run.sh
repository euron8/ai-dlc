#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# story-evidence-smoke-mutants/run.sh -- the sm MUTATION BATTERY for BL-845's smoke arms, behind story-evidence-receipts,
# the shipped fixture that makes receipt-bl845.sh's full control call and its RAN SET. Split from
# story-evidence-receipts-mutants by grain, so the pool runs the two batteries side by side. Distribution-only (its
# .dist-only says why): every mutant edits a copy of core's own validate-handoff-evidence.sh.
#
# THE CONTROL TREE, THE RECEIPT AND sm_run ARE THE SHIPPED FIXTURE'S. This file SOURCES story-evidence-receipts/run.sh,
# whose BASH_SOURCE guard returns after it has built the control tree ($HECTL), named the receipts and defined sm_run
# and the C3 extractor. It then makes its OWN bl845 control call below, which seeds the worlds ONCE into $SMW, sets B_sm
# and holds the RAN set every kill is credited against (kill_credit, BL-979 C2); a copy of the worlds taken right after
# that call is compared with `diff -r` after the last mutant (the SMOKE WORLDS arm). Each mutant is written beside
# record-only-diff.sh in that control tree (world.sh's mkmut), names its ONE deciding cell (plus clean), and must fail
# that cell and leave clean standing.
#
# THE MUTANT MATRIX. Each mutant runs on its deciding cell and the clean cell, inside one receipt call. clean prints no
# label of its own (sm_mutant refuses a `FAIL clean:` line), so every row is `twins=-` with that reason. The full mutant
# x cell matrix is printed by `--matrix` (one MATRIX-ROW per mutant: the cells its full receipt call fails),
# re-measured whenever a cell or a mutant is added or changed.
# Measured (--matrix): every row's deciding cell is in the set its full receipt call trips, and no mutant trips
# clean.
# MUTANT-MATRIX sm-m1-off decides=m1 twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-m1-no-ext decides=e2e twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-m1-tree decides=dotdir twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-m1-no-removal decides=rm twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-tok-slash decides=api twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-tok-chars decides=kv twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-tok-line decides=line twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-tok-node decides=node twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-fence decides=grammar twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-section-end decides=grammar twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-m2-off decides=s320 twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-m2-any-token decides=s320 twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-surface-inverted decides=s320 twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-surface-first-line decides=excl twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-surface-at-frozen decides=edited twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-no-edited decides=edited twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-l1-ok-not-skip decides=absent twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-no-none decides=none twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-none-case decides=cnone twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-pathspec-rc decides=magic twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-surface-matches-nothing decides=nonedot twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-surface-base-only decides=green twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-listing-any-fail-rejected decides=corrupt twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-smoke-uneval-swallowed decides=brk0 twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-uneval-exit2 decides=magic twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-smoke-uneval-outranks decides=broken twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-hand-uneval-outranks decides=handbrk twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-diff-cwd decides=sub twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-no-empty decides=empty twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-decl-ignored decides=decl twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-emptykey-unrefused decides=emptykey twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-handoff-unwired decides=hand twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX sm-exclglob-lost decides=exclglob twins=- why=its twin is bl845 clean, run in the same receipt call and refused by the FAIL clean check; no label here emits it
# MUTANT-MATRIX-DYNAMIC rcpt-helpers why=each name reaches mutant_killed as its helper literal first argument, rowed above
# MUTANT-MATRIX-REMEASURE bash core/fixtures/story-evidence-smoke-mutants/run.sh --matrix
#
# Exit: 0 every arm and every mutant passed, 1 one did not, 2 the fixture could not run.
set -u
MDIR="$(cd "$(dirname "$0")" && pwd)"
MATRIX=0; [ "${1:-}" = --matrix ] && MATRIX=1
SER="$MDIR/../story-evidence-receipts/run.sh"
[ -f "$SER" ] || { echo "story-evidence-smoke-mutants: FIXTURE BROKEN -- $SER is absent, so there is no control tree to score a mutant in" >&2; exit 2; }
# shellcheck source=/dev/null
. "$SER" || { echo "story-evidence-smoke-mutants: FIXTURE BROKEN -- sourcing story-evidence-receipts/run.sh failed" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/story-evidence-receipts/run.sh"
# mutant.sh needs ok() and bad(), which the sourced file defines.
MUT_LIB="$MDIR/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "story-evidence-smoke-mutants: FIXTURE BROKEN -- lib/mutant.sh is absent" >&2; exit 2; }
# shellcheck source=/dev/null
. "$MUT_LIB" || exit 2
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
# The sourced file must have handed over its control tree, its receipts and its functions; world.sh's mkmut is the
# 4-argument one (<name> he <from> <to>), and it writes each mutant beside record-only-diff.sh in $HECTL's tree.
{ [ -f "${HECTL:-}" ] && [ -f "$(dirname "$HECTL")/record-only-diff.sh" ] && [ -f "${R845:-}" ] && [ -d "${SES:-}" ] \
  && declare -F want_cells c3_check ran_set cn_run b9_run sm_run b43_run mkmut rcpt_run >/dev/null; } \
  || { echo "story-evidence-smoke-mutants: FIXTURE BROKEN -- story-evidence-receipts/run.sh did not hand over its control tree, receipts or functions" >&2; exit 2; }

echo "story-evidence-smoke-mutants:"
# --- THE bl845 CONTROL CALL, this file's own ---------------------------------------------------------------------
# It sets B_sm only in its passing branch, seeds the worlds once (every mutant call below
# reads them), and holds the RAN set every kill is credited against.
sm_out="$(sm_run "$HECTL")"; sm_rc=$?
[ -f "$SMW/.seeded" ] && cp -R "$SMW" "$WORK/sm-worlds.snap" || { sm_rc=9; sm_out="$sm_out (the worlds were not seeded once into $SMW)"; }
if [ "$sm_rc" -eq 0 ]; then ok "BL-845 SMOKE ARMS: an untracked listed test file is REFUSED smoke-listed-absent and a removed one is not; directory, trailing-slash and extensionless tokens are ignored by m1; /api, KEY=URL and glob tokens are not paths, :line and ::node suffixes are stripped; the s320 4.2 body over a UI diff is REFUSED smoke-not-updated, an empty body over a non-UI diff is quiet, and an :(exclude) or :! surface line removes a generated file from the surface; an absent surface prints SKIP undeclared and no SMOKE OK, none prints NO-SURFACE, an empty one SKIP empty, a capitalised None NO-SURFACE, a surface line git rejects and a surface matching nothing at base (none., a backticked none, a typo) REFUSED smoke-surface-unevaluable with exit 1 while a matching glob the range misses is quiet and a surface directory the story creates is not refused, a corrupt base tree under the surface is UNEVALUABLE (exit 2) and not a rejected pathspec, an unevaluable range diff with nothing refused exits 2, a refusal outranks a later unevaluable diff (exit 1, never 2) in both modes, an :(exclude,glob) line drops a top-level test file that :(exclude) keeps, and -C <subdirectory> refuses as -C <toplevel> does; an edited surface is REFUSED and read at base; fences, CRLF and the next heading bound the section; handoff mode runs the same arms"; B_sm=1
else bad "BL-845 SMOKE ARMS: receipt-bl845.sh exited $sm_rc on the shipped validator: $(tr '\n' ' ' <<<"$sm_out")"; fi
SM_GATED="$(want_cells "$R845")"
if c3_msg="$(c3_check "$R845" "$sm_out")"; then ok "RAN SET bl845: the full control call ran exactly the $(grep -c . <<<"$SM_GATED") cells the receipt's code gates, through want and its cell and hand_rc helpers"
else bad "$c3_msg"; fi

# --- --matrix: each mutant's FULL receipt call (no cell named), so every cell it trips is printed ----------------
mfails() { sed -n 's/^FAIL \([A-Za-z0-9_-]*\):.*/\1/p' <<<"$1" | LC_ALL=C sort -u | tr '\n' ' '; }
mrow() { # <run function> <name> <from> <to> <deciding cell> <label>: one MATRIX-ROW, the mutant's full receipt call
  local run="$1" m o mrc; shift
  if ! m="$(mkmut "$1" he "$2" "$3")" || [ -z "$m" ]; then bad "FIXTURE ERROR: mutation '$1' matched nothing"; return; fi
  o="$("$run" "$m")"; mrc=$?
  echo "MATRIX-ROW $1 decides=$4 rc=$mrc tripped=[$(mfails "$o")]"
}

# --- THE MUTANTS -------------------------------------------------------------------------------------------------
kill_credit() { # <B flag> <full-call output> <gated cells> <cell> <mutant>: KC=1 only when the kill may be credited
  if [ "$1" = 1 ] && { ! grep -qxF -- "$4" <<<"$3" || grep -qxF -- "RAN $4" <<<"$2"; }; then KC=1
  elif [ "$1" = 1 ]; then KC=0; bad "MUTATION '$5' not credited: its deciding cell $4 is want-gated and the full control call printed no RAN $4"
  else KC=0; fi
}
# kill_credit's three outcomes, driven directly (no subject run): a gated cell with no RAN line is refused
# visibly (KC=0 and the exit counter moves), a gated cell with its RAN line and an ungated cell are credited.
_rkc=$rc; rc=0; _kv=""
kill_credit 1 'RAN aa' "$(printf 'aa\nbb')" bb kc-probe 2>/dev/null; _kv="$_kv$KC:$rc "; rc=0
kill_credit 1 'RAN aa' "$(printf 'aa\nbb')" aa kc-probe; _kv="$_kv$KC:$rc "; rc=0
kill_credit 1 'RAN aa' "$(printf 'aa\nbb')" cc kc-probe; _kv="$_kv$KC:$rc"
if [ "$_kv" = "0:1 1:0 1:0" ]; then rc=$_rkc; ok "KILL-CREDIT PROBE: a want-gated deciding cell with no RAN line is refused with a visible failure, one with its RAN line and an ungated cell are credited"
else rc=1; bad "KILL-CREDIT PROBE: want [0:1 1:0 1:0], got [$_kv]"; fi

# --- BL-845 SMOKE ARMS (sm_*) -----------------------------------------------------------------------
# The mechanical half of Check 11: smoke_arms, run by --smoke and by handoff mode. receipt-bl845.sh owns
# the worlds and the cells (its header lists them): m1 smoke-listed-absent (an untracked listed path, a
# directory), the removal clause, each rejected token form (`/api/...`, `KEY=http://...`, a glob) and
# each stripped suffix (`:352`, `::Class::test`), m2 smoke-not-updated on the LITERAL s320 4.2 body and
# its empty-body non-surface near-miss, the four surface states (absent: SKIP undeclared and NO
# `SMOKE OK`; `none`; empty; globs), smoke-surface-edited with the surface read at <base>, the heading,
# fence and CRLF grammar, and the handoff-mode call. Every mutant is written beside record-only-diff.sh
# in the control tree and must FAIL its own named cell and leave the clean cell standing.
# The worlds are seeded ONCE, into $SMW, by the first call; every mutant call reuses them (a mutant edits
# the validator, never a world). A copy taken right after seeding is compared with `diff -r` after the
# last mutant, so a call that wrote into a world fails the arm instead of skewing the later cells.
sm_mutant() { # <name> <from> <to> <cell that must FAIL> <label>
  [ "$MATRIX" = 0 ] || { mrow sm_run "$@"; return; }
  local m o mrc
  if ! m="$(mkmut "$1" he "$2" "$3")" || [ -z "$m" ]; then bad "FIXTURE ERROR: mutation '$1' matched nothing"; return; fi
  o="$(sm_run "$m" "$4")"; mrc=$?
  if [ "$mrc" -eq 9 ]; then bad "FIXTURE BROKEN: mutation '$1' -- the receipt could not run ($(tr '\n' ' ' <<<"$o"))"
  elif grep -q '^FAIL clean:' <<<"$o"; then bad "MUTATION '$1' moved the clean control cell -- $5"
  elif [ "$mrc" -eq 1 ] && grep -q "^FAIL $4:" <<<"$o"; then kill_credit "${B_sm:-0}" "$sm_out" "$SM_GATED" "$4" "$1"; mutant_killed "${KC:-0}" "$1" "MUTATION '$1' killed by cell $4: $5"
  else bad "MUTATION '$1' SURVIVED (rc=$mrc, cell $4 did not fail) -- $5"; fi
}
sm_mutant sm-m1-off 'refuse "smoke-listed-absent $st: \`$tok\` in ## Smoke Test Updates is not tracked' ': "smoke-listed-absent $st: \`$tok\` in ## Smoke Test Updates is not tracked' m1 "m1 removed, an untracked listed smoke test passes"
# The candidate rule has two guards, each with a subject the other cannot reach: `web/tests`, `web/`,
# `test-results/` and `tests/e2e` carry no `.` in their last segment (only the extension rule acquits
# them), and `web/tests/e2e.d` is a dotted TREE (only the tree rule acquits it).
sm_mutant sm-m1-no-ext 'case "${tok##*/}" in *.*) ;; *) continue ;; esac' ':' e2e "an extensionless or directory prose token refused as a listed test"
sm_mutant sm-m1-tree '[ "$ty" = tree ] && continue' ':' dotdir "a dotted directory token refused as a listed test"
sm_mutant sm-m1-no-removal '[ "$rmv" = 1 ] && continue' ':' rm "the removal clause dropped, a removed listed test is refused"
sm_mutant sm-tok-slash ' || t ~ /^\// || ' ' || ' api "a token starting with / read as a path"
sm_mutant sm-tok-chars ' || t ~ /=|:\/\/|[*?[]/) continue' ') continue' kv "KEY=URL and glob tokens read as paths"
sm_mutant sm-tok-line 'sub(/:[0-9]+$/, "", t)' 'sub(/^NEVER$/, "", t)' line "the :<line> suffix not stripped"
sm_mutant sm-tok-node 'sub(/::.*$/, "", t);' 'sub(/^NEVER$/, "", t);' node "the ::node suffix not stripped"
sm_mutant sm-fence 'if (sfc == "" && m != "") { sfc = m; next }' 'if (0) { sfc = m; next }' grammar "fenced lines read as section text"
sm_mutant sm-section-end '    /^##?[ \t]/ { on = 0 }' '    /^NEVER/ { on = 0 }' grammar "the section runs on past the next heading"
sm_mutant sm-m2-off 'refuse "smoke-not-updated' ': "smoke-not-updated' s320 "m2 removed, the s320 4.2 body over a UI diff passes"
sm_mutant sm-m2-any-token 'if grep -qxF -- "$tok" <<<"$chg"; then hit="$tok"' 'if true; then hit="$tok"' s320 "any backticked path acquits m2 (the S1 predicate), so s320 4.2 passes"
sm_mutant sm-surface-inverted 'if [ -z "$hits" ]; then' 'if [ -n "$hits" ]; then' s320 "the surface match inverted"
# Every surface line must reach git as its own pathspec: passing only the first drops the exclude.
sm_mutant sm-surface-first-line '"$sb" "$sf" -- $globs 2>/dev/null)"' '"$sb" "$sf" -- $(head -n 1 <<<"$globs") 2>/dev/null)"' excl "only the first surface line reaches git, so an exclude pathspec is lost"
sm_mutant sm-surface-at-frozen 'local srev="$sb"' 'local srev="$sf"' edited "the surface read at <frozen>, so the story moves its own gate"
sm_mutant sm-no-edited 'refuse "smoke-surface-edited' ': "smoke-surface-edited' edited "an edited surface file not refused"
sm_mutant sm-l1-ok-not-skip "printf 'SKIP SMOKE-SURFACE (undeclared: no %s at %s)" "printf 'SMOKE OK (undeclared: no %s at %s)" absent "L1: an absent surface prints SMOKE OK instead of SKIP"
sm_mutant sm-no-none 'if [ "$lglobs" = none ]; then' 'if false; then' none "a declared none read as a pathspec"
sm_mutant sm-none-case 'lglobs="$(tr '"'"'[:upper:]'"'"' '"'"'[:lower:]'"'"' <<<"$globs")"' 'lglobs="$globs"' cnone "a capitalised None left uncased reaches the matches-nothing guard and refuses smoke-surface-unevaluable"
# The two unevaluable guards each have a subject the other cannot reach: a rejected line still lists
# nothing, so with the rc guard off magic refuses through the matches-nothing guard WITHOUT the R flag;
# `none.` passes git and lists nothing, so only the matches-nothing guard refuses it.
sm_mutant sm-pathspec-rc 'if [ "$lrc" -ne 0 ]; then' 'if false; then' magic "a surface line git rejects not refused as a rejected pathspec"
sm_mutant sm-surface-matches-nothing 'if [ -z "$lst$flst" ]; then' 'if false; then' nonedot "a surface matching no path at base or frozen (none.) read as no surface change, so SMOKE OK"
# The matches-nothing guard lists <frozen> too: without that listing a surface naming a directory the story
# creates (green: web/app/**) refuses. typo (matches nothing at either sha) is the near-miss that still refuses.
sm_mutant sm-surface-base-only ''"'"'; SD "$et" "$sf" -- $globs 2>/dev/null)"; frc=$?' ''"'"'; :)"; frc=$?' green "the matches-nothing guard lists only <base>, so a greenfield surface the story creates refuses"
# A listing failure whose pathspecs parse over <empty tree>..<empty tree> failed on an object: UNEVALUABLE, not a rejected pathspec.
sm_mutant sm-listing-any-fail-rejected ''"'"'; SD "$et" "$et" -- $globs >/dev/null 2>&1); then' ''"'"'; false); then' corrupt "a corrupt base tree reported as a rejected surface pathspec"
# Nothing refused and the range diff fails: --smoke exits 2 (brk0 is the broken world without the m1 token).
sm_mutant sm-smoke-uneval-swallowed '|| exit 2 # smoke mode' '|| : # smoke mode' brk0 "--smoke: an unevaluable range diff with nothing refused falls through to smoke OK"
sm_mutant sm-uneval-exit2 '(exit $lrc); correct the line outside the story'"'"'s range"; return 0' '(exit $lrc); correct the line outside the story'"'"'s range"; refused=0; return 2' magic "a rejected surface line exits 2 unrefused, which every caller reads as nothing checked"
sm_mutant sm-smoke-uneval-outranks 'smoke_arms "$BASE" "$FROZEN" "$STORY" || [ "$refused" -eq 1 ] || exit 2 # smoke mode' 'smoke_arms "$BASE" "$FROZEN" "$STORY" || exit 2 # smoke mode' broken "--smoke: an unevaluable range diff after an m1 refusal exits 2, so the refusal does not block"
sm_mutant sm-hand-uneval-outranks 'smoke_arms "$BASE" "$FROZEN" "$STORY" || [ "$refused" -eq 1 ] || exit 2 # handoff mode' 'smoke_arms "$BASE" "$FROZEN" "$STORY" || exit 2 # handoff mode' handbrk "handoff: an unevaluable smoke arm after a refusal exits 2, so the refusal does not block dispatch"
sm_mutant sm-diff-cwd 'SD() { git -C "$TOP" diff' 'SD() { git -C "$REPO" diff' sub "-C <subdirectory> re-roots the smoke pathspecs, so the range is acquitted"
sm_mutant sm-no-empty "if [ -z \"\$globs\" ]; then printf 'SKIP SMOKE-SURFACE (empty" "if false; then printf 'SKIP SMOKE-SURFACE (empty" empty "an empty surface read as the whole diff"
# The surface PATH (BL-845's reader): a declared non-default path swapped back to the default while an
# empty declaration stays empty (so the emptykey cell is not what kills it), and the empty-key refusal off.
sm_mutant sm-decl-ignored "| head -1 | sed 's/[[:space:]]*\$//')\"" "| head -1 | sed 's/[[:space:]]*\$//')\"; [ -z \"\$SMOKE_SURFACE\" ] || SMOKE_SURFACE=\"\$SMOKE_SURFACE_DEFAULT\"" decl "the declared consumer_smoke_surface_file: ignored, so docs/smoke-surface.txt is read in its place"
sm_mutant sm-emptykey-unrefused 'if [ -z "$SMOKE_SURFACE" ]; then' 'if false; then' emptykey "an empty consumer_smoke_surface_file: is not refused by its own message"
sm_mutant sm-handoff-unwired 'smoke_arms "$BASE" "$FROZEN" "$STORY" || [ "$refused" -eq 1 ] || exit 2 # handoff mode' ': # handoff mode' hand "handoff mode does not run the smoke arms"
sm_mutant sm-exclglob-lost '"$sb" "$sf" -- $globs 2>/dev/null)"' '"$sb" "$sf" -- $(grep -v '"'"'^:(exclude,glob)'"'"' <<<"$globs") 2>/dev/null)"' exclglob "a glob-magic exclude line dropped from the (m2) diff, so a top-level test-only change refuses"
if [ -d "$WORK/sm-worlds.snap/cnone/.git" ] && [ -d "$WORK/sm-worlds.snap/magic/.git" ] && [ -d "$WORK/sm-worlds.snap/edited/web" ] \
  && [ -d "$WORK/sm-worlds.snap/broken/.git" ] && [ -d "$WORK/sm-worlds.snap/nonedot/.git" ] \
  && [ -d "$WORK/sm-worlds.snap/brk0/.git" ] && [ -d "$WORK/sm-worlds.snap/green/web/app" ] && [ -d "$WORK/sm-worlds.snap/corrupt/.git" ] \
  && diff -r "$WORK/sm-worlds.snap" "$SMW" >/dev/null 2>&1; then
  ok "BL-845 SMOKE WORLDS intact: seeded once (the cnone, magic, edited/web, broken, nonedot, brk0, green/web/app and corrupt worlds among them) and byte-identical after every mutant call (diff -r against the post-seed copy)"
else
  bad "BL-845 SMOKE WORLDS: the worlds changed across the mutant calls or were never snapshotted -- the reuse is unsafe and every cell above is suspect"
fi
# --- end BL-845 SMOKE ARMS --------------------------------------------------------------------------

[ "$MATRIX" = 0 ] || exit "$rc"
# INPROC: every subject call the control calls and the mutants made through he-inproc.sh was answered in process.
# Positive conjunct: the log exists, so an unset variable cannot pass.
if [ -f "$UT_FALLBACK_LOG" ] && [ ! -s "$UT_FALLBACK_LOG" ]; then
  ok "INPROC: every validator, record-only-diff.sh and sprint-status.sh call the receipts made was answered in process"
else
  bad "INPROC: subject calls ran as processes: $(sort "$UT_FALLBACK_LOG" 2>/dev/null | uniq -c | tr '\n' ' ')"
fi
if [ "$rc" -eq 0 ]; then echo "PASS story-evidence-smoke-mutants"; else echo "FAIL story-evidence-smoke-mutants"; fi
exit "$rc"
