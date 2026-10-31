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
#     WHAT IT CAN AND CANNOT ANSWER. Without --dispatch it cannot say which teammate
#     owed which deliverable -- nothing on disk joins a teammate name to a path, and this
#     script does not guess one, for the same reason it will not guess a progress path.
#     What it can say is a SESSION-scoped fact: whether ANY teammate has taken a turn
#     recently. That is exactly the fact the operator's question surfaced in S306,
#     where the answer was "no -- both went idle an hour ago". WITH --dispatch the join
#     is made by the record the dispatch wrote, not guessed: the spawn ledger's
#     tool_use_id names the `agent-<id>.meta.json` whose toolUseId matches, so the
#     sensor reads that agent's own transcript and no other.
#
#     THE ERROR DIRECTION IS DELIBERATE. The age is the MINIMUM across every teammate
#     in the session, so one live teammate suppresses the idle report for the whole
#     wave, and a beat invoked from inside a teammate can never call itself idle. That
#     under-reports idleness and never over-reports it; under-reporting leaves today's
#     behaviour exactly as it was.
#
#     THE SESSION-WIDE READING CHANGES NO DECISION THIS SCRIPT MAKES -- not the exit
#     code, not the beat counter, not a progress grant. It cannot attribute work to a
#     deliverable: one live teammate anywhere in the session answers for all of them.
#     It is a status line, and here the status line IS the outcome: this file's contract
#     is that stdout carries the verdict (see WHY WAITING IS NOT NONZERO), and S306 was a
#     lead acting on output that could not distinguish two states. Wiring a session-wide
#     mtime heuristic into the exit code would be re-dispatching live teammates on a
#     guess, which is the failure the whole file exists to prevent.
#
#     A TRANSCRIPT SCOPED TO THE DISPATCH IS A DIFFERENT KIND OF EVIDENCE, AND IT DOES
#     DECIDE, IN ONE PLACE. The agentId that --dispatch joins to the dispatch's toolUseId
#     names THIS teammate's own transcript, so a turn in it is this teammate's own work:
#     the same kind of evidence as --progress-path, a delta in a file the teammate
#     writes. It extends a wait only under --complete-repair, with ONE target and ONE
#     resolved agent (dispatch_live), because that mode refuses --progress-path and its
#     record is appended only at the end -- the target cannot grow, so the wait has no
#     growth signal of its own, and without this a live serial remediator reached the cap
#     and was handed "Re-dispatch the teammate ONCE": two writers on one record. The
#     extension goes through the existing counted grant, so the wait still ends.
#
#     TWO BANDS, ONE FOR EACH DECISION. A turn younger than one quantum (BUDGET) is LIVE:
#     it grants. A turn older than that but younger than IDLE_SECS is RECENT: it grants
#     NOTHING, but at the cap it still replaces the bare re-dispatch with "read its last
#     turns, then --reset or STOP it before any re-dispatch", and the beat still exits 1.
#     The reason for the second band: a remediator inside one long tool call takes no turn
#     for longer than a quantum and is STILL A WRITER on its record, and a re-dispatch then
#     puts two writers on one record. That collision is judged on its consequence, not on
#     how rarely a live teammate goes that quiet. At IDLE_SECS or older there is no grant;
#     with the path absent the cap prints STOPPED DISPATCH (read that transcript's last
#     message before any re-dispatch), and only an unresolved, stalled or session-wide beat
#     keeps the bare re-dispatch -- silence that long is the measured mark of a teammate
#     that finished or wrote elsewhere.
#     THE GRANT IS --complete-repair's ALONE; THE REMEDY IS EVERY RESOLVED DISPATCH'S. A plain
#     `--dispatch <id> <path>` beat whose dispatch resolves to ONE agent gets the same LIVE and
#     RECENT answers at the cap (no grant, still exit 1), because a remediator whose work has no
#     deliverable file -- an inline changelog append -- gives the join a path that never
#     appears, and the bare remedy then fired against a live writer (BL-721). Past IDLE_SECS,
#     with the path absent, the cap prints STOPPED in place of the bare remedy: that writer
#     finishes WITHOUT writing the path, so absence plus silence is the shape of a finished
#     teammate as much as a failed one, and its last message decides which.
#     A dispatch that did not resolve to an agent, several dispatches, several targets, a
#     stalled transcript, or no --dispatch at all keep the session-wide reading and the bare
#     remedy, and decide nothing.
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
#   scripts/ai-dlc/wait-for-deliverable.sh --mark <file> <step> <seat> <shard>... findings=<n>
#   scripts/ai-dlc/wait-for-deliverable.sh --mark-repair <file> <pass>
#   scripts/ai-dlc/wait-for-deliverable.sh --dispatch-ts <agentId|toolu_id>
#
#   --dispatch-ts      never a beat: prints the ISO-8601 UTC `ts` of that dispatch's spawn-ledger
#                      row, resolved exactly as --dispatch resolves it, and writes nothing. It is
#                      the In-Flight row's `dispatched-at`. No single ledger row: exit 64.
#
#   --mark             the SEAT's closing call, never a beat: appends its sealed marker
#                      `seat-complete: <step> <seat> <shard> sha=<hex> findings=<n>`; on a
#                      review shard `seat-complete: <step> <seat> <shard> key=<k> sha=<hex> findings=<n>`
#                      (header: "--mark", term 4).
#   --mark-repair      the same for a repair record: `repair-complete: serial <pass> sha=<hex>`.
#   --complete         DELIVERED also needs a last line `seat-complete: ` whose sha= matches
#                      (a marker with no sha= must instead have settled).
#   --complete-repair  the same, keyed on `repair-complete: serial ` -- the serial
#                      remediator's terminal line on a joined repair record. With ONE
#                      target and ONE --dispatch that resolves to an agent, that agent's
#                      own transcript taking a turn within a quantum extends the beat cap
#                      through the counted grants, and a turn within IDLE_SECS withholds
#                      the bare re-dispatch remedy at the cap (header: "TWO BANDS").
#   --status           print DELIVERED / UNFINISHED / UNSETTLED / WAITING per path
#                      and return at once: no sleep, no beat charged, no file written.
#   --shard-header <axis>  with --complete only: a marked adversarial shard DELIVERS only
#                      if `merge-adversarial-shards.sh --check-header <path> --axis <axis>`
#                      passes; otherwise it is UNFINISHED with the merge's refusal text.
#   --dispatch <id>    the dispatch this join waits on: the `agentId` (or `agent_id`) the
#                      Agent result returned, or its toolu_ id. Its spawn-ledger `ts` is the
#                      join's --since, and a --since LATER than it is refused. At the cap a
#                      beat printing LIVE DISPATCH or STOPPED DISPATCH means read that agent's
#                      transcript before any re-dispatch.
#   (Each is documented in full below the `set -u` line.)
#
# EXIT CODES
#   0  BEAT COMPLETE  the beat ran and returned. Read stdout for per-path status:
#                     `DELIVERED <path>` / `WAITING <path>`, then the BEAT COMPLETE
#                     summary line. Consume ONLY the delivered paths.
#                     `PROGRESS <path>` means an exhausted sequence was extended
#                     because work was observed (under --progress-path, in a --complete
#                     target's own writes, or under --complete-repair in the one
#                     dispatched agent's own transcript) -- do NOT re-dispatch, beat again.
#                     `TEAMMATE IDLE, DELIVERABLE ABSENT` means no teammate in this
#                     session has taken a turn for a long time while the join is
#                     still out: the likely cause is a DIVERGED delivery, not a slow
#                     teammate. Check the path before beating again. It is a report,
#                     not a verdict -- the exit code is unaffected.
#   1  NON-DELIVERY   a path exhausted max_wait_beats. Rule 20 non-delivery:
#                     re-dispatch ONCE (with --reset), then HARD_BLOCK -- unless the beat
#                     printed LIVE DISPATCH or STOPPED DISPATCH, in which case read that
#                     agent's transcript first, as the block says.
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
# when a progress signal (--progress-path, a --complete target's own writes, or a
# --complete-repair dispatch's own transcript) holds and every grant is spent. The previous 20
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
#   THE MARKER BINDS THE CONTENT ABOVE IT. A seat that writes its marker and then edits
#   ABOVE it -- measured on the reference consumer: one cross seat wrote its file once,
#   marker last, then made seven in-place Edits over three minutes -- ends in the marker
#   the whole time, so "marker last" alone consumed it mid-edit. So the seat closes with
#   `--mark` (header: "--mark"), which appends `sha=<hex>`: the content_hash of every line
#   above the marker. A marker carrying `sha=` is decided by that digest alone, with NO
#   window and at any age: it matches, and the file is DELIVERED at once; it does not, and
#   the file is UNFINISHED until the seat re-marks, printed as
#     UNFINISHED <path> -- its seat-complete: line carries sha= but the file changed after it was marked; re-mark with --mark
#   on every beat, by --status, and in place of `absent` at exhaustion. A broken seal opens no
#   settle record and is not counted by REVISED-AFTER-MARKER: with a seal no file is consumed
#   mid-edit, so that after-the-fact report belongs to the legacy path alone.
#
#   A MARKER WITH NO `sha=` KEEPS THE SETTLE PATH, AND THAT IS THE FAIL-OPEN NET FOR LEGACY
#   MARKERS DURING THE PULL. This engine is live from pull step 3; the role and step files that
#   tell a seat to run --mark arrive only at the reconcile merge, so until then seats write the
#   bare marker. Refusing it would hang every join of that sprint. So a bare marker is judged
#   exactly as before: DELIVERED also requires the file's content hash to be unchanged for
#   the SETTLE WINDOW: a `.settle`
#   sidecar beside the counter holds `<hash> <epoch first seen>`, any change of hash
#   restarts it, and the file delivers only once `now - epoch > SETTLE` in whole seconds
#   (so at least SETTLE real seconds). A file that loses its marker drops its sidecar.
#
#   THAT NET IS BOUNDED BY THE MARKER ADMISSION (BL-750; content-seal.sh header "THE MARKER
#   ADMISSION", which owns the rule). For a target under `planning-artifacts/` the sibling
#   `content-seal.sh --admit-marker` runs before the settle window: inside its sealed set a bare marker
#   is admitted only while the installed role file its seat names still carries the pre-`--mark`
#   fallback (or no `--mark` instruction), and a missing role file refuses; a sealed marker must also
#   match its file's newest seal row. A refused marker is reported, on every beat, at exhaustion and by
#   --status, as
#     UNFINISHED <path> -- ends in seat-complete: but its marker is not admitted: <refusal text>
#   and opens no settle record. Outside the sealed set (an `epics/part-<n>.md`, a party-mode record) and
#   for any target not under `planning-artifacts/`, the settle path is unchanged.
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
#   exhaustion, for the same reason: it is not absent either. A present, non-empty file last
#   written BEFORE the join armed is reported on exhaustion as
#     UNCHANGED <path> -- present (<n> lines), not modified since the join
#   -- a serial remediator's record mid-pass, appended only at the end, is exactly that file.
#   The bare Rule 20 re-dispatch remedy prints only when some exhausted target is truly absent.
#
# Without --complete every line this script prints is byte-identical to before.
#
# --complete-repair: THE SERIAL REMEDIATOR'S JOINED RECORD. That record exists before the
# serial remediator is dispatched and is APPENDED to, so the plain predicate returns on its
# first append and on every one after it, and `seat-complete:` is not a line a repair record
# carries. This flag is --complete in every respect except the marker, which is
# `repair-complete: serial ` and ONLY that. The serial remediator closes with `--mark-repair
# <record> <pass>`, which seals `repair-complete: serial <pass> sha=<hex>` exactly as --mark seals
# a seat file; a bare `repair-complete: serial <pass>` is a legacy marker and settles as before.
# The token is keyed per CALL, never per target and
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
#                        (also a marker whose sha= is broken: changed after it was marked)
#   UNSETTLED <path>     a marker with no sha=, settle pending -- the settle window needs a hash a
#                        BEAT recorded more than SETTLE seconds ago, and --status records none.
#                        A marker whose sha= matches reads DELIVERED here with no beat at all.
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
# SETTLE APPLIES TO A LEGACY MARKER ONLY -- one carrying no `sha=` (header: "THE MARKER BINDS THE
# CONTENT ABOVE IT"). A sealed marker is decided by its digest and never waits on this window.
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
DISPATCH_TS_ONLY=""
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

# --complete: the LAST NON-BLANK line begins with this call's marker token (`seat-complete: `,
# or `repair-complete: serial ` under --complete-repair), carries no carriage return, and is
# not inside an unclosed fence. A whitespace-only line is blank (NF == 0), so trailing blank
# lines cannot hide the marker. The token reaches awk through the environment, never `-v`,
# which would strip a level of escaping.
has_marker() {  # $1 = path
  MT_="$MARK_TOKEN" awk '
    # A fence opens on a run of 3+ backticks (info string carrying no backtick) or 3+ tildes; it closes only on a run of the SAME
    # character at least as long, with nothing but blanks after it.
    match($0, /^[ \t]*(```+|~~~+)/) {
      r = substr($0, RSTART, RLENGTH); sub(/^[ \t]*/, "", r)
      if (fc == "") { if (!(substr(r, 1, 1) == "`" && substr($0, RSTART + RLENGTH) ~ /`/)) { fc = substr(r, 1, 1); fl = length(r) } }
      else if (substr(r, 1, 1) == fc && length(r) >= fl && substr($0, RSTART + RLENGTH) ~ /^[ \t\r]*$/) { fc = ""; fl = 0 }
    }
    NF { l = $0 }
    END { exit ((fc == "" && l !~ /\r/ && index(l, ENVIRON["MT_"]) == 1) ? 0 : 1) }' "$1" 2>/dev/null
}

content_hash() {  # $1 = path -> a content hash, empty when unreadable
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" 2>/dev/null | cut -d' ' -f1
  elif command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" 2>/dev/null | cut -d' ' -f1
  else cksum < "$1" 2>/dev/null | tr -d ' \t'; fi
}

# THE SEAL (header: "--mark"). The body a seal binds is every line above the file's LAST
# NON-BLANK line, each with its newline; `seal_body <path> 1` keeps that last line too (the
# writer's body when the file ends in no marker yet). ONE extraction serves the writer and the
# reader, so both hash the same bytes with the same content_hash.
seal_body() {  # $1 = path, $2 = 1 to keep the last non-blank line -> bytes on stdout
  awk -v k="${2:-0}" 'NF { L = NR } { a[NR] = $0 } END { if (k == 1) L++; for (i = 1; i < L; i++) print a[i] }' "$1" 2>/dev/null
}
# seal_of <path whose marker has_marker accepted> -> SEAL_V and its status:
#   sealed (0)  the marker carries `sha=<hex>` and it equals the digest of the body above it
#   broken (1)  the marker carries `sha=` and it does not: the file changed after it was marked
#   legacy (2)  the marker carries no `sha=` token: a seat from before the seal, which SETTLE judges
seal_of() {
  so_s_="$(awk 'NF { l = $0 } END { n = split(l, w, /[ \t]+/); f = "N"
    for (i = 1; i <= n; i++) if (w[i] ~ /^sha=/) { f = "Y"; s = substr(w[i], 5) }; print f s }' "$1" 2>/dev/null)"
  case "$so_s_" in
    Y*) so_s_="${so_s_#Y}" ;;
    *) SEAL_V="legacy"; return 2 ;;
  esac
  so_d_="$(seal_body "$1" | content_hash /dev/stdin)"
  if [ -n "$so_s_" ] && [ -n "$so_d_" ] && [ "$so_s_" = "$so_d_" ]; then SEAL_V="sealed"; return 0; fi
  SEAL_V="broken"; return 1
}

# ---------------------------------------------------------------------------
# --mark / --mark-repair: THE SEAL WRITER. It runs here, before the flag loop, the root walk and
# every write below, so it creates no state dir, takes no lease and charges no beat: it is the
# seat's own last act, not a beat. One Bash call:
#   wait-for-deliverable.sh --mark <file> <step> <seat> <shard>... findings=<n>
#   wait-for-deliverable.sh --mark-repair <file> <pass>
# It drops a trailing marker of its own token (sealed or bare), so a re-mark replaces rather
# than stacks, and drops trailing blank lines. It writes the body to a sibling temp file, takes
# that file's content_hash, appends
#   seat-complete: <step> <seat> <shard>... sha=<hex> findings=<n>
#   seat-complete: <step> <seat> <shard> key=<k> sha=<hex> findings=<n>     (a review shard, term 4)
#   repair-complete: serial <pass> sha=<hex>
# (`sha=` BEFORE `findings=`: both merges anchor `findings=[0-9]+[ \t]*$` at end of line), and
# moves it over the file only once the beat's own has_marker and seal_of read it as sealed. A
# body ending inside an unclosed fence would put the marker in the fence, a file no beat accepts
# -- the hang this exists to prevent -- so that, and every other bad call, is exit 64 with the
# file untouched.
#
# THE CONTENT SEAL (`content-seal.sh`, beside this script, owns the sealed set and the
# comparison). A file under `planning-artifacts/` may be in the sealed set, whose join readers
# refuse bytes that differ from the file's newest seal row -- and this call is a Bash write. So it
# is the ONE sanctioned Bash write, on three terms:
#   1. It reads a SNAPSHOT of the file, and when the file carries a seal row the snapshot must be
#      the sealed bytes: a file already amended through Bash is refused (64), never laundered.
#   2. It seals only a file that HAD a seal row. A file with none -- written wholly through Bash,
#      or before the recorder -- stays uncompared, as the seal leaves it, so marking never turns
#      an unsealed file into a sealed one.
#   3. Its program row records the sha of the bytes THIS CALL WROTE (`--record-expect`), never
#      whatever is on disk after the move, and none at all when those bytes are already gone. A
#      write landing after the move then differs from the row, and every reader refuses it.
#   4. A REVIEW SHARD -- a file in `<idx>-code-review-<sha12>[-p<M>]/` or
#      `<idx>-qa-validation-<sha12>[-p<M>]/` (under `docs/reviews/s<N>/shards/`, outside any state
#      dir) -- is held further. `<shard>` is the file's KEY, its name without `.md` (`03`, `cross`,
#      `cross-2`), compared ordinal-normalised; a field carrying `key=` or `sha=` is refused, and
#      exactly <step> <seat> <shard> findings=<n> is taken. Before anything is written it runs the
#      sibling `merge-review-shards.sh <dir> --gate code-review|qa --check-shard <file> --findings <n>`
#      (the merge's own per-shard code) and `content-seal.sh --review-shard <file>`, which REQUIRES a
#      seal row (a seat's Write leaves one through the recorder; a shard with none was not written by
#      its seat, or the recorder is not registered), refuses bytes that differ from it, and refuses a
#      shard last written by the top-level session. Either refusing is exit 64 with its text, nothing
#      written; a seal reader exit 4 (`SEAL-UNAVAILABLE`: jq absent, the file not in a git worktree,
#      a ledger that does not parse) is also exit 64, relaying that text with an environment remedy. The snapshot must still equal the file after
#      both run. The marker then carries
#      `key=<k>` (between <shard> and sha=; findings= stays last), and the program row is recorded with
#      --record-expect into the ledger content-seal.sh locates from the shard's common dir. The
#      remedy for every refusal on bytes is re-dispatching the reviewer. The sentinel comment
#      MARK-KEY-WRITER (with its version, once, in the block below) marks this writer for
#      merge-review-shards.sh's legacy test.
#   5. A REMEDIATOR PART -- a non-review file at `planning-artifacts/s<N>/shards/<D>/<b>.md` where <D>
#      ends in `-repair-p<M>` or `-repair` -- keeps the arity and findings= checks above, then has its
#      <step> <seat> <shard> REPLACED by derived words: step = <D> without that suffix (`coe-repair-p1`
#      -> `coe`, `requirements-party-repair` -> `requirements-party`), seat = `remediator`, shard = <b>
#      without `.md`, as spelled (`1`, `05`, `lane-1`). The marker is then
#      `seat-complete: <step> remediator <b> sha=<hex> findings=<n>`. It derives rather than refuses
#      because no reader consumes those three words of a sealed marker (has_marker reads the prefix,
#      seal_of reads sha=) and a lead brief produces `shard: i/N`, which a refusal would reject. These
#      directory names cannot overlap term 4: a review directory ends in 12 hex digits (optionally
#      -p<M>), and `repair` is not 12 hex digits. Every other path writes the caller's words.
#   6. A REMEDIATOR FILE (`--mark-repair`, or `--mark` on a term-5 part) stating `derivations: not
#      replayed` is REPLAYED here, because the join refuses that line and a refusal there costs a whole
#      re-dispatch (BL-804). Which lines count is the JOIN's own judgment: the sibling
#      join-remediator-shards.sh's checks_field is extracted and run (CF_LINES=1) on the body plus a
#      provisional marker of this call's token, so a part holding no repaired entry, and in a joined
#      record every shard segment above the block this call closes, is left as written. When it names
#      lines, the sibling validate-artifact-derivations.sh runs on the snapshot, with
#      AI_DLC_PROJECT_ROOT the state dir's parent and AI_DLC_DERIV_SUPERSEDE_FROM the file (so the
#      supersession the gate applies to a record applies here). Exit 0 with `OK: <n> derivation(s)`
#      rewrites each named line to `<indent>derivations: replayed <n>` in a fresh copy, and that copy is
#      what is sealed: after term 1, before the seal, so term 3's row records the rewritten bytes and
#      nothing is laundered. <n> is the WHOLE FILE's count, one figure for every rewritten line. Exit 1
#      refuses (64) relaying the FAIL line, with the deferral remedy only where the join lets the
#      record defer (a `sections/.manifest` or `.subject` in its shard dir); any other exit, or an
#      exit 0 with no OK line, refuses as no verdict. Either sibling absent is a 64 naming reinstall.
#      `replayed <n>` and `deferred to the join` lines, and a file with no derivations line, are never touched.
#      A CLAIMED REPLAY IS CHECKED, NEVER REWRITTEN (BL-816). When the segment this call closes states
#      `replayed <n>` (checks_field's RPL line gives that segment's first and last line), the validator
#      runs the same way, and exit 1 refuses (64) only on a `FAIL (<KIND>): <copy>:<line>` whose line
#      lies inside that range; a FAIL in any other segment is left to the join, and n is not compared.
#      A FAIL line that names no line of the copy refuses, and any exit but 0 or 1 refuses as no verdict.
# ---------------------------------------------------------------------------
mark_refuse() { echo "FAIL: $MK_MODE: $1 Nothing was written." >&2; exit 64; }
# mk_sibling_ <file> <entry function>: 0 when <file> defines the entry function at a line start, so it holds
# its program behind a BASH_SOURCE guard and can be sourced and asked in process (read with builtins, no
# process). A sibling that does not (a stand-in script) is run as a process, as it always was.
mk_sibling_() { local _t; IFS= read -r -d '' _t < "$1" || true; [[ "$_t" == *$'\n'"$2() {"* ]]; }
# wfd_mark_main holds the --mark / --mark-repair dispatch below, unchanged. It is a function so a
# fixture can source this file (the guard after it) and run the writer in a subshell; run as a
# program it is called at once, from the same place, with the script's own arguments.
wfd_mark_main() {
case "${1:-}" in
  --mark|--mark-repair)
    MK_MODE="$1"; shift
    MK_FILE="${1:-}"; [ $# -gt 0 ] && shift
    [ -n "$MK_FILE" ] || mark_refuse "needs the file to mark."
    [ -f "$MK_FILE" ] && [ -s "$MK_FILE" ] || mark_refuse "'$MK_FILE' is not a non-empty file; write the findings first, then mark."
    for mk_w_ in "$@"; do
      case "$mk_w_" in ''|*"$(printf '\r')"*|*"
"*) mark_refuse "a marker field is empty or carries a line break." ;; esac
    done
    if [ "$MK_MODE" = "--mark" ]; then
      [ $# -ge 4 ] || mark_refuse "takes <file> <step> <seat> <shard>... findings=<n>."
      eval "MK_N=\${$#}"
      case "$MK_N" in findings=[0-9]*) case "${MK_N#findings=}" in *[!0-9]*) mark_refuse "the last field must be findings=<n> (got '$MK_N')." ;; esac ;;
        *) mark_refuse "the last field must be findings=<n> (got '$MK_N')." ;; esac
      MK_F=""; mk_i_=1
      for mk_w_ in "$@"; do [ "$mk_i_" -lt $# ] && MK_F="${MK_F}${MK_F:+ }$mk_w_"; mk_i_=$(( mk_i_ + 1 )); done
      MARK_TOKEN="seat-complete: "; MK_TAIL="$MK_N"
    else
      [ $# -eq 1 ] || mark_refuse "takes <file> <pass>."
      MARK_TOKEN="repair-complete: serial "; MK_F="$1"; MK_TAIL=""
    fi
    MK_SEAL="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/content-seal.sh"
    # REVIEW SHARDS (header: "--mark", term 4). A file in `<idx>-code-review-<sha12>[-p<M>]/` or
    # `<idx>-qa-validation-<sha12>[-p<M>]/` is keyed, checked and sealed here before anything is written.
    # MARK-KEY-WRITER v1
    MK_REVIEW=""; MK_GATE=""
    MK_PDIR="$(cd "$(dirname "$MK_FILE")" 2>/dev/null && pwd)"
    if [ "$MK_MODE" = "--mark" ]; then
      mk_bd_="${MK_PDIR##*/}"
      case "$mk_bd_" in *-p[0-9]*) mk_bs_="${mk_bd_%-p*}"; case "${mk_bd_##*-p}" in *[!0-9]*) mk_bs_="$mk_bd_" ;; esac ;; *) mk_bs_="$mk_bd_" ;; esac
      case "$mk_bs_" in
        *-code-review-????????????) MK_GATE=code-review ;;
        *-qa-validation-????????????) MK_GATE=qa ;;
      esac
      if [ -n "$MK_GATE" ]; then case "${mk_bs_##*-}" in *[!0-9a-f]*) MK_GATE="" ;; esac; fi
      [ -n "$MK_GATE" ] && MK_REVIEW=1
    fi
    if [ -n "$MK_REVIEW" ]; then
      MK_RESTORE="re-dispatch the reviewer for that shard, which rewrites it with Write and marks it again; never amend a review shard through Bash or a lead Write/Edit."
      # The key is the file's own name: `<ordinal>.md` as spelled, `cross.md`, `cross-<g>.md` (g de-zeroed).
      mk_b_="$(basename "$MK_FILE")"
      case "$mk_b_" in
        cross.md) MK_KEY=cross ;;
        cross-*.md) mk_g_="${mk_b_#cross-}"; mk_g_="${mk_g_%.md}"
          case "$mk_g_" in ""|*[!0-9]*|??????????*) mark_refuse "'$MK_FILE' is not a review shard name (<ordinal>.md, cross.md or cross-<g>.md)." ;; esac
          MK_KEY="cross-$((10#$mk_g_))" ;;
        *.md) MK_KEY="${mk_b_%.md}"
          case "$MK_KEY" in ""|*[!0-9]*|??????????*) mark_refuse "'$MK_FILE' is not a review shard name (<ordinal>.md, cross.md or cross-<g>.md)." ;; esac ;;
        *) mark_refuse "'$MK_FILE' is not a review shard name (<ordinal>.md, cross.md or cross-<g>.md)." ;;
      esac
      case " $MK_F " in *key=*|*sha=*) mark_refuse "a marker field carries key= or sha=; --mark writes both itself (key=$MK_KEY from the file name). Pass <step> <seat> $MK_KEY findings=<n>." ;; esac
      set -f; set -- $MK_F; set +f
      [ $# -eq 3 ] || mark_refuse "a review shard's marker takes exactly <step> <seat> <shard> findings=<n> (got '$MK_F'); <shard> is the file's key, $MK_KEY."
      mk_s_="$3"
      # Ordinal-normalised: `3`, `03` and `003` are one key; `cross-02` is `cross-2`.
      case "$MK_KEY" in
        cross) [ "$mk_s_" = cross ] || mk_s_="!" ;;
        cross-*) case "$mk_s_" in cross-*) mk_g_="${mk_s_#cross-}"; case "$mk_g_" in ""|*[!0-9]*|??????????*) mk_s_="!" ;; *) [ "$((10#$mk_g_))" = "${MK_KEY#cross-}" ] || mk_s_="!" ;; esac ;; *) mk_s_="!" ;; esac ;;
        *) case "$mk_s_" in ""|*[!0-9]*|??????????*) mk_s_="!" ;; *) [ "$((10#$mk_s_))" = "$((10#$MK_KEY))" ] || mk_s_="!" ;; esac ;;
      esac
      [ "$mk_s_" != "!" ] || mark_refuse "the <shard> field '$3' is not this file's key, $MK_KEY (the shard's own file name without .md); mark it as <step> <seat> $MK_KEY findings=<n>."
      MK_F="$MK_F key=$MK_KEY"
      MK_MERGE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/merge-review-shards.sh"
      [ -f "$MK_MERGE" ] || mark_refuse "a review shard is checked by merge-review-shards.sh --check-shard, which is not beside this script ($MK_MERGE); reinstall ai-dlc."
      [ -f "$MK_SEAL" ] || mark_refuse "a review shard is sealed by content-seal.sh, which is not beside this script ($MK_SEAL); reinstall ai-dlc."
      MK_SRC="$(mktemp "${TMPDIR:-/tmp}/wfd-mark.XXXXXX")" || mark_refuse "cannot take a snapshot of $MK_FILE."
      cp "$MK_FILE" "$MK_SRC" || { rm -f "$MK_SRC"; mark_refuse "cannot take a snapshot of $MK_FILE."; }
      if mk_sibling_ "$MK_MERGE" mrs_main; then
        MK_OUT="$( ( . "$MK_MERGE" && mrs_main "$MK_PDIR" --gate "$MK_GATE" --check-shard "$MK_FILE" --findings "${MK_N#findings=}" ) 2>&1 )"
      else
        MK_OUT="$(bash "$MK_MERGE" "$MK_PDIR" --gate "$MK_GATE" --check-shard "$MK_FILE" --findings "${MK_N#findings=}" 2>&1)"
      fi \
        || { rm -f "$MK_SRC"; mark_refuse "merge-review-shards.sh --check-shard refused the shard; fix every line below, then mark again:
$MK_OUT
"; }
      if mk_sibling_ "$MK_SEAL" seal_main; then
        MK_OUT="$( ( . "$MK_SEAL" && seal_main --review-shard "$MK_FILE" ) 2>&1 )"; MK_SRC_RC=$?
      else
        MK_OUT="$(bash "$MK_SEAL" --review-shard "$MK_FILE" 2>&1)"; MK_SRC_RC=$?
      fi
      # Exit 4 is the ENVIRONMENT (SEAL-UNAVAILABLE: jq, git placement, the ledger): relayed as is,
      # since re-dispatching the reviewer cannot repair it.
      [ "$MK_SRC_RC" -ne 4 ] \
        || { rm -f "$MK_SRC"; mark_refuse "$MK_OUT; repair the environment, then mark again."; }
      [ "$MK_SRC_RC" -eq 0 ] \
        || { rm -f "$MK_SRC"; mark_refuse "$MK_OUT; $MK_RESTORE"; }
      cmp -s "$MK_SRC" "$MK_FILE" \
        || { rm -f "$MK_SRC"; mark_refuse "'$MK_FILE' changed while it was being checked; mark it again once nothing else writes it."; }
      MK_STATE="$( . "$MK_SEAL" && seal_review_locate "$MK_FILE" && printf '%s' "$_RV_STATE" )" && [ -n "$MK_STATE" ] \
        || { rm -f "$MK_SRC"; mark_refuse "the ledger for '$MK_FILE' cannot be located."; }
      MK_ROWED=1
    fi
    # The state dir AS SPELLED (logical `pwd`, never -P): content-seal.sh names a row by the state
    # dir's own name, which the recorder takes from AI_DLC_STATE_DIR, so a symlinked `_bmad-output`
    # resolved to its target would name no row and the file would never be re-sealed. The FIRST
    # `/planning-artifacts/` is the state dir's; a later one is a directory inside the sprint.
    MK_PHYS="$(cd "$(dirname "$MK_FILE")" 2>/dev/null && pwd)/$(basename "$MK_FILE")"
    # REMEDIATOR PART (header: "--mark", term 5): the words are derived from the path, the caller's are dropped.
    if [ "$MK_MODE" = "--mark" ] && [ -z "$MK_REVIEW" ]; then
      mk_pd_="${MK_PHYS%/*}"; mk_dn_="${mk_pd_##*/}"; mk_gp_="${mk_pd_%/*}"; mk_pb_="${MK_PHYS##*/}"
      case "$mk_gp_" in */planning-artifacts/s[0-9]*/shards) mk_rs_=""
        case "$mk_dn_" in
          *-repair-p[0-9]*) case "${mk_dn_##*-repair-p}" in *[!0-9]*) ;; *) mk_rs_="${mk_dn_%-repair-p*}" ;; esac ;;
          *-repair) mk_rs_="${mk_dn_%-repair}" ;;
        esac
        case "$mk_pb_" in *.md) [ -n "${mk_pb_%.md}" ] || mk_rs_="" ;; *) mk_rs_="" ;; esac
        if [ -n "$mk_rs_" ]; then MK_F="$mk_rs_ remediator ${mk_pb_%.md}"; fi ;;
      esac
    fi
    MK_REM=""; [ "$MK_MODE" = "--mark-repair" ] && MK_REM=1
    [ "$MK_MODE" = "--mark" ] && [ -z "$MK_REVIEW" ] && [ -n "${mk_rs_:-}" ] && MK_REM=0
    if [ -n "$MK_REVIEW" ]; then :; else
    MK_STATE=""; MK_ROWED=0; MK_SRC="$MK_FILE"
    case "$MK_PHYS" in */planning-artifacts/*) MK_STATE="${MK_PHYS%%/planning-artifacts/*}" ;; esac
    fi
    if [ -n "$MK_REVIEW" ]; then :
    elif [ -n "$MK_STATE" ] && [ -f "$MK_SEAL" ]; then
      MK_SRC="$(mktemp "${TMPDIR:-/tmp}/wfd-mark.XXXXXX")" || mark_refuse "cannot take a snapshot of $MK_FILE."
      cp "$MK_FILE" "$MK_SRC" || { rm -f "$MK_SRC"; mark_refuse "cannot take a snapshot of $MK_FILE."; }
      if mk_sibling_ "$MK_SEAL" seal_main; then
        MK_ROW="$( ( . "$MK_SEAL" && seal_main --row "$MK_STATE" "$MK_FILE" ) 2>&1 )"
      else
        MK_ROW="$(bash "$MK_SEAL" --row "$MK_STATE" "$MK_FILE" 2>&1)"
      fi \
        || { rm -f "$MK_SRC"; mark_refuse "its content-seal row could not be read: $(printf '%s\n' "$MK_ROW" | head -1)"; }
      if [ "$MK_ROW" != null ]; then
        MK_ROWED=1
        MK_WANT="$(printf '%s' "$MK_ROW" | sed -n 's/.*"sha256":"\([0-9a-f][0-9a-f]*\)".*/\1/p')"
        MK_HAVE="$( . "$MK_SEAL" && seal_sha "$MK_SRC" )"
        if [ -z "$MK_WANT" ] || [ "$MK_HAVE" != "$MK_WANT" ]; then
          rm -f "$MK_SRC"
          case "$MK_PHYS" in
            */planning-artifacts/s[0-9]*/shards/*-repair-p*/*.md) MK_RESTORE="restore the file with Edit, then mark." ;;
            */planning-artifacts/s[0-9]*/shards/*/*.md) MK_RESTORE="re-dispatch the adversary for that shard, then merge with merge-adversarial-shards.sh --rerun <shard>.md@<ISO> (a lead Edit re-seals the bytes but leaves a shard last written by the top-level session, which the merge refuses)." ;;
            *) MK_RESTORE="restore the file with Edit, then mark." ;;
          esac
          mark_refuse "'$MK_FILE' is not the bytes its newest content-seal row records ($MK_WANT; on disk $MK_HAVE), so it changed through Bash after its last Write or Edit. --mark never seals such bytes: $MK_RESTORE"
        fi
      fi
    elif [ -n "$MK_STATE" ] && grep -qE '"actor":[[:space:]]*"(agent|session)"' "$MK_STATE/planning-artifacts/.artifact-writes.jsonl" 2>/dev/null; then
      mark_refuse "$MK_STATE/planning-artifacts/.artifact-writes.jsonl carries content-seal rows but $MK_SEAL is absent, so the file's seal cannot be honoured; reinstall ai-dlc."
    fi
    MK_KEEP=1; has_marker "$MK_SRC" && MK_KEEP=0
    # THE REPLAY (header: "--mark", term 6). Between term 1 and the seal, so the seal and term 3's row
    # cover the rewritten bytes and nothing is laundered.
    if [ -n "$MK_REM" ] && LC_ALL=C awk '/^[[:space:]-]*[*_`]*derivations[*_`]*:/ { v = tolower($0); gsub(/[*_`\r]/, "", v); if (v ~ /not replayed|replayed [0-9]/) f = 1 } END { exit !f }' "$MK_SRC"; then
      mk_rdrop_() { rm -f "$MK_PRB" "$MK_VO" "$MK_VE"; [ "$MK_SRC" = "$MK_FILE" ] || rm -f "$MK_SRC"; }
      mk_sd_="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
      MK_JOIN="$mk_sd_/join-remediator-shards.sh"; MK_VAL="$mk_sd_/validate-artifact-derivations.sh"
      MK_PRB=""; MK_VO=""; MK_VE=""
      [ -f "$MK_JOIN" ] || { mk_rdrop_; mark_refuse "a record stating 'derivations: not replayed' or 'replayed <n>' is checked here, and the join's checks_field, which segments it, is not beside this script ($MK_JOIN); reinstall ai-dlc."; }
      [ -f "$MK_VAL" ] || { mk_rdrop_; mark_refuse "a record stating 'derivations: not replayed' or 'replayed <n>' is checked by validate-artifact-derivations.sh, which is not beside this script ($MK_VAL); reinstall ai-dlc."; }
      mk_n_="$(grep -c '^checks_field() {' "$MK_JOIN")" || mk_n_=0
      [ "$mk_n_" = 1 ] || { mk_rdrop_; mark_refuse "found $mk_n_ 'checks_field() {' definitions in $MK_JOIN (want exactly 1); reinstall ai-dlc."; }
      # checks_field reads the join's one disposition-key predicate (BL-823), so it is extracted beside it.
      mk_n_="$(grep -c '^DISP_KEY_ERE=' "$MK_JOIN")" || mk_n_=0
      [ "$mk_n_" = 1 ] || { mk_rdrop_; mark_refuse "found $mk_n_ 'DISP_KEY_ERE=' definitions in $MK_JOIN (want exactly 1); reinstall ai-dlc."; }
      MK_PRB="$(mktemp "${TMPDIR:-/tmp}/wfd-mark.XXXXXX")" || { mk_rdrop_; mark_refuse "cannot take a snapshot of $MK_FILE."; }
      # The record AS THE JOIN WILL READ IT: this call's body and a provisional marker of this call's
      # token, so the segment that marker closes is the one this call seals (line numbers unchanged).
      { seal_body "$MK_SRC" "$MK_KEEP"; printf '%s%s sha=0%s%s\n' "$MARK_TOKEN" "$MK_F" "${MK_TAIL:+ }" "$MK_TAIL"; } > "$MK_PRB" \
        || { mk_rdrop_; mark_refuse "cannot take a snapshot of $MK_FILE."; }
      MK_CF="$( eval "$(grep '^DISP_KEY_ERE=' "$MK_JOIN"; sed -n '/^checks_field() {/,/^}/p' "$MK_JOIN")" && CF_LINES=1 checks_field "$MK_REM" "$MK_PRB" | awk -F'\t' '$1 == "NRL" || $1 == "RPL"' )" \
        || { mk_rdrop_; mark_refuse "the join's checks_field could not read $MK_FILE."; }
      MK_NRL="$(printf '%s\n' "$MK_CF" | awk -F'\t' '$1 == "NRL" { print $2 }')"
      MK_RPL="$(printf '%s\n' "$MK_CF" | awk -F'\t' '$1 == "RPL" { l = $2 " " $3 } END { print l }')"
      if [ -n "${MK_NRL# }" ] || [ -n "$MK_RPL" ]; then
        MK_VO="$(mktemp "${TMPDIR:-/tmp}/wfd-mark.XXXXXX")" && MK_VE="$(mktemp "${TMPDIR:-/tmp}/wfd-mark.XXXXXX")" \
          || { mk_rdrop_; mark_refuse "cannot take a snapshot of $MK_FILE."; }
        # IN PROCESS ONLY WHEN THE CALLER LOADED THIS VERY VALIDATOR. A caller that sourced
        # validate-artifact-derivations.sh and ran its vad_load (a fixture driving --mark in process)
        # gets the same run as `bash "$MK_VAL"` from `( vad_invoke ... )`, its documented in-process
        # equal. Taken only when VAD_LOADED and the files vad_invoke, vad_load and vad_run were
        # DEFINED from (extdebug) are all $MK_VAL itself, so a function imported from the environment,
        # which names no file, never stands in for the validator. Otherwise the lines below run as
        # they always have.
        mk_vin_=0
        if [ -n "${VAD_LOADED:-}" ] && [ "$VAD_LOADED" -ef "$MK_VAL" ] && declare -F vad_invoke > /dev/null 2>&1; then
          mk_vin_=1
          mk_vdf_="$(shopt -s extdebug; declare -F vad_invoke vad_load vad_run 2>/dev/null)" || mk_vdf_='x 0 '
          while IFS= read -r mk_vdl_; do
            mk_vdl_="${mk_vdl_#* }"; mk_vdl_="${mk_vdl_#* }"
            [ -n "$mk_vdl_" ] && [ "$mk_vdl_" != "(null)" ] && [ "$mk_vdl_" -ef "$MK_VAL" ] || mk_vin_=0
          done <<< "$mk_vdf_"
        fi
        if [ "$mk_vin_" = 1 ]; then
          if [ -n "$MK_STATE" ]; then
            ( AI_DLC_PROJECT_ROOT="$(dirname "$MK_STATE")" AI_DLC_DERIV_SUPERSEDE_FROM="$MK_FILE" vad_invoke "$MK_SRC" ) > "$MK_VO" 2> "$MK_VE"; mk_vrc_=$?
          else
            ( AI_DLC_DERIV_SUPERSEDE_FROM="$MK_FILE" vad_invoke "$MK_SRC" ) > "$MK_VO" 2> "$MK_VE"; mk_vrc_=$?
          fi
        else
        if [ -n "$MK_STATE" ]; then
          AI_DLC_PROJECT_ROOT="$(dirname "$MK_STATE")" AI_DLC_DERIV_SUPERSEDE_FROM="$MK_FILE" bash "$MK_VAL" "$MK_SRC" > "$MK_VO" 2> "$MK_VE"; mk_vrc_=$?
        else
          AI_DLC_DERIV_SUPERSEDE_FROM="$MK_FILE" bash "$MK_VAL" "$MK_SRC" > "$MK_VO" 2> "$MK_VE"; mk_vrc_=$?
        fi
        fi
        mk_vn_="$(sed -n 's/^OK: \([0-9][0-9]*\) derivation(s) .*/\1/p' "$MK_VO" | tail -1)"
        # BL-816: a block claiming `replayed <n>` is refused only on a FAIL whose `<copy>:<line>` lies in
        # that block's own range (n is not compared). A FAIL in another segment is the join's to judge;
        # a FAIL line naming no line of the copy is kept, so an attribution that cannot be read refuses.
        # An exit 1 is a VERDICT only beside the validator's own `FAIL: <n> stale or unrunnable derivation(s)`
        # summary on stderr; one without it (a `set -u` fault, a syntax error) is a crash, never a FAIL set
        # that happens to miss this block, and is refused as no verdict on both the replayed and not-replayed paths.
        mk_vs_=0; [ "$mk_vrc_" -eq 1 ] && grep -q '^FAIL: [0-9][0-9]* stale or unrunnable derivation' "$MK_VE" && mk_vs_=1
        MK_ATT=""
        if [ "$mk_vs_" = 1 ] && [ -z "${MK_NRL# }" ]; then
          MK_ATT="$(LC_ALL=C awk -v pfx="$MK_SRC:" -v lo="${MK_RPL% *}" -v hi="${MK_RPL#* }" '/^FAIL \([A-Z-]+\): / {
              i = index($0, pfx); r = (i ? substr($0, i + length(pfx)) : ""); if (!match(r, /^[0-9]+/)) { print; next }
              ln = substr(r, 1, RLENGTH) + 0; if (ln >= lo + 0 && ln <= hi + 0) print }' "$MK_VE")"
        fi
        if [ -z "${MK_NRL# }" ] && { { [ "$mk_vrc_" -eq 0 ] && [ -n "$mk_vn_" ]; } || { [ "$mk_vs_" = 1 ] && [ -z "$MK_ATT" ]; }; }; then
          rm -f "$MK_PRB" "$MK_VO" "$MK_VE"
        elif [ "$mk_vrc_" -eq 0 ] && [ -n "$mk_vn_" ]; then
          MK_RW="$(mktemp "${TMPDIR:-/tmp}/wfd-mark.XXXXXX")" || { mk_rdrop_; mark_refuse "cannot take a snapshot of $MK_FILE."; }
          LC_ALL=C awk -v ls="$MK_NRL" -v n="$mk_vn_" 'BEGIN { k = split(ls, a, " "); for (i = 1; i <= k; i++) at[a[i]] = 1 }
            FNR in at { match($0, /^[[:space:]-]*/); print substr($0, 1, RLENGTH) "derivations: replayed " n; next } { print }' "$MK_SRC" > "$MK_RW" \
            || { rm -f "$MK_RW"; mk_rdrop_; mark_refuse "cannot write the replayed copy of $MK_FILE."; }
          rm -f "$MK_PRB" "$MK_VO" "$MK_VE"; [ "$MK_SRC" = "$MK_FILE" ] || rm -f "$MK_SRC"
          MK_SRC="$MK_RW"
        else
          mk_vr_="$(grep -E '^(FAIL|REFUSED|ERROR):' "$MK_VE" | head -3)"; [ -n "$mk_vr_" ] || mk_vr_="$(head -3 "$MK_VE")"
          if [ "$mk_vs_" = 1 ]; then
            mk_pd_="${MK_PHYS%/*}"
            if [ "$MK_REM" = 1 ]; then mk_sh_="$mk_pd_/shards/$(basename "$MK_PHYS" .md)"; else mk_sh_="$mk_pd_"; fi
            MK_DEFER=""
            if [ -f "$mk_sh_/sections/.manifest" ] || [ -f "$mk_sh_/.subject" ]; then
              MK_DEFER=" Where a fence names your own section file or the document assembled from it, which reads stale until assembly, write 'derivations: deferred to the join (section/subject shard)' instead."
            fi
            MK_RESTORE="fix the stale derivation(s) (validate-artifact-derivations.sh $MK_FILE names each), then mark again.$MK_DEFER"
            [ -n "${MK_NRL# }" ] || { mk_rdrop_; mark_refuse "'$MK_FILE' states 'derivations: replayed <n>' in the block this call seals (lines ${MK_RPL% *}-${MK_RPL#* }), and a fence inside it does not reproduce: $MK_ATT -- fix the stale fence (validate-artifact-derivations.sh $MK_FILE names each), replay again, then mark.$MK_DEFER"; }
            mk_rdrop_; mark_refuse "'$MK_FILE' states 'derivations: not replayed', and the replay this call ran failed: $mk_vr_ -- $MK_RESTORE"
          fi
          mk_rdrop_; mark_refuse "'$MK_FILE' states 'derivations: ${MK_NRL:+not }replayed', and the replay this call ran gave no verdict (exit $mk_vrc_): $mk_vr_ -- re-run once the fault is gone or fix the fence, then mark again."
        fi
      else
        rm -f "$MK_PRB"
      fi
    fi
    MK_TMP="${MK_FILE}.mark-tmp.$$"
    mk_drop_() { rm -f "$MK_TMP"; [ "$MK_SRC" = "$MK_FILE" ] || rm -f "$MK_SRC"; }
    seal_body "$MK_SRC" "$MK_KEEP" > "$MK_TMP" || { mk_drop_; mark_refuse "cannot write $MK_TMP."; }
    MK_SHA="$(content_hash "$MK_TMP")"
    [ -n "$MK_SHA" ] || { mk_drop_; mark_refuse "no content hash could be taken."; }
    MK_LINE="${MARK_TOKEN}${MK_F} sha=${MK_SHA}${MK_TAIL:+ }${MK_TAIL}"
    printf '%s\n' "$MK_LINE" >> "$MK_TMP" || { mk_drop_; mark_refuse "cannot write $MK_TMP."; }
    if ! has_marker "$MK_TMP"; then
      mk_drop_
      mark_refuse "the marker would not be the last line a beat accepts (the body ends inside an unclosed fence, or carries a carriage return). Close the fence first."
    fi
    seal_of "$MK_TMP" >/dev/null
    [ "$SEAL_V" = "sealed" ] || { mk_drop_; mark_refuse "the written seal does not read back as sealed."; }
    MK_EXP=""
    if [ "$MK_ROWED" = 1 ]; then
      MK_EXP="$( . "$MK_SEAL" && seal_sha "$MK_TMP" )"
      [ -n "$MK_EXP" ] || { mk_drop_; mark_refuse "no sha256 could be taken for the content seal."; }
    fi
    mv -f "$MK_TMP" "$MK_FILE" || { mk_drop_; mark_refuse "cannot replace $MK_FILE."; }
    [ "$MK_SRC" = "$MK_FILE" ] || rm -f "$MK_SRC"
    if [ "$MK_ROWED" = 1 ]; then
      MK_REC="$(bash "$MK_SEAL" --record-expect "$MK_STATE" program:wait-for-deliverable "$MK_EXP" "$MK_FILE" 2>&1)" || {
        echo "FAIL: $MK_MODE: $MK_FILE was replaced, but its bytes changed again before its content-seal row was written ($(printf '%s\n' "$MK_REC" | head -1)); no row was recorded, so every join reader refuses the file. Restore it with Edit, then mark again." >&2
        exit 64; }
    fi
    echo "MARKED $MK_FILE -- $MK_LINE"
    exit 0 ;;
esac
}

wfd_beat_main() {
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
    --dispatch-ts)
      shift
      [ $# -gt 0 ] && [ -n "$1" ] || { echo "FAIL: --dispatch-ts needs the agentId the Agent result returned." >&2; exit 64; }
      DISPATCH_TS_ONLY="${DISPATCH_TS_ONLY}${DISPATCH_TS_ONLY:+ }$1"; STATUS=1; shift ;;
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

# --dispatch-ts: THE IN-FLIGHT ROW'S `dispatched-at`, read from the dispatch's own spawn-ledger row
# (BL-605). A lead that stamps the cell from a clock stamps it AFTER the dispatch -- measured 57 s
# late on the reference consumer -- and every reader of the row inherits that. This mode resolves
# the id through the SAME dispatch_epoch_of the --dispatch beat uses, prints the row's `ts`
# verbatim, and exits 0; any id that resolves to no single ledger row is refused (64) with
# dispatch_refuse's text. It sets STATUS=1, so it takes every --status no-write path: no state
# dir, no lease, no trap. One id per call, nothing else on the line: a stamp has one answer.
if [ -n "$DISPATCH_TS_ONLY" ]; then
  case "$DISPATCH_TS_ONLY" in *' '*)
    echo "FAIL: --dispatch-ts takes exactly one id (got '$DISPATCH_TS_ONLY'); one row, one stamp." >&2; exit 64 ;; esac
  if [ -n "$TARGETS$DISPATCH$SINCE$PROGRESS_PATHS" ] || [ "$RESET$COMPLETE$SEAT_FLAG" != 000 ] || [ -n "$SHARD_AXIS" ]; then
    echo "FAIL: --dispatch-ts prints one dispatch's ledger ts and is not a beat; pass it alone." >&2; exit 64
  fi
  DISPATCH="$DISPATCH_TS_ONLY"; TARGETS="-"
fi

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
# THE MARKER ADMISSION (BL-750; content-seal.sh header "THE MARKER ADMISSION"), the sibling beside
# this script. Consulted only for a target under `planning-artifacts/`; see admit_refused.
WD_SEAL="${WD_SCRIPT_DIR}/content-seal.sh"
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

# A sidecar write whose loss costs a record, never the beat: the beat goes on, and the failure
# is said on stderr rather than folded into success.
sidecar_put() {  # $1 = file, $2 = content
  printf '%s' "$2" > "$1" 2>/dev/null || echo "WARN: wait-for-deliverable: could not write $1" >&2
}

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
#
# AND BEFORE EVERY OTHER READ, right after the state dir exists. The guards, the --dispatch
# resolution (which reads the spawn ledger and the subagents dir) and the sweep's `--shard-header`
# check (a subprocess per shard) all ran before the lease, and any of them can block: measured
# with the ledger as a FIFO, a --dispatch beat sat blocked with no marker on disk, so the hook
# saw no beat while one was armed. A call those steps refuse (exit 64) releases the lease through
# the same trap, so a refusal leaves nothing behind.
#
# THE LEASE LIVES AT THE PROJECT ROOT'S `_bmad-output`, WHATEVER AI_DLC_STATE_DIR SAYS. The stop
# hook reads `${CLAUDE_PROJECT_DIR}/_bmad-output/.beat-inflight` (ai-dlc-continue.sh:120) and
# never sees AI_DLC_STATE_DIR: every lead beat that sets one sets it as a per-command prefix, so
# the hook's environment cannot carry it. A lease written under a custom state dir was therefore
# invisible to the hook. Counters, join epochs and settle records stay in STATE_DIR; only the
# marker and the `.lease-<pid>` registrations move, together, because the heir scan must see
# every live beat's registration in the one directory the marker's holder scans -- writing the
# marker in two places instead would hand it to no heir.
# ---------------------------------------------------------------------------
# A PROCESS'S START TIME, ONE DEFINITION. The sibling wfd-start-of.sh owns it (installed beside
# this script as scripts/ai-dlc/wfd-start-of.sh); the definition under `if` is the fallback for a
# lone copy with no sibling -- every mutant core/fixtures/wait-beat-liveness builds is one -- and
# that fixture holds its whole `^wfd_start_of() {` .. `^}` range byte-identical to the helper's.
# The shell-identity markers (THE SHELL'S IDENTITY, below) store and compare this value.
#
# THE START TIME HAS A SECOND SOURCE (BL-686). `/bin/ps` is setuid root and `sandbox-exec` refuses
# to exec it, so under a sandboxed harness every marker was one field and every beat fell back to
# the clock test the identity check replaced. When `ps` prints nothing, the stock perl reads the
# same kernel field (kinfo_proc p_starttime, via sysctl KERN_PROC_PID) and prints it with
# localtime -- `ps -o lstart=` word for word under LC_ALL=C in the same zone, which is why `ps` is
# pinned to LC_ALL=C in both copies: a marker written by one source must read equal through the other.
# macOS only ($^O); elsewhere, or for a dead pid, it prints nothing and the clock test decides.
[ -f "${WD_SCRIPT_DIR}/wfd-start-of.sh" ] && . "${WD_SCRIPT_DIR}/wfd-start-of.sh" 2>/dev/null
if ! declare -F wfd_start_of >/dev/null 2>&1; then
wfd_start_of() {  # $1 = pid -> its start time, whitespace-normalised; empty when it cannot be read
  ss_="$(LC_ALL=C ps -o lstart= -p "$1" 2>/dev/null)" || ss_=""
  [ -n "$ss_" ] || ss_="$(perl -e 'exit 1 unless $^O eq "darwin" && $ARGV[0] =~ /^[1-9][0-9]*$/; my $m = pack("i4", 1, 14, 1, $ARGV[0]); my $b = "\0" x 1024; my $l = pack("Q", 1024); syscall(202, $m, 4, $b, $l, 0, 0) == 0 or exit 1; my ($s) = unpack("q", $b); exit 1 unless unpack("Q", $l) > 0 && $s > 0; print scalar localtime $s' "$1" 2>/dev/null)" || ss_=""
  printf '%s' "$ss_" | tr -s ' \t' ' ' | sed 's/^ //; s/ $//'
}
fi

# THE LEASE'S HOLDER IS THIS BEAT'S PID. Run as a program that is $$. A fixture that sources this
# file and runs wfd_beat_main in a background subshell sets WFD_SELF_PID to that subshell's pid,
# which $$ (the sourcing shell's pid) cannot report; unset, it is exactly $$.
WD_SELF_PID="${WFD_SELF_PID:-$$}"
LEASE_HOME="${WD_ROOT}/_bmad-output"
LEASE_DIR="${LEASE_HOME}/.wait-beats"
[ "$STATUS" -eq 1 ] || mkdir -p "$LEASE_DIR" 2>/dev/null || true
BEAT_MARKER="${LEASE_HOME}/.beat-inflight"
LEASE_SELF="${LEASE_DIR}/.lease-$WD_SELF_PID"
lease_holder_dead() {  # $1 = holder pid -> 0 when no live beat stands behind it
  ld_r_="$(cat "${LEASE_DIR}/.lease-$1" 2>/dev/null || echo '')"
  case "$ld_r_" in ''|*[!0-9]*) return 0 ;; esac
  [ "$ld_r_" -gt "$(date +%s)" ] || return 0
  kill -0 "$1" 2>/dev/null && return 1
  return 0
}
LEASE_TMP="${LEASE_DIR}/.beat-inflight.$WD_SELF_PID"   # inside the ignored .wait-beats/, same filesystem
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
  case "$ba_ep_" in ''|*[!0-9]*) lease_put "$ba_e_" "$WD_SELF_PID"; return 0 ;; esac
  case "$ba_pid_" in *[!0-9]*) lease_put "$ba_e_" "$WD_SELF_PID"; return 0 ;; esac
  if [ "$ba_ep_" -le "$(date +%s)" ]; then lease_put "$ba_e_" "$WD_SELF_PID"; return 0; fi
  [ -n "$ba_pid_" ] || return 0                     # a live pre-upgrade lease: not ours to take
  if [ "$ba_pid_" = "$WD_SELF_PID" ] || lease_holder_dead "$ba_pid_"; then lease_put "$ba_e_" "$WD_SELF_PID"; fi
  return 0
}
lease_release() {
  lr_cur_="$(cat "$BEAT_MARKER" 2>/dev/null || echo '')"
  case "$lr_cur_" in *' '*) lr_pid_="${lr_cur_#* }" ;; *) lr_pid_="" ;; esac
  if [ "$lr_pid_" = "$WD_SELF_PID" ]; then
    lr_now_="$(date +%s)"; lr_heir_=""
    for lr_f_ in "$LEASE_DIR"/.lease-*; do
      [ -f "$lr_f_" ] || continue
      lr_p_="${lr_f_##*/.lease-}"
      [ "$lr_p_" = "$WD_SELF_PID" ] && continue
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

# --status writes nothing (header: "--status"), so it neither takes the lease nor arms the trap.
if [ "$STATUS" -eq 0 ]; then
trap 'lease_release' EXIT
beat_alive
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
  # THE SEAL DECIDES, WITH NO WINDOW (header: "--mark"). A sealed marker delivers now; a broken
  # one is UNFINISHED at any age until the seat re-marks. Only a legacy marker reaches SETTLE.
  # THE MARKER ADMISSION (BL-750) runs on the sealed and the legacy marker, never the broken one,
  # which keeps its own line: inside content-seal's sealed set a bare marker outside the legacy
  # window, or a sealed one whose file differs from its seal row, is UNFINISHED and opens no settle record.
  seal_of "$1"; id_sv_=$?
  if [ "$id_sv_" -eq 1 ] || admit_refused "$1"; then id_sv_=1; fi
  if [ "$id_sv_" -ne 2 ]; then
    rm -f "$id_st_" 2>/dev/null; settle_memo "$id_st_" ""
    return "$id_sv_"
  fi
  settled "$1" "$id_st_"
}

# has_marker, content_hash, seal_body and seal_of are defined above the flag loop, beside
# --mark, which runs before anything below. The token as the report lines name it:
# `seat-complete:` byte-identical to every earlier release, or `repair-complete: serial`.
MARK_NAME="${MARK_TOKEN% }"

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

# THE MARKER ADMISSION (BL-750): 0 when content-seal.sh --admit-marker REFUSES $1's marker, with
# AD_MSG set to its line; 1 when it admits it. Only a target under `planning-artifacts/` is asked,
# because the sealed set lives there and nothing outside it is ever refused. A missing sibling, or any
# exit but 0 and 1, refuses: a check that could not run never acquits. Memoised per process on the
# content hash, as header_refused is.
admit_refused() {  # $1 = path
  ar_p_="$(cd "$(dirname "$1")" 2>/dev/null && pwd)/$(basename "$1")"
  case "$ar_p_" in */planning-artifacts/*) ;; *) AD_MSG=""; return 1 ;; esac
  ar_h_="$(content_hash "$1")"; ar_k_="$(key_of "$1")"
  eval "ar_mh_=\${ADH_${ar_k_}:-}"
  if [ -n "$ar_h_" ] && [ "$ar_mh_" = "$ar_h_" ]; then
    eval "AD_MSG=\${ADM_${ar_k_}:-}"
    [ -n "$AD_MSG" ]; return
  fi
  if [ ! -f "$WD_SEAL" ]; then
    AD_MSG="no marker admission ran: content-seal.sh is missing beside this script ($WD_SEAL); reinstall ai-dlc"
  else
    ar_o_="$(bash "$WD_SEAL" --admit-marker "$1" 2>&1)"; ar_rc_=$?
    ar_o_="$(printf '%s' "$ar_o_" | tr '\n' ' ')"; ar_o_="${ar_o_% }"
    case "$ar_rc_" in
      0) AD_MSG="" ;;
      1) AD_MSG="${ar_o_:-the marker admission exited 1 and printed nothing}" ;;
      *) AD_MSG="the marker admission could not run (exit $ar_rc_): ${ar_o_:-no output}" ;;
    esac
  fi
  if [ -n "$ar_h_" ]; then eval "ADH_${ar_k_}=\$ar_h_; ADM_${ar_k_}=\$AD_MSG"; fi
  [ -n "$AD_MSG" ]
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
# A BROKEN SEAL: present, written since the join armed, marked with `sha=`, and changed since.
# Its own function, so is_unfinished above keeps the unmarked case alone.
is_seal_broken() {  # $1 = path, $2 = join epoch
  [ "$COMPLETE" -eq 1 ] && [ -s "$1" ] && [ "$(mtime_of "$1")" -ge "$2" ] && has_marker "$1" \
    && ! { [ -n "$SHARD_AXIS" ] && header_refused "$1"; } && { seal_of "$1"; [ $? -eq 1 ]; }
}
say_seal_broken() {  # $1 = path. The one emitter of this line, at every site.
  echo "UNFINISHED $1 -- its ${MARK_NAME} line carries sha= but the file changed after it was marked; re-mark with --mark"
}
# A REFUSED MARKER (BL-750): present, written since the join armed, marked, header passing, seal not
# broken, and its marker refused by the admission.
is_admit_refused() {  # $1 = path, $2 = join epoch; sets AD_MSG
  [ "$COMPLETE" -eq 1 ] && [ -s "$1" ] && [ "$(mtime_of "$1")" -ge "$2" ] && has_marker "$1" \
    && ! { [ -n "$SHARD_AXIS" ] && header_refused "$1"; } && { seal_of "$1"; [ $? -ne 1 ]; } && admit_refused "$1"
}
say_admit_refused() {  # $1 = path; reads AD_MSG. The one emitter of this line, at every site.
  echo "UNFINISHED $1 -- ends in ${MARK_NAME} but its marker is not admitted: $AD_MSG"
}
say_unfinished() {  # $1 = path, $2 = join epoch -- the line beneath a WAITING line
  is_unfinished "$1" "$2" && echo "UNFINISHED $1 -- present, last non-blank line is not ${MARK_NAME}"
  is_header_unfinished "$1" "$2" && say_header_unfinished "$1"
  is_seal_broken "$1" "$2" && say_seal_broken "$1"
  is_admit_refused "$1" "$2" && say_admit_refused "$1"
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
# THE TEAMMATE LIVENESS SENSOR. Why this signal exists, why its session-wide reading
# changes no decision while a dispatch-scoped one may extend a --complete-repair wait
# (dispatch_live), which direction it errs in and where its threshold came from are all
# in the header ("SLOW AND NEVER LOOK THE SAME"). This is only the implementation.
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
# re-dispatch anything. (The one reading that does decide is dispatch_live's, keyed on
# BUDGET and on a single dispatched agent's own transcript -- not on this threshold.) LOAD: the outcome (one extra line) does not depend on load, but the
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
#   toolu_<...>      the ledger row whose `tool_use_id` is it. Any DISPATCH_ID_PREFIXES member
#   call_<...>       (read from the sibling validator, below) is taken the same way.
#   <name>@<team>    a named teammate: the ONE ledger row whose `name` is <name>. Its
#                    meta.json carries no toolUseId, so the name is the only key.
#   <hex agentId>    this session's `agent-<id>.meta.json` gives `toolUseId`, which is the
#                    ledger `tool_use_id` (ai-dlc-dispatch-guard.sh, measured 4 of 4)
# Each step that finds nothing, or more than one row, REFUSES: a guessed dispatch time is
# the defect this exists to remove. Keyed on the dispatch's own id because a deliverable
# path is not one: the reference ledger records a path on 14 of 5153 rows, none current.
# --dispatch REPEATS for a beat that joins several dispatches (a fan-out round): --since is
# checked against the EARLIEST, and without --since the join starts there.
# A --since without --dispatch still runs; refusing it would break every caller written before
# the flag. It WARNs on stderr once per invocation, only on a beat that ARMS a target (the
# first beat, --reset, a wave adding a target, a target delivered on its arming beat): a
# continuation beat and --status stay silent.
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
  case "$dp_id_" in *[!A-Za-z0-9_@.-]*) dispatch_refuse "not an agentId, a <name>@<team> or a dispatch id (prefixes: $DP_PREFIXES)" \
    "Pass the agentId the Agent result returned." ;; esac
  dp_hit_=0
  for dp_p_ in $DP_PREFIXES; do case "$dp_id_" in "$dp_p_"?*) dp_hit_=1 ;; esac; done
  case "$dp_hit_:$dp_id_" in
    1:*) dp_tui_="$dp_id_" ;;
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
# THE DISPATCH-ID PREFIXES ARE READ FROM THEIR ONE DECLARATION, never retyped here: the sibling
# validate-adversarial-convergence.sh declares `DISPATCH_ID_PREFIXES="toolu_ call_"`, and an id
# opening with any member is a tool_use_id (`call_` is a local-model lead's). Resolved beside this
# script, as --shard-header resolves its sibling. The value may be double- or single-quoted; it
# must be declared exactly once, and every member must be word characters. Under --dispatch, a
# missing sibling or a missing, duplicated or malformed declaration REFUSES (exit 64): a silent
# `toolu_`-only fallback would refuse a local-model lead's ids while reading as a working grammar.
DISPATCH_GRAMMAR="${WD_SCRIPT_DIR}/validate-adversarial-convergence.sh"
dispatch_prefixes() {  # prints the declared prefix list; 1 when it cannot be read as one
  [ -f "$DISPATCH_GRAMMAR" ] || return 1
  dg_h_="$(grep -E "^DISPATCH_ID_PREFIXES=(\"[^\"]*\"|'[^']*')[[:blank:]]*\$" "$DISPATCH_GRAMMAR" 2>/dev/null)" || return 1
  [ "$(grep -c '^DISPATCH_ID_PREFIXES=' "$DISPATCH_GRAMMAR" 2>/dev/null)" = 1 ] || return 1
  dg_v_="${dg_h_#DISPATCH_ID_PREFIXES=}"
  dg_v_="$(printf '%s' "$dg_v_" | sed 's/[[:blank:]]*$//')"   # trailing blanks after the quote
  dg_v_="${dg_v_#?}"; dg_v_="${dg_v_%?}"                       # the quote pair
  case "$dg_v_" in *[!A-Za-z0-9_\ ]*) return 1 ;; esac
  [ -n "${dg_v_// /}" ] || return 1
  printf '%s' "$dg_v_"
}
if [ -n "$DISPATCH" ]; then
  DP_PREFIXES="$(dispatch_prefixes)" || {
    echo "FAIL: --dispatch cannot read its id grammar: DISPATCH_ID_PREFIXES is not declared exactly once," >&2
    echo "  quoted and word-only, in $DISPATCH_GRAMMAR (or that file is absent beside this script)." >&2
    echo "  No dispatch id can be classified, so NO beat ran and the join is NOT armed." >&2
    exit 64; }
  DISPATCH_EPOCH=""; DISPATCH_TS=""; DISPATCH_TUI=""
  # An id is validated inside the loop, after this split, so no glob may expand first: noglob is
  # on for the SPLIT ALONE and restored before anything else runs. Left on, it silenced every glob
  # below -- the teammate-transcript scan read `unavailable` and the EXIT trap's lease-heir scan
  # found no heir -- on every --dispatch beat. Restored before the loop, not after it, because
  # dispatch_refuse exits from inside the loop, and any EXIT trap armed by then globs too.
  dp_noglob_=0; case "$-" in *f*) dp_noglob_=1 ;; esac
  set -f
  DP_IDS_=( $DISPATCH )
  [ "$dp_noglob_" = 1 ] || set +f
  # The liveness scope (in_liveness_scope): each dispatch's agentId, found as the subagents-dir
  # meta.json whose toolUseId is the dispatch's tool_use_id. If ANY dispatch has none, the scope
  # stays the whole session -- a partial scope would drop the one transcript that matters.
  DP_AGENTS_=""; dp_scope_ok_=1
  for dp_one_ in "${DP_IDS_[@]}"; do
    dispatch_epoch_of "$dp_one_"
    if [ -z "$DISPATCH_EPOCH" ] || [ "$dp_e_" -lt "$DISPATCH_EPOCH" ]; then
      DISPATCH_EPOCH="$dp_e_"; DISPATCH_TS="$dp_ts_"; DISPATCH_TUI="$dp_tui_"
    fi
    dp_ag_=""
    if [ -n "$TEAMMATE_DIR" ] && [ -d "$TEAMMATE_DIR" ]; then
      for dp_mf_ in "$TEAMMATE_DIR"/agent-*.meta.json; do
        [ -f "$dp_mf_" ] || continue
        grep -qF "\"toolUseId\":\"$dp_tui_\"" "$dp_mf_" 2>/dev/null || continue
        dp_ag_="${dp_mf_##*/agent-}"; dp_ag_="${dp_ag_%.meta.json}"; break
      done
    fi
    if [ -n "$dp_ag_" ]; then DP_AGENTS_="${DP_AGENTS_}${DP_AGENTS_:+ }$dp_ag_"; else dp_scope_ok_=0; fi
  done
  [ "$dp_scope_ok_" = 1 ] || DP_AGENTS_=""
  if [ -n "$SINCE" ] && [ "$SINCE" -gt "$DISPATCH_EPOCH" ]; then
    echo "FAIL: --since is $(( SINCE - DISPATCH_EPOCH )) s after the earliest dispatch it joins ($DISPATCH_TS, tool_use_id $DISPATCH_TUI)." >&2
    echo "  Every write the teammate made in between would read as pre-existing. Drop --since;" >&2
    echo "  --dispatch alone sets the join to the dispatch." >&2
    exit 64
  fi
  [ -n "$SINCE" ] || SINCE="$DISPATCH_EPOCH"
  if [ -n "$DISPATCH_TS_ONLY" ]; then printf '%s\n' "$DISPATCH_TS"; exit 0; fi
fi
SINCE_WARNED=0

# ---------------------------------------------------------------------------
# A TURN IS AN ASSISTANT OR USER (TOOL-RESULT) LINE, NOT A WRITE TO THE FILE. The harness also
# appends an `api-request` line for every request it SENDS, answered or not, so a teammate whose
# requests the model never answers -- measured on the reference consumer: an account out of
# usage, seven retries ~195s apart, no assistant line after them -- kept its transcript's mtime
# fresh and read as a live turn every ~3 minutes, for as long as anyone waited. Quiet is now
# `now` minus the NEWEST timestamp on an assistant/user line (the maximum, never the last line's:
# timestamps are not monotonic in a transcript), and a transcript with no such timestamp falls
# back to its mtime, which is exactly the old reading.
#
# STALL_K (3) BOUNDS ONE PROPERTY: HOW MANY CONSECUTIVE `{"type":"api-request"` LINES MUST END A
# TRANSCRIPT BEFORE THE BEAT SAYS ITS MODEL IS NOT ANSWERING. Measured over 3,349 real teammate
# transcripts: runs of api-request lines between two assistant lines were 1 long 7,400 times, 2
# long 7 times (all live: a reply followed in 3-108s), 4 long once and 8 long once (the wedge).
# So 3 has no false positive in that corpus. The match carries its closing quote, because
# `api-request-blob` and `api-request-shape` lines open the same way and are not requests.
# WHEN HIT: a STALLED report, per transcript. Like IDLE it changes no exit code, beat count or
# grant -- it tells the lead to tell the operator. LOAD-FREE: a count of lines, not of seconds.
# ---------------------------------------------------------------------------
STALL_K=3
transcript_turn() {  # $1 = transcript -> "<newest turn YYYY-MM-DDTHH:MM:SS|-> <trailing api-request run>"
  awk '
    index($0, "{\"type\":\"api-request\"") == 1 { run++; next }
    NF { run = 0 }
    index($0, "\"type\":\"assistant\"") || index($0, "\"type\":\"user\"") {
      if (match($0, /"timestamp":"[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]T[0-9][0-9]:[0-9][0-9]:[0-9][0-9]/)) {
        t = substr($0, RSTART + 13, 19); if (t > mx) mx = t
      }
    }
    END { print (mx == "" ? "-" : mx), run + 0 }' "$1" 2>/dev/null
}
# Under --dispatch the sensor reads ONLY the dispatched agents' own transcripts, by name: across a
# session the newest turn of ANY teammate would let a live one hide the wedged one being joined.
in_liveness_scope() {  # $1 = transcript path -> 0 when it is read
  [ -n "${DP_AGENTS_:-}" ] || return 0
  for il_a_ in $DP_AGENTS_; do [ "${1##*/}" = "agent-${il_a_}.jsonl" ] && return 0; done
  return 1
}
teammate_quiet_for() {  # prints seconds since the most recent teammate turn in this session,
                        # then ` STALLED <file>...` for each transcript ending in a stalled run;
                        # returns 1 and prints nothing when there is no signal
  [ -n "$TEAMMATE_DIR" ] && [ -d "$TEAMMATE_DIR" ] || return 1
  tq_now_="$(date +%s)"; tq_best_=""; tq_stall_=""
  for tq_f_ in "$TEAMMATE_DIR"/*.jsonl; do
    [ -f "$tq_f_" ] || continue
    in_liveness_scope "$tq_f_" || continue
    tq_r_="$(transcript_turn "$tq_f_")"
    tq_t_="${tq_r_%% *}"; tq_k_="${tq_r_##* }"
    case "$tq_k_" in ''|*[!0-9]*) tq_k_=0 ;; esac
    tq_m_=""; [ "$tq_t_" = "-" ] || tq_m_="$(to_epoch "${tq_t_}Z")" || tq_m_=""
    [ -n "$tq_m_" ] || tq_m_="$(mtime_of "$tq_f_")"
    [ "$tq_m_" -gt 0 ] || continue
    tq_a_=$(( tq_now_ - tq_m_ ))
    [ "$tq_a_" -lt 0 ] && tq_a_=0   # clock skew must not manufacture a future turn
    [ "$tq_k_" -ge "$STALL_K" ] && tq_stall_="${tq_stall_} ${tq_f_##*/}:${tq_k_}"
    if [ -z "$tq_best_" ] || [ "$tq_a_" -lt "$tq_best_" ]; then tq_best_="$tq_a_"; fi
  done
  [ -n "$tq_best_" ] || return 1
  printf '%s%s' "$tq_best_" "${tq_stall_:+ STALLED$tq_stall_}"
}

# THE DISPATCH-SCOPED READING, AND THE ONE PLACE LIVENESS DECIDES ANYTHING (header: "IT CHANGES
# NO DECISION", which states the split). Scope: ONE target and ONE resolved agent, in any mode
# -- DP_AGENTS_ is already empty when any dispatch failed to resolve, or when there is no
# --dispatch, which is the session-wide case and decides nothing -- whose own
# `agent-<id>.jsonl` exists and does not end in a stalled run. Inside that scope THREE answers,
# by the age of that transcript's newest turn:
#   0  LIVE     younger than one quantum (BUDGET)        -- replaces the remedy; grants ONLY under
#                                                            --complete-repair (the caller gates it)
#   2  RECENT   BUDGET or older, younger than IDLE_SECS  -- NO grant, but replaces the remedy
#   3  STOPPED  IDLE_SECS or older                       -- NO grant; with the path absent, the
#                                                            STOPPED line replaces the remedy
#   1  out of scope, or stalled                          -- the bare remedy, as before
# The age is read exactly as teammate_quiet_for reads it (transcript_turn, the epoch, the mtime
# fallback, the skew clamp); this is not a second parser. Sets DL_AGENT and DL_AGE for the lines
# that name it.
#
# TWO BANDS, BECAUSE THE TWO DECISIONS FAIL IN OPPOSITE DIRECTIONS. A grant extends the wait, so
# it asks the strict question -- did the teammate take a turn inside the beat that just ran? --
# and stays counted, so it can never make the wait unbounded. The remedy is a different decision:
# a remediator inside one long tool call takes no turn for longer than a quantum (13 of 57,050
# live appends, see "THE THRESHOLD IS MEASURED") and is STILL A WRITER on its record, so a bare
# re-dispatch then starts a second one. That collision is judged on consequence, not frequency:
# up to IDLE_SECS -- the measured point where silence starts to mean "finished elsewhere" -- the
# cap prints the liveness-check block instead, and still exits 1, so the wait stays bounded.
DL_AGENT=""; DL_AGE=""
dispatch_live() {
  DL_AGENT=""; DL_AGE=""
  dl_a_="${DP_AGENTS_:-}"
  case "$dl_a_" in ''|*' '*) return 1 ;; esac
  case "$TARGETS" in *'|'*) return 1 ;; esac
  [ -n "$TEAMMATE_DIR" ] || return 1
  dl_f_="$TEAMMATE_DIR/agent-${dl_a_}.jsonl"
  [ -f "$dl_f_" ] || return 1
  dl_r_="$(transcript_turn "$dl_f_")"
  dl_t_="${dl_r_%% *}"; dl_k_="${dl_r_##* }"
  case "$dl_k_" in ''|*[!0-9]*) dl_k_=0 ;; esac
  [ "$dl_k_" -lt "$STALL_K" ] || return 1
  dl_m_=""; [ "$dl_t_" = "-" ] || dl_m_="$(to_epoch "${dl_t_}Z")" || dl_m_=""
  [ -n "$dl_m_" ] || dl_m_="$(mtime_of "$dl_f_")"
  [ "$dl_m_" -gt 0 ] || return 1
  dl_g_=$(( $(date +%s) - dl_m_ ))
  [ "$dl_g_" -lt 0 ] && dl_g_=0
  # LIVE is decided first and on BUDGET alone, so an IDLE_SECS retuned below BUDGET can only
  # narrow the RECENT band, never take away a grant.
  DL_AGENT="$dl_a_"; DL_AGE="$dl_g_"
  if [ "$dl_g_" -lt "$BUDGET" ]; then return 0; fi
  [ "$dl_g_" -lt "$IDLE_SECS" ] || return 3
  return 2
}

# ONE function, called from all THREE places a beat can end -- the exhaustion path,
# the chained-sibling path and the post-sleep report. A lead that reads only one of
# them has to get the same three-way answer, and three copies of this ladder would
# be three chances for one of them to stop agreeing.
say_liveness() {
  if ! sl_r_="$(teammate_quiet_for)"; then
    say "LIVENESS  unavailable (no teammate transcripts for this session) -- this beat"
    say "  cannot tell a working teammate from one that finished and delivered elsewhere."
    return 0
  fi
  sl_q_="${sl_r_%% *}"; sl_st_=""
  case "$sl_r_" in *' STALLED '*) sl_st_="${sl_r_#* STALLED }" ;; esac
  # echo, not say, for the reason the IDLE banner below gives: the wait itself is the wrong action.
  for sl_s_ in $sl_st_; do
    echo "TEAMMATE STALLED ${sl_s_%:*} -- its transcript ends in ${sl_s_##*:} api-request lines with no reply"
    echo "  after them: the model is not answering this teammate (account usage limit, auth or network),"
    echo "  and it is not thinking. Beating again cannot fix that. Tell the operator now: only the"
    echo "  operator can switch accounts, and a re-dispatch on the same account wedges again. Stop the"
    echo "  teammate only on the operator's word, or when the next beat reports it STALLED again."
  done
  case "$sl_q_" in ''|*[!0-9]*) sl_q_=0 ;; esac
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
    elif seal_of "$t"; [ "$SEAL_V" = "broken" ]; then
      S_V="UNFINISHED"; say_seal_broken "$t"
    elif admit_refused "$t"; then
      S_V="UNFINISHED"; say_admit_refused "$t"
    elif seal_of "$t"; then
      S_V="DELIVERED"; echo "DELIVERED $t"
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
#
# A MARKER WHOSE SHELL IS STILL THE SAME PROCESS IS KEPT AT ANY AGE (see THE SHELL'S IDENTITY
# below): its age no longer decides anything, and pruning it would let a chained call delayed
# past the prune age sleep a second quantum. Identity is the pid in the name plus the start time
# stored in the marker; a recycled pid has a different start time and is pruned on age as before.
# The start time is wfd_start_of, defined above the lease (A PROCESS'S START TIME).
SH_PRUNE_SECS=$(( ( (BUDGET / 60) + 1 ) * 60 ))
for sh_f_ in "$COUNTER_DIR"/.shell-*; do
  [ -f "$sh_f_" ] || continue
  sh_r_="$(cat "$sh_f_" 2>/dev/null || echo '')"
  case "$sh_r_" in
    *' '*) [ "${sh_r_#* }" = "$(wfd_start_of "${sh_f_##*/.shell-}")" ] && continue ;;
  esac
  [ $(( $(date +%s) - $(mtime_of "$sh_f_") )) -gt "$SH_PRUNE_SECS" ] && rm -f "$sh_f_" 2>/dev/null
done

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
#
# THE SHELL'S IDENTITY DECIDES IT NOW, AND THE CLOCK ONLY FOR A MARKER THAT CARRIES NONE. The
# marker is `<stamp> <start time of $PPID>`. A sibling beat in the SAME process -- same pid, same
# start time -- is a chained call at any age, so load can no longer push it past the window. A
# different start time is a recycled pid, a different shell, and sleeps. A one-field marker
# (a beat from before this release, mid-pull) and a box where `ps` cannot read the start time
# both keep the `-lt "$BUDGET"` test above. MEASURED: two calls from one shell read the same
# start time, and the harness starts a fresh shell for every Bash tool call (two calls, two
# parent pids), so "same shell" is "same Bash call" there. A harness that ran every call in ONE
# persistent shell would make every beat after the first read as chained; none does today.
SIBLING="${COUNTER_DIR}/.shell-${PPID}"
SHELL_START="$(wfd_start_of "$PPID")"
# NEITHER SOURCE COULD READ IT (BL-686): `ps` refused or empty, and no perl. Said once per beat, on
# stderr, because the guard below then decides by the clock alone and a reader must know that.
[ -n "$SHELL_START" ] || printf 'NOTE: start time of shell %s unreadable (ps refused or printed nothing, and no perl fallback) -- the chained-beat guard decides by the clock alone this beat\n' "$PPID" >&2
MAY_SLEEP=1
if [ -f "$SIBLING" ]; then
  LAST_REC="$(cat "$SIBLING" 2>/dev/null || echo 0)"
  LAST="${LAST_REC%% *}"
  case "$LAST" in ''|*[!0-9]*) LAST=0 ;; esac
  LAST_START=""; case "$LAST_REC" in *' '*) LAST_START="${LAST_REC#* }" ;; esac
  if [ -n "$LAST_START" ] && [ -n "$SHELL_START" ]; then
    [ "$LAST_START" = "$SHELL_START" ] && MAY_SLEEP=0
  elif [ $(( $(date +%s) - LAST )) -lt "$BUDGET" ]; then
    MAY_SLEEP=0
  fi
fi
printf '%s%s' "$(date +%s)" "${SHELL_START:+ $SHELL_START}" > "$SIBLING" 2>/dev/null

# ---------------------------------------------------------------------------
# Reset / already-delivered sweep, and the sequence bound. Done for every path
# BEFORE any sleeping: an exhausted sequence must not buy one more blind window.
# ---------------------------------------------------------------------------
PENDING=""
EXHAUSTED=""
PREEXISTING=""
GRANTED=""
GRANTSPENT=""
# dispatch_live's verdict, taken once in the exhaustion arm (the only place it decides anything)
# and read again by the final print, so an awk over a long transcript runs at most once per beat:
# 0 none, 1 LIVE, 2 RECENT, 3 STOPPED. DL_GRANT is 1 when the transcript alone bought this beat's grant.
DISPATCH_LIVE=0
DL_GRANT=0
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
  if [ "$FIRST" -eq 1 ] && [ -n "$SINCE" ] && [ -z "$DISPATCH" ] && [ "$SINCE_WARNED" -eq 0 ]; then
    SINCE_WARNED=1
    echo "WARN: wait-for-deliverable: --since without --dispatch -- nothing checks the stamp against the dispatch, and a stamp later than it misses the teammate's early writes. Pass --dispatch <agentId from the Agent result>." >&2
  fi
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
    # --complete-repair: the record is appended only at the end, so the target cannot grow and
    # its own mark never grants. The dispatched agent's own transcript is that wait's evidence of
    # work (dispatch_live), read here and nowhere else. A pure read, so a chained sibling and a
    # fresh arm after the cap get the same answer as a sleeping beat.
    # LIVE (0) replaces the remedy, and grants only under --complete-repair; RECENT (2) and
    # STOPPED (3) never grant (dispatch_live). Only the GRANT is gated on the mode: any resolved
    # --dispatch gets the remedy its own transcript supports (BL-721).
    # DL_GRANT marks a grant the transcript alone bought, so its PROGRESS line names the transcript.
    dispatch_live; dl_v_=$?
    case "$dl_v_" in
      0) DISPATCH_LIVE=1
         if [ "$COMPLETE_REPAIR" -eq 1 ]; then [ "$PROGRESSED" -eq 1 ] || DL_GRANT=1; PROGRESSED=1; fi ;;
      2) DISPATCH_LIVE=2 ;;
      3) DISPATCH_LIVE=3 ;;
    esac

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
    if [ "$DL_GRANT" -eq 1 ]; then
      echo "PROGRESS  ${e#* } -- work observed in agent-${DL_AGENT}.jsonl, this dispatch's own transcript; sequence"
    else
      echo "PROGRESS  ${e#* } -- work observed under the progress path; sequence"
    fi
    echo "  extended by one beat (grant ${e%% *}). The teammate is demonstrably"
    echo "  working, so this is NOT Rule 20 non-delivery. Do NOT re-dispatch; beat again."
  done; IFS="$OLDIFS"
fi

if [ -n "$EXHAUSTED" ]; then
  # Which kinds this exhaustion holds. The bare Rule 20 remedy belongs to a target that is truly
  # ABSENT (or to a wait without --complete, where every exhausted target reads absent): under
  # --complete a present file is a seat's or remediator's work, and the paragraphs below say read it.
  EX_ABSENT=0; EX_UNCHANGED=0
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
    elif is_seal_broken "$t" "$(join_of "$t")"; then
      echo "NON-DELIVERY $t -- after $MAX_BEATS beats."
      say_seal_broken "$t"
    elif is_admit_refused "$t" "$(join_of "$t")"; then
      echo "NON-DELIVERY $t -- after $MAX_BEATS beats."
      say_admit_refused "$t"
    elif [ "$COMPLETE" -eq 1 ] && [ -s "$t" ] && [ "$(mtime_of "$t")" -ge "$(join_of "$t")" ] && has_marker "$t"; then
      echo "NON-DELIVERY $t -- after $MAX_BEATS beats."
      echo "UNSETTLED $t -- present and ends in ${MARK_NAME}, but its content was still changing"
    elif [ "$COMPLETE" -eq 1 ] && [ -s "$t" ] && [ "$(mtime_of "$t")" -lt "$(join_of "$t")" ]; then
      # Present, non-empty, and last written BEFORE the join armed. The mtime test is stated, not
      # inferred from the branches above: a post-join file that reached here is a defect in those
      # branches, and it must keep reading 'absent' so the arm that guards them can see it. A
      # serial remediator appends to its record only at the end, so a record mid-pass is exactly
      # this file. It is not absent, and calling it absent printed a re-dispatch over a teammate
      # still running.
      EX_UNCHANGED=1
      echo "NON-DELIVERY $t -- after $MAX_BEATS beats."
      echo "UNCHANGED $t -- present ($(awk 'END { print NR }' "$t" 2>/dev/null) lines), not modified since the join"
    else
      EX_ABSENT=1
      echo "NON-DELIVERY $t -- absent after $MAX_BEATS beats."
    fi
    IFS='|'
  done; IFS="$OLDIFS"
  if [ "$COMPLETE" -eq 1 ]; then
    echo "  UNFINISHED or UNSETTLED is NOT absence: the seat wrote a file. Read it before you"
    echo "  decide -- its findings are real whether or not it closed them, and a re-dispatch"
    echo "  over it discards them. Only a path reported 'absent' is Rule 20 non-delivery."
    if [ "$EX_UNCHANGED" -eq 1 ]; then
      echo "  UNCHANGED is NOT absence either: the file is on disk and was not written during this"
      echo "  join. A record appended only at the end looks exactly like this while its writer is"
      echo "  still working. Read it and the teammate's own last turns before you decide."
    fi
  fi
  # The NOTE's "Decide: re-dispatch" contradicts the LIVE/RECENT block, so those two suppress it;
  # STOPPED does not, because the transcript then says nothing about the progress path's writes.
  if [ -n "$GRANTSPENT" ] && { [ "$DISPATCH_LIVE" -eq 0 ] || [ "$DISPATCH_LIVE" -eq 3 ]; }; then
    IFS='|'; for t in $GRANTSPENT; do
      echo "  NOTE: $t still shows work under the progress path, but all $MAX_BEATS"
      echo "  progress grants are spent. The bound is deliberate -- a teammate that"
      echo "  keeps writing without delivering is a hang, and Rule 29 Check C says a"
      echo "  wait must end. Decide: re-dispatch, or --reset if you have read the"
      echo "  worktree and judged it genuinely close."
    done; IFS="$OLDIFS"
  fi
  if [ "$DISPATCH_LIVE" -eq 1 ] || [ "$DISPATCH_LIVE" -eq 2 ]; then
    # THIS dispatch's own transcript is LIVE with the grants spent (or, without --complete-repair,
    # with no grant to give), or RECENT (no turn this beat, so no grant, but younger than
    # IDLE_SECS -- one long tool call looks exactly like this): a bare re-dispatch would start a
    # second writer on the record the first may still be writing.
    # echo, not say, for the reason the PROGRESS line gives: --quiet must not hide what not to do.
    echo "  LIVE DISPATCH agent-${DL_AGENT} -- its own transcript took a turn ${DL_AGE}s ago:"
    echo "    ${TEAMMATE_DIR}/agent-${DL_AGENT}.jsonl"
    if [ "$DISPATCH_LIVE" -eq 1 ] && [ "$COMPLETE_REPAIR" -eq 1 ]; then
      echo "  That teammate is still writing, and all $MAX_BEATS grants are spent. A re-dispatch now"
    elif [ "$DISPATCH_LIVE" -eq 1 ]; then
      echo "  That teammate is still working, and a turn in its transcript buys no grant outside"
      echo "  --complete-repair: a writer whose work has no file at the joined path (an inline"
      echo "  changelog append) never makes it appear. A re-dispatch now"
    else
      echo "  No turn inside the last beat, so no grant; but a teammate inside one long tool call is"
      echo "  silent exactly like this and is still a writer on its record. A re-dispatch now"
    fi
    if [ "$COMPLETE_REPAIR" -eq 1 ]; then
      echo "  would put two writers on one record. Read that teammate's last turns, then either"
    else
      echo "  would put two writers on one piece of work. Read that teammate's last turns, then either"
    fi
    echo "  re-run with --reset and beat again, or STOP that teammate first and only then"
    echo "  re-dispatch it ONCE (then re-run with --reset); if it fails again, HARD_BLOCK."
  elif [ "$DISPATCH_LIVE" -eq 3 ] && [ "$EX_ABSENT" -eq 1 ]; then
    # THIS dispatch's own transcript has been silent past IDLE_SECS and the path is absent. A
    # writer with no deliverable file finishes without ever writing the joined path, so this is
    # the shape of a teammate that FINISHED as much as of one that failed -- and only its last
    # message tells them apart. A bare re-dispatch over a finished writer repeats its work.
    echo "  STOPPED DISPATCH agent-${DL_AGENT} -- its own transcript last took a turn ${DL_AGE}s ago:"
    echo "    ${TEAMMATE_DIR}/agent-${DL_AGENT}.jsonl"
    if [ "$COMPLETE_REPAIR" -eq 1 ]; then
      echo "  A finished teammate leaves a silent transcript, and the path may be absent because it"
      echo "  wrote its work elsewhere, so an absent path and a silent transcript are what a FINISHED"
      echo "  teammate looks like too. Read that transcript's"
    else
      echo "  A writer with no deliverable file finishes without writing one, so an absent path and a"
      echo "  silent transcript are what a FINISHED teammate looks like too. Read that transcript's"
    fi
    echo "  last message before any re-dispatch: if it reports the work done, verify the work where"
    echo "  it says it wrote it; only if it did not finish, re-dispatch ONCE (then re-run with"
    echo "  --reset), and if it fails again, HARD_BLOCK."
  elif [ "$COMPLETE" -eq 0 ] || [ "$EX_ABSENT" -eq 1 ]; then
    echo "  Rule 20 defines an absent deliverable as non-delivery. Re-dispatch the"
    echo "  teammate ONCE (then re-run with --reset), and if it fails again, HARD_BLOCK."
  fi
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
}
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
wfd_mark_main "$@"
wfd_beat_main "$@"
