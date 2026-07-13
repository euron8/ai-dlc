#!/bin/bash
#
# AI/DLC Operator Steering-Budget Validator (Rule 29)
#
# WHY THIS EXISTS
# Claude Code delivers a queued operator message at a TOOL-CALL BOUNDARY -- it
# rides in alongside the next tool result. A long turn is therefore harmless on
# its own; what starves the operator is a long SINGLE tool call. While one is in
# flight there is no boundary, so the message cannot land. The blind window is
# exactly the duration of the in-flight foreground call.
#
# Measured on 278 graph sessions before this rule existed:
#   Agent  n=1650   p50 28s  p90 5.0m  p99 16.5m  max 36.2m   (417 calls > 2m)
#   Bash   n=12130  p50  0s  p90   3s  p99  3.3m  max 10.0m   (181 calls > 2m)
#
# Agent is the ONLY unbounded foreground primitive. Bash and TaskOutput are
# already capped by the harness at 10 minutes (their max timeout is 600000ms),
# and AskUserQuestion's duration is the human's own think-time. That leaves the
# Agent call as the single mechanism by which ai-dlc can hold the operator's
# message hostage -- and ai-dlc used to MANDATE it: implementation.md's old
# "Foreground-dispatch mandate" required gated dev dispatch to be a blocking
# Agent call and forbade run_in_background. Rule 29 replaced it with the
# bounded-join: dispatch in background, then join in <=budget beats. This script
# is the commit-time / gate-time guard that the bounded-join is actually being
# used, because a lead that reverts to a blocking dispatch reintroduces a
# 36-minute window in which the operator cannot be heard.
#
# WHAT IT CHECKS (a session transcript, JSONL)
#   A. STARVATION. Any FOREGROUND tool call whose wall-clock exceeds the budget.
#      A foreground call is one without run_in_background:true.
#   B. STEAMROLL. Any operator message followed by a pipeline-ADVANCING tool call
#      (Agent/Task/Skill/TaskCreate, or a write under _bmad-output/) issued BEFORE
#      the lead clears the pause flag. ai-dlc-pause.sh sets the flag on every
#      operator message and the contract is "do not execute pipeline steps while
#      the flag exists"; the sanctioned exit is an explicit
#      `rm ... pipeline-paused.flag`. So an advancing call with no preceding rm is
#      the lead receiving a steer and executing straight through it.
#
#      NOTE: an earlier draft of this check treated ANY assistant text as
#      acknowledgement. That is circular -- the lead almost always emits some
#      narration, so the check passed on a corpus that provably contains the
#      failure. Do not reintroduce it. The flag lifecycle is the invariant, not
#      the presence of prose.
#   D. WRONG JOIN API. A TaskOutput call that failed with "No task found with ID".
#      `Agent` returns an `agent_id` (<name>@session-<id>); `TaskOutput` joins a
#      `task_id`, which only `TaskCreate` produces. TaskOutput CANNOT join an Agent.
#      Rule 29 used to prescribe exactly that, so the lead burned a call, learned
#      nothing, and fell back to a filesystem wait. Corpus: 137 TaskOutput successes
#      (all on real TaskCreate tasks), 18 failures (all agent names).
#      The join for a teammate is the deliverable -- Rule 29's bounded file-wait beat.
#   C. UNBOUNDED WAIT. More than max_wait_beats consecutive FOREGROUND wait-shaped
#      Bash calls with no intervening re-dispatch. This is the hole Check A cannot
#      see: A bounds a single CALL, so a lead that polls the filesystem in
#      110-second slices forever is compliant with A while advancing nothing.
#      Rule 29's bounded file-wait beat bounds the SEQUENCE too -- on exhaustion
#      the deliverable is absent, which Rule 20 already calls non-delivery, so the
#      lead re-dispatches (an advancing call, which resets the run) or HARD_BLOCKs.
#
# EXEMPT FROM CHECK A
#   AskUserQuestion -- its duration is the HUMAN's think-time, not machine
#   starvation. The lead is waiting ON the operator, not blocking them. Counting
#   it would flag every checkpoint as a violation.
#
# NOT AN OPERATOR MESSAGE (excluded from check B)
#   The auto-compaction resume prompt ("This session is being continued from a
#   previous conversation..."). It is a HARNESS injection, not a human steer, and
#   the lead advancing straight after it is the POST-COMPACT RECOVERY PROTOCOL
#   working as designed. Counting it inverted the check's meaning: 19 of 114
#   "steamrolls" in the reference consumer corpus (16.7%) were this phantom. Same
#   class of error as the circular-acknowledgement draft above -- a machine event
#   read as a human one. Do not reintroduce it.
#
# A BLOCKED ATTEMPT IS NOT A STEAMROLL (excluded from check B)
#   When ai-dlc-acknowledge.sh DENIES an advancing call, the tool_use still appears
#   in the transcript -- the deny lands on the tool_result (is_error:true, carrying
#   "AI/DLC Rule 29: the pipeline is PAUSED"). A check that reads tool_use and never
#   looks at the result therefore counts the BLOCKED attempt and reports "the lead
#   received the steer and executed straight through it" about a call that never
#   executed. That is the hook WORKING, reported as the failure the hook prevents.
#
#   This was live: the reference consumer's first post-v0.45.0 sessions showed 2
#   "steamrolls", and the flow log showed 3 ACK_DENIED events at the same moments.
#   The hook had stopped every one. Check B now scores OUTCOMES, not attempts.
#
#   Note what this does to the old remedy text, which said "if these violations are
#   recent, the hook is not installed." That advice was exactly backwards: a working
#   hook MANUFACTURED the violations. Do not restore it.
#
# USAGE
#   core/scripts/validate-steering-budget.sh --transcript PATH [--quiet]
#   core/scripts/validate-steering-budget.sh --dir PATH [--quiet]   # scan a corpus
#   core/scripts/validate-steering-budget.sh --transcript PATH --count
#       Print ONLY the total violation count (A+B+C+D) as a bare integer, exit 0.
#       gate-validation.md Check 25 needs an integer to compare against the count
#       the previous gate recorded; it must not have to grep one out of prose.
#
# ENV OVERRIDES
#   AI_DLC_STEERING_BUDGET  max foreground block, seconds   (default 120)
#   AI_DLC_STEERING_GRACE   jitter allowance, seconds       (default 30)
#   AI_DLC_MAX_WAIT_BEATS   max consecutive wait beats      (default 10)
#
# EXIT
#   0  no foreground call exceeded the budget; no steamrolled operator message;
#      no unbounded wait sequence
#   1  a violation was found, or input unreadable

set -u

BUDGET="${AI_DLC_STEERING_BUDGET:-120}"
GRACE="${AI_DLC_STEERING_GRACE:-30}"
MAX_BEATS="${AI_DLC_MAX_WAIT_BEATS:-10}"
TRANSCRIPT=""
DIR=""
QUIET=0
COUNT=0

while [ $# -gt 0 ]; do
  case "$1" in
    --transcript) TRANSCRIPT="${2:-}"; shift 2 ;;
    --dir)        DIR="${2:-}"; shift 2 ;;
    --quiet)      QUIET=1; shift ;;
    --count)      COUNT=1; shift ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

say(){ [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

if [ -z "$TRANSCRIPT" ] && [ -z "$DIR" ]; then
  echo "FAIL: pass --transcript PATH or --dir PATH" >&2
  exit 1
fi
if [ -n "$TRANSCRIPT" ] && [ ! -r "$TRANSCRIPT" ]; then
  echo "FAIL: transcript not readable: $TRANSCRIPT" >&2
  exit 1
fi
if [ -n "$DIR" ] && [ ! -d "$DIR" ]; then
  echo "FAIL: dir not readable: $DIR" >&2
  exit 1
fi

command -v node >/dev/null 2>&1 || { echo "FAIL: node is required" >&2; exit 1; }

THRESHOLD=$(( BUDGET + GRACE ))

AI_DLC_T="$TRANSCRIPT" AI_DLC_D="$DIR" AI_DLC_TH="$THRESHOLD" AI_DLC_B="$BUDGET" AI_DLC_MB="$MAX_BEATS" AI_DLC_Q="$QUIET" AI_DLC_C="$COUNT" node <<'NODE'
const fs = require("fs"), path = require("path");
const TH = +process.env.AI_DLC_TH, BUDGET = +process.env.AI_DLC_B;
const MAX_BEATS = +process.env.AI_DLC_MB;
const QUIET = process.env.AI_DLC_Q === "1";
const COUNT = process.env.AI_DLC_C === "1";
const one = process.env.AI_DLC_T, dir = process.env.AI_DLC_D;

// AskUserQuestion measures the human's think-time, not machine starvation.
const EXEMPT = new Set(["AskUserQuestion"]);
const ADVANCING = new Set(["Agent", "Task", "Skill", "TaskCreate"]);

// `_bmad-output/ai-dlc-update/**` is the UPDATER's own scratch space (reconcile
// report, push-candidate ledger), not pipeline output. /ai-dlc-update is a
// different skill from /ai-dlc: it does not advance a sprint, and it runs precisely
// when the pipeline is NOT running. Writing its reconcile report while an operator
// message is outstanding is not steamrolling a pipeline -- there is no pipeline.
// Observed live: the updater's own report write was scored as a Rule 29 steamroll.
const isPipelineArtifact = (fp) =>
  /(^|\/)_bmad-output\//.test(fp) && !/(^|\/)_bmad-output\/ai-dlc-update\//.test(fp);

const isAdvancing = (b) => ADVANCING.has(b.name) ||
  (/^(Write|Edit|MultiEdit|NotebookEdit)$/.test(b.name) &&
   isPipelineArtifact(b.input?.file_path || ""));

// A wait BEAT is a foreground Bash call that sleeps AND file-tests a
// _bmad-output/ path. All three clauses are load-bearing, and each was added
// because the looser version misfired on the reference corpus (405 foreground
// wait calls):
//
//   sleeps                -- the signal that it is WAITING. We do not enumerate
//                            spellings (until / while / for+seq); that would just
//                            be a list of the ones we happened to have seen.
//   names _bmad-output/   -- scopes this to PIPELINE deliverables. Rule 29's
//                            file-wait beat exists because an absent deliverable
//                            is Rule 20 NON-DELIVERY, whose remedy is re-dispatch.
//                            A lead polling a deploy, a `gh pr` merge state, or an
//                            ECS task is in no such situation -- there is nothing
//                            to re-dispatch and 10 beats is the wrong ceiling for a
//                            rollout. 323 of the 405 are these; bounding them would
//                            be the validator inventing a rule ai-dlc never made.
//   file-existence test   -- distinguishes waiting ON a deliverable from merely
//                            TEE-ING a log into _bmad-output/ while polling
//                            something else. Without it, 51 of 78 remaining hits
//                            were `gh pr create`, flag removal, and log tails.
const isWaitBeat = (b) => b.name === "Bash" &&
  b.input?.run_in_background !== true &&
  /\bsleep\s+\d/.test(b.input?.command || "") &&
  /_bmad-output\//.test(b.input?.command || "") &&
  /(\[\s*-[sfe]\s|test\s+-[sfe]\s)/.test(b.input?.command || "");

// The auto-compact resume prompt is a harness injection, not an operator steer.
// See "NOT AN OPERATOR MESSAGE" in the header before touching this.
const isCompactResume = (t) =>
  /^This session is being continued from a previous conversation/.test(t);

// A call the ai-dlc-acknowledge.sh PreToolUse hook DENIED. It surfaces as a
// tool_result with is_error:true carrying the hook's reason. The lead attempted to
// advance and was STOPPED -- that is the mechanism working, not a steamroll. See
// "A BLOCKED ATTEMPT IS NOT A STEAMROLL" in the header.
const DENY_MARK = /AI\/DLC Rule 29: the pipeline is PAUSED/;
const isDenied = (b) => {
  if (!b || b.is_error !== true) return false;
  const raw = typeof b.content === "string" ? b.content : JSON.stringify(b.content || "");
  return DENY_MARK.test(raw);
};

const files = one ? [one]
  : fs.readdirSync(dir).filter(f => f.endsWith(".jsonl")).map(f => path.join(dir, f));

const starv = [], steam = [], unbounded = [], wrongjoin = [];

// A TaskOutput handed an agent_id. The harness says so in the error, verbatim.
const NO_TASK = /No task found with ID:\s*([^<\n"]+)/;

for (const f of files) {
  let recs;
  try {
    recs = fs.readFileSync(f, "utf8").split("\n").filter(Boolean)
      .map(l => { try { return JSON.parse(l); } catch { return null; } })
      .filter(Boolean).filter(r => !r.isSidechain);
  } catch { continue; }

  // ---- Check A: foreground calls that exceed the budget -------------------
  const use = {}, res = {}, denied = new Set();
  for (const r of recs) {
    const c = r.message?.content;
    if (!Array.isArray(c)) continue;
    for (const b of c) {
      if (b.type === "tool_use")
        use[b.id] = { n: b.name, t: Date.parse(r.timestamp), bg: b.input?.run_in_background === true };
      if (b.type === "tool_result") {
        res[b.tool_use_id] = Date.parse(r.timestamp);
        if (isDenied(b)) denied.add(b.tool_use_id);   // the hook stopped this one
        // ---- Check D: TaskOutput handed an agent_id ------------------------
        if (use[b.tool_use_id]?.n === "TaskOutput") {
          const raw = typeof b.content === "string" ? b.content : JSON.stringify(b.content || "");
          const m = NO_TASK.exec(raw);
          if (m) wrongjoin.push({ f: path.basename(f), id: m[1].trim().slice(0, 48) });
        }
      }
    }
  }
  for (const [id, u] of Object.entries(use)) {
    if (u.bg || EXEMPT.has(u.n) || !res[id]) continue;
    const s = (res[id] - u.t) / 1000;
    if (s > TH) starv.push({ f: path.basename(f), n: u.n, s });
  }

  // ---- Check B: operator message steamrolled by a pipeline-advancing call --
  for (let i = 0; i < recs.length; i++) {
    const r = recs[i];
    if (r.type !== "user") continue;
    const c = r.message?.content;
    if (Array.isArray(c) && c.some(b => b.type === "tool_result")) continue;
    let txt = typeof c === "string" ? c
      : Array.isArray(c) ? c.map(b => (b.type === "text" ? b.text : "")).join(" ") : "";
    txt = (txt || "").replace(/<system-reminder>[\s\S]*?<\/system-reminder>/g, "").trim();
    if (!txt) continue;
    // Not a human steer: harness/system injections and teammate traffic.
    // "Another Claude session sent a message" wraps SendMessage traffic from a
    // teammate -- machine, not operator. Counting it would inflate check B.
    if (/^(<task-notification|<local-command|<command-|<agent-message|<teammate-message|Caveat:|\[Request interrupted|## Context Usage|Stop hook feedback|Base directory|Another Claude session sent a message)/.test(txt)) continue;
    if (/<teammate-message/.test(txt)) continue;
    // Not a human steer: the harness's own auto-compaction resume prompt. The
    // lead advancing right after it is the recovery protocol, not a steamroll.
    if (isCompactResume(txt)) continue;

    // Walk forward: does the lead ADVANCE the pipeline before it clears the
    // pause flag? The flag -- not the presence of narration -- is the contract.
    for (let j = i + 1; j < recs.length; j++) {
      const rr = recs[j];
      if (rr.type === "user") {
        const cc = rr.message?.content;
        if (!(Array.isArray(cc) && cc.some(b => b.type === "tool_result"))) break; // next human msg
        continue;
      }
      if (rr.type !== "assistant") continue;
      const cc = rr.message?.content;
      if (!Array.isArray(cc)) continue;
      const uses = cc.filter(b => b.type === "tool_use");
      // The sanctioned resume: an explicit rm of the pause flag.
      const cleared = uses.some(b => b.name === "Bash" &&
        /rm\b[^\n]*pipeline-paused\.flag/.test(b.input?.command || ""));
      // A DENIED advancing call is not a steamroll -- the lead tried and the hook
      // stopped it. Counting the attempt inverts the check's meaning: it reports
      // "executed straight through it" about a call that never executed.
      const adv = uses.filter(isAdvancing).find(b => !denied.has(b.id));
      if (adv && !cleared) {
        steam.push({ f: path.basename(f), tool: adv.name, msg: txt.slice(0, 60).replace(/\n/g, " ") });
        break;
      }
      if (cleared) break; // flag released before advancing -- correct
    }
  }

  // ---- Check C: an unbounded run of wait beats ------------------------------
  // Rule 29 bounds the sequence, not only the call. A re-dispatch (any advancing
  // call) is the sanctioned exit from a wait, so it resets the run.
  let run = 0, firstCmd = "";
  for (const r of recs) {
    if (r.type !== "assistant") continue;
    const c = r.message?.content;
    if (!Array.isArray(c)) continue;
    for (const b of c) {
      if (b.type !== "tool_use") continue;
      if (isWaitBeat(b)) {
        if (run === 0) firstCmd = (b.input.command || "").replace(/\s+/g, " ").slice(0, 64);
        run++;
        if (run === MAX_BEATS + 1)
          unbounded.push({ f: path.basename(f), beats: run, cmd: firstCmd });
        else if (run > MAX_BEATS + 1)
          unbounded[unbounded.length - 1].beats = run;   // same run, still growing
      } else if (isAdvancing(b)) {
        run = 0;  // re-dispatched (or moved on) -- the wait ended legitimately
      }
    }
  }
}

// --count: emit ONLY the total violation count, as a bare integer, and exit 0.
// gate-validation.md Check 25 compares this number against the one the previous
// gate recorded. It needs an INTEGER, and the alternative -- having a markdown
// step file grep a count out of an English sentence on stderr -- is the
// hand-rolled pipe that verdict.sh exists to kill (`cmd | grep` takes grep's exit
// status, so a validator that prints FAIL and exits 1 reads as a pass). The gate
// asks a different question from the validator's own PASS/FAIL ("how many?" vs
// "any?"), so it needs its own answer, not a parse of someone else's.
if (COUNT) {
  console.log(starv.length + steam.length + unbounded.length + wrongjoin.length);
  process.exit(0);
}

const log = (...a) => { if (!QUIET) console.log(...a); };
log(`steering budget     : ${BUDGET}s (foreground calls may not block longer)`);
log(`transcripts scanned : ${files.length}`);
log(`exempt from check A : AskUserQuestion (human think-time, not starvation)`);
log("");

let bad = false;

if (starv.length) {
  bad = true;
  const byTool = {};
  for (const v of starv) (byTool[v.n] ??= []).push(v.s);
  console.error(`FAIL (A -- STARVATION): ${starv.length} foreground tool call(s) blocked longer than the ${BUDGET}s steering budget.`);
  console.error(`      While each was in flight there was no tool boundary, so a queued operator`);
  console.error(`      message could not be delivered. The operator was unheard for that long.`);
  for (const [n, arr] of Object.entries(byTool).sort((a, b) => b[1].length - a[1].length)) {
    arr.sort((a, b) => b - a);
    console.error(`        ${n}: ${arr.length} call(s), worst ${(arr[0] / 60).toFixed(1)} min`);
  }
  // The remedy depends on the SHAPE of the thing being waited on. Telling a
  // filesystem poll to "use TaskOutput(task_id)" is useless advice -- neither a
  // Skill spawn nor an Agent spawn has a task_id, which is precisely why the
  // lead wrote the poll. Only TaskCreate produces one.
  console.error(`      Fix (Agent spawn -- teammates: dev, qa, code-reviewer, adversary, analyst):`);
  console.error(`      Agent returns an agent_id, NOT a task_id, and TaskOutput cannot join it.`);
  console.error(`      Dispatch run_in_background:true, then join on the DELIVERABLE with Rule 29's`);
  console.error(`      bounded file-wait beat. Every teammate delivers by file (Rule 20), so the`);
  console.error(`      file is the handle.`);
  console.error(`      Fix (TaskCreate -- the only shape that yields a task_id):`);
  console.error(`      TaskOutput(task_id, block:true, timeout:${BUDGET * 1000}).`);
  if (byTool.Bash) {
    console.error(`      Fix (Bash waiting on any file-delivered deliverable -- no task_id exists):`);
    console.error(`      Rule 29's bounded file-wait beat. Each beat is ONE Bash call that returns`);
    console.error(`      within ${BUDGET}s and may poll inside itself; bound the SEQUENCE at`);
    console.error(`      max_wait_beats, then re-dispatch. Never one open-ended poll.`);
  }
} else {
  log(`PASS  (A) no foreground call exceeded the budget.`);
}

if (steam.length) {
  bad = true;
  console.error(`FAIL (B -- STEAMROLL): ${steam.length} operator message(s) were followed by a`);
  console.error(`      pipeline-advancing call issued BEFORE the pause flag was cleared. The lead`);
  console.error(`      received the steer and executed straight through it.`);
  for (const v of steam.slice(0, 8)) console.error(`        [${v.tool}] "${v.msg}"`);
  if (steam.length > 8) console.error(`        ... and ${steam.length - 8} more`);
  console.error(`      Fix: answer the operator, then release the pause flag`);
  console.error(`      (rm -f _bmad-output/pipeline-paused.flag) before advancing.`);
  console.error(`      These are calls that SUCCEEDED. Attempts the ai-dlc-acknowledge.sh hook`);
  console.error(`      denied are excluded -- a blocked attempt is the hook working, not a`);
  console.error(`      steamroll. So if these are recent, the hook did NOT stop them: check it`);
  console.error(`      is registered on PreToolUse with a matcher covering`);
  console.error(`      Agent|Task|Skill|TaskCreate|Write|Edit|MultiEdit|NotebookEdit.`);
} else {
  log(`PASS  (B) every operator message was acknowledged before the pipeline advanced.`);
}

if (unbounded.length) {
  bad = true;
  console.error(`FAIL (C -- UNBOUNDED WAIT): ${unbounded.length} wait sequence(s) ran past the`);
  console.error(`      ${MAX_BEATS}-beat ceiling with no re-dispatch. Each beat may be under the budget`);
  console.error(`      (so check A is silent), but the lead is polling forever and advancing nothing.`);
  for (const v of unbounded.sort((a, b) => b.beats - a.beats).slice(0, 8))
    console.error(`        ${v.beats} beats  ${v.f}  "${v.cmd}"`);
  if (unbounded.length > 8) console.error(`        ... and ${unbounded.length - 8} more`);
  console.error(`      Fix: an exhausted wait means the deliverable is ABSENT, which Rule 20 already`);
  console.error(`      calls non-delivery -- re-dispatch, then HARD_BLOCK. Rule 29 bounded file-wait beat.`);
} else {
  log(`PASS  (C) no wait sequence exceeded ${MAX_BEATS} beats without a re-dispatch.`);
}

if (wrongjoin.length) {
  bad = true;
  console.error(`FAIL (D -- WRONG JOIN API): ${wrongjoin.length} TaskOutput call(s) failed with`);
  console.error(`      "No task found with ID". TaskOutput joins a task_id, which only TaskCreate`);
  console.error(`      produces. An Agent returns an agent_id (<name>@session-<id>) and TaskOutput`);
  console.error(`      will NOT take it -- the call fails and the lead learns nothing.`);
  for (const v of wrongjoin.slice(0, 8)) console.error(`        ${v.f}  ${v.id}`);
  if (wrongjoin.length > 8) console.error(`        ... and ${wrongjoin.length - 8} more`);
  console.error(`      Fix: join a TEAMMATE on its DELIVERABLE -- every ai-dlc teammate delivers by`);
  console.error(`      file (Rule 20), so use Rule 29's bounded file-wait beat. TaskOutput is correct`);
  console.error(`      only for a task you created with TaskCreate and hold a real task_id for.`);
} else {
  log(`PASS  (D) no TaskOutput call was handed an agent_id.`);
}

process.exit(bad ? 1 : 0);
NODE
