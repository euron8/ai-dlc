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
#
# EXEMPT FROM CHECK A
#   AskUserQuestion -- its duration is the HUMAN's think-time, not machine
#   starvation. The lead is waiting ON the operator, not blocking them. Counting
#   it would flag every checkpoint as a violation.
#
# USAGE
#   core/scripts/validate-steering-budget.sh --transcript PATH [--quiet]
#   core/scripts/validate-steering-budget.sh --dir PATH [--quiet]   # scan a corpus
#
# ENV OVERRIDES
#   AI_DLC_STEERING_BUDGET  max foreground block, seconds   (default 120)
#   AI_DLC_STEERING_GRACE   jitter allowance, seconds       (default 30)
#
# EXIT
#   0  no foreground call exceeded the budget; no steamrolled operator message
#   1  a violation was found, or input unreadable

set -u

BUDGET="${AI_DLC_STEERING_BUDGET:-120}"
GRACE="${AI_DLC_STEERING_GRACE:-30}"
TRANSCRIPT=""
DIR=""
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --transcript) TRANSCRIPT="${2:-}"; shift 2 ;;
    --dir)        DIR="${2:-}"; shift 2 ;;
    --quiet)      QUIET=1; shift ;;
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

AI_DLC_T="$TRANSCRIPT" AI_DLC_D="$DIR" AI_DLC_TH="$THRESHOLD" AI_DLC_B="$BUDGET" AI_DLC_Q="$QUIET" node <<'NODE'
const fs = require("fs"), path = require("path");
const TH = +process.env.AI_DLC_TH, BUDGET = +process.env.AI_DLC_B;
const QUIET = process.env.AI_DLC_Q === "1";
const one = process.env.AI_DLC_T, dir = process.env.AI_DLC_D;

// AskUserQuestion measures the human's think-time, not machine starvation.
const EXEMPT = new Set(["AskUserQuestion"]);
const ADVANCING = new Set(["Agent", "Task", "Skill", "TaskCreate"]);
const isAdvancing = (b) => ADVANCING.has(b.name) ||
  (/^(Write|Edit|MultiEdit|NotebookEdit)$/.test(b.name) &&
   /(^|\/)_bmad-output\//.test(b.input?.file_path || ""));

const files = one ? [one]
  : fs.readdirSync(dir).filter(f => f.endsWith(".jsonl")).map(f => path.join(dir, f));

const starv = [], steam = [];

for (const f of files) {
  let recs;
  try {
    recs = fs.readFileSync(f, "utf8").split("\n").filter(Boolean)
      .map(l => { try { return JSON.parse(l); } catch { return null; } })
      .filter(Boolean).filter(r => !r.isSidechain);
  } catch { continue; }

  // ---- Check A: foreground calls that exceed the budget -------------------
  const use = {}, res = {};
  for (const r of recs) {
    const c = r.message?.content;
    if (!Array.isArray(c)) continue;
    for (const b of c) {
      if (b.type === "tool_use")
        use[b.id] = { n: b.name, t: Date.parse(r.timestamp), bg: b.input?.run_in_background === true };
      if (b.type === "tool_result") res[b.tool_use_id] = Date.parse(r.timestamp);
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
      const adv = uses.find(isAdvancing);
      if (adv && !cleared) {
        steam.push({ f: path.basename(f), tool: adv.name, msg: txt.slice(0, 60).replace(/\n/g, " ") });
        break;
      }
      if (cleared) break; // flag released before advancing -- correct
    }
  }
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
  console.error(`      Fix: dispatch with run_in_background:true, then join in bounded beats --`);
  console.error(`      TaskOutput(task_id, block:true, timeout:${BUDGET * 1000}). Rule 29 / implementation.md.`);
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
  console.error(`      (rm -f _bmad-output/pipeline-paused.flag) before advancing. The`);
  console.error(`      ai-dlc-acknowledge.sh PreToolUse hook denies this at runtime; if these`);
  console.error(`      violations are recent, the hook is not installed.`);
} else {
  log(`PASS  (B) every operator message was acknowledged before the pipeline advanced.`);
}

process.exit(bad ? 1 : 0);
NODE
