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
# have shipped reading exactly like a clean corpus. The self-probe below therefore fires in
# BOTH directions -- its seeded prose-closable receipt must flip under the token seed AND
# must NOT flip under the generic one.
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
# untracked at base 1 falls through to UNSCORABLE -- the self-probe seeds exactly that file,
# because an absent one is refused by an `[ -f ]` test too and could not tell the two apart.
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
#   receipt that re-enters this validator skips. A SELF-PROBE runs first, through the same readers and
#   the same judge over the REAL classifier and ceiling on two seeded ledgers: the readers must parse
#   both programs' real output (a format drift that empties a reading is caught there, not acquitted),
#   the join must hold on the seeded truth, and it must FAIL with the arm's count one short (j1) and
#   with a ceiling reading one more entry (b16). Where this tree carries no validate-backlog-size.sh
#   (the receipt-binding fixture's seeds) or its HEAD no scripts/backlog-reverify.sh, R9 prints
#   `R9: NOT RUN` and observes nothing, said as such in every verbosity. A zero on both sides is not
#   refused: an all-manual ledger has no `sh` receipt, and the probe, not the corpus, proves the join
#   can fire.
#
# EMPTY IS NOT CLEAN. Both populations print a line in every verbosity -- `OPEN-POPULATION: EMPTY`
# when the ledger has no live `sh` receipt (the state on every push when this shipped: 43 live
# entries, 0 `sh` receipts; control, the same ledger's `^verify:` lines, 47, of which the one
# `^verify: sh` line is the `## Receipts` legend and sits in no entry), and
# `CLOSED-POPULATION: EMPTY / NOT DERIVED / <n> run`. A self-probe fires both of them, and R7/R8 in
# both directions, before the corpus (R7_PROBED).
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
#          [--max-unstable N] [--max-cannot-measure N]
#          [--min-sh-receipts N] [--min-entries N]
# Output: one TAB-delimited row per finding, then a summary and one OK line.
#          STATUS <TAB> ENTRY <TAB> paths=... <TAB> tokens=...
# Exit:  0 = at or under every ceiling; 1 = over one, or nothing was scored;
#        2 = usage, environment, or a self-probe that did not fire.
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
# call. The self-probe's `config core.hooksPath` wrote a mktemp path into the CALLER'S config,
# pointing that repository's own pre-push hook at a directory this run deletes -- a later push
# then ran NO GATE AT ALL and reported success, and a release landed on origin ungated. And
# `mktree`'s `worktree add --detach HEAD` checked out the CALLER'S HEAD for every receipt, so
# each one was scored against the wrong tree; at the gate that surfaced as the self-probe's
# seeded receipts reading OUT-OF-POPULATION with base exits of 2, which reads as a broken
# scorer rather than as a redirected one.
#
# A PER-CALL SCRUB CANNOT BE COMPLETE. This file makes a dozen `git -C` calls across four
# helpers and any new one inherits the defect silently, so the environment is cleared ONCE, for
# the process, before a single git call is made. `core/fixtures/lib/preamble.sh` and the
# `fixture git-env scrub` gate phase exist for exactly this class on the fixture side; this
# program is not a fixture and had no such carrier.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
# AND THE CALLER'S `git -c` SETTINGS. git exports them to every hook child as GIT_CONFIG_PARAMETERS
# (and GIT_CONFIG_COUNT/KEY_n/VALUE_n), which override every repository's own config -- so a push run
# as `git -c core.hooksPath=X push` set X in the probe repository below, its post-checkout never ran,
# and the BL-906 arm read PROSE-CLOSABLE: a false red on a clean tree.
unset GIT_CONFIG_PARAMETERS GIT_CONFIG_COUNT
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
if [ "${1:-}" = "--score-one" ] || [ "${1:-}" = "--closed-one" ]; then
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
  # ONE function, so a mutant emptying the set is one edit and is killed by the self-probe.
  cm_reason() {
    case "$1" in
      9) printf 'exit-9' ;;
      126) printf 'exit-126' ;;
      *) if [ "$1" -ge 128 ]; then printf 'exit-%s' "$1"
         elif [ -n "$(cant_measure "$1" < "$2")" ]; then printf 'own-shell'; fi ;;
    esac
  }

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
  ( cd "$TA" && eval "$REST" ) >/dev/null 2>"$W/t/$n.err"
  BASE_RC=$?
  BASE_CM="$(cm_reason "$BASE_RC" "$W/t/$n.err")"

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
    wr OUT-OF-POPULATION "base-exit=$BASE_RC${BASE_CM:+-cannot-measure=$BASE_CM}" "paths=${PL:-none}" "tokens=${TL:-none}"; exit 0
  fi
  # THE OWN-SHELL ROUTE AT EXIT 1. A receipt whose own shell could not source its helper (`. missing.sh`
  # with no guard) exits 1, which is a reproduction's code; without this it would go on to be seeded
  # and scored as though it had measured something.
  if [ -n "$BASE_CM" ]; then
    wr OUT-OF-POPULATION "base-exit=$BASE_RC-cannot-measure=$BASE_CM" "paths=${PL:-none}" "tokens=${TL:-none}"; exit 0
  fi

  # --- the DRIVER class -----------------------------------------------------------------
  # A one-liner that is nothing but `bash <repo-rel>.sh [plain args]`, optionally chained with
  # `&&`, greps nothing in the one-liner, so no comment in any file it names can satisfy it: the
  # SCRIPT is the subject. Classified by SHAPE, whatever the base exit (0 or 1 -- non-0/1 has
  # already left above), and only when EVERY script it runs is TRACKED in the checkout. A path
  # that is merely present on disk is not enough, and the self-probe seeds exactly that file.
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
  # both the self-probe's second direction and the FORMAT control below.
  SEED_LINE="#"
  while IFS= read -r t; do
    [ -n "$t" ] || continue
    SEED_LINE="$SEED_LINE $t"
  done <<EOF
$TOKENS
EOF
  GENERIC_LINE="# probe"
  [ "${BR_GENERIC_SEED:-0}" = "1" ] && SEED_LINE="$GENERIC_LINE"

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
  if [ "$HAS_STRUCTURED" = "1" ] && [ "${BR_GENERIC_SEED:-0}" != "1" ]; then
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
QUIET=0; LEDGER=""; ROOT_ARG=""; EFF_MODE=""; BASE_REF="origin/main"
MAX_PC=""; MAX_UNSC=""; MAX_OOP=""; MAX_UNSTABLE=""; MIN_SH=""; MIN_ENTRIES=""; MAX_CM=""
usage() { echo "usage: validate-backlog-receipts.sh [<ledger>] [--archive | --efficiency-only] [--root <dir>] [--base <ref>] [--quiet] [--max-prose-closable N] [--max-unscorable N] [--max-out-of-population N] [--max-cannot-measure N] [--min-sh-receipts N] [--min-entries N]" >&2; }
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
    --base) BASE_REF="${2:-}"; shift 2 ;;
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
[ -n "$BASE_REF" ] || { echo "$(me): FAIL -- --base needs a ref" >&2; exit 2; }
# RE-ENTRY. A receipt that invokes `.githooks/pre-push` (dozens of archive receipts do, directly
# or as `git push`) re-enters this validator from inside the run executing it, whose population at
# that tree is the same one, so it would recurse without end. Both receipt executors -- score_ledger
# (the OPEN receipts R2-R7 judge) and score_closed (R8) -- export BR_RECEIPTS_RUNNING to every
# receipt. A run that finds it set ON ENTRY still runs its self-probes and the efficiency arms, but
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
# ONE function, so the self-probe drives the same decision the run takes.
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
  if [ -d "$WORK/t" ]; then
    for _d in "$WORK"/t/*; do
      [ -e "$_d/.git" ] || continue
      git -C "$SUBJECT_ROOT" worktree remove --force "$_d" >/dev/null 2>&1 || rm -rf "$_d"
    done
  fi
  # `prune` is what clears a registration whose directory is already gone -- a worker the
  # pool killed leaves exactly that, and `worktree remove` cannot see it to remove it.
  git -C "$SUBJECT_ROOT" worktree prune >/dev/null 2>&1 || true
}
parent_cleanup() { parent_cleanup_trees; rm -rf "$WORK"; }
trap parent_cleanup EXIT INT TERM
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
# The grep-literal grammar, defined ONCE. Both the self-probe and the corpus run this file.
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
# The probe fires both ways first: a mutated class must be refused, and an unmutated one must
# be accepted -- without the second direction an always-refusing comparator reads exactly like
# a clean binding, and without the first an always-accepting one does.
# ---------------------------------------------------------------------------
class_of() { # class_of <file> -> the class inside <CLASS_FUNC>()'s `tr -c`
  sed -n "s/^${CLASS_FUNC}().*tr -c '\\(.*\\)' '.*/\\1/p" "$1" 2>/dev/null | sed -n '1p'
}
}

vbr_probe_r0() {
r0_probe="$WORK/r0"; mkdir -p "$r0_probe"
printf "%s\n" "${CLASS_FUNC}() { printf '%s\\n' \"\$1\" | tr -c 'A-Za-z0-9_./\$-' '\\n' || true; }" > "$r0_probe/good.sh"
printf "%s\n" "${CLASS_FUNC}() { printf '%s\\n' \"\$1\" | tr -c 'A-Za-z0-9_.-' '\\n' || true; }" > "$r0_probe/bad.sh"
printf "%s\n" "other_tokens() { printf '%s\\n' \"\$1\" | tr -c 'A-Za-z0-9_./\$-' '\\n'; }" > "$r0_probe/wrongfunc.sh"
r0_good="$(class_of "$r0_probe/good.sh")"
r0_bad="$(class_of "$r0_probe/bad.sh")"
r0_wrong="$(class_of "$r0_probe/wrongfunc.sh")"
if [ -z "$r0_good" ]; then
  echo "$(me): SELF-PROBE FAILED -- R0's extractor read NOTHING from a seeded ${CLASS_FUNC}() line, so its reading of the real file is not a reading." >&2; exit 2
fi
if [ "$r0_good" != "$PATH_CLASS" ]; then
  echo "$(me): SELF-PROBE FAILED -- R0 refused a class identical to this file's, so it refuses everything and a green R0 below would mean nothing." >&2; exit 2
fi
if [ "$r0_bad" = "$PATH_CLASS" ]; then
  echo "$(me): SELF-PROBE FAILED -- R0 ACCEPTED a mutated class, so it cannot see a drift." >&2; exit 2
fi
if [ -n "$r0_wrong" ]; then
  echo "$(me): SELF-PROBE FAILED -- R0's extractor matched a DIFFERENT function carrying the same class. Anchored that loosely it reads a near-miss elsewhere in the tree and reports a binding it did not make." >&2; exit 2
fi
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
#      threshold or comparison is applied to any number.
#      ONE ISOLATED BRANCH, eff_nostep_ok, accepts a SPRINTLESS line, and only when it says there
#      is no graph pipeline step AND names where the cost lives (operator ruling). It is one
#      function so a mutant widening it is one edit and is killed by the self-probe.
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
# --archive and --efficiency-only run the self-probe and these arms only, and exit before the
# per-receipt checkout scorer, which costs a checkout per receipt and has nothing to say here.
# ===========================================================================
EFFAWK="$WORK/eff.awk"
{ ledger_entry_awk; backlog_entry_label_awk; backlog_efficiency_tag_awk; cat <<'AWK'
function eflush() {
  if (label == "") return
  gsub(/[ \t]+/, " ", text); gsub(/[ \t]+/, " ", oc)
  if (stp == "") stp = "-"
  printf "%s\t%d\t%d\t%d\t%d\t%d\t%d\t%d\t%s\t%d\t%s\n", label, tagged, (index(text, "docs/analysis/") > 0), (index(text, "A step with no measured value goes") > 0 && index(text, ".claude/rules/operator-rulings.md") > 0), (index(text, "no graph pipeline step") > 0), landed, ocn, bas, stp, mv, oc
  label = ""; tagged = 0; landed = 0; ocn = 0; oc = ""; inoc = 0; text = ""; bas = 0; stp = ""; mv = 0
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
  text = text " " $0
  if (backlog_efficiency_tagged($0)) tagged = 1
  if ($0 ~ /^(<br>)?\*\*LANDED \(v[0-9]/) landed = 1
  if (inoc) { if ($0 ~ /^[ \t]*$/) inoc = 0; else oc = oc " " $0 }
  if (ocn == 0 && $0 ~ /^(<br>)?(\*\*)?Outcome measured:/) { ocn = 1; inoc = 1; oc = $0 }
  f = efield($0, "Baseline"); if (f != "@NONE@" && f ~ /^`?s3[0-9][0-9]([^0-9]|$)/) bas = 1
  f = efield($0, "Expected movement"); if (f != "@NONE@" && f ~ /[A-Za-z0-9]/) mv = 1
  f = efield($0, "Step")
  if (f != "@NONE@" && stp == "") { gsub(/[`*]/, "", f); sub(/[ \t].*$/, "", f); sub(/[.,;:]+$/, "", f); stp = f }
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
eff_step_ok() {
  case "$1" in
    pre-step) return 0 ;;
    gate-validation\[*\]) local _m="${1#gate-validation[}"; _m="${_m%]}"; [ "$_m" != gate-validation ] && grep -qxF -- "$_m" <<<"$EFF_VOCAB" ;;
    gate-validation) return 1 ;;
    *) grep -qxF -- "$1" <<<"$EFF_VOCAB" ;;
  esac
}
# eff_cite_ok <outcome-text> <root> -- 0 iff some `path:line "phrase"` resolves BY THE PHRASE to a
# `Failure caught:` line or a table row of that file under <root>. grep, never awk getline: an
# unopenable file must not read as an empty one.
eff_cite_ok() {
  local _c _p _ph _hits
  while IFS= read -r _c; do
    [ -n "$_c" ] || continue
    _p="${_c%%:*}"
    _ph="$(sed -n 's/^[^"]*"\([^"]*\)".*/\1/p' <<<"$_c")"
    [ -n "$_ph" ] && [ -f "$2/$_p" ] || continue
    _hits="$(grep -F -- "$_ph" "$2/$_p" 2>/dev/null)" || continue
    grep -qE 'Failure caught:|^[[:space:]]*\|' <<<"$_hits" && return 0
  done <<EOF
$(grep -oE '[A-Za-z0-9_./-]+\.(md|sh|py):[0-9]+[^"]{0,16}"[^"]+"' <<<"$1")
EOF
  return 1
}
# eff_close <outcome-present> <outcome-text> <root> -> a finding code, or nothing
eff_close() {
  [ "$1" = "1" ] || { echo NO-OUTCOME; return; }
  if ! eff_names_sprint "$2"; then
    eff_nostep_ok "$2" && return
    echo NO-SPRINT; return
  fi
  eff_shape_ok "$2" || { echo SHAPE; return; }
  eff_script_ok "$2" "$3" || { echo NO-SCRIPT; return; }
  eff_figs_ok "$2" || { echo NO-FIGURES; return; }
  case "$2" in
    *"did not fall"*) eff_cite_ok "$2" "$3" || echo NO-VALUE-CITATION ;;
    *fell*) ;;
    *) echo NO-DIRECTION ;;
  esac
}
# eff_corpus <ledger> <root> <live|archive> [<added-labels-file>] -> `CODE<TAB>LABEL` per finding;
# counts to $WORK/eff.counts. F-BASELINE / F-STEP / F-MOVEMENT (BL-817 item 2) judge a TAGGED entry
# (the population F-RULING reads; an untagged docs/analysis/ citer is F-UNTAGGED's) that is not on
# the no-step branch and whose label is in <added-labels-file> -- the entries ADDED on this branch.
# No file, or `--archive`, and they judge nothing: an entry filed before the arm is not re-filed.
eff_corpus() {
  local _l _t _a _r _n _ld _on _bs _st _mv _oc _code _pop=0 _ns=0 _ent=0 _fadd=0
  while IFS="$(printf '\t')" read -r _l _t _a _r _n _ld _on _bs _st _mv _oc; do
    [ -n "$_l" ] || continue
    _ent=$((_ent + 1))
    if [ "$3" = "live" ]; then
      [ "$_t" = "1" ] && [ "$_r" != "1" ] && printf 'F-RULING\t%s\n' "$_l"
      [ "$_a" = "1" ] && [ "$_t" != "1" ] && [ "$_n" != "1" ] && printf 'F-UNTAGGED\t%s\n' "$_l"
      if [ "$_t" = "1" ] && [ "$_n" != "1" ] && [ -n "${4:-}" ] && grep -qxF -- "$_l" "$4"; then
        _fadd=$((_fadd + 1))
        [ "$_bs" = "1" ] || printf 'F-BASELINE\t%s\n' "$_l"
        eff_step_ok "$_st" || printf 'F-STEP\t%s\n' "$_l"
        [ "$_mv" = "1" ] || printf 'F-MOVEMENT\t%s\n' "$_l"
      fi
    fi
    if [ "$_ld" = "1" ] && { [ "$_t" = "1" ] || [ "$_on" = "1" ]; }; then
      _pop=$((_pop + 1))
      _code="$(eff_close "$_on" "$_oc" "$2")"
      if [ -n "$_code" ]; then printf '%s\t%s\n' "$_code" "$_l"
      elif ! eff_names_sprint "$_oc"; then _ns=$((_ns + 1)); fi
    fi
  done <<EOF
$(awk -f "$EFFAWK" "$1")
EOF
  printf '%s %s %s %s\n' "$_ent" "$_pop" "$_ns" "$_fadd" > "$WORK/eff.counts"
}
# eff_added_labels <ledger> <root> <out-file> -- the entry labels in <ledger> that its version at
# the merge-base of HEAD with origin/main does not carry. Prints the base sha, or a SKIP reason
# (origin/main absent, or the ledger not tracked at the base) and leaves <out-file> absent.
eff_added_labels() {
  local _abs _rel _base
  _abs="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
  case "$_abs" in "$2"/*) _rel="${_abs#"$2"/}" ;; *) echo "not evaluated -- $1 is outside $2"; return ;; esac
  git -C "$2" rev-parse -q --verify origin/main >/dev/null 2>&1 || { echo "not evaluated -- origin/main is absent"; return; }
  _base="$(git -C "$2" merge-base origin/main HEAD 2>/dev/null)" || { echo "not evaluated -- no merge-base with origin/main"; return; }
  git -C "$2" cat-file -e "${_base}:${_rel}" 2>/dev/null || { echo "not evaluated -- $_rel is not tracked at the merge-base ${_base}"; return; }
  # Each step is checked: a failing read here would leave an EMPTY added set, which reads exactly
  # like "nothing was added" and lets every new filing through. Refuse instead.
  git -C "$2" show "${_base}:${_rel}" > "$3.blob" 2>/dev/null \
    && awk -f "$EFFAWK" "$3.blob" > "$3.bent" && awk -f "$EFFAWK" "$1" > "$3.tent" \
    && awk -F'\t' 'NR == FNR { b[$1] = 1; next } !($1 in b) { print $1 }' "$3.bent" "$3.tent" > "$3" \
    || { echo "$(me): FAIL -- could not derive the entries added since merge-base ${_base}; refusing rather than judging the filing shape against an empty set." >&2; rm -f "$3"; return 2; }
  echo "against merge-base ${_base}"
}
}

vbr_probe_e0() {
# E0 -- THE SELF-PROBE, BEFORE ANY CORPUS, BOTH DIRECTIONS. One seeded ledger, every case one
# entry; the expected finding SET is compared whole, so a case that stops firing and a case that
# starts firing both fail it. BL-959 is the second spelling of a valid line (bold label, `sprint
# 321`, a `Failure caught:` citation); BL-958 cites a phrase that resolves to an ordinary line.
# Item 1's remainder: every quiet sprint-branch seed carries EPM (a full script path that resolves,
# and the before/after words). BL-983 names only an unresolved path plus a RESOLVING `.sh:NN` value
# citation (NO-SCRIPT: a value citation is not the measuring script); BL-984 is the directory-plus-
# basename spelling (quiet); BL-985 a resolving directory whose basename is not under it (NO-SCRIPT);
# BL-986 has `before` alone and the sprint pair `s319 to s320` (NO-FIGURES); BL-987 `$2.23 to 1.24`
# with no before/after word (quiet). Item 2: $EP/added lists the entries "added on the branch".
# BL-988 carries none of the three fields (F-BASELINE, F-STEP, F-MOVEMENT); BL-989 all three
# (quiet); BL-990 the bare `gate-validation`, which the extractor never emits (F-STEP); BL-991
# `gate-validation[implementation]` and a backticked baseline (quiet); BL-992 `pre-step` and the
# baseline `s31` (F-BASELINE); BL-993 the sub-procedure `_gate-procedures` (F-STEP); BL-994 an empty
# `Expected movement:` (F-MOVEMENT); BL-995 no fields and NOT added (quiet: the scope); BL-996 added
# with the no-step line and no fields (quiet: the exemption).
EP="$WORK/effprobe"; mkdir -p "$EP/docs/m"
printf '| E-9 | ROWPHRASE alpha |\n**Mechanism.** Failure caught: FCPHRASE beta\nPLAINPHRASE gamma\n' > "$EP/docs/v.md"
: > "$EP/docs/m/roll.py"; : > "$EP/docs/m/run.sh"
printf 'BL-988\nBL-989\nBL-990\nBL-991\nBL-992\nBL-993\nBL-994\nBL-996\n' > "$EP/added"
EPR='Cites "A step with no measured value goes" in `.claude/rules/operator-rulings.md`.'
EPL='token-equivalent $9 with API $8 beside it, 1.0 h gap-inclusive'
EPM='measured by docs/m/roll.py, before 2.0 h and after 1.0 h'
EPS="$EPL, lead active 0.4 h, subagent \$5, $EPM"
{
  printf '# probe\n\n'
  printf '## BL-951\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\n' "$EPR"
  printf '## BL-952\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: graph s321, %s; did not fall.\n\n' "$EPR" "$EPS"
  printf '## BL-953\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: graph s321, %s; fell from 2.0 h.\n\n' "$EPR" "$EPS"
  printf '## BL-954\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: graph s321, %s; did not fall;\nvalue: docs/v.md:1 "ROWPHRASE alpha".\n\n' "$EPR" "$EPS"
  printf '## BL-955\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: no graph pipeline step; the cost lives in scripts/x.sh.\n\n' "$EPR"
  printf '## BL-956\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: the cost fell.\n\n' "$EPR"
  printf '## BL-957\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: graph s321, API $8, 1.0 h gap-inclusive; fell.\n\n' "$EPR"
  printf '## BL-958\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: graph s321, %s; did not fall; docs/v.md:3 "PLAINPHRASE gamma".\n\n' "$EPR" "$EPS"
  printf '## BL-959\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\n<br>**Outcome measured:** graph sprint 321, %s; did not fall; `docs/v.md:2` "FCPHRASE beta".\n\n' "$EPR" "$EPS"
  printf '## BL-960\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: no graph pipeline step.\n\n' "$EPR"
  printf '## BL-961\n\n**DEFECT (efficiency).** filed without the ruling.\n\n'
  printf '## BL-962\n\n**DEFECT (efficiency).** Cites "A step with no measured value\ngoes" in `.claude/rules/operator-rulings.md`.\n\n'
  printf '## BL-963\n\nFiled from docs/analysis/x.md with no tag.\n\n'
  printf '## BL-964\n\nFiled from docs/analysis/x.md; there is no graph pipeline step.\n\n'
  printf '## A section heading\n\nSection prose citing docs/analysis/x.md.\n\n'
  printf '## BL-965\n\nAn ordinary entry.\n\n'
  printf '## BL-966\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: no graph pipeline step; the cost lives in docs/analysis/pipeline-efficiency-s317-s320/scripts/x.py, analysis tooling.\n\n' "$EPR"
  printf '## BL-967\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: measured on s319 and s320, %s; fell from 2.0 h.\n\n' "$EPR" "$EPS"
  printf '## BL-968\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: the `s319` run, see docs/analysis/pipeline-efficiency-s317-s320/x.md, %s; fell.\n\n' "$EPR" "$EPS"
  printf '## BL-969\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: graph s321, %s; fell.\n\n' "$EPR" "$EPL"
  printf '## BL-970\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: graph s321, %s. Lead-seat local-model share of calls in this step group: s321 2%%; subagent seats ran hosted models only (opus, sonnet, haiku); lead `Agent` calls (s321 51). The step fell.\n\n' "$EPR" "$EPL"
  printf '## BL-971\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: graph s321, lead share 2%%, token-equivalent $39.1 (API $39.1), 0.9 h gap-inclusive, subagent $5.6; fell.\n\n' "$EPR"
  printf '## BL-972\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: graph s321, %s; lead and subagent 1.2 h; fell.\n\n' "$EPR" "$EPL"
  printf '## BL-973\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: graph s321, %s; lead active 1.2 h; fell.\n\n' "$EPR" "$EPL"
  printf '## BL-974\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: graph s321, %s; leading 1.2 h, mislead $3; subagent $5.6; fell.\n\n' "$EPR" "$EPL"
  printf '## BL-975\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: graph s321, %s; lead active 1.2 h, lead $3.4; subagents 0.8 h / $5.6; %s; fell.\n\n' "$EPR" "$EPL" "$EPM"
  printf '## BL-976\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: graph s321, %s; Lead (BL-819) s321 1.2 h; Subagent sprint 321 $5.6; %s; fell.\n\n' "$EPR" "$EPL" "$EPM"
  printf '## BL-977\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: graph s321, lead active 0.4 h; subagent seats ran hosted models only. token-equivalent $9 (API $8), 1.0 h gap-inclusive; fell.\n\n' "$EPR"
  printf '## BL-978\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: graph s321, lead active 0.4 h; subagents were not used; 1.0 h gap-inclusive, token-equivalent $9 (API $8); fell.\n' "$EPR"
  # THE OTHER THREE TAG SPELLINGS (BL-835), each closed with no outcome line, each must fire
  # NO-OUTCOME; and the near-miss, bold PROSE carrying the word, closed with no outcome, which must
  # stay out of the close population.
  printf '\n## BL-979\n\n**DEFECT, efficiency.** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\n' "$EPR"
  printf '## BL-980\n\n**NOTE (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\n' "$EPR"
  printf '## BL-981\n\nPreamble. **DEFECT. [efficiency rank 3] $12, 40 agent-minutes.** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\n' "$EPR"
  printf '## BL-982\n\n**Lead hours and lead tokens join every efficiency outcome.** x.\n\n**LANDED (v0.1.0, verified abc1234).**\n\n'
  printf '## BL-983\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: graph s321, %s, lead active 0.4 h, subagent $5, measured by docs/m/gone.py from docs/m/run.sh:12, before 2.0 h and after 1.0 h; fell.\n\n' "$EPR" "$EPL"
  printf '## BL-984\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: graph s321, %s, lead active 0.4 h, subagent $5, `docs/m/` (roll.py), before 2.0 h and after 1.0 h; fell.\n\n' "$EPR" "$EPL"
  printf '## BL-985\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: graph s321, %s, lead active 0.4 h, subagent $5, `docs/m/` (gone.py), before 2.0 h and after 1.0 h; fell.\n\n' "$EPR" "$EPL"
  printf '## BL-986\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: graph s319 to s320, %s, lead active 0.4 h, subagent $5, measured by docs/m/roll.py, 2.0 h before; fell.\n\n' "$EPR" "$EPL"
  printf '## BL-987\n\n**DEFECT (efficiency).** x. %s\n\n**LANDED (v0.1.0, verified abc1234).**\n\nOutcome measured: graph s321, %s, lead active 0.4 h, subagent $5, measured by docs/m/roll.py, $/shard $2.23 to 1.24; fell.\n\n' "$EPR" "$EPL"
  printf '## BL-988\n\n**DEFECT (efficiency).** x. %s\n\n' "$EPR"
  printf '## BL-989\n\n**DEFECT (efficiency).** x. %s\n\nBaseline: s320\nStep: `implementation`\nExpected movement: lead dollars per story fall.\n\n' "$EPR"
  printf '## BL-990\n\n**DEFECT (efficiency).** x. %s\n\nBaseline: s320\nStep: gate-validation\nExpected movement: falls.\n\n' "$EPR"
  printf '## BL-991\n\n**DEFECT (efficiency).** x. %s\n\n**Baseline:** `s319`\n**Step:** `gate-validation[implementation]`.\nExpected movement: falls.\n\n' "$EPR"
  printf '## BL-992\n\n**DEFECT (efficiency).** x. %s\n\nBaseline: s31\nStep: pre-step\nExpected movement: falls.\n\n' "$EPR"
  printf '## BL-993\n\n**DEFECT (efficiency).** x. %s\n\nBaseline: s320\nStep: _gate-procedures\nExpected movement: falls.\n\n' "$EPR"
  printf '## BL-994\n\n**DEFECT (efficiency).** x. %s\n\nBaseline: s320\nStep: implementation\nExpected movement:\n\n' "$EPR"
  printf '## BL-995\n\n**DEFECT (efficiency).** x. %s\n\n' "$EPR"
  printf '## BL-996\n\n**DEFECT (efficiency).** x. %s There is no graph pipeline step.\n\n' "$EPR"
} > "$EP/backlog.md"
EP_WANT="F-BASELINE BL-988|F-BASELINE BL-992|F-MOVEMENT BL-988|F-MOVEMENT BL-994|F-RULING BL-961|F-STEP BL-988|F-STEP BL-990|F-STEP BL-993|F-UNTAGGED BL-963|NO-FIGURES BL-986|NO-OUTCOME BL-951|NO-OUTCOME BL-979|NO-OUTCOME BL-980|NO-OUTCOME BL-981|NO-SCRIPT BL-983|NO-SCRIPT BL-985|NO-SPRINT BL-956|NO-SPRINT BL-960|NO-SPRINT BL-968|NO-VALUE-CITATION BL-952|NO-VALUE-CITATION BL-958|SHAPE BL-957|SHAPE BL-969|SHAPE BL-970|SHAPE BL-971|SHAPE BL-972|SHAPE BL-973|SHAPE BL-974|SHAPE BL-977|SHAPE BL-978|"
EP_GOT="$(eff_corpus "$EP/backlog.md" "$EP" live "$EP/added" | LC_ALL=C sort | tr '\t' ' ' | tr '\n' '|')"
if [ "$EP_GOT" != "$EP_WANT" ]; then
  echo "$(me): SELF-PROBE FAILED -- E0: the efficiency arms over the seeded ledger reported [$EP_GOT], expected [$EP_WANT]. Each seeded case is one branch of E1/E2/E3 (an absent row is a branch that cannot fire; an extra row is one that fires on a quiet case), so no corpus verdict from these arms would mean anything." >&2
  exit 2
fi
read -r EP_ENT EP_POP EP_NS EP_FADD < "$WORK/eff.counts"
[ "$EP_ENT" = 46 ] && [ "$EP_POP" = 31 ] && [ "$EP_NS" = 2 ] && [ "$EP_FADD" = 7 ] || {
  echo "$(me): SELF-PROBE FAILED -- E0: the seeded ledger parsed to $EP_ENT entries / $EP_POP in the close population / $EP_NS accepted on the no-step branch / $EP_FADD judged by the filing-shape arms, expected 46 / 31 / 2 / 7. BL-995 (not added) and BL-996 (no-step) must stay out of the filing-shape population. The section heading must close BL-964 and open nothing; BL-966's path-embedded s317 must not read as a sprint; BL-982's prose bold must stay out of the close population." >&2; exit 2; }
EP_ARCH="$(eff_corpus "$EP/backlog.md" "$EP" archive "$EP/added" | cut -f1 | grep -c '^F-')" || EP_ARCH=0
[ "$EP_ARCH" -eq 0 ] || { echo "$(me): SELF-PROBE FAILED -- E0: --archive applied a FILING arm ($EP_ARCH row(s)); filing is judged on the live ledger only." >&2; exit 2; }
}

vbr_sec_eff() {
EFF_ADDED=""; EFF_SCOPE="not evaluated under --archive"
if [ "${EFF_MODE:-live}" = live ]; then
  EFF_SCOPE="$(eff_added_labels "$LEDGER" "$SUBJECT_ROOT" "$WORK/eff.added")" || exit 2
  [ -f "$WORK/eff.added" ] && EFF_ADDED="$WORK/eff.added"
fi
EFF_OUT="$(eff_corpus "$LEDGER" "$SUBJECT_ROOT" "${EFF_MODE:-live}" "$EFF_ADDED")"
read -r EFF_ENT EFF_POP EFF_NS EFF_FADD < "$WORK/eff.counts"
EFF_N="$(printf '%s' "$EFF_OUT" | grep -c .)" || EFF_N=0
eff_report() {
  [ "$EFF_N" -eq 0 ] && return 0
  printf '%s\n' "$EFF_OUT" | awk -F'\t' '{ printf "FAIL: E\t%s\t%s\n", $2, $1 }' >&2
  echo "FAIL: E: $EFF_N efficiency finding(s) in $LEDGER (codes above). NO-OUTCOME/NO-SPRINT/NO-DIRECTION/NO-VALUE-CITATION/SHAPE: an efficiency close needs an 'Outcome measured:' line naming the consumer sprint, the token-equivalent \$ with API \$ beside, gap-inclusive hours, a lead figure and a subagent figure reported separately (each seat word -- lead, subagent(s) -- followed first by '<n> h' or '\$<n>', not a percentage or a count, and not one figure shared by both seats), and 'fell' or 'did not fall' -- the latter with a path:line \"phrase\" citation resolving to a Failure caught: line or step-value table row; or, with no sprint, the explicit 'no graph pipeline step' wording naming where 'the cost lives in'. F-RULING: cite \"A step with no measured value goes\" in .claude/rules/operator-rulings.md. NO-SCRIPT/NO-FIGURES: a sprint-naming outcome line also names the script that measured it (a resolving path ending .py or .sh, or a resolving directory token plus a bare basename under it; a path:line value citation does not count) and gives a before and an after figure (both words 'before' and 'after', or a '<num> to <num>' pair). F-BASELINE/F-STEP/F-MOVEMENT: a tagged efficiency entry ADDED on this branch carries a 'Baseline: s3NN' line, a 'Step: <token>' line whose token is a step of extract.py's STEP_RE (less SUBPROC), 'pre-step' or 'gate-validation[<step>]', and a non-empty 'Expected movement:' line, unless it says there is no graph pipeline step. F-UNTAGGED: an entry citing docs/analysis/ carries a bold efficiency tag (**DEFECT (efficiency).**, **DEFECT, efficiency.**, **NOTE (efficiency).** or **DEFECT. [efficiency rank N]**) or the 'no graph pipeline step' line." >&2
  return 1
}
if [ -n "$EFF_MODE" ]; then
  eff_report || exit 1
  echo "OK: validate-backlog-receipts --$([ "$EFF_MODE" = archive ] && echo archive || echo efficiency-only) -- E0 fired both directions over ${EP_ENT} seeded entries; ${EFF_ENT} entries in ${LEDGER}, ${EFF_POP} in the efficiency close population, every one carrying a valid outcome line (${EFF_NS} on the no-graph-pipeline-step branch); filing shape: ${EFF_FADD} added entr(y/ies) judged, ${EFF_SCOPE}."
  exit 0
fi
}

# ---------------------------------------------------------------------------
# score_ledger <ledger> <subject-root> -> result rows on stdout; the `sh` receipt count and
# the live entry count go to $WORK/counts, which `read_counts` lifts back into the caller.
# The corpus and the self-probe both go through this function, so the probe exercises the
# instrument rather than a second implementation of it.
# ---------------------------------------------------------------------------
score_ledger() {
  _sl_ledger="$1"; _sl_root="$2"
  rm -rf "$WORK/out" "$WORK/rec" "$WORK/t"
  # PRUNE BEFORE A PASS REUSES CHECKOUT NAMES. Every pass names its trees <record>.<suffix> under
  # $WORK/t, and the probes run several passes. A worker whose `worktree remove` lost the lock to a
  # sibling falls back to `rm -rf`, leaving the registration behind, and the next pass's `worktree
  # add` to that same path then fails five times and reads BROKEN. Measured: the fourth pass (R7's
  # probe) read BROKEN|no-base-worktree on 2 of 3 fixture runs until this prune was added.
  git -C "$_sl_root" worktree prune >/dev/null 2>&1 || true
  mkdir -p "$WORK/out" "$WORK/rec" "$WORK/t"
  _sl_i=0; _sl_e=0; _sl_m=0
  : > "$WORK/unrec"
  # The has/lacks verb pair is bound to the classifier's own case arm: if it moves, refuse rather than drift.
  # Fixture backlog-receipt-binding arm m8e-drift proves this fires (a copy with the arm renamed exits 2).
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
  # R1 runs this function TWICE over the same probe ledger (token seed, then generic), and
  # BL-910's counter must see each run as a first run or the second one reads it already
  # advanced and the receipt is stable-at-1. Resetting here rather than at the probe's
  # creation keeps the two runs independent, which is what the pair is for.
  # `printf 0`, never `: >`. An EMPTY file makes the receipt's `$(cat)` yield the empty
  # string, which is not `0`, so its first-reading branch never fires and the probe is stable
  # at 1 -- a seeded non-determinism that is not non-deterministic, and the arm it exists to
  # exercise would go untested while every other probe passed.
  [ -n "${BR_PROBE_COUNTER:-}" ] && printf 0 > "$BR_PROBE_COUNTER"

  BR_SENTINEL="$(git -C "$_sl_root" ls-tree -r --name-only HEAD 2>/dev/null | sed -n '1p')"
  if [ -z "$BR_SENTINEL" ]; then
    echo "$(me): FAIL -- $_sl_root has no tracked files at HEAD, so no checkout can be proven complete." >&2
    return 2
  fi

  BR_WORK="$WORK"; BR_SUBJECT_ROOT="$_sl_root"; BR_PATH_CLASS="$PATH_CLASS"
  BR_TOKAWK="$TOKAWK"; BR_GENERIC_SEED="${BR_GENERIC_SEED:-0}"
  export BR_WORK BR_SUBJECT_ROOT BR_PATH_CLASS BR_TOKAWK BR_GENERIC_SEED BR_SENTINEL BR_LIB_VARS
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
  export BR_WORK BR_SUBJECT_ROOT BR_SENTINEL BR_LIB_VARS
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

# closed_line / open_empty_line -- the two population lines, each ONE emitter, so the self-probe and
# the corpus print the same words. An EMPTY population is said as such, never as a clean one.
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

# ---------------------------------------------------------------------------
# R1 -- THE SEEDED SELF-PROBE, AND IT RUNS BEFORE THE CORPUS. An arm reporting "no receipt
# flipped" without first producing a flip has established that it ran, not that the receipts
# bind. The probe tree is a throwaway repository under mktemp and is never the real corpus;
# every entry below holds one branch of the scorer open:
#
#   BL-901 literal grep     MUST flip under the token seed, MUST NOT under a generic one
#   BL-902 drives a subject reads its subject's OUTPUT, so a comment in it changes nothing
#   BL-903 exits 9          out of population, decided BEFORE any seed
#   BL-904 no literal       UNSCORABLE, and its silence is not a bound receipt
#   BL-905 base 0 -> 1      must NOT be counted: the direction IS the finding
#   BL-906 unwritable path  cannot be fully seeded, and a partial seed is not a reading
#   BL-907 parses JSON      flips on ANY appended line, so the FORMAT control must claim it
#   BL-908 reads git        proves the checkout is a real repository: base 1, never 128
#   BL-910 exits 9 on its FIRST reading and 1 on its second, counting through a file OUTSIDE
#          the checkout, so it is UNSTABLE and not OUT-OF-POPULATION. Without it the re-read
#          has no subject: every other exit-9 receipt here answers 9 both times, so an arm
#          that skipped the second reading entirely would pass every probe beside it.
#   BL-909 TWO files, TWO literals, and it is the seed-COMPLETENESS probe. It flips only when
#          BOTH paths are seeded AND both greps are extracted, so a scorer that seeds the
#          first named path or reads the first grep and stops leaves it BOUND. Measured
#          against the real ledger: those two shortcuts take a correct 9 findings to 6 and to
#          3, silently, and every single-path single-grep probe above passes under both.
#   BL-911 runs one TRACKED script that exits 1: DRIVER, and alone it passes R2 as all-driver
#   BL-912 the same script `&&` one PRESENT in the checkout but UNTRACKED, at base 1: NOT a
#          driver, so UNSCORABLE -- and BL-911 plus BL-904 must still FAIL R2's all-driver test
# ---------------------------------------------------------------------------
vbr_probe_r1() {
P="$WORK/probe"
mkdir -p "$P/probe" "$P/docs"
echo "0.0.0" > "$P/VERSION"
printf 'alpha\nbeta\n' > "$P/probe/subject.txt"
printf 'alpha\n' > "$P/probe/flip.txt"
printf 'locked\n' > "$P/probe/locked.txt"
printf '{\n  "k": "alpha"\n}\n' > "$P/probe/doc.json"
# BL-909's two subjects. Neither carries its literal, so the receipt's base is 1 and it can
# only reach 0 when BOTH files take BOTH tokens.
printf 'first\n' > "$P/probe/one.txt"
printf 'second\n' > "$P/probe/two.txt"
# BL-910's counter lives OUTSIDE the checkout on purpose: each reading gets a fresh tree, so
# state kept inside one cannot survive into the next and the receipt could not differ.
BR_PROBE_COUNTER="$WORK/probe.counter"
printf 0 > "$BR_PROBE_COUNTER"
export BR_PROBE_COUNTER
printf '#!/usr/bin/env bash\nprintf %%s\\\\n WAIT\n' > "$P/probe/tool.sh"
# BL-911/BL-912's driven script. It exits 1, so both receipts reach the DRIVER test at base 1:
# BL-912's absent second segment is then refused by the TRACKED check alone, never by a 127.
printf '#!/usr/bin/env bash\nexit 1\n' > "$P/probe/drive.sh"
# BL-912's second script is PRESENT in every checkout and UNTRACKED: the post-checkout hook below
# writes it, and this ignore line keeps the checkout's porcelain clean so tree_complete accepts it.
# Present-but-untracked is the input that separates a TRACKED check from an `[ -f ]` one; an
# absent file would be refused by both and the probe could not tell them apart.
printf 'probe/untracked-driver.sh\n' > "$P/.gitignore"
{
  printf '# Probe ledger\n\n'
  printf '## BL-901\n\nverify: sh grep -q %s probe/subject.txt\n\n' "'PROBEMARKER'"
  # A PROSE LEAD-IN BULLET INSIDE THE HOST, BEFORE ITS RECEIPT. Under a loose label rule it opens
  # a phantom BL-632 that takes BL-902's receipt, BL-902 has no row, and the sh-receipt COUNT is
  # still 12 -- so the count arm cannot see it; the per-id asserts below can.
  printf '## BL-902\n\n- **BL-632 is LANDED** prose about another entry\n\nverify: sh out="$(bash probe/tool.sh)"; grep -q %s <<<"$out"\n\n' "'READY'"
  printf '## BL-903\n\nverify: sh grep -q %s probe/subject.txt || exit 9\n\n' "'NINEMARK'"
  printf '## BL-904\n\nverify: sh test -f probe/absent-file.txt\n\n'
  printf '## BL-905\n\nverify: sh ! grep -q %s probe/flip.txt\n\n' "'ZEROFLIP'"
  printf '## BL-906\n\nverify: sh grep -q %s probe/locked.txt\n\n' "'LOCKMARK'"
  printf '## BL-907\n\nverify: sh grep -q %s probe/doc.json || awk %s probe/doc.json\n\n' \
    "'JSONMARK'" "'END { exit (NR == 3 ? 1 : 0) }'"
  printf '## BL-908\n\nverify: sh git rev-parse HEAD >/dev/null 2>&1 || exit 9; grep -q %s probe/subject.txt\n\n' "'GITMARK'"
  printf '## BL-909\n\nverify: sh grep -q %s probe/one.txt && grep -q %s probe/two.txt\n\n' "'MARKONE'" "'MARKTWO'"
  printf '## BL-910\n\nverify: sh C="$BR_PROBE_COUNTER"; n=$(cat "$C" 2>/dev/null || echo 0); printf %%s $((n+1)) > "$C"; [ "$n" = "0" ] && exit 9; exit 1\n\n'
  printf '## BL-911\n\nverify: sh bash probe/drive.sh\n\n'
  printf '## BL-912\n\nverify: sh bash probe/drive.sh && bash probe/untracked-driver.sh\n\n'
} > "$P/docs/backlog.md"

# A THROWAWAY REPOSITORY, and the git environment is scrubbed first: git exports GIT_DIR
# ABSOLUTE into any hook run from a linked worktree, and a `git init` under an inherited one
# SILENTLY SUCCEEDS WITHOUT CREATING A REPOSITORY, redirecting every later call at the
# caller's index. That is the exact defect core/fixtures/lib/preamble.sh exists for.
(
  unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
  cd "$P" && git init -q . >/dev/null 2>&1 \
    && git add -A >/dev/null 2>&1 \
    && git -c user.email=probe@local -c user.name=probe commit -q -m probe >/dev/null 2>&1
) || { echo "$(me): SELF-PROBE FAILED -- the probe repository did not build, so nothing below was proven." >&2; exit 2; }
[ -d "$P/.git" ] || { echo "$(me): SELF-PROBE FAILED -- the probe directory is not a repository (an inherited GIT_DIR makes \`git init\` succeed without creating one), so every probe below would have run against the caller's tree." >&2; exit 2; }

# BL-906's subject must be UNWRITABLE IN THE CHECKOUT, which is what makes its seed refuse
# rather than apply -- and a `chmod` here does not survive, because git records only the
# executable bit and materialises every checkout at the umask default. A `post-checkout`
# hook inside the probe repository is the only place the mode can be set after the files
# exist and before a worker touches them. Asserted below rather than assumed: a probe whose
# subject is writable is a probe whose UNSEEDED branch has no subject at all.
mkdir -p "$P/.probehooks"
{ echo '#!/usr/bin/env bash'
  echo '[ -f probe/locked.txt ] && chmod 444 probe/locked.txt'
  echo 'printf "#!/usr/bin/env bash\nexit 1\n" > probe/untracked-driver.sh'
  echo 'exit 0'
} > "$P/.probehooks/post-checkout"
chmod +x "$P/.probehooks/post-checkout"
# SCRUBBED LIKE THE `git init` ABOVE, AND FOR A WORSE REASON THAN THAT ONE HAD.
#
# `git -C <dir>` DOES NOT OVERRIDE AN INHERITED `GIT_DIR`; the environment wins, for reads and
# for WRITES. MEASURED on two throwaway repositories: `GIT_DIR=A/.git git -C B log` reports A's
# commit, and `GIT_DIR=A/.git git -C B config probe.marker x` writes the key into A/.git/config
# and leaves B's untouched. So this line -- unscrubbed, `-C "$P"` notwithstanding -- wrote
# `core.hooksPath=<a mktemp probe directory>` into the CALLER'S repository whenever the gate ran
# from a linked worktree, where git exports GIT_DIR into every hook. The caller's own pre-push
# hook was then pointed at a directory this run deletes on exit, and a later push ran NO GATE AT
# ALL while reporting success. Measured on this repo: a release landed on origin ungated.
#
# The failure is silent in both directions -- the probe below still passes, because its
# unwritable-subject arm reads a `post-checkout` the probe repo never needed to find, and the
# caller shows nothing until the next push quietly skips its hooks.
# ON ONE LINE, DELIBERATELY. The fixture arm that binds this scrub reverts it by replacing this
# single line; spread across three, a mutation has to edit a `(`, a `)` and the lines between,
# and a `sed` that catches only some of them yields a mutant that does not PARSE -- which fails
# every arm for a reason the mutation does not own and scores as a kill nobody earned.
_br_scrub_config() { ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY; git -C "$1" config "$2" "$3" ); }
_br_scrub_config "$P" core.hooksPath "$P/.probehooks" >/dev/null 2>&1 || {
  echo "$(me): SELF-PROBE FAILED -- the probe repository would not take a hooks path, so its unwritable-subject probe has no subject." >&2; exit 2; }
# AND IT LANDED IN THE PROBE'S OWN CONFIG, ASSERTED BY PATH. `--file "$P/.git/config"` cannot be
# redirected by an environment variable, which is the whole point: a read that goes through
# GIT_DIR would confirm the write by looking at the very repository the write may have gone to
# by mistake, and would read as a pass in exactly the case this guard exists to catch.
_probe_hp="$(git config --file "$P/.git/config" --get core.hooksPath 2>/dev/null)" || _probe_hp=""
[ "$_probe_hp" = "$P/.probehooks" ] || {
  echo "$(me): SELF-PROBE FAILED -- the probe repository's own .git/config does not carry core.hooksPath (read by path: '${_probe_hp:-<unset>}', expected '$P/.probehooks'). The write went somewhere else -- under an inherited GIT_DIR that somewhere is the CALLER'S repository, whose pre-push hook would then point at a directory this run deletes." >&2; exit 2; }

# r2_alldriver <rows> <sh-count> -- exit 0 iff a ZERO-scored ledger is accounted for by drivers:
# nothing scored, at least one DRIVER, and every `sh` receipt is DRIVER, ALREADY-PASSING or
# OUT-OF-POPULATION. ONE implementation, called by R1 on seeded rows and by R2 on the corpus.
r2_alldriver() {
  printf '%s\n' "$1" | awk -F'\t' -v sh="$2" '
    $1 == "PROSE-CLOSABLE" || $1 == "BOUND" || $1 == "FORMAT-SENSITIVE" { sc++ }
    $1 == "DRIVER" { dr++ }
    $1 == "DRIVER" || $1 == "ALREADY-PASSING" || $1 == "OUT-OF-POPULATION" { ok++ }
    END { exit ((sc + 0) == 0 && (dr + 0) > 0 && (ok + 0) == sh + 0 ? 0 : 1) }'
}
probe_status() { printf '%s\n' "$1" | awk -F'\t' -v id="$2" '$2 == id { print $1 }'; }
probe_detail() { printf '%s\n' "$1" | awk -F'\t' -v id="$2" '$2 == id { print $3 }'; }
probe_count()  { printf '%s\n' "$1" | awk -F'\t' '$1 == "PROSE-CLOSABLE"' | grep -c . ; }

BR_GENERIC_SEED=0
R1_OUT="$(score_ledger "$P/docs/backlog.md" "$P")" || exit 2
R1_N="$(probe_count "$R1_OUT")" || R1_N=0
read_counts
R1_SH="$SH_RECEIPTS"

r1_fail() { echo "$(me): SELF-PROBE FAILED -- $1" >&2; printf '%s\n' "$R1_OUT" | sed 's/^/    /' >&2; exit 2; }

[ "$R1_SH" -eq 12 ] || r1_fail "the probe ledger parsed to $R1_SH sh receipts, not 12, so the entry grammar did not read the probe and nothing below is about the scorer."
[ "$(probe_status "$R1_OUT" BL-901)" = "PROSE-CLOSABLE" ] || r1_fail "the seeded prose-closable receipt did NOT flip under a seed carrying its own grep literal (got: $(probe_status "$R1_OUT" BL-901)). The scorer cannot produce a finding, so a clean corpus below would mean only that it ran."
# BEFORE BL-902's check, deliberately: a phantom that took BL-902's receipt also empties BL-902's
# row, so the BOUND check below would exit first and this arm could never speak.
[ -z "$(probe_status "$R1_OUT" BL-632)" ] || r1_fail "the prose bullet '- **BL-632 is LANDED**' inside BL-902 was read as an entry (row $(probe_status "$R1_OUT" BL-632)), so it took BL-902's receipt. The label rule in reconcile/lib.sh backlog_entry_label() must take a bullet only in its strict form."
[ "$(probe_status "$R1_OUT" BL-902)" = "BOUND" ] || r1_fail "the receipt that DRIVES its subject was reported $(probe_status "$R1_OUT" BL-902), not BOUND. An arm that flags a bound receipt puts every honest receipt in the finding set."
[ "$(probe_status "$R1_OUT" BL-903)" = "OUT-OF-POPULATION" ] || r1_fail "the base-exit-9 receipt was reported $(probe_status "$R1_OUT" BL-903), not OUT-OF-POPULATION. A receipt answering a question about its own preconditions is not reproducing, and seeding it scores a flip that is not about prose."
case "$(probe_detail "$R1_OUT" BL-903)" in
  *base-exit=9*) ;;
  *) r1_fail "the base-exit-9 receipt is out of population but its detail does not carry base-exit=9, so the exclusion cannot be attributed to the exit code." ;;
esac
[ "$(probe_status "$R1_OUT" BL-904)" = "UNSCORABLE" ] || r1_fail "the receipt with no extractable literal was reported $(probe_status "$R1_OUT" BL-904), not UNSCORABLE. A receipt this grammar cannot spell must be counted as unspelled, never as bound."
[ "$(probe_status "$R1_OUT" BL-905)" = "ALREADY-PASSING" ] || r1_fail "the base-0 receipt was reported $(probe_status "$R1_OUT" BL-905), not ALREADY-PASSING. A receipt whose fix is already present is not a finding in either direction, and an arm that counted its 0 -> 1 flip would report a defect where the ledger is simply ahead of its annotation."
case "$(probe_detail "$R1_OUT" BL-905)" in
  *"base-exit=0-seed-exit=1"*) ;;
  *) r1_fail "the base-0 receipt was not carried through the seed, so the 0 -> 1 direction is never observed and an arm that counted it would pass this probe unchanged." ;;
esac
[ "$(probe_status "$R1_OUT" BL-906)" = "UNSEEDED" ] || r1_fail "the receipt naming a path the seed cannot append to was reported $(probe_status "$R1_OUT" BL-906), not UNSEEDED. A seed that did not apply makes 'no flip' unreadable, and \`cmp -s\` is what separates the two."
[ "$(probe_status "$R1_OUT" BL-907)" = "FORMAT-SENSITIVE" ] || r1_fail "the receipt that PARSES its structured subject was reported $(probe_status "$R1_OUT" BL-907), not FORMAT-SENSITIVE. It flips on any appended line, so counting it would attribute a broken document to prose-closability."
[ "$(probe_status "$R1_OUT" BL-908)" = "PROSE-CLOSABLE" ] || r1_fail "the receipt that READS GIT was reported $(probe_status "$R1_OUT" BL-908) -- its base exit was not 1, so the checkout is not a faithful repository and the population of every git-reading receipt below is wrong."
# THE SEED-COMPLETENESS ASSERTION, and it is the one that two whole classes of wrong scorer
# fail. Both its paths must take the seed and both its literals must reach the seed line; a
# scorer that stops at the first of either leaves this BOUND while every other probe here
# still passes, and shrinks the real answer without saying so.
[ "$(probe_status "$R1_OUT" BL-909)" = "PROSE-CLOSABLE" ] || r1_fail "the TWO-file TWO-literal receipt was reported $(probe_status "$R1_OUT" BL-909), not PROSE-CLOSABLE. It flips only when every path it names is seeded AND every grep it carries is extracted, so this is a scorer that stops at the first of one or the other -- which reports FEWER findings than exist and reads exactly like a cleaner ledger."
[ "$R1_N" -eq 3 ] || r1_fail "the probe ledger scored $R1_N prose-closable receipts, expected exactly 3."
# THE RE-READ HAS A SUBJECT. Every other exit-9 receipt here answers 9 both times, so an arm
# that never took the second reading would pass every probe beside this one.
[ "$(probe_status "$R1_OUT" BL-910)" = "UNSTABLE" ] || r1_fail "the receipt that exits 9 on its FIRST reading and 1 on its second was reported $(probe_status "$R1_OUT" BL-910), not UNSTABLE. A non-deterministic receipt filed as OUT-OF-POPULATION is a real push failure attributed to the wrong thing -- measured once in thirty-three runs under contention -- and one silently absorbed is a receipt nobody fixes."
case "$(probe_detail "$R1_OUT" BL-910)" in
  *"base-exit=9/"*) ;;
  *) r1_fail "the unstable receipt is reported without BOTH of its exits, so the report cannot say what disagreed." ;;
esac
# ...and its NEAR-MISS twin: a receipt that exits 9 on BOTH readings is a precondition that is
# genuinely unmet and must stay out of population. Without this, an arm calling every non-0/1
# exit unstable would empty the class the re-read exists to protect.
[ "$(probe_status "$R1_OUT" BL-903)" = "OUT-OF-POPULATION" ] || r1_fail "the receipt that exits 9 on EVERY reading was reported $(probe_status "$R1_OUT" BL-903) after the re-read, not OUT-OF-POPULATION."
# THE DRIVER CLASS, BOTH DIRECTIONS. BL-911 runs one TRACKED script and must be DRIVER. BL-912
# runs the same script and then one that is PRESENT IN THE CHECKOUT BUT UNTRACKED, at base 1, so
# only the tracked check can refuse it -- it must fall through to UNSCORABLE. BL-902 above still
# reads BOUND: a one-liner that also greps is not a driver.
[ "$(probe_status "$R1_OUT" BL-911)" = "DRIVER" ] || r1_fail "the receipt that only runs a TRACKED script was reported $(probe_status "$R1_OUT" BL-911), not DRIVER. Every receipt rewritten the way R2's own remedy says would then be unscorable, and a ledger of them fails R2 as a zero."
[ "$(probe_status "$R1_OUT" BL-912)" = "UNSCORABLE" ] || r1_fail "the receipt whose second script is present but UNTRACKED was reported $(probe_status "$R1_OUT" BL-912), not UNSCORABLE. A driver whose subject is not in the tree is not a driver; this is an arm that reads the disk, not the index."
# R2's ALL-DRIVER ESCAPE, BOTH DIRECTIONS, ON THE SCORER'S OWN ROWS. A ledger whose only `sh`
# receipt is BL-911 must pass; the same ledger plus BL-904 (UNSCORABLE, not a driver) must refuse.
# The two inputs are asserted to DIFFER first, or the pair is one measurement taken twice.
R1_DRV_ONLY="$(printf '%s\n' "$R1_OUT" | awk -F'\t' '$2 == "BL-911"')"
R1_DRV_MIX="$(printf '%s\n' "$R1_OUT" | awk -F'\t' '$2 == "BL-911" || $2 == "BL-904"')"
[ -n "$R1_DRV_ONLY" ] && [ "$R1_DRV_ONLY" != "$R1_DRV_MIX" ] || r1_fail "the all-driver pair did not build two different row sets, so neither verdict below would discriminate."
r2_alldriver "$R1_DRV_ONLY" 1 || r1_fail "R2's all-driver escape REFUSED a ledger whose only sh receipt is a DRIVER, so a ledger rewritten as R2's remedy says still fails as a zero."
if r2_alldriver "$R1_DRV_MIX" 2; then
  r1_fail "R2's all-driver escape ACCEPTED a ledger carrying an UNSCORABLE non-driver receipt beside a driver, so one driver acquits every unspelled receipt beside it."
fi

# THE SECOND DIRECTION. The generic seed carries no token, and the arm must go quiet on the
# SAME ledger. Without it, an arm that flags everything and an arm that discriminates print
# the identical finding above.
BR_GENERIC_SEED=1
R1G_OUT="$(score_ledger "$P/docs/backlog.md" "$P")" || exit 2
BR_GENERIC_SEED=0
# BL-907 is EXPECTED to flip here and is excluded by name: it is the probe whose subject is
# a structured document, so it flips on ANY appended line -- which is the very property the
# format control exists to detect, and asserting it does not flip would assert the opposite
# of what this file ships. Every OTHER receipt must be quiet, and the count is taken over
# that remainder so the exclusion cannot hide a second flip.
R1G_N="$(printf '%s\n' "$R1G_OUT" | awk -F'\t' '$1 == "PROSE-CLOSABLE" && $2 != "BL-907"' | grep -c .)" || R1G_N=0
if [ "$R1G_N" -ne 0 ]; then
  echo "$(me): SELF-PROBE FAILED -- a seed carrying NO token flipped $R1G_N receipt(s) whose subject is plain text. The arm is reporting something other than the receipt's own literal, so every finding below is suspect." >&2
  printf '%s\n' "$R1G_OUT" | sed 's/^/    /' >&2
  exit 2
fi
case "$(probe_status "$R1G_OUT" BL-907)" in
  PROSE-CLOSABLE) ;;
  *) echo "$(me): SELF-PROBE FAILED -- the structured-subject receipt did NOT flip under a token-free line, so the format control below has nothing to discriminate and its acquittal of a real finding would go unnoticed." >&2; exit 2 ;;
esac
case "$(probe_status "$R1G_OUT" BL-901)" in
  PROSE-CLOSABLE) echo "$(me): SELF-PROBE FAILED -- the generic seed flipped the literal-grep receipt, so the two seeds do not differ and the pair above is one measurement twice." >&2; exit 2 ;;
esac

# UNRECOGNISED-VALUE SELF-PROBE: a seeded `verify: manual.` entry MUST be named by id, and the
# near-misses `manual` and `manual reason` MUST NOT be, and must count as manual.
mkdir -p "$WORK/unrecprobe"
printf '## BL-951\n\nverify: manual. reason\n\n## BL-952\n\nverify: manual\n\n## BL-953\n\nverify: manual reason\n\n' > "$WORK/unrecprobe/backlog.md"
score_ledger "$WORK/unrecprobe/backlog.md" "$P" >/dev/null || exit 2
read_counts
if [ "$(cut -f1 "$WORK/unrec" | tr '\n' ' ')" != "BL-951 " ] || [ "$MANUAL_RECEIPTS" -ne 2 ] || [ "$ENTRIES" -ne 3 ]; then
  echo "$(me): SELF-PROBE FAILED -- the unrecognised-value arm did not name exactly BL-951 (named: $(cut -f1 "$WORK/unrec" | tr '\n' ' '); manual $MANUAL_RECEIPTS of $ENTRIES), so a clean corpus below would mean only that it ran." >&2; exit 2
fi
}

vbr_probe_r7r8() {
# ---------------------------------------------------------------------------
# R7 / R8 SELF-PROBE (BL-836), BOTH DIRECTIONS, BEFORE THE CORPUS, THROUGH THE SAME FUNCTIONS.
# The OPEN half: a seeded ledger of receipts whose exits sit either side of the FAIL set --
#   BL-971 exit 2                       -> OUT-OF-POPULATION, NO cannot-measure marker  (a: OK)
#   BL-972 exit 9                       -> marker exit-9                                (b: FAIL)
#   BL-973 own shell: command not found -> marker own-shell (rc 127)                    (c: FAIL)
#   BL-974 bare 127 from a SUBJECT      -> NO marker                                    (g: not FAIL)
#   BL-977 exit 126                     -> marker exit-126
#   BL-978 exit 130                     -> marker exit-130 (the >= 128 branch)
#   BL-975 `. <absent file>` unguarded  -> marker own-shell (rc 1: BL-834's guardless shape)
# The CLOSED half: a two-commit repository, base then branch, run with --base at the base sha --
#   BL-981 stamped LANDED on the branch, receipt greps a symbol the branch RENAMED (BL-830) -> FAIL (d)
#   BL-983 heading ADDED to the archive on the branch, receipt exits 1                      -> FAIL (e)
#   BL-982 stamped LANDED on the branch, receipt exits 0                                    -> OK   (f)
#   BL-984 LANDED already at base, broken receipt                     -> NOT RUN (near-miss of d)
#   BL-985 in the archive already at base, broken receipt             -> NOT RUN (near-miss of e)
#   BL-988 archived at base, heading RETITLED on the branch           -> NOT RUN (near-miss of e)
#   BL-989 absent at base, filed AND rotated on the branch, exits 0   -> OK (a release's own close)
#   BL-986 OPEN on the branch, the same renamed-symbol receipt as BL-981 -> STILL-LIVE shape, exits
#          1, and is NOT a finding: an open entry's renamed anchor CANNOT be seen by exit alone.
# ---------------------------------------------------------------------------
r7_fail() { echo "$(me): SELF-PROBE FAILED -- $1" >&2; exit 2; }
mkdir -p "$WORK/r7probe"
printf '#!/usr/bin/env bash\nsubject_helper_never_shipped_zz\n' > "$P/probe/calls-missing.sh"
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
  cd "$P" && git add probe/calls-missing.sh >/dev/null 2>&1 \
    && git -c user.email=probe@local -c user.name=probe commit -q -m probe2 >/dev/null 2>&1 ) \
  || r7_fail "the probe repository would not take the R7 subject commit."
{
  printf '## BL-971\n\nverify: sh exit 2\n\n'
  printf '## BL-972\n\nverify: sh exit 9\n\n'
  printf '## BL-973\n\nverify: sh receipt_helper_never_shipped_zz x\n\n'
  printf '## BL-974\n\nverify: sh bash probe/calls-missing.sh\n\n'
  printf '## BL-975\n\nverify: sh . probe/absent-helper-lib.sh\n\n'
  printf '%s\n\n' '## BL-976' 'verify: sh test -n "${BR_RECEIPTS_RUNNING:-}"'
  printf '%s\n\n' '## BL-979' 'verify: sh printf "%s" "${BR_RECEIPTS_RUNNING:-}" > "$BR_WORK/r7probe/seen"'
  printf '## BL-977\n\nverify: sh exit 126\n\n'
  printf '## BL-978\n\nverify: sh exit 130\n\n'
} > "$WORK/r7probe/backlog.md"
R7_OUT="$(score_ledger "$WORK/r7probe/backlog.md" "$P")" || exit 2
cm_of() { printf '%s\n' "$R7_OUT" | awk -F'\t' -v id="$1" '$2 == id { print $1 "|" $3 }'; }
case "$(cm_of BL-971)" in "OUT-OF-POPULATION|base-exit=2") ;; *) r7_fail "(a) an OPEN receipt exiting 2 read '$(cm_of BL-971)', not OUT-OF-POPULATION without a cannot-measure marker. 2-8 are STILL-LIVE codes here, and a FAIL set that takes them fails every honest reproduction." ;; esac
case "$(cm_of BL-972)" in "OUT-OF-POPULATION|base-exit=9-cannot-measure=exit-9") ;; *) r7_fail "seed BL-972: (b)an OPEN receipt exiting 9 read '$(cm_of BL-972)', not cannot-measure=exit-9." ;; esac
case "$(cm_of BL-973)" in "OUT-OF-POPULATION|base-exit=127-cannot-measure=own-shell") ;; *) r7_fail "(c) an OPEN receipt whose OWN shell reported 'command not found' read '$(cm_of BL-973)', not cannot-measure=own-shell." ;; esac
case "$(cm_of BL-974)" in "OUT-OF-POPULATION|base-exit=127") ;; *) r7_fail "(g) an OPEN receipt exiting 127 because its SUBJECT called a missing helper read '$(cm_of BL-974)', not OUT-OF-POPULATION without a marker. Bare 127 is a defect a receipt may be asserting." ;; esac
case "$(cm_of BL-975)" in "OUT-OF-POPULATION|base-exit=1-cannot-measure=own-shell") ;; *) r7_fail "an OPEN receipt sourcing an absent file with no guard (exit 1, BL-834's shape) read '$(cm_of BL-975)', not cannot-measure=own-shell." ;; esac
case "$(cm_of BL-976)" in *"|base-exit=0"*) ;; *) r7_fail "seed BL-976: an OPEN receipt did not see BR_RECEIPTS_RUNNING ('$(cm_of BL-976)'), so an open receipt re-entering this validator through pre-push would run every open receipt again, without end." ;; esac
# BL-979, THE RE-ENTRY KEY. The receipt wrote the sentinel it inherited. A validator that receipt
# starts over the SAME ledger -- from any checkout of the same repository -- must read re-entry,
# and one over a ledger of its own seeding must not, which is the receipt shape BL-227, BL-387 and
# BL-680 use. Driven through re_entry_of and ledger_key, the functions the run itself calls; a
# nested validator here would run this probe again, under a new key each time, without end.
R7_SEEN="$(cat "$WORK/r7probe/seen" 2>/dev/null)" || R7_SEEN=""
[ "$R7_SEEN" = "$(ledger_key "$WORK/r7probe/backlog.md" "$P")" ] || r7_fail "seed BL-979: an OPEN receipt inherited the sentinel '$R7_SEEN', not this ledger's key, so a re-entry over the same ledger would not be recognised."
mkdir -p "$WORK/r7other"
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
  cd "$WORK/r7other" && git init -q . >/dev/null 2>&1 && printf '# other\n' > backlog.md && git add -A >/dev/null 2>&1 \
    && git -c user.email=probe@local -c user.name=probe commit -q -m other >/dev/null 2>&1 ) \
  || r7_fail "seed BL-979: the foreign-ledger probe repository did not build."
[ -z "$(re_entry_of "$R7_SEEN" "$(ledger_key "$WORK/r7other/backlog.md" "$WORK/r7other")")" ] || r7_fail "seed BL-979: a validator a receipt starts over a ledger of its OWN seeding read as a re-entry, so it would skip R2-R8 and score nothing."
[ -z "$(re_entry_of "$R7_SEEN" "$(ledger_key "$P/other-ledger.md" "$P")")" ] || r7_fail "seed BL-979: a different ledger in the SAME repository read as a re-entry."
[ "$(re_entry_of "$R7_SEEN" "$R7_SEEN")" = 1 ] || r7_fail "seed BL-979: the same ledger did not read as a re-entry."
[ -z "$(re_entry_of "" "$R7_SEEN")" ] || r7_fail "seed BL-979: no inherited sentinel read as a re-entry."
# The key must not depend on which checkout of the repository resolves it.
R7_WT="$WORK/r7wt"
git -C "$P" worktree add --detach -q "$R7_WT" HEAD >/dev/null 2>&1 || r7_fail "seed BL-979: no checkout of the probe repository for the key's checkout-invariance."
_r7_k1="$(ledger_key "$P/x.md" "$P")"; _r7_k2="$(ledger_key "$R7_WT/x.md" "$R7_WT")"
git -C "$P" worktree remove --force "$R7_WT" >/dev/null 2>&1 || rm -rf "$R7_WT"
[ -n "$_r7_k1" ] && [ "$_r7_k1" = "$_r7_k2" ] || r7_fail "seed BL-979: the same ledger resolved to two keys from two checkouts ('$_r7_k1' / '$_r7_k2'), so a pre-push re-entered from a receipt's checkout would not be recognised."
# The REPOSITORY half of the key. Two repositories that each carry a ledger at the same relative
# path (every one carries docs/backlog.md) must get different keys, or a receipt that seeds its own
# repository's docs/backlog.md -- BL-387's shape -- reads as a re-entry of the outer run. $P and
# r7other both hold x.md at their root, so only the common dir can tell them apart.
_r7_k3="$(ledger_key "$WORK/r7other/x.md" "$WORK/r7other")"
[ -n "$_r7_k3" ] && [ "${_r7_k1#*|}" = "${_r7_k3#*|}" ] || r7_fail "seed BL-979: the cross-repository pair does not share a relative path ('$_r7_k1' / '$_r7_k3'), so it cannot test the repository half of the key."
[ "$_r7_k3" != "$_r7_k1" ] || r7_fail "seed BL-979: two repositories with a ledger at the same relative path resolved to ONE key ('$_r7_k1'), so a receipt seeding its own docs/backlog.md would read as a re-entry and score nothing."
case "$(cm_of BL-977)" in "OUT-OF-POPULATION|base-exit=126-cannot-measure=exit-126") ;; *) r7_fail "seed BL-977: an OPEN receipt exiting 126 read '$(cm_of BL-977)', not cannot-measure=exit-126." ;; esac
case "$(cm_of BL-978)" in "OUT-OF-POPULATION|base-exit=130-cannot-measure=exit-130") ;; *) r7_fail "seed BL-978: an OPEN receipt exiting 130 (a signal) read '$(cm_of BL-978)', not cannot-measure=exit-130." ;; esac
case "$(open_skip_line)" in "OPEN-POPULATION: SKIPPED -- "*) ;; *) r7_fail "the open-population skip line does not say SKIPPED." ;; esac
read_counts
[ "$(open_empty_line "$SH_RECEIPTS")" = "" ] || r7_fail "the open-population line said EMPTY over a ledger of $SH_RECEIPTS sh receipts."
case "$(open_empty_line 0)" in "OPEN-POPULATION: EMPTY -- 0 "*) ;; *) r7_fail "the open-population line did not say EMPTY at 0 sh receipts, so an empty run would read as a clean one." ;; esac

# The CLOSED half's repository: base, then the branch commit.
Q="$WORK/r8probe"
mkdir -p "$Q/docs" "$Q/probe"
echo "0.0.0" > "$Q/VERSION"
printf 'bg1_killed() { :; }\n' > "$Q/probe/run.sh"
r8_ledger() { # r8_ledger <stamp 0|1>
  printf '# Probe ledger\n\n'
  printf '## BL-981\n\n'; [ "$1" = 1 ] && printf '**LANDED (v0.0.1, verified probe).**\n\n'
  printf 'verify: sh grep -q %s probe/run.sh\n\n' "'bg1_killed'"
  printf '## BL-982\n\n'; [ "$1" = 1 ] && printf '**LANDED (v0.0.1, verified probe).**\n\n'
  printf 'verify: sh exit 0\n\n'
  printf '## BL-984\n\n**LANDED (v0.0.0, verified probe).**\n\nverify: sh exit 1\n\n'
  printf '## BL-986\n\nverify: sh grep -q %s probe/run.sh\n\n' "'bg1_killed'"
  printf '## BL-987\n\n'; [ "$1" = 1 ] && printf '**LANDED (v0.0.1, verified probe).**\n\n'
  printf '%s\n\n' 'verify: sh test -n "${BR_RECEIPTS_RUNNING:-}"'
  # BL-983 is live at the base and leaves the live ledger on the branch: a real rotation.
  [ "$1" = 0 ] && printf '## BL-983\n\nverify: sh exit 1\n\n'
  return 0
}
r8_ledger 0 > "$Q/docs/backlog.md"
# BL-988 is archived at the base and only RETITLED on the branch: its heading is added to the
# archive diff but it never left the live ledger, so it is not a rotation (near-miss of e).
printf '# Archive\n\n## BL-985\n\nverify: sh exit 1\n\n## BL-988 — old title\n\nverify: sh exit 1\n\n' > "$Q/docs/backlog.archive.md"
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
  cd "$Q" && git init -q . >/dev/null 2>&1 && git add -A >/dev/null 2>&1 \
    && git -c user.email=probe@local -c user.name=probe commit -q -m base >/dev/null 2>&1 ) \
  || r7_fail "the closed-population probe repository did not build."
[ -d "$Q/.git" ] || r7_fail "the closed-population probe directory is not a repository."
R8_MB="$(git -C "$Q" rev-parse HEAD 2>/dev/null)" || R8_MB=""
[ -n "$R8_MB" ] || r7_fail "the closed-population probe has no base commit."
# Before the branch commit: HEAD == base, so the population is derived and EMPTY.
R8_EMPTY="$(score_closed "$Q/docs/backlog.md" "$Q" "$R8_MB")" || exit 2
[ -z "$R8_EMPTY" ] || r7_fail "the closed population at HEAD == base was not empty: $R8_EMPTY"
case "$(closed_line 0)" in "CLOSED-POPULATION: EMPTY -- 0 "*) ;; *) r7_fail "a derived, empty closed population was not reported as EMPTY: $(closed_line 0)" ;; esac
# The branch: stamp two, rotate one in, and rename the symbol BL-981 and BL-986 grep for.
printf 'bg1_convicts() { :; }\n' > "$Q/probe/run.sh"
r8_ledger 1 > "$Q/docs/backlog.md"
# BL-989 appears nowhere at the base: filed AND rotated on the branch, as a release's own close is.
printf '# Archive\n\n## BL-985\n\nverify: sh exit 1\n\n## BL-988 — new title\n\nverify: sh exit 1\n\n## BL-983\n\n**LANDED (v0.0.1, verified probe).**\n\nverify: sh exit 1\n\n## BL-989\n\n**LANDED (v0.0.1, verified probe).**\n\nverify: sh exit 0\n\n' > "$Q/docs/backlog.archive.md"
( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY
  cd "$Q" && git add -A >/dev/null 2>&1 \
    && git -c user.email=probe@local -c user.name=probe commit -q -m branch >/dev/null 2>&1 ) \
  || r7_fail "the closed-population probe's branch commit did not build."
R8_OUT="$(score_closed "$Q/docs/backlog.md" "$Q" "$R8_MB")" || exit 2
c8_of() { printf '%s\n' "$R8_OUT" | awk -F'\t' -v id="$1" '$2 == id { print $1 "|" $3 }'; }
[ "$(c8_of BL-981)" = "CLOSED-FAIL|exit=1" ] || r7_fail "(d) an entry stamped LANDED on the branch whose receipt exits 1 (a renamed symbol) read '$(c8_of BL-981)', not CLOSED-FAIL exit=1."
[ "$(c8_of BL-983)" = "CLOSED-FAIL|exit=1" ] || r7_fail "(e) an entry rotated into the archive on the branch whose receipt exits 1 read '$(c8_of BL-983)', not CLOSED-FAIL exit=1."
[ "$(c8_of BL-982)" = "CLOSED-OK|exit=0" ] || r7_fail "(f) an entry stamped LANDED on the branch whose receipt exits 0 read '$(c8_of BL-982)', not CLOSED-OK."
[ -z "$(c8_of BL-984)" ] || r7_fail "an entry LANDED already at the base was run ('$(c8_of BL-984)'); the population is the BRANCH's closes."
[ -z "$(c8_of BL-985)" ] || r7_fail "an entry already in the archive at the base was run ('$(c8_of BL-985)'); only headings the branch ADDED are rotations."
[ -z "$(c8_of BL-986)" ] || r7_fail "an OPEN entry was run as closed ('$(c8_of BL-986)')."
[ -z "$(c8_of BL-988)" ] || r7_fail "seed BL-988: an archived entry only RETITLED on the branch was run as a rotation ('$(c8_of BL-988)'); a rotation is an id NEW to the archive."
[ "$(c8_of BL-989)" = "CLOSED-OK|exit=0" ] || r7_fail "seed BL-989: an entry filed AND rotated on the branch read '$(c8_of BL-989)', not CLOSED-OK: a release's own close was dropped from R8."
[ "$(c8_of BL-987)" = "CLOSED-OK|exit=0" ] || r7_fail "seed BL-987: a closed receipt did not see BR_RECEIPTS_RUNNING ('$(c8_of BL-987)'), so a receipt re-entering this validator through pre-push would run R8 again, without end."
case "$(closed_line 2)" in "CLOSED-POPULATION: 5 sh receipt(s) run over merge-base "*"(3 stamped LANDED on the branch, 2 rotated on the branch), 2 not exiting 0.") ;; *) r7_fail "the closed-population line misreports the probe: $(closed_line 2)" ;; esac
# And a base ref that does not resolve: NOT DERIVED, never EMPTY.
score_closed "$Q/docs/backlog.md" "$Q" "refs/heads/no-such-base-zz" >/dev/null || exit 2
case "$(closed_line 0)" in "CLOSED-POPULATION: NOT DERIVED "*) ;; *) r7_fail "an unresolvable base was reported as '$(closed_line 0)', not NOT DERIVED." ;; esac
# And the re-entry skip: no receipt runs, and the line says SKIPPED rather than EMPTY or a count.
R8_SKIP=1
R8_SKIPPED_OUT="$(score_closed "$Q/docs/backlog.md" "$Q" "$R8_MB")" || exit 2
R8_SKIP=0
[ -z "$R8_SKIPPED_OUT" ] || r7_fail "a re-entered run executed closed receipts: $R8_SKIPPED_OUT"
case "$(closed_line 0)" in "CLOSED-POPULATION: SKIPPED "*) ;; *) r7_fail "a re-entered run was reported as '$(closed_line 0)', not SKIPPED." ;; esac
R7_PROBED="R7 fired both directions over 8 seeded open receipts and R8 over 9 seeded closed-population entries and the re-entry skip"
}

# ---------------------------------------------------------------------------
# R9 -- THE LIVE-LEDGER JOINS (BL-872); see the header. ONE reader per producer and ONE judge, called
# by the self-probe on seeded ledgers and by the corpus on the live one.
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
# r9_run -> prints the R9 line on stdout; returns 0 held or not run, 1 a join failed, 2 a refusal
r9_run() {
  R9_SIZE="$SELF_ROOT/scripts/validate-backlog-size.sh"
  if [ ! -f "$R9_SIZE" ]; then
    echo "R9: NOT RUN -- scripts/validate-backlog-size.sh is absent beside this validator, so the live-ledger joins (j1 population, b16 ceiling) observed NOTHING in this tree; that is not a clean result."
    return 0
  fi
  if ! git -C "$SUBJECT_ROOT" cat-file -e "HEAD:scripts/backlog-reverify.sh" 2>/dev/null; then
    echo "R9: NOT RUN -- the subject repository's HEAD carries no scripts/backlog-reverify.sh, so the live-ledger joins (j1 population, b16 ceiling) observed NOTHING in this tree; that is not a clean result."
    return 0
  fi
  R9_T="$WORK/t/r9"
  mkdir -p "$WORK/t"
  git -C "$SUBJECT_ROOT" worktree add --detach -q "$R9_T" HEAD >/dev/null 2>&1 \
    || { echo "$(me): FAIL -- R9 could not check out HEAD of $SUBJECT_ROOT for the classifier; this is a refusal, not a reading." >&2; return 2; }
  R9_REV="$R9_T/scripts/backlog-reverify.sh"
  # THE SELF-PROBE, BOTH DIRECTIONS, BEFORE THE CORPUS, ON THE REAL PROGRAMS.
  printf '# R9 probe\n\n## BL-001 — probe\n\nverify: sh true\n\n## BL-002 — probe\n\nverify: manual\n' > "$WORK/r9p2.md"
  { cat "$WORK/r9p2.md"; printf '\n## BL-003 — probe\n\nverify: manual\n'; } > "$WORK/r9p3.md"
  r9_prow="$(bash "$R9_REV" "$WORK/r9p2.md" 2>/dev/null)"
  r9_ps2="$(AI_DLC_BACKLOG_MAX_ENTRIES=100000 bash "$R9_SIZE" "$WORK/r9p2.md" 2>&1)"
  r9_ps3="$(AI_DLC_BACKLOG_MAX_ENTRIES=100000 bash "$R9_SIZE" "$WORK/r9p3.md" 2>&1)"
  r9_pread="$(r9_read_rows "$r9_prow") $(r9_read_size "$r9_ps2") $(r9_read_size "$r9_ps3")"
  r9_pfail=""
  [ "$r9_pread" = "1 2 2 CLOSE-CANDIDATE 2 3" ] || r9_pfail="the readers parsed '$r9_pread' from the real classifier and ceiling on two seeded ledgers, want '1 2 2 CLOSE-CANDIDATE 2 3'"
  [ -n "$r9_pfail" ] || r9_judge 1 "$r9_ps2" "$r9_prow" >/dev/null || r9_pfail="the join REFUSED the seeded truth (arm 1, classifier 1 resolved of 2, ceiling 2)"
  [ -n "$r9_pfail" ] || ! r9_judge 0 "$r9_ps2" "$r9_prow" >/dev/null || r9_pfail="j1 ACCEPTED an arm population one short of the classifier's"
  [ -n "$r9_pfail" ] || ! r9_judge 1 "$r9_ps3" "$r9_prow" >/dev/null || r9_pfail="b16 ACCEPTED a ceiling reading one entry more than the classifier"
  if [ -n "$r9_pfail" ]; then
    git -C "$SUBJECT_ROOT" worktree remove --force "$R9_T" >/dev/null 2>&1 || rm -rf "$R9_T"
    echo "$(me): SELF-PROBE FAILED -- R9: $r9_pfail; the live-ledger joins below would prove nothing." >&2
    return 2
  fi
  # THE CORPUS. The classifier's receipts run in the checkout; a re-entry into this validator skips.
  r9_rows="$(BR_RECEIPTS_RUNNING="$LEDGER_KEY" bash "$R9_REV" "$LEDGER" 2>/dev/null)"
  r9_size="$(AI_DLC_BACKLOG_MAX_ENTRIES=100000 bash "$R9_SIZE" "$LEDGER" 2>&1)"
  git -C "$SUBJECT_ROOT" worktree remove --force "$R9_T" >/dev/null 2>&1 || rm -rf "$R9_T"
  if r9_why="$(r9_judge "$SH_RECEIPTS" "$r9_size" "$r9_rows")"; then
    echo "R9: OK -- live-ledger joins on ${LEDGER}: ${r9_why} (probe fired both directions)."
    return 0
  fi
  echo "FAIL: R9: live-ledger join on ${LEDGER}: ${r9_why}." >&2
  echo "R9: FAIL -- see stderr."
  return 1
}

vbr_sec_corpus() {
# ---------------------------------------------------------------------------
# THE CORPUS.
# ---------------------------------------------------------------------------
# A RE-ENTERED RUN executes no corpus receipt (see RE_ENTRY): both population lines say SKIPPED,
# and the verdict is the efficiency arms' alone. The self-probes above have already run.
if [ -n "$RE_ENTRY" ]; then
  R8_SKIP=1
  score_closed "$LEDGER" "$SUBJECT_ROOT" "$BASE_REF" >/dev/null || exit 2
  open_skip_line
  closed_line 0
  eff_report || exit 1
  parent_cleanup_trees
  echo "OK: validate-backlog-receipts -- EXAMINED NOTHING for R2-R8: re-entered from inside a receipt (BR_RECEIPTS_RUNNING set on entry), so no corpus receipt was executed here; ${R7_PROBED}; the efficiency arms ran over ${LEDGER}."
  exit 0
fi
OUT="$(score_ledger "$LEDGER" "$SUBJECT_ROOT")" || exit 2
read_counts
CLOSED_OUT="$(score_closed "$LEDGER" "$SUBJECT_ROOT" "$BASE_REF")" || exit 2

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
# r2_alldriver, the function R1 probed in both directions above.
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
closed_line "$N_CFAIL"

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
  echo "FAIL: R7: $N_CM OPEN receipt(s) in $LEDGER CANNOT MEASURE their subject (named above), against a ceiling of $MAX_CM. The set is exit 9, 126, 128 and above, and the receipt's OWN shell reporting a missing command, a missing sourced file or a syntax error (scripts/backlog-receipt-lib.sh cant_measure). Such a receipt answers whatever the fix does, so the entry it guards has no instrument -- usually a subject renamed or moved inside a release. NOT in the set: bare 127 and 2-8, which are reproductions. REMEDY: repair the receipt so it reaches its question." >&2
  RC=1
fi
if [ "$N_CFAIL" -gt 0 ]; then
  printf '%s\n' "$CLOSED_OUT" | awk -F'\t' '$1 == "CLOSED-FAIL" { printf "FAIL: R8\t%s\t%s\t%s\n", $2, $3, $4 }' >&2
  echo "FAIL: R8: $N_CFAIL entr(ies) closed on this branch (stamped **LANDED (v in $LEDGER, or rotated into the archive, since the merge-base with $BASE_REF) carry a verify: sh receipt that does not exit 0 (named above with the exit and the reason). A close says the fix is present; a receipt that disagrees is either a subject renamed inside the release or a close that did not land. REMEDY: fix the receipt or the close, then re-run." >&2
  RC=1
fi

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
  echo "OK: validate-backlog-receipts -- R2 ${N_PC}/${MAX_PC} prose-closable, R3 ${UNSCORED}/${MAX_UNSC} unscored, R4 ${N_OOP}/${MAX_OOP} out of population, R6 ${N_UNSTABLE}/${MAX_UNSTABLE} unstable, R5 ${SH_RECEIPTS} sh receipts over ${ENTRIES} live entries in ${_where} (${N_BOUND} bound, ${N_FS} format-sensitive, ${N_PASS} already passing, ${N_DRIVER} driver; R0 bound the path-split class to ${CLASS_SOURCE}; R1 fired both directions over 12 seeded receipts; R7 ${N_CM}/${MAX_CM} open receipts cannot measure; R8 ${N_CFAIL} closed-on-branch receipts not exiting 0; ${R7_PROBED}; every receipt ran in its own ${PROVENANCE}, ${WT_OWN_AFTER} of this run's own checkouts still registered, caller porcelain ${PORC_BEFORE} unchanged).${R2_ALLPASS}${R2_ALLMANUAL}${R2_DECLEMPTY}${R2_ALLDRIVER}"
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
# core/fixtures/backlog-receipt-binding/run.sh (its vin helper) sources it and calls vbr_main in a subshell.
vbr_main() {
vbr_sec_env
vbr_worker "$@"
vbr_sec_args "$@"
vbr_sec_setup
vbr_probe_r0
vbr_sec_r0
vbr_probe_e0
vbr_sec_eff
vbr_probe_r1
vbr_probe_r7r8
vbr_sec_corpus
}
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
vbr_main "$@"
