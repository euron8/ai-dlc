#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# adversarial-shard-merge/run.sh -- merge-adversarial-shards.sh, the JOIN that turns one
# adversary per story ordinal plus one cross-story adversary into the ONE pass file every gate
# reads. The behavioural arms only: the mutation battery that once proved each of them can fail
# has been retired; the predicates and worlds live in `lib.sh` beside this file. The battery mutates copies of core's own scripts, which a
# consumer cannot edit, so the consumer keeps every correctness arm and loses only that proof.
# The hard-coded `@` expectations go red in a consumer whose pair readers were carried at their pre-`@`
# version; read such a red as "a reader is carried", not as a merge or join regression.
#
# WHY A FIXTURE OF ITS OWN. No existing fixture owns this script: check-24-adversarial-convergence
# owns the convergence validator the merge's OUTPUT feeds, and it seeds pass files directly, so it
# never runs the merge. The merge is a new program with its own refusals, and its one
# load-bearing claim -- the merged verdict is RECOMPUTED from the summed residue, never taken from
# a shard -- is invisible to anything that only reads a finished pass file.
#
# THE DISCRIMINATING INPUT (B3). Three per-ordinal shards each holding 2 blocking MAJOR, each
# honestly stamped EXIT_CONDITION_MET because 2 is under the ceiling, and a clean cross shard. The
# artifact holds 6. A merge that took the worst shard verdict, or any one shard verdict, says MET;
# the recomputed verdict is NOT_MET, and the convergence validator must ACCEPT the merged file
# (--cycle-state CONTINUE, exit 0) rather than refuse it as unparseable.
#
# SEEDS ARE REAL CONSUMER BYTES, TRIMMED. `seed.<basename>` are the first 12 lines of three story
# files from one reference-consumer sprint, chosen because their LC_ALL=C order puts two
# NON-`story-` files (`192-ff-...`, `bug-...`) at ordinals 1 and 2: an ordinal key that only
# understood `story-<n>-` would refuse or mis-key them. `seed.finding-headings.txt` is the heading
# list of a real multi-story adversarial pass; every shard finding carries one of those titles.
# Only the severity word and the `stories:` line are added, because the real pass predates the
# shard grammar (see arm R6, which runs a heading exactly as the real pass wrote it).
#
# SECTION MODE (--document, arms D0-D6). `seed.doc-test-strategy.md` is a real consumer
# single-file artifact that partition-document.sh --map splits into three parts, and
# `seed.doc-serial-epics.md` a real one it calls SERIAL; D0 reads both off --map rather than
# assuming them. D2's seed is the one the receipt could not build: a finding carrying ONE
# `sections:` line and a `stories:` line, so the one-citation count passes it and only the axis
# guard refuses -- the mutant CM-axis-guard-gone asserts that, with the guard gone, the same seed merges. D4's
# shard names a byte-identical COPY of the document, so the sha check passes and only the path
# check refuses; D3 is the mirror, the right path with other bytes' sha.
# `seed.files-b3-merged.expected` is the B3 output of the merge BEFORE section mode existed
# (origin/main at dd7e40ad), so D6 holds files mode to its old bytes rather than to whatever the
# current merge prints. Regenerated once for the cross groups (BL-464): K=3 now owes cross-1..3,
# and the diff against the earlier golden is confined to the cross headers, the shard count and
# the two id lines -- every ordinal shard's body is byte-identical. Regenerated again when the
# dispatch ids became DERIVED from the harness records: the diff is confined to the same two id
# lines (lines 118-119), now carrying the ids lib.sh's hr_ids derives from each shard's dir and name.
#
# Every arm that scores a merge calls its predicate as `p_<name> "$MERGE"` at the start of a
# line.
#
# MUTANTS. Each is a copy of the merge's whole sibling set (or of the provenance schema) with one anchor
# changed. PER PUSH a mutant runs its DECIDING arm, which must FAIL, and one TWIN, an arm the measured matrix
# shows GREEN for it, which must PASS; the kill is emitted through mutant_killed behind the same-run base pass
# of both arms and of the unmutated copy (MX0). `--matrix` scores MX0 and every mutant against EVERY arm and
# prints one MATRIX row per cell. The matrix is re-measured as .claude/rules/fixture-mutants.md clause 2 ("One
# run per distinct state") requires. The matrix is
# not run through hermetic-run.sh, which forwards no argument. Worlds are per-use: the merge refuses a world
# whose write-ledger rows name another root, so no world is shared across arms or mutants.
#
# MUTANT-MATRIX-CONTROL MX0 why=the unmutated copy of the merge's sibling set must trip no arm; it is the base pass every kill is gated on
# MUTANT-MATRIX m-k2only decides=X1 twins=X4
# MUTANT-MATRIX m-nomix decides=X4 twins=A1
# MUTANT-MATRIX RM-A decides=RS1 twins=A1
# MUTANT-MATRIX RM-B decides=CH2 twins=A1
# MUTANT-MATRIX CM-verdict-from-shards decides=A1 twins=RS1
# MUTANT-MATRIX CM-ordinal-story-only decides=M0 twins=D3
# MUTANT-MATRIX CM-axis-guard-gone decides=D2 twins=D3
# MUTANT-MATRIX CM-doc-path-unchecked decides=D4 twins=D3
# MUTANT-MATRIX CM-doc-sha-unchecked decides=D3 twins=D4
# MUTANT-MATRIX CM-merged-unparseable decides=A1 twins=RS1
# MUTANT-MATRIX CM-major-count-unchecked decides=FG2 twins=A1
# MUTANT-MATRIX CM-other-root-not-refused decides=TR1 twins=A1
# MUTANT-MATRIX CM-serial-not-refused decides=D5 twins=D3
# MUTANT-MATRIX CM-files-bytes-moved decides=D6 twins=A1
# MUTANT-MATRIX FI-m1-keyless-accepted decides=FI1 twins=FI2
# MUTANT-MATRIX FI-m2-no-digit decides=FI1 twins=FI2
# MUTANT-MATRIX FI-m3-dup-accepted decides=FI3a twins=FI1
# MUTANT-MATRIX FI-m4-both-axes decides=FIE twins=FI1
# MUTANT-MATRIX FI-m5-no-bracket-strip decides=FI2 twins=FI1
# MUTANT-MATRIX FI-m6-dup-raw decides=FI3b twins=FI3a
# MUTANT-MATRIX FI-m8-open-fence-accepted decides=FIF twins=FI1
# MUTANT-MATRIX FI-m9-shard-heading-accepted decides=FIS twins=FI1
# MUTANT-MATRIX FI-m10-own-ordinal-raw decides=FISa twins=FIS
# MUTANT-MATRIX BM-1 decides=B726B twins=B726H
# MUTANT-MATRIX BM-2 decides=B726C twins=B726H
# MUTANT-MATRIX BM-3 decides=B726F twins=B726B
# MUTANT-MATRIX BM-4 decides=B726H twins=B726B
# MUTANT-MATRIX PM1 decides=P1 twins=PBARE
# MUTANT-MATRIX DW-M1-same-relaxed decides=RR6a,RR3,RR6c twins=RR6b
# MUTANT-MATRIX DW-M2-every-same decides=RR3 twins=RR6b
# MUTANT-MATRIX DW-M3-tie-admits decides=RR6c twins=RR6b
# MUTANT-MATRIX DW-M4-no-site-b decides=RR6n,RR6a,RR6c twins=RR6b
# MUTANT-MATRIX DW-M5-draft-writer decides=RR6f twins=RR6b
# MUTANT-MATRIX DW-M6-dw-before-out decides=RR6d twins=RR6b
# MUTANT-MATRIX DW-M7-draft-straddle-narrowed decides=RR6g twins=RR6b
# MUTANT-MATRIX DW-M8-nlst-exact-only decides=RR6g twins=RR6b
# MUTANT-MATRIX-DYNAMIC mut-name-argument why=mut() emits mutant_killed with the name it is called with; every name it is called with is a literal row of this block
# MUTANT-MATRIX KMb-inst decides=KEps_inst twins=K2vac_inst
# MUTANT-MATRIX KMc-core decides=KEsch_core twins=K2vac_core
# MUTANT-MATRIX KEM-inst decides=KEps_inst twins=KEvac_inst
# MUTANT-MATRIX KEM-core decides=KEsch_core twins=KEvac_core
# MUTANT-MATRIX DV-full-map decides=DV4 twins=A1
# MUTANT-MATRIX DV-joined-record-only decides=DV2 twins=DV5
# MUTANT-MATRIX DV-open-findings-dropped decides=DV3 twins=DV2
# MUTANT-MATRIX DV-files-key-ordinal decides=DV4 twins=DV3
# MUTANT-MATRIX DV-sections-silent-full decides=DV4D twins=DV3
# MUTANT-MATRIX DV-reason-blank decides=PCE twins=DV5
# MUTANT-MATRIX DV-doc-narrow-consumed decides=DVRS twins=PCS
# MUTANT-MATRIX DV-subj-narrow-consumed decides=DVRSS twins=PC1
# MUTANT-MATRIX PC-ordinal-join decides=PC1 twins=DV3
# MUTANT-MATRIX PC-cite-by-ordinal decides=DV4D twins=PC1
# MUTANT-MATRIX PC-dup-presence decides=PCD twins=PC1
# MUTANT-MATRIX PC-subject-digest-only decides=PCS2 twins=PC1
# MUTANT-MATRIX PC-pred-nolist-narrows decides=PCKa twins=DV5
# MUTANT-MATRIX PC-own-nolist-narrows decides=PCKb twins=DV5
# MUTANT-MATRIX PC-malformed-narrows decides=PCKc twins=DV5
# MUTANT-MATRIX PC-count-unchecked decides=PCKd twins=DV5
# MUTANT-MATRIX PC-legacy-narrows decides=PCE twins=DV5
# MUTANT-MATRIX PC-no-table-run decides=PCT2,PCT,PCSR twins=PC1
# MUTANT-MATRIX PC-run-widen-neighbour decides=PCC twins=PCT2
# MUTANT-MATRIX PC-pred-norun-narrows decides=PCKe twins=DV5
# MUTANT-MATRIX PC-own-norun-narrows decides=PCKf twins=DV5
# MUTANT-MATRIX PC-run-malformed-narrows decides=PCKg twins=DV5
# MUTANT-MATRIX PC-remerge-strict decides=PCR twins=DV3
# MUTANT-MATRIX PC-prun-print-as-you-go decides=PCKm twins=DV5
# MUTANT-MATRIX PC-moved-tab-ifs decides=PCMV twins=PC1
# MUTANT-MATRIX PC-scoped-map-continue decides=PCN2 twins=PC1
# MUTANT-MATRIX VAC-doc-probe-gone decides=NDP twins=DV2
# MUTANT-MATRIX VAC-ceiling-nd decides=NDC twins=DV2
# MUTANT-MATRIX DV-narrow-on-unread decides=DV5 twins=DV2
# MUTANT-MATRIX DV-gate-supersets-only decides=DVRS twins=DV2
# MUTANT-MATRIX DV-notarize-dispatched-only decides=DV10 twins=DV2
# MUTANT-MATRIX DV-literal-m-minus-1 decides=DV10 twins=DV2
# MUTANT-MATRIX CSM-agree decides=CS1 twins=A1
# MUTANT-MATRIX CSM-self decides=CS1 twins=A1
# MUTANT-MATRIX CSM-cite decides=CS2 twins=A1
# MUTANT-MATRIX CSM-artifact decides=CS3 twins=A1
# MUTANT-MATRIX CSM-header decides=CS4 twins=A1
# MUTANT-MATRIX CSM-skip decides=CS5 twins=A1
# MUTANT-MATRIX CSM-bytes decides=CS6 twins=A1
# MUTANT-MATRIX CSW-call decides=CS8 twins=CS1
# MUTANT-MATRIX CSW-relay decides=CS8 twins=CS1
# MUTANT-MATRIX CSM-early decides=CS9 twins=A1
# MUTANT-MATRIX CSM-order decides=CS9 twins=A1
# MUTANT-MATRIX CSM-docsel decides=CS10 twins=A1
# MUTANT-MATRIX CSM-noblock decides=CS11 twins=A1
# MUTANT-MATRIX CSM-docfb decides=CS13 twins=CS14
# MUTANT-MATRIX CSM-flagswap decides=CS12 twins=A1
# MUTANT-MATRIX CSM-flagglob decides=CS12 twins=A1
# MUTANT-MATRIX-REMEASURE bash core/fixtures/adversarial-shard-merge/run.sh --matrix
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="adversarial-shard-merge"
[ -f "$HERE/lib.sh" ] || { echo "FIXTURE BROKEN: $HERE/lib.sh is absent; nothing was asserted" >&2; exit 2; }
# --matrix scores every mutant against every arm. Two optional narrowings, each a comma list, each legal only with
# --matrix: --mutants=<m>,... scores only those mutants (the rest are neither built nor scored), --arms=<arm>,...
# scores each against only those arms (MX0 included). Both go through the same sc_run and mx_cells as the full
# matrix; a scored mutant whose deciding or twin arm is outside --arms= has its cells recorded and its kill NOT
# judged. An unknown name in either list is FIXTURE ERROR. The plain run reads neither.
# --jobs=<n> (--matrix only, default 8) scores that many matrix rows (MX0 and each mutant) at once, each in its own
# worker (mx_enqueue); once every worker has answered, the rows print in the serial run's order, each row's kill
# line after its cells, all of them after the K section rather than interleaved with it. --jobs=1 is the serial
# matrix, every row scored inline as before. Ctrl-C does not reach the workers (a non-interactive shell's background
# jobs ignore SIGINT): stop a --matrix by its process group, with SIGTERM.
MATRIX=0; MATRIX_ROWS=0; MX_MUT_SEL=""; MX_ARM_SEL=""; MX_JOBS=""
for _a in "$@"; do
  case "$_a" in
    --matrix) MATRIX=1 ;;
    --mutants=?*) MX_MUT_SEL="${_a#--mutants=}"; MX_MUT_SEL=" ${MX_MUT_SEL//,/ } " ;;
    --arms=?*) MX_ARM_SEL="${_a#--arms=}"; MX_ARM_SEL="${MX_ARM_SEL//,/ }" ;;
    --jobs=[1-9]|--jobs=[1-9][0-9]) MX_JOBS="${_a#--jobs=}" ;;
    *) echo "FIXTURE ERROR: unknown argument '$_a' (usage: run.sh [--matrix [--mutants=<m>,...] [--arms=<arm>,...] [--jobs=<1-99>]])" >&2; exit 2 ;;
  esac
done
if [ "$MATRIX" -eq 0 ] && [ -n "$MX_MUT_SEL$MX_ARM_SEL$MX_JOBS" ]; then
  echo "FIXTURE ERROR: --mutants=, --arms= and --jobs= shape --matrix and mean nothing without it" >&2; exit 2
fi
MX_JOBS="${MX_JOBS:-8}"
# Every arm asks the merge IN PROCESS (lib.sh mx: the merge sourced, merge_main called in a subshell); the
# CLI is driven once per distinct outcome by the EQ arms below, each byte-compared with its in-process twin.
ASM_RUN=mx
# Each world shape is built once and copied per use (lib.sh wc_get); WC0 below holds a copy to a fresh build.
ASM_WCACHE=1
. "$HERE/lib.sh"
for _l in matrix.sh mutant.sh; do
  [ -f "$HERE/../lib/$_l" ] || { echo "FIXTURE ERROR: $HERE/../lib/$_l is absent; nothing was asserted" >&2; exit 2; }
  . "$HERE/../lib/$_l"
done
KOK=0; OKSET="|"
ok() { printf '  ok    %s\n' "$1"; OKSET="$OKSET${1%%:*}|"; } # records each passing arm label, so a mutant is gated on the same-run base pass
echo "HERMETIC-CONSUMED $MERGE"
echo "HERMETIC-CONSUMED core/fixtures/lib/matrix.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
# Every marked shard the arms merge is admitted by the merge's sibling content-seal.sh --admit-marker (BL-750).
echo "HERMETIC-CONSUMED core/scripts/content-seal.sh"

# ---------------------------------------------------------------------------------- the arms
echo "$NAME:"

# M0: the ordinal map covers every *.md, whatever its name, in C order.
p_m0() { # <merge> -> 0 iff --map keys the three real files, the two non-story- names included, in C order
  local d want; d="$(new_world)" || return 1
  map="$($ASM_RUN "$1" --map "$d")"
  want="$(printf '1\t192-ff-A-token-decimal-resolution.md\n2\tbug-192-il-accuracy.md\n3\tstory-1-rebalancer-il-accuracy.md')"
  [ "$map" = "$want" ]
}
if p_m0 "$MERGE"; then
  ok "M0: --map keys all three real files by ordinal, the two NON-story- names (192-ff-, bug-) included, in LC_ALL=C order"
else
  bad "M0: --map printed [$map], not the three ordinals over the real listing"
fi

# EQ: THE SEAM. Every arm below asks the merge in process (mx). Here each DISTINCT CLI OUTCOME runs once end to
# end and once in process on the SAME world, and stdout, stderr, the exit code and the pass file it writes must
# be byte-identical; the kept end-to-end run per outcome is the CLI half. The output is moved aside between the
# two halves, so both write it afresh. EQ0 then asserts the outcomes differ from each other.
eq_pair() { # <label> <shard dir or -> <args...> (@D is replaced by the shard dir) -> EQ_SAME, EQ_RC, $WORK/eq.<label>.*
  local lab="$1" d="$2" a o=""; shift 2
  local args=(); for a in "$@"; do args[${#args[@]}]="${a//@D/$d}"; done
  [ "$d" = - ] || o="$(out_of "$d")"
  bash "$MERGE" "${args[@]}" > "$WORK/eq.$lab.c.out" 2> "$WORK/eq.$lab.c.err"; echo $? > "$WORK/eq.$lab.c.rc"
  [ -n "$o" ] && [ -f "$o" ] && mv "$o" "$WORK/eq.$lab.c.pass"
  mx "$MERGE" "${args[@]}" > "$WORK/eq.$lab.i.out" 2> "$WORK/eq.$lab.i.err"; echo $? > "$WORK/eq.$lab.i.rc"
  [ -n "$o" ] && [ -f "$o" ] && mv "$o" "$WORK/eq.$lab.i.pass"
  EQ_SAME=1; for a in out err rc; do cmp -s "$WORK/eq.$lab.c.$a" "$WORK/eq.$lab.i.$a" || EQ_SAME=0; done
  if [ -f "$WORK/eq.$lab.c.pass" ] || [ -f "$WORK/eq.$lab.i.pass" ]; then cmp -s "$WORK/eq.$lab.c.pass" "$WORK/eq.$lab.i.pass" || EQ_SAME=0; fi
  EQ_RC="$(cat "$WORK/eq.$lab.c.rc")"
}
eq_arm() { # <label> <want rc> <token in stdout or stderr> <describe> <shard dir or -> <args...>
  local lab="$1" want="$2" tok="$3" what="$4"; shift 4
  eq_pair "$lab" "$@"
  if [ "$EQ_SAME" = 1 ] && [ "$EQ_RC" = "$want" ] && grep -qF -- "$tok" "$WORK/eq.$lab.c.out" "$WORK/eq.$lab.c.err"; then
    ok "$lab: $what -- the CLI and merge_main in process answer byte-identically (stdout, stderr, rc $want, pass file)"
  else bad "$lab: $what -- same=$EQ_SAME rc=$EQ_RC (want $want, '$tok'): $(head -2 "$WORK/eq.$lab.c.out") | $(head -2 "$WORK/eq.$lab.i.out")"; fi
}
eqd="$(b3_world)"
eq_arm EQ1 0 "verdict=EXIT_CONDITION_NOT_MET shards=6" "files mode MERGED (B3)" "$eqd" @D
[ -f "$WORK/eq.EQ1.c.pass" ] || bad "EQ1: FIXTURE BROKEN -- the CLI merge wrote no pass file, so the pass-file comparison compared nothing"
eqr="$(b3_world)"; rm -f "$eqr/1.md"
eq_arm EQ2 2 "REFUSED: " "files mode REFUSED (ordinal 1 missing)" "$eqr" @D
eq_arm EQ3 0 "192-ff-A-token-decimal-resolution.md" "--map" "$eqd" --map @D
eq_arm EQ4 0 "DRY-RUN: clean" "--dry-run clean" "$eqd" --dry-run @D
eq_arm EQ5 2 "REFUSED: " "--dry-run refusing" "$eqr" --dry-run @D
eq_arm EQ6 0 "@" "--pair-sep" - --pair-sep
sed '/^verdict:/d' "$eqd/1.md" > "$WORK/eq-nov.md"
eq_arm EQ7 1 "REFUSED: " "--check-header refusing" - --check-header "$WORK/eq-nov.md" --axis convergence
eq_pair EQ8 - --check-header "$eqd/1.md" --axis convergence
if [ "$EQ_SAME" = 1 ] && [ "$EQ_RC" = 0 ] && [ ! -s "$WORK/eq.EQ8.c.out" ]; then ok "EQ8: --check-header passing -- byte-identical, rc 0, nothing printed"
else bad "EQ8: --check-header passing: same=$EQ_SAME rc=$EQ_RC"; fi
eqw="$(HR_BOUND=0 b3_world)"; HR_BOUND=0 shard "$eqw" 1 2 EXIT_CONDITION_MET 1 "" 2026-08-24T13:00:00Z
eq_arm EQ9 0 "LEGACY" "a LEGACY WARN on stderr beside a MERGED line" "$eqw" @D
eq_arm EQ10 2 "usage: " "a usage refusal" - --document
eq_arm EQ11 0 "USAGE" "--help" - --help
# WC0: a COPIED world is the world a fresh build makes. eqd above was the first b3 build (the template); a copy
# and a fresh build each merge, and the two pass files and MERGED lines (the root aside) must be byte-identical,
# and the copy's ledger must name no other world's root.
wcc="$(b3_world)"; wcf="$(b3_world_build)"
mx "$MERGE" "$wcc" > "$WORK/wc.c" 2>&1; wcrc=$?; mx "$MERGE" "$wcf" > "$WORK/wc.f" 2>&1; wfrc=$?
wcr="$(dirname "$(hr_state "$wcc/1.md")")"; wce="$(dirname "$(hr_state "$eqd/1.md")")"
if [ "$wcc" != "$eqd" ] && [ "$wcrc" = 0 ] && [ "$wfrc" = 0 ] && cmp -s "$(out_of "$wcc")" "$(out_of "$wcf")" \
   && ! grep -qF "/${wce##*/}" "$wcr/_bmad-output/planning-artifacts/.artifact-writes.jsonl" \
   && grep -qF "/${wcr##*/}\"" "$wcr/_bmad-output/planning-artifacts/.artifact-writes.jsonl"; then
  ok "WC0: a copied B3 world merges to the pass file a fresh build merges to, byte for byte, and its ledger names its own root only"
else bad "WC0: the copied world (rc=$wcrc) and a fresh build (rc=$wfrc) differ, or its ledger names the template's root: $(head -1 "$WORK/wc.c")"; fi
eqx=1
for _p in "EQ1 EQ2" "EQ3 EQ4" "EQ4 EQ5" "EQ7 EQ8" "EQ1 EQ9"; do
  set -- $_p
  cmp -s "$WORK/eq.$1.c.out" "$WORK/eq.$2.c.out" && cmp -s "$WORK/eq.$1.c.err" "$WORK/eq.$2.c.err" && eqx=0
done
[ "$eqx" = 1 ] && ok "EQ0: each refusing outcome differs from its passing twin (EQ1/EQ2, EQ4/EQ5, EQ7/EQ8), and the mode outcomes from each other" \
  || bad "EQ0: two outcomes the EQ arms call distinct printed identical bytes; the equivalence pairs prove nothing"

# The worlds must differ from each other where the arms say they do, or the pair proves nothing.
d1="$(b3_world)"; d2="$(clean_world)"
if cmp -s "$d1/1.md" "$d2/1.md"; then bad "W0: FIXTURE BROKEN -- the B3 and clean worlds seed byte-identical shard 1"
else ok "W0: the B3 and clean worlds differ in shard bytes (count and stamped verdict), so the pair can split"; fi
n_met="$(grep -l '^verdict: EXIT_CONDITION_MET$' "$d1"/1.md "$d1"/2.md "$d1"/3.md | grep -c .)" || n_met=0
[ "$n_met" -eq 3 ] && ok "W1: every B3 shard stamps EXIT_CONDITION_MET (a worst-shard merge would say MET)" \
  || bad "W1: FIXTURE BROKEN -- only $n_met of 3 B3 shards stamp MET, so B3 no longer discriminates"

p_b3 "$MERGE" && ok "A1: B3 (3 shards x 2 blocking MAJOR, each stamped MET) merges NOT_MET with blocking=6, shards=4 beside a repair dir, and --cycle-state reads CONTINUE" \
  || bad "A1: the B3 input did not merge to a recomputed NOT_MET accepted by the convergence validator (rc=$RC): $(cat "$MO") $(cat "$CO" 2>/dev/null)"
p_clean "$MERGE" && ok "A2: every shard stamped NOT_MET, summed blocking 3 = the ceiling -> merged MET and CONVERGED (the mirror of A1)" \
  || bad "A2: the clean set did not merge to MET/CONVERGED (rc=$RC): $(cat "$MO")"
p_ceiling "$MERGE"; r=$?
if [ "$r" -eq 2 ]; then bad "A3: FIXTURE STALE -- MAJOR_EXIT_CEILING=3 is not a line of the convergence validator, so the ceiling copy changed nothing"
elif [ "$r" -eq 0 ]; then ok "A3: with the sibling's MAJOR_EXIT_CEILING at 6 the SAME B3 input merges MET (ceiling=6) -- the ceiling is read, not restated"
else bad "A3: a sibling ceiling of 6 did not move the B3 merge to MET: $(cat "$MO")"; fi
p_miss_ord "$MERGE"   && ok "R1: ordinal 1 (a non-story- file) with no shard -> REFUSED 'is missing', exit 2, nothing written" || bad "R1: a missing ordinal shard was not refused cleanly (rc=$RC): $(cat "$MO")"
p_miss_cross "$MERGE" && ok "R2: cross-2.md of the three cross groups absent -> REFUSED 'shard cross-2 is missing', exit 2, nothing written" || bad "R2: a missing cross shard was not refused cleanly (rc=$RC): $(cat "$MO")"
p_dup "$MERGE"        && ok "R3: 1.md beside 01.md -> REFUSED 'delivered more than once', exit 2, nothing written" || bad "R3: a duplicate shard was not refused cleanly (rc=$RC): $(cat "$MO")"
p_partition "$MERGE"  && ok "R4: a per-ordinal finding citing two stories, and a cross finding citing one, each REFUSED, nothing written" || bad "R4: a partition violation was not refused cleanly (rc=$RC): $(cat "$MO")"
p_ms "$MERGE"         && ok "A4: shards stamped 15:00:19.497Z and 15:00:19Z merge, the merged invoked_at is 15:00:19Z (the true earliest, not the raw-string least), and --cycle-state accepts it (exit 0)" \
  || bad "A4: a millisecond-stamped shard did not merge to the true-earliest invoked_at (rc=$RC): $(cat "$MO") $(cat "$CO" 2>/dev/null)"
p_sha "$MERGE"        && ok "R5: a shard notarizing another story's sha -> REFUSED 'reviewed other bytes', exit 2, nothing written" || bad "R5: a sha mismatch was not refused cleanly (rc=$RC): $(cat "$MO")"

# ---- section mode. The seeds must reach the branches they are named for, or every D arm below
# asserts about a world that cannot express its defect.
DS0="$(new_doc_world)"; DS1="$(new_doc_world seed.doc-serial-epics.md)"
n_parts="$(bash "$PARTITION" --map "$(doc_of "$DS0")" | grep -c .)" || n_parts=0
bash "$PARTITION" --map "$(doc_of "$DS1")" > "$WORK/serial.map" 2>&1; r_serial=$?
if [ "$n_parts" -eq 3 ] && [ "$r_serial" -eq 3 ] && has "$WORK/serial.map" "SERIAL:"; then
  ok "D0: the document seed partitions into 3 parts and the SERIAL seed exits 3 with SERIAL: (both read from partition-document.sh --map, never assumed)"
else
  bad "D0: FIXTURE BROKEN -- the document seed maps to $n_parts part(s) (want 3) and the SERIAL seed exited $r_serial (want 3); the D arms cannot discriminate"
fi
p_doc_b3 "$MERGE" && ok "D1: three section shards x 2 MAJOR, each stamped MET, merge NOT_MET major=6; ONE artifact_sha equal to the document's; tool_use_id = cross-1's; a shard_wall entry per shard (cross-1..3 included); the convergence validator reads critical=0 major=6" \
  || bad "D1: the section B3 did not merge to a recomputed NOT_MET with one artifact_sha read 0/6 by the validator (rc=$RC): $(cat "$MO") $(grep -m1 'major=' "$CO" 2>/dev/null)"
p_doc_axis "$MERGE" && ok "D2: a finding carrying ONE sections: line AND a stories: line -> REFUSED by the axis guard (the one-citation count passes it), nothing written" \
  || bad "D2: a finding citing both axes was not refused by the axis guard (rc=$RC): $(cat "$MO")"
p_doc_sha "$MERGE" && ok "D3: a section shard notarizing other bytes at the right path -> REFUSED 'reviewed other bytes', nothing written" \
  || bad "D3: a whole-document sha mismatch was not refused cleanly (rc=$RC): $(cat "$MO")"
p_doc_path "$MERGE" && ok "D4: a section shard naming a byte-identical COPY of the document -> REFUSED 'reviewed another file' (the sha passes, the path does not), nothing written" \
  || bad "D4: an artifact path other than --document was not refused cleanly (rc=$RC): $(cat "$MO")"
p_doc_serial "$MERGE" && ok "D5: --document on a document partition-document.sh calls SERIAL -> REFUSED with its SERIAL: reason, nothing written" \
  || bad "D5: a SERIAL document was not refused cleanly (rc=$RC): $(cat "$MO")"
p_files_golden "$MERGE" && ok "D6: files mode on B3 is byte-identical to seed.files-b3-merged.expected, the output of the merge before section mode existed" \
  || bad "D6: files-mode output moved from the pre-section-mode golden (rc=$RC): $(cat "$MO")"

# ---- subject mode. U0: the seed must map to parts in at least two files, or a cross-file
# citation cannot be expressed and U3 asserts about nothing.
SW0="$(new_subj_world)"; SW0R="$(subj_root "$SW0")"
n_sp="$(grep -c . "$SW0R/subject.map")" || n_sp=0
n_sf="$(cut -f2 "$SW0R/subject.map" | sort -u | grep -c .)" || n_sf=0
if [ "$n_sp" -ge 4 ] && [ "$n_sf" -eq 4 ] && [ -f "$SW0R/$SUBJ_PA/s9/requirements-subject.md" ]; then
  ok "U0: the subject seed maps to $n_sp parts across all 4 files (read from partition-subject.sh --map), manifest written"
else
  bad "U0: FIXTURE BROKEN -- the subject seed maps to $n_sp part(s) over $n_sf file(s): $(head -3 "$SW0R/subject.map")"
fi
p_subj_b3 "$MERGE" && ok "U1: subject shards each stamped MET with 1 MAJOR merge NOT_MET; artifact: = the manifest; artifact_sha: the four stems at disk bytes; ids = map ordinals + cross" \
  || bad "U1: the subject merge did not sum, recompute and notarize the manifest (rc=$RC): $(cat "$MO")"
p_subj_at "$MERGE" && ok "U1b: subject shards notarizing the old <stem>=<sha> form merge; the merged artifact_sha is the <stem>@<sha> list at disk bytes" \
  || bad "U1b: the merge did not read =-form shards into an @-form line (rc=$RC): $(cat "$MO")"
p_subj_miss_cross "$MERGE" && ok "U2: a subject shard set missing its LAST cross group -> REFUSED, nothing written" || bad "U2: (rc=$RC) $(cat "$MO")"
p_subj_xcite "$MERGE" && ok "U3: a part shard citing another file's ordinal -> REFUSED by the partition, nothing written" || bad "U3: (rc=$RC) $(cat "$MO")"
p_subj_sha "$MERGE" && ok "U4: one stem notarized at other bytes (the rest right) -> REFUSED naming that stem, nothing written" || bad "U4: (rc=$RC) $(cat "$MO")"
p_subj_stems "$MERGE" && ok "U5: a shard notarizing three of four stems -> REFUSED, nothing written" || bad "U5: (rc=$RC) $(cat "$MO")"
p_subj_art "$MERGE" && ok "U6: a shard naming prd.md instead of the manifest -> REFUSED, nothing written" || bad "U6: (rc=$RC) $(cat "$MO")"
p_subj_elicit "$MERGE" && ok "U7: --elicitation writes s9/requirements-elicitation.md with NO verdict (file or stdout); a verdict-bearing shard and a non-elicitation skill each REFUSED" \
  || bad "U7: the elicitation merge (rc=$RC): $(cat "$MO")"
p_subj_b4 "$MERGE" && ok "U8: --document into shards/requirements-p1 -> REFUSED 'merge it with --subject' (B4), nothing written" || bad "U8: (rc=$RC) $(cat "$MO")"
p_b4doc "$MERGE" && ok "U9: --document prd.md from shards/prd-p1 while s9/requirements-subject.md names it -> REFUSED naming the 'prd' stem and --subject 9 (B4 by document), nothing written" \
  || bad "U9: a --document merge of a manifest-named file was not refused (rc=$RC): $(cat "$MO")"
p_b4doc_nomf "$MERGE" && ok "U10: the same --document prd.md merge with NO manifest in the sprint -> MERGED prd-adversarial-p1 (U9's ALLOW twin)" \
  || bad "U10: the no-manifest twin did not merge (rc=$RC): $(cat "$MO")"
p_b4doc_other "$MERGE" && ok "U11: --document of an s9 file the manifest does NOT name, manifest present -> MERGED (B4 keys on the manifest's files, not on the manifest's presence)" \
  || bad "U11: a --document merge of a file outside the subject was refused beside a manifest (rc=$RC): $(cat "$MO")"

# ---- the cross groups (BL-464, BL-811). A K>=3 shard set carries ONE cross.md (the dispatched shape)
# or one cross shard per row of partition-document.sh --cross-groups <K>, never both, in EVERY mode;
# X1-X3 drive K=8 through each mode (and K=2 through files and --document), each predicate
# presence-shaped in every cell.
p_xfiles "$MERGE" && ok "X1: files mode, K=8: cross-1..6 merges (tool_use_id = cross-1's); cross.md alone MERGES titled K+1 shards, its body last under '## Shard: cross-story', tool_use_id the lone cross's, keyed cross=; cross-1..5 without cross-6 REFUSED; a finding in its owner AND another covering group REFUSED naming the owner, its owner alone merges major=1, a (1, 2, K-1) finding held only by a non-owner merges major=1; K=2 cross.md merges, K=2 cross-1.md REFUSED" \
  || bad "X1: files-mode cross groups (rc=$RC): $(cat "$MO")"
p_xdoc "$MERGE" && ok "X2: --document, K=8: the same five cells (the lone cross under '## Shard: cross-section'), and K=2 cross.md merges" \
  || bad "X2: --document cross groups (rc=$RC): $(cat "$MO")"
p_xelicit "$MERGE" && ok "X3: --subject --elicitation over the 6-part subject: cross-1..6 merges, cross.md alone MERGES (under '## Shard: cross-part'), a partial set REFUSED, the non-owner duplicate REFUSED, the owner alone counted once" \
  || bad "X3: elicitation cross groups (rc=$RC): $(cat "$MO")"
p_xmix "$MERGE" && ok "X4: cross.md beside cross-1..3.md -> REFUSED as a mix, nothing written" || bad "X4: (rc=$RC) $(cat "$MO")"
p_xunknown "$MERGE" && ok "X5: cross-7.md at K=3 -> REFUSED, the table does not print group 7, nothing written" || bad "X5: (rc=$RC) $(cat "$MO")"
p_xcomplete "$MERGE" && ok "X6: one shard ending in seat-complete: makes an unmarked shard an unfinished REFUSAL; every shard marked with its findings=<n> merges with the markers dropped; findings=3 over 2 findings REFUSED as truncated" \
  || bad "X6: seat-complete (rc=$RC): $(cat "$MO")"

# ---- the series stem is not the artifact. S1 is the defect graph s319 nearly shipped; S2 is its
# ALLOW twin one property apart (the dir name), with graph's real coe-p1 beside it; S3 is the
# near-miss that carries the word without ending in it; S4 is files mode and --map.
p_stem_series "$MERGE" && ok "S1: --document from shards/doc-adversarial-p1/ -> REFUSED 'names the series, not the artifact' (exit 2), and s9/ holds no *adversarial* file" \
  || bad "S1: a shard dir named for the series was not refused before any write (rc=$RC): $(cat "$MO")"
p_stem_control "$MERGE" && ok "S2: the same shards under shards/doc-p1/ and shards/coe-p1/ -> MERGED, writing doc-adversarial-p1.md and coe-adversarial-p1.md" \
  || bad "S2: the correctly named shard dir did not merge (rc=$RC): $(cat "$MO")"
p_stem_near "$MERGE" && ok "S3: shards/adversarial-notes-p1/ (the word, not the -adversarial suffix) -> MERGED" \
  || bad "S3: a stem containing 'adversarial' without ending in it was refused (rc=$RC): $(cat "$MO")"
p_stem_files "$MERGE" && ok "S4: files mode and --map on shards/stories-adversarial-p1/ -> each REFUSED naming the series, nothing written" \
  || bad "S4: files mode or --map accepted a series-named shard dir (rc=$RC): $(cat "$MO")"

# ---- the dispatch id is DERIVED from the harness records, never self-reported (T1-T10). Every
# shard helper drives the REAL remediation-guard hook with a PreToolUse Write payload, and seeds the
# agent's meta file and an adversary spawn row; each cell below varies ONE of those for shard 2.
p_tuid_main "$MERGE" && ok "T1: self ids NOT_ACCESSIBLE, unavailable, absent and the forged toolu_cross1_g1_dispatch each merge; shard_tool_use_ids are the derived ids, tool_use_id is cross-1's, the forged string absent" \
  || bad "T1: a set with real records did not merge to the derived ids (rc=$RC): $(cat "$MO")"
p_tuid_norow "$MERGE" && ok "T2: shard 2 with no write-ledger row (a Bash write) and a toolu_-prefixed self id -> REFUSED 'has no row', nothing written" \
  || bad "T2: (rc=$RC) $(cat "$MO")"
p_tuid_nometa "$MERGE" && ok "T3: shard 2's writer has no meta file, no probe row, and a real-shaped self id -> REFUSED, nothing written" \
  || bad "T3: (rc=$RC) $(cat "$MO")"
p_tuid_selfdiff "$MERGE" && ok "T4: a real-shaped self id differing from the derived one -> REFUSED; the derived id self-reported merges" \
  || bad "T4: (rc=$RC) $(cat "$MO")"
p_tuid_role "$MERGE" && ok "T5: shard 2 written only by a remediator dispatch, and by an adversary plus a remediator -> each REFUSED naming the role" \
  || bad "T5: (rc=$RC) $(cat "$MO")"
p_tuid_twowriters "$MERGE" && ok "T6: two adversary dispatches wrote shard 2 -> REFUSED, neither taken" \
  || bad "T6: (rc=$RC) $(cat "$MO")"
p_tuid_oneagent "$MERGE" && ok "T7: one agent wrote shards 2 and 3 -> REFUSED 'one dispatch delivered two shards'" \
  || bad "T7: (rc=$RC) $(cat "$MO")"
p_tuid_nospawn "$MERGE" && ok "T8: the meta file's dispatch id has no spawn-ledger row -> REFUSED" \
  || bad "T8: (rc=$RC) $(cat "$MO")"
p_tuid_session "$MERGE" && ok "T9: payload session_id differs from the transcript stem -> the meta file is found by the row's transcript_path and agent_id, and the set merges" \
  || bad "T9: (rc=$RC) $(cat "$MO")"
p_tuid_pre "$MERGE" && ok "T10: a row with no transcript_path takes the probe row's id and merges; without the probe row it is REFUSED naming the agent and 'predates transcript_path'" \
  || bad "T10: (rc=$RC) $(cat "$MO")"
p_tuid_basename "$MERGE" && ok "T11: shard 2's only rows sit under shards/stories-p2/ and under s2/shards/stories-p1/ -> REFUSED 'has no row' (rows keyed on the full path, never the basename)" \
  || bad "T11: (rc=$RC) $(cat "$MO")"
p_tuid_probemeta "$MERGE" && ok "T12: the probe ledger names the meta's id AND another adversary dispatch for shard 2's agent -> REFUSED 'the meta file was rewritten after the agent stopped'" \
  || bad "T12: (rc=$RC) $(cat "$MO")"
p_tuid_tworoles "$MERGE" && ok "T13: shard 2's dispatch id carries two spawn rows, adversary and remediator -> REFUSED naming the remediator role" \
  || bad "T13: (rc=$RC) $(cat "$MO")"

# ---- the re-dispatch of one shard (--rerun <shard>.md@<ISO>). RR1 is the contracted path; RR2 is
# graph s318 requirements-p1/cross-2, a genuine cross-shard write --rerun must never acquit; RR3 is
# the superseded writer posing as its own re-run.
p_rerun_join "$MERGE" && ok "RR1: a stalled adversary's 2.md and 2.md.draft before S, a NEW dispatch's 2.md after -> MERGED with --rerun 2.md@S, superseded=2, the rerun: line naming the stalled agent, 2= the new id" \
  || bad "RR1: (rc=$RC) $(cat "$MO")"
p_rerun_other "$MERGE" && ok "RR2: cross-1's own adversary edited 2.md before S -> REFUSED with --rerun, naming its cross-1.md row" \
  || bad "RR2: (rc=$RC) $(cat "$MO")"
p_rerun_same "$MERGE" && ok "RR3: the superseded writer writes 2.md again after S -> REFUSED, the re-run is a NEW dispatch" \
  || bad "RR3: (rc=$RC) $(cat "$MO")"

# ---- BL-946: DOUBLE-WRITE. A shard where NO --rerun start is admissible (a writer kept writing after another
# writer's first row) is refused as DOUBLE-WRITE, at the join's two-dispatch test, in both entry paths; a shard
# where some start is admissible keeps SAME (RR3, one writer) and the two-dispatch message (RR6f) byte-identical.
p_dw_rerun "$MERGE" && ok "RR6a: graph s322 coe-p2/cross.md -- O writes 2.md before S, the re-dispatch N after, O again after N -> --rerun 2.md@S REFUSED 'DOUBLE-WRITE 2.md:' naming both spans and 'no agent seal row', never SAME" \
  || bad "RR6a: (rc=$RC) $(cat "$MO")"
p_dw_plain "$MERGE" && ok "RR6n: the RR6a world with no --rerun -> REFUSED 'DOUBLE-WRITE 2.md:', never the two-dispatch --rerun remedy" \
  || bad "RR6n: (rc=$RC) $(cat "$MO")"
p_dw_twin "$MERGE" && ok "RR6b: RR6a's twin, O's last row before S -> MERGED with --rerun 2.md@S, superseded=2" \
  || bad "RR6b: (rc=$RC) $(cat "$MO")"
p_dw_tie "$MERGE" && ok "RR6c: O's last row ts equals N's first, --rerun at that tie -> REFUSED 'DOUBLE-WRITE 2.md:' (the comparison is strict)" \
  || bad "RR6c: (rc=$RC) $(cat "$MO")"
p_dw_out "$MERGE" && ok "RR6d: the RR6a world, O also writing 3.md.draft after its straddling row -> the OUT refusal, not DOUBLE-WRITE" \
  || bad "RR6d: (rc=$RC) $(cat "$MO")"
p_dw_role "$MERGE" && ok "RR6e: the RR6a world plus a remediator writing 2.md, no --rerun -> the role violation, not DOUBLE-WRITE" \
  || bad "RR6e: (rc=$RC) $(cat "$MO")"
p_dw_draft "$MERGE" && ok "RR6f: graph s318's shape, a draft-only agent inside N's span is no writer -> no --rerun: the two-dispatch refusal; --rerun 2.md@S: MERGED superseded=1" \
  || bad "RR6f: (rc=$RC) $(cat "$MO")"
p_dw_straddle_draft "$MERGE" && ok "RR6g: the straddle's late row is on 2.md.draft only (O 2.md at 20:00, N 2.md at 21:00, O 2.md.draft at 21:10) -> DOUBLE-WRITE with and without --rerun 2.md@S" \
  || bad "RR6g: (rc=$RC) $(cat "$MO")"

# ---- BL-536: a superseded writer is role-checked (D1), one dispatch writes one shard dir (D2), and
# the meta file is corroborated by the probe ledger (D4). Each refusal beside its MERGED twin.
p_rerun_role "$MERGE" && ok "RR4: --rerun superseding a stalled adversary AND a remediator -> REFUSED as a role violation; the same world with that writer an adversary MERGES superseded=2" \
  || bad "RR4: (rc=$RC) $(cat "$MO")"
p_xdir "$MERGE" && ok "XD1: shard 2's writer also wrote stories-p2/1.md, or stories-p10/1.md -> REFUSED 'under another shard dir', and under --rerun too; its own 2.md.draft, an unrelated agent in stories-p10, and --rerun without the p2 row each MERGE" \
  || bad "XD1: (rc=$RC) $(cat "$MO")"
p_probe_disagree "$MERGE" && ok "PR2: shard 2's meta file rewritten to another adversary dispatch after its adversary, or remediator, stopped -> each REFUSED 'the meta file was rewritten'; the unforged twin MERGES" \
  || bad "PR2: (rc=$RC) $(cat "$MO")"
p_probe_absent "$MERGE" && ok "PR1: a legitimate writer with no probe row, and a remediator with a forged meta and no probe row -> each REFUSED 'has not stopped'; the legitimate writer with its row MERGES" \
  || bad "PR1: (rc=$RC) $(cat "$MO")"
p_rerun_residual "$MERGE" && ok "RR5: KNOWN GAP, stated in the merge header -- a superseded remediator with no probe row and its meta forged to an adversary dispatch MERGES under --rerun; the same remediator WITH its probe row is REFUSED 'the meta file was rewritten'" \
  || bad "RR5: (rc=$RC) $(cat "$MO")"

# ---- BL-544 / BL-554 / BL-548 (merge half). Each world is seeded the BL-536 way (shard -> harness
# record) because the dispatch-id derivation refuses a shard with no record before these checks run.
p_hdr "$MERGE" && ok "H1: a shard with NO ## Findings section whose finding opens '## F-1 (MAJOR)' and declares 0 findings -> REFUSED naming the line and the FINDING GRAMMAR; '## Notes' and the same heading inside a fence MERGE" \
  || bad "H1: (rc=$RC) $(cat "$MO")"
p_draft "$MERGE" && ok "H2: 2.md.draft beside a complete shard -> MERGED with 'NOTE: ignored draft 2.md.draft' on stderr and its body absent from the pass; notes.md and notes.md.draft still REFUSED" \
  || bad "H2: (rc=$RC) $(cat "$MO")"
p_dry "$MERGE" && ok "H3: --dry-run over two shards citing another story prints all four REFUSED lines, exit 2, no pass file; the clean set prints DRY-RUN: clean (exit 0), writes nothing, then merges for real" \
  || bad "H3: (rc=$RC) $(cat "$MO")"
p_dry_barrier "$MERGE" && ok "H4: --dry-run with shard 1 missing AND a finding refusal in shard 2 prints exactly the missing-shard line and reads no stdin (stdin is a file of poison in the shard grammar)" \
  || bad "H4: (rc=$RC) $(cat "$MO")"
# ---- BL-596: one tree. BL-597: a local-model lead's call_ ids. BL-598: the re-run start is bound.
p_tree "$MERGE" && ok "TR1: shard 2's only row is a write to a worktree's copy -> REFUSED 'not this tree'; the same write through a symlink alias of this tree, and a ledger with no root field, each MERGE" \
  || bad "TR1: (rc=$RC) $(cat "$MO")"
p_tuid_call "$MERGE" && ok "TC1: every dispatch id in the call_ shape -> MERGED with the derived call_ ids; a real-shaped call_ self id that differs -> REFUSED" \
  || bad "TC1: (rc=$RC) $(cat "$MO")"
p_rerun_bind "$MERGE" && ok "RB1: --rerun 2.md@1999-01-01T00:00:00Z on a normal round -> REFUSED past BACKDATE_TOL_S; 45 s after the recorded dispatch time -> MERGED, superseded: none" \
  || bad "RB1: (rc=$RC) $(cat "$MO")"

# ---- BL-577: `### ` under `## Findings` is reserved for a finding (FINDING GRAMMAR). BL-575: one
# header check, owned by the merge, callable on one file as --check-header. These arms are INLINE,
# not `p_<name> "$MERGE"` predicates. RM-A and RM-B below are this
# fixture's own mutants, built PM1's way in a copy of the merge's whole sibling set.
# RS1: the filed incident -- graph s319 requirements-p1/2.md, findings=0, a probes subsection.
p_rs1 "$MERGE" \
  && ok "RS1: '### Probes run (no finding)' under ## Findings, findings=0 -> REFUSED naming the reserved form and the fix (line 5), nothing written" \
  || bad "RS1: a severity-less ### under ## Findings was not refused with the reserved-form message (rc=$RC): $(cat "$MO")"
d="$(hdr_world "## Findings\n\n## Probes\n\n$PROBES")"; mk_markers "$d"; run_merge "$MERGE" "$d"
[ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$MO" "major=4" \
  && ok "RS1c: the same probes under their own ## Probes section -> MERGED, shard 2 counting 0 (major=4 = shards 1 and 3)" \
  || bad "RS1c: the probes moved to ## Probes did not merge with shard 2 at 0 (rc=$RC): $(cat "$MO")"
# RS2 / RS3: the F-form opens ONE finding; the bare severity form (s315-s317 wrote it, and J3 can never close
# it: no id) is REFUSED on the convergence axis since BL-958 (THE FINDING ID, merge header).
for cell in 'RS2|### F-1 (MAJOR) the ordinal map omits story 2' 'RS3|### MAJOR: the ordinal map omits story 2'; do
  id="${cell%%|*}"; h="${cell#*|}"
  d="$(hdr_world "## Findings\n\n$h\n\nstories: 2\n")"; set_major "$d/2.md" 1; mk_markers "$d"
  printf '\n' >> "$d/2.md"; sed 's/^seat-complete: stories adversary 2 findings=0$/seat-complete: stories adversary 2 findings=1/' "$d/2.md" > "$d/2.tmp" && mv "$d/2.tmp" "$d/2.md"
  run_merge "$MERGE" "$d"
  if [ "$id" = RS2 ]; then
    [ "$RC" -eq 0 ] && has "$MO" "major=5" \
      && ok "$id: '$h' counts as 1 MAJOR finding (findings=1 marker agrees; merged major=5)" \
      || bad "$id: '$h' was not counted as one MAJOR finding (rc=$RC): $(cat "$MO")"
  else
    refused_clean "2.md:5 is a MAJOR finding heading from which no finding id is derived" "$d" && has "$MO" "$KF_MAJ" \
      && ok "$id: '$h' (no finding id) -> REFUSED naming 2.md:5 and the keyed form, nothing written" \
      || bad "$id: '$h' was not refused as a keyless MAJOR (rc=$RC): $(cat "$MO")"
  fi
done
# ---- BL-958: THE FINDING ID (merge header). Predicates in lib.sh (p_t1 .. p_t1_dry).
p_t1 "$MERGE" && ok "FI1: '### MAJOR — wiring check' and '### CRITICAL: x', counts agreeing -> each REFUSED naming 2.md:5, the keyed form and J3's source token, nothing written" \
  || bad "FI1: (rc=$RC) $(cat "$MO")"
p_t2 "$MERGE" && ok "FI2: F-1, **F-2**, 'Finding 3:', '1.', [F-3] (all MAJOR) and a keyless MINOR -> MERGED major=9" \
  || bad "FI2: (rc=$RC) $(cat "$MO")"
p_t3a "$MERGE" && ok "FI3a: F-1 twice as MAJOR, and F-1 as MAJOR beside F-1 as MINOR -> each REFUSED naming 2.md:9 and line 5; shard 2's M1 beside shard 1's M1 -> MERGED major=5" \
  || bad "FI3a: (rc=$RC) $(cat "$MO")"
p_t3b "$MERGE" && ok "FI3b: '**F-1**' and 'F-1.' (raw-different, one normalised id) -> REFUSED naming 2.md:9 and line 5" \
  || bad "FI3b: (rc=$RC) $(cat "$MO")"
p_d1 "$MERGE" && ok "FIF: a fence left open at end of file after a counted finding -> REFUSED naming 2.md:9; the same fence closed -> MERGED major=5" \
  || bad "FIF: (rc=$RC) $(cat "$MO")"
p_elic "$MERGE" && ok "FIE: FI1's keyless MAJOR in an elicitation shard -> --check-header --axis elicitation passes (rc 0, silent): convergence axis only" \
  || bad "FIE: (rc=$RC) $(cat "$MO")"
p_t1_chk "$MERGE" && ok "FIC: --check-header --axis convergence refuses FI1's shard (rc 1) with the same refusal" \
  || bad "FIC: (rc=$RC) $(cat "$MO")"
p_t1_dry "$MERGE" && ok "FID: --dry-run refuses FI1's world (rc 2) with the same refusal and writes nothing" \
  || bad "FID: (rc=$RC) $(cat "$MO")"
p_sh_refuse "$MERGE" && ok "FIS: a shard's own '## Shard: story 3' in 2.md -> merge REFUSED naming 2.md:3 and the shard file J3 would key it under (3.md), nothing written; --check-header refuses 'part 04' in 5.md (J3: 4.md), 'cross-story group 2 (1,3)' in cross-1.md (cross-2.md), and 'story 2' followed by '## Shard: notes' in 2.md (?)" \
  || bad "FIS: (rc=$RC) $(cat "$MO")"
p_sh_accept "$MERGE" && ok "FISa: --check-header accepts a self-heading J3 maps to the shard's own file -- 'story 2' in 2.md, 'part 04' in 04.md, 'cross-story' in cross.md, 'cross-section group 01 (1,3)' in cross-1.md" \
  || bad "FISa: (rc=$RC) $(cat "$MO")"
# The finding-grammar binding of the merge, the join and J3 (BL-958, BB0-BB2) is core/fixtures/finding-grammar-binding.
# RS4: a non-finding ### inside a fence under ## Findings is ignored.
d="$(hdr_world "## Findings\n\n\`\`\`text\n$PROBES\n\`\`\`")"; mk_markers "$d"; run_merge "$MERGE" "$d"
[ "$RC" -eq 0 ] && has "$MO" "major=4" \
  && ok "RS4: the probes heading inside a fence under ## Findings -> ignored, MERGED at shard 2 = 0" \
  || bad "RS4: a fenced ### under ## Findings was not ignored (rc=$RC): $(cat "$MO")"

# ---- BL-660: one fence grammar (opener: no backtick in a backtick fence's info string; closer: a bare run of the opener's character)
p_fence_prose "$MERGE" && ok "FG1: a prose line opening with three backticks and carrying a backtick, then a real derived fence and two findings -> MERGED counting both (the filed instance)" \
  || bad "FG1: (rc=$RC) $(cat "$MO")"
p_fence_unclosed "$MERGE" && ok "FG2: a genuinely unclosed fence still hides its finding -> REFUSED on the count" || bad "FG2: (rc=$RC) $(cat "$MO")"
p_fence_tilde "$MERGE" && ok "FG3: a backtick fence holding a ~~~~^^^ line closes only on its own backtick line -> M1 stays hidden, MERGED major=4" || bad "FG3: (rc=$RC) $(cat "$MO")"
p_fence_four "$MERGE" && ok "FG4: a four-backtick opener with an info string opens and its bare four-backtick line closes -> MERGED major=5" || bad "FG4: (rc=$RC) $(cat "$MO")"
p_fence_sameset "$MERGE" && ok "FG5: same_set -- a cross finding duplicating its owner's set is REFUSED identically with and without a prose backtick line in the owner's shard" || bad "FG5: (rc=$RC) $(cat "$MO")"
p_fence_nested "$MERGE" && ok "FG6: a four-backtick fence holding a three-backtick block hides the finding before its own closer -> declared 0 MERGED major=4, declared 1 REFUSED on the count" || bad "FG6: (rc=$RC) $(cat "$MO")"
p_fence_nested_set "$MERGE" && ok "FG7: same_set -- the owner's finding after a four-backtick fence holding a three-backtick block is read, so the duplicate is REFUSED" || bad "FG7: (rc=$RC) $(cat "$MO")"

# ---- BL-664: a trailing ` #` comment is stripped from a provenance value (schema parser.comments)
p_hdr_comment "$MERGE" && ok "HC1: every provenance value carrying a ' # ' comment passes --check-header on both axes, and merges byte-identical to the files-mode golden; 'findings_major: 2#x' (no whitespace) is still refused as non-integer" \
  || bad "HC1: (rc=$RC) $(cat "$MO")"

# ---- BL-670: the merge stamps DIVERGENT_HARD_BLOCK from the summed prior scope (arm C on the sum)
p_sum_divergent "$MERGE" && ok "SD1: summed prior_scope 2 over p1's 1 CRITICAL -> DIVERGENT_HARD_BLOCK with the stamp line naming p1; over p1's 2 -> not divergent; pass 1 -> not divergent; p3 with p2 absent compares with p1; a two-block p1 stamps on its FIRST block; a block-less p2 is skipped" \
  || bad "SD1: (rc=$RC) $(cat "$MO")"
if p_sum_excl_drift "$MERGE"; then ok "SD3: a validator copy whose --series exclusion line drifted is REFUSED naming the exclusion line, rc 2"
else bad "SD3: the drifted exclusion line was not refused (rc=${RC:-?}): $(head -3 "$MO")"; fi
# SD2: the oracle, not spelled as a line-start predicate call.
if p_sum_divergent_oracle "$MERGE"; then ok "SD2: on five seeded series (a -pass1 and a zero-padded -p02 predecessor, a two-block and a block-less one) the merge stamps exactly where validate-adversarial-convergence.sh --series fires arm C on the unstamped twin"
else bad "SD2: the merge's stamp (${OR_ST:-?}) disagrees with arm C on the unstamped twin (${OR_C:-?}): $(grep -m2 'FAIL\|pass artifact' "$CO" 2>/dev/null)"; fi

# CH1-CH8: --check-header on one file. The base is a real B3 shard, which passes; each cell varies ONE field.
ch() { $ASM_RUN "$MERGE" --check-header "$1" --axis "$2" > "$MO" 2>&1; RC=$?; } # <shard file> <axis>
chv() { sed "$2" "$1" > "$3"; } # <src> <sed script> <dst>
d="$(b3_world)"; c="$WORK/ch"; mkdir -p "$c"
ch "$d/1.md" convergence
[ "$RC" -eq 0 ] && [ ! -s "$MO" ] && ok "CH1: --check-header on a complete shard (verdict: EXIT_CONDITION_MET) -> exit 0, nothing printed" \
  || bad "CH1: a complete shard did not pass --check-header silently (rc=$RC): $(cat "$MO")"
p_chv "$MERGE" \
  && ok "CH2: no verdict: line -> --check-header exit 1 with the merge's own refusal text (the same line the merge prints for that shard, path aside)" \
  || bad "CH2: the no-verdict shard: --check-header and the merge did not refuse with one text (rc=$RC): $(cat "$MO")"
for cell in "CH3|s/^verdict: .*/verdict: PENDING-LEAD/|declares verdict 'PENDING_LEAD'" \
            "CH4|/^lead_role:/d|declares no lead_role" \
            "CH5|s/^lead_role: .*/lead_role: <the step file that invoked or dispatched the evaluation>/|an unfilled template placeholder" \
            "CH6|s/^verdict: .*/verdict: <EXIT_CONDITION_MET|EXIT_CONDITION_NOT_MET|DIVERGENT_HARD_BLOCK>/|declares verdict 'EXIT_CONDITION_MET_EXIT_CONDITION_NOT_MET_DIVERGENT_HARD_BLOCK'" \
            "CH7|s/^verdict: .*/verdict:   # stamped by the adversary/|declares verdict '<none>'"; do
  id="${cell%%|*}"; rest="${cell#*|}"; tok="${rest##*|}"; scr="${rest%|*}"
  chv "$d/1.md" "$scr" "$c/$id.md"; ch "$c/$id.md" convergence
  [ "$RC" -eq 1 ] && has "$MO" "REFUSED: $c/$id.md" && has "$MO" "$tok" \
    && ok "$id: [$scr] -> --check-header exit 1, '$tok'" || bad "$id: [$scr] gave rc=$RC: $(cat "$MO")"
done
# CH7: a COMMENT-ONLY verdict. The trailing ` #` comment is stripped from the raw value before the
# trim (BL-664), so nothing is left and the shard is refused as '<none>'; the commented VALUE that
# passes is p_hdr_comment's (HC1 below).
cp "$d/1.md" "$c/m.md"; printf '\nseat-complete: stories adversary 1 findings=3\n' >> "$c/m.md"; ch "$c/m.md" convergence
[ "$RC" -eq 1 ] && has "$MO" "findings=3' but its ## Findings section heads 2 finding(s)" \
  && ok "CH8: a marker declaring findings=3 over 2 findings -> --check-header exit 1 with the merge's truncation refusal" \
  || bad "CH8: (rc=$RC) $(cat "$MO")"
cp "$d/1.md" "$c/m2.md"; printf '\nseat-complete: stories adversary 1 findings=2\n' >> "$c/m2.md"; ch "$c/m2.md" convergence
[ "$RC" -eq 0 ] && ok "CH8c: the same shard with findings=2 -> exit 0" || bad "CH8c: (rc=$RC) $(cat "$MO")"
chv "$d/1.md" 's/^skill: .*/skill: bmad-advanced-elicitation/;/^verdict:/d' "$c/el0.md"; ch "$c/el0.md" elicitation; r0=$RC
chv "$d/1.md" 's/^skill: .*/skill: bmad-advanced-elicitation/' "$c/el1.md"; ch "$c/el1.md" elicitation; r1=$RC
[ "$r0" -eq 0 ] && [ "$r1" -eq 1 ] && has "$MO" "declares a verdict; an elicitation shard carries none" \
  && ok "CH9: --axis elicitation: no verdict -> exit 0; with a verdict -> exit 1 'an elicitation shard carries none'" \
  || bad "CH9: elicitation axis gave no-verdict rc=$r0, with-verdict rc=$r1: $(cat "$MO")"
chv "$d/1.md" "s/^## Findings$/## Findings\\
\\
### Probes run (no finding)\\
/" "$c/rs.md"; ch "$c/rs.md" convergence
[ "$RC" -eq 1 ] && has "$MO" "$RESERVED" && ok "CH10: --check-header refuses the reserved-form heading the merge refuses" \
  || bad "CH10: (rc=$RC) $(cat "$MO")"

# CS1-CS7: --check-shard, ONE adversary shard at its seal (BL-974; header: THE SHARD CHECK). Each cell is a
# real seeded world; the sealed sibling is sealed by the REAL producer, wait-for-deliverable.sh --mark.
# Every predicate takes the merge file first, so a mutant is scored by the arm's own body.
WFD="$SRCDIR/wait-for-deliverable.sh"
cs() { $ASM_RUN "$1" --check-shard "$2" --findings "$3" > "$MO" 2>&1; RC=$?; } # <merge> <shard file> <n>
cs_lr() { sed "s|^lead_role: .*|lead_role: $2|" "$1" > "$1.t" && mv "$1.t" "$1"; } # <shard file> <value>
cs_seal() { bash "$WFD" --mark "$1" requirements adversary "$2" "findings=$3" >/dev/null 2>&1; } # <file> <shard> <n>
# The shipped mark now runs --check-shard (wait-for-deliverable.sh header term 7), so a SECOND sealed sibling that
# disagrees with the first is refused at its seal. That world is still reachable: a shard sealed by an engine half
# whose mark has no merge beside it (term 7's absent-sibling case, today's behaviour). cs_seal_presib is that mark,
# the shipped wait-for-deliverable.sh and content-seal.sh in a dir that holds no merge.
CS_PRESIB="$WORK/cs-presib"; mkdir -p "$CS_PRESIB" && cp "$WFD" "$SRCDIR/content-seal.sh" "$CS_PRESIB/" \
  || { echo "FIXTURE BROKEN: cannot build the pre-sibling mark dir" >&2; exit 2; }
cs_seal_presib() { bash "$CS_PRESIB/wait-for-deliverable.sh" --mark "$1" requirements adversary "$2" "findings=$3" >/dev/null 2>&1; }
p_cs_lead() { # lead_role against a SEALED sibling, both directions; an unsealed one and self are never the reference
  local m="$1" d w ok=1
  for w in "requirements|requirements.md" "requirements.md|requirements"; do
    d="$(subj_b3_world)" || return 1
    cs_lr "$d/1.md" "${w%|*}"; cs_seal "$d/1.md" 1 1 || return 1
    cs_lr "$d/2.md" "${w#*|}"; cs "$m" "$d/2.md" 1
    [ "$RC" -eq 2 ] && has "$MO" "REFUSED: $d/2.md declares lead_role '${w#*|}' where the sealed shard $d/1.md declares '${w%|*}'" || ok=0
    cs_lr "$d/2.md" "${w%|*}"; cs "$m" "$d/2.md" 1                     # near-miss: the reference spelling
    [ "$RC" -eq 0 ] && has "$MO" "SHARD-OK" || ok=0
  done
  d="$(subj_b3_world)" || return 1                                      # control: the sibling is NOT sealed
  cs_lr "$d/1.md" requirements; cs_lr "$d/2.md" requirements.md; cs "$m" "$d/2.md" 1
  [ "$RC" -eq 0 ] && has "$MO" "SHARD-OK" || ok=0
  d="$(subj_b3_world)" || return 1                                      # re-mark: self is sealed with the old spelling
  cs_lr "$d/2.md" requirements.md; cs_seal "$d/2.md" 2 1 || return 1
  sed 's|^lead_role: .*|lead_role: requirements|' "$d/2.md" > "$WORK/cs-remark.md" || return 1
  export AI_DLC_CHECK_BYTES="$WORK/cs-remark.md"; cs "$m" "$d/2.md" 1; unset AI_DLC_CHECK_BYTES
  [ "$RC" -eq 0 ] && has "$MO" "SHARD-OK" || ok=0
  d="$(subj_b3_world)" || return 1                                      # sealed siblings disagreeing: WARN, pass
  cs_lr "$d/1.md" requirements; cs_seal "$d/1.md" 1 1 || return 1
  cs_lr "$d/3.md" requirements.md; cs_seal_presib "$d/3.md" 3 1 || return 1
  cs "$m" "$d/2.md" 1
  [ "$RC" -eq 0 ] && has "$MO" "WARN: the sealed shards in" && has "$MO" "SHARD-OK" || ok=0
  [ "$ok" = 1 ]
}
p_cs_cite() { # a finding with no sections: line is refused at the seal; the same shard with it passes
  local m="$1" d; d="$(subj_b3_world)" || return 1
  cs "$m" "$d/1.md" 1; [ "$RC" -eq 0 ] && has "$MO" "SHARD-OK" || return 1
  awk 'k == 0 && /^sections: / { k = 1; next } { print }' "$d/1.md" > "$d/1.t" && mv "$d/1.t" "$d/1.md"
  cs "$m" "$d/1.md" 1
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED: $d/1.md:5 finding carries 0 sections: lines; each finding carries exactly one"
}
p_cs_stem() { # artifact_sha stem SPec@ against SPEC@ (the subject's own stem): refused; SPEC@ passes
  local m="$1" d; d="$(subj_b3_world)" || return 1
  has "$d/1.md" "SPEC@" || has "$d/1.md" "SPEC=" || return 1
  cs "$m" "$d/1.md" 1; [ "$RC" -eq 0 ] && has "$MO" "SHARD-OK" || return 1
  sed -E 's/^(artifact_sha:.* )SPEC([=@])/\1SPec\2/' "$d/1.md" > "$d/1.t" && mv "$d/1.t" "$d/1.md"
  cs "$m" "$d/1.md" 1
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED: $d/1.md artifact_sha names stem 'SPec', not a subject stem"
}
p_cs_opener() { # the provenance opener misspelt SKILL_INVOCATION_PROVENANCE_BEGIN: one REFUSED line, exit 2
  local m="$1" d n; d="$(b3_world)" || return 1
  cs "$m" "$d/1.md" 2; [ "$RC" -eq 0 ] && has "$MO" "SHARD-OK" || return 1
  sed 's/SKILL_INVOCATION_PROVENANCE v1/SKILL_INVOCATION_PROVENANCE_BEGIN/' "$d/1.md" > "$d/1.t" && mv "$d/1.t" "$d/1.md"
  cs "$m" "$d/1.md" 2; n="$(grep -c '^REFUSED: ' "$MO")" || n=0
  [ "$RC" -eq 2 ] && [ "$n" = 1 ] && has "$MO" "carries 0 provenance block opening(s) and 1 closing(s)"
}
p_cs_skip() { # dir-level non-subjects SKIP (exit 3); a real files-mode shard dir beside them is checked (exit 0)
  local m="$1" d s x ok=1; d="$(b3_world)" || return 1; s="$(dirname "$d")"
  cs "$m" "$d/1.md" 2; [ "$RC" -eq 0 ] && has "$MO" "SHARD-OK" || ok=0
  for x in stories-fences-p1 architecture-adversarial-p1; do
    mkdir -p "$s/$x"; sed 's|^artifact_sha: .*|artifact_sha: 0|' "$d/1.md" > "$s/$x/1.md"
    cs "$m" "$s/$x/1.md" 2
    [ "$RC" -eq 3 ] && has "$MO" "SKIP: " && ! has "$MO" "REFUSED" || ok=0
  done
  [ "$ok" = 1 ]
}
p_cs_bytes() { # AI_DLC_CHECK_BYTES: the bytes checked are that file's, the path named is the real shard's
  local m="$1" d; d="$(b3_world)" || return 1
  sed '/^verdict:/d' "$d/1.md" > "$WORK/cs-bytes.md"
  export AI_DLC_CHECK_BYTES="$WORK/cs-bytes.md"; cs "$m" "$d/1.md" 2; unset AI_DLC_CHECK_BYTES
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED: $d/1.md declares verdict '<none>'" && ! has "$MO" "$WORK/cs-bytes.md" || return 1
  cs "$m" "$d/1.md" 2; [ "$RC" -eq 0 ] || return 1                       # the real bytes: clean
  cs "$m" "$d/1.md" 3                                                    # --findings 3 over 2 findings, no marker
  [ "$RC" -eq 2 ] && has "$MO" "findings=3' but its ## Findings section heads 2 finding(s)" || return 1
  $ASM_RUN "$m" --check-shard "$d/1.md" > "$MO" 2>&1; [ "$?" -eq 64 ]
}
p_cs_lead "$MERGE" && ok "CS1: lead_role 'requirements.md' against a SEALED 'requirements' sibling, and the reverse -> REFUSED naming the sibling and its value; the reference spelling, an UNSEALED disagreeing sibling, and a re-mark of a shard sealed with the old spelling -> SHARD-OK; sealed siblings disagreeing among themselves -> WARN, SHARD-OK" \
  || bad "CS1: (rc=$RC) $(head -3 "$MO")"
p_cs_cite "$MERGE" && ok "CS2: a finding with no sections: line -> --check-shard exit 2 with the merge's own cite-line refusal; the shard with it -> SHARD-OK" \
  || bad "CS2: (rc=$RC) $(head -3 "$MO")"
p_cs_stem "$MERGE" && ok "CS3: artifact_sha stem SPec@ (the subject's is SPEC@) -> exit 2 with the merge's own stem refusal; SPEC@ -> SHARD-OK" \
  || bad "CS3: (rc=$RC) $(head -3 "$MO")"
p_cs_opener "$MERGE" && ok "CS4: a provenance opener misspelt SKILL_INVOCATION_PROVENANCE_BEGIN -> exactly one REFUSED line (0 openings, 1 closing), exit 2; the real opener -> SHARD-OK" \
  || bad "CS4: (rc=$RC) $(head -3 "$MO")"
p_cs_skip "$MERGE" && ok "CS5: a shard in stories-fences-p1 (no subject resolvable) and in architecture-adversarial-p1 (the series stem) -> SKIP, exit 3, no REFUSED; stories-p1 beside them -> SHARD-OK" \
  || bad "CS5: (rc=$RC) $(head -3 "$MO")"
p_cs_bytes "$MERGE" && ok "CS6: AI_DLC_CHECK_BYTES names the bytes checked and the refusal names the real shard path; --findings 3 over 2 markerless findings -> the truncation refusal; no --findings -> exit 64" \
  || bad "CS6: (rc=$RC) $(head -3 "$MO")"
p_cs_selffirst() { # the self-only checks run BEFORE a subject is resolved: in a dir with none, a misspelt opener is
  # REFUSED (exit 2, the block count), and the correct opener in the same dir is SKIP (exit 3) naming the checks run
  local m="$1" d s; d="$(b3_world)" || return 1; s="$(dirname "$d")/stories-fences-p1"
  mkdir -p "$s" && cp "$d/1.md" "$s/1.md" || return 1
  cs "$m" "$s/1.md" 2
  [ "$RC" -eq 3 ] && has "$MO" "SKIP: no subject resolvable" && has "$MO" "the self-only checks ran and passed (check_header" && ! has "$MO" "REFUSED" || return 1
  sed 's/SKILL_INVOCATION_PROVENANCE v1/SKILL_INVOCATION_PROVENANCE_BEGIN/' "$d/1.md" > "$s/1.md" || return 1
  cs "$m" "$s/1.md" 2
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED: $s/1.md carries 0 provenance block opening(s) and 1 closing(s)" && ! has "$MO" "SKIP" || return 1
  # A COLLECTED refusal (the block parses, the verdict is absent) in the same dir: the self-only verdict, not the block-count stop, decides it.
  sed '/^verdict:/d' "$d/1.md" > "$s/1.md" || return 1
  cs "$m" "$s/1.md" 2
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED: $s/1.md declares verdict '<none>'" && ! has "$MO" "SKIP"
}
p_cs_selffirst "$MERGE" && ok "CS9: in stories-fences-p1 (no subject resolvable) a SKILL_INVOCATION_PROVENANCE_BEGIN opener -> exit 2 naming the block count, and a verdict-less shard -> exit 2, never SKIP; the real opener in the same dir -> exit 3 SKIP naming the self-only checks that ran" \
  || bad "CS9: (rc=$RC) $(head -3 "$MO")"
p_cs_docsel() { # FILES MODE ONLY on an entry spelled EXACTLY <artifact> holding two or more story files, never on
  # `[ -d ]` alone: a same-name dir holding ONE document, and a case-variant dir (which a case-insensitive
  # filesystem reads as the same name), beside sections: shards whose artifact partitions -> SHARD-OK, document mode.
  # Document mode is proven, not inferred: the same shard with a sections: line removed -> the sections: cite refusal.
  local m="$1" d s ok=1
  d="$(doc_b3_world)" || return 1; s="$(dirname "$(dirname "$d")")"
  cs "$m" "$d/1.md" 2; [ "$RC" -eq 0 ] && has "$MO" "SHARD-OK" || ok=0          # control: no colliding entry
  mkdir -p "$s/test-strategy" && cp "$s/test-strategy.md" "$s/test-strategy/test-strategy.md" || return 1
  cs "$m" "$d/1.md" 2; [ "$RC" -eq 0 ] && has "$MO" "SHARD-OK" && ! has "$MO" "stories:" || ok=0
  awk 'k == 0 && /^sections: / { k = 1; next } { print }' "$d/1.md" > "$d/1.t" && mv "$d/1.t" "$d/1.md"
  cs "$m" "$d/1.md" 2
  [ "$RC" -eq 2 ] && has "$MO" "finding carries 0 sections: lines; each finding carries exactly one" || ok=0
  d="$(doc_b3_world)" || return 1; s="$(dirname "$(dirname "$d")")"
  mkdir -p "$s/TEST-STRATEGY" && cp "$s/test-strategy.md" "$s/TEST-STRATEGY/test-strategy.md" || return 1
  cs "$m" "$d/1.md" 2; [ "$RC" -eq 0 ] && has "$MO" "SHARD-OK" && ! has "$MO" "stories:" || ok=0
  [ "$ok" = 1 ]
}
p_cs_docsel "$MERGE" && ok "CS10: a same-name dir s1/test-strategy/ holding ONE document, and a case-variant dir s1/TEST-STRATEGY/, beside sections: shards -> SHARD-OK in document mode (a sections:-less finding there -> the sections: cite refusal), never files mode" \
  || bad "CS10: (rc=$RC) $(head -3 "$MO")"
p_cs_noblock() { # a file with NO provenance block (0 openings, 0 closings) in a dir resolving no subject -> SKIP, both a
  # stories-fences-p1 and a stories-amend-p1 repair-style part; one opening and no closing in that dir -> REFUSED
  local m="$1" d s x ok=1; d="$(b3_world)" || return 1
  for x in stories-fences-p1 stories-amend-p1; do
    s="$(dirname "$d")/$x"; mkdir -p "$s" || return 1
    printf '# repair part\n\n- **disposition:** repaired\n- **edit:** `stories/story-1.md:3`\n' > "$s/1.md"
    cs "$m" "$s/1.md" 0
    [ "$RC" -eq 3 ] && has "$MO" "SKIP: $s/1.md carries no provenance block" && ! has "$MO" "REFUSED" || ok=0
  done
  sed '/SKILL_INVOCATION_PROVENANCE_END/d' "$d/1.md" > "$s/1.md" || return 1
  cs "$m" "$s/1.md" 2
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED: $s/1.md carries 1 provenance block opening(s) and 0 closing(s)" && ! has "$MO" "SKIP" || ok=0
  [ "$ok" = 1 ]
}
p_cs_noblock "$MERGE" && ok "CS11: a file carrying no provenance block (0 openings, 0 closings) in stories-fences-p1 and stories-amend-p1 -> SKIP, exit 3; one opening and no closing in the same dir -> REFUSED naming the block count (CS9 holds 0 openings, 1 closing)" \
  || bad "CS11: (rc=$RC) $(head -3 "$MO")"
# CS13/CS14: THE DOCUMENT FROM A SEALED SIBLING (BL-974). A document-mode shard whose WHOLE provenance block is
# deleted carries no `artifact:`, so its own bytes name no document; the merge's join refuses it on the block count.
# --check-shard takes the document from the SEALED siblings (cs_sealed, the agreement's definition: a sha= marker
# the merge's own admission admits) when every one that declares an `artifact:` declares the same one. Worlds are
# CS10's (doc_b3_world: sections: shards of test-strategy.md) and CS11's (stories-fences-p1 repair parts); every
# seal is the REAL --mark. cs_noblk deletes the block's lines, opener to closer, and nothing else.
cs_noblk() { awk '/SKILL_INVOCATION_PROVENANCE v1/ { skip = 1 } !skip { print } /SKILL_INVOCATION_PROVENANCE_END/ { skip = 0 }' "$1" > "$1.t" && mv "$1.t" "$1"; }
p_cs_docfb() { # CS13: 2.md, block deleted, beside a SEALED 1.md -> REFUSED with the block-count line the merge's join prints;
  # beside two SEALED siblings that disagree on artifact: -> SKIP with the disagreement WARN
  # The merge is asked BEFORE 1.md is sealed: with one shard marked and 2.md not, its marker-set check refuses first.
  local m="$1" d j
  d="$(doc_b3_world)" || return 1
  cs_noblk "$d/2.md"; ! has "$d/2.md" "SKILL_INVOCATION_PROVENANCE" && has "$d/2.md" "## Findings" || return 1
  run_doc_merge "$m" "$d"; j="$(grep -F "REFUSED: $d/2.md carries 0 provenance block opening(s)" "$MO" | head -1)"
  [ "$RC" -eq 2 ] && [ -n "$j" ] || return 1
  cs_seal "$d/1.md" 1 2 || return 1
  cs "$m" "$d/2.md" 2
  [ "$RC" -eq 2 ] && has "$MO" "$j" && ! has "$MO" "SKIP" || return 1
  # (c) two SEALED siblings disagree on artifact: no document is taken, SKIP as before, and the WARN only the
  # fallback prints names the disagreement
  d="$(doc_b3_world)" || return 1
  cs_seal "$d/1.md" 1 2 || return 1
  sed 's|^artifact: .*|artifact: _bmad-output/planning-artifacts/s1/other.md|' "$d/3.md" > "$d/3.t" && mv "$d/3.t" "$d/3.md"
  cs_seal_presib "$d/3.md" 3 2 || return 1
  cs_noblk "$d/2.md"; cs "$m" "$d/2.md" 2
  [ "$RC" -eq 3 ] && has "$MO" "SKIP: $d/2.md carries no provenance block" && has "$MO" "WARN: the sealed shards in" \
    && has "$MO" "disagree on artifact among themselves" && ! has "$MO" "REFUSED"
}
p_cs_docfb_near() { # CS14: the same block-less 2.md keeps today's SKIP wherever no sealed sibling declares a document
  local m="$1" d s ok=1
  d="$(doc_b3_world)" || return 1                                    # (b) every sibling carries artifact:, none sealed
  cs_noblk "$d/2.md"; cs "$m" "$d/2.md" 2
  [ "$RC" -eq 3 ] && has "$MO" "SKIP: $d/2.md carries no provenance block" && ! has "$MO" "REFUSED" || ok=0
  d="$(b3_world)" || return 1; s="$(dirname "$d")/stories-fences-p1"  # (d) CS11's dir: a SEALED sibling with no artifact:
  mkdir -p "$s" || return 1
  printf '# repair part\n\n- **disposition:** repaired\n- **edit:** `stories/story-1.md:3`\n' > "$s/1.md"
  printf '# repair part\n\n- **disposition:** repaired\n- **edit:** `stories/story-1.md:4`\n' > "$s/2.md"
  cs_seal_presib "$s/2.md" 2 0 || return 1
  has "$s/2.md" "sha=" && bash "$(dirname "$m")/content-seal.sh" --admit-marker "$s/2.md" >/dev/null 2>&1 || return 1 # sealed as cs_sealed reads it
  cs "$m" "$s/1.md" 0
  [ "$RC" -eq 3 ] && has "$MO" "SKIP: $s/1.md carries no provenance block" && ! has "$MO" "REFUSED" || ok=0
  [ "$ok" = 1 ]
}
p_cs_docfb "$MERGE" && ok "CS13: a document-mode shard with its whole provenance block deleted, beside a SEALED sibling naming the document -> --check-shard exit 2 with the merge join's own block-count refusal line, never SKIP; beside two SEALED siblings disagreeing on artifact: -> SKIP and the disagreement WARN" \
  || bad "CS13: (rc=$RC) $(head -3 "$MO")"
p_cs_docfb_near "$MERGE" && ok "CS14: the same block-less shard beside UNSEALED siblings only, and in stories-fences-p1 beside a SEALED (admitted) sibling with no artifact: -> SKIP, exit 3, as before" \
  || bad "CS14: (rc=$RC) $(head -3 "$MO")"
p_cs_flags() { # --check-shard-dir and --check-shard are two modes, told apart in both directions in one world.
  # (a) --check-shard-dir on a dir holding a shard --check-shard refuses (2.md, no verdict:): exactly the one
  #     `OK<TAB><dir>` line, rc 0, and none of --check-shard's lines (REFUSED:, SHARD-OK, SKIP:, its usage).
  # (b) --check-shard on 1.md, a path --check-shard-dir refuses (its parent is no shards/ dir): rc 0 SHARD-OK
  #     and none of --check-shard-dir's tab lines (OK, SKIP, REFUSED) or its usage.
  local m="$1" d ok=1; d="$(b3_world)" || return 1
  sed '/^verdict:/d' "$d/2.md" > "$d/2.t" && mv "$d/2.t" "$d/2.md" || return 1
  $ASM_RUN "$m" --check-shard-dir "$d" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && [ "$(cat "$MO")" = "$(printf 'OK\t%s' "$d")" ] \
    && ! has "$MO" "REFUSED: " && ! has "$MO" "SHARD-OK" && ! has "$MO" "SKIP: " && ! has "$MO" "--check-shard <shard-file>" || ok=0
  $ASM_RUN "$m" --check-shard "$d/1.md" --findings 2 > "$MO.b" 2>&1; RC_B=$?
  [ "$RC_B" -eq 0 ] && has "$MO.b" "SHARD-OK" && ! grep -q "$(printf '^\\(OK\\|SKIP\\|REFUSED\\)\t')" "$MO.b" \
    && ! has "$MO.b" "--check-shard-dir <planning>" || ok=0
  [ "$ok" = 1 ] || { cat "$MO.b" >> "$MO"; RC="$RC/$RC_B"; return 1; }
}
p_cs_flags "$MERGE" && ok "CS12: --check-shard-dir on a shard dir holding a shard --check-shard refuses -> exactly OK<TAB><dir>, rc 0, no --check-shard line; --check-shard on a file path --check-shard-dir refuses -> SHARD-OK, rc 0, no --check-shard-dir line" \
  || bad "CS12: (rc=$RC) $(head -4 "$MO")"
csd="$(b3_world)"; sed '/^verdict:/d' "$csd/2.md" > "$csd/2.t" && mv "$csd/2.t" "$csd/2.md"
eq_arm CS7a 2 "REFUSED: " "--check-shard refusing" - --check-shard "$csd/2.md" --findings 2
eq_arm CS7b 0 "SHARD-OK" "--check-shard passing" - --check-shard "$csd/1.md" --findings 2
# CS8: END TO END. The REAL --check-shard refusal flows through the REAL wait-for-deliverable.sh --mark, the merge
# file's own sibling (header terms 7: the mark resolves the merge beside itself), never a stand-in. A copied sibling
# set gets the shipped wait-for-deliverable.sh beside it, so a merge mutant is the merge the mark runs; a
# wait-for-deliverable.sh mutant (mutw) is built beside an unmutated merge. Each offender: exit 64, the shard's bytes
# unchanged (cmp), the merge's REFUSED line relayed and the mark's remedy; each corrected near-miss: MARKED.
cs_mk() { # <dir holding wait-for-deliverable.sh> <shard file> <shard> <n> -> RC, $MO, $WORK/cs-e2e.before
  cp "$2" "$WORK/cs-e2e.before" || return 1
  bash "$1/wait-for-deliverable.sh" --mark "$2" requirements adversary "$3" "findings=$4" > "$MO" 2>&1; RC=$?
}
cs_mk_refused() { # <shard file> <the merge's REFUSED line>
  [ "$RC" -eq 64 ] && cmp -s "$WORK/cs-e2e.before" "$1" && has "$MO" "$2" \
    && has "$MO" "the join's own check, refused '$1'; fix it in your file with Edit, then run the same --mark again"
}
cs_mk_marked() { # <shard file>
  [ "$RC" -eq 0 ] && has "$MO" "MARKED " && ! has "$MO" "REFUSED" && ! cmp -s "$WORK/cs-e2e.before" "$1" \
    && grep -q '^seat-complete: requirements adversary [0-9]* sha=[0-9a-f]\{64\} findings=1$' <<< "$(tail -1 "$1")"
}
p_cs_e2e() { # <merge>
  local m="$1" wd d w ok=1
  wd="$(dirname "$m")"; [ -f "$wd/wait-for-deliverable.sh" ] || cp "$WFD" "$wd/" || return 1
  for w in "requirements|requirements.md" "requirements.md|requirements"; do
    d="$(subj_b3_world)" || return 1
    cs_lr "$d/1.md" "${w%|*}"; cs_seal "$d/1.md" 1 1 || return 1
    cs_lr "$d/2.md" "${w#*|}"; cs_mk "$wd" "$d/2.md" 2 1
    cs_mk_refused "$d/2.md" "REFUSED: $d/2.md declares lead_role '${w#*|}' where the sealed shard $d/1.md declares '${w%|*}'" || ok=0
    cs_lr "$d/2.md" "${w%|*}"; cs_mk "$wd" "$d/2.md" 2 1                  # near-miss: the sealed sibling's spelling
    cs_mk_marked "$d/2.md" || ok=0
  done
  d="$(subj_b3_world)" || return 1
  has "$d/1.md" "SPEC@" || has "$d/1.md" "SPEC=" || return 1
  sed -E 's/^(artifact_sha:.* )SPEC([=@])/\1SPec\2/' "$d/1.md" > "$d/1.t" && mv "$d/1.t" "$d/1.md"
  cs_mk "$wd" "$d/1.md" 1 1
  cs_mk_refused "$d/1.md" "REFUSED: $d/1.md artifact_sha names stem 'SPec', not a subject stem" || ok=0
  sed -E 's/^(artifact_sha:.* )SPec([=@])/\1SPEC\2/' "$d/1.md" > "$d/1.t" && mv "$d/1.t" "$d/1.md"
  cs_mk "$wd" "$d/1.md" 1 1                                              # near-miss: the subject's own stem
  cs_mk_marked "$d/1.md" || ok=0
  [ "$ok" = 1 ]
}
p_cs_e2e "$MERGE" && ok "CS8: END TO END through the real wait-for-deliverable.sh --mark and the real merge --check-shard: lead_role 'requirements.md' against a SEALED 'requirements' sibling, the reverse, and artifact_sha stem SPec@ against SPEC@ -> exit 64, the shard byte-unchanged, the merge's REFUSED line relayed with the mark's remedy; each corrected spelling -> MARKED" \
  || bad "CS8: (rc=$RC) $(head -5 "$MO")"

# RM-A / RM-B: mutants of the merge, each in a copy of its whole sibling set, the anchor applied exactly once.
mut_merge() { # <old> <new> -> prints the mutated merge's path; empty when the anchor is not there once
  local md s
  md="$(mktemp -d "$WORK/rm.XXXXXX")" || return 1
  for s in merge-adversarial-shards.sh validate-adversarial-convergence.sh validate-steering-budget.sh partition-document.sh partition-subject.sh validate-artifact-budget.sh validate-provenance-block.sh content-seal.sh; do
    [ -f "$SRCDIR/$s" ] && cp "$SRCDIR/$s" "$md/"
  done
  M_OLD="$1" M_NEW="$2" python3 - "$md/merge-adversarial-shards.sh" <<'PY' || return 0
import os, sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read(); o = os.environ["M_OLD"]
if t.count(o) != 1: sys.exit(3)
open(p, "w", encoding="utf-8").write(t.replace(o, os.environ["M_NEW"]))
PY
  cmp -s "$MERGE" "$md/merge-adversarial-shards.sh" && return 0
  [ -f "$md/partition-document.sh" ] && [ -f "$md/validate-adversarial-convergence.sh" ] && bash -n "$md/merge-adversarial-shards.sh" || return 0
  printf '%s' "$md/merge-adversarial-shards.sh"
}
# ---- BL726: a shard's invoked_at sits between its dispatch's spawn-ledger ts and its last write row,
# within BACKDATE_TOL_S, REFUSED only for a dispatch whose spawn row carries invoked_bound (LEGACY: WARN).
bl726_clean "$MERGE"
bl726_merged && grep -qx 'invoked_at: 2026-08-24T15:01:19Z' "$(out_of "$BL_D")" \
  && ok "BL726a: the B3 world, spawn ts 15:00:00Z and every shard stamped after it -> MERGED, invoked_at 15:01:19Z" \
  || bad "BL726a: (rc=$RC) $(cat "$MO")"
p_bl726b "$MERGE" \
  && ok "BL726b: shard 1 stamped 13:00:00Z, two hours before its bound dispatch -> REFUSED naming 1.md, both times, the tolerance and the --rerun remedy; nothing written" \
  || bad "BL726b: (rc=$RC) $(cat "$MO")"
p_bl726c "$MERGE" \
  && ok "BL726c: shard 2's only write row at 14:00:00Z, its stamp 15:02:19Z -> REFUSED naming 2.md and both times; nothing written" \
  || bad "BL726c: (rc=$RC) $(cat "$MO")"
bl726_near "$MERGE"
bl726_merged && ok "BL726d: shard 1 stamped 59 s before its dispatch (inside BACKDATE_TOL_S) -> MERGED" || bad "BL726d: (rc=$RC) $(cat "$MO")"
bl726_frac "$MERGE"
bl726_merged && ok "BL726e: shard 1 stamped 14:59:30.750Z, fractional and inside the tolerance -> MERGED (the fraction is stripped before the epoch)" || bad "BL726e: (rc=$RC) $(cat "$MO")"
p_bl726f "$MERGE" \
  && ok "BL726f: the 13:00:00Z shard under a dispatch with no invoked_bound key (an older guard's row) -> MERGED, stderr WARN naming 1.md, both times and LEGACY" \
  || bad "BL726f: (rc=$RC) $(cat "$MO") $(cat "$MO.err")"
HR_BOUND=0 bl726_late "$MERGE"
bl726_merged && has "$MO.err" "WARN: " && has "$MO.err" "last wrote it at 2026-08-24T14:00:00Z" && has "$MO.err" "LEGACY" \
  && ok "BL726g: the LATE shard under a dispatch with no invoked_bound key -> MERGED, stderr WARN naming the write time and LEGACY" \
  || bad "BL726g: (rc=$RC) $(cat "$MO") $(cat "$MO.err")"
p_bl726h "$MERGE" \
  && ok "BL726h: shard 2 written at 14:00:00Z and 15:30:00Z, stamped 15:02:19Z between them -> MERGED (bounded by its LAST write row, never its first)" \
  || bad "BL726h: (rc=$RC) $(cat "$MO") $(cat "$MO.err")"
bl726_nocal "$MERGE"
bl726_refused "1.md invoked_at 2026-08-24T24:00:00Z is not a calendar time" "--rerun 1.md@" \
  && ok "BL726i: shard 1 stamped 2026-08-24T24:00:00Z (the shape passes, the calendar does not) under a bound dispatch -> REFUSED naming 1.md and its stamp; nothing written" \
  || bad "BL726i: (rc=$RC) $(cat "$MO") $(cat "$MO.err")"
HR_BOUND=0 bl726_nocal "$MERGE"
bl726_merged && has "$MO.err" "WARN: " && has "$MO.err" "1.md invoked_at 2026-08-24T24:00:00Z is not a calendar time" && has "$MO.err" "LEGACY" \
  && ok "BL726j: the same hour-24 stamp under a dispatch with no invoked_bound key -> MERGED, stderr WARN naming 1.md and LEGACY (fail-open)" \
  || bad "BL726j: (rc=$RC) $(cat "$MO") $(cat "$MO.err")"
for _bv in false '"true"'; do
  HR_BOUND_V="$_bv" bl726_early "$MERGE"
  bl726_merged && has "$MO.err" "WARN: " && has "$MO.err" "1.md claims invoked_at 2026-08-24T13:00:00Z" && has "$MO.err" "LEGACY" \
    && ok "BL726k: invoked_bound:$_bv on the spawn row (only the JSON boolean true binds) with the 13:00:00Z shard -> MERGED, LEGACY WARN" \
    || bad "BL726k: invoked_bound:$_bv gave rc=$RC: $(cat "$MO") $(cat "$MO.err")"
done

# R6: a finding heading EXACTLY as the real pass wrote it carries no severity word, so the heads
# counted (0 MAJOR) disagree with findings_major -- refused, never counted as zero.
p_r6() { # <merge> -> 0 iff the real-pass heading (no severity word) under findings_major: 1 is REFUSED on its count
  local d; d="$(b3_world)"
  {
    printf '## Findings\n\n%s\n\nstories: 1\n\n' "$(sed -n 1p "$HERE/seed.finding-headings.txt")"
    sed -n '/SKILL_INVOCATION_PROVENANCE v1/,$p' "$d/1.md" | sed 's/^findings_major: 2$/findings_major: 1/'
  } > "$d/1.tmp" && mv "$d/1.tmp" "$d/1.md"
  run_merge "$1" "$d"
  refused_clean "Findings section heads 0 CRITICAL / 0 MAJOR" "$d"
}
p_r6 "$MERGE" \
  && ok "R6: a real-pass heading with no severity word -> REFUSED on the count, never merged as 0 MAJOR" \
  || bad "R6: a heading without a severity word was not refused on its count (rc=$RC): $(cat "$MO")"

# P1: the merged pass is a provenance block the READER accepts. Its artifact_sha is the files-mode
# list `<stem>@<sha> ...` (the `@` a current tree's merge emits; `=` before it), which the schema's single-sha pattern refused, so every sharded pass
# failed validate-provenance-block.sh while the convergence validator passed it. The two
# near-misses keep the widening honest: a list of ONE (a merge always has two or more stories)
# and a list carrying a short sha are both refused, and a bare sha is the control that still passes.
p_pb "$MERGE"; r_p1=$?
case "$r_p1" in
  0) ok "P1: the merged pass ($PB_NPAIRS <stem>@<sha> pairs) passes validate-provenance-block.sh; a one-pair list and a short sha are refused; a bare sha still passes" ;;
  2) bad "P1: FIXTURE BROKEN -- validate-provenance-block.sh is not beside the merge at $SRCDIR" ;;
  3) bad "P1: FIXTURE BROKEN -- the B3 merge did not write a multi-file <stem>@<sha> artifact_sha (rc=$RC, pairs=${PB_NPAIRS:-0}, first='${PB_FIRST:-}')" ;;
  4) bad "P1: FIXTURE BROKEN -- the short-sha near-miss did not apply to the @ list" ;;
  *) bad "P1: provenance reader on the merged forms gave ${PB_RS:-?} (want 0 non-0 non-0 0)" ;;
esac

# ---- K: the separator the merge EMITS (--pair-sep). `@` only when every reader installed beside
# the merge accepts it: (a) validate-adversarial-convergence.sh and (b) partition-subject.sh each
# carry one `PAIR_SEP='[=@]'` line, and (c) validate-provenance-block.sh --accepts-at-pair exits 0
# on the schema ITS chain resolves. Each world is a tree laid out by hand in one layout -- `inst`
# (scripts/ai-dlc/ + .claude/schemas/, as install.sh lays a consumer out) or `core` (core/scripts/
# + core/schemas/) -- and every run sets AI_DLC_PROJECT_ROOT to the world (hermetic-run exports one).
# The three old readers are DERIVED from the current files at run time, never vendored: a pinned
# copy of core's own scripts under core/fixtures/ is a second corpus for the content-keyed arms.
# The key reads exactly three things, so each derivation removes exactly that one: the old VAC and
# the old partition-subject are the current files with their one `PAIR_SEP='[=@]'` line deleted;
# the old schema is the current one with the artifact_sha pattern's `[=@]` turned to `=` and
# `[^\s=@]` to `[^\s=]` (the pattern at 8df9b8ae6~1). Each derivation must differ from its source
# by `cmp -s`, and the schema's must make validate-provenance-block.sh --accepts-at-pair exit 1;
# otherwise K0 is FIXTURE BROKEN. Expectations are HARD-CODED, never read from --pair-sep: a
# merge that always printed `@` passes K1 and fails every K2 world, so the old worlds are what
# discriminates the key from a constant.
KSCH=""
_d="$SRCDIR"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _c in "$_d/core/schemas/provenance-block.json" "$_d/.claude/schemas/provenance-block.json"; do
    [ -f "$_c" ] && { KSCH="$_c"; break 2; }
  done
  _d="$(dirname "$_d")"
done
k_broken=""
for _f in "$KSCH" "$CONV" "$SRCDIR/partition-subject.sh" "$SRCDIR/validate-provenance-block.sh"; do
  [ -n "$_f" ] && [ -s "$_f" ] || k_broken="$k_broken ${_f:-<schema not found above $SRCDIR>}"
done
KOLD="$(mktemp -d "$WORK/kold.XXXXXX")" || exit 2
K_OLD_VAC="$KOLD/validate-adversarial-convergence.sh"; K_OLD_PS="$KOLD/partition-subject.sh"; K_OLD_SCH="$KOLD/provenance-block.json"
# Each derivation checks its anchor BEFORE it edits: an anchor not found exactly as expected is
# FIXTURE STALE, an edit leaving the file byte-identical is FIXTURE BROKEN; either names the anchor,
# no world is scored, and neither is ever a pass or a kill.
k_stale=""; K_A1=""; K_A0=""
k_drop_sep() { # <src> <out> <name> -- the source with its one PAIR_SEP='[=@]' line deleted
  local n0
  n0="$(grep -cxF "PAIR_SEP='[=@]'" "$1")" || n0=0
  [ "$n0" = 1 ] || { k_stale="$k_stale $3(anchor ^PAIR_SEP='[=@]'\$ found $n0 times, want 1)"; return 0; }
  grep -vxF "PAIR_SEP='[=@]'" "$1" > "$2"
  cmp -s "$1" "$2" && k_broken="$k_broken $3(deleting ^PAIR_SEP='[=@]'\$ left the file byte-identical)"
  return 0
}
k_old_schema() { # <src> <out> -- the artifact_sha pattern back to the `=`-only form; must make --accepts-at-pair exit 1
  local rc r a1 a0
  python3 - "$1" "$2" <<'PY'
import sys
src, out = sys.argv[1], sys.argv[2]
lines = open(src, encoding="utf-8").read().split("\n")
hits = [i for i, l in enumerate(lines) if l.lstrip().startswith('"artifact_sha": "^')]
if len(hits) != 1: sys.exit(3)
l = lines[hits[0]]
if l.count("[=@]") != 2 or l.count("[^\\\\s=@]") != 2: sys.exit(3)
lines[hits[0]] = l.replace("[=@]", "=").replace("[^\\\\s=@]", "[^\\\\s=]")
open(out, "w", encoding="utf-8").write("\n".join(lines))
PY
  rc=$?
  [ "$rc" = 3 ] && { k_stale="$k_stale old-schema(anchor: one \"artifact_sha\": \"^ pattern line carrying [=@] twice and [^\\\\s=@] twice, not found)"; return 0; }
  [ "$rc" = 0 ] || { k_broken="$k_broken old-schema(derivation exited $rc)"; return 0; }
  cmp -s "$1" "$2" && { k_broken="$k_broken old-schema(the [=@] / [^\\\\s=@] edit left the file byte-identical)"; return 0; }
  # The derivation must BITE: the current validator exits 1 over it, and 0 over its source.
  r="$(mktemp -d "$WORK/ksch.XXXXXX")" && mkdir -p "$r/core/schemas" && cp "$2" "$r/core/schemas/provenance-block.json" \
    || { k_broken="$k_broken old-schema(probe root did not build)"; return 0; }
  AI_DLC_PROJECT_ROOT="$r" bash "$SRCDIR/validate-provenance-block.sh" --accepts-at-pair >/dev/null 2>&1; a1=$?
  cp "$1" "$r/core/schemas/provenance-block.json"
  AI_DLC_PROJECT_ROOT="$r" bash "$SRCDIR/validate-provenance-block.sh" --accepts-at-pair >/dev/null 2>&1; a0=$?
  [ "$a1" = 1 ] && [ "$a0" = 0 ] || k_broken="$k_broken old-schema(--accepts-at-pair exited $a1 on the derivation and $a0 on its source, want 1 and 0)"
  K_A1="$a1"; K_A0="$a0"
  return 0
}
if [ -z "$k_broken" ]; then
  k_drop_sep "$CONV" "$K_OLD_VAC" old-VAC
  k_drop_sep "$SRCDIR/partition-subject.sh" "$K_OLD_PS" old-partition-subject
  k_old_schema "$KSCH" "$K_OLD_SCH"
fi
# kl_world <layout inst|core> <swap none|vac|ps|sch> <merge file> -> prints the world root
kl_world() {
  local w s c
  w="$(mktemp -d "$WORK/kw-$1-$2.XXXXXX")" || return 1
  if [ "$1" = inst ]; then s="$w/scripts/ai-dlc"; c="$w/.claude/schemas"
  else s="$w/core/scripts"; c="$w/core/schemas"; mkdir -p "$w/core/skills/ai-dlc" || return 1; fi
  mkdir -p "$s" "$c" || return 1
  cp "$3" "$s/merge-adversarial-shards.sh" && cp "$CONV" "$s/" && cp "$SRCDIR/partition-subject.sh" "$s/" \
    && cp "$SRCDIR/validate-provenance-block.sh" "$s/" && cp "$SRCDIR/partition-document.sh" "$s/" \
    && cp "$SRCDIR/validate-artifact-budget.sh" "$s/" \
    && cp "$KSCH" "$c/provenance-block.json" || return 1
  case "$2" in
    vac) cp "$K_OLD_VAC" "$s/validate-adversarial-convergence.sh" ;;
    ps)  cp "$K_OLD_PS" "$s/partition-subject.sh" ;;
    sch) cp "$K_OLD_SCH" "$c/provenance-block.json" ;;
  esac || return 1
  printf '%s' "$w"
}
k_dir() { [ "$1" = inst ] && printf 'scripts/ai-dlc' || printf 'core/scripts'; } # <layout>
# k_ps <world> <layout> [override root] -> the answer, as `@`, `=`, or `BAD(<rc>,<bytes>)`
k_ps() {
  local o="$WORK/kps.out" r n
  AI_DLC_PROJECT_ROOT="${3:-$1}" $ASM_RUN "$1/$(k_dir "$2")/merge-adversarial-shards.sh" --pair-sep > "$o" 2>/dev/null; r=$?
  n="$(wc -c < "$o" | tr -d ' ')"
  if [ "$r" -eq 0 ] && [ "$n" = 1 ] && { [ "$(cat "$o")" = "@" ] || [ "$(cat "$o")" = "=" ]; }; then cat "$o"
  else printf 'BAD(%s,%s)' "$r" "$n"; fi
}
# k_differs <world> <layout> <swap> -- the swapped reader really is not the current one (cmp)
k_differs() {
  case "$3" in
    vac) ! cmp -s "$CONV" "$1/$(k_dir "$2")/validate-adversarial-convergence.sh" ;;
    ps)  ! cmp -s "$SRCDIR/partition-subject.sh" "$1/$(k_dir "$2")/partition-subject.sh" ;;
    sch) if [ "$2" = inst ]; then ! cmp -s "$KSCH" "$1/.claude/schemas/provenance-block.json"
         else ! cmp -s "$KSCH" "$1/core/schemas/provenance-block.json"; fi ;;
  esac
}
# Mutants of the key, each a COPY of the merge with one conjunct's line deleted, keyed on the
# conjunct's own token: the token counts 1 in the merge and 0 in the mutant, and the copy differs.
k_mut() { # <out> <token>
  local n0 n1
  n0="$(grep -cF -- "$2" "$MERGE")" || n0=0
  sed "/$(printf '%s' "$2" | sed 's/[][\/.*$^]/\\&/g')/d" "$MERGE" > "$1" || return 1
  n1="$(grep -cF -- "$2" "$1")" || n1=0
  [ "$n0" = 1 ] && [ "$n1" = 0 ] && ! cmp -s "$MERGE" "$1"
}
KMB="$WORK/merge.mut-b.sh"; KMC="$WORK/merge.mut-c.sh"
k_mut "$KMB" '"$d/partition-subject.sh" 2>/dev/null' || k_broken="$k_broken mutant-b(did-not-apply)"
k_mut "$KMC" '--accepts-at-pair >/dev/null' || k_broken="$k_broken mutant-c(did-not-apply)"
# The EMITTER mutant for KE: the run's separator keyed on the VAC sibling alone, while pair_sep() and
# --pair-sep stay three-keyed -- so every K1/K2/KM arm, which reads --pair-sep, passes it.
KM593="$WORK/merge.mut-593.sh"
K593_LINE="$(cat <<'EOF'
PAIR_OUT='='; grep -qxF "PAIR_SEP='[=@]'" "$(dirname "$MERGE_SELF")/validate-adversarial-convergence.sh" && PAIR_OUT=@
EOF
)"
k593_n0="$(grep -c "^PAIR_OUT='='; " "$MERGE")" || k593_n0=0
sed "s|^PAIR_OUT='='; .*|$(printf '%s' "$K593_LINE" | sed 's/[&|\\]/\\&/g')|" "$MERGE" > "$KM593" || k_broken="$k_broken mutant-593(sed failed)"
k593_n1="$(grep -cxF -- "$K593_LINE" "$KM593")" || k593_n1=0
[ "$k593_n0" = 1 ] && [ "$k593_n1" = 1 ] || k_broken="$k_broken mutant-593(anchor ^PAIR_OUT='='; found $k593_n0 times, mutant line $k593_n1 times; want 1 and 1)"
cmp -s "$MERGE" "$KM593" && k_broken="$k_broken mutant-593(byte-identical to the merge)"
if [ -n "$k_stale" ] || [ -n "$k_broken" ]; then
  [ -z "$k_stale" ] || bad "K0: FIXTURE STALE -- anchor not found:$k_stale; re-anchor the derivation, no K arm was asserted"
  [ -z "$k_broken" ] || bad "K0: FIXTURE BROKEN -- missing or unbuildable:$k_broken; no K arm was asserted"
else
  ok "K0: three old readers derived from the current files -- VAC and partition-subject each with its one PAIR_SEP='[=@]' line deleted (differ by cmp), the schema's artifact_sha pattern turned back to '='; validate-provenance-block.sh --accepts-at-pair exits $K_A1 on the derived schema and $K_A0 on its source"
  KOK=1
  for L in inst core; do
    # K1: current readers -> `@`.
    w="$(kl_world "$L" none "$MERGE")" && a="$(k_ps "$w" "$L")" || a="BUILD"
    [ "$a" = "@" ] && ok "K1-$L: $L layout, every reader current -> --pair-sep prints exactly one byte '@', exit 0" \
      || bad "K1-$L: $L layout with current readers gave '$a' (want @)"
    # K2: ONE old reader, derived from the current file (K0) -> `=`, each world first proven to differ from the current one.
    # Only the vac world is a base cell here: it is the K mutants' twin. The ps and sch old readers are scored
    # end to end by KE below (KEps_inst, KEsch_core), the cells the kill matrix shows kill every K mutant.
    for S in vac; do
      w="$(kl_world "$L" "$S" "$MERGE")" || { bad "K2$S-$L: FIXTURE BROKEN -- world did not build"; continue; }
      if ! k_differs "$w" "$L" "$S"; then bad "K2$S-$L: FIXTURE BROKEN -- the old-$S world is byte-identical to the current one"; continue; fi
      a="$(k_ps "$w" "$L")"
      [ "$a" = "=" ] && ok "K2$S-$L: $L layout, the old $S reader (derived from the current file, differs by cmp) -> --pair-sep prints '='" \
        || bad "K2$S-$L: $L layout with the old $S reader gave '$a' (want =)"
    done
  done
  # K3: an override root carrying the OLD schema in core/schemas, the install carrying the new ->
  # the validator's chain takes the override's first, so `=`. Its twin, an override root with NO
  # schema, falls through to the install's and prints `@`: the override is what moved the answer.
  w="$(kl_world inst none "$MERGE")"; ov="$(mktemp -d "$WORK/kov.XXXXXX")"; ov0="$(mktemp -d "$WORK/kov0.XXXXXX")"
  mkdir -p "$ov/core/schemas" && cp "$K_OLD_SCH" "$ov/core/schemas/provenance-block.json"
  a="$(k_ps "$w" inst "$ov")"; a0="$(k_ps "$w" inst "$ov0")"
  [ "$a" = "=" ] && [ "$a0" = "@" ] && ok "K3: AI_DLC_PROJECT_ROOT with the old schema in core/schemas over a current install -> '='; the same override with no schema -> '@'" \
    || bad "K3: override with the old schema gave '$a' (want =), override with none gave '$a0' (want @)"
  # KE: the EMITTER, end to end. K1-K3 read --pair-sep; this drives the merge itself (subject mode)
  # once per world and reads the separator of every pair in the artifact_sha list it wrote. One
  # subject world serves every drive: each output is moved aside, so the next drive writes afresh.
  # Expectations are hard-coded: `@` with every reader current, `=` in each old-reader world.
  # The world is SHARED by every drive, so a parallel --matrix worker builds its own (mx_enqueue clears KE_SD and
  # kearm calls ke_build): two rows driving one world at once read each other's output as already written.
  ke_build() {
    KE_SD="$(new_subj_world)" && {
      for k in $(cut -f1 "$(subj_root "$KE_SD")/subject.map"); do sshard "$KE_SD" "$k" 0 "$k"; done
      for k in $(subj_xkeys "$KE_SD"); do sshard "$KE_SD" "$k" 0 "1, 2"; done; }
  }
  ke_build
  # k_drive <world> <merge in that world> -> `@` or `=` when every pair carries that one separator, else BAD(...)
  k_drive() {
    local o lst tok s seps="" n=0 r
    AI_DLC_PROJECT_ROOT="$1" $ASM_RUN "$2" --subject 9 "$KE_SD" > "$WORK/ke.out" 2>&1; r=$?
    o="$(subj_out_of "$KE_SD")"
    { [ "$r" -eq 0 ] && [ -f "$o" ]; } || { printf 'BAD(rc=%s:%s)' "$r" "$(head -1 "$WORK/ke.out")"; return 0; }
    lst="$(sed -n 's/^artifact_sha://p' "$o" | head -1)"
    mv "$o" "$(mktemp "$WORK/ke-out.XXXXXX")" || { printf 'BAD(mv)'; return 0; }
    for tok in $lst; do
      n=$((n + 1)); case "$tok" in *@*) s=@ ;; *=*) s='=' ;; *) s='?' ;; esac
      case "$seps" in *"$s"*) ;; *) seps="$seps$s" ;; esac
    done
    if [ "$n" -ge 2 ] && [ "${#seps}" = 1 ]; then printf '%s' "$seps"; else printf 'BAD(pairs=%s,seps=%s)' "$n" "$seps"; fi
  }
  ke_n="$(ls "$KE_SD" 2>/dev/null | grep -c '^cross.*\.md$')" || ke_n=0
  if [ -z "$KE_SD" ] || [ "$ke_n" -lt 1 ]; then
    bad "KE: FIXTURE BROKEN -- the subject world for the end-to-end drives did not build"
  else
    # One old-reader killer per layout: ps in inst, sch in core (the irredundant cover of the K mutants).
    for L in inst core; do
      row=""
      if [ "$L" = inst ]; then ke_sw="none vac ps"; want=" none=@ vac== ps=="; else ke_sw="none vac sch"; want=" none=@ vac== sch=="; fi
      for S in $ke_sw; do
        w="$(kl_world "$L" "$S" "$MERGE")" && row="$row $S=$(k_drive "$w" "$w/$(k_dir "$L")/merge-adversarial-shards.sh")" || row="$row $S=BUILD"
      done
      [ "$row" = "$want" ] && ok "KE-$L: $L layout, the merge itself (subject mode) writes every artifact_sha pair with '@' when every reader is current and '=' in each old-reader world:$row" \
        || bad "KE-$L: the merge's emitted separators were$row (want$want)"
    done
  fi
fi

# ---- THE DERIVED SET (BL-911): a pass after a series' first reviews only the repair. lib.sh's dv worlds: eight
# stories, the rulebook carrying the era token committed at a fixed 2026-01-01, p1 merged, stories 3 and 6
# repaired on disk, only 3 cited by the joined repair record.
if ! dv_rulebook; then bad "DV: FIXTURE BROKEN -- _gate-procedures.md not found above $LIB_DIR; no derived-set arm can bind"
else
  echo "HERMETIC-CONSUMED $RULEBOOK"
  p_dv2 "$MERGE" && ok "DV2: story 6, changed on disk and cited by no edit: line (a serial edit), is in the set {$DV_ORDS}" || bad "DV2: ords [$DV_ORDS]"
  p_dv3 "$MERGE" && ok "DV3: p1's MAJOR on unedited story 5 and its repaired + 'edit: n/a' MAJOR on story 7 keep both in: {3 5 6 7}" || bad "DV3: ords [$DV_ORDS], want [3 5 6 7]"
  p_dv4 "$MERGE" && ok "DV4: a story sorting FIRST shifts every ordinal; keyed on basename the set is {1 4 6 7 8}" || bad "DV4: ords [$DV_ORDS], want [1 4 6 7 8]"
  p_dv4d "$MERGE" && ok "DV4D: --document after p1, Section 2b inserted and Section 4 edited: {3 5 7}, the cited unchanged Section 6 owed at its NEW ordinal 7 (ordinal join {3 4 5 6 7 8}, cite-by-ordinal {3 5 6})" || bad "DV4D: ords [$DV_ORDS] hdr [$DV_HDR] ${PC_WHY:-}, want {3 5 7}"
  p_pc1 "$MERGE" && ok "PC1: a repack (Section 2 grows, Section 4 edited, seven parts become five): {2 3 4}, not the byte-identical Section 7 at another ordinal (ordinal and line-range joins {2 3 4 5})" || bad "PC1: ords [$DV_ORDS] hdr [$DV_HDR] ${PC_WHY:-}, want {2 3 4}"
  p_pcd "$MERGE" && ok "PCD: Section 3 rewritten into a byte copy of Section 5: both copies owed, {3 5 6} (a presence join owes {6})" || bad "PCD: ords [$DV_ORDS] ${PC_WHY:-}, want {3 5 6}"
  p_pct "$MERGE" && ok "PCT: a 260-row table cut into a notarized run, only the header piece changed: every member of p1's part_run owed (the content join alone owes one)" || bad "PCT: ords [$DV_ORDS] run [${PC_RUN:-}] ${PC_WHY:-}"
  p_pct2 "$MERGE" && ok "PCT2: a table cut into exactly two pieces, the header piece packed under Section 1, only the header changed: both pieces owed (ignoring the run owes {1})" || bad "PCT2: ords [$DV_ORDS] run [${PC_RUN:-}] ${PC_WHY:-}"
  p_pcc "$MERGE" && ok "PCC: a plain row before a run edited: {1} only, never the run beside it" || bad "PCC: ords [$DV_ORDS] run [${PC_RUN:-}] ${PC_WHY:-}, want {1}"
  p_pcsr "$MERGE" && ok "PCSR: subject, a table added since base inside prd, cut into a run mapped onto GLOBAL ordinals (every member a prd.md row, the header inside the first): its header changed, the whole run owed" || bad "PCSR: ords [$DV_ORDS] run [${PC_RUN:-}] ${PC_WHY:-}"
  p_pcs "$MERGE" && ok "PCS: subject, the brief leaves scope (ordinals drop by one), Goals grows, Requirements edited: {1 3 4}, the cited SPEC at its new ordinal 1 (cite-by-ordinal {2 3 4}, ordinal join the whole map)" || bad "PCS: ords [$DV_ORDS] ${PC_WHY:-}, want {1 3 4}"
  p_pcs2 "$MERGE" && ok "PCS2: subject, SPEC.md rewritten into architecture-impact.md's bytes: keyed (file, digest) only SPEC is owed, {2} (digest alone {2 6})" || bad "PCS2: ords [$DV_ORDS] ${PC_WHY:-}, want {2}"
  p_pck "$MERGE" && ok "PCK: K4 controls -- the unedited document world owes {6} and PCC's edited world {1}, narrowed in --derived-map and --derived-set alike" || bad "PCK: ${PC_CELL:-}: ${PC_WHY:-}"
  p_pcka "$MERGE" && ok "PCKa: p1 without part_sha: the FULL map with its reason, byte-identical in --derived-map and --derived-set" || bad "PCKa: ${PC_WHY:-}"
  p_pckb "$MERGE" && ok "PCKb: pass M without its own part_sha (p1 has one): --derived-set owes the FULL map with its reason, never narrowed" || bad "PCKb: ${PC_WHY:-}"
  p_pckc "$MERGE" && ok "PCKc: a malformed part_sha token in p1: the FULL map with its reason, both programs alike" || bad "PCKc: ${PC_WHY:-}"
  p_pckd "$MERGE" && ok "PCKd: p1's part_sha one entry short of its map: the FULL map with its reason, both programs alike" || bad "PCKd: ${PC_WHY:-}"
  p_pcke "$MERGE" && ok "PCKe: p1 without part_run: the FULL map with its reason, both programs alike" || bad "PCKe: ${PC_WHY:-}"
  p_pckf "$MERGE" && ok "PCKf: pass M without its own part_run: --derived-set owes the FULL map with its reason, never narrowed" || bad "PCKf: ${PC_WHY:-}"
  p_pckg "$MERGE" && ok "PCKg: p1's part_run naming an ordinal outside its map: the FULL map with its reason, both programs alike" || bad "PCKg: ${PC_WHY:-}"
  p_pckh "$MERGE" && ok "PCKh: a one-member run in p1's part_run: the FULL map with its reason, both programs alike" || bad "PCKh: ${PC_WHY:-}"
  p_pce "$MERGE" && ok "PCE: D1 -- a LEGACY series and a NOTOKEN rulebook each owe the FULL map with their reason, identical in --derived-map and --derived-set (bound: PCK's control {6})" || bad "PCE: cell ${PC_CELL:-?}: ${PC_WHY:-}"
  p_pcr "$MERGE" && ok "PCR: an identical re-merge over an old-engine document or subject pass (no part_sha:/part_run:) is UNCHANGED (and --dry-run clean) and leaves the file byte-for-byte; a same-engine re-merge is UNCHANGED; a pass with part_sha: but no part_run:, and one differing in a counted field, still refuse" || bad "PCR: cell ${PC_CELL:-?}: ${PC_WHY:-}"
  p_pckm "$MERGE" && ok "PCKm: a malformed, repeated or outside run in SECOND position of p1's part_run (1,2;3 / 1,2;2,3 / 1,2;3,99) owes the FULL map with its reason in both programs; near-misses: a good-only 1,2 narrows to {1}, a first-position 3;1,2 is FULL" || bad "PCKm: cell ${PC_CELL:-?}: ${PC_WHY:-}"
  p_pcmv "$MERGE" && ok "PCMV: SPEC.md moved between the part-digest hashing and the check (in-process seam, the merge's own sha_of wrapped) -> REFUSED naming it, p1 byte-unchanged; near-miss: the unhooked re-merge is UNCHANGED" || bad "PCMV: cell ${PC_CELL:-?}: ${PC_WHY:-}"
  p_pcn2 "$MERGE" && ok "PCN2: --part-sha --rows --scope-ref with a scope list the scoped map cannot read (rc=2) REFUSES and prints no run; near-miss: unwrapped, the same rows print the prd table's run" || bad "PCN2: cell ${PC_CELL:-?}: ${PC_WHY:-}"
  p_ndp "$MERGE" && ok "NDP: arm N's document self-probe -- the gate exits 2 'arm N document self-probe failed' when the merge beside it holds document mode at full width; near-miss: the shipped sibling set passes it" || bad "NDP: cell ${PC_CELL:-?}: ${PC_WHY:-}"
  p_ndc "$MERGE" && ok "NDC: TMPDIR inside a git work tree (git sees it from there) -- the shipped validator's document self-probe passes; a copy with the ceiling put back at the probe root exits 2 'arm N document self-probe failed'" || bad "NDC: cell ${PC_CELL:-?}: ${PC_WHY:-}"
  p_dv5 "$MERGE" && ok "DV5: p1's sha list unreadable -> the FULL map, and the header says why" || bad "DV5: ords [$DV_ORDS] hdr [$DV_HDR]"
  p_dv10 "$MERGE" && ok "DV10: p3 with no p2 on disk derives from p1 (series order); a dispatch adding underived shard 1 is REFUSED, nothing written (DV1); the merge of 3 and 6 stamps p1 and notarizes all 8 stems at their disk shas (DV7); arm N reads p1 as its predecessor, and the same pass dispatching {1 3 6} (a superset) FAILS owed {3 6} (DV6 superset half; the subset half is held by DVRS)" \
    || bad "DV10: failed at stage ${DV_STAGE:-?}: rc=$RC ords [$DV_ORDS] hdr [$DV_HDR] $(head -1 "$MO") $(grep -m2 'FAIL (N' "$CO")"
  if [ -f "$SRCDIR/serial-remediation-worklist.sh" ]; then
    echo "HERMETIC-CONSUMED $SRCDIR/serial-remediation-worklist.sh"
    p_dvrs "$MERGE" && ok "DVRS: document mode, the shipped sequence (split on p1's sha, a section edited, assembled, the worklist consuming .before): --derived-map prints exactly the --map rows {4 6} with no full-width reason, the full map dispatched is REFUSED, the derived p2 merges derived from p1, the gate reads no FAIL (N, and arm N FAILs a superset and a subset of {4 6} (N4); a files world in the same arm still narrows to {3 6}" \
      || bad "DVRS: rc=$RC ords [$DV_ORDS] $(head -2 "$WORK/dvrs.err" 2>/dev/null) | $(head -2 "$MO") | $(grep -m2 'FAIL (N' "$CO")"
    p_dvrss "$MERGE" && ok "DVRSS: subject mode, the shipped sequence (split on p1's sha list, a prd section edited, assembled, the worklist consuming prd's and SPEC's .before): exactly the --map rows {2 3}, the full map REFUSED, p2 merges derived from p1, the gate reads no FAIL (N, and arm N FAILs a superset and a subset (N4)" \
      || bad "DVRSS: rc=$RC $(head -2 "$WORK/dvrs.err" 2>/dev/null) | $(head -2 "$MO") | $(head -2 "$WORK/dvrss.split" 2>/dev/null) | $(grep -m2 'FAIL (N' "$CO")"
  else bad "DVRS: FIXTURE BROKEN -- serial-remediation-worklist.sh is not beside the merge; the shipped sequence cannot run"; fi
fi

# ---- THE MUTANTS. Each is a COPY of the merge's whole sibling set (or of the provenance schema) with one
# anchor changed, built by mut_merge, which refuses a lost or repeated anchor. PER PUSH a mutant runs its
# DECIDING arm, which must FAIL, and one TWIN, an arm the measured matrix shows GREEN for it, which must
# PASS; the kill is emitted through mutant_killed behind the same-run base-pass flags of both arms and of
# the unmutated copy (MX0). --matrix scores the unmutated copy and every mutant against EVERY arm and
# prints one MATRIX row per cell (matrix_row, core/fixtures/lib/matrix.sh), `killed=yes` iff THAT arm tripped.
n_mut=0; n_kill=0
ARMS_ALL="A1 M0 R6 D2 D3 D4 D5 D6 X1 X4 RS1 CH2 FI1 FI2 FI3a FI3b FIF FIE FIS FISa B726B B726C B726F B726H P1 PBARE DV2 DV3 DV4 DV4D DV5 DV10 DVRS DVRSS PC1 PCD PCT PCT2 PCC PCSR PCS PCS2 PCK PCKa PCKb PCKc PCKd PCKe PCKf PCKg PCKh PCE PCR PCKm PCMV PCN2 NDP NDC TR1 FG2 RR3 RR6a RR6n RR6b RR6c RR6d RR6e RR6f RR6g CS1 CS2 CS3 CS4 CS5 CS6 CS8 CS9 CS10 CS11 CS12 CS13 CS14"
[ "$KOK" = 1 ] && ARMS_ALL="$ARMS_ALL K1_inst K1_core K2vac_inst K2vac_core KEnone_inst KEvac_inst KEps_inst KEnone_core KEvac_core KEsch_core"
karm() { # <merge file> <swap> <layout> <want> -- --pair-sep answer in that world
  local w a
  w="$(kl_world "$3" "$2" "$1")" && a="$(k_ps "$w" "$3")" || return 1
  [ "$a" = "$4" ]
}
kearm() { # <merge file> <swap> <layout> <want> -- the separator the merge itself writes in that world
  local w a
  [ -n "${KE_SD:-}" ] || ke_build || return 1
  w="$(kl_world "$3" "$2" "$1")" || return 1
  a="$(k_drive "$w" "$w/$(k_dir "$3")/merge-adversarial-shards.sh")"
  [ "$a" = "$4" ]
}
arm_run() { # <arm> <merge file> -> 0 iff the arm HOLDS
  case "$1" in
    A1) p_b3 "$2" ;;
    M0) p_m0 "$2" ;;
    R6) p_r6 "$2" ;;
    D2) p_doc_axis "$2" ;;
    D3) p_doc_sha "$2" ;;
    D4) p_doc_path "$2" ;;
    D5) p_doc_serial "$2" ;;
    D6) p_files_golden "$2" ;;
    X1) p_xfiles "$2" ;;
    X4) p_xmix "$2" ;;
    RS1) p_rs1 "$2" ;;
    FI1) p_t1 "$2" ;;
    FI2) p_t2 "$2" ;;
    FI3a) p_t3a "$2" ;;
    FI3b) p_t3b "$2" ;;
    FIF) p_d1 "$2" ;;
    FIE) p_elic "$2" ;;
    FIS) p_sh_refuse "$2" ;;
    FISa) p_sh_accept "$2" ;;
    CH2) p_chv "$2" ;;
    B726B) p_bl726b "$2" ;;
    B726C) p_bl726c "$2" ;;
    B726F) p_bl726f "$2" ;;
    B726H) p_bl726h "$2" ;;
    P1) p_pb "$2" ;;
    PBARE) p_pbbare "$2" ;;
    DV2) p_dv2 "$2" ;;
    DV3) p_dv3 "$2" ;;
    DV4) p_dv4 "$2" ;;
    DV4D) p_dv4d "$2" ;;
    DV5) p_dv5 "$2" ;;
    DV10) p_dv10 "$2" ;;
    DVRS) p_dvrs "$2" ;;
    DVRSS) p_dvrss "$2" ;;
    PC1) p_pc1 "$2" ;;
    PCD) p_pcd "$2" ;;
    PCT) p_pct "$2" ;;
    PCT2) p_pct2 "$2" ;;
    PCC) p_pcc "$2" ;;
    PCSR) p_pcsr "$2" ;;
    PCS) p_pcs "$2" ;;
    PCS2) p_pcs2 "$2" ;;
    PCK) p_pck "$2" ;;
    PCK[a-h]) "p_pck${1#PCK}" "$2" ;;
    PCE) p_pce "$2" ;;
    PCR) p_pcr "$2" ;;
    PCKm) p_pckm "$2" ;;
    PCMV) p_pcmv "$2" ;;
    PCN2) p_pcn2 "$2" ;;
    NDP) p_ndp "$2" ;;
    NDC) p_ndc "$2" ;;
    TR1) p_tree "$2" ;;
    FG2) p_fence_unclosed "$2" ;;
    RR3) p_rerun_same "$2" ;;
    RR6a) p_dw_rerun "$2" ;;
    RR6n) p_dw_plain "$2" ;;
    RR6b) p_dw_twin "$2" ;;
    RR6c) p_dw_tie "$2" ;;
    RR6d) p_dw_out "$2" ;;
    RR6e) p_dw_role "$2" ;;
    RR6f) p_dw_draft "$2" ;;
    RR6g) p_dw_straddle_draft "$2" ;;
    CS1) p_cs_lead "$2" ;;
    CS2) p_cs_cite "$2" ;;
    CS3) p_cs_stem "$2" ;;
    CS4) p_cs_opener "$2" ;;
    CS5) p_cs_skip "$2" ;;
    CS6) p_cs_bytes "$2" ;;
    CS8) p_cs_e2e "$2" ;;
    CS9) p_cs_selffirst "$2" ;;
    CS10) p_cs_docsel "$2" ;;
    CS11) p_cs_noblock "$2" ;;
    CS13) p_cs_docfb "$2" ;;
    CS14) p_cs_docfb_near "$2" ;;
    CS12) p_cs_flags "$2" ;;
    K1_*) karm "$2" none "${1#K1_}" "@" ;;
    K2vac_*) karm "$2" vac "${1#K2vac_}" "=" ;;
    KEnone_*) kearm "$2" none "${1#KEnone_}" "@" ;;
    KEvac_*) kearm "$2" vac "${1#KEvac_}" "=" ;;
    KEps_*) kearm "$2" ps "${1#KEps_}" "=" ;;
    KEsch_*) kearm "$2" sch "${1#KEsch_}" "=" ;;
    *) return 1 ;;
  esac
}
armlabel() { # <arm> -> the label of the ok line that records the arm passing on the SHIPPED merge in this run
  case "$1" in
    B726B) echo BL726b ;; B726C) echo BL726c ;; B726F) echo BL726f ;; B726H) echo BL726h ;; PBARE) echo P1 ;;
    K2vac_*) echo "${1%%_*}-${1#*_}" ;;
    KE*_*) echo "KE-${1#*_}" ;;
    K1_*) echo "K1-${1#K1_}" ;;
    *) echo "$1" ;;
  esac
}
bflag() { case "$OKSET" in *"|$(armlabel "$1")|"*) echo 1 ;; *) echo 0 ;; esac; } # <arm> -> 1 iff its base ok line printed this run
in_set() { case " $2 " in *" $1 "*) return 0 ;; esac; return 1; } # <arm> <space-separated set>
sc_run() { # <merge file> <arm>... -> SC_DEAD, the arms that TRIPPED (did not hold), in the order given
  local mf="$1" a sd s ms; shift; SC_DEAD=""
  # A lone mutated file (the K mutants) finds no siblings, so every non-K arm would trip for THAT reason.
  # Non-K arms therefore run the mutated merge inside a copy of the whole sibling set.
  ms="$mf"
  if [ ! -f "$(dirname "$mf")/partition-document.sh" ]; then
    sd="$(mktemp -d "$WORK/sib.XXXXXX")"
    for s in merge-adversarial-shards.sh validate-adversarial-convergence.sh validate-steering-budget.sh partition-document.sh partition-subject.sh validate-artifact-budget.sh validate-provenance-block.sh content-seal.sh; do
      [ -f "$SRCDIR/$s" ] && cp "$SRCDIR/$s" "$sd/"
    done
    cp "$mf" "$sd/merge-adversarial-shards.sh"; ms="$sd/merge-adversarial-shards.sh"
  fi
  for a in "$@"; do
    case "$a" in
      K*) arm_run "$a" "$mf" || SC_DEAD="$SC_DEAD $a" ;;
      *) arm_run "$a" "$ms" || SC_DEAD="$SC_DEAD $a" ;;
    esac
  done
  SC_DEAD="${SC_DEAD# }"
}
mrow() { matrix_row "$1" "$2" 0 "$3" "$4"; MATRIX_ROWS=$((MATRIX_ROWS + 1)); } # <id> <arm> <GREEN|TRIPPED> <yes|no>
mx_cells() { # <id> -> one MATRIX row per arm of MX_ARMS (ARMS_ALL unless --arms= narrows it), from SC_DEAD
  local a
  for a in $MX_ARMS; do
    if in_set "$a" "$SC_DEAD"; then mrow "$1" "$a" TRIPPED yes; else mrow "$1" "$a" GREEN no; fi
  done
}
mut() { # <name> <deciding arm> <twin arm> <merge file>
  local name="$1" dec="$2" twin="$3" mf="$4"
  mx_skip "$name" && return 0
  n_mut=$((n_mut + 1))
  if [ "$MATRIX" -eq 1 ] && [ "$MX_JOBS" -gt 1 ]; then mx_enqueue "$name" "$dec" "$twin" "$mf"; return 0; fi
  if [ "$MATRIX" -eq 1 ]; then sc_run "$mf" $MX_ARMS; else sc_run "$mf" "$dec" "$twin"; fi
  mut_judge "$name" "$dec" "$twin"
}
# THE PARALLEL MATRIX (--jobs=<n> above 1). mx_enqueue starts one row's sc_run in a background worker, at most
# MX_JOBS at once (FIFO: the oldest is waited on when every slot is taken). The worker rebinds WORK and the two fixed
# scratch names (bind_scratch) to a dir of its own and builds its own KE world (ke_build; measured, the shared one
# tripped KEnone_core, KEvac_core and KEvac_inst on rows that hold them serially), so no fixed path or world is
# written by two rows at once, and copies the parent's cached worlds (lib.sh wc_get, WC_ROOT). It writes SC_DEAD to
# <seq>.dead and everything it printed, stderr included, to <seq>.log; mx_drain then replays every row in enqueue
# order through the same mx_cells and mut_judge the serial matrix runs inline. A worker that leaves no .dead is a
# FAIL, never a row (that branch has not been seen to fire).
MXQ=""; MXQ_N=0; MXQ_PIDS=""
mx_enqueue() { # <id> <deciding arm> <twin arm> <merge file>
  local n p rest
  [ -n "$MXQ" ] || { MXQ="$(mktemp -d "$WORK/mxq.XXXXXX")" || { bad "matrix: no queue dir"; return 1; }; }
  printf '%s %s %s\n' "$1" "$2" "$3" > "$MXQ/$MXQ_N.job"
  n=0; for p in $MXQ_PIDS; do n=$((n + 1)); done
  if [ "$n" -ge "$MX_JOBS" ]; then
    p="${MXQ_PIDS%% *}"; rest="${MXQ_PIDS#* }"; [ "$rest" = "$MXQ_PIDS" ] && rest=""
    wait "$p"; MXQ_PIDS="$rest"
  fi
  ( WORK="$(mktemp -d "$MXQ/w.XXXXXX")" || exit 1
    bind_scratch "$WORK"; MX_WORKER=1; KE_SD=""
    sc_run "$4" $MX_ARMS
    printf '%s\n' "$SC_DEAD" > "$MXQ/$MXQ_N.dead.t" && mv "$MXQ/$MXQ_N.dead.t" "$MXQ/$MXQ_N.dead"
    rm -rf "$WORK" ) > "$MXQ/$MXQ_N.log" 2>&1 < /dev/null &
  MXQ_PIDS="${MXQ_PIDS:+$MXQ_PIDS }$!"
  MXQ_N=$((MXQ_N + 1))
}
mx_drain() { # every enqueued row, in enqueue order: its worker's output, its cells, its judgment
  local i=0 p id dec twin
  for p in $MXQ_PIDS; do wait "$p"; done
  MXQ_PIDS=""
  while [ "$i" -lt "$MXQ_N" ]; do
    read -r id dec twin < "$MXQ/$i.job"
    cat "$MXQ/$i.log"
    if [ ! -f "$MXQ/$i.dead" ]; then bad "matrix row $id: its worker wrote no verdict -- nothing was scored for it"; i=$((i + 1)); continue; fi
    SC_DEAD="$(cat "$MXQ/$i.dead")"; mx_cells "$id"
    if [ "$id" = MX0 ]; then mx0_judge; else mut_judge "$id" "$dec" "$twin"; fi
    i=$((i + 1))
  done
}
mut_judge() { # <name> <deciding arm> <twin arm> -- SC_DEAD holds the row; the kill, or the FAIL saying why not
  local name="$1" dec="$2" twin="$3" fl
  fl="$(bflag "$dec")$(bflag "$twin")${B_MX0:-0}"
  if [ "$MATRIX" -eq 1 ]; then
    [ "$MX_JOBS" -gt 1 ] || mx_cells "$name"
    if ! in_set "$dec" "$MX_ARMS" || ! in_set "$twin" "$MX_ARMS"; then
      n_unj=$((n_unj + 1)); printf '  note  mutant %s: deciding [%s] or twin [%s] outside --arms=; cells recorded, kill not judged\n' "$name" "$dec" "$twin"; return 0
    fi
  fi
  if ! in_set "$dec" "$SC_DEAD"; then bad "mutant $name SURVIVED its deciding arm [$dec] (tripped: [$SC_DEAD]) -- the kill moved; re-measure with --matrix"
  elif in_set "$twin" "$SC_DEAD"; then bad "mutant $name: twin [$twin] FAILS too (tripped: [$SC_DEAD]) -- the kill spread past the recorded matrix; re-measure with --matrix"
  else n_kill=$((n_kill + 1)); mutant_killed "$([ "$fl" = 111 ] && echo 1 || echo 0)" "$name" "mutant $name KILLED by [$dec]; twin [$twin] holds"
  fi
}
mutc() { # <name> <deciding arm> <twin arm> <old> <new> -- the CONVERGENCE VALIDATOR mutated beside an unmutated merge
  local md s
  mx_skip "$1" && return 0
  md="$(mktemp -d "$WORK/rc.XXXXXX")" || return 1
  for s in merge-adversarial-shards.sh validate-adversarial-convergence.sh validate-steering-budget.sh partition-document.sh partition-subject.sh validate-artifact-budget.sh validate-provenance-block.sh content-seal.sh; do
    [ -f "$SRCDIR/$s" ] && cp "$SRCDIR/$s" "$md/"
  done
  if ! M_OLD="$4" M_NEW="$5" python3 - "$md/validate-adversarial-convergence.sh" <<'PY' || cmp -s "$CONV" "$md/validate-adversarial-convergence.sh" || ! bash -n "$md/validate-adversarial-convergence.sh"
import os, sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read(); o = os.environ["M_OLD"]
if t.count(o) != 1: sys.exit(3)
open(p, "w", encoding="utf-8").write(t.replace(o, os.environ["M_NEW"]))
PY
  then bad "$1: FIXTURE STALE -- its anchor is not in the validator exactly once; re-anchor it, never relax the arm"; n_mut=$((n_mut + 1)); return; fi
  mut "$1" "$2" "$3" "$md/merge-adversarial-shards.sh"
}
mutp() { # <name> <deciding arm> <twin arm> <old> <new> -- partition-document.sh mutated beside an unmutated merge
  local md s
  mx_skip "$1" && return 0
  md="$(mktemp -d "$WORK/rp.XXXXXX")" || return 1
  for s in merge-adversarial-shards.sh validate-adversarial-convergence.sh validate-steering-budget.sh partition-document.sh partition-subject.sh validate-artifact-budget.sh validate-provenance-block.sh content-seal.sh; do
    [ -f "$SRCDIR/$s" ] && cp "$SRCDIR/$s" "$md/"
  done
  if ! M_OLD="$4" M_NEW="$5" python3 - "$md/partition-document.sh" <<'PY' || cmp -s "$PARTITION" "$md/partition-document.sh" || ! bash -n "$md/partition-document.sh"
import os, sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read(); o = os.environ["M_OLD"]
if t.count(o) != 1: sys.exit(3)
open(p, "w", encoding="utf-8").write(t.replace(o, os.environ["M_NEW"]))
PY
  then bad "$1: FIXTURE STALE -- its anchor is not in partition-document.sh exactly once; re-anchor it, never relax the arm"; n_mut=$((n_mut + 1)); return; fi
  mut "$1" "$2" "$3" "$md/merge-adversarial-shards.sh"
}
mutm() { # <name> <deciding arm> <twin arm> <old> <new>
  local mm; mx_skip "$1" && return 0; mm="$(mut_merge "$4" "$5")"
  if [ -z "$mm" ]; then bad "$1: FIXTURE STALE -- its anchor is not in the merge exactly once; re-anchor it, never relax the arm"; n_mut=$((n_mut + 1)); return; fi
  mut "$1" "$2" "$3" "$mm"
}
# THE MATRIX NARROWINGS (--mutants=, --arms=; see the argument block). mx_skip <name> -> 0 when --mutants= leaves the
# mutant out (it is then neither built nor scored); every name asked about is recorded for the unknown-name check.
n_unj=0; MX_ASKED=""
mx_skip() { MX_ASKED="$MX_ASKED $1 "; [ "$MATRIX" -eq 1 ] && [ -n "$MX_MUT_SEL" ] && ! in_set "$1" "$MX_MUT_SEL"; }
MX_ARMS="$ARMS_ALL"
if [ -n "$MX_ARM_SEL" ]; then
  for _a in $MX_ARM_SEL; do
    in_set "$_a" "$ARMS_ALL" || { echo "FIXTURE ERROR: --arms= names '$_a', which is not an arm of ARMS_ALL in this run" >&2; exit 2; }
  done
  MX_ARMS="$MX_ARM_SEL"
fi
# MX0: the UNMUTATED copy, built as a mutant is (the whole sibling set, cmp'd identical). Per push it must hold
# the arms below; --matrix scores it on every arm. A1 gives it a positive conjunct (a merge that ran).
mx0d="$(mktemp -d "$WORK/mx0.XXXXXX")"
for _s in merge-adversarial-shards.sh validate-adversarial-convergence.sh validate-steering-budget.sh partition-document.sh partition-subject.sh validate-artifact-budget.sh validate-provenance-block.sh content-seal.sh; do
  [ -f "$SRCDIR/$_s" ] && cp "$SRCDIR/$_s" "$mx0d/"
done
MX0F="$mx0d/merge-adversarial-shards.sh"
mx0_judge() { # SC_DEAD holds MX0's matrix row
  if [ -z "$SC_DEAD" ]; then ok "CONTROL MX0 (unmutated copy of the merge's sibling set): every arm HOLDS on it, tripped=[] (matrix)"; B_MX0=1
  else bad "unmutated copy fails [$SC_DEAD] -- the harness, not a mutant, is what fails"; fi
}
if ! cmp -s "$MERGE" "$MX0F"; then bad "MX0: FIXTURE BROKEN -- the unmutated copy is not byte-identical to the merge"
elif [ "$MATRIX" -eq 1 ] && [ "$MX_JOBS" -gt 1 ]; then
  mx_enqueue MX0 - - "$MX0F"
elif [ "$MATRIX" -eq 1 ]; then
  sc_run "$MX0F" $MX_ARMS; mx_cells MX0; mx0_judge
else
  sc_run "$MX0F" A1 RS1
  if [ -z "$SC_DEAD" ]; then ok "CONTROL MX0 (unmutated copy of the merge's sibling set): B3 merges NOT_MET and RS1 refuses the reserved form, tripped=[]"; B_MX0=1
  else bad "unmutated copy fails [$SC_DEAD] -- the harness, not a mutant, is what fails"; fi
fi
mutm m-k2only X1 X4 'if [ "$x_plain" -eq 1 ]; then cross_shape lone; fi' \
  '[ "$x_plain" -eq 1 ] && [ "$G" -gt 1 ] && collect "$SHARD_DIR holds cross.md, but the $UNIT_COUNT is $K, whose cross groups are $XTABLE_KEYS; a single cross shard is owed only at K=2"; if [ "$x_plain" -eq 1 ]; then cross_shape lone; fi'
mutm m-nomix X4 A1 '[ "$x_plain" -eq 1 ] && [ "$x_num" -eq 1 ] \' 'false \'
mutm RM-A RS1 A1 'if (sev($0) == "NONE") { if (rline == 0) rline = NR; next } ' ''
mutm RM-B CH2 A1 '    EXIT_CONDITION_MET|EXIT_CONDITION_NOT_MET) ;;' '    EXIT_CONDITION_MET|EXIT_CONDITION_NOT_MET|"") ;;'
# THE DERIVED SET's mutants (BL-911), each the regression its arm names.
mutm DV-full-map DV4 A1 \
  'else ORDINALS="$(awk -v w="$W" '"'"'{ printf "%s%0*d", (NR > 1 ? " " : ""), w, $1 }'"'"' "$T/d.out")"; fi' 'else :; fi'
mutm DV-joined-record-only DV2 DV5 \
  '"$T/d.psha" "$csrc" > "$T/d.src" || return 1' \
  '"$T/d.psha" "$csrc" | while IFS="$(printf '"'"'\t'"'"')" read -r _b _s; do if [ "$_s" = changed ] && ! grep -rqF -- "$_b" "$sd/shards/$art"-repair-p* 2>/dev/null; then _s=same; fi; printf '"'"'%s\t%s\n'"'"' "$_b" "$_s"; done > "$T/d.src" || return 1'
mutm DV-open-findings-dropped DV3 DV2 'if (K["P", j] in CKEY) OP[CKEY[K["P", j]]] = 1' 'if (0) OP[1] = 1'
mutm DV-files-key-ordinal DV4 DV3 'key = $2 }' 'key = $1 + 0 }'
# A bound document pass silently derives NOTHING (cross only, no reason): DV4D's {3 5 7} reads empty.
mutm DV-sections-silent-full DV4D DV3 '      bound) ;;' '      bound) return 0 ;;'
# The reason blanked while the full map is kept (re-keyed onto the NOTOKEN reason): every row still prints, so only
# the header's reason separates it.
mutm DV-reason-blank PCE DV5 '      notoken) D_FULL="the installed rulebook carries no' \
  '      notoken) awk '"'"'{ print $1 + 0 }'"'"' "$cmap" > "$T/d.out"; D_FULL=""; : "the installed rulebook carries no'
# One mode keeps the retired full width in a bound series (re-keyed: once, narrowing a pass whose snapshot was
# consumed): the shipped-sequence arm of that mode fails, the other mode's holds.
mutm DV-doc-narrow-consumed DVRS PCS '      bound) ;;' \
  '      bound) if [ "$mode" = document ]; then D_FULL="document mode kept at full width"; return 0; fi ;;'
mutm DV-subj-narrow-consumed DVRSS PC1 '      bound) ;;' \
  '      bound) if [ "$mode" = subject ]; then D_FULL="subject mode kept at full width"; return 0; fi ;;'
# THE PART-CONTENT JOIN's mutants (BL-911), each the wrong join its arm's seed is asserted to separate.
# Keyed on the ordinal: a part is changed when the digest AT ITS ORDINAL moved.
mutm PC-ordinal-join PC1 DV3 'for (i = 1; i <= nc; i++) if (!(PC[CK[i]] == 1 && CC[CK[i]] == 1)) OW[i] = 1' \
  'for (i = 1; i <= nc; i++) if (PS[O["C", i]] != CS[O["C", i]]) OW[i] = 1'
# A cited part read as a CURRENT ordinal instead of mapped forward by its unique digest.
mutm PC-cite-by-ordinal DV4D PC1 'if (PC[k] == 1 && CC[k] == 1) OW[CI[k]] = 1' 'OW[cc[q] + 0] = 1'
# Unchanged when the digest is merely PRESENT in the predecessor: duplicates are not owed.
mutm PC-dup-presence PCD PC1 'for (i = 1; i <= nc; i++) if (!(PC[CK[i]] == 1 && CC[CK[i]] == 1)) OW[i] = 1' \
  'for (i = 1; i <= nc; i++) if (!(CK[i] in PC)) OW[i] = 1'
# Subject keyed on the digest alone: the same bytes in two files collide.
mutm PC-subject-digest-only PCS2 PC1 'fl = (md == "subject") ? $2 : "-"' 'fl = "-"'
# B1: the notarized run ignored -- a changed header piece owes itself alone.
mutm PC-no-table-run PCT2 PC1 'if (hit) for (q = 1; q <= m; q++) OW[CORD[rr[q] + 0]] = 1' 'if (0) OW[1] = 1'
# B1: a run widened to the row before it (the retired heuristic) -- an edit to that plain row owes the run too.
mutm PC-run-widen-neighbour PCC PCT2 'if (hit) for (q = 1; q <= m; q++) OW[CORD[rr[q] + 0]] = 1' \
  'if (CORD[rr[1] + 0] > 1 && OW[CORD[rr[1] + 0] - 1]) hit = 1; if (hit) { for (q = 1; q <= m; q++) OW[CORD[rr[q] + 0]] = 1; if (CORD[rr[1] + 0] > 1) OW[CORD[rr[1] + 0] - 1] = 1 }'
# K4: each unjoinable input narrows (cross only) instead of falling to full width with its reason.
mutm PC-pred-nolist-narrows PCKa DV5 \
  '[ -n "$pv" ] || { D_FULL="$(basename "$D_PRED") carries no part_sha list (merged by an engine before $mode-mode narrowing)"; return 0; }' \
  '[ -n "$pv" ] || return 0'
mutm PC-own-nolist-narrows PCKb DV5 \
  '[ -n "$pv" ] || { D_FULL="$lb carries no part_sha list of its own, so the set it owed cannot be recomputed"; return 0; }' \
  '[ -n "$pv" ] || return 0'
mutm PC-malformed-narrows PCKc DV5 '"$T/d.pmap" > "$T/d.ppairs" || { D_FULL="$D_PSHA_WHY"; return 0; }' '"$T/d.pmap" > "$T/d.ppairs" || return 0'
mutm PC-count-unchecked PCKd DV5 'if (n != m) { print "BAD' 'if (0) { print "BAD'
mutm PC-pred-norun-narrows PCKe DV5 \
  '[ -n "$pv" ] || { D_FULL="$(basename "$D_PRED") carries no part_run list (merged by an engine before cut-table runs were notarized)"; return 0; }' \
  '[ -n "$pv" ] || return 0'
mutm PC-own-norun-narrows PCKf DV5 \
  '[ -n "$pv" ] || { D_FULL="$lb carries no part_run list of its own, so the set it owed cannot be recomputed"; return 0; }' \
  '[ -n "$pv" ] || return 0'
mutm PC-run-malformed-narrows PCKg DV5 \
  'd_prun "$(basename "$D_PRED")" "$pv" "$T/d.pmap" > /dev/null || { D_FULL="$D_PSHA_WHY"; return 0; }' \
  'd_prun "$(basename "$D_PRED")" "$pv" "$T/d.pmap" > /dev/null || return 0'
# The old-engine tolerance gone: every re-merge over a pass without part_sha: compares byte for byte and refuses.
# THE TIP-ADVERSARY FIXES' mutants, each the regression the fix removed.
# D2: d_prun prints each good run as it passes, so a bad run after a good one never reaches the BAD* test.
mutm PC-prun-print-as-you-go PCKm DV5 '        G[++ng] = R[r]
      } }
    END { if (bad) exit; for (r = 1; r <= ng; r++) print G[r] }' '        print R[r]
      } }
    END { }'
# D1: the moved-file check reads the space-separated manifest rows with a TAB IFS, so no row is a `file:` row.
mutm PC-moved-tab-ifs PCMV PC1 '    while read -r _k _st _rel; do' '    while IFS="$(printf '"'"'\t'"'"')" read -r _k _st _rel; do'
# N2: a failed scoped map is skipped, so its runs are dropped and the answer reads complete.
mutp PC-scoped-map-continue PCN2 PC1 '          [ "$MRC" -eq 0 ] || refuse "the scoped map of $p at $PS_REF failed (rc=$MRC); its cut-table runs are unknown"' \
  '          [ "$MRC" -eq 0 ] || continue'
# D4: the validator's document self-probe never refuses, so a merge that never narrows a document passes it.
mutc VAC-doc-probe-gone NDP DV2 '    if [ "$n_dset" != "2 3 " ] || [ -n "$(printf '"'"'%s\n'"'"' "$n_d" | awk -F'"'"'\t'"'"' '"'"'$1 == "FULL"'"'"')" ]; then' '    if false; then'
# N4: the ceiling back AT the probe root, which git ignores for its own working directory.
mutc VAC-ceiling-nd NDC DV2 'GIT_CEILING_DIRECTORIES="$AC_T" bash "$N_MERGE"' 'GIT_CEILING_DIRECTORIES="$AC_T/nd" bash "$N_MERGE"'
mutm PC-remerge-strict PCR DV3 '  [ -n "$PART_SHA_LIST" ] || return 1' '  return 1'
# D1: a LEGACY series narrowed as if bound.
mutm PC-legacy-narrows PCE DV5 '      legacy) D_FULL="$mode mode narrows only' '      legacy) ;; xlegacy) D_FULL="$mode mode narrows only'
mutm DV-narrow-on-unread DV5 DV2 \
  '[ -s "$T/d.psha" ] || { D_FULL="$(basename "$D_PRED") notarizes no <stem>=<sha> list"; return 0; }' '[ -s "$T/d.psha" ] || return 0'
mutc DV-gate-supersets-only DVRS DV2 'if [ "$n_have" != "$n_owe" ]; then' 'if [ "$n_have" != "$n_owe" ] && [ "${#n_have}" -gt "${#n_owe}" ]; then'
mutm DV-notarize-dispatched-only DV10 DV2 'if [ -n "$DERIVED_FROM" ] && [ -z "$DOCUMENT" ] && [ -z "$SUBJECT" ]; then' 'if false; then'
mutm DV-literal-m-minus-1 DV10 DV2 \
  'if [ "$k" -lt "$3" ] && [ "$k" -gt "$best" ]; then best="$k"; D_PRED="$f"; fi' \
  'if [ "$k" -eq "$(($3 - 1))" ]; then best="$k"; D_PRED="$f"; fi'
# THE CLAIM MUTANTS (BL-918): one per core claim the header states and no mutant above breaks.
# The verdict is taken from the shards rather than recomputed from the summed residue: every B3 shard says MET.
mutm CM-verdict-from-shards A1 RS1 'elif [ "$S_CRIT" -le "$CRIT_CEIL" ] && [ "$BLOCKING" -le "$MAJOR_CEIL" ]; then' 'elif true; then'
# The ordinal map understands only story-<n>- names, so the two real non-story- seeds drop out of it. Every
# files-mode arm seeds those names and trips with M0, so the twin is a document-mode arm, which reads no listing.
mutm CM-ordinal-story-only M0 D3 'for f in "$STORIES_DIR"/*.md; do' 'for f in "$STORIES_DIR"/story-*.md; do'
# The wrong-axis guard gone: a section finding that also carries a stories: line is keyed on one axis and merges.
mutm CM-axis-guard-gone D2 D3 '[ "${wrong:-0}" = "0" ] ||' 'true ||'
# The document path check gone: a shard notarizing a byte-identical COPY passes; the sha check (D3) still holds.
mutm CM-doc-path-unchecked D4 D3 '[ "$ART_ABS" = "$DOCUMENT" ] \' 'true \'
# The document sha check gone: a shard notarizing other bytes at the right path passes; D4's copy carries the right bytes.
mutm CM-doc-sha-unchecked D3 D4 '[ "$sha" = "$DOC_SHA" ] ||' 'true ||'
# The merged pass loses its findings_major line: the MERGED line and the verdict line still read NOT_MET, so only
# the convergence validator, which must ACCEPT the merged file, separates it. RS1 refuses before any write.
mutm CM-merged-unparseable A1 RS1 "  printf 'findings_major: %s\\n' \"\$S_MAJOR\"
" ''
# The worded-heading MAJOR count no longer compared: an unclosed fence hides a finding, the heading count falls short
# of the stated major, and the shipped merge's count refusal ('Findings section heads 0') is gone. Since BL-958 the
# mutant does not merge either: FG2's fence is still open at end of file, so check_keys refuses it on THAT -- FG2
# still decides, on its missing count token. FG2 decides because
# R6's seed is refused earlier by the reserved-heading guard, so R6 trips only on a missing output token, not on this count.
mutm CM-major-count-unchecked FG2 A1 '[ "$nc" -eq "$crit" ] && [ "$nm" -eq "$major" ] \' '[ "$nc" -eq "$crit" ] \'
# The other-root refusal gone: a write-ledger row naming a worktree's copy no longer refuses; TR1 asserts the refusal.
mutm CM-other-root-not-refused TR1 A1 '    refuse "${_op} carries a write-ledger row by agent' '    : "${_op} carries a write-ledger row by agent'
# The SERIAL refusal gone, and the exit-3 answer read as a partition: a SERIAL document is not refused with its reason.
mutm CM-serial-not-refused D5 D3 '  refuse "$DOCUMENT does not partition (' '  prc=0; : "$DOCUMENT does not partition ('
# One byte of files-mode output moved in the pass header: every count, verdict and id still reads right.
mutm CM-files-bytes-moved D6 A1 "shard verdicts are advisory.\\n'" "shard verdicts are advisory!\\n'"
# THE FINDING ID's mutants (BL-958), each the regression its arm names.
# m1: the keyless refusal gone -- '### MAJOR — wiring check' merges.
mutm FI-m1-keyless-accepted FI1 FI2 '[ "${KEY_C1:-0}" = "0" ] ||' 'true ||'
# m2: the id rule's digit requirement dropped -- `MAJOR` itself keys, so the keyless heading reads as keyed.
mutm FI-m2-no-digit FI1 FI2 'if (t ~ /[0-9]/) print b "\t" t' 'print b "\t" t'
# m3: the duplicate refusal gone -- two F-1 headings merge.
mutm FI-m3-dup-accepted FI3a FI1 '[ "${KEY_C2:-0}" = "0" ] ||' 'true ||'
# m4: the requirement applied on both axes -- an elicitation shard's keyless MAJOR is refused.
mutm FI-m4-both-axes FIE FI1 '[ "$3" = convergence ] || return 0' 'true || return 0'
# m5: the merge's id copy without the bracket strip -- '[F-3] MAJOR' derives no id and is refused.
mutm FI-m5-no-bracket-strip FI2 FI1 'gsub(/[][]/, "", s)' 's = s'
# m6: ids compared before normalisation (the trailing `.` kept) -- '**F-1**' and 'F-1.' read as two ids; the
# raw-identical pair (FI3a) is still refused.
mutm FI-m6-dup-raw FI3b FI3a 't = substr(s, 1, RLENGTH); sub(/[.-]+$/, "", t)' 't = substr(s, 1, RLENGTH)'
# m8: the open-fence refusal gone -- a fence left open at end of file merges.
mutm FI-m8-open-fence-accepted FIF FI1 '[ "${KEY_Z:-0}" = "0" ] ||' 'true ||'
# m9: the self-heading refusal gone -- a shard saying '## Shard: story 3' in 2.md merges, its F-1 keyed 3.md#F-1 by J3.
mutm FI-m9-shard-heading-accepted FIS FI1 '[ "${KEY_SL:-0}" = "0" ] ||' 'true ||'
# m10: the shard's own ordinal compared raw (BL-962's number read dropped) -- 'part 04' in 04.md is refused; every
# FIS refusal still stands.
mutm FI-m10-own-ordinal-raw FISa FIS 'if (own ~ /^[0-9]+\.md$/) own = (own + 0) ".md"; else if' 'if (0) own = own; else if'
mutm BM-1 B726B B726H '| if ($s.e - $ae) > $tol then' '| if false then'
mutm BM-2 B726C B726H '| if ($ae - $w.e) > $tol then' '| if false then'
mutm BM-3 B726F B726B 'def verdict($bound): if $bound then "REFUSE" else "WARN" end;' 'def verdict($bound): "REFUSE";'
mutm BM-4 B726H B726B '| max_by(.e)) as $w' '| min_by(.e)) as $w'
# THE DOUBLE-WRITE MUTANTS (BL-946). RR6b, an admissible start that merges, is every one's green twin.
DW_ANCHOR='if ((p in dw) || noadm(p)) { dw[p] = 1; continue }'
# M1: SAME relaxed, a superseded writer's rows at or after S dropped: RR6a merges crediting N with O's bytes.
mutm DW-M1-same-relaxed RR6a RR6b "$DW_ANCHOR" 'drop[i] = 1; continue'
# M2: every SAME taken as DOUBLE-WRITE. RR3's lone writer is left un-narrowed and refused FAR by the start binding.
mutm DW-M2-every-same RR3 RR6b "$DW_ANCHOR" 'if (1) { dw[p] = 1; continue }'
# M3: the admissibility comparison loosened to >=: the tie in RR6c reads as a start that can pass.
mutm DW-M3-tie-admits RR6c RR6b '!(nfst[w] > nlst[o])' '!(nfst[w] >= nlst[o])'
# M4: site (b)'s NOADM branch dropped: the no-rerun world gets the two-dispatch --rerun remedy.
mutm DW-M4-no-site-b RR6n RR6b 'if [ "${_tw%% *}" = NOADM ]; then' 'if false; then'
# M5: a draft-only agent counted as a writer: its draft row inside N's span disqualifies N.
mutm DW-M5-draft-writer RR6f RR6b '    if (f[i] != p) continue' '    if (f[i] != p && f[i] != p ".draft") continue'
# M6: DOUBLE-WRITE ahead of OUT: the scan stops at the NOADM shard and never reaches O's later 3.md.draft row.
mutm DW-M6-dw-before-out RR6d RR6b "$DW_ANCHOR" 'if ((p in dw) || noadm(p)) { dw[p] = 1; i = n; break }'
# M7: a superseded writer's late DRAFT row no longer keeps its shard un-narrowed: --rerun reads the straddle as an acquittal.
mutm DW-M7-draft-straddle-narrowed RR6g RR6b 'for (i = 1; i <= n; i++) if ((i in drop) && (f[i] in dw)) delete drop[i]' 'for (i = 1; i <= n; i++) if (0) delete drop[i]'
# M8: last(o) taken over exact P rows only: O's 21:10 draft row is not counted, a start is admissible, the two-dispatch message returns.
mutm DW-M8-nlst-exact-only RR6g RR6b 'if ((f[i] == p || f[i] == p ".draft") && (a[i] in nfst)' 'if ((f[i] == p) && (a[i] in nfst)'
# THE SHARD-CHECK MUTANTS (BL-974). Each anchor is a line only --check-shard executes, so A1 (a merge) is every
# one's green twin and no kill can spread into the merge's own arms.
mutm CSM-agree CS1 A1 'elif [ "$nref" -eq 1 ] && [ "$ref" != "$own" ]; then' 'elif false; then'
mutm CSM-self CS1 A1 '"$bn") continue ;; cross.md|' 'cross.md|'
mutm CSM-cite CS2 A1 '    check_cite_lines "$sf" "$line" "$nlines" || cs_refuse "$HDR_MSG"' '    :'
mutm CSM-artifact CS3 A1 '    check_shard_artifact "$T/cs.p" "$sf" "$key" "$is_x" || cs_refuse "$HDR_MSG"' '    :'
mutm CSM-header CS4 A1 '  if ! check_header "$T/cs.p" "$by" "$AXIS"; then' '  if false; then'
mutm CSM-skip CS5 A1 '[ "${CS_SKIP:-0}" != 1 ] || { printf '"'"'SKIP: %s%s\n'"'"' ' '[ "${CS_SKIP:-0}" != 1 ] || true || { printf '"'"'SKIP: %s%s\n'"'"' '
# The self-only verdict deferred past the derivation: a dir with no subject SKIPs a header refusal.
mutm CSM-early CS9 A1 '  if [ "$CS_N" -gt 0 ]; then exit 2; fi' '  if false; then exit 2; fi'
# The unresolvable subject SKIPped before any self-only check runs (the shipped defect of the first cut).
mutm CSM-order CS9 A1 '        CITE=""; OTHER=""
' '        printf '"'"'SKIP: no subject resolvable\n'"'"'; exit 3
'
# Files mode chosen by `[ -d ]` alone again (the exact-name listing and the two-story minimum gone): a same-name dir
# holding one document is read as files mode and every sections: finding is refused for its missing stories: line.
mutm CSM-docsel CS10 A1 '    for v in "$SPRINT_DIR"/*; do [ "${v##*/}" = "$ARTIFACT" ] && [ -d "$v" ] && { cs_e="$v"; break; }; done
    if [ -n "$cs_e" ]; then
      k=0; for v in "$cs_e"/*.md; do [ -f "$v" ] && k=$((k + 1)); done
      [ "$k" -ge 2 ] && { CITE=stories; CS_MODE=files; }
    fi
' '    [ -d "$STORIES_DIR" ] && { CITE=stories; CS_MODE=files; }
'
# The no-block SKIP gone: a repair-style part with no provenance block is refused by check_header's block count.
mutm CSM-noblock CS11 A1 '|| cs_skip "$sf carries no provenance block' '|| : "$sf carries no provenance block'
# The sealed-sibling document fallback gone: a block-less document-mode shard SKIPs again (CS13); CS14's SKIPs hold.
mutm CSM-docfb CS13 CS14 '[ -n "$cs_art" ] || cs_art="$(cs_sib_artifact "$cs_dir" "$bn")"' ':'
mutm CSM-bytes CS6 A1 '    by="$AI_DLC_CHECK_BYTES"' '    :'
# CS12's two: the two case labels SWAPPED, and the dir label widened to a glob that takes --check-shard too.
mutm CSM-flagswap CS12 A1 '    shift; check_shard_dirs "$@"; exit $? ;;
  --check-shard) check_shard_main "$@" ;;' '    shift; check_shard_main "$@" ;;
  --check-shard) check_shard_dirs "$@"; exit $? ;;'
mutm CSM-flagglob CS12 A1 '  --check-shard-dir)
    [ $# -ge 2 ] && [ -z "$RERUN" ]' '  --check-shard*)
    [ $# -ge 2 ] && [ -z "$RERUN" ]'
# THE MARK'S RELAY MUTANTS (BL-974 E): wait-for-deliverable.sh mutated beside an UNMUTATED merge, so CS8 is the
# only arm that runs the mutated file (CS1 seals with the shipped one and asks the merge directly: the twin).
mutw() { # <name> <deciding arm> <twin arm> <old> <new>
  local md s
  mx_skip "$1" && return 0
  md="$(mktemp -d "$WORK/rw.XXXXXX")" || return 1
  for s in merge-adversarial-shards.sh validate-adversarial-convergence.sh validate-steering-budget.sh partition-document.sh partition-subject.sh validate-artifact-budget.sh validate-provenance-block.sh content-seal.sh; do
    [ -f "$SRCDIR/$s" ] && cp "$SRCDIR/$s" "$md/"
  done
  if ! M_OLD="$4" M_NEW="$5" python3 - "$WFD" "$md/wait-for-deliverable.sh" <<'PY' || cmp -s "$WFD" "$md/wait-for-deliverable.sh" || ! bash -n "$md/wait-for-deliverable.sh"
import os, sys
t = open(sys.argv[1], encoding="utf-8").read(); o = os.environ["M_OLD"]
if t.count(o) != 1: sys.exit(3)
open(sys.argv[2], "w", encoding="utf-8").write(t.replace(o, os.environ["M_NEW"]))
PY
  then bad "$1: FIXTURE STALE -- its anchor is not in wait-for-deliverable.sh exactly once; re-anchor it, never relax the arm"; n_mut=$((n_mut + 1)); return; fi
  mut "$1" "$2" "$3" "$md/merge-adversarial-shards.sh"
}
# CSW-call: the mark never runs the sibling's check (the shard is MARKED); CSW-relay: it refuses, but relays none
# of the merge's REFUSED lines (rc 64, bytes unchanged, the remedy present: only the relay conjunct can kill it).
mutw CSW-call CS8 CS1 '      if [ -z "$MK_JS" ] || [ ! -f "$MK_JS" ]; then :' '      if :; then :'
mutw CSW-relay CS8 CS1 "          2) mk_jr_=\"\$(printf '%s\\n' \"\$MK_JO\" | grep '^REFUSED:')\" || mk_jr_=\"\$MK_JO\"" '          2) mk_jr_=""'
# PM1: the schema reverted to the single-sha pattern, driven through AI_DLC_PROJECT_ROOT (whose core/schemas/ the
# reader tries FIRST), so the validator is the shipped one and only the schema differs. PBARE is its twin.
pm1_mt="$(mktemp -d "$WORK/pm1.XXXXXX")"; mkdir -p "$pm1_mt/core/schemas"
if [ -z "$KSCH" ] || [ ! -s "$KSCH" ]; then bad "PM1: FIXTURE BROKEN -- provenance-block.json not found above $SRCDIR"; n_mut=$((n_mut + 1))
else
  cp "$KSCH" "$pm1_mt/core/schemas/provenance-block.json"
  M_OLD='"pattern_ref": "artifact_sha"' M_NEW='"pattern_ref": "sha256"' python3 - "$pm1_mt/core/schemas/provenance-block.json" <<'PY'
import os, sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read(); o = os.environ["M_OLD"]
if t.count(o) != 1: sys.exit(3)
open(p, "w", encoding="utf-8").write(t.replace(o, os.environ["M_NEW"]))
PY
  if cmp -s "$KSCH" "$pm1_mt/core/schemas/provenance-block.json"; then bad "PM1: FIXTURE STALE -- the pattern_ref anchor is not in the schema exactly once"; n_mut=$((n_mut + 1))
  else PBROOT="$pm1_mt" mut PM1 P1 PBARE "$MERGE"; fi
fi
if [ "$KOK" = 1 ]; then
  # The deciding cells are the irredundant cover of the kill matrix: the old-ps world in inst kills KMb and KEM,
  # the old-sch world in core kills KMc and KEM.
  # KMb and KMc are each ONE mutated file with ONE deciding cell, so each is scored once; KEM keeps a row per layout.
  mut KMb-inst KEps_inst K2vac_inst "$KMB"
  mut KMc-core KEsch_core K2vac_core "$KMC"
  mut KEM-inst KEps_inst KEvac_inst "$KM593"
  mut KEM-core KEsch_core KEvac_core "$KM593"
else
  bad "KMb/KMc/KEM: not scored -- the K section did not build (see K0)"
fi
[ "$MATRIX" -eq 1 ] && [ "$MX_JOBS" -gt 1 ] && mx_drain
if [ "$MATRIX" -eq 0 ]; then
  [ "$n_mut" -gt 0 ] && [ "$n_kill" -eq "$n_mut" ] && ok "$n_kill of $n_mut mutants scored dead" || bad "$n_kill of $n_mut mutants scored dead"
  [ "$MATRIX_ROWS" -eq 0 ] && ok "PLAIN-RUN: no MATRIX row printed -- the full matrix runs only under --matrix" || bad "PLAIN-RUN printed $MATRIX_ROWS MATRIX row(s)"
else
  [ "$n_mut" -gt 0 ] && [ "$((n_kill + n_unj))" -eq "$n_mut" ] && ok "matrix tally (--arms= narrowed): $n_kill of $n_mut mutants scored dead, $n_unj recorded and not judged" \
    || bad "matrix tally (--arms= narrowed): $n_kill of $n_mut mutants scored dead, $n_unj recorded and not judged"
  for _m in $MX_MUT_SEL; do in_set "$_m" "$MX_ASKED" || bad "FIXTURE ERROR: --mutants= names '$_m', which no mutant of this run carries"; done
  n_arm=0; for _a in $MX_ARMS; do n_arm=$((n_arm + 1)); done
  [ "$MATRIX_ROWS" -eq $(( (n_mut + 1) * n_arm )) ] && ok "MATRIX: $MATRIX_ROWS rows printed ($n_arm arms x (every scored mutant plus MX0))" || bad "MATRIX printed $MATRIX_ROWS rows, expected $(( (n_mut + 1) * n_arm ))"
fi
echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
