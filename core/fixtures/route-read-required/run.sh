#!/usr/bin/env bash
# route-read-required — an `/ai-dlc` session that NEVER READ THE ROUTER must not be able to
# produce files, and the act that fixes it must stay reachable.
#
# Usage: run.sh
# Exit:  0 = every arm holds, 1 = one does not, 2 = fixture broken.
#
# THE INCIDENT. A consumer session was invoked with `/ai-dlc`, loaded `SKILL.md`, and then
# never read `steps/route.md` at all -- no variant detection, no Step 1a artifact-budget gate,
# no `sprint_id`, no envelope roll, no Rule 3(d) scope pause, no story files, no gate. It did
# real engineering work and then rewrote `pipeline-snapshot.md` twice to make it look like
# sanctioned sprint activity. EVERY GATE-TIME CHECK WAS UNREACHABLE BY CONSTRUCTION, because
# reaching a gate is the thing that did not happen. Check 2z of `ai-dlc-acknowledge.sh` is the
# only place that can be caught, since it is the only check that runs before the pipeline does.
#
# WHY THE ARM KEYS ON A `file_path` AND NOT ON THE STRING. Measured over 171 transcripts of the
# reference consumer: 69 carry a real `Skill(ai-dlc)` tool_use and only 38 ever Read
# `steps/route.md`, and `STEP_LOADED_TOKEN: route` agrees at exactly 38 -- two independently
# derived values. MENTIONING the router is not reading it: the incident's own transcript
# mentions it once and Reads it zero times, and `SKILL.md` itself carries the path in prose, so
# a check keyed on the string matches 69 of 69 and detects nothing. Arm 1's two halves are that
# distinction, ONE PROPERTY APART IN THE SAME RUN -- two transcripts differing by exactly one
# line, the `"file_path":"...steps/route.md"` a Read emits.
#
# THIS FIXTURE'S OWN FALSIFIABILITY RECORD, because a green fixture is not evidence that any of
# its arms CAN fire. Driven through the `AI_DLC_RRR_HOOK` seam against a copy of the hook from
# before Check 2z existed -- sides asserted to differ by `md5` before the comparison was read --
# FIVE arms go RED on the exact input the incident describes: all four tools on the denied
# surface are ALLOWED for a session that never read the router, and no `ROUTE_DENIED` is logged.
# Against the hook carrying the check, the same run is green. That differential is what says
# these arms discriminate; re-run it the same way if they are ever suspected of being vacuous.
# The count tracks the surface, so it moves when the surface does -- derive it, do not quote it.
#
# SECTION 7 CARRIES ITS OWN DIFFERENTIAL, taken through the same `AI_DLC_RRR_HOOK` seam against
# the copy of this hook at `origin/main` -- the revision from before Check 2z's guard grew its
# `agent_id` conjunct -- run from the REPO ROOT, because this fixture resolves its root from the
# process cwd. Sides asserted to differ by `md5` before the result was read. Against that pre-fix
# copy the TEAMMATE cell is DENIED and its ROUTE_DENIED row appears, so exactly two of section 7's
# arms go RED: the teammate allow and the teammate log. The twin and the pause arm stay green,
# and that shape is the claim -- red on both halves would mean the arms read the tree rather than
# the conjunct. `origin/main` is a ref that moves, so the durable way to rebuild that copy is the
# sibling battery's `teammate-conjunct-deleted` mutant, which deletes exactly that conjunct.
#
# AND THE ARM'S OWN COULD-NOT-FIRE TRAP, which is arm 2. The remedy for this denial is to READ
# the router, and the lead reaches a step file through `Skill`/`Agent` dispatch and `Bash`. An
# arm that denied those would forbid the very act it demands and wedge the pipeline at its first
# step -- a check whose remedy it also blocks is not a check, it is a deadlock. So arm 2 drives
# `Skill`, `Agent` and `Bash` against THE VERY TRANSCRIPT whose `Write` arm 1 just denied, in the
# same run and on the same tree. A separate clean run would only ask whether those tools are
# ever allowed; it could not ask whether they are allowed while the deny is live.
set -uo pipefail

# AI_DLC_RRR_HOOK is the seam the sibling mutation battery drives; unset in every real run.
#
# READ BEFORE THE SCRUB, AND THAT ORDER IS THE WHOLE POINT. The hermetic scrub below unsets
# every AI_DLC_* variable, this one included -- so a battery that exported it would find the
# REAL hook, every mutant would score a survival, and the sweep would read as a clean one.
HOOK="${AI_DLC_RRR_HOOK:-}"

# HERMETIC -- scrub the operator's tuning before invoking any hook (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
[ -n "$HOOK" ] || HOOK="$(pick "$HERE/../../hooks/ai-dlc-acknowledge.sh" \
                               "$HERE/../../../.claude/hooks/ai-dlc-acknowledge.sh" \
                               "$HERE/../../../core/hooks/ai-dlc-acknowledge.sh")"
[ -n "$HOOK" ] && [ -f "$HOOK" ] \
  || { echo "FIXTURE ERROR: cannot locate ai-dlc-acknowledge.sh" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq is required" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# -----------------------------------------------------------------------------
# THE TREE. A live pipeline, NOT PAUSED, and no adversarial series.
# -----------------------------------------------------------------------------
# UNPAUSED IS LOAD-BEARING, and it is what makes every deny below attributable. Check 2z sits
# ABOVE both the Rule 8 stop guard and the pause-flag early exit, so on this tree there is
# exactly one check that can deny anything -- if a paused tree were used instead, a `Write`
# denied by Check 3's catch-all would be indistinguishable from one denied by Check 2z, and
# arm 1 would pass over the wrong mechanism. Arm 5 pauses a SEPARATE tree on purpose.
#
# The sprint resolves and its slot exists so Check 2a finds no series and logs nothing; the
# closing arm asserts that, because an UNADJUDICABLE line would mean these arms read the
# divergence guard rather than the router guard.
seed() { # <name> [nosnapshot|paused] -> absolute tree path
  local w="$WORK/$1"; shift
  mkdir -p "$w/_bmad-output/planning-artifacts/s7" "$w/scripts/ai-dlc"
  printf '#!/bin/sh\necho 7\n' > "$w/scripts/ai-dlc/sprint-status.sh"
  chmod +x "$w/scripts/ai-dlc/sprint-status.sh"
  case "${1:-}" in
    nosnapshot) ;;
    paused)  : > "$w/_bmad-output/pipeline-snapshot.md"
             : > "$w/_bmad-output/pipeline-paused.flag" ;;
    *)       : > "$w/_bmad-output/pipeline-snapshot.md" ;;
  esac
  printf '%s' "$w"
}

# -----------------------------------------------------------------------------
# THE TRANSCRIPTS. Seeded from what the HARNESS emits, never from what the hook accepts.
# -----------------------------------------------------------------------------
# Both forms below were lifted from a real transcript in the reference consumer's project
# directory: the Read `tool_use` serialization, and the way `SKILL.md`'s own prose carries the
# router path inside a JSON string. A seed derived from the hook's grep would prove only that
# the grep matches its own grammar, and would stay green through a change to both.
TR_BYPASS="$WORK/bypass.jsonl"    # /ai-dlc invoked; route.md MENTIONED, never read
TR_ROUTED="$WORK/routed.jsonl"    # ...the same session, plus the one line a Read emits
TR_UPDATER="$WORK/updater.jsonl"  # /ai-dlc-update; no route read, and none is owed
TR_PLAIN="$WORK/plain.jsonl"      # no ai-dlc skill invoked at all, ever

printf '{"type":"user","message":{"content":"<command-name>/ai-dlc</command-name>"}}\n' > "$TR_BYPASS"
# The MENTION. This is `SKILL.md` INITIALIZATION quoted back into the transcript -- the exact
# text every `/ai-dlc` session carries, which is why a string-keyed check is vacuous.
printf '{"type":"assistant","message":{"content":[{"type":"text","text":"**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/route.md`"}]}}\n' >> "$TR_BYPASS"
printf '{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Write","input":{"file_path":"/w/_bmad-output/pipeline-snapshot.md"}}]}}\n' >> "$TR_BYPASS"

# ONE PROPERTY APART. `routed` is `bypass` plus a single line: the `file_path` a Read emits.
# Anything else that differs between them would give arm 1 a second explanation.
cp "$TR_BYPASS" "$TR_ROUTED"
printf '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_01","name":"Read","input":{"file_path":"/w/.claude/skills/ai-dlc/steps/route.md"}}]}}\n' >> "$TR_ROUTED"

printf '{"type":"user","message":{"content":"<command-name>/ai-dlc-update</command-name>"}}\n' > "$TR_UPDATER"
printf '{"type":"user","message":{"content":"fix the timezone bug in the ingest worker"}}\n' > "$TR_PLAIN"

# -----------------------------------------------------------------------------
drive() { # <tree> <tool> <transcript> [file_path] [agent_id] -> stdout
  local w="$1" tool="$2" tr="$3" fp="${4:-}" ag="${5:-}"
  # THE 5th ARGUMENT IS THE ACTOR, and the two fields it adds are the HARNESS'S, not this
  # fixture's invention: the shared PreToolUse payload is enumerated in `ai-dlc-context-sensor.sh`
  # as "session_id, transcript_path, cwd, prompt_id, permission_mode, agent_id, agent_type,
  # effort", and `ai-dlc-gate-remediation-guard.sh` and `ai-dlc-subagent-probe.sh` both read
  # `agent_id` off it for this same question. Omitting it is the LEAD's call -- the default, and
  # what every arm above drives -- so no existing arm changes shape.
  #
  # THE TOKEN `TYPE-ONLY` IS A THIRD ACTOR, AND IT IS THE ONE THAT SEPARATES THE TWO FIELD NAMES.
  # A lead started with `claude --agent <name>` carries `agent_type` and NO `agent_id` --
  # measured in a headless session with a payload dumper on PreToolUse: the flagged lead's call
  # read agent_id ABSENT, agent_type "Explore". So `agent_type` is not a second spelling of the
  # teammate discriminator; a check keyed on it exempts that lead and cannot fire. Every seed
  # that supplies both fields together, or neither, is blind to that difference by construction.
  jq -nc --arg t "$tool" --arg tr "$tr" --arg fp "$fp" --arg ag "$ag" \
     '{session_id:"rrr-session",transcript_path:$tr,tool_name:$t,
       tool_input:(if $fp == "" then {} else {file_path:$fp} end)}
      + (if $ag == "" then {}
         elif $ag == "TYPE-ONLY" then {agent_type:"Explore"}
         else {agent_id:$ag,agent_type:"general-purpose"} end)' \
    | CLAUDE_PROJECT_DIR="$w" bash "$HOOK" 2>/dev/null
}
denied() { case "$1" in *'"permissionDecision": "deny"'*|*'"permissionDecision":"deny"'*) return 0 ;; esac; return 1; }
# WHICH deny, not merely THAT one. Two checks in this hook deny a `Write`, and a fixture that
# read only the verdict would score Check 3's pause denial as Check 2z firing. Assert the VALUE.
is_route_deny() { case "$1" in *'has not read the router'*) return 0 ;; esac; return 1; }
is_pause_deny() { case "$1" in *'Rule 29'*) return 0 ;; esac; return 1; }

echo "route-read-required:"

# =============================================================================
# 1. THE BYPASS IS DENIED — and the near-miss, one property apart, is not.
# =============================================================================
W="$(seed live)"
# `NotebookEdit` IS in this list. It is on the hook's registered matcher and writes a file like
# the rest, so leaving it out would have left a bypassing session one unwatched way to produce
# one -- an affordance to remove, not a hole to document.
for T in Write Edit MultiEdit NotebookEdit; do
  OUT="$(drive "$W" "$T" "$TR_BYPASS" "$W/_bmad-output/pipeline-snapshot.md")"
  if denied "$OUT" && is_route_deny "$OUT"; then
    ok "BYPASS: \`$T\` is DENIED for an /ai-dlc session that only MENTIONED the router"
  elif denied "$OUT"; then
    bad "BYPASS: \`$T\` was denied, but not by Check 2z — the reason names no router, so this arm is reading another check's verdict"
  else
    bad "BYPASS: \`$T\` was ALLOWED for an /ai-dlc session that never read steps/route.md — the incident reproduces"
  fi
done

# THE NEAR-MISS, IN THE SAME RUN AND ON THE SAME TREE. `routed` differs from `bypass` by
# exactly one line. A near-miss in a SEPARATE run is an ADJACENT input: it asks only whether
# the arm CAN fire, never whether it fires on the right property.
OUT="$(drive "$W" Write "$TR_ROUTED" "$W/_bmad-output/pipeline-snapshot.md")"
if denied "$OUT"; then
  bad "NEAR-MISS: a session that DID Read steps/route.md was denied anyway — the arm fires on /ai-dlc, not on the missing read, and every routed session is now blocked"
else
  ok "NEAR-MISS: adding the one \`file_path\` line a Read emits turns the same Write from DENY to ALLOW"
fi

# THE NEAR-MISS FOR THE NEWEST MEMBER OF THE SURFACE. `NotebookEdit` was added because it is on
# the hook's registered matcher and writes a file like the rest. A surface arm that only ever
# asserts the DENY half of a tool cannot tell coverage from a tool that is denied unconditionally
# -- which is the shape a careless widening produces -- so every member gets both halves.
OUT="$(drive "$W" NotebookEdit "$TR_ROUTED" "$W/_bmad-output/analysis.ipynb")"
if denied "$OUT"; then
  bad "NEAR-MISS notebook: a routed session's NotebookEdit was DENIED — the tool is denied unconditionally rather than on the missing router read, so its DENY arm above proves nothing"
else
  ok "NEAR-MISS notebook: a routed session's \`NotebookEdit\` is ALLOWED, so the deny above is keyed on the missing read and not on the tool"
fi

# ...and the mention must not be what answered. If `bypass` were denied for carrying no route
# string AT ALL, arm 1 would hold for the wrong reason and a string-keyed check would pass it.
if grep -q 'steps/route\.md' "$TR_BYPASS" && ! grep -q '"file_path":"[^"]*steps/route\.md"' "$TR_BYPASS"; then
  ok "the denied transcript DOES name steps/route.md, and not as a file_path: the arm discriminates a read from a mention"
else
  bad "FIXTURE BROKEN: the bypass transcript does not carry a bare MENTION of steps/route.md, so arm 1 never tested the mention/read distinction"
fi

# =============================================================================
# 2. THE REMEDY IS NOT DENIED — on the transcript that was just denied a Write.
# =============================================================================
# The could-not-fire trap for this whole check. Reaching the router is a `Skill` or `Agent`
# dispatch and a `Bash` invocation; deny those and the deny's own instruction is impossible to
# follow. `Bash` is not on this hook's registered matcher at all, so the arm asserts the code
# path rather than a live denial -- but the matcher is settings, and settings change.
for T in Skill Agent Bash; do
  OUT="$(drive "$W" "$T" "$TR_BYPASS")"
  if denied "$OUT"; then
    bad "REMEDY: \`$T\` is DENIED on the same transcript whose Write is denied — the deny demands a router read and blocks the way to it. The pipeline is wedged at its first step."
  else
    ok "REMEDY: \`$T\` is ALLOWED while the Write deny is live, so the routing instruction is followable"
  fi
done

# =============================================================================
# 3. SCOPE — three populations the check must not touch.
# =============================================================================
OUT="$(drive "$W" Write "$TR_UPDATER" "$W/_bmad-output/ai-dlc-update/reconcile-report.md")"
if denied "$OUT"; then
  bad "SCOPE updater: an /ai-dlc-update session's Write was DENIED. It holds because AIDLC_SESSION is 0 for an updater transcript, not because of a separate conjunct — the hook carries none, deliberately, and the census that removed it is recorded in the sibling battery's marker."
else
  ok "SCOPE updater: an /ai-dlc-update session is untouched by the router check"
fi

WNS="$(seed nopipe nosnapshot)"
OUT="$(drive "$WNS" Write "$TR_BYPASS" "$WNS/notes.md")"
if denied "$OUT"; then
  bad "SCOPE no-pipeline: a tree with no pipeline-snapshot.md was DENIED — the hook's no-pipeline bail is gone and every project in the world now answers to it"
else
  ok "SCOPE no-pipeline: a tree with no pipeline-snapshot.md is untouched (the existing bail)"
fi

OUT="$(drive "$W" Write "$WORK/does-not-exist.jsonl" "$W/_bmad-output/x.md")"
if denied "$OUT"; then
  bad "SCOPE no-transcript: an unreadable transcript was DENIED. Absence of a transcript is absence of evidence, and reading it as a bypass turns every harness hiccup into a blocked write."
else
  ok "SCOPE no-transcript: an unreadable transcript is not evidence of a bypass"
fi

# THE POPULATION THE JUSTIFICATION ACTUALLY NAMES. Check 2z's false-positive argument is that
# `SKILL.md` INITIALIZATION requires the router read UNCONDITIONALLY -- so firing on a session
# that skipped it is a detection. That argument binds a session which LOADED `SKILL.md`. A
# session that never invoked any ai-dlc skill loaded nothing, is owed no router read, and is
# outside the argument entirely.
#
# MEASURED, replicating the hook's own two predicates verbatim over the reference consumer's
# 171 transcripts: 69 carry a real `/ai-dlc` invocation (control: 38 of them read the router,
# so the read predicate is not vacuous). 46 carry NO ai-dlc invocation of any kind and no
# router read; 12 of those 46 issued a `Write`/`Edit`/`MultiEdit`. Every one of the 12 is an
# ordinary engineering session in a repo that happens to have a `_bmad-output/` -- and that
# repo has the snapshot on disk, the hook installed, and `Write|Edit|MultiEdit` on its matcher.
OUT="$(drive "$W" Write "$TR_PLAIN" "$W/src/ingest.py")"
if denied "$OUT"; then
  bad "SCOPE not-an-ai-dlc-session: a session that invoked NO ai-dlc skill was DENIED. The guard is \`UPDATER_SESSION = 0\`, which is not \`/ai-dlc was invoked\` — it is every session that is not the updater. Measured false-positive set: 12 of 171 on the reference consumer."
else
  ok "SCOPE not-an-ai-dlc-session: a session that never invoked /ai-dlc is untouched"
fi

# =============================================================================
# 4. THE DENY IS LOGGED, AND THE ALLOW IS NOT.
# =============================================================================
# Both directions, on two FRESH trees so neither reads the other's log. The absence half is
# what proves the record is keyed on the denial rather than written on every pass; the sibling
# mutation battery is what proves that absence can go red.
WD="$(seed logdeny)"
drive "$WD" Write "$TR_BYPASS" "$WD/_bmad-output/pipeline-snapshot.md" >/dev/null
LOGD="$WD/_bmad-output/pipeline-continuation-log.md"
if grep -q '^## .*-- ROUTE_DENIED' "$LOGD" 2>/dev/null; then
  if grep -q 'rrr-session' "$LOGD" 2>/dev/null; then
    ok "LOG: the deny records a ROUTE_DENIED event carrying the session id"
  else
    bad "LOG: a ROUTE_DENIED event was written without the session id — retro's Rule 25(c) audit cannot attribute it"
  fi
else
  bad "LOG: the deny left no ROUTE_DENIED event in pipeline-continuation-log.md, so a blocked session is invisible to the audit that reads this file"
fi

WA="$(seed logallow)"
drive "$WA" Write "$TR_ROUTED" "$WA/_bmad-output/pipeline-snapshot.md" >/dev/null
if grep -q 'ROUTE_DENIED' "$WA/_bmad-output/pipeline-continuation-log.md" 2>/dev/null; then
  bad "LOG: a ROUTE_DENIED event was recorded on the ALLOW path — the log counts passes, not denials, and every nonzero count in it is meaningless"
else
  ok "LOG: no ROUTE_DENIED event on the allow path, so a nonzero count is a count of real denials"
fi

# =============================================================================
# 5. CHECK 2z RETURNS EARLY, SO PROVE THE CHECKS BELOW IT STILL ANSWER.
# =============================================================================
# This arm sits above Check 2a and Check 3 and `exit 0`s out of the hook. A new early return is
# the classic way to make everything downstream unreachable while every existing fixture that
# drives it stays green -- so drive the pause path THROUGH the new check, on a transcript that
# DID route, and read the reason to prove it is Rule 29's and not Check 2z's.
WP="$(seed paused paused)"
OUT="$(drive "$WP" Write "$TR_ROUTED" "$WP/_bmad-output/planning-artifacts/product-brief.md")"
if denied "$OUT" && is_pause_deny "$OUT"; then
  ok "DOWNSTREAM: Check 3's Rule 29 pause deny still fires on a routed session (Check 2z did not swallow it)"
elif denied "$OUT"; then
  bad "DOWNSTREAM: the paused write was denied by the WRONG check — Check 2z is answering for a routed session"
else
  bad "DOWNSTREAM: a paused artifact write was ALLOWED. Check 2z's early return has made the Rule 29 pause unreachable."
fi

OUT="$(drive "$WP" Write "$TR_ROUTED" "$WP/_bmad-output/pipeline-snapshot.md")"
if denied "$OUT"; then
  bad "DOWNSTREAM: Check 3's pipeline-snapshot carve-out was denied — the allow paths below Check 2z are broken too, not just the deny"
else
  ok "DOWNSTREAM: Check 3's pipeline-snapshot carve-out still allows (the allow half below Check 2z survives)"
fi

# =============================================================================
# 6. AND CHECK 2a MUST NOT HAVE BEEN WHAT ANSWERED.
# =============================================================================
if grep -q 'ADVERSARIAL_STATE_UNADJUDICABLE' "$W/_bmad-output/pipeline-continuation-log.md" 2>/dev/null; then
  bad "FIXTURE BROKEN: the seed is unadjudicable to Check 2a, so the arms above exercised the divergence guard"
else
  ok "the seed reaches Check 2z: no UNADJUDICABLE line, so the router guard is what answered"
fi

# =============================================================================
# 7. A DISPATCHED TEAMMATE IS OUTSIDE CHECK 2z
# =============================================================================
# THE SAME TREE AND THE SAME TRANSCRIPT AS ARM 1, which is what makes this pair readable at all:
# on that tree Check 2z is the only check that can deny anything, so a deny here is attributable
# to it and a mistaken allow cannot be blamed on a downstream carve-out.
#
# WHY THE CHECK EVER FIRED ON A TEAMMATE. The harness sends a dispatched teammate's tool call with
# its own `agent_id` AND the LEAD's `transcript_path` -- the teammate's own session file is one
# level down at `<session>/subagents/agent-<id>.jsonl`, and this scan never opens it. So
# `AIDLC_SESSION` is read off the lead's `/ai-dlc` marker while the router Read the teammate DID
# make is invisible, and the deny's remedy ("READ steps/route.md now") is addressed to an actor
# who cannot clear it. The transcript pair is the defect; `agent_id` is the property that names it.
AG="rrr-teammate-01"
OUT="$(drive "$W" Write "$TR_BYPASS" "$W/_bmad-output/pipeline-snapshot.md" "$AG")"
if denied "$OUT"; then
  bad "TEAMMATE: a dispatched teammate's Write was DENIED. The remedy is unreachable by the actor denied — its own router read lands in a transcript file this check never opens, and clearing the deny requires a Read by the LEAD, who is not the one being stopped."
else
  ok "TEAMMATE: a dispatched teammate carrying an \`agent_id\` is outside Check 2z, so no deny is issued at all"
fi

# ITS TWIN, ONE PROPERTY APART, IN THE SAME RUN AND ON THE SAME TREE. Drop the `agent_id` and
# change nothing else -- same tool, same transcript, same tree. This is the exemption's ACQUITTAL
# PROBE: an exemption that also covered the LEAD would delete Check 2z outright while every arm
# above still passed, and an arm asserting only "the teammate is allowed" cannot tell an exemption
# keyed on the actor from one that acquits everybody.
#
# IT OVERLAPS ARM 1's `Write` CELL AND ARM 1 OWNS THAT CELL. Widening the route key turns both red
# together, which is arms sharing one subject rather than an entangled pair: arm 1 asserts the
# cell, this arm asserts that the EXEMPTION did not take it away. Measured while building this
# section, driving the shipped fixture against a hook whose route grep was widened to the mention:
# the four BYPASS arms, the LOG deny arm and this twin go red together, and the teammate arms above
# and below stay green.
OUT="$(drive "$W" Write "$TR_BYPASS" "$W/_bmad-output/pipeline-snapshot.md")"
if denied "$OUT" && is_route_deny "$OUT"; then
  ok "TEAMMATE twin: the identical Write with NO \`agent_id\` is still ROUTE-denied, so the exemption is keyed on the actor and does not cover the lead"
elif denied "$OUT"; then
  bad "TEAMMATE twin: the lead's Write was denied, but not by Check 2z — the reason names no router, so this arm is reading another check's verdict and the acquittal probe proved nothing"
else
  bad "TEAMMATE twin: dropping the \`agent_id\` left the Write ALLOWED. The exemption covers the lead as well, so Check 2z is gone for every session and the incident reproduces."
fi

# THE LEAD THAT CARRIES `agent_type`. `claude --agent <name>` starts a LEAD whose every payload
# carries `agent_type` and no `agent_id` (see `drive()`). This is the input that tells an
# `agent_id`-keyed exemption from an `agent_type`-keyed one; the twin above cannot, because it
# carries neither field, and the teammate cell cannot, because it carries both. An exemption keyed
# on `agent_type` would exempt this lead from Check 2z outright -- a check that cannot fire on the
# population it exists for. Found by an adversarial hand after every other channel had accepted
# the `agent_type` spelling, because every seed supplied the two fields together.
OUT="$(drive "$W" Write "$TR_BYPASS" "$W/_bmad-output/pipeline-snapshot.md" TYPE-ONLY)"
if denied "$OUT" && is_route_deny "$OUT"; then
  ok "TEAMMATE agent-flag: a lead carrying \`agent_type\` and NO \`agent_id\` (a \`--agent\` session) is still ROUTE-denied, so the exemption is keyed on \`agent_id\` and not on the field a flagged lead also carries"
elif denied "$OUT"; then
  bad "TEAMMATE agent-flag: the \`--agent\` lead was denied, but not by Check 2z — the reason names no router, so this arm read another check's verdict"
else
  bad "TEAMMATE agent-flag: a lead carrying \`agent_type\` and no \`agent_id\` was ALLOWED. The exemption is keyed on \`agent_type\`, which a \`--agent\` lead also carries, so Check 2z cannot fire on such a session at all."
fi

# THE SCOPE OF THE EXEMPTION. It is a conjunct on Check 2z's guard, not an early return from the
# hook. A fresh PAUSED tree, as arm 5 seeds one, and a routed transcript so Check 2z has nothing
# to say either way: what answers must be Check 3's Rule 29 deny, read by its VALUE and not by the
# bare verdict. Whether a teammate SHOULD be pause-denied is a separate question; this arm holds
# the answer where the hook put it and does not decide it.
WT="$(seed teampaused paused)"
OUT="$(drive "$WT" Write "$TR_ROUTED" "$WT/_bmad-output/planning-artifacts/product-brief.md" "$AG")"
if denied "$OUT" && is_pause_deny "$OUT"; then
  ok "TEAMMATE pause: a teammate's artifact write on a PAUSED tree is still denied by Check 3's Rule 29"
elif denied "$OUT"; then
  bad "TEAMMATE pause: the teammate's paused write was denied by the WRONG check — the reason names no Rule 29, so this arm is reading Check 2z's verdict"
else
  bad "TEAMMATE pause: a teammate's write on a PAUSED tree was ALLOWED. The \`agent_id\` exemption has leaked out of Check 2z into the whole hook, and every check below it is now unreachable for a dispatched teammate."
fi

# AND THE LOG, ON A FRESH TREE so it cannot read another arm's record — the same both-directions
# pattern as section 4's allow arm. An exemption that returned the allow and still wrote the
# record would leave retro's Rule 25(c) audit counting denials that never happened.
WTL="$(seed teamlog)"
drive "$WTL" Write "$TR_BYPASS" "$WTL/_bmad-output/pipeline-snapshot.md" "$AG" >/dev/null
if grep -q 'ROUTE_DENIED' "$WTL/_bmad-output/pipeline-continuation-log.md" 2>/dev/null; then
  bad "TEAMMATE log: the teammate's ALLOWED Write still recorded a ROUTE_DENIED event — the audit that reads this file counts a denial that did not happen, and every nonzero count in it is meaningless"
else
  ok "TEAMMATE log: the teammate's allowed Write records no ROUTE_DENIED event"
fi

echo
if [ "$fails" -eq 0 ]; then echo "route-read-required: PASS"; exit 0; fi
echo "route-read-required: $fails assertion(s) FAILED" >&2
exit 1
