#!/usr/bin/env bash
# ledger-reverify.sh — re-verify OPEN push-candidate ledger entries against `theirs`,
# and flag the ones upstream has since absorbed as CLOSE-CANDIDATE for the operator.
#
# WHY THIS EXISTS. The push-candidate ledger (`_bmad-output/ai-dlc-update/push-candidate-ledger.md`)
# is the queue of consumer innovations upstream lacks and consumer-filed upstream defects.
# The pull APPENDS to it (SKILL.md step 8, "drain push_candidate extensions"), but nothing
# CLOSED it: when upstream adopts an entry, it stays open forever, re-surfaces every push
# arc, and may be re-pushed. Closing was hand-work — the reference consumer's three
# `ADOPTED UPSTREAM` closures landed in a separate commit 19 minutes after the pull, by a
# human remembering to check each entry against `origin/main`. An un-closed entry is
# invisible to every check; there was no CLOSE path at all (no `reconcile/*` even named the
# ledger).
#
# This is the ledger twin of `unregistered-drift.sh`'s `HARD-CORE-DRIFT-ABSORBED` and
# `layer-drift.sh`'s `EXTENSION-RETIRE-CANDIDATE`: both re-run a mechanical check against
# `theirs` and let the OPERATOR confirm. This one never blocks `apply` (a close touches no
# core and cannot lose data) and never edits the ledger — it reports, the operator annotates.
#
# THE CONVENTION (opt-in, one line per entry; the ledger stays prose). An entry may carry:
#
#   verify: theirs_lacks <core-rel-path> "<substr>"
#       The entry is an innovation upstream LACKS. Still live iff `theirs:<path>` still
#       lacks <substr>. If it now CONTAINS it → upstream absorbed it → CLOSE-CANDIDATE.
#   verify: theirs_has  <core-rel-path> "<substr>"
#       The entry is a defect present UPSTREAM. Still live iff `theirs:<path>` still has
#       <substr>. If it no longer does → upstream fixed it → CLOSE-CANDIDATE.
#   verify: sh <one-liner>
#       Escape hatch. Runs with $DIST/$BASE/$THEIRS/$CONSUMER exported. Exit 0 = the entry
#       STILL reproduces at theirs (stays open); nonzero = it no longer does → CLOSE-CANDIDATE.
#   verify: manual
#       No mechanical predicate exists for this entry — hand-review is the intent, not a
#       defect → HAND-REVIEW. This verb used to fall through to `unknown verify verb`, which
#       filed a deliberate declaration under the same banner as a typo.
#
# MARKDOWN FORMATTING IS TOLERATED, NOT REQUIRED. The ledger is prose an operator writes, so a
# receipt arrives code-formatted as often as not — `verify: theirs_lacks …` wrapped whole, or
# just the verb wrapped. Backticks and a trailing period are stripped from BOTH ends of the
# verb and from the end of the directive. A formatting slip must not change a verdict, and
# rejecting the habit outright would only move the failure from silent to loud without helping
# anyone. Do not write receipts to satisfy the parser; write them and let it cope.
#
# An entry with NO `verify:` line is left to hand-review, exactly as today — it is not
# emitted. An entry already annotated `ADOPTED UPSTREAM` is closed and skipped.
#
# PATH FALLBACK. `<core-rel-path>` is distribution-relative (`core/skills/…`,
# `core/scripts/…`, `core/fixtures/…`). Consumers routinely file it in their own INSTALL
# layout instead (`core/.claude/skills/…`, `core/scripts/ai-dlc/…`, `core/tests/fixtures/…`),
# which resolves at neither ref, so the substring is never compared and the entry reports
# NEEDS-REVIEW — indistinguishable from an entry whose claim is genuinely ambiguous. A
# never-run predicate reads exactly like a hand-review-by-design one.
#
# VACUOUS PREDICATES. A close is only trustworthy if the predicate's STILL-LIVE side was ever
# reachable. `theirs_has "<substr>"` closes when the substring is gone at theirs — but if the
# substring was never at BASE either, the predicate could never have reported STILL-LIVE. It
# was born closed, and no upstream change produced the verdict. Same in reverse for
# `theirs_lacks` on a substring present at both refs.
#
# The usual cause is an inverted verb: the author picks a substring naming the FIX they want
# ("fail-closed by default", "Check 3 and Check 4 real enforcers") and pairs it with
# `theirs_has`, which means the opposite. Measured on the reference consumer: SIX entries did
# exactly this, every one a live defect the run reported as absorbed. A confident wrong close
# is worse than a NEEDS-REVIEW, because a drain acts on it. Both refs are checked before any
# close is emitted; a predicate that could not have fired is reported, not obeyed.
#
# UNFALSIFIABLE PREDICATES — the third case, and the one two refs cannot decide. Both guards
# above fire on the CLOSE side: they run where a close would be emitted. An entry that never
# closes never reaches them. `theirs_lacks` on a substring absent from base AND theirs is
# exactly that entry — it reports STILL-LIVE on every pull, forever, including after upstream
# adopts the innovation, because the substring was never text upstream would write.
#
# It cannot be decided from base and theirs alone: absent-at-both is also the NORMAL state of
# a genuinely live entry. What separates them is whether the substring is a literal an
# ADOPTION would carry. SKILL.md step 3f already requires this — "anchor on a status name, a
# flag, a filename, a manifest row — something the fix cannot be written without" — and had
# no mechanism behind it. Measured on the reference consumer at v0.146.0: THIRTEEN entries
# violated the rule, two of them quoting the very strings this header names above as the
# canonical authoring error.
#
# So the CONSUMER's tree is read as a third ref. A token the fix cannot be written without
# exists in the consumer's own implementation of it; prose invented to describe the fix
# exists nowhere. Unreachable in all three → NEEDS-REVIEW, never STILL-LIVE.
#
# A proposal-only entry (upstream should add X; nobody has built it) legitimately has the
# substring nowhere — and for that entry `theirs_lacks` on invented wording IS the
# unfalsifiable case. It wants `manual`, or an anchor on a flag/filename the fix cannot
# avoid. Firing there is the check working, not a false positive.
#
# So: when a path does not resolve, retry ONCE by basename across the tree at `theirs`.
# Exactly one match → verify against it and say so in DETAIL. Zero or more than one → the
# old NEEDS-REVIEW. The set is DERIVED from the tree, never a hand-maintained consumer→dist
# prefix table: such a table is one more list to keep in sync, and the stale list becomes the
# bug. Ambiguity degrades to today's behaviour rather than guessing.
#
# BOTH ENTRY SHAPES CARRY A `verify:` LINE. A ledger entry is either a top-level
# `- **Title**` bullet or a `## SECTION-ID — title` heading; ledgers grow into the heading
# shape as entries acquire receipts too long to read as a bullet. The parser originally
# treated EVERY heading as a pure terminator — it flushed and cleared the label — so a
# `verify:` line inside a heading-shaped entry set the directive against an empty label and
# `flush()` dropped it. The detector emitted nothing and exited 0, which is byte-identical
# to "no entry has anything to close."
#
# Measured on the reference consumer: every entry filed after 2026-07-20 uses the heading
# shape, including the ONE entry that had adopted this convention at all. Upstream had
# already fixed that entry's defect; the closer stayed silent about it. A heading now OPENS
# an entry (after flushing the previous one, so the terminator semantics are unchanged).
#
# Usage:  ledger-reverify.sh <dist-repo> <base-sha> <consumer-root> <theirs-ref> [ledger-path]
#         (arg order matches unregistered-drift.sh)
# Output: TSV — STATUS<TAB>ENTRY<TAB>DETAIL
#   CLOSE-CANDIDATE  upstream absorbed the entry; the operator confirms and annotates.
#   NAMED-UPSTREAM   upstream's own history NAMES this entry's id. Emitted IN ADDITION to the
#                    receipt's verdict, never instead of it — see THE NAME IS THE THIRD SIGNAL.
#   STILL-LIVE       the entry still reproduces at theirs; stays open (filtered from the report).
#   HAND-REVIEW      the entry declares `verify: manual` — no mechanical predicate by design.
#   NEEDS-REVIEW     the receipt itself is at fault. THREE causes, and the DETAIL names which:
#                    `unresolved:` (malformed line, unresolvable path, empty sh, unknown verb),
#                    `vacuous predicate:`, `unfalsifiable predicate:`. Hand-review, as an entry
#                    without a verify line would be.
#
#   INPUT-UNRESOLVED an ARGUMENT does not resolve — the consumer root is not a directory, or an
#                    explicitly-supplied arg-5 ledger path is not a readable file. Run-scoped,
#                    not entry-scoped: the ENTRY column carries the offending path. Nothing was
#                    re-verified, and this row exists because that state used to be spelled as
#                    zero rows and rc=0, which is how a clean corpus is spelled.
#
#                    Two of the three were literal prefixes the code emitted; `unresolved` was
#                    named in SKILL.md and nowhere in this file, spread across four sites that
#                    emitted four different unlabelled strings. So the mode could not be grepped
#                    or counted, and — once emit-report.sh started carrying DETAIL into the
#                    report — it would have reached the operator as the one cause with no name.
#                    Adding a mode means adding its prefix here; the count above is part of the
#                    contract SKILL.md states.
# Exit:   0 ALWAYS. A classifier, not a gate — the caller decides, and a close never blocks.
set -uo pipefail

# ledger_entry_shape() — THE entry-boundary rule, from lib.sh. See that file for why it is not
# copied here: rotate's copy of this block drifted within one release.
SELF="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
. "$SELF/lib.sh" || { echo "ledger-reverify: cannot source $SELF/lib.sh" >&2; exit 1; }

DIST="${1:?usage: ledger-reverify.sh <dist-repo> <base-sha> <consumer-root> <theirs-ref> [ledger-path]}"
BASE="${2:?}"
CONSUMER="${3:?}"
THEIRS="${4:?}"

# NORMALIZED TO A PHYSICAL ABSOLUTE PATH, BECAUSE THE FORM OF THIS ARGUMENT IS PART OF EVERY
# `sh` RECEIPT'S PREDICATE — and the failure it produced is a FALSE CLOSE, the one verdict this
# file's header names as the direction that loses information permanently.
#
# `$CONSUMER` is the only one of the four exported values a receipt can read AS A PATH: `$DIST`
# is handed to `git -C` and is form-insensitive, and the two refs are shas. Callers routinely
# pass `.`, which is a valid consumer root. A receipt whose CLAIM is about absolute-path handling
# then has its own subject handed to it in the wrong form — the two-arm predicate for
# `PC-S312-STRAYS-DOES-NOT-NORMALIZE-AN-ABSOLUTE-PATH` requires the relative path to pass and the
# absolute one to fail, and with `CONSUMER=.` the second arm receives `./docs/…`, which is still
# relative, so it passes too, the `&&` chain inverts and the entry reads CLOSE-CANDIDATE.
#
# MEASURED on the reference consumer at 0.300.0, `.` versus the absolute root, same refs, same
# ledger: 74 rows either way — the control that this is a targeted inversion and not a broken
# invocation — and exactly ONE row differs, that entry, CLOSE-CANDIDATE against STILL-LIVE.
#
# ABSOLUTE, NOT PHYSICAL — `pwd`, deliberately not `pwd -P`. The defect is relativeness; symlink
# resolution is a second change with its own blast radius, and it is not free: `$CONSUMER` is
# rendered verbatim into the reachability DETAIL an operator reads, and on macOS `-P` rewrites
# every root under `/var` as `/private/var`. Measured — with `-P` the fixture's own
# absolute-root run moved ten rows that have nothing to do with this fix, which is how a
# one-line correction acquires a regression surface. `ledger_top_dir()` below needs nothing from
# here either: it resolves BOTH sides with `pwd -P` itself, so its containment test is already
# self-consistent whatever spelling arrives.
#
# A `cd` that fails leaves `$CONSUMER` VERBATIM rather than empty: an empty consumer root would
# silently re-point every path at the process cwd, and the arm below reports the bad root by
# name instead.
_abs_consumer="$(cd "$CONSUMER" 2>/dev/null && pwd)"
[ -n "$_abs_consumer" ] && CONSUMER="$_abs_consumer"

# ONE HOME for the conventional in-tree ledger path: it is both the default subject and the
# fallback the reachability exclusion derives from when arg 5 points somewhere else.
LEDGER_DEFAULT="$CONSUMER/_bmad-output/ai-dlc-update/push-candidate-ledger.md"
LEDGER="${5:-$LEDGER_DEFAULT}"

# RSFX names WHICH receipt produced this row, and is empty for the single-receipt case so output
# is byte-identical to before for every entry carrying one. Appended here rather than at each call
# site: there are eight emit() calls across four verbs, and a suffix added to seven of them is a row
# an operator cannot attribute.
#
# DEFINED ABOVE THE BAIL BELOW, DELIBERATELY. The bail is the one place this tool reports without
# having parsed an entry, and a diagnostic printed through a second, hand-rolled printf is a
# second output grammar for the same reader.
RSFX=""
emit() { printf '%s\t%s\t%s\n' "$1" "$2" "$3$RSFX"; }

# A CALLER ERROR MUST NOT READ AS A CLEAN CORPUS.
#
# This was one unconditional line — `[ -f "$LEDGER" ] || exit 0` — and its INTENT is right: a
# consumer that never filed a candidate has no ledger and nothing to re-verify. But the exit was
# doing double duty. "Nothing to re-verify" and "I could not find what you named" produced the
# same silence and the same rc=0, and only the second is a caller error. SKILL.md step 3f calls
# this tool once and reads its rows; zero rows there reads as *every entry re-verified, nothing
# to close*.
#
# MEASURED at 0.300.0 against the reference consumer, three invocations, same tree, same moment:
#
#   bogus arg 5                    0 rows   rc=0   0 bytes of stderr
#   args swapped (consumer/theirs) 0 rows   rc=0   0 bytes of stderr
#   correct                       74 rows   rc=0
#
# TWO ARMS, BECAUSE ONE DOES NOT COVER THE MISTAKE THAT WAS ACTUALLY MADE. The obvious fix —
# warn when an EXPLICITLY-supplied arg 5 is unreadable — is silent on the swapped-args case,
# which is the case the filing calls the natural mistake: this tool takes consumer THIRD and
# theirs FOURTH while every sibling in `reconcile/` takes `<dist> <base> <theirs> <consumer>`,
# and `layer-drift.sh`'s own usage line is the opposite order. Swapping them puts a SHA in the
# consumer slot, `$LEDGER` is then the DEFAULT path under a root that does not exist, and an
# arg-5-only check never fires. So the consumer ROOT is checked on its own, unconditionally:
# a root that is not a directory is a caller error whichever ledger path was used, and it is
# also the case where every `sh` receipt silently resolves against the wrong tree.
#
# FALSE-POSITIVE SET, EMPTY BY CONSTRUCTION: every legitimate consumer root is a directory,
# including `.`, and `-d` follows symlinks.
#
# WHAT NEITHER ARM CAN SEE, stated rather than left to read as covered: a consumer root that IS
# a directory but is the wrong one — the distribution passed twice, say — has no ledger at its
# default path, and that is genuinely indistinguishable from a consumer that never filed a
# candidate. Deciding it would need a probe for the machinery home, which is a different claim
# from "the path you named does not exist".
#
# STILL EXIT 0. This is a classifier, not a gate, and its callers depend on that. The row IS the
# signal, and it goes to STDOUT — the same channel the zero was misread from. A warning on
# stderr would be correct and unread: `emit-report.sh` discards this tool's stderr, and its row
# filter is a denylist (`$1!="STILL-LIVE"`), so a status added here reaches the operator's report
# with no change there.
if [ ! -d "$CONSUMER" ]; then
  emit INPUT-UNRESOLVED "$CONSUMER" "unresolved: the consumer root is not a directory, so no ledger can be found under it and every 'verify: sh' receipt would resolve its paths against the wrong tree. This tool takes <dist> <base> CONSUMER <theirs> — consumer THIRD, theirs FOURTH — which is the opposite of every sibling in reconcile/. Check the argument order, then re-run. Nothing was re-verified; a zero row count here is not a clean corpus."
fi
if [ ! -f "$LEDGER" ]; then
  if [ "$LEDGER" != "$LEDGER_DEFAULT" ]; then
    emit INPUT-UNRESOLVED "$LEDGER" "unresolved: the ledger path given as argument 5 is not a readable file. Nothing was re-verified. Correct the path, or omit argument 5 to use the conventional in-tree ledger, then re-run."
  fi
  # The genuine no-ledger case: the DEFAULT path, absent, under a real consumer root. Silent,
  # exactly as before — a consumer that never filed a candidate has nothing to re-verify.
  exit 0
fi

theirs_show() { git -C "$DIST" show "${THEIRS}:$1" 2>/dev/null; }
theirs_has_path() { git -C "$DIST" cat-file -e "${THEIRS}:$1" 2>/dev/null; }
base_show() { git -C "$DIST" show "${BASE}:$1" 2>/dev/null; }

# absorbed_at <path> <substring> -> the VERSION where <substring> FIRST appeared in <path>
#
# The close rows used to say "upstream absorbed this at $TV", where $TV is VERSION at THEIRS —
# the tip being pulled, which has no relationship to when the substring arrived. Any absorption
# predating theirs was annotated with the wrong release, and that annotation is permanent: the
# ledger entry is the provenance of an upstreamed change, and retro and the §8.1 fan-in read it.
#
# Measured on the reference consumer: PC-S298's substring first appears at v0.144.0. The tool
# reported 0.147.0. A hand correction filed against it said 0.146.0, derived by sampling the
# three refs already loaded rather than walking the history — also wrong. Three releases apart,
# in a record nothing re-derives.
#
# Bounded to base..theirs deliberately. Searching all history would attribute a substring that
# was removed and later re-introduced to its ORIGINAL commit, which is a different claim than
# "the pull you are looking at absorbed it". Falls back to $TV when the search finds nothing —
# a relocated path, a rewritten line — because a close row with no version is worse than one
# with the tip's.
absorbed_at() {
  local _c _v
  _c="$(git -C "$DIST" log -S"$2" --reverse --format=%H "${BASE}..${THEIRS}" -- "$1" 2>/dev/null | head -1)"
  [ -n "$_c" ] || { printf '%s' "$TV"; return; }
  _v="$(git -C "$DIST" show "${_c}:VERSION" 2>/dev/null | tr -d '[:space:]')"
  [ -n "$_v" ] && printf '%s' "$_v" || printf '%s' "$TV"
}

# THE NAME IS THE THIRD SIGNAL, AND IT IS THE ONLY ONE THE WORDING CANNOT DEFEAT.
#
# Every predicate above tests the RECEIPT. That is exactly the wrong instrument when the
# receipt is the thing at fault, because a receipt can be structurally incapable of ever
# closing, and then the entry reports a confident verdict forever. Two shapes do it:
#   - anchored on a token present BEFORE and AFTER the fix, so `theirs_has` never flips;
#   - an INVERTED VERB — `theirs_has` naming the FIX text, so absorption reads as still-live.
# And `verify: manual` has no mechanical predicate by design, so it reports HAND-REVIEW on
# every pull until a human happens to look.
#
# But an upstream commit that lands a consumer's entry NAMES the entry's id in its message.
# That token is not paraphrasable: it is the join key the ledger, the report and the §8.1
# fan-in already use. So ask the history directly.
#
# MEASURED on the reference consumer, 51 heading labels / 37 id-shaped / 4 named:
#   PC-S296-…-LAST-MATCH-WINS      NAMED at v0.153.0 and only PARTLY absorbed — that commit
#                                  anchored the match to a line start, closing the prose-mention
#                                  arm, while the entry's own subject (the scalar `directive=`)
#                                  stayed live until the accumulation fix below. Its receipt
#                                  anchors `directive=substr(`, present at both refs.
#   PC-S297-…-PM-AC-PRECISION      NAMED, NOT absorbed — the commit names it in passing; the
#                                  requirement is still absent from pm.md at theirs
#   PC-S300-…-SECOND-SKILL         absorbed by the v0.172.0 drain; `verify: manual`
#   PC-S303-…-FIVE-OF-TEN-SUBTREES NAMED to REFUTE it — the five-root scan set is a reviewed I12
#                                  exemption, not an oversight; `verify: manual`
# All four are TRUE POSITIVES **as namings**, which is all this status claims; the other 33
# id-shaped labels emit nothing, the control that this discriminates rather than rubber-stamps. Four
# of four were invisible to every other predicate here.
#
# ADJUDICATED AFTERWARDS, AND THE SPREAD IS THE WARNING: of the four, ONE was an absorption
# (PC-S300), one a split, one a passing mention, one an explicit refutation. The author of this
# status recorded all four as absorbed in the same release that shipped it — misled by the verb
# the status was originally named for, three lines below the sentence insisting it says NAMES.
# That is why the status is named for what it observes, not for a verdict it cannot reach: the
# original name asserted an outcome only the operator can determine, and it fooled its own author
# before it reached a single operator. Read a row here as "upstream's history mentions this id",
# nothing more, and go read the commit.
#
# EMITTED IN ADDITION TO THE RECEIPT'S VERDICT, NEVER INSTEAD OF IT. Replacing the row would
# hide the fact that the receipt needs re-anchoring, and `STILL-LIVE` + `NAMED-UPSTREAM` on one
# entry is the highest-value pair this tool can print: it says the entry is absorbed AND its
# receipt is wrong. Suppressing either half loses one of those two facts.
#
# IT SAYS "NAMES", NOT "ABSORBED", AND NEVER AUTO-CLOSES. A commit can name an id to record
# that it was REJECTED, split, or superseded. The operator adjudicates; SKILL.md already
# restricts closing to `CLOSE-CANDIDATE` rows, so this status is non-closable by construction.
#
# UNBOUNDED TO THEIRS — deliberately NOT `BASE..THEIRS` like absorbed_at() above. The two
# searches answer different questions. A SUBSTRING can be removed and re-introduced, so
# attributing it across all history would claim the wrong release; that is why absorbed_at is
# bounded. An ID is written once, in the commit that lands the entry, and never re-added. Worse,
# the measured absorptions above predate the pull's own base: bounding this to base..theirs
# would fire the signal on exactly one pull and then go silent forever if the operator missed
# that pull — turning the one un-defeatable signal into the easiest one to lose. The entry still
# being OPEN is the delta; the name is the state.
#
# ID-SHAPE GUARD, NOT A BARE `--grep`. A label is whatever precedes the first " — ", and for a
# malformed bullet that is its whole prose first line (see the extractor below, which keeps such
# a label deliberately). Feeding prose to `--grep` matches unrelated commits by common words.
# Measured: 37 of 51 labels are id-shaped; the 14 excluded are section headings
# (`Open`, `Re-verification pass`, `push_candidate: true extensions (by source)`) and one
# retained-copy heading — none of them an entry a commit could land.
#
# `tail -1`, NOT `--reverse | head -1`. git log is newest-first, so the last line is the FIRST
# commit to name the id. The `head` form makes git the writer into a pipe a reader abandons
# early — the SIGPIPE-under-pipefail defect this file's all_present() carried, and there is no
# reason to re-import it for the sake of a flag.
named_absorbed() { # <label> -> "<version> <short-sha>" if upstream's history names it, else ""
  local _id="$1" _c _v
  case "$_id" in
    *[!A-Z0-9-]*|'') return 0 ;;              # not id-shaped: prose label, nothing to ask
  esac
  case "$_id" in
    *-*) : ;;
    *)   return 0 ;;                          # a single word is not an id
  esac
  _c="$(git -C "$DIST" log -F --grep="$_id" --format=%H "$THEIRS" 2>/dev/null | tail -1)"
  [ -n "$_c" ] || return 0
  _v="$(git -C "$DIST" show "${_c}:VERSION" 2>/dev/null | tr -d '[:space:]')"
  printf '%s %s' "${_v:-unknown}" "$(git -C "$DIST" rev-parse --short "$_c" 2>/dev/null)"
}

# $1 = file content, $2 = newline-separated substrings. True iff EVERY one is present.
# The convention's single-substring form is just the one-element case.
#
# NEVER PIPE INTO `grep -q` HERE. This file runs under `set -o pipefail`, and `grep -q` exits
# the instant it matches. On content larger than the pipe buffer (~64 KB) the writer has not
# finished, takes SIGPIPE, and the PIPELINE's status becomes that failure -- so a successful
# MATCH is reported as "not found". Smaller files complete the write before grep exits and
# behave correctly, which is what makes the bug look like flakiness rather than a size
# threshold.
#
# The verdict was therefore NONDETERMINISTIC on this repo's largest rule files. Measured on
# the reference consumer: four consecutive runs of one unchanged entry against
# `steps/gate-validation.md` returned STILL-LIVE, NEEDS-REVIEW, STILL-LIVE, CLOSE-CANDIDATE.
# Because this feeds the report's rendered region, `emit-report.sh --verify` failed 8/8 and
# six renders produced four distinct outputs. Everything outside this helper was stable.
#
# A herestring is not a pipe: grep reads a file, there is no writer to signal, and an early
# exit cannot become a false negative. Keeping `grep -F` (rather than a `case` glob) preserves
# the per-LINE fixed-string semantics the convention's substrings are written against.
all_present() {
  _c="$1"; _ok=1
  while IFS= read -r _one; do
    [ -n "$_one" ] || continue
    grep -qF -- "$_one" <<<"$_c" || _ok=0
  done <<EOF
$2
EOF
  [ "$_ok" -eq 1 ]
}

# Did the substrings already hold at BASE? A close is only meaningful if the predicate's
# still-live side was ever reachable — see VACUOUS PREDICATES in the header.
base_holds() { all_present "$(base_show "$1")" "$2"; }

# Every path at THEIRS whose basename equals $1. Compared as a fixed string after splitting
# on "/", so a basename carrying '.' or '-' needs no regex escaping to get wrong.
theirs_basename_matches() {
  git -C "$DIST" ls-tree -r --name-only "$THEIRS" 2>/dev/null |
    awk -v b="$1" '{ n=split($0, p, "/"); if (p[n] == b) print }'
}

# --- consumer reachability: the third ref (see UNFALSIFIABLE PREDICATES in the header) -----
#
# SCAN SET IS DERIVED, NEVER LISTED — the same rule the basename fallback above follows.
# `git ls-files` at the consumer gives tracked files only, which drops `.claude/worktrees/`
# (untracked agent checkouts carrying their own copy of this ledger) for free, with no
# --exclude-dir to keep in sync.
#
# TWO EXCLUSIONS, BOTH DERIVED. They are not polish; without them the check reports every
# predicate reachable and catches nothing:
#   - the ledger's own top-level directory, taken from $LEDGER rather than named, so it
#     follows a ledger passed via arg 5. The ledger and the reconcile report quote each
#     predicate verbatim. Measured: 11 of 13 unfalsifiable predicates read as "reachable"
#     through worktree copies of _bmad-output alone.
#   - this script's own basename, taken from $0. Its header quotes "fail-closed by default"
#     and "Check 3 and Check 4 real enforcers" as the canonical errors, so documenting the
#     defect would mask the defect. Only this file is excluded, not the updater directory:
#     entries proposing fixes TO the updater are real and must stay decidable.
# THE STRIP IS PATH ARITHMETIC, NOT STRING SURGERY, AND AN EMPTY RESULT MEANS *NO EXCLUSION*.
#
# This was `${LEDGER#"$CONSUMER"/}` piped through `%%/*` — a literal prefix strip that silently
# yields "" whenever the two arguments are not spelled identically. Measured, four ordinary
# invocations produced "": a ledger outside the consumer tree (arg 5 pointing at /tmp), a
# consumer arg with a trailing slash, a doubled slash, and a `/./` in the path produced ".".
#
# An empty or "." value is not a harmless no-op. It becomes the pathspec `:(exclude)`, which
# excludes the WHOLE TREE, so `git grep` finds nothing and exits 1 — NOT 128. consumer_reachable
# therefore returns 1 (a real "absent"), not 2 (undecidable), and every entry whose substring is
# absent at both refs is reported `unfalsifiable predicate: … absent from the consumer's own
# tracked tree`. A wrong input manufactures a confident finding, and the undecidable branch that
# exists for exactly this case is unreachable. Observed on the reference consumer: one entry
# reported unfalsifiable via arg 5 and STILL-LIVE via the default path, same refs, same ledger.
#
# So: resolve both sides to physical absolute paths and ask whether one contains the other.
#
# AND WHEN THE SUBJECT IS OUT OF TREE, FALL BACK TO THE CONVENTIONAL PATH — do not drop the
# exclusion. Passing arg 5 a copy under /tmp does not remove the consumer's OWN ledger from the
# tree, and that copy quotes every predicate verbatim, so scanning it would make EVERY predicate
# read reachable and the unfalsifiable check would go silently vacuous. Trading the false
# accusation for a false all-clear is the worse half of the same bug. `$LEDGER_DEFAULT` is the
# same expression the subject defaults to, so the two never drift.
SELF_BASE="${0##*/}"
ledger_top_dir() { # <path> -> its top-level dir relative to the consumer root, or "" if outside
  local _p="$1" _root _abs
  [ -n "$_p" ] || return 0
  _root="$(git -C "$CONSUMER" rev-parse --show-toplevel 2>/dev/null)" || return 0
  [ -n "$_root" ] || return 0
  _root="$(cd "$_root" 2>/dev/null && pwd -P)" || return 0
  case "$_p" in /*) _abs="$_p" ;; *) _abs="$CONSUMER/$_p" ;; esac
  _abs="$(cd "$(dirname "$_abs")" 2>/dev/null && pwd -P)/$(basename "$_abs")" || return 0
  case "$_abs" in
    "$_root"/*) _abs="${_abs#"$_root"/}"; printf '%s' "${_abs%%/*}" ;;
    *)          : ;;
  esac
}
LEDGER_TOP="$(ledger_top_dir "$LEDGER")"
[ -n "$LEDGER_TOP" ] || LEDGER_TOP="$(ledger_top_dir "$LEDGER_DEFAULT")"

# THE SCAN IS `git grep`, NOT A FILE LIST PIPED INTO xargs.
#
# git grep searches TRACKED files in the working tree, which is the same derived set the
# ls-files version used — `.claude/worktrees/` agent checkouts are untracked and drop out
# for free — but it needs no temp file, no NUL plumbing, and no xargs. That matters beyond
# tidiness: the xargs form died with `unterminated quote` on paths git had quoted, produced
# nothing, and with stderr discarded that abort was indistinguishable from "not found", so
# every predicate read unfalsifiable. Removing the machinery removes the failure mode.
#
# It is also ~40x faster (0.012s vs 0.5s per substring on the reference consumer), which is
# not a micro-optimisation: this runs once per substring per absent-at-both entry, and at 7
# such entries the old form was ~70% of the whole classifier's runtime.
#
# EXIT STATUS IS READ DIRECTLY, three ways: 0 found, 1 not found, anything else (bad
# pathspec, not a repo) UNDECIDABLE. No pipe, so no early-exit SIGPIPE can turn a match into
# a miss — the defect this file's all_present() carried for large files.
consumer_scannable() {
  git -C "$CONSUMER" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 1
  [ -n "$(git -C "$CONSUMER" ls-files 2>/dev/null | head -1)" ]
}

# True iff EVERY substring is found in at least one tracked consumer file. A predicate is
# unfalsifiable when ANY of its substrings can never appear, because all_present() requires
# all of them to match at theirs.
#
# Returns 2 — NOT false — when the consumer cannot be scanned. Undecidable must not
# manufacture a verdict: reporting "unreachable" there would turn a missing input into a
# wall of NEEDS-REVIEW on entries that are fine. The caller says so in DETAIL.
consumer_reachable() {
  consumer_scannable || return 2
  while IFS= read -r _one; do
    [ -n "$_one" ] || continue
    # NEVER emit a bare `:(exclude)`. Empty means the ledger is outside the tree, so there is
    # nothing of its to exclude — passing the empty pathspec would exclude everything and turn
    # this scan into a machine for false "absent" verdicts.
    if [ -n "$LEDGER_TOP" ]; then
      git -C "$CONSUMER" grep -qF -e "$_one" -- \
        ":(exclude)$LEDGER_TOP" ":(exclude)*/$SELF_BASE" >/dev/null 2>&1
    else
      git -C "$CONSUMER" grep -qF -e "$_one" -- \
        ":(exclude)*/$SELF_BASE" >/dev/null 2>&1
    fi
    case "$?" in
      0) : ;;
      1) return 1 ;;
      *) return 2 ;;
    esac
  done <<EOF
$1
EOF
  return 0
}

TV="$(theirs_show VERSION | tr -d '[:space:]')"
[ -n "$TV" ] || TV="$THEIRS"

# Extract (label<TAB>directive) for each OPEN entry carrying a verify: line. An entry is a
# top-level `- **…**` bullet OR a `##`-`######` heading; either one ends the entry before it.
# `ADOPTED UPSTREAM` anywhere in the entry marks it closed → skip. Piped into a while-read
# loop rather than `mapfile` so it runs under bash 3.2 (macOS), like the sibling reconcile
# classifiers.
#
# DASH is passed in rather than written as an awk escape: it is a multibyte em dash, and
# `\xNN` escapes are not portable across the awks this ships to (BSD awk on macOS, gawk and
# mawk on Linux). A label is the text before the first " — ", so
# `## PC-FOO — long prose title (filed …)` labels as `PC-FOO`.
#
# BOTH SHAPES SPLIT ON THE DASH, AND NEITHER TRUNCATES. The split was on the heading arm only,
# and both arms then clipped the result to 70 characters. The label is the ENTRY column of this
# tool's output and the name `emit-report.sh` renders into the operator's report; it is a join
# key back into the ledger, and a clipped key does not grep. Measured on the reference consumer:
# TEN of 41 rows came out at exactly 70 bytes, five of them a bullet's whole prose title because
# the bullet arm never split, one clipped mid-word inside `(original` — two of which the operator
# read as garbage rows in a real report. The cap was undocumented and had no padding counterpart
# anywhere, so it was never column formatting; it was a silent clip.
#
# A bullet whose bold title WRAPS gets its whole first line, because `sub(/\*\*.*/)` finds no
# closing `**` there. That is complete and greppable and visibly not an id, which is the honest
# output for a malformed entry. Narrowing the bullet predicate to "closing ** on this line" would
# instead DROP such an entry, and the reference consumer has a live one.
ENTRIES="$(awk -v DASH=' — ' "$(ledger_entry_awk)"'
  # An ENTRY LINE closes its own entry two ways. A marker anywhere on it is one: the withdrawal
  # lives in the heading (`## PC-FOO — **WITHDRAWN …**`) and the fork-retirement records are
  # bullets whose title ends `→ ADOPTED UPSTREAM (v…)`. The retained-copy parenthetical is the
  # other: when a withdrawn entry is superseded, the honest convention keeps its original text
  # under a heading carrying `(original text, retained for the record)` — and that copy carries
  # no marker of its own, so it re-reported HAND-REVIEW forever, asking an operator to adjudicate
  # a defect that was retracted as false. The withdrawal marker closes the superseder; this
  # closes the copy it supersedes.
  function entry_line_closes(s) {
    return (s ~ /ADOPTED UPSTREAM|WITHDRAWN/) || (s ~ /\(original text, retained for the record\)/)
  }
  # EVERY RECEIPT, NOT THE LAST ONE. `directive` was a scalar assigned inside a per-line rule, so
  # an entry carrying two line-leading `verify:` lines had its first silently overwritten — no row,
  # no warning, and the surviving verdict answering a question the operator did not ask. That is
  # the subject PC-S296 names. v0.153.0 anchored the match to a line start, which closed the
  # PROSE-MENTION arm of the same defect, and the entry was then wrongly recorded upstream as
  # absorbed on that basis — a citation read as a fix. Reproduced at v0.183.0: an entry with
  # `theirs_has` (STILL-LIVE) followed by `theirs_lacks` on an absent token emitted ONLY the second
  # row, while the same entry carrying the first receipt alone emitted STILL-LIVE.
  #
  # An entry now emits one row PER receipt, tagged with its ordinal. THE AGGREGATE RULE IS THAT AN
  # ENTRY CLOSES ONLY WHEN EVERY RECEIPT CLOSES, and printing them all is what enforces it: a
  # CLOSE-CANDIDATE row can no longer hide a STILL-LIVE one, and ledger-rotate.sh archives only on
  # an explicit `**ADOPTED UPSTREAM (v` annotation by the operator, so the close stays a human act taken
  # with every row in view.
  function flush(){
    if (has_verify && !closed && label != "")
      for (di = 1; di <= dn; di++)
        printf "%s\t%s\t%s\n", label, di "/" dn, dv[di]
    has_verify=0; closed=0; label=""; dn=0
  }
  {
    shape = ledger_entry_shape($0)
    if (shape == "bullet") {
      flush()
      l=$0; sub(/^- \*\*/,"",l); sub(/\*\*.*/,"",l)
      p=index(l, DASH); if (p > 0) l=substr(l, 1, p-1)
      sub(/[[:space:]]+$/,"",l)
      gsub(/`/,"",l); label=l
      if (entry_line_closes($0)) closed=1
      next
    }
    if (shape == "heading") {
      flush()
      l=$0; sub(/^#+[ \t]*/,"",l)
      p=index(l, DASH); if (p > 0) l=substr(l, 1, p-1)
      sub(/[[:space:]]+$/,"",l)
      gsub(/`/,"",l); label=l
      if (entry_line_closes($0)) closed=1
      next
    }
  }
  # TWO WAYS AN ENTRY IS DONE, AND ONLY ONE WAS RECOGNISED. `ADOPTED UPSTREAM` closes an entry
  # upstream took. `WITHDRAWN` closes one whose PREMISE WAS FALSE — the author found the defect
  # they filed does not exist. Both are finished; neither wants a verdict on the next pull. Only
  # the first was in the vocabulary, so a withdrawn entry re-reported forever, and its receipt
  # cannot resolve the contradiction because there is no defect for the receipt to test.
  #
  # Measured on the reference consumer: of nine HAND-REVIEW rows, TWO were one withdrawn entry
  # counted twice — the entry and the copy of its original text retained for the record.
  #
  # NOT MIRRORED INTO ledger-rotate.sh. Its close predicate is the stricter annotation form
  # `**ADOPTED UPSTREAM (v`, and lib.sh records that the two differ deliberately. A withdrawn
  # entry therefore stops emitting a row but is not auto-archived: the silent-skip direction,
  # which that same note names as the safe one of the two. Rotating a withdrawal is a hand call.
  #
  # ANCHORED, for the same reason `^verify:` below is — and this predicate needed it MORE, because
  # its failure is silent in the worse direction. Unanchored, a PROSE MENTION of the vocabulary
  # closed a live entry, and the operator saw no row at all rather than a wrong one. Measured on
  # the reference consumer: FOUR entries with live receipts were invisible — three closed by a
  # sentence that quotes the marker while explaining when to write it (`… and annotate
  # `ADOPTED UPSTREAM (v…)` once the grep is non-zero`), one by a blockquote of the output this
  # very file emits. An entry that documents the close vocabulary could not describe its own
  # subject without deleting itself.
  # (No apostrophes below this point: the awk program is a single-quoted shell string, and one
  # in a comment ends it — which is exactly how the first draft of this block failed to parse.)
  #
  # THE DISCRIMINATOR IS LINE-LEADING STRUCTURE, not the presence of the words. An annotation is
  # written at the start of its line — bare, or opening a bold span, optionally behind the `<br>`
  # the entry bodies use to force a newline. A mention sits inside a sentence. Derived from every
  # occurrence on the reference consumer: seven real closes (`**ADOPTED UPSTREAM (v…`,
  # `**BOTH ADOPTED UPSTREAM (verified …`, `<br>**ANGLE-BRACKET SKIP ADOPTED UPSTREAM (v…`, a bare
  # line-start form, and the withdrawal) all match; all four mentions fail. Entry lines are handled
  # in the branch above, where the marker legitimately sits mid-line after the title.
  #
  # `[^`]*` between the bold opener and the marker is defence in depth: an annotation never quotes
  # itself, so a code span before the words is a mention even when the bold happens to lead.
  /^[ \t]*(<br[ \t]*\/?[ \t]*>)?[ \t]*(\*\*[^`]*)?(ADOPTED UPSTREAM|WITHDRAWN)/ { closed=1 }
  # ANCHORED to the start of the line. The ledger is prose that DISCUSSES receipts as well as
  # carrying them, and an unanchored match treated both alike: "explicitly NO verify: field"
  # in a sentence registered as a directive. The scalar is last-match-wins, so a prose mention
  # later in a span silently REPLACED the real receipt with whatever followed it — 450 words of
  # narrative, in the case the consumer filed as PC-S296-LEDGER-REVERIFY-LAST-MATCH-WINS.
  # Measured on the reference consumer: 88 unanchored matches, 47 real receipt lines.
  # A leading list marker, indentation, or backtick still counts; a mid-sentence mention does not.
  # The permitted prefix is LINE-LEADING STRUCTURE ONLY: indentation, a list marker, an HTML
  # break the entry body uses to force a newline, and an opening backtick when the whole
  # receipt is one code span. Derived from the reference consumer, where every real receipt
  # carries one of exactly three prefixes (none, whitespace, <br>) and every other occurrence
  # is a sentence that happens to end in a backtick before the word. A receipt is a line; a
  # mention is part of one.
  /^[ \t]*(<br[ \t]*\/?[ \t]*>)?[ \t]*[-*]?[ \t]*`?verify:/ && match($0, /verify:[ \t]*/) {
    has_verify=1
    directive=substr($0, RSTART+RLENGTH)
    sub(/[[:space:]]+$/,"",directive)
    # A receipt written as one inline code span is the natural thing to type in a markdown
    # ledger, and it leaves a CLOSING backtick on the directive. Stripping backticks from the
    # verb alone is not enough, and is actively worse: the verb then dispatches, the trailing
    # backtick stays glued to the quoted substring, the comparison silently misses, and a loud
    # unknown-verb report becomes a quiet STILL-LIVE. Only a FINAL backtick goes; a substring
    # legitimately ending in one is followed by its closing quote, so this cannot eat it.
    # NOTE no apostrophes in this block: the awk program is a single-quoted shell string.
    sub(/`+$/,"",directive)
    sub(/[[:space:]]+$/,"",directive)
    # APPEND. The cleanups above still run on the scalar; only the handoff to flush() accumulates.
    dn++; dv[dn]=directive
  }
  END { flush() }
' "$LEDGER")"

# A HERESTRING, NOT A PIPE, AND THE REASON IS THE TALLY BELOW. `awk … | while read` runs the
# loop body in a SUBSHELL, so a counter incremented inside it is discarded at the closing
# `done` — a variable that reads as zero for the same reason a check that cannot fire reads as
# one that passed. Capturing the extraction into a variable (rather than moving the awk program
# down into a `< <(…)`) keeps every line of that program where it is, so this change is a
# rewiring and not a hundred-line move. `mapfile` is still not an option: bash 3.2 on macOS.
#
# An EMPTY extraction herestrings as one empty line, which the guard on the first line of the
# body already drops — the same guard that has always dropped awk's blank output.
while IFS="$(printf '\t')" read -r label ord directive; do
  [ -n "$directive" ] || continue
  # Empty suffix for a single-receipt entry, so those rows are unchanged.
  case "$ord" in
    1/1|"") RSFX="" ;;
    *)      RSFX=" [receipt $ord]" ;;
  esac
  verb="${directive%% *}"
  rest="${directive#"$verb"}"; rest="${rest# }"
  # Punctuation around the verb (a stray backtick from prose formatting, a period) is a
  # formatting slip, not a different verb. Strip it for dispatch; the unknown-verb message
  # still reports what was actually written.
  #
  # BOTH ends. This stripped only the trailing side, so a receipt written `` `theirs_lacks` ``
  # — the natural thing to type in a markdown ledger — kept its LEADING backtick and fell
  # through to `unknown verify verb`, filing a formatting slip under the same banner as a
  # typo. That is the exact conflation the `manual` verb was added to eliminate. Four
  # directives on the reference consumer are written that way.
  verb_norm="$(printf '%s' "$verb" | sed -E 's/^[^A-Za-z_]+//; s/[^A-Za-z_]+$//')"
  note=""

  # ASKED FOR EVERY OPEN ENTRY, INDEPENDENT OF THE VERB — including `manual`, which has no
  # other mechanical signal at all. Additional to the receipt's verdict below, never a
  # substitute for it: see THE NAME IS THE THIRD SIGNAL above for why losing either half
  # loses a distinct fact.
  # ONE ROW PER ENTRY, not per receipt: the name is a property of the entry, and repeating it once
  # per receipt would make a two-receipt entry read as two absorptions.
  na=""
  case "$ord" in 1/*|"") na="$(named_absorbed "$label")" ;; esac
  if [ -n "$na" ]; then
    na_v="${na%% *}"; na_c="${na##* }"
    emit NAMED-UPSTREAM "$label" "upstream's own history NAMES this entry's id at v$na_v ($na_c), which no receipt in this entry can see. Confirm whether that commit ABSORBED the entry or recorded a rejection/split; if it absorbed, annotate 'ADOPTED UPSTREAM (v$na_v, verified <date>)' and re-anchor or drop the stale receipt. Do NOT delete the entry."
  fi

  case "$verb_norm" in
    theirs_lacks|theirs_has)
      path="${rest%% *}"
      sub="${rest#"$path"}"
      # Strip surrounding whitespace and one optional pair of double quotes.
      sub="$(printf '%s' "$sub" | sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//')"
      # A directive may carry MORE THAN ONE quoted substring; all must match. Splitting on
      # the `" "` boundary is what makes that work. Without the split the whole run is one
      # literal INCLUDING the quotes between them, which matches nothing — so a multi-
      # substring entry reported "still lacks" forever no matter what theirs held. Measured
      # on the reference consumer: two entries used this form, and one of them named two
      # markers upstream ALREADY carries. It would have stayed open permanently.
      subs="$(printf '%s' "$sub" | sed 's/" *"/\
/g')"
      if [ -z "$path" ] || [ -z "$sub" ]; then
        emit NEEDS-REVIEW "$label" "unresolved: malformed verify: $directive"
        continue
      fi
      if ! theirs_has_path "$path"; then
        # Filed in the consumer's install layout rather than dist-relative. Retry by basename.
        matches="$(theirs_basename_matches "${path##*/}")"
        nmatch="$(printf '%s' "$matches" | grep -c . )"
        if [ "$nmatch" -eq 1 ]; then
          note=" [resolved by basename from '$path' — the ledger's path is not dist-relative]"
          path="$matches"
        else
          emit NEEDS-REVIEW "$label" "unresolved: path '$path' does not resolve at theirs ($TV) and its basename matches $nmatch files there; re-verify by hand"
          continue
        fi
      fi
      present=1; all_present "$(theirs_show "$path")" "$subs" || present=0
      if [ "$verb_norm" = theirs_lacks ]; then
        if [ "$present" -eq 1 ]; then
          if base_holds "$path" "$subs"; then
            emit NEEDS-REVIEW "$label" "vacuous predicate: \"$sub\" is present at BOTH base and theirs ($TV), so 'theirs_lacks' could never have reported STILL-LIVE — no upstream change produced this close. Re-read the entry body before draining.$note"
          else
            av="$(absorbed_at "$path" "$sub")"
            emit CLOSE-CANDIDATE "$label" "theirs:$path now CONTAINS \"$sub\" — upstream absorbed this at $av. Confirm the upstream version covers your entry, then annotate 'ADOPTED UPSTREAM (v$av, verified <date>)'. Do NOT delete the entry.$note"
          fi
        else
          # Absent at theirs. Present at BASE means the predicate demonstrably COULD match,
          # so the still-live side is reachable and there is nothing to decide. Absent at
          # both is the case two refs cannot separate — ask the consumer.
          if base_holds "$path" "$subs"; then
            emit STILL-LIVE "$label" "theirs:$path still lacks \"$sub\"$note"
          else
            consumer_reachable "$subs"; _reach=$?
            case "$_reach" in
              0) emit STILL-LIVE "$label" "theirs:$path still lacks \"$sub\"$note" ;;
              1) emit NEEDS-REVIEW "$label" "unfalsifiable predicate: \"$sub\" is absent at base, at theirs ($TV), AND from the consumer's own tracked tree, so no upstream adoption can produce it — this entry reports STILL-LIVE forever, including after the innovation lands. Re-anchor on a token the fix cannot be written without (a flag, a filename, a status name, a manifest row), or declare 'verify: manual' if the entry is a proposal nobody has built yet.$note" ;;
              *) emit STILL-LIVE "$label" "theirs:$path still lacks \"$sub\" — consumer reachability NOT checked (no tracked file list at '$CONSUMER'), so an unfalsifiable predicate would not have been caught here$note" ;;
            esac
          fi
        fi
      else # theirs_has
        th_total=$((${th_total:-0} + 1))
        if [ "$present" -eq 1 ]; then
          # THE STILL-LIVE ROW IS BYTE-UNCHANGED. The tally is taken here and reported once at
          # the end; suffixing this DETAIL would rewrite every still-live row in every consumer
          # report to say something the summary says better, and these rows are filtered out of
          # that report anyway. See RECEIPTS-UNDECIDED at the foot of this file.
          base_holds "$path" "$subs" && th_undecided=$((${th_undecided:-0} + 1))
          emit STILL-LIVE "$label" "theirs:$path still has \"$sub\"$note"
        else
          if base_holds "$path" "$subs"; then
            av="$(absorbed_at "$path" "$sub")"
            emit CLOSE-CANDIDATE "$label" "theirs:$path no longer has \"$sub\" — upstream fixed this at $av. Confirm, then annotate 'ADOPTED UPSTREAM (v$av, verified <date>)'. Do NOT delete the entry.$note"
          else
            emit NEEDS-REVIEW "$label" "vacuous predicate: \"$sub\" is absent at BOTH base and theirs ($TV), so 'theirs_has' could never have reported STILL-LIVE — no upstream change produced this close. Usually an inverted verb: a substring naming the FIX wants theirs_lacks. Re-read the entry body before draining.$note"
          fi
        fi
      fi
      ;;
    sh)
      if [ -z "$rest" ]; then
        emit NEEDS-REVIEW "$label" "unresolved: empty 'verify: sh' directive"
        continue
      fi
      # A MISSING SUBJECT IS NOT A FIX, AND THIS IS THE ONE VERDICT THAT LOSES DATA.
      #
      # `sh` reads a non-zero exit as "no longer reproduces" -> CLOSE-CANDIDATE. But a
      # receipt whose subject file was RENAMED also exits non-zero -- 127 for a missing
      # command, 126 for a non-executable one, 2 for a `grep` on a missing path -- so a
      # relocation reads as an absorption that never happened. Measured on a reference
      # consumer: ONE relocation commit moved five receipt subjects and all five flipped to
      # CLOSE-CANDIDATE in a single run, every one of them still reproducing at its new
      # path. This file's own header calls that the direction that loses information
      # permanently.
      #
      # The `theirs_*` verbs have been guarded against exactly this since they were
      # written -- an unresolvable path is NEEDS-REVIEW, never a close. `sh` is the escape
      # hatch that runs arbitrary consumer-side commands, where paths are MOST volatile,
      # and it was the one verb without the guard.
      #
      # Status-based, not path-parsing: a subject inside a longer `&&` chain does not
      # surface as a distinguishable status, so a parser would give false confidence. This
      # arm claims only what the status can carry, and says so.
      DIST="$DIST" BASE="$BASE" THEIRS="$THEIRS" CONSUMER="$CONSUMER" \
        bash -c "$rest" >/dev/null 2>&1
      sh_rc=$?
      case "$sh_rc" in
        0)
          emit STILL-LIVE "$label" "verify sh: still reproduces at theirs ($TV)" ;;
        126|127)
          emit NEEDS-REVIEW "$label" "unresolved: the receipt exited $sh_rc (command not found / not executable), which is what a RENAMED or DELETED subject looks like — not a fix. A close here would record an absorption that never happened. Re-anchor the receipt at the subject's current path, then re-run. If the subject really is gone, say so in the entry rather than letting the exit status say it." ;;
        *)
          emit CLOSE-CANDIDATE "$label" "verify sh: no longer reproduces at theirs ($TV) — likely absorbed. Confirm, then annotate 'ADOPTED UPSTREAM (v$TV, verified <date>)'. Do NOT delete the entry. NOTE: exit $sh_rc cannot distinguish 'fixed' from 'subject moved' inside an && chain — check the receipt's subject paths still exist before draining." ;;
      esac
      ;;
    manual)
      emit HAND-REVIEW "$label" "verify: manual — no mechanical predicate by design; adjudicate the entry body against theirs ($TV)"
      ;;
    *)
      emit NEEDS-REVIEW "$label" "unresolved: unknown verify verb '$verb' (expected theirs_lacks | theirs_has | sh | manual)"
      ;;
  esac
done <<< "$ENTRIES"

# --- RECEIPTS-UNDECIDED: how much of the STILL-LIVE column this pull actually measured ------
#
# THE STATE THIS MAKES VISIBLE. `theirs_has` reports STILL-LIVE when the substring is present at
# theirs. If it was present at BASE too, then nothing in `base..theirs` moved the predicate, and
# this run's STILL-LIVE is a RESTATEMENT of the last run's, not a new measurement. The entry may
# be live or long fixed; this pull did not distinguish them.
#
# That is not a hypothetical. Every guard in this file tests the receipt, and SKILL.md step 3f
# already carries the rule that would prevent the failure — *anchor a `theirs_has` receipt on a
# token the FIX MUST REMOVE* — while stating in the same breath that it *"has no guard at all,
# and it is the verb most receipts use"*. MEASURED on the reference consumer at 0.301.0, five
# `STILL-LIVE` verdicts re-checked against the code by hand: THREE were false, and all three had
# anchored on text their own fix keeps —
#   PC-S299-…-SIGPIPE-FALSE-ABSENT           anchored `grep -qF -- `, which IS the repaired line
#   PC-S299-…-MISATTRIBUTES-ABSORBING-VERSION anchored prose the corrected emit still prints
#   PC-S316-ABSORPTION-DETECTOR-…-ANCHORS     anchored a guard the fix deliberately KEPT, adding
#                                             a second pass beside it — which that entry's own
#                                             receipt note predicted it would miss
# Only ONE of the three was visible to `named_absorbed`; the other two are invisible to every
# other signal here. And this file's own tally, run against that ledger, is **24 of 24** — every
# `theirs_has` receipt it carries. (A standalone probe of the same question said 23 of 23: it
# skipped a receipt whose path resolves only through the basename fallback this file implements.
# The number above is the SHIPPING code's, which is the only one that can be quoted.)
#
# WHY A COUNT AND NOT A VERDICT. "Present at both refs" is ALSO the normal state of a genuinely
# live entry, so it cannot decide any single row — the same undecidability the `theirs_lacks`
# unfalsifiable case has, and there the answer was a third ref. There is no third ref for this
# verb: the question is *would the fix have had to remove this token*, which is not answerable
# from two trees. A predicate WAS built and measured — the bucket, narrowed to entries whose
# cited FILE changed in `base..theirs` — and it is NOT SHIPPED: measured by that same standalone
# probe it fires on 15 of the 23 it could see, including
# entries confirmed live (`PC-S302-…-DISARMS-LC-A1`, whose subject sentence is still in
# SKILL.md). An unmeasured lint is one the operator turns off. Do not rebuild it.
#
# So this claims only what it can carry: a COUNT of a defined set, with no per-entry accusation
# and therefore no false-positive set. It reaches the operator because it is not `STILL-LIVE` —
# `emit-report.sh` filters that one status out, which is precisely why the false confidence has
# been invisible: the report shows closes, and zero closes reads as nothing to close.
#
# SILENT AT ZERO, AND THE ZERO IS EARNED. The row is emitted only when the bucket is non-empty,
# so a ledger whose receipts are all well-anchored says nothing — and $th_total is the control
# that makes that silence readable, because a run with no `theirs_has` receipts at all has an
# empty bucket for a completely different reason.
if [ "${th_undecided:-0}" -gt 0 ]; then
  # THE ENTRY COLUMN IS A CONSTANT, NOT `$LEDGER`, AND THAT IS NOT COSMETIC. This row is
  # run-scoped, so it has no entry to name — and the obvious filler is the ledger path, which is
  # spelled differently depending on how the caller addressed the same file. The
  # `ledger-reverify-unfalsifiable` fixture asserts precisely that a verdict cannot depend on the
  # addressing, and it caught this: `<consumer>/./_bmad-…/push-candidate-ledger.md` and an arg-5
  # copy elsewhere are the same run and must produce the same rows.
  emit RECEIPTS-UNDECIDED "(theirs_has receipts)" "$th_undecided of $th_total 'theirs_has' receipt(s) reported STILL-LIVE on a substring present at BASE as well as at theirs ($TV), so THIS PULL MOVED NEITHER SIDE OF THEM: those verdicts are restatements of the previous run, not new measurements. A STILL-LIVE here is not evidence the defect survives — an anchor on text the fix KEEPS survives the fix, and the entry can then never close. Re-anchor each on a token the fix must REMOVE (step 3f), or read the code. Do not treat a zero CLOSE-CANDIDATE count from this run as evidence that nothing was absorbed."
fi

# ---------------------------------------------------------------------------
# ENTRY-SWALLOWED — a bold-bullet annotation that became its own entry
# ---------------------------------------------------------------------------
# THE DEFECT. `ledger_entry_shape()` opens a new entry on ANY line-leading `- **`. That is
# correct for a ledger whose entries are bullets, and it is what makes an ANNOTATION written in
# the same shape indistinguishable from one. An operator who annotates an entry with
# `- **Case 3 (…)** …` splits that entry in two: everything after the annotation, INCLUDING the
# receipt, is attributed to a new entry labelled with the annotation prose, and the real entry
# stops emitting any row under its own id. Nothing said so. The reference consumer hit this while
# annotating an entry and two intermediate runs read clean.
#
# NOT A RE-KEYING OF THE ENTRY-SHAPE RULE. That remedy was considered and rejected: the bullet
# arm is load-bearing for every ledger whose entries are bullets, which is most of them, and
# narrowing it drops real entries. v0.171.1 recorded the same class one heuristic over -- a
# swallowed entry produces no row at all -- and the answer there was the same: leave the parser,
# ship the diagnostic.
#
# WHAT IS DETECTABLE, MEASURED, AND WHAT WAS REJECTED ON THE WAY. Two predicates were measured
# against the reference consumer before this one shipped, and both are recorded because both read
# as obviously right:
#
#   (1) "an entry that ends without emitting a row". UNSHIPPABLE: an entry with no `verify:` line
#       legitimately emits nothing, and that is 58 entries there (15 id-shaped, 43 prose). It
#       reports most of the ledger.
#   (2) "a receipt attributed to a label that is not an entry id". Also unshippable, and this one
#       had to be run against the real tool to find out: SEVEN rows, of which SIX are real entries
#       that simply carry prose titles rather than id keys. A standalone probe scored it 1 of 1
#       because the probe anchored `verify:` at column zero while the real receipt pattern
#       tolerates the indentation every bullet-nested receipt actually has. The probe was stricter
#       than the thing it was modelling, so it under-counted, and its clean result was an artefact.
#
# THE SIGNAL IS THE COLON. An annotation is written as a lead-in -- `- **The share:** the analyst
# also reads ...` -- and an entry is written as a title. The bold span of a lead-in ends in a
# colon; the bold span of a title does not. Measured across all 52 top-level bullets on the
# reference consumer: THREE end in a colon, and those three are exactly the annotation sub-bullets
# of one entry, each of which truncates it. The other 49 are real entries. FALSE POSITIVES: ZERO.
#
# The id-shape guard is kept as a second condition so that an entry legitimately keyed
# `- **PC-FOO-BAR:**` cannot be reported for its punctuation alone.
#
# BULLETS ONLY. A heading ending in a colon is a section heading and is not this defect.
#
# A SEPARATE PASS, DELIBERATELY. It reuses the single-homed boundary rule but runs its own scan,
# so a diagnostic added here cannot perturb the receipt parse above -- which is the parse this
# entire tool exists to get right.
# (No apostrophes anywhere below: the awk program is a single-quoted shell string.)
awk -v DASH=' — ' "$(ledger_entry_awk)"'
  # An id is upper-case, digits and hyphens, with at least one hyphen. A single word is not an id.
  function idshape(s) {
    sub(/[[:space:]]*\(.*\)[[:space:]]*$/, "", s)
    return (s ~ /^[A-Z0-9-]+$/ && s ~ /-/)
  }
  function flush() {
    if (label != "" && is_bullet && label ~ /:$/ && !idshape(label))
      printf "%s\t%s\t%s\n", label, (hasv ? "CAPTURED" : "none"), (prev_id == "" ? "(no id-shaped entry above)" : prev_id)
  }
  {
    shape = ledger_entry_shape($0)
    if (shape != "") {
      flush()
      if (label != "" && idshape(label)) prev_id = label
      l = $0
      if (shape == "bullet") { sub(/^- \*\*/, "", l); sub(/\*\*.*/, "", l) }
      else                   { sub(/^#+[ \t]*/, "", l) }
      p = index(l, DASH); if (p > 0) l = substr(l, 1, p-1)
      sub(/[[:space:]]+$/, "", l)
      gsub(/`/, "", l)
      label = l; hasv = 0; is_bullet = (shape == "bullet")
      next
    }
    if ($0 ~ /^[ \t]*(<br[ \t]*\/?[ \t]*>)?[ \t]*[-*]?[ \t]*`?verify:/) hasv = 1
  }
  END { flush() }
' "$LEDGER" 2>/dev/null \
| while IFS="$(printf '\t')" read -r sw_label sw_cap sw_prev; do
    [ -n "${sw_label:-}" ] || continue
    if [ "$sw_cap" = CAPTURED ]; then
      sw_harm="and it CAPTURED that entry's verify: receipt, so the entry now emits NO row under its own id — which reads exactly like an entry with nothing to report"
    else
      sw_harm="so everything below it is attributed to this annotation rather than to that entry"
    fi
    emit ENTRY-SWALLOWED "$sw_label" "this bullet is an annotation lead-in, not an entry title — its bold span ends in a colon and it is not an id. A line-leading '- **\u2026**' opens a NEW entry, so this line truncates the entry above it (nearest id-shaped entry above: ${sw_prev}) ${sw_harm}. Re-indent the annotation so it does not start a line, or drop the bold, then re-run and confirm the entry reports under its own id."
  done

exit 0   # classifier — the while-pipe's status is irrelevant; a close never blocks
