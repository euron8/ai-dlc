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
#   OPEN <file:line> LIVING-STALE|LIVING-ALLOWLIST|LIVING-READS-STDIN|LIVING-UNRUN <$ command> - living-sweep
#       a LIVING-sweep row (see THE LIVING SWEEP below): no record row and no reconcile log, so the 5th
#       column is `-` and the 6th is `living-sweep`. The reason is LIVING- plus the validator's FAIL kind,
#       or UNRUN. CLOSURE: rewrite the fence in place (re-run its command, record the output, and rewrite
#       the sentence it supports). No record write closes it.
#   UNMEASURED: no owed-derivations record at <rel path>; ...
#   UNMEASURED: owed-derivations record at <rel path> is present with 0 OWED rows; ...
#       the two cases in which no OPEN line is NOT a measurement of nothing owed: no record exists, or
#       the record holds no OWED row (it is empty, or carries only REPOINTED rows). Neither is a failure
#       and neither changes the exit, so a tree with no reconcile yet is never wedged at its gate. The
#       two texts differ, so the reader can tell "never recorded" from "recorded, nothing owed".
#       The LIVING sweep still runs after either line is printed, and it decides the exit.
# Exit:   0 no open row. Prints an UNMEASURED line when there was no record or it held no OWED row;
#           a record with OWED rows none of which is OPEN exits 0 silently
#         1 one or more OPEN rows, owed or living-sweep
#         2 the record is unreadable or malformed, or the current sprint cannot be resolved, or the
#           validator's `--list` of a file to be judged fails (except over a file whose own run gave no
#           verdict, whose owed row then reads UNASSESSED), or the
#           LIVING sweep could not decide (the validator gave no verdict, or core-paths.sh or
#           `--explain-cmd` is unavailable). A REFUSAL, distinct from an absent record: an absent
#           record owes nothing, an unreadable one has not been shown to owe nothing.
#
# THE LIVING SWEEP. Operator ruling (A), 2026-10-23: "Block on ai-dlc files only". It catches a fence
# broken BEFORE any owed row existed. It runs only in reader mode, after the `--scope`/`--scope-batch`
# dispatch, so those two modes are unchanged, and it runs whether or not a record exists.
#   POPULATION: every `_bmad-output/**/*.md` carrying a ```derived opener (a fixed-string superset
#     prefilter, so no carrier is dropped), classified by `classify` below and kept only when LIVING.
#     CURRENT, PAST and HISTORY are left out. A tree with no fence needs no sprint and no validator.
#   ONE VALIDATOR CALL over the kept files, with absolute `$ROOT/<rel>` arguments, except files the
#     owed pass already ran, whose stderr is reused, so each file runs once. That call exiting 2 is a
#     refusal unless its stream carries an UNRUN line AND its one REFUSED line is the end-of-run summary;
#     every other exit-2 path abandons the files after the one it was on. FAIL and UNRUN lines are
#     parsed whatever the exit.
#   THE CORE-OPERAND PREDICATE, which decides the silent branch: a LIVING FAIL or UNRUN line is kept
#     only when at least one asked word of its command is ai-dlc core. The asked words are: the
#     validator's own `--explain-cmd -` WORD lines of class `operand` (a grep PATTERN is one, since the
#     grammar classes it so) and the `val` word of `-f`/`--file`, EXCEPT in a segment whose ARGV line
#     begins `git -C `. The validator ADMITS a `-C` directory it resolves inside the root and then prints
#     that segment's words unprefixed, as if read from the root, so those WORD lines are dropped. For
#     every `git` segment carrying `-C <dir>`, admitted or refused, the words are read off the ARGV line
#     instead: every non-option word after the subcommand, with the joined `-C` directory prefixed. The
#     `-C` directory ITSELF is never asked (lead ruling: it is where a command runs, not what it reads).
#     A `<rev>:<path>` word's path is resolved by git from the ROOT whatever the `-C`, so it is asked
#     UNprefixed, and with the directory prefixed only when it starts `./` or `../`. For each asked
#     word, and the path part of a `<rev>:<path>` word, a root-absolute `$ROOT/` prefix is dropped;
#     a word with no `/` once a trailing `/` is dropped is skipped when every core glob carries one; then
#     the word is core when `<word>/` (its trailing `/` normalised) is a literal prefix of a
#     `core-paths.sh --list` glob (a DIRECTORY that holds core files, lead ruling: the axis is ownership),
#     or when `core-paths.sh --is-core` (a SIBLING of this script, run with cwd at the root) says the
#     word, or the word with a trailing `/`, is core. So `.claude/skills/ai-dlc/steps`, `.claude/hooks`,
#     `.claude/skills` and `tests/fixtures` are core and `server/` is not; a single-component parent is
#     skipped in either spelling, `scripts` and `scripts/`, `tests` and `tests/`, `.claude` and `.claude/`
#     (lead ruling). A command NAME is never asked (an installed script run with only flags has no
#     operand). Existence is never tested, because a pull DELETES core files. Consumer-code drift stays
#     silent. A GRAMMAR fail names a fence opener, which has no command and so no operand, so it never
#     blocks.
#   THE COMMAND OF A LINE, here and in pass 2, comes from the validator's own `--list` of that file (run
#     once per file and cached, a failure is a refusal), never from a second scan of the fence grammar.
#   THE LEDGER'S SUPERSESSION, for `_bmad-output/ai-dlc-update/push-candidate-ledger.md` ONLY (its rows are
#     append-only): a FAIL or UNRUN at line K is dropped when the validator's `--list` names the same
#     command at a later line L and the same run printed no FAIL or UNRUN for L. A copy the validator does
#     not list (in an unclosed fence, an indented output line, a CRLF opener, a text fence) never runs,
#     so it acquits nothing. Every other LIVING file closes by rewriting the fence in place, and a later
#     copy there acquits nothing.
#   COLLISION: a sweep line that is the content-located line of a non-PAST, non-HISTORY OWED row, or
#     the copy that SUPERSEDED it, is that row's to report and is not printed again.
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
# key" means closed only when the key names a line the validator RUNS as a command. The row is
# therefore LOCATED BY CONTENT: the lines the validator's own `--list` of the file names with exactly
# that command (a copy in an unclosed fence, an indented output line or behind a CRLF opener is none).
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

TMP=""
make_tmp() {
  [ -n "$TMP" ] && return 0
  TMP="$(mktemp -d "${TMPDIR:-/tmp}/check-owed-derivations-XXXXXX")" \
    || { echo "REFUSED: could not create a scratch directory." >&2; exit 2; }
  trap cleanup EXIT
}
cleanup() { [ -n "$TMP" ] && { rm -f "$TMP"/* 2>/dev/null; rmdir "$TMP" 2>/dev/null; }; return 0; }
VALIDATOR=""
locate_validator() {
  [ -n "$VALIDATOR" ] && return 0
  VALIDATOR="$ROOT/scripts/ai-dlc/validate-artifact-derivations.sh"
  [ -f "$VALIDATOR" ] || VALIDATOR="$SELF_DIR/validate-artifact-derivations.sh"
  [ -f "$VALIDATOR" ] || { echo "REFUSED: no validate-artifact-derivations.sh beside this script or under $ROOT/scripts/ai-dlc/, so no row can be re-run." >&2; exit 2; }
}

# THE COMMAND LOCATOR, shared by pass 2 and the sweep. Defined ABOVE the sweep, because the sweep runs
# on the absent-record path before pass 2 is reached. A command in a text fence, in prose, or anywhere
# else the validator does not run is no match, because it has no verdict at all.
#
# THE VALIDATOR'S OWN WALK, NEVER A SECOND FENCE GRAMMAR. The commands of a file are read off the
# validator's `--list` output for that ONE file, the lines `  $ROOT/<rel>:<L>  <command>`, matched
# byte for byte. A raw scan of the file disagreed with the validator's walk_blocks on three shapes:
# a copy in a derived fence that is never closed (the validator never runs the block's last command),
# an output line indented deeper than its fence (an output line, never a command), and a CRLF opener
# (no fence at all). A copy the validator never runs has no verdict, so a raw scan read its silence
# as "reproduces". `--list` runs ONCE per file and is cached; a `--list` that fails is a refusal.
# list_of <rel>: sets LST to the cached `--list` output of <rel>. Called directly, never inside $( ),
# so its refusal exits the reader. `list_of <rel> soft` returns 1 instead of refusing: pass 2 uses it
# ONLY for a file whose own validator run already gave no verdict, whose row is UNASSESSED either way.
LST=""; LST_N=0
list_of() {
  local _j=1 _lrc
  make_tmp
  while [ "$_j" -le "$LST_N" ]; do
    if [ "$(cat "$TMP/lst.$_j.name")" = "$1" ]; then
      LST="$TMP/lst.$_j.out"
      [ "$(cat "$TMP/lst.$_j.rc")" = 0 ] && return 0
      [ "${2:-}" = soft ] && return 1
      echo "REFUSED: validate-artifact-derivations.sh --list exited $(cat "$TMP/lst.$_j.rc") on $1, so which of its lines the validator reads as a derivation command is unknown." >&2; exit 2
    fi
    _j=$((_j + 1))
  done
  LST_N=$((LST_N + 1)); LST="$TMP/lst.$LST_N.out"
  printf '%s\n' "$1" > "$TMP/lst.$LST_N.name"
  ( cd "$ROOT" && AI_DLC_PROJECT_ROOT="$ROOT" bash "$VALIDATOR" --list "$ROOT/$1" > "$LST" 2> /dev/null ); _lrc=$?
  printf '%s\n' "$_lrc" > "$TMP/lst.$LST_N.rc"
  [ "$_lrc" -eq 0 ] && return 0
  [ "${2:-}" = soft ] && return 1
  echo "REFUSED: validate-artifact-derivations.sh --list exited $_lrc on $1, so which of its lines the validator reads as a derivation command is unknown." >&2; exit 2
}
# list_cmd_lines <list file> <rel> <command> -> every line number L the listing names with exactly
# <command>. list_cmd_at <list file> <rel> <L> -> the command at L; exit 1 when L is no command.
# The prefix and the command travel by ENVIRON (awk -v strips a level of backslash escaping).
list_cmd_lines() {
  P="  $ROOT/$2:" C="$3" LC_ALL=C awk 'BEGIN { p = ENVIRON["P"]; c = ENVIRON["C"] }
    index($0, p) == 1 { r = substr($0, length(p) + 1)
      if (match(r, /^[0-9]+  /) && substr(r, RLENGTH + 1) == c) print substr(r, 1, RLENGTH - 2) }' "$1"
}
list_cmd_at() {
  P="  $ROOT/$2:$3  " LC_ALL=C awk 'BEGIN { p = ENVIRON["P"] }
    index($0, p) == 1 { print substr($0, length(p) + 1); f = 1; exit }
    END { exit f ? 0 : 1 }' "$1"
}

# ---- THE LIVING SWEEP (see the header) ------------------------------------------------------------
# THE LEDGER'S SUPERSESSION. push-candidate-ledger.md is append-only, so a stale row there is closed by
# a SUPERSEDING row, never by an edit. ledger_superseded <index> <rel> <K> <command>: 0 when the file
# holds a derived-fence copy of <command> at a line L > K and the sweep's verdict stream carries no
# FAIL or UNRUN line for (<rel>, L), so the later copy reproduced. This file ONLY: every other LIVING
# document closes by rewriting the fence in place, and a later copy there acquits nothing.
LEDGER_REL="_bmad-output/ai-dlc-update/push-candidate-ledger.md"
ledger_superseded() {
  local _L _all
  list_of "$2"
  _all="$(list_cmd_lines "$LST" "$2" "$4")" \
    || { echo "REFUSED: could not scan $2 for a superseding row, so its LIVING row cannot be judged." >&2; exit 2; }
  for _L in $_all; do
    [ "$_L" -gt "$3" ] || continue
    awk -F'\t' -v i="$1" -v l="$_L" '$1 == i && $2 == l { f = 1 } END { exit f ? 1 : 0 }' "$TMP/ls.verd" && return 0
  done
  return 1
}
# ls_accept_rc <rc> <stderr file> <what>: refuses (exit 2) unless the run is a verdict. 0 and 1 are.
# 2 is one only when the stream carries an UNRUN line AND its one REFUSED line is the end-of-run summary
# (validate-artifact-derivations.sh's `REFUSED: <n> derivation(s) did not run to completion`): every
# other exit-2 path prints its own REFUSED line and abandons each file after the one it was on, so an
# UNRUN line from an EARLIER file would otherwise acquit the files the run never reached.
ls_accept_rc() {
  local nref
  case "$1" in
    0|1) return 0 ;;
    2) nref="$(grep -c '^REFUSED: ' "$2")" || nref=0
       if grep -q '^UNRUN: ' "$2" && [ "$nref" = 1 ] \
         && grep -qE '^REFUSED: [0-9]+ derivation\(s\) did not run to completion' "$2"; then return 0; fi ;;
  esac
  echo "REFUSED: the LIVING sweep's validator run over $3 exited $1 with no verdict for every file it was given, so the LIVING documents have not been shown to reproduce." >&2
  exit 2
}
LS_OPEN=0
NL='
'
NL1="${NL}1"
living_sweep() {
  local _c _r _q _w _t _k _p _ln _kind _cmd _hit _rc _i _id _cands=0 _cache="" vrc
  local -a _batch _abs
  [ -d "$ROOT/_bmad-output" ] || return 0
  make_tmp
  ( cd "$ROOT" && find _bmad-output -type f -name '*.md' ) > "$TMP/ls.all" \
    || { echo "REFUSED: could not list the markdown files under _bmad-output/, so the LIVING sweep read nothing." >&2; exit 2; }
  # PREFILTER FIRST, so a tree with no derived fence needs no sprint and no validator. The grep is a
  # SUPERSET of what the validator reads as a fence opener, so it can drop no carrier. Batched: the
  # status of each grep is read (1 is "no match in this batch", anything above it is a refusal).
  : > "$TMP/ls.fenced"
  ls_grep() {
    ( cd "$ROOT" && grep -lF -e '```derived' -- "${_batch[@]}" ) >> "$TMP/ls.fenced"
    _r=$?
    [ "$_r" -le 1 ] || { echo "REFUSED: grep exited $_r over the _bmad-output/ markdown files, so which carry a derived fence is unknown." >&2; exit 2; }
  }
  _batch=()
  while IFS= read -r _c; do
    [ -n "$_c" ] || continue
    _batch[${#_batch[@]}]="$_c"
    if [ "${#_batch[@]}" -ge 400 ]; then ls_grep; _batch=(); fi
  done < "$TMP/ls.all"
  [ "${#_batch[@]}" -gt 0 ] && ls_grep
  [ -s "$TMP/ls.fenced" ] || return 0
  # Classify with THE ONE classifier, in-process; keep LIVING only.
  [ -n "$CUR" ] || { resolve_sprint; compute_live_stem; }
  : > "$TMP/ls.rel"; : > "$TMP/ls.abs"; : > "$TMP/ls.errs"
  _abs=()
  while IFS= read -r _c; do
    classify "$_c"
    [ "$SCOPE_TOKEN" = LIVING ] || continue
    printf '%s\n' "$_c" >> "$TMP/ls.rel"; printf '%s\n' "$ROOT/$_c" >> "$TMP/ls.abs"
    # A file the owed pass already ran is NOT run again: its own stderr is reused, so each file runs once.
    _i=""
    if [ -s "$TMP/files" ] 2>/dev/null; then _i="$(idx_of "$_c")"; fi
    if [ -n "$_i" ] && [ -f "$TMP/f.$_i.rc" ]; then
      # No refusal here: a file the validator gave no verdict for already carries an OPEN owed row
      # (UNASSESSED, or MOVED), so the reader exits 1 on it whatever this sweep decides.
      printf '%s\n' "$TMP/f.$_i.err" >> "$TMP/ls.errs"
    else
      _abs[${#_abs[@]}]="$ROOT/$_c"
    fi
  done < "$TMP/ls.fenced"
  [ -s "$TMP/ls.rel" ] || return 0
  locate_validator
  if [ "${#_abs[@]}" -gt 0 ]; then
    ( cd "$ROOT" && AI_DLC_PROJECT_ROOT="$ROOT" bash "$VALIDATOR" "${_abs[@]}" > /dev/null 2> "$TMP/ls.err" ); vrc=$?
    ls_accept_rc "$vrc" "$TMP/ls.err" "${#_abs[@]} LIVING file(s)"
    printf '%s\n' "$TMP/ls.err" >> "$TMP/ls.errs"
  fi
  # Every FAIL or UNRUN line naming a kept file, as <index>\t<line>\t<kind>, parsed whatever the exit.
  : > "$TMP/ls.verd"
  while IFS= read -r _c; do
    awk 'FNR == NR { k[++n] = $0; next }
      {
        if (match($0, /^FAIL \([A-Z-]+\): /)) { kind = substr($0, 7, RLENGTH - 9); rest = substr($0, RLENGTH + 1) }
        else if (substr($0, 1, 7) == "UNRUN: ") { kind = "UNRUN"; rest = substr($0, 8) }
        else next
        for (i = 1; i <= n; i++) {
          p = k[i] ":"
          if (index(rest, p) == 1) {
            t = substr(rest, length(p) + 1)
            if (match(t, /^[0-9]+ /)) print i "\t" substr(t, 1, RLENGTH - 1) "\t" kind
            break
          }
        }
      }' "$TMP/ls.abs" "$_c" >> "$TMP/ls.verd" \
      || { echo "REFUSED: could not parse the LIVING sweep's verdict stream." >&2; exit 2; }
  done < "$TMP/ls.errs"
  # Drop what an owed row already judged, and fetch each remaining line's command from the file itself.
  : > "$TMP/ls.cand"; : > "$TMP/ls.meta"
  while IFS="$(printf '\t')" read -r _i _ln _kind; do
    _c="$(sed -n "${_i}p" "$TMP/ls.rel")"
    if [ -f "$TMP/covered" ] && grep -qxF -- "$_c:$_ln" "$TMP/covered"; then continue; fi
    # The command is the validator's own listing of that line. A line it lists no command at (a GRAMMAR
    # fail names a fence opener) has no operand, so it can never be core.
    list_of "$_c"
    _cmd="$(list_cmd_at "$LST" "$_c" "$_ln")"; _r=$?
    case "$_r" in
      0) [ -n "$_cmd" ] || continue ;;
      1) continue ;;
      *) echo "REFUSED: could not read the validator's listing of $_c, so its LIVING row cannot be judged." >&2; exit 2 ;;
    esac
    if [ "$_c" = "$LEDGER_REL" ] && ledger_superseded "$_i" "$_c" "$_ln" "$_cmd"; then continue; fi
    _cands=$((_cands + 1))
    printf '%s\t%s\n' "$_cands" "$_cmd" >> "$TMP/ls.cand"
    printf '%s\t%s:%s\t%s\n' "$_cands" "$_c" "$_ln" "$_kind" >> "$TMP/ls.meta"
  done < "$TMP/ls.verd"
  [ "$_cands" -gt 0 ] || return 0
  # THE CORE-OPERAND PREDICATE. Operands come from the validator's own grammar; each is asked of
  # core-paths.sh --is-core, a SIBLING of this script, with cwd at the root (its manifest candidates are
  # root-relative). Unavailable is a refusal, never a silent pass.
  [ -f "$SELF_DIR/core-paths.sh" ] \
    || { echo "REFUSED: no core-paths.sh beside $0, so whether a LIVING derivation reads an ai-dlc core file cannot be decided; it is never assumed consumer-owned." >&2; exit 2; }
  ( cd "$ROOT" && AI_DLC_PROJECT_ROOT="$ROOT" bash "$VALIDATOR" --explain-cmd - < "$TMP/ls.cand" > "$TMP/ls.explain" 2>/dev/null ) \
    || { echo "REFUSED: validate-artifact-derivations.sh --explain-cmd failed, so the operands of a LIVING derivation are unknown." >&2; exit 2; }
  _i="$(awk -F'\t' '$2 == "VERDICT" { v[$1] = 1 } END { for (k in v) n++; print n + 0 }' "$TMP/ls.explain")"
  [ "$_i" = "$_cands" ] \
    || { echo "REFUSED: validate-artifact-derivations.sh --explain-cmd answered for $_i of $_cands LIVING derivation(s), so their operands are unknown." >&2; exit 2; }
  # Operands, plus the value of `-f`/`--file` (a file the command READS, such as grep's pattern file).
  # A segment whose ARGV line begins `git -C ` contributes NO WORD line: the validator admits a `-C`
  # directory it can resolve inside the root, and then prints that segment's words UNprefixed, as if
  # they were read from the root, so a `-C web` segment naming a core-looking path inside web/ would ask
  # a core path it never reads. Each segment's ARGV line precedes its WORD lines, so the flag is per segment and a
  # later segment of the same pipeline is still asked.
  awk -F'\t' '$2 == "ARGV" { gc = (substr($3, 1, 7) == "git -C ") } $2 == "WORD" && !gc && ($5 == "operand" || ($5 == "val" && ($6 == "-f" || $6 == "--file"))) { print $1 "\t" $7 }' "$TMP/ls.explain" > "$TMP/ls.ops"
  # A `git -C <dir>` segment reads its operands relative to <dir>, so its words are read off the ARGV line
  # here instead, whether the validator admitted the `-C` or refused it: each `-C` value is joined (a later
  # relative one under the earlier), the subcommand is skipped, and every later non-option word is asked
  # with the directory prefixed. The directory ITSELF is never asked (lead ruling: it is where a command
  # runs, not what it reads). A `<rev>:<path>` word's path is resolved by git from the ROOT, so it is
  # asked UNprefixed, and prefixed only when it starts `./` or `../` (git's cwd-relative spelling).
  awk -F'\t' '$2 == "ARGV" { print $1 "\t" $3 }' "$TMP/ls.explain" > "$TMP/ls.argv"
  while IFS="$(printf '\t')" read -r _id _q; do
    case "$_q" in git\ *) ;; *) continue ;; esac
    eval "set -- $_q" 2>/dev/null || continue
    shift; _gd=""
    while [ "$#" -gt 0 ]; do
      case "$1" in
        -C) [ "$#" -ge 2 ] || break; case "$2" in /*) _gd="$2" ;; *) _gd="${_gd:+${_gd%/}/}$2" ;; esac; shift 2 ;;
        -c) [ "$#" -ge 2 ] || break; shift 2 ;;
        -*) shift ;;
        *) break ;;
      esac
    done
    [ -n "$_gd" ] || continue
    [ "$#" -gt 0 ] || continue
    shift
    for _w in "$@"; do
      case "$_w" in -*|'') continue ;; esac
      case "$_w" in
        *:*) _p="${_w#*:}"
             case "$_p" in ./*) _p="${_gd%/}/${_p#./}" ;; ../*) _p="${_gd%/}/$_p" ;; esac
             printf '%s\t%q\n' "$_id" "$_p" >> "$TMP/ls.ops" ;;
        *) printf '%s\t%q\n' "$_id" "${_gd%/}/$_w" >> "$TMP/ls.ops" ;;
      esac
    done
  done < "$TMP/ls.argv"
  # A word with no `/` is skipped ONLY when every core glob carries a literal `/` outside a bracket class,
  # which this run derives from `core-paths.sh --list` rather than assumes; one slash-free glob turns the
  # shortcut off. It removes the forks for pattern operands (`grep -c alpha f`), never a path's.
  _slashless_ok=0
  ( cd "$ROOT" && AI_DLC_PROJECT_ROOT="$ROOT" bash "$SELF_DIR/core-paths.sh" --list > "$TMP/ls.globs" 2>/dev/null ) \
    || { echo "REFUSED: core-paths.sh --list failed, so the ai-dlc core set is unknown and no LIVING derivation can be judged." >&2; exit 2; }
  [ -s "$TMP/ls.globs" ] \
    || { echo "REFUSED: core-paths.sh --list printed no core glob, so the ai-dlc core set is unknown." >&2; exit 2; }
  awk '{ g = $0; gsub(/\[[^]]*\]/, "", g); if (index(g, "/") == 0) bad = 1 } END { exit bad ? 1 : 0 }' "$TMP/ls.globs" && _slashless_ok=1
  # A DIRECTORY is core when `<word>/` is a literal prefix of a core glob (lead ruling A: the axis is
  # ownership, so `ls .claude/skills/ai-dlc/steps` reads ai-dlc files). Compared in-process, no fork.
  _globsnl="$NL$(cat "$TMP/ls.globs")$NL"
  : > "$TMP/ls.core"
  while IFS="$(printf '\t')" read -r _id _q; do
    [ -n "$_q" ] || continue
    if grep -qxF -- "$_id" "$TMP/ls.core"; then continue; fi
    eval "_w=$_q" 2>/dev/null || continue
    # The word itself, a `<rev>:<path>` word's path, and the word as a directory; a root-absolute word
    # is made root-relative. String forms only: existence is never tested, because a pull DELETES core files.
    for _t in "$_w" "${_w#*:}"; do
      case "$_t" in -*|'') continue ;; esac
      _t="${_t#"$ROOT"/}"
      case "${_t%/}" in */*) ;; *) [ "$_slashless_ok" = 1 ] && continue ;; esac
      case "$_globsnl" in *"$NL${_t%/}/"*) printf '%s\n' "$_id" >> "$TMP/ls.core"; break ;; esac
      for _k in "$_t" "${_t%/}/"; do
        case "$_cache" in
          *"$NL1 $_k$NL"*) _hit=1 ;;
          *"${NL}0 $_k$NL"*) _hit=0 ;;
          *) ( cd "$ROOT" && AI_DLC_PROJECT_ROOT="$ROOT" bash "$SELF_DIR/core-paths.sh" --is-core "$_k" > /dev/null 2>&1 ); _rc=$?
             case "$_rc" in
               0) _hit=1 ;; 1) _hit=0 ;;
               *) echo "REFUSED: core-paths.sh --is-core exited $_rc on '$_k', so whether a LIVING derivation reads an ai-dlc core file cannot be decided." >&2; exit 2 ;;
             esac
             _cache="$_cache$NL$_hit $_k$NL" ;;
        esac
        if [ "$_hit" = 1 ]; then printf '%s\n' "$_id" >> "$TMP/ls.core"; break 2; fi
      done
    done
  done < "$TMP/ls.ops"
  while IFS="$(printf '\t')" read -r _id _k _kind; do
    grep -qxF -- "$_id" "$TMP/ls.core" || continue
    _cmd="$(awk -F'\t' -v n="$_id" '$1 == n { sub(/^[^\t]*\t/, ""); print; exit }' "$TMP/ls.cand")"
    LS_OPEN=$((LS_OPEN + 1))
    printf 'OPEN\t%s\tLIVING-%s\t$ %s\t-\tliving-sweep\n' "$_k" "$_kind" "$_cmd"
  done < "$TMP/ls.meta"
}
sweep_and_exit() { # <exit the owed rows decided>
  living_sweep
  [ "$1" -eq 0 ] && [ "$LS_OPEN" -eq 0 ] && exit 0
  exit 1
}

# ---- the record: absent is a visible UNMEASURED 0, unreadable or malformed is 2 -------------
# `-e` false is the ONLY absence. Anything that exists and cannot be read in full is a refusal. An absent
# record still exits 0 (a tree with no reconcile yet must not be wedged at its gate), but it no longer
# exits SILENTLY: silence is what a clean record produces too, so Check 37 could not tell "nothing owed"
# from "nothing ever measured".
case "$REC" in "$ROOT"/*) REC_REL="${REC#"$ROOT"/}" ;; *) REC_REL="$REC" ;; esac
if [ ! -e "$REC" ] && [ ! -L "$REC" ]; then
  printf 'UNMEASURED: no owed-derivations record at %s; no reconcile has recorded what it owes, so no OPEN line is not a measurement of nothing owed.\n' "$REC_REL"
  sweep_and_exit 0
fi
[ -f "$REC" ] && [ -r "$REC" ] \
  || { echo "REFUSED: the owed-derivations record $REC exists and cannot be read as a file, so what it owes is unknown." >&2; exit 2; }

locate_validator
make_tmp

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
  sweep_and_exit 0
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
  found=""; nfound=0; unlisted=0
  if [ "$cyc" != 1 ] && [ -f "$ROOT/$rel" ]; then
    # A file whose own run gave no verdict is UNASSESSED whatever its listing says, so a `--list` that
    # also fails there unassesses the row; anywhere else a failed `--list` is a refusal.
    j="$(idx_of "$rel")"; rc="$(cat "$TMP/f.$j.rc" 2>/dev/null)"
    if [ "$rc" = 0 ] || [ "$rc" = 1 ]; then list_of "$rel"
    elif ! list_of "$rel" soft; then unlisted=1; fi
    if [ "$unlisted" = 0 ]; then
      found="$(list_cmd_lines "$LST" "$rel" "$tcmd")" \
        || { echo "REFUSED: could not scan $rel for the recorded command, so the row $key cannot be placed." >&2; exit 2; }
      [ -n "$found" ] && nfound="$(printf '%s\n' "$found" | awk 'END { print NR + 0 }')"
    fi
  fi
  if [ "$nfound" -gt 1 ]; then
    if grep -qxF -- "$ln" <<<"$found"; then nfound=1; found="$ln"
    else echo "REFUSED: $rel carries $nfound derived-fence copies of the recorded command for $key and none is at the recorded line, so the row cannot be placed." >&2; exit 2; fi
  fi
  if [ "$unlisted" = 1 ]; then
    reason="UNASSESSED"
  elif [ "$nfound" -eq 0 ]; then
    reason="MOVED"
  else
    ln="$found"
    # THE COVERED SET: the line this row judged, and below, the copy that superseded it. A LIVING-sweep
    # line inside it is this row's to report and is not printed a second time.
    printf '%s:%s\n' "$rel" "$ln" >> "$TMP/covered"
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
        printf '%s:%s\n' "$rel" "$sup" >> "$TMP/covered"
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

sweep_and_exit "$nopen"
