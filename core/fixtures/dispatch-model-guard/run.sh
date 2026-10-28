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

expect_deny() { # expect_deny <out> <label>
  if [ "$(printf '%s' "$1" | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)" = deny ] \
     && printf '%s' "$1" | jq -e '.hookSpecificOutput | has("updatedInput") | not' >/dev/null 2>&1; then
    ok "$2 -> DENIED, with no updatedInput"
  else bad "$2 -> expected a deny with no updatedInput, got '$(printf '%s' "$1" | cut -c1-200)'"; fi
}
expect_quiet() { # expect_quiet <out> <label>
  [ -z "$1" ] && ok "$2 -> allowed (no decision)" || bad "$2 -> expected NO decision, got '$(printf '%s' "$1" | cut -c1-200)'"
}

# Each mutant is a COPY of the whole hooks directory, because the guard sources
# ai-dlc-context-provenance.sh as a sibling on its emit path.
HOOKS_SRC="$(dirname "$HOOK")"
mk_hooks_copy() { # mk_hooks_copy <tag> -> path of the guard inside a fresh copy of the hooks dir
  local d; d="$(mktemp -d "$WORK/hooks-$1.XXXXXX")" || return 1
  cp -R "$HOOKS_SRC/." "$d/" || return 1
  printf '%s/%s' "$d" "$(basename "$HOOK")"
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
[ -r "$SRC_ROLES/gate-adjudicator.md" ] && echo "HERMETIC-CONSUMED core/team-roles/gate-adjudicator.md"
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
# the seed. The model-binding subject is the CITED twin (the brief names the role file), so
# the injection is asserted where the dispatch is allowed; the uncited twin is THE CITATION
# DENY's: neither carrier delivers the Rule 19(b) line to a declared role, so it is refused
# with no row (the false/null record is observable only on the fail-open world below).
rm -f "$LEDGER"
JC="$(jq -nc '{tool_name:"Agent",tool_input:{name:"t-1",model:"sonnet",subagent_type:"remediator",prompt:"Your operating contract is `.claude/team-roles/remediator.md`. Read it first. Do the work."}}')"
[ "$(setmodel "$CONSUMER" "$JC")" = "opus" ] \
  && ok "subagent_type-only dispatch is bound (was a silent no-op before v0.158.0)" \
  || bad "subagent_type-only dispatch injected '$(setmodel "$CONSUMER" "$JC")', expected opus"
rm -f "$LEDGER"
J="$(jq -nc '{tool_name:"Agent",tool_input:{name:"t-1",model:"sonnet",subagent_type:"remediator",prompt:"Do the work."}}')"
J_OUT="$(raw "$CONSUMER" "$J")"
expect_deny "$J_OUT" "CITATION DENY: the same dispatch with no Rule 19(b) line (a declared role, no definition)"
[ ! -s "$LEDGER" ] && ok "  and writes no ledger row" || bad "  the denied uncited dispatch wrote a row: $(lrow)"
grep -qF 'refused a `remediator` dispatch, because the Rule 19(b) role-contract line' <<<"$J_OUT" \
  && ok "  and the reason names the role" || bad "  the citation deny does not name \`remediator\`"
# OUT OF SCOPE: an undeclared agent type with no line is the measured false-positive class.
GPJ="$(jq -nc '{tool_name:"Agent",tool_input:{description:"walk",subagent_type:"general-purpose",prompt:"Walk the rubric."}}')"
GP_D="$(raw "$CONSUMER" "$GPJ" | jq -r '.hookSpecificOutput.permissionDecision // "none"' 2>/dev/null)"
[ "$GP_D" != deny ] && ok "CITATION DENY: general-purpose with no line is NOT denied (decision '$GP_D')" \
  || bad "CITATION DENY: general-purpose with no line was DENIED -- the deny is not scoped to declared roles"
# FAIL OPEN: settings.json unparseable, so no declared set can be read. The dispatch is allowed
# and the row is still written with the uncited record Check 22 reads on this path.
FO="$WORK/citefailopen"
mkdir -p "$FO/.claude" "$FO/_bmad-output"
cp -R "$CONSUMER/.claude/team-roles" "$FO/.claude/"
cp "$CONSUMER/.claude/.ai-dlc-version" "$FO/.claude/"
printf '{ not json\n' > "$FO/.claude/settings.json"
printf -- '- sprint_id: 291\n' > "$FO/_bmad-output/pipeline-snapshot.md"
FO_D="$(raw "$FO" "$J" | jq -r '.hookSpecificOutput.permissionDecision // "none"' 2>/dev/null)"
FO_R="$(jq -r '"\(.role)/\(.role_contract_cited | tostring)/\(.contract_via | tostring)"' "$FO/_bmad-output/spawn-ledger.jsonl" 2>/dev/null | tail -1)"
[ "$FO_D" != deny ] && [ "$FO_R" = "remediator/false/null" ] \
  && ok "CITATION DENY fail-open: unparseable settings -> not denied, row records remediator/false/null" \
  || bad "CITATION DENY fail-open: decision '$FO_D', row '$FO_R'; expected not-deny and remediator/false/null"
CD_ANCHOR='  if [ -n "$DECLARED_ROLES" ] && row_in_scope "$ROLE" "$ROLE_CONTRACT_CITED"; then'
_cdn="$(grep -cxF -- "$CD_ANCHOR" "$HOOK")" || _cdn=0
CD_M="$(mk_hooks_copy citescope)"
if [ "$_cdn" = 1 ] && [ -n "$CD_M" ] \
   && A="$CD_ANCHOR" R='  if true; then' awk '$0 == ENVIRON["A"] { print ENVIRON["R"]; next } { print }' "$HOOK" > "$CD_M" \
   && ! cmp -s "$HOOK" "$CD_M" && bash -n "$CD_M" 2>/dev/null; then
  _cdm="$(printf '%s' "$GPJ" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$CD_M" 2>/dev/null | jq -r '.hookSpecificOutput.permissionDecision // "none"' 2>/dev/null)"
  _cdc="$(printf '%s' "$JC" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$CD_M" 2>/dev/null | jq -r '.hookSpecificOutput.permissionDecision // "none"' 2>/dev/null)"
  [ "$_cdm" = deny ] && [ "$_cdc" != deny ] \
    && ok "CITATION MUTANT scope-dropped killed: keying on the raw field denies general-purpose (and still allows the cited twin)" \
    || bad "CITATION MUTANT scope-dropped SURVIVED: general-purpose '$_cdm', cited twin '$_cdc'"
else bad "CITATION MUTANT scope-dropped DID NOT APPLY (anchor matched $_cdn line(s), or the copy failed or did not parse)"; fi

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
# THE WORLDS, each keyed to one property, scored `<decision>:<rows added>:<cited/via>`:
#   a  defok, subagent_type only, no prompt citation      -> allow:1:true/definition
#   b  defok, prompt cites the role AND definition bound  -> allow:1:true/prompt   (prompt wins)
#   c  defnoline, bound, body carries neither line         -> deny:0:-
#   d  defwrongrole, bound, body carries defok line 1 + 2  -> deny:0:-
#   e  remediator, no definition at all                    -> deny:0:-
#   f  defok, a two-document input the emit cannot amend  -> see its own comment
# THE CARRIER'S `false` IS NOW A DECISION, NOT A ROW. The carrier runs only on a BOUND definition,
# which needs the role's pin, so the role is a declared aiDlcRoles key -- and THE CITATION DENY
# refuses every uncited declared role before the append. c, d and e therefore read deny with no
# row; a carrier mutant crediting the line flips its cell to allow:1:true/definition. The uncited
# false/null ROW survives only where the deny cannot decide (the fail-open world above).
# c and d are MARKED and AGREE with settings, so the guard binds them exactly as it binds
# defok; only the body differs, which is the property under test. The definition_bound
# controls below say so in this run, or a false there would be a false for the wrong reason.
#
# EVERY DRIVE SEEDS AN EPOCH ROW FIRST, and it is not the subject. A one-row ledger makes the
# subject its own epoch and `tail -1` then reads whatever row exists; here the subject must be
# row 2 and must carry its own role, or the cell reports the row it did read. The epoch row is
# prompt-cited (true/prompt), so a subject that wrote nothing cannot pass a false/null arm on it.
EPOCHJ="$(mkjson Agent gate-adjudicator opus)"
# ccell <guard> <json> <subject-role> -> "<decision>:<rows added after the epoch>:<cited/via>"
# of the subject (`-` when it wrote no row). The decision is read literally, `none` when the hook
# printed nothing, so a crashed hook cannot pass for an allowed or a denied one.
ccell() {
  local n d o c=-
  rm -f "$LEDGER"
  printf '%s' "$EPOCHJ" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$1" >/dev/null 2>&1
  o="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$1" 2>/dev/null)"
  d="$(jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$o" 2>/dev/null)"; [ -n "$d" ] || d=none
  n="$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')"; n="${n:-0}"
  [ "$n" = 2 ] && c="$(tail -1 "$LEDGER" | jq -r --arg r "$3" \
    'if .role == $r then "\(.role_contract_cited | tostring)/\(.contract_via | tostring)" else "WRONGROW:\(.role)" end' 2>/dev/null)"
  printf '%s:%s:%s' "$d" "$((n - 1))" "$c"
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

# CONTROLS: c and d are bound (so the body is what decides), e is not. Their uncited dispatch is
# denied with no row, so binding is read off the PROMPT-CITED twin of the same role and world:
# definition binding is decided before the citation is, and does not read the prompt's line.
cited_twin() { printf '%s' "$1" | jq -c --arg r "$2" '.tool_input.prompt = ("Your operating contract is `.claude/team-roles/" + $r + ".md`. Read it first. " + .tool_input.prompt)'; }
for _cw in "a:defok:$CW_A" "c:defnoline:$CW_C" "d:defwrongrole:$CW_D"; do
  _cr="${_cw#*:}"; _cj="${_cr#*:}"; _cr="${_cr%%:*}"
  rm -f "$LEDGER"; raw "$CONSUMER" "$(cited_twin "$_cj" "$_cr")" >/dev/null
  [ "$(lfield .definition_bound)" = "true" ] \
    && ok "CONTROL world ${_cw%%:*}: the definition is BOUND (read on its cited twin), so the cell below is decided by the body" \
    || bad "CONTROL world ${_cw%%:*}: definition_bound='$(lfield .definition_bound)' on the cited twin, expected true — the world is not the one its arm claims"
done
rm -f "$LEDGER"; raw "$CONSUMER" "$(cited_twin "$CW_E" remediator)" >/dev/null
[ "$(lfield .definition_bound)" = "false" ] \
  && ok "CONTROL world e: remediator has no definition (definition_bound=false, on its cited twin)" \
  || bad "CONTROL world e: definition_bound='$(lfield .definition_bound)', expected false"

TIP_A="$(ccell "$HOOK" "$CW_A" defok)"
[ "$TIP_A" = "allow:1:true/definition" ] \
  && ok "(a) definition-bound, subagent_type-only, no prompt citation -> allowed, cited=true contract_via=definition" \
  || bad "(a) scored '$TIP_A', expected 'allow:1:true/definition' — the selected definition body carries the role line and the guard says it was not delivered"
TIP_B="$(ccell "$HOOK" "$CW_B" defok)"
[ "$TIP_B" = "allow:1:true/prompt" ] \
  && ok "(b) prompt citation with a definition ALSO bound -> allowed, contract_via=prompt (the prompt wins)" \
  || bad "(b) scored '$TIP_B', expected 'allow:1:true/prompt'"
TIP_C="$(ccell "$HOOK" "$CW_C" defnoline)"
[ "$TIP_C" = "deny:0:-" ] \
  && ok "(c) marked, agreeing definition whose body lacks the line -> DENIED, no row (the frontmatter is not the carrier)" \
  || bad "(c) scored '$TIP_C', expected 'deny:0:-' — a bound definition was credited without its body being read"
TIP_D="$(ccell "$HOOK" "$CW_D" defwrongrole)"
[ "$TIP_D" = "deny:0:-" ] \
  && ok "(d) role R definition carrying role S line 1 and the shared line 2 -> DENIED, no row (the match is role-specific)" \
  || bad "(d) scored '$TIP_D', expected 'deny:0:-' — another role's contract line was credited to this role"
TIP_E="$(ccell "$HOOK" "$CW_E" remediator)"
[ "$TIP_E" = "deny:0:-" ] \
  && ok "(e) no definition file, no prompt citation -> DENIED, no row" \
  || bad "(e) scored '$TIP_E', expected 'deny:0:-'"

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
[ "$TIP_F" = "none:1:true/definition" ] \
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
CC_WANT="a=allow:1:true/definition b=allow:1:true/prompt c=deny:0:- d=deny:0:- e=deny:0:-"

CC_CTL="$(mk_hooks_copy control)"
if [ -z "$CC_CTL" ] || [ ! -r "$(dirname "$CC_CTL")/ai-dlc-context-provenance.sh" ]; then
  bad "CARRIER MUTANT CONTROL: the hooks copy is missing the guard or its provenance sibling — every verdict below would be about a copy that cannot run"
else
  CC_CTL_VEC="$(cvec "$CC_CTL")"
  [ "$CC_CTL_VEC" = "$CC_WANT" ] \
    && ok "CARRIER MUTANT CONTROL: an unmutated hooks copy scores a=allow:1:true/definition (positive) and the full expected vector" \
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
  "a=allow:1:true/definition b=allow:1:true/prompt c=allow:1:true/definition d=allow:1:true/definition e=deny:0:-" \
  "citing on definition_bound alone credits the line-less body, so the deny lets it through — arm (c) owns it (d moves too, stated above)"
# (ii) the match keyed on line 2, which every role body carries.
cc_mut line2-key \
  '  _dg_line="$(printf '"'"'Your operating contract is `.claude/team-roles/%s.md`. Read it and follow it as your'"'"' "$ROLE")"' \
  '  _dg_line="FIRST action before any other work."' \
  "a=allow:1:true/definition b=allow:1:true/prompt c=deny:0:- d=allow:1:true/definition e=deny:0:-" \
  "keying on the shared line 2 credits another role line, so the deny lets it through — arm (d) alone catches it"
# (iii) revert to prompt-only: the definition carrier is never consulted.
cc_mut prompt-only \
  'if [ "$ROLE_CONTRACT_CITED" = false ] && [ "$DEFINITION_BOUND" = true ]; then' \
  'if false; then' \
  "a=deny:0:- b=allow:1:true/prompt c=deny:0:- d=deny:0:- e=deny:0:-" \
  "a prompt-only guard reads the definition-bound dispatch as uncited and refuses it — arm (a) alone catches it"

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
#
# THESE WORLDS DRIVE `dev-escalated`, A NON-SHARDABLE ROLE, ON PURPOSE. On a shardable role the
# guard now REFUSES an invented exception before any row is written (THE SHARD DENY), so a
# remediator subject would leave the parse with no row to read and every parse mutant below with
# no subject. `dev-escalated` is outside the guard's fixed shardable list and the seeded role
# files carry no party-seat sentence, so the parse is still recorded here. The deny is asserted
# by its own pair below (SHARD DENY), one property apart from these worlds.
SHARD_EPOCH="$(mkjson Agent gate-adjudicator opus)"
shard_payload() { # shard_payload <brief lines...> -> a dev-escalated (non-shardable) dispatch carrying them
  local p; p="Your operating contract is \`.claude/team-roles/dev-escalated.md\`. Read it first."
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
  tail -1 "$LEDGER" | jq -r 'if .role == "dev-escalated" then "\(.shard | tostring)|\(.shard_raw | tostring)" else "WRONGROW:\(.role)" end' 2>/dev/null
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

# THE ROW SURVIVES A RAW TEXT CUT INSIDE A MULTIBYTE CHARACTER (non-shardable role, as above). `shard_raw` is the first 160
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

# --- THE SHARD DENY: AN INVENTED EXCEPTION ON A SHARDABLE ROLE IS REFUSED, WITH NO ROW --------
# The row a shardable role writes under `invalid-exception` is one Check 22 arm S3 FAILS, so the
# guard refuses the dispatch before the ledger append. Scored as ONE vector of
# `<decision>:<rows added after the epoch>:<row-2 shard>` cells; the decision is read literally
# (`none` when the hook printed nothing), never normalised, so a crashed hook cannot pass for an
# allowed one. The pair `rinv`/`ninv` is ONE property apart (the role): the same invented line is
# denied with no row on `remediator` and recorded on `dev-escalated`. The other cells are
# shardable-role spellings that must stay allowed with their row.
dpayload() { # dpayload <role> [brief line] -> an Agent dispatch of <role> carrying the line
  local p; p="Your operating contract is \`.claude/team-roles/$1.md\`. Read it first."
  [ -n "${2-}" ] && p="$p"$'\n'"$2"
  jq -nc --arg p "$p"$'\n'"Do the work." '{tool_name:"Agent",tool_input:{name:"shard-deny",prompt:$p}}'
}
DOUT=""; DCELL=""
dcell() { # dcell <guard> <role> [brief line] -> prints "<decision>:<rows added>:<row-2 shard>"
  # and sets DCELL to it and DOUT to the hook's stdout (call without $( ) to keep the two).
  local n d s
  rm -f "$LEDGER"
  printf '%s' "$SHARD_EPOCH" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$1" >/dev/null 2>&1
  DOUT="$(dpayload "$2" "${3-}" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$1" 2>/dev/null)"
  d="$(jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$DOUT" 2>/dev/null)"
  [ -n "$d" ] || d=none
  n="$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')"; n="${n:-0}"
  if [ "$n" = 2 ]; then s="$(tail -1 "$LEDGER" | jq -r '.shard | tostring' 2>/dev/null)"; else s=-; fi
  DCELL="$d:$((n - 1)):$s"
  printf '%s' "$DCELL"
}
DINV='shard: none (serial cross-section remediator, after join)'
# THE DENY READS THE SHARDABLE SET, NOT THE WORD `remediator`. Two more denied cells carry the
# same invented line on shardable roles that are not the remediator: `qa` (a member of the fixed
# list, with no role file in this consumer) and `seatx`, a party seat the set picks up only from
# its role file's opening line. A deny keyed on the literal role `remediator` keeps rinv and
# loses both of these, which mutant (iii) below scores.
printf 'The lead spawns you as a party-mode persona. You speak as seatx.\n' > "$CONSUMER/.claude/team-roles/seatx.md"
dvec() {
  printf 'rinv=%s;qinv=%s;pinv=%s;ninv=%s;rac=%s;r3=%s;r11=%s;romit=%s;rsd=%s;rtitle=%s;rord=%s' \
    "$(dcell "$1" remediator "$DINV")" "$(dcell "$1" qa "$DINV")" "$(dcell "$1" seatx "$DINV")" \
    "$(dcell "$1" dev-escalated "$DINV")" \
    "$(dcell "$1" remediator 'shard: none (authoring-chain)')" "$(dcell "$1" remediator 'shard: none (3)')" \
    "$(dcell "$1" remediator 'shard: 1/1 x')" "$(dcell "$1" remediator)" \
    "$(dcell "$1" remediator 'shard: none (serial-document). Files you may edit: docs/a.md')" \
    "$(dcell "$1" remediator 'Shard: None (4)')" "$(dcell "$1" remediator 'shard: 3/7 x')"
}
DV_RINV='rinv=deny:0:-'
DV_QPINV='qinv=deny:0:-;pinv=deny:0:-'
DV_NINV='ninv=allow:1:invalid-exception'
DV_REST='rac=allow:1:none (3);r3=allow:1:none (3);r11=allow:1:1/1 x;romit=allow:1:null;rsd=allow:1:none (4);rtitle=allow:1:none (4);rord=allow:1:3/7 x'
DV_WANT="$DV_RINV;$DV_QPINV;$DV_NINV;$DV_REST"
DV_TIP="$(dvec "$HOOK")"
_old_ifs="$IFS"; IFS=';'
for _c in $DV_WANT; do
  case ";$DV_TIP;" in
    *";$_c;"*) ok "SHARD DENY ${_c%%=*}: '${_c#*=}' (decision:rows added:shard)" ;;
    *) bad "SHARD DENY ${_c%%=*}: expected '${_c#*=}', got vector '$DV_TIP'" ;;
  esac
done
IFS="$_old_ifs"

# The deny reason keeps the raw invented text, since no row carries `shard_raw` for it.
dcell "$HOOK" remediator "$DINV" >/dev/null
_drs="$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$DOUT" 2>/dev/null)"
case "$_drs" in
  *"$DINV"*) ok "SHARD DENY reason: quotes the raw line '$DINV'" ;;
  *) bad "SHARD DENY reason does not quote '$DINV': '$(printf '%s' "$_drs" | cut -c1-200)'" ;;
esac
case "$_drs" in
  *"shard: none (authoring-chain)"*) ok "  and names 'shard: none (authoring-chain)' for the serial remediator" ;;
  *) bad "  the deny reason does not name 'shard: none (authoring-chain)'" ;;
esac

# A DENIED BRIEF RE-SENT WITH A VALID LINE IS ALLOWED, AND ONLY THE RE-SEND WRITES A ROW. The
# ledger is NOT cleared between the two drives, so the deny must have left exactly the epoch.
rm -f "$LEDGER"
printf '%s' "$SHARD_EPOCH" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$HOOK" >/dev/null 2>&1
_rs1="$(dpayload remediator "$DINV" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$HOOK" 2>/dev/null)"
_rs1d="$(jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$_rs1" 2>/dev/null)"
_rs1n="$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')"
_rs2="$(dpayload remediator 'shard: none (authoring-chain)' | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$HOOK" 2>/dev/null)"
_rs2d="$(jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$_rs2" 2>/dev/null)"
_rs2n="$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')"
_rs2s="$(tail -1 "$LEDGER" 2>/dev/null | jq -r '.shard | tostring' 2>/dev/null)"
[ "$_rs1d:$_rs1n:$_rs2d:$_rs2n:$_rs2s" = "deny:1:allow:2:none (3)" ] \
  && ok "SHARD DENY re-send: denied with the epoch row only, then the corrected brief is allowed and records none (3)" \
  || bad "SHARD DENY re-send: got '$_rs1d:$_rs1n:$_rs2d:$_rs2n:$_rs2s', expected 'deny:1:allow:2:none (3)'"

# A RAW TEXT CUT INSIDE A MULTIBYTE CHARACTER ON THE DENY PATH: the reason carries the raw prefix,
# and the hook's output must still be one valid JSON object, or the harness reads no decision.
dcell "$HOOK" remediator "shard: none (x${_mb})" >/dev/null; _mbd="$DCELL"
if [ "$_mbd" = "deny:0:-" ] && jq -e . >/dev/null 2>&1 <<<"$DOUT" \
   && case "$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$DOUT" 2>/dev/null)" in *"shard: none (x"*) true ;; *) false ;; esac; then
  ok "SHARD DENY multibyte: a 160-byte cut inside a UTF-8 character still emits a valid deny carrying the raw prefix"
else
  bad "SHARD DENY multibyte: cell '$_mbd', output '$(printf '%s' "$DOUT" | cut -c1-200)'"
fi

# MUTANTS on the deny, scored on the EXACT eleven-cell vector, so each moves only the cells it owns.
DV_CTL_G="$(mk_hooks_copy deny-control)"
if [ -n "$DV_CTL_G" ] && [ "$(dvec "$DV_CTL_G")" = "$DV_WANT" ]; then
  ok "SHARD DENY MUTANT CONTROL: an unmutated hooks copy scores the full eleven-cell vector, the three denies and the near-miss row included (positive)"
else
  bad "SHARD DENY MUTANT CONTROL is dead: an unmutated copy scored '$(dvec "$DV_CTL_G")'"
fi
dv_mut() { # dv_mut <tag> <exact-anchor-line> <replacement-line> <expected-vector> <label>
  local g n vec
  n="$(grep -cxF -- "$2" "$HOOK")" || n=0
  if [ "$n" != 1 ]; then bad "SHARD DENY MUTANT $1 anchor matched $n lines in the guard, expected exactly 1"; return; fi
  g="$(mk_hooks_copy "$1")"
  if [ -z "$g" ]; then bad "SHARD DENY MUTANT $1: could not build the hooks copy"; return; fi
  A="$2" R="$3" awk '$0 == ENVIRON["A"] { print ENVIRON["R"]; next } { print }' "$HOOK" > "$g"
  if cmp -s "$HOOK" "$g"; then bad "SHARD DENY MUTANT $1 DID NOT APPLY (cmp -s)"; return; fi
  if ! bash -n "$g" 2>/dev/null; then bad "SHARD DENY MUTANT $1 DID NOT APPLY as valid shell"; return; fi
  vec="$(dvec "$g")"
  [ "$vec" = "$4" ] && ok "SHARD DENY MUTANT $1 killed: $5" \
    || bad "SHARD DENY MUTANT $1: vector '$vec', expected '$4' — $5 is not what the arms see"
}
# (i) the deny dropped: the invented line is recorded on every shardable role, as before this
# release. Cells rinv, qinv and pinv move. qa and seatx have no aiDlcRoles entry here, so an
# allowed dispatch of either prints nothing and reads `none`, with its row written.
dv_mut deny-dropped \
  'if [ "${SPAWN_SHARD:-}" = invalid-exception ]; then' \
  'if false; then' \
  "rinv=allow:1:invalid-exception;qinv=none:1:invalid-exception;pinv=none:1:invalid-exception;$DV_NINV;$DV_REST" \
  "a guard with no shard deny records the invented line S3 fails — cells rinv, qinv and pinv catch it"
# (ii) the shardable scoping dropped: every role is refused. Cell ninv alone moves.
dv_mut scoping-dropped \
  '    *" $ROLE "*)' \
  '    *)' \
  "$DV_RINV;$DV_QPINV;ninv=deny:0:-;$DV_REST" \
  "an unscoped deny refuses a dev-escalated dispatch S3 does not judge — cell ninv alone catches it"
# (iii) the shardable set replaced by the literal role `remediator`: the case subject becomes
# ` remediator `, so `*" $ROLE "*` matches only ROLE=remediator. Cells qinv (fixed list) and pinv
# (party seat) alone move; rinv stays denied, which is why rinv alone could not see this.
dv_mut remediator-only \
  '  case "$_dg_shardable" in' \
  '  case " remediator " in' \
  "$DV_RINV;qinv=none:1:invalid-exception;pinv=none:1:invalid-exception;$DV_NINV;$DV_REST" \
  "a deny keyed on the word remediator records the invented line on qa and on a party seat — cells qinv and pinv alone catch it"
rm -f "$CONSUMER/.claude/team-roles/seatx.md"

# --- THE COVER DENY: THE ONE CROSS AGENT (G=1) WHOSE ORDINALS OMIT A PART OF 1..K -----------
# Arm S4 fails such a row at the gate, so the guard refuses it before the append, naming the
# missing ordinals. Cells reuse dcell's `<decision>:<rows added after the epoch>:<row-2 shard>`.
# gap/full are ONE property apart (ordinal 3); the G>1 per-group cross covers a subset by design
# and is untouched; zpad is the zero-padded full list partition-document.sh emits at K>=10.
xvec() {
  printf 'gap=%s;full=%s;group=%s;zpad=%s' \
    "$(dcell "$1" remediator 'shard: cross/3 g1/1 1,2')" "$(dcell "$1" remediator 'shard: cross/3 g1/1 1,2,3')" \
    "$(dcell "$1" remediator 'shard: cross/3 g1/2 1,2')" "$(dcell "$1" remediator 'shard: cross/3 g1/1 01,02,03')"
}
XV_WANT='gap=deny:0:-;full=allow:1:cross/3 g1/1 1,2,3;group=allow:1:cross/3 g1/2 1,2;zpad=allow:1:cross/3 g1/1 01,02,03'
XV_TIP="$(xvec "$HOOK")"
_old_ifs="$IFS"; IFS=';'
for _c in $XV_WANT; do
  case ";$XV_TIP;" in
    *";$_c;"*) ok "COVER DENY ${_c%%=*}: '${_c#*=}' (decision:rows added:shard)" ;;
    *) bad "COVER DENY ${_c%%=*}: expected '${_c#*=}', got vector '$XV_TIP'" ;;
  esac
done
IFS="$_old_ifs"
dcell "$HOOK" remediator 'shard: cross/3 g1/1 1,2' >/dev/null
_xrs="$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$DOUT" 2>/dev/null)"
case "$_xrs" in *"omits part(s) 3 of 1..3"*) ok "COVER DENY reason names the missing ordinal: 'omits part(s) 3 of 1..3'" ;;
  *) bad "COVER DENY reason does not name ordinal 3: '$(printf '%s' "$_xrs" | cut -c1-200)'" ;; esac
# FAIL OPEN: the predicate erroring allows, with the row (Check 22 arm S4 still judges it).
XV_CTL="$(mk_hooks_copy cover-control)"
[ -n "$XV_CTL" ] && [ "$(xvec "$XV_CTL")" = "$XV_WANT" ] \
  && ok "COVER MUTANT CONTROL: an unmutated hooks copy scores the full four-cell vector, the deny included (positive)" \
  || bad "COVER MUTANT CONTROL is dead: an unmutated copy scored '$(xvec "$XV_CTL")'"
xv_mut() { # xv_mut <tag> <exact-anchor-line> <replacement-line> <expected-vector> <label>
  local g n vec
  n="$(grep -cxF -- "$2" "$HOOK")" || n=0
  if [ "$n" != 1 ]; then bad "COVER MUTANT $1 anchor matched $n lines in the guard, expected exactly 1"; return; fi
  g="$(mk_hooks_copy "$1")" || { bad "COVER MUTANT $1: could not build the hooks copy"; return; }
  A="$2" R="$3" awk '$0 == ENVIRON["A"] { print ENVIRON["R"]; next } { print }' "$HOOK" > "$g"
  if cmp -s "$HOOK" "$g"; then bad "COVER MUTANT $1 DID NOT APPLY (cmp -s)"; return; fi
  if ! bash -n "$g" 2>/dev/null; then bad "COVER MUTANT $1 DID NOT APPLY as valid shell"; return; fi
  vec="$(xvec "$g")"
  [ "$vec" = "$4" ] && ok "COVER MUTANT $1 killed: $5" \
    || bad "COVER MUTANT $1: vector '$vec', expected '$4' -- $5 is not what the arms see"
}
XV_GAP_ALLOWED='gap=allow:1:cross/3 g1/1 1,2;full=allow:1:cross/3 g1/1 1,2,3;group=allow:1:cross/3 g1/2 1,2;zpad=allow:1:cross/3 g1/1 01,02,03'
# (i) the shared predicate reports nothing missing: the gap is recorded, which S4 fails. Gap alone moves.
xv_mut nomissing '  return cv_out' '  return ""' "$XV_GAP_ALLOWED" \
  "a missing-ordinals predicate that reports nothing lets the gap through -- cell gap alone catches it"
# (ii) the predicate failing (nonzero rc, no output) FAILS OPEN: the gap is allowed with its row.
xv_mut predfail '  return cv_out' '  exit 3' "$XV_GAP_ALLOWED" \
  "a predicate that cannot run allows (fail open), never denies a full cover -- cell gap alone moves"

# --- THE MARK LINE: A BRIEF WHOSE `--mark` THE ENGINE WILL REFUSE IS DENIED; A RENDERED ONE IS RECORDED ---
# dg_mark_scan is the one predicate. Each cell is `<decision>:<rows written>:<mark field>`, the
# decision read literally (`none` when the hook printed nothing), so a crashed hook cannot pass for
# an allowed one; `-` when no row was written. Allowed cells read `allow` because the remediator
# dispatch carries no model param and is corrected, which is the same on every cell.
MCELL=""; MOUT=""
mcell() { # mcell <guard> <brief line> -> sets MCELL and MOUT
  local d n m
  rm -f "$LEDGER"
  MOUT="$(dpayload remediator "$2" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$1" 2>/dev/null)"
  d="$(jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$MOUT" 2>/dev/null)"; [ -n "$d" ] || d=none
  n="$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')"; n="${n:-0}"
  if [ "$n" = 1 ]; then m="$(jq -r '.mark | tostring' "$LEDGER" 2>/dev/null)"; else m=-; fi
  MCELL="$d:$n:$m"
}
ML_ROWS='/p/scripts/ai-dlc/wait-for-deliverable.sh --mark /x/dv.md deploy-validate qa deferred-ac-predicates rows=34'
ML_CHAIN='cd /x && /p/wait-for-deliverable.sh --mark /f.md s q k rows=3'
ML_PH='Close it with `<lead engine>/wait-for-deliverable.sh --mark <file> <step> <role> <shard> findings=<n>`.'
ML_RED='/p/wait-for-deliverable.sh --mark /f.md deploy-validate ops a2 findings=<number of RED verdicts>'
ML_PROSE='Then run /p/wait-for-deliverable.sh --mark /f.md deploy-validate qa k findings=0. Evidence blocks come first.'
ML_S319='When done run /g/scripts/ai-dlc/wait-for-deliverable.sh --mark /g/_bmad-output/dv-s319.md deploy-validate qa deferred-ac-predicates rows=<n>. A trailer naming the model goes last.'
ML_NONE='Write the result to /f.md and stop.'
ML_GOOD='/g/scripts/ai-dlc/wait-for-deliverable.sh --mark /g/_bmad-output/dv.md deploy-validate qa deferred-ac-predicates findings=0'
mvec() {
  local o=""
  mcell "$1" "$ML_ROWS";  o="rows=$MCELL"
  mcell "$1" "$ML_CHAIN"; o="$o;chain=$MCELL"
  mcell "$1" "$ML_PH";    o="$o;ph=$MCELL"
  mcell "$1" "$ML_RED";   o="$o;red=$MCELL"
  mcell "$1" "$ML_PROSE"; o="$o;prose=$MCELL"
  mcell "$1" "$ML_S319";  o="$o;s319=$MCELL"
  mcell "$1" "$ML_NONE";  o="$o;none=$MCELL"
  mcell "$1" "$ML_GOOD";  o="$o;good=$MCELL"
  printf '%s' "$o"
}
MV_WANT='rows=deny:0:-;chain=deny:0:-;ph=allow:1:rendered;red=allow:1:rendered;prose=allow:1:rendered;s319=deny:0:-;none=allow:1:null;good=allow:1:rendered'
MV_TIP="$(mvec "$HOOK")"
_old_ifs="$IFS"; IFS=';'
for _c in $MV_WANT; do
  case ";$MV_TIP;" in
    *";$_c;"*) ok "MARK LINE ${_c%%=*}: '${_c#*=}' (decision:rows:mark)" ;;
    *) bad "MARK LINE ${_c%%=*}: expected '${_c#*=}', got vector '$MV_TIP'" ;;
  esac
done
IFS="$_old_ifs"
# The deny text is the engine refusal plus the corrected line, rendered from the offending one.
mcell "$HOOK" "$ML_ROWS"
_mrs="$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$MOUT" 2>/dev/null)"
case "$_mrs" in
  *"the last field must be findings=<n> (got 'rows=34')"*"/p/scripts/ai-dlc/wait-for-deliverable.sh --mark /x/dv.md deploy-validate qa deferred-ac-predicates findings=<n>"*)
    ok "MARK LINE reason: the engine refusal naming rows=34, then the rendered line to copy" ;;
  *) bad "MARK LINE reason lacks the refusal or the rendered line: '$(printf '%s' "$_mrs" | cut -c1-300)'" ;;
esac
# MUTANTS, each scored on the EXACT vector and each killed by the cell named in its label.
ml_mut() { # ml_mut <tag> <exact-anchor-line> <replacement-line> <expected-vector> <label>
  local g n vec
  n="$(grep -cxF -- "$2" "$HOOK")" || n=0
  if [ "$n" != 1 ]; then bad "MARK LINE MUTANT $1 anchor matched $n lines in the guard, expected exactly 1"; return; fi
  g="$(mk_hooks_copy "ml-$1")"
  if [ -z "$g" ]; then bad "MARK LINE MUTANT $1: could not build the hooks copy"; return; fi
  A="$2" R="$3" awk '$0 == ENVIRON["A"] { print ENVIRON["R"]; next } { print }' "$HOOK" > "$g"
  if cmp -s "$HOOK" "$g"; then bad "MARK LINE MUTANT $1 DID NOT APPLY (cmp -s)"; return; fi
  if ! bash -n "$g" 2>/dev/null; then bad "MARK LINE MUTANT $1 DID NOT APPLY as valid shell"; return; fi
  vec="$(mvec "$g")"
  [ "$vec" = "$4" ] && ok "MARK LINE MUTANT $1 killed: $5" \
    || bad "MARK LINE MUTANT $1: vector '$vec', expected '$4' -- $5 is not what the arms see"
}
_mlc="$(mk_hooks_copy ml-control)"
[ -n "$_mlc" ] && [ "$(mvec "$_mlc")" = "$MV_WANT" ] \
  && ok "MARK LINE MUTANT CONTROL: an unmutated hooks copy scores the full eight-cell vector" \
  || bad "MARK LINE MUTANT CONTROL is dead: an unmutated copy scored '$(mvec "$_mlc")'"
# (m1) the cut at a period before a capital dropped: only the backtick cut remains, and the s319
# sentence after `rows=<n>.` supplies the last field, which carries no `=`.
ml_mut backtick-only \
  '      if (match(t, /\. [A-Z]/) && RSTART < c) c = RSTART; if (substr(t, length(t)) == "." && length(t) < c) c = length(t)' \
  '      c = c' \
  'rows=deny:0:-;chain=deny:0:-;ph=allow:1:rendered;red=allow:1:rendered;prose=allow:1:null;s319=allow:1:null;none=allow:1:null;good=allow:1:rendered' \
  "a backtick-only cut lets the s319 brief through undenied -- cell s319 catches it (and, under the field rule, cell prose loses its field)"
# (m2) a digits-strict parse: only findings=<digits> passes, so a placeholder is denied.
ml_mut digits-strict \
  '      if (last ~ /^[A-Za-z_]+=/ && substr(last, 1, 9) != "findings=") {' \
  '      if (last ~ /^[A-Za-z_]+=/ && last !~ /^findings=[0-9]+$/) {' \
  'rows=deny:0:-;chain=deny:0:-;ph=deny:0:-;red=allow:1:rendered;prose=allow:1:rendered;s319=deny:0:-;none=allow:1:null;good=allow:1:rendered' \
  "a digits-strict parse refuses the findings=<n> template -- cell ph alone catches it"
# (m3) the field written on every allowed dispatch, brief or no brief.
ml_mut always-field \
  'SPAWN_MARK=""' \
  'SPAWN_MARK=rendered' \
  'rows=deny:0:-;chain=deny:0:-;ph=allow:1:rendered;red=allow:1:rendered;prose=allow:1:rendered;s319=deny:0:-;none=allow:1:rendered;good=allow:1:rendered' \
  "a field written whatever the brief says arms --complete on a dispatch with no --mark -- cell none alone catches it"

# THE FIELD RULE: a trigger alone writes no field. `rendered` is written only for a line the engine's
# arity and last-field check would ACCEPT -- five fields or more (the file plus four) with the last
# starting `findings=`. Each of these lines triggers the scan and is not denied, and the engine
# refuses every one (exit 64), so a field on any of them arms --complete on a marker that never
# lands. Cell fgood is the well-formed control in the same vector.
MF_NOFIND='/p/wait-for-deliverable.sh --mark /f.md s q k'
MF_ZERO='/p/wait-for-deliverable.sh --mark /f.md s q k 0'
MF_BARE='/p/wait-for-deliverable.sh --mark /f.md'
MF_PROSE='Do NOT run wait-for-deliverable.sh --mark yourself; the lead does.'
MF_SHORT='/p/wait-for-deliverable.sh --mark /f.md s findings=0'
# The reference consumer's s319 ops brief: the engine reads the last field as `findings=0)`.
MF_PAREN='all: /g/wait-for-deliverable.sh --mark /g/dv-4b-a1.md deploy-validate ops a1 findings=0 (the last field must be findings=<n>, use findings=<number of RED probes>). If anything looks unsafe, stop.'
# One well-formed line beside one refused line: the field is owed to neither.
MF_MIXED="$ML_GOOD
$MF_NOFIND"
mfvec() {
  local o=""
  mcell "$1" "$MF_NOFIND"; o="nofind=$MCELL"
  mcell "$1" "$MF_ZERO";   o="$o;zero=$MCELL"
  mcell "$1" "$MF_BARE";   o="$o;bare=$MCELL"
  mcell "$1" "$MF_PROSE";  o="$o;fprose=$MCELL"
  mcell "$1" "$MF_SHORT";  o="$o;short=$MCELL"
  mcell "$1" "$MF_PAREN";  o="$o;paren=$MCELL"
  mcell "$1" "$MF_MIXED";  o="$o;mixed=$MCELL"
  mcell "$1" "$ML_GOOD";   o="$o;fgood=$MCELL"
  printf '%s' "$o"
}
MF_WANT='nofind=allow:1:null;zero=allow:1:null;bare=allow:1:null;fprose=allow:1:null;short=allow:1:null;paren=allow:1:null;mixed=allow:1:null;fgood=allow:1:rendered'
MF_TIP="$(mfvec "$HOOK")"
_old_ifs="$IFS"; IFS=';'
for _c in $MF_WANT; do
  case ";$MF_TIP;" in
    *";$_c;"*) ok "MARK FIELD ${_c%%=*}: '${_c#*=}' (decision:rows:mark)" ;;
    *) bad "MARK FIELD ${_c%%=*}: expected '${_c#*=}', got vector '$MF_TIP'" ;;
  esac
done
IFS="$_old_ifs"
# (m4) the old END restored: any trigger writes the field. Scored on the exact field vector; the
# findings-less cell nofind is the first to see it (every cell but fgood flips to rendered).
_mf_a="    END { if (!den && good > 0 && good == trig) print \"rendered\" }'"
_mf_r="    END { if (!den && trig > 0) print \"rendered\" }'"
_mf_n="$(grep -cxF -- "$_mf_a" "$HOOK")" || _mf_n=0
if [ "$_mf_n" != 1 ]; then bad "MARK FIELD MUTANT trig-field anchor matched $_mf_n lines in the guard, expected exactly 1"
else
  _mf_g="$(mk_hooks_copy "mf-trig")"
  if [ -z "$_mf_g" ]; then bad "MARK FIELD MUTANT trig-field: could not build the hooks copy"
  else
    A="$_mf_a" R="$_mf_r" awk '$0 == ENVIRON["A"] { print ENVIRON["R"]; next } { print }' "$HOOK" > "$_mf_g"
    if cmp -s "$HOOK" "$_mf_g"; then bad "MARK FIELD MUTANT trig-field DID NOT APPLY (cmp -s)"
    elif ! bash -n "$_mf_g" 2>/dev/null; then bad "MARK FIELD MUTANT trig-field DID NOT APPLY as valid shell"
    else
      _mf_v="$(mfvec "$_mf_g")"
      [ "$_mf_v" = 'nofind=allow:1:rendered;zero=allow:1:rendered;bare=allow:1:rendered;fprose=allow:1:rendered;short=allow:1:rendered;paren=allow:1:rendered;mixed=allow:1:rendered;fgood=allow:1:rendered' ] \
        && ok "MARK FIELD MUTANT trig-field killed: a field on any trigger arms --complete on a line the engine refuses -- cell nofind catches it" \
        || bad "MARK FIELD MUTANT trig-field: vector '$_mf_v' -- cell nofind is not what the arms see"
    fi
  fi
fi
# (m5) any-good: one well-formed line suffices, so a brief carrying a refused line beside it still
# writes the field. Only cell mixed sees it.
_mf_r2="    END { if (!den && good > 0) print \"rendered\" }'"
_mf_g2="$(mk_hooks_copy "mf-anygood")"
if [ -z "$_mf_g2" ] || [ "$_mf_n" != 1 ]; then bad "MARK FIELD MUTANT any-good: could not build the hooks copy or the anchor is not unique"
else
  A="$_mf_a" R="$_mf_r2" awk '$0 == ENVIRON["A"] { print ENVIRON["R"]; next } { print }' "$HOOK" > "$_mf_g2"
  if cmp -s "$HOOK" "$_mf_g2"; then bad "MARK FIELD MUTANT any-good DID NOT APPLY (cmp -s)"
  elif ! bash -n "$_mf_g2" 2>/dev/null; then bad "MARK FIELD MUTANT any-good DID NOT APPLY as valid shell"
  else
    _mf_v2="$(mfvec "$_mf_g2")"
    [ "$_mf_v2" = 'nofind=allow:1:null;zero=allow:1:null;bare=allow:1:null;fprose=allow:1:null;short=allow:1:null;paren=allow:1:null;mixed=allow:1:rendered;fgood=allow:1:rendered' ] \
      && ok "MARK FIELD MUTANT any-good killed: one well-formed line beside a refused one arms --complete on the refused file -- cell mixed alone catches it" \
      || bad "MARK FIELD MUTANT any-good: vector '$_mf_v2' -- cell mixed is not what the arms see"
  fi
fi

# THE SAME LINE: every invocation on a line is scanned, not only the first. A refused invocation
# after a good one on the same line withholds the field (or denies, for a `name=` last field), and an
# invocation ends where the token carrying the next engine name begins, so an unfenced refused one
# does not borrow the next one's `findings=`. THE TRAILING DOT: a teammate copies `findings=0.` and
# the engine refuses it, so a last field made `findings=...` only by cutting a trailing period is not
# well formed; cell nodot is the same line without the period.
SL_GOOD='/p/wait-for-deliverable.sh --mark /f.md s q k findings=0'
SL_GB="Run \`$SL_GOOD\`, then \`/p/wait-for-deliverable.sh --mark /f2.md s findings=0\`."
SL_BG="Run \`/p/wait-for-deliverable.sh --mark /f2.md s findings=0\`, then \`$SL_GOOD\`."
SL_GG="Run \`$SL_GOOD\`, then \`/p/wait-for-deliverable.sh --mark /f2.md s q k2 findings=1\`."
SL_DENY="Run \`$SL_GOOD\`, then \`/p/wait-for-deliverable.sh --mark /f2.md s q k rows=34\`."
SL_NOSEP="/p/wait-for-deliverable.sh --mark /f2.md s q k rows=3; $SL_GOOD"
SL_DOT="Then run $SL_GOOD."
SL_NODOT="Then run $SL_GOOD"
# THE BOUND KEYS ON AN INVOCATION, not on any token naming the engine: a field that merely CONTAINS
# the engine name stays a field the engine reads. engtok-log and engtok-prose end in such a token,
# which the engine takes as the last field and refuses; engtok-deny is a name= last field carrying
# the name; engtok-path is a well-formed line whose FILE carries the name.
SL_ETLOG="Run /p/wait-for-deliverable.sh --mark a.md s1 qa none findings=0 wait-for-deliverable.sh.log"
SL_ETPROSE="Run /p/wait-for-deliverable.sh --mark a.md s1 qa none findings=0 (wait-for-deliverable.sh refuses any other last field)"
SL_ETDENY="Run /p/wait-for-deliverable.sh --mark a.md s1 qa 1 x=wait-for-deliverable.sh"
SL_ETPATH="Run /p/wait-for-deliverable.sh --mark /x/wait-for-deliverable.sh.md s1 qa none findings=0"
slvec() {
  local o=""
  mcell "$1" "$SL_GB";    o="samelinegb=$MCELL"
  mcell "$1" "$SL_BG";    o="$o;samelinebg=$MCELL"
  mcell "$1" "$SL_GG";    o="$o;samelinegg=$MCELL"
  mcell "$1" "$SL_DENY";  o="$o;sameline-deny=$MCELL"
  mcell "$1" "$SL_NOSEP"; o="$o;nosep=$MCELL"
  mcell "$1" "$SL_DOT";   o="$o;dot=$MCELL"
  mcell "$1" "$SL_NODOT"; o="$o;nodot=$MCELL"
  mcell "$1" "$SL_ETLOG";   o="$o;engtok-log=$MCELL"
  mcell "$1" "$SL_ETPROSE"; o="$o;engtok-prose=$MCELL"
  mcell "$1" "$SL_ETDENY";  o="$o;engtok-deny=$MCELL"
  mcell "$1" "$SL_ETPATH";  o="$o;engtok-path=$MCELL"
  printf '%s' "$o"
}
SL_WANT='samelinegb=allow:1:null;samelinebg=allow:1:null;samelinegg=allow:1:rendered;sameline-deny=deny:0:-;nosep=deny:0:-;dot=allow:1:null;nodot=allow:1:rendered;engtok-log=allow:1:null;engtok-prose=allow:1:null;engtok-deny=deny:0:-;engtok-path=allow:1:rendered'
SL_TIP="$(slvec "$HOOK")"
_old_ifs="$IFS"; IFS=';'
for _c in $SL_WANT; do
  case ";$SL_TIP;" in
    *";$_c;"*) ok "MARK LINE ${_c%%=*}: '${_c#*=}' (decision:rows:mark)" ;;
    *) bad "MARK LINE ${_c%%=*}: expected '${_c#*=}', got vector '$SL_TIP'" ;;
  esac
done
IFS="$_old_ifs"
# The deny on the SECOND invocation renders the correction from that invocation, not the first.
mcell "$HOOK" "$SL_DENY"
_sls="$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$MOUT" 2>/dev/null)"
case "$_sls" in
  *"(got 'rows=34')"*"/p/wait-for-deliverable.sh --mark /f2.md s q k findings=<n>"*)
    ok "MARK LINE sameline-deny reason: names rows=34 and renders the second invocation's line" ;;
  *) bad "MARK LINE sameline-deny reason does not render the second invocation: '$(printf '%s' "$_sls" | cut -c1-300)'" ;;
esac
sl_mut() { # sl_mut <tag> <exact-anchor-line> <replacement-line> <expected-vector> <label>
  local g n vec
  n="$(grep -cxF -- "$2" "$HOOK")" || n=0
  if [ "$n" != 1 ]; then bad "SAME LINE MUTANT $1 anchor matched $n lines in the guard, expected exactly 1"; return; fi
  g="$(mk_hooks_copy "sl-$1")"
  if [ -z "$g" ]; then bad "SAME LINE MUTANT $1: could not build the hooks copy"; return; fi
  A="$2" R="$3" awk '$0 == ENVIRON["A"] { print ENVIRON["R"]; next } { print }' "$HOOK" > "$g"
  if cmp -s "$HOOK" "$g"; then bad "SAME LINE MUTANT $1 DID NOT APPLY (cmp -s)"; return; fi
  if ! bash -n "$g" 2>/dev/null; then bad "SAME LINE MUTANT $1 DID NOT APPLY as valid shell"; return; fi
  vec="$(slvec "$g")"
  [ "$vec" = "$4" ] && ok "SAME LINE MUTANT $1 killed: $5" \
    || bad "SAME LINE MUTANT $1: vector '$vec', expected '$4' -- $5 is not what the arms see"
}
# (m6) first-invocation-only: nothing is left to scan after one pass.
sl_mut first-only \
  '      s = t' \
  '      s = ""' \
  'samelinegb=allow:1:rendered;samelinebg=allow:1:null;samelinegg=allow:1:rendered;sameline-deny=allow:1:rendered;nosep=deny:0:-;dot=allow:1:null;nodot=allow:1:rendered;engtok-log=allow:1:null;engtok-prose=allow:1:null;engtok-deny=deny:0:-;engtok-path=allow:1:rendered' \
  "scanning only the first invocation on a line arms --complete past a refused second one -- cells samelinegb and sameline-deny catch it"
# (m7) no invocation bound: the refused first invocation borrows the second one's findings=0.
sl_mut no-bound \
  '      q = (match(t, /wait-for-deliverable\.sh[[:space:]]--mark[[:space:]]/) ? RSTART : 0); if (q > 0) { t = substr(t, 1, q - 1); sub(/[^[:space:]]*$/, "", t) }' \
  '      q = 0' \
  'samelinegb=allow:1:null;samelinebg=allow:1:null;samelinegg=allow:1:rendered;sameline-deny=deny:0:-;nosep=allow:1:rendered;dot=allow:1:null;nodot=allow:1:rendered;engtok-log=allow:1:null;engtok-prose=allow:1:null;engtok-deny=deny:0:-;engtok-path=allow:1:rendered' \
  "an unbounded invocation reads the next one's findings= as its own last field -- cell nosep alone catches it"
# (m8) the dot-cut field re-accepted.
sl_mut dot-accept \
  '      if (m >= 5 && h[m] ~ /^findings=([0-9]+|<x>)$/ && !dot) good++' \
  '      if (m >= 5 && h[m] ~ /^findings=([0-9]+|<x>)$/) good++' \
  'samelinegb=allow:1:null;samelinebg=allow:1:null;samelinegg=allow:1:rendered;sameline-deny=deny:0:-;nosep=deny:0:-;dot=allow:1:rendered;nodot=allow:1:rendered;engtok-log=allow:1:null;engtok-prose=allow:1:null;engtok-deny=deny:0:-;engtok-path=allow:1:rendered' \
  "a field made findings= by cutting the trailing period arms --complete on a findings=0. the engine refuses -- cell dot alone catches it"
# (m9) the bound keyed on ANY token containing the engine name: a trailing field that names the engine
# is stripped, so the line before it reads as well formed, a name= field naming it is stripped and
# the deny is lost, and a file path naming it empties the invocation.
sl_mut index-bound \
  '      q = (match(t, /wait-for-deliverable\.sh[[:space:]]--mark[[:space:]]/) ? RSTART : 0); if (q > 0) { t = substr(t, 1, q - 1); sub(/[^[:space:]]*$/, "", t) }' \
  '      q = index(t, W); if (q > 0) { t = substr(t, 1, q - 1); sub(/[^[:space:]]*$/, "", t) }' \
  'samelinegb=allow:1:null;samelinebg=allow:1:null;samelinegg=allow:1:rendered;sameline-deny=deny:0:-;nosep=deny:0:-;dot=allow:1:null;nodot=allow:1:rendered;engtok-log=allow:1:rendered;engtok-prose=allow:1:rendered;engtok-deny=allow:1:null;engtok-path=allow:1:null' \
  "a bound on any token containing the engine name arms --complete on a line the engine refuses and loses a deny -- cells engtok-log, engtok-prose, engtok-deny and engtok-path catch it"

# THE SCAN FAILS OPEN. A failed dg_mark_scan is neither a deny nor a field, so a broken scan reads
# exactly like a clean brief; this cell is the only thing that can tell the two apart. FORCED by a
# PATH shim for `awk` -- the hook resolves awk through PATH -- that exits 2 with no output ONLY for
# the awk program carrying the mark-scan token and execs the real awk for every other program, so
# the scan fails the way a broken awk would while the shard parse and frontmatter reads still run.
# The brief is the rows=34 line a working scan denies, so `allow:1:null` can only mean the scan
# failed and the dispatch went on. Cell fo-ctl is the same brief through the same PATH with the
# shim absent: denied. The shim token is checked to be in the hook before the cell is trusted.
ML_SHIM="$WORK/ml-awk-shim"; mkdir -p "$ML_SHIM"
ML_AWK="$(command -v awk)"
printf '#!/bin/sh\ncase "$*" in *wait-for-deliverable.sh*) exit 2 ;; esac\nexec %s "$@"\n' "$ML_AWK" > "$ML_SHIM/awk"
chmod +x "$ML_SHIM/awk"
# The shim must be the awk a PATH lookup finds, or the fail-open cell reads a working scan's deny.
[ "$(PATH="$ML_SHIM:$PATH" bash -c 'command -v awk')" = "$ML_SHIM/awk" ] \
  || bad "MARK LINE fail-open FIXTURE BROKEN: the awk shim is not what PATH resolves (not executable?), so the scan cannot be forced to fail"
fo_cell() { # fo_cell <guard> <path-prefix> -> "<decision>:<rows>:<mark>"
  local o d n m
  rm -f "$LEDGER"
  o="$(dpayload remediator "$ML_ROWS" | PATH="$2$PATH" CLAUDE_PROJECT_DIR="$CONSUMER" bash "$1" 2>/dev/null)"
  d="$(jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$o" 2>/dev/null)"; [ -n "$d" ] || d=none
  n="$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')"; n="${n:-0}"
  if [ "$n" = 1 ]; then m="$(jq -r 'if has("mark") then .mark else "NOKEY" end' "$LEDGER" 2>/dev/null)"; else m=-; fi
  printf '%s:%s:%s' "$d" "$n" "$m"
}
_fo_tok="$(grep -c 'BEGIN { W = "wait-for-deliverable.sh"' "$HOOK")" || _fo_tok=0
[ "$_fo_tok" = 1 ] || bad "MARK LINE fail-open FIXTURE BROKEN: the shim token is on $_fo_tok lines of the guard, expected 1, so the shim would not fail the scan"
_fo_ctl="$(fo_cell "$HOOK" "")"
[ "$_fo_ctl" = "deny:0:-" ] && ok "MARK LINE fo-ctl: the rows=34 brief with the scan intact is denied, no row ($_fo_ctl)" \
  || bad "MARK LINE fo-ctl: expected 'deny:0:-', got '$_fo_ctl'"
_fo_got="$(fo_cell "$HOOK" "$ML_SHIM:")"
[ "$_fo_got" = "allow:1:NOKEY" ] && ok "MARK LINE fail-open: awk failing inside dg_mark_scan allows the rows=34 brief and writes its row with NO mark key ($_fo_got)" \
  || bad "MARK LINE fail-open: expected 'allow:1:NOKEY', got '$_fo_got'"
# (m4) fail-closed: a scan failure denies. Killed by cell fail-open alone; fo-ctl does not move.
_fo_anchor='DG_MARK_OUT="$(printf '"'"'%s\n'"'"' "$PROMPT" | dg_mark_scan 2>/dev/null || true)"'
_fo_n="$(grep -cxF -- "$_fo_anchor" "$HOOK")" || _fo_n=0
if [ "$_fo_n" != 1 ]; then bad "MARK LINE MUTANT fail-closed anchor matched $_fo_n lines, expected 1"
else
  _fo_g="$(mk_hooks_copy ml-failclosed)"
  A="$_fo_anchor" R='DG_MARK_OUT="$(printf '"'"'%s\n'"'"' "$PROMPT" | dg_mark_scan 2>/dev/null)" || dg_deny "AI/DLC dispatch guard: the --mark scan failed."' \
    awk '$0 == ENVIRON["A"] { print ENVIRON["R"]; next } { print }' "$HOOK" > "$_fo_g"
  if cmp -s "$HOOK" "$_fo_g" || ! bash -n "$_fo_g" 2>/dev/null; then bad "MARK LINE MUTANT fail-closed DID NOT APPLY"
  else
    _fo_m="$(fo_cell "$_fo_g" "$ML_SHIM:"):$(fo_cell "$_fo_g" "")"
    [ "$_fo_m" = "deny:0:-:deny:0:-" ] && ok "MARK LINE MUTANT fail-closed killed: a failed scan denies the dispatch -- cell fail-open alone catches it (fo-ctl unchanged)" \
      || bad "MARK LINE MUTANT fail-closed: got '$_fo_m', expected 'deny:0:-:deny:0:-'"
  fi
fi

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

# 14w. A FAILED TAIL WRITE FAILS OPEN. The write is made to fail PART-WAY with a file-size limit
# (SIGXFSZ ignored, so `tail` gets EFBIG and exits non-zero) on a transcript that HOLDS when read
# whole: the rejection sits in the first records and Bash padding, which releases nothing, pushes
# the file past the limit. The partial file therefore still carries the rejection, so a guard
# that greps after a failed write denies -- an EMPTY failed write could not tell the two apart.
CAPPAD="$CAPDIR/pad.jsonl"
{ cat "$CAPDIR/a.jsonl"; _i=0
  while [ "$_i" -lt 40 ]; do t_use "p$_i" Bash "pad $_i" "true"; t_res "p$_i" "padding output line $_i" false; _i=$((_i+1)); done
} > "$CAPPAD"
CAP_LIM_KB=4
cap_lim() { # cap_lim <script> <transcript> <description> -> decision or empty, under the size limit
  ( trap '' XFSZ; ulimit -f "$CAP_LIM_KB" || exit 3
    printf '%s' "$(capj "$2" "$3")" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$1" 2>/dev/null ) \
    | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null
}
_lt="$WORK/cap-limtail.out"
( trap '' XFSZ; ulimit -f "$CAP_LIM_KB" && tail -c 1048576 "$CAPPAD" > "$_lt" ) 2>/dev/null && _lt_rc=0 || _lt_rc=$?
if [ "$_lt_rc" -ne 0 ] && [ -s "$_lt" ] && grep -qF 'Concurrent subagent limit reached' "$_lt" \
   && [ "$(wc -c < "$_lt")" -lt "$(wc -c < "$CAPPAD")" ]; then
  ok "14w precondition: under the limit \`tail\` exits $_lt_rc with a PARTIAL file that still holds the rejection"
else
  bad "14w FIXTURE BROKEN: the size limit did not produce a failed, partial, rejection-bearing tail (rc=$_lt_rc) -- 14w asserts nothing"
fi
[ "$(cap_lim "$CAPCTL" "$CAPDIR/a.jsonl" "Party seat 7")" = deny ] \
  && ok "14w CONTROL: under the same limit an unmutated copy still denies 14a (its tail fits), so the limit disturbs nothing else" \
  || bad "14w CONTROL is dead -- the limit itself changes the guard's answer, so 14w's allow is unearned"
expect_deny "$(capout "$CAPPAD" "Party seat 7")" "14w' the padded transcript, written whole, HOLDS"
_cl="$(cap_lim "$HOOK" "$CAPPAD" "Party seat 7")"
[ -z "$_cl" ] && ok "14w the same transcript, its tail write failing part-way -> allowed (fail open)" \
  || bad "14w a failed tail write -> expected NO decision, got '$_cl'"
_m="$WORK/guard-cap-notailgate.sh"
if sed 's/^    if tail -c \(.*\) 2>\/dev\/null \\$/    tail -c \1 2>\/dev\/null; if true \\/' "$HOOK" > "$_m" \
   && ! cmp -s "$HOOK" "$_m" && bash -n "$_m" 2>/dev/null; then
  [ "$(cap_lim "$_m" "$CAPPAD" "Party seat 7")" = deny ] \
    && ok "CAP MUTANT notailgate killed: a grep after a failed tail write holds on the partial file (14w)" \
    || bad "CAP MUTANT notailgate SURVIVED: dropping the write's && binding still fails open (14w)"
else
  bad "CAP MUTANT notailgate DID NOT APPLY (sed failed, matched nothing, or did not parse)"
fi

# 14h. `--hold-status [<description>] --transcript <path>` answers from the SAME computation the
# PreToolUse arm uses (dg_hold_compute): 0 no hold, 1 a hold is live, 2 cannot tell. Cells differ from
# the live-hold cell in ONE input each: b.jsonl (a launch released it), a missing transcript, a
# different description. The PreToolUse path is re-asserted beside them: 14a still denies.
hs() { bash "$HOOK" --hold-status "$@" >/dev/null 2>&1; echo $?; }
[ "$(hs --transcript "$CAPDIR/a.jsonl")" = 1 ] && ok "14h hold-status, a live hold, any description -> exit 1" \
  || bad "14h hold-status on a seeded live hold did not exit 1"
[ "$(hs "Party seat 7" --transcript "$CAPDIR/a.jsonl")" = 1 ] && ok "14h hold-status, a live hold for the description -> exit 1" \
  || bad "14h hold-status on a seeded live hold for its description did not exit 1"
[ "$(hs "Party seat 9" --transcript "$CAPDIR/a.jsonl")" = 0 ] && ok "14h hold-status, a hold for a different description -> exit 0" \
  || bad "14h hold-status for a description with no hold did not exit 0"
[ "$(hs --transcript "$CAPDIR/b.jsonl")" = 0 ] && ok "14h hold-status, no hold (a launch released it) -> exit 0" \
  || bad "14h hold-status with no live hold did not exit 0"
[ "$(hs --transcript "$CAPDIR/c.jsonl")" = 0 ] && ok "14h hold-status, no hold (an agent exited) -> exit 0" \
  || bad "14h hold-status after an agent exit did not exit 0"
[ "$(hs --transcript "$CAPDIR/no-such-transcript.jsonl")" = 2 ] && ok "14h hold-status, an unreadable transcript -> exit 2" \
  || bad "14h hold-status on an unreadable transcript did not exit 2"
[ "$(hs)" = 2 ] && ok "14h hold-status, no transcript given -> exit 2" || bad "14h hold-status with no transcript did not exit 2"
[ "$(AI_DLC_HOLD_TRANSCRIPT="$CAPDIR/a.jsonl" hs)" = 1 ] && ok "14h hold-status takes the transcript from AI_DLC_HOLD_TRANSCRIPT" \
  || bad "14h hold-status did not read AI_DLC_HOLD_TRANSCRIPT"
expect_deny "$(capout "$CAPDIR/a.jsonl" "Party seat 7")" "14h PreToolUse path after the refactor: a held re-send"

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
# The shardable set built LAZILY for arm 2, only when the CURRENT brief is invalid, as THE SHARD
# DENY builds it. An adjudicator brief carries no invalid line, so the set is one blank and clause
# 2 never fires. The replacement keeps `_dg_shardable` SET, so under `set -u` the copy runs rather
# than aborting (which would also read as allow); 15a's deny on the same copy proves it ran.
adj_kill lazyset '/clause 2 would never fire\.$/{n;s/^  dg_shardable_set$/  _dg_shardable=" "; case "${SPAWN_SHARD:-}" in invalid-exception) dg_shardable_set ;; esac/;}' \
  "$W5" allow "a shardable set built only for an invalid current line leaves the waiver arm an empty set (15e)"
[ "$(adj_mut "$WORK/guard-adj-lazyset.sh" "$W1")" = deny ] \
  && ok "  and the lazyset copy still denies 15a, so it ran (clause 1 is untouched)" \
  || bad "  the lazyset copy does not deny 15a -- it did not run, and its kill is unearned"

# 15w. A FAILED KEY PRODUCER FAILS OPEN. 15a's world plus one ledger row whose tool_use_id is a
# NUMBER: the guard's `"K\t" + .tool_use_id` cannot add a string and a number. It is the LAST row
# because jq 1.8.1 exits 5 only when the failing input is the last one -- mid-stream it exits 0 and
# drops that row's keys silently, which no status can see. Every earlier row still keys, so the
# file is non-empty and only the recorded status can make the arm stand down. 15a is the control:
# the same world without the row denies.
# An ALLOWED drive appends its own ledger row after this arm runs, which would push the numeric row
# off the end, so every drive gets a FRESH world and asserts the row is last before it runs.
numid_world() { # numid_world <name> -> project dir
  local p; p="$(mkworld "$1" 317)"; cat "$WAIVER_SRC" >> "$p/docs/escalations/pending.md"
  printf '%s\n' '{"v":1,"sprint":317,"name":"s317-numid","role":"dev","tool_use_id":42,"shard":null}' \
    >> "$p/_bmad-output/spawn-ledger.jsonl"
  printf '%s\n' "$p"
}
numid_last() { [ "$(tail -1 "$1/_bmad-output/spawn-ledger.jsonl" | jq -r '.tool_use_id | type' 2>/dev/null)" = number ]; }
W11="$(numid_world numid)"
# PRECONDITION: this host's jq must actually FAIL on the seed, or 15w's allow is unearned. The
# expression is the guard's own key term; a jq that exits 0 here never reaches the fail-open path.
if jq -Rr 'fromjson? | select(type == "object") | "K\t" + .tool_use_id' \
     "$W11/_bmad-output/spawn-ledger.jsonl" >/dev/null 2>&1; then
  bad "15w FIXTURE BROKEN: this jq exits 0 on a final numeric tool_use_id row, so the producer never fails and 15w asserts nothing"
else
  ok "15w precondition: the key term exits non-zero on the seeded ledger's final numeric row"
fi
if numid_last "$W11"; then
  expect_quiet "$(adj "$W11")" "15w the 15a waiver, the key producer failing on a numeric tool_use_id -> fail open"
else bad "15w FIXTURE BROKEN: the numeric tool_use_id row is not the ledger's last row"; fi
W12="$(numid_world numid-mut)"
if numid_last "$W12"; then
  adj_kill nokok 's/^        if (rc < 0 || nk == 0 || kok != 1) dead = 1$/        if (rc < 0 || nk == 0) dead = 1/' \
    "$W12" deny "dropping the producer status judges partial keys and denies (15w)"
else bad "15w FIXTURE BROKEN: the mutant world's numeric row is not the ledger's last row"; fi

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

# 15q. THE OPERATOR-FREE REMEDY (BL-842). An invalid-exception row V is covered with NO pending.md
# entry when a LATER row R of its sprint and role, that RAN (joined in subagent-context.jsonl) and
# carries a real `i/N` shard, names V on a `remediates:` brief line. The guard does not decide that:
# it asks validate-spawn-ledger.sh --remediated-keys, located by walking up from the hook's own
# directory, and reads any failure of that call as an EMPTY set (deny stands, one could-not-run line).
# R is written by the REAL guard from a real brief, never hand-seeded; V is hand-seeded because a
# current guard refuses an invented exception (THE SHARD DENY) and never writes one.
REM_ROOT="$(cd "$(dirname "$HOOK")/../.." && pwd)"
VSL=""; for _c in "$REM_ROOT/core/scripts/validate-spawn-ledger.sh" "$REM_ROOT/scripts/ai-dlc/validate-spawn-ledger.sh"; do
  [ -f "$_c" ] && { VSL="$_c"; break; }; done
VGA=""; for _c in "$REM_ROOT/core/scripts/validate-gate-adjudication.sh" "$REM_ROOT/scripts/ai-dlc/validate-gate-adjudication.sh"; do
  [ -f "$_c" ] && { VGA="$_c"; break; }; done
[ -n "$VSL" ] && echo "HERMETIC-CONSUMED $VSL" || bad "15q FIXTURE BROKEN: validate-spawn-ledger.sh not found beside $HOOK"
[ -n "$VGA" ] && echo "HERMETIC-CONSUMED $VGA" || bad "15q FIXTURE BROKEN: validate-gate-adjudication.sh not found beside $HOOK"
REM_V=toolu_01REMINV000000000000001
REM_R=toolu_01REMR00000000000000001
# remdisp <role> <tool_use_id> <brief line>... -> an Agent dispatch of <role> carrying the lines,
# with the PreToolUse tool_use_id the guard records (and the probe joins on).
remdisp() {
  local r="$1" t="$2" p; shift 2
  p="Your operating contract is \`.claude/team-roles/$r.md\`. Read it first."
  for _l in "$@"; do p="$p"$'\n'"$_l"; done
  jq -nc --arg p "$p"$'\n'"Do the work." --arg t "$t" --arg n "s317-$r-${t#toolu_01}" \
    '{tool_name:"Agent",tool_use_id:$t,tool_input:{name:$n,prompt:$p}}'
}
# ran <project> <tool_use_id> <role> -> one subagent-context.jsonl row, the shape SubagentStop writes.
ran() {
  local m; m="$(jq -r --arg r "$3" '.aiDlcModels[.aiDlcRoles[$r].model // ""] // ""' "$1/.claude/settings.json")"
  jq -nc --arg t "$2" --arg r "$3" --arg m "$m" \
    '{v:3,ts:"2026-10-10T23:00:00Z",sprint:317,agent_id:("a" + $t),model:$m,role:$r,tool_use_id:$t}' \
    >> "$1/_bmad-output/subagent-context.jsonl"
}
# rem_world <name> <key R names> [ran: 1|0] -> project dir: the 15e row V, then the real guard's R.
rem_world() {
  local p; p="$(mkworld "$1" 317)"
  ledrow 317 remediator remediator "$REM_V" invalid-exception >> "$p/_bmad-output/spawn-ledger.jsonl"
  raw "$p" "$(remdisp remediator "$REM_R" 'shard: 1/2 rem-fix-a' "remediates: $2")" >/dev/null
  [ "${3:-1}" = 1 ] && ran "$p" "$REM_R" remediator
  printf '%s\n' "$p"
}
last_field() { tail -1 "$1/_bmad-output/spawn-ledger.jsonl" | jq -r "$2 | tostring" 2>/dev/null; }

# THE GUARD WRITES THE FIELD FROM THE BRIEF. One line -> `remediates`; two -> `remediates_invalid`.
WRA="$(rem_world allow "$REM_V")"
[ "$(last_field "$WRA" .tool_use_id):$(last_field "$WRA" .remediates):$(last_field "$WRA" .shard)" = "$REM_R:$REM_V:1/2 rem-fix-a" ] \
  && ok "15q the guard writes R's row: tool_use_id $REM_R, remediates $REM_V, shard 1/2 rem-fix-a" \
  || bad "15q R's row is '$(tail -1 "$WRA/_bmad-output/spawn-ledger.jsonl" | cut -c1-300)'; expected remediates=$REM_V (the R dispatch may have been denied)"
WR2="$(mkworld remtwo 317)"
raw "$WR2" "$(remdisp remediator toolu_01REMTWO000000000000001 'shard: 1/2 rem-fix-a' "remediates: $REM_V" 'remediates: toolu_01DEVROW000000000000001')" >/dev/null
[ "$(last_field "$WR2" .tool_use_id):$(last_field "$WR2" .remediates_invalid):$(last_field "$WR2" 'has("remediates")')" = "toolu_01REMTWO000000000000001:multiple:false" ] \
  && ok "15q' two remediates: lines -> remediates_invalid=multiple and NO remediates field" \
  || bad "15q' two remediates: lines wrote '$(tail -1 "$WR2/_bmad-output/spawn-ledger.jsonl" | cut -c1-300)'"

# ALLOW / DENY TWINS, one property apart: the key R names.
expect_quiet "$(adj "$WRA")" "15r an invalid-exception row remediated by a later run R naming it, pending.md EMPTY"
[ ! -s "$WRA/docs/escalations/pending.md" ] && ok "  and pending.md holds no entry (0 bytes)" || bad "  15r's pending.md is not empty"
WRD="$(rem_world deny toolu_01NOTTHEROW00000000000001)"
WRD_OUT="$(adj "$WRD")"
expect_deny "$WRD_OUT" "15r' its twin: R names a DIFFERENT id"
grep -qF "$REM_V" <<<"$WRD_OUT" && ok "  and the reason names V ($REM_V)" || bad "  15r' deny does not name V"
grep -qF 'could not run' <<<"$WRD_OUT" && bad "  15r' says the predicate could not run -- it must have run and found nothing" \
  || ok "  and the predicate ran (no could-not-run line)"
WRP2="$(rem_world pending "$REM_V" 0)"
expect_deny "$(adj "$WRP2")" "15r'' R names V but never RAN (no subagent-context row)"
# THE NAME KEY: V carries a tool_use_id AND a dispatch name distinct from its role; R names it by
# the NAME. The guard keys the uncovered row by tool_use_id, so this allows only when the
# validator's REMEDIATED line reports V by that same tool_use_id.
WRN2="$(mkworld remname 317)"
ledrow 317 s317-rem-inv remediator "$REM_V" invalid-exception >> "$WRN2/_bmad-output/spawn-ledger.jsonl"
raw "$WRN2" "$(remdisp remediator "$REM_R" 'shard: 1/2 rem-fix-a' 'remediates: s317-rem-inv')" >/dev/null
ran "$WRN2" "$REM_R" remediator
expect_quiet "$(adj "$WRN2")" "15r''' V named by its distinct dispatch NAME on R's remediates: line"

# THE PREDICATE CANNOT RUN -> DENY, never skip. Guard copies sit in a tree where the walk-up finds a
# validator we place: the real one (control, must ALLOW 15r) or a stub exiting 2.
rem_tree() { # rem_tree <tag> <validator source> -> path of a guard copy whose walk-up finds <source>
  local d; d="$(mktemp -d "$WORK/remtree-$1.XXXXXX")" || return 1
  mkdir -p "$d/core/hooks" "$d/core/scripts" && cp -R "$HOOKS_SRC/." "$d/core/hooks/" \
    && cp "$2" "$d/core/scripts/validate-spawn-ledger.sh" || return 1
  printf '%s/core/hooks/%s' "$d" "$(basename "$HOOK")"
}
REM_CTL="$(rem_tree control "$VSL")"
[ -n "$REM_CTL" ] && [ -z "$(adj_mut "$REM_CTL" "$WRA")" ] && [ "$(adj_mut "$REM_CTL" "$WRD")" = deny ] \
  && ok "REM MUTANT CONTROL: an unmutated tree copy ALLOWS 15r and denies 15r' (its walk-up found the validator)" \
  || bad "REM MUTANT CONTROL is dead: the tree copy does not allow 15r, so every REM verdict below is unearned"
printf '#!/usr/bin/env bash\nexit 2\n' > "$WORK/q0-vsl-exit2.sh"
REM_X2="$(rem_tree exit2 "$WORK/q0-vsl-exit2.sh")"
X2_OUT="$(printf '%s' "$(adjj)" | CLAUDE_PROJECT_DIR="$WRA" bash "$REM_X2" 2>/dev/null)"
expect_deny "$X2_OUT" "15s the 15r world, the validator exiting 2"
grep -qF 'The remediation predicate could not run, so no row was counted remediated: validate-spawn-ledger.sh --remediated-keys exited rc 2' <<<"$X2_OUT" \
  && grep -qF "$REM_V" <<<"$X2_OUT" \
  && ok "  and the reason carries the could-not-run line (rc 2) and names V" \
  || bad "  15s deny lacks the could-not-run line or V: '$(printf '%s' "$X2_OUT" | cut -c1-300)'"
# MUTANT: the coverage path deleted (no class matches), the call still made. Built in a tree copy so
# the walk-up still finds the real validator; a kill with the could-not-run line would be unearned.
REM_M="$(rem_tree nocover "$VSL")"
_ra_n="$(grep -cF "| sed -n 's/^REMEDIATED" "$HOOK")" || _ra_n=0
_ra="$(grep -F "| sed -n 's/^REMEDIATED" "$HOOK")"
_rr="${_ra/$'\t'shard$'\t'/$'\t'NOSUCH$'\t'}"
if [ -n "$REM_M" ] && [ "$_ra_n" = 1 ] && [ "$_rr" != "$_ra" ] \
   && A="$_ra" R="$_rr" awk '$0 == ENVIRON["A"] { print ENVIRON["R"]; next } { print }' "$HOOK" > "$REM_M" \
   && ! cmp -s "$HOOK" "$REM_M" && bash -n "$REM_M" 2>/dev/null; then
  RM_OUT="$(printf '%s' "$(adjj)" | CLAUDE_PROJECT_DIR="$WRA" bash "$REM_M" 2>/dev/null)"
  if [ "$(jq -r '.hookSpecificOutput.permissionDecision // empty' <<<"$RM_OUT" 2>/dev/null)" = deny ] \
     && ! grep -qF 'could not run' <<<"$RM_OUT"; then
    ok "REM MUTANT nocover killed: with the ledger-coverage path deleted, 15r is DENIED though the predicate ran"
  else bad "REM MUTANT nocover SURVIVED (or was denied only because the predicate could not run): '$(printf '%s' "$RM_OUT" | cut -c1-200)'"; fi
else bad "REM MUTANT nocover DID NOT APPLY (sed failed, matched nothing, or did not parse)"; fi

# 15t. NO PATH REQUIRES AN OPERATOR ENTRY (BL-842's owed item, realised structurally). One world
# whose ONLY Check 22 violations are three remediated rows, one per remediable class (cite: Rule
# 19(b) uncited; shard: S3 invented exception; cover: S4 one-cross gap), and whose pending.md is
# EMPTY. In it the guard allows the implementation adjudicator, validate-spawn-ledger.sh exits 0
# printing a REMEDIATED line per pair and remediated=3, and validate-gate-adjudication.sh --series
# exits 0 over a 22 FAIL -> PASS series carrying the lead's resolution record. Every row is written
# by the REAL guard from a real brief, the epoch row in an earlier sprint FIRST; each V is then
# edited in place to its violation (a current guard refuses all three at dispatch, so none can be
# produced there), keeping every other field the guard wrote.
NOP="$WORK/waiver-nooperator"
mkdir -p "$NOP/.claude" "$NOP/_bmad-output/gate-adjudication" "$NOP/_bmad-output/planning-artifacts/s317" "$NOP/docs/escalations"
cp -R "$CONSUMER/.claude/team-roles" "$NOP/.claude/"
cp "$CONSUMER/.claude/.ai-dlc-version" "$CONSUMER/.claude/settings.json" "$NOP/.claude/"
: > "$NOP/docs/escalations/pending.md"
printf -- '- sprint_id: 316\n' > "$NOP/_bmad-output/pipeline-snapshot.md"
raw "$NOP" "$(remdisp dev toolu_01NOPEPOCH00000000000001)" >/dev/null
printf -- '- sprint_id: 317\n' > "$NOP/_bmad-output/pipeline-snapshot.md"
NV_S=toolu_01REMINV000000000000001; NR_S=toolu_01REMR00000000000000001
NV_C=toolu_01CITV000000000000000001; NR_C=toolu_01CITR000000000000000001
NV_X=toolu_01COVV000000000000000001; NR_X=toolu_01COVR000000000000000001
raw "$NOP" "$(remdisp remediator "$NV_S" 'shard: 1/2 rem-fix-a')" >/dev/null
raw "$NOP" "$(remdisp analyst "$NV_C" 'shard: 1/1 analysis')" >/dev/null
raw "$NOP" "$(remdisp analyst "$NV_X" 'shard: cross/3 g1/1 1,2,3')" >/dev/null
raw "$NOP" "$(remdisp remediator "$NR_S" 'shard: 1/2 rem-fix-a' "remediates: $NV_S")" >/dev/null
raw "$NOP" "$(remdisp analyst "$NR_C" 'shard: 1/1 analysis' "remediates: $NV_C")" >/dev/null
raw "$NOP" "$(remdisp analyst "$NR_X" 'shard: cross/3 g1/1 1,2,3' "remediates: $NV_X")" >/dev/null
NOP_L="$NOP/_bmad-output/spawn-ledger.jsonl"
jq -c --arg s "$NV_S" --arg c "$NV_C" --arg x "$NV_X" '
  if .tool_use_id == $s then .shard = "invalid-exception" | .shard_raw = "none (serial cross-section remediator)"
  elif .tool_use_id == $c then .role_contract_cited = false | .contract_via = null
  elif .tool_use_id == $x then .shard = "cross/3 g1/1 1,2"
  else . end' "$NOP_L" > "$NOP_L.new" && mv "$NOP_L.new" "$NOP_L"
for _t in toolu_01NOPEPOCH00000000000001:dev "$NV_S:remediator" "$NV_C:analyst" "$NV_X:analyst" \
          "$NR_S:remediator" "$NR_C:analyst" "$NR_X:analyst"; do ran "$NOP" "${_t%%:*}" "${_t#*:}"; done
[ "$(jq -sr 'map(.tool_use_id) | join(" ")' "$NOP_L" 2>/dev/null)" = "toolu_01NOPEPOCH00000000000001 $NV_S $NV_C $NV_X $NR_S $NR_C $NR_X" ] \
  && ok "15t world: seven guard-written rows in ledger order (epoch, three V, three R)" \
  || bad "15t FIXTURE BROKEN: the ledger is '$(jq -sr 'map(.tool_use_id // "?") | join(" ")' "$NOP_L" 2>/dev/null)' -- a dispatch was denied or misordered"
expect_quiet "$(adj "$NOP")" "15t the guard: an implementation adjudicator over a sprint whose only violations are remediated"
NOP_VO="$(bash "$VSL" --ledger "$NOP_L" --sprint 317 --settings "$NOP/.claude/settings.json" \
  --probe "$NOP/_bmad-output/subagent-context.jsonl" --context "$NOP/_bmad-output/subagent-context.jsonl" 2>&1)"; NOP_VR=$?
[ "$NOP_VR" = 0 ] && grep -qF "REMEDIATED: $NV_S by $NR_S (shard)" <<<"$NOP_VO" \
  && grep -qF "REMEDIATED: $NV_C by $NR_C (cite)" <<<"$NOP_VO" && grep -qF "REMEDIATED: $NV_X by $NR_X (cover)" <<<"$NOP_VO" \
  && grep -qE '^COUNTS:' <<<"$NOP_VO" && grep -qE 'remediation \(classes: cite shard cover\): remediated=3 pending-remedy=0' <<<"$NOP_VO" \
  && ok "15t the validator: exit 0, one REMEDIATED line per class, remediated=3" \
  || bad "15t the validator exited $NOP_VR: '$(printf '%s' "$NOP_VO" | tr '\n' ' ' | cut -c1-600)'"
# THE SAME LEDGER WITHOUT R's RUN: every V is still a violation, so exit 1 -- the 15t exit 0 is
# the remedies' doing, not a validator that judges nothing.
grep -vF "$NR_S" "$NOP/_bmad-output/subagent-context.jsonl" | grep -vF "$NR_C" | grep -vF "$NR_X" > "$WORK/q0-nop-norun.jsonl"
bash "$VSL" --ledger "$NOP_L" --sprint 317 --settings "$NOP/.claude/settings.json" \
  --probe "$WORK/q0-nop-norun.jsonl" --context "$WORK/q0-nop-norun.jsonl" >/dev/null 2>&1; _nr=$?
[ "$_nr" = 1 ] && ok "  its control: the same ledger with no R joined exits 1" || bad "  15t control: no R joined exited $_nr, expected 1"
cat > "$NOP/_bmad-output/planning-artifacts/s317/gate-implementation-resolution-p1.md" <<NOPEOF
# Gate resolution record — implementation gate, pass 1

## Check 22 — spawn ledger

- disposition: remediated (classes shard, cite, cover); no escalation entry
- edit: _bmad-output/spawn-ledger.jsonl — $NR_S remediates: $NV_S; $NR_C remediates: $NV_C; $NR_X remediates: $NV_X
- derivation:
  \`\`\`
$(printf '%s\n' "$NOP_VO" | grep -E '^(REMEDIATED|COUNTS):|remediation \(classes:' | sed 's/^/  /')
  \`\`\`
NOPEOF
for _p in "implementation-20261010T230257Z FAIL 2026-10-10T23:02:57Z" "implementation-20261010T234500Z PASS 2026-10-10T23:45:00Z"; do
  set -- $_p
  jq -n --arg n "$1" --arg v "$2" --arg g "$3" '{schema_id:"GATE_ADJUDICATION_VERDICT v1",gate_type:"implementation",
    gate_series_id:"implementation-gate-20261010T2300Z",gate_nonce:$n,generated_at:$g,adjudicator_agent_id:("agent-" + $n),
    catalog:"core",verdicts:[{check_id:"22",verdict:$v,evidence:"validate-spawn-ledger.sh --sprint 317"}]}' \
    > "$NOP/_bmad-output/gate-adjudication/$1.verdict.json"
done
set --
bash "$VGA" --series "$NOP/_bmad-output/gate-adjudication" >/dev/null 2>&1; _sr=$?
[ "$_sr" = 0 ] && ok "15t --series: 22 FAIL -> PASS with the resolution record exits 0" || bad "15t --series exited $_sr, expected 0"
mv "$NOP/_bmad-output/planning-artifacts/s317/gate-implementation-resolution-p1.md" "$WORK/q0-nop-record.md"
bash "$VGA" --series "$NOP/_bmad-output/gate-adjudication" >/dev/null 2>&1; _sr=$?
[ "$_sr" = 1 ] && ok "  its control: the same series without the record exits 1" || bad "  15t --series without the record exited $_sr, expected 1"
[ ! -s "$NOP/docs/escalations/pending.md" ] && ok "15t pending.md is EMPTY throughout: no path above required an operator entry" \
  || bad "15t pending.md was written"
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

# --- 16. WHO ISSUED THE SPAWN: parent_agent_id --------------------------------------------------
# A spawn made from inside a teammate carries the payload `agent_id`; the lead's carries none. The
# row records it as `parent_agent_id`, the EMPTY STRING for the lead and never null, so a join that
# counts writers can attribute a nested writer to the agent that dispatched it. The subject shape is
# the reference consumer's own nested call: `subagent_type: general-purpose`, no `name`, no role
# citation, a role with no team-roles file, issued by a requirements teammate.
#   16a a teammate-issued spawn writes a row at all, and is not denied
#   16b that row carries the teammate's agent_id
#   16c the same call from the lead writes `parent_agent_id: ""` -- the key present, a string, empty
PA_ID="a1c69096c184098d6"
PA_LEAD="$(jq -nc '{tool_name:"Agent",tool_use_id:"toolu_pa_lead",transcript_path:"/nonexistent",
  tool_input:{description:"PRD rubric walker",subagent_type:"general-purpose",prompt:"Walk the PRD rubric.",run_in_background:true}}')"
PA_MATE="$(printf '%s' "$PA_LEAD" | jq -c --arg a "$PA_ID" '.agent_id = $a | .tool_use_id = "toolu_pa_mate"')"
# pa_cell <guard> <json> -> "<rows>|<decision>|<parent_agent_id as JSON>" for one drive on an empty ledger.
pa_cell() {
  local out n p
  rm -f "$LEDGER"
  out="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$1" 2>/dev/null \
    | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)"
  n="$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')"
  p="$(tail -1 "$LEDGER" 2>/dev/null | jq -c 'if has("parent_agent_id") then .parent_agent_id else "ABSENT" end' 2>/dev/null)"
  printf '%s|%s|%s' "${n:-0}" "${out:-none}" "${p:-NOROW}"
}
pa_vec() { printf '%s %s' "$(pa_cell "$1" "$PA_MATE")" "$(pa_cell "$1" "$PA_LEAD")"; }
PA_WANT="1|none|\"$PA_ID\" 1|none|\"\""
PA_GOT="$(pa_vec "$HOOK")"
PA_M="${PA_GOT%% *}"; PA_L="${PA_GOT#* }"
case "$PA_M" in 1\|none\|*) ok "16a a teammate-issued general-purpose spawn writes exactly one row and is not denied" ;;
  *) bad "16a a teammate-issued spawn produced '$PA_M' (rows|decision|parent), expected one row and no decision" ;; esac
[ "${PA_M##*|}" = "\"$PA_ID\"" ] && ok "16b the teammate row carries parent_agent_id = the payload agent_id" \
  || bad "16b the teammate row carries parent_agent_id ${PA_M##*|}, expected \"$PA_ID\""
[ "$PA_L" = '1|none|""' ] && ok "16c the lead row carries parent_agent_id \"\" (present, a string, empty)" \
  || bad "16c the lead row produced '$PA_L', expected '1|none|\"\"'"
# Each mutant is scored on the EXACT two-cell vector, so one that moves a cell it does not own shows.
# pa_mut <tag> <sed-expr> <expected-vector> <label>
pa_mut() {
  local m="$WORK/guard-pa-$1.sh" got
  sed "$2" "$HOOK" > "$m"
  if cmp -s "$HOOK" "$m"; then bad "PA MUTANT $1 matched nothing (cmp -s guard)"; return; fi
  bash -n "$m" 2>/dev/null || { bad "PA MUTANT $1 does not parse -- its silence would not be the mutation"; return; }
  got="$(pa_vec "$m")"
  if [ "$got" = "$3" ]; then ok "PA MUTANT $1 killed: $4"
  else bad "PA MUTANT $1 scored '$got', expected '$3' ($4)"; fi
}
# 16a: the guard returns before the append for a call made from inside a subagent.
pa_mut earlyexit 's/^mkdir -p "\$SPAWN_STATE_DIR" 2>\/dev\/null || true$/[ -n "$DG_AGENT_ID" ] \&\& exit 0; &/' \
  "0|none|NOROW 1|none|\"\"" "an exit before the append for an agent_id caller leaves the nested spawn unrecorded"
# 16b: the field is written but never from the payload.
pa_mut noparent 's/--arg parent "\${DG_AGENT_ID:-}"/--arg parent ""/' \
  "1|none|\"\" 1|none|\"\"" "a field that never reads agent_id reads every nested spawn as the lead's"
# 16c: the lead is written as null, which is how a row from an older guard would read.
pa_mut leadnull 's/^     parent_agent_id: \$parent,$/     parent_agent_id: (if $parent == "" then null else $parent end),/' \
  "1|none|\"$PA_ID\" 1|none|null" "a null lead value is indistinguishable from a row that never asked"
# 16d/16e A ROLE-LESS spawn: `subagent_type: Explore` (the role pattern rejects a capital) and one
# carrying no `subagent_type`. From inside a teammate each is RECORDED with `role: ""` and its
# issuer; from the lead neither writes a row, which is the state the role-less arm above asserts.
# rl_cell <guard> <json> -> "<rows>|<decision>|<role>|<parent>" on an empty ledger.
rl_cell() {
  local out n r
  rm -f "$LEDGER"
  out="$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$CONSUMER" bash "$1" 2>/dev/null \
    | jq -r '.hookSpecificOutput.permissionDecision // empty' 2>/dev/null)"
  n="$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')"
  r="$(tail -1 "$LEDGER" 2>/dev/null | jq -r '"\(.role | tojson)|\(.parent_agent_id | tojson)"' 2>/dev/null)"
  printf '%s|%s|%s' "${n:-0}" "${out:-none}" "${r:-NOROW}"
}
RL_EXL="$(printf '%s' "$PA_LEAD" | jq -c '.tool_input.subagent_type = "Explore"')"
RL_EXM="$(printf '%s' "$RL_EXL" | jq -c --arg a "$PA_ID" '.agent_id = $a')"
RL_NTM="$(printf '%s' "$PA_MATE" | jq -c 'del(.tool_input.subagent_type)')"
rl_vec() { printf '%s %s %s' "$(rl_cell "$1" "$RL_EXM")" "$(rl_cell "$1" "$RL_NTM")" "$(rl_cell "$1" "$RL_EXL")"; }
RL_WANT="1|none|\"\"|\"$PA_ID\" 1|none|\"\"|\"$PA_ID\" 0|none|NOROW"
RL_GOT="$(rl_vec "$HOOK")"
case "$RL_GOT" in "1|none|\"\"|\"$PA_ID\" 1|none|\"\"|\"$PA_ID\" "*)
  ok "16d a teammate's Explore and type-less spawns are each recorded, role \"\", issuer named, no decision" ;;
  *) bad "16d role-less teammate spawns produced '$RL_GOT', expected the first two cells of '$RL_WANT'" ;; esac
[ "${RL_GOT##* }" = "0|none|NOROW" ] && ok "16e the lead's Explore spawn writes no row and gets no decision" \
  || bad "16e the lead's Explore spawn produced '${RL_GOT##* }', expected '0|none|NOROW'"
# rl_mut <tag> <sed-expr> <expected-vector> <label>
rl_mut() {
  local m="$WORK/guard-rl-$1.sh" got
  sed "$2" "$HOOK" > "$m"
  if cmp -s "$HOOK" "$m"; then bad "RL MUTANT $1 matched nothing (cmp -s guard)"; return; fi
  bash -n "$m" 2>/dev/null || { bad "RL MUTANT $1 does not parse"; return; }
  got="$(rl_vec "$m")"
  if [ "$got" = "$3" ]; then ok "RL MUTANT $1 killed: $4"
  else bad "RL MUTANT $1 scored '$got', expected '$3' ($4)"; fi
}
# 16d: the pre-fix exit -- every role-less dispatch leaves, the teammate's too.
rl_mut roleexit "s/^  \[ -n \"\$(printf '%s' \"\$INPUT\" | jq -r '.agent_id \/\/ empty' 2>\/dev\/null || true)\" \] || exit 0$/  exit 0/" \
  "0|none|NOROW 0|none|NOROW 0|none|NOROW" "exiting on an empty role drops a teammate's role-less spawn"
# 16e: the issuer test gone -- the lead's role-less dispatch is recorded too.
rl_mut leadrow "s/^  \[ -n \"\$(printf '%s' \"\$INPUT\" | jq -r '.agent_id \/\/ empty' 2>\/dev\/null || true)\" \] || exit 0$/  :/" \
  "1|none|\"\"|\"$PA_ID\" 1|none|\"\"|\"$PA_ID\" 1|none|\"\"|\"\"" "recording every role-less dispatch writes rows for the lead's utility agents"
[ "$RL_GOT" = "$RL_WANT" ] || bad "16d/e FIXTURE BROKEN: unmutated vector '$RL_GOT' is not '$RL_WANT'"
[ "$PA_GOT" = "$PA_WANT" ] || bad "16 FIXTURE BROKEN: the unmutated vector '$PA_GOT' is not '$PA_WANT', so every PA mutant above was scored against the wrong baseline"

echo
if [ "$fails" -eq 0 ]; then echo "dispatch-model-guard: PASS"; exit 0; fi
echo "dispatch-model-guard: $fails assertion(s) FAILED" >&2
exit 1
