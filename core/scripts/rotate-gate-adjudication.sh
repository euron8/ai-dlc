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
# A SERIES ID NO --sprint CAN NAME IS A REFUSAL ON AN EMPTY SELECTION WHEN ITS
# SERIES CARRIES A FAIL, AND A WARN OTHERWISE. The schema leaves `gate_series_id`
# unpatterned, and the reference consumer's writers stamp ids with no sprint token
# at all -- `<gate>-<nonce>`, `s310-planning`, `story-s311`. Measured on that
# consumer's live directory: 239 verdicts, 94 with no series id, 93 carrying a
# `-s<N>-` token, and 52 carrying an id no `*-s<N>-*` selector can match, 42 of
# them exactly `<gate>-<nonce>`. Every sprint whose writers stamped only such ids
# reported "nothing to move" and exited 0, so retro's rotation step passed while
# moving nothing and the closed sprint's verdicts stayed live. So, in --sprint mode:
#   - EMPTY selection, and any unmatchable series (a NON-EMPTY id that
#     `survivor_unmovable` scores unmovable) with at least one member recording a
#     FAIL: exit 1, naming every file of every such series and printing one
#     `--series` command per distinct id. A legacy verdict (no id) never counts
#     here; --legacy-through owns those.
#   - EMPTY selection and only PASS-only unmatchable series: "nothing to move", a
#     WARN naming them with the same commands, exit 0.
#   - NON-EMPTY selection: the selected verdicts move as before, the unmatchable
#     ones stay live, and a WARN line names them with the same commands. Exit 0.
#     The HARD_BLOCK fires only on an empty selection, because a sprint whose
#     own verdicts were tagged has been rotated, and refusing that move over a
#     different series would wedge the close for something it did not cause.
#
# THE REFUSAL WAS NARROWED TO FAIL-CARRYING SERIES, AND AN EARLIER REVISION KEYED IT
# ON THE ID ALONE. The guard reads only the live directory, and a stale verdict that
# records no FAIL is its ALLOW state: leaving one live denies nothing. A stale FAIL
# is what denies, so it is what the close must not pass over. Measured on the
# reference consumer: 8 of the 52 unmatchable verdicts carry a FAIL, and the
# motivating s318 close still refuses. Of the 12 unmatchable verdicts newer than
# the s317 archive, 2 carry a FAIL; their 2 series hold 4 of the 12 files the
# refusal names. The fixture's mutation 6 therefore REVERTS the narrowing
# (every unmatchable series counts) and requires the PASS-only world to flip from
# exit 0 to exit 1; it used to apply the narrowing as the wrong fix.
#
# The sprint printed in each command is a HINT, labelled as one, and given only
# when exactly one sprint is possible:
#   - the id's own `s<digits>` field when it has one;
#   - no sprint archive at all: the sprint being closed;
#   - the archived sprint whose nonce range holds the verdict's nonce;
#   - newer than the newest archive s<N>: the candidates are s<N+1> through the
#     sprint being closed, and a hint is printed only when that is one sprint;
#   - between archives s<L> and s<H>: the candidates are s<L+1> through s<H-1>,
#     the same rule, so two ADJACENT archives give no candidate at all.
# Anything else prints `NO HINT (s<a>..s<b>)` and a placeholder sprint that
# --sprint validation rejects, so an unknown sprint cannot be run by accident.
# The last two rules exclude the archive below the nonce, which is right only
# when that archive is complete; measured on the reference consumer, the s312
# archive holds one verdict while six of s312's sit live after it, and the rule
# that hinted N+1 there named s313 for all six. Nothing applies a hint; each
# printed command is a dry run until the operator confirms the sprint and adds
# --apply. The commands are spelled for the layout this copy runs from:
# `bash scripts/ai-dlc/...` installed, `bash core/scripts/...` in the distribution.
#
# THE ESCAPE IS `--sprint s<N> --series <exact-id>`. It moves every verdict whose
# `gate_series_id` EQUALS <exact-id> -- string equality, never a prefix, because
# `<gate>-<nonce>` ids share prefixes with their retries -- into s<N>'s archive,
# with sidecars, under every refusal --sprint mode honours. It refuses an id a
# --sprint selector can already name, since moving that one by hand could file it
# under the wrong sprint. Run the printed commands in the order printed: oldest
# series first, so the newest verdict stays live until its own series moves.
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
#   rotate-gate-adjudication.sh --sprint s<N> --series <exact-id> [--apply] [--state-dir <dir>]
#   rotate-gate-adjudication.sh --legacy-through <nonce> [--apply] [--state-dir <dir>]
#     --apply           write; default is a report that changes nothing
#     --series          move the verdicts whose gate_series_id is EXACTLY <exact-id>
#                       into s<N>, instead of selecting by the `-s<N>-` token. The
#                       remedy the unmatchable-series refusal prints.
#     --state-dir       default: ${AI_DLC_STATE_DIR:-_bmad-output}, resolved under
#                       the repo root found by walking UP for a `VERSION` file or a
#                       `.git` directory from the CURRENT WORKING DIRECTORY. Given
#                       explicitly, a RELATIVE --state-dir is resolved against the
#                       cwd instead, never against the repo root.
#     --legacy-through  the OTHER mode, and it takes no --sprint. Moves PRE-SERIES
#                       verdicts (no `gate_series_id`) whose nonce is at or before
#                       <nonce>, INCLUSIVE. This is the escape the stranding
#                       refusal prescribes: a pre-series verdict names no sprint,
#                       so no --sprint invocation can ever move it. The bound is
#                       CALLER-ASSERTED -- nothing derives it from a live series.
#
#   source:      <state-dir>/gate-adjudication/
#   destination: <state-dir>/implementation-artifacts/s<N>/gate-adjudication/
#                <state-dir>/implementation-artifacts/pre-series/gate-adjudication/
#                  (--legacy-through)
#
# Exit: 0 = reported or rotated (nothing to rotate is a normal, affirmative
#           result, and so is a second --apply for an already-rotated sprint)
#       1 = REFUSED or HARD_BLOCK: an integrity check failed and NOTHING more
#           was written than had already landed before the failure
#       2 = usage / cannot resolve a repo root
set -uo pipefail

SELF_NAME="rotate-gate-adjudication"

# The command a remedy line prints, spelled for the layout THIS copy runs from, so an
# operator can paste it from the repo root: install.sh puts core/scripts/<x> at
# scripts/ai-dlc/<x>. Derived from this script's own directory, never hardcoded.
SELF_DIR="$(cd "$(dirname "$0")" 2>/dev/null && pwd)" || SELF_DIR=""
case "$SELF_DIR" in
  */scripts/ai-dlc) SELF_CMD="bash scripts/ai-dlc/${SELF_NAME}.sh" ;;
  */core/scripts)   SELF_CMD="bash core/scripts/${SELF_NAME}.sh" ;;
  *)                SELF_CMD="bash ${SELF_DIR:-.}/${SELF_NAME}.sh" ;;
esac

# shq <string> -> the string with every ' spelled '\'' so it can sit inside a
# single-quoted shell word and be pasted as printed.
shq() { printf '%s' "$1" | sed "s/'/'\\\\''/g"; }

usage() {
  echo "usage: rotate-gate-adjudication.sh --sprint s<N> [--apply] [--state-dir <dir>]" >&2
  echo "       rotate-gate-adjudication.sh --sprint s<N> --series <exact-id> [--apply] [--state-dir <dir>]" >&2
  echo "       rotate-gate-adjudication.sh --legacy-through <nonce> [--apply] [--state-dir <dir>]" >&2
  echo "  --series moves the verdicts whose gate_series_id is exactly <exact-id> into s<N>;" >&2
  echo "  it is what the unmatchable-series refusal prescribes." >&2
  echo "  --legacy-through moves PRE-SERIES verdicts at or before <nonce> (inclusive)," >&2
  echo "  which no --sprint invocation can move. It is what the stranding refusal prescribes." >&2
  exit 2
}

SPRINT=""
APPLY=0
STATE_DIR_ARG=""
LEGACY_THROUGH=""
SERIES=""

while [ $# -gt 0 ]; do
  case "$1" in
    --sprint)     SPRINT="${2:?--sprint needs a value}"; shift 2 ;;
    --series)     [ $# -ge 2 ] && [ -n "$2" ] || {
                    echo "${SELF_NAME}: --series needs a non-empty, exact gate_series_id" >&2; usage; }
                  SERIES="$2"; shift 2 ;;
    --apply)      APPLY=1; shift ;;
    --state-dir)  STATE_DIR_ARG="${2:?--state-dir needs a path}"; shift 2 ;;
    --legacy-through) LEGACY_THROUGH="${2:?--legacy-through needs a nonce}"; shift 2 ;;
    -h|--help)    usage ;;
    *) echo "${SELF_NAME}: unknown argument '$1'" >&2; usage ;;
  esac
done

# --legacy-through is the OTHER mode and takes no --sprint: it moves pre-series
# verdicts, which name no sprint and so cannot be selected by one.
if [ -n "$LEGACY_THROUGH" ]; then
  [ -n "$SPRINT" ] && {
    echo "${SELF_NAME}: --legacy-through and --sprint are separate modes; pass one" >&2; exit 2; }
  [ -n "$SERIES" ] && {
    echo "${SELF_NAME}: --series needs --sprint, not --legacy-through" >&2; exit 2; }
  case "$LEGACY_THROUGH" in
    [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z) ;;
    *) echo "${SELF_NAME}: --legacy-through must be a nonce like 20260811T000000Z (got '${LEGACY_THROUGH}')" >&2
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
: > "$TMPD/series_rows"

for f in "$SRC"/*.verdict.json; do
  [ -e "$f" ] || continue
  series="$(jq -r '.gate_series_id // empty' "$f" 2>/dev/null)"
  rc=$?
  if [ "$rc" -ne 0 ]; then
    printf '%s\n' "$f" >> "$TMPD/unparseable"
    continue
  fi
  if [ -n "$LEGACY_THROUGH" ]; then
    # LEGACY MODE: select PRE-SERIES verdicts only, up to and INCLUDING the bound.
    #
    # THE BOUND IS INCLUSIVE, AND AN EXCLUSIVE ONE MADE THE REFUSAL'S OWN REMEDY
    # LOOP FOREVER. The refusal names the survivor and prints a command to remove
    # it; under a strict `<` that command moved everything EXCEPT the named file,
    # so the next close re-printed the identical bound. Measured on the reference
    # consumer: 92 verdicts moved where 93 were owed, the named survivor still
    # live, and no fixed point. Inclusive, the printed command converges in one
    # run. `--legacy-through` is named for the semantics so a reader cannot carry
    # the old assumption over.
    #
    # THE BOUND IS CALLER-ASSERTED AND IS NOT DERIVED FROM ANY LIVE SERIES. An
    # earlier comment here claimed it was what stopped this mode moving a legacy
    # verdict a live series had not yet overtaken; it is not, and a hand-run bound
    # can do exactly that. The refusal's own printed bound cannot -- the survivor
    # it names is by construction the newest conforming stem -- but a hand-run one
    # is the documented usage, so the property is the caller's to hold.
    [ -n "$series" ] && continue
    _lstem="$(basename "$f" .verdict.json)"
    case "${_lstem##*-}" in
      [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z) ;;
      *) continue ;;              # unorderable stem: the guard cannot see it either
    esac
    if [ ! "${_lstem##*-}" \> "$LEGACY_THROUGH" ]; then
      printf '%s\n' "$_lstem" >> "$TMPD/move_stems"
    fi
    continue
  fi
  [ -n "$series" ] || continue   # legacy: no gate_series_id -- never moves
  # Every series-bearing verdict is recorded for the unmatchable-series check,
  # which runs once the predicate it calls is defined below.
  printf '%s\t%s\n' "$series" "$f" >> "$TMPD/series_rows"
  if [ -n "$SERIES" ]; then
    # --series: exact string equality, never a prefix or a glob.
    [ "$series" = "$SERIES" ] && basename "$f" .verdict.json >> "$TMPD/move_stems"
    continue
  fi
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
# VERDICTS MOVE BEFORE THEIR SIDECARS. `sort` puts `<stem>.repair.md` ahead of
# `<stem>.verdict.json`, so an abort between the two would leave a live verdict
# whose repair record had already left, and the guard would read that FAIL as owed
# again. Moving the verdict first means an abort can only strand a sidecar.
grep '\.verdict\.json$' "$TMPD/move_files" > "$TMPD/move_files_ordered"
grep -v '\.verdict\.json$' "$TMPD/move_files" >> "$TMPD/move_files_ordered"
cp "$TMPD/move_files_ordered" "$TMPD/move_files"
N_VERDICTS="$(grep -c . "$TMPD/move_stems" 2>/dev/null)" || N_VERDICTS=0
N_FILES="$(grep -c . "$TMPD/move_files" 2>/dev/null)" || N_FILES=0
N_SIDECARS=$(( N_FILES - N_VERDICTS ))

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

# THE PREDICATE IS "NO MODE CAN MOVE IT", NOT "IT IS LEGACY", AND THE NARROWER
# SPELLING LEFT A SECOND DOOR OPEN. A verdict is unmovable in TWO ways: it
# carries no `gate_series_id` (legacy, moved only by --legacy-through), or it
# carries one that `*-s<N>-*` cannot select. The schema calls the field
# "deliberately unpatterned: required and non-empty, nothing more", so the glob
# is an UNSTATED pattern imposed on a field nothing constrains -- any writer
# stamping a legal-but-differently-ordered id produces a member. Measured on the
# reference consumer: `s310-planning`, sprint-first, written by a live session
# and matching no `*-s<N>-*`. Such a verdict is worse than a legacy one, because
# --legacy-through skips it too (`[ -n "$series" ] && continue`): no refusal AND
# no escape. Keying on legacy-ness alone reopened the exact trap this refusal
# exists to close, through a different door.
# ASK WHETHER A SPRINT ANYONE WOULD TYPE MOVES IT; A GLOB ANSWERS A DIFFERENT
# QUESTION. An earlier revision tested `*-s[0-9]*-*`, where `[0-9]*` is one digit
# followed by ANYTHING, so it matched ids whose "sprint token" holds whitespace or
# letters -- `a-s1x-b`, `x-s3 1 0-y`, `planning-s310 -<nonce>`.
#
# THOSE THREE ARE TECHNICALLY MOVABLE, AND AN EARLIER COMMENT HERE SAID THEY WERE
# NOT. Measured by DRIVING this rotator rather than by a second parser: `--sprint`
# validation accepts `s[0-9]*`, so `s1x` and `s310 ` are accepted arguments and
# they do select those verdicts. The claim that nothing could move them came from
# an oracle that swept only well-formed numeric sprints -- the same narrowness it
# was written to criticise.
#
# REFUSING THEM IS STILL RIGHT, for a reason the old comment did not give. The
# only argument that moves such a verdict is one no operator would type, and its
# destination is derived from that argument: `--sprint "s310 "` writes to
# `implementation-artifacts/s310 /`, a trailing-space directory that is NOT the
# sprint it appears to name. An "escape" that silently files a verdict under a
# differently-named sprint is not an escape. So the predicate is deliberately
# CONSERVATIVE here: it refuses, and the operator re-stamps.
#
# The token is DERIVED from the id and tested as the selector tests it: split on
# `-`, and for each field of the form s<digits> -- digits ONLY, which is where
# this is stricter than `--sprint` validation and is the whole point -- ask
# whether the exact `-<field>-` substring the selector uses is present. Same
# string operation the selection loop performs, so the two cannot drift.
survivor_unmovable() { # <series> -> 0 when no mode can ever move this verdict
  [ -n "$1" ] || return 0                      # legacy: only --legacy-through
  _u_rest="$1"
  while [ -n "$_u_rest" ]; do
    case "$_u_rest" in
      *-*) _u_field="${_u_rest%%-*}"; _u_rest="${_u_rest#*-}" ;;
      *)   _u_field="$_u_rest"; _u_rest="" ;;
    esac
    # A sprint token is `s` followed by digits ONLY -- the same shape --sprint
    # validation accepts, minus its `s[0-9]*` looseness.
    case "$_u_field" in
      s*) _u_n="${_u_field#s}" ;;
      *)  continue ;;
    esac
    [ -n "$_u_n" ] || continue
    case "$_u_n" in *[!0-9]*) continue ;; esac
    # The selector's exact test, on the whole id.
    case "$1" in *"-${_u_field}-"*) return 1 ;; esac
  done
  return 0
}

# ---------------------------------------------------------------------------
# UNMATCHABLE SERIES IDS: a refusal on an empty --sprint selection, a WARN on a
# non-empty one, and the `--series` escape that clears both. See the header.
#
# STANDALONE BY DESIGN, NOT ROUTED THROUGH THE SURVIVOR BLOCK BELOW. That block
# asks whether the NEWEST verdict left behind FAILs; this one asks whether ANY
# unmatchable series records a FAIL, wherever it sorts. Keyed on the survivor it
# would pass the reference consumer's s318 close, whose newest unmatchable verdict
# PASSes while two older s318 verdicts in FAIL-carrying series stay live.
# ---------------------------------------------------------------------------
if [ -n "$SERIES" ] && ! survivor_unmovable "$SERIES"; then
  echo "${SELF_NAME}: --series '${SERIES}' carries a -s<N>- token, so --sprint already selects it;" >&2
  echo "  run --sprint with that sprint instead. --series is only for ids no --sprint can name." >&2
  exit 2
fi

# The verdicts whose non-empty series id no --sprint selector can name, as
# "<series>\t<file>" rows. A legacy verdict has no row here: --legacy-through owns it.
# fail_series lists every such id with at least one member recording a FAIL; the
# whole series is then FAIL-carrying, so a retry that PASSes does not split it.
: > "$TMPD/unmatchable"
: > "$TMPD/fail_series"
while IFS="$(printf '\t')" read -r _um_series _um_file; do
  [ -n "$_um_series" ] || continue
  survivor_unmovable "$_um_series" || continue
  printf '%s\t%s\n' "$_um_series" "$_um_file" >> "$TMPD/unmatchable"
  _um_fc="$(jq -r '[.verdicts[]? | select(.verdict=="FAIL")] | length' "$_um_file" 2>/dev/null)" || _um_fc=0
  [ "${_um_fc:-0}" != 0 ] && printf '%s\n' "$_um_series" >> "$TMPD/fail_series"
done < "$TMPD/series_rows"
# Partition the rows by series: FAIL-carrying series refuse an empty selection,
# PASS-only series only WARN. A per-row grep, never an awk NR==FNR join, which
# misreads its second file as the first when fail_series is empty.
: > "$TMPD/unmatchable_fail"
: > "$TMPD/unmatchable_pass"
while IFS="$(printf '\t')" read -r _pt_series _pt_file; do
  if grep -qxF -- "$_pt_series" "$TMPD/fail_series"; then
    printf '%s\t%s\n' "$_pt_series" "$_pt_file" >> "$TMPD/unmatchable_fail"
  else
    printf '%s\t%s\n' "$_pt_series" "$_pt_file" >> "$TMPD/unmatchable_pass"
  fi
done < "$TMPD/unmatchable"
N_UM_FAIL="$(grep -c . "$TMPD/unmatchable_fail" 2>/dev/null)" || N_UM_FAIL=0
N_UM_PASS="$(grep -c . "$TMPD/unmatchable_pass" 2>/dev/null)" || N_UM_PASS=0

# Each archived sprint's nonce range, "<N>\t<min>\t<max>", sorted by N. Read only
# to print a HINT; nothing below applies it.
archive_ranges() {
  for _ar_dir in "$STATE_DIR/implementation-artifacts"/s*/gate-adjudication; do
    [ -d "$_ar_dir" ] || continue
    _ar_s="$(basename "$(dirname "$_ar_dir")")"
    _ar_n="${_ar_s#s}"
    case "$_ar_n" in ''|*[!0-9]*) continue ;; esac
    _ar_min=""; _ar_max=""
    for _ar_f in "$_ar_dir"/*.verdict.json; do
      [ -e "$_ar_f" ] || continue
      _ar_ts="$(conforming_nonce "$(basename "$_ar_f" .verdict.json)")" || continue
      { [ -z "$_ar_min" ] || [ "$_ar_ts" \< "$_ar_min" ]; } && _ar_min="$_ar_ts"
      { [ -z "$_ar_max" ] || [ "$_ar_ts" \> "$_ar_max" ]; } && _ar_max="$_ar_ts"
    done
    [ -n "$_ar_min" ] && printf '%s\t%s\t%s\n' "$_ar_n" "$_ar_min" "$_ar_max"
  done | sort -n
}

# hint_sprint <series> <oldest-member-nonce> -> "<sprint>\t<why>". A hint is given
# only when exactly ONE sprint is possible; otherwise the sprint is "s<N>" (the
# literal placeholder, which --sprint validation rejects, so an unknown sprint
# cannot be run by accident) and <why> opens with "NO HINT". See the header.
hint_sprint() {
  _h_rest="$1"
  while [ -n "$_h_rest" ]; do
    case "$_h_rest" in
      *-*) _h_field="${_h_rest%%-*}"; _h_rest="${_h_rest#*-}" ;;
      *)   _h_field="$_h_rest"; _h_rest="" ;;
    esac
    case "$_h_field" in
      s[0-9]*) case "${_h_field#s}" in *[!0-9]*) ;; *)
        printf '%s\t%s\n' "$_h_field" "the id itself carries the token '${_h_field}'"; return 0 ;; esac ;;
    esac
  done
  _h_ts="$2"
  if [ ! -s "$TMPD/ranges" ]; then
    printf '%s\t%s\n' "$SPRINT" "no sprint archive exists yet, so the sprint being closed"; return 0
  fi
  [ -n "$_h_ts" ] || { printf 's<N>\t%s\n' "NO HINT (its stem carries no nonce) -- pick the sprint"; return 0; }
  # _h_n/_h_max: the highest archive whose range opens at or before the nonce.
  # _h_hi: the next archived sprint above it, if any.
  _h_n=""; _h_max=""; _h_hi=""; _h_first=""
  while IFS="$(printf '\t')" read -r _r_n _r_min _r_max; do
    [ -n "$_h_first" ] || _h_first="$_r_n"
    if [ ! "$_r_min" \> "$_h_ts" ]; then
      _h_n="$_r_n"; _h_max="$_r_max"; _h_hi=""
    elif [ -z "$_h_hi" ]; then
      _h_hi="$_r_n"
    fi
  done < "$TMPD/ranges"
  if [ -z "$_h_n" ]; then
    printf 's<N>\t%s\n' "NO HINT (..s$(( _h_first - 1 ))): nonce ${_h_ts} predates every sprint archive -- pick the sprint"; return 0
  fi
  if [ ! "$_h_ts" \> "$_h_max" ]; then
    printf 's%s\t%s\n' "$_h_n" "nonce ${_h_ts} falls inside s${_h_n}'s archived range"; return 0
  fi
  _h_lo=$(( _h_n + 1 ))
  if [ -n "$_h_hi" ]; then
    _h_top=$(( _h_hi - 1 ))
    _h_where="between s${_h_n}'s archive and s${_h_hi}'s"
  else
    _h_top="${SPRINT#s}"
    case "$_h_top" in ''|*[!0-9]*) _h_top=-1 ;; esac
    _h_where="newer than s${_h_n}'s archive, the newest, closing ${SPRINT}"
  fi
  if [ "$_h_top" -eq "$_h_lo" ]; then
    printf 's%s\t%s\n' "$_h_lo" "nonce ${_h_ts} is ${_h_where}, and s${_h_lo} is the only sprint in that window"; return 0
  fi
  if [ "$_h_top" -gt "$_h_lo" ]; then
    printf 's<N>\t%s\n' "NO HINT (s${_h_lo}..s${_h_top}): nonce ${_h_ts} is ${_h_where} -- pick the sprint"; return 0
  fi
  # An empty window: the archive below the nonce is itself incomplete, so it and
  # the one above are the candidates.
  printf 's<N>\t%s\n' "NO HINT (s${_h_n}..s${_h_hi:-${SPRINT#s}}): nonce ${_h_ts} is ${_h_where}, and no sprint lies strictly between -- pick the sprint"
}

# print_series_commands <rows-file>: one dry-run `--series` command per distinct id
# in "<series>\t<file>" rows, OLDEST SERIES FIRST (ordered by each id's newest
# member), so the newest verdict stays live until its own series is the one moving.
print_series_commands() {
  archive_ranges > "$TMPD/ranges"
  : > "$TMPD/series_ts"
  while IFS="$(printf '\t')" read -r _p_series _p_file; do
    _p_ts="$(conforming_nonce "$(basename "$_p_file" .verdict.json)")" || _p_ts=""
    printf '%s\t%s\n' "$_p_series" "$_p_ts" >> "$TMPD/series_ts"
  done < "$1"
  awk -F'\t' '{ if (!($1 in mn) || $2 < mn[$1]) mn[$1]=$2; if (!($1 in mx) || $2 > mx[$1]) mx[$1]=$2 }
              END { for (k in mx) printf "%s\t%s\t%s\n", mx[k], mn[k], k }' "$TMPD/series_ts" \
    > "$TMPD/series_order_raw"
  sort "$TMPD/series_order_raw" > "$TMPD/series_order"
  while IFS="$(printf '\t')" read -r _p_max _p_min _p_series; do
    _p_hint="$(hint_sprint "$_p_series" "$_p_min")"
    _p_sprint="${_p_hint%%	*}"; _p_why="${_p_hint#*	}"
    echo "    ${SELF_CMD} --sprint ${_p_sprint} --series '$(shq "$_p_series")'" >&2
    case "$_p_why" in
      "NO HINT"*) echo "        ${_p_why}" >&2 ;;
      *)          echo "        sprint is a HINT, not a finding: ${_p_why}" >&2 ;;
    esac
  done < "$TMPD/series_order"
}

warn_pass_only() { # <rows-file> <count>
  echo "${SELF_NAME}: WARN -- $2 verdict(s) carry a gate_series_id no --sprint selector can match and stay live;" >&2
  echo "  none of their series records a FAIL, so the guard reads them as clean:" >&2
  cut -f2 "$1" | sed 's/^/    /' >&2
  echo "  This run still proceeds. To move them, run each command below (a dry run), confirm" >&2
  echo "  its sprint, then add --apply, in the order printed:" >&2
  print_series_commands "$1"
}

if [ "$N_FILES" -eq 0 ]; then
  if [ -z "$LEGACY_THROUGH" ] && [ -z "$SERIES" ] && [ "$N_UM_FAIL" -gt 0 ]; then
    echo "${SELF_NAME}: REFUSED -- no verdict names series '${SPRINT}', and ${N_UM_FAIL} verdict(s) carry a" >&2
    echo "  gate_series_id no --sprint selector can match, in a series that records a FAIL, so this" >&2
    echo "  sprint's verdicts may be among them:" >&2
    cut -f2 "$TMPD/unmatchable_fail" | sed 's/^/    /' >&2
    echo "  An empty-selection exit 0 here would let the retro pass while every one of them" >&2
    echo "  stayed live for the gate-remediation guard. Nothing written." >&2
    echo "" >&2
    echo "  THE REMEDY IS ONE --series MOVE PER ID. Run each command below as printed (a dry" >&2
    echo "  run), confirm its sprint, then add --apply. Run them in the order printed. A line" >&2
    echo "  marked NO HINT names no sprint; ask the operator which sprint it belongs to:" >&2
    print_series_commands "$TMPD/unmatchable_fail"
    echo "  Then re-run this command. Report the writer that stamped these ids too: it will" >&2
    echo "  keep producing verdicts no --sprint can move." >&2
    if [ "$N_UM_PASS" -gt 0 ]; then
      echo "" >&2
      warn_pass_only "$TMPD/unmatchable_pass" "$N_UM_PASS"
    fi
    exit 1
  fi
  if [ -z "$LEGACY_THROUGH" ] && [ -z "$SERIES" ] && [ "$N_UM_PASS" -gt 0 ]; then
    warn_pass_only "$TMPD/unmatchable_pass" "$N_UM_PASS"
  fi
  if [ -n "$SERIES" ]; then
    echo "${SELF_NAME}: no verdict under '${SRC}' carries series id '${SERIES}' -- nothing to move."
  else
    echo "${SELF_NAME}: no verdict under '${SRC}' names series '${SPRINT}' -- nothing to move."
  fi
  exit 0
fi

SURVIVOR_STEM=""; SURVIVOR_TS=""; SURVIVOR_FAILS=""; SURVIVOR_UNMOVABLE=0; SURVIVOR_WHY=""
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
    if survivor_unmovable "$_series"; then
      SURVIVOR_UNMOVABLE=1
      if [ -n "$_series" ]; then
        SURVIVOR_WHY="its gate_series_id '${_series}' matches no --sprint selector"
      else
        SURVIVOR_WHY="it carries no gate_series_id"
      fi
    else
      SURVIVOR_UNMOVABLE=0; SURVIVOR_WHY=""
    fi
  fi
done

if [ "$SURVIVOR_UNMOVABLE" -eq 1 ] && [ -n "$SURVIVOR_FAILS" ]; then
  echo "${SELF_NAME}: REFUSED -- this rotation would strand a FAILing verdict no mode can move." >&2
  echo "  Newest verdict left in '${SRC}' after this move:" >&2
  echo "    ${SURVIVOR_STEM} -- ${SURVIVOR_WHY}; FAILed check(s): ${SURVIVOR_FAILS}" >&2
  echo "  The gate-remediation guard picks its live pass by trailing nonce with no notion of" >&2
  echo "  sprint, so that verdict would become the live pass and deny artifact edits, and the" >&2
  echo "  deny would not clear on its own. Nothing written." >&2
  echo "" >&2
  # THE REMEDY DIFFERS BY CASE AND MUST NOT BE PRINTED UNCONDITIONALLY. A
  # --legacy-through run cannot move a verdict that HAS a series id, so printing
  # it for that case would be a second inert remedy -- the defect this block was
  # already corrected for once.
  if [ -z "$(jq -r '.gate_series_id // empty' "${SRC}/${SURVIVOR_STEM}.verdict.json" 2>/dev/null)" ]; then
    echo "  THE REMEDY IS TO ROTATE THE PRE-SERIES VERDICTS OUT, then re-run this command:" >&2
    echo "    ${SELF_CMD} --legacy-through ${SURVIVOR_TS} --apply" >&2
  else
    # --series is the mechanical remedy for this case. Before it existed this
    # branch said there was none, which was true then and is false now.
    _sv_series="$(jq -r '.gate_series_id // empty' "${SRC}/${SURVIVOR_STEM}.verdict.json" 2>/dev/null)"
    echo "  Its gate_series_id is well-formed by the schema, which leaves the field" >&2
    echo "  deliberately unpatterned, but no --sprint selector can name it and" >&2
    echo "  --legacy-through skips it because it HAS a series id. THE REMEDY IS TO MOVE" >&2
    echo "  THAT SERIES BY ITS EXACT ID into the sprint it belongs to, then re-run this command:" >&2
    echo "    ${SELF_CMD} --sprint s<N> --series '$(shq "$_sv_series")' --apply" >&2
    echo "  Or Re-stamp that verdict's gate_series_id in the '<gate_type>-s<N>-<nonce>' form" >&2
    echo "  its siblings use. Either way, report the writer that stamped it, because it will" >&2
    echo "  keep producing verdicts no --sprint can move." >&2
  fi
  echo "" >&2
  echo "  A SIDECAR DOES NOT LIFT THIS. The guard's repair and authorization records are" >&2
  echo "  read by the GUARD, not by this rotator, so writing one changes nothing here --" >&2
  echo "  an earlier revision of this message prescribed exactly that and it was inert." >&2
  echo "  Deferring until the next sprint's first verdict lands also only moves the block:" >&2
  echo "  it clears this close and refuses the following one, one sprint behind forever." >&2
  exit 1
fi

# WARN, never refuse, on a non-empty selection: this sprint's tagged verdicts
# move, and the unmatchable ones (minus any this --series run moves) stay live.
: > "$TMPD/unmatchable_left"
while IFS="$(printf '\t')" read -r _w_series _w_file; do
  grep -qxF "$(basename "$_w_file" .verdict.json)" "$TMPD/move_stems" 2>/dev/null && continue
  printf '%s\t%s\n' "$_w_series" "$_w_file" >> "$TMPD/unmatchable_left"
done < "$TMPD/unmatchable"
N_LEFT="$(grep -c . "$TMPD/unmatchable_left" 2>/dev/null)" || N_LEFT=0
if [ -z "$LEGACY_THROUGH" ] && [ "$N_LEFT" -gt 0 ]; then
  echo "${SELF_NAME}: WARN -- ${N_LEFT} verdict(s) carry a gate_series_id no --sprint selector can match and stay live:" >&2
  cut -f2 "$TMPD/unmatchable_left" | sed 's/^/    /' >&2
  echo "  This run still proceeds. To move them, run each command below (a dry run), confirm" >&2
  echo "  its sprint, then add --apply, in the order printed:" >&2
  print_series_commands "$TMPD/unmatchable_left"
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

# REFUSAL: a destination file already exists. `mv` would replace it silently,
# and the size check after the move compares source with destination, so it cannot
# see what was lost. Checked over the whole move set before the first write.
: > "$TMPD/clobber"
while IFS= read -r name; do
  [ -n "$name" ] || continue
  if [ -e "$DEST/$name" ]; then printf '%s\n' "$DEST/$name" >> "$TMPD/clobber"; fi
done < "$TMPD/move_files"
N_CLOBBER="$(grep -c . "$TMPD/clobber" 2>/dev/null)" || N_CLOBBER=0
if [ "$N_CLOBBER" -gt 0 ]; then
  echo "${SELF_NAME}: REFUSED -- ${N_CLOBBER} destination file(s) already exist and would be overwritten:" >&2
  sed 's/^/    /' "$TMPD/clobber" >&2
  echo "  Compare each with its live namesake under '${SRC}' and remove whichever is not" >&2
  echo "  the record to keep, then re-run. Nothing written." >&2
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
