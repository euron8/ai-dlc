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
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. The manifest this seed copies is the consumer's
# INSTALLED one, which on an un-upgraded tree does not yet claim fixtures/ -- so the guard
# cannot deny a core fixture, and calling that a regression blocked the very self-update
# cycle that installs the claim. In the DISTRIBUTION the claim is always present, so an
# absent one is a hard error there and upstream cannot go green vacuously.
IS_DIST=0; [ -d "$HERE/../../../core/skills/ai-dlc" ] && IS_DIST=1
skip() { # skip <what> <why>
  if [ "$IS_DIST" = 1 ]; then bad "$1 -- $2 (HARD in the distribution: the claim must be present here)"
  else printf '  SKIP  %s -- %s\n' "$1" "$2"; fi
}

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

# --- Assertion 10b: in-place edit to a CORE HOOK → DENY ---------------------
# Core hooks are upstream-owned machinery; the manifest lists hooks/ai-dlc-*.sh, so the
# guard denies an in-place edit to one. Before this, hooks were absent from the manifest
# and read as an editable target — two agents concluded they were consumer-owned (LD-S295-1).
HOOKF="$CONSUMER/.claude/hooks/ai-dlc-pause.sh"
d="$(decision "$CONSUMER" "$(mkjson Edit "$HOOKF" 'touch $PAUSE_FLAG')")"
[ "$d" = deny ] && ok "Edit to a core hook (.claude/hooks/ai-dlc-*.sh) → deny" \
  || bad "Edit to a core hook classified '$d', expected deny — hooks were an editable target"

# --- Assertion 10d: edit to a CONSUMER-OWNED hook → ALLOW -------------------
# The glob is hooks/ai-dlc-*.sh, not hooks/*.sh: a consumer may ship its own hooks
# (e.g. guarded-merge.sh) beside the core set. Those are consumer-owned — the guard MUST
# NOT deny them, or a consumer cannot edit its own hook. This is the over-capture fix.
CONSUMER_HOOK="$CONSUMER/.claude/hooks/guarded-merge.sh"
d="$(decision "$CONSUMER" "$(mkjson Edit "$CONSUMER_HOOK" 'consumer body')")"
[ "$d" = allow ] && ok "Edit to a consumer-owned hook (non-ai-dlc) → allow" \
  || bad "Edit to a consumer hook classified '$d', expected allow — hooks/*.sh over-captures consumer hooks"

# --- Assertion 10c: the hook deny gives MACHINERY advice, not layer routing --
# A hook has no overrides/extensions grain; the message must say so and point at the
# hook's AI_DLC_* tunables / upstream, not send the author to a layer that cannot hold it.
OUTH="$(raw "$CONSUMER" "$(mkjson Edit "$HOOKF" 'touch $PAUSE_FLAG')")"
if printf '%s' "$OUTH" | grep -q 'machinery' \
   && printf '%s' "$OUTH" | grep -q 'AI_DLC_' \
   && ! printf '%s' "$OUTH" | grep -q 'Route it to the layer instead'; then
  ok "hook deny gives machinery/AI_DLC_ advice, not overrides/extensions routing"
else
  bad "hook deny gave layer-routing advice — a hook cannot go in overrides/ or extensions/"
fi

# --- Assertion 10e: in-place edit to an installed CORE FIXTURE → DENY -------
# The manifest claims each shipped fixture dir as fixtures/<name>/**. Until it did,
# upstream test data was the last part of core a consumer could edit in place, and the
# reference consumer had edited several fixture files. The deny message matters here more
# than elsewhere: a fixture's markers and counts ARE its assertion's input, so a tidying
# edit can leave it green while it tests nothing.
COREFIX="$CONSUMER/tests/fixtures/check-15-bypass/seed.sh"
CLAIMED=0
grep -q '^  - fixtures/' "$CONSUMER/.claude/skills/ai-dlc/core-manifest.md" 2>/dev/null && CLAIMED=1
if [ "$CLAIMED" = 0 ]; then
  skip "core-fixture deny (10e) and its message (10g)" \
    "the installed core-manifest.md does not claim fixtures/ yet; the claim lands with this same pull"
else
  d="$(decision "$CONSUMER" "$(mkjson Edit "$COREFIX" '# TODO reword this marker')")"
  [ "$d" = deny ] && ok "Edit to an installed core fixture (tests/fixtures/<core-name>/) → deny" \
    || bad "Edit to a core fixture classified '$d', expected deny — upstream test data is still editable in place"
fi

# --- Assertion 10f: edit to a CONSUMER-AUTHORED fixture → ALLOW -------------
# tests/fixtures/ is SHARED, and core and consumer dirs there share the `check-` prefix,
# which is why the entries are name-exact rather than a glob. A guard that denied a
# consumer's own fixture gets turned off, and takes 10e's protection with it. The name
# below shares every character of a core fixture's plus a suffix — the shape one dropped
# slash in a manifest entry would over-capture.
#
# NOT skipped when the claim is absent: allow is the answer either way, so this arm is
# meaningful on an un-upgraded tree too, and it is the half that catches over-capture.
OWNFIX="$CONSUMER/tests/fixtures/check-15-bypass-local/seed.sh"
d="$(decision "$CONSUMER" "$(mkjson Edit "$OWNFIX" 'consumer fixture body')")"
[ "$d" = allow ] && ok "Edit to a consumer-authored fixture at an adjacent name → allow" \
  || bad "Edit to a consumer fixture classified '$d', expected allow — the fixture entries over-capture"

# --- Assertion 10g: the fixture deny gives TEST-DATA advice ------------------
# Neither the layer routing nor the validator's AI_DLC_ tunable advice applies: you
# cannot override a seed, and a fixture has no knobs. The message must say the content
# is the assertion's input, or the reader tidies the file and vacates the test.
if [ "$CLAIMED" = 1 ]; then
  OUTF="$(raw "$CONSUMER" "$(mkjson Edit "$COREFIX" '# TODO reword this marker')")"
  if printf '%s' "$OUTF" | grep -q 'TEST DATA' \
     && printf '%s' "$OUTF" | grep -q 'VACATE' \
     && ! printf '%s' "$OUTF" | grep -q 'Route it to the layer instead'; then
    ok "fixture deny warns the content IS the assertion's input, not layer routing"
  else
    bad "fixture deny gave layer-routing or generic advice — a seed cannot go in overrides/"
  fi
fi

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
