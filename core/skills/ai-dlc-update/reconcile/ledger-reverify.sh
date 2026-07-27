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
#   STILL-LIVE       the entry still reproduces at theirs; stays open (filtered from the report).
#   HAND-REVIEW      the entry declares `verify: manual` — no mechanical predicate by design.
#   NEEDS-REVIEW     the receipt itself is at fault. THREE causes, and the DETAIL names which:
#                    `unresolved:` (malformed line, unresolvable path, empty sh, unknown verb),
#                    `vacuous predicate:`, `unfalsifiable predicate:`. Hand-review, as an entry
#                    without a verify line would be.
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
LEDGER="${5:-$CONSUMER/_bmad-output/ai-dlc-update/push-candidate-ledger.md}"

# A consumer that never filed a candidate has no ledger and nothing to re-verify.
[ -f "$LEDGER" ] || exit 0

emit() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }

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
LEDGER_TOP="${LEDGER#"$CONSUMER"/}"; LEDGER_TOP="${LEDGER_TOP%%/*}"
SELF_BASE="${0##*/}"

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
    git -C "$CONSUMER" grep -qF -e "$_one" -- \
      ":(exclude)$LEDGER_TOP" ":(exclude)*/$SELF_BASE" >/dev/null 2>&1
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
awk -v DASH=' — ' "$(ledger_entry_awk)"'
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
  function flush(){
    if (has_verify && !closed && label != "")
      printf "%s\t%s\n", label, directive
    has_verify=0; closed=0; directive=""; label=""
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
  }
  END { flush() }
' "$LEDGER" | while IFS="$(printf '\t')" read -r label directive; do
  [ -n "$directive" ] || continue
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
        if [ "$present" -eq 1 ]; then
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
      if DIST="$DIST" BASE="$BASE" THEIRS="$THEIRS" CONSUMER="$CONSUMER" \
         bash -c "$rest" >/dev/null 2>&1; then
        emit STILL-LIVE "$label" "verify sh: still reproduces at theirs ($TV)"
      else
        emit CLOSE-CANDIDATE "$label" "verify sh: no longer reproduces at theirs ($TV) — likely absorbed. Confirm, then annotate 'ADOPTED UPSTREAM (v$TV, verified <date>)'. Do NOT delete the entry."
      fi
      ;;
    manual)
      emit HAND-REVIEW "$label" "verify: manual — no mechanical predicate by design; adjudicate the entry body against theirs ($TV)"
      ;;
    *)
      emit NEEDS-REVIEW "$label" "unresolved: unknown verify verb '$verb' (expected theirs_lacks | theirs_has | sh | manual)"
      ;;
  esac
done

exit 0   # classifier — the while-pipe's status is irrelevant; a close never blocks
