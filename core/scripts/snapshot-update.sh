#!/usr/bin/env bash
# snapshot-update.sh -- the lead's writer for pipeline-snapshot.md: one call carries every change of
# one snapshot update, and nothing is written unless the stamp check passes on it.
#
# WHAT IT REPLACES. The lead updated the snapshot one Edit per row. Measured on graph's s319 and s320
# lead transcripts: 445 and 219 snapshot Edits (22.25 and 16.85 per story), in 298 and 123 runs of
# consecutive snapshot Edits with no other tool call between them, plus 76 and 18 Reads of the
# snapshot that Edit's read-before-edit precondition costs. One call per run is 7.35 and 7.38 fewer
# calls per story. The shell and interpreter writes the lead also used (451 python and 49 sed -i in
# s319) are already refused by the foreground-budget hook's Deny B since 0.947.0; this program is
# the sanctioned shell path that Deny B's header names.
#
# WHY IT RUNS THE STAMP CHECK ITSELF. An Edit of the snapshot reaches the derivation-capture
# PostToolUse hook, which runs `validate-artifact-budget.sh --stamps-only` on the lines the Edit
# added. A write made from inside a Bash call reaches no PostToolUse hook at all. So this program
# runs that same mode on the lines IT adds, and it runs it BEFORE the write: the candidate is built
# beside the snapshot (the check reads spawn-ledger.jsonl from the snapshot's own directory), judged,
# and moved over the snapshot only on exit 0. A finding leaves the snapshot byte-identical, which is
# stronger than the hook can be -- the hook runs after an Edit has landed.
#
# FAILS CLOSED. The validator absent, its usage refusal, an op whose target matches zero or several
# lines, a cell count that does not match the table header, a refused shape (below), or a snapshot
# changed by another writer on every retry: each is exit 2 and writes nothing. There is no path that
# writes unchecked.
#
# usage:
#   snapshot-update.sh [--snapshot <path>] <op> [<op> ...]
# ops, applied in order to one candidate. <section> is the heading text after `## ` (a prefix match
# that must hit ONE heading). A "match" is a substring that must hit exactly ONE line.
#   --activity <text>            insert `- <text>` as the newest line under Recent Activity
#   --open-item <text>           insert `- <text>` first under Open Items
#   --open-item-file <file>      insert every line of <file> first under Open Items, in file order
#   --close-item <match>         delete the ONE Open Items bullet containing <match>, with its
#                                continuation lines
#   --line-add <section> <text> [--bottom]
#                                insert <text> verbatim as the first line of the section, or after
#                                its last non-blank line with --bottom. In In-Flight Teammates a
#                                table row <text> must carry a member status cell, as --line-replace
#                                requires; a --- rule and a header into a section with no header are
#                                not judged, and a second header beside one is refused
#   --line-replace <section> <match> <text>   replace the ONE matching line, and its continuation
#                                lines when it is a wrapped bullet, with the one line <text>. In
#                                In-Flight Teammates a table row <text> must carry a member status
#                                cell (in-flight, delivered-reachable, stopped), as --row-replace
#                                requires; the header line and a --- rule are not judged
#   --line-delete <section> <match>           delete the ONE matching line and its continuation lines
#   --move-to-history <section> <match>       append the ONE matching line and its continuation
#                                lines to pipeline-snapshot-history.md FIRST, then drop them
#   A <match> is looked for in a bullet's first line only.
#   IN PIPELINE POSITION AND SPRINT CONTEXT --line-add and --line-replace refuse a `- key:` line
#                                (bold, indented and `*`/`+` spellings included): a key there is written with
#                                --set, so a key no allowlist names cannot be minted another way
#   --set <key> <value> [<section>]   rewrite the ONE line `- <key>: ...` (a bold `- **key:**`
#                                spelling matches and is rewritten canonical). Without <section> the
#                                key is resolved across the file and is never created; with it the
#                                search is inside that section and a missing key is created there.
#                                In Pipeline Position and Sprint Context a create is allowed only for
#                                a key of THE CREATE ALLOWLIST (below), and a position or sprint_id
#                                line is never created beside one already in the file
#   --section-add <heading>      add an absent section: one of the seven, or a name declared in
#                                AI_DLC_SNAPSHOT_EXTRA_SECTIONS whose name does not begin with one of
#                                the seven. Refused when a heading beginning with
#                                that name exists. In-Flight Teammates is written with its table
#                                header. One of the seven goes before the first later one of the
#                                seven, an extra section before Context Reminders; with none, at the
#                                end -- after the last table row when the file ends in In-Flight
#                                Teammates (a heading a row swallowed is re-added under that row)
#   --section-move-to-history <heading>   append the ONE section (heading prefix) and its body to
#                                pipeline-snapshot-history.md FIRST, then drop it. Refuses one of the
#                                seven, unless that heading occurs more than once (a Check 14 SCHEMA
#                                duplicate): then the LAST occurrence is the one moved
#   --row-replace <agent> <c1 | c2 | ...>   rewrite the ONE row --row-delete would find, whole;
#                                the cell count, status membership and stamp check of --row-add apply,
#                                and the new agent cell may carry no id another row carries
#   --key-delete <section> <key> delete the key line AND its continuation lines; refuses
#                                current_step_file and sprint_id
#   --set-block <section> <key> <file>   replace the key line and every continuation line with
#                                `- <key>: |` plus the lines of <file>, indented key-indent + 4
#   --row-add <c1 | c2 | ...>    append an In-Flight Teammates row; the cell count must equal the
#                                header's (`agent | role | deliverable | dispatched-at | status`);
#                                a no-op when an existing row's agent cell already carries the new
#                                row's agentId or toolu_ id AND its cells are the same; the same id
#                                with different cells is exit 2 naming --row-replace; writes the
#                                header first when the section has none
#   --row-status <agent> <status>  set the status cell of the ONE row whose agent cell's first word
#                                is <agent>; <status> is exactly in-flight, delivered-reachable or stopped
#   --row-set <agent> <col> <value>  set the cell named <col> (a header name; not `agent`) of that
#                                row; a status value takes the same membership test as --row-status
#   --row-delete <agent>         delete the ONE row whose agent cell's first word is <agent>
#   --init <step-file> <sprint-id>  render the seven-section skeleton into an EMPTY (or absent)
#                                snapshot; <step-file> must be non-empty, <sprint-id> digits
# --snapshot defaults to <root>/${AI_DLC_STATE_DIR:-_bmad-output}/pipeline-snapshot.md, the root
# found by walking up for a marker (never by counting `..`).
#
# THE SKELETON'S ONE SOURCE is render_skeleton below. steps/route.md names this op and does not
# carry a second copy of the section list. --section-add and --section-move-to-history read the
# seven names and their order from it, and the In-Flight table header.
#
# THE CREATE ALLOWLIST is every key render_skeleton writes under Pipeline Position and Sprint
# Context, plus SU_SETCREATE_EXTRA below: the keys a step file or a consumer's reset skeleton tells
# the lead to record there that the skeleton does not carry. --set and --set-block read it.
#
# THE POSITION AND SPRINT READERS. ai-dlc-continue.sh, ai-dlc-recover.sh and
# validate-mandatory-rules.sh resolve the step file from the `## Pipeline Position` bullets (their
# count grammar is bound by I113 and is never copied here); the dispatch guard reads the FIRST line
# `- sprint_id: <digits>` anywhere in the file. So no op renames or moves that heading or the
# `- current_step_file:` line shape; a key create in those two sections is --set's alone and only
# for a key of the create allowlist, and --line-add/--line-replace refuse a `- key:` line there; a key match
# tolerates leading whitespace and bold; every text-taking op refuses text beginning `#`; a line
# that reads as a position bullet (the key before the first colon, any bullet character or none, as
# the readers fallback arms and Check 8 read it) or a sprint_id line is refused unless it is the --set/--init of
# its own section; --set-block refuses content lines that read as either or begin `#`.
#
# A LOCK serializes writers: `mkdir <state dir>/.pipeline-snapshot.md.lock` (pid inside) before the
# checksum is read, released on exit; a dead holder's lock is broken. Under the lock a checksum
# change means an UNLOCKED Edit or Write landed, so the candidate is rebuilt from the new file, up
# to 3 attempts. Wait: AI_DLC_SNAPSHOT_LOCK_TENTHS tenths of a second (default 100).
#
# exit:
#   0  every op applied, the stamp check passed, the snapshot was written
#   1  the stamp check refused the candidate (its FUTURE/MALFORMED/BACKDATED/LATE lines are printed);
#      the snapshot is unchanged
#   2  a refusal: bad usage, an op matching zero or several targets, a block scalar, a refused
#      create/delete/shape, a non-member status, a non-empty --init target, no validator, the
#      snapshot moved under all 3 attempts; the snapshot is unchanged
#   3  the lock was not acquired within the wait; nothing was read or written
set -u

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of `..` hops:
# this runs from <root>/core/scripts/ and from a consumer's <root>/scripts/ai-dlc/. Inline on
# purpose, as in every script that needs it -- locating a shared lib is the same unsolved problem.
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
AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "snapshot-update: REFUSED: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root. Nothing written." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------
SU_SELF_DIR="$AI_DLC_SELF_DIR"
SU_ROOT="$AI_DLC_ROOT"

refuse() { printf 'snapshot-update: REFUSED: %s\nsnapshot-update: nothing written.\n' "$1" >&2; exit 2; }

# The status column's closed set, as the `tok == "<member>"` chain I110 extracts from this file and
# compares with the owner (validate-artifact-budget.sh). Every machine writer routes through it.
status_ok() {
  printf '%s\n' "$1" | LC_ALL=C awk '{ tok = $0
    if (tok == "in-flight") next
    if (tok == "delivered-reachable") next
    if (tok == "stopped") next
    bad = 1 } END { exit bad }'
}

# render_skeleton <step-file> <sprint-id> -- the ONE source of the seven-section skeleton.
render_skeleton() {
  cat <<SKELETON
# Pipeline Snapshot

## Pipeline Position
- current_step_file: $1
- pipeline_variant: none
- first_step_file: none
- last_completed_step_file: none
- last_gate_passed: none
- branch: none
- user_request_verbatim: |
    none
- user_request_cite: none
- bug_signal_present: none
- carryover_or_sprint_signal_present: none
- clarification_asked: none
- scope_confirmed: none
- scope_confirmed_cite: none
- scope_deferred_items: none

## Sprint Context
- sprint_id: $2
- sprint_name: none
- validation_intensity: none
- scope: none

## Recent Activity

## Open Items

## Locked Decisions

## In-Flight Teammates
agent | role | deliverable | dispatched-at | status

## Context Reminders
- context_reminders_sent: none
- last_yellow_fire_tokens: null
- last_yellow_fire_turns: null
- last_red_fire_tokens: null
- last_red_fire_turns: null
SKELETON
}

# THE CREATE ALLOWLIST's second half (header). Derived from two sources, every key a source tells
# the lead to record in Pipeline Position or Sprint Context that render_skeleton does not write:
#   the core step files -- is_ui_epic (stories-test-strategy.md Step 7, gate-validation.md Check 14),
#     stories_completed_this_sprint / stories_in_progress / stories_not_started (gate-validation.md
#     Check 14; its "current branch" is the skeleton's `branch` key, so no second key is admitted for
#     it), and resume_instruction, the name for Check 14's "handoff-only
#     resume instruction" (a bg watcher pid the successor must re-arm), which names no key itself;
#   the reference consumer's reset skeleton FILL comments -- inputs and stories (its Sprint Context
#     FILL); its other FILL keys are render_skeleton keys: variant is pipeline_variant, current step
#     file current_step_file, last completed step last_completed_step_file, last gate passed
#     last_gate_passed, git branch branch, name sprint_name, operator committed scope scope.
SU_SETCREATE_EXTRA='is_ui_epic stories_completed_this_sprint stories_in_progress stories_not_started resume_instruction inputs stories'
SU_SKEL=""; NEEDSKEL=0

SNAP=""
OPS="$(mktemp "${TMPDIR:-/tmp}/snapshot-update-ops.XXXXXX")" || refuse "no temp file"
LOCK=""; HELD=0
CAND=""; PAY=""; HISTP=""
cleanup() {
  rm -f "$OPS"
  [ -z "$CAND" ] || rm -f "$CAND" "$CAND.next"
  [ -z "$PAY" ] || rm -f "$PAY"
  [ -z "$HISTP" ] || rm -f "$HISTP"
  if [ "$HELD" = 1 ]; then rm -f "$LOCK/pid"; rmdir "$LOCK" 2>/dev/null; fi
}
trap cleanup EXIT
trap 'exit 143' TERM
trap 'exit 130' INT HUP
nops=0; FIRSTOP=""
# Ops go to a file, one per record, fields separated by an ASCII unit separator, so a cell or a
# line of text can carry any byte but a newline and the separator.
US=$'\037'
rec() { local IFS="$US"; [ -n "$FIRSTOP" ] || FIRSTOP="$1"; printf '%s\n' "$*" >> "$OPS"; nops=$((nops + 1)); }
nl() { local x; for x in "$@"; do case "$x" in *$'\n'*|*"$US"*) refuse "$OPFLAG: an argument carries a newline"; esac; done; }
nonempty() { local x; for x in "$@"; do [ -n "$x" ] || refuse "$OPFLAG needs non-empty arguments"; done; }
nohash() { # a text-taking argument must not begin `#` (a column-0 `#` line can be read as a heading)
  local t="${1#"${1%%[![:space:]]*}"}"
  case "$t" in "#"*) refuse "$OPFLAG: the text begins with '#', which a reader can take for a section heading" ;; esac
}
need() { [ $# -ge "$1" ] || refuse "$OPFLAG needs $1 argument(s)"; }
while [ $# -gt 0 ]; do
  OPFLAG="$1"
  case "$1" in
    --snapshot)     [ $# -ge 2 ] || refuse "--snapshot needs a path"; SNAP="$2"; shift 2 ;;
    --activity|--open-item|--row-add)
                    need 2 "$@"; nonempty "$2"; nl "$2"; nohash "$2"; rec "${1#--}" "$2"; shift 2 ;;
    --close-item|--row-delete)
                    need 2 "$@"; nonempty "$2"; nl "$2"; rec "${1#--}" "$2"; shift 2 ;;
    --open-item-file)
                    need 2 "$@"; nonempty "$2"; [ -r "$2" ] && [ -s "$2" ] || refuse "--open-item-file: '$2' is not a readable, non-empty file"
                    rec open-item-file "$2"; shift 2 ;;
    --row-status)   need 3 "$@"; nonempty "$2" "$3"; nl "$2" "$3"
                    status_ok "$3" || refuse "--row-status: '$3' is not in-flight, delivered-reachable or stopped"
                    rec row-status "$2" "$3"; shift 3 ;;
    --row-set)      need 4 "$@"; nonempty "$2" "$3" "$4"; nl "$2" "$3" "$4"
                    [ "$3" != agent ] || refuse "--row-set: the agent cell is the row's identity; --row-delete and --row-add replace it"
                    case "$4" in *"|"*) refuse "--row-set: a cell value cannot carry '|'" ;; esac
                    if [ "$3" = status ]; then
                      status_ok "$4" || refuse "--row-set status: '$4' is not in-flight, delivered-reachable or stopped"
                    fi
                    rec row-set "$2" "$3" "$4"; shift 4 ;;
    --set)          need 3 "$@"; nonempty "$2" "$3"; nl "$2" "$3"
                    case "${4:-}" in ""|--*) rec set "$2" "$3"; shift 3 ;;
                      *) nl "$4"; rec set-in "$4" "$2" "$3"; NEEDSKEL=1; shift 4 ;; esac ;;
    --key-delete)   need 3 "$@"; nonempty "$2" "$3"; nl "$2" "$3"; rec key-delete "$2" "$3"; shift 3 ;;
    --set-block)    need 4 "$@"; nonempty "$2" "$3" "$4"; nl "$2" "$3" "$4"
                    [ -r "$4" ] && [ -s "$4" ] || refuse "--set-block: '$4' is not a readable, non-empty file"
                    rec set-block "$2" "$3" "$4"; NEEDSKEL=1; shift 4 ;;
    --section-add|--section-move-to-history)
                    need 2 "$@"; nonempty "$2"; nl "$2"; nohash "$2"; rec "${1#--}" "$2"; NEEDSKEL=1; shift 2 ;;
    --row-replace)  need 3 "$@"; nonempty "$2" "$3"; nl "$2" "$3"; nohash "$3"; rec row-replace "$2" "$3"; shift 3 ;;
    --line-add)     need 3 "$@"; nonempty "$2" "$3"; nl "$2" "$3"; nohash "$3"
                    if [ "${4:-}" = --bottom ]; then rec line-add "$2" "$3" 1; shift 4; else rec line-add "$2" "$3" 0; shift 3; fi ;;
    --line-replace) need 4 "$@"; nonempty "$2" "$3" "$4"; nl "$2" "$3" "$4"; nohash "$4"; rec line-replace "$2" "$3" "$4"; shift 4 ;;
    --line-delete|--move-to-history)
                    need 3 "$@"; nonempty "$2" "$3"; nl "$2" "$3"; rec "${1#--}" "$2" "$3"; shift 3 ;;
    --init)         need 3 "$@"; nonempty "$2" "$3"; nl "$2" "$3"; nohash "$2"
                    case "$2" in *[[:space:]]*) refuse "--init: the step file '$2' carries whitespace" ;; esac
                    case "$3" in *[!0-9]*) refuse "--init: the sprint id '$3' is not digits" ;; esac
                    [ "$nops" -eq 0 ] || refuse "--init must be the first op"
                    rec init "$2" "$3"; shift 3 ;;
    -h|--help)      sed -n '/^set -u$/q;2,$p' "${BASH_SOURCE[0]}"; exit 0 ;;
    # The op names come from this header's usage lines, so a lead that guessed a name (s322:
    # `--activity-add`) is shown every real one and does not spend a further call on --help.
    *)              refuse "unknown argument '$1'; the ops are: $(sed -n 's/^#   \(--[a-z-]*\).*/\1/p' "${BASH_SOURCE[0]}" | tr '\n' ' ')" ;;
  esac
done
[ "$nops" -gt 0 ] || refuse "no op given"
[ -n "$SNAP" ] || SNAP="${SU_ROOT}/${AI_DLC_STATE_DIR:-_bmad-output}/pipeline-snapshot.md"
if [ ! -f "$SNAP" ]; then
  [ "$FIRSTOP" = init ] || refuse "no snapshot at $SNAP"
fi

# The seven names, their order, the In-Flight header and the allowlist's first half come from the
# skeleton itself, rendered only for the ops that read them.
[ "$NEEDSKEL" = 0 ] || SU_SKEL="$(render_skeleton x 0)"

VALIDATOR="$SU_SELF_DIR/validate-artifact-budget.sh"
[ -f "$VALIDATOR" ] || refuse "validate-artifact-budget.sh is not beside this program ($SU_SELF_DIR), so the stamp check cannot run"

SDIR="$(cd "$(dirname "$SNAP")" && pwd)" || refuse "cannot enter $(dirname "$SNAP")"
CAND="$SDIR/.pipeline-snapshot.md.candidate.$$"
PAY="$SDIR/.pipeline-snapshot.md.payload.$$"
HISTP="$SDIR/.pipeline-snapshot.md.history.$$"
HIST="$SDIR/pipeline-snapshot-history.md"

# --- the lock ------------------------------------------------------------------------------
LOCK="$SDIR/.pipeline-snapshot.md.lock"
WAIT="${AI_DLC_SNAPSHOT_LOCK_TENTHS:-100}"
case "$WAIT" in ''|*[!0-9]*) WAIT=100 ;; esac
waited=0
while ! mkdir "$LOCK" 2>/dev/null; do
  holder=""
  [ -f "$LOCK/pid" ] && holder="$(cat "$LOCK/pid" 2>/dev/null)"
  case "$holder" in ''|*[!0-9]*) holder="" ;; esac
  if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then
    # A dead holder. Re-read the pid before breaking, so a lock another breaker just re-took is kept.
    if [ "$(cat "$LOCK/pid" 2>/dev/null)" = "$holder" ]; then
      rm -f "$LOCK/pid"; rmdir "$LOCK" 2>/dev/null
    fi
    continue
  fi
  waited=$((waited + 1))
  if [ "$waited" -gt "$WAIT" ]; then
    printf 'snapshot-update: LOCK TIMEOUT: %s is held by pid %s after %s tenths of a second. Nothing read or written.\n' \
      "$LOCK" "${holder:-unknown}" "$WAIT" >&2
    exit 3
  fi
  /bin/sleep 0.1
done
HELD=1
printf '%s\n' "$$" > "$LOCK/pid"

snapsum() { if [ -f "$SNAP" ]; then cksum < "$SNAP"; else echo absent; fi; }

tries=0
while :; do
tries=$((tries + 1))
BEFORE="$(snapsum)"
rm -f "$HISTP" "$CAND.next"
if [ -f "$SNAP" ]; then cp "$SNAP" "$CAND" || refuse "cannot write a candidate beside $SNAP"; OLD="$SNAP"
else : > "$CAND" || refuse "cannot write a candidate beside $SNAP"; OLD=/dev/null; fi
NOW_UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# One awk pass per op over the candidate. Exit 3: the op's target matched nothing; 4: it matched
# more than one line; 5: a row's cell count differs from its table header; 6: the section is absent;
# 7: the op's shape is refused (the reason is printed).
while IFS="$US" read -r op a b c; do
  if [ "$op" = init ]; then
    [ ! -s "$CAND" ] || refuse "--init: the snapshot is not empty; an existing file is archived first (steps/route.md), never overwritten"
    render_skeleton "$a" "$b" > "$CAND.next" && mv "$CAND.next" "$CAND"
    continue
  fi
  SU_OP="$op" SU_A="$a" SU_B="${b:-}" SU_C="${c:-}" SU_HP="$HISTP" SU_NOW="$NOW_UTC" \
    SU_SKEL="$SU_SKEL" SU_SCX="$SU_SETCREATE_EXTRA" SU_XS="${AI_DLC_SNAPSHOT_EXTRA_SECTIONS:-}" LC_ALL=C awk '
    function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
    function cells(line, arr,   r) { r = line; sub(/^[ \t]*\|/, "", r); sub(/\|[ \t]*$/, "", r); return split(r, arr, "|") }
    function isblank(s) { return s ~ /^[ \t]*$/ }
    function indent(s,   t) { t = s; sub(/[^ \t].*$/, "", t); return length(t) }
    function die(rc, msg) { print "snapshot-update: " msg > "/dev/stderr"; exit rc }
    # The two reader shapes a text-taking op must not mint. The first is a position bullet in the
    # readers key grammar, spelled so that I113 (which pins that grammar in exactly three files)
    # does not see a fourth copy: it is a refusal pattern here, not a reader.
    # WIDER THAN THE COUNTED READER, ON PURPOSE: the key anywhere before the first colon, with any
    # bullet character or none. The readers fallback arms (whole-file or whole-section first match,
    # reached when no dash bullet is counted) and Check 8 read `* key:` and a bare `key:` line, so
    # the refusal covers what any reader arm takes, not only what the count takes. Measured on the
    # reference consumer: of 25141 distinct lines its 591 snapshot revisions added, the dash form
    # matched 258 and this form 260 -- the 2 more are wrapped prose lines a reader fallback reads too.
    function hasbullet(s,   t) { t = tolower(s); return (t ~ /^[^:]*(current_step_file|current[_ ]step|current[_ ]phase)[^:]*:/) }
    # THE FALLBACK STATE. The readers count unlabelled dash position bullets in Pipeline Position;
    # with none, the continue and recover hooks take the FIRST line anywhere naming the key, colon or
    # no colon, so a dated activity line `- <stamp> the current step is x: note` is read as the
    # position (measured on the shipped hooks). FB is that state, computed from the candidate; in it
    # any added line naming the key is refused unless it is the --set/--init of Pipeline Position.
    function hasdash(s,   t) { t = tolower(s); return (t ~ /^[ \t]*-[^:]*(current_step_file|current[_ ]step|current[_ ]phase)[^:]*:/) && !(t ~ /^[^:]*(prior|superseded|retained history)/) }
    function haskey(s,   t) { t = tolower(s); return (t ~ /current_step_file|current[_ ]step|current[_ ]phase/) }
    function hassp(s) { return (s ~ /^[ \t]*- *[*]*sprint_id:/) }
    function guard(line, okpos, oksp) {
      if (line ~ /^#/) die(7, "refused: an added line begins with # and could be read as a section heading: " line)
      if (hasbullet(line) && !okpos) die(7, "refused: an added line reads as a Pipeline Position bullet outside --set/--init of that section: " line)
      if (FB && haskey(line) && !okpos) die(7, "refused: Pipeline Position holds no position bullet, so the readers take the first line naming the position key anywhere; write the position first with --set current_step_file <file> \"Pipeline Position\": " line)
      if (hassp(line) && !oksp) die(7, "refused: an added line reads as a sprint_id line outside --set/--init of Sprint Context: " line)
    }
    function insafter(i, text) { INS[i] = (i in INS) ? INS[i] "\n" text : text }
    function blockend(i,   k, e, ind) {
      ind = indent(L[i]); e = i
      for (k = i + 1; k <= n; k++) { if (isblank(L[k])) continue; if (indent(L[k]) > ind) e = k; else break }
      return e
    }
    function keyhit(line, key,   s) {
      if (!match(line, /^[ \t]*-[ \t]+/)) return 0
      s = substr(line, RLENGTH + 1)
      if (substr(s, 1, 2) == "**") s = substr(s, 3)
      if (substr(s, 1, length(key)) != key) return 0
      s = substr(s, length(key) + 1)
      if (substr(s, 1, 2) == "**") s = substr(s, 3)
      if (substr(s, 1, 1) != ":") return 0
      s = substr(s, 2); if (substr(s, 1, 2) == "**") s = substr(s, 3)
      KV = trim(s); KIND = indent(line); return 1
    }
    function secfind(want,   i, t) {
      HS = 0; HE = n + 1
      for (i = 1; i <= n; i++) if (L[i] ~ /^## /) {
        t = L[i]; sub(/^##[ \t]*/, "", t)
        if (HS && HE == n + 1) HE = i
        if (substr(t, 1, length(want)) == want) {
          if (HS) die(4, "two sections named " want)
          HS = i; HE = n + 1
        }
      }
      if (!HS) die(6, "no section named " want)
    }
    function bottom(   i, b) { b = HS; for (i = HS + 1; i < HE; i++) if (!isblank(L[i])) b = i; return b }
    function keyfind(key, lo, hi,   i, m) {
      m = 0; HIT = 0
      for (i = lo; i < hi; i++) if (!CONT[i] && keyhit(L[i], key)) { m++; HIT = i }
      return m
    }
    function isblk(i) { return (KV ~ /^[|>][-+]?$/) || blockend(i) > i }
    function posbullet_target(i) { return (SECT[i] ~ /^Pipeline Position/ || SECT[i] ~ /^Sprint Context/) && (hasbullet(L[i]) || hassp(L[i])) }
    function secflags(i) { OKP = (SECT[i] ~ /^Pipeline Position/); OKS = (SECT[i] ~ /^Sprint Context/) }
    function statuscell_ok(v) { return (v == "in-flight" || v == "delivered-reachable" || v == "stopped") }
    # A free-text writer into In-Flight Teammates (--line-replace, and --line-add with tgt 0, since an
    # added line replaces none) applies the status-cell vocabulary to a table row it writes. A header
    # added to a section with no header is not judged (no hd yet); a second header added beside one
    # is a row whose status cell reads `status`, so it is refused. The header is the first line of the
    # section naming dispatched-at, as the row ops find it; the status column is the header cell named
    # status. A text that is no table row, a rule (every cell a run of three or more dashes, optionally
    # colon-flanked), or ANY text replacing the header line itself (tgt is the replaced line) is not
    # checked; a row that merely names dispatched-at in a cell, replacing another line, is judged. A
    # header with no status column (or no header) keeps today`s behaviour: the same if (sc) exemption
    # --row-replace has below. The refusal prints the cell VALUE, with \047 for the quote.
    function ifstatus_chk(txt, tgt,   i, k, j2, hc, cc, hd, sc2, v, rule) {
      if (txt !~ /\|/) return
      k = cells(txt, cc); rule = 1
      for (j2 = 1; j2 <= k; j2++) if (cc[j2] !~ /^[ \t]*:?---+:?[ \t]*$/) rule = 0
      if (rule) return
      hd = 0; sc2 = 0
      for (i = HS + 1; i < HE && !hd; i++) if (L[i] ~ /\|/) {
        k = cells(L[i], hc); for (j2 = 1; j2 <= k; j2++) if (trim(hc[j2]) == "dispatched-at") hd = i
      }
      if (!hd) return
      k = cells(L[hd], hc); for (j2 = 1; j2 <= k; j2++) if (trim(hc[j2]) == "status") sc2 = j2
      if (!sc2) return
      if (tgt == hd) return
      k = cells(txt, cc)
      v = trim(cc[sc2])
      if (!statuscell_ok(v)) die(7, "refused: the status cell \047" v "\047 is not in-flight, delivered-reachable or stopped")
    }
    function idtoks(cell, out,   s, w, k, j, m) {
      s = cell; gsub(/[^A-Za-z0-9_@.-]+/, " ", s); k = split(s, w, " "); m = 0
      for (j = 1; j <= k; j++) if (w[j] ~ /^toolu_/ || (length(w[j]) >= 8 && w[j] ~ /[0-9]/)) out[++m] = w[j]
      return m
    }
    # The end of the target: a bullet takes its continuation lines with it (its blockend range).
    function itemend(h) { return (L[h] ~ /^[ \t]*-[ \t]/) ? blockend(h) : h }
    function oneline(sec, mt, what,   i, m, h) {
      secfind(sec); m = 0
      for (i = HS + 1; i < HE; i++) if (!CONT[i] && index(L[i], mt)) { m++; h = i }
      if (m == 0) exit 3
      if (m > 1) exit 4
      if (posbullet_target(h)) die(7, "refused: the " what " target is the position or sprint line; rewrite it with --set")
      OE = itemend(h)
      return h
    }
    # A line in the P1 key shape: `- key:`, the key optionally bold, the line optionally indented.
    # The key begins with a letter or _, so a dated line (`- 2026-11-04T06:29Z ...`) is not one.
    # Any bullet character (`-`, `*`, `+`): the position readers fallback arms and Check 8 read a
    # `* key:` line as readily as a dash bullet. A BARE `key:` line is not refused here: measured over
    # the reference consumer`s 591 snapshot revisions, the two sections hold 60 bare identifier-colon
    # lines of 8170, every one prose or a wrapped continuation (`Theme:`, `Merged:`, `NOTE:`), and 0
    # `*`/`+` key lines (control: 2650 dash key lines). A bare POSITION line is refused by hasbullet.
    function keyshaped(s,   t, p) {
      if (!match(s, /^[ \t]*[-*+][ \t]+/)) return 0
      t = substr(s, RLENGTH + 1)
      if (substr(t, 1, 2) == "**") t = substr(t, 3)
      p = index(t, ":"); if (p < 2) return 0
      t = substr(t, 1, p - 1); sub(/[*]+$/, "", t)
      return (t ~ /^[A-Za-z_][A-Za-z0-9_ .()\[\]-]*$/)
    }
    function nokey(sec, s) {
      if ((sec ~ /^Pipeline Position/ || sec ~ /^Sprint Context/) && keyshaped(s))
        die(7, "refused: a key line in " sec " is written with --set <key> <value> " sec " (the create allowlist), never by --" op ": " s)
    }
    # Which of the seven a heading text is (its index in the skeleton order), by prefix; 0 for none.
    function iscore(t,   j) { for (j = 1; j <= ncan; j++) if (substr(t, 1, length(CAN[j])) == CAN[j]) return j; return 0 }
    # A declared extra: the name itself, or the name followed by a space and a suffix, as the
    # validator`s prefix match reads `Deploy Baseline (captured at init, ...)`.
    function isextra(h,   j) { for (j = 1; j <= nx; j++) if (h == XS[j] || substr(h, 1, length(XS[j]) + 1) == XS[j] " ") return j; return 0 }
    function headtext(i,   t) { t = L[i]; sub(/^##[ \t]*/, "", t); return t }
    BEGIN { op = ENVIRON["SU_OP"]; A = ENVIRON["SU_A"]; B = ENVIRON["SU_B"]; C = ENVIRON["SU_C"]; n = 0
      IFHDR = "agent | role | deliverable | dispatched-at | status"
      # The seven, their order, the In-Flight header and the allowlist keys, read from render_skeleton.
      nk = split(ENVIRON["SU_SKEL"], SK, "\n"); ncan = 0; sk = ""
      for (j = 1; j <= nk; j++) {
        if (SK[j] ~ /^## /) { sk = substr(SK[j], 4); CAN[++ncan] = sk; if (sk == "In-Flight Teammates") IFH = SK[j + 1]; continue }
        if ((sk == "Pipeline Position" || sk == "Sprint Context") && match(SK[j], /^- [A-Za-z0-9_]+:/)) ALLOW[substr(SK[j], 3, RLENGTH - 3)] = 1
      }
      k = split(ENVIRON["SU_SCX"], W, " "); for (j = 1; j <= k; j++) ALLOW[W[j]] = 1
      k = split(ENVIRON["SU_XS"], W, ","); nx = 0; for (j = 1; j <= k; j++) { t = trim(W[j]); if (t != "") XS[++nx] = t }
    }
    { L[++n] = $0 }
    END {
      # PRE-PASS: the section title of every line, and which lines are the continuation of a bullet
      # whose next non-blank line is more indented (a block scalar or a wrapped item). A key match
      # never lands inside one.
      cur = ""
      for (i = 1; i <= n; i++) {
        if (L[i] ~ /^## /) { cur = L[i]; sub(/^##[ \t]*/, "", cur) }
        SECT[i] = cur
      }
      FB = 1; for (i = 1; i <= n; i++) if (SECT[i] ~ /^Pipeline Position/ && hasdash(L[i])) { FB = 0; break }
      for (i = 1; i <= n; i++) if (L[i] ~ /^[ \t]*-[ \t]/) {
        e = blockend(i)
        if (e > i) { for (k = i + 1; k <= e; k++) CONT[k] = 1; i = e }
      }
      want = (op == "activity") ? "Recent Activity" : (op ~ /item$/ || op == "open-item-file") ? "Open Items" : (op ~ /^row-/) ? "In-Flight Teammates" : ""
      if (op == "line-add" || op == "line-replace" || op == "line-delete" || op == "move-to-history" || op == "set-in" || op == "key-delete" || op == "set-block") want = A
      if (want != "") secfind(want)
      if (op == "activity" || op == "open-item") {
        txt = A; if (substr(txt, 1, 2) != "- ") txt = "- " txt
        guard(txt, 0, 0); insafter(HS, txt)
      } else if (op == "open-item-file") {
        got = 0
        while ((r = (getline ln < A)) > 0) { got++; txt = ln; if (substr(txt, 1, 2) != "- ") txt = "- " txt; guard(txt, 0, 0); insafter(HS, txt) }
        if (r < 0 || got == 0) die(7, "refused: could not read any line of " A)
      } else if (op == "close-item") {
        m = 0; for (i = HS + 1; i < HE; i++) if (!CONT[i] && index(L[i], A)) { m++; h = i }
        if (m == 0) exit 3; if (m > 1) exit 4
        e = itemend(h); for (i = h; i <= e; i++) D[i] = 1
      } else if (op == "line-add") {
        guard(B, 0, 0); nokey(SECT[HS], B)
        if (SECT[HS] ~ /^In-Flight Teammates/) ifstatus_chk(B, 0)
        insafter((C == "1") ? bottom() : HS, B)
      } else if (op == "line-replace") {
        h = oneline(A, B, "line-replace"); guard(C, 0, 0); nokey(SECT[HS], C)
        if (SECT[HS] ~ /^In-Flight Teammates/) ifstatus_chk(C, h)
        L[h] = C
        for (i = h + 1; i <= OE; i++) D[i] = 1
      } else if (op == "line-delete") {
        h = oneline(A, B, "line-delete"); for (i = h; i <= OE; i++) D[i] = 1
      } else if (op == "move-to-history") {
        h = oneline(A, B, "move-to-history"); MOVE = L[h]; D[h] = 1
        for (i = h + 1; i <= OE; i++) { MOVE = MOVE "\n" L[i]; D[i] = 1 }
      } else if (op == "section-add") {
        j = 0; for (k = 1; k <= ncan; k++) if (A == CAN[k]) j = k
        if (!j && !isextra(A)) die(7, "refused: " A " is not one of the seven sections and not declared in AI_DLC_SNAPSHOT_EXTRA_SECTIONS")
        # A declared extra whose name BEGINS with one of the seven is refused: every prefix reader
        # (the ops, the validator, the readers section awk) would take it for that section.
        if (!j && iscore(A)) die(7, "refused: " A " begins with the name of one of the seven sections, so every prefix reader would take it for that section; declare a name that does not")
        for (i = 1; i <= n; i++) if (L[i] ~ /^## / && (j ? substr(headtext(i), 1, length(A)) == A : (isextra(A) && isextra(headtext(i)) == isextra(A))))
          die(7, "refused: the section already exists: " L[i])
        crx = iscore("Context Reminders"); at = 0
        for (i = 1; i <= n && !at; i++) if (L[i] ~ /^## /) { t = iscore(headtext(i)); if (j ? t > j : t == crx) at = i }
        blk = "## " A; if (A == "In-Flight Teammates") blk = blk "\n" IFH
        if (at) {
          if (at > 1 && !isblank(L[at - 1])) blk = "\n" blk
          if (at == 1) PRE = blk "\n"; else insafter(at - 1, blk "\n")
        } else {
          # At the end. When the last section is In-Flight Teammates and lines that are no table
          # row follow its last row, Context Reminders goes directly under that row, so those lines
          # are its body again: the repair of a row that swallowed the heading.
          ls = 0; for (i = 1; i <= n; i++) if (L[i] ~ /^## /) ls = i
          lr = 0
          if (A == "Context Reminders" && ls && iscore(headtext(ls)) == iscore("In-Flight Teammates")) for (i = ls + 1; i <= n; i++) if (L[i] ~ /\|/) lr = i
          if (lr) insafter(lr, "\n" blk)
          else { b = n; while (b > 0 && isblank(L[b])) b--; if (b) insafter(b, "\n" blk); else PRE = blk "\n" }
        }
      } else if (op == "section-move-to-history") {
        # Its own lookup, not secfind: a heading of the seven that occurs MORE than once is a
        # duplicate (Check 14 SCHEMA), and its LAST occurrence is moved. One occurrence of the seven
        # is refused; several matches that are not all the same one of the seven are ambiguous.
        m = 0; HS = 0; k1 = 0
        for (i = 1; i <= n; i++) if (L[i] ~ /^## / && substr(headtext(i), 1, length(A)) == A) {
          m++; t = iscore(headtext(i)); if (m == 1) k1 = t; else if (t != k1) k1 = 0
          HS = i
        }
        if (!m) die(6, "no section named " A)
        if (m > 1 && !k1) die(4, "two sections named " A)
        HE = n + 1; for (i = HS + 1; i <= n; i++) if (L[i] ~ /^## /) { HE = i; break }
        if (m == 1 && iscore(headtext(HS))) die(7, "refused: " headtext(HS) " is one of the seven sections and is never moved; --section-move-to-history moves a section outside them, or the last copy of a duplicated one")
        MOVE = L[HS]; D[HS] = 1
        for (i = HS + 1; i < HE; i++) { MOVE = MOVE "\n" L[i]; D[i] = 1 }
      } else if (op == "set") {
        m = keyfind(A, 1, n + 1)
        if (m == 0) exit 3; if (m > 1) exit 4
        keyhit(L[HIT], A)
        if (isblk(HIT)) die(7, "refused: " A " is a block scalar; --set would orphan its continuation lines. Use --set-block.")
        secflags(HIT); ind = substr(L[HIT], 1, KIND)
        L[HIT] = ind "- " A ": " B; guard(L[HIT], OKP, OKS)
        if (OKP && hasbullet(L[HIT]) && trim(B) == "") die(7, "refused: an empty value for " A)
      } else if (op == "set-in") {
        m = keyfind(B, HS + 1, HE)
        if (m > 1) exit 4
        if (m == 0) {
          nl2 = "- " B ": " C
          if (SECT[HS] ~ /^Pipeline Position/ || SECT[HS] ~ /^Sprint Context/) {
            if (!(B in ALLOW)) die(7, "refused: " B " is not in " SECT[HS] " and not in the create allowlist (render_skeleton keys and SU_SETCREATE_EXTRA)")
            # A position or sprint_id line is created only in its own section and only when the
            # file holds none, so the readers never meet two.
            secflags(HS); guard(nl2, OKP, OKS)
            for (i = 1; i <= n; i++) if ((hasbullet(nl2) && hasbullet(L[i])) || (hassp(nl2) && hassp(L[i]))) die(7, "refused: the file already holds a line the readers take for " B ": " L[i])
          } else guard(nl2, 0, 0)
          insafter(bottom(), nl2)
        } else {
          keyhit(L[HIT], B)
          if (isblk(HIT)) die(7, "refused: " B " is a block scalar; --set-in would orphan its continuation lines. Use --set-block.")
          secflags(HIT); ind = substr(L[HIT], 1, KIND)
          L[HIT] = ind "- " B ": " C; guard(L[HIT], OKP, OKS)
        }
      } else if (op == "key-delete") {
        if (B == "current_step_file" || B == "sprint_id" || hasbullet("- " B ":") || hassp("- " B ":")) die(7, "refused: " B " is read by the continue, recover and dispatch-guard hooks and is never deleted")
        m = keyfind(B, HS + 1, HE)
        if (m == 0) exit 3; if (m > 1) exit 4
        keyhit(L[HIT], B); e = blockend(HIT)
        for (i = HIT; i <= e; i++) D[i] = 1
      } else if (op == "set-block") {
        fn = 0
        while ((r = (getline ln < C)) > 0) {
          F[++fn] = ln; t = trim(ln)
          if (t ~ /^#/) die(7, "refused: a --set-block content line begins with #: " ln)
          if (FB && haskey(ln)) die(7, "refused: Pipeline Position holds no position bullet, so the readers take the first line naming the position key anywhere, and this --set-block content line names it; write the position first with --set current_step_file <file> \"Pipeline Position\": " ln)
          if (hasbullet(ln) || hassp(ln)) die(7, "refused: a --set-block content line reads as a position or sprint_id bullet: " ln)
        }
        if (r < 0 || fn == 0) die(7, "refused: could not read any line of " C)
        if (B == "current_step_file" || B == "sprint_id" || hasbullet("- " B ":") || hassp("- " B ":")) die(7, "refused: " B " is single-valued and is written with --set")
        m = keyfind(B, HS + 1, HE)
        if (m > 1) exit 4
        if (m == 0) {
          if ((SECT[HS] ~ /^Pipeline Position/ || SECT[HS] ~ /^Sprint Context/) && !(B in ALLOW)) die(7, "refused: " B " is not in " SECT[HS] " and not in the create allowlist (render_skeleton keys and SU_SETCREATE_EXTRA)")
          at = bottom(); kind = 0
        } else {
          keyhit(L[HIT], B); kind = KIND; at = HIT; e = blockend(HIT)
          for (i = HIT + 1; i <= e; i++) D[i] = 1
          secflags(HIT)
        }
        pad = ""; for (j = 0; j < kind + 4; j++) pad = pad " "
        ind = ""; for (j = 0; j < kind; j++) ind = ind " "
        kl = ind "- " B ": |"
        if (m == 1) { L[HIT] = kl } else { insafter(at, kl); at = -1 }
        for (j = 1; j <= fn; j++) {
          cl = (F[j] ~ /^[ \t]*$/) ? "" : pad F[j]
          if (m == 1) insafter(HIT, cl); else insafter(bottom(), cl)
        }
      } else {
        hdr = 0; for (i = HS + 1; i < HE; i++) if (L[i] ~ /\|/) {
          k = cells(L[i], c); for (j = 1; j <= k; j++) if (trim(c[j]) == "dispatched-at") { hdr = i; nc = k }
          if (hdr) break
        }
        hdrnew = 0
        if (!hdr) {
          if (op != "row-add") die(6, "no In-Flight Teammates header row naming dispatched-at; the section exists, so write the header with --line-add \047In-Flight Teammates\047 \047" IFHDR "\047")
          nc = 5; sc = 5; piped = 0; hdrnew = 1
          last = bottom(); insafter(last, IFHDR)
        } else {
          sc = 0; cells(L[hdr], c); for (j = 1; j <= nc; j++) if (trim(c[j]) == "status") sc = j
          piped = (L[hdr] ~ /^[ \t]*\|/)
          last = hdr
          for (i = hdr + 1; i < HE; i++) if (L[i] ~ /\|/) last = i
        }
        # The new row of --row-add (its text in A) and of --row-replace (in B): the header`s cell
        # count, its status cell a member, and the row text guarded.
        if (op == "row-add" || op == "row-replace") {
          nr = (op == "row-add") ? A : B
          k = cells(nr, c); if (k != nc) { printf "the row has %d cells, the header %d\n", k, nc > "/dev/stderr"; exit 5 }
          r = ""; for (j = 1; j <= k; j++) r = r (j > 1 ? " | " : "") trim(c[j])
          rowtxt = piped ? "| " r " |" : r
          guard(rowtxt, 0, 0)
          if (sc) { cells(nr, c); if (!statuscell_ok(trim(c[sc]))) die(7, "refused: the status cell \047" trim(c[sc]) "\047 is not in-flight, delivered-reachable or stopped") }
        }
        if (op == "row-add") {
          dup = 0
          if (!hdrnew) {
            cells(A, c); nid = idtoks(trim(c[1]), mine)
            for (i = hdr + 1; i < HE && !dup; i++) if (L[i] ~ /\|/ && L[i] !~ /^[ \t|:-]+$/) {
              cells(L[i], c); ne = idtoks(trim(c[1]), theirs)
              for (x = 1; x <= nid && !dup; x++) for (y = 1; y <= ne; y++) if (mine[x] == theirs[y]) { dup = i; break }
            }
          }
          if (dup) {
            k = cells(L[dup], c); o = ""; for (j = 1; j <= k; j++) o = o (j > 1 ? " | " : "") trim(c[j])
            if (o != r) die(7, "refused: an existing row already carries this agent id with different cells; rewrite it with --row-replace <agent> <row>: " L[dup])
            print "snapshot-update: --row-add: an existing row already carries this agent id; nothing added" > "/dev/stderr"
          }
          else insafter(last, rowtxt)
        } else {
          m = 0
          for (i = hdr + 1; i < HE; i++) if (L[i] ~ /\|/ && L[i] !~ /^[ \t|:-]+$/) {
            cells(L[i], c); f = trim(c[1]); split(f, w, /[ \t]+/)
            if (w[1] == A) { m++; hit = i }
          }
          if (m == 0) exit 3; if (m > 1) exit 4
          if (op == "row-delete") D[hit] = 1
          else if (op == "row-replace") {
            # The new agent cell must not carry an id another row already carries: a replace that
            # did would leave two rows the --row-add dedupe and the --row-* lookups take for one.
            cells(B, c); nid = idtoks(trim(c[1]), mine)
            for (i = hdr + 1; i < HE; i++) if (i != hit && L[i] ~ /\|/ && L[i] !~ /^[ \t|:-]+$/) {
              cells(L[i], c); ne = idtoks(trim(c[1]), theirs)
              for (x = 1; x <= nid; x++) for (y = 1; y <= ne; y++) if (mine[x] == theirs[y])
                die(7, "refused: the new agent cell carries " mine[x] ", which another row already carries: " L[i])
            }
            L[hit] = rowtxt
          }
          else {
            colname = (op == "row-set") ? B : "status"; val = (op == "row-set") ? C : B
            col = 0; cells(L[hdr], c); for (j = 1; j <= nc; j++) if (trim(c[j]) == colname) col = j
            if (!col) die(7, "refused: the header names no column " colname)
            if (colname == "status" && !statuscell_ok(val)) die(7, "refused: " val " is not in-flight, delivered-reachable or stopped")
            k = cells(L[hit], c); if (k != nc) { printf "the row has %d cells, the header %d\n", k, nc > "/dev/stderr"; exit 5 }
            c[col] = " " val " "
            r = ""; for (j = 1; j <= k; j++) r = r (j > 1 ? " | " : "") trim(c[j])
            L[hit] = piped ? "| " r " |" : r
            guard(L[hit], 0, 0)
          }
        }
      }
      if (op == "move-to-history" || op == "section-move-to-history") {
        hp = ENVIRON["SU_HP"]
        print "## [MOVED " ENVIRON["SU_NOW"] " from pipeline-snapshot.md -- " A " via snapshot-update --" op "]" >> hp
        print "" >> hp
        print MOVE >> hp
        print "" >> hp
        close(hp)
      }
      if (PRE != "") print PRE
      for (i = 1; i <= n; i++) {
        if (!(i in D)) print L[i]
        if (i in INS) print INS[i]
      }
    }' "$CAND" > "$CAND.next"
  rc=$?
  case "$rc" in
    0) mv "$CAND.next" "$CAND" ;;
    3) rm -f "$CAND.next"; refuse "--$op '$a': no line matches" ;;
    4) rm -f "$CAND.next"; refuse "--$op '$a': more than one line matches; name it exactly" ;;
    5) rm -f "$CAND.next"; refuse "--$op: cell count differs from the In-Flight Teammates header" ;;
    7) rm -f "$CAND.next"; refuse "--$op: the shape above is refused" ;;
    *) rm -f "$CAND.next"; refuse "--$op: the snapshot has no section for it (rc $rc)" ;;
  esac
done < "$OPS"

# The payload is what the candidate ADDED, each line counted against its occurrences in the old
# file, exactly as the derivation-capture hook subtracts an Edit's old_string from its new_string.
# The old file is told apart by NAME, never by FNR == NR: an empty old file would make NR == FNR hold
# through the candidate too and leave the payload empty.
LC_ALL=C awk -v old="$OLD" 'FILENAME == old { c[$0]++; next } { if (c[$0] > 0) c[$0]--; else if ($0 != "") print }' "$OLD" "$CAND" > "$PAY"

VOUT="$(AI_DLC_PROJECT_ROOT="$SU_ROOT" bash "$VALIDATOR" --stamps-only "$CAND" --payload "$PAY" 2>&1)"
VRC=$?
if [ "$VRC" -eq 1 ]; then
  printf '%s\n' "$VOUT" >&2
  printf 'snapshot-update: REFUSED by the stamp check; %s is unchanged. Fix the stamp and re-run the whole call.\n' "$SNAP" >&2
  exit 1
fi
[ "$VRC" -eq 0 ] || { printf '%s\n' "$VOUT" >&2; refuse "the stamp check could not run (validate-artifact-budget.sh exit $VRC)"; }

[ "$(snapsum)" = "$BEFORE" ] && break
# Under the lock a change means an unlocked Edit or Write landed: rebuild from the new file.
[ "$tries" -lt 3 ] || refuse "$SNAP changed under every one of 3 attempts (an unlocked writer is active); re-run it"
done

# History FIRST (a crash between the two leaves a duplicate, never a loss), then the snapshot.
if [ -s "$HISTP" ]; then
  if [ ! -f "$HIST" ]; then
    printf '# Pipeline Snapshot -- History (write-only; never whole-read)\n\n' > "$HIST" || refuse "cannot create $HIST"
  fi
  cat "$HISTP" >> "$HIST" || refuse "cannot append to $HIST"
fi
mv "$CAND" "$SNAP" || refuse "cannot move the candidate over $SNAP"
printf 'snapshot-update: %d op(s) written to %s (stamp check passed on %d added line(s))\n' \
  "$nops" "$SNAP" "$(grep -c . "$PAY" 2>/dev/null || true)"
exit 0
