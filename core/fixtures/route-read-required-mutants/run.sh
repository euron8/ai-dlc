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
printf '{"type":"user","message":{"content":"<command-name>/ai-dlc</command-name>"}}\n' > "$TR_BYPASS"
printf '{"type":"assistant","message":{"content":[{"type":"text","text":"**READ AND FOLLOW:** `{project-root}/.claude/skills/ai-dlc/steps/route.md`"}]}}\n' >> "$TR_BYPASS"
cp "$TR_BYPASS" "$TR_ROUTED"
printf '{"type":"assistant","message":{"content":[{"type":"tool_use","id":"toolu_01","name":"Read","input":{"file_path":"/w/.claude/skills/ai-dlc/steps/route.md"}}]}}\n' >> "$TR_ROUTED"
printf '{"type":"user","message":{"content":"<command-name>/ai-dlc-update</command-name>"}}\n' > "$TR_UPDATER"
printf '{"type":"user","message":{"content":"fix the timezone bug in the ingest worker"}}\n' > "$TR_PLAIN"

PROBE_NAME=( bypass  routed  skill  agent  bash   notebook      updater  plain  )
PROBE_TOOL=( Write   Write   Skill  Agent  Bash   NotebookEdit  Write    Write  )
PROBE_TR=(   BYPASS  ROUTED  BYPASS BYPASS BYPASS BYPASS        UPDATER  PLAIN  )
BASELINE='DENY ALLOW ALLOW ALLOW ALLOW DENY ALLOW ALLOW'
CELLS='0 1 2 3 4 5 6 7'

tr_of() { case "$1" in BYPASS) printf '%s' "$TR_BYPASS";; ROUTED) printf '%s' "$TR_ROUTED";;
                       UPDATER) printf '%s' "$TR_UPDATER";; PLAIN) printf '%s' "$TR_PLAIN";; esac; }

verdict() { # <hook copy> <tool> <transcript token> -> ALLOW | DENY
  local out
  out="$(jq -nc --arg t "$2" --arg tr "$(tr_of "$3")" \
          '{session_id:"m",transcript_path:$tr,tool_name:$t,tool_input:{file_path:"/w/_bmad-output/x.md"}}' \
        | CLAUDE_PROJECT_DIR="$W" bash "$1" 2>/dev/null)"
  case "$out" in
    *'"permissionDecision": "deny"'*|*'"permissionDecision":"deny"'*) printf 'DENY' ;;
    *) printf 'ALLOW' ;;
  esac
}

row() { # <hook copy> -> the eight verdicts in PROBE order
  local h="$1" i out=""
  for i in $CELLS; do out="$out $(verdict "$h" "${PROBE_TOOL[$i]}" "${PROBE_TR[$i]}")"; done
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
  ok "CONTROL: an unmutated copy DENIES both write cells and allows the other six (positive conjunct: \`bypass\` and \`notebook\` are DENY, so a subject that emitted nothing would fail this)"
else
  bad "CONTROL: an unmutated copy answers '$CTRL' over (${PROBE_NAME[*]}), not '$BASELINE' — the harness, not the mutants, is what the arms below measure"
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
  score route-key-widened-to-mention 'ALLOW ALLOW ALLOW ALLOW ALLOW ALLOW ALLOW ALLOW' \
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
    case "$T" in Skill) want='DENY ALLOW DENY ALLOW ALLOW DENY ALLOW ALLOW';;
                 Agent) want='DENY ALLOW ALLOW DENY ALLOW DENY ALLOW ALLOW';;
                 Bash)  want='DENY ALLOW ALLOW ALLOW DENY DENY ALLOW ALLOW';; esac
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
    score surface-narrowed-drop-notebook 'DENY ALLOW ALLOW ALLOW ALLOW ALLOW ALLOW ALLOW' \
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
  score aidlc-guard-deleted 'DENY ALLOW ALLOW ALLOW ALLOW DENY DENY DENY' \
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
# 5. THE JOIN — a load-bearing cell the SHIPPED suite does not assert is still uncovered.
# =============================================================================
# Sections 1-4 prove these cells are load-bearing IN THE HOOK. They do not prove any consumer
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
           'DOWNSTREAM: Check 3' )
JOIN_WHY=( bypass "routed near-miss" "the remedy arms" "all three remedy tools" \
           "the whole denied surface including NotebookEdit" updater "not-an-ai-dlc-session" \
           "the checks below Check 2z" )
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
