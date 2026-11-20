#!/usr/bin/env bash
# suite-admission.sh -- the one call a seat makes to run the consumer's suite when
# the box may be saturated.
#
#   suite-admission.sh [--ticket ID] [--sprint N] [--capture FILE] -- <suite command...>
#   suite-admission.sh --probe-only
#
# The consumer declares an admission probe in .claude/settings.json "env" as
# AI_DLC_SUITE_ADMISSION_PROBE (a shell command; exit 0 = admit, 3 = refuse, any
# other exit = probe error). The reconcile never writes it. With NO declaration
# this script runs the suite directly: no lock, no probe, no refusal path.
#
# With a declaration: one box-wide single-flight lock (a fixed per-user path) is
# taken, the probe runs, and on refusal the call waits inside ONE slice
# (AI_DLC_SUITE_ADMISSION_SLICE seconds, default 480, always under the 10-minute
# foreground cap), then returns QUEUED. The seat re-invokes with the same --ticket.
# It never backgrounds the call and never loops by hand.
#
# Exit codes: the suite's own exit when admitted and run; 75 QUEUED (re-invoke);
# 76 ESCALATE (refusal budget spent; prints one Rule 12 HARD_BLOCK entry for the lead to append);
# 3 --probe-only refusal; 2 usage or probe error, or ESCALATE reached with no --sprint N (the entry
# header must carry [S<N>], the token validate-escalation-resolution.sh scopes on; the sprint is
# PASSED IN, never read from the snapshot here: I104 allows three copies of that reader).
#
# ONE ESCALATION PER CAUSE: the first ticket to reach ESCALATE takes the box-wide record
# $STATE/escalation-open (an atomic mkdir; its ticket file names the entry). Any OTHER ticket reaching
# ESCALATE while it is open prints a reference to that entry, no new entry, and exits 76. The
# record is cleared by the next admitted run (or `rm -rf $STATE/escalation-open` by the lead).
#
# CAPTURE (--capture FILE): line 1 `$ <replayable command>`, `head: <sha>`, the
# counts line, the last 40 lines; the full log lives outside git (LOG_DIR).
set -u

MAX_REFUSALS=6          # slices a ticket may end refused before ESCALATE; declared once, here
QUEUED_RC=75
ESCALATE_RC=76
STATE="${AI_DLC_SUITE_ADMISSION_DIR:-$HOME/.cache/ai-dlc/suite-admission}"
LOG_DIR="${AI_DLC_SUITE_LOG_DIR:-$STATE/logs}"
SLICE="${AI_DLC_SUITE_ADMISSION_SLICE:-480}"
POLL="${AI_DLC_SUITE_ADMISSION_POLL:-15}"
PROBE="${AI_DLC_SUITE_ADMISSION_PROBE:-}"

ticket=""; capture=""; probe_only=0; sprint=""
while [ $# -gt 0 ]; do
  case "$1" in
    --ticket) ticket="${2:-}"; shift 2 ;;
    --sprint) sprint="${2:-}"; shift 2 ;;
    --capture) capture="${2:-}"; shift 2 ;;
    --probe-only) probe_only=1; shift ;;
    --) shift; break ;;
    *) echo "usage: suite-admission.sh [--ticket ID] [--sprint N] [--capture FILE] -- CMD... | --probe-only" >&2; exit 2 ;;
  esac
done

run_probe() { bash -c "$PROBE" >/dev/null 2>&1; }

if [ "$probe_only" = 1 ]; then
  [ -n "$PROBE" ] || { echo "SUITE-ADMISSION: NO-PROBE (no probe declared)"; exit 0; }
  run_probe; prc=$?
  case "$prc" in
    0) echo "SUITE-ADMISSION: ADMIT"; exit 0 ;;
    3) echo "SUITE-ADMISSION: REFUSED (the declared probe refuses a suite run now)"; exit 3 ;;
    *) echo "SUITE-ADMISSION: PROBE-ERROR rc=$prc" >&2; exit 2 ;;
  esac
fi

[ $# -gt 0 ] || { echo "suite-admission.sh: no suite command after --" >&2; exit 2; }

run_suite() {
  if [ -z "$capture" ]; then "$@"; return $?; fi
  mkdir -p "$LOG_DIR" || return 2
  local log="$LOG_DIR/suite-$(date -u +%Y%m%dT%H%M%SZ)-$$.log" rc cmd line counts
  "$@" >"$log" 2>&1; rc=$?
  cmd="$(printf '%q ' "$@")"
  counts="$(grep -E '[0-9]+ (passed|failed)|[0-9]+ tests? ' "$log" | tail -1)"
  [ -n "$counts" ] || counts="exit=$rc lines=$(wc -l <"$log" | tr -d ' ')"
  {
    printf '$ %s\n' "${cmd% }"
    printf 'head: %s\n' "$(git rev-parse HEAD 2>/dev/null || echo unknown)"
    printf '%s\n' "$counts"
    tail -40 "$log"
    printf 'full log: %s\n' "$log"
  } >"$capture"
  cat "$capture"
  return "$rc"
}

if [ -z "$PROBE" ]; then run_suite "$@"; exit $?; fi

mkdir -p "$STATE/tickets" || exit 2
[ -n "$ticket" ] || ticket="t$(date -u +%Y%m%dT%H%M%SZ)-$$"
case "$ticket" in */*|"") echo "suite-admission.sh: bad ticket" >&2; exit 2 ;; esac
echo "SUITE-ADMISSION: TICKET $ticket"   # first output line, before any wait: a cut-off call still leaves it
tfile="$STATE/tickets/$ticket.refusals"
n=0; [ -f "$tfile" ] && n="$(cat "$tfile")"
case "$n" in ''|*[!0-9]*) n=0 ;; esac
# ESCALATE: print one Rule 12 HARD_BLOCK entry (escalations.md format) for the lead to append to
# docs/escalations/pending.md. A seat cannot write that protected path; no second record file exists.
escalate() {
  local rec="$STATE/escalation-open" opened
  case "$sprint" in ''|*[!0-9]*)
    echo "SUITE-ADMISSION: ESCALATE ticket=$ticket needs --sprint <N> (the entry header must carry [S<N>]); re-invoke with --ticket $ticket --sprint <N>" >&2; exit 2 ;;
  esac
  if ! mkdir "$rec" 2>/dev/null; then
    opened="$(cat "$rec/ticket" 2>/dev/null)"
    if [ -n "$opened" ] && [ "$opened" != "$ticket" ]; then
      echo "SUITE-ADMISSION: ESCALATE ticket=$ticket -- the open escalation for ticket $opened already covers this cause; no new entry (the lead's entry [SUITE-ADMISSION] [S$(cat "$rec/sprint" 2>/dev/null)] [$opened] stands)"
      exit "$ESCALATE_RC"
    fi
  else
    echo "$ticket" >"$rec/ticket"; echo "$sprint" >"$rec/sprint"
  fi
  printf '## [SUITE-ADMISSION] [S%s] [%s] - %s\n' "$sprint" "$ticket" "$(date -u +%Y-%m-%dT%H:%MZ)"
  printf '**Status:** HARD_BLOCK\n**Blocker type:** missing requirement\n'
  printf '**Context:** Running the suite through suite-admission.sh; the consumer-declared admission probe refused %s consecutive slices.\n' "$MAX_REFUSALS"
  printf '**Evidence observed:** probe `%s` refused %s slices for ticket %s; command: %s\n' "$PROBE" "$MAX_REFUSALS" "$ticket" "$(printf '%q ' "$@")"
  printf '**Assertion (beyond evidence):** none -- assertion equals evidence.\n'
  printf '**Decision/Question:** Wait longer, free capacity, or run the suite without admission?\n'
  printf '**Options:** (Recommended) free capacity then re-invoke; wait; run without admission.\n**Impact if skipped:** the suite run, and the story that needs it, does not happen.\n'
  echo "SUITE-ADMISSION: ESCALATE ticket=$ticket (append the entry above to docs/escalations/pending.md)"
  exit "$ESCALATE_RC"
}

if [ "$n" -ge "$MAX_REFUSALS" ]; then escalate "$@"; fi

LOCK="$STATE/lock"
held=0
release() { [ "$held" = 1 ] && rm -rf "$LOCK"; held=0; }
trap 'release' EXIT
trap 'release; exit 143' INT TERM

take_lock() {
  if mkdir "$LOCK" 2>/dev/null; then echo $$ >"$LOCK/pid"; held=1; return 0; fi
  local p; p="$(cat "$LOCK/pid" 2>/dev/null)"
  if [ -n "$p" ] && ! kill -0 "$p" 2>/dev/null; then
    # Stale: its recorded pid is dead. The rename lets exactly one reclaimer win.
    if mv "$LOCK" "$LOCK.stale.$$" 2>/dev/null; then
      rm -rf "$LOCK.stale.$$"
      if mkdir "$LOCK" 2>/dev/null; then echo $$ >"$LOCK/pid"; held=1; return 0; fi
    fi
  fi
  return 1
}

deadline=$(( $(date +%s) + SLICE ))
state=queued
while :; do
  if take_lock; then
    run_probe; prc=$?
    case "$prc" in
      0) state=admitted; break ;;
      3) release; state=refused ;;
      *) release; echo "SUITE-ADMISSION: PROBE-ERROR rc=$prc" >&2; exit 2 ;;
    esac
  else
    state=busy
  fi
  [ "$(date +%s)" -ge "$deadline" ] && break
  sleep "$POLL"
done

if [ "$state" = admitted ]; then rm -f "$tfile"; rm -rf "$STATE/escalation-open"; run_suite "$@"; exit $?; fi

# Slice over without admission: only a probe refusal spends the budget; a held lock does not.
if [ "$state" = refused ]; then
  n=$((n + 1)); echo "$n" >"$tfile"
  if [ "$n" -ge "$MAX_REFUSALS" ]; then
    escalate "$@"
  fi
fi
echo "SUITE-ADMISSION: QUEUED ticket=$ticket reason=$state refusals=$n/$MAX_REFUSALS (re-invoke with --ticket $ticket)"
exit "$QUEUED_RC"
