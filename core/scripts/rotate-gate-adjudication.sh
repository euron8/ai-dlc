#!/usr/bin/env bash
#
# AI/DLC Gate-Adjudication Rotator
#
# Moves a closed sprint's `*.verdict.json` (plus its repair and authorization
# sidecars) out of the live `gate-adjudication/` directory and into that
# sprint's own archive under `implementation-artifacts/`.
#
# WHY THIS EXISTS. `core/hooks/ai-dlc-gate-remediation-guard.sh` (arm 4, picking
# the live pass) orders every `*.verdict.json` in the directory by nonce alone,
# with no notion of sprint. A closed sprint's dispositioned FAIL therefore stays
# the "live pass" until the next sprint's first verdict lands. Measured on the
# reference consumer: two `GATE_REMEDIATION_DENIED` events at a fresh sprint's
# first planning-artifacts edit both named the PRIOR sprint's sprint-review
# nonce and a check the operator had already suppressed; six clerical edits
# were routed through opus remediators for nothing owed. Rotating the closed
# sprint's verdicts at retro close removes the affordance rather than teaching
# a hook that deliberately reads no snapshot about sprint boundaries.
#
# SELECTION. A verdict moves when it parses as JSON and its `gate_series_id`
# names the given sprint (`*-s<N>-*`, e.g. `planning-s308-20260902T034604Z`
# for `--sprint s308`). A verdict with NO `gate_series_id` is legacy and never
# moves. A verdict naming a different sprint never moves. A `*.verdict.json`
# that does not parse is a REFUSAL: an unreadable verdict must never be silently
# left standing as the guard's live pass, whichever sprint it does or does not
# belong to.
#
# THE LEGACY SKIP IS SAFE ONLY WHILE A NEWER VERDICT SHADOWS IT, AND AN EARLIER
# REVISION OF THIS HEADER CLAIMED OTHERWISE. It said the skip was safe because
# "the guard's own series split already tolerates it". The guard has no series
# split: `gate_series_id` does not appear in `ai-dlc-gate-remediation-guard.sh`
# at all. That split is `validate-gate-adjudication.sh`'s, and even there the
# tolerance is conditional on the legacy verdict sorting BEFORE every live
# series. Rotating a closed sprint out can therefore promote a FAILing legacy
# verdict to live pass, which is a deny no later rotation can clear -- so the
# refusal below computes that outcome and refuses the move. See its header.
#
# SIDECARS move with their verdict: any regular file in the source directory
# whose name is `<nonce-stem>.<anything>` -- `<stem>.repair.md`,
# `<stem>.repair2.md`, `<stem>.repair2-addendum.md`, `<stem>.authorization.md`
# on the reference consumer. Everything else (subdirectories,
# `.verdict-writes.jsonl`, unrelated files) is untouched.
#
# THE DESTINATION MUST BE ABLE TO ENTER THE CORPUS, same reasoning as
# `rotate-snapshot-archive.sh`'s REFUSAL 3: `validate-gate-adjudication.sh`
# reads the on-disk tree, not `git ls-files`, but a git-ignored destination is
# still the wrong place to put an artifact the retro and the series validator
# are expected to be able to find later. Refused before anything is written.
#
# Usage:
#   rotate-gate-adjudication.sh --sprint s<N> [--apply] [--state-dir <dir>]
#     --apply       write; default is a report that changes nothing
#     --state-dir   default: ${AI_DLC_STATE_DIR:-_bmad-output}, resolved under
#                   the repo root found by walking UP for a `VERSION` file or a
#                   `.git` directory from the CURRENT WORKING DIRECTORY. Given
#                   explicitly, a RELATIVE --state-dir is resolved against the
#                   cwd instead, never against the repo root.
#
#   source:      <state-dir>/gate-adjudication/
#   destination: <state-dir>/implementation-artifacts/s<N>/gate-adjudication/
#
# Exit: 0 = reported or rotated (nothing to rotate is a normal, affirmative
#           result, and so is a second --apply for an already-rotated sprint)
#       1 = REFUSED or HARD_BLOCK: an integrity check failed and NOTHING more
#           was written than had already landed before the failure
#       2 = usage / cannot resolve a repo root
set -uo pipefail

SELF_NAME="rotate-gate-adjudication"

usage() {
  echo "usage: rotate-gate-adjudication.sh --sprint s<N> [--apply] [--state-dir <dir>]" >&2
  exit 2
}

SPRINT=""
APPLY=0
STATE_DIR_ARG=""
LEGACY_BEFORE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --sprint)     SPRINT="${2:?--sprint needs a value}"; shift 2 ;;
    --apply)      APPLY=1; shift ;;
    --state-dir)  STATE_DIR_ARG="${2:?--state-dir needs a path}"; shift 2 ;;
    --legacy-before) LEGACY_BEFORE="${2:?--legacy-before needs a nonce}"; shift 2 ;;
    -h|--help)    usage ;;
    *) echo "${SELF_NAME}: unknown argument '$1'" >&2; usage ;;
  esac
done

# --legacy-before is the OTHER mode and takes no --sprint: it moves pre-series
# verdicts, which name no sprint and so cannot be selected by one.
if [ -n "$LEGACY_BEFORE" ]; then
  [ -n "$SPRINT" ] && {
    echo "${SELF_NAME}: --legacy-before and --sprint are separate modes; pass one" >&2; exit 2; }
  case "$LEGACY_BEFORE" in
    [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z) ;;
    *) echo "${SELF_NAME}: --legacy-before must be a nonce like 20260811T000000Z (got '${LEGACY_BEFORE}')" >&2
       exit 2 ;;
  esac
  SPRINT="pre-series"
else
  [ -n "$SPRINT" ] || usage
  case "$SPRINT" in
    s[0-9]*) ;;
    *) echo "${SELF_NAME}: --sprint must look like 's<N>' (got '${SPRINT}')" >&2; exit 2 ;;
  esac
fi

command -v jq >/dev/null 2>&1 || {
  echo "${SELF_NAME}: jq is required and not on PATH" >&2; exit 2; }

# ---------------------------------------------------------------------------
# Resolve the state directory. CLAUDE.md: "Resolve the repo root by walking up
# for a marker. Never count '..' hops." -- the walk starts at the CURRENT
# WORKING DIRECTORY, not at this script's own location, because the state dir
# is a property of the tree being operated on, and a relative --state-dir is
# explicitly cwd-relative rather than repo-root-relative.
# ---------------------------------------------------------------------------
find_repo_root() {
  local d="$PWD"
  while [ "$d" != "/" ]; do
    if [ -f "$d/VERSION" ] || [ -d "$d/.git" ]; then printf '%s' "$d"; return 0; fi
    d="$(dirname "$d")"
  done
  return 1
}

if [ -n "$STATE_DIR_ARG" ]; then
  case "$STATE_DIR_ARG" in
    /*) STATE_DIR="$STATE_DIR_ARG" ;;
    *)  STATE_DIR="$PWD/$STATE_DIR_ARG" ;;
  esac
else
  REPO_ROOT="$(find_repo_root)" || {
    echo "${SELF_NAME}: cannot find a VERSION file or a .git directory walking up from '${PWD}'" >&2
    exit 2
  }
  NAME="${AI_DLC_STATE_DIR:-_bmad-output}"
  case "$NAME" in
    /*) STATE_DIR="$NAME" ;;
    *)  STATE_DIR="$REPO_ROOT/$NAME" ;;
  esac
fi

SRC="$STATE_DIR/gate-adjudication"
DEST="$STATE_DIR/implementation-artifacts/${SPRINT}/gate-adjudication"

# Absent source is not an error -- a sprint with no adjudication directory yet
# (or ever) has nothing to rotate, and a rotator that refused here would fail
# the very first sprint of a fresh project.
if [ ! -d "$SRC" ]; then
  echo "${SELF_NAME}: no '${SRC}' -- nothing to rotate."
  exit 0
fi

TMPD="$(mktemp -d "${TMPDIR:-/tmp}/aidlc-gaterotate.XXXXXX")" || {
  echo "${SELF_NAME}: mktemp failed" >&2; exit 1; }
trap 'rm -rf "$TMPD"' EXIT

# ---------------------------------------------------------------------------
# Discovery: classify every top-level *.verdict.json. Read-only; no writes
# happen in this block in EITHER mode, so a refusal here has written nothing
# by construction.
# ---------------------------------------------------------------------------
: > "$TMPD/move_stems"
: > "$TMPD/unparseable"

for f in "$SRC"/*.verdict.json; do
  [ -e "$f" ] || continue
  series="$(jq -r '.gate_series_id // empty' "$f" 2>/dev/null)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    printf '%s\n' "$f" >> "$TMPD/unparseable"
    continue
  fi
  if [ -n "$LEGACY_BEFORE" ]; then
    # LEGACY MODE: select PRE-SERIES verdicts only, and only those strictly older
    # than the given nonce. The bound is required and is not a convenience: it is
    # what keeps this mode from moving a legacy verdict that a live series has not
    # yet overtaken -- the one case `validate-gate-adjudication.sh` FAILS CLOSED on.
    [ -n "$series" ] && continue
    _lstem="$(basename "$f" .verdict.json)"
    case "${_lstem##*-}" in
      [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z) ;;
      *) continue ;;              # unorderable stem: the guard cannot see it either
    esac
    if [ "${_lstem##*-}" \< "$LEGACY_BEFORE" ]; then
      printf '%s\n' "$_lstem" >> "$TMPD/move_stems"
    fi
    continue
  fi
  [ -n "$series" ] || continue   # legacy: no gate_series_id -- never moves
  case "$series" in
    *"-${SPRINT}-"*) basename "$f" .verdict.json >> "$TMPD/move_stems" ;;
    *) ;;                         # a different sprint's series id -- never moves
  esac
done

# REFUSAL: an unreadable verdict must never be left as the guard's live pass,
# whichever sprint it does or does not belong to, and this must hold in report
# mode too -- a report that quietly skipped a file it could not read would
# print a move plan that understates the danger already sitting in the
# directory.
N_BAD="$(grep -c . "$TMPD/unparseable" 2>/dev/null)" || N_BAD=0
if [ "$N_BAD" -gt 0 ]; then
  echo "${SELF_NAME}: REFUSED -- ${N_BAD} file(s) under '${SRC}' do not parse as JSON:" >&2
  sed 's/^/  /' "$TMPD/unparseable" >&2
  echo "  An unreadable verdict must never be silently left as the guard's live pass." >&2
  echo "  Fix or remove the file(s) above. Nothing written." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Expand each selected stem to its full move set: the verdict itself plus
# every sidecar sharing its nonce stem (`<stem>.<anything>`), regular files
# only -- a subdirectory or an unrelated file never matches this glob because
# the literal `.` requires the stem to be followed by a dot.
# ---------------------------------------------------------------------------
: > "$TMPD/move_files"
while IFS= read -r stem; do
  [ -n "$stem" ] || continue
  for f in "$SRC/$stem".*; do
    [ -f "$f" ] || continue
    basename "$f" >> "$TMPD/move_files"
  done
done < "$TMPD/move_stems"

sort -u "$TMPD/move_files" -o "$TMPD/move_files"
N_VERDICTS="$(grep -c . "$TMPD/move_stems" 2>/dev/null)" || N_VERDICTS=0
N_FILES="$(grep -c . "$TMPD/move_files" 2>/dev/null)" || N_FILES=0
N_SIDECARS=$(( N_FILES - N_VERDICTS ))

if [ "$N_FILES" -eq 0 ]; then
  echo "${SELF_NAME}: no verdict under '${SRC}' names series '${SPRINT}' -- nothing to move."
  exit 0
fi

# ---------------------------------------------------------------------------
# REFUSAL: this rotation would leave a FAILing LEGACY verdict as the guard's
# live pass, and no later rotation can ever clear it.
#
# WHY THIS EXISTS, AND WHY THE CARVE-OUT ABOVE IS NOT SELF-JUSTIFYING. The
# legacy skip at the selection loop says a verdict with no `gate_series_id`
# never moves, on the stated grounds that "the guard's own series split already
# tolerates it". THAT SPLIT IS NOT THE GUARD'S. `gate_series_id` does not occur
# in `ai-dlc-gate-remediation-guard.sh` at all; its live-pass pick orders every
# conforming stem in the directory by trailing nonce and reads nothing else.
# The split described is `validate-gate-adjudication.sh`'s, whose own header
# tolerates a legacy verdict ONLY while it sorts strictly BEFORE the first pass
# of every live series -- a precondition that rotating every series-bearing
# verdict out DESTROYS. A true sentence about one reader, offered as a safety
# argument for another that shares the directory and nothing else.
#
# WHAT THAT COSTS, MEASURED ON THE REFERENCE CONSUMER. Its live directory holds
# 188 verdicts, 94 of them legacy, and 33 of those 94 record a FAIL. The newest
# is `story-20260811T214958Z`, check 7, carrying no repair and no authorization
# sidecar. Today every legacy verdict is shadowed by a newer series-bearing one,
# so the guard never reaches back that far and the state is invisible. Rotate
# the closed sprints out and that 2026-08-11 verdict becomes the live pass:
# driving the real guard against a scratch copy, residue present ALLOWS,
# residue rotated away DENIES, and restoring one clean current-sprint verdict
# ALLOWS again -- so the removal is the cause, not something ambient.
#
# THE DENY IS UNCLEARABLE, WHICH IS WHY THIS REFUSES RATHER THAN WARNS. A
# stale-sprint deny clears when the next sprint writes its first verdict. This
# one cannot: the file carries no series id, so the selection loop above refuses
# to move it for ANY `--sprint`, and with no sidecar neither lift arm applies.
# Trading a self-clearing denial for a permanent one is strictly worse than the
# state being repaired, so the rotation is refused before it can construct it.
#
# THE PREDICATE COSTS NO NEW I/O -- every verdict in the directory was already
# parsed by the discovery loop above -- and it is keyed on what the GUARD reads:
# the conforming-stem shape and the trailing nonce, not on this script's own
# selection rule. FP set on the reference consumer: 0 across all nine
# single-sprint rotations, which is the shipping call path (`retro.md` 5b);
# it fires only on the multi-sprint backfill that actually strands the residue.
# ---------------------------------------------------------------------------
conforming_nonce() {
  # The guard's own filter: the stem's trailing `-` field must be a nonce.
  # A stem that fails it is invisible to the guard and must not be considered
  # here either -- two such files exist on the reference consumer.
  case "${1##*-}" in
    [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z)
      printf '%s' "${1##*-}"; return 0 ;;
  esac
  return 1
}

SURVIVOR_STEM=""; SURVIVOR_TS=""; SURVIVOR_FAILS=""; SURVIVOR_LEGACY=0
for f in "$SRC"/*.verdict.json; do
  [ -e "$f" ] || continue
  _stem="$(basename "$f" .verdict.json)"
  # Anything this run is about to move is not a survivor.
  if grep -qxF "$_stem" "$TMPD/move_stems" 2>/dev/null; then continue; fi
  _ts="$(conforming_nonce "$_stem")" || continue
  if [ -z "$SURVIVOR_TS" ] || [ "$_ts" \> "$SURVIVOR_TS" ]; then
    SURVIVOR_TS="$_ts"; SURVIVOR_STEM="$_stem"
    SURVIVOR_FAILS="$(jq -r '[.verdicts[]? | select(.verdict=="FAIL") | .check_id] | join(" ")' \
                        "$f" 2>/dev/null)" || SURVIVOR_FAILS=""
    _series="$(jq -r '.gate_series_id // empty' "$f" 2>/dev/null)" || _series=""
    if [ -n "$_series" ]; then SURVIVOR_LEGACY=0; else SURVIVOR_LEGACY=1; fi
  fi
done

if [ "$SURVIVOR_LEGACY" -eq 1 ] && [ -n "$SURVIVOR_FAILS" ]; then
  echo "${SELF_NAME}: REFUSED -- this rotation would strand a FAILing legacy verdict." >&2
  echo "  Newest verdict left in '${SRC}' after this move:" >&2
  echo "    ${SURVIVOR_STEM} -- no gate_series_id, FAILed check(s): ${SURVIVOR_FAILS}" >&2
  echo "  The gate-remediation guard picks its live pass by trailing nonce with no notion of" >&2
  echo "  sprint, so that verdict would become the live pass and deny artifact edits. It" >&2
  echo "  carries no gate_series_id, so NO --sprint rotation can ever move it, and the deny" >&2
  echo "  would not clear on its own. Nothing written." >&2
  echo "" >&2
  echo "  THE REMEDY IS TO ROTATE THE PRE-SERIES VERDICTS OUT, then re-run this command:" >&2
  echo "    ${SELF_NAME}.sh --legacy-before ${SURVIVOR_TS} --apply" >&2
  echo "" >&2
  echo "  A SIDECAR DOES NOT LIFT THIS. The guard's repair and authorization records are" >&2
  echo "  read by the GUARD, not by this rotator, so writing one changes nothing here --" >&2
  echo "  an earlier revision of this message prescribed exactly that and it was inert." >&2
  echo "  Deferring until the next sprint's first verdict lands also only moves the block:" >&2
  echo "  it clears this close and refuses the following one, one sprint behind forever." >&2
  exit 1
fi

# ---------------------------------------------------------------------------
# Report-only (the default).
# ---------------------------------------------------------------------------
if [ "$APPLY" -eq 0 ]; then
  echo "${SELF_NAME}: ${N_VERDICTS} verdict(s) and ${N_SIDECARS} sidecar(s) would move to ${DEST}:"
  sed 's/^/  /' "$TMPD/move_files"
  echo "  re-run with --apply to write."
  exit 0
fi

# ---------------------------------------------------------------------------
# The destination must be able to enter the corpus. Refused BEFORE anything is
# written -- same register as rotate-snapshot-archive.sh's REFUSAL 3.
# ---------------------------------------------------------------------------
IN_GIT=0
GITROOT=""
if git -C "$SRC" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  IN_GIT=1
  GITROOT="$(git -C "$SRC" rev-parse --show-toplevel 2>/dev/null)"
fi

if [ "$IN_GIT" -eq 1 ] && [ -n "$GITROOT" ] && git -C "$GITROOT" check-ignore -q "$DEST" 2>/dev/null; then
  echo "${SELF_NAME}: REFUSED -- the destination is git-ignored: ${DEST}" >&2
  echo "  Rotating a sprint's gate-adjudication records into a path git ignores would move" >&2
  echo "  them somewhere the retro and the series validator are not expected to look. Nothing" >&2
  echo "  written. Un-ignore the path, or pass --state-dir with one that is tracked." >&2
  exit 1
fi

mkdir -p "$DEST" || {
  echo "${SELF_NAME}: cannot create ${DEST}. Nothing written." >&2; exit 1; }

# ---------------------------------------------------------------------------
# Apply. Move one file at a time, recording what has already moved so a
# mismatch can restore it. `git mv` when the file is tracked (so the rename is
# recorded rather than read as a delete + an add), plain `mv` otherwise.
# ---------------------------------------------------------------------------
: > "$TMPD/moved_log"   # "tracked\tsrc\tdest" per successfully relocated file

restore_moved() {
  # Best-effort: put back everything this run relocated, in reverse order.
  while IFS="$(printf '\t')" read -r tracked s d; do
    [ -n "${s:-}" ] || continue
    if [ -f "$d" ] && [ ! -e "$s" ]; then
      if [ "$tracked" = "1" ] && [ -n "$GITROOT" ]; then
        git -C "$GITROOT" mv -- "$d" "$s" >/dev/null 2>&1 || mv "$d" "$s" 2>/dev/null
      else
        mv "$d" "$s" 2>/dev/null
      fi
    fi
  done < "$TMPD/moved_log"
}

FAIL=0
while IFS= read -r name; do
  [ -n "$name" ] || continue
  SFILE="$SRC/$name"
  DFILE="$DEST/$name"
  SIZE_BEFORE="$(wc -c < "$SFILE" | tr -d ' ')"

  TRACKED=0
  if [ "$IN_GIT" -eq 1 ] && [ -n "$GITROOT" ] \
     && git -C "$GITROOT" ls-files --error-unmatch -- "$SFILE" >/dev/null 2>&1; then
    TRACKED=1
  fi

  if [ "$TRACKED" -eq 1 ]; then
    git -C "$GITROOT" mv -- "$SFILE" "$DFILE" >/dev/null 2>&1 || mv "$SFILE" "$DFILE"
  else
    mv "$SFILE" "$DFILE"
  fi

  if [ -e "$SFILE" ] || [ ! -f "$DFILE" ]; then
    echo "${SELF_NAME}: HARD_BLOCK -- '${name}' did not relocate cleanly (source present: $([ -e "$SFILE" ] && echo yes || echo no), destination present: $([ -f "$DFILE" ] && echo yes || echo no))." >&2
    FAIL=1
    break
  fi

  SIZE_AFTER="$(wc -c < "$DFILE" | tr -d ' ')"
  if [ "$SIZE_AFTER" != "$SIZE_BEFORE" ]; then
    echo "${SELF_NAME}: HARD_BLOCK -- '${name}' changed size in transit (${SIZE_BEFORE} -> ${SIZE_AFTER} bytes)." >&2
    FAIL=1
    break
  fi

  printf '%s\t%s\t%s\n' "$TRACKED" "$SFILE" "$DFILE" >> "$TMPD/moved_log"
done < "$TMPD/move_files"

if [ "$FAIL" -eq 1 ]; then
  restore_moved
  echo "${SELF_NAME}: HARD_BLOCK -- rotation aborted; every file this run had already relocated was restored to '${SRC}'. Nothing net was written." >&2
  exit 1
fi

echo "${SELF_NAME}: moved ${N_VERDICTS} verdict(s), ${N_SIDECARS} sidecar(s) -- ${N_FILES} file(s) total -- to ${DEST}."
sed 's/^/  /' "$TMPD/move_files"
exit 0
