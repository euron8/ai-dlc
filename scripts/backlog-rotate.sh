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
# closer to a third of a ledger while reading as a bug fix is not available here, so this file
# refuses the input it would corrupt instead of guessing at it.
#
# THE PARSER REPAIR HAS SINCE LANDED, IN THE BOUNDED FORM. `ledger_entry_shape()` in lib.sh now
# ignores a fenced entry-shaped line whose label is NOT id-keyed, and still opens an entry on
# one that IS -- so the desync above cannot recur IN lib.sh's rule, and neither can a hidden
# `## BL-…`. That is why this guard keys on the BL- label: the shape lib.sh ignores is exactly
# the one this guard never split on, and the shape it still opens is exactly the one this guard
# still refuses. THIS GUARD'S OWN `depth` TOGGLE BELOW IS STILL THE NAIVE FORM and disagrees
# with lib.sh on a fence quoting two `## BL-` headings: it then refuses a real top-level entry
# and its remedy text tells the operator to strip that entry's marker. BL-161 carries it.
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
# `backlog_entry_label()` is defined ONCE and used by BOTH this guard and the split that follows.
# A guard keyed on a restatement of the predicate it protects drifts from it, and the drift is
# invisible until it either wedges a good ledger or passes a corrupting one. It now lives in
# reconcile/lib.sh beside the boundary rule it calls, because a SECOND reader appeared --
# `validate-backlog-size.sh` -- and the first thing that reader did was restate it. That is the
# same drift this file's header warns about, one file over.
BACKLOG_LABEL_AWK="$(backlog_entry_label_awk)"
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

# ---------------------------------------------------------------------------------------------
# THE EVIDENCE GUARD -- an entry leaves this ledger only if its evidence holds.
#
# WHY IT EXISTS. The close predicate is a FORM, never a verification: `:192` matches
# `**LANDED (v[0-9]`, and `backlog-reverify.sh` reports any such entry ALREADY-CLOSED and NEVER
# RUNS ITS RECEIPT AGAIN. Nothing re-reads the archive either. So before this guard, appending
# ONE line to any entry moved it out of the ledger with a green verdict -- measured on this tree
# against `## BL-006`, an entry whose own first line reads "DO NOT CLOSE THIS ON ITS RECEIPT ...
# the defect is LIVE": `--check` reported PASS and `--apply` archived it, rc=0 both.
#
# WHY `--check` CANNOT CATCH IT AND THIS GUARD IS NOT SITED INSIDE EITHER BRANCH. The acceptance
# test below filters `^ALREADY-CLOSED` from BOTH sides, so a falsely-annotated entry is removed
# from the very comparison meant to police its removal. This block therefore runs BEFORE the
# `if CHECK` and `if APPLY` branches and all three entry points read the same variables: a guard
# inside `if APPLY` is bypassed by running `--check`, and one inside `if CHECK` by omitting it.
#
# IT TAKES TWO ARMS, AND THE RECEIPT ARM ALONE WOULD HAVE MISSED ITS OWN MOTIVATING CASE.
# Measured over all 56 live `sh` receipts: 1 exits 0, 54 exit 1, 1 exits 9. The single 0 is
# `BL-006` -- the entry the attack seeded -- because its receipt is genuinely green and wrong.
# A guard keyed only on "the receipt exits 0" PERMITS it. The sha arm is what refuses it, and
# `sha deadbeef DOES NOT RESOLVE` is the line that fires. Neither arm subsumes the other.
#
# THE POPULATION IS THE MOVED SET, NOT THE LEDGER. `$AWKF.moved` is the partition computed two
# blocks above -- it is not a join that can drift from the moved set, it IS the moved set. The
# whole-ledger engine costs 52-71s; verifying only what is leaving costs under a second, and it
# keeps the rotator's verdict independent of the 60-odd entries it is not touching.
#
# FALSE-POSITIVE SET, MEASURED ON THE DISCRIMINATING POPULATION. Today's ledger carries zero
# closed entries, so a clean run on it proves nothing. Re-presented to this guard, all 27 entries
# this repo has ever rotated, staged at each rotation's pre-rotation tree: 26 PERMIT, 1 REFUSE.
# The one is `BL-081`, a correct close whose receipt was never re-anchored because the close went
# through two verifiers rather than through the receipt. That is a genuine false positive and its
# remedy is a one-line edit the entry already contains. The SHA arm's false-positive set over the
# same 27 is EMPTY -- all 27 annotations name a resolving commit (control: `deadbeef` rc=128).
#
# `manual` IS PERMITTED, AND THE HOLE IS NAMED RATHER THAN PAPERED OVER. `verify: manual` is
# declared at FILING, by a different session than the one closing, before any ceiling pressure
# existed -- so it is not a closer granting themselves an exemption. 7 of 65 live entries declare
# it; refusing them would make 7 entries permanently unarchivable underneath the very bound they
# count against, which is a check that wedges live work. The residual attack is that a closer
# edits `verify: sh ...` down to `verify: manual` and then annotates. That is two lines instead
# of one and it is legible in the diff; no mechanism available to a tool that sees one tree and
# one ledger can separate it from a correct re-classification.
#
# EXIT 9 IS REFUSED. It means a precondition moved and the receipt measured nothing. No entry has
# ever been rotated on one: across all 27 rotations the codes are 25x0 and 1x1. `BL-076` is the
# corpus's own answer -- it was one of the two exit-9 entries and its receipt was RE-ANCHORED
# before its close, exiting 0 at the rotation commit and its parent. Refusing wedges an entry
# until someone edits one line; permitting loses the work it recorded.
#
# NOTE, not fixed here: an exit-9 refusal prints "still reproduces here", which is the wrong
# sentence for a receipt that measured nothing. The refusal is right; the wording belongs to the
# live entry that owns the exit-9/exit-1 conflation.
# ---------------------------------------------------------------------------------------------
MOVED_ANN="$(LC_ALL=C awk "$(ledger_entry_awk)$BACKLOG_LABEL_AWK"'
  function flush() { if (label != "") printf "%s\t%s\n", label, ann; label = ""; ann = "" }
  {
    lbl = backlog_entry_label($0)
    if (lbl != "") { flush(); label = lbl; next }
    if (label != "" && ann == "" && $0 ~ /^(<br>)?\*\*LANDED \(v[0-9]/) ann = $0
  }
  END { flush() }
' "$AWKF.moved")"

# The sha arm SKIPS rather than refuses outside a git repository, because refusing there would
# wedge every scratch ledger, including the ones core/fixtures/backlog-ledger builds.
R1_SKIP=false
if ! git -C "$(dirname "$LEDGER")" rev-parse --git-dir >/dev/null 2>&1; then R1_SKIP=true; fi

EVID_ROWS="$(bash "$REPO_ROOT/scripts/backlog-reverify.sh" --closed-receipts "$AWKF.moved" 2>/dev/null)"

# EVERY DISPATCHED ENTRY MUST PRODUCE A VERDICT, ASSERTED AS A SET AND NOT AS A COUNT. An engine
# that answers for no entry and an engine that finds nothing wrong are the same silence; and
# `INPUT-UNRESOLVED` emits exactly one row whose label is a PATH, which a count check would
# happily accept against a single moved entry.
WANT_LABELS="$(printf '%s\n' "$MOVED_ANN"  | cut -f1 | grep -v '^$' | sort)"
GOT_LABELS="$(printf  '%s\n' "$EVID_ROWS" | cut -f2 | grep -v '^$' | sort)"
if [ "$WANT_LABELS" != "$GOT_LABELS" ]; then
  echo "backlog-rotate: REFUSING TO APPLY — the receipt engine did not return a verdict for every entry being moved." >&2
  echo "  dispatched $MOVED_COUNT entr(y|ies); backlog-reverify.sh answered for a DIFFERENT set." >&2
  diff <(printf '%s\n' "$WANT_LABELS") <(printf '%s\n' "$GOT_LABELS") >&2
  echo "  An engine that answers for no entry and an engine that finds nothing wrong are the same" >&2
  echo "  zero, so this is refused rather than passed over. Nothing was moved and nothing was written." >&2
  exit 2
fi

EVID_TABLE=""; EVID_REFUSE=""; OLDIFS="$IFS"
while IFS="$(printf '\t')" read -r ST LB DT; do
  [ -n "$LB" ] || continue
  ANN="$(printf '%s\n' "$MOVED_ANN" | awk -F'\t' -v l="$LB" '$1==l{print $2; exit}')"
  SHA="$(printf '%s\n' "$ANN" | sed -n 's/.*verified \([0-9a-f][0-9a-f]*\).*/\1/p')"
  if   [ "$R1_SKIP" = true ]; then SHAV="sha SKIPPED (ledger is not in a git repository)"
  elif [ -z "$SHA" ];          then SHAV="sha ABSENT"
  elif git -C "$(dirname "$LEDGER")" cat-file -e "${SHA}^{commit}" 2>/dev/null; then SHAV="sha $SHA resolves"
  else SHAV="sha $SHA DOES NOT RESOLVE"; fi
  EVID_TABLE="$EVID_TABLE  $LB  $ST  [$SHAV]
"
  case "$ST" in
    CLOSE-CANDIDATE|HAND-REVIEW) : ;;
    *) EVID_REFUSE="$EVID_REFUSE  $LB  $ST — $DT
" ;;
  esac
  case "$SHAV" in
    *"DOES NOT RESOLVE"|*ABSENT)
      EVID_REFUSE="$EVID_REFUSE  $LB  the annotation's $SHAV, so it attests to no commit in this repository.
" ;;
  esac
done <<EOF
$EVID_ROWS
EOF
IFS="$OLDIFS"

echo "  receipt verdicts for the entries being moved:"
printf '%s' "$EVID_TABLE"

if [ -n "$EVID_REFUSE" ]; then
  echo "backlog-rotate: REFUSING TO MOVE — an entry is annotated LANDED but its evidence does not hold." >&2
  printf '%s' "$EVID_REFUSE" >&2
  echo "  The annotation is a FORM, not a verification. Re-anchor the entry's 'verify:' receipt so it" >&2
  echo "  exits 0 against this tree, or correct the sha the annotation names, and run this again." >&2
  echo "  Do NOT weaken this guard to move the entry: it moves, it never deletes, and an entry" >&2
  echo "  wrongly kept costs one more read while one wrongly archived costs the work it recorded." >&2
  echo "  Nothing was moved and nothing was written." >&2
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
