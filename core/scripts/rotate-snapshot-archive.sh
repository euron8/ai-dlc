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
#                          and TRUNCATE it to 0 bytes. This is route.md's fresh-start archival,
#                          which used to mint `pipeline-snapshot.archive.<ISO>.md` -- 158 such
#                          files on the reference consumer, in five different timestamp
#                          spellings, none of them matched by is_archive(). One archive, one
#                          writer, no new file.
#
# --absorb TRUNCATES, IT NEVER REMOVES. Every control hook keys "a pipeline is active" on the
# snapshot's EXISTENCE (`[ -f ]`: ai-dlc-continue.sh's stall check, ai-dlc-pause.sh's pause flag,
# Rule 29's deny, compaction recovery). The fresh start is two acts -- this call, then the lead
# writing the new snapshot -- and a turn can end between them. A removed snapshot turns every one
# of those hooks off for that window; an emptied one keeps them firing. So the file exists at
# every instant, and route.md Step 0 already routes an EMPTY snapshot away from resume.
#
# --absorb RUNS ON EVERY PATH THAT IS NOT A REFUSAL: no history file yet, a history at or below
# its cut floor, and a real rotation. It used to run only on the last, so on a fresh consumer (no
# history) or a history sitting at exactly --keep-entries cut points it was a silent exit-0 no-op,
# and the lead's next write destroyed the stale snapshot unarchived. The ignored-archive refusal
# and the archive staging apply to the absorb on every one of those paths. An absorb of a snapshot
# that is ALREADY EMPTY writes nothing, so a re-run after an interrupted swap appends no empty block.
#
# Every argument is parsed before any exit, so an unknown option or an --absorb naming no file is
# exit 2 on every path, including the no-history one.
#
# Exit: 0 = reported or rotated (nothing to rotate is a normal, affirmative result). With --apply,
#           an existing archive is staged on every exit-0 path, not only after a rotation.
#       1 = REFUSED: an integrity check or a write failed.
#           On exit 1 the history is byte-identical to before, EXCEPT in exactly one case: the
#           history rename succeeded and the snapshot truncate then failed (read-only snapshot).
#           There the history is the new, complete history and the archive holds the moved block
#           and the snapshot; re-running after making the snapshot writable appends the snapshot
#           again. The snapshot is never emptied without having been archived. The archive may
#           carry a duplicate block after any exit 1.
#           Refused BEFORE anything is written, so these leave every file as it was: a history
#           that is a symlink, has more than one hard link, is not writable, or sits in a
#           directory that is not writable (or is sticky and owned by someone else); and any
#           failure while building the new history beside it (the temp copy is removed).
#       2 = usage
#
# THE HISTORY IS REPLACED BY AN ATOMIC RENAME, AND NOTHING EVER WRITES INTO IT. The new history is
# built in a fresh `mktemp` file in the history's own directory (same filesystem, so `mv` is a
# rename), verified by status and size, and renamed over the history. So the history is at every
# instant either the complete old file or the complete new one. The in-place write-back this
# replaces existed only to keep symlinks, hard links and the mode; every recovery text it needed
# (a kept temp copy, a prefix test, a listing command) existed only because an interrupted
# in-place write leaves the history partial. None of that has a subject any more.
#   - A SYMLINKED history is REFUSED, not followed. Rotating through the link is the behaviour a
#     rename breaks (the link becomes a regular file and its target is orphaned); refusing is the
#     fix by subtraction. A history with more than one hard link is refused for the same reason
#     (the rename would split it from its peer).
#   - The mode is kept by `cp -p` onto the temp file before the new content is written into it.
#     The OWNER is kept only where the user may set it: `cp -p` run by a user who does not own the
#     history silently gives the temp file (and so the new history) that user's ownership, rc 0,
#     on BSD and GNU alike. The in-place write it replaces kept the owner.
#   - A run killed with SIGKILL at any point loses no line, and a plain re-run exits 0. It may
#     leave a stray `.<history basename>.rotate.XXXXXX` beside the history. The history was never
#     written through it, so it is SAFE TO DELETE; no later run reads it or refuses on it, and it
#     is outside the `*.md` corpus Check 35 reads.
#   - A kill between the rename and the snapshot truncate leaves the archive unstaged; the re-run
#     lands on "nothing to rotate", stages it, and absorbs the snapshot again (a duplicate block).
#   - ONE RUN ASSUMES NO CONCURRENT WRITER TO THE HISTORY. A writer holding it open with `>>`
#     across a rotation writes into the replaced inode and its lines are lost; a trim appending
#     between this run's read and its rename is lost too (as it was under the in-place design).
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

ARCHIVE_DIR="$(dirname "$ARCHIVE")"
IN_GIT=0
GITROOT=""

# ---------------------------------------------------------------------------
# REFUSAL 3: the destination must be able to enter Check 35's corpus.
#
# This is the refusal the measurement bought, and it is the reason this script is not three lines
# of `cat`. The corpus is `git ls-files -z -- '*.md' | xargs -0 cat`: a path that git ignores is
# never listed, so its bytes are not in the corpus no matter what is on disk. Truncating the live
# file into an ignored archive is not a move, it is a deletion with extra steps -- and it scores
# on the reference consumer as 62 additional destroyed lines against a floor of 40.
#
# Checked BEFORE anything is written, on every path that writes (rotation or absorb), and only
# when git can answer. Outside a work tree there is no corpus to fall out of, so there is nothing
# to refuse. The work tree is resolved from the first of the history's directory, the archive's
# directory and the absorbed file's directory that exists: on a fresh project the history file,
# and possibly the archive directory, do not exist yet.
# ---------------------------------------------------------------------------
resolve_git() {
  local d
  [ "$IN_GIT" -eq 1 ] && return 0
  for d in "$(dirname "$HISTORY")" "$ARCHIVE_DIR" ${ABSORB:+"$(dirname "$ABSORB")"}; do
    [ -d "$d" ] || continue
    if git -C "$d" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      IN_GIT=1
      GITROOT="$(git -C "$d" rev-parse --show-toplevel 2>/dev/null)"
      break
    fi
  done
  return 0
}
refuse_if_archive_ignored() {
  resolve_git
  if [ "$IN_GIT" -eq 1 ] && [ -n "$GITROOT" ] && git -C "$GITROOT" check-ignore -q "$ARCHIVE" 2>/dev/null; then
    echo "${SELF_NAME}: REFUSED -- the archive path is git-ignored: ${ARCHIVE}" >&2
    echo "  Check 35 (validate-snapshot-conservation.sh) builds its corpus from 'git ls-files -- *.md'," >&2
    echo "  so an ignored destination holds bytes that the conservation check cannot see. Moving the" >&2
    echo "  live history or the absorbed snapshot there would score every relocated line as DESTROYED." >&2
    echo "  Nothing written. Un-ignore the path, or pass --archive with one that is tracked." >&2
    exit 1
  fi
}

ensure_archive() {
  mkdir -p "$ARCHIVE_DIR" || {
    [ -n "${HIST_NEW:-}" ] && rm -f "$HIST_NEW"
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
    } > "$ARCHIVE" || archive_fail "the header block could not be written"
  fi
}

# EVERY WRITE TO THE ARCHIVE IS CHECKED, AND A FAILED ONE STOPS THE RUN BEFORE ANYTHING SHRINKS.
# The callers truncate the snapshot and rewrite the history AFTER appending, so an unchecked
# append turns an unwritable archive (a read-only file, a read-only directory, a directory at the
# archive path) into an exit-0 run that empties the snapshot and shrinks the history with their
# bytes in no file. That is the one failure this script exists to make impossible.
#
# A partial append is caught by size, not by exit status alone: a `{ printf; cat; }` group answers
# with its LAST command, so a failed header followed by a successful body reads as success. The
# archive must grow by exactly the header plus the body. A partial block left behind by a refusal
# is not rolled back: the archive is append-only, the bytes are duplicates of content still in the
# live files, and a rollback would be a second write that can fail the same way.
archive_fail() {
  [ -n "${HIST_NEW:-}" ] && rm -f "$HIST_NEW"
  echo "${SELF_NAME}: REFUSED -- could not append to the archive ${ARCHIVE}: $1." >&2
  echo "  Nothing was truncated: the history${ABSORB:+ and ${ABSORB}} are unchanged. Make the archive a writable regular file and re-run." >&2
  exit 1
}

# archive_append HEADER BODY-FILE: append HEADER then the file's bytes, verified by growth.
archive_append() {
  local hdr="$1" body="$2" before after b_hdr b_body
  [ -f "$ARCHIVE" ] || archive_fail "it is not a regular file"
  before="$(wc -c < "$ARCHIVE")" || archive_fail "its size cannot be read"
  b_body="$(wc -c < "$body")" || archive_fail "the source ${body} cannot be read"
  b_hdr="$(printf '%s' "$hdr" | wc -c)" || archive_fail "the header size cannot be measured"
  { printf '%s' "$hdr"; cat "$body"; } >> "$ARCHIVE" || archive_fail "the write failed"
  after="$(wc -c < "$ARCHIVE")" || archive_fail "its size cannot be re-read"
  before="${before// /}"; after="${after// /}"; b_hdr="${b_hdr// /}"; b_body="${b_body// /}"
  # FAIL CLOSED. When the builtin `printf` fails (EFBIG, ENOSPC), bash keeps the unwritten bytes in
  # its stdout buffer and the NEXT command substitution's child flushes them into its own output,
  # so `after` can come back as "8192<!-- rotated from ...". `[ x -ne y ]` on that is an ERROR
  # (status 2), which an `if` reads exactly like "the sizes match". Measured: with the write-status
  # check deleted, a full archive made this comparison error out, the run went on, and exited 0.
  # So every operand is proven numeric, and the comparison refuses unless it positively holds.
  case "${before}${after}${b_hdr}${b_body}" in ''|*[!0-9]*) archive_fail "a size read back as non-numeric" ;; esac
  if ! [ "$after" -eq "$(( before + b_hdr + b_body ))" ]; then
    archive_fail "it grew by $(( after - before )) bytes where $(( b_hdr + b_body )) were written"
  fi
}
NL=$'\n'

# The move is not complete until the destination is in the corpus. Staging here rather than
# leaving it to the caller is deliberate: the caller who forgets is exactly the failure REFUSAL 3
# exists to prevent, and an unstaged new file contributes nothing to `git ls-files`.
stage_archive() {
  if [ "$IN_GIT" -eq 1 ] && [ -n "$GITROOT" ]; then
    git -C "$GITROOT" add -- "$ARCHIVE" >/dev/null 2>&1 || {
      echo "${SELF_NAME}: WARNING -- could not stage ${ARCHIVE}." >&2
      echo "  Until it is tracked, Check 35 cannot see the lines just moved into it." >&2
      echo "  Run: git add -- ${ARCHIVE}" >&2
    }
  fi
}

# What the absorb would do, for report-only mode. Writes nothing.
absorb_report() {
  [ -n "$ABSORB" ] || return 0
  if [ ! -s "$ABSORB" ]; then
    echo "  absorb : ${ABSORB} is already empty -- nothing to absorb, nothing would be written"
  else
    echo "  absorb : ${ABSORB} ($(wc -l < "$ABSORB" | tr -d ' ') lines) would be appended to ${ARCHIVE}, then truncated to 0 bytes (never removed)"
  fi
}

# Append the stale snapshot to the archive; the caller stages the archive and then calls
# absorb_truncate. An already-empty snapshot is a no-op that writes nothing (idempotent re-run).
ABSORB_NOTE=""
ABSORB_DID=0
absorb_append() {
  [ -n "$ABSORB" ] || return 0
  if [ ! -s "$ABSORB" ]; then
    ABSORB_NOTE=" ${ABSORB} was already empty, nothing absorbed;"
    return 0
  fi
  ensure_archive
  A_LINES="$(wc -l < "$ABSORB" | tr -d ' ')"
  archive_append "${NL}<!-- absorbed whole snapshot from $(basename "$ABSORB") at fresh start: ${A_LINES} lines -->${NL}${NL}" "$ABSORB"
  # Reached only when the append verified; archive_append exits 1 otherwise.
  ABSORB_DID=1
  ABSORB_NOTE=" absorbed ${ABSORB} (${A_LINES} lines) and truncated it to 0 bytes;"
}

# Truncate, never remove: the control hooks key on the file's existence (see header).
#
# THE TRUNCATE IS VERIFIED, because an unchecked one on a read-only snapshot exited 0 and printed
# "truncated it to 0 bytes" over a snapshot still holding every line. The lead then Reads a file it
# was told is empty and writes over it. It runs last, after the append and the staging, so a refusal
# here leaves the snapshot archived AND still full: a re-run appends it to the archive again.
absorb_truncate() {
  [ "$ABSORB_DID" -eq 1 ] || return 0
  { : > "$ABSORB"; } 2>/dev/null
  if ! { [ -f "$ABSORB" ] && [ ! -s "$ABSORB" ]; }; then
    echo "${SELF_NAME}: REFUSED -- ${ABSORB} was appended to the archive ${ARCHIVE} but could not be emptied: it is not a writable regular file." >&2
    echo "  The snapshot is archived but NOT emptied, and it still holds all of its content. Do not write over it as if it were empty." >&2
    echo "  Make it writable and re-run: the re-run appends it to the archive AGAIN (a duplicate block that conserves it), then empties it." >&2
    exit 1
  fi
}

# The absorb alone, for the paths where the history does not rotate.
absorb_only() {
  [ -n "$ABSORB" ] || return 0
  refuse_if_archive_ignored
  if [ "$APPLY" -eq 0 ]; then
    absorb_report
    echo "  re-run with --apply to write."
    return 0
  fi
  absorb_append
  if [ "$ABSORB_DID" -eq 1 ]; then
    stage_archive
    absorb_truncate
  fi
  echo "${SELF_NAME}:${ABSORB_NOTE} archive: ${ARCHIVE}"
}

# The archive is staged on the paths that do not rotate too, whenever it exists and --apply was
# given. A run killed after the history rename and before the staging leaves the new history
# already cut and the archive holding the moved block UNTRACKED; the re-run then lands on "nothing
# to rotate". Without staging there, a caller without --absorb left the archive untracked and
# Check 35 scored every line moved into it as destroyed. Measured under the earlier in-place
# design, whose recovery landed on the same path: 8 of 29 pre-run lines absent from
# `git ls-files` after a clean exit-0 re-run.
#
# It stages only; it does not refuse. An archive that already exists and is ignored is refused by
# REFUSAL 3 on every path that writes to it, and here `git add` of it fails and prints the same
# warning as every other staging failure.
stage_existing_archive() {
  [ "$APPLY" -eq 1 ] && [ -f "$ARCHIVE" ] || return 0
  resolve_git
  stage_archive
}

HIST_DIR="$(dirname "$HISTORY")"
HIST_BASE="$(basename "$HISTORY")"
HIST_NEW=""

# Absent is not an error. The first trim of a fresh project creates this file; a rotator that
# exits non-zero before it exists would fail the very step that is about to create it. The absorb
# still runs: on a fresh project this is the only path the fresh-start archival ever takes.
if [ ! -f "$HISTORY" ]; then
  echo "${SELF_NAME}: no history at '${HISTORY}' -- nothing to rotate."
  stage_existing_archive
  absorb_only
  exit 0
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
  stage_existing_archive # at the cut floor
  absorb_only
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
  stage_existing_archive # nothing older than the cut
  exit 0
fi

N_MOVE=$(( N_CUT - KEEP_ENTRIES ))
B_MOVE="$(wc -c < "$TMPD/move" | tr -d ' ')"

# REFUSAL 3 (defined above): checked before anything is written.
refuse_if_archive_ignored

# ---------------------------------------------------------------------------
# Report-only (the default).
# ---------------------------------------------------------------------------
if [ "$APPLY" -eq 0 ]; then
  echo "${SELF_NAME}: ${N_MOVE} of ${N_CUT} entr(ies) would move -- ${L_MOVE} of ${L_ALL} lines (${B_MOVE} bytes),"
  echo "  leaving ${L_PRE} preamble + ${L_TAIL} live."
  echo "  archive: ${ARCHIVE}"
  absorb_report
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
# THE HISTORY IS NEVER WRITTEN THROUGH. `cat preamble tail > "$HISTORY"` truncates the history
# when it opens it, so a write that fails part-way leaves a cut history, and the EXIT trap then
# deletes $TMPD, which held the only complete copy of the kept tail. Measured with `ulimit -f 8`:
# rc 1, the history cut to 8192 bytes, 5 of 10 headings gone, 92 pre-run lines in neither file.
# The in-place write-back that followed (a verified temp copy written back INTO the history) was
# the same hazard one step later: every recovery it needed was a new way to lose lines.
#
# So the new history is built in a fresh `mktemp` file beside the history, verified, and RENAMED
# over it. The order is fixed, and each step's failure leaves a stated state:
#   1. prechecks                 -- refuse, nothing written;
#   2. build the temp, verify it -- remove the temp, refuse, nothing else written;
#   3. archive append, verified  -- remove the temp, refuse; the archive may hold a partial block;
#   4. rename the temp over the history -- remove the temp, refuse; the history is unchanged and
#      the archive holds the moved block, which the next run appends again (a duplicate that
#      conserves it);
#   5. snapshot truncate (absorb_truncate) -- refuse; the rotation is complete.
# The new history depends only on the history, so it is built BEFORE anything is appended: a
# temp that cannot be built never leaves a block in the archive.

# PRECHECKS. Every one runs before any write. The symlink check comes before `[ -w ]`, because
# `[ -w ]` follows the link to the file it names.
if [ -L "$HISTORY" ]; then
  echo "${SELF_NAME}: REFUSED -- the history is a symlink: ${HISTORY}. Nothing written." >&2
  echo "  The new history replaces the history by a rename, which would turn the link into a regular file and" >&2
  echo "  orphan its target. Point the caller at the link's target (or replace the link with the file) and re-run." >&2
  exit 1
fi
# `find FILE -links +1` prints FILE when it has more than one hard link, on BSD and GNU. A relative
# path is prefixed with `./` so a name starting with `-` is not read as an option, and a find that
# FAILS refuses: its empty output would otherwise read as "one link".
case "$HISTORY" in /*) FIND_PATH="$HISTORY" ;; *) FIND_PATH="./$HISTORY" ;; esac
LINKED="$(find "$FIND_PATH" -links +1 2>/dev/null)"; FIND_RC=$?
if [ "$FIND_RC" -ne 0 ]; then
  echo "${SELF_NAME}: REFUSED -- could not read the history's hard-link count (find exited ${FIND_RC}): ${HISTORY}. Nothing written." >&2
  exit 1
fi
if [ -n "$LINKED" ]; then
  echo "${SELF_NAME}: REFUSED -- the history has more than one hard link: ${HISTORY}. Nothing written." >&2
  echo "  The rename would split it from its peer, which would keep the old content. Remove the extra link and re-run." >&2
  exit 1
fi
if [ ! -w "$HISTORY" ]; then
  echo "${SELF_NAME}: REFUSED -- the history is not writable: ${HISTORY}. Nothing written." >&2
  echo "  Make it writable (or run as a user who can write it) and re-run." >&2
  exit 1
fi
# The temp file is created in the history's directory and renamed there, so the directory must be
# writable. Measured under the earlier design: without this, every retry appended the moved block
# again, the archive 1721 -> 2772 -> 3823 bytes.
if [ ! -w "$HIST_DIR" ]; then
  echo "${SELF_NAME}: REFUSED -- the history's directory is not writable: ${HIST_DIR}. Nothing written." >&2
  echo "  The new history is built beside the history and renamed over it. Make the directory writable and re-run." >&2
  exit 1
fi
# A sticky directory lets a user create the temp file but not rename it over a history someone
# else owns, and that failure would come after the archive append.
if [ -k "$HIST_DIR" ] && [ ! -O "$HISTORY" ] && [ "$(id -u)" -ne 0 ]; then
  echo "${SELF_NAME}: REFUSED -- the history's directory is sticky and the history is owned by another user: ${HISTORY}. Nothing written." >&2
  echo "  The rename over it would be refused. Run as the history's owner and re-run." >&2
  exit 1
fi

ARCHIVE_WRITTEN=0
rewrite_fail() {
  [ -n "$HIST_NEW" ] && rm -f "$HIST_NEW"
  if [ "$ARCHIVE_WRITTEN" -eq 0 ]; then
    echo "${SELF_NAME}: REFUSED -- writing the new history failed: $1. Nothing was written: ${HISTORY}, the archive${ABSORB:+ and ${ABSORB}} are unchanged, and the temp file is removed." >&2
    echo "  Fix the cause and re-run." >&2
  else
    echo "${SELF_NAME}: REFUSED -- writing the new history failed: $1, after the moved block was appended to ${ARCHIVE}${ABSORB:+ with ${ABSORB}}." >&2
    echo "  ${HISTORY} is unchanged${ABSORB:+, ${ABSORB} still holds its content,} and the temp file is removed. The moved lines are in BOTH files," >&2
    echo "  which conserves them. Fix the cause and re-run: the re-run appends them to the archive again." >&2
  fi
  exit 1
}

# BUILD. `mktemp` with a trailing-X template (the one form BSD and GNU both substitute) makes a
# fresh name in the history's directory, so the rename is on one filesystem and atomic. `cp -p`
# gives it the history's mode (and owner, where this user may set it) before the new content is
# written into it with `>`, which truncates only our own file.
HIST_NEW="$(mktemp "${HIST_DIR}/.${HIST_BASE}.rotate.XXXXXX")" || { HIST_NEW=""; rewrite_fail "mktemp could not create a file in ${HIST_DIR}"; }
cp -p -- "$HISTORY" "$HIST_NEW" || rewrite_fail "cp -p of the history failed"
B_PRE="$(wc -c < "$TMPD/preamble" | tr -d ' ')"; B_TAIL="$(wc -c < "$TMPD/tail" | tr -d ' ')"
cat "$TMPD/preamble" "$TMPD/tail" > "$HIST_NEW" || rewrite_fail "the write failed"
B_GOT="$(wc -c < "$HIST_NEW" | tr -d ' ')" || rewrite_fail "its size cannot be read"
# Fail closed, for the same reason as archive_append's growth check.
case "${B_PRE}${B_TAIL}${B_GOT}" in ''|*[!0-9]*) rewrite_fail "a size read back as non-numeric" ;; esac
B_WANT=$(( B_PRE + B_TAIL ))
[ "$B_GOT" -eq "$B_WANT" ] || rewrite_fail "it holds ${B_GOT} bytes where ${B_WANT} were written"

# APPEND. archive_fail and ensure_archive remove the temp before they refuse.
ensure_archive

archive_append "${NL}<!-- rotated from $(basename "$HISTORY"): ${L_MOVE} lines, ${N_MOVE} entries -->${NL}${NL}" "$TMPD/move"

absorb_append
ARCHIVE_WRITTEN=1

# RENAME. The history is the complete old file until this returns and the complete new file after.
mv -f -- "$HIST_NEW" "$HISTORY" || rewrite_fail "the rename over the history failed"
HIST_NEW=""

stage_archive
absorb_truncate

echo "${SELF_NAME}: moved ${N_MOVE} entr(ies), ${L_MOVE} lines (${B_MOVE} bytes) to ${ARCHIVE};${ABSORB_NOTE} history is now $(wc -l < "$HISTORY" | tr -d ' ') lines."
echo "  Verify: validate-snapshot-conservation.sh must report the same verdict as before this ran."
exit 0
