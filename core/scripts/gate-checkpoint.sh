#!/usr/bin/env bash
set -euo pipefail

# gate-checkpoint.sh -- record and read back a gate's PER-CHECK verdicts, so a gate
# interrupted by a compaction resumes instead of restarting.
#
# THE DEFECT THIS CLOSES, MEASURED. The first durable write in the whole gate protocol
# is Check 12's gate-log append, and the manifest orders Check 12 after 1, 2, 2a, 3, 4
# and 7. Every verdict before it -- roughly twenty script-arm validator runs and every
# lead-evaluated check -- exists only in the conversation. A compaction discards all of
# it, the recovery protocol re-arms the identical work, and the gate never reaches its
# own terminal write. Measured on the reference consumer: eight compactions in one
# sitting, four of them inside one planning gate, `gate-log.md` with no row for that
# sprint, `gate-metrics.jsonl` stopping at the previous sprint, and no adjudication
# verdict written -- the gate ran four times and recorded nothing, four times.
#
# WHAT IT IS AND IS NOT. It is a resume ledger keyed on `gate_nonce`, and the nonce is
# what makes it safe: a verdict is valid ONLY for the dispatch that produced it, and the
# gate file already says a re-dispatch mints a fresh nonce and re-derives every check
# from current state. So this file can never carry a verdict forward across a
# re-dispatch -- a fresh nonce reads an empty ledger by construction. It is NOT a second
# gate log: `gate-log.md` stays the human and audit trail and Check 12 still writes it.
# A ledger row is a note that a check was EVALUATED at this nonce, never evidence that
# the gate passed.
#
# WHY A RECORD OF INTENT WOULD BE WORTHLESS HERE. This repo has measured the failure of
# deciding from a record a program writes from its own input: the in-flight marker that
# `apply.sh` stamps from its own argument before any write, compared against that same
# argument, is a tautology that fired over a tree still at base. So `record` refuses to
# write a row that names no verdict, and the verdict vocabulary is closed -- a row is
# written by the act of REACHING a verdict, never by entering the check.
#
# usage:
#   gate-checkpoint.sh --nonce <gate_nonce> open            # at nonce mint: THIS is the live gate
#   gate-checkpoint.sh --nonce <gate_nonce> record <check-id> <PASS|FAIL|SKIP|PENDING> [note]
#   gate-checkpoint.sh --nonce <gate_nonce> done            # comma list for gate-slice --done
#   gate-checkpoint.sh --nonce <gate_nonce> list            # the rows, tab separated
#   gate-checkpoint.sh --nonce <gate_nonce> close           # gate finished: no gate is live
#   gate-checkpoint.sh --nonce <gate_nonce> clear           # drop this nonce's ledger
#   gate-checkpoint.sh current                              # the OPEN nonce, or nothing
#   gate-checkpoint.sh --self-probe
#   [--root PATH]  project root (default: walked up)
#
# exit:
#   0  the operation completed
#   2  a refusal -- bad usage, unknown verdict token, unwritable state dir, no nonce,
#      or an `open` whose nonce is not `<gate_type>-$(date -u +%Y%m%dT%H%M%SZ)`.
#      Never 1: this script renders no verdict about the gate, so it has no failure arm
#      a caller could confuse with a gate FAIL.
#
# `current` READS THE OPEN MARKER, NEVER A DIRECTORY LISTING. The first form picked the
# newest ledger by mtime, and an adversary reproduced two ways that narrows the WRONG gate:
# a fully-settled ledger from the previous sprint, still on disk because nothing ever
# clears one, is the newest file until the new gate's first `record` lands -- and a
# compaction in that window resumes the new gate with every check "already settled";
# and a concurrent session's ledger of another gate type, newer by mtime, narrows this
# gate on the ids the two types share. So entering a gate is an explicit act: `open`
# writes `<nonce>` to `.gate-checkpoint/OPEN` at nonce mint, before any check runs, and
# `close` removes it. `current` answers from that file alone. A settled ledger with no
# OPEN marker is history, and a resume that finds no marker resumes no gate.
#
# WRITES ARE SERIALISED. The adjudicator runs `run_in_background` while the lead records
# its own checks, so two writers at one nonce is the shipped operating pattern, not an
# edge case; the first form lost 14 of 20 concurrent rows with every writer exiting 0.
# A `mkdir` lock is the portable primitive -- this box has no flock(1) -- held across the
# read-filter-append-rename, with a bounded wait and a refusal past it.
#
# ONLY `PASS` AND `SKIP` NARROW A RESUME, AND THAT IS THE LOAD-BEARING ASYMMETRY. A
# `FAIL` sends the gate to Gate Failure, which is a path that must re-read the check it
# failed; a `PENDING` is by definition unfinished. Narrowing on either would let a
# resume skip the check whose state the gate still has to act on. `done` therefore emits
# the settled set only, and the two vocabularies are separate on purpose.
#
# A GATE CLOSED AT A STEP ENTRY RE-OPENS ON ITS NEXT `record` OR `done`. ai-dlc-handoff-entry.sh
# closes the OPEN marker when the lead whole-reads another step without a `close`, and
# ai-dlc-recover.sh's transcript backstop closes one at a compaction. Each writes
# `.gate-checkpoint/LEFT` = `<nonce><TAB><step left to><TAB><the gate's own step>[<TAB>noted]` only
# after its close succeeded (the backstop's already noted, since it emits the section itself). A leave is not
# always an ending: on the measured lead transcripts 7 of 9 leaves were followed by a return, and
# every return that CONTINUED its gate did so with `record`, `done`, or a `list` followed by
# `record` within two minutes. So `record` and `done` at the nonce LEFT names, with no OPEN marker,
# write OPEN back, restore STEP to the gate's own step (LEFT's field 3) keeping the session STEP
# carries -- writing nothing when there is no STEP, no session in it, or no gate step in LEFT --
# and remove LEFT. `list` does NOT re-open: gate-transition.sh runs it on every
# story close, and a re-open there would resurrect a finished gate. A Read of gate-validation.md
# is not a return either -- both returns made only by such Reads were followed by a fresh `open`.
# The re-open is a no-clobber link, so a concurrent `open` of a fresh nonce is never overwritten.
# `open` removes LEFT (a fresh gate supersedes the left one) and `close` at LEFT's nonce removes it
# whether or not a marker was open. `open` still overwrites an open marker silently: a refusal
# there would break a re-dispatch, which mints a fresh nonce and opens it.

# --- AI_DLC_ROOT ------------------------------------------------------------
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. install.sh splits what
# shares a parent in core/, so no fixed hop count from $0 reaches the root in both
# layouts. core/fixtures/validator-path-resolution asserts both agree.
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
  echo "ERROR: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------

NONCE=""; ROOT=""; ACTION=""; PROBE=0
ARGS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --nonce) NONCE="${2:-}"; shift 2 ;;
    --root)  ROOT="${2:-}"; shift 2 ;;
    --self-probe) PROBE=1; shift ;;
    -h|--help) sed -n '/^# usage:/,/^#      a caller could confuse/p' "$0" >&2; exit 2 ;;
    open|close|record|done|list|clear|current)
      ACTION="$1"; shift
      while [ $# -gt 0 ]; do ARGS="${ARGS}${ARGS:+$(printf '\037')}$1"; shift; done
      ;;
    *) echo "gate-checkpoint: unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ "$PROBE" = "1" ]; then
  # THE PROBE RUNS BEFORE ANY REAL LEDGER AND FIRES IN BOTH DIRECTIONS. A checkpoint
  # that reports a clean read without first proving it can refuse has established that
  # it ran, not that it discriminates. Built under `mktemp`, never a real state dir.
  # The record seam is the probe's own and is set only per writer below; an inherited one
  # would seam Directions 1-9 and 12, whose verdicts are about the unseamed path.
  unset AI_DLC_GATE_CHECKPOINT_PROBE_SEAM
  _pr="$(mktemp -d)"; mkdir -p "${_pr}/_bmad-output"
  _me="$0"
  _n="planning-19700101T000000Z"
  _fail=0

  # Direction 1: a recorded PASS comes back in `done`.
  bash "$_me" --root "$_pr" --nonce "$_n" record 7 PASS "probe" >/dev/null 2>&1 || _fail=1
  _d="$(bash "$_me" --root "$_pr" --nonce "$_n" done 2>/dev/null || true)"
  [ "$_d" = "7" ] || { echo "gate-checkpoint SELF-PROBE FAIL: recorded PASS 7 read back as '${_d}'." >&2; exit 2; }

  # Direction 2: a FAIL must NOT narrow a resume. Silence here would be the acquittal
  # that lets a resume skip the check the gate still has to act on.
  bash "$_me" --root "$_pr" --nonce "$_n" record 12 FAIL "probe" >/dev/null 2>&1 || _fail=1
  _d="$(bash "$_me" --root "$_pr" --nonce "$_n" done 2>/dev/null || true)"
  [ "$_d" = "7" ] || { echo "gate-checkpoint SELF-PROBE FAIL: a FAIL narrowed the resume set ('${_d}')." >&2; exit 2; }

  # Direction 3: a PENDING must not narrow either.
  bash "$_me" --root "$_pr" --nonce "$_n" record 14 PENDING >/dev/null 2>&1 || _fail=1
  _d="$(bash "$_me" --root "$_pr" --nonce "$_n" done 2>/dev/null || true)"
  [ "$_d" = "7" ] || { echo "gate-checkpoint SELF-PROBE FAIL: a PENDING narrowed the resume set ('${_d}')." >&2; exit 2; }

  # Direction 4: SKIP narrows -- a check that correctly self-skipped is settled.
  bash "$_me" --root "$_pr" --nonce "$_n" record 9 SKIP "not a UI epic" >/dev/null 2>&1 || _fail=1
  _d="$(bash "$_me" --root "$_pr" --nonce "$_n" done 2>/dev/null || true)"
  [ "$_d" = "7,9" ] || { echo "gate-checkpoint SELF-PROBE FAIL: SKIP did not settle ('${_d}')." >&2; exit 2; }

  # Direction 5: A FRESH NONCE READS EMPTY. This is the arm that makes the whole
  # mechanism safe, and it is the one a caller would never notice was broken.
  _d="$(bash "$_me" --root "$_pr" --nonce "planning-19700101T000001Z" done 2>/dev/null || true)"
  [ -z "$_d" ] || { echo "gate-checkpoint SELF-PROBE FAIL: a fresh nonce inherited rows ('${_d}')." >&2; exit 2; }

  # Direction 6: an unknown verdict token must REFUSE. A checkpoint that accepts any
  # string records "EVALUATED" for a check nobody judged.
  if bash "$_me" --root "$_pr" --nonce "$_n" record 3 PROBABLY >/dev/null 2>&1; then
    echo "gate-checkpoint SELF-PROBE FAIL: an unknown verdict token was accepted." >&2; exit 2
  fi

  # Direction 7: a record with NO verdict must refuse -- a row of intent is a tautology.
  if bash "$_me" --root "$_pr" --nonce "$_n" record 3 >/dev/null 2>&1; then
    echo "gate-checkpoint SELF-PROBE FAIL: a verdictless row was accepted." >&2; exit 2
  fi

  # Direction 8: re-recording one check does not duplicate it, and last wins.
  bash "$_me" --root "$_pr" --nonce "$_n" record 7 SKIP "re-evaluated" >/dev/null 2>&1 || _fail=1
  _c="$(bash "$_me" --root "$_pr" --nonce "$_n" list 2>/dev/null | awk -F'\t' '$1=="7"' | wc -l | tr -d ' ')"
  [ "$_c" = "1" ] || { echo "gate-checkpoint SELF-PROBE FAIL: check 7 has ${_c} rows, expected 1." >&2; exit 2; }

  # Direction 9: `current` answers from the OPEN marker. Newest-by-mtime was the first
  # form and it narrowed the wrong gate two ways; both are the probe.
  _cur="$(bash "$_me" --root "$_pr" current 2>/dev/null || true)"
  [ -z "$_cur" ] || { echo "gate-checkpoint SELF-PROBE FAIL: current named '${_cur}' with no gate opened." >&2; exit 2; }
  bash "$_me" --root "$_pr" --nonce "$_n" open >/dev/null 2>&1 || _fail=1
  _cur="$(bash "$_me" --root "$_pr" current 2>/dev/null || true)"
  [ "$_cur" = "$_n" ] || { echo "gate-checkpoint SELF-PROBE FAIL: current read '${_cur}' after open, expected '${_n}'." >&2; exit 2; }
  # (a) a NEWER ledger by mtime that was never opened must not become current.
  sleep 1
  bash "$_me" --root "$_pr" --nonce "story-19700101T000002Z" record 1 PASS >/dev/null 2>&1 || _fail=1
  _cur="$(bash "$_me" --root "$_pr" current 2>/dev/null || true)"
  [ "$_cur" = "$_n" ] || { echo "gate-checkpoint SELF-PROBE FAIL: an unopened newer ledger became current ('${_cur}')." >&2; exit 2; }
  # (b) close removes the marker; a settled ledger left on disk is history, not a resume.
  bash "$_me" --root "$_pr" --nonce "$_n" close >/dev/null 2>&1 || _fail=1
  _cur="$(bash "$_me" --root "$_pr" current 2>/dev/null || true)"
  [ -z "$_cur" ] || { echo "gate-checkpoint SELF-PROBE FAIL: current named '${_cur}' after close." >&2; exit 2; }
  [ -f "${_pr}/_bmad-output/.gate-checkpoint/${_n}.tsv" ] || { echo "gate-checkpoint SELF-PROBE FAIL: close deleted the ledger; it must only drop the marker." >&2; exit 2; }
  # (c) opening a second nonce replaces the first: one live gate per tree.
  bash "$_me" --root "$_pr" --nonce "$_n" open >/dev/null 2>&1 || _fail=1
  bash "$_me" --root "$_pr" --nonce "planning-19700101T000003Z" open >/dev/null 2>&1 || _fail=1
  _cur="$(bash "$_me" --root "$_pr" current 2>/dev/null || true)"
  [ "$_cur" = "planning-19700101T000003Z" ] || { echo "gate-checkpoint SELF-PROBE FAIL: a second open did not replace the first ('${_cur}')." >&2; exit 2; }

  # Direction 10: THE LOCK SERIALISES THE READ-MODIFY-WRITE, shown by a FORCED interleaving
  # that waits on events and never on time (BL-1006, BL-868). Writer A reads and holds at
  # seam point (1), between its read and its rename; only then is writer B started, and the
  # probe reads B's FIRST event. Under the lock B cannot read while A holds it, so that event
  # is `L fb`, seam point (2), and both rows land. A writer that appends unlocked reads the
  # same stale ledger A read, reports `R fb` first, and whichever rename lands second erases
  # the other's row: one row of two, at any load, because no step here is decided by a clock.
  # A writer's exit is an event too, and a seamed writer never waits unannounced (see the seam
  # in `record`, and its one stated limit), so a seam whose event line is gone refuses here
  # rather than hangs.
  _ps="$(mktemp -d)"; _pf="$(mktemp -d)"; mkdir -p "${_pf}/_bmad-output"
  printf '%s\n' "$$" > "${_ps}/pid"; : > "${_ps}/hold.fa"; : > "${_ps}/hold.fb"
  mkfifo "${_ps}/ev"; exec 3<>"${_ps}/ev"
  _gw() { # _gw <id>: one seamed writer, then its exit as an event
    _wr=0
    AI_DLC_GATE_CHECKPOINT_PROBE_SEAM="$_ps" bash "$_me" --root "$_pf" --nonce "$_n" record "$1" PASS >/dev/null 2>&1 || _wr=$?
    printf 'X %s %s\n' "$1" "$_wr" >> "${_ps}/ev"
  }
  _gw fa & _pa=$!
  read -r _ea <&3
  if [ "$_ea" != "R fa" ]; then
    : > "${_ps}/go.fa"; wait "$_pa"; exec 3<&-
    echo "gate-checkpoint SELF-PROBE FAIL: writer A's first event was '${_ea}', expected 'R fa' -- seam point (1) never held it between its read and its rename, so no interleaving was forced." >&2; exit 2
  fi
  _gw fb & _pb=$!
  read -r _eb <&3
  : > "${_ps}/go.fa"; : > "${_ps}/go.fb"
  wait "$_pa" "$_pb"; exec 3<&-
  _rows="$(bash "$_me" --root "$_pf" --nonce "$_n" list 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$_eb" != "L fb" ] || [ "$_rows" != "2" ]; then
    echo "gate-checkpoint SELF-PROBE FAIL: while writer A held between its read and its rename, writer B's first event was '${_eb}' (expected 'L fb', waiting on the lock) and the ledger kept ${_rows} of 2 rows -- the read-modify-write is not serialised." >&2; exit 2
  fi

  # Direction 11: twenty concurrent writers lose nothing. Seamed, so a writer waits on the
  # holder's release instead of a 200-try clock: the count cannot move with load.
  _pc="$(mktemp -d)"; mkdir -p "${_pc}/_bmad-output"
  _ps="$(mktemp -d)"; printf '%s\n' "$$" > "${_ps}/pid"
  _i=1
  while [ "$_i" -le 20 ]; do
    AI_DLC_GATE_CHECKPOINT_PROBE_SEAM="$_ps" bash "$_me" --root "$_pc" --nonce "$_n" record "c${_i}" PASS >/dev/null 2>&1 &
    _i=$(( _i + 1 ))
  done
  wait
  _rows="$(bash "$_me" --root "$_pc" --nonce "$_n" list 2>/dev/null | wc -l | tr -d ' ')"
  [ "$_rows" = "20" ] || { echo "gate-checkpoint SELF-PROBE FAIL: 20 concurrent records landed ${_rows} rows." >&2; exit 2; }

  # Direction 12: UNSEAMED, the shipped bound stands. A lock held by hand (never by a racing
  # writer) and `sleep` shadowed by an exported function that returns at once and logs its
  # argument: the writer must try 200 times, sleep 0.05 between tries (199 sleeps), refuse with
  # the shipped text, exit 2 and write no ledger. Deterministic, it costs no real sleeping, and
  # the function forks nothing, so the arm's cost is the writer's own 200 `mkdir` attempts.
  _pl="$(mktemp -d)"; _lk="${_pl}/_bmad-output/.gate-checkpoint/${_n}.tsv.lock"; mkdir -p "$_lk"
  _sb="$(mktemp -d)"; : > "${_sb}/slept"
  GCK_PROBE_SLEPT="${_sb}/slept"; export GCK_PROBE_SLEPT
  sleep() { printf '%s\n' "$1" >> "$GCK_PROBE_SLEPT"; }
  export -f sleep
  _wr=0
  _err="$(bash "$_me" --root "$_pl" --nonce "$_n" record h PASS 2>&1 >/dev/null)" || _wr=$?
  unset -f sleep; unset GCK_PROBE_SLEPT
  _l1="$(printf '%s\n' "$_err" | head -1)"
  _sl="$(wc -l < "${_sb}/slept" | tr -d ' ')"; _sv="$(sort -u "${_sb}/slept" | tr '\n' ' ')"
  if [ "$_wr" != "2" ] || [ "$_l1" != "gate-checkpoint: FAIL -- could not take ${_lk} after 200 tries." ] \
     || [ "$_sl" != "199" ] || [ "$_sv" != "0.05 " ] || [ -e "${_pl}/_bmad-output/.gate-checkpoint/${_n}.tsv" ]; then
    echo "gate-checkpoint SELF-PROBE FAIL: an unseamed writer against a held lock exited ${_wr} after ${_sl} sleep(s) of '${_sv}' and said '${_l1}' -- the shipped bound (200 tries, sleep 0.05, refusal, exit 2, no write) moved." >&2; exit 2
  fi

  # Direction 13: `open` refuses a non-canonical nonce and leaves the open gate unchanged;
  # a canonical one (a hyphenated gate type included) opens; `record` is not gated.
  if bash "$_me" --root "$_pr" --nonce "implementation-1970-01-01T000004Z" open >/dev/null 2>&1; then
    echo "gate-checkpoint SELF-PROBE FAIL: a hyphenated-date nonce opened." >&2; exit 2
  fi
  _cur="$(bash "$_me" --root "$_pr" current 2>/dev/null || true)"
  [ "$_cur" = "planning-19700101T000003Z" ] || { echo "gate-checkpoint SELF-PROBE FAIL: a refused open moved current to '${_cur}'." >&2; exit 2; }
  bash "$_me" --root "$_pr" --nonce "sprint-review-19700101T000005Z" open >/dev/null 2>&1 \
    || { echo "gate-checkpoint SELF-PROBE FAIL: a canonical sprint-review nonce was refused." >&2; exit 2; }
  bash "$_me" --root "$_pr" --nonce "probe-free-form" record 1 PASS >/dev/null 2>&1 \
    || { echo "gate-checkpoint SELF-PROBE FAIL: a non-canonical record was refused; only open is gated." >&2; exit 2; }

  # Direction 14: a gate LEFT at a step entry re-opens on `record` and on `done` at LEFT's
  # nonce, and on nothing else. Each world starts closed, with LEFT naming _ln.
  _ln="story-19700101T000006Z"; _lo="story-19700101T000007Z"
  _left_world() {
    _lw="$(mktemp -d)"; mkdir -p "${_lw}/_bmad-output/.gate-checkpoint"
    printf '%s\t%s\t%s\n' "$_ln" "dev-story" "create-story" > "${_lw}/_bmad-output/.gate-checkpoint/LEFT"
    printf '%s\t%s\n' "dev-story" "sess-a" > "${_lw}/_bmad-output/.gate-checkpoint/STEP"
  }
  _tab="$(printf '\t')"
  _left_world
  bash "$_me" --root "$_lw" --nonce "$_ln" record c1 PASS >/dev/null 2>&1 || _fail=1
  _cur="$(bash "$_me" --root "$_lw" current 2>/dev/null || true)"
  [ "$_cur" = "$_ln" ] && [ ! -f "${_lw}/_bmad-output/.gate-checkpoint/LEFT" ] \
    || { echo "gate-checkpoint SELF-PROBE FAIL: record at LEFT's nonce did not re-open it (current '${_cur}')." >&2; exit 2; }
  # Direction 15: the re-open puts STEP back on the gate's own step, keeping STEP's session.
  _stp="$(cat "${_lw}/_bmad-output/.gate-checkpoint/STEP" 2>/dev/null || true)"
  [ "$_stp" = "create-story${_tab}sess-a" ] \
    || { echo "gate-checkpoint SELF-PROBE FAIL: the re-open did not restore STEP to the gate's step (STEP '${_stp}')." >&2; exit 2; }
  _left_world
  bash "$_me" --root "$_lw" --nonce "$_ln" done >/dev/null 2>&1 || _fail=1
  _cur="$(bash "$_me" --root "$_lw" current 2>/dev/null || true)"
  _stp="$(cat "${_lw}/_bmad-output/.gate-checkpoint/STEP" 2>/dev/null || true)"
  [ "$_cur" = "$_ln" ] && [ ! -f "${_lw}/_bmad-output/.gate-checkpoint/LEFT" ] && [ "$_stp" = "create-story${_tab}sess-a" ] \
    || { echo "gate-checkpoint SELF-PROBE FAIL: done at LEFT's nonce did not re-open it with STEP restored (current '${_cur}', STEP '${_stp}')." >&2; exit 2; }
  _left_world
  rm -f "${_lw}/_bmad-output/.gate-checkpoint/STEP"
  bash "$_me" --root "$_lw" --nonce "$_ln" record c1 PASS >/dev/null 2>&1 || _fail=1
  _cur="$(bash "$_me" --root "$_lw" current 2>/dev/null || true)"
  [ "$_cur" = "$_ln" ] && [ ! -f "${_lw}/_bmad-output/.gate-checkpoint/STEP" ] \
    || { echo "gate-checkpoint SELF-PROBE FAIL: with no STEP the re-open failed or invented one (current '${_cur}')." >&2; exit 2; }
  _left_world
  bash "$_me" --root "$_lw" --nonce "$_lo" record c1 PASS >/dev/null 2>&1 || _fail=1
  _cur="$(bash "$_me" --root "$_lw" current 2>/dev/null || true)"
  _stp="$(cat "${_lw}/_bmad-output/.gate-checkpoint/STEP" 2>/dev/null || true)"
  [ -z "$_cur" ] && [ -f "${_lw}/_bmad-output/.gate-checkpoint/LEFT" ] && [ "$_stp" = "dev-story${_tab}sess-a" ] \
    || { echo "gate-checkpoint SELF-PROBE FAIL: a record at ANOTHER nonce re-opened, cleared LEFT or moved STEP (current '${_cur}', STEP '${_stp}')." >&2; exit 2; }
  bash "$_me" --root "$_lw" --nonce "$_ln" list >/dev/null 2>&1 || _fail=1
  _cur="$(bash "$_me" --root "$_lw" current 2>/dev/null || true)"
  [ -z "$_cur" ] && [ -f "${_lw}/_bmad-output/.gate-checkpoint/LEFT" ] \
    || { echo "gate-checkpoint SELF-PROBE FAIL: list re-opened a left gate (current '${_cur}'); gate-transition.sh runs list on every story close." >&2; exit 2; }
  # Direction 16: open, and close in both of its branches, clear LEFT.
  _left_world
  bash "$_me" --root "$_lw" --nonce "$_lo" open >/dev/null 2>&1 || _fail=1
  [ ! -f "${_lw}/_bmad-output/.gate-checkpoint/LEFT" ] \
    || { echo "gate-checkpoint SELF-PROBE FAIL: open left a stale LEFT behind." >&2; exit 2; }
  _left_world
  bash "$_me" --root "$_lw" --nonce "$_ln" close >/dev/null 2>&1 || _fail=1
  [ ! -f "${_lw}/_bmad-output/.gate-checkpoint/LEFT" ] \
    || { echo "gate-checkpoint SELF-PROBE FAIL: close with no marker open kept LEFT at its nonce." >&2; exit 2; }
  _left_world
  printf '%s\n' "$_ln" > "${_lw}/_bmad-output/.gate-checkpoint/OPEN"
  bash "$_me" --root "$_lw" --nonce "$_ln" close >/dev/null 2>&1 || _fail=1
  [ ! -f "${_lw}/_bmad-output/.gate-checkpoint/LEFT" ] && [ ! -f "${_lw}/_bmad-output/.gate-checkpoint/OPEN" ] \
    || { echo "gate-checkpoint SELF-PROBE FAIL: close of the open marker kept LEFT at its nonce." >&2; exit 2; }

  [ "$_fail" = "0" ] || { echo "gate-checkpoint SELF-PROBE FAIL: a well-formed record returned non-zero." >&2; exit 2; }
  echo "gate-checkpoint SELF-PROBE PASS: PASS/SKIP settle, FAIL/PENDING do not, a fresh nonce reads empty, bad verdicts and verdictless rows refuse, re-records replace, current reads the OPEN marker (not mtime) and open/close move it, open refuses a non-canonical nonce, a forced read-rename interleaving keeps both rows, 20 concurrent records land 20 rows, an unseamed writer keeps the shipped 200-try refusal, a LEFT gate re-opens on record and done at its nonce and not at another nonce or on list, the re-open restores STEP to the gate's own step (and invents none), open and close clear LEFT."
  exit 0
fi

[ -n "$ROOT" ] || ROOT="$AI_DLC_ROOT"
STATE_DIR="${ROOT}/${AI_DLC_STATE_DIR:-_bmad-output}"
LEDGER_DIR="${STATE_DIR}/.gate-checkpoint"

if [ -z "$ACTION" ]; then
  echo "gate-checkpoint: FAIL -- no action. One of: open, close, record, done, list, clear, current." >&2
  exit 2
fi

OPEN_MARKER="${LEDGER_DIR}/OPEN"
LEFT_MARKER="${LEDGER_DIR}/LEFT"

# LEFT is one line, `<nonce><TAB><step left to><TAB><the gate's own step>[<TAB>noted]`, written after a
# close by ai-dlc-handoff-entry.sh (M1) or by ai-dlc-recover.sh's transcript backstop (already noted).
# The nonce LEFT names, or nothing.
_left_nonce() {
  [ -f "$LEFT_MARKER" ] || return 0
  head -1 "$LEFT_MARKER" 2>/dev/null | awk -F'\t' '{print $1}'
}

# The gate's own step LEFT names (field 3), or nothing.
_left_gate_step() {
  [ -f "$LEFT_MARKER" ] || return 0
  head -1 "$LEFT_MARKER" 2>/dev/null | awk -F'\t' '{print $3}'
}

# A RE-OPEN PUTS STEP BACK ON THE GATE'S OWN STEP. The close that wrote LEFT moved STEP to the step the
# lead left to, so with OPEN restored and STEP left there the lead's next whole Read of the gate's own
# step reads as another leave and closes the re-opened gate. STEP becomes `<gate step><TAB><session>`,
# keeping the session the current STEP carries; with no STEP, no session in it, or no gate step in
# LEFT nothing is written. Written to a sibling temp and renamed, as every STEP writer does.
_restore_step_from_left() {
  local _g _s="" _ss="" _sf="${LEDGER_DIR}/STEP"
  _g="$(_left_gate_step)"
  case "$_g" in ""|-|noted) return 0 ;; esac
  [ -f "$_sf" ] || return 0
  IFS="$(printf '\t')" read -r _s _ss < "$_sf" 2>/dev/null || true
  [ -n "$_ss" ] || return 0
  { printf '%s\t%s\n' "$_g" "$_ss" > "${_sf}.$$" && mv "${_sf}.$$" "$_sf"; } 2>/dev/null || rm -f "${_sf}.$$" 2>/dev/null
  return 0
}

# Remove LEFT when it names this nonce.
_clear_left_at_nonce() {
  [ "$(_left_nonce)" = "$NONCE" ] && rm -f "$LEFT_MARKER"
  return 0
}

# Re-open the gate this nonce LEFT at a step entry: no OPEN marker, LEFT names this nonce.
_reopen_if_left() {
  [ -f "$OPEN_MARKER" ] && return 0
  [ "$(_left_nonce)" = "$NONCE" ] || return 0
  local _t="${OPEN_MARKER}.$$"
  printf '%s\n' "$NONCE" > "$_t" 2>/dev/null || { rm -f "$_t"; return 0; }
  if ln "$_t" "$OPEN_MARKER" 2>/dev/null; then
    rm -f "$_t"
    _restore_step_from_left
    _clear_left_at_nonce
    printf 'gate-checkpoint: re-opened %s (left at step entry)\n' "$NONCE" >&2
  else
    rm -f "$_t"
  fi
  return 0
}

if [ "$ACTION" = "current" ]; then
  # The open marker, or nothing. A directory with ledgers and no marker is a tree whose
  # last gate finished; "no gate is live" is an answer and exits 0.
  if [ -f "$OPEN_MARKER" ]; then
    _o="$(head -1 "$OPEN_MARKER" 2>/dev/null | tr -d '[:space:]')"
    [ -n "$_o" ] && printf '%s\n' "$_o"
  fi
  exit 0
fi

if [ -z "$NONCE" ]; then
  echo "gate-checkpoint: FAIL -- --nonce is required." >&2
  echo "  The nonce IS the ledger's identity: a verdict is valid only for the dispatch that" >&2
  echo "  produced it, and a nonce-less ledger would carry verdicts across a re-dispatch," >&2
  echo "  which the gate file forbids in as many words." >&2
  exit 2
fi

# The nonce reaches a filename, so it is constrained rather than trusted. A nonce
# carrying a slash or a leading dot would write outside the ledger directory; refused
# here rather than sanitised, because a silently-rewritten nonce is a ledger a resume
# looks for under the wrong name and reads as empty.
case "$NONCE" in
  *[!A-Za-z0-9._-]*|.*|"")
    echo "gate-checkpoint: FAIL -- nonce ${NONCE} is not a bare [A-Za-z0-9._-] token." >&2
    echo "  It names a file. A rewritten nonce would read back as a ledger with no rows," >&2
    echo "  which no reader can tell from a gate at its first check." >&2
    exit 2 ;;
esac

LEDGER="${LEDGER_DIR}/${NONCE}.tsv"

# `open` ADMITS ONLY THE CANONICAL NONCE, BEFORE ANY WRITE. The nonce is the stem of the
# adjudication verdict path, and `validate-gate-adjudication.sh --series` orders a gate's
# passes by it and refuses a nonce off the schema's `patterns.gate_nonce`. A lead that mints
# `implementation-2026-10-11T083048Z` (from `date -u +%Y-%m-%dT…`) used to open it here with
# exit 0, so the first program to notice was the one judging the finished gate. NONCE_RE is
# that schema pattern with `\d` spelled `[0-9]` (ERE has no `\d`); core/fixtures/gate-resume
# compares the two texts. Only `open` refuses: `record`/`done`/`list`/`close`/`clear` key a
# ledger that already exists, and a resume must still be able to read one opened earlier.
# FALSE-POSITIVE SET, measured on the reference consumer's real history: 94 of 94 opens and
# 87 of 87 checkpoint ledgers carry the strict form except the 2 non-canonical opens this
# refusal exists for -- both true positives. The set reached zero by keying on the schema's
# closed gate-type list rather than any `<word>-` prefix, which would admit
# `deploy-validate-s304-20260822T005500Z`.
NONCE_RE='^(planning|story|implementation|sprint-review|retro)-[0-9]{8}T[0-9]{6}Z$'
_require_canonical_nonce() {
  if [[ "$NONCE" =~ $NONCE_RE ]]; then return 0; fi
  echo "gate-checkpoint: FAIL -- refusing to open non-canonical nonce ${NONCE}." >&2
  echo "  The canonical form is <gate_type>-YYYYMMDDTHHMMSSZ, gate_type one of planning, story," >&2
  echo "  implementation, sprint-review, retro (e.g. implementation-20260715T140322Z)." >&2
  echo "  Mint it as: <gate_type>-\$(date -u +%Y%m%dT%H%M%SZ) -- no hyphens or colons in the time." >&2
  echo "  Nothing was written; the previously open gate (if any) is unchanged." >&2
  exit 2
}

case "$ACTION" in
  open)
    _require_canonical_nonce
    mkdir -p "$LEDGER_DIR" 2>/dev/null || { echo "gate-checkpoint: FAIL -- cannot create ${LEDGER_DIR}." >&2; exit 2; }
    _t="${OPEN_MARKER}.$$"
    printf '%s\n' "$NONCE" > "$_t" && mv "$_t" "$OPEN_MARKER" \
      || { rm -f "$_t"; echo "gate-checkpoint: FAIL -- cannot write ${OPEN_MARKER}." >&2; exit 2; }
    rm -f "$LEFT_MARKER"
    printf 'gate-checkpoint: opened %s\n' "$NONCE" >&2
    ;;

  close)
    # Only the nonce that is open may close it: a stale caller closing a newer gate's
    # marker would make that gate's next resume read as "no gate in flight".
    if [ -f "$OPEN_MARKER" ]; then
      _o="$(head -1 "$OPEN_MARKER" 2>/dev/null | tr -d '[:space:]')"
      if [ "$_o" = "$NONCE" ]; then
        rm -f "$OPEN_MARKER"
        printf 'gate-checkpoint: closed %s\n' "$NONCE" >&2
      else
        echo "gate-checkpoint: FAIL -- ${NONCE} is not the open gate (${_o} is)." >&2
        exit 2
      fi
    fi
    _clear_left_at_nonce
    ;;

  record)
    # Split the collected args back out on the unit separator. Done this way because the
    # Bash tool's shell is zsh, where an unquoted `$var` is not word-split, so a loop
    # written for bash iterates once over the whole string.
    _id="$(printf '%s' "$ARGS" | awk -F'\037' '{print $1}')"
    _v="$(printf '%s' "$ARGS" | awk -F'\037' '{print $2}')"
    _note="$(printf '%s' "$ARGS" | awk -F'\037' '{for(i=3;i<=NF;i++){printf "%s%s",(i>3?" ":""),$i}}')"

    if [ -z "$_id" ]; then
      echo "gate-checkpoint: FAIL -- record needs a check id." >&2; exit 2
    fi
    if [ -z "$_v" ]; then
      echo "gate-checkpoint: FAIL -- record needs a verdict for check ${_id}." >&2
      echo "  A row naming no verdict would record that the check was ENTERED, which is a" >&2
      echo "  record of intent: comparing it against the fact that the gate started is a" >&2
      echo "  tautology, and a resume would skip a check nobody judged." >&2
      exit 2
    fi
    case "$_v" in
      PASS|FAIL|SKIP|PENDING) : ;;
      *) echo "gate-checkpoint: FAIL -- unknown verdict '${_v}' for check ${_id}." >&2
         echo "  The vocabulary is closed: PASS FAIL SKIP PENDING. An open vocabulary lets a" >&2
         echo "  row say something no reader can act on, and 'done' would have to guess." >&2
         exit 2 ;;
    esac
    case "$_id" in
      *[!A-Za-z0-9._-]*) echo "gate-checkpoint: FAIL -- check id '${_id}' is not a bare token." >&2; exit 2 ;;
    esac

    mkdir -p "$LEDGER_DIR" 2>/dev/null || {
      echo "gate-checkpoint: FAIL -- cannot create ${LEDGER_DIR}." >&2; exit 2; }

    _now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    _tmp="${LEDGER}.$$"
    _lock="${LEDGER}.lock"
    # Last-wins on the check id, and the whole read-filter-append-rename is serialised
    # under a mkdir lock: the rename alone is atomic, the sequence around it is not, and
    # two writers interleaving at the read both rewrite from the same stale copy. Bounded
    # wait; a lock held past it is refused loudly rather than stolen, because a stolen
    # lock is the race with one more step. Tabs are the field separator and the note is
    # stripped of them for that reason.
    _note="$(printf '%s' "$_note" | tr '\t\n' '  ')"
    # THE PROBE SEAM (BL-868). Set ONLY by --self-probe, on its own writers, to a scratch dir
    # holding `pid` (the probe's pid). Unset, every line below it runs exactly as without it.
    # Set, it does three things and nothing else: point (1) appends `R <id>` to `<seam>/ev`
    # after the read, before the rename, and holds there while `<seam>/hold.<id>` exists
    # until `<seam>/go.<id>` appears; point (2) appends `L <id>` on the FIRST failed mkdir;
    # and the lock wait is taken off the 200-try bound, waiting on the holder's release
    # instead, so a probe verdict never depends on how fast twenty writers are scheduled.
    # A probe that dies releases its writers: each one exits 2 once `pid` is gone.
    # A SEAMED WRITER NEVER WAITS UNANNOUNCED. The probe waits only on events, so a writer
    # that held or waited without first telling it would leave both blocked with no clock to
    # end it. Each wait is therefore licensed by `_seam_ev`, which only the SAME statement
    # that appends its event sets: delete either event line and the writer exits 2 at the
    # wait instead, the probe reads that exit as the writer's event and refuses. The limit,
    # stated: an edit that keeps `&& _seam_ev=...` while dropping only the append before it
    # still waits silently; no event-only construction can tell an event that was never
    # sent from one not sent YET, and a clock is the thing this seam exists to remove.
    _seam="${AI_DLC_GATE_CHECKPOINT_PROBE_SEAM:-}"; _seam_ev=""
    _tries=0
    until mkdir "$_lock" 2>/dev/null; do
      # PROBE-SEAM(2) begin
      if [ -n "$_seam" ]; then
        [ "$_tries" -gt 0 ] || { printf 'L %s\n' "$_id" >> "${_seam}/ev" && _seam_ev=L; }
        [ "$_seam_ev" = L ] || exit 2
        _tries=$(( _tries + 1 ))
        kill -0 "$(cat "${_seam}/pid")" 2>/dev/null || exit 2
        sleep 0.05
        continue
      fi
      # PROBE-SEAM(2) end
      _tries=$(( _tries + 1 ))
      if [ "$_tries" -ge 200 ]; then
        echo "gate-checkpoint: FAIL -- could not take ${_lock} after ${_tries} tries." >&2
        echo "  Another writer holds it, or a crashed one left it behind. Remove it only" >&2
        echo "  after confirming no gate-checkpoint process is live." >&2
        exit 2
      fi
      sleep 0.05
    done
    { [ -f "$LEDGER" ] && awk -F'\t' -v id="$_id" '$1 != id' "$LEDGER"
      printf '%s\t%s\t%s\t%s\n' "$_id" "$_v" "$_now" "$_note"
    } > "$_tmp" 2>/dev/null || { rmdir "$_lock" 2>/dev/null; echo "gate-checkpoint: FAIL -- cannot write ${LEDGER}." >&2; rm -f "$_tmp"; exit 2; }
    # PROBE-SEAM(1) begin
    if [ -n "$_seam" ]; then
      printf 'R %s\n' "$_id" >> "${_seam}/ev" && _seam_ev=R
      while [ -e "${_seam}/hold.${_id}" ] && [ ! -e "${_seam}/go.${_id}" ]; do
        [ "$_seam_ev" = R ] || { rmdir "$_lock" 2>/dev/null; rm -f "$_tmp"; exit 2; }
        kill -0 "$(cat "${_seam}/pid")" 2>/dev/null || { rmdir "$_lock" 2>/dev/null; rm -f "$_tmp"; exit 2; }
        sleep 0.05
      done
    fi
    # PROBE-SEAM(1) end
    mv "$_tmp" "$LEDGER" || { rmdir "$_lock" 2>/dev/null; echo "gate-checkpoint: FAIL -- cannot replace ${LEDGER}." >&2; rm -f "$_tmp"; exit 2; }
    rmdir "$_lock" 2>/dev/null || true
    printf 'gate-checkpoint: %s recorded %s in %s\n' "$_id" "$_v" "$LEDGER" >&2
    _reopen_if_left
    ;;

  done)
    # PASS and SKIP only. See the header: a FAIL routes to Gate Failure, which re-reads
    # the check it failed, and a PENDING is unfinished. Emitting either would narrow a
    # resume past a check the gate still has to act on.
    _reopen_if_left
    if [ -f "$LEDGER" ]; then
      awk -F'\t' '$2 == "PASS" || $2 == "SKIP" { printf "%s%s", (n++ ? "," : ""), $1 } END { if (n) printf "\n" }' "$LEDGER"
    fi
    ;;

  list)
    if [ -f "$LEDGER" ]; then
      cat "$LEDGER"
    fi
    ;;

  clear)
    rm -f "$LEDGER"
    printf 'gate-checkpoint: cleared the ledger for %s\n' "$NONCE" >&2
    ;;
esac
