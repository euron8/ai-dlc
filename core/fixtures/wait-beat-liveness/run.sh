#!/usr/bin/env bash
# wait-beat-liveness — the bounded join must be able to tell a SLOW teammate from
# one that already went idle, and its WAITING line must not repeat verbatim.
#
# THE DEFECT THIS ADDRESSES. `wait-for-deliverable.sh` had exactly two things to say
# about a path: `WAITING ... not yet delivered` and `DELIVERED`. Neither carries any
# information about whether the dispatched teammate is still working. A teammate that
# finished its real work, went idle, and wrote its answer to a path the join was not
# watching therefore produced BYTE-IDENTICAL output, beat after beat, to a teammate
# genuinely still in progress. Reproduced S306: two teammates had both gone idle, the
# lead re-armed the same beat twice against an unchanging false negative, and it
# stopped only because the operator asked whether the wait was still appropriate. The
# manual liveness check that question prompted showed both idle immediately.
#
# THE GENERAL SHAPE. Any cause of a teammate finishing without satisfying the watched
# path — a crash after partial delivery, a role that returns text instead of a file, a
# path typo in either direction — produces that same silent-forever symptom. So this
# fixture is not about idleness; it is about the beat having a THIRD thing to say.
#
# WHAT MAKES THE FIX POSSIBLE AT ALL. The subject is a shell script and cannot call
# the lead's agent-listing tool. It does not need to: the harness exports
# CLAUDE_CODE_SESSION_ID into every Bash subprocess and appends one transcript per
# teammate under $HOME/.claude/projects/<slug>/<session>/subagents/*.jsonl. Those
# mtimes ARE the liveness signal. Every arm below is about the three answers that
# sensor can give — UNAVAILABLE, a live turn, and quiet past the threshold — and about
# the one hazard that spans them: two of those three must never collapse into one.
#
# THIS FIXTURE'S PROBE TREES ARE SYNTHETIC AND THAT IS DELIBERATE. It never reads the
# operator's real ~/.claude. Every teammate directory below is built under mktemp and
# reached through AI_DLC_TEAMMATE_DIR, except section 9, whose whole subject is the
# auto-resolution path — and that one builds a synthetic HOME rather than using the
# real one, because an arm that passes only on the machine that wrote it is an arm
# that cannot fail anywhere else.

set -uo pipefail

# HERMETIC — scrub the operator's tuning BEFORE this fixture sets its own (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
SUBJ="$(pick "$HERE/../../scripts/wait-for-deliverable.sh" \
             "$HERE/../../../scripts/ai-dlc/wait-for-deliverable.sh" \
             "$HERE/../../../core/scripts/wait-for-deliverable.sh")"
[ -n "$SUBJ" ] || { echo "FIXTURE ERROR: cannot locate wait-for-deliverable.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/wait-for-deliverable.sh"
# --shard-header's checker is the subject's SIBLING in both layouts, so it is found beside the
# resolved subject -- the same directory, no walk (I33).
MERGE="$(dirname "$SUBJ")/merge-adversarial-shards.sh"
[ -f "$MERGE" ] || { echo "FIXTURE ERROR: merge-adversarial-shards.sh is not beside $SUBJ" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/merge-adversarial-shards.sh"
# --dispatch reads its id prefixes from this sibling's DISPATCH_ID_PREFIXES (sections 18-19).
GRAMMAR="$(dirname "$SUBJ")/validate-adversarial-convergence.sh"
[ -f "$GRAMMAR" ] || { echo "FIXTURE ERROR: validate-adversarial-convergence.sh is not beside $SUBJ" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/validate-adversarial-convergence.sh"
# Section 26 sources the start-time helper the subject sources, from beside the subject.
[ -f "$(dirname "$SUBJ")/wfd-start-of.sh" ] || { echo "FIXTURE ERROR: wfd-start-of.sh is not beside $SUBJ" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/wfd-start-of.sh"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
# PRE-WRAP CONSUMER GATE (BL-878): a consumer one pull behind carries this fixture with a subject that predates the
# in-process wrap, and loading it would run its whole body. Neither half is SKIP (FIXTURE BROKEN in the distribution,
# exit 0 on a consumer); exactly one half FAILS; an unreadable subject is FIXTURE ERROR.
grep -qxF 'wfd_beat_main() {' "$SUBJ"; _wg1=$?
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$SUBJ"; _wg2=$?
[ "$_wg1" -le 1 ] && [ "$_wg2" -le 1 ] || { echo "FIXTURE ERROR: cannot read $SUBJ (grep exit $_wg1/$_wg2)" >&2; exit 2; }
case "$_wg1$_wg2" in
  00) : ;;
  11) echo "SKIP: wait-beat-liveness: $SUBJ predates the in-process wrap"; fx_skip_exit "$HERE" ;;
  *) bad "$SUBJ carries one half of the in-process wrap (wfd_beat_main line: rc $_wg1, column-0 source guard: rc $_wg2) -- a respelled subject this fixture cannot drive"
     report_end wait-beat-liveness ;;
esac
broken() { printf 'wait-beat-liveness: FIXTURE BROKEN — %s\n' "$1" >&2; exit 2; }

TMPROOT="$(mktemp -d)" || broken "mktemp failed"
trap 'rm -rf "$TMPROOT"' EXIT
BEATOUT="$TMPROOT/beat.out"

# ---------------------------------------------------------------------------
# THE INJECTED CLOCK. A waiting beat polls `sleep "$POLL"` until a wall-clock DEADLINE, so every
# beat that does not deliver cost its whole quantum in real seconds, and the settle window
# (`now - recorded > SETTLE`) could close only by real time passing. Neither is the subject's
# behaviour under test; both were the fixture's runtime. So the subject runs with a `date` and a
# `sleep` first on its PATH that keep a VIRTUAL clock per world: `date +%s` answers real time
# plus the world's offset, and `sleep N` (whole seconds) adds N to the offset and returns at
# once. The subject is unedited -- the shims are the same PATH lookup its every call already
# makes. A world is the subject's AI_DLC_PROJECT_ROOT; it is ON only while `$WBL_CLOCK_DIR/<root
# with / as _>` exists (fx_clock_on). Every other call -- the fixture's own, a world switched off,
# a fractional sleep, any other `date` form -- execs the real binary. Concurrent beats (a lease
# holder handing off to a live sibling, sections 18b and 21b) run on the world's clock too, ordered
# by the per-beat poll gate (beat_gate); only section 20, whose beats block on a FIFO before any
# poll, keeps the real clock (fx_clock_off), and nothing there is bounded by it.
#
# ONE CLOCK, BOTH SIDES. Whatever the fixture stamps INTO a clocked world (a transcript turn, a
# round epoch) is read from the same offset (fx_now), never from the real clock, so a comparison
# never skews one side only. A file the subject must see as written AT the virtual now is given
# that mtime explicitly (fx_settime), because a real write carries a real mtime.
#
# AN EVENT ON A POLL. `<clock file>.onsleep`, when present, is sourced by the sleep shim after
# it advances the offset: a writer that used to race the poll cadence from the background (the
# churning seat, the delivering teammate) is now an event the subject's own poll triggers, once
# per poll, with no process and no wall clock.
# ---------------------------------------------------------------------------
# A child of this fixture (section 12's --run-one) inherits the parent's shim dir first on PATH, so
# it takes the REAL binaries the parent resolved rather than resolving its parent's shims.
WBL_REAL_DATE="${WBL_REAL_DATE:-$(command -v date)}"; WBL_REAL_SLEEP="${WBL_REAL_SLEEP:-$(command -v sleep)}"; WBL_BASH="$(command -v bash)"
[ -n "$WBL_REAL_DATE" ] && [ -n "$WBL_REAL_SLEEP" ] && [ -n "$WBL_BASH" ] || broken "cannot resolve date/sleep/bash for the clock shims"
WBL_CLOCK_DIR="$TMPROOT/clock"; WBL_CLOCK_BIN="$TMPROOT/clockbin"
mkdir -p "$WBL_CLOCK_DIR" "$WBL_CLOCK_BIN" || broken "cannot create the clock dirs"
{ printf '#!%s\n' "$WBL_BASH"
  printf 'if [ "$#" -eq 1 ] && [ "$1" = "+%%s" ] && [ -n "${AI_DLC_PROJECT_ROOT:-}" ] && [ -n "${WBL_CLOCK_DIR:-}" ]; then\n'
  printf '  f_="$WBL_CLOCK_DIR/${AI_DLC_PROJECT_ROOT//\\//_}"\n'
  printf '  if [ -f "$f_" ]; then o_=0; read -r o_ < "$f_"; read -r r_ < "$f_.base"; printf "%%s\\n" "$(( r_ + o_ ))"; exit 0; fi\n'
  printf 'fi\n'
  printf 'exec "$WBL_REAL_DATE" "$@"\n'
} > "$WBL_CLOCK_BIN/date" || broken "cannot write the date shim"
{ printf '#!%s\n' "$WBL_BASH"
  printf 'if [ "$#" -eq 1 ] && [ -n "${AI_DLC_PROJECT_ROOT:-}" ] && [ -n "${WBL_CLOCK_DIR:-}" ]; then\n'
  printf '  case "$1" in ""|*[!0-9]*) ;; *)\n'
  printf '    f_="$WBL_CLOCK_DIR/${AI_DLC_PROJECT_ROOT//\\//_}"\n'
  printf '    if [ -f "$f_" ]; then o_=0; read -r o_ < "$f_"; printf "%%s" "$(( o_ + $1 ))" > "$f_"\n'
  printf '      read -r r_ < "$f_.base"; n_=$(( r_ + o_ + $1 ))\n'
  printf '      fx_vtouch() { touch -t "$("$WBL_REAL_DATE" -r "$n_" +%%Y%%m%%d%%H%%M.%%S 2>/dev/null || "$WBL_REAL_DATE" -d "@$n_" +%%Y%%m%%d%%H%%M.%%S)" "$1"; }\n'
  printf '      [ -f "$f_.onsleep" ] && . "$f_.onsleep"; exit 0; fi ;;\n'
  printf '  esac\n'
  printf 'fi\n'
  printf 'exec "$WBL_REAL_SLEEP" "$@"\n'
} > "$WBL_CLOCK_BIN/sleep" || broken "cannot write the sleep shim"
chmod +x "$WBL_CLOCK_BIN/date" "$WBL_CLOCK_BIN/sleep" || broken "cannot make the clock shims executable"
export WBL_REAL_DATE WBL_REAL_SLEEP WBL_CLOCK_DIR
PATH="$WBL_CLOCK_BIN:$PATH"; export PATH
fx_clock_file() { printf '%s/%s' "$WBL_CLOCK_DIR" "$(printf '%s' "$1" | tr / _)"; }
fx_clock_on()  { printf '0' > "$(fx_clock_file "$1")" && "$WBL_REAL_DATE" +%s > "$(fx_clock_file "$1").base" || broken "cannot start the clock for $1"; }
# A world on the REAL clock also drops the shim dir from PATH: each shim call is a bash start, and a real-time poll
# loop makes a timing-dependent number of them, so the invocation budget would drift between runs. With the shim
# dir off PATH the subject's date and sleep are the real binaries (not bash starts). fx_shims_on restores it; the
# driver restores it before every case.
fx_shims_on()  { case ":$PATH:" in *":$WBL_CLOCK_BIN:"*) ;; *) PATH="$WBL_CLOCK_BIN:$PATH" ;; esac; export PATH; }
fx_clock_off() { rm -f "$(fx_clock_file "$1")" "$(fx_clock_file "$1").onsleep" "$(fx_clock_file "$1").base"; PATH="${PATH//"$WBL_CLOCK_BIN":/}"; export PATH; }
fx_offset() { fo_=0; [ -f "$(fx_clock_file "$1")" ] && read -r fo_ < "$(fx_clock_file "$1")"; printf '%s' "${fo_:-0}"; }
fx_now() { fn_b_=""; [ -f "$(fx_clock_file "$1").base" ] && read -r fn_b_ < "$(fx_clock_file "$1").base"; printf '%s' "$(( ${fn_b_:-$("$WBL_REAL_DATE" +%s)} + $(fx_offset "$1") ))"; }
fx_advance() {  # $1 = world, $2 = seconds -- the clock moves; nothing sleeps
  [ -f "$(fx_clock_file "$1")" ] || broken "fx_advance on a world with no clock: $1"
  printf '%s' "$(( $(fx_offset "$1") + $2 ))" > "$(fx_clock_file "$1")"
}
fx_onsleep() { printf '%s\n' "$2" > "$(fx_clock_file "$1").onsleep" || broken "cannot write the poll hook for $1"; }
fx_onsleep_off() { rm -f "$(fx_clock_file "$1").onsleep"; }
fx_settime() {  # $1 = file, $2 = epoch -- BSD then GNU, refuses on neither
  st_t_="$("$WBL_REAL_DATE" -r "$2" +%Y%m%d%H%M.%S 2>/dev/null || "$WBL_REAL_DATE" -d "@$2" +%Y%m%d%H%M.%S 2>/dev/null)"
  [ -n "$st_t_" ] && touch -t "$st_t_" "$1" || broken "cannot set the mtime of $1 to $2"
}

# THE CLOCK'S OWN PROBE, BOTH DIRECTIONS, before any arm leans on it: in a clocked world a
# `sleep 60` reaches no real sleep and moves `date +%s` by exactly 60; with the clock off the same
# world's shims fall through, so the sleep reaches the real binary and `date` reads the real clock.
# STRUCTURAL, NOT TIMED. The real sleep the shims fall through to is `$WBL_REAL_SLEEP`, so for these
# calls it names a RECORDER that logs its argument and returns: "no real sleep" is an empty log and
# "the real sleep" is a logged `1`, and the real date is bracketed by two reads of the real clock. No
# elapsed time decides either direction, so a loaded box cannot fail the probe (BL-868). A shim that
# never engaged (PATH order, an `env -i` farm that dropped it) still fails here by name.
CLOCK_REC="$TMPROOT/clock-probe.sleeps"; CLOCK_REC_BIN="$TMPROOT/clock-probe-sleep"
{ printf '#!%s\n' "$WBL_BASH"; printf 'printf "%%s\\n" "$*" >> "%s"\n' "$CLOCK_REC"; } > "$CLOCK_REC_BIN" \
  && chmod +x "$CLOCK_REC_BIN" || broken "cannot write the clock probe's sleep recorder"
clock_probe() {
  cp_w_="$TMPROOT/clock-probe"; mkdir -p "$cp_w_"; fx_clock_on "$cp_w_"; : > "$CLOCK_REC"
  cp_out_="$(cd "$cp_w_" && AI_DLC_PROJECT_ROOT="$cp_w_" WBL_REAL_SLEEP="$CLOCK_REC_BIN" bash -c 'a=$(date +%s); sleep 60; b=$(date +%s); printf "%s %s %s" "$(command -v sleep)" "$a" "$b"')"  # bl868-allow: wbl-clock-shim-probe
  set -- $cp_out_
  if [ "${1:-}" = "$WBL_CLOCK_BIN/sleep" ] && [ $(( ${3:-0} - ${2:-0} )) -eq 60 ] && [ ! -s "$CLOCK_REC" ]; then
    ok "clock: in a clocked world the subject's PATH finds the shim, a sleep 60 reaches no real sleep, and date +%s moved exactly 60"
  else broken "clock: the shim did not engage (sleep=${1:-?}, date moved $(( ${3:-0} - ${2:-0} ))s, real sleeps: $(tr '\n' ' ' < "$CLOCK_REC"))"; fi
  fx_clock_off "$cp_w_"; fx_shims_on
  cp_r0_="$("$WBL_REAL_DATE" +%s)"
  cp_out_="$(cd "$cp_w_" && AI_DLC_PROJECT_ROOT="$cp_w_" WBL_REAL_SLEEP="$CLOCK_REC_BIN" bash -c 'sleep 1; date +%s')"  # bl868-allow: wbl-clock-shim-control
  cp_r1_="$("$WBL_REAL_DATE" +%s)"
  if [ "$(cat "$CLOCK_REC")" = 1 ] && [ "${cp_out_:-0}" -ge "$cp_r0_" ] && [ "${cp_out_:-0}" -le "$cp_r1_" ]; then
    ok "clock: CONTROL — the same world with its clock off falls through: the sleep reached the real binary and date read the real clock"
  else broken "clock: CONTROL FAILED — with the clock off the shims did not fall through (real sleeps: $(tr '\n' ' ' < "$CLOCK_REC"), date $cp_out_ against ${cp_r0_}..${cp_r1_})"; fi
}

# ---------------------------------------------------------------------------
# THE OUTPUT VOCABULARY, NAMED ONCE. Section 0 proves these three strings
# discriminate before any of them is used against the subject. A detector that
# cannot spell what it hunts scores its own subject as a non-instance and returns
# clean, which is the failure mode this whole repo scars over.
# ---------------------------------------------------------------------------
IDLE_BANNER='TEAMMATE IDLE, DELIVERABLE ABSENT'
LIVE_LINE='LIVENESS  a teammate in this session took a turn'
UNAVAIL_LINE='LIVENESS  unavailable (no teammate transcripts for this session)'
HDR_REFUSE='-- ends in seat-complete: but the merge would refuse it: '
NOMARK_LINE='-- present, last non-blank line is not seat-complete:'

# Pure shell pattern match, no pipe and no grep. `grep -q` fed from a pipe reports
# NOT-FOUND on input that contains the pattern once the writer fills the pipe buffer
# (EPIPE under pipefail), and this fixture's inputs are multi-line beat output that
# grows as the subject's prose grows — exactly the shape that crosses that threshold
# silently.
has() { case "$OUT" in *"$1"*) return 0 ;; *) return 1 ;; esac; }

# The fixture's OWN mtime reader. Deliberately not borrowed from the subject: a
# fixture that reused `mtime_of` would report an age of zero whenever that function
# broke, and the idle arms would then be measuring the code they are testing.
fx_mtime() {
  if stat -f "%m" . >/dev/null 2>&1; then stat -f "%m" "$1" 2>/dev/null || echo 0
  else stat -c "%Y" "$1" 2>/dev/null || echo 0; fi
}

# THE SEED CLOCK. A seed's age is measured against the clock of the world that reads it, never
# against the fixture's real clock: a transcript stamped "1h ago" in real time and read on a world
# clock started earlier is 1h PLUS however long the steps between took, so its age moved with load
# (BL-868). mk_work records the world it made in $TMPROOT/last-world, and every seed helper stamps
# relative to that world's virtual now (fx_seed_now) -- the age the subject reads is then the age asked
# for plus the virtual seconds its own polls advanced, whatever any step cost in real time.
fx_seed_now() { fs_w_=""; [ -f "$TMPROOT/last-world" ] && read -r fs_w_ < "$TMPROOT/last-world"; fx_now "${fs_w_:-/nonexistent}"; }

# Backdate a file by N seconds, on the seed clock. BSD `date -r` and GNU `date -d` split
# here, and a silent failure is the dangerous direction: an un-aged transcript makes every
# idle arm read "not idle" while printing nothing wrong. So this returns nonzero and the
# caller declares the fixture BROKEN rather than letting the arm score clean.
fx_backdate() {  # $1 = file, $2 = seconds into the past
  bd_e_=$(( $(fx_seed_now) - $2 ))
  bd_st="$("$WBL_REAL_DATE" -r "$bd_e_" +%Y%m%d%H%M.%S 2>/dev/null || "$WBL_REAL_DATE" -d "@$bd_e_" +%Y%m%d%H%M.%S 2>/dev/null || true)"
  [ -n "$bd_st" ] || return 1
  touch -t "$bd_st" "$1" 2>/dev/null || return 1
  return 0
}

# A teammate transcript, aged. `$2` seconds of quiet, verified by the fixture's own
# reader before the subject ever sees it.
#
# THE LINES ARE THE HARNESS'S OWN SHAPE, NOT `{"t":1}`. The sensor reads a turn from the newest
# timestamp on an assistant or user line, so a seed with no such line exercises only its mtime
# fallback. Each transcript carries a user line, an answered `{"type":"api-request"` line and an
# assistant line, every timestamp `$2` seconds old, and the file's mtime agrees. The fallback has
# its own seed (mk_transcript_bare) and its own arm in section 23.
mk_transcript() {  # $1 = dir, $2 = age seconds, $3 = basename
  mkdir -p "$1" || broken "cannot create $1"
  mt_now_="$(fx_seed_now)"
  mt_ts_="$(fx_iso $(( mt_now_ - $2 )))"; [ -n "$mt_ts_" ] || broken "neither BSD nor GNU date can format an epoch"
  { printf '{"parentUuid":null,"isSidechain":true,"agentId":"a1","type":"user","message":{"role":"user","content":[{"type":"text","text":"brief"}]},"timestamp":"%s.100Z"}\n' "$mt_ts_"
    printf '{"type":"api-request","sessionId":"s","agentId":"a1","id":"r1","timestamp":"%s.200Z","shapeHash":"7d7e1ada"}\n' "$mt_ts_"
    printf '{"parentUuid":"u1","isSidechain":true,"agentId":"a1","message":{"role":"assistant","content":[{"type":"text","text":"ok"}]},"type":"assistant","timestamp":"%s.300Z"}\n' "$mt_ts_"
  } > "$1/$3" || broken "cannot write $1/$3"
  # The mtime agrees with the lines: stamped at the seed clock's now minus the age, age 0 included.
  fx_backdate "$1/$3" "$2" || broken "neither BSD nor GNU date can backdate a file here"
  age=$(( mt_now_ - $(fx_mtime "$1/$3") ))
  [ "$age" -eq "$2" ] || broken "backdate did not take: asked $2s, measured ${age}s"
}

mk_work() {  # a fresh join tree on the injected clock; prints its path
  w="$(mktemp -d "$TMPROOT/w.XXXXXX")" || broken "mktemp failed"
  mkdir -p "$w/_bmad-output" || broken "cannot create state dir"
  fx_clock_on "$w"; fx_shims_on
  printf '%s\n' "$w" > "$TMPROOT/last-world" || broken "cannot record the seed clock's world"
  printf '%s' "$w"
}
fx_clock_copy() {  # $1 = source world, $2 = destination world: the destination reads the source's clock
  cp "$(fx_clock_file "$1")" "$(fx_clock_file "$2")" && cp "$(fx_clock_file "$1").base" "$(fx_clock_file "$2").base" \
    || broken "cannot copy the clock of $1"
}

# ---------------------------------------------------------------------------
# THE SUBJECT, IN PROCESS. wbl_ip runs wait-for-deliverable.sh IN THE CALLING SHELL, which is always a
# subshell the caller opened: it sources the subject (whose BASH_SOURCE guard returns before either main
# runs) and calls wfd_mark_main then wfd_beat_main with the argv the CLI gets -- the two lines the
# script's own tail runs. The subject's `exit` ends that subshell and its EXIT trap runs there, so a
# call costs a subshell, not a bash start. It is sourced once per call because it reads its AI_DLC_*
# tuning at source time and the callers vary that tuning per call. The CLI itself is still run, once
# per distinct outcome, by wiring_e2e (below), which also holds the two answers byte-identical.
#   pipefail is off, as the CLI runs it. wfd_start_of is unset first: S26 defines the helper's copy in
#   this shell, and a lone copy with no helper beside it must take its own inline fallback, as its CLI run did.
#   date and sleep are FUNCTIONS here -- THE INJECTED CLOCK in process. The same arithmetic as the PATH
#   shims above, keyed on the same clock file: `date +%s` is base + offset, `sleep N` adds N and then
#   sources the world's poll hook in a subshell (so the hook's `exit` ends only the hook). A world with
#   no clock falls through to the real date and to `command sleep` (a gated stub, where a cell put one
#   first on PATH). Children the subject starts (the merge's --check-header, the seal's
#   --admit-marker) still see the PATH shims.
#   THE PARENT SHELL. The CLI ran every beat with a fresh parent pid, so a beat never found a
#   `.shell-<its PPID>` marker it had not been chained behind. In process every call shares this
#   fixture's $PPID, so a beat call first removes `.shell-$PPID` from its counter dir -- a fresh shell
#   -- unless WBL_CHAIN=1 (the chained cases, which write or keep that marker on purpose). --status,
#   --dispatch-ts and --mark write nothing, and nothing is removed for them.
#   THE LEASE HOLDER. A background beat exports WFD_SELF_PID as its own subshell's pid, read INLINE as
#   `$("$WBL_BASH" -c 'echo $PPID')` (bash 3.2 has no BASHPID; through a function the substitution
#   forks once more and reads a pid one level down). That is the `$!` its caller holds; a foreground
#   call leaves it unset and holds as $$.
# ---------------------------------------------------------------------------
wbl_ip() {  # $1 = subject; rest = its argv. Call it inside a subshell.
  wi_s_="$1"; shift
  set +o pipefail
  unset -f wfd_start_of
  wbl_clock_fns
  case " $* " in *" --status "*|*" --dispatch-ts "*|" --mark "*|" --mark-repair "*) ;;
    *) if [ "${WBL_CHAIN:-0}" != 1 ] && [ -n "${AI_DLC_PROJECT_ROOT:-}" ]; then
         case "${AI_DLC_STATE_DIR:-}" in
           /*) wi_sd_="$AI_DLC_STATE_DIR" ;;
           *) wi_sd_="$AI_DLC_PROJECT_ROOT/${AI_DLC_STATE_DIR:-_bmad-output}" ;;
         esac
         rm -f "$wi_sd_/.wait-beats/.shell-$PPID"
       fi ;;
  esac
  # shellcheck disable=SC1090
  [[ "$wi_s_" != */core/scripts/wait-for-deliverable.sh ]] && [[ "$wi_s_" != */core/fixtures/*/../../scripts/wait-for-deliverable.sh ]] || fx_inproc "$wi_s_"; . "$wi_s_"
  wfd_mark_main "$@"
  [[ "$wi_s_" != */core/scripts/wait-for-deliverable.sh ]] && [[ "$wi_s_" != */core/fixtures/*/../../scripts/wait-for-deliverable.sh ]] || fx_inproc "$wi_s_"; wfd_beat_main "$@"
}
wbl_clock_fns() {  # defines date and sleep as the in-process clock, in the calling (sub)shell
  date() {
    if [ "$#" -eq 1 ] && [ "$1" = "+%s" ] && [ -n "${AI_DLC_PROJECT_ROOT:-}" ]; then
      wck_f_="$WBL_CLOCK_DIR/${AI_DLC_PROJECT_ROOT//\//_}"
      if [ -f "$wck_f_" ]; then wck_o_=0; read -r wck_o_ < "$wck_f_"; read -r wck_r_ < "$wck_f_.base"; printf '%s\n' "$(( wck_r_ + wck_o_ ))"; return 0; fi
    fi
    "$WBL_REAL_DATE" "$@"
  }
  sleep() {
    if [ "$#" -eq 1 ] && [ -n "${AI_DLC_PROJECT_ROOT:-}" ]; then
      case "$1" in ""|*[!0-9]*) ;; *)
        wck_f_="$WBL_CLOCK_DIR/${AI_DLC_PROJECT_ROOT//\//_}"
        if [ -f "$wck_f_" ]; then
          wck_o_=0; read -r wck_o_ < "$wck_f_"; printf '%s' "$(( wck_o_ + $1 ))" > "$wck_f_"
          read -r wck_r_ < "$wck_f_.base"; wck_n_=$(( wck_r_ + wck_o_ + $1 ))
          [ -f "$wck_f_.onsleep" ] && ( set +u
            fx_vtouch() { touch -t "$("$WBL_REAL_DATE" -r "$wck_n_" +%Y%m%d%H%M.%S 2>/dev/null || "$WBL_REAL_DATE" -d "@$wck_n_" +%Y%m%d%H%M.%S)" "$1"; }
            . "$wck_f_.onsleep" )
          return 0
        fi ;;
      esac
    fi
    command sleep "$@"
  }
}
# THE IN-PROCESS CLOCK'S OWN PROBE, BOTH DIRECTIONS, beside clock_probe: in a clocked world the
# functions answer `sleep 60` at once and move `date +%s` by 60, and run the poll hook; with the clock
# off the same world falls through to the real date and to `command sleep`. Structural, as
# clock_probe is: the real sleep is the recorder for these calls, and nothing is timed.
clock_probe_ip() {
  cpi_w_="$TMPROOT/clock-probe-ip"; mkdir -p "$cpi_w_"; fx_clock_on "$cpi_w_"; : > "$CLOCK_REC"
  fx_onsleep "$cpi_w_" ": > '$cpi_w_/hooked'"
  cpi_out_="$( AI_DLC_PROJECT_ROOT="$cpi_w_"; WBL_REAL_SLEEP="$CLOCK_REC_BIN"; wbl_clock_fns; a=$(date +%s); sleep 60; b=$(date +%s); printf '%s %s %s' "$(type -t sleep)" "$a" "$b" )"  # bl868-allow: wbl-clock-ip-probe
  set -- $cpi_out_
  if [ "${1:-}" = function ] && [ $(( ${3:-0} - ${2:-0} )) -eq 60 ] && [ ! -s "$CLOCK_REC" ] && [ -e "$cpi_w_/hooked" ]; then
    ok "clock: in process, a clocked world's sleep 60 reaches no real sleep, date +%s moves exactly 60, and the poll hook ran"
  else broken "clock: the in-process clock did not engage (sleep=${1:-?}, date moved $(( ${3:-0} - ${2:-0} ))s, real sleeps: $(tr '\n' ' ' < "$CLOCK_REC"), hook=$([ -e "$cpi_w_/hooked" ] && echo ran || echo no))"; fi
  fx_clock_off "$cpi_w_"; fx_shims_on
  cpi_r0_="$("$WBL_REAL_DATE" +%s)"
  cpi_out_="$( AI_DLC_PROJECT_ROOT="$cpi_w_"; export WBL_REAL_SLEEP="$CLOCK_REC_BIN"; wbl_clock_fns; sleep 1; date +%s )"  # bl868-allow: wbl-clock-ip-control
  cpi_r1_="$("$WBL_REAL_DATE" +%s)"
  if [ "$(cat "$CLOCK_REC")" = 1 ] && [ "${cpi_out_:-0}" -ge "$cpi_r0_" ] && [ "${cpi_out_:-0}" -le "$cpi_r1_" ]; then
    ok "clock: in process, CONTROL — the same world with its clock off falls through: the sleep reached the real binary and date read the real clock"
  else broken "clock: in process, CONTROL FAILED — with the clock off the functions did not fall through (real sleeps: $(tr '\n' ' ' < "$CLOCK_REC"), date $cpi_out_ against ${cpi_r0_}..${cpi_r1_})"; fi
}

# ---------------------------------------------------------------------------
# ONE BEAT. The quantum is 2s with a 1s poll and a 1s margin: RESERVE is max(MARGIN,
# POLL) = 1, so the deadline lands one second out and a waiting beat costs ~1-2s. The
# margin is load-bearing and easy to miss — at its default of 10 the deadline would
# land in the PAST, the poll loop would break immediately, and every arm below would
# pass or fail by luck rather than by the code path it names.
#
# CLAUDE_CODE_SESSION_ID IS SCRUBBED ON EVERY CALL BUT ONE. Left set, the subject
# would resolve the OPERATOR'S real teammate directory, every arm would score against
# whatever that machine happened to be doing, and the suite would be green or red by
# time of day. Section 9 is the single exception and it supplies its own HOME.
#
# Output goes to a FILE, not to command substitution: `OUT="$(beat ...)"` runs the
# function in a subshell, so the RC it sets never reaches the caller and every
# exit-code assertion reads a stale value.
# ---------------------------------------------------------------------------
beat() {  # $1=subject $2=workdir $3=idle_secs $4=teammate_dir ; rest = extra argv
  b_subj="$1" b_w="$2" b_idle="$3" b_td="$4"; shift 4
  ( cd "$b_w" && unset CLAUDE_CODE_SESSION_ID && export \
        AI_DLC_WAIT_BEAT_SECS=2 \
        AI_DLC_WAIT_POLL_SECS=1 \
        AI_DLC_WAIT_MARGIN_SECS=1 \
        AI_DLC_MAX_WAIT_BEATS="${MAXB:-6}" \
        AI_DLC_TEAMMATE_IDLE_SECS="$b_idle" \
        AI_DLC_TEAMMATE_DIR="$b_td" \
        AI_DLC_PROJECT_ROOT="$PWD" && wbl_ip "$b_subj" "$@" deliv.md ) > "$BEATOUT" 2>&1
  RC=$?
  OUT="$(cat "$BEATOUT")"
}

# A chained sibling: the marker is keyed on the PID of the shell that INVOKES the
# subject, so it must be written by that very shell. In process that shell's pid is
# this fixture's $PPID (a subshell keeps it), so the marker is `.shell-$PPID`, stamped
# with the real clock and no start time -- the one-field marker the CLI wrapper wrote
# -- and WBL_CHAIN keeps wbl_ip from clearing it. Section 7b asserts it landed.
chained_beat() {  # $1=subject $2=workdir $3=idle_secs $4=teammate_dir
  c_subj="$1" c_w="$2" c_idle="$3" c_td="$4"
  ( cd "$c_w" && unset CLAUDE_CODE_SESSION_ID && export \
        AI_DLC_WAIT_BEAT_SECS=60 \
        AI_DLC_WAIT_POLL_SECS=1 \
        AI_DLC_WAIT_MARGIN_SECS=1 \
        AI_DLC_MAX_WAIT_BEATS="${MAXB:-6}" \
        AI_DLC_TEAMMATE_IDLE_SECS="$c_idle" \
        AI_DLC_TEAMMATE_DIR="$c_td" \
    && { printf "%s" "$("$WBL_REAL_DATE" +%s)" > "_bmad-output/.wait-beats/.shell-$PPID" || exit 3; } \
    && export AI_DLC_PROJECT_ROOT="$PWD" WBL_CHAIN=1 && wbl_ip "$c_subj" deliv.md ) > "$BEATOUT" 2>&1
  RC=$?
  OUT="$(cat "$BEATOUT")"
}

# ===========================================================================
# 0. SELF-PROBE — runs BEFORE the corpus, and in BOTH directions.
#    An arm reporting a clean corpus without first proving it can produce a finding
#    has established that it ran, not that the corpus is clean. Every string this
#    fixture searches for is seeded here as an offender and as a NEAR-MISS: a
#    detector that flags everything and a detector that discriminates are the same
#    output on a corpus that happens to be clean.
# ===========================================================================
probe() {
  echo "  -- self-probe (must run before any subject invocation) --"

  OUT="head
${IDLE_BANNER} -- no teammate in this session has taken a
tail"
  if has "$IDLE_BANNER"; then ok "probe: the idle detector reports a seeded offender"
  else bad "probe: the idle detector cannot spell its own subject — every idle arm below is a false clean"; fi

  # NEAR-MISS. The banner's discriminating half is the second clause: an ABSENT
  # deliverable. `TEAMMATE IDLE, DELIVERABLE PRESENT` is not this finding, and a
  # detector keyed on `TEAMMATE IDLE` alone would score it as one.
  OUT="head
TEAMMATE IDLE, DELIVERABLE PRESENT -- something else entirely
tail"
  if has "$IDLE_BANNER"; then bad "probe: the idle detector fires on a near-miss, so its greens mean nothing"
  else ok "probe: the idle detector stays quiet on a seeded near-miss"; fi

  OUT="x ${LIVE_LINE} 4m ago. y"
  if has "$LIVE_LINE"; then ok "probe: the live-turn detector reports a seeded offender"
  else bad "probe: the live-turn detector cannot spell its own subject"; fi
  OUT="x LIVENESS a teammate in this session took a turn 4m ago. y"   # one space, not two
  if has "$LIVE_LINE"; then bad "probe: the live-turn detector fires on a near-miss"
  else ok "probe: the live-turn detector stays quiet on a seeded near-miss"; fi

  OUT="x ${UNAVAIL_LINE} -- this beat y"
  if has "$UNAVAIL_LINE"; then ok "probe: the unavailable detector reports a seeded offender"
  else bad "probe: the unavailable detector cannot spell its own subject"; fi
  OUT="x LIVENESS  unavailable (no teammate transcripts for this project) y"
  if has "$UNAVAIL_LINE"; then bad "probe: the unavailable detector fires on a near-miss"
  else ok "probe: the unavailable detector stays quiet on a seeded near-miss"; fi

  # The --shard-header line and the marker-missing line are each other's near-miss: both open
  # `UNFINISHED <path> -- `, and a detector keyed on that prefix scores either as the other.
  OUT="x UNFINISHED s.md -- ends in seat-complete: but the merge would refuse it: why y"
  if has "$HDR_REFUSE" && ! has "$NOMARK_LINE"; then ok "probe: the header-refusal detector reports a seeded offender, and the marker-missing detector does not"
  else bad "probe: the header-refusal detector cannot spell its subject, or the marker-missing one fires on it"; fi
  OUT="x UNFINISHED s.md -- present, last non-blank line is not seat-complete: y"
  if has "$NOMARK_LINE" && ! has "$HDR_REFUSE"; then ok "probe: the header-refusal detector stays quiet on the marker-missing near-miss, which its own detector reports"
  else bad "probe: the header-refusal detector fires on the marker-missing line, or that line's detector is blind"; fi

  OUT=""
}

# ===========================================================================
# 1. THE SENSOR'S THREE ANSWERS ARE THREE, NOT TWO.
#    `unavailable` and `quiet for zero seconds` are different facts. Collapsing them
#    reports a DEAD SENSOR as a LIVE TEAMMATE — silent, and in the direction that
#    keeps the lead beating. Both spellings of "no signal" are covered: an override
#    naming a directory that does not exist, and no override and no session id at all.
# ===========================================================================
S1_unavailable() {
  W="$(mk_work)"

  beat "$SUBJ" "$W" 60 "$TMPROOT/does-not-exist"
  if has "$UNAVAIL_LINE"; then ok "unavailable: a teammate dir that does not exist reports NO SIGNAL"
  else bad "unavailable: a nonexistent teammate dir printed no unavailable line — the beat is silently blind: $OUT"; fi
  if has "$LIVE_LINE"; then bad "unavailable: no signal was reported as a LIVE TEAMMATE — the two answers collapsed"
  else ok "unavailable: no signal is NOT reported as a live teammate"; fi
  if has "$IDLE_BANNER"; then bad "unavailable: no signal was reported as IDLE — an absent sensor must never accuse"
  else ok "unavailable: no signal is NOT reported as idle"; fi

  # THE CONTROL, IN THE SAME INVOCATION SET. Three absences above establish only that
  # the run happened. This is the same subject and the same work tree with a REAL
  # stale transcript, and it must come back non-zero on the banner.
  TD="$TMPROOT/s1-td"; mk_transcript "$TD" 7200 agent-aone-1.jsonl
  beat "$SUBJ" "$W" 60 "$TD"
  if has "$IDLE_BANNER"; then ok "unavailable: CONTROL — the same subject and tree DO report the banner when a real stale transcript is present"
  else bad "unavailable: CONTROL FAILED — the banner never fires at all, so the three absences above prove nothing: $OUT"; fi

  rm -rf "$W"
}

# ===========================================================================
# 2. A LIVE TEAMMATE IS NOT IDLE — the near-miss direction of the threshold.
# ===========================================================================
S2_live() {
  W="$(mk_work)"
  TD="$TMPROOT/s2-td"; mk_transcript "$TD" 0 agent-aone-1.jsonl

  beat "$SUBJ" "$W" 3600 "$TD"
  if has "$LIVE_LINE"; then ok "live: a teammate that just took a turn is reported as live"
  else bad "live: a fresh transcript produced no live-turn line: $OUT"; fi
  if has "$IDLE_BANNER"; then bad "live: a teammate that took a turn seconds ago was accused of being idle — the threshold is not read"
  else ok "live: a fresh teammate does NOT trip the idle banner"; fi
  if has "$UNAVAIL_LINE"; then bad "live: a present transcript was reported as no signal"
  else ok "live: a present transcript is not reported as no signal"; fi

  rm -rf "$W"
}

# ===========================================================================
# 3. QUIET PAST THE THRESHOLD IS THE BANNER — and it changes NO DECISION.
#    This is the arm that would let the fix become the failure it replaces: an mtime
#    heuristic wired into the exit code would re-dispatch live teammates on a guess.
#    So the banner and rc=0 are asserted together, and the counter is asserted not to
#    have moved differently either.
# ===========================================================================
S3_idle_reports_but_decides_nothing() {
  W="$(mk_work)"
  TD="$TMPROOT/s3-td"; mk_transcript "$TD" 7200 agent-aone-1.jsonl

  beat "$SUBJ" "$W" 60 "$TD"
  if has "$IDLE_BANNER"; then ok "idle: a session whose teammates have all been quiet past the threshold trips the banner"
  else bad "idle: a 2h-quiet teammate did not trip the banner: $OUT"; fi
  if [ "$RC" -eq 0 ]; then ok "idle: a still-waiting join still exits ZERO — the banner is a report, not a verdict"
  else bad "idle: rc $RC — the liveness report changed the exit code, which turns every quiet stretch into a harness failure line"; fi
  if has "WAITING   deliv.md"; then ok "idle: the ordinary WAITING line is still printed alongside the banner"
  else bad "idle: the banner REPLACED the waiting line — the lead loses the per-path status: $OUT"; fi

  # The banner must not suppress or duplicate the beat accounting either.
  beat "$SUBJ" "$W" 60 "$TD"
  if has "beat 2/6"; then ok "idle: the beat counter advances normally under the banner"
  else bad "idle: the counter did not reach beat 2 with the banner firing — the report is interfering with the sequence bound: $OUT"; fi

  rm -rf "$W"
}

# ===========================================================================
# 4. THE MINIMUM ACROSS TEAMMATES — the error direction, asserted as a property.
#    One live teammate suppresses the banner for the whole wave. That UNDER-reports
#    idleness and never over-reports it, which is what makes the sensor safe to ship
#    with no per-path binding: nothing on disk joins a teammate name to a deliverable,
#    so an arm that accused a specific teammate would be inventing the join.
# ===========================================================================
S4_min_across_teammates() {
  W="$(mk_work)"
  TD="$TMPROOT/s4-td"
  mk_transcript "$TD" 7200 agent-astale-1.jsonl
  mk_transcript "$TD" 0    agent-afresh-2.jsonl

  beat "$SUBJ" "$W" 60 "$TD"
  if has "$IDLE_BANNER"; then bad "min: one live teammate did not suppress the banner — the sensor takes the OLDEST turn, so it over-accuses whenever a wave is uneven"
  else ok "min: one live teammate suppresses the banner for the whole session"; fi
  if has "$LIVE_LINE"; then ok "min: the live teammate is what gets reported"
  else bad "min: neither line was printed with a mixed directory: $OUT"; fi

  # THE CONTROL. Removing the one fresh transcript must flip it. Without this the arm
  # above passes against a sensor that never fires at all.
  rm -f "$TD/agent-afresh-2.jsonl"
  beat "$SUBJ" "$W" 60 "$TD"
  if has "$IDLE_BANNER"; then ok "min: CONTROL — with the fresh transcript removed the same directory DOES trip the banner"
  else bad "min: CONTROL FAILED — the banner cannot fire on this tree, so the suppression above proves nothing: $OUT"; fi

  rm -rf "$W"
}

# ===========================================================================
# 5. A CLOSED JOIN GETS NO LIVENESS REPORT.
#    Printing one on a beat where everything landed trains the lead to skip the line,
#    which is how the S306 output became wallpaper in the first place.
# ===========================================================================
S5_delivered_is_silent() {
  W="$(mk_work)"
  TD="$TMPROOT/s5-td"; mk_transcript "$TD" 7200 agent-aone-1.jsonl

  # ARM FROM AN EPOCH THAT PRECEDES THE WRITE, and this is the subject's own escape hatch
  # rather than a workaround. The join accepts a deliverable only if it was written SINCE the
  # join armed, and a single-shot beat arms at invocation — so a file created on the line above
  # can only ever be as new as the arming instant, never newer. It passed for as long as the two
  # landed inside one second of each other and FAILED the moment they did not, which under the
  # pre-push pool is a red unit on a green tree: measured green 3 of 3 solo on two trees, and red
  # as the single failing unit of 174 at pool width 12. `--since` is clamped so it can only pull
  # the threshold EARLIER, so this widens nothing the subject would otherwise enforce.
  S5_SINCE=$(( $(date +%s) - 5 ))
  printf 'answer\n' > "$W/deliv.md"
  beat "$SUBJ" "$W" 60 "$TD" --since "$S5_SINCE"
  if has "DELIVERED deliv.md"; then ok "delivered: the join closes"
  else bad "delivered: a non-empty fresh file was not accepted: $OUT"; fi
  if has "$IDLE_BANNER" || has "$LIVE_LINE" || has "$UNAVAIL_LINE"; then
    bad "delivered: a closed join still printed a liveness line: $OUT"
  else ok "delivered: a closed join prints NO liveness line"; fi

  # THE CONTROL. Same tree, same teammate dir, deliverable removed — the line must
  # appear. An absence with no control is a statement that the run happened.
  rm -f "$W/deliv.md"
  beat "$SUBJ" "$W" 60 "$TD"
  if has "$IDLE_BANNER"; then ok "delivered: CONTROL — remove the deliverable and the same tree DOES report liveness"
  else bad "delivered: CONTROL FAILED — no liveness line on this tree either way: $OUT"; fi

  rm -rf "$W"
}

# ===========================================================================
# 6. NON-DELIVERY CARRIES THE REPORT, AND STILL EXITS 1.
#    This is the highest-value moment for it: Rule 20 turns non-delivery into a
#    re-dispatch, and "no teammate has taken a turn in two hours" is the fact that
#    says the deliverable DIVERGED rather than the teammate being slow. Re-dispatching
#    against a path typo repeats the typo.
# ===========================================================================
S6_non_delivery() {
  W="$(mk_work)"
  TD="$TMPROOT/s6-td"; mk_transcript "$TD" 7200 agent-aone-1.jsonl

  MAXB=1
  beat "$SUBJ" "$W" 60 "$TD"          # charges the only beat
  beat "$SUBJ" "$W" 60 "$TD"          # sequence spent
  unset MAXB
  if has "NON-DELIVERY deliv.md"; then ok "non-delivery: the sequence bound still fires"
  else bad "non-delivery: the bound did not fire — the rest of this section is testing nothing: $OUT"; fi
  if [ "$RC" -eq 1 ]; then ok "non-delivery: exit 1 is unchanged by the liveness report"
  else bad "non-delivery: rc $RC, expected 1 — the report moved the exit code"; fi
  if has "$IDLE_BANNER"; then ok "non-delivery: the banner reaches the lead at the moment it decides to re-dispatch"
  else bad "non-delivery: the exhaustion path exits without reporting liveness, which is the one place it matters most: $OUT"; fi

  rm -rf "$W"
}

# ===========================================================================
# 7. THE WAITING LINE MUST NOT REPEAT VERBATIM.
#    This is the half of the defect that needs no sensor at all. The lead re-armed the
#    same beat twice because two beats produced identical text. Two emitters exist and
#    only one of them carried a beat number; the chained-sibling line carried nothing.
# ===========================================================================
S7a_waiting_varies() {
  W="$(mk_work)"
  TD="$TMPROOT/s7-td"; mk_transcript "$TD" 0 agent-aone-1.jsonl

  beat "$SUBJ" "$W" 3600 "$TD"; L1="$OUT"
  beat "$SUBJ" "$W" 3600 "$TD"; L2="$OUT"

  # THE CONTROL COMES FIRST. "L1 differs from L2" is also true of two empty strings
  # and of a subject that crashed differently twice, so assert both are real WAITING
  # lines before reading the comparison.
  OUT="$L1"; g1=0; has "WAITING   deliv.md -- beat 1/6" && g1=1
  OUT="$L2"; g2=0; has "WAITING   deliv.md -- beat 2/6" && g2=1
  if [ "$g1" -eq 1 ] && [ "$g2" -eq 1 ]; then
    ok "vary: CONTROL — both beats emitted a real WAITING line, carrying beats 1 and 2"
  else bad "vary: CONTROL FAILED — beat lines not found (g1=$g1 g2=$g2); a difference between these two strings would mean nothing: $L1 || $L2"; fi

  if [ "$L1" != "$L2" ]; then ok "vary: two successive beats do NOT produce identical output"
  else bad "vary: two successive beats produced byte-identical output — this is the S306 defect verbatim"; fi

  OUT="$L2"
  if has "since this join armed"; then ok "vary: the WAITING line carries elapsed time since arming, which a --reset visibly restarts"
  else bad "vary: the WAITING line carries no clock, so a re-armed join is indistinguishable from a fresh one: $L2"; fi

  rm -rf "$W"
}

S7b_chained_waiting_varies() {
  W="$(mk_work)"
  TD="$TMPROOT/s7b-td"; mk_transcript "$TD" 0 agent-aone-1.jsonl

  # PRIME FIRST, AND THIS IS NOT SETUP TIDINESS. The subject WIPES its whole counter
  # directory on the first beat of a new bound (the .bound self-heal), which takes the
  # sibling marker with it -- so a chained beat written as the FIRST invocation runs
  # with MAY_SLEEP=1, sleeps its quantum, and silently scores the other emitter. That
  # is section 7a a second time wearing this section's name, and it passes.
  beat "$SUBJ" "$W" 3600 "$TD"
  chained_beat "$SUBJ" "$W" 3600 "$TD"

  # THE ARM CANNOT FIRE UNLESS THE SIBLING MARKER LANDED. Without it the subject
  # sleeps its quantum and takes the OTHER emitter, and this whole section would be
  # scoring section 7a a second time.
  if has "a sibling beat already ran in this same Bash call"; then
    ok "chained: CONTROL — the sibling marker landed, so this is the MAY_SLEEP=0 emitter"
  else bad "chained: the chained-sibling path was not taken; this section is testing the wrong emitter: $OUT"; fi

  if has "WAITING   deliv.md -- beat 1/6 (no beat charged)"; then
    ok "chained: the non-sleeping WAITING line names the beat count and says no beat was charged"
  else bad "chained: the non-sleeping WAITING line carries no beat count — it was byte-identical on every invocation, which is what let the lead re-arm blind: $OUT"; fi
  if has "since"; then ok "chained: the non-sleeping WAITING line carries the elapsed clock"
  else bad "chained: the non-sleeping WAITING line carries no clock: $OUT"; fi
  if has "$LIVE_LINE"; then ok "chained: the liveness report reaches the chained emitter too"
  else bad "chained: a chained sibling returns without any liveness line, so a lead that chains beats stays blind: $OUT"; fi

  rm -rf "$W"
}

# ===========================================================================
# 8. THE THRESHOLD IS READ, IN BOTH DIRECTIONS, ON INPUTS THAT DISCRIMINATE.
#    A control passing on an input ADJACENT to the one that matters reads exactly like
#    one that works, so these two runs differ ONLY in the threshold — same tree, same
#    transcript, same age.
# ===========================================================================
S8_threshold() {
  W="$(mk_work)"
  TD="$TMPROOT/s8-td"; mk_transcript "$TD" 3600 agent-aone-1.jsonl

  beat "$SUBJ" "$W" 3000 "$TD"
  a=0; has "$IDLE_BANNER" && a=1
  beat "$SUBJ" "$W" 7200 "$TD"
  b=0; has "$IDLE_BANNER" && b=1

  if [ "$a" -eq 1 ] && [ "$b" -eq 0 ]; then
    ok "threshold: the SAME 1h-quiet transcript trips the banner at 3000s and not at 7200s"
  else bad "threshold: the threshold does not discriminate (below=$a above=$b) — one of the two sides is not being read"; fi

  rm -rf "$W"
}

# ===========================================================================
# 9. AUTO-RESOLUTION — the path that actually ships.
#    Every section above reaches the sensor through AI_DLC_TEAMMATE_DIR, which exists
#    so the sensor can be probed at all. NONE of them exercises the resolution a real
#    beat performs, and a fixture that only ever drives the override would be green
#    against a subject whose shipped resolver never worked. So this builds a synthetic
#    HOME with TWO project directories, the session living only in the second, and
#    drives the subject with nothing but CLAUDE_CODE_SESSION_ID.
# ===========================================================================
S9_auto_resolve() {
  W="$(mk_work)"
  H="$TMPROOT/home"
  SID="11111111-2222-3333-4444-555555555555"
  # THE DECOY CARRIES A FRESH TRANSCRIPT, and that is what makes this section able to
  # fail. An empty decoy directory scores "unavailable" too, so a resolver that
  # ignored the session id entirely would satisfy both arms below. A LIVE decoy makes
  # the two answers different: the right session says IDLE, the wrong one says live.
  mk_transcript "$H/.claude/projects/aaa-first-project/other-session/subagents" 0 agent-adecoy-9.jsonl
  mk_transcript "$H/.claude/projects/zzz-second-project/$SID/subagents" 7200 agent-aone-1.jsonl

  ( cd "$W" && export HOME="$H" CLAUDE_CODE_SESSION_ID="$SID" \
        AI_DLC_WAIT_BEAT_SECS=2 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=1 \
        AI_DLC_MAX_WAIT_BEATS=6 AI_DLC_TEAMMATE_IDLE_SECS=60 \
    AI_DLC_PROJECT_ROOT="$PWD" && wbl_ip "$SUBJ" deliv.md ) > "$BEATOUT" 2>&1
  RC=$?; OUT="$(cat "$BEATOUT")"
  if has "$IDLE_BANNER"; then ok "auto-resolve: the sensor finds THIS session's subagents dir from CLAUDE_CODE_SESSION_ID alone, past a project holding a live decoy session"
  else bad "auto-resolve: no banner with only the session id set — the shipped resolution path does not work, and every other section here drives an override that hides that: $OUT"; fi

  # THE CONTROL. Same HOME, same tree, a session id that names nothing. It must fall
  # to NO SIGNAL, not to the first directory it can reach.
  ( cd "$W" && export HOME="$H" CLAUDE_CODE_SESSION_ID="99999999-0000-0000-0000-000000000000" \
        AI_DLC_WAIT_BEAT_SECS=2 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=1 \
        AI_DLC_MAX_WAIT_BEATS=6 AI_DLC_TEAMMATE_IDLE_SECS=60 \
    AI_DLC_PROJECT_ROOT="$PWD" && wbl_ip "$SUBJ" deliv.md ) > "$BEATOUT" 2>&1
  OUT="$(cat "$BEATOUT")"
  if has "$UNAVAIL_LINE"; then ok "auto-resolve: CONTROL — an unknown session id resolves to NO SIGNAL, not to whatever directory sorts first"
  else bad "auto-resolve: CONTROL FAILED — an unknown session id did not report no signal, so the resolver is matching something it should not: $OUT"; fi

  rm -rf "$W"
}

# ===========================================================================
# 10. ONLY TRANSCRIPTS COUNT AS A TEAMMATE TURN.
#     The directory also accumulates `*.meta.json` sidecars, which are written ONCE at
#     spawn and never again. Counting those would make a session look live for as long
#     as it existed — the sensor's own version of "evidence of work that stays true
#     forever", which is the exact bug the progress mark was reshaped to avoid.
# ===========================================================================
S10_only_transcripts() {
  W="$(mk_work)"
  TD="$TMPROOT/s10-td"
  mk_transcript "$TD" 7200 agent-aone-1.jsonl
  printf '{"name":"one"}\n' > "$TD/agent-aone-1.meta.json"   # fresh, and NOT a turn

  beat "$SUBJ" "$W" 60 "$TD"
  if has "$IDLE_BANNER"; then ok "transcripts: a freshly written non-transcript file in the directory is not counted as a teammate turn"
  else bad "transcripts: a fresh .meta.json suppressed the banner — the sensor counts spawn-time sidecars as activity and can never report idle: $OUT"; fi

  # THE CONTROL. The same file made into a transcript MUST suppress it, or the arm
  # above is passing because nothing in that directory is ever read.
  cp "$TD/agent-aone-1.meta.json" "$TD/agent-atwo-2.jsonl"
  beat "$SUBJ" "$W" 60 "$TD"
  if has "$IDLE_BANNER"; then bad "transcripts: CONTROL FAILED — a fresh .jsonl did not suppress the banner either, so the directory is not being read at all: $OUT"
  else ok "transcripts: CONTROL — the same fresh bytes named .jsonl DO suppress the banner"; fi

  rm -rf "$W"
}

# ===========================================================================
# 12. CWD INVARIANCE. The suite runs this from the repo root, so every arm above has
#     been observed at exactly one cwd. That cuts both ways here: a fixture can be
#     green only from the root, and it can be green only because decoy files happen to
#     exist there. Everything resolves through HERE (absolute, from $0) and through
#     mktemp trees, so cwd cannot reach any of it — asserted, not assumed.
# ===========================================================================
S12_cwd_invariance() {
  SELF_ABS="$HERE/$(basename "$0")"
  out="$( cd / && bash "$SELF_ABS" --run-one S2_live 2>&1 )"
  rc=$?
  if [ "$rc" -eq 0 ]; then ok "cwd-invariance: a case reaches the same verdict launched from /"
  else bad "cwd-invariance: rc $rc from cwd=/ — some arm is reading a path relative to the repo root: $out"; fi
  # THE CONTROL. `-eq 0` is also what an empty run scores, and a case that printed
  # nothing is the exact shape of a resolution failure that exited quietly.
  n=0
  while IFS= read -r ln; do case "$ln" in '  ok'*) n=$((n+1)) ;; esac; done <<EOF
$out
EOF
  if [ "$n" -eq 3 ]; then ok "cwd-invariance: CONTROL — all three of that case's assertions ran from /, not zero of them"
  else bad "cwd-invariance: $n assertions from cwd=/ , expected 3 — the case exited without running, which scores as clean"; fi
}

# ===========================================================================
# 13. --complete: AN EARLY-WRITING SHARD IS DELIVERED ONLY BY ITS MARKER, AND ITS
#     OWN WRITES ARE ITS EVIDENCE OF WORK.
#     A seat that writes its header first and appends findings as it verifies them is
#     non-empty for its whole run, so the plain predicate would consume it half-written.
#     Every arm here drives TWO shapes one property apart: the same skeleton with and
#     without the flag, the marker last and the marker followed by a finding, and two
#     targets in one beat of which only one grows. The no-flag pins in sections 1-12 are
#     untouched and still pass, which is the byte-identical claim for callers without it.
# ===========================================================================
CBEAT_SINCE=""
# THE SETTLE WINDOW IS PINNED TO 1s here (its default is 180s, measured -- see the subject's
# --complete header). CB_BEAT is the quantum, 2s by default: enough wherever a beat only has
# to SEE a state. A call that must DELIVER a marked file passes CB_BEAT=3, the floor where it
# can settle (the strict `> 1` needs two whole seconds; a 2s beat polls one second past
# arming). Measured: at 2s everywhere, those six calls fail and nothing else does.
CB_BEAT=2
cbeat() {  # $1=subject $2=workdir ; rest = argv (targets relative to the workdir)
  cb_subj="$1" cb_w="$2"; shift 2
  ( cd "$cb_w" && unset CLAUDE_CODE_SESSION_ID && export \
        AI_DLC_WAIT_BEAT_SECS="$CB_BEAT" \
        AI_DLC_WAIT_SETTLE_SECS="${CB_SETTLE:-1}" \
        AI_DLC_WAIT_POLL_SECS=1 \
        AI_DLC_WAIT_MARGIN_SECS=0 \
        AI_DLC_MAX_WAIT_BEATS="${CB_MAXB:-1}" \
        AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
        AI_DLC_PROJECT_ROOT="$PWD" && wbl_ip "$cb_subj" --since "$CBEAT_SINCE" "$@" ) > "$BEATOUT" 2>&1
  RC=$?
  OUT="$(cat "$BEATOUT")"
}
SKELETON='# requirements pm cross-1

- a finding verified so far'
MARKER='seat-complete: requirements pm cross-1'

S13a_complete_requires_marker() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n' "$SKELETON" > "$W/a.md"; printf '%s\n' "$SKELETON" > "$W/b.md"
  cbeat "$SUBJ" "$W" a.md
  if has "DELIVERED a.md"; then ok "complete: CONTROL — without the flag a non-empty skeleton is DELIVERED"
  else bad "complete: CONTROL FAILED — the no-flag skeleton was not delivered, so the WAITING below means nothing: $OUT"; fi
  cbeat "$SUBJ" "$W" --complete b.md
  if has "WAITING   b.md" && ! has "DELIVERED b.md" && [ "$RC" -eq 0 ]; then
    ok "complete: the same skeleton under --complete is WAITING, not DELIVERED"
  else bad "complete: a skeleton with no seat-complete line was accepted under --complete (rc=$RC): $OUT"; fi

  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/c.md"
  CB_BEAT=3 cbeat "$SUBJ" "$W" --complete c.md
  if has "DELIVERED c.md"; then ok "complete: the marker as the last line DELIVERS"
  else bad "complete: a file ending in its seat-complete line was not delivered: $OUT"; fi

  printf '%s\n%s\n- a finding appended after the marker\n' "$SKELETON" "$MARKER" > "$W/d.md"
  cbeat "$SUBJ" "$W" --complete d.md
  if has "WAITING   d.md" && ! has "DELIVERED d.md"; then ok "complete: a marker that is NOT the last non-blank line does not deliver"
  else bad "complete: a marker followed by a finding was taken as completion: $OUT"; fi

  printf '%s\n%s\n\n   \n\n' "$SKELETON" "$MARKER" > "$W/e.md"
  CB_BEAT=3 cbeat "$SUBJ" "$W" --complete e.md
  if has "DELIVERED e.md"; then ok "complete: trailing blank and whitespace-only lines do not hide the marker"
  else bad "complete: blank lines after the marker hid it: $OUT"; fi

  cbeat "$SUBJ" "$W" --complete --progress-path "$W" b.md
  if [ "$RC" -eq 64 ]; then ok "complete: --complete with --progress-path is refused (exit 64)"
  else bad "complete: --complete with --progress-path was accepted (rc=$RC): $OUT"; fi
  rm -rf "$W"
}

S13b_complete_progress_per_target() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n' "$SKELETON" > "$W/grow.md"; printf '%s\n' "$SKELETON" > "$W/static.md"
  cbeat "$SUBJ" "$W" --complete grow.md static.md     # charges the only beat, stamps each mark
  fx_advance "$W" 1
  printf -- '- a second finding, verified\n' >> "$W/grow.md"; fx_settime "$W/grow.md" "$(fx_now "$W")"
  cbeat "$SUBJ" "$W" --complete grow.md static.md     # sequence spent
  if has "PROGRESS  grow.md" && ! has "NON-DELIVERY grow.md"; then
    ok "complete: the target that grew since its own mark is granted PROGRESS"
  else bad "complete: a growing early-writing shard got no progress grant: $OUT"; fi
  if has "NON-DELIVERY static.md" && ! has "PROGRESS  static.md" && [ "$RC" -eq 1 ]; then
    ok "complete: the static target beside it reaches NON-DELIVERY (rc 1) — no cross-grant"
  else bad "complete: the static target was not declared non-delivered (rc=$RC): $OUT"; fi
  if has "re-arm with --reset --progress-path"; then bad "complete: the --progress-path advice printed under --complete: $OUT"
  else ok "complete: the --progress-path advice is suppressed under --complete"; fi

  # THE CONTROL for the suppression: the same exhaustion WITHOUT the flag prints it.
  # An ABSENT target: a file written in the same whole second as the arming instant
  # would be DELIVERED, which is the mtime race section 5 records.
  W2="$(mk_work)"
  cbeat "$SUBJ" "$W2" x.md
  cbeat "$SUBJ" "$W2" x.md
  if has "NON-DELIVERY x.md" && has "re-arm with --reset --progress-path"; then
    ok "complete: CONTROL — a no-flag exhaustion still prints the --progress-path advice"
  else bad "complete: CONTROL FAILED — the no-flag advice is gone, so its absence above proves nothing: $OUT"; fi
  rm -rf "$W" "$W2"
}

# A writer that rewrites a marked file ABOVE its marker on EVERY POLL the beat takes: the consumer's
# cross seat that wrote once and then made seven in-place Edits. It is the world's poll hook (see THE
# INJECTED CLOCK), so it edits between two observations of the subject's own loop -- the same order
# a writer racing the poll cadence produced, with no process and no wall clock. A counter makes every
# rewrite distinct bytes and stamps the virtual now as the file's mtime. `churn_stop` removes the
# hook and REFUSES (exit 2) when it never fired: a file the arms below read as being edited that was
# in fact static would turn every verdict on it into a statement about a still file.
churn() {  # $1 = file, $2 = world
  CHURN_FILE="$1"; CHURN_W="$2"; printf '0' > "$1.revs"
  fx_onsleep "$2" "i_=0; read -r i_ < '$1.revs'; i_=\$(( i_ + 1 )); printf '%s' \"\$i_\" > '$1.revs'; printf '%s\n- an in-place edit, revision %d\n%s\n' '$SKELETON' \"\$i_\" '$MARKER' > '$1'; fx_vtouch '$1'"
}
churn_stop() {
  fx_onsleep_off "$CHURN_W"
  cs_n_=0; read -r cs_n_ < "$CHURN_FILE.revs"
  [ "${cs_n_:-0}" -gt 0 ] || broken "the churn hook never fired, so the file the arms read as being edited was static"
}
# THE REFUSAL, PROBED BOTH WAYS: a churn no beat ever polled must refuse (exit 2); one a beat polled must not.
S13h_churn_refuses_when_never_fired() {
  ( W="$(mk_work)"; churn "$W/cap.md" "$W"; churn_stop ) 2>/dev/null; cp1=$?
  ( W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 )); churn "$W/cap.md" "$W"; CB_BEAT=6 CB_SETTLE=4 cbeat "$SUBJ" "$W" --complete cap.md; churn_stop ) >/dev/null 2>&1; cp2=$?
  if [ "$cp1" = 2 ] && [ "$cp2" = 0 ]; then ok "churn: a writer no poll ever fired refuses (rc $cp1); one the beat's poll fired does not (rc $cp2)"
  else bad "churn probe: never-fired rc=$cp1 (want 2), fired rc=$cp2 (want 0)"; fi
}

S13c_complete_marker_must_settle() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  # CONTROL: the identical marked file, static, delivers inside one beat -- so the WAITING
  # below is the churn and not a settle window the beat can never close.
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/still.md"
  CB_BEAT=3 cbeat "$SUBJ" "$W" --complete still.md
  if has "DELIVERED still.md"; then ok "complete: CONTROL — a static marked file settles and DELIVERS inside one beat"
  else bad "complete: CONTROL FAILED — a static marked file did not deliver, so the churn arm means nothing: $OUT"; fi

  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/churn.md"
  churn "$W/churn.md" "$W"
  CB_BEAT=6 CB_SETTLE=4 cbeat "$SUBJ" "$W" --complete churn.md       # charges the only beat
  o1="$OUT"
  CB_BEAT=6 CB_SETTLE=4 cbeat "$SUBJ" "$W" --complete churn.md       # sequence spent: its own edits buy the one grant
  o3="$OUT"
  CB_BEAT=6 CB_SETTLE=4 cbeat "$SUBJ" "$W" --complete churn.md       # grant spent, still churning
  o2="$OUT"; r2=$RC
  churn_stop
  OUT="$o1"
  if has "WAITING   churn.md" && ! has "DELIVERED churn.md"; then
    ok "complete: a marked file still being edited above its marker is WAITING, not DELIVERED"
  else bad "complete: a marked file edited in place mid-beat was delivered: $OUT"; fi
  OUT="$o3"
  if has "PROGRESS  churn.md" && ! has "DELIVERED churn.md"; then
    ok "complete: its in-place edits are its evidence of work (PROGRESS), still not DELIVERED"
  else bad "complete: a churning marked file got no PROGRESS grant, or delivered: $OUT"; fi
  OUT="$o2"
  if has "UNSETTLED churn.md" && ! has "absent after" && [ "$r2" -eq 1 ]; then
    ok "complete: on exhaustion a still-changing marked file is UNSETTLED, never 'absent' (rc 1)"
  else bad "complete: an exhausted still-changing marked file was not reported UNSETTLED (rc=$r2): $OUT"; fi
  CB_BEAT=3 cbeat "$SUBJ" "$W" --complete --reset churn.md
  if has "DELIVERED churn.md"; then ok "complete: once the edits stop, the same file settles and DELIVERS"
  else bad "complete: the churned file did not deliver after its edits stopped: $OUT"; fi

  # A marked file that PREDATES the join (a previous sprint's file at a reused path) is not
  # UNSETTLED: nothing changed. Nor is it 'absent' -- it is on disk -- so on exhaustion it is
  # UNCHANGED (BL-717), and the bare Rule 20 re-dispatch remedy is not printed for it.
  W3="$(mk_work)"; CBEAT_SINCE=""
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W3/old.md"
  fx_backdate "$W3/old.md" 3600 || broken "cannot backdate old.md"
  cb2() { ( cd "$W3" && unset CLAUDE_CODE_SESSION_ID && export AI_DLC_WAIT_BEAT_SECS=2 AI_DLC_WAIT_SETTLE_SECS=1 AI_DLC_WAIT_POLL_SECS=1 \
      AI_DLC_WAIT_MARGIN_SECS=0 AI_DLC_MAX_WAIT_BEATS=1 AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
      AI_DLC_PROJECT_ROOT="$PWD" && wbl_ip "$SUBJ" --complete old.md ) > "$BEATOUT" 2>&1; RC=$?; OUT="$(cat "$BEATOUT")"; }
  cb2; cb2
  if has "UNCHANGED old.md -- present (" && ! has "absent after" && ! has "UNSETTLED old.md" \
     && ! has "Re-dispatch the" && [ "$RC" -eq 1 ]; then
    ok "complete: a marked file older than the join is UNCHANGED on exhaustion, never 'absent' or UNSETTLED (rc 1)"
  else bad "complete: a pre-join marked file was reported absent, UNSETTLED, or given the re-dispatch remedy (rc=$RC): $OUT"; fi
  rm -rf "$W" "$W3"
}

S13d_complete_unfinished_is_not_absent() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n' "$SKELETON" > "$W/u.md"
  cbeat "$SUBJ" "$W" --complete u.md gone.md   # charges the only beat
  if has "WAITING   u.md" && has "UNFINISHED u.md -- present, last non-blank line is not seat-complete:" \
     && ! has "UNFINISHED gone.md"; then
    ok "complete: a present unmarked file is WAITING and UNFINISHED; an absent one is not UNFINISHED"
  else bad "complete: the WAITING beat did not name the present unmarked file UNFINISHED: $OUT"; fi
  cbeat "$SUBJ" "$W" --complete u.md gone.md   # sequence spent
  if has "UNFINISHED u.md -- present, last non-blank line is not seat-complete:" \
     && ! has "NON-DELIVERY u.md -- absent" && [ "$RC" -eq 1 ]; then
    ok "complete: on exhaustion a present unmarked file is UNFINISHED, never 'absent' (rc 1)"
  else bad "complete: an exhausted present unmarked file was reported absent or not UNFINISHED (rc=$RC): $OUT"; fi
  # The near-miss in the SAME beat: a target that really is absent still says so.
  if has "NON-DELIVERY gone.md -- absent after"; then
    ok "complete: NEAR-MISS — an absent target beside it is still 'absent'"
  else bad "complete: NEAR-MISS FAILED — the absent target lost its 'absent' line: $OUT"; fi
  # Without the flag nothing is ever UNFINISHED.
  W2="$(mk_work)"; printf '%s\n' "$SKELETON" > "$W2/n.md"
  cbeat "$SUBJ" "$W2" n.md
  if has "DELIVERED n.md" && ! has "UNFINISHED"; then ok "complete: CONTROL — no UNFINISHED line without --complete"
  else bad "complete: CONTROL FAILED — a no-flag beat printed UNFINISHED or did not deliver: $OUT"; fi
  rm -rf "$W" "$W2"
}

S13e_complete_marker_not_fenced_not_crlf() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n```text\n%s\n' "$SKELETON" "$MARKER" > "$W/fenced.md"
  printf '%s\n```text\nquoted\n```\n%s\n' "$SKELETON" "$MARKER" > "$W/closed.md"
  printf '%s\r\n%s\r\n' "$SKELETON" "$MARKER" > "$W/crlf.md"
  # A four-backtick fence is not closed by three, nor a backtick fence by tildes.
  printf '%s\n````text\nquoted\n```\n%s\n' "$SKELETON" "$MARKER" > "$W/short.md"
  printf '%s\n```text\nquoted\n~~~\n%s\n' "$SKELETON" "$MARKER" > "$W/mixed.md"
  printf '%s\n````text\nquoted\n`````\n%s\n' "$SKELETON" "$MARKER" > "$W/long.md"
  CB_BEAT=3 cbeat "$SUBJ" "$W" --complete fenced.md closed.md crlf.md short.md mixed.md long.md
  if has "WAITING   fenced.md" && ! has "DELIVERED fenced.md"; then
    ok "complete: a marker inside an unclosed fence does not deliver"
  else bad "complete: a marker inside an unclosed fence was taken as completion: $OUT"; fi
  if has "DELIVERED closed.md"; then ok "complete: NEAR-MISS — a marker after a CLOSED fence delivers"
  else bad "complete: NEAR-MISS FAILED — a marker after a closed fence did not deliver: $OUT"; fi
  if has "WAITING   short.md" && ! has "DELIVERED short.md" && has "WAITING   mixed.md" && ! has "DELIVERED mixed.md"; then
    ok "complete: a fence is not closed by a shorter run or by the other fence character"
  else bad "complete: a \`\`\`\` fence closed by \`\`\`, or a \`\`\` fence closed by ~~~, delivered: $OUT"; fi
  if has "DELIVERED long.md"; then ok "complete: NEAR-MISS — a fence closed by a LONGER run of its character delivers"
  else bad "complete: NEAR-MISS FAILED — a fence closed by a longer run did not deliver: $OUT"; fi
  if has "WAITING   crlf.md" && ! has "DELIVERED crlf.md"; then
    ok "complete: a marker on a CRLF line does not deliver"
  else bad "complete: a CRLF marker line was taken as completion: $OUT"; fi
  rm -rf "$W"
}

S13f_arming_note_only_for_pre_arm_files() {
  # D2: under --complete a POST-arm undelivered file did not "already have content".
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n' "$SKELETON" > "$W/post.md"
  CB_BEAT=2 cbeat "$SUBJ" "$W" --complete post.md
  if has "UNFINISHED post.md" && ! has "already had content when this join armed"; then
    ok "complete: a post-arm unmarked file gets no 'already had content' NOTE"
  else bad "complete: a post-arm file under --complete got the arming NOTE: $OUT"; fi
  # A PRE-arm file under --complete still gets it.
  W2="$(mk_work)"; printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W2/old.md"
  fx_backdate "$W2/old.md" 3600 || broken "cannot backdate old.md"
  CBEAT_SINCE=$(date +%s); CB_BEAT=2 cbeat "$SUBJ" "$W2" --complete old.md
  if has "NOTE      old.md already had content when this join armed"; then
    ok "complete: NEAR-MISS — a pre-arm file under --complete still gets the NOTE"
  else bad "complete: NEAR-MISS FAILED — a pre-arm file lost the arming NOTE: $OUT"; fi
  rm -rf "$W" "$W2"
}

# ===========================================================================
# 14. --complete-repair: THE SERIAL REMEDIATOR'S RECORD IS KEYED ON `repair-complete: serial `,
#     AND ONLY THAT, PER CALL.
#     A joined repair record concatenates PART remediators' records, so it can end in a part's
#     own `seat-complete:` marker before the serial pass has started. A beat that accepted either
#     token would consume it. Every arm pairs the token with a near-miss one property away: the
#     part marker, the bare prefix with no `serial `, the same line as a list item, and the repair
#     token offered to a plain --complete call.
# ===========================================================================
REPAIR_MARKER='repair-complete: serial requirements'
S14a_complete_repair_token() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n%s\n' "$SKELETON" "$REPAIR_MARKER" > "$W/r1.md"
  printf '%s\nseat-complete: part 3\n' "$SKELETON" > "$W/r2.md"
  printf '%s\nrepair-complete: done\n' "$SKELETON" > "$W/r3.md"
  printf '%s\n- %s\n' "$SKELETON" "$REPAIR_MARKER" > "$W/r4.md"
  CB_BEAT=3 cbeat "$SUBJ" "$W" --complete-repair r1.md r2.md r3.md r4.md
  if has "DELIVERED r1.md"; then ok "repair: a record ending 'repair-complete: serial requirements' DELIVERS under --complete-repair"
  else bad "repair: a record ending in the serial repair marker was not delivered: $OUT"; fi
  if has "WAITING   r2.md" && ! has "DELIVERED r2.md"; then
    ok "repair: a record ending in a PART remediator's 'seat-complete: part 3' does not deliver under --complete-repair"
  else bad "repair: a part remediator's seat-complete marker was taken as the serial repair marker: $OUT"; fi
  if has "WAITING   r3.md" && ! has "DELIVERED r3.md"; then ok "repair: NEAR-MISS — bare 'repair-complete: done' does not deliver"
  else bad "repair: 'repair-complete: done' (no 'serial ') delivered: $OUT"; fi
  if has "WAITING   r4.md" && ! has "DELIVERED r4.md"; then ok "repair: NEAR-MISS — the marker as a list item ('- repair-complete: serial ...') does not deliver"
  else bad "repair: a list-item repair marker delivered — the token is not keyed at column 0: $OUT"; fi
  if grep -qxF 'UNFINISHED r2.md -- present, last non-blank line is not repair-complete: serial' "$BEATOUT"; then
    ok "repair: the UNFINISHED line under --complete-repair names 'repair-complete: serial'"
  else bad "repair: the UNFINISHED line under --complete-repair does not read '... is not repair-complete: serial': $OUT"; fi

  # The token is keyed per CALL: the repair line offered to a plain --complete beat is not a
  # marker. The seat file beside it is the same-beat control that --complete still delivers.
  printf '%s\nrepair-complete: serial x\n' "$SKELETON" > "$W/s1.md"
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/s2.md"
  CB_BEAT=3 cbeat "$SUBJ" "$W" --complete s1.md s2.md
  if has "DELIVERED s2.md"; then ok "repair: CONTROL — the same --complete beat delivers a seat file ending seat-complete:"
  else bad "repair: CONTROL FAILED — the --complete beat delivered nothing, so the WAITING below means nothing: $OUT"; fi
  if has "WAITING   s1.md" && ! has "DELIVERED s1.md"; then ok "repair: a seat file ending 'repair-complete: serial x' does NOT deliver under plain --complete"
  else bad "repair: the repair token delivered a plain --complete call — the token is not keyed per call: $OUT"; fi
  if grep -qxF 'UNFINISHED s1.md -- present, last non-blank line is not seat-complete:' "$BEATOUT"; then
    ok "repair: under --complete the UNFINISHED line is byte-identical '... is not seat-complete:'"
  else bad "repair: the --complete UNFINISHED line moved: $OUT"; fi

  cbeat "$SUBJ" "$W" --complete --complete-repair r1.md
  r1=$RC
  cbeat "$SUBJ" "$W" --complete-repair --complete r1.md
  if [ "$r1" -eq 64 ] && [ "$RC" -eq 64 ]; then ok "repair: --complete with --complete-repair is refused (exit 64), in either order"
  else bad "repair: --complete with --complete-repair was accepted (rc=$r1 / $RC): $OUT"; fi
  rm -rf "$W"
}

# ===========================================================================
# 15. --status: THE BEAT'S OWN VERDICT, WITHOUT THE BEAT, AND IT WRITES NOTHING.
#     A progress check that disagrees with the beat that later consumes the file is worse than
#     none, and the inputs that separate a shipped predicate from a hand-rolled `tail -1` test
#     are exactly the ones a seat produces: a fenced marker, a CRLF line, a finding after the
#     marker, trailing blank lines, a closed fence before the marker.
# ===========================================================================
scall() {  # $1=subject $2=workdir ; rest = argv after --status. CB_SETTLE honoured.
  sc_subj="$1" sc_w="$2"; shift 2
  ( cd "$sc_w" && unset CLAUDE_CODE_SESSION_ID && export \
        AI_DLC_WAIT_SETTLE_SECS="${CB_SETTLE:-1}" \
        AI_DLC_WAIT_POLL_SECS=1 \
        AI_DLC_MAX_WAIT_BEATS="${CB_MAXB:-1}" \
        AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
        AI_DLC_PROJECT_ROOT="$PWD" && wbl_ip "$sc_subj" --status "$@" ) > "$BEATOUT" 2>&1
  RC=$?
  OUT="$(cat "$BEATOUT")"
}
# A beat in its OWN parent shell, so a second beat in one case sleeps instead of returning as a
# chained sibling: wbl_ip clears `.shell-$PPID` first (WBL_CHAIN unset), which is the fresh shell.
obeat() {  # $1=subject $2=workdir $3=outfile $4=beat secs $5=settle secs $6=since ; rest = argv
  ob_subj="$1" ob_w="$2" ob_o="$3" ob_b="$4" ob_st="$5" ob_si="$6"; shift 6
  ( cd "$ob_w" && unset CLAUDE_CODE_SESSION_ID && export \
        AI_DLC_WAIT_BEAT_SECS="$ob_b" AI_DLC_WAIT_SETTLE_SECS="$ob_st" \
        AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=0 AI_DLC_MAX_WAIT_BEATS=6 \
        AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
    AI_DLC_PROJECT_ROOT="$PWD" && wbl_ip "$ob_subj" --since "$ob_si" "$@" ) > "$ob_o" 2>&1
}
# A --reset beat whose output nobody reads (sections 15d and 16b).
reset_beat() {  # $1 = subject, $2 = workdir, $3 = target
  ( cd "$2" && unset CLAUDE_CODE_SESSION_ID && export AI_DLC_WAIT_BEAT_SECS=1 AI_DLC_WAIT_POLL_SECS=1 \
      AI_DLC_WAIT_MARGIN_SECS=0 AI_DLC_MAX_WAIT_BEATS=6 AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
      AI_DLC_PROJECT_ROOT="$PWD" && wbl_ip "$1" --reset --complete "$3" ) >/dev/null 2>&1
}
SIBLING_NOTE='a sibling beat already ran in this same Bash call'
PARITY_FILES="p-fenced.md p-crlf.md p-notlast.md p-trail.md p-closed.md"
mk_parity_world() {  # $1 = workdir
  printf '%s\n```text\n%s\n' "$SKELETON" "$MARKER" > "$1/p-fenced.md"
  printf '%s\r\n%s\r\n' "$SKELETON" "$MARKER" > "$1/p-crlf.md"
  printf '%s\n%s\n- a finding after the marker\n' "$SKELETON" "$MARKER" > "$1/p-notlast.md"
  printf '%s\n%s\n\n   \n\n' "$SKELETON" "$MARKER" > "$1/p-trail.md"
  printf '%s\n```text\nquoted\n```\n%s\n' "$SKELETON" "$MARKER" > "$1/p-closed.md"
}
# The beat's verdict for one file, in --status's vocabulary. A beat names no UNSETTLED state
# before exhaustion: a present, post-arm file it reports WAITING with no UNFINISHED line beneath
# is one whose marker it accepted and whose settle window has not closed -- UNSETTLED. Every
# parity file is written after the join's --since, so "present" is "post-arm" here.
beat_class() {  # $1 = name, $2 = workdir; reads OUT; sets PC
  if has "DELIVERED $1"; then PC=DELIVERED
  elif has "UNFINISHED $1 --"; then PC=UNFINISHED
  elif has "WAITING   $1"; then if [ -s "$2/$1" ]; then PC=UNSETTLED; else PC=WAITING; fi
  else PC=NONE; fi
}
status_class() {  # $1 = name; reads OUT; sets PC
  if has "DELIVERED $1"; then PC=DELIVERED
  elif has "UNFINISHED $1 --"; then PC=UNFINISHED
  elif has "UNSETTLED $1 --"; then PC=UNSETTLED
  elif has "WAITING   $1 --"; then PC=WAITING
  else PC=NONE; fi
}
parity() {  # $1 = beat output, $2 = status output, $3 = workdir; sets MISMATCH and CLASSES
  MISMATCH=""; CLASSES=""
  for pf in $PARITY_FILES; do
    OUT="$1"; beat_class "$pf" "$3"; pb="$PC"
    OUT="$2"; status_class "$pf"; ps="$PC"
    CLASSES="$CLASSES $pf=$pb"
    [ "$pb" = "$ps" ] && [ "$pb" != NONE ] || MISMATCH="$MISMATCH $pf:beat=$pb,status=$ps"
  done
}

S15a_status_matches_beat() {
  W="$(mk_work)"; SI=$(( $(date +%s) - 30 ))
  mk_parity_world "$W"
  # INSTANT 0 -- no beat has recorded a settle. The beat that follows runs SETTLE=60, so it
  # records each marked file's hash and cannot close the window: its verdict is the UNSETTLED
  # case. --status before it must say UNSETTLED, never DELIVERED.
  CB_SETTLE=60 scall "$SUBJ" "$W" --complete --since "$SI" $PARITY_FILES; st0="$OUT"
  obeat "$SUBJ" "$W" "$BEATOUT" 2 60 "$SI" --complete $PARITY_FILES; bt1="$(cat "$BEATOUT")"
  fx_advance "$W" 2
  # INSTANT 1 -- under SETTLE=1 those recorded hashes are now past the window. --status must say
  # DELIVERED for exactly the files the next beat delivers, UNFINISHED where it says UNFINISHED.
  CB_SETTLE=1 scall "$SUBJ" "$W" --complete --since "$SI" $PARITY_FILES; st1="$OUT"
  obeat "$SUBJ" "$W" "$BEATOUT" 2 1 "$SI" --complete $PARITY_FILES; bt2="$(cat "$BEATOUT")"

  OUT="$bt1$bt2"
  if has "$SIBLING_NOTE"; then bad "status parity: a beat ran as a chained sibling, so its verdict is not the sleeping beat's: $OUT"
  else ok "status parity: CONTROL — both beats slept in their own shell (no sibling NOTE)"; fi
  # The control that the five inputs DISCRIMINATE: the beat must deliver some and refuse others.
  OUT="$bt2"
  if has "DELIVERED p-trail.md" && has "DELIVERED p-closed.md" && has "UNFINISHED p-fenced.md --" \
     && has "UNFINISHED p-crlf.md --" && has "UNFINISHED p-notlast.md --"; then
    ok "status parity: CONTROL — the beat delivers trailing-blank and closed-fence, and calls fenced, CRLF and marker-not-last UNFINISHED"
  else bad "status parity: CONTROL FAILED — the beat's verdicts are not the expected split, so parity would mean nothing: $OUT"; fi
  parity "$bt1" "$st0" "$W"
  if [ -z "$MISMATCH" ]; then ok "status parity: before any settle --status equals the beat on all five inputs (marked files UNSETTLED, never DELIVERED)"
  else bad "status parity: --status disagrees with the beat before settle:$MISMATCH (beat:$CLASSES) -- status: $st0"; fi
  OUT="$st0"
  if has "UNSETTLED p-trail.md --" && ! has "DELIVERED p-trail.md"; then ok "status parity: a marked file with no beat-recorded settle reads UNSETTLED"
  else bad "status parity: a marked file with no recorded settle did not read UNSETTLED: $st0"; fi
  parity "$bt2" "$st1" "$W"
  if [ -z "$MISMATCH" ]; then ok "status parity: after the settle window --status equals the consuming beat on all five inputs (DELIVERED where it delivers)"
  else bad "status parity: --status disagrees with the consuming beat:$MISMATCH (beat:$CLASSES) -- status: $st1"; fi
  rm -rf "$W"
}

S15b_status_absent_and_unsettled() {
  W="$(mk_work)"; SI=$(( $(date +%s) - 30 ))
  printf 'answer\n' > "$W/present.md"
  scall "$SUBJ" "$W" --since "$SI" present.md gone.md
  if has "DELIVERED present.md" && has "WAITING   gone.md -- absent or empty" && has "STATUS -- 1 delivered, 1 not."; then
    ok "status: an ABSENT path reads WAITING and the summary counts it as not delivered"
  else bad "status: an absent path was not WAITING, or was counted as delivered: $OUT"; fi
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/sealed.md"
  scall "$SUBJ" "$W" --complete --since "$SI" sealed.md
  if has "UNSETTLED sealed.md --" && ! has "DELIVERED sealed.md"; then
    ok "status: one --status call on a marked file with no beat-recorded settle prints UNSETTLED, never DELIVERED"
  else bad "status: a marked file with no recorded settle was not UNSETTLED: $OUT"; fi
  scall "$SUBJ" "$W" --reset --since "$SI" present.md
  if [ "$RC" -eq 64 ]; then ok "status: --status with --reset is refused (exit 64)"
  else bad "status: --status --reset was accepted (rc=$RC): $OUT"; fi
  rm -rf "$W"
}

# A beat that DELIVERS drops the path's join state, so --status taken AFTER the consuming beat once
# read every consumed seat as unarmed (WAITING) or, given --since, UNSETTLED: the s319 undercount
# by another route. The beat now keeps the consumed hash; --status reads it while the file is
# unchanged, judges a changed file afresh, and a --reset clears it.
status_after_delivery() {  # $1 = subject -> sets SAD_* from one world
  W="$(mk_work)"; SI=$(( $(date +%s) - 30 ))
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/done.md"
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/later.md"
  obeat "$1" "$W" "$BEATOUT" 3 1 "$SI" --complete done.md later.md; SAD_BEAT="$(cat "$BEATOUT")"
  CB_SETTLE=60 scall "$1" "$W" --complete done.md; SAD_PLAIN="$OUT"
  CB_SETTLE=60 scall "$1" "$W" --complete --since "$SI" done.md; SAD_SINCE="$OUT"
  printf '%s\n- edited after consumption\n%s\n' "$SKELETON" "$MARKER" > "$W/later.md"
  CB_SETTLE=60 scall "$1" "$W" --complete --since "$SI" later.md; SAD_CHANGED="$OUT"
  reset_beat "$1" "$W" done.md
  CB_SETTLE=60 scall "$1" "$W" --complete done.md; SAD_RESET="$OUT"
  rm -rf "$W"
}
S15d_status_after_delivery() {
  status_after_delivery "$SUBJ"
  case "$SAD_BEAT" in *"DELIVERED done.md"*"DELIVERED later.md"*|*"DELIVERED later.md"*"DELIVERED done.md"*)
    ok "status-after-delivery: CONTROL — the consuming beat delivered both seats" ;;
    *) bad "status-after-delivery: the consuming beat did not deliver both, so nothing below was consumed: $SAD_BEAT" ;; esac
  case "$SAD_PLAIN$SAD_SINCE" in *"DELIVERED done.md"*"DELIVERED done.md"*)
    ok "status-after-delivery: a seat a beat consumed reads DELIVERED, with and without --since" ;;
    *) bad "status-after-delivery: a consumed seat was not DELIVERED (plain: $SAD_PLAIN | since: $SAD_SINCE)" ;; esac
  case "$SAD_CHANGED" in *"DELIVERED later.md"*) bad "status-after-delivery: a seat edited after consumption still read DELIVERED: $SAD_CHANGED" ;;
    *"UNSETTLED later.md"*) ok "status-after-delivery: a seat edited after consumption is judged afresh (UNSETTLED), not DELIVERED" ;;
    *) bad "status-after-delivery: an edited consumed seat read neither: $SAD_CHANGED" ;; esac
  case "$SAD_RESET" in *"DELIVERED done.md"*) bad "status-after-delivery: --reset left the consumed record behind: $SAD_RESET" ;;
    *"WAITING   done.md"*) ok "status-after-delivery: --reset clears the consumed record" ;;
    *) bad "status-after-delivery: after --reset the seat read neither: $SAD_RESET" ;; esac
}

# The REVISED-AFTER-MARKER count must outlive DELIVERED: a beat's printed line is read once and
# gone, so `<key>.revised` is the record a repair brief reads. Only --reset (or a new round) clears it.
# The edit is ordered by the gated stub, not by a clock: it lands inside the beat's first poll
# sleep, after the sweep observed the marked file, so the beat counts exactly one revision.
rev_hook() {  # $1 = workdir: one edit above the marker on the beat's FIRST poll sleep, with no process
  fx_onsleep "$1" "[ -e '$1/.rev-done' ] && exit 0; : > '$1/.rev-done'; printf '%s\n- an edit above the marker\n%s\n' '$SKELETON' '$MARKER' > '$1/rv.md'; fx_vtouch '$1/rv.md'"
}
revised_survives() {  # $1 = subject -> RS_BEAT, RS_AFTER, RS_RESET
  W="$(mk_work)"; SI=$(( $(date +%s) - 30 ))
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/rv.md"
  rev_hook "$W"
  obeat "$1" "$W" "$BEATOUT" 8 2 "$SI" --quiet --complete rv.md
  [ -e "$W/.rev-done" ] || broken "revised-survives: the beat never entered its poll sleep, so the edit never landed — no verdict"
  fx_onsleep_off "$W"
  RS_BEAT="$(cat "$BEATOUT")"
  RS_AFTER="$(cat "$W/_bmad-output/.wait-beats/$(fx_key rv.md).revised" 2>/dev/null || echo ABSENT)"
  reset_beat "$1" "$W" rv.md
  RS_RESET="$( [ -e "$W/_bmad-output/.wait-beats/$(fx_key rv.md).revised" ] && echo PRESENT || echo ABSENT )"
  rm -rf "$W"
}
S16b_revised_survives_delivery() {
  revised_survives "$SUBJ"
  # The REVISED line is echoed, not `say`d, so --quiet cannot hide it -- and a beat's stdout is
  # still read once and gone, which is why the sidecar must outlive delivery as the record.
  case "$RS_BEAT" in *"REVISED-AFTER-MARKER 1 rv.md"*)
    ok "revised-survives: CONTROL — the beat saw rv.md revised and reported it, even under --quiet" ;;
    *) bad "revised-survives: CONTROL FAILED — the beat did not report rv.md revised, so there is no count to keep: '$RS_BEAT'" ;; esac
  case "$RS_AFTER" in ''|*[!0-9]*) bad "revised-survives: after DELIVERED .revised is '$RS_AFTER', not a count" ;;
    *) if [ "$RS_AFTER" -eq 1 ]; then ok "revised-survives: after DELIVERED .revised still holds $RS_AFTER"
       else bad "revised-survives: after DELIVERED .revised holds $RS_AFTER, not the 1 revision the beat saw"; fi ;; esac
  if [ "$RS_RESET" = ABSENT ]; then ok "revised-survives: --reset clears .revised"
  else bad "revised-survives: .revised survived --reset"; fi
}

# --status SURFACES the persisted count, so a repair brief never computes a cksum key by hand; and
# the count is ROUND-SCOPED: a later round re-arms with `--since <round epoch>` (never --reset), so
# a reused seat path must not inherit the earlier round's revision -- not in --status, not on disk.
revised_rounds() {  # $1 = subject -> RR_* from one world
  W="$(mk_work)"; SI=$(( $(date +%s) - 30 ))
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/rv.md"
  rev_hook "$W"
  obeat "$1" "$W" "$BEATOUT" 8 2 "$SI" --complete rv.md
  [ -e "$W/.rev-done" ] || broken "revised-rounds: the beat never entered its poll sleep, so the edit never landed — no verdict"
  fx_onsleep_off "$W"
  RR_BEAT="$(cat "$BEATOUT")"
  CB_SETTLE=60 scall "$1" "$W" --complete --since "$SI" rv.md; RR_STATUS1="$OUT"
  fx_advance "$W" 1; R2=$(fx_now "$W"); fx_advance "$W" 1
  CB_SETTLE=60 scall "$1" "$W" --complete --since "$R2" rv.md; RR_STATUS2="$OUT"
  obeat "$1" "$W" "$BEATOUT" 1 2 "$R2" --complete rv.md
  RR_DISK="$( [ -e "$W/_bmad-output/.wait-beats/$(fx_key rv.md).revised" ] && echo PRESENT || echo ABSENT )"
  rm -rf "$W"
}
S16c_revised_status_and_rounds() {
  revised_rounds "$SUBJ"
  case "$RR_BEAT" in *"REVISED-AFTER-MARKER 1 rv.md"*) ok "revised-rounds: CONTROL — round one delivered rv.md revised once" ;;
    *) bad "revised-rounds: round one did not report rv.md revised, so nothing below has a count to read: $RR_BEAT" ;; esac
  case "$RR_STATUS1" in *"REVISED-AFTER-MARKER 1 rv.md"*) ok "revised-rounds: --status in the same round prints the persisted count" ;;
    *) bad "revised-rounds: --status did not surface the count — a brief would hand-compute the sidecar key: $RR_STATUS1" ;; esac
  case "$RR_STATUS2" in *"REVISED-AFTER-MARKER"*) bad "revised-rounds: --status for a LATER round still printed round one's count: $RR_STATUS2" ;;
    *) ok "revised-rounds: --status for a later round withholds the earlier round's count" ;; esac
  if [ "$RR_DISK" = ABSENT ]; then ok "revised-rounds: a beat armed for the later round drops round one's .revised"
  else bad "revised-rounds: round one's .revised survived a beat armed with a later --since — it leaks into the next round"; fi
}

fx_snap() {  # $1 = tree, $2 = out file: the listing and every file's hash, in find order
  { find "$1" -print; find "$1" -type f -exec shasum {} +; } > "$2" 2>&1
}
fx_key() { printf '%s' "$1" | cksum | tr -d ' \t' | cut -c1-16; }

S15c_status_read_only() {
  W="$(mk_work)"; SI=$(( $(date +%s) - 30 )); CBEAT_SINCE="$SI"
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/a.md"
  printf '%s\n' "$SKELETON" > "$W/u.md"
  printf 'x\n' > "$W/nojoin.md"
  CB_SETTLE=60 cbeat "$SUBJ" "$W" --complete a.md u.md     # arms a.md and u.md: .since, .settle, .progress, .bound
  CD="$W/_bmad-output/.wait-beats"
  # A STALE BOUND: the beat wipes every counter when .bound disagrees with its own bound.
  printf '99' > "$CD/.bound"
  rm -f "$CD"/.shell-*
  [ -f "$CD/$(fx_key a.md).since" ] && [ -f "$CD/$(fx_key a.md).settle" ] \
    || broken "the arming beat left no .since/.settle for a.md — the read-only world is not the one this arm names"
  fx_snap "$W" "$TMPROOT/snap1"
  CB_SETTLE=60 scall "$SUBJ" "$W" --complete a.md u.md nojoin.md gone.md; o_a="$OUT"
  CB_SETTLE=60 scall "$SUBJ" "$W" --complete --since "$SI" a.md u.md nojoin.md gone.md; o_b="$OUT"
  fx_snap "$W" "$TMPROOT/snap2"
  if grep -q '/\.bound$' "$TMPROOT/snap1" && cmp -s "$TMPROOT/snap1" "$TMPROOT/snap2"; then
    ok "status: read-only — two --status calls over joined, unjoined and absent paths leave every file and listing byte-identical, stale .bound included"
  else bad "status: --status changed the state tree (or the snapshot is empty)"; fi
  n_shell=0; for f in "$CD"/.shell-*; do [ -e "$f" ] && n_shell=$((n_shell+1)); done
  if [ "$n_shell" -eq 0 ] && [ ! -e "$W/_bmad-output/.beat-inflight" ] && [ ! -e "$CD/$(fx_key nojoin.md).since" ] \
     && [ "$(cat "$CD/.bound")" = 99 ]; then
    ok "status: no .shell-* marker, no .beat-inflight, no .since for the unjoined path, and the stale .bound is untouched"
  else bad "status: --status wrote a marker (shell=$n_shell inflight=$([ -e "$W/_bmad-output/.beat-inflight" ] && echo y) nojoin.since=$([ -e "$CD/$(fx_key nojoin.md).since" ] && echo y) bound=$(cat "$CD/.bound"))"; fi
  OUT="$o_a"
  if has "WAITING   nojoin.md -- no join armed" && has "WAITING   gone.md -- no join armed" \
     && has "UNSETTLED a.md --" && has "UNFINISHED u.md --"; then
    ok "status: with no join armed and no --since a path reads WAITING 'no join armed'; joined paths read their stored epoch"
  else bad "status: the no-join / stored-epoch reading is wrong: $OUT"; fi
  OUT="$o_b"
  if has "UNFINISHED nojoin.md --" && has "WAITING   gone.md -- absent or empty"; then
    ok "status: CONTROL — with --since the same unjoined path is read, so 'no join armed' above was the missing epoch"
  else bad "status: CONTROL FAILED — --since did not give the unjoined path an epoch: $OUT"; fi
  # THE CONTROL that the stale bound was a live hazard: a real beat over the same tree wipes it.
  cbeat "$SUBJ" "$W" nojoin.md
  if [ "$(cat "$CD/.bound" 2>/dev/null)" = 1 ] && [ ! -e "$CD/$(fx_key u.md).since" ]; then
    ok "status: CONTROL — a real beat over the same tree rewrites the stale .bound and wipes the counters --status left alone"
  else bad "status: CONTROL FAILED — a beat did not wipe on the stale bound, so its survival above proves nothing: $OUT"; fi

  # NO STATE DIR: --status in a tree with none must not create it.
  W2="$(mktemp -d)" || broken "mktemp failed"
  printf 'x\n' > "$W2/f.md"
  scall "$SUBJ" "$W2" --since "$SI" f.md
  if has "DELIVERED f.md" && [ ! -e "$W2/_bmad-output" ]; then ok "status: in a tree with no _bmad-output, --status answers and does not create it"
  else bad "status: --status created _bmad-output or did not answer: $OUT"; fi
  # `--progress-path .` names an ancestor of the state dir, so the subject refuses it (exit 64)
  # AFTER its mkdir and before any sleep: the control costs no beat.
  ( cd "$W2" && unset CLAUDE_CODE_SESSION_ID && export AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
      AI_DLC_PROJECT_ROOT="$PWD" && wbl_ip "$SUBJ" --progress-path . f.md ) > "$BEATOUT" 2>&1
  if [ -d "$W2/_bmad-output" ]; then ok "status: CONTROL — the same tree without --status DOES get _bmad-output created"
  else bad "status: CONTROL FAILED — the subject never creates the state dir here, so its absence above proves nothing: $(cat "$BEATOUT")"; fi
  rm -rf "$W" "$W2"
}

# ===========================================================================
# 16. REVISED-AFTER-MARKER: A SEAT THAT EDITS A FILE IT DECLARED FINAL IS NAMED, AT BOTH PLACES
#     A PATH IS DELIVERED.
#     One world, four files, five beats, each beat in its own shell so it sleeps:
#       f1    (i)   seen marked, edited above the marker, delivered at the POST-POLL site
#       f2    (ii)  seen marked, marker withdrawn, restored byte-identical, delivered post-poll
#       still (iii) seen marked, never touched -- no REVISED line
#       f4    (iv)  revised during a beat that times out (.revised left on disk), delivered at
#                   the PRE-SWEEP site of the next beat (a pre-sweep delivery prints no BEAT
#                   COMPLETE line; a post-poll one does -- that is the site discriminator)
# ===========================================================================
revised_world() {  # $1 = subject, $2 = fresh workdir
  rw_s="$1" rw_w="$2"; rw_si=$(( $(date +%s) - 30 ))
  mkdir -p "$rw_w/_bmad-output"; fx_clock_on "$rw_w"
  for rw_f in f1 f2 f4 still; do printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$rw_w/$rw_f.md"; done
  obeat "$rw_s" "$rw_w" "$rw_w/o.a1" 2 60 "$rw_si" --complete f1.md f2.md f4.md still.md
  printf '%s\n- an edit above the marker\n%s\n' "$SKELETON" "$MARKER" > "$rw_w/f1.md"
  printf '%s\n- an edit above the marker\n%s\n' "$SKELETON" "$MARKER" > "$rw_w/f4.md"
  printf '%s\n- the marker withdrawn\n' "$SKELETON" > "$rw_w/f2.md"
  obeat "$rw_s" "$rw_w" "$rw_w/o.b2" 3 1  "$rw_si" --complete f1.md still.md
  obeat "$rw_s" "$rw_w" "$rw_w/o.b3" 2 60 "$rw_si" --complete f4.md f2.md
  cat "$rw_w/_bmad-output/.wait-beats/$(fx_key f4.md).revised" > "$rw_w/o.rv4" 2>/dev/null
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$rw_w/f2.md"
  fx_advance "$rw_w" 2   # f4's settle record must be more than SETTLE=1 whole seconds old at b4's pre-sweep
  obeat "$rw_s" "$rw_w" "$rw_w/o.b4" 3 1  "$rw_si" --complete f4.md
  obeat "$rw_s" "$rw_w" "$rw_w/o.b5" 3 1  "$rw_si" --complete f2.md
}
rw_out() { OUT="$(cat "$1/o.$2" 2>/dev/null)"; }

S16_revised_after_marker() {
  W="$(mktemp -d)" || broken "mktemp failed"
  revised_world "$SUBJ" "$W"
  OUT="$(cat "$W"/o.*)"
  if has "$SIBLING_NOTE"; then bad "revised: a beat ran as a chained sibling — the world is not the one this section names: $OUT"
  else ok "revised: CONTROL — every beat slept in its own shell (no sibling NOTE)"; fi
  rw_out "$W" a1
  if has "WAITING   f1.md" && has "0 delivered, 4 still out" && ! has "DELIVERED f"; then ok "revised: CONTROL — the first beat saw every marked file and delivered none"
  else bad "revised: CONTROL FAILED — the first beat delivered, so no file was seen before its edit: $OUT"; fi
  rw_out "$W" b2
  if has "DELIVERED f1.md" && has "REVISED-AFTER-MARKER 1 f1.md" && has "BEAT COMPLETE"; then
    ok "revised (i): a marked file edited before it settled is DELIVERED then REVISED-AFTER-MARKER 1, at the post-poll site"
  else bad "revised (i): no REVISED-AFTER-MARKER 1 beneath the post-poll DELIVERED: $OUT"; fi
  if has "DELIVERED still.md" && ! has " still.md -- its content changed"; then
    ok "revised (iii): CONTROL — an unrevised sealed file delivers with NO REVISED line"
  else bad "revised (iii): the untouched file was not delivered, or was named revised: $OUT"; fi
  rw_out "$W" b3
  if has "WAITING   f4.md" && has "UNFINISHED f2.md --" && [ "$(cat "$W/o.rv4" 2>/dev/null)" = 1 ]; then
    ok "revised (iv): the beat that saw f4 revised timed out with .revised=1 left on disk; f2's withdrawn marker reads UNFINISHED"
  else bad "revised (iv): the timing-out beat did not leave .revised=1 (got '$(cat "$W/o.rv4" 2>/dev/null)'): $OUT"; fi
  rw_out "$W" b4
  if has "DELIVERED f4.md" && has "REVISED-AFTER-MARKER 1 f4.md" && ! has "BEAT COMPLETE"; then
    ok "revised (iv): the next beat delivers f4 at the PRE-SWEEP site and prints REVISED-AFTER-MARKER 1 there too"
  else bad "revised (iv): no REVISED line at the pre-sweep delivery, or it was not a pre-sweep delivery: $OUT"; fi
  rw_out "$W" b5
  if has "DELIVERED f2.md" && has " f2.md -- its content changed" && ! has "REVISED-AFTER-MARKER 0"; then
    ok "revised (ii): a marker removed then restored byte-identical still prints REVISED-AFTER-MARKER n>=1"
  else bad "revised (ii): a withdrawn-and-restored marker printed no REVISED line: $OUT"; fi
  rm -rf "$W"
}

# ===========================================================================
# 17. --shard-header: A MARKED ADVERSARIAL SHARD IS DELIVERED ONLY IF THE MERGE WOULD TAKE ITS HEADER.
#     The motivating case is a shard that ends in `seat-complete:` and carries no `verdict:` -- it
#     read DELIVERED and surfaced only at the merge, after its adversary had exited. Every arm
#     reads the expected refusal FROM THE MERGE ITSELF (--check-header, run here from the same
#     cwd so the path in its text is the beat's), asserts the merge discriminates the pair first
#     (exit 1 for the failing shard, 0 for its control), then demands that exact text in the beat.
#     The shards are built here, minimally, not with adversarial-shard-merge/lib.sh: that lib
#     resolves the merge by walking up and requires the write-ledger hook and jq, none of which
#     --check-header reads. Each is the reference shard grammar (lib.sh `shard()`): a provenance
#     block, zero findings, and a `seat-complete: ... findings=0` marker, so the valid one passes
#     the marker-count check. Written via temp + mv, so a concurrent read never sees half a file.
# ===========================================================================
mk_shard() {  # $1 = file, $2 = skill, $3 = verdict ('' = no verdict line), $4 = field to drop, $5 = body line
  ms_t="$1.tmp"
  {
    printf '# requirements -- adversarial shard\n\n## Findings\n\n## Probed and found sound\n\n- %s\n\n' "${5:-nothing further}"
    printf '<!-- SKILL_INVOCATION_PROVENANCE v1\n'
    printf 'skill: %s\ninvoked_at: 2026-10-01T10:00:00Z\ntool_use_id: NOT_ACCESSIBLE\nmode: subagent\n' "$2"
    [ "$4" = lead_role ] || printf 'lead_role: .claude/skills/ai-dlc/steps/requirements.md\n'
    printf 'artifact: _bmad-output/planning-artifacts/s1/requirements.md\n'
    printf 'findings_critical: 0\nfindings_critical_prior_scope: 0\nfindings_major: 0\nfindings_major_underived: 0\nfindings_minor: 0\n'
    if [ -n "$3" ]; then printf 'verdict: %s\n' "$3"; fi
    printf 'SKILL_INVOCATION_PROVENANCE_END -->\n\nseat-complete: requirements p1 1 findings=0\n'
  } > "$ms_t" && mv -f "$ms_t" "$1" || broken "cannot write shard $1"
}
hdr_msg() {  # $1 = workdir, $2 = shard (relative), $3 = axis -> HM (the merge's text, no `REFUSED: `), HRC
  HM="$( cd "$1" && bash "$MERGE" --check-header "$2" --axis "$3" 2>&1 )"; HRC=$?
  HM="${HM#REFUSED: }"
}
hdr_line() {  # $1 = shard, $2 = refusal text: is the beat's exact UNFINISHED line in BEATOUT?
  grep -qxF "UNFINISHED $1 ${HDR_REFUSE}$2" "$BEATOUT"
}
CV=ai-dlc-adversary-review
EL=bmad-advanced-elicitation

S17a_shard_header_convergence() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  mk_shard "$W/s-ok.md"   "$CV" EXIT_CONDITION_MET ""
  mk_shard "$W/s-nov.md"  "$CV" ""                 ""
  mk_shard "$W/s-pend.md" "$CV" PENDING-LEAD       ""
  mk_shard "$W/s-nolr.md" "$CV" EXIT_CONDITION_MET lead_role
  hdr_msg "$W" s-ok.md convergence;   c_ok=$HRC
  hdr_msg "$W" s-nov.md convergence;  c_nov=$HRC;  m_nov="$HM"
  hdr_msg "$W" s-pend.md convergence; c_pend=$HRC; m_pend="$HM"
  hdr_msg "$W" s-nolr.md convergence; c_nolr=$HRC; m_nolr="$HM"
  if [ "$c_ok" -eq 0 ] && [ "$c_nov" -eq 1 ] && [ "$c_pend" -eq 1 ] && [ "$c_nolr" -eq 1 ]; then
    ok "shard-header: CONTROL — the merge itself passes the MET shard and refuses no-verdict, PENDING-LEAD and no-lead_role"
  else bad "shard-header: CONTROL FAILED — the merge does not discriminate the seeds (ok=$c_ok nov=$c_nov pend=$c_pend nolr=$c_nolr), so the beat arms below mean nothing"; fi

  CB_BEAT=3 cbeat "$SUBJ" "$W" --complete --shard-header convergence s-ok.md s-nov.md s-pend.md s-nolr.md
  if has "DELIVERED s-ok.md" && [ "$RC" -eq 0 ]; then ok "shard-header: CONTROL — the same shard WITH verdict: EXIT_CONDITION_MET is DELIVERED (rc 0)"
  else bad "shard-header: CONTROL FAILED — a valid marked shard was not delivered under --shard-header (rc=$RC): $OUT"; fi
  if hdr_line s-nov.md "$m_nov" && ! has "DELIVERED s-nov.md"; then
    ok "shard-header (1): a marked shard with no verdict: is UNFINISHED, carrying the merge's own refusal text"
  else bad "shard-header (1): a marked no-verdict shard was not UNFINISHED with the merge's text '$m_nov': $OUT"; fi
  if hdr_line s-pend.md "$m_pend" && ! has "DELIVERED s-pend.md"; then ok "shard-header (2): verdict: PENDING-LEAD is UNFINISHED"
  else bad "shard-header (2): a PENDING-LEAD shard was not UNFINISHED with '$m_pend': $OUT"; fi
  if hdr_line s-nolr.md "$m_nolr" && ! has "DELIVERED s-nolr.md"; then ok "shard-header (3): a marked shard missing lead_role is UNFINISHED"
  else bad "shard-header (3): a no-lead_role shard was not UNFINISHED with '$m_nolr': $OUT"; fi

  # --status is the beat's verdict without the beat, so it must say the same.
  CB_SETTLE=60 scall "$SUBJ" "$W" --complete --shard-header convergence --since "$CBEAT_SINCE" s-nov.md
  if hdr_line s-nov.md "$m_nov"; then ok "shard-header: --status reports the same UNFINISHED line as the beat"
  else bad "shard-header: --status disagrees with the beat on a header-failing shard: $OUT"; fi
  rm -rf "$W"
}

S17b_shard_header_elicitation() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  # One property apart: both declare the elicitation skill; only the verdict: line differs.
  mk_shard "$W/e-nov.md" "$EL" ""                 ""
  mk_shard "$W/e-v.md"   "$EL" EXIT_CONDITION_MET ""
  hdr_msg "$W" e-nov.md elicitation; c_nov=$HRC
  hdr_msg "$W" e-v.md elicitation;   c_v=$HRC; m_v="$HM"
  CB_BEAT=3 cbeat "$SUBJ" "$W" --complete --shard-header elicitation e-nov.md e-v.md
  if [ "$c_nov" -eq 0 ] && [ "$c_v" -eq 1 ] && has "DELIVERED e-nov.md"; then
    ok "shard-header (4): on the elicitation axis a shard with NO verdict is DELIVERED"
  else bad "shard-header (4): an elicitation shard without verdict was not delivered (merge nov=$c_nov v=$c_v): $OUT"; fi
  if hdr_line e-v.md "$m_v" && ! has "DELIVERED e-v.md"; then ok "shard-header (4): on the elicitation axis a shard WITH a verdict is UNFINISHED"
  else bad "shard-header (4): an elicitation shard carrying a verdict was not UNFINISHED with '$m_v': $OUT"; fi
  rm -rf "$W"
}

S17c_shard_header_absent_changes_nothing() {
  # A headerless marked shard WITHOUT the flag delivers exactly as a valid one does: the two worlds
  # print the same output (timing words masked). WITH the flag the headerless one is UNFINISHED, so
  # the comparison is shown able to differ. Byte identity against the pre-flag script is the
  # build's probe; this arm holds the no-flag path blind to the header.
  WA="$(mk_work)"; WB="$(mk_work)"; WC="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '# requirements -- adversarial shard\n\n## Findings\n\nseat-complete: requirements p1 1 findings=0\n' > "$WA/h.md"
  cp "$WA/h.md" "$WC/h.md"
  mk_shard "$WB/h.md" "$CV" EXIT_CONDITION_MET ""
  hdr_msg "$WA" h.md convergence; c_h=$HRC; m_h="$HM"
  CB_BEAT=3 cbeat "$SUBJ" "$WA" --complete h.md; oa="$(sed -E 's/[0-9]+[smhd] (old|since|ago)/N \1/g' "$BEATOUT")"
  CB_BEAT=3 cbeat "$SUBJ" "$WB" --complete h.md; ob="$(sed -E 's/[0-9]+[smhd] (old|since|ago)/N \1/g' "$BEATOUT")"
  OUT="$oa"
  if [ "$c_h" -eq 1 ] && has "DELIVERED h.md" && [ "$oa" = "$ob" ]; then
    ok "shard-header (5): without the flag a headerless marked shard is DELIVERED, output identical to a valid shard's"
  else bad "shard-header (5): without the flag the header changed the outcome (merge rc=$c_h): [$oa] vs [$ob]"; fi
  CB_BEAT=3 cbeat "$SUBJ" "$WC" --complete --shard-header convergence h.md
  if hdr_line h.md "$m_h" && ! has "DELIVERED h.md"; then ok "shard-header (5): CONTROL — the same headerless shard WITH the flag is UNFINISHED"
  else bad "shard-header (5): CONTROL FAILED — the flag did not change the headerless outcome, so the identity above proves nothing: $OUT"; fi
  rm -rf "$WA" "$WB" "$WC"
}

# Both shards rewritten together on EVERY POLL the beat takes (the world's poll hook, see THE
# INJECTED CLOCK), each revision distinct bytes outside ## Findings; removed by churn_stop (shared
# with section 13c), which refuses when the hook never fired. The hook carries mk_shard's own
# definition, so it writes the shards through the same function the seeds use.
shard_churn() {  # $1 = workdir
  CHURN_FILE="$1/c-bad.md"; CHURN_W="$1"; printf '0' > "$CHURN_FILE.revs"
  fx_onsleep "$1" "$(declare -f mk_shard)
i_=0; read -r i_ < '$CHURN_FILE.revs'; i_=\$(( i_ + 1 )); printf '%s' \"\$i_\" > '$CHURN_FILE.revs'
mk_shard '$1/c-bad.md' '$CV' '' '' \"revision \$i_\"
mk_shard '$1/c-ok.md' '$CV' EXIT_CONDITION_MET '' \"revision \$i_\"
fx_vtouch '$1/c-bad.md'; fx_vtouch '$1/c-ok.md'"
}

S17d_shard_header_unfinished_not_unsettled() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  mk_shard "$W/c-bad.md" "$CV" ""                 ""
  mk_shard "$W/c-ok.md"  "$CV" EXIT_CONDITION_MET ""
  shard_churn "$W"
  CB_BEAT=6 CB_SETTLE=4 cbeat "$SUBJ" "$W" --complete --shard-header convergence c-bad.md c-ok.md; o1="$OUT"   # charges the beat
  CB_BEAT=6 CB_SETTLE=4 cbeat "$SUBJ" "$W" --complete --shard-header convergence c-bad.md c-ok.md               # own-progress grant
  CB_BEAT=6 CB_SETTLE=4 cbeat "$SUBJ" "$W" --complete --shard-header convergence c-bad.md c-ok.md; o3="$OUT"; r3=$RC   # spent
  churn_stop
  OUT="$o1"
  if has "UNFINISHED c-bad.md $HDR_REFUSE"; then ok "shard-header (6): a changing header-failing shard is UNFINISHED beneath its WAITING line"
  else bad "shard-header (6): the WAITING beat did not name the changing header-failing shard UNFINISHED: $OUT"; fi
  OUT="$o3"
  if has "UNSETTLED c-ok.md" && [ "$r3" -eq 1 ]; then ok "shard-header (6): CONTROL — the valid shard churning beside it IS UNSETTLED on exhaustion (rc 1)"
  else bad "shard-header (6): CONTROL FAILED — the churning valid shard was not UNSETTLED (rc=$r3), so the exhaustion path was not reached: $OUT"; fi
  if has "NON-DELIVERY c-bad.md -- after" && has "UNFINISHED c-bad.md $HDR_REFUSE" && ! has "UNSETTLED c-bad.md" \
     && ! has "NON-DELIVERY c-bad.md -- absent"; then
    ok "shard-header (6): on exhaustion a changing header-failing shard is UNFINISHED, never UNSETTLED or absent"
  else bad "shard-header (6): an exhausted changing header-failing shard was not routed to UNFINISHED: $OUT"; fi
  rm -rf "$W"
}

S17e_shard_header_refusals() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  cbeat "$SUBJ" "$W" --shard-header convergence x.md
  if [ "$RC" -eq 64 ] && has "valid only with --complete"; then ok "shard-header (7): --shard-header without --complete is refused (exit 64)"
  else bad "shard-header (7): --shard-header without --complete was accepted (rc=$RC): $OUT"; fi
  cbeat "$SUBJ" "$W" --complete-repair --shard-header convergence x.md
  if [ "$RC" -eq 64 ] && has "valid only with --complete"; then ok "shard-header (7): --shard-header with --complete-repair is refused (exit 64)"
  else bad "shard-header (7): --shard-header with --complete-repair was accepted (rc=$RC): $OUT"; fi
  cbeat "$SUBJ" "$W" --complete --shard-header bogus x.md
  if [ "$RC" -eq 64 ] && has "takes convergence or elicitation"; then ok "shard-header (7): an axis other than convergence or elicitation is refused (exit 64)"
  else bad "shard-header (7): an unknown axis was accepted (rc=$RC): $OUT"; fi
  # THE MISSING SIBLING IS REFUSED AT ARMING, never an acquittal. Control: the same lone copy
  # without the flag runs a beat, so the refusal is the flag's and not a broken copy.
  LONE="$TMPROOT/lone"; mkdir -p "$LONE"; cp "$SUBJ" "$LONE/wait-for-deliverable.sh" || broken "cannot copy the subject"
  [ ! -e "$LONE/merge-adversarial-shards.sh" ] || broken "the lone copy has a merge beside it"
  cbeat "$LONE/wait-for-deliverable.sh" "$W" --complete --shard-header convergence x.md
  if [ "$RC" -eq 64 ] && has "needs merge-adversarial-shards.sh beside this script"; then
    ok "shard-header: a subject with no merge beside it refuses --shard-header at arming (exit 64)"
  else bad "shard-header: a missing sibling merge did not refuse at arming (rc=$RC): $OUT"; fi
  cbeat "$LONE/wait-for-deliverable.sh" "$W" --complete x.md
  if [ "$RC" -eq 0 ] && has "WAITING   x.md"; then ok "shard-header: CONTROL — the same lone copy without the flag runs a beat"
  else bad "shard-header: CONTROL FAILED — the lone copy does not run at all (rc=$RC): $OUT"; fi
  rm -rf "$W" "$LONE"
}

# ===========================================================================
# 18. --dispatch MUST NOT SWITCH GLOBBING OFF FOR THE REST OF THE BEAT.
#     The id split runs under `set -f`. Left on, every later glob in the subject iterates once
#     over its own literal pattern: the teammate scan reads `unavailable` on a session with a
#     fresh transcript, and the EXIT trap's heir scan finds no heir, so a holder that exits
#     deletes the marker under a sibling still asleep. Measured on the reference consumer: a
#     lead whose every join was armed with --dispatch read `LIVENESS  unavailable` 7 times and
#     `took a turn` 0 times. Each arm below has its no-dispatch twin in this file (section 2;
#     the heir arm's control is B's own pre-exit marker), and section 18c deletes the restore.
# ===========================================================================
fx_iso() {  # $1 = epoch -> ISO8601 UTC, BSD then GNU
  date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null
}
mk_ledger_row() {  # $1 = workdir, $2 = tool_use_id, $3 = epoch -- appends one spawn-ledger row
  le_ts="$(fx_iso "$3")"; [ -n "$le_ts" ] || broken "neither BSD nor GNU date can format an epoch"
  printf '{"v":1,"ts":"%s","name":"wbl","role":"dev","tool_use_id":"%s"}\n' "$le_ts" "$2" \
    >> "$1/_bmad-output/spawn-ledger.jsonl" || broken "cannot write the spawn ledger"
}
# Every subject this section drives sits in a directory with its siblings, because --dispatch
# reads its id grammar from the one beside it; a lone copy would refuse for that, not for the
# behaviour under test.
sib_dir() {  # $1 = subject copy -> prints a fresh dir holding it as wait-for-deliverable.sh
  sd_="$(mktemp -d "$TMPROOT/sib.XXXXXX")" || broken "mktemp failed"
  cp "$1" "$sd_/wait-for-deliverable.sh" || broken "cannot copy the subject"
  cp "$MERGE" "$GRAMMAR" "$sd_/" || broken "cannot copy the subject's siblings beside it"
  printf '%s' "$sd_"
}

dispatch_live_world() {  # $1 = subject; sets OUT/RC -- a --dispatch beat over a fresh transcript
  W="$(mk_work)"; TD="$TMPROOT/s18-td.$$.$RANDOM"; mk_transcript "$TD" 0 agent-aone-1.jsonl
  mk_ledger_row "$W" toolu_wbl661 $(( $(date +%s) - 30 ))
  beat "$1" "$W" 3600 "$TD" --dispatch toolu_wbl661
}
S18a_dispatch_keeps_liveness() {
  dispatch_live_world "$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  if [ "$RC" -eq 0 ] && has "WAITING   deliv.md"; then ok "dispatch-glob: CONTROL — the --dispatch beat resolved its ledger row and ran a beat"
  else bad "dispatch-glob: CONTROL FAILED — the --dispatch beat did not run (rc=$RC), so the line below proves nothing: $OUT"; fi
  if has "$LIVE_LINE" && ! has "$UNAVAIL_LINE"; then ok "dispatch-glob: a --dispatch beat over a fresh transcript reports the teammate's turn"
  else bad "dispatch-glob: a --dispatch beat read a fresh transcript as no signal — noglob leaked past the id split: $OUT"; fi
  rm -rf "$W"
}

# Beat B (armed --dispatch) holds the marker; a live registered sibling A stands behind it; B's
# target lands and B exits. Its EXIT trap must hand the marker to A. A is a registration the
# fixture plants -- `.lease-<pid>` naming a process this fixture holds open -- rather than a second
# real beat, because a real A re-stamps the marker on its own next poll and would mask a holder
# that dropped it.
#
# NOTHING HERE IS BOUNDED BY TIME (BL-868). B runs on the world's injected clock and BLOCKS in its
# first poll sleep (beat_gate) until the fixture has planted A and written b.md, so "B exited before
# A registered" cannot happen however slow any step is. A is a subshell alive while the world dir
# exists, until the fixture kills it (so a `broken` exit leaves no orphan), and its registration carries an epoch no run can
# reach -- an expiring `sleep 120` and a `now + 300` epoch were the same bound twice. Every wait is
# on a condition, and ends early only when the process that must produce it is gone.
HEIR_A_PID=""; HEIR_B_PID=""; HEIR_AFTER=""
marker_pid() { mp_=""; IFS= read -r mp_ 2>/dev/null < "$1/_bmad-output/.beat-inflight"; case "$mp_" in *' '*) printf '%s' "${mp_#* }" ;; esac; }
pid_gone() { ! kill -0 "$1" 2>/dev/null; }
# An UNBOUNDED condition wait: 0 once the command holds, 1 when the pid that must make it hold is
# gone without it (the command is tried once more after the pid is gone, for a write just before exit).
wait_until() {  # $1 = pid of the producer, rest = command
  wu_p_="$1"; shift
  while :; do
    "$@" && return 0
    pid_gone "$wu_p_" && { "$@"; return; }
    "$WBL_REAL_SLEEP" 0.1
  done
}
# THE PER-BEAT GATE, ON THE WORLD'S POLL HOOK. A beat run with WBL_BEAT_TAG=<t> (a variable exported
# into that beat, never keyed on `$!`) writes `<world>/.asleep-<t>` on every poll sleep and blocks
# there until `<world>/.go-<t>` exists or the world is gone; a beat with no tag passes straight through.
# The first `.asleep-<t>` means the beat is past its arming lease, its sweep and its post-sweep lease,
# and inside its poll loop -- an event the subject's own loop produces, not a clock. Once `.go-<t>`
# exists every later poll returns at once and the beat runs out its quantum in virtual seconds, so a
# released beat always ends.
# Each poll is also numbered: poll <n> writes `.asleep-<t>.<n>` and is released by `.go-<t>.<n>` as well
# as by `.go-<t>`, so a fixture can let a beat take exactly one more poll and wait for the next.
beat_gate() {  # $1 = world
  fx_onsleep "$1" "case \"\${WBL_BEAT_TAG:-}\" in ?*) g_t_=\"\$WBL_BEAT_TAG\"; g_n_=0
  [ -f '$1/.polls-'\"\$g_t_\" ] && read -r g_n_ < '$1/.polls-'\"\$g_t_\"; g_n_=\$(( g_n_ + 1 ))
  printf '%s' \"\$g_n_\" > '$1/.polls-'\"\$g_t_\"; : > '$1/.asleep-'\"\$g_t_\"; : > '$1/.asleep-'\"\$g_t_.\$g_n_\"
  while [ ! -e '$1/.go-'\"\$g_t_\" ] && [ ! -e '$1/.go-'\"\$g_t_.\$g_n_\" ] && [ -d '$1' ]; do \"\$WBL_REAL_SLEEP\" 0.1; done ;; esac"
}
heir_world() {  # $1 = subject (in a sibling dir); leaves W, sets HEIR_*
  W="$(mk_work)"; HEIR_A_PID=""; HEIR_B_PID=""; HEIR_AFTER=""
  mk_ledger_row "$W" toolu_wbl661heir $(( $(date +%s) - 30 ))
  beat_gate "$W"
  ( cd "$W" && unset CLAUDE_CODE_SESSION_ID && export AI_DLC_WAIT_BEAT_SECS=40 AI_DLC_WAIT_POLL_SECS=1 \
      AI_DLC_WAIT_MARGIN_SECS=1 AI_DLC_MAX_WAIT_BEATS=6 AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" WBL_BEAT_TAG=B \
      AI_DLC_PROJECT_ROOT="$PWD" WFD_SELF_PID="$("$WBL_BASH" -c 'echo $PPID')" && wbl_ip "$1" --dispatch toolu_wbl661heir b.md ) > "$BEATOUT.B" 2>&1 &
  hw_bg_=$!
  wait_until "$hw_bg_" test -e "$W/.asleep-B" || { wait "$hw_bg_"; broken "heir: the --dispatch beat exited before its first poll sleep"; }
  HEIR_B_PID="$(marker_pid "$W")"
  ( while [ -d "$W" ]; do "$WBL_REAL_SLEEP" 0.1; done ) & HEIR_A_PID=$!
  printf '%s' 9999999999 > "$W/_bmad-output/.wait-beats/.lease-$HEIR_A_PID" || broken "heir: cannot plant A's registration"
  printf 'b\n' > "$W/b.md"
  : > "$W/.go-B"
  wait "$hw_bg_"
  HEIR_AFTER="$(marker_pid "$W")"
  kill "$HEIR_A_PID" 2>/dev/null; wait "$HEIR_A_PID" 2>/dev/null
  return 0
}
S18b_dispatch_holder_hands_off() {
  heir_world "$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  if [ -n "$HEIR_B_PID" ] && [ "$HEIR_B_PID" != "$HEIR_A_PID" ]; then ok "dispatch-heir: CONTROL — the --dispatch beat held the marker while its sibling registered"
  else bad "dispatch-heir: CONTROL FAILED — B ('$HEIR_B_PID') did not hold the marker apart from A ('$HEIR_A_PID')"; fi
  if [ -n "$HEIR_AFTER" ] && [ "$HEIR_AFTER" = "$HEIR_A_PID" ]; then ok "dispatch-heir: a --dispatch holder that exits hands the marker to the live sibling"
  else bad "dispatch-heir: after the --dispatch holder exited the marker names '$HEIR_AFTER', not the live sibling $HEIR_A_PID — its heir scan never globbed"; fi
  rm -rf "$W"
}

# ===========================================================================
# 19. --dispatch TAKES EVERY DECLARED ID PREFIX, READ FROM ITS ONE DECLARATION.
#     A local-model lead's dispatch id is `call_<32 hex>`. The subject once matched `toolu_*`
#     alone, so a `call_` id fell to the agentId arm and refused for a missing meta.json. The
#     prefixes are declared once, in the sibling validate-adversarial-convergence.sh; the arms
#     drive a `call_` id against a seeded ledger row, a bare-hex agentId through meta.json as the
#     control that the agentId arm still runs, and a subject with no sibling, which must refuse
#     64 rather than fall back to `toolu_` alone. The ledger seeds an EPOCH row first, so the
#     subject's row is not the ledger's only one.
# ===========================================================================
CALL_ID="call_45aba045bf78553ca703fc8694de7577"
call_world() {  # $1 = subject -> W, OUT, RC; a --status read of a path written after the dispatch
  W="$(mk_work)"; cw_e_=$(( $(date +%s) - 60 ))
  mk_ledger_row "$W" toolu_wbl649epoch $(( cw_e_ - 600 ))
  mk_ledger_row "$W" "$CALL_ID" "$cw_e_"
  printf 'x\n' > "$W/deliv.md"
  ( cd "$W" && unset CLAUDE_CODE_SESSION_ID && export AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
      AI_DLC_PROJECT_ROOT="$PWD" && wbl_ip "$1" --status --dispatch "$CALL_ID" deliv.md ) > "$BEATOUT" 2>&1
  RC=$?; OUT="$(cat "$BEATOUT")"
}
S19a_dispatch_call_prefix() {
  call_world "$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  if [ "$RC" -eq 0 ] && has "DELIVERED deliv.md"; then ok "dispatch-call: a call_ dispatch id resolves its ledger row and joins from it"
  else bad "dispatch-call: a call_ dispatch id did not resolve (rc=$RC): $OUT"; fi
  rm -rf "$W"
  # CONTROL: a bare-hex agentId still takes the meta.json arm and reaches the same row.
  W="$(mk_work)"; TD="$TMPROOT/s19-td.$$"; mkdir -p "$TD"
  mk_ledger_row "$W" "$CALL_ID" $(( $(date +%s) - 60 ))
  printf '{"agentType":"dev","toolUseId":"%s"}' "$CALL_ID" > "$TD/agent-a649beef.meta.json"
  printf 'x\n' > "$W/deliv.md"
  s19a_sd_="$(sib_dir "$SUBJ")"
  ( cd "$W" && unset CLAUDE_CODE_SESSION_ID && export AI_DLC_TEAMMATE_DIR="$TD" \
      AI_DLC_PROJECT_ROOT="$PWD" && wbl_ip "$s19a_sd_/wait-for-deliverable.sh" --status --dispatch a649beef deliv.md ) > "$BEATOUT" 2>&1
  RC=$?; OUT="$(cat "$BEATOUT")"
  if [ "$RC" -eq 0 ] && has "DELIVERED deliv.md"; then ok "dispatch-call: CONTROL — a bare-hex agentId still resolves through its meta.json"
  else bad "dispatch-call: CONTROL FAILED — the agentId arm no longer resolves (rc=$RC): $OUT"; fi
  rm -rf "$W"
}
S19b_dispatch_grammar_missing_refuses() {
  LONE649="$(mktemp -d "$TMPROOT/lone649.XXXXXX")"; cp "$SUBJ" "$LONE649/wait-for-deliverable.sh" || broken "cannot copy the subject"
  call_world "$LONE649/wait-for-deliverable.sh"
  if [ "$RC" -eq 64 ] && has "cannot read its id grammar"; then ok "dispatch-call: a subject with no sibling grammar refuses --dispatch (exit 64)"
  else bad "dispatch-call: a missing id grammar did not refuse (rc=$RC) — a silent fallback: $OUT"; fi
  rm -rf "$W"
  # CONTROL: the same lone copy without --dispatch still runs, so the refusal is the grammar's.
  W="$(mk_work)"
  ( cd "$W" && unset CLAUDE_CODE_SESSION_ID && export AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
      AI_DLC_PROJECT_ROOT="$PWD" && wbl_ip "$LONE649/wait-for-deliverable.sh" --status --since "$(( $(date +%s) - 60 ))" deliv.md ) > "$BEATOUT" 2>&1
  RC=$?; OUT="$(cat "$BEATOUT")"
  if [ "$RC" -eq 0 ] && has "STATUS --"; then ok "dispatch-call: CONTROL — the same lone copy without --dispatch runs"
  else bad "dispatch-call: CONTROL FAILED — the lone copy does not run at all (rc=$RC): $OUT"; fi
  # A DUPLICATED declaration refuses too: two lines are two grammars, and picking one is a guess.
  SD="$(sib_dir "$SUBJ")"
  printf '\nDISPATCH_ID_PREFIXES="toolu_"\n' >> "$SD/validate-adversarial-convergence.sh"
  call_world "$SD/wait-for-deliverable.sh"
  if [ "$RC" -eq 64 ]; then ok "dispatch-call: a duplicated DISPATCH_ID_PREFIXES declaration refuses (exit 64)"
  else bad "dispatch-call: a duplicated declaration was accepted (rc=$RC): $OUT"; fi
  rm -rf "$W" "$LONE649"
}

# ===========================================================================
# 19c. THE --since-WITHOUT---dispatch WARN FIRES ON A BEAT THAT ARMS A TARGET, AND ONLY THEN.
#      It once printed on every --since-only invocation, continuation beats and --status included,
#      so a lead re-arming the same wave read the same advice dozens of times and learned to skip
#      it. The emission sits in the sweep at FIRST=1 (the sidecar did not exist before this beat).
#      Rows: the first arm warns; a continuation is silent; --reset warns; a wave adding a target
#      warns once; a target delivered on its arming beat warns; --status is silent; a path
#      delivered and then re-armed in a later round warns again (delivery removes the sidecar);
#      an --own-job arming beat is silent, and its exhaustion prints the own-job remedy alone.
# ===========================================================================
S19C_WARN="WARN: wait-for-deliverable: --since without --dispatch"
s19c_beat() {  # $1 = subject, $2 = workdir; rest = argv (the targets are named by the caller)
  s19c_subj="$1" s19c_w="$2"; shift 2
  ( cd "$s19c_w" && unset CLAUDE_CODE_SESSION_ID && export \
        AI_DLC_WAIT_BEAT_SECS=2 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=1 \
        AI_DLC_MAX_WAIT_BEATS="${S19C_MAXB:-6}" AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
        AI_DLC_PROJECT_ROOT="$PWD" && wbl_ip "$s19c_subj" "$@" ) > "$BEATOUT" 2>&1
  RC=$?; OUT="$(cat "$BEATOUT")"
  s19c_n="$(grep -cF "$S19C_WARN" "$BEATOUT")" || s19c_n=0
}
s19c_world() {  # $1 = subject -> W19C_1..W19C_8 (WARN counts) and W19C_DEL (delivered on the arming beat)
  s19c_w="$(mk_work)"; s19c_s="$(( $(date +%s) - 60 ))"
  s19c_beat "$1" "$s19c_w" --since "$s19c_s" pend.md;                        W19C_1="$s19c_n"
  s19c_beat "$1" "$s19c_w" --since "$s19c_s" pend.md;                        W19C_2="$s19c_n"
  s19c_beat "$1" "$s19c_w" --reset --since "$s19c_s" pend.md;                W19C_3="$s19c_n"
  s19c_beat "$1" "$s19c_w" --since "$s19c_s" pend.md pend2.md pend3.md;      W19C_4="$s19c_n"
  s19c_beat "$1" "$s19c_w" --status --since "$s19c_s" pend.md pend2.md;      W19C_6="$s19c_n"
  s19c_d="$(mk_work)"; printf 'x\n' > "$s19c_d/deliv.md"
  s19c_beat "$1" "$s19c_d" --since "$s19c_s" deliv.md;                       W19C_5="$s19c_n"
  case "$OUT" in *"DELIVERED deliv.md"*) W19C_DEL=1 ;; *) W19C_DEL=0 ;; esac
  rm -f "$s19c_d/deliv.md"
  s19c_beat "$1" "$s19c_d" --since "$s19c_s" deliv.md;                       W19C_7="$s19c_n"
  # Row 8: an arming beat that passes --dispatch (the shape the step files prescribe) is silent.
  s19c_e="$(mk_work)"; mk_ledger_row "$s19c_e" toolu_wbl764disp $(( s19c_s + 30 ))
  s19c_beat "$(sib_dir "$1")/wait-for-deliverable.sh" "$s19c_e" --since "$s19c_s" --dispatch toolu_wbl764disp pend.md; W19C_8="$s19c_n"
  W19C_8RC="$RC"; W19C_8OUT="$OUT"
  # Row 9: an --own-job arming beat (--since, no --dispatch) is silent; row 10: its second beat
  # exhausts a one-beat sequence and prints the own-job remedy. The log predates the join, so it
  # buys no progress grant.
  s19c_o="$(mk_work)"; : > "$s19c_o/job.log"
  fx_backdate "$s19c_o/job.log" 3600 || broken "cannot backdate job.log"
  S19C_MAXB=1
  s19c_beat "$1" "$s19c_o" --own-job --since "$s19c_s" --progress-path job.log sent; W19C_9="$s19c_n"; W19C_9OUT="$OUT"
  s19c_beat "$1" "$s19c_o" --own-job --since "$s19c_s" --progress-path job.log sent; W19C_10RC="$RC"; W19C_10OUT="$OUT"
  S19C_MAXB=6
  rm -rf "$s19c_w" "$s19c_d" "$s19c_e" "$s19c_o"
}
S19c_since_warn_fires_on_arming_only() {
  s19c_world "$SUBJ"
  [ "$W19C_1" -eq 1 ] && ok "since-warn: the first arm warns once" || bad "since-warn: the first arm printed $W19C_1 WARN line(s), want 1"
  [ "$W19C_2" -eq 0 ] && ok "since-warn: a continuation beat is silent" || bad "since-warn: a continuation beat printed $W19C_2 WARN line(s), want 0"
  [ "$W19C_3" -eq 1 ] && ok "since-warn: --reset re-arms from a typed stamp and warns" || bad "since-warn: --reset printed $W19C_3 WARN line(s), want 1"
  [ "$W19C_4" -eq 1 ] && ok "since-warn: a wave adding targets warns once" || bad "since-warn: a wave adding targets printed $W19C_4 WARN line(s), want 1"
  [ "$W19C_DEL" -eq 1 ] || bad "since-warn: CONTROL FAILED — the target did not deliver on its arming beat: $OUT"
  [ "$W19C_5" -eq 1 ] && ok "since-warn: a target delivered on its arming beat warns" || bad "since-warn: delivered-on-arming printed $W19C_5 WARN line(s), want 1"
  [ "$W19C_6" -eq 0 ] && ok "since-warn: --status is silent" || bad "since-warn: --status printed $W19C_6 WARN line(s), want 0"
  [ "$W19C_7" -eq 1 ] && ok "since-warn: a path delivered then re-armed in a later round warns again" || bad "since-warn: the re-armed path printed $W19C_7 WARN line(s), want 1"
  case "$W19C_8OUT" in *"pend.md"*) : ;; *) bad "since-warn: CONTROL FAILED — the --dispatch arming beat did not run (rc=$W19C_8RC): $W19C_8OUT" ;; esac
  [ "$W19C_8" -eq 0 ] && ok "since-warn: an arming beat that passes --dispatch is silent" || bad "since-warn: an arming beat with --dispatch printed $W19C_8 WARN line(s), want 0"
  case "$W19C_9OUT" in *"WAITING   sent"*) : ;; *) bad "since-warn: CONTROL FAILED — the --own-job arming beat did not run: $W19C_9OUT" ;; esac
  [ "$W19C_9" -eq 0 ] && ok "since-warn: an --own-job arming beat is silent" || bad "since-warn: an --own-job arming beat printed $W19C_9 WARN line(s), want 0"
  case "$W19C_10OUT" in
    *"NON-DELIVERY sent -- absent after 1 beats"*"OWN JOB: this sentinel is your own background job's. Never re-dispatch or re-run it"*"stop it by its own background task id (never by pattern)"*"SendMessage BLOCKED with that"*)
      case "$W19C_10OUT" in
        *"Re-dispatch the"*|*"Do NOT keep beating"*) bad "own-job: the exhaust text still carries the re-dispatch remedy: $W19C_10OUT" ;;
        *) [ "$W19C_10RC" -eq 1 ] && ok "own-job: exhaustion prints the own-job remedy, not the re-dispatch one (rc 1)" \
             || bad "own-job: exhaustion exited $W19C_10RC, want 1: $W19C_10OUT" ;;
      esac ;;
    *) bad "own-job: exhaustion did not print the own-job remedy (rc=$W19C_10RC): $W19C_10OUT" ;;
  esac
}

# ===========================================================================
# 20. THE LEASE IS HELD BEFORE ANY STEP THAT CAN BLOCK.
#     The stop hook allows the lead's yield only while `.beat-inflight` is live. A beat that
#     blocks before writing it reads to the hook as "no beat armed" while one is. Two blocking
#     steps are forced, each on a FIFO this fixture holds open: the --dispatch ledger read
#     (20a, which the lease once followed) and the sweep's --shard-header check (20b, which it
#     already preceded -- a pin). Each case first proves the beat REACHED the blocking read (the
#     FIFO's writer opens only once a reader has); a beat that exits without reaching it is
#     FIXTURE BROKEN, exit 2, never a FAIL. Nothing here reads a clock, and nothing is bounded by one.
# ===========================================================================
BLK_PID=""; BLK_MARK=""
# THE SECOND OPEN CANNOT BLOCK. Before the release the path is replaced by a REGULAR file holding the same
# line: the beat already blocked in read() keeps the FIFO it opened, and every later open of the path reads
# the file and returns. The beat then always ends, and is waited for plainly -- no elapsed-time bound decides
# BLK_MARK, the arm's own assertion (BL-868).
fifo_hold() {  # $1 = fifo, $2 = reached file, $3 = release file, $4 = the line: opens the writer, records it, holds until released
  printf '%s\n' "${4:-}" > "$1.after" || broken "lease: cannot write the FIFO's replacement"
  ( exec 3> "$1"; : > "$2"; while [ ! -e "$3" ] && [ -d "${3%/*}" ]; do "$WBL_REAL_SLEEP" 0.1; done; printf '%s\n' "${4:-}" >&3 ) &
  FH_PID=$!
}
blocked_lease() {  # $1 = workdir, $2 = reached file, $3 = release file, $4 = the fifo; reads BLK_PID; sets BLK_MARK
  wait_until "$BLK_PID" test -e "$2" || { : > "$3"; kill "$FH_PID" 2>/dev/null; wait "$FH_PID" 2>/dev/null; broken "lease: the beat exited without reaching its blocking read"; }
  BLK_MARK=0; [ -n "$(marker_pid "$1")" ] && [ "$(marker_pid "$1")" = "$BLK_PID" ] && BLK_MARK=1
  mv -f "$4.after" "$4" || broken "lease: cannot replace the FIFO before the release"
  : > "$3"
  wait "$FH_PID" 2>/dev/null
  wait "$BLK_PID" 2>/dev/null
}
ledger_fifo_world() {  # $1 = subject (in a sibling dir); leaves W, sets BLK_MARK
  W="$(mk_work)"; fx_clock_off "$W"; command -v mkfifo >/dev/null || broken "no mkfifo"
  mkfifo "$W/_bmad-output/spawn-ledger.jsonl" || broken "cannot make the ledger a FIFO"
  fifo_hold "$W/_bmad-output/spawn-ledger.jsonl" "$W/reached" "$W/release" \
    "{\"v\":1,\"ts\":\"$(fx_iso $(( $(date +%s) - 30 )))\",\"name\":\"wbl\",\"tool_use_id\":\"toolu_wbl541\"}"
  ( cd "$W" && unset CLAUDE_CODE_SESSION_ID && export AI_DLC_WAIT_BEAT_SECS=2 AI_DLC_WAIT_POLL_SECS=1 \
      AI_DLC_WAIT_MARGIN_SECS=1 AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
      AI_DLC_PROJECT_ROOT="$PWD" WFD_SELF_PID="$("$WBL_BASH" -c 'echo $PPID')" && wbl_ip "$1" --dispatch toolu_wbl541 deliv.md ) > "$BEATOUT" 2>&1 &
  BLK_PID=$!
  blocked_lease "$W" "$W/reached" "$W/release" "$W/_bmad-output/spawn-ledger.jsonl"
  OUT="$(cat "$BEATOUT")"
}
S20a_lease_before_dispatch_read() {
  ledger_fifo_world "$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  if has "WAITING   deliv.md"; then ok "lease-early: CONTROL — the beat blocked on the ledger resumed and ran once the row arrived"
  else bad "lease-early: CONTROL FAILED — the beat over a FIFO ledger never ran a beat: $OUT"; fi
  if [ "$BLK_MARK" -eq 1 ]; then ok "lease-early: a --dispatch beat blocked reading the spawn ledger already holds .beat-inflight"
  else bad "lease-early: a --dispatch beat blocked on the ledger held no lease — the stop hook sees no beat while one is armed"; fi
  rm -rf "$W"
}
S20b_lease_before_shard_check() {
  SD="$(sib_dir "$SUBJ")"; W="$(mk_work)"; fx_clock_off "$W"; command -v mkfifo >/dev/null || broken "no mkfifo"
  mkfifo "$W/hdr.fifo" || broken "cannot make the header FIFO"
  # The stub merge: records that the sweep reached it, then blocks reading the FIFO; exits 0 (header passes).
  printf '#!/usr/bin/env bash\n: > "%s/reached"\nIFS= read -r _ < "%s/hdr.fifo"\nexit 0\n' "$W" "$W" > "$SD/merge-adversarial-shards.sh"
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/s.md"
  fifo_hold "$W/hdr.fifo" "$W/held" "$W/release" go
  ( cd "$W" && unset CLAUDE_CODE_SESSION_ID && export AI_DLC_WAIT_BEAT_SECS=2 AI_DLC_WAIT_SETTLE_SECS=1 AI_DLC_WAIT_POLL_SECS=1 \
      AI_DLC_WAIT_MARGIN_SECS=0 AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
      AI_DLC_PROJECT_ROOT="$PWD" WFD_SELF_PID="$("$WBL_BASH" -c 'echo $PPID')" && wbl_ip "$SD/wait-for-deliverable.sh" --since "$(( $(date +%s) - 30 ))" --complete --shard-header convergence s.md ) > "$BEATOUT" 2>&1 &
  BLK_PID=$!
  blocked_lease "$W" "$W/reached" "$W/release" "$W/hdr.fifo"
  OUT="$(cat "$BEATOUT")"
  if [ -e "$W/reached" ]; then ok "lease-early: CONTROL — the sweep reached the stub header check"
  else bad "lease-early: CONTROL FAILED — the sweep never ran the header check: $OUT"; fi
  if [ "$BLK_MARK" -eq 1 ]; then ok "lease-early: a beat blocked inside the sweep's header check already holds .beat-inflight"
  else bad "lease-early: a beat blocked in the sweep's header check held no lease"; fi
  rm -rf "$W"
}

# ===========================================================================
# 21. THE LEASE IS WHERE THE STOP HOOK LOOKS, WHATEVER AI_DLC_STATE_DIR SAYS.
#     The hook reads `<root>/_bmad-output/.beat-inflight` and never sees AI_DLC_STATE_DIR (lead
#     beats set it as a per-command prefix). So a beat armed with a custom state dir holds its
#     marker and its registration at the root's `_bmad-output`, while its counters stay in the
#     custom dir -- the control that the state dir was honoured at all.
# ===========================================================================
cs_counter_written() { for cw_ in "$1"/_bmad-output/seat-q/.wait-beats/*; do [ -f "$cw_" ] && return 0; done; return 1; }
# Read once, at the beat's first poll sleep (beat_gate): by then the beat has armed its lease, swept (its
# counters are written) and re-stamped the lease before the loop, so the marker is where it will ever be.
# There is no wait on the marker (BL-868).
custom_state_world() {  # $1 = subject; leaves W, sets CS_MARK (holder pid at root, or ''), CS_LEASE, CS_CTR
  W="$(mk_work)"; CS_MARK=""; CS_LEASE=0; CS_CTR=0
  beat_gate "$W"
  ( cd "$W" && unset CLAUDE_CODE_SESSION_ID && export AI_DLC_STATE_DIR=_bmad-output/seat-q AI_DLC_WAIT_BEAT_SECS=40 \
      AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=1 AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" WBL_BEAT_TAG=C \
      AI_DLC_PROJECT_ROOT="$PWD" WFD_SELF_PID="$("$WBL_BASH" -c 'echo $PPID')" && wbl_ip "$1" deliv.md ) > "$BEATOUT" 2>&1 &
  cs_p_=$!
  wait_until "$cs_p_" test -e "$W/.asleep-C" || { wait "$cs_p_"; broken "custom-state: the beat exited before its first poll sleep"; }
  cs_counter_written "$W" && CS_CTR=1
  CS_MARK="$(marker_pid "$W")"
  [ -f "$W/_bmad-output/.wait-beats/.lease-$cs_p_" ] && CS_LEASE=1
  printf 'x\n' > "$W/deliv.md"
  : > "$W/.go-C"
  wait "$cs_p_" 2>/dev/null
  CS_PID="$cs_p_"
}
S21_lease_at_root_under_custom_state_dir() {
  custom_state_world "$SUBJ"
  if [ "$CS_CTR" -eq 1 ]; then ok "custom-state: CONTROL — the beat's counters land in its custom state dir"
  else bad "custom-state: CONTROL FAILED — no counter in the custom state dir"; fi
  if [ "$CS_MARK" = "$CS_PID" ] && [ "$CS_LEASE" -eq 1 ]; then ok "custom-state: a beat armed with a custom AI_DLC_STATE_DIR holds its marker and registration at the root _bmad-output"
  else bad "custom-state: marker at the root names '$CS_MARK' (beat $CS_PID), registration=$CS_LEASE — the stop hook cannot see this beat"; fi
  rm -rf "$W"
}
# THE REGISTRATIONS MOVE WITH THE MARKER. Beat B (default state dir) holds the marker; beat A,
# armed with a custom state dir, registers behind it; B's target lands and B exits. B's heir scan
# must find A, so A's `.lease-<pid>` has to sit where B scans. A's post-sweep beat_alive (the one
# before its poll loop) CAN re-take the marker when it sees no registration for B, so b.md is
# written only once A is past it and blocked in its first poll sleep, and only
# once the marker names B again (B's next poll re-takes a marker A took).
# ON THE WORLD'S CLOCK, GATED PER POLL (BL-868). Both beats share the world's injected clock and its poll
# hook (beat_gate), each under its own tag, so the order is fixed by events and no real second passes in
# any sleep. In virtual seconds from B's arming t0: B arms, sweeps, holds the marker (epoch t0+3) and
# blocks in poll 1 at t0+1; A arms at t0+1 (B's registration is live, so the fixed A leaves the marker
# alone), and blocks in its 30s poll at
# t0+31; B's poll 1 is released, B re-takes the now-expired marker and blocks in poll 2 at t0+32; b.md is
# written and B released, delivers and exits. A's registration reads t0+91 > t0+32 and A is alive, so the
# heir scan finds it exactly when it scans the directory A registered in. The real clock enters only as
# b.md's mtime, which is after the join epoch whatever the load.
cross_heir_world() {  # $1 = subject; leaves W, sets XH_A, XH_B, XH_AFTER
  W="$(mk_work)"; XH_A=""; XH_B=""; XH_AFTER=""
  beat_gate "$W"
  ( cd "$W" && unset CLAUDE_CODE_SESSION_ID && export AI_DLC_WAIT_BEAT_SECS=40 AI_DLC_WAIT_POLL_SECS=1 \
      AI_DLC_WAIT_MARGIN_SECS=1 AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" WBL_BEAT_TAG=B \
      AI_DLC_PROJECT_ROOT="$PWD" WFD_SELF_PID="$("$WBL_BASH" -c 'echo $PPID')" && wbl_ip "$1" b.md ) > "$BEATOUT.B" 2>&1 &
  XH_B=$!
  xh_stop_() { : > "$W/.go-A"; : > "$W/.go-B"; wait "$XH_A" 2>/dev/null; wait "$XH_B" 2>/dev/null; broken "cross-heir: $1"; }
  wait_until "$XH_B" test -e "$W/.asleep-B.1" || xh_stop_ "beat B exited before its first poll sleep"
  ( cd "$W" && unset CLAUDE_CODE_SESSION_ID && export AI_DLC_STATE_DIR=_bmad-output/seat-q AI_DLC_WAIT_BEAT_SECS=80 \
      AI_DLC_WAIT_POLL_SECS=30 AI_DLC_WAIT_MARGIN_SECS=1 AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" WBL_BEAT_TAG=A \
      AI_DLC_PROJECT_ROOT="$PWD" WFD_SELF_PID="$("$WBL_BASH" -c 'echo $PPID')" && wbl_ip "$1" a.md ) > "$BEATOUT.A" 2>&1 &
  XH_A=$!
  wait_until "$XH_A" test -e "$W/.asleep-A.1" || xh_stop_ "beat A exited before its first poll sleep"
  cs_counter_written "$W" || xh_stop_ "beat A swept without writing a counter in its own state dir"
  : > "$W/.go-B.1"
  wait_until "$XH_B" test -e "$W/.asleep-B.2" || xh_stop_ "beat B exited before its second poll sleep"
  [ "$(marker_pid "$W")" = "$XH_B" ] || xh_stop_ "the marker names '$(marker_pid "$W")', not B, once A was asleep"
  printf 'b\n' > "$W/b.md"
  : > "$W/.go-B"
  wait "$XH_B" 2>/dev/null
  XH_AFTER="$(marker_pid "$W")"
  : > "$W/.go-A"
  wait "$XH_A" 2>/dev/null
  return 0
}
S21b_heir_across_state_dirs() {
  cross_heir_world "$SUBJ"
  if [ "$XH_AFTER" = "$XH_A" ]; then ok "custom-state: a holder that exits hands the marker to a live beat armed with a different state dir"
  else bad "custom-state: after the holder exited the marker names '$XH_AFTER', not the live custom-state beat $XH_A — the heir scan cannot see its registration"; fi
  rm -rf "$W"
}

# ===========================================================================
# 22. A CHAINED BEAT IS RECOGNISED BY ITS SHELL, NOT BY HOW RECENTLY ITS SIBLING RAN.
#     The guard once called a sibling "chained" only if its stamp was under BUDGET old, so a
#     loaded box that delayed the second call fails it open and serialises a second quantum.
#     The marker now carries the parent shell's start time. One wrapper shell runs a REAL first
#     beat (short quantum), which writes the marker in the subject's own format; the wrapper then
#     ages that marker 2 x BUDGET (its stamp and its mtime, past the prune age), and for the
#     control replaces the start time with one no live process has (a recycled pid). A second beat
#     from the same wrapper must then not sleep, and the control must. The trailing `exit $?`
#     keeps bash from exec-ing the subject, so both beats' $PPID is the wrapper.
# ===========================================================================
# In process both beats run in ONE subshell, whose parent shell -- the subject's $PPID -- is this
# fixture's parent: one real process with a real start time, so the first beat writes the marker
# in the subject's own format and the second, from the same shell, reads it (WBL_CHAIN keeps it).
# Both run on the world's injected clock. A sleeping second beat would run its whole 60s quantum;
# its first poll sleep delivers deliv.md (the poll hook, set only after the first beat), so the arm
# reads which return it TOOK -- the chained NOTE, or DELIVERED after a sleep -- never how long it took.
aged_shell_beat() {  # $1 = subject, $2 = workdir, $3 = same|other, [$4 = a dir put first on PATH for the SECOND beat only] -> OUT, RC
  ( cd "$2" && unset CLAUDE_CODE_SESSION_ID && export AI_DLC_WAIT_POLL_SECS=1 \
      AI_DLC_WAIT_MARGIN_SECS=1 AI_DLC_MAX_WAIT_BEATS=6 AI_DLC_TEAMMATE_DIR="$TMPROOT/does-not-exist" \
      AI_DLC_PROJECT_ROOT="$2" || exit 3
    ( AI_DLC_WAIT_BEAT_SECS=2 wbl_ip "$1" first.md ) > /dev/null 2>&1
    m="_bmad-output/.wait-beats/.shell-$PPID"; [ -f "$m" ] || exit 3
    r="$(cat "$m")"; r="$(( $(fx_now "$2") - 120 ))${r#"${r%% *}"}"
    [ "$3" = other ] && r="${r%% *} Thu Jan 1 00:00:00 1970"
    printf "%s" "$r" > "$m" || exit 3
    fx_backdate "$m" 300 || exit 3   # on the world's clock: past the prune age whatever the steps cost
    fx_onsleep "$2" "[ -e '$2/deliv.md' ] || { printf 'x\n' > '$2/deliv.md'; fx_vtouch '$2/deliv.md'; }"
    case "${4:-}" in "") ;; =*) PATH="${4#=}" ;; *) PATH="$4:$PATH" ;; esac
    WBL_CHAIN=1 AI_DLC_WAIT_BEAT_SECS=60 wbl_ip "$1" deliv.md ) > "$BEATOUT" 2>&1
  RC=$?; OUT="$(cat "$BEATOUT")"
  [ "$RC" -ne 3 ] || broken "chained: the first beat left no .shell marker for its shell"
}
S22_chained_by_shell_identity() {
  W="$(mk_work)"; aged_shell_beat "$SUBJ" "$W" same
  if [ "$RC" -eq 0 ] && has "a sibling beat already ran in this same Bash call"; then
    ok "chained: a same-shell sibling stamped 2 x BUDGET ago still reads as chained — the beat does not sleep"
  else bad "chained: a same-shell sibling older than BUDGET let the beat sleep a second quantum (rc=$RC): $OUT"; fi
  rm -rf "$W"
  W="$(mk_work)"; aged_shell_beat "$SUBJ" "$W" other
  if [ "$RC" -eq 0 ] && ! has "a sibling beat already ran in this same Bash call" && has "DELIVERED deliv.md"; then
    ok "chained: CONTROL — a marker naming another start time (a recycled pid) sleeps"
  else bad "chained: CONTROL FAILED — a different-shell marker was read as chained (rc=$RC): $OUT"; fi
  rm -rf "$W"
}
# ===========================================================================
# 22b. THE START TIME SURVIVES A `ps` THAT CANNOT RUN (BL-686). `/bin/ps` is setuid root and
#      `sandbox-exec` refuses to exec it, so under a sandboxed harness the identity test had no
#      input and every beat fell back to the clock. The FIRST beat writes its marker with the real
#      `ps`; the SECOND beat runs with a PATH `ps` that exits 1, so its start time can come only from
#      the perl fallback -- and it must read EQUAL to what `ps` wrote, or the chained call sleeps.
#      Both beats run under LC_ALL=de_DE.UTF-8, where an unpinned `ps` prints German day names and
#      perl's localtime prints English, so the arm also holds the pin. CONTROL: `ps` AND `perl` both
#      stubbed -- no start time at all, the clock test decides, and the 2 x BUDGET-old marker sleeps.
# ===========================================================================
nops_stubs() {  # -> $TMPROOT/nops (a `ps` that exits 1) and $TMPROOT/nops/both (that `ps` and a `perl` that exits 1)
  sb_d_="$TMPROOT/nops"; mkdir -p "$sb_d_/both" || broken "cannot create the ps stub dirs"
  printf '#!/bin/bash\nexit 1\n' > "$sb_d_/ps" && chmod +x "$sb_d_/ps" && cp "$sb_d_/ps" "$sb_d_/both/ps" && cp "$sb_d_/ps" "$sb_d_/both/perl" \
    || broken "cannot write the ps/perl stubs"
  [ "$(PATH="$sb_d_:$PATH" command -v ps)" = "$sb_d_/ps" ] || broken "the ps stub is not first on PATH"
}
# PERL IS OPTIONAL (BL-686). S22b needs the fallback to read what `ps` reads, and needs
# de_DE.UTF-8 to move an unpinned `ps`. Probed ONCE, through the SUBJECT's own INLINE wfd_start_of
# (the fallback under `if ! declare -F`). S22b and S22c drive $SUBJ
# in place, beside its helper, so they exercise the helper's copy; S26 holds the two ranges
# byte-identical. On a miss S22b prints SKIP by name -- never `broken`.
# FB_OK caches the answer.
FB_OK=""
fb_probe() {
  [ -n "$FB_OK" ] && return 0
  nops_stubs
  fb_f_="$(sed -n '/^wfd_start_of() {/,/^}/p' "$SUBJ")"
  [ -n "$fb_f_" ] || broken "could not extract the inline wfd_start_of from $SUBJ"
  fb_real_="$(eval "$fb_f_"; wfd_start_of $$)"
  fb_stub_="$(eval "$fb_f_"; PATH="$TMPROOT/nops:$PATH"; wfd_start_of $$)"
  fb_de_="$(LC_ALL=de_DE.UTF-8 ps -o lstart= -p $$ 2>/dev/null)"; fb_c_="$(LC_ALL=C ps -o lstart= -p $$ 2>/dev/null)"
  FB_OK=1; FB_WHY=""
  [ -n "$fb_real_" ] && [ "$fb_stub_" = "$fb_real_" ] || { FB_OK=0; FB_WHY="with ps stubbed the perl fallback read '$fb_stub_', not '$fb_real_' -- no usable perl here (it is optional)"; }
  [ -n "$fb_de_" ] && [ "$fb_de_" != "$fb_c_" ] || { FB_OK=0; FB_WHY="${FB_WHY:+$FB_WHY; }de_DE.UTF-8 and C read the same start ('$fb_de_') -- the locale pin cannot be held"; }
  # ANTI-SKIP: the precondition computed apart from the probe above -- perl on PATH (probed, never
  # run), a Darwin kernel, and de_DE.UTF-8 moving `ps`. Under it a SKIP is a FAIL, by name.
  if command -v perl >/dev/null 2>&1 && [ "$(uname -s 2>/dev/null)" = Darwin ] && [ -n "$fb_de_" ] && [ "$fb_de_" != "$fb_c_" ]; then
    FB_MUST=1
  else FB_MUST=0; fi
}
fb_skip() {  # $1 = case name: 0 (SKIP printed, or FAIL under the anti-SKIP precondition) when the fallback cannot be exercised
  fb_probe
  [ "$FB_OK" = 1 ] && return 1
  if [ "$FB_MUST" = 1 ]; then
    bad "anti-SKIP: perl is on PATH on Darwin and de_DE.UTF-8 moves ps, yet $1 would be SKIPPED -- the fallback probe is broken: $FB_WHY"
  else printf '  SKIP  %s: %s\n' "$1" "$FB_WHY"; fi
  return 0
}
S22b_start_time_without_ps() {
  fb_skip S22b_start_time_without_ps && return
  nops_stubs
  W="$(mk_work)"; LC_ALL=de_DE.UTF-8 aged_shell_beat "$SUBJ" "$W" same "$sb_d_"
  if [ "$RC" -eq 0 ] && has "a sibling beat already ran in this same Bash call"; then
    ok "chained: with ps refused (PATH stub, as sandbox-exec refuses the setuid /bin/ps) the perl fallback reads the start ps wrote -- still chained, no second quantum"
  else bad "chained: with ps refused, a same-shell sibling stamped past BUDGET let the beat sleep (rc=$RC): $OUT"; fi
  rm -rf "$W"
  W="$(mk_work)"; LC_ALL=de_DE.UTF-8 aged_shell_beat "$SUBJ" "$W" same "$sb_d_/both"
  if [ "$RC" -eq 0 ] && ! has "a sibling beat already ran in this same Bash call" && has "DELIVERED deliv.md"; then
    ok "chained: CONTROL — with ps AND perl refused there is no start time, the clock decides, and the aged marker sleeps"
  else bad "chained: CONTROL FAILED — with ps and perl both refused the aged marker still read as chained (rc=$RC): $OUT"; fi
  rm -rf "$W"
}
# 22c. NO PERL AT ALL (BL-686, the lead's ruling: perl is optional). The second beat runs on a PATH
#      that is ONLY a directory of links to this fixture's declared tools, with perl left out and a
#      `ps` that prints nothing and exits 0. The beat has no start time, so it must say once, on
#      stderr, that the guard decides by the clock -- never fall back silently.
NOPERL_LINE='-- the chained-beat guard decides by the clock alone this beat'
noperl_path() {  # -> $TMPROOT/noperl: links to every tools.decl tool except perl and ps, plus a ps that prints nothing
  np_d_="$TMPROOT/noperl"; mkdir -p "$np_d_" || broken "cannot create the no-perl PATH dir"
  while IFS= read -r np_t_; do
    case "$np_t_" in ''|'#'*|perl|ps) continue ;; esac
    np_p_="$(command -v "$np_t_")" || broken "tools.decl names $np_t_, which is not on PATH"
    # date and sleep resolve to the clock SHIMS (bash scripts) while the shim dir is on PATH; linking a shim
    # would make every poll of a real-clock beat a counted bash start, so the link is the real binary.
    case "$np_t_" in date) np_p_="$WBL_REAL_DATE" ;; sleep) np_p_="$WBL_REAL_SLEEP" ;; esac
    ln -sf "$np_p_" "$np_d_/$np_t_" || broken "cannot link $np_t_"
  done < "$HERE/tools.decl"
  printf '#!/bin/bash\nexit 0\n' > "$np_d_/ps" && chmod +x "$np_d_/ps" || broken "cannot write the empty ps stub"
  [ -z "$(PATH="$np_d_" command -v perl)" ] && [ "$(PATH="$np_d_" command -v ps)" = "$np_d_/ps" ] \
    || broken "the no-perl PATH still finds perl, or not the empty ps"
}
np_count() { printf '%s\n' "$OUT" | grep -cF -- "$NOPERL_LINE" || true; }
S22c_no_perl_states_clock_fallback() {
  noperl_path
  W="$(mk_work)"; aged_shell_beat "$SUBJ" "$W" same "=$TMPROOT/noperl"
  np_n_="$(np_count)"
  if [ "$RC" -eq 0 ] && [ "$np_n_" = 1 ] && has "DELIVERED deliv.md"; then
    ok "no perl: with ps empty and perl absent from PATH the beat states its clock fallback exactly once on stderr"
  else bad "no perl: the clock-fallback line appeared $np_n_ time(s), want 1 (rc=$RC): $OUT"; fi
  rm -rf "$W"
  W="$(mk_work)"; aged_shell_beat "$SUBJ" "$W" same
  np_n_="$(np_count)"
  if [ "$np_n_" = 0 ] && has "a sibling beat already ran in this same Bash call"; then
    ok "no perl: CONTROL — with ps working the line is absent and identity decides"
  else bad "no perl: CONTROL FAILED — with ps working the clock-fallback line appeared $np_n_ time(s): $OUT"; fi
  rm -rf "$W"
}

# ===========================================================================
# 23. A TEAMMATE WHOSE MODEL IS NOT ANSWERING IS STALLED, NOT LIVE.
#     The harness appends a `{"type":"api-request"` line per request it sends, answered or not.
#     Keyed on mtime, seven unanswered retries read as seven fresh turns. Every seed below has a
#     FRESH mtime; only its lines differ. 3 trailing requests after the last assistant line is
#     STALLED; 2 is not (live runs of 2 occur); `api-request-blob` lines do not count; a recent
#     assistant line last is the control. A wedged transcript's last TURN is old even though the
#     file is new, so with a short idle threshold it also reads IDLE -- which the mtime sensor
#     could never say. Under --dispatch the dispatched agent's transcript is judged by name, so a
#     live sibling does not hide it.
# ===========================================================================
mk_wedged() {  # $1 = dir, $2 = basename, $3 = trailing request lines, $4 = line type (api-request|api-request-blob)
  mkdir -p "$1" || broken "cannot create $1"
  mw_e_="$(fx_seed_now)"; mw_old_="$(fx_iso $(( mw_e_ - 3600 )))"; mw_now_="$(fx_iso "$mw_e_")"
  { printf '{"parentUuid":"u1","isSidechain":true,"agentId":"a1","message":{"role":"assistant","content":[{"type":"tool_use","name":"Skill"}]},"type":"assistant","timestamp":"%s.300Z"}\n' "$mw_old_"
    mw_i_=0; while [ "$mw_i_" -lt "$3" ]; do
      printf '{"type":"%s","sessionId":"s","agentId":"a1","id":"r%s","timestamp":"%s.200Z","shapeHash":"7d7e1ada"}\n' "$4" "$mw_i_" "$mw_now_"
      mw_i_=$(( mw_i_ + 1 )); done
  } > "$1/$2" || broken "cannot write $1/$2"
}
mk_recovered() {  # $1 = dir, $2 = basename: 3 requests, then a fresh assistant line -- the run was answered
  mkdir -p "$1" || broken "cannot create $1"
  mr_e_="$(fx_seed_now)"; mr_old_="$(fx_iso $(( mr_e_ - 3600 )))"; mr_now_="$(fx_iso "$mr_e_")"
  { printf '{"isSidechain":true,"agentId":"a1","message":{"role":"assistant"},"type":"assistant","timestamp":"%s.300Z"}\n' "$mr_old_"
    for mr_i_ in 0 1 2; do
      printf '{"type":"api-request","sessionId":"s","agentId":"a1","id":"r%s","timestamp":"%s.200Z"}\n' "$mr_i_" "$mr_now_"; done
    printf '{"isSidechain":true,"agentId":"a1","message":{"role":"assistant"},"type":"assistant","timestamp":"%s.400Z"}\n' "$mr_now_"
  } > "$1/$2" || broken "cannot write $1/$2"
}
mk_transcript_bare() {  # $1 = dir, $2 = age seconds, $3 = basename: no timestamp on any line
  mkdir -p "$1" || broken "cannot create $1"
  printf '{"t":1}\n' > "$1/$3" || broken "cannot write $1/$3"
  [ "$2" -gt 0 ] && { fx_backdate "$1/$3" "$2" || broken "cannot backdate $1/$3"; }
  return 0
}
STALL_LINE='TEAMMATE STALLED '
S23a_stalled_after_three_requests() {
  W="$(mk_work)"; MAXB=60; TD="$TMPROOT/s23a.$$"; mk_wedged "$TD" agent-awedge.jsonl 3 api-request
  beat "$SUBJ" "$W" 60 "$TD"
  if has "${STALL_LINE}agent-awedge.jsonl" && [ "$RC" -eq 0 ]; then ok "stalled: 3 unanswered api-request lines after the last assistant line report STALLED (rc 0)"
  else bad "stalled: a transcript ending in 3 unanswered requests was not reported STALLED (rc=$RC): $OUT"; fi
  if has "$IDLE_BANNER" && ! has "$LIVE_LINE"; then ok "stalled: its last TURN is an hour old though the file is fresh — not reported as a live turn"
  else bad "stalled: a fresh mtime over an hour-old last turn still read as live: $OUT"; fi
  rm -rf "$TD"
  TD="$TMPROOT/s23b.$$"; mk_wedged "$TD" agent-atwo.jsonl 2 api-request
  beat "$SUBJ" "$W" 60 "$TD"
  if ! has "$STALL_LINE"; then ok "stalled: 2 trailing api-request lines do NOT report STALLED (live runs of 2 occur)"
  else bad "stalled: 2 trailing requests were called STALLED: $OUT"; fi
  rm -rf "$TD"
  TD="$TMPROOT/s23c.$$"; mk_wedged "$TD" agent-ablob.jsonl 5 api-request-blob
  beat "$SUBJ" "$W" 60 "$TD"
  if ! has "$STALL_LINE"; then ok "stalled: api-request-blob lines are not requests and do NOT count"
  else bad "stalled: api-request-blob lines were counted as unanswered requests: $OUT"; fi
  rm -rf "$TD"
  # A run of 3 that an assistant line then ANSWERED is a recovered teammate: the run resets.
  TD="$TMPROOT/s23r.$$"; mk_recovered "$TD" agent-arecov.jsonl
  beat "$SUBJ" "$W" 60 "$TD"
  if has "$LIVE_LINE" && ! has "$STALL_LINE"; then ok "stalled: 3 requests followed by an assistant line read live, NOT STALLED (the run resets)"
  else bad "stalled: a teammate that answered after 3 requests was called STALLED or not live: $OUT"; fi
  rm -rf "$TD"
  TD="$TMPROOT/s23d.$$"; mk_transcript "$TD" 0 agent-alive.jsonl
  beat "$SUBJ" "$W" 60 "$TD"
  if has "$LIVE_LINE" && ! has "$STALL_LINE"; then ok "stalled: CONTROL — a recent assistant line last reads as a live turn, not STALLED"
  else bad "stalled: CONTROL FAILED — a live transcript did not read live: $OUT"; fi
  rm -rf "$TD"
  unset MAXB; rm -rf "$W"
}
S23b_quiet_fallback_without_timestamps() {
  W="$(mk_work)"; MAXB=60; TD="$TMPROOT/s23e.$$"; mk_transcript_bare "$TD" 7200 agent-abare.jsonl
  beat "$SUBJ" "$W" 60 "$TD"
  if has "$IDLE_BANNER"; then ok "stalled: a transcript carrying no timestamps falls back to its mtime (2h old reads IDLE)"
  else bad "stalled: a timestamp-less transcript gave no reading from its mtime: $OUT"; fi
  rm -rf "$TD"
  TD="$TMPROOT/s23f.$$"; mk_transcript_bare "$TD" 0 agent-abare.jsonl
  beat "$SUBJ" "$W" 60 "$TD"
  if has "$LIVE_LINE"; then ok "stalled: CONTROL — the same seed with a fresh mtime reads live"
  else bad "stalled: CONTROL FAILED — a fresh timestamp-less transcript is not read live: $OUT"; fi
  rm -rf "$TD"
  unset MAXB; rm -rf "$W"
}
S23c_dispatch_judges_its_own_transcript() {
  W="$(mk_work)"; TD="$TMPROOT/s23g.$$"
  mk_wedged "$TD" agent-awedge.jsonl 3 api-request
  mk_transcript "$TD" 0 agent-alive.jsonl
  printf '{"agentType":"dev","toolUseId":"toolu_wbl578"}' > "$TD/agent-awedge.meta.json"
  mk_ledger_row "$W" toolu_wbl578 $(( $(date +%s) - 30 ))
  beat "$(sib_dir "$SUBJ")/wait-for-deliverable.sh" "$W" 60 "$TD" --dispatch toolu_wbl578
  if has "${STALL_LINE}agent-awedge.jsonl" && has "$IDLE_BANNER" && ! has "$LIVE_LINE"; then
    ok "stalled: under --dispatch the dispatched agent's own transcript is judged — a live sibling does not hide the wedge"
  else bad "stalled: a live sibling hid the dispatched agent's wedge under --dispatch: $OUT"; fi
  rm -rf "$W"
  # CONTROL: the same directory without --dispatch takes the newest turn across the session.
  # The seeds were stamped on the first world's clock, so the second world reads that clock.
  W0="$W"; W="$(mk_work)"; fx_clock_copy "$W0" "$W"; beat "$SUBJ" "$W" 60 "$TD"
  if has "$LIVE_LINE" && has "${STALL_LINE}agent-awedge.jsonl"; then ok "stalled: CONTROL — without --dispatch the session reads live and still names the stalled transcript"
  else bad "stalled: CONTROL FAILED — the whole-session reading is not the live sibling's: $OUT"; fi
  rm -rf "$W" "$TD"
}

# ===========================================================================
# 24. --mark: THE SEAL DECIDES, WITH NO WINDOW, AND A LEGACY MARKER STILL SETTLES.
#     A seat closes with `--mark`, which appends `sha=<digest of everything above>` before
#     `findings=`. A sealed file DELIVERS in one beat under a settle window it could never close
#     (SETTLE=600); the same file edited above its marker is UNFINISHED under SETTLE=1 in a beat
#     long enough to settle anything, i.e. at any age; re-marked it DELIVERS again. The CONTROL is
#     a bare marker beside it in the same beat, which settles and DELIVERS -- so the broken file's
#     WAITING is the seal's verdict and not a beat too short to settle.
# ===========================================================================
SEAL_BROKEN='-- its seat-complete: line carries sha= but the file changed after it was marked'
# --mark / --mark-repair in process: the subject's wfd_mark_main, which the writer's `exit` ends.
markcall() {  # $1 = subject; rest = argv -> output in BEATOUT, returns the rc
  ( wbl_ip "$@" ) > "$BEATOUT" 2>&1
}
seal_world() {  # $1 = subject, $2 = workdir -> s.md sealed, x.md sealed then edited, b.md bare
  printf '%s\n' "$SKELETON" > "$2/s.md"; printf '%s\n' "$SKELETON" > "$2/x.md"
  printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$2/b.md"
  markcall "$1" --mark "$2/s.md" requirements pm cross-1 findings=1 || broken "--mark refused s.md: $(cat "$BEATOUT")"
  markcall "$1" --mark "$2/x.md" requirements pm cross-1 findings=1 || broken "--mark refused x.md: $(cat "$BEATOUT")"
  awk 'NR == 3 { print "- a finding rewritten after the marker"; next } { print }' "$2/x.md" > "$2/x.tmp" && mv "$2/x.tmp" "$2/x.md"
}

S24a_seal_decides() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  seal_world "$SUBJ" "$W"
  case "$(tail -1 "$W/s.md")" in
    "$MARKER sha="*" findings=1") ok "seal: --mark appends '<marker> sha=<hex> findings=<n>', sha= before findings=" ;;
    *) bad "seal: --mark wrote '$(tail -1 "$W/s.md")'" ;;
  esac
  CB_SETTLE=600 cbeat "$SUBJ" "$W" --complete s.md
  if has "DELIVERED s.md"; then ok "seal: a sealed file DELIVERS in one 2s beat under SETTLE=600 -- no window"
  else bad "seal: a sealed file waited on the settle window: $OUT"; fi
  CB_BEAT=3 cbeat "$SUBJ" "$W" --complete x.md b.md
  if has "DELIVERED b.md"; then ok "seal: CONTROL -- a bare marker settles and DELIVERS in the same 3s beat under SETTLE=1"
  else bad "seal: CONTROL FAILED -- the bare marker did not settle, so the beat below proves nothing: $OUT"; fi
  if ! has "DELIVERED x.md" && has "UNFINISHED x.md $SEAL_BROKEN"; then
    ok "seal: a sealed file edited above its marker is UNFINISHED where a bare one settles -- at any age"
  else bad "seal: a broken seal was delivered or not named UNFINISHED: $OUT"; fi
  CB_SETTLE=600 scall "$SUBJ" "$W" --complete --since "$CBEAT_SINCE" s.md x.md
  if has "DELIVERED s.md" && has "UNFINISHED x.md $SEAL_BROKEN"; then ok "seal: --status reads sealed DELIVERED and broken UNFINISHED, with no beat run"
  else bad "seal: --status disagrees with the beat on a sealed or broken file: $OUT"; fi
  markcall "$SUBJ" --mark "$W/x.md" requirements pm cross-1 findings=1 || broken "re-mark refused"
  n_mk="$(grep -c '^seat-complete: ' "$W/x.md")" || n_mk=0
  CB_SETTLE=600 cbeat "$SUBJ" "$W" --complete x.md
  if has "DELIVERED x.md" && [ "$n_mk" = 1 ]; then ok "seal: re-marked, the edited file DELIVERS at once and carries one marker"
  else bad "seal: re-mark did not deliver (markers=$n_mk): $OUT"; fi
  rm -rf "$W"
}

S24b_mark_refusals() {
  W="$(mk_work)"
  printf '%s\n```text\nan open fence\n' "$SKELETON" > "$W/f.md"; cp "$W/f.md" "$W/f.orig"
  markcall "$SUBJ" --mark "$W/f.md" requirements pm cross-1 findings=0; rc=$?
  if [ "$rc" -eq 64 ] && cmp -s "$W/f.md" "$W/f.orig"; then ok "seal: --mark on a body ending inside an open fence refuses (64) and writes nothing"
  else bad "seal: --mark into an open fence rc=$rc, file changed or accepted"; fi
  # Four fields on a clean file, so the refusal is the findings= check and not the arity or a fence.
  printf '%s\n' "$SKELETON" > "$W/c.md"
  markcall "$SUBJ" --mark "$W/c.md" requirements pm cross-1 count=1; rc=$?
  if [ "$rc" -eq 64 ] && grep -qF 'the last field must be findings=<n>' "$BEATOUT"; then ok "seal: --mark whose last field is not findings=<n> refuses (64)"
  else bad "seal: --mark with a malformed findings field rc=$rc: $(cat "$BEATOUT")"; fi
  printf '### e\n- edit: x\n' > "$W/r.md"
  markcall "$SUBJ" --mark-repair "$W/r.md" requirements; rc=$?
  case "$rc $(tail -1 "$W/r.md")" in
    "0 repair-complete: serial requirements sha="*) ok "seal: --mark-repair appends 'repair-complete: serial <pass> sha=<hex>'" ;;
    *) bad "seal: --mark-repair rc=$rc wrote '$(tail -1 "$W/r.md")'" ;;
  esac
  rm -rf "$W"
}

# --mark-repair seals the serial remediator's record the same way: a sealed record DELIVERS under
# --complete-repair at SETTLE=600, an edit above its marker is UNFINISHED, and the CONTROL is a
# bare `repair-complete: serial` record settling in that same beat under SETTLE=1.
repair_world() {  # $1 = subject, $2 = workdir -> rs.md sealed, rx.md sealed then edited, rb.md bare
  printf '### e\n- edit: x\n' > "$2/rs.md"; printf '### e\n- edit: x\n' > "$2/rx.md"
  printf '### e\n- edit: x\n%s\n' "$REPAIR_MARKER" > "$2/rb.md"
  markcall "$1" --mark-repair "$2/rs.md" requirements || broken "--mark-repair refused rs.md: $(cat "$BEATOUT")"
  markcall "$1" --mark-repair "$2/rx.md" requirements || broken "--mark-repair refused rx.md: $(cat "$BEATOUT")"
  awk 'NR == 1 { print "### a repair entry added after the marker" } { print }' "$2/rx.md" > "$2/rx.tmp" && mv "$2/rx.tmp" "$2/rx.md"
}
S24c_mark_repair_seals() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  repair_world "$SUBJ" "$W"
  CB_SETTLE=600 cbeat "$SUBJ" "$W" --complete-repair rs.md
  if has "DELIVERED rs.md"; then ok "seal: a --mark-repair record DELIVERS under --complete-repair in one beat at SETTLE=600"
  else bad "seal: a sealed repair record waited on the settle window: $OUT"; fi
  CB_BEAT=3 cbeat "$SUBJ" "$W" --complete-repair rx.md rb.md
  if has "DELIVERED rb.md"; then ok "seal: CONTROL -- a bare repair-complete record settles and DELIVERS in the same 3s beat"
  else bad "seal: CONTROL FAILED -- the bare repair record did not settle, so the beat below proves nothing: $OUT"; fi
  if ! has "DELIVERED rx.md" && has "UNFINISHED rx.md" && has "changed after it was marked"; then
    ok "seal: a sealed repair record edited above its marker is UNFINISHED"
  else bad "seal: a broken repair seal was delivered or not named UNFINISHED: $OUT"; fi
  rm -rf "$W"
}

# ===========================================================================
# 25. A REPAIR PART IS JOINED ON ITS --mark LINE. A part remediator writes its part early and
#     rewrites it, so a plain beat takes its first partial write as delivered. The part closes
#     with the argv remediator.md prescribes, `--mark <part> <step> remediator <shard>
#     findings=<n>`, and the part join beat passes --complete. A written, unmarked part is
#     UNFINISHED under --complete and DELIVERED after --mark; the CONTROL is the same unmarked
#     part under a plain beat, which DELIVERS, so the UNFINISHED is the flag's verdict.
# ===========================================================================
PART_BODY='- artifact: _bmad-output/planning-artifacts/s9/stories/a.md
- advisor: called
- derivations: replayed 1

### F-1 — MAJOR
- disposition: repaired
- edit: _bmad-output/planning-artifacts/s9/stories/a.md:4'
S25_part_marked_join() {
  W="$(mk_work)"; CBEAT_SINCE=$(( $(date +%s) - 30 ))
  printf '%s\n' "$PART_BODY" > "$W/04.md"
  scall "$SUBJ" "$W" --since "$CBEAT_SINCE" 04.md
  if has "DELIVERED 04.md"; then ok "part: CONTROL -- a written, unmarked repair part is DELIVERED by a plain beat"
  else bad "part: CONTROL FAILED -- the plain beat did not deliver the unmarked part, so the UNFINISHED below means nothing: $OUT"; fi
  scall "$SUBJ" "$W" --complete --since "$CBEAT_SINCE" 04.md
  if has "UNFINISHED 04.md" && ! has "DELIVERED 04.md"; then ok "part: the same unmarked part under --complete is UNFINISHED"
  else bad "part: an unmarked repair part was delivered under --complete: $OUT"; fi
  markcall "$SUBJ" --mark "$W/04.md" stories remediator 04 findings=1 || broken "--mark refused the part: $(cat "$BEATOUT")"
  case "$(tail -1 "$W/04.md")" in
    "seat-complete: stories remediator 04 sha="*" findings=1") ok "part: --mark appends 'seat-complete: <step> remediator <shard> sha=<hex> findings=<n>'" ;;
    *) bad "part: --mark wrote '$(tail -1 "$W/04.md")'" ;;
  esac
  scall "$SUBJ" "$W" --complete --since "$CBEAT_SINCE" 04.md
  if has "DELIVERED 04.md"; then ok "part: marked, the part is DELIVERED under --complete"
  else bad "part: a marked repair part was not delivered under --complete: $OUT"; fi
  rm -rf "$W"
}

# ===========================================================================
# 26. ONE START-TIME DEFINITION: THE SUBJECT'S FALLBACK IS THE HELPER'S, WHOLE RANGE.
#     wfd-start-of.sh owns wfd_start_of; the subject carries a fallback copy under
#     `if ! declare -F` for a lone copy with no sibling.
#     The shell-identity markers store and compare its value, so the two copies must agree.
# ===========================================================================
START_OF_HELPER="$(dirname "$SUBJ")/wfd-start-of.sh"
S26_start_of_ranges_identical() {
  [ -f "$START_OF_HELPER" ] || broken "wfd-start-of.sh is not beside $SUBJ"
  # shellcheck disable=SC1090
  . "$START_OF_HELPER"; declare -F wfd_start_of >/dev/null || broken "wfd-start-of.sh does not define wfd_start_of"
  # THE WHOLE RANGE, not the first line: the definition is multi-line (ps, then the perl fallback,
  # then the normalisation), so a body-only drift between the two copies must fail here.
  sa_h_="$(sed -n '/^wfd_start_of() {/,/^}/p' "$START_OF_HELPER")"
  sa_s_="$(sed -n '/^wfd_start_of() {/,/^}/p' "$SUBJ")"
  if [ -n "$sa_s_" ] && [ "$sa_h_" = "$sa_s_" ] && [ "$(printf '%s\n' "$sa_s_" | tail -n 1)" = "}" ]; then
    ok "start-of: the subject's fallback wfd_start_of is byte-identical to wfd-start-of.sh's, whole range"
  else bad "start-of: the subject's fallback wfd_start_of differs from wfd-start-of.sh's (or is absent), so a lone copy and the helper read start times differently"; fi
}

# ===========================================================================
# 27. --complete-repair: THE DISPATCH'S OWN TRANSCRIPT EXTENDS THE CAP AND GOVERNS THE REMEDY.
#     A serial remediator appends to its record only at the end, so the record cannot grow and
#     the wait had no evidence of work: a live remediator reached the cap and was told "Re-dispatch
#     the teammate ONCE", two writers on one record (BL-717). Under --complete-repair with one
#     target and one --dispatch that resolves to an agent, that agent's own transcript taking a
#     turn within a quantum grants the counted extension, and at GRANTSPENT withholds the bare
#     remedy; a turn older than a quantum but younger than IDLE_SECS grants nothing yet still
#     withholds it. Each arm has its near-miss beside it: the same seed with the turn an hour old
#     (dead) or past IDLE_SECS, with no --dispatch (the session-wide reading decides nothing), and
#     with a stalled run.
#     Counters are seeded exactly as beat <max> leaves them (`.bound`, `<key>`, `<key>.grants`),
#     except 27b's fresh-arm arm, which reaches the cap by real beats, each its own subshell, so
#     the chained-beat guard cannot skip a charge.
#     The quantum is 30s (R27_BUDGET) for every arm that does not sleep, so pool load cannot push a
#     turn seeded at "now" past it into RECENT; it is 4s only where a beat really runs (the granted
#     first arm of 27a and the real-beat loop of 27b).
# ===========================================================================
R27_AG=a717beef; R27_TUI=toolu_wbl717
r27_key() { printf '%s' "$1" | cksum | tr -d ' \t' | cut -c1-16; }
r27_world() {  # $1 = workdir -> ledger row, meta.json joining R27_AG to R27_TUI, td/
  mkdir -p "$1/td" "$1/_bmad-output/.wait-beats" || broken "cannot create the section 27 world"
  mk_ledger_row "$1" "$R27_TUI" $(( $(date +%s) - 300 ))
  printf '{"agentType":"dev","toolUseId":"%s"}' "$R27_TUI" > "$1/td/agent-$R27_AG.meta.json" || broken "cannot write meta.json"
}
r27_transcript() {  # $1 = workdir, $2 = age of the last turn (s), $3 = trailing api-request lines
  rt_ts_="$(fx_iso $(( $(fx_now "$1") - $2 )))"; [ -n "$rt_ts_" ] || broken "neither BSD nor GNU date can format an epoch"
  rt_ts_="${rt_ts_%Z}"; rt_now_="$(fx_iso "$(fx_now "$1")")"; rt_now_="${rt_now_%Z}"
  { printf '{"isSidechain":true,"agentId":"%s","type":"user","message":{"role":"user"},"timestamp":"%s.100Z"}\n' "$R27_AG" "$rt_ts_"
    printf '{"isSidechain":true,"agentId":"%s","message":{"role":"assistant"},"type":"assistant","timestamp":"%s.300Z"}\n' "$R27_AG" "$rt_ts_"
    rt_i_=0; while [ "$rt_i_" -lt "$3" ]; do
      printf '{"type":"api-request","sessionId":"s","agentId":"%s","id":"r%s","timestamp":"%s.200Z"}\n' "$R27_AG" "$rt_i_" "$rt_now_"
      rt_i_=$(( rt_i_ + 1 )); done
  } > "$1/td/agent-$R27_AG.jsonl" || broken "cannot write the section 27 transcript"
}
r27_cap() {  # $1 = workdir, $2 = grants already spent ('' none) -- the counters beat 2 of 2 leaves
  rc_d_="$1/_bmad-output/.wait-beats"; rc_k_="$(r27_key rec.md)"
  printf '2' > "$rc_d_/.bound" && printf '2' > "$rc_d_/$rc_k_" || broken "cannot seed the beat counter"
  [ -z "$2" ] || printf '%s' "$2" > "$rc_d_/$rc_k_.grants" || broken "cannot seed the grant counter"
}
r27_beat() {  # $1 = subject (in a sibling dir), $2 = workdir ; rest = argv
  r7_s_="$1" r7_w_="$2"; shift 2
  ( cd "$r7_w_" && unset CLAUDE_CODE_SESSION_ID && export AI_DLC_WAIT_BEAT_SECS="${R27_BUDGET:-30}" AI_DLC_WAIT_POLL_SECS=1 \
      AI_DLC_WAIT_MARGIN_SECS=0 AI_DLC_MAX_WAIT_BEATS=2 AI_DLC_TEAMMATE_IDLE_SECS="${R27_IDLE:-3600}" \
      AI_DLC_TEAMMATE_DIR="$PWD/td" AI_DLC_PROJECT_ROOT="$PWD" && wbl_ip "$r7_s_" "$@" ) > "$BEATOUT" 2>&1
  RC=$?
  OUT="$(cat "$BEATOUT")"
}
R27_REMEDY='Re-dispatch the'
R27_LIVE="LIVE DISPATCH agent-$R27_AG"
R27_STOP="STOPPED DISPATCH agent-$R27_AG"
S27a_repair_dispatch_live_extends_cap() {
  R27_S="$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  W="$(mk_work)"; r27_world "$W"; r27_cap "$W" ""; r27_transcript "$W" 0 0
  R27_BUDGET=4 r27_beat "$R27_S" "$W" --complete-repair --dispatch "$R27_AG" rec.md
  if [ "$RC" -eq 0 ] && has "PROGRESS  rec.md -- work observed in agent-$R27_AG.jsonl, this dispatch's own transcript" \
     && ! has "under the progress path" && ! has "$R27_REMEDY" && ! has "NON-DELIVERY"; then
    ok "repair-live: at the cap, the dispatched agent's own fresh turn grants the counted extension, and PROGRESS names its transcript (rc 0, no re-dispatch)"
  else bad "repair-live: a live --complete-repair dispatch at the cap was not granted, named the progress path, or was told to re-dispatch (rc=$RC): $OUT"; fi
  rm -rf "$W"
  # THE RECENT BAND: a turn older than one quantum but younger than IDLE_SECS grants NOTHING, and
  # still replaces the bare remedy with the liveness-check block; the wait ends (rc 1).
  W="$(mk_work)"; r27_world "$W"; r27_cap "$W" ""; r27_transcript "$W" 60 0
  R27_IDLE=1200 r27_beat "$R27_S" "$W" --complete-repair --dispatch "$R27_AG" rec.md
  if [ "$RC" -eq 1 ] && has "$R27_LIVE" && has "no grant" && ! has "$R27_REMEDY" && ! has "PROGRESS"; then
    ok "repair-live: RECENT — a turn 60s old (quantum 30s, idle 1200s) gets no grant, and the liveness block replaces the re-dispatch (rc 1)"
  else bad "repair-live: RECENT band granted, or printed the bare re-dispatch (rc=$RC): $OUT"; fi
  rm -rf "$W"
  # NEAR-MISS: the same seed past IDLE_SECS gets no LIVE block and no grant; with the record
  # absent it is STOPPED (BL-721): read the last message before any re-dispatch.
  W="$(mk_work)"; r27_world "$W"; r27_cap "$W" ""; r27_transcript "$W" 1300 0
  R27_IDLE=1200 r27_beat "$R27_S" "$W" --complete-repair --dispatch "$R27_AG" rec.md
  if [ "$RC" -eq 1 ] && has "$R27_STOP" && ! has "$R27_REMEDY" && ! has "$R27_LIVE" && ! has "PROGRESS"; then
    ok "repair-live: NEAR-MISS — a turn past IDLE_SECS (1300s of 1200s) gets no LIVE block and no grant; the absent record reads STOPPED (rc 1)"
  else bad "repair-live: NEAR-MISS FAILED — a dispatch idle past IDLE_SECS was granted, read LIVE, or did not read STOPPED (rc=$RC): $OUT"; fi
  rm -rf "$W"
  # NEAR-MISS: the same seed with the turn an hour old is NON-DELIVERY, STOPPED, never granted.
  W="$(mk_work)"; r27_world "$W"; r27_cap "$W" ""; r27_transcript "$W" 3600 0
  r27_beat "$R27_S" "$W" --complete-repair --dispatch "$R27_AG" rec.md
  if [ "$RC" -eq 1 ] && has "NON-DELIVERY rec.md -- absent after" && has "$R27_STOP" && ! has "$R27_LIVE" && ! has "PROGRESS"; then
    ok "repair-live: NEAR-MISS — the same dispatch with its last turn an hour old is NON-DELIVERY and STOPPED, never granted (rc 1)"
  else bad "repair-live: NEAR-MISS FAILED — a dead dispatch was granted, read LIVE, or did not read STOPPED (rc=$RC): $OUT"; fi
  rm -rf "$W"
  # CONTROL: a live transcript with NO --dispatch is the session-wide reading, which decides nothing.
  W="$(mk_work)"; r27_world "$W"; r27_cap "$W" ""; r27_transcript "$W" 0 0
  r27_beat "$R27_S" "$W" --complete-repair rec.md
  if [ "$RC" -eq 1 ] && has "$R27_REMEDY" && has "$LIVE_LINE" && ! has "PROGRESS"; then
    ok "repair-live: CONTROL — without --dispatch a live session reads LIVENESS only, and the remedy is today's (rc 1)"
  else bad "repair-live: CONTROL FAILED — the session-wide reading granted or withheld the remedy (rc=$RC): $OUT"; fi
  rm -rf "$W"
  # NEAR-MISS: a fresh turn followed by a stalled run is not live.
  W="$(mk_work)"; r27_world "$W"; r27_cap "$W" ""; r27_transcript "$W" 0 3
  r27_beat "$R27_S" "$W" --complete-repair --dispatch "$R27_AG" rec.md
  if [ "$RC" -eq 1 ] && has "$R27_REMEDY" && has "${STALL_LINE}agent-$R27_AG.jsonl" && ! has "PROGRESS"; then
    ok "repair-live: NEAR-MISS — a dispatch ending in 3 unanswered api-requests is not granted (rc 1, STALLED)"
  else bad "repair-live: NEAR-MISS FAILED — a stalled dispatch was granted (rc=$RC): $OUT"; fi
  rm -rf "$W"
}
S27b_repair_dispatch_live_grantspent() {
  R27_S="$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  W="$(mk_work)"; r27_world "$W"; r27_cap "$W" 2; r27_transcript "$W" 0 0
  r27_beat "$R27_S" "$W" --complete-repair --dispatch "$R27_AG" rec.md
  if [ "$RC" -eq 1 ] && has "$R27_LIVE" && has "agent-$R27_AG.jsonl" && has "two writers on one record" \
     && ! has "$R27_REMEDY" && has "(Rule 29, Check C)"; then
    ok "repair-live: GRANTSPENT with the dispatch still live ends the wait (rc 1) with the liveness-check block, never the bare re-dispatch"
  else bad "repair-live: GRANTSPENT on a live dispatch printed the bare remedy or no liveness block (rc=$RC): $OUT"; fi
  rm -rf "$W"
  # A FRESH ARM AFTER THE CAP (graph S319's seventh invocation): real beats to the cap, then new
  # invocations with no --reset. Every one of them reads the spent counter; none may re-dispatch.
  W="$(mk_work)"; r27_world "$W"; rb_n_=0; rb_bad_=""
  while [ "$rb_n_" -lt 6 ]; do
    r27_transcript "$W" 0 0
    R27_BUDGET=4 r27_beat "$R27_S" "$W" --complete-repair --dispatch "$R27_AG" rec.md
    rb_n_=$(( rb_n_ + 1 ))
    has "$R27_REMEDY" && rb_bad_="${rb_bad_} beat$rb_n_"
    [ "$RC" -eq 1 ] && break
  done
  if [ -z "$rb_bad_" ] && [ "$RC" -eq 1 ] && has "$R27_LIVE" && [ "$rb_n_" -eq 5 ]; then
    ok "repair-live: armed fresh after the cap, a live dispatch takes both grants, then the liveness block at beat 5 — never 'Re-dispatch the'"
  else bad "repair-live: a fresh arm after the cap re-dispatched (at:$rb_bad_) or ended at beat $rb_n_ not 5 (rc=$RC): $OUT"; fi
  rm -rf "$W"
}
S27c_complete_present_is_unchanged() {
  R27_S="$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  W="$(mk_work)"; r27_world "$W"; r27_cap "$W" ""; r27_transcript "$W" 3600 0
  awk 'BEGIN { for (i = 1; i <= 40; i++) print "- record line " i }' > "$W/rec.md" || broken "cannot write rec.md"
  fx_backdate "$W/rec.md" 3600 || broken "cannot backdate rec.md"
  r27_beat "$R27_S" "$W" --complete-repair --dispatch "$R27_AG" rec.md
  if [ "$RC" -eq 1 ] && has "UNCHANGED rec.md -- present (40 lines), not modified since the join" \
     && ! has "absent after" && ! has "$R27_REMEDY"; then
    ok "repair-unchanged: a present record older than the join is UNCHANGED at the cap, never 'absent', and gets no re-dispatch remedy (rc 1)"
  else bad "repair-unchanged: a present pre-join record was called absent or given the bare remedy (rc=$RC): $OUT"; fi
  rm -rf "$W"
  # NEAR-MISS: the record truly missing is still 'absent', with the remedy.
  W="$(mk_work)"; r27_world "$W"; r27_cap "$W" ""; r27_transcript "$W" 3600 0
  r27_beat "$R27_S" "$W" --complete-repair rec.md
  if [ "$RC" -eq 1 ] && has "NON-DELIVERY rec.md -- absent after" && has "$R27_REMEDY" && ! has "UNCHANGED"; then
    ok "repair-unchanged: NEAR-MISS — a truly missing record is still 'absent' with the re-dispatch remedy"
  else bad "repair-unchanged: NEAR-MISS FAILED — a missing record lost its 'absent' line or its remedy (rc=$RC): $OUT"; fi
  rm -rf "$W"
}

# ===========================================================================
# 27d. A PLAIN --dispatch GETS THE REMEDY ITS OWN TRANSCRIPT SUPPORTS; ONLY THE GRANT IS
#      --complete-repair's (BL-721). A remediator whose work has no deliverable file (an inline
#      changelog append) gives the join a path that never appears, so a beat armed on it can
#      only reach its cap -- and the bare "Re-dispatch the teammate ONCE" then fired against a
#      live or finished writer. Seeds: a two-row ledger with the subject NOT first, and a
#      meta.json joining the agentId to the dispatch's toolu_ id.
#      AI_DLC_MAX_WAIT_BEATS=1 with the counters seeded at the cap. Both id spellings are driven.
#      The near-miss without --dispatch keeps the bare remedy.
# ===========================================================================
R27D_AG=a721c8dcd555207b8; R27D_TUI=toolu_01Bl721SubjectDispatchAAAA; R27D_TUI_E=toolu_01Bl721EpochRowBBBBBBBBB
r27d_world() {  # $1 = age of the transcript's last turn (s) -> W
  W="$(mk_work)"; mkdir -p "$W/td" "$W/_bmad-output/.wait-beats" || broken "cannot create the section 27d world"
  mk_ledger_row "$W" "$R27D_TUI_E" $(( $(fx_now "$W") - 400 ))
  mk_ledger_row "$W" "$R27D_TUI" $(( $(fx_now "$W") - 300 ))
  printf '{"agentType":"remediator","toolUseId":"%s"}\n' "$R27D_TUI" > "$W/td/agent-$R27D_AG.meta.json" || broken "cannot write meta.json"
  rd_ts_="$(fx_iso $(( $(fx_now "$W") - $1 )))"; [ -n "$rd_ts_" ] || broken "neither BSD nor GNU date can format an epoch"
  rd_ts_="${rd_ts_%Z}"
  { printf '{"isSidechain":true,"agentId":"%s","type":"user","message":{"role":"user"},"timestamp":"%s.100Z"}\n' "$R27D_AG" "$rd_ts_"
    printf '{"isSidechain":true,"agentId":"%s","message":{"role":"assistant"},"type":"assistant","timestamp":"%s.300Z"}\n' "$R27D_AG" "$rd_ts_"
  } > "$W/td/agent-$R27D_AG.jsonl" || broken "cannot write the section 27d transcript"
  printf '1' > "$W/_bmad-output/.wait-beats/.bound" && printf '1' > "$W/_bmad-output/.wait-beats/$(r27_key never.marker)" \
    || broken "cannot seed the beat counter"
}
r27d_beat() {  # $1 = subject (in a sibling dir); rest = argv -> OUT, RC
  rd_s_="$1"; shift
  ( cd "$W" && unset CLAUDE_CODE_SESSION_ID && export AI_DLC_WAIT_BEAT_SECS=30 AI_DLC_WAIT_POLL_SECS=1 \
      AI_DLC_WAIT_MARGIN_SECS=0 AI_DLC_MAX_WAIT_BEATS=1 AI_DLC_TEAMMATE_IDLE_SECS=1200 \
      AI_DLC_TEAMMATE_DIR="$PWD/td" AI_DLC_PROJECT_ROOT="$PWD" && wbl_ip "$rd_s_" "$@" ) > "$BEATOUT" 2>&1
  RC=$?
  OUT="$(cat "$BEATOUT")"
}
R27D_LIVE="LIVE DISPATCH agent-$R27D_AG"
R27D_STOP="STOPPED DISPATCH agent-$R27D_AG"
r27d_live_arm() {  # $1 = subject, $2 = id -> 0 when the fresh arm holds
  r27d_world 0; r27d_beat "$1" --dispatch "$2" never.marker
  [ "$RC" -eq 1 ] && has "NON-DELIVERY never.marker -- absent after 1 beats" && has "$R27D_LIVE" \
    && has "buys no grant outside" && ! has "$R27_REMEDY" && ! has "PROGRESS"
}
r27d_stop_arm() {  # $1 = subject, $2 = id -> 0 when the stale arm holds
  r27d_world 3600; r27d_beat "$1" --dispatch "$2" never.marker
  [ "$RC" -eq 1 ] && has "NON-DELIVERY never.marker -- absent after 1 beats" && has "$R27D_STOP" \
    && has "agent-$R27D_AG.jsonl" && ! has "$R27D_LIVE" && ! has "$R27_REMEDY"
}
r27d_nodispatch_arm() {  # $1 = subject -> 0 when the near-miss keeps the bare remedy
  r27d_world 0; r27d_beat "$1" never.marker
  [ "$RC" -eq 1 ] && has "NON-DELIVERY never.marker -- absent after 1 beats" && has "$R27_REMEDY" \
    && ! has "$R27D_LIVE" && ! has "$R27D_STOP"
}
S27d_plain_dispatch_remedy() {
  R27D_S="$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  for rd_id_ in "$R27D_AG" "$R27D_TUI"; do
    if r27d_live_arm "$R27D_S" "$rd_id_"; then
      ok "plain-dispatch: --dispatch $rd_id_ at its cap with a fresh transcript prints LIVE DISPATCH, no grant, never 'Re-dispatch the' (rc 1)"
    else bad "plain-dispatch: --dispatch $rd_id_ with a fresh transcript printed the bare remedy, a grant, or no LIVE block (rc=$RC): $OUT"; fi
    rm -rf "$W"
    if r27d_stop_arm "$R27D_S" "$rd_id_"; then
      ok "plain-dispatch: --dispatch $rd_id_ at its cap with the transcript past IDLE_SECS prints STOPPED naming it, never 'Re-dispatch the' (rc 1)"
    else bad "plain-dispatch: --dispatch $rd_id_ past IDLE_SECS printed the bare remedy, a LIVE block, or no STOPPED line (rc=$RC): $OUT"; fi
    rm -rf "$W"
  done
  if r27d_nodispatch_arm "$R27D_S"; then
    ok "plain-dispatch: NEAR-MISS — the same fresh transcript with no --dispatch keeps the bare remedy and no dispatch block (rc 1)"
  else bad "plain-dispatch: NEAR-MISS FAILED — without --dispatch the beat lost the bare remedy or printed a dispatch block (rc=$RC): $OUT"; fi
  rm -rf "$W"
}

# ===========================================================================
# 28. --dispatch-ts PRINTS THE DISPATCH'S OWN LEDGER ts, VERBATIM, AND REFUSES EVERY OTHER ANSWER
#     (BL-605). The In-Flight row's `dispatched-at` was stamped from a clock after the dispatch --
#     the motivating pair is dispatched 05:00:03Z, stamped 05:01:00Z -- so the mode reads the
#     dispatch's spawn-ledger row through dispatch_epoch_of. Seeds: a two-row ledger with the
#     subject NOT first (a one-row ledger makes its own row the answer to any lookup), and a
#     meta.json joining the agentId to the subject's toolu_ id. Both id spellings must print the
#     subject row's ts; the other row must print its OWN ts; an agentId with no meta.json, an
#     agentId with no subagents dir at all, and an id with no ledger row each exit 64 with
#     dispatch_refuse's text and print nothing on stdout. The mode takes the --status no-write
#     path, so the tree is byte-for-byte the same file list after every call. stdout and stderr
#     are captured apart: the stamp is the whole of stdout, and a refusal must not leak one there.
# ===========================================================================
R28_D="2026-10-16T05:00:03Z"; R28_LATE="2026-10-16T05:01:00Z"; R28_E="2026-10-16T04:58:41Z"
R28_TUI=toolu_01Bl605SubjectDispatchAAAA; R28_TUI_E=toolu_01Bl605EpochRowBBBBBBBBB; R28_AG=a7ffc8dcd555207b8
R28_NOROW=toolu_01Bl605NoSuchDispatchZZZ; R28_NOMETA=a0000000000000605
r28_world() {  # -> W: the epoch row first, the subject second, and the agentId's meta.json
  W="$(mk_work)"; mkdir -p "$W/sub" "$W/nostate" || broken "cannot create the section 28 world"
  { printf '{"ts":"%s","tool_use_id":"%s","name":"","subagent_type":"architect"}\n' "$R28_E" "$R28_TUI_E"
    printf '{"ts":"%s","tool_use_id":"%s","name":"","subagent_type":"remediator"}\n' "$R28_D" "$R28_TUI"
  } > "$W/_bmad-output/spawn-ledger.jsonl" || broken "cannot write the section 28 ledger"
  printf '{"agentType":"remediator","toolUseId":"%s"}\n' "$R28_TUI" > "$W/sub/agent-$R28_AG.meta.json" \
    || broken "cannot write the section 28 meta.json"
}
r28_argv() {  # $1 = subject, $2 = teammate dir ('' = none, and no session id), rest = argv -> R28_OUT, R28_ERR, RC
  r28_s_="$1"; r28_t_="$2"; shift 2
  ( cd "$W" && if [ -n "$r28_t_" ]; then export AI_DLC_TEAMMATE_DIR="$r28_t_"; else unset AI_DLC_TEAMMATE_DIR; fi
    if [ -n "${R28_STATE:-}" ]; then export AI_DLC_STATE_DIR="$R28_STATE"; fi
    unset CLAUDE_CODE_SESSION_ID; export AI_DLC_PROJECT_ROOT="$PWD"; wbl_ip "$r28_s_" "$@" ) \
    > "$TMPROOT/r28.out" 2> "$TMPROOT/r28.err"
  RC=$?
  R28_OUT="$(cat "$TMPROOT/r28.out")"; R28_ERR="$(cat "$TMPROOT/r28.err")"
  OUT="rc=$RC stdout=[$R28_OUT] stderr=[$R28_ERR]"
}
r28_ts() {  # $1 = subject, $2 = id, $3 = teammate dir ('' = none, and no session id) -> R28_OUT, R28_ERR, RC
  r28_argv "$1" "$3" --dispatch-ts "$2"
}
r28_argshape_arm() {  # $1 = subject, $2 = the whole refusal line, rest = argv -> 0 when refused with exactly that line
  r28_as_s_="$1"; r28_as_t_="$2"; shift 2
  r28_argv "$r28_as_s_" "$W/sub" "$@"
  [ "$RC" -eq 64 ] && [ -z "$R28_OUT" ] && [ "$R28_ERR" = "$r28_as_t_" ]
}
r28_snap() {  # -> stdout: every path under $W, then a cksum of every file's CONTENT
  find "$W" | sort
  find "$W" -type f -exec cksum {} \; | sort
}
r28_stamp_arm() {  # $1 = subject, $2 = id, $3 = expected ts -> 0 when that id prints exactly that ts
  r28_ts "$1" "$2" "$W/sub"
  [ "$RC" -eq 0 ] && [ "$R28_OUT" = "$3" ] && [ "$R28_OUT" != "$R28_LATE" ] && [ -z "$R28_ERR" ]
}
r28_refuse_arm() {  # $1 = subject, $2 = id, $3 = teammate dir, $4 = refusal text -> 0 when refused by name
  r28_ts "$1" "$2" "$3"
  [ "$RC" -eq 64 ] && [ -z "$R28_OUT" ] || return 1
  case "$R28_ERR" in *"FAIL: --dispatch '$2': $4"*"No dispatch time is guessed."*) return 0 ;; esac
  return 1
}
S28_dispatch_ts_contract() {
  r28_world
  r28_before_="$(r28_snap)"
  if r28_stamp_arm "$SUBJ" "$R28_AG" "$R28_D"; then
    ok "dispatch-ts: agentId $R28_AG resolves through its meta.json and prints the subject row's ts $R28_D verbatim (the second ledger row, not the late $R28_LATE)"
  else bad "dispatch-ts: agentId $R28_AG did not print the subject row's ts $R28_D alone on stdout: $OUT"; fi
  if r28_stamp_arm "$SUBJ" "$R28_TUI" "$R28_D"; then
    ok "dispatch-ts: toolu_ id $R28_TUI prints the same ledger ts $R28_D verbatim (rc 0, nothing on stderr)"
  else bad "dispatch-ts: toolu_ id $R28_TUI did not print $R28_D: $OUT"; fi
  if r28_stamp_arm "$SUBJ" "$R28_TUI_E" "$R28_E"; then
    ok "dispatch-ts: the OTHER ledger row's id prints its own ts $R28_E, so the lookup discriminates by row"
  else bad "dispatch-ts: the other row $R28_TUI_E did not print its own ts $R28_E -- the lookup does not discriminate: $OUT"; fi
  if r28_refuse_arm "$SUBJ" "$R28_NOROW" "$W/sub" "the ledger holds 0 row(s) for tool_use_id $R28_NOROW, not one"; then
    ok "dispatch-ts: an id with no ledger row is refused by name (rc 64, dispatch_refuse's text, stdout empty)"
  else bad "dispatch-ts: an id with no ledger row was not refused with rc 64, the 0-row text and an empty stdout: $OUT"; fi
  if r28_refuse_arm "$SUBJ" "$R28_NOMETA" "$W/sub" "no agent-${R28_NOMETA}.meta.json in this session's subagents dir ($W/sub)"; then
    ok "dispatch-ts: an agentId with no meta.json is refused by name (rc 64, stdout empty)"
  else bad "dispatch-ts: an agentId with no meta.json was not refused with rc 64, its text and an empty stdout: $OUT"; fi
  if r28_refuse_arm "$SUBJ" "$R28_AG" "" "no agent-${R28_AG}.meta.json in this session's subagents dir (unresolved: CLAUDE_CODE_SESSION_ID is unset)"; then
    ok "dispatch-ts: with no session id and no subagents dir even a real agentId is refused by name (rc 64, stdout empty)"
  else bad "dispatch-ts: an agentId with no session id was not refused with rc 64, the unresolved text and an empty stdout: $OUT"; fi
  # The argument shapes refused before any lookup. Each refusal is the WHOLE of stderr, rc 64,
  # stdout empty. The two ids are the subject row and the other row, and each prints its own ts
  # alone (the stamp arms above are the control), so a guard that never matches prints a stamp.
  r28_need_="FAIL: --dispatch-ts needs the agentId the Agent result returned."
  if r28_argshape_arm "$SUBJ" "$r28_need_" --dispatch-ts "" \
     && r28_argshape_arm "$SUBJ" "$r28_need_" --dispatch-ts; then
    ok "dispatch-ts: an empty id and a missing id are each refused (rc 64, the needs-the-agentId line, stdout empty)"
  else bad "dispatch-ts: an empty or missing --dispatch-ts id was not refused with rc 64, its line and an empty stdout: $OUT"; fi
  if r28_argshape_arm "$SUBJ" "FAIL: --dispatch-ts takes exactly one id (got '$R28_TUI $R28_TUI_E'); one row, one stamp." \
       --dispatch-ts "$R28_TUI" --dispatch-ts "$R28_TUI_E"; then
    ok "dispatch-ts: two ids that each resolve alone are refused together (rc 64, exactly-one-id line, no stamp guessed)"
  else bad "dispatch-ts: two --dispatch-ts ids were not refused with rc 64, the exactly-one-id line and an empty stdout: $OUT"; fi
  r28_alone_="FAIL: --dispatch-ts prints one dispatch's ledger ts and is not a beat; pass it alone."
  if r28_argshape_arm "$SUBJ" "$r28_alone_" --dispatch-ts "$R28_TUI" deliverable.md \
     && r28_argshape_arm "$SUBJ" "$r28_alone_" --reset --dispatch-ts "$R28_TUI"; then
    ok "dispatch-ts: combined with a target path or with --reset it is refused (rc 64, pass-it-alone line, stdout empty)"
  else bad "dispatch-ts: --dispatch-ts beside a beat argument was not refused with rc 64, the pass-it-alone line and an empty stdout: $OUT"; fi
  if R28_STATE=nostate r28_argshape_arm "$SUBJ" "FAIL: --dispatch '$R28_TUI': no spawn ledger at $W/nostate/spawn-ledger.jsonl
  No dispatch time is guessed. Arm from the project root, where the dispatch guard writes it." --dispatch-ts "$R28_TUI"; then
    ok "dispatch-ts: a state dir with no spawn-ledger.jsonl is refused by name (rc 64, no-spawn-ledger text, stdout empty)"
  else bad "dispatch-ts: a state dir with no spawn ledger was not refused with rc 64, its text and an empty stdout: $OUT"; fi
  if r28_argshape_arm "$SUBJ" "FAIL: --dispatch '$R28_TUI/x': not an agentId, a <name>@<team> or a dispatch id (prefixes: toolu_ call_)
  No dispatch time is guessed. Pass the agentId the Agent result returned." --dispatch-ts "$R28_TUI/x"; then
    ok "dispatch-ts: an id outside the accepted charset is refused by name (rc 64, not-an-agentId text, stdout empty)"
  else bad "dispatch-ts: an id outside the charset was not refused with rc 64, its text and an empty stdout: $OUT"; fi
  r28_after_="$(r28_snap)"
  if [ -n "$r28_before_" ] && [ "$r28_before_" = "$r28_after_" ] && [ ! -e "$W/_bmad-output/.wait-beats" ] \
     && [ ! -e "$W/_bmad-output/.beat-inflight" ]; then
    ok "dispatch-ts: every call left the tree unchanged -- the same paths, every file's cksum the same, no .wait-beats, no .beat-inflight lease"
  else bad "dispatch-ts: --dispatch-ts wrote into the tree: before=[$r28_before_] after=[$r28_after_]"; fi
  rm -rf "$W"
}

# ===========================================================================
# 29. DISPATCH FAILED: A DISPATCHED AGENT THAT DIED BEFORE DELIVERING IS NAMED (BL-975).
#     The motivating session dispatched nine remediators; four died mid-request, each transcript
#     ending in one unanswered `{"type":"api-request"` (two followed only by harness attachment
#     lines), and the only beat ended with the In-Flight rows naming the wrong deliverable for every
#     agent, so the lead resumed the agents the rows named and three dead parts were never resumed.
#     Every world below is a --dispatch beat over a session dir laid out as the harness writes it:
#     `<sess>/subagents/agent-<id>.jsonl` with its meta.json (the description is the agent's real
#     deliverable), and the lead transcript `<sess>.jsonl` beside the subagents dir. The seed lines
#     carry the key order and timestamp form of real harness lines (millis and Z on every stamp, the
#     agent side and the notice side alike, because arm A's resume acquittal compares them as text).
#     The ledger holds an EPOCH row before every subject row.
#     EVERY AGE IS ON THE WORLD'S VIRTUAL CLOCK (BL-868): stamps are fx_now-relative, the beat's own
#     polls move the clock, and DF_EL is the virtual seconds a beat took -- never the real clock.
#     The quantum is 300 s with a 30 s poll and no margin, so a beat that runs out its deadline
#     takes exactly 270 virtual seconds, and one that breaks on its first poll takes 0.
# ===========================================================================
DF_DEAD=a975dead00000d001; DF_LIVE=a975cafe00000c002; DF_LIVE2=a975beef00000b003
DF_HDR='DISPATCH FAILED agent-'
DF_EARLY='This beat ended early on that report: its beat charge was refunded, and the time already waited is not charged.'
DF_DASH=a975-dead-0000d004
# Every stamp here is formatted by the REAL date binary, never the `date` that PATH finds first (the
# clockbin shim, a bash start per call): a section that writes one stamp per seed line would otherwise
# charge the invocation budget once per line for a value the shim does not change.
df_iso_ms() {  # $1 = age (s) on W's clock, $2 = millis -> ISO8601 with millis and Z
  di_e_=$(( $(fx_now "$W") - $1 ))
  di_t_="$("$WBL_REAL_DATE" -u -r "$di_e_" +%Y-%m-%dT%H:%M:%S 2>/dev/null || "$WBL_REAL_DATE" -u -d "@$di_e_" +%Y-%m-%dT%H:%M:%S 2>/dev/null)"
  [ -n "$di_t_" ] || broken "neither BSD nor GNU date can format an epoch"
  printf '%s.%sZ' "$di_t_" "$2"
}
df_ledger_row() {  # $1 = tool_use_id, $2 = age (s) -> one spawn-ledger row, in mk_ledger_row's shape
  dl_t_="$(df_iso_ms "$2" 000)"
  printf '{"v":1,"ts":"%sZ","name":"wbl","role":"dev","tool_use_id":"%s"}\n' "${dl_t_%.000Z}" "$1" \
    >> "$W/_bmad-output/spawn-ledger.jsonl" || broken "cannot write the spawn ledger"
}
df_world() {  # -> W, TD (the session's subagents dir), the lead transcript beside it, and an epoch ledger row
  W="$(mk_work)"; TD="$W/sess/subagents"
  mkdir -p "$TD" "$W/_bmad-output/.wait-beats" || broken "cannot create the section 29 world"
  df_ledger_row toolu_df975epoch 900
}
df_agent() {  # $1 = agent id, $2 = part number, $3 = tool_use_id (default toolu_df_<id>) -> its ledger row and meta.json
  da_t_="${3:-toolu_df_$1}"
  df_ledger_row "$da_t_" 800
  printf '{"agentType":"remediator","isBuiltIn":false,"description":"Repair part %s brief","toolUseId":"%s","spawnDepth":1}\n' "$2" "$da_t_" \
    > "$TD/agent-$1.meta.json" || broken "cannot write the section 29 meta.json"
}
df_tx() {  # $1 = agent id; rest = kind:age (user assistant req attach apierr) -> appended to its transcript
  dt_a_="$1"; shift
  for dt_s_ in "$@"; do
    dt_t_="$(df_iso_ms "${dt_s_#*:}" 300)"
    case "${dt_s_%%:*}" in
      user) printf '{"parentUuid":null,"isSidechain":true,"agentId":"%s","type":"user","message":{"role":"user","content":[{"type":"text","text":"brief"}]},"uuid":"u1","timestamp":"%s"}\n' "$dt_a_" "$dt_t_" ;;
      assistant) printf '{"parentUuid":"u1","isSidechain":true,"agentId":"%s","message":{"model":"m","type":"message","role":"assistant","content":[{"type":"text","text":"ok"}]},"type":"assistant","uuid":"u2","timestamp":"%s"}\n' "$dt_a_" "$dt_t_" ;;
      req) printf '{"type":"api-request","sessionId":"s","agentId":"%s","id":"r1","timestamp":"%s","querySource":"agent:custom:remediator","shapeHash":"c349"}\n' "$dt_a_" "$dt_t_" ;;
      attach) printf '{"parentUuid":"u2","isSidechain":true,"agentId":"%s","attachment":{"type":"deferred_tools_delta","addedNames":["SendMessage"]},"type":"attachment","uuid":"u3","timestamp":"%s"}\n' "$dt_a_" "$dt_t_" ;;
      apierr) printf '{"parentUuid":"u2","isSidechain":true,"agentId":"%s","type":"assistant","uuid":"u4","timestamp":"%s","message":{"model":"<synthetic>","role":"assistant","type":"message","content":[{"type":"text","text":"API Error: Connection refused"}]},"isApiErrorMessage":true}\n' "$dt_a_" "$dt_t_" ;;
      *) broken "df_tx: no line kind ${dt_s_%%:*}" ;;
    esac >> "$TD/agent-$dt_a_.jsonl" || broken "cannot write the section 29 transcript"
  done
}
df_notice() {  # $1 = agent id, $2 = part, $3 = age -> one harness task-notification (status failed) in the lead transcript
  printf '{"type":"queue-operation","operation":"enqueue","timestamp":"%s","sessionId":"s","content":"<task-notification>\\n<task-id>%s</task-id>\\n<tool-use-id>toolu_df_%s</tool-use-id>\\n<status>failed</status>\\n<summary>Agent \\"Repair part %s brief\\" failed: Agent terminated early due to an API error: API Error: Connection refused</summary>\\n</task-notification>"}\n' \
    "$(df_iso_ms "$3" 500)" "$1" "$1" "$2" >> "$W/sess.jsonl" || broken "cannot write the lead transcript"
}
df_snapshot() {  # rest = agent:deliverable rows -> the In-Flight Teammates table, rows in the order given
  { printf '# Pipeline snapshot\n\n## In-Flight Teammates\n\n| agent | role | dispatched-at | status | deliverable |\n|---|---|---|---|---|\n'
    for ds_r_ in "$@"; do printf '| %s (remediator) | remediator | %s | in-flight | `%s` |\n' "${ds_r_%%:*}" "$(df_iso_ms 800 000)" "${ds_r_#*:}"; done
    printf '\n## Next\n'
  } > "$W/_bmad-output/pipeline-snapshot.md" || broken "cannot write the pipeline snapshot"
}
# THE POLL HOOK. Sourced by the in-process sleep in a subshell of the beat, where wck_n_ is the virtual
# now the sleep just reached: `reply` answers the open request once, `retry` sends one more request.
df_on_sleep() {  # $1 = transcript, $2 = agent id, $3 = reply|retry
  dos_t_="$("$WBL_REAL_DATE" -u -r "$wck_n_" +%Y-%m-%dT%H:%M:%S 2>/dev/null || "$WBL_REAL_DATE" -u -d "@$wck_n_" +%Y-%m-%dT%H:%M:%S 2>/dev/null)"
  case "$3" in
    reply) [ -e "$1.replied" ] && return 0; : > "$1.replied"
      printf '{"parentUuid":"u1","isSidechain":true,"agentId":"%s","message":{"model":"m","type":"message","role":"assistant","content":[{"type":"text","text":"ok"}]},"type":"assistant","uuid":"u5","timestamp":"%s.300Z"}\n' "$2" "$dos_t_" >> "$1" ;;
    retry) printf '{"type":"api-request","sessionId":"s","agentId":"%s","id":"r9","timestamp":"%s.300Z","shapeHash":"c349"}\n' "$2" "$dos_t_" >> "$1" ;;
  esac
}
df_beat() {  # $1 = subject (in a sibling dir); rest = argv -> OUT, RC, DF_EL (virtual seconds the beat took)
  db_s_="$1"; shift; db_o_="$(fx_offset "$W")"
  ( cd "$W" && unset CLAUDE_CODE_SESSION_ID && export AI_DLC_WAIT_BEAT_SECS="${DF_BUDGET:-300}" AI_DLC_WAIT_POLL_SECS=30 \
      AI_DLC_WAIT_MARGIN_SECS=0 AI_DLC_MAX_WAIT_BEATS="${DF_MAXB:-3}" AI_DLC_TEAMMATE_IDLE_SECS=3600 AI_DLC_WAIT_SETTLE_SECS=1 \
      AI_DLC_TEAMMATE_DIR="$TD" AI_DLC_PROJECT_ROOT="$PWD" && wbl_ip "$db_s_" "$@" ) > "$BEATOUT" 2>&1
  RC=$?; OUT="$(cat "$BEATOUT")"; DF_EL=$(( $(fx_offset "$W") - db_o_ ))
}
df_cap() {  # $1 = target -> its counter at the bound, as the last charged beat leaves it
  printf '%s' "${DF_MAXB:-3}" > "$W/_bmad-output/.wait-beats/.bound" && printf '%s' "${DF_MAXB:-3}" > "$W/_bmad-output/.wait-beats/$(fx_key "$1")" \
    || broken "cannot seed the beat counter"
}
df_scf() {  # $1 = agent id, $2 = target -> the path of that agent's early-break sidecar for that target
  printf '%s' "$W/_bmad-output/.wait-beats/failed-$1-$(fx_key "$2")"
}
df_nsc() {  # -> the number of early-break sidecars of any agent and target in W
  dns_n_=0; for dns_f_ in "$W/_bmad-output/.wait-beats/"failed-*; do [ -e "$dns_f_" ] && dns_n_=$(( dns_n_ + 1 )); done
  printf '%s' "$dns_n_"
}
df_count() {  # $1 = text -> the number of output lines that open with it
  dc_n_="$(printf '%s\n' "$OUT" | grep -c "^$1")" || dc_n_=0; printf '%s' "$dc_n_"
}
# S1. Dead, its one open request 1500 s old, and the transcript's MTIME at the virtual now: the file looks
# fresh, the request does not. FAILED by arm B, and the beat breaks on its first poll and is refunded.
S29a_failed_open_request_breaks_early() {
  DFS="$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  df_world; df_agent "$DF_DEAD" 1; df_tx "$DF_DEAD" user:1600 assistant:1600 req:1500
  fx_settime "$TD/agent-$DF_DEAD.jsonl" "$(fx_now "$W")"
  df_beat "$DFS" --dispatch "toolu_df_$DF_DEAD" p1.md
  if [ "$RC" -eq 0 ] && has "${DF_HDR}$DF_DEAD (Repair part 1 brief) -- its last request has had no reply past the bound" \
     && has "  arm B: its last record is an api-request sent 1500s ago with no reply (bound 1200s)" \
     && has "  Resume THIS agent by id (SendMessage to $DF_DEAD)." && has "$DF_EARLY" && ! has "  arm A:" \
     && [ "$DF_EL" -le 120 ]; then
    ok "dispatch-failed: an open request 1500s old under a transcript touched at the virtual now is FAILED by arm B, and the beat ended after ${DF_EL}s virtual (<= 120), refunded"
  else bad "dispatch-failed: a dead request under a fresh mtime was not named FAILED, or the beat did not break early (rc=$RC, ${DF_EL}s virtual): $OUT"; fi
}
# S2. Dead, then only harness attachment lines, stamped fresh: an attachment does not answer a request.
S29b_failed_attachment_does_not_answer() {
  DFS="$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  df_world; df_agent "$DF_DEAD" 2; df_tx "$DF_DEAD" user:1600 assistant:1600 req:1500 attach:5 attach:0
  df_beat "$DFS" --dispatch "toolu_df_$DF_DEAD" p2.md
  if has "${DF_HDR}$DF_DEAD (Repair part 2 brief)" && has "  arm B: its last record is an api-request sent 1500s ago with no reply (bound 1200s)"; then
    ok "dispatch-failed: an open request followed only by fresh attachment lines is still FAILED (arm B)"
  else bad "dispatch-failed: attachment lines after a dead request hid it (rc=$RC): $OUT"; fi
}
# S3. A live long request: answered by the beat's first poll, before the bound. Not FAILED, and the beat
# runs out its deadline. Its allow-twin, one property apart: the same world with no reply is FAILED at the
# first rescan past the bound (1100 s + 120 s), so this arm cannot pass on an arm B that never fires.
S29c_answered_request_is_not_failed() {
  DFS="$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  df_world; df_agent "$DF_DEAD" 3; df_tx "$DF_DEAD" user:1100 assistant:1100 req:1100
  fx_onsleep "$W" "df_on_sleep '$TD/agent-$DF_DEAD.jsonl' '$DF_DEAD' reply"
  df_beat "$DFS" --dispatch "toolu_df_$DF_DEAD" p3.md
  if [ "$RC" -eq 0 ] && ! has "$DF_HDR" && [ "$DF_EL" -eq 270 ] && has "WAITING   p3.md -- beat 1/3"; then
    ok "dispatch-failed: a 1100s request answered on the first poll is not FAILED, and the beat runs its whole 270s virtual"
  else bad "dispatch-failed: an answered request was named FAILED or the beat ended early (rc=$RC, ${DF_EL}s virtual): $OUT"; fi
  df_world; df_agent "$DF_DEAD" 3; df_tx "$DF_DEAD" user:1100 assistant:1100 req:1100
  df_beat "$DFS" --dispatch "toolu_df_$DF_DEAD" p3.md
  if has "${DF_HDR}$DF_DEAD" && has "sent 1220s ago with no reply (bound 1200s)" && [ "$DF_EL" -eq 120 ]; then
    ok "dispatch-failed: TWIN — the same 1100s request never answered is FAILED at the first rescan past the bound (1220s, beat ended at 120s virtual)"
  else bad "dispatch-failed: TWIN FAILED — an unanswered request crossing the bound mid-beat was not named at 1220s (rc=$RC, ${DF_EL}s virtual): $OUT"; fi
}
# S4. A wedge: the run's FIRST request is 2400 s old and its newest 1100 s, and every poll sends another.
# Keyed on the newest send it is STALLED and never FAILED; keyed on the first of the run it would be.
# Twin: the same run with no fresh retries crosses the bound and is FAILED.
S29d_wedge_is_stalled_not_failed() {
  DFS="$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  df_world; df_agent "$DF_DEAD" 4; df_tx "$DF_DEAD" assistant:3600 req:2400 req:1700 req:1100
  fx_onsleep "$W" "df_on_sleep '$TD/agent-$DF_DEAD.jsonl' '$DF_DEAD' retry"
  df_beat "$DFS" --dispatch "toolu_df_$DF_DEAD" p4.md
  if [ "$RC" -eq 0 ] && has "${STALL_LINE}agent-$DF_DEAD.jsonl" && ! has "$DF_HDR" && [ "$DF_EL" -eq 270 ]; then
    ok "dispatch-failed: a wedge whose retries keep its newest send fresh is TEAMMATE STALLED, not FAILED (first of the run 2400s old)"
  else bad "dispatch-failed: a retrying wedge was named FAILED, or not STALLED (rc=$RC, ${DF_EL}s virtual): $OUT"; fi
  df_world; df_agent "$DF_DEAD" 4; df_tx "$DF_DEAD" assistant:3600 req:2400 req:1700 req:1100
  df_beat "$DFS" --dispatch "toolu_df_$DF_DEAD" p4.md
  if has "${DF_HDR}$DF_DEAD" && has "sent 1220s ago with no reply"; then
    ok "dispatch-failed: TWIN — the same run with no fresh retry is FAILED once its newest send passes the bound"
  else bad "dispatch-failed: TWIN FAILED — a run whose newest send went stale was not named (rc=$RC): $OUT"; fi
}
# S5. Arm A: the harness's failed notice, and nothing in the agent's transcript newer -> FAILED; the same
# agent then resumed (a user line and a reply newer than the notice) -> not FAILED, and the sidecar STAYS:
# it goes only with its target's join state (S16), never because one scan saw the agent not FAILED.
S29e_failed_notice_and_resume() {
  DFS="$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  df_world; df_agent "$DF_DEAD" 5; df_tx "$DF_DEAD" user:900 req:880 assistant:870; df_notice "$DF_DEAD" 5 600
  dfe_ts_="$(df_iso_ms 600 500)"
  df_beat "$DFS" --dispatch "toolu_df_$DF_DEAD" p5.md
  if has "${DF_HDR}$DF_DEAD (Repair part 5 brief) -- the harness reported it failed, and it has written nothing since" \
     && has "  arm A: the harness reported it failed at ${dfe_ts_}: Agent \"Repair part 5 brief\" failed: Agent terminated early" \
     && has "  Resume THIS agent by id, or re-dispatch its deliverable." && ! has "  arm B:" \
     && [ -f "$(df_scf "$DF_DEAD" p5.md)" ]; then
    ok "dispatch-failed: the harness's failed notice with nothing newer in the transcript is FAILED by arm A, and the sidecar is written"
  else bad "dispatch-failed: a failed notice with no later record was not named by arm A (rc=$RC): $OUT"; fi
  df_tx "$DF_DEAD" user:300 req:295 assistant:290
  df_beat "$DFS" --dispatch "toolu_df_$DF_DEAD" p5.md
  if [ "$RC" -eq 0 ] && ! has "$DF_HDR" && has "WAITING   p5.md" && [ -f "$(df_scf "$DF_DEAD" p5.md)" ]; then
    ok "dispatch-failed: the same agent resumed after the notice (a newer user line) is not FAILED, and its join-scoped sidecar stays"
  else bad "dispatch-failed: a resumed agent was still named FAILED, or its sidecar was dropped inside the join (rc=$RC): $OUT"; fi
}
# S6. The third death shape: the transcript ENDS in an isApiErrorMessage assistant line, which closes the
# request and reads as a fresh turn. Only arm A sees it, and a FAILED agent is never LIVE: at the cap under
# --complete-repair it gets no grant and no LIVE DISPATCH. Twin: the same world with no notice is LIVE and
# granted, so the arm cannot pass on a turn that was never fresh enough to grant.
S29f_api_error_turn_is_failed_never_live() {
  DFS="$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  df_world; df_agent "$DF_DEAD" 6; df_tx "$DF_DEAD" user:20 req:15 apierr:10; df_notice "$DF_DEAD" 6 5; df_cap rec.md
  DF_BUDGET=30 df_beat "$DFS" --complete-repair --dispatch "toolu_df_$DF_DEAD" rec.md
  if [ "$RC" -eq 1 ] && has "${DF_HDR}$DF_DEAD (Repair part 6 brief) -- the harness reported it failed, and it has written nothing since" \
     && has "  arm A: the harness reported it failed at" && ! has "  arm B:" \
     && has "  Resume THIS agent by id, or re-dispatch its deliverable." && ! has "LIVE DISPATCH" && ! has "PROGRESS"; then
    ok "dispatch-failed: a transcript ending in an API-error turn after a failed notice is FAILED by arm A alone, with no grant and no LIVE DISPATCH (rc 1)"
  else bad "dispatch-failed: an API-error death was granted, read LIVE, or not named by arm A (rc=$RC): $OUT"; fi
  df_world; df_agent "$DF_DEAD" 6; df_tx "$DF_DEAD" user:20 req:15 apierr:10; df_cap rec.md
  DF_BUDGET=30 df_beat "$DFS" --complete-repair --dispatch "toolu_df_$DF_DEAD" rec.md
  if [ "$RC" -eq 0 ] && has "PROGRESS  rec.md -- work observed in agent-$DF_DEAD.jsonl" && ! has "$DF_HDR"; then
    ok "dispatch-failed: TWIN — the same API-error turn with no failed notice reads as a fresh turn and is granted (rc 0)"
  else bad "dispatch-failed: TWIN FAILED — without the notice the fresh turn was not granted, so the arm above proves nothing (rc=$RC): $OUT"; fi
}
# S7 (and S14's world). --status over a dead dispatch: every target delivered prints no block; the same
# world with the second target absent prints it. The gate, not the world, silences it.
df_status_world() {  # $1 = 1 to write p2.md -> W
  df_world; df_agent "$DF_DEAD" 7; df_tx "$DF_DEAD" user:1600 assistant:1600 req:1500
  printf 'part 1\n' > "$W/p1.md" || broken "cannot write p1.md"
  [ "$1" = 1 ] && { printf 'part 2\n' > "$W/p2.md" || broken "cannot write p2.md"; }
  return 0
}
S29g_all_delivered_is_not_failed() {
  DFS="$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  df_status_world 1
  df_beat "$DFS" --status --dispatch "toolu_df_$DF_DEAD" p1.md p2.md
  if [ "$RC" -eq 0 ] && has "STATUS -- 2 delivered, 0 not." && ! has "$DF_HDR"; then
    ok "dispatch-failed: --status with every target delivered prints no block over a stale open request"
  else bad "dispatch-failed: --status named a dead agent whose targets are all delivered (rc=$RC): $OUT"; fi
  df_beat "$DFS" --dispatch "toolu_df_$DF_DEAD" p1.md p2.md
  if [ "$RC" -eq 0 ] && has "DELIVERED p1.md" && has "DELIVERED p2.md" && ! has "$DF_HDR"; then
    ok "dispatch-failed: a beat whose targets are all delivered prints no block over a stale open request"
  else bad "dispatch-failed: a beat named a dead agent whose targets are all delivered (rc=$RC): $OUT"; fi
  df_status_world 0
  df_beat "$DFS" --status --dispatch "toolu_df_$DF_DEAD" p1.md p2.md
  if has "STATUS -- 1 delivered, 1 not." && has "${DF_HDR}$DF_DEAD"; then
    ok "dispatch-failed: TWIN — the same world with p2.md absent prints the block, so the silence above is the gate's"
  else bad "dispatch-failed: TWIN FAILED — with a target out the block did not print (rc=$RC): $OUT"; fi
}
# S9. Three dispatched agents, the dead one in the middle of the dispatch order and of the ledger. Then a
# dead agent whose id carries '-': its id is read as a literal, never skipped.
df_dash_beat() {  # $1 = subject -> OUT, RC over a live agent and a dead one with a dashed id
  df_world; df_agent "$DF_LIVE" 1; df_agent "$DF_DASH" 4 toolu_df_dash4
  df_tx "$DF_LIVE" user:120 req:115 assistant:100; df_tx "$DF_DASH" user:1600 assistant:1600 req:1500
  df_beat "$1" --dispatch "toolu_df_$DF_LIVE" --dispatch toolu_df_dash4 p1.md p4.md
}
S29i_one_dead_of_three() {
  DFS="$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  df_world; df_agent "$DF_LIVE" 1; df_agent "$DF_DEAD" 2; df_agent "$DF_LIVE2" 3
  df_tx "$DF_LIVE" user:120 req:115 assistant:100; df_tx "$DF_DEAD" user:1600 assistant:1600 req:1500; df_tx "$DF_LIVE2" user:60 req:55 assistant:50
  df_beat "$DFS" --dispatch "toolu_df_$DF_LIVE" --dispatch "toolu_df_$DF_DEAD" --dispatch "toolu_df_$DF_LIVE2" p1.md p2.md p3.md
  if [ "$(df_count "$DF_HDR")" -eq 1 ] && has "${DF_HDR}$DF_DEAD (Repair part 2 brief)" \
     && ! has "${DF_HDR}$DF_LIVE" && ! has "${DF_HDR}$DF_LIVE2" && has "  Not delivered: p1.md p2.md p3.md"; then
    ok "dispatch-failed: of three dispatched agents exactly one block prints, naming the dead one (the middle of the order)"
  else bad "dispatch-failed: three agents with one dead did not print exactly one block naming it ($(df_count "$DF_HDR") blocks): $OUT"; fi
  # A dashed agent id is read, never skipped: the dead agent second of two, its id carrying '-'.
  df_dash_beat "$DFS"
  if [ "$(df_count "$DF_HDR")" -eq 1 ] && has "${DF_HDR}$DF_DASH (Repair part 4 brief) -- its last request has had no reply past the bound" \
     && has "  arm B: its last record is an api-request sent 1500s ago with no reply (bound 1200s)" \
     && has "  Resume THIS agent by id (SendMessage to $DF_DASH)." && has "$DF_EARLY" \
     && [ -f "$(df_scf "$DF_DASH" p1.md)" ] && [ -f "$(df_scf "$DF_DASH" p4.md)" ] && [ "$(df_nsc)" -eq 2 ]; then
    ok "dispatch-failed: a dead agent whose id carries '-' is named FAILED by arm B, and its sidecar is written under that id for each pending target"
  else bad "dispatch-failed: a dashed agent id was skipped or misread ($(df_count "$DF_HDR") blocks, rc=$RC): $OUT"; fi
}
# S10. The motivating mis-map: the dead agent's row claims a path that IS delivered (by another agent),
# while another target is out. A row never acquits: FAILED, with the row's claim quoted as a claim.
S29j_misplaced_row_does_not_acquit() {
  DFS="$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  df_world; df_agent "$DF_LIVE" 1; df_agent "$DF_DEAD" 2
  df_tx "$DF_LIVE" user:300 req:295 assistant:290; df_tx "$DF_DEAD" user:1600 assistant:1600 req:1500
  df_snapshot "$DF_LIVE:p2.md" "$DF_DEAD:p1.md"; printf 'part 1\n' > "$W/p1.md" || broken "cannot write p1.md"
  df_beat "$DFS" --dispatch "toolu_df_$DF_LIVE" --dispatch "toolu_df_$DF_DEAD" p1.md p2.md
  if has "${DF_HDR}$DF_DEAD (Repair part 2 brief)" \
     && has "  In-Flight row claims deliverable: p1.md   (the row is the lead's claim; check it against the description)" \
     && has "  Not delivered: p2.md" && ! has "${DF_HDR}$DF_LIVE"; then
    ok "dispatch-failed: a dead agent whose row names a DELIVERED path is still FAILED, and the row's claim is printed as a claim"
  else bad "dispatch-failed: a mis-mapped row acquitted the dead agent or was not quoted (rc=$RC): $OUT"; fi
}
# S11. No row for the dead agent at all.
S29k_no_row_reads_none() {
  DFS="$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  df_world; df_agent "$DF_LIVE" 1; df_agent "$DF_DEAD" 2
  df_tx "$DF_LIVE" user:300 req:295 assistant:290; df_tx "$DF_DEAD" user:1600 assistant:1600 req:1500
  df_snapshot "$DF_LIVE:p1.md"
  df_beat "$DFS" --dispatch "toolu_df_$DF_LIVE" --dispatch "toolu_df_$DF_DEAD" p1.md p2.md
  if has "${DF_HDR}$DF_DEAD" && has "  In-Flight row claims deliverable: none   (the row is the lead's claim"; then
    ok "dispatch-failed: a dead agent with no In-Flight row is FAILED and its row claim reads 'none'"
  else bad "dispatch-failed: a dead agent with no row was not named, or its claim did not read none (rc=$RC): $OUT"; fi
}
# S12. Under --complete the dead agent's deliverable EXISTS but carries no seat-complete line: the gate is
# the beat's own predicate, never file existence, so the target is listed as not delivered.
S29l_present_unsealed_is_not_delivered() {
  DFS="$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  df_world; df_agent "$DF_DEAD" 1; df_tx "$DF_DEAD" user:1600 assistant:1600 req:1500
  printf '%s\n' "$SKELETON" > "$W/p1.md" || broken "cannot write p1.md"
  df_beat "$DFS" --complete --dispatch "toolu_df_$DF_DEAD" p1.md
  if has "${DF_HDR}$DF_DEAD" && has "  Not delivered: p1.md" && ! has "DELIVERED p1.md"; then
    ok "dispatch-failed: under --complete a present but unsealed deliverable is FAILED and listed as not delivered"
  else bad "dispatch-failed: a present unsealed deliverable acquitted the dead agent under --complete (rc=$RC): $OUT"; fi
}
# S13. Repeated beats, the dead agent never resumed, a live sibling's target out too. Beat 1 breaks on its
# first poll and is refunded (beat 0/3); beats 2-4 run out their deadline and are charged; the cap is beat 5.
df_sequence() {  # $1 = subject -> DFQ_N (the beat that exited 1), DFQ_EL (virtual seconds per beat), DFQ_B1 (beat 1's output)
  df_world; df_agent "$DF_LIVE" 1; df_agent "$DF_DEAD" 2
  df_tx "$DF_LIVE" user:60 req:55 assistant:50; df_tx "$DF_DEAD" user:1600 assistant:1600 req:1500
  DFQ_N=0; DFQ_EL=""; DFQ_B1=""; dq_i_=0
  while [ "$dq_i_" -lt 8 ]; do
    dq_i_=$(( dq_i_ + 1 ))
    df_beat "$1" --dispatch "toolu_df_$DF_LIVE" --dispatch "toolu_df_$DF_DEAD" p1.md p2.md
    DFQ_EL="$DFQ_EL $DF_EL"; [ "$dq_i_" -eq 1 ] && DFQ_B1="$OUT"
    [ "$RC" -eq 1 ] && { DFQ_N="$dq_i_"; break; }
  done
}
S29m_dead_agent_breaks_once() {
  DFS="$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  df_sequence "$DFS"
  case "$DFQ_B1" in *"$DF_EARLY"*"BEAT COMPLETE"*) dq_e_=1 ;; *) dq_e_=0 ;; esac
  case "$DFQ_B1" in *"WAITING   p1.md -- beat 0/3"*) dq_r_=1 ;; *) dq_r_=0 ;; esac
  if [ "$DFQ_N" -eq 5 ] && [ "$DFQ_EL" = " 0 270 270 270 0" ] && [ "$dq_e_" = 1 ] && [ "$dq_r_" = 1 ] \
     && has "NON-DELIVERY p1.md" && has "${DF_HDR}$DF_DEAD" && ! has "$DF_EARLY"; then
    ok "dispatch-failed: a never-resumed dead agent breaks beat 1 only (0s, refunded to beat 0/3); beats 2-4 run 270s each and the cap is beat 5, still naming it"
  else bad "dispatch-failed: repeated beats over a dead agent broke more than once, charged the early beat, or capped at beat $DFQ_N (virtual seconds:$DFQ_EL): $DFQ_B1 ... $OUT"; fi
}
# S14. --status over a dead dispatch with a target out prints the whole block, and writes no sidecar.
S29n_status_prints_block() {
  DFS="$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  df_status_world 0
  df_beat "$DFS" --status --dispatch "toolu_df_$DF_DEAD" p1.md p2.md
  if [ "$RC" -eq 0 ] && has "${DF_HDR}$DF_DEAD (Repair part 7 brief) -- its last request has had no reply past the bound" \
     && has "  arm B: its last record is an api-request sent 1500s ago with no reply (bound 1200s)" \
     && has "  In-Flight row claims deliverable: none" && has "  Not delivered: p2.md" \
     && has "  Resume THIS agent by id (SendMessage to $DF_DEAD)." && ! has "$DF_EARLY" \
     && [ "$(df_nsc)" -eq 0 ]; then
    ok "dispatch-failed: --status over a dead dispatch prints the whole block and writes no sidecar"
  else bad "dispatch-failed: --status did not print the block, or wrote a sidecar (rc=$RC): $OUT"; fi
}
# S15. The measured live shape at the cap: a --complete-repair single dispatch whose newest send of a
# two-send run has stayed open 853 s -- the max open interval of a LIVE agent (send to next send or
# reply) over 6,023 graph transcripts -- and is answered on the beat's first poll. Not FAILED, the grant
# is kept (rc 0, PROGRESS) and the granted beat runs out its 1380 s. Budget 1400, so the turn before
# the run (859 s) reads LIVE -- at a 600 s quantum the turn is outside the LIVE band and no grant is
# possible on any bound, because the open send sits after the turn. Twin, one property apart: the same
# run at 1300 s (the turn at 1306 s, still LIVE) is FAILED and arm B alone denies the grant, so this arm
# cannot pass on an arm B that never fires.
df_open_interval_world() {  # $1 = newest send age -> W, a live agent at the cap whose turn is 6 s older
  df_world; df_agent "$DF_LIVE" 15
  df_tx "$DF_LIVE" user:$(( $1 + 17 )) assistant:$(( $1 + 6 )) req:$(( $1 + 5 )) req:"$1"; df_cap rec.md
}
S29o_live_open_interval_is_not_failed() {
  DFS="$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  df_open_interval_world 853
  fx_onsleep "$W" "df_on_sleep '$TD/agent-$DF_LIVE.jsonl' '$DF_LIVE' reply"
  DF_BUDGET=1400 df_beat "$DFS" --complete-repair --dispatch "toolu_df_$DF_LIVE" rec.md
  if [ "$RC" -eq 0 ] && has "PROGRESS  rec.md -- work observed in agent-$DF_LIVE.jsonl" && ! has "$DF_HDR" && [ "$DF_EL" -eq 1380 ]; then
    ok "dispatch-failed: a live agent at the cap whose newest send has been open 853s (the measured max) is not FAILED, keeps its grant (rc 0) and runs 1380s virtual"
  else bad "dispatch-failed: a live 853s open interval was named FAILED or lost its grant (rc=$RC, ${DF_EL}s virtual): $OUT"; fi
  df_open_interval_world 1300
  DF_BUDGET=1400 df_beat "$DFS" --complete-repair --dispatch "toolu_df_$DF_LIVE" rec.md
  if [ "$RC" -eq 1 ] && has "${DF_HDR}$DF_LIVE (Repair part 15 brief)" && has "  arm B: its last record is an api-request sent 1300s ago with no reply (bound 1200s)" \
     && ! has "PROGRESS"; then
    ok "dispatch-failed: TWIN — the same run with its newest send open 1300s is FAILED and arm B alone denies the LIVE grant (rc 1)"
  else bad "dispatch-failed: TWIN FAILED — a 1300s open send at the cap was not named FAILED (rc=$RC): $OUT"; fi
}
# S16. One join, the agent flapping FAILED -> answered -> FAILED: beat 1 breaks and is refunded (beat 0/3);
# beat 2 sees it answered and runs (1/3); beat 3 sees a new open request past the bound, prints the block,
# and does NOT break or refund again (2/3), because the sidecar is keyed per target, and so per join. Then
# --reset drops the join state, the target's sidecar included, and the next beat breaks and is refunded once more.
df_flap() {  # $1 = subject -> DFF_EL (virtual seconds per beat), DFF_O1..DFF_O4, DFF_SC (1: sidecar after beat 3)
  df_world; df_agent "$DF_DEAD" 16; df_tx "$DF_DEAD" user:1600 assistant:1600 req:1500
  DFF_EL=""
  df_beat "$1" --dispatch "toolu_df_$DF_DEAD" p1.md; DFF_EL="$DFF_EL $DF_EL"; DFF_O1="$OUT"
  df_tx "$DF_DEAD" assistant:1490
  df_beat "$1" --dispatch "toolu_df_$DF_DEAD" p1.md; DFF_EL="$DFF_EL $DF_EL"; DFF_O2="$OUT"
  df_tx "$DF_DEAD" req:1250
  df_beat "$1" --dispatch "toolu_df_$DF_DEAD" p1.md; DFF_EL="$DFF_EL $DF_EL"; DFF_O3="$OUT"
  DFF_SC=0; [ -f "$(df_scf "$DF_DEAD" p1.md)" ] && DFF_SC=1
  df_beat "$1" --reset --dispatch "toolu_df_$DF_DEAD" p1.md; DFF_EL="$DFF_EL $DF_EL"; DFF_O4="$OUT"
}
S29p_flap_within_join_refunds_once() {
  DFS="$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  df_flap "$DFS"
  dff_bad_=""
  [ "$DFF_EL" = " 0 270 270 0" ] || dff_bad_="$dff_bad_ seconds:$DFF_EL"
  case "$DFF_O1" in *"$DF_EARLY"*"WAITING   p1.md -- beat 0/3"*|*"WAITING   p1.md -- beat 0/3"*"$DF_EARLY"*) ;; *) dff_bad_="$dff_bad_ beat1" ;; esac
  case "$DFF_O2" in *"$DF_HDR"*) dff_bad_="$dff_bad_ beat2-named" ;; *"WAITING   p1.md -- beat 1/3"*) ;; *) dff_bad_="$dff_bad_ beat2" ;; esac
  case "$DFF_O3" in *"$DF_EARLY"*) dff_bad_="$dff_bad_ beat3-refunded" ;; *"WAITING   p1.md -- beat 2/3"*"${DF_HDR}$DF_DEAD"*) ;; *) dff_bad_="$dff_bad_ beat3" ;; esac
  [ "$DFF_SC" = 1 ] || dff_bad_="$dff_bad_ sidecar"
  case "$DFF_O4" in *"$DF_EARLY"*) ;; *) dff_bad_="$dff_bad_ reset" ;; esac
  if [ -z "$dff_bad_" ]; then
    ok "dispatch-failed: an agent flapping FAILED, answered, FAILED inside one join is refunded once (beats 0/3, 1/3, 2/3; 0 270 270s), and --reset drops the sidecar so the next beat breaks again"
  else bad "dispatch-failed: a flapping agent was refunded more than once in a join, or --reset kept its sidecar [${dff_bad_# }]: $DFF_O3 ... $DFF_O4"; fi
}
# S17. The sidecar is keyed per TARGET, so per join. Join 1 (q1.md) breaks early over the dead agent and
# writes its sidecar, then closes on a beat with NO --dispatch once q1.md lands, which knows no agent ids;
# join 2, on a fresh path, dispatches the SAME agent id and must break early and be refunded (beat 0/3).
# A per-agent key outlives join 1 and join 2 then runs its whole 270 s, charged (beat 1/3).
df_crossjoin() {  # $1 = subject -> DFX_O1 (join 1 beat 1), DFX_O2 (join 1 closing beat), DFX_EL, DFX_SC1, DFX_SC1G; OUT, RC: join 2
  df_world; df_agent "$DF_DEAD" 17; df_tx "$DF_DEAD" user:1600 assistant:1600 req:1500
  df_beat "$1" --dispatch "toolu_df_$DF_DEAD" q1.md; DFX_O1="$OUT"; DFX_EL="$DF_EL"
  DFX_SC1=0; [ -f "$(df_scf "$DF_DEAD" q1.md)" ] && DFX_SC1=1
  printf 'part 17\n' > "$W/q1.md" || broken "cannot write q1.md"
  fx_settime "$W/q1.md" "$(fx_now "$W")"
  df_beat "$1" q1.md; DFX_O2="$OUT"; DFX_EL="$DFX_EL $DF_EL"
  DFX_SC1G=0; [ -f "$(df_scf "$DF_DEAD" q1.md)" ] || DFX_SC1G=1
  df_beat "$1" --dispatch "toolu_df_$DF_DEAD" q2.md; DFX_EL="$DFX_EL $DF_EL"
}
S29q_agent_reused_in_new_join_breaks_again() {
  DFS="$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  df_crossjoin "$DFS"
  dfx_bad_=""
  case "$DFX_O1" in *"$DF_EARLY"*) ;; *) dfx_bad_="$dfx_bad_ join1-no-break" ;; esac
  [ "$DFX_SC1" = 1 ] || dfx_bad_="$dfx_bad_ join1-no-sidecar"
  case "$DFX_O2" in *"DELIVERED q1.md"*) ;; *) dfx_bad_="$dfx_bad_ join1-not-closed" ;; esac
  [ "$DFX_SC1G" = 1 ] || dfx_bad_="$dfx_bad_ join1-sidecar-kept"
  has "$DF_EARLY" || dfx_bad_="$dfx_bad_ join2-no-break"
  has "WAITING   q2.md -- beat 0/3" || dfx_bad_="$dfx_bad_ join2-charged"
  has "${DF_HDR}$DF_DEAD (Repair part 17 brief)" || dfx_bad_="$dfx_bad_ join2-unnamed"
  [ -f "$(df_scf "$DF_DEAD" q2.md)" ] || dfx_bad_="$dfx_bad_ join2-no-sidecar"
  case "$DFX_EL" in " "*) dfx_bad_="$dfx_bad_ seconds" ;; "0 "*" 0") ;; *) dfx_bad_="$dfx_bad_ seconds" ;; esac
  if [ "$RC" -eq 0 ] && [ -z "$dfx_bad_" ]; then
    ok "dispatch-failed: an agent id reused in a later join on a fresh path breaks that join early and is refunded (beat 0/3), after join 1 closed on a beat with no --dispatch and took its sidecar with it (virtual seconds: $DFX_EL)"
  else bad "dispatch-failed: an agent reused in a new join lost its early break or refund, or join 1 kept its sidecar [${dfx_bad_# }] (rc=$RC, virtual seconds: $DFX_EL): $OUT"; fi
}

# ===========================================================================
# 30. A ROLE-LESS SPAWN'S DISPATCH TIME IS ITS Agent tool_use LINE (BL-975). The guard writes no
#     ledger row for a role-less spawn, so a lead beat over a round-dispatcher's return file refused
#     `--dispatch` (0 rows) and was re-armed without it: the dispatcher had no DISPATCH FAILED arm.
#     The lead transcript `<sess>.jsonl` carries one Agent tool_use line per spawn, in the harness's
#     key order. Seeds, in this order (the subject is not first): a launched role-less epoch spawn, a
#     guard-denied role-bound spawn (no meta.json), the launched role-less dispatcher, a guard-denied
#     role-less spawn (no meta.json), two launched spawns with no row that name a role one way each
#     (`subagent_type` only, `team-roles/` only), and a launched role-less spawn on two lines. Only the
#     two launched role-less spawns resolve, each to its own line's stamp cut to the second; the
#     other three keep the 0-row refusal. One beat over the dead dispatcher names it FAILED.
# ===========================================================================
S30_X=a975d15c00000e005; S30_E=a975e90c00000e006; S30_R=a975b0d000000e007
s30_spawn() {  # $1 = tool_use_id, $2 = age, $3 = roleless|role|stype|troles, $4 = agent id to launch ('' = guard-denied)
  ss_t_="$(df_iso_ms "$2" 273)"
  case "$3" in
    roleless) ss_in_='{"description":"Run sprint-review party round","prompt":"You are a round-dispatcher.","run_in_background":true}' ;;
    role) ss_in_='{"description":"Party PM seat","prompt":"Read .claude/team-roles/pm.md first.","subagent_type":"pm","run_in_background":true}' ;;
    stype) ss_in_='{"description":"Party PM seat","prompt":"You are the PM seat.","subagent_type":"pm","run_in_background":true}' ;;
    troles) ss_in_='{"description":"Party PM seat","prompt":"Read .claude/team-roles/pm.md first.","run_in_background":true}' ;;
  esac
  printf '{"parentUuid":"p0","isSidechain":false,"message":{"id":"msg_s30","type":"message","role":"assistant","content":[{"type":"tool_use","id":"%s","name":"Agent","input":%s}],"stop_reason":"tool_use"},"type":"assistant","uuid":"u%s","timestamp":"%s"}\n' \
    "$1" "$ss_in_" "$2" "$ss_t_" >> "$W/sess.jsonl" || broken "cannot write the section 30 lead transcript"
  [ -z "$4" ] || printf '{"agentType":"general-purpose","isBuiltIn":true,"description":"Run sprint-review party round","toolUseId":"%s","spawnDepth":1}\n' "$1" \
    > "$TD/agent-$4.meta.json" || broken "cannot write the section 30 meta.json"
}
S30_roleless_dispatch_ts() {
  DFS="$(sib_dir "$SUBJ")/wait-for-deliverable.sh"
  df_world
  s30_spawn toolu_s30epoch 1900 roleless "$S30_E"
  s30_spawn toolu_s30denrole 1800 role ""
  s30_spawn toolu_s30disp 1700 roleless "$S30_X"
  s30_spawn toolu_s30denless 1650 roleless ""
  s30_spawn toolu_s30stype 1600 stype "$S30_R"
  s30_spawn toolu_s30troles 1590 troles a975b0d000000e008
  s30_spawn toolu_s30dup 1580 roleless a975d0b000000e009
  s30_spawn toolu_s30dup 1570 roleless ""
  # A compaction later in the same session: the transcript keeps the Agent lines above it.
  printf '{"parentUuid":null,"logicalParentUuid":"u1600","isSidechain":false,"type":"system","subtype":"compact_boundary","content":"Conversation compacted","compactMetadata":{"trigger":"auto"},"uuid":"c1","timestamp":"%s"}\n' \
    "$(df_iso_ms 1550 100)" >> "$W/sess.jsonl" || broken "cannot write the section 30 compaction line"
  s30_x_="$(df_iso_ms 1700 273)"; s30_x_="${s30_x_%.273Z}Z"
  s30_e_="$(df_iso_ms 1900 273)"; s30_e_="${s30_e_%.273Z}Z"
  s30_bad_=""
  r28_ts "$SUBJ" "$S30_X" "$TD"
  { [ "$RC" -eq 0 ] && [ "$R28_OUT" = "$s30_x_" ] && [ -z "$R28_ERR" ]; } || s30_bad_="$s30_bad_ agentid[$OUT]"
  r28_ts "$SUBJ" toolu_s30disp "$TD"
  { [ "$RC" -eq 0 ] && [ "$R28_OUT" = "$s30_x_" ]; } || s30_bad_="$s30_bad_ toolu[$OUT]"
  r28_ts "$SUBJ" "$S30_E" "$TD"
  { [ "$RC" -eq 0 ] && [ "$R28_OUT" = "$s30_e_" ]; } || s30_bad_="$s30_bad_ epoch[$OUT]"
  for s30_d_ in toolu_s30denless toolu_s30denrole toolu_s30stype toolu_s30troles toolu_s30dup; do
    r28_refuse_arm "$SUBJ" "$s30_d_" "$TD" "the ledger holds 0 row(s) for tool_use_id $s30_d_, not one" \
      || s30_bad_="$s30_bad_ $s30_d_[$OUT]"
  done
  if [ -z "$s30_bad_" ]; then
    ok "dispatch-ts: a launched role-less spawn with no ledger row prints its own Agent tool_use stamp cut to the second ($s30_x_ by agentId and by toolu_ id; the epoch spawn $s30_e_), while a guard-denied role-less, a guard-denied role-bound, a launched spawn naming only a subagent_type, one naming only a team-roles/ path and a launched role-less id on two lines each keep the 0-row refusal"
  else bad "dispatch-ts: the role-less fallback answered wrongly [${s30_bad_# }]"; fi
  df_tx "$S30_X" user:1690 assistant:1680 req:1500
  df_beat "$DFS" --dispatch "$S30_X" _bmad-output/planning-artifacts/s1/rounds/r1.return
  if [ "$RC" -eq 0 ] && has "${DF_HDR}$S30_X (Run sprint-review party round)" \
     && has "  arm B: its last record is an api-request sent 1500s ago with no reply (bound 1200s)"; then
    ok "dispatch-failed: a lead beat over a round-return file armed with --dispatch <role-less dispatcher> names the dead dispatcher FAILED by arm B"
  else bad "dispatch-failed: a beat on a dead role-less dispatcher did not name it FAILED (rc=$RC): $OUT"; fi
  # A LATER session re-arms with `--since <epoch>` alone: its own subagents dir holds no meta.json and
  # its transcript no Agent line for the dispatcher, and the beat waits exactly as before the fallback.
  TD="$W/sess2/subagents"; mkdir -p "$TD" || broken "cannot create the section 30 later session"
  rm -rf "$W/_bmad-output/.wait-beats"; mkdir -p "$W/_bmad-output/.wait-beats" || broken "cannot reset the section 30 beats"
  df_beat "$DFS" --since "$(( $(fx_now "$W") - 1800 ))" _bmad-output/planning-artifacts/s1/rounds/r1.return
  if [ "$RC" -eq 0 ] && has "WAITING   _bmad-output/planning-artifacts/s1/rounds/r1.return" \
     && ! has "$DF_HDR" && ! has "FAIL:"; then
    ok "dispatch-failed: a later session's beat over the same return file with --since alone still WAITS (rc 0), with no refusal and no FAILED block"
  else bad "dispatch-failed: a later session's --since-alone beat did not wait as before (rc=$RC): $OUT"; fi
  rm -rf "$W"
}

# ---------------------------------------------------------------------------
# THE WIRING, END TO END: ONE CLI RUN PER DISTINCT OUTCOME, EACH HELD BYTE-IDENTICAL TO wbl_ip.
# Every cell above calls the subject in process. This is where `bash wait-for-deliverable.sh` still
# runs -- once per outcome the CLI has (fixture-mutants.md clauses 5 and 6) -- and where the two
# answers are compared: the world is snapshotted, the CLI runs on it, the world and its virtual
# clock are restored to the snapshot, and wbl_ip runs on it at the same path, the same instant. Its
# stdout, its stderr and its exit code must be equal byte for byte, and the six outcomes must be six
# different answers, so the equality is shown able to fail. Not an S function: it runs once, in the
# driver.
# ---------------------------------------------------------------------------
wr_env() {  # the tuning both sides run under
  unset CLAUDE_CODE_SESSION_ID
  export AI_DLC_WAIT_BEAT_SECS=2 AI_DLC_WAIT_SETTLE_SECS=1 AI_DLC_WAIT_POLL_SECS=1 AI_DLC_WAIT_MARGIN_SECS=0 \
    AI_DLC_MAX_WAIT_BEATS=1 AI_DLC_TEAMMATE_DIR="${WR_TD:-$TMPROOT/does-not-exist}" AI_DLC_PROJECT_ROOT="$PWD"
}
wr_pair() {  # $1 = label, $2 = world; rest = argv -> WR_<label> = "rc|<stdout cksum>|<stderr cksum>"; 1 on a mismatch
  wp_l_="$1" wp_w_="$2"; shift 2
  wp_s_="$TMPROOT/wr-snap.$wp_l_"; rm -rf "$wp_s_"; cp -Rp "$wp_w_" "$wp_s_" || broken "wiring: cannot snapshot $wp_w_"
  wp_o_="$(fx_offset "$wp_w_")"
  ( cd "$wp_w_" && wr_env && bash "$SUBJ" "$@" ) > "$TMPROOT/wr.$wp_l_.cli.out" 2> "$TMPROOT/wr.$wp_l_.cli.err"; wp_rc1_=$?
  rm -rf "$wp_w_" && cp -Rp "$wp_s_" "$wp_w_" || broken "wiring: cannot restore $wp_w_"
  printf '%s' "$wp_o_" > "$(fx_clock_file "$wp_w_")"
  ( cd "$wp_w_" && wr_env && wbl_ip "$SUBJ" "$@" ) > "$TMPROOT/wr.$wp_l_.ip.out" 2> "$TMPROOT/wr.$wp_l_.ip.err"; wp_rc2_=$?
  eval "WR_$wp_l_=\"$wp_rc1_|$(cksum < "$TMPROOT/wr.$wp_l_.cli.out" | tr -d ' \t')|$(cksum < "$TMPROOT/wr.$wp_l_.cli.err" | tr -d ' \t')\""
  [ "$wp_rc1_" = "$wp_rc2_" ] && cmp -s "$TMPROOT/wr.$wp_l_.cli.out" "$TMPROOT/wr.$wp_l_.ip.out" \
    && cmp -s "$TMPROOT/wr.$wp_l_.cli.err" "$TMPROOT/wr.$wp_l_.ip.err"
}
wiring_e2e() {
  wr_bad_=""
  # (1) beat rc 0, DELIVERED: a fresh file written after the --since epoch.
  W="$(mk_work)"; printf 'answer\n' > "$W/deliv.md"
  wr_pair del "$W" --since "$(( $(fx_now "$W") - 30 ))" deliv.md || wr_bad_="$wr_bad_ del"
  grep -q '^DELIVERED deliv.md' "$TMPROOT/wr.del.cli.out" || wr_bad_="$wr_bad_ del-shape"
  rm -rf "$W"
  # (2) beat rc 1, NON-DELIVERY: the only beat already charged (the bound file and the counter at 1).
  W="$(mk_work)"; mkdir -p "$W/_bmad-output/.wait-beats"
  printf '1' > "$W/_bmad-output/.wait-beats/.bound"; printf '1' > "$W/_bmad-output/.wait-beats/$(fx_key deliv.md)"
  wr_pair nondel "$W" deliv.md || wr_bad_="$wr_bad_ nondel"
  grep -q '^NON-DELIVERY deliv.md' "$TMPROOT/wr.nondel.cli.out" || wr_bad_="$wr_bad_ nondel-shape"
  rm -rf "$W"
  # (3) rc 64, an argv refusal (one that prints no $0).
  W="$(mk_work)"
  wr_pair refuse "$W" --complete --progress-path . deliv.md || wr_bad_="$wr_bad_ refuse"
  grep -q 'cannot be combined' "$TMPROOT/wr.refuse.cli.err" || wr_bad_="$wr_bad_ refuse-shape"
  rm -rf "$W"
  # (4) --status rc 0.
  W="$(mk_work)"; printf '%s\n%s\n' "$SKELETON" "$MARKER" > "$W/s.md"
  wr_pair status "$W" --status --complete --since "$(( $(fx_now "$W") - 30 ))" s.md gone.md || wr_bad_="$wr_bad_ status"
  grep -q '^STATUS -- ' "$TMPROOT/wr.status.cli.out" || wr_bad_="$wr_bad_ status-shape"
  rm -rf "$W"
  # (5) --dispatch-ts rc 0 (beside its sibling grammar).
  r28_world; WR_SD="$(sib_dir "$SUBJ")"
  ( SUBJ="$WR_SD/wait-for-deliverable.sh"; WR_TD="$W/sub" wr_pair dts "$W" --dispatch-ts "$R28_TUI" ) || wr_bad_="$wr_bad_ dts"
  [ "$(cat "$TMPROOT/wr.dts.cli.out")" = "$R28_D" ] || wr_bad_="$wr_bad_ dts-shape"
  eval "WR_dts=\"0|$(cksum < "$TMPROOT/wr.dts.cli.out" | tr -d ' \t')|x\""
  rm -rf "$W"
  # (6) --mark rc 0 (a relative path, so the MARKED line names the same file on both sides).
  W="$(mk_work)"; printf '%s\n' "$SKELETON" > "$W/m.md"
  wr_pair mark "$W" --mark m.md requirements pm cross-1 findings=1 || wr_bad_="$wr_bad_ mark"
  grep -q '^MARKED m.md' "$TMPROOT/wr.mark.cli.out" || wr_bad_="$wr_bad_ mark-shape"
  rm -rf "$W"
  wr_all_="$(printf '%s\n' "$WR_del" "$WR_nondel" "$WR_refuse" "$WR_status" "$WR_dts" "$WR_mark")"
  wr_n_="$(printf '%s\n' "$wr_all_" | sort -u | grep -c .)" || wr_n_=0
  if [ -z "$wr_bad_" ] && [ "$wr_n_" -eq 6 ]; then
    ok "wiring: the CLI and wbl_ip answer byte-for-byte alike (stdout, stderr, rc) on six distinct outcomes: DELIVERED rc 0, NON-DELIVERY rc 1, refusal rc 64, --status, --dispatch-ts, --mark"
  else bad "wiring: CLI and in-process answers differ, or an outcome is missing [${wr_bad_# }] (distinct answers: $wr_n_ of 6) -- see $TMPROOT/wr.*"; fi
}

# ---------------------------------------------------------------------------
# THE DRIVER
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--run-one" ]; then
  FN="${2:-}"
  declare -F "$FN" >/dev/null 2>&1 || {
    echo "FIXTURE ERROR: --run-one needs a case function name; '$FN' is not one" >&2; exit 2; }
  "$FN"
  [ "$fails" -eq 0 ] || exit 1
  exit 0
fi

echo "wait-beat-liveness: mode PUSH"

probe
clock_probe
clock_probe_ip
wiring_e2e

# THE CASE LIST IS DERIVED FROM THIS FILE'S OWN DEFINITIONS, in source order, with a
# zero guard. A hand-written list is the defect the subject itself is about: a case
# dropped from it runs nothing, prints nothing, and N-1 greens read exactly like N.
NAMES="$(grep -oE '^S[0-9]+[a-z]?_[a-z0-9_]+\(\) \{' "$0" | sed 's/() {$//')"
N_LISTED="$(printf '%s\n' "$NAMES" | grep -c . || true)"
if [ "$N_LISTED" -lt 15 ]; then
  echo "FIXTURE ERROR: derived $N_LISTED case(s) from this file — the naming grammar moved" >&2
  exit 2
fi

for n in $NAMES; do
  fx_shims_on
  "$n"
done
report_end wait-beat-liveness
