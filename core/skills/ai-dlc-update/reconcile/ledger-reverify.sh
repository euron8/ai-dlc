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
#
# An entry with NO `verify:` line is left to hand-review, exactly as today — it is not
# emitted. An entry already annotated `ADOPTED UPSTREAM` is closed and skipped.
#
# Usage:  ledger-reverify.sh <dist-repo> <base-sha> <consumer-root> <theirs-ref> [ledger-path]
#         (arg order matches unregistered-drift.sh)
# Output: TSV — STATUS<TAB>ENTRY<TAB>DETAIL
#   CLOSE-CANDIDATE  upstream absorbed the entry; the operator confirms and annotates.
#   STILL-LIVE       the entry still reproduces at theirs; stays open (filtered from the report).
#   NEEDS-REVIEW     the verify line is malformed or its path does not resolve at theirs;
#                    hand-review, as an entry without a verify line would be.
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

TV="$(theirs_show VERSION | tr -d '[:space:]')"
[ -n "$TV" ] || TV="$THEIRS"

# Extract (label<TAB>directive) for each OPEN entry carrying a verify: line. An entry is a
# top-level `- **…**` bullet; the entry ends at the next such bullet or any `##`-`######`
# heading. `ADOPTED UPSTREAM` anywhere in the entry marks it closed → skip. Piped into a
# while-read loop rather than `mapfile` so it runs under bash 3.2 (macOS), like the sibling
# reconcile classifiers.
awk '
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
  /^#{2,6}[ \t]/ { flush(); next }
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

  case "$verb" in
    theirs_lacks|theirs_has)
      path="${rest%% *}"
      sub="${rest#"$path"}"
      # Strip surrounding whitespace and one optional pair of double quotes.
      sub="$(printf '%s' "$sub" | sed -E 's/^[[:space:]]*"?//; s/"?[[:space:]]*$//')"
      if [ -z "$path" ] || [ -z "$sub" ]; then
        emit NEEDS-REVIEW "$label" "malformed verify: $directive"
        continue
      fi
      if ! theirs_has_path "$path"; then
        emit NEEDS-REVIEW "$label" "path '$path' does not resolve at theirs ($TV); re-verify by hand"
        continue
      fi
      present=1; theirs_show "$path" | grep -qF -- "$sub" || present=0
      if [ "$verb" = theirs_lacks ]; then
        if [ "$present" -eq 1 ]; then
          emit CLOSE-CANDIDATE "$label" "theirs:$path now CONTAINS \"$sub\" — upstream absorbed this at $TV. Confirm the upstream version covers your entry, then annotate 'ADOPTED UPSTREAM (v$TV, verified <date>)'. Do NOT delete the entry."
        else
          emit STILL-LIVE "$label" "theirs:$path still lacks \"$sub\""
        fi
      else # theirs_has
        if [ "$present" -eq 1 ]; then
          emit STILL-LIVE "$label" "theirs:$path still has \"$sub\""
        else
          emit CLOSE-CANDIDATE "$label" "theirs:$path no longer has \"$sub\" — upstream fixed this at $TV. Confirm, then annotate 'ADOPTED UPSTREAM (v$TV, verified <date>)'. Do NOT delete the entry."
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
    *)
      emit NEEDS-REVIEW "$label" "unknown verify verb '$verb' (expected theirs_lacks | theirs_has | sh)"
      ;;
  esac
done

exit 0   # classifier — the while-pipe's status is irrelevant; a close never blocks
