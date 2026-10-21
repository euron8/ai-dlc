#!/usr/bin/env bash
# audit-party-wave-barrier.sh -- replay recorded Claude Code transcripts and flag every UNNEEDED WAVE
# BARRIER in a party round: an agent of the round EXITED and its notification was DELIVERED to the lead,
# a harness slot was free, round members were still undispatched, and the lead's response to that
# delivery dispatched nothing for the round. Rule 28's third uncovered notification -- "an exit while
# round members remain undispatched releases the next undispatched members, up to the free slots" --
# was left unanswered, and the slot sat idle until a later dispatch (BL-695).
#
# READ-ONLY. It reads the transcripts it is given and writes only under its own mktemp dir.
#
# USAGE
#   audit-party-wave-barrier.sh [--cap N] [--trace] <transcript.jsonl>...
#   audit-party-wave-barrier.sh --seed <case> <out.jsonl> [--seed <case> <out.jsonl>]...
# --seed writes one of the self-probe's seeded transcripts (cases a-s below) and exits 0, so a receipt
# can drive the detector over the same shapes the probe uses.
#
# EXIT: 0 no findings; 1 one or more findings; 2 usage, a refused self-probe, an empty transcript
# list, or any transcript that could not be scanned (unreadable, empty, or not JSONL). Scanned is
# counted against given, and any shortfall is exit 2, never 0.
#
# OUTPUT (stdout), one line per judged batch boundary:
#   FINDING <transcript> round=<dir/step> batch=<k> exit=<ts> dispatch=<ts> running=<n> cap=<c> idle=<c-n> gap=<s>s unrefilled=<u>
#   UNKNOWN-CAP <transcript> round=<dir/step> batch=<k> exit=<ts> dispatch=<ts> running=<n> unrefilled=<u>
#   TRACE <transcript> round=<dir/step> DELIVERED ... REFILLED|UNREFILLED|SLOTS-FULL|NO-CAP   (--trace only)
# <exit> is the first unanswered delivery of the stretch, and running/idle are read at it.
# A summary goes to stderr: given, scanned, rounds, batches, findings, unknown-cap. UNKNOWN-CAP is
# NEVER a finding and does not move the exit code, but it is LOUD: each transcript and round that held
# a batch it could not judge also prints one stderr line
#   audit-party-wave-barrier: UNKNOWN-CAP session=<transcript basename> round=<dir/step> unjudged=<n>
# because a quiet rc 0 over a transcript with no readable cap reads exactly like a clean one.
#
# GRAMMAR -- what the replay reads. It judges DISPATCH BEHAVIOUR ONLY: Agent/Task tool_use blocks and
# their tool_results, exit and delivery records read by their FIELDS, turn boundaries and the cap. It
# never reads an assistant text or thinking block. Text written ABOUT a dispatch is not the dispatch.
#   MEMBER    an Agent or Task tool_use whose input.prompt names a path `party-mode/<dir>/<file>.md`
#             whose SEAT -- the last `-<seat>` segment ROUND strips -- equals input.subagent_type, where
#             the seat is one of the rule-20 role-manifest personas (rule-20.md, "Role-manifest
#             preamble"): pm architect dev qa tea ux sm cis. Every cited party-mode path is tried in
#             prompt order and the FIRST whose seat matches is the member's identity, so a cross seat
#             citing another seat's file first, or a seat citing a shared brief.md first, is still a
#             member of its own seat. A call no cited path matches -- a remediator repairing seat
#             findings, an adversary, code-reviewer or general-purpose agent reading them -- is not a
#             member, answers no delivery, and is RUNNING like any other call (BL-732, case t).
#   ROUND     <dir>/<step>, where <step> is <file> with `.md`, then a trailing `-<digits>`, then a
#             trailing `-cross`, then the last `-<seat>` segment removed. So
#             s319/stories-dev-01.md, s319/stories-architect-cross-5.md and s319/stories-tea-19.md are
#             all round `s319/stories`: the seats of one round are one round, never one round each.
#   LAUNCH    the member's tool_result is not an error. A result carrying `Concurrent subagent limit`
#             (is_error) is a REJECTED spawn: nothing launched. Any other error result, such as a
#             hook's deny, launched nothing either; neither kind is a member or RUNNING (cases o,
#             p). `Async agent launched` makes it a
#             background agent; any other non-error result is a foreground agent that ran from its
#             tool_use to its tool_result. An Agent call with no result counts as running forever.
#   NEW       a member's FIRST non-error launch of its path in the round. A re-dispatch of a launched
#             path (a MISSING member re-sent, a 429 retry) is never new.
#   EXIT      the first exit record naming the agent, by the <tool-use-id> child equal to the Agent
#             call's id or the <task-id> child equal to the launch's `agentId:`, any <status>. Exit
#             records are keyed on record FIELDS, as ai-dlc-dispatch-guard.sh's ARM 1 keys them: a
#             `queue-operation` with operation `enqueue` (the moment the agent exits), or a record whose
#             .origin.kind or .attachment.origin.kind is `task-notification` (the delivery). The body
#             is read for its three children only; no text prefix of it is matched.
#   DELIVERY  the first .origin.kind / .attachment.origin.kind record for an agent: the moment the
#             lead was TOLD. An enqueue alone is an exit the lead has not seen and is never judged.
#   TURN      a `user` record whose message.content is a string (a human prompt or a delivered
#             notification) starts a turn; tool_result arrays and attachments do not, and neither
#             does a compaction summary (isCompactSummary), which lands mid-turn (213 of 239 in the
#             corpus follow a tool_use) and is neither a prompt nor a delivery (case q). An isMeta
#             record (Stop-hook feedback, "no visible output") DOES start one: it follows an end_turn
#             in every corpus instance but a handful, so the lead's response had already ended, and
#             exempting it acquitted the TRUE 3dbc11fb b2. isSidechain records are dropped (case r).
#   RESPONSE  the records after a delivery up to the next TURN start that follows at least one
#             assistant record. Consecutive deliveries with no assistant record between them share one
#             response. The response ANSWERS the delivery when it carries any Agent/Task call of the
#             same round, new, re-sent or rejected. Keyed on the turn and not on the next assistant
#             message: a lead that arms a beat and dispatches the refill in the next message of the
#             same turn has answered (case k).
#   RUNNING   at a moment s: every Agent/Task launched before s, of ANY round or none, minus those
#             whose exit is at or before s.
#   CAP       in order: --cap N; else the harness rejection text `You can run N subagents at once` in
#             a tool_result of an Agent/Task call; else the environment, read from a tool_result line
#             that is EXACTLY `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=N`, or a tool_result that is
#             EXACTLY an integer answering a Bash call whose command names that variable (the
#             `printenv CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` rule 28 prescribes). The rejection ranks
#             above the environment because it is the LIVE value the harness enforced; an env read can
#             predate a relaunch. Two values within one source take the LOWER and both are named in the
#             STAT line. Otherwise the cap is UNKNOWN and is never assumed.
#   VERDICT   each delivery of a round member is REFILLED (its response answered it), SLOTS-FULL
#             (RUNNING >= CAP at the delivery), NO-CAP (unanswered, cap unknown) or UNREFILLED. At each
#             NEW member of a round after its first, the deliveries of round members since the round's
#             previous NEW member are a stretch: any UNREFILLED makes a FINDING (batch k+1), else any
#             NO-CAP makes an UNKNOWN-CAP, else it is quiet. A NEW member after the delivery is what
#             proves members were still undispatched at it, so a round's last stretch is never judged.
#   SCANNED   a transcript is scanned when it is readable, non-empty and its first line parses as a
#             JSON object. Lines that do not parse are skipped. The parse reads only lines carrying
#             one of the prefilter tokens below; a dropped Agent result reads as "running forever".
#
# SELF-PROBE. Before any corpus is read the script replays twenty transcripts it seeds under
# mktemp, with both exit carriers the harness writes (the enqueue, then the delivery) and no envelope
# tag on any body. Each answers as stated or the run refuses with exit 2, naming the case:
#   (a) cap 4 env line; Dev 01-02; Dev 01's delivery answered by a --status beat only; Dev 02's by
#       the Architect dispatch.                             -> 1 FINDING, running 1 cap 4 idle 3
#   (b) refill on exit, cap 2; the assistant text states a per-seat barrier.      -> quiet
#   (c) cap 2 from a REJECTED spawn; Dev 01's exit answered by a re-send the harness rejects again,
#       Dev 02's by the re-dispatch that launches.          -> quiet, 2 batches judged
#   (d) (a) with no cap anywhere.                           -> 1 UNKNOWN-CAP and the loud line
#   (e) s319: cap 42; four 25-member seat messages, each delivery answered by --status only.
#                                                           -> 3 FINDINGs, running 24 idle 18
#   (f) X6: cap 4 by printenv, all 4 running; three exit at +5 min answered by --status, the
#       straggler at +40, then the next seat.               -> 1 FINDING, running 3 idle 1
#   (g) X6 reversed: each exit's enqueue, an in-flight message, its delivery, then its refill. -> quiet
#   (h) X2: cap 10, no beat at all, deliveries answered by text only; the first is delivered by the
#       mid-turn attachment carrier.                        -> 1 FINDING, idle 7, unrefilled 3
#   (i) X1: cap 10; 3 of 4 exit, the lead waits 30 min, 3 Architects while Dev 04 runs. -> 1 FINDING
#   (j) X1b: (i) with 2 of 4 exited and 4 Architects.       -> 1 FINDING
#   (k) X3: cap 4 by rejection; three deliveries back to back, a beat over the straggler, then the
#       refill in the next message of the same turn.        -> quiet
#   (l) X4: cap 4; all four exit within a second; the next message refills four.   -> quiet
#   (m) cap 2; the refill launched between an exit's enqueue and its delivery, which then arrives
#       with RUNNING = CAP and is answered by --status only. -> quiet (SLOTS-FULL)
#   (n) cap 4; Dev 01's delivery answered by --status; Dev 02's by a MISSING re-send of Dev 01; no
#       new member ever follows.                            -> quiet
#   (o) cap 4; Architect 01 denied by a hook (an error result that is not a cap rejection); Dev 01's
#       delivery answered by --status; Architect 01 re-sent and launched at +40. -> 1 FINDING, running 1
#   (p) cap 3 from two REJECTED Architect spawns held across Dev 01's exit, answered by --status only.
#       A rejected spawn is not RUNNING.                    -> 1 FINDING, running 1 cap 3 idle 2
#   (q) cap 4; Dev 01's refill follows a compaction summary (isCompactSummary) that lands between
#       the delivery's first assistant record and the refill; Dev 02's is refilled at once. -> quiet
#   (r) (a)-shaped barrier; a sidechain Agent call naming a round path follows Dev 01's delivery.
#                                                           -> 1 FINDING (the sidechain answers nothing)
#   (s) rejections carrying 5 then 3; the lower is the cap. -> 1 FINDING, running 2 cap 3 idle 1
#   (t) (a)-shaped barrier; Dev 01's delivery is answered only by calls citing a round path that are
#       not seats: a remediator, a code-reviewer and a general-purpose agent reading seat files, and an
#       adversary writing stories-adversary-01.md (a seat segment outside the role-manifest map).
#                                                           -> 1 FINDING, agents=7
#
# FALSE-POSITIVE SET AND HOW IT REACHED ITS FINAL STATE (measured on the graph transcript corpus,
# ~/.claude/projects/-Users-n8-git-graph/*.jsonl, read only):
#   1. A round keyed on <dir>/<seat> split s319's Dev, Architect and TEA seats into three one-batch
#      rounds and the motivating transcript a0701ce0 read ZERO findings. The round key strips the seat.
#   2. A cap read from any text found `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS` in Read output of rule
#      prose (with a `<N>` placeholder) and in an operator message "I have raised ...=42 but need to
#      relaunch" in ea675b67, whose live cap per the harness rejections was 20. The cap is read only
#      from the harness rejection of an Agent call, or from a whole tool_result, never message text.
#   3. A re-dispatch of an already launched path is not a new member; it is legitimate after a join.
#   The earlier BEAT predicate ("a wait-for-deliverable beat joined an earlier batch, with RUNNING <
#   CAP at the beat") and its three narrowings -- `--status` charges no beat; a dispatch under a live
#   beat is a refill unless the join completed; the size-and-majority test for a straggler wave -- are
#   GONE. The beat was never the barrier: X6 (all slots full at the beat, then three exits left idle
#   35 minutes) read CAP-FULL, X1 and X1b read REFILL-UNDER-BEAT, and a lead that never arms a beat
#   (X2) could not be judged at all. The delivered-exit predicate convicts all four and needs none of
#   the narrowings: a refill is an answered delivery whatever beat is armed.
#   4. An Agent call a hook DENIED (an error result that is not a cap rejection, e.g. Rule 29's pause
#      deny) carried no prefilter token, so its result was dropped and it read as a launched member
#      RUNNING forever: its later real launch read as a re-send and its stretch was never judged
#      (case o). Every error result is now read. This moved 22e0f5c2 b31's exit past the pause and
#      surfaced 22e0f5c2 b30 and ea675b67 b32, and it removed ed2d9d82's third UNKNOWN-CAP, which was
#      a denied SM call at 12:39:05 read as a new member.
#   5. A compaction summary is a string-content user record and opened a turn, so a refill that
#      followed one in the same turn read as unanswered (case q). It no longer ends a turn. An isMeta
#      record (Stop-hook feedback) still does: exempting it too acquitted the TRUE 3dbc11fb b2, whose
#      lead ended its turn at 09:40:18 on "the beat will report the rest" and dispatched at 09:51:35.
#   FINAL STATE over the 185 transcripts in the directory at re-measure (BL-732), no --cap:
#   40 rounds, 164 batches, 13 FINDINGS, 4 UNKNOWN-CAP. The pre-BL-732 key read 44 rounds, 171
#   batches, 13 FINDINGS and 7 UNKNOWN-CAP over the same set (its original 187-transcript figure of
#   43/170 plus a367e62c, written after it). The seat key dropped remediator and adversary fan-outs
#   citing seat files: whole rounds in a367e62c, b65d934e, 4aa8adbd and f849d75f, and the second
#   "batch" of 755e5287, 79ff7d55 and c67c233a, which were the three lost UNKNOWN-CAPs. No FINDING moved.
#   TRUE (11): 09dc13f7 s318/stories b2 (61 min on one SM cross straggler, 24 of 42 free); 3dbc11fb
#   s317/sprint-review b2, b3, b4 (per-seat waves joined, 12-16 free); 22e0f5c2 s316/sprint-review b31
#   (exit 01:12:49, after "proceed" lifted the pause: the held cross set not re-sent on eleven exits
#   over 7 minutes, 7 of 20 free);
#   945b34a0 s316/stories-test-strategy b2, b3 (48 rejected spawns held across exits, 1-7 free);
#   ea675b67 s317/stories b3 (three SM exits, 88 s, before the Dev refill); 20bd359c s318/sprint-review
#   b2 (dev-11, dev-13 and dev-cross-1..6 rejected at 07:54-07:55 and held across twelve exits from
#   07:56:18 to 07:57:28, running falling 39 to 28 of 42, re-sent at 08:04:19); ea675b67 b14 (was
#   b15: Architect 12's 06:32:40 call was hook-denied, so its 06:38:30 launch is now the new member)
#   and b17 (16-18 running of the harness's 20, held at a "ceiling of 16" the lead's own text
#   introduced at 06:32:59 -- no operator prompt from 05:30 to 06:33 names one, and rule 28 forbids an
#   assumed number). Three gaps sit at the response-latency floor (88 s, 119 s, 132 s); they are true
#   by the rule and small by consequence.
#   FALSE (2), both inside a Rule 29 pause, which the replay cannot see (residual 2): 22e0f5c2 b30
#   (exits 01:10:27-01:10:54, between the deny of the qa-cross re-send at 01:10:34 and "proceed" at
#   01:11:31; the lead's text says it is answering, not dispatching) and ea675b67 b32 (exit 07:04:52,
#   between the denies of the Architect 08/10 re-sends at 07:04:47-49 and "continue" at 07:05:43).
#   Both surfaced when item 4 above was fixed: the denied calls had masked them.
#   The refill-heavy stretches of ea675b67 and 22e0f5c2 that the beat predicate's narrowing 5 existed
#   for read REFILLED: each exit there was answered by a sized dispatch.
#   RESIDUALS, reachable and not separated:
#   - A ceiling below the harness cap that someone legitimately set is invisible; the replay never
#     reads conversation. None was found in the corpus; ea675b67's 16 was not one.
#   - An operator pause or question window reads as unanswered exits: the two FALSE findings above.
#     A hook-denied Agent call of the round marks one start in both, and the next human prompt its
#     end, so the window is derivable from record fields; it is not built here.
#   - A response turn has no latency bound. 3dbc11fb's eleven 09:40:13-09:42:56 deliveries read
#     REFILLED by a dispatch nine minutes later in the same turn, across a compaction.
#   - An enqueue with no delivery is never judged (2 in ea675b67, 4 in 22e0f5c2).
#   - RUNNING undercounts where Agent records do not reach the transcript in the order the harness
#     admitted them. At rejections, running() read below the cap in 33 of 46 rejections in 20bd359c
#     (by up to 6), 16 of 23 in ea675b67 (up to 2) and 10 of 10 in 3dbc11fb (up to 16, all in one
#     27-call message), and in 0 of 75 in 22e0f5c2 and 0 of 80 in 945b34a0. Measured mid-wave, which
#     is not the input a delivery minutes later sees; an idle count of 1-3 is inside that error.
#   - A party round RE-RUN under the same <dir>/<step> would read as a later batch of the first run,
#     and with a known cap it could be a false FINDING. The one instance this header named (79ff7d55
#     s317/stories) was a remediator fan-out, not a re-run, and the seat key no longer counts it.
#   The motivating transcript a0701ce0 carries no readable cap (its only mentions of the variable are
#   rule prose with a `<N>` placeholder), so it reads UNKNOWN-CAP without --cap and fires under an
#   operator-supplied --cap 42, twice: s319/stories batches 2 and 3, 24 running, idle 18 each.
set -uo pipefail

ME="audit-party-wave-barrier"
SEED_CASES="a b c d e f g h i j k l m n o p q r s t"
usage() { echo "$ME: $1" >&2; echo "usage: $ME.sh [--cap N] [--trace] <transcript.jsonl>... | --seed <$(echo $SEED_CASES | tr ' ' '|')> <out.jsonl>..." >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "$ME: jq is required" >&2; exit 2; }

# Events, one tab-separated line each, in transcript order:
#   M <e> <ts> <msgid>                                  an assistant record (any content)
#   A <e> <ts> <msgid> <tool_use id> <subagent_type> <every party path, space-joined, prompt order>   an Agent/Task call
#   V <e> <ts> <msgid> <tool_use id>                     a Bash call whose command names the cap variable
#   R <e> <ts> - <tool_use id> err|ok <rejcap> <envline> <agentId> async|fg <bare integer>
#   T <e> <ts>                                          a user record with string content: a turn starts
#   N <e> <ts> x|d <tool-use-id> <task-id> <status>      an exit record: x the enqueue, d a delivery
read -r -d '' JQ_PROG <<'JQEOF' || true
def ep: (try (sub("\\.[0-9]+Z$"; "Z") | fromdateiso8601) catch 0);
def flat: gsub("[\t\n\r\\\\]"; " ");
def txt: if type == "string" then . elif type == "array" then ([.[]? | select(type == "object") | (.text // "")] | join("\n")) else "" end;
def kid($k): ((capture("<" + $k + ">(?<x>[^<]*)</" + $k + ">") | .x) // "");
def exitrec($kind; $e; $ts): if type == "string" then ["N", $e, $ts, $kind, kid("tool-use-id"), kid("task-id"), kid("status")] else empty end;
def nkind: (try .origin.kind catch null);
def akind: (try .attachment.origin.kind catch null);
fromjson? // empty
| select(type == "object" and .isSidechain != true)
| (.timestamp // "" | tostring) as $ts | ($ts | ep) as $e
| if .type == "assistant" then
    (.message.id // "") as $mid
    | ["M", $e, $ts, $mid],
      ((.message.content // []) | if type == "array" then .[] else empty end
       | select(type == "object" and .type == "tool_use")
       | if (.name == "Agent" or .name == "Task") then
           ["A", $e, $ts, $mid, (.id // ""),
            (.input.subagent_type // ""),
            ([(.input.prompt // "" | tostring) | scan("party-mode/[A-Za-z0-9_.-]+/[A-Za-z0-9_-]+\\.md")] | join(" "))]
         elif .name == "Bash" and ((.input.command // "") | tostring | test("CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS")) then
           ["V", $e, $ts, $mid, (.id // "")]
         else empty end)
  elif .type == "user" then
    (.message.content) as $c
    | if ($c | type) == "array" then
        $c[] | select(type == "object" and .type == "tool_result")
        | ((.content // "") | txt) as $t
        | ["R", $e, $ts, "-", (.tool_use_id // ""),
           (if .is_error == true then "err" else "ok" end),
           ([$t | scan("You can run ([0-9]+) subagents at once")] | .[0][0] // ""),
           ([$t | split("\n")[] | select(test("^CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=[0-9]+$"))] | .[0] // "" | sub("^[^=]*="; "")),
           ([$t | scan("agentId: ([A-Za-z0-9]+)")] | .[0][0] // ""),
           (if ($t | test("Async agent launched")) then "async" else "fg" end),
           ($t | if test("^\\s*[0-9]+\\s*$") then gsub("\\s"; "") else "" end)]
      elif ($c | type) == "string" then
        (if .isCompactSummary != true then ["T", $e, $ts] else empty end),
        (if nkind == "task-notification" then ($c | exitrec("d"; $e; $ts)) else empty end)
      else empty end
  elif .type == "queue-operation" and .operation == "enqueue" then (.content | exitrec("x"; $e; $ts))
  elif .type == "attachment" and akind == "task-notification" then (.attachment.prompt | exitrec("d"; $e; $ts))
  else empty end
| map(tostring | flat) | join("\t")
JQEOF

# The replay. Two passes over one event file: pass 1 learns every agent's launch status, exit,
# delivery and the cap; pass 2 walks dispatches, deliveries and turns in transcript order.
read -r -d '' AWK_PROG <<'AWKEOF' || true
function rkey(p,   d, f) {
  sub(/^party-mode\//, "", p)
  d = p; sub(/\/.*/, "", d)
  f = p; sub(/^[^\/]*\//, "", f)
  sub(/\.md$/, "", f); sub(/-[0-9]+$/, "", f); sub(/-cross$/, "", f)
  if (f ~ /-/) sub(/-[^-]*$/, "", f)
  return d "/" f
}
# seatmember(p, t): 1 when subagent_type t is the seat of party path p -- the `-<seat>` segment rkey
# strips last -- and that seat is a rule-20 role-manifest persona.
function seatmember(p, t,   f) {
  f = p; sub(/^.*\//, "", f)
  sub(/\.md$/, "", f); sub(/-[0-9]+$/, "", f); sub(/-cross$/, "", f)
  if (f !~ /-/) return 0
  sub(/^.*-/, "", f)
  return ((f in seats) && f == tolower(t))
}
# memberpath(list, t): the first space-separated party path in list whose seat is t, or "".
function memberpath(list, t,   n, i, pl) {
  n = split(list, pl, " ")
  for (i = 1; i <= n; i++) if (seatmember(pl[i], t)) return pl[i]
  return ""
}
function running(s,   i, id, n) {
  n = 0
  for (i = 1; i <= nag; i++) {
    id = agl[i]
    if (aseq[id] >= s) continue
    if (ast[id] == "rej" || ast[id] == "err") continue
    if ((id in aexit) && aexit[id] <= s) continue
    n++
  }
  return n
}
function agent_of(   id) {
  id = ""
  if ($5 in isag) id = $5; else if ($6 != "" && ($6 in byaid)) id = byaid[$6]
  return id
}
# close_seen: finalize every open delivery that has seen an assistant record; keep the rest open.
function close_seen(   i, k, r, v) {
  k = 0
  for (i = 1; i <= gn; i++) {
    if (!gseen[i]) { k++; gid[k] = gid[i]; gr[k] = gr[i]; gts[k] = gts[i]; gep[k] = gep[i]; grun[k] = grun[i]; gans[k] = gans[i]; gseen[k] = 0; continue }
    r = gr[i]
    if (gans[i]) v = "REFILLED"
    else if (cap == "") { v = "NO-CAP"; if (!snocap[r]) { snts[r] = gts[i]; snrun[r] = grun[i] } snocap[r]++ }
    else if (grun[i] >= cap) v = "SLOTS-FULL"
    else { v = "UNREFILLED"; if (!sunref[r]) { suts[r] = gts[i]; suep[r] = gep[i]; surun[r] = grun[i] } sunref[r]++ }
    if (trace) printf "TRACE %s round=%s DELIVERED exit=%s running=%d cap=%s %s\n", name, r, gts[i], grun[i], (cap == "" ? "unknown" : cap), v
  }
  gn = k
}
BEGIN { FS = "\t"; capsrc = "unknown"; nag = 0; gn = 0; nfind = 0; nunk = 0; nrounds = 0; nbatches = 0
  nseat = split("pm architect dev qa tea ux sm cis", seatl, " "); for (i = 1; i <= nseat; i++) seats[seatl[i]] = 1 }
NR == FNR {
  if ($1 == "A") { id = $5; if (!(id in isag)) { isag[id] = 1; nag++; agl[nag] = id; aseq[id] = FNR
      mp = memberpath($7, $6)
      if (mp != "") { p = mp; sub(/.*party-mode\//, "party-mode/", p); amr[id] = rkey(p); bn = p; sub(/.*\//, "", bn); abn[id] = bn } } }
  else if ($1 == "V") envcmd[$5] = 1
  else if ($1 == "R" && ($5 in isag)) {
    id = $5
    if ($6 == "err") { ast[id] = "err"; if ($7 != "") { ast[id] = "rej"; rejcap[$7] = 1; if (rejmin == "" || $7 + 0 < rejmin + 0) rejmin = $7 } }
    else if ($10 == "async") { ast[id] = "bg"; if ($9 != "") byaid[$9] = id }
    else { ast[id] = "fg"; if (!(id in aexit)) aexit[id] = FNR }
  }
  else if ($1 == "R") {
    v = $8; if (v == "" && ($5 in envcmd)) v = $11
    if (v != "" && v + 0 > 0) { envcap[v] = 1; if (envmin == "" || v + 0 < envmin + 0) envmin = v }
  }
  else if ($1 == "N") {
    id = agent_of()
    if (id != "") { if (!(id in aexit)) aexit[id] = FNR; if ($4 == "d" && !(id in adel)) adel[id] = FNR }
  }
  next
}
FNR == 1 {
  capsrc = "unknown"; cap = ""
  if (capopt != "") { cap = capopt + 0; capsrc = "option" }
  else if (rejmin != "") { cap = rejmin + 0; capsrc = "rejection"; for (v in rejcap) capvals = capvals " " v }
  else if (envmin != "") { cap = envmin + 0; capsrc = "env"; for (v in envcap) capvals = capvals " " v }
}
$1 == "T" { close_seen(); next }
$1 == "M" { for (i = 1; i <= gn; i++) gseen[i] = 1; next }
$1 == "N" {
  id = agent_of()
  if (id == "" || adel[id] != FNR || !(id in amr)) next
  gn++; gid[gn] = id; gr[gn] = amr[id]; gts[gn] = $3; gep[gn] = $2; grun[gn] = running(FNR); gans[gn] = 0; gseen[gn] = 0
  sdel[amr[id]]++
  next
}
$1 == "A" {
  id = $5
  if (!(id in amr) || aseq[id] != FNR) next
  r = amr[id]; bn = abn[id]
  # Any call of the round answers its open deliveries: a new member, a re-send or a rejected spawn.
  for (i = 1; i <= gn; i++) if (gr[i] == r) gans[i] = 1
  if (ast[id] == "rej" || ast[id] == "err") next
  if ((r SUBSEP bn) in mem) next
  mem[r SUBSEP bn] = id
  if (!(r in batch)) { nrounds++; nbatches++; batch[r] = 1; next }
  if (sdel[r] > 0) { batch[r]++; nbatches++ }
  if (sunref[r] > 0) {
    nfind++
    printf "FINDING %s round=%s batch=%d exit=%s dispatch=%s running=%d cap=%d idle=%d gap=%ds unrefilled=%d\n", name, r, batch[r], suts[r], $3, surun[r], cap, cap - surun[r], $2 - suep[r], sunref[r]
  } else if (snocap[r] > 0) {
    nunk++; unkr[r]++
    printf "UNKNOWN-CAP %s round=%s batch=%d exit=%s dispatch=%s running=%d unrefilled=%d\n", name, r, batch[r], snts[r], $3, snrun[r], snocap[r]
  }
  sdel[r] = 0; sunref[r] = 0; snocap[r] = 0
}
END {
  close_seen(); for (i = 1; i <= gn; i++) gseen[i] = 1; close_seen()
  for (r in unkr) printf "UNKCAP-ROUND %s %d\n", r, unkr[r]
  printf "STAT rounds=%d batches=%d findings=%d unknown=%d agents=%d cap=%s capsrc=%s capvals=%s\n", nrounds, nbatches, nfind, nunk, nag, (cap == "" ? "unknown" : cap), capsrc, (capvals == "" ? "-" : substr(capvals, 2))
}
AWKEOF

# The prefilter. An exit record is read by its fields, so the prefilter keys on what those records
# carry -- `<task-id>` (every enqueue and delivery body) and `"kind":"task-notification"` (every
# delivery's origin) -- and never on the body's opening tag. Assistant records are all read, because a
# response is any assistant record; string-content user records are what start a turn. Every error
# tool_result is read (its is_error flag), so an Agent call a hook denied reads as "err" -- neither a
# member nor RUNNING -- instead of a dropped result that runs forever and makes its later real launch
# read as a re-send (case o). Extended
# regular expressions, one per line, under the C locale.
PREFILTER='"type":"assistant"
"role":"user","content":"
"name":"Agent"
"name":"Task"
<task-id>
"kind":"task-notification"
agentId
Concurrent subagent limit
"is_error": ?true
MAX_CONCURRENT_SUBAGENTS
"(content|text)":"[0-9]+(\\n)?"'

TMP="$(mktemp -d "${TMPDIR:-/tmp}/apwb.XXXXXX")" || { echo "$ME: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$TMP"' EXIT
printf '%s\n' "$PREFILTER" > "$TMP/tokens" || exit 2

# wave_replay <cap or empty> <trace 0|1> <file>: prints FINDING/UNKNOWN-CAP/TRACE/UNKCAP-ROUND lines and one STAT line.
wave_replay() {
  local rc
  LC_ALL=C grep -E -f "$TMP/tokens" -- "$3" > "$TMP/ev.raw"; rc=$?
  [ "$rc" -le 1 ] || return 2
  jq -R -r "$JQ_PROG" < "$TMP/ev.raw" > "$TMP/ev" || return 2
  awk -v capopt="$1" -v trace="$2" -v name="$(basename "$3")" "$AWK_PROG" "$TMP/ev" "$TMP/ev"
}

# --- seeds: records shaped on what the harness writes ---------------------------------------------------
# An exit is two records: the `queue-operation` enqueue when the agent exits, and the delivery, a `user`
# record with string content and origin.kind `task-notification`, when the lead is told. The body holds
# the children only; the envelope tag is never written.
_sj() { printf '%s\n' "$1" >> "$SEED_OUT"; }
_ag() { # ts msg tuid seatfile desc: a seat is spawned as its own role, the seat segment of its file
  local seat="${4%.md}"; seat="${seat%-[0-9]*}"; seat="${seat%-cross}"; seat="${seat##*-}"
  _sj '{"type":"assistant","timestamp":"'"$1"'","message":{"id":"'"$2"'","role":"assistant","content":[{"type":"tool_use","id":"'"$3"'","name":"Agent","input":{"subagent_type":"'"$seat"'","description":"'"$5"'","prompt":"Your operating contract is `.claude/team-roles/'"$seat"'.md`. Read it first.\n\nYou are a party-round SEAT. Read the shared brief and follow it exactly.\nWrite your findings file at: _bmad-output/party-mode/s900/'"$4"'\n","run_in_background":true}}]}}'
}
_cite() { # ts msg tuid subagent_type prompt: an Agent call that names a round path but is not a seat
  _sj '{"type":"assistant","timestamp":"'"$1"'","message":{"id":"'"$2"'","role":"assistant","content":[{"type":"tool_use","id":"'"$3"'","name":"Agent","input":{"subagent_type":"'"$4"'","description":"'"$4"' '"$3"'","prompt":"'"$5"'","run_in_background":true}}]}}'
}
_launched() { # ts tuid agentid
  _sj '{"type":"user","timestamp":"'"$1"'","message":{"role":"user","content":[{"tool_use_id":"'"$2"'","type":"tool_result","content":[{"type":"text","text":"Async agent launched successfully.\nagentId: '"$3"' (internal ID - do not mention to user.)\nThe agent is working in the background."}]}]},"toolUseResult":{"isAsync":true,"status":"async_launched","agentId":"'"$3"'"}}'
}
_rejected() { # ts tuid cap
  _sj '{"type":"user","timestamp":"'"$1"'","message":{"role":"user","content":[{"type":"tool_result","content":"Concurrent subagent limit reached. You can run '"$3"' subagents at once. Do not retry. If the user wants more concurrent subagents, ask them to increase CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS.","is_error":true,"tool_use_id":"'"$2"'"}]}}'
}
_body() { # agentid tuid summary
  printf '%s' '<task-id>'"$1"'</task-id>\n<tool-use-id>'"$2"'</tool-use-id>\n<status>completed</status>\n<summary>'"$3"'</summary>'
}
_enq() { # ts agentid tuid desc
  _sj '{"type":"queue-operation","operation":"enqueue","timestamp":"'"$1"'","content":"'"$(_body "$2" "$3" 'Agent \"'"$4"'\" finished')"'"}'
}
_deliv() { # ts agentid tuid desc
  _sj '{"type":"user","timestamp":"'"$1"'","message":{"role":"user","content":"'"$(_body "$2" "$3" 'Agent \"'"$4"'\" finished')"'"},"origin":{"kind":"task-notification","producer":"session-task"}}'
}
_note() { _enq "$@"; _deliv "$@"; } # ts agentid tuid desc
_attnote() { # ts agentid tuid desc: the mid-turn carrier, a queued_command attachment with attachment.origin.kind
  _enq "$@"
  _sj '{"type":"attachment","timestamp":"'"$1"'","attachment":{"type":"queued_command","prompt":"'"$(_body "$2" "$3" 'Agent \"'"$4"'\" finished')"'","origin":{"kind":"task-notification","producer":"session-task"}}}'
}
_bgdone() { # ts taskid tuid: a backgrounded beat finishing -- a delivery naming no agent, which starts a turn
  _sj '{"type":"queue-operation","operation":"enqueue","timestamp":"'"$1"'","content":"'"$(_body "$2" "$3" 'Background command \"join beat\" completed (exit code 0)')"'"}'
  _sj '{"type":"user","timestamp":"'"$1"'","message":{"role":"user","content":"'"$(_body "$2" "$3" 'Background command \"join beat\" completed (exit code 0)')"'"},"origin":{"kind":"task-notification","producer":"session-task"}}'
}
_bash() { # ts msg tuid command result
  _sj '{"type":"assistant","timestamp":"'"$1"'","message":{"id":"'"$2"'","role":"assistant","content":[{"type":"tool_use","id":"'"$3"'","name":"Bash","input":{"command":"'"$4"'"}}]}}'
  _sj '{"type":"user","timestamp":"'"$1"'","message":{"role":"user","content":[{"tool_use_id":"'"$3"'","type":"tool_result","content":"'"$5"'"}]}}'
}
_beat() { _bash "$1" "$2" "$3" "$4" "Command running in background with ID: b$3."; } # ts msg tuid command
_status() { _bash "$1" "$2" "$3" 'scripts/ai-dlc/wait-for-deliverable.sh --status _bmad-output/party-mode/s900/stories-dev-01.md' 'PENDING'; } # ts msg tuid
_envcap() { _bash "$1" msg_env toolu_env 'env | grep MAX_CONCURRENT' "CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS=$2"; } # ts cap
_printenv() { _bash "$1" msg_env toolu_env 'printenv CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS' "$2"; } # ts cap
_denied() { # ts tuid: a PreToolUse hook's deny of an Agent call -- an error result that is not a cap rejection
  _sj '{"type":"user","timestamp":"'"$1"'","message":{"role":"user","content":[{"type":"tool_result","content":"AI/DLC Rule 29: the pipeline is PAUSED -- an operator message is outstanding.","is_error":true,"tool_use_id":"'"$2"'"}]}}'
}
_ustr() { # ts flag text: a string-content user record carrying a harness flag (isCompactSummary)
  _sj '{"type":"user","timestamp":"'"$1"'","'"$2"'":true,"message":{"role":"user","content":"'"$3"'"}}'
}
_prose() { # ts msg text
  _sj '{"type":"assistant","timestamp":"'"$1"'","message":{"id":"'"$2"'","role":"assistant","content":[{"type":"text","text":"'"$3"'"}]}}'
}
SEED_BEAT='P=_bmad-output/party-mode/s900 && scripts/ai-dlc/wait-for-deliverable.sh --complete --dispatch aa01 --dispatch aa02 $P/stories-dev-0{1,2}.md'
SEED_BEAT4='scripts/ai-dlc/wait-for-deliverable.sh --complete _bmad-output/party-mode/s900/stories-dev-0{1,2,3,4}.md'
# _devs <ts> <n>: Dev 01..n in one message msg_1, all launched (ad1..adn).
_devs() { local i; i=0; while [ "$i" -lt "$2" ]; do i=$((i + 1)); _ag "$1" msg_1 "td$i" "stories-dev-0$i.md" "Dev seat story 0$i"; done
          i=0; while [ "$i" -lt "$2" ]; do i=$((i + 1)); _launched "$1" "td$i" "ad$i"; done; }
# _archs <ts> <msg> <from> <to>: Architect members in one message, all launched.
_archs() { local i; i=$(($3 - 1)); while [ "$i" -lt "$4" ]; do i=$((i + 1)); _ag "$1" "$2" "ta$i" "stories-architect-0$i.md" "Architect seat story 0$i"; done
           i=$(($3 - 1)); while [ "$i" -lt "$4" ]; do i=$((i + 1)); _launched "$1" "ta$i" "aa$i"; done; }
wave_seed() { # <case> <out>
  SEED_OUT="$2"; : > "$SEED_OUT" || return 2
  case "$1" in
    a|d)
      [ "$1" = a ] && _envcap 2026-01-01T10:00:00.000Z 4
      _ag 2026-01-01T10:00:01.000Z msg_1 toolu_d1 stories-dev-01.md "Dev seat story 01"
      _ag 2026-01-01T10:00:02.000Z msg_1 toolu_d2 stories-dev-02.md "Dev seat story 02"
      _launched 2026-01-01T10:00:03.000Z toolu_d1 aa01
      _launched 2026-01-01T10:00:03.000Z toolu_d2 aa02
      _beat 2026-01-01T10:00:10.000Z msg_2 toolu_w1 "$SEED_BEAT"
      _note 2026-01-01T10:05:00.000Z aa01 toolu_d1 "Dev seat story 01"
      _status 2026-01-01T10:05:01.000Z msg_s1 toolu_s1
      _note 2026-01-01T10:06:00.000Z aa02 toolu_d2 "Dev seat story 02"
      _ag 2026-01-01T10:07:00.000Z msg_3 toolu_r1 stories-architect-01.md "Architect seat story 01"
      _ag 2026-01-01T10:07:01.000Z msg_3 toolu_r2 stories-architect-02.md "Architect seat story 02"
      _launched 2026-01-01T10:07:02.000Z toolu_r1 ab01
      _launched 2026-01-01T10:07:02.000Z toolu_r2 ab02
      ;;
    b)
      _envcap 2026-01-01T10:00:00.000Z 2
      _ag 2026-01-01T10:00:01.000Z msg_1 toolu_d1 stories-dev-01.md "Dev seat story 01"
      _ag 2026-01-01T10:00:02.000Z msg_1 toolu_d2 stories-dev-02.md "Dev seat story 02"
      _launched 2026-01-01T10:00:03.000Z toolu_d1 aa01
      _launched 2026-01-01T10:00:03.000Z toolu_d2 aa02
      _prose 2026-01-01T10:00:05.000Z msg_1 "The other three seats follow once the harness cap is known from any rejections; I will join each wave before the next wave spawns."
      _note 2026-01-01T10:05:00.000Z aa01 toolu_d1 "Dev seat story 01"
      _ag 2026-01-01T10:05:02.000Z msg_3 toolu_r1 stories-architect-01.md "Architect seat story 01"
      _launched 2026-01-01T10:05:03.000Z toolu_r1 ab01
      _note 2026-01-01T10:06:00.000Z aa02 toolu_d2 "Dev seat story 02"
      _ag 2026-01-01T10:06:02.000Z msg_4 toolu_r2 stories-architect-02.md "Architect seat story 02"
      _launched 2026-01-01T10:06:03.000Z toolu_r2 ab02
      ;;
    c)
      _ag 2026-01-01T10:00:01.000Z msg_1 toolu_d1 stories-dev-01.md "Dev seat story 01"
      _ag 2026-01-01T10:00:02.000Z msg_1 toolu_d2 stories-dev-02.md "Dev seat story 02"
      _ag 2026-01-01T10:00:02.500Z msg_1 toolu_x1 stories-architect-01.md "Architect seat story 01"
      _launched 2026-01-01T10:00:03.000Z toolu_d1 aa01
      _launched 2026-01-01T10:00:03.000Z toolu_d2 aa02
      _rejected 2026-01-01T10:00:03.000Z toolu_x1 2
      _beat 2026-01-01T10:00:10.000Z msg_2 toolu_w1 "$SEED_BEAT"
      # Dev 01's exit is answered by re-sending the held spawn, which the harness rejects again; Dev 02's
      # by the re-dispatch that launches. A rejected call is a response: the harness, not the lead, held it.
      _note 2026-01-01T10:05:00.000Z aa01 toolu_d1 "Dev seat story 01"
      _ag 2026-01-01T10:05:01.000Z msg_r1 toolu_x1b stories-architect-01.md "Architect seat story 01"
      _rejected 2026-01-01T10:05:01.500Z toolu_x1b 2
      _note 2026-01-01T10:06:00.000Z aa02 toolu_d2 "Dev seat story 02"
      _ag 2026-01-01T10:06:02.000Z msg_3 toolu_r1 stories-architect-01.md "Architect seat story 01"
      _ag 2026-01-01T10:06:02.500Z msg_3 toolu_r2 stories-architect-02.md "Architect seat story 02"
      _launched 2026-01-01T10:06:03.000Z toolu_r1 ab01
      _launched 2026-01-01T10:06:03.000Z toolu_r2 ab02
      ;;
    e)
      local si=0 seat n f h ss beat
      _envcap 2026-01-01T09:00:00.000Z 42
      for seat in dev architect tea sm; do
        si=$((si + 1)); h="1$si"; beat='scripts/ai-dlc/wait-for-deliverable.sh --complete'
        [ "$si" -gt 1 ] && _bgdone "2026-01-01T$h:00:00.000Z" "bw$((si - 1))" "toolu_w$((si - 1))"
        n=0
        while [ "$n" -lt 25 ]; do
          n=$((n + 1)); ss="$(printf '%02d' "$n")"
          if [ "$n" -le 19 ]; then f="stories-$seat-$ss.md"; else f="stories-$seat-cross-$((n - 19)).md"; fi
          _ag "2026-01-01T$h:00:$ss.000Z" "msg_e$si" "toolu_e${si}_$ss" "$f" "$seat seat $f"
          beat="$beat _bmad-output/party-mode/s900/$f"
        done
        n=0
        while [ "$n" -lt 25 ]; do n=$((n + 1)); ss="$(printf '%02d' "$n")"; _launched "2026-01-01T$h:00:40.000Z" "toolu_e${si}_$ss" "e$si$ss"; done
        _beat "2026-01-01T$h:01:00.000Z" "msg_w$si" "toolu_w$si" "$beat"
        n=0
        while [ "$n" -lt 25 ]; do n=$((n + 1)); ss="$(printf '%02d' "$n")"
          _note "2026-01-01T$h:20:$ss.000Z" "e$si$ss" "toolu_e${si}_$ss" "$seat seat $ss"
          _prose "2026-01-01T$h:20:$ss.500Z" "msg_c$si$ss" "The live beat covers it."
        done
      done
      ;;
    f|g)
      _printenv 2026-01-01T10:00:00.000Z 4
      _devs 2026-01-01T10:00:01.000Z 4
      _beat 2026-01-01T10:00:10.000Z msg_2 tw1 "$SEED_BEAT4"
      if [ "$1" = f ]; then
        _note 2026-01-01T10:05:00.000Z ad1 td1 "Dev seat story 01"; _status 2026-01-01T10:05:00.500Z msg_s1 ts1
        _note 2026-01-01T10:05:01.000Z ad2 td2 "Dev seat story 02"; _status 2026-01-01T10:05:01.500Z msg_s2 ts2
        _note 2026-01-01T10:05:02.000Z ad3 td3 "Dev seat story 03"; _status 2026-01-01T10:05:02.500Z msg_s3 ts3
        _note 2026-01-01T10:40:00.000Z ad4 td4 "Dev seat story 04"
        _archs 2026-01-01T10:40:10.000Z msg_3 1 4
      else
        # Each exit's enqueue lands while the lead is mid-turn on something else; its delivery starts the
        # next turn, and that turn's first message refills the slot.
        # X6's own timeline: three exits at +5 min, the straggler at +40.
        local i hm
        for i in 1 2 3 4; do
          case "$i" in 1) hm=10:05:00 ;; 2) hm=10:05:10 ;; 3) hm=10:05:20 ;; *) hm=10:40:00 ;; esac
          _enq "2026-01-01T$hm.000Z" "ad$i" "td$i" "Dev seat story 0$i"
          _status "2026-01-01T$hm.200Z" "msg_s$i" "ts$i"
          _deliv "2026-01-01T$hm.500Z" "ad$i" "td$i" "Dev seat story 0$i"
          _archs "2026-01-01T$hm.800Z" "msg_r$i" "$i" "$i"
        done
      fi
      ;;
    h)
      _envcap 2026-01-01T10:00:00.000Z 10
      _devs 2026-01-01T10:00:01.000Z 4
      _attnote 2026-01-01T10:05:00.000Z ad1 td1 "Dev seat story 01"; _prose 2026-01-01T10:05:01.000Z msg_p1 "Dev 01 is in."
      _note 2026-01-01T10:06:00.000Z ad2 td2 "Dev seat story 02"; _prose 2026-01-01T10:06:01.000Z msg_p2 "Dev 02 is in."
      _note 2026-01-01T10:07:00.000Z ad3 td3 "Dev seat story 03"; _prose 2026-01-01T10:07:01.000Z msg_p3 "Dev 03 is in."
      _note 2026-01-01T10:40:00.000Z ad4 td4 "Dev seat story 04"
      _archs 2026-01-01T10:40:01.000Z msg_3 1 4
      ;;
    i|j)
      _envcap 2026-01-01T10:00:00.000Z 10
      _devs 2026-01-01T10:00:01.000Z 4
      _beat 2026-01-01T10:00:10.000Z msg_2 tw1 "$SEED_BEAT4"
      _note 2026-01-01T10:05:00.000Z ad1 td1 "Dev seat story 01"; _status 2026-01-01T10:05:00.500Z msg_s1 ts1
      _note 2026-01-01T10:06:00.000Z ad2 td2 "Dev seat story 02"; _status 2026-01-01T10:06:00.500Z msg_s2 ts2
      if [ "$1" = i ]; then
        _note 2026-01-01T10:07:00.000Z ad3 td3 "Dev seat story 03"; _status 2026-01-01T10:07:00.500Z msg_s3 ts3
        _bgdone 2026-01-01T10:40:00.000Z bw1 tw1
        _archs 2026-01-01T10:40:01.000Z msg_3 1 3
      else
        _bgdone 2026-01-01T10:40:00.000Z bw1 tw1
        _archs 2026-01-01T10:40:01.000Z msg_3 1 4
      fi
      ;;
    k)
      _devs 2026-01-01T10:00:01.000Z 4
      _ag 2026-01-01T10:00:05.000Z msg_1 tx1 stories-tea-01.md "TEA seat story 01"; _ag 2026-01-01T10:00:06.000Z msg_1 tx2 stories-tea-02.md "TEA seat story 02"
      _rejected 2026-01-01T10:00:07.000Z tx1 4; _rejected 2026-01-01T10:00:07.000Z tx2 4
      _beat 2026-01-01T10:00:10.000Z msg_2 tw1 "$SEED_BEAT4"
      _note 2026-01-01T10:05:00.000Z ad1 td1 "Dev seat story 01"; _note 2026-01-01T10:05:01.000Z ad2 td2 "Dev seat story 02"; _note 2026-01-01T10:05:02.000Z ad3 td3 "Dev seat story 03"
      _beat 2026-01-01T10:05:10.000Z msg_4 tw2 'scripts/ai-dlc/wait-for-deliverable.sh --complete _bmad-output/party-mode/s900/stories-dev-04.md'
      _archs 2026-01-01T10:05:20.000Z msg_5 1 2
      ;;
    l)
      _envcap 2026-01-01T10:00:00.000Z 4
      _devs 2026-01-01T10:00:01.000Z 4
      _beat 2026-01-01T10:00:10.000Z msg_2 tw1 "$SEED_BEAT4"
      _note 2026-01-01T10:05:01.000Z ad1 td1 "Dev seat story 01"; _note 2026-01-01T10:05:02.000Z ad2 td2 "Dev seat story 02"
      _note 2026-01-01T10:05:03.000Z ad3 td3 "Dev seat story 03"; _note 2026-01-01T10:05:04.000Z ad4 td4 "Dev seat story 04"
      _archs 2026-01-01T10:05:11.000Z msg_3 1 4
      ;;
    m)
      _envcap 2026-01-01T10:00:00.000Z 2
      _devs 2026-01-01T10:00:01.000Z 2
      _enq 2026-01-01T10:05:00.000Z ad1 td1 "Dev seat story 01"
      _archs 2026-01-01T10:05:01.000Z msg_r1 1 1
      _deliv 2026-01-01T10:05:02.000Z ad1 td1 "Dev seat story 01"
      _status 2026-01-01T10:05:03.000Z msg_s1 ts1
      _note 2026-01-01T10:06:00.000Z ad2 td2 "Dev seat story 02"
      _archs 2026-01-01T10:06:01.000Z msg_r2 2 2
      ;;
    n)
      _envcap 2026-01-01T10:00:00.000Z 4
      _devs 2026-01-01T10:00:01.000Z 2
      _note 2026-01-01T10:05:00.000Z ad1 td1 "Dev seat story 01"; _status 2026-01-01T10:05:00.500Z msg_s1 ts1
      _note 2026-01-01T10:06:00.000Z ad2 td2 "Dev seat story 02"
      _ag 2026-01-01T10:06:01.000Z msg_3 td1b stories-dev-01.md "Dev seat story 01 (missing, re-sent)"
      _launched 2026-01-01T10:06:02.000Z td1b ad1b
      ;;
    o)
      _envcap 2026-01-01T10:00:00.000Z 4
      _devs 2026-01-01T10:00:01.000Z 2
      _ag 2026-01-01T10:00:02.000Z msg_x tx1 stories-architect-01.md "Architect seat story 01"
      _denied 2026-01-01T10:00:02.500Z tx1
      _note 2026-01-01T10:05:00.000Z ad1 td1 "Dev seat story 01"; _status 2026-01-01T10:05:00.500Z msg_s1 ts1
      _note 2026-01-01T10:40:00.000Z ad2 td2 "Dev seat story 02"
      _archs 2026-01-01T10:40:01.000Z msg_3 1 1
      ;;
    p)
      _devs 2026-01-01T10:00:01.000Z 2
      _ag 2026-01-01T10:00:02.000Z msg_x tx1 stories-architect-01.md "Architect seat story 01"
      _ag 2026-01-01T10:00:02.000Z msg_x tx2 stories-architect-02.md "Architect seat story 02"
      _rejected 2026-01-01T10:00:03.000Z tx1 3; _rejected 2026-01-01T10:00:03.000Z tx2 3
      _note 2026-01-01T10:05:00.000Z ad1 td1 "Dev seat story 01"; _status 2026-01-01T10:05:00.500Z msg_s1 ts1
      _note 2026-01-01T10:40:00.000Z ad2 td2 "Dev seat story 02"
      _archs 2026-01-01T10:40:01.000Z msg_3 1 1
      ;;
    q)
      _envcap 2026-01-01T10:00:00.000Z 4
      _devs 2026-01-01T10:00:01.000Z 2
      _note 2026-01-01T10:05:00.000Z ad1 td1 "Dev seat story 01"; _prose 2026-01-01T10:05:01.000Z msg_p1 "Dev 01 is in; refilling."
      _ustr 2026-01-01T10:05:02.000Z isCompactSummary "This session is being continued from a previous conversation that ran out of context."
      _archs 2026-01-01T10:05:03.000Z msg_r1 1 1
      _note 2026-01-01T10:06:00.000Z ad2 td2 "Dev seat story 02"
      _archs 2026-01-01T10:06:01.000Z msg_r2 2 2
      ;;
    r)
      _envcap 2026-01-01T10:00:00.000Z 4
      _devs 2026-01-01T10:00:01.000Z 2
      _note 2026-01-01T10:05:00.000Z ad1 td1 "Dev seat story 01"
      _sj '{"type":"assistant","isSidechain":true,"timestamp":"2026-01-01T10:05:01.000Z","message":{"id":"msg_sc","role":"assistant","content":[{"type":"tool_use","id":"tsc","name":"Agent","input":{"subagent_type":"architect","prompt":"Write your findings file at: _bmad-output/party-mode/s900/stories-architect-09.md"}}]}}'
      _status 2026-01-01T10:05:02.000Z msg_s1 ts1
      _note 2026-01-01T10:40:00.000Z ad2 td2 "Dev seat story 02"
      _archs 2026-01-01T10:40:01.000Z msg_3 1 1
      ;;
    s)
      _devs 2026-01-01T10:00:01.000Z 3
      _ag 2026-01-01T10:00:02.000Z msg_x1 tx1 stories-architect-01.md "Architect seat story 01"; _rejected 2026-01-01T10:00:03.000Z tx1 5
      _ag 2026-01-01T10:00:04.000Z msg_x2 tx2 stories-architect-02.md "Architect seat story 02"; _rejected 2026-01-01T10:00:05.000Z tx2 3
      _note 2026-01-01T10:05:00.000Z ad1 td1 "Dev seat story 01"; _status 2026-01-01T10:05:00.500Z msg_s1 ts1
      _note 2026-01-01T10:40:00.000Z ad2 td2 "Dev seat story 02"
      _archs 2026-01-01T10:40:01.000Z msg_3 1 1
      ;;
    t)
      _envcap 2026-01-01T10:00:00.000Z 4
      _devs 2026-01-01T10:00:01.000Z 2
      _note 2026-01-01T10:05:00.000Z ad1 td1 "Dev seat story 01"
      _cite 2026-01-01T10:05:01.000Z msg_t1 tt1 remediator 'part path: _bmad-output/s900/shards/party-repair-p1/1.md\nYour findings: every finding in _bmad-output/party-mode/s900/stories-dev-01.md'
      _cite 2026-01-01T10:05:01.000Z msg_t1 tt2 code-reviewer 'Review the seat findings in _bmad-output/party-mode/s900/stories-dev-02.md'
      _cite 2026-01-01T10:05:01.000Z msg_t1 tt3 adversary 'Write your findings file at: _bmad-output/party-mode/s900/stories-adversary-01.md'
      _cite 2026-01-01T10:05:01.000Z msg_t1 tt4 general-purpose 'Summarise the seat findings in _bmad-output/party-mode/s900/stories-sm-01.md'
      _launched 2026-01-01T10:05:02.000Z tt1 at1; _launched 2026-01-01T10:05:02.000Z tt2 at2; _launched 2026-01-01T10:05:02.000Z tt3 at3; _launched 2026-01-01T10:05:02.000Z tt4 at4
      _status 2026-01-01T10:05:03.000Z msg_s1 ts1
      _note 2026-01-01T10:40:00.000Z ad2 td2 "Dev seat story 02"
      _archs 2026-01-01T10:40:01.000Z msg_3 1 1
      ;;
    *) return 2 ;;
  esac
}

# wave_selfprobe: every case must answer as the header says before a corpus result is reported.
wave_selfprobe() {
  local c out f u s failed=0
  mkdir -p "$TMP/probe" || return 2
  for c in $SEED_CASES; do
    wave_seed "$c" "$TMP/probe/$c.jsonl" || { echo "$ME: self-probe FAILED: case $c could not be seeded" >&2; return 2; }
    out="$(wave_replay "" 0 "$TMP/probe/$c.jsonl")" || { echo "$ME: self-probe FAILED: case $c did not replay" >&2; return 2; }
    f="$(grep -c '^FINDING ' <<<"$out")" || f=0
    u="$(grep -c '^UNKNOWN-CAP ' <<<"$out")" || u=0
    s="$(grep '^STAT ' <<<"$out")"
    case "$c" in
      a) [ "$f" = 1 ] && [ "$u" = 0 ] && grep -q ' running=1 cap=4 idle=3 ' <<<"$out" ;;
      b) [ "$f" = 0 ] && [ "$u" = 0 ] && grep -q ' agents=4 ' <<<"$s" && grep -q ' cap=2 ' <<<"$s" ;;
      c) [ "$f" = 0 ] && [ "$u" = 0 ] && grep -q ' batches=2 ' <<<"$s" && grep -q ' capsrc=rejection ' <<<"$s" ;;
      d) [ "$f" = 0 ] && [ "$u" = 1 ] && grep -q '^UNKCAP-ROUND s900/stories 1$' <<<"$out" ;;
      e) [ "$f" = 3 ] && [ "$u" = 0 ] && [ "$(grep -c ' running=24 cap=42 idle=18 ' <<<"$out")" = 3 ] && grep -q ' agents=100 ' <<<"$s" ;;
      f) [ "$f" = 1 ] && [ "$u" = 0 ] && grep -q ' running=3 cap=4 idle=1 ' <<<"$out" && grep -q ' capsrc=env ' <<<"$s" ;;
      g) [ "$f" = 0 ] && [ "$u" = 0 ] && grep -q ' batches=5 ' <<<"$s" && grep -q ' cap=4 ' <<<"$s" ;;
      h|i|j) [ "$f" = 1 ] && [ "$u" = 0 ] && grep -q ' running=3 cap=10 idle=7 ' <<<"$out" ;;
      k) [ "$f" = 0 ] && [ "$u" = 0 ] && grep -q ' batches=2 ' <<<"$s" && grep -q ' capsrc=rejection ' <<<"$s" ;;
      l) [ "$f" = 0 ] && [ "$u" = 0 ] && grep -q ' batches=2 ' <<<"$s" ;;
      m) [ "$f" = 0 ] && [ "$u" = 0 ] && grep -q ' batches=2 ' <<<"$s" && grep -q ' agents=4 ' <<<"$s" ;;
      n) [ "$f" = 0 ] && [ "$u" = 0 ] && grep -q ' agents=3 ' <<<"$s" && grep -q ' batches=1 ' <<<"$s" ;;
      o) [ "$f" = 1 ] && [ "$u" = 0 ] && grep -q ' running=1 cap=4 idle=3 ' <<<"$out" && grep -q ' batches=2 ' <<<"$s" ;;
      p) [ "$f" = 1 ] && [ "$u" = 0 ] && grep -q ' running=1 cap=3 idle=2 ' <<<"$out" && grep -q ' capsrc=rejection ' <<<"$s" ;;
      q) [ "$f" = 0 ] && [ "$u" = 0 ] && grep -q ' batches=3 ' <<<"$s" ;;
      r) [ "$f" = 1 ] && [ "$u" = 0 ] && grep -q ' running=1 cap=4 idle=3 ' <<<"$out" && grep -q ' agents=3 ' <<<"$s" ;;
      s) [ "$f" = 1 ] && [ "$u" = 0 ] && grep -q ' running=2 cap=3 idle=1 ' <<<"$out" && grep -q ' capsrc=rejection ' <<<"$s" ;;
      t) [ "$f" = 1 ] && [ "$u" = 0 ] && grep -q ' running=1 cap=4 idle=3 ' <<<"$out" && grep -q ' agents=7 ' <<<"$s" ;;
    esac || { echo "$ME: self-probe FAILED: case $c (findings=$f unknown-cap=$u; $s)" >&2; failed=1; }
  done
  [ "$failed" = 0 ] || return 2
  echo "$ME: self-probe: ok ($(echo $SEED_CASES | wc -w | tr -d ' ') cases)" >&2
}

# --- arguments ---------------------------------------------------------------------------------------
CAP=""; TRACE=0; SEEDS=0
FILES=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --cap) [ "$#" -ge 2 ] || usage "--cap needs a value"
           case "$2" in ''|*[!0-9]*) usage "--cap takes a positive integer" ;; esac
           [ "$2" -gt 0 ] || usage "--cap takes a positive integer"
           CAP="$2"; shift 2 ;;
    --trace) TRACE=1; shift ;;
    --seed) [ "$#" -ge 3 ] || usage "--seed needs <case> <out>"
            case " $SEED_CASES " in *" $2 "*) ;; *) usage "--seed takes one of: $SEED_CASES" ;; esac
            wave_seed "$2" "$3" || { echo "$ME: could not write $3" >&2; exit 2; }
            SEEDS=$((SEEDS + 1)); shift 3 ;;
    --) shift; while [ "$#" -gt 0 ]; do FILES+=("$1"); shift; done ;;
    -*) usage "unknown option $1" ;;
    *) FILES+=("$1"); shift ;;
  esac
done
if [ "$SEEDS" -gt 0 ]; then [ "${#FILES[@]}" -eq 0 ] || usage "--seed takes no transcripts"; exit 0; fi
[ "${#FILES[@]}" -gt 0 ] || usage "no transcript given"

wave_selfprobe || exit 2

GIVEN=${#FILES[@]}; SCANNED=0; ROUNDS=0; BATCHES=0; FINDINGS=0; UNKNOWN=0; BAD=0
for f in "${FILES[@]}"; do
  if [ ! -r "$f" ] || [ ! -s "$f" ] || ! head -n 1 "$f" | jq -e 'type == "object"' >/dev/null 2>&1; then
    echo "$ME: not scanned (unreadable, empty, or not JSONL): $f" >&2; BAD=$((BAD + 1)); continue
  fi
  out="$(wave_replay "$CAP" "$TRACE" "$f")" || { echo "$ME: not scanned (replay failed): $f" >&2; BAD=$((BAD + 1)); continue; }
  SCANNED=$((SCANNED + 1))
  grep -v -e '^STAT ' -e '^UNKCAP-ROUND ' <<<"$out"
  while read -r _ ur un; do
    [ -n "${ur:-}" ] && echo "$ME: UNKNOWN-CAP session=$(basename "$f") round=$ur unjudged=$un" >&2
  done <<<"$(grep '^UNKCAP-ROUND ' <<<"$out")"
  st="$(grep '^STAT ' <<<"$out")"
  n="$(sed -n 's/.* rounds=\([0-9]*\) .*/\1/p' <<<"$st")"; ROUNDS=$((ROUNDS + ${n:-0}))
  n="$(sed -n 's/.* batches=\([0-9]*\) .*/\1/p' <<<"$st")"; BATCHES=$((BATCHES + ${n:-0}))
  n="$(sed -n 's/.* findings=\([0-9]*\) .*/\1/p' <<<"$st")"; FINDINGS=$((FINDINGS + ${n:-0}))
  n="$(sed -n 's/.* unknown=\([0-9]*\) .*/\1/p' <<<"$st")"; UNKNOWN=$((UNKNOWN + ${n:-0}))
  [ "$TRACE" = 1 ] && echo "$ME: $(basename "$f") $st" >&2
done
echo "$ME: given=$GIVEN scanned=$SCANNED rounds=$ROUNDS batches=$BATCHES findings=$FINDINGS unknown-cap=$UNKNOWN" >&2
[ "$SCANNED" -eq "$GIVEN" ] && [ "$BAD" -eq 0 ] || exit 2
[ "$FINDINGS" -eq 0 ] || exit 1
exit 0
