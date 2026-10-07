#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# review-shard-merge/run.sh -- partition-review-diff.sh and merge-review-shards.sh, the part set
# and the JOIN of a sharded gate-1 code review and of a sharded gate-2 QA validation (--gate qa;
# arms Q1-Q16, S7-S10). The behavioural arms only: the mutation battery that proves each of them
# can fail is `review-shard-merge-mutants`, distribution-only, which sources the SAME predicates
# from `lib.sh` beside this file. The battery mutates copies of core's own scripts, which a
# consumer cannot edit, so the consumer keeps every correctness arm and loses only that proof.
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
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="review-shard-merge"
[ -f "$HERE/lib.sh" ] || { echo "FIXTURE BROKEN: $HERE/lib.sh is absent; nothing was asserted" >&2; exit 2; }
. "$HERE/lib.sh"

# ---------------------------------------------------------------------------------- the arms
echo "$NAME:"
seed_controls

arm() { # <predicate> <label-ok> <label-bad>
  if "p_$1" "$SRCDIR"; then ok "$2"; else bad "$3 (rc=${RC:-?}): $(cat "$MO" 2>/dev/null | head -3)"; fi
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
arm env "P3: the key set to 4 in the environment, no flag -> repo B partitions to >= 2 parts" \
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
arm x_only "X2: K=8, and K=3, with one cross.md in place of the cross groups -> REFUSED 'a single cross shard is owed only at K=2', nothing at --out" \
           "X2: a single unsharded cross reviewer was merged where the cross groups were owed"
arm x_mix "X3: cross.md beside cross-1..3 -> REFUSED as a mix, nothing at --out" "X3: cross.md and cross-<g>.md merged together"
arm x_unknown "X4: cross-4 at K=3, and cross-1.md in place of cross.md at K=2 -> each REFUSED as a group --cross-groups does not print" \
              "X4: a cross shard naming a group the table does not print was merged"
arm x_owner "X5: K=8, a finding citing 1, 2 in cross-3 (inside its group, owned by cross-1) -> REFUSED naming the owner; the same finding in cross-1 merges and the finding count rises by one" \
            "X5: a cross finding reported by a group that does not own it was merged, or its owner's copy was refused"
arm x_actable "X6: --gate qa, the per-AC table in cross-2 and the deferred record in cross-3 -> each REFUSED, only cross-1 writes them" \
              "X6: a per-AC table or deferred record outside cross-1 was merged"
arm x_horun "X7: --gate qa, part 2's hand-over replayed by cross-2 rather than cross-1 -> REFUSED, only cross-1 runs a replay" \
            "X7: a hand-over replayed by a cross group other than the execution owner was merged"
arm x_k2 "X8: K=2 -- cross.md merges under both gates, titled 'merged from 3 shards', its body header '## Shard: cross'" \
         "X8: a K=2 shard dir with its one cross.md did not merge as before"
arm x_seat "X9: one shard without 'seat-complete:' beside shards with it, and a marker that is not the last non-blank line -> each REFUSED; every shard ending in it (blank lines after) merges, the marker dropped" \
           "X9: an unfinished shard was merged beside finished ones, or finished shards were refused"

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
  grep -qF 'The part QAs are dispatched first; the cross QAs, one per row `partition-document.sh --cross-groups <K>` prints (K = N), briefed `shard: cross/<K> g<g>/<G> <ordinals>` with the whole group table and the owner rule, each writing `cross-<g>.md` there (`cross.md` when the table has one row), are dispatched only after every part shard file exists, and the first cross QA'"'"'s brief names the absolute path of every part shard file.' <<<"$t" \
    && grep -qF 'Before scoring, the first cross QA reads every part shard file for `handover:` lines, runs each handed-over replay and records it as a `handover-run:` line' <<<"$t"; }
p_ho_role() { local t; t="$(role_sect "$1" | joined)"
  grep -qF 'The hand-over finding goes under `### Important`, never under a `### Deferred` container, and carries exactly one column-0 `handover: <AC-id>` line beside its `parts:` line.' <<<"$t" \
    && grep -qF 'Before scoring anything, the cross shard reads every part shard `<ordinal>.md` its brief names for `handover:` lines, runs each handed-over replay in the frozen worktree after the project'"'"'s canonical dependency setup, and records each one as a column-0 `handover-run: <ordinal> <AC-id> <RED|GREEN-SURVIVED|NO-BASELINE>` line' <<<"$t"; }
p_ho_deliver() { local t; t="$(role_bullet "$1" Communication '- **Deliver before idle' | joined)"
  grep -qF 'The first cross shard (`cross-1`, or `cross` when there is one cross group) delivers its shard file'"'"'s absolute path, its `shard-verdict:` value and the count of hand-overs it ran; its per-AC rows stay in the file.' <<<"$t"; }
# OFFENDERS: the one-wave dispatch restored; the cross-read dropped from each site; the hand-over
# placed under Deferred; the ordering sentence moved out of its paragraph; the cross delivery dropped.
sed -e 's/^("Split dispatch": files axis)\. The part QAs are dispatched first; the cross$/("Split dispatch": files axis), together with the cross/' "$STEP_MD" > "$WORK/ho-step-onewave.md"
sed -e 's/^the first cross QA reads every part shard file for `handover:` lines, runs each$/the first cross QA may read a part shard file for `handover:` lines, runs each/' "$STEP_MD" > "$WORK/ho-step-noread.md"
awk '/^\*\*Gate-2 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ && !d { print; print "The part QAs are dispatched first; the cross QAs, one per row `partition-document.sh --cross-groups <K>` prints (K = N), briefed `shard: cross/<K> g<g>/<G> <ordinals>` with the whole group table and the owner rule, each writing `cross-<g>.md` there (`cross.md` when the table has one row), are dispatched only after every part shard file exists, and the first cross QA'"'"'s brief names the absolute path of every part shard file."; d = 1; p = 0 }
     /^\("Split dispatch": files axis\)\. The part QAs are dispatched first; the cross$/ { print "(\"Split dispatch\": files axis), together with the cross"; next } { print }' "$STEP_MD" > "$WORK/ho-step-moved.md"
grep -q '^("Split dispatch": files axis), together with the cross$' "$WORK/ho-step-moved.md" || cp "$STEP_MD" "$WORK/ho-step-moved.md"
sed -e 's/^`### Important`, never under a `### Deferred` container, and carries exactly$/`### Deferred ACs`, and carries exactly/' "$QA_MD" > "$WORK/ho-role-deferred.md"
sed -e 's/^parts\. Before scoring anything, the cross shard reads every part shard$/parts. After scoring, the cross shard may read a part shard/' "$QA_MD" > "$WORK/ho-role-noread.md"
sed -e 's/^  `shard-verdict:` value and the count of hand-overs it ran; its per-AC rows$/  `shard-verdict:` value; its per-AC rows/' "$QA_MD" > "$WORK/ho-deliver-nocount.md"
_s11s=0
for _p in "$STEP_MD:ho-step-onewave.md" "$STEP_MD:ho-step-noread.md" "$STEP_MD:ho-step-moved.md" \
          "$QA_MD:ho-role-deferred.md" "$QA_MD:ho-role-noread.md" "$QA_MD:ho-deliver-nocount.md"; do
  cmp -s "${_p%%:*}" "$WORK/${_p#*:}" && { _s11s=1; echo "  (unchanged probe: ${_p#*:})"; }
done
_s11f=""
for _o in ho-step-onewave ho-step-noread ho-step-moved; do p_ho_step "$WORK/$_o.md" && _s11f="$_s11f $_o"; done
for _o in ho-role-deferred ho-role-noread; do p_ho_role "$WORK/$_o.md" && _s11f="$_s11f $_o"; done
p_ho_deliver "$WORK/ho-deliver-nocount.md" && _s11f="$_s11f ho-deliver-nocount"
if [ "$_s11s" -ne 0 ]; then
  bad "S11-pre: FIXTURE STALE -- a hand-over ordering or cross-read probe's edit matched nothing, so the probe would score the shipped text"
elif [ -n "$_s11f" ]; then
  bad "S11-pre: FIXTURE BROKEN -- a hand-over ordering or cross-read predicate passed offender(s) [${_s11f# }]"
else
  ok "S11-pre: 6 offenders refused (parts and cross in one wave; the cross read dropped from the Gate-2 paragraph; the ordering moved out of it; the hand-over under '### Deferred ACs'; the cross read dropped from qa.md; the cross delivery without its hand-over count)"
fi
_s11=""
p_ho_step "$STEP_MD" || _s11="$_s11 implementation.md-Gate-2-dispatch"
p_ho_role "$QA_MD" || _s11="$_s11 qa.md-As-a-Shard"
p_ho_deliver "$QA_MD" || _s11="$_s11 qa.md-Deliver-before-idle"
if [ -z "$_s11" ]; then
  ok "S11: the Gate-2 paragraph dispatches the cross QA only after every part shard file exists, names them in its brief, and has it read them for hand-overs before scoring; qa.md places a hand-over under '### Important' with its 'handover:' line and has the cross shard read every part shard and write 'handover-run:'; the cross shard delivers its hand-over count"
else
  bad "S11: [${_s11# }] does not carry the parts-first dispatch, the cross shard's hand-over read, or its hand-over count"
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
if [ -z "$_s12" ]; then
  ok "S12: qa.md's As a Shard and implementation.md's Gate-2 paragraph tell every part shard to write 'handovers: <n>', 0 when it handed nothing over"
else
  bad "S12: [${_s12# }] does not tell a part shard to write its declared 'handovers: <n>' count"
fi
echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
