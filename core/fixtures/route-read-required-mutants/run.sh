#!/usr/bin/env bash
# route-read-required-mutants — the mutation battery behind Check 2z, the router-read guard in
# `core/hooks/ai-dlc-acknowledge.sh`. DISTRIBUTION-ONLY.
#
# Usage: run.sh
# Exit:  0 = every arm is load-bearing and exclusively so, 1 = one is not, 2 = fixture broken.
#
# WHY IT EXISTS. Four of the shipped fixture's arms are ABSENCE-shaped -- "the remedy is not
# denied", "the updater is untouched", "a plain session is untouched", "no ROUTE_DENIED on the
# allow path". An absence-shaped arm passes against a subject that emits nothing, which is
# exactly what a hook copy that died looks like, and a both-directions near-miss does not
# repair that: it establishes that the arm discriminates between two inputs, never that it
# discriminates at all. Only a mutant establishes the second thing.
#
# WHAT A KILL IS HERE, AND IT IS TWO DIFFERENT SHAPES. Widening the DENIED SURFACE turns one
# allowed tool from ALLOW to DENY; widening the ROUTE KEY turns the one denied path from DENY
# to ALLOW. Both directions are represented on purpose -- a battery that only ever deletes a
# guard measures the misfire direction and never the leak direction, and the leak is the one
# that reproduces the incident.
#
# WHY IT DRIVES THE HOOK AND DOES NOT RE-RUN THE SHIPPED FIXTURE. Same reasoning as the sibling
# `pause-write-allowlist-mutants`: cell-level attribution is what tells a mutant that failed
# ONLY its own assertion from one that moved two, and re-running the subject once per mutant
# buys a coarser answer for more wall clock. The join to the shipped fixture is on NAMES
# instead (section 4) -- an arm must be load-bearing AND the shipped suite must be the thing
# that notices when it stops being.
#
# ONE BASELINE CELL HAS NO MUTANT, DELIBERATELY, AND IT IS A FINDING RATHER THAN AN OMISSION.
# Cell `updater` is held by two conjuncts at once. `AIDLC_SESSION=1` and `UPDATER_SESSION=0`
# are set from ONE first-match-wins `case` over the same `LAST_SKILL` value, whose `/ai-dlc`
# and `/ai-dlc-update` patterns are mutually exclusive -- and the payload arm that could set
# them independently only carries `.tool_input.skill` on a `Skill` call, which Check 2z's
# `Write|Edit|MultiEdit` surface never reaches. So no input can make the updater conjunct
# decide anything, and section 3 MEASURES that rather than asserting it: the conjunct is
# removed, every cell is re-read, and the census is printed beside a control conjunct whose
# removal does move a cell. Two guards that cover each other read exactly like two guards that
# do not work, and the symptom is zero failures.
set -uo pipefail

# HERMETIC -- scrub the operator's tuning before invoking any hook (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
HOOK=""
[ -n "$ROOT" ] && [ -f "$ROOT/core/hooks/ai-dlc-acknowledge.sh" ] \
  && HOOK="$ROOT/core/hooks/ai-dlc-acknowledge.sh"
[ -n "$HOOK" ] \
  || { echo "FIXTURE ERROR: core/hooks/ai-dlc-acknowledge.sh not found — this fixture is distribution-only" >&2; exit 2; }
SUBJ="$HERE/../route-read-required/run.sh"
[ -f "$SUBJ" ] || { echo "FIXTURE ERROR: sibling route-read-required/run.sh not found" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq is required" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# A live pipeline, NOT PAUSED, no adversarial series: the tree on which Check 2z is the only
# check that can deny anything, so a moved cell is attributable to it and to nothing else.
W="$WORK/tree"
mkdir -p "$W/_bmad-output/planning-artifacts/s7" "$W/scripts/ai-dlc"
: > "$W/_bmad-output/pipeline-snapshot.md"
printf '#!/bin/sh\necho 7\n' > "$W/scripts/ai-dlc/sprint-status.sh"
chmod +x "$W/scripts/ai-dlc/sprint-status.sh"

# Seeded from the harness's own serialization, not from the hook's grep (see the shipped
# fixture's header). `routed` is `bypass` plus exactly one line.
TR_BYPASS="$WORK/bypass.jsonl"; TR_ROUTED="$WORK/routed.jsonl"
TR_UPDATER="$WORK/updater.jsonl"; TR_PLAIN="$WORK/plain.jsonl"
printf '{"type":"user","message":{"role":"user","content":"<command-message>ai-dlc</command-message>\\n<command-name>/ai-dlc</command-name>\\n<command-args></command-args>"}}\n' > "$TR_BYPASS"
printf '{"type":"assistant","message":{"content":[{"type":"text","text":"**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/route.md`"}]}}\n' >> "$TR_BYPASS"
cp "$TR_BYPASS" "$TR_ROUTED"
printf '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_01","name":"Read","input":{"file_path":"/w/.claude/skills/ai-dlc/steps/route.md"}}]}}\n' >> "$TR_ROUTED"
printf '{"type":"user","message":{"role":"user","content":"<command-message>ai-dlc-update</command-message>\\n<command-name>/ai-dlc-update</command-name>\\n<command-args></command-args>"}}\n' > "$TR_UPDATER"
printf '{"type":"user","message":{"content":"fix the timezone bug in the ingest worker"}}\n' > "$TR_PLAIN"

# THE ACTOR IS A PROBE AXIS, not a variant of the transcript axis. `teammate` differs from
# `bypass` by exactly one property -- the `agent_id` the harness sets on a dispatched teammate's
# tool call -- and by nothing else: same tool, same transcript, same tree. Two cells one property
# apart are what tell an exemption keyed on the actor from one that acquits everybody, and the
# pair has to sit in ONE table or a mutant cannot be scored against both at once.
# THE TENTH CELL IS A LEAD, NOT A TEAMMATE, AND IT CARRIES `agent_type` ALONE. `claude --agent
# <name>` starts a lead whose payloads carry `agent_type` and no `agent_id` (measured in a
# headless session with a PreToolUse payload dumper: agent_id ABSENT, agent_type "Explore"). It
# is the only input that separates an `agent_id`-keyed exemption from an `agent_type`-keyed one:
# `teammate` carries both fields and every lead cell carries neither, so without this cell a
# mutant swapping the field name survives every row -- which is exactly what happened before it
# was added. Baseline DENY: a flagged lead that never routed is the check's own population.
PROBE_NAME=( bypass  routed  skill  agent  bash   notebook      updater  plain  teammate agentlead )
PROBE_TOOL=( Write   Write   Skill  Agent  Bash   NotebookEdit  Write    Write  Write    Write     )
PROBE_TR=(   BYPASS  ROUTED  BYPASS BYPASS BYPASS BYPASS        UPDATER  PLAIN  BYPASS   BYPASS    )
PROBE_AG=(   -       -       -      -      -      -             -        -      ax       type      )
BASELINE='DENY ALLOW ALLOW ALLOW ALLOW DENY ALLOW ALLOW ALLOW DENY'
CELLS='0 1 2 3 4 5 6 7 8 9'

tr_of() { case "$1" in BYPASS) printf '%s' "$TR_BYPASS";; ROUTED) printf '%s' "$TR_ROUTED";;
                       UPDATER) printf '%s' "$TR_UPDATER";; PLAIN) printf '%s' "$TR_PLAIN";; esac; }

verdict() { # <hook copy> <tool> <transcript token> [agent token; `-` is the LEAD] -> ALLOW | DENY
  # `agent_id` and `agent_type` are the HARNESS's field names, not this battery's: the shared
  # PreToolUse payload is enumerated in `ai-dlc-context-sensor.sh`, and both
  # `ai-dlc-gate-remediation-guard.sh` and `ai-dlc-subagent-probe.sh` read `agent_id` off it.
  local out
  out="$(jq -nc --arg t "$2" --arg tr "$(tr_of "$3")" --arg ag "${4:--}" \
          '{session_id:"m",transcript_path:$tr,tool_name:$t,tool_input:{file_path:"/w/_bmad-output/x.md"}}
           + (if $ag == "-" then {}
              elif $ag == "type" then {agent_type:"Explore"}
              else {agent_id:$ag,agent_type:"general-purpose"} end)' \
        | CLAUDE_PROJECT_DIR="$W" bash "$1" 2>/dev/null)"
  case "$out" in
    *'"permissionDecision": "deny"'*|*'"permissionDecision":"deny"'*) printf 'DENY' ;;
    *) printf 'ALLOW' ;;
  esac
}

row() { # <hook copy> -> one verdict per probe cell, in PROBE order
  local h="$1" i out=""
  for i in $CELLS; do
    out="$out $(verdict "$h" "${PROBE_TOOL[$i]}" "${PROBE_TR[$i]}" "${PROBE_AG[$i]}")"
  done
  printf '%s' "${out# }"
}

# The SECOND observable. The verdict row cannot see the log at all, so a mutation that writes a
# ROUTE_DENIED record on the allow path moves no cell and would score a survival.
logcell() { # <hook copy> <transcript token> -> PRESENT | ABSENT
  local lw="$WORK/log.$$"; rm -rf "$lw"; mkdir -p "$lw/_bmad-output/planning-artifacts/s7" "$lw/scripts/ai-dlc"
  : > "$lw/_bmad-output/pipeline-snapshot.md"
  printf '#!/bin/sh\necho 7\n' > "$lw/scripts/ai-dlc/sprint-status.sh"; chmod +x "$lw/scripts/ai-dlc/sprint-status.sh"
  jq -nc --arg tr "$(tr_of "$2")" \
     '{session_id:"m",transcript_path:$tr,tool_name:"Write",tool_input:{file_path:"/w/_bmad-output/x.md"}}' \
    | CLAUDE_PROJECT_DIR="$lw" bash "$1" >/dev/null 2>&1
  if grep -q 'ROUTE_DENIED' "$lw/_bmad-output/pipeline-continuation-log.md" 2>/dev/null
  then printf 'PRESENT'; else printf 'ABSENT'; fi
}

# THE THIRD OBSERVABLE, and it exists for the same reason the log cells do: no cell of the verdict
# table is PAUSED, so a mutation that turns Check 2z's `agent_id` conjunct into a whole-hook exit
# moves nothing in that table and would score a survival. This drives a teammate's AGENT DISPATCH
# on a PAUSED tree with a ROUTED transcript -- Check 2z has nothing to say either way, so what
# answers is Check 3's Rule 29 deny, which no teammate exemption may reach. (A teammate's WRITE is
# allowed by Check 3 itself while paused, so it cannot tell a whole-hook exit from the design.)
pausetree() { # -> fresh paused tree path
  local pw="$WORK/pause.$$"; rm -rf "$pw"
  mkdir -p "$pw/_bmad-output/planning-artifacts/s7" "$pw/scripts/ai-dlc"
  : > "$pw/_bmad-output/pipeline-snapshot.md"
  : > "$pw/_bmad-output/pipeline-paused.flag"
  printf '#!/bin/sh\necho 7\n' > "$pw/scripts/ai-dlc/sprint-status.sh"; chmod +x "$pw/scripts/ai-dlc/sprint-status.sh"
  printf '%s' "$pw"
}
pverdict() { # <hook copy> <tree> <tool> <agent token: - | type | id> -> DENY | ALLOW (deny must be Rule 29's)
  local out
  out="$(jq -nc --arg t "$3" --arg tr "$(tr_of ROUTED)" --arg ag "$4" --arg p "$2/_bmad-output/planning-artifacts/s7/prd.md" \
     '{session_id:"m",transcript_path:$tr,tool_name:$t,
       tool_input:(if $t == "NotebookEdit" then {notebook_path:$p} elif $t == "Agent" then {} else {file_path:$p} end)}
      + (if $ag == "-" then {} elif $ag == "type" then {agent_type:"Explore"}
         else {agent_id:$ag,agent_type:"general-purpose"} end)' \
    | CLAUDE_PROJECT_DIR="$2" bash "$1" 2>/dev/null)"
  case "$out" in
    *'Rule 29'*) printf 'DENY' ;;
    *'"permissionDecision"'*) printf 'OTHER' ;;
    *) printf 'ALLOW' ;;
  esac
}
pausecell() { # <hook copy> -> DENY | ALLOW  (a teammate's Agent dispatch on a paused tree)
  pverdict "$1" "$(pausetree)" Agent ax
}

# THE PAUSED TABLE -- Check 3's teammate decision, one property apart per cell. On a PAUSED tree:
# teammate Write, teammate Agent, lead Write, `--agent` lead Write (agent_type only), lead
# NotebookEdit (whose path field is `notebook_path`). Baseline: only the teammate's write goes through.
PAUSE_NAME=( team-write team-agent lead-write agentlead-write lead-notebook )
PAUSE_TOOL=( Write      Agent      Write      Write           NotebookEdit  )
PAUSE_AG=(   ax         ax         -          type            -             )
PAUSE_BASE='ALLOW DENY DENY DENY DENY'
prow() { # <hook copy> -> one verdict per paused cell
  local h="$1" i out=""
  for i in 0 1 2 3 4; do out="$out $(pverdict "$h" "$(pausetree)" "${PAUSE_TOOL[$i]}" "${PAUSE_AG[$i]}")"; done
  printf '%s' "${out# }"
}
pscore() { # <label> <expected paused row> <sentence>
  local got; got="$(prow "$WORK/$1.sh")"
  if [ "$got" = "$2" ]; then ok "MUTANT $1 $3"
  else bad "MUTANT $1: expected paused row '$2' over (${PAUSE_NAME[*]}), got '$got'"; fi
}
# The paused LOG: a teammate's allowed write must record ACK_TEAMMATE_WRITE and NO ACK_DENIED.
plogcell() { # <hook copy> -> "<ACK_TEAMMATE_WRITE count>/<ACK_DENIED count>"
  local pw a d; pw="$(pausetree)"
  pverdict "$1" "$pw" Write ax >/dev/null
  a="$(grep -c '^## .*-- ACK_TEAMMATE_WRITE' "$pw/_bmad-output/pipeline-continuation-log.md" 2>/dev/null)" || a=0
  d="$(grep -c '^## .*-- ACK_DENIED' "$pw/_bmad-output/pipeline-continuation-log.md" 2>/dev/null)" || d=0
  printf '%s/%s' "$a" "$d"
}

# Build a mutant as a COPY and refuse one that changed nothing: an unmutated copy answers the
# baseline and scores a survival on every clause.
mk() { # <label> <sed program> -> 0 = copy built and differs, 1 = refused (already reported)
  local label="$1" prog="$2" copy="$WORK/$1.sh"
  sed "$prog" "$HOOK" > "$copy" 2>/dev/null
  if cmp -s "$HOOK" "$copy"; then
    bad "MUTANT $label: the sed matched nothing — no mutation was applied, so nothing was proven"
    return 1
  fi
  return 0
}

# REPLACE OR INSERT AT A LOCATED LINE, rather than escaping a regex into a `sed` program.
# `cmp -s` proves bytes MOVED; it does not prove the right bytes moved. Measured while building
# this battery: a `sed` rewriting the route pattern's PREFIX left its trailing quote behind, so
# the mutant differed from the original, passed `cmp -s`, and produced a grep that still matched
# nothing -- a mutation that changed the file and not the behaviour. The kill assertion caught
# it; the anti-no-op guard could not. Locating the line and writing it whole removes the class.
#
# AN ANCHOR HELPER PRINTS ONLY A NUMBER. It is called inside `$( )`, so anything else it writes
# is CAPTURED rather than shown -- measured here: an early version reported a bad anchor through
# `bad()`, the sentence was captured as the line number, and the arithmetic below died with
# `invalid arithmetic operator` instead of naming the missing anchor. Report at the call site.
anchor() { # <fixed string> -> line number if UNIQUE, else "" (caller reports)
  [ "$(grep -cF -- "$1" "$HOOK")" = 1 ] || { printf ''; return; }
  grep -nF -- "$1" "$HOOK" | cut -d: -f1 | tr -d '\n'
}
# ...and the STRUCTURAL form, for a string that is deliberately not unique. Check 2z and Check 3
# both carry the `Write|Edit|MultiEdit|NotebookEdit)` surface, and they must: the tool sets are
# the same question asked twice. Mutating the wrong copy leaves every arm green and reads
# exactly like an arm that cannot fire, which `cmp -s` cannot catch because the edit applied
# cleanly to a file the run never consulted. So the surface is located RELATIVE to the route
# grep, which IS unique -- the nearest match above it is Check 2z's by construction, and the
# caller asserts exactly one match lies above.
anchor_before() { # <fixed string> <line> -> greatest matching line < <line>, if exactly one
  local n; n="$(grep -nF -- "$1" "$HOOK" | cut -d: -f1 | awk -v L="$2" '$1 < L' | wc -l | tr -d ' ')"
  [ "$n" = 1 ] || { printf ''; return; }
  grep -nF -- "$1" "$HOOK" | cut -d: -f1 | awk -v L="$2" '$1 < L' | tail -1 | tr -d '\n'
}
splice() { # <label> <line> <replace|after> <text> -> 0 = built and differs, 1 = refused
  local copy="$WORK/$1.sh" n="$2" keep
  [ "$3" = replace ] && keep=$((n-1)) || keep="$n"
  { head -n "$keep" "$HOOK"; printf '%s\n' "$4"; tail -n "+$((n+1))" "$HOOK"; } > "$copy"
  cmp -s "$HOOK" "$copy" && { bad "MUTANT $1: the splice changed nothing"; return 1; }
  return 0
}

score() { # <label> <expected row> <human sentence>
  local got; got="$(row "$WORK/$1.sh")"
  if [ "$got" = "$2" ]; then ok "MUTANT $1 $3"
  else bad "MUTANT $1: expected '$2' over (${PROBE_NAME[*]}), got '$got'"; fi
}

echo "route-read-required-mutants:"

# =============================================================================
# 0. THE UNMUTATED CONTROL, FIRST — and it carries a POSITIVE conjunct.
# =============================================================================
# A copy that dies emits nothing and nothing reads as ALLOW, so a control asserting only "no
# denials went wrong" passes against a subject replaced by `exit 0`. The baseline's `bypass`
# cell is DENY, so this control demands the hook produce something before any survival below
# is readable as evidence. The log cells are the same demand on the second observable.
cp "$HOOK" "$WORK/control.sh"
CTRL="$(row "$WORK/control.sh")"
if [ "$CTRL" = "$BASELINE" ]; then
  ok "CONTROL: an unmutated copy DENIES both lead write cells and allows every other cell including \`teammate\` (positive conjunct: \`bypass\` and \`notebook\` are DENY, so a subject that emitted nothing would fail this)"
else
  bad "CONTROL: an unmutated copy answers '$CTRL' over (${PROBE_NAME[*]}), not '$BASELINE' — the harness, not the mutants, is what the arms below measure"
fi
CP_ROW="$(prow "$WORK/control.sh")"; CP_LOG="$(plogcell "$WORK/control.sh")"
if [ "$CP_ROW" = "$PAUSE_BASE" ] && [ "$CP_LOG" = "1/0" ]; then
  ok "CONTROL: on a PAUSED tree an unmutated copy allows only the teammate's write (logged 1 ACK_TEAMMATE_WRITE / 0 ACK_DENIED) and Rule-29-denies the teammate's dispatch and every lead write"
else
  bad "CONTROL: paused row '$CP_ROW' over (${PAUSE_NAME[*]}) and log '$CP_LOG', not '$PAUSE_BASE' and '1/0'"
fi
CL_D="$(logcell "$WORK/control.sh" BYPASS)"; CL_A="$(logcell "$WORK/control.sh" ROUTED)"
if [ "$CL_D" = PRESENT ] && [ "$CL_A" = ABSENT ]; then
  ok "CONTROL: the log records ROUTE_DENIED on the deny path and nothing on the allow path"
else
  bad "CONTROL: log cells are '$CL_D'/'$CL_A' over (deny,allow), not 'PRESENT'/'ABSENT'"
fi

# =============================================================================
# 1. THE ROUTE KEY WIDENED — the LEAK direction, and the incident itself.
# =============================================================================
# `MENTIONING` route.md is not reading it. This is the plausible "simplify the pattern" edit,
# and it is the one that silently reproduces the incident: measured over 171 transcripts of the
# reference consumer, a string-keyed check matches 69 of the 69 `/ai-dlc` sessions and detects
# nothing at all, because SKILL.md's own INITIALIZATION prose carries the path.
LN_KEY="$(anchor '"file_path":"[^"]*steps/route')"
if [ -z "$LN_KEY" ]; then
  bad "ANCHOR: the route grep line is not unique in the hook — every mutation below is aimed at nothing, and a battery that cannot locate its subject must say so rather than report survivals"
elif splice route-key-widened-to-mention "$LN_KEY" replace \
       '      if ! grep -q '"'"'steps/route\.md'"'"' "$TRANSCRIPT" 2>/dev/null; then'; then
  # BOTH denial cells move, and they share ONE subject: the route key is what makes `bypass` and
  # `notebook` deny at all. This is arms overlapping on a single mutation, not an entangled pair.
  score route-key-widened-to-mention 'ALLOW ALLOW ALLOW ALLOW ALLOW ALLOW ALLOW ALLOW ALLOW ALLOW' \
    "turns both denial cells from DENY to ALLOW: keying on the string instead of a Read's file_path detects nothing"
fi

# =============================================================================
# 2. THE DENIED SURFACE WIDENED — the arm's own could-not-fire trap, one tool at a time.
# =============================================================================
# The remedy for this denial is to READ the router, reached through Skill/Agent dispatch and
# Bash. One mutant per tool rather than one that adds all three: a single mutant adding the
# whole set moves three cells at once, and a mutant that fails three assertions cannot tell an
# entangled arm from a bad mutation program.
SURF='Write|Edit|MultiEdit|NotebookEdit)'
LN_SURF=""
[ -n "$LN_KEY" ] && LN_SURF="$(anchor_before "$SURF" "$LN_KEY")"
if [ -z "$LN_SURF" ]; then
  bad "ANCHOR: could not locate exactly one \`$SURF\` line above the route grep. Check 3 carries the same tool set, so a battery that cannot tell the two apart would mutate the wrong copy, leave every cell green, and report a full sweep."
else
  for T in Skill Agent Bash; do
    case "$T" in Skill) want='DENY ALLOW DENY ALLOW ALLOW DENY ALLOW ALLOW ALLOW DENY';;
                 Agent) want='DENY ALLOW ALLOW DENY ALLOW DENY ALLOW ALLOW ALLOW DENY';;
                 Bash)  want='DENY ALLOW ALLOW ALLOW DENY DENY ALLOW ALLOW ALLOW DENY';; esac
    if splice "surface-widened-to-$T" "$LN_SURF" replace "    Write|Edit|MultiEdit|NotebookEdit|$T)"; then
      score "surface-widened-to-$T" "$want" \
        "turns \`$T\` from ALLOW to DENY: the deny would forbid the act it demands, and the pipeline wedges at its first step"
    fi
  done

  # THE OTHER DIRECTION ON THE SAME LINE. `NotebookEdit` was added to this surface because it is
  # on the hook's registered matcher and writes a file like the rest; dropping it back out is the
  # plausible "tidy the tool list" edit and it silently restores one unwatched way to produce a
  # file. A widening mutant cannot detect a narrowing regression.
  if splice surface-narrowed-drop-notebook "$LN_SURF" replace '    Write|Edit|MultiEdit)'; then
    score surface-narrowed-drop-notebook 'DENY ALLOW ALLOW ALLOW ALLOW ALLOW ALLOW ALLOW ALLOW DENY' \
      "turns \`NotebookEdit\` from DENY to ALLOW: the surface's coverage of it is load-bearing, not decorative"
  fi
fi

# =============================================================================
# 3. THE TWO SCOPE CONJUNCTS — one is load-bearing, one has no subject.
# =============================================================================
# Removed one at a time, and read as a CENSUS rather than as a pair of pass/fail arms. The
# AIDLC conjunct is the control that proves this probe can detect a conjunct removal at all;
# without it, "the updater conjunct moves nothing" is indistinguishable from a probe too coarse
# to see either.
if mk aidlc-guard-deleted 's#\[ "\$AIDLC_SESSION" = "1" \] && ##'; then
  # IT OWNS BOTH SCOPE CELLS, and that is the whole scope guard rather than two entangled arms.
  # `updater` and `plain` are both outside this check for the same reason -- neither is an
  # `/ai-dlc` session -- and one conjunct is what holds them there.
  score aidlc-guard-deleted 'DENY ALLOW ALLOW ALLOW ALLOW DENY DENY DENY ALLOW DENY' \
    "turns BOTH scope cells from ALLOW to DENY — the guard is what keeps the updater, and 12 of the reference consumer's 171 ordinary sessions, out of this check"
fi

# AND THE CONJUNCT THAT IS NO LONGER THERE. Check 2z carried `UPDATER_SESSION = 0` beside the
# guard above until a census run from this battery measured that removing it moved no cell of
# the probe table, against the control that removing `AIDLC_SESSION` DOES move one. The hook
# deleted it and wrote the reason at the site. This arm is the regression guard on that
# subtraction: a conjunct with no subject is a loaded gun, and the way it comes back is somebody
# adding it because it "looks like it belongs".
CHK2Z_IF="$(grep -F 'AIDLC_SESSION" = "1"' "$HOOK")"
if [ -z "$CHK2Z_IF" ]; then
  bad "REGRESSION GUARD: Check 2z's guard line could not be located, so this arm asserted nothing"
elif case "$CHK2Z_IF" in *UPDATER_SESSION*) true ;; *) false ;; esac; then
  # A `case`, not `printf | grep -q`. I54/I54b fired on the pipe form here, correctly: `grep -q`
  # leaves at its first match while the writer is still pushing, and under `pipefail` the
  # pipeline answers with the writer's EPIPE and reports NOT-FOUND on input that contains the
  # pattern. This file sets `pipefail`, and the status decides an assertion.
  bad "REGRESSION: an \`UPDATER_SESSION\` conjunct is back in Check 2z's guard. It decides nothing — both flags come from one first-match-wins case whose patterns are mutually exclusive, and the payload arm that could split them fires only on a Skill call this surface never sees. Re-derive before re-adding it."
else
  ok "REGRESSION GUARD: Check 2z's guard carries no \`UPDATER_SESSION\` conjunct (the census removed one that decided nothing on any reachable input)"
fi

# =============================================================================
# 4. THE LOG WRITTEN UNCONDITIONALLY — the second observable, which no cell can see.
# =============================================================================
# Injected rather than deleted: the shipped fixture's log arms are one PRESENCE and one
# ABSENCE, and only the absence needs a mutant. Splice a ROUTE_DENIED write above the guard so
# it fires on every Write, which is what "log it while we are in here" looks like as a diff.
if [ -n "$LN_SURF" ] && \
   splice log-unconditional "$LN_SURF" after \
     '        echo "## ${TIMESTAMP} -- ROUTE_DENIED" >> "$LOG_FILE"'; then
  ML_D="$(logcell "$WORK/log-unconditional.sh" BYPASS)"; ML_A="$(logcell "$WORK/log-unconditional.sh" ROUTED)"
  ML_R="$(row "$WORK/log-unconditional.sh")"
  if [ "$ML_A" = PRESENT ] && [ "$ML_D" = PRESENT ] && [ "$ML_R" = "$BASELINE" ]; then
    ok "MUTANT log-unconditional turns the ALLOW path's log cell from ABSENT to PRESENT and moves no verdict: the absence arm is falsifiable, so 'no ROUTE_DENIED on the allow path' means something"
  else
    bad "MUTANT log-unconditional: expected log 'PRESENT'/'PRESENT' and an unchanged verdict row; got '$ML_D'/'$ML_A' and '$ML_R'"
  fi
fi

# =============================================================================
# 5. THE TEAMMATE CONJUNCT DELETED — and the same exemption widened past its own check.
# =============================================================================
# Two mutations, one property each, failing in opposite directions. The first DELETES the
# `agent_id` conjunct from Check 2z's guard, which is the whole of the exemption: it must flip the
# `teammate` cell to DENY and move nothing else, because no other cell of the table carries an
# actor. The second leaves the conjunct alone and HOISTS the same test into a whole-hook early
# exit -- the plausible "a teammate is exempt, so say it once at the top" edit -- and it moves no
# cell of the verdict table at all, because no probe cell is PAUSED and Check 2z already allows
# the one cell that would notice.
#
# THAT SECOND MUTANT IS THE SAME BLINDNESS SECTION 4 ANSWERS, one observable over: the verdict row
# cannot see the log, and it cannot see a check that lives below the one being mutated. So it is
# answered the same way -- a second observable, here `pausecell()`, with the control scored beside
# the mutant in the same arm. A mutant scored only against the row would come back green here, and
# a survival that means "the probe cannot look there" reads exactly like a guard that is vestigial.
if mk teammate-conjunct-deleted 's#\[ -z "\$AGENT_ID" \] && ##'; then
  score teammate-conjunct-deleted 'DENY ALLOW ALLOW ALLOW ALLOW DENY ALLOW ALLOW DENY DENY' \
    "turns the \`teammate\` cell from ALLOW to DENY and moves no other cell: the exemption is load-bearing and keyed on the actor rather than on the transcript"
fi

# THE FIELD NAME SWAPPED. `agent_type` reads like a second spelling of `agent_id` and is not one:
# a `--agent` lead carries it too. This mutant is the one every earlier channel survived, because
# every seed supplied both fields together; it is killed by the `agentlead` cell alone, which
# flips DENY to ALLOW while `teammate` (both fields) and every neither-field lead cell hold.
if mk teammate-keyed-on-agent-type 's#\.agent_id // empty#.agent_type // empty#'; then
  score teammate-keyed-on-agent-type 'DENY ALLOW ALLOW ALLOW ALLOW DENY ALLOW ALLOW ALLOW ALLOW' \
    "turns the \`agentlead\` cell from DENY to ALLOW and moves nothing else: keying the exemption on \`agent_type\` exempts a \`--agent\` lead, and Check 2z cannot fire on such a session"
  # The same field swap reaches Check 3, which reads the same AGENT_ID: the `--agent` lead then
  # writes straight through a pause.
  pscore teammate-keyed-on-agent-type 'ALLOW DENY DENY ALLOW DENY' \
    "also turns the paused \`agentlead-write\` cell from DENY to ALLOW: Check 3's teammate arm keyed on \`agent_type\` lets a \`--agent\` lead through the pause"
fi

LN_AG="$(anchor 'AGENT_ID=$(echo "$INPUT"')"
if [ -z "$LN_AG" ]; then
  bad "ANCHOR: the AGENT_ID assignment is not unique in the hook, so the whole-hook exemption mutant is aimed at nothing and a battery that cannot locate its subject must say so rather than report a survival"
elif splice teammate-exemption-whole-hook "$LN_AG" after '[ -z "$AGENT_ID" ] || exit 0'; then
  MR="$(row "$WORK/teammate-exemption-whole-hook.sh")"
  CP="$(pausecell "$WORK/control.sh")"
  MP="$(pausecell "$WORK/teammate-exemption-whole-hook.sh")"
  if [ "$CP" = DENY ] && [ "$MP" = ALLOW ] && [ "$MR" = "$BASELINE" ]; then
    ok "MUTANT teammate-exemption-whole-hook moves NO verdict cell, and the paused probe catches it anyway: the control DENIES a teammate's paused Agent dispatch (Rule 29) where the mutant ALLOWS it, so \"the exemption is scoped to Check 2z\" is a falsifiable claim and not a description"
  else
    bad "MUTANT teammate-exemption-whole-hook: expected pause cells 'DENY'/'ALLOW' over (control,mutant) and an unchanged verdict row; got '$CP'/'$MP' and '$MR'"
  fi
fi

# =============================================================================
# 5b. CHECK 3's TEAMMATE ARM — the paused table. One mutant per property, scored on the row.
# =============================================================================
# Located by UNIQUE anchor and rewritten whole (see `splice`). Each mutant must move exactly the
# cell its property owns: the arm dropped denies the teammate's write; the arm widened to the
# dispatch tools lets the teammate spawn; the `notebook_path` fallback dropped lets the lead's
# notebook through. The log mutants are read on the second observable, which no row can see.
ck3() { # <label> <anchor> <replacement line> -> 0 = built
  local ln; ln="$(anchor "$2")"
  if [ -z "$ln" ]; then bad "ANCHOR: \`$2\` is not unique in the hook, so MUTANT $1 is aimed at nothing"; return 1; fi
  splice "$1" "$ln" replace "$3"
}
# Anchored on the TEAMMATE branch itself, not on the arm's opening line: the arm is three lines
# (updater, teammate, lead) and only this one owns the `team-write` cell. The replacement keeps
# the `elif` chain well-formed and makes the branch unreachable. The paused table's transcript is
# a routed `/ai-dlc` session, so the updater branch above it is inert and every cell is the lead's
# or the teammate's -- which is why the expected row is unchanged from the single-line arm.
if ck3 teammate-write-arm-dropped 'elif [ -n "$AGENT_ID" ]; then TEAMMATE_WRITE=1' \
     '        elif false; then :'; then
  pscore teammate-write-arm-dropped 'DENY DENY DENY DENY DENY' \
    "turns the paused \`team-write\` cell from ALLOW to DENY and moves nothing else: the teammate's in-flight write is let through by this arm alone"
fi
if ck3 teammate-arm-widened-to-dispatch '[ "$UPDATER_SESSION" -eq 1 ] || ADVANCING=1' \
     '    [ "$UPDATER_SESSION" -eq 1 ] || [ -n "$AGENT_ID" ] || ADVANCING=1'; then
  pscore teammate-arm-widened-to-dispatch 'ALLOW ALLOW DENY DENY DENY' \
    "turns the paused \`team-agent\` cell from DENY to ALLOW and moves nothing else: a teammate exemption on every tool lets a teammate spawn work past a waiting operator"
fi
if ck3 notebook-path-dropped ".tool_input.file_path // .tool_input.notebook_path // empty" \
     "    FP=\$(echo \"\$INPUT\" | jq -r '.tool_input.file_path // empty')"; then
  pscore notebook-path-dropped 'ALLOW DENY DENY DENY ALLOW' \
    "turns the paused \`lead-notebook\` cell from DENY to ALLOW and moves nothing else: NotebookEdit's \`notebook_path\` is what puts a notebook under the pause"
fi
if ck3 teammate-write-logged-as-denial 'echo "## ${TIMESTAMP} -- ACK_TEAMMATE_WRITE"' \
     '    echo "## ${TIMESTAMP} -- ACK_DENIED"'; then
  ML="$(plogcell "$WORK/teammate-write-logged-as-denial.sh")"; MR="$(prow "$WORK/teammate-write-logged-as-denial.sh")"
  if [ "$ML" = "0/1" ] && [ "$MR" = "$PAUSE_BASE" ]; then
    ok "MUTANT teammate-write-logged-as-denial moves the paused log from 1/0 to 0/1 and no verdict: an allowed write recorded as ACK_DENIED would inflate the denial count, and the log arm sees it"
  else
    bad "MUTANT teammate-write-logged-as-denial: expected log '0/1' and paused row '$PAUSE_BASE'; got '$ML' and '$MR'"
  fi
fi
# The attribution lines on the DENY row: drop `File:` and the lead's denial is unattributable again.
lead_log_has_file() { # <hook copy> -> YES | NO
  local pw; pw="$(pausetree)"
  pverdict "$1" "$pw" Write - >/dev/null
  if grep -qF -- "- File: $pw/_bmad-output/planning-artifacts/s7/prd.md" "$pw/_bmad-output/pipeline-continuation-log.md" 2>/dev/null \
     && grep -qF -- '- Agent: <lead>' "$pw/_bmad-output/pipeline-continuation-log.md" 2>/dev/null
  then printf YES; else printf NO; fi
}
CF="$(lead_log_has_file "$WORK/control.sh")"
if ck3 ack-denied-file-line-dropped 'echo "- File: ${FP:-<none>}"' '  echo "- Pause flag present"'; then
  MF="$(lead_log_has_file "$WORK/ack-denied-file-line-dropped.sh")"
  if [ "$CF" = YES ] && [ "$MF" = NO ]; then
    ok "MUTANT ack-denied-file-line-dropped: the control's ACK_DENIED row carries the lead actor and the file, the mutant's does not"
  else
    bad "MUTANT ack-denied-file-line-dropped: expected control/mutant 'YES'/'NO', got '$CF'/'$MF'"
  fi
fi

# =============================================================================
# 6. THE JOIN — a load-bearing cell the SHIPPED suite does not assert is still uncovered.
# =============================================================================
# Sections 1-5 prove these cells are load-bearing IN THE HOOK. They do not prove any consumer
# would find out: this battery is `.dist-only` and never runs there. `route-read-required` is
# the shipped fixture that drives Check 2z, so every cell must be named in it.
# JOIN ON THE LABEL EACH ARM EMITS, never on the cell's bare name. `grep -qi bash` is satisfied
# by the word `bash` in a shebang, a comment or an unrelated arm -- a hit inside a file is not
# a statement about that file, and a join that cannot fail is the mirror of a check that cannot
# fire. These are the strings the shipped fixture PRINTS when the cell holds.
JOIN_TOK=( 'BYPASS: \`$T\` is DENIED'
           'NEAR-MISS: adding the one'
           'REMEDY: \`$T\` is ALLOWED'
           'for T in Skill Agent Bash'
           'for T in Write Edit MultiEdit NotebookEdit'
           'SCOPE updater:'
           'SCOPE not-an-ai-dlc-session:'
           'DOWNSTREAM: Check 3'
           'TEAMMATE: a dispatched teammate'
           'TEAMMATE twin:'
           'TEAMMATE pause:'
           'TEAMMATE log:'
           'TEAMMATE agent-flag:'
           'PAUSE teammate write:'
           'PAUSE teammate spawn:'
           'PAUSE lead write:'
           'PAUSE agent-flag lead:'
           'PAUSE lead notebook:'
           'PAUSE teammate log:'
           'PAUSE lead log:' )
JOIN_WHY=( bypass "routed near-miss" "the remedy arms" "all three remedy tools" \
           "the whole denied surface including NotebookEdit" updater "not-an-ai-dlc-session" \
           "the checks below Check 2z" "the teammate exemption" \
           "the teammate's lead twin, one property apart" \
           "the exemption's scope at Check 3's pause deny" \
           "the teammate allow writing no ROUTE_DENIED row" \
           "the --agent lead carrying agent_type alone still being denied" \
           "the teammate's paused write allowed" "the teammate's paused dispatch denied" \
           "the lead's paused write denied" "the --agent lead's paused write denied" \
           "the lead's paused notebook denied" "the ACK_TEAMMATE_WRITE row" "the attributable ACK_DENIED row" )
i=0
while [ "$i" -lt ${#JOIN_TOK[@]} ]; do
  if grep -qF -- "${JOIN_TOK[$i]}" "$SUBJ"; then
    ok "the shipped subject asserts ${JOIN_WHY[$i]} at its own emission site (a consumer's suite goes red when it stops holding)"
  else
    bad "${JOIN_WHY[$i]} is load-bearing but route-read-required does not emit \`${JOIN_TOK[$i]}\`: the cell is proven here, in a fixture no consumer receives, and nowhere a consumer runs"
  fi
  i=$((i+1))
done
# ...and the join must be falsifiable. A token that CANNOT be present proves these greps
# discriminate rather than matching anything at all.
if grep -qF -- 'SCOPE this-arm-does-not-exist:' "$SUBJ"; then
  bad "JOIN CONTROL: an impossible token matched the shipped subject — the greps above are not discriminating"
else
  ok "JOIN CONTROL: an impossible token does not match, so the ${#JOIN_TOK[@]} hits above are real"
fi

echo
if [ "$fails" -eq 0 ]; then echo "route-read-required-mutants: PASS"; exit 0; fi
echo "route-read-required-mutants: $fails assertion(s) FAILED" >&2
exit 1
