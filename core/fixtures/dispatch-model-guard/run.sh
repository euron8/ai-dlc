#!/usr/bin/env bash
#
# Drives ai-dlc-dispatch-guard.sh against a seeded layered consumer.
#
# v0.79.x: the guard SETS the model instead of DENYING a wrong/absent one. On the correcting path
# it returns `permissionDecision: "allow"` with `updatedInput.model` = the role's pinned tier; on an
# already-correct or fail-open dispatch it exits 0 with NO output. So the assertions check the
# INJECTED tier, not a deny verdict.
#
# THE TEETH, restated for the flip. The motivating failure was a no-param spawn on a resumed session
# running on an undetermined model. The correcting cases below (absent param, wrong tier) must now
# emit `updatedInput.model` = the pin. If the guard silently reverted to allow-all, every correcting
# assertion reads empty and FAILS — the check cannot pass vacuously. The already-correct and
# fail-open cases must emit NOTHING (no forced approval, no injection), or the guard would be
# rewriting inputs it has no pin for, or force-approving dispatches another hook may need to deny.
set -uo pipefail

# The pre-push gate exports every AI_DLC_* tunable a consumer set in settings.json into this
# process. Scrub them so the hook is tested against its own defaults, not the tester's env.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# raw <project_dir> <json> -> hook stdout (decision JSON on a set, empty on a plain allow).
raw() { printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$HOOK" 2>/dev/null; }

# setmodel <project> <json> -> the injected updatedInput.model (empty if the hook emitted nothing).
setmodel() { raw "$1" "$2" | jq -r '.hookSpecificOutput.updatedInput.model // empty' 2>/dev/null; }
# verdict <project> <json> -> the permissionDecision (empty if the hook emitted nothing).
verdict() { raw "$1" "$2" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null; }

# mkjson <tool> <role|-> [model]   — builds an Agent dispatch binding a role file.
mkjson() {
  local bind=""
  [ "$2" != "-" ] && bind="Your operating contract is \`.claude/team-roles/$2.md\`. Read it first."
  jq -nc --arg t "$1" --arg p "$bind Do the work." --arg m "${3-}" '
    {tool_name: $t, tool_input: {prompt: $p, name: "teammate-s291-1"}}
    | if $m != "" then .tool_input.model = $m else . end'
}

# expect_set <project> <json> <want-tier> <label>
expect_set() {
  local got; got="$(setmodel "$1" "$2")"
  [ "$got" = "$3" ] && ok "$4 → set model=$3" \
    || bad "$4 → injected '$got', expected '$3' (the guard is not binding the pinned tier)"
}
# expect_untouched <project> <json> <label>  — no injection, no forced verdict.
expect_untouched() {
  local out; out="$(raw "$1" "$2")"
  [ -z "$out" ] && ok "$3 → untouched (exit 0, no decision)" \
    || bad "$3 → hook emitted '$out', expected NOTHING (it must not inject or force-approve here)"
}

# The prompt the guard hands back, for effort assertions.
newprompt() { raw "$1" "$2" | jq -r '.hookSpecificOutput.updatedInput.prompt // ""' 2>/dev/null; }
expect_effort() {  # expect_effort <root> <json> <level> <label>
  # THE EXTRACTOR IS THE GUARD'S OWN GRAMMAR AND MOVES WITH IT. It used to read
  # `/effort [a-z]+`, matching an imperative to run a slash command no file in this
  # distribution defines; the guard now STATES the level instead, so this matches the
  # statement. Anchored on the phrase AND the level so a guard that emitted the wrong
  # level, or the right level for the wrong role, is still caught.
  local got; got="$(newprompt "$1" "$2" | grep -oE 'reasoning effort for this role is [a-z]+' | head -1)"
  [ "$got" = "reasoning effort for this role is $3" ] \
    && ok "$4 -> prompt states the configured effort ($3)" \
    || bad "$4 -> expected the prompt to state effort '$3', got '${got:-<none>}'"
}
expect_model_kept() { # expect_model_kept <root> <json> <label>
  # The guard emitted (to append effort) but did NOT rewrite `model`. Distinguishes
  # "left the model alone" from "emitted nothing", which stopped being the same thing
  # once effort became a second, independent trigger.
  local m; m="$(raw "$1" "$2" | jq -r '.hookSpecificOutput.updatedInput.model // "<unset>"' 2>/dev/null)"
  local want; want="$(printf '%s' "$2" | jq -r '.tool_input.model // "<unset>"')"
  [ "$m" = "$want" ] \
    && ok "$3 -> model left as '$want'" \
    || bad "$3 -> model was rewritten to '$m', expected it left as '$want'"
}
expect_no_model() { # expect_no_model <root> <json> <label>
  raw "$1" "$2" | jq -e '.hookSpecificOutput.updatedInput | has("model") | not' >/dev/null 2>&1 \
    && ok "$3 -> no model bound" \
    || bad "$3 -> a model was bound where none is configured"
}
expect_no_effort() { # expect_no_effort <root> <json> <label>
  local got; got="$(newprompt "$1" "$2" | grep -oE 'reasoning effort for this role is [a-z]+' | head -1)"
  [ -z "$got" ] \
    && ok "$3 -> no effort stated" \
    || bad "$3 -> an effort was stated ('$got') where none should be"
}

echo "dispatch-model-guard"

# --- 1. gate-adjudicator with NO model param -> SET opus ---------------------
# The motivating failure. Absent model was UNDETERMINED; the guard now binds the pin.
expect_set "$CONSUMER" "$(mkjson Agent gate-adjudicator)" opus \
  "gate-adjudicator, no model param"

# --- 1b. the emission is `allow` (least restrictive) and names the tier + source ---
# allow is what makes this SAFE: deny > defer > ask > allow, so this cannot override the pause
# hook's deny. And the reason must name what it bound, or a reader cannot audit the correction.
J="$(mkjson Agent gate-adjudicator)"
[ "$(verdict "$CONSUMER" "$J")" = allow ] \
  && ok "set emits permissionDecision=allow (cannot override another hook's deny)" \
  || bad "set did not emit allow — either it still denies, or it emits a more-restrictive verdict"
# THIS ARM WAS SATISFIED BY THE WRONG STRING. It used to require the literal `role file`
# anywhere in the hook's output, and what supplied it was the EFFORT directive's own wording
# ("...before reading your role file."), not the reason. The reason has always cited
# `aiDlcRoles.<role>` in settings.json — which is the actual provenance, since the config is
# authoritative for both values and the role file states neither. Rewording the effort line
# turned the arm red and exposed that it was keyed on an unrelated sentence. It now asserts the
# config entry, which is the thing whose absence would make the correction unauditable.
raw_out="$(raw "$CONSUMER" "$J")"
if grep -q 'opus' <<<"$raw_out" && grep -q 'aiDlcRoles' <<<"$raw_out"; then
  ok "the correction names the tier it bound and cites the aiDlcRoles entry as the source"
else
  bad "the correction does not explain what it set or from where — unauditable"
fi
# and the injected input PRESERVES the rest of the call (the role binding is not dropped)
raw "$CONSUMER" "$J" | jq -e '.hookSpecificOutput.updatedInput.prompt | contains("team-roles/gate-adjudicator.md")' >/dev/null 2>&1 \
  && ok "updatedInput preserves the original prompt/role binding" \
  || bad "updatedInput dropped the prompt — the guard is replacing the input, not amending it"

# --- 2. remediator with no param -> SET opus --------------------------------
expect_set "$CONSUMER" "$(mkjson Agent remediator)" opus "remediator, no model param"

# --- 3. THE REAL S291 DEFECT: an EXPLICIT wrong tier -> OVERRIDE to opus -----
# remediator-s291-disc-p1/-prd-p1 requested sonnet against remediator's opus pin. The guard now
# corrects the call to the pin rather than rejecting it — a call site cannot override the role file.
expect_set "$CONSUMER" "$(mkjson Agent remediator sonnet)" opus \
  "remediator explicitly requested sonnet against an opus pin (the real S291 defect)"

# --- 4. correct tier -> UNTOUCHED (happy path keeps its approval posture) ----
# The call is still AMENDED — effort has to be appended — but the model is left alone.
# Model and effort are independent triggers; either can fire without the other.
expect_model_kept "$CONSUMER" "$(mkjson Agent gate-adjudicator opus)" \
  "gate-adjudicator requested opus against an opus config"
expect_model_kept "$CONSUMER" "$(mkjson Agent analyst sonnet)" \
  "analyst requested sonnet against a sonnet config"

# --- 5. a request CARRYING the key matches ----------------------------------
# The key is `opus`; a full model string containing it is the same model -> untouched.
# The tolerance is bounded by the DECLARED key, not by a hardcoded tier table.
expect_model_kept "$CONSUMER" "$(mkjson Agent gate-adjudicator 'claude-opus-5[1m]')" \
  "full model string carrying the configured key (key compare, not a tier guess)"

# --- 6. unpinned role -> UNTOUCHED (fail-open: tea/sm/ux/cis declare nothing)-
# No model param, so an absent `model` in updatedInput proves the guard bound none —
# with a param present it would be the CALLER's value surviving, which proves nothing.
expect_no_model "$CONSUMER" "$(mkjson Agent tea)" \
  "tea configures an effort but no model"
expect_model_kept "$CONSUMER" "$(mkjson Agent tea opus)" \
  "tea with an explicit model: the guard has no configured value to correct it to"

# --- 7. model key not defined in aiDlcModels -> NO MODEL BOUND (fail-open) ---
# architect's entry names `ghostkey`, which aiDlcModels does not define. The model must
# not be bound. Its EFFORT is still valid and still binds — proof the two resolve
# independently, so one broken half cannot silently take the other down with it.
expect_no_model "$CONSUMER" "$(mkjson Agent architect)" \
  "role whose configured model key is absent from aiDlcModels — no model bound"
expect_model_kept "$CONSUMER" "$(mkjson Agent architect sonnet)" \
  "and an explicitly wrong model is NOT corrected against an unresolvable key"
expect_effort "$CONSUMER" "$(mkjson Agent architect sonnet)" high \
  "the same role's valid effort still binds (the two resolve independently)"

# --- 8. the Ollama prose line is not a pin; the `- Model:` key binds ---------
expect_model_kept "$CONSUMER" "$(mkjson Agent dev sonnet)" \
  "dev configured sonnet: a sonnet request is left alone"
expect_set "$CONSUMER" "$(mkjson Agent dev opus)" sonnet \
  "dev.md opus request is corrected to the pinned sonnet (prose /model line is not the pin)"

# --- 8b. dev-escalated: model escalation is a ROLE, and its pin is bound ------
expect_model_kept "$CONSUMER" "$(mkjson Agent dev-escalated opus)" \
  "dev-escalated requested opus against its opus config (escalation happy path)"
expect_set "$CONSUMER" "$(mkjson Agent dev-escalated sonnet)" opus \
  "dev-escalated requested sonnet against its opus pin → corrected to opus (the escalation slip)"
expect_set "$CONSUMER" "$(mkjson Agent dev-escalated)" opus \
  "dev-escalated with no model param → set opus"

# --- 9. no role binding in the prompt -> UNTOUCHED --------------------------
expect_untouched "$CONSUMER" "$(mkjson Agent - opus)" \
  "dispatch with no role binding (not ours)"

# --- 10. non-dispatch tool -> UNTOUCHED ------------------------------------
expect_untouched "$CONSUMER" "$(jq -nc '{tool_name:"Edit",tool_input:{file_path:"/tmp/x",old_string:"a",new_string:"b"}}')" \
  "Edit (out of scope)"

# --- 11. activation gate: unstamped tree -> total no-op --------------------
expect_untouched "$NOSTAMP" "$(mkjson Agent gate-adjudicator)" \
  "unstamped tree (not a layered consumer)"

# --- 11b. no aiDlcModels block at all -> total no-op ------------------------
# A consumer whose settings.json predates the block (or was hand-trimmed) has no
# resolvable key for ANY role. The guard must bind nothing rather than fall back
# to a guess — this is the branch that makes a missing block safe to ship into.
expect_untouched "$NOMODELS" "$(mkjson Agent gate-adjudicator)" \
  "consumer settings.json carries no aiDlcModels block — fail-open"
expect_untouched "$NOMODELS" "$(mkjson Agent gate-adjudicator sonnet)" \
  "no aiDlcModels block, explicit wrong model — still fail-open, never a guess"

# --- 12. unknown role file -> UNTOUCHED (fail-open) ------------------------
expect_untouched "$CONSUMER" "$(mkjson Agent nonexistent-role)" \
  "unreadable/unknown role file — fail-open"

# --- 13. Task tool is in scope too -----------------------------------------
expect_set "$CONSUMER" "$(mkjson Task remediator)" opus \
  "Task-tool dispatch is policed like Agent"

# --- 13b. EFFORT is bound too, from the same config entry -------------------
# The Agent tool has no `effort` parameter, so the guard appends a `/effort` directive
# to the dispatch PROMPT. Without this the config would be authoritative for model and
# merely advisory for effort, and a teammate would have to read settings.json to learn
# its own effort — the compliance hope this release exists to remove.
expect_effort "$CONSUMER" "$(mkjson Agent gate-adjudicator)" high \
  "gate-adjudicator (config says high)"
expect_effort "$CONSUMER" "$(mkjson Agent dev)" medium \
  "dev (config says medium)"

# A role with an effort and NO model — the party-persona shape. Before this release it
# got no binding at all; now its effort is bound even though its model is not.
expect_effort "$CONSUMER" "$(mkjson Agent tea)" high \
  "tea has an effort but no model"
raw "$CONSUMER" "$(mkjson Agent tea)" | jq -e '.hookSpecificOutput.updatedInput | has("model") | not' >/dev/null 2>&1 \
  && ok "tea gets no model bound (it configures none) while still getting its effort" \
  || bad "a model was bound for tea, which configures none — the guard is inventing one"

# An unrecognised effort level is DROPPED, never injected. Injecting it would state a
# configured effort that is not one, in the authoritative voice of the config.
expect_no_effort "$CONSUMER" "$(mkjson Agent badeffort)" \
  "a role configured with an invalid effort level"

# --- 13c. IDEMPOTENCE: a well-formed dispatch keeps its approval posture -----
# The guard emits `allow` to carry `updatedInput`. If it emitted on every dispatch it
# would change the approval posture of calls it has nothing to correct, so a call that
# already carries the right model AND the effort directive must produce NO decision.
#
# THE LITERAL IS PINNED HERE ON PURPOSE, and it is what couples the guard's emitted line to its
# own dedupe test. The dedupe matches a substring of what the guard appends; change the line
# without changing the match and this arm goes red, which is the only thing standing between a
# reworded line and a guard that emits on every dispatch forever.
IDEM="$(jq -nc --arg p "contract is .claude/team-roles/gate-adjudicator.md

Your configured reasoning effort for this role is high. Operate at that level." \
  '{tool_name:"Agent",tool_input:{model:"opus",prompt:$p,name:"t"}}')"
expect_untouched "$CONSUMER" "$IDEM" \
  "a dispatch already carrying the configured model AND effort"

# ...and the dedupe must key on the LEVEL, not merely on the phrase. Without this the guard
# reads "already has an effort" as "already has the RIGHT effort", so a role reconfigured from
# medium to high keeps being dispatched at medium forever, silently and with a spawn-ledger row
# claiming otherwise. Measured as a live gap: dropping the level from the match killed no
# assertion in this file before this arm existed.
STALE="$(jq -nc --arg p "contract is .claude/team-roles/gate-adjudicator.md

Your configured reasoning effort for this role is medium. Operate at that level." \
  '{tool_name:"Agent",tool_input:{model:"opus",prompt:$p,name:"t"}}')"
#
# READ THE LAST OCCURRENCE, NOT THE FIRST. The guard APPENDS, so a prompt that already carried a
# stale statement ends up with both; the configured one is the one it added, and it is last.
# `expect_effort` takes the first match and is right for every other call site, where there is
# only one. Asserting the emission separately is what stops this arm from passing on a guard
# that stayed silent and left the stale line as the only match.
stale_out="$(newprompt "$CONSUMER" "$STALE" | grep -oE 'reasoning effort for this role is [a-z]+' | tail -1)"
[ "$stale_out" = "reasoning effort for this role is high" ] \
  && ok "a prompt carrying the WRONG level is re-stated at the configured one" \
  || bad "a prompt stating the wrong level was left at it (last statement: '${stale_out:-<none>}') — the dedupe matches the phrase without the level, so a reconfigured role is never re-stamped"
[ -n "$(raw "$CONSUMER" "$STALE")" ] \
  && ok "CONTROL: that dispatch produced a decision at all — the correction is an emission, not a silent pass" \
  || bad "CONTROL: the guard emitted nothing for a dispatch carrying the wrong level"

# --- 13c-MUT. the idempotence arm is an ABSENCE, so prove it can fire ---------
# `expect_untouched` asserts the hook emitted NOTHING, and a hook that emits nothing for every
# input satisfies it perfectly. That arm is the only thing coupling the guard's emitted effort
# line to its own dedupe test — reword one without the other and it is what goes red — so an
# arm that cannot fire would silently uncouple them. The guard sources no siblings, so a lone
# copy is a faithful subject here; the unmutated control states that rather than assuming it.
MCTL="$WORK/guard-control.sh"; cp "$HOOK" "$MCTL"
[ -z "$(printf '%s' "$IDEM" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$MCTL" 2>/dev/null)" ] \
  && ok "MUTANT CONTROL: an unmutated copy of the guard is still silent on the idempotent dispatch" \
  || bad "MUTANT CONTROL is dead — a copy of the guard behaves differently from the original, so the kill below is unearned"

# THE MUTATION MUST MAKE THE DEDUPE MATCH NOTHING, NOT MATCH EVERYTHING, and the first
# attempt here got that backwards. Widening the pattern to `*)` means NEEDS_EFFORT is never
# set, so the mutant emits nothing on this input — which is exactly what the ORIGINAL does,
# and the arm scored a kill it had not earned. Narrowing it to a token no prompt contains
# sends every dispatch down the `NEEDS_EFFORT=true` branch, so the idempotent one starts
# emitting. Assert the POSITIVE outcome.
MGUARD="$WORK/guard-nodedupe.sh"
sed 's|\*"reasoning effort for this role is \${PIN_EFFORT}"\*) : ;;|*"__NO_PROMPT_CONTAINS_THIS__"*) : ;;|' "$HOOK" > "$MGUARD"
if cmp -s "$HOOK" "$MGUARD"; then
  bad "MUTANT matched nothing (cmp -s guard) — the idempotence arm proves nothing"
else
  [ -n "$(printf '%s' "$IDEM" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$MGUARD" 2>/dev/null)" ] \
    && ok "MUTANT: with the dedupe unable to match, the idempotent dispatch starts emitting — so that arm is live" \
    || bad "MUTANT: the idempotent dispatch stayed silent even with the dedupe disabled — the idempotence arm passes whatever the guard does"
fi

# --- 13d. a role with no config entry -> UNTOUCHED (fail-open) --------------
expect_untouched "$CONSUMER" "$(mkjson Agent nocfg)" \
  "role file with no aiDlcRoles entry — fail-open, binds nothing"

# --- 14. FIXTURE STALENESS: the real core role files must still parse -------
REAL_PTR="$(grep -c 'aiDlcRoles\.' "$SRC_ROLES/gate-adjudicator.md" 2>/dev/null)"; REAL_PTR="${REAL_PTR:-0}"
[ "$REAL_PTR" -gt 0 ] && ok "real core gate-adjudicator.md points at its aiDlcRoles entry" \
  || bad "FIXTURE STALE: core/team-roles/gate-adjudicator.md no longer names aiDlcRoles — the role file and the config have been decoupled without updating this fixture"

REAL_PIN="$(grep -c '^- Model: \|^- `/effort ' "$SRC_ROLES/gate-adjudicator.md" 2>/dev/null)"; REAL_PIN="${REAL_PIN:-0}"
[ "$REAL_PIN" -eq 0 ] && ok "real core role files state no model or effort of their own (config owns both)" \
  || bad "FIXTURE STALE: core/team-roles/gate-adjudicator.md has grown a '- Model:' or '- /effort' line back. Two sources for one value is the drift this release removed; the guard reads only the config, so an in-file value would be silently ignored."

# --- SPAWN LEDGER (v0.158.0) --------------------------------------------------
# Check 22 reads this file instead of a table the lead writes about itself. The
# assertions below are what make that substitution safe: a row per dispatch, the
# model ACTUALLY bound (not requested), and the Rule 19(b) citation observed
# rather than claimed.
LEDGER="$CONSUMER/_bmad-output/spawn-ledger.jsonl"
mkdir -p "$CONSUMER/_bmad-output"
printf -- '- **sprint_id:** 291\n' > "$CONSUMER/_bmad-output/pipeline-snapshot.md"
lrow() { jq -c 'select(.name != null)' "$LEDGER" 2>/dev/null | tail -1; }
# `tostring`, NOT `// "null"`: jq's alternative operator treats `false` as absent,
# so `.role_contract_cited // "null"` reports "null" for the very value these
# assertions exist to catch — a boolean field read through `//` can never be false.
lfield() { lrow | jq -r "$1 | tostring" 2>/dev/null; }

# A corrected dispatch must record BOTH values. Recording only the bound model
# would hide the slip; only the requested one would misreport what ran.
rm -f "$LEDGER"
raw "$CONSUMER" "$(mkjson Agent remediator sonnet)" >/dev/null
[ "$(lfield .model_requested)" = "sonnet" ] && [ "$(lfield .model_bound)" = "opus" ] \
  && ok "corrected dispatch records requested=sonnet AND bound=opus (the slip stays visible)" \
  || bad "ledger recorded requested='$(lfield .model_requested)' bound='$(lfield .model_bound)', expected sonnet/opus"

[ "$(lfield .role_contract_cited)" = "true" ] \
  && ok "role_contract_cited=true when the prompt names team-roles/<role>.md" \
  || bad "role_contract_cited='$(lfield .role_contract_cited)', expected true"

# An ALREADY-CORRECT dispatch emits nothing on stdout but must still be recorded,
# or Check 22 sees only the sprint's mistakes and reads a clean sprint as no spawns.
rm -f "$LEDGER"
raw "$CONSUMER" "$(mkjson Agent gate-adjudicator opus)" >/dev/null
[ "$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')" = "1" ] \
  && ok "an already-correct dispatch is still recorded (silence on stdout is not silence on disk)" \
  || bad "already-correct dispatch wrote $(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ') row(s), expected 1"

# subagent_type-only: before v0.158.0 this was a total no-op — no binding, no row.
# It is the likeliest route by which a protected-path-editor reached sonnet on the
# reference consumer while the guard sat installed and green.
rm -f "$LEDGER"
J="$(jq -nc '{tool_name:"Agent",tool_input:{name:"t-1",model:"sonnet",subagent_type:"remediator",prompt:"Do the work."}}')"
[ "$(setmodel "$CONSUMER" "$J")" = "opus" ] \
  && ok "subagent_type-only dispatch is bound (was a silent no-op before v0.158.0)" \
  || bad "subagent_type-only dispatch injected '$(setmodel "$CONSUMER" "$J")', expected opus"
raw "$CONSUMER" "$J" >/dev/null
[ "$(lfield .role_contract_cited)" = "false" ] \
  && ok "  and records role_contract_cited=false — the Rule 19(b) omission stays visible" \
  || bad "  role_contract_cited='$(lfield .role_contract_cited)', expected false"

# Fail-closed: a role file that does not resolve is a Rule 19 violation, and it
# must be RECORDED. Exiting before the write would make it look like no dispatch.
rm -f "$LEDGER"
raw "$CONSUMER" "$(mkjson Agent nonexistent-role opus)" >/dev/null
[ "$(lfield .role_file_readable)" = "false" ] \
  && ok "unresolvable role file is recorded (role_file_readable=false), not silently skipped" \
  || bad "unresolvable role file recorded readable='$(lfield .role_file_readable)', expected false"

# A dispatch with no role at all is not a teammate spawn — no row, or Check 22
# inherits noise it must then explain away.
rm -f "$LEDGER"
raw "$CONSUMER" "$(mkjson Agent - opus)" >/dev/null
[ ! -s "$LEDGER" ] \
  && ok "a dispatch binding no role writes no row (not our spawn)" \
  || bad "a role-less dispatch wrote a ledger row: $(lrow)"

# --- SPRINT STAMP: THE READER MUST NOT SPELL THE DECORATION -------------------
# EVERY SEED HERE USED TO BE THE EMPHASISED BULLET, WHICH IS THE FORM THE READER
# ALREADY ACCEPTED. That is seeding from the reader's accept-set: it proved the
# hook accepts its own grammar and stayed green while the hook resolved EMPTY on
# the plain bullet the snapshot writer actually emits. Measured over 2066 real
# snapshot revisions, the old spelling resolved nothing on 195 of them.
# Both forms are asserted BESIDE each other, in this run, because a second clean
# tree can only ask whether the read fires at all -- never whether it fires on
# the right shape. Every arm is PRESENCE-shaped: it demands a specific sprint
# value, so a hook that resolves nothing fails it rather than passing quietly.
sprint_of() { # sprint_of <snapshot-line>  -> the .sprint the guard recorded
  rm -f "$LEDGER"
  printf -- '%s\n' "$1" > "$CONSUMER/_bmad-output/pipeline-snapshot.md"
  raw "$CONSUMER" "$(mkjson Agent remediator sonnet)" >/dev/null
  lfield .sprint
}

[ "$(sprint_of '- sprint_id: 291')" = "291" ] \
  && ok "plain bullet resolves the sprint (the form the snapshot writer emits)" \
  || bad "plain '- sprint_id: 291' recorded sprint='$(sprint_of '- sprint_id: 291')', expected 291 — the reader is spelling the decoration again"

[ "$(sprint_of '- **sprint_id:** 291')" = "291" ] \
  && ok "  and the emphasised bullet still resolves it (the fix widened, it did not move)" \
  || bad "emphasised bullet recorded sprint='$(sprint_of '- **sprint_id:** 291')', expected 291 — this is the regression the fix must not cause"

# The near-miss, beside the offender: a non-numeric value is the schema saying no
# sprint is assigned yet, and null is the right answer. Without this arm the two
# above are satisfied by a read that matches anything after the colon.
[ "$(sprint_of '- sprint_id: TBD')" = "null" ] \
  && ok "  and a non-numeric value stays null (TBD/none/S270 mean no sprint is assigned)" \
  || bad "'- sprint_id: TBD' recorded sprint='$(sprint_of '- sprint_id: TBD')', expected null"

# The three readers share one expression by hand, and I104 fails the push if they
# diverge. This asserts the BEHAVIOUR the invariant protects is actually present
# in the copy this fixture drives, so a byte-identical set of three broken reads
# cannot pass on agreement alone.
printf -- '- **sprint_id:** 291\n' > "$CONSUMER/_bmad-output/pipeline-snapshot.md"

# --- 13e. THE RENDERED DEFINITION: subagent_type rewrite, name and model deleted ----
# A definition's `effort:` is APPLIED by the harness where the guard's prompt sentence is
# only advisory, so this is the binding half of the release. Three properties, and all
# three must hold together or the dispatch silently loses its effort:
#
#   * `subagent_type` names the role, so the harness selects `.claude/agents/<role>.md`;
#   * `name` is GONE, because a name routes the spawn to the in-process teammate runner,
#     which spreads the definition's model and NOT its effort;
#   * `model` is GONE, because an explicit param outranks the definition's `model:`.
#
# EACH IS ASSERTED SEPARATELY AND THE WRONG FIXES ARE SEEDED BELOW. A single arm reading
# "the type was rewritten" passes against a guard that rewrites the type and leaves the
# name — which is the shape that reads as working and delivers nothing.
defout() { raw "$CONSUMER" "$1"; }
defui()  { defout "$1" | jq -c '.hookSpecificOutput.updatedInput' 2>/dev/null; }

DEFJ="$(mkjson Agent defok sonnet)"
[ "$(defui "$DEFJ" | jq -r '.subagent_type // "<unset>"')" = "defok" ] \
  && ok "definition-bound: subagent_type rewritten to the role (the harness selects .claude/agents/defok.md)" \
  || bad "definition-bound: subagent_type is '$(defui "$DEFJ" | jq -r '.subagent_type // "<unset>"')', expected 'defok' — the definition is not selected and its effort cannot apply"
defui "$DEFJ" | jq -e 'has("name") | not' >/dev/null 2>&1 \
  && ok "  and \`name\` is DELETED (a name routes to the teammate runner, which drops effort)" \
  || bad "  \`name\` SURVIVED the rewrite: $(defui "$DEFJ" | jq -r '.name') — the spawn goes to the runner that ignores the definition's effort"
defui "$DEFJ" | jq -e 'has("model") | not' >/dev/null 2>&1 \
  && ok "  and \`model\` is DELETED (an explicit param outranks the definition's model:)" \
  || bad "  \`model\` SURVIVED the rewrite: $(defui "$DEFJ" | jq -r '.model') — two live sources for one value"
# The prompt is amended, never replaced — same property the model path asserts.
defui "$DEFJ" | jq -e '.prompt | contains("team-roles/defok.md")' >/dev/null 2>&1 \
  && ok "  and the original prompt/role binding survives the rewrite" \
  || bad "  the rewrite dropped the prompt — the guard is replacing the input, not amending it"

# THE LEDGER RECORDS THE ACT. `name_stripped` carries the deleted value, so a reader can
# still identify the dispatch; `model_bound` is read from the DEFINITION FILE, not from
# settings, because the file is what the harness selects and the two diverge on a stale
# render. `tool_use_id` is the join key Check 22's effort arm resolves on.
rm -f "$LEDGER"
DEFJT="$(printf '%s' "$DEFJ" | jq -c '. + {tool_use_id: "toolu_FIXTURE_1"}')"
raw "$CONSUMER" "$DEFJT" >/dev/null
[ "$(lfield .definition_bound)" = "true" ] \
  && ok "  ledger records definition_bound=true" \
  || bad "  ledger recorded definition_bound='$(lfield .definition_bound)', expected true"
[ "$(lfield .name_stripped)" = "teammate-s291-1" ] \
  && ok "  ledger records the name it deleted (name_stripped), so the dispatch stays identifiable" \
  || bad "  name_stripped='$(lfield .name_stripped)', expected 'teammate-s291-1' — the deletion is unrecorded"
[ "$(lfield .model_bound)" = "opus" ] \
  && ok "  model_bound is the definition's model: line, which is what the harness applies" \
  || bad "  model_bound='$(lfield .model_bound)', expected 'opus'"
[ "$(lfield .tool_use_id)" = "toolu_FIXTURE_1" ] \
  && ok "  ledger records tool_use_id — the order-free join key Check 22's effort arm needs" \
  || bad "  tool_use_id='$(lfield .tool_use_id)', expected 'toolu_FIXTURE_1'; without it the effort arm joins on an ORDERED key and mis-pairs two same-role spawns that finish out of order"

# `effort_bound` MIRRORS `model_bound`: the DISPATCH, not the config. Read from the seeded
# definition rather than written here, for the reason model_bound is read from the file — a
# hardcoded expectation is satisfied by a guard that copies settings whenever settings and
# the definition agree, which is every green tree.
DEFOK_EFFORT="$(awk '/^effort:[[:space:]]/{sub(/^effort:[[:space:]]*/,""); print; exit}' \
                   "$CONSUMER/.claude/agents/defok.md")"
[ -n "$DEFOK_EFFORT" ] \
  && ok "  CONTROL: the seeded defok.md declares an effort ($DEFOK_EFFORT) — the arm below has a value to compare"  \
  || bad "  CONTROL is dead: .claude/agents/defok.md carries no effort: line, so the assertion below compares nothing"
[ "$(lfield .effort_bound)" = "$DEFOK_EFFORT" ] \
  && ok "  effort_bound is the definition's effort: line, which is what the harness applies" \
  || bad "  effort_bound='$(lfield .effort_bound)', expected '$DEFOK_EFFORT' from .claude/agents/defok.md"

# THE DISCRIMINATING SEED. `defnodef` pins an effort in settings and has NO rendered
# definition, so nothing binds an effort for it: the configured level reaches the teammate as
# the guard's prompt sentence, which is advisory and applies nothing. A row claiming an effort
# was bound there is the defect — it is what makes an unbound dispatch read as a bound one,
# and it is what this guard recorded before `effort_bound` moved off the config.
NODEF_PIN="$(jq -r '.aiDlcRoles.defnodef.effort // ""' "$CONSUMER/.claude/settings.json")"
[ -n "$NODEF_PIN" ] && [ ! -e "$CONSUMER/.claude/agents/defnodef.md" ] \
  && ok "  CONTROL: defnodef pins effort '$NODEF_PIN' in settings AND has no rendered definition — the two states the arm below separates" \
  || bad "  CONTROL is dead: defnodef pins '$NODEF_PIN' and its definition is $( [ -e "$CONSUMER/.claude/agents/defnodef.md" ] && echo present || echo absent ) — a null here would prove nothing"
rm -f "$LEDGER"; raw "$CONSUMER" "$(mkjson Agent defnodef)" >/dev/null
[ "$(lfield .effort_bound)" = "null" ] \
  && ok "  a dispatch with no definition records effort_bound=null even though its role pins one — the prompt line is advisory and binds nothing" \
  || bad "  effort_bound='$(lfield .effort_bound)' on a dispatch that bound no effort, expected null: the field is recording the CONFIG, so a row nothing applied an effort to reads as one that did"
# ...and the row exists, so the null above is a recorded null and not an unwritten row.
[ "$(lfield .role)" = "defnodef" ] \
  && ok "  CONTROL: that dispatch wrote a row at all — the null is a recorded value, not a missing one" \
  || bad "  CONTROL: no row was written for the defnodef dispatch, so the null above is the absence of a row"

# --- 13f. A STALE DEFINITION IS NOT SELECTED --------------------------------
# A rendered file that no longer projects the config would run the teammate on a value
# nobody declared. The guard falls back to today's behaviour and SAYS so. Both stale
# shapes are asserted — model-disagrees and effort-disagrees — because the agreement test
# is a conjunction and a seed exercising one half leaves the other droppable.
for _r in defstalemodel defstaleeffort; do
  _j="$(mkjson Agent "$_r")"
  [ "$(defui "$_j" | jq -r '.subagent_type // "<unset>"')" = "<unset>" ] \
    && ok "stale definition ($_r): subagent_type NOT rewritten — a drifted render is never selected" \
    || bad "stale definition ($_r): the guard selected it anyway (subagent_type=$(defui "$_j" | jq -r '.subagent_type'))"
  rm -f "$LEDGER"; raw "$CONSUMER" "$_j" >/dev/null
  [ "$(lfield .definition_stale)" = "true" ] && [ "$(lfield .definition_bound)" = "false" ] \
    && ok "  and the row says definition_stale=true, definition_bound=false" \
    || bad "  row recorded stale='$(lfield .definition_stale)' bound='$(lfield .definition_bound)', expected true/false"
done
# ...and the drift is REPORTED to the lead, with the remedy named. A silent fallback is
# how a drifted definition stays drifted.
# Captured, not piped into `grep -q` — see the I54 note on the absent-definition arm below.
STALE_CTX="$(raw "$CONSUMER" "$(mkjson Agent defstalemodel)" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)"
grep -q 'STALE' <<<"$STALE_CTX" \
  && ok "  and the lead is told the definition is STALE and how to re-render it" \
  || bad "  the stale fallback is silent — nothing tells the lead the binding half did not happen"

# --- 13g. AN UNMARKED FILE IS A CONSUMER'S OWN AND IS LEFT ALONE -------------
# `.claude/agents/` is consumer-writable. The seeded `defunmarked.md` AGREES with settings
# in every field and differs from a rendered one only by the marker, so this arm can only
# be satisfied by a guard that keys on the marker — not by one that keys on disagreement.
[ "$(defui "$(mkjson Agent defunmarked)" | jq -r '.subagent_type // "<unset>"')" = "<unset>" ] \
  && ok "an UNMARKED .claude/agents file is never selected, even though it agrees with settings" \
  || bad "the guard selected a file this distribution did not render — the marker is not being read"

# --- 13h. ABSENT DEFINITION: today's behaviour, and the lead is told why -----
# THE FAIL-OPEN DIRECTION. `subagent_type` must never be rewritten to a name the harness
# cannot resolve: that ERRORS the spawn, which is worse than mis-binding it.
ABSJ="$(mkjson Agent defnodef)"
[ "$(defui "$ABSJ" | jq -r '.subagent_type // "<unset>"')" = "<unset>" ] \
  && ok "absent definition: subagent_type NOT rewritten (a type the harness cannot resolve errors the spawn)" \
  || bad "absent definition: the guard rewrote subagent_type to a definition that does not exist"
[ "$(defui "$ABSJ" | jq -r '.model // "<unset>"')" = "opus" ] \
  && ok "  and today's behaviour still applies — the model is bound as before" \
  || bad "  the absent branch stopped binding the model: got '$(defui "$ABSJ" | jq -r '.model // "<unset>"')'"
rm -f "$LEDGER"; raw "$CONSUMER" "$ABSJ" >/dev/null
[ "$(lfield .definition_bound)" = "false" ] && [ "$(lfield .definition_stale)" = "false" ] \
  && ok "  row records definition_bound=false with definition_stale=false — absent and drifted are different facts" \
  || bad "  row recorded bound='$(lfield .definition_bound)' stale='$(lfield .definition_stale)', expected false/false"
# NO `| grep -q` OFF A PIPELINE (I54): grep leaves at its first match while the writer is
# still pushing, and under pipefail the pipeline answers with the writer's EPIPE — NOT-FOUND
# on input that contains the pattern, above a size threshold and with no symptom. Capture,
# then feed the reader a here-string.
ABS_CTX="$(raw "$CONSUMER" "$ABSJ" | jq -r '.hookSpecificOutput.additionalContext' 2>/dev/null)"
grep -q 'no rendered .claude/agents/defnodef.md' <<<"$ABS_CTX" \
  && ok "  and the lead is told the definition is MISSING and given the render command" \
  || bad "  the missing definition is not reported — the lead cannot see that the effort binding did not happen"

# A role whose settings declare NO effort, rendered with no `effort:` line: absent must
# AGREE with absent. Without this, every such render reads as stale and binds nothing.
[ "$(defui "$(mkjson Agent defnoeffort)" | jq -r '.subagent_type // "<unset>"')" = "defnoeffort" ] \
  && ok "a definition with no effort: line AGREES with a role declaring no effort (absent == absent)" \
  || bad "a role declaring no effort was called stale against a render that correctly omits the key"

# --- 13i. IDEMPOTENCE ON THE DEFINITION PATH --------------------------------
# The rewrite emits `allow` to carry `updatedInput`, so it must not fire on a dispatch
# already in the target shape, or every correct call has its approval posture changed.
IDEMDEF="$(jq -nc --arg p "Your operating contract is \`.claude/team-roles/defok.md\`.

Your configured reasoning effort for this role is high. Operate at that level." \
  '{tool_name:"Agent",tool_input:{subagent_type:"defok",prompt:$p}}')"
expect_untouched "$CONSUMER" "$IDEMDEF" \
  "a dispatch already carrying the rewritten type, no name and no model"

# ...and the three conditions are read SEPARATELY. A guard that keyed idempotence on the
# type alone would leave a surviving `name` in place — the exact state that drops effort —
# while reporting nothing. Each near-miss differs from the idempotent call by ONE property.
IDEM_NAME="$(printf '%s' "$IDEMDEF" | jq -c '.tool_input.name = "surviving-name"')"
[ -n "$(raw "$CONSUMER" "$IDEM_NAME")" ] \
  && ok "  a correct type WITH a surviving name still fires (the name is what drops the effort)" \
  || bad "  a dispatch carrying a name was read as already-correct — it routes to the teammate runner and the definition's effort never applies"
IDEM_MODEL="$(printf '%s' "$IDEMDEF" | jq -c '.tool_input.model = "opus"')"
[ -n "$(raw "$CONSUMER" "$IDEM_MODEL")" ] \
  && ok "  a correct type WITH a surviving model param still fires (the param outranks the definition)" \
  || bad "  a dispatch carrying a model param was read as already-correct — two live sources for one value"

# --- 13j. MUTANTS: the three wrong fixes, each seeded and asserted RED -------
# Every arm above is PRESENCE-shaped, so a guard that emits nothing fails them. These
# prove the arms discriminate between the RIGHT fix and three plausible wrong ones — each
# of which passes at least one arm above and is caught only by the arm it breaks.
mut_drive() { # mut_drive <script> <json> -> updatedInput
  printf '%s' "$2" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$1" 2>/dev/null \
    | jq -c '.hookSpecificOutput.updatedInput' 2>/dev/null
}
DEFCTL="$WORK/guard-def-control.sh"; cp "$HOOK" "$DEFCTL"
[ "$(mut_drive "$DEFCTL" "$DEFJ" | jq -r '.subagent_type // "<unset>"')" = "defok" ] \
  && ok "MUTANT CONTROL: an unmutated copy still rewrites the type (a mutant's silence is the mutation, not the copy)" \
  || bad "MUTANT CONTROL is dead — a copy of the guard behaves differently from the original, so the kills below are unearned"

# WRONG FIX 1: rewrite the type, keep the name. Passes the type arm; the spawn still goes
# to the teammate runner and the effort is still dropped.
M1="$WORK/guard-keepname.sh"
sed "s@'. + {subagent_type: \$t} | del(.name) | del(.model)'@'. + {subagent_type: \$t} | del(.model)'@" "$HOOK" > "$M1"
if cmp -s "$HOOK" "$M1"; then
  bad "MUTANT keepname matched nothing (cmp -s guard) — the name-deletion arm proves nothing"
else
  if [ "$(mut_drive "$M1" "$DEFJ" | jq -r '.name // "<unset>"')" != "<unset>" ] \
     && [ "$(mut_drive "$M1" "$DEFJ" | jq -r '.subagent_type // "<unset>"')" = "defok" ]; then
    ok "MUTANT keepname: rewriting the type WITHOUT deleting the name leaves the spawn on the teammate runner — the name arm is what catches it, and the type arm cannot"
  else
    bad "MUTANT keepname survived: the name arm is not load-bearing"
  fi
fi

# WRONG FIX 2: delete the name, never rewrite the type. Passes the name arm; the harness
# selects no definition at all, so nothing binds the effort.
M2="$WORK/guard-notype.sh"
sed "s@'. + {subagent_type: \$t} | del(.name) | del(.model)'@'del(.name) | del(.model)'@" "$HOOK" > "$M2"
if cmp -s "$HOOK" "$M2"; then
  bad "MUTANT notype matched nothing (cmp -s guard) — the type-rewrite arm proves nothing"
else
  if [ "$(mut_drive "$M2" "$DEFJ" | jq -r '.subagent_type // "<unset>"')" = "<unset>" ] \
     && [ "$(mut_drive "$M2" "$DEFJ" | jq -r '.name // "<unset>"')" = "<unset>" ]; then
    ok "MUTANT notype: deleting the name WITHOUT rewriting the type selects no definition — the type arm is what catches it, and the name arm cannot"
  else
    bad "MUTANT notype survived: the type arm is not load-bearing"
  fi
fi

# WRONG FIX 3: rewrite whenever the file exists, marker and agreement unread. This is the
# dangerous one: it selects a consumer's hand-written agent AND a drifted render, and it
# passes every arm in 13e.
M3="$WORK/guard-noagree.sh"
sed 's/^if \[ -r "\$DEF_FILE" \] && grep -qF "\$DEF_MARKER" "\$DEF_FILE" 2>\/dev\/null; then$/if [ -r "$DEF_FILE" ]; then/' "$HOOK" > "$M3"
if cmp -s "$HOOK" "$M3"; then
  bad "MUTANT nomarker matched nothing (cmp -s guard) — the marker arm proves nothing"
else
  if [ "$(mut_drive "$M3" "$(mkjson Agent defunmarked)" | jq -r '.subagent_type // "<unset>"')" = "defunmarked" ]; then
    ok "MUTANT nomarker: without the marker test the guard binds a teammate to a file this distribution never rendered — 13g is what catches it"
  else
    bad "MUTANT nomarker survived: the unmarked file stayed unselected without the marker test, so 13g asserts nothing"
  fi
fi

M4="$WORK/guard-nostale.sh"
sed 's/^  if \[ "\$DEF_MODEL" = "\$EXPECT" \] \&\& \[ "\$DEF_EFFORT" = "\$PIN_EFFORT" \]; then$/  if true; then/' "$HOOK" > "$M4"
if cmp -s "$HOOK" "$M4"; then
  bad "MUTANT nostale matched nothing (cmp -s guard) — the staleness arm proves nothing"
else
  if [ "$(mut_drive "$M4" "$(mkjson Agent defstaleeffort)" | jq -r '.subagent_type // "<unset>"')" = "defstaleeffort" ]; then
    ok "MUTANT nostale: without the agreement test a DRIFTED render is selected and the teammate runs at a level nothing declared — 13f is what catches it"
  else
    bad "MUTANT nostale survived: the stale definition stayed unselected without the agreement test, so 13f asserts nothing"
  fi
fi

# The ledger must never be able to block a spawn.
rm -rf "$CONSUMER/_bmad-output"
OUT_RO="$(setmodel "$CONSUMER" "$(mkjson Agent remediator sonnet)")"
[ "$OUT_RO" = "opus" ] \
  && ok "binding still works with the state dir absent (bookkeeping never blocks a dispatch)" \
  || bad "with no state dir the guard injected '$OUT_RO', expected opus — the ledger write is not fail-open"
mkdir -p "$CONSUMER/_bmad-output"

echo
if [ "$fails" -eq 0 ]; then echo "dispatch-model-guard: PASS"; exit 0; fi
echo "dispatch-model-guard: $fails assertion(s) FAILED" >&2
exit 1
