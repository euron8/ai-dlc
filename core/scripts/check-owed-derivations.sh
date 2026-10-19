#!/usr/bin/env bash
# check-owed-derivations.sh — which derivations did an earlier pull LEAVE broken, and are they still?
#
# Usage: check-owed-derivations.sh [<record>]
#        check-owed-derivations.sh --scope <rel-path>        (prints CURRENT | LIVING | PAST | HISTORY)
#        check-owed-derivations.sh --scope-batch < paths     (one `<TOKEN><TAB><path>` per input line)
#   <record> defaults to `_bmad-output/ai-dlc-update/owed-derivations.tsv` under the project root,
#   which is the file `reconcile/derivation-differential.sh --record-owed` appends to.
#
# Output on STDOUT, one tab-separated line per row:
#   OPEN <key file:line> <reason> <$ command> <base>..<theirs> <reconcile log name>
#       <reason> is STALE | UNRUN | SUPERSEDED-STALE | MOVED | UNASSESSED, prefixed REPOINTED- when
#       the row was re-pointed and the NEW derivation is the one judged (its command is shown).
#   INFO history <key> <detail>
#       a row whose file is a HISTORY file (see the set below). Same behaviour as past-sprint.
#   INFO past-sprint <key> <detail>
#       a row whose file is in a sprint that has since finished. Unrepaired debt that is no longer
#       enforced. It is NOT closed, and it never counts toward exit 1.
#   UNMEASURED: no owed-derivations record at <rel path>; ...
#   UNMEASURED: owed-derivations record at <rel path> is present with 0 OWED rows; ...
#       the two cases in which no OPEN line is NOT a measurement of nothing owed: no record exists, or
#       the record holds no OWED row (it is empty, or carries only REPOINTED rows). Neither is a failure
#       and neither changes the exit, so a tree with no reconcile yet is never wedged at its gate. The
#       two texts differ, so the reader can tell "never recorded" from "recorded, nothing owed".
# Exit:   0 no open row. Prints an UNMEASURED line when there was no record or it held no OWED row;
#           a record with OWED rows none of which is OPEN exits 0 silently
#         1 one or more OPEN rows
#         2 the record is unreadable or malformed, or the current sprint cannot be resolved. A
#           REFUSAL, distinct from an absent record: an absent record owes nothing, an unreadable one
#           has not been shown to owe nothing.
#
# RECORD GRAMMAR (append-only, no status cell, tab-separated):
#   OWED        <key file:line> <command> <recorded> <actual> <base>..<theirs> <log>   (the writer)
#   REPOINTED   <old key> <new file:line> $ <new command>                                (the re-pointer)
# A REPOINTED row names where a derivation went. It closes nothing by itself: the reader follows the
# LATEST REPOINTED for a key (and the latest for that target, and so on) and JUDGES THE NEW DERIVATION
# with the same content-location and fenced check, on every read.
#
# SCOPE IS CURRENT SPRINT ONLY (operator ruling). `--scope <rel-path>` prints CURRENT | LIVING | PAST and
# is the ONE definition: the writer (reconcile/derivation-differential.sh --record-owed) calls it for each
# NEWLY-FAILING row, and this script calls it for each row on read, so a row recorded while its sprint was
# current reads INFO once the sprint rolls. Only OPEN rows block anything.
#
# OPENNESS IS DERIVED FROM THE TREE, NEVER FROM THE RECORD. A row is open iff the installed validator,
# re-run on that row's OWN file, still reports that derivation failing. It closes by re-pointing the
# derivation, never by writing a word, so prose saying "done" beside a still-failing derivation changes
# nothing.
#
# THE VERDICT STREAM IS STDERR, AND A REPRODUCING DERIVATION PRINTS NOTHING ON IT. So "no line for this
# key" means closed only when the key names a real `$ ` command line inside a derived fence. The row is
# therefore LOCATED BY CONTENT: the `$ ` lines inside a derived fence whose text equals the command.
# Zero matches: MOVED (open). One: that line is judged, so a shifted line is tolerated. Several: the
# recorded line number breaks the tie when it is one of them; otherwise the row cannot be placed and the
# run refuses with exit 2. A command in a text fence is no match, because the validator never reads it.
#
# JOIN RULE for the located line K, in order:
#   (a) the validator exited 2 over K's file: unassessed (UNASSESSED), open, never closed. An UNRUN
#       derivation anywhere in that file makes the validator exit 2, so it unassesses EVERY owed row in
#       the file; run or remove that derivation;
#   (b) K is named by `SUPERSEDED: <f>:<K> by <f>:<later>` on stderr: open iff a FAIL or UNRUN line
#       exists for <later>, the copy that actually ran;
#   (c) otherwise open iff a FAIL or UNRUN line exists for K.
set -uo pipefail

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of `..` hops: this
# script runs from core/scripts/ (distribution) and scripts/ai-dlc/ (consumer). Inline on purpose, as
# in every sibling that needs it, because locating a shared lib is the same unsolved problem. Precedence:
# override -> walk up from this script -> CLAUDE_PROJECT_DIR -> walk up from cwd -> exit 2.
ai_dlc_resolve_root() {
    local d="$1"
    while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
        if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
            printf '%s\n' "$d"; return 0
        fi
        d="$(dirname "$d")"
    done
    return 1
}
CO_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CO_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$CO_ROOT" ] || CO_ROOT="$(ai_dlc_resolve_root "$CO_SCRIPT_DIR" || true)"
[ -n "$CO_ROOT" ] || CO_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$CO_ROOT" ] || CO_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$CO_ROOT" ] || { echo "REFUSED: cannot resolve the project root; set AI_DLC_PROJECT_ROOT." >&2; exit 2; }
# --- end AI_DLC_ROOT --------------------------------------------------------
SELF_DIR="$CO_SCRIPT_DIR"
ROOT="$CO_ROOT"

# ---- the scope classifier: ONE place ------------------------------------------------------------
# A SLOT is any whole `s<digits>` path COMPONENT anywhere under `_bmad-output/`, derived from the path
# grammar: core/scripts/validate-artifact-paths.sh:167 and :241 match `s[0-9]+` against a whole path
# COMPONENT, and its SLOT_RE (:125, from `artifact-path-config.sh --slot-re`) is `^s[0-9]+$`. This script
# cannot obtain SLOT_RE from that config without walking from one core file to another (I33), so the
# expression is copied here and BOUND to `--slot-re` by a dist-only battery arm. The FILENAME is never a
# slot (the basename is dropped first), a directory `s319x/` or `s5-notes/` is no slot, and a path carrying
# several slot components uses the FIRST one under `_bmad-output/`. A path with no slot is LIVING (prd.md).
SLOT_RE='^s[0-9]+$'

# The current sprint comes ONLY from sprint-status.sh sprint-id, a sibling of this script (installed at
# scripts/ai-dlc/ beside it, in the distribution at core/scripts/). Unresolved is a refusal: a scope is
# never guessed and never defaulted to PAST.
CUR=""
resolve_sprint() {
  local ss="$SELF_DIR/sprint-status.sh" out
  [ -f "$ss" ] || { echo "REFUSED: no sprint-status.sh beside $0, so the current sprint cannot be resolved. A scope is never guessed." >&2; exit 2; }
  out="$(AI_DLC_PROJECT_ROOT="$ROOT" bash "$ss" sprint-id --root "$ROOT" 2>/dev/null)" \
    || { echo "REFUSED: sprint-status.sh sprint-id failed, so the current sprint cannot be resolved. A scope is never guessed." >&2; exit 2; }
  out="$(printf '%s' "$out" | tr -d '[:space:]')"
  case "$out" in
    ''|*[!0-9]*) echo "REFUSED: sprint-status.sh sprint-id printed '${out}', not a sprint number, so the current sprint cannot be resolved." >&2; exit 2 ;;
  esac
  CUR="$out"
}

# sprint_split <path>: sets SP_N (the sprint number) and SP_REST (the path below the slot directory) and
# returns 0 when the directory part of <path> carries a slot component under `_bmad-output/`; else 1.
SP_N=""; SP_REST=""
sprint_split() {
  local p="$1" d seg
  SP_N=""; SP_REST=""
  case "$p" in _bmad-output/*/*) ;; *) return 1 ;; esac
  d="${p%/*}"; d="${d#_bmad-output/}"
  [ "$d" != "${p%/*}" ] || return 1
  while :; do
    seg="${d%%/*}"
    # SLOT_RE `^s[0-9]+$` as a case, so no fork is paid per component (the battery binds the two).
    case "$seg" in
      s[0-9]*) case "${seg#s}" in *[!0-9]*) ;; *) SP_N="${seg#s}"; SP_REST="${p#*/"$seg"/}"; return 0 ;; esac ;;
    esac
    case "$d" in */*) d="${d#*/}" ;; *) break ;; esac
  done
  return 1
}

# THE HISTORY SET (lead ruling): paths an ai-dlc program WRITES as history, plus every `archive` directory.
# EXACT matches only: no substring and no suffix matching (a `*-history.md` or `*-archive*.md` glob also
# caught `s<N>/requirements-history.md`, `stories/story-3-archive-cleanup.md` and `data-archive-policy.md`,
# which are live). A history path is never enforced, never recorded and never carried, WHEREVER it sits, so
# it is checked FIRST and a history file inside the current sprint's s<N>/ is still HISTORY. Citations,
# re-verified by grep at the tip:
#   (i) any directory component named exactly `archive` under `_bmad-output/`: `planning-artifacts/archive/**`
#       (core/scripts/migrate-artifact-paths.sh:18) and `s<N>/archive/**` (core/scripts/validate-artifact-budget.sh
#       :1362-1368). `archived/` and `archive-notes/` are no `archive` component.
#   (ii) exact writer-produced names:
#   - THE FOUR HISTORY COMPANIONS, on their own line of the case below: `prd-history.md`,
#     `product-brief-history.md`, `carry-over-backlog-archive.md` and `architecture-history.md`. The writer
#     names them at core/skills/ai-dlc/SKILL.md (the `<live> -> <history>` pairs under "Current-state live,
#     history archive") and core/skills/ai-dlc/steps/artifact-consolidation.md:128; retro.md:651 cuts carry-over
#     items into the third. The dist-only battery derives that pair list from SKILL.md and fails when a
#     companion is missing here. Each LIVE side (`prd.md`, `carry-over-backlog.md`, ...) is NOT history.
#   - `push-candidate-ledger.archive.md`: core/skills/ai-dlc-update/reconcile/ledger-rotate.sh:136.
#   - `pipeline-history/pipeline-snapshot-archive.md`: core/scripts/rotate-snapshot-archive.sh:149.
#   - `operator-answers-history.md`: core/hooks/ai-dlc-answer-capture.sh:105 (path) and :242 (append).
#   - `operator-requests-history.md`: core/hooks/ai-dlc-pause.sh:210 (path) and :261 (append).
#   - `pipeline-snapshot-history.md`: fed by the `trim` remedy that core/scripts/validate-artifact-budget.sh:2148,
#     core/skills/ai-dlc/steps/_gate-procedures.md:71,:82 and steps/route.md:327 tell the lead to write; its path
#     is named in core/schemas/pipeline-state-paths.json, and rotate-snapshot-archive.sh:5 rotates it.
#   - the rotated gate-adjudication directories, core/scripts/rotate-gate-adjudication.sh:155-157 (header) and
#     :272 (DEST): `_bmad-output/implementation-artifacts/s<N>/gate-adjudication/**` and
#     `_bmad-output/implementation-artifacts/pre-series/gate-adjudication/**`. The LIVE
#     `_bmad-output/gate-adjudication/` (SRC, :271) is NOT history as a directory: it classifies by the
#     guard's live-nonce rule below (live stem and sidecars CURRENT, every other stem HISTORY).
#   - `_bmad-output/ai-dlc-update/reconcile-log-<ts>.md`, ts shaped `[0-9]{8}T[0-9]{4,6}Z`: written by the
#     update session itself, one per run (core/skills/ai-dlc-update/SKILL.md:2497, "YOU write ... and
#     `apply.sh` does NOT"; apply.sh:2780 confirms).
#   - `_bmad-output/planning-artifacts/implementation-readiness-report-<YYYY-MM-DD>.md`: written fresh per run by
#     BMAD's own skill `bmad-check-implementation-readiness` (outputFile
#     `{planning_artifacts}/implementation-readiness-report-{{date}}.md`). That writer is BMAD's, so it is NOT in
#     this tree and the outputFile shape is NOT checked here. ai-dlc invokes the skill from
#     core/skills/ai-dlc/steps/architecture.md:264 and core/skills/ai-dlc/steps/stories-test-strategy.md:18.
is_history() { # <root-relative path> -> 0 when HISTORY
  local p="$1" rest seg after b n
  case "$p" in
    _bmad-output/implementation-artifacts/pre-series/gate-adjudication/*) return 0 ;;
    _bmad-output/implementation-artifacts/s*/gate-adjudication/*)
      rest="${p#_bmad-output/implementation-artifacts/}"; seg="${rest%%/*}"
      case "${seg#s}" in
        ''|*[!0-9]*) ;;
        *) after="${rest#*/}"; case "$after" in gate-adjudication/*) return 0 ;; esac ;;
      esac ;;
  esac
  # (i) a WHOLE directory component named `archive` (the directory part is wrapped in slashes)
  case "$p" in _bmad-output/*) case "/${p%/*}/" in */archive/*) return 0 ;; esac ;; esac
  b="${p##*/}"
  case "$b" in
    prd-history.md|product-brief-history.md|carry-over-backlog-archive.md|architecture-history.md) return 0 ;;
    push-candidate-ledger.archive.md) return 0 ;;
    operator-answers-history.md|operator-requests-history.md|pipeline-snapshot-history.md) return 0 ;;
  esac
  # rotate-snapshot-archive.sh:149 writes the archive beside the snapshot history, in its pipeline-history
  # directory. Matched on the part below the pipeline root: this reader classifies that path and never
  # creates it, and the state-path schema is the writer's to declare.
  case "$p" in _bmad-output/*) case "${p#_bmad-output/}" in pipeline-history/pipeline-snapshot-archive.md) return 0 ;; esac ;; esac
  case "$p" in
    _bmad-output/ai-dlc-update/reconcile-log-*.md)
      n="${b#reconcile-log-}"; n="${n%.md}"
      case "$n" in
        [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9]Z) return 0 ;;
        [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9]Z) return 0 ;;
        [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z) return 0 ;;
      esac ;;
    _bmad-output/planning-artifacts/implementation-readiness-report-[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9].md) return 0 ;;
  esac
  return 1
}

# THE LIVE GATE-ADJUDICATION STEM, computed ONCE per call by the guard's own rule. This is a COPY of
# core/hooks/ai-dlc-gate-remediation-guard.sh:790-804 (step 4, "Which pass is live? ... order by nonce, never
# mtime"): over `<gate dir>/*.verdict.json`, stem = basename minus `.verdict.json`, ts = the part after the
# last `-`, keep only ts matching [0-9]{8}T[0-9]{6}Z, and the live stem is the one with the greatest ts.
# I33 forbids sourcing the hook, so the loop is copied and the dist-only battery binds the two. A file in the
# live directory is live iff its basename EQUALS the live stem or starts with `<live-stem>.` (the rotator's
# sidecar rule, rotate-gate-adjudication.sh:124-125: `<nonce-stem>.<anything>`). No conforming verdict: no
# live stem, so every file there is HISTORY.
LIVE_STEM=""
compute_live_stem() {
  local _f _stem _ts LIVE_TS=""
  LIVE_STEM=""
  for _f in "$ROOT/_bmad-output/gate-adjudication"/*.verdict.json; do
    [ -f "$_f" ] || continue
    _stem="${_f##*/}"; _stem="${_stem%.verdict.json}"
    _ts="${_stem##*-}"
    case "$_ts" in
      [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]T[0-9][0-9][0-9][0-9][0-9][0-9]Z) ;;
      *) continue ;;
    esac
    if [ "$_ts" \> "$LIVE_TS" ]; then LIVE_TS="$_ts"; LIVE_STEM="$_stem"; fi
  done
}

# classify <root-relative path>: sets SCOPE_TOKEN to HISTORY | CURRENT | PAST | LIVING. THE ONE
# CLASSIFICATION IMPLEMENTATION: --scope, --scope-batch and the reader's per-row scoping all call it,
# in-process (no fork per path). FINAL ORDER:
#   1. is_history          -> HISTORY (beats everything, including s<current>/archive/**)
#   2. live gate-adjudication with NO slot component: live-stem file -> CURRENT, any other -> HISTORY
#   3. a slot component    -> CURRENT if it equals the current sprint, else PAST
#   4. otherwise           -> LIVING
# A gate-adjudication file WITH a slot (`gate-adjudication/s303/x.md`) skips step 2 and is judged by its slot.
SCOPE_TOKEN=""
classify() {
  local p="$1" b
  if is_history "$p"; then SCOPE_TOKEN=HISTORY; return 0; fi
  case "$p" in
    _bmad-output/gate-adjudication/*)
      if ! sprint_split "$p"; then
        b="${p##*/}"
        if [ -n "$LIVE_STEM" ] && { [ "$b" = "$LIVE_STEM" ] || case "$b" in "$LIVE_STEM".*) true ;; *) false ;; esac; }; then
          SCOPE_TOKEN=CURRENT
        else
          SCOPE_TOKEN=HISTORY
        fi
        return 0
      fi ;;
  esac
  if sprint_split "$p"; then
    if [ "$((10#$SP_N))" -eq "$CUR" ]; then SCOPE_TOKEN=CURRENT; else SCOPE_TOKEN=PAST; fi
    return 0
  fi
  SCOPE_TOKEN=LIVING
}

# scope_batch [tokens]: reads root-relative paths from stdin, one per line, and prints
# `<TOKEN><TAB><path>` per line in input order (just `<TOKEN>` with an argument). The sprint is resolved
# ONCE. Empty stdin: exit 0, no output. A blank line, or a resolver failure: exit 2 and NO partial
# stdout, because the output is staged in a file and printed only after every line classified.
SB_DIR=""
sb_cleanup() { [ -n "$SB_DIR" ] && { rm -f "$SB_DIR/in" "$SB_DIR/out" 2>/dev/null; rmdir "$SB_DIR" 2>/dev/null; }; }
scope_batch() {
  local _bp
  SB_DIR="$(mktemp -d "${TMPDIR:-/tmp}/check-owed-scope-XXXXXX")" \
    || { echo "REFUSED: could not create a scratch directory." >&2; exit 2; }
  trap sb_cleanup EXIT
  cat > "$SB_DIR/in" || { echo "REFUSED: could not read stdin." >&2; exit 2; }
  [ -s "$SB_DIR/in" ] || exit 0
  resolve_sprint
  compute_live_stem
  while IFS= read -r _bp || [ -n "$_bp" ]; do
    [ -n "$_bp" ] || { echo "REFUSED: a blank line in the --scope-batch input; no output was produced." >&2; exit 2; }
    classify "$_bp"
    if [ "${1:-}" = tokens ]; then printf '%s\n' "$SCOPE_TOKEN"; else printf '%s\t%s\n' "$SCOPE_TOKEN" "$_bp"; fi
  done < "$SB_DIR/in" > "$SB_DIR/out"
  cat "$SB_DIR/out"
}

if [ "${1:-}" = "--scope-batch" ]; then
  [ "$#" -eq 1 ] || { echo "usage: check-owed-derivations.sh --scope-batch < paths" >&2; exit 2; }
  scope_batch
  exit 0
fi
if [ "${1:-}" = "--scope" ]; then
  [ "$#" -eq 2 ] && [ -n "$2" ] || { echo "usage: check-owed-derivations.sh --scope <rel-path>" >&2; exit 2; }
  printf '%s\n' "$2" | scope_batch tokens; exit $?
fi

REC="${1:-$ROOT/_bmad-output/ai-dlc-update/owed-derivations.tsv}"

# ---- the record: absent is a visible UNMEASURED 0, unreadable or malformed is 2 -------------
# `-e` false is the ONLY absence. Anything that exists and cannot be read in full is a refusal. An absent
# record still exits 0 (a tree with no reconcile yet must not be wedged at its gate), but it no longer
# exits SILENTLY: silence is what a clean record produces too, so Check 37 could not tell "nothing owed"
# from "nothing ever measured".
case "$REC" in "$ROOT"/*) REC_REL="${REC#"$ROOT"/}" ;; *) REC_REL="$REC" ;; esac
if [ ! -e "$REC" ] && [ ! -L "$REC" ]; then
  printf 'UNMEASURED: no owed-derivations record at %s; no reconcile has recorded what it owes, so no OPEN line is not a measurement of nothing owed.\n' "$REC_REL"
  exit 0
fi
[ -f "$REC" ] && [ -r "$REC" ] \
  || { echo "REFUSED: the owed-derivations record $REC exists and cannot be read as a file, so what it owes is unknown." >&2; exit 2; }

VALIDATOR="$ROOT/scripts/ai-dlc/validate-artifact-derivations.sh"
[ -f "$VALIDATOR" ] || VALIDATOR="$SELF_DIR/validate-artifact-derivations.sh"
[ -f "$VALIDATOR" ] || { echo "REFUSED: no validate-artifact-derivations.sh beside this script or under $ROOT/scripts/ai-dlc/, so no row can be re-run." >&2; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/check-owed-derivations-XXXXXX")" \
  || { echo "REFUSED: could not create a scratch directory." >&2; exit 2; }
cleanup() { rm -f "$TMP"/* 2>/dev/null; rmdir "$TMP" 2>/dev/null; }
trap cleanup EXIT

# Copy first and compare sizes: awk's getline returns -1 on an unopenable file exactly as it returns 0
# on an empty one, so the record is read by cat, whose failure is a status.
cat "$REC" > "$TMP/rec" 2>/dev/null \
  || { echo "REFUSED: could not read $REC in full." >&2; exit 2; }
[ "$(wc -c < "$REC" 2>/dev/null | tr -d ' ')" = "$(wc -c < "$TMP/rec" | tr -d ' ')" ] \
  || { echo "REFUSED: $REC read short, so what it owes is unknown." >&2; exit 2; }

# Validate every line and emit it with \037 between fields (a tab IFS would collapse the empty
# recorded/actual cells). ONE malformed line refuses the whole record.
: > "$TMP/rows"; : > "$TMP/repoints"
awk -F'\t' -v rf="$TMP/rows" -v pf="$TMP/repoints" '
  /^[[:space:]]*$/ { next }
  {
    ok = 0; kind = 0
    if ($1 == "OWED") {
      kind = 1
      ok = (NF == 7 && $2 ~ /^.+:[0-9]+$/ && $3 != "" && $6 != "" && $7 != "")
    } else if ($1 == "REPOINTED") {
      kind = 2
      ok = (NF == 4 && $2 ~ /^.+:[0-9]+$/ && $3 ~ /^.+:[0-9]+$/ && substr($4, 1, 2) == "$ " && length($4) > 2)
    }
    if (!ok) { bad = NR; exit }
    if (kind == 1) printf "%s\037%s\037%s\037%s\037%s\037%s\n", $2, $3, $4, $5, $6, $7 > rf
    else if (kind == 2) printf "%s\037%s\037%s\n", $2, $3, substr($4, 3) > pf
  }
  END { if (bad) { print "MALFORMED " bad > "/dev/stderr"; exit 2 } }
' "$TMP/rec" 2> "$TMP/awk.err"
arc=$?
if [ "$arc" -ne 0 ]; then
  echo "REFUSED: $REC is malformed ($(tr -d '\n' < "$TMP/awk.err")): a row is not OWED with seven tab-separated fields (file:line, command, recorded, actual, range, log) or REPOINTED with four (old key, new file:line, \$ command)." >&2
  exit 2
fi

# No OWED row (an empty record, or one holding only REPOINTED rows): no scope to resolve and no validator
# to run, and no OPEN line below could ever appear, so say that the record measured nothing.
if [ ! -s "$TMP/rows" ]; then
  printf 'UNMEASURED: owed-derivations record at %s is present with 0 OWED rows; nothing was recorded as owed, so no OPEN line is not a measurement that a derivation was re-run and reproduced.\n' "$REC_REL"
  exit 0
fi
resolve_sprint
compute_live_stem

SEP="$(printf '\037')"

# ---- pass 1: scope each row and follow its REPOINTED chain to the derivation that will be judged ----
repoint_of() { # <key> -> "<new key><SEP><new command>" for the LATEST REPOINTED naming <key>, else empty
  K="$1" awk -F "$SEP" 'BEGIN { k = ENVIRON["K"] } $1 == k { n = $2; c = $3 } END { if (n != "") printf "%s\037%s", n, c }' "$TMP/repoints"
}
: > "$TMP/targets"; : > "$TMP/files.raw"
while IFS="$SEP" read -r key cmd _recd _act range logn; do
  [ -n "$key" ] || continue
  classify "${key%:*}"; sc="$SCOPE_TOKEN"
  tkey="$key"; tcmd="$cmd"; hops=0; cyc=0; seen="$SEP$key$SEP"
  while :; do
    nx="$(repoint_of "$tkey")"
    [ -n "$nx" ] || break
    hops=$((hops + 1))
    [ "$hops" -le 20 ] || { echo "REFUSED: the REPOINTED chain from $key runs past 20 hops without reaching a derivation, so it is unbounded and the row cannot be placed." >&2; exit 2; }
    tkey="${nx%%"$SEP"*}"; tcmd="${nx#*"$SEP"}"
    # A target already visited (the SAME key, a command fixed in place, or a cycle across DISTINCT keys)
    # ends the walk: the latest target is judged ONCE, by content-location of its own new command.
    case "$seen" in *"$SEP$tkey$SEP"*) break ;; esac
    seen="$seen$tkey$SEP"
  done
  printf '%s\037%s\037%s\037%s\037%s\037%s\037%s\037%s\037%s\n' "$key" "$cmd" "$range" "$logn" "$sc" "$tkey" "$tcmd" "$hops" "$cyc" >> "$TMP/targets"
  if [ "$sc" != PAST ] && [ "$sc" != HISTORY ] && [ "$cyc" = 0 ]; then printf '%s\n' "${tkey%:*}" >> "$TMP/files.raw"; fi
done < "$TMP/rows"
sort -u "$TMP/files.raw" > "$TMP/files"

# ---- run the validator ONCE per distinct file that will be judged ----------------------------
i=0
while IFS= read -r _f; do
  [ -n "$_f" ] || continue
  i=$((i + 1))
  printf '%s\n' "$_f" > "$TMP/f.$i.name"
  if [ -f "$ROOT/$_f" ]; then
    ( cd "$ROOT" && AI_DLC_PROJECT_ROOT="$ROOT" bash "$VALIDATOR" "$ROOT/$_f" > /dev/null 2> "$TMP/f.$i.err" )
    printf '%s\n' "$?" > "$TMP/f.$i.rc"
  fi
done < "$TMP/files"
nfiles="$i"

idx_of() { # <rel file> -> index, empty when none
  local j=1
  while [ "$j" -le "$nfiles" ]; do
    [ "$(cat "$TMP/f.$j.name")" = "$1" ] && { printf '%s' "$j"; return; }
    j=$((j + 1))
  done
}

# FIXED-STRING MATCHING, NEVER A REGEX BUILT FROM A PATH. A path carrying ( ) + ? { } | made a grep -E
# exit 2, which reads as "no match" and CLOSED the row. awk index() compares bytes, and the prefix
# travels by ENVIRON because awk -v strips one level of backslash escaping.
verdict_has() { # <stderr file> <fail|unrun|any> <prefix after the head>
  P="$3" awk -v kind="$2" 'BEGIN { p = ENVIRON["P"] }
    kind != "unrun" && match($0, /^FAIL \([A-Z-]+\): /) && index(substr($0, RLENGTH + 1), p) == 1 { f = 1 }
    kind != "fail" && substr($0, 1, 7) == "UNRUN: " && index(substr($0, 8), p) == 1 { f = 1 }
    END { exit f ? 0 : 1 }' "$1"
}
superseded_by() { # <stderr file> <abs:ln> -> the later line number, empty when not superseded
  P="SUPERSEDED: $2 by ${2%:*}:" awk 'BEGIN { p = ENVIRON["P"] }
    index($0, p) == 1 { r = substr($0, length(p) + 1); if (r ~ /^[0-9]+$/) { print r; exit } }' "$1"
}
# derived_cmd_lines <file> <command> -> the line number of every `$ ` line that sits inside a derived
# fence and whose text equals <command>. A command in any other fence (a text fence) is one the
# validator never reads, so it has no verdict at all and is not a match. The command travels by
# ENVIRON (awk -v strips a level of backslash escaping) and is compared with ==, never as a regex.
derived_cmd_lines() {
  C="$2" awk 'BEGIN { st = 0; fc = sprintf("%c%c%c", 96, 96, 96); want = ENVIRON["C"] }
    { t = $0; sub(/^[ \t]+/, "", t); sub(/[ \t\r]+$/, "", t) }
    st == 0 && substr(t, 1, 3) == fc { st = (t == fc "derived") ? 2 : 1; next }
    st != 0 && substr(t, 1, 3) == fc { st = 0; next }
    st == 2 && substr(t, 1, 2) == "$ " && substr(t, 3) == want { print NR }' "$1"
}

# ---- pass 2: judge ----------------------------------------------------------------------------
nopen=0
while IFS="$SEP" read -r key cmd range logn sc tkey tcmd hops cyc; do
  [ -n "$key" ] || continue
  if [ "$sc" = HISTORY ]; then
    printf 'INFO\thistory\t%s is in a history file (an archive, or an ai-dlc rotation output): unrepaired debt that is no longer enforced, NOT closed ($ %s; %s; %s)\n' "$key" "$cmd" "$range" "$logn"
    continue
  fi
  if [ "$sc" = PAST ]; then
    printf 'INFO\tpast-sprint\t%s recorded in a sprint that has since finished: unrepaired debt that is no longer enforced, NOT closed ($ %s; %s; %s)\n' "$key" "$cmd" "$range" "$logn"
    continue
  fi
  rel="${tkey%:*}"; ln="${tkey##*:}"
  pre=""; [ "$hops" -gt 0 ] && pre="REPOINTED-"
  reason=""
  # THE DERIVATION IS LOCATED BY CONTENT, NOT BY LINE NUMBER (see the header). A re-pointed row is judged
  # as the NEW derivation: its own file, its own command, the same checks.
  found=""; nfound=0
  if [ "$cyc" != 1 ] && [ -f "$ROOT/$rel" ]; then
    found="$(derived_cmd_lines "$ROOT/$rel" "$tcmd")" \
      || { echo "REFUSED: could not scan $rel for the recorded command, so the row $key cannot be placed." >&2; exit 2; }
    [ -n "$found" ] && nfound="$(printf '%s\n' "$found" | awk 'END { print NR + 0 }')"
  fi
  if [ "$nfound" -gt 1 ]; then
    if grep -qxF -- "$ln" <<<"$found"; then nfound=1; found="$ln"
    else echo "REFUSED: $rel carries $nfound derived-fence copies of the recorded command for $key and none is at the recorded line, so the row cannot be placed." >&2; exit 2; fi
  fi
  if [ "$nfound" -eq 0 ]; then
    reason="MOVED"
  else
    ln="$found"
    j="$(idx_of "$rel")"
    err="$TMP/f.$j.err"; abs="$ROOT/$rel"
    rc="$(cat "$TMP/f.$j.rc" 2>/dev/null)"
    if [ "$rc" != 0 ] && [ "$rc" != 1 ]; then
      reason="UNASSESSED"
    else
      target="$ln"
      sup="$(superseded_by "$err" "${abs}:${ln}")"
      if [ -n "$sup" ]; then
        target="$sup"
        verdict_has "$err" any "${abs}:${target} " && reason="SUPERSEDED-STALE"
      else
        if verdict_has "$err" fail "${abs}:${target} "; then reason="STALE"
        elif verdict_has "$err" unrun "${abs}:${target} "; then reason="UNRUN"; fi
      fi
    fi
  fi
  if [ -n "$reason" ]; then
    nopen=$((nopen + 1))
    printf 'OPEN\t%s\t%s%s\t$ %s\t%s\t%s\n' "$key" "$pre" "$reason" "$tcmd" "$range" "$logn"
  fi
done < "$TMP/targets"

[ "$nopen" -eq 0 ] && exit 0
exit 1
