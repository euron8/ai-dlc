#!/usr/bin/env bash
# backlog-rotate.sh -- move CLOSED entries out of docs/backlog.md into docs/backlog.archive.md.
#
# WHY THIS EXISTS, MEASURED ON THE PATTERN THIS BORROWS FROM. A ledger is append-only, so it
# grows every cycle and never shrinks: `core/skills/ai-dlc-update/SKILL.md:1678` records the
# reference consumer's push-candidate ledger at 2830 lines / 220 KB / 50 entries, of which only
# 39 still classified. Every read parses the closed ones and every edit pays for their bytes.
# Nothing in this repo bounds a file that way -- `scripts/validate-plan-shape.sh` has no size
# arm, the A6 byte ceiling in `validate-claude-rules.sh` covers only CLAUDE.md and
# .claude/rules/, and `docs/plans/retire-graph-consumer-layer.md` reached 384817 bytes with
# nothing failing a push over it.
#
# IT MOVES, IT NEVER DELETES. An entry wrongly kept costs one more read to notice; one wrongly
# archived costs the work it recorded. The asymmetry decides every judgment call here.
#
# THE CLOSE PREDICATE IS THE ANNOTATION FORM, NEVER THE WORD. `**LANDED (v` -- bolded, with an
# open paren and a version. An entry whose PROSE discusses landing something, or which quotes
# the annotation form while explaining it, is not closed. This is the same distinction
# `reconcile/ledger-rotate.sh` draws for the consumer's ledger, and its seed fixture exists
# because "ADOPTED UPSTREAM appearing in an OPEN entry's prose is the realistic way a rotation
# eats live work."
#
# THE PREDICATE IS DELIBERATELY NOT SHARED WITH THE OTHER TWO, AND lib.sh SAYS WHY. Only the
# entry BOUNDARY is single-sourced there; the close-predicates "stay in their own files because
# they differ DELIBERATELY -- reverify skips on `ADOPTED UPSTREAM` anywhere, rotate requires the
# annotation form -- and collapsing those would archive live entries." This is a third such
# predicate, for a third ledger, for that same reason.
#
# ACCEPTANCE TEST, INHERITED WHOLE: `backlog-reverify.sh` output must be byte-identical before
# and after a rotation. Rotation moves exactly the entries reverify already reports as
# ALREADY-CLOSED, so any difference means a LIVE entry was swept. `--check` runs it for you.
#
# Usage:  backlog-rotate.sh [<ledger>] [--apply] [--archive <path>] [--check]
#         default ledger:  <repo-root>/docs/backlog.md
#         default archive: <ledger-dir>/backlog.archive.md
#         Without --apply it REPORTS what would move and writes nothing.
# Exit:   0 report or apply succeeded; 1 nothing to do is NOT an error and still exits 0;
#         2 the ledger or the repo root could not be resolved, or --check found a difference.
set -uo pipefail

REPO_ROOT=""
d="$(cd "$(dirname "$0")" && pwd)"
while [ "$d" != "/" ]; do
  if [ -f "$d/VERSION" ]; then REPO_ROOT="$d"; break; fi
  d="$(dirname "$d")"
done
[ -n "$REPO_ROOT" ] || { echo "backlog-rotate: no VERSION marker above this script; repo root unknown" >&2; exit 2; }

LEDGER=""
ARCHIVE=""
APPLY=false
CHECK=false
while [ $# -gt 0 ]; do
  case "$1" in
    --apply)   APPLY=true; shift ;;
    --check)   CHECK=true; shift ;;
    --archive) ARCHIVE="${2:?--archive needs a path}"; shift 2 ;;
    -*)        echo "backlog-rotate: unknown option $1" >&2; exit 2 ;;
    *)         LEDGER="$1"; shift ;;
  esac
done
[ -n "$LEDGER" ] || LEDGER="$REPO_ROOT/docs/backlog.md"
[ -f "$LEDGER" ] || { echo "backlog-rotate: $LEDGER is not a file" >&2; exit 2; }
[ -n "$ARCHIVE" ] || ARCHIVE="$(dirname "$LEDGER")/backlog.archive.md"

LIB="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
[ -f "$LIB" ] || { echo "backlog-rotate: reconcile/lib.sh missing; refusing to use a private copy of the entry-boundary rule" >&2; exit 2; }
# shellcheck source=../core/skills/ai-dlc-update/reconcile/lib.sh
. "$LIB" || { echo "backlog-rotate: cannot source $LIB" >&2; exit 2; }

# --- REFUSE TO ROTATE A LEDGER THE BOUNDARY RULE CANNOT PARSE ----------------
# `ledger_entry_shape()` is fence-BLIND: it calls any `^#{2,6}[ \t]` or `^- \*\*` line an entry
# boundary, including one inside a fenced code block. So a closed entry whose body fences an
# entry-shaped line gets SPLIT MID-FENCE -- the archive takes the head and stops at the opening
# fence, leaving an UNTERMINATED fence and corrupt markdown, while the live file keeps the
# orphaned tail plus a phantom entry promoted out of the fence. Reproduced on a scratch ledger
# before this guard was written, and it is the same class the consumer filed as
# PC-S313-LEDGER-ROTATE-SPLITS-AN-ENTRY-AT-A-BOLD-ANNOTATION.
#
# THE GUARD IS A DETECTOR, NOT A PARSER FIX, AND THAT IS DELIBERATE. Making the shared boundary
# rule fence-aware is the real repair, but the OBVIOUS form of it is worse than the defect:
# measured on the reference consumer's 4356-line ledger, a plain `infence = !infence` toggle
# takes the entry-start count from 142 to 95 -- it silently drops 47 real entries. The cause is
# that the corpus carries 111 fence delimiters, an ODD number, because exactly ONE entry holds an
# unterminated fence; the toggle desynchronises there and never recovers. A fix that blinds the
# closer to a third of a ledger while reading as a bug fix is not available here, so the parser
# repair is scoped as its own remediation with its own fixture, and this file refuses the input it
# would corrupt instead of guessing at it.
#
# REFUSING IS THE CORRECT FAILURE. Everywhere else this repo prefers PENDING over FAIL, because a
# check that wedges live work gets switched off. Not here: the alternative to stopping is
# irreversible loss of the tail of a real entry, and the fix is a one-line edit to the offending
# ledger (indent the fenced line, or drop the `## ` from it). Cheap to satisfy, unrecoverable to
# skip.
#
# Pairs delimiters WITHIN the span the fence-blind rule already produces, never globally: global
# pairing is the same desync one level along, since one unterminated fence would re-pair every
# delimiter after it. An UNPAIRED delimiter is reported as corruption in its own right rather
# than absorbed, because damage and cleanliness are otherwise spelled identically.
#
# KEYED ON THE SPLIT PREDICATE, NOT ON `ledger_entry_shape()` ALONE, AND THE FIRST CUT GOT THIS
# WRONG. `ledger_entry_shape()` calls any `## <text>` line entry-shaped, but this file only SPLITS
# on one whose label matches `^BL-[0-9]+` after the marker is stripped. Guarding on shape alone
# refused a ledger containing a fenced `## Some prose heading` -- which the rotator handles
# perfectly -- and a backlog whose entries quote markdown carries those constantly. Measured
# false-positive set before this narrowing: non-empty and common; after it: empty over the near-miss
# battery (`#BL-9` with no space, an indented `  ## BL-9`, a mid-line `## BL-9`, and a non-BL
# heading all stay quiet while the real corrupting shape still fires). An unmeasured lint is one
# the operator turns off, which is worse than no lint.
#
# `backlog_entry_label()` is defined ONCE, below, and used by BOTH this guard and the split that
# follows. A guard keyed on a restatement of the predicate it protects drifts from it, and the
# drift is invisible until it either wedges a good ledger or passes a corrupting one.
BACKLOG_LABEL_AWK='
function backlog_entry_label(l,   line, shape) {
  shape = ledger_entry_shape(l)
  if (shape == "") return ""
  line = l
  if (shape == "heading") { sub(/^#{2,6}[ \t]+/, "", line) }
  else                    { sub(/^- \*\*/, "", line); sub(/\*\*.*$/, "", line) }
  if (match(line, /^BL-[0-9]+/)) return substr(line, 1, RLENGTH)
  return ""
}'
FENCE_FINDINGS="$(LC_ALL=C awk "$(ledger_entry_awk)$BACKLOG_LABEL_AWK"'
  function report(msg) { print msg }
  # A real entry start at depth 0 closes the previous span and resets, so an unterminated fence
  # cannot leak past it.
  {
    if (backlog_entry_label($0) != "" && depth == 0) {
      if (open_at) report("  unterminated fence opened at line " open_at " (entry starting line " entry_at ")")
      entry_at = NR; open_at = 0; depth = 0; next
    }
    if ($0 ~ /^[ \t]*(```|~~~)/) {
      if (depth == 0) { depth = 1; open_at = NR } else { depth = 0; open_at = 0 }
      next
    }
    if (depth == 1 && backlog_entry_label($0) != "")
      report("  line " NR ": entry-shaped line `" backlog_entry_label($0) "` inside the fence opened at line " open_at " -- rotation would split the entry starting at line " entry_at)
  }
  END { if (open_at) report("  unterminated fence opened at line " open_at " (entry starting line " entry_at ")") }
' "$LEDGER")"
if [ -n "$FENCE_FINDINGS" ]; then
  echo "backlog-rotate: REFUSING to rotate $LEDGER -- the entry-boundary rule cannot parse it safely." >&2
  printf '%s\n' "$FENCE_FINDINGS" >&2
  echo "  Rotating this file would archive the head of an entry and leave its tail behind, with an" >&2
  echo "  unterminated fence in the archive. Nothing was moved and nothing was written." >&2
  echo "  Fix the ledger, not this guard: indent the fenced line, or remove the leading '## ' / '- **'" >&2
  echo "  so it is not entry-shaped at column 0. See PC-S313 for the underlying parser defect." >&2
  exit 2
fi

# BUILT OUTSIDE A COMMAND SUBSTITUTION. bash is 3.2 and its `$( ... )` parser counts parens
# across heredoc bodies it should not be reading; the `\(v` below is a literal to awk and an
# unmatched open to that counter. Measured while writing backlog-reverify.sh: the shell
# swallowed the rest of the file and reported `unexpected EOF` a hundred lines later.
AWKF="$(mktemp)" || { echo "backlog-rotate: mktemp failed" >&2; exit 2; }
trap 'rm -f "$AWKF" "$AWKF.live" "$AWKF.moved"' EXIT

{ ledger_entry_awk; printf '%s\n' "$BACKLOG_LABEL_AWK"; cat <<'AWK'
# Emits the ledger split in two: LIVE lines to one file, CLOSED entries to another, with every
# byte accounted for. The preamble -- everything before the first id-shaped entry -- always
# stays live.
function flush(   i) {
  if (label == "") return
  if (closed) { for (i = 1; i <= n; i++) print buf[i] > MOVED; movedn++ }
  else        { for (i = 1; i <= n; i++) print buf[i] > LIVE }
  label = ""; closed = 0; n = 0
}
{
  # Via the shared helper, so the fence guard above and this split can never disagree about what
  # an entry is. They did not share it at first, and a guard keyed on its own copy of the
  # predicate is a guard that drifts from the thing it protects.
  lbl = backlog_entry_label($0)
  if (lbl != "") {
    flush()
    label = lbl
    buf[++n] = $0
    next
  }
  if (label == "") { print > LIVE; next }
  # STRICTER THAN backlog-reverify.sh's PREDICATE, ON PURPOSE. Rotate's closed-set must be a
  # strict SUBSET of reverify's, or the --check acceptance test below is comparing two readers
  # that share a defect and its agreement means nothing. Measured while writing this file: with
  # both predicates spelled `**LANDED (v` anywhere in the entry, an OPEN entry whose prose
  # QUOTED the annotation form while explaining it was swept into the archive AND --check
  # reported PASS, because reverify had mis-read the same line the same way.
  #
  # Two narrowings, each of which alone rejects that decoy:
  #   - the annotation must OPEN a line (a bare `<br>` prefix is allowed, since that is how the
  #     form is written in practice); a quotation of it sits mid-sentence.
  #   - the version must be NUMERIC; a quotation writes `(vX.Y.Z` or `(v<version>`.
  if ($0 ~ /^(<br>)?\*\*LANDED \(v[0-9]/) closed = 1
  buf[++n] = $0
}
END { flush(); print movedn+0 > "/dev/stderr" }
AWK
} > "$AWKF"

MOVED_COUNT="$(awk -v LIVE="$AWKF.live" -v MOVED="$AWKF.moved" -f "$AWKF" "$LEDGER" 2>&1 >/dev/null)"
MOVED_COUNT="${MOVED_COUNT:-0}"

if [ "$MOVED_COUNT" = "0" ]; then
  echo "backlog-rotate: no entry carries the annotation form '**LANDED (v' — nothing to move."
  echo "  (this is a normal state, not an error; a backlog with no closed entries rotates to itself)"
  exit 0
fi

echo "backlog-rotate: $MOVED_COUNT closed entr(y|ies) would move to $ARCHIVE"
# `[[:space:]]`, never `[ \t]` -- in a POSIX bracket expression the latter is the character SET
# backslash-and-t, not a tab, so it silently truncates any value ending in `t`. I71 fails the
# push on it, and it caught this line.
grep -E '^#{2,6}[[:space:]]+BL-[0-9]+|^- \*\*BL-[0-9]+' "$AWKF.moved" 2>/dev/null | sed 's/^/  /'

# CONSERVATION, ASSERTED ALWAYS AND INDEPENDENTLY OF EITHER PREDICATE. The two verdict-based
# checks can only catch a MISCLASSIFICATION; neither can see a line that fell out of both
# files. This one does not read the predicate at all -- it reads bytes -- so it survives any
# future change to what "closed" means.
ORIG_LINES="$(wc -l < "$LEDGER" | tr -d ' ')"
LIVE_LINES="$(wc -l < "$AWKF.live" 2>/dev/null | tr -d ' ')"; LIVE_LINES="${LIVE_LINES:-0}"
MOVE_LINES="$(wc -l < "$AWKF.moved" 2>/dev/null | tr -d ' ')"; MOVE_LINES="${MOVE_LINES:-0}"
if [ "$((LIVE_LINES + MOVE_LINES))" -ne "$ORIG_LINES" ]; then
  echo "backlog-rotate: REFUSING TO APPLY — the partition does not conserve the file: $ORIG_LINES lines in, $LIVE_LINES live + $MOVE_LINES moved = $((LIVE_LINES + MOVE_LINES)) out. A rotation that loses a line is the failure this tool exists to not have." >&2
  exit 2
fi

if [ "$CHECK" = true ]; then
  # THE ACCEPTANCE TEST. Compare reverify's verdict on the live remainder against its verdict on
  # the original, with the rows rotation is ENTITLED to remove filtered out. Any other
  # difference means a live entry was swept.
  BEFORE="$(bash "$REPO_ROOT/scripts/backlog-reverify.sh" "$LEDGER" | grep -v '^ALREADY-CLOSED')"
  AFTER="$(bash "$REPO_ROOT/scripts/backlog-reverify.sh" "$AWKF.live" | grep -v '^ALREADY-CLOSED')"
  if [ "$BEFORE" = "$AFTER" ]; then
    echo "  --check PASS: every non-closed verdict is byte-identical across the rotation."
  else
    echo "  --check FAIL: the live verdicts DIFFER across the rotation, so an entry that was not closed would be archived." >&2
    diff <(printf '%s\n' "$BEFORE") <(printf '%s\n' "$AFTER") >&2
    exit 2
  fi
fi

if [ "$APPLY" != true ]; then
  echo "  (report only; pass --apply to move them)"
  exit 0
fi

if [ ! -f "$ARCHIVE" ]; then
  {
    echo "# Carry-over backlog — archive"
    echo
    echo "Entries closed and rotated out of \`docs/backlog.md\` by \`scripts/backlog-rotate.sh\`."
    echo "Nothing here is deleted; this file is the destination, not a wastebasket."
    echo
  } > "$ARCHIVE"
fi
cat "$AWKF.moved" >> "$ARCHIVE"
cp "$AWKF.live" "$LEDGER"
echo "  applied: $MOVED_COUNT entr(y|ies) appended to $ARCHIVE and removed from $LEDGER"
exit 0
