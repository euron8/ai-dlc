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
#       filed a deliberate declaration under the same banner as a typo. A trailing backtick
#       or period on the verb is tolerated: a formatting slip must not change the verdict.
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
#   NEEDS-REVIEW     the verify line is malformed or its path does not resolve at theirs
#                    (nor by basename); hand-review, as an entry without a verify line would be.
# Exit:   0 ALWAYS. A classifier, not a gate — the caller decides, and a close never blocks.
set -uo pipefail

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

# $1 = file content, $2 = newline-separated substrings. True iff EVERY one is present.
# The convention's single-substring form is just the one-element case.
all_present() {
  _c="$1"; _ok=1
  while IFS= read -r _one; do
    [ -n "$_one" ] || continue
    printf '%s' "$_c" | grep -qF -- "$_one" || _ok=0
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
# mawk on Linux). A heading's label is the text before the first " — ", so
# `## PC-FOO — long prose title (filed …)` labels as `PC-FOO`.
awk -v DASH=' — ' '
  function flush(){
    if (has_verify && !closed && label != "")
      printf "%s\t%s\n", label, directive
    has_verify=0; closed=0; directive=""; label=""
  }
  /^- \*\*/ {
    flush()
    l=$0; sub(/^- \*\*/,"",l); sub(/\*\*.*/,"",l)
    gsub(/`/,"",l); label=substr(l,1,70)
    next
  }
  /^#{2,6}[ \t]/ {
    flush()
    l=$0; sub(/^#+[ \t]*/,"",l)
    p=index(l, DASH); if (p > 0) l=substr(l, 1, p-1)
    sub(/[[:space:]]+$/,"",l)
    gsub(/`/,"",l); label=substr(l,1,70)
    next
  }
  /ADOPTED UPSTREAM/ { closed=1 }
  match($0, /verify:[ \t]*/) {
    has_verify=1
    directive=substr($0, RSTART+RLENGTH)
    sub(/[[:space:]]+$/,"",directive)
  }
  END { flush() }
' "$LEDGER" | while IFS="$(printf '\t')" read -r label directive; do
  [ -n "$directive" ] || continue
  verb="${directive%% *}"
  rest="${directive#"$verb"}"; rest="${rest# }"
  # Trailing punctuation on the verb (a stray backtick from prose formatting, a period) is a
  # formatting slip, not a different verb. Strip it for dispatch; the unknown-verb message
  # still reports what was actually written.
  verb_norm="$(printf '%s' "$verb" | sed -E 's/[^A-Za-z_]+$//')"
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
        emit NEEDS-REVIEW "$label" "malformed verify: $directive"
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
          emit NEEDS-REVIEW "$label" "path '$path' does not resolve at theirs ($TV) and its basename matches $nmatch files there; re-verify by hand"
          continue
        fi
      fi
      present=1; all_present "$(theirs_show "$path")" "$subs" || present=0
      if [ "$verb_norm" = theirs_lacks ]; then
        if [ "$present" -eq 1 ]; then
          if base_holds "$path" "$subs"; then
            emit NEEDS-REVIEW "$label" "vacuous predicate: \"$sub\" is present at BOTH base and theirs ($TV), so 'theirs_lacks' could never have reported STILL-LIVE — no upstream change produced this close. Re-read the entry body before draining.$note"
          else
            emit CLOSE-CANDIDATE "$label" "theirs:$path now CONTAINS \"$sub\" — upstream absorbed this at $TV. Confirm the upstream version covers your entry, then annotate 'ADOPTED UPSTREAM (v$TV, verified <date>)'. Do NOT delete the entry.$note"
          fi
        else
          emit STILL-LIVE "$label" "theirs:$path still lacks \"$sub\"$note"
        fi
      else # theirs_has
        if [ "$present" -eq 1 ]; then
          emit STILL-LIVE "$label" "theirs:$path still has \"$sub\"$note"
        else
          if base_holds "$path" "$subs"; then
            emit CLOSE-CANDIDATE "$label" "theirs:$path no longer has \"$sub\" — upstream fixed this at $TV. Confirm, then annotate 'ADOPTED UPSTREAM (v$TV, verified <date>)'. Do NOT delete the entry.$note"
          else
            emit NEEDS-REVIEW "$label" "vacuous predicate: \"$sub\" is absent at BOTH base and theirs ($TV), so 'theirs_has' could never have reported STILL-LIVE — no upstream change produced this close. Usually an inverted verb: a substring naming the FIX wants theirs_lacks. Re-read the entry body before draining.$note"
          fi
        fi
      fi
      ;;
    sh)
      if [ -z "$rest" ]; then
        emit NEEDS-REVIEW "$label" "empty 'verify: sh' directive"
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
      emit NEEDS-REVIEW "$label" "unknown verify verb '$verb' (expected theirs_lacks | theirs_has | sh | manual)"
      ;;
  esac
done

exit 0   # classifier — the while-pipe's status is irrelevant; a close never blocks
