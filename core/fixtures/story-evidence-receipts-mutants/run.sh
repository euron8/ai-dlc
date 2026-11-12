#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# story-evidence-receipts-mutants/run.sh -- the MUTATION BATTERY behind story-evidence-receipts, the shipped fixture for
# story-evidence-scaffold's four receipts (BL-809, BL-815, BL-843, BL-845) and BL-979's RAN SET: the cn (BL-815), b9
# (BL-809) and b43 (BL-843) validator mutants and the rr receipt mutants of all four receipts. The sm (BL-845) validator
# mutants are story-evidence-smoke-mutants'. Distribution-only (its .dist-only says why): every validator mutant edits a
# copy of core's own validate-handoff-evidence.sh, and every rr mutant a copy of a receipt.
#
# THE CONTROL TREE, THE RECEIPTS AND THE RUN FUNCTIONS ARE THE SHIPPED FIXTURE'S. This file SOURCES
# story-evidence-receipts/run.sh, whose BASH_SOURCE guard returns after it has built the control tree ($HECTL), named
# the four receipts and defined cn_run, b9_run, sm_run, b43_run and the C3 extractor (want_cells, c3_check). It then
# makes its OWN control calls of bl815, bl809 and bl843 below, so each B_ baseline flag, each RAN set a kill is credited
# against and each receipt world a mutant call reads is set in this process, by this file; bl845's worlds are seeded by
# its rr twin, the first call that reads them. Each validator mutant is written beside record-only-diff.sh in that
# control tree (world.sh's mkmut), so it finds every sibling the real validator does, and the receipt asks it in
# process. A mutant call names its ONE deciding cell (plus the receipt's ctl cell), and must fail that cell and leave
# ctl standing; its kill is credited only when the deciding cell's RAN line is in the full control call's output
# (kill_credit, BL-979 C2).
#
# THE MUTANT MATRIX. Each validator mutant runs on its deciding cell and the receipt's ctl cell, inside one receipt
# call; each rr mutant runs the full call of its receipt copy, after the unmodified twin of that copy passed C3. The ctl
# cell and the twin print no label of their own (the helper refuses a `FAIL ctl:` line, and the twin's ok line is a
# sentence), so every row is `twins=-` with that reason. The full mutant x cell matrix is printed by `--matrix` (one
# MATRIX-ROW per mutant: the cells its full receipt call fails, or for an rr mutant whether C3 held), re-measured
# whenever a cell or a mutant is added or changed.
# Measured (--matrix): every row's deciding cell is in the set its full receipt call trips, and no mutant trips
# ctl; each rr mutant leaves C3 failed with exit 0 and no cell tripped, so it fails C3 alone.
# MUTANT-MATRIX cn-n1-no-normaliser decides=inner twins=- why=its twin is bl815 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX cn-n2-no-warn decides=un twins=- why=its twin is bl815 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX cn-n3-dotdot-from-story decides=dd twins=- why=its twin is bl815 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX cn-n5-split-readers decides=xr twins=- why=its twin is bl815 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX cn-n4-no-ignore-exempt decides=ign twins=- why=its twin is bl815 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX cn-n6-silent-unreadable decides=gu twins=- why=its twin is bl815 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-m1-no-kunq decides=kunq twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-m2-quoted decides=kq twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-m3-no-exempt decides=red twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-m4-refusal decides=rc twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-q1-no-warn decides=qoff twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-q2-all-kinds decides=qkind twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-q3-no-cap-partition decides=qcap twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-q4-bare-silent decides=qbareoff twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-q5-no-basename decides=qbare twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-q6-no-ext decides=qext twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-q7-abs-read decides=qabs twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-q8-elided-read decides=qel twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-q9-glob-read decides=qglob twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-q10-no-norm decides=qdot twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-q11-path-always decides=qtrk twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-q12-refusal decides=qlvl twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-q13-refused-bump decides=qrc twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-q14-abs-in-top-silent decides=qabsin twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-q15-elide-after-strip decides=qtel twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-q16-all-words decides=qnl twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-q17-no-line-cut decides=qln twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-q18-section-read decides=qsec twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-q19-sticky-header decides=qac twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-q20-empty-cell decides=qemp twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-q21-wt-acquit-removed decides=qwtb twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b9-q22-wt-top-rest decides=qwt twins=- why=its twin is bl809 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# (q) tripped sets, MEASURED by the --matrix run, 22 of 22 b9-q rows equal these sets: q1 [qabsin qbareoff qdel qdot
# qemp qign qln qlvl qoff qrc qwtf qwtun]; q2 [qkind]; q3 [qcap]; q4 [qbareoff]; q5 [qbare];
# q6 [qext]; q7 [qabs]; q8 [qel qtel] (inherent: one elision test serves both cells); q9 [qglob]; q10 [qdot]; q11
# [qtrk qwt] (inherent: one tracked lookup serves both); q12 [qlvl qrc]
# (inherent: a refusal moves the exit qrc holds); q13 [qrc]; q14 [qabsin qwtun]
# (re-anchored on the no-worktree branch, which both cells reach); q15 [qtel]; q16 [qnl]; q17 [qln]; q18 [qsec]; q19
# [qac]; q20 [qemp]; q21 [qwtb]; q22 [qwt
# qwtf] (inherent: one worktree-relative rest serves both, and qwtf's line
# then names the toplevel-relative rest).
# MUTANT-MATRIX b43-path-only decides=r2 twins=- why=its twin is bl843 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b43-legacy-any decides=r3 twins=- why=its twin is bl843 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b43-und-binds decides=und twins=- why=its twin is bl843 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b43-never-ok decides=r1 twins=- why=its twin is bl843 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b43-dup-3 decides=r5 twins=- why=its twin is bl843 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b43-no-strip decides=r8 twins=- why=its twin is bl843 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b43-no-dirty decides=r9 twins=- why=its twin is bl843 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b43-no-escape decides=esc twins=- why=its twin is bl843 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b43-first-dollar decides=cmd twins=- why=its twin is bl843 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b43-count-all decides=r9 twins=- why=its twin is bl843 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b43-first-count decides=d3 twins=- why=its twin is bl843 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b43-no-counts decides=cnt twins=- why=its twin is bl843 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b43-counts-stale decides=cntnb twins=- why=its twin is bl843 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b43-replay-count decides=rp twins=- why=its twin is bl843 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b43-no-cmd-trim decides=trim twins=- why=its twin is bl843 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX b43-counts-nophrase decides=cntpl twins=- why=its twin is bl843 ctl, run in the same receipt call and refused by the FAIL ctl check; no label here emits it
# MUTANT-MATRIX rr-bl809-dead decides=c3-bl809 twins=- why=its twin is the unmodified copy of receipt-bl809.sh that rr_twin drives first (T_bl809); its ok line is a sentence, not a label
# MUTANT-MATRIX rr-bl815-dead decides=c3-bl815 twins=- why=its twin is the unmodified copy of receipt-bl815.sh that rr_twin drives first (T_bl815); its ok line is a sentence, not a label
# MUTANT-MATRIX rr-bl843-dead decides=c3-bl843 twins=- why=its twin is the unmodified copy of receipt-bl843.sh that rr_twin drives first (T_bl843); its ok line is a sentence, not a label
# MUTANT-MATRIX rr-bl845-dead decides=c3-bl845 twins=- why=its twin is the unmodified copy of receipt-bl845.sh that rr_twin drives first (T_bl845); its ok line is a sentence, not a label
# MUTANT-MATRIX rr-bl815-gu-unreachable decides=c3-bl815 twins=- why=its twin is the unmodified copy of receipt-bl815.sh that rr_twin drives first (T_bl815); its ok line is a sentence, not a label
# MUTANT-MATRIX rr-bl843-r5-unreachable decides=c3-bl843 twins=- why=its twin is the unmodified copy of receipt-bl843.sh that rr_twin drives first (T_bl843); its ok line is a sentence, not a label
# MUTANT-MATRIX rr-bl845-hand-unreachable decides=c3-bl845 twins=- why=its twin is the unmodified copy of receipt-bl845.sh that rr_twin drives first (T_bl845); its ok line is a sentence, not a label
# MUTANT-MATRIX-DYNAMIC rcpt-helpers why=each name reaches mutant_killed as its helper literal first argument, rowed above
# MUTANT-MATRIX-REMEASURE bash core/fixtures/story-evidence-receipts-mutants/run.sh --matrix
#
# Exit: 0 every arm and every mutant passed, 1 one did not, 2 the fixture could not run.
set -u
MDIR="$(cd "$(dirname "$0")" && pwd)"
MATRIX=0; [ "${1:-}" = --matrix ] && MATRIX=1
SER="$MDIR/../story-evidence-receipts/run.sh"
[ -f "$SER" ] || { echo "story-evidence-receipts-mutants: FIXTURE BROKEN -- $SER is absent, so there is no control tree to score a mutant in" >&2; exit 2; }
# shellcheck source=/dev/null
. "$SER" || { echo "story-evidence-receipts-mutants: FIXTURE BROKEN -- sourcing story-evidence-receipts/run.sh failed" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/story-evidence-receipts/run.sh"
# mutant.sh needs ok() and bad(), which the sourced file defines.
MUT_LIB="$MDIR/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "story-evidence-receipts-mutants: FIXTURE BROKEN -- lib/mutant.sh is absent" >&2; exit 2; }
# shellcheck source=/dev/null
. "$MUT_LIB" || exit 2
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
# The sourced file must have handed over its control tree, its receipts and its functions; world.sh's mkmut is the
# 4-argument one (<name> he <from> <to>), and it writes each mutant beside record-only-diff.sh in $HECTL's tree.
{ [ -f "${HECTL:-}" ] && [ -f "$(dirname "$HECTL")/record-only-diff.sh" ] && [ -f "${R845:-}" ] && [ -d "${SES:-}" ] \
  && declare -F want_cells c3_check ran_set cn_run b9_run sm_run b43_run mkmut rcpt_run >/dev/null; } \
  || { echo "story-evidence-receipts-mutants: FIXTURE BROKEN -- story-evidence-receipts/run.sh did not hand over its control tree, receipts or functions" >&2; exit 2; }

echo "story-evidence-receipts-mutants:"
# --- THE bl815, bl809 AND bl843 CONTROL CALLS, this file's own -------------------------------------------------------------------
# Each sets its receipt's B_ flag only in its passing branch, seeds the receipt's worlds once (every mutant call below
# reads them), and holds the RAN set every kill of that receipt is credited against.
cn_out="$(cn_run "$HECTL")"; cn_rc=$?
if [ "$cn_rc" -eq 0 ]; then ok "CAPTURE NORMALISATION: inner ../, absolute and aliased spellings of a tracked capture are judged (no-command), a leading ../ is outside the repository (WARN, or red-untracked when RED), untracked and outside citations WARN capture-unresolved with their reasons, a frozen-.gitignore'd one prints nothing, the exit is unchanged, --list-captures lists the toplevel spellings, and both readers agree on one ./ token"; B_cn=1
else bad "CAPTURE NORMALISATION: receipt-bl815.sh exited $cn_rc on the shipped validator: $(tr '\n' ' ' <<<"$cn_out")"; fi
CN_GATED="$(want_cells "$R815")"
if c3_msg="$(c3_check "$R815" "$cn_out")"; then ok "RAN SET bl815: the full control call ran exactly the cells the receipt's code gates ($(tr '\n' ' ' <<<"$CN_GATED"))"
else bad "$c3_msg"; fi
b9_out="$(b9_run "$HECTL")"; b9_rc=$?
if [ "$b9_rc" -eq 0 ]; then ok "BL-809 ARMS: an unquoted multi-word -k is REFUSED k-unquoted, quoted and single-word -k are quiet, a <tree> placeholder WARNs without moving the exit, <redacted> and <base-worktree> are quiet; (q) WARNs ac-citation-unresolved on an untracked, deleted, ignored or outside test-row citation, an untracked bare basename, an untracked absolute path under the toplevel, under a registered worktree at <frozen> or under an unregistered .claude/worktrees directory, an untracked citation in a row with an empty Case cell (printed as case -) and an untracked path with a :line suffix, exits 0 on a story with no refusal, and is quiet on a tracked path (also spelt under a registered worktree at <frozen>), a path under a registered worktree whose HEAD is not <frozen>, a basename tracked elsewhere, a non-test row, a capture (capture-unresolved instead), absolute tokens outside the toplevel, inner and trailing elided and glob tokens, a dotted identifier, an unbackticked non-leading token, an AC-keyed table and a table under a later heading"; B_b9=1
else bad "BL-809 ARMS: receipt-bl809.sh exited $b9_rc on the shipped validator: $(tr '\n' ' ' <<<"$b9_out")"; fi
B9_GATED="$(want_cells "$R809")"
if c3_msg="$(c3_check "$R809" "$b9_out")"; then ok "RAN SET bl809: the full control call ran exactly the cells the receipt's code gates ($(tr '\n' ' ' <<<"$B9_GATED"))"
else bad "$c3_msg"; fi
b43_out="$(b43_run "$HECTL")"; b43_rc=$?
if [ "$b43_rc" -eq 0 ]; then ok "CAPTURE-HEADS: --render-dar renders each capture's head (+dirty kept, the replay block's own), its (a)-arm command (a backtick in a double-backtick span) and the full-collection capture's last count only; --check accepts the pasted block, refuses one retyped head stale, a missing block (post-epoch) and two blocks; a pre-epoch or undecidable story WARNs; the block's own paths are never citations; counts: capture-heads block is a run only with a fresh counted block"; B_b43=1
else bad "CAPTURE-HEADS: receipt-bl843.sh exited $b43_rc on the shipped validator: $(tr '\n' ' ' <<<"$b43_out")"; fi
B43_GATED="$(want_cells "$R843")"
if c3_msg="$(c3_check "$R843" "$b43_out")"; then ok "RAN SET bl843: the full control call ran exactly the $(grep -c . <<<"$B43_GATED") cells the receipt's code gates"
else bad "$c3_msg"; fi

# --- --matrix: each mutant's FULL receipt call (no cell named), so every cell it trips is printed ----------------
mfails() { sed -n 's/^FAIL \([A-Za-z0-9_-]*\):.*/\1/p' <<<"$1" | LC_ALL=C sort -u | tr '\n' ' '; }
mrow() { # <run function> <name> <from> <to> <deciding cell> <label>: one MATRIX-ROW, the mutant's full receipt call
  local run="$1" m o mrc; shift
  if ! m="$(mkmut "$1" he "$2" "$3")" || [ -z "$m" ]; then bad "FIXTURE ERROR: mutation '$1' matched nothing"; return; fi
  o="$("$run" "$m")"; mrc=$?
  echo "MATRIX-ROW $1 decides=$4 rc=$mrc tripped=[$(mfails "$o")]"
}
mrr() { # <name> <receipt id> <copy> <its full-call output> <its rc>: one MATRIX-ROW for an rr mutant
  local t=failed
  c3_check "$3" "$4" >/dev/null && t=held
  echo "MATRIX-ROW $1 decides=c3-$2 c3=$t rc=$5 tripped=[$(mfails "$4")]"
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

# --- BL-815 CAPTURE NORMALISATION (cn_*) ------------------------------------------------------
# A separately named block: the --list-captures arms land beside it, not inside it. receipt-bl815.sh
# owns the world and the cells (its header lists them). Every relative token resolves from the
# TOPLEVEL: an inner `a/../b`, physical-absolute and symlinked-alias spellings of a tracked capture
# with no command line must each be REFUSED no-command (judged, not merely warned); the toplevel
# spelling is the unchanged control; a leading `../` climbs out and WARNs capture-unresolved
# (outside) although the story-directory reading names a tracked file, and a RED one is REFUSED
# red-untracked; an untracked non-ignored citation and an other-worktree / climbing one WARN with
# their reasons; one the frozen .gitignore ignores prints nothing; the WARN never moves the exit;
# --list-captures lists the toplevel spellings; and cell xr holds BOTH readers to one answer on one
# `./` token. Every mutant is written beside record-only-diff.sh in the control tree and must FAIL
# its own named cell and leave the ctl cell standing.
# Every receipt below is SOURCED in a fresh subshell (rcpt_run), and its world is seeded ONCE into
# $WORK/rw-<receipt> by the control call and read by every mutant call (no call writes into it).
cn_mutant() { # <name> <from> <to> <cell that must FAIL> <label>
  [ "$MATRIX" = 0 ] || { mrow cn_run "$@"; return; }
  local m o mrc
  if ! m="$(mkmut "$1" he "$2" "$3")" || [ -z "$m" ]; then bad "FIXTURE ERROR: mutation '$1' matched nothing"; return; fi
  o="$(cn_run "$m" "$4")"; mrc=$?
  if [ "$mrc" -eq 9 ]; then bad "FIXTURE BROKEN: mutation '$1' -- the receipt could not run ($(tr '\n' ' ' <<<"$o"))"
  elif grep -q '^FAIL ctl:' <<<"$o"; then bad "MUTATION '$1' moved the toplevel control cell -- $5"
  elif [ "$mrc" -eq 1 ] && grep -q "^FAIL $4:" <<<"$o"; then kill_credit "${B_cn:-0}" "$cn_out" "$CN_GATED" "$4" "$1"; mutant_killed "${KC:-0}" "$1" "MUTATION '$1' killed by cell $4: $5"
  else bad "MUTATION '$1' SURVIVED (rc=$mrc, cell $4 did not fail) -- $5"; fi
}
# BL-849: the helper records its failures with bad(), which writes the fixture-level rc. A local of the
# same name shadowed it and lost every failure on return. This arm drives the real helper with an anchor
# that matches nothing and asserts the exit counter moved by exactly one; it dies if the local returns.
_r849=$rc; rc=0
cn_mutant b849-never-applies ZZQX_NEVER_ANCHOR_849 x inner "BL-849 probe" 2>/dev/null
if [ "$rc" -eq 1 ]; then rc=$_r849; ok "BL-849 did not apply: a cn_mutant mutant reaches the exit counter"
else rc=1; bad "BL-849: a DID-NOT-APPLY cn_mutant mutant did not reach the exit counter"; fi
cn_mutant cn-n1-no-normaliser '    cap_norm "$t" || CN=""' '    CN="$t"' inner "N1: the normaliser removed, an a/../b capture is not judged"
cn_mutant cn-n2-no-warn '[ -z "$ureason" ] || warn "capture-unresolved' '[ -z "$ureason" ] || : "capture-unresolved' un "N2: the capture-unresolved WARN removed, an untracked citation is silent"
cn_mutant cn-n3-dotdot-from-story '    *) p="$t" ;;' '    ./*|../*) p="${STORY%/*}/$t" ;; *) p="$t" ;;' dd "N3: ./ and ../ resolved against the story's directory, not the toplevel"
cn_mutant cn-n5-split-readers 'cap_tokens 0 <<<"$TEXT" | cap_resolve' 'cap_tokens 0 <<<"$TEXT" | while IFS="$TAB" read -r r x; do [ "${x#./}" = "$x" ] || x="${STORY%/*}/$x"; printf "%s\t%s\n" "$r" "$x"; done | cap_resolve' xr "N5: the handoff arms read ./ from the story's directory while --list-captures reads it from the toplevel"
cn_mutant cn-n4-no-ignore-exempt 'elif ignored_at_frozen "$cap"; then' 'elif false; then' ign "N4: the frozen-.gitignore exemption removed, a gitignored full-suite capture WARNs"
cn_mutant cn-n6-silent-unreadable 'warn "gitignore-unreadable' ': "gitignore-unreadable' gu "N6: an unreadable frozen .gitignore set is not named, the WARNs lose their cause"
# --- end BL-815 CAPTURE NORMALISATION -----------------------------------------------------------

# --- BL-809 ARMS (b9_*) ---------------------------------------------------------------------------
# Arms (m) K-UNQUOTED (a refusal) and (n) PLACEHOLDER (a WARN). receipt-bl809.sh owns the world and
# the cells (its header lists them): `-k alpha or beta` unquoted is REFUSED k-unquoted; `-k "a or b"`,
# `-k 'a and b'` and single-word `-k alpha` are quiet; `<tree>` on a `$ ` line WARNs placeholder;
# `<redacted>` and `<base-worktree>` are quiet; the placeholder WARN never moves the exit; a capture
# with no command line is the unchanged no-command control (cell ctl). Every mutant is written beside
# record-only-diff.sh in the control tree and must FAIL its own named cell and leave ctl standing.
b9_mutant() { # <name> <from> <to> <cell that must FAIL> <label>
  [ "$MATRIX" = 0 ] || { mrow b9_run "$@"; return; }
  local m o mrc
  if ! m="$(mkmut "$1" he "$2" "$3")" || [ -z "$m" ]; then bad "FIXTURE ERROR: mutation '$1' matched nothing"; return; fi
  o="$(b9_run "$m" "$4")"; mrc=$?
  if [ "$mrc" -eq 9 ]; then bad "FIXTURE BROKEN: mutation '$1' -- the receipt could not run ($(tr '\n' ' ' <<<"$o"))"
  elif grep -q '^FAIL ctl:' <<<"$o"; then bad "MUTATION '$1' moved the no-command control cell -- $5"
  elif [ "$mrc" -eq 1 ] && grep -q "^FAIL $4:" <<<"$o"; then kill_credit "${B_b9:-0}" "$b9_out" "$B9_GATED" "$4" "$1"; mutant_killed "${KC:-0}" "$1" "MUTATION '$1' killed by cell $4: $5"
  else bad "MUTATION '$1' SURVIVED (rc=$mrc, cell $4 did not fail) -- $5"; fi
}
# BL-849: the helper records its failures with bad(), which writes the fixture-level rc. A local of the
# same name shadowed it and lost every failure on return. This arm drives the real helper with an anchor
# that matches nothing and asserts the exit counter moved by exactly one; it dies if the local returns.
_r849=$rc; rc=0
b9_mutant b849-never-applies ZZQX_NEVER_ANCHOR_849 x inner "BL-849 probe" 2>/dev/null
if [ "$rc" -eq 1 ]; then rc=$_r849; ok "BL-849 did not apply: a b9_mutant mutant reaches the exit counter"
else rc=1; bad "BL-849: a DID-NOT-APPLY b9_mutant mutant did not reach the exit counter"; fi
b9_mutant b9-m1-no-kunq 'if [ -n "$kl" ]; then' 'if false; then' kunq "M1: arm (m) removed, an unquoted multi-word -k passes"
b9_mutant b9-m2-quoted $'[^[:space:]"\'"\'"\']+[[:space:]]+(or' '[^[:space:]]+[[:space:]]+(or' kq "M2: arm (m) accepts a quoted expression as unquoted"
b9_mutant b9-m3-no-exempt 'if (p != "<redacted>" && p != "<base-worktree>") print' 'print' red "M3: arm (n)'s <redacted>/<base-worktree> exemptions removed"
b9_mutant b9-m4-refusal 'warn "placeholder' 'refuse "placeholder' rc "M4: arm (n) made a refusal, so a placeholder moves the exit"
# Arm (q) AC-CITATION-UNRESOLVED (receipt-bl809.sh's q-cells): its WARN, its tier, the test-row narrowing, the capture
# partition, the basename and extension rules, the not-read token shapes and the normaliser, one deciding cell each.
b9_mutant b9-q1-no-warn 'warn "ac-citation-unresolved $STORY: $a_id' ': "ac-citation-unresolved $STORY: $a_id' qoff "Q1: the (q) WARN removed, an untracked test-row citation is silent"
b9_mutant b9-q2-all-kinds 'if (kind != "test") next' 'if (0) next' qkind "Q2: the test-row narrowing removed, a predicate row's path is judged"
b9_mutant b9-q3-no-cap-partition 'case "$acq_caps" in *" $a_t "*) continue ;; esac' ':' qcap "Q3: the capture partition removed, an untracked capture is reported by (q) too"
b9_mutant b9-q4-bare-silent 'print "bare\t" L[i]; continue' 'continue' qbareoff "Q4: a bare basename tracked nowhere is acquitted"
b9_mutant b9-q5-no-basename '|| (p in base)) continue' ') continue' qbare "Q5: the basename rule removed, a bare basename tracked under another directory fires"
b9_mutant b9-q6-no-ext ' || !(substr(p, RSTART + 2) in ext)' '' qext "Q6: the extension rule removed, a dotted identifier is judged as a basename"
b9_mutant b9-q7-abs-read '/*) continue ;;' '/*) cap_norm "$a_t" || CN="" ;;' qabs "Q7: absolute tokens outside the toplevel read, an API route fires"
b9_mutant b9-q8-elided-read 'if (index(w, "...")) return ""; ' '' qel "Q8: elided tokens read, a ... path fires"
b9_mutant b9-q9-glob-read 'if (w !~ /^[A-Za-z0-9_.\/-]+$/' 'if (w !~ /^[A-Za-z0-9_.\/*-]+$/' qglob "Q9: glob tokens read, a glob fires"
b9_mutant b9-q10-no-norm '*) cap_norm "$a_t" || CN="" ;;' '*) CN="$a_t" ;;' qdot "Q10: the normaliser removed, a leading ../ is judged as a path instead of outside the repository"
b9_mutant b9-q11-path-always 'if (!(p in have)) print "path\t" L[i]' 'print "path\t" L[i]' qtrk "Q11: the tracked lookup removed, a tracked test file fires"
b9_mutant b9-q12-refusal 'warn "ac-citation-unresolved $STORY: $a_id' 'refuse "ac-citation-unresolved $STORY: $a_id' qlvl "Q12: (q) made a refusal, so an unresolved citation moves the exit"
b9_mutant b9-q13-refused-bump 'warn "ac-citation-unresolved $STORY: $a_id' 'refused=1; warn "ac-citation-unresolved $STORY: $a_id' qrc "Q13: the WARN kept and the refusal counter bumped, so a story with no other refusal exits 1"
b9_mutant b9-q14-abs-in-top-silent 'if [ -z "$a_wm" ]; then cap_norm "${a_t#"$TOP"/}" || CN=""' 'if [ -z "$a_wm" ]; then continue' qabsin "Q14: an absolute token under the toplevel not read, an untracked in-toplevel citation is silent"
b9_mutant b9-q15-elide-after-strip 'if (index(w, "...")) return ""; sub(/^[(<\[]+/, "", w); sub(/::.*/, "", w); sub(/[.,;:)>\]]+$/, "", w)' 'sub(/^[(<\[]+/, "", w); sub(/::.*/, "", w); sub(/[.,;:)>\]]+$/, "", w); if (index(w, "...")) return ""' qtel "Q15: the elision test after the punctuation strip, a trailing ... is stripped and the path read"
b9_mutant b9-q16-all-words 'split(lead, W, /[[:space:]]+/); acq_emit(W[1])' 'm = split(lead, W, /[[:space:]]+/); for (x = 1; x <= m; x++) acq_emit(W[x])' qnl "Q16: every unbackticked word read, the acquitted non-leading node token fires"
b9_mutant b9-q17-no-line-cut '; sub(/:[0-9]+(-[0-9]+)?$/, "", w)' '' qln "Q17: the :line cut removed, an untracked path with a line suffix is silent"
b9_mutant b9-q18-section-read 'on && /^## / { exit }' 'on && /^## / { next }' qsec "Q18: a later ## heading does not end the read, a strategy table under it is judged"
b9_mutant b9-q19-sticky-header '{ hasres = (ph == "Strategy id" && pres); next }' '{ if (ph == "Strategy id" && pres) hasres = 1; next }' qac "Q19: the header binding kept past the strategy table, an AC-keyed table row is judged"
b9_mutant b9-q20-empty-cell '(cs == "" ? "-" : cs)' 'cs' qemp "Q20: an empty Case cell printed empty, so the tab-IFS read shifts the columns of its WARN"
b9_mutant b9-q21-wt-acquit-removed '          else continue' '          else cap_norm "${a_t#"$TOP"/}" || CN=""' qwtb "Q21: the registered-worktree acquittal removed, a citation under a worktree whose HEAD is not <frozen> is judged by its toplevel-relative rest and fires"
b9_mutant b9-q22-wt-top-rest 'then cap_norm "${a_t#"$a_wm"/}" || CN=""' 'then cap_norm "${a_t#"$TOP"/}" || CN=""' qwt "Q22: a citation under the <frozen> worktree judged by its toplevel-relative rest, a tracked file fires (the defect)"
# --- end BL-809 ARMS ------------------------------------------------------------------------------

# --- BL-843 CAPTURE-HEADS BLOCK (b43_*) -----------------------------------------------------------
# --render-dar, --check and the (o) fold. receipt-bl843.sh owns the worlds and the cells (its header
# lists them: ctl r1-r9, esc, cmd, d3, cnt and its near-misses cntnb/cntpl, rp, trim, und). Every mutant is
# written beside record-only-diff.sh in the control tree and must FAIL its own named cell and leave
# the ctl cell (a story citing nothing renders the two markers, --check 0) standing.
b43_mutant() { # <name> <from> <to> <cell that must FAIL> <label>
  [ "$MATRIX" = 0 ] || { mrow b43_run "$@"; return; }
  local m o mrc
  if ! m="$(mkmut "$1" he "$2" "$3")" || [ -z "$m" ]; then bad "FIXTURE ERROR: mutation '$1' matched nothing"; return; fi
  o="$(b43_run "$m" "$4")"; mrc=$?
  if [ "$mrc" -eq 9 ]; then bad "FIXTURE BROKEN: mutation '$1' -- the receipt could not run ($(tr '\n' ' ' <<<"$o"))"
  elif grep -q '^FAIL ctl:' <<<"$o"; then bad "MUTATION '$1' moved the no-capture control cell -- $5"
  elif [ "$mrc" -eq 1 ] && grep -q "^FAIL $4:" <<<"$o"; then kill_credit "${B_b43:-0}" "$b43_out" "$B43_GATED" "$4" "$1"; mutant_killed "${KC:-0}" "$1" "MUTATION '$1' killed by cell $4: $5"
  else bad "MUTATION '$1' SURVIVED (rc=$mrc, cell $4 did not fail) -- $5"; fi
}
b43_mutant b43-path-only 'if (a != r) {' 'if (substr(a, 1, index(a, " — ")) != substr(r, 1, index(r, " — "))) {' r2 "--check compares only the path column, so a retyped head passes"
b43_mutant b43-legacy-any '    if [ "$DL" = bind ]; then refuse "$DAR_MSG"' '    if false; then refuse "$DAR_MSG"' r3 "the legacy exemption accepts any story with no block"
b43_mutant b43-und-binds '  DL=undecidable; DL_WHY=""' '  DL=bind; DL_WHY=""' und "an undecidable epoch refuses instead of warning"
b43_mutant b43-never-ok '  DAR_STATE=ok' '  DAR_STATE=stale; DAR_MSG="dar-heads-stale $STORY: forced"' r1 "a byte-identical block refused stale"
b43_mutant b43-dup-3 'if [ "${nb:-0}" -ge 2 ]; then' 'if [ "${nb:-0}" -ge 3 ]; then' r5 "two blocks are not a duplicate"
b43_mutant b43-no-strip 'dar_strip() { LC_ALL=C awk "$DAR_STRIP_AWK"; }' 'dar_strip() { cat; }' r8 "the block region is not stripped before cap_tokens, so its own paths are citations"
b43_mutant b43-no-dirty '  case "$h" in *"(+dirty)") CH_DIRTY=1 ;; esac' '  case "$h" in NEVER-DIRTY) CH_DIRTY=1 ;; esac' r9 "a (+dirty) head renders as clean"
b43_mutant b43-no-escape "  case \"\$1\" in *'\`'*) printf" '  case "$1" in NEVER-A-BACKTICK) printf' esc "a command holding a backtick renders in a single-backtick span"
b43_mutant b43-first-dollar 'cmd="$(LC_ALL=C grep -E "$CMD_RE"' "cmd=\"\$(LC_ALL=C grep -E '^\\\$ '" cmd "the rendered command is the first \$ line, not the (a)-arm reader's"
b43_mutant b43-count-all '      if [ -n "$fcp" ] && grep -qxF -- "$p" <<<"$fcp"; then' '      if true; then' r9 "every capture renders a count, so the uncited dirty capture's 1 passed renders"
b43_mutant b43-first-count "(passed|failed)([^A-Za-z]|\$)' | tail -n 1)\"" "(passed|failed)([^A-Za-z]|\$)' | head -n 1)\"" d3 "the first count line renders, not the last"
b43_mutant b43-no-counts '    dar_counts_ok "$fc" || ev_none' '    false || ev_none' cnt "counts: capture-heads block with a fresh counted block is refused full-collection-none"
b43_mutant b43-counts-stale '  [ "$DAR_STATE" = ok ] && [ "$DAR_NCOUNT" -gt 0 ]' '  true' cntnb "counts: capture-heads block is accepted with no block"
b43_mutant b43-replay-count '        [ -z "$rl" ] || cnt=""' '        :' rp "a replay capture cited on Full-collection run: renders its count, so its 1 failed is accepted as the run"
b43_mutant b43-no-cmd-trim '      cmd="${cmd%"${cmd##*[![:space:]]}"}"' '      :' trim "the rendered command keeps its trailing blanks"
b43_mutant b43-counts-nophrase '  case "$1" in *"counts: capture-heads block"*) ;; *) return 1 ;; esac' '  :' cntpl "a bare capture path is accepted as a run whenever a fresh block exists"
# --- end BL-843 CAPTURE-HEADS BLOCK -----------------------------------------------------------------

# --- BL-979 RAN SET RECEIPT MUTANTS (rr_*) -----------------------------------------------------------
# Each RAN SET arm above against a receipt whose want() gate is dead. Copies live in ONE scratch dir with
# he-inproc.sh beside them; each is driven on the full call over its receipt's already-seeded world
# ($WORK/rw-<receipt>, or $SMW for bl845; no re-seed) with $HECTL, which has record-only-diff.sh beside it. An UNMODIFIED twin
# in that dir must pass C3 first; a mutant must exit 0 with no FAIL line (every other cell it reaches still
# holds) and fail ONLY C3, keyed on C3's own `RAN SET` message, never on exit 9.
RR="$WORK/rr"; mkdir -p "$RR"; cp "$SES/he-inproc.sh" "$RR/he-inproc.sh"
[ -f "$(dirname "$HECTL")/record-only-diff.sh" ] || bad "FIXTURE BROKEN: no record-only-diff.sh beside $HECTL, so no receipt copy below can run"
# Each receipt by the fixture-relative path its verify: lines and BL-915 E1 name it (a moved block keeps this line).
for _rp in story-evidence-scaffold/receipt-bl809.sh story-evidence-scaffold/receipt-bl815.sh story-evidence-scaffold/receipt-bl843.sh story-evidence-scaffold/receipt-bl845.sh; do
  [ -f "$DIR/../$_rp" ] || bad "FIXTURE BROKEN: $_rp is not at the path its verify: lines name"
done
T_bl809=0 T_bl815=0 T_bl843=0 T_bl845=0
rr_call() { # <receipt id> <copy>: the full call over the receipt's seeded worlds (bl845 takes them as an argument)
  case "$1" in
    bl845) rcpt_run - "$2" "$HECTL" "$SMW" "" 2>&1 ;;
    *) rcpt_run "$WORK/rw-$1" "$2" "$HECTL" 2>&1 ;;
  esac
}
rr_twin() { # <receipt id>: sets T_<id>=1 when the unmodified copy in $RR passes C3
  local o msg; cp "$SES/receipt-$1.sh" "$RR/twin-$1.sh"
  o="$(rr_call "$1" "$RR/twin-$1.sh")"
  if cmp -s "$SES/receipt-$1.sh" "$RR/twin-$1.sh" && msg="$(c3_check "$RR/twin-$1.sh" "$o")"; then
    case "$1" in bl809) T_bl809=1 ;; bl815) T_bl815=1 ;; bl843) T_bl843=1 ;; bl845) T_bl845=1 ;; esac
    ok "RAN SET twin $1: the unmodified copy beside he-inproc.sh in the mutant dir passes C3"
  else bad "FIXTURE BROKEN: the unmodified twin of receipt-$1.sh in $RR fails C3 (${msg:-not a byte copy}), so no mutant beside it can be scored"; fi
}
rr_mutant() { # <name> <receipt id> <from> <to> <label>
  local m="$RR/$1.sh" o mrc msg n
  n="$(FROM="$3" awk 'BEGIN{f=ENVIRON["FROM"]} {s=$0; while ((p=index(s,f))) {c++; s=substr(s,p+length(f))}} END{print c+0}' "$SES/receipt-$2.sh")"
  if [ "$n" != 1 ]; then bad "FIXTURE ERROR: mutation '$1' anchor occurs $n times in receipt-$2.sh, want 1"; return; fi
  FROM="$3" TO="$4" awk 'BEGIN{f=ENVIRON["FROM"]; t=ENVIRON["TO"]} !done && (p=index($0,f)) {$0=substr($0,1,p-1) t substr($0,p+length(f)); done=1} {print}' "$SES/receipt-$2.sh" > "$m"
  if cmp -s "$SES/receipt-$2.sh" "$m"; then bad "FIXTURE ERROR: mutation '$1' DID NOT APPLY"; return; fi
  o="$(rr_call "$2" "$m")"; mrc=$?
  [ "$MATRIX" = 0 ] || { mrr "$1" "$2" "$m" "$o" "$mrc"; return; }
  if msg="$(c3_check "$m" "$o")"; then bad "MUTATION '$1' SURVIVED (C3 held on the mutant) -- $5"
  elif [ "$mrc" -ne 0 ] || grep -q '^FAIL ' <<<"$o"; then bad "MUTATION '$1' failed more than C3 (rc=$mrc: $(grep '^FAIL ' <<<"$o" | tr '\n' ' ')) -- $5"
  else
    case "$msg" in
      "RAN SET $1.sh: the full call ran ["*)
        case "$2" in
          bl809) mutant_killed "${T_bl809:-0}" "$1" "MUTATION '$1' killed by C3 ($msg): $5" ;;
          bl815) mutant_killed "${T_bl815:-0}" "$1" "MUTATION '$1' killed by C3 ($msg): $5" ;;
          bl843) mutant_killed "${T_bl843:-0}" "$1" "MUTATION '$1' killed by C3 ($msg): $5" ;;
          bl845) mutant_killed "${T_bl845:-0}" "$1" "MUTATION '$1' killed by C3 ($msg): $5" ;;
          *) bad "FIXTURE ERROR: mutation '$1' names receipt $2, which has no twin" ;;
        esac ;;
      *) bad "MUTATION '$1' C3 message is not C3's own: [$msg]" ;;
    esac
  fi
}
rr_twin bl809; rr_twin bl815; rr_twin bl843; rr_twin bl845
RR_DEAD_FROM='[ -z "$CELLS" ] && return 0; case' RR_DEAD_TO='[ -z "$CELLS" ] || case'
rr_mutant rr-bl809-dead bl809 "$RR_DEAD_FROM" "$RR_DEAD_TO" "bl809's want() reverted to the dead form, so the full call runs no gated cell"
rr_mutant rr-bl815-dead bl815 "$RR_DEAD_FROM" "$RR_DEAD_TO" "bl815's want() reverted to the dead form, so the full call runs no gated cell"
rr_mutant rr-bl843-dead bl843 "$RR_DEAD_FROM" "$RR_DEAD_TO" "bl843's want() reverted to the dead form, so the full call runs no gated cell"
rr_mutant rr-bl845-dead bl845 "$RR_DEAD_FROM" "$RR_DEAD_TO" "bl845's want() reverted to the dead form, so the full call runs no gated cell"
# gu, not lc: the gu block's PATH-shimmed git is the costliest subject in the receipt (30 counted starts per
# run), so the unreachable-gu mutant adds none of them; the twin above pays them once.
rr_mutant rr-bl815-gu-unreachable bl815 'if want gu; then' 'if want gu && false; then' "bl815's gu block unreachable, so one gated cell never runs"
rr_mutant rr-bl843-r5-unreachable bl843 'if want r5; then' 'if want r5 && false; then' "bl843's r5 block unreachable, so one gated cell never runs"
# hand, not a cell() call: the hand block is one validator call, so skipping it removes the least work from a
# mutant that otherwise pays the full bl845 call; every other cell still runs and still passes.
rr_mutant rr-bl845-hand-unreachable bl845 'if want hand; then' 'if want hand && false; then' "bl845's hand block unreachable, so one gated cell never runs"
# --- end BL-979 RAN SET RECEIPT MUTANTS ---------------------------------------------------------------

[ "$MATRIX" = 0 ] || exit "$rc"
# INPROC: every subject call the control calls and the mutants made through he-inproc.sh was answered in process.
# Positive conjunct: the log exists, so an unset variable cannot pass.
if [ -f "$UT_FALLBACK_LOG" ] && [ ! -s "$UT_FALLBACK_LOG" ]; then
  ok "INPROC: every validator, record-only-diff.sh and sprint-status.sh call the receipts made was answered in process"
else
  bad "INPROC: subject calls ran as processes: $(sort "$UT_FALLBACK_LOG" 2>/dev/null | uniq -c | tr '\n' ' ')"
fi
if [ "$rc" -eq 0 ]; then echo "PASS story-evidence-receipts-mutants"; else echo "FAIL story-evidence-receipts-mutants"; fi
exit "$rc"
