#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# Hermetic against ambient AI_DLC_* tunables (enforcement-map I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# apply-setup-sited-merge -- apply.sh resolves a setup-sited BOTH-CHANGED->CLASSIFY file whose only
# consumer delta is its declared setup values, and hands back every other shape exactly as before.
#
# Usage: run.sh
# Exit:  0 = every assertion holds (or the subject predates the feature: SKIP), 1 = regressed,
#        2 = fixture broken.
#
# THE DEFECT. A file reconcile/setup-sites.md declares carries values ai-dlc-setup filled in, so it
# never byte-matches base and every upstream change to it buckets BOTH-CHANGED->CLASSIFY. apply.sh
# handed each one back as `WORKLIST semantic-merge`, a manual 3-way merge whose whole content was
# "take theirs, keep the values" -- on the reproduced pull, `git merge-file` produced bytes identical
# to the consumer's hand merge for both such files.
#
# THE FIX RESOLVES ONLY WHEN FOUR QUESTIONS, EACH ASKED OF A PROGRAM, ALL SAY YES: (a) against BASE
# this one file differs only inside its spans (setup-site-drift.sh --file), (b) merge-file exits 0,
# (c) the unwritten merge equals theirs outside its spans (--file --ours), (d) theirs added no live
# `{token}` outside an HTML comment. An already-merged file resolves with no content write, accepted
# when re-merging theirs changes nothing, or -- for a re-merge that is ambiguous, a block added beside
# an identical one -- when it equals theirs outside its spans and every span's text is identical at
# base and theirs. Anything else is today's row, byte for byte, with the file untouched.
#
# HOW EACH ARM IS JUDGED. The clean target is compared against an expected file built HERE from
# theirs' bytes with the two site lines replaced by the seeded values -- never against
# setup-site-drift.sh, which is the subject's own oracle. A fallback is judged by the file's bytes,
# inode and mode before and after, AND by the row: literally `WORKLIST<TAB>semantic-merge<TAB><rel>`,
# and byte-identical to the row a REFERENCE copy of the same apply.sh prints for the same world --
# the reference is the shipped program with the merge call replaced by `false`, so it is exactly
# today's arm. Each world is built fresh per drive and records its refs in `.B`/`.T` beside it.
#
# WHERE THE MUTANTS ARE. The worlds, drives and predicates live in lib.sh beside this file. The
# 24-mutant battery that proves these arms can fail is `apply-setup-sited-merge-mutants`,
# distribution-only, which sources the SAME lib.sh: it edits copies of core's own apply.sh and
# setup-site-drift.sh, which a consumer is denied editing, so it is a question only this repository
# asks. The unmutated control copy (S2) moved with it.
#
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A consumer can receive this file one pull before the
# apply.sh it tests, so an absent subject prints SKIP and exits 0 -- never an ok. The probe is keyed
# on the EMISSION site, the `say RESOLVED setup-site-merge` line; a tree that defines
# setup_site_merge() without that line is a respelled subject this grammar cannot see, which FAILS.

NAME=apply-setup-sited-merge
HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$HERE/lib.sh" ] || { echo "$NAME: FIXTURE BROKEN -- lib.sh is absent beside this fixture" >&2; exit 2; }
. "$HERE/lib.sh"

# --- D10: the subject probe, at the emission site -----------------------------------------------
if ! grep -qF 'say RESOLVED setup-site-merge' "$REC/apply.sh"; then
  if grep -q '^setup_site_merge()' "$REC/apply.sh"; then
    echo "  FAIL  apply.sh defines setup_site_merge() but no line emits \`say RESOLVED setup-site-merge\` -- the row was respelled and this probe can no longer see its subject"
    echo; echo "apply-setup-sited-merge: FAIL (1)"; exit 1
  fi
  echo "SKIP: subject predates setup-site-merge"
  exit 0
fi
lib_init

# --- the reference: today's arm, from the same apply.sh -----------------------------------------
REF="$WORK/ref"
mut_new "$REF" && mut_sub "$REF" "$CALL" '&& false; then' && mutated "$REF" \
  || broken "the reference copy could not be built: the merge call \`$CALL\` is not on exactly one line of apply.sh"

# --- worlds, built in a bounded pool and reaped before any is read -----------------------------
FALLBACKS="b1 b1b b2 b2twin d2 conflict d8del d8add d7 spanD spanQ delIM delDV delDVb cadd qd"
RESOLVES="dol ml com"
for v in clean cwd mode fin fence spanFar blkLen qdctl d6a d6b $FALLBACKS $RESOLVES; do
  case "$v" in cwd|mode) vv=clean ;; fin) vv=d6a ;; *) vv="$v" ;; esac
  bspawn "$WORK/tip-$v" "$vv"
done
for v in clean d6a d6b $FALLBACKS; do bspawn "$WORK/ref-$v" "$v"; done
breap
# The world count is derived from the two lists above, so a list that lost a member cannot shrink
# the expectation with it: 29 tip worlds (10 named + 16 fallbacks + 3 resolves), 19 reference.
set -- $FALLBACKS; n_fb=$#; set -- $RESOLVES; n_rs=$#
n_want=$(( (10 + n_fb + n_rs) + (3 + n_fb) ))
[ "$BUILT_OK" -eq "$n_want" ] && [ "$n_fb" -gt 0 ] && [ "$n_rs" -gt 0 ] \
  || broken "$BUILT_OK worlds built, $n_want owed by the world lists"
echo "$NAME: $BUILT_OK of $n_want worlds built before any drive"
render_report "$WORK/tip-clean" "$REC" || broken "emit-report.sh did not render the clean world's report"
grep -q 'reconcile-mechanical' "$WORK/tip-clean/cons/_bmad-output/ai-dlc-update/reconcile-report.md" \
  || broken "the rendered report carries no reconcile-mechanical region"

# --- phase 1 drives ----------------------------------------------------------------------------
launch tip-clean "$REC" "$WORK/tip-clean"
launch tip-cwd   "$REC" "$WORK/tip-cwd" /
for v in mode fin fence spanFar blkLen qdctl d6a d6b $FALLBACKS $RESOLVES; do launch "tip-$v" "$REC" "$WORK/tip-$v"; done
for v in clean d6a d6b $FALLBACKS; do launch "ref-$v" "$REF" "$WORK/ref-$v"; done
wait; njobs=0

# --- phase 1b: the exec bit taken away after the merge, then a re-run (the shortcut must restore
# it), and --finish over the d6a tree the ordinary run left with its stamp withheld ---------------
MODE_RES1="$(has_resolved tip-mode "$DV" && echo yes || echo no)"
FENCE_RES1="$(has_resolved tip-fence "$DV" && echo yes || echo no)"; FENCE_INO1="$(ino "$WORK/tip-fence/cons/.claude/$DV")"
cp "$WORK/tip-fence/cons/.claude/$DV" "$WORK/tip-fence/after1"
render_report "$WORK/tip-fence" "$REC" || broken "emit-report.sh did not render the fence world's run-2 report"
launch tip-fence2 "$REC" "$WORK/tip-fence"
chmod -x "$WORK/tip-mode/cons/.claude/$DV"
launch tip-mode2 "$REC" "$WORK/tip-mode"
launch tip-fin2 "$REC" "$WORK/tip-fin" "" --finish
# The second run over the clean tree (D1). Its report is re-rendered first: run 1 moved the stamp,
# and a region rendered before it is refused as STALE, which would test the union gate instead of
# the merge. Run 1 was reaped above, so this rides in the same batch as the other re-runs.
INO1="$(ino "$WORK/tip-clean/cons/.claude/$DV")"; cp "$WORK/tip-clean/cons/.claude/$DV" "$WORK/tip-clean/after1"
render_report "$WORK/tip-clean" "$REC" || broken "emit-report.sh did not re-render the clean world's report"
launch tip-clean2 "$REC" "$WORK/tip-clean"
wait; njobs=0

for l in tip-clean tip-clean2 ref-clean; do
  ran "$l" || { sed 's/^/        /' "$WORK/out/$l.err" | head -8; broken "drive $l exited $(cat "$WORK/out/$l.rc" 2>/dev/null) or printed nothing"; }
done

# === S: the reference is today's arm ===========================================================
# (S2, the unmutated control copy, moved to apply-setup-sited-merge-mutants with the mutants it
# vouches for.)
if has_today ref-clean "$DV" && ! has_resolved ref-clean "$DV"; then
  ok "S1 the reference copy (merge call replaced by false) hands the clean world back as today's semantic-merge row -- it is a real 'before'"
else
  bad "S1 the reference copy did not print today's row on the clean world, so every byte-identity comparison below compares against nothing"
fi

# === C: the clean target ========================================================================
W="$WORK/tip-clean"; expect_dv "$W" || broken "could not build the expected clean file"
if has_resolved tip-clean "$DV"; then ok "C1 the clean target emits RESOLVED${TAB}setup-site-merge${TAB}$DV"
else bad "C1 the clean target did not resolve: $(cut -f1-3 "$WORK/out/tip-clean.out" | tr '\t\n' ' |')"; fi
if has_today tip-clean "$DV"; then bad "C1 and the same run ALSO printed today's semantic-merge row for it"; fi
if cmp -s "$W/want" "$W/after1"; then
  ok "C2 the written file is theirs byte-for-byte outside the two sites, and carries the consumer's values inside them"
else
  bad "C2 the written file is not theirs-with-the-consumer's-values:"; diff "$W/want" "$W/after1" | head -8 | sed 's/^/        /'
fi
if [ "$(xbit "$W/after1")" = x ] && [ "$(cat "$W/mode.deploy-validate.md")" = - ]; then
  ok "C3 the consumer's 0644 copy took theirs' 100755 (D5)"
else
  bad "C3 the mode did not follow theirs: consumer was $(cat "$W/mode.deploy-validate.md"), now $(xbit "$W/after1"), theirs 100755"
fi
if [ "$INO1" != "$(cat "$W/ino.deploy-validate.md")" ]; then ok "C4 the write replaced the inode (.incoming + mv), the positive control for D1's no-write"
else bad "C4 the clean write kept the inode -- either nothing was written or it was written in place"; fi

# === D1: idempotence ============================================================================
if has_resolved tip-clean2 "$DV" && [ "$(ino "$W/cons/.claude/$DV")" = "$INO1" ] && cmp -s "$W/after1" "$W/cons/.claude/$DV"; then
  ok "D1 a second run over the merged file resolves again, with the same inode and bytes -- already merged, no write"
else
  bad "D1 the second run: resolved=$(has_resolved tip-clean2 "$DV" && echo yes || echo NO) inode $(ino "$W/cons/.claude/$DV") vs $INO1, bytes $(cmp -s "$W/after1" "$W/cons/.claude/$DV" && echo same || echo CHANGED)"
fi

# === CWD ========================================================================================
if ran tip-cwd && has_resolved tip-cwd "$DV" && cmp -s "$W/want" "$WORK/tip-cwd/cons/.claude/$DV"; then
  ok "CWD the clean world driven from / reaches the same verdict and the same bytes"
else
  bad "CWD the clean world driven from / did not reproduce (rc $(cat "$WORK/out/tip-cwd.rc" 2>/dev/null))"
fi

# === fallbacks: today's row, byte-identical to the reference, file untouched ===================
# fallback <arm> <variant> <rel> <nf> <why>
fallback() {
  local a="$1" v="$2" r="$3" nf="$4" why="$5" w="$WORK/tip-$2"
  if ! ran "tip-$v" || ! ran "ref-$v"; then bad "$a ($v) a drive failed: tip rc $(cat "$WORK/out/tip-$v.rc"), ref rc $(cat "$WORK/out/ref-$v.rc")"; return; fi
  local t f; t="$(rows_for "tip-$v" "$r")"; f="$(rows_for "ref-$v" "$r")"
  if has_today "tip-$v" "$r" "$nf" && ! has_resolved "tip-$v" "$r" && [ -n "$t" ] && [ "$t" = "$f" ] && untouched "$w" "$r"; then
    ok "$a $why -- today's row, byte-identical to the reference's, and $r untouched (bytes, inode, mode)"
  else
    bad "$a $why -- tip rows [$(printf '%s' "$t" | tr '\t\n' ' |')] ref rows [$(printf '%s' "$f" | tr '\t\n' ' |')] untouched=$(untouched "$w" "$r" && echo yes || echo NO)"
  fi
}
fallback B1  b1       "$DV" 3 "theirs rewords the after_line anchor: (a) OK and merge-file 0, only (c) sees the lost anchor"
fallback B1b b1b      "$DV" 3 "theirs rewords the anchor of a site the consumer left unfilled: (c) exits 1 while still printing SETUP-SITE-OK"
fallback B2  b2       "$DV" 3 "the consumer edited the <!-- {deploy_command}: ... --> doc-comment line, outside every span"
fallback B2t b2twin   "$DV" 3 "consumer and theirs made the SAME doc-comment edit: unregistered-drift exempts the hunk and (c) is blind, only (a) refuses"
fallback D2  d2       "$DV" 3 "theirs adds a live {deploy_command} --retry line outside the site"
fallback MF  conflict "$DV" 3 "theirs edits a span line the consumer filled: merge-file exits 1"
fallback D7  d7       "$DV" 4 "a pending retired-token obligation keeps today's row with its re-point detail"
fallback D8b d8add    "$QA" 3 "a BOTH-ADDED->CLASSIFY sited file falls back because it has no blob at base to merge from"
fallback SpD spanD    "$DV" 3 "theirs changes the value line to {deploy_command} --wait, the locator still matching: the already-merged shortcut must not read it as merged"
fallback SpQ spanQ    "$QA" 3 "theirs rewords the doc comment INSIDE qa.md's ## Ownership block: the already-merged shortcut must not read it as merged"
fallback DlI delIM    "$IM" 3 "theirs deletes the line below the filled implementation-smoke-command site: a first run must not accept the file without theirs' deletion"
fallback DlD delDV    "$DV" 3 "theirs deletes the closing fence after the filled smoke line"
fallback DlB delDVb   "$DV" 3 "theirs deletes the opening fence before the filled smoke line"
fallback CAd cadd     "$DV" 3 "the consumer adds a line right after the filled deploy site: (a) must see it as outside every span"
fallback QD  qd       "$QA" 3 "the consumer deletes from inside qa.md's Ownership block through ## Responsibilities and its body: one d hunk whose first line is in span"

# === QDc: a deletion-shaped edit wholly inside the block still resolves =========================
w="$WORK/tip-qdctl"
git -C "$w/dist" show "$(cat "$w/.T"):core/$QA" > "$w/want" \
  && edit "$w/want" '<!-- {ownership_paths}: filled in by ai-dlc-setup -->' '<!-- our paths -->' \
  || broken "could not build the expected qa.md for qdctl"
if ran tip-qdctl && has_resolved tip-qdctl "$QA" && cmp -s "$w/want" "$w/cons/.claude/$QA"; then
  ok "QDc the same in-block comment reword without the deletion RESOLVES -- the range test does not hit edits inside the block"
else
  bad "QDc qdctl: resolved=$(has_resolved tip-qdctl "$QA" && echo yes || echo NO) bytes=$(cmp -s "$w/want" "$w/cons/.claude/$QA" && echo want || echo OTHER)"
fi

# === (d)'s pass direction: three theirs additions that are NOT a live setup token ===============
for v in $RESOLVES; do
  w="$WORK/tip-$v"; expect_dv "$w" || broken "could not build the expected file for $v"
  case "$v" in
    dol) why='theirs adds `Export ${LOGDIR}` -- a shell expansion, not a setup token' ;;
    ml)  why='theirs adds a multi-line <!-- ... {deploy_command} ... --> comment' ;;
    com) why='theirs rewords only the <!-- {deploy_command}: ... --> comment line' ;;
  esac
  if ran "tip-$v" && has_resolved "tip-$v" "$DV" && cmp -s "$w/want" "$w/cons/.claude/$DV"; then
    ok "D+$v $why: it RESOLVES, and the file is theirs-with-values"
  else
    bad "D+$v $why: resolved=$(has_resolved "tip-$v" "$DV" && echo yes || echo NO) bytes=$(cmp -s "$w/want" "$w/cons/.claude/$DV" && echo want || echo OTHER) -- (d) refuses an addition that carries no live token"
  fi
done

# === SpF: theirs' line inside a heading block, away from the value, is MERGED ==================
w="$WORK/tip-spanFar"
git -C "$w/dist" show "$(cat "$w/.T"):core/$QA" > "$w/want" && edit "$w/want" '{ownership_paths}' 'tests/e2e/' \
  || broken "could not build the expected qa.md for spanFar"
if ran tip-spanFar && has_resolved tip-spanFar "$QA" && cmp -s "$w/want" "$w/cons/.claude/$QA"; then
  ok "SpF theirs adds a line inside qa.md's ## Ownership block away from the value: it RESOLVES, carrying theirs' line and keeping the consumer's value"
else
  bad "SpF spanFar: resolved=$(has_resolved tip-spanFar "$QA" && echo yes || echo NO), theirs' line present $(grep -c 'QA also owns the e2e harness.' "$w/cons/.claude/$QA"), value kept $(grep -c 'tests/e2e/' "$w/cons/.claude/$QA"), bytes $(cmp -s "$w/want" "$w/cons/.claude/$QA" && echo want || echo OTHER)"
fi

# === BLK: a block span may change length on both sides and still resolve =======================
w="$WORK/tip-blkLen"
git -C "$w/dist" show "$(cat "$w/.T"):core/$QA" \
  | awk '$0 == "{ownership_paths}" { print "src/**"; print "infra/**"; next } { print }' > "$w/want" \
  || broken "could not build the expected qa.md for blkLen"
if ran tip-blkLen && has_resolved tip-blkLen "$QA" && cmp -s "$w/want" "$w/cons/.claude/$QA"; then
  ok "BLK qa.md's Ownership block changes length on both sides (theirs adds a line, the consumer's value is two lines): it still RESOLVES to theirs-with-values"
else
  bad "BLK blkLen: resolved=$(has_resolved tip-blkLen "$QA" && echo yes || echo NO) bytes=$(cmp -s "$w/want" "$w/cons/.claude/$QA" && echo want || echo OTHER) -- a length check meant for single-line sites is catching block spans"
fi

# === D1f: idempotence over a fence-adjacent insertion ==========================================
w="$WORK/tip-fence"; expect_dv "$w" || broken "could not build the expected fence file"
n_t="$(grep -c '^make check$' "$w/want")" || n_t=0
n_1="$(grep -c '^make check$' "$w/after1")" || n_1=0
n_2="$(grep -c '^make check$' "$w/cons/.claude/$DV")" || n_2=0
if [ "$FENCE_RES1" = yes ] && cmp -s "$w/want" "$w/after1" && [ "$n_t" = 1 ] \
   && ran tip-fence2 && has_resolved tip-fence2 "$DV" && cmp -s "$w/after1" "$w/cons/.claude/$DV" \
   && [ "$(ino "$w/cons/.claude/$DV")" = "$FENCE_INO1" ] && [ "$n_2" = 1 ]; then
  ok "D1f theirs adds a fenced block beside an existing fence: run 1 merges it, run 2 resolves with no write, and the block appears once"
else
  bad "D1f fence: run1 resolved=$FENCE_RES1 bytes=$(cmp -s "$w/want" "$w/after1" && echo want || echo OTHER); run2 resolved=$(has_resolved tip-fence2 "$DV" && echo yes || echo NO) bytes=$(cmp -s "$w/after1" "$w/cons/.claude/$DV" && echo same || echo CHANGED) inode $([ "$(ino "$w/cons/.claude/$DV")" = "$FENCE_INO1" ] && echo same || echo CHANGED); 'make check' count theirs=$n_t run1=$n_1 run2=$n_2"
fi

# === M2: the shortcut restores theirs' exec bit ================================================
if [ "$MODE_RES1" = yes ] && ran tip-mode2 && has_resolved tip-mode2 "$DV" && [ "$(xbit "$WORK/tip-mode/cons/.claude/$DV")" = x ]; then
  ok "M2 after chmod -x on the merged file, a re-run resolves through the shortcut AND restores theirs' 100755"
else
  bad "M2 re-run after chmod -x: run1 resolved=$MODE_RES1, run2 resolved=$(has_resolved tip-mode2 "$DV" && echo yes || echo NO), exec bit now $(xbit "$WORK/tip-mode/cons/.claude/$DV") (want x)"
fi

# === FIN: --finish over the d6a tree (fin_note is in lib.sh; the battery's finNote reads it too) ==
if ran tip-fin && has_resolved tip-fin "$DV" && has_today tip-fin "$IM" && ran tip-fin2; then
  n_dv="$(fin_note tip-fin2 "$DV")"; n_im="$(fin_note tip-fin2 "$IM")"
  if [ -z "$n_dv" ] && [ -n "$n_im" ] && case "$n_im" in *"SETUP-SITE-DRIFT .claude/$IM"*) true ;; *) false ;; esac; then
    ok "FIN --finish: the merged deploy-validate.md is verified (no finish-unverified row), implementation.md keeps the NOTE carrying ssd's DRIFT rows"
  else
    bad "FIN --finish: DV note [${n_dv:-none}] (want none); IM note [${n_im:-NONE}] (want one naming SETUP-SITE-DRIFT .claude/$IM)"
  fi
else
  bad "FIN setup: the d6a ordinary run did not leave DV resolved and IM handed back, or --finish did not run (rc $(cat "$WORK/out/tip-fin2.rc" 2>/dev/null))"
fi

# === INC: no world is left holding a write temp ================================================
# Counted over EVERY world driven by the shipped program, so a write path that leaks its
# `.incoming.$$` in any shape is seen. The control is the number of worlds the find walked.
n_w=0; n_leak=0
for w in "$WORK"/tip-* "$WORK"/ref-*; do
  [ -d "$w/cons" ] || continue
  n_w=$((n_w+1))
  [ -z "$(find "$w/cons" -name '*.incoming.*' 2>/dev/null)" ] || n_leak=$((n_leak+1))
done
if [ "$n_w" -ge 20 ] && [ "$n_leak" -eq 0 ]; then
  ok "INC none of the $n_w driven worlds holds an *.incoming.* temp"
else
  bad "INC $n_leak of $n_w driven worlds hold an *.incoming.* temp (or too few worlds were walked to mean anything)"
fi
# D8: consumer-deleted
if ran tip-d8del && ran ref-d8del && [ ! -e "$WORK/tip-d8del/cons/.claude/$DV" ] && ! has_resolved tip-d8del "$DV" \
   && [ "$(rows_for tip-d8del "$DV")" = "$(rows_for ref-d8del "$DV")" ]; then
  ok "D8 a consumer-deleted sited path stays absent, and its rows are the reference's ($(rows_for tip-d8del "$DV" | cut -f1,2 | tr '\t\n' ' |'))"
else
  bad "D8 the consumer-deleted path: present=$([ -e "$WORK/tip-d8del/cons/.claude/$DV" ] && echo YES || echo no), rows tip [$(rows_for tip-d8del "$DV" | tr '\t\n' ' |')] ref [$(rows_for ref-d8del "$DV" | tr '\t\n' ' |')]"
fi

# === D6: per file, both directions =============================================================
d6() { # <arm> <variant> <target-rel> <other-rel> <expect-fn>
  local w="$WORK/tip-$2"
  "$5" "$w" || broken "could not build the expected file for $2"
  if ran "tip-$2" && has_resolved "tip-$2" "$3" && cmp -s "$w/want" "$w/cons/.claude/$3" \
     && has_today "tip-$2" "$4" && untouched "$w" "$4" \
     && [ "$(rows_for "tip-$2" "$4")" = "$(rows_for "ref-$2" "$4")" ]; then
    ok "$1 $3 resolves to theirs-with-values while $4, carrying an outside-span consumer edit, gets today's row untouched"
  else
    bad "$1 per-file: $3 resolved=$(has_resolved "tip-$2" "$3" && echo yes || echo NO) bytes=$(cmp -s "$w/want" "$w/cons/.claude/$3" && echo want || echo OTHER); $4 today=$(has_today "tip-$2" "$4" && echo yes || echo NO) untouched=$(untouched "$w" "$4" && echo yes || echo NO)"
  fi
}
d6 D6a d6a "$DV" "$IM" expect_dv
d6 D6b d6b "$IM" "$DV" expect_im

echo
if [ "$fails" -eq 0 ]; then echo "apply-setup-sited-merge: PASS"; exit 0; fi
echo "apply-setup-sited-merge: FAIL ($fails)"
exit 1
