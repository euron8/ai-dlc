#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# adversarial-shard-merge/run.sh -- merge-adversarial-shards.sh, the JOIN that turns one
# adversary per story ordinal plus one cross-story adversary into the ONE pass file every gate
# reads. The behavioural arms only: the mutation battery that proves each of them can fail is
# `adversarial-shard-merge-mutants`, distribution-only, which sources the SAME predicates and
# worlds from `lib.sh` beside this file. The battery mutates copies of core's own scripts, which a
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
# the two id lines -- every ordinal shard's body is byte-identical.
#
# Every arm that scores a merge calls its predicate as `p_<name> "$MERGE"` at the start of a
# line; the battery's join J1 reads exactly that shape to prove the shipped arm set and P_ALL
# are one set.
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="adversarial-shard-merge"
[ -f "$HERE/lib.sh" ] || { echo "FIXTURE BROKEN: $HERE/lib.sh is absent; nothing was asserted" >&2; exit 2; }
. "$HERE/lib.sh"

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
