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
#   core/scripts/validate-steering-budget.sh --dir PATH [--since ISO] [--quiet]
#       Scan a corpus. This is the SPRINT-scoped mode: a sprint spans many transcripts
#       whenever it HANDED OFF, because a fresh CLI invocation or a /resume starts a new
#       file. An auto-compact does not do so on Claude Code -- it continues in the same
#       file under one sessionId -- so splitting is a property of the handoff, not of
#       compaction. A single --transcript run audits only the file it names and cannot
#       fail for anything in the sessions it never opened; a sprint that only
#       auto-compacted has one file, and a count of 1 there is complete rather than
#       narrow. --since bounds the corpus by file mtime to the sprint window; without it
#       the scan reaches back across sprint boundaries. The count of transcripts scanned
#       and the count excluded are both printed, so a narrow scan is visible rather than
#       assumed.
#   core/scripts/validate-steering-budget.sh --transcript PATH --count
#       Print ONLY the total violation count (A+B+C+D) as a bare integer, exit 0.
#       gate-validation.md Check 25 needs an integer to compare against the count
#       the previous gate recorded; it must not have to grep one out of prose.
#   core/scripts/validate-steering-budget.sh (--transcript PATH | --dir PATH) --cite "SUBSTR" [--since ISO] [--authorized-at ISO]
#       PROVENANCE-CITATION query mode. Asks a different question from the checks
#       above: not "did the lead mishandle operator messages?" but "did a GENUINE
#       operator message actually contain these words?" Prints MATCH <ts> or NOMATCH
#       and exits 0 (found) / 2 (not found). --since bounds the search to messages at
#       or after an ISO-8601 timestamp (the pause window). This exists so a record
#       that CLAIMS operator authorization (an ADVERSARIAL_RESOLUTION operator_
#       authorization citation) can be checked against the harness-owned transcript.
#
#       --authorized-at IS THE CITATION'S OWN TIMESTAMP, and it is the difference
#       between "the operator said these words" and "the operator said these words
#       WHEN THIS RECORD SAYS THEY DID". Without it the corpus is the project's whole
#       session history and any twelve-character phrase the operator ever typed
#       verifies a citation filed today: every caller printed `MATCH <ts>` and sent it
#       to /dev/null, so the one output that could have refuted the claim was the one
#       nobody read. A record verifies only if an accepted operator turn carrying the
#       quote falls within AI_DLC_CITE_AUTH_TOLERANCE_S seconds either side of this
#       timestamp. The bound is OPTIONAL and an EMPTY value is how a caller says so:
#       a caller that cannot derive a timestamp from its own record passes `""` and
#       gets today's unbounded answer, because refusing a citation for a field the
#       entry grammar does not require is a check that wedges live work. Every shipped
#       reader passes the flag UNCONDITIONALLY for that reason -- the literal then sits
#       on the invocation line, where invariant I109 joins it to `--cite`, rather than
#       on a conditional assignment a whole-file grep would find in a comment. A
#       NON-EMPTY value that will not parse is REFUSED (exit 1) rather than ignored --
#       a bound silently dropped is an unbounded verify wearing a bound's exit code.
#
#       WHY A WINDOW AND NOT AN EQUALITY, measured over the reference consumer's 26
#       `**Operator authorization:**` rows. These timestamps are HAND-TYPED and
#       routinely rounded (`19:34:00Z`, `22:40:00Z`), so the record they cite is not at
#       the stated instant: taking each row's NEAREST matching accepted record, the gap
#       runs from -1116s to +4283s. An exact compare would NOMATCH 19 of the 23 rows
#       that verify today. The default tolerance is 7200s, which admits every one of
#       the 23 with a 1.68x margin on the worst (+4283s, an entry stated at 22:40:00Z
#       whose operator answer landed at 23:51:22Z) and 6.45x on the other side.
#
#       Its predicate is Check B's, plus AskUserQuestion ANSWERS -- and only the answer
#       side, never the lead-authored question -- plus SLASH-COMMAND ARGUMENTS, and only
#       the <command-args> side, never the harness-written command name. Check B
#       deliberately accepts neither. The two checks ask different questions ("did the
#       lead execute through a steer?" vs "did the operator say these words?"), and both
#       additions are evidence for the second while being false positives for the first:
#       an answer the lead solicited, and a /ai-dlc invocation whose whole purpose is to
#       be executed straight through. See the notes on citableOperatorText.
#
# ENV OVERRIDES
#   AI_DLC_STEERING_BUDGET  max foreground block, seconds   (default 120)
#   AI_DLC_STEERING_GRACE   jitter allowance, seconds       (default 30)
#   AI_DLC_MAX_WAIT_BEATS   max consecutive wait beats      (default 6)
#   AI_DLC_CITE_AUTH_TOLERANCE_S  --authorized-at window, seconds each side (default 7200)
#
# AI_DLC_STEERING_BUDGET IS FOREGROUND-ONLY and must stay 120. It is not the
# backgrounded beat's sleep quantum -- that is AI_DLC_WAIT_BEAT_SECS, read only
# by wait-for-deliverable.sh. The two shared this name until v0.167.0, which is
# why the beat inherited a bound designed for a gag it cannot commit. This file's
# own code already knew: Check A skips `u.bg` and isWaitBeat requires
# `run_in_background !== true`, so neither ever measured a backgrounded beat.
#
# EXIT
#   0  no foreground call exceeded the budget; no steamrolled operator message;
#      no unbounded wait sequence
#   1  a violation was found, or input unreadable

set -u

BUDGET="${AI_DLC_STEERING_BUDGET:-120}"
GRACE="${AI_DLC_STEERING_GRACE:-30}"
MAX_BEATS="${AI_DLC_MAX_WAIT_BEATS:-6}"
TRANSCRIPT=""
DIR=""
QUIET=0
COUNT=0
CITE=""
SINCE=""
AUTH_AT=""

while [ $# -gt 0 ]; do
  case "$1" in
    --transcript) TRANSCRIPT="${2:-}"; shift 2 ;;
    --dir)        DIR="${2:-}"; shift 2 ;;
    --quiet)      QUIET=1; shift ;;
    --count)      COUNT=1; shift ;;
    --cite)       CITE="${2:-}"; shift 2 ;;
    --since)      SINCE="${2:-}"; shift 2 ;;
    --authorized-at) AUTH_AT="${2:-}"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 1 ;;
  esac
done

say(){ [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

# --cite TAKES A CORPUS, and withholding that was a live deadlock.
#
# This used to read "--cite is a single-transcript query; it never scans a corpus" and
# reject --dir. But --dir exists for the reason the --dir usage line above states -- a
# sprint spans many transcripts once it has handed off -- and that reason applies to a
# CITATION with more force than to an audit. Cited, not restated: a copy of that sentence
# here would drift from it silently.
#
# A resolution record's operator_authorization is verified by shelling here. The caller
# (ai-dlc-acknowledge.sh) passes the CURRENT session's transcript, which is always the
# session asking permission and never the session in which the operator spoke. So a record
# was verifiable only inside the session that wrote it: cross any boundary that starts a
# NEW TRANSCRIPT FILE -- a handoff, or a /clear that opens a new session, but NOT an
# auto-compact, which continues in the same file -- and the citation reported NOMATCH,
# the record stopped counting, and
# --cycle-state regressed RESOLVED -> STALLED -> rc 3 -> every dispatch denied. The record
# survived on disk; its provenance did not survive the session boundary.
#
# Worse, the failure was INVERTED against honesty: with NO transcript the caller fails OPEN
# and the record counts, but with a READABLE transcript merely lacking the quote it fails
# CLOSED. Supplying ground truth was strictly worse than supplying none, and a genuine
# cross-session record was treated exactly like a forged one.
if [ -n "$CITE" ] && [ -z "$TRANSCRIPT" ] && [ -z "$DIR" ]; then
  echo "FAIL: --cite requires --transcript PATH or --dir PATH" >&2
  exit 1
fi

# --authorized-at ONLY BOUNDS --cite, and a caller that passes it to a checks run has asked for
# a bound nothing will apply. Refusing beats ignoring: the same silence would report a
# fully-unbounded verify with the exit code of a bounded one, which is the defect this flag
# exists to close, one level up.
if [ -n "$AUTH_AT" ] && [ -z "$CITE" ]; then
  echo "FAIL: --authorized-at bounds --cite and has no meaning without it" >&2
  exit 1
fi

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

AI_DLC_T="$TRANSCRIPT" AI_DLC_D="$DIR" AI_DLC_TH="$THRESHOLD" AI_DLC_B="$BUDGET" AI_DLC_MB="$MAX_BEATS" AI_DLC_Q="$QUIET" AI_DLC_C="$COUNT" AI_DLC_CITE="$CITE" AI_DLC_SINCE="$SINCE" AI_DLC_AUTH_AT="$AUTH_AT" AI_DLC_AUTH_TOL="${AI_DLC_CITE_AUTH_TOLERANCE_S:-7200}" node <<'NODE'
const fs = require("fs"), path = require("path");
const TH = +process.env.AI_DLC_TH, BUDGET = +process.env.AI_DLC_B;
const MAX_BEATS = +process.env.AI_DLC_MB;
const QUIET = process.env.AI_DLC_Q === "1";
const COUNT = process.env.AI_DLC_C === "1";
const CITE = process.env.AI_DLC_CITE || "";
const SINCE = process.env.AI_DLC_SINCE || "";
const AUTH_AT = process.env.AI_DLC_AUTH_AT || "";
const AUTH_TOL_S = +(process.env.AI_DLC_AUTH_TOL || 7200);
const one = process.env.AI_DLC_T, dir = process.env.AI_DLC_D;

// AskUserQuestion measures the human's think-time, not machine starvation.
const EXEMPT = new Set(["AskUserQuestion"]);
const ADVANCING = new Set(["Agent", "Task", "Skill", "TaskCreate"]);

// THE genuine-operator-message predicate: "a real human FREELY TYPED this". Returns the
// cleaned message text, or "" if the record is not a free-text operator turn (tool_result,
// harness/system injection, teammate traffic, or the auto-compact resume prompt). Keep every
// exclusion here in lockstep with the "NOT AN OPERATOR MESSAGE" header notes.
//
// Check B (steamroll) is its ONLY caller. --cite calls citableOperatorText below, which is
// this plus one carefully-bounded addition. The two were deliberately separated; see the note
// on citableOperatorText for why sharing one predicate was wrong in BOTH directions.
const genuineOperatorText = (r) => {
  if (!r || r.type !== "user") return "";
  // THE HARNESS'S OWN FLAG, and the only exclusion here that does not have to be spelled as a
  // prefix. `isMeta:true` is what Claude Code sets on a user-shaped record IT wrote: skill
  // re-load notices, re-invocation notes, usage-limit resets, "please continue" nudges. The
  // prefix list below is a list of the injections somebody happened to see; this is the
  // producer saying so. Measured over the reference consumer's 252 transcripts (205851 records
  // after the sidechain filter, 38572 type:user): 984 records accepted as operator text, 90 of
  // them isMeta -- "Skill /ai-dlc-update is already loaded above; instructions unchanged.",
  // "(Re-invocation of /ai-dlc-update ...)", "Your claude.ai usage limit has reset. Continue the
  // task you were working on". Every one is over twelve characters and would have verified a
  // citation quoting it. All 90 arrived through THIS arm and none through the AskUserQuestion
  // or command-args arms, which is why the test sits here and is not restated in
  // citableOperatorText: a guard there would have no subject today.
  if (r.isMeta === true) return "";
  const c = r.message?.content;
  if (Array.isArray(c) && c.some(b => b.type === "tool_result")) return "";
  let txt = typeof c === "string" ? c
    : Array.isArray(c) ? c.map(b => (b.type === "text" ? b.text : "")).join(" ") : "";
  txt = (txt || "").replace(/<system-reminder>[\s\S]*?<\/system-reminder>/g, "").trim();
  if (!txt) return "";
  if (/^(<task-notification|<local-command|<command-|<agent-message|<teammate-message|Caveat:|\[Request interrupted|## Context Usage|Stop hook feedback|Base directory|Another Claude session sent a message)/.test(txt)) return "";
  if (/<teammate-message/.test(txt)) return "";
  if (/^This session is being continued from a previous conversation/.test(txt)) return "";
  return txt;
};

// ---------------------------------------------------------------------------
// AskUserQuestion answers: citable, but NOT steamroll-relevant.
//
// WHY THIS EXISTS. genuineOperatorText rejects any record carrying a tool_result (:189).
// An AskUserQuestion answer arrives in the transcript as EXACTLY that shape -- a type:"user"
// record whose content array holds a tool_result replying to the AskUserQuestion tool_use. So
// --cite structurally could not accept ANY AskUserQuestion-sourced answer as a citable
// operator message. Not one bad citation: a closed class.
//
// That is the MIRROR of the failure Check 2a exists to catch. Rule 11(a) names AskUserQuestion
// as the sanctioned mechanism for exactly this kind of operator decision, and the reference
// consumer dispositioned a HARD_BLOCK through it. Citing that answer in Check 2a's own format
// failed with the identical message the S290 fabrication case produced ("appears in NO genuine
// operator message in the transcript") -- a genuine, mechanism-sanctioned citation rejected,
// rather than a fabricated one accepted.
//
// WHY THE PREDICATE IS SPLIT RATHER THAN WIDENED. Sharing one predicate was wrong in both
// directions, and widening genuineOperatorText would have broken Check B:
//
//   Check B asks "did an operator message land that the lead then executed straight
//   through?" The lead SOLICITS an AskUserQuestion answer. No pause flag is set, because the
//   answer is a tool result rather than a UserPromptSubmit, and no acknowledgement is owed --
//   the lead already stopped and asked. Every AskUserQuestion -> advance sequence would score
//   as a steamroll, in the one check whose design notes twice warn against reading a machine
//   event as a human one.
//
//   --cite asks a different question: "did the operator actually say these words?" For that,
//   a deliberate timestamped selection is evidence of the same kind as typed prose.
//
// WHY ONLY THE ANSWER SIDE. The tool_result text is
//
//     Your questions have been answered: "<question>"="<answer>", "<question>"="<answer>". ...
//
// and the QUESTIONS are text the LEAD authored. Accepting the whole string would let a lead
// cite words it wrote itself and pass the provenance check -- reintroducing the S290
// fabrication through the fix for its mirror image. Only the answer side of each pair is
// returned. The extraction stops at the first unescaped quote, so an answer containing a
// literal `"` is truncated rather than over-read: a citation may fail to match, which is the
// safe direction for a provenance check.
const askUserQuestionAnswers = (r, askIds) => {
  if (!r || r.type !== "user") return "";
  const c = r.message?.content;
  if (!Array.isArray(c)) return "";
  const out = [];
  for (const b of c) {
    if (b.type !== "tool_result" || !askIds.has(b.tool_use_id)) continue;
    const raw = typeof b.content === "string" ? b.content
      : Array.isArray(b.content) ? b.content.map(x => (x.type === "text" ? x.text : "")).join(" ")
      : "";
    for (const m of raw.matchAll(/"\s*=\s*"([^"]*)"/g)) out.push(m[1]);
  }
  return out.join(" ").trim();
};

// ---------------------------------------------------------------------------
// Slash-command arguments: citable, but NOT steamroll-relevant.
//
// WHY THIS EXISTS. genuineOperatorText rejects any record whose text opens with `<command-`.
// A slash-command turn reaches the transcript as that envelope, with what the operator
// actually typed inside <command-args>:
//
//     <command-message>ai-dlc</command-message>
//     <command-name>/ai-dlc</command-name>
//     <command-args>Sprint 300: take the ETH-REWARDS ... through to production</command-args>
//
// So --cite could not accept ANY text an operator supplied to a slash command. That is not an
// edge case: /ai-dlc IS the sprint kickoff, which makes the SPRINT'S OWN SCOPE the single
// largest class of operator prose the requirement chain rests on, and it was structurally
// uncitable. Measured on the reference consumer: 5508 operator text records, 643 rejected by
// the `<command-` arm, 304 of them carrying non-empty args, 148 of those /ai-dlc invocations.
//
// The failure that surfaced it: a lead recorded `user_request_verbatim` as a POINTER to the
// previous sprint's locked block, planned three stories sharing not one identifier with what
// the operator asked for, and passed four consecutive gates. Nothing could contradict the
// pointer, because the operator's actual words were invisible to the only verifier that could
// have refuted it.
//
// WHY THE PREDICATE IS SPLIT RATHER THAN WIDENED -- and this time it is measured. Check B asks
// "did an operator message land that the lead then executed straight through?" A /ai-dlc
// invocation is followed by pipeline-ADVANCING calls BY DESIGN; dispatching is what the
// operator invoked it to do. On the reference consumer, 305 of the 643 command-envelope
// records are followed by an advancing call before the next genuine operator turn, against
// 183 for the free-typed records that are Check B's real subject. Widening genuineOperatorText
// would therefore have nearly TRIPLED Check B's candidate set with sprint starts -- every one
// a false positive, in the one check whose design notes twice warn against reading a
// solicited event as an unsolicited one.
//
// WHY ONLY THE ARGS SIDE. <command-name> is scaffolding the HARNESS wrote, and
// <command-message> is its echo. Accepting the whole envelope would let a lead cite the string
// `/ai-dlc` -- a token no operator composed -- and pass a provenance check. Only <command-args>
// is returned, by a regex that structurally cannot reach a sibling <local-command-stdout>:
// command OUTPUT is not operator input. An invocation with empty args (`/ai-dlc resume`)
// yields "" and stays uncitable, which is correct -- nothing was said.
const commandArgsText = (r) => {
  if (!r || r.type !== "user") return "";
  const c = r.message?.content;
  if (Array.isArray(c) && c.some(b => b.type === "tool_result")) return "";
  let txt = typeof c === "string" ? c
    : Array.isArray(c) ? c.map(b => (b.type === "text" ? b.text : "")).join(" ") : "";
  txt = (txt || "").replace(/<system-reminder>[\s\S]*?<\/system-reminder>/g, "").trim();
  // Only a command envelope. This arm widens nothing else that genuineOperatorText rejects.
  if (!/^<command-/.test(txt)) return "";
  const out = [];
  for (const m of txt.matchAll(/<command-args>([\s\S]*?)<\/command-args>/g)) out.push(m[1]);
  return out.join(" ").trim();
};

// The --cite predicate. genuineOperatorText, plus an AskUserQuestion answer, plus the
// arguments an operator typed to a slash command. Every OTHER tool_result shape stays
// rejected -- a Bash result, a file read, a subagent return is not an operator message
// however operator-sounding its bytes are.
const citableOperatorText = (r, askIds) =>
  genuineOperatorText(r) || askUserQuestionAnswers(r, askIds) || commandArgsText(r);

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

// A sprint that HANDED OFF does not run in one transcript: a fresh CLI invocation or a
// /resume starts a new file. An AUTO-COMPACT does not, on Claude Code -- the compaction
// boundary record sits mid-file, with conversation on both sides of it and one unchanging
// sessionId spanning both -- so a compacted session is still one transcript, and a scan of 1
// on a sprint that never handed off is complete rather than narrow. Where a handoff DID
// occur, a single --transcript scan covers only the file it names -- in a long sprint, a
// minority of it. Checks A and B therefore cannot fail for anything in the sessions it never
// opened, and the retro cites a PASS produced by a scope that excluded the region where its
// failures live. Measured on the reference consumer: run as retro.md then directed
// (one transcript) the audit returned PASS; run across that sprint's three transcripts,
// Check B returned FAIL (B -- STEAMROLL): 2 -- both in a session the directed invocation
// never opened, and one of them a violation the sprint had already recorded by hand.
//
// --dir is the sprint-scoped mode, and --since bounds it. Without the bound it scans the
// project's whole session history, which over-reports across sprint boundaries and makes the
// count meaningless against Check 25's previous-gate baseline. The filter is on file mtime:
// a transcript last written before the sprint opened cannot hold an event inside it. Files
// excluded are REPORTED, never silently dropped -- a narrow scan must be visible, which is
// the whole defect being fixed here.
// SAME DEFECT, THE OTHER OUTPUT PATH. `--cite` is THE genuine-operator predicate --
// the convergence validator, the escalation gate and the remediation guard all delegate
// their \"a real human said this\" question to it -- and it reported only a COUNT, so a
// citation verified against the wrong corpus was byte-identical to one verified against
// the right one. The corpus SOURCE rather than every member: --cite runs on every gate
// call and the discriminator is which corpus was consulted, not which files it held.
const CORPUS_ID = path.resolve(one || dir);
let skippedBySince = 0;
const files = one ? [one]
  : fs.readdirSync(dir).filter(f => f.endsWith(".jsonl")).map(f => path.join(dir, f))
      .filter(f => {
        if (!SINCE) return true;
        const cut = Date.parse(SINCE);
        if (Number.isNaN(cut)) return true;
        let mt;
        try { mt = fs.statSync(f).mtimeMs; } catch { return true; }
        if (mt >= cut) return true;
        skippedBySince++;
        return false;
      });

// ---- --cite: provenance-citation query (single transcript) ------------------
// Answer one mechanical question: is CITE a verbatim (whitespace-normalized,
// case-insensitive) substring of a GENUINE operator message at or after --since,
// and -- when the caller can say when its record claims the authorization happened --
// within the --authorized-at window rather than anywhere in the project's history?
// It deliberately does NOT judge whether those words AUTHORIZE anything -- that is
// an LLM judgment, itself forgeable, and the caller (a resolution record's operator_
// authorization field) surfaces the words verbatim for the human to own the meaning.
// The machine notarizes provenance; the human owns meaning.
if (CITE) {
  const norm = (s) => (s || "").replace(/\s+/g, " ").trim().toLowerCase();
  const needle = norm(CITE);
  const sinceMs = SINCE ? Date.parse(SINCE) : -Infinity;
  // THE AUTHORIZATION WINDOW. The header carries the measurement that set the tolerance.
  // A value that will not parse is a REFUSAL and not an unbounded scan: every caller reads
  // rc 0 as MATCH and rc 2 as the verifier's own NOMATCH, treating anything else as a tooling
  // failure that covers nothing, so exit 1 is the only answer here that cannot be read as a
  // verdict. Silently dropping an unparseable bound would hand back a fully unbounded verify
  // wearing a bounded one's exit code -- the defect this flag exists to close, one level up.
  let authMs = null;
  const authTolMs = AUTH_TOL_S * 1000;
  if (AUTH_AT) {
    // A ZONE-LESS VALUE IS UTC HERE, NOT LOCAL. escalations.md prescribes UTC and all 26 of the
    // reference consumer's authorization rows carry `Z`, but Date.parse reads a zone-less
    // ISO string in the RUNNER's local time -- which would move the window by the machine's
    // offset and make the verdict a property of where the gate ran rather than of the citation.
    const v = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?$/.test(AUTH_AT) ? AUTH_AT + "Z" : AUTH_AT;
    authMs = Date.parse(v);
    if (Number.isNaN(authMs)) {
      console.error(`FAIL: --authorized-at "${AUTH_AT}" is not an ISO-8601 timestamp, so the citation window cannot be computed. Refusing rather than verifying unbounded.`);
      process.exit(1);
    }
    if (!Number.isFinite(AUTH_TOL_S) || AUTH_TOL_S < 0) {
      console.error(`FAIL: AI_DLC_CITE_AUTH_TOLERANCE_S="${process.env.AI_DLC_AUTH_TOL}" is not a non-negative number of seconds.`);
      process.exit(1);
    }
  }
  // Records carrying the quote that fell OUTSIDE the window. The two NOMATCHes are different
  // findings and a caller cannot act on them alike: nothing carried these words at all is the
  // S290 fabrication, while the operator said them a fortnight from the stated authorization is
  // a citation pointed at the wrong turn. Counted so the diagnostic can say which.
  let outsideWindow = 0;
  // THE CORPUS, not one file. `files` is already [one] for --transcript and the
  // since-bounded directory listing for --dir, so this needs no second assembly.
  let recs = [];
  for (const f of files) {
    try {
      recs = recs.concat(
        fs.readFileSync(f, "utf8").split("\n").filter(Boolean)
          .map(l => { try { return JSON.parse(l); } catch { return null; } })
          .filter(Boolean).filter(r => !r.isSidechain));
    } catch { /* an unreadable member is not a verdict; the count below shows the scan */ }
  }
  if (!recs.length) {
    console.error(`NOMATCH (0 records across ${files.length} transcript(s) from ${CORPUS_ID})`);
    console.log("NOMATCH"); process.exit(2);
  }
  // Which tool_use ids are AskUserQuestion calls. Resolved by PAIRING, never by sniffing the
  // result text: any subagent can emit a string that looks like an answer block, and only the
  // tool_use it replies to says what actually asked the operator.
  const askIds = new Set();
  for (const r of recs) {
    const c = r.message?.content;
    if (!Array.isArray(c)) continue;
    for (const b of c) if (b.type === "tool_use" && b.name === "AskUserQuestion") askIds.add(b.id);
  }
  for (const r of recs) {
    const txt = citableOperatorText(r, askIds);
    if (!txt) continue;
    const ts = Date.parse(r.timestamp);
    if (!(ts >= sinceMs)) continue;
    const carries = norm(txt).includes(needle);
    if (authMs !== null && Math.abs(ts - authMs) > authTolMs) {
      if (carries) outsideWindow++;
      continue;
    }
    if (carries) {
      console.error(`cite: scanned ${files.length} transcript(s) from ${CORPUS_ID}`);
      console.log(`MATCH ${r.timestamp}`); process.exit(0);
    }
  }
  const windowNote = authMs === null ? ""
    : outsideWindow
      ? `, though ${outsideWindow} operator turn(s) carried it outside the +/-${AUTH_TOL_S}s window around the cited authorization time ${AUTH_AT} -- the words were said, but not when this record says they were`
      : ` within +/-${AUTH_TOL_S}s of the cited authorization time ${AUTH_AT}`;
  console.error(`cite: scanned ${files.length} transcript(s) from ${CORPUS_ID}, no genuine operator message carried it${windowNote}`);
  console.log("NOMATCH"); process.exit(2);
}

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
    // The genuine-operator predicate -- shared with --cite so the two cannot drift.
    // Excludes tool_results, harness/system injections, teammate traffic, and the
    // auto-compact resume prompt (see genuineOperatorText and the header notes).
    const txt = genuineOperatorText(r);
    if (!txt) continue;

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
log(`transcripts scanned : ${files.length}${SINCE && !one ? ` (${skippedBySince} excluded: mtime before ${SINCE})` : ""}`);
// A COUNT IS NOT PROVENANCE, AND THE EMPTY CASE IS THE ONE THAT MATTERS. The corpus is
// named on its OWN line rather than only through the members read, because a run that found
// nothing — or a `--since` window that excluded everything, which is the invocation shape
// `steps/retro.md` itself prescribes — would otherwise name no source at all, and a
// wrong-corpus run that comes back empty is precisely the case a reader cannot tell from a
// right one. Caught by this validator's own fixture, red against a first fix that printed
// only the members it read.
// `--transcript` and `--dir` are both free caller-supplied paths
// bound to nothing, so two runs over two DIFFERENT corpora holding identical content produced
// byte-identical output and a wrong-session run was indistinguishable from a correct one. The
// count answers "how many", which is not the question a reader of this gate has. Resolved, so
// a relative path and the absolute path it names cannot read as two different corpora; one
// per line under a hanging indent, because `--dir` over an unbounded project directory is
// hundreds of files and a joined line would be unreadable. The line ABOVE is read by label
// (`steps/retro.md`), so this goes after it and changes none of its bytes.
log(`corpus              : ${CORPUS_ID}`);
log(`transcripts read    : ${files.length ? files.map(f => path.resolve(f)).join("\n                      ") : "(none)"}`);
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
