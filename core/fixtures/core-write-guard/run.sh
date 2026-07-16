#!/usr/bin/env bash
# core-write-guard/run.sh — drive the REAL ai-dlc-core-guard.sh hook with synthesized
# PreToolUse JSON on stdin and prove the core/override boundary is enforced at edit time.
#
# THE DEFECT THIS EXISTS TO CATCH. Rule 27 forbids a consumer editing a core (upstream-owned)
# file in place, but nothing STOPPED it at the keystroke — the retro gate catches it a whole
# sprint late, and by then /ai-dlc-update has a BOTH-CHANGED-on-core prose merge to untangle.
# This hook denies the write as it happens and routes it to overrides/ or extensions/. The
# assertions below prove it denies core, allows the layer, allows /ai-dlc-setup config fills,
# never touches shell writes, and no-ops in the distribution.
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

# raw <project_dir> <json> -> the hook's stdout (JSON on deny, empty on allow)
raw() { printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$HOOK" 2>/dev/null; }

# decision <project_dir> <json> -> "deny" | "allow"
decision() {
  if raw "$1" "$2" | grep -q '"permissionDecision": *"deny"'; then echo deny; else echo allow; fi
}

# mkjson <tool> <file_path> [old_string]
mkjson() {
  jq -nc --arg t "$1" --arg f "$2" --arg o "${3-}" '
    {tool_name: $t, tool_input: {file_path: $f}}
    | if   $t=="Edit"  then .tool_input.old_string=$o | .tool_input.new_string="REPLACED"
      elif $t=="Write" then .tool_input.content="WHOLE FILE REPLACED"
      else . end'
}

echo "core-write-guard:"

# --- Assertion 0: SANITY — the hook exists and is runnable -------------------
[ -x "$HOOK" ] || bad "hook not executable: $HOOK"

# --- Assertion 1: in-place CORE edit in a layered consumer → DENY ------------
CORE="$CONSUMER/.claude/skills/ai-dlc/steps/gate-validation.md"
d="$(decision "$CONSUMER" "$(mkjson Edit "$CORE" "Fixed rulebook prose.")")"
[ "$d" = deny ] && ok "Edit to a core step file → deny" \
  || bad "Edit to a core step file classified '$d', expected deny — the core lock is not firing"

# --- Assertion 1b: the deny ROUTES (names overrides/ and extensions/) --------
OUT1="$(raw "$CONSUMER" "$(mkjson Edit "$CORE" "Fixed rulebook prose.")")"
if printf '%s' "$OUT1" | grep -q 'overrides/' && printf '%s' "$OUT1" | grep -q 'extensions/'; then
  ok "deny message routes the author to overrides/ and extensions/"
else
  bad "deny message does not name overrides/ + extensions/ — a refusal without a route gets the hook turned off"
fi

# --- Assertion 2: edit to an overrides/ entry → ALLOW ------------------------
d="$(decision "$CONSUMER" "$(mkjson Edit "$SKILL/overrides/example-shadow.md" "Consumer-owned override body.")")"
[ "$d" = allow ] && ok "Edit to overrides/ → allow" \
  || bad "Edit to overrides/ classified '$d', expected allow — a false-deny on the layer wedges the consumer"

# --- Assertion 3: edit to an extensions/ entry → ALLOW ----------------------
d="$(decision "$CONSUMER" "$(mkjson Edit "$SKILL/extensions/example-rule.md" "Consumer-owned additive extension body.")")"
[ "$d" = allow ] && ok "Edit to extensions/ → allow" \
  || bad "Edit to extensions/ classified '$d', expected allow"

# --- Assertion 4: a SHELL write to core is UNAFFECTED (not an Edit-tool call) -
# apply.sh writes core via `git show > file`; that is a Bash tool call, which this
# hook must ignore entirely (it matches only Edit|Write|MultiEdit).
BASHJSON="$(jq -nc --arg c "git show theirs:core/skills/ai-dlc/steps/gate-validation.md > $CORE" \
  '{tool_name:"Bash", tool_input:{command:$c}}')"
d="$(decision "$CONSUMER" "$BASHJSON")"
[ "$d" = allow ] && ok "Bash shell write to core → allow (update flow exempt by construction)" \
  || bad "a Bash shell write to core classified '$d', expected allow — the hook must not see shell writes"

# --- Assertion 5: NO-OP in the distribution (no .ai-dlc-version stamp) -------
d="$(decision "$NOSTAMP" "$(mkjson Edit "$NOSTAMP/.claude/skills/ai-dlc/steps/gate-validation.md" "Fixed rulebook prose.")")"
[ "$d" = allow ] && ok "Edit to core in an unstamped tree (distribution) → allow (no-op)" \
  || bad "the hook fired '$d' in an unstamped tree, expected allow — it must no-op in the distribution"

# --- Assertion 6: /ai-dlc-setup single-line config fill → ALLOW -------------
# Replacing the model-string line (a declared single-line site) is a setup fill, not drift.
MODEL_LINE="$(grep -m1 '^- Personal: `/model' "$CONSUMER/.claude/team-roles/architect.md" || true)"
[ -n "$MODEL_LINE" ] || bad "FIXTURE STALE: architect.md has no '- Personal: \`/model' line"
d="$(decision "$CONSUMER" "$(mkjson Edit "$CONSUMER/.claude/team-roles/architect.md" "$MODEL_LINE")")"
[ "$d" = allow ] && ok "Edit filling a declared model-string site (team-role) → allow" \
  || bad "a setup model-string fill classified '$d', expected allow — the config exemption is not applying"

# --- Assertion 7: edit OUTSIDE the config regions of the SAME file → DENY ----
# A Responsibilities line in architect.md is rulebook, not a declared site.
RULE_LINE="$(awk '/^## Responsibilities/{f=1;next} f&&NF{print;exit}' "$CONSUMER/.claude/team-roles/architect.md")"
[ -n "$RULE_LINE" ] || bad "FIXTURE STALE: architect.md has no Responsibilities content line"
d="$(decision "$CONSUMER" "$(mkjson Edit "$CONSUMER/.claude/team-roles/architect.md" "$RULE_LINE")")"
[ "$d" = deny ] && ok "Edit to a rulebook line of a config-bearing file → deny (region check is precise)" \
  || bad "an in-place rulebook edit classified '$d', expected deny — the region check exempts the whole file, not just its sites"

# --- Assertion 8: /ai-dlc-setup heading-block config fill → ALLOW -----------
# The dev.md ## Ownership block is a declared heading-block site.
OWN_LINE="$(awk '/^## Ownership/{f=1;next} f&&/^## Responsibilities/{exit} f&&NF{print;exit}' "$CONSUMER/.claude/team-roles/dev.md")"
[ -n "$OWN_LINE" ] || bad "FIXTURE STALE: dev.md has no content in the ## Ownership block"
d="$(decision "$CONSUMER" "$(mkjson Edit "$CONSUMER/.claude/team-roles/dev.md" "$OWN_LINE")")"
[ "$d" = allow ] && ok "Edit within the dev.md ## Ownership heading-block site → allow" \
  || bad "an ownership-block fill classified '$d', expected allow — the heading-block region is not being honored"

# --- Assertion 9: WRITE (whole-file overwrite) of a core file → DENY --------
d="$(decision "$CONSUMER" "$(mkjson Write "$CORE")")"
[ "$d" = deny ] && ok "Write (whole-file overwrite) of a core file → deny" \
  || bad "a whole-file Write to core classified '$d', expected deny — a Write is never a token fill"

# --- Assertion 10: MultiEdit whose edits touch rulebook → DENY --------------
MULTI="$(jq -nc --arg f "$CORE" '{tool_name:"MultiEdit", tool_input:{file_path:$f, edits:[{old_string:"Fixed rulebook prose.", new_string:"X"}]}}')"
d="$(decision "$CONSUMER" "$MULTI")"
[ "$d" = deny ] && ok "MultiEdit to a core rulebook file → deny" \
  || bad "a MultiEdit to core classified '$d', expected deny"

# --- Assertion 11: derivation FALLBACK — remove core-manifest.md, keep sites -
# The hook must fall back to setup-sites.md's I5-synced core_manifest copy and still deny.
rm -f "$CONSUMER/.claude/skills/ai-dlc/core-manifest.md"
d="$(decision "$CONSUMER" "$(mkjson Edit "$CORE" "Fixed rulebook prose.")")"
[ "$d" = deny ] && ok "core-manifest.md absent → derives core set from setup-sites.md, still denies" \
  || bad "with core-manifest.md gone the hook classified '$d', expected deny (setup-sites.md fallback failed)"

# --- Assertion 12: FAIL-OPEN — no manifest source at all → ALLOW ------------
# Remove the fallback too; with no way to derive the core set the hook must fail open.
rm -f "$CONSUMER/.claude/skills/ai-dlc-update/reconcile/setup-sites.md"
d="$(decision "$CONSUMER" "$(mkjson Edit "$CORE" "Fixed rulebook prose.")")"
[ "$d" = allow ] && ok "no manifest source anywhere → fail-open allow (never wedge on ambiguity)" \
  || bad "with no manifest source the hook classified '$d', expected allow — it must fail open, not closed"

echo
if [ "$fails" -eq 0 ]; then echo "core-write-guard: PASS"; exit 0; fi
echo "core-write-guard: $fails assertion(s) FAILED" >&2
exit 1
