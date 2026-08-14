#!/usr/bin/env bash
# backlog-reverify.sh -- execute every entry's `verify:` receipt in docs/backlog.md and
# classify the entry. A CLASSIFIER, not a gate: exit 0 ALWAYS, and the caller decides.
#
# WHY THIS EXISTS. A plan's next-action list records status as a human CLAIM that nobody
# re-derives. Measured on this repo's own plan: item 8 read "needs the OPERATOR, and an idle
# box" for a full session AFTER the operator had already run it, and a human had to say so.
# A receipt that executes cannot drift that way -- it re-answers on every run.
#
# THIS IS THE DISTRIBUTION'S BACKLOG AND IT IS NOT A PUSH-CANDIDATE LEDGER. The consumer's
# `reconcile/ledger-reverify.sh` resolves `theirs_has`/`theirs_lacks` against a PULL's theirs
# ref -- one of a base/theirs/ours triple. There is no triple here; there is one working tree.
# The verbs therefore differ by design (`sh`/`has`/`lacks`), so neither engine can read the
# other's ledger and a receipt cannot be moved between them by copy-paste.
#
# THE ENTRY GRAMMAR IS SHARED, THE PREDICATES ARE NOT. `ledger_entry_shape()` comes from
# reconcile/lib.sh, whose own header records why: rotate and reverify were two hand-copies of
# that boundary rule and they DRIFTED WITHIN ONE RELEASE. The close-predicates deliberately
# stay in their own files -- reverify skips on the phrase anywhere, rotate requires the
# annotation form -- and this file's is a third, for the same reason.
#
# THE GUARD THAT DOES NOT TRANSFER, STATED RATHER THAN FAKED. The consumer engine separates a
# live entry from one anchored on invented prose by reading a THIRD REF: a token the fix cannot
# be written without exists in the consumer's own implementation, invented prose exists nowhere
# (core/fixtures/ledger-reverify-unfalsifiable/README.md -- 13 such entries measured at
# v0.146.0). Here the ledger and the searched tree are ONE tree, so there is no third ref and
# no local analogue. What replaces it: this tree is EXECUTABLE, so `verify: sh` asserts the
# behaviour itself and cannot be anchored on prose. `has`/`lacks` remain available and remain
# the author's responsibility to anchor on a token the fix must carry. That duty is named in
# docs/backlog.md and enforced by review, NOT by this program -- do not read a clean run as
# evidence that the anchors are sound.
#
# Usage:  backlog-reverify.sh [<ledger-path>]        (default: <repo-root>/docs/backlog.md)
# Output: TSV -- STATUS<TAB>ENTRY<TAB>DETAIL
#   CLOSE-CANDIDATE  the receipt says the fix is present. The OPERATOR confirms and annotates
#                    `**LANDED (v<version>, verified <sha>).**`; this tool never writes.
#   STILL-LIVE       the receipt still reproduces here. Stays open.
#   HAND-REVIEW      the entry declares `verify: manual` -- no mechanical predicate by design.
#   NEEDS-REVIEW     the RECEIPT is at fault, never the entry. The DETAIL names which:
#                    `unresolved:` (no receipt, unknown verb, malformed line, missing path)
#                    or `vacuous predicate:` (a substring that cannot discriminate).
#   INPUT-UNRESOLVED an ARGUMENT does not resolve. Run-scoped, not entry-scoped. This row
#                    exists because that state used to be spelled as zero rows and rc=0,
#                    which is how a CLEAN corpus is spelled -- the two must not collide.
#   ALREADY-CLOSED   annotated `**LANDED (v` and awaiting rotation. Reported so the count is
#                    conserved; `backlog-rotate.sh` is what moves them.
# Exit:   0 ALWAYS.
set -uo pipefail

# Resolve the repo root by WALKING UP FOR A MARKER, never by counting `..` hops -- a validator
# that counts hops answers differently from the root, from a subdirectory and from a sandbox
# that copied it, and the sandbox answer is the silent one.
REPO_ROOT=""
d="$(cd "$(dirname "$0")" && pwd)"
while [ "$d" != "/" ]; do
  if [ -f "$d/VERSION" ]; then REPO_ROOT="$d"; break; fi
  d="$(dirname "$d")"
done
if [ -z "$REPO_ROOT" ]; then
  printf 'INPUT-UNRESOLVED\t%s\tunresolved: no VERSION marker above this script, so the repo root is unknown and every relative receipt path would resolve against the wrong tree. Nothing was re-verified; a zero row count here is not a clean corpus.\n' "$(dirname "$0")"
  exit 0
fi

LEDGER="${1:-$REPO_ROOT/docs/backlog.md}"
if [ ! -f "$LEDGER" ] || [ ! -r "$LEDGER" ]; then
  printf 'INPUT-UNRESOLVED\t%s\tunresolved: the ledger path is not a readable file. Nothing was re-verified; a zero row count here is not a clean corpus.\n' "$LEDGER"
  exit 0
fi

# The entry-boundary rule, single-sourced. See the header for why this is not copied.
LIB="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
if [ ! -f "$LIB" ]; then
  printf 'INPUT-UNRESOLVED\t%s\tunresolved: reconcile/lib.sh is missing, so the entry-boundary rule cannot be loaded. Refusing to fall back to a private copy of that grammar -- the two copies this replaced drifted within one release. Nothing was re-verified.\n' "$LIB"
  exit 0
fi
# shellcheck source=../core/skills/ai-dlc-update/reconcile/lib.sh
. "$LIB" || {
  printf 'INPUT-UNRESOLVED\t%s\tunresolved: reconcile/lib.sh could not be sourced. Nothing was re-verified.\n' "$LIB"
  exit 0
}

# Split the ledger into one record per entry: LABEL <TAB> CLOSED <TAB> RECEIPT
# CLOSED is 1 when the entry carries the annotation FORM `**LANDED (v` -- the form, never the
# word anywhere, because an entry whose prose DISCUSSES landing something is not closed. That
# is the same distinction rotate draws, and getting it wrong sweeps live work.
#
# THE AWK PROGRAM IS BUILT OUTSIDE A COMMAND SUBSTITUTION, DELIBERATELY. `bash` here is 3.2,
# whose `$( ... )` parser counts parentheses across the whole body and does NOT exempt heredoc
# content. The regex below carries `\(v` -- an escaped paren that is a LITERAL to awk and an
# unmatched OPEN to that counter -- so building this inside `RECORDS="$( ... )"` made the shell
# swallow the rest of the file and report `unexpected EOF` a hundred lines later, at a line
# with nothing wrong with it. A minimal heredoc-in-substitution parses fine; it is the
# unbalanced paren in the BODY that breaks it, which is why the construct looks innocent.
AWKF="$(mktemp)" || { printf 'INPUT-UNRESOLVED\t-\tunresolved: mktemp failed, so the entry parser could not be built. Nothing was re-verified.\n'; exit 0; }
{ ledger_entry_awk; cat <<'AWK'
function flush(   r) {
  if (label == "") return
  r = receipt; if (r == "") r = "@NONE@"
  printf "%s\t%d\t%s\n", label, closed, r
  label = ""; closed = 0; receipt = ""
}
{
  shape = ledger_entry_shape($0)
  if (shape != "") {
    line = $0
    if (shape == "heading") { sub(/^#{2,6}[ \t]+/, "", line) }
    else                    { sub(/^- \*\*/, "", line); sub(/\*\*.*$/, "", line) }
    # THE LABEL RULE IS LOCAL, AND lib.sh SAYS SO -- only the BOUNDARY is shared, because the
    # two callers extract a label differently from a bullet and from a heading.
    #
    # AN ENTRY IS AN ID, NOT ANY HEADING. Measured on this file's own first run: the preamble's
    # `## Receipts` section parsed as an entry, and because that section QUOTES the closing
    # annotation form while explaining it, the entry came back ALREADY-CLOSED. Prose about the
    # ledger became a row in it. So a heading opens an entry only when it opens with an id --
    # and a heading that does not is not a boundary at all, or every prose section would end
    # the entry above it.
    #
    # Extracting by match() rather than truncating at the ` -- ` title separator also removes
    # the em-dash from the grammar entirely. The first cut truncated with a BRACKET CLASS over
    # a multibyte em-dash, which is this machine's documented trap -- a multibyte character
    # needs an alternation, never a class -- and it silently kept the whole title as the label.
    if (match(line, /^BL-[0-9]+/)) {
      flush()
      label = substr(line, 1, RLENGTH)
    }
    next
  }
  if (label == "" ) next
  # The annotation must OPEN a line (a `<br>` prefix is how the form is written in practice).
  # A quotation of the form sits mid-sentence, and this file's own preamble contains one --
  # measured: without the anchor, the preamble's explanation of the form closed an entry.
  # backlog-rotate.sh narrows this FURTHER, requiring a numeric version, and that gap is what
  # makes its acceptance test meaningful rather than self-confirming.
  if ($0 ~ /^(<br>)?\*\*LANDED \(v/) closed = 1
  if ($0 ~ /^[ \t]*verify:/ && receipt == "") {
    r = $0
    sub(/^[ \t]*verify:[ \t]*/, "", r)
    receipt = r
  }
}
END { flush() }
AWK
} > "$AWKF"
RECORDS="$(awk -f "$AWKF" "$LEDGER")"
rm -f "$AWKF"

if [ -z "$RECORDS" ]; then
  printf 'INPUT-UNRESOLVED\t%s\tunresolved: the ledger parsed to ZERO entries. An empty parse and a fully-closed backlog are the same zero, so this is reported rather than passed over.\n' "$LEDGER"
  exit 0
fi

emit() { printf '%s\t%s\t%s\n' "$1" "$2" "$3"; }

# `read` on a here-string, never a pipe: an assignment made in a pipeline's last stage is lost
# to a subshell, and `grep -q` fed from a pipe answers with the WRITER's EPIPE status.
while IFS="$(printf '\t')" read -r LABEL CLOSED RECEIPT; do
  [ -n "$LABEL" ] || continue

  if [ "$CLOSED" = "1" ]; then
    emit "ALREADY-CLOSED" "$LABEL" "annotated LANDED and awaiting backlog-rotate.sh"
    continue
  fi

  if [ "$RECEIPT" = "@NONE@" ]; then
    emit "NEEDS-REVIEW" "$LABEL" "unresolved: the entry carries no 'verify:' receipt, so its status is a claim nobody re-derives -- which is the state this ledger exists to replace."
    continue
  fi

  VERB="${RECEIPT%% *}"
  REST="${RECEIPT#* }"
  [ "$VERB" = "$RECEIPT" ] && REST=""

  case "$VERB" in
    manual)
      emit "HAND-REVIEW" "$LABEL" "declares 'verify: manual' -- no mechanical predicate by design"
      ;;
    sh)
      if [ -z "$REST" ]; then
        emit "NEEDS-REVIEW" "$LABEL" "unresolved: 'verify: sh' with an empty one-liner. An empty command exits 0, which this tool would read as CLOSE-CANDIDATE -- a receipt that closes itself."
        continue
      fi
      ( cd "$REPO_ROOT" && eval "$REST" ) >/dev/null 2>&1
      if [ $? -eq 0 ]; then
        emit "CLOSE-CANDIDATE" "$LABEL" "sh receipt exited 0 -- the fix is present. Operator confirms and annotates."
      else
        emit "STILL-LIVE" "$LABEL" "sh receipt exited non-zero -- still reproduces here"
      fi
      ;;
    has|lacks)
      RPATH="${REST%% *}"
      SUB="$(unquote "${REST#* }")"
      # A BACKSLASH-ESCAPED QUOTE INSIDE THE ANCHOR PRODUCES A FALSE CLOSE, MEASURED ON THIS
      # FILE'S OWN FIRST RUN. `unquote` strips ONE matching outer pair and deliberately leaves
      # inner content alone, so `"echo \"foo"` searches for a literal backslash, finds nothing,
      # and a `lacks` receipt reports CLOSE-CANDIDATE -- the dangerous direction, since a false
      # STILL-LIVE only wastes a look while a false close retires a live item. The anchor
      # grammar has no escape mechanism, so an anchor that appears to use one is refused rather
      # than guessed at.
      case "$SUB" in
        *\\*)
          emit "NEEDS-REVIEW" "$LABEL" "unresolved: the anchor contains a backslash, which this grammar does not interpret -- it would be searched for literally and a 'lacks' receipt would then report a FALSE close. Re-anchor on a substring that needs no escaping."
          continue
          ;;
      esac
      if [ -z "$RPATH" ] || [ "$RPATH" = "$REST" ]; then
        emit "NEEDS-REVIEW" "$LABEL" "unresolved: '$VERB' needs a path AND a quoted substring; got: $RECEIPT"
        continue
      fi
      if [ -z "$SUB" ]; then
        emit "NEEDS-REVIEW" "$LABEL" "vacuous predicate: an empty substring matches every file, so '$VERB' cannot discriminate and its verdict is fixed before it runs."
        continue
      fi
      case "$RPATH" in
        docs/backlog.md|docs/backlog.archive.md)
          emit "NEEDS-REVIEW" "$LABEL" "unresolved: the receipt greps the ledger itself, so it measures its own text and closes or stays open on how this entry is WORDED. Anchor on the tree, not on the filing."
          continue
          ;;
      esac
      if [ ! -f "$REPO_ROOT/$RPATH" ]; then
        emit "NEEDS-REVIEW" "$LABEL" "unresolved: '$RPATH' is not a file in this tree. A '$VERB' against a missing path answers the same way forever, whatever the fix does."
        continue
      fi
      if grep -qF -- "$SUB" "$REPO_ROOT/$RPATH"; then FOUND=1; else FOUND=0; fi
      if [ "$VERB" = "has" ]; then
        if [ "$FOUND" = "1" ]; then
          emit "CLOSE-CANDIDATE" "$LABEL" "'$RPATH' now contains the anchor -- the fix is present. Operator confirms and annotates."
        else
          emit "STILL-LIVE" "$LABEL" "'$RPATH' still lacks the anchor"
        fi
      else
        if [ "$FOUND" = "0" ]; then
          emit "CLOSE-CANDIDATE" "$LABEL" "'$RPATH' no longer contains the anchor -- the fix is present. Operator confirms and annotates."
        else
          emit "STILL-LIVE" "$LABEL" "'$RPATH' still contains the anchor"
        fi
      fi
      ;;
    *)
      emit "NEEDS-REVIEW" "$LABEL" "unresolved: unknown verb '$VERB'. This ledger's verbs are sh, has, lacks, manual. 'theirs_has'/'theirs_lacks' belong to the CONSUMER's push-candidate ledger and resolve against a pull ref that does not exist here."
      ;;
  esac
done <<EOF
$RECORDS
EOF

exit 0
