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
# Usage: validate-backlog-receipts.sh [<ledger>] [--root <dir>] [--quiet]
#          [--max-prose-closable N] [--max-unscorable N] [--max-out-of-population N]
#          [--max-unstable N]
#          [--min-sh-receipts N] [--min-entries N]
# Output: one TAB-delimited row per finding, then a summary and one OK line.
#          STATUS <TAB> ENTRY <TAB> paths=... <TAB> tokens=...
# Exit:  0 = at or under every ceiling; 1 = over one, or nothing was scored;
#        2 = usage, environment, or a self-probe that did not fire.
set -uo pipefail

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
DEFAULT_MIN_SH=76
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
if [ "${1:-}" = "--score-one" ]; then
  REC="${2:-}"
  [ -n "$REC" ] || exit 2
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

  ( cd "$TA" && eval "$REST" ) >/dev/null 2>&1
  BASE_RC=$?

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
    wr OUT-OF-POPULATION "base-exit=$BASE_RC" "paths=${PL:-none}" "tokens=${TL:-none}"; exit 0
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

# ===========================================================================
# PARENT MODE
# ===========================================================================
QUIET=0; LEDGER=""; ROOT_ARG=""
MAX_PC=""; MAX_UNSC=""; MAX_OOP=""; MAX_UNSTABLE=""; MIN_SH=""; MIN_ENTRIES=""
usage() { echo "usage: validate-backlog-receipts.sh [<ledger>] [--root <dir>] [--quiet] [--max-prose-closable N] [--max-unscorable N] [--max-out-of-population N] [--min-sh-receipts N] [--min-entries N]" >&2; }
while [ "$#" -gt 0 ]; do
  case "$1" in
    --quiet) QUIET=1; shift ;;
    --root) ROOT_ARG="${2:-}"; shift 2 ;;
    --max-prose-closable) MAX_PC="${2:-}"; shift 2 ;;
    --max-unscorable) MAX_UNSC="${2:-}"; shift 2 ;;
    --max-out-of-population) MAX_OOP="${2:-}"; shift 2 ;;
    --max-unstable) MAX_UNSTABLE="${2:-}"; shift 2 ;;
    --min-sh-receipts) MIN_SH="${2:-}"; shift 2 ;;
    --min-entries) MIN_ENTRIES="${2:-}"; shift 2 ;;
    -*) usage; exit 2 ;;
    *)  LEDGER="$1"; shift ;;
  esac
done

# Resolve THIS script's own root by walking UP for a marker, never by counting `..` hops -- a
# validator that counts hops answers differently from the repo root, from a subdirectory, and
# from a fixture sandbox that copied it, and the sandbox answer is the silent one.
SELF_ROOT="$(cd "$(dirname "$0")" && pwd)"
while [ "$SELF_ROOT" != "/" ] && [ ! -f "$SELF_ROOT/VERSION" ]; do SELF_ROOT="$(dirname "$SELF_ROOT")"; done
[ -f "$SELF_ROOT/VERSION" ] || { echo "$(me): FAIL -- no VERSION marker above $0" >&2; exit 2; }
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"

LIB="$SELF_ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
[ -f "$LIB" ] || { echo "$(me): FAIL -- reconcile/lib.sh missing; refusing to fall back to a private copy of the entry-boundary rule" >&2; exit 2; }
# shellcheck source=../core/skills/ai-dlc-update/reconcile/lib.sh
. "$LIB" || { echo "$(me): FAIL -- cannot source $LIB" >&2; exit 2; }

DEFAULTED=0
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

# ---------------------------------------------------------------------------
# score_ledger <ledger> <subject-root> -> result rows on stdout; the `sh` receipt count and
# the live entry count go to $WORK/counts, which `read_counts` lifts back into the caller.
# The corpus and the self-probe both go through this function, so the probe exercises the
# instrument rather than a second implementation of it.
# ---------------------------------------------------------------------------
score_ledger() {
  _sl_ledger="$1"; _sl_root="$2"
  rm -rf "$WORK/out" "$WORK/rec" "$WORK/t"
  mkdir -p "$WORK/out" "$WORK/rec" "$WORK/t"
  _sl_i=0; _sl_e=0
  while IFS="$(printf '\t')" read -r _l _c _r; do
    [ -n "$_l" ] || continue
    [ "$_c" = "1" ] && continue                 # annotated LANDED: awaiting rotation, not live
    _sl_e=$(( _sl_e + 1 ))
    [ "$_r" = "@NONE@" ] && continue
    case "$_r" in "sh "*|"sh") ;; *) continue ;; esac
    _sl_i=$(( _sl_i + 1 ))
    printf '%s\n%s\n' "$_l" "$_r" > "$WORK/rec/$(printf '%04d' "$_sl_i")"
  done <<EOF
$(awk -f "$AWKF" "$_sl_ledger")
EOF
  # THE COUNTS GO TO A FILE, NOT TO A VARIABLE. Every caller runs this in `$( )` to capture
  # its rows, and an assignment made inside a command substitution is lost to the subshell --
  # the caller would read an unbound variable, or worse, the PREVIOUS call's value.
  printf '%s %s\n' "$_sl_i" "$_sl_e" > "$WORK/counts"
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
  export BR_WORK BR_SUBJECT_ROOT BR_PATH_CLASS BR_TOKAWK BR_GENERIC_SEED BR_SENTINEL
  find "$WORK/rec" -type f | sort | xargs -P "$JOBS" -n 1 bash "$SELF" --score-one

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

# The counts score_ledger wrote, read back in the PARENT shell. A missing file is a refusal:
# a defaulted zero here would read as an empty ledger, which is a different finding.
read_counts() {
  SH_RECEIPTS=""; ENTRIES=""
  [ -f "$WORK/counts" ] || { echo "$(me): FAIL -- the scorer wrote no population counts, so the ledger's size is unknown and no ratchet below could be read." >&2; exit 2; }
  read -r SH_RECEIPTS ENTRIES < "$WORK/counts"
  case "${SH_RECEIPTS:-}${ENTRIES:-}" in ''|*[!0-9]*) echo "$(me): FAIL -- the scorer's population counts did not parse." >&2; exit 2 ;; esac
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
# ---------------------------------------------------------------------------
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
{
  printf '# Probe ledger\n\n'
  printf '## BL-901\n\nverify: sh grep -q %s probe/subject.txt\n\n' "'PROBEMARKER'"
  printf '## BL-902\n\nverify: sh out="$(bash probe/tool.sh)"; grep -q %s <<<"$out"\n\n' "'READY'"
  printf '## BL-903\n\nverify: sh grep -q %s probe/subject.txt || exit 9\n\n' "'NINEMARK'"
  printf '## BL-904\n\nverify: sh test -f probe/absent-file.txt\n\n'
  printf '## BL-905\n\nverify: sh ! grep -q %s probe/flip.txt\n\n' "'ZEROFLIP'"
  printf '## BL-906\n\nverify: sh grep -q %s probe/locked.txt\n\n' "'LOCKMARK'"
  printf '## BL-907\n\nverify: sh grep -q %s probe/doc.json || awk %s probe/doc.json\n\n' \
    "'JSONMARK'" "'END { exit (NR == 3 ? 1 : 0) }'"
  printf '## BL-908\n\nverify: sh git rev-parse HEAD >/dev/null 2>&1 || exit 9; grep -q %s probe/subject.txt\n\n' "'GITMARK'"
  printf '## BL-909\n\nverify: sh grep -q %s probe/one.txt && grep -q %s probe/two.txt\n\n' "'MARKONE'" "'MARKTWO'"
  printf '## BL-910\n\nverify: sh C="$BR_PROBE_COUNTER"; n=$(cat "$C" 2>/dev/null || echo 0); printf %%s $((n+1)) > "$C"; [ "$n" = "0" ] && exit 9; exit 1\n\n'
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
  echo 'exit 0'
} > "$P/.probehooks/post-checkout"
chmod +x "$P/.probehooks/post-checkout"
git -C "$P" config core.hooksPath "$P/.probehooks" >/dev/null 2>&1 || {
  echo "$(me): SELF-PROBE FAILED -- the probe repository would not take a hooks path, so its unwritable-subject probe has no subject." >&2; exit 2; }

probe_status() { printf '%s\n' "$1" | awk -F'\t' -v id="$2" '$2 == id { print $1 }'; }
probe_detail() { printf '%s\n' "$1" | awk -F'\t' -v id="$2" '$2 == id { print $3 }'; }
probe_count()  { printf '%s\n' "$1" | awk -F'\t' '$1 == "PROSE-CLOSABLE"' | grep -c . ; }

BR_GENERIC_SEED=0
R1_OUT="$(score_ledger "$P/docs/backlog.md" "$P")" || exit 2
R1_N="$(probe_count "$R1_OUT")" || R1_N=0
read_counts
R1_SH="$SH_RECEIPTS"

r1_fail() { echo "$(me): SELF-PROBE FAILED -- $1" >&2; printf '%s\n' "$R1_OUT" | sed 's/^/    /' >&2; exit 2; }

[ "$R1_SH" -eq 10 ] || r1_fail "the probe ledger parsed to $R1_SH sh receipts, not 10, so the entry grammar did not read the probe and nothing below is about the scorer."
[ "$(probe_status "$R1_OUT" BL-901)" = "PROSE-CLOSABLE" ] || r1_fail "the seeded prose-closable receipt did NOT flip under a seed carrying its own grep literal (got: $(probe_status "$R1_OUT" BL-901)). The scorer cannot produce a finding, so a clean corpus below would mean only that it ran."
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

# ---------------------------------------------------------------------------
# THE CORPUS.
# ---------------------------------------------------------------------------
OUT="$(score_ledger "$LEDGER" "$SUBJECT_ROOT")" || exit 2
read_counts

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
SCORED=$(( N_PC + N_BOUND + N_FS ))
UNSCORED=$(( N_UNSC + N_UNSEED ))

PORC_AFTER="$(porcelain_count)" || PORC_AFTER=0
if [ "$PORC_AFTER" != "$PORC_BEFORE" ]; then
  echo "$(me): FAIL -- the caller's working tree changed during this run ($PORC_BEFORE -> $PORC_AFTER dirty paths). A seed escaped its checkout. Every verdict from this run is discarded." >&2
  exit 2
fi

if [ "$N_BROKEN" -ne 0 ]; then
  printf '%s\n' "$OUT" | awk -F'\t' '$1 == "BROKEN" { printf "FAIL: BROKEN\t%s\t%s\n", $2, $3 }' >&2
  echo "$(me): FAIL -- $N_BROKEN receipt(s) could not be scored because the harness failed, not because the receipt did. This is a refusal, not a reading." >&2
  exit 2
fi

# THE ZERO IS A FINDING. An empty parse, a ledger whose every receipt this grammar cannot
# spell, and a corpus of perfectly bound receipts all print the same 0 prose-closable.
if [ "$SCORED" -eq 0 ]; then
  echo "FAIL: R2: $LEDGER produced ZERO scored receipts (entries $ENTRIES, sh receipts ${SH_RECEIPTS:-0}, unscorable $N_UNSC, unseeded $N_UNSEED, out of population $N_OOP, already passing $N_PASS). Nothing was observed, and an arm that observed nothing is not a clean corpus." >&2
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
    $1 == "PROSE-CLOSABLE" || $1 == "FORMAT-SENSITIVE" || $1 == "UNSCORABLE" || $1 == "UNSEEDED" || $1 == "OUT-OF-POPULATION" || $1 == "ALREADY-PASSING" { printf "%s\t%s\t%s\t%s\n", $1, $2, $4, $5 }
  ' | sort
  echo "SUMMARY entries=$ENTRIES sh-receipts=$SH_RECEIPTS scored=$SCORED prose-closable=$N_PC/$MAX_PC format-sensitive=$N_FS bound=$N_BOUND unscorable=$N_UNSC+unseeded=$N_UNSEED/$MAX_UNSC out-of-population=$N_OOP/$MAX_OOP unstable=$N_UNSTABLE/$MAX_UNSTABLE already-passing=$N_PASS"
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

# THE POPULATION FLOOR. The three ceilings all bound a count WITHIN the `sh` population, so
# the last escape is to leave it: rewrite `verify: sh` as `verify: manual`, or delete the
# receipt line. Both are invisible to every clause above, and both read as an improvement.
if [ "$SH_RECEIPTS" -lt "$MIN_SH" ]; then
  _sh_drop=$(( MIN_SH - SH_RECEIPTS ))
  _en_drop=$(( MIN_ENTRIES - ENTRIES ))
  [ "$_en_drop" -lt 0 ] && _en_drop=0
  if [ "$_sh_drop" -gt "$_en_drop" ]; then
    echo "FAIL: R5: the sh receipt population fell by $_sh_drop (from $MIN_SH to $SH_RECEIPTS) while the live entry count fell by only $_en_drop (from $MIN_ENTRIES to $ENTRIES). Rotation removes an entry and its receipt together and moves both sides; a 'verify: sh' rewritten as 'verify: manual', or a deleted receipt line, moves only this one -- and either lowers every count above while fixing nothing. If entries really were rotated, lower --min-sh-receipts and --min-entries together in .githooks/pre-push." >&2
    RC=1
  fi
fi
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
  echo "OK: validate-backlog-receipts -- R2 ${N_PC}/${MAX_PC} prose-closable, R3 ${UNSCORED}/${MAX_UNSC} unscored, R4 ${N_OOP}/${MAX_OOP} out of population, R6 ${N_UNSTABLE}/${MAX_UNSTABLE} unstable, R5 ${SH_RECEIPTS} sh receipts over ${ENTRIES} live entries in ${_where} (${N_BOUND} bound, ${N_FS} format-sensitive, ${N_PASS} already passing; R0 bound the path-split class to ${CLASS_SOURCE}; R1 fired both directions over 10 seeded receipts; every receipt ran in its own ${PROVENANCE}, ${WT_OWN_AFTER} of this run's own checkouts still registered, caller porcelain ${PORC_BEFORE} unchanged)."
else
  # `--quiet` SUPPRESSES THE FINDING ROWS, NEVER THE PROVENANCE. A caller that asks for quiet
  # still has to be able to tell this arm's silence from a stub's: a fifteen-line heuristic
  # that greps receipts for the word `grep` produces the same exit code and the same empty
  # output, and there would be nothing to distinguish them. This line reports what the run
  # actually DID -- how many receipts were checked out and scored -- which no implementation
  # that seeds nothing can emit truthfully.
  echo "OK: validate-backlog-receipts -- ${SCORED} receipt(s) scored in ${_where}, each in its own ${PROVENANCE}; ${N_PC}/${MAX_PC} prose-closable."
fi
exit 0
