#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# handoff-completion-assertion — assert the handoff seam end to end, across the two hooks and
# the one predicate they now share.
#
# THREE SUBJECTS, AND NONE OF THEM IS REACHABLE FROM `handoff-resume-guard`.
#
# 1. ai-dlc-continue.sh's PUSH ARM (steps/handoff.md step 3). Step 3 is the half of the
#    procedure nothing had ever checked, and it is the half that loses work: the resume line
#    and the teammate sweep are both recorded IN the conversation, so a lead that skips them
#    is visible, while an unpushed branch looks exactly like a pushed one from inside the
#    session. It deliberately does NOT fire when no remote is configured -- step 3 names that
#    as one of three environmental causes it forgives -- and that narrowing is the whole
#    false-positive story, so it is asserted here beside the case it must still catch.
#
# 2. ai-dlc-handoff-pending.sh, THE SHARED PREDICATE, through both of its callers. A handoff
#    typed while the lead is working is stored by the harness as a `queue-operation` record
#    and never becomes a `message.role=="user"` entry, so the transcript cannot see it and
#    every transcript-keyed guard was silent. The predicate answers from disk instead, on
#    three keys, gated by the pause flag. Each key gets a seed the other two cannot satisfy --
#    `fixture-mutants.md`'s "two guards that COVER each other" is the failure being avoided,
#    and its symptom is ZERO mutant kills rather than two.
#
# 3. ai-dlc-recover.sh's STEP-FILE OVERRIDE. `current_step_file` is wrong by construction at a
#    handoff: it records the step the handoff INTERRUPTED until step 3 rewrites it, so a
#    compaction lands the recovering lead in the wrong procedure with every downstream check
#    passing. Asserted through the emitted `additionalContext`, and cross-checked against the
#    `.recover-fired` marker -- two independently derived values, because a count read off one
#    rendering is not a derived count.
#
# WHY THE PREDICATE IS DRIVEN THROUGH ITS CALLERS AND NEVER CALLED DIRECTLY. Isolating the
# subject is not running the PROGRAM: a defect in a caller -- a wrong state dir, a session id
# read from the wrong field, a schema that does not resolve in that hook's layout -- stays
# invisible to a fixture that sources the library and calls the function.
#
# EVERY NEGATIVE HERE IS AN EMPTY OR UNCHANGED OUTPUT, AND SO IS A HOOK THAT DIED ON LOAD.
# Every arm is therefore PRESENCE-shaped: a Stop allow is paired with the same tree driven
# with the resume block stripped, which must BLOCK; and a recover negative REQUIRES the
# mandate to name the snapshot's own step file, which an empty block cannot do.
#
# Usage: run.sh [path-to-hooks-directory-or-ai-dlc-continue.sh]
set -uo pipefail

# HERMETIC — scrub the operator's tuning before invoking any hook. A fixture that INHERITS
# ambient config tests the config, not the code; see handoff-resume-guard's header for the
# consumer that pinned AI_DLC_MODEL_ROW and failed seven assertions against a sensor behaving
# exactly as specified.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# The harness block cap clamps the continue hook's EFF_MAX; an exported one moves its counts.
unset CLAUDE_CODE_STOP_HOOK_BLOCK_CAP

# AND SCRUB GIT'S OWN AMBIENT REPO POINTERS, which no other fixture here has had to. `GIT_DIR`
# and friends take precedence over `-C <dir>`, so a runner that exported one would make the
# not-a-git-repo probe below read as a git repo and quietly re-arm the very arm that case
# exists to prove is disarmed. Measured on git 2.54.0 (Apple Git-157): a pre-push hook gets
# `GIT_EXEC_PATH`, `GIT_PREFIX` and `GIT_EDITOR` and no `GIT_DIR` -- so this is defence
# against a different git, and seed.sh carries the same scrub plus a hard abort, because it is
# executable on its own and one run of it with `GIT_DIR` set committed to this repository.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY GIT_COMMON_DIR GIT_NAMESPACE 2>/dev/null || true

HERE="$(cd "$(dirname "$0")" && pwd)"
pickd() { for c in "$@"; do [ -n "$c" ] && [ -d "$c" ] && { printf '%s' "$c"; return; }; done; }
pick()  { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }

# THE WHOLE DIRECTORY IS RESOLVED, NOT ONE HOOK. Both hooks source
# ai-dlc-handoff-pending.sh as a SIBLING of themselves, so a hook placed on its own finds no
# library, fails open, and reads exactly like a guard that stood down.
_arg="${1:-}"
[ -n "$_arg" ] && [ -f "$_arg" ] && _arg="$(cd "$(dirname "$_arg")" && pwd)"
HOOKS_DIR="$(pickd "$_arg" "$HERE/../../hooks" "$HERE/../../../core/hooks" "$HERE/../../../.claude/hooks")"
[ -n "$HOOKS_DIR" ] || { echo "FIXTURE ERROR: cannot locate the hooks directory" >&2; exit 2; }
HOOKS_DIR="$(cd "$HOOKS_DIR" && pwd)"
command -v jq  >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq required"  >&2; exit 2; }
command -v git >/dev/null 2>&1 || { echo "FIXTURE ERROR: git required" >&2; exit 2; }

SCHEMA="$(pick "$HERE/../../schemas/pause-routing.json" \
               "$HERE/../../../core/schemas/pause-routing.json" \
               "$HERE/../../../.claude/schemas/pause-routing.json")"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
broken() { printf '  FAIL  %s\n' "$1"; echo ""; echo "handoff-completion-assertion: FIXTURE BROKEN" >&2; exit 2; }

for _f in ai-dlc-continue.sh ai-dlc-recover.sh ai-dlc-handoff-pending.sh; do
  [ -f "$HOOKS_DIR/$_f" ] || broken "$_f is not in the resolved hooks directory ($HOOKS_DIR) — this fixture drives all three and cannot report on any of them"
done
# The vocabulary declaration gates Check 0 entirely and is key 3's whole grammar: with it
# unreachable both callers stand down and every assertion below passes for the wrong reason.
[ -n "$SCHEMA" ] || broken "schemas/pause-routing.json not found in either layout; the handoff vocabulary is read from there and both hooks would skip, so every assertion below would pass without the predicate running"

echo "HERMETIC-CONSUMED core/hooks/ai-dlc-continue.sh"
echo "HERMETIC-CONSUMED core/hooks/ai-dlc-recover.sh"
echo "HERMETIC-CONSUMED core/hooks/ai-dlc-handoff-pending.sh"
echo "HERMETIC-CONSUMED core/schemas/pause-routing.json"

# IN PROCESS (BL-878). ai-dlc-continue.sh is wrapped (hkcont_main behind the column-0 source guard); ai-dlc-recover.sh is
# not, and is sourced whole in a subshell of its own, where its `exit` ends only that subshell. Both are asked through the
# `bash` shim below, which every `bash <hook>` start of this file reaches; any other start (the entry hook, the gate, the
# seed, a sibling a hook starts itself) is real. A core fixture ships ahead of its subject: a continue hook with neither the
# `hkcont_main() {` line nor the column-0 source guard predates the wrap and SKIPs (FIXTURE BROKEN in the distribution);
# exactly one half FAILs; an unreadable subject is FIXTURE ERROR.
hca_halves() { # <file> <entry> -> "<def><guard>"
  local d=0 g=0 x
  grep -qxF "$2() {" "$1"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $1 (grep exit $x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$x" -ne 0 ] || d=1
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$1"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $1 (grep exit $x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$x" -ne 0 ] || g=1
  printf '%s%s' "$d" "$g"
}
_h="$(hca_halves "$HOOKS_DIR/ai-dlc-continue.sh" hkcont_main)" || exit 2
case "$_h" in
  11) : ;;
  00) echo "SKIP: subject predates the in-process wrap: $HOOKS_DIR/ai-dlc-continue.sh"; fx_skip_exit "$HERE" ;;
  *) bad "$HOOKS_DIR/ai-dlc-continue.sh carries one half of the in-process wrap (hkcont_main line, column-0 source guard: $_h) -- a respelled subject this fixture cannot drive"
     report_end handoff-completion-assertion ;;
esac
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
export FX_CONT="$HOOKS_DIR/ai-dlc-continue.sh" FX_REC="$HOOKS_DIR/ai-dlc-recover.sh" # exported: the shim's subshell keeps exported variables and drops the rest
bash() { # `bash <continue|recover>` runs the hook in a fresh-options subshell, one fx_inproc pass per call; any other start is real
  local _p="${1:-}" _e=""
  case "$_p" in
    "$FX_CONT") _e=hkcont_main ;;
    "$FX_REC") _e=recover ;;
  esac
  if [ -z "$_e" ]; then command bash "$@"; return; fi
  shift
  (
    _x=" $(compgen -e) "; _x="${_x//$'\n'/ }"
    for _v in $(compgen -v); do
      case "$_x" in *" $_v "*) continue ;; esac
      case "$_v" in
        _x|_v|_e|_p) continue ;;
        BASH|BASH_*|BASHOPTS|BASHPID|COMP_WORDBREAKS|DIRSTACK|EUID|FUNCNAME|GROUPS|HISTCMD|HOSTNAME|HOSTTYPE) continue ;;
        IFS|LINENO|MACHTYPE|OPTERR|OPTIND|OSTYPE|PIPESTATUS|PPID|PS4|PWD|OLDPWD|RANDOM|SECONDS|SHELL|SHELLOPTS) continue ;;
        SHLVL|TERM|UID|_) continue ;;
      esac
      unset "$_v" 2>/dev/null
    done
    for _f in $(compgen -A function); do [ "$_f" = fx_inproc ] || unset -f "$_f"; done
    unset _f _x _v
    OPTIND=1; set +eufx +o pipefail; hash -r
    case "$_e" in
      hkcont_main) fx_inproc "$_p"; unset -f fx_inproc; . "$_p" && hkcont_main "$@" ;;
      recover) fx_inproc "$_p"; unset -f fx_inproc; . "$_p" ;;
    esac
  )
}

ROOT="$(bash "$HERE/seed.sh")"
{ [ -n "$ROOT" ] && [ -d "$ROOT" ]; } || broken "seed.sh produced no sandbox root"

printf '        hooks:      %s\n' "$HOOKS_DIR"
printf '        vocabulary: %s\n' "$SCHEMA"

T_REQ_OK="$(cat "$ROOT/.t_req_ok")"
T_REQ_NOBLK="$(cat "$ROOT/.t_req_noblk")"
T_QUIET="$(cat "$ROOT/.t_quiet")"
T_QUIET_OK="$(cat "$ROOT/.t_quiet_ok")"

P_NOGIT="$ROOT/proj-nogit"
P_NOREMOTE="$ROOT/proj-noremote"
P_UNPUSHED="$ROOT/proj-unpushed"
P_PUSHED="$ROOT/proj-pushed"
P_AHEAD="$ROOT/proj-ahead"
P_DISK="$ROOT/proj-disk"
P_REC="$ROOT/proj-recover"
P_REC_CLAUDE="$ROOT/proj-recover-claude"
P_ENTRY="$ROOT/proj-entry"

STEP_IMPL="core/skills/ai-dlc/steps/implementation.md"
STEP_HANDOFF="core/skills/ai-dlc/steps/handoff.md"
STEP_IMPL_C=".claude/skills/ai-dlc/steps/implementation.md"
STEP_HANDOFF_C=".claude/skills/ai-dlc/steps/handoff.md"

SESS_A="sess-alpha-11110000"
SESS_B="sess-bravo-22220000"

# -----------------------------------------------------------------------------
# Driving the hooks
# -----------------------------------------------------------------------------
# THE STATE IS RESET EXPLICITLY BY EACH CASE, never implicitly here, because these trees are
# reused and every case differs from its neighbour in exactly one file. `reset_state` is what
# makes "the same tree" a true statement rather than an aspiration.
#
# The rapid-fire state file is the one exception and is cleared on every drive: Check 0's own
# backoff releases after MAX_RAPID_BLOCKS consecutive blocks, so a tree driven four times
# would start ALLOWING -- a leak that reads exactly like the arm standing down.
reset_state() { # reset_state <projdir>
  local sd="$1/_bmad-output"
  mkdir -p "$sd/.driver"
  rm -f "$sd/handoff-guard-state.txt" "$sd/pipeline-continuation-log.md" \
        "$sd/pipeline-paused.flag" "$sd/.handoff-in-progress" "$sd/.recover-fired" \
        "$sd/pipeline-snapshot.md" "$sd/.handoff-guard-armed" "$sd/.handoff-complete"
  # STEP 4's TOUCH IS PART OF THE BASELINE STATE. Check 0 asserts `.driver/handoff` once the
  # resume, sweep and push arms are satisfied, so every ALLOW case in this file needs it on
  # disk or it blocks for the driver arm's reason. It is the LEAD's own Bash action, not a
  # hook's artifact, so seeding it here seeds the actor's step and not a reader's grammar --
  # unlike `.handoff-in-progress`, which only ai-dlc-handoff-entry.sh may write (mkmarker).
  # The driver-arm cases below REMOVE it to reach their subject.
  : > "$sd/.driver/handoff"
  return 0
}

# ai-dlc-continue.sh: JSON on stdin, decision JSON on stdout, exit 0 either way.
#
# NO SNAPSHOT in either Stop battery. Check 0 is the first check in the hook and Check 2 (no
# active pipeline) is what allows the stop further down, so with no snapshot Check 0's verdict
# is the only thing that can block. A snapshot would make the pipeline ACTIVE and Rule 3 would
# block every Stop for a reason unrelated to the arm under test. It also pins TEAMMATES_OK=1,
# which is what isolates the push arm.
drive() { # drive <projdir> <session> <transcript> [hooksdir] -> raw stdout
  local proj="$1" sess="$2" t="$3" hd="${4:-$HOOKS_DIR}"
  mkdir -p "$proj/_bmad-output"
  rm -f "$proj/_bmad-output/handoff-guard-state.txt"
  jq -nc --arg t "$t" --arg s "$sess" '{transcript_path:$t,session_id:$s}' \
  | PATH="${HCA_PATH:-$PATH}" CLAUDE_PROJECT_DIR="$proj" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" bash "$hd/ai-dlc-continue.sh" 2>/dev/null
}
# ai-dlc-handoff-entry.sh: a PostToolUse payload in, a marker file on disk out. It is the
# PRODUCER of key 1, so every key-1 seed in this fixture is made by driving it -- never by
# touching `.handoff-in-progress` here. A seed a fixture writes itself proves the reader
# accepts the fixture's own spelling; this one proves the two shipped halves agree.
edrive() { # edrive <projdir> <tool> <file-path> [hooksdir] -> hook exit code
  local proj="$1" tool="$2" fp="$3" hd="${4:-$HOOKS_DIR}"
  jq -nc --arg t "$tool" --arg p "$fp" --arg id "${GD_ID:-}" \
    '{tool_name:$t,tool_input:{file_path:$p}} + (if $id != "" then {tool_use_id:$id} else {} end)' \
  | CLAUDE_PROJECT_DIR="$proj" bash "$hd/ai-dlc-handoff-entry.sh" >/dev/null 2>&1
  printf '%s' "$?"
}
mkmarker() { # mkmarker <projdir> [hooksdir] -> produce key 1 the way the machinery does
  local p="" c
  for c in ".claude/skills/ai-dlc/steps" "core/skills/ai-dlc/steps"; do
    [ -f "$1/$c/handoff.md" ] && { p="$1/$c/handoff.md"; break; }
  done
  [ -n "$p" ] || p="$1/core/skills/ai-dlc/steps/handoff.md"
  edrive "$1" Read "$p" "${2:-$HOOKS_DIR}" >/dev/null
}
marker_at() { [ -f "$1/_bmad-output/.handoff-in-progress" ]; }

verdict() { if printf '%s' "$1" | jq -e '.decision=="block"' >/dev/null 2>&1; then printf block; else printf allow; fi; }
reason()  { printf '%s' "$1" | jq -r '.reason // ""' 2>/dev/null; }
has()     { grep -qF -- "$2" <<<"$1"; }

# ai-dlc-recover.sh: a SessionStart `compact` payload in, additionalContext out. The hook
# exits 0 emitting nothing unless a snapshot exists and `.source` is exactly `compact`.
rdrive() { # rdrive <projdir> <session> [hooksdir] -> additionalContext
  local proj="$1" sess="$2" hd="${3:-$HOOKS_DIR}" out
  out="$(jq -nc --arg s "$sess" '{source:"compact",session_id:$s}' \
        | CLAUDE_PROJECT_DIR="$proj" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" bash "$hd/ai-dlc-recover.sh" 2>/dev/null)"
  printf '%s' "$out" | jq -r '.hookSpecificOutput.additionalContext // ""' 2>/dev/null
}

# The ai-dlc-continue.sh block texts, keyed on a phrase unique to each. The push and commit
# texts say "Emit no resume prompt", so the resume marker has to be the longer phrase or
# assertion k would score the push branch as the resume branch.
PUSH_MARK="step 3's push has NOT landed"
TEAM_MARK="still carries a row whose status reads"
RESUME_MARK="WITHOUT a copy-pasteable resume prompt"
DRIVER_MARK="step 4's driver signal was NOT touched"
MARKER_MARK="step 5's entry marker is still present"

# -----------------------------------------------------------------------------
# The continuation-log rows, written in the two REAL producers' shapes
# -----------------------------------------------------------------------------
# SEEDED FROM WHAT THE PRODUCER EMITS, NOT FROM WHAT THE READER ACCEPTS. A row derived from
# the predicate's own awk grammar proves the reader accepts its own spelling and stays green
# through a change to both. These are transcribed from the two emitters: ai-dlc-pause.sh
# (UserPromptSubmit, `- Prompt (first 120 chars):`) and ai-dlc-answer-capture.sh
# (AskUserQuestion, `- Question (lead-authored, NOT the intent signal):` followed by
# `- Answer (first 120 chars):`).
log_open() { cat > "$1" <<'EOF'
# Pipeline Flow Log

---

EOF
}
row_prompt() { # row_prompt <outfile> <session> <ts> <prompt-value>
  cat >> "$1" <<EOF
## $3 -- USER_PAUSE
- Session: $2
- Channel: UserPromptSubmit (typed message)
- Prompt (first 120 chars): $4

EOF
}
row_answer() { # row_answer <outfile> <session> <ts> <question-value> <answer-value>
  cat >> "$1" <<EOF
## $3 -- USER_PAUSE
- Session: $2
- Channel: AskUserQuestion answer (handoff intent)
- Tool-use: toolu_01FIXTURE
- Question (lead-authored, NOT the intent signal): $4
- Answer (first 120 chars): $5

EOF
}
log_prompt() { log_open "$1"; row_prompt "$1" "$2" "2026-08-30T12:00:00Z" "$3"; }
log_answer() { log_open "$1"; row_answer "$1" "$2" "2026-08-30T12:00:00Z" "$3" "$4"; }

# THE TWO-ROW LOG, AND IT IS THE MOST LOAD-BEARING SEED IN THIS FILE.
#
# The predicate's `USER_PAUSE` awk rule ends in `next`, so without a flush before the reset a
# second USER_PAUSE header DISCARDS the first block's prose and only the LAST block of the
# session survives -- silently degenerating into "the most recent row", which is the exact
# reading the predicate's header records as measured and REJECTED (it fires on 1 of the
# consumer's 22 compactions, and not on the episode this exists for). A log with ONE row
# cannot tell the two implementations apart, so a battery built entirely from single-row logs
# would score that mutant green.
#
# The shape is the episode's own: the operator asks for the handoff, then asks ABOUT it four
# minutes later. The second row is newer and is NOT a request.
log_two_row() { # log_two_row <outfile> <session> <first-value> <second-value>
  log_open "$1"
  row_prompt "$1" "$2" "2026-08-30T13:06:31Z" "$3"
  row_prompt "$1" "$2" "2026-08-30T13:10:44Z" "$4"
}

# The operator prose each row carries. Declared once and used by BOTH the premise arms below
# and the log writers, so a seed cannot drift from the premise asserted about it.
P_INTENT="hand off the sprint"
P_BARE="handoff"
P_DISCUSS="why did the handoff guard fire when I typed hand off the sprint"
P_NOINTENT="not yet, keep going"
P_AFTER="Did the full handoff steps run"
Q_INTENT="should I hand off the sprint before I stop?"
Q_NOINTENT="anything else before I stop?"
# THE ROW EVERY RESUMED SESSION CARRIES FIRST. `/ai-dlc` is in the mention exclusion, and the
# exclusion used to be applied to the whole session's prose joined -- so this one row vetoed
# key 3 for the rest of the session, and the reference consumer's `handoff` typed five hours
# later scored NOT PENDING. It is a producer-derived seed: ai-dlc-pause.sh records the slash
# command verbatim as the first USER_PAUSE row of a resumed session.
P_RESUME="/ai-dlc resume"
# THE TERSE REQUEST AS THE FINAL SENTENCE OF A LONGER MESSAGE. Producer-derived: this is the
# reference consumer's own `- Prompt (first 120 chars):` row, verbatim, from the episode filed
# as PC-S308-HANDOFF-INTENT-PATTERN-MISSES-TRAILING-TERSE-PHRASING. The standalone alternative
# is anchored to the whole field and cannot see it. The near-miss is a real consumer row too,
# VERBATIM and therefore carrying the operator's CURLY apostrophe: the word trails a VERB with
# no sentence boundary before it, and on the consumer's full history that shape is a question
# or a denial five times in fifteen. The curly form is not decoration -- the row travels
# through the log writer, the awk field extractor and the intent grep, and a multibyte
# character is the class of input a bracket class silently mis-reads. Straightened, the seed
# exercises none of that; `answer-handoff-routing` carries the straightened spelling, so the
# two channels seed one shape apart rather than converging on the same bytes.
P_TERSE="I'm solving this issue. handoff."
P_TERSE_NEAR="I didn’t request handoff"
# A SECOND NEAR-MISS WITH TERMINAL PUNCTUATION, because the first has none. The adversarial hand
# built a trailing-word regression that REQUIRES a terminal period and it passed every arm keyed
# on the unpunctuated denial. This is the consumer's own row (verbatim, 117 chars, so it survives
# the 120-char preview): the operator saying a handoff was NOT wanted, ending in the word and a
# period, with no sentence boundary before the word.
P_TERSE_NEAR2="continue. Note for retro that you weren't supposed to be able to pause the pipeline to ask me if I wanted to handoff."
# PLAIN NOUN MENTIONS, exclusion-clean. The declaration's description says noun mentions are
# not requests and nothing asserted it: the adversarial hand's widenings `|the hand[ -]?off|`
# and `|handoff (is|was|will)|` passed every arm. Three shapes, because one seed guards one
# shape: indefinite article and definite article are the consumer's own rows; the copula form
# has no producer instance in the consumer's history and is SYNTHETIC, said so here.
P_NOUN="why haven't we done a handoff"
P_NOUN2="did all of the handoff steps run?"
P_NOUN3="the handoff was fine yesterday"

LG="$ROOT/logs/log.md"

# =============================================================================
# FIXTURE-BROKEN ARMS: prove each probe tree IS the state its assertions assume
# =============================================================================
# Without these the push battery is a check that cannot fire. A `mktemp -d` that is not a git
# repo returns ALLOW from every push case, and ALLOW is what four of the five expect.
if git -C "$P_NOGIT" rev-parse --git-dir >/dev/null 2>&1; then
  broken "the not-a-git-repo probe ($P_NOGIT) READS as a git repo — an ambient GIT_DIR or an enclosing repository is reaching it, so case (a) would assert the fail-safe path while exercising a live one"
fi
ok "probe shape: $P_NOGIT is NOT a git repo (case (a) really exercises the fail-safe path)"

for _p in "$P_NOREMOTE" "$P_UNPUSHED" "$P_PUSHED" "$P_AHEAD"; do
  git -C "$_p" rev-parse --git-dir >/dev/null 2>&1 || \
    broken "probe tree $_p is NOT a git repo — the push arm's outer guard would short-circuit and every verdict below would be the fail-safe one"
done
ok "probe shape: the four git probes are real repositories (the push arm's outer guard is satisfied)"

[ -z "$(git -C "$P_NOREMOTE" remote 2>/dev/null)" ] || \
  broken "the no-remote probe has a remote configured — case (b) would not be testing the environmental narrowing"
ok "probe shape: no-remote probe has zero remotes"

{ [ -n "$(git -C "$P_UNPUSHED" remote 2>/dev/null)" ] \
  && ! git -C "$P_UNPUSHED" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1; } || \
  broken "the unpushed probe is not 'remote configured, branch never published' — case (c) is not v0.434.0's state"
ok "probe shape: unpushed probe has a remote and NO upstream (v0.434.0's exact state)"

_pushed_ahead="$(git -C "$P_PUSHED" rev-list --count '@{u}..HEAD' 2>/dev/null)"
{ [ -n "$(git -C "$P_PUSHED" remote 2>/dev/null)" ] && [ "$_pushed_ahead" = "0" ]; } || \
  broken "the pushed probe is not 'upstream set, 0 ahead' (rev-list said '${_pushed_ahead:-<unreadable>}') — case (d) would not be testing the satisfied state"
ok "probe shape: pushed probe has an upstream and is 0 commits ahead"

_ahead_ahead="$(git -C "$P_AHEAD" rev-list --count '@{u}..HEAD' 2>/dev/null)"
[ "$_ahead_ahead" = "1" ] || \
  broken "the ahead probe is ${_ahead_ahead:-<unreadable>} commits ahead, not 1 — case (e) is not the stranded-work state"
ok "probe shape: ahead probe is exactly 1 commit ahead of its upstream"

# The recover battery's trees must carry BOTH step files, or the override has nothing to name
# and every case would fall back for a reason that is not the one under test.
for _pair in "$P_REC:$STEP_IMPL:$STEP_HANDOFF" "$P_REC_CLAUDE:$STEP_IMPL_C:$STEP_HANDOFF_C"; do
  _pd="${_pair%%:*}"; _rest="${_pair#*:}"; _si="${_rest%%:*}"; _sh="${_rest#*:}"
  { [ -r "$_pd/$_si" ] && [ -r "$_pd/$_sh" ]; } || \
    broken "recover probe $_pd is missing $_si or $_sh — the override resolves against those paths, so a fall-back verdict would say nothing about the predicate"
done
ok "probe shape: both recover trees carry a readable implementation.md AND handoff.md (core/ and .claude/ layouts)"

# =============================================================================
# SEED-PREMISE ARMS: the declared vocabulary classifies these seeds as claimed
# =============================================================================
# Every key-3 assertion rests on a claim about how the DECLARED patterns score one string.
# Those patterns live in pause-routing.json and can be edited without touching this file, at
# which point an assertion still passes while testing something else. These arms point the
# grammar at its own subjects and fail loudly instead.
INTENT_RE="$(jq -rj '.handoff_intent_pattern // ""' "$SCHEMA" 2>/dev/null)"
EXCL_RE="$(jq -rj '.handoff_mention_exclusion_pattern // ""' "$SCHEMA" 2>/dev/null)"
{ [ -n "$INTENT_RE" ] && [ -n "$EXCL_RE" ]; } || \
  broken "pause-routing.json declares no handoff_intent_pattern / handoff_mention_exclusion_pattern — key 3 would return 1 unconditionally"

isreq()  { grep -qiE "$INTENT_RE" <<<"$1"; }
ismech() { grep -qiE "$EXCL_RE"   <<<"$1"; }

{ isreq "$P_INTENT" && ! ismech "$P_INTENT"; } || \
  broken "seed premise dead: the declared vocabulary no longer reads '$P_INTENT' as a handoff REQUEST"
{ isreq "$P_BARE" && ! ismech "$P_BARE"; } || \
  broken "seed premise dead: the declared vocabulary no longer reads the bare word '$P_BARE' as a handoff REQUEST — that seed is the only one that can distinguish a field-value match from a whole-line match"
{ isreq "$P_DISCUSS" && ismech "$P_DISCUSS"; } || \
  broken "seed premise dead: '$P_DISCUSS' no longer matches BOTH the intent pattern and the mention exclusion — the exclusion case would pass without exercising the exclusion conjunct at all"
! isreq "$P_NOINTENT" || \
  broken "seed premise dead: '$P_NOINTENT' now reads as a handoff request"
! isreq "$P_AFTER" || \
  broken "seed premise dead: '$P_AFTER' now reads as a handoff REQUEST — it is the SECOND row of the two-row log, and if it is a request then a reader that keeps only the last block scores the same as one that flushes, and the flush mutant cannot be told apart from the shipped hook"
! ismech "$P_AFTER" || \
  broken "seed premise dead: '$P_AFTER' now matches the mention EXCLUSION — the exclusion is applied to the whole extracted prose, so the second row would veto the first and the two-row log would report NOT pending for the wrong reason"
{ isreq "$Q_INTENT" && ! ismech "$Q_INTENT"; } || \
  broken "seed premise dead: the lead-authored question '$Q_INTENT' no longer reads as a handoff request — the Question-line case could not detect that field being routed"
! isreq "$Q_NOINTENT" || \
  broken "seed premise dead: '$Q_NOINTENT' now reads as a handoff request"
{ ! isreq "$P_RESUME" && ismech "$P_RESUME"; } || \
  broken "seed premise dead: '$P_RESUME' no longer scores as a NON-request that matches the mention EXCLUSION — the per-row case below would then pass without exercising the exclusion's scope at all"
{ isreq "$P_TERSE" && ! ismech "$P_TERSE"; } || \
  broken "seed premise dead: the declared vocabulary no longer reads '$P_TERSE' as a handoff REQUEST — the final-sentence alternative is gone, and (g4) would report the shipped defect PC-S308-HANDOFF-INTENT-PATTERN-MISSES-TRAILING-TERSE-PHRASING as a fixture failure"
! isreq "$P_TERSE_NEAR" || \
  broken "seed premise dead: '$P_TERSE_NEAR' now reads as a handoff REQUEST — the final-sentence alternative has widened into a trailing-word match, which on the reference consumer's history admits five questions or denials about a handoff"
! isreq "$P_TERSE_NEAR2" || \
  broken "seed premise dead: the punctuated denial '$P_TERSE_NEAR2' now reads as a handoff REQUEST — the final-sentence alternative has widened into a trailing-word-plus-period match, which admits an operator saying a handoff was not wanted"
! ismech "$P_TERSE_NEAR2" || \
  broken "seed premise dead: '$P_TERSE_NEAR2' now matches the mention EXCLUSION, so its near-miss would pass for the wrong reason"
for _n in "$P_NOUN" "$P_NOUN2" "$P_NOUN3"; do
  { ! isreq "$_n" && ! ismech "$_n"; } || \
    broken "seed premise dead: the plain noun mention '$_n' now scores as a request or as mechanism discussion — the declaration's own description says a noun mention is neither, and a widening that admits it is the bare-substring match the description forbids"
done
ok "seed premise: the DECLARED vocabulary scores all fourteen log-prose seeds as this fixture assumes"

# The transcripts' own premises, DERIVED from the seeded files rather than restated.
_req_user="$(jq -rs '[.[]|select(.message.role=="user")|.message.content]|last // ""' "$T_REQ_OK" 2>/dev/null)"
_quiet_user="$(jq -rs '[.[]|select(.message.role=="user")|.message.content]|last // ""' "$T_QUIET" 2>/dev/null)"
{ isreq "$_req_user" && ! ismech "$_req_user"; } || \
  broken "the push battery's transcript no longer carries a handoff request as its last user message ('$_req_user') — Check 0 would never open and all five push cases would ALLOW"
{ ! isreq "$_quiet_user"; } || \
  broken "the on-disk battery's transcript ('$_quiet_user') now reads as a handoff request — the transcript path would fire and no on-disk verdict below would mean anything"
_quiet_ok_user="$(jq -rs '[.[]|select(.message.role=="user")|.message.content]|last // ""' "$T_QUIET_OK" 2>/dev/null)"
{ ! isreq "$_quiet_ok_user"; } || \
  broken "the sticky battery's transcript ('$_quiet_ok_user') now reads as a handoff request — the transcript channel would arm the guard and no sticky verdict below would mean anything"
ok "seed premise: the push transcript IS a request and the on-disk transcript is NOT (so an on-disk BLOCK can only have come from disk)"

# =============================================================================
# ai-dlc-continue.sh — THE PUSH ARM
# =============================================================================
push_case() { # push_case <label> <projdir> <expected> <why> <control-why>
  local label="$1" proj="$2" want="$3" why="$4" cwhy="$5" r
  reset_state "$proj"
  r="$(verdict "$(drive "$proj" "$SESS_A" "$T_REQ_OK")")"
  if [ "$r" = "$want" ]; then
    ok "$label"
    case "$label" in
      "(b) "*) B_b=1 ;; "(d) "*) B_d=1 ;; "(e) "*) B_e=1 ;;
      "(s2a) "*) B_s2a=1 ;; "(s2d) "*) B_s2d=1 ;; "(s2e) "*) B_s2e=1 ;;
    esac
  else
    bad "$why (got $r)"
  fi
  if [ "$want" = allow ]; then
    reset_state "$proj"
    r="$(verdict "$(drive "$proj" "$SESS_A" "$T_REQ_NOBLK")")"
    [ "$r" = block ] && ok "  control: the same tree BLOCKS once the resume block is stripped — the hook runs here" \
                     || bad "$cwhy (got $r) — the ALLOW above is unreadable, it may be a hook that never ran"
  fi
}

push_case "(a) not a git repo at all -> ALLOW (fail-safe: today's behaviour preserved)" \
  "$P_NOGIT" allow \
  "a handoff in a directory that is not a git repo was BLOCKED — the push arm invented a finding where nothing can be asserted" \
  "the not-a-git-repo tree did not block a missing resume block either"

push_case "(b) git repo, NO remote configured -> ALLOW (step 3 forgives 'no remote configured')" \
  "$P_NOREMOTE" allow \
  "a handoff in a local-only repo was BLOCKED — a repo with no remote can NEVER satisfy a push assertion, so this wedges every handoff in a local tree until the backoff releases" \
  "the no-remote tree did not block a missing resume block either"

push_case "(c) remote exists, branch NEVER pushed -> BLOCK (v0.434.0's exact state)" \
  "$P_UNPUSHED" block \
  "a handoff on an unpublished branch was ALLOWED — the commits it just made exist only on this machine, and from inside the session that looks exactly like a pushed branch" \
  ""

push_case "(d) remote, pushed, 0 commits ahead -> ALLOW (the satisfied state)" \
  "$P_PUSHED" allow \
  "BLOCKED a handoff whose branch is published and up to date — the check fires on COMPLIANCE with step 3" \
  "the pushed tree did not block a missing resume block either"

push_case "(e) remote, pushed, 1 commit AHEAD -> BLOCK (offline / protected branch land here)" \
  "$P_AHEAD" block \
  "a handoff with unpushed commits was ALLOWED — this is the stranded-work state the operator needs told about" \
  ""

# =============================================================================
# ai-dlc-continue.sh — THE COMMIT ARM (step 2)
# =============================================================================
# The push arm counts COMMITS, so a skipped step 2 reads `ahead 0` and passes. The commit arm
# reads the working tree with the pipeline root excluded. Three directions: dirty work outside
# the root BLOCKS (tracked and untracked), dirt the hook ITSELF wrote under a tracked root
# ALLOWS, and clean is (d) above.
P_DIRTY="$ROOT/proj-dirty"
P_UNTRACKED="$ROOT/proj-untracked"
P_STATEDIRTY="$ROOT/proj-statedirty"
COMMIT_MARK="step 2's commit has NOT landed"
ps_excl() { git -C "$1" status --porcelain -- ':/' ':(exclude)_bmad-output' 2>/dev/null | sed '/^$/d' | wc -l | tr -d ' '; }
ps_raw()  { git -C "$1" status --porcelain 2>/dev/null | sed '/^$/d' | wc -l | tr -d ' '; }

# PROBE SHAPES, TAKEN AFTER reset_state, because that is the tree the drive sees.
for _p in "$P_DIRTY" "$P_UNTRACKED" "$P_STATEDIRTY"; do
  reset_state "$_p"
  _a="$(git -C "$_p" rev-list --count '@{u}..HEAD' 2>/dev/null)"
  [ "$_a" = "0" ] || broken "commit-arm probe $_p is ${_a:-<unreadable>} commits ahead, not 0 — the push arm would block it and the commit arm would not be isolated"
done
reset_state "$P_DIRTY"
[ "$(git -C "$P_DIRTY" status --porcelain -- seed.txt 2>/dev/null)" = " M seed.txt" ] || \
  broken "the dirty probe does not carry a MODIFIED tracked seed.txt — case (s2a) is not the skipped-step-2 state"
reset_state "$P_UNTRACKED"
[ "$(git -C "$P_UNTRACKED" status --porcelain -- left-behind.md 2>/dev/null)" = "?? left-behind.md" ] || \
  broken "the untracked probe does not carry an untracked left-behind.md — case (s2b) is not the teammate-left-work state"
# The pushed tree (d) is the clean direction, and every ALLOW probe carries untracked dirt under
# the root from reset_state: that is the control that the excluded form CAN see the root (raw
# >= 1) and the assertion that it does not count it (excluded = 0), in one invocation.
reset_state "$P_PUSHED"
_raw="$(ps_raw "$P_PUSHED")"; _ex="$(ps_excl "$P_PUSHED")"
{ [ "$_raw" -ge 1 ] && [ "$_ex" = "0" ]; } || \
  broken "pushed probe: raw porcelain $_raw (want >=1, the root's untracked state) and excluded $_ex (want 0) — case (d) does not separate root dirt from work"
ok "probe shape: (s2a) tracked edit, (s2b) untracked file, both 0 ahead; (d) root dirt raw=$_raw excluded=$_ex"

push_case "(s2a) pushed, 0 ahead, a TRACKED file modified -> BLOCK (step 2 skipped; the push arm reads ahead 0)" \
  "$P_DIRTY" block \
  "a handoff with an uncommitted tracked edit was ALLOWED — the push arm counts commits, and this tree is 0 ahead with the work never committed" \
  ""

push_case "(s2b) pushed, 0 ahead, an UNTRACKED file outside the root -> BLOCK (work a teammate left behind)" \
  "$P_UNTRACKED" block \
  "a handoff with an untracked file outside the pipeline root was ALLOWED — step 2 names work teammates left in the working tree" \
  ""

# (s2a-k) THE REASON NAMES STEP 2 AND NOT STEP 3. This tree is pushed and 0 ahead, so the push
# text would tell the lead the branch is ahead of its upstream, which is false.
reset_state "$P_DIRTY"
rr="$(reason "$(drive "$P_DIRTY" "$SESS_A" "$T_REQ_OK")")"
if [ -z "$rr" ]; then
  bad "(s2a-k) dirty tree: the block carried NO reason at all"
elif ! has "$rr" "$COMMIT_MARK"; then
  bad "(s2a-k) dirty tree: the reason does NOT name step 2's commit. It reads: $(printf '%s' "$rr" | head -c 120)"
elif has "$rr" "$PUSH_MARK" || has "$rr" "$RESUME_MARK" || has "$rr" "$TEAM_MARK"; then
  bad "(s2a-k) dirty tree: the reason names step 2 AND another step — the dispatch is not exclusive"
elif ! has "$rr" "seed.txt"; then
  bad "(s2a-k) dirty tree: the reason does not list the uncommitted path seed.txt"
else
  ok "(s2a-k) dirty tree: the emitted reason is the STEP 2 text alone and lists seed.txt"
fi
_lg="$P_DIRTY/_bmad-output/pipeline-continuation-log.md"
grep -qF "step 2's commit has not landed (1 uncommitted path(s) outside _bmad-output)" "$_lg" 2>/dev/null \
  && ok "(s2a-log) the HANDOFF_GUARD_BLOCK row names step 2 and counts 1 path" \
  || bad "(s2a-log) the block row does not name step 2's commit with a count of 1"

# (s2c) THE LEGITIMATE DIRT, PRODUCED BY THE HOOK. A tracked continuation log under the root; the
# first drive (no resume block) BLOCKS and appends its row to that tracked file, which is the
# write a correct handoff leaves behind. The second drive is compliant and must ALLOW over it.
reset_state "$P_STATEDIRTY"
git -C "$P_STATEDIRTY" checkout -q -- _bmad-output/pipeline-continuation-log.md 2>/dev/null
r="$(verdict "$(drive "$P_STATEDIRTY" "$SESS_A" "$T_REQ_NOBLK")")"
[ "$r" = block ] && ok "(s2c) control: the tracked-root tree BLOCKS a missing resume block — the hook runs here and writes its row" \
                 || bad "(s2c) control: the tracked-root tree returned $r for a missing resume block — the hook did not run, so (s2c) below is unreadable"
_st="$(git -C "$P_STATEDIRTY" status --porcelain -- _bmad-output/pipeline-continuation-log.md 2>/dev/null)"
_ex="$(ps_excl "$P_STATEDIRTY")"
{ [ "$_st" = " M _bmad-output/pipeline-continuation-log.md" ] && [ "$_ex" = "0" ]; } || \
  broken "(s2c) premise: the hook's own row did not leave the tracked log MODIFIED with nothing outside the root (status '$_st', excluded $_ex) — the case would not exercise the exclusion"
r="$(verdict "$(drive "$P_STATEDIRTY" "$SESS_A" "$T_REQ_OK")")"
[ "$r" = allow ] && ok "(s2c) tracked pipeline root MODIFIED by the hook's own block row -> ALLOW (pipeline state is not step 2's subject)" \
                 || bad "(s2c) a compliant handoff was BLOCKED over the hook's OWN write to the tracked continuation log (got $r) — with the root in scope every block dirties the tree and wedges the next Stop"

# (s2d)-(s2g) CLAUDE CODE'S OWN FILES, in a tree whose .gitignore does not cover .claude/. Two
# exclusions, each with an ALLOW case and a BLOCK twin one property away: a tracked dirty
# settings.json is still work, and `.claude/worktrees-not/` is a sibling the worktrees
# exclusion must not swallow. Each tree's one dirty path is asserted before it is driven.
P_CL_LOCAL="$ROOT/proj-claude-local"; P_CL_WT="$ROOT/proj-claude-wt"
P_CL_TRACKED="$ROOT/proj-claude-tracked"; P_CL_NEAR="$ROOT/proj-claude-near"
for _pair in "$P_CL_LOCAL|?? .claude/settings.local.json" "$P_CL_WT|?? .claude/worktrees/" \
             "$P_CL_TRACKED| M .claude/settings.json" "$P_CL_NEAR|?? .claude/worktrees-not/"; do
  _pd="${_pair%%|*}"; _want="${_pair#*|}"
  reset_state "$_pd"
  _got="$(git -C "$_pd" status --porcelain -- .claude 2>/dev/null)"
  _a="$(git -C "$_pd" rev-list --count '@{u}..HEAD' 2>/dev/null)"
  { [ "$_got" = "$_want" ] && [ "$_a" = "0" ]; } || \
    broken ".claude probe $_pd: status under .claude/ is '$_got' (want '$_want') and ${_a:-<unreadable>} ahead (want 0) — the case would not isolate its one path"
done
ok "probe shape: the four .claude/ trees each carry exactly their one dirty path, 0 ahead"

push_case "(s2d) untracked .claude/settings.local.json -> ALLOW (Claude Code's per-user file is never work)" \
  "$P_CL_LOCAL" allow \
  "a compliant handoff was BLOCKED on .claude/settings.local.json — the lead is told to commit a per-user harness file" \
  "the settings.local.json tree did not block a missing resume block either"
push_case "(s2e) untracked .claude/worktrees/agent-1/ -> ALLOW (an agent worktree is its own checkout)" \
  "$P_CL_WT" allow \
  "a compliant handoff was BLOCKED on an agent worktree under .claude/worktrees/ — the lead is told to git add another checkout" \
  "the worktrees tree did not block a missing resume block either"
push_case "(s2f) TRACKED .claude/settings.json modified -> BLOCK (only the two named paths are excluded)" \
  "$P_CL_TRACKED" block \
  "a handoff with an uncommitted edit to the tracked .claude/settings.json was ALLOWED — the exclusion swallowed all of .claude/" \
  ""
push_case "(s2g) untracked .claude/worktrees-not/x -> BLOCK (a sibling prefix is not the worktrees directory)" \
  "$P_CL_NEAR" block \
  "a handoff with untracked work in .claude/worktrees-not/ was ALLOWED — the worktrees exclusion matches by prefix, not by directory" \
  ""

# (s2h) THE PROJECT DIR BELOW THE REPOSITORY TOP. The exclusions are relative to the project
# dir, so reset_state's untracked `sub/_bmad-output` is excluded and a clean tree ALLOWS; the
# same tree with tracked `sub/notes.md` modified BLOCKS.
P_SUB="$ROOT/proj-subrepo"
reset_state "$P_SUB/sub"
_raw="$(git -C "$P_SUB" status --porcelain 2>/dev/null)"
[ "$_raw" = "?? sub/_bmad-output/" ] || \
  broken "(s2h) premise: the subdirectory repo's only dirt should be '?? sub/_bmad-output/', got '$_raw'"
push_case "(s2h) project dir is a SUBDIRECTORY, only <sub>/_bmad-output untracked -> ALLOW" \
  "$P_SUB/sub" allow \
  "a compliant handoff from a subdirectory project was BLOCKED on its own pipeline root — the exclusion is anchored at the repo top, not the project dir" \
  "the subdirectory project did not block a missing resume block either"
echo "edited" >> "$P_SUB/sub/notes.md"
push_case "(s2h') the same subdirectory project, tracked sub/notes.md modified -> BLOCK" \
  "$P_SUB/sub" block \
  "a subdirectory project with an uncommitted tracked edit was ALLOWED" \
  ""
git -C "$P_SUB" checkout -q -- sub/notes.md

# --- (k) the block REASON names the right STEP ------------------------------------------
#
# THE DISPATCH-ORDERING REGRESSION, and the one a careless rewrite reintroduces. With two arms
# the cause could be inferred from RESUME_OK; with three that inference is wrong and answers a
# missing PUSH with the teammate text. A verdict-only assertion cannot see it: the hook still
# blocks, and the lead is simply sent to fix something that is not broken.
reason_case() { # reason_case <label> <projdir>
  local label="$1" rr
  reset_state "$2"
  rr="$(reason "$(drive "$2" "$SESS_A" "$T_REQ_OK")")"
  if [ -z "$rr" ]; then
    bad "(k) $label: the block carried NO reason at all — nothing was dispatched"
  elif ! has "$rr" "$PUSH_MARK"; then
    bad "(k) $label: the emitted reason does NOT name step 3's push. It reads: $(printf '%s' "$rr" | head -c 120)"
  elif has "$rr" "$RESUME_MARK" || has "$rr" "$TEAM_MARK"; then
    bad "(k) $label: the emitted reason names step 3 AND another step — the dispatch is not exclusive"
  else
    ok "(k) $label: only the push arm failed, and the emitted reason is the STEP 3 text (not the teammate or resume-line text)"
    B_k=1
  fi
}
# ONE TREE, DELIBERATELY. The ahead-of-upstream tree reaches the identical dispatch through the
# identical PUSH_OK value, so a second reason_case here asserts nothing new -- and it made the
# ahead-test mutant fail TWO arms, which is the entanglement `fixture-mutants.md` warns about:
# assertion (e) OWNS "1 commit ahead -> BLOCK", so this arm stands down for it.
reason_case "unpushed branch" "$P_UNPUSHED"

# --- (t1) STEP ORDER WITH NO RESUME BLOCK (BL-698) ----------------------------------------
# The COMMIT and PUSH arms once also required the resume block, so a handoff whose step 2 or 3
# had not landed AND whose resume line was not yet emitted got the RESUME text -- told to emit
# a resume prompt for an unpushed branch. Every case here drives T_REQ_NOBLK and asserts the
# TEXT, because the verdict (block) is the same under the defect.
P_DIRTY_UNPUSHED="$ROOT/proj-dirty-unpushed"
reset_state "$P_DIRTY_UNPUSHED"
{ [ "$(git -C "$P_DIRTY_UNPUSHED" status --porcelain -- seed.txt 2>/dev/null)" = " M seed.txt" ] \
  && ! git -C "$P_DIRTY_UNPUSHED" rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1 \
  && [ -n "$(git -C "$P_DIRTY_UNPUSHED" remote 2>/dev/null)" ]; } || \
  broken "(t1) premise: proj-dirty-unpushed is not dirty AND unpublished with a remote — the both-bad case would not have both steps unsatisfied"
ok "probe shape: (t1-both) carries a modified tracked seed.txt, a remote, and no upstream"
t1_case() { # t1_case <label> <projdir> <want-mark> <failmsg> [extra-mark]
  local rr
  reset_state "$2"
  rr="$(reason "$(drive "$2" "$SESS_A" "$T_REQ_NOBLK")")"
  if [ -z "$rr" ]; then
    bad "(t1) $1: the block carried NO reason at all"
  elif ! has "$rr" "$3"; then
    bad "(t1) $1: $4. It reads: $(printf '%s' "$rr" | head -c 120)"
  elif [ "$3" != "$RESUME_MARK" ] && has "$rr" "$RESUME_MARK"; then
    bad "(t1) $1: the reason carries the RESUME text as well — the dispatch is not exclusive"
  elif [ -n "${5:-}" ] && ! has "$rr" "$5"; then
    bad "(t1) $1: the reason lacks '$5'"
  else
    ok "(t1) $1"
    case "$1" in
      "push not landed, NO resume block"*) B_t1push=1 ;;
      "commit not landed, NO resume block"*) B_t1commit=1 ;;
    esac
  fi
}
t1_case "push not landed, NO resume block -> the PUSH text, not RESUME" "$P_UNPUSHED" "$PUSH_MARK" \
  "an unpublished branch with no resume block was answered with something other than step 3's push — the lead is told to emit a resume prompt for a branch that exists only on this machine"
t1_case "commit not landed, NO resume block -> the COMMIT text" "$P_DIRTY" "$COMMIT_MARK" \
  "a dirty tree with no resume block was answered with something other than step 2's commit"
t1_case "commit AND push not landed, NO resume block -> the COMMIT text (step 2 before step 3)" "$P_DIRTY_UNPUSHED" "$COMMIT_MARK" \
  "a dirty, unpublished tree with no resume block was not answered with step 2 first"
t1_case "ahead of upstream, NO resume block -> the PUSH text with the environmental clause (finish steps 4 and 5)" "$P_AHEAD" "$PUSH_MARK" \
  "a branch 1 commit ahead with no resume block was not answered with step 3's push" \
  "finish steps 4 and 5 in this same turn"
t1_case "everything landed, NO resume block -> the RESUME text (control: the resume arm still answers)" "$P_PUSHED" "$RESUME_MARK" \
  "a pushed, clean tree with no resume block was not answered with the resume text"
# push not landed WITH the resume block is reason_case (k) above: the PUSH text, unchanged.

# --- (pb) A BACKGROUNDED PUSH STILL RUNNING DEFERS THE GUARD (BL-698) ----------------------
# The harness moves a foreground push to the background at its 600000 ms timeout and records
# `toolUseResult.backgroundTaskId` on the tool result; it writes a `queue-operation` enqueue
# naming that task id when the task exits. Record shapes transcribed from the reference
# consumer's session (graph a0701ce0, lines 1825, 1826 and 2005). Built here, at drive time,
# so the in-ceiling timestamp is NOW. The pause flag is up, as it is in a directed handoff, so
# the deferred Stop falls through to Check 1 and the log must carry BOTH rows.
PB_DEF="HANDOFF_GUARD_DEFERRED_BY_PUSH"
pb_tx() { # pb_tx <out> <bg: run|enq> <iso-ts> [bash-command] [agent: yes -> an Agent dispatch first]
  : > "$1"
  [ "${5:-}" = yes ] && jq -nc '{type:"assistant",message:{role:"assistant",content:[{type:"tool_use",id:"toolu_PBAGENT1",name:"Agent",input:{subagent_type:"dev"}}]}}' >> "$1"
  jq -nc '{type:"user",message:{role:"user",content:"hand off the sprint"}}' >> "$1"
  jq -nc --arg c "${4:-git push -u origin HEAD}" '{type:"assistant",message:{role:"assistant",content:[{type:"tool_use",id:"toolu_PB1",name:"Bash",input:{command:$c,timeout:600000}}]}}' >> "$1"
  jq -nc --arg ts "$3" '{type:"user",timestamp:$ts,toolUseResult:{stdout:"",stderr:"",interrupted:false,backgroundTaskId:"bPBtask01",timedOutAfterMs:600000},message:{role:"user",content:[{type:"tool_result",tool_use_id:"toolu_PB1",content:"Command running in background with ID: bPBtask01"}]}}' >> "$1"
  [ "$2" = enq ] && jq -nc '{type:"queue-operation",operation:"enqueue",content:"<task-notification>\n<task-id>bPBtask01</task-id>\n<tool-use-id>toolu_PB1</tool-use-id>\n<status>completed</status>\n</task-notification>"}' >> "$1"
  jq -nc '{type:"assistant",message:{role:"assistant",content:[{type:"text",text:"The push is still running in the background."}]}}' >> "$1"
}
T_PB_RUN="$ROOT/pb-run.jsonl"; T_PB_ENQ="$ROOT/pb-enq.jsonl"; T_PB_OLD="$ROOT/pb-old.jsonl"
T_PB_MID="$ROOT/pb-mid.jsonl"; T_PB_WATCH="$ROOT/pb-watch.jsonl"; T_PB_AGENT="$ROOT/pb-agent.jsonl"
# THE PUSH'S AGE IS DECIDED BY AN INJECTED CLOCK, NOT BY HOW LONG THE FIXTURE TOOK. The stamps are cut from one
# epoch captured once, and every drive that reads them puts a `date` shim first on the hook's PATH (HCA_PATH)
# that answers `date +%s` with that epoch, so the age the hook computes is exactly 0 and 1800 whatever the load.
# Every other `date` call passes through to the real one. reset_state/drive clear the stall state before each
# drive, so no stamp written under the real clock is read under the pinned one.
HCA_EPOCH="$(date +%s)"; HCA_REAL_DATE="$(command -v date)"; mkdir -p "$ROOT/clk"
printf '#!%s\nif [ "$#" -eq 1 ] && [ "$1" = "+%%s" ]; then echo %s; exit 0; fi\nexec %s "$@"\n' "$(type -P bash)" "$HCA_EPOCH" "$HCA_REAL_DATE" > "$ROOT/clk/date"
chmod +x "$ROOT/clk/date"
# RESOLUTION FIRST, THEN THE ANSWER (BL-868). A shim that is not executable is skipped by PATH lookup and the REAL date
# answers instead, which equals HCA_EPOCH only while the clock has not ticked since HCA_EPOCH was taken -- a coin flip on
# the second boundary. `chmod` must be in tools.decl for the chmod above to run in the sandbox; absent, this is BROKEN every run.
[ "$(PATH="$ROOT/clk:$PATH" command -v date)" = "$ROOT/clk/date" ] && [ "$(PATH="$ROOT/clk:$PATH" date +%s)" = "$HCA_EPOCH" ] \
  || broken "(pb) the injected clock shim at $ROOT/clk/date is not the date PATH resolves (is chmod declared in tools.decl?), or does not answer date +%s"
_pb_now="$(jq -nr --argjson e "$HCA_EPOCH" '$e | strftime("%Y-%m-%dT%H:%M:%S.000Z")')"
# 1800 s back: past the old one-sample 729 s ceiling, inside the derived 3004 s one.
_pb_mid="$(jq -nr --argjson e "$HCA_EPOCH" '$e - 1800 | strftime("%Y-%m-%dT%H:%M:%S.000Z")')"
pb_tx "$T_PB_RUN" run "$_pb_now"; pb_tx "$T_PB_ENQ" enq "$_pb_now"; pb_tx "$T_PB_OLD" run "2020-01-01T00:00:00.000Z"
pb_tx "$T_PB_MID" run "$_pb_mid"
# A backgrounded WATCHER that carries `git push` as TEXT, never as its program.
pb_tx "$T_PB_WATCH" run "$_pb_now" "until grep -q 'git push' push.log; do sleep 5; done; echo \"git push finished\""
pb_tx "$T_PB_AGENT" run "$_pb_now" "git push -u origin HEAD" yes
_pb_user="$(jq -rs '[.[]|select(.message.role=="user")|.message.content|(if type=="string" then . else (map(select(.type=="text")|.text)|join(" ")) end)]|map(select(length>0))|last // ""' "$T_PB_RUN" 2>/dev/null)"
{ isreq "$_pb_user" && ! ismech "$_pb_user"; } || \
  broken "(pb) premise: the background-push transcript's last user text ('$_pb_user') is not a handoff request — the tool-result record displaced it, and no (pb) verdict would mean anything"
pb_drive() { # pb_drive <transcript> [hooksdir] -> raw stdout; the pause flag is up
  reset_state "$P_UNPUSHED"; touch "$P_UNPUSHED/_bmad-output/pipeline-paused.flag"
  HCA_PATH="$ROOT/clk:$PATH" drive "$P_UNPUSHED" "$SESS_A" "$1" "${2:-$HOOKS_DIR}"
}
pb_log() { printf '%s' "$P_UNPUSHED/_bmad-output/pipeline-continuation-log.md"; }

o="$(pb_drive "$T_PB_RUN")"
if [ "$(verdict "$o")" != allow ]; then
  bad "(pb1) a push backgrounded by the harness with NO exit record was BLOCKED — the lead is told to push again in the foreground, a second concurrent pre-push suite. It reads: $(reason "$o" | head -c 120)"
elif ! grep -qF -- "-- $PB_DEF" "$(pb_log)"; then
  bad "(pb1) ALLOWED, but the log carries no $PB_DEF row — the allow did not come from the deferral"
elif ! grep -qF -- "bPBtask01" "$(pb_log)"; then
  bad "(pb1) the $PB_DEF row does not name the background task id"
elif ! grep -qF -- "-- ALLOWED_BY_PAUSE" "$(pb_log)"; then
  bad "(pb1) deferred, but the Stop did not fall through to Check 1 (no ALLOWED_BY_PAUSE row)"
else
  ok "(pb1) background push, no exit record -> ALLOW, a $PB_DEF row naming the task, then ALLOWED_BY_PAUSE (the fall-through reaches Check 1)"
  B_pb1=1
fi
# (pb1b) THE PIPED FORM A REAL LEAD WROTE (graph 6249c621, bun00ozwh): `git push -u origin HEAD 2>&1 | tail -15`.
T_PB_PIPE="$ROOT/pb-pipe.jsonl"; pb_tx "$T_PB_PIPE" run "$_pb_now" "git push -u origin HEAD 2>&1 | tail -15"
o="$(pb_drive "$T_PB_PIPE")"
if [ "$(verdict "$o")" = allow ] && grep -qF -- "-- $PB_DEF" "$(pb_log)"; then
  ok "(pb1b) the piped background push, no exit record -> ALLOW with a $PB_DEF row"
else
  bad "(pb1b) the piped background push (git push ... | tail) was not deferred -- push_bg_read misses a form the reference consumer's lead used"
fi
o="$(pb_drive "$T_PB_ENQ")"
if ! has "$(reason "$o")" "$PUSH_MARK"; then
  bad "(pb2) the SAME transcript with the push's exit record (enqueue) was not answered with the PUSH text — the deferral outlives the push. It reads: $(reason "$o" | head -c 120)"
elif grep -qF -- "-- $PB_DEF" "$(pb_log)"; then
  bad "(pb2) the PUSH text was emitted but a $PB_DEF row was also written"
else
  ok "(pb2) background push WITH its exit record (enqueue) -> the PUSH text, no deferral row"
fi
o="$(pb_drive "$T_PB_OLD")"
if ! has "$(reason "$o")" "$PUSH_MARK"; then
  bad "(pb3) a background push past the ceiling was not answered with the PUSH text — a lost exit record defers the guard forever. It reads: $(reason "$o" | head -c 120)"
else
  ok "(pb3) background push with no exit record, PAST the ceiling -> the PUSH text, never silence"
  B_pb3=1
fi
# (pb3b) PAST THE CEILING THE TEXT MUST NOT SAY "WAIT". A lead told to wait there waits; each
#        wait is a counted block, and BACKOFF then allows the unpushed handoff. Driven three
#        times WITHOUT clearing the stall state -- the whole BACKOFF window -- and every one must
#        carry the overrun clause and none the wait clause.
WAIT_MARK="do not issue another; end the turn and wait"
OVERRUN_MARK="has overrun its ceiling"
reset_state "$P_UNPUSHED"; touch "$P_UNPUSHED/_bmad-output/pipeline-paused.flag"
_pb3b=""
for _i in 1 2 3; do
  o="$(jq -nc --arg t "$T_PB_OLD" --arg s "$SESS_A" '{transcript_path:$t,session_id:$s}' \
       | CLAUDE_PROJECT_DIR="$P_UNPUSHED" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" bash "$HOOKS_DIR/ai-dlc-continue.sh" 2>/dev/null)"
  rr="$(reason "$o")"
  if has "$rr" "$OVERRUN_MARK" && ! has "$rr" "$WAIT_MARK"; then _pb3b="${_pb3b}o"; else _pb3b="${_pb3b}x"; fi
done
if [ "$_pb3b" = ooo ]; then
  ok "(pb3b) past the ceiling, three Stops in the BACKOFF window -> each the overrun clause, none the wait clause"; B_pb3b=1
else
  bad "(pb3b) past the ceiling the PUSH text told the lead to wait, or lacked the overrun clause ($_pb3b) — the lead waits into BACKOFF, which allows the unpushed handoff"
fi
rm -f "$P_UNPUSHED/_bmad-output/handoff-guard-state.txt"
# (pb3c) and with NO background push the PUSH text carries neither clause.
o="$(pb_drive "$T_REQ_NOBLK")"; rr="$(reason "$o")"
{ has "$rr" "$PUSH_MARK" && ! has "$rr" "$OVERRUN_MARK" && ! has "$rr" "$WAIT_MARK"; } \
  && ok "(pb3c) no background push -> the PUSH text with neither the wait nor the overrun clause" \
  || bad "(pb3c) with no background push the PUSH text carried a background-push clause"

# (pb10) AN EMPTY ID JOINS NOTHING. A Bash git push whose tool_use carries no `id` and whose
#        tool_result carries no `tool_use_id`, backgrounded with no enqueue: the two absent ids
#        must not join as "" == "". The PUSH text, no deferral.
T_PB_NOID="$ROOT/pb-noid.jsonl"
{ jq -nc '{type:"user",message:{role:"user",content:"hand off the sprint"}}'
  jq -nc '{type:"assistant",message:{role:"assistant",content:[{type:"tool_use",name:"Bash",input:{command:"git push -u origin HEAD",timeout:600000}}]}}'
  jq -nc --arg ts "$_pb_now" '{type:"user",timestamp:$ts,toolUseResult:{backgroundTaskId:"bPBnoid01",timedOutAfterMs:600000},message:{role:"user",content:[{type:"tool_result",content:"Command running in background with ID: bPBnoid01"}]}}'
  jq -nc '{type:"assistant",message:{role:"assistant",content:[{type:"text",text:"The push is still running in the background."}]}}'
} > "$T_PB_NOID"
o="$(pb_drive "$T_PB_NOID")"
if { has "$(reason "$o")" "$PUSH_MARK" && ! grep -qF -- "-- $PB_DEF" "$(pb_log)"; }; then
  ok "(pb10) a backgrounded push with NO tool_use id and NO tool_result id -> the PUSH text, no deferral (an empty id joins nothing)"; B_pb10=1
else
  bad "(pb10) two ABSENT ids joined as equal and deferred the guard. It reads: $(reason "$o" | head -c 120)"
fi
o="$(pb_drive "$T_REQ_NOBLK")"
if ! has "$(reason "$o")" "$PUSH_MARK" || grep -qF -- "-- $PB_DEF" "$(pb_log)"; then
  bad "(pb4) a transcript with NO background push was not answered with the PUSH text alone (pause flag up)"
else
  ok "(pb4) no background push in the transcript, pause flag up -> the PUSH text, no deferral row (the id is required)"
  B_pb4=1
fi

# (pb5) THE CEILING IS THE LONGEST RECORDED GATE, NOT ONE SAMPLE. A push backgrounded 1800 s ago
#       is past the motivating push's 729 s and inside the derived 3004 s: it still DEFERS.
o="$(pb_drive "$T_PB_MID")"
if { [ "$(verdict "$o")" = allow ] && grep -qF -- "-- $PB_DEF" "$(pb_log)"; }; then
  ok "(pb5) background push 1800 s old, no exit record -> still DEFERRED (the ceiling covers a gate longer than one sample)"; B_pb5=1
else
  bad "(pb5) a push backgrounded 1800 s ago was not deferred — a recorded consumer gate ran 3604 s, so the guard would start a second concurrent suite under it. It reads: $(reason "$o" | head -c 120)"
fi

# (pb6) A WATCHER IS NOT A PUSH. A backgrounded Bash command that carries `git push` only as
#       TEXT (a grep pattern, an echo) defers nothing: the PUSH text is the answer.
o="$(pb_drive "$T_PB_WATCH")"
if { has "$(reason "$o")" "$PUSH_MARK" && ! grep -qF -- "-- $PB_DEF" "$(pb_log)"; }; then
  ok "(pb6) a backgrounded watcher carrying 'git push' as text, no exit record -> the PUSH text, no deferral (git push must be the program)"; B_pb6=1
else
  bad "(pb6) a backgrounded watcher that only MENTIONS git push deferred the guard — a substring match. It reads: $(reason "$o" | head -c 120)"
fi

# (pb7)-(pb9) THE DEFERRAL REPLACES THE PUSH ANSWER ONLY. With a push in flight, each earlier
#       step keeps its own text, and no deferral row is written. One world per arm, each in a
#       tree whose only other unsatisfied step is the push.
pbx_drive() { # pbx_drive <projdir> <transcript> [hooksdir] -> raw stdout; the pause flag is up
  reset_state "$1"; touch "$1/_bmad-output/pipeline-paused.flag"
  HCA_PATH="$ROOT/clk:$PATH" drive "$1" "$SESS_A" "$2" "${3:-$HOOKS_DIR}"
}
pbx_log() { printf '%s' "$1/_bmad-output/pipeline-continuation-log.md"; }
INFL_MARK="table has NO data rows while"
# (pb7) INFLIGHT: an Agent dispatch with a ledger row and a meta sidecar, no stop record, and no
#       snapshot (so the table has no rows). The sidecar dir is the harness's own path,
#       `${TRANSCRIPT%.jsonl}/subagents/`, the one handoff-resume-guard's worlds use.
mkdir -p "${T_PB_AGENT%.jsonl}/subagents"
jq -nc '{toolUseId:"toolu_PBAGENT1",agentType:"dev"}' > "${T_PB_AGENT%.jsonl}/subagents/agent-apbfixture0001.meta.json"
pb7_world() { # pb7_world <projdir>: the ledger row is written after reset_state, which does not remove it
  jq -nc '{v:1,ts:"2026-10-18T17:00:00Z",name:"dev",role:"dev",tool_use_id:"toolu_PBAGENT1"}' > "$1/_bmad-output/spawn-ledger.jsonl"
}
reset_state "$P_UNPUSHED"; pb7_world "$P_UNPUSHED"; touch "$P_UNPUSHED/_bmad-output/pipeline-paused.flag"
o="$(HCA_PATH="$ROOT/clk:$PATH" drive "$P_UNPUSHED" "$SESS_A" "$T_PB_AGENT")"
rr="$(reason "$o")"
if has "$rr" "$INFL_MARK" && ! grep -qF -- "-- $PB_DEF" "$(pbx_log "$P_UNPUSHED")"; then
  ok "(pb7) push in flight AND an empty In-Flight table with a dispatch outstanding -> the INFLIGHT text, no deferral"
  B_pb7=1
else
  bad "(pb7) with a push in flight, an unrecorded teammate was not answered with the INFLIGHT text (or a deferral row was written) — the deferral swallowed step 1. It reads: $(printf '%s' "$rr" | head -c 120)"
fi
rm -f "$P_UNPUSHED/_bmad-output/spawn-ledger.jsonl"
# (pb8) TEAMMATES: a snapshot whose In-Flight table still carries an `in-flight` row.
reset_state "$P_UNPUSHED"; touch "$P_UNPUSHED/_bmad-output/pipeline-paused.flag"
printf '# Pipeline Snapshot\n\n## Pipeline Position\ncurrent_step_file: implementation.md\n\n## In-Flight Teammates\n\nagent | role | deliverable | dispatched-at | status\ndev | dev | docs/x.md | 2026-10-18T17:00:00Z | in-flight\n\n## Context Reminders\ncontext_reminders_sent: none\n' \
  > "$P_UNPUSHED/_bmad-output/pipeline-snapshot.md"
o="$(HCA_PATH="$ROOT/clk:$PATH" drive "$P_UNPUSHED" "$SESS_A" "$T_PB_RUN")"
rr="$(reason "$o")"
if has "$rr" "$TEAM_MARK" && ! grep -qF -- "-- $PB_DEF" "$(pbx_log "$P_UNPUSHED")"; then
  ok "(pb8) push in flight AND an in-flight teammate row -> the TEAMMATES text, no deferral"
else
  bad "(pb8) with a push in flight, an in-flight teammate row was not answered with the TEAMMATES text (or a deferral row was written). It reads: $(printf '%s' "$rr" | head -c 120)"
fi
reset_state "$P_UNPUSHED"
# (pb9) COMMIT: the dirty and unpublished tree.
o="$(pbx_drive "$P_DIRTY_UNPUSHED" "$T_PB_RUN")"
rr="$(reason "$o")"
if has "$rr" "$COMMIT_MARK" && ! grep -qF -- "-- $PB_DEF" "$(pbx_log "$P_DIRTY_UNPUSHED")"; then
  ok "(pb9) push in flight AND uncommitted work -> the COMMIT text, no deferral"
else
  bad "(pb9) with a push in flight, an uncommitted tree was not answered with the COMMIT text (or a deferral row was written). It reads: $(printf '%s' "$rr" | head -c 120)"
fi

# =============================================================================
# ai-dlc-continue.sh — THE DRIVER-SIGNAL ARM (step 4) AND THE MARKER ARM (step 5)
# =============================================================================
# Measured on the reference consumer over the 39 handoffs its transcripts can score: step 4's
# `touch _bmad-output/.driver/handoff` skipped on 20, step 5's `rm -f .handoff-in-progress` on
# 4 of the 17 in scope. Neither had an arm. Every case drives the COMPLIANT transcript, so the
# resume arm is satisfied and the only thing that varies is one file under _bmad-output.
#
# (d1) THE PUSHED TREE WITH THE DRIVER SIGNAL REMOVED. Same tree as (d), which is the ALLOW
#      control beside it: steps 1, 3 and the resume line are all recorded, and the only
#      difference is the touch.
reset_state "$P_PUSHED"
rm -f "$P_PUSHED/_bmad-output/.driver/handoff"
rr="$(reason "$(drive "$P_PUSHED" "$SESS_A" "$T_REQ_OK")")"
if [ -z "$rr" ]; then
  bad "(d1) pushed tree, resume block present, driver signal ABSENT -> was ALLOWED — a handoff that skipped step 4's touch ends the session and an attached driver never learns of it"
elif ! has "$rr" "$DRIVER_MARK"; then
  bad "(d1) blocked, but the reason does not name step 4's touch. It reads: $(printf '%s' "$rr" | head -c 120)"
elif has "$rr" "$PUSH_MARK" || has "$rr" "$TEAM_MARK" || has "$rr" "$RESUME_MARK" || has "$rr" "$MARKER_MARK"; then
  bad "(d1) the reason names step 4's touch AND another step — the dispatch is not exclusive"
else
  ok "(d1) pushed tree, resume block present, driver signal ABSENT -> BLOCK, and the reason is the STEP 4 touch text alone"
  B_d1=1
fi
reset_state "$P_PUSHED"
r="$(verdict "$(drive "$P_PUSHED" "$SESS_A" "$T_REQ_OK")")"
[ "$r" = allow ] && ok "  control: the same tree with the driver signal present -> ALLOW (the arm accepts the state it demands)" \
                 || bad "  the same tree BLOCKED with the signal present ($r) — the arm fires on compliance with step 4"

# (d2) THE MARKER STILL ON DISK AFTER EVERYTHING ELSE. The non-git tree, so the push arm is
#      out of scope; the marker is produced by the REAL entry hook (mkmarker), never touched
#      here. The transcript is the compliant one, so the marker is also key 1 -- which is fine:
#      the key arms the guard and the arm asserts the same file is gone by the end.
reset_state "$P_DISK"
mkmarker "$P_DISK"
marker_at "$P_DISK" || broken "(d2) mkmarker did not produce the entry marker in $P_DISK — the marker arm has no subject"
rr="$(reason "$(drive "$P_DISK" "$SESS_A" "$T_REQ_OK")")"
if [ -z "$rr" ]; then
  bad "(d2) resume block present, driver signal present, entry marker STILL PRESENT -> was ALLOWED — the next compaction will route this session back into handoff.md"
elif ! has "$rr" "$MARKER_MARK"; then
  bad "(d2) blocked, but the reason does not name step 5's marker. It reads: $(printf '%s' "$rr" | head -c 120)"
elif has "$rr" "$PUSH_MARK" || has "$rr" "$TEAM_MARK" || has "$rr" "$RESUME_MARK" || has "$rr" "$DRIVER_MARK"; then
  bad "(d2) the reason names step 5's marker AND another step — the dispatch is not exclusive"
else
  ok "(d2) everything recorded but the entry marker still present -> BLOCK, and the reason is the STEP 5 text alone"
  B_d2=1
fi
reset_state "$P_DISK"
r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_REQ_OK")")"
[ "$r" = allow ] && ok "  control: the same tree with the marker cleared -> ALLOW" \
                 || bad "  the same tree BLOCKED with the marker cleared ($r) — the marker arm fires on compliance with step 5"

# (d4) THE STALE SIGNAL. The reference consumer's tree: `.driver/handoff` left by a previous
#      handoff, no driver attached to consume it, and THIS handoff finalized its snapshot after
#      that touch. A presence test passes here forever; the arm keys on the snapshot's mtime as
#      the step-3 reference and must BLOCK. `touch -t` back-dates the signal rather than sleeping
#      for a clock tick, so the ordering is by construction and not by timing.
reset_state "$P_PUSHED"
touch -t 202001010000 "$P_PUSHED/_bmad-output/.driver/handoff"
printf '# Pipeline Snapshot\n\n## Pipeline Position\ncurrent_step_file: implementation.md\n\n## In-Flight Teammates\n\n' > "$P_PUSHED/_bmad-output/pipeline-snapshot.md"
touch "$P_PUSHED/_bmad-output/pipeline-paused.flag"
[ "$P_PUSHED/_bmad-output/pipeline-snapshot.md" -nt "$P_PUSHED/_bmad-output/.driver/handoff" ] \
  || broken "(d4) the seed could not make the snapshot newer than the driver signal — the stale case is not constructible on this filesystem"
rr="$(reason "$(drive "$P_PUSHED" "$SESS_A" "$T_REQ_OK")")"
if [ -z "$rr" ]; then
  bad "(d4) a driver signal OLDER than this handoff's finalized snapshot was accepted as step 4 -> ALLOW — on a tree with no driver attached the previous handoff's marker satisfies the arm forever, and the most-skipped step is unguarded exactly where its skip rate was measured"
elif ! has "$rr" "$DRIVER_MARK"; then
  bad "(d4) blocked, but not on the driver arm. It reads: $(printf '%s' "$rr" | head -c 120)"
else
  ok "(d4) a driver signal OLDER than the finalized snapshot -> BLOCK on the step-4 arm (presence is not this turn's touch)"
  B_d4=1
fi
: > "$P_PUSHED/_bmad-output/.driver/handoff"
rm -f "$P_PUSHED/_bmad-output/handoff-guard-state.txt"
r="$(verdict "$(drive "$P_PUSHED" "$SESS_A" "$T_REQ_OK")")"
[ "$r" = allow ] && ok "  control: the same tree after a FRESH touch -> ALLOW (the arm accepts the state step 4 produces)" \
                 || bad "  the same tree BLOCKED after a fresh touch ($r) — the freshness test rejects a compliant step 4"
reset_state "$P_PUSHED"

# (d3) BOTH MISSING: step 4 is dispatched before step 5, in the procedure's order.
reset_state "$P_DISK"
mkmarker "$P_DISK"
rm -f "$P_DISK/_bmad-output/.driver/handoff"
rr="$(reason "$(drive "$P_DISK" "$SESS_A" "$T_REQ_OK")")"
{ has "$rr" "$DRIVER_MARK" && ! has "$rr" "$MARKER_MARK"; } \
  && ok "(d3) driver signal absent AND marker present -> the STEP 4 text, not step 5's (dispatched in procedure order)" \
  || bad "(d3) with both step 4 and step 5 unsatisfied the reason is not step 4's alone — the lead is told the later step first, or both. It reads: $(printf '%s' "$rr" | head -c 120)"

# (d5) STEP 5 BEFORE STEP 4 MUST NOT ESCAPE. The guard is armed by KEY 1 ALONE -- pause flag up,
#      entry marker produced by the real hook, no log row, no snapshot record, and a transcript
#      whose last user message is NOT a request (T_QUIET_OK, which still carries the resume block
#      so the resume arm is satisfied). It blocks on step 4. Then the lead clears the marker WITHOUT
#      touching the driver signal: key 1 is gone, no other key holds, and a guard armed only by
#      the predicate would not examine this Stop at all. The first armed Stop recorded the session,
#      so this one is armed by that record and must still BLOCK on step 4. Then the touch satisfies
#      it and the record is removed. One file per step, and (d3) is NOT reused here because (d3)
#      arms through the transcript, which would mask the very channel under test -- measured: the
#      first cut of this case did reuse it and passed against the mutant that disables the record.
ARMED="$P_DISK/_bmad-output/.handoff-guard-armed"
reset_state "$P_DISK"; touch "$P_DISK/_bmad-output/pipeline-paused.flag"
mkmarker "$P_DISK"; rm -f "$P_DISK/_bmad-output/.driver/handoff"
rr="$(reason "$(drive "$P_DISK" "$SESS_A" "$T_QUIET_OK")")"
has "$rr" "$DRIVER_MARK" || broken "(d5) the key-1-armed first Stop did not block on the driver arm (got: $(printf '%s' "$rr" | head -c 80)) — the sticky case cannot start"
[ -f "$ARMED" ] || broken "(d5) the armed Stop left no arming record at $ARMED — the sticky arm has no subject"
rm -f "$P_DISK/_bmad-output/.handoff-in-progress" "$P_DISK/_bmad-output/handoff-guard-state.txt"
rr="$(reason "$(drive "$P_DISK" "$SESS_A" "$T_QUIET_OK")")"
if [ -z "$rr" ]; then
  bad "(d5) marker cleared first, driver signal still untouched -> ALLOW — clearing the marker disarmed the guard, so step 5 before step 4 escapes both new arms"
elif has "$rr" "$DRIVER_MARK"; then
  ok "(d5) marker cleared first, driver signal still untouched -> still BLOCKS on step 4 (the earlier armed Stop keeps the guard armed for this session)"
  B_d5=1
else
  bad "(d5) blocked, but not on the driver arm. It reads: $(printf '%s' "$rr" | head -c 120)"
fi
grep -qF -- "armed by an earlier Stop" "$P_DISK/_bmad-output/pipeline-continuation-log.md" 2>/dev/null \
  && ok "  the block row says the guard was armed by an earlier Stop, not by a key — the record is attributable" \
  || bad "  the block row does not say how the guard was armed; a retro cannot tell a sticky arming from a live key"
: > "$P_DISK/_bmad-output/.driver/handoff"; rm -f "$P_DISK/_bmad-output/handoff-guard-state.txt"
r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_QUIET_OK")")"
[ "$r" = allow ] && ok "  control: the touch satisfies the guard -> ALLOW" \
                 || bad "  BLOCKED after the touch ($r) — the sticky arming does not release on a complete handoff"
[ -f "$ARMED" ] && bad "  the arming record survived a satisfied handoff — the NEXT paused Stop of this session would be examined for a handoff that is over" \
                || ok "  the arming record is removed on the satisfied path"
# A DIFFERENT session with the record on disk must not be armed by it, and must clear it.
reset_state "$P_DISK"; touch "$P_DISK/_bmad-output/pipeline-paused.flag"; printf '%s\n' "$SESS_A" > "$ARMED"
rm -f "$P_DISK/_bmad-output/.driver/handoff"
r="$(verdict "$(drive "$P_DISK" "$SESS_B" "$T_QUIET")")"
[ "$r" = allow ] && ok "  near-miss: another session's arming record does not arm THIS session -> ALLOW" \
                 || bad "  another session's arming record BLOCKED this one ($r) — the record is not session-bound and would wedge the successor at its first paused Stop"
[ -f "$ARMED" ] && bad "  a foreign arming record was left on disk — it will be re-read at every Stop" \
                || ok "  a foreign arming record is cleared"
# And the record must not survive the pause flag coming down (the handoff was abandoned).
reset_state "$P_DISK"; printf '%s\n' "$SESS_A" > "$ARMED"; rm -f "$P_DISK/_bmad-output/.driver/handoff"
r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_QUIET")")"
{ [ "$r" = allow ] && [ ! -f "$ARMED" ]; } \
  && ok "  near-miss: the pause flag DOWN clears the record and does not arm (an abandoned handoff does not haunt the session)" \
  || bad "  with the pause flag down the record armed the guard or survived ($r, record $([ -f "$ARMED" ] && echo present || echo absent)) — a lead that resumed after abandoning a handoff is blocked on it"

# =============================================================================
# ai-dlc-continue.sh — THE ON-DISK TRIGGER (the predicate, through the Stop caller)
# =============================================================================
# Every case below drives the SAME transcript -- one whose last user message is NOT a request
# -- against the SAME non-git tree, so the push arm is out of scope and the only thing that
# varies is the state under _bmad-output. A BLOCK here can only have come from the predicate.
#
# THE PAUSE FLAG IS PRESENT IN ALL OF THEM, because the predicate requires it. It is also what
# really happens: ai-dlc-pause.sh raised it the moment the operator typed. Check 0 runs BEFORE
# Check 1, so the flag does not itself produce the allow.
dsetup() { # dsetup [log-file|""] [marker: yes|no]
  reset_state "$P_DISK"
  touch "$P_DISK/_bmad-output/pipeline-paused.flag"
  [ -n "${1:-}" ] && cp "$1" "$P_DISK/_bmad-output/pipeline-continuation-log.md"
  [ "${2:-no}" = yes ] && mkmarker "$P_DISK" "${3:-$HOOKS_DIR}"
  return 0
}
disk() { # disk <session> [hooksdir] -> verdict
  verdict "$(drive "$P_DISK" "$1" "$T_QUIET" "${2:-$HOOKS_DIR}")"
}
disk_log() { printf '%s' "$P_DISK/_bmad-output/pipeline-continuation-log.md"; }

# (f) PAUSED, BUT NO KEY AT ALL. The hook seeds its own legend header into an absent log, and
#     that legend NAMES every event type and uses the words "handoff intent" in prose -- so
#     this is also the control that key 3 is anchored on a `## <ts> -- USER_PAUSE` heading and
#     not on a substring of the machinery's own documentation.
dsetup
r="$(disk "$SESS_A")"
[ "$r" = allow ] && ok "(f) pause flag but NO key -> ALLOW (the pause flag alone is never a pending handoff)" \
                 || bad "(f) the guard fired with no handoff record on disk ($r) — the flag alone is being read as a key, and every paused turn in a sprint would block"
dsetup
r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_REQ_NOBLK")")"
[ "$r" = block ] && ok "  control: the same tree BLOCKS a transcript-visible request with no resume block — the hook runs here" \
                 || bad "  the on-disk tree did not block a transcript-visible request either ($r) — every ALLOW in this section is unreadable"

# KEY 1 THROUGH THIS CALLER. The recover battery owns the key-1 mutant; this arm exists
# because the two callers pass different state dirs and different session sources, and a
# defect in either is invisible to a fixture that only drives the other.
dsetup "" yes
r="$(disk "$SESS_A")"
[ "$r" = block ] && ok "(f2) key 1, the entry marker, reaches the Stop caller too -> BLOCK" \
                 || bad "(f2) the entry marker did not block at the Stop seam ($r) — ai-dlc-recover.sh and ai-dlc-continue.sh are answering the same question differently, which is the drift the shared predicate exists to prevent"
_kl="$(disk_log)"
if grep -qF -- "via entry-marker" "$_kl" 2>/dev/null; then
  ok "  the HANDOFF_GUARD_BLOCK row names WHICH key fired (entry-marker) — retro's investigation channel is populated"
else
  bad "  the block row does not name the key that fired; a retro reading these counts cannot tell a queued message from a lead mid-procedure"
fi

# (g) A handoff request recorded against THIS session.
log_prompt "$LG" "$SESS_A" "$P_INTENT"
dsetup "$LG"
r="$(disk "$SESS_A")"
[ "$r" = block ] && ok "(g) key 3, a USER_PAUSE row carrying handoff intent, SAME session -> BLOCK" \
                 || bad "(g) a handoff recorded on disk for THIS session was ALLOWED ($r) — this is the queued-message episode, and the guard is silent for exactly the reason the predicate was written"
if grep -qF -- "via log-request" "$(disk_log)" 2>/dev/null; then
  ok "  and the row names key 3 (log-request), not key 1 — the two keys are distinguishable in the record"
else
  bad "  the block row does not name log-request; the key attribution is wrong or missing and a retro cannot tell which channel saw the request"
fi

# (g2) THE SAME REQUEST AS THE BARE WORD, which is what the operator actually typed. It can
#      only match through the ANCHORED `^ *hand[ -]?off *$` alternative, and that alternative
#      cannot match a line still carrying its `- Prompt (first 120 chars): ` prefix. So this
#      case, and only this case, distinguishes a pattern applied to the extracted field VALUE
#      from one applied to the whole log LINE -- a line-wise grep reads a real request as a
#      non-instance and returns a clean, plausible zero.
log_prompt "$LG" "$SESS_A" "$P_BARE"
dsetup "$LG"
r="$(disk "$SESS_A")"
if [ "$r" = block ]; then
  ok "(g2) the bare word '$P_BARE' as the field VALUE -> BLOCK (the pattern is applied to the value, not the line)"; B_g2=1
else
  bad "(g2) the bare word '$P_BARE' was ALLOWED ($r) — the intent pattern is being applied to the whole log line, where its anchored alternative can never match"
fi

# (g3) KEY 3 IS SCORED PER ROW, AND THIS IS THE EPISODE'S OWN LOG SHAPE. The session was
#      started by `/ai-dlc resume`, which ai-dlc-pause.sh records as its first row, and the
#      operator typed `handoff` hours later. With the exclusion applied to the session's prose
#      JOINED, `/ai-dlc` in row one vetoed the request in row two and the guard allowed the
#      stop -- the incident PC-S308-HANDOFF-PROCEDURE-5-STEP-NOT-FOLLOWED was filed from. Per
#      row, the request stands on its own. Killed by mutant M20 and by nothing else.
log_two_row "$LG" "$SESS_A" "$P_RESUME" "$P_BARE"
dsetup "$LG"
r="$(disk "$SESS_A")"
if [ "$r" = block ]; then
  ok "(g3) key 3: a '$P_RESUME' row FOLLOWED by a '$P_BARE' row, same session -> BLOCK (the exclusion vetoes its own row, not the session)"; B_g3=1
else
  bad "(g3) the request was ALLOWED ($r) — the mention exclusion is being applied to the whole session's prose, so every session started by the slash command has key 3 disarmed for its whole life; this is the filed incident exactly"
fi
log_two_row "$LG" "$SESS_A" "$P_RESUME" "$P_NOINTENT"
dsetup "$LG"
r="$(disk "$SESS_A")"
[ "$r" = allow ] && ok "  near-miss: the same first row followed by a NON-request -> ALLOW (per-row scoring did not widen the key)" \
                 || bad "  a resumed session with no request BLOCKED ($r) — per-row scoring is reading the slash command itself as a request"

# (g4) THE TERSE REQUEST AS THE FINAL SENTENCE OF A LONGER MESSAGE, which is what the operator
#      typed in PC-S308-HANDOFF-INTENT-PATTERN-MISSES-TRAILING-TERSE-PHRASING; the row is the
#      reference consumer's own, verbatim. The standalone alternative is anchored to the whole
#      field and cannot see it; the final-sentence alternative can. Driven on a copy of the
#      consumer's real log for the incident session: shipped declaration rc=1, repaired rc=0,
#      and no other session in that log moves. Killed by mutant M25, which removes that
#      alternative from a COPY of the declaration.
log_prompt "$LG" "$SESS_A" "$P_TERSE"
dsetup "$LG"
r="$(disk "$SESS_A")"
if [ "$r" = block ]; then
  ok "(g4) key 3: '$P_TERSE' -> BLOCK (a terse request trailing unrelated context is a request)"; B_g4=1
else
  bad "(g4) the trailing terse request was ALLOWED ($r) — the incident PC-S308-HANDOFF-INTENT-PATTERN-MISSES-TRAILING-TERSE-PHRASING exactly: the lead improvises the procedure and no Stop is examined"
fi
log_prompt "$LG" "$SESS_A" "$P_TERSE_NEAR"
dsetup "$LG"
r="$(disk "$SESS_A")"
[ "$r" = allow ] && ok "  near-miss: '$P_TERSE_NEAR', the word trailing a VERB with no sentence boundary before it -> ALLOW (the alternative anchors the sentence, not the word)" \
                 || bad "  a denial that merely ENDS in the word BLOCKED ($r) — the alternative has widened to any trailing 'handoff', which on the reference consumer's history admits five questions or denials"
log_prompt "$LG" "$SESS_A" "$P_TERSE_NEAR2"
dsetup "$LG"
r="$(disk "$SESS_A")"
[ "$r" = allow ] && ok "  near-miss: the PUNCTUATED denial, the word after a verb and before a period -> ALLOW (the boundary is before the word, not after it)" \
                 || bad "  an operator saying a handoff was NOT wanted BLOCKED ($r) — the alternative has widened to a trailing word plus period, which admits four denials or questions on the consumer's history"
log_prompt "$LG" "$SESS_A" "$P_NOUN"
dsetup "$LG"
r="$(disk "$SESS_A")"
[ "$r" = allow ] && ok "  near-miss: a plain noun mention '$P_NOUN' -> ALLOW" \
                 || bad "  a plain noun mention BLOCKED ($r) — the declaration matches the noun its own description says it does not"
# AND THROUGH THE TRANSCRIPT CHANNEL, the other reader of the same declaration at this seam.
# The same message as the LAST user turn, no resume block, no log row: a BLOCK here can only
# be Check 0's transcript arm reading the declaration. Both readers resolve one jq line, so
# the two cells must agree -- and M25 moves both, which is that single-source claim measured.
T_TERSE_NOBLK="$ROOT/t_terse_noblk.jsonl"
jq -nc --arg u "$P_TERSE" '{message:{role:"user",content:$u}}' > "$T_TERSE_NOBLK"
jq -nc --arg a "Done. Everything is committed and the snapshot is updated." '{message:{role:"assistant",content:$a}}' >> "$T_TERSE_NOBLK"
T_NEAR_NOBLK="$ROOT/t_near_noblk.jsonl"
jq -nc --arg u "$P_TERSE_NEAR" '{message:{role:"user",content:$u}}' > "$T_NEAR_NOBLK"
jq -nc --arg a "Done. Everything is committed and the snapshot is updated." '{message:{role:"assistant",content:$a}}' >> "$T_NEAR_NOBLK"
dsetup
r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_TERSE_NOBLK")")"
[ "$r" = block ] && ok "  and as the transcript's last user message with no resume block -> BLOCK (the transcript reader sees the same declaration)" \
                 || bad "  the same message as the transcript's last user turn was ALLOWED ($r) — the two readers of one declaration disagree"
dsetup
r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_NEAR_NOBLK")")"
[ "$r" = allow ] && ok "  near-miss through the transcript: the denial -> ALLOW" \
                 || bad "  the denial BLOCKED through the transcript ($r) — the transcript reader has widened where the on-disk reader has not, or both have"

# (g5) A MULTI-LINE MESSAGE IS ONE FIELD, NOT A SET OF LINES. The declared patterns anchor on
#      `^` and `$`, and grep anchors per LINE, so a message whose MIDDLE line ends in the terse
#      form -- an operator pasting the incident's own row into a question -- matched on that
#      line alone and routed the whole message. ai-dlc-pause.sh collapses newlines before it
#      writes the row key 3 reads; the transcript reader now collapses the same way. The
#      sibling BLOCK is the same message with the terse form on its LAST line, which is a
#      request whether or not it is collapsed. Killed by mutant M26.
P_PASTED="$(printf 'Look at this filing:\nRepro row: %s\nIs the fix right?' "$P_TERSE")"
P_LASTLINE="$(printf 'Everything is committed.\n%s' "$P_TERSE")"
T_PASTED_NOBLK="$ROOT/t_pasted_noblk.jsonl"
jq -nc --arg u "$P_PASTED" '{message:{role:"user",content:$u}}' > "$T_PASTED_NOBLK"
jq -nc --arg a "Done. Everything is committed and the snapshot is updated." '{message:{role:"assistant",content:$a}}' >> "$T_PASTED_NOBLK"
T_LASTLINE_NOBLK="$ROOT/t_lastline_noblk.jsonl"
jq -nc --arg u "$P_LASTLINE" '{message:{role:"user",content:$u}}' > "$T_LASTLINE_NOBLK"
jq -nc --arg a "Done. Everything is committed and the snapshot is updated." '{message:{role:"assistant",content:$a}}' >> "$T_LASTLINE_NOBLK"
[ "$(printf '%s' "$P_PASTED" | wc -l | tr -d ' ')" = "2" ] || broken "seed premise dead: the pasted-filing seed is not three lines, so (g5) cannot tell a per-line reader from a per-field one"
dsetup
r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_PASTED_NOBLK")")"
if [ "$r" = allow ]; then
  ok "(g5) a three-line message whose MIDDLE line ends in the terse form -> ALLOW (the transcript is one field, not a set of lines)"; B_g5=1
else
  bad "(g5) a pasted filing quoting the incident row BLOCKED ($r) — the transcript reader matches per line, so any message that quotes a request on its own line arms the guard"
fi
dsetup
r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_LASTLINE_NOBLK")")"
[ "$r" = block ] && ok "  control: the same shape with the terse form on the LAST line -> BLOCK (collapsing did not disarm the final-sentence alternative)" \
                 || bad "  a two-line message ending in the terse request was ALLOWED ($r) — the collapse broke the final-sentence alternative, or the transcript reader is dead and (g5) is unreadable"

# (h) THE SESSION BOUND IS THE DISCHARGE. The log is rotated per sprint, so "any handoff row"
#     would stay true for every later session in the sprint and would block ordinary work at
#     its first Stop. Same tree, same log bytes, only the driving session id differs.
log_prompt "$LG" "$SESS_A" "$P_INTENT"
dsetup "$LG"
r="$(disk "$SESS_B")"
[ "$r" = allow ] && ok "(h) the same row read by a DIFFERENT session -> ALLOW (the session bound discharges the row)" \
                 || bad "(h) a handoff recorded for another session BLOCKED this one ($r) — the row never expires and every session for the rest of the sprint wedges at its first Stop"
dsetup "$LG"
r="$(disk "$SESS_A")"
[ "$r" = block ] && ok "  control: the identical row read by ITS OWN session still BLOCKS — the ALLOW above is the session bound, not a dead reader" \
                 || bad "  the identical row did not block its own session either ($r) — (h) proves nothing"

# (i) MECHANISM DISCUSSION IS NOT A REQUEST. The prose matches the intent pattern AND the
#     mention exclusion; the exclusion is a veto, and without it the guard fires on someone
#     asking why it fired.
log_prompt "$LG" "$SESS_A" "$P_DISCUSS"
dsetup "$LG"
r="$(disk "$SESS_A")"
if [ "$r" = allow ]; then
  ok "(i) prose that DISCUSSES the guard while quoting the request -> ALLOW (the exclusion pattern vetoes it)"; B_i=1
else
  bad "(i) a question ABOUT the handoff guard BLOCKED ($r) — the exclusion conjunct is not being applied, and the guard now fires on its own subject"
fi
log_prompt "$LG" "$SESS_A" "$P_INTENT"
dsetup "$LG"
r="$(disk "$SESS_A")"
[ "$r" = block ] && ok "  control: the request WITHOUT the mechanism words, same tree and same session, still BLOCKS — (i) is the exclusion firing, not the reader failing" \
                 || bad "  the plain request did not block either ($r) — (i) proves nothing"

# (j) THE LEAD MUST NOT ROUTE ITS OWN GUARD. `- Question` is lead-authored and
#     ai-dlc-answer-capture.sh labels it "NOT the intent signal" in the row itself. The pair
#     below is the same row shape with the handoff words moved between the two fields.
log_answer "$LG" "$SESS_A" "$Q_INTENT" "$P_NOINTENT"
dsetup "$LG"
r="$(disk "$SESS_A")"
if [ "$r" = allow ]; then
  ok "(j) handoff words in the lead-authored '- Question' line only -> ALLOW (the lead cannot route its own guard)"; B_j=1
else
  bad "(j) the lead-authored question BLOCKED ($r) — a lead can now trigger the handoff guard by phrasing its own AskUserQuestion, and the operator's answer is not what is read"
fi
log_answer "$LG" "$SESS_A" "$Q_NOINTENT" "$P_INTENT"
dsetup "$LG"
r="$(disk "$SESS_A")"
[ "$r" = block ] && ok "  control: the same row with the handoff words in the OPERATOR's '- Answer' field BLOCKS — (j) is the field bound, not a dead reader" \
                 || bad "  the operator's answer field did not block either ($r) — (j) proves nothing, and the AskUserQuestion channel is unguarded"

# =============================================================================
# ai-dlc-continue.sh — THE ON-DISK KEYS WITH NO TRANSCRIPT
# =============================================================================
# THE SUBJECT. The guard's entry test required a readable transcript, so a Stop whose
# transcript path names no file skipped every arm -- including the on-disk trigger built for
# the request the transcript cannot see. The keys now enter on their own.
#
# THE ARM THAT MATTERS IS (nt3), THE ALL-SATISFIED ALLOW. With no transcript the resume arm
# has nothing to parse; computed anyway it reads 0, and every transcript-less Stop with a key
# would block for "no resume block" -- a verdict drawn from an input never read. It must read
# 1 = unknown, so only the disk-and-git arms convict here. (nt1)/(nt2) prove those still do.
#
# THE TRANSCRIPT PATH IS ASSERTED ABSENT IN THE SAME INVOCATION. A path that happened to exist
# would be the transcript-present case wearing this battery's label.
# HC is defined HERE, before its first reader. Defined below it, `[ ! -f "$(HC …)" ]` tests
# the empty path and passes whatever the hook wrote.
HC() { printf '%s' "$1/_bmad-output/.handoff-complete"; }
T_NONE="$ROOT/no-such-transcript.jsonl"
NT_ANN="[no transcript:"
ntdisk() { verdict "$(drive "$P_DISK" "$SESS_A" "$T_NONE" "${1:-$HOOKS_DIR}")"; }
if [ ! -e "$T_NONE" ] && [ -f "$T_QUIET" ]; then
  ok "(nt0) the no-transcript path names nothing, and the transcript control beside it exists"
else
  broken "the no-transcript seed path exists (or the transcript control does not) — every (nt) verdict below would be about the wrong input"
fi

# (nt1) key 3 + step 4 skipped, no transcript -> BLOCK on the driver arm, and the row says the
#       transcript was not read.
log_prompt "$LG" "$SESS_A" "$P_INTENT"
dsetup "$LG"; rm -f "$P_DISK/_bmad-output/.driver/handoff"
rr="$(reason "$(drive "$P_DISK" "$SESS_A" "$T_NONE")")"
if has "$rr" "$DRIVER_MARK"; then
  ok "(nt1) key 3, NO transcript, driver signal absent -> BLOCK with the step-4 text (the on-disk key enters the guard on its own)"; B_nt1=1
else
  bad "(nt1) a handoff recorded on disk with no transcript did not block on step 4 ($([ -n "$rr" ] && echo "different text" || echo "allowed")) — the guard still requires a transcript to run any arm"
fi
grep -qF -- "$NT_ANN" "$(disk_log)" 2>/dev/null \
  && ok "  the HANDOFF_GUARD_BLOCK row records that the transcript was not read" \
  || bad "  the block row does not say the transcript was absent — a retro reads the resume clause of the block text as checked"

# (nt2) key 1, the entry marker, no transcript -> BLOCK on the marker arm.
dsetup "" yes
rr="$(reason "$(drive "$P_DISK" "$SESS_A" "$T_NONE")")"
if has "$rr" "$MARKER_MARK"; then
  ok "(nt2) key 1, NO transcript -> BLOCK with the step-5 text"; B_nt2=1
else
  bad "(nt2) the entry marker with no transcript did not block on step 5 ($([ -n "$rr" ] && echo "different text" || echo "allowed"))"
fi

# (nt3) key 3, every disk arm satisfied, no transcript -> ALLOW, and NO completion stamp: the
#       resume arm was not read, so the completion is not verified and key 2 must not discharge.
log_prompt "$LG" "$SESS_A" "$P_INTENT"
dsetup "$LG"
r="$(ntdisk)"
if [ "$r" = allow ]; then
  ok "(nt3) key 3, NO transcript, every disk arm satisfied -> ALLOW (the unread resume arm reads unknown, not missing)"; B_nt3=1
else
  bad "(nt3) BLOCKED with no transcript and every disk arm satisfied ($r) — the resume arm is convicting from a transcript it never read"
fi
if [ ! -f "$(HC "$P_DISK")" ]; then
  ok "  and writes NO completion stamp (an unverified resume does not discharge key 2)"; B_nt3s=1
else
  bad "  the no-transcript ALLOW wrote .handoff-complete — key 2 is discharged on a completion nobody verified"
fi
# CONTROL: the same tree with a compliant transcript allows AND stamps, so the absence above
# is the transcript condition and not a writer that never runs.
log_prompt "$LG" "$SESS_A" "$P_INTENT"
dsetup "$LG"
r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_QUIET_OK")")"
{ [ "$r" = allow ] && [ -f "$(HC "$P_DISK")" ]; } \
  && ok "  control: the same tree WITH a compliant transcript allows and stamps" \
  || bad "  the transcript-present control did not allow-and-stamp ($r, stamp $([ -f "$(HC "$P_DISK")" ] && echo present || echo absent)) — (nt3)'s stamp absence is unreadable"
# CONTROL: the transcript arms still convict when the transcript IS readable -- T_QUIET carries
# no resume block, so it blocks on the resume text, and its row does NOT carry the annotation.
log_prompt "$LG" "$SESS_A" "$P_INTENT"
dsetup "$LG"
rr="$(reason "$(drive "$P_DISK" "$SESS_A" "$T_QUIET")")"
{ has "$rr" "$RESUME_MARK" && ! grep -qF -- "$NT_ANN" "$(disk_log)" 2>/dev/null; } \
  && ok "  control: the same key WITH a transcript lacking the resume block still BLOCKS on the resume text, unannotated" \
  || bad "  the transcript-present resume case did not block on the resume text, or carried the no-transcript annotation — the unknown reading has leaked into the transcript path"

# (nt4) NEAR-MISS: the pause flag, NO key, NO transcript -> ALLOW, and nothing armed. The
#       driver signal is REMOVED so a hook that entered on the flag alone would BLOCK on step 4;
#       with it present every disk arm is satisfied and the ALLOW would discriminate nothing.
dsetup; rm -f "$P_DISK/_bmad-output/.driver/handoff"
r="$(ntdisk)"
{ [ "$r" = allow ] && [ ! -f "$ARMED" ]; } \
  && ok "(nt4) pause flag, no key, no transcript -> ALLOW, and no arming record (the flag alone never enters the guard)" \
  || bad "(nt4) flag with no key and no transcript produced $r (record $([ -f "$ARMED" ] && echo present || echo absent)) — the hoist admits a Stop with nothing pending"

# (nt5) THE STICKY RECORD ENTERS TOO. Key 1 cleared before step 4's touch leaves no key; the
#       record an earlier Stop of this session wrote is what arms the guard, transcript or not.
dsetup; printf '%s\n' "$SESS_A" > "$ARMED"; rm -f "$P_DISK/_bmad-output/.driver/handoff"
rr="$(reason "$(drive "$P_DISK" "$SESS_A" "$T_NONE")")"
if has "$rr" "$DRIVER_MARK"; then
  ok "(nt5) sticky record for THIS session, no key, no transcript -> BLOCK with the step-4 text"; B_nt5=1
else
  bad "(nt5) the sticky record did not arm a transcript-less Stop ($([ -n "$rr" ] && echo "different text" || echo "allowed")) — clearing key 1 early escapes the guard whenever the transcript is absent"
fi
dsetup

# (nt6) AN UNREAD RESUME ARM DOES NOT DISCHARGE THE STICKY RECORD. Two Stops of one session.
#       The first has no transcript and every disk arm satisfied, so it ALLOWS with the resume
#       arm read as unknown -- and must leave the record on disk, because the one arm it could
#       not read is still owed. The second has a transcript with no resume block and no key;
#       only the record arms it, so it must BLOCK on the resume text. A hook that removes the
#       record on the unverified ALLOW lets the second Stop end the session.
dsetup; printf '%s\n' "$SESS_A" > "$ARMED"
r="$(ntdisk)"
if { [ "$r" = allow ] && [ -f "$ARMED" ]; }; then
  ok "(nt6) sticky record, every disk arm satisfied, NO transcript -> ALLOW with the record still on disk"; B_nt6=1
else
  bad "(nt6) the transcript-less satisfied Stop produced $r with the record $([ -f "$ARMED" ] && echo present || echo absent) — an unread resume arm discharged the arming"
fi
rr="$(reason "$(drive "$P_DISK" "$SESS_A" "$T_QUIET")")"
has "$rr" "$RESUME_MARK" && ok "  then a Stop WITH a transcript lacking the resume block -> BLOCK on the resume text (the record carried the arming across)" \
                         || bad "  the second Stop, transcript present and no resume block, $([ -n "$rr" ] && echo "blocked on different text" || echo "was ALLOWED") — the handoff escaped its resume check"
dsetup

# =============================================================================
# ai-dlc-continue.sh — A DAMAGED OR UNREADABLE TRANSCRIPT, AND NO jq (BL-700)
# =============================================================================
# THE SUBJECT. A requested handoff on an unpublished branch was ALLOWED with no HANDOFF_GUARD row
# in four cases: the transcript's last line truncated mid-write, a non-JSON line mid-file, a
# transcript path naming no file, and no jq on PATH. Three answers, keyed by what is recoverable:
# a damaged transcript is READ line-wise and gets the NORMAL guard text (fc1, fc2); with no
# transcript the fresh driver signal ENTERS Check 0, which decides from disk and git (fc3, and its
# completed-handoff control fc3b); with no jq the guard FAILS CLOSED with one constant block and a
# HANDOFF_GUARD_FAIL_CLOSED row (fc4). The seed is the receipt's: the unpublished tree, the pause flag up, and step 4's
# driver signal the only handoff signal on disk. Two controls bound the fail-closed path: no
# signal on disk ALLOWS (fc5), and a READABLE transcript keeps the existing decision (fc6). (fc7)
# is the bound that keeps a stale signal on a no-jq box from wedging a session.
FC_ROW="HANDOFF_GUARD_FAIL_CLOSED"
FC_MARK="HANDOFF GUARD (fail-closed)"
FC_U='{"type":"user","message":{"role":"user","content":"hand off the sprint"}}'
FC_A='{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"Snapshot finalized."}]}}'
T_FC_OK="$ROOT/fc-ok.jsonl"; T_FC_TRUNC="$ROOT/fc-trunc.jsonl"; T_FC_GARB="$ROOT/fc-garbage.jsonl"
T_FC_QUIET="$ROOT/fc-quiet.jsonl"; T_FC_NONE="$ROOT/fc-no-such-transcript.jsonl"
printf '%s\n%s\n' "$FC_U" "$FC_A" > "$T_FC_OK"
printf '%s\n%s\n' "$FC_U" "${FC_A:0:40}" > "$T_FC_TRUNC"
printf '%s\n%s\n%s\n' "$FC_U" '{"broken":' "$FC_A" > "$T_FC_GARB"
printf '%s\n%s\n' '{"type":"user","message":{"role":"user","content":"did the full handoff steps run"}}' "$FC_A" > "$T_FC_QUIET"
# A PATH with every /bin and /usr/bin tool EXCEPT jq, plus git -- the receipt's construction, and
# its assertion that the shim really lacks jq and really carries the tools the hook calls.
FC_NJ="$ROOT/fc-nojq"; mkdir -p "$FC_NJ"
for _d in /bin /usr/bin; do for _t in "$_d"/*; do _b="${_t##*/}"; [ "$_b" = jq ] && continue; [ -e "$FC_NJ/$_b" ] || ln -s "$_t" "$FC_NJ/$_b" 2>/dev/null; done; done
ln -sf "$(command -v git)" "$FC_NJ/git" 2>/dev/null
_fc0=""
[ ! -e "$FC_NJ/jq" ]                          || _fc0="$_fc0 shim-has-jq-file"
[ -z "$(PATH="$FC_NJ"; command -v jq)" ]      || _fc0="$_fc0 shim-resolves-jq"
[ -n "$(PATH="$FC_NJ"; command -v git)" ]     || _fc0="$_fc0 shim-lacks-git"
[ -n "$(PATH="$FC_NJ"; command -v sed)" ]     || _fc0="$_fc0 shim-lacks-sed"
[ ! -e "$T_FC_NONE" ]                         || _fc0="$_fc0 absent-transcript-exists"
[ -f "$T_FC_OK" ]                             || _fc0="$_fc0 ok-transcript-missing"
[ -z "$_fc0" ] \
  || broken "(fc0) premise failed:${_fc0} — no (fc) verdict would be about its label"
ok "(fc0) premise: the no-jq PATH has no jq and has git and sed; the absent transcript names nothing"
fc_drive() { # fc_drive <transcript> [PATH] [hooksdir] -> raw stdout; P_UNPUSHED, pause flag up, driver signal on disk
  reset_state "$P_UNPUSHED"; touch "$P_UNPUSHED/_bmad-output/pipeline-paused.flag"
  jq -nc --arg t "$1" --arg s "$SESS_A" '{transcript_path:$t,session_id:$s}' \
  | PATH="${2:-$PATH}" CLAUDE_PROJECT_DIR="$P_UNPUSHED" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" \
    bash "${3:-$HOOKS_DIR}/ai-dlc-continue.sh" 2>/dev/null
}
fc_log() { printf '%s' "$P_UNPUSHED/_bmad-output/pipeline-continuation-log.md"; }
fc_isblock() { grep -q '"decision" *: *"block"' <<<"$1" && grep -qF 'HANDOFF GUARD' <<<"$1"; }
# CONTROL for (fc1)-(fc4): the well-formed transcript blocks on the PUSH text, so the seed is live.
o="$(fc_drive "$T_FC_OK")"
{ has "$(reason "$o")" "$PUSH_MARK" && ! has "$o" "$FC_MARK"; } \
  || broken "(fc) premise: the well-formed transcript on the unpublished tree did not block on the PUSH text — none of the four cases below is readable"
ok "  control: the well-formed transcript blocks on step 3's PUSH text"

# (fc1)/(fc2) READABLE AFTER ALL: the damaged line is dropped, the request is read, and the Stop
# gets the NORMAL guard text -- never the fail-closed one, which would mean the read was given up.
for _fc in "fc1|$T_FC_TRUNC|the last line truncated mid-write" "fc2|$T_FC_GARB|a non-JSON line mid-file"; do
  _id="${_fc%%|*}"; _r="${_fc#*|}"; _t="${_r%%|*}"; _l="${_r#*|}"
  o="$(fc_drive "$_t")"
  if has "$(reason "$o")" "$PUSH_MARK" && ! has "$o" "$FC_MARK" && ! grep -qF -- "-- $FC_ROW" "$(fc_log)"; then
    ok "($_id) $_l -> the request is still read: BLOCK on the normal step-3 PUSH text, no fail-closed row"
  else
    bad "($_id) $_l was not answered with the normal PUSH text ($(fc_isblock "$o" && echo "a different block" || echo "ALLOWED")) — the reader gives up on a damaged transcript"
  fi
done

# (fc3) NO TRANSCRIPT, jq PRESENT: the fresh driver signal ENTERS Check 0, whose disk and git arms
#       decide. The unpublished branch is answered with the NORMAL step-3 PUSH text and a
#       HANDOFF_GUARD_BLOCK row naming the driver-signal arming -- never the fail-closed block.
o="$(fc_drive "$T_FC_NONE")"
if has "$(reason "$o")" "$PUSH_MARK" && ! has "$o" "$FC_MARK" && ! grep -qF -- "-- $FC_ROW" "$(fc_log)" \
   && grep -qF -- "-- HANDOFF_GUARD_BLOCK (1/" "$(fc_log)" && grep -qF -- "armed by step 4's driver signal with no transcript" "$(fc_log)"; then
  ok "(fc3) the transcript path names no file -> Check 0 decides from disk and git: the normal PUSH text and a HANDOFF_GUARD_BLOCK row naming the driver-signal arming"
else
  bad "(fc3) with no transcript and a fresh driver signal the unpublished branch was not answered by Check 0's PUSH text with its row ($(fc_isblock "$o" && echo "a different block" || echo "ALLOWED")) — the driver signal does not enter the guard"
fi
# (fc3b) THE FALSE POSITIVE THAT ENTRY MUST NOT CREATE: the same Stop on a COMPLETED handoff (the
#        pushed, clean tree, driver signal fresh, no transcript) ALLOWS with no block row. With no
#        transcript the resume arm reads unknown and the In-Flight arm has no dispatch set, so only
#        the disk and git arms convict, and all of them are satisfied here.
reset_state "$P_PUSHED"; touch "$P_PUSHED/_bmad-output/pipeline-paused.flag"
o="$(jq -nc --arg t "$T_FC_NONE" --arg s "$SESS_A" '{transcript_path:$t,session_id:$s}' \
     | CLAUDE_PROJECT_DIR="$P_PUSHED" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" bash "$HOOKS_DIR/ai-dlc-continue.sh" 2>/dev/null)"
if ! fc_isblock "$o" && ! grep -qF -- "-- HANDOFF_GUARD" "$P_PUSHED/_bmad-output/pipeline-continuation-log.md" 2>/dev/null; then
  ok "(fc3b) a COMPLETED handoff, no transcript, driver signal fresh -> ALLOW with no HANDOFF_GUARD row (the entry costs a finished handoff nothing)"
else
  bad "(fc3b) a completed handoff with no transcript was BLOCKED or logged a guard row — the driver-signal entry convicts a finished handoff"
fi
reset_state "$P_PUSHED"

# (fc4) NO jq: nothing can be read, so one constant block that parses, and a FAIL_CLOSED row.
for _fc in "fc4|$T_FC_OK|$FC_NJ|no jq on PATH|jq is not on PATH"; do
  _id="${_fc%%|*}"; _r="${_fc#*|}"; _t="${_r%%|*}"; _r="${_r#*|}"; _p="${_r%%|*}"; _r="${_r#*|}"; _l="${_r%%|*}"; _w="${_r#*|}"
  o="$(fc_drive "$_t" "${_p:-$PATH}")"
  if ! fc_isblock "$o"; then
    bad "($_id) $_l, a handoff pending on disk -> ALLOWED silently — the guard fails open where it can read nothing"
  elif ! jq -e . >/dev/null 2>&1 <<<"$o"; then
    bad "($_id) $_l: the fail-closed block is not valid JSON — the harness would read no decision"
  elif ! has "$o" "$FC_MARK" || ! has "$o" "$_w"; then
    bad "($_id) $_l: blocked, but not with the fail-closed text naming the cause ('$_w')"
  elif ! grep -qF -- "-- $FC_ROW (1/" "$(fc_log)"; then
    bad "($_id) $_l: blocked, but the log carries no $FC_ROW row — a requested handoff ends with no HANDOFF_GUARD record"
  else
    ok "($_id) $_l -> the constant fail-closed block (valid JSON, names the cause) and a $FC_ROW row"
  fi
done

# (fc5) CONTROL 1: NO handoff signal on disk -> ALLOW, with no transcript and with no jq. The
#       driver signal is removed, nothing else is pending, and the pause flag is still up.
_fc5=""
for _p in "$PATH" "$FC_NJ"; do
  reset_state "$P_UNPUSHED"; touch "$P_UNPUSHED/_bmad-output/pipeline-paused.flag"; rm -f "$P_UNPUSHED/_bmad-output/.driver/handoff"
  o="$(jq -nc --arg t "$T_FC_NONE" --arg s "$SESS_A" '{transcript_path:$t,session_id:$s}' \
       | PATH="$_p" CLAUDE_PROJECT_DIR="$P_UNPUSHED" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" bash "$HOOKS_DIR/ai-dlc-continue.sh" 2>/dev/null)"
  if ! fc_isblock "$o" && ! grep -qF -- "-- $FC_ROW" "$(fc_log)"; then _fc5="${_fc5}a"; else _fc5="${_fc5}b"; fi
done
[ "$_fc5" = aa ] && ok "(fc5) no handoff signal on disk, transcript absent / no jq -> ALLOW both ways, no fail-closed row (an unreadable Stop with nothing pending is not convicted)" \
                 || bad "(fc5) with NO handoff signal on disk the fail-closed guard fired ($_fc5: absent-transcript, no-jq) — it blocks every paused Stop it cannot read"

# (fc6) CONTROL 2: the driver signal on disk and a READABLE transcript with no request -> the
#       existing decision (Check 0 does not arm on the driver signal; Check 1 allows by pause),
#       never the fail-closed block. Fail-closed must not override a real read.
o="$(fc_drive "$T_FC_QUIET")"
if ! fc_isblock "$o" && ! grep -qF -- "-- $FC_ROW" "$(fc_log)" && grep -qF -- "-- ALLOWED_BY_PAUSE" "$(fc_log)"; then
  ok "(fc6) driver signal on disk, readable transcript with no request -> ALLOWED_BY_PAUSE as before, no fail-closed row"
else
  bad "(fc6) a READABLE transcript with no handoff request got $(fc_isblock "$o" && echo "a HANDOFF GUARD block" || echo "no ALLOWED_BY_PAUSE row") — the fail-closed path overrides a real read"
fi

# (fc7) THE BOUND. A stale driver signal on a no-jq box: five Stops of ONE session. Between Stops
#       the state's epoch is pushed 4000 s back, so the 30 s time test can never continue the run:
#       only the session id -- recovered without jq -- can. At most EFF_MAX (3) blocks, then every
#       later Stop passes through, with ONE BACKOFF row and Check 1's ALLOWED_BY_PAUSE row each time.
fc7_age() { # fc7_age <state-file>: line 1 (the last-block epoch) moved 4000 s into the past
  local f="$1" e
  [ -f "$f" ] || return 0
  e="$(sed -n '1p' "$f")"; case "$e" in ''|*[!0-9]*) return 0 ;; esac
  awk -v e="$((e - 4000))" 'NR == 1 { print e; next } { print }' "$f" > "$f.age" && mv "$f.age" "$f"
}
reset_state "$P_UNPUSHED"; touch "$P_UNPUSHED/_bmad-output/pipeline-paused.flag"
_fc7=""
for _i in 1 2 3 4 5; do
  fc7_age "$P_UNPUSHED/_bmad-output/handoff-guard-state.txt"
  o="$(jq -nc --arg t "$T_FC_OK" --arg s "$SESS_A" '{transcript_path:$t,session_id:$s}' \
       | PATH="$FC_NJ" CLAUDE_PROJECT_DIR="$P_UNPUSHED" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" bash "$HOOKS_DIR/ai-dlc-continue.sh" 2>/dev/null)"
  if fc_isblock "$o"; then _fc7="${_fc7}b"; else _fc7="${_fc7}a"; fi
done
_fc7bo="$(grep -c -- '-- BACKOFF$' "$(fc_log)" 2>/dev/null)" || _fc7bo=0
_fc7ap="$(grep -c -- '-- ALLOWED_BY_PAUSE$' "$(fc_log)" 2>/dev/null)" || _fc7ap=0
{ [ "$_fc7" = bbbaa ] && [ "$_fc7bo" = 1 ] && [ "$_fc7ap" = 2 ]; } \
  && ok "(fc7) no jq, a stale driver signal, five Stops of one session spaced past the 30 s window -> bbbaa, one BACKOFF row, and ALLOWED_BY_PAUSE on both releases (bounded by session, and the release falls through to Check 1)" \
  || bad "(fc7) the fail-closed guard read $_fc7 with $_fc7bo BACKOFF and $_fc7ap ALLOWED_BY_PAUSE row(s), not bbbaa / 1 / 2 — the bound does not hold per session, or the release skips Check 1"
reset_state "$P_UNPUSHED"

# =============================================================================
# KEY 2's LIFECYCLE — the completion stamp, at both ends
# =============================================================================
# THE SUBJECT. Key 2 reads a LINE in the snapshot, and the snapshot's writers only APPEND.
# Key 1 reads a FILE that step 5 deletes, so it is self-clearing by construction; key 2 had
# no discharge at all, and a record once written armed this guard for every later paused Stop
# of every later session. Measured on the reference consumer: one record, two days old, the
# guard firing five times across one maintenance session that owed no handoff protocol.
#
# THE ARM THAT MATTERS IS THE ARMING ONE, NOT THE DISCHARGE. A discharge that is too eager
# produces a handoff whose Stop is never examined -- the whole failure ai-dlc-continue.sh's
# Check 0 exists to catch -- so every ALLOW below is paired, in the same tree, with the case
# that must still BLOCK: no stamp (c1), a stamp OLDER than the record (c3), and a transcript
# request through the stamped tree (c2's control). The discharge changes which SNAPSHOT
# RECORDS are live, and nothing else.
#
# BOTH ENDS ARE DRIVEN, because a reader with no writer discharges nothing and a writer with
# no reader is inert, and each one alone reads exactly like a working pair. (c5) drives the
# WRITER through the Stop hook's own satisfied branch -- never by touching the file here --
# so the stamp these arms read is the one a real completion produces.
#
# THE SEED IS THE PRODUCER-DERIVED ONE, the reference consumer's own bold lead-in -- the only
# instance of this record that exists anywhere. A lifecycle asserted over the reader-derived
# heading alone would be asserted over a shape nothing has been observed writing.
SNAP_BOLD_SRC="$ROOT/snap-bold.md"
[ -r "$SNAP_BOLD_SRC" ] || broken "the producer-derived snapshot seed is missing from the sandbox; every key-2 lifecycle case below would run against a tree with no handoff record and pass for the wrong reason"
snap_at() { cp "$SNAP_BOLD_SRC" "$1/_bmad-output/pipeline-snapshot.md"; }

# (c1) THE ARMING CASE. The reference consumer's own record shape, no stamp. This is the state
#      every consumer is in before its first verified completion, and it MUST still block.
dsetup
snap_at "$P_DISK"
rm -f "$(HC "$P_DISK")"
r="$(disk "$SESS_A")"
[ "$r" = block ] && ok "(c1) key 2: a handoff record with NO completion stamp -> BLOCK (a real pending handoff still arms the guard)" \
                 || bad "(c1) a pending handoff record was ALLOWED ($r) — the discharge has disarmed key 2 outright, and a genuine in-flight handoff now ends its session unexamined"

# (c2) THE DISCHARGE. The same bytes on disk, one file apart: a stamp NEWER than the record.
dsetup
snap_at "$P_DISK"
touch -t 202001010000 "$P_DISK/_bmad-output/pipeline-snapshot.md"   # the record is OLDER than the stamp; backdated, never slept for
: > "$(HC "$P_DISK")"
r="$(disk "$SESS_A")"
if [ "$r" = allow ]; then
  ok "(c2) the SAME record with a completion stamp newer than it -> ALLOW (the record's own completion clears the key)"; B_c2=1
else
  bad "(c2) a COMPLETED handoff still armed the guard ($r) — key 2 has no lifecycle, so the record arms every later paused Stop forever; this is the reference consumer's five blocks in one session"
fi
# AND THE STAMP DISCHARGES THE KEY, NOT THE GUARD. Same stamped tree, a transcript-visible
# request: Check 0 must still block. Without this the ALLOW above is equally consistent with
# a stamp that switches Check 0 off.
dsetup
snap_at "$P_DISK"
touch -t 202001010000 "$P_DISK/_bmad-output/pipeline-snapshot.md"   # the record is OLDER than the stamp; backdated, never slept for
: > "$(HC "$P_DISK")"
r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_REQ_NOBLK")")"
[ "$r" = block ] && ok "  control: the stamped tree still BLOCKS a transcript-visible request — the stamp discharges KEY 2, not Check 0" \
                 || bad "  the stamped tree allowed a transcript-visible request too ($r) — the stamp is switching the whole guard off, which is a guard that fails open"

# (c3) THE NEAR-MISS THE DISCHARGE MUST NOT COVER, and it is the exemption's own subject. A
#      LATER handoff writes a NEW record at step 3, after the previous handoff's stamp. The
#      comparison is "snapshot newer than stamp" and never the inverse: bash 3.2's `-nt` is
#      whole-second, so a compliant handoff whose step 3 and step 5 land in one second is
#      `-nt` in NEITHER direction, and the inverse form would disarm it.
dsetup
: > "$(HC "$P_DISK")"
touch -t 202001010000 "$(HC "$P_DISK")"   # the stamp is OLDER than the record
snap_at "$P_DISK"
r="$(disk "$SESS_A")"
if [ "$r" = block ]; then
  ok "(c3) a NEW record written AFTER an old stamp -> BLOCK (the exemption does not acquit the next handoff)"; B_c3=1
else
  bad "(c3) the next handoff's record was acquitted by the PREVIOUS handoff's stamp ($r) — one completed handoff disarms key 2 for the rest of the consumer's life"
fi

# (c4) KEY 1 IS UNAFFECTED BY THE STAMP. The two keys must stay separable: a lead INSIDE the
#      procedure arms the guard whatever the last handoff recorded.
dsetup "" yes
: > "$(HC "$P_DISK")"
r="$(disk "$SESS_A")"
[ "$r" = block ] && ok "(c4) the entry marker with a stamp present -> BLOCK (the discharge is scoped to key 2)" \
                 || bad "(c4) the entry marker stopped arming once a stamp existed ($r) — the discharge has leaked into key 1, and a lead mid-procedure is no longer caught"

# (c5) THE WRITER, DRIVEN THROUGH ITS OWN HOOK. The stamp is written on the branch where every
#      Check 0 arm was READ and found satisfied -- never by this fixture, and never on the
#      backoff branch, which allows a Stop it could not verify. Three cells: the unsatisfied
#      Stop leaves no stamp, the satisfied Stop writes one, and the NEXT Stop of that same
#      tree then allows. The third cell is the defect's own shape and it is what the writer
#      and the reader have to agree on.
dsetup
snap_at "$P_DISK"
rm -f "$(HC "$P_DISK")" "$P_DISK/_bmad-output/.driver/handoff"
r="$(disk "$SESS_A")"
_c5a=absent; [ -f "$(HC "$P_DISK")" ] && _c5a=present
if [ "$r" = block ] && [ "$_c5a" = absent ]; then
  ok "(c5) an UNSATISFIED Stop blocks and writes NO stamp — an unverified handoff does not discharge its own key"; B_c5a=1
else
  bad "(c5) an unsatisfied Stop verdict=$r stamp=$_c5a — a handoff that failed its own arms is recording itself complete, and the next Stop is not examined"
fi
touch -t 202001010000 "$P_DISK/_bmad-output/pipeline-snapshot.md"   # the driver signal must be NEWER than the snapshot
: > "$P_DISK/_bmad-output/.driver/handoff"
rm -f "$P_DISK/_bmad-output/handoff-guard-state.txt"
r="$(verdict "$(drive "$P_DISK" "$SESS_A" "$T_REQ_OK")")"
_c5b=absent; [ -f "$(HC "$P_DISK")" ] && _c5b=present
if [ "$r" = allow ] && [ "$_c5b" = present ]; then
  ok "  and the SATISFIED Stop allows and writes the stamp — the completion record has a producer in the shipped machinery"; B_c5b=1
else
  bad "  the satisfied Stop verdict=$r stamp=$_c5b — key 2's discharge has no writer, so the reader above can never fire on a real tree"
fi
# (hc-h) THE STAMP'S CONTENT, from that same satisfied Stop. Line 1 is `completed_at: ` plus the
#     hook's own timestamp, read independently off the ALLOWED_BY_PAUSE row the same run wrote;
#     line 2 names the session; and the stamp holds the snapshot's record line, extracted here
#     with a fixed-string grep, never with the predicate's grammar.
H_STAMP="$ROOT/h-stamp"; cp "$(HC "$P_DISK")" "$H_STAMP" 2>/dev/null || : > "$H_STAMP"
_h_ts="$(sed -n 's/^## \([^ ]*\) -- ALLOWED_BY_PAUSE$/\1/p' "$(disk_log)" 2>/dev/null | tail -1)"
_h_rec="$(grep -F 'HANDOFF POINT' "$SNAP_BOLD_SRC" | head -1)"
_h_l1="$(sed -n 1p "$H_STAMP")"; _h_l2="$(sed -n 2p "$H_STAMP")"
if [ -n "$_h_ts" ] && [ -n "$_h_rec" ] && [ "$_h_l1" = "completed_at: $_h_ts" ] && [ "$_h_l2" = "session: $SESS_A" ] \
   && grep -qxF -- "$_h_rec" "$H_STAMP"; then
  ok "(hc-h) the satisfied Stop's stamp reads completed_at: $_h_ts (its own ALLOWED_BY_PAUSE row's timestamp), session: $SESS_A, and holds the snapshot's record line"
else
  bad "(hc-h) the stamp's content is wrong: line 1 [$_h_l1], line 2 [$_h_l2], hook row ts [$_h_ts], record line held: $(grep -cxF -- "$_h_rec" "$H_STAMP" 2>/dev/null) — keys 2 and 3 cannot discharge from it"
fi
rm -f "$P_DISK/_bmad-output/handoff-guard-state.txt" "$P_DISK/_bmad-output/.handoff-guard-armed"
r="$(disk "$SESS_A")"
[ "$r" = allow ] && ok "  and the NEXT paused Stop of that same tree ALLOWS — the two halves agree, which is the whole defect" \
                 || bad "  the next Stop of the completed tree still BLOCKED ($r) — the writer's stamp is not the file the reader reads, or the comparison is the wrong way round"

# =============================================================================
# KEY 3's IN-SESSION DISCHARGE — the stamp's completed_at bounds this session's rows, by value
# =============================================================================
# Every case: the pause flag, no snapshot, a literal stamp, and request rows at literal header
# timestamps; nothing is ordered by sleeping. (hc-e) is the discharge and passes only on the fix;
# (hc-f), (hc-g), (hc-iv) and (hc-vi) must still BLOCK, each one property from (hc-e), and are fail-closed.
K3_AT="2026-08-30T12:05:00Z"
k3() { # k3 <stamp-session> <row-ts>... -> verdict; one request row of SESS_A per ts, in argument order
  local s="$1" t; shift
  log_open "$LG"; for t in "$@"; do row_prompt "$LG" "$SESS_A" "$t" "$P_INTENT"; done
  dsetup "$LG"
  printf 'completed_at: %s\nsession: %s\n' "$K3_AT" "$s" > "$(HC "$P_DISK")"
  disk "$SESS_A"
}
k3_via() { grep -qF -- "via log-request" "$(disk_log)" 2>/dev/null; }
r="$(k3 "$SESS_A" "2026-08-30T12:00:00Z")"
if [ "$r" = allow ] && grep -q -- '-- ALLOWED_BY_PAUSE$' "$(disk_log)" 2>/dev/null; then
  ok "(hc-e) this session's request row OLDER than the stamp's completed_at -> ALLOW, the Stop reaching Check 1's ALLOWED_BY_PAUSE row (a verified completion discharges key 3 in-session)"
else
  bad "(hc-e) a request row older than this session's completion stamp gave $r — key 3 is never discharged in-session, and every later paused Stop re-arms the guard"
fi
r="$(k3 "$SESS_A" "2026-08-30T12:10:00Z")"
{ [ "$r" = block ] && k3_via; } && ok "(hc-f) a request row NEWER than completed_at -> BLOCK via log-request (a request after the completion still arms)" \
                               || bad "(hc-f) a request row after the completion gave $r (via log-request: $(k3_via && echo yes || echo no)) — the stamp discharges requests it never saw"
r="$(k3 "$SESS_A" "$K3_AT")"
{ [ "$r" = block ] && k3_via; } && ok "(hc-g) a request row AT completed_at (a tie) -> BLOCK via log-request (the tie fails closed)" \
                               || bad "(hc-g) a request row tied with completed_at gave $r — the bound is strict the wrong way and a request typed while the Stop was judged is lost"
r="$(k3 "$SESS_A" "2026-08-30T12:10:00Z" "2026-08-30T12:00:00Z")"
{ [ "$r" = block ] && k3_via; } && ok "(hc-iv) a NEWER request row printed BEFORE an older one -> BLOCK via log-request (compared by value, never by position)" \
                               || bad "(hc-iv) an out-of-order log with a request after completed_at gave $r — the bound is read off log position"
r="$(k3 "$SESS_B" "2026-08-30T12:00:00Z")"
{ [ "$r" = block ] && k3_via; } && ok "(hc-vi) a stamp from ANOTHER session, this session's row older than its completed_at -> BLOCK via log-request (the key-3 discharge is session-bound)" \
                               || bad "(hc-vi) another session's stamp discharged this session's request ($r)"

# (hc-B1) A LEAD-STARTED HANDOFF: no request row, the entry marker present, the snapshot's record line
#      already held by the real writer's stamp (hc-h). Key 1 arms it. Fail-closed: passes on base too.
dsetup "" yes
snap_at "$P_DISK"
touch -t 202001010000 "$P_DISK/_bmad-output/pipeline-snapshot.md"   # the driver signal must be NEWER than the snapshot
cp "$H_STAMP" "$(HC "$P_DISK")"
rr="$(reason "$(drive "$P_DISK" "$SESS_A" "$T_NONE")")"   # no transcript, as (nt2): only the disk arms convict
{ has "$rr" "$MARKER_MARK" && grep -qF -- "via entry-marker" "$(disk_log)" 2>/dev/null; } \
  && ok "(hc-B1) lead-started handoff, marker present, record line already stamped -> BLOCK via entry-marker with the step-5 text" \
  || bad "(hc-B1) a lead-started handoff with its marker present was not blocked via entry-marker ($([ -n "$rr" ] && echo "different text" || echo "allowed")) — the stamp has disarmed key 1"

# =============================================================================
# ai-dlc-recover.sh — THE STEP-FILE OVERRIDE (the predicate, through the compact caller)
# =============================================================================
# TWO INDEPENDENTLY DERIVED VALUES, COMPARED. The mandate is read out of the emitted
# additionalContext; `.recover-fired`'s `step_file=` is written by a different statement in the
# same run and is what `ai-dlc-recover-gate.sh` actually arms on. Reading only one of them
# would leave a hook that emits a correct mandate and arms the gate on a different file
# indistinguishable from a working one.
rsetup() { # rsetup <projdir> <snapshot> <flag: yes|no> <marker: yes|no> [log]
  reset_state "$1"
  cp "$2" "$1/_bmad-output/pipeline-snapshot.md"
  [ "$3" = yes ] && touch "$1/_bmad-output/pipeline-paused.flag"
  [ "$4" = yes ] && mkmarker "$1"
  [ -n "${5:-}" ] && cp "$5" "$1/_bmad-output/pipeline-continuation-log.md"
  return 0
}
rassert() { # rassert <label> <projdir> <session> <expected-relpath> <failmsg> [hooksdir]
  local ctx sp mk
  ctx="$(rdrive "$2" "$3" "${6:-$HOOKS_DIR}")"
  if [ -z "$ctx" ]; then
    bad "$1: the recover hook emitted NO additionalContext at all — it did not run, and every negative in this section would read the same way"
    return
  fi
  sp="$(printf '%s' "$ctx" | sed -n 's/.*Your SECOND tool call MUST be `Read \([^`]*\)` in full, with native Read in consecutive.*/\1/p' | head -1)"
  if [ -z "$sp" ]; then
    bad "$1: the emitted block names NO second-mandate path — it took the unresolved branch, so this case says nothing about the override"
    return
  fi
  mk="$(sed -n 's/^step_file=//p' "$2/_bmad-output/.recover-fired" 2>/dev/null | head -1)"
  if [ "$sp" != "$mk" ]; then
    bad "$1: the mandate names '$sp' but .recover-fired records '$mk' — the lead and the gate are being pointed at different files"
    return
  fi
  if [ "$sp" = "$4" ]; then
    ok "$1"
    case "$1" in
      "(n) "*) B_n=1 ;; "(o) "*) B_o=1 ;; "(o-synth) "*) B_osynth=1 ;; "(o2) "*) B_o2=1 ;; "(p) "*) B_p=1 ;;
      "(q) "*) B_q=1 ;; "(r) "*) B_r=1 ;; "(s) "*) B_s=1 ;;
    esac
  else
    bad "$5 (the mandate named '$sp', expected '$4')"
  fi
}

SNAP_PLAIN="$ROOT/snap-plain.md"
SNAP_HEADING="$ROOT/snap-heading.md"
SNAP_BOLD="$ROOT/snap-bold.md"
SNAP_MENTION="$ROOT/snap-mention.md"

# (l) Nothing pending. The baseline, and it is PRESENCE-shaped: it requires the mandate to
#     name the snapshot's own step file, which a hook that emitted nothing cannot do.
rsetup "$P_REC" "$SNAP_PLAIN" no no
rassert "(l) nothing pending -> the mandate names the snapshot's own current_step_file" \
  "$P_REC" "$SESS_A" "$STEP_IMPL" \
  "(l) a recovery with NO pending handoff was routed to handoff.md — every compaction in the sprint now recovers into the wrong procedure"

# (m) The pause flag on its own. It is raised by every Rule 3 pause point and by every operator
#     message, and steps/handoff.md step 5 creates it too, so on its own it is as true after a
#     completed handoff as during a pending one.
rsetup "$P_REC" "$SNAP_PLAIN" yes no
rassert "(m) pause flag alone, no key -> still the snapshot's own step file" \
  "$P_REC" "$SESS_A" "$STEP_IMPL" \
  "(m) the pause flag alone routed the recovery to handoff.md — every paused compaction in a sprint would recover into the handoff procedure"

# (n) KEY 1, the entry marker, alone: no HANDOFF POINT heading and no continuation log, so
#     neither of the other two keys can reach this case.
rsetup "$P_REC" "$SNAP_PLAIN" yes yes
rassert "(n) key 1 (.handoff-in-progress) -> the mandate names handoff.md" \
  "$P_REC" "$SESS_A" "$STEP_HANDOFF" \
  "(n) a compaction landing INSIDE the handoff procedure was routed back to the interrupted step — the marker steps/handoff.md exists to leave is not being read"

# (s) THE SAME PENDING STATE WITH steps/handoff.md UNREADABLE. A mandate must name something
#     the lead can actually read; a lead that cannot comply learns that these MUSTs are
#     negotiable. Beside (n) in the same tree, differing in one file.
# The marker is produced BEFORE handoff.md is moved away, so this case is genuinely "the
# procedure was entered and the file has since become unreadable" rather than a marker the
# fixture invented for a file that was never there.
rsetup "$P_REC" "$SNAP_PLAIN" yes yes
mv "$P_REC/$STEP_HANDOFF" "$P_REC/${STEP_HANDOFF}.hidden"
rassert "(s) pending, but steps/handoff.md is ABSENT -> falls back to the snapshot's step file" \
  "$P_REC" "$SESS_A" "$STEP_IMPL" \
  "(s) the override named handoff.md in a tree where it does not exist — the mandate cannot be complied with, and ai-dlc-recover-gate.sh would arm on a path that resolves nowhere"
mv "$P_REC/${STEP_HANDOFF}.hidden" "$P_REC/$STEP_HANDOFF"
[ -r "$P_REC/$STEP_HANDOFF" ] || broken "failed to restore $STEP_HANDOFF after case (s) — every later recover case would be testing an absent file"

# (k16) A PENDING HANDOFF OWES THE WHOLE handoff.md, NEVER A RESUME RANGE OF THE INTERRUPTED STEP. The snapshot's sub_step
#     names the interrupted step (implementation.md, which here carries a Resume table naming that value), and the Resume-range
#     narrowing applies only to the step file the mandate resolved to; the override resolves handoff.md, so the file part does
#     not match and the marker carries no step_ranges. THE CONTROL IS IN THE SAME ARM, same tree and snapshot bytes, one
#     key apart: with no pending handoff the mandate resolves to the interrupted step and the SAME sub_step DOES narrow it,
#     so the absence above is the override's doing and not a seed that cannot express a range.
_k_snap="$ROOT/snap-substep.md"
awk '/^current_step_file: implementation.md$/ { print "- current_step_file: implementation.md"; print "- sub_step: implementation.md#alpha"; next } { print }' "$SNAP_PLAIN" > "$_k_snap"
grep -qF -- '- sub_step: implementation.md#alpha' "$_k_snap" || broken "the (k) seed carries no sub_step line, so it cannot express the case"
_k_orig="$ROOT/impl-orig.md"; cp "$P_REC/$STEP_IMPL" "$_k_orig"
printf '# implementation\n\nThe step the handoff interrupted.\n\n## Resume\n\n| Value | Meaning |\n| `alpha` | first |\n\n## Body\n\n### alpha. Alpha\nalpha body\n' > "$P_REC/$STEP_IMPL"
rsetup "$P_REC" "$_k_snap" no no
_k_ctl="$(rdrive "$P_REC" "$SESS_A")"
_k_ctl_mk="$(grep -c '^step_ranges=' "$P_REC/_bmad-output/.recover-fired" 2>/dev/null)" || _k_ctl_mk=0
rsetup "$P_REC" "$_k_snap" yes yes
_k_ctx="$(rdrive "$P_REC" "$SESS_A")"
_k_mk="$(grep -c '^step_ranges=' "$P_REC/_bmad-output/.recover-fired" 2>/dev/null)" || _k_mk=0
cp "$_k_orig" "$P_REC/$STEP_IMPL"
cmp -s "$_k_orig" "$P_REC/$STEP_IMPL" || broken "failed to restore $STEP_IMPL after case (k)"
if [ "$_k_ctl_mk" != 1 ] || ! grep -qF -- "Read ${STEP_IMPL} offset=1 limit=" <<<"$_k_ctl"; then
  bad "(k16) the CONTROL did not narrow: with no pending handoff the sub_step implementation.md#alpha left marker step_ranges lines=$_k_ctl_mk and mandate [$(grep -o 'SECOND tool call MUST be[^.]*' <<<"$_k_ctl" | head -1)] — the seed cannot express a range, so the absence below proves nothing"
elif [ "$_k_mk" = 0 ] && grep -qF -- "Read ${STEP_HANDOFF}\` in full" <<<"$_k_ctx" && ! grep -qF -- "offset=1 limit=" <<<"$_k_ctx"; then
  ok "(k16) a pending handoff plus a sub_step naming the interrupted step -> the whole handoff.md mandate and NO step_ranges in the marker (while the same sub_step with nothing pending narrows the interrupted step)"
else
  bad "(k16) a pending handoff with a sub_step on the interrupted step did not give the whole handoff.md mandate (marker step_ranges lines=$_k_mk): [$(grep -o 'SECOND tool call MUST be[^.]*' <<<"$_k_ctx" | head -1)]"
fi

# (o) KEY 2, the snapshot's handoff record, alone: no entry marker and no continuation log.
#
# TWO POSITIVE SHAPES AND ONE NEGATIVE, ordered by PROVENANCE, because this key is the one
# whose grammar came from the reader rather than from a producer and that is exactly how it
# first went wrong. Nothing in core WRITES this record -- a lead does, by hand -- so the first
# grammar demanded a markdown heading and scored ZERO on the only instance that exists
# anywhere. (o) is the found shape and is primary; (o-synth) is the imagined one and is kept
# only because it is a legal spelling the key must still accept. A battery carrying (o-synth)
# alone passes against the grammar that shipped broken.
rsetup "$P_REC" "$SNAP_BOLD" yes no
rassert "(o) key 2 as the reference consumer ACTUALLY wrote it — a bold lead-in, no '#' -> handoff.md [= hc-d: no stamp is PENDING]" \
  "$P_REC" "$SESS_A" "$STEP_HANDOFF" \
  "(o) the ONE real handoff record that exists scores as a non-instance — a grammar that demands a heading misses the very record this key was added to detect, and a consumer mid-handoff at pull time has this key and nothing else"

rsetup "$P_REC" "$SNAP_HEADING" yes no
rassert "(o-synth) key 2 as a markdown HEADING, the reader-derived shape -> handoff.md" \
  "$P_REC" "$SESS_A" "$STEP_HANDOFF" \
  "(o-synth) a snapshot carrying a handoff record as a heading was routed back to the interrupted step"

# (o2) THE SAME WORDS MID-LINE, which is discussion and not a record. Beside both positives in
#      the same tree, differing only in where on the line the words sit.
rsetup "$P_REC" "$SNAP_MENTION" yes no
rassert "(o2) the same words as a MENTION mid-line -> the snapshot's own step file (a mention is not a record)" \
  "$P_REC" "$SESS_A" "$STEP_IMPL" \
  "(o2) a snapshot merely DISCUSSING the handoff record was treated as carrying one — the key is a bare substring and any snapshot whose prose names the section reroutes every compaction"

# (o3) KEY 2's DISCHARGE THROUGH THE OTHER CALLER. The two callers pass different state dirs
#      and different session sources, and a discharge that works at the Stop seam and not here
#      leaves a compaction after a COMPLETED handoff recovering into the handoff procedure --
#      the exact drift the shared predicate exists to prevent. Paired in the same tree with
#      (o), which must still route: the discharge is one file apart from it.
rsetup "$P_REC" "$SNAP_BOLD" yes no
touch -t 202001010000 "$P_REC/_bmad-output/pipeline-snapshot.md"
: > "$(HC "$P_REC")"
rassert "(o3) key 2 with a completion stamp newer than the record -> the snapshot's own step file" \
  "$P_REC" "$SESS_A" "$STEP_IMPL" \
  "(o3) a COMPLETED handoff still routed a post-compact recovery into handoff.md — key 2's discharge does not reach ai-dlc-recover.sh, so the two callers answer one question differently"
rsetup "$P_REC" "$SNAP_BOLD" yes no
: > "$(HC "$P_REC")"
touch -t 202001010000 "$(HC "$P_REC")"
cp "$SNAP_BOLD" "$P_REC/_bmad-output/pipeline-snapshot.md"
rassert "  control: a record NEWER than the stamp still routes to handoff.md — the discharge is the ordering, not the file's presence [= hc-c: a legacy 0-byte stamp older than the snapshot is PENDING]" \
  "$P_REC" "$SESS_A" "$STEP_HANDOFF" \
  "  a handoff record written after the previous handoff's stamp was acquitted — one completed handoff disarms the recovery override for good"
# That control is also (hc-c): a legacy 0-byte stamp older than the snapshot is PENDING; and (o) is (hc-d):
# no stamp is PENDING.

# KEY 2 AGAINST A STAMP THAT HOLDS ITS RECORD LINES. Every snapshot below is the bold seed with one
# line changed or appended; the stamp's record line is cut from that seed with a fixed-string grep,
# never with the predicate's grammar. mtimes are literal (`touch -t`): K2_OLD for the earlier file,
# K2_NEW for the later. (hc-a) and the round trip (hc-v) are the discharge and pass only on the fix; every
# PENDING arm beside them differs in one property.
K2_OLD=202001010000; K2_NEW=202101010000
K2_REC="$(grep -F 'HANDOFF POINT' "$SNAP_BOLD" | head -1)"
[ -n "$K2_REC" ] || broken "the bold seed carries no HANDOFF POINT line, so no key-2 stamp arm below can express its case"
K2_STAMP="$ROOT/k2-stamp"; printf 'completed_at: 2026-08-30T12:05:00Z\nsession: %s\n%s\n' "$SESS_A" "$K2_REC" > "$K2_STAMP"
K2_BAD="$ROOT/k2-stamp-unparseable"; printf 'completed: yesterday\nsession: %s\n%s\n' "$SESS_A" "$K2_REC" > "$K2_BAD"
k2snap() { # k2snap <out> <base-snapshot> <awk program over it>
  awk "$3" "$2" > "$1"
}
K2_SN_B="$ROOT/snap-k2-new-record.md";  k2snap "$K2_SN_B" "$SNAP_BOLD" '{ print } END { print ""; print "**HANDOFF POINT (operator-requested, second handoff after gate-3).** The next handoff." }'
K2_SN_II="$ROOT/snap-k2-amended.md";    k2snap "$K2_SN_II" "$SNAP_BOLD" '/HANDOFF POINT/ { print $0 " (amended)"; next } { print }'
K2_SN_III="$ROOT/snap-k2-lowercase.md"; k2snap "$K2_SN_III" "$SNAP_BOLD" '/HANDOFF POINT/ { sub(/HANDOFF POINT/, "handoff point") } { print }'
K2_SN_N1="$ROOT/snap-k2-prose.md";      k2snap "$K2_SN_N1" "$SNAP_PLAIN" '{ print } END { print ""; print "see the HANDOFF POINT section below" }'
K2_SN_N2="$ROOT/snap-k2-list-near.md";  k2snap "$K2_SN_N2" "$SNAP_PLAIN" '{ print } END { print ""; print "- the handoff point was moved" }'
K2_SN_L="$ROOT/snap-k2-list.md";        k2snap "$K2_SN_L" "$SNAP_PLAIN" '{ print } END { print ""; print "- HANDOFF POINT (operator-requested, mid gate-3 for story-307-1)" }'
grep -qxF -- "$K2_REC (amended)" "$K2_SN_II" && grep -qF 'handoff point (operator-requested' "$K2_SN_III" && ! grep -qF 'HANDOFF POINT' "$K2_SN_III" \
  && grep -qxF -- '- HANDOFF POINT (operator-requested, mid gate-3 for story-307-1)' "$K2_SN_L" \
  || broken "a key-2 stamp-arm snapshot did not take its one-line change"
k2() { # k2 <snapshot> <stamp|-> <older: stamp|snapshot> -> sets up P_REC
  rsetup "$P_REC" "$1" yes no
  [ "$2" = - ] || cp "$2" "$(HC "$P_REC")"
  if [ "$2" != - ]; then
    if [ "$3" = stamp ]; then touch -t "$K2_OLD" "$(HC "$P_REC")"; touch -t "$K2_NEW" "$P_REC/_bmad-output/pipeline-snapshot.md"
    else touch -t "$K2_OLD" "$P_REC/_bmad-output/pipeline-snapshot.md"; touch -t "$K2_NEW" "$(HC "$P_REC")"; fi
  fi
}
k2 "$SNAP_BOLD" "$K2_STAMP" stamp
rassert "(hc-a) a stamp holding the record line, then a LATER ordinary snapshot write -> the snapshot's own step file (the record line is discharged, whatever the mtime)" \
  "$P_REC" "$SESS_A" "$STEP_IMPL" \
  "(hc-a) an ordinary snapshot write after a verified completion re-armed key 2 — the discharge is by mtime and every later snapshot edit routes the recovery into handoff.md"
k2 "$K2_SN_B" "$K2_STAMP" stamp
rassert "(hc-b) the same stamp, then the snapshot gains a NEW record line -> handoff.md (the next handoff still arms)" \
  "$P_REC" "$SESS_A" "$STEP_HANDOFF" \
  "(hc-b) a new record line written after the stamp was acquitted by the previous handoff's stamp"
k2 "$SNAP_BOLD" "$K2_BAD" stamp
rassert "(hc-i) a NON-EMPTY unparseable stamp holding the record line, the snapshot newer -> handoff.md (the legacy mtime path)" \
  "$P_REC" "$SESS_A" "$STEP_HANDOFF" \
  "(hc-i) an unparseable stamp discharged key 2 by its record lines — only a parseable stamp is a membership discharge"
k2 "$SNAP_BOLD" "$K2_BAD" snapshot
rassert "  twin: the same unparseable stamp NEWER than the snapshot -> the snapshot's own step file (the legacy path still discharges by mtime)" \
  "$P_REC" "$SESS_A" "$STEP_IMPL" \
  "  an unparseable stamp newer than the snapshot armed key 2 — the legacy mtime path is gone, not kept"
k2 "$K2_SN_II" "$K2_STAMP" stamp
rassert "(hc-ii) a snapshot line EXTENDING the stamp's line (' (amended)') -> handoff.md (membership is whole-line, never prefix or substring)" \
  "$P_REC" "$SESS_A" "$STEP_HANDOFF" \
  "(hc-ii) an amended record line was discharged by the stamp's shorter line — membership is a prefix or substring test"
k2 "$K2_SN_III" "$K2_STAMP" stamp
rassert "(hc-iii) a CASE-VARIANT record line ('handoff point') -> handoff.md (membership is exact; only selection is case-blind)" \
  "$P_REC" "$SESS_A" "$STEP_HANDOFF" \
  "(hc-iii) a lower-case record line was discharged by the stamp's upper-case one — membership is case-blind"
k2 "$K2_SN_N1" - -
rassert "(hc-nm1) NEAR-MISS: a mid-line prose mention ('see the HANDOFF POINT section below') -> the snapshot's own step file" \
  "$P_REC" "$SESS_A" "$STEP_IMPL" \
  "(hc-nm1) a prose mention of the record armed key 2"
k2 "$K2_SN_N2" - -
rassert "(hc-nm2) NEAR-MISS: a list item not opening with the token ('- the handoff point was moved') -> the snapshot's own step file" \
  "$P_REC" "$SESS_A" "$STEP_IMPL" \
  "(hc-nm2) a list item merely naming the handoff point armed key 2 — the list prefix admits any following text"
k2 "$K2_SN_L" - -
rassert "(hc-lp) the LIST-ITEM record spelling ('- HANDOFF POINT (...)') -> handoff.md (the grammar takes the list prefix)" \
  "$P_REC" "$SESS_A" "$STEP_HANDOFF" \
  "(hc-lp) a list-item record line did not arm key 2 — the grammar has no list prefix"
k2 "$SNAP_BOLD" "$H_STAMP" stamp
rassert "(hc-v) round trip: the stamp a real satisfied Stop wrote (hc-h), then a later snapshot write -> the snapshot's own step file" \
  "$P_REC" "$SESS_A" "$STEP_IMPL" \
  "(hc-v) the real writer's stamp does not discharge key 2 after a later snapshot write — writer and reader disagree on the record lines"

# (p) KEY 3, this session's request rows, alone: no entry marker and no HANDOFF POINT heading.
#     TWO ROWS, request first and a question about it second. See log_two_row's header.
log_two_row "$LG" "$SESS_A" "$P_INTENT" "$P_AFTER"
rsetup "$P_REC" "$SNAP_PLAIN" yes no "$LG"
rassert "(p) key 3 (this session's request row, with a LATER non-request row after it) -> handoff.md" \
  "$P_REC" "$SESS_A" "$STEP_HANDOFF" \
  "(p) the operator's recorded request was not found — either key 3 is dead, or the reader keeps only the LAST block of the session, which is the 'most recent row' reading measured at 1 of 22 and rejected"

# (q) The same two-row log read by a DIFFERENT session. Beside (p) in the same tree, same
#     bytes on disk, differing only in the session id the harness supplies.
rsetup "$P_REC" "$SNAP_PLAIN" yes no "$LG"
rassert "(q) the same rows read by a DIFFERENT session -> the snapshot's own step file" \
  "$P_REC" "$SESS_B" "$STEP_IMPL" \
  "(q) another session's handoff rows rerouted this recovery — the log is rotated per sprint, so every compaction for the rest of the sprint would recover into handoff.md"

# (r) EVERY KEY PRESENT AND THE PAUSE FLAG GONE. This is the state a resumed session is in:
#     the resume path removed the flag, and a stale marker or an old log row must not fire.
log_two_row "$LG" "$SESS_A" "$P_INTENT" "$P_AFTER"
rsetup "$P_REC" "$SNAP_HEADING" no yes "$LG"
rassert "(r) all three keys present but NO pause flag -> the snapshot's own step file" \
  "$P_REC" "$SESS_A" "$STEP_IMPL" \
  "(r) a stale key fired with the pipeline unpaused — a session that has already resumed would be dragged back into the handoff procedure on its next compaction"

# The consumer layout. `install.sh` splits what shares a parent here, and a path that resolves
# in this tree can resolve nowhere in an installed one; the override's candidate loop tries
# `.claude/...` FIRST, so the distribution layout above exercises only its second branch.
rsetup "$P_REC_CLAUDE" "$SNAP_PLAIN" yes yes
rassert "(n-consumer) key 1 in a .claude/ INSTALLED layout -> the mandate names .claude/…/handoff.md" \
  "$P_REC_CLAUDE" "$SESS_A" "$STEP_HANDOFF_C" \
  "(n-consumer) the override did not resolve in the consumer layout — it would name nothing on every installed tree, which is where this hook actually runs"
rsetup "$P_REC_CLAUDE" "$SNAP_PLAIN" no no
rassert "  control: the same consumer tree with nothing pending -> .claude/…/implementation.md" \
  "$P_REC_CLAUDE" "$SESS_A" "$STEP_IMPL_C" \
  "  the consumer tree does not resolve its own step file either — the layout arm above proves nothing"

# =============================================================================
# ai-dlc-handoff-entry.sh — THE PRODUCER OF KEY 1
# =============================================================================
# Key 1 is the only key with a shipped writer, and until this section existed every key-1 seed
# in this fixture was a file the fixture touched itself -- which proves the reader accepts the
# fixture's own spelling and nothing about whether the two halves agree. `mkmarker` now drives
# this hook for every key-1 seed above, so those arms and these share one producer.
#
# WHY A HOOK AND NOT THE STEP FILE: I95 rejected the step-file version, because
# pipeline-state-paths.json's `producer` field requires a shipped file that CONSTRUCTS the path
# on a non-comment line, and a file that tells a lead to construct it does not. The defect this
# whole change exists for is a lead that did not execute the procedure at all, so a marker whose
# only writer is that same procedure is absent in precisely the motivating case.
#
# THE NEGATIVES ARE ABSENCE-SHAPED AND A CRASHED HOOK PRODUCES THE SAME ABSENCE, so each one is
# followed IN THE SAME TREE by the positive, which must create the marker.
eassert() { # eassert <label> <tool> <path> <want: marker|no-marker> <failmsg>
  local rc
  rm -f "$P_ENTRY/_bmad-output/.handoff-in-progress"
  rc="$(edrive "$P_ENTRY" "$2" "$3")"
  if [ "$rc" != "0" ]; then
    bad "$1: the hook exited $rc — it is PostToolUse, it runs after the call has returned, and every path must exit 0 or the pipeline's ability to READ a step file depends on its ability to write one"
    return
  fi
  if [ "$4" = marker ]; then
    if marker_at "$P_ENTRY"; then ok "$1"; else bad "$5"; fi
  else
    if marker_at "$P_ENTRY"; then
      bad "$5"
    else
      ok "$1"
      case "$1" in
        "(e2) "*) B_e2=1 ;; "(e2b) "*) B_e2b=1 ;; "(e3) "*) B_e3=1 ;;
      esac
    fi
  fi
}
econtrol() { # econtrol — the positive, in the same tree, after a negative
  rm -f "$P_ENTRY/_bmad-output/.handoff-in-progress"
  local rc; rc="$(edrive "$P_ENTRY" Read "$P_ENTRY/core/skills/ai-dlc/steps/handoff.md")"
  { [ "$rc" = 0 ] && marker_at "$P_ENTRY"; } \
    && ok "  control: a Read of steps/handoff.md in the same tree DOES create the marker — the hook runs here" \
    || bad "  the hook does not create the marker in this tree either (exit $rc) — the absence above is a dead hook, not a guard"
}

eassert "(e1) Read of steps/handoff.md -> the entry marker is created" \
  Read "$P_ENTRY/core/skills/ai-dlc/steps/handoff.md" marker \
  "(e1) a Read of the handoff step file left NO marker — the only on-disk trace that the lead ENTERED the procedure is missing, and a compaction inside the five steps recovers into the interrupted step"

eassert "(e1c) the same file by its CONSUMER spelling (.claude/…) -> the marker is created" \
  Read "$P_ENTRY/.claude/skills/ai-dlc/steps/handoff.md" marker \
  "(e1c) the consumer spelling did not match — the hook is anchored on a distribution-only path and would never fire on an installed tree, which is where it actually runs"

eassert "(e2) Read of a DIFFERENT step file -> no marker" \
  Read "$P_ENTRY/core/skills/ai-dlc/steps/implementation.md" no-marker \
  "(e2) reading an ordinary step file created the handoff marker — every step in the pipeline would then look like a handoff in progress"
econtrol

eassert "(e2b) Read of a consumer's OWN unrelated docs/handoff.md -> no marker" \
  Read "$P_ENTRY/docs/handoff.md" no-marker \
  "(e2b) a file merely NAMED handoff.md, outside steps/, created the marker — the match is on the basename alone and any consumer document with that name arms the guard"
econtrol

eassert "(e3) EDIT of steps/handoff.md -> no marker" \
  Edit "$P_ENTRY/core/skills/ai-dlc/steps/handoff.md" no-marker \
  "(e3) editing the step file created the marker — the marker means the lead is EXECUTING the procedure, and an author changing the file is not"
econtrol

# (e4) NO _bmad-output DIRECTORY. A plain file read must not manufacture pipeline state, and
#      the hook must still exit 0: it is PostToolUse, so a failure here cannot be allowed to
#      surface as a tool error.
rm -rf "$P_ENTRY/_bmad-output"
_e4rc="$(edrive "$P_ENTRY" Read "$P_ENTRY/core/skills/ai-dlc/steps/handoff.md")"
if [ "$_e4rc" != "0" ]; then
  bad "(e4) with no _bmad-output directory the hook exited $_e4rc — a marker hook that can fail makes reading a step file depend on writing a file"
elif [ -d "$P_ENTRY/_bmad-output" ]; then
  bad "(e4) the hook CREATED _bmad-output on a tree that has never run the pipeline — a plain file read now manufactures pipeline state"
else
  ok "(e4) no _bmad-output directory -> no marker, no directory created, and exit 0"
fi
mkdir -p "$P_ENTRY/_bmad-output"
econtrol

# (e5) THE PRODUCER/CONSUMER JOIN, END TO END. Nothing below hand-writes the marker: the entry
#      hook writes it and the recover hook reads it through the shared predicate. Two shipped
#      halves, one file, no fixture-authored spelling in between -- which is the only form of
#      this assertion that could catch the two disagreeing about the path or the filename.
reset_state "$P_REC"
cp "$SNAP_PLAIN" "$P_REC/_bmad-output/pipeline-snapshot.md"
touch "$P_REC/_bmad-output/pipeline-paused.flag"
_e5rc="$(edrive "$P_REC" Read "$P_REC/$STEP_HANDOFF")"
if [ "$_e5rc" != "0" ] || ! marker_at "$P_REC"; then
  bad "(e5) the entry hook did not write a marker into the recover tree (exit $_e5rc) — the join below cannot be read"
else
  rassert "(e5) the marker the ENTRY hook wrote routes a recovery to handoff.md (no hand-written seed anywhere)" \
    "$P_REC" "$SESS_A" "$STEP_HANDOFF" \
    "(e5) the writer and the reader disagree about the entry marker — each half works against a seed the fixture wrote, and neither works against the other"
fi

# =============================================================================
# (e6)-(e13) A RECOVERY-MANDATED READ IS NOT A HANDOFF INITIATION
# =============================================================================
# THE DEFECT. `ai-dlc-recover.sh` MANDATES `Read <step file>` as the second tool call after
# EVERY compaction and points that mandate at handoff.md whenever a handoff is already
# pending; `ai-dlc-recover-gate.sh` then DENIES any other call until that Read happens. So a
# session that merely compacts while paused is COMPELLED to read handoff.md -- and this hook,
# which armed on any Read of that path, wrote the entry marker on the strength of a Read the
# machinery itself forced. The marker means "this session is INSIDE the handoff procedure",
# and it is key 1: the key that arms the Stop guard and reroutes the next compaction. A
# session that never began the procedure has nothing to run step 5, so it persists.
#
# EVERY ARM HERE DRIVES THE SHIPPED HOOK SEQUENCE, AND THAT IS THE WHOLE POINT OF THE
# SECTION. The two hooks run on different events: `ai-dlc-recover-gate.sh` is PreToolUse on
# every tool, `ai-dlc-handoff-entry.sh` is PostToolUse on `Read`. On the call that satisfies
# the second mandate the real order is GATE, then the Read, then ENTRY -- and the gate DELETES
# `.recover-fired` on that call, one hook before the entry hook runs. A seed that invokes the
# entry hook alone with a hand-placed marker reports not-armed, correctly, about a sequence no
# consumer ever executes; it cannot see either of the two defects a tip adversary found here.
#
# THE ORDER IS PARSED OUT OF THE SETTINGS TEMPLATE, NEVER ASSUMED -- AND NOT HERE. A fixture
# that hard-codes "gate first" encodes one hand's belief about the registration, and the
# registration is the thing that decides. If the template ever registered the entry hook on
# PreToolUse, or the gate on PostToolUse, this section would be driving a sequence the consumer
# does not run and would keep printing `ok`. That (e6-order) check and its impossible-hook
# control live in `schema-install-fallback`, which is `.dist-only` and declares `templates/`.
# They used to sit here behind a template-present test, and that test was the defect: this
# fixture SHIPS, so it cannot declare `templates/settings.json.template` (a declared path absent
# on a consumer is exit 2), so its sandbox never held the template and the check stood down on
# every gated run while printing ok. The line below is not an assertion: it is an informational
# `--` line, never an `ok`, and it counts toward no total, because nothing here checks the order
# any more and an unconditional `ok` would claim a check that does not run. It prints the same
# in a plain run and a sandboxed run.
echo ""
echo "  --    (e6-order) the registration order (gate on PreToolUse, entry on PostToolUse) is asserted against the settings template in schema-install-fallback (.dist-only, declares templates/); the arms below drive gate-then-entry"

# `gdrive` runs the PreToolUse gate exactly as the harness does: JSON on stdin, decision on
# stdout. `seq_read` then runs the SHIPPED SEQUENCE for one Read -- gate, then entry -- and
# reports marker|no-marker. Nothing here hand-places `.recover-satisfied`: the gate writes it
# on the satisfying call and the entry hook consumes it, which is the only form of this
# assertion that can catch the two halves disagreeing about the breadcrumb.
gdrive() { # gdrive <projdir> <tool> <file-path> [hooksdir] -> raw decision JSON
  local proj="$1" tool="$2" fp="$3" hd="${4:-$HOOKS_DIR}"
  # The gate refuses every UNBOUNDED Read of a mandated file, so a Read is bounded (offset 1, limit 2000: the
  # whole of a small file) unless GD_UNBOUNDED=1; GD_ID gives the call a tool_use_id.
  jq -nc --arg t "$tool" --arg p "$fp" --arg id "${GD_ID:-}" --arg ub "${GD_UNBOUNDED:-0}" \
    '{tool_name:$t,tool_input:({file_path:$p} + (if $t == "Read" and $ub != "1" then {offset:1,limit:2000} else {} end))} + (if $id != "" then {tool_use_id:$id} else {} end)' \
  | CLAUDE_PROJECT_DIR="$proj" bash "$hd/ai-dlc-recover-gate.sh" 2>/dev/null
}
gdenied() { printf '%s' "$1" | jq -e '.hookSpecificOutput.permissionDecision=="deny"' >/dev/null 2>&1; }
# `reset_state` PREDATES BOTH OF THESE FILES AND DOES NOT CLEAR THEM, and that leak is not
# cosmetic: measured while building this section, a stale `.recover-gate-progress` from the
# previous case put a freshly-reset tree at the gate's SECOND mandate before any snapshot Read
# had happened, so (e8) was building a window it then asserted it could not build — and (e6)
# read a breadcrumb an earlier case had caused. Every case here differs from its neighbour in
# one file, which is only a true statement if the residue is removed.
#
# IT IS A SEPARATE HELPER RATHER THAN A CHANGE TO `reset_state`, because that function is
# called by roughly a hundred arms in this file whose subject is the Stop seam; widening it
# would change what every one of them is seeded with, and the two files are this section's.
rclean() { rm -f "$1/_bmad-output/.recover-gate-progress" "$1/_bmad-output/.recover-satisfied" \
                 "$1/_bmad-output/.recover-fired" 2>/dev/null || true; }
seq_read() { # seq_read <projdir> <read-path> [hooksdir] -> marker|no-marker
  local proj="$1" fp="$2" hd="${3:-$HOOKS_DIR}"
  rm -f "$proj/_bmad-output/.handoff-in-progress"
  gdrive "$proj" Read "$fp" "$hd" >/dev/null   # PreToolUse
  edrive "$proj" Read "$fp" "$hd" >/dev/null   # the Read happens, then PostToolUse
  if [ -f "$proj/_bmad-output/.handoff-in-progress" ]; then printf marker; else printf no-marker; fi
}
# Puts a tree into the state where the gate's SECOND mandate is outstanding: a recovery has
# fired and the snapshot Read has already been made. Built by driving the real hooks.
arm_to_step() { # arm_to_step <projdir> <session>
  rdrive "$1" "$2" >/dev/null                                   # ai-dlc-recover.sh writes .recover-fired
  local _sn; _sn="$(sed -n 's/^snapshot_path=//p' "$1/_bmad-output/.recover-fired" 2>/dev/null | head -1)"
  [ -n "$_sn" ] && gdrive "$1" Read "$1/$_sn" >/dev/null        # satisfy mandate 1 through the gate
}

# --- (e6) THE SUPPRESSED STATE, DRIVEN AS THE CONSUMER RUNS IT ---------------------------
reset_state "$P_REC"; rclean "$P_REC"
cp "$SNAP_PLAIN" "$P_REC/_bmad-output/pipeline-snapshot.md"
touch "$P_REC/_bmad-output/pipeline-paused.flag"
mkmarker "$P_REC"                    # a handoff IS pending, so the mandate points at handoff.md
arm_to_step "$P_REC" "$SESS_A"
_E6_STEP="$(sed -n 's/^step_file=//p' "$P_REC/_bmad-output/.recover-fired" 2>/dev/null | head -1)"
_E6_STAGE="$(cat "$P_REC/_bmad-output/.recover-gate-progress" 2>/dev/null || true)"
# THE PRECONDITIONS ARE ASSERTED BEFORE THE ARM. A tree whose mandate names another file, or
# whose gate is still on stage 1, is in a DIFFERENT world -- one where arming is correct -- and
# (e6) would then pass for the opposite reason to the one it claims.
case "$_E6_STEP" in
  */steps/handoff.md|steps/handoff.md) _e6_ok=1 ;;
  *) _e6_ok=0 ;;
esac
if [ "$_e6_ok" -ne 1 ]; then
  bad "(e6-pre) the recovery recorded step_file='${_E6_STEP:-<nothing>}', which does not name handoff.md — this tree is in (e8)'s world and (e6) would pass by arming correctly rather than by suppressing"
elif [ "$_E6_STAGE" != "step" ]; then
  bad "(e6-pre) after the snapshot Read the gate is at stage '${_E6_STAGE:-<none>}', not 'step'. The second mandate is not outstanding, so the Read below is not the one the recovery demands and (e6) measures nothing"
else
  ok "(e6-pre) the recovery mandates handoff.md and the gate is at its SECOND mandate — the Read below is the compelled one"
  # The gate must ALLOW this Read; if it denied, no consumer would ever reach the entry hook
  # with this input and the arm would be about an unreachable sequence.
  _E6_DEC="$(gdrive "$P_REC" Read "$P_REC/$STEP_HANDOFF")"
  if gdenied "$_E6_DEC"; then
    bad "(e6-pre) the gate DENIED the very Read it mandated, so the sequence under test is unreachable and (e6)'s verdict is about a call no consumer makes"
  else
    ok "  and the gate ALLOWS that Read, so the shipped sequence reaches the entry hook"
  fi
  # RE-ARM, AND `rclean` IS WHAT MAKES THE RE-ARM REAL. The gate probe above satisfied the
  # second mandate, so it WROTE a breadcrumb; `reset_state` predates that file and does not
  # remove it. Left in place, `mkmarker`'s own Read consumes it and is suppressed, key 1 is
  # never created, the recovery then mandates the INTERRUPTED step instead of handoff.md, and
  # the sequence below arms — reported as (e6) failing, which is a true statement about a
  # world the fixture built wrong rather than about the hook. Measured exactly that way.
  reset_state "$P_REC"; rclean "$P_REC"
  cp "$SNAP_PLAIN" "$P_REC/_bmad-output/pipeline-snapshot.md"
  touch "$P_REC/_bmad-output/pipeline-paused.flag"
  mkmarker "$P_REC"; arm_to_step "$P_REC" "$SESS_A"
  if [ "$(seq_read "$P_REC" "$P_REC/$STEP_HANDOFF")" = no-marker ]; then
    ok "(e6) driven in SHIPPED ORDER (gate -> Read -> entry), a recovery-mandated Read does NOT write the entry marker"
    B_e6=1
  else
    bad "(e6) a recovery-mandated Read wrote the entry marker when the two hooks are driven in shipped order. The gate deletes .recover-fired on this very call, one hook before the entry hook runs, so a suppression keyed on that marker is UNREACHABLE on a consumer — it tests a file that is already gone"
  fi
fi

# --- (e7) THE SEED THAT SEPARATES A CORRECT FIX FROM A BROKEN ONE -------------------------
# No recovery at all: a lead opening the procedure of their own accord, where the marker is
# REQUIRED. A fix keyed on anything other than the satisfying call agrees with the correct one
# on (e6) and diverges only here.
reset_state "$P_REC"; rclean "$P_REC"
cp "$SNAP_PLAIN" "$P_REC/_bmad-output/pipeline-snapshot.md"
touch "$P_REC/_bmad-output/pipeline-paused.flag"
if [ "$(seq_read "$P_REC" "$P_REC/$STEP_HANDOFF")" = marker ]; then
  ok "(e7) with NO recovery in flight the same sequence DOES write the marker — a genuine initiation still arms"
else
  bad "(e7) a genuine handoff initiation no longer writes the marker. The suppression has swallowed the mandate rather than one distinguishable state, and the routing this hook exists to provide is gone: a compaction now sends the successor to the interrupted step instead of to the procedure"
fi

# --- (e8) A RECOVERY IN FLIGHT THAT HAS NOT REACHED ITS SECOND MANDATE --------------------
# THE SECOND DEFECT THE BREADCRUMB EXISTS FOR, and no arm above can see it. A lead that has
# satisfied only the FIRST mandated Read and then opens handoff.md of its own accord is a
# GENUINE INITIATION with `.recover-fired` still on disk. A suppression keyed on the marker's
# existence silences it and loses the routing; one keyed on the SATISFYING CALL does not,
# because no breadcrumb has been written yet.
reset_state "$P_REC"; rclean "$P_REC"
cp "$SNAP_PLAIN" "$P_REC/_bmad-output/pipeline-snapshot.md"
touch "$P_REC/_bmad-output/pipeline-paused.flag"
mkmarker "$P_REC"
rdrive "$P_REC" "$SESS_A" >/dev/null     # a recovery fires; mandate 1 is NOT satisfied
_E8_STAGE="$(cat "$P_REC/_bmad-output/.recover-gate-progress" 2>/dev/null || printf 'snapshot')"
if [ -f "$P_REC/_bmad-output/.recover-fired" ] && [ "$_E8_STAGE" != step ]; then
  ok "(e8-pre) a recovery is in flight and the gate is still at its FIRST mandate — the marker exists, no satisfying call has happened"
  if [ "$(seq_read "$P_REC" "$P_REC/$STEP_HANDOFF")" = marker ]; then
    ok "(e8) a voluntary open during that window still ARMS — the key is the satisfying call, not the marker's existence"
  else
    bad "(e8) a lead opening handoff.md while a recovery was in flight but UNSATISFIED was suppressed. That Read was compelled by nothing, so the suppression is keyed on 'a recovery exists' rather than on 'this Read is the one it demanded' — and losing the routing is the worse direction by this hook's own reasoning"
  fi
else
  bad "(e8-pre) could not build the in-flight-but-unsatisfied window (marker present? stage='$_E8_STAGE'), so (e8) would assert against a state that is not the one it names"
fi

# --- (e8g) THE GATE DOES NOT LET A FIRST-CALL handoff.md READ REACH THE ENTRY HOOK ----------
# (e8) drives the entry hook whatever the gate decided. This arm drives it ONLY when the gate
# ALLOWED, which is the sequence a consumer actually runs. The gate's snapshot stage allows a full
# step Read without advancing (BL-687), and that allow writes no breadcrumb -- so a handoff.md step
# Read let through there would reach the entry hook unmarked as compelled and arm key 1 from a Read
# the recovery mandated. The gate keeps that one Read denied; a gate that let it through fails here.
e8g_run() { # e8g_run <projdir> [hooksdir] -> pre:<why> | <deny|allow> <marker|no-marker>
  local proj="$1" hd="${2:-$HOOKS_DIR}" st dec g=deny
  reset_state "$proj"; rclean "$proj"
  cp "$SNAP_PLAIN" "$proj/_bmad-output/pipeline-snapshot.md"
  touch "$proj/_bmad-output/pipeline-paused.flag"
  mkmarker "$proj" "$hd"
  rdrive "$proj" "$SESS_A" "$hd" >/dev/null   # a recovery fires toward handoff.md; mandate 1 is NOT satisfied
  st="$(sed -n 's/^step_file=//p' "$proj/_bmad-output/.recover-fired" 2>/dev/null | head -1)"
  case "$st" in */steps/handoff.md|steps/handoff.md) ;; *) printf 'pre:step_file=%s' "${st:-<nothing>}"; return ;; esac
  [ -f "$proj/_bmad-output/.recover-gate-progress" ] && { printf 'pre:a stage file is already present'; return; }
  rm -f "$proj/_bmad-output/.handoff-in-progress"
  dec="$(gdrive "$proj" Read "$proj/$st" "$hd")"
  if ! gdenied "$dec"; then g=allow; edrive "$proj" Read "$proj/$st" "$hd" >/dev/null; fi
  if marker_at "$proj"; then printf '%s marker' "$g"; else printf '%s no-marker' "$g"; fi
}
_E8G="$(e8g_run "$P_REC")"
case "$_E8G" in
  pre:*) bad "(e8g-pre) not a first-call recovery toward handoff.md (${_E8G#pre:}), so (e8g) would measure nothing" ;;
  *' no-marker') ok "(e8g) driven gate-then-entry only when the gate allows, a first-call handoff.md Read during a recovery does not arm key 1 (gate: ${_E8G% *})"; B_e8g=1 ;;
  *) bad "(e8g) the gate ALLOWED a full Read of handoff.md before the snapshot Read, and the entry hook then armed key 1 from a Read the recovery compelled — the snapshot stage's step-Read allow writes no breadcrumb, so it must not cover handoff.md" ;;
esac
# The Read above is BOUNDED (the gate refuses an unbounded one at any size); both spellings must be denied here,
# and the gate's answer is asserted, not just the marker, so an allow that happened to leave no marker fails.
case "$_E8G" in
  'deny '*) ok "(e8g) the bounded handoff.md Read at stage snapshot is DENIED by the gate" ;;
  *) bad "(e8g) the bounded handoff.md Read at stage snapshot was not denied (${_E8G})" ;;
esac
_E8GU="$(GD_UNBOUNDED=1 e8g_run "$P_REC")"
case "$_E8GU" in
  'deny no-marker') ok "(e8g) the UNBOUNDED handoff.md Read at stage snapshot is also DENIED and arms nothing" ;;
  *) bad "(e8g) the unbounded handoff.md Read at stage snapshot answered '${_E8GU}', expected 'deny no-marker'" ;;
esac

# --- (e9) FAIL OPEN: a breadcrumb with no step_file key ----------------------------------
# Every unreadable or ambiguous input falls through and arms. The two errors are not
# symmetric: a marker written wrongly is a Stop guard the lead clears with `rm`, a marker
# MISSED while the lead really is mid-handoff loses the routing. WRITTEN DIRECTLY, because
# the gate cannot be driven into emitting a keyless breadcrumb -- it writes the key or nothing.
reset_state "$P_REC"
printf 'satisfied_at=2026-09-21T00:00:00Z\n' > "$P_REC/_bmad-output/.recover-satisfied"
if [ "$(seq_read "$P_REC" "$P_REC/$STEP_HANDOFF")" = marker ]; then
  ok "(e9) a breadcrumb carrying no step_file key FAILS OPEN to arming"
else
  bad "(e9) an ambiguous breadcrumb suppressed the arming. A marker written wrongly is cleared with rm; a marker missed loses the routing this hook exists to provide, so every unreadable input must arm"
fi

# --- (e10) THE BREADCRUMB IS ONE-SHOT ----------------------------------------------------
# It describes ONE call. Left on disk it would answer for a LATER Read of the same file, so a
# voluntary re-open moments after the mandated one would be read as the mandated one and
# silently fail to arm. The consumer deletes it as it reads it; this asserts that directly by
# running the sequence TWICE against a single breadcrumb.
reset_state "$P_REC"; rclean "$P_REC"
cp "$SNAP_PLAIN" "$P_REC/_bmad-output/pipeline-snapshot.md"
touch "$P_REC/_bmad-output/pipeline-paused.flag"
mkmarker "$P_REC"; arm_to_step "$P_REC" "$SESS_A"
# Every bounded handoff.md chunk at stage step carries a tool_use_id and the gate writes its PER-CALL breadcrumb
# `.recover-satisfied.<id>` BEFORE crediting it; the entry hook consumes only its own call's id. The first call
# is driven in two halves so the breadcrumb is observed on disk between the hooks.
_E10_DIR="$P_REC/_bmad-output"
rm -f "$_E10_DIR/.handoff-in-progress"
GD_ID=toolu_e10a gdrive "$P_REC" Read "$P_REC/$STEP_HANDOFF" >/dev/null
_E10_CRUMB=absent; [ -e "$_E10_DIR/.recover-satisfied.toolu_e10a" ] && _E10_CRUMB=present
GD_ID=toolu_e10a edrive "$P_REC" Read "$P_REC/$STEP_HANDOFF" >/dev/null
_E10_LEFT=absent; [ -e "$_E10_DIR/.recover-satisfied.toolu_e10a" ] && _E10_LEFT=present
_E10_FIRST=no-marker; [ -f "$_E10_DIR/.handoff-in-progress" ] && _E10_FIRST=marker
_E10_SECOND="$(GD_ID=toolu_e10b seq_read "$P_REC" "$P_REC/$STEP_HANDOFF")"
if [ "$_E10_CRUMB" = present ] && [ "$_E10_LEFT" = absent ] && [ "$_E10_FIRST" = no-marker ] && [ "$_E10_SECOND" = marker ]; then
  ok "(e10) the per-call breadcrumb exists after the gate, is CONSUMED by the entry hook (mandated Read suppressed), and an immediate re-open with a new tool_use_id arms"
  B_e10=1
else
  bad "(e10) breadcrumb after the gate '$_E10_CRUMB' (want present), left after the entry hook '$_E10_LEFT' (want absent), mandated Read '$_E10_FIRST' (want no-marker), re-open '$_E10_SECOND' (want marker). A breadcrumb left on disk answers for a later call, so a voluntary re-open right after the mandated one is read as the mandated one and silently fails to arm"
fi

# --- (e11) CONTROL FOR (e6): the SAME state, a DIFFERENT file read ------------------------
reset_state "$P_REC"; rclean "$P_REC"
cp "$SNAP_PLAIN" "$P_REC/_bmad-output/pipeline-snapshot.md"
touch "$P_REC/_bmad-output/pipeline-paused.flag"
mkmarker "$P_REC"; arm_to_step "$P_REC" "$SESS_A"
if [ "$(seq_read "$P_REC" "$P_REC/$STEP_IMPL")" = no-marker ]; then
  ok "(e11) control: in (e6)'s exact state, a Read of a DIFFERENT step file is also unmarked"
else
  bad "(e11) reading an ordinary step file in the suppressed state wrote the marker — the path match and the suppression are interacting, and (e6)'s silence cannot be attributed to either"
fi

# --- (e12) BOTH LAYOUTS ------------------------------------------------------------------
# The comparison is on the BASENAME UNDER ITS steps/ PARENT because the gate records a
# project-relative path while the Read may arrive absolute; a whole-path compare fails to
# suppress in exactly the layouts this hook spans. Driven on the CONSUMER tree, whose step
# files live under `.claude/`, with the breadcrumb written by the gate itself.
reset_state "$P_REC_CLAUDE"; rclean "$P_REC_CLAUDE"
cp "$SNAP_PLAIN" "$P_REC_CLAUDE/_bmad-output/pipeline-snapshot.md"
touch "$P_REC_CLAUDE/_bmad-output/pipeline-paused.flag"
mkmarker "$P_REC_CLAUDE"; arm_to_step "$P_REC_CLAUDE" "$SESS_A"
_E12_STEP="$(sed -n 's/^step_file=//p' "$P_REC_CLAUDE/_bmad-output/.recover-fired" 2>/dev/null | head -1)"
case "$_E12_STEP" in
  .claude/*)
    ok "(e12-pre) on the consumer tree the gate records a .claude/-spelled mandate ($_E12_STEP)"
    if [ "$(seq_read "$P_REC_CLAUDE" "$P_REC_CLAUDE/$STEP_HANDOFF_C")" = no-marker ]; then
      ok "(e12) the suppression holds in the INSTALLED layout, which is the only layout this hook runs in"
    else
      bad "(e12) the consumer layout did not suppress. The hook is comparing whole paths or is anchored on the distribution spelling, so on every installed tree a compaction still arms the Stop guard over a procedure that was never begun"
    fi
    ;;
  *)
    bad "(e12-pre) the consumer tree recorded step_file='${_E12_STEP:-<nothing>}', which is not consumer-spelled — the layout arm would assert about the distribution spelling twice"
    ;;
esac
# POSITIVE CONTROL for (e12): the same tree with no breadcrumb must still arm, or (e12) is a
# dead hook rather than a suppression.
reset_state "$P_REC_CLAUDE"; rclean "$P_REC_CLAUDE"
cp "$SNAP_PLAIN" "$P_REC_CLAUDE/_bmad-output/pipeline-snapshot.md"
touch "$P_REC_CLAUDE/_bmad-output/pipeline-paused.flag"
if [ "$(seq_read "$P_REC_CLAUDE" "$P_REC_CLAUDE/$STEP_HANDOFF_C")" = marker ]; then
  ok "  control: the same consumer tree with no breadcrumb DOES arm"
else
  bad "  the entry hook does not arm in the consumer tree even with no breadcrumb — (e12) is a dead hook, not a suppression"
fi

# --- (e13) THE BREADCRUMB IS PARSED AS KEY=VALUE, NEVER SOURCED --------------------------
# `.` on a file under the project directory executes whatever a consumer's tree put there,
# and this hook runs on EVERY Read. Seeded with a value that is a command substitution:
# sourcing it creates the canary, parsing it does not.
CANARY="$P_ENTRY/_bmad-output/.sourced-canary"
rm -f "$CANARY" "$P_ENTRY/_bmad-output/.handoff-in-progress"
printf 'step_file=$(touch %s)\n' "$CANARY" > "$P_ENTRY/_bmad-output/.recover-satisfied"
edrive "$P_ENTRY" Read "$P_ENTRY/$STEP_HANDOFF" >/dev/null
if [ -f "$CANARY" ]; then
  bad "(e13) the hook SOURCED .recover-satisfied — a file under the project directory, whose content a consumer's tree supplies, was executed as shell by a PostToolUse hook that runs on every Read"
else
  ok "(e13) the breadcrumb is parsed as key=value, never sourced (a command-substitution payload did not execute)"
fi
rm -f "$P_ENTRY/_bmad-output/.recover-satisfied" "$CANARY" "$P_ENTRY/_bmad-output/.handoff-in-progress"

# --- LEAD ONLY: a TEAMMATE's Read of steps/handoff.md arms nothing (A1, A2, A2b, A3) ------------
# The marker is project-wide, so a dispatched teammate's Read must neither write it NOR consume
# the lead's `.recover-satisfied` breadcrumb. PostToolUse carries a non-empty `agent_id` for a
# subagent's call and none for the lead's; a `claude --agent` lead carries `agent_type` and NO
# `agent_id` and is still the lead (A2b), which is what kills a key on `agent_id || agent_type`.
#
# A1 IS ABSENCE-SHAPED, so it is followed in the same tree by A2, the lead twin one property apart
# (no `agent_id`), which must create the marker -- a hook that died on load would score A1 for free.
# `tdrive` omits a key when its value is empty, so the lead payload carries no `agent_id` at all
# rather than an empty one.
tdrive() { # tdrive <projdir> <agent_id|-> <agent_type|-> <path> [hooksdir] -> hook exit code
  local proj="$1" aid="$2" aty="$3" fp="$4" hd="${5:-$HOOKS_DIR}"
  jq -nc --arg p "$fp" --arg i "$aid" --arg y "$aty" \
    '{tool_name:"Read",tool_input:{file_path:$p}}
     + (if $i == "-" then {} else {agent_id:$i} end)
     + (if $y == "-" then {} else {agent_type:$y} end)' \
  | CLAUDE_PROJECT_DIR="$proj" bash "$hd/ai-dlc-handoff-entry.sh" >/dev/null 2>&1
  printf '%s' "$?"
}
# tcase <projdir> <agent_id|-> <agent_type|-> <hooksdir> <breadcrumb: yes|no> -> "<marker|no-marker> <crumb|no-crumb> <rc>"
tcase() {
  local proj="$1" sd="$1/_bmad-output" rc
  mkdir -p "$sd"
  rm -f "$sd/.handoff-in-progress" "$sd/.recover-satisfied"
  [ "$5" = yes ] && printf 'step_file=steps/handoff.md\n' > "$sd/.recover-satisfied"
  rc="$(tdrive "$proj" "$2" "$3" "$proj/$STEP_HANDOFF" "$4")"
  local m=no-marker c=no-crumb
  [ -f "$sd/.handoff-in-progress" ] && m=marker
  [ -f "$sd/.recover-satisfied" ] && c=crumb
  rm -f "$sd/.handoff-in-progress" "$sd/.recover-satisfied"
  printf '%s %s %s' "$m" "$c" "$rc"
}
_a1="$(tcase "$P_ENTRY" agent-0123456789abcdef general-purpose "$HOOKS_DIR" no)"
_a2="$(tcase "$P_ENTRY" - - "$HOOKS_DIR" no)"
_a2b="$(tcase "$P_ENTRY" - general-purpose "$HOOKS_DIR" no)"
_a3="$(tcase "$P_ENTRY" agent-0123456789abcdef general-purpose "$HOOKS_DIR" yes)"
if [ "$_a1" = "no-marker no-crumb 0" ]; then
  ok "(A1) a TEAMMATE's Read (agent_id set) of steps/handoff.md -> no marker"; B_A1=1
else
  bad "(A1) a teammate's Read of steps/handoff.md gave '$_a1' — the lead's project-wide marker is armed by a dispatched subagent"
fi
if [ "$_a2" = "marker no-crumb 0" ]; then
  ok "(A2) the LEAD twin (no agent_id), same run, one property apart -> the marker EXISTS"; B_A2=1
else
  bad "(A2) the lead's Read gave '$_a2' — the hook no longer arms at all, so A1's absence is a dead hook rather than a guard"
fi
if [ "$_a2b" = "marker no-crumb 0" ]; then
  ok "(A2b) agent_type set and NO agent_id (a claude --agent lead) -> the marker EXISTS"; B_A2b=1
else
  bad "(A2b) a Read carrying agent_type and no agent_id gave '$_a2b' — the exit is keyed on agent_type, which a claude --agent LEAD also carries"
fi
if [ "$_a3" = "no-marker crumb 0" ]; then
  ok "(A3) a teammate's Read leaves the lead's .recover-satisfied breadcrumb ON DISK"; B_A3=1
else
  bad "(A3) a teammate's Read with a breadcrumb present gave '$_a3' — the exit sits after the breadcrumb block, so the teammate consumed the breadcrumb the lead's compelled Read still needs"
fi

stamp_at() { if [ -f "$(HC "$P_DISK")" ]; then echo present; else echo absent; fi; }
# arm_c5k: five consecutive blocks inside the rapid window release the BACKOFF; the stamp must stay
# ABSENT because the backoff allows a Stop it could not verify. `drive` clears the counter, so the
# hook is driven raw here: the counter is the subject.
arm_c5k() { local i=0; dsetup; snap_at "$P_DISK"; rm -f "$(HC "$P_DISK")" "$P_DISK/_bmad-output/.driver/handoff"
           while [ "$i" -lt 5 ]; do
             jq -nc --arg t "$T_REQ_OK" --arg s "$SESS_A" '{transcript_path:$t,session_id:$s}' \
               | CLAUDE_PROJECT_DIR="$P_DISK" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" bash "$1/ai-dlc-continue.sh" >/dev/null 2>&1
             i=$((i + 1))
           done
           [ "$(stamp_at)" = absent ]; }

# (c5k) THE BACKOFF BRANCH DOES NOT STAMP, on the shipped hook: five consecutive blocks inside the
#       rapid window release the backoff, and the Stop it allows is one it could not verify.
if arm_c5k "$HOOKS_DIR"; then
  ok "(c5k) five consecutive Stops inside the rapid window release the BACKOFF and still write NO stamp -- the backoff allows a Stop it could not verify"; B_c5k=1
else
  bad "(c5k) the BACKOFF branch wrote a completion stamp -- a handoff that failed every arm recorded itself complete"
fi

# =============================================================================
# EQUIVALENCE: the in-process answer is the command line's, byte for byte (stdout, stderr, exit), on a refusing and a
# passing input of each hook. One real start per cell, tagged FXCELL=<id> (cells.decl). ai-dlc-continue.sh is a `cli`
# subject (guarded); ai-dlc-recover.sh carries no source guard, so its two starts are `e2e` cells.
# =============================================================================
EQ="$ROOT/.eqv"; mkdir -p "$EQ"
eqv() { # eqv <cell-id> <hook> <projdir> <payload-file> <want-pattern> <want-label>
  local id="$1" hook="$2" proj="$3" pl="$4" want="$5" lbl="$6" k
  for k in ip cl; do
    reset_state "$proj"; rm -f "$proj/_bmad-output/handoff-guard-state.txt"
    [ "$hook" != "$FX_REC" ] || [ ! -f "$SNAP_PLAIN" ] || [ "$want" = QUIET ] || cp "$SNAP_PLAIN" "$proj/_bmad-output/pipeline-snapshot.md"
    if [ "$k" = ip ]; then
      ( CLAUDE_PROJECT_DIR="$proj" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" bash "$hook" < "$pl" > "$EQ/$id.$k.out" 2> "$EQ/$id.$k.err"; echo "$?" > "$EQ/$id.$k.rc" )
    else
      ( CLAUDE_PROJECT_DIR="$proj" AI_DLC_PAUSE_ROUTING_SCHEMA="$SCHEMA" FXCELL="$id" command bash "$hook" < "$pl" > "$EQ/$id.$k.out" 2> "$EQ/$id.$k.err"; echo "$?" > "$EQ/$id.$k.rc" )
    fi
    # each emission opens with a provenance marker carrying a per-emission nonce; only the nonce is normalised
    sed 's/nonce=[0-9a-f]*/nonce=N/' "$EQ/$id.$k.out" > "$EQ/$id.$k.outn"
  done
  if [ "$want" = QUIET ]; then
    [ ! -s "$EQ/$id.ip.out" ] || { bad "(eqv $id) $lbl: the in-process run was expected to emit nothing"; return; }
  else
    grep -q -- "$want" "$EQ/$id.ip.out" || { bad "(eqv $id) $lbl: the in-process run lacks '$want' -- the cell would compare two empty answers"; return; }
  fi
  if cmp -s "$EQ/$id.ip.outn" "$EQ/$id.cl.outn" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"; then
    ok "(eqv $id) $lbl: the in-process answer is the command line's (stdout, stderr, exit $(cat "$EQ/$id.cl.rc"))"
  else
    bad "(eqv $id) $lbl: the in-process answer differs from the CLI's: rc ip=$(cat "$EQ/$id.ip.rc") cl=$(cat "$EQ/$id.cl.rc")"
  fi
}
jq -nc --arg t "$T_REQ_NOBLK" --arg s "$SESS_A" '{transcript_path:$t,session_id:$s}' > "$EQ/stop-block.json"
jq -nc --arg t "$T_REQ_OK" --arg s "$SESS_A" '{transcript_path:$t,session_id:$s}' > "$EQ/stop-allow.json"
jq -nc --arg s "$SESS_A" '{source:"compact",session_id:$s}' > "$EQ/rec-compact.json"
jq -nc --arg s "$SESS_A" '{source:"startup",session_id:$s}' > "$EQ/rec-startup.json"
eqv cli-cont-block "$FX_CONT" "$P_UNPUSHED" "$EQ/stop-block.json" '"decision"' "continue, refusing input (a Stop with no resume block on an unpushed tree)"
eqv cli-cont-allow "$FX_CONT" "$P_NOGIT" "$EQ/stop-allow.json" QUIET "continue, passing input (not a git repo)"
eqv e2e-rec-ctx "$FX_REC" "$P_REC" "$EQ/rec-compact.json" 'additionalContext' "recover, a compact SessionStart over a snapshot"
eqv e2e-rec-quiet "$FX_REC" "$P_REC" "$EQ/rec-startup.json" QUIET "recover, a non-compact SessionStart"

rm -rf "$ROOT"
echo ""
report_end handoff-completion-assertion
