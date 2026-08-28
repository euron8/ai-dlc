#!/bin/bash
#
# AI/DLC Operator-Acknowledgement Hook (Rule 29)
#
# PURPOSE
# Gives the pause flag teeth. `ai-dlc-pause.sh` (UserPromptSubmit) creates
# _bmad-output/pipeline-paused.flag on every operator message and instructs
# the lead not to execute pipeline steps while it exists. Until now NOTHING
# enforced that: the flag was read only by the Stop hook (ai-dlc-continue.sh)
# and the driver signal. The lead -- simultaneously under Rule 3 ("Keep
# working. Do not ask if you should continue.") and the Stop hook's forced-
# continuation reason -- routinely steamrolled the operator's message, which
# arrives mid-turn alongside a tool result and is easy to ignore.
#
# This hook denies PIPELINE-ADVANCING tool calls while the flag exists. The
# lead must deal with the operator before it can advance.
#
# DECISION ORDER (first match wins)
# 1. no snapshot            -> allow (no active pipeline; same gating as pause.sh)
# 2. no pause flag          -> allow (autonomous mode; the common path)
# 3. tool is pipeline-      -> DENY with a reason telling the lead to answer
#    advancing                 the operator, then clear the flag to resume
# 4. default                -> allow (read-only work + the flag-clearing rm)
#
# THE ENFORCEMENT SURFACE (deliberately narrow -- Rule 26 minimum mechanism)
# Denied:  Agent, Skill, TaskCreate, and Write/Edit under _bmad-output/.
#          Per Rule 28 delegation is the default, so the lead cannot advance
#          the pipeline without one of these. This is the whole surface.
# Allowed: Read, Grep, Glob, Bash, and everything else -- so the lead can
#          investigate the operator's question, AND so it can always run
#          `rm -f _bmad-output/pipeline-paused.flag` to resume. Allowing Bash
#          is what makes deadlock impossible.
#
# WHY NOT DENY EVERYTHING
# A hook that denied Bash too would trap the lead: the sanctioned resume path
# (SKILL.md INITIALIZATION) is an `rm` via Bash. Denying it would wedge the
# pipeline permanently. The escape hatch must stay open.
#
# OUTPUT
# - Appends to: _bmad-output/pipeline-continuation-log.md (event: ACK_DENIED)
# - JSON to stdout on deny: permissionDecision + reason
# - Exit 0 in all cases (the deny is in the JSON body)
#
# INSTALL
# 1. Place at .claude/hooks/ai-dlc-acknowledge.sh
# 2. chmod +x .claude/hooks/ai-dlc-acknowledge.sh
# 3. Add to .claude/settings.json hooks under "PreToolUse" with
#    "matcher": "Agent|Skill|TaskCreate|Write|Edit"
# 4. Restart Claude Code; verify with /hooks

set -u

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
SNAPSHOT_FILE="${PROJECT_DIR}/_bmad-output/pipeline-snapshot.md"
LOG_DIR="${PROJECT_DIR}/_bmad-output"
LOG_FILE="${LOG_DIR}/pipeline-continuation-log.md"
PAUSE_FLAG="${LOG_DIR}/pipeline-paused.flag"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // empty')
TRANSCRIPT=$(echo "$INPUT" | jq -r '.transcript_path // empty')
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# -----------------------------------------------------------------------------
# Which skill is this session running?
#
# `/ai-dlc-update` is NOT `/ai-dlc`. It advances no sprint, passes no gate, and
# runs precisely when the pipeline is parked -- which is exactly when the pause
# flag is set. Denying its dispatches because "the pipeline is PAUSED" blocks a
# skill that has no pipeline to pause, and the flag it trips over is usually the
# one a HANDOFF left behind.
#
# This was already understood for the updater's file WRITES (see the
# _bmad-output/ai-dlc-update/ carve-out below) and never extended to its
# DISPATCHES -- while the updater's whole design is a fan-out ("dispatch ONE
# generic agent per file", ai-dlc-update/SKILL.md). So it was denied, and the
# model routed around the denial by doing the work INLINE in the lead, which
# defeats the offload the dispatch existed for and inflates the very context the
# updater is meant to protect. A guardrail that is trivially routed around is not
# a guardrail; it is a tax on the honest path.
#
# Detected from the transcript rather than a marker file. A marker would need a
# lifecycle -- create, delete, and a story for the crash in between -- and a
# stale-flag-with-a-lifecycle is the bug being fixed here, not a tool to fix it
# with. The transcript is self-healing: whichever skill was invoked LAST is the
# one in play. A session that runs /ai-dlc-update and then /ai-dlc resume is a
# pipeline session again, and the pause gate applies to it in full.
#
# THREE SIGNALS, AND THEY ARE DISJOINT -- NONE OF THEM COVERS BOTH INVOCATION
# PATHS. This is the whole of the defect the reference consumer filed as
# PC-S331: the carve-out never fired on a run where the AGENT invoked the skill
# rather than the operator typing it, so the first dispatch was denied every
# time. Measured live, one headless session per arm, probe on PreToolUse:
#
#   the operator types /ai-dlc-update   marker PRESENT, no Skill tool_use exists
#                                       at all -- a typed slash command loads the
#                                       skill directly and calls no tool
#   the agent calls Skill(ai-dlc-update)  marker NEVER written, not at the
#                                       dispatch and not anywhere later in the
#                                       session; and at the dispatch itself the
#                                       transcript does not yet carry the
#                                       tool_use line either (12 lines, both
#                                       absent) -- it is flushed by the time the
#                                       NEXT tool call runs (17 lines, present)
#
# So the transcript cannot answer for the agent-driven dispatch (nothing is
# there yet) and the payload cannot answer for anything that is not a Skill call
# (Agent/Task/Write carry no `.tool_input.skill`) -- and the updater's own design
# is a fan-out of Agent calls, "dispatch ONE generic agent per file". Both are
# required, and the marker arm stays because it is the ONLY signal a typed
# invocation produces.
#
# THE PAYLOAD IS APPLIED AFTER THE SCAN, AND THE ORDER IS LOAD-BEARING. The
# transcript is one tool call stale by construction, so on the dispatch that
# switches skills it still names the PREVIOUS one. The payload is the current
# call; the recency rule above means it wins.
# -----------------------------------------------------------------------------
# -----------------------------------------------------------------------------
# Check 1: no active pipeline -> allow
# -----------------------------------------------------------------------------
# ORDERING IS LOAD-BEARING. This guard precedes the transcript scan below because
# the scan is the expensive part of this hook and the guard is free. The hook
# fires on Agent|Task|Skill|TaskCreate|Write|Edit|MultiEdit|NotebookEdit -- 10271
# such calls over 30 days on the reference consumer, against transcripts that run
# p90 4.3MB and reach 27.7MB. Scanning before knowing whether there is a pipeline
# at all charged every non-pipeline session in the project for a question only a
# pipeline session asks. `ai-dlc-context-sensor.sh` already bails on no-snapshot
# before it reads a byte of transcript, and names the hazard at its own read site:
# a full scan "often is real hot-path latency". Same discipline, same reason.
[ -f "$SNAPSHOT_FILE" ] || exit 0

UPDATER_SESSION=0
if [ -n "$TRANSCRIPT" ] && [ -f "$TRANSCRIPT" ]; then
  # STILL ONE SCAN, now over FOUR forms. The question is "whichever skill was
  # invoked LAST", so the last line matching ANY marker is the whole answer --
  # separate greps each read the file to EOF (all take `tail -1`) to reconstruct
  # by line number what a single alternation reads once and answers directly.
  #
  # The closing tag is part of both command-name patterns and the closing QUOTE
  # is part of both tool_use patterns, so `/ai-dlc` cannot match an
  # `/ai-dlc-update` line in either family.
  #
  # THE TOOL_USE FORM IS STRUCTURAL, NOT A MENTION. `"name":"Skill","input":{` is
  # the serialization of a real tool_use block; a transcript that merely QUOTES
  # the string carries it inside a JSON string, where every quote is
  # backslash-escaped and this pattern cannot match. Measured over 498 local
  # transcripts: 69 carry a real Skill(ai-dlc*) tool_use, the pattern matches
  # exactly those 69 and 0 others -- and the control is that the session which
  # wrote this comment mentions the string four times and matches zero.
  LAST_SKILL=$(grep -oE '<command-name>/ai-dlc(-update)?</command-name>|"name":"Skill","input":\{"skill":"ai-dlc(-update)?"' "$TRANSCRIPT" 2>/dev/null | tail -1)
  case "$LAST_SKILL" in
    *'/ai-dlc-update</command-name>') UPDATER_SESSION=1 ;;
    *'"skill":"ai-dlc-update"')       UPDATER_SESSION=1 ;;
  esac
fi

# THE CURRENT CALL, which is newer than anything the transcript can hold. Only a
# `Skill` payload carries this field; for every other tool it is empty and the
# transcript verdict above stands unchanged.
case "$(echo "$INPUT" | jq -r '.tool_input.skill // empty')" in
  ai-dlc-update) UPDATER_SESSION=1 ;;
  ai-dlc)        UPDATER_SESSION=0 ;;
esac

# -----------------------------------------------------------------------------
# Check 2a: the adversarial cycle has STOPPED (Rule 8) -- THE TEETH
# -----------------------------------------------------------------------------
# Minimum mechanism (Rule 26(c)).
#   Failure caught: an adversarial cycle DIVERGES (the repair is injecting defects into text
#     already cleared) or STALLS (a nonzero MAJOR held at zero CRITICAL, pass after pass),
#     and the lead dispatches another pass. Rule 8 says stop. Nothing could deny the dispatch.
#   Measured: a live cycle hard-blocked at p15, ran p16, hard-blocked again at p17 -- and
#     earlier held 0C/1M across p11-p14 with nothing firing. Seventeen passes, ~14 hours.
#   False-positive cost: one operator adjudication on a cycle that was going to need one.
#   Removal condition: retire when two consecutive sprints record zero STOP states.
#
# WHY HERE AND NOT IN THE Stop HOOK. v0.57.0 put this in `ai-dlc-continue.sh`, which fires on
# `Stop` -- and `Stop` fires only when the lead YIELDS. Rule 3 and the continue hook exist
# precisely to make the lead never yield. A lead that dispatches pass N+1 in the same turn as
# pass N's join never emits a Stop event, and the check never runs. It fired on the reference
# consumer because the lead happened to stop and present results, not because anything
# enforced it. PreToolUse is the only place a dispatch can actually be denied, so this is the
# only place the hard block can have teeth.
#
# THIS RUNS BEFORE THE PAUSE-FLAG EARLY EXIT, ON PURPOSE. A STOP must survive the flag being
# cleared. Otherwise the resume path (`rm -f pipeline-paused.flag`, which Bash allows and must
# keep allowing) doubles as a way to walk straight past the hard block -- and then the flag is
# not an escape hatch, it is a bypass.
#
# NO ADJUDICATION HERE (Rule 26; v0.54.3's "one predicate, two implementations, and the tool
# wins"). This hook picks the SERIES by mtime -- "which cycle is live" is a RECENCY question,
# and mtime is the right signal for it. It does NOT pick the pass: "which pass is last" is an
# ORDERING question, mtime is the WRONG signal for that, and using it there was order_key()'s
# original bug. The validator owns ordering, and it answers the only question this hook asks:
# may I dispatch? Exit 3 means no.
ADVANCING_TOOL=0
case "$TOOL_NAME" in Agent|Task|Skill|TaskCreate) ADVANCING_TOOL=1 ;; esac

if [ "$ADVANCING_TOOL" -eq 1 ] && [ "$UPDATER_SESSION" -eq 0 ]; then
  ART_DIR="${LOG_DIR}/planning-artifacts"
  CONVERGENCE_VALIDATOR="${PROJECT_DIR}/scripts/ai-dlc/validate-adversarial-convergence.sh"
  # --- LIVE-SERIES DERIVATION -- ONE definition; I81 asserts both hooks carry it verbatim ---
  # TWO HALVES. The first is the SCOPE, and it is what this hook could not have before
  # `artifact-path-grammar.md`: the sprint is DECLARED (`sprint-status.sh sprint-id`, the one
  # home for that answer) and the glob runs inside that sprint's own directory, so "which cycle
  # is live" is asked of one sprint's candidate set. It used to be asked of every series the
  # project had ever written -- measured on the reference consumer at 135 files spanning 56
  # series (s288..s301) in one never-pruned directory, where any touch on a long-converged
  # series redirected the guard. The reason it stood for so long is that there was no
  # naming-safe filter to add: series took the sprint as a filename SUFFIX
  # (`architecture-adversarial-s288-`) as often as a prefix, so an `s<N>-` filter would have
  # silently EXCLUDED real series -- a worse failure than the one it fixed. The directory slot
  # is what makes the scope expressible.
  #
  # NO CROSS-SPRINT FALLBACK, deliberately. When the sprint does not resolve, the glob is
  # pointed at a name that cannot exist and the caller logs the state as unadjudicable. A
  # fallback to the unscoped glob would restore the exact defect this replaces, and would do it
  # precisely when the pipeline's declared state is already broken.
  #
  # The second half is the FILTER. `sed -n 's/.../p'` PRINTS ONLY WHERE THE SUBSTITUTION
  # SUCCEEDED. The previous form picked the newest glob match FIRST and stripped it SECOND, so a
  # filename the strip could not match produced a SERIES that was the entire filename. `--series
  # <whole-filename>` then resolved exactly ONE file, and a one-pass series can never be STALLED
  # or DIVERGENT -- so the stall guard adjudicated nothing, reported a clean state, and allowed
  # the dispatch. Measured on the reference consumer: 6 of 135 files matching this glob defeat
  # the strip (`s289-adversarial-pass1-discovery.md`, `prd-adversarial-sprint-150.md` and four
  # siblings), each one a live opportunity for that silent pass. Filtering INSIDE the pick makes
  # the state unrepresentable -- a non-conforming name is never a candidate and the newest
  # CONFORMING series wins -- rather than detecting it afterwards, which is a second thing to
  # keep in sync. `head -1` closing the pipe early is safe here: no hook sets `pipefail`.
  # >>> I81 LIVE-SERIES BLOCK >>>
  SPRINT_N="$("${PROJECT_DIR}/scripts/ai-dlc/sprint-status.sh" sprint-id --root "${PROJECT_DIR}" 2>/dev/null | head -1)"
  case "$SPRINT_N" in ''|*[!0-9]*) SPRINT_N="" ;; esac
  SPRINT_DIR="${ART_DIR}/s${SPRINT_N:-.no-sprint-resolved}"
  SERIES_UNSCOPED=0
  [ -d "$SPRINT_DIR" ] || for _d in "${ART_DIR}"/s[0-9]*/; do [ -d "$_d" ] && SERIES_UNSCOPED=1; done
  SERIES="$(ls -t "${SPRINT_DIR}"/*adversarial*p*.md 2>/dev/null | sed -E -n 's/(pass|p)[0-9]+\.md$//p' | head -1)"
  # <<< I81 LIVE-SERIES BLOCK <<<
  if [ -z "$SPRINT_N" ] || [ "$SERIES_UNSCOPED" -eq 1 ]; then
    # LOUD, not silent. This hook owns the DENY, so an unscoped state it cannot adjudicate is
    # exactly what must not pass unremarked; retro's Rule 25(c) audit reads this log.
    mkdir -p "$LOG_DIR"
    {
      echo "## ${TIMESTAMP} -- ADVERSARIAL_STATE_UNADJUDICABLE"
      echo "- Session: ${SESSION_ID}"
      echo "- The live adversarial series could not be scoped to a sprint directory."
      echo "  sprint-id resolved: '${SPRINT_N:-<none>}'"
      echo "  scope directory:    ${SPRINT_DIR} (absent, while other s<N>/ directories exist)"
      echo "  The Rule 8 divergence/stall DENY is NOT armed for this dispatch."
      echo "  sprint-id never fails -- with no envelope on disk it returns 1 (greenfield,"
      echo "  route.md Step 6 rule 2), so the failure shape here is a CONFIDENT WRONG sprint,"
      echo "  not an empty one. Fix the declared sprint; there is deliberately no fallback to"
      echo "  an unscoped glob, which is the mtime-across-every-sprint defect this replaced."
      echo ""
    } >> "$LOG_FILE"
  fi

  if [ -n "$SERIES" ] && [ -f "$CONVERGENCE_VALIDATOR" ]; then
    # Feed the validator the harness-owned transcript so arm F6 (operator-citation) can verify
    # a resolution record's operator_authorization against ground truth -- the S290 fix: a lead
    # cannot release an operator-gated HARD_BLOCK by quoting an operator who never spoke. If the
    # transcript is unreadable the validator fails OPEN here (Check 24, the gate, is the
    # fail-closed backstop) and says so on stderr, which we surface to the flow log below.
    CYCLE_ARGS=(--series "$SERIES" --cycle-state)
    [ -n "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ] && CYCLE_ARGS+=(--transcript "$TRANSCRIPT")
    # AND THE DIRECTORY IT LIVES IN. `transcript_path` is always THIS session -- the one
    # asking permission -- never the session in which the operator spoke. A resolution
    # record outlives its session; its citation must too, or every record goes
    # unverifiable across a handoff or /clear and the stall re-deadlocks.
    [ -n "$TRANSCRIPT" ] && [ -d "$(dirname "$TRANSCRIPT")" ] && \
      CYCLE_ARGS+=(--transcript-dir "$(dirname "$TRANSCRIPT")")
    CYCLE_ERRF="$(mktemp 2>/dev/null || echo "${LOG_DIR}/.cycle-err.$$")"
    CYCLE_OUT="$(bash "$CONVERGENCE_VALIDATOR" "${CYCLE_ARGS[@]}" 2>"$CYCLE_ERRF")"
    CYCLE_RC=$?
    CYCLE_STATE="$(printf '%s' "$CYCLE_OUT" | cut -f1)"
    CYCLE_PASS="$(printf '%s' "$CYCLE_OUT" | cut -f2)"
    # Fail-open trace: a resolution cited an operator but it could not be verified (no
    # transcript). A silent fail-open is indistinguishable from a verified pass -- the exact
    # defect class this change is about -- so leave a mark retro's Rule 25(c) audit reads.
    if grep -q 'ADVERSARIAL_CITATION_UNVERIFIABLE' "$CYCLE_ERRF" 2>/dev/null; then
      mkdir -p "$LOG_DIR"
      {
        echo "## ${TIMESTAMP} -- ADVERSARIAL_CITATION_UNVERIFIABLE"
        echo "- Session: ${SESSION_ID}"
        echo "- a resolution record cites operator_authorization, but no readable transcript was"
        echo "  available to verify it. Failed OPEN; Check 24 (gate) is the fail-closed backstop."
        echo ""
      } >> "$LOG_FILE"
    fi
    rm -f "$CYCLE_ERRF" 2>/dev/null

    # FAIL OPEN on anything but an explicit STOP. A hook that fails CLOSED on its own bug
    # wedges the pipeline, and a wedged pipeline gets the hook switched off -- after which
    # nothing is watching at all. Exit 3 is the only code that denies; the gate (Check 24,
    # fail-closed) remains the backstop for everything else.
    #
    # Exit 0 covers CONTINUE, CONVERGED and RESOLVED. RESOLVED is the whole point: it means
    # a valid resolution record exists for the stopped pass, so the VERIFICATION pass is
    # exactly what should be dispatched now. The validator decides that; this hook does not
    # know what a resolution record is.
    if [ "$CYCLE_RC" -eq 3 ]; then
      # ONE BRANCH PER STATE THE VALIDATOR CAN EMIT AT rc=3. This was a two-way `if`
      # whose `else` assumed STALLED, so a new exit-3 state arrived describing itself
      # as a plateau -- a wrong remedy delivered with a confident verdict, which is
      # worse than no message. Any future state added there must land here too.
      case "$CYCLE_STATE" in
        DIVERGENT)
          STOP_WHAT="\`$(basename "$CYCLE_PASS")\` stamps \`verdict: DIVERGENT_HARD_BLOCK\` -- it found CRITICALs in scope a previous pass had ALREADY cleared. Those are defects the REPAIR injected. The next pass finds the next wave." ;;
        REOPENED)
          STOP_WHAT="This series had ALREADY stamped \`EXIT_CONDITION_MET\`, and \`$(basename "$CYCLE_PASS")\` ran after it and found CRITICAL/MAJOR work. The same bytes reviewed under the same contract yield the same residue, so a non-zero residue after MET is proof the artifact MOVED after it was signed off. That is a RE-OPEN, not a continuation: it costs a fresh sub-cycle nobody scheduled. The cycle is ORDERED -- Party Mode, then Advanced Elicitation, then Adversarial Review -- and elicitation editing an artifact its series already notarised is the measured cause." ;;
        *)
          STOP_WHAT="The cycle has held a nonzero MAJOR at ZERO CRITICAL for pass after pass (through \`$(basename "$CYCLE_PASS")\`). It is neither converging nor diverging -- it is STALLED. Each repair rewrites the prose around a claim nobody verified; the next pass falsifies the rewrite with one more counterexample." ;;
      esac

      STOP_REASON="AI/DLC Rule 8: THE ADVERSARIAL CYCLE HAS STOPPED (${CYCLE_STATE}). \`${TOOL_NAME}\` would dispatch another pass, so it is DENIED.

${STOP_WHAT}

ANOTHER PASS IS NOT THE REMEDY. Running one is what produced this state.

THE EXIT:  STOP -> ADJUDICATE -> RESOLVE -> VERIFY

1. STOP. You are here. Nothing further runs on the artifact as it stands.
2. ADJUDICATE. Put this to the operator. Present the finding, the repair that caused it,
   whether that repair weakened something LOAD-BEARING (an AC, a predicate, a guard, a
   LOCKED_REQUIREMENTS entry -- test: after the edit, can the check still FAIL?), and your
   recommended resolution KIND.
3. RESOLVE. A repair edits the artifact to close findings on UNCHANGED scope. That is what
   diverged; doing it again is not a resolution. A resolution changes WHAT IS UNDER REVIEW:
     REVERT_REPAIR    put the artifact back to a state an earlier pass actually reviewed
     CUT_SCOPE        remove the contested scope; the artifact must get SMALLER
     CHANGE_APPROACH  a different approach entirely, on the operator's authority
     RESTART_CYCLE    abandon the series, archive it, start over
   Write the record: ${ART_DIR}/<sprint>-<artifact>-resolution-p<N>.md
   That write is ALLOWED right now, paused or not. It is the one write this pause is
   waiting for, and it is what lifts this denial.
   (FREEZE is deliberately NOT on the list. A hard block means CRITICALs rose in text that
   is ALREADY frozen -- freezing it again removes nothing, and no gate can pass over it.)
4. VERIFY. Dispatch ONE pass on the resolved artifact, as the NEXT PASS NUMBER IN THIS SAME
   SERIES, declaring \`resolves_divergence: <the record>\`. That is the terminal clean pass
   Check 24 requires. Do not open a new series: the glob spans both, the pass numbers
   collide, and the gate then fails on a cycle that did nothing wrong.

Clearing the pause flag does NOT lift this. It is not a stall and Rule 3 does not override it."

      mkdir -p "$LOG_DIR"
      {
        echo "## ${TIMESTAMP} -- ADVERSARIAL_STOP_DENIED"
        echo "- Session: ${SESSION_ID}"
        echo "- Tool denied: ${TOOL_NAME}"
        echo "- ${CYCLE_STATE} at $(basename "$CYCLE_PASS"); no resolution record present"
        echo ""
      } >> "$LOG_FILE"

      jq -n --arg reason "$STOP_REASON" \
        '{
          hookSpecificOutput: {
            hookEventName: "PreToolUse",
            permissionDecision: "deny",
            permissionDecisionReason: $reason
          }
        }'
      exit 0
    fi
  elif [ -n "$SERIES" ]; then
    # A partial install must not SILENTLY disable the hard block -- that is the
    # `core/git-hooks/`-at-a-dead-path failure, an enforcer at a path nothing reads with
    # nothing saying so. Leave a trace retro's Rule 25(c) audit reads, and fail open.
    mkdir -p "$LOG_DIR"
    {
      echo "## ${TIMESTAMP} -- ADVERSARIAL_STATE_UNADJUDICABLE"
      echo "- Session: ${SESSION_ID}"
      echo "- scripts/ai-dlc/validate-adversarial-convergence.sh is MISSING; the Rule 8 stop state"
      echo "  cannot be adjudicated and the divergence/stall hard block is NOT armed."
      echo ""
    } >> "$LOG_FILE"
  fi
fi

# -----------------------------------------------------------------------------
# Check 2b: not paused -> allow (the common path; keep it cheap)
# -----------------------------------------------------------------------------
[ -f "$PAUSE_FLAG" ] || exit 0

# -----------------------------------------------------------------------------
# Check 3: is this tool pipeline-advancing?
# -----------------------------------------------------------------------------
ADVANCING=0
case "$TOOL_NAME" in
  Agent|Task|Skill|TaskCreate)
    # In an /ai-dlc-update session these advance nothing: the updater fans out
    # over its own reconcile, it does not run a sprint. Denying here is what
    # pushed the work inline. In a pipeline session they advance the pipeline
    # and the deny stands.
    [ "$UPDATER_SESSION" -eq 1 ] || ADVANCING=1
    ;;
  Write|Edit|MultiEdit|NotebookEdit)
    # Only artifact production under _bmad-output/ counts. Escalations
    # (docs/escalations/) and source edits are NOT denied -- the lead may
    # legitimately need to write an escalation while paused.
    FP=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')
    case "$FP" in
      # _bmad-output/ai-dlc-update/** is the UPDATER's scratch space (reconcile
      # report, push-candidate ledger) -- NOT pipeline output. /ai-dlc-update is a
      # different skill from /ai-dlc: it advances no sprint, and it runs precisely
      # when the pipeline is not running. Denying its report write because "the
      # pipeline is paused" blocks a skill that has no pipeline to pause. Observed
      # live: the updater was denied mid-reconcile on its own ledger.
      # This case must precede the _bmad-output match below -- first match wins.
      */_bmad-output/ai-dlc-update/*|_bmad-output/ai-dlc-update/*) ;;

      # THE RESOLUTION RECORD IS THE ADJUDICATION ARTIFACT, NOT PIPELINE OUTPUT.
      # It is written when the pipeline is STOPPED, by definition -- a divergence or a
      # stall raised the pause flag, and this file is what the operator's adjudication
      # writes down. It advances nothing: it does not pass a gate, does not add scope,
      # and cannot be produced by any other tool (Bash cannot author it; Write can).
      #
      # DENYING IT WOULD DENY THE EXIT. Check 2a above refuses every dispatch until this
      # record exists; if the pause flag then refuses the record, the two checks lock the
      # pipeline against itself and the only way out is to disable a hook. That is the
      # deadlock this release exists to remove, rebuilt out of its own parts.
      # Same shape and same reasoning as the ai-dlc-update carve-out directly above.
      */_bmad-output/planning-artifacts/*-resolution-p*.md|_bmad-output/planning-artifacts/*-resolution-p*.md) ;;

      # THE PIPELINE SNAPSHOT IS A STATE RECORD, NOT A DELIVERABLE. It mirrors state that has
      # ALREADY happened -- a gate that passed, a teammate that delivered, a resolved block --
      # and it is what a resume or handoff reads to pick the pipeline back up. It advances
      # nothing by itself: advancing is DISPATCH (Agent/Task/Skill/TaskCreate, still denied
      # above), and recording the checkpoint starts no work. Denying it is the resolution-record
      # deadlock a THIRD time: the handoff path itself raises this flag
      # (`ai-dlc-continue.sh` tells the lead to `touch pipeline-paused.flag` when it has no next
      # action -- a handoff), and Rule 2(c) then requires finalizing this very file before the
      # handoff. So the flag the handoff sets would deny the snapshot the handoff must write, and
      # a stale snapshot is a broken resume. Same shape and reasoning as the two carve-outs above.
      # Bash can write it too (and is allowed while paused), but the lead edits an existing 40KB
      # file with Edit, not a heredoc -- routing it to Bash is a trap, not a fix.
      */_bmad-output/pipeline-snapshot.md|_bmad-output/pipeline-snapshot.md) ;;

      # THE ARCHIVE HALF OF THE FILE DIRECTLY ABOVE, and it is one arm rather than a wildcard
      # on purpose. Rule 25(a) and Check 14's `trim` remedy both say the same thing about an
      # over-budget snapshot: MOVE the superseded prose to this file, never delete it. So the
      # rulebook mandates a write in the same breath the arm above sanctions its other half,
      # and a move whose destination is denied is not a move -- the lead compresses in place
      # instead, which is a compliant fallback and is not what the rule prescribes. Measured
      # live on the reference consumer at a handoff seam, which is exactly where a trim comes
      # due: the `Edit` on `pipeline-snapshot.md` succeeded and the identical `Edit` on this
      # file was denied.
      #
      # It is the same deadlock the three carve-outs above each describe, one file short:
      # denying the state-recording half of an already-sanctioned action. Allowing the live
      # file and denying its archive does not narrow the carve-out, it only makes the
      # sanctioned action impossible to perform correctly.
      #
      # LITERAL, NOT `pipeline-snapshot*.md`. The glob would also admit the
      # `.archive.<ISO>.md` form and anything later named to match, none of which has been
      # reviewed here; the archive form is produced by a MOVE at fresh start, and Bash is
      # deliberately never denied while paused, so no denial was ever measured against it.
      */_bmad-output/pipeline-snapshot-history.md|_bmad-output/pipeline-snapshot-history.md) ;;

      */_bmad-output/*|_bmad-output/*) ADVANCING=1 ;;
    esac
    ;;
esac

[ "$ADVANCING" -eq 1 ] || exit 0

# -----------------------------------------------------------------------------
# DENY. The operator is waiting.
# -----------------------------------------------------------------------------
REASON="AI/DLC Rule 29: the pipeline is PAUSED -- an operator message is outstanding and has not been acknowledged. \`${TOOL_NAME}\` advances the pipeline, so it is denied until you deal with the operator.

Do this now, in order:
1. READ the operator's message. It arrived mid-turn, most likely alongside a tool result, and is easy to scroll past. Find it.
2. RESPOND to it in text. Answer the question, accept the correction, or state what you will do differently. Do not silently continue.
3. THEN classify intent, per the pause contract:
   (a) Resume intent (including /ai-dlc resume, handoff resume, or natural resume language) -> \`rm -f _bmad-output/pipeline-paused.flag\`, then RE-READ the current step file (Rule 22) and continue.
   (b) Question / correction / clarification -> answer it, leave the flag in place, and wait. The operator is steering.
   (c) Handoff request -> follow the Rule 2 handoff protocol; leave the flag in place.

Read-only tools (Read, Grep, Glob, Bash) are still ALLOWED -- use them to investigate the operator's question, and to clear the flag when you resume. Only pipeline-advancing calls are blocked.

This is not a stall and Rule 3 does not override it. Rule 3 forbids stalling when NO ONE is waiting on you. Here a human IS waiting on you. Answer them."

# Seed the log header if this is the first write of the sprint. Retro rotates
# the live log away at close (Rule 25(c)), so any of the three hooks may find
# the file absent and must be able to open a fresh one.
mkdir -p "$LOG_DIR"
if [ ! -s "$LOG_FILE" ]; then
  cat > "$LOG_FILE" <<'EOF'
# Pipeline Flow Log

Records pipeline-level events: user pauses, Rule 3 enforcement, operator
acknowledgement denials, and rapid-fire stall detection. Generated by AI/DLC
hook scripts. Rotated per sprint at retro close (Rule 25(c)).

Event types:

- `USER_PAUSE`: the operator steered and the pipeline paused via flag file. TWO
  channels raise it and the entry's `Channel:` line names which: a typed message
  (UserPromptSubmit), or an AskUserQuestion answer carrying handoff intent. The
  second raises no UserPromptSubmit at all, so before it was routed a handoff
  asked for that way produced no USER_PAUSE, no flag, and no record that the
  operator had spoken
- `PAUSE_SKIPPED`: a UserPromptSubmit carried no operator prose, so no pause
  flag was created. The harness raises the event identically for a completed
  background task and for a human typing; this records the ones that were not
  a human, so a pause that never happened is distinguishable from one the lead
  already cleared
- `BLOCKED`: Stop event blocked; Rule 3 enforcement forced continue
- `ALLOWED_BY_PAUSE`: Stop event allowed because pause flag exists
- `ACK_DENIED`: a pipeline-advancing tool call was DENIED because an operator
  message was outstanding and unacknowledged (Rule 29). A nonzero count means
  the lead tried to execute straight through a waiting human and the hook --
  not the lead's judgment -- is what stopped it. Investigate each one.
- `BACKOFF`: rapid-fire stop attempts detected; stall confirmed
- `ESCALATION_UNDELIVERED`: a SendMessage returned `success:false`, so an
  operator-bound message was never delivered. The harness does NOT mark these
  as tool errors, which is why they fell through silently; a nonzero count
  means an escalation the lead believed it had sent did not arrive. Read the
  recorded target -- a failure to reach `parent` is subagent routing, not an
  operator escalation

Retro reviews this log to assess pipeline flow:

- High USER_PAUSE counts mean the user intervened often (normal for
  interactive sprints, concerning if unexpected)
- High PAUSE_SKIPPED counts are normal in a sprint with heavy background
  dispatch; a SUDDEN change in the USER_PAUSE:PAUSE_SKIPPED ratio is the
  signal worth reading
- High BLOCKED counts mean Rule 3 enforcement is doing work; without
  the hook the pipeline would have stalled
- BACKOFF entries indicate the pipeline actually got stuck and the
  hook exhausted its retry budget. Investigate the transcript around
  each BACKOFF to find the upstream cause.

Counting entries: one event is one `## <timestamp> -- <EVENT>` line. Count with
`grep -c '^## .*-- <EVENT>'`. A bare `grep -c <EVENT>` also matches this header,
which mentions every event name, so it over-reports — and the inflated number is
plausible enough that nothing about the result signals it counted documentation.

---

EOF
fi

{
  echo "## ${TIMESTAMP} -- ACK_DENIED"
  echo "- Session: ${SESSION_ID}"
  echo "- Tool denied: ${TOOL_NAME}"
  echo "- Pause flag present; operator message not yet acknowledged"
  echo ""
} >> "$LOG_FILE"

jq -n \
  --arg reason "$REASON" \
  '{
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: $reason
    }
  }'

exit 0
