#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# review-shard-merge/run.sh -- partition-review-diff.sh and merge-review-shards.sh, the part set
# and the JOIN of a sharded gate-1 code review and of a sharded gate-2 QA validation (--gate qa;
# arms Q1-Q16, S7-S10), and (BL-737) the seat's shard pre-check, the owner tails, the marker key, the
# content seal on review shards and the legacy rule (arms CS1-FT1). The mutation battery that once
# proved the older arms can fail has been retired; the predicates live in `lib.sh` beside this file.
# BL-740's verdict-backing arms (VB1-VB4) carry M7-M10 and an unmutated CONTROL (VBCTL) the same way.
# The BL-737 arms carry five in-process mutants (M1-M5 below), each run in a copy of the resolved
# script directory and only in the DISTRIBUTION layout: a consumer cannot edit core's scripts, so it
# keeps every correctness arm and loses only that proof.
#
# WHAT IS AT STAKE. Check 1 in gate-validation.md reads ONE verdict line from ONE review file. A
# sharded review is N part reviewers plus one cross reviewer per cross group, and the merge writes that file. Its
# load-bearing claims are invisible to anything that only reads a finished review:
#   - the part set is RE-DERIVED from the manifest's inputs, never read off the shard directory;
#   - the merged verdict is the WORST shard verdict, never a count, the cross shard, or the last;
#   - the output matches Check 1's own pattern exactly once, and Check 1 reads the right value;
#   - every refusal writes nothing at --out.
#
# TWO SEEDED REPOSITORIES, ON PURPOSE. The merge re-runs the partition sibling, so a partition
# mutant runs inside every merge world. REPO A (dominant) puts every reviewable file under one top
# directory, `app/`: a first-path-component key sees one group and answers SERIAL, so only the
# adaptive split makes it partition -- arm P1 owns that. REPO B (equal) has three top directories
# of byte-identical numstat weight and is merged with --max-parts 3, where 3 x 1/3 of the weight
# never exceeds 1/K of the total, so adaptive and first-component keys give the SAME map; every
# merge world is built on B, so the first-component mutant moves P1 and nothing else.
#
# THE VERDICT WORLDS. W_disc {BLOCKED, APPROVED, APPROVED, cross APPROVED}: cross-wins, last-part-
# wins and majority all say APPROVED, worst-of says BLOCKED. W_bn {NEEDS_REWORK, BLOCKED,
# NEEDS_REWORK, cross APPROVED}: majority says NEEDS_REWORK, worst-of BLOCKED. W_ok (all APPROVED)
# stops "always BLOCKED" passing. W_c1 {NEEDS_REWORK, APPROVED, NEEDS_REWORK, cross NEEDS_REWORK}
# is the world where every one of those wrong rules AGREES with worst-of, so the Check-1 and
# conservation arms do not ride on the verdict mutants.
#
# CHECK 1'S PATTERN IS DERIVED from gate-validation.md with the sed gate-verdict-grep-shape uses,
# and the value is read back by this fixture's own reader, not by the merge's. The value rule is
# the one gate-validation.md Check 1 states, and it is cited there rather than restated here.
#
# The threshold key is named ONCE, in lib.sh's unset (fixtures scrub AI_DLC_*; I87). Everywhere
# else it is DERIVED from the partition script's own dereference site. lib.sh sets the shell
# options, scrubs AI_DLC_*, owns WORK and its one EXIT trap.
#
# THE MUTANT MATRIX. Measured once by the re-measure command below, and re-measured whenever an arm or
# a mutant is added or changed: a mut_run line, a `cell` a mutant drive declares, or a file of the
# derived sibling set. Its population is each mutant x the cells of its own drive (the predicate its
# mut_run names), plus, for a drive declaring fewer than two cells, the deciding cell of every mutant of
# the same file; cells outside that population are not measured. Each cell is scored over the mutant
# copy and over the unmutated control copy, and reads RED (the cell failed), GREEN (it passed, exactly
# one cell run) or SKIP (not exactly one cell run). decides= is the cell the mutant is scored on (the arm whose reason token its killed line names);
# any other cell RED over the mutant and GREEN over the control is listed on a `# also trips:` comment line above the rows. twins= is a GREEN-under-both cell
# of the population outside decides=, the nearest to the deciding cell in declaration order. On each
# push a mutant runs its deciding cell (the kill) and each twin, which must pass: the mutant fails only
# its own assertion. An arm is <predicate>/<cell>.
# also trips: M2 owner/dup-check-owner-sealed
# also trips: M7 vb_qa/q-nr-sug
# also trips: M12 vb_qa/q-nr-empty,vb_r3/r3-graph-cross1,vb_qa/q-unclassed,fr_bound/frb-legacy
# also trips: M13 vb_qleg/q-leg-pass-crit,vb_qleg/q-leg-nr-empty
# also trips: M15 fr_verdict/fr-bold,fr_verdict/fr-paren,fr_verdict/fr-reorder
# also trips: M18 serial/sr-q-suffix
# also trips: M23 canon/cr-filter-kglued,canon/cr-filter-kquoted,canon/cr-filter-keyword,canon/cr-deselect,canon/cr-file,canon/cr-node,canon/cr-path-noconv,canon/cr-m-other,canon/cr-path-other,canon/cr-filter-suffix,canon/cr-filter-gorun,canon/cr-filter-lf,canon/cr-filter-xff,canon/cr-filter-dd,canon/cr-path-sub
# also trips: M24 canon/cr-exempt-evil,canon/cr-exempt-whole,canon/cr-norun-na,canon/cr-norun-nonebt,canon/cr-norun-other
# also trips: M25 canon_merge/crm-disk-legacy
# also trips: M27 canon_merge/crm-disk-held,canon_merge/crm-neither
# also trips: M28 canon/cr-exempt-empty
# also trips: M29 canon/cr-m-other,canon/cr-filter-ff,canon/cr-path-super,canon/cr-conv-runner
# also trips: M30 canon/cr-conv-runner-none,canon/cr-norun-other,canon/cr-norun-rec
# also trips: M41 adv_qa/ad-q-unreadable-absent,adv_qa/ad-q-world-b,adv_qa/ad-q-untracked-new
# also trips: M42 adv_qa/ad-q-legacy-prose,adv_qa/ad-q-world-a,adv_qa/ad-q-untracked-old
# also trips: M43 xc_count/xc-count,xc_one/xc-one
# also trips: m-k2only x_lone/x-lone-qa
# MUTANT-MATRIX M1 decides=cs/partcite twins=cs/crossone
# MUTANT-MATRIX M2 decides=owner/dup-merge twins=owner/dup-check-owner-unsealed
# MUTANT-MATRIX M3 decides=mark/shard-3 twins=mark/caller-key
# MUTANT-MATRIX M4 decides=seal_rewrite/seal-rewrite twins=mark/shard-3
# MUTANT-MATRIX M5 decides=legacy/sentinel twins=legacy/absent
# MUTANT-MATRIX M6 decides=unmarked/unmarked-sentinel twins=unmarked/control-old-engine
# MUTANT-MATRIX M7 decides=vb_qa/q-nr-empty twins=vb_qa/q-nr-imp
# MUTANT-MATRIX M8 decides=vb_cr/cr-blocked-sug twins=vb_cr/cr-approved-crit
# MUTANT-MATRIX M9 decides=vb_cr/cr-approved-crit twins=vb_cr/cr-approved-imp
# MUTANT-MATRIX M10 decides=vb_cr/cr-nr-imp twins=vb_cr/cr-blocked-crit
# MUTANT-MATRIX M11 decides=vb_r3/r3-graph-cross1 twins=cs/partcite
# MUTANT-MATRIX M12 decides=vb_qmode/q-mode-sug twins=cs/partcite
# MUTANT-MATRIX M13 decides=vb_qleg/q-leg-nr-one twins=vb_qleg/q-two-containers
# MUTANT-MATRIX M14 decides=vb_qa/q-unclassed twins=vb_qa/q-nr-empty
# MUTANT-MATRIX M15 decides=fr_verdict/fr-plain twins=fr_verdict/fr-expected-only
# MUTANT-MATRIX M16 decides=fr_verdict/fr-reorder twins=fr_verdict/fr-expected-only
# MUTANT-MATRIX M17 decides=fr_orphan/fr-ac10 twins=fr_orphan/fr-ac1
# MUTANT-MATRIX M18 decides=serial/sr-q-set twins=serial/sr-cr-approved
# MUTANT-MATRIX M19 decides=serial/sr-q-twosame twins=serial/sr-q-suffix
# MUTANT-MATRIX M20 decides=fr_bound/frb-legacy twins=fr_bound/frb-severity
# MUTANT-MATRIX M21 decides=x_dupall/two twins=x_dupall/one
# MUTANT-MATRIX M22 decides=x_dupall/check twins=x_dupall/preca
# MUTANT-MATRIX M23 decides=canon/cr-filter-k twins=canon/cr-m-noconv
# MUTANT-MATRIX M24 decides=canon/cr-exempt-code twins=canon/cr-exempt-norange
# MUTANT-MATRIX M25 decides=canon_merge/crm-legacy twins=canon_merge/crm-disk-held
# MUTANT-MATRIX M26 decides=canon/cr-nr-norun twins=canon/cr-exempt-rec
# MUTANT-MATRIX M27 decides=canon_merge/crm-norun twins=canon_merge/crm-nr-norun
# MUTANT-MATRIX M28 decides=canon/cr-exempt-narrow twins=canon/cr-exempt-whole
# MUTANT-MATRIX M29 decides=canon/cr-path-conv twins=canon/cr-path-other
# MUTANT-MATRIX M30 decides=canon/cr-norun-na twins=canon/cr-norun-nonebt
# MUTANT-MATRIX M31 decides=canon/cr-exempt-evil twins=canon/cr-exempt-narrow
# MUTANT-MATRIX M32 decides=canon/cr-serial-legacy twins=canon/cr-ok
# MUTANT-MATRIX M33 decides=canon_merge/crm-disk-legacy twins=canon_merge/crm-disk-held
# MUTANT-MATRIX M34 decides=canon/cr-filter-suffix twins=canon/cr-filter-gorun
# MUTANT-MATRIX M35 decides=canon/cr-filter-gorun twins=canon/cr-filter-lf
# MUTANT-MATRIX M36 decides=canon/cr-filter-lf twins=canon/cr-filter-xff
# MUTANT-MATRIX M37 decides=canon/cr-filter-dd twins=canon/cr-path-super
# MUTANT-MATRIX M38 decides=canon/cr-path-super twins=canon/cr-conv-runner
# MUTANT-MATRIX M39 decides=canon/cr-norun-nonebt twins=canon/cr-norun-other
# MUTANT-MATRIX M40 decides=canon/cr-conv-runner twins=canon/cr-conv-runner-none
# MUTANT-MATRIX M41 decides=adv_qa/ad-q-present-absent twins=adv_qa/ad-q-called
# MUTANT-MATRIX M42 decides=adv_qa/ad-q-legacy-absent twins=adv_qa/ad-q-unreadable-absent
# MUTANT-MATRIX M43 decides=xc_flip/xc-flip twins=xc_merge/xc-merge
# MUTANT-MATRIX M44 decides=xc_merge/xc-merge twins=xc_flip/xc-flip
# MUTANT-MATRIX M45 decides=xc_count/xc-count twins=xc_flip/xc-flip
# MUTANT-MATRIX M46 decides=xc_one/xc-one twins=xc_flip/xc-flip
# MUTANT-MATRIX m-k2only decides=x_lone/x-lone-k8 twins=x_lone/x-partial
# MUTANT-MATRIX m-nomix decides=x_mix/x-mix twins=cs/partcite
# MUTANT-MATRIX-CONTROL VBCTL why=no mutation: each mutant's deciding cell reuses the passing top-level arm of the same predicate from this run as its base-pass flag, and runs over the unmutated sibling copy only when no such arm passed or under --matrix
# MUTANT-MATRIX-DYNAMIC mut_run why=mut_run hands its <id> argument to mutant_killed; every id it is called with has its own MUTANT-MATRIX row above
# MUTANT-MATRIX-REMEASURE bash core/fixtures/review-shard-merge/run.sh --matrix
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="review-shard-merge"
[ -f "$HERE/lib.sh" ] || { echo "FIXTURE BROKEN: $HERE/lib.sh is absent; nothing was asserted" >&2; exit 2; }
# --matrix runs the mutant x cell matrix in place of the twins (MATRIX lines); a plain run never does.
RSM_MATRIX=0
case "${1:-}" in
  "") ;;
  --matrix) RSM_MATRIX=1 ;;
  *) echo "usage: run.sh [--matrix]" >&2; exit 2 ;;
esac
# I10 reads run.sh, not lib.sh, for the ambient-env scrub; this is the same scrub lib.sh performs.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
. "$HERE/lib.sh"
# The kill emitter (BL-828): a kill is scored only behind the same run's base-pass flag.
. "$(cd "$HERE/../lib" && pwd)/mutant.sh"
echo "HERMETIC-CONSUMED core/scripts/partition-review-diff.sh"
echo "HERMETIC-CONSUMED core/scripts/merge-review-shards.sh"
echo "HERMETIC-CONSUMED core/scripts/content-seal.sh"
echo "HERMETIC-CONSUMED core/scripts/wait-for-deliverable.sh"
echo "HERMETIC-CONSUMED core/hooks/ai-dlc-content-seal.sh"
echo "HERMETIC-CONSUMED core/scripts/record-only-diff.sh"

# ---------------------------------------------------------------------------------- the arms
echo "$NAME:"
seed_controls

arm() { # <predicate> <label-ok> <label-bad>
  if "p_$1" "$SRCDIR"; then ok "$2"; eval "ARMOK_$1=1"; else bad "$3 (rc=${RC:-?}): $(cat "$MO" 2>/dev/null | head -3)"; fi
}
arm2() { # <predicate> <label-ok> <label-bad> -- the predicate sets WHY to what it saw
  WHY=""
  if "p_$1" "$SRCDIR"; then ok "$2"; eval "ARMOK_$1=1"; else bad "$3:${WHY:- (no reason recorded)}"; fi
}
arm part "P1: repo A (all files under app/) partitions to >= 2 parts above --min-files 4, app/ split across parts, no part keyed on bare app/, the docs/reviews/ artifact excluded" \
         "P1: repo A did not partition by adaptive depth"
arm dflt_lo "P2: key unset, no flag, $((DFLT - 1)) reviewable files ($DFLT in the diff, one under a scan root) -> exit 3, 'SERIAL:' naming the built-in default $DFLT and $KEY, no manifest" \
             "P2: below the built-in default did not answer SERIAL naming the default"
arm dflt_hi "P2b: key unset, no flag, exactly $DFLT reviewable files -> partitions to >= 2 parts (the default is ON, and the boundary is inclusive)" \
            "P2b: exactly the built-in default's file count did not partition"
arm off "P2c: $KEY=0, and --min-files 0, each on $DFLT files -> exit 3, 'SERIAL: review sharding is disabled' naming the source, no manifest" \
        "P2c: a zero threshold did not answer SERIAL disabled"
arm refuse_val "P2d: $KEY set but EMPTY, and $KEY=abc -> each REFUSED exit 2 'is not a non-negative integer', no manifest (empty is NOT unset)" \
               "P2d: an empty or non-numeric key was not refused"
arm prec "P2e: --min-files $((DFLT + 1)) with $KEY=4 on $DFLT files -> SERIAL naming --min-files; --min-files 4 with $KEY=$((DFLT + 1)) -> partitions (the flag wins both ways)" \
         "P2e: the key overrode --min-files"
arm dmerge "P2f: a repo of $((DFLT + 2)) files partitioned with the threshold UNSET records a NUMERIC min-files in its manifest and merges end to end (the merge hands it back as --min-files)" \
           "P2f: a default-built partition did not merge, or its manifest did not record the numeric threshold"
arm env_key "P3: the key set to 4 in the environment, no flag -> repo B partitions to >= 2 parts" \
        "P3: the environment threshold did not partition"
arm worst "V1: worst-of -- {B,A,A,xA} merges BLOCKED (cross, last and majority say APPROVED); {NR,B,NR,xA} merges BLOCKED (majority says NR); all-APPROVED merges APPROVED; each read back Check 1's way" \
          "V1: the merged verdict is not the worst shard verdict"
arm c1 "C1: the merged file matches Check 1's derived pattern exactly once and Check 1's read gives NEEDS_REWORK" \
       "C1: the merged file does not match Check 1 exactly once with the right value"
arm conserve "C2: conservation -- a unique token and the finding heading of each of parts 1-3 and cross appear in the merged file" \
             "C2: a shard's content was lost in the merge"
arm miss_ord "R1: part 2 missing -> REFUSED, exit 2, nothing at --out" "R1: a missing part was not refused cleanly"
arm miss_cross "R2: cross.md missing -> REFUSED, exit 2, nothing at --out" "R2: a missing cross shard was not refused cleanly"
arm dup "R3: 1.md beside 01.md -> REFUSED 'delivered more than once', exit 2, nothing at --out" "R3: a duplicate part was not refused cleanly"
arm part_cite "R4: part 2 reporting a finding citing part 3 -> REFUSED, exit 2, nothing at --out" "R4: a part citing another part was not refused cleanly"
arm cross_one "R5: a cross finding citing one part -> REFUSED, exit 2, nothing at --out" "R5: a one-part cross finding was not refused cleanly"
arm sha_dir "R6: a shard dir named for another sha12 than the manifest's -> REFUSED, exit 2, nothing at --out" "R6: a manifest/dir-name sha mismatch was not refused cleanly"
arm sha_rev "R7: a shard whose reviewed-sha is not the manifest's sha -> REFUSED, exit 2, nothing at --out" "R7: a reviewed-sha mismatch was not refused cleanly"
arm moved "R8: the worktree's scan roots moved after the manifest was written (the re-run still partitions, differently) -> REFUSED 'differs from the map it records', nothing at --out" \
          "R8: a manifest map that no longer matches a re-run partition was not refused cleanly"
arm a3 "R9: a shard body carrying '## Verdict' -> REFUSED on Check 1's count (2), exit 2, nothing at --out" "R9: a shard verdict heading was not refused"
arm rerun "R10: an identical re-merge is UNCHANGED; a re-merge after shard 1 changed -> REFUSED 'never overwritten', exit 2, the first review byte-unchanged" \
          "R10: a re-merge over a different existing review was not refused with the file intact"
arm anc "R11: a base that is not an ancestor of the frozen sha (a sibling commit, same two-dot file set) -> partition REFUSED on stderr, exit 2, no map, no manifest" \
        "R11: a diverged base was partitioned"
arm cross_sha "R12: cross.md whose reviewed-sha is the base -> REFUSED 'not the frozen sha', exit 2, nothing at --out" \
              "R12: a cross shard reviewing another tree was not refused"
arm bad_verdict "R13: 'shard-verdict: PASS' -> REFUSED, exit 2, nothing at --out" "R13: a verdict outside the ranked three was not refused"
arm noparts "R14: a '#### ' finding under ## Findings with no 'parts:' line -> REFUSED, exit 2, nothing at --out" \
            "R14: an uncited finding was not refused"
arm manifest "R15: an identical partition re-run leaves .manifest; a --max-parts 2 re-run (a different map) -> REFUSED 'never overwritten', manifest byte-unchanged" \
             "R15: a differing partition re-run over an existing manifest was not refused with the manifest intact"
arm two_sha "R16: a shard carrying two 'reviewed-sha:' lines (the right one first) -> REFUSED, exit 2, nothing at --out" \
            "R16: a second reviewed-sha line was not refused"
arm default_k "P4: four equal-weight groups and no --max-parts -> exactly 4 parts (the default K)" \
              "P4: the default part ceiling is not 4"
arm stray "R17: a 'parts:' line behind a bullet inside ## Findings, and a '#### ' citing part 3 under '## Critical Issues' beside a real ## Findings -> each REFUSED, exit 2, nothing at --out" \
          "R17: a parts: line outside a '#### ' finding under ## Findings was not refused"
arm nofind "R18: a shard with no '## Findings' section -> REFUSED, exit 2, nothing at --out" "R18: a shard without ## Findings was merged"
arm knob "R19: --min-files, the env key and --max-parts at 18446744073709551617 -> each REFUSED 'longer than 9 digits', no manifest; a 9-digit --min-files answers SERIAL" \
         "R19: a value over 9 digits was not refused before arithmetic"
arm fence_nested "R20: a '#### ' finding inside a four-backtick fence holding a three-backtick block is not counted -> MERGED with the base world's findings count" \
                 "R20: a four-backtick fence closed on the inner three-backtick line and the fenced finding was counted"
arm q_worst "Q1: --gate qa worst-of -- all PASS merges PASS; one part NEEDS_REWORK (cross PASS) merges NEEDS_REWORK; cross NEEDS_REWORK (parts PASS) merges NEEDS_REWORK; each read back Check 1's way" \
            "Q1: the merged QA verdict is not the worst shard verdict"
arm q_table "Q2: a cross shard carrying a '| AC | Verdict |' table under '## Acceptance Criteria' merges with exactly one Check-1 match, every shard's token and finding conserved" \
            "Q2: a QA cross shard with a per-AC table did not merge to exactly one Check-1 match"
arm q_title "Q3: the merged title is '# Code Review: 1 (merged from 4 shards)' for gate 1 and '# QA Validation: 1 (merged from 4 shards)' for gate 2" \
            "Q3: a merged title does not name its gate"
arm q_fenced "Q4: a part shard quoting '## Acceptance Criteria' and '## Deferred ACs' inside a fence merges (the section refusals skip fenced text)" \
             "Q4: a fenced section heading in a part shard was refused"
arm q_part_ac "Q5: a part shard carrying '## Acceptance Criteria' -> REFUSED, exit 2, nothing at --out" "Q5: a part shard's per-AC section was merged"
arm q_part_def "Q6: a part shard carrying '## Deferred ACs' -> REFUSED, exit 2, nothing at --out" "Q6: a part shard's deferred-AC section was merged"
arm q_cross_noac "Q7: cross.md without '## Acceptance Criteria' -> REFUSED, exit 2, nothing at --out" "Q7: a cross shard with no per-AC section was merged"
arm q_cross_twoac "Q8: cross.md with two '## Acceptance Criteria' sections -> REFUSED, exit 2, nothing at --out" "Q8: a cross shard with two per-AC sections was merged"
arm q_cross_twodef "Q9: cross.md with two '## Deferred ACs' sections -> REFUSED, exit 2, nothing at --out" "Q9: a cross shard with two deferred-AC sections was merged"
arm q_nodef "Q10: cross.md with NO '## Deferred ACs' merges (at most one, not exactly one)" "Q10: a cross shard without a deferred-AC section was refused"
arm q_rank "Q11: a qa shard carrying 'shard-verdict: APPROVED' -> REFUSED, exit 2 (gate 1's set is not gate 2's)" "Q11: a gate-1 verdict was ranked under --gate qa"
arm q_pm "Q12: pass markers, both gates -- dir -p2 with --out -p2 merges, dir -p2 with an unmarked --out and an unmarked dir with --out -p2 refuse (qa); the same three cells for code-review at -p3/-p2" \
         "Q12: a shard directory's pass marker and --out's disagree and the merge went ahead, or agree and it refused"
arm q_suffix "Q13: a <idx>-code-review-<sha12> dir merged --gate qa, and a <idx>-qa-validation-<sha12> dir merged --gate code-review -> each REFUSED, nothing at --out" \
             "Q13: a shard directory of the other gate was merged"
arm q_gate "Q14: --gate deploy -> REFUSED, exit 2, nothing at --out" "Q14: an unknown gate was not refused"
arm q_vset "Q15: qa.md declaring a third verdict -> --gate qa REFUSED; code-reviewer.md declaring a fourth -> --gate qa still merges PASS and --gate code-review refuses (QA's set is lifted from qa.md)" \
           "Q15: QA's verdict set is not lifted from qa.md alone"
arm q_secvar "Q16: part shards carrying '## Acceptance Criteria:', '##  Acceptance Criteria', '## acceptance criteria', '### ACCEPTANCE CRITERIA', '### Deferred ACs', '## Deferred / operator-owned', '## deferred acs', and a cross shard with a second '## Acceptance Criteria:' -> each REFUSED; the variants inside a fence and '#### ' findings titled with a section name merge" \
             "Q16: a section-heading variant escaped the count, or a fenced variant or a '#### ' finding was counted"
arm q_ho_ok "H1: part 2's 'handover: AC7' matched by cross's 'handover-run: 2 AC7 RED' merges PASS (the shard verdicts' worst-of), read back Check 1's way, the replay tabled" \
            "H1: a matched RED hand-over did not merge at the shard verdicts' worst-of"
arm q_ho_unm "H2: part 2's 'handover: AC7' with no 'handover-run:' in cross.md -> REFUSED naming '2 AC7', exit 2, nothing at --out" \
             "H2: an unmatched hand-over was merged -- its HARD GATE replay was run by nobody"
arm q_ho_orph "H3: cross.md's 'handover-run: 2 AC7 RED' with no hand-over in part 2 -> REFUSED, exit 2, nothing at --out" \
              "H3: an orphan handover-run was merged"
arm q_ho_force "H4: 'handover-run: 2 AC7 GREEN-SURVIVED', and NO-BASELINE, each over four PASS shards -> merges NEEDS_REWORK, read back Check 1's way" \
               "H4: an unmet hand-over replay did not force NEEDS_REWORK"
arm q_ho_cross "H5: a 'handover:' line in cross.md -> REFUSED, exit 2, nothing at --out" "H5: a cross-shard hand-over was merged"
arm q_ho_prun "H6: a 'handover-run:' line in part shard 3 -> REFUSED, exit 2, nothing at --out" "H6: a part-shard handover-run was merged"
arm q_ho_fenced "H7: 'handover: AC7' fenced in part 2 and 'handover-run: 2 AC9 GREEN-SURVIVED' fenced in cross merge PASS (neither is counted)" \
                "H7: a fenced hand-over line was counted"
arm q_ho_shape "H8: a replay finding citing '1, 2' for a part-2 replay, and a bulleted '- handover: AC7', each REFUSED" \
               "H8: a mis-cited replay finding or a bulleted hand-over was merged"
arm q_ho_multi "H9: part 2's 'handover: AC7 AC8' with only 'handover-run: 2 AC7 RED' in cross.md -> REFUSED 'names more than one AC', nothing at --out" \
               "H9: a two-AC hand-over line was merged -- the second AC's replay is run by nobody"
arm q_ho_twoline "H10: two 'handover:' lines in one part-2 finding, both run -> REFUSED on the per-finding count, nothing at --out" \
                 "H10: a finding carrying two hand-over lines was merged"
arm q_ho_dup "H11: two part-2 findings each 'handover: AC7', run once -> REFUSED 'handed over more than once', nothing at --out" \
             "H11: a duplicate hand-over was merged"
arm q_ho_deco "H12: '**handover:** AC7', '*handover*: AC7', a backtick-quoted and a '>'-quoted hand-over, 'hand-over: AC7', and the same for handover-run -> each REFUSED as a malformed hand-over" \
              "H12: a decorated, quoted or hyphenated hand-over line was merged -- the AC dropped with no replay owed"
arm q_ho_nocolon "H13: 'handover - AC7', 'handover AC7', 'handover-run 2 AC7 RED' and 'handover-run - 2 AC7 RED' at column 0 -> each REFUSED as a malformed hand-over" \
                 "H13: a column-0 hand-over missing its colon was merged"
arm q_ho_prose "H14: prose naming the hand-over at column 0 ('The handover step ...', 'Handover to the cross shard: none ...', 'Handover step', 'hand-over is not owed') merges PASS" \
               "H14: prose about the hand-over was refused as a malformed hand-over line"
arm q_ho_acid "H15: an empty 'handover:' (recorded as '-') and 'handover: .', each with its matching run -> REFUSED, an <AC-id> begins with a letter or digit" \
              "H15: a hand-over naming no AC was merged"
arm q_hc_dash "H16: part 2 declaring 'handovers: 1' with its hand-over written 'handover — AC7' (em dash, unparsed) -> REFUSED on the count mismatch, nothing at --out" \
              "H16: an em-dash hand-over under a declared count of 1 was not refused on the count"
arm q_hc_hidden "H17: 'handovers: 1' with the hand-over as a pipe-table row and as an HTML comment (forms the malformed-line pattern does not match) -> each REFUSED on the count mismatch" \
                "H17: a hand-over the malformed-line pattern cannot see merged with no replay owed"
arm q_hc_zero "H18: 'handovers: 0' over a correct, run 'handover: AC7' -> REFUSED on the count mismatch" \
              "H18: a declared count of 0 over a parsed hand-over was merged"
arm q_hc_missing "H19: a part shard with no 'handovers:' line -> REFUSED, nothing at --out" \
                 "H19: a part shard without its declared hand-over count was merged"
arm q_hc_two "H20: a part shard with two 'handovers:' lines -> REFUSED, nothing at --out" \
             "H20: a part shard declaring its hand-over count twice was merged"
arm q_hc_nonint "H21: 'handovers: x', '-1', 2^64, and '?' / '[1]' from a cwd holding files 0 and 1 -> each REFUSED as not a non-negative integer" \
                "H21: a non-integer hand-over count was merged"
arm q_hc_cross "H22: a 'handovers:' line in cross.md -> REFUSED, nothing at --out" \
               "H22: a cross shard declaring a hand-over count was merged"
arm q_hc_none "H23: every part shard 'handovers: 0', cross.md with none, no hand-over anywhere -> merges PASS, read back Check 1's way" \
              "H23: a world with no hand-overs and correct zero counts was refused"
arm q_ho_widen "H24: under 'handovers: 0', 'handover' followed by an em dash, en dash, '=', '->', a trailing reason, a parenthesised reason, a '1. ' list prefix (bare and bold), and 'handover-run —' -> each REFUSED as a malformed hand-over" \
               "H24: a hand-over spelling the widened malformed-line pattern names was merged"
arm x_k8 "X1: K=8 -- eight parts and cross-1..6 (one per --cross-groups row) merge, titled 'merged from 14 shards', one body header per group" \
         "X1: a K=8 shard dir with every cross group was not merged as fourteen shards"
arm2 x_lone "X2: ONE cross.md in place of the groups at K>2 is ACCEPTED (BL-811) -- K=8 merges titled 9 shards, the parts then '## Shard: cross' last, a 1, 2 finding owned by it; K=3 --gate qa merges PASS with its per-AC table and --check-shard cross.md is SHARD-OK; a partial cross-1..5 set at K=8 REFUSED naming cross-6" \
          "X2: the lone cross shard at K>2 was refused, mis-merged, or a partial cross-<g> set was merged"
arm2 x_mix "X3: cross.md beside cross-1..3 -> REFUSED as a mix, nothing at --out" "X3: cross.md and cross-<g>.md merged together"
arm x_unknown "X4: cross-4 at K=3, and cross-1.md in place of cross.md at K=2 -> each REFUSED as a group --cross-groups does not print" \
              "X4: a cross shard naming a group the table does not print was merged"
arm x_owner "X5: K=8, a finding citing 1, 2 in cross-3 AND in its owner cross-1 -> REFUSED naming the owner; 1, 2, 7 in cross-3 alone merges, count +1; the same finding in cross-1 merges and the finding count rises by one" \
            "X5: a cross finding reported by a group that does not own it was merged, or its owner's copy was refused"
arm x_actable "X6: --gate qa, the per-AC table in cross-2 and the deferred record in cross-3 -> each REFUSED, only cross-1 writes them" \
              "X6: a per-AC table or deferred record outside cross-1 was merged"
arm x_horun "X7: --gate qa, part 2's hand-over replayed by cross-2 rather than cross-1 -> REFUSED, only cross-1 runs a replay" \
            "X7: a hand-over replayed by a cross group other than the execution owner was merged"
arm x_k2 "X8: K=2 -- cross.md merges under both gates, titled 'merged from 3 shards', its body header '## Shard: cross'" \
         "X8: a K=2 shard dir with its one cross.md did not merge as before"
arm x_seat "X9: one shard without 'seat-complete:' beside shards with it, a marker that is not the last non-blank line, and findings=3 over 1 finding -> each REFUSED; every shard ending in it (blank lines after) merges, the marker dropped" \
           "X9: an unfinished shard was merged beside finished ones, or finished shards were refused"
arm cr_ho_ok "G1: --gate code-review, parts 1 and 2 each hand over a disjoint replay, cross-1 runs both once -> merges APPROVED with both tabled; AC7 GREEN-SURVIVED merges NEEDS_REWORK" \
             "G1: gate-1 hand-overs owned by two parts and run once each did not merge, or an unmet replay did not force NEEDS_REWORK"
arm cr_ho_block "G2: --gate code-review, every shard BLOCKED and a NO-BASELINE replay -> merges BLOCKED (the forced NEEDS_REWORK never lowers a verdict)" \
                "G2: an unmet replay lowered a BLOCKED review to NEEDS_REWORK"
arm cr_ho_unm "G3: --gate code-review, part 2's hand-over run by no shard -> REFUSED, nothing at --out" \
              "G3: a gate-1 hand-over handed to no replay was merged"
arm cr_ho_runtwice "G4: --gate code-review, one hand-over replayed twice by cross-1 -> REFUSED 'more than one handover-run', nothing at --out" \
                   "G4: a hand-over replayed twice was merged"
arm cr_hc_missing "G5: --gate code-review, a part shard with no 'handovers:' line -> REFUSED, nothing at --out" \
                  "G5: a gate-1 part shard without its declared hand-over count was merged"

# ------------------------------------------------------------------------------------ BL-737
# Each predicate sets WHY to what it saw. A predicate that never ran leaves no `ok` line, so every arm
# here is presence-shaped: the receipt counts these labels' `ok` lines, never the exit alone. arm2
# itself is defined beside arm, above, because X2 and X3 use it too.
arm2 cs "CS1: --check-shard prints the full merge's REFUSED line byte-for-byte, the physical path through a symlinked alias, for $CS_N single-defect worlds (every per-shard class under both gates, the marker count, key= and <shard>, and the content seal; qa includes graph's '## Deferred live check (not scored here)' part heading); a clean shard answers SHARD-OK" \
         "CS1: --check-shard's verdict is not the merge's own"
arm2 copies "CP1: has_marker, content_hash, seal_body and seal_of in merge-review-shards.sh, and content-seal.sh's seal_review_body body, are byte-identical to wait-for-deliverable.sh's, extracted by name, and a one-byte drift in either copy is seen" \
             "CP1: the merge's copy of the seal reader is not wait-for-deliverable.sh's"
arm2 owner "OT1: every refusal family's owner tail names the shard whose file must change -- per-shard, missing, unfinished, duplicate key (both files), hand-over join (part and cross-1), hand-over twice, replay twice, Check-1 multi-match, bad name and set-level (lead); the owner duplicate names the NON-owner, and --check-shard reads the owner only once it is sealed" \
           "OT1: an owner tail names the wrong shard"
arm2 key "KY1: a set every seat wrote and --mark closed merges with each marker keyed by its own file name; a marker key= naming another shard, and a <shard> field naming another, each REFUSED [owner: 2]" \
         "KY1: the marker key check accepts a key that is not the file's, or refuses the right one"
arm2 mark "MK1: --mark on a review shard refuses a <shard> that is not the file key, a caller key= and a caller sha= word, and findings=3 over 1 finding -- each exit 64, the file byte-unchanged -- and the same call with the right fields marks it 'key=2'" \
          "MK1: --mark marked a review shard it should have refused, or refused the right call"
arm2 seal_rewrite "SE1: a qa part shard its seat wrote and marked reads SEAL-OK; rewritten by an in-place sed rewrite and re-marked, --mark refuses (64) with the re-dispatch remedy, the file unchanged" \
                  "SE1: a Bash-rewritten review shard was re-marked"
arm2 session "SE2: a seat-sealed set merges; after a top-level-session Edit row on shard 2 the merge REFUSES it [owner: 2]; after an agent Edit row it merges again" \
             "SE2: a shard last written by the session was merged, or the agent's re-write refused"
arm2 legacy "LG1: legacy markers over an old engine merge with the exact 'LEGACY: ... reviewed sha <full sha> predates the key= engine' line per shard (a Write then the old Bash append accepted on body_sha); the same Write then a sed rewrite, the sentinel engine at the frozen sha, and an engine in neither layout each REFUSED" \
            "LG1: the legacy rule acquitted what it should refuse, or refused a legitimate legacy shard"
arm2 layouts "LY1: from a linked worktree the seal reader names the MAIN checkout's ledger in a distribution-layout and a consumer-layout tree (never the worktree's own decoy); the recorder fired there writes MAIN's ledger, both readers read SEAL-OK, and a set sealed there merges" \
             "LY1: the review-shard ledger is not the main checkout's from a linked worktree"
arm2 first_ts "FT1: a review-shard row written before a gate part does not move --first-tool-ts; the same row without body_sha does" \
              "FT1: a review-shard row moved --first-tool-ts, or the control did not"
arm2 env "EV1: on a PATH built from tools.decl without jq, a seat-sealed set is REFUSED 'SEAL-UNAVAILABLE' [owner: lead] with no re-dispatch, and --mark exits 64 relaying it with the environment remedy, the file unchanged; the same set with jq added back merges" \
         "EV1: an environment that cannot read the seal was charged to a reviewer, or the jq control did not merge"
arm2 unmarked "UM1: adv-strip.sh's input -- every seat-complete line stripped, one verdict rewritten by sed -- over a sentinel-engine frozen sha with no seal rows is REFUSED 'carries no content-seal row'; the same steps over the old engine merge" \
              "UM1: an unmarked set over the key= engine merged without a seal row, or the old-engine control was refused"

# ------------------------------------------------------------------------------------ BL-740
# VERDICT BACKING. Every refusal is driven through the merge AND --check-shard, the two REFUSED lines
# byte-equal; every pass merges and answers SHARD-OK. Each cell writes its own WHY token.
arm2 vb_cr "VB1: --gate code-review -- NEEDS_REWORK with the empty findings template REFUSED with the stem, NEEDS_REWORK with one Important merges, BLOCKED with one Critical merges, BLOCKED with only a Suggestion REFUSED, APPROVED with a Critical REFUSED, APPROVED with an Important merges; each refusal byte-equal under --check-shard" \
           "VB1: a code-review verdict was not held to its own findings"
arm2 vb_qmode "VB2M: --gate qa over qa.md's three containers -- NEEDS_REWORK backed only by a Suggestions finding REFUSED, the severity mode alone (M12's one cell)" \
              "VB2M: QA verdict backing stayed count-only over a three-container qa.md"
arm2 vb_qa "VB2: --gate qa over qa.md's three containers -- NEEDS_REWORK with 0 findings, and with only a Suggestions finding (naming the move-it remedy), REFUSED; with an Important finding merges, no LEGACY line; PASS with a Critical REFUSED, with an Important merges; a finding under no container REFUSED as unclassed; each refusal byte-equal under --check-shard" \
           "VB2: a qa verdict was not held to its own findings' severity"
arm2 vb_qleg "VB2L: --gate qa over a qa.md declaring NO container (a consumer between pull step 3 and the reconcile merge) -- the LEGACY count-only line, an uncontained NEEDS_REWORK finding and a PASS over a Critical heading merge, an empty NEEDS_REWORK REFUSED with the count-only text; a qa.md declaring TWO containers REFUSED [owner: lead]; the code-review gate under that root still refuses an unclassed finding" \
             "VB2L: the zero-container fallback is not count-only, or a two-container qa.md was read"
arm2 fr_verdict "FR1: --gate qa, cross-1's per-AC table -- a PASS merge over an AC4 row reading FAIL, **FAIL**, 'FAIL (no RED)', and FAIL under a Result column moved to position 3, each REFUSED [owner: cross-1]; FAIL only in Expected/Got, and all-PASS rows, merge PASS; NEEDS_REWORK carried by part 2's finding naming AC4 merges" \
                 "FR1: a QA merge read PASS over a per-AC FAIL row, or refused a row that does not fail"
arm2 fr_orphan "FR2: a FAIL row under a NEEDS_REWORK merge whose AC no '#### ' finding names is REFUSED as an orphan (the table's own mention does not count), a finding naming only AC10 does not name AC1; a finding naming AC1 beside AC10 merges" \
               "FR2: an orphan per-AC FAIL row merged, or the AC id matched as a substring"
arm2 fr_graph "FR4: graph 811ad3d7d story 3.1 qa p2 as two states, frozen over a tree whose INSTALLED qa.md declares no container and judged by today's -- cross-1 PASS with an AC4 FAIL row and the NEEDS_REWORK cross shard carrying only its AC10 finding REFUSED as an orphan FAIL row [owner: cross-1] (not the FAIL-under-PASS rule); with its hand-added uncontained AC4 finding the set merges NEEDS_REWORK with the severity-boundary LEGACY line naming cross-2" \
               "FR4: the graph AC4 orphan was not refused before its finding, or not accepted after it"
arm2 fr_bound "FRB: the severity boundary is read off qa.md AS INSTALLED AT THE FROZEN SHA -- graph's post-F2 set frozen over a container-less installed qa.md merges NEEDS_REWORK with the LEGACY line; frozen over the three-container one REFUSED unclassed [owner: cross-2], no LEGACY line; frozen over a tree installing no qa.md (unreadable) REFUSED the same way" \
               "FR4: the graph AC4 orphan was not refused before its finding, or not accepted after it"
arm2 fr_remedy "FR3: the orphan remedy is satisfiable -- cross-1 filing the AC4 finding under cross-2's own parts set is the owner-duplicate refusal, under a set cross-1 owns it merges, and the owning cross-2 naming AC4 in its own finding merges" \
               "FR3: the orphan FAIL row's remedy cannot be satisfied under the owner rule"
arm2 serial "SR1: --check-serial, gate 3's Check 1 rule and no stricter -- '## Verdict / PASS', 'Verdict: NEEDS_REWORK', 'Verdict: PASS (all ACs)', '## Verdict / PASS.' and two matches both reading PASS answer SERIAL-OK; the heading-then-'Verdict: PASS' union and two different values, 'PASS-pending', APPROVED under --gate qa, a renamed '## Result' code review (0 matches), a PASS over a FAIL or FAILED row (the latter under '### Acceptance criteria'), and FAIL rows named only by 'AC-4.1' or a 'handover:' line each REFUSED [owner: serial]; code-review APPROVED and a backed NEEDS_REWORK FAIL row answer SERIAL-OK" \
             "SR1: --check-serial accepted a malformed serial verdict, or refused a correct one"
arm2 canon "CR1: --check-serial --gate qa, a PASS waits for its canonical run -- the run line plus a counted result, a bulleted pair and a '-p no:cacheprovider' near-miss answer SERIAL-OK; no run line, counts only on a RED replay line, -k in four spellings, --deselect, a file and a node id, a path root and a marker the conventions do not declare, no result line, a NOT FINISHED result and a result with no count each REFUSED [owner: serial]; NEEDS_REWORK with no run SERIAL-OK; 'none, <reason>' over a record-only --range SERIAL-OK, over a range touching a test, a test module under test-results/, a seat-narrowed rework range, an empty range and a non-ancestor base, and with no range REFUSED; N/A, TBD and skipped held to the same partition; a bare none REFUSED; -m unit accepted with no conventions and declared, a declared path root accepted; a root whose qa.md lacks the sentinel prints LEGACY and accepts" \
           "CR1: --check-serial accepted a PASS with no canonical run, or refused a correct one"
arm2 canon_merge "CR2: the qa merge -- four PASS shards carrying the run merge with no LEGACY line; the execution owner's run lines removed REFUSED [owner: cross-1]; the same with a NEEDS_REWORK part merges NEEDS_REWORK; frozen over an installed qa.md with no label, LEGACY and merges; qa.md untracked at the frozen sha and on disk without the label LEGACY, with it held; neither, held naming both paths; --range on the merge REFUSED" \
                 "CR2: the merge did not hold the execution owner's PASS to its canonical run, or held a legacy set"
# BL-790: THE ADVISOR LINE, per shard under both gates and through --check-serial, its absence keyed on
# the gate's role file AT THE FROZEN SHA (lead worlds a and b; the untracked fallback refuses).
AD_ARM="the sentinel world: absent REFUSED [owner: 1] naming the role file that prescribes it, called, unavailable and 'unavailable' with trailing blanks and CR merge with no LEGACY line, maybe, two lines, '- advisor: called' (naming the remediator near-miss) and '**advisor:** called' REFUSED; a fenced 'advisor: maybe' above the bare line, and graph's prose 'Advisor: ...' line beside it, merge; a role file at the frozen sha without the sentinel accepts the absence, and that prose line alone, with the LEGACY line by value and still refuses maybe; a role file unreadable at the sha REFUSED; world (a), frozen over the old role file with the new one on disk, LEGACY and merges; world (b), frozen over the new one with the old on disk, REFUSED; untracked at the sha with the new copy on disk REFUSED naming the on-disk fallback and the commit remedy, with the old copy on disk LEGACY naming it"
arm2 adv_qa "AD1: --gate qa -- $AD_ARM" "AD1: the qa merge did not hold the advisor line to its era"
arm2 adv_cr "AD2: --gate code-review -- $AD_ARM" "AD2: the code-review merge did not hold the advisor line to its era"
arm2 adv_serial "AD3: --check-serial under both gates, over the installed role file carrying the sentinel -- absent, maybe, two lines and '- advisor: called' REFUSED [owner: serial], called, unavailable, a trailing CR and a fenced 'advisor: maybe' above the bare line SERIAL-OK; over a root whose role files lack it, absent SERIAL-OK with the LEGACY line by value" \
                 "AD3: --check-serial did not hold the advisor line to the installed role file's era"
# SR2 (BL-742 role text): qa.md's and code-reviewer.md's serial passages each name the --check-serial
# call; offenders with the step removed from either file are refused.
grep -vF -- "$SR_ROLE_CMD <validation file> --gate qa" "$QA_MD" > "$WORK/sr-qa-nostep.md"
grep -vF -- "$SR_ROLE_CMD <review file> --gate code-review" "$ROLE_MD" > "$WORK/sr-cr-nostep.md"
if cmp -s "$QA_MD" "$WORK/sr-qa-nostep.md" || cmp -s "$ROLE_MD" "$WORK/sr-cr-nostep.md"; then
  bad "SR2: FIXTURE STALE -- a serial-step offender's edit matched nothing, so the predicate would score the shipped text"
elif ! p_serial_role "$QA_MD" "$ROLE_MD"; then
  bad "SR2: qa.md or code-reviewer.md does not tell its serial seat to run --check-serial before returning"
elif p_serial_role "$WORK/sr-qa-nostep.md" "$ROLE_MD" || p_serial_role "$QA_MD" "$WORK/sr-cr-nostep.md"; then
  bad "SR2: FIXTURE BROKEN -- the serial-step predicate passed a role file with the step removed"
else
  ok "SR2: qa.md and code-reviewer.md each tell the serial seat to run merge-review-shards.sh --check-serial before returning; with the step removed from either, refused"
fi
arm2 vb_r3 "VB3: graph s319 3.1's cross-1 shape (qa NEEDS_REWORK, its ## Findings saying the gap is another group's) REFUSED byte-equal under --check-shard, naming the set 'shard-verdict: PASS' exit first, then the file-here exit, and [owner: cross-1]" \
           "VB3: the cross-1 refusal does not name both exits and its owner"
arm2 vb_mark "VB4: --mark findings=0 on an empty NEEDS_REWORK code-review shard exits 64 relaying the stem, the file byte-unchanged; the same file with one Important finding re-written marks findings=1 key=2" \
             "VB4: --mark marked an unbacked NEEDS_REWORK, or refused the backed one"
# BL-763: every owner-duplicate refusal in one run, and --check-shard exits 2 on one (--mark keys on it).
arm2 x_dupall "X10: K=3 -- duplicates in cross-2 and cross-3 print two REFUSED lines (tails cross-2, cross-3), one prints one, an owner's own repeat merges, --check-shard over a duplicate exits 2 with no SHARD-OK, a duplicate then a later per-shard refusal print both (the duplicate first), an earlier per-shard refusal stands alone, and one shard's duplicate then its own verdict-backing refusal print two lines naming it; nothing written" \
              "X10: a merge did not name every owner duplicate in one run, or --check-shard passed a duplicate"
# BL-808: cited captures leave the threshold COUNT, never the file set (partition-review-diff.sh
# --exclude-captures). XC1 is the discriminating seed: a capture-heavy diff that stays sharded, so the
# merge's flagless re-derivation must reproduce the flagged map. M43-M46 below are owned by these.
arm2 xc_merge "XC1: $((DFLT + 2)) code files and 10 captures partitioned WITH --exclude-captures into a shard dir (no exclude key in its manifest) merge end to end: the merge's flagless re-derivation reproduces the recorded map" \
              "XC1: a capture-heavy flagged partition did not merge through the flagless re-derivation"
arm2 xc_flip "XC2: $((DFLT - 1)) code files and 10 captures partition without the flag; with it -> exit 3, 'SERIAL: $((DFLT - 1)) reviewable file(s) (... 10 cited capture(s) not counted), below the threshold of $DFLT', no shard dir written" \
             "XC2: the flag did not flip a capture-heavy diff to SERIAL cleanly"
arm2 xc_count "XC3: the excluded count is the INTERSECTION -- a list of 13 lines (cap10 only as CRLF, an out-of-diff path, a scan-root path, a duplicate) prints '10 cited capture(s) not counted'; the same ten spelled './' print 0, in the same arm" \
              "XC3: the excluded count is not the list's intersection with the counted files"
arm2 xc_one "XC4: one code file and five captures under --min-files 1 partition without the flag and answer SERIAL 'a review of at most one counted file is never sharded' with it; two code files under the same flag still shard" \
            "XC4: a one-counted-file review was sharded, or a two-file one was not"
arm2 xc_missing "XC5: --exclude-captures naming a file that does not exist -> REFUSED exit 2, nothing on stdout, no manifest" \
                "XC5: an unreadable capture list was not refused"

# ------------------------------------------------- BL-737 mutants (distribution layout only, in-process)
# Each is a copy of the WHOLE resolved script directory (the merge, --mark and the seal resolve their
# siblings beside themselves), one exact substring replaced -- refused unless it occurs exactly once,
# reported DID NOT APPLY otherwise -- and driven through the one predicate that owns it. A kill must
# carry its own reason token in WHY, so a mutant that died for another cause is not scored a kill.
if [ -d "$LIB_DIR/../../scripts" ] && [ "$(cd "$LIB_DIR/../../scripts" && pwd)" = "$SRCDIR" ]; then
  mutate() { # <copy dir> <file> <old> <new> -> 0 applied once
    local f="$1/$2" n
    n="$(OLD="$3" awk 'BEGIN { o = ENVIRON["OLD"] } { s = $0; while ((i = index(s, o)) > 0) { n++; s = substr(s, i + length(o)) } } END { print n + 0 }' "$f")"
    [ "$n" = 1 ] || return 1
    OLD="$3" NEW="$4" awk 'BEGIN { o = ENVIRON["OLD"]; w = ENVIRON["NEW"] }
      { i = index($0, o); if (i > 0) $0 = substr($0, 1, i - 1) w substr($0, i + length(o)); print }' "$f" > "$f.mut" \
      && ! cmp -s "$f" "$f.mut" && cat "$f.mut" > "$f" && rm -f "$f.mut"
  }
  # THE COPY IS THE DERIVED SIBLING SET (BL-755), never the whole script directory. Its roots are the
  # scripts the predicates invoke through their script-dir argument (`$sd/`, `$1/`, `$md/`, `$vb_ctl/`
  # joined to `<name>.sh` in lib.sh and this file). The closure adds every `<name>.sh` that a
  # non-comment line of a member resolves beside itself, meaning a directory expression (`$VAR/`,
  # `${VAR}/`, `)/`) joined to the name, until nothing is added. A sibling the closure misses cannot pass
  # silently: every mutant first runs its selected cell over the UNMUTATED copy (the control, below).
  sib_set() { # -> the derived set, one basename per line, sorted
    local s t f new
    s="$(grep -ohE '\$(sd|1|md|vb_ctl)/[A-Za-z0-9_-]+\.sh' "$LIB_DIR/lib.sh" "$LIB_DIR/run.sh" | sed 's|.*/||' | sort -u)"
    while :; do
      new="$s"
      for f in $s; do
        [ -f "$SRCDIR/$f" ] || continue
        for t in $(grep -v '^[[:space:]]*#' "$SRCDIR/$f" | grep -oE '(\$[A-Za-z_][A-Za-z0-9_]*|\$\{[A-Za-z_][A-Za-z0-9_]*\}|\))/[A-Za-z0-9_-]+\.sh' | sed 's|.*/||' | sort -u); do
          [ -f "$SRCDIR/$t" ] && new="$(printf '%s\n%s\n' "$new" "$t" | sort -u)"
        done
      done
      [ "$new" = "$s" ] && break
      s="$new"
    done
    for f in $s; do [ -f "$SRCDIR/$f" ] && printf '%s\n' "$f"; done
  }
  SIB_SET="$(sib_set)"
  sib_copy() { # <fresh dir> -> 0 when it holds exactly SIB_SET, byte-identical to SRCDIR's
    local f
    [ ! -e "$1" ] && mkdir -p "$1" || return 1
    for f in $SIB_SET; do cp "$SRCDIR/$f" "$1/$f" || return 1; done
    [ "$(for f in "$1"/*; do [ -f "$f" ] && basename "$f"; done | sort)" = "$SIB_SET" ]
  }
  # The set must hold what every predicate drives and what the merge, --mark and the seal resolve. Its
  # size against the directory is printed, never asserted: under hermetic-run the directory holds only
  # declared inputs, so the two can be equal there; sib_copy asserts each copy IS the set, nothing more.
  sib_n="$(printf '%s\n' "$SIB_SET" | grep -c .)" || sib_n=0
  src_n=0; for f in "$SRCDIR"/*; do [ -f "$f" ] && src_n=$((src_n + 1)); done
  sib_miss=""
  for f in merge-review-shards.sh wait-for-deliverable.sh content-seal.sh partition-review-diff.sh partition-document.sh \
           merge-adversarial-shards.sh validate-adversarial-convergence.sh wfd-start-of.sh artifact-path-config.sh; do
    grep -qxF "$f" <<<"$SIB_SET" || sib_miss="$sib_miss $f"
  done
  if [ -z "$sib_miss" ] && [ "$sib_n" -ge 9 ]; then
    ok "SIB: the mutant copy is the derived sibling set, $sib_n of the $src_n files in $SRCDIR, holding the four mut_run siblings and every script they resolve"
  else bad "SIB: FIXTURE ERROR -- the derived sibling set ($sib_n of $src_n) lacks [${sib_miss# }]"; fi
  # THE SELECTOR (BL-755). Every mut_run line names the one cell its mutant is scored on (CS_ONLY), and
  # every predicate a mutant drives runs only that cell (lib.sh `cell`). CS_RAN counts the cells run. The
  # control is each mutant's own cell over the UNMUTATED copy in vb_ctl, which must run exactly ONE cell
  # and pass. A mutant run that runs no cell prints the sentinel `CS-UNSELECTED`, which the receipt counts.
  vb_ctl="$WORK/mut-VBCTL"; VB_CTL_N=0; VB_CTL_OK=1
  if sib_copy "$vb_ctl" && cmp -s "$SRCDIR/merge-review-shards.sh" "$vb_ctl/merge-review-shards.sh"; then :; else VB_CTL_OK=0; fi
  # THE BASE-PASS FLAG (BL-828). B_rsm_ctl is reset at the top of every mut_run and set to 1 only in the
  # passing branch of THAT mutant's own control, so its kill is emitted through mutant_killed only when
  # its own cell passed unmutated in this run. Each control prints its own VBCTL <id> line.
  # THE TWINS. A plain run reads the mutant's `# MUTANT-MATRIX` header line: its first decides= arm must
  # be this mut_run's <predicate>/<cell> (a mutant added or changed without a re-measure is refused), and
  # each twins= arm is run over the mutant copy and must PASS, one cell run. Its unmutated control is the
  # arm above that runs the same predicate over SRCDIR. --matrix records the mutant (mx_rows) instead and
  # matrix_score, after the last mut_run, scores the mutant x cell population the header describes.
  mx_line() { awk -v id="$1" '$1 == "#" && $2 == "MUTANT-MATRIX" && $3 == id { print; n++ } END { exit n != 1 }' "$HERE/run.sh"; }
  mx_field() { printf '%s\n' "$1" | tr ' ' '\n' | sed -n "s/^$2=//p"; } # <header line> <decides|twins>
  TWIN_N=0; MX_CELLS=0; MX_ROWS="$WORK/mx-rows"; : > "$MX_ROWS"
  mut_run() { # <id> <file> <old> <new> <predicate> <reason token> <label>; CS_ONLY names the cell
    local id="$1" md="$WORK/mut-$1" hl dec tw a tp tc
    B_rsm_ctl=0
    [ -n "${CS_ONLY:-}" ] || { bad "$id: FIXTURE ERROR -- no CS_ONLY selector names the cell this mutant is scored on"; return; }
    [ "$VB_CTL_OK" = 1 ] || { bad "$id: FIXTURE ERROR -- the unmutated control copy $vb_ctl was not built from the derived set"; return; }
    WHY=""; CS_RAN=0
    # The control copy is byte-identical to SRCDIR (sib_copy), and the arm that runs this predicate over SRCDIR passed
    # earlier in THIS run with every cell, this one included: that pass is the base-pass flag, so the cell is not
    # re-run over the copy (one run per distinct state). A predicate with no passing arm runs its cell here.
    if [ "$(eval "printf %s \"\${ARMOK_$5:-0}\"")" = 1 ] && [ "$RSM_MATRIX" = 0 ]; then
      VB_CTL_N=$((VB_CTL_N + 1)); ok "VBCTL $id: cell '$CS_ONLY' of $5 passed unmutated (arm $5 passed over the byte-identical SRCDIR set earlier in this run)"; B_rsm_ctl=1
    elif "p_$5" "$vb_ctl" && [ "$CS_RAN" = 1 ]; then
      VB_CTL_N=$((VB_CTL_N + 1)); ok "VBCTL $id: cell '$CS_ONLY' of $5 passed over the unmutated copy, one cell run"; B_rsm_ctl=1
    else bad "$id: FIXTURE ERROR -- the unmutated copy failed cell '$CS_ONLY' of $5 (cells run: $CS_RAN):${WHY}"; return; fi
    sib_copy "$md" || { bad "$id: FIXTURE ERROR -- the derived sibling set was not copied fresh into $md"; return; }
    [ -f "$md/merge-review-shards.sh" ] && [ -f "$md/wait-for-deliverable.sh" ] && [ -f "$md/content-seal.sh" ] && [ -f "$md/partition-review-diff.sh" ] \
      || { bad "$id: FIXTURE ERROR -- a sibling is absent from $md"; return; }
    mutate "$md" "$2" "$3" "$4" || { bad "$id: DID NOT APPLY -- '$3' does not occur exactly once in $2"; return; }
    WHY=""; CS_RAN=0
    if "p_$5" "$md"; then bad "$id: SURVIVED -- $7 ($5 passed over $md/$2)"
    elif case "$WHY" in *"$6"*) true ;; *) false ;; esac; then mutant_killed "${B_rsm_ctl:-0}" "$id" "$id: killed -- $7 ($5:${WHY})"
    else bad "$id: died for another reason than '$6' -- $7 ($5:${WHY})"; fi
    [ "$CS_RAN" -le 1 ] || bad "$id: FIXTURE ERROR -- the mutant ran $CS_RAN cells of $5 under CS_ONLY=$CS_ONLY, not one"
    [ "$CS_RAN" -ge 1 ] || echo "CS-UNSELECTED: $id ran no cell of $5 for CS_ONLY=$CS_ONLY"
    if [ "$RSM_MATRIX" = 1 ]; then printf '%s\t%s\t%s\t%s\n' "$id" "$2" "$5" "$CS_ONLY" >> "$MX_ROWS"; return; fi
    hl="$(mx_line "$id")" || { bad "$id: FIXTURE STALE -- run.sh carries no single '# MUTANT-MATRIX $id' line; re-measure the matrix"; return; }
    dec="$(mx_field "$hl" decides | cut -d, -f1)"; tw="$(mx_field "$hl" twins)"
    [ "$dec" = "$5/$CS_ONLY" ] || { bad "$id: FIXTURE STALE -- its MUTANT-MATRIX line decides=$dec, but mut_run scores $5/$CS_ONLY; re-measure the matrix"; return; }
    [ -n "$tw" ] || { bad "$id: FIXTURE STALE -- its MUTANT-MATRIX line names no twin"; return; }
    for a in $(printf '%s\n' "$tw" | tr ',' ' '); do
      tp="${a%%/*}"; tc="${a#*/}"; WHY=""; CS_RAN=0
      if CS_ONLY="$tc" "p_$tp" "$md" && [ "$CS_RAN" = 1 ]; then TWIN_N=$((TWIN_N + 1)); ok "TWIN $id: $a passed over the mutant copy, one cell run"
      else bad "$id: co-tripped its twin $a, or ran $CS_RAN cells of it, over the mutant copy:${WHY}"; fi
    done
  }
  # matrix_score (--matrix only): for every recorded mutant, its population is the cells of its own drive
  # (listed by running the predicate under CS_LIST, which runs no cell), plus, when that drive declares
  # fewer than two cells, the deciding cell of every other mutant of the same file. Each cell is scored
  # over the mutant copy and over the unmutated control copy (one control per cell, memoised).
  mx_state() { # <predicate> <cell> <script-dir> -> RED|GREEN|SKIP; the predicate's own stdout is dropped
    WHY=""; CS_RAN=0
    if CS_ONLY="$2" "p_$1" "$3" > /dev/null 2>&1 < /dev/null; then [ "$CS_RAN" = 1 ] && echo GREEN || echo SKIP
    else [ "$CS_RAN" = 1 ] && echo RED || echo SKIP; fi
  }
  # mx_twin <id> <deciding arm> <decides list> <population...> -> the twin: the first cell of the
  # population, outside decides=, GREEN over the mutant and the control, after the deciding cell in
  # declaration order, else before it. A function, not a $( ) body: bash 3.2 misparses a `case`
  # pattern's unbalanced `)` inside a command substitution.
  mx_twin() {
    local id="$1" d="$2" dec="$3" q
    shift 3
    for q in $(printf '%s\n' "$@" | awk -v d="$d" '$0 == d { s = 1; next } { if (s) a[++na] = $0; else b[++nb] = $0 }
      END { for (i = 1; i <= na; i++) print a[i]; for (i = 1; i <= nb; i++) print b[i] }'); do
      if printf ',%s,' "$dec" | grep -qF ",$q,"; then continue; fi
      if grep -qxF "MATRIX $id $q mutant=GREEN control=GREEN" "$WORK/mx-log"; then printf '%s' "$q"; return 0; fi
    done
    return 0
  }
  matrix_score() {
    local id f p c cl pop q pc ms cs key dec tw
    mkdir -p "$WORK/mx-cells" "$WORK/mx-ctl"
    while IFS='	' read -r id f p c <&3; do
      cl="$WORK/mx-cells/$p"
      [ -f "$cl" ] || { CS_LIST="$cl.tmp"; : > "$CS_LIST"; WHY=""; "p_$p" "$vb_ctl" > /dev/null 2>&1 < /dev/null || :; CS_LIST=""
        awk '!s[$0]++' "$cl.tmp" > "$cl"; }
      pop="$(sed "s|^|$p/|" "$cl")"
      if [ "$(grep -c . "$cl")" -lt 2 ]; then
        pop="$(printf '%s\n%s\n' "$pop" "$(awk -F'\t' -v id="$id" -v f="$f" '$1 != id && $2 == f { print $3 "/" $4 }' "$MX_ROWS")" | awk 'NF && !s[$0]++')"
      fi
      dec="$p/$c"; tw=""; also=""
      for q in $pop; do
        pc="${q#*/}"; key="$WORK/mx-ctl/$(printf '%s' "$q" | tr '/' '_')"
        [ -f "$key" ] || mx_state "${q%%/*}" "$pc" "$vb_ctl" > "$key"
        cs="$(cat "$key")"; ms="$(mx_state "${q%%/*}" "$pc" "$WORK/mut-$id")"; MX_CELLS=$((MX_CELLS + 1))
        echo "MATRIX $id $q mutant=$ms control=$cs" | tee -a "$WORK/mx-log"
        [ "$q" = "$p/$c" ] && continue
        if [ "$ms" = RED ] && [ "$cs" = GREEN ]; then also="$also,$q"; fi
      done
      tw="$(mx_twin "$id" "$p/$c" "$dec" $pop)"
      echo "MATRIX-HEADER # MUTANT-MATRIX $id decides=$dec twins=${tw:-NONE}"
      [ -z "$also" ] || echo "MATRIX-ALSO # also trips: $id ${also#,}"
    done 3< "$MX_ROWS"
  }
  CS_ONLY=partcite mut_run M1 merge-review-shards.sh '[ $# -eq 1 ] && [ "$1" = "$key" ]' \
    '{ [ -n "$CHECK" ] || { [ $# -eq 1 ] && [ "$1" = "$key" ]; }; }' cs "csc_partcite{" \
    "the part-cite refusal dropped in --check-shard only"
  CS_ONLY=dup-merge mut_run M2 merge-review-shards.sh '|| collect_dup "$sf:$line ($key) cites$distinct, a finding owned by' \
    '|| refuse_to "$ownk" "$sf:$line ($key) cites$distinct, a finding owned by' owner "dup-merge{" \
    "the owner-duplicate refusal names the owner"
  CS_ONLY=shard-3 mut_run M3 wait-for-deliverable.sh '[ "$mk_s_" != "!" ] || mark_refuse' 'true || mark_refuse' mark "shard-3{" \
    "--mark skips the <shard> key check"
  CS_ONLY=seal-rewrite mut_run M4 wait-for-deliverable.sh '*-qa-validation-????????????) MK_GATE=qa ;;' '*-qa-validation-NOMATCH) MK_GATE=qa ;;' \
    seal_rewrite "review-shard branch" "--mark's review-shard (seal) branch does not match a qa-validation path"
  CS_ONLY=sentinel mut_run M5 merge-review-shards.sh 'present) refuse "' 'present) : "' legacy "sentinel{" \
    "a legacy marker is accepted when the frozen sha's engine carries the sentinel"
  CS_ONLY=unmarked-sentinel mut_run M6 merge-review-shards.sh '[ "$ENGINE" != present ] || SEAL_MODE=""' ':' unmarked "unmarked-sentinel{" \
    "the unmarked shard's engine reading is dropped, so it keeps the legacy seal"
  # BL-740. The CONTROL is now per mutant: mut_run runs each mutant's own selected cell over the
  # unmutated copy in $vb_ctl (the same derived set every mutant copies) before it scores the mutant,
  # and VBCTL, after M22, asserts that every mutant's control ran.
  CS_ONLY=q-nr-empty mut_run M7 merge-review-shards.sh '      NEEDS_REWORK|BLOCKED)' '      M7)' vb_qa "q-nr-empty{" \
    "the severity-mode verdict-backing rule removed"
  CS_ONLY=cr-blocked-sug mut_run M8 merge-review-shards.sh '(cls(t, ENVIRON["PS_IMP_"]) ? "imp" : "")' '"imp"' vb_cr "cr-blocked-sug{" \
    "a Suggestions finding counted as Important"
  CS_ONLY=cr-approved-crit mut_run M9 merge-review-shards.sh '[ "$kc_" -eq 0 ] \' 'true \' vb_cr "cr-approved-crit{" \
    "the APPROVED-forbids-Critical half dropped"
  CS_ONLY=cr-nr-imp mut_run M10 merge-review-shards.sh 'CRIT_NAME="$1"; IMP_NAME="$2"; SUG_NAME="$3"' 'CRIT_NAME="Critical"; IMP_NAME=""; SUG_NAME="Suggestions"' \
    vb_cr "cr-nr-imp{" "the container lift replaced by a hard-coded list that omits Important"
  # M11 keeps all three r3 phrases present and reverses only their ORDER (the file-here clause first),
  # so the single token that can fire is the order one.
  CS_ONLY=r3-graph-cross1 mut_run M11 merge-review-shards.sh \
    "If the finding belongs to another shard, set 'shard-verdict: \$best_' here and let that shard's verdict carry it; otherwise file the finding that makes it \$v here, as a '#### ' heading under '### \$CRIT_NAME' or '### \$IMP_NAME' with a 'parts:' set this shard may own (one the owning group's shard does not already carry), or move" \
    "Either way, otherwise file the finding that makes it \$v here, as a '#### ' heading under '### \$CRIT_NAME' or '### \$IMP_NAME' with a 'parts:' set this shard may own (one the owning group's shard does not already carry); If the finding belongs to another shard, set 'shard-verdict: \$best_' here and let that shard's verdict carry it, or move" \
    vb_r3 "r3-owner-first-order{" "the owner-first clause moved after the file-here clause"
  # BL-746. M12 reads qa.md as count-only whatever its template declares (code-review's rule only);
  # M13 drops the zero-container fallback, so a consumer's installed qa.md is refused; M14 drops the
  # unclassed-finding refusal. Each is owned by one cell.
  CS_ONLY=q-mode-sug mut_run M12 merge-review-shards.sh 'if [ "$GATE" = qa ] && [ "$#" -eq 0 ]; then' 'if [ "$GATE" = qa ]; then' \
    vb_qmode "q-mode-sug{" "QA stays count-only when qa.md declares the three containers"
  CS_ONLY=q-leg-nr-one mut_run M13 merge-review-shards.sh 'if [ "$GATE" = qa ] && [ "$#" -eq 0 ]; then' 'if false; then' \
    vb_qleg "q-leg-nr-one{" "the zero-container fallback dropped, so the old installed qa.md is refused"
  CS_ONLY=q-unclassed mut_run M14 merge-review-shards.sh '[ "$ku_" = 0 ] \' 'true \' vb_qa "q-unclassed{" \
    "a finding under no container accepted in severity mode"
  # BL-747. M15 removes the FAIL-row gate from the merge; M16 reads the first column after AC instead
  # of the one headed Result/Verdict; M17 matches the AC id as a substring.
  CS_ONLY=fr-plain mut_run M15 merge-review-shards.sh '  fail_gate "$(awk' '  : "$(awk' fr_verdict "fr-plain{" \
    "the FAIL-row check removed from the merge"
  CS_ONLY=fr-reorder mut_run M16 merge-review-shards.sh 'if (!ac) ac = 2' 'if (!ac) ac = 2; rc = ac + 1' fr_verdict "fr-reorder{" \
    "the result column read by position instead of by its header"
  CS_ONLY=fr-ac10 mut_run M17 merge-review-shards.sh 'if (p !~ /[A-Za-z0-9.]/ && q !~ /[A-Za-z0-9.]/) return 1' 'return 1' fr_orphan "fr-ac10{" \
    "the AC id matched as a substring, so AC10 names AC1"
  # BL-742. M18 drops --check-serial's set-membership read.
  CS_ONLY=sr-q-set mut_run M18 merge-review-shards.sh '    *" $C1V "*) ;;' '    *) ;;' serial "sr-q-set{" \
    "--check-serial skips the set-membership read"
  CS_ONLY=sr-q-twosame mut_run M19 merge-review-shards.sh '  [ "$C1D" = 1 ] \' '  [ "$C1N" = 1 ] \' serial "sr-q-twosame{" \
    "--check-serial reverts to the merge's strict one-match count"
  # M20 drops the severity boundary's LEGACY arm, so a set frozen over a container-less installed qa.md
  # is judged by the current three-container rule.
  CS_ONLY=frb-legacy mut_run M20 merge-review-shards.sh '    if [ "$QA_AT" = legacy ]; then sev_=0' '    if false; then sev_=0' fr_bound "frb-legacy{" \
    "the severity boundary's LEGACY arm dropped"
  # BL-763. M21 collects every duplicate but prints only the first; M22 drops the --check-shard barrier
  # (the two-space-indented one), so --check-shard answers SHARD-OK over a duplicate and --mark seals it.
  CS_ONLY=two mut_run M21 merge-review-shards.sh 'collect_dup() { printf' 'collect_dup() { [ "$DUP_N" -gt 0 ] || printf' x_dupall "two{" \
    "only the first owner duplicate of a run printed"
  CS_ONLY=check mut_run M22 merge-review-shards.sh '  [ "$DUP_N" -eq 0 ] || exit 2' '  :' x_dupall "check{" \
    "the --check-shard duplicate barrier dropped"
  # BL-769. M23 the filter read dropped, so a -k PASS is accepted. M24 the record-only decision dropped,
  # so a code-touching none is accepted. M25 the merge's LEGACY gate dropped, so a set frozen over an
  # installed qa.md with no label is refused. M26 the PASS-only scope dropped, so an early NEEDS_REWORK
  # with no run is refused. M27 the merge's call dropped, so a run-less PASS merges. M28 the serial
  # gate-1-base check dropped, so a seat-narrowed rework range acquits. M29 the conventions file not
  # handed to the serial check, so a declared path root refuses. M30 the no-run inversion reverted, so
  # 'N/A' reads as a run. M31 the record-dir code-suffix exclusion dropped (record-only-diff.sh). M32 the
  # serial LEGACY branch forced off. M33 the merge's on-disk qa.md read dropped.
  CS_ONLY=cr-filter-k mut_run M23 merge-review-shards.sh '  cg_rf_="$(bash "$RO" run-filter "$cg_run_" ${cg_c_:+"$cg_c_"})" \' '  cg_rf_="$(true)" \' \
    canon "cr-filter-k{" "a filtered canonical run accepted"
  CS_ONLY=cr-exempt-code mut_run M24 merge-review-shards.sh '    cg_ro_="$(bash "$RO" paths' '    cg_ro_="$(true' canon "cr-exempt-code{" \
    "the record-only exemption accepted whatever the diff"
  CS_ONLY=crm-legacy mut_run M25 merge-review-shards.sh '  if [ "$cr_held_" = 0 ]; then' '  if false; then' canon_merge "crm-legacy{" \
    "the merge's installed-qa.md LEGACY gate dropped"
  CS_ONLY=cr-nr-norun mut_run M26 merge-review-shards.sh '  [ "$WORST" = PASS ] || return 0' '  :' canon "cr-nr-norun{" \
    "a NEEDS_REWORK with no canonical run refused"
  CS_ONLY=crm-norun mut_run M27 merge-review-shards.sh '    canon_gate "$(awk' '    : "$(awk' canon_merge "crm-norun{" \
    "the merge's canonical-run call removed"
  CS_ONLY=cr-exempt-narrow mut_run M28 merge-review-shards.sh '      cg_sb_="$(bash "$RO" story-base' '      cg_sb_="$(true' canon "cr-exempt-narrow{" \
    "the serial exemption decided over a seat-narrowed range"
  CS_ONLY=cr-path-conv mut_run M29 merge-review-shards.sh '      canon_gate "$SERIAL" serial "$sr_repo_" "$R_BASE" "$R_FROZEN" "$sr_conv_"' '      canon_gate "$SERIAL" serial "$sr_repo_" "$R_BASE" "$R_FROZEN" ""' \
    canon "cr-path-conv{" "the consumer's declared canonical path refused"
  CS_ONLY=cr-norun-na mut_run M30 merge-review-shards.sh '  if ! bash "$RO" run-shape "$cg_run_" ${cg_c_:+"$cg_c_"}; then' '  if bash "$RO" none-reason "$cg_run_" 2>/dev/null; [ $? -ne 2 ]; then' \
    canon "cr-norun-na{" "a no-run claim spelled other than none read as a run"
  CS_ONLY=cr-exempt-evil mut_run M31 record-only-diff.sh '            *.py|*.sh|*.toml|*.cfg|conftest.py|pytest.ini) first="$p" ;;' '            NEVER-A-SUFFIX) first="$p" ;;' \
    canon "cr-exempt-evil{" "a collectable module under a record directory classed record-only"
  CS_ONLY=cr-serial-legacy mut_run M32 merge-review-shards.sh '    if grep -qF -- "$CANON_SENTINEL" "$ROLE_MD"; then' '    if true; then' canon "cr-serial-legacy{" \
    "the --check-serial LEGACY branch forced off"
  CS_ONLY=crm-disk-legacy mut_run M33 merge-review-shards.sh '  if [ -z "$cr_inst_" ]; then' '  if false; then' canon_merge "crm-disk-legacy{" \
    "the merge's on-disk qa.md read dropped"
  # BL-769 fold, all in record-only-diff.sh's RUN-FILTER and RUN-SHAPE. M34 the test-file suffixes
  # dropped, so a vitest file argument reads as a path. M35 go's -run dropped. M36 --lf dropped. M37
  # the `--` hand-off dropped. M38 the superset clause dropped, so a root containing the declared one
  # refuses. M39 the none no longer read before the run shape.
  CS_ONLY=cr-filter-suffix mut_run M34 record-only-diff.sh '          *::*|*.py|*.test.*|*.spec.*|*_test.go)' '          *::*|*.py)' \
    canon "cr-filter-suffix{" "a test-file argument to a non-pytest runner accepted as a path"
  CS_ONLY=cr-filter-gorun mut_run M35 record-only-diff.sh '|--testNamePattern=*|-run|-run=*)' '|--testNamePattern=*)' \
    canon "cr-filter-gorun{" "go test -run accepted"
  CS_ONLY=cr-filter-lf mut_run M36 record-only-diff.sh '          --lf|--last-failed) printf' '          --NEVER-lf) printf' \
    canon "cr-filter-lf{" "a last-failed re-run accepted"
  CS_ONLY=cr-filter-dd mut_run M37 record-only-diff.sh '          [ "$w" = -- ] && dd=1' '          :' \
    canon "cr-filter-dd{" "a path handed to the runner after -- accepted"
  CS_ONLY=cr-path-super mut_run M38 record-only-diff.sh ' || substr($2, 1, length(v) + 1) == v "/")' ')' \
    canon "cr-path-super{" "a path root containing the declared one refused"
  CS_ONLY=cr-norun-nonebt mut_run M39 record-only-diff.sh '    bash "$0" none-reason "$2" >/dev/null 2>&1; [ $? -eq 2 ] || exit 1' '    :' \
    canon "cr-norun-nonebt{" "a none carrying a runner span read as a run"
  # M40 the conventions' declared canonical command no longer read as a runner, so `tox -e all` is a no-run claim.
  CS_ONLY=cr-conv-runner mut_run M40 record-only-diff.sh '        rs_rn="$rs_rn|$(printf' '        : "$(printf' \
    canon "cr-conv-runner{" "a runner the conventions declare canonical read as a no-run claim"
  # BL-790. M41 the advisor absence refusal deleted, so a sentinel-era shard with no line merges. M42 the
  # era check deleted, so the absence is refused in the legacy world too.
  CS_ONLY=ad-q-present-absent mut_run M41 merge-review-shards.sh "  else refuse \"\$1 carries no column-0 'advisor:' line" "  else : \"\$1 carries no column-0 'advisor:' line" \
    adv_qa "ad-q-present-absent{" "the advisor absence refusal deleted"
  CS_ONLY=ad-q-legacy-absent mut_run M42 merge-review-shards.sh '  if [ "$ADV_AT" = legacy ]; then' '  if false; then' \
    adv_qa "ad-q-legacy-absent{" "the advisor era check deleted, so a legacy shard's absence is refused"
  # BL-808. M43 the flag parsed but the exclusion not applied. M44 the captures dropped from the FILE
  # SET as well as the count, so the flagged map differs from the merge's flagless re-run -- killed
  # through the merge's own map-cmp refusal. M45 the list's LENGTH subtracted, not its intersection.
  # M46 the one-counted-file SERIAL rule (C8) removed.
  CS_ONLY=xc-flip mut_run M43 partition-review-diff.sh '  NF_REV=$((NF_REV - XC))' '  :' xc_flip "xc-flip{" \
    "the --exclude-captures list parsed but not subtracted from the count"
  CS_ONLY=xc-merge mut_run M44 partition-review-diff.sh '  NF_REV=$((NF_REV - XC))' \
    '  NF_REV=$((NF_REV - XC)); awk -F'"'"'\t'"'"' '"'"'FNR == NR { sub(/\r$/, ""); L[$0] = 1; next } !($2 in L)'"'"' "$XCAP" "$T/files" > "$T/files.x" && mv "$T/files.x" "$T/files"' \
    xc_merge "differs from the map it records" "the cited captures dropped from the file set, not only from the count"
  CS_ONLY=xc-count mut_run M45 partition-review-diff.sh '  NF_REV=$((NF_REV - XC))' '  XC="$(grep -c . "$XCAP")"; NF_REV=$((NF_REV - XC))' \
    xc_count "xc-count{" "the list length subtracted instead of its intersection with the counted files"
  CS_ONLY=xc-one mut_run M46 partition-review-diff.sh '  if [ "$NF_REV" -le 1 ]; then' '  if false; then' xc_one "xc-one{" \
    "the one-counted-file SERIAL rule removed"
  # BL-811. m-k2only restores the K=2-only rule (a lone cross.md refused wherever the table has more
  # than one row), so the lone-cross cell goes red on its own refusal text. m-nomix drops the mixed
  # refusal, so cross.md beside cross-1..3 is no longer refused as a mix.
  CS_ONLY=x-lone-k8 mut_run m-k2only merge-review-shards.sh 'if [ "$x_plain" -eq 1 ]; then cross_shape lone; fi' \
    '[ "$x_plain" -eq 1 ] && [ "$G" -gt 1 ] && refuse "$SDIR holds cross.md, but the part map has $K parts, whose cross groups are $XTABLE_KEYS; a single cross shard is owed only at K=2"; if [ "$x_plain" -eq 1 ]; then cross_shape lone; fi' \
    x_lone "owed only at K=2" "the K=2-only lone-cross rule restored"
  CS_ONLY=x-mix mut_run m-nomix merge-review-shards.sh '[ "$x_plain" -eq 1 ] && [ "$x_num" -eq 1 ] \' 'false \' \
    x_mix "x-mix{" "the mixed cross.md + cross-<g>.md refusal dropped"
  # The matrix, or the twins. A plain run scores no matrix cell and runs at least one twin per mutant; a
  # --matrix run scores the matrix and runs no twin. Either way the count below is the mode's own.
  _mx_n="$(grep -c . "$MX_ROWS")" || _mx_n=0
  if [ "$RSM_MATRIX" = 1 ]; then
    : > "$WORK/mx-log"; matrix_score
    reuse_proof
    if [ "$MX_CELLS" -gt "$_mx_n" ] && [ "$TWIN_N" = 0 ] && [ "$_mx_n" = 48 ]; then
      ok "MX1: --matrix scored $MX_CELLS mutant x cell pairs over $_mx_n mutants and ran no twin"
    else bad "MX1: --matrix scored $MX_CELLS pairs over $_mx_n recorded mutants, twins run $TWIN_N"; fi
  else
    if [ "$MX_CELLS" = 0 ] && [ "$_mx_n" = 0 ] && [ "$TWIN_N" -ge 48 ]; then
      ok "MX1: a plain run scored no matrix cell and ran $TWIN_N twin cells, at least one per mutant, each passing over its mutant copy"
    else bad "MX1: a plain run scored $MX_CELLS matrix cells ($_mx_n recorded mutants) and ran $TWIN_N twins, want 0, 0 and at least 48"; fi
  fi
  # VBCTL: every mutant's own cell passed over the unmutated derived copy first (mut_run), one per mutant.
  if [ "$VB_CTL_N" = 48 ]; then ok "VBCTL: CONTROL -- each of M1-M46, m-k2only and m-nomix's selected cells passed unmutated ($VB_CTL_N of 48): by the same run's passing arm over the byte-identical source set, else over the unmutated copy of the derived sibling set every mutant is built from"
  else bad "VBCTL: FIXTURE ERROR -- $VB_CTL_N of 48 mutants' cells passed over the unmutated copy, so the other verdicts are not evidence"; fi
else
  echo "  (BL-737 mutants M1-M6, and BL-740's CONTROL and M7-M11, not run: $SRCDIR is the consumer layout, whose scripts the consumer cannot edit)"
fi

# THE PROGRAMS ARE NOTHING IF THE LEAD IS NEVER TOLD TO RUN THEM. Every arm above drives the two
# programs directly, so a release that built them and never rewired the step file passes all of
# them and every consumer keeps dispatching one reviewer. Keyed on the EMISSION SITE: the
# paragraph implementation.md opens with `**Gate-1 dispatch:`, read outside fences, must name
# both programs -- a whole-file grep is satisfied by a mention anywhere, including a fence.
# The same for the role clause: the `## As a Shard` section must name the three grammar tokens
# the merge refuses without, or a shard written as the role file says is refused at the join.
step_para() { # <file> -> the Gate-1 dispatch paragraph, fenced lines dropped
  awk '/^```/ { f = !f; next } f { next }
       /^\*\*Gate-1 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { exit } p { print }' "$1"
}
p_step() { # <file>
  local t; t="$(step_para "$1")"
  [ -n "$t" ] && grep -qF 'partition-review-diff.sh' <<<"$t" && grep -qF 'merge-review-shards.sh' <<<"$t"
}
role_sect() { awk '/^## As a Shard/ { p = 1; next } p && /^## / { exit } p { print }' "$1"; }
p_role() { # <file>
  local t; t="$(role_sect "$1")"
  [ -n "$t" ] && grep -qF 'shard-verdict:' <<<"$t" && grep -qF 'reviewed-sha:' <<<"$t" && grep -qF 'parts:' <<<"$t"
}
# Self-probes, both directions, on copies: the names removed from the paragraph, and the names
# present only inside a fence, must each fail; the shipped file must pass.
sed -e '/^\*\*Gate-1 dispatch:/,/^[[:space:]]*$/s/merge-review-shards\.sh/MERGE-GONE/g' "$STEP_MD" > "$WORK/step-strip.md"
{ printf '%s\n' '**Gate-1 dispatch: decoy.** one reviewer.' '' '```' 'partition-review-diff.sh merge-review-shards.sh' '```'; } > "$WORK/step-fence.md"
sed -e '/^## As a Shard/,/^## /s/reviewed-sha:/REVIEWED-GONE/g' "$ROLE_MD" > "$WORK/role-strip.md"
if cmp -s "$STEP_MD" "$WORK/step-strip.md" || cmp -s "$ROLE_MD" "$WORK/role-strip.md"; then
  bad "S0: FIXTURE STALE -- a structural probe's sed matched nothing, so the probe would score the shipped text"
elif p_step "$WORK/step-strip.md" || p_step "$WORK/step-fence.md" || p_role "$WORK/role-strip.md"; then
  bad "S0: FIXTURE BROKEN -- a structural predicate passed a copy with a program or token removed, or present only in a fence"
else
  ok "S0: the structural predicates refuse a paragraph missing the merge, names only inside a fence, and a role clause missing reviewed-sha:"
fi
# THE STEP SAYS SHARDING IS ON BY DEFAULT, in the paragraph the lead acts on. A reverted step
# tells every consumer lead the old contract while the script shards anyway. Read as one joined
# line, so a wrapped sentence still matches. Two refusals inside THIS paragraph only:
#   - the word "opt-in";
#   - opt-in BEHAVIOUR without the word: a clause gating the partition on the variable being set,
#     "only when|if ... is set" or "unless ... is set", up to the clause's end.
# LIMIT, STATED: this arm pins WORDING, not behaviour. A paraphrase of the opt-in contract outside
# both shapes ("run the partition after configuring the variable") passes it. The behaviour is
# held by P2/P2b, which run the shipping script with the variable unset.
p_step_dflt() { # <file>
  local t; t="$(step_para "$1" | tr '\n' ' ' | tr -s ' ')"
  [ -n "$t" ] && ! grep -qi 'opt-in' <<<"$t" && grep -qF 'Review sharding is on by default' <<<"$t" \
    && grep -qF 'setting it to `0` turns review sharding off' <<<"$t" \
    && ! grep -qiE 'only (when|if) [^.;]*is set|unless [^.;]*is set' <<<"$t"
}
# Offender: the paragraph's default-on sentence reverted to the opt-in text.
awk '/^\*\*Gate-1 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { p = 0 }
     p && /^Review sharding is on by default/ { print "Review sharding is opt-in: the program answers `SERIAL:` (exit 3) unless"; next }
     { print }' "$STEP_MD" > "$WORK/step-optin.md"
# Offender: default-on kept, "opt-in" added inside the paragraph. Near-miss: "opt-in" in a
# paragraph of its own after the dispatch paragraph, which the arm must NOT read as a finding.
awk '/^\*\*Gate-1 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { if (!done) print "Older releases made review sharding opt-in."; done = 1; p = 0 } { print }' \
  "$STEP_MD" > "$WORK/step-optin-in.md"
awk '/^\*\*Gate-1 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { if (!done) { print; print "Older releases made review sharding opt-in." }; done = 1; p = 0 } { print }' \
  "$STEP_MD" > "$WORK/step-optin-out.md"
# Offenders without the word (W4): "only when ... is set" and "unless ... is set" added to the
# paragraph. Near-miss: the same "only when ... is set" sentence in the NEXT paragraph.
awk '/^\*\*Gate-1 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { if (!done) print "Run the partition only when `AI_DLC_REVIEW_SHARD_MIN_FILES` is set; otherwise dispatch one serial reviewer."; done = 1; p = 0 } { print }' \
  "$STEP_MD" > "$WORK/step-onlywhen.md"
awk '/^\*\*Gate-1 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { if (!done) print "Dispatch one serial reviewer unless the variable is set."; done = 1; p = 0 } { print }' \
  "$STEP_MD" > "$WORK/step-unless.md"
awk '/^\*\*Gate-1 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { if (!done) { print; print "Older releases ran the partition only when the variable is set." }; done = 1; p = 0 } { print }' \
  "$STEP_MD" > "$WORK/step-onlywhen-out.md"
_s6s=0
for _f in step-optin.md step-optin-in.md step-optin-out.md step-onlywhen.md step-unless.md step-onlywhen-out.md; do
  cmp -s "$STEP_MD" "$WORK/$_f" && _s6s=1
done
if [ "$_s6s" -ne 0 ]; then
  bad "S6-pre: FIXTURE STALE -- a default-on probe's edit matched nothing, so the probe would score the shipped text"
elif p_step_dflt "$WORK/step-optin.md" || p_step_dflt "$WORK/step-optin-in.md" \
     || p_step_dflt "$WORK/step-onlywhen.md" || p_step_dflt "$WORK/step-unless.md"; then
  bad "S6-pre: FIXTURE BROKEN -- the default-on predicate passed a paragraph reverted to opt-in, carrying 'opt-in', or gating the partition on the variable being set"
elif ! p_step_dflt "$WORK/step-optin-out.md" || ! p_step_dflt "$WORK/step-onlywhen-out.md"; then
  bad "S6-pre: FIXTURE BROKEN -- the default-on predicate refused 'opt-in' or 'only when ... is set' OUTSIDE the dispatch paragraph (near-misses)"
else
  ok "S6-pre: the default-on predicate refuses the reverted sentence, 'opt-in', 'only when ... is set' and 'unless ... is set' inside the paragraph, and accepts 'opt-in' and 'only when ... is set' in the next paragraph"
fi
if p_step_dflt "$STEP_MD"; then
  ok "S6: implementation.md's Gate-1 dispatch paragraph says review sharding is on by default and that \`0\` turns it off, and neither says opt-in nor gates the partition on the variable being set"
else
  bad "S6: implementation.md's Gate-1 dispatch paragraph does not state default-on sharding, or says opt-in, or gates the partition on the variable being set"
fi
if p_step "$STEP_MD"; then
  ok "S1: implementation.md's Gate-1 dispatch paragraph names partition-review-diff.sh and merge-review-shards.sh outside a fence"
else
  bad "S1: implementation.md's Gate-1 dispatch paragraph does not name both programs outside a fence -- the lead is never told to shard"
fi
if p_role "$ROLE_MD"; then
  ok "S2: code-reviewer.md's '## As a Shard' clause names shard-verdict:, reviewed-sha: and parts:, the grammar the merge refuses without"
else
  bad "S2: code-reviewer.md's '## As a Shard' clause does not carry the merge's shard grammar -- a shard written to it is refused at the join"
fi

# GATE 2 AT THE EMISSION SITE. The paragraph implementation.md opens with `**Gate-2 dispatch:`,
# fenced lines dropped, must name the partition, the merge and `--gate qa`; qa.md's `## As a Shard`
# must name the three grammar tokens plus `## Acceptance Criteria`, the one section the merge
# requires of the cross shard. And neither file may carry the serial-gate-2 sentences anywhere:
# `Gate 2 is dispatched serially` (the consumer's receipt is a substring match on qa.md) and
# `it has no shard merge`.
step2_para() { awk '/^```/ { f = !f; next } f { next }
       /^\*\*Gate-2 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { exit } p { print }' "$1"; }
p_step2() { local t; t="$(step2_para "$1")"
  [ -n "$t" ] && grep -qF 'partition-review-diff.sh' <<<"$t" && grep -qF 'merge-review-shards.sh' <<<"$t" \
    && grep -qF -- '--gate qa' <<<"$t"; }
p_qrole() { local t; t="$(role_sect "$1")"
  [ -n "$t" ] && grep -qF 'shard-verdict:' <<<"$t" && grep -qF 'reviewed-sha:' <<<"$t" && grep -qF 'parts:' <<<"$t" \
    && grep -qF '## Acceptance Criteria' <<<"$t"; }
# Read WHITESPACE-NORMALISED: the base text wrapped "Gate 2" / "is dispatched serially" across
# two lines, so a per-line match was already true of the tree it was written to refuse.
p_noserial() { local t; t="$(tr -s '[:space:]' ' ' < "$1")"
  ! grep -qiF 'Gate 2 is dispatched serially' <<<"$t" && ! grep -qiF 'it has no shard merge' <<<"$t"; }
sed -e '/^\*\*Gate-2 dispatch:/,/^[[:space:]]*$/s/--gate qa/--gate QA-GONE/g' "$STEP_MD" > "$WORK/step2-strip.md"
{ printf '%s\n' '**Gate-2 dispatch: decoy.** one QA.' '' '```' 'partition-review-diff.sh merge-review-shards.sh --gate qa' '```'; } > "$WORK/step2-fence.md"
sed -e '/^## As a Shard/,/^## /s/## Acceptance Criteria/## AC-GONE/g' "$QA_MD" > "$WORK/qrole-strip.md"
awk '{ print } /^## Context Loading$/ && !d { print ""; print "Gate 2 is dispatched serially: your brief carries `shard: 1/1 <story-index>`."; d = 1 }' "$QA_MD" > "$WORK/qa-serial.md"
awk '{ print } /^\*\*DAR-fold preflight before gate-2 dispatch\.\*\*/ && !d { print "Gate 2 is dispatched `shard: 1/1 <story-index>`; it has no shard merge."; d = 1 }' "$STEP_MD" > "$WORK/step-nomerge.md"
# The serial sentences WRAPPED, each in the shape base shipped: implementation.md's qa bullet broke
# after "Gate 2" (base lines 127-128), and the no-merge clause wrapped after "it has no". A
# per-line match misses all three; that miss is asserted below so the kill is the normalisation's.
awk '/^- \*\*qa\*\* from `qa\.md`\./ && !d { print "- **qa** from `qa.md`. Validates acceptance criteria, runs tests. Gate 2"; print "  is dispatched serially, `shard: 1/1 <story-index>`."; d = 1; next } { print }' \
  "$STEP_MD" > "$WORK/step-serial-wrap.md"
awk '{ print } /^\*\*DAR-fold preflight before gate-2 dispatch\.\*\*/ && !d { print "Gate 2 is dispatched `shard: 1/1 <story-index>`; it has no"; print "shard merge."; d = 1 }' "$STEP_MD" > "$WORK/step-nomerge-wrap.md"
awk '{ print } /^## Context Loading$/ && !d { print ""; print "Gate 2"; print "is dispatched serially: your brief carries `shard: 1/1 <story-index>`."; d = 1 }' "$QA_MD" > "$WORK/qa-serial-wrap.md"
# The serial sentence in LOWER CASE, which an exact-case match misses; that miss is asserted below.
awk '{ print } /^## Context Loading$/ && !d { print ""; print "gate 2 is dispatched serially: your brief carries `shard: 1/1 <story-index>`."; d = 1 }' "$QA_MD" > "$WORK/qa-serial-lower.md"
_s7w=0
grep -qF 'Gate 2 is dispatched serially' "$WORK/qa-serial-lower.md" && _s7w=1
for _f in step-serial-wrap step-nomerge-wrap qa-serial-wrap; do
  grep -qF 'Gate 2 is dispatched serially' "$WORK/$_f.md" && _s7w=1
  grep -qF 'it has no shard merge' "$WORK/$_f.md" && _s7w=1
done
if cmp -s "$STEP_MD" "$WORK/step2-strip.md" || cmp -s "$QA_MD" "$WORK/qrole-strip.md" \
   || cmp -s "$QA_MD" "$WORK/qa-serial.md" || cmp -s "$STEP_MD" "$WORK/step-nomerge.md" \
   || cmp -s "$STEP_MD" "$WORK/step-serial-wrap.md" || cmp -s "$STEP_MD" "$WORK/step-nomerge-wrap.md" \
   || cmp -s "$QA_MD" "$WORK/qa-serial-wrap.md" || cmp -s "$QA_MD" "$WORK/qa-serial-lower.md"; then
  bad "S7-pre: FIXTURE STALE -- a gate-2 structural probe's edit matched nothing, so the probe would score the shipped text"
elif [ "$_s7w" -ne 0 ]; then
  bad "S7-pre: FIXTURE BROKEN -- a wrapped or lowercase serial-sentence copy matches exact-case on one line, so it cannot tell a per-line or case-sensitive predicate from the shipped one"
elif p_step2 "$WORK/step2-strip.md" || p_step2 "$WORK/step2-fence.md" || p_qrole "$WORK/qrole-strip.md" \
     || p_noserial "$WORK/qa-serial.md" || p_noserial "$WORK/step-nomerge.md" \
     || p_noserial "$WORK/step-serial-wrap.md" || p_noserial "$WORK/step-nomerge-wrap.md" \
     || p_noserial "$WORK/qa-serial-wrap.md" || p_noserial "$WORK/qa-serial-lower.md"; then
  bad "S7-pre: FIXTURE BROKEN -- a gate-2 predicate passed a copy missing --gate qa, naming it only in a fence, a role clause missing '## Acceptance Criteria', or a re-inserted serial sentence, one-line, wrapped or lowercase"
else
  ok "S7-pre: the gate-2 predicates refuse a paragraph missing --gate qa, names only inside a fence, a qa clause missing '## Acceptance Criteria', and either serial sentence re-inserted on one line, WRAPPED as base wrapped it (which a per-line match misses), or in lower case (which an exact-case match misses)"
fi
if p_step2 "$STEP_MD"; then
  ok "S7: implementation.md's Gate-2 dispatch paragraph names partition-review-diff.sh, merge-review-shards.sh and --gate qa outside a fence"
else
  bad "S7: implementation.md's Gate-2 dispatch paragraph does not name the partition, the merge and --gate qa outside a fence -- the lead is never told to shard gate 2"
fi
if p_qrole "$QA_MD"; then
  ok "S8: qa.md's '## As a Shard' clause names shard-verdict:, reviewed-sha:, parts: and '## Acceptance Criteria'"
else
  bad "S8: qa.md's '## As a Shard' clause does not carry the merge's QA shard grammar"
fi
_ser=""
p_noserial "$STEP_MD" || _ser="$_ser implementation.md"
p_noserial "$QA_MD" || _ser="$_ser qa.md"
if [ -z "$_ser" ]; then
  ok "S9: neither 'Gate 2 is dispatched serially' nor 'it has no shard merge' appears anywhere in implementation.md or qa.md"
else
  bad "S9: [${_ser# }] still says gate 2 is serial or has no shard merge"
fi

# WHO MAKES THE CLOSING WRITES, AND WHEN. The `done` transition, `deferred_acs` (taken from QA's
# verdict, so unknowable before gate 2), the upstream close-out and the closing commit are made by
# ONE `code-reviewer` the lead dispatches AFTER GATE 3, for every story, serial or sharded -- a
# dispatched agent, so the gate-remediation guard's agent_id arm allows its story-file edit while
# a verdict is FAIL. No gate-1 reviewer makes them, and the lead does not. The gate-1 REVIEW
# commit, which persists the review file Check 1 reads, is a different commit and is unchanged.
#
# PINS, each read as one joined line with `**` dropped so a wrapped or emphasised sentence still
# matches: the step's task item 4 (dispatch, timing, the four duties, the catch-up for a story
# already past gate 3), its Gate-1 paragraph, its section 7 precondition; the role's Ownership
# pointer, Responsibilities bullet, As a Shard sentence and As the Closing Writer brief.
#
# AND A REFUSAL OVER EACH WHOLE FILE, As the Closing Writer included. The file is split into
# clauses at `. ` and `; `. A clause naming a closing write -- `done` transition, `status: done`,
# `deferred_acs`, the closing commit, or the review commit beside `done`/`deferred_acs` -- must have the closing
# writer as its subject, or negate the WRITE VERB itself (`do/does NOT make|perform`). Any other
# " not " acquits nothing. Clauses that only describe the field or the lifecycle (a value of
# `deferred_acs`, a `done` story, Dev's earlier write) are acquitted by enumerated shapes below.
# FALSE-POSITIVE SET, measured on the shipped files before this arm was pinned: every clause the
# grammar flagged was reworded to name its subject, so the shipped set is 0. The enumerated
# acquittals are the narrowing story; widening one widens what a wrong build can say.
joined() { tr '\n' ' ' | tr -s ' ' | sed -e 's/\*\*//g'; }
close_item() { awk '/^4\. Closing writer/ { p = 1 } p && (/^[[:space:]]*$/ || /^### /) { exit } p { print }' "$1"; }
sect7() { awk '/^### 7\. All Gates Passed/ { p = 1; next } p && /^### / { exit } p { print }' "$1"; }
role_named() { # <file> <section heading text> -> that section's body
  awk -v h="## $2" '$0 == h { p = 1; next } p && /^## / { exit } p { print }' "$1"; }
role_bullet() { # <file> <section> <bullet prefix> -> that bullet, continuation lines included
  role_named "$1" "$2" | awk -v b="$3" 'index($0, b) == 1 { p = 1; print; next } p && /^- / { exit } p { print }'; }
p_own_step() { local t g s
  t="$(close_item "$1" | joined)"; g="$(step_para "$1" | joined)"; s="$(sect7 "$1" | joined)"
  grep -qF 'Once gate 3 passes, the lead dispatches one `code-reviewer` as the closing writer, `shard: 1/1 <story-index>`, for every story, serial or sharded.' <<<"$t" \
    && grep -qF 'the closing writer makes exactly these writes and nothing else' <<<"$t" \
    && grep -qF 'deferred_acs` in both sprint-status views taken from the merged QA file'"'"'s `## Deferred ACs`, or the deferred record in the serial file, the upstream close-out section 5 requires, and the closing commit' <<<"$t" \
    && grep -qF 'The lead does NOT make these writes.' <<<"$t" \
    && grep -qF 'The closing writer is also owed to a story already past gate 3 without its closing writes' <<<"$t" \
    && grep -qF 'the lead dispatches it at the lead'"'"'s next turn' <<<"$t" \
    && grep -qF 'A gate-1 reviewer, serial or shard, does NOT make the `done` transition, `deferred_acs` or the closing commit; the closing writer does, after gate 3.' <<<"$g" \
    && grep -qF 'Persisting the gate-1 review file is unchanged' <<<"$g" \
    && grep -qF 'the closing writer has landed every story'"'"'s closing commit, leaving every story `done` with a `deferred_acs` field in both sprint-status views' <<<"$s" \
    && grep -qF 'The closing writer has not run for a story past gate 3 that is still `review`, or `done` with no `deferred_acs` field in a view: dispatch the closing writer now (section 3, item 4)' <<<"$s"; }
p_own_role() { local o r s c
  o="$(role_named "$1" Ownership | joined)"; s="$(role_sect "$1" | joined)"; c="$(role_named "$1" 'As the Closing Writer' | joined)"
  r="$(role_bullet "$1" Responsibilities '- Dispatched as the closing writer' | joined)"
  grep -qF 'The closing writes belong to the closing writer, and only to it.' <<<"$o" \
    && grep -qF 'A gate-1 reviewer — serial `shard: 1/1`, a part shard or the cross shard — does NOT make any of them. After gate 3 passes, the lead dispatches one `code-reviewer` as the closing writer (see "As the Closing Writer")' <<<"$o" \
    && grep -qF 'in the review commit that Check 1 of `gate-validation.md` reads. That is unchanged, and the review commit carries no status write.' <<<"$o" \
    && grep -qF 'the closing writer updates the story file `Status:` header and `sprint-status.yaml` to `done`, writes the story'"'"'s `deferred_acs` beside `status: done` in both views, and makes the upstream close-out, all in the closing commit. As a gate-1 reviewer you do NOT make these writes.' <<<"$r" \
    && grep -qF 'you do NOT make the `done` transition, `deferred_acs` in both sprint-status views, or the closing commit; the closing writer does, after gate 3.' <<<"$s" \
    && grep -qF 'the lead dispatches you after gate 3 passes, for every story, serial or sharded' <<<"$c" \
    && grep -qF 'the closing writer makes exactly these writes and nothing else' <<<"$c" \
    && grep -qF 'the upstream close-out `implementation.md` section 5 requires' <<<"$c" \
    && grep -qF 'and the closing commit carrying all of them.' <<<"$c"; }
# One clause per line. Fenced lines and headings are dropped; `e.g.`/`i.e.` cannot split.
clauses() { awk '/^```/ { f = !f; next } f || /^#/ { next } { print }' "$1" | joined \
  | sed -e 's/e\.g\./eg/g' -e 's/i\.e\./ie/g' | awk '{ gsub(/\. /, ".\n"); gsub(/; /, ";\n"); print }'; }
# 0 when NO clause gives a closing write to anyone but the closing writer. Prints offenders on fd 3.
p_write_refuse() { # <file>
  clauses "$1" | awk '
    { s = tolower($0) }
    { w = (s ~ /`done` transition/ || s ~ /status: done/ || s ~ /deferred_acs/ || s ~ /closing commit/ \
           || (s ~ /review commit/ && (s ~ /`done`/ || s ~ /deferred_acs/))) }
    !w { next }
    s ~ /the closing writer/ { next }                                   # its subject is the writer
    s ~ /(do|does) not (make|perform)/ { next }                         # the WRITE VERB negated
    # Field and lifecycle descriptions, enumerated (the narrowing story):
    s ~ /^`?deferred_acs`? is not one single-line/ { next }
    s ~ /if the story has no deferred ac/ { next }
    s ~ /never a block list/ { next }
    s ~ /deploy-validate §4b clears/ { next }
    s ~ /`?deferred_acs: \[ac5, ac6\]`?\.?$/ { next }
    s ~ /^dev owns the earlier/ { next }
    { print > "/dev/fd/3"; bad = 1 } END { exit bad }'; }
# The header's THRESHOLD paragraph states the default, derived from the assignment, and the off
# spelling, and no longer calls sharding opt-in.
hdr_para() { awk '/^# THRESHOLD/ { p = 1; print; next } p && /^# [^ ]/ { exit } p { print }' "$1"; }
p_hdr() { local t; t="$(hdr_para "$1" | joined)"
  [ -n "$t" ] && ! grep -qi 'opt-in' <<<"$t" && grep -qF "the built-in default $DFLT" <<<"$t" && grep -qF "$KEY=0" <<<"$t"; }
# OFFENDERS, one per pinned or refused property, each a copy guarded by cmp -s.
#   step-early     item 4's dispatch moved before gate 3            (the tip adversary's W1, first round)
#   step-lead      the Gate-1 paragraph hands the writes to the lead
#   step-elsewhere item 4 de-timed, the pinned sentence added under another heading
#   step-noclose   the upstream close-out dropped from item 4's brief          (D1)
#   step-nocatch   the catch-up for a story already past gate 3 dropped       (D3)
#   step-s7        a section-7 clause where the LEAD makes the writes          (W3, step half)
#   role-nopointer the Ownership pointer bullet deleted                         (W2, first round)
#   role-resp      the Responsibilities bullet reverted to the pre-change text (W2)
#   role-incw      a clause INSIDE As the Closing Writer giving the serial gate-1 reviewer the writes (W1)
#   role-notlead   a clause giving the cross shard the writes, carrying an unrelated " not " (W3)
# NEAR-MISSES, which must pass:
#   role-negated   the role-notlead clause with its WRITE VERB negated
#   step-negated   a section-7 clause where the lead does NOT make the writes
sed -e 's/Once gate 3 passes, the lead/Once gate 2 passes, the lead/' "$STEP_MD" > "$WORK/own-step-early.md"
sed -e '/^\*\*Gate-1 dispatch:/,/^[[:space:]]*$/s/the closing writer does, after gate 3\./the lead performs them after the merge./' "$STEP_MD" > "$WORK/own-step-lead.md"
sed -e 's/Once gate 3 passes, the lead/Once gate 2 passes, the lead/' "$STEP_MD" \
  | awk '/^### 4\. Self-Validate/ { print "Once gate 3 passes, the lead dispatches one `code-reviewer` as the closing writer, `shard: 1/1 <story-index>`, for every story, serial or sharded."; print "" } { print }' \
  > "$WORK/own-step-elsewhere.md"
sed -e 's/^   upstream close-out section 5 requires, and the closing commit carrying$/   and the closing commit carrying/' "$STEP_MD" > "$WORK/own-step-noclose.md"
# The pre-change sentence, line for line: "taken from QA's verdict, the upstream close-out ...".
awk '/^   `deferred_acs` in both sprint-status views taken from the merged QA file.s$/ { print "   `deferred_acs` in both sprint-status views taken from QA'"'"'s verdict, the"; skip = 1; next }
     skip { skip = 0; next } { print }' "$STEP_MD" > "$WORK/own-step-qaverdict.md"
sed -e 's/The closing writer is also owed to a story/A story is also owed/' "$STEP_MD" > "$WORK/own-step-nocatch.md"
awk '/^### 7\. All Gates Passed/ { print; print ""; print "Before routing, the lead writes `status: done` and `deferred_acs` for every story itself and makes the closing commit."; next } { print }' \
  "$STEP_MD" > "$WORK/own-step-s7.md"
awk '/^### 7\. All Gates Passed/ { print; print ""; print "Before routing, the lead does NOT make the `done` transition or the closing commit for any story."; next } { print }' \
  "$STEP_MD" > "$WORK/own-step-negated.md"
awk '/^- \*\*The closing writes belong to the closing writer/ { skip = 1; next }
     skip && /^- / { skip = 0 } !skip { print }' "$ROLE_MD" > "$WORK/own-role-nopointer.md"
awk '/^- Dispatched as the closing writer after gate 3 passes/ { skip = 1
       print "- After approving the final gate for a story, update `sprint-status.yaml`"
       print "  and the story file `Status:` header to `done` in the review commit, with"
       print "  the story'"'"'s `deferred_acs` written beside `status: done` in both views."; next }
     skip && (/^- / || /^$/) { skip = 0 } !skip { print }' "$ROLE_MD" > "$WORK/own-role-resp.md"
awk '{ print } /^the story file and to `carry-over-backlog\.md`\.$/ && !d { print "A gate-1 serial reviewer that approves makes the `done` transition, `deferred_acs` and the closing commit itself at gate 1; dispatch a closing writer only for a sharded review."; d = 1 }' \
  "$ROLE_MD" > "$WORK/own-role-incw.md"
awk '/^## Constraints$/ { print "As the cross shard you make the closing commit and the `done` transition, not the lead."; print "" } { print }' \
  "$ROLE_MD" > "$WORK/own-role-notlead.md"
awk '/^## Constraints$/ { print "As the cross shard you do NOT make the closing commit or the `done` transition."; print "" } { print }' \
  "$ROLE_MD" > "$WORK/own-role-negated.md"
sed -e '/^# THRESHOLD/s/ON BY DEFAULT/OPT-IN/' "$PART" > "$WORK/hdr-optin.sh"
sed -e "/^# THRESHOLD/,/^# THE PART SET/s/the built-in default $DFLT/the built-in default $((DFLT + 1))/" "$PART" > "$WORK/hdr-num.sh"
_stale=0
grep -qF 'Once gate 2 passes, the lead' "$WORK/own-step-elsewhere.md" || { _stale=1; echo "  (item 4 not de-timed in own-step-elsewhere.md)"; }
for _p in "$STEP_MD:own-step-early.md" "$STEP_MD:own-step-lead.md" "$STEP_MD:own-step-elsewhere.md" \
          "$STEP_MD:own-step-noclose.md" "$STEP_MD:own-step-qaverdict.md" "$STEP_MD:own-step-nocatch.md" "$STEP_MD:own-step-s7.md" "$STEP_MD:own-step-negated.md" \
          "$ROLE_MD:own-role-nopointer.md" "$ROLE_MD:own-role-resp.md" "$ROLE_MD:own-role-incw.md" \
          "$ROLE_MD:own-role-notlead.md" "$ROLE_MD:own-role-negated.md" \
          "$PART:hdr-optin.sh" "$PART:hdr-num.sh"; do
  cmp -s "${_p%%:*}" "$WORK/${_p#*:}" && { _stale=1; echo "  (unchanged probe: ${_p#*:})"; }
done
# Each offender must be refused by the arm that OWNS it; the pins and the refusal are scored apart
# so a wrong build that slips one is still named.
_own_fail=""
for _o in own-step-early own-step-lead own-step-elsewhere own-step-noclose own-step-qaverdict own-step-nocatch; do
  p_own_step "$WORK/$_o.md" && _own_fail="$_own_fail $_o"
done
p_write_refuse "$WORK/own-step-s7.md" 3>/dev/null && _own_fail="$_own_fail own-step-s7"
p_own_role "$WORK/own-role-nopointer.md" && _own_fail="$_own_fail own-role-nopointer"
p_own_role "$WORK/own-role-resp.md" && _own_fail="$_own_fail own-role-resp(pin)"
p_write_refuse "$WORK/own-role-resp.md" 3>/dev/null && _own_fail="$_own_fail own-role-resp(refuse)"
p_write_refuse "$WORK/own-role-incw.md" 3>/dev/null && _own_fail="$_own_fail own-role-incw"
p_write_refuse "$WORK/own-role-notlead.md" 3>/dev/null && _own_fail="$_own_fail own-role-notlead"
p_hdr "$WORK/hdr-optin.sh" && _own_fail="$_own_fail hdr-optin"
p_hdr "$WORK/hdr-num.sh" && _own_fail="$_own_fail hdr-num"
_nm_fail=""
{ p_write_refuse "$WORK/own-role-negated.md" 3>/dev/null && p_own_role "$WORK/own-role-negated.md"; } || _nm_fail="$_nm_fail own-role-negated"
{ p_write_refuse "$WORK/own-step-negated.md" 3>/dev/null && p_own_step "$WORK/own-step-negated.md"; } || _nm_fail="$_nm_fail own-step-negated"
if [ "$_stale" -ne 0 ]; then
  bad "S3-pre: FIXTURE STALE -- an ownership or header probe's edit matched nothing, so the probe would score the shipped text"
elif [ -n "$_own_fail" ]; then
  bad "S3-pre: FIXTURE BROKEN -- an ownership or header predicate passed offender(s) [${_own_fail# }]"
elif [ -n "$_nm_fail" ]; then
  bad "S3-pre: FIXTURE BROKEN -- a predicate refused near-miss(es) [${_nm_fail# }], a clause whose write verb is negated"
else
  ok "S3-pre: 13 offenders refused by the arm that owns each (dispatch before gate 3, writes to the lead, dispatch outside item 4, no close-out, deferred_acs taken from 'QA's verdict' rather than the merged file's '## Deferred ACs', no catch-up, a lead-writes clause in section 7, no Ownership pointer, the Responsibilities bullet reverted, a contradiction inside As the Closing Writer, an unrelated 'not', OPT-IN, another number); 2 near-misses with the write verb negated pass"
fi
if p_own_step "$STEP_MD"; then
  ok "S3: implementation.md's item 4 dispatches the closing writer after gate 3 for every story with its four duties and the catch-up, the Gate-1 paragraph gives no gate-1 reviewer the writes and keeps review-file persistence, and section 7 routes only after every closing commit"
else
  bad "S3: implementation.md does not pin the post-gate-3 closing writer at item 4, the Gate-1 paragraph and section 7"
fi
if p_own_role "$ROLE_MD"; then
  ok "S4: code-reviewer.md's Ownership, Responsibilities, As a Shard and As the Closing Writer give the closing writes to the closing writer alone, after gate 3, upstream close-out included, and keep the review commit"
else
  bad "S4: code-reviewer.md does not give the closing writes to the post-gate-3 closing writer at all four sites"
fi
_sref=""
p_write_refuse "$ROLE_MD" 3>/dev/null || _sref="$_sref code-reviewer.md"
p_write_refuse "$STEP_MD" 3>/dev/null || _sref="$_sref implementation.md"
if [ -z "$_sref" ]; then
  ok "S4b: no clause in code-reviewer.md or implementation.md, As the Closing Writer included, gives a closing write to anyone but the closing writer unless its write verb is negated"
else
  bad "S4b: a clause in [${_sref# }] gives a closing write to a subject other than the closing writer"
fi
if p_hdr "$PART"; then
  ok "S5: partition-review-diff.sh's THRESHOLD paragraph states the built-in default $DFLT and $KEY=0, and does not say opt-in"
else
  bad "S5: partition-review-diff.sh's THRESHOLD paragraph still says opt-in, or does not state the default $DFLT and the off spelling"
fi

# A PART SHARD'S WORKTREE HAS NO DEPENDENCIES, AND A PART SHARD DELIVERS A PATH, NOT ROWS. A fresh
# `git worktree add --detach` carries none of the project's gitignored dependencies, so a RED
# replayed there without setup fails for a reason the mutation does not own -- measured on the
# reference consumer: its canonical interpreter is absent (rc 127) until its documented setup
# runs (rc 0). PINS, each read joined with `**` dropped, at the two emission sites: qa.md's
# `## As a Shard` (setup first, GREEN baseline before any mutation, the hand-over to the cross
# shard as a `#### ` finding, and the cross shard owning the handed-over replays), the Gate-2
# dispatch paragraph (the same three duties), and qa.md's "Deliver before idle" bullet (a part
# shard delivers its shard file path and shard-verdict, never per-AC rows).
p_qsetup_role() { local t; t="$(role_sect "$1" | joined)"
  grep -qF 'in it you first run the project'"'"'s canonical dependency setup, the setup the dev'"'"'s QA Handoff Evidence records or else the story'"'"'s documented setup, and confirm the canonical run of the anchor'"'"'s test is GREEN there before any mutation.' <<<"$t" \
    && grep -qF 'An AC whose replay cannot reach a GREEN baseline in your worktree is handed to the cross shard rather than scored: list it under `## Findings` as a `#### ` finding citing `parts: <your ordinal>` that names the AC and the reason.' <<<"$t" \
    && grep -qF 'the RED replays for any AC whose anchor lies in no part'"'"'s files or that a part shard handed over' <<<"$t"; }
p_qsetup_step() { local t; t="$(step2_para "$1" | joined)"
  grep -qF 'a part QA first runs the project'"'"'s canonical dependency setup (the setup the dev'"'"'s QA Handoff Evidence records, or the story'"'"'s documented setup) and confirms the canonical run of the anchor'"'"'s test is GREEN there before any mutation.' <<<"$t" \
    && grep -qF 'An AC whose replay cannot reach a GREEN baseline in the part'"'"'s worktree is handed to the first cross QA, listed under the part shard'"'"'s findings with its reason, rather than scored.' <<<"$t" \
    && grep -qF 'the RED replays a part QA handed over' <<<"$t"; }
p_qdeliver() { local t; t="$(role_bullet "$1" Communication '- **Deliver before idle' | joined)"
  grep -qF 'A part shard delivers its shard file'"'"'s absolute path and its `shard-verdict:` value instead, never per-AC rows, which only the first cross shard writes.' <<<"$t"; }
# OFFENDERS: each obligation dropped at its site; and each moved OUT of its section (into the
# paragraph after it), which a whole-file grep would still accept.
sed -e 's/^it you first run the project.s canonical dependency setup, the setup the dev.s$/it you run the replays directly, the setup the dev'"'"'s/' "$QA_MD" > "$WORK/qs-role-nosetup.md"
sed -e 's/^the canonical run of the anchor.s test is GREEN there before any mutation\. An$/the mutation directly. An/' "$QA_MD" > "$WORK/qs-role-nogreen.md"
sed -e 's/^AC whose replay cannot reach a GREEN baseline in your worktree is handed to the$/AC whose replay cannot reach a GREEN baseline in your worktree is scored REJECT by the/' "$QA_MD" > "$WORK/qs-role-nohand.md"
sed -e 's/^part.s files or that a part shard handed over, and the interactions between$/part'"'"'s files, and the interactions between/' "$QA_MD" > "$WORK/qs-role-nocross.md"
sed -e 's/^first runs the project.s canonical dependency setup (the setup the dev.s QA$/first runs the replays (the setup the dev'"'"'s QA/' "$STEP_MD" > "$WORK/qs-step-nosetup.md"
sed -e 's/^whose replay cannot reach a GREEN baseline in the part.s worktree is handed to$/whose replay cannot reach a GREEN baseline in the part'"'"'s worktree is REJECTed, not handed to/' "$STEP_MD" > "$WORK/qs-step-nohand.md"
awk '/^\*\*Gate-2 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ && !d { print; print "In that worktree a part QA first runs the project'"'"'s canonical dependency setup (the setup the dev'"'"'s QA Handoff Evidence records, or the story'"'"'s documented setup) and confirms the canonical run of the anchor'"'"'s test is GREEN there before any mutation."; d = 1; p = 0 }
     /^first runs the project.s canonical dependency setup \(the setup the dev.s QA$/ { print "first runs the replays (the setup the dev'"'"'s QA"; next } { print }' "$STEP_MD" > "$WORK/qs-step-moved.md"
# The moved copy must not still carry the sentence in place: assert the in-paragraph edit applied.
grep -q '^first runs the replays (the setup the dev.s QA$' "$WORK/qs-step-moved.md" || cp "$STEP_MD" "$WORK/qs-step-moved.md"
sed -e 's/^  path and its `shard-verdict:` value instead, never per-AC rows, which only$/  path, its `shard-verdict:` value and its per-AC rows, which only/' "$QA_MD" > "$WORK/qs-deliver-rows.md"
_s10s=0
for _p in "$QA_MD:qs-role-nosetup.md" "$QA_MD:qs-role-nogreen.md" "$QA_MD:qs-role-nohand.md" "$QA_MD:qs-role-nocross.md" \
          "$STEP_MD:qs-step-nosetup.md" "$STEP_MD:qs-step-nohand.md" "$STEP_MD:qs-step-moved.md" "$QA_MD:qs-deliver-rows.md"; do
  cmp -s "${_p%%:*}" "$WORK/${_p#*:}" && { _s10s=1; echo "  (unchanged probe: ${_p#*:})"; }
done
_s10f=""
for _o in qs-role-nosetup qs-role-nogreen qs-role-nohand qs-role-nocross; do p_qsetup_role "$WORK/$_o.md" && _s10f="$_s10f $_o"; done
for _o in qs-step-nosetup qs-step-nohand qs-step-moved; do p_qsetup_step "$WORK/$_o.md" && _s10f="$_s10f $_o"; done
p_qdeliver "$WORK/qs-deliver-rows.md" && _s10f="$_s10f qs-deliver-rows"
if [ "$_s10s" -ne 0 ]; then
  bad "S10-pre: FIXTURE STALE -- a part-shard setup or delivery probe's edit matched nothing, so the probe would score the shipped text"
elif [ -n "$_s10f" ]; then
  bad "S10-pre: FIXTURE BROKEN -- a part-shard setup or delivery predicate passed offender(s) [${_s10f# }]"
else
  ok "S10-pre: 8 offenders refused (setup, GREEN baseline, hand-over or cross ownership dropped from qa.md; setup or hand-over dropped from the Gate-2 paragraph; setup moved out of that paragraph; a part shard delivering per-AC rows)"
fi
_s10=""
p_qsetup_role "$QA_MD" || _s10="$_s10 qa.md-As-a-Shard"
p_qsetup_step "$STEP_MD" || _s10="$_s10 implementation.md-Gate-2-dispatch"
p_qdeliver "$QA_MD" || _s10="$_s10 qa.md-Deliver-before-idle"
if [ -z "$_s10" ]; then
  ok "S10: qa.md's As a Shard and implementation.md's Gate-2 paragraph make a part shard run the canonical dependency setup and reach a GREEN baseline before any mutation, hand an unreachable AC to the cross shard, and the cross shard owns it; a part shard delivers its shard path and shard-verdict, not per-AC rows"
else
  bad "S10: [${_s10# }] does not carry the part shard's dependency setup, GREEN baseline, hand-over, or path-and-verdict delivery"
fi

# A HAND-OVER IS RUN BY NOBODY UNLESS THE CROSS QA IS DISPATCHED AFTER THE PARTS AND TOLD TO READ
# THEM. Parts and cross in one wave left the cross shard no file to read, and nothing told it to
# read one. PINS, joined with `**` dropped, at the emission sites: the Gate-2 paragraph (parts
# first, cross only after every part shard file exists, its brief naming them, and the cross QA
# reading them for `handover:` lines before scoring); qa.md's As a Shard (the hand-over's
# `handover:` line under `### Important`, never a Deferred container, and the cross shard reading
# every part shard and writing `handover-run:`); the Deliver-before-idle bullet (the first cross
# shard, cross-1, delivers the count of hand-overs it ran).
p_ho_step() { local t; t="$(step2_para "$1" | joined)"
  grep -qF 'ONE cross QA, briefed `shard: cross/<K> g1/1 <ordinals>` (K = N, `<ordinals>` every ordinal 1..K comma-joined without padding) with the whole map and the whole diff to read, writing `cross.md` there, is dispatched in the same wave as the part QAs, the first cross QA in the first wave whatever the cap leaves for the rest, and the first cross QA'"'"'s brief names the absolute path of every part shard file, the round'"'"'s epoch and a beat state directory of its own' <<<"$t" \
    && grep -qF 'the first cross QA in the first wave whatever the cap leaves for the rest' <<<"$t" \
    && grep -qF 'and only then joins the part shard files itself with `AI_DLC_STATE_DIR=<that directory> wait-for-deliverable.sh --complete --since <epoch> <part paths>`' <<<"$t" \
    && grep -qF 'Once that join completes, the first cross QA reads every part shard file for `handover:` lines, runs each handed-over replay and records it as a `handover-run:` line' <<<"$t"; }
p_ho_role() { local t; t="$(role_sect "$1" | joined)"
  grep -qF 'The hand-over finding goes under `### Important`, never under a `### Deferred` container, and carries exactly one column-0 `handover: <AC-id>` line beside its `parts:` line.' <<<"$t" \
    && grep -qF 'You are dispatched in the same wave as the part shards, so the part files may not exist yet.' <<<"$t" \
    && grep -qF 'scripts/ai-dlc/wait-for-deliverable.sh --complete --since <the round epoch your brief names> <part paths>`, run in the background and re-armed until every path is DELIVERED.' <<<"$t" \
    && grep -qF 'Once the join completes, the cross shard reads every part shard `<ordinal>.md` its brief names for `handover:` lines, runs each handed-over replay in the frozen worktree after the project'"'"'s canonical dependency setup, and records each one as a column-0 `handover-run: <ordinal> <AC-id> <RED|GREEN-SURVIVED|NO-BASELINE>` line' <<<"$t"; }
p_ho_deliver() { local t; t="$(role_bullet "$1" Communication '- **Deliver before idle' | joined)"
  grep -qF 'The first cross shard (`cross`, or `cross-1` of a per-group set) delivers its shard file'"'"'s absolute path, its `shard-verdict:` value and the count of hand-overs it ran; its per-AC rows stay in the file.' <<<"$t"; }
# OFFENDERS: the parts-first (two-wave) dispatch restored; the cross QA's own --complete join
# dropped; the cross-read dropped from each site; the hand-over placed under Deferred; the
# same-wave sentence moved out of its paragraph; the cross delivery dropped.
sed -e 's/^writing `cross.md` there, is dispatched in the same wave as the part QAs, the first cross QA in$/writing `cross.md` there, is dispatched only after every part shard file exists, the first cross QA in/' "$STEP_MD" > "$WORK/ho-step-onewave.md"
sed -e 's/^`AI_DLC_STATE_DIR=<that directory> wait-for-deliverable.sh --complete --since <epoch> <part paths>`,$/`AI_DLC_STATE_DIR=<that directory> wait-for-deliverable.sh --complete <part paths>`,/' "$STEP_MD" > "$WORK/ho-step-nojoin.md"
sed -e 's/^the first wave whatever the cap leaves for the rest, and the first cross QA.s$/the wave after the parts, and the first cross QA'"'"'s/' "$STEP_MD" > "$WORK/ho-step-latewave.md"
sed -e 's/^completes, the first cross QA reads every part shard file for `handover:` lines, runs each$/completes, the first cross QA may read a part shard file for `handover:` lines, runs each/' "$STEP_MD" > "$WORK/ho-step-noread.md"
awk '/^\*\*Gate-2 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ && !d { print; print "ONE cross QA, briefed `shard: cross/<K> g1/1 <ordinals>` (K = N, `<ordinals>` every ordinal 1..K comma-joined without padding) with the whole map and the whole diff to read, writing `cross.md` there, is dispatched in the same wave as the part QAs, the first cross QA in the first wave whatever the cap leaves for the rest, and the first cross QA'"'"'s brief names the absolute path of every part shard file, the round'"'"'s epoch and a beat state directory of its own"; d = 1; p = 0 }
     /^writing `cross.md` there, is dispatched in the same wave as the part QAs, the first cross QA in$/ { print "writing `cross.md` there, is dispatched only after every part shard file exists, the first cross QA in"; next } { print }' "$STEP_MD" > "$WORK/ho-step-moved.md"
grep -q '^writing `cross.md` there, is dispatched only after every part shard file exists' "$WORK/ho-step-moved.md" || cp "$STEP_MD" "$WORK/ho-step-moved.md"
sed -e 's/^`### Important`, never under a `### Deferred` container, and carries exactly$/`### Deferred ACs`, and carries exactly/' "$QA_MD" > "$WORK/ho-role-deferred.md"
sed -e 's/^the join completes, the cross shard reads every part shard$/the join completes, the cross shard may read a part shard/' "$QA_MD" > "$WORK/ho-role-noread.md"
sed -e 's/^scripts\/ai-dlc\/wait-for-deliverable.sh --complete --since <the round epoch your brief names> <part paths>`,$/scripts\/ai-dlc\/wait-for-deliverable.sh --complete <part paths>`,/' "$QA_MD" > "$WORK/ho-role-nojoin.md"
sed -e 's/^  `shard-verdict:` value and the count of hand-overs it ran; its per-AC rows$/  `shard-verdict:` value; its per-AC rows/' "$QA_MD" > "$WORK/ho-deliver-nocount.md"
_s11s=0
for _p in "$STEP_MD:ho-step-onewave.md" "$STEP_MD:ho-step-nojoin.md" "$STEP_MD:ho-step-latewave.md" "$STEP_MD:ho-step-noread.md" "$STEP_MD:ho-step-moved.md" \
          "$QA_MD:ho-role-deferred.md" "$QA_MD:ho-role-noread.md" "$QA_MD:ho-role-nojoin.md" "$QA_MD:ho-deliver-nocount.md"; do
  cmp -s "${_p%%:*}" "$WORK/${_p#*:}" && { _s11s=1; echo "  (unchanged probe: ${_p#*:})"; }
done
_s11f=""
for _o in ho-step-onewave ho-step-nojoin ho-step-latewave ho-step-noread ho-step-moved; do p_ho_step "$WORK/$_o.md" && _s11f="$_s11f $_o"; done
for _o in ho-role-deferred ho-role-noread ho-role-nojoin; do p_ho_role "$WORK/$_o.md" && _s11f="$_s11f $_o"; done
p_ho_deliver "$WORK/ho-deliver-nocount.md" && _s11f="$_s11f ho-deliver-nocount"
if [ "$_s11s" -ne 0 ]; then
  bad "S11-pre: FIXTURE STALE -- a hand-over ordering or cross-read probe's edit matched nothing, so the probe would score the shipped text"
elif [ -n "$_s11f" ]; then
  bad "S11-pre: FIXTURE BROKEN -- a hand-over ordering or cross-read predicate passed offender(s) [${_s11f# }]"
else
  ok "S11-pre: 9 offenders refused (the cross QAs dispatched after the parts; the first cross QA out of the first wave; the cross QA's join without --since at the Gate-2 paragraph and at qa.md; the cross read dropped from each; the same-wave sentence moved out of the paragraph; the hand-over under '### Deferred ACs'; the cross delivery without its hand-over count)"
fi
_s11=""
p_ho_step "$STEP_MD" || _s11="$_s11 implementation.md-Gate-2-dispatch"
p_ho_role "$QA_MD" || _s11="$_s11 qa.md-As-a-Shard"
p_ho_deliver "$QA_MD" || _s11="$_s11 qa.md-Deliver-before-idle"
if [ -z "$_s11" ]; then
  ok "S11: the Gate-2 paragraph dispatches the cross QAs in the same wave as the parts, has the first cross QA join the part files with its own --complete beat and only then read them for hand-overs; qa.md says the same, places a hand-over under '### Important' and has the cross shard write 'handover-run:'; the cross shard delivers its hand-over count"
else
  bad "S11: [${_s11# }] does not carry the same-wave dispatch, the cross shard's own join, its hand-over read, or its hand-over count"
fi

# GATE 1 SHARDS ITS MUTATION-RED REPLAYS. Pinned at the two emission sites, read joined: the
# Gate-1 paragraph (one wave; each part reviewer replays its own part's REDs in its own detached
# worktree and declares `handovers: <n>`; the first cross reviewer joins the parts before running
# the hand-overs) and code-reviewer.md's As a Shard. A REVERT to "part reviewers EXECUTE NOTHING"
# is refused at both sites.
p_cr_step() { local t; t="$(step_para "$1" | joined)"
  ! grep -qi 'Part reviewers EXECUTE NOTHING' <<<"$t" \
    && grep -qF '(Rule 28, "Split dispatch": files axis), all in the same wave and the first cross reviewer in the first wave.' <<<"$t" \
    && grep -qF 'Each part reviewer replays, with `validate-mutation-red.sh`, the mutation-REDs whose anchor file lies in its part, in its own detached worktree at the frozen sha after the project'"'"'s canonical dependency setup' <<<"$t" \
    && grep -qF 'every part shard carries one header line `handovers: <n>`, `0` when it handed nothing over.' <<<"$t" \
    && grep -qF 'joins the part shard files as the first cross QA does below and runs every handed-over replay there, recorded as `handover-run:` lines' <<<"$t"; }
p_cr_role() { local t; t="$(role_sect "$1" | joined)"
  ! grep -qi 'As a part shard you EXECUTE NOTHING' <<<"$t" \
    && grep -qF 'in your OWN detached worktree at the frozen sha (`git worktree add --detach <tmp> <sha>`), never in the shared frozen worktree' <<<"$t" \
    && grep -qF 'As a part shard you also carry one column-0 `handovers: <n>` line beside `reviewed-sha:`, `0` when you handed nothing over.' <<<"$t" \
    && grep -qF 'scripts/ai-dlc/wait-for-deliverable.sh --complete --since <the round epoch your brief names> <part paths>`, backgrounded and re-armed until each is DELIVERED.' <<<"$t" \
    && grep -qF '`handover-run: <ordinal> <AC-id> <RED|GREEN-SURVIVED|NO-BASELINE>`' <<<"$t"; }
sed -e 's/^Part reviewers run no suite and no build\. Each part reviewer replays, with$/Part reviewers EXECUTE NOTHING. Each part reviewer replays, with/' "$STEP_MD" > "$WORK/cr-step-exec.md"
sed -e 's/^(Rule 28, "Split dispatch": files axis), all in the same wave and$/(Rule 28, "Split dispatch": files axis), and/' "$STEP_MD" > "$WORK/cr-step-wave.md"
sed -e 's/^one header line `handovers: <n>`, `0` when it handed nothing over\. The first$/one header line, `0` when it handed nothing over. The first/' "$STEP_MD" > "$WORK/cr-step-nocount.md"
sed -e 's/^`parts:` set\. As a part shard you run no suite and no build\. You replay,$/`parts:` set. As a part shard you EXECUTE NOTHING. You replay,/' "$ROLE_MD" > "$WORK/cr-role-exec.md"
sed -e 's/^(`git worktree add --detach <tmp> <sha>`), never in the shared frozen$/in the shared frozen/' "$ROLE_MD" > "$WORK/cr-role-shared.md"
sed -e 's/^scripts\/ai-dlc\/wait-for-deliverable.sh --complete --since <the round epoch your brief names> <part paths>`,$/scripts\/ai-dlc\/wait-for-deliverable.sh --complete <part paths>`,/' "$ROLE_MD" > "$WORK/cr-role-nojoin.md"
_s13s=0
for _p in "$STEP_MD:cr-step-exec.md" "$STEP_MD:cr-step-wave.md" "$STEP_MD:cr-step-nocount.md" \
          "$ROLE_MD:cr-role-exec.md" "$ROLE_MD:cr-role-shared.md" "$ROLE_MD:cr-role-nojoin.md"; do
  cmp -s "${_p%%:*}" "$WORK/${_p#*:}" && { _s13s=1; echo "  (unchanged probe: ${_p#*:})"; }
done
_s13f=""
for _o in cr-step-exec cr-step-wave cr-step-nocount; do p_cr_step "$WORK/$_o.md" && _s13f="$_s13f $_o"; done
for _o in cr-role-exec cr-role-shared cr-role-nojoin; do p_cr_role "$WORK/$_o.md" && _s13f="$_s13f $_o"; done
if [ "$_s13s" -ne 0 ]; then
  bad "S13-pre: FIXTURE STALE -- a gate-1 execution-sharding probe's edit matched nothing, so the probe would score the shipped text"
elif [ -n "$_s13f" ]; then
  bad "S13-pre: FIXTURE BROKEN -- a gate-1 execution-sharding predicate passed offender(s) [${_s13f# }]"
else
  ok "S13-pre: 6 offenders refused (part reviewers EXECUTE NOTHING restored at each site; the same wave dropped; the declared count dropped; the replay moved into the shared frozen worktree; the cross reviewer's re-armed join dropped)"
fi
_s13=""
p_cr_step "$STEP_MD" || _s13="$_s13 implementation.md-Gate-1-dispatch"
p_cr_role "$ROLE_MD" || _s13="$_s13 code-reviewer.md-As-a-Shard"
if [ -z "$_s13" ]; then
  ok "S13: the Gate-1 paragraph and code-reviewer.md's As a Shard dispatch every reviewer in one wave, have each part reviewer replay its part's mutation-REDs in its own detached worktree and declare 'handovers: <n>', and have the first cross reviewer join the parts before running the hand-overs"
else
  bad "S13: [${_s13# }] does not shard gate 1's mutation-RED replays across the part reviewers"
fi

# THE DECLARED COUNT AT THE EMISSION SITES. A part shard written to qa.md or briefed from the Gate-2
# paragraph without `handovers: <n>` is refused at the join, so both sites must tell it to write
# one: qa.md's `## As a Shard` and the Gate-2 dispatch paragraph, read joined with `**` dropped.
p_hc_role() { local t; t="$(role_sect "$1" | joined)"
  grep -qF 'A part shard also carries, beside those two lines, exactly one column-0 `handovers: <n>` line counting its hand-overs however written, `0` when it handed nothing over; the cross shard carries none.' <<<"$t"; }
p_hc_step() { local t; t="$(step2_para "$1" | joined)"
  grep -qF 'every part shard carries one header line `handovers: <n>` counting its hand-overs, `0` when it handed nothing over (the grammar is `merge-review-shards.sh`'"'"'s header).' <<<"$t"; }
sed -e 's/^exactly one column-0 `handovers: <n>` line counting its hand-overs however written, `0`$/exactly one column-0 line counting its hand-overs however written, `0`/' "$QA_MD" > "$WORK/hc-role-strip.md"
sed -e 's/^shard carries one header line `handovers: <n>` counting its hand-overs, `0` when$/shard counts its hand-overs, `0` when/' "$STEP_MD" > "$WORK/hc-step-strip.md"
if cmp -s "$QA_MD" "$WORK/hc-role-strip.md" || cmp -s "$STEP_MD" "$WORK/hc-step-strip.md"; then
  bad "S12-pre: FIXTURE STALE -- a declared-count probe's edit matched nothing, so the probe would score the shipped text"
elif p_hc_role "$WORK/hc-role-strip.md" || p_hc_step "$WORK/hc-step-strip.md"; then
  bad "S12-pre: FIXTURE BROKEN -- a declared-count predicate passed a copy with 'handovers: <n>' removed"
else
  ok "S12-pre: the declared-count predicates refuse qa.md's As a Shard and the Gate-2 paragraph with 'handovers: <n>' removed"
fi
_s12=""
p_hc_role "$QA_MD" || _s12="$_s12 qa.md-As-a-Shard"
p_hc_step "$STEP_MD" || _s12="$_s12 implementation.md-Gate-2-dispatch"
# XC-STEP (BL-808): every literal partition invocation in implementation.md -- gate 1, the pass-M>=2
# re-review and gate 2 -- passes --exclude-captures ON THE SAME LINE as its `--map <worktree>`. The
# invocation count is held to exactly 3 (the control: a count below 3 means an invocation lost its
# literal and the per-line join would pass on fewer), and the flagged count must equal it. The
# offender drops the flag from the FIRST invocation only, on a copy.
xc_step_counts() { # <file> -> "<invocations> <flagged>"
  local a b
  a="$(grep -cF -- 'partition-review-diff.sh --map <worktree>' "$1")" || a=0
  b="$(grep -F -- 'partition-review-diff.sh --map <worktree>' "$1" | grep -cF -- '--exclude-captures')" || b=0
  printf '%s %s' "$a" "$b"
}
p_xc_step() { [ "$(xc_step_counts "$1")" = "3 3" ]; }
awk '!done && index($0, "partition-review-diff.sh --map <worktree>") && sub(/ --exclude-captures/, "") { done = 1 } { print }' \
  "$STEP_MD" > "$WORK/xc-step-drop.md"
if cmp -s "$STEP_MD" "$WORK/xc-step-drop.md"; then
  bad "XC-STEP-pre: FIXTURE STALE -- the drop-the-flag offender matched no invocation carrying ' --exclude-captures', so the probe would score the shipped text"
elif p_xc_step "$WORK/xc-step-drop.md"; then
  bad "XC-STEP-pre: FIXTURE BROKEN -- the step pin passed a copy with --exclude-captures dropped from one invocation ($(xc_step_counts "$WORK/xc-step-drop.md"))"
else
  ok "XC-STEP-pre: the step pin refuses a copy with --exclude-captures dropped from one invocation ($(xc_step_counts "$WORK/xc-step-drop.md"))"
fi
if p_xc_step "$STEP_MD"; then
  ok "XC-STEP: implementation.md carries exactly 3 'partition-review-diff.sh --map <worktree>' invocations (gate 1, the re-review, gate 2), each passing --exclude-captures on the same line"
else
  bad "XC-STEP: implementation.md's partition invocations and flagged ones read [$(xc_step_counts "$STEP_MD")], want [3 3]"
fi
if [ -z "$_s12" ]; then
  ok "S12: qa.md's As a Shard and implementation.md's Gate-2 paragraph tell every part shard to write 'handovers: <n>', 0 when it handed nothing over"
else
  bad "S12: [${_s12# }] does not tell a part shard to write its declared 'handovers: <n>' count"
fi
echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
