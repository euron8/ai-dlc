#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# remediator-shard-join/run.sh -- join-remediator-shards.sh and the write ledger it reads. The
# behavioural arms only: the JX mutation battery that once proved each of them can fail
# has been retired; the predicates live in `lib.sh` beside this file. The battery mutates copies of core's own join, which a consumer
# cannot edit, so the consumer keeps every correctness arm and loses only that proof.
# The hard-coded `@` expectations go red in a consumer whose pair readers were carried at their pre-`@`
# version; read such a red as "a reader is carried", not as a merge or join regression.
#
# WHY A FIXTURE OF ITS OWN. No existing fixture owns this script. gate-remediation-deny owns the
# remediation-guard HOOK and its deny paths; check-24-adversarial-convergence owns arm H, which
# reads the ONE repair record the join writes. The join is the program between them: it proves the
# sharded remediators wrote DISJOINT file sets from rows the hook recorded, and only then writes
# the record arm H reads.
#
# THE LEDGER IS WRITTEN BY THE REAL HOOK. Every `.artifact-writes.jsonl` row below comes from
# driving `ai-dlc-gate-remediation-guard.sh` with a PreToolUse payload carrying a harness-shaped
# `agent_id` (17 hex characters, the shape the reference consumer's `.verdict-writes.jsonl`
# carries). No row is hand-written, so a change to what the hook records is a change this fixture
# sees. The one exception is AL2, which strips the three evidence keys from real rows with
# `jq del(...)` to build a pre-upgrade ledger; the re-run arms pin the hook's clock through a
# `date` shim and still let the hook write every row. The PARTS carry no agent id at all: the join keys a part on the files its `edit:` lines
# cite, never on an id a model reports about itself.
#
# SEEDS ARE REAL CONSUMER BYTES, TRIMMED. `seed.story-*.md` are the first 12 lines of three
# stories of one reference-consumer sprint (s305), and `seed.block-*.md` are three finding blocks
# of that sprint's real repair record, one per story, each ending at its `derivation:` label. The
# worlds are built AS sprint 305, so every `edit:` path is the consumer's own spelling, verbatim.
# `seed.block-epics.md` is a block of a DIFFERENT sprint's record (s310 stories pass 1, MINOR-1)
# whose `edit:` line cites ONLY `epics/epics.md` -- the shape of 101 of the 174 `edit:` lines
# in that consumer's stories repair records, and the reason `--artifact-path` is the sprint slot.
#
#
# MUTANTS. Each mutant is ONE drive of a mutated copy, scored by the cells that drive reads: its
# deciding arm and, where the drive also reads an arm one property apart, that arm as its twin (green
# under the mutant). A mutant whose drive reads one cell alone writes `twins=-`. The unmutated arm a
# mutant guards is the live run's own arm, never re-run per mutant: its pass sets the B_ flag the kill
# is gated on. The matrix is each mutant's own drive cells, printed one row per mutant by the REMEASURE
# command below, and is re-measured whenever an arm or a mutant is added or changed. Each mutant
# co-trips no other arm, measured at authoring.
# MUTANT-MATRIX HX1 decides=L4 twins=- why=the hook drive reads L4 alone, one conjunction of every key
# MUTANT-MATRIX HX2 decides=L4 twins=- why=the hook drive reads L4 alone, one conjunction of every key
# MUTANT-MATRIX U5 decides=A15 twins=A6
# MUTANT-MATRIX U3 decides=A12 twins=A6
# MUTANT-MATRIX U4 decides=A14 twins=A6
# MUTANT-MATRIX U1 decides=A8 twins=A6
# MUTANT-MATRIX U2 decides=A8 twins=A6
# MUTANT-MATRIX CP2 decides=CP1 twins=- why=--check-part is its own mode and no other arm drives it
# MUTANT-MATRIX CP3m decides=CP3 twins=CP4
# MUTANT-MATRIX CP4m decides=CP4 twins=CP3
# MUTANT-MATRIX MKPm-call decides=MKP twins=CP3
# MUTANT-MATRIX MKPm-relay decides=MKP twins=CP3
# MUTANT-MATRIX MK8m decides=MK8 twins=- why=the exit-4 drive is read by MK8 alone; its exit-2 control half is asserted in the same predicate
# MUTANT-MATRIX DX1 decides=D5 twins=D6
# MUTANT-MATRIX EC40m decides=EC40 twins=- why=the --mark derivation is read by EC40 alone
# MUTANT-MATRIX EC40m2 decides=EC40 twins=- why=the --mark derivation is read by EC40 alone
# MUTANT-MATRIX EC41m-drop decides=EC41.a twins=- why=p_replay is run on that one case alone (R_ONLY), so one cell is read
# MUTANT-MATRIX EC41m-forge decides=EC41.b twins=- why=p_replay is run on that one case alone (R_ONLY), so one cell is read
# MUTANT-MATRIX EC42m-attr decides=EC42.b twins=- why=p_claim is run on that one case alone (R_ONLY), so one cell is read
# MUTANT-MATRIX EC42m-invert decides=EC42.c twins=- why=p_claim is run on that one case alone (R_ONLY), so one cell is read
# MUTANT-MATRIX EC42m-late decides=EC42.c twins=- why=p_claim is run on that one case alone (R_ONLY), so one cell is read
# MUTANT-MATRIX EC42m-early decides=EC42.d twins=- why=p_claim is run on that one case alone (R_ONLY), so one cell is read
# MUTANT-MATRIX EC43m-summary decides=EC43.crash-serial twins=- why=p_vcrash is run on that one case alone (R_ONLY), so one cell is read
# MUTANT-MATRIX EC43m-reword decides=EC43.ctl-stale twins=- why=p_vcrash is run on that one case alone (R_ONLY), so one cell is read
# MUTANT-MATRIX EC39m decides=EC39a twins=- why=the record-mode BADSIB classification is read by EC39a alone
# MUTANT-MATRIX LN3m decides=LN3 twins=- why=the lane partition drive reads LN3 alone
# MUTANT-MATRIX LN6m decides=LN6 twins=- why=the lane-record drive reads LN6 alone
# MUTANT-MATRIX LN10m decides=LN10 twins=- why=the four-item fan-in drive reads LN10 alone
# MUTANT-MATRIX LN13m decides=LN13 twins=- why=the unedited-story escalation drive reads LN13 alone
# MUTANT-MATRIX LN15m decides=LN15 twins=- why=the adjudicator-wrote lane-round drive reads LN15 alone
# MUTANT-MATRIX LPm1 decides=LP1 twins=LP3
# MUTANT-MATRIX LPm4 decides=LP4 twins=LP3,LP1
# MUTANT-MATRIX NLma decides=NL3 twins=NL1
# MUTANT-MATRIX NLmb decides=NL4 twins=NL1
# MUTANT-MATRIX NLmc decides=NL3 twins=NL1
# MUTANT-MATRIX NLme decides=NL7 twins=NL1
# MUTANT-MATRIX NLmd decides=NL5 twins=NL1
# MUTANT-MATRIX NLmf decides=NL8 twins=NL1
# MUTANT-MATRIX NLmg decides=NL8 twins=NL1
# MUTANT-MATRIX NLmh decides=NL8c twins=NL1
# MUTANT-MATRIX DKm decides=DK1 twins=DK2
# MUTANT-MATRIX UFm decides=UF1 twins=UF1.now
# MUTANT-MATRIX PCm1417 decides=PC1417 twins=- why=PC1756 and PC2768 share its broken copy in other modes and still fire under it, measured once in --matrix
# MUTANT-MATRIX PCm1423 decides=PC1423 twins=- why=PC2779 shares its broken copy in subject mode and still fires under it, measured once in --matrix
# MUTANT-MATRIX PCm1756 decides=PC1756 twins=- why=PC1417 and PC2768 share its broken copy in other modes and still fire under it, measured once in --matrix
# MUTANT-MATRIX PCm1773 decides=PC1773 twins=- why=PC2755 shares its broken copy in party mode and still fires under it, measured once in --matrix
# MUTANT-MATRIX PCm2755 decides=PC2755 twins=- why=PC1773 shares its broken copy in --sources mode and still fires under it, measured once in --matrix
# MUTANT-MATRIX PCm2768 decides=PC2768 twins=- why=PC1417 and PC1756 share its broken copy in record modes and still fire under it, measured once in --matrix
# MUTANT-MATRIX PCm2779 decides=PC2779 twins=- why=PC1423 shares its broken copy in --escalations mode and still fires under it, measured once in --matrix
# MUTANT-MATRIX SRm1 decides=SR1 twins=SR2
# MUTANT-MATRIX SRm4 decides=SR4 twins=SR1
# MUTANT-MATRIX SRm5 decides=SR6 twins=SR2
# MUTANT-MATRIX SRm6 decides=SR7 twins=SR2
# MUTANT-MATRIX SRm7 decides=SR8 twins=SR4
# MUTANT-MATRIX SRm8 decides=SR8 twins=SR8b
# MUTANT-MATRIX SRm9 decides=SR10 twins=SR4
# MUTANT-MATRIX SRm10 decides=SR9 twins=SR4
# MUTANT-MATRIX SRm11 decides=SR11 twins=SR4
# MUTANT-MATRIX SRm12 decides=SR12 twins=SR1
# MUTANT-MATRIX SRm13 decides=SR13 twins=SR4
# MUTANT-MATRIX SRm14 decides=SR14 twins=SR4
# MUTANT-MATRIX SRm15 decides=SR16 twins=SR4
# MUTANT-MATRIX SRmF1 decides=SRC1 twins=SRC3
# MUTANT-MATRIX SRmF2 decides=SRC5b twins=SRC5
# MUTANT-MATRIX SRmF3 decides=SRC6 twins=SRC3
# MUTANT-MATRIX SRmF4 decides=SRC7 twins=SRC3
# MUTANT-MATRIX SRmF5 decides=SRC8 twins=SRC6
# MUTANT-MATRIX SRmF6 decides=SRC9 twins=SRC3
# MUTANT-MATRIX SRmF7 decides=SRC11 twins=SRC6
# MUTANT-MATRIX SRmF8 decides=SRC6 twins=SRC10
# MUTANT-MATRIX SRm3 decides=SRT1 twins=- why=the token-on-one-line arm is read by SRT1 alone; the control is the unmutated real file
# MUTANT-MATRIX SRm2 decides=SR3 twins=- why=the boundary is read by the SR3 world alone; SR1 and SR2 install the sentence
# MUTANT-MATRIX BINDm-strip decides=BIND1 twins=BIND2,BIND3
# MUTANT-MATRIX BINDm-prefix decides=BIND1 twins=BIND2,BIND3
# MUTANT-MATRIX BINDm-same decides=BIND1 twins=BIND2,BIND3
# MUTANT-MATRIX BINDm-dw decides=BIND2 twins=BIND1,BIND3
# MUTANT-MATRIX BINDm-dwdel decides=BIND2 twins=BIND1,BIND3
# MUTANT-MATRIX BINDm-third decides=BIND3 twins=BIND1,BIND2
# MUTANT-MATRIX DWm-false decides=RR4,RR5 twins=RR16
# MUTANT-MATRIX DWm-true decides=RR16 twins=RR4
# MUTANT-MATRIX DWm-alias decides=RR18 twins=RR4
# MUTANT-MATRIX DWm-onefile decides=RR19 twins=RR4
# MUTANT-MATRIX DWm-once decides=RR20 twins=RR4
# MUTANT-MATRIX-DYNAMIC pc-score why=pc_score passes PCm<site> to mutant_killed
# MUTANT-MATRIX-DYNAMIC hx-loop why=the HX loop passes its list id _id to mutant_killed
# MUTANT-MATRIX-DYNAMIC u34-loop why=the U3/U4 loop passes its list id _id to mutant_killed
# MUTANT-MATRIX-DYNAMIC u12-loop why=the U1/U2 loop passes its list id _id to mutant_killed
# MUTANT-MATRIX-DYNAMIC ec41-loop why=the EC41m loop passes EC41m-<mode> to mutant_killed
# MUTANT-MATRIX-DYNAMIC ec42-loop why=the EC42m loop passes EC42m-<mode> to mutant_killed
# MUTANT-MATRIX-DYNAMIC ec43-loop why=the EC43m loop passes EC43m-<mode> to mutant_killed
# MUTANT-MATRIX-DYNAMIC mkp-loop why=the MKPm loop passes MKPm-<mode> to mutant_killed
# MUTANT-MATRIX-DYNAMIC nl-score why=nl_score passes NLm<tag> to mutant_killed
# MUTANT-MATRIX-REMEASURE bash core/fixtures/remediator-shard-join/run.sh --matrix
#
# lib.sh sets the shell options, scrubs AI_DLC_*, owns WORK and its one EXIT trap.
NAME="remediator-shard-join"
MATRIX=0
[ "${1:-}" = --matrix ] && MATRIX=1
[ -f "$(cd "$(dirname "$0")" && pwd)/lib.sh" ] || { echo "FIXTURE BROKEN: lib.sh is absent beside $0; nothing was asserted" >&2; exit 2; }
. "$(cd "$(dirname "$0")" && pwd)/lib.sh"
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
# mrow <mutant> <arm>=<0|1>... -- one uniform matrix row (1 = the arm failed under the mutant), printed
# in --matrix mode only. N_MROWS counts the rows printed, so the plain run can assert it printed none.
N_MROWS=0
mrow() { [ "$MATRIX" = 1 ] || return 0; N_MROWS=$((N_MROWS + 1)); echo "  MATRIX $*"; }

# ---------------------------------------------------------------------------------- the arms
echo "$NAME:"
if [ "$MATRIX" = 1 ]; then echo "$NAME: mode FULL (--matrix): every mutant's drive cells printed as a MATRIX row"
else echo "$NAME: mode PUSH: each mutant drives its deciding arm and its twin"; fi
echo "HERMETIC-CONSUMED core/scripts/join-remediator-shards.sh"
echo "HERMETIC-CONSUMED core/hooks/ai-dlc-gate-remediation-guard.sh"

# ---- unit-reader-b.sh: L1-L4/HX, J, D, A/U1-U5, B2/SJ0, PS5/PS6/PS9/PS12, SP1-SP11, AW1, CP1/CP2, D5/D6/DX1, H1/H2, UF1/UFm
# asked in process through the same lib.sh predicates; its SEAM-B and CLI-B cells keep one CLI pass and refusal per join
# mode it owns. End to end here: PS1 (a party join), PS7 (--sources passes), PS8 (--sources refuses). One literal call line.
bash "$HERE/unit-reader-b.sh" ${1:+"$1"}; _urb=$?
case "$_urb" in 0) ;; 1) fails=$((fails + 1)) ;; *) bad "unit-reader-b.sh exited $_urb (FIXTURE BROKEN); nothing was asserted" ;; esac


# ---- unit-parts.sh: the parts-mode and --sources ENTRY-CONTRACT cells (EC1-EC13, EC15-EC17, EC27, PS2-PS4, PS10, PS11) asked in
# process against the sourced join. One end to end run per mode stays: EC32 (parts refusal, CLI-A in unit-reader-a.sh), PS1 (parts join), PS8
# (--sources refusal), PS7 (--sources pass). One literal call line, never a loop variable.
bash "$HERE/unit-parts.sh"; _up=$?
case "$_up" in 0) ;; 1) fails=$((fails + 1)) ;; *) bad "unit-parts.sh: FIXTURE BROKEN, exit $_up" ;; esac
# ---- party repairs (BL-462). Each refusal has its ALLOW twin one property apart in the same run.
p_party "$JOIN" && ok "PS1: a party repair (--artifact stories-party), sources keyed on (seat file, id) -- F-1 in BOTH dev-1 and tea-1, and graph's \`## Finding D4-1\` form -> JOINED, the tokens carried into the record" \
  || bad "PS1: a party repair with resolving sources did not join (rc=$RC): $(cat "$JO")"
p_srcok "$JOIN" && ok "PS7: --sources on a record no join wrote -- colliding F-1 keyed by file -> rc 0, '2 entries, 3 sources'" \
  || bad "PS7: --sources refused a resolving record (rc=$RC): $(cat "$JO")"
p_srcunres "$JOIN" && ok "PS8: --sources, one property apart (F-4 under dev-1) -> rc 2, UNRESOLVED, the carrying seat named" \
  || bad "PS8: --sources accepted an id only another seat carries (rc=$RC): $(cat "$JO")"

# ---- the entry contract (BL-508, BL-519). Each refusal has its ALLOW twin one property apart.
bash "$HERE/unit-record.sh"; _ur=$?
case "$_ur" in 0) ;; 1) fails=$((fails + 1)) ;; *) bad "unit-record.sh exited $_ur (FIXTURE BROKEN); nothing was asserted" ;; esac
# ---- unit-reader.sh: SEAM-JOIN and SEAM-HOOK, the in-process (join_main, hook_pretool_head) answers pinned byte-identical to the CLI's.
bash "$HERE/unit-reader.sh"; _urd=$?
case "$_urd" in 0) ;; 1) fails=$((fails + 1)) ;; *) bad "unit-reader.sh exited $_urd (FIXTURE BROKEN); nothing was asserted" ;; esac
# ---- unit-bind.sh: BIND0-BIND3, the join's SAME and DOUBLE-WRITE refusal text bound to the merge's, self-probed first.
bash "$HERE/unit-bind.sh" ${1:+"$1"}; _ubd=$?
case "$_ubd" in 0) ;; 1) fails=$((fails + 1)) ;; *) bad "unit-bind.sh exited $_ubd (FIXTURE BROKEN); nothing was asserted" ;; esac



# R1: the role file the remediator is bound to teaches the write tool and the citation form. Walked
# up from this fixture in both layouts; install copies team-roles/ verbatim, so no render exists.
ROLE=""
_d="$HERE"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _c in "$_d/core/team-roles/remediator.md" "$_d/.claude/team-roles/remediator.md"; do
    [ -f "$_c" ] && { ROLE="$_c"; break 2; }
  done
  _d="$(dirname "$_d")"
done
if [ -z "$ROLE" ]; then
  bad "R1: FIXTURE BROKEN -- remediator.md not found above $HERE in either layout"
else
  role_flat="$(tr '\n' ' ' < "$ROLE" | tr -s ' ')"
  n_rel="$(grep -o "the project-relative path in the ledger's spelling" <<<"$role_flat" | grep -c .)" || n_rel=0
  n_full="$(grep -c 'FULL path' "$ROLE")" || n_full=0
  if grep -qF "every edit to a file under the sprint slot goes through Edit, Write or MultiEdit, never a Bash redirect" <<<"$role_flat" \
     && [ "$n_rel" -eq 2 ] && [ "$n_full" -eq 0 ]; then
    ok "R1: $ROLE teaches Edit/Write/MultiEdit for slot edits and the ledger-spelled citation at both sites (2), with no FULL path left"
  else
    bad "R1: $ROLE -- Edit/Write/MultiEdit sentence absent, or ledger-spelled citations=$n_rel (want 2), FULL path=$n_full (want 0)"
  fi
fi


# ---- unit-mark.sh: MK0, the in-process --mark seam pinned to the CLI. EC37 and EC40-EC43 below drive the same seam.
bash "$HERE/unit-mark.sh"; _um=$?
case "$_um" in 0) ;; 1) fails=$((fails + 1)) ;; *) bad "unit-mark.sh exited $_um (FIXTURE BROKEN); nothing was asserted" ;; esac
if p_markderive "$SRCDIR/wait-for-deliverable.sh"; then ok "EC40: --mark on a remediator part derives the words from the path -- coe-repair-p1/2.md written coe remediator 2, the shifted call coe 7 remediator 7 written coe remediator 7, requirements-party-repair/05.md called with wrong words written requirements-party remediator 05 and 03.md keeps its correct spelling, coe-party-serial-repair-p1/lane-1.md keeps lane-1, a 1/8 brief shard becomes the file name; a plain/ file keeps the caller's words"; B_EC40=1
else bad "EC40: --mark did not derive the remediator part marker words (BL-796)"; fi
# EC40m: the derivation removed must be KILLED by EC40. The unmutated control is EC40's own live pass
# above (B_EC40), never re-run here.
EM40="$(mktemp -d "$WORK/ec40m.XXXXXX")" || exit 2
cp "$SRCDIR"/*.sh "$EM40/" || { echo "FIXTURE BROKEN: EC40m could not copy the sibling scripts into $EM40" >&2; exit 2; }
sed 's/^        if \[ -n "\$mk_rs_" \]; then MK_F=.*$/        :/' "$SRCDIR/wait-for-deliverable.sh" > "$EM40/wait-for-deliverable.sh" \
  || { echo "FIXTURE BROKEN: EC40m could not write the mutated --mark into $EM40" >&2; exit 2; }
if cmp -s "$SRCDIR/wait-for-deliverable.sh" "$EM40/wait-for-deliverable.sh"; then
  bad "EC40m: FIXTURE STALE -- the derivation-removal mutation matched nothing in $SRCDIR/wait-for-deliverable.sh; re-anchor it, never relax the assertion"
elif ! bash -n "$EM40/wait-for-deliverable.sh" 2>/dev/null; then
  bad "EC40m: the mutant is not valid shell"
elif ! p_markderive "$EM40/wait-for-deliverable.sh"; then
  mrow EC40m EC40=1
  mutant_killed "${B_EC40:-0}" EC40m "EC40m the part-marker derivation removed: KILLED by [EC40]"
else
  mrow EC40m EC40=0
  bad "EC40m: SURVIVED -- EC40 holds against a --mark that writes the caller's words on a remediator part"
fi
# EC40m2: the plain -repair branch removed must be KILLED by EC40 (its case (c) calls wrong words).
EM40B="$(mktemp -d "$WORK/ec40m2.XXXXXX")" || exit 2
cp "$SRCDIR"/*.sh "$EM40B/" || { echo "FIXTURE BROKEN: EC40m2 could not copy the sibling scripts into $EM40B" >&2; exit 2; }
sed '/^          \*-repair) mk_rs_="\${mk_dn_%-repair}" ;;$/d' "$SRCDIR/wait-for-deliverable.sh" > "$EM40B/wait-for-deliverable.sh" \
  || { echo "FIXTURE BROKEN: EC40m2 could not write the mutated --mark into $EM40B" >&2; exit 2; }
if cmp -s "$SRCDIR/wait-for-deliverable.sh" "$EM40B/wait-for-deliverable.sh"; then
  bad "EC40m2: FIXTURE STALE -- the -repair-branch deletion matched nothing in $SRCDIR/wait-for-deliverable.sh; re-anchor it, never relax the assertion"
elif ! bash -n "$EM40B/wait-for-deliverable.sh" 2>/dev/null; then
  bad "EC40m2: the mutant is not valid shell"
elif ! p_markderive "$EM40B/wait-for-deliverable.sh"; then
  mrow EC40m2 EC40=1
  mutant_killed "${B_EC40:-0}" EC40m2 "EC40m2 the plain -repair branch removed: KILLED by [EC40]"
else
  mrow EC40m2 EC40=0
  bad "EC40m2: SURVIVED -- EC40 holds against a --mark with no plain -repair branch"
fi
# EC41 (BL-804): --mark / --mark-repair replay a remediator record stating `derivations: not replayed`.
if p_replay "$SRCDIR/wait-for-deliverable.sh"; then ok "EC41: --mark replays a not replayed remediator part -- two reproducing fences under one triple written replayed 2 and sealed, a stale fence refused 64 with the file byte-identical (the deferral remedy only in a section-split dir), a deferred line, a non-repair seat and a part with no repaired entry untouched; --mark-repair on a joined record rewrites the serial block's own line to replayed 3 and leaves the shard body's line alone"; B_EC41=1
else bad "EC41: the --mark replay failed at case ${R804:-?} (BL-804)"; fi
# EC41m / EC41m2: the rewrite dropped (KILLED by case a), and a rewrite on a forged OK verdict that never
# ran the validator (KILLED by case b). Each built in a copy of the whole script dir, so the join and the
# validator sit beside the mutant. The unmutated control in a copy runs ONCE for the family, in the first
# copy: every copy is the same `cp "$SRCDIR"/*.sh`, so a second control would read the same bytes.
# TMPDIR points into $WORK for these runs: the `drop` mutant never removes the wfd-mark.* snapshot it took,
# and under the host's TMPDIR that file outlived the fixture. Restored after the loop.
_ec41_tmp="${TMPDIR-}"; _ec41_set="${TMPDIR+1}"; export TMPDIR="$WORK"
for _m in drop forge; do
  EM41="$(mktemp -d "$WORK/ec41m.XXXXXX")" || exit 2
  cp "$SRCDIR"/*.sh "$EM41/" || { echo "FIXTURE BROKEN: EC41m could not copy the sibling scripts into $EM41" >&2; exit 2; }
  case "$_m" in
    drop) _want=a; awk '$0 != "          MK_SRC=\"$MK_RW\""' "$SRCDIR/wait-for-deliverable.sh" > "$EM41/wfd.mut" ;;
    forge) _want=b; awk -v k='bash "$MK_VAL" "$MK_SRC" > "$MK_VO" 2> "$MK_VE"; mk_vrc_=$?' '{ i = index($0, k)
        if (i && substr($0, i + length(k)) == "") $0 = substr($0, 1, i - 1) "echo \"OK: 2 derivation(s) in 1 block(s) across 1 file(s) reproduce at HEAD.\" > \"$MK_VO\"; mk_vrc_=0"
        print }' "$SRCDIR/wait-for-deliverable.sh" \
        | awk -v k='vad_invoke "$MK_SRC" ) > "$MK_VO" 2> "$MK_VE"; mk_vrc_=$?' '{ i = index($0, k)
        if (i && substr($0, i + length(k)) == "") $0 = substr($0, 1, i - 1) "true ) ; echo \"OK: 2 derivation(s) in 1 block(s) across 1 file(s) reproduce at HEAD.\" > \"$MK_VO\"; mk_vrc_=0"
        print }' > "$EM41/wfd.mut" ;;
  esac || { echo "FIXTURE BROKEN: EC41m ($_m) could not write the mutant" >&2; exit 2; }
  if cmp -s "$SRCDIR/wait-for-deliverable.sh" "$EM41/wfd.mut"; then
    bad "EC41m ($_m): FIXTURE STALE -- the mutation matched nothing in $SRCDIR/wait-for-deliverable.sh; re-anchor it, never relax the assertion"
  elif ! bash -n "$EM41/wfd.mut" 2>/dev/null; then
    bad "EC41m ($_m): the mutant is not valid shell"
  elif [ "${B_EC41c:-0}" != 1 ] && ! p_replay "$EM41/wait-for-deliverable.sh"; then
    bad "EC41m ($_m): the unmutated control in the copy did not pass (case ${R804:-?})"
  else
    if [ "${B_EC41c:-0}" != 1 ]; then ok "EC41 copy control: the unmutated scripts in a copy of the dir pass EC41"; B_EC41c=1; fi
    mv -f "$EM41/wfd.mut" "$EM41/wait-for-deliverable.sh"
    if R_ONLY="$_want" p_replay "$EM41/wait-for-deliverable.sh"; then
      mrow "EC41m-$_m" "EC41.$_want=0"
      bad "EC41m ($_m): SURVIVED -- EC41 holds against it"
    elif [ "$R804" = "$_want" ]; then
      mrow "EC41m-$_m" "EC41.$_want=1"
      mutant_killed "$(( ${B_EC41:-0} && ${B_EC41c:-0} ))" "EC41m-$_m" "EC41m ($_m): KILLED by [EC41 case $_want]"
    else
      mrow "EC41m-$_m" "EC41.$_want=0" "EC41.$R804=1"
      bad "EC41m ($_m): failed at case $R804, not its own case $_want"
    fi
  fi
done
if [ -n "$_ec41_set" ]; then export TMPDIR="$_ec41_tmp"; else unset TMPDIR; fi
# EC42 (BL-816): --mark checks a claimed `replayed <n>` and refuses only on a stale fence inside the block it seals.
if p_claim "$SRCDIR/wait-for-deliverable.sh"; then ok "EC42: --mark checks a claimed replay -- a clean joined record and a part claiming replayed 7 over 2 reproducing fences marked, sealed and never rewritten; a stale fence on the FIRST and on the LAST fence line of the serial block, and in a part, refused 64 with the file byte-identical; a stale fence in the SHARD segment above it left to the join, the serial block marked"; B_EC42=1
else bad "EC42: the claimed-replay check failed at case ${R816:-?} (BL-816)"; fi
# EC42m: attribution dropped (any FAIL refuses; KILLED by case b), attribution inverted (KILLED by c), the
# range opened one chunk late (KILLED by c) and closed one chunk early (KILLED by d). Each built in a copy of
# the whole script dir, the unmutated control in a copy passing ONCE for the family first. The line-level `<` for `<=` at
# either bound is an EQUIVALENT mutant and is not committed: a bound is a chunk edge (a triple, a shard
# marker, a terminator), and checks_field skips fence lines, so no `$ ` line can sit on one.
for _m in attr invert late early; do
  EM42="$(mktemp -d "$WORK/ec42m.XXXXXX")" || exit 2
  cp "$SRCDIR"/*.sh "$EM42/" || { echo "FIXTURE BROKEN: EC42m could not copy the sibling scripts into $EM42" >&2; exit 2; }
  _k='ln = substr(r, 1, RLENGTH) + 0; if (ln >= lo + 0 && ln <= hi + 0) print }'
  _j='if (sy && nrl == 1 && own) print "RPL\t" cl[lo] "\t" (hi < nk ? cl[hi + 1] - 1 : FNR)'
  case "$_m" in
    attr) _want=b; _t=wait-for-deliverable.sh; _r='ln = substr(r, 1, RLENGTH) + 0; print }' ;;
    invert) _want=c; _t=wait-for-deliverable.sh; _r='ln = substr(r, 1, RLENGTH) + 0; if (!(ln >= lo + 0 && ln <= hi + 0)) print }' ;;
    late) _want=c; _t=join-remediator-shards.sh; _k="$_j"; _r='if (sy && nrl == 1 && own) print "RPL\t" cl[lo + 1] "\t" (hi < nk ? cl[hi + 1] - 1 : FNR)' ;;
    early) _want=d; _t=join-remediator-shards.sh; _k="$_j"; _r='if (sy && nrl == 1 && own) print "RPL\t" cl[lo] "\t" (cl[hi] - 1)' ;;
  esac
  # The anchors reach awk through ENVIRON, which keeps their `\t` as two characters (awk -v would not).
  K42="$_k" R42="$_r" awk 'BEGIN { k = ENVIRON["K42"]; r = ENVIRON["R42"] } { i = index($0, k); if (i) $0 = substr($0, 1, i - 1) r substr($0, i + length(k)); print }' \
    "$SRCDIR/$_t" > "$EM42/mut" || { echo "FIXTURE BROKEN: EC42m ($_m) could not write the mutant" >&2; exit 2; }
  if cmp -s "$SRCDIR/$_t" "$EM42/mut"; then
    bad "EC42m ($_m): FIXTURE STALE -- the mutation matched nothing in $SRCDIR/$_t; re-anchor it, never relax the assertion"
  elif ! bash -n "$EM42/mut" 2>/dev/null; then
    bad "EC42m ($_m): the mutant is not valid shell"
  elif [ "${B_EC42c:-0}" != 1 ] && ! p_claim "$EM42/wait-for-deliverable.sh"; then
    bad "EC42m ($_m): the unmutated control in the copy did not pass (case ${R816:-?})"
  else
    if [ "${B_EC42c:-0}" != 1 ]; then ok "EC42 copy control: the unmutated scripts in a copy of the dir pass EC42"; B_EC42c=1; fi
    mv -f "$EM42/mut" "$EM42/$_t"
    if R_ONLY="$_want" p_claim "$EM42/wait-for-deliverable.sh"; then
      mrow "EC42m-$_m" "EC42.$_want=0"
      bad "EC42m ($_m): SURVIVED -- EC42 holds against it"
    elif [ "$R816" = "$_want" ]; then
      mrow "EC42m-$_m" "EC42.$_want=1"
      mutant_killed "$(( ${B_EC42:-0} && ${B_EC42c:-0} ))" "EC42m-$_m" "EC42m ($_m): KILLED by [EC42 case $_want]"
    else
      mrow "EC42m-$_m" "EC42.$_want=0" "EC42.$R816=1"
      bad "EC42m ($_m): failed at case $R816, not its own case $_want"
    fi
  fi
done
# EC43 (BL-816, B1): a validator exit 1 with no `FAIL: <n> stale or unrunnable` summary is a crash, never a FAIL set
# that misses the block being sealed. Predicate p_vcrash in lib.sh.
if p_vcrash "$SRCDIR"; then ok "EC43: a validator that dies under set -u (exit 1, no FAIL line) -> --mark-repair over a stale replayed 2 block and --mark over a clean not-replayed part each refused 64 as no verdict, the file byte-identical; the real validator marks a clean record and refuses a stale fence as stale"; B_EC43=1
else bad "EC43: the crashed-validator refusal failed at case ${RVC:-?} (BL-816)"; fi
# EC43m: (summary) the summary-line requirement reverted in --mark, KILLED by crash-serial; (reword) the validator's
# summary reworded at its emission site, KILLED by ctl-stale, and the reworded run must still refuse that stale
# fence 64 as no verdict with the file byte-identical (fail closed, never sealed). Each in a copy of the whole dir.
for _m in summary reword; do
  EM43="$(mktemp -d "$WORK/ec43m.XXXXXX")" || exit 2
  cp "$SRCDIR"/*.sh "$EM43/" || { echo "FIXTURE BROKEN: EC43m could not copy the sibling scripts into $EM43" >&2; exit 2; }
  case "$_m" in
    summary) _want=crash-serial; _t=wait-for-deliverable.sh; _k="[ \"\$mk_vrc_\" -eq 1 ] && grep -q '^FAIL: [0-9][0-9]* stale or unrunnable derivation' \"\$MK_VE\" && mk_vs_=1"; _r="[ \"\$mk_vrc_\" -eq 1 ] && mk_vs_=1" ;;
    reword) _want=ctl-stale; _t=validate-artifact-derivations.sh; _k="printf 'FAIL: %s stale or unrunnable derivation(s) of"; _r="printf 'FAIL: %s derivation(s) stale or unrunnable of" ;;
  esac
  K43="$_k" R43="$_r" awk 'BEGIN { k = ENVIRON["K43"]; r = ENVIRON["R43"] } { i = index($0, k); if (i) $0 = substr($0, 1, i - 1) r substr($0, i + length(k)); print }' \
    "$SRCDIR/$_t" > "$EM43/mut" || { echo "FIXTURE BROKEN: EC43m ($_m) could not write the mutant" >&2; exit 2; }
  if cmp -s "$SRCDIR/$_t" "$EM43/mut"; then
    bad "EC43m ($_m): FIXTURE STALE -- the mutation matched nothing in $SRCDIR/$_t; re-anchor it, never relax the assertion"
  elif ! bash -n "$EM43/mut" 2>/dev/null; then
    bad "EC43m ($_m): the mutant is not valid shell"
  elif [ "${B_EC43c:-0}" != 1 ] && ! p_vcrash "$EM43"; then
    bad "EC43m ($_m): the unmutated control in the copy did not pass (case ${RVC:-?})"
  else
    if [ "${B_EC43c:-0}" != 1 ]; then ok "EC43 copy control: the unmutated scripts in a copy of the dir pass EC43"; B_EC43c=1; fi
    mv -f "$EM43/mut" "$EM43/$_t"
    if R_ONLY="$_want" p_vcrash "$EM43"; then
      mrow "EC43m-$_m" "EC43.$_want=0"
      bad "EC43m ($_m): SURVIVED -- EC43 holds against it"
    elif [ "$RVC" != "$_want" ]; then
      mrow "EC43m-$_m" "EC43.$_want=0" "EC43.$RVC=1"
      bad "EC43m ($_m): failed at case $RVC, not its own case $_want"
    elif [ "$_m" = reword ] && ! { _f="$RVC_W/_bmad-output/planning-artifacts/s9/c-repair-p1.md"; cmp -s "$_f" "$_f.before" && has "$_f.out" 'gave no verdict (exit 1)'; }; then
      mrow "EC43m-$_m" "EC43.$_want=1"
      bad "EC43m (reword): dead at its case, but the reworded summary did not fail closed -- the stale fence was not refused as no verdict with the file byte-identical"
    else
      mrow "EC43m-$_m" "EC43.$_want=1"
      mutant_killed "$(( ${B_EC43:-0} && ${B_EC43c:-0} ))" "EC43m-$_m" "EC43m ($_m): KILLED by [EC43 case $_want]"
    fi
  fi
done

# EC39 (BL-734): a closing entry appended to a joined record -- the BADSIB refusal line, its two accepted
# near-misses, then the writer paragraphs of both role files, then the mutant that scores the first.
RP="$(dirname "${ROLE:-/nonexistent/x}")/pm-escalated.md"
if [ -z "${ROLE:-}" ] || [ ! -f "$RP" ]; then
  bad "EC39: FIXTURE BROKEN -- remediator.md or pm-escalated.md not found beside the role directory"
else
  if p_bl734 "$JOIN"; then ok "EC39a: --escalations over a joined record with an appended closing entry -- 'siblings: checked' is REFUSED with the BADSIB line itself, rc 2; the field then a blank line then a fence, and a fence directly under it, both rc 0"; B_EC39a=1
  else bad "EC39a: the appended closing entry's siblings: shapes were not judged as specified (rc=$RC): $(cat "$JO")"; fi
  p_bl734prose "$ROLE" "$RP" && ok "EC39b: each role file's writer paragraph carries join-remediator-shards.sh --escalations with --sprint, remediator.md before --mark-repair and after the SPEC re-render, and the 'no procedure runs' negation is gone" \
    || bad "EC39b: a writer paragraph lacks the --escalations instruction (with --sprint), it precedes --mark-repair, or the old negation remains"
  # self-probe of the prose arm, both directions, on copies: removed, moved to an unrelated section, placed AFTER the mark, negated
  PD="$(mktemp -d "$WORK/ec39.XXXXXX")" || exit 2
  sed 's/join-remediator-shards.sh --escalations <record> --sprint/join-remediator-shards.sh --sources <record> --sprint/' "$RP" > "$PD/pm.removed.md"
  perl -0pe 's/run\n`scripts\/ai-dlc\/join-remediator-shards/never run `scripts\/ai-dlc\/join-remediator-shards/' "$RP" > "$PD/pm.negated.md"
  { sed 's/join-remediator-shards.sh --escalations <record> --sprint/join-remediator-shards.sh --sources <record> --sprint/' "$ROLE"; printf '\n## Unrelated\n\nbefore `--mark-repair`, run `scripts/ai-dlc/join-remediator-shards.sh --escalations <record> --sprint <N>`\n'; } > "$PD/rem.moved.md"
  perl -0pe 's/before `--mark-repair`, run\n/after `--mark-repair`, run\n/' "$ROLE" > "$PD/rem.after.md"
  perl -0pe 's/before `--mark-repair`, run\n/before `--mark-repair`, never run\n/' "$ROLE" > "$PD/rem.negated.md"
  if cmp -s "$RP" "$PD/pm.removed.md" || cmp -s "$RP" "$PD/pm.negated.md" || cmp -s "$ROLE" "$PD/rem.moved.md" || cmp -s "$ROLE" "$PD/rem.after.md" || cmp -s "$ROLE" "$PD/rem.negated.md"; then
    bad "EC39c: FIXTURE STALE -- a prose self-probe copy equals the real file; re-anchor it, never relax the assertion"
  else
    c1=ok; p_bl734prose "$ROLE" "$PD/pm.removed.md" && c1=alive
    c2=ok; p_bl734prose "$PD/rem.moved.md" "$RP" && c2=alive
    c3=ok; p_bl734prose "$PD/rem.after.md" "$RP" && c3=alive
    c4=ok; p_bl734prose "$PD/rem.negated.md" "$RP" && c4=alive
    c5=ok; p_bl734prose "$ROLE" "$PD/pm.negated.md" && c5=alive
    if [ "$c1" = ok ] && [ "$c2" = ok ] && [ "$c3" = ok ] && [ "$c4" = ok ] && [ "$c5" = ok ]; then
      ok "EC39c: the prose arm FAILS for the instruction removed from pm-escalated.md, moved to an unrelated section, placed after --mark-repair, and negated in either file"
    else
      bad "EC39c: the prose arm passed a broken role file (removed=$c1 moved=$c2 after=$c3 negated-rem=$c4 negated-pm=$c5)"
    fi
  fi
  # EC39m: the record-mode call filters ^BADSIB out of contract_check 1 -> EC39a must die. Line 1172 stays (EC15/CP1 share it).
  EM="$(mktemp -d "$WORK/ec39m.XXXXXX")" || exit 2
  cp "$(dirname "$JOIN")"/*.sh "$EM/" \
    || { echo "FIXTURE BROKEN: EC39m could not copy the join's sibling scripts into $EM" >&2; exit 2; }
  sed 's/^  contract_refusals 1 "\$(contract_check 1 "\$@")"$/  contract_refusals 1 "$(contract_check 1 "$@" | grep -v "^BADSIB")"/' "$JOIN" > "$EM/join-remediator-shards.sh" \
    || { echo "FIXTURE BROKEN: EC39m could not write the mutated join into $EM" >&2; exit 2; }
  if cmp -s "$JOIN" "$EM/join-remediator-shards.sh"; then
    bad "EC39m: FIXTURE STALE -- the record-mode mutation matched nothing in $JOIN; re-anchor it, never relax the assertion"
  elif [ ! -f "$EM/validate-adversarial-convergence.sh" ]; then
    bad "EC39m: the sibling set is absent in the copy"
  elif ! p_bl734 "$EM/join-remediator-shards.sh"; then
    mrow EC39m EC39a=1
    mutant_killed "${B_EC39a:-0}" EC39m "EC39m the record-mode BADSIB classification skipped: KILLED by [EC39a]"
  else
    mrow EC39m EC39a=0
    bad "EC39m: SURVIVED -- EC39a holds against a record-mode call that never classifies siblings"
  fi
fi

# ---- unit-reader-a.sh: SJ1-SJ9/SJ1o, EC14 EC18 EC19 EC25 EC32 EC36 EC37 EC38, RR1-RR20 with DWm-*, AL1-AL9, NW1, LN1-LN9 with
# LN3m/LN6m, LP1-LP5 with LPm1/LPm4, NL1-NL8c with NLma-NLmh, asked in process through the same lib.sh predicates;
# its SEAM-A and CLI-A cells keep one CLI pass and refusal per join mode it owns. One literal call line.
bash "$HERE/unit-reader-a.sh" ${1:+"$1"}; _ura=$?
case "$_ura" in 0) ;; 1) fails=$((fails + 1)) ;; *) bad "unit-reader-a.sh exited $_ura (FIXTURE BROKEN); nothing was asserted" ;; esac
NLM="$(mktemp -d "$WORK/nlm.XXXXXX")" || exit 2
nl_mut() { # <tag> <sed expr> -> the mutant's path, or empty when it did not apply
  mkdir -p "$NLM/$1" && cp "$(dirname "$JOIN")"/*.sh "$NLM/$1/" || return 1
  sed "$2" "$JOIN" > "$NLM/$1/join-remediator-shards.sh" || return 1
  cmp -s "$JOIN" "$NLM/$1/join-remediator-shards.sh" && return 1
  bash -n "$NLM/$1/join-remediator-shards.sh" 2>/dev/null || return 1
  printf '%s' "$NLM/$1/join-remediator-shards.sh"
}

# ---- BL-823: one disposition-key predicate (DISP_KEY_ERE) at every site. A capitalised LIST ITEM is the key, so an
# out-of-set value under it is refused BADDISP; a capitalised column-0 summary is not, so it neither refuses nor
# overwrites the entry's disposition (graph s292's `**Disposition:** 4 repaired / 0 escalated.`).
if p_dispcap "$JOIN"; then ok "DK1: \`- **Disposition:** frobnicated\` in era -> REFUSED BADDISP by name, not NODISP"; B_DK1=1
else bad "DK1: a capitalised list-item disposition outside the vocabulary was not refused BADDISP (rc=$RC): $(grep -m2 -E 'REFUSED|JOINED|ESCALATED' "$JO")"; fi
if p_dispsummary "$JOIN"; then ok "DK2: a column-0 \`**Disposition:** 4 repaired / 0 escalated.\` summary, in the preamble and inside an in-era entry -> rc 0, nothing refused"; B_DK2=1
else bad "DK2: a capitalised summary line was read as a disposition key (rc=$RC): $(grep -m2 -E 'REFUSED|ESCALATED' "$JO")"; fi
# DKm: contract_check's key (the reader that sets the `dfull` BADDISP reads) restored to the case-sensitive literal,
# anchored inside contract_check because part_cites and esc_cites open with the same `$0 ~ DK {` line.
_dkm="$(nl_mut dk '/^contract_check() {$/,/^}$/ s/^    \$0 ~ DK {$/    \/^[[:space:]-]*[*_`]*disposition[*_`]*:\/ {/')"
if [ -z "$_dkm" ]; then bad "DKm: FIXTURE STALE -- the mutation matched nothing in $JOIN; re-anchor it, never relax the assertion"
elif [ "$(grep -c '^    \$0 ~ DK {$' "$_dkm")" -ne "$(( $(grep -c '^    \$0 ~ DK {$' "$JOIN") - 1 ))" ]; then
  bad "DKm: the mutation did not edit exactly one site (contract_check's) -- the anchor is not unique"
else
  p_dispsummary "$_dkm"; _c=$RC
  if [ "$_c" -ne 0 ] || ! has "$JO" "ESCALATED-COUNT: 0"; then mrow DKm DK2=1; bad "DKm: the near-miss control DK2 did not pass under the mutant copy (rc=$_c) -- the copy did not run or the arms are entangled"
  elif p_dispcap "$_dkm"; then mrow DKm DK1=0 DK2=0; bad "DKm: SURVIVED -- contract_check's case-sensitive key still refused the capitalised list item BADDISP"
  else mrow DKm DK1=1 DK2=0; mutant_killed "$(( ${B_DK1:-0} && ${B_DK2:-0} ))" DKm "DKm contract_check's key reverted to case-sensitive: KILLED by [DK1] (rc=$RC, no BADDISP for F-2), DK2 still clean"; fi
fi

# ---- BL-877: one OWNING cell per self-probe call site of the join. A probe is the join's guard against its own grammar
# breaking, so each cell drives the join, in the one mode that reaches its site, from a WHOLE-DIRECTORY copy of the scripts
# dir whose SHARED grammar function the probe exercises is broken by one line, and asserts the probe's own die text and no
# verdict (rc 2). Three broken copies, each built ONCE: ct (contract_check's vocabulary key `not-reproduced` renamed, so
# contract_probe's vocabulary case dies), src (src_check stops counting sources, so src_probe's resolving case dies), sr
# (spec_render_scan stops counting decisions after a render, so spec_render_probe's stale case dies). One copy per grammar,
# because in one tree :1417 dies before :1423 is reached. Each mutant PCm<site> is its cell's broken copy plus that ONE
# call line replaced with `:`, anchored on the call line AND the line above it (`  contract_probe` and
# `  spec_render_probe` each occur twice), the anchor asserted unique and the diff asserted to be exactly one line; the
# owning cell must then reach its mode's verdict (rc 0) with no self-probe text. Sites sharing a broken copy and reached by
# different modes keep firing under each other's mutants; --matrix drives them as the twin column, the plain run does not.
PCB="$WORK/pcb"; mkdir -p "$PCB" || exit 2
pc_break() { # <name> <grammar text> <replacement> -> 0 when $PCB/<name> is a whole-dir copy with that ONE line changed
  local d="$PCB/$1"
  mkdir -p "$d" && cp -R "$SRCDIR"/. "$d/" || return 1
  K="$2" N="$3" awk 'BEGIN { k = ENVIRON["K"]; r = ENVIRON["N"] } { i = index($0, k); if (i) { $0 = substr($0, 1, i - 1) r substr($0, i + length(k)); c++ } print } END { exit (c == 1 ? 0 : 3) }' \
    "$JOIN" > "$d/join-remediator-shards.sh" || return 1
  ! cmp -s "$JOIN" "$d/join-remediator-shards.sh" && bash -n "$d/join-remediator-shards.sh" && [ -f "$d/partition-subject.sh" ]
}
pc_mut() { # <site> <broken name> <line above> <call line> -> the mutant join's path, or EMPTY on a lost or ambiguous anchor
  local d="$PCB/m$1" b="$PCB/$2/join-remediator-shards.sh"
  mkdir -p "$d" && cp -R "$PCB/$2"/. "$d/" || return 1
  P="$3" L="$4" awk 'BEGIN { p = ENVIRON["P"]; l = ENVIRON["L"] } $0 == l && prev == p { prev = $0; print ":"; c++; next } { prev = $0; print } END { exit (c == 1 ? 0 : 3) }' \
    "$b" > "$d/join-remediator-shards.sh" || return 1
  [ "$(awk 'NR == FNR { a[FNR] = $0; n = FNR; next } { if (a[FNR] != $0) x++; m = FNR } END { print (n == m ? x + 0 : -1) }' "$b" "$d/join-remediator-shards.sh")" = 1 ] || return 1
  bash -n "$d/join-remediator-shards.sh" || return 1
  printf '%s' "$d/join-remediator-shards.sh"
}
PC_REC='### F-1 — MAJOR\n- disposition: escalated\n- edit: n/a\n'
pcb_none() { printf '%s' -; }
pcb_chk() { local w; w="$(mktemp -d "$WORK/pcchk.XXXXXX")" && mkdir -p "$w/.claude" && printf '%b' "$PC_REC" > "$w/part.md" && printf '%s' "$w"; }
pcb_src() { local w; w="$(mktemp -d "$WORK/pcsrc.XXXXXX")" && mkdir -p "$w/.claude" && seat_seed "$w" 305 && printf '%s' "$w"; }
pcb_files() { local w; w="$(new_world)" || return 1; three_writers "$w"; part "$w" 01 2.1; part "$w" 02 2.2; part "$w" 03 3.1; printf '%s' "$w"; }
pcb_party() { local w; w="$(party_world)" || return 1
  ppart "$w" 01 2.1 "architecture-dev-1.md#F-1 architecture-tea-1.md#F-1"; ppart "$w" 02 2.2 "_bmad-output/party-mode/s305/architecture-dev-4.md#D4-1"
  ppart "$w" 03 3.1 "architecture-tea-1.md#F-4"; printf '%s' "$w"; }
pcb_subj() { local w; w="$(subj_world)" || return 1; sj_all "$w"; printf '%s' "$w"; }
pcd_esc() { esc_rec "$1" "$PC_REC"; }
pcd_chk() { AI_DLC_PROJECT_ROOT="$2" bash "$1" --check-part "$2/part.md" > "$JO" 2>&1; RC=$?; }
pcd_src() { src_rec "$2" '### F-1\n- disposition: repaired\n- source: architecture-dev-1.md#F-1 architecture-tea-1.md#F-1\n' "$1"; }
pcd_files() { run_join "$1" "$2"; }
pcd_party() { run_pjoin "$1" "$2"; }
pcd_subj() { run_sjoin "$1" "$2"; }
PCT_CT="the entry contract's self-probe failed: the disposition key and vocabulary read"
PCT_SRC="the source resolver's self-probe failed: a resolving source read"
PCT_SR="the SPEC render arm's self-probe failed: a decision after a render read"
pc_site() { # <site> -> PB builder, PD drive, PK broken copy, PT die text, PV verdict, PP line above, PL call line, PS siblings
  case "$1" in
    1417) PB=pcb_none; PD=pcd_esc; PK=ct; PT="$PCT_CT"; PV="ESCALATED-COUNT: 1"; PP='  local _r _sp=0'; PL='  contract_probe'; PS="1756 2768" ;;
    1423) PB=pcb_none; PD=pcd_esc; PK=sr; PT="$PCT_SR"; PV="ESCALATED-COUNT: 1"; PP='  done'; PL='  spec_render_probe'; PS="2779" ;;
    1756) PB=pcb_chk; PD=pcd_chk; PK=ct; PT="$PCT_CT"; PV="CHECK-PART:"; PP='if [ "$PARTMODE" = 1 ]; then'; PL='  contract_probe'; PS="1417 2768" ;;
    1773) PB=pcb_src; PD=pcd_src; PK=src; PT="$PCT_SRC"; PV="SOURCES:"; PP='    && die "${SRC_REC} names only part tokens (<N>.md, cross-<N>.md) in its source: lines, so it is not a party repair; its escalations are read with --escalations ${SRC_REC} --sprint ${SPRINT}"'; PL='  src_probe'; PS="2755" ;;
    2755) PB=pcb_party; PD=pcd_party; PK=src; PT="$PCT_SRC"; PV="JOINED:"; PP='  if [ -d "$SEAT_DIR" ]; then'; PL='    src_probe'; PS="1773" ;;
    2768) PB=pcb_files; PD=pcd_files; PK=ct; PT="$PCT_CT"; PV="JOINED:"; PP='# The entry contract over every part, in every mode (BL-508 siblings, BL-519 set-aside).'; PL='contract_probe'; PS="1417 1756" ;;
    2779) PB=pcb_subj; PD=pcd_subj; PK=sr; PT="$PCT_SR"; PV="JOINED:"; PP='if [ "$SUBJMODE" = 1 ]; then'; PL='  spec_render_probe'; PS="1423" ;;
  esac
}
pc_cell() { # <site> <join> <world> -> 0 when the join refused with THAT probe's die text and printed no verdict: rc 2,
  # or rc 4 at site 1756, --check-part, where a failed self-probe is the harness-fault exit (the join's hdie)
  local want=2; [ "$1" = 1756 ] && want=4
  pc_site "$1"; "$PD" "$2" "$3"; [ "$RC" -eq "$want" ] && has "$JO" "$PT" && ! has "$JO" "$PV"
}
pc_score() { # <base flag> <site> <world> <what> -- the site's call line replaced with `:` in its broken copy
  local m s f row=""
  pc_site "$2"; m="$(pc_mut "$2" "$PK" "$PP" "$PL")"
  if [ -z "$m" ]; then bad "PCm$2: FIXTURE STALE -- the call line at join site $2 ('$PL' under '$PP') is absent or not unique, or the mutant differs by more than one line; re-anchor it, never relax the assertion"; return; fi
  if [ "$MATRIX" = 1 ]; then
    for s in $PS; do pc_site "$s"; f=1; pc_cell "$s" "$m" "$($PB)" && f=0; row="$row PC$s=$f"; done
    pc_site "$2"
  fi
  "$PD" "$m" "$3"
  if [ "$RC" -eq 0 ] && has "$JO" "$PV" && ! has "$JO" "self-probe failed"; then
    mrow "PCm$2" "PC$2=1"$row
    mutant_killed "$1" "PCm$2" "PCm$2 the $4 call at the join's site $2 replaced with ':' in the broken copy: KILLED by [PC$2] -- the join printed '$PV' (rc 0) with no self-probe refusal"
  else
    mrow "PCm$2" "PC$2=0"$row
    bad "PCm$2: SURVIVED or did not run -- with the $4 call removed the join still did not reach '$PV' (rc=$RC): $(head -2 "$JO")"
  fi
}
if ! pc_break ct 'VOC["not-reproduced"] = 1' 'VOC["not-reproduced-c877"] = 1' || ! pc_break src 'n++; ns++' 'n++' \
   || ! pc_break sr '{ if (r) { n++; if (!f) f = NR } }' '{ }'; then
  bad "PC: FIXTURE STALE -- a shared-grammar break (contract_check vocabulary, src_check source count, spec_render_scan decision count) matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"
else
  if [ -z "$(pc_mut 0 ct 'IMPOSSIBLE-PREV-c877-pc0' '  contract_probe')" ]; then ok "PC0: an anchor whose line above matches nothing applies no mutant (the uniqueness control)"
  else bad "PC0: a mutant applied under an impossible anchor; pc_mut does not key on its context"; fi
  _w="$(pcb_none)"; if pc_cell 1417 "$PCB/ct/join-remediator-shards.sh" "$_w"; then ok "PC1417: --escalations, contract_check broken in a whole-dir copy -> record_tail's contract_probe refuses rc 2 with its vocabulary die text, no ESCALATED-COUNT"; B_PC1417=1
  else bad "PC1417: --escalations over the broken contract_check did not refuse with the probe's text (rc=$RC): $(head -2 "$JO")"; fi
  pc_score "${B_PC1417:-0}" 1417 "$_w" contract_probe
  _w="$(pcb_none)"; if pc_cell 1423 "$PCB/sr/join-remediator-shards.sh" "$_w"; then ok "PC1423: --escalations, spec_render_scan broken in a whole-dir copy -> record_tail's spec_render_probe refuses rc 2 with its stale-render die text, no ESCALATED-COUNT"; B_PC1423=1
  else bad "PC1423: --escalations over the broken spec_render_scan did not refuse with the probe's text (rc=$RC): $(head -2 "$JO")"; fi
  pc_score "${B_PC1423:-0}" 1423 "$_w" spec_render_probe
  _w="$(pcb_chk)"; if pc_cell 1756 "$PCB/ct/join-remediator-shards.sh" "$_w"; then ok "PC1756: --check-part, contract_check broken -> the check-part contract_probe refuses rc 4 (a harness fault, no verdict) with its vocabulary die text, no CHECK-PART"; B_PC1756=1
  else bad "PC1756: --check-part over the broken contract_check did not refuse with the probe's text (rc=$RC): $(head -2 "$JO")"; fi
  pc_score "${B_PC1756:-0}" 1756 "$_w" contract_probe
  _w="$(pcb_src)"; if pc_cell 1773 "$PCB/src/join-remediator-shards.sh" "$_w"; then ok "PC1773: --sources, src_check broken -> the --sources src_probe refuses rc 2 with its resolving-source die text, no SOURCES"; B_PC1773=1
  else bad "PC1773: --sources over the broken src_check did not refuse with the probe's text (rc=$RC): $(head -2 "$JO")"; fi
  pc_score "${B_PC1773:-0}" 1773 "$_w" src_probe
  _w="$(pcb_party)"; if pc_cell 2755 "$PCB/src/join-remediator-shards.sh" "$_w"; then ok "PC2755: a party parts join, src_check broken -> the party src_probe refuses rc 2 with its resolving-source die text, nothing JOINED"; B_PC2755=1
  else bad "PC2755: a party join over the broken src_check did not refuse with the probe's text (rc=$RC): $(head -2 "$JO")"; fi
  pc_score "${B_PC2755:-0}" 2755 "$_w" src_probe
  _w="$(pcb_files)"; if pc_cell 2768 "$PCB/ct/join-remediator-shards.sh" "$_w"; then ok "PC2768: a files parts join, contract_check broken -> the every-mode contract_probe refuses rc 2 with its vocabulary die text, nothing JOINED"; B_PC2768=1
  else bad "PC2768: a files join over the broken contract_check did not refuse with the probe's text (rc=$RC): $(head -2 "$JO")"; fi
  pc_score "${B_PC2768:-0}" 2768 "$_w" contract_probe
  _w="$(pcb_subj)"; if pc_cell 2779 "$PCB/sr/join-remediator-shards.sh" "$_w"; then ok "PC2779: a subject join, spec_render_scan broken -> the subject-mode spec_render_probe refuses rc 2 with its stale-render die text, nothing JOINED"; B_PC2779=1
  else bad "PC2779: a subject join over the broken spec_render_scan did not refuse with the probe's text (rc=$RC): $(head -2 "$JO")"; fi
  pc_score "${B_PC2779:-0}" 2779 "$_w" spec_render_probe
fi

# ---- SEAT SPAWN ROWS: a sharded party seat's record is its role-bound spawn-ledger row (seat_row_check). One --sources
# world per state, the seeded seats sharded by name (architecture-<seat>-<ordinal>.md, K = 4 from dev-4). SR1 seeds
# every seat's row except tea-1, whose rows are one property off each (role_contract_cited false; ordinal 2, K 4):
# REFUSED by name. SR7 gives tea-1 one role-bound row at K 5 instead, so the round's seats share no K: REFUSED as a
# K disagreement naming 4 and 5, no seat named. SR2 is SR1 plus tea-1's role-bound 1/4 row: SOURCES. SR3 installs a rulebook WITHOUT the sentence and no
# ledger: one SKIP line, rc 0. The installed sentence is the rulebook's own line, verbatim.
# SRT: the token the join greps for is read out of the join itself and must sit on exactly ONE line of the REAL
# rulebook of the tree under test (found by walking up, either layout); SR_LINE is that real line, never a copy.
GP=""; _d="$HERE"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _c in "$_d/core/skills/ai-dlc/steps/_gate-procedures.md" "$_d/.claude/skills/ai-dlc/steps/_gate-procedures.md"; do
    [ -f "$_c" ] && { GP="$_c"; break 2; }
  done
  _d="$(dirname "$_d")"
done
srt_check() { # <join> <rulebook> -> 0 only when the join's SEAT_ROW_TOKEN is non-empty and on exactly one rulebook line
  local t n; t="$(sed -n 's/^SEAT_ROW_TOKEN="\(.*\)"$/\1/p' "$1" 2>/dev/null | head -1)"
  [ -n "$t" ] || return 1
  n="$(grep -cF -e "$t" "$2" 2>/dev/null)" || n=0
  [ "$n" = 1 ]
}
SR_TOKEN="$(sed -n 's/^SEAT_ROW_TOKEN="\(.*\)"$/\1/p' "$JOIN" | head -1)"
SR_LINE=""; [ -n "$GP" ] && [ -n "$SR_TOKEN" ] && SR_LINE="$(grep -F -e "$SR_TOKEN" "$GP" | head -1)"
if [ -n "$GP" ] && srt_check "$JOIN" "$GP"; then ok "SRT1: the join's SEAT_ROW_TOKEN sits on exactly one line of the real _gate-procedures.md"; B_SRT1=1
else bad "SRT1: SEAT_ROW_TOKEN is empty, unextractable, or not on exactly one line of the real _gate-procedures.md (gp=${GP:-absent}) -- every consumer join would print SEAT-ROWS: SKIP"; fi
# Every seeded row carries SR_TS; the world's install commit is dated SR_INST (epoch seconds), so SR_TS post-dates it
# unless a cell passes the pre-install stamp. The install commit is the seeded git repo's one commit of the rulebook.
SR_POST="2030-01-01T00:00:00Z"; SR_PRE="2020-01-01T00:00:00Z"; SR_INST=1700000000; SR_TS="$SR_POST"
sr_row() { printf '{"v":1,"ts":"%s","sprint":305,"role":"%s","role_contract_cited":%s,"tool_use_id":"toolu_sr%s","shard":"%s"}\n' "$SR_TS" "$1" "$2" "$3" "$4"; }
sr_world() { # <with tea-1 row 0|1> <rulebook carries the sentence 0|1> [ts] [git 0|1] [drop dev-4 0|1] [tea row shard] [seat commit epoch] [noledger] -> a --sources world
  local w; w="$(pcb_src)" || return 1
  SR_TS="${3:-$SR_POST}"
  mkdir -p "$w/.claude/skills/ai-dlc/steps" || return 1
  if [ "$2" = 1 ]; then printf '# Gate procedures\n\n%s\n' "$SR_LINE"; else printf '# Gate procedures\n\nNo seat sentence.\n'; fi \
    > "$w/.claude/skills/ai-dlc/steps/_gate-procedures.md" || return 1
  if [ "$2" = 1 ]; then
    { sr_row architect true 1 "1/4 ## A"; sr_row dev true 2 "1/4 ## A"; sr_row dev true 3 "4/4 ## D"
      sr_row tea false 4 "1/4 ## A"; sr_row tea true 5 "${6:-2/4} ## A"
      if [ "$1" = 1 ]; then sr_row tea true 6 "1/4 ## A"; fi; } > "$w/_bmad-output/spawn-ledger.jsonl" || return 1
  fi
  [ "${5:-0}" = 1 ] && { rm "$w/_bmad-output/party-mode/s305/architecture-dev-4.md" || return 1; }
  [ "${8:-}" = noledger ] && { rm -f "$w/_bmad-output/spawn-ledger.jsonl" || return 1; }
  if [ "${4:-1}" = 1 ]; then
    git -C "$w" init -q . || return 1
    if [ -n "${7:-}" ]; then sr_commit "$w" "${7}" _bmad-output/party-mode || return 1; fi
    sr_commit "$w" "$SR_INST" .claude/skills/ai-dlc/steps/_gate-procedures.md || return 1
  fi
  printf '%s' "$w"
}
sr_commit() { # <world> <epoch> <path> -- one commit of that path, dated
  git -C "$1" add "$3" && GIT_AUTHOR_DATE="$2 +0000" GIT_COMMITTER_DATE="$2 +0000" git -C "$1" -c user.name=fx -c user.email=fx@fx -c commit.gpgsign=false commit -q -m "$3"
}
sr_drive() { pcd_src "$1" "$2"; }
SR_REF="seat file architecture-tea-1.md is a sharded party seat (tea, shard 1/4) with no role-bound row"
sr1() { [ "$RC" -eq 2 ] && has "$JO" "$SR_REF" && ! has "$JO" "architecture-dev-1.md is a sharded" && ! has "$JO" "SOURCES:"; }
sr2() { [ "$RC" -eq 0 ] && has "$JO" "SOURCES:" && ! has "$JO" "is a sharded party seat" && ! has "$JO" "SEAT-ROWS: SKIP"; }
sr3() { [ "$RC" -eq 0 ] && has "$JO" "SEAT-ROWS: SKIP -- the installed" && has "$JO" "SOURCES:" && ! has "$JO" "is a sharded party seat"; }
SR1W="$(sr_world 0 1)"; SR2W="$(sr_world 1 1)"; SR3W="$(sr_world 0 0)"
SR_SPRE=$((SR_INST - 1000)); SR_SPOST=$((SR_INST + 1000))
SR4W="$(sr_world 0 1 "$SR_PRE" 1 0 2/4 "$SR_SPRE")"; SR5W="$(sr_world 0 1 "$SR_POST" 0)"; SR6W="$(sr_world 1 1 "$SR_POST" 1 1)"
SR7W="$(sr_world 0 1 "$SR_POST" 1 0 1/5)"
sr4() { [ "$RC" -eq 0 ] && has "$JO" "SEAT-ROWS: SKIP legacy-round architecture" && has "$JO" "SOURCES:" && ! has "$JO" "is a sharded party seat"; }
sr5() { [ "$RC" -eq 0 ] && has "$JO" "SEAT-ROWS: SKIP install-date-unreadable" && has "$JO" "SOURCES:" && ! has "$JO" "is a sharded party seat"; }
sr6() { [ "$RC" -eq 0 ] && has "$JO" "SOURCES:" && ! has "$JO" "is a sharded party seat" && ! has "$JO" "SEAT-ROWS: SKIP"; }
sr7() { [ "$RC" -eq 2 ] && has "$JO" "the sharded party round architecture's spawn-ledger rows disagree on K" && has "$JO" "at shard counts 4 5 with no single K" && ! has "$JO" "is a sharded party seat" && ! has "$JO" "SOURCES:"; }
# SR8, the mid-sprint pull: an old round's role-bound rows for all four seats at K 4, stamped before the install, then
# a new round with the same roles, ordinals and K stamped after it for every seat but tea-1. The seat files are committed
# before the install, so a round dated off its rows falls to the seat dating and reads legacy, never undatable. Rows name no step, so the
# new round's seats match the old rows too: dated by their EARLIEST row it SKIPped as legacy, and tea-1 joined the old
# round's 1/4 row. Judged and refused by name, its covered siblings not named. SR8b adds tea-1's own post-install row:
# the same mixed ledger, every seat covered -> SOURCES, no SKIP (the allow twin, one row apart).
sr_mixed() { # <tea-1 new-round row 0|1> -> a --sources world
  local w; w="$(pcb_src)" || return 1
  mkdir -p "$w/.claude/skills/ai-dlc/steps" || return 1
  printf '# Gate procedures\n\n%s\n' "$SR_LINE" > "$w/.claude/skills/ai-dlc/steps/_gate-procedures.md" || return 1
  { SR_TS="$SR_PRE"; sr_row architect true 1 "1/4 ## A"; sr_row dev true 2 "1/4 ## A"; sr_row dev true 3 "4/4 ## D"; sr_row tea true 4 "1/4 ## A"
    SR_TS="$SR_POST"; sr_row architect true 5 "1/4 ## A"; sr_row dev true 6 "1/4 ## A"; sr_row dev true 7 "4/4 ## D"
    if [ "$1" = 1 ]; then sr_row tea true 8 "1/4 ## A"; fi; } > "$w/_bmad-output/spawn-ledger.jsonl" || return 1
  git -C "$w" init -q . && sr_commit "$w" "$SR_SPRE" _bmad-output/party-mode && sr_commit "$w" "$SR_INST" .claude/skills/ai-dlc/steps/_gate-procedures.md || return 1
  printf '%s' "$w"
}
SR8W="$(sr_mixed 0)"; SR8BW="$(sr_mixed 1)"
sr8() { [ "$RC" -eq 2 ] && has "$JO" "$SR_REF" && ! has "$JO" "SEAT-ROWS: SKIP" && ! has "$JO" "architecture-dev-1.md is a sharded" && ! has "$JO" "SOURCES:"; }
sr8b() { [ "$RC" -eq 0 ] && has "$JO" "SOURCES:" && ! has "$JO" "is a sharded party seat" && ! has "$JO" "SEAT-ROWS: SKIP"; }
# A round with NO post-install row is dated by its seat files' newest-add commits, and is undatable when any is not clean. SR9: every row pre-install, every
# seat committed AFTER the install -> judged, all four seats refused by name (shard <o>/K: no post-install row names
# K). SR10: the same rows, the seats never committed -> SKIP round-undatable naming 4 seats, never legacy, rc 0.
# SR4 above is the legacy twin: the same rows, the seats committed BEFORE the install. SR11: SR4 with no spawn
# ledger at all -> SKIP legacy-round, rc 0, no missing-ledger refusal. SR12: a depth-1 clone of the SR1 history with a
# later commit on top -> SKIP install-date-unreadable naming the shallow clone, no seat judged.
SR9W="$(sr_world 0 1 "$SR_PRE" 1 0 2/4 "$SR_SPOST")"; SR10W="$(sr_world 0 1 "$SR_PRE")"
SR11W="$(sr_world 0 1 "$SR_PRE" 1 0 2/4 "$SR_SPRE" noledger)"
sr_shallow() {
  local o w; o="$(sr_world 0 1)" || return 1
  sr_commit "$o" "$SR_SPRE" _bmad-output && printf 'x\n' > "$o/later" && sr_commit "$o" "$SR_SPOST" later || return 1
  w="$(mktemp -d "$WORK/srsh.XXXXXX")" && git clone -q --depth 1 "file://$o" "$w/c" 2>/dev/null || return 1
  [ "$(git -C "$w/c" rev-parse --is-shallow-repository)" = true ] || return 1
  printf '%s' "$w/c"
}
SR12W="$(sr_shallow)"
# SR13: the SR4 legacy round (rows and seat commits all pre-install), then every seat file overwritten by a re-run and
# left uncommitted -> SKIP round-undatable 4 seats, never legacy, rc 0. SR14: the seats committed pre-install, deleted,
# and re-added AFTER the install, every row pre-install -> dated by the NEWEST add, judged, all 4 seats refused. SR15:
# the SR9 round (committed after the install) beside two untracked decoys, an unsharded `architecture-dev.md` and a
# sharded seat of another step `architecture-x-dev-01.md` -> still judged and all 4 refused (the dating list is the
# scan's parsed seats, never a `<step>-*` glob).
sr_rerun() { local w; w="$(sr_world 0 1 "$SR_PRE" 1 0 2/4 "$SR_SPRE")" || return 1
  for f in "$w"/_bmad-output/party-mode/s305/architecture-*.md; do printf '\nre-run\n' >> "$f" || return 1; done; printf '%s' "$w"; }
sr_readd() { local w; w="$(sr_world 0 1 "$SR_PRE" 1 0 2/4 "$SR_SPRE")" || return 1
  git -C "$w" rm -q -r _bmad-output/party-mode || return 1
  GIT_AUTHOR_DATE="$SR_SPOST +0000" GIT_COMMITTER_DATE="$SR_SPOST +0000" git -C "$w" -c user.name=fx -c user.email=fx@fx -c commit.gpgsign=false commit -q -m del || return 1
  seat_seed "$w" 305 && sr_commit "$w" "$((SR_SPOST + 10))" _bmad-output/party-mode || return 1; printf '%s' "$w"; }
sr_decoy() { local w; w="$(sr_world 0 1 "$SR_PRE" 1 0 2/4 "$SR_SPOST")" || return 1
  printf '# x\n' > "$w/_bmad-output/party-mode/s305/architecture-dev.md" && printf '# x\n' > "$w/_bmad-output/party-mode/s305/architecture-x-dev-01.md" || return 1
  printf '%s' "$w"; }
# SR16: the SR10 round (never committed) with party-mode excluded in .git/info/exclude, so `git status` reports
# nothing -> still round-undatable from the never-committed count, never legacy.
sr_hidden() { local w; w="$(sr_world 0 1 "$SR_PRE")" || return 1
  printf '_bmad-output/party-mode/\n' >> "$w/.git/info/exclude" || return 1
  [ -z "$(git -C "$w" status --porcelain -- _bmad-output/party-mode)" ] || return 1; printf '%s' "$w"; }
SR13W="$(sr_rerun)"; SR14W="$(sr_readd)"; SR15W="$(sr_decoy)"; SR16W="$(sr_hidden)"
sr13() { [ "$RC" -eq 0 ] && has "$JO" "SEAT-ROWS: SKIP round-undatable architecture 4 seats" && ! has "$JO" "legacy-round" && has "$JO" "SOURCES:" && ! has "$JO" "is a sharded party seat"; }
sr9() { [ "$RC" -eq 2 ] && [ "$(grep -c 'is a sharded party seat' "$JO")" = 4 ] && has "$JO" "seat file architecture-tea-1.md is a sharded party seat (tea, shard 1/K)" && ! has "$JO" "SEAT-ROWS: SKIP" && ! has "$JO" "SOURCES:"; }
sr10() { [ "$RC" -eq 0 ] && has "$JO" "SEAT-ROWS: SKIP round-undatable architecture 4 seats" && ! has "$JO" "legacy-round" && has "$JO" "SOURCES:" && ! has "$JO" "is a sharded party seat"; }
sr11() { [ "$RC" -eq 0 ] && has "$JO" "SEAT-ROWS: SKIP legacy-round architecture" && has "$JO" "SOURCES:" && ! has "$JO" "have no spawn ledger"; }
sr12() { [ "$RC" -eq 0 ] && has "$JO" "SEAT-ROWS: SKIP install-date-unreadable" && has "$JO" "is a shallow clone" && has "$JO" "SOURCES:" && ! has "$JO" "is a sharded party seat"; }
if [ -z "$SR1W" ] || [ -z "$SR2W" ] || [ -z "$SR3W" ] || [ -z "$SR4W" ] || [ -z "$SR5W" ] || [ -z "$SR6W" ] || [ -z "$SR7W" ] || [ -z "$SR8W" ] || [ -z "$SR8BW" ] \
  || [ -z "$SR9W" ] || [ -z "$SR10W" ] || [ -z "$SR11W" ] || [ -z "$SR12W" ] || [ -z "$SR13W" ] || [ -z "$SR14W" ] || [ -z "$SR15W" ] || [ -z "$SR16W" ]; then bad "SR: FIXTURE BROKEN -- a seat-row world could not be built"
else
  sr_drive "$JOIN" "$SR1W"
  if sr1; then ok "SR1: a sharded seat (tea-1) whose rows are role_contract_cited false and ordinal 2 -> REFUSED rc 2 naming it, its covered siblings not named"; B_SR1=1
  else bad "SR1: a sharded seat with no role-bound row was not refused by name (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR2W"
  if sr2; then ok "SR2: the near-miss, every sharded seat with its role-bound row (tea-1 1/4 added) -> SOURCES, rc 0, no seat refused"; B_SR2=1
  else bad "SR2: every seat carried its row and the join did not pass (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR3W"
  if sr3; then ok "SR3: the installed rulebook lacks the seat-record sentence -> one SEAT-ROWS: SKIP line, SOURCES, no seat refused"; B_SR3=1
  else bad "SR3: under a rulebook before the shape the join did not SKIP the seat-row join (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR4W"
  if sr4; then ok "SR4: the SR1 round with every row stamped before the install commit -> SEAT-ROWS: SKIP legacy-round, SOURCES, no seat refused"; B_SR4=1
  else bad "SR4: a round dispatched before the install was judged or not skipped by name (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR5W"
  if sr5; then ok "SR5: the rulebook is not tracked (no install commit) -> SEAT-ROWS: SKIP install-date-unreadable, rc 0, never a refusal"; B_SR5=1
  else bad "SR5: an unreadable install date did not SKIP with its reason (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR6W"
  if sr6; then ok "SR6: the top-ordinal seat file (dev-4) never delivered, its siblings' rows carry K 4 -> every delivered seat joins, nothing refused"; B_SR6=1
  else bad "SR6: K was taken from the delivered files, so a round missing its top ordinal refused its delivered seats (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR7W"
  if sr7; then ok "SR7: tea-1's only role-bound row is at K 5, its siblings' at K 4 -> REFUSED rc 2 as a K disagreement naming 4 and 5, no seat named"; B_SR7=1
  else bad "SR7: seat rows sharing no K were not refused as a disagreement naming both values (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR8W"
  if sr8; then ok "SR8: a post-install round sharing roles, ordinals and K with a pre-install round of the sprint, tea-1 covered only by the old round's row -> judged, no SKIP, REFUSED rc 2 naming tea-1 alone"; B_SR8=1
  else bad "SR8: the mixed sprint's post-install round was skipped as legacy or its old-row-only seat joined (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR8BW"
  if sr8b; then ok "SR8b: the same mixed ledger with tea-1's own post-install row -> SOURCES, rc 0, no SKIP, no seat refused"; B_SR8B=1
  else bad "SR8b: a judged round with every seat's post-install row did not pass over the old round's rows (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR9W"
  if sr9; then ok "SR9: every row pre-install, every seat committed after the install -> judged, all 4 seats REFUSED by name at shard <o>/K, no SKIP"; B_SR9=1
  else bad "SR9: a round with no post-install row and post-install seat commits was not judged (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR10W"
  if sr10; then ok "SR10: every row pre-install, the seats never committed -> SEAT-ROWS: SKIP round-undatable architecture 4 seats, not legacy, rc 0"; B_SR10=1
  else bad "SR10: a round with uncommitted seats and no post-install row was not SKIPped as undatable (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR11W"
  if sr11; then ok "SR11: the legacy SR4 round with no spawn ledger -> SKIP legacy-round, rc 0, no missing-ledger refusal"; B_SR11=1
  else bad "SR11: a legacy round with no ledger was refused for the ledger or not skipped (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR12W"
  if sr12; then ok "SR12: a depth-1 shallow clone -> SEAT-ROWS: SKIP install-date-unreadable naming the shallow clone, rc 0, no seat judged"; B_SR12=1
  else bad "SR12: a shallow clone's boundary commit was read as the install (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR13W"
  if sr13; then ok "SR13: the legacy SR4 round's committed seats overwritten by a re-run and left uncommitted -> SEAT-ROWS: SKIP round-undatable architecture 4 seats, not legacy, rc 0"; B_SR13=1
  else bad "SR13: a round whose committed pre-install seats were modified in the working tree read legacy or was judged (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR14W"
  if sr9; then ok "SR14: seats added pre-install, deleted, re-added after the install, every row pre-install -> dated by the newest add, judged, all 4 seats REFUSED"; B_SR14=1
  else bad "SR14: a round re-added after the install was dated by its oldest add (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR15W"
  if sr9; then ok "SR15: the SR9 round beside untracked decoys architecture-dev.md and architecture-x-dev-01.md -> still judged, all 4 seats REFUSED, never undatable"; B_SR15=1
  else bad "SR15: an unsharded or other-step file beside the round entered its dating list (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SR16W"
  if sr10; then ok "SR16: the SR10 round's never-committed seats hidden from git status by .git/info/exclude -> still SEAT-ROWS: SKIP round-undatable architecture 4 seats, not legacy"; B_SR16=1
  else bad "SR16: a never-committed round invisible to git status read legacy or was judged (rc=$RC): $(head -3 "$JO")"; fi
  # SRm7: the round dated by its EARLIEST matched row again -> SR8 is not judged (its date falls to its seats, committed
  # before the install, and the round SKIPs as legacy, which the arm requires). SR4 (every row old) still SKIPs.
  if pc_break srm7 'function later(a, b) { return a + 0 > b + 0 }' 'function later(a, b) { return a + 0 < b + 0 }'; then
    sr_drive "$PCB/srm7/join-remediator-shards.sh" "$SR8W"; _a=0; ! sr8 && has "$JO" "SEAT-ROWS: SKIP legacy-round architecture" && _a=1
    sr_drive "$PCB/srm7/join-remediator-shards.sh" "$SR4W"; _b=1; sr4 && _b=0
    mrow SRm7 "SR8=$_a" "SR4=$_b"
    if [ "$_a" = 1 ] && [ "$_b" = 0 ]; then mutant_killed "$(( ${B_SR8:-0} && ${B_SR4:-0} ))" SRm7 "SRm7 the round dated by its earliest row: KILLED by [SR8] -- the post-install round dated off its pre-install row and its pre-install seat commits, SKIPped as legacy-round; SR4 still skips"
    else bad "SRm7: SURVIVED or entangled -- SR8=$_a SR4=$_b (want 1 0)"; fi
  else bad "SRm7: FIXTURE STALE -- the row-date order line matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"; fi
  # SRm8: a pre-install row covers a seat again -> SR8's tea-1 joins the old round's row. SR8b still passes.
  if pc_break srm8 'if (INST == "" || $5 == "-1" || $5 + 0 >= INST + 0) { n[k SUBSEP $4]++' 'if (1) { n[k SUBSEP $4]++'; then
    sr_drive "$PCB/srm8/join-remediator-shards.sh" "$SR8W"; _a=1; sr8 && _a=0
    sr_drive "$PCB/srm8/join-remediator-shards.sh" "$SR8BW"; _b=1; sr8b && _b=0
    mrow SRm8 "SR8=$_a" "SR8b=$_b"
    if [ "$_a" = 1 ] && [ "$_b" = 0 ]; then mutant_killed "$(( ${B_SR8:-0} && ${B_SR8B:-0} ))" SRm8 "SRm8 a pre-install row covers a seat: KILLED by [SR8] -- tea-1 joined the old round's row; SR8b still passes"
    else bad "SRm8: SURVIVED or entangled -- SR8=$_a SR8b=$_b (want 1 0)"; fi
  else bad "SRm8: FIXTURE STALE -- the coverage bound line matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"; fi
  # SRm9: an undatable round folded into legacy -> SR10 reads legacy-round. SRm10: the seat-commit check skipped (a
  # round whose rows are all pre-install is legacy outright) -> SR9 SKIPs. SRm11: the missing-ledger refusal
  # unconditional again -> SR11 refuses. SRm12: the shallow-clone check removed -> SR12 reads the boundary as the install.
  if pc_break srm9 'c < n ? "U" :' 'c < n ? "L" :'; then
    sr_drive "$PCB/srm9/join-remediator-shards.sh" "$SR10W"; _a=1; sr10 && _a=0
    sr_drive "$PCB/srm9/join-remediator-shards.sh" "$SR4W"; _b=1; sr4 && _b=0
    mrow SRm9 "SR10=$_a" "SR4=$_b"
    if [ "$_a" = 1 ] && [ "$_b" = 0 ]; then mutant_killed "$(( ${B_SR10:-0} && ${B_SR4:-0} ))" SRm9 "SRm9 undatable folded into legacy: KILLED by [SR10] -- the uncommitted round read legacy-round; SR4 still skips"
    else bad "SRm9: SURVIVED or entangled -- SR10=$_a SR4=$_b (want 1 0)"; fi
  else bad "SRm9: FIXTURE STALE -- the era verdict line matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"; fi
  # SRm13: the working-tree status ignored -> SR13 reads legacy-round. SRm14: each seat dated by its OLDEST add again
  # -> SR14 reads legacy-round. SR4 (clean, added once, pre-install) still skips under both.
  if pc_break srm13 '[ -n "$st" ] && dirty=1' '[ -n "$st" ] && dirty=""'; then
    sr_drive "$PCB/srm13/join-remediator-shards.sh" "$SR13W"; _a=0; ! sr13 && has "$JO" "SEAT-ROWS: SKIP legacy-round architecture" && _a=1
    sr_drive "$PCB/srm13/join-remediator-shards.sh" "$SR4W"; _b=1; sr4 && _b=0
    mrow SRm13 "SR13=$_a" "SR4=$_b"
    if [ "$_a" = 1 ] && [ "$_b" = 0 ]; then mutant_killed "$(( ${B_SR13:-0} && ${B_SR4:-0} ))" SRm13 "SRm13 the working-tree status ignored: KILLED by [SR13] -- the overwritten round read legacy-round; SR4 still skips"
    else bad "SRm13: SURVIVED or entangled -- SR13=$_a SR4=$_b (want 1 0)"; fi
  else bad "SRm13: FIXTURE STALE -- the dirty-status line matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"; fi
  if pc_break srm14 'if (!(b in A)) A[b] = ts' 'if (!(b in A) || ts < A[b]) A[b] = ts'; then
    sr_drive "$PCB/srm14/join-remediator-shards.sh" "$SR14W"; _a=0; ! sr9 && has "$JO" "SEAT-ROWS: SKIP legacy-round architecture" && _a=1
    sr_drive "$PCB/srm14/join-remediator-shards.sh" "$SR4W"; _b=1; sr4 && _b=0
    mrow SRm14 "SR14=$_a" "SR4=$_b"
    if [ "$_a" = 1 ] && [ "$_b" = 0 ]; then mutant_killed "$(( ${B_SR14:-0} && ${B_SR4:-0} ))" SRm14 "SRm14 each seat dated by its oldest add: KILLED by [SR14] -- the re-added round read legacy-round; SR4 still skips"
    else bad "SRm14: SURVIVED or entangled -- SR14=$_a SR4=$_b (want 1 0)"; fi
  else bad "SRm14: FIXTURE STALE -- the newest-add line matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"; fi
  # SRm15: the never-committed count dropped from the verdict (status alone decides) -> SR16 reads legacy-round.
  if pc_break srm15 'dirty != "" || c < n ?' 'dirty != "" ?'; then
    sr_drive "$PCB/srm15/join-remediator-shards.sh" "$SR16W"; _a=0; ! sr10 && has "$JO" "SEAT-ROWS: SKIP legacy-round architecture" && _a=1
    sr_drive "$PCB/srm15/join-remediator-shards.sh" "$SR4W"; _b=1; sr4 && _b=0
    mrow SRm15 "SR16=$_a" "SR4=$_b"
    if [ "$_a" = 1 ] && [ "$_b" = 0 ]; then mutant_killed "$(( ${B_SR16:-0} && ${B_SR4:-0} ))" SRm15 "SRm15 the never-committed count dropped: KILLED by [SR16] -- the status-invisible uncommitted round read legacy-round; SR4 still skips"
    else bad "SRm15: SURVIVED or entangled -- SR16=$_a SR4=$_b (want 1 0)"; fi
  else bad "SRm15: FIXTURE STALE -- the never-committed count term matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"; fi
  if pc_break srm10 'if [ "$rts" != -1 ] && [ "$rts" -ge "$inst" ]; then judged=1; continue; fi' \
    'if [ "$rts" != -1 ]; then if [ "$rts" -ge "$inst" ]; then judged=1; else echo "SEAT-ROWS: SKIP legacy-round ${t}"; skipped="$skipped $t "; fi; continue; fi'; then
    sr_drive "$PCB/srm10/join-remediator-shards.sh" "$SR9W"; _a=1; sr9 && _a=0
    sr_drive "$PCB/srm10/join-remediator-shards.sh" "$SR4W"; _b=1; sr4 && _b=0
    mrow SRm10 "SR9=$_a" "SR4=$_b"
    if [ "$_a" = 1 ] && [ "$_b" = 0 ]; then mutant_killed "$(( ${B_SR9:-0} && ${B_SR4:-0} ))" SRm10 "SRm10 the seat-commit check skipped: KILLED by [SR9] -- the post-install-committed round read legacy; SR4 still skips"
    else bad "SRm10: SURVIVED or entangled -- SR9=$_a SR4=$_b (want 1 0)"; fi
  else bad "SRm10: FIXTURE STALE -- the post-install row line matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"; fi
  if pc_break srm11 '[ -f "$sl" ] || { [ -z "$judged" ] || refuse' '[ -f "$sl" ] || { refuse'; then
    sr_drive "$PCB/srm11/join-remediator-shards.sh" "$SR11W"; _a=1; sr11 && _a=0
    sr_drive "$PCB/srm11/join-remediator-shards.sh" "$SR4W"; _b=1; sr4 && _b=0
    mrow SRm11 "SR11=$_a" "SR4=$_b"
    if [ "$_a" = 1 ] && [ "$_b" = 0 ]; then mutant_killed "$(( ${B_SR11:-0} && ${B_SR4:-0} ))" SRm11 "SRm11 the missing-ledger refusal unconditional: KILLED by [SR11] -- the legacy round was refused for its ledger; SR4 still skips"
    else bad "SRm11: SURVIVED or entangled -- SR11=$_a SR4=$_b (want 1 0)"; fi
  else bad "SRm11: FIXTURE STALE -- the missing-ledger line matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"; fi
  if pc_break srm12 'rev-parse --is-shallow-repository 2>/dev/null)" = true ]' 'rev-parse --is-shallow-repository 2>/dev/null)" = never ]'; then
    sr_drive "$PCB/srm12/join-remediator-shards.sh" "$SR12W"; _a=1; sr12 && _a=0
    sr_drive "$PCB/srm12/join-remediator-shards.sh" "$SR1W"; _b=1; sr1 && _b=0
    mrow SRm12 "SR12=$_a" "SR1=$_b"
    if [ "$_a" = 1 ] && [ "$_b" = 0 ]; then mutant_killed "$(( ${B_SR12:-0} && ${B_SR1:-0} ))" SRm12 "SRm12 the shallow-clone check removed: KILLED by [SR12] -- the boundary commit was read as the install; SR1 still refuses"
    else bad "SRm12: SURVIVED or entangled -- SR12=$_a SR1=$_b (want 1 0)"; fi
  else bad "SRm12: FIXTURE STALE -- the shallow-clone line matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"; fi
  # SRm4: the per-round legacy test removed -> SR4 refuses the pre-install round. SRm5: K taken from the files' top ordinal -> SR6 refuses.
  if pc_break srm4 '      L) echo "SEAT-ROWS: SKIP legacy-round' '      L) judged=1 ;; L-off) echo "SEAT-ROWS: SKIP legacy-round'; then
    sr_drive "$PCB/srm4/join-remediator-shards.sh" "$SR4W"; _a=1; sr4 && _a=0
    sr_drive "$PCB/srm4/join-remediator-shards.sh" "$SR1W"; _b=1; sr1 && _b=0
    mrow SRm4 "SR4=$_a" "SR1=$_b"
    if [ "$_a" = 1 ] && [ "$_b" = 0 ]; then mutant_killed "$(( ${B_SR4:-0} && ${B_SR1:-0} ))" SRm4 "SRm4 the per-round legacy test removed: KILLED by [SR4] -- the pre-install round was judged; SR1 still passes"
    else bad "SRm4: SURVIVED or entangled -- SR4=$_a SR1=$_b (want 1 0)"; fi
  else bad "SRm4: FIXTURE STALE -- the legacy test line matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"; fi
  if pc_break srm5 '        if (ni) SK[t] = ik + 0;' '        ik = 0; for (i = 1; i <= nf; i++) if (FT[i] == t && FO[i] != "cross" && FO[i] > ik) ik = FO[i]; if (1) SK[t] = ik + 0;'; then
    sr_drive "$PCB/srm5/join-remediator-shards.sh" "$SR6W"; _a=1; sr6 && _a=0
    sr_drive "$PCB/srm5/join-remediator-shards.sh" "$SR2W"; _b=1; sr2 && _b=0
    mrow SRm5 "SR6=$_a" "SR2=$_b"
    if [ "$_a" = 1 ] && [ "$_b" = 0 ]; then mutant_killed "$(( ${B_SR6:-0} && ${B_SR2:-0} ))" SRm5 "SRm5 K taken from the delivered files: KILLED by [SR6] -- the round missing its top ordinal refused; SR2 still passes"
    else bad "SRm5: SURVIVED or entangled -- SR6=$_a SR2=$_b (want 1 0)"; fi
  else bad "SRm5: FIXTURE STALE -- the K selection line matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"; fi
  # SRm6: the common-K intersection replaced by the first row-bearing seat's K set -> SR7 joins at architect-1's K 4.
  if pc_break srm6 'else { for (c in I) if (!(c in H)) delete I[c] }' 'else { }'; then
    sr_drive "$PCB/srm6/join-remediator-shards.sh" "$SR7W"; _a=1; sr7 && _a=0
    sr_drive "$PCB/srm6/join-remediator-shards.sh" "$SR2W"; _b=1; sr2 && _b=0
    mrow SRm6 "SR7=$_a" "SR2=$_b"
    if [ "$_a" = 1 ] && [ "$_b" = 0 ]; then mutant_killed "$(( ${B_SR7:-0} && ${B_SR2:-0} ))" SRm6 "SRm6 K kept from the first row-bearing seat: KILLED by [SR7] -- the disagreeing round was not refused as one; SR2 still passes"
    else bad "SRm6: SURVIVED or entangled -- SR7=$_a SR2=$_b (want 1 0)"; fi
  else bad "SRm6: FIXTURE STALE -- the K intersection line matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"; fi
  # SRm3: the real rulebook paragraph rewrapped so the token splits across two lines -> SRT1 fails.
  _w="$(mktemp -d "$WORK/srt.XXXXXX")"; _n="${SR_TOKEN%% *}"
  if [ -n "$GP" ] && [ -n "$_n" ]; then awk -v t="$SR_TOKEN" -v h="${SR_TOKEN%% *}" '{ i=index($0,t); if(i){ print substr($0,1,i-1) h; print substr($0,i+length(h)+1) } else print }' "$GP" > "$_w/_gate-procedures.md"; fi
  if [ -s "$_w/_gate-procedures.md" ] && ! cmp -s "$GP" "$_w/_gate-procedures.md"; then
    _a=1; srt_check "$JOIN" "$_w/_gate-procedures.md" || _a=0
    srt_check "$JOIN" "$GP"; _b=$?
    mrow SRm3 "SRT1=$_a" "ctl=$_b"
    if [ "$_a" = 0 ] && [ "$_b" = 0 ]; then mutant_killed "${B_SRT1:-0}" SRm3 "SRm3 the token split across two rulebook lines: KILLED by [SRT1] -- the rewrapped copy is refused, the real file passes"
    else bad "SRm3: SURVIVED or entangled -- rewrapped copy rejected=$([ "$_a" = 0 ] && echo 1 || echo 0) real passes=$([ "$_b" = 0 ] && echo 1 || echo 0)"; fi
  else bad "SRm3: FIXTURE STALE -- the rewrapped rulebook copy was not produced or equals the original"; fi
  # SRm1: the join's call removed (seat_complete_check no longer calls seat_row_check) -> SR1 passes the row-less seat.
  # SRm2: the legacy boundary removed (the rulebook test made always-judge) -> SR3 refuses for want of a ledger.
  if pc_break srm1 '  seat_row_check "$sd" "$cited"' '  :'; then
    sr_drive "$PCB/srm1/join-remediator-shards.sh" "$SR1W"; _a=1; sr1 && _a=0
    sr_drive "$PCB/srm1/join-remediator-shards.sh" "$SR2W"; _b=1; sr2 && _b=0
    mrow SRm1 "SR1=$_a" "SR2=$_b"
    if [ "$_a" = 1 ] && [ "$_b" = 0 ]; then mutant_killed "$(( ${B_SR1:-0} && ${B_SR2:-0} ))" SRm1 "SRm1 seat_row_check's call removed: KILLED by [SR1] -- the row-less seat joined; SR2 still passes"
    else bad "SRm1: SURVIVED or entangled -- with the seat-row join removed SR1=$_a SR2=$_b (want 1 0)"; fi
  else bad "SRm1: FIXTURE STALE -- the seat_row_check call line matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"; fi
  if pc_break srm2 'if ! grep -qF -e "$SEAT_ROW_TOKEN" "$gp" 2>/dev/null; then' 'if false; then'; then
    sr_drive "$PCB/srm2/join-remediator-shards.sh" "$SR3W"; _a=1; sr3 && _a=0
    mrow SRm2 "SR3=$_a"
    if [ "$_a" = 1 ]; then mutant_killed "${B_SR3:-0}" SRm2 "SRm2 the installed-rulebook boundary removed: KILLED by [SR3] -- a rulebook before the shape was judged (rc=$RC)"
    else bad "SRm2: SURVIVED -- with the boundary removed SR3 still skipped"; fi
  else bad "SRm2: FIXTURE STALE -- the boundary line matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"; fi
fi

# ---- SEAT FILE ROWS: a row carrying `mark_file` (the dispatch guard copies it from the brief) matches ONLY the cited seat
# whose path ends in `party-mode/s305/<that basename>`, never enters step/ordinal/K inference, dates its own seat, and
# covers it only when stamped at or after the install. Field-less rows keep the inference, for the seats no field-row
# matched. The cited round is always `architecture` (pcd_src); SRC1 and SRC4 add an uncited `requirements` round.
SR_G=/Users/n8/git/graph/_bmad-output/party-mode/s305
sr_frow() { printf '{"v":1,"ts":"%s","sprint":305,"role":"%s","role_contract_cited":true,"tool_use_id":"toolu_sf%s","shard":"%s","mark":"rendered","mark_file":"%s"}\n' "$SR_TS" "$1" "$2" "$3" "$4"; }
sr_fbuild() { # <seat commit epoch> <requirements seats 0|1> <rows fn> -> a --sources world
  local w s; w="$(pcb_src)" || return 1
  mkdir -p "$w/.claude/skills/ai-dlc/steps" && printf '# Gate procedures\n\n%s\n' "$SR_LINE" > "$w/.claude/skills/ai-dlc/steps/_gate-procedures.md" || return 1
  if [ "$2" = 1 ]; then for s in $SEATS; do printf '# x\n' > "$w/_bmad-output/party-mode/s305/requirements-$s.md" || return 1; done; fi
  "$3" > "$w/_bmad-output/spawn-ledger.jsonl" || return 1
  git -C "$w" init -q . && sr_commit "$w" "$1" _bmad-output/party-mode && sr_commit "$w" "$SR_INST" .claude/skills/ai-dlc/steps/_gate-procedures.md || return 1
  printf '%s' "$w"
}
# SRC1, DEFECT 1: the cited round's rows field-less and pre-install, the requirements round's rows post-install and naming
# their own seat files at the same roles, ordinals and K -> they cover and date nothing of architecture: legacy.
sr_rows_c1() { SR_TS="$SR_PRE"; sr_row architect true 1 "1/4 ## A"; sr_row dev true 2 "1/4 ## A"; sr_row dev true 3 "4/4 ## D"; sr_row tea true 4 "1/4 ## A"
  SR_TS="$SR_POST"; sr_frow architect 5 "1/4 ## A" "$SR_G/requirements-architect-1.md"; sr_frow dev 6 "1/4 ## A" "$SR_G/requirements-dev-1.md"
  sr_frow dev 7 "4/4 ## D" "$SR_G/requirements-dev-4.md"; sr_frow tea 8 "1/4 ## A" "$SR_G/requirements-tea-1.md"; }
# SRC2: tea-1's only row names a file that does not exist (`architecture-tea-01.md`) -> tea-1 refused, its siblings covered.
sr_rows_c2() { SR_TS="$SR_POST"; sr_row architect true 1 "1/4 ## A"; sr_row dev true 2 "1/4 ## A"; sr_row dev true 3 "4/4 ## D"
  sr_frow tea 4 "1/4 ## A" "_bmad-output/party-mode/s305/architecture-tea-01.md"; }
# SRC3: three seats by field-rows (worktree-relative), tea-1 by a field-less row -> the fallback still covers tea-1.
sr_rows_c3() { SR_TS="$SR_POST"; sr_frow architect 1 "1/4 ## A" "_bmad-output/party-mode/s305/architecture-architect-1.md"
  sr_frow dev 2 "1/4 ## A" "_bmad-output/party-mode/s305/architecture-dev-1.md"; sr_frow dev 3 "4/4 ## D" "_bmad-output/party-mode/s305/architecture-dev-4.md"
  sr_row tea true 4 "1/4 ## A"; }
# SRC4: tea-1 has no row; the requirements round's tea-1 field-row sits at tea 1/4 -> architecture-tea-1 is refused.
sr_rows_c4() { SR_TS="$SR_POST"; sr_row architect true 1 "1/4 ## A"; sr_row dev true 2 "1/4 ## A"; sr_row dev true 3 "4/4 ## D"
  sr_frow tea 4 "1/4 ## A" "$SR_G/requirements-tea-1.md"; }
# SRC5 / SRC5b: every seat by its own field-row, all stamped before the install. Seats committed before it -> legacy
# (SRC5); committed after it -> judged, and a pre-install field-row covers nothing: all four refused (SRC5b).
sr_rows_c5() { SR_TS="$SR_PRE"; sr_frow architect 1 "1/4 ## A" "$SR_G/architecture-architect-1.md"; sr_frow dev 2 "1/4 ## A" "$SR_G/architecture-dev-1.md"
  sr_frow dev 3 "4/4 ## D" "$SR_G/architecture-dev-4.md"; sr_frow tea 4 "1/4 ## A" "$SR_G/architecture-tea-1.md"; }
# SRC6, the relocated root: the same field-rows post-install, absolute under the reference consumer path while the join
# runs under a mktemp JR_ROOT, seats committed before the install -> dated by the rows, judged, every seat covered.
sr_rows_c6() { SR_TS="$SR_POST"; sr_frow architect 1 "1/4 ## A" "$SR_G/architecture-architect-1.md"; sr_frow dev 2 "1/4 ## A" "$SR_G/architecture-dev-1.md"
  sr_frow dev 3 "4/4 ## D" "$SR_G/architecture-dev-4.md"; sr_frow tea 4 "1/4 ## A" "$SR_G/architecture-tea-1.md"; }
SRC1W="$(sr_fbuild "$SR_SPRE" 1 sr_rows_c1)"; SRC2W="$(sr_fbuild "$SR_SPRE" 0 sr_rows_c2)"; SRC3W="$(sr_fbuild "$SR_SPRE" 0 sr_rows_c3)"
SRC4W="$(sr_fbuild "$SR_SPRE" 1 sr_rows_c4)"; SRC5W="$(sr_fbuild "$SR_SPRE" 0 sr_rows_c5)"; SRC5BW="$(sr_fbuild "$SR_SPOST" 0 sr_rows_c5)"
# SRC7: architect-1, dev-4 and tea-1 by field-less rows at K 4; dev-1 named by its own field-row AND carrying a field-less
# row at K 9 -> a field seat never votes K, so the round's K is 4 and dev-1 is covered by its field-row: SOURCES rc 0.
sr_rows_c7() { SR_TS="$SR_POST"; sr_row architect true 1 "1/4 ## A"; sr_row dev true 2 "1/9 ## A"; sr_row dev true 3 "4/4 ## D"; sr_row tea true 4 "1/4 ## A"
  sr_frow dev 5 "1/4 ## A" "$SR_G/architecture-dev-1.md"; }
# SRC8: a cited post-install DEV field-row names architecture-tea-1.md, and tea-1 has no row of its own -> an M row
# covers only the seat of its own role, so tea-1 is refused by name; the field-row still names it (no fallback).
sr_rows_c8() { SR_TS="$SR_POST"; sr_row architect true 1 "1/4 ## A"; sr_row dev true 2 "1/4 ## A"; sr_row dev true 3 "4/4 ## D"
  sr_frow dev 4 "1/4 ## A" "$SR_G/architecture-tea-1.md"; }
# SRC9: tea-1's only row carries a mark_file with no party-mode tail (the guard's unrendered placeholder) -> it names no
# seat file and is read as a field-less row: tea-1 covered at tea 1/4, SOURCES rc 0.
sr_rows_c9() { SR_TS="$SR_POST"; sr_row architect true 1 "1/4 ## A"; sr_row dev true 2 "1/4 ## A"; sr_row dev true 3 "4/4 ## D"
  sr_frow tea 4 "1/4 ## A" "<your seat file>"; }
# SRC10: SRC9's tail-less tea row (a path cut at a blank) plus an UNCITED tea field-row naming architecture-tea-1.md ->
# the seat is a field seat, so the tail-less row (field-less precedence) cannot cover it: tea-1 refused by name.
sr_rows_c10() { SR_TS="$SR_POST"; sr_row architect true 1 "1/4 ## A"; sr_row dev true 2 "1/4 ## A"; sr_row dev true 3 "4/4 ## D"
  sr_frow tea 4 "1/4 ## A" "/a"
  printf '{"v":1,"ts":"%s","sprint":305,"role":"tea","role_contract_cited":false,"tool_use_id":"toolu_sf5","shard":"1/4 ## A","mark":"rendered","mark_file":"%s"}\n' "$SR_TS" "$SR_G/architecture-tea-1.md"; }
SRC6W="$(sr_fbuild "$SR_SPRE" 0 sr_rows_c6)"; SRC7W="$(sr_fbuild "$SR_SPRE" 0 sr_rows_c7)"; SRC8W="$(sr_fbuild "$SR_SPRE" 0 sr_rows_c8)"
# SRC11: tea-1's only row is a field-row whose mark_file the brief quoted (`"<path>"`) -> one pair of quotes stripped,
# the tail matches architecture-tea-1.md: covered, SOURCES rc 0.
sr_rows_c11() { SR_TS="$SR_POST"; sr_row architect true 1 "1/4 ## A"; sr_row dev true 2 "1/4 ## A"; sr_row dev true 3 "4/4 ## D"
  sr_frow tea 4 "1/4 ## A" "\\\"$SR_G/architecture-tea-1.md\\\""; }
SRC9W="$(sr_fbuild "$SR_SPRE" 0 sr_rows_c9)"; SRC10W="$(sr_fbuild "$SR_SPRE" 0 sr_rows_c10)"; SRC11W="$(sr_fbuild "$SR_SPRE" 0 sr_rows_c11)"
srdis() { [ "$RC" -eq 2 ] && has "$JO" "the sharded party round architecture's spawn-ledger rows disagree on K" && has "$JO" "at shard counts 4 9 with no single K" && ! has "$JO" "SOURCES:"; }
if [ -z "$SRC1W" ] || [ -z "$SRC2W" ] || [ -z "$SRC3W" ] || [ -z "$SRC4W" ] || [ -z "$SRC5W" ] || [ -z "$SRC5BW" ] || [ -z "$SRC6W" ] || [ -z "$SRC7W" ] || [ -z "$SRC8W" ] || [ -z "$SRC9W" ] || [ -z "$SRC10W" ] || [ -z "$SRC11W" ] || [ -z "$SR_LINE" ]; then
  bad "SRC: FIXTURE BROKEN -- a seat-file-row world could not be built"
else
  sr_drive "$JOIN" "$SRC1W"
  if sr4; then ok "SRC1: architecture's rows field-less and pre-install, requirements' post-install field-rows at the same roles, ordinals and K -> SEAT-ROWS: SKIP legacy-round architecture, rc 0"; B_SRC1=1
  else bad "SRC1: another round's field-rows dated or covered the cited round (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SRC2W"
  if sr8; then ok "SRC2: tea-1's only row names an absent file -> REFUSED rc 2 naming tea-1 alone, the row covering no other seat"; B_SRC2=1
  else bad "SRC2: a field-row naming an absent file covered a seat (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SRC3W"
  if sr2; then ok "SRC3: three seats by relative field-rows, tea-1 by a field-less row -> the field-less fallback covers tea-1, SOURCES rc 0"; B_SRC3=1
  else bad "SRC3: a field-less row beside field-rows no longer infers (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SRC4W"
  if sr8; then ok "SRC4: another round's tea-1 field-row at tea 1/4 -> architecture-tea-1 REFUSED rc 2 by name"; B_SRC4=1
  else bad "SRC4: a field-row covered a seat of another round (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SRC5W"
  if sr4; then ok "SRC5: every seat by its own pre-install field-row, seats committed pre-install -> SEAT-ROWS: SKIP legacy-round architecture"; B_SRC5=1
  else bad "SRC5: a round of pre-install field-rows was not legacy (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SRC5BW"
  if sr9; then ok "SRC5b: the same pre-install field-rows, seats committed after the install -> judged, all 4 REFUSED: a pre-install field-row covers nothing"; B_SRC5B=1
  else bad "SRC5b: a pre-install field-row covered its seat (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SRC6W"
  if sr2; then ok "SRC6: absolute ${SR_G} field-rows, the join under another JR_ROOT -> each matches its seat by tail, dated and covered, SOURCES rc 0"; B_SRC6=1
  else bad "SRC6: a field-row under a relocated root did not match its seat (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SRC7W"
  if sr2; then ok "SRC7: dev-1 named by its field-row and carrying a field-less row at K 9, its siblings at K 4 -> the field seat votes no K, SOURCES rc 0"; B_SRC7=1
  else bad "SRC7: a field seat's field-less row voted K (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SRC8W"
  if sr8; then ok "SRC8: a cited post-install dev field-row names architecture-tea-1.md -> tea-1 REFUSED rc 2 by name: a field-row covers only its own role's seat"; B_SRC8=1
  else bad "SRC8: a field-row of another role covered tea-1 (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SRC9W"
  if sr2; then ok "SRC9: tea-1's only row carries a tail-less mark_file -> read as a field-less row, tea-1 covered, SOURCES rc 0"; B_SRC9=1
  else bad "SRC9: a tail-less mark_file row matched nothing (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SRC10W"
  if sr8; then ok "SRC10: a tail-less tea row beside an uncited tea field-row naming tea-1 -> tea-1 REFUSED rc 2: the tail-less row cannot cover a field seat"; B_SRC10=1
  else bad "SRC10: a tail-less row covered a seat a field-row names (rc=$RC): $(head -3 "$JO")"; fi
  sr_drive "$JOIN" "$SRC11W"
  if sr2; then ok "SRC11: tea-1's field-row carries a double-quoted mark_file -> the quotes stripped, it matches its seat, SOURCES rc 0"; B_SRC11=1
  else bad "SRC11: a quoted mark_file did not match its seat (rc=$RC): $(head -3 "$JO")"; fi
  # SRmF1 (contract M1): field-rows fall into inference -> SRC1's architecture seats match requirements' post-install rows
  # and the round is judged. SRC3 still passes.
  if pc_break srmf1 '      | if $m != null then' '      | if false then'; then
    sr_drive "$PCB/srmf1/join-remediator-shards.sh" "$SRC1W"; _a=1; sr4 && _a=0; has "$JO" "self-probe failed" && _a=0
    sr_drive "$PCB/srmf1/join-remediator-shards.sh" "$SRC3W"; _b=1; sr2 && _b=0
    mrow SRmF1 "SRC1=$_a" "SRC3=$_b"
    if [ "$_a" = 1 ] && [ "$_b" = 0 ]; then mutant_killed "$(( ${B_SRC1:-0} && ${B_SRC3:-0} ))" SRmF1 "SRmF1 field-rows fall into inference: KILLED by [SRC1] -- another round's rows judged the legacy round; SRC3 still passes"
    else bad "SRmF1: SURVIVED or entangled -- SRC1=$_a SRC3=$_b (want 1 0)"; fi
  else bad "SRmF1: FIXTURE STALE -- the field-row branch matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"; fi
  # SRmF2: a pre-install field-row covers its seat -> SRC5b passes. SRC5 (legacy) still skips.
  if pc_break srmf2 'if ($4 == "1" && (INST == "" || $5 == "-1" || $5 + 0 >= INST + 0) && parse($2) && PS == $3) MC[$2] = 1' 'if ($4 == "1" && parse($2) && PS == $3) MC[$2] = 1'; then
    sr_drive "$PCB/srmf2/join-remediator-shards.sh" "$SRC5BW"; _a=1; sr9 && _a=0; has "$JO" "self-probe failed" && _a=0
    sr_drive "$PCB/srmf2/join-remediator-shards.sh" "$SRC5W"; _b=1; sr4 && _b=0
    mrow SRmF2 "SRC5b=$_a" "SRC5=$_b"
    if [ "$_a" = 1 ] && [ "$_b" = 0 ]; then mutant_killed "$(( ${B_SRC5B:-0} && ${B_SRC5:-0} ))" SRmF2 "SRmF2 a pre-install field-row covers: KILLED by [SRC5b] -- the judged round's seats joined their old rows; SRC5 still skips"
    else bad "SRmF2: SURVIVED or entangled -- SRC5b=$_a SRC5=$_b (want 1 0)"; fi
  else bad "SRmF2: FIXTURE STALE -- the field-row coverage line matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"; fi
  # SRmF3: a field-row no longer dates its seat -> SRC6 falls to its pre-install seat commits and reads legacy. SRC3
  # (dated by tea-1's field-less row) still passes.
  if pc_break srmf3 'if (FB[i] in MF) v = (FB[i] in MT) ? MT[FB[i]] : -1; else' 'if (FB[i] in MF) v = -1; else'; then
    sr_drive "$PCB/srmf3/join-remediator-shards.sh" "$SRC6W"; _a=0; ! sr2 && has "$JO" "SEAT-ROWS: SKIP legacy-round architecture" && _a=1
    sr_drive "$PCB/srmf3/join-remediator-shards.sh" "$SRC3W"; _b=1; sr2 && _b=0
    mrow SRmF3 "SRC6=$_a" "SRC3=$_b"
    if [ "$_a" = 1 ] && [ "$_b" = 0 ]; then mutant_killed "$(( ${B_SRC6:-0} && ${B_SRC3:-0} ))" SRmF3 "SRmF3 a field-row dates nothing: KILLED by [SRC6] -- the round fell to its seat commits and read legacy; SRC3 still passes"
    else bad "SRmF3: SURVIVED or entangled -- SRC6=$_a SRC3=$_b (want 1 0)"; fi
  else bad "SRmF3: FIXTURE STALE -- the field-row date line matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"; fi
  # SRmF4: a field seat enters K inference -> SRC7's dev-1 votes K 9 against its siblings' 4 and the round is refused as
  # a K disagreement. SRC3 (field seats with no field-less row) still passes.
  if pc_break srmf4 'if (FB[i] in MF) continue' ''; then
    sr_drive "$PCB/srmf4/join-remediator-shards.sh" "$SRC7W"; _a=0; srdis && _a=1
    sr_drive "$PCB/srmf4/join-remediator-shards.sh" "$SRC3W"; _b=1; sr2 && _b=0
    mrow SRmF4 "SRC7=$_a" "SRC3=$_b"
    if [ "$_a" = 1 ] && [ "$_b" = 0 ]; then mutant_killed "$(( ${B_SRC7:-0} && ${B_SRC3:-0} ))" SRmF4 "SRmF4 a field seat votes K: KILLED by [SRC7] -- the round was refused as a K disagreement at 4 9; SRC3 still passes"
    else bad "SRmF4: SURVIVED or entangled -- SRC7=$_a SRC3=$_b (want 1 0)"; fi
  else bad "SRmF4: FIXTURE STALE -- the field-seat K skip matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"; fi
  # SRmF5: the role comparison dropped -> SRC8's dev field-row covers tea-1. SRC6 (every field-row of its own role) still passes.
  if pc_break srmf5 ' && parse($2) && PS == $3) MC' ') MC'; then
    sr_drive "$PCB/srmf5/join-remediator-shards.sh" "$SRC8W"; _a=1; sr8 && _a=0; has "$JO" "self-probe failed" && _a=0
    sr_drive "$PCB/srmf5/join-remediator-shards.sh" "$SRC6W"; _b=1; sr2 && _b=0
    mrow SRmF5 "SRC8=$_a" "SRC6=$_b"
    if [ "$_a" = 1 ] && [ "$_b" = 0 ]; then mutant_killed "$(( ${B_SRC8:-0} && ${B_SRC6:-0} ))" SRmF5 "SRmF5 a field-row covers any role's seat: KILLED by [SRC8] -- the dev row covered tea-1; SRC6 still passes"
    else bad "SRmF5: SURVIVED or entangled -- SRC8=$_a SRC6=$_b (want 1 0)"; fi
  else bad "SRmF5: FIXTURE STALE -- the field-row role comparison matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"; fi
  # SRmF6: a tail-less mark_file row matches nothing again -> SRC9's tea-1 has no row and is refused. SRC3 (tea-1's row
  # carries no mark_file) still passes.
  if pc_break srmf6 'select(.sprint == $s and .role_contract_cited == true and (.shard | type) == "string")' 'select((.mark_file | type) != "string" and .sprint == $s and .role_contract_cited == true and (.shard | type) == "string")'; then
    sr_drive "$PCB/srmf6/join-remediator-shards.sh" "$SRC9W"; _a=0; sr8 && _a=1
    sr_drive "$PCB/srmf6/join-remediator-shards.sh" "$SRC3W"; _b=1; sr2 && _b=0
    mrow SRmF6 "SRC9=$_a" "SRC3=$_b"
    if [ "$_a" = 1 ] && [ "$_b" = 0 ]; then mutant_killed "$(( ${B_SRC9:-0} && ${B_SRC3:-0} ))" SRmF6 "SRmF6 a tail-less mark_file row matches nothing: KILLED by [SRC9] -- tea-1 lost its only row and was refused; SRC3 still passes"
    else bad "SRmF6: SURVIVED or entangled -- SRC9=$_a SRC3=$_b (want 1 0)"; fi
  else bad "SRmF6: FIXTURE STALE -- the field-less row select matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"; fi
  # SRmF7: the quote strip removed -> SRC11's basename keeps its closing quote, names no seat file, and tea-1 is refused.
  # SRC6 (unquoted field-rows) still passes.
  if pc_break srmf7 ' then .[1:-1] else . end)' ' then . else . end)'; then
    sr_drive "$PCB/srmf7/join-remediator-shards.sh" "$SRC11W"; _a=0; sr8 && _a=1
    sr_drive "$PCB/srmf7/join-remediator-shards.sh" "$SRC6W"; _b=1; sr2 && _b=0
    mrow SRmF7 "SRC11=$_a" "SRC6=$_b"
    if [ "$_a" = 1 ] && [ "$_b" = 0 ]; then mutant_killed "$(( ${B_SRC11:-0} && ${B_SRC6:-0} ))" SRmF7 "SRmF7 the mark_file quote strip removed: KILLED by [SRC11] -- the quoted row named no seat and tea-1 was refused; SRC6 still passes"
    else bad "SRmF7: SURVIVED or entangled -- SRC11=$_a SRC6=$_b (want 1 0)"; fi
  else bad "SRmF7: FIXTURE STALE -- the quote strip matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"; fi
  # SRmF8: the field seat's `continue` dropped from the final loop -> a COVERED field seat falls through to the
  # field-less join, finds no R row and is refused, so SRC6 (every seat a covered field seat) is refused. SRC10's
  # uncited field seat already printed its MISS and then consumes the tail-less R row, so its output is unchanged:
  # SRC10 is the twin, not the decider (measured: its verdict holds under the mutant).
  if pc_break srmf8 '"\t" SK[t] "\t" t; continue }' '"\t" SK[t] "\t" t }'; then
    sr_drive "$PCB/srmf8/join-remediator-shards.sh" "$SRC6W"; _a=1; sr2 && _a=0; has "$JO" "self-probe failed" && _a=0
    sr_drive "$PCB/srmf8/join-remediator-shards.sh" "$SRC10W"; _b=1; sr8 && _b=0
    mrow SRmF8 "SRC6=$_a" "SRC10=$_b"
    if [ "$_a" = 1 ] && [ "$_b" = 0 ]; then mutant_killed "$(( ${B_SRC6:-0} && ${B_SRC10:-0} ))" SRmF8 "SRmF8 a field seat falls through to the field-less join: KILLED by [SRC6] -- covered field seats with no field-less row were refused; SRC10 still refuses tea-1"
    else bad "SRmF8: SURVIVED or entangled -- SRC6=$_a SRC10=$_b (want 1 0)"; fi
  else bad "SRmF8: FIXTURE STALE -- the field-seat continue matched nothing or more than one line in $JOIN; re-anchor it, never relax the assertion"; fi
fi

# PLAIN: rule 9 -- a plain (push) run prints no matrix-only cell; --matrix prints one row per mutant.
if [ "$MATRIX" = 1 ]; then echo "  (matrix mode: $N_MROWS MATRIX row(s) printed)"
elif [ "$N_MROWS" -eq 0 ]; then ok "PLAIN: a plain run printed no matrix-only cell"
else bad "PLAIN: a plain run printed $N_MROWS matrix row(s)"; fi
echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
