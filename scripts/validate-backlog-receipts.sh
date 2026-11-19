#!/usr/bin/env bash
# validate-backlog-receipts.sh -- a receipt that a COMMENT can satisfy is not a receipt.
#
# THE SUBJECT. `.claude/rules/verification-discipline.md` says "bind to the line that EMITS
# the thing", and nothing enforced it. Measured over one batch's ranked set by building the
# non-fix for every candidate: nine of ten receipts went 1 -> 0 against a bare comment, a
# pure line reflow, or one word inside an unrelated description string. Every one of those
# receipts is the instrument the NEXT batch uses to decide whether its own fix worked.
#
# WHAT THIS ARM DOES. For every live `verify: sh` receipt it appends ONE comment line --
# carrying the receipt's own grep literals -- to every file the receipt names, in a pristine
# checkout of the tree, and re-runs the receipt. A receipt that goes 1 -> 0 against that
# comment is satisfied by prose. A flip is its own proof, so this arm's false-positive set is
# EMPTY BY CONSTRUCTION: it never judges a receipt, it demonstrates one.
#
# WHY THE SEED CARRIES THE RECEIPT'S OWN TOKENS AND NOT A GENERIC COMMENT. Measured over the
# live `sh` receipts: a generic `# probe` appended to every file every receipt names flips
# ZERO of them. An arm built on the generic seed is a check that cannot fire, and it would
# have shipped reading exactly like a clean corpus.
#
# THE SUBJECT TREE IS A REAL WORKING TREE OF A REAL REPOSITORY, AND THAT IS NOT A DETAIL. A
# `git archive` extraction has no `.git`, and a fifth of these receipts invoke git. Measured
# against a bare extraction: three receipts went to exit 0 -- a FALSE CLOSE, the dangerous
# direction -- and five more to 9 or 128, so the population itself was wrong and eight
# entries were excluded or flipped for a reason that had nothing to do with their receipts.
# Each receipt therefore gets `git worktree add --detach ... HEAD` off the ledger's OWN
# repository. Measured per tree: worktree 0.238s, archive 0.246s, init-plus-commit 0.889s,
# clone 1.022s -- and the worktree is the only cheap one that walks real history, which is
# what a receipt reading `origin/main` needs.
#
# A WORKTREE REGISTERS ITSELF IN THE PARENT REPOSITORY, so every one is removed on every exit
# path -- normal, failed, and interrupted -- and the parent prunes and then asserts the
# registered count came back to where it started. A leaked worktree is not a wrong verdict;
# it is a repository that slowly fills with directories nobody can name.
#
# REPORT BY NAME, GATE ON GROWTH. The population is already non-zero, so failing on any
# finding would wedge the push on first contact and be switched off, which is worse than no
# check. The ceilings are RATCHETS that only ever move DOWN -- the shape
# `core/scripts/validate-write-format-steering.sh --max-undeclared` and
# `scripts/validate-fixture-git-env.sh --max-unscrubbed` already use, for the same reason.
# Rewriting a reported receipt is per-entry work: each of those entries is its own subject.
#
# THERE ARE THREE RATCHETS AND A FLOOR, BECAUSE ONE RATCHET IS ESCAPABLE BY LEAVING THE
# POPULATION. Every one of these edits lowers the prose-closable count and fixes nothing:
# build the pattern from a variable, build the path from a variable, move the predicate into
# an `awk` body or `grep -f`, make the receipt exit 9, rewrite `verify: sh` as
# `verify: manual`, or delete the receipt line. The first four land in UNSCORABLE, the fifth
# in OUT-OF-POPULATION, and the last two leave the `sh` population altogether -- so all three
# counts are bounded and the population itself carries a floor.
#
# THE FLOOR'S SPEC, AND IT IS DELIBERATELY THE SIMPLE ONE. `sh` receipts may fall only by as
# much as the live entry count falls. Rotation and archiving remove entries and their
# receipts together, so they move both sides and are silent here; a `sh` -> `manual` rewrite
# and a deleted receipt line move only the first, and are not. FALSE-POSITIVE SET, MEASURED
# over the last twenty commits that touched docs/backlog.md, replaying each ledger blob
# against the compiled-in pair: the set is EMPTY -- every one of those commits moves the two
# counts together or not at all, because rotation is the only thing that has removed a receipt
# here. TWO CONTROLS IN THE SAME MEASUREMENT, both of which FIRE: rewriting one live entry's
# `verify: sh` as `verify: manual`, and deleting one live entry's receipt line, each take the
# `sh` count down by one against an unchanged entry count.
#
# THE FIRST SPELLING OF THAT CONTROL WAS QUIET, AND IT WAS THE CONTROL THAT WAS WRONG. Keyed
# on the first `^verify: sh ` line in the file, it rewrote the LEGEND in the preamble -- which
# is not inside any entry, so no count moved and the floor correctly said nothing. A control
# that agrees with the verdict is not a control; it must be seeded where the predicate can
# see it, which here means inside an entry.
#
# WHAT THE SEED GRAMMAR CANNOT SPELL, stated because a scan that cannot spell its own subject
# scores it as a non-instance and returns a clean zero of unknown depth. A pattern built from
# a variable (`grep -qF -- "$SUB"`), `grep -f <file>`, a `case` glob, an `awk` match body, and
# any pattern whose token is only partly quoted are all invisible here. Receipts carrying only
# those are reported UNSCORABLE with a count -- they are UNSPELLED, never evidence of a bound
# receipt.
#
# A RECEIPT THAT ONLY RUNS A TRACKED SCRIPT IS ITS OWN CLASS, `DRIVER`, AND IS NOT UNSCORABLE.
# `bash <repo-rel>.sh [plain args]`, optionally chained with `&&`, greps nothing in the one-liner,
# so there is no literal to seed and no comment that can satisfy it: the script is the subject.
# That is the shape R2's own remedy text tells authors to write. MEASURED on the ledger that
# exposed it -- 6 live entries, 4 `sh` receipts, 2 manual: three receipts were driver-shaped and
# all three read UNSCORABLE (every one at base exit 0), the fourth was OUT-OF-POPULATION at base
# 127 because its second `&&` segment names a script that is not in the tree, and R2 failed the
# push as "ZERO scored receipts" -- the arm refusing the corpus its own remedy produces. On the
# previous ledger it had passed only because one grep-literal receipt was left to score.
# The class is decided by SHAPE whatever the base exit (0 or 1), because a driver whose fix has
# landed is still a driver; the base exit rides in the detail. It requires EVERY script the chain
# runs to be TRACKED at HEAD (`git ls-files --error-unmatch` in the checkout): a script that is
# absent exits 127 and has already left as OUT-OF-POPULATION, and one present on disk but
# untracked at base 1 falls through to UNSCORABLE.
# R2 then accepts a zero only when every `sh` receipt is DRIVER, ALREADY-PASSING or
# OUT-OF-POPULATION and at least one is DRIVER (` R2 all-driver`), so one driver cannot acquit an
# unspelled receipt beside it. R3 DOES NOT COUNT DRIVER: R3 bounds the escapes from R2 (a pattern
# hidden in a variable, an awk body, a `grep -f` file), and a driver is R2's remedy, not an escape.
# Measured on the same ledger: unscorable 3 -> 0; `DEFAULT_MAX_UNSC` 28 and the hook's
# `--max-unscorable 28` are both unchanged. WHAT THE CLASS CANNOT SEE: a tracked script that itself
# only greps a literal is prose-closable one level down, and this arm does not open the script.
#
# A FLIP ON A .json/.yaml/.yml FILE IS AMBIGUOUS AND GETS A SECOND CONTROL. Appending a line
# to a JSON document breaks the document as well as carrying the token, so a receipt that
# parses its subject flips for a reason that is not prose-closability. Every flip whose seeded
# set touches such a file is re-run against a control line carrying NO token: if it flips
# under that too, the finding is a FORMAT break and is reported FORMAT-SENSITIVE rather than
# counted.
#
# DISTRIBUTION-ONLY. A consumer tree has no `docs/backlog.md`; `install.sh` derives its copy
# loop from `core/scripts/` and never touches the repo-root `scripts/`, so nothing here ships.
#
# WHY THIS IS NOT AN ARM INSIDE validate-enforcement-map.sh. That validator is invoked by
# roughly two dozen fixture directories and the two sharded mutation batteries drive it
# through ~20 and ~17 mutants each, so a second of arm there is ~30s on the suite's POLE.
# This arm runs whole subject trees and is the most expensive validator in the hook; it is
# dispatched once, from the hook, like the other standalone validators. It is also not an arm
# of `validate-backlog-size.sh`: that one bounds the ledger's DEPTH and never opens a receipt.
#
# THE LEDGER IS READ WHERE IT IS GIVEN AND THE RECEIPTS RUN AGAINST ITS REPOSITORY'S `HEAD`.
# At push time the working tree and HEAD agree, which is the only time this arm gates. They
# differ in a dirty tree, and the OK line names both sides so a surprising verdict is
# diagnosable rather than mysterious.
#
# NEITHER THE ENTRY BOUNDARY NOR THE LABEL RULE IS RESTATED HERE. Both are loaded from
# reconcile/lib.sh -- `ledger_entry_awk` and `backlog_entry_label_awk` -- whose header records
# that two hand-copies of the boundary DRIFTED WITHIN ONE RELEASE.
#
# R7 AND R8 -- A RECEIPT THAT STOPPED MEASURING ITS SUBJECT (BL-836). Before them, every exit outside
# {0,1} fell into OUT-OF-POPULATION under a ceiling of 1, and nothing ran a CLOSED entry's receipt
# at all, so a subject renamed inside a release broke the receipt silently (BL-830's
# `bg1_killed` -> `bg1_convicts`; BL-834's missing `core/fixtures/lib/mutant.sh`).
#
#   R7, OPEN entries. Population: every live `verify: sh` receipt the scorer above already runs.
#      FAIL SET, and its SOURCE is backlog-reverify.sh's measured could-not-measure set, sourced
#      from scripts/backlog-receipt-lib.sh rather than restated: exit 9; exit 126; exit >= 128;
#      and `cant_measure`'s own-shell route -- exit 1, 2 or 127 with the receipt's OWN interpreter
#      (`$0: line N:` / `$0: eval: line N:`) reporting `command not found`, `No such file or
#      directory` or `syntax error`. NOT bare 127 (a SUBJECT calling a helper it does not ship) and
#      NOT 2-8: those are reproductions here, and BL-830's receipt exits 2 while open. Decided after
#      the re-read, so a 9-then-1 receipt stays UNSTABLE. Rows stay OUT-OF-POPULATION and carry
#      `-cannot-measure=<member>`; R7's ceiling `DEFAULT_MAX_CM` is 0.
#      WHAT R7 CANNOT SEE, stated plainly: an OPEN receipt that GREPS for a renamed anchor exits 1,
#      which is STILL-LIVE's own code, so exit alone cannot tell it from a live defect -- measured,
#      `grep -q old_name f` seeded open: exit 1, no finding. A receipt that CALLS the renamed symbol
#      is seen: BL-830's real shape (`. f; old_name x || exit 1`) gives the receipt's own shell a
#      `command not found`, exit 1, which the own-shell route takes -- measured, seeded open: R7 fires.
#      A grep-shaped receipt is seen only when it ASSERTS ITS ANCHOR EXISTS before testing the defect
#      (`grep -q anchor f || exit 9; ...`) -- a receipt convention, not built here.
#   R8, entries CLOSED ON THE BRANCH. Population, derived in the SUBJECT repository against the
#      merge-base of `--base` (default origin/main) and HEAD: entries carrying `**LANDED (v` at HEAD
#      and not at the merge-base, plus entries whose heading is among the ADDED lines of the
#      archive's `git diff -U0`, each parsed with the ledger's own entry grammar. Expected exit:
#      exactly 0; any other exit FAILs with a row naming the id, the exit and the reason.
#      `--base` resolving to nothing is reported NOT DERIVED, never as empty.
#   No path-token filter is used by either arm, so neither carries a path-extraction floor.
#
# R9 -- THE LIVE-LEDGER JOINS (BL-872). Two joins that used to be arms j1 and b16 of
# core/fixtures/backlog-real-ledger/, which now reads a frozen ledger snapshot so its invocation
# count stops following docs/backlog.md. Against the LIVE ledger they run here, wherever the pre-push
# step "backlog receipts" runs. That step is keyed on what it reads, the ledger among them, so a
# ledger edit re-runs it; AI_DLC_PRESUITE_SKIP=1 skips it and R9 with it (BL-870):
#   j1  this arm's own `sh` population (the scorer's count, R5's number) is AT LEAST the shipping
#       classifier's resolved set -- the distinct ids scripts/backlog-reverify.sh reports from an sh
#       receipt that ran (`sh receipt exited`). Smaller means receipts exist that this arm never scores.
#   b16 scripts/validate-backlog-size.sh's B1 count equals the classifier's distinct entry ids; a
#       declared-empty ledger is asked the declared state instead (ceiling 0 declared empty, one
#       DECLARED-EMPTY row).
#   The classifier evaluates every live receipt, so it runs inside a detached checkout of the subject
#   repository's HEAD, never in the caller's tree, with BR_RECEIPTS_RUNNING set to this run's key so a
#   receipt that re-enters this validator skips. Where this tree carries no validate-backlog-size.sh
#   (a seeded ledger tree) or its HEAD no scripts/backlog-reverify.sh, R9 prints
#   `R9: NOT RUN` and observes nothing, said as such in every verbosity. A zero on both sides is not
#   refused: an all-manual ledger has no `sh` receipt.
#
# R10 -- AN OPEN RECEIPT ASSERTS ITS ANCHOR BEFORE IT TESTS ITS DEFECT (BL-836, the operator's
# "adopt the convention" ruling). R7 cannot see a grep-shaped receipt whose subject was renamed: it
# exits 1, STILL-LIVE's own code (and `! grep` exits 0, which R8 then reads as a good close). The
# convention makes that rename visible to R7 with no change to R7: before the defect test the receipt
# proves the thing it tests EXISTS, and exits 9 -- already in R7's FAIL set -- if it does not.
#   Population: every OPEN `verify: sh` receipt, the `$WORK/rec` line-2 bytes R2's worker evals, read
#      as TEXT in the corpus step only (`--archive` exits before it). It EXECUTES NOTHING: one `git ls-files` and one awk program per run.
#   Rule: a grep, egrep, fgrep, awk, sed or cat -- `! grep` included, since after a rename it exits 0
#      -- or a working-tree `git grep` / `git show HEAD:p` / `git show :p`, whose FILE operand resolves
#      to a path TRACKED in the subject root (`git ls-files`, exact path, never a prefix list), must be
#      preceded in the same receipt by an ANCHOR on THAT path. Operands are resolved through earlier
#      `NAME=<literal>` assignments and `$( )` is descended into, quoted or not. A read inside a
#      `NAME=$( )` capture is held pending and is settled by a later anchor on its capture.
#   Anchor forms, each at top level (not inside `( )` or `$( )`, where exit leaves only the subshell):
#      `grep -q|--quiet <pat> P || exit 9`, `grep -q <pat> P || { ...; exit 9; }`,
#      `if ! grep -q <pat> P; then exit 9; fi`, and the non-empty extract
#      `s=$(awk|sed|grep ... P); [ -n "$s" ] || exit 9`, a count meaning one match or more
#      (`n=$(grep -c t P); [ "$n" -ge 1 ] || exit 9`, or the `$( )` inline), an anchor in an `&&`
#      chain ending `|| exit 9`, `awk|sed ... P | grep -q . || exit 9`, and an awk/sed rewrite of P to a
#      copy followed by `cmp -s P copy && exit 9`. The exit is `exit 9` followed by a word
#      boundary (`exit 99` is refused). A bare `[ -f P ]` is NOT an anchor, nor is `grep -qv`.
#   Vacuous anchors are refused: the pattern must carry an identifier run of four or more characters,
#      must not be a shebang, and must not be found on line 1 of P. An irrelevant-but-real identifier
#      is left to review.
#   Exempt: a history read against a NON-HEAD revision -- `git show <rev>:p`, `git grep ... <rev>`,
#      `git log` -- because the working tree's rename does not move it. NOT exempt: `git show HEAD:p`,
#      `git grep ... -- p`, `cat p | grep`, and a here-string fed from `$(cat p)`.
#   Ceiling 0 (`DEFAULT_MAX_R10`, `--max-unanchored`); `R10-POPULATION:` prints in every verbosity.
#   TODAY'S OPEN POPULATION IS 2 RECEIPTS, BOTH DRIVERS (`bash scripts/<x>.sh`) WITH NO GREP, so the
#      corpus 0 is VACUOUS: nothing was judged.
#   WHAT IT CANNOT SEE, so its refusal count is a FLOOR: a driver script's own greps (the arm never
#      opens a file a receipt runs), backticks, `cd`-relative paths, loop variables, heredocs,
#      `xargs`/`eval`/`bash -c` bodies, `git -C`, a directory operand (`grep -r x core/`), and any
#      operand left holding a `$` after resolution. Receipts carrying one are counted on the
#      population line as not fully parsed.
#   HOW THE FALSE-POSITIVE SET REACHED ITS VALUE: see the R10 FP block beside DEFAULT_MAX_R10.
#
# R11 -- A VERIFIED SHA THIS BRANCH ADDS TO A LANDED LINE IS AN ANCESTOR OF --base (BL-874). Population,
# rule, NOT DERIVED case and the measured false-positive set: the R11 block above
# r11_judge. `R11-POPULATION:` prints in every verbosity; ceiling 0.
#
# R12 -- A PARTIAL LIVE ENTRY KEEPS `verify: manual` WHILE ANY OWED ITEM IS OPEN (BL-943). Population,
# grammar, exemption, the measured false-positive set, its narrowing and its floors: the R12
# block above r12_judge. `R12-POPULATION:` prints in every verbosity; ceiling 0.
#
# R14 -- A LIVE LANDED LINE IS IN A FORM scripts/backlog-rotate.sh MOVES (BL-1147). Population, the loaded
# grammar, scope and the measured false-positive set: the R14 block above r14_judge. `R14-POPULATION:` prints
# in every verbosity; ceiling 0.
#
# M1 AND R13 -- A REMOVED DRIVER IS A CANNOT-MEASURE EXIT, AND A NAMED FILE A RECEIPT READS IS REMOVED AND THE
# RECEIPT RE-RUN (BL-899). M1 is R7's fourth route (driver-absent, lead ruling L3); R13 runs only under
# `--traced-removal`. Mechanism, instrument (atime after a forced epoch), the NAMED closure and its narrowing,
# the blind spots and the record: the M1/R13 block above vbr_sec_corpus.
# `R13-POPULATION:` prints in every verbosity; ceiling DEFAULT_MAX_R13.
#
# EMPTY IS NOT CLEAN. Both populations print a line in every verbosity -- `OPEN-POPULATION: EMPTY`
# when the ledger has no live `sh` receipt (the state on every push when this shipped: 43 live
# entries, 0 `sh` receipts; control, the same ledger's `^verify:` lines, 47, of which the one
# `^verify: sh` line is the `## Receipts` legend and sits in no entry), and
# `CLOSED-POPULATION: EMPTY / NOT DERIVED / <n> run`.
#
# HOW R7's FALSE-POSITIVE SET REACHED ZERO: it is EMPTY VACUOUSLY -- the live open `sh` population
# is 0, so nothing was measured, and that is not evidence. The cap ships at 0 on that basis; a
# filed `sh` receipt joins the population the moment it lands. R8's population on the release
# branch that ships it is that release's own closes. Measured on two scratch branches, each
# stamping one archived entry's text LANDED in the live ledger: BL-604's receipt exits 0 and R8
# passed; BL-056's exits 16 at this tree and R8 FAILED it by name -- a receipt that rotted after its
# close, which is a TRUE positive for a close made today, not a false one. The archive's receipts
# were NOT swept: over a hundred drive fixtures and dozens recurse into pre-push.
#
# Usage: validate-backlog-receipts.sh [<ledger>] [--root <dir>] [--base <ref>] [--quiet]
#          [--max-prose-closable N] [--max-unscorable N] [--max-out-of-population N]
#          [--max-unstable N] [--max-cannot-measure N] [--max-unanchored N]
#          [--traced-removal] [--max-unguarded N] [--min-sh-receipts N] [--min-entries N]
# Output: one TAB-delimited row per finding, then a summary and one OK line.
#          STATUS <TAB> ENTRY <TAB> paths=... <TAB> tokens=...
# Exit:  0 = at or under every ceiling; 1 = over one, or nothing was scored;
#        2 = usage or environment;
#        3 = RESTRICTED: the run was given --r13-drive or BR_R13_PROBE_DIR (the fixture's
#            cheap mode), so it is never a gate pass; its verdict (0 or 1) is printed as `RESTRICTED: verdict-rc=<n>`.
#            A restricted refusal stays 2.
vbr_sec_env() {
set -uo pipefail

# SCRUB THE REPOSITORY ENVIRONMENT BEFORE ANYTHING ELSE, AND FOR THE WHOLE PROCESS.
#
# `git -C <dir>` DOES NOT OVERRIDE AN INHERITED `GIT_DIR` -- the environment wins, for reads and
# for WRITES. MEASURED on two throwaway repositories: `GIT_DIR=A/.git git -C B log` reports A's
# commit, and `GIT_DIR=A/.git git -C B config k v` writes into A/.git/config and leaves B's
# untouched. Git exports GIT_DIR, ABSOLUTE, into every hook run from a LINKED WORKTREE, which is
# how this program runs at the gate -- so EVERY `git -C` in this file was aimed at the caller's
# repository rather than at the tree it named.
#
# TWO MEASURED CONSEQUENCES, and the second is why this sits at the top rather than around one
# call. A `config core.hooksPath` write wrote a mktemp path into the CALLER'S config,
# pointing that repository's own pre-push hook at a directory this run deletes -- a later push
# then ran NO GATE AT ALL and reported success, and a release landed on origin ungated. And
# `mktree`'s `worktree add --detach HEAD` checked out the CALLER'S HEAD for every receipt, so
# each one was scored against the wrong tree; at the gate that surfaced as
# receipts reading OUT-OF-POPULATION with base exits of 2, which reads as a broken
# scorer rather than as a redirected one.
#
# A PER-CALL SCRUB CANNOT BE COMPLETE. This file makes a dozen `git -C` calls across four
# helpers and any new one inherits the defect silently, so the environment is cleared ONCE, for
# the process, before a single git call is made. `core/fixtures/lib/preamble.sh` and the
# `fixture git-env scrub` gate phase exist for exactly this class on the fixture side; this
# program is not a fixture and had no such carrier.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
# AND THE CALLER'S `git -c` SETTINGS. git exports them to every hook child as GIT_CONFIG_PARAMETERS
# (and GIT_CONFIG_COUNT/KEY_n/VALUE_n), which override every repository's own config.
unset GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
# BR_R13_DIR ARMS R13'S TRACE IN EVERY --score-one WORKER (BL-899), so it too is the parent's alone: r13_arm sets
# it for the corpus pass. An inherited one would trace every pass.
case "${1:-}" in --score-one|--closed-one|--r13-one) ;; *) unset BR_R13_DIR BR_R13_STORE BR_R13_KCOMMON BR_R13_AWK BR_R13_RMOUT ;; esac
}

# ---------------------------------------------------------------------------
# THE PATH-SPLIT CHARACTER CLASS. This is the ONE grammar in this file that also exists
# somewhere else: `receipt_path_tokens()` in the consumer engine's ledger-reverify.sh, whose
# own header calls the class "every character a path cannot contain" and records that a second
# copy is "a second chance for the two to drift, and a drift here is silent in both directions
# at once." That file is a bootstrapping file and is not edited from here, so arm R0 below
# EXTRACTS its class at run time and compares the two rather than trusting this line.
# ---------------------------------------------------------------------------
PATH_CLASS='A-Za-z0-9_./$-'
CLASS_SOURCE='core/skills/ai-dlc-update/reconcile/ledger-reverify.sh'
CLASS_FUNC='receipt_path_tokens'

# The compiled-in ceilings and floors. They are what this arm READ on the tree that shipped
# them, not policy numbers: every receipt under a ceiling is a filed defect awaiting per-entry
# work, and the only sanctioned direction is down. Each is overridable by its flag and by the
# matching `AI_DLC_BACKLOG_*` variable, the flag winning.
DEFAULT_MAX_PC=9
DEFAULT_MAX_UNSC=28
DEFAULT_MAX_OOP=1
# UNSTABLE SHIPS AT ZERO, and it is the one ceiling that is not a measured debt. A receipt
# whose exit changes between two readings of the same commit cannot answer the question it
# exists to answer -- not once, not on the run that matters -- so there is no population of
# them to ratchet down. Zero is the standard, and a breach names the receipt.
DEFAULT_MAX_UNSTABLE=0
# R7, CANNOT-MEASURE, SHIPS AT ZERO: the live ledger's open `sh` population is 0 entries, so its
# false-positive set is EMPTY -- VACUOUSLY (see the header's BL-836 section). The gate passes no
# --max-cannot-measure, so this line is the one source.
DEFAULT_MAX_CM=0
# R10, UNANCHORED READS, SHIPS AT ZERO. The open `sh` population is 2 driver receipts with no grep, so
# its false-positive set is EMPTY -- VACUOUSLY.
# R10 FP BLOCK -- HOW THE REFUSAL SET REACHED ITS VALUE. Measured once, text only, with THIS file's
# r10_judge over every `verify: sh` receipt the ledger grammar parses at ba72d81e7 (702 archived, 2
# live; tracked set from that tree): 167 refused, 60 anchored, 477 reading no tracked path. 702 is
# the archive's 700 column-0 plus 2 indented `verify: sh` lines; a raw `grep -c 'verify: sh'` reads
# 730 because 28 more sit mid-line in prose, and only 1 entry carries a second `verify:` line (not
# an `sh` one). 167 IS A FLOOR: 253 receipts outside the refused set were only partly parsed (228
# reading no tracked path, 25 anchored), and any of them can hide an unanchored read this grammar
# could not follow. The census lint before it refused 33; 31 of those are still refused, and the 2
# that left were read correctly here (BL-116 anchors through a `[ -n "$s" ] || exit 9` capture,
# BL-064 reads no tracked path). The narrowing from the contract's draft: `! grep` was un-exempted
# (G1), the history exemption narrowed to a non-HEAD revision (G3), tracked decided by `git ls-files`
# rather than a prefix list (G2). THE FALSE-POSITIVE CENSUS, by this grammar over the same 704: 36 of
# the 167 carried an `exit 9` guard, other than a bare existence test, whose statement names the
# refused path or a variable bound to or captured from it. Five guard shapes ARE anchors and were
# accepted, each with an accepted seed, a vacuous twin and a mutant; which ids each freed was derived
# by judging the 704 once per scratch copy with that one acceptance disabled:
#   a count meaning one match or more (`-gt 0`, `-ge|-eq|= N>=1`, `-ne 0`), captured or inline
#     (BL-1029..1033, r10-m7): freed BL-073 140 151 271 286
#   an anchor in an `&&` chain ending `|| exit 9`, not the right side of an `||` (BL-1034/1035,
#     r10-m8): freed BL-153 365 366 396 408 415 502 504 656
#   a read piped into `grep -q . || exit 9` (BL-1037/1038, r10-m10): freed BL-263
#   an awk/sed rewrite of P to a copy, then `cmp -s P copy && exit 9` (BL-1039/1040, r10-m11):
#     freed BL-304 675
#   `grep -q <id pat> <<<"$C" || exit 9` over a capture C of P (BL-1041/1042/1045, r10-m12): freed
#     BL-050 400, and holds BL-403
# and two vacuous forms are refused: a pattern whose only word is a POSIX class name (`[[:blank:]]`;
# BL-1043, r10-m13), and `[ -n ]` over a `grep -v` capture, non-empty whenever another line exists
# (BL-1044, r10-m14), which is why BL-406 is newly refused -- it had read ANCHORED only through both.
# Result: 149 refused (was 167), 78 anchored (was 60); 19 left the set and 1 joined it.
# THE RESIDUAL FALSE POSITIVES -- the path's content gates `exit 9` with an identifier pattern, in a
# shape this grammar has no reader for -- are 4, left open, not accepted:
#   BL-014 `case "$P" in *'fm_block "$OVR" reason'*) ;; *) exit 9 ;; esac` over an awk capture of P
#   BL-248 `END{if(n!=8||g!=1)exit 9}` inside an awk program over P
#   BL-291 `jq -e '... any(test("/\\.claude/hooks/ai-dlc-..."))' P || exit 9`
#   BL-707 a count of a seeded marker in a rewritten copy of P, in a receipt only partly parsed
# REFUSED BY G5, the convention working as designed -- content gates `exit 9` but the pattern carries
# no identifier of four or more characters:
#   BL-091 `^## BL-[0-9]+` counted `-gt 0` (one identifier word in it reads ANCHORED, measured)
#   BL-127 `^# --- I[0-9]+` counted `${h:-0} -ge 10`
#   BL-653 BL-654 `[ -n "$t" ]` over `awk '/^### 2\./' P | tr`
#   BL-723 `awk '/^### 24\./' P` counted through `${c% *} -gt 0`
# THE TRUE REFUSALS among the 36, each guarding the refused read with no content test that exits 9:
#   BL-123 BL-456 BL-498 only `[ -f ]` and `cp ... || exit 9` touch the path
#   BL-193 `[ -f ]`, `cp ... || exit 9`, and `grep -q ... || exit 1` reads: a rename exits 1
#   BL-197 BL-743 the first read of the path is guarded by `exit 1`
#   BL-224 the anchor is on layer-drift.sh; the refused read is SKILL.md
#   BL-278 `grep -q x P && exit 9` exits 9 on a MATCH, so a rename does not reach exit 9
#   BL-288 the refused path is only `[ -r ]`-tested
#   BL-466 the capture is a pipeline whose own `|| exit 1` fires first on a rename
#   BL-477 a sed rewrite `|| exit 9` with no no-op check: sed exits 0 whatever it matched
#   BL-701 BL-713 a `grep -v` capture, non-empty for any file with an uncommented line
# THE FLOOR. 326 of the 704 are partly parsed (66 refused, 32 anchored, 228 no tracked path), so 149
# is a floor of unknown depth. By the PARTIAL site each set (a receipt can set several), from a
# tagged scratch copy over the same 704: an operand still holding `$`, `$( )` or `${..}` after
# resolution 184, `case` 130, a `git -<option>` (git -C) 116, an unresolved command word 10, a
# directory operand 3; backticks, heredocs and unbalanced quotes 0. The live 2 refuse 0.
DEFAULT_MAX_R10=0
# THE ONE SOURCE of the sh-receipt floor: `.githooks/pre-push` passes no --min-sh-receipts, so the
# gate and a bare run read this line. Lower it only with DEFAULT_MIN_ENTRIES, when entries rotate.
DEFAULT_MIN_SH=0
DEFAULT_MIN_ENTRIES=88

me() { printf 'validate-backlog-receipts'; }

# THE PROVENANCE CLAUSE, AND IT IS A CONTRACT WITH THIS ARM'S CALLERS. It appears on the OK
# line in both verbosities, including `--quiet`, because a caller asserting this arm ran needs
# a token that a program which SEEDS NOTHING cannot honestly print. The clause names the
# mechanism -- a detached checkout per receipt -- and it is emitted beside the count of
# receipts actually scored, so a heuristic that classifies receipts by reading their text
# cannot produce the pair. Callers may key on the exact string below; do not reword it
# without a matching change to whatever greps it.
PROVENANCE='detached checkout of HEAD'

# ===========================================================================
# WORKER MODE. One receipt, one process, dispatched by `xargs -P`. It is the SAME program
# rather than a second script so the scoring logic has exactly one implementation -- a
# hand-written second copy is a second implementation whose bugs nobody finds.
# ===========================================================================
vbr_worker() {
if [ "${1:-}" = "--score-one" ] || [ "${1:-}" = "--closed-one" ] || [ "${1:-}" = "--r13-one" ]; then
  WMODE="$1"
  REC="${2:-}"
  [ -n "$REC" ] || exit 2
  # THE COULD-NOT-MEASURE RULE IS THE CLASSIFIER'S, SOURCED, NEVER RESTATED. The parent resolved
  # the helper under its own root and refused if it was absent; a worker that cannot load it
  # writes no verdict, and the parent's every-receipt-produced-a-verdict assertion refuses the run.
  # SELF_NAME is the `$0` this worker `eval`s receipts under, which is what its prefix rule keys on.
  SELF_NAME="$0"
  # shellcheck source=backlog-receipt-lib.sh
  . "${BR_RECEIPT_LIB:-/nonexistent}" || exit 2
  # THE PARENT'S reconcile/lib.sh STATE IS REMOVED BEFORE ANY RECEIPT RUNS. The parent sources
  # lib.sh, which EXPORTS `AI_DLC_RECONCILE_MEMO`, and this worker inherits it through the
  # environment -- so every receipt below borrowed the parent's memo, and one driving a reconcile
  # script read a cached answer (backlog-reverify.sh's BL-382, the same defect). Functions do not
  # reach here: this is a fresh `bash`, and lib.sh's functions are not exported. The list is
  # derived in the parent (BR_LIB_VARS, see where lib.sh is sourced) and removed ONCE, here, so
  # every `eval` in this branch -- and any added later -- runs without it.
  # shellcheck disable=SC2086 # a space-joined list of variable names, split on purpose
  [ -n "${BR_LIB_VARS:-}" ] && unset $BR_LIB_VARS
  W="$BR_WORK"
  SR="$BR_SUBJECT_ROOT"
  n="$(basename "$REC")"
  LABEL=""; RECEIPT=""
  { IFS= read -r LABEL; IFS= read -r RECEIPT; } < "$REC"

  # EVERY WORKTREE THIS PROCESS REGISTERS IS REMOVED ON EVERY EXIT PATH. `git worktree add`
  # writes into the PARENT repository's administrative area, so an abandoned one outlives the
  # run and the directory it named is gone -- `git worktree list` then carries a prunable
  # stale entry per interrupted receipt. The trap covers the normal return, every `exit`
  # below, and an interrupt.
  # THE LIST OF TREES TO REMOVE IS A FILE, NOT A VARIABLE, and that is not a style choice.
  # `mktree` is called as `d="$(mktree a)"`, so everything it assigns happens in a SUBSHELL
  # and is lost the moment the substitution closes -- the trap then reads an empty list and
  # removes nothing, while every checkout stays registered in the parent repository.
  # Measured on this file's own first full run: 126 abandoned registrations, and the arm's
  # own final assertion is what reported it.
  BR_TREELIST="$W/t/$n.trees"
  : > "$BR_TREELIST"
  cleanup_trees() {
    while IFS= read -r _t; do
      [ -n "$_t" ] || continue
      git -C "$SR" worktree remove --force "$_t" >/dev/null 2>&1 || rm -rf "$_t"
    done < "$BR_TREELIST"
    : > "$BR_TREELIST"
  }
  trap cleanup_trees EXIT INT TERM

  # `git worktree add` TAKES A LOCK ON THE PARENT REPOSITORY, so under the pool it can lose a
  # race and exit non-zero with nothing wrong. A single attempt turns that into a BROKEN
  # verdict -- a refusal the caller reads as a harness failure -- for a receipt that is
  # perfectly scorable. Measured under 8-way dispatch: retries are rare and always succeed on
  # the second attempt. The retry is bounded so a genuinely broken repository still refuses
  # rather than spinning.
  # A CHECKOUT IS NOT USABLE BECAUSE `git worktree add` EXITED 0. Every receipt's verdict is a
  # statement about the tree it ran in, so a tree that is incomplete produces a verdict about
  # the checkout rather than about the receipt -- and the receipts most affected are exactly
  # the ones guarding their preconditions with `|| exit 9`, which is a silent reclassification
  # out of the population. The add is therefore followed by an assertion that the tree is
  # COMPLETE: git reports it clean, and a file known to be in HEAD is present and non-empty.
  # A tree that fails the assertion is discarded and re-added rather than used.
  tree_complete() { # tree_complete <dir>
    [ -d "$1" ] || return 1
    [ -e "$1/.git" ] || return 1
    [ -s "$1/$BR_SENTINEL" ] || return 1
    _tc="$(git -C "$1" status --porcelain 2>/dev/null | grep -c .)" || _tc=0
    [ "$_tc" -eq 0 ]
  }

  mktree() { # mktree <suffix> -> echoes a fresh detached worktree at HEAD, or empty
    _d="$W/t/$n.$1"
    _try=0
    while [ "$_try" -lt 5 ]; do
      rm -rf "$_d"
      if git -C "$SR" worktree add --detach -q "$_d" HEAD >/dev/null 2>&1; then
        if tree_complete "$_d"; then
          printf '%s\n' "$_d" >> "$BR_TREELIST"
          printf '%s' "$_d"
          return 0
        fi
        # Incomplete: unregister before retrying, or the registry fills with trees this
        # function has already abandoned.
        git -C "$SR" worktree remove --force "$_d" >/dev/null 2>&1 || rm -rf "$_d"
      fi
      _try=$(( _try + 1 ))
      sleep 1
    done
    return 1
  }

  wr() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$LABEL" "$2" "${3:-paths=}" "${4:-tokens=}" > "$W/out/$n"; }

  VERB="${RECEIPT%% *}"
  REST="${RECEIPT#* }"
  [ "$VERB" = "$RECEIPT" ] && REST=""

  # cm_reason <rc> <stderr-file> -> the FAIL-set member this exit is, or nothing. THE FAIL SET:
  # exit 9 (the receipt's own could-not-measure code, ledger legend), 126 (not executable), >=128
  # (a signal, or git's own refusal), and cant_measure's own-shell route (1/2/127 with the
  # receipt's OWN interpreter reporting a missing command, a missing sourced file or a syntax
  # error). NOT bare 127 and NOT 2-8: a subject that exits 127 because IT calls a helper it does
  # not ship, and the 2-8 codes, are real STILL-LIVE answers here (BL-830's receipt exits 2 open).
  # ONE function, so a mutant emptying the set is one edit.
  # THE FOURTH ROUTE, driver-absent (BL-899 M1): the receipt's own `bash <P>` operand is gone and
  # bash said so for THAT path; m1_driver_absent (the M1/R13 block) decides it with lead ruling L3
  # applied, in this worker, against the tree the receipt ran in ($TA).
  cm_reason() {
    case "$1" in
      9) printf 'exit-9' ;;
      126) printf 'exit-126' ;;
      *) if [ "$1" -ge 128 ]; then printf 'exit-%s' "$1"
         elif [ -n "$(cant_measure "$1" < "$2")" ]; then printf 'own-shell'
         else _cm_m1="$(m1_driver_absent "$1" "$2" "${TA:-}" "$REST")"
              case "$_cm_m1" in driver-absent/*) printf '%s' "$_cm_m1" ;; esac; fi ;;
    esac
  }

  # --- an R13 removal (BL-899): one NAMED path removed, the receipt run as above --------------
  [ "$WMODE" = "--r13-one" ] && { r13_remove_one; exit 0; }

  # --- a CLOSED-on-branch receipt: run once, expect exactly 0 -------------------------------
  # Its fix is claimed present by the close itself, so 0 is the only exit that agrees with the
  # entry; every other exit, FAIL set or not, is a row naming the id, the exit and the reason.
  if [ "$WMODE" = "--closed-one" ]; then
    KIND="$(sed -n '3p' "$REC")"
    cw() { printf '%s\t%s\t%s\t%s\n' "$1" "$LABEL" "$2" "$3" > "$W/cout/$n"; }
    if [ -z "$REST" ]; then cw CLOSED-FAIL "exit=none" "$KIND: an empty sh one-liner cannot confirm a close"; exit 0; fi
    if ! bash -n -c "{ $REST
}" >/dev/null 2>&1; then cw CLOSED-FAIL "exit=none" "$KIND: the receipt does not parse, so it never ran"; exit 0; fi
    TA="$(mktree a)"
    [ -n "$TA" ] || { cw BROKEN "exit=none" "no-closed-worktree"; exit 0; }
    ( cd "$TA" && eval "$REST" </dev/null ) >/dev/null 2>"$W/t/$n.err"
    C_RC=$?
    if [ "$C_RC" -eq 0 ]; then cw CLOSED-OK "exit=0" "$KIND"; exit 0; fi
    C_WHY="$(cant_measure "$C_RC" < "$W/t/$n.err")"
    C_CM="$(cm_reason "$C_RC" "$W/t/$n.err")"
    if [ -n "$C_CM" ]; then
      cw CLOSED-FAIL "exit=$C_RC" "$KIND: closed on this branch, and its receipt CANNOT MEASURE its subject ($C_CM${C_WHY:+: $C_WHY}) -- a close needs a receipt that reaches its question and exits 0"
    else
      cw CLOSED-FAIL "exit=$C_RC" "$KIND: closed on this branch, and its receipt still exits $C_RC -- the close says the fix is present, so the receipt must exit 0 (renamed or moved subject, or the fix is not there)"
    fi
    exit 0
  fi

  if [ -z "$REST" ]; then
    wr UNSCORABLE "empty-sh-one-liner"; exit 0
  fi

  # A RECEIPT THAT DOES NOT PARSE HAS NOT RUN, and its exit status says nothing about
  # anything. The brace wrap with its closer on a second line is the shape
  # scripts/backlog-reverify.sh already refuses on, and it is stricter than `eval`:
  # `eval 'true \'` returns 0 while this fails.
  SH_PROG="{ $REST
}"
  if ! bash -n -c "$SH_PROG" >/dev/null 2>&1; then
    wr UNSCORABLE "malformed-receipt-does-not-parse"; exit 0
  fi

  TA="$(mktree a)"
  [ -n "$TA" ] || { wr BROKEN "no-base-worktree"; exit 0; }

  # STDERR IS KEPT, NOT DISCARDED: cant_measure reads it to tell the receipt's own shell failing
  # (a missing helper, a missing sourced file, a syntax error) from the subject failing.
  # R13 (BL-899): with BR_R13_DIR set, this baseline run IS the trace -- closure and key first, the forced
  # epoch, the run, then the read set before anything else walks the tree. Unset, neither line does anything.
  # The traced run alone also carries r13_eval_env (core.trustctime=false, scoped to this subshell), because the
  # forced epoch moves every ctime and a git-refreshing receipt would otherwise re-read the whole tree.
  [ -n "${BR_R13_DIR:-}" ] && r13_pre "$TA"
  ( cd "$TA" && { [ -z "${BR_R13_DIR:-}" ] || r13_eval_env; } && eval "$REST" ) >/dev/null 2>"$W/t/$n.err"
  BASE_RC=$?
  [ -n "${BR_R13_DIR:-}" ] && r13_post "$TA"
  BASE_CM="$(cm_reason "$BASE_RC" "$W/t/$n.err")"
  # L3 (b): a driver absent at HEAD AND at --base is EXCLUDED, never a cannot-measure member, and the
  # row says so (`-excluded=driver-absent-at-base`) so R13 counts it separately.
  BASE_X=""
  [ -z "$BASE_CM" ] && [ "$(m1_driver_absent "$BASE_RC" "$W/t/$n.err" "$TA" "$REST")" = EXCLUDED-DRIVER-ABSENT-AT-BASE ] && BASE_X="-excluded=driver-absent-at-base"

  # --- what the receipt NAMES ---------------------------------------------------------
  # Split on every character a path cannot contain, so each candidate stands as its own word.
  # A path seen MID-TOKEN is not a path the receipt addresses.
  # A DIRECTORY IS NOT A SEEDABLE SUBJECT AND IS NOT A REFUSAL EITHER. The split leaves the
  # directory half of every glob standing as its own token -- `scripts/*.sh` yields
  # `scripts/` -- so treating a non-file as unseedable refuses most of the ledger for a
  # property of the SPLIT rather than of the receipt. The filter is `-f`.
  PATHS=""; NSEEDABLE=0; HAS_STRUCTURED=0
  for p in $(printf '%s\n' "$REST" | tr -c "$BR_PATH_CLASS" '\n' | sort -u); do
    case "$p" in */*) ;; *) continue ;; esac
    case "$p" in
      /*) continue ;;                       # absolute: not this tree's to seed
      *'*'*|*'?'*|*'$'*) continue ;;        # a glob or a variable names no one file
    esac
    [ -f "$TA/$p" ] || continue
    PATHS="$PATHS $p"; NSEEDABLE=$(( NSEEDABLE + 1 ))
    case "$p" in *.json|*.yaml|*.yml) HAS_STRUCTURED=1 ;; esac
  done

  # --- what the receipt GREPS ---------------------------------------------------------
  printf '%s\n' "$REST" > "$W/t/$n.receipt"
  TOKENS="$(awk -f "$BR_TOKAWK" "$W/t/$n.receipt")"
  NTOK="$(printf '%s\n' "$TOKENS" | grep -c .)" || NTOK=0

  PL="$(printf '%s' "$PATHS" | sed 's/^ //; s/ /,/g')"
  TL="$(printf '%s\n' "$TOKENS" | tr '\n' ' ' | sed 's/ *$//')"

  # Base exit decides the POPULATION, and it is read BEFORE anything is seeded. A receipt that
  # already exits 0 is not reproducing, and one that exits 9 or 128 is answering a question
  # about its own preconditions rather than about the fix.
  # THE TWO NON-1 BASE EXITS ARE DIFFERENT FINDINGS AND ARE NOT POOLED. A base of 0 is a
  # receipt whose fix is ALREADY PRESENT -- a close candidate awaiting the operator, which
  # backlog-reverify.sh already reports and which no one evades anything by producing. A base
  # of 9 or 128 is a receipt that never reached its question. Only the second is an escape
  # from R2, so only the second carries a ratchet; pooling them would make ordinary progress
  # on the ledger trip a gate built for an evasion.
  # A base of 9 or 128 is decided HERE, before any seed: the receipt never reached its
  # question, so there is nothing for a seed to move. A base of 0 is carried THROUGH the
  # seed instead -- its 0 -> 1 direction has to be observed for the report to be able to say
  # it was not counted, and a branch that exits before the seed cannot say that.
  # A NON-0/1 BASE IS RE-READ ONCE, IN A FRESH CHECKOUT, BEFORE IT IS CLASSIFIED. Measured
  # under three-way contention: one receipt moved BOUND -> OUT-OF-POPULATION on a single run
  # of thirty-three, taking R4 over its ceiling and failing the push by name -- a real push
  # failure produced by a receipt that is fine. Exit 9 and exit 128 are the shapes a receipt
  # uses to say "my preconditions were not met", so anything that perturbs the environment
  # lands there rather than in a verdict.
  #
  # THE RE-READ IS DIAGNOSTIC AND IS NOT A RETRY. A retry would take the second reading as the
  # answer and hide the disagreement -- and a receipt whose exit depends on when it ran is a
  # defect in the RECEIPT, not noise to be smoothed away. So the two readings are compared: if
  # they agree the verdict stands, and if they disagree the receipt is reported UNSTABLE with
  # both exits, counted under its own ratchet, and counted under nothing else.
  if [ "$BASE_RC" -ne 0 ] && [ "$BASE_RC" -ne 1 ]; then
    TR="$(mktree r)"
    if [ -z "$TR" ]; then
      wr BROKEN "no-reread-worktree"; exit 0
    fi
    ( cd "$TR" && eval "$REST" ) >/dev/null 2>&1
    REREAD_RC=$?
    if [ "$REREAD_RC" != "$BASE_RC" ]; then
      wr UNSTABLE "base-exit=$BASE_RC/$REREAD_RC" "paths=${PL:-none}" "tokens=${TL:-none}"; exit 0
    fi
    # A FAIL-SET EXIT STAYS OUT-OF-POPULATION AND CARRIES A MARKER. It is decided AFTER the re-read,
    # so a receipt that answers 9 then 1 is UNSTABLE, never cannot-measure; the parent counts the
    # marker under R7, whose ceiling is 0.
    wr OUT-OF-POPULATION "base-exit=$BASE_RC${BASE_CM:+-cannot-measure=$BASE_CM}$BASE_X" "paths=${PL:-none}" "tokens=${TL:-none}"; exit 0
  fi
  # THE OWN-SHELL ROUTE AT EXIT 1. A receipt whose own shell could not source its helper (`. missing.sh`
  # with no guard) exits 1, which is a reproduction's code; without this it would go on to be seeded
  # and scored as though it had measured something.
  if [ -n "$BASE_CM" ]; then
    wr OUT-OF-POPULATION "base-exit=$BASE_RC-cannot-measure=$BASE_CM" "paths=${PL:-none}" "tokens=${TL:-none}"; exit 0
  fi
  # L3 (b) AT EXIT 1 (`bash -e <never built>` exits 1): routed as at 127, so the exclusion is said, never lost.
  if [ -n "$BASE_X" ]; then
    wr OUT-OF-POPULATION "base-exit=$BASE_RC$BASE_X" "paths=${PL:-none}" "tokens=${TL:-none}"; exit 0
  fi

  # --- the DRIVER class -----------------------------------------------------------------
  # A one-liner that is nothing but `bash <repo-rel>.sh [plain args]`, optionally chained with
  # `&&`, greps nothing in the one-liner, so no comment in any file it names can satisfy it: the
  # SCRIPT is the subject. Classified by SHAPE, whatever the base exit (0 or 1 -- non-0/1 has
  # already left above), and only when EVERY script it runs is TRACKED in the checkout. A path
  # that is merely present on disk is not enough.
  DRV_PATHS="$(awk '{
    n = split($0, S, /&&/)
    out = ""
    for (i = 1; i <= n; i++) {
      s = S[i]; sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s)
      if (s !~ /^bash[ \t]+[A-Za-z0-9_.\/-]+\.sh([ \t]+[A-Za-z0-9_.=\/,:+-]+)*$/) exit 1
      p = s; sub(/^bash[ \t]+/, "", p); sub(/[ \t].*$/, "", p)
      if (p ~ /^\// || p ~ /(^|\/)\.\.(\/|$)/) exit 1
      out = out p "\n"
    }
    printf "%s", out
  }' <<<"$REST")" || DRV_PATHS=""
  if [ -n "$DRV_PATHS" ]; then
    DRV_OK=1
    while IFS= read -r _dp; do
      [ -n "$_dp" ] || continue
      git -C "$TA" ls-files --error-unmatch -- "$_dp" >/dev/null 2>&1 || { DRV_OK=0; break; }
    done <<EOF
$DRV_PATHS
EOF
    if [ "$DRV_OK" = "1" ]; then
      DL="$(printf '%s\n' "$DRV_PATHS" | tr '\n' ',' | sed 's/,*$//')"
      wr DRIVER "base-exit=$BASE_RC" "paths=$DL" "tokens=none"; exit 0
    fi
  fi

  if [ "$NTOK" -eq 0 ] || [ "$NSEEDABLE" -eq 0 ]; then
    wr UNSCORABLE "base-exit=$BASE_RC-paths=$NSEEDABLE-tokens=$NTOK" "paths=${PL:-none}" "tokens=${TL:-none}"; exit 0
  fi

  # --- seeding ------------------------------------------------------------------------
  # THE SEED LINE. `# ` plus the receipt's own literals: exactly what an author's comment
  # would carry, which is the whole finding. The generic line carries no token at all and is
  # the FORMAT control below.
  SEED_LINE="#"
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    SEED_LINE="$SEED_LINE $t"
  done <<EOF
$TOKENS
EOF
  GENERIC_LINE="# probe"

  # seed_tree <suffix> <line> -> echoes the tree, or empty on a refusal already reported
  seed_tree() {
    _st_d="$(mktree "$1")"
    if [ -z "$_st_d" ]; then wr BROKEN "no-seed-worktree"; return 1; fi
    for _p in $PATHS; do
      # EVERY MUTATION IS `cmp -s`-ASSERTED APPLIED. A seed that changed nothing is a no-op,
      # and its "no flip" is indistinguishable from a receipt that resisted it.
      cp "$_st_d/$_p" "$_st_d/$_p.brpre" 2>/dev/null || { wr BROKEN "cannot-snapshot:$_p"; return 1; }
      # The append runs in a SUBSHELL with stderr closed: a `>>` onto an unwritable path is
      # refused by the SHELL, not by the command, so `printf ... 2>/dev/null` does not silence
      # it and the diagnostic reaches the caller's stderr as though the arm had failed.
      ( printf '%s\n' "$2" >> "$_st_d/$_p" ) 2>/dev/null
      if cmp -s "$_st_d/$_p" "$_st_d/$_p.brpre"; then
        wr UNSEEDED "the-seed-did-not-change:$_p" "paths=${PL:-none}" "tokens=${TL:-none}"
        rm -f "$_st_d/$_p.brpre"
        return 1
      fi
      rm -f "$_st_d/$_p.brpre"
    done
    printf '%s' "$_st_d"
  }

  TB="$(seed_tree b "$SEED_LINE")" || exit 0
  ( cd "$TB" && eval "$REST" ) >/dev/null 2>&1
  SEED_RC=$?

  # THE DIRECTION IS PART OF THE FINDING. Only 1 -> 0 is a receipt a comment SATISFIES. A
  # 0 -> 1 receipt is one a comment BREAKS -- a different defect, whose remedy is unrelated --
  # and counting it here would inflate the ratchet with entries nobody can discharge.
  # A base of 0 is a receipt whose fix is ALREADY PRESENT -- a close candidate awaiting the
  # operator, which backlog-reverify.sh already reports and which nobody evades anything by
  # producing. It is reported under its own status rather than pooled with the exit-9 class,
  # because only that class is an escape from R2 and only that class carries a ratchet;
  # pooling them makes ordinary progress on the ledger trip a gate built for an evasion.
  if [ "$BASE_RC" != "1" ]; then
    wr ALREADY-PASSING "base-exit=$BASE_RC-seed-exit=$SEED_RC" "paths=${PL:-none}" "tokens=${TL:-none}"; exit 0
  fi
  if [ "$SEED_RC" != "0" ]; then
    wr BOUND "seed-exit=$SEED_RC" "paths=${PL:-none}" "tokens=${TL:-none}"; exit 0
  fi

  # --- the FORMAT control -------------------------------------------------------------
  # It runs only on a flip whose seeded set touches a structured file, because that is the
  # only case where it can change an answer, and a control run on every receipt would double
  # the arm's cost to establish something already known about a plain-text file.
  if [ "$HAS_STRUCTURED" = "1" ]; then
    TC="$(seed_tree c "$GENERIC_LINE")" || exit 0
    ( cd "$TC" && eval "$REST" ) >/dev/null 2>&1
    CTRL_RC=$?
    if [ "$CTRL_RC" = "0" ]; then
      wr FORMAT-SENSITIVE "flips-on-a-line-carrying-NO-token-so-the-format-broke-not-the-binding" "paths=${PL:-none}" "tokens=${TL:-none}"
      exit 0
    fi
  fi

  wr PROSE-CLOSABLE "seed-exit=0" "paths=${PL:-none}" "tokens=${TL:-none}"
  exit 0
fi
}

# ===========================================================================
# PARENT MODE
# ===========================================================================
vbr_sec_args() {
QUIET=0; LEDGER=""; ROOT_ARG=""; EFF_MODE=""; BASE_REF="origin/main"; BASE_GIVEN=0
MAX_PC=""; MAX_UNSC=""; MAX_OOP=""; MAX_UNSTABLE=""; MIN_SH=""; MIN_ENTRIES=""; MAX_CM=""; MAX_R10=""; MAX_R13=""; R13_OPT=0; R13_DRIVE=""
usage() { echo "usage: validate-backlog-receipts.sh [<ledger>] [--archive | --efficiency-only] [--root <dir>] [--base <ref>] [--quiet] [--max-prose-closable N] [--max-unscorable N] [--max-out-of-population N] [--max-cannot-measure N] [--max-unanchored N] [--traced-removal] [--max-unguarded N] [--min-sh-receipts N] [--min-entries N]" >&2; }
while [ "$#" -gt 0 ]; do
  case "$1" in
    --quiet) QUIET=1; shift ;;
    --archive) EFF_MODE=archive; shift ;;
    --efficiency-only) EFF_MODE=live; shift ;;
    --root) ROOT_ARG="${2:-}"; shift 2 ;;
    --max-prose-closable) MAX_PC="${2:-}"; shift 2 ;;
    --max-unscorable) MAX_UNSC="${2:-}"; shift 2 ;;
    --max-out-of-population) MAX_OOP="${2:-}"; shift 2 ;;
    --max-unstable) MAX_UNSTABLE="${2:-}"; shift 2 ;;
    --max-cannot-measure) MAX_CM="${2:-}"; shift 2 ;;
    --max-unanchored) MAX_R10="${2:-}"; shift 2 ;;
    --traced-removal) R13_OPT=1; shift ;;
    --r13-drive) [ "$#" -ge 2 ] || { usage; exit 2; }; R13_DRIVE="$2"; shift 2 ;;
    --max-unguarded) MAX_R13="${2:-}"; shift 2 ;;
    --base) BASE_REF="${2:-}"; BASE_GIVEN=1; shift 2 ;;
    --min-sh-receipts) MIN_SH="${2:-}"; shift 2 ;;
    --min-entries) MIN_ENTRIES="${2:-}"; shift 2 ;;
    -*) usage; exit 2 ;;
    *)  LEDGER="$1"; shift ;;
  esac
done
}

vbr_sec_setup() {
# Resolve THIS script's own root by walking UP for a marker, never by counting `..` hops -- a
# validator that counts hops answers differently from the repo root, from a subdirectory, and
# from a fixture sandbox that copied it, and the sandbox answer is the silent one.
# THE SELF PATH IS THIS FILE'S OWN, READ FROM BASH_SOURCE, which equals `$0` on every CLI run and,
# inside a function, names the file that DEFINED the function -- so a fixture that sourced a copy of
# this file and calls vbr_main gets that copy's root, siblings and workers, exactly as the CLI would.
_vbr_self="${BASH_SOURCE[0]}"
SELF_ROOT="$(cd "$(dirname "$_vbr_self")" && pwd)"
while [ "$SELF_ROOT" != "/" ] && [ ! -f "$SELF_ROOT/VERSION" ]; do SELF_ROOT="$(dirname "$SELF_ROOT")"; done
[ -f "$SELF_ROOT/VERSION" ] || { echo "$(me): FAIL -- no VERSION marker above $_vbr_self" >&2; exit 2; }
SELF="$(cd "$(dirname "$_vbr_self")" && pwd)/$(basename "$_vbr_self")"

LIB="$SELF_ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
[ -f "$LIB" ] || { echo "$(me): FAIL -- reconcile/lib.sh missing; refusing to fall back to a private copy of the entry-boundary rule" >&2; exit 2; }
# The could-not-measure rule, shared with backlog-reverify.sh. Every worker sources it by this path.
BR_RECEIPT_LIB="$SELF_ROOT/scripts/backlog-receipt-lib.sh"
[ -f "$BR_RECEIPT_LIB" ] || { echo "$(me): FAIL -- scripts/backlog-receipt-lib.sh missing; refusing to fall back to a private copy of the could-not-measure rule" >&2; exit 2; }
export BR_RECEIPT_LIB
# WHAT lib.sh EXPORTS IS DERIVED, NOT LISTED, SO A RECEIPT CAN BE RUN WITHOUT IT. The same shape
# as scripts/backlog-reverify.sh's BL-382 fix, duplicated rather than shared: the two files source
# lib.sh for its entry grammar and share no helper file of their own. The set is the EXPORTED
# names new after the source, because only those reach a worker; `AI_DLC_RECONCILE_MEMO` is ALSO
# named outright, because a CALLER that already exported one puts it in the BEFORE snapshot, where
# a diff alone would never remove it. The worker unsets the list on entry.
_br_added() { # <before> <after> -- the names in <after> absent from <before>, space-joined
  printf '%s\n--\n%s\n' "$1" "$2" | awk '/^--$/ { p = 1; next } !p { s[$0] = 1; next } !($0 in s) { printf "%s ", $0 }'
}
_br_pre_e="$(compgen -e)"
# shellcheck source=../core/skills/ai-dlc-update/reconcile/lib.sh
. "$LIB" || { echo "$(me): FAIL -- cannot source $LIB" >&2; exit 2; }
BR_LIB_VARS="AI_DLC_RECONCILE_MEMO $(_br_added "$_br_pre_e" "$(compgen -e)")"
unset _br_pre_e

DEFAULTED=0
if [ -z "$LEDGER" ] && [ "$EFF_MODE" = "archive" ]; then LEDGER="$SELF_ROOT/docs/backlog.archive.md"; DEFAULTED=1; fi
[ -n "$LEDGER" ] || { LEDGER="$SELF_ROOT/docs/backlog.md"; DEFAULTED=1; }
[ -f "$LEDGER" ] || { echo "$(me): FAIL -- $LEDGER is not a file" >&2; exit 2; }

# THE SUBJECT ROOT FOLLOWS THE LEDGER, NOT THIS SCRIPT. A receipt is written against the tree
# its ledger describes, and this arm is driven against ledgers outside this repository. Walk
# up from the LEDGER for a repository; `--root` overrides.
if [ -n "$ROOT_ARG" ]; then
  SUBJECT_ROOT="$(cd "$ROOT_ARG" 2>/dev/null && pwd)" || SUBJECT_ROOT=""
  [ -n "$SUBJECT_ROOT" ] || { echo "$(me): FAIL -- --root '$ROOT_ARG' is not a directory" >&2; exit 2; }
else
  SUBJECT_ROOT="$(cd "$(dirname "$LEDGER")" && pwd)"
  while [ "$SUBJECT_ROOT" != "/" ] && [ ! -e "$SUBJECT_ROOT/.git" ]; do SUBJECT_ROOT="$(dirname "$SUBJECT_ROOT")"; done
fi
if ! git -C "$SUBJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  echo "$(me): FAIL -- no git repository at or above $LEDGER (looked at '$SUBJECT_ROOT'). Every receipt runs in a checkout of that repository's HEAD; a receipt run in a tree with no .git answers a question about its own preconditions, which reads as a verdict. Pass --root <dir>." >&2
  exit 2
fi
git -C "$SUBJECT_ROOT" rev-parse HEAD >/dev/null 2>&1 || {
  echo "$(me): FAIL -- $SUBJECT_ROOT has no HEAD commit, so no checkout can be made." >&2; exit 2; }

num_or_die() { # num_or_die <value> <name>
  case "$1" in ''|*[!0-9]*) echo "$(me): FAIL -- $2 is not a non-negative integer: '$1'" >&2; exit 2 ;; esac
}
[ -n "$MAX_PC" ]      || MAX_PC="${AI_DLC_BACKLOG_MAX_PROSE_CLOSABLE:-$DEFAULT_MAX_PC}"
[ -n "$MAX_UNSC" ]    || MAX_UNSC="${AI_DLC_BACKLOG_MAX_UNSCORABLE:-$DEFAULT_MAX_UNSC}"
[ -n "$MAX_OOP" ]     || MAX_OOP="${AI_DLC_BACKLOG_MAX_OUT_OF_POPULATION:-$DEFAULT_MAX_OOP}"
[ -n "$MAX_UNSTABLE" ] || MAX_UNSTABLE="${AI_DLC_BACKLOG_MAX_UNSTABLE:-$DEFAULT_MAX_UNSTABLE}"
[ -n "$MIN_SH" ]      || MIN_SH="${AI_DLC_BACKLOG_MIN_SH_RECEIPTS:-$DEFAULT_MIN_SH}"
[ -n "$MIN_ENTRIES" ] || MIN_ENTRIES="${AI_DLC_BACKLOG_MIN_ENTRIES:-$DEFAULT_MIN_ENTRIES}"
[ -n "$MAX_CM" ]      || MAX_CM="${AI_DLC_BACKLOG_MAX_CANNOT_MEASURE:-$DEFAULT_MAX_CM}"
num_or_die "$MAX_CM" --max-cannot-measure
[ -n "$MAX_R10" ]     || MAX_R10="${AI_DLC_BACKLOG_MAX_UNANCHORED:-$DEFAULT_MAX_R10}"
num_or_die "$MAX_R10" --max-unanchored
[ -n "$MAX_R13" ]     || MAX_R13="${AI_DLC_BACKLOG_MAX_UNGUARDED:-$DEFAULT_MAX_R13}"
num_or_die "$MAX_R13" --max-unguarded
[ -n "$BASE_REF" ] || { echo "$(me): FAIL -- --base needs a ref" >&2; exit 2; }
m1_base_check
# RE-ENTRY. A receipt that invokes `.githooks/pre-push` (dozens of archive receipts do, directly
# or as `git push`) re-enters this validator from inside the run executing it, whose population at
# that tree is the same one, so it would recurse without end. Both receipt executors -- score_ledger
# (the OPEN receipts R2-R7 judge) and score_closed (R8) -- export BR_RECEIPTS_RUNNING to every
# receipt. A run that finds it set ON ENTRY still runs the efficiency arms, but
# executes no corpus receipt: it prints `OPEN-POPULATION: SKIPPED` and `CLOSED-POPULATION: SKIPPED`
# and exits on the efficiency verdict alone. The outer run executes every receipt once. The name
# carries no `AI_DLC_` prefix because fixtures strip that prefix from their environment.
# hermetic-run.sh's `env -i` drops it as well, and that path cannot reach this validator: no
# fixture sandbox that declares the hook also declares this validator.
# THE VALUE IS THE LEDGER'S IDENTITY, AND ONLY A RUN OVER THE SAME LEDGER SKIPS. Presence alone
# made every receipt that drives this validator on a ledger of its OWN seeding skip R2-R8 silently
# (BL-227's archived receipt exits 0 unset and 1 set). The key is the subject repository's git
# COMMON dir, physically resolved, plus the ledger's path relative to the subject root. Not the
# ledger's absolute path: every receipt runs in a `git worktree add` checkout, so a pre-push that
# re-enters from one resolves `<checkout>/docs/backlog.md`, which is never the outer path, while
# the common dir is shared by every worktree of one repository.
ledger_key() { # ledger_key <ledger> <subject-root> -> "<common-dir>|<ledger relative to root>"
  _lk_root="$(cd "$2" 2>/dev/null && pwd -P)" || return 1
  _lk_dir="$(cd "$(dirname "$1")" 2>/dev/null && pwd -P)" || return 1
  _lk_led="$_lk_dir/$(basename "$1")"
  case "$_lk_led" in "$_lk_root"/*) _lk_led="${_lk_led#"$_lk_root"/}" ;; esac
  _lk_cd="$(git -C "$_lk_root" rev-parse --git-common-dir 2>/dev/null)" || return 1
  case "$_lk_cd" in /*) ;; *) _lk_cd="$_lk_root/$_lk_cd" ;; esac
  _lk_cd="$(cd "$_lk_cd" 2>/dev/null && pwd -P)" || return 1
  printf '%s|%s' "$_lk_cd" "$_lk_led"
}
LEDGER_KEY="$(ledger_key "$LEDGER" "$SUBJECT_ROOT")" || { echo "$(me): FAIL -- could not resolve the ledger's identity for the re-entry guard." >&2; exit 2; }
# re_entry_of <inherited sentinel> <this run's key> -> 1 when this run is a re-entry, else nothing.
re_entry_of() {
  [ -n "$1" ] && [ "$1" = "$2" ] && printf '1'
  return 0
}
RE_ENTRY="$(re_entry_of "${BR_RECEIPTS_RUNNING:-}" "$LEDGER_KEY")"
R8_SKIP=0
num_or_die "$MAX_PC" --max-prose-closable
num_or_die "$MAX_UNSC" --max-unscorable
num_or_die "$MAX_OOP" --max-out-of-population
num_or_die "$MAX_UNSTABLE" --max-unstable
num_or_die "$MIN_SH" --min-sh-receipts
num_or_die "$MIN_ENTRIES" --min-entries

JOBS="${AI_DLC_BACKLOG_RECEIPT_JOBS:-8}"
case "$JOBS" in ''|*[!0-9]*|0) JOBS=8 ;; esac

WORK="$(mktemp -d)" || { echo "$(me): FAIL -- mktemp -d" >&2; exit 2; }

# THE PARENT'S OWN CLEANUP. A worker's trap removes its own trees; this catches a worker the
# pool killed before its trap ran, and it fires on an interrupt of the parent too.
parent_cleanup_trees() {
  r9_reap   # R9's background classifier (r9_start), when r9_run never waited for it

  if [ -d "$WORK/t" ] || [ -d "$WORK/t9" ]; then
    for _d in "$WORK"/t/* "$WORK"/t9/*; do
      [ -e "$_d/.git" ] || continue
      git -C "$SUBJECT_ROOT" worktree remove --force "$_d" >/dev/null 2>&1 || rm -rf "$_d"
    done
  fi
  # `prune` is what clears a registration whose directory is already gone -- a worker the
  # pool killed leaves exactly that, and `worktree remove` cannot see it to remove it.
  git -C "$SUBJECT_ROOT" worktree prune >/dev/null 2>&1 || true
}
parent_cleanup() { parent_cleanup_trees; rm -rf "$WORK"; }
# r9_reap [kill]: an exit WAITS for R9's background job, so a run that stops before r9_run makes the same starts on
# every run; only an interrupt (r9_start's INT/TERM trap) kills it, by its recorded process group.
r9_reap() {
  [ -n "${R9_PID:-}" ] || return 0
  [ "${1:-}" = kill ] && kill -TERM -- "-$R9_PID" 2>/dev/null
  wait "$R9_PID" 2>/dev/null; R9_PID=""
}
trap parent_cleanup EXIT INT TERM
# A RESTRICTED RUN IS NEVER A GATE PASS (lead ruling, batch 256). Given --r13-drive or BR_R13_PROBE_DIR
# (which moves the instrument probe off the checkouts' filesystem), the run is restricted, so every exit
# after this line leaves through this trap: a verdict of 0 or 1 leaves as 3, a refusal stays 2, and the verdict it
# would have given is printed as `RESTRICTED: verdict-rc=<n>`. A refusal BEFORE this line (an argument or setup error)
# exits 2 without the RESTRICTED line. No path of a restricted run exits 0.
vbr_restricted_exit() {
  local _rc=$?
  parent_cleanup
  echo "RESTRICTED: verdict-rc=$_rc -- this run was restricted and is never a gate pass"
  case "$_rc" in 0|1) exit 3 ;; *) exit "$_rc" ;; esac
}
[ -n "$R13_DRIVE${BR_R13_PROBE_DIR:-}" ] && trap vbr_restricted_exit EXIT
mkdir -p "$WORK/out" "$WORK/rec" "$WORK/t"

# ---------------------------------------------------------------------------
# THE CALLER'S TREE IS NEVER TOUCHED, AND THAT IS ASSERTED RATHER THAN INTENDED. A seed that
# escapes into the repository is the one failure of this arm that costs more than a wrong
# verdict. The worktree count is read the same way, and for the same reason.
# ---------------------------------------------------------------------------
porcelain_count() { git -C "$SUBJECT_ROOT" status --porcelain 2>/dev/null | grep -c . ; }
# THE REGISTRY IS ASKED ABOUT THIS RUN'S OWN CHECKOUTS, NEVER ABOUT ITS TOTAL SIZE. A count
# over the whole registry is a count over a SHARED resource: the gate, another agent's
# worktree, or a second copy of this arm can add or remove one mid-run, and the difference
# then reports a leak that did not happen while the verdict beside it is correct. Measured on
# two concurrent runs: identical SUMMARY lines, exit 2 and exit 0. Every checkout this run
# makes lives under $WORK, which mktemp guarantees is unique to the process, so the question
# with an answer is whether any path under THAT prefix is still registered.
own_registered() { git -C "$SUBJECT_ROOT" worktree list 2>/dev/null | awk -v p="$WORK/" 'index($1, p) == 1' | grep -c . ; }
PORC_BEFORE="$(porcelain_count)" || PORC_BEFORE=0
# Asserted rather than assumed: `$WORK` is fresh from mktemp, so nothing under it can already
# be registered. A non-zero reading here means the prefix is not unique to this run and the
# arm's own leak check would be measuring another process's checkouts.
WT_OWN_BEFORE="$(own_registered)" || WT_OWN_BEFORE=0
if [ "$WT_OWN_BEFORE" -ne 0 ]; then
  echo "$(me): FAIL -- $WT_OWN_BEFORE checkout(s) are already registered under this run's own working directory $WORK, which mktemp just created. The prefix is not unique to this process, so the leak check below would answer about somebody else's checkouts." >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# The grep-literal grammar, defined ONCE.
#
# It walks the receipt character by character keeping quote state, so a token is classified by
# HOW it was written: wholly single-quoted (a literal), wholly double-quoted (a literal only
# when it carries no `$` and no backtick -- otherwise the shell, not this grammar, decides what
# it says), bare, or mixed. Only the first two are seedable. None of this is passed through
# `awk -v`, which strips one level of escaping and would make a correct site look wrong.
# ---------------------------------------------------------------------------
TOKAWK="$WORK/tok.awk"
cat <<'AWK' > "$TOKAWK"
function clean(s) { sub(/^\^/, "", s); sub(/\$$/, "", s); return s }
function addkind(k) { if (kind == "") kind = k; else if (kind != k) kind = "m" }
function flush() {
  if (tok != "" || kind != "") { nt++; T[nt] = tok; K[nt] = kind }
  tok = ""; kind = ""
}
function emitpat(idx,   s) {
  if (K[idx] == "s") { s = clean(T[idx]); if (s != "" && !(s in SEEN)) { SEEN[s] = 1; print s }; return }
  if (K[idx] == "d") {
    # A double-quoted pattern is a literal only when the SHELL would not rewrite it. A `$`
    # or a backtick means the text this arm can see is not the text grep receives.
    if (T[idx] ~ /\$/) return
    if (T[idx] ~ /`/) return
    s = clean(T[idx]); if (s != "" && !(s in SEEN)) { SEEN[s] = 1; print s }
  }
}
{
  # A COMMAND SUBSTITUTION IS SCANNED AS CODE, NOT SWALLOWED AS TEXT, and that is the whole
  # reason this is a state machine rather than a split. `n="$(grep -c 'tok' "$V")"` is ONE
  # shell word, so a scanner that splits on whitespace never sees a word equal to `grep` and
  # scores the receipt as carrying no pattern -- silently, and for the commonest spelling in
  # this ledger. Measured while building this arm: of the receipts this file reports, that
  # reading found a literal in 36 where a word-split found none.
  line = $0; n = length(line); i = 1; nt = 0
  tok = ""; kind = ""; dq = 0; depth = 0
  while (i <= n) {
    c = substr(line, i, 1)
    if (c == "\\") { tok = tok substr(line, i + 1, 1); addkind(dq ? "d" : "b"); i = i + 2; continue }
    if (c == "'" && dq == 0) {
      rest = substr(line, i + 1); j = index(rest, "'")
      if (j == 0) { addkind("m"); i = n + 1; continue }
      tok = tok substr(rest, 1, j - 1); addkind("s"); i = i + j + 1; continue
    }
    if (c == "\"") { dq = 1 - dq; i++; continue }
    if (c == "$" && substr(line, i + 1, 1) == "(") {
      flush(); depth++; DQ[depth] = dq; dq = 0; i = i + 2; continue
    }
    if (c == ")" && dq == 0 && depth > 0) { flush(); dq = DQ[depth]; depth--; i++; continue }
    if (dq == 0 && (c == " " || c == "\t")) { flush(); i++; continue }
    if (dq == 0 && (c == ";" || c == "|" || c == "&" || c == "(" || c == ")" || c == "{" || c == "}")) { flush(); i++; continue }
    tok = tok c; addkind(dq ? "d" : "b"); i++
  }
  flush()

  for (p = 1; p <= nt; p++) {
    if (K[p] != "b") continue
    w = T[p]
    if (w != "grep" && w != "egrep" && w != "fgrep" && w !~ /\/e?grep$/) continue
    q = p + 1
    while (q <= nt) {
      if (K[q] == "b") {
        b = T[q]
        if (b == "--") { q++; continue }
        # `grep -f <file>` reads its patterns from a file this grammar cannot open, and
        # everything after it is an argument, not a pattern.
        if (b == "-f" || b ~ /^-[a-zA-Z]*f$/) break
        if (b == "-e" || b ~ /^-[a-zA-Z]*e$/) { q++; if (q <= nt) emitpat(q); break }
        if (b ~ /^-/) { q++; continue }
        break
      }
      emitpat(q); break
    }
  }
}
AWK

# ---------------------------------------------------------------------------
# The ledger parser. The BOUNDARY and the LABEL come from reconcile/lib.sh; only the receipt
# and the close-annotation reading are local, and both are this file's own business.
#
# The awk program is built OUTSIDE a command substitution, deliberately: bash 3.2's `$( )`
# parser counts parentheses across a heredoc body and does not exempt it. See
# backlog-reverify.sh:87.
# ---------------------------------------------------------------------------
AWKF="$WORK/ledger.awk"
{ ledger_entry_awk; backlog_entry_label_awk; cat <<'AWK'
function flush(   r) {
  if (label == "") return
  r = receipt; if (r == "") r = "@NONE@"
  printf "%s\t%d\t%s\n", label, closed, r
  label = ""; closed = 0; receipt = ""
}
{
  lbl = backlog_entry_label($0)
  if (lbl != "") { flush(); label = lbl; next }
  if (label == "") next
  if ($0 ~ /^(<br>)?\*\*LANDED \(v/) closed = 1
  if ($0 ~ /^[ \t]*verify:/ && receipt == "") {
    r = $0; sub(/^[ \t]*verify:[ \t]*/, "", r); receipt = r
  }
}
END { flush() }
AWK
} > "$AWKF"

# ---------------------------------------------------------------------------
# R0 -- THE PATH-SPLIT CLASS IS THE CONSUMER ENGINE'S, EXTRACTED AT RUN TIME.
# A drift in either copy is silent in both directions at once, so the two spellings are
# compared as strings rather than trusted.
#
# THE EXTRACTION IS ANCHORED ON THE FUNCTION NAME, NOT ON THE BRACKET CLASS. A near-miss of
# the same class sits in scripts/validate-enforcement-map.sh, so a grammar keyed on the class
# alone resolves whichever file it is pointed at and reads as a binding while binding nothing.
# ---------------------------------------------------------------------------
class_of() { # class_of <file> -> the class inside <CLASS_FUNC>()'s `tr -c`
  sed -n "s/^${CLASS_FUNC}().*tr -c '\\(.*\\)' '.*/\\1/p" "$1" 2>/dev/null | sed -n '1p'
}
}

vbr_sec_r0() {
R0_SRC="$SELF_ROOT/$CLASS_SOURCE"
if [ ! -f "$R0_SRC" ]; then
  echo "$(me): FAIL -- R0: $CLASS_SOURCE is absent, so the path-split class cannot be bound to its other copy. This refuses rather than scoring a corpus with an unbound grammar." >&2; exit 2
fi
R0_THEIRS="$(class_of "$R0_SRC")"
if [ -z "$R0_THEIRS" ]; then
  echo "$(me): FAIL -- R0: ${CLASS_FUNC}()'s \`tr -c\` class could not be read out of $CLASS_SOURCE. The extractor found the file and not the line, which is a moved subject, not a clean binding." >&2; exit 2
fi
if [ "$R0_THEIRS" != "$PATH_CLASS" ]; then
  echo "$(me): FAIL -- R0: the path-split class has DRIFTED. This file carries '$PATH_CLASS'; ${CLASS_FUNC}() in $CLASS_SOURCE carries '$R0_THEIRS'. That function's own header calls a second copy 'a second chance for the two to drift, and a drift here is silent in both directions at once'. Change the class in ONE place and re-run." >&2; exit 2
fi

# ===========================================================================
# E -- THE EFFICIENCY ARMS (BL-817). A receipt proves a mechanism shipped; for an efficiency
# entry the OUTCOME is the claim, and the ranked set of 19 closed on tree receipts while per-story
# cost over graph s317-s319 never moved. Three arms, one entry scanner:
#
#   E1 CLOSE (live ledger and, via --archive, docs/backlog.archive.md). Population: an entry
#      annotated `**LANDED (v<digit>` that carries a bold efficiency tag, or that carries an
#      `Outcome measured:` line at all. The tag is any of four forms, `**DEFECT (efficiency).**`,
#      `**DEFECT, efficiency.**`, `**NOTE (efficiency).**` and `**DEFECT. [efficiency rank N] ...**`,
#      decided by backlog_efficiency_tagged() in reconcile/lib.sh -- the one predicate
#      backlog-rotate.sh's outcome guard also reads (BL-835); bold prose carrying the word is not
#      a tag. The same predicate sets E3's tagged population. TAG-ONLY by the lead's ruling: an untagged
#      entry is not judged here by reading what it cites -- E3 closes that escape at FILING. It
#      fires on: no outcome line (NO-OUTCOME); a line naming no sprint (NO-SPRINT); a line stating
#      no direction (NO-DIRECTION); a figure that did not fall with no value citation that
#      resolves (NO-VALUE-CITATION). A value citation is `path:line "quoted phrase"`, RESOLVED BY
#      THE PHRASE: some line of that file carries the phrase AND is a `Failure caught:` line or a
#      table row. The line number is a pointer for the reader and is not what binds, because step
#      files move. A seat figure's PRESENCE is required (E2); its VALUE never is, and no
#      threshold is applied to any number. ONE comparison is (BL-1031): a live `Verdict: <group>
#      fell` is held to its own before and after figures, which must fall (FELL-ROSE otherwise,
#      eff_fell_ok); a `fell` whose figures cannot be read needs the value citation a `did not
#      fall` owes (NO-VALUE-CITATION).
#      ONE ISOLATED BRANCH, eff_nostep_ok, accepts a SPRINTLESS line, and only when it says there
#      is no graph pipeline step AND names where the cost lives (operator ruling). It is one
#      function so a mutant widening it is one edit.
#   E2 SHAPE (D6). A sprint-naming outcome line carries the token-equivalent basis, the API figure
#      beside it, and the gap-inclusive hours label (operator ruling), AND a figure for each SEAT:
#      the lead and the subagents reported separately, each seat word followed by an hours
#      (`<n> h`) or dollar (`$<n>`) figure as the first number after it (eff_seat_ok, BL-817's
#      batch-243 amendment). Not applied to the no-step branch: a line saying there is no step has
#      no figure to label. The same line also names its MEASURING SCRIPT (NO-SCRIPT, eff_script_ok)
#      and gives a BEFORE and an AFTER figure (NO-FIGURES, eff_figs_ok) -- BL-817 item 1's remainder.
#   E3b FILING SHAPE (live ledger only, entries ADDED since the merge-base with origin/main; SKIP
#      with the reason in the OK line when origin/main is absent). A tagged entry not on the no-step
#      branch carries `Baseline: s3NN` (F-BASELINE), `Step: <token>` from the extractor's step set
#      (F-STEP, eff_step_ok) and a non-empty `Expected movement:` (F-MOVEMENT) -- BL-817 item 2.
#   E3 FILING (live ledger only). A tagged entry CITES the step-value ruling -- the phrase "A step
#      with no measured value goes" and `.claude/rules/operator-rulings.md`, both, read over the
#      whitespace-collapsed entry so a wrapped phrase still counts (F-RULING). An entry citing
#      `docs/analysis/` with neither the tag nor the "no graph pipeline step" line is refused
#      (F-UNTAGGED): that is the untagged-filing escape the tag-only E1 would otherwise leave open.
#      The ruling is matched as TEXT and never resolved on disk, so this arm adds no read.
#
#   E3c F-TARGET (live ledger only) -- the operator ruling "no target number on an efficiency goal"
#      (`.claude/rules/operator-rulings.md`). Population: a TAGGED entry not on the no-step branch
#      that was ADDED since the merge-base with origin/main OR whose `Expected movement:` line
#      differs from, or is absent at, the merge-base (eff_added_labels writes that set beside the
#      added set, `.mvchg`). An unchanged entry is never re-judged, so the existing corpus cannot
#      wedge a push; no origin/main, no set, no verdict. It fires on either of two spellings:
#        (1) the `Expected movement:` line states a comparator then a figure: `at or below`, `at or
#            under`, `at most`, `no more than`, `or less`, `or below`, `under`, `below`, or `<=`,
#            then optional `$` and a digit. The motivating case is BL-1175 at f4c9810a1: "planning
#            less operator wait at or below 15 h" (removed by c9743e6e5).
#        (2) anywhere in the entry text, `target` or `target number`, optionally `of|is|was|at|for`,
#            then `: ` or spaces, an optional `~ < >` or `$`, and a digit.
#      The text for (2) is first scrubbed of `no target [number]` and `not a target`, so BL-878's "No
#      target number (operator ruling, batch 259)" and BL-972's "not a target: 26 to 29 questions"
#      stay quiet. A `^Target:` field-label arm was rejected: its count is 0 in both ledgers against
#      15 for `^Baseline:`, so it could not fire.
#      FALSE-POSITIVE SET, MEASURED with the shipping entry awk over EVERY entry, scope ignored
#      (live 55 entries, 38 tagged, 15 carrying `Expected movement:`; archive 1084, 40 tagged, 5
#      carrying it): live 2 -- BL-975 and BL-1166, tagged, both `Expected movement:` lines describe
#      a mechanism ("the fix removes the share of ...", "a beat names a dispatched agent ...") and
#      carry `under`/`below`/`at most` before a digit; archive 1 -- BL-272, UNTAGGED (a migration
#      target), outside the population. All three are excluded by the scope above; the narrowing
#      that reached zero is that scope, not the regex, and a probe seeds a base-resident
#      offender that stays quiet. The first spelling of (2) hit BL-972 on its disclaimer; the
#      `not a target` scrub took it to 0. Case is matched as written, so `NO-TARGET` never matches.
#      WHAT IT CANNOT SEE: a target spelled with neither a comparator nor the word (`reduce to
#      30%`, `aim for`). No DEFAULT_* ceiling or count is added.
#      THE OTHER RULING, "one backlog entry per goal", IS NOT AN ARM HERE. Whether an entry is a
#      sibling finding of an open goal cannot be decided from its text. Its shape half (a numbered
#      work list and exactly one `Done condition` / `Close condition`) was measured and is not
#      FP-clean: of 55 live entries only BL-878 carries a labelled condition line at all, and it
#      carries two; 19 carry a numbered list, so a whole-ledger arm wedges on BL-878 and a
#      filing-scope arm requiring the label refuses 18 of 19 existing spellings (BL-1178 states its
#      done condition unlabelled).
#
# THE NARROWING, AND ITS MEASUREMENT. The receipt parser above lets an entry run to the next BL-
# label, so a `## Section` preamble between two entries is read as the body of the entry above it.
# Measured on the live ledger before this arm: E3 named exactly ONE entry, BL-807 (later BL-806
# after a rebase) -- whose own text cites nothing under docs/analysis/; the hit was the "Efficiency
# regression after the ranked set" section preamble below it. In THESE arms only, a column-0 `##`
# heading carrying no BL- label closes the entry (the shape helper decides it, so a fenced `##`
# line does not). After it the live FP set is 0. Controls in the same measurement: the six tagged
# citers (BL-538/810/811/812/817/819) all read as citing. The receipt parser is left alone --
# changing what it calls an entry body moves receipts, which is not this arm's business.
# F-RULING's FP set before the ledger amendment: 9 named tagged entries (538, 584, 616, 695, 804,
# 808, 809, 811, 812), each fixed in the ledger in the same release; no narrowing was needed.
#
# --archive and --efficiency-only run these arms only, and exit before the
# per-receipt checkout scorer, which costs a checkout per receipt and has nothing to say here.
# ===========================================================================
EFFAWK="$WORK/eff.awk"
{ ledger_entry_awk; backlog_entry_label_awk; backlog_efficiency_tag_awk; cat <<'AWK'
function eflush(   sok, vd, von, ntok, vcf, tt, mt) {
  if (label == "") return
  gsub(/[ \t]+/, " ", text); gsub(/[ \t]+/, " ", oc)
  if (stp == "") stp = "-"
  sok = estep(stp)
  vd = everdict(hv ? vf : "@NONE@"); von = (vd != "-" && egroup_on(stp))
  ntok = (oc ~ /(^|[^A-Za-z0-9_.])[0-9][0-9.,]*( ?[MKB])? tokens([^A-Za-z]|$)/)
  # VERDICT-CONFLICT's column (b255 F2b D1): the outcome prose says `did not fall` (a letter on
  # neither side) while the Verdict field reads `fell`.
  vcf = (vd == "fell" && oc ~ /(^|[^A-Za-z])[Dd]id not fall([^A-Za-z]|$)/)
  tt = text; gsub(/[Nn]o target( number)?|[Nn]ot an? target/, "", tt)
  tgt = (tt ~ /[Tt]arget( number)?( of| is| was| at| for)?[: ]+[~<>]?[$]?[0-9]/)
  mt = mvt; gsub(/[ \t]+/, " ", mt); if (mt == "") mt = "-"
  if (mvt ~ /(at or below|at or under|at most|no more than|or less|or below|under|below|<=) *[$]?[0-9]/) tgt = 1
  printf "%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%d\t%d\t%s\t%d\t%d\t%d\t%d\t%s\t%s\n", label, tagged, (index(text, "docs/analysis/") > 0), (index(text, "A step with no measured value goes") > 0 && index(text, ".claude/rules/operator-rulings.md") > 0), (index(text, "no graph pipeline step") > 0), landed, ocn, bas, stp, mv, sok, vd, von, ntok, vcf, tgt, mt, oc
  label = ""; tagged = 0; landed = 0; ocn = 0; oc = ""; inoc = 0; text = ""; bas = 0; stp = ""; mv = 0; mvt = ""; vf = ""; hv = 0; ng = 0
}
# THE STEP SET, ONE SOURCE (BL-817 item 2, and b255 F2b). V (the extractor's steps) and B (roll.py's
# bucket tokens) are filled by the BEGIN block appended to this program once the vocabulary is read
# below; F-STEP, NO-STEP-BOUND and the Verdict group all ask this function and nothing else.
# `pre-step` is the extractor's pre-step bucket; `gate-validation[<main>]` takes any <main> in V
# other than gate-validation itself; bare `gate-validation` is never a step.
function estep(t,   m) {
  if (t == "pre-step") return 1
  if (t == "gate-validation") return 0
  if (t ~ /^gate-validation\[.*\]$/) { m = substr(t, 17, length(t) - 17); return (m != "gate-validation" && (m in V)) }
  return ((t in V) || (t in B))
}
# THE VERDICT FIELD (b255 F2b, BL-817 owed item (a)). `Verdict: <group> fell` or `Verdict: <group>
# did not fall`, the WHOLE field, an optional final period, backticks and bold stripped. <group> is
# `<tok>( plus <tok>)*`, each tok a step estep() accepts. Returns `fell`, `dnf`, or `-` (absent or
# malformed: no direction can be read). The group's tokens go to G for egroup_on(). No separate
# blank test: estep() already refuses a token carrying a blank, since no V or B member carries one.
function everdict(f,   d, n, i, t) {
  ng = 0
  if (f == "@NONE@") return "-"
  gsub(/[`*]/, "", f); sub(/[ \t]+$/, "", f); sub(/\.$/, "", f)
  if (f ~ / did not fall$/) { d = "dnf"; sub(/ did not fall$/, "", f) }
  else if (f ~ / fell$/) { d = "fell"; sub(/ fell$/, "", f) }
  else return "-"
  n = split(f, t, / plus /)
  if (n < 1) return "-"
  for (i = 1; i <= n; i++) { if (!estep(t[i])) return "-"; G[i] = t[i] }
  ng = n
  return d
}
# THE STEP BINDING (BL-817 owed item (b)). 1 iff the group names the entry's own step AND carries no
# bucket token other than that step: `stories-test-strategy plus pipeline fell` is the BL-811 escape
# (the step rose, the bucket fell), so a bucket is admitted only when the bucket IS the step.
function egroup_on(s,   i, on) {
  on = 0
  for (i = 1; i <= ng; i++) { if (G[i] == s) on = 1; else if (G[i] in B) return 0 }
  return on
}
# THE FILING FIELDS (BL-817 item 2), each a LABEL opening its own line, optionally bold or after
# `<br>` / `- `. The step token is the first non-blank run after `Step:`, backticks and bold
# stripped, trailing punctuation cut; the caller judges it against the vocabulary.
function efield(l, name,   s) {
  s = l
  if (!sub("^(<br>|- )?(\\*\\*)?" name ":(\\*\\*)?[ \t]*", "", s)) return "@NONE@"
  return s
}
{
  lbl = backlog_entry_label($0)
  if (lbl != "") { eflush(); label = lbl; text = $0; next }
  if (label == "") next
  if (ledger_entry_shape($0) == "heading" && $0 ~ /^##[ \t]/) { eflush(); next }
  # THE RECEIPT IS NOT THE ENTRY (BL-1041): a `verify:` line (the receipt grammar's own `^[ \t]*verify:`)
  # is text about a program, so a tag or a docs/analysis path inside it classes nothing.
  if ($0 ~ /^[ \t]*verify:/) next
  text = text " " $0
  if (backlog_efficiency_tagged($0)) tagged = 1
  if ($0 ~ /^(<br>)?\*\*LANDED \(v[0-9]/) landed = 1
  if (inoc) { if ($0 ~ /^[ \t]*$/) inoc = 0; else oc = oc " " $0 }
  if (ocn == 0 && $0 ~ /^(<br>)?(\*\*)?Outcome measured:/) { ocn = 1; inoc = 1; oc = $0 }
  f = efield($0, "Baseline"); if (f != "@NONE@" && f ~ /^`?s3[0-9][0-9]([^0-9]|$)/) bas = 1
  f = efield($0, "Expected movement"); if (f != "@NONE@" && f ~ /[A-Za-z0-9]/) { mv = 1; if (mvt == "") mvt = f }
  f = efield($0, "Step")
  if (f != "@NONE@" && stp == "") { gsub(/[`*]/, "", f); sub(/[ \t].*$/, "", f); sub(/[.,;:]+$/, "", f); stp = f }
  f = efield($0, "Verdict"); if (f != "@NONE@" && !hv) { vf = f; hv = 1 }
}
END { eflush() }
AWK
} > "$EFFAWK"

# THE ISOLATED NO-STEP BRANCH. Both conditions, and nothing else may accept a sprintless line.
eff_nostep_ok() { case "$1" in *"no graph pipeline step"*) grep -qE 'the cost lives in [^ .]' <<<"$1" ;; *) return 1 ;; esac; }
# A SPRINT TOKEN COUNTS ONLY AS A STANDALONE WORD. Backtick spans are removed first, then every
# whitespace-delimited token carrying a `/` (a path), and only then is `s<NNN>` / `sprint <NNN>`
# matched, with `/`, `.` and `_` also refused as the left boundary. FALSE-POSITIVE STORY: the first
# spelling matched ANY `s<3 digits>`, so BL-821's no-step Outcome line, which cites
# `docs/analysis/pipeline-efficiency-s317-s320/scripts/impl_passes.py`, took the sprint branch and
# failed SHAPE once stamped (the delta adversary's `FAIL: E BL-821 SHAPE` on a scratch copy). Re-measured
# over the live ledger and the archive at this narrowing, old against new predicate on every entry
# carrying an Outcome line: live, 1 flip, BL-821 sprint -> no-step, expected (its line cites a path
# and carries no standalone sprint token); archive, 0 flips of 20 (15 no-step and 5 sprint unchanged).
# E0 seeds all three shapes: a path-embedded token on a no-step line (BL-966, no-step), prose
# "measured on s319 and s320" (BL-967, sprint branch), and -- THE GUARD AGAINST OVER-ACQUITTAL -- a
# token only inside backticks and a path with no no-step wording (BL-968), which must still FIRE as
# NO-SPRINT: the narrowing removes a false sprint, it never grants the no-step acquittal.
eff_names_sprint() {
  local _t
  _t="$(sed -e 's/`[^`]*`//g' -e 's#[^[:space:]]*/[^[:space:]]*##g' <<<"$1")"
  grep -qE '(^|[^A-Za-z0-9_./])(s|sprint )[0-9]{3}([^0-9]|$)' <<<"$_t"
}
# THE SEAT FIGURES (BL-817 item 1, its batch-243 amendment; BL-819 item 3). A sprint-naming line
# reports the step for the LEAD seat and the SUBAGENT seat separately: each seat word -- `lead`,
# `subagent`, `subagents`, any case, a letter on neither side, so `leading` and `mislead` are not
# seats and `Lead-seat` is -- needs at least one occurrence whose FIRST number is a figure, `<n> h`
# or `$<n>`. Skipped before that number: `sNNN`, `sprint NNN` and `BL-NNN` tokens, which name a
# sprint or an entry and are not a figure. One occurrence is scanned only up to the next seat word
# of either kind, so `lead and subagent 1.2 h` gives the lead nothing and one figure never serves
# both seats. The scan also stops at a sentence break (`. ` or `; `), so a later total is not taken as the
# seat's figure. No character window: a percentage or a call count is the
# first number after `Lead-seat local-model share ... s317 2%` and after `lead Agent calls (s317
# 51`, and that alone refuses them. Only the PRESENCE of a figure is judged, never its value.
# The text reaches awk on stdin, never by -v, which strips one level of escaping.
# FALSE-POSITIVE STORY: the contract's first grammar was a character window from the seat word to a
# figure. The contract adversary showed that it accepts `leading 1.2 h` and `mislead $3`, a figure
# across a comma in another subject's clause, and one figure shared by both seats (`lead and subagent
# 1.2 h`). This spelling applies letter boundaries on the seat word, requires the FIRST number after
# it to carry a unit while skipping sNNN / sprint NNN / BL-NNN, and stops each seat's scan at the next
# seat word. E0 seeds BL-969..BL-978 hold each rule, and removing any one rule flips exactly its seed:
# no-boundary flips BL-974, no-skip flips BL-976, no-stop flips BL-972, no-sentence-cut flips BL-977 and BL-978.
# FP-SET: measured with this validator at the collected tip of this release against base (fc71a7b10), over
# copies of both corpora passed by path. The old predicate gives 0 rows over the base archive, the tip
# archive, the base live ledger and the tip live ledger. The new predicate over the BASE archive gives
# exactly 5 SHAPE rows, BL-509, BL-511, BL-515, BL-568 and BL-569: sprint-branch outcome lines that
# carried no lead or subagent figure, the arm's own subject and not false positives. Over the base
# archive (fc71a7b10) with this release's five amended lines applied it gives 0 rows (21 in the close population, 16 on the no-step branch); over the live ledger,
# base and tip, 0 rows with 0 in the close population (BL-513 and BL-694 are not yet stamped `**LANDED`;
# a stamped copy gave 2 in the close population, both valid). The false-positive set is EMPTY, and the
# 5 true positives were dispositioned by amendment from the committed snapshot, so the exception set
# is empty.
eff_seat_ok() {
  LC_ALL=C awk '
  function fig(seg,   p, r) {
    gsub(/(^|[^a-z0-9])(s|sprint )[0-9][0-9][0-9][0-9]*/, " ", seg)
    gsub(/(^|[^a-z0-9])bl-[0-9][0-9]*/, " ", seg)
    p = match(seg, /[0-9]/)
    if (p == 0) return 0
    if (p > 1 && substr(seg, p - 1, 1) == "$") return 1
    r = substr(seg, p)
    match(r, /^[0-9][0-9.,]*/)
    r = substr(r, RLENGTH + 1)
    return (r ~ /^ ?h([^a-z]|$)/)
  }
  { t = t " " tolower($0) }
  END {
    lead = 0; sub_ = 0
    while (match(t, /(^|[^a-z])(lead|subagents|subagent)([^a-z]|$)/)) {
      w = substr(t, RSTART, RLENGTH)
      kind = (w ~ /lead/) ? "lead" : "sub"
      e = RSTART + RLENGTH - 1
      if (substr(t, e, 1) !~ /[a-z]/) e = e - 1
      t = substr(t, e + 1)
      seg = t
      if (match(seg, /(^|[^a-z])(lead|subagents|subagent)([^a-z]|$)/)) seg = substr(seg, 1, RSTART)
      q = match(seg, /[.;] /); if (q) seg = substr(seg, 1, q)
      if (fig(seg)) { if (kind == "lead") lead = 1; else sub_ = 1 }
    }
    exit !(lead && sub_)
  }' <<<"$1"
}
eff_shape_ok() { case "$1" in *token-equivalent*) ;; *) return 1 ;; esac; case "$1" in *API*) ;; *) return 1 ;; esac; case "$1" in *gap-inclusive*) ;; *) return 1 ;; esac; eff_seat_ok "$1"; }
# THE MEASURING SCRIPT AND THE BEFORE/AFTER PAIR (BL-817 item 1, its remainder). Sprint-branch
# lines only; the no-step branch has no figure and is never asked.
# eff_script_ok <text> <root> -- 0 iff the line names the script that measured it: a token with a
# `/` ending `.py` or `.sh` that is a file under <root> (NO-SCRIPT otherwise), OR a directory token
# (ending `/`, a directory under <root>) plus a bare basename (no `/` before it) that is a file
# under that directory. `path.sh:NNN` / `path.py:NNN` tokens are removed first: they are VALUE
# CITATIONS pointing at a line, not the script that took the figure, and accepting them would let a
# `.sh` value citation satisfy this clause by path shape alone.
# FALSE-POSITIVE STORY: measured with this validator's own entry awk over the archive at base
# (c0d4f97cc): 29 lines carry the phrase, 26 are anchored outcome lines, 8 take the sprint branch
# (BL-509, 511, 513, 515, 568, 569, 594, 694). All 8 name `docs/analysis/pipeline-efficiency-
# s317-s320/scripts/` plus a bare `extract.py` / `roll.py`, which is why the directory-plus-basename
# branch exists: a full-path-only grammar refuses all 8. No line names a full script path. On the
# live ledger 0 sprint-branch lines exist at base or tip. The predicate gives 0 rows over both.
eff_script_ok() {
  local _t _p _d _b
  _t="$(sed -E 's#[A-Za-z0-9_./-]+\.(py|sh):[0-9]+##g' <<<"$1")"
  while IFS= read -r _p; do
    [ -n "$_p" ] && [ -f "$2/$_p" ] && return 0
  done <<EOF
$(grep -oE '[A-Za-z0-9_.-]*/[A-Za-z0-9_./-]*\.(py|sh)([^A-Za-z0-9_]|$)' <<<"$_t" | sed -E 's/[^A-Za-z0-9_]$//')
EOF
  while IFS= read -r _d; do
    [ -n "$_d" ] && [ -d "$2/$_d" ] || continue
    while IFS= read -r _b; do
      [ -n "$_b" ] && [ -f "$2/$_d$_b" ] && return 0
    done <<EOF2
$(grep -oE '(^|[^A-Za-z0-9_./-])[A-Za-z0-9_-][A-Za-z0-9_.-]*\.(py|sh)([^A-Za-z0-9_]|$)' <<<"$_t" | sed -E -e 's/^[^A-Za-z0-9_-]//' -e 's/[^A-Za-z0-9_]$//')
EOF2
  done <<EOF
$(grep -oE '[A-Za-z0-9_.-]+(/[A-Za-z0-9_.-]+)*/([^A-Za-z0-9_.-]|$)' <<<"$_t" | sed -E 's#/[^/]*$#/#')
EOF
  return 1
}
# eff_figs_ok <text> -- 0 iff the line gives a before and an after figure: both words `before` and
# `after` (any case, letters on neither side), OR a `<num> to <num>` pair -- a digit on both sides,
# an optional `$` and an optional short unit on the left, and no letter immediately before the left
# number, so `s319 to s320` names two sprints and is not a pair (NO-FIGURES otherwise). Only the
# PRESENCE of a pair is judged; no per-seat pairing and no value comparison.
eff_figs_ok() {
  { grep -qiE '(^|[^a-z])before([^a-z]|$)' <<<"$1" && grep -qiE '(^|[^a-z])after([^a-z]|$)' <<<"$1"; } && return 0
  grep -qE '(^|[^A-Za-z0-9_.])\$?[0-9][0-9.,]*( ?[a-z%]{1,4})? to \$?[0-9]' <<<"$1"
}
# eff_fell_ok <text> <root> -- a live `fell` Verdict against its own figures (BL-1031). 0 iff the figures
# fell; 1 iff they were read and did not fall (FELL-ROSE); 2 iff none could be read and no value citation
# qualifies (NO-VALUE-CITATION). The figures, read in this order: the first number after the word
# `before` and the first after `after` (any case, letters on neither side, an optional `$`), else the two
# numbers of the first `<num> to <num>` pair eff_figs_ok accepts (left is before). Commas are dropped.
# With neither, the line falls back to eff_cite_ok's live rule, the citation a `did not fall` owes.
eff_fell_ok() {
  local _r=0
  awk '
    function num(s) { gsub(/[^0-9.]/, "", s); sub(/\.+$/, "", s); return s + 0 }
    function after_word(s, w,   p) {
      p = match(s, "(^|[^a-z])" w "[ \t]*[$]?[0-9][0-9.,]*")
      if (!p) return ""
      s = substr(s, RSTART, RLENGTH); sub("^.*" w "[ \t]*[$]?", "", s); return s
    }
    { t = tolower($0)
      b = after_word(t, "before"); a = after_word(t, "after")
      if (b != "" && a != "") exit (num(a) < num(b) ? 0 : 1)
      if (match(t, /(^|[^a-z0-9_.])[$]?[0-9][0-9.,]*( ?[a-z%][a-z%]?[a-z%]?[a-z%]?)? to [$]?[0-9][0-9.,]*/)) {
        p = substr(t, RSTART, RLENGTH); l = p; sub(/ to .*$/, "", l); sub(/^[^0-9]*/, "", l); sub(/[^0-9.,].*$/, "", l)
        r = p; sub(/^.* to [$]?/, "", r)
        exit (num(r) < num(l) ? 0 : 1)
      }
      exit 3 }
    END { if (!NR) exit 3 }' <<<"$1" || _r=$?
  case "$_r" in 0|1) return "$_r" ;; esac
  eff_cite_ok "$1" "$2" live && return 0
  return 2
}
# THE STEP VOCABULARY (BL-817 item 2), READ AT RUN TIME FROM THE EXTRACTOR, never copied. The step
# set is every `*.md` under `$SELF_ROOT/core` whose path matches extract.py's `STEP_RE` (its `(?:`
# rewritten to `(` for grep -E), less the names in its `SUBPROC` set, plus `pre-step` (the
# extractor's pre-step bucket) and `gate-validation[<main>]` for any <main> in the set other than
# gate-validation itself. Bare `gate-validation` is NOT a step: the extractor never emits it, every
# gate-validation read becomes `gate-validation[<main>]`. A missing extractor, a missing STEP_RE or
# SUBPROC line, or an empty set is a refusal (exit 2), never a skip.
EFF_EXTRACT="$SELF_ROOT/docs/analysis/pipeline-efficiency-s317-s320/scripts/extract.py"
[ -f "$EFF_EXTRACT" ] || { echo "$(me): FAIL -- $EFF_EXTRACT is missing, so the F-STEP vocabulary (BL-817 item 2) cannot be read; refusing rather than judging step tokens against nothing." >&2; exit 2; }
EFF_STEP_RE="$(sed -n 's/^STEP_RE = re\.compile(r"\(.*\)")$/\1/p' "$EFF_EXTRACT" | sed 's/(?:/(/g')"
EFF_SUBPROC="$(sed -n 's/^SUBPROC = {\(.*\)}$/\1/p' "$EFF_EXTRACT" | tr -d '" ' | tr ',' '\n')"
[ -n "$EFF_STEP_RE" ] && [ -n "$EFF_SUBPROC" ] || { echo "$(me): FAIL -- no STEP_RE or SUBPROC line in $EFF_EXTRACT; the F-STEP vocabulary has drifted from the extractor." >&2; exit 2; }
EFF_VOCAB="$(find "$SELF_ROOT/core" -name '*.md' -path '*/steps/*' 2>/dev/null | grep -E -- "$EFF_STEP_RE" | sed -e 's#.*/##' -e 's/\.md$//' | grep -vxF -- "$EFF_SUBPROC" | LC_ALL=C sort -u)"
[ -n "$EFF_VOCAB" ] || { echo "$(me): FAIL -- no step file under $SELF_ROOT/core matches extract.py's STEP_RE ($EFF_STEP_RE); the F-STEP vocabulary is empty." >&2; exit 2; }
# THE BUCKET TOKENS (b255 F2b), READ AT RUN TIME FROM roll.py, never copied: the second column of
# every row of its `GROUPS = [` ... `]` list whose step set is `None` -- today `pipeline` and
# `ai-dlc-update`, the buckets roll.py totals over every step. `Step: pipeline` declares the whole
# pipeline. A missing roll.py, a missing GROUPS list or no None row is a refusal (exit 2).
EFF_ROLL="$SELF_ROOT/docs/analysis/pipeline-efficiency-s317-s320/scripts/roll.py"
[ -f "$EFF_ROLL" ] || { echo "$(me): FAIL -- $EFF_ROLL is missing, so the bucket tokens of the Verdict/Step grammar (BL-817) cannot be read; refusing rather than judging a verdict group against nothing." >&2; exit 2; }
EFF_BUCKETS="$(awk '/^GROUPS = \[/ { g = 1; next } g && /^\]/ { exit } g' "$EFF_ROLL" | sed -n "s/^[[:space:]]*('[^']*', *'\([A-Za-z0-9_.-]*\)', *None),*[[:space:]]*\$/\1/p" | LC_ALL=C sort -u)"
[ -n "$EFF_BUCKETS" ] || { echo "$(me): FAIL -- no GROUPS row with a None step set in $EFF_ROLL; the bucket tokens of the Verdict/Step grammar have drifted from roll.py." >&2; exit 2; }
# The step set reaches the entry awk as an appended BEGIN block (awk runs every BEGIN), so estep()
# needs no fork per entry. Every token is a file basename or a roll.py identifier, checked to the
# safe class here so none can break the awk string it is written into.
{ printf 'BEGIN {\n'
  printf '%s\n' "$EFF_VOCAB" | LC_ALL=C grep -E '^[A-Za-z0-9_.-]+$' | sed 's/.*/  V["&"] = 1/'
  printf '%s\n' "$EFF_BUCKETS" | sed 's/.*/  B["&"] = 1/'
  printf '}\n'; } >> "$EFFAWK"
# F-STEP's answer is the entry awk's `sok` column (estep() above, the one definition); this wrapper
# keeps the call site and the mutant anchor.
eff_step_ok() {
  [ "$1" = 1 ]
}
# eff_cite_ok <outcome-text> <root> [live|archive] -- 0 iff some `path:line "phrase"` citation's
# phrase QUALIFIES; else 2 if some phrase resolved (hit a line of a file under <root>), else 1.
# THE VALUE CITATION (b255 F2b item (d); BL-817). LIVE: a phrase qualifies iff it is non-empty, hits
# EXACTLY ONE line of <root>/<path>, that line does not carry `did not fall` (a letter on neither
# side), and the line is either
#   (a) a `Failure caught:` line in a file under core/skills/ai-dlc/steps/ whose tail is non-null; or
#   (b) a table row that is not its table's header (the first `|` line of a contiguous block), where
#       the header has a column matching `Failure caught|[Uu]nique|[Cc]atch` and the row's cell in
#       at least one such column is non-null.
# Null: empty, none, n/a, -, an em dash, 0, no, nothing, or a cell starting `no ` or `0 `. A phrase
# that resolves with no qualifying line is VALUE-NULL; none resolving is NO-VALUE-CITATION. ARCHIVE
# judges as before: any hit line that is a `Failure caught:` line or a table row.
# THE LIMIT, stated because the arm header says a figure's VALUE is never judged: this checks the
# SHAPE of the cited line, not the truth of its value. A made-up non-null cell under a catch header
# still passes.
# COST: ONE awk per citation ($EFFCITE), which replaced a sed, a grep and a second grep. The citation
# goes in by ENVIRON, never -v (which strips one level of escaping), and the cited file is awk's MAIN
# input, never `getline <`, so an unopenable file is an awk error exit, which reads as unresolved
# beside the shell `[ -f ]`. Exit 0 qualifies; 4 resolved, null; 5 resolved, null live but an
# old-rule hit (a row or a Failure caught: line), which --archive accepts; anything else unresolved.
# FALSE-POSITIVE STORY: measured with this validator over the archive (32 in the close population,
# 6 value citations) and the live ledger. The live ledger has no close population at this base, so
# its FP set is 0. Over the archive the new predicate flips exactly ONE entry, BL-594: its phrase
# "Keep as the convergence exit" hits TWO rows of docs/analysis/step-value-s317-s319.md, and the p1
# row's catch cell, "no unique high-consequence catch", is null. It was filed and closed before
# this arm existed, so it is the enumerated exception: an archive entry present at the merge-base
# with origin/main keeps the old any-hit rule rather than being re-judged (see eff_close for the
# scope; an archive entry ADDED since the merge-base takes the live rule).
eff_cite_ok() {
  local _c _p _r _res=1
  while IFS= read -r _c; do
    [ -n "$_c" ] || continue
    _p="${_c%%:*}"
    [ -f "$2/$_p" ] || continue
    _r=0; EFF_CITE="$_c" awk -f "$EFFCITE" "$2/$_p" 2>/dev/null || _r=$?
    case "$_r" in
      0) return 0 ;;
      5) [ "${3:-live}" = archive ] && return 0; _res=2 ;;
      4) _res=2 ;;
    esac
  done <<EOF
$(grep -oE '[A-Za-z0-9_./-]+\.(md|sh|py):[0-9]+[^"]{0,16}"[^"]+"' <<<"$1")
EOF
  return "$_res"
}
EFFCITE="$WORK/effcite.awk"
cat > "$EFFCITE" <<'AWK'
function trim(s) { gsub(/^[ \t*`]+|[ \t*`.]+$/, "", s); return s }
function isnull(s) { s = tolower(trim(s)); return (s == "" || s ~ /^(none|n\/a|-|—|0|no|nothing)$/ || s ~ /^(no|0) /) }
BEGIN {
  c = ENVIRON["EFF_CITE"]; ph = ""; i = index(c, "\"")
  if (i) { r = substr(c, i + 1); j = index(r, "\""); if (j > 1) ph = substr(r, 1, j - 1) }
  if (ph == "") { bad = 1; exit 1 }
  insteps = (substr(c, 1, index(c, ":") - 1) ~ /^core\/skills\/ai-dlc\/steps\//)
}
{ isrow = ($0 ~ /^[ \t]*\|/) }
isrow && !intab { intab = 1; hdr = $0; hnr = NR }
!isrow { intab = 0 }
index($0, ph) {
  hits++
  fc = (index($0, "Failure caught:") > 0)
  if (isrow || fc) old = 1
  q = 0
  if (fc && insteps) { t = $0; sub(/.*Failure caught:/, "", t); if (!isnull(t)) q = 1 }
  if (isrow && NR != hnr) {
    nh = split(hdr, H, "|"); nr = split($0, R, "|")
    for (k = 1; k <= nh; k++) if (H[k] ~ /Failure caught|[Uu]nique|[Cc]atch/ && k <= nr && !isnull(R[k])) q = 1
  }
  if ($0 ~ /(^|[^A-Za-z])[Dd]id not fall([^A-Za-z]|$)/) q = 0
}
END { if (bad || !hits) exit 1; if (hits == 1 && q) exit 0; exit (old ? 5 : 4) }
AWK
# eff_close <outcome-present> <outcome-text> <root> <live|archive> <sok> <vd> <von> <ntok> <step-at-close> <vcf>
#   -> a finding code, or nothing. Arguments 5-8 and 10 are the entry awk's columns; 9 is 1 when the
#   entry's step differs from, or is absent at, the merge-base (STEP-AT-CLOSE), 0 otherwise or when
#   no merge-base was evaluated. <live|archive> is the RULE, not the file: eff_corpus passes `live`
#   for every live-ledger entry and for every archive entry added since the merge-base.
# THE VERDICT GRAMMAR, LIVE LEDGER ONLY (b255 F2b, BL-817 owed items (a), (b), (c)). A sprint-branch
# close on the live ledger, after SHAPE / NO-SCRIPT / NO-FIGURES, also needs, in this order:
#   NO-TOKENS      a token figure in the outcome line, `<n> tokens` / `<n>M tokens` / `<n> K tokens`
#                  (the `ntok` column; roll.py seat_line prints `<x.1f>M tokens`);
#   NO-STEP-BOUND  a `Step:` line naming a step estep() accepts (`sok`) -- no Basis fallback.
#                  THE BASIS LINES, re-measured at origin/main 5a6a6c657, at ca6a6f941 (0.1070.0) and at this tip,
#                  both files alike, <f> docs/backlog.md and docs/backlog.archive.md (Basis rows alike at all three):
#                    git show <ref>:<f> | grep -cE '^(<br>|- )?(\*\*)?Basis:'     -> 0 live, 0 archive
#                    git show <ref>:<f> | grep -cE '^(<br>|- )?(\*\*)?Basis[ :(]' -> 5 live, 0 archive
#                    control, grep -cE '^(<br>|- )?(\*\*)?Step:' -> 10 live, 3 archive at 5a6a6c657; 12 live, 3 archive at ca6a6f941 (0.1070.0)
#                  RE-DERIVED at c75a7c323 (0.1128.0) by the same three commands: Basis: 0 live, 0 archive; Basis[ :(]
#                  3 live (BL-809, 810, 812), 2 archive (BL-808, 811, rotated); Step: 27 live, 10 archive; negative
#                  control QqZBasisNone -> 0 in both (BasisZZQ is no control any more: BL-1031's entry names it).
#                  The first pattern's 0 was BLIND, not a finding: the ledger's form is `Basis
#                  (operator ruling, BL-817):`, a parenthesis before the colon, which `Basis:` cannot
#                  spell. Seeded check, four lines (`Basis (operator ruling, BL-817): x`, `- **Basis: y`,
#                  `Basisless: z`, `not Basis (x)`): the second pattern matches 2, the first 1, missing
#                  exactly the parenthesised form. The 5 lines, one each in BL-808, 809, 810, 811 and
#                  812, all open `Basis (operator ruling, BL-817): dollars are token-equivalent ...`
#                  and each declares the STEP SCOPE ITS PRICING COVERS: BL-808 and BL-809
#                  implementation plus gate-validation[implementation]; BL-810 the four planning steps
#                  (no single token); BL-811 stories-test-strategy; BL-812 the whole `pipeline` bucket.
#                  A pricing-scope line is not a step declaration, so the fallback is dropped by
#                  design and a close binds only through a `Step:` field: no close binds through a
#                  Basis line, and an entry whose only step naming is its Basis line fails closed
#                  (NO-STEP-BOUND). All 5 declare a step scope and all 5 carry a `Step:` line
#                  (implementation, implementation, carry-over-evaluation, stories-test-strategy, pipeline,
#                  for BL-808, 809, 810, 811, 812; re-read at c75a7c323). With no Step line a close fails
#                  closed (NO-STEP-BOUND). BL-810's four-step scope binds by declaring ONE member in `Step:`
#                  (the field takes one token) and naming all four in the `Verdict:` group, which carries
#                  every step of the scope (`Step: carry-over-evaluation` with the group
#                  `carry-over-evaluation plus requirements plus architecture plus stories-test-strategy`,
#                  or `Step: implementation` with `implementation plus gate-validation[implementation]`,
#                  reads quiet; a group not naming the declared member reads OFF-STEP). egroup_on lets such
#                  a group read `fell` while the declared member rose, so a close states the declared
#                  member's own movement beside the group's.
#   NO-DIRECTION   a `Verdict: <group> fell|did not fall` field (`vd`); direction is read from
#                  that field ONLY, never from `fell` anywhere in the prose;
#   OFF-STEP       a group naming the entry's own step and no bucket token other than it (`von`);
#   STEP-AT-CLOSE  a step already declared, identically, at the merge-base (argument 9);
#   VERDICT-CONFLICT a `fell` field while the outcome prose says `did not fall`, letter-bounded
#                  (argument 10): the field cannot cancel the value-citation rule the prose owes;
# and then `did not fall` keeps its value citation: none resolving is NO-VALUE-CITATION, one
# resolving to no qualifying line is VALUE-NULL (eff_cite_ok, live rule); and `fell` is held to its
# own figures: read and not falling is FELL-ROSE, unreadable with no qualifying citation is
# NO-VALUE-CITATION (eff_fell_ok, BL-1031).
# THE ARCHIVE SCOPE IS BY MERGE-BASE, NOT BY MODE (b255 F2b D2). Under --archive, every archive
# entry ADDED since the merge-base with origin/main (absent from docs/backlog.archive.md there;
# eff_added_labels, the live ledger's derivation applied to the archive) is judged by the LIVE rules
# above, so a close cannot go from unstamped-live to archived in one squash and never meet them; its
# STEP-AT-CLOSE base is the merge-base's live ledger plus archive, where a rotated entry's Step line
# sat. Entries PRESENT in the archive at the merge-base keep the archive rule: direction from the
# Verdict field when the entry carries one, else from `fell` / `did not fall` anywhere in the line,
# and the old any-hit value citation. With no origin/main, no merge-base, or the archive untracked
# there, nothing is added and every archive entry takes the archive rule; the OK line says why.
# The filing arms (F-*) stay live-ledger-only in both modes.
# FALSE-POSITIVE STORY: measured with this validator over the live ledger at 0.1060.0 (fc292b591;
# `git show fc292b591:docs/backlog.md > <scratch>/backlog.md`, then the --efficiency-only command
# below: 60 entries, 0 in the close population, since nothing is stamped), over a stamped scratch
# copy, and over the archive with --archive (32 in the population, 24 no-step, verdicts unchanged).
# The full measurement is in the release that introduced this arm. THE SCOPE IS THE NARROWING, AND THE PRE-EXISTING SET IS MEASURED,
# not hand-listed: the live close rules over EVERY archive entry at origin/main 09bec4bc3, by
#   git show 09bec4bc3:docs/backlog.archive.md > <scratch>/backlog.archive.md
#   bash scripts/validate-backlog-receipts.sh <scratch>/backlog.archive.md --efficiency-only --root .
# (a ledger outside the tree, so the live branch runs with no merge-base set: STEP-AT-CLOSE and the
# added-entry filing arms not evaluated), close codes only, first failing rule per entry:
#   BL-507, 509, 511, 513, 515, 568, 569, 694 NO-STEP-BOUND; BL-594 NO-TOKENS
# -- 9 of 33 in the close population, the 24 others on the no-step branch. These are the archive's 9
# sprint-branch closes, filed and closed before the arm existed (BL-507 archived at 0.1063.0 with no
# Step: or Verdict line); BL-594 is also the value-citation exception (see eff_cite_ok). They are
# exempt BY BEING PRESENT IN THE ARCHIVE AT THE MERGE-BASE (the E3/E3b precedent: an entry closed
# before an arm is not re-judged by it), never by a blanket exemption of the archive: a merge-base
# before an entry's archiving judges it live, and BL-507 then fires NO-STEP-BOUND. The live set is empty.
eff_close() {
  [ "$1" = "1" ] || { echo NO-OUTCOME; return; }
  if ! eff_names_sprint "$2"; then
    eff_nostep_ok "$2" && return
    echo NO-SPRINT; return
  fi
  eff_shape_ok "$2" || { echo SHAPE; return; }
  eff_script_ok "$2" "$3" || { echo NO-SCRIPT; return; }
  eff_figs_ok "$2" || { echo NO-FIGURES; return; }
  if [ "$4" = live ]; then
    [ "$8" = 1 ] || { echo NO-TOKENS; return; }
    [ "$5" = 1 ] || { echo NO-STEP-BOUND; return; }
    [ "$6" != - ] || { echo NO-DIRECTION; return; }
    [ "$7" = 1 ] || { echo OFF-STEP; return; }
    [ "$9" != 1 ] || { echo STEP-AT-CLOSE; return; }
    [ "${10}" != 1 ] || { echo VERDICT-CONFLICT; return; }
    if [ "$6" = dnf ]; then
      eff_cite_ok "$2" "$3" live
      case $? in 0) ;; 2) echo VALUE-NULL ;; *) echo NO-VALUE-CITATION ;; esac
    else
      eff_fell_ok "$2" "$3"
      case $? in 0) ;; 1) echo FELL-ROSE ;; *) echo NO-VALUE-CITATION ;; esac
    fi
    return
  fi
  case "$6" in
    dnf) eff_cite_ok "$2" "$3" archive || echo NO-VALUE-CITATION; return ;;
    fell) return ;;
  esac
  case "$2" in
    *"did not fall"*) eff_cite_ok "$2" "$3" archive || echo NO-VALUE-CITATION ;;
    *fell*) ;;
    *) echo NO-DIRECTION ;;
  esac
}
# eff_corpus <ledger> <root> <live|archive> [<added-labels-file>] -> `CODE<TAB>LABEL` per finding;
# counts to $WORK/eff.counts. F-BASELINE / F-STEP / F-MOVEMENT (BL-817 item 2) judge a TAGGED entry
# (the population F-RULING reads; an untagged docs/analysis/ citer is F-UNTAGGED's) that is not on
# the no-step branch and whose label is in <added-labels-file> -- the entries ADDED on this branch.
# No file, or `--archive`, and they judge nothing: an entry filed before the arm is not re-filed.
# Under `archive`, <added-labels-file> names the archive entries ADDED since the merge-base, and
# each of those is closed by the LIVE rules (eff_close's `live`); the rest keep the archive rule.
eff_corpus() {
  local _l _t _a _r _n _ld _on _bs _st _mv _sok _vd _von _ntok _vcf _tg _mt _oc _code _sac _rule _chg="" _add="" _pop=0 _ns=0 _ent=0 _fadd=0 _alive=0 _mvc=""
  [ -n "${4:-}" ] && [ -f "$4.mvchg" ] && _mvc="$(cat "$4.mvchg")"
  # STEP-AT-CLOSE's set, read ONCE (no fork per entry): the labels eff_added_labels found whose
  # step differs from, or is absent at, the merge-base. No added-labels file, no set: not evaluated.
  [ -n "${4:-}" ] && [ -f "$4.stepchg" ] && _chg="$(cat "$4.stepchg")"
  # The archive's added set, read ONCE for the same reason.
  [ "$3" = archive ] && [ -n "${4:-}" ] && [ -f "$4" ] && _add="$(cat "$4")"
  while IFS="$(printf '\t')" read -r _l _t _a _r _n _ld _on _bs _st _mv _sok _vd _von _ntok _vcf _tg _mt _oc; do
    [ -n "$_l" ] || continue
    _ent=$((_ent + 1))
    if [ "$3" = "live" ]; then
      [ "$_t" = "1" ] && [ "$_r" != "1" ] && printf 'F-RULING\t%s\n' "$_l"
      [ "$_a" = "1" ] && [ "$_t" != "1" ] && [ "$_n" != "1" ] && printf 'F-UNTAGGED\t%s\n' "$_l"
      if [ "$_t" = "1" ] && [ "$_n" != "1" ] && [ -n "${4:-}" ] && grep -qxF -- "$_l" "$4"; then
        _fadd=$((_fadd + 1))
        [ "$_bs" = "1" ] || printf 'F-BASELINE\t%s\n' "$_l"
        eff_step_ok "$_sok" || printf 'F-STEP\t%s\n' "$_l"
        [ "$_mv" = "1" ] || printf 'F-MOVEMENT\t%s\n' "$_l"
      fi
      if [ "$_t" = "1" ] && [ "$_n" != "1" ] && [ "$_tg" = "1" ]; then
        case "
$_mvc
" in *"
$_l
"*) printf 'F-TARGET\t%s\n' "$_l" ;; esac
      fi
    fi
    if [ "$_ld" = "1" ] && { [ "$_t" = "1" ] || [ "$_on" = "1" ]; }; then
      _pop=$((_pop + 1))
      _sac=0
      case "
$_chg
" in *"
$_l
"*) _sac=1 ;; esac
      _rule="$3"
      case "
$_add
" in *"
$_l
"*) _rule=live; _alive=$((_alive + 1)) ;; esac
      _code="$(eff_close "$_on" "$_oc" "$2" "$_rule" "$_sok" "$_vd" "$_von" "$_ntok" "$_sac" "$_vcf")"
      if [ -n "$_code" ]; then printf '%s\t%s\n' "$_code" "$_l"
      elif ! eff_names_sprint "$_oc"; then _ns=$((_ns + 1)); fi
    fi
  done <<EOF
$(awk -f "$EFFAWK" "$1")
EOF
  printf '%s %s %s %s %s\n' "$_ent" "$_pop" "$_ns" "$_fadd" "$_alive" > "$WORK/eff.counts"
}
# eff_added_labels <ledger> <root> <out-file> -- the entry labels in <ledger> that its version at
# the merge-base of HEAD with origin/main does not carry. Prints the base sha, or a SKIP reason
# (origin/main absent, or the ledger not tracked at the base) and leaves <out-file> absent.
# <step-base-name>, given under --archive as the live ledger's basename, adds that file beside the
# ledger AT THE MERGE-BASE to the step map STEP-AT-CLOSE compares against (never to the added set):
# an entry stamped and rotated in one commit had its Step line in the live ledger at the base.
eff_added_labels() { # eff_added_labels <ledger> <root> <out-file> [<step-base-name>]
  local _abs _rel _base _sb _x=""
  _abs="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
  case "$_abs" in "$2"/*) _rel="${_abs#"$2"/}" ;; *) echo "not evaluated -- $1 is outside $2"; return ;; esac
  git -C "$2" rev-parse -q --verify origin/main >/dev/null 2>&1 || { echo "not evaluated -- origin/main is absent"; return; }
  _base="$(git -C "$2" merge-base origin/main HEAD 2>/dev/null)" || { echo "not evaluated -- no merge-base with origin/main"; return; }
  git -C "$2" cat-file -e "${_base}:${_rel}" 2>/dev/null || { echo "not evaluated -- $_rel is not tracked at the merge-base ${_base}"; return; }
  # Each step is checked: a failing read here would leave an EMPTY added set, which reads exactly
  # like "nothing was added" and lets every new filing through. Refuse instead.
  _sb="$3.bent"
  if [ -n "${4:-}" ]; then case "$_rel" in */*) _x="${_rel%/*}/$4" ;; *) _x="$4" ;; esac; fi
  git -C "$2" show "${_base}:${_rel}" > "$3.blob" 2>/dev/null \
    && awk -f "$EFFAWK" "$3.blob" > "$3.bent" && awk -f "$EFFAWK" "$1" > "$3.tent" \
    && awk -F'\t' 'NR == FNR { b[$1] = 1; next } !($1 in b) { print $1 }' "$3.bent" "$3.tent" > "$3" \
    && { [ -z "$_x" ] || ! git -C "$2" cat-file -e "${_base}:${_x}" 2>/dev/null \
         || { _sb="$3.sbent"; git -C "$2" show "${_base}:${_x}" | awk -f "$EFFAWK" | cat - "$3.bent" > "$_sb"; }; } \
    && awk -F'\t' 'NR == FNR { s[$1] = $9; next } !($1 in s) || s[$1] == "-" || s[$1] != $9 { print $1 }' "$_sb" "$3.tent" > "$3.stepchg" \
    && awk -F'\t' 'NR == FNR { s[$1] = $17; next } !($1 in s) || s[$1] != $17 { print $1 }' "$3.bent" "$3.tent" > "$3.mvchg" \
    || { echo "$(me): FAIL -- could not derive the entries added since merge-base ${_base}; refusing rather than judging the filing shape against an empty set." >&2; rm -f "$3" "$3.stepchg" "$3.mvchg"; return 2; }
  echo "against merge-base ${_base}"
}
}

vbr_sec_eff() {
EFF_ADDED=""
if [ "${EFF_MODE:-live}" = live ]; then
  EFF_SCOPE="$(eff_added_labels "$LEDGER" "$SUBJECT_ROOT" "$WORK/eff.added")" || exit 2
else
  # D2: the archive's entries added since the merge-base, with the live ledger beside it (at the
  # base) feeding STEP-AT-CLOSE's step map. A ledger not named *.archive.md has no live sibling.
  EFF_XNAME=""; case "${LEDGER##*/}" in *.archive.md) EFF_XNAME="${LEDGER##*/}"; EFF_XNAME="${EFF_XNAME%.archive.md}.md" ;; esac
  EFF_SCOPE="$(eff_added_labels "$LEDGER" "$SUBJECT_ROOT" "$WORK/eff.added" "$EFF_XNAME")" || exit 2
fi
[ -f "$WORK/eff.added" ] && EFF_ADDED="$WORK/eff.added"
EFF_OUT="$(eff_corpus "$LEDGER" "$SUBJECT_ROOT" "${EFF_MODE:-live}" "$EFF_ADDED")"
read -r EFF_ENT EFF_POP EFF_NS EFF_FADD EFF_ALIVE < "$WORK/eff.counts"
# NOTE (b): STEP-AT-CLOSE is evaluated only where the merge-base step set was derived; say so on the
# efficiency line too, not only under the filing scope.
if [ -n "$EFF_ADDED" ]; then EFF_SAC="STEP-AT-CLOSE evaluated ${EFF_SCOPE}"; else EFF_SAC="STEP-AT-CLOSE ${EFF_SCOPE}"; fi
if [ "${EFF_MODE:-live}" = archive ]; then
  if [ -n "$EFF_ADDED" ]; then EFF_ASCOPE="; archive scope: ${EFF_ALIVE} close(s) added since the merge-base judged by the live rules, the rest by the archive rule, ${EFF_SCOPE}"
  else EFF_ASCOPE="; archive scope: every entry judged by the archive rule, live rules ${EFF_SCOPE}"; fi
  EFF_FSCOPE="not evaluated under --archive"
else EFF_ASCOPE=""; EFF_FSCOPE="$EFF_SCOPE"; fi
EFF_N="$(printf '%s' "$EFF_OUT" | grep -c .)" || EFF_N=0
eff_report() {
  [ "$EFF_N" -eq 0 ] && return 0
  printf '%s\n' "$EFF_OUT" | awk -F'\t' '{ printf "FAIL: E\t%s\t%s\n", $2, $1 }' >&2
  echo "FAIL: E: $EFF_N efficiency finding(s) in $LEDGER (codes above). NO-OUTCOME/NO-SPRINT/NO-DIRECTION/NO-VALUE-CITATION/SHAPE: an efficiency close needs an 'Outcome measured:' line naming the consumer sprint, the token-equivalent \$ with API \$ beside, gap-inclusive hours, a lead figure and a subagent figure reported separately (each seat word -- lead, subagent(s) -- followed first by '<n> h' or '\$<n>', not a percentage or a count, and not one figure shared by both seats), and 'fell' or 'did not fall' -- the latter with a path:line \"phrase\" citation whose phrase hits exactly one line, that line not saying 'did not fall' and being either a 'Failure caught:' line under core/skills/ai-dlc/steps/ with a non-null tail or a non-header table row with a non-null cell under a 'Failure caught' / 'Unique' / 'Catch' column (VALUE-NULL when the phrase resolves but its line does not qualify; null is empty, none, n/a, -, an em dash, 0, no, nothing, or a cell starting 'no ' or '0 '; --archive keeps the old any-hit rule); or, with no sprint, the explicit 'no graph pipeline step' wording naming where 'the cost lives in'. F-RULING: cite \"A step with no measured value goes\" in .claude/rules/operator-rulings.md. NO-SCRIPT/NO-FIGURES: a sprint-naming outcome line also names the script that measured it (a resolving path ending .py or .sh, or a resolving directory token plus a bare basename under it; a path:line value citation does not count) and gives a before and an after figure (both words 'before' and 'after', or a '<num> to <num>' pair). NO-TOKENS/NO-STEP-BOUND/NO-DIRECTION/OFF-STEP/STEP-AT-CLOSE/VERDICT-CONFLICT (sprint-naming line, on the live ledger and, under --archive, on every archive entry added since the merge-base with origin/main; an archive entry present at the merge-base keeps the archive rule): the outcome line carries a token figure ('<n> tokens', '<n>M tokens', '<n> K tokens'; roll.py prints '<x>M tokens'; an 'sNNN tokens' sprint token does not count); the entry carries a 'Step: <token>' line whose token is a step (as F-STEP below; no Basis: fallback); the direction is read ONLY from a 'Verdict: <group> fell' or 'Verdict: <group> did not fall' line, the whole field, where <group> is '<step>( plus <step>)*', never from 'fell' elsewhere in the prose; the group names the entry's own Step token and no bucket token (roll.py GROUPS rows with no step set: $(printf '%s' "$EFF_BUCKETS" | tr '\n' ' ')) other than it, so 'Step: pipeline' is the only way to close on the whole-pipeline bucket; and the Step line was already present, unchanged, at the merge-base with origin/main, so the step is declared before the close, never at it; and a 'fell' Verdict field may not stand beside outcome prose saying 'did not fall' (VERDICT-CONFLICT: the field cannot cancel the value citation that prose owes). FELL-ROSE: a 'Verdict: <group> fell' close needs its own figures to fall (the first number after 'before' above the first after 'after', or the left of the first '<num> to <num>' pair above the right); a 'fell' whose figures cannot be read that way needs the value citation a 'did not fall' owes (NO-VALUE-CITATION). F-TARGET: a tagged entry added, or whose 'Expected movement:' changed, since the merge-base states no target number: no 'Expected movement:' comparator-then-figure ('at or below 15', 'at most 3', '<= 4') and no 'target of 30' wording (operator-rulings.md; 'no target number' and 'not a target' disclaimers are fine). F-BASELINE/F-STEP/F-MOVEMENT: a tagged efficiency entry ADDED on this branch carries a 'Baseline: s3NN' line, a 'Step: <token>' line whose token is a step of extract.py's STEP_RE (less SUBPROC), 'pre-step', 'gate-validation[<step>]' or a roll.py bucket token, and a non-empty 'Expected movement:' line, unless it says there is no graph pipeline step. F-UNTAGGED: an entry citing docs/analysis/ carries a bold efficiency tag (**DEFECT (efficiency).**, **DEFECT, efficiency.**, **NOTE (efficiency).** or **DEFECT. [efficiency rank N]**) or the 'no graph pipeline step' line." >&2
  return 1
}
if [ -n "$EFF_MODE" ]; then
  eff_report || exit 1
  echo "OK: validate-backlog-receipts --$([ "$EFF_MODE" = archive ] && echo archive || echo efficiency-only) -- ${EFF_ENT} entries in ${LEDGER}, ${EFF_POP} in the efficiency close population, every one carrying a valid outcome line (${EFF_NS} on the no-graph-pipeline-step branch; ${EFF_SAC})${EFF_ASCOPE}; filing shape: ${EFF_FADD} added entr(y/ies) judged, ${EFF_FSCOPE}."
  exit 0
fi
}

# ---------------------------------------------------------------------------
# score_ledger <ledger> <subject-root> -> result rows on stdout; the `sh` receipt count and
# the live entry count go to $WORK/counts, which `read_counts` lifts back into the caller.
# ---------------------------------------------------------------------------
score_ledger() {
  _sl_ledger="$1"; _sl_root="$2"
  rm -rf "$WORK/out" "$WORK/rec" "$WORK/t"
  # PRUNE BEFORE A PASS REUSES CHECKOUT NAMES. Every pass names its trees <record>.<suffix> under
  # $WORK/t, and a run makes several passes. A worker whose `worktree remove` lost the lock to a
  # sibling falls back to `rm -rf`, leaving the registration behind, and the next pass's `worktree
  # add` to that same path then fails five times and reads BROKEN.
  git -C "$_sl_root" worktree prune >/dev/null 2>&1 || true
  mkdir -p "$WORK/out" "$WORK/rec" "$WORK/t"
  _sl_i=0; _sl_e=0; _sl_m=0
  : > "$WORK/unrec"
  # The has/lacks verb pair is bound to the classifier's own case arm: if it moves, refuse rather than drift.
  grep -qE '^[[:space:]]*has\|lacks\)' "$SELF_ROOT/scripts/backlog-reverify.sh" 2>/dev/null || { echo "$(me): FAIL -- backlog-reverify.sh no longer dispatches 'has|lacks)', so the verb pair recognised here has drifted from it." >&2; return 2; }
  while IFS="$(printf '\t')" read -r _l _c _r; do
    [ -n "$_l" ] || continue
    [ "$_c" = "1" ] && continue                 # annotated LANDED: awaiting rotation, not live
    _sl_e=$(( _sl_e + 1 ))
    [ "$_r" = "@NONE@" ] && continue
    case "$_r" in "manual"|"manual "*) _sl_m=$(( _sl_m + 1 )); continue ;; esac
    # A VALUE THAT IS NEITHER FORM IS NAMED, NOT DROPPED. `manual.` / `manual,` / `manual:` carry a
    # char after `manual` that is not a space, so they match neither case above; falling through
    # silently left the ledger one entry short of its manual count with nothing naming the line.
    # has/lacks are ledger verbs resolved by backlog-reverify.sh: recognised, neither manual nor unrecognised.
    case "$_r" in "has "*|"lacks "*) continue ;; esac
    case "$_r" in "sh "*|"sh") ;; *) printf '%s\t%s\n' "$_l" "$(printf '%s' "$_r" | cut -c1-20)" >> "$WORK/unrec"; continue ;; esac
    _sl_i=$(( _sl_i + 1 ))
    printf '%s\n%s\n' "$_l" "$_r" > "$WORK/rec/$(printf '%04d' "$_sl_i")"
  done <<EOF
$(awk -f "$AWKF" "$_sl_ledger")
EOF
  # THE COUNTS GO TO A FILE, NOT TO A VARIABLE. Every caller runs this in `$( )` to capture
  # its rows, and an assignment made inside a command substitution is lost to the subshell --
  # the caller would read an unbound variable, or worse, the PREVIOUS call's value.
  printf '%s %s %s\n' "$_sl_i" "$_sl_e" "$_sl_m" > "$WORK/counts"
  [ "$_sl_i" -eq 0 ] && return 0

  # THE COMPLETENESS SENTINEL IS DERIVED FROM THE SUBJECT, NEVER NAMED. A hardcoded path is
  # absent from some repository that this arm is pointed at, and every checkout then fails the
  # completeness test for a reason that has nothing to do with the checkout. The first tracked
  # file at HEAD is present by construction in any tree `git worktree add` produced.

  BR_SENTINEL="$(git -C "$_sl_root" ls-tree -r --name-only HEAD 2>/dev/null | sed -n '1p')"
  if [ -z "$BR_SENTINEL" ]; then
    echo "$(me): FAIL -- $_sl_root has no tracked files at HEAD, so no checkout can be proven complete." >&2
    return 2
  fi

  BR_WORK="$WORK"; BR_SUBJECT_ROOT="$_sl_root"; BR_PATH_CLASS="$PATH_CLASS"
  BR_TOKAWK="$TOKAWK"
  BR_L3_BASE="$(m1_l3_base "$_sl_root")"
  export BR_WORK BR_SUBJECT_ROOT BR_PATH_CLASS BR_TOKAWK BR_SENTINEL BR_LIB_VARS BR_L3_BASE
  # BR_RECEIPTS_RUNNING reaches every open receipt and everything it starts -- see RE_ENTRY.
  # The key is resolved BEFORE the pipeline and a failure refuses: an empty key exported here would
  # leave every receipt this pass runs unguarded against re-entry, which fails open.
  _sl_key="$(ledger_key "$_sl_ledger" "$_sl_root")" || { echo "$(me): FAIL -- could not resolve the re-entry key for $_sl_ledger." >&2; return 2; }
  find "$WORK/rec" -type f | sort | BR_RECEIPTS_RUNNING="$_sl_key" xargs -P "$JOBS" -n 1 bash "$SELF" --score-one

  # EVERY DISPATCHED RECEIPT MUST HAVE PRODUCED A VERDICT. A worker that died leaves no file,
  # and a smaller result set reads exactly like a smaller population.
  _sl_got="$(find "$WORK/out" -type f | grep -c .)" || _sl_got=0
  if [ "$_sl_got" -ne "$_sl_i" ]; then
    echo "$(me): FAIL -- $_sl_got of $_sl_i dispatched receipts produced a verdict. A missing verdict reads exactly like a receipt that scored clean; this refuses rather than reporting the difference as a result." >&2
    return 2
  fi
  cat "$WORK/out"/* 2>/dev/null
  return 0
}

# ---------------------------------------------------------------------------
# score_closed <ledger> <subject-root> <base-ref> -> CLOSED-OK / CLOSED-FAIL rows on stdout; the
# population summary goes to $WORK/ccounts as "<derived 0|1> <mb> <stamped> <rotated> <sh-run>".
# THE CLOSED-ON-BRANCH POPULATION (BL-836). Two sets, both keyed on what THIS BRANCH did, both read
# from the subject repository's own history -- never this script's:
#   STAMPED  an entry annotated `**LANDED (v` in the ledger at HEAD whose label is NOT annotated in
#            the ledger at the merge-base of <base-ref> and HEAD.
#   ROTATED  an entry whose heading is among the ADDED lines of the archive's `git diff -U0 MB HEAD`.
#            The added lines are parsed with the SAME entry grammar as the ledger, so a heading the
#            grammar would not call an entry is not a rotation either.
# For both, the archive/ledger record at HEAD supplies the receipt, and only a `verify: sh` receipt
# runs; its expected exit is exactly 0, because the close itself says the fix is present.
# The base resolves IN THE SUBJECT ROOT. Resolved against this script's own repository instead, a
# probe tree passed with --root would be scored against the wrong history.
# ---------------------------------------------------------------------------
score_closed() {
  _sc_ledger="$1"; _sc_root="$2"; _sc_base="$3"
  rm -rf "$WORK/crec" "$WORK/cout"; mkdir -p "$WORK/crec" "$WORK/cout" "$WORK/t"
  if [ "${R8_SKIP:-0}" = 1 ]; then printf 'skip - 0 0 0\n' > "$WORK/ccounts"; return 0; fi
  git -C "$_sc_root" worktree prune >/dev/null 2>&1 || true   # see score_ledger: names are reused
  printf '0 - 0 0 0\n' > "$WORK/ccounts"
  _sc_mb="$(git -C "$_sc_root" merge-base "$_sc_base" HEAD 2>/dev/null)" || _sc_mb=""
  [ -n "$_sc_mb" ] || return 0
  _sc_abs="$(cd "$(dirname "$_sc_ledger")" && pwd)/$(basename "$_sc_ledger")"
  _sc_rel="$(git -C "$(dirname "$_sc_abs")" ls-files --full-name -- "$(basename "$_sc_abs")" 2>/dev/null | sed -n '1p')"
  [ -n "$_sc_rel" ] || return 0
  case "$_sc_rel" in */*) _sc_arel="${_sc_rel%/*}/backlog.archive.md" ;; *) _sc_arel="backlog.archive.md" ;; esac
  _sc_head="$(git -C "$_sc_root" show "HEAD:$_sc_rel" 2>/dev/null | awk -f "$AWKF")"
  _sc_was="$(git -C "$_sc_root" show "${_sc_mb}:${_sc_rel}" 2>/dev/null | awk -f "$AWKF" | awk -F'\t' '$2 == "1" { print $1 }')"
  _sc_added="$(git -C "$_sc_root" diff -U0 "$_sc_mb" HEAD -- "$_sc_arel" 2>/dev/null | awk '/^\+\+\+ / { next } /^\+/ { print substr($0, 2) }' | awk -f "$AWKF" | cut -f1)"
  # A ROTATION is an entry NEW TO THE ARCHIVE: its heading is ADDED in the archive diff AND its id
  # is absent from the archive at the merge-base. An archived heading retitled on the branch is
  # added to the diff too, but its id was already archived, so it is not a close this branch made.
  # "Removed from the live ledger" is NOT the test: an entry filed AND rotated on the same branch
  # (BL-848 in its own release) is in the live ledger at neither end, and that test drops it.
  _sc_archwas="$(git -C "$_sc_root" show "${_sc_mb}:${_sc_arel}" 2>/dev/null | awk -f "$AWKF" | cut -f1)"
  _sc_arch="$(git -C "$_sc_root" show "HEAD:$_sc_arel" 2>/dev/null | awk -f "$AWKF")"
  _sc_i=0; _sc_ns=0; _sc_nr=0
  # One record per member: label, receipt, kind. A label in both sets is counted once, as rotated.
  _sc_emit() { # _sc_emit <label> <receipt> <kind>
    case "$2" in "sh "*|"sh") ;; *) return 0 ;; esac
    _sc_i=$(( _sc_i + 1 ))
    printf '%s\n%s\n%s\n' "$1" "$2" "$3" > "$WORK/crec/c$(printf '%04d' "$_sc_i")"
  }
  while IFS="$(printf '\t')" read -r _l _c _r; do
    [ -n "$_l" ] && [ "$_c" = "1" ] || continue
    grep -qxF -- "$_l" <<<"$_sc_was" && continue
    _sc_ns=$(( _sc_ns + 1 ))
    _sc_emit "$_l" "$_r" "stamped LANDED on the branch"
  done <<EOF
$_sc_head
EOF
  while IFS="$(printf '\t')" read -r _l _c _r; do
    [ -n "$_l" ] || continue
    grep -qxF -- "$_l" <<<"$_sc_added" || continue
    grep -qxF -- "$_l" <<<"$_sc_archwas" && continue
    _sc_nr=$(( _sc_nr + 1 ))
    _sc_emit "$_l" "$_r" "rotated on the branch"
  done <<EOF
$_sc_arch
EOF
  printf '1 %s %s %s %s\n' "$(printf '%s' "$_sc_mb" | cut -c1-9)" "$_sc_ns" "$_sc_nr" "$_sc_i" > "$WORK/ccounts"
  [ "$_sc_i" -eq 0 ] && return 0
  BR_SENTINEL="$(git -C "$_sc_root" ls-tree -r --name-only HEAD 2>/dev/null | sed -n '1p')"
  [ -n "$BR_SENTINEL" ] || { echo "$(me): FAIL -- $_sc_root has no tracked files at HEAD, so no checkout can be proven complete." >&2; return 2; }
  BR_WORK="$WORK"; BR_SUBJECT_ROOT="$_sc_root"
  BR_L3_BASE="$(m1_l3_base "$_sc_root")"
  export BR_WORK BR_SUBJECT_ROOT BR_SENTINEL BR_LIB_VARS BR_L3_BASE
  # BR_RECEIPTS_RUNNING reaches every closed receipt and everything it starts -- see RE_ENTRY.
  _sc_key="$(ledger_key "$_sc_ledger" "$_sc_root")" || { echo "$(me): FAIL -- could not resolve the re-entry key for $_sc_ledger." >&2; return 2; }
  find "$WORK/crec" -type f | sort | BR_RECEIPTS_RUNNING="$_sc_key" xargs -P "$JOBS" -n 1 bash "$SELF" --closed-one
  _sc_got="$(find "$WORK/cout" -type f | grep -c .)" || _sc_got=0
  if [ "$_sc_got" -ne "$_sc_i" ]; then
    echo "$(me): FAIL -- $_sc_got of $_sc_i dispatched closed-on-branch receipts produced a verdict; a missing verdict reads exactly like a close that was confirmed." >&2
    return 2
  fi
  cat "$WORK/cout"/* 2>/dev/null
  return 0
}

# closed_line / open_empty_line -- the two population lines, each ONE emitter. An EMPTY population is said as such, never as a clean one.
closed_line() { # reads $WORK/ccounts and the failure count $1
  read -r _cl_d _cl_mb _cl_s _cl_r _cl_n < "$WORK/ccounts"
  if [ "$_cl_d" = "skip" ]; then
    echo "CLOSED-POPULATION: SKIPPED -- this run was started from inside a receipt (BR_RECEIPTS_RUNNING is set on entry), so R8 does not run again here; the outer run executes those receipts once."
  elif [ "$_cl_d" != "1" ]; then
    echo "CLOSED-POPULATION: NOT DERIVED -- base ref '$BASE_REF' has no merge-base with HEAD in the subject repository, or the ledger is not tracked there; no closed-on-branch receipt was run, and this is not a clean result."
  elif [ "$_cl_n" -eq 0 ]; then
    echo "CLOSED-POPULATION: EMPTY -- 0 sh receipt(s) to run over merge-base $_cl_mb ($_cl_s stamped LANDED on the branch, $_cl_r rotated on the branch); nothing was observed, which is not a clean result."
  else
    echo "CLOSED-POPULATION: $_cl_n sh receipt(s) run over merge-base $_cl_mb ($_cl_s stamped LANDED on the branch, $_cl_r rotated on the branch), $1 not exiting 0."
  fi
}
open_skip_line() { echo "OPEN-POPULATION: SKIPPED -- this run was started from inside a receipt (BR_RECEIPTS_RUNNING is set on entry), so no open sh receipt runs here and R2-R7 judge nothing; the outer run executes those receipts once."; }
open_empty_line() { # open_empty_line <sh-receipt-count> -> the line, or nothing when the population is non-empty
  [ "$1" -eq 0 ] && echo "OPEN-POPULATION: EMPTY -- 0 open sh receipt(s) in the ledger, so the open-entry cannot-measure check (R7) observed NOTHING this run; that is not a clean result."
  return 0
}

# The counts score_ledger wrote, read back in the PARENT shell. A missing file is a refusal:
# a defaulted zero here would read as an empty ledger, which is a different finding.
read_counts() {
  SH_RECEIPTS=""; ENTRIES=""; MANUAL_RECEIPTS=""
  [ -f "$WORK/counts" ] || { echo "$(me): FAIL -- the scorer wrote no population counts, so the ledger's size is unknown and no ratchet below could be read." >&2; exit 2; }
  read -r SH_RECEIPTS ENTRIES MANUAL_RECEIPTS < "$WORK/counts"
  case "${SH_RECEIPTS:-}${ENTRIES:-}${MANUAL_RECEIPTS:-}" in ''|*[!0-9]*) echo "$(me): FAIL -- the scorer's population counts did not parse." >&2; exit 2 ;; esac
}

# r2_alldriver <rows> <sh-count> -- exit 0 iff a ZERO-scored ledger is accounted for by drivers:
# nothing scored, at least one DRIVER, and every `sh` receipt is DRIVER, ALREADY-PASSING or
# OUT-OF-POPULATION. ONE implementation, called by R2 on the corpus.
r2_alldriver() {
  printf '%s\n' "$1" | awk -F'\t' -v sh="$2" '
    $1 == "PROSE-CLOSABLE" || $1 == "BOUND" || $1 == "FORMAT-SENSITIVE" { sc++ }
    $1 == "DRIVER" { dr++ }
    $1 == "DRIVER" || $1 == "ALREADY-PASSING" || $1 == "OUT-OF-POPULATION" { ok++ }
    END { exit ((sc + 0) == 0 && (dr + 0) > 0 && (ok + 0) == sh + 0 ? 0 : 1) }'
}
# ---------------------------------------------------------------------------
# R9 -- THE LIVE-LEDGER JOINS (BL-872); see the header. ONE reader per producer and ONE judge, called
# by the corpus on the live ledger.
# ---------------------------------------------------------------------------
# r9_read_rows <classifier rows> -> "<resolved sh ids> <distinct ids> <rows> <first status>"
r9_read_rows() {
  printf '%s\n' "$1" | awk -F'\t' '
    $0 == "" { next }
    { n++; if (n == 1) first = $1; ids[$2] = 1 }
    $3 ~ /^sh receipt exited/ { sh[$2] = 1 }
    END { for (i in ids) ni++; for (s in sh) ns++; printf "%d %d %d %s\n", ns + 0, ni + 0, n + 0, (first == "" ? "-" : first) }'
}
# r9_read_size <validate-backlog-size.sh output> -> its B1 count, or nothing when B1 did not speak
r9_read_size() {
  printf '%s\n' "$1" | sed -n 's|^OK: validate-backlog-size -- B1 \([0-9][0-9]*\)/[0-9]* entries in .*|\1|p'
}
# r9_judge <arm sh count> <ceiling output> <classifier rows> -> one line; 0 both joins hold, 1 not
r9_judge() {
  _r9_rd="$(r9_read_rows "$3")"
  read -r _r9_ns _r9_ni _r9_nr _r9_first <<<"$_r9_rd"
  _r9_sz="$(r9_read_size "$2")"
  if [ "$_r9_first" = DECLARED-EMPTY ]; then
    if [ "$_r9_nr" -eq 1 ] && [ "$_r9_sz" = 0 ] && grep -qF ', declared empty (' <<<"$2"; then
      echo "the ledger is declared empty, and the ceiling (0, declared empty) and the classifier (one DECLARED-EMPTY row) both say so"; return 0
    fi
    echo "the classifier says the ledger is declared empty and the ceiling disagrees (ceiling '${_r9_sz}', classifier rows ${_r9_nr})"; return 1
  fi
  if [ "$_r9_first" = INPUT-UNRESOLVED ] || [ "$_r9_nr" -eq 0 ]; then
    echo "the classifier resolved no entry (rows ${_r9_nr}, first '${_r9_first}'), so neither join observed anything"; return 1
  fi
  if [ -z "$_r9_sz" ]; then
    echo "validate-backlog-size.sh printed no B1 reading, so the ceiling join has no left side"; return 1
  fi
  if [ "$1" -lt "$_r9_ns" ]; then
    echo "j1: this arm's sh population is $1 and backlog-reverify.sh resolves ${_r9_ns} sh receipts; the arm's population is SMALLER than the classifier's, so receipts exist that it never scores"; return 1
  fi
  if [ "$_r9_sz" -ne "$_r9_ni" ]; then
    echo "b16: the ceiling counts ${_r9_sz} entries and backlog-reverify.sh classifies ${_r9_ni}"; return 1
  fi
  echo "j1 the sh population $1 covers the classifier's resolved set ${_r9_ns}; b16 the ceiling and the classifier agree at ${_r9_sz} entries"
  return 0
}
# R9 RUNS IN TWO HALVES (BL-1054). r9_start, called just before the corpus score_ledger, takes the checkout and starts the classifier and the ceiling over the live ledger in the BACKGROUND, in their own
# process group; r9_run, at R9's place after every read of $WORK/counts, waits for them and judges. The two passes
# share no file: the checkout is $WORK/t9/r9, outside the $WORK/t that score_ledger and score_closed clear. Every
# line R9 prints is deferred to r9_run, so the output is the serial run's. A run that exits before r9_run
# waits for the job (r9_reap); an interrupt kills its group. r9_run alone (no r9_start) runs both halves in line.
R9_STATE=""; R9_MSG=""; R9_PID=""
r9_start() {
  R9_STATE=notrun
  R9_SIZE="$SELF_ROOT/scripts/validate-backlog-size.sh"
  if [ ! -f "$R9_SIZE" ]; then
    R9_MSG="R9: NOT RUN -- scripts/validate-backlog-size.sh is absent beside this validator, so the live-ledger joins (j1 population, b16 ceiling) observed NOTHING in this tree; that is not a clean result."
    return 0
  fi
  if ! git -C "$SUBJECT_ROOT" cat-file -e "HEAD:scripts/backlog-reverify.sh" 2>/dev/null; then
    R9_MSG="R9: NOT RUN -- the subject repository's HEAD carries no scripts/backlog-reverify.sh, so the live-ledger joins (j1 population, b16 ceiling) observed NOTHING in this tree; that is not a clean result."
    return 0
  fi
  R9_STATE=refused
  R9_T="$WORK/t9/r9"
  mkdir -p "$WORK/t9"
  git -C "$SUBJECT_ROOT" worktree add --detach -q "$R9_T" HEAD >/dev/null 2>&1 \
    || { R9_MSG="$(me): FAIL -- R9 could not check out HEAD of $SUBJECT_ROOT for the classifier; this is a refusal, not a reading."; return 0; }
  R9_REV="$R9_T/scripts/backlog-reverify.sh"
  # THE CORPUS, in the background. The classifier's receipts run in the checkout; a re-entry into this validator skips.
  set -m
  { BR_RECEIPTS_RUNNING="$LEDGER_KEY" bash "$R9_REV" "$LEDGER" > "$WORK/r9.rows" 2>/dev/null
    AI_DLC_BACKLOG_MAX_ENTRIES=100000 bash "$R9_SIZE" "$LEDGER" > "$WORK/r9.size" 2>&1; } </dev/null &
  R9_PID=$!
  set +m
  trap 'r9_reap kill; parent_cleanup' INT TERM
  R9_STATE=started
}
# r9_run -> prints the R9 line on stdout; returns 0 held or not run, 1 a join failed, 2 a refusal
r9_run() {
  [ -n "$R9_STATE" ] || r9_start
  case "$R9_STATE" in
    notrun) echo "$R9_MSG"; return 0 ;;
    refused) echo "$R9_MSG" >&2; return 2 ;;
  esac
  wait "$R9_PID"; R9_PID=""
  # The checkout must outlive the classifier: a pass that cleared it mid-run leaves rows j1's `at least` accepts.
  if [ ! -f "$R9_REV" ]; then
    git -C "$SUBJECT_ROOT" worktree remove --force "$R9_T" >/dev/null 2>&1 || rm -rf "$R9_T"
    echo "$(me): FAIL -- R9's checkout $R9_T was removed while the classifier ran in it, so its rows describe a vanishing tree; this is a refusal, not a reading." >&2
    return 2
  fi
  r9_rows=""; [ -f "$WORK/r9.rows" ] && r9_rows="$(<"$WORK/r9.rows")"
  r9_size=""; [ -f "$WORK/r9.size" ] && r9_size="$(<"$WORK/r9.size")"
  git -C "$SUBJECT_ROOT" worktree remove --force "$R9_T" >/dev/null 2>&1 || rm -rf "$R9_T"
  if r9_why="$(r9_judge "$SH_RECEIPTS" "$r9_size" "$r9_rows")"; then
    echo "R9: OK -- live-ledger joins on ${LEDGER}: ${r9_why}."
    return 0
  fi
  echo "FAIL: R9: live-ledger join on ${LEDGER}: ${r9_why}." >&2
  echo "R9: FAIL -- see stderr."
  return 1
}

# ---------------------------------------------------------------------------
# R10 -- THE ANCHOR CONVENTION (BL-836); see the header. ONE grammar, r10_awk_prog, and ONE judge,
# r10_judge, called by the corpus on `$WORK/rec`.
# TEXT ONLY: nothing a receipt names is executed, and the only file contents read are line 1 of each
# tracked path an anchor names (the vacuity test). Record files are the scorer's own format: line 1
# the entry label, line 2 the ledger's receipt value (`sh <one-liner>`).
# Row: <label> TAB <ANCHORED|UNANCHORED|NO-TRACKED-READ> TAB <first unanchored path, or -> TAB
# <full|partial>; then one `R10-COUNTS <scanned> <unanchored> <anchored> <partial>` line.
# ---------------------------------------------------------------------------
r10_awk_prog() {
cat <<'AWK'
function isid(s) { return (s ~ /[A-Za-z_][A-Za-z0-9_][A-Za-z0-9_][A-Za-z0-9_]/) }
function addtok(d, t, v) { NT[d]++; TT[d, NT[d]] = t; TV[d, NT[d]] = v }
# matchp <text> <i> -> the index of the ")" closing the "(" at i, quote-aware; 0 when unbalanced
function matchp(t, i,   n, dep, q, c) {
  n = length(t); dep = 0; q = ""
  for (; i <= n; i++) {
    c = substr(t, i, 1)
    if (q == "'") { if (c == "'") q = ""; continue }
    if (c == "\\") { i++; continue }
    if (q == "\"") {
      if (c == "\"") q = ""
      else if (c == "$" && substr(t, i + 1, 1) == "(") { i = matchp(t, i + 1); if (!i) return 0 }
      continue
    }
    if (c == "'" || c == "\"") { q = c; continue }
    if (c == "(") dep++
    else if (c == ")") { dep--; if (dep == 0) return i }
  }
  return 0
}
# dollar <text> <i> <depth> -> the index after the expansion at i; DOL is its template: S1 k S1 for
# command substitution k (its text in SUBT), S2 name S2 for a variable, S3 for anything unresolvable.
function dollar(t, i, d,   c, j, nm, k) {
  c = substr(t, i + 1, 1)
  if (c == "(") {
    j = matchp(t, i + 1)
    if (!j) { PARTIAL = 1; DOL = S3; return length(t) + 1 }
    if (substr(t, i + 2, 1) == "(") { DOL = S3; return j + 1 }
    k = ++NSUB[d]; SUBT[d, k] = substr(t, i + 2, j - i - 2); DOL = S1 k S1; return j + 1
  }
  if (c == "{") {
    j = index(substr(t, i + 2), "}")
    if (!j) { PARTIAL = 1; DOL = S3; return length(t) + 1 }
    nm = substr(t, i + 2, j - 1)
    DOL = (nm ~ /^[A-Za-z_][A-Za-z0-9_]*$/) ? S2 nm S2 : S3
    return i + 2 + j
  }
  if (c ~ /[A-Za-z_]/) {
    nm = substr(t, i + 1); match(nm, /^[A-Za-z_][A-Za-z0-9_]*/)
    DOL = S2 substr(nm, 1, RLENGTH) S2; return i + 1 + RLENGTH
  }
  if (c ~ /[0-9?#@*$!-]/) { DOL = S3; return i + 2 }
  DOL = "$"; return i + 1
}
# lex <text> <depth> -> tokens TT/TV at that depth: w (a word template), r (a redirection), o (an operator)
function lex(t, d,   n, i, c, c2, w, inw, q, two, three, j) {
  NT[d] = 0; NSUB[d] = 0; n = length(t); w = ""; inw = 0; q = ""; i = 1
  while (i <= n) {
    c = substr(t, i, 1)
    if (q == "'") { if (c == "'") q = ""; else w = w c; i++; continue }
    if (c == "\\") {
      c2 = substr(t, i + 1, 1)
      if (q == "\"" && c2 !~ /[$`"\\]/) { w = w c; i++; continue }
      w = w c2; inw = 1; i += 2; continue
    }
    if (c == "$") { i = dollar(t, i, d); w = w DOL; inw = 1; continue }
    if (c == "`") { PARTIAL = 1; j = index(substr(t, i + 1), "`"); w = w S3; inw = 1; i = j ? i + j + 1 : n + 1; continue }
    if (q == "\"") { if (c == "\"") q = ""; else w = w c; i++; continue }
    if (c == "'" || c == "\"") { q = c; inw = 1; i++; continue }
    if (c == " " || c == "\t") { if (inw) addtok(d, "w", w); w = ""; inw = 0; i++; continue }
    two = substr(t, i, 2); three = substr(t, i, 3)
    if (c == "<" || c == ">" || two == "&>") {
      if (inw && c != "&" && w ~ /^[0-9]+$/) { w = ""; inw = 0 }
      if (inw) addtok(d, "w", w)
      w = ""; inw = 0
      if (three == "<<<") { addtok(d, "r", "<<<"); i += 3; continue }
      if (two == "<<") { PARTIAL = 1; addtok(d, "r", "<<"); i += 2; continue }
      if (two == ">>" || two == ">&" || two == "<&" || two == "&>" || two == "<>" || two == ">|") { addtok(d, "r", two); i += 2; continue }
      addtok(d, "r", c); i++; continue
    }
    if (two == "&&" || two == "||" || two == ";;") { if (inw) addtok(d, "w", w); w = ""; inw = 0; addtok(d, "o", two); i += 2; continue }
    if (c == ";" || c == "|" || c == "&" || c == "\n" || c == "(" || c == ")") { if (inw) addtok(d, "w", w); w = ""; inw = 0; addtok(d, "o", c); i++; continue }
    w = w c; inw = 1; i++
  }
  if (q != "") PARTIAL = 1
  if (inw) addtok(d, "w", w)
}
function newcmd(d, lvl) { C = ++NC[d]; CN[d, C] = 0; CSEP[d, C] = ""; CIN[d, C] = ""; COUT[d, C] = ""; CHS[d, C] = ""; CLVL[d, C] = lvl; CG[d, C] = 0; CGC[d, C] = 0; CSUBS[d, C] = "" }
function addsubs(d, c, w,   a, b) {
  while ((a = index(w, S1)) > 0) { w = substr(w, a + 1); b = index(w, S1); CSUBS[d, c] = CSUBS[d, c] " " substr(w, 1, b - 1); w = substr(w, b + 1) }
}
# build <depth> -> simple commands CW/CN, each with its terminating operator CSEP, its `<` input CIN,
# its subshell level CLVL, and whether it opens (CG) or closes (CGC) a `{ }` group.
function build(d,   i, t, v, open, lvl, tgt) {
  NC[d] = 0; open = 0; lvl = 0; tgt = ""
  for (i = 1; i <= NT[d]; i++) {
    t = TT[d, i]; v = TV[d, i]
    if (t == "w") {
      if (tgt != "") { if (tgt == "<") CIN[d, C] = v; if (tgt == ">") COUT[d, C] = v; if (tgt == "<<<") CHS[d, C] = v; addsubs(d, C, v); tgt = ""; continue }
      if (!open) { newcmd(d, lvl); open = 1 }
      if (CN[d, C] == 0 && v == "{") { CG[d, C]++; continue }
      if (CN[d, C] == 0 && v == "}") { CGC[d, C] = 1; continue }
      CN[d, C]++; CW[d, C, CN[d, C]] = v; addsubs(d, C, v); continue
    }
    if (t == "r") { if (!open) { newcmd(d, lvl); open = 1 }; tgt = v; continue }
    if (v == "(") { if (open) CSEP[d, C] = v; open = 0; lvl++; continue }
    if (v == ")") { if (open) CSEP[d, C] = v; open = 0; if (lvl > 0) lvl--; continue }
    if (open) { CSEP[d, C] = v; open = 0 } else if (NC[d] > 0 && (CSEP[d, C] == ")" || CSEP[d, C] == "")) CSEP[d, C] = v
  }
}
# expand <template> -> the word with every known variable substituted; UNRES = 1 when anything is left
function expand(w,   out, a, b, nm) {
  UNRES = 0; out = ""
  while ((a = index(w, S2)) > 0) {
    out = out substr(w, 1, a - 1); w = substr(w, a + 1); b = index(w, S2); nm = substr(w, 1, b - 1); w = substr(w, b + 1)
    if (nm in VAR) out = out VAR[nm]; else { UNRES = 1; out = out "$" nm }
  }
  out = out w
  if (index(out, S1) || index(out, S3)) UNRES = 1
  return out
}
# rpath <template> -> the TRACKED path it names, or nothing; an unresolved or directory operand is PARTIAL
function rpath(w,   v) {
  v = expand(w)
  if (UNRES) { PARTIAL = 1; return "" }
  sub(/^\.\//, "", v); sub(/\/$/, "", v)
  if (v in TR) return v
  if (v in TD) PARTIAL = 1
  return ""
}
function line1(p,   l) {
  if (!(p in L1)) { L1[p] = ""; if ((getline l < (ROOT "/" p)) > 0) L1[p] = l; close(ROOT "/" p) }
  return L1[p]
}
# patok <pattern template> <path> -> 1 when the pattern is a non-vacuous anchor for that path
function patok(pt, p,   v, s) {
  v = expand(pt)
  if (UNRES) return 0
  # A POSIX class name is not an identifier: `^[[:blank:]]*#` names no line of the subject.
  s = v; gsub(/\[\[:[a-z]+:\]\]/, "", s)
  if (!isid(s)) return 0
  if (v ~ /^\^?#!/) return 0
  s = v; sub(/^\^/, "", s); sub(/\$$/, "", s)
  if (index(line1(p), s) > 0) return 0
  return 1
}
# chain9 <depth> <c> -> 1 when command c gates an `exit 9`: c heads or sits in an `&&` chain, at one
# subshell level, whose last member is joined by `||` to `exit 9` (or a `{ }` group holding one), and
# the chain is not itself the right side of an `||` (`X || grep -q t P || exit 9` skips the grep when X
# succeeds). A lone `grep -q t P || exit 9` is the one-member chain.
function chain9(d, c,   m) {
  m = c
  while (m > 1 && CSEP[d, m - 1] == "&&") m--
  if (m > 1 && CSEP[d, m - 1] == "||") return 0
  m = c
  while (m <= NC[d] && CSEP[d, m] == "&&") { m++; if (m > NC[d] || CLVL[d, m] != CLVL[d, c]) return 0 }
  return (m <= NC[d] && CSEP[d, m] == "||" && exit9_after(d, m))
}
# cmpok <op> <k> -> 1 when `[ "$n" <op> <k> ]` holding means n >= 1: a count of at least one match.
# `-ge 0`, `-lt`, `-le` and `-eq 0` hold on a count of zero, so they are vacuous and refused.
function cmpok(op, k) {
  if (k !~ /^[0-9]+$/) return 0
  if (op == "-gt") return 1
  if (op == "-ge" || op == "-eq" || op == "=" || op == "==") return (k + 0 >= 1)
  if (op == "-ne") return (k + 0 == 0)
  return 0
}
function is9(d, m) { return (m <= NC[d] && CN[d, m] == 2 && CW[d, m, 1] == "exit" && CW[d, m, 2] == "9") }
# grepdot <depth> <m> -> 1 when command m is `grep -q .` (no file, not inverted): a pipe into it fails
# exactly when the stage before printed nothing.
function grepdot(d, m) { return (m <= NC[d] && CN[d, m] == 3 && CW[d, m, 1] == "grep" && CW[d, m, 2] ~ /^-[A-Za-z]*q[A-Za-z]*$/ && CW[d, m, 2] !~ /v/ && CW[d, m, 3] == ".") }
# cmpanchor <depth> <c> -- `cmp -s A B && exit 9`, at top level and not the right side of an `||`,
# where B is the `>` target of an earlier awk or sed over the tracked path A (or the operands swapped):
# a transform that changed nothing exits 9, so its pattern is an anchor on A.
function cmpanchor(d, c,   j, a, ops, no, k, x, y, px) {
  if (CLVL[d, c] || CSEP[d, c] != "&&" || !is9(d, c + 1) || (c > 1 && CSEP[d, c - 1] == "||")) return
  no = 0
  for (j = 2; j <= CN[d, c]; j++) { a = CW[d, c, j]; if (substr(a, 1, 1) == "-") continue; ops[++no] = a }
  if (no != 2) return
  for (k = 1; k <= 2; k++) {
    x = ops[k]; y = ops[3 - k]
    px = rpath(x); if (px == "") continue
    y = S6 expand(y)
    if ((y in PEND) && index(PEND[y] S4, S4 px S4)) { ANC[px] = 1; NANC++; PEND[y] = ""; return }
  }
}
function then9(d, m) { return (m <= NC[d] && CN[d, m] == 3 && CW[d, m, 1] == "then" && CW[d, m, 2] == "exit" && CW[d, m, 3] == "9") }
# exit9_after <depth> <c> -> 1 when the command after c is `exit 9`, or a `{ }` group holding one
function exit9_after(d, c,   m, g) {
  m = c + 1
  if (m > NC[d]) return 0
  if (!CG[d, m]) return is9(d, m)
  g = 0
  for (; m <= NC[d]; m++) { g += CG[d, m]; if (is9(d, m)) return 1; if (CGC[d, m]) g--; if (g <= 0) return 0 }
  return 0
}
function pgrep(d, c, s, git,   j, a, k, ch, rest, endo, havep, v) {
  endo = 0; havep = 0
  for (j = s; j <= CN[d, c]; j++) {
    a = CW[d, c, j]
    if (!endo && a == "--") { endo = 1; if (git) GITDD = 1; continue }
    if (!endo && substr(a, 1, 1) == "-" && a != "-") {
      if (a ~ /^--/) {
        if (a == "--quiet" || a == "--silent") QUIET = 1
        else if (a == "--invert-match") INV = 1
        else if (a ~ /^--regexp=/) { if (!havep) PAT = substr(a, 10); havep = 1 }
        else if (a == "--regexp") { j++; if (!havep) PAT = CW[d, c, j]; havep = 1 }
        else if (a == "--file") { j++; PAT = S3; havep = 1 }
        else if (a ~ /^--file=/) { PAT = S3; havep = 1 }
        continue
      }
      for (k = 2; k <= length(a); k++) {
        ch = substr(a, k, 1)
        if (ch == "q") QUIET = 1
        if (ch == "v") INV = 1
        if (index("efmABCdD", ch)) {
          rest = substr(a, k + 1); if (rest == "") { j++; rest = CW[d, c, j] }
          if (ch == "e") { if (!havep) PAT = rest; havep = 1 } else if (ch == "f") { PAT = S3; havep = 1 }
          break
        }
      }
      continue
    }
    if (!havep) { PAT = a; havep = 1; continue }
    if (git && !GITDD) {
      v = expand(a)
      if (UNRES) { PARTIAL = 1; continue }
      if ((v in TR) || (v in TD)) { F[++NF2] = a; continue }
      if (v != "HEAD") EXEMPT = 1
      continue
    }
    F[++NF2] = a
  }
}
function pawk(d, c, s,   j, a, havep) {
  havep = 0
  for (j = s; j <= CN[d, c]; j++) {
    a = CW[d, c, j]
    if (!havep && substr(a, 1, 1) == "-" && a != "-") {
      if (a == "-f") { j++; PAT = S3; havep = 1 } else if (a == "-F" || a == "-v") j++
      continue
    }
    if (!havep) { PAT = a; havep = 1; continue }
    if (a ~ /^[A-Za-z_][A-Za-z0-9_]*=/) continue
    F[++NF2] = a
  }
}
function psed(d, c, s,   j, a, havep, endo) {
  havep = 0; endo = 0
  for (j = s; j <= CN[d, c]; j++) {
    a = CW[d, c, j]
    if (!endo && a == "--") { endo = 1; continue }
    if (!endo && substr(a, 1, 1) == "-" && a != "-") {
      if (a == "-e" || a == "--expression" || a ~ /^-[A-Za-z]*e$/) { j++; if (!havep) PAT = CW[d, c, j]; havep = 1 }
      else if (a == "-f") { j++; PAT = S3; havep = 1 }
      continue
    }
    if (!havep) { PAT = a; havep = 1; continue }
    F[++NF2] = a
  }
}
function pcat(d, c, s,   j, a) {
  for (j = s; j <= CN[d, c]; j++) { a = CW[d, c, j]; if (substr(a, 1, 1) == "-" && a != "-") continue; F[++NF2] = a }
}
# git show <rev>:<path> reads the WORKING TREE only when <rev> is HEAD or the index (empty); any
# other revision is a history read the rename does not move, and the command is exempt.
function pshow(d, c, s,   j, a, v, rv, k) {
  for (j = s; j <= CN[d, c]; j++) {
    a = CW[d, c, j]
    if (substr(a, 1, 1) == "-") continue
    v = expand(a)
    if (UNRES) { PARTIAL = 1; continue }
    k = index(v, ":")
    if (!k) continue
    rv = substr(v, 1, k - 1)
    if (rv != "HEAD" && rv != "") { EXEMPT = 1; continue }
    F[++NF2] = substr(v, k + 1)
  }
}
# settle <depth> <c> <j> <insub> <neg> -- `[ -n "$NAME" ] || exit 9`, or a count compare
# `[ "$NAME" -ge 1 ] || exit 9` (cmpok), anchors every path NAME's capture read with a non-vacuous
# pattern. The word may also be an inline `"$(grep -c t P)"`, whose reads walk() held under S5 d S5 k.
function settle(d, c, j, insub, neg,   w, nm, n, ps, i) {
  w = CW[d, c, j]
  if (substr(w, 1, 1) == S1 && substr(w, length(w), 1) == S1) nm = S5 d S5 substr(w, 2, length(w) - 2)
  else if (substr(w, 1, 1) != S2 || substr(w, length(w), 1) != S2) return
  else nm = substr(w, 2, length(w) - 2)
  if (insub || CLVL[d, c] || neg || !chain9(d, c)) return
  if (!(nm in PEND) || PEND[nm] == "") return
  n = split(substr(PEND[nm], 2), ps, S4)
  for (i = 1; i <= n; i++) { ANC[ps[i]] = 1; NANC++ }
  PEND[nm] = ""
}
# hsettle <name> -- the here-string anchor: every path NAME's capture read (PEND and PENDX) for which
# PAT is a non-vacuous anchor is anchored; the rest stay pending.
function hsettle(nm,   n, ps, i, keep) {
  keep = ""; n = split(substr(PEND[nm], 2), ps, S4)
  for (i = 1; i <= n; i++) if (patok(PAT, ps[i])) { ANC[ps[i]] = 1; NANC++ } else keep = keep S4 ps[i]
  PEND[nm] = keep
  keep = ""; n = split(substr(PENDX[nm], 2), ps, S4)
  for (i = 1; i <= n; i++) if (patok(PAT, ps[i])) { ANC[ps[i]] = 1; NANC++ } else keep = keep S4 ps[i]
  PENDX[nm] = keep
}
function capname(caps, k,   a, s) {
  a = index(caps, " " k "=")
  if (!a) return ""
  s = substr(caps, a + length(k) + 2); sub(/ .*$/, "", s)
  return s
}
# walk <depth> <insub> <cap> -- judge every command at this depth, substitutions before the command
# that carries them. <insub> is 1 inside `$( )`, where no exit leaves the receipt; <cap> names the
# variable a `NAME=$( )` capture assigns, whose reads wait for a `[ -n "$NAME" ] || exit 9`.
function walk(d, insub, cap,   c, j, n, ks, k, w1, neg, isif, a, nm, val, caps, cmd, isg, anc, i, p, cpk) {
  build(d)
  for (c = 1; c <= NC[d]; c++) {
    caps = ""
    for (j = 1; j <= CN[d, c] && CW[d, c, j] ~ /^[A-Za-z_][A-Za-z0-9_]*=/; j++) {
      a = index(CW[d, c, j], "="); nm = substr(CW[d, c, j], 1, a - 1); val = substr(CW[d, c, j], a + 1)
      while ((a = index(val, S1)) > 0) { val = substr(val, a + 1); i = index(val, S1); caps = caps " " substr(val, 1, i - 1) "=" nm; val = substr(val, i + 1) }
    }
    n = split(CSUBS[d, c], ks, " ")
    for (j = 1; j <= n; j++) {
      k = ks[j]; nm = capname(caps, k)
      # An inline count compare `[ "$(grep -c t P)" -gt 0 ]` holds its reads as a capture of its own.
      if (nm == "" && CW[d, c, 1] == "[" && CW[d, c, 2] == S1 k S1) nm = S5 d S5 k
      lex(SUBT[d, k], d + 1); walk(d + 1, 1, nm != "" ? nm : cap)
    }
    j = 1; neg = 0; isif = 0
    while (j <= CN[d, c]) {
      w1 = CW[d, c, j]
      if (w1 == "!") neg = 1
      else if (w1 == "if") isif = 1
      else if (w1 == "case") { PARTIAL = 1; j = CN[d, c] + 1; break }
      else if (w1 !~ /^(then|do|else|elif|while|until|time|fi|done|esac)$/) break
      j++
    }
    while (j <= CN[d, c] && CW[d, c, j] ~ /^[A-Za-z_][A-Za-z0-9_]*=/) {
      a = index(CW[d, c, j], "="); nm = substr(CW[d, c, j], 1, a - 1); val = expand(substr(CW[d, c, j], a + 1))
      VAR[nm] = UNRES ? S3 : val; j++
    }
    if (j > CN[d, c]) continue
    cmd = expand(CW[d, c, j])
    if (UNRES) { PARTIAL = 1; continue }
    if (cmd == "env" || cmd == "command") { j++; while (j <= CN[d, c] && CW[d, c, j] ~ /^[A-Za-z_][A-Za-z0-9_]*=/) j++; cmd = expand(CW[d, c, j]) }
    sub(/^.*\//, "", cmd)
    if (cmd == "[" || cmd == "test") {
      if (CW[d, c, j + 1] == "-n") settle(d, c, j + 2, insub, neg)
      else if (cmpok(CW[d, c, j + 2], CW[d, c, j + 3]) && (cmd == "[" ? (CN[d, c] == j + 4 && CW[d, c, j + 4] == "]") : CN[d, c] == j + 3)) settle(d, c, j + 1, insub, neg)
      continue
    }
    if (cmd == "cmp") { if (!insub && !neg && j == 1) cmpanchor(d, c); continue }
    NF2 = 0; PAT = ""; QUIET = 0; INV = 0; EXEMPT = 0; GITDD = 0; isg = 0
    if (cmd == "grep" || cmd == "egrep" || cmd == "fgrep") { isg = 1; pgrep(d, c, j + 1, 0) }
    else if (cmd == "awk" || cmd == "gawk" || cmd == "nawk") pawk(d, c, j + 1)
    else if (cmd == "sed") psed(d, c, j + 1)
    else if (cmd == "cat") pcat(d, c, j + 1)
    else if (cmd == "git") {
      a = CW[d, c, j + 1]
      if (a == "grep") { isg = 1; pgrep(d, c, j + 2, 1) }
      else if (a == "show") pshow(d, c, j + 2)
      else { if (substr(a, 1, 1) == "-") PARTIAL = 1; continue }
    }
    else continue
    if (EXEMPT) continue
    if (CIN[d, c] != "") F[++NF2] = CIN[d, c]
    anc = ""
    # An INVERTED grep (-v) matches any line lacking the pattern, so it is never an anchor.
    if (isg && QUIET && !INV && NF2 == 1 && !insub && !CLVL[d, c]) {
      p = rpath(F[1])
      if (p != "" && patok(PAT, p)) {
        if (!neg && chain9(d, c)) anc = p
        else if (neg && isif && (CSEP[d, c] == ";" || CSEP[d, c] == "\n") && then9(d, c + 1)) anc = p
      }
    }
    # A read piped into `grep -q . || exit 9`: the stage's output is empty exactly when its pattern
    # matched nothing, so a non-vacuous pattern anchors its one path.
    if (anc == "" && !INV && NF2 == 1 && !insub && !CLVL[d, c] && !neg && CSEP[d, c] == "|" && grepdot(d, c + 1) && chain9(d, c + 1)) {
      p = rpath(F[1])
      if (p != "" && patok(PAT, p)) anc = p
    }
    # `grep -q <pat> <<<"$NAME" || exit 9` over a capture NAME of P anchors P with that pattern,
    # whatever read took the capture (a `grep -v` comment strip included): its CONTENT is P's lines.
    if (isg && QUIET && !INV && NF2 == 0 && !insub && !CLVL[d, c] && !neg && chain9(d, c)) {
      a = CHS[d, c]
      if (length(a) > 2 && substr(a, 1, 1) == S2 && substr(a, length(a), 1) == S2) hsettle(substr(a, 2, length(a) - 2))
    }
    # An awk or sed over one path written by `>` to a copy: the read waits for `cmp -s P copy && exit 9`.
    cpk = ""
    if (!isg && !INV && NF2 == 1 && COUT[d, c] != "" && !insub && !CLVL[d, c]) cpk = S6 expand(COUT[d, c])
    for (i = 1; i <= NF2; i++) {
      p = rpath(F[i])
      if (p == "") continue
      TRK = 1
      if (p in ANC) continue
      if (p == anc) { ANC[p] = 1; NANC++; continue }
      # A capture's read waits: PEND for one a `[ -n ]` or a count compare may settle (a non-inverted
      # read with a non-vacuous pattern), PENDX for one only a here-string anchor settles.
      if (cap != "" && !INV && patok(PAT, p)) { PEND[cap] = PEND[cap] S4 p; continue }
      if (cap != "") { PENDX[cap] = PENDX[cap] S4 p; continue }
      if (cpk != "" && patok(PAT, p)) { PEND[cpk] = PEND[cpk] S4 p; continue }
      if (REF == "") REF = p
    }
  }
}
BEGIN {
  S1 = sprintf("%c", 1); S2 = sprintf("%c", 2); S3 = sprintf("%c", 3); S4 = sprintf("%c", 4); S5 = sprintf("%c", 5); S6 = sprintf("%c", 6)
  while ((rc = (getline l < TRL)) > 0) { TR[l] = 1; p = l; while (sub(/\/[^\/]*$/, "", p)) { if (p in TD) break; TD[p] = 1 } }
  if (rc < 0) { print "R10-ERROR the tracked list " TRL " could not be read"; ERR = 1; exit 2 }
  close(TRL)
}
FNR == 1 { LBL = $0; next }
FNR == 2 {
  r = $0
  if (r == "sh") r = ""; else sub(/^sh /, "", r)
  delete VAR; delete ANC; delete PEND; delete PENDX
  NANC = 0; PARTIAL = 0; REF = ""; TRK = 0
  lex(r, 1); walk(1, 0, "")
  for (nm in PEND) if (PEND[nm] != "" && REF == "") { REF = substr(PEND[nm], 2); sub(S4 ".*$", "", REF) }
  for (nm in PENDX) if (PENDX[nm] != "" && REF == "") { REF = substr(PENDX[nm], 2); sub(S4 ".*$", "", REF) }
  st = (REF != "") ? "UNANCHORED" : (TRK ? "ANCHORED" : "NO-TRACKED-READ")
  if (REF != "") NU++; else if (TRK) NA++
  if (PARTIAL) NP++
  printf "%s\t%s\t%s\t%s\n", LBL, st, (REF != "" ? REF : "-"), (PARTIAL ? "partial" : "full")
  NSCAN++
}
END { if (ERR) exit 2; printf "R10-COUNTS %d %d %d %d\n", NSCAN, NU, NA, NP }
AWK
}
# r10_judge <subject-root> <record-file>... -> the rows and the R10-COUNTS line; 2 when the tracked
# list could not be read, which is a refusal and never an empty population.
r10_judge() {
  _r10_root="$1"; shift
  git -C "$_r10_root" -c core.quotePath=false ls-files > "$WORK/r10.tracked" 2>/dev/null || return 2
  [ -s "$WORK/r10.tracked" ] || return 2
  [ -s "$WORK/r10.awk" ] || r10_awk_prog > "$WORK/r10.awk"
  awk -v ROOT="$_r10_root" -v TRL="$WORK/r10.tracked" -f "$WORK/r10.awk" "$@"
}
# r10_counts <judge output> -- lifts R10-COUNTS into R10_SCAN R10_N R10_ANC R10_PART and the rows
# into R10_ROWS, with no fork; 1 when the line is missing or does not parse.
r10_counts() {
  R10_ROWS=""; R10_SCAN=""; R10_N=""; R10_ANC=""; R10_PART=""
  case "$1" in *"R10-COUNTS "*) ;; *) return 1 ;; esac
  read -r R10_SCAN R10_N R10_ANC R10_PART <<<"${1##*R10-COUNTS }"
  R10_ROWS="${1%R10-COUNTS *}"
  case "${R10_SCAN}${R10_N}${R10_ANC}${R10_PART}" in ''|*[!0-9]*) return 1 ;; esac
  return 0
}

# ---------------------------------------------------------------------------
# R11 -- A VERIFIED SHA A BRANCH ADDS TO THE LEDGER IS ON --base (BL-874). A LANDED line written
# before the squash names the pre-squash commit, which the squash leaves unreachable from main; b245
# re-anchored six of them by hand. The release practice is now the sha-less `**LANDED (v<x>).**`
# (scripts/backlog-rotate.sh binds it to CHANGELOG.md / VERSION), and a `verified <sha>` is written
# only for a sha already on main. R11 holds that second half.
#   POPULATION: the shas of `**LANDED (v..., verified <sha>)` lines -- the rotator's anchored form,
#     so an inner PARTIAL and a dated `verified 2026-..` are never taken -- PRESENT at <head> in the
#     ledger or its archive and ABSENT from BOTH at merge-base(<base>, <head>). Keyed on the SHA, not
#     the line: a rotation moves a line between the two files and may re-prefix it, and a move is not
#     an add. Pre-existing archive lines are out of scope: 121 of them were not ancestors of
#     origin/main at 47102ad20 (BL-874's progress note), and an archive-wide arm would fail on those.
#   RULE: each sha resolves to a commit and is an ancestor of <base> itself, not of the merge-base.
#   NO MERGE-BASE (a probe repository with no origin/main, an unrelated --base): NOT DERIVED, said as
#     such in both verbosities, never a failure and never EMPTY.
#   FALSE-POSITIVE SET, MEASURED. The contract adversary replayed this population over the last 40
#     first-parent commits of origin/main, each judged with base = its parent: 20 true positives
#     (pre-squash shas the squash left unreachable) and 1 move, which this population excludes. A
#     hand re-ran the SHIPPING r11_judge (this file, sourced) over the same window, in the main
#     repository at afea572a5: `git rev-list --first-parent -40 afea572a5`, head = C, base = C^.
#     r11_judge fires on 19 distinct shas across 14 commits (0.968.0 .. 0.983.0), all 19 resolving
#     and not ancestors, out of an added population of 52. A line-keyed count over the same window
#     reads 20: one sha sits on two added lines of one commit, and R11 keys on the sha. That matches
#     the adversary's 20. A hand count of verified shas MOVED from the ledger into the archive in
#     the window read 0, against the adversary's 1; that difference is unreconciled. All 19 fired shas read not-an-ancestor of afea572a5. Same-invocation controls: a
#     `commit-tree` side commit off afea572a5 reads not-an-ancestor (rc 1), and afea572a5~3 reads
#     ancestor (rc 0). Every one of those fires is a TRUE positive, the pre-squash LANDED sha of
#     a release that has since shipped. The gate judges only the pushing branch's adds, and the
#     release practice above writes none, so the corpus ships with a ceiling of 0.
# ---------------------------------------------------------------------------
# r11_judge <root> <ledger-rel> <base> <head> -> `R11-COUNTS <derived 0|1> <mb9> <added> <fail>` then one
# `R11-FAIL\t<sha>\tv<version>\t<reason>` row per failing sha. Self-contained: no $WORK, no $AWKF.
r11_judge() {
  local _r="$1" _rel="$2" _b="$3" _h="$4" _mb _arel _rows _n=0 _f=0 _out="" _s _v
  case "$_rel" in */*) _arel="${_rel%/*}/backlog.archive.md" ;; *) _arel="backlog.archive.md" ;; esac
  _mb=""; [ -n "$_rel" ] && { _mb="$(git -C "$_r" merge-base "$_b" "$_h" 2>/dev/null)" || _mb=""; }
  if [ -z "$_mb" ]; then echo "R11-COUNTS 0 - 0 0"; return 0; fi
  _rows="$( { echo '@@R11 MB'; git -C "$_r" show "${_mb}:${_rel}" 2>/dev/null; echo; git -C "$_r" show "${_mb}:${_arel}" 2>/dev/null
              echo; echo '@@R11 HEAD'; git -C "$_r" show "${_h}:${_rel}" 2>/dev/null; echo; git -C "$_r" show "${_h}:${_arel}" 2>/dev/null; } \
    | awk '
      $0 == "@@R11 MB" { side = "mb"; next }
      $0 == "@@R11 HEAD" { side = "head"; next }
      /^(<br>)?\*\*LANDED \(v[^,]*, verified [0-9a-f]+[^0-9a-f]/ {
        s = $0; sub(/^(<br>)?\*\*LANDED \(v/, "", s); v = s; sub(/,.*/, "", v)
        sub(/^[^,]*, verified /, "", s); match(s, /^[0-9a-f]+/); s = substr(s, 1, RLENGTH)
        if (length(s) < 7) next
        if (side == "mb") was[s] = 1; else if (!(s in now)) { now[s] = v; ord[++n] = s }
      }
      END { for (i = 1; i <= n; i++) if (!(ord[i] in was)) printf "%s\t%s\n", ord[i], now[ord[i]] }')"
  while IFS="$(printf '\t')" read -r _s _v; do
    [ -n "$_s" ] || continue
    _n=$(( _n + 1 ))
    if ! git -C "$_r" cat-file -e "${_s}^{commit}" 2>/dev/null; then
      _f=$(( _f + 1 )); _out="$_out$(printf 'R11-FAIL\t%s\tv%s\tdoes not resolve to a commit' "$_s" "$_v")
"
    elif ! git -C "$_r" merge-base --is-ancestor "$_s" "$_b" 2>/dev/null; then
      _f=$(( _f + 1 )); _out="$_out$(printf 'R11-FAIL\t%s\tv%s\tis not an ancestor of %s' "$_s" "$_v" "$_b")
"
    fi
  done <<EOF
$_rows
EOF
  echo "R11-COUNTS 1 $(printf '%s' "$_mb" | cut -c1-9) $_n $_f"
  printf '%s' "$_out"
}
r11_line() { # r11_line <judge output> -> the population line, printed in both verbosities
  local _d _mb _n _f
  read -r _ _d _mb _n _f <<<"$(printf '%s\n' "$1" | sed -n '/^R11-COUNTS /p')"
  if [ "${_d:-0}" != 1 ]; then
    echo "R11-POPULATION: NOT DERIVED -- base ref '$BASE_REF' has no merge-base with HEAD in the subject repository, or the ledger is not tracked there, so no LANDED sha added on this branch was checked against it; this is not a clean result."
  elif [ "$_n" -eq 0 ]; then
    echo "R11-POPULATION: EMPTY -- 0 verified LANDED sha(s) added since merge-base $_mb; nothing was observed, which is not a clean result."
  else
    echo "R11-POPULATION: $_n verified LANDED sha(s) added since merge-base $_mb, $_f not an ancestor of $BASE_REF."
  fi
}

# ---------------------------------------------------------------------------
# R12 -- A PARTIAL LIVE ENTRY KEEPS `verify: manual` WHILE ANY OWED ITEM IS OPEN (BL-943). The rule
# was committed as prose only (docs/plans/graph-ledger-full-drain.md, the per-entry commit rule), and
# nothing enforced it. Measured at b85de402a: BL-538 is PARTIAL (its outcome line is owed) and its
# verify line ran `bash core/fixtures/process-rule-pins/run.sh --report`, the corpus arm for the
# SHIPPED prose half, so scripts/backlog-reverify.sh scored a PARTIAL entry CLOSE-CANDIDATE. BL-538
# first went `sh` at 1809d8589 (0.1000.0, receipt-bl538.sh, which already scored only the prose half)
# and 0119c6a58 (0.1019.0) repointed it at the fixture.
#   POPULATION: every LIVE entry of the ledger this run reads (the entry boundary and the label are
#     reconcile/lib.sh `ledger_entry_awk` + `backlog_entry_label_awk`). The archive is OUT of the
#     population: its entries are closed and an old PARTIAL paragraph there is history (r12_judge over
#     the archive at VERSION 0.1031.0: 857 entries, 25 PARTIAL, 0 exempt -- every LANDED there is
#     released -- and 14 that would read as findings, correctly `sh` at their close). `--archive` exits
#     before this arm.
#   GRAMMAR: an entry is PARTIAL iff any UNFENCED body line OPENS `**PARTIAL` (`^\*\*PARTIAL`), the
#     first body line or a later progress paragraph alike. Fenced is `ledger_entry_shape`s own fence
#     state, so a quoted `**PARTIAL` inside a code fence is not a marker (live fenced instances: 0).
#   RULE: a PARTIAL entry whose first `verify:` value is not the word `manual` (`^manual` followed by a
#     non-word byte or the end: `manual`, `manual -- <reason>` pass, `manualXYZ` does not) is a
#     FINDING, unless it is EXEMPT: its FIRST unfenced line opening `**LANDED (v<digit>` (optionally
#     after `<br>`) is in scripts/backlog-rotate.sh `pending()` form `**LANDED (v<n.n.n>).**` and names
#     a version v >= the tree VERSION. The comparison IS rotate's: `pending()` keyed on the first such
#     line, `vgt` field by field (copied here as r12_vgt), and `>=` is `!vgt(VERSION, v)`. An entry
#     rotate keeps live as PENDING is NOT exactly the entry R12 exempts, in two ways: at equality
#     (LANDED version == VERSION) R12 exempts by the `>=` ruling while rotate moves the entry
#     (harmless: the release commit's rotate archives it), and a FENCED LANDED line is read by
#     rotate and not by R12. VERSION is rotate's too: the
#     VERSION file at the git top level of the ledger's directory. No VERSION -> nothing is exempt (fail closed). POSITION AGAINST THE
#     PARTIAL LINES DOES NOT MATTER: the house writes the LANDED line at the TOP of the body (641 of 856
#     archived line-opening rotate-form LANDED lines are the first non-blank body line, at 230e3ccc4), above the old PARTIAL paragraph, and an
#     order rule fired on every such close. An exempt entry is closing, and R8 judges its receipt (exit
#     0 required). A RELEASED LANDED (v < VERSION) does not exempt, so an entry that landed a half
#     earlier and went PARTIAL again still fires. One divergence from rotate, on purpose: rotate keys
#     its first LANDED line fenced or not, R12 only an unfenced one (a quoted form exempts nothing).
#   TIER: ERROR, ceiling 0. The false-positive path is closed: a PARTIAL whose owed work all landed
#     carries a pending LANDED line and is exempt until its release, then rotates out of the live ledger.
#   RE-ENTRY: a run re-entered from inside a receipt (BR_RECEIPTS_RUNNING) exits 1 on an R12 finding,
#     by design: R12 is text-only and runs no receipt, so it judges the ledger there too.
#   FALSE-POSITIVE SET, MEASURED: at b85de402a exactly {BL-538} (11 live PARTIAL entries, 14 line-
#     opening `**PARTIAL` lines, 2 opening the body and 12 later); after BL-538 went back to
#     `verify: manual`, {} (0). Both by r12_judge itself over the two ledger blobs, re-taken under the
#     version rule at VERSION 0.1031.0: R12-COUNTS 49 11 0 at b85de402a and 50 11 0 at 230e3ccc4 (no
#     live entry carries a line-opening LANDED line, so the rule change moves neither set).
#   HOW IT GOT THERE (narrowing): live-only; line-opening, unfenced `**PARTIAL` (an unanchored
#     `\*\*PARTIAL` admits prose that cites the word: 24 live entries mention PARTIAL mid-line); a
#     `manual` WORD prefix so `verify: manual -- <reason>` passes and `manualXYZ` does not; the
#     pending-LANDED exemption (version >= VERSION), keyed on the first LANDED line as rotate keys it.
#   COST OF THE RULE: it forbids one historically correct form, BL-159 (a PARTIAL whose sh receipt
#     exited 1 while open and 0 at close). The alternative not taken is "open, PARTIAL, sh, base exit
#     0", which the scorer could compute; it is a receipt judgment, and this arm is a text rule.
#   WHAT IT CANNOT SEE (its zero is a floor): 13 live entries saying stays/still/remains PARTIAL in
#     prose with no `**PARTIAL` line (all `manual` today), a `**PARTIAL` mid-line after another
#     bold token (0 live, 1 archived: BL-664), and the one-line form `**PARTIAL ...<br>**LANDED (v...`
#     (PARTIAL and LANDED on one physical line, so the LANDED half opens no line and exempts nothing):
#     UNSEEN, 0 live and 0 archived by `^\*\*PARTIAL.*<br>\*\*LANDED \(v[0-9]`, beside the control
#     `.<br>\*\*LANDED \(v[0-9]` (a mid-line `<br>` LANDED on any line): 0 live, 1 archived, BL-673,
#     inside its receipt text and not on a PARTIAL line. Measured at 230e3ccc4.
#   COST: one awk pass over the ledger file the validator already reads; no fork per entry.
# ---------------------------------------------------------------------------
# r12_judge <ledger-file> [--counts] -> one `R12 <BL-id>` line per finding, then (with --counts) one
# `R12-COUNTS <entries> <partial> <exempt>` line. Returns 0 with no finding, 1 with any, 2 when it
# cannot read. Self-contained: no $WORK, no $AWKF; it loads reconcile/lib.sh itself when sourced alone.
r12_judge() {
  # An unreadable or absent ledger is refused by awk itself (it exits 2 on a file it cannot open), so
  # no metadata test precedes the read (S15 of validate-shell-portability.sh). VERSION is read as
  # backlog-rotate.sh reads it, from the git top level of the ledger's directory. An unreadable VERSION
  # is empty, and an empty VERSION exempts nothing.
  local _l="$1" _m="" _v="" _d _t _p _o _f
  shift
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --counts)  _m="--counts" ;;
    esac
    shift
  done
  _d="${_l%/*}"; [ "$_d" = "$_l" ] && _d="."
  _t="$(git -C "$_d" rev-parse --show-toplevel 2>/dev/null)" || _t=""
  [ -n "$_t" ] && { read -r _v < "$_t/VERSION" || :; } 2>/dev/null
  if ! declare -F ledger_entry_awk >/dev/null || ! declare -F backlog_entry_label_awk >/dev/null; then
    _d="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)" || return 2
    while [ "$_d" != "/" ] && [ ! -f "$_d/VERSION" ]; do _d="$(dirname "$_d")"; done
    [ -f "$_d/core/skills/ai-dlc-update/reconcile/lib.sh" ] || return 2
    # shellcheck source=../core/skills/ai-dlc-update/reconcile/lib.sh
    . "$_d/core/skills/ai-dlc-update/reconcile/lib.sh" || return 2
  fi
  _p="$(ledger_entry_awk; backlog_entry_label_awk)" || return 2
  _o="$(awk -v VER="$_v" "$_p"'
# r12_vgt(a, b): a > b numerically, field by field -- backlog-rotate.sh vgt, copied (no shared one exists).
function r12_vgt(a, b,   x, y, na, nb, n, i) {
  na = split(a, x, "."); nb = split(b, y, "."); n = (na > nb) ? na : nb
  for (i = 1; i <= n; i++) { if ((x[i] + 0) > (y[i] + 0)) return 1; if ((x[i] + 0) < (y[i] + 0)) return 0 }
  return 0
}
# r12_pending(s): s, the entry s FIRST rotate-form LANDED line, is in backlog-rotate.sh pending() form
# and names a version v >= VER. No VER -> 0 (fail closed: nothing is exempt).
function r12_pending(s,   v) {
  if (VER == "" || s !~ /^(<br>)?\*\*LANDED \(v[0-9][0-9.]*\)\.\*\*/) return 0
  v = s; sub(/^(<br>)?\*\*LANDED \(v/, "", v); sub(/\).*$/, "", v)
  return !r12_vgt(VER, v)
}
function r12_flush() {
  if (lbl == "") return
  ne++
  if (part) {
    np++
    if (ex) nx++
    else if (rec !~ /^manual([^A-Za-z0-9_]|$)/) printf "R12 %s\n", lbl
  }
  lbl = ""; part = 0; lsn = 0; ex = 0; rec = ""; seen = 0
}
{
  l = backlog_entry_label($0)
  if (l != "") { r12_flush(); lbl = l; next }
  if (lbl == "") next
  if (!__lef_in) {
    if ($0 ~ /^\*\*PARTIAL/) part = 1
    if (!lsn && $0 ~ /^(<br>)?\*\*LANDED \(v[0-9]/) { lsn = 1; ex = r12_pending($0) }
  }
  if (!seen && $0 ~ /^[ \t]*verify:/) { seen = 1; rec = $0; sub(/^[ \t]*verify:[ \t]*/, "", rec) }
}
END { r12_flush(); printf "R12-COUNTS %d %d %d\n", ne, np, nx }' "$_l")" || return 2
  _f="$(printf '%s\n' "$_o" | sed -n '/^R12 /p')"
  [ -n "$_f" ] && printf '%s\n' "$_f"
  [ "$_m" = "--counts" ] && printf '%s\n' "$_o" | sed -n '/^R12-COUNTS /p'
  [ -z "$_f" ]  || return 1
  return 0
}

# ---------------------------------------------------------------------------
# R14 -- A LIVE LANDED LINE IS IN A FORM scripts/backlog-rotate.sh MOVES (BL-1147). Rotate keys an entry's close on
# its FIRST line opening `(<br>)?**LANDED (v<digit>` (fenced or not) and moves it only when that line is one of the two
# forms of its LANDED_FORM span; any other form reads `sha ABSENT` and REFUSES the release's rotate, after every
# builder check and pregate passed.
#   POPULATION: every LIVE entry's first line opening `(<br>)?**LANDED (v`, after `vVERSION_PLACEHOLDER` is stamped
#     to `v0.0.0` (a builder's line names no version until the squash; the stamp is the lead's). The archive is OUT:
#     `--archive` exits before this arm.
#   GRAMMAR: LOADED, never restated. The `# LANDED_FORM_BEGIN` .. `# LANDED_FORM_END` span of backlog-rotate.sh
#     (beside this script) is extracted once per run and its `landed_form` applied to each line; empty LF_SHA AND
#     LF_SLV is a finding. A missing span, or one that defines no landed_form, is a refusal (exit 2), never a pass.
#   SCOPE: LANDED only. A PARTIAL line never rotates, and `**PARTIAL (vVERSION_PLACEHOLDER; ...)` is a legal form.
#   TIER: ERROR, ceiling 0.
#   FALSE-POSITIVE SET, MEASURED: {} (0), by r14_judge itself at edb812bc1. Population: the 1040 archived LANDED
#     lines (every one an entry's first, R14-COUNTS 1040), each a line rotate has already moved; applying the loaded
#     landed_form to every line opening `(<br>)?**LANDED (v` there reads 820 sha + 220 sha-less, 0 neither. The live
#     ledger carries 0 LANDED lines (they rotate out), so the archive is the corpus that discriminates. Positive
#     control: a seeded `**LANDED (vVERSION_PLACEHOLDER; batch 1, W1).**` line FIRES, and `**LANDED
#     (vVERSION_PLACEHOLDER).** (prose)`, a `(v.., verified <sha>)` line and a `**PARTIAL (vVERSION_PLACEHOLDER; ..)`
#     line stay quiet. HOW IT GOT THERE: no narrowing was needed; the grammar is rotate's own.
#   COST: one sed extraction of the span per run and one awk pass over the ledger; then landed_form's two sed forks
#     per live LANDED line (a handful on a release branch, 0 on main).
# ---------------------------------------------------------------------------
# r14_judge <ledger-file> <backlog-rotate.sh> -> one `R14 <BL-id>\t<line>` per finding, then one
# `R14-COUNTS <landed lines>` line. Returns 0 with no finding, 1 with any, 2 when it cannot read either file.
r14_judge() {
  local _l="$1" _r="$2" _span _p _o _lb _ln _n=0 _f=""
  _span="$(sed -n '/^# LANDED_FORM_BEGIN$/,/^# LANDED_FORM_END$/p' "$_r" 2>/dev/null)" || return 2
  [ -n "$_span" ] || return 2
  eval "$_span" || return 2
  declare -F landed_form >/dev/null || return 2
  if ! declare -F ledger_entry_awk >/dev/null || ! declare -F backlog_entry_label_awk >/dev/null; then
    return 2
  fi
  _p="$(ledger_entry_awk; backlog_entry_label_awk)" || return 2
  _o="$(awk "$_p"'
{
  l = backlog_entry_label($0)
  if (l != "") { lbl = l; got = 0; next }
  if (lbl == "" || got) next
  if ($0 ~ /^(<br>)?\*\*LANDED \(v/) { got = 1; printf "%s\t%s\n", lbl, $0 }
}' "$_l")" || return 2
  while IFS="$(printf '\t')" read -r _lb _ln; do
    [ -n "$_lb" ] || continue
    _n=$((_n + 1))
    landed_form "${_ln//vVERSION_PLACEHOLDER/v0.0.0}"
    [ -z "$LF_SHA" ] && [ -z "$LF_SLV" ] && _f="$_f$(printf 'R14 %s\t%s' "$_lb" "$_ln" | cut -c1-200)
"
  done <<R14_EOF
$_o
R14_EOF
  [ -n "$_f" ] && printf '%s' "$_f"
  printf 'R14-COUNTS %d\n' "$_n"
  [ -z "$_f" ] || return 1
  return 0
}


# ===========================================================================
# M1 AND R13 -- A RECEIPT THAT STOPS MEASURING WHEN A FILE IT READS IS REMOVED (BL-899).
#
# M1, driver-absent. A receipt `bash <P>` whose own driver P is gone exits 127 with bash's
#   `bash: <P>: No such file or directory`, and cant_measure (keyed on `$SELF_NAME: line`) never
#   saw it, so a renamed driver was invisible to R7 for EVERY driver receipt. m1_driver_absent is
#   the fourth cannot-measure route, decided in the WORKER (cm_reason) and keyed on the receipt's
#   OWN operand only: every `bash [-opts] <P>` segment of the top-level `&&` chain, in order, until
#   a segment of any other shape (a `cd` before it moves the operand). Conjuncts: exit 127 (or 1 when an option precedes P), `[ ! -e <tree>/<P> ]`, and the exact
#   stderr line for THAT P. Lead ruling L3 (ai-dlc-a7, batch 256), applied where it is decided:
#     (a) driver present at HEAD: judged normally;
#     (b) absent at HEAD and at --base: EXCLUDED-DRIVER-ABSENT-AT-BASE, counted separately, no
#         cannot-measure member (an unbuilt fix's script; its baseline is 127 by construction);
#     (c) absent at HEAD, present at --base: a FINDING, driver-absent/DRIVER-REMOVED;
#     (d) --base not given or not resolving: nothing excluded, driver-absent/
#         DRIVER-ABSENT-UNRESOLVED-BASE, a finding (fail closed).
#   "Present at --base" is `git cat-file -e "${BASE}:${P}"`. M1 lives HERE and not in
#   scripts/backlog-receipt-lib.sh because only this validator has a base to compare; the two
#   programs therefore differ by exactly this base-dependent route, which both files record.
#   THE FALSE-POSITIVE CENSUS (batch 257, at 27fded102, by this file's `--r13-drive score` over a ledger of the
#   archive's receipts). A false positive is a driver-absent label on a receipt whose exit its own absent driver did
#   not cause. docs/backlog.archive.md holds 810 column-0 `verify: sh` receipts (and 2 indented ones, neither a driver
#   receipt); 138 have a driver segment (m1_driver_ops); in 84 the FIRST segment's driver is absent at HEAD, and in
#   none is only a later segment's driver absent. All 84 exit 127 and read EXCLUDED-DRIVER-ABSENT-AT-BASE at --base
#   origin/main (= HEAD); at --base 20784dea2 (before those drivers were deleted) 81 read DRIVER-REMOVED and 3
#   EXCLUDED. 0 are false: a first-segment `bash <absent P>` runs nothing else. NOT EXECUTED, AND AVAILABLE: the 54
#   whose drivers are all present (the `[ ! -e ]` conjunct cannot hold; read from the code and an `-e` test, not a
#   run; some recurse into pre-push) and the 672 with no driver segment (m1_driver_ops prints nothing). The open
#   ledger's one sh receipt (BL-878) has its driver present. None of the 84 carries an option before P, so the exit-1
#   admission is held by core/fixtures/backlog-receipt-traced-removal's world m (`bash -e w/never2.sh`).
#   `bash A && bash B` with a present A is 0 in the corpus. The fixture's c-m1-chain cell calls m1_driver_absent
#   in process: a present A that exits 1 after printing B's diagnostic admits nothing, while `-e` before B, or
#   exit 127, names B. No real-worker run drives the chain.
#
# R13, traced removal over the NAMED closure (`--traced-removal`, which the hook passes; a run
#   without it prints `R13-POPULATION: NOT RUN`, so the fixtures that drive this file over seeded
#   ledgers never start it). Population: every open `verify: sh` receipt R2 runs.
#   WHAT DECIDES "READ": atime after a forced epoch, the instrument `.githooks/pre-push` uses for its
#   pre-suite step keys (comment :135-148, pk_reset_all and the canary :260-268). Before the baseline
#   run the worker forces every path of its checkout (outside .git) and a control file beside it
#   to 2000-01-01 00:00; after it, every tracked file whose atime is newer than a 00:01 mark was
#   READ. The baseline IS R2's own run: same eval, `$0`, stdin, and environment except one variable set:
#   core.trustctime=false, exported inside the eval's own subshell (r13_eval_env), because the epoch
#   moves every ctime and a git that refreshes the index would otherwise re-read the whole tree. Before
#   the epoch the checkout's index is settled (r13_settle_index) so no entry is racily clean or smudged.
#   THE INSTRUMENT IS PROVED BEFORE IT IS USED: r13_instrument_probe, in `$WORK` beside the
#   checkouts, must see a cat move atime, an unopened file not move, and a second read after a
#   second reset move again; anything else prints `R13-INSTRUMENT-REFUSED <which>` and R13 refuses,
#   exit 2. The third check catches noatime and a filesystem that records only a first access; it does
#   NOT catch relatime, which the 2000 epoch defeats by design (an atime older than mtime always moves).
#   Per receipt a must-miss control (an unread file reset by the same find) and a must-hit control
#   (the driver, the one file a `bash <P>` receipt is KNOWN to read, `./` normalised) refuse that
#   receipt when either fails. And for EVERY receipt that names a file, a read set holding none of
#   its named files refuses it (`R13-NO-NAMED-READ <id>`, exit 2, no record): that covers the receipts
#   with no driver for must-hit (`cd x && bash P`, grep-only). named > 0 with removed = 0 is a
#   refusal, never a clean line. And R13's traced count plus R2's refused-before-checkout count must
#   equal the sh population R2 scored, or R13 refuses (`R13-UNTRACED <n>`, exit 2).
#   RECORDED BLIND SPOT: a stat-only read (`[ -f ]`, `test -e`, a stat) moves no atime and is not
#   seen; such a file is counted named-unread and is not removed.
#   RECORDED LIMIT: each removal commits on a detached state, so it writes objects into the subject's
#   common object store (unreachable, left to gc), and a receipt that reads HEAD's log in a removal
#   run sees that removal commit.
#   WHY NOT THE SANDBOX TRACER (BL-899's title): `log stream` drops reports under load
#   (core/scripts/derive-fixture-readsets.sh:11, :1816) and BL-868 forbids a load-dependent
#   verdict. The operator ruled atime for this arm (batch 256).
#   NAMED: a fixed point over NAMED SCRIPTS from the receipt text (B1): a path token resolved
#   against the referencing script's directory (`$HERE/`, `$DIR/`, `$(dirname "$0")/`, `./`, `../`)
#   or the repo root (`$ROOT/`, `$root/`, bare) that is TRACKED (B2), read from EXECUTABLE lines
#   only (a line whose first non-blank character is `#` is dropped), and every named `*.sh` or
#   shell-shebang file the closure EXECUTES (the expansion rule below) read the same way. Basename
#   matching is forbidden. A VARIABLE-BUILT path is named when the same text assigns the variable a
#   literal path (`V=w/d` or `V="w/d"`, outside an open quote; any later non-literal assignment to V in the
#   scope forgets it) and
#   then reads `$V/<literal>` or `${V}/<literal>`: the joined path resolves as a bare token does, so it is
#   removed ALONE like any named read. A path built from any other variable (a loop or glob member, a
#   computed value) is not named: NAMED IS A FLOOR, and every traced read outside it is
#   ENUMERATED -- counted on the population line every run and removed TOGETHER in one extra
#   removal per judged receipt (row path `ENUMERATED(<n>)`), judged as a named removal is: a receipt
#   that still answers 0 or 1 with every enumerated input gone is measuring an empty population. A
#   single enumerated file is never removed alone. The removal set is
#   NAMED ∩ READ; a named file the baseline did not read is counted named-unread.
#   HOW THE NAMED SET REACHED ITS SHAPE (the narrowing, measured by the owner's reference closure script over base
#   0bb1ee28d, batch 256): with comment lines included the closure SATURATED at 340 files for every seed, through the
#   hub scripts/validate-enforcement-map.sh, whose comments alone add 128-139 paths; executable lines
#   only, the archived BL-981 shape names 163, and BL-878 (`bash scripts/validate-fixture-inprocess.sh
#   --complete`) names 14, of which 6 of its 892 traced reads are named (886 enumerated). The third
#   saturation was measured on a scratch combine with a sibling bundle (batch 256): a self-probe in
#   scripts/validate-fixture-invocations.sh names scripts/validate-enforcement-map.sh inside a printf
#   string and a function argument, on executable lines, and BL-878 then read `R13-NAMED-OVERFLOW
#   BL-878 126` (176 named). So EXPANSION IS RESTRICTED TO EXECUTION EDGES: every resolved token on an
#   executable line of the receipt or of an EXPANDED script is still NAMED, but a named script is
#   EXPANDED (its own text read) only when that text EXECUTES it -- the token is the operand of bash or
#   sh (options allowed), `.`, `source` or `exec`, or the command word (line start, or after `&&`, `||`,
#   `;`, `|`, `$(` or `(`), or it is assigned to a variable (`V=path`) that the same text executes by
#   one of those forms. A token inside an open quote (counted after the last `$(`) is never an
#   execution edge. Measured by a byte comparison against an independent python reference of the same
#   rule: BL-878 names 8 on that combine and 7 at this release's tip, the archived BL-981 shape 131 on
#   both, identical sets. A receipt whose removal set exceeds R13_MAX_REMOVALS (32) prints
#   `R13-NAMED-OVERFLOW <id> <n>` and is REFUSED, never truncated.
#   REMOVAL: per P, a fresh checkout of HEAD, `git rm` P and a commit on the private detached state
#   (gone from disk and from ls-files, the tree clean -- asserted), then the receipt exactly as R2
#   runs it. PASS when cm_reason, M1 included, names a member; otherwise `UNGUARDED-READ <id> <P>
#   exit=<n>`. L3 compares a removal against the PRE-REMOVAL HEAD, because a removal stands for a
#   rename inside a release and a driver new on the branch is absent at --base. Width 4, never wider.
#   Ceiling DEFAULT_MAX_R13 (`--max-unguarded`, AI_DLC_BACKLOG_MAX_UNGUARDED).
#   THE RECORD (M3): on a run whose UNGUARDED-READ count is within the ceiling (owner ruling, batch 256), every
#   judged receipt writes `<K>.green` -- the manifest, a `#r13-rows` line, a `#r13-pop <named removals> <named-unread> <enumerated>` line (a replay re-prints those figures labelled replayed, so the enumerated exclusion is said on every run), and its rows VERBATIM -- in
#   `<subject common dir>/ai-dlc-r13-records/` (BR_R13_RECORD_DIR overrides; the hook never sets it),
#   by a temp file and a move. K is the `git hash-object` of the manifest: this file's,
#   backlog-receipt-lib.sh's and reconcile/lib.sh's blob ids, $BASH_VERSION, `git --version`, the
#   `command -v` paths of the tools R13 runs, the OS version, whether --base resolves, the entry label (two entries with one receipt text keep two records), the receipt
#   text, and each NAMED path with its blob id at HEAD and its presence at --base. A record whose
#   manifest half equals the manifest REPLAYS that receipt: no epoch, no removal, and its stored rows are
#   printed and counted against --max-unguarded exactly as the live run's were, so a lowered ceiling fails a
#   replay as it fails a live run. A red R13, a refusal, an OVERFLOW, an instrument refusal, a must-hit
#   failure, and an EXCLUDED or BASELINE-CM receipt write nothing. RECORDED LIMIT: a change only to an
#   ENUMERATED file does not move K.
#   TEST SEAM BR_R13_PROBE_DIR: an absolute directory r13_instrument_probe uses in place of `$WORK/r13i`. It
#   creates only the probe files that are ABSENT, so a caller can pre-place one (an unreadable `read`, mode
#   0200) and DRIVE a refusal. The hook never sets it. Its limit: pointed elsewhere, the probe proves atime on
#   THAT filesystem, not on the one the checkouts are made on.
# ===========================================================================
# DEFAULT_MAX_R13 -- DERIVED AT BUILD FROM THE FINAL BASE; RE-MEASURED AFTER REBASE (lead ruling, batch 256). It is a
# TWO-SIDED RATCHET: the run FAILS when the live UNGUARDED-READ count is ABOVE it, and ALSO when it is BELOW it (a
# stale-high ceiling hides a regrowth, as in the fork-budget gate), with a message naming the live count to lower it
# to. `--max-unguarded` / AI_DLC_BACKLOG_MAX_UNGUARDED keep the same two-sided meaning.
# THE THREE ROWS, all against BL-878's receipt (`bash scripts/validate-fixture-inprocess.sh --complete`, base exit 1):
# scripts/fixture-inprocess-allowlist.txt, core/fixtures/lib/mutant.sh, and ENUMERATED(<n>) (every enumerated input
# removed together). Removed, the driver exits 1 -- the receipt's own STILL-LIVE code -- on a DELETED input, which reads
# as "rows remain". R7 reads exit 1 as a measurement, so a rename of any of them would leave BL-878 with no instrument.
# scripts/validate-enforcement-map.sh, scripts/validate-fixture-hygiene.sh and scripts/validate-fixture-invocations.sh
# are guarded: under --complete the driver exits 9 when any of them is absent or unopenable (its absent_refuse, and the
# invocation judge's `A` join row for an absent cli subject), so R13 reads them as could-not-measure.
# Any release that moves BL-878's unguarded count (rotating BL-878, or changing its driver or the files it reads) must
# edit DEFAULT_MAX_R13 in scripts/validate-backlog-receipts.sh in the same commit; the two-sided ceiling fails the
# 'backlog receipts' step otherwise.
DEFAULT_MAX_R13=3
R13_MAX_REMOVALS=32

# THE FIXTURE'S CHEAP MODE (fixture-mutants.md clause 5), never passed by the hook. core/fixtures/
# backlog-receipt-traced-removal starts this file as ONE tagged `cli` start per distinct state, so the workers each
# start launches are covered by its single self-nested cells.decl row; a full CLI run per state would run R10-R12 and
# the efficiency arms for nothing. After vbr_sec_setup it runs exactly one of:
#   --r13-drive corpus   r13_arm, the corpus score_ledger, r13_corpus      prints `R13-RC <rc>`
#   --r13-drive score    the corpus score_ledger's rows                    (the M1 rows of a seeded ledger)
vbr_r13_drive() {
  case "$R13_DRIVE" in
    corpus) r13_arm; OUT="$(score_ledger "$LEDGER" "$SUBJECT_ROOT")" || exit 2; read_counts
            r13_corpus; _vd_rc=$?; echo "R13-RC $_vd_rc"; exit "$_vd_rc" ;;
    score) score_ledger "$LEDGER" "$SUBJECT_ROOT" || exit 2; exit 0 ;;
    *) echo "$(me): FAIL -- --r13-drive takes corpus or score, not '$R13_DRIVE'" >&2; exit 2 ;;
  esac
}

# --- M1 ----------------------------------------------------------------------
# m1_l3_base <root> -> the commit --base resolves to in <root>, or nothing (L3 (d)).
m1_l3_base() { git -C "$1" rev-parse --verify -q "${BASE_REF:-origin/main}^{commit}" 2>/dev/null || true; }

# m1_base_check -- LEAD RULING A (batch 256): a --base that was GIVEN and does not resolve to a commit in the subject
# root refuses the whole run before anything is scored: `M1-BASE-UNRESOLVED: <reason>` and the remedy, exit 2. This is
# a refusal, never a per-receipt finding. The hook always passes `--base origin/main`. With no --base at all (every
# other caller) nothing is refused here, BASE_REF keeps its default origin/main, and L3 is judged against it per
# receipt; only where origin/main does not resolve in the subject root does L3 (d) apply: DRIVER-ABSENT-UNRESOLVED-BASE,
# a finding.
m1_base_check() {
  [ "${BASE_GIVEN:-0}" = 1 ] || return 0
  git -C "$SUBJECT_ROOT" rev-parse --verify -q "${BASE_REF}^{commit}" >/dev/null 2>&1 && return 0
  echo "M1-BASE-UNRESOLVED: --base '$BASE_REF' names no commit in $SUBJECT_ROOT, so lead ruling L3 cannot tell a removed driver (a finding) from one never built (excluded)."
  echo "$(me): FAIL -- M1-BASE-UNRESOLVED. REMEDY: run \`git fetch origin\`, or pass --base <ref> naming a commit that resolves in $SUBJECT_ROOT. Nothing was scored; this is a refusal, not a reading." >&2
  exit 2 # M1-BASE-UNRESOLVED refuses
}

# m1_driver_ops <receipt> -> one "<opt 0|1> <P>" line per `bash [options] <P> [plain args]` segment of the
# top-level `&&` chain, in order, stopping at the first segment of any other shape. Options: short flags (`-e`,
# `-ex`), long flags (`--norc`), and the four that take the next word (`-o <opt>`, `-O <opt>`, `--rcfile <f>`,
# `--init-file <f>`). P is printed as written (bash names it that way in its diagnostic); r13_pre normalises `./`.
m1_driver_ops() {
  awk '{
    ns = split($0, SEG, /&&/)
    for (k = 1; k <= ns; k++) {
      s = SEG[k]; sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s)
      nw = split(s, T, /[ \t]+/)
      if (nw < 2 || T[1] != "bash") exit 0
      o = 0; i = 2
      while (i <= nw && substr(T[i], 1, 1) == "-") {
        if (T[i] == "-o" || T[i] == "-O" || T[i] == "--rcfile" || T[i] == "--init-file") { o = 1; i += 2; continue }
        if (T[i] ~ /^--[a-z][a-z-]*$/) { o = 1; i++; continue }
        if (T[i] ~ /^-[A-Za-z]+$/) { o = 1; i++; continue }
        exit 0
      }
      if (i > nw) exit 0
      p = T[i]
      if (p !~ /^[A-Za-z0-9_.\/][A-Za-z0-9_.\/-]*$/ || p ~ /^\//) exit 0
      for (j = i + 1; j <= nw; j++) if (T[j] !~ /^[A-Za-z0-9_.=\/,:+-]+$/) exit 0
      print o " " p
    }
  }' <<<"$1"
}

# m1_driver_absent <rc> <stderr-file> <tree> <receipt> -> driver-absent/DRIVER-REMOVED,
# driver-absent/DRIVER-ABSENT-UNRESOLVED-BASE, EXCLUDED-DRIVER-ABSENT-AT-BASE, or nothing.
m1_driver_absent() {
  local _rc="$1" _err="$2" _tree="$3" _o _p
  case "$_rc" in 127|1) ;; *) return 0 ;; esac
  [ -n "$_tree" ] && [ -f "$_err" ] || return 0
  while read -r _o _p; do
    [ -n "$_p" ] || continue
    [ "$_rc" = 127 ] || [ "$_o" = 1 ] || continue
    [ ! -e "$_tree/$_p" ] || continue
    grep -qxF -- "bash: $_p: No such file or directory" "$_err" || continue
    if [ -z "${BR_L3_BASE:-}" ]; then printf 'driver-absent/DRIVER-ABSENT-UNRESOLVED-BASE'
    elif git -C "$_tree" cat-file -e "${BR_L3_BASE}:${_p}" 2>/dev/null; then printf 'driver-absent/DRIVER-REMOVED'
    else printf 'EXCLUDED-DRIVER-ABSENT-AT-BASE'; fi
    return 0
  done <<EOF
$(m1_driver_ops "$4")
EOF
  return 0
}

# --- R13 ---------------------------------------------------------------------
# r13_named_awk <file> -- writes the NAMED-closure program. Input: the tracked list (ARGV). -v root=<tree>
# -v recf=<receipt file>. Output: the NAMED paths, then `#scanned <n> unread <u>`; exit 2 when it could not
# read its input. No apostrophe may appear in the program (it is a quoted heredoc, but kept clean anyway).
r13_named_awk() {
cat <<'AWK' > "$1"
function norm(p,    n, i, a, k, s, out) {
  if (substr(p, 1, 1) == "/") return ""
  n = split(p, a, "/"); k = 0
  for (i = 1; i <= n; i++) {
    s = a[i]
    if (s == "" || s == ".") continue
    if (s == "..") { if (k > 0 && ST[k] != "..") { k--; continue }; k++; ST[k] = ".."; continue }
    k++; ST[k] = s
  }
  if (k == 0 || ST[1] == "..") return ""
  out = ST[1]; for (i = 2; i <= k; i++) out = out "/" ST[i]
  return out
}
function jn(d, p) { return (d == "" ? p : d "/" p) }
function dirof(p,   i) { i = match(p, /\/[^\/]*$/); return (i ? substr(p, 1, i - 1) : "") }
function isdirvar(v) { return v == "HERE" || v == "DIR" || v == "here" || v == "dir" || v == "SCRIPT_DIR" || v == "FX_DIR" }
function isrootvar(v) { return v == "ROOT" || v == "root" || v == "REPO" || v == "REPO_ROOT" }
function isscript(p,   l, r, f) {
  if (p ~ /[.]sh$/) return 1
  f = root "/" p; l = ""; r = (getline l < f); close(f)
  if (r <= 0) return 0
  return (l ~ /^#!(.*[^A-Za-z0-9_])?(ba|z|da|k)?sh([^A-Za-z0-9_]|$)/)
}
# EXECUTION EDGES. unq(p): p with ONE trailing quote (the token own opening quote) removed. inq(p): 1 when p ends
# inside an open quote, counted after the last command substitution opener. isexec(pre): the text before a token
# puts the token in an executed position -- the operand of bash/sh (options allowed), dot, source or exec, or the
# command word (line start, or after a double ampersand, a double bar, a semicolon, a bar, a substitution opener or an
# open paren). asgvar(pre): the variable a token is assigned to, or nothing.
function unq(p,   e) { e = substr(p, length(p), 1); if (e == DQ || e == SQ) return substr(p, 1, length(p) - 1); return p }
function inq(p,   i, j, s, a, b) {
  i = 0; s = p
  while ((j = index(s, "$(")) > 0) { i += j + 1; s = substr(s, j + 2) }
  s = substr(p, i + 1)
  a = s; b = s
  return ((gsub(DQ, "", a) % 2) == 1 || (gsub(SQ, "", b) % 2) == 1)
}
function isexec(pre,   p) {
  p = unq(pre)
  if (inq(p)) return 0
  if (p ~ /(^|[;&|(`[:space:]])(bash|sh)([[:space:]]+-[A-Za-z-]+)*[[:space:]]+$/) return 1
  if (p ~ /(^|[;&|(`[:space:]])([.]|source|exec)[[:space:]]+$/) return 1
  if (p ~ /^[[:space:]]*$/ || p ~ /(&&|[|][|]|;|[|]|[$][(]|[(])[[:space:]]*$/) return 1
  return 0
}
function asgvar(pre,   p, v) {
  p = unq(pre)
  if (inq(p)) return ""
  if (match(p, /(^|[;&|[:space:]])[A-Za-z_][A-Za-z0-9_]*=$/) == 0) return ""
  v = substr(p, RSTART, RLENGTH); sub(/^[;&|[:space:]]/, "", v); sub(/=$/, "", v)
  return v
}
function push(c) { if (!(c in EXD)) { EXD[c] = 1; ne++; EQ[ne] = c } }
# resolve <text> <refdir>: every resolved token is NAMED; one in an executed position is queued for expansion; one
# assigned to a variable is remembered in ASG; a variable in an executed position is remembered in EXV.
function resolve(text, refdir,    rest, off, m, pre, v, path, nc, c, i, ms, ml, isx, av, vn) {
  # ASSIGNMENTS FIRST, in text order: `V=<literal path>` (unquoted or quoted, no expansion, outside an open quote)
  # is remembered in LITV for this scope, so a later `$V/<literal>` on this line or a later one resolves to a NAMED
  # token; ANY other assignment to V (an expansion, a substitution) forgets it.
  rest = text; off = 0
  while (match(rest, GASG) > 0) {
    ms = RSTART; ml = RLENGTH
    m = substr(rest, ms, ml); rest = substr(rest, ms + ml)
    pre = substr(text, 1, off + ms - 1); off = off + ms + ml - 1
    if (inq(pre)) continue
    v = m; sub(/^[;&|[:space:]]/, "", v); sub(/=$/, "", v)
    if (isdirvar(v) || isrootvar(v)) continue
    if (match(rest, LITVAL) > 0) {
      path = substr(rest, 1, RLENGTH); sub(/[;&|[:space:]]$/, "", path); gsub(DQ, "", path); gsub(SQ, "", path)
      LITV[v] = path
    } else if (v in LITV) delete LITV[v]
  }
  rest = text; off = 0
  while (match(rest, TOK) > 0) {
    ms = RSTART; ml = RLENGTH
    m = substr(rest, ms, ml); rest = substr(rest, ms + ml)
    pre = substr(text, 1, off + ms - 1); off = off + ms + ml - 1
    path = m; v = ""; vn = ""
    if (substr(m, 1, 1) == "$") {
      if (match(m, DN0) > 0 || match(m, DNB) > 0) { vn = "dirname"; path = substr(m, RLENGTH + 1) }
      else if (match(m, VARP) > 0) { v = substr(m, 1, RLENGTH - 1); gsub(/[${}]/, "", v); vn = "var"; path = substr(m, RLENGTH + 1) }
    }
    if (vn == "var" && !isdirvar(v) && !isrootvar(v)) {
      if (!(v in LITV)) continue
      path = jn(LITV[v], path); vn = ""
    }
    nc = 0
    if (vn == "dirname" || (vn == "var" && isdirvar(v))) { nc++; C[nc] = norm(jn(refdir, path)) }
    else if (vn == "var") { nc++; C[nc] = norm(path) }
    else if (substr(path, 1, 2) == "./" || substr(path, 1, 3) == "../") { nc++; C[nc] = norm(jn(refdir, path)); nc++; C[nc] = norm(path) }
    else { nc++; C[nc] = norm(path); nc++; C[nc] = norm(jn(refdir, path)) }
    for (i = 1; i <= nc; i++) {
      c = C[i]
      if (c != "" && (c in TR)) {
        if (!(c in NAMED)) { NAMED[c] = 1; nn++; NEW[nn] = c }
        isx = isexec(pre)
        if (isx) push(c)
        av = asgvar(pre); if (av != "") ASG[av] = ASG[av] " " c
        break
      }
    }
  }
  rest = text; off = 0
  while (match(rest, VREF) > 0) {
    ms = RSTART; ml = RLENGTH
    m = substr(rest, ms, ml); rest = substr(rest, ms + ml)
    pre = substr(text, 1, off + ms - 1); off = off + ms + ml - 1
    if (substr(rest, 1, 1) == "/") continue
    v = m; gsub(/[${}]/, "", v)
    if (isexec(pre)) EXV[v] = 1
  }
}
# endscope: a variable assigned a path and executed in the same text queues that path; the scope is then cleared.
function endscope(   v, n, a, i) {
  for (v in EXV) if (v in ASG) { n = split(ASG[v], a, " "); for (i = 1; i <= n; i++) if (a[i] != "") push(a[i]) }
  split("", EXV); split("", ASG); split("", LITV)
}
BEGIN {
  TOK = "([$][{]?[A-Za-z_][A-Za-z0-9_]*[}]?/|[$][(]dirname \"?[$]0\"?[)]/|[$][(]dirname \"?[$][{]BASH_SOURCE[[]0[]][}]\"?[)]/)?([.][.]?/)*([A-Za-z0-9_.-]+/)*[A-Za-z0-9_.-]+[.][A-Za-z0-9]+"
  DN0 = "^[$][(]dirname \"?[$]0\"?[)]/"
  DNB = "^[$][(]dirname \"?[$][{]BASH_SOURCE[[]0[]][}]\"?[)]/"
  VARP = "^[$][{]?[A-Za-z_][A-Za-z0-9_]*[}]?/"
  VREF = "[$][{]?[A-Za-z_][A-Za-z0-9_]*[}]?"
  DQ = "\""; SQ = sprintf("%c", 39)
  GASG = "(^|[;&|[:space:]])[A-Za-z_][A-Za-z0-9_]*="
  LITVAL = "^[" DQ SQ "]?[A-Za-z0-9_./-]+[" DQ SQ "]?([;&|[:space:]]|$)"
  nn = 0; ne = 0; ntr = 0
}
{ TR[$0] = 1; ntr++ }
END {
  if (ntr == 0) { print "#refused no-tracked-set"; exit 2 }
  r = 0
  while ((r = (getline l < recf)) > 0) resolve(l, "")
  if (r < 0) { print "#refused receipt-unread"; exit 2 }
  close(recf)
  endscope()
  q = 1; scanned = 0; unread = 0
  while (q <= ne) {
    p = EQ[q]; q++
    if (!isscript(p)) continue
    f = root "/" p; scanned++
    while ((r = (getline l < f)) > 0) {
      t = l; sub(/^[[:space:]]+/, "", t)
      if (substr(t, 1, 1) == "#") continue
      resolve(l, dirof(p))
    }
    if (r < 0) unread++
    close(f)
    endscope()
  }
  for (i = 1; i <= nn; i++) print NEW[i]
  printf "#scanned %d unread %d\n", scanned, unread
}
AWK
}

# r13_reset <tree> <control-dir> -- the forced epoch, pk_reset_all's technique: every path under <tree> outside
# .git, and the control beside it, in ONE find. Nothing may walk <tree> between this and the receipt.
r13_reset() {
  find "$1" "$2" -path "$1/.git" -prune -o -exec touch -a -h -t 200001010000 {} + 2>/dev/null
}

# r13_state <state> [detail] -- the worker's per-receipt state line.
r13_state() { printf '%s %s\n' "$1" "${2:--}" > "$BR_R13_DIR/$n.state"; }

# r13_manifest <tree> <named-file> -> the per-receipt manifest (M3's K is its blob id).
r13_manifest() {
  local _d="$BR_R13_DIR"
  printf '%s\n' "$BR_R13_KCOMMON"
  printf 'label %s\n' "$LABEL"
  printf 'receipt %s\n' "$RECEIPT"
  : > "$_d/$n.ls"; : > "$_d/$n.bc"
  if [ -s "$2" ]; then
    tr '\n' '\0' < "$2" | xargs -0 git -C "$1" ls-files -s -- > "$_d/$n.ls" 2>/dev/null || return 1
    if [ -n "${BR_L3_BASE:-}" ]; then
      awk -v b="$BR_L3_BASE" '{ print b ":" $0 }' "$2" | git -C "$1" cat-file --batch-check > "$_d/$n.bc" 2>/dev/null || return 1
    fi
  fi
  awk -F'\t' -v lsf="$_d/$n.ls" -v bcf="$_d/$n.bc" '
    BEGIN { while ((getline l < lsf) > 0) { split(l, h, "\t"); split(h[1], w, " "); B[h[2]] = w[2] }
            while ((getline l < bcf) > 0) { nb++; P[nb] = (l ~ / missing$/ ? 0 : 1) } }
    { m++; printf "named %s %s base=%s\n", $0, ($0 in B ? B[$0] : "-"), (nb ? P[m] : "-") }' "$2"
}

# r13_pre <tree> -- in the --score-one worker, BEFORE the baseline eval: the NAMED closure and the key are read
# from the tree first (a read moves atime), then the record is asked, then the forced epoch.
r13_pre() {
  local _t="$1" _d="$BR_R13_DIR" _man _k _sc
  printf '%s\n%s\n' "$LABEL" "$RECEIPT" > "$_d/$n.rec"
  printf '%s\n' "$REST" > "$_d/$n.receipt"
  git -C "$_t" ls-files > "$_d/$n.tracked" 2>/dev/null || { r13_state refused closure-no-tracked-set; return 0; }
  awk -v root="$_t" -v recf="$_d/$n.receipt" -f "$BR_R13_AWK" "$_d/$n.tracked" > "$_d/$n.closure" 2>/dev/null \
    || { r13_state refused closure-unreadable; return 0; }
  _sc="$(sed -n 's/^#scanned [0-9]* unread \([0-9]*\)$/\1/p' "$_d/$n.closure")"
  [ "$_sc" = 0 ] || { r13_state refused "closure-unread-script(${_sc:-none})"; return 0; }
  grep -v '^#' "$_d/$n.closure" | LC_ALL=C sort -u > "$_d/$n.named"
  m1_driver_ops "$REST" | awk 'NR == 1 { p = $2; while (substr(p, 1, 2) == "./") p = substr(p, 3); print p }' > "$_d/$n.drv"
  _man="$(r13_manifest "$_t" "$_d/$n.named")" || { r13_state refused key-unreadable; return 0; }
  _k="$(printf '%s\n' "$_man" | git hash-object --stdin 2>/dev/null)" || _k=""
  [ -n "$_k" ] || { r13_state refused key-unhashable; return 0; }
  printf '%s\n' "$_man" > "$_d/$n.man"
  # A RECORD IS THE MANIFEST, A `#r13-rows` LINE, THEN THE ROWS ITS RUN PRINTED (every one R13-PASS or an
  # UNGUARDED-READ within the ceiling). The manifest half is compared byte for byte; the rows are replayed
  # verbatim, so a replay prints and counts exactly what the live run did.
  if [ -f "$BR_R13_STORE/$_k.green" ] && [ "$(sed '/^#r13-rows$/,$d' "$BR_R13_STORE/$_k.green")" = "$_man" ] \
     && grep -qx '#r13-rows' "$BR_R13_STORE/$_k.green"; then
    sed '1,/^#r13-rows$/d' "$BR_R13_STORE/$_k.green" | awk '!/^#r13-pop /' > "$_d/$n.replayrows"
    sed -n 's/^#r13-pop //p' "$BR_R13_STORE/$_k.green" > "$_d/$n.replaypop"
    r13_state replay "$_k"; return 0
  fi
  mkdir -p "$_d/$n.ctl" && printf 'u\n' > "$_d/$n.ctl/unread" && touch -t 200001010001 "$_d/$n.mark" \
    || { r13_state refused control-setup; return 0; }
  r13_settle_index "$_t" || { r13_state refused index-settle; return 0; }
  r13_state fire "$_k"
  r13_reset "$_t" "$_d/$n.ctl"
}

# r13_eval_env -- exported INSIDE the traced (and removal) eval's subshell only: core.trustctime=false, through
# GIT_CONFIG_COUNT/KEY_0/VALUE_0. The forced epoch moves every file's ctime, and with ctime trusted a receipt that
# refreshes the index (git status, diff, add) would re-hash, so READ, the whole tree.
r13_eval_env() { export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.trustctime GIT_CONFIG_VALUE_0=false; }

# r13_settle_index <tree> -- before the epoch, make the checkout's index neither racy nor smudged, so a git that
# stats the tree during the receipt reads no file whose stat is unchanged. A fresh `worktree add` writes its files
# and index within one second, so every entry is racily clean (re-read by content) and smudged on the next write.
# The index's mtime is moved one minute FORWARD, the index refreshed (it is read with the forward timestamp, so no
# entry is racy and none is smudged on write), and moved forward again after that write.
r13_settle_index() {
  local _ix
  _ix="$(git -C "$1" rev-parse --git-path index 2>/dev/null)" || return 1
  case "$_ix" in /*) ;; *) _ix="$1/$_ix" ;; esac
  [ -f "$_ix" ] || return 1
  touch -m -A 0100 "$_ix" && git -C "$1" -c core.trustctime=false update-index -q --refresh >/dev/null 2>&1
  touch -m -A 0100 "$_ix"
}

# r13_post <tree> -- AFTER the baseline eval and before anything else walks the tree: the read set (tracked
# files only), then the must-miss control.
r13_post() {
  local _t="$1" _d="$BR_R13_DIR" _s _x
  read -r _s _x < "$_d/$n.state" 2>/dev/null || return 0
  [ "$_s" = fire ] || return 0
  find "$_t" -path "$_t/.git" -prune -o -type f -neweram "$_d/$n.mark" -print 2>/dev/null \
    | awk -v p="$_t/" 'index($0, p) == 1 { print substr($0, length(p) + 1) }' > "$_d/$n.allreads"
  awk 'NR == FNR { T[$0] = 1; next } ($0 in T)' "$_d/$n.tracked" "$_d/$n.allreads" | LC_ALL=C sort -u > "$_d/$n.reads"
  if [ -n "$(find "$_d/$n.ctl/unread" -neweram "$_d/$n.mark" 2>/dev/null)" ]; then
    r13_state refused must-miss "$_x"
  fi
}

# r13_instrument_probe <dir> -- ATIME MUST BE A WORKING READ INSTRUMENT ON THE FILESYSTEM OF THE CHECKOUTS.
# Three files and an epoch mark, in a fresh directory beside the checkouts: a file read with cat moves; a file
# never opened does not; a file read BEFORE the reset does not; and after a SECOND reset a second read moves
# again (noatime fails that; relatime does not, as the 2000 epoch is older than mtime). Its own literal touches, never r13_reset, so a defect in either is
# seen by its own guard. Prints `R13-INSTRUMENT-REFUSED <which>` and returns 1 on any failure.
r13_instrument_probe() {
  local _d="$1" _why=""
  # Only ABSENT probe files are created (the BR_R13_PROBE_DIR seam; a fresh $WORK/r13i has none).
  mkdir -p "$_d" && { [ -e "$_d/read" ] || printf 'r\n' > "$_d/read"; } && { [ -e "$_d/unread" ] || printf 'u\n' > "$_d/unread"; } \
    && { [ -e "$_d/spare" ] || printf 's\n' > "$_d/spare"; } && touch -t 200001010001 "$_d/mark" || _why=setup
  [ -n "$_why" ] || cat "$_d/spare" > /dev/null
  [ -n "$_why" ] || touch -a -h -t 200001010000 "$_d/read" "$_d/unread" "$_d/spare" 2>/dev/null || _why=epoch-refused
  [ -n "$_why" ] || { cat "$_d/read" > /dev/null; [ -n "$(find "$_d/read" -neweram "$_d/mark" 2>/dev/null)" ] || _why=read-not-moved; }
  [ -n "$_why" ] || [ -z "$(find "$_d/unread" -neweram "$_d/mark" 2>/dev/null)" ] || _why=unread-moved
  [ -n "$_why" ] || [ -z "$(find "$_d/spare" -neweram "$_d/mark" 2>/dev/null)" ] || _why=reset-not-applied
  [ -n "$_why" ] || touch -a -h -t 200001010000 "$_d/read" 2>/dev/null || _why=epoch-refused
  [ -n "$_why" ] || [ -z "$(find "$_d/read" -neweram "$_d/mark" 2>/dev/null)" ] || _why=second-reset-not-applied
  [ -n "$_why" ] || { cat "$_d/read" > /dev/null; [ -n "$(find "$_d/read" -neweram "$_d/mark" 2>/dev/null)" ] || _why=second-read-not-moved; }
  if [ -n "$_why" ]; then
    echo "R13-INSTRUMENT-REFUSED $_why -- atime is not a working read instrument under $_d, so no read set R13 takes there can be trusted; R13 refuses rather than judge zero removals."
    return 1
  fi
  echo "R13-INSTRUMENT: atime moved on a read and on a second read after a second reset, and not on an unopened file or a file read before the reset, under $(dirname "$_d")."
  return 0
}

# r13_arm -- before the corpus score_ledger: decides whether R13 runs at all, proves the instrument, and exports
# what the --score-one workers need (BR_R13_DIR arms r13_pre/r13_post there).
R13_STATE=off
r13_arm() {
  R13_STATE=off
  [ "${R13_OPT:-0}" = 1 ] || return 0
  [ -z "$RE_ENTRY" ] || return 0
  r13_instrument_probe "${BR_R13_PROBE_DIR:-$WORK/r13i}" || exit 2
  R13_STATE=on
  BR_R13_AWK="$WORK/r13named.awk"; r13_named_awk "$BR_R13_AWK"
  BR_R13_DIR="$WORK/r13c"; mkdir -p "$BR_R13_DIR" || { echo "$(me): FAIL -- R13 could not create $BR_R13_DIR." >&2; exit 2; }
  if [ -n "${BR_R13_RECORD_DIR:-}" ]; then BR_R13_STORE="$BR_R13_RECORD_DIR"
  else
    BR_R13_STORE="$(git -C "$SUBJECT_ROOT" rev-parse --git-common-dir 2>/dev/null)" || BR_R13_STORE=""
    case "$BR_R13_STORE" in ''|/*) ;; *) BR_R13_STORE="$SUBJECT_ROOT/$BR_R13_STORE" ;; esac
    [ -n "$BR_R13_STORE" ] && BR_R13_STORE="$BR_R13_STORE/ai-dlc-r13-records"
  fi
  { [ -n "$BR_R13_STORE" ] && mkdir -p "$BR_R13_STORE" && [ -w "$BR_R13_STORE" ]; } \
    || { echo "$(me): FAIL -- R13's record store '$BR_R13_STORE' is not a writable directory; this is a refusal, not a reading." >&2; exit 2; }
  BR_R13_KCOMMON="$(r13_key_common)" || { echo "$(me): FAIL -- R13's key could not be computed; this is a refusal, not a reading." >&2; exit 2; }
  export BR_R13_AWK BR_R13_DIR BR_R13_STORE BR_R13_KCOMMON
}

# r13_key_common -> the manifest lines every receipt's key shares.
r13_key_common() {
  local _ids _t
  _ids="$(git hash-object --no-filters -- "$SELF" "$BR_RECEIPT_LIB" "$LIB" 2>/dev/null)" || return 1
  [ "$(printf '%s\n' "$_ids" | grep -c .)" -eq 3 ] || return 1
  printf 'r13-judge %s\n' $_ids
  printf 'bash %s\n' "$BASH_VERSION"
  printf 'git %s\n' "$(git --version 2>/dev/null)"
  for _t in git awk sed grep find touch xargs sort tr cmp; do printf 'tool %s %s\n' "$_t" "$(command -v "$_t")"; done
  printf 'os %s\n' "$(sw_vers -productVersion 2>/dev/null || uname -sr)"
  if [ -n "$(m1_l3_base "$SUBJECT_ROOT")" ]; then printf 'base resolved\n'; else printf 'base unresolved\n'; fi
}

# r13_plan <state-dir> <rows> -- per traced receipt, its verdict line in <state-dir>/plan and its removal records in
# <state-dir>/rm/; the counts in <state-dir>/pcounts. Decides nothing it cannot read from the files the workers wrote.
#   plan rows: <n> TAB <label> TAB replay|baseline-cm|excluded|refused|overflow|judge TAB <detail>
r13_plan() {
  local _sd="$1" _rows="$2" _f _n _s _x _lbl _row _drv _k _nr _nu _ne
  local _t=0 _rm=0 _un=0 _en=0 _xc=0 _cc=0 _pc=0 _oc=0 _rc=0 _rmr=0 _unr=0 _enr=0 _a _b _c
  mkdir -p "$_sd/rm"; : > "$_sd/plan"
  for _f in "$_sd"/*.state; do
    [ -f "$_f" ] || continue
    _n="$(basename "$_f" .state)"; _t=$(( _t + 1 ))
    read -r _s _x _ < "$_f"
    _lbl="$(sed -n '1p' "$_sd/$_n.rec")"
    _row="$(printf '%s\n' "$_rows" | awk -F'\t' -v id="$_lbl" '$2 == id { print $3; exit }')"
    case "$_s" in
      replay) _pc=$(( _pc + 1 ))
              # A REPLAY RE-PRINTS ITS RUN'S POPULATION FIGURES (named removals, named-unread, enumerated), stored
              # in the record, so the enumerated exclusion is said on every run, never as a replay's zero.
              if read -r _a _b _c < "$_sd/$_n.replaypop" 2>/dev/null; then
                _rmr=$(( _rmr + ${_a:-0} )); _unr=$(( _unr + ${_b:-0} )); _enr=$(( _enr + ${_c:-0} ))
              fi
              printf '%s\t%s\treplay\t%s\n' "$_n" "$_lbl" "$_x" >> "$_sd/plan"; continue ;;
      refused) _rc=$(( _rc + 1 )); printf '%s\t%s\trefused\t%s\n' "$_n" "$_lbl" "$_x" >> "$_sd/plan"; continue ;;
    esac
    case "$_row" in
      *-cannot-measure=*) _cc=$(( _cc + 1 )); printf '%s\t%s\tbaseline-cm\t%s\n' "$_n" "$_lbl" "$_row" >> "$_sd/plan"; continue ;;
      *-excluded=driver-absent-at-base*) _xc=$(( _xc + 1 )); printf '%s\t%s\texcluded\tEXCLUDED-DRIVER-ABSENT-AT-BASE\n' "$_n" "$_lbl" >> "$_sd/plan"; continue ;;
    esac
    # THE MUST-HIT CONTROL: the driver is the one file a `bash <P>` receipt is KNOWN to read. Absent from the
    # read set, the instrument saw nothing, and named > 0 with removed = 0 is a refusal, never a clean line.
    _drv="$(sed -n '1p' "$_sd/$_n.drv" 2>/dev/null)"
    if [ -n "$_drv" ] && grep -qxF -- "$_drv" "$_sd/$_n.named" && ! grep -qxF -- "$_drv" "$_sd/$_n.reads"; then
      _rc=$(( _rc + 1 )); printf '%s\t%s\trefused\tmust-hit:%s\n' "$_n" "$_lbl" "$_drv" >> "$_sd/plan"; continue
    fi
    awk 'NR == FNR { R[$0] = 1; next } ($0 in R)' "$_sd/$_n.reads" "$_sd/$_n.named" > "$_sd/$_n.remove"
    _nr="$(grep -c . "$_sd/$_n.remove")" || _nr=0
    _nu=$(( $(grep -c . "$_sd/$_n.named" || true) - _nr ))
    awk 'NR == FNR { N[$0] = 1; next } !($0 in N)' "$_sd/$_n.named" "$_sd/$_n.reads" > "$_sd/$_n.enum"
    _ne="$(grep -c . "$_sd/$_n.enum")" || _ne=0
    _en=$(( _en + _ne )); _un=$(( _un + _nu ))
    # NO NAMED READ (tip adversary D4): for EVERY receipt that names a file, a baseline read set holding none of
    # them is a refusal -- a `cd x && bash P`, a `bash ./P` or a grep-only receipt has no driver for must-hit.
    if [ -s "$_sd/$_n.named" ] && [ "$_nr" -eq 0 ]; then
      _rc=$(( _rc + 1 )); printf '%s\t%s\trefused\tno-named-read\n' "$_n" "$_lbl" >> "$_sd/plan"; continue
    fi
    if [ "$_nr" -gt "$R13_MAX_REMOVALS" ]; then
      _oc=$(( _oc + 1 )); printf '%s\t%s\toverflow\t%s\n' "$_n" "$_lbl" "$_nr" >> "$_sd/plan"; continue
    fi
    _rm=$(( _rm + _nr )); printf '%s %s %s\n' "$_nr" "$_nu" "$_ne" > "$_sd/$_n.pop"
    _k=0
    while IFS= read -r _p; do
      [ -n "$_p" ] || continue
      _k=$(( _k + 1 ))
      { sed -n '1,2p' "$_sd/$_n.rec"; printf '%s\n' "$_p"; } > "$_sd/rm/$_n.r$(printf '%02d' "$_k")"
    done < "$_sd/$_n.remove"
    # THE ENUMERATION REMOVAL: every ENUMERATED read of the receipt removed together, in ONE run (job `<n>.rE`,
    # line 3 the marker, lines 4+ the paths), judged as a named removal is.
    if [ "$_ne" -gt 0 ]; then
      { sed -n '1,2p' "$_sd/$_n.rec"; printf '@enumerated\n'; cat "$_sd/$_n.enum"; } > "$_sd/rm/$_n.rE"
    fi
    printf '%s\t%s\tjudge\t%s\n' "$_n" "$_lbl" "$_nr" >> "$_sd/plan"
  done
  printf '%s %s %s %s %s %s %s %s %s %s %s %s\n' "$_t" "$_rm" "$_un" "$_en" "$_xc" "$_cc" "$_pc" "$_oc" "$_rc" "$_rmr" "$_unr" "$_enr" > "$_sd/pcounts"
}

# r13_untraced <traced> <rows> <sh-population> -> how many scored receipts R13 neither traced nor saw refused before
# a checkout (R2's `empty-sh-one-liner` and `malformed-receipt-does-not-parse` rows); 0 when all are accounted for.
r13_untraced() {
  local _pre
  _pre="$(printf '%s\n' "$2" | awk -F'\t' '$1 == "UNSCORABLE" && ($3 == "empty-sh-one-liner" || $3 == "malformed-receipt-does-not-parse")' | grep -c .)" || _pre=0
  printf '%s' "$(( $3 - $1 - _pre ))"
}

# r13_removals <state-dir> <root> <ledger> -- runs every removal record in <state-dir>/rm, width 4, through the
# shipping worker (--r13-one), into <state-dir>/rows; returns 2 when a dispatched removal produced no verdict.
r13_removals() {
  local _sd="$1" _root="$2" _key _head _i _got
  mkdir -p "$_sd/rows.d"
  _i="$(find "$_sd/rm" -type f | grep -c .)" || _i=0
  [ "$_i" -gt 0 ] || { : > "$_sd/rows"; return 0; }
  _key="$(ledger_key "$3" "$_root")" || { echo "$(me): FAIL -- R13 could not resolve the re-entry key for $3." >&2; return 2; }
  _head="$(git -C "$_root" rev-parse --verify -q 'HEAD^{commit}' 2>/dev/null)" || _head=""
  BR_SENTINEL="$(git -C "$_root" ls-tree -r --name-only HEAD 2>/dev/null | sed -n '1p')"
  BR_WORK="$WORK"; BR_SUBJECT_ROOT="$_root"; BR_R13_RMOUT="$_sd/rows.d"
  export BR_WORK BR_SUBJECT_ROOT BR_SENTINEL BR_LIB_VARS BR_R13_RMOUT
  git -C "$_root" worktree prune >/dev/null 2>&1 || true
  # L3 IN A REMOVAL RUN COMPARES AGAINST THE PRE-REMOVAL HEAD: the removal stands for a rename inside a release.
  find "$_sd/rm" -type f | sort | BR_RECEIPTS_RUNNING="$_key" BR_L3_BASE="$_head" xargs -P 4 -n 1 bash "$SELF" --r13-one
  _got="$(find "$_sd/rows.d" -type f | grep -c .)" || _got=0
  if [ "$_got" -ne "$_i" ]; then
    echo "$(me): FAIL -- $_got of $_i dispatched R13 removals produced a verdict; a missing verdict reads exactly like a guarded read. This is a refusal, not a reading." >&2
    return 2
  fi
  cat "$_sd/rows.d"/* > "$_sd/rows"
  return 0
}

# r13_removed_ok <tree> <path-list file> -- the removal is APPLIED: every listed path gone from disk and from
# ls-files, the tree clean.
r13_removed_ok() {
  local _q _ls _st
  while IFS= read -r _q; do [ ! -e "$1/$_q" ] || return 1; done < "$2"
  _ls="$(git -C "$1" ls-files 2>/dev/null)" || return 1
  _st="$(git -C "$1" status --porcelain 2>/dev/null)" || return 1
  [ -n "$_ls" ] && [ -z "$(printf '%s\n' "$_ls" | awk 'NR == FNR { P[$0] = 1; next } ($0 in P)' "$2" -)" ] && [ -z "$_st" ]
}

# r13_judge_rc <rc> <cm member> -> PASS when the removal made the receipt say it cannot measure.
r13_judge_rc() { [ -n "$2" ]; }

# r13_remove_one -- the --r13-one worker body: record lines 1-2 are the receipt, line 3 the path to remove; or line 3
# `@enumerated` and lines 4+ every enumerated path, removed together, the row's path field `ENUMERATED(<n>)`.
r13_remove_one() {
  local _p _rc _cm _out _ps _q
  _p="$(sed -n '3p' "$REC")"
  _out="$BR_R13_RMOUT/$n"
  _ps="$W/t/$n.paths"
  if [ "$_p" = "@enumerated" ]; then
    sed '1,3d' "$REC" > "$_ps"; _p="ENUMERATED($(grep -c . "$_ps" || true))"
  else printf '%s\n' "$_p" > "$_ps"; fi
  rw() { printf '%s\t%s\t%s\t%s\t%s\n' "$1" "$LABEL" "$_p" "$2" "$3" > "$_out"; }
  [ -n "$_p" ] && grep -q . "$_ps" || { rw BROKEN exit=none no-path; return 0; }
  TA="$(mktree a)"
  [ -n "$TA" ] || { rw BROKEN exit=none no-removal-worktree; return 0; }
  git --literal-pathspecs -C "$TA" rm -q --pathspec-from-file="$_ps" >/dev/null 2>&1 \
    && git -C "$TA" -c user.email=r13@local -c user.name=r13 -c commit.gpgsign=false -c core.hooksPath=/dev/null \
         -c maintenance.auto=false commit -q --no-verify -m "r13 removal" >/dev/null 2>&1 \
    || { rw BROKEN exit=none removal-did-not-commit; return 0; }
  r13_removed_ok "$TA" "$_ps" || { rw BROKEN exit=none removal-not-applied; return 0; }
  ( cd "$TA" && r13_eval_env && eval "$REST" ) >/dev/null 2>"$W/t/$n.err"
  _rc=$?
  _cm="$(cm_reason "$_rc" "$W/t/$n.err")"
  if r13_judge_rc "$_rc" "$_cm"; then rw R13-PASS "exit=$_rc" "$_cm"; else rw UNGUARDED-READ "exit=$_rc" "-"; fi
}

# r13_records <state-dir> -- called only on a run within the ceiling (owner ruling, batch 256): every judged receipt
# whose rows are all R13-PASS or UNGUARDED-READ writes its record -- the manifest, `#r13-rows`, its rows verbatim --
# by a temp file and a move. A red R13, a refusal, an overflow, an instrument refusal and a must-hit failure exit or
# return before this is reached, so none of them writes one.
r13_records() {
  local _sd="$1" _n _lbl _v _x _k _t
  while IFS="$(printf '\t')" read -r _n _lbl _v _x; do
    [ "$_v" = judge ] || continue
    if [ -n "$(cat "$_sd"/rows.d/"$_n".r* 2>/dev/null | awk -F'\t' '$1 != "R13-PASS" && $1 != "UNGUARDED-READ"')" ]; then continue; fi
    read -r _ _k < "$_sd/$_n.state"
    _t="$(mktemp "$BR_R13_STORE/.$_k.XXXXXX")" || continue
    if { cat "$_sd/$_n.man"; printf '#r13-rows\n'; printf '#r13-pop %s\n' "$(cat "$_sd/$_n.pop" 2>/dev/null)"; cat "$_sd"/rows.d/"$_n".r* 2>/dev/null; } > "$_t" && mv -f "$_t" "$BR_R13_STORE/$_k.green"; then
      printf 'R13-RECORD: WRITTEN %s (K=%s)\n' "$_lbl" "$_k"
    else rm -f "$_t"; fi
  done < "$_sd/plan"
}

# r13_corpus -- after every other corpus reader: plans, removes,
# records, and prints the rows and the population line. Exit 2 on any refusal; returns 1 over the ceiling.
r13_corpus() {
  local _sd="$WORK/r13c" _t _rm _un _en _xc _cc _pc _oc _rc _ng _n9 _ncm _nrm _f _untr _jd
  if [ "$R13_STATE" != on ]; then
    echo "R13-POPULATION: NOT RUN -- --traced-removal was not given, so no receipt was traced and nothing was removed; that is not a clean result."
    return 0
  fi
  if [ "$SH_RECEIPTS" -eq 0 ]; then
    echo "R13-POPULATION: EMPTY -- 0 open sh receipt(s), so traced removal (R13) observed NOTHING this run; that is not a clean result."
    # THE TWO-SIDED CEILING HOLDS ON AN EMPTY POPULATION TOO: rotating the receipt that carried the unguarded reads
    # empties it, and a ceiling left above 0 would let the next, unrelated receipt's reads through unseen.
    [ "$MAX_R13" -gt 0 ] && { echo "FAIL: R13: the open sh population is EMPTY, so the live UNGUARDED-READ count is 0, BELOW the ceiling of $MAX_R13. REMEDY: lower DEFAULT_MAX_R13 in scripts/validate-backlog-receipts.sh to 0 (and drop the rows beside it). A red R13 writes no record." >&2; return 1; }
    return 0
  fi
  r13_plan "$_sd" "$OUT"
  read -r _t _rm _un _en _xc _cc _pc _oc _rc _rmr _unr _enr < "$_sd/pcounts"
  awk -F'\t' '$3 == "overflow" { printf "R13-NAMED-OVERFLOW %s %s\n", $2, $4 }' "$_sd/plan"
  awk -F'\t' '$3 == "refused" && $4 == "no-named-read" { printf "R13-NO-NAMED-READ %s\n", $2 }' "$_sd/plan"
  awk -F'\t' '$3 == "refused" { printf "R13-REFUSED %s %s\n", $2, $4 }' "$_sd/plan"
  # EVERY RECEIPT R2 SCORED IS ACCOUNTED FOR (tip adversary D6): traced (a state file each) plus those R2 refused
  # before any checkout (an empty or unparsable one-liner) must equal the sh population, or R13 refuses.
  _untr="$(r13_untraced "$_t" "$OUT" "$SH_RECEIPTS")"
  if [ "$_untr" != 0 ]; then
    echo "R13-UNTRACED $_untr"
    echo "$(me): FAIL -- R13: $_untr of $SH_RECEIPTS open sh receipt(s) R2 scored left no R13 state and were not refused before a checkout, so R13 cannot say it traced them. This is a refusal, not a reading." >&2
    exit 2
  fi
  _nrm="$(find "$_sd/rm" -type f | grep -c .)" || _nrm=0
  if [ "$_oc" -eq 0 ] && [ "$_rc" -eq 0 ] && [ "$_nrm" -gt 0 ]; then
    r13_removals "$_sd" "$SUBJECT_ROOT" "$LEDGER" || exit 2
  else
    : > "$_sd/rows"
  fi
  # A REPLAYED receipt's stored rows join the live ones, so they print and count against --max-unguarded alike.
  for _f in "$_sd"/*.replayrows; do [ -f "$_f" ] && cat "$_f" >> "$_sd/rows"; done
  _ng="$(awk -F'\t' '$1 == "UNGUARDED-READ"' "$_sd/rows" | grep -c .)" || _ng=0
  _n9="$(awk -F'\t' '$4 == "exit=9"' "$_sd/rows" | grep -c .)" || _n9=0
  _ncm="$(awk -F'\t' '$1 == "R13-PASS"' "$_sd/rows" | grep -c .)" || _ncm=0
  [ "$QUIET" = 1 ] || awk -F'\t' '$1 != "R13-PASS" { printf "%s\t%s\t%s\t%s\n", $1, $2, $3, $4 }' "$_sd/rows"
  echo "R13-POPULATION: $SH_RECEIPTS open sh receipt(s), $_t traced, $(( _rm + _rmr )) named removals ($_rmr replayed), $(( _un + _unr )) named-unread ($_unr replayed), $(( _en + _enr )) enumerated, removed together ($_enr replayed), $_xc EXCLUDED-DRIVER-ABSENT-AT-BASE, $_cc baseline-cm, $_pc replayed, $_oc overflow, $_rc refused; removals: $_n9 exit 9, $_ncm in the cannot-measure set, $_ng UNGUARDED-READ (ceiling $MAX_R13)."
  if [ -n "$(awk -F'\t' '$1 == "BROKEN"' "$_sd/rows")" ]; then
    awk -F'\t' '$1 == "BROKEN" { printf "FAIL: R13 BROKEN\t%s\t%s\t%s\n", $2, $3, $5 }' "$_sd/rows" >&2
    echo "$(me): FAIL -- R13: a removal could not be built or applied (named above). This is a refusal, not a reading." >&2
    exit 2
  fi
  if [ "$_oc" -gt 0 ] || [ "$_rc" -gt 0 ]; then
    echo "$(me): FAIL -- R13: $_oc receipt(s) named more than $R13_MAX_REMOVALS read files (R13-NAMED-OVERFLOW, never truncated) and $_rc receipt(s) were refused (R13-REFUSED: an unreadable closure or key, the must-miss control moved, or the must-hit driver was not in the read set). No record was written for them. This is a refusal, not a reading." >&2
    exit 2
  fi
  # NOTHING JUDGED IS NOT A COUNT OF 0: when every traced receipt was baseline cannot-measure or excluded (none judged,
  # none replayed), the live count reads 0 only because nothing was removed, so a ceiling above 0 cannot be checked and
  # the run fails saying so -- never "lower it to 0", which would be a reading of nothing.
  _jd="$(awk -F'\t' '$3 == "judge" || $3 == "replay"' "$_sd/plan" | grep -c .)" || _jd=0
  [ "$_jd" -eq 0 ] && [ "$MAX_R13" -gt 0 ] && { echo "FAIL: R13: NOTHING WAS JUDGED -- 0 of $_t traced open sh receipt(s) were judged or replayed (each was baseline cannot-measure or excluded), so the live UNGUARDED-READ count of 0 measures nothing and the ceiling of $MAX_R13 cannot be checked. REMEDY: repair the receipts R7 reads as cannot-measure, or, if the receipts that carried the unguarded reads have left the ledger, set DEFAULT_MAX_R13 in scripts/validate-backlog-receipts.sh to match. A red R13 writes no record." >&2; return 1; }
  # THE CEILING IS TWO-SIDED: a live count BELOW it is a stale-high ceiling, and a failure. No record is written.
  [ "$_ng" -lt "$MAX_R13" ] && { echo "FAIL: R13: the live UNGUARDED-READ count is $_ng, BELOW the ceiling of $MAX_R13. A stale-high ceiling would let $(( MAX_R13 - _ng )) new unguarded read(s) through unseen. REMEDY: lower DEFAULT_MAX_R13 in scripts/validate-backlog-receipts.sh to $_ng (and drop the rows beside it that no longer print). A red R13 writes no record." >&2; return 1; }
  [ "$_ng" -gt "$MAX_R13" ] || { r13_records "$_sd"; return 0; }
  awk -F'\t' '$1 == "UNGUARDED-READ" { printf "FAIL: R13\t%s\t%s\t%s\n", $2, $3, $4 }' "$_sd/rows" >&2
  echo "FAIL: R13: $_ng read(s) of a NAMED file by an open receipt in $LEDGER, when removed, left the receipt exiting with a code R7 reads as a measurement (named above with the path and the exit), against a ceiling of $MAX_R13. A rename of that file inside a release would leave the entry with no instrument and nothing would say so. REMEDY: guard the read so its absence exits 9 (\`[ -f <path> ] || exit 9\` before it, or \`grep -q <anchor> <path> || exit 9\`), in the receipt or in the script it runs. A red R13 writes no record." >&2
  return 1
}

vbr_sec_corpus() {
# ---------------------------------------------------------------------------
# THE CORPUS.
# ---------------------------------------------------------------------------
# A RE-ENTERED RUN executes no corpus receipt (see RE_ENTRY): both population lines say SKIPPED,
# and the verdict is the efficiency arms' alone.
# R12 is TEXT-ONLY and runs no receipt, so it judges the ledger on a re-entered run too, before that exit.
R12_OUT="$(r12_judge "$LEDGER" --counts)"; _r12_rc=$?
[ "$_r12_rc" -eq 2 ] && { echo "$(me): FAIL -- R12 could not read $LEDGER; this is a refusal, not a reading." >&2; exit 2; }
N_R12="$(printf '%s\n' "$R12_OUT" | grep -c '^R12 ')" || N_R12=0
read -r _ R12_ENT R12_PART R12_EXEMPT <<<"$(printf '%s\n' "$R12_OUT" | sed -n '/^R12-COUNTS /p')"
echo "R12-POPULATION: ${R12_PART:-0} PARTIAL live entr(ies) of ${R12_ENT:-0}, ${R12_EXEMPT:-0} exempt by a pending LANDED line (version >= VERSION), ${N_R12} not verify: manual."
r12_report() { # prints the R12 failure on stderr; returns 1 when there is one
  [ "$N_R12" -gt 0 ] || return 0
  printf '%s\n' "$R12_OUT" | awk '$1 == "R12" { printf "FAIL: R12\t%s\n", $2 }' >&2
  echo "FAIL: R12: $N_R12 live PARTIAL entr(ies) in $LEDGER (named above) carry a verify: value that is not manual. A PARTIAL entry has owed work open, and an sh receipt over the half that shipped exits 0, which scripts/backlog-reverify.sh reads as CLOSE-CANDIDATE -- a false close. REMEDY: write \`verify: manual\` (a reason may follow) until the entry closes; a closing entry carries a pending \`**LANDED (v<version>).**\` line (its first LANDED line, naming a version >= VERSION, anywhere in the body) and R8 then runs its receipt." >&2
  return 1
}
# R14 is TEXT-ONLY too: it runs no receipt, so it judges the ledger on a re-entered run as well.
R14_OUT="$(r14_judge "$LEDGER" "${SELF%/*}/backlog-rotate.sh")"; _r14_rc=$?
[ "$_r14_rc" -eq 2 ] && { echo "$(me): FAIL -- R14 could not read $LEDGER or the LANDED_FORM span of ${SELF%/*}/backlog-rotate.sh; this is a refusal, not a reading." >&2; exit 2; }
N_R14="$(printf '%s\n' "$R14_OUT" | grep -c '^R14 ')" || N_R14=0
read -r _ R14_N <<<"$(printf '%s\n' "$R14_OUT" | sed -n '/^R14-COUNTS /p')"
echo "R14-POPULATION: ${R14_N:-0} live LANDED line(s), ${N_R14} in a form backlog-rotate.sh refuses."
r14_report() { # prints the R14 failure on stderr; returns 1 when there is one
  [ "$N_R14" -gt 0 ] || return 0
  printf '%s\n' "$R14_OUT" | awk -F'\t' '$1 ~ /^R14 / { printf "FAIL: %s\t%s\n", $1, $2 }' >&2
  echo "FAIL: R14: $N_R14 live LANDED line(s) in $LEDGER (named above) are in neither form scripts/backlog-rotate.sh moves, so the release's rotate reads them \`sha ABSENT\` and REFUSES. REMEDY: open the line with exactly \`**LANDED (vVERSION_PLACEHOLDER).**\` and put any provenance after it, e.g. \`**LANDED (vVERSION_PLACEHOLDER).** (batch N, unit.) <text>\`." >&2
  return 1
}
if [ -n "$RE_ENTRY" ]; then
  r12_report || exit 1
  r14_report || exit 1
  R8_SKIP=1
  score_closed "$LEDGER" "$SUBJECT_ROOT" "$BASE_REF" >/dev/null || exit 2
  open_skip_line
  closed_line 0
  echo "R11-POPULATION: SKIPPED -- re-entered from inside a receipt; the outer run checks the branch's added LANDED shas once."
  echo "R10-POPULATION: SKIPPED -- re-entered from inside a receipt, so the anchor convention judged no open receipt here; the outer run judges them once."
  echo "R13-POPULATION: SKIPPED -- re-entered from inside a receipt, so nothing was traced or removed here; the outer run traces them once."
  eff_report || exit 1
  parent_cleanup_trees
  echo "OK: validate-backlog-receipts -- EXAMINED NOTHING for R2-R8: re-entered from inside a receipt (BR_RECEIPTS_RUNNING set on entry), so no corpus receipt was executed here; R12 ${N_R12}/0 PARTIAL entries not manual; the efficiency arms ran over ${LEDGER}."
  exit 0
fi
r13_arm
r9_start
OUT="$(score_ledger "$LEDGER" "$SUBJECT_ROOT")" || exit 2
read_counts
# R10 over the records score_ledger just wrote: the exact bytes its workers evaluated, as TEXT.
set -- "$WORK"/rec/*
[ -e "${1:-}" ] || set --
R10_JOUT="R10-COUNTS 0 0 0 0"
[ "$#" -gt 0 ] && { R10_JOUT="$(r10_judge "$SUBJECT_ROOT" "$@")" || { echo "$(me): FAIL -- R10 could not read the tracked set of $SUBJECT_ROOT; this is a refusal, not a reading." >&2; exit 2; }; }
r10_counts "$R10_JOUT" || { echo "$(me): FAIL -- R10's judge printed no R10-COUNTS line; this is a refusal, not a reading." >&2; exit 2; }
[ "$R10_SCAN" -eq "$SH_RECEIPTS" ] || { echo "$(me): FAIL -- R10 scanned $R10_SCAN of the scorer's $SH_RECEIPTS open sh receipts; a receipt it never read would read as anchored. This is a refusal, not a reading." >&2; exit 2; }
CLOSED_OUT="$(score_closed "$LEDGER" "$SUBJECT_ROOT" "$BASE_REF")" || exit 2
# R11 over the subject repository's own history: the ledger's tracked path, --base, and HEAD.
_r11_abs="$(cd "$(dirname "$LEDGER")" && pwd)/$(basename "$LEDGER")"
_r11_rel="$(git -C "$(dirname "$_r11_abs")" ls-files --full-name -- "$(basename "$_r11_abs")" 2>/dev/null | sed -n '1p')"
R11_OUT="$(r11_judge "$SUBJECT_ROOT" "$_r11_rel" "$BASE_REF" HEAD)" || exit 2
N_R11="$(printf '%s\n' "$R11_OUT" | grep -c '^R11-FAIL')" || N_R11=0

n_of() { printf '%s\n' "$OUT" | awk -F'\t' -v s="$1" '$1 == s' | grep -c . ; }
N_PC="$(n_of PROSE-CLOSABLE)"     || N_PC=0
N_FS="$(n_of FORMAT-SENSITIVE)"   || N_FS=0
N_BOUND="$(n_of BOUND)"           || N_BOUND=0
N_UNSC="$(n_of UNSCORABLE)"       || N_UNSC=0
N_UNSEED="$(n_of UNSEEDED)"       || N_UNSEED=0
N_OOP="$(n_of OUT-OF-POPULATION)" || N_OOP=0
N_PASS="$(n_of ALREADY-PASSING)"  || N_PASS=0
N_UNSTABLE="$(n_of UNSTABLE)"     || N_UNSTABLE=0
N_BROKEN="$(n_of BROKEN)"         || N_BROKEN=0
N_DRIVER="$(n_of DRIVER)"         || N_DRIVER=0
N_CM="$(printf '%s\n' "$OUT" | awk -F'\t' '$1 == "OUT-OF-POPULATION" && $3 ~ /-cannot-measure=/' | grep -c .)" || N_CM=0
N_M1X="$(printf '%s\n' "$OUT" | awk -F'\t' '$1 == "OUT-OF-POPULATION" && $3 ~ /-excluded=driver-absent-at-base/' | grep -c .)" || N_M1X=0
N_CFAIL="$(printf '%s\n' "$CLOSED_OUT" | awk -F'\t' '$1 == "CLOSED-FAIL"' | grep -c .)" || N_CFAIL=0
N_CBROKEN="$(printf '%s\n' "$CLOSED_OUT" | awk -F'\t' '$1 == "BROKEN"' | grep -c .)" || N_CBROKEN=0
SCORED=$(( N_PC + N_BOUND + N_FS ))
UNSCORED=$(( N_UNSC + N_UNSEED ))

PORC_AFTER="$(porcelain_count)" || PORC_AFTER=0
if [ "$PORC_AFTER" != "$PORC_BEFORE" ]; then
  echo "$(me): FAIL -- the caller's working tree changed during this run ($PORC_BEFORE -> $PORC_AFTER dirty paths). A seed escaped its checkout. Every verdict from this run is discarded." >&2
  exit 2
fi

if [ "$N_CBROKEN" -ne 0 ]; then
  echo "$(me): FAIL -- $N_CBROKEN closed-on-branch receipt(s) could not be checked out, so their closes were not confirmed. This is a refusal, not a reading." >&2
  exit 2
fi
if [ "$N_BROKEN" -ne 0 ]; then
  printf '%s\n' "$OUT" | awk -F'\t' '$1 == "BROKEN" { printf "FAIL: BROKEN\t%s\t%s\n", $2, $3 }' >&2
  echo "$(me): FAIL -- $N_BROKEN receipt(s) could not be scored because the harness failed, not because the receipt did. This is a refusal, not a reading." >&2
  exit 2
fi

# THE ZERO IS A FINDING. An empty parse, a ledger whose every receipt this grammar cannot
# spell, and a corpus of perfectly bound receipts all print the same 0 prose-closable.
# EXCEPT WHEN EVERY LIVE RECEIPT ALREADY PASSES: each one was run and read 0 at HEAD, which is an
# observation, not an absence -- it is the state a release fixing the last live receipt leaves.
R2_ALLPASS=""
[ "$SCORED" -eq 0 ] && [ "$N_PASS" -gt 0 ] && R2_ALLPASS=" R2 all-already-passing"
# AND WHEN EVERY LIVE ENTRY DECLARES `verify: manual`: there is no `sh` receipt to run, by each
# entry's own declaration, and the ledger is accounted for entry by entry (entries == manual).
# That is the state a release closing the last `sh`-receipted entry leaves, and it is not the
# state m8 guards against: an empty parse counts no manual receipts either, so it still refuses.
# The R5 floor (`--min-sh-receipts`) is lowered only when the entry count fell with it.
R2_ALLMANUAL=""
[ "$SCORED" -eq 0 ] && [ "$N_PASS" -eq 0 ] && [ "$ENTRIES" -gt 0 ] && [ "${MANUAL_RECEIPTS:-0}" -eq "$ENTRIES" ] && R2_ALLMANUAL=" R2 all-manual"
# AND WHEN THE LEDGER IS DECLARED EMPTY: zero entries, so zero receipts by construction, and the
# state the rotation of the last entry leaves. Whether a zero is DECLARED is decided by
# `backlog-reverify.sh --declared-empty` alone (marker last, no BL- id anywhere) and asked ONLY at
# ENTRIES == 0 -- a ledger emptied by hand, or one whose entries the parser stopped seeing, is
# still m8's zero. Its exit 2 is an environment failure and is this file's exit 2.
R2_DECLEMPTY=""
if [ "$ENTRIES" -eq 0 ]; then
  bash "$SELF_ROOT/scripts/backlog-reverify.sh" --declared-empty "$LEDGER" >/dev/null 2>&1; _de=$?
  case "$_de" in
    0) R2_DECLEMPTY=" R2 declared-empty" ;;
    1) : ;;
    *) echo "$(me): FAIL -- backlog-reverify.sh --declared-empty exited $_de on $LEDGER, an environment failure; the zero could not be classified." >&2; exit 2 ;;
  esac
fi
# AND WHEN EVERY `sh` RECEIPT IS A DRIVER, ALREADY-PASSING OR OUT-OF-POPULATION, WITH AT LEAST ONE
# DRIVER: each driver ran a tracked script and was read, which is an observation. The predicate is
# r2_alldriver.
R2_ALLDRIVER=""
R2_UNREC_IDS=""
# The rows print BEFORE R2 so an R2 exit still names them; the exit itself is after R2.
[ -s "$WORK/unrec" ] && awk -F'\t' '{ printf "FAIL: UNRECOGNISED\t%s\tverify: %s\n", $1, $2 }' "$WORK/unrec" >&2
[ -s "$WORK/unrec" ] && R2_UNREC_IDS="; entries whose verify: value matched no receipt form: $(cut -f1 "$WORK/unrec" | tr '\n' ' ')"
[ "$SCORED" -eq 0 ] && r2_alldriver "$OUT" "$SH_RECEIPTS" && R2_ALLDRIVER=" R2 all-driver"
if [ "$SCORED" -eq 0 ] && [ "$N_PASS" -eq 0 ] && [ -z "$R2_ALLMANUAL" ] && [ -z "$R2_DECLEMPTY" ] && [ -z "$R2_ALLDRIVER" ]; then
  echo "FAIL: R2: $LEDGER produced ZERO scored receipts (entries $ENTRIES, sh receipts ${SH_RECEIPTS:-0}, manual ${MANUAL_RECEIPTS:-0}, unscorable $N_UNSC, unseeded $N_UNSEED, out of population $N_OOP, already passing $N_PASS, driver $N_DRIVER)$R2_UNREC_IDS. Nothing was observed, and an arm that observed nothing is not a clean corpus." >&2
  exit 1
fi

if [ -s "$WORK/unrec" ]; then
  echo "FAIL: $LEDGER carries $(grep -c . "$WORK/unrec") live entr(ies) whose verify: value is neither 'sh' nor 'manual' (ids above). A value like 'manual.' matches no receipt form and is counted as nothing; write 'verify: manual <reason>' or 'verify: sh ...'." >&2
  exit 1
fi

# `--quiet` DROPS THE PER-RECEIPT ROWS AND THE SUMMARY, never the OK line's provenance clause
# below. A FAILING run still prints its FAIL text on stderr, because a ceiling breach a caller
# asked not to hear about is the one message that must always arrive.
if [ "$QUIET" != "1" ]; then
  # UNSTABLE carries its two exits in field 3, where every other status carries a detail the
  # report drops. They ARE the finding -- "9 on one reading, 1 on the next" is the whole of
  # what is wrong with the receipt -- so that row is rendered with the detail in place of the
  # paths, and the fixed four-column shape is preserved.
  printf '%s\n' "$OUT" | awk -F'\t' '
    $1 == "UNSTABLE" { printf "%s\t%s\t%s\t%s\n", $1, $2, $3, $5; next }
    $1 == "PROSE-CLOSABLE" || $1 == "FORMAT-SENSITIVE" || $1 == "UNSCORABLE" || $1 == "UNSEEDED" || $1 == "OUT-OF-POPULATION" || $1 == "ALREADY-PASSING" || $1 == "DRIVER" { printf "%s\t%s\t%s\t%s\n", $1, $2, $4, $5 }
  ' | sort
  echo "SUMMARY entries=$ENTRIES sh-receipts=$SH_RECEIPTS scored=$SCORED prose-closable=$N_PC/$MAX_PC format-sensitive=$N_FS bound=$N_BOUND unscorable=$N_UNSC+unseeded=$N_UNSEED/$MAX_UNSC out-of-population=$N_OOP/$MAX_OOP unstable=$N_UNSTABLE/$MAX_UNSTABLE already-passing=$N_PASS driver=$N_DRIVER cannot-measure=$N_CM/$MAX_CM closed-fail=$N_CFAIL"
fi
# THE TWO POPULATION LINES PRINT IN BOTH VERBOSITIES. An empty population is a fact a caller must
# be able to see even under --quiet: it is the difference between "checked, clean" and "checked
# nothing", and the second reads exactly like the first in every other line this arm prints.
open_empty_line "$SH_RECEIPTS"
echo "M1-EXCLUDED: $N_M1X open sh receipt(s) EXCLUDED-DRIVER-ABSENT-AT-BASE (driver absent at HEAD and at --base '$BASE_REF', lead ruling L3 (b)); counted here, never an R7 finding."
closed_line "$N_CFAIL"
r11_line "$R11_OUT"
if [ "$QUIET" != "1" ] && [ "$R10_N" -gt 0 ]; then
  printf '%s\n' "$R10_ROWS" | awk -F'\t' '$2 == "UNANCHORED" { printf "UNANCHORED\t%s\t%s\t%s\n", $1, $3, $4 }'
fi
if [ "$R10_SCAN" -eq 0 ]; then
  echo "R10-POPULATION: EMPTY -- 0 open sh receipt(s), so the anchor convention (R10) observed NOTHING this run; that is not a clean result."
else
  echo "R10-POPULATION: $R10_SCAN open sh receipt(s) read as text, $R10_N unanchored, $R10_ANC anchored, $(( R10_SCAN - R10_N - R10_ANC )) reading no tracked path ($R10_PART not fully parsed, so the unanchored count is a floor)."
fi

RC=0
if [ "$N_PC" -gt "$MAX_PC" ]; then
  echo "FAIL: R2: $N_PC receipt(s) in $LEDGER are satisfied by a COMMENT carrying their own grep literal, against a ceiling of $MAX_PC. Each one named above went 1 -> 0 when a single comment line was appended to the files it greps, in a pristine checkout -- so it cannot tell a fix from prose about a fix, and it is the instrument the next batch will use to decide whether its own fix worked. REMEDY, and it is two things: rewrite the receipt to DRIVE its subject (run the program, read its exit or its output) rather than grep the text of the file that implements it, AND assert that the control case still DENIES -- driving the subject defeats a prose closer and does NOT defeat an over-broad fix that silences every case. This ceiling is a RATCHET and only ever moves DOWN." >&2
  RC=1
fi
if [ "$UNSCORED" -gt "$MAX_UNSC" ]; then
  echo "FAIL: R3: $UNSCORED receipt(s) in $LEDGER could not be scored at all ($N_UNSC unscorable, $N_UNSEED unseeded), against a ceiling of $MAX_UNSC. THIS CEILING EXISTS BECAUSE THE ONE ABOVE IS ESCAPABLE: building the pattern from a variable, moving it into an awk body or a grep -f file, or naming a path the seed cannot append to all lower the prose-closable count and fix nothing. An unscorable receipt is UNSPELLED, never bound -- write the predicate so its literal is visible, or drive the subject. This ceiling is a RATCHET and only ever moves DOWN." >&2
  RC=1
fi
if [ "$N_UNSTABLE" -gt "$MAX_UNSTABLE" ]; then
  echo "FAIL: R6: $N_UNSTABLE receipt(s) in $LEDGER gave DIFFERENT exits on two readings of the SAME commit, against a ceiling of $MAX_UNSTABLE. Each is named above with both exits. A receipt whose answer depends on when it ran cannot answer the question it exists to answer -- not on the run that matters either -- so this is reported by name rather than smoothed away by taking the second reading. The usual cause is a precondition guard (\`|| exit 9\`) over something that is not guaranteed at the moment the receipt runs: a pipeline whose reader leaves early, a temp directory, a process the receipt does not own. REMEDY: make each guard read what it needs ONCE into a variable and test that variable, and keep exit 9 for a genuinely missing file. This ceiling ships at zero and is not a measured debt." >&2
  RC=1
fi
if [ "$N_OOP" -gt "$MAX_OOP" ]; then
  echo "FAIL: R4: $N_OOP receipt(s) in $LEDGER have a base exit that is neither 0 nor 1, against a ceiling of $MAX_OOP. A receipt exiting 9 or 128 is answering a question about its own preconditions, and it answers that way whatever the fix does -- so it is outside this arm's population AND outside its own. THIS CEILING EXISTS BECAUSE R2 IS ESCAPABLE: adding an '|| exit 9' guard lowers the prose-closable count and fixes nothing. This ceiling is a RATCHET and only ever moves DOWN." >&2
  RC=1
fi

if [ "$N_CM" -gt "$MAX_CM" ]; then
  printf '%s\n' "$OUT" | awk -F'\t' '$1 == "OUT-OF-POPULATION" && $3 ~ /-cannot-measure=/ { sub(/^base-exit=/, "", $3); printf "FAIL: R7\t%s\texit=%s\n", $2, $3 }' >&2
  echo "FAIL: R7: $N_CM OPEN receipt(s) in $LEDGER CANNOT MEASURE their subject (named above), against a ceiling of $MAX_CM. The set is exit 9, 126, 128 and above, the receipt's OWN shell reporting a missing command, a missing sourced file or a syntax error (scripts/backlog-receipt-lib.sh cant_measure), and the receipt's own \`bash <P>\` driver absent at HEAD (driver-absent: DRIVER-REMOVED when --base has it, DRIVER-ABSENT-UNRESOLVED-BASE when --base does not resolve; absent at --base too is EXCLUDED, lead ruling L3). Such a receipt answers whatever the fix does, so the entry it guards has no instrument -- usually a subject renamed or moved inside a release. NOT in the set: bare 127 and 2-8, which are reproductions. REMEDY: repair the receipt so it reaches its question." >&2
  RC=1
fi
if [ "$R10_N" -gt "$MAX_R10" ]; then
  printf '%s\n' "$R10_ROWS" | awk -F'\t' '$2 == "UNANCHORED" { printf "FAIL: R10\t%s\tpath=%s\n", $1, $3 }' >&2
  echo "FAIL: R10: $R10_N OPEN receipt(s) in $LEDGER read a tracked file with no anchor on it (named above with the first such path), against a ceiling of $MAX_R10. A grep-shaped receipt whose subject is renamed exits 1, which is a live defect's own code, and a \`! grep\` exits 0, which reads as a fix -- so R7 cannot see the rename and the entry has no instrument. REMEDY: before the defect test, assert the file still carries a token the subject cannot lack while it exists, and exit 9 if not: \`grep -q '<anchor>' <path> || exit 9; <defect test>\`. A bare [ -f ] is not an anchor, the exit must be exactly 9, and the anchor must survive the fix (R8 wants a closed receipt to exit 0)." >&2
  RC=1
fi
if [ "$N_CFAIL" -gt 0 ]; then
  printf '%s\n' "$CLOSED_OUT" | awk -F'\t' '$1 == "CLOSED-FAIL" { printf "FAIL: R8\t%s\t%s\t%s\n", $2, $3, $4 }' >&2
  echo "FAIL: R8: $N_CFAIL entr(ies) closed on this branch (stamped **LANDED (v in $LEDGER, or rotated into the archive, since the merge-base with $BASE_REF) carry a verify: sh receipt that does not exit 0 (named above with the exit and the reason). A close says the fix is present; a receipt that disagrees is either a subject renamed inside the release or a close that did not land. REMEDY: fix the receipt or the close, then re-run." >&2
  RC=1
fi
if [ "$N_R11" -gt 0 ]; then
  printf '%s\n' "$R11_OUT" | awk -F'\t' '$1 == "R11-FAIL" { printf "FAIL: R11\t%s\t%s\t%s\n", $2, $3, $4 }' >&2
  echo "FAIL: R11: $N_R11 verified sha(s) on LANDED lines this branch ADDED to $LEDGER or its archive (since the merge-base with $BASE_REF) are not commits on $BASE_REF (named above). A sha written before the squash names a commit the squash leaves unreachable, so the line attests to nothing on main. REMEDY: write the sha-less form \`**LANDED (v<version>).**\` (scripts/backlog-rotate.sh binds it to CHANGELOG.md or VERSION), or name a sha already on $BASE_REF." >&2
  RC=1
fi
r12_report || RC=1
r14_report || RC=1

# THE POPULATION FLOOR. The three ceilings all bound a count WITHIN the `sh` population, so
# the last escape is to leave it: rewrite `verify: sh` as `verify: manual`, or delete the
# receipt line. Both are invisible to every clause above, and both read as an improvement.
if [ "$SH_RECEIPTS" -lt "$MIN_SH" ]; then
  _sh_drop=$(( MIN_SH - SH_RECEIPTS ))
  _en_drop=$(( MIN_ENTRIES - ENTRIES ))
  [ "$_en_drop" -lt 0 ] && _en_drop=0
  if [ "$_sh_drop" -gt "$_en_drop" ]; then
    echo "FAIL: R5: the sh receipt population fell by $_sh_drop (from $MIN_SH to $SH_RECEIPTS) while the live entry count fell by only $_en_drop (from $MIN_ENTRIES to $ENTRIES). Rotation removes an entry and its receipt together and moves both sides; a 'verify: sh' rewritten as 'verify: manual', or a deleted receipt line, moves only this one -- and either lowers every count above while fixing nothing. If entries really were rotated, lower DEFAULT_MIN_SH in this script and --min-entries in .githooks/pre-push together." >&2
    RC=1
  fi
fi
# R9, after every read of $WORK/counts and $WORK/unrec above; its line prints in both verbosities.
r9_run; _r9_rc=$?
[ "$_r9_rc" -eq 2 ] && exit 2
[ "$_r9_rc" -eq 0 ] || RC=1
eff_report || RC=1
r13_corpus || RC=1
[ "$RC" -ne 0 ] && exit 1

# THE WORKTREE REGISTRY IS ASSERTED BACK. Each checkout registers in the subject repository,
# and an abandoned registration outlives the process that made it.
parent_cleanup_trees
WT_OWN_AFTER="$(own_registered)" || WT_OWN_AFTER=0
if [ "$WT_OWN_AFTER" -ne 0 ]; then
  echo "$(me): FAIL -- $WT_OWN_AFTER of this run's own checkout(s) under $WORK are still registered in $SUBJECT_ROOT. Run \`git worktree prune\`; the verdict above stands but the repository was left dirty. (Checkouts belonging to other processes are deliberately not counted -- the registry is shared, and a concurrent add would otherwise read as this run's leak.)" >&2
  exit 2
fi

_where="$LEDGER"
[ "$DEFAULTED" = "1" ] && _where="docs/backlog.md"
if [ "$QUIET" != "1" ]; then
  echo "OK: validate-backlog-receipts -- R2 ${N_PC}/${MAX_PC} prose-closable, R3 ${UNSCORED}/${MAX_UNSC} unscored, R4 ${N_OOP}/${MAX_OOP} out of population, R6 ${N_UNSTABLE}/${MAX_UNSTABLE} unstable, R5 ${SH_RECEIPTS} sh receipts over ${ENTRIES} live entries in ${_where} (${N_BOUND} bound, ${N_FS} format-sensitive, ${N_PASS} already passing, ${N_DRIVER} driver; R0 bound the path-split class to ${CLASS_SOURCE}; R7 ${N_CM}/${MAX_CM} open receipts cannot measure; R8 ${N_CFAIL} closed-on-branch receipts not exiting 0; R11 ${N_R11} added LANDED shas not on ${BASE_REF}; R10 ${R10_N}/${MAX_R10} open receipts unanchored over ${R10_SCAN} read; R12 ${N_R12}/0 PARTIAL entries not manual over ${R12_PART} PARTIAL; every receipt ran in its own ${PROVENANCE}, ${WT_OWN_AFTER} of this run's own checkouts still registered, caller porcelain ${PORC_BEFORE} unchanged).${R2_ALLPASS}${R2_ALLMANUAL}${R2_DECLEMPTY}${R2_ALLDRIVER}"
else
  # `--quiet` SUPPRESSES THE FINDING ROWS, NEVER THE PROVENANCE. A caller that asks for quiet
  # still has to be able to tell this arm's silence from a stub's: a fifteen-line heuristic
  # that greps receipts for the word `grep` produces the same exit code and the same empty
  # output, and there would be nothing to distinguish them. This line reports what the run
  # actually DID -- how many receipts were checked out and scored -- which no implementation
  # that seeds nothing can emit truthfully.
  echo "OK: validate-backlog-receipts -- ${SCORED} receipt(s) scored in ${_where}, each in its own ${PROVENANCE}; ${N_PC}/${MAX_PC} prose-closable.${R2_ALLPASS}${R2_ALLMANUAL}${R2_DECLEMPTY}${R2_ALLDRIVER}"
fi
exit 0
}

# THE SOURCE GUARD. Sourced, this file defines its functions and its constants and stops; vbr_main
# is the whole CLI, in the order the file always ran: scrub, worker dispatch, arguments, parent.
vbr_main() {
vbr_sec_env "$@"
vbr_worker "$@"
vbr_sec_args "$@"
vbr_sec_setup
[ -n "$R13_DRIVE" ] && vbr_r13_drive
vbr_sec_r0
vbr_sec_eff
vbr_sec_corpus
}
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
vbr_main "$@"
