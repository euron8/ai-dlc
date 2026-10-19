#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# adversarial-shard-merge/run.sh -- merge-adversarial-shards.sh, the JOIN that turns one
# adversary per story ordinal plus one cross-story adversary into the ONE pass file every gate
# reads. The behavioural arms only: the mutation battery that once proved each of them can fail
# has been retired; the predicates and worlds live in `lib.sh` beside this file. The battery mutates copies of core's own scripts, which a
# consumer cannot edit, so the consumer keeps every correctness arm and loses only that proof.
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
# guard refuses -- the battery's MX6b asserts that, with the guard gone, the same seed merges. D4's
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
# line; the battery's join J1 reads exactly that shape to prove the shipped arm set and P_ALL
# are one set.
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="adversarial-shard-merge"
[ -f "$HERE/lib.sh" ] || { echo "FIXTURE BROKEN: $HERE/lib.sh is absent; nothing was asserted" >&2; exit 2; }
. "$HERE/lib.sh"
echo "HERMETIC-CONSUMED $MERGE"

# ---------------------------------------------------------------------------------- the arms
echo "$NAME:"

# M0: the ordinal map covers every *.md, whatever its name, in C order.
d="$(new_world)"
map="$(bash "$MERGE" --map "$d")"
want="$(printf '1\t192-ff-A-token-decimal-resolution.md\n2\tbug-192-il-accuracy.md\n3\tstory-1-rebalancer-il-accuracy.md')"
if [ "$map" = "$want" ]; then
  ok "M0: --map keys all three real files by ordinal, the two NON-story- names (192-ff-, bug-) included, in LC_ALL=C order"
else
  bad "M0: --map printed [$map], not the three ordinals over the real listing"
fi

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

# ---- the cross groups (BL-464). Every K>=3 shard set owes one cross shard per row of
# partition-document.sh --cross-groups <K>, in EVERY mode; X1-X3 drive K=8 through each mode (and
# K=2 through files and --document), each predicate presence-shaped in every cell.
p_xfiles "$MERGE" && ok "X1: files mode, K=8: cross-1..6 merges (tool_use_id = cross-1's); cross.md alone REFUSED; a finding in its owner AND another covering group REFUSED naming the owner, its owner alone merges major=1, a (1, 2, K-1) finding held only by a non-owner merges major=1; K=2 cross.md merges, K=2 cross-1.md REFUSED" \
  || bad "X1: files-mode cross groups (rc=$RC): $(cat "$MO")"
p_xdoc "$MERGE" && ok "X2: --document, K=8: the same four cells, and K=2 cross.md merges" \
  || bad "X2: --document cross groups (rc=$RC): $(cat "$MO")"
p_xelicit "$MERGE" && ok "X3: --subject --elicitation over the 6-part subject: cross-1..6 merges, cross.md REFUSED, the non-owner duplicate REFUSED, the owner alone counted once" \
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
# not `p_<name> "$MERGE"` predicates: a predicate joins P_ALL and the retired mutant battery's J1 and XM1
# sets. RM-A and RM-B below are this
# fixture's own mutants, built PM1's way in a copy of the merge's whole sibling set.
mk_markers() { # <shard dir>: every shard ends in its seat-complete marker, n = its `### M<n>` findings
  local f n
  for f in "$1"/*.md; do
    n="$(grep -c '^### M[0-9]' "$f")" || n=0
    printf '\nseat-complete: stories adversary %s findings=%s\n' "$(basename "$f" .md)" "$n" >> "$f"
  done
}
set_major() { sed "s/^findings_major: .*/findings_major: $2/" "$1" > "$1.tmp" && mv "$1.tmp" "$1"; } # <shard file> <n>
PROBES='### Probes run (no finding)\n\nProbed the ordinal citation of every AC; each holds.'
RESERVED='is a `### ` heading under `## Findings` with no severity word'
# RS1: the filed incident -- graph s319 requirements-p1/2.md, findings=0, a probes subsection.
d="$(hdr_world "## Findings\n\n$PROBES")"; mk_markers "$d"; run_merge "$MERGE" "$d"
refused_clean "$RESERVED" "$d" && has "$MO" "move it under its own \`## \` section, or demote it to \`#### \`" && has "$MO" "2.md:5 is" \
  && ok "RS1: '### Probes run (no finding)' under ## Findings, findings=0 -> REFUSED naming the reserved form and the fix (line 5), nothing written" \
  || bad "RS1: a severity-less ### under ## Findings was not refused with the reserved-form message (rc=$RC): $(cat "$MO")"
d="$(hdr_world "## Findings\n\n## Probes\n\n$PROBES")"; mk_markers "$d"; run_merge "$MERGE" "$d"
[ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$MO" "major=4" \
  && ok "RS1c: the same probes under their own ## Probes section -> MERGED, shard 2 counting 0 (major=4 = shards 1 and 3)" \
  || bad "RS1c: the probes moved to ## Probes did not merge with shard 2 at 0 (rc=$RC): $(cat "$MO")"
# RS2 / RS3: the F-form and the bare severity form each open ONE finding (s315-s317 write the second).
for cell in 'RS2|### F-1 (MAJOR) the ordinal map omits story 2' 'RS3|### MAJOR: the ordinal map omits story 2'; do
  id="${cell%%|*}"; h="${cell#*|}"
  d="$(hdr_world "## Findings\n\n$h\n\nstories: 2\n")"; set_major "$d/2.md" 1; mk_markers "$d"
  printf '\n' >> "$d/2.md"; sed 's/^seat-complete: stories adversary 2 findings=0$/seat-complete: stories adversary 2 findings=1/' "$d/2.md" > "$d/2.tmp" && mv "$d/2.tmp" "$d/2.md"
  run_merge "$MERGE" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "major=5" \
    && ok "$id: '$h' counts as 1 MAJOR finding (findings=1 marker agrees; merged major=5)" \
    || bad "$id: '$h' was not counted as one MAJOR finding (rc=$RC): $(cat "$MO")"
done
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
# SD2: the oracle, out of P_ALL (the battery never runs the validator per mutant), so not spelled as a
# line-start predicate call that the battery's J1 join reads.
if p_sum_divergent_oracle "$MERGE"; then ok "SD2: on five seeded series (a -pass1 and a zero-padded -p02 predecessor, a two-block and a block-less one) the merge stamps exactly where validate-adversarial-convergence.sh --series fires arm C on the unstamped twin"
else bad "SD2: the merge's stamp (${OR_ST:-?}) disagrees with arm C on the unstamped twin (${OR_C:-?}): $(grep -m2 'FAIL\|pass artifact' "$CO" 2>/dev/null)"; fi

# CH1-CH8: --check-header on one file. The base is a real B3 shard, which passes; each cell varies ONE field.
ch() { bash "$MERGE" --check-header "$1" --axis "$2" > "$MO" 2>&1; RC=$?; } # <shard file> <axis>
chv() { sed "$2" "$1" > "$3"; } # <src> <sed script> <dst>
d="$(b3_world)"; c="$WORK/ch"; mkdir -p "$c"
ch "$d/1.md" convergence
[ "$RC" -eq 0 ] && [ ! -s "$MO" ] && ok "CH1: --check-header on a complete shard (verdict: EXIT_CONDITION_MET) -> exit 0, nothing printed" \
  || bad "CH1: a complete shard did not pass --check-header silently (rc=$RC): $(cat "$MO")"
chv "$d/1.md" '/^verdict:/d' "$c/nov.md"; ch "$c/nov.md" convergence; ch_out="$(cat "$MO")"; ch_rc=$RC
# The merge's own refusal of the SAME bytes, in a world where that shard is the only defect.
dm="$(b3_world)"; sed '/^verdict:/d' "$dm/1.md" > "$dm/1.tmp" && mv "$dm/1.tmp" "$dm/1.md"; run_merge "$MERGE" "$dm"
m_line="$(grep '^REFUSED:' "$MO")"
ch_tail="${ch_out#* declares }"; m_tail="${m_line#* declares }"
if [ "$ch_rc" -eq 1 ] && [ "$RC" -eq 2 ] && [ "$ch_tail" != "$ch_out" ] && [ "$ch_tail" = "$m_tail" ] \
   && has "$WORK/ch/nov.md" "findings_major:" && [ "${ch_out#REFUSED: }" != "$ch_out" ] \
   && case "$ch_tail" in "verdict '<none>', not one of"*) true ;; *) false ;; esac; then
  ok "CH2: no verdict: line -> --check-header exit 1 with the merge's own refusal text (the same line the merge prints for that shard, path aside)"
else
  bad "CH2: no-verdict shard: --check-header rc=$ch_rc [$ch_out], merge rc=$RC [$m_line]"
fi
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

# RM-A / RM-B: mutants of the merge, each in a copy of its whole sibling set, the anchor applied exactly once.
mut_merge() { # <old> <new> -> prints the mutated merge's path; empty when the anchor is not there once
  local md s
  md="$(mktemp -d "$WORK/rm.XXXXXX")" || return 1
  for s in merge-adversarial-shards.sh validate-adversarial-convergence.sh validate-steering-budget.sh partition-document.sh partition-subject.sh validate-artifact-budget.sh; do
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
# RM-A: "any ### opens a finding" restored. RS1's world then reads the probes heading as a finding, so
# the reserved-form refusal is gone and the count it inflates is what refuses (--dry-run prints every
# refusal of that phase, so the marker-count mismatch is visible beside the citation refusal).
ma="$(mut_merge 'if (sev($0) == "NONE") { if (rline == 0) rline = NR; next } ' '')"
if [ -z "$ma" ]; then bad "RM-A: FIXTURE STALE -- the reservation anchor is not in the merge exactly once; re-anchor it, never relax RS1"
else
  d="$(hdr_world "## Findings\n\n$PROBES")"; mk_markers "$d"
  bash "$ma" --dry-run "$d" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$MO" "findings=0' but its ## Findings section heads 1 finding(s)" && ! has "$MO" "$RESERVED" \
    && ok "RM-A: with every ### opening a finding, RS1's world reports the marker-count mismatch (findings=0 vs 1) and no reserved-form refusal -- RS1 watches the reservation" \
    || bad "RM-A: the restored any-### parse gave rc=$RC: $(cat "$MO")"
fi
# RM-B: the verdict enum weakened in THE ONE header check. Both --check-header AND a full merge then
# accept the verdict-less shard, which proves they read one source.
mb="$(mut_merge '    EXIT_CONDITION_MET|EXIT_CONDITION_NOT_MET) ;;' '    EXIT_CONDITION_MET|EXIT_CONDITION_NOT_MET|"") ;;')"
if [ -z "$mb" ]; then bad "RM-B: FIXTURE STALE -- the verdict-enum anchor is not in the merge exactly once; re-anchor it, never relax CH2"
else
  bash "$mb" --check-header "$c/nov.md" --axis convergence > "$MO" 2>&1; r_ch=$?
  dm="$(b3_world)"; sed '/^verdict:/d' "$dm/1.md" > "$dm/1.tmp" && mv "$dm/1.tmp" "$dm/1.md"; run_merge "$mb" "$dm"
  [ "$r_ch" -eq 0 ] && [ "$RC" -eq 0 ] && has "$MO" "MERGED:" \
    && ok "RM-B: with the verdict enum weakened in check_header_core, --check-header (exit 0) AND the full merge (MERGED) both accept the verdict-less shard -- one source" \
    || bad "RM-B: weakened enum gave --check-header rc=$r_ch and merge rc=$RC: $(cat "$MO")"
fi

# R6: a finding heading EXACTLY as the real pass wrote it carries no severity word, so the heads
# counted (0 MAJOR) disagree with findings_major -- refused, never counted as zero.
d="$(b3_world)"
{
  printf '## Findings\n\n%s\n\nstories: 1\n\n' "$(sed -n 1p "$HERE/seed.finding-headings.txt")"
  sed -n '/SKILL_INVOCATION_PROVENANCE v1/,$p' "$d/1.md" | sed 's/^findings_major: 2$/findings_major: 1/'
} > "$d/1.tmp" && mv "$d/1.tmp" "$d/1.md"
run_merge "$MERGE" "$d"
refused_clean "Findings section heads 0 CRITICAL / 0 MAJOR" "$d" \
  && ok "R6: a real-pass heading with no severity word -> REFUSED on the count, never merged as 0 MAJOR" \
  || bad "R6: a heading without a severity word was not refused on its count (rc=$RC): $(cat "$MO")"

# P1: the merged pass is a provenance block the READER accepts. Its artifact_sha is the files-mode
# list `<stem>=<sha> ...`, which the schema's single-sha pattern refused, so every sharded pass
# failed validate-provenance-block.sh while the convergence validator passed it. The two
# near-misses keep the widening honest: a list of ONE (a merge always has two or more stories)
# and a list carrying a short sha are both refused, and a bare sha is the control that still passes.
PB="$SRCDIR/validate-provenance-block.sh"
if [ ! -f "$PB" ]; then
  bad "P1: FIXTURE BROKEN -- validate-provenance-block.sh is not beside the merge at $SRCDIR"
else
  d="$(b3_world)"; o="$(out_of "$d")"; run_merge "$MERGE" "$d"
  pb() { bash "$PB" "$1" --require-skill ai-dlc-adversary-review > "$WORK/pb.out" 2>&1; }
  sha_line="$(grep '^artifact_sha:' "$o" 2>/dev/null)"
  n_pairs="$(printf '%s' "${sha_line#artifact_sha:}" | wc -w | tr -d ' ')"
  if [ "$RC" -ne 0 ] || [ "${n_pairs:-0}" -lt 2 ]; then
    bad "P1: FIXTURE BROKEN -- the B3 merge did not write a multi-file artifact_sha (rc=$RC, pairs=${n_pairs:-0})"
  else
    one="$WORK/pb-one.md"; short="$WORK/pb-short.md"; bare="$WORK/pb-bare.md"
    first="$(printf '%s' "${sha_line#artifact_sha: }" | cut -d' ' -f1)"
    sed "s/^artifact_sha:.*/artifact_sha: $first/" "$o" > "$one"
    sed -E 's/^(artifact_sha: [^ ]+=)[a-f0-9]{64}/\1abc123/' "$o" > "$short"
    sed "s/^artifact_sha:.*/artifact_sha: ${first#*=}/" "$o" > "$bare"
    pb "$o"; r_m=$?; pb "$one"; r_1=$?; pb "$short"; r_s=$?; pb "$bare"; r_b=$?
    if [ "$r_m" -eq 0 ] && [ "$r_1" -ne 0 ] && [ "$r_s" -ne 0 ] && [ "$r_b" -eq 0 ]; then
      ok "P1: the merged pass ($n_pairs <stem>=<sha> pairs) passes validate-provenance-block.sh; a one-pair list and a short sha are refused; a bare sha still passes"
    else
      bad "P1: provenance reader on the merged forms gave merged=$r_m one-pair=$r_1 short-sha=$r_s bare=$r_b (want 0 non-0 non-0 0)"
    fi
    # PM1: the schema reverted to the single-sha pattern -- the shipped defect on demand. Driven
    # through AI_DLC_PROJECT_ROOT, whose core/schemas/ the reader tries FIRST, so the validator
    # is the shipped one and only the schema differs. The bare-sha control must stay at 0, or the
    # mutant tree failed for a reason of its own.
    SCH=""
    _d="$SRCDIR"
    while [ -n "$_d" ] && [ "$_d" != "/" ]; do
      for _c in "$_d/core/schemas/provenance-block.json" "$_d/.claude/schemas/provenance-block.json"; do
        [ -f "$_c" ] && { SCH="$_c"; break 2; }
      done
      _d="$(dirname "$_d")"
    done
    mt="$(mktemp -d "$WORK/pm1.XXXXXX")"; mkdir -p "$mt/core/schemas"
    if [ -z "$SCH" ]; then
      bad "PM1: FIXTURE BROKEN -- provenance-block.json not found above $SRCDIR"
    else
      cp "$SCH" "$mt/core/schemas/provenance-block.json"
      M_OLD='"pattern_ref": "artifact_sha"' M_NEW='"pattern_ref": "sha256"' python3 - "$mt/core/schemas/provenance-block.json" <<'PY'
import os, sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read(); o = os.environ["M_OLD"]
if t.count(o) != 1: sys.exit(3)
open(p, "w", encoding="utf-8").write(t.replace(o, os.environ["M_NEW"]))
PY
      if cmp -s "$SCH" "$mt/core/schemas/provenance-block.json"; then
        bad "PM1: FIXTURE STALE -- the pattern_ref anchor is not in the schema exactly once; re-anchor it, never relax P1"
      else
        AI_DLC_PROJECT_ROOT="$mt" bash "$PB" "$o" --require-skill ai-dlc-adversary-review > "$WORK/pb.out" 2>&1; m_m=$?
        AI_DLC_PROJECT_ROOT="$mt" bash "$PB" "$bare" --require-skill ai-dlc-adversary-review > "$WORK/pb.out" 2>&1; m_b=$?
        if [ "$m_m" -ne 0 ] && [ "$m_b" -eq 0 ]; then
          ok "PM1: the schema reverted to the single-sha pattern refuses the merged pass (rc=$m_m) while the bare-sha control holds at 0 -- P1 watches the pattern"
        else
          bad "PM1: with the single-sha pattern the merged pass gave rc=$m_m and the bare control rc=$m_b (want non-0 and 0)"
        fi
      fi
    fi
  fi
fi
echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
