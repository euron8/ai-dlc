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

# The prompt the guard hands back, for the prompt-integrity assertions.
newprompt() { raw "$1" "$2" | jq -r '.hookSpecificOutput.updatedInput.prompt // ""' 2>/dev/null; }

# THE GUARD AMENDS PARAMETERS AND NEVER THE PROMPT, and these two arms are what holds it
# there. The Agent tool has no effort parameter and prompt text is read back by nothing --
# `validate-spawn-ledger.sh` resolves a teammate's actual level from that teammate's own
# transcript -- so a sentence appended here reaches no mechanism while making every dispatch
# with a configured effort a correcting dispatch. The two arms are keyed on DIFFERENT
# observables on purpose: one on byte identity, one on the text a directive would produce.
# A single grammar scoring its own subject as a non-instance is how an absence scan reports
# a floor of unknown depth.
#
# expect_prompt_verbatim <root> <json> <label>
# Only meaningful on a dispatch that EMITS -- a silent one hands back no prompt at all, so
# the emission is ASSERTED here rather than assumed, and an arm pointed at a silent dispatch
# reports that it cannot see its subject instead of passing over an empty string.
expect_prompt_verbatim() {
  local out got want
  out="$(raw "$1" "$2")"
  if [ -z "$out" ]; then
    bad "$3 -> the guard emitted NOTHING, so no returned prompt exists to compare — this arm needs a correcting dispatch and is asserting nothing here"
    return
  fi
  got="$(printf '%s' "$out" | jq -r '.hookSpecificOutput.updatedInput.prompt // "<unset>"' 2>/dev/null)"
  want="$(printf '%s' "$2" | jq -r '.tool_input.prompt // "<unset>"')"
  [ "$got" = "$want" ] \
    && ok "$3 -> the outgoing prompt is byte-identical to the one dispatched" \
    || bad "$3 -> the guard REWROTE the prompt. sent: '$want' / returned: '$got'"
}
# expect_no_effort_prose <root> <json> <label>
# Keyed on the OBSERVABLE a re-added directive produces -- any sentence naming a level of
# the configured vocabulary -- rather than on one spelling, so a reworded line is caught too.
expect_no_effort_prose() {
  local got; got="$(newprompt "$1" "$2" | grep -oiE '(reasoning )?effort[^.]{0,40}(low|medium|high|xhigh|max)' | head -1)"
  [ -z "$got" ] \
    && ok "$3 -> the outgoing prompt states no effort level" \
    || bad "$3 -> the outgoing prompt states an effort ('$got') — the guard has no effort channel and must not put one in the prompt"
}
expect_model_kept() { # expect_model_kept <root> <json> <label>
  # The guard emitted (for another trigger) but did NOT rewrite `model`. Distinguishes
  # "left the model alone" from "emitted nothing" on a dispatch that emits for a reason
  # other than the model.
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
# THE TRIGGER SET IS TWO, NOT THREE, AND THESE ARMS ARE WHERE THAT IS OBSERVABLE. A
# configured effort is not a trigger: the only channel that reaches a teammate's effort is
# the rendered definition, which `NEEDS_TYPE` already selects. So a dispatch whose model is
# already right and whose role has NO rendered definition needs nothing and must emit
# NOTHING — it keeps whatever approval posture it would otherwise have. Every role in this
# block pins an effort and has no definition, so each of these used to emit purely to append
# a prompt sentence, and each is now silent.
expect_untouched "$CONSUMER" "$(mkjson Agent gate-adjudicator opus)" \
  "gate-adjudicator requested opus against an opus config"
expect_untouched "$CONSUMER" "$(mkjson Agent analyst sonnet)" \
  "analyst requested sonnet against a sonnet config"

# --- 5. a request CARRYING the key matches ----------------------------------
# The key is `opus`; a full model string containing it is the same model -> untouched.
# The tolerance is bounded by the DECLARED key, not by a hardcoded tier table.
expect_untouched "$CONSUMER" "$(mkjson Agent gate-adjudicator 'claude-opus-5[1m]')" \
  "full model string carrying the configured key (key compare, not a tier guess)"

# --- 6. unpinned role -> UNTOUCHED (fail-open: tea/sm/ux/cis declare nothing)-
# `tea` configures an effort and NO model, and has no rendered definition. With effort gone
# as a trigger there is nothing left for the guard to do on either shape, so both are total
# no-ops rather than emissions that bind no model.
expect_untouched "$CONSUMER" "$(mkjson Agent tea)" \
  "tea configures an effort but no model — nothing to correct"
expect_untouched "$CONSUMER" "$(mkjson Agent tea opus)" \
  "tea with an explicit model: the guard has no configured value to correct it to"

# --- 6b. a party persona WITH a model -> BOUND like any role -------------------
# A persona's model is optional. `sm` sets one (the shipped template's shape), so the guard
# binds it exactly as it binds `dev`: absent param set, wrong tier corrected, right tier left
# alone. One property apart from the tea cells above -- the presence of the model key.
expect_set "$CONSUMER" "$(mkjson Agent sm)" sonnet \
  "sm (a party persona that SETS a model), no model param"
expect_set "$CONSUMER" "$(mkjson Agent sm opus)" sonnet \
  "sm requested opus against its sonnet config → corrected (a /bmad-party-mode spawn is bound like any role)"
expect_untouched "$CONSUMER" "$(mkjson Agent sm sonnet)" \
  "sm requested sonnet against its sonnet config"

# --- 7. model key not defined in aiDlcModels -> NO MODEL BOUND (fail-open) ---
# architect's entry names `ghostkey`, which aiDlcModels does not define, so nothing resolves
# to bind. Its effort is valid and still cannot be delivered by this guard: architect has no
# rendered definition, so the level reaches the teammate through no channel at all and the
# guard stays silent rather than emitting prose about it.
expect_untouched "$CONSUMER" "$(mkjson Agent architect)" \
  "role whose configured model key is absent from aiDlcModels — nothing bound, nothing emitted"
expect_untouched "$CONSUMER" "$(mkjson Agent architect sonnet)" \
  "and an explicitly wrong model is NOT corrected against an unresolvable key"

# --- 8. the Ollama prose line is not a pin; the `- Model:` key binds ---------
expect_untouched "$CONSUMER" "$(mkjson Agent dev sonnet)" \
  "dev configured sonnet: a sonnet request is left alone"
expect_set "$CONSUMER" "$(mkjson Agent dev opus)" sonnet \
  "dev.md opus request is corrected to the pinned sonnet (prose /model line is not the pin)"

# --- 8b. dev-escalated: model escalation is a ROLE, and its pin is bound ------
expect_untouched "$CONSUMER" "$(mkjson Agent dev-escalated opus)" \
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

# --- 13b. THE PROMPT IS NOT A CHANNEL: the guard amends PARAMETERS ONLY -------
# The Agent tool has no `effort` parameter, and a sentence in the prompt is read back by
# nothing — `validate-spawn-ledger.sh` resolves a teammate's level from that teammate's own
# transcript, never from what was said to it. So the guard hands the prompt back UNCHANGED on
# every path, and a configured effort is delivered by the rendered definition or not at all.
#
# BOTH ARMS RUN ON A DISPATCH THAT EMITS, or they are reading an empty string. Two are driven:
# a model correction (no definition involved) and a definition-bound rewrite (whose role pins
# an effort and whose definition supplies it), because those are the two emitting paths and a
# reinstated append could sit on either one.
EFFJ_MODEL="$(mkjson Agent remediator sonnet)"
EFFJ_DEF="$(mkjson Agent defok sonnet)"
expect_prompt_verbatim "$CONSUMER" "$EFFJ_MODEL" \
  "model-correcting dispatch (remediator pins effort high)"
expect_prompt_verbatim "$CONSUMER" "$EFFJ_DEF" \
  "definition-bound dispatch (defok pins effort high and its definition binds it)"
expect_no_effort_prose "$CONSUMER" "$EFFJ_MODEL" \
  "model-correcting dispatch"
expect_no_effort_prose "$CONSUMER" "$EFFJ_DEF" \
  "definition-bound dispatch"

# A role with an effort and NO model — the party-persona shape. Nothing about it is
# correctable, so the whole dispatch is a no-op rather than an emission carrying prose.
expect_untouched "$CONSUMER" "$(mkjson Agent tea)" \
  "tea has an effort and no model, and no definition — nothing to bind"

# A role configured with an INVALID effort level. Its model still resolves and is still
# corrected, and the unrecognised level reaches the outgoing call through nothing.
expect_set "$CONSUMER" "$(mkjson Agent badeffort opus)" sonnet \
  "a role with an invalid effort level still has its model corrected"
expect_no_effort_prose "$CONSUMER" "$(mkjson Agent badeffort opus)" \
  "a role configured with an invalid effort level"

# --- 13c. IDEMPOTENCE: a well-formed dispatch keeps its approval posture -----
# The guard emits `allow` to carry `updatedInput`. If it emitted on every dispatch it would
# change the approval posture of calls it has nothing to correct. With effort no longer a
# trigger, a dispatch whose model is already right and whose role has no rendered definition
# is such a call — and its prompt is irrelevant to that verdict, which is what the pair below
# asserts: the SAME dispatch is silent with and without an effort sentence in its prompt.
IDEM="$(jq -nc --arg p "contract is .claude/team-roles/gate-adjudicator.md" \
  '{tool_name:"Agent",tool_input:{model:"opus",prompt:$p,name:"t"}}')"
expect_untouched "$CONSUMER" "$IDEM" \
  "a dispatch already carrying the configured model"

# THE LEGACY PROMPT, one property apart. A consumer dispatching from a cached prompt still
# carries the sentence the guard used to append. It is not a trigger, not a dedupe key and not
# something the guard strips — the verdict must be identical to the arm above, or prompt text
# is still steering a decision somewhere.
IDEM_LEGACY="$(jq -nc --arg p "contract is .claude/team-roles/gate-adjudicator.md

Your configured reasoning effort for this role is high. Operate at that level." \
  '{tool_name:"Agent",tool_input:{model:"opus",prompt:$p,name:"t"}}')"
expect_untouched "$CONSUMER" "$IDEM_LEGACY" \
  "the same dispatch whose prompt still carries the sentence the guard used to append"

# A prompt naming a DIFFERENT level is the same non-event. Under the old dedupe this input
# was the one that forced an emission; nothing reads it now.
IDEM_WRONGLEVEL="$(jq -nc --arg p "contract is .claude/team-roles/gate-adjudicator.md

Your configured reasoning effort for this role is medium. Operate at that level." \
  '{tool_name:"Agent",tool_input:{model:"opus",prompt:$p,name:"t"}}')"
expect_untouched "$CONSUMER" "$IDEM_WRONGLEVEL" \
  "the same dispatch whose prompt names a level the config does not"

# --- 13c-MUT. EVERY ARM ABOVE IS AN ABSENCE, SO SEED THE RE-ADDITION ----------
# `expect_untouched`, `expect_prompt_verbatim` and `expect_no_effort_prose` all pass against a
# guard that does nothing, and deleting six assertions for a channel removes coverage unless
# something can still fail. The two mutants below reinstate the removed behaviour at the two
# LOCATIONS it could return to — the trigger set, and the emit path's input rewrite — and each
# is scored on an OBSERVABLE of the dispatch, never on the spelling of any sentence.
#
# The guard sources no siblings, so a lone copy is a faithful subject; the control states that
# rather than assuming it, and it asserts a POSITIVE outcome beside the silence so a copy that
# died at startup cannot score as a clean run.
MCTL="$WORK/guard-control.sh"; cp "$HOOK" "$MCTL"
mctl_idem="$(printf '%s' "$IDEM" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$MCTL" 2>/dev/null)"
mctl_corr="$(printf '%s' "$EFFJ_MODEL" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$MCTL" 2>/dev/null \
             | jq -r '.hookSpecificOutput.updatedInput.model // "<unset>"' 2>/dev/null)"
if [ -z "$mctl_idem" ] && [ "$mctl_corr" = "opus" ]; then
  ok "MUTANT CONTROL: an unmutated copy is silent on the idempotent dispatch AND still binds opus on the correcting one — it ran, and the kills below are against the mutation"
else
  bad "MUTANT CONTROL is dead — copy emitted '${mctl_idem:-<nothing>}' on the idempotent dispatch and bound '$mctl_corr' on the correcting one; a copy that behaves differently from the original makes every kill below unearned"
fi

# MUTANT A — EFFORT IS A TRIGGER AGAIN. The fast-exit is what makes a configured effort stop
# deciding whether the guard speaks, so widening it back is the mutation the section-4 and
# section-6 arms exist to catch. Scored on EMISSION: a dispatch those arms require to be
# silent starts producing a decision, which is the approval-posture change itself.
#
# AWK, NOT SED. The replacement text carries `||`, and an `&` or a `\|` in a BSD sed
# replacement is not the literal the author typed — measured here, the sed form died with
# `bad flag in substitute command` and the copy came out unmutated, which `cmp -s` correctly
# refused. awk compares the whole line and prints a literal, so neither side is a pattern.
MTRIG="$WORK/guard-effort-trigger.sh"
MTRIG_ANCHOR='[ "$NEEDS_MODEL" = true ] || [ "$NEEDS_TYPE" = true ] || exit 0'
mtrig_n="$(grep -cxF "$MTRIG_ANCHOR" "$HOOK")" || mtrig_n=0
[ "$mtrig_n" -eq 1 ] \
  && ok "MUTANT effort-trigger anchor is UNIQUE in the guard (1 line) — the mutation below edits the trigger set and nothing else" \
  || bad "MUTANT effort-trigger anchor matched $mtrig_n lines, expected exactly 1 — a mutation on a non-unique anchor moves cells it did not intend"
awk '
  $0 == "[ \"$NEEDS_MODEL\" = true ] || [ \"$NEEDS_TYPE\" = true ] || exit 0" {
    print "[ \"$NEEDS_MODEL\" = true ] || [ \"$NEEDS_TYPE\" = true ] || [ -n \"$PIN_EFFORT\" ] || exit 0"
    next
  }
  { print }
' "$HOOK" > "$MTRIG"
if cmp -s "$HOOK" "$MTRIG"; then
  bad "MUTANT effort-trigger DID NOT APPLY — the awk matched nothing, so the trigger-set arms prove nothing"
elif ! bash -n "$MTRIG" 2>/dev/null; then
  bad "MUTANT effort-trigger DID NOT APPLY as valid shell — a mutant that cannot parse is silent for a reason that is not the mutation"
else
  mtrig_out="$(printf '%s' "$(mkjson Agent gate-adjudicator opus)" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$MTRIG" 2>/dev/null)"
  [ -n "$mtrig_out" ] \
    && ok "MUTANT effort-trigger: with a configured effort back in the trigger set, a dispatch the guard has nothing to correct starts emitting — sections 4/6 are what catch it" \
    || bad "MUTANT effort-trigger survived: the already-correct dispatch stayed silent with effort restored as a trigger, so the untouched arms assert nothing about the trigger set"
fi

# MUTANT B — THE PROMPT IS REWRITTEN AGAIN, on the one emitting path that is definitionally
# about effort. Anchored INSIDE the definition-bound jq so it cannot be confused with the
# model path, and it appends to `.prompt` rather than replacing it, which is the closest
# reinstatement of what was removed. Scored on TWO observables, because 13b reads the property
# through two grammars and a mutant that only one can see leaves the other unproven.
MAPP="$WORK/guard-prompt-append.sh"
sed "s@'. + {subagent_type: \$t} | del(.name) | del(.model)'@'. + {subagent_type: \$t} | del(.name) | del(.model) | .prompt = (.prompt + \"\\\\n\\\\nYour configured reasoning effort for this role is high. Operate at that level.\")'@" \
  "$HOOK" > "$MAPP"
if cmp -s "$HOOK" "$MAPP"; then
  bad "MUTANT prompt-append matched nothing (cmp -s guard) — the prompt-integrity arms prove nothing"
else
  mapp_prompt="$(printf '%s' "$EFFJ_DEF" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$MAPP" 2>/dev/null \
                 | jq -r '.hookSpecificOutput.updatedInput.prompt // "<unset>"' 2>/dev/null)"
  mapp_sent="$(printf '%s' "$EFFJ_DEF" | jq -r '.tool_input.prompt')"
  [ "$mapp_prompt" != "$mapp_sent" ] \
    && ok "MUTANT prompt-append: the returned prompt stops being byte-identical to the dispatched one — expect_prompt_verbatim is what catches it" \
    || bad "MUTANT prompt-append survived the verbatim arm: the prompt came back identical with an append reinstated, so that arm cannot fire"
  [ -n "$(printf '%s' "$mapp_prompt" | grep -oiE '(reasoning )?effort[^.]{0,40}(low|medium|high|xhigh|max)' | head -1)" ] \
    && ok "  and the effort-prose grammar sees it too — the second reading of the same property is live, not a restatement of the first" \
    || bad "  the effort-prose grammar scored its own subject as a non-instance: a reinstated directive was invisible to it, so its zero is a floor of unknown depth"
fi

# --- 13c-MUT2. PERSONA MUTANT: the old reading as code -- personas are never bound -----
# Scored in BOTH directions: the with-model persona (sm) must stop being corrected, AND the
# model-less persona (tea) must stay untouched under the mutant, so the kill is about the
# persona special case and not a guard that stopped binding everything.
MP="$WORK/guard-skippersona.sh"
sed 's/^EXPECT="\$(pin_key "\$SETTINGS" "\$ROLE")"$/&; case "$ROLE" in cis|sm|tea|ux) EXPECT="" ;; esac/' "$HOOK" > "$MP"
if cmp -s "$HOOK" "$MP"; then
  bad "MUTANT skippersona matched nothing (cmp -s guard) — section 6b proves nothing"
elif ! bash -n "$MP" 2>/dev/null; then
  bad "MUTANT skippersona DID NOT APPLY as valid shell"
else
  mp_sm="$(printf '%s' "$(mkjson Agent sm opus)" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$MP" 2>/dev/null | jq -r '.hookSpecificOutput.updatedInput.model // "<unset>"' 2>/dev/null)"
  mp_tea="$(printf '%s' "$(mkjson Agent tea)" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$MP" 2>/dev/null)"
  mp_dev="$(printf '%s' "$(mkjson Agent dev opus)" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$MP" 2>/dev/null | jq -r '.hookSpecificOutput.updatedInput.model // "<unset>"' 2>/dev/null)"
  if [ "$mp_sm" != "sonnet" ] && [ -z "$mp_tea" ] && [ "$mp_dev" = "sonnet" ]; then
    ok "MUTANT skippersona killed: a guard that never binds a persona leaves sm's opus request uncorrected (section 6b catches it), while tea stays untouched and dev is still corrected — the kill is about the persona special case"
  else
    bad "MUTANT skippersona: sm='$mp_sm' (want not sonnet), tea='${mp_tea:-<nothing>}' (want nothing), dev='$mp_dev' (want sonnet)"
  fi
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
#
# THIS IS THE NO-DEFINITION WORLD. `remediator` has no rendered `.claude/agents/` file in
# the seed, so neither carrier delivers the Rule 19(b) line and false stays the right
# record. A subagent_type-only dispatch whose role HAS a bound definition is a different
# world with a different answer; the CONTRACT CARRIER block below owns it.
rm -f "$LEDGER"
J="$(jq -nc '{tool_name:"Agent",tool_input:{name:"t-1",model:"sonnet",subagent_type:"remediator",prompt:"Do the work."}}')"
[ "$(setmodel "$CONSUMER" "$J")" = "opus" ] \
  && ok "subagent_type-only dispatch is bound (was a silent no-op before v0.158.0)" \
  || bad "subagent_type-only dispatch injected '$(setmodel "$CONSUMER" "$J")', expected opus"
raw "$CONSUMER" "$J" >/dev/null
[ "$(lfield .role_contract_cited)" = "false" ] && [ "$(lfield .contract_via)" = "null" ] \
  && ok "  and records role_contract_cited=false, contract_via=null — with no definition the Rule 19(b) omission stays visible" \
  || bad "  role_contract_cited='$(lfield .role_contract_cited)' contract_via='$(lfield .contract_via)', expected false/null"

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

# --- CONTRACT CARRIER: role_contract_cited and contract_via ------------------------
# The Rule 19(b) line reaches a teammate by one of two carriers: the dispatch PROMPT naming
# `team-roles/<role>.md`, or the BODY of the `.claude/agents/<role>.md` definition the dispatch
# selects, which is the subagent system prompt. The row records which in `contract_via`, and
# `role_contract_cited` is true when either delivered it. A record of delivery-as-selected at
# PreToolUse, never of the read.
#
# THE WORLDS, each keyed to one property:
#   a  defok, subagent_type only, no prompt citation      -> true/definition
#   b  defok, prompt cites the role AND definition bound  -> true/prompt   (prompt wins)
#   c  defnoline, bound, body carries neither line         -> false/null
#   d  defwrongrole, bound, body carries defok line 1 + 2  -> false/null
#   e  remediator, no definition at all                    -> false/null
#   f  defok, a two-document input the emit cannot amend  -> see its own comment
# c and d are MARKED and AGREE with settings, so the guard binds them exactly as it binds
# defok; only the body differs, which is the property under test. The definition_bound
# controls below say so in this run, or a false there would be a false for the wrong reason.
#
# EVERY DRIVE SEEDS AN EPOCH ROW FIRST, and it is not the subject. A one-row ledger makes the
# subject its own epoch and `tail -1` then reads whatever row exists; here the subject must be
# row 2 and must carry its own role, or the cell reports the row it did read. The epoch row is
# prompt-cited (true/prompt), so a subject that wrote nothing cannot pass a false/null arm on it.
EPOCHJ="$(mkjson Agent gate-adjudicator opus)"
# ccell <guard> <json> <subject-role> -> "cited/via" of the subject row, or a diagnostic.
ccell() {
  local n
  rm -f "$LEDGER"
  printf '%s' "$EPOCHJ" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$1" >/dev/null 2>&1
  printf '%s' "$2" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$1" >/dev/null 2>&1
  n="$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')"
  [ "$n" = 2 ] || { printf 'ROWS=%s' "${n:-0}"; return; }
  tail -1 "$LEDGER" | jq -r --arg r "$3" \
    'if .role == $r then "\(.role_contract_cited | tostring)/\(.contract_via | tostring)" else "WRONGROW:\(.role)" end' 2>/dev/null
}
CW_A="$(jq -nc '{tool_name:"Agent",tool_input:{name:"t-a",subagent_type:"defok",prompt:"Do the work."}}')"
CW_B="$(mkjson Agent defok)"
CW_C="$(jq -nc '{tool_name:"Agent",tool_input:{name:"t-c",subagent_type:"defnoline",prompt:"Do the work."}}')"
CW_D="$(jq -nc '{tool_name:"Agent",tool_input:{name:"t-d",subagent_type:"defwrongrole",prompt:"Do the work."}}')"
CW_E="$(jq -nc '{tool_name:"Agent",tool_input:{name:"t-e",subagent_type:"remediator",prompt:"Do the work."}}')"
# cvec <guard> -> the a..e cell vector, one string, for the mutant battery.
cvec() {
  printf 'a=%s b=%s c=%s d=%s e=%s' \
    "$(ccell "$1" "$CW_A" defok)" "$(ccell "$1" "$CW_B" defok)" \
    "$(ccell "$1" "$CW_C" defnoline)" "$(ccell "$1" "$CW_D" defwrongrole)" \
    "$(ccell "$1" "$CW_E" remediator)"
}

# CONTROLS: c and d are bound (so the body is what decides), e is not.
for _cw in "a:$CW_A" "c:$CW_C" "d:$CW_D"; do
  rm -f "$LEDGER"; raw "$CONSUMER" "${_cw#*:}" >/dev/null
  [ "$(lfield .definition_bound)" = "true" ] \
    && ok "CONTROL world ${_cw%%:*}: the definition is BOUND, so the contract cell below is decided by the body" \
    || bad "CONTROL world ${_cw%%:*}: definition_bound='$(lfield .definition_bound)', expected true — the world is not the one its arm claims"
done
rm -f "$LEDGER"; raw "$CONSUMER" "$CW_E" >/dev/null
[ "$(lfield .definition_bound)" = "false" ] \
  && ok "CONTROL world e: remediator has no definition (definition_bound=false)" \
  || bad "CONTROL world e: definition_bound='$(lfield .definition_bound)', expected false"

TIP_A="$(ccell "$HOOK" "$CW_A" defok)"
[ "$TIP_A" = "true/definition" ] \
  && ok "(a) definition-bound, subagent_type-only, no prompt citation -> cited=true contract_via=definition" \
  || bad "(a) recorded '$TIP_A', expected 'true/definition' — the selected definition body carries the role line and the row says it was not delivered"
TIP_B="$(ccell "$HOOK" "$CW_B" defok)"
[ "$TIP_B" = "true/prompt" ] \
  && ok "(b) prompt citation with a definition ALSO bound -> contract_via=prompt (the prompt wins)" \
  || bad "(b) recorded '$TIP_B', expected 'true/prompt'"
TIP_C="$(ccell "$HOOK" "$CW_C" defnoline)"
[ "$TIP_C" = "false/null" ] \
  && ok "(c) marked, agreeing definition whose body lacks the line -> false/null (the frontmatter is not the carrier)" \
  || bad "(c) recorded '$TIP_C', expected 'false/null' — a bound definition was credited without its body being read"
TIP_D="$(ccell "$HOOK" "$CW_D" defwrongrole)"
[ "$TIP_D" = "false/null" ] \
  && ok "(d) role R definition carrying role S line 1 and the shared line 2 -> false/null (the match is role-specific)" \
  || bad "(d) recorded '$TIP_D', expected 'false/null' — another role's contract line was credited to this role"
TIP_E="$(ccell "$HOOK" "$CW_E" remediator)"
[ "$TIP_E" = "false/null" ] \
  && ok "(e) no definition file, no prompt citation -> false/null" \
  || bad "(e) recorded '$TIP_E', expected 'false/null'"

# (f) THE INPUT THE EMIT CANNOT AMEND. Two JSON documents on stdin: every read takes the first,
# so the role resolves and the definition binds, but the final decision build receives two
# values and fails, and the guard FAILS OPEN — it emits nothing and the rewrite that selects
# the definition never reaches the harness. The ledger row is written BEFORE the emit, from
# the selection, so it records true/definition anyway. THIS ARM RECORDS THAT BEHAVIOUR, it
# does not endorse it: contract_via is delivery-as-SELECTED at PreToolUse, and here the
# selection was not delivered. Asserted so a change to it is seen, in either direction.
CW_F="$(printf '%s {"x":1}' "$CW_A")"
rm -f "$LEDGER"
F_OUT="$(printf '%s' "$CW_F" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$HOOK" 2>/dev/null)"
[ -z "$F_OUT" ] \
  && ok "(f) CONTROL: the two-document input takes the fail-open path (no decision emitted)" \
  || bad "(f) CONTROL: the guard emitted on the two-document input, so this world is not the fail-open path: '$F_OUT'"
TIP_F="$(ccell "$HOOK" "$CW_F" defok)"
[ "$TIP_F" = "true/definition" ] \
  && ok "(f) fail-open emit: the row still records true/definition — a record of the selection, not of a rewrite that reached the harness" \
  || bad "(f) fail-open emit recorded '$TIP_F', expected 'true/definition' (the recorded behaviour changed; decide whether that is intended)"

# --- CONTRACT CARRIER MUTANTS -------------------------------------------------
# Each mutant is a COPY of the whole hooks directory, because the guard sources
# ai-dlc-context-provenance.sh as a sibling on its emit path. Each is guarded by `cmp -s`
# and a parse check, and each is scored on the EXACT a..e vector, so a mutant that moves a
# cell it does not own is visible rather than scored as a kill.
#
# OVERLAP, STATED: mutant (i) necessarily moves BOTH c and d, because both are bound
# definitions whose body lacks this role line 1 and (i) never reads the body. c OWNS that
# case; d is proven load-bearing by (ii), which moves d alone. Mutant (iii) also moves world
# f, which is not in the scored vector: f records behaviour and owns no mutant.
HOOKS_SRC="$(dirname "$HOOK")"
mk_hooks_copy() { # mk_hooks_copy <tag> -> path of the guard inside a fresh copy of the hooks dir
  local d; d="$(mktemp -d "$WORK/hooks-$1.XXXXXX")" || return 1
  cp -R "$HOOKS_SRC/." "$d/" || return 1
  printf '%s/%s' "$d" "$(basename "$HOOK")"
}
CC_WANT="a=true/definition b=true/prompt c=false/null d=false/null e=false/null"

CC_CTL="$(mk_hooks_copy control)"
if [ -z "$CC_CTL" ] || [ ! -r "$(dirname "$CC_CTL")/ai-dlc-context-provenance.sh" ]; then
  bad "CARRIER MUTANT CONTROL: the hooks copy is missing the guard or its provenance sibling — every verdict below would be about a copy that cannot run"
else
  CC_CTL_VEC="$(cvec "$CC_CTL")"
  [ "$CC_CTL_VEC" = "$CC_WANT" ] \
    && ok "CARRIER MUTANT CONTROL: an unmutated hooks copy records a=true/definition (positive) and the full expected vector" \
    || bad "CARRIER MUTANT CONTROL is dead: vector '$CC_CTL_VEC', expected '$CC_WANT'"
fi

# cc_mut <tag> <exact-anchor-line> <replacement-line> <expected-vector> <label>
cc_mut() {
  local g n vec
  n="$(grep -cxF -- "$2" "$HOOK")" || n=0
  if [ "$n" != 1 ]; then
    bad "CARRIER MUTANT $1 anchor matched $n lines in the guard, expected exactly 1 — the mutation is lost or ambiguous"
    return
  fi
  g="$(mk_hooks_copy "$1")"
  if [ -z "$g" ]; then bad "CARRIER MUTANT $1: could not build the hooks copy"; return; fi
  A="$2" R="$3" awk '$0 == ENVIRON["A"] { print ENVIRON["R"]; next } { print }' "$HOOK" > "$g"
  if cmp -s "$HOOK" "$g"; then
    bad "CARRIER MUTANT $1 DID NOT APPLY (cmp -s) — its arm proves nothing"; return
  fi
  if ! bash -n "$g" 2>/dev/null; then
    bad "CARRIER MUTANT $1 DID NOT APPLY as valid shell"; return
  fi
  vec="$(cvec "$g")"
  [ "$vec" = "$4" ] \
    && ok "CARRIER MUTANT $1 killed: $5" \
    || bad "CARRIER MUTANT $1: vector '$vec', expected '$4' — $5 is not what the arms see"
}

# (i) the citation is DEFINITION_BOUND, the body is never read.
cc_mut body-ignored \
  '  if [ -n "$_dg_body" ] && grep -qxF -- "$_dg_line" <<<"$_dg_body" 2>/dev/null; then' \
  '  if true; then' \
  "a=true/definition b=true/prompt c=true/definition d=true/definition e=false/null" \
  "citing on definition_bound alone credits the line-less body — arm (c) owns it (d moves too, stated above)"
# (ii) the match keyed on line 2, which every role body carries.
cc_mut line2-key \
  '  _dg_line="$(printf '"'"'Your operating contract is `.claude/team-roles/%s.md`. Read it and follow it as your'"'"' "$ROLE")"' \
  '  _dg_line="FIRST action before any other work."' \
  "a=true/definition b=true/prompt c=false/null d=true/definition e=false/null" \
  "keying on the shared line 2 credits another role line — arm (d) alone catches it"
# (iii) revert to prompt-only: the definition carrier is never consulted.
cc_mut prompt-only \
  'if [ "$ROLE_CONTRACT_CITED" = false ] && [ "$DEFINITION_BOUND" = true ]; then' \
  'if false; then' \
  "a=false/null b=true/prompt c=false/null d=false/null e=false/null" \
  "a prompt-only guard records the definition-bound dispatch as uncited — arm (a) alone catches it"

# --- THE SHARD LINE: AN INVENTED SERIAL EXCEPTION IS RECORDED, NEVER LAUNDERED TO NULL --------
# Rule 28 names four serial exceptions. A `none` naming anything else records
# `invalid-exception` plus the lead text in `shard_raw`, which Check 22 arm S3 FAILS on. Seeded
# from what leads actually wrote: the consumer briefs carried `none (serial-document). Files
# you may edit...` (a valid exception followed by prose) and reasons outside the four.
#
# SIX WORLDS, ONE PROPERTY EACH, every drive behind an epoch row that is not the subject:
#   inv   `none (serial cross-file repair: a, b)`  -> invalid-exception|<that text>
#   ac    `none (authoring-chain)`                  -> none (3)|null
#   sd    `none (serial-document). Files you...`    -> none (4)|null     (trailing prose ignored)
#   dash  `none — serial because`                   -> invalid-exception|<that text>
#   two   an invented line AND a valid line         -> invalid-exception (a repeat cannot launder it)
#   ord   `3/7 x`                                   -> 3/7 x|null        (the awk ran at all)
#   upper `SHARD: none (made up)`                   -> invalid-exception (the KEY is case-folded)
#   wrap  `shard: **none (made up)**`               -> invalid-exception (the VALUE is unwrapped)
#   title `Shard: None (4)`                         -> none (4)          (key AND token folded)
# `ord` is in the scored vector so a mutant whose awk dies reads as every cell moving, never
# as a clean kill of one. The last three are spellings no consumer brief carries today; each
# laundered an invented exception to null before the fold and the unwrap existed.
SHARD_EPOCH="$(mkjson Agent gate-adjudicator opus)"
shard_payload() { # shard_payload <brief lines...> -> a remediator dispatch carrying them
  local p; p="Your operating contract is \`.claude/team-roles/remediator.md\`. Read it first."
  for _l in "$@"; do p="$p"$'\n'"$_l"; done
  jq -nc --arg p "$p"$'\n'"Do the work." '{tool_name:"Agent",tool_input:{name:"rem-shard",prompt:$p}}'
}
SH_INV="$(shard_payload 'shard: none (serial cross-file repair: a, b)')"
SH_AC="$(shard_payload 'shard: none (authoring-chain)')"
SH_SD="$(shard_payload 'shard: none (serial-document). Files you may edit: docs/a.md')"
SH_DASH="$(shard_payload 'shard: none — serial because the files interlock')"
SH_TWO="$(shard_payload 'shard: none (invented reason)' 'shard: none (4)')"
SH_ORD="$(shard_payload 'shard: 3/7 x')"
SH_UPPER="$(shard_payload 'SHARD: none (made up)')"
SH_WRAP="$(shard_payload 'shard: **none (made up)**')"
SH_TITLE="$(shard_payload 'Shard: None (4)')"
# scell <guard> <json> -> "<shard>|<shard_raw>" of the subject row (row 2), or a diagnostic.
scell() {
  local n
  rm -f "$LEDGER"
  printf '%s' "$SHARD_EPOCH" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$1" >/dev/null 2>&1
  printf '%s' "$2" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$1" >/dev/null 2>&1
  n="$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')"
  [ "$n" = 2 ] || { printf 'ROWS=%s' "${n:-0}"; return; }
  tail -1 "$LEDGER" | jq -r 'if .role == "remediator" then "\(.shard | tostring)|\(.shard_raw | tostring)" else "WRONGROW:\(.role)" end' 2>/dev/null
}
svec() {
  printf 'inv=%s;ac=%s;sd=%s;dash=%s;two=%s;ord=%s;upper=%s;wrap=%s;title=%s' \
    "$(scell "$1" "$SH_INV")" "$(scell "$1" "$SH_AC")" "$(scell "$1" "$SH_SD")" \
    "$(scell "$1" "$SH_DASH")" "$(scell "$1" "$SH_TWO")" "$(scell "$1" "$SH_ORD")" \
    "$(scell "$1" "$SH_UPPER")" "$(scell "$1" "$SH_WRAP")" "$(scell "$1" "$SH_TITLE")"
}
SV_INV='inv=invalid-exception|none (serial cross-file repair: a, b)'
SV_AC='ac=none (3)|null'
SV_SD='sd=none (4)|null'
SV_DASH='dash=invalid-exception|none — serial because the files interlock'
SV_TWO='two=invalid-exception|none (invented reason)'
SV_ORD='ord=3/7 x|null'
SV_UPPER='upper=invalid-exception|none (made up)'
SV_WRAP='wrap=invalid-exception|none (made up)'
SV_TITLE='title=none (4)|null'
SV_FOLD="$SV_UPPER;$SV_WRAP;$SV_TITLE"
SV_WANT="$SV_INV;$SV_AC;$SV_SD;$SV_DASH;$SV_TWO;$SV_ORD;$SV_FOLD"
SV_TIP="$(svec "$HOOK")"
for _c in "$SV_INV" "$SV_AC" "$SV_SD" "$SV_DASH" "$SV_TWO" "$SV_ORD" "$SV_UPPER" "$SV_WRAP" "$SV_TITLE"; do
  case ";$SV_TIP;" in
    *";$_c;"*) ok "SHARD ${_c%%=*}: recorded '${_c#*=}' (shard|shard_raw)" ;;
    *) bad "SHARD ${_c%%=*}: expected '${_c#*=}', got vector '$SV_TIP'" ;;
  esac
done

# THE ROW SURVIVES A RAW TEXT CUT INSIDE A MULTIBYTE CHARACTER. `shard_raw` is the first 160
# bytes, and a cut through a UTF-8 sequence must not fail the single jq that writes the WHOLE
# row: losing the row would cost every other field for this one.
_mb=""; for _i in $(seq 1 100); do _mb="${_mb}é"; done
SH_MB="$(shard_payload "shard: none (x${_mb})")"
_mbc="$(scell "$HOOK" "$SH_MB")"
case "$_mbc" in
  invalid-exception\|"none (x"*) ok "SHARD multibyte: a 160-byte cut inside a UTF-8 character still writes the row (invalid-exception, raw kept)" ;;
  *) bad "SHARD multibyte: a raw text cut inside a UTF-8 character recorded '$_mbc' — the row build failed or the value changed" ;;
esac

# MUTANTS on the shard parse, each a copy of the whole hooks dir, exact-line anchored, scored
# on the EXACT nine-cell vector so a mutant that moves a cell it does not own is visible.
SV_CTL_G="$(mk_hooks_copy shard-control)"
if [ -n "$SV_CTL_G" ] && [ "$(svec "$SV_CTL_G")" = "$SV_WANT" ]; then
  ok "SHARD MUTANT CONTROL: an unmutated hooks copy records the full expected nine-cell vector, invalid-exception included (positive)"
else
  bad "SHARD MUTANT CONTROL is dead: an unmutated copy recorded '$(svec "$SV_CTL_G")'"
fi
# sh_mut <tag> <exact-anchor-line> <replacement-line> <expected-vector> <label>
sh_mut() {
  local g n vec
  n="$(grep -cxF -- "$2" "$HOOK")" || n=0
  if [ "$n" != 1 ]; then bad "SHARD MUTANT $1 anchor matched $n lines in the guard, expected exactly 1"; return; fi
  g="$(mk_hooks_copy "$1")"
  if [ -z "$g" ]; then bad "SHARD MUTANT $1: could not build the hooks copy"; return; fi
  A="$2" R="$3" awk '$0 == ENVIRON["A"] { print ENVIRON["R"]; next } { print }' "$HOOK" > "$g"
  if cmp -s "$HOOK" "$g"; then bad "SHARD MUTANT $1 DID NOT APPLY (cmp -s)"; return; fi
  if ! bash -n "$g" 2>/dev/null; then bad "SHARD MUTANT $1 DID NOT APPLY as valid shell"; return; fi
  vec="$(svec "$g")"
  [ "$vec" = "$4" ] && ok "SHARD MUTANT $1 killed: $5" \
    || bad "SHARD MUTANT $1: vector '$vec', expected '$4' — $5 is not what the arms see"
}
# (b) the parse anchored on the WHOLE line, as before this release: trailing prose after a
# valid exception is rejected, so the real consumer `none (serial-document). Files...` line
# records invalid-exception. Arm sd alone catches it.
sh_mut whole-line \
  '      if (match(line, /^none ?\([^)]*\)/)) {' \
  '      if (match(line, /^none ?\([^)]*\)$/)) {' \
  "$SV_INV;$SV_AC;sd=invalid-exception|none (serial-document). Files you may edit: docs/a.md;$SV_DASH;$SV_TWO;$SV_ORD;$SV_FOLD" \
  "a whole-line-anchored parse FAILS a valid exception followed by prose — arm sd alone catches it"
# (d) the repeated-line rule from before this release: more than one key line resets to null,
# so a second, valid line launders an invented one. Arm two alone catches it.
sh_mut repeat-resets \
  '  END { if (bad) { print "invalid-exception"; print raw } else if (keys == 1 && good == 1) print out }' \
  '  END { if (keys == 1 && bad) { print "invalid-exception"; print raw } else if (keys == 1 && good == 1) print out }' \
  "$SV_INV;$SV_AC;$SV_SD;$SV_DASH;two=null|null;$SV_ORD;$SV_FOLD" \
  "a repeated shard line resetting to null launders the invented exception — arm two alone catches it"
# (e) no case-fold: the key and the `none` token match lower case only, so `SHARD:` and
# `Shard: None` are skipped and record null. Arms upper and title alone catch it; wrap is
# lower case and does not move.
sh_mut no-casefold \
  '  function fold(s) { return tolower(s) }' \
  '  function fold(s) { return s }' \
  "$SV_INV;$SV_AC;$SV_SD;$SV_DASH;$SV_TWO;$SV_ORD;upper=null|null;$SV_WRAP;title=null|null" \
  "dropping the case-fold launders an upper-case key to null — arms upper and title alone catch it"
# (f) no unwrap: an emphasised `**none (...)**` value matches no branch and records null. Arm
# wrap alone catches it, so the fold and the unwrap each have a subject the other cannot see.
sh_mut no-unwrap \
  '    v = line; sub(/^[*_`"]+/, "", v); sub(/[*_`"]+$/, "", v)' \
  '    v = line' \
  "$SV_INV;$SV_AC;$SV_SD;$SV_DASH;$SV_TWO;$SV_ORD;$SV_UPPER;wrap=null|null;$SV_TITLE" \
  "dropping the unwrap launders an emphasised invented exception to null — arm wrap alone catches it"

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
# A definition's `effort:` is APPLIED by the harness, and it is the ONLY channel that
# reaches a teammate's effort at all. Three properties, and all three must hold together or
# the dispatch silently loses its effort:
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
# definition, so nothing binds an effort for it: the configured level reaches the teammate
# through no channel at all. A row claiming an effort
# was bound there is the defect — it is what makes an unbound dispatch read as a bound one,
# and it is what this guard recorded before `effort_bound` moved off the config.
NODEF_PIN="$(jq -r '.aiDlcRoles.defnodef.effort // ""' "$CONSUMER/.claude/settings.json")"
[ -n "$NODEF_PIN" ] && [ ! -e "$CONSUMER/.claude/agents/defnodef.md" ] \
  && ok "  CONTROL: defnodef pins effort '$NODEF_PIN' in settings AND has no rendered definition — the two states the arm below separates" \
  || bad "  CONTROL is dead: defnodef pins '$NODEF_PIN' and its definition is $( [ -e "$CONSUMER/.claude/agents/defnodef.md" ] && echo present || echo absent ) — a null here would prove nothing"
rm -f "$LEDGER"; raw "$CONSUMER" "$(mkjson Agent defnodef)" >/dev/null
[ "$(lfield .effort_bound)" = "null" ] \
  && ok "  a dispatch with no definition records effort_bound=null even though its role pins one — no channel carries that level" \
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
IDEMDEF="$(jq -nc --arg p "Your operating contract is \`.claude/team-roles/defok.md\`." \
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

# --- 14. DENY ARM 1: A CAP-REJECTED SPAWN RE-SENT BEFORE ANY AGENT EXITED ---------
# FALSE-POSITIVE SET, measured by driving this guard at each of the 233 same-description lead
# re-sends in the reference consumer's nine cap-rejecting sessions (transcript cut at the re-send's
# record): 3 denied, 3 of them rejected again by the harness, 0 launched. It reached zero through two
# narrowings, each with its own case here: releasing on a non-rejected Agent result (14b; without it
# 48 held, 33 launched) and counting the queue ENQUEUE as an agent exit (14c''; without it 6 held, 3
# launched). Slowest call on the corpus, a 44 MB transcript, 0.34 s.
# The rejection is produced by Claude Code AFTER PreToolUse, so it can only be SEEDED: the real
# record shapes, taken from the reference consumer's lead transcripts, are an assistant
# `tool_use` and a user `tool_result` whose content is the cap text with `is_error: true`. Every
# dispatch below is `dev` with `model: sonnet`, a call the model path leaves UNTOUCHED -- so any
# output at all is this arm's, an allow is the empty string, and a deny is `deny`.
CAPTXT='Concurrent subagent limit reached. You can run 20 subagents at once. Do not retry. If the user wants more concurrent subagents, ask them to increase CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS.'
t_use() { # t_use <id> <tool> <description> [command]
  jq -nc --arg id "$1" --arg n "$2" --arg d "$3" --arg c "${4-}" '{type:"assistant",isSidechain:false,
    message:{role:"assistant",content:[{type:"tool_use",id:$id,name:$n,
      input:({description:$d} + (if $c != "" then {command:$c} else {} end))}]}}'
}
t_res() { # t_res <id> <text> <is_error>
  jq -nc --arg id "$1" --arg t "$2" --argjson e "$3" '{type:"user",isSidechain:false,
    message:{role:"user",content:[{type:"tool_result",tool_use_id:$id,content:$t,is_error:$e}]}}'
}
t_note() { # t_note <summary-kind>   -- a notification as the harness records it: origin.kind on the record
  jq -nc --arg c "$(printf '<task-notification>\n<task-id>a0</task-id>\n<status>completed</status>\n<summary>%s "seat" finished</summary>\n</task-notification>' "$1")" \
    '{type:"user",isSidechain:false,origin:{kind:"task-notification"},message:{role:"user",content:$c}}'
}
CAPDIR="$WORK/cap"; mkdir -p "$CAPDIR"
# The rejected spawn, preceded by an UNRELATED launched one, so the rejection is not the first
# record and a launch BEFORE it must not release it.
{ t_use u0 Agent "Earlier seat"; t_res u0 "Async agent launched successfully." false
  t_use u1 Agent "Party seat 7"; t_res u1 "$CAPTXT" true; } > "$CAPDIR/a.jsonl"
{ cat "$CAPDIR/a.jsonl"; t_use u2 Agent "Party seat 8"; t_res u2 "Async agent launched successfully." false; } > "$CAPDIR/b.jsonl"
{ cat "$CAPDIR/a.jsonl"; t_note Agent; } > "$CAPDIR/c.jsonl"
# c3: the agent's exit recorded ONLY as the harness's queue ENQUEUE, before delivery -- the
# earliest record of an exit, and the one a lead re-send most often races.
{ cat "$CAPDIR/a.jsonl"
  jq -nc --arg c "$(printf '<%s>\n<status>completed</status>\n<summary>Agent "seat" finished</summary>' task-notification)" \
    '{type:"queue-operation",operation:"enqueue",content:$c}'; } > "$CAPDIR/c3.jsonl"
# c2: the near-miss for (c) -- a notification for a BACKGROUND COMMAND, which is no agent exiting.
{ cat "$CAPDIR/a.jsonl"; t_note "Background command"; } > "$CAPDIR/c2.jsonl"
# d: the cap text ONLY in a Bash call's command and that call's error result. The Bash tool_use
# carries a `description` equal to the re-sent one, so an arm that read every tool's results
# would hold it. No Agent call was ever rejected here.
{ t_use b1 Bash "Party seat 7" "grep -c 'Concurrent subagent limit reached' t.jsonl"
  t_res b1 "$CAPTXT" true; } > "$CAPDIR/d.jsonl"

capj() { # capj <transcript> <description> [agent_id]
  mkjson Agent dev sonnet | jq -c --arg t "$1" --arg d "$2" --arg a "${3-}" \
    '.transcript_path = $t | .tool_input.description = $d | if $a != "" then .agent_id = $a else . end'
}
capout() { raw "${3:-$CONSUMER}" "$(capj "$1" "$2" "${4-}")"; }
expect_deny() { # expect_deny <out> <label>
  if [ "$(printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)" = deny ] \
     && printf '%s' "$1" | jq -e '.hookSpecificOutput | has("updatedInput") | not' >/dev/null 2>&1; then
    ok "$2 -> DENIED, with no updatedInput"
  else bad "$2 -> expected a deny with no updatedInput, got '$(printf '%s' "$1" | cut -c1-200)'"; fi
}
expect_quiet() { # expect_quiet <out> <label>
  [ -z "$1" ] && ok "$2 -> allowed (no decision)" || bad "$2 -> expected NO decision, got '$(printf '%s' "$1" | cut -c1-200)'"
}
CAP_A="$(capout "$CAPDIR/a.jsonl" "Party seat 7")"
expect_deny "$CAP_A" "14a a re-send of a cap-rejected description with nothing released since"
grep -qF 'an agent of this session has exited since the rejection' <<<"$CAP_A" \
  && ok "  and the remedy quotes Rule 28's held-set paragraph" \
  || bad "  the deny does not quote Rule 28's held-set release condition"
expect_quiet "$(capout "$CAPDIR/b.jsonl" "Party seat 7")" "14b the same, after a non-rejected Agent result (the cap admitted a spawn)"
expect_quiet "$(capout "$CAPDIR/c.jsonl" "Party seat 7")" "14c the same, after an agent task-notification (an agent exited)"
expect_quiet "$(capout "$CAPDIR/c3.jsonl" "Party seat 7")" "14c'' the same, after an agent exit recorded only as the queue enqueue"
expect_deny "$(capout "$CAPDIR/c2.jsonl" "Party seat 7")" "14c' the same, after only a BACKGROUND-COMMAND notification"
expect_quiet "$(capout "$CAPDIR/d.jsonl" "Party seat 7")" "14d the cap text only inside a Bash command and its result"
expect_quiet "$(capout "$CAPDIR/a.jsonl" "Party seat 9")" "14e a different description"
expect_quiet "$(capout "$CAPDIR/a.jsonl" "Party seat 7" "" a1234567890abcdef)" "14f a subagent's call (agent_id set)"
expect_quiet "$(capout "$CAPDIR/a.jsonl" "Party seat 7" "$NOSTAMP")" "14g a non-layered tree"

# MUTANTS. Each is a copy of the guard, guarded by `cmp -s`, and must fail ONLY its own case.
CAPCTL="$WORK/guard-cap-control.sh"; cp "$HOOK" "$CAPCTL"
cap_mut() { # cap_mut <script> <transcript> <description> [agent_id] -> decision or empty
  printf '%s' "$(capj "$2" "$3" "${4-}")" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$1" 2>/dev/null \
    | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null
}
[ "$(cap_mut "$CAPCTL" "$CAPDIR/a.jsonl" "Party seat 7")" = deny ] \
  && ok "CAP MUTANT CONTROL: an unmutated copy denies 14a" \
  || bad "CAP MUTANT CONTROL is dead -- the kills below are unearned"
cap_kill() { # cap_kill <name> <sed-expr> <transcript> <description> <agent_id> <label>
  local m="$WORK/guard-cap-$1.sh"
  sed "$2" "$HOOK" > "$m" || { bad "CAP MUTANT $1: sed DID NOT APPLY"; return; }
  if cmp -s "$HOOK" "$m"; then bad "CAP MUTANT $1 matched nothing (cmp -s guard)"; return; fi
  [ "$(cap_mut "$m" "$3" "$4" "$5")" = deny ] \
    && ok "CAP MUTANT $1 killed: $6" || bad "CAP MUTANT $1 SURVIVED: $6"
}
cap_kill anytool 's/and (.name == "Agent" or .name == "Task")))/))/' \
  "$CAPDIR/d.jsonl" "Party seat 7" "" "reading every tool's results holds a Bash call's quoted text (14d)"
cap_kill nodesc 's/(if .ids\[\$t.tool_use_id\] == \$d then .held = true | .hmid = .mid\[\$t.tool_use_id\] else . end)/(.held = true | .hmid = .mid[$t.tool_use_id])/' \
  "$CAPDIR/a.jsonl" "Party seat 9" "" "dropping the description match holds every description (14e)"
cap_kill nolead 's/^if \[ -z "\$DG_AGENT_ID" \] && \[ -n "\$DG_DESC" \]/if [ -n "$DG_DESC" ]/' \
  "$CAPDIR/a.jsonl" "Party seat 7" a1234567890abcdef "dropping the lead-only scope denies a subagent (14f)"
cap_kill nolaunch 's/                   else .held = false end$/                   else . end/' \
  "$CAPDIR/b.jsonl" "Party seat 7" "" "dropping the launch release holds past an admitted spawn (14b)"
cap_kill nonote 's/| if (\$r | agentnote) then .held = false else . end)/| if ($r | agentnote) then . else . end)/' \
  "$CAPDIR/c.jsonl" "Party seat 7" "" "dropping the notification release holds past an agent exit (14c)"
cap_kill noenqueue 's/        def agentnote: ((.type == "queue-operation" and .operation? == "enqueue")$/        def agentnote: (false/' \
  "$CAPDIR/c3.jsonl" "Party seat 7" "" "dropping the enqueue carrier holds past an exit not yet delivered (14c'')"

# --- 15. DENY ARM 2: A GATE-ADJUDICATOR DISPATCHED OVER A WAIVER CHECK 22 WILL REJECT ---------
# FALSE-POSITIVE SET, measured by driving this guard over the reference consumer's live pending.md
# and pending-archive.md (each alone and concatenated) with its real ledger, probe rows and
# team-roles, sprints 298-318, under an implementation nonce. Clause 1 (names no spawn): 0 denies;
# it reached 0 by excluding names equal to their role (15a's mutant) and by keying on a Check 22
# DISPOSITION rather than a substring (15i's mutant) -- the substring form scored 19 of 32
# OVERRIDDEN entries and denied S302 (two S302-5 entries, Check 11 and Check 16 dispositions citing
# "Check-22 pattern by analogy" in their Resolution) and S307 (a Check 929 entry whose Blocker type
# reads "Rule 19-adjacent"); the keyed form scores the other 16.
# Re-measured after the Remediation field was assembled across wrapped lines and the negation test
# scoped to the claim's own clause: archive+live concatenated, S298-S318, denies S316 and S317 only,
# and clause 1 still denies 0. Live alone also denies S318 once the consumer rotated its S318
# exception-(3)/(2) entry into the archive (live then holds no S318 OVERRIDDEN entry); the prior
# guard gives the identical live answer, so that row is the corpus moving, not this arm. Implementation scope over the 264 lead adjudicator
# briefs: 178 judged (every brief whose own nonce is implementation), 86 not (32 planning, 38
# sprint-review, 15 story, 1 sprint-review brief citing an earlier implementation nonce).
# Clause 2 (uncovered invalid-exception row): it denies live S316 (3 rows) and S317 (11 rows), and
# archive S316/S317/S318. Each of those rows is one validate-spawn-ledger.sh arm S3 FAILS, which
# makes each a true positive: Check 22 would discard the pass. The archived S318 rows are covered
# in the live file by an entry citing exceptions (3) and (2). Clause 2 reached that set by scoping
# to S3's shardable roles (15g; without it S316 adds a dev-escalated row S3 does not judge).
# Each world is a fresh project: stamp, roles and settings copied from CONSUMER, a snapshot
# naming the sprint, a seeded spawn ledger and a seeded pending.md. The ledger holds a non-subject
# epoch row FIRST, so no arm passes by reading only the first row.
WAIVER_SRC="$HERE/s317-tier-pin-waiver.md"
[ -r "$WAIVER_SRC" ] || bad "15 the extracted s317 waiver body ($WAIVER_SRC) is missing -- section 15 asserts nothing"
ledrow() { # ledrow <sprint> <name> <role> <tool_use_id> [shard]
  jq -nc --argjson s "$1" --arg n "$2" --arg r "$3" --arg t "$4" --arg sh "${5-}" \
    '{v:1,sprint:$s,name:$n,role:$r,tool_use_id:$t,shard:(if $sh == "" then null else $sh end)}'
}
mkworld() { # mkworld <name> <sprint> -> prints the project dir; ledger and pending.md from stdin-free files
  local p="$WORK/waiver-$1"
  mkdir -p "$p/.claude" "$p/_bmad-output" "$p/docs/escalations"
  cp -R "$CONSUMER/.claude/team-roles" "$p/.claude/"
  cp "$CONSUMER/.claude/.ai-dlc-version" "$CONSUMER/.claude/settings.json" "$p/.claude/"
  printf -- '- sprint_id: %s\n' "$2" > "$p/_bmad-output/pipeline-snapshot.md"
  { ledrow 316 epoch-row analyst toolu_EPOCH0
    ledrow 317 dev dev toolu_01DEVROW000000000000001
    ledrow 317 code-reviewer code-reviewer toolu_01CRROW0000000000000001
    ledrow 317 s317-w8 dev toolu_01W8ROW0000000000000001
  } > "$p/_bmad-output/spawn-ledger.jsonl"
  : > "$p/docs/escalations/pending.md"
  printf '%s\n' "$p"
}
entry() { # entry <file> <header> <body-line>...
  local f="$1" h="$2"; shift 2
  { printf '\n%s\n**Status:** OVERRIDDEN\n' "$h"; for l in "$@"; do printf '%s\n' "$l"; done; } >> "$f"
}
# Every adjudicator brief carries its gate nonce, as all 264 of the reference consumer's do; the
# arm judges IMPLEMENTATION gates only (Check 22's manifest row), so a world driven without one
# would assert nothing.
adjj() { mkjson Agent gate-adjudicator opus | jq -c --arg n "${1:-implementation-20261010T230257Z}" \
  '.tool_input.prompt += (" gate_nonce: " + $n)'; }
adj() { raw "$1" "$(adjj "${2-}")"; }
ADJ_REM="**Remediation:** outputs verified against the role contract."

W1="$(mkworld unnamed 317)"; cat "$WAIVER_SRC" >> "$W1/docs/escalations/pending.md"
W1_OUT="$(adj "$W1")"
expect_deny "$W1_OUT" "15a the real s317 tier-pin waiver (names 82 dev and 42 code-reviewer rows, no spawn)"
grep -qF 'names no spawn' <<<"$W1_OUT" && ok "  and the reason names the unnamed-waiver clause" \
  || bad "  the deny does not say the waiver names no spawn"
expect_quiet "$(raw "$W1" "$(mkjson Agent dev sonnet)")" "15a' the same world, a NON-adjudicator dispatch"

W2="$(mkworld tooluse 317)"
entry "$W2/docs/escalations/pending.md" "## [S317-CHECK22-WAIVER] lead - 2026-10-10" \
  "**Context:** Check 22 tier mismatch on toolu_01DEVROW000000000000001." "$ADJ_REM"
expect_quiet "$(adj "$W2")" "15b a Check 22 waiver naming a ledger tool_use_id"

W3="$(mkworld nameonly 317)"
entry "$W3/docs/escalations/pending.md" "## [S317-CHECK22-WAIVER] lead - 2026-10-10" \
  "**Context:** Check 22 tier mismatch on the dispatch s317-w8." "$ADJ_REM"
expect_quiet "$(adj "$W3")" "15c a Check 22 waiver naming a ledger dispatch name only"

W4="$(mkworld prior 318)"; cat "$WAIVER_SRC" >> "$W4/docs/escalations/pending.md"
expect_quiet "$(adj "$W4")" "15d the same unnamed waiver, from a PRIOR sprint"

# THE INVALID-EXCEPTION CLAUSE. One remediator row recorded `invalid-exception` in S317.
inv_world() { # inv_world <name> <entry-body-line> -> project dir
  local p; p="$(mkworld "$1" 317)"
  ledrow 317 remediator remediator toolu_01REMINV000000000000001 invalid-exception >> "$p/_bmad-output/spawn-ledger.jsonl"
  [ -n "$2" ] && entry "$p/docs/escalations/pending.md" "## [S317-CHECK22-S3] lead - 2026-10-10" \
    "**Context:** Check 22 arm S3 on toolu_01REMINV000000000000001." "$2"
  printf '%s\n' "$p"
}
W5="$(inv_world uncovered "**Remediation:** no Rule 28 exception applies, and none is invented here.")"
W5_OUT="$(adj "$W5")"
expect_deny "$W5_OUT" "15e an invalid-exception row named by a waiver that cites no exception"
grep -qF 'toolu_01REMINV000000000000001' <<<"$W5_OUT" && ok "  and the reason names the uncovered row" \
  || bad "  the deny does not name the uncovered invalid-exception row"
expect_deny "$(adj "$(inv_world generic "**Remediation:** one of Rule 28's four serial exceptions applied.")")" \
  "15e' the same, citing the exceptions only as \"the four\" (the s317 124524Z form)"
expect_quiet "$(adj "$(inv_world covered "**Remediation:** the exception that applied is exception (4), a serial document.")")" \
  "15f the same row, covered by an entry citing exception (4)"
W7="$(mkworld nonshard 317)"
ledrow 317 dev-escalated dev-escalated toolu_01DEVESCINV00000000001 invalid-exception >> "$W7/_bmad-output/spawn-ledger.jsonl"
expect_quiet "$(adj "$W7")" "15g an invalid-exception row on a NON-shardable role (Check 22 arm S3 does not judge it)"

# MUTANTS for arm 2, each a copy guarded by `cmp -s`, each killed by its own world only.
ADJCTL="$WORK/guard-adj-control.sh"; cp "$HOOK" "$ADJCTL"
adj_mut() { printf '%s' "$(adjj "${3-}")" | CLAUDE_PROJECT_DIR="$2" bash "$1" 2>/dev/null \
  | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null; }
[ "$(adj_mut "$ADJCTL" "$W1")" = deny ] && ok "ADJ MUTANT CONTROL: an unmutated copy denies 15a" \
  || bad "ADJ MUTANT CONTROL is dead -- the kills below are unearned"
adj_kill() { # adj_kill <name> <sed-expr> <world> <want: deny|allow> <label> [nonce]
  local m="$WORK/guard-adj-$1.sh" got
  sed "$2" "$HOOK" > "$m" || { bad "ADJ MUTANT $1: sed DID NOT APPLY"; return; }
  if cmp -s "$HOOK" "$m"; then bad "ADJ MUTANT $1 matched nothing (cmp -s guard)"; return; fi
  got="$(adj_mut "$m" "$3" "${6-}")"; [ -n "$got" ] || got=allow
  [ "$got" = "$4" ] && ok "ADJ MUTANT $1 killed: $5" || bad "ADJ MUTANT $1 SURVIVED: $5"
}
adj_kill regexonly 's/          if (t in key) named = 1$/          if (t ~ \/^(toolu_|a[0-9a-f]{16}$)\/) named = 1/' \
  "$W3" deny "a shape-regex join cannot see a waiver that names a spawn by dispatch name (15c)"
adj_kill rolename 's/          (if (.name \/\/ "") != "" and .name != .role then "K\\t" + .name else empty end),$/          (if (.name \/\/ "") != "" then "K\\t" + .name else empty end),/' \
  "$W1" allow "joining role-equal names reads \"82 dev and 42 code-reviewer rows\" as naming spawns (15a)"
adj_kill nosprint 's/^        if (hdr !~ ("\[Ss\]" sprint "(\[^0-9\]|\$)")) return$/        if (0) return/' \
  "$W4" deny "dropping the sprint scope refuses over a prior sprint's waiver (15d)"
adj_kill noinvalid 's/^        if (!dead) for (i = 1; i <= ni; i++) if (!(i in cov)) print "X\\t".*$/        if (0) print/' \
  "$W5" allow "dropping the invalid-exception clause misses an uncovered S3 row (15e)"
adj_kill anyexc 's/^        EXC = ".*"$/        EXC = "exception"/' \
  "$(inv_world generic2 "**Remediation:** one of Rule 28's four serial exceptions applied.")" allow \
  "a bare-word exception match accepts \"the four\" as a citation (15e')"
adj_kill noshardable 's/^\(          (if .shard == "invalid-exception"\) and (\$sh | contains(" " + \$role + " "))$/\1/' \
  "$W7" deny "dropping the shardable-role filter refuses over a dev-escalated row Check 22 arm S3 does not judge (15g)"

# THE SHARDED-REMEDIATION ARM of clause 2: Check 22 clearing arm 4 accepts, for this class, "the
# work was re-dispatched sharded" as well as a named exception. The three near-misses each carry
# `re-dispatch` and `shard` in the entry and must still deny: an UNCHOSEN option (the s317 form),
# a negated remediation, and one that never says sharded.
W8="$(inv_world sharded "**Remediation:** the work was re-dispatched sharded as rem-p1a and rem-p1b; output verified.")"
expect_quiet "$(adj "$W8")" "15h an invalid-exception row covered by a Remediation stating a sharded re-dispatch"
W8I="$(inv_world shardinline "Remediation: the work was re-dispatched sharded as rem-p1a and rem-p1b; output verified.")"
expect_quiet "$(adj "$W8I")" "15h' the same, written as an inline Remediation: (the adversary's s9 form)"
W8O="$(inv_world shardoption "**Options:** (a) OVERRIDDEN [chosen]; (b) re-dispatch the nine as sharded spawns.")"
expect_deny "$(adj "$W8O")" "15h'' a sharded re-dispatch only as an UNCHOSEN option (the s317 124524Z entry's form)"
W8N="$(inv_world shardneg "**Remediation:** No spawn is re-dispatched sharded; outputs verified.")"
expect_deny "$(adj "$W8N")" "15h''' a negated sharded re-dispatch in the Remediation"
W8U="$(inv_world shardnone "**Remediation:** the work was re-dispatched serially; output verified.")"
expect_deny "$(adj "$W8U")" "15h'''' a re-dispatch that is not sharded"

# CLAUSE 1 KEYS ON A CHECK 22 DISPOSITION. The near-miss carries both shapes the reference
# consumer's two false positives had: `Rule 19` in a field (S307 Check 929's "Rule 19-adjacent")
# and `Check-22` only in a Resolution (S302-5's "Check-22 pattern by analogy").
W9="$(mkworld substr 317)"
entry "$W9/docs/escalations/pending.md" "## [S317-Z] lead - 2026-10-10" \
  "**Blocker type:** Check 30 spec join ruling; unrelated to the Rule 19(b) binding." \
  "**Resolution:** disposition by the Check-22 pattern, by analogy."
expect_quiet "$(adj "$W9")" "15i an OVERRIDDEN Check 30 entry mentioning Rule 19(b) and Check-22 only in passing"
W9P="$(mkworld substrpos 317)"
entry "$W9P/docs/escalations/pending.md" "## [S317-Z] lead - 2026-10-10" \
  "**Blocker type:** Check 30 spec join ruling; unrelated to the Rule 19(b) binding." \
  "**Context:** Check 22 tier mismatch on the dev rows." "$ADJ_REM"
expect_deny "$(adj "$W9P")" "15i' its twin: the same entry with Check 22 in its Context (a disposition naming no spawn)"
W9C="$(mkworld substrcont 317)"
entry "$W9C/docs/escalations/pending.md" "## [S317-Z] lead - 2026-10-10" \
  "**Context:** Gate 3 ran the ledger validator, and" "the Check 22 FAIL lists the dev rows." "$ADJ_REM"
expect_deny "$(adj "$W9C")" "15i'' Check 22 on a wrapped continuation line of the Context field"

# ENTRIES SPLIT ON `## ` ONLY: a `###` subheading carrying the waiver's spawn list is the entry's.
W10="$(mkworld h3 317)"
entry "$W10/docs/escalations/pending.md" "## [S317-Y] lead - 2026-10-10" \
  "**Context:** Check 22 tier mismatch waived." "$ADJ_REM" "### Spawns waived" "toolu_01DEVROW000000000000001"
expect_quiet "$(adj "$W10")" "15j a Check 22 waiver whose spawn list sits under a ### subheading"

# ONLY AN IMPLEMENTATION GATE, read from the brief's OWN nonce: the first after its `gate_nonce`
# key, else the first anywhere; case-insensitive; a hyphenated prefix glued on still counts.
# `adjj` writes " gate_nonce: <arg>", so the arg's first nonce is the brief's own.
expect_quiet "$(adj "$W1" sprint-review-20261011T101010Z)" "15k the 15a world, a SPRINT-REVIEW adjudicator"
expect_quiet "$(raw "$W1" "$(mkjson Agent gate-adjudicator opus | jq -c '.tool_input.prompt += " cites implementation-20261010T230257Z. gate_nonce: sprint-review-20261011T101010Z"')")" \
  "15k' the 15a world, a sprint-review brief that CITES an earlier implementation nonce"
expect_quiet "$(raw "$W1" "$(mkjson Agent gate-adjudicator opus)")" "15k'' the 15a world, a brief naming no nonce"
expect_deny "$(adj "$W1" "implementation-20261010T230257Z; story verdict story-20261009T101010Z")" \
  "15k''' the 15a world, an implementation brief that also cites a story nonce (judged)"
expect_deny "$(adj "$W1" gate-adjudicator-implementation-20261010T230257Z)" \
  "15k'''' the 15a world, an implementation nonce glued to a hyphenated prefix (judged)"
expect_deny "$(adj "$W1" IMPLEMENTATION-20261010T230257Z)" "15k''''' the 15a world, an upper-case implementation nonce (judged)"

# A REFUSED DISPATCH WRITES NO LEDGER ROW; an allowed one in the same world writes exactly one.
L0="$(wc -l < "$W1/_bmad-output/spawn-ledger.jsonl" | tr -d ' ')"
adj "$W1" >/dev/null
L1="$(wc -l < "$W1/_bmad-output/spawn-ledger.jsonl" | tr -d ' ')"
adj "$W1" sprint-review-20261011T101010Z >/dev/null
L2="$(wc -l < "$W1/_bmad-output/spawn-ledger.jsonl" | tr -d ' ')"
[ "$L1" = "$L0" ] && [ "$L2" = "$((L0 + 1))" ] \
  && ok "15l a denied adjudicator dispatch leaves no ledger row; the allowed control adds one ($L0 -> $L1 -> $L2)" \
  || bad "15l ledger rows $L0 -> $L1 (denied) -> $L2 (allowed); expected $L0 -> $L0 -> $((L0 + 1))"

adj_kill substr 's/^        if (c22 \&\& !named) print "U\\t" hdr$/        if ((body ~ \/Check 22\/ || body ~ \/Check-22\/ || body ~ \/Rule 19\/) \&\& !named) print "U\\t" hdr/' \
  "$W9" deny "a bare substring reads a passing Rule 19 / Check-22 mention as a disposition (15i)"
adj_kill h3split 's/^      \/^## \/ { remclose(); flush(); hdr = \$0;/      \/^#{2,3} \/ { remclose(); flush(); hdr = $0;/' \
  "$W10" deny "splitting on ### drops the spawn list under a subheading (15j)"
adj_kill nosharded 's/^            || sharded) {$/            ) {/' \
  "$W8" deny "dropping the sharded-remediation disjunct refuses arm 4's other remedy (15h)"
adj_kill anyfield 's/^            || sharded) {$/            || sharded || remsharded(body)) {/' \
  "$W8O" allow "reading a sharded re-dispatch from any field accepts an unchosen option (15h'')"
adj_kill nonegation 's/^            if (!negwin(lastclause(pre), -4) \&\& (p > 0/            if ((p > 0/' \
  "$W8N" allow "dropping the negation test accepts \"No spawn is re-dispatched sharded\" (15h''')"
adj_kill noimplscope 's/^\[ "\$_dg_gt" = implementation \] \&\& DG_IMPL_GATE=true$/DG_IMPL_GATE=true/' \
  "$W1" deny "dropping the implementation-gate scope refuses a sprint-review adjudicator (15k)" sprint-review-20261011T101010Z

# THE REMEDIATION IS ASSEMBLED ACROSS WRAPPED LINES, AND NEGATION IS SCOPED TO THE CLAIM'S CLAUSE.
# The reference consumer wraps its fields (62 continuation lines inside OVERRIDDEN entries). Every
# world below is the 15e row named by an entry whose Remediation is the given text.
WRP="$(inv_world wrappos "$(printf '%s\n%s' '**Remediation:** the work was re-dispatched' 'sharded as rem-p1a and rem-p1b; output verified.')")"
expect_quiet "$(adj "$WRP")" "15m a sharded Remediation wrapped across two lines (re-dispatched / sharded)"
WRN="$(inv_world wrapneg "$(printf '%s\n%s' '**Remediation:** the work was not' 're-dispatched sharded; outputs verified.')")"
expect_deny "$(adj "$WRN")" "15m' its negated twin, the negator on the line BEFORE the claim (not / re-dispatched sharded)"
WSN="$(inv_world notserial "**Remediation:** the work was re-dispatched sharded, not serially, as rem-p1a and rem-p1b.")"
expect_quiet "$(adj "$WSN")" "15n a negation AFTER the claim (\"re-dispatched sharded, not serially\")"
expect_quiet "$(adj "$(inv_world soexc "**Remediation:** re-dispatched sharded as rem-p1a and rem-p1b, so no Rule 28 exception is claimed.")")" \
  "15n' a negated trailing clause (\"..., so no Rule 28 exception is claimed\")"
expect_quiet "$(adj "$(inv_world emdash "$(printf '**Remediation:** the work was re-dispatched sharded as rem-p1a and rem-p1b \342\200\224 none of the four exceptions applied.')")")" \
  "15n'' an em-dash clause after the claim (\"-- none of the four exceptions applied\")"
expect_quiet "$(adj "$(inv_world runt "**Remediation:** the work was re-dispatched sharded as s317-rem-run-t1 and s317-rem-run-t2.")")" \
  "15n''' a shard name the old n.t stand-in read as a negator (s317-rem-run-t1)"
WAP="$(inv_world apos "**Remediation:** the work wasn't re-dispatched sharded; outputs verified.")"
expect_deny "$(adj "$WAP")" "15o a straight-apostrophe negator before the claim (wasn't re-dispatched sharded)"
WCU="$(inv_world curly "$(printf '**Remediation:** the work wasn\342\200\231t re-dispatched sharded; outputs verified.')")"
expect_deny "$(adj "$WCU")" "15o' a curly-apostrophe negator before the claim"
WEN="$(inv_world excneg "**Remediation:** Rule 28 exception (3) does not apply; outputs verified.")"
expect_deny "$(adj "$WEN")" "15p a negated exception citation (\"exception (3) does not apply\")"
expect_deny "$(adj "$(inv_world excneg2 "**Remediation:** no exception (3) applies; outputs verified.")")" \
  "15p' a negator before the citation (\"no exception (3) applies\")"
expect_quiet "$(adj "$(inv_world excpos "**Remediation:** exception (3) applied, and no other was considered.")")" \
  "15p'' its twin: a cited exception with a negation in a LATER clause"
WXS="$(inv_world excprior "**Remediation:** The four were not invented. Exception (3) applied to toolu_01REMINV000000000000001.")"
expect_quiet "$(adj "$WXS")" "15p''' a cited exception with a negator in the PRIOR sentence"
adj_kill xsentence 's/^        n = split(norm(t), Q, \/\[.;\](\[\[:space:\]\]|\$)\/)$/        n = split(norm(t), Q, \/\\001\/)/' \
  "$WXS" deny "judging the whole field as one sentence lets a prior sentence's negator void a citation (15p''')"
adj_kill nojoin 's/^      !op \&\& inrem { rem = rem " " \$0 }$/      !op \&\& inrem { }/' \
  "$WRP" deny "dropping continuation lines refuses a wrapped sharded Remediation (15m)"
adj_kill perline 's/^      !op \&\& inrem { rem = rem " " \$0 }$/      !op \&\& inrem { if (remsharded($0)) sharded = 1; rem = rem " " $0 }/' \
  "$WRN" allow "reading each physical line alone accepts \"not / re-dispatched sharded\" (15m')"
adj_kill unscoped 's/^            if (!negwin(lastclause(pre), -4) \&\& (p > 0/            if (!negany(S[i]) \&\& (p > 0/' \
  "$WSN" deny "a sentence-wide negation test refuses \"re-dispatched sharded, not serially\" (15n)"
adj_kill noapos 's/^      function isneg(w) { return (w ~ \/^(no|not|never|none|nor|without|cannot)\$\/ || w ~ NT) }$/      function isneg(w) { return (w ~ \/^(no|not|never|none|nor|without|cannot)$\/) }/' \
  "$WAP" allow "dropping the n-apostrophe-t negator accepts \"wasn't re-dispatched sharded\" (15o)"
adj_kill nocurly 's/^        gsub(\/\\342\\200\\231\/, AP, t)$/        t = t/' \
  "$WCU" allow "dropping the curly-apostrophe fold accepts a curly \"wasn't\" (15o')"
adj_kill excnoneg 's/^            if (!negwin(lastclause(pre), -4) \&\& !negwin(firstclause(rest), 2)) return 1$/            return 1/' \
  "$WEN" allow "an unscoped exception match accepts \"exception (3) does not apply\" (15p)"
adj_kill firstnonce 's/^_dg_nl="\$(sed -n .*$/_dg_nl=""/' \
  "$W1" deny "ignoring the gate_nonce key reads a sprint-review brief's cited implementation nonce as its own (15k')" \
  "cites implementation-20261010T230257Z. gate_nonce: sprint-review-20261011T101010Z"
adj_kill boundary 's#grep -oE "$_dg_nre"#grep -oE "(^|[^a-z0-9-])$_dg_nre" | sed -E '\''s/^[^a-z]*//'\''#g' \
  "$W1" allow "requiring a boundary before the nonce misses one glued to a prefix (15k'''')" \
  gate-adjudicator-implementation-20261010T230257Z
# The ledger placement, mutated: a row appended BEFORE the deny arms.
LM="$WORK/guard-adj-ledgerfirst.sh"
sed 's/^# --- THE TWO DENY ARMS/mkdir -p "$SPAWN_STATE_DIR"; printf "{}\\n" >> "$SPAWN_LEDGER"; &/' "$HOOK" > "$LM"
if cmp -s "$HOOK" "$LM"; then bad "ADJ MUTANT ledgerfirst matched nothing (cmp -s guard)"
else
  LA="$(wc -l < "$W1/_bmad-output/spawn-ledger.jsonl" | tr -d ' ')"
  LD="$(adj_mut "$LM" "$W1")"
  LB="$(wc -l < "$W1/_bmad-output/spawn-ledger.jsonl" | tr -d ' ')"
  [ "$LD" = deny ] && [ "$LB" != "$LA" ] \
    && ok "ADJ MUTANT ledgerfirst killed: a row written before the arms survives a refused dispatch (15l)" \
    || bad "ADJ MUTANT ledgerfirst SURVIVED (decision '$LD', rows $LA -> $LB)"
fi

# BL-515 SAME-BATCH ORDER. Claude Code writes each tool_use of one assistant message as its own
# record sharing `message.id`. A sibling the cap ADMITTED in the rejection's own batch frees no slot.
t_usem() { # t_usem <message-id> <id> <description>
  jq -nc --arg m "$1" --arg id "$2" --arg d "$3" '{type:"assistant",isSidechain:false,
    message:{id:$m,role:"assistant",content:[{type:"tool_use",id:$id,name:"Agent",input:{description:$d}}]}}'
}
{ t_usem msg_B1 v1 "Party seat 7"; t_usem msg_B1 v2 "Party seat 8"
  t_res v1 "$CAPTXT" true; t_res v2 "Async agent launched successfully." false; } > "$CAPDIR/sb.jsonl"
{ t_usem msg_B1 v1 "Party seat 7"; t_res v1 "$CAPTXT" true
  t_usem msg_B2 v2 "Party seat 8"; t_res v2 "Async agent launched successfully." false; } > "$CAPDIR/sb2.jsonl"
expect_deny "$(capout "$CAPDIR/sb.jsonl" "Party seat 7")" "14h a re-send whose only later launch was a sibling in the rejection's own batch"
expect_quiet "$(capout "$CAPDIR/sb2.jsonl" "Party seat 7")" "14h' its twin: the same launch from a LATER message releases"
SBM="$WORK/guard-cap-samebatch.sh"
sed 's/^                   elif .held and .hmid != "" and .mid\[\$t.tool_use_id\] == .hmid then .$/                   elif false then ./' "$HOOK" > "$SBM"
if cmp -s "$HOOK" "$SBM"; then bad "CAP MUTANT samebatch matched nothing (cmp -s guard)"
elif [ -z "$(cap_mut "$SBM" "$CAPDIR/sb.jsonl" "Party seat 7")" ] && [ "$(cap_mut "$SBM" "$CAPDIR/a.jsonl" "Party seat 7")" = deny ]; then
  ok "CAP MUTANT samebatch killed: releasing on a same-batch sibling allows 14h (and still denies 14a)"
else bad "CAP MUTANT samebatch SURVIVED: 14h still denied, or the mutant stopped denying 14a"; fi

# BL-515 AN ERROR RESULT RELEASES NOTHING. A later Agent call that a HOOK refused (this guard's own
# deny among them) is an is_error tool_result that launched no agent, so no slot freed.
{ cat "$CAPDIR/a.jsonl"; t_use u5 Agent "Party seat 8"; t_res u5 "PreToolUse:Agent hook error: refused" true; } > "$CAPDIR/he.jsonl"
expect_deny "$(capout "$CAPDIR/he.jsonl" "Party seat 7")" "14i a re-send after only a HOOK-REFUSED Agent result (is_error, not the cap)"
ERM="$WORK/guard-cap-errorreleases.sh"
sed 's/^                   elif \$t.is_error == true then .$/                   elif false then ./' "$HOOK" > "$ERM"
if cmp -s "$HOOK" "$ERM"; then bad "CAP MUTANT errorreleases matched nothing (cmp -s guard)"
elif [ -z "$(cap_mut "$ERM" "$CAPDIR/he.jsonl" "Party seat 7")" ] && [ "$(cap_mut "$ERM" "$CAPDIR/a.jsonl" "Party seat 7")" = deny ]; then
  ok "CAP MUTANT errorreleases killed: releasing on any non-cap error result allows 14i (and still denies 14a)"
else bad "CAP MUTANT errorreleases SURVIVED: 14i still denied, or the mutant stopped denying 14a"; fi

echo
if [ "$fails" -eq 0 ]; then echo "dispatch-model-guard: PASS"; exit 0; fi
echo "dispatch-model-guard: $fails assertion(s) FAILED" >&2
exit 1
