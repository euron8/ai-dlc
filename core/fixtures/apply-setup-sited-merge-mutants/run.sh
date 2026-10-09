#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# Hermetic against ambient AI_DLC_* tunables (enforcement-map I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# apply-setup-sited-merge-mutants/run.sh -- the mutation battery behind `apply-setup-sited-merge`.
# DISTRIBUTION-ONLY (see .dist-only).
#
# Usage: run.sh [--inner]
#        --inner  skip MP, the battery's probe of its own count gate. Passed only by MP itself, to
#                 the emptied copy it runs, so the probe does not recurse.
# Exit:  0 = the control resolved and every declared mutant was judged and killed, 1 = an assertion
#        failed, 2 = fixture broken.
#
# WHY THIS IS SPLIT OUT. The battery edits copies of core's own apply.sh and setup-site-drift.sh,
# which a consumer is denied editing, so proving the shipped arms can fail is a question about
# files only this repository changes. The consumer keeps every behavioural arm; the 24 mutants,
# their worlds and their drives were a third of the shipped fixture's CPU.
#
# ONE COPY OF THE PREDICATES. Both fixtures source `apply-setup-sited-merge/lib.sh`, so a mutant is
# judged against the worlds, drives and predicates the shipped arms use. Each `kill_if` line below
# prints the same text the unsplit fixture printed for that mutant.
#
# AN EMPTY BATTERY MUST FAIL. Before this split a copy with `MUTS=""` printed PASS: the mutants
# were judged inside `for m in $MUT_OK`, so a list that lost every member judged nothing and
# failed nothing. So every declared mutant must reach exactly one verdict -- a kill, a survival,
# a dead run, or DID NOT APPLY -- and MC, outside every loop over the list, requires the verdict
# count to EQUAL the declared count, the declared count to be non-zero, every declared name to
# have been judged, and at least one kill. A mutant in MUTS with no `case` arm below is
# declared-but-unjudged and MC names it. MP proves MC can fire: it runs a copy of this battery
# whose MUTS line is emptied and requires that copy to exit 1 with MC as its ONE failure, its
# control still resolving, and its `driving` line naming the copy's own tree.
#
# THE SUBJECT IS NEVER SKIPPED HERE. The shipped fixture prints SKIP for an apply.sh that predates
# the feature, because a consumer can be one pull behind. This battery never reaches a consumer,
# and a battery that SKIPs exits 0 having judged nothing -- the same silence MC exists to stop.

NAME=apply-setup-sited-merge-mutants
HERE="$(cd "$(dirname "$0")" && pwd)"
INNER=""
case "${1:-}" in
  "") ;;
  --inner) INNER=1 ;;
  *) echo "usage: run.sh [--inner]" >&2; exit 2 ;;
esac
SIB="$HERE/../apply-setup-sited-merge"
[ -f "$SIB/lib.sh" ] || { echo "$NAME: FIXTURE BROKEN -- $SIB/lib.sh is absent; no world or predicate exists to judge a mutant with" >&2; exit 2; }
. "$SIB/lib.sh"
grep -qF 'say RESOLVED setup-site-merge' "$REC/apply.sh" \
  || broken "$REC/apply.sh carries no \`say RESOLVED setup-site-merge\` line; every mutant below edits a subject that is not there"
echo "HERMETIC-CONSUMED $REC/apply.sh"
lib_init

# --- the control: the unmutated program, copied the way every mutant is -------------------------
CTL="$WORK/ctl"
mut_new "$CTL" || broken "the unmutated control copy could not be built"
bspawn "$WORK/ctl-clean" clean

# --- mutants: each a copy, each aimed at one arm -----------------------------------------------
read -r -d '' W2_FN <<'EOF'
w2_subst() { local c; c="$(consumer_path "$1")" || return 1; git -C "$DIST" show "${THEIRS}:core/$1" | sed -e 's|{deploy_command}|scripts/ecs-deploy.sh prod|g' -e 's|{smoke_test_command}|scripts/smoke.sh|g' > "$c.w2" && mv "$c.w2" "$c"; }
EOF
read -r -d '' W3_A <<'EOF'
awk -F'\t' -v r="$_r" '$1=="CORE-TEMPLATE-SUBSTITUTED" && $2==r {f=1} END {exit !f}' "$DT_DIR/ud.out" || return 1; printf 'SETUP-SITE-OK\t-\t\n' > "$DT_DIR/ssm.out"
EOF
A_LINE='detector_run ssm setup-site-drift.sh --file "$_p" "$DIST" "$CONSUMER" "$BASE" || return 1'
C_LINE='--ours "$_d/merged" "$DIST" "$CONSUMER" "$THEIRS" || return 1'
GATE='if [ "$rt_rc" -eq 0 ] && [ -z "$rt" ] \'
# The second acceptance's span-identity conjunct: every span's text equal at base and theirs.
SPANID='     && [ "$_stb" = "$_stt" ]; then'
# The already-merged shortcut's no-op-merge test. `if true` is the shortcut as it first shipped
# (outside-span OK alone); `if false` removes the shortcut.
SHORT='if git merge-file -p "$_cons" "$_d/b0" "$_d/t0" > "$_d/m0" 2>/dev/null && cmp -s "$_d/m0" "$_cons" \'
# The second acceptance's opening line. no-idempotence disables BOTH acceptances: with only the
# first gone, the second still accepts an already-merged file and the mutant reads as idempotent.
SHORT2='  if detector_run ssm setup-site-drift.sh --file "$_p" "$DIST" "$CONSUMER" "$THEIRS" && ssm_ok \'
# Theirs' exec bit is applied at both acceptances, so the mode mutant strips both.
SHORT_MODE='    sync_mode_from_theirs "$_r" "$_cons"'
# NO BUCKET TEST AND NO BUCKET MUTANT. The call site no longer tests the bucket: what refuses every
# CLASSIFY bucket other than BOTH-CHANGED is setup_site_merge itself, which reads BASE's and THEIRS'
# blobs first and needs a consumer file. So BOTH-ADDED (absent at base), UPSTREAM-DELETED+consumer-
# modified (absent at theirs) and UPSTREAM-MOD+consumer-deleted (no consumer file) all return 1
# there, and the ORPHANED-* rows name no sited path. D8b and D8 are the arms that hold that.
#
# NO "ABSENT LOCATOR READ AS EQUAL" MUTANT, because no world reaches it. The span texts are compared
# as strings and each must be non-empty: a site whose locator is absent at BASE gives an empty base
# text against a non-empty theirs text, unequal whatever the guard; and for both to be absent the
# locator must be absent at THEIRS, which already fails the `--file` OK conjunct before them.
# setup-site-drift.sh's c-hunk length test: a hunk touching a single-line site whose two sides differ
# in length is drift. laxC reverts it in the copy's checker; laxCa is the same mutation scored on the
# consumer-addition world, (a)'s side of the same blindness.
LAXC='        if [ $((l2 - l1)) -ne $((r2 - r1)) ]; then'
# Its a|d arm's range test: every deleted line of a `d` hunk must sit in a heading block. laxD
# reverts it to testing the hunk's first line alone.
LAXD='          for l in $(seq "$l1" "$l2"); do in_span "$l" || { _ad_ok=0; break; }; done'
MUTS="W1 W2 W3 W4 noD noIdem treeA mode ssdExit noD7 bareShort rcOnly spanId spanIdQ dDol dML dCom idemMode leak writeRestore finNote laxC laxCa laxD"
mk_mut() {
  local m="$WORK/m-$1"
  mut_new "$m" || return 1
  case "$1" in
    W1)     mut_sub "$m" "$CALL" '&& overwrite_from_theirs "$rel"; then' ;;
    W2)     mut_sub "$m" "$CALL" '&& w2_subst "$rel"; then' \
            && mut_sub "$m" 'setup_site_merge() { # <core-path>' "$W2_FN
setup_site_merge() { # <core-path>" ;;
    W3)     mut_sub "$m" "$A_LINE" "$W3_A" ;;
    W4)     mut_del "$m" "$C_LINE" 1 ;;
    noD)    mut_sub "$m" 'END { exit bad ? 1 : 0 }' 'END { exit 0 }' ;;
    noIdem) mut_sub "$m" "$SHORT" 'if false \' && mut_sub "$m" "$SHORT2" '  if false \' ;;
    bareShort) mut_sub "$m" "$SHORT" 'if true \' ;;
    rcOnly) mut_sub "$m" "$SHORT" 'if git merge-file -p "$_cons" "$_d/b0" "$_d/t0" > "$_d/m0" 2>/dev/null \' ;;
    dDol)   mut_sub "$m" '(^|[^$])[{][A-Za-z0-9_]+[}]' '[{][A-Za-z0-9_]+[}]' ;;
    dML)    mut_sub "$m" '      s = $0; out = ""' '      s = $0; out = ""; incom = 0' ;;
    dCom)   mut_sub "$m" 'i = index(s, "<!--")' 'i = 0' ;;
    idemMode) mut_subn "$m" "$SHORT_MODE" '    :' 2 ;;
    leak)   mut_sub "$m" '  # (b)' '  cp -p "$_cons" "$_cons.incoming.$$" # (b)' ;;
    writeRestore) mut_sub "$m" '  # (c)' '  cp -p "$_cons" "$_d/orig"; cat "$_d/merged" > "$_cons" # (c)' \
            && mut_sub "$m" "$C_LINE" '"$DIST" "$CONSUMER" "$THEIRS" || { cat "$_d/orig" > "$_cons"; return 1; }' ;;
    finNote) mut_sub "$m" 'if [ "$_fv_ss_rc" -eq 0 ] && awk' 'if true || awk' ;;
    laxC|laxCa) ssd_sub "$m" "$LAXC" '        if false; then' && ssd_mutated "$m"; return ;;
    laxD)   ssd_sub "$m" "$LAXD" '          in_span "$l1" || _ad_ok=0' && ssd_mutated "$m"; return ;;
    treeA)  mut_sub "$m" '--file "$_p" "$DIST" "$CONSUMER" "$BASE"' '"$DIST" "$CONSUMER" "$BASE"' ;;
    mode)   mut_del "$m" 'sync_mode_from_theirs "$_r" "$_tmp"' 0 ;;
    spanId|spanIdQ) mut_sub "$m" "$SPANID" '     ; then' ;;
    ssdExit) mut_sub "$m" "$C_LINE" '--ours "$_d/merged" "$DIST" "$CONSUMER" "$THEIRS" || :' ;;
    noD7)   mut_sub "$m" "$GATE" 'if [ "$rt_rc" -eq 0 ] \' ;;
  esac || return 1
  mutated "$m"
}
mut_world() { case "$1" in W1|W2|mode|noIdem|idemMode) echo clean ;; W3) echo b2twin ;; W4|writeRestore|leak) echo b1 ;; noD) echo d2 ;;
  treeA|finNote) echo d6a ;; ssdExit) echo b1b ;; noD7) echo d7 ;; bareShort) echo spanD ;; rcOnly|spanId) echo spanFar ;; spanIdQ) echo spanQ ;; laxC) echo delIM ;; laxCa) echo cadd ;; laxD) echo qd ;;
  dDol) echo dol ;; dML) echo ml ;; dCom) echo com ;; esac; }

# Every mutant copy and its world are built in the same bounded pool as the control's world. A
# mutant whose anchor misses writes `noapply` and builds no world; one that applied writes `applied`
# and goes through build_mark, so breap() requires its world like any other.
N_DECL=0; for m in $MUTS; do N_DECL=$((N_DECL+1)); done
mk_job() { # <mutant>
  if mk_mut "$1"; then
    echo applied > "$WORK/mstat.$1"
    build_mark "$WORK/mw-$1" "$(mut_world "$1")"
  else
    echo noapply > "$WORK/mstat.$1"
  fi
}
for m in $MUTS; do
  BUILT_N=$((BUILT_N+1))
  mk_job "$m" &
  bjobs=$((bjobs+1)); [ "$bjobs" -lt "$BPOOL" ] || { wait; bjobs=0; }
done
wait; bjobs=0
# Every verdict -- DID NOT APPLY, killed, survived, dead -- counts once, by name, toward MC.
N_VERD=0; N_KILL=0; JUDGED=" "
verdict() { N_VERD=$((N_VERD+1)); JUDGED="$JUDGED$1 "; }
MUT_OK=""
for m in $MUTS; do
  case "$(cat "$WORK/mstat.$m" 2>/dev/null)" in
    applied) printf '%s\n' "$WORK/mw-$m" >> "$WORK/built.want"; MUT_OK="$MUT_OK $m" ;;
    noapply) BUILT_N=$((BUILT_N-1)); verdict "$m"
             bad "MUTANT $m DID NOT APPLY -- its anchor is not on exactly one line of apply.sh, so it proves nothing. Re-anchor it." ;;
    *)       broken "the build job for mutant $m left no status; it was lost or never started" ;;
  esac
done
breap
echo "$NAME: $BUILT_OK worlds built (the control's and $((BUILT_OK-1)) mutants') before any drive"

# --- drives: every mutant once, then the three re-runs, each after its first run was reaped ------
launch ctl-clean "$CTL" "$WORK/ctl-clean"
for m in $MUT_OK; do launch "m-$m" "$WORK/m-$m" "$WORK/mw-$m"; done
wait; njobs=0
case " $MUT_OK " in *" idemMode "*) chmod -x "$WORK/mw-idemMode/cons/.claude/$DV"; launch m-idemMode2 "$WORK/m-idemMode" "$WORK/mw-idemMode" ;; esac
case " $MUT_OK " in *" finNote "*) launch m-finNote2 "$WORK/m-finNote" "$WORK/mw-finNote" "" --finish ;; esac
case " $MUT_OK " in *" noIdem "*) launch m-noIdem2 "$WORK/m-noIdem" "$WORK/mw-noIdem" ;; esac
wait; njobs=0

# === S2: the control is the shipped program, judged before any mutant ==========================
# Positive conjunct: the control must PRINT the resolved row, so a copy that ran and printed nothing
# cannot read as a working control.
ran ctl-clean || { sed 's/^/        /' "$WORK/out/ctl-clean.err" | head -8; broken "drive ctl-clean exited $(cat "$WORK/out/ctl-clean.rc" 2>/dev/null) or printed nothing"; }
if has_resolved ctl-clean "$DV"; then
  ok "S2 an unmutated copy in a fresh directory resolves the clean world -- a mutant's fallback is its mutation, not the copy"
else
  bad "S2 the unmutated control copy did not resolve the clean world; every mutant verdict below is unreadable"
fi

# === mutants ====================================================================================
# Every verdict is PRESENCE-shaped: a kill needs the mutant to have run (rc 0, rows printed) AND to
# have produced the wrong observable its arm reads.
mres() { # <mutant> -> the world dir
  printf '%s' "$WORK/mw-$1"
}
kill_if() { # <mutant> <arm> <claim> <test...>
  local m="$1" a="$2" c="$3"; shift 3
  verdict "$m"
  if ! ran "m-$m"; then bad "MUTANT $m did not run (rc $(cat "$WORK/out/m-$m.rc" 2>/dev/null)) -- a dead copy cannot score a kill"; return; fi
  if "$@"; then N_KILL=$((N_KILL+1)); ok "MUTANT $m killed by $a: $c"; else bad "MUTANT $m SURVIVED $a: $c"; fi
}
# Each kill names the WRONG SHAPE it reads, never only "not the right one": a copy that errored and
# fell back would also leave the file unequal to want, and must not score.
k_W1() { local w; w="$(mres W1)"; expect_dv "$w" && has_resolved m-W1 "$DV" && ! cmp -s "$w/want" "$w/cons/.claude/$DV" \
           && grep -qxF '{deploy_command}' "$w/cons/.claude/$DV"; }
k_W2() { local w; w="$(mres W2)"; expect_dv "$w" && has_resolved m-W2 "$DV" && ! cmp -s "$w/want" "$w/cons/.claude/$DV" \
           && grep -qF '<!-- scripts/ecs-deploy.sh prod:' "$w/cons/.claude/$DV"; }
k_mode()        { local w; w="$(mres mode)"; expect_dv "$w" && has_resolved m-mode "$DV" && cmp -s "$w/want" "$w/cons/.claude/$DV" && [ "$(xbit "$w/cons/.claude/$DV")" = - ]; }
k_resolved()    { has_resolved "m-$1" "$2"; }
k_treeA()       { ! has_resolved m-treeA "$DV" && has_today m-treeA "$DV"; }
k_noIdem()      { ran m-noIdem2 && has_resolved m-noIdem "$DV" && ! has_resolved m-noIdem2 "$DV" && has_today m-noIdem2 "$DV"; }
k_today()       { has_today "m-$1" "$DV" && ! has_resolved "m-$1" "$DV"; }
k_dropFar()     { has_resolved "m-$1" "$QA" && grep -qxF 'tests/e2e/' "$WORK/mw-$1/cons/.claude/$QA" \
                    && ! grep -qxF 'QA also owns the e2e harness.' "$WORK/mw-$1/cons/.claude/$QA"; }
k_idemMode()    { ran m-idemMode2 && has_resolved m-idemMode2 "$DV" && [ "$(xbit "$WORK/mw-idemMode/cons/.claude/$DV")" = - ]; }
# The leak is seeded on B1, a fallback past (b): on a resolving world the write reuses the same
# `.incoming.$$` name and its `mv` consumes the leaked copy, so only a fallback can show it.
k_leak()        { has_today m-leak "$DV" && [ -n "$(find "$WORK/mw-leak/cons" -name '*.incoming.*' 2>/dev/null)" ]; }
k_writeRestore() { local w="$WORK/mw-writeRestore"; has_today m-writeRestore "$DV" && cmp -s "$w/pre.deploy-validate.md" "$w/cons/.claude/$DV" \
                    && [ "$(ino "$w/cons/.claude/$DV")" = "$(cat "$w/ino.deploy-validate.md")" ] && ! untouched "$w" "$DV"; }
k_finNote()     { ran m-finNote2 && has_today m-finNote "$IM" && [ -z "$(fin_note m-finNote2 "$IM")" ]; }
for m in $MUT_OK; do
  case "$m" in
    W1)  kill_if W1 C2 "re-bucketing as overwrite_from_theirs lands theirs' {token} lines over the consumer's values" k_W1 ;;
    W2)  kill_if W2 C2 "substituting token text rewrites theirs' <!-- {deploy_command}: ... --> comment" k_W2 ;;
    W3)  kill_if W3 B2t "keying on CORE-TEMPLATE-SUBSTITUTED resolves a file whose consumer delta is outside its spans" k_resolved W3 "$DV" ;;
    W4)  kill_if W4 B1 "skipping (c) resolves over a lost after_line anchor" k_resolved W4 "$DV" ;;
    noD) kill_if noD D2 "without (d) theirs' new live {deploy_command} line lands unfilled and resolves" k_resolved noD "$DV" ;;
    noIdem) kill_if noIdem D1 "without the already-merged check the second run falls back on its own write" k_noIdem ;;
    treeA) kill_if treeA D6a "a tree-wide (a) hands back the clean target because ANOTHER file drifted" k_treeA ;;
    mode) kill_if mode C3 "without sync_mode_from_theirs the merged file keeps the consumer's 0644" k_mode ;;
    spanId) kill_if spanId SpF "the second acceptance without span identity resolves spanFar with no write, dropping theirs' line" k_dropFar spanId ;;
    spanIdQ) kill_if spanIdQ SpQ "the second acceptance without span identity resolves spanQ, leaving theirs' reworded block comment unmerged" k_resolved spanIdQ "$QA" ;;
    ssdExit) kill_if ssdExit B1b "reading a non-zero setup-site-drift.sh exit as a pass resolves over an unlocatable site" k_resolved ssdExit "$DV" ;;
    noD7) kill_if noD7 D7 "without the retired-token gate a pending re-point obligation is resolved away" k_resolved noD7 "$DV" ;;
    bareShort) kill_if bareShort SpD "the bare already-merged shortcut (outside-span OK alone) resolves theirs' --wait away unmerged" k_resolved bareShort "$DV" ;;
    rcOnly) kill_if rcOnly SpF "a shortcut trusting merge-file's exit without comparing its output resolves spanFar and drops theirs' line" k_dropFar rcOnly ;;
    dDol) kill_if dDol D+dol "(d) without the \$ exclusion hands back \${LOGDIR}" k_today dDol ;;
    dML)  kill_if dML D+ml "(d) resetting comment state per line reads a multi-line comment's token as live" k_today dML ;;
    dCom) kill_if dCom D+com "(d) treating comment text as live hands back a comment-only reword" k_today dCom ;;
    idemMode) kill_if idemMode M2 "a shortcut without sync_mode_from_theirs leaves the re-run file 0644" k_idemMode ;;
    leak) kill_if leak INC "a write path that leaves its .incoming temp behind" k_leak ;;
    writeRestore) kill_if writeRestore B1 "write-then-restore leaves the same bytes and inode but a newer mtime" k_writeRestore ;;
    laxC) kill_if laxC DlI "a c-hunk test reading left lines only resolves a file missing theirs' deletion beside the filled site" k_resolved laxC "$IM" ;;
    laxCa) kill_if laxCa CAd "the same lax test lets (a) pass a consumer line added beside the filled deploy site" k_resolved laxCa "$DV" ;;
    laxD) kill_if laxD QD "a d-hunk test reading its first line alone resolves a file whose consumer deleted ## Responsibilities" k_resolved laxD "$QA" ;;
    finNote) kill_if finNote FIN "--finish always dropping the NOTE loses implementation.md's unverified row" k_finNote ;;
  esac
done


# === MC: every declared mutant was judged, and the battery is not empty ========================
# Outside every loop over the list, so an emptied list reaches it.
unjudged=""
for m in $MUTS; do case "$JUDGED" in *" $m "*) ;; *) unjudged="$unjudged $m" ;; esac; done
if [ "$N_DECL" -gt 0 ] && [ "$N_VERD" -eq "$N_DECL" ] && [ -z "$unjudged" ] && [ "$N_KILL" -gt 0 ]; then
  ok "MC $N_VERD of $N_DECL declared mutants judged, $N_KILL killed"
else
  bad "MC $N_VERD verdict(s) for $N_DECL declared mutant(s), $N_KILL killed; declared but unjudged:${unjudged:- none} -- an empty or partly unjudged battery proves nothing"
fi

# === MP: MC can fire -- a copy of this battery with its MUTS line emptied must FAIL on MC alone ====
mp_probe() {
  local p="$WORK/mp" n
  mkdir -p "$p/core/fixtures/lib" "$p/core/fixtures/apply-setup-sited-merge" "$p/core/fixtures/$NAME" "$p/core/skills/ai-dlc-update" || return 1
  cp "$HERE/../lib/preamble.sh" "$p/core/fixtures/lib/" && cp "$SIB/lib.sh" "$p/core/fixtures/apply-setup-sited-merge/" \
    && cp -R "$REC" "$p/core/skills/ai-dlc-update/reconcile" || return 1
  n="$(grep -c '^MUTS="' "$HERE/run.sh")" || n=0
  [ "$n" = 1 ] || { echo "MUTS= is on $n lines of run.sh (want 1)"; return 1; }
  awk '/^MUTS="/ { print "MUTS=\"\""; next } { print }' "$HERE/run.sh" > "$p/core/fixtures/$NAME/run.sh" || return 1
  ! cmp -s "$HERE/run.sh" "$p/core/fixtures/$NAME/run.sh" || { echo "the emptied copy is byte-identical"; return 1; }
  bash "$p/core/fixtures/$NAME/run.sh" --inner > "$WORK/mp.out" 2> "$WORK/mp.err"; echo $? > "$WORK/mp.rc"
}
if [ -z "$INNER" ]; then
  mp_why="$(mp_probe)" || mp_why="${mp_why:-the probe tree could not be built}"
  mp_rc="$(cat "$WORK/mp.rc" 2>/dev/null)"
  mp_nf="$(grep -c '^  FAIL  ' "$WORK/mp.out" 2>/dev/null)" || mp_nf=0
  if [ -z "${mp_why:-}" ] && [ "$mp_rc" = 1 ] && [ "$mp_nf" = 1 ] \
     && grep -q '^  FAIL  MC 0 verdict(s) for 0 declared mutant(s)' "$WORK/mp.out" \
     && grep -q '^  ok    S2 ' "$WORK/mp.out" \
     && grep -qF "driving $WORK/mp/core/skills/ai-dlc-update/reconcile/apply.sh" "$WORK/mp.out"; then
    ok "MP a copy with MUTS emptied exits 1 with MC as its one failure, its control resolving, driving its own tree"
  else
    bad "MP the emptied copy: ${mp_why:+[$mp_why] }rc=${mp_rc:-none} failures=$mp_nf (want rc 1, one failure, MC) -- an empty battery may be passing"
    sed 's/^/        /' "$WORK/mp.out" 2>/dev/null | head -12
  fi
fi

echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: FAIL ($fails)"
exit 1
