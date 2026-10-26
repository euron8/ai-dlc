#!/usr/bin/env bash
# context-mode-protect/run.sh — drive the REAL ai-dlc-protect.sh hook with
# synthesized PreToolUse JSON on stdin and prove the verbatim-load boundary
# holds on the shapes a live consumer actually emits.
#
# THE DEFECTS THIS EXISTS TO CATCH. The hook shipped in v0.23.0 and its
# protected set was never touched again while the pipeline gained byte-enforced
# artifacts. Auditing 376KB of the graph consumer's own protection log across
# s289-s296 found four ways a protected file reached context-mode anyway, all
# of them logged as `allowed`:
#
#   1. an absolute path through a story WORKTREE (the literal $CLAUDE_PROJECT_DIR
#      prefix strip missed it, so it matched no pattern)
#   2. a GLOB spanning the file (`cat gate-log*.md` — the token equals no pattern)
#   3. a bare DIRECTORY reference (`wc -l .claude/skills/ai-dlc`)
#   4. ctx_index, which was not in the matcher at all, and which persists what
#      it consolidates into an FTS base that outlives the session
#
# And one that made every one of them moot: on bash 3.2 (the macOS system bash)
# expanding an EMPTY array under `set -u` is an error, so a hook that grew one
# would exit non-zero, emit no decision, and let the tool proceed — a silent
# fail-open that logs nothing. Assertion 0b pins the exit code for that reason.
set -uo pipefail

# The pre-push gate exports every AI_DLC_* tunable a consumer set in settings.json
# into this process. Scrub them so the hook is tested against its own defaults.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"
[ -r "$(dirname "$HOOK")/ai-dlc-context-provenance.sh" ] && echo "HERMETIC-CONSUMED core/hooks/ai-dlc-context-provenance.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# raw <project_dir> <json> -> hook stdout (JSON on deny, empty on allow)
raw() { printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$HOOK" 2>/dev/null; }

# decision <project_dir> <json> -> "deny" | "allow"
decision() {
  if grep -q '"permissionDecision": *"deny"' <<<"$(raw "$1" "$2")"; then echo deny; else echo allow; fi
}

# JSON builders, one per tool arm.
jf() { jq -nc --arg p "$1" '{tool_name:"mcp__plugin_context-mode_context-mode__ctx_execute_file", tool_input:{path:$p, language:"javascript", code:"x"}}'; }
ji() { jq -nc --arg p "$1" '{tool_name:"mcp__plugin_context-mode_context-mode__ctx_index", tool_input:{path:$p, source:"s"}}'; }
jb() { jq -nc --arg c "$1" '{tool_name:"mcp__plugin_context-mode_context-mode__ctx_batch_execute", tool_input:{commands:[{label:"l", command:$c}]}}'; }
# jbm <label1> <command1> [<label2> <command2> ...] -> a multi-command batch, in order.
jbm() { jq -nc '{tool_name:"mcp__plugin_context-mode_context-mode__ctx_batch_execute",
  tool_input:{commands:[range(0; $ARGS.positional|length; 2) as $i | {label:$ARGS.positional[$i], command:$ARGS.positional[$i+1]}]}}' --args "$@"; }

# expect <want> <project_dir> <json> <label>
expect() {
  local got; got="$(decision "$2" "$3")"
  [ "$got" = "$1" ] && ok "$4" || bad "$4 — classified '$got', expected '$1'"
}

echo "context-mode-protect:"

# --- Assertion 0: SANITY -----------------------------------------------------
[ -x "$HOOK" ] || bad "hook not executable: $HOOK"

# --- Assertion 0b: the hook EXITS 0 (no silent fail-open) --------------------
# A non-zero exit emits no decision and the tool proceeds. The hook must never
# take that path, on any arm, protected or not.
for _j in "$(jf .claude/skills/ai-dlc/SKILL.md)" "$(jf _bmad-output/planning-artifacts/prd.md)" \
          "$(jb 'npm test')" "$(ji .claude/team-roles)"; do
  printf '%s' "$_j" | CLAUDE_PROJECT_DIR="$PLAIN" bash "$HOOK" >/dev/null 2>&1 \
    || bad "hook exited non-zero (silent fail-open: no decision reaches the harness)"
done
ok "hook exits 0 on every arm (no silent fail-open)"

# --- Assertion 1: the ordinary case — a rule file by relative path -----------
expect deny "$PLAIN" "$(jf .claude/skills/ai-dlc/steps/implementation.md)" \
  "rule file (relative) → deny"

# --- Assertion 2: GLOB spanning a protected file -----------------------------
# `gate-log*.md` expands inside the sandbox to include the live gate-log. The
# literal token equals no pattern, so a one-directional match waves it through.
expect deny "$PLAIN" "$(jb 'cat _bmad-output/implementation-artifacts/gate-log*.md')" \
  "glob spanning the live gate-log → deny"
expect deny "$PLAIN" "$(jb 'cat .claude/team-roles/*')" \
  "glob over the role files → deny"

# --- Assertion 3: bare DIRECTORY reference to a rulebook dir -----------------
expect deny "$PLAIN" "$(jb 'wc -l .claude/skills/ai-dlc')" \
  "directory reference to the skill root → deny"
expect deny "$PLAIN" "$(ji .claude/team-roles)" \
  "ctx_index of the team-roles directory → deny"

# --- Assertion 4: WORKTREE / foreign-root absolute path ----------------------
# The project dir is PLAIN; the path is reached through a sibling worktree.
expect deny "$PLAIN" "$(jf "$WORKTREE/docs/coding-conventions.md")" \
  "rule file via a sibling worktree (absolute) → deny"
expect deny "$PLAIN" "$(jf "$WORKTREE/CLAUDE.md")" \
  "CLAUDE.md via a sibling worktree (absolute) → deny"
expect deny "$PLAIN" "$(jf "$PLAIN/docs/coding-conventions.md")" \
  "rule file via the project root (absolute) → deny"

# --- Assertion 5: the artifacts added since v0.23.0 --------------------------
expect deny "$PLAIN" "$(jf _bmad-output/audit-anchors.md)"                       "audit-anchors.md → deny"
expect deny "$PLAIN" "$(jf _bmad-output/planning-artifacts/stories/s1-x.md)"     "story file → deny"
expect deny "$PLAIN" "$(jf _bmad-output/implementation-artifacts/sprint-status.yaml)" "sprint-status.yaml (impl) → deny"
expect deny "$PLAIN" "$(jf _bmad-output/planning-artifacts/sprint-status.yaml)"  "sprint-status.yaml (planning) → deny"
expect deny "$PLAIN" "$(jf .claude/schemas/sprint-status.json)"                  "core schema → deny"

# --- Assertion 6: the planning corpus stays OFFLOADABLE ----------------------
# Rule 24 exists to keep this out of the lead. Its byte-exactness claims are
# enforced script-side by validate-locked-anchor.sh, so consolidating it cannot
# forge a passing anchor. A false deny here costs hundreds of native Reads.
expect allow "$PLAIN" "$(jf _bmad-output/planning-artifacts/prd.md)"                "prd.md → allow (Rule 24 offload)"
expect allow "$PLAIN" "$(jf _bmad-output/planning-artifacts/carry-over-backlog.md)" "carry-over-backlog.md → allow"
expect allow "$PLAIN" "$(jb 'grep -rn x _bmad-output/planning-artifacts/')"         "planning-artifacts sweep → allow"
expect allow "$PLAIN" "$(jb 'ls _bmad-output/planning-artifacts/stories/')"         "stories directory sweep → allow"

# --- Assertion 7: ARCHIVES are excluded BY DECISION --------------------------
# The retro reads these to summarize them; that is what consolidation is for.
expect allow "$PLAIN" "$(jf _bmad-output/implementation-artifacts/gate-log-archive-s287.md)" "gate-log archive → allow"
expect allow "$PLAIN" "$(jf _bmad-output/pipeline-snapshot-history.md)"                      "snapshot history → allow"
expect allow "$PLAIN" "$(jf docs/escalations/pending-archive.md)"                            "escalations archive → allow"
expect allow "$PLAIN" "$(jf docs/pre-ai-dlc/20260423-184725/CLAUDE.md)"                      "pre-ai-dlc snapshot → allow"

# --- Assertion 8: no OVER-capture of the consumer's own tree ----------------
expect allow "$PLAIN" "$(jf .claude/skills/bmad-agent-dev/SKILL.md)" "another skill's SKILL.md → allow"
expect allow "$PLAIN" "$(jf .claude/skills/ai-dlc-update/reconcile/emit-report.sh)" "a reconcile script → allow"
expect allow "$PLAIN" "$(jb 'cat docs/retro/2026-01-01.md')"         "a retro doc → allow"

# --- Assertion 9: the CONSUMER LAYER extends the set ------------------------
# docs/architecture.md is graph's architecture SoR. Core cannot name it without
# shipping one project's vocabulary to every consumer; the layer file declares it.
expect allow "$PLAIN"   "$(jf docs/architecture.md)" "consumer path with NO layer file → allow (core is project-agnostic)"
expect deny  "$LAYERED" "$(jf docs/architecture.md)" "consumer path declared in extensions/protected-paths.json → deny"
expect deny  "$LAYERED" "$(jf "$LAYERED/docs/architecture-index.md")" "declared consumer path, absolute → deny"
expect allow "$LAYERED" "$(jf docs/architecture-drafts/wip.md)"       "consumer-declared exclusion → allow"
expect deny  "$LAYERED" "$(jf _bmad-output/pipeline-snapshot.md)"     "core set still enforced under a layer file → deny"
expect allow "$LAYERED" "$(jf _bmad-output/planning-artifacts/prd.md)" "layer file does not over-protect → allow"

# --- Assertion 9b: the layer file extends the BATCH arm's extraction too -----
# The batch alternation is derived from the pattern list. If it were still the
# hand-written prefix list, a consumer path outside it would be invisible here
# while the file arm denied it.
expect deny "$LAYERED" "$(jb 'cat docs/architecture.md')" \
  "consumer path seen by the BATCH arm (derived alternation) → deny"

# --- Assertion 9c: the deny's CONTEXT never calls a consumer-protected path unprotected ---
# Core cannot know a consumer's layer. A CONTEXT sentence saying the planning corpus
# (architecture.md among it) is NOT protected contradicted the same deny's own REASON on a
# consumer whose layer protects docs/architecture.md. The arm is PRESENCE-shaped: a hook that
# emits nothing fails the third conjunct. ctxarm <hook> -> 0 when all three hold.
ctxarm() {
  local o; o="$(printf '%s' "$(jb 'cat docs/architecture.md')" | CLAUDE_PROJECT_DIR="$LAYERED" bash "$1" 2>/dev/null)"
  grep -q '"permissionDecision": *"deny"' <<<"$o" || return 1
  ! grep -qF 'NOT protected' <<<"$o" || return 1
  grep -qF 'Use the native Read tool' <<<"$o" || return 1
}
ctxarm "$HOOK" \
  && ok "layered deny CONTEXT: deny, no 'NOT protected', names the native Read tool" \
  || bad "layered deny CONTEXT: deny + no 'NOT protected' + 'Use the native Read tool' did not all hold"

# Mutant CONTEXT-RESTORED: the whole hooks directory is copied (the hook sources a sibling),
# with the 0.927.0 sentence restored. It must differ from the fix, pass the unmutated control,
# and fail this arm alone.
_MUT="$WORK/mut-ctx"; mkdir -p "$_MUT"
cp -R "$(dirname "$HOOK")/." "$_MUT/" 2>/dev/null
_OLD='story files."'
_NEW='story files. Archives and the planning corpus (prd/architecture/product-brief/carry-over) are NOT protected — consolidate those freely."'
_SRC="$(cat "$HOOK"; printf x)"; _SRC="${_SRC%x}"
printf '%s' "${_SRC/"$_OLD"/$_NEW}" > "$_MUT/ai-dlc-protect.sh"
if cmp -s "$HOOK" "$_MUT/ai-dlc-protect.sh"; then
  bad "mutant CONTEXT-RESTORED did not differ from the fix (DID NOT APPLY)"
elif ! bash -n "$_MUT/ai-dlc-protect.sh" 2>/dev/null; then
  bad "mutant CONTEXT-RESTORED does not parse (a crashing hook is killed at the deny conjunct, not the NOT protected one)"
elif _MO="$(printf '%s' "$(jb 'cat docs/architecture.md')" | CLAUDE_PROJECT_DIR="$LAYERED" bash "$_MUT/ai-dlc-protect.sh" 2>/dev/null)"; \
     ! { grep -q '"permissionDecision": *"deny"' <<<"$_MO" && grep -qF 'NOT protected' <<<"$_MO"; }; then
  bad "mutant CONTEXT-RESTORED output lacks deny + 'NOT protected': its kill would not come from the NOT protected conjunct"
elif ! { cp "$HOOK" "$_MUT/ctl.sh" && ctxarm "$_MUT/ctl.sh"; }; then
  bad "mutant CONTEXT-RESTORED harness broken: an unmutated copy in the same directory fails the 9c arm"
elif ! ctxarm "$_MUT/ai-dlc-protect.sh" \
     && [ "$(CLAUDE_PROJECT_DIR="$PLAIN" bash "$_MUT/ai-dlc-protect.sh" <<<"$(jf docs/architecture.md)" 2>/dev/null | grep -c permissionDecision)" = 0 ]; then
  ok "mutant CONTEXT-RESTORED killed by the 9c arm, and its PLAIN allow of docs/architecture.md still holds"
else
  bad "mutant CONTEXT-RESTORED SURVIVED the 9c arm (or disturbed the PLAIN allow)"
fi

# --- Assertion 9d: a batch deny NAMES its offending commands ----------------
# The deny used to name the paths but not which commands carried them, so the
# agent re-sent the whole batch blind. The DECISION is unchanged and still comes
# from every element joined (labels and string elements included); the naming is
# a separate step that only changes REASON. offending <hook> <json> -> the
# REASON's "Offending: ..." clause, empty when there is none.
J_HIT2="$(jbm a 'npm test' rd 'cat .claude/skills/ai-dlc/SKILL.md' c 'ls docs')"
J_HIT3="$(jbm a 'npm test' b 'ls docs' rd 'cat .claude/team-roles/lead.md')"
J_NONE="$(jbm a 'npm test' b 'ls docs' c 'cat docs/retro/2026-01-01.md')"
J_LABEL="$(jbm a 'npm test' '.claude/skills/ai-dlc/SKILL.md' 'ls docs' c 'pwd')"
J_STR='{"tool_name":"mcp__plugin_context-mode_context-mode__ctx_batch_execute","tool_input":{"commands":["cat .claude/skills/ai-dlc/SKILL.md"]}}'
reason() { printf '%s' "$2" | CLAUDE_PROJECT_DIR="$PLAIN" bash "$1" 2>/dev/null | jq -r '.hookSpecificOutput.permissionDecisionReason // empty' 2>/dev/null; }
offending() { reason "$1" "$2" | grep -oE 'Offending: [^.]*' ; }
# decision_with <hooks_dir> <json> -> "deny" | "allow" for the hook in that directory.
decision_with() {
  if grep -q '"permissionDecision": *"deny"' <<<"$(printf '%s' "$2" | CLAUDE_PROJECT_DIR="$PLAIN" bash "$1/ai-dlc-protect.sh" 2>/dev/null)"; then echo deny; else echo allow; fi
}
# hit2arm <hook> -> 0 when the command-2 deny names command 2 of 3, its label, and nothing else.
hit2arm() {
  local r; r="$(reason "$1" "$J_HIT2")"
  [ "$(offending "$1" "$J_HIT2")" = 'Offending: command 2 of 3 (label "rd")' ] || return 1
  grep -qF 'The other 2 of 3 carry no protected path' <<<"$r" || return 1
  grep -qF 'Use native Read' <<<"$r" || return 1
  grep -qF '.claude/skills/ai-dlc/SKILL.md' <<<"$r" || return 1
}
# labelarm <hook> -> 0 when a path carried ONLY by a label still denies.
labelarm() { grep -q '"permissionDecision": *"deny"' <<<"$(printf '%s' "$J_LABEL" | CLAUDE_PROJECT_DIR="$PLAIN" bash "$1" 2>/dev/null)"; }

expect deny "$PLAIN" "$J_HIT2" "3-command batch, protected path in command 2 → deny"
hit2arm "$HOOK" \
  && ok "batch deny REASON names exactly 'command 2 of 3 (label \"rd\")', the 2 clean commands, and native Read" \
  || bad "batch deny REASON does not name exactly command 2 of 3 — got '$(offending "$HOOK" "$J_HIT2")'"
[ "$(offending "$HOOK" "$J_HIT3")" = 'Offending: command 3 of 3 (label "rd")' ] \
  && ok "batch deny with the hit in command 3 names 'command 3 of 3'" \
  || bad "batch deny with the hit in command 3 — got '$(offending "$HOOK" "$J_HIT3")'"
expect allow "$PLAIN" "$J_NONE" "3-command batch with no protected path → allow"
expect deny "$PLAIN" "$J_LABEL" "protected path carried ONLY by a label → deny (decision reads the whole element)"
labelarm "$HOOK" || bad "labelarm helper disagrees with expect on the label-only batch"
expect deny "$PLAIN" "$J_STR" "string-element batch naming a protected path → deny"
[ "$(offending "$HOOK" "$J_STR")" = 'Offending: command 1 of 1' ] \
  && ok "string-element deny names 'command 1 of 1' with no label" \
  || bad "string-element deny — got '$(offending "$HOOK" "$J_STR")'"
grep -qF -- '- Offending commands: command 2 of 3 (label "rd")' "$PLAIN/_bmad-output/context-mode-protection-log.md" \
  && ok "protection log carries the '- Offending commands:' line" \
  || bad "protection log lacks '- Offending commands: command 2 of 3 (label \"rd\")'"

# mkmut9d <name> <old> <new> [<old2> <new2>] -> path of a mutated copy of the hooks dir, or empty
# when a substitution matched nothing. The whole directory is copied (the hook sources a sibling).
mkmut9d() {
  local d="$WORK/mut-$1" src
  mkdir -p "$d"; cp -R "$(dirname "$HOOK")/." "$d/" 2>/dev/null
  src="$(cat "$HOOK"; printf x)"; src="${src%x}"
  case "$src" in *"$2"*) ;; *) return 0 ;; esac
  src="${src/"$2"/$3}"
  if [ "$#" -ge 5 ]; then
    case "$src" in *"$4"*) ;; *) return 0 ;; esac
    src="${src/"$4"/$5}"
  fi
  printf '%s' "$src" > "$d/ai-dlc-protect.sh"
  cmp -s "$HOOK" "$d/ai-dlc-protect.sh" || printf '%s' "$d"
}
# Unmutated control in a copied directory: the harness itself must pass every arm the mutants are scored on.
_CTL9="$WORK/ctl-9d"; mkdir -p "$_CTL9"; cp -R "$(dirname "$HOOK")/." "$_CTL9/" 2>/dev/null
if hit2arm "$_CTL9/ai-dlc-protect.sh" && labelarm "$_CTL9/ai-dlc-protect.sh"; then
  ok "9d mutant control: an unmutated copy passes the command-2 and label-only arms"
else
  bad "9d mutant harness broken: an unmutated copy fails the command-2 or label-only arm"
fi

# Mutant REASON-BASE: the naming branch never taken, so REASON is base's text. Killed by the
# command-2 arm; its decisions (command-2 deny, label-only deny, clean allow) must still hold.
_M1="$(mkmut9d reason-base 'elif [ -n "$OFF_DESC" ]; then' 'elif false; then')"
if [ -z "$_M1" ]; then
  bad "mutant REASON-BASE did not differ from the fix (DID NOT APPLY)"
elif ! bash -n "$_M1/ai-dlc-protect.sh" 2>/dev/null; then
  bad "mutant REASON-BASE does not parse"
elif hit2arm "$_M1/ai-dlc-protect.sh"; then
  bad "mutant REASON-BASE SURVIVED the command-2 arm"
elif [ "$(decision_with "$_M1" "$J_HIT2")$(decision_with "$_M1" "$J_LABEL")$(decision_with "$_M1" "$J_NONE")" = denydenyallow ]; then
  ok "mutant REASON-BASE killed by the command-2 arm, its decisions unchanged (deny, deny, allow)"
else
  bad "mutant REASON-BASE moved a decision — its kill is not the REASON's"
fi

# Mutant PER-ELEMENT-DECIDES: the naming step searches only each element's command (labels
# dropped) and a batch it names nothing in is allowed. Killed by the label-only arm; the
# command-2 arm must still pass on it, so the kill is the label's.
_M2="$(mkmut9d per-element '\(.value | tojson)"' '\(if (.value | type) == "object" then (.value.command // "" | tostring) else (.value | tostring) end)"' \
  "$(printf '\nOFF_DESC=""\n')" "$(printf '\nif [ "$OFF_TOTAL" -gt 0 ]; then [ "$OFF_N" -gt 0 ] || PROTECTED_HITS=(); fi\nOFF_DESC=""\n')")"
if [ -z "$_M2" ]; then
  bad "mutant PER-ELEMENT-DECIDES did not differ from the fix (DID NOT APPLY)"
elif ! bash -n "$_M2/ai-dlc-protect.sh" 2>/dev/null; then
  bad "mutant PER-ELEMENT-DECIDES does not parse"
elif labelarm "$_M2/ai-dlc-protect.sh"; then
  bad "mutant PER-ELEMENT-DECIDES SURVIVED the label-only arm"
elif hit2arm "$_M2/ai-dlc-protect.sh"; then
  ok "mutant PER-ELEMENT-DECIDES killed by the label-only arm, and the command-2 arm still passes on it"
else
  bad "mutant PER-ELEMENT-DECIDES also fails the command-2 arm — its kill is not the label's"
fi

# Fallback arm: when the naming step names no offender while the decision denies, REASON is
# base's text. The naming step's jq is pointed at a key the batch does not carry (a copy of the
# hooks dir), so it yields no rows while the decision source, a separate extraction, still denies.
# fallbackarm <hook> -> 0 when deny AND base REASON text AND no 'Offending:'.
fallbackarm() {
  local r; r="$(reason "$1" "$J_HIT2")"
  [ "$(decision_with "$(dirname "$1")" "$J_HIT2")" = deny ] || return 1
  grep -qF 'Use native Read for verbatim content.' <<<"$r" || return 1
  ! grep -qF 'Offending:' <<<"$r" || return 1
}
_M3="$(mkmut9d naming-empty '(.tool_input.commands // [])' '(.tool_input.nocommands // [])')"
if [ -z "$_M3" ]; then
  bad "fallback arm: naming-step mutant did not differ from the fix (DID NOT APPLY)"
elif ! bash -n "$_M3/ai-dlc-protect.sh" 2>/dev/null; then
  bad "fallback arm: naming-step mutant does not parse"
elif fallbackarm "$HOOK"; then
  bad "fallback arm: the unmutated hook satisfies the fallback arm (it names the offender, so the arm cannot discriminate)"
elif fallbackarm "$_M3/ai-dlc-protect.sh"; then
  ok "REASON falls back to base text (deny, 'Use native Read for verbatim content.', no 'Offending:') when naming finds no offender"
else
  bad "fallback arm: with the naming step empty the hook did not deny with base REASON text and no 'Offending:'"
fi

# Allowed-batch cost arm, structural rather than timed: the naming step's output is read only in
# the deny branch, so an ALLOWED batch must not run it. Its observable is its one jq fork. A jq shim
# on PATH counts invocations; an allowed 3-command batch must fork jq exactly as often as an
# allowed ctx_execute_file call (tool_name, session_id, one extraction), and a deny must fork MORE
# (the step ran) so the counter is shown to see the step at all. The counter is an EXPORTED bash
# function (no shim file, so no chmod and no tool outside tools.decl), which the hook's own bash
# resolves ahead of PATH.
# jqcount <hook> <json> -> number of jq invocations the hook made for that input.
jqcount() {
  local f="$WORK/jqcount.$$.$RANDOM" n; : > "$f"
  (
    jq() { echo x >> "$JQ_COUNT_FILE"; command jq "$@"; }
    export -f jq
    printf '%s' "$2" | JQ_COUNT_FILE="$f" CLAUDE_PROJECT_DIR="$PLAIN" bash "$1" >/dev/null 2>&1
  )
  n="$(grep -c x "$f")" || n=0
  printf '%s' "$n"
}
J_ALLOWF="$(jf _bmad-output/planning-artifacts/prd.md)"
# costarm <hook> -> 0 when an allowed batch forks jq the same number of times as an allowed file call.
costarm() { [ "$(jqcount "$1" "$J_NONE")" = "$(jqcount "$1" "$J_ALLOWF")" ]; }
_cn="$(jqcount "$HOOK" "$J_NONE")"; _cd="$(jqcount "$HOOK" "$J_HIT2")"
if [ "${_cn:-0}" -gt 0 ] && [ "${_cd:-0}" -gt "${_cn:-0}" ] && costarm "$HOOK"; then
  ok "allowed batch does not run the naming step (jq forks: allowed batch $_cn = allowed file call, deny $_cd)"
else
  bad "allowed batch ran the naming step, or the jq counter is blind (allowed batch ${_cn:-?}, deny ${_cd:-?}, file call $(jqcount "$HOOK" "$J_ALLOWF"))"
fi
_M4="$(mkmut9d naming-unguarded ' && [ ${#PROTECTED_HITS[@]} -gt 0 ]; then' '; then')"
if [ -z "$_M4" ]; then
  bad "mutant NAMING-UNGUARDED did not differ from the fix (DID NOT APPLY)"
elif ! bash -n "$_M4/ai-dlc-protect.sh" 2>/dev/null; then
  bad "mutant NAMING-UNGUARDED does not parse"
elif costarm "$_M4/ai-dlc-protect.sh"; then
  bad "mutant NAMING-UNGUARDED SURVIVED the cost arm"
elif hit2arm "$_M4/ai-dlc-protect.sh" && [ "$(decision_with "$_M4" "$J_NONE")" = allow ]; then
  ok "mutant NAMING-UNGUARDED killed by the cost arm, its command-2 REASON and clean allow unchanged"
else
  bad "mutant NAMING-UNGUARDED moved a decision or the REASON — its kill is not the cost arm's"
fi

# --- Assertion 10: a MALFORMED layer file fails CLOSED ----------------------
expect deny "$BROKEN" "$(jf _bmad-output/planning-artifacts/prd.md)" \
  "malformed layer file → deny even an unprotected path (fail closed)"
OUTB="$(raw "$BROKEN" "$(jf _bmad-output/planning-artifacts/prd.md)")"
grep -q 'protected-paths.json' <<<"$OUTB" \
  && ok "fail-closed deny names the file to fix" \
  || bad "fail-closed deny does not name protected-paths.json — a refusal with no route gets the hook turned off"

# --- Assertion 10b: fail-closed does NOT wedge pathless calls ---------------
# An enforcer with no release is a deadlock. A typo in the layer file must not
# stop a test run from being offloaded.
expect allow "$BROKEN" "$(jb 'npm test')" \
  "malformed layer file + no path in the call → allow (fail-closed, not wedged)"

# --- Assertion 11: the log records both decisions ---------------------------
LOG="$PLAIN/_bmad-output/context-mode-protection-log.md"
grep -q -- '-- PROTECTED' "$LOG" && grep -q -- '-- allowed' "$LOG" \
  && ok "protection log records both PROTECTED and allowed events" \
  || bad "protection log is missing one of the two decision classes — the retro reads this file"

echo
if [ "$fails" -eq 0 ]; then echo "context-mode-protect: PASS"; exit 0; fi
echo "context-mode-protect: $fails assertion(s) FAILED" >&2
exit 1
