#!/usr/bin/env bash
#
# Drives ai-dlc-dispatch-guard.sh against a seeded layered consumer.
# Both polarities of every branch. Exits non-zero on any failed assertion.
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

# raw <project_dir> <json> -> hook stdout (JSON on deny, empty on allow)
raw() { printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$HOOK" 2>/dev/null; }

decision() {
  if raw "$1" "$2" | grep -q '"permissionDecision": *"deny"'; then echo deny; else echo allow; fi
}

# mkjson <tool> <role|-> [model]   — builds an Agent dispatch binding a role file.
# A `-` role means "no role binding in the prompt".
mkjson() {
  local bind=""
  [ "$2" != "-" ] && bind="Your operating contract is \`.claude/team-roles/$2.md\`. Read it first."
  jq -nc --arg t "$1" --arg p "$bind Do the work." --arg m "${3-}" '
    {tool_name: $t, tool_input: {prompt: $p, name: "teammate-s291-1"}}
    | if $m != "" then .tool_input.model = $m else . end'
}

echo "dispatch-model-guard"

# --- 1. gate-adjudicator with NO model param -> DENY -------------------------
# Not because it would inherit sonnet (the record shows no-param resolving to
# opus), but because the model is UNDETERMINED: the tool contract says
# inherit-from-parent, the record says claude-opus-4-8, and the teammate leaves
# no transcript to settle it. A model nobody can name is not a model anyone chose.
d="$(decision "$CONSUMER" "$(mkjson Agent gate-adjudicator)")"
[ "$d" = deny ] && ok "gate-adjudicator dispatch with no model param → deny (undetermined model)" \
  || bad "no-model gate-adjudicator classified '$d', expected deny — an unnameable model is not a chosen one"

# --- 1b. the deny must NAME the tier to pass (a refusal without a route ------
#     gets the hook turned off)
OUT="$(raw "$CONSUMER" "$(mkjson Agent gate-adjudicator)")"
if printf '%s' "$OUT" | grep -q 'opus' && printf '%s' "$OUT" | grep -q 'model'; then
  ok "deny names the required tier and the param to pass"
else
  bad "deny does not tell the caller what to pass — a refusal without a route gets the hook turned off"
fi

# --- 2. remediator with no param -> DENY ------------------------------------
d="$(decision "$CONSUMER" "$(mkjson Agent remediator)")"
[ "$d" = deny ] && ok "remediator dispatch with no model param → deny" \
  || bad "no-model remediator classified '$d', expected deny"

# --- 3. THE REAL S291 DEFECT: an EXPLICIT wrong tier -> DENY ----------------
# remediator-s291-disc-p1 and -prd-p1 both requested model:'sonnet' against
# remediator.md's opus pin. Certain, measured, and it happened twice — this is
# the strongest defect the A/B found and the one this hook exists for.
d="$(decision "$CONSUMER" "$(mkjson Agent remediator sonnet)")"
[ "$d" = deny ] && ok "remediator EXPLICITLY requested sonnet against an opus pin → deny (the real S291 defect)" \
  || bad "tier mismatch classified '$d', expected deny"

# --- 4. correct tier -> ALLOW (the happy path must not be denied) -----------
d="$(decision "$CONSUMER" "$(mkjson Agent gate-adjudicator opus)")"
[ "$d" = allow ] && ok "gate-adjudicator requested opus against an opus pin → allow" \
  || bad "a CORRECT dispatch was denied — this hook would wedge a live pipeline"

d="$(decision "$CONSUMER" "$(mkjson Agent analyst sonnet)")"
[ "$d" = allow ] && ok "analyst requested sonnet against a sonnet pin → allow" \
  || bad "a correct sonnet dispatch was denied"

# --- 5. tier compare, not string compare ------------------------------------
# The param is an alias ('opus'); the pin is 'claude-opus-4-8[1m]'. A string
# compare would deny every dispatch in existence.
d="$(decision "$CONSUMER" "$(mkjson Agent gate-adjudicator 'claude-opus-4-8[1m]')")"
[ "$d" = allow ] && ok "full model string matching the pin's tier → allow (tier compare, not string)" \
  || bad "full model string denied — the guard is string-comparing"

# --- 6. unpinned role -> ALLOW (documented gap: tea/sm/ux/cis declare nothing)
d="$(decision "$CONSUMER" "$(mkjson Agent tea opus)")"
[ "$d" = allow ] && ok "unpinned role (tea.md) → allow (fail-open: declares no pin)" \
  || bad "unpinned role denied — a role file that declares nothing cannot bind anything"

# --- 7. pins disagreeing on tier -> ALLOW (ambiguous intent, fail-open) ------
d="$(decision "$CONSUMER" "$(mkjson Agent architect sonnet)")"
[ "$d" = allow ] && ok "role whose Personal/Bedrock pins disagree on tier → allow (fail-open)" \
  || bad "ambiguous pin denied — the guard is picking a side it cannot justify"

# --- 8. prose '/model' mention is not a pin ---------------------------------
# dev.md has a line mentioning `/model` with no model string. If that were read
# as a pin the tier would be empty and dev would fail open — so assert the REAL
# pin is what binds: sonnet is allowed, opus is denied.
d="$(decision "$CONSUMER" "$(mkjson Agent dev sonnet)")"
[ "$d" = allow ] && ok "dev.md prose '/model' line ignored; real sonnet pin allows sonnet" \
  || bad "dev.md sonnet dispatch denied — the prose /model line is being read as a pin"
d="$(decision "$CONSUMER" "$(mkjson Agent dev opus)")"
[ "$d" = deny ] && ok "dev.md still denies opus — the real pin binds, not the prose line" \
  || bad "dev.md opus classified '$d', expected deny — dev's pin is not being read at all"

# --- 8b. dev-escalated: model escalation is a ROLE, and its pin is enforced ---
# A story routed with `escalate_model: true` binds dev-escalated.md (opus pin),
# NOT dev.md with a call-site opus override (case 8 proves that override is
# denied). The escalated role's own pin must bind: opus allowed, sonnet denied,
# no-param denied. The sonnet case is the tooth that matters — routing a story to
# the escalated tier but then running it on the cheap model is the exact slip
# escalation invites, and it must not pass silently.
d="$(decision "$CONSUMER" "$(mkjson Agent dev-escalated opus)")"
[ "$d" = allow ] && ok "dev-escalated requested opus against its opus pin → allow (the escalation happy path)" \
  || bad "dev-escalated opus classified '$d', expected allow — the escalated route would wedge"
d="$(decision "$CONSUMER" "$(mkjson Agent dev-escalated sonnet)")"
[ "$d" = deny ] && ok "dev-escalated requested sonnet against its opus pin → deny (escalated route, cheap model)" \
  || bad "dev-escalated sonnet classified '$d', expected deny — the escalated tier is not being enforced"
d="$(decision "$CONSUMER" "$(mkjson Agent dev-escalated)")"
[ "$d" = deny ] && ok "dev-escalated dispatch with no model param → deny (undetermined model)" \
  || bad "no-model dev-escalated classified '$d', expected deny"

# --- 9. no role binding in the prompt -> ALLOW ------------------------------
d="$(decision "$CONSUMER" "$(mkjson Agent - opus)")"
[ "$d" = allow ] && ok "dispatch with no role binding → allow (not ours)" \
  || bad "a non-role dispatch was denied — the guard is over-broad"

# --- 10. non-dispatch tool -> ALLOW ----------------------------------------
d="$(decision "$CONSUMER" "$(jq -nc '{tool_name:"Edit",tool_input:{file_path:"/tmp/x",old_string:"a",new_string:"b"}}')")"
[ "$d" = allow ] && ok "Edit → allow (out of scope)" \
  || bad "the guard fired on a non-dispatch tool"

# --- 11. activation gate: unstamped tree -> total no-op --------------------
d="$(decision "$NOSTAMP" "$(mkjson Agent gate-adjudicator)")"
[ "$d" = allow ] && ok "unstamped tree (not a layered consumer) → allow" \
  || bad "the guard fired outside a layered consumer"

# --- 12. unknown role file -> ALLOW ----------------------------------------
d="$(decision "$CONSUMER" "$(mkjson Agent nonexistent-role)")"
[ "$d" = allow ] && ok "unreadable/unknown role file → allow (fail-open)" \
  || bad "unknown role denied — fail-open is broken"

# --- 13. Task tool is in scope too -----------------------------------------
d="$(decision "$CONSUMER" "$(mkjson Task remediator)")"
[ "$d" = deny ] && ok "Task-tool dispatch is policed like Agent" \
  || bad "Task classified '$d', expected deny — matcher covers Task but the hook does not"

# --- 14. FIXTURE STALENESS: the real core role files must still parse -------
# If a role file's pin line is ever reformatted, this guard silently stops
# binding and every assertion above still passes against the fixture's own
# rendered files. Assert the REAL tree's shape too.
REAL_PIN="$(grep -oE '^- (Personal|Bedrock): `/model [^`]+`' "$SRC_ROLES/gate-adjudicator.md" 2>/dev/null | head -1)"
[ -n "$REAL_PIN" ] && ok "real core gate-adjudicator.md still carries a parseable pin line" \
  || bad "FIXTURE STALE: core/team-roles/gate-adjudicator.md has no '- Personal/Bedrock: \`/model ...\`' line — the guard would silently stop binding"

REAL_PIN="$(grep -oE '^- (Personal|Bedrock): `/model [^`]+`' "$SRC_ROLES/dev-escalated.md" 2>/dev/null | head -1)"
[ -n "$REAL_PIN" ] && ok "real core dev-escalated.md still carries a parseable pin line" \
  || bad "FIXTURE STALE: core/team-roles/dev-escalated.md has no '- Personal/Bedrock: \`/model ...\`' line — the guard would silently stop binding the escalated tier"

echo
if [ "$fails" -eq 0 ]; then echo "dispatch-model-guard: PASS"; exit 0; fi
echo "dispatch-model-guard: $fails assertion(s) FAILED" >&2
exit 1
