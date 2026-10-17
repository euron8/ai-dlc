#!/usr/bin/env bash
# wait-for-deliverable.sh -- Rule 29's bounded file-wait beat, as a command.
#
# WHY THIS EXISTS. Rule 29 is right that a teammate's DELIVERABLE FILE is the
# handle: `Agent` returns an `agent_id` that `TaskOutput` will not take, and a
# `Skill` spawn returns no handle at all, but both deliver by file (Rule 20).
# What Rule 29 gave the lead, though, was a shell SNIPPET to retype:
#
#     for i in $(seq 1 11); do [ -s "$f" ] && exit 0; sleep 10; done
#
# Measured on the reference consumer's S289 implementation phase: the lead
# retyped that loop 75 times, at ~170 tokens of tool-call parameter each --
# ~13k resident tokens spent re-authoring a fixed procedure. Worse, a retyped
# loop is a loop that can be typed WRONG, and Rule 29's Check C (sequence bound)
# existed only to police handwritten loops after the fact.
#
# So: one call site, and the two bounds are enforced HERE, not trusted to the
# caller.
#
#   THE CALL BOUND  -- this script never runs longer than the BEAT QUANTUM
#                      (AI_DLC_WAIT_BEAT_SECS). Every invocation is ONE beat and
#                      returns inside it, so the lead is re-invoked and can act
#                      on whatever landed.
#   THE SEQUENCE BOUND -- beats are COUNTED across calls in a sidecar. At
#                      max_wait_beats the script declares Rule 20 non-delivery.
#                      An unbounded wait is a hang, not a gag (Rule 29).
#
# THE BEAT QUANTUM IS NOT THE STEERING BUDGET. Both were once
# AI_DLC_STEERING_BUDGET, and the shared name was the bug. The steering budget
# bounds a FOREGROUND call, because the operator cannot be heard while one is in
# flight. This beat is BACKGROUNDED (v0.81.0): the lead has ended its turn, so a
# queued operator message lands on the very next turn no matter how long the beat
# sleeps. The quantum therefore buys nothing for steerability -- it only decides
# how often a still-waiting join re-invokes the lead, and every one of those
# re-invocations costs a turn. validate-steering-budget.sh already agrees: Check A
# skips run_in_background calls and isWaitBeat requires foreground, so the
# validator never bound this script to 120s in the first place.
#
# WAIT ON A WHOLE WAVE IN ONE BEAT. Pass every deliverable you are joining:
#
#     scripts/ai-dlc/wait-for-deliverable.sh docs/reviews/a.md docs/reviews/b.md ...
#
# All paths are polled inside the SAME beat, concurrently. This is the point:
# a wave of three teammates joined as three separate calls is 3 x 110s of
# serialized wall clock, and a lead told to make one call per teammate will
# instead chain them into a single Bash call -- which is the identical failure
# in a new costume. v0.50.0 shipped without this and the consumer did exactly
# that within the hour: `wait a.md; wait b.md` in one call, 2 x 110s against a
# 120s budget, harness-backgrounded at the cap, both verdicts lost to a file it
# never read. The loop goes in the beat count, never inside the call -- and
# neither does a second beat.
#
# WHY MTIME, NOT PRESENCE. Delivery is "non-empty AND written since this join
# armed" -- not merely "non-empty". A presence-only test cannot tell a teammate's
# answer from the PREVIOUS sprint's file sitting at the same path, and it reports
# the stale one as DELIVERED in under a second. That is not a stall the lead can
# notice; it is a silent wrong answer that gets consumed as this sprint's input.
# It happened: a bug-investigation join landed on a 41KB analysis from three
# sprints earlier, and the lead caught it only by reading a date line in the body.
#
# Note the asymmetry the old predicate got backwards. This script's counter logic
# below is careful about false NON-DELIVERY (it re-dispatches a live teammate --
# loud, bounded, and a retro finding). False DELIVERY is worse: nothing downstream
# ever re-examines it. So when the two cannot be told apart, we wait.
#
# The join epoch is captured HERE, at arming, not taken from the caller. A lead
# writes `dispatched-at` into the snapshot ROUNDED (observed: 23:30:00Z recorded
# for a 23:29:50 dispatch -- ten seconds into the future). A future threshold is an
# ABSORBING failure: the teammate's file is never rewritten, so every later beat
# re-reads the same mtime, the counter walks to max_wait_beats, and the script
# declares non-delivery on a complete artifact. --since may therefore only move the
# threshold EARLIER (see the clamp at join_of), never later.
#
# LIMIT -- mtime is a heuristic, not a proof. `git checkout`, a branch switch,
# `stash pop`, and a fresh clone all stamp tracked files with the current time, so
# a stale artifact can still look fresh. The structural fix is a deliverable path
# that CANNOT collide: the nonce'd and sprint-stamped paths this pipeline already
# uses elsewhere (`s<N>-...`, `<nonce>.verdict.json`) are immune by construction.
# The collision above happened on a lead-invented UNSTAMPED path. This test is the
# belt for paths that escaped that discipline.
#
# NON-DELIVERY MEANS "NO EVIDENCE OF WORK", NOT "TIME ELAPSED". The sequence bound
# below is a clock, and a clock cannot tell a slow teammate from a dead one. So the
# mechanism built to stop a lead re-dispatching a live teammate periodically causes
# exactly that. Three recurrences, and the first two fixes both only moved the
# threshold:
#
#   1. S297 -- `adversary-p1-rr` declared non-delivered at the then-20-minute
#      ceiling; a LIVE teammate was re-dispatched. Fix: ceiling 20 -> 60 minutes.
#   2. Non-sleeping siblings charged a beat without waiting, so the counter reached
#      the bound while the teammate was alive and the deliverable landed four
#      minutes later. Fix: charge a beat only when the invocation sleeps (below).
#   3. S298 -- a legitimate 62-minute dispatch, which exceeds even the raised
#      ceiling, and a second dispatch on the same trajectory. The lead pre-empted
#      the false NON-DELIVERY BY HAND, checking `git status` in the teammate's
#      worktree for changed files and re-arming instead of re-dispatching. That
#      the lead had to hand-write the liveness check is the defect.
#
# --progress-path is that hand-written check, mechanized. Point it at where the
# teammate WORKS (its worktree), and each beat asks whether any file under it was
# written since the previous beat. If so the teammate is demonstrably working, and
# an exhausted sequence is EXTENDED by one beat instead of declaring non-delivery.
# Omit the flag and behaviour is byte-for-byte what it was: strictly additive.
#
# THE EXTENSION IS BOUNDED, AND THAT IS NOT OPTIONAL. Rule 29's Check C is the
# other half of this script's contract -- an unbounded wait is a hang, not a gag --
# so "progress resets the counter" would trade a false NON-DELIVERY for a join that
# can never terminate. A teammate stuck in a loop touching a log file every ten
# minutes would hold the lead forever, and the Rule 26(c) claim that this script
# "can commit neither" failure would quietly become false. So grants are counted
# too, in their own sidecar, capped at max_wait_beats. Worst case doubles; it does
# not become infinite.
#
# WHY NOT A PROGRESS PATH THE SCRIPT PICKS ITSELF. Only the caller knows which tree
# the teammate was pointed at, and a guessed one is worse than none: a path nothing
# writes to makes the grant unreachable and the feature inert, which reads exactly
# like a feature that is working. Hence an explicit flag, and hence the hard errors
# on a path that does not exist and on the state dir (see the guards below) -- both
# are ways this check could silently never fire.
#
# SLOW AND NEVER LOOK THE SAME, WHICH IS A DIFFERENT DEFECT FROM THE ONE ABOVE.
# --progress-path answers "is the teammate working?" only when the caller can name
# the tree it works in, and only once the sequence is spent. Everywhere else this
# beat's entire output vocabulary was `WAITING ... not yet delivered` / `DELIVERED`,
# printed IDENTICALLY beat after beat. Reproduced S306: two teammates had both
# finished their real work and gone idle, having written their answers to paths this
# join was not watching. The beat reported the same non-delivery text every beat, the
# lead re-armed it twice against an unchanging false negative, and it stopped only
# because the operator asked whether the wait was still appropriate -- a manual check
# then showed both idle at once. Absent that question the join would have reported the
# same line indefinitely. The cause is general: ANY way a teammate can finish without
# satisfying the watched path -- a crash after partial delivery, a role that answers in
# text, a path typo in either direction -- produces that identical silent symptom.
#
# TWO REPAIRS, AND THEY ARE INDEPENDENT OF EACH OTHER.
#
# (1) THE LINE MUST NOT REPEAT. Every WAITING line now carries the beat number AND the
#     elapsed time since this join armed, so beat N is textually distinct from beat
#     N+1 and a --reset that restarts the clock is visible as a reset rather than as
#     more of the same. The chained-sibling WAITING line carried neither, and it was
#     the one that was byte-identical on every invocation.
#
# (2) TEAMMATE LIVENESS IS REACHABLE FROM A SHELL, AND ASSUMING OTHERWISE IS WHY THIS
#     TOOK THREE SPRINTS. This is a process, not the lead, so it cannot call the
#     agent-listing tool -- and it does not need to. The harness exports
#     CLAUDE_CODE_SESSION_ID into every Bash subprocess it starts (including a
#     backgrounded beat, and including one started from inside a teammate, where the
#     value is still the LEAD's session), and it appends one transcript per teammate
#     under
#
#         $HOME/.claude/projects/<project-slug>/<session>/subagents/*.jsonl
#
#     as that teammate takes turns. The mtime of those files IS the liveness signal.
#     It needs no flag, and it is the same KIND of evidence --progress-path already
#     uses: an mtime DELTA, never a state.
#
#     WHAT IT CAN AND CANNOT ANSWER. It cannot say which teammate owed which
#     deliverable -- nothing on disk joins a teammate name to a path, and this script
#     does not guess one, for the same reason it will not guess a progress path. What
#     it can say is a SESSION-scoped fact: whether ANY teammate has taken a turn
#     recently. That is exactly the fact the operator's question surfaced in S306,
#     where the answer was "no -- both went idle an hour ago".
#
#     THE ERROR DIRECTION IS DELIBERATE. The age is the MINIMUM across every teammate
#     in the session, so one live teammate suppresses the idle report for the whole
#     wave, and a beat invoked from inside a teammate can never call itself idle. That
#     under-reports idleness and never over-reports it; under-reporting leaves today's
#     behaviour exactly as it was.
#
#     IT CHANGES NO DECISION THIS SCRIPT MAKES -- not the exit code, not the beat
#     counter, not a progress grant. It is a status line, and here the status line IS
#     the outcome: this file's contract is that stdout carries the verdict (see WHY
#     WAITING IS NOT NONZERO), and S306 was a lead acting on output that could not
#     distinguish two states. Wiring an mtime heuristic into the exit code would be
#     re-dispatching live teammates on a guess, which is the failure the whole file
#     exists to prevent.
#
#     THE THRESHOLD IS MEASURED, NOT PICKED. Over 1,337 real teammate transcripts from
#     this pipeline and the reference consumer's -- 57,050 consecutive appends -- a
#     teammate that was ALIVE and merely running one long tool call was silent for
#     more than one beat quantum (600s) in 13 of those appends, more than 900s in 3,
#     and more than 1200s in 2: 0.0036%. Teammates that had genuinely gone idle and
#     were later re-messaged were silent past 1200s in 57 of 844 episodes. Two quanta
#     is therefore the default, and AI_DLC_TEAMMATE_IDLE_SECS retunes it.
#
#     WHEN THE SIGNAL IS ABSENT THE BEAT SAYS SO, AND THAT LINE IS NOT DECORATION.
#     Only 47 of 172 sessions in this project have a subagents directory at all -- a
#     join on a Skill spawn, on a backgrounded command, or on a teammate the harness
#     did not record has none. An absent directory must never read as "idle"; it reads
#     as "this beat cannot see liveness", which the lead needs, because a sensor that
#     is silent because all is well and one that is silent because it is broken are
#     otherwise the same output. That is this whole section's failure, one level down.
#
# USAGE
#   scripts/ai-dlc/wait-for-deliverable.sh <path> [<path>...] [--reset] [--quiet]
#                                   [--since <epoch|ISO8601>] [--dispatch <agentId|toolu_id>]
#                                   [--progress-path <dir|file>]...
#                                   [--complete | --complete-repair] [--status]
#                                   [--shard-header convergence|elicitation]
#
#   --complete         DELIVERED also needs a settled last line `seat-complete: `.
#   --complete-repair  the same, keyed on `repair-complete: serial ` -- the serial
#                      remediator's terminal line on a joined repair record.
#   --status           print DELIVERED / UNFINISHED / UNSETTLED / WAITING per path
#                      and return at once: no sleep, no beat charged, no file written.
#   --shard-header <axis>  with --complete only: a marked adversarial shard DELIVERS only
#                      if `merge-adversarial-shards.sh --check-header <path> --axis <axis>`
#                      passes; otherwise it is UNFINISHED with the merge's refusal text.
#   --dispatch <id>    the dispatch this join waits on: the `agentId` (or `agent_id`) the
#                      Agent result returned, or its toolu_ id. Its spawn-ledger `ts` is the
#                      join's --since, and a --since LATER than it is refused.
#   (Each is documented in full below the `set -u` line.)
#
# EXIT CODES
#   0  BEAT COMPLETE  the beat ran and returned. Read stdout for per-path status:
#                     `DELIVERED <path>` / `WAITING <path>`, then the BEAT COMPLETE
#                     summary line. Consume ONLY the delivered paths.
#                     `PROGRESS <path>` means an exhausted sequence was extended
#                     because work was observed -- do NOT re-dispatch, beat again.
#                     `TEAMMATE IDLE, DELIVERABLE ABSENT` means no teammate in this
#                     session has taken a turn for a long time while the join is
#                     still out: the likely cause is a DIVERGED delivery, not a slow
#                     teammate. Check the path before beating again. It is a report,
#                     not a verdict -- the exit code is unaffected.
#   1  NON-DELIVERY   a path exhausted max_wait_beats. Rule 20 non-delivery:
#                     re-dispatch ONCE (with --reset), then HARD_BLOCK.
#
# WHY WAITING IS NOT NONZERO. A join that is still waiting is the ordinary case --
# it is what nine of every ten beats report. The harness treats a nonzero exit from
# a BACKGROUNDED command as a failure and injects `<status>failed</status>` into
# the lead's context, so the old `exit 2` announced a failure roughly every two
# minutes for the entire life of every healthy join. That is not merely noise: a
# lead that reads an attempt as an outcome re-dispatches live teammates (it has
# happened), and a real non-delivery drowns in the false ones. Nonzero is now
# reserved for the one state that genuinely needs a decision. The delivered/waiting
# distinction moved to stdout, which the lead had to read anyway -- an exit code
# could never say WHICH path in a wave was still out.
#
# ENV
#   AI_DLC_WAIT_BEAT_SECS    seconds a beat may sleep       (default 600)
#   AI_DLC_WAIT_POLL_SECS    seconds between polls          (default 10)
#   AI_DLC_MAX_WAIT_BEATS    beats before non-delivery      (default 6, and it is
#                            also the cap on progress grants, so the worst-case
#                            wait is 2 x quantum x this -- still finite)
#   AI_DLC_WAIT_MARGIN_SECS  reserve held back from quantum (default 10)
#   AI_DLC_STATE_DIR         state dir; relative = under the project root   (default _bmad-output)
#   AI_DLC_PROJECT_ROOT      project root override (else walk up from this script, CLAUDE_PROJECT_DIR, cwd)
#   AI_DLC_TEAMMATE_IDLE_SECS  quiet seconds before the beat reports TEAMMATE IDLE
#                            (default 2 x the beat quantum; see the measurement above)
#   AI_DLC_TEAMMATE_DIR      override the teammate-transcript directory. Exists so
#                            the fixture can point the sensor at a tree it built --
#                            a sensor that resolves its own location cannot be
#                            probed, and one that cannot be probed cannot be shown
#                            to fire.
#
# AI_DLC_STEERING_BUDGET is deliberately NOT read here -- see "THE BEAT QUANTUM
# IS NOT THE STEERING BUDGET" above. It bounds foreground calls and belongs to
# validate-steering-budget.sh alone.
#
# The wall-clock ceiling is quantum x max_wait_beats = 60 minutes, or twice that
# when --progress-path is supplied and every grant is spent. The previous 20
# minutes was too short for what teammates actually take: S297 declared
# `adversary-p1-rr` non-delivered at the ceiling and re-dispatched a live
# teammate, and S298 ran a legitimate 62-minute dispatch -- which exceeds the
# raised ceiling too, and is why raising it again is not the fix.

set -u

# ---------------------------------------------------------------------------
# --complete: THE EARLY-WRITING SHARD. (Documented here, below the `set -u` line, which
# is where `--help` stops printing; the USAGE block above names every flag in one line.)
#
# A seat or shard brief that writes its header FIRST and appends each finding as it
# is verified makes the deliverable non-empty minutes before it is finished, so the
# plain predicate -- non-empty and written since the join armed -- would consume a
# half-written file. Under --complete (no argument):
#
#   DELIVERED additionally requires the file's LAST NON-BLANK line to begin
#   `seat-complete: `. A marker anywhere else is not completion -- the brief makes it
#   one final write, so a finding appended after it reopens the file. The beat reads the
#   marker only; the merges check its `findings=<n>` count.
#   Trailing blank lines are skipped, not read as the last line.
#
#   PROGRESS is per target and needs no --progress-path: each target carries its OWN
#   `.progress` mark beside its counter, created and re-stamped by every sleeping beat,
#   and the target PROGRESSED iff the target itself is newer than its own mark. An
#   early-writing shard's file IS its evidence of work. One growing target never
#   grants another: a static target beside a growing one still reaches NON-DELIVERY.
#   --progress-path is refused in combination, because two sources of progress for
#   one target is exactly a cross-grant.
#
#   The exhaustion advice to re-arm with --progress-path is not printed: under this
#   flag the progress signal is already on.
#
#   THE MARKER MUST ALSO HAVE SETTLED. A seat that writes its marker and then edits
#   ABOVE it -- measured on the reference consumer: one cross seat wrote its file once,
#   marker last, then made seven in-place Edits over three minutes -- ends in the marker
#   the whole time, so "marker last" alone consumed it mid-edit. DELIVERED therefore also
#   requires the file's content hash to be unchanged for the SETTLE WINDOW: a `.settle`
#   sidecar beside the counter holds `<hash> <epoch first seen>`, any change of hash
#   restarts it, and the file delivers only once `now - epoch > SETTLE` in whole seconds
#   (so at least SETTLE real seconds). A file that loses its marker drops its sidecar.
#
#   THE WINDOW IS MEASURED, NOT THE POLL INTERVAL. That seat's harness transcript records
#   one Write and seven Edits of its file, 18:10:59Z to 18:14:08Z, with gaps of 29.7, 1.7,
#   1.6, 5.1, 146.6, 2.4 and 1.4 seconds. A window of one poll (10s) delivered it between
#   the first two writes. The default, AI_DLC_WAIT_SETTLE_SECS=180, is the largest gap plus
#   margin; it is never set below 60.
#
#   WHAT IS NOT A MARKER. The last non-blank line must open with `seat-complete: `,
#   carry no carriage return (a CRLF line is not the line the brief asked for), and lie
#   OUTSIDE a fenced block: a marker inside an unclosed ``` or ~~~ fence is quoted text,
#   not the seat's final write. A fence closes only on a run of the opener's character at
#   least as long as the opener, with nothing after it -- a ```` fence is not closed by ```.
#
#   UNFINISHED IS NOT ABSENT. A target that is present, non-empty, written since the
#   join armed, and whose last non-blank line is not a marker is reported as
#     UNFINISHED <path> -- present, last non-blank line is not seat-complete:
#   beneath its WAITING line on every beat, and IN PLACE OF the `absent after N beats`
#   line when the sequence is spent (still exit 1: a decision is owed). The lead reads
#   that file before deciding; re-dispatching over it discards the seat's findings. A
#   present file that does carry its marker but never settled is reported UNSETTLED on
#   exhaustion, for the same reason: it is not absent either.
#
# Without --complete every line this script prints is byte-identical to before.
#
# --complete-repair: THE SERIAL REMEDIATOR'S JOINED RECORD. That record exists before the
# serial remediator is dispatched and is APPENDED to, so the plain predicate returns on its
# first append and on every one after it, and `seat-complete:` is not a line a repair record
# carries. This flag is --complete in every respect except the marker, which is
# `repair-complete: serial ` and ONLY that. The token is keyed per CALL, never per target and
# never as an either-token: the join that builds the record concatenates PART remediators'
# records, so a joined record can end in a part's own marker before the serial pass has
# started, and a beat that accepted any marker would consume it. A lead never joins seat files
# and a repair record in one beat, so one token per call costs nothing. The two flags are
# refused together.
#
# --status: THE SAME PREDICATE, WITHOUT THE BEAT. A progress check ("how many seats are
# done?") needs the shipped answer, not a hand-rolled last-line test that a trailing blank
# line miscounts. Each path prints exactly one line:
#   DELIVERED <path>     what a beat would consume now, or what a beat already consumed and
#                        is unchanged since (its hash is kept in `<key>.delivered`, because a
#                        delivering beat drops the join state --status otherwise reads)
#   UNFINISHED <path>    present and written since the join armed, no marker last
#   UNSETTLED <path>     marker present, settle pending -- the settle window needs a hash a
#                        BEAT recorded more than SETTLE seconds ago, and --status records none
#   WAITING   <path>     absent, empty, older than the join, or no join armed on it
# It is STRICTLY read-only: it exits before the state dir is created, before the bound check
# that can wipe every live join's counters, and before any `.since`, `.settle`, `.progress`,
# shell marker or lease is written. It reads a path's stored join epoch and never arms one;
# with neither a stored epoch nor --since there is no instant to compare a write against, so
# the path reads WAITING. --reset is refused with it, because a reset is a write.
#
# --shard-header convergence|elicitation: THE HEADER IS PART OF DELIVERY FOR AN ADVERSARIAL SHARD.
# A shard can end in `seat-complete:` and still be one the merge refuses -- measured on the
# reference consumer, 13 of 19 shards in one pass carried the marker and no `verdict:`, and the
# refusal surfaced only at the merge, after every adversary had exited. With this flag (valid only
# with --complete; refused otherwise, and under --complete-repair) a target whose last non-blank
# line is the marker is DELIVERED only if the SIBLING `merge-adversarial-shards.sh --check-header
# <path> --axis <axis>` exits 0. Header parsing is the merge's and is never re-implemented here.
# A marked target the check refuses is reported, on every beat, at exhaustion and by --status, as
#   UNFINISHED <path> -- ends in seat-complete: but the merge would refuse it: <refusal text>
# (the merge's line with its `REFUSED: ` prefix removed). It is UNFINISHED, never UNSETTLED: the
# check runs before the settle window, so a header-failing shard opens no settle record and its
# repair is not counted as a revision. Its OWN writes still grant PROGRESS while its agent fixes it.
# THE SIBLING IS RESOLVED BESIDE THIS SCRIPT, never by walking up: both layouts put the two in one
# directory (core/scripts/, scripts/ai-dlc/). A MISSING SIBLING IS REFUSED AT ARMING (exit 64,
# nothing armed), the precedent --progress-path sets for a check that would otherwise never fire.
# If it vanishes mid-join, or exits anything other than 0 or 1 (2 is the merge's bad-input exit),
# the target is REFUSED with that output as the text -- a check that could not run never acquits.
# The verdict is memoised per process on the file's content hash, so a poll re-runs the check
# only when the file changed.
# ---------------------------------------------------------------------------

BUDGET="${AI_DLC_WAIT_BEAT_SECS:-600}"
POLL="${AI_DLC_WAIT_POLL_SECS:-10}"
MAX_BEATS="${AI_DLC_MAX_WAIT_BEATS:-6}"
MARGIN="${AI_DLC_WAIT_MARGIN_SECS:-10}"
# SETTLE (default 180s) BOUNDS ONE PROPERTY: HOW LONG A MARKED FILE'S CONTENT HASH MUST STAY
# UNCHANGED BEFORE THE MARKER IS TRUSTED AS THE SEAT'S FINAL WRITE. The event it waits for
# is "the seat has finished editing", and that event CANNOT be observed: a seat that is
# thinking between two Edits and a seat that is done leave the same bytes on disk. Quiet is
# the only evidence there is, so the number is the longest inter-write gap measured in a
# real marked-then-edited seat (146.6s, see "THE WINDOW IS MEASURED" in the --complete
# header) plus margin. It is a multiple of nothing else in this file.
# WHEN HIT (the hash held for more than SETTLE): the file DELIVERS -- the lead consumes it.
# That is the harmful direction, because consuming is irreversible for the beat.
# LOAD-SENSITIVE: the gap a seat leaves between edits is its own turn latency, and a loaded
# box (or a slow local model) stretches it. A correct seat whose gap exceeds SETTLE is
# consumed mid-edit. The mitigation is after the fact only -- revised_bump / say_revised
# report that the hash changed after delivery -- it cannot un-consume the file. The
# 146.6s gap was measured on an unloaded harness; no gap was measured under load.
SETTLE="${AI_DLC_WAIT_SETTLE_SECS:-180}"
case "$SETTLE" in ''|*[!0-9]*) SETTLE=180 ;; esac

QUIET=0
RESET=0
TARGETS=""
SINCE=""
DISPATCH=""
PROGRESS_PATHS=""
COMPLETE=0
STATUS=0
COMPLETE_REPAIR=0
SEAT_FLAG=0
SHARD_AXIS=""
# The marker a --complete beat keys on. One token per call (see --complete-repair above).
MARK_TOKEN="seat-complete: "

# ---------------------------------------------------------------------------
# Platform probes, done ONCE. `stat` and `date` split BSD/GNU on exactly the two
# things this script needs, and probing per poll would re-fork them every 10s for
# the life of a 60-minute join.
# ---------------------------------------------------------------------------
if stat -f "%m" . >/dev/null 2>&1; then STAT_FLAVOR="bsd"; else STAT_FLAVOR="gnu"; fi

mtime_of() {  # epoch of $1's last write, or 0 if it cannot be read
  if [ "$STAT_FLAVOR" = "bsd" ]; then
    stat -f "%m" "$1" 2>/dev/null || echo 0
  else
    stat -c "%Y" "$1" 2>/dev/null || echo 0
  fi
}

human_age() {  # $1 = seconds -> "3d" / "4h" / "12m". Single-sourced: two callers
               # printed the same three-branch ladder and drifting them apart would
               # give one beat's lines a different clock from the next line's.
  ha_="$1"
  if   [ "$ha_" -ge 86400 ]; then printf '%sd' "$(( ha_ / 86400 ))"
  elif [ "$ha_" -ge 3600 ];  then printf '%sh' "$(( ha_ / 3600 ))"
  else                            printf '%sm' "$(( ha_ / 60 ))"
  fi
}

to_epoch() {  # accept a bare epoch or an ISO8601 stamp; empty on failure
  case "$1" in
    ''|*[!0-9]*) : ;;
    *) printf '%s' "$1"; return 0 ;;
  esac
  date -u -d "$1" +%s 2>/dev/null && return 0          # GNU
  date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$1" +%s 2>/dev/null && return 0   # BSD
  return 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --reset) RESET=1; shift ;;
    --quiet) QUIET=1; shift ;;
    --complete) COMPLETE=1; SEAT_FLAG=1; shift ;;
    --complete-repair) COMPLETE=1; COMPLETE_REPAIR=1; MARK_TOKEN="repair-complete: serial "; shift ;;
    --status) STATUS=1; shift ;;
    --shard-header)
      shift
      case "${1:-}" in
        convergence|elicitation) SHARD_AXIS="$1"; shift ;;
        *) echo "FAIL: --shard-header takes convergence or elicitation (got '${1:-}')." >&2; exit 64 ;;
      esac ;;
    --since)
      shift
      [ $# -gt 0 ] || { echo "FAIL: --since needs a value (epoch or ISO8601)." >&2; exit 64; }
      SINCE="$(to_epoch "$1")" || {
        echo "FAIL: --since value '$1' is not an epoch or an ISO8601 stamp." >&2; exit 64; }
      shift ;;
    --dispatch)
      shift
      [ $# -gt 0 ] && [ -n "$1" ] || { echo "FAIL: --dispatch needs the agentId the Agent result returned." >&2; exit 64; }
      DISPATCH="${DISPATCH}${DISPATCH:+ }$1"; shift ;;
    --progress-path)
      shift
      [ $# -gt 0 ] || { echo "FAIL: --progress-path needs a path." >&2; exit 64; }
      # A path that does not exist yields no hits forever, so the grant becomes
      # unreachable and this whole check silently never fires. Refuse it here --
      # a typo must not read as "the teammate is not working".
      [ -e "$1" ] || {
        echo "FAIL: --progress-path '$1' does not exist. A missing progress path" >&2
        echo "  can never show evidence of work, so the check would silently never" >&2
        echo "  fire. Pass the directory the teammate actually writes in." >&2
        exit 64; }
      PROGRESS_PATHS="${PROGRESS_PATHS}${PROGRESS_PATHS:+|}$1"
      shift ;;
    -h|--help) sed -n '2,/^set -u$/p' "$0" | sed '$d'; exit 0 ;;
    -*) echo "unknown arg: $1" >&2; exit 64 ;;
    *) TARGETS="${TARGETS}${TARGETS:+|}$1"; shift ;;
  esac
done

if [ -z "$TARGETS" ]; then
  echo "FAIL: pass at least one deliverable path." >&2
  echo "usage: $0 <path> [<path>...] [--reset]" >&2
  exit 64
fi

if [ "$COMPLETE" -eq 1 ] && [ -n "$PROGRESS_PATHS" ]; then
  echo "FAIL: --complete and --progress-path cannot be combined. Under --complete each" >&2
  echo "  target's own writes are its evidence of work; a shared progress path would" >&2
  echo "  let one target's work extend another's wait." >&2
  exit 64
fi

if [ "$SEAT_FLAG" -eq 1 ] && [ "$COMPLETE_REPAIR" -eq 1 ]; then
  echo "FAIL: --complete and --complete-repair cannot be combined. A repair record and a seat" >&2
  echo "  file are joined by different beats; each call keys on exactly one marker." >&2
  exit 64
fi

if [ -n "$SHARD_AXIS" ] && [ "$SEAT_FLAG" -ne 1 ]; then
  echo "FAIL: --shard-header is valid only with --complete. It checks the header of an adversarial" >&2
  echo "  shard whose last line is seat-complete:, which only a --complete join reads." >&2
  exit 64
fi

if [ "$STATUS" -eq 1 ] && [ "$RESET" -eq 1 ]; then
  echo "FAIL: --status and --reset cannot be combined. --status writes nothing; a reset is a write." >&2
  exit 64
fi

say() { [ "$QUIET" -eq 1 ] || echo "$@"; }

abs_of() {  # normalized absolute path; no realpath dependency (not on BSD by default)
  if [ -d "$1" ]; then ( cd "$1" 2>/dev/null && pwd -P ); return; fi
  d_="$(dirname "$1")"; b_="$(basename "$1")"
  ( cd "$d_" 2>/dev/null && printf '%s/%s' "$(pwd -P)" "$b_" )
}

# --- AI_DLC_ROOT ------------------------------------------------------------
# Walk UP for a marker, never count `..` hops. The canonical block, precedence bound by I75:
# override -> walk up from this script -> CLAUDE_PROJECT_DIR -> walk up from cwd -> refuse.
# Inline on purpose: locating a shared lib is the same unsolved problem. The state dir hangs off
# this root and not off the cwd, so a Bash cwd that drifted into a subdirectory still arms the
# beat where the stop hook looks for its lease.
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
WD_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WD_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$WD_ROOT" ] || WD_ROOT="$(ai_dlc_resolve_root "$WD_SCRIPT_DIR" || true)"
[ -n "$WD_ROOT" ] || WD_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$WD_ROOT" ] || WD_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$WD_ROOT" ] || {
  echo "FAIL: wait-for-deliverable: cannot resolve the project root from ${WD_SCRIPT_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). NO beat ran and the join is NOT armed. Run it from inside the" >&2
  echo "  project, or set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 64
}
# --- end AI_DLC_ROOT --------------------------------------------------------
# --shard-header's checker: the sibling beside this script (header: "--shard-header"), never a walk.
SHARD_CHECK="${WD_SCRIPT_DIR}/merge-adversarial-shards.sh"
if [ -n "$SHARD_AXIS" ] && [ ! -f "$SHARD_CHECK" ]; then
  echo "FAIL: --shard-header needs merge-adversarial-shards.sh beside this script ($SHARD_CHECK)." >&2
  echo "  Without it no shard header can be checked, so every marked shard would be refused." >&2
  echo "  NO beat ran and the join is NOT armed." >&2
  exit 64
fi
case "${AI_DLC_STATE_DIR:-}" in
  /*) STATE_DIR="$AI_DLC_STATE_DIR" ;;
  *)  STATE_DIR="${WD_ROOT}/${AI_DLC_STATE_DIR:-_bmad-output}" ;;
esac
# ONE STATE DIR FOR EVERY CWD MEANS A RELATIVE TARGET NEEDS THE CWD IN ITS KEY. Shard files are
# named `<ordinal>.md` inside each shard directory, so `1.md` armed from shards/a and `1.md` armed
# from shards/b are two deliverables; keyed on the bare string they would share one counter, one
# join epoch and one settle record, and the second join would read the first one's epoch. A
# relative target from a cwd below the root is keyed on its root-relative path, so a call from the
# root -- the ordinary case, and every counter live today -- keys exactly as before.
WD_CWD_P="$(pwd -P)"; WD_ROOT_P="$(cd "$WD_ROOT" 2>/dev/null && pwd -P)"
case "$WD_CWD_P" in
  "$WD_ROOT_P")   KEY_PFX="" ;;
  "$WD_ROOT_P"/*) KEY_PFX="${WD_CWD_P#"$WD_ROOT_P"/}/" ;;
  *)              KEY_PFX="${WD_CWD_P}/" ;;
esac

COUNTER_DIR="${STATE_DIR}/.wait-beats"
if [ "$STATUS" -eq 0 ]; then   # --status creates nothing, not even the state dir
  mkdir -p "$STATE_DIR" 2>/dev/null || true
  mkdir -p "$COUNTER_DIR" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# THE PROGRESS PATH MAY NOT BE THE STATE DIR, OR ANY ANCESTOR OF IT.
# `_bmad-output` is the obvious thing to reach for -- it is where deliverables
# live -- and it is the one path that makes this check unable to fail. THIS beat
# re-stamps `.beat-inflight` every poll and writes its own counters there, and the
# lead rewrites the snapshot and the continuation log every turn. Evidence of work
# would then be permanently true, NON-DELIVERY could never fire, and the join
# would be exactly the unbounded wait Rule 29 Check C forbids -- while printing a
# reassuring PROGRESS line each beat. Fail loudly instead, and name the fix.
# ---------------------------------------------------------------------------
if [ -n "$PROGRESS_PATHS" ]; then
  SD_ABS="$(abs_of "$STATE_DIR")"
  OLDIFS="$IFS"; IFS='|'
  for p in $PROGRESS_PATHS; do
    IFS="$OLDIFS"
    P_ABS="$(abs_of "$p")"
    if [ -n "$P_ABS" ] && [ -n "$SD_ABS" ] && \
       { [ "$P_ABS" = "$SD_ABS" ] || case "$SD_ABS" in "$P_ABS"/*) true ;; *) false ;; esac; }; then
      echo "FAIL: --progress-path '$p' is the state dir ('$STATE_DIR') or contains it." >&2
      echo "  This beat writes its own counters and .beat-inflight there, and the lead" >&2
      echo "  rewrites the snapshot every turn, so progress would ALWAYS be observed and" >&2
      echo "  NON-DELIVERY could never fire -- an unbounded wait (Rule 29, Check C)." >&2
      echo "  Point it at where the TEAMMATE works, e.g. its worktree:" >&2
      echo "    --progress-path .claude/worktrees/<teammate>" >&2
      exit 64
    fi
    IFS='|'
  done
  IFS="$OLDIFS"
fi

key_of() {  # an absolute target keys as itself; a relative one is prefixed with the cwd (KEY_PFX)
  case "$1" in /*) ko_="$1" ;; *) ko_="${KEY_PFX}$1" ;; esac
  printf '%s' "$ko_" | cksum | tr -d ' \t' | cut -c1-16
}

# ---------------------------------------------------------------------------
# THE JOIN EPOCH. Recorded per target in a `.since` sidecar beside the counter, on
# the first beat, and reused by every later beat of the same join. The counter file
# itself stays a bare integer: consumers have live counters mid-sprint and nothing
# may change how those parse.
#
# --since is a HINT, not the authority. It is clamped so it can only pull the
# threshold EARLIER -- never past `now`, and never later than a value an earlier
# beat already settled on. Earlier is the direction only the caller can know
# (a teammate that delivered before this join armed, which is the normal shape
# after a compaction). Later is the direction that produces a threshold no write
# can ever satisfy.
#
# THE EPOCH IS SETTLED ONCE PER PROCESS, AND THE SIDECAR IS NOT RE-READ AFTER THAT. Every beat
# over a path shares its `.since` (the sidecars are keyed by path, not by beat), and a beat
# that DELIVERS a path deletes it. Measured with two beats armed over one seat file before it
# was written, each from its own shell: the first to see the marker settle delivered and
# deleted `.since`; the second's next read found no sidecar, re-armed the epoch at `now` --
# after the file's last write -- and reported a sealed file WAITING for the rest of its
# quantum, 3 runs of 3. So the pre-sweep's answer is memoised in `JM_<key>` in this shell,
# and every later call in the same process returns it and writes nothing. The memo never
# re-creates a sidecar another beat deleted: a LATER beat re-armed without --since still reads
# a delivered file as pre-existing, as Rule 28 documents.
# ---------------------------------------------------------------------------
join_of() {
  t_="$1"
  jk_="$(key_of "$t_")"
  eval "jm_=\${JM_${jk_}:-}"
  if [ -n "$jm_" ]; then printf '%s' "$jm_"; return 0; fi
  f_="${COUNTER_DIR}/${jk_}.since"
  now_="$(date +%s)"
  stored_=""
  [ -f "$f_" ] && stored_="$(cat "$f_" 2>/dev/null || echo '')"
  case "$stored_" in ''|*[!0-9]*) stored_="" ;; esac

  if [ -z "$stored_" ]; then j_="$now_"; else j_="$stored_"; fi
  [ -n "$SINCE" ] && [ "$SINCE" -lt "$j_" ] && j_="$SINCE"
  [ "$j_" -gt "$now_" ] && j_="$now_"

  printf '%s' "$j_" > "$f_" 2>/dev/null || true
  printf '%s' "$j_"
}

# The delivery predicate, single-sourced. Every place that asks "is this one done?"
# MUST come through here. If the pre-sweep and the poll loop disagree, the loop
# breaks the moment it sees a stale file present, the sweep then reports WAITING,
# and the beat returns in zero seconds having CHARGED a beat and slept none --
# ten instant beats straight to a false non-delivery.
is_delivered() {  # $1 = path, $2 = join epoch
  [ -s "$1" ] || return 1
  [ "$(mtime_of "$1")" -ge "$2" ] || return 1
  [ "$COMPLETE" -eq 1 ] || return 0
  id_st_="${COUNTER_DIR}/$(key_of "$1").settle"
  if ! has_marker "$1"; then
    # A marker this beat had seen settling is gone: the seat reopened a file it had declared
    # final. That is a revision (BL-548), counted before the settle record is dropped.
    if settle_record "$id_st_" >/dev/null; then revised_bump "$id_st_"; fi
    rm -f "$id_st_" 2>/dev/null; settle_memo "$id_st_" ""
    return 1
  fi
  # --shard-header: a header the merge refuses is UNFINISHED, checked BEFORE the settle window so
  # it opens no settle record and its repair is not counted as a revision.
  if [ -n "$SHARD_AXIS" ] && header_refused "$1"; then return 1; fi
  settled "$1" "$id_st_"
}

# --complete: the LAST NON-BLANK line begins with this call's marker token (`seat-complete: `,
# or `repair-complete: serial ` under --complete-repair), carries no carriage return, and is
# not inside an unclosed fence. A whitespace-only line is blank (NF == 0), so trailing blank
# lines cannot hide the marker. The token reaches awk through the environment, never `-v`,
# which would strip a level of escaping.
has_marker() {  # $1 = path
  MT_="$MARK_TOKEN" awk '
    # A fence opens on a run of 3+ backticks or tildes; it closes only on a run of the SAME
    # character at least as long, with nothing but blanks after it.
    match($0, /^[ \t]*(```+|~~~+)/) {
      r = substr($0, RSTART, RLENGTH); sub(/^[ \t]*/, "", r)
      if (fc == "") { fc = substr(r, 1, 1); fl = length(r) }
      else if (substr(r, 1, 1) == fc && length(r) >= fl && substr($0, RSTART + RLENGTH) ~ /^[ \t\r]*$/) { fc = ""; fl = 0 }
    }
    NF { l = $0 }
    END { exit ((fc == "" && l !~ /\r/ && index(l, ENVIRON["MT_"]) == 1) ? 0 : 1) }' "$1" 2>/dev/null
}
# The token as the report lines name it: `seat-complete:` byte-identical to every earlier
# release, or `repair-complete: serial`.
MARK_NAME="${MARK_TOKEN% }"

content_hash() {  # $1 = path -> a content hash, empty when unreadable
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" 2>/dev/null | cut -d' ' -f1
  else cksum < "$1" 2>/dev/null | tr -d ' \t'; fi
}

# --shard-header: 0 when the sibling merge's --check-header REFUSES $1's header, with HC_MSG set to
# its refusal (the `REFUSED: ` prefix removed); 1 when it passes. A missing sibling, or any exit but
# 0 and 1, is a refusal (header: "--shard-header"). Memoised per process on the content hash, in
# HCH_<key> / HCM_<key>, so the poll loop re-runs the merge only when the file changed.
header_refused() {  # $1 = path
  hr_h_="$(content_hash "$1")"; hr_k_="$(key_of "$1")"
  eval "hr_mh_=\${HCH_${hr_k_}:-}"
  if [ -n "$hr_h_" ] && [ "$hr_mh_" = "$hr_h_" ]; then
    eval "HC_MSG=\${HCM_${hr_k_}:-}"
    [ -n "$HC_MSG" ]; return
  fi
  if [ ! -f "$SHARD_CHECK" ]; then
    HC_MSG="no header check ran: merge-adversarial-shards.sh is missing beside this script ($SHARD_CHECK)"
  else
    hr_o_="$(bash "$SHARD_CHECK" --check-header "$1" --axis "$SHARD_AXIS" 2>&1)"; hr_rc_=$?
    hr_o_="$(printf '%s' "$hr_o_" | tr '\n' ' ')"; hr_o_="${hr_o_% }"; hr_o_="${hr_o_#REFUSED: }"
    case "$hr_rc_" in
      0) HC_MSG="" ;;
      1) HC_MSG="${hr_o_:-the header check exited 1 and printed nothing}" ;;
      *) HC_MSG="the header check could not run (exit $hr_rc_): ${hr_o_:-no output}" ;;
    esac
  fi
  if [ -n "$hr_h_" ]; then eval "HCH_${hr_k_}=\$hr_h_; HCM_${hr_k_}=\$HC_MSG"; fi
  [ -n "$HC_MSG" ]
}

# THE SETTLE RECORD IS MEMOISED PER PROCESS for the reason the join epoch is (join_of): a
# concurrent beat over the same path deletes the shared `.settle` when it delivers or loses
# the marker, and a beat that then re-recorded from `now` would restart its own window on a
# file that never changed. The sidecar is authoritative while present; the memo stands in when
# it is absent; a record is WRITTEN only on a new observation. `settle_memo <sidecar> <rec>`
# sets it, and an empty record clears it.
settle_memo() {  # $1 = sidecar, $2 = record ('' clears)
  sm_k_="${1##*/}"; sm_k_="${sm_k_%.settle}"
  eval "SM_${sm_k_}=\$2"
}
settle_record() {  # $1 = sidecar -> prints `<hash> <epoch>`; 1 when there is none
  sr_r_=""
  [ -f "$1" ] && sr_r_="$(cat "$1" 2>/dev/null || echo '')"
  if [ -z "$sr_r_" ]; then
    sr_k_="${1##*/}"; sr_k_="${sr_k_%.settle}"
    eval "sr_r_=\${SM_${sr_k_}:-}"
  fi
  [ -n "$sr_r_" ] || return 1
  printf '%s' "$sr_r_"
}

# BL-548: how often a marked file's content changed after its marker was first seen. Kept in
# its OWN `.revised` sidecar, not as a third `.settle` field: settled() and every live
# two-field `.settle` on a consumer's disk parse `<hash> <epoch>`, and a marker loss deletes
# `.settle` -- which is itself a revision and must not take the count with it. Two concurrent
# beats over one file may each count the same change; the count can read high, never zero.
# IT SURVIVES DELIVERY: the printed line is echoed (--quiet cannot hide it) but a beat's output is
# read once and gone, so the sidecar is the record a repair brief reads, through --status. It is
# cleared by --reset, a bound
# wipe, or a beat armed with a join epoch later than its last write (a new round; see
# "ROUND-SCOPED RECORDS").
# A sidecar write whose loss costs a record, never the beat: the beat goes on, and the failure
# is said on stderr rather than folded into success.
sidecar_put() {  # $1 = file, $2 = content
  printf '%s' "$2" > "$1" 2>/dev/null || echo "WARN: wait-for-deliverable: could not write $1" >&2
}
revised_bump() {  # $1 = the .settle sidecar path; bumps its sibling .revised
  rb_f_="${1%.settle}.revised"
  rb_n_=0; [ -f "$rb_f_" ] && rb_n_="$(cat "$rb_f_" 2>/dev/null || echo 0)"
  case "$rb_n_" in ''|*[!0-9]*) rb_n_=0 ;; esac
  sidecar_put "$rb_f_" "$(( rb_n_ + 1 ))"
}
# Printed beneath a DELIVERED line, at both places a path is delivered, and only when n >= 1,
# so a seat that kept its contract prints exactly what it always did.
say_revised() {  # $1 = target, $2 = counter path (without suffix)
  sv_n_=0; [ -f "${2}.revised" ] && sv_n_="$(cat "${2}.revised" 2>/dev/null || echo 0)"
  case "$sv_n_" in ''|*[!0-9]*) sv_n_=0 ;; esac
  [ "$sv_n_" -ge 1 ] || return 0
  echo "REVISED-AFTER-MARKER ${sv_n_} $1 -- its content changed ${sv_n_} time(s) after its ${MARK_NAME} line"
  echo "  was first seen. The seat edited a file it had declared final: re-read its findings."
}

# What a beat consumed, for --status: the hash of the file at delivery, in `<key>.delivered`. It
# outlives the join state the delivery drops; --reset and a bound wipe remove it with the rest.
record_delivered() {  # $1 = target, $2 = counter path (without suffix)
  rd_h_="$(content_hash "$1")"
  if [ -n "$rd_h_" ]; then sidecar_put "${2}.delivered" "$rd_h_"; fi
}

# The marked file has SETTLED: its hash equals the one its record holds from more than SETTLE
# seconds ago (the measured window in the --complete header). Any other hash (or no record)
# re-records `<hash> <now>` and waits; a different hash under an existing record is a revision.
settled() {  # $1 = path, $2 = its .settle sidecar
  st_h_="$(content_hash "$1")"; [ -n "$st_h_" ] || return 1
  st_now_="$(date +%s)"
  st_rec_="$(settle_record "$2")" || st_rec_=""
  st_rh_="${st_rec_%% *}"
  st_t_="${st_rec_#* }"
  case "$st_t_" in ''|*[!0-9]*) st_t_="" ;; esac
  if [ "$st_rh_" = "$st_h_" ] && [ -n "$st_t_" ]; then
    # Memoise a record another beat wrote, too: measured, a beat that only ever READ its
    # sibling's record had no memo when that sibling delivered and deleted it, re-recorded from
    # `now`, and ran out its quantum (1 run of 8 under load). Another beat may also have deleted
    # the sidecar; restore it so the next beat in the join reads the window already opened.
    settle_memo "$2" "$st_rec_"
    [ -f "$2" ] || sidecar_put "$2" "$st_rec_"
    # STRICTLY greater: both stamps are whole seconds, so a difference of exactly POLL can be
    # a few milliseconds of real time across a second boundary. POLL + 1 whole seconds is at
    # least POLL real ones.
    [ $(( st_now_ - st_t_ )) -gt "$SETTLE" ] && return 0
    return 1
  fi
  [ -n "$st_rh_" ] && revised_bump "$2"
  settle_memo "$2" "$st_h_ $st_now_"
  printf '%s %s' "$st_h_" "$st_now_" > "$2" 2>/dev/null || return 1
  return 1
}

# UNFINISHED: present, non-empty, written since the join armed, and NOT closed by a marker.
is_unfinished() {  # $1 = path, $2 = join epoch
  [ "$COMPLETE" -eq 1 ] && [ -s "$1" ] && [ "$(mtime_of "$1")" -ge "$2" ] && ! has_marker "$1"
}
# --shard-header: present, written since the join armed, marked, and its header REFUSED by the merge.
is_header_unfinished() {  # $1 = path, $2 = join epoch; sets HC_MSG
  [ -n "$SHARD_AXIS" ] && [ -s "$1" ] && [ "$(mtime_of "$1")" -ge "$2" ] && has_marker "$1" && header_refused "$1"
}
say_header_unfinished() {  # $1 = path; reads HC_MSG. The one emitter of this line, at every site.
  echo "UNFINISHED $1 -- ends in ${MARK_NAME} but the merge would refuse it: $HC_MSG"
}
say_unfinished() {  # $1 = path, $2 = join epoch -- the line beneath a WAITING line
  is_unfinished "$1" "$2" && echo "UNFINISHED $1 -- present, last non-blank line is not ${MARK_NAME}"
  is_header_unfinished "$1" "$2" && say_header_unfinished "$1"
  return 0
}

# --complete's evidence of work: the target ITSELF newer than its OWN mark. `find
# -newer` rather than whole-second mtimes, for the same reason progressed_since uses
# it. A missing target or mark is no evidence.
target_progressed() {  # $1 = target, $2 = its own mark; 0 iff the target is newer
  [ -f "$1" ] && [ -f "$2" ] || return 1
  tp_hit_="$(find "$1" -newer "$2" -print 2>/dev/null)"
  [ -n "$tp_hit_" ]
}

# ---------------------------------------------------------------------------
# EVIDENCE OF WORK, as a delta and not a state. The lead's hand-written version of
# this check was `git status` in the teammate's worktree -- but "there are changed
# files" stays true forever after the first edit, including long after the teammate
# died mid-edit. What it actually recorded, and what makes it a liveness signal, was
# the CHANGE between two observations. So: a mark file per join, re-stamped once per
# sleeping beat, and the question is whether anything is newer than the mark.
#
# `-newer` and `-prune` are POSIX. `-newermt` is GNU-only and `-quit` is not on
# every BSD find, so neither appears here. Nor does a pipe to `head`: the output is
# captured whole, because a pipe that closes early turns SIGPIPE into "not found"
# and reports a present thing absent. Only files written inside the last beat can
# match, so the capture is a handful of lines however large the tree is; the
# traversal is the cost, once per quantum.
#
# The prune is not defensive decoration. A teammate worktree carries its own
# `_bmad-output/`, so a teammate that runs its own beats leaves `.wait-beats/` and
# `.beat-inflight` ticking inside the very tree we are watching -- machinery
# heartbeats, not work. The state-dir guard above cannot see those: they are not
# THIS run's state dir.
# ---------------------------------------------------------------------------
progressed_since() {  # $1 = mark file; 0 iff a tracked file is newer than it
  [ -n "$PROGRESS_PATHS" ] || return 1
  [ -f "$1" ] || return 1
  ps_ifs_="$IFS"; hit_=""
  IFS='|'
  for p_ in $PROGRESS_PATHS; do
    IFS="$ps_ifs_"
    hit_="$(find "$p_" \( -name .git -o -name .wait-beats \) -prune \
                 -o -type f ! -name '.beat-inflight' -newer "$1" -print 2>/dev/null)"
    if [ -n "$hit_" ]; then IFS="$ps_ifs_"; return 0; fi
    IFS='|'
  done
  IFS="$ps_ifs_"
  return 1
}

# ---------------------------------------------------------------------------
# THE TEAMMATE LIVENESS SENSOR. Why this signal exists, why it changes no decision,
# which direction it errs in and where its threshold came from are all in the header
# ("SLOW AND NEVER LOOK THE SAME"). This is only the implementation.
#
# IT HAS THREE ANSWERS, NOT TWO, AND COLLAPSING TWO OF THEM IS THE WHOLE HAZARD.
# "unavailable" and "quiet for zero seconds" are different facts: the first says the
# beat cannot see, the second says it looked and found a live teammate. A caller that
# read only the printed number would treat a dead sensor as a live teammate -- silent,
# and in the direction that keeps the lead waiting. So teammate_quiet_for RETURNS 1
# and prints nothing when there is no signal, and every reader branches on the return.
# ---------------------------------------------------------------------------
TEAMMATE_DIR="${AI_DLC_TEAMMATE_DIR:-}"
if [ -z "$TEAMMATE_DIR" ] && [ -n "${CLAUDE_CODE_SESSION_ID:-}" ]; then
  # THE SESSION ID IS INSIDE THE GLOB, not matched after it. Only the project slug
  # is wild, so this expands to AT MOST ONE path -- and to the literal pattern, `*`
  # and all, when this session has no teammates. teammate_quiet_for's own `[ -d ]`
  # rejects that literal, which is why there is no second existence test here: it
  # would change no outcome in any state, and a condition that changes no outcome is
  # one nobody can ever prove works. It was written that way first, and the mutant
  # built to kill it came back green.
  for td_ in "${HOME:-/nonexistent}"/.claude/projects/*/"${CLAUDE_CODE_SESSION_ID}"/subagents; do
    TEAMMATE_DIR="$td_"; break
  done
fi
# IDLE_SECS (default 2 x BUDGET = 1200s) BOUNDS ONE PROPERTY: HOW LONG A SESSION'S NEWEST
# TEAMMATE TRANSCRIPT MAY GO UNWRITTEN BEFORE THE BEAT SAYS "THIS LOOKS DIVERGED, NOT SLOW".
# The event it waits for is a teammate's next turn. That event IS observable directly -- it
# is the mtime of the newest `*.jsonl` under TEAMMATE_DIR (teammate_quiet_for) -- but what it
# MEANS is not: a live teammate inside one long tool call and a teammate that finished and
# wrote elsewhere are both silent, and no file distinguishes them. So the number cannot be
# derived from the event; it is a measured separation point (see "THE THRESHOLD IS MEASURED"
# in the header: 0.0036% of live appends exceed 1200s against 57 of 844 genuinely idle
# episodes), and it is a multiple of BUDGET so that a retune of the quantum moves it too.
# WHEN HIT: say_liveness prints TEAMMATE IDLE, DELIVERABLE ABSENT. That is a report; it
# changes no exit code, no beat count and no grant, so hitting it cannot deny, consume or
# re-dispatch anything. LOAD: the outcome (one extra line) does not depend on load, but the
# measurement does -- a loaded box stretches a live teammate's single tool call, so the
# false-IDLE rate measured on an unloaded corpus is a floor under load. The line is advice
# to read the path before beating again, which is harmless when wrong.
IDLE_SECS="${AI_DLC_TEAMMATE_IDLE_SECS:-$(( BUDGET * 2 ))}"
case "$IDLE_SECS" in ''|*[!0-9]*) IDLE_SECS=$(( BUDGET * 2 )) ;; esac

# ---------------------------------------------------------------------------
# --dispatch: THE JOIN'S EPOCH IS THE DISPATCH, READ FROM THE RECORD THE DISPATCH WROTE.
# A hand-typed --since LATER than the dispatch hides every write the teammate made in
# between, and the beat reads a delivered file WAITING. Measured on the reference
# consumer: a serial remediator dispatched 05:00:03Z was armed with `--since 05:00:30Z`
# and re-armed with `--since 05:01:30Z`; the clamp to `now` does not help, because the
# early write is already in the past. The BACKDATED arm cannot see this either: it judges
# the snapshot row against the ledger and never reads a beat's argv.
#
# The id is what the lead HOLDS at arm time, never what arrives later. The Agent result
# shows `agentId: <hex>` for a spawn and `agent_id: <name>@<team>` for a named teammate;
# the toolu_ id first reaches the lead in the task-notification, when the agent ENDS.
#   toolu_<...>      the ledger row whose `tool_use_id` is it
#   <name>@<team>    a named teammate: the ONE ledger row whose `name` is <name>. Its
#                    meta.json carries no toolUseId, so the name is the only key.
#   <hex agentId>    this session's `agent-<id>.meta.json` gives `toolUseId`, which is the
#                    ledger `tool_use_id` (ai-dlc-dispatch-guard.sh, measured 4 of 4)
# Each step that finds nothing, or more than one row, REFUSES: a guessed dispatch time is
# the defect this exists to remove. Keyed on the dispatch's own id because a deliverable
# path is not one: the reference ledger records a path on 14 of 5153 rows, none current.
# --dispatch REPEATS for a beat that joins several dispatches (a fan-out round): --since is
# checked against the EARLIEST, and without --since the join starts there.
# A --since without --dispatch still runs, with a WARN on stderr; refusing it would break
# every caller written before the flag.
# ---------------------------------------------------------------------------
SPAWN_LEDGER="${STATE_DIR}/spawn-ledger.jsonl"
dispatch_refuse() {  # $1 = what failed, $2 = the remedy; uses $dp_id_
  echo "FAIL: --dispatch '$dp_id_': $1" >&2
  echo "  No dispatch time is guessed. $2" >&2
  exit 64
}
ledger_rows() {  # $1 = field, $2 = value -> the matching ledger lines (compact JSON, one per line)
  grep -F "\"$1\":\"$2\"" "$SPAWN_LEDGER" 2>/dev/null
}
dispatch_epoch_of() {  # $1 = agentId, <name>@<team> or toolu_ id -> sets dp_ts_, dp_tui_, dp_e_; refuses
  dp_id_="$1"
  [ -r "$SPAWN_LEDGER" ] || dispatch_refuse "no spawn ledger at $SPAWN_LEDGER" \
    "Arm from the project root, where the dispatch guard writes it."
  case "$dp_id_" in *[!A-Za-z0-9_@.-]*) dispatch_refuse "not an agentId or a toolu_ id" \
    "Pass the agentId the Agent result returned." ;; esac
  case "$dp_id_" in
    toolu_*) dp_tui_="$dp_id_" ;;
    *@*)
      dp_n_="${dp_id_%%@*}"
      dp_rows_="$(ledger_rows name "$dp_n_")"
      dp_c_="$(printf '%s' "$dp_rows_" | grep -c .)" || dp_c_=0
      [ "$dp_c_" -eq 1 ] || dispatch_refuse "the ledger holds $dp_c_ dispatch(es) named '$dp_n_', not one" \
        "No dispatch time is available for this named teammate: arm without --since."
      dp_tui_="$(printf '%s' "$dp_rows_" | sed -n 's/.*"tool_use_id":"\([A-Za-z0-9_]*\)".*/\1/p')"
      [ -n "$dp_tui_" ] || dispatch_refuse "its ledger row carries no tool_use_id" \
        "No dispatch time is available for this named teammate: arm without --since." ;;
    *)
      dp_m_=""
      [ -n "$TEAMMATE_DIR" ] && [ -f "$TEAMMATE_DIR/agent-${dp_id_}.meta.json" ] \
        && dp_m_="$TEAMMATE_DIR/agent-${dp_id_}.meta.json"
      [ -n "$dp_m_" ] || dispatch_refuse "no agent-${dp_id_}.meta.json in this session's subagents dir (${TEAMMATE_DIR:-unresolved: CLAUDE_CODE_SESSION_ID is unset})" \
        "Pass the agentId from this session's own Agent result."
      dp_tui_="$(sed -n 's/.*"toolUseId":"\([A-Za-z0-9_]*\)".*/\1/p' "$dp_m_" 2>/dev/null)"
      [ -n "$dp_tui_" ] || dispatch_refuse "its meta.json carries no toolUseId (a named teammate)" \
        "Pass the agent_id the Agent result returned, <name>@<team>." ;;
  esac
  dp_rows_="$(ledger_rows tool_use_id "$dp_tui_")"
  dp_c_="$(printf '%s' "$dp_rows_" | grep -c .)" || dp_c_=0
  [ "$dp_c_" -eq 1 ] || dispatch_refuse "the ledger holds $dp_c_ row(s) for tool_use_id $dp_tui_, not one" \
    "The dispatch guard writes one row per dispatch; a re-sent spawn is a new agentId."
  dp_ts_="$(printf '%s' "$dp_rows_" | sed -n 's/.*"ts":"\([^"]*\)".*/\1/p')"
  dp_e_="$(to_epoch "$dp_ts_")" || dp_e_=""
  [ -n "$dp_e_" ] || dispatch_refuse "its ledger row has no readable ts ('$dp_ts_')" \
    "Arm without --since."
}
if [ -n "$DISPATCH" ]; then
  DISPATCH_EPOCH=""; DISPATCH_TS=""; DISPATCH_TUI=""
  set -f   # an id is validated inside the loop, after this split: no glob may expand first
  for dp_one_ in $DISPATCH; do
    dispatch_epoch_of "$dp_one_"
    if [ -z "$DISPATCH_EPOCH" ] || [ "$dp_e_" -lt "$DISPATCH_EPOCH" ]; then
      DISPATCH_EPOCH="$dp_e_"; DISPATCH_TS="$dp_ts_"; DISPATCH_TUI="$dp_tui_"
    fi
  done
  if [ -n "$SINCE" ] && [ "$SINCE" -gt "$DISPATCH_EPOCH" ]; then
    echo "FAIL: --since is $(( SINCE - DISPATCH_EPOCH )) s after the earliest dispatch it joins ($DISPATCH_TS, tool_use_id $DISPATCH_TUI)." >&2
    echo "  Every write the teammate made in between would read as pre-existing. Drop --since;" >&2
    echo "  --dispatch alone sets the join to the dispatch." >&2
    exit 64
  fi
  [ -n "$SINCE" ] || SINCE="$DISPATCH_EPOCH"
elif [ -n "$SINCE" ]; then
  echo "WARN: wait-for-deliverable: --since without --dispatch -- nothing checks the stamp against the dispatch, and a stamp later than it misses the teammate's early writes. Pass --dispatch <agentId from the Agent result>." >&2
fi

teammate_quiet_for() {  # prints seconds since the most recent teammate turn in this
                        # session; returns 1 and prints nothing when there is no signal
  [ -n "$TEAMMATE_DIR" ] && [ -d "$TEAMMATE_DIR" ] || return 1
  tq_now_="$(date +%s)"; tq_best_=""
  for tq_f_ in "$TEAMMATE_DIR"/*.jsonl; do
    [ -f "$tq_f_" ] || continue
    tq_m_="$(mtime_of "$tq_f_")"
    [ "$tq_m_" -gt 0 ] || continue
    tq_a_=$(( tq_now_ - tq_m_ ))
    [ "$tq_a_" -lt 0 ] && tq_a_=0   # clock skew must not manufacture a future turn
    if [ -z "$tq_best_" ] || [ "$tq_a_" -lt "$tq_best_" ]; then tq_best_="$tq_a_"; fi
  done
  [ -n "$tq_best_" ] || return 1
  printf '%s' "$tq_best_"
}

# ONE function, called from all THREE places a beat can end -- the exhaustion path,
# the chained-sibling path and the post-sleep report. A lead that reads only one of
# them has to get the same three-way answer, and three copies of this ladder would
# be three chances for one of them to stop agreeing.
say_liveness() {
  if ! sl_q_="$(teammate_quiet_for)"; then
    say "LIVENESS  unavailable (no teammate transcripts for this session) -- this beat"
    say "  cannot tell a working teammate from one that finished and delivered elsewhere."
    return 0
  fi
  if [ "$sl_q_" -ge "$IDLE_SECS" ]; then
    # echo, not say: this is the line that tells the lead the wait itself is the
    # wrong action, and --quiet must not be able to hide it -- the same reason the
    # PROGRESS and NON-DELIVERY lines below are echoed.
    echo "TEAMMATE IDLE, DELIVERABLE ABSENT -- no teammate in this session has taken a"
    echo "  turn for $(human_age "$sl_q_"), and the path(s) above are still absent. A teammate that"
    echo "  finished and wrote its answer to a path this join is NOT watching looks exactly"
    echo "  like one still working, and beating again cannot resolve a diverged path."
    echo "  Check that what you are joining is the path the teammate was told to write,"
    echo "  and read the teammate's own last message before you beat or re-dispatch."
  else
    say "LIVENESS  a teammate in this session took a turn $(human_age "$sl_q_") ago."
  fi
}

# ---------------------------------------------------------------------------
# --status: the read-only answer (header: "--status"). Everything above this line reads; this
# block exits before anything below it writes. The verdict functions are the beat's own --
# has_marker through status_marked, the same mtime and join-epoch comparison -- so a progress
# check cannot disagree with the beat that will later consume the file.
# ---------------------------------------------------------------------------
status_marked() { has_marker "$1"; }
status_join() {  # $1 = target -> the stored join epoch (clamped as join_of does); 1 if none
  sj_f_="${COUNTER_DIR}/$(key_of "$1").since"; sj_s_=""
  [ -f "$sj_f_" ] && sj_s_="$(cat "$sj_f_" 2>/dev/null || echo '')"
  case "$sj_s_" in ''|*[!0-9]*) sj_s_="" ;; esac
  [ -n "$SINCE" ] && { [ -z "$sj_s_" ] || [ "$SINCE" -lt "$sj_s_" ]; } && sj_s_="$SINCE"
  [ -n "$sj_s_" ] || return 1
  sj_now_="$(date +%s)"; [ "$sj_s_" -gt "$sj_now_" ] && sj_s_="$sj_now_"
  printf '%s' "$sj_s_"
}
if [ "$STATUS" -eq 1 ]; then
  S_DONE=0; S_OUT=0
  OLDIFS="$IFS"; IFS='|'
  for t in $TARGETS; do
    IFS="$OLDIFS"
    case "$t" in
      *[![:space:]]*) : ;;
      *) echo "FAIL: empty/blank deliverable path in target list." >&2; exit 64 ;;
    esac
    S_V="WAITING"
    # A beat that DELIVERED a path drops its join state, so without this record --status would
    # call every consumed seat unarmed -- the undercount it exists to prevent. The record holds the
    # hash the beat consumed; a file changed since is judged afresh below.
    # A record older than a known join epoch is an earlier round's consumption of a reused path,
    # not this round's (the beat also clears one when it arms -- see "ROUND-SCOPED RECORDS").
    sd_c="${COUNTER_DIR}/$(key_of "$t")"
    sd_rec="$(cat "${sd_c}.delivered" 2>/dev/null || echo '')"
    if [ -n "$sd_rec" ] && sj_e="$(status_join "$t")" && [ "$(mtime_of "${sd_c}.delivered")" -lt "$sj_e" ]; then sd_rec=""; fi
    if [ -n "$sd_rec" ] && [ -s "$t" ] && [ "$sd_rec" = "$(content_hash "$t")" ]; then
      S_V="DELIVERED"; echo "DELIVERED $t -- consumed by a beat, unchanged since"
    elif ! sj="$(status_join "$t")"; then
      echo "WAITING   $t -- no join armed on this path (no stored epoch and no --since)"
    elif [ ! -s "$t" ]; then
      echo "WAITING   $t -- absent or empty"
    elif [ "$(mtime_of "$t")" -lt "$sj" ]; then
      echo "WAITING   $t -- last written before this join armed"
    elif [ "$COMPLETE" -eq 0 ]; then
      S_V="DELIVERED"; echo "DELIVERED $t"
    elif ! status_marked "$t"; then
      S_V="UNFINISHED"; echo "UNFINISHED $t -- present, last non-blank line is not ${MARK_NAME}"
    elif [ -n "$SHARD_AXIS" ] && header_refused "$t"; then
      S_V="UNFINISHED"; say_header_unfinished "$t"
    else
      ss_rec="$(cat "${COUNTER_DIR}/$(key_of "$t").settle" 2>/dev/null || echo '')"
      ss_t="${ss_rec#* }"; case "$ss_t" in ''|*[!0-9]*) ss_t="" ;; esac
      if [ -n "$ss_t" ] && [ "${ss_rec%% *}" = "$(content_hash "$t")" ] \
         && [ $(( $(date +%s) - ss_t )) -gt "$SETTLE" ]; then
        S_V="DELIVERED"; echo "DELIVERED $t"
      else
        S_V="UNSETTLED"
        echo "UNSETTLED $t -- marker present, settle pending (a beat must see its content unchanged for ${SETTLE}s)"
      fi
    fi
    # The revision count, so a repair brief reads it here and never computes a sidecar key by
    # hand. Withheld when it predates a known join epoch: that count belongs to an earlier round.
    if ! { sr_e="$(status_join "$t")" && [ "$(mtime_of "${sd_c}.revised")" -lt "$sr_e" ]; }; then
      say_revised "$t" "$sd_c"
    fi
    if [ "$S_V" = "DELIVERED" ]; then S_DONE=$(( S_DONE + 1 )); else S_OUT=$(( S_OUT + 1 )); fi
    IFS='|'
  done
  IFS="$OLDIFS"
  echo "STATUS -- ${S_DONE} delivered, ${S_OUT} not. Nothing slept, nothing was written, no beat was charged."
  exit 0
fi

# ---------------------------------------------------------------------------
# THE BEAT-LIVENESS LEASE, AND WHO MAY REMOVE IT.
#
# `.beat-inflight` is the ONE marker Stop-hook Check 2b reads, and every beat in a project
# shares it. Until this release each beat wrote a bare epoch and its EXIT trap deleted the file
# unconditionally, so the first beat to exit took the lease from every other beat still asleep.
# Measured, two beats from two shells: B delivered and exited, A stayed alive, and the marker was
# ABSENT, 3 runs of 3 -- the Stop hook then reports "no live wait-beat" with one sleeping.
#
# So the marker is `<epoch> <pid>` and has ONE holder. Every live beat also registers its own
# `.wait-beats/.lease-<pid>` (its epoch), re-stamped every poll. A beat takes the marker only
# when it is absent, unparseable, expired, or names a holder that is dead -- no registration,
# an expired one, or a pid `kill -0` cannot signal; the registration is what makes a recycled
# pid read dead. On exit a beat removes the marker only if it holds it, and first hands it to
# any other live registered beat. A pid-less live marker is a beat from before this release,
# mid-pull: it is left alone, because that beat re-stamps it and deletes it on its own exit,
# after which the next poll here re-takes it.
#
# THE WINDOW THAT REMAINS. A SIGKILLed holder skips its trap, so a live sibling takes the
# marker when the dead holder's registration expires, up to one lease length (3 x POLL) -- the
# same window a single SIGKILLed beat leaves today, worth at most one Rule 3 block.
#
# WRITTEN BEFORE THE PRE-SLEEP WORK, not after it. The bound check, the shell-marker prune and
# the sweep run first and can take seconds over a large wave; a lease written only at the sleep
# left that window uncovered, which is the "armed seconds ago, hook saw no beat" the s319 lead
# reported. A call that turns out not to sleep releases what it took, through the same trap.
# ---------------------------------------------------------------------------
BEAT_MARKER="${STATE_DIR}/.beat-inflight"
LEASE_SELF="${COUNTER_DIR}/.lease-$$"
lease_holder_dead() {  # $1 = holder pid -> 0 when no live beat stands behind it
  ld_r_="$(cat "${COUNTER_DIR}/.lease-$1" 2>/dev/null || echo '')"
  case "$ld_r_" in ''|*[!0-9]*) return 0 ;; esac
  [ "$ld_r_" -gt "$(date +%s)" ] || return 0
  kill -0 "$1" 2>/dev/null && return 1
  return 0
}
LEASE_TMP="${COUNTER_DIR}/.beat-inflight.$$"   # inside the ignored .wait-beats/, same filesystem
lease_put() {  # $1 = epoch, $2 = pid -- whole-file replace, never a partial line for the hook to read
  { printf '%s %s' "$1" "$2" > "$LEASE_TMP" 2>/dev/null && mv -f "$LEASE_TMP" "$BEAT_MARKER" 2>/dev/null; } \
    || echo "WARN: wait-for-deliverable: could not write the lease $BEAT_MARKER; the stop hook will not see this beat" >&2
}
beat_alive() {
  ba_e_=$(( $(date +%s) + 3 * POLL ))
  sidecar_put "$LEASE_SELF" "$ba_e_"
  ba_cur_="$(cat "$BEAT_MARKER" 2>/dev/null || echo '')"
  ba_ep_="${ba_cur_%% *}"
  case "$ba_cur_" in *' '*) ba_pid_="${ba_cur_#* }" ;; *) ba_pid_="" ;; esac
  case "$ba_ep_" in ''|*[!0-9]*) lease_put "$ba_e_" "$$"; return 0 ;; esac
  case "$ba_pid_" in *[!0-9]*) lease_put "$ba_e_" "$$"; return 0 ;; esac
  if [ "$ba_ep_" -le "$(date +%s)" ]; then lease_put "$ba_e_" "$$"; return 0; fi
  [ -n "$ba_pid_" ] || return 0                     # a live pre-upgrade lease: not ours to take
  if [ "$ba_pid_" = "$$" ] || lease_holder_dead "$ba_pid_"; then lease_put "$ba_e_" "$$"; fi
  return 0
}
lease_release() {
  lr_cur_="$(cat "$BEAT_MARKER" 2>/dev/null || echo '')"
  case "$lr_cur_" in *' '*) lr_pid_="${lr_cur_#* }" ;; *) lr_pid_="" ;; esac
  if [ "$lr_pid_" = "$$" ]; then
    lr_now_="$(date +%s)"; lr_heir_=""
    for lr_f_ in "$COUNTER_DIR"/.lease-*; do
      [ -f "$lr_f_" ] || continue
      lr_p_="${lr_f_##*/.lease-}"
      [ "$lr_p_" = "$$" ] && continue
      lr_e_="$(cat "$lr_f_" 2>/dev/null || echo '')"
      case "$lr_p_$lr_e_" in *[!0-9]*|'') rm -f "$lr_f_" 2>/dev/null; continue ;; esac
      if [ "$lr_e_" -gt "$lr_now_" ] && kill -0 "$lr_p_" 2>/dev/null; then lr_heir_="$lr_e_ $lr_p_"; break; fi
      rm -f "$lr_f_" 2>/dev/null
    done
    if [ -n "$lr_heir_" ]; then lease_put "${lr_heir_%% *}" "${lr_heir_#* }"
    else rm -f "$BEAT_MARKER" 2>/dev/null; fi
  fi
  rm -f "$LEASE_SELF" "$LEASE_TMP" 2>/dev/null || true
}
trap 'lease_release' EXIT
beat_alive

# ---------------------------------------------------------------------------
# COUNTERS ARE SCOPED TO THE BOUND THEY WERE COUNTED AGAINST.
# The counters survive a pull, and a live join carrying a count of 7 against an
# old bound of 10 would exhaust on its FIRST beat under a new bound of 6 -- a
# false NON-DELIVERY that re-dispatches a live teammate, which is the exact
# failure this whole script exists to prevent. So record the active bound and
# wipe the counters once whenever it changes. Self-heals for this retune and any
# future one; the `.since` sidecars go with them, which is correct, because a
# re-armed join must re-capture its epoch anyway. The `.lease-<pid>` registrations
# are kept: they belong to beats asleep right now, not to the bound.
BOUND_FILE="${COUNTER_DIR}/.bound"
PREV_BOUND="$(cat "$BOUND_FILE" 2>/dev/null || echo '')"
if [ "$PREV_BOUND" != "$MAX_BEATS" ]; then
  find "$COUNTER_DIR" -mindepth 1 -maxdepth 1 ! -name '.lease-*' -exec rm -rf {} + 2>/dev/null || true
  mkdir -p "$COUNTER_DIR" 2>/dev/null || true
  sidecar_put "$BOUND_FILE" "$MAX_BEATS"
fi

# ---------------------------------------------------------------------------
# CHAINED-BEAT GUARD. Two invocations chained in one Bash call (`wait a; wait b`)
# share a parent shell, so they share $PPID. The first consumes the call's whole
# quantum; the second then serializes a second one behind it, so the wave waits
# 2x as long as it needed to for no gain -- the wave should have gone to ONE call
# and polled concurrently. If a sibling beat ran in this same shell moments ago,
# we do a single instantaneous check and return: we never sleep twice inside one
# Bash call.
# ---------------------------------------------------------------------------
# Prune stale shell markers before trusting one. They are keyed by PID, and PIDs
# recycle -- a marker left by a long-dead shell whose PID is reissued to ours
# would suppress a legitimate beat. Anything older than the budget cannot be a
# sibling of THIS call by definition, so it is safe to drop, and this also stops
# the markers accumulating forever.
find "$COUNTER_DIR" -maxdepth 1 -name '.shell-*' -mmin +"$(( (BUDGET / 60) + 1 ))" -delete 2>/dev/null || true

# THE `-lt "$BUDGET"` TEST BELOW BOUNDS ONE PROPERTY: "A SIBLING BEAT IN THIS SHELL STARTED
# LESS THAN ONE QUANTUM AGO, SO IT HAS NOT YET HAD TIME TO FINISH SLEEPING -- WHICH MEANS
# THIS CALL IS CHAINED BEHIND IT". The event it infers is a chained invocation, and that is
# not observable directly: $PPID is shared, but a prior call from the same long-lived shell
# looks identical once enough time has passed. The marker is stamped BEFORE the sleep
# (the printf below), and a sleeping beat runs to start + BUDGET - RESERVE with RESERVE
# >= MARGIN (10s), so a genuinely chained second beat arrives at about BUDGET - RESERVE: 10s
# inside the window. BUDGET is therefore the natural bound, not a tuned one.
# WHEN HIT (age < BUDGET): MAY_SLEEP=0, the beat does one instantaneous check, charges no
# beat and returns. WHEN NOT HIT: the beat sleeps a full quantum.
# LOAD-SENSITIVE (a NOTE-tier cost, no wrong delivery): the 10s of slack is all that separates
# the two, so a loaded box that delays the chained call's start by more than RESERVE
# makes age >= BUDGET, the guard fails OPEN, and the call serializes a second full quantum
# behind the first -- the 2 x BUDGET wait this guard exists to prevent. The cost is wall
# clock and one beat charged, never a false DELIVERED or NON-DELIVERY on its own.
SIBLING="${COUNTER_DIR}/.shell-${PPID}"
MAY_SLEEP=1
if [ -f "$SIBLING" ]; then
  LAST="$(cat "$SIBLING" 2>/dev/null || echo 0)"
  case "$LAST" in ''|*[!0-9]*) LAST=0 ;; esac
  if [ $(( $(date +%s) - LAST )) -lt "$BUDGET" ]; then
    MAY_SLEEP=0
  fi
fi
printf '%s' "$(date +%s)" > "$SIBLING" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Reset / already-delivered sweep, and the sequence bound. Done for every path
# BEFORE any sleeping: an exhausted sequence must not buy one more blind window.
# ---------------------------------------------------------------------------
PENDING=""
EXHAUSTED=""
PREEXISTING=""
GRANTED=""
GRANTSPENT=""
OLDIFS="$IFS"; IFS='|'
for t in $TARGETS; do
  # A blank target is a malformed wait -- an empty In-Flight Teammates row cell,
  # or a lead that built the path from an unset variable. The old code silently
  # `continue`d past it, so a wave of nothing-but-blank paths fell straight
  # through to the `[ -z "$PENDING" ] && exit 0` below and reported DELIVERED: a
  # false join on a teammate that never ran. Fail loud and immediately instead.
  case "$t" in
    *[![:space:]]*) : ;;   # contains a non-whitespace char -- a real path
    *) echo "FAIL: empty/blank deliverable path in target list." >&2; exit 64 ;;
  esac
  c="${COUNTER_DIR}/$(key_of "$t")"
  s="${c}.since"
  pg="${c}.progress"
  gr="${c}.grants"
  [ "$RESET" -eq 1 ] && rm -f "$c" "$s" "$pg" "$gr" "${c}.settle" "${c}.revised" "${c}.delivered" 2>/dev/null

  # Whether THIS beat armed the join must be read before join_of, which creates
  # the sidecar as a side effect.
  FIRST=0; [ -f "$s" ] || FIRST=1
  j="$(join_of "$t")"
  # join_of ran in a subshell; memoise its answer HERE so every later call in this process
  # returns it instead of re-reading a sidecar another beat may delete (see join_of).
  eval "JM_$(key_of "$t")=\$j"

  # ROUND-SCOPED RECORDS. `.revised` and `.delivered` survive delivery on purpose (a repair brief
  # and --status read them), so a path REUSED by a later round would inherit the earlier round's
  # count and consumption. Rounds re-arm with `--since <round epoch>`, never --reset, so the join
  # epoch is the round boundary: a record last written before it belongs to an earlier round and
  # is dropped here, by the one writer, instead of adding a --reset duty to every step file.
  for rr_ in "${c}.revised" "${c}.delivered"; do
    [ -f "$rr_" ] && [ "$(mtime_of "$rr_")" -lt "$j" ] && rm -f "$rr_" 2>/dev/null
  done

  if is_delivered "$t" "$j"; then
    say "DELIVERED $t"
    say_revised "$t" "$c"
    record_delivered "$t" "$c"
    rm -f "$c" "$s" "$pg" "$gr" "${c}.settle" 2>/dev/null || true
    continue
  fi

  # Non-empty, but not newer than the arming instant: the ambiguous case. Name it
  # on the one beat that decides it, so the lead learns the flag while it is still
  # actionable -- not at minute twenty via a non-delivery it cannot explain.
  # Only a file OLDER than the arming instant: under --complete a post-arm file can be
  # undelivered (unmarked or unsettled), and it did not "already have content". Without the
  # flag an undelivered non-empty file is always older, so this clause changes nothing there.
  [ "$FIRST" -eq 1 ] && [ -s "$t" ] && [ "$(mtime_of "$t")" -lt "$j" ] && PREEXISTING="${PREEXISTING}${PREEXISTING:+|}$t"

  b=0; [ -f "$c" ] && b="$(cat "$c" 2>/dev/null || echo 0)"
  case "$b" in ''|*[!0-9]*) b=0 ;; esac

  # Sample evidence of work, then re-stamp the mark, so the next beat asks about
  # the window that is about to start.
  #
  # THE READ AND THE RE-STAMP NEED DIFFERENT GATES, AND SHARING ONE WAS A FALSE
  # NON-DELIVERY. The hazard the MAY_SLEEP gate exists for is real but belongs to the
  # RE-STAMP alone: a non-sleeping sibling that re-stamped would shrink the observation
  # window to nothing and report a working teammate as idle. Sampling is a pure READ --
  # `progressed_since()` only compares mtimes -- so gating it bought nothing and cost
  # the opposite error. With both gated, a chained sibling (MAY_SLEEP=0, set at :400)
  # arrives at the exhaustion arm below with PROGRESSED forced to 0. That arm is NOT
  # gated on MAY_SLEEP, so it denies the work-in-progress grant and reports EXHAUSTED --
  # non-delivery, which Rule 20 turns into a re-dispatch -- for a teammate whose files
  # are demonstrably being written. The sole variable was whether a sibling beat had
  # already run in the same shell.
  #
  # So: sample ALWAYS, re-stamp only when this invocation may sleep. A non-sleeping
  # sibling now reads the window its sleeping predecessor opened and leaves it open for
  # the next one, which is the behaviour the window was for.
  PROGRESSED=0
  # --complete: the same gates as the block below -- sample always, re-stamp only when
  # this beat may sleep -- but the evidence is this target's own file against this
  # target's own mark. The two blocks are exclusive: the flags are refused together.
  if [ "$COMPLETE" -eq 1 ]; then
    target_progressed "$t" "$pg" && PROGRESSED=1
    if [ "$MAY_SLEEP" -eq 1 ]; then
      : > "$pg" 2>/dev/null || echo "NOTE: could not re-stamp $pg -- $t's next beat reads its growth against the previous mark" >&2
    fi
  fi
  if [ -n "$PROGRESS_PATHS" ]; then
    progressed_since "$pg" && PROGRESSED=1
    if [ "$MAY_SLEEP" -eq 1 ]; then
      : > "$pg" 2>/dev/null || true
    fi
  fi

  if [ "$b" -ge "$MAX_BEATS" ]; then
    # The sequence is spent. Before calling it non-delivery -- which Rule 20 turns
    # into a re-dispatch -- ask whether the teammate is demonstrably working. A
    # grant buys exactly ONE more beat and is itself counted, so this can extend
    # the wait but can never remove its end.
    g=0; [ -f "$gr" ] && g="$(cat "$gr" 2>/dev/null || echo 0)"
    case "$g" in ''|*[!0-9]*) g=0 ;; esac

    if [ "$PROGRESSED" -eq 1 ] && [ "$g" -lt "$MAX_BEATS" ]; then
      g=$(( g + 1 ))
      printf '%s' "$g" > "$gr" 2>/dev/null || true
      printf '%s' "$(( MAX_BEATS - 1 ))" > "$c" 2>/dev/null || true
      GRANTED="${GRANTED}${GRANTED:+|}${g}/${MAX_BEATS} $t"
      PENDING="${PENDING}${PENDING:+|}$t"
      continue
    fi

    [ "$PROGRESSED" -eq 1 ] && GRANTSPENT="${GRANTSPENT}${GRANTSPENT:+|}$t"
    EXHAUSTED="${EXHAUSTED}${EXHAUSTED:+|}$t"
    continue
  fi

  # The counter is bumped ONLY if this invocation actually sleeps -- see below.
  # The sequence bound caps WAITING TIME (max_wait_beats x the beat quantum); a
  # beat that did not wait is not a beat, and charging one for it burns the
  # budget without buying any wait. That is not academic: the reference consumer
  # wrapped beats in `for i in 3 4 5; do wait-for-deliverable.sh ...; done`, so
  # two of every three invocations were non-sleeping siblings -- and each still
  # took a beat. The counter hit the bound while the teammate was alive, the
  # script declared NON-DELIVERY, and Rule 20 tells the lead to re-dispatch on
  # that. The deliverable landed 4 minutes later. A false NON-DELIVERY re-
  # dispatches a live teammate, which is the exact failure this whole mechanism
  # exists to prevent.
  PENDING="${PENDING}${PENDING:+|}$t"
done
IFS="$OLDIFS"

# Printed with echo, not `say`: this is the line that tells the lead NOT to act on
# an exhausted sequence, and --quiet must not be able to hide it.
if [ -n "$GRANTED" ]; then
  IFS='|'; for e in $GRANTED; do
    echo "PROGRESS  ${e#* } -- work observed under the progress path; sequence"
    echo "  extended by one beat (grant ${e%% *}). The teammate is demonstrably"
    echo "  working, so this is NOT Rule 20 non-delivery. Do NOT re-dispatch; beat again."
  done; IFS="$OLDIFS"
fi

if [ -n "$EXHAUSTED" ]; then
  IFS='|'; for t in $EXHAUSTED; do
    IFS="$OLDIFS"
    # Under --complete a PRESENT file is never called absent: re-dispatching over a seat's
    # findings discards them. UNFINISHED and UNSETTLED say read the file, then decide.
    if is_unfinished "$t" "$(join_of "$t")"; then
      echo "NON-DELIVERY $t -- after $MAX_BEATS beats."
      echo "UNFINISHED $t -- present, last non-blank line is not ${MARK_NAME}"
    elif is_header_unfinished "$t" "$(join_of "$t")"; then
      echo "NON-DELIVERY $t -- after $MAX_BEATS beats."
      say_header_unfinished "$t"
    elif [ "$COMPLETE" -eq 1 ] && [ -s "$t" ] && [ "$(mtime_of "$t")" -ge "$(join_of "$t")" ] && has_marker "$t"; then
      echo "NON-DELIVERY $t -- after $MAX_BEATS beats."
      echo "UNSETTLED $t -- present and ends in ${MARK_NAME}, but its content was still changing"
    else
      echo "NON-DELIVERY $t -- absent after $MAX_BEATS beats."
    fi
    IFS='|'
  done; IFS="$OLDIFS"
  if [ "$COMPLETE" -eq 1 ]; then
    echo "  UNFINISHED or UNSETTLED is NOT absence: the seat wrote a file. Read it before you"
    echo "  decide -- its findings are real whether or not it closed them, and a re-dispatch"
    echo "  over it discards them. Only a path reported 'absent' is Rule 20 non-delivery."
  fi
  if [ -n "$GRANTSPENT" ]; then
    IFS='|'; for t in $GRANTSPENT; do
      echo "  NOTE: $t still shows work under the progress path, but all $MAX_BEATS"
      echo "  progress grants are spent. The bound is deliberate -- a teammate that"
      echo "  keeps writing without delivering is a hang, and Rule 29 Check C says a"
      echo "  wait must end. Decide: re-dispatch, or --reset if you have read the"
      echo "  worktree and judged it genuinely close."
    done; IFS="$OLDIFS"
  fi
  echo "  Rule 20 defines an absent deliverable as non-delivery. Re-dispatch the"
  echo "  teammate ONCE (then re-run with --reset), and if it fails again, HARD_BLOCK."
  echo "  Do NOT keep beating: the wait never runs forever (Rule 29, Check C)."
  if [ -z "$PROGRESS_PATHS" ] && [ "$COMPLETE" -eq 0 ]; then
    echo "  Before you re-dispatch: an exhausted clock is not evidence of death. If the"
    echo "  teammate may still be working, re-arm with --reset --progress-path <its"
    echo "  worktree> and this beat will extend the sequence while it keeps writing."
  fi
  # The highest-value moment for the liveness report: NON-DELIVERY tells the lead to
  # re-dispatch, and "no teammate has taken a turn in an hour" is the fact that says
  # the deliverable diverged rather than the teammate being slow. Re-dispatching on a
  # path typo repeats the typo.
  say_liveness
  exit 1
fi

if [ -n "$PREEXISTING" ]; then
  NOW_="$(date +%s)"
  IFS='|'; for t in $PREEXISTING; do
    AGE_=$(( NOW_ - $(mtime_of "$t") ))
    AGE_H="$(human_age "$AGE_") old"
    echo "NOTE      $t already had content when this join armed (${AGE_H})."
  done; IFS="$OLDIFS"
  echo "  Not accepting it on sight; this join waits for a write NEWER than the"
  echo "  arming instant. A file that predates the join cannot be shown to be THIS"
  echo "  dispatch's answer -- it is equally the previous sprint's artifact at a"
  echo "  reused path, and consuming that is a silent wrong answer."
  echo "  If your teammate may have delivered BEFORE this join armed (the normal"
  echo "  shape when you are resuming a join after a compaction), re-run with the"
  echo "  dispatch time from the snapshot's In-Flight Teammates row:"
  echo "    scripts/ai-dlc/wait-for-deliverable.sh --since <epoch|ISO8601> <path> ..."
fi

[ -z "$PENDING" ] && exit 0   # everything was already delivered

if [ "$MAY_SLEEP" -eq 0 ]; then
  # This was the line that was BYTE-IDENTICAL on every invocation -- no beat number,
  # no clock, nothing a lead could use to tell beat three from beat one. It now
  # carries both, so a repeat is visibly a repeat and a --reset is visibly a reset.
  NOW_="$(date +%s)"
  IFS='|'
  for t in $PENDING; do
    IFS="$OLDIFS"
    c="${COUNTER_DIR}/$(key_of "$t")"
    b="$(cat "$c" 2>/dev/null || echo 0)"; case "$b" in ''|*[!0-9]*) b=0 ;; esac
    echo "WAITING   $t -- beat ${b}/${MAX_BEATS} (no beat charged), $(human_age "$(( NOW_ - $(join_of "$t") ))") since"
    echo "  this join armed, not yet delivered."
    say_unfinished "$t" "$(join_of "$t")"
    IFS='|'
  done
  IFS="$OLDIFS"
  say_liveness
  echo "  NOTE: a sibling beat already ran in this same Bash call, so this one did"
  echo "  NOT sleep and did NOT consume a beat -- two beats in one call serialize"
  echo "  into 2 x ${BUDGET}s for a wave that ONE call polls concurrently. Do not loop"
  echo "  or chain beats; pass every deliverable to ONE call, and beat again next call:"
  echo "    scripts/ai-dlc/wait-for-deliverable.sh path-a path-b path-c"
  exit 0
fi

# This invocation is going to wait, so it costs a beat. Charge it here and
# nowhere else.
IFS='|'
for t in $PENDING; do
  c="${COUNTER_DIR}/$(key_of "$t")"
  b=0; [ -f "$c" ] && b="$(cat "$c" 2>/dev/null || echo 0)"
  case "$b" in ''|*[!0-9]*) b=0 ;; esac
  printf '%s' "$(( b + 1 ))" > "$c" 2>/dev/null || true
done
IFS="$OLDIFS"

# ---------------------------------------------------------------------------
# ONE beat, polling every pending path. The loop sleeps AFTER its check, so the
# worst-case beat runs to `deadline + POLL`; the reserve must cover a whole poll
# interval or a large POLL silently pushes the beat past the budget.
# ---------------------------------------------------------------------------
# DEADLINE (start + BUDGET - RESERVE) BOUNDS ONE PROPERTY: THE MOMENT THIS BEAT STOPS POLLING
# AND HANDS THE LEAD BACK ITS TURN. The event it waits for is the deliverable landing, which
# IS observed directly (all_present, every POLL seconds); the deadline exists only because
# the wait must be finite -- THE CALL BOUND in the header. It is BUDGET minus a reserve of
# one poll interval (at least MARGIN) because the loop sleeps AFTER its check, so the
# worst-case beat ends at DEADLINE + POLL, which is then at most BUDGET.
# WHEN HIT: the loop breaks and the code below RE-EVALUATES is_delivered for every path, so
# a file that landed during the last sleep is still reported DELIVERED; anything else is
# reported WAITING and costs the beat already charged above. Exit 0 either way.
# LOAD-FREE: the deadline is a wall-clock epoch, not a count of polls, so a loaded box
# gets fewer polls in the same window rather than a longer or shorter window, and the
# verdict is read once more after the loop. The only load effect is the beat overrunning
# BUDGET by the cost of one slow final poll. What load CAN change is whether a settle
# window opens in time, and that belongs to SETTLE above, not here.
RESERVE="$MARGIN"
[ "$POLL" -gt "$RESERVE" ] && RESERVE="$POLL"
DEADLINE=$(( $(date +%s) + BUDGET - RESERVE ))

# ---------------------------------------------------------------------------
# Beat-liveness marker (v0.81.0). A live, backgrounded beat is the ONLY state in
# which the lead may end its turn: the Stop hook (ai-dlc-continue.sh Check 2b)
# allows the yield iff this marker exists and is unexpired, because THIS process
# will exit and re-invoke the idle lead. It is first written before the pre-sleep
# work and released by the EXIT trap (both at "THE BEAT-LIVENESS LEASE" above), so a
# call that returns without sleeping holds it only while it runs, a foreground beat
# clears it on exit, and post-beat prose still BLOCKS -- unchanged behavior.
#
# IT IS A HEARTBEAT, NOT A PROMISE. The marker once held the beat's worst-case
# END epoch, written once. A SIGKILLed beat skips the EXIT trap, so the lead was
# then free to keep yielding until that epoch with NOTHING scheduled to re-invoke
# it -- and the size of that dead window was exactly the beat quantum. At 120s
# that was tolerable; at 600s it would not be. So the loop re-stamps the marker
# every poll with `now + 2*POLL`: a live beat keeps it ~20s ahead, and a dead
# one's marker goes stale within ~20s no matter how large the quantum is. The
# hook's `epoch > now` test is unchanged, and so is the fail-safe direction --
# a stale marker falls through to the Rule 3 block, which force-continues.
#
# 3*POLL, not 1*POLL: the hook may read the marker at any point between two
# re-stamps, so the lease must outlast a whole poll interval plus slack for a
# loaded machine. Too SHORT costs a spurious Rule 3 block on a healthy join;
# too LONG costs idle time after a kill. 30s of lease for 10s of polling puts
# the slack where the cheaper mistake is.
beat_alive

all_present() {
  IFS='|'
  for t in $PENDING; do
    if ! is_delivered "$t" "$(join_of "$t")"; then IFS="$OLDIFS"; return 1; fi
  done
  IFS="$OLDIFS"; return 0
}

while :; do
  if all_present; then break; fi
  [ "$(date +%s)" -ge "$DEADLINE" ] && break
  sleep "$POLL"
  beat_alive
done

RC=0
N_DELIVERED=0
N_WAITING=0
NOW_="$(date +%s)"
IFS='|'
for t in $PENDING; do
  c="${COUNTER_DIR}/$(key_of "$t")"
  s="${c}.since"
  if is_delivered "$t" "$(join_of "$t")"; then
    say "DELIVERED $t"
    say_revised "$t" "$c"
    record_delivered "$t" "$c"
    rm -f "$c" "$s" "${c}.progress" "${c}.grants" "${c}.settle" 2>/dev/null || true
    N_DELIVERED=$(( N_DELIVERED + 1 ))
  else
    b="$(cat "$c" 2>/dev/null || echo '?')"
    # The elapsed clock is the half of this line that a --reset cannot flatten into
    # sameness: the beat number restarts at 1 on every re-arm, the clock restarts
    # too, and a lead that sees both restart can SEE that it re-armed.
    say "WAITING   $t -- beat $b/$MAX_BEATS, $(human_age "$(( NOW_ - $(join_of "$t") ))") since this join armed, not yet delivered. Beat again."
    say_unfinished "$t" "$(join_of "$t")"
    N_WAITING=$(( N_WAITING + 1 ))
  fi
done
IFS="$OLDIFS"

# The beat ran to completion, which is what exit 0 now means -- NOT "everything
# landed". A wave beat can finish with some paths delivered and some still out, so
# the last line states which, and the lead consumes only the DELIVERED ones. This
# is the line that has to be unmissable: the exit code no longer carries it.
if [ "$N_WAITING" -eq 0 ]; then
  say "BEAT COMPLETE -- all ${N_DELIVERED} delivered. Consume them."
else
  # Only when something is STILL OUT. A join that closed needs no liveness report,
  # and printing one there would train the lead to skip the line.
  say_liveness
  say "BEAT COMPLETE -- ${N_DELIVERED} delivered, ${N_WAITING} still out. Consume only the DELIVERED paths, then beat again."
fi

exit "$RC"
