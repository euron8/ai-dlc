#!/usr/bin/env bash
#
# AI/DLC Snapshot-History Rotator
#
# Moves the older part of `pipeline-snapshot-history.md` into ONE append-only archive, so the
# live history stays small enough that reading it by accident is survivable.
#
# WHY THIS EXISTS, AND WHY IT OVERRIDES RULE 25(a). Rule 25(a) says history files are write-only
# and "their growth is free", and `is_archive()` in validate-artifact-budget.sh skips every
# `*-history.md` BEFORE measuring it. That holds for a history fed at a sprint boundary. It does
# not hold for this one: the snapshot trim fires per GATE (route.md Step 1a, _gate-procedures.md,
# gate-validation.md Check 14), so this file accretes all sprint with nothing bounding it.
# Measured on the reference consumer: 87 KB on 2026-07-13, 617 KB on 2026-08-11, 29 commits,
# every one of them del=0. Nothing was wrong with the file. Nothing was watching it either.
#
# THE COST IS NOT BYTES, AND SAYING SO MATTERS BECAUSE THE BYTE ARGUMENT IS AVAILABLE AND WRONG.
# Check 35's corpus is every tracked *.md in the working tree -- 94.6 MB, 758k distinct lines on
# the reference consumer -- and it runs in under 4s. This file is 0.8% of that. Rotating it saves
# no measurable time. What it saves is the READ: `ai-dlc-protect.sh` lists `*-history.md` in
# EXCLUDED_PATTERNS, so a whole Read of 617 KB (~154k tokens) is EXPLICITLY ALLOWED. The file's
# own H1 says "never whole-read" and nothing enforces it. Rotation is the enforcement.
#
# THE ONE THING THAT CAN GO WRONG, MEASURED RATHER THAN IMAGINED. Check 35 asks whether lines
# removed from the snapshot still exist ANYWHERE in the tracked markdown corpus. On the reference
# consumer, with 89 candidate lines and a floor of 40:
#
#     destroyed, baseline                        : 17   PASS
#     destroyed if this history file vanished    : 79   FAIL -- 62 candidates live ONLY here
#     destroyed if all 158 dated archives vanish : 17   unchanged
#
# So the archive is not a filing cabinet, it is load-bearing evidence, and the margin is 23 lines.
# A rotation whose destination is outside the corpus does not shrink a file, it destroys 62 lines
# of gate provenance. `git ls-files` is what defines the corpus, so the destination must be
# TRACKABLE: this script REFUSES to truncate when the archive path is git-ignored, and stages the
# archive itself on apply. Writing the bytes is not the move; being in the corpus is the move.
#
# WHY THERE IS NO ENTRY PARSER, WHICH IS THE PART THAT LOOKS UNDER-BUILT AND IS NOT.
# `ledger-rotate.sh` classifies entries because its predicate is semantic (a CLOSED entry moves).
# Here the predicate is positional -- old moves -- so classification buys nothing and costs
# correctness. Measured on the reference consumer's live file: 163 lines match `^## `, and they
# are NOT 163 entries. An archived snapshot is pasted in verbatim and brings its own seven
# section headings with it (`## Pipeline Position`, `## Sprint Context`, `## Recent Activity`,
# `## Open Items`, `## Locked Decisions`, `## In-Flight Teammates`, `## Context Reminders`), so
# the entry at line 3800 owns the eight `## ` lines that follow it. One line (`## Deploy Baseline`
# via a hardcoded shell `case`) is a sentence that merely starts that way. A rotator that treated
# each `^## ` as an entry would shred archived snapshots into fragments and file them separately.
#
# So this picks ONE CUT POINT and never interprets a heading: the Nth-from-last `^## ` line.
# Everything between the preamble and the cut moves; the preamble and everything from the cut
# onward stay. A miscounted heading shifts the window by one entry and can never corrupt the
# split, because the split is a line index. Conservation is arithmetic, not judgement.
#
# THE PREAMBLE ALWAYS STAYS. Lines before the first `^## ` are the file's H1 and its "write-only"
# note. Moving them would leave a live file with no header, which the next trim would recreate by
# hand, differently.
#
# Usage:
#   rotate-snapshot-archive.sh <history-path> [options]
#     --apply              write; default is a report that changes nothing
#     --archive PATH       default: <history-dir>/pipeline-history/pipeline-snapshot-archive.md
#     --keep-entries N     boundaries to keep live (default 10, mirroring the snapshot's own
#                          "Recent Activity holds the last ~10 entries")
#     --absorb PATH        additionally fold a stale pipeline-snapshot.md into the same archive
#                          and delete it. This is route.md's fresh-start archival, which used to
#                          mint `pipeline-snapshot.archive.<ISO>.md` -- 158 such files on the
#                          reference consumer, in five different timestamp spellings, none of
#                          them matched by is_archive(). One archive, one writer, no new file.
#
# Exit: 0 = reported or rotated (nothing to rotate is a normal, affirmative result)
#       1 = REFUSED: an integrity check failed and NOTHING was written
#       2 = usage
set -uo pipefail

SELF_NAME="rotate-snapshot-archive"

usage() {
  echo "usage: rotate-snapshot-archive.sh <history-path> [--apply] [--archive <path>] [--keep-entries <N>] [--absorb <path>]" >&2
  exit 2
}

HISTORY="${1:-}"
[ -n "$HISTORY" ] || usage
case "$HISTORY" in --*) usage ;; esac
shift

# Absent is not an error. The first trim of a fresh project creates this file; a rotator that
# exits non-zero before it exists would fail the very step that is about to create it.
[ -f "$HISTORY" ] || {
  echo "${SELF_NAME}: no history at '${HISTORY}' -- nothing to rotate."
  exit 0
}

APPLY=0
KEEP_ENTRIES=10
ABSORB=""
ARCHIVE="$(dirname "$HISTORY")/pipeline-history/pipeline-snapshot-archive.md"

while [ $# -gt 0 ]; do
  case "$1" in
    --apply)         APPLY=1; shift ;;
    --archive)       ARCHIVE="${2:?--archive needs a path}"; shift 2 ;;
    --keep-entries)  KEEP_ENTRIES="${2:?--keep-entries needs a number}"; shift 2 ;;
    --absorb)        ABSORB="${2:?--absorb needs a path}"; shift 2 ;;
    *) echo "${SELF_NAME}: unknown argument '$1'" >&2; usage ;;
  esac
done

case "$KEEP_ENTRIES" in
  ''|*[!0-9]*) echo "${SELF_NAME}: --keep-entries must be a non-negative integer, got '${KEEP_ENTRIES}'" >&2; exit 2 ;;
esac

if [ -n "$ABSORB" ] && [ ! -f "$ABSORB" ]; then
  echo "${SELF_NAME}: --absorb names no file: '${ABSORB}'" >&2
  exit 2
fi

TMPD="$(mktemp -d "${TMPDIR:-/tmp}/aidlc-snaprotate.XXXXXX")" || {
  echo "${SELF_NAME}: mktemp failed" >&2; exit 1; }
trap 'rm -rf "$TMPD"' EXIT

L_ALL="$(wc -l < "$HISTORY" | tr -d ' ')"

# ---------------------------------------------------------------------------
# The cut point.
#
# PREAMBLE_END  = last line before the first `^## `  (0 when the file starts with one)
# CUT           = line number of the Nth-from-last `^## `
#
# grep -n gives both without reading the file into awk twice, and an empty result is
# distinguishable from a zero because the count is taken from the same list.
# ---------------------------------------------------------------------------
grep -n '^## ' "$HISTORY" > "$TMPD/boundaries" 2>/dev/null || true
N_BOUND="$(grep -c . "$TMPD/boundaries")"

# NOT EVERY `^## ` IS A PLACE IT IS SAFE TO CUT, and the difference is measured rather than
# guessed. An entry that archives a whole snapshot pastes it in verbatim, so it carries the
# seven schema section headings INSIDE itself -- eight `^## ` lines belonging to one entry. A
# cut landing among them tears the archived snapshot across the two files. Conservation still
# holds (the split is a line index and every line lands somewhere), so nothing would ever
# report it; the archive would just quietly stop being readable.
#
# The fix is not an entry parser. It is: do not CUT at a heading that is one of the seven.
# The set is closed and already defined by gate-validation.md Check 14 and enforced by
# validate-artifact-budget.sh -- it is looked up, not invented here.
#
# WHAT THIS DELIBERATELY DOES NOT FIX: a line of prose that merely begins `## `, of which the
# reference consumer has one (`## Deploy Baseline` quoted inside a remedy sentence). Cutting
# there costs one orphaned line, not a torn snapshot, and telling prose from a heading needs
# exactly the parser this design exists to avoid. Stated rather than silently tolerated.
grep -vE '^[0-9]+:## (Pipeline Position|Sprint Context|Recent Activity|Open Items|Locked Decisions|In-Flight Teammates|Context Reminders)[[:space:]]*$' \
  "$TMPD/boundaries" > "$TMPD/cutpoints" || true
N_CUT="$(grep -c . "$TMPD/cutpoints")"

# If filtering left nothing, every boundary in the file is a schema section name and the
# unfiltered list is the only thing to work with. Falling back is right here: a worse cut point
# beats refusing to bound a file that is growing for real.
if [ "$N_CUT" -eq 0 ]; then
  cp "$TMPD/boundaries" "$TMPD/cutpoints"
  N_CUT="$N_BOUND"
fi

# REFUSAL 1: a non-empty body with no boundary at all.
#
# Without this the split degenerates to "everything is preamble, nothing moves" and the script
# prints a clean nothing-to-rotate line -- indistinguishable from a genuinely short history. A
# zero that means "the parser found nothing" reads exactly like a zero that means "there is
# nothing to find", and only one of them is true.
if [ "$N_BOUND" -eq 0 ] && [ "$L_ALL" -gt 0 ]; then
  echo "${SELF_NAME}: REFUSED -- '${HISTORY}' has ${L_ALL} lines and not one '## ' heading, so there is no cut point." >&2
  echo "  This is reported rather than treated as 'nothing to rotate', because those two look identical" >&2
  echo "  from the outside and only one of them is safe. Nothing written." >&2
  exit 1
fi

FIRST_BOUND="$(head -1 "$TMPD/boundaries" | cut -d: -f1)"
PREAMBLE_END=$(( FIRST_BOUND - 1 ))

# REFUSAL 2: at the fixed point WITH unheaded move markers in the body.
#
# REFUSAL 1 above catches zero boundaries. It is a knife-edge: ONE surviving `^## ` sends the
# file here instead, where `N_CUT <= KEEP_ENTRIES` prints an affirmative line and exits 0 --
# and that is the state a real history reaches, because every rotation KEEPS `KEEP_ENTRIES`
# headings. Measured on the reference consumer: eight rounds of trims, the file rotates ONCE,
# lands on exactly 10 headings, then grows +112 lines per round forever while this line reports
# "nothing to rotate". 122514 bytes against 8821 for the same content correctly headed -- and
# both arms print `10 entr(ies) present`, exit 0. The verdict cannot tell them apart.
#
# The discriminator is not a size threshold, and a size threshold was measured and REJECTED:
# max-span-over-mean scores the defect case at 4.40 while five healthy files in the same tree
# score higher (prd-history.md at 131.53), so any cut separating them flags the healthy corpus.
#
# What separates them is a property of the file alone: a MOVE MARKER that is not a heading.
# Those blocks cannot be cut apart, so at the fixed point they are why nothing moves. Measured
# false-positive set over the reference consumer's 109 tracked `-history`/`-archive` files:
# ONE hit, the defect case itself. Zero false positives.
#
# It refuses rather than warns because "nothing to rotate" and "cannot rotate" look identical
# from the outside and only one of them is safe -- the same reason REFUSAL 1 exists, one branch
# over. Rule 25(a) states the heading a moved block carries.
if [ "$N_CUT" -le "$KEEP_ENTRIES" ]; then
  N_UNHEADED="$(grep -cE '^\[MOVED|^[[:space:]]+\[MOVED' "$HISTORY")" || N_UNHEADED=0
  if [ "$N_UNHEADED" -gt 0 ]; then
    echo "${SELF_NAME}: REFUSED -- '${HISTORY}' is at its cut floor (${N_CUT} entr(ies), keeping ${KEEP_ENTRIES}) and carries ${N_UNHEADED} move marker(s) that are not \`## \` headings, so those blocks can never be cut apart and this file cannot be bounded." >&2
    echo "  Reported rather than treated as 'nothing to rotate': a file that is merely short and one that is growing without a cut point print the same line otherwise." >&2
    echo "  Remedy: head each moved block per Rule 25(a) -- '## [MOVED <ISO-8601 timestamp> from <source basename> — <trigger>]'. Nothing written." >&2
    exit 1
  fi
  echo "${SELF_NAME}: ${N_CUT} entr(ies) present, keeping ${KEEP_ENTRIES} -- nothing to rotate (${L_ALL} lines stay)."
  exit 0
fi

CUT="$(tail -n "$KEEP_ENTRIES" "$TMPD/cutpoints" | head -1 | cut -d: -f1)"

# ---------------------------------------------------------------------------
# Split. Three parts, and every line of the file is in exactly one of them.
# ---------------------------------------------------------------------------
sed -n "1,${PREAMBLE_END}p"        "$HISTORY" > "$TMPD/preamble"
sed -n "$((PREAMBLE_END + 1)),$((CUT - 1))p" "$HISTORY" > "$TMPD/move"
sed -n "${CUT},\$p"                "$HISTORY" > "$TMPD/tail"

L_PRE="$(wc -l < "$TMPD/preamble" | tr -d ' ')"
L_MOVE="$(wc -l < "$TMPD/move" | tr -d ' ')"
L_TAIL="$(wc -l < "$TMPD/tail" | tr -d ' ')"

# REFUSAL 2: line accounting. A rotation that drops a line is worse than no rotation, so this
# refuses rather than reports. Lifted from ledger-rotate.sh's identical invariant.
if [ "$(( L_PRE + L_MOVE + L_TAIL ))" -ne "$L_ALL" ]; then
  echo "${SELF_NAME}: REFUSED -- line accounting does not balance (${L_PRE} preamble + ${L_MOVE} moved + ${L_TAIL} kept != ${L_ALL} total). Nothing written." >&2
  exit 1
fi

if [ "$L_MOVE" -eq 0 ]; then
  echo "${SELF_NAME}: 0 lines older than the last ${KEEP_ENTRIES} entr(ies) -- nothing to rotate (${L_ALL} lines stay)."
  exit 0
fi

N_MOVE=$(( N_CUT - KEEP_ENTRIES ))
B_MOVE="$(wc -c < "$TMPD/move" | tr -d ' ')"

# ---------------------------------------------------------------------------
# REFUSAL 3: the destination must be able to enter Check 35's corpus.
#
# This is the refusal the measurement bought, and it is the reason this script is not three lines
# of `cat`. The corpus is `git ls-files -z -- '*.md' | xargs -0 cat`: a path that git ignores is
# never listed, so its bytes are not in the corpus no matter what is on disk. Truncating the live
# file into an ignored archive is not a move, it is a deletion with extra steps -- and it scores
# on the reference consumer as 62 additional destroyed lines against a floor of 40.
#
# Checked BEFORE anything is written, and only when git can answer. Outside a work tree there is
# no corpus to fall out of, so there is nothing to refuse.
# ---------------------------------------------------------------------------
ARCHIVE_DIR="$(dirname "$ARCHIVE")"
IN_GIT=0
if git -C "$ARCHIVE_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
   git -C "$(dirname "$HISTORY")" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  IN_GIT=1
fi

if [ "$IN_GIT" -eq 1 ]; then
  GITROOT="$(git -C "$(dirname "$HISTORY")" rev-parse --show-toplevel 2>/dev/null)"
  if [ -n "$GITROOT" ] && git -C "$GITROOT" check-ignore -q "$ARCHIVE" 2>/dev/null; then
    echo "${SELF_NAME}: REFUSED -- the archive path is git-ignored: ${ARCHIVE}" >&2
    echo "  Check 35 (validate-snapshot-conservation.sh) builds its corpus from 'git ls-files -- *.md'," >&2
    echo "  so an ignored destination holds bytes that the conservation check cannot see. Moving the" >&2
    echo "  live history there would score every relocated line as DESTROYED. Nothing written." >&2
    echo "  Un-ignore the path, or pass --archive with one that is tracked." >&2
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# Report-only (the default).
# ---------------------------------------------------------------------------
if [ "$APPLY" -eq 0 ]; then
  echo "${SELF_NAME}: ${N_MOVE} of ${N_CUT} entr(ies) would move -- ${L_MOVE} of ${L_ALL} lines (${B_MOVE} bytes),"
  echo "  leaving ${L_PRE} preamble + ${L_TAIL} live."
  echo "  archive: ${ARCHIVE}"
  [ -n "$ABSORB" ] && echo "  absorb : ${ABSORB} (folded into the same archive, then removed)"
  echo "  re-run with --apply to write. Verify after: validate-snapshot-conservation.sh must report"
  echo "  the same verdict it reported before."
  exit 0
fi

# ---------------------------------------------------------------------------
# Apply. Append to the archive FIRST, shrink the live file LAST, so no instant exists in which
# the bytes are in neither file. Measured why this ordering is not cosmetic: truncating a tracked
# file drops its content from the corpus the moment it hits disk, even though the index still
# holds the old blob -- staging does not protect content, presence on disk does.
# ---------------------------------------------------------------------------
mkdir -p "$ARCHIVE_DIR" || {
  echo "${SELF_NAME}: cannot create ${ARCHIVE_DIR}. Nothing written." >&2; exit 1; }

if [ ! -s "$ARCHIVE" ]; then
  {
    echo "# Pipeline snapshot — archive"
    echo
    echo "Superseded snapshot narrative, rotated out of \`pipeline-snapshot-history.md\` by"
    echo "\`scripts/ai-dlc/rotate-snapshot-archive.sh\`, plus whole snapshots absorbed at a"
    echo "fresh start. ONE file, appended forever, never rewritten."
    echo
    echo "This is provenance, and it is load-bearing: Check 35"
    echo "(\`validate-snapshot-conservation.sh\`) reads every tracked markdown file in the"
    echo "working tree to decide whether content evicted from the snapshot still exists."
    echo "Lines in here are the evidence that a trim was a MOVE and not a deletion. Do not"
    echo "delete it, do not gitignore it, and do not hand-edit an entry back into the live"
    echo "history — the rotator is the only writer."
    echo
  } > "$ARCHIVE"
fi

{
  echo ""
  echo "<!-- rotated from $(basename "$HISTORY"): ${L_MOVE} lines, ${N_MOVE} entries -->"
  echo ""
} >> "$ARCHIVE"
cat "$TMPD/move" >> "$ARCHIVE"

ABSORB_NOTE=""
if [ -n "$ABSORB" ]; then
  A_LINES="$(wc -l < "$ABSORB" | tr -d ' ')"
  {
    echo ""
    echo "<!-- absorbed whole snapshot from $(basename "$ABSORB") at fresh start: ${A_LINES} lines -->"
    echo ""
  } >> "$ARCHIVE"
  cat "$ABSORB" >> "$ARCHIVE"
  ABSORB_NOTE=" absorbed ${ABSORB} (${A_LINES} lines);"
fi

cat "$TMPD/preamble" "$TMPD/tail" > "$HISTORY"

# The move is not complete until the destination is in the corpus. Staging here rather than
# leaving it to the caller is deliberate: the caller who forgets is exactly the failure REFUSAL 3
# exists to prevent, and an unstaged new file contributes nothing to `git ls-files`.
if [ "$IN_GIT" -eq 1 ] && [ -n "${GITROOT:-}" ]; then
  git -C "$GITROOT" add -- "$ARCHIVE" >/dev/null 2>&1 || {
    echo "${SELF_NAME}: WARNING -- could not stage ${ARCHIVE}." >&2
    echo "  Until it is tracked, Check 35 cannot see the ${L_MOVE} lines just moved into it." >&2
    echo "  Run: git add -- ${ARCHIVE}" >&2
  }
  [ -n "$ABSORB" ] && git -C "$GITROOT" rm -q -- "$ABSORB" >/dev/null 2>&1
fi
[ -n "$ABSORB" ] && [ -f "$ABSORB" ] && rm -f "$ABSORB"

echo "${SELF_NAME}: moved ${N_MOVE} entr(ies), ${L_MOVE} lines (${B_MOVE} bytes) to ${ARCHIVE};${ABSORB_NOTE} history is now $(wc -l < "$HISTORY" | tr -d ' ') lines."
echo "  Verify: validate-snapshot-conservation.sh must report the same verdict as before this ran."
exit 0
