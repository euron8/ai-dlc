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
