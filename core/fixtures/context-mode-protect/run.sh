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

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# raw <project_dir> <json> -> hook stdout (JSON on deny, empty on allow)
raw() { printf '%s' "$2" | CLAUDE_PROJECT_DIR="$1" bash "$HOOK" 2>/dev/null; }

# decision <project_dir> <json> -> "deny" | "allow"
decision() {
  if raw "$1" "$2" | grep -q '"permissionDecision": *"deny"'; then echo deny; else echo allow; fi
}

# JSON builders, one per tool arm.
jf() { jq -nc --arg p "$1" '{tool_name:"mcp__plugin_context-mode_context-mode__ctx_execute_file", tool_input:{path:$p, language:"javascript", code:"x"}}'; }
ji() { jq -nc --arg p "$1" '{tool_name:"mcp__plugin_context-mode_context-mode__ctx_index", tool_input:{path:$p, source:"s"}}'; }
jb() { jq -nc --arg c "$1" '{tool_name:"mcp__plugin_context-mode_context-mode__ctx_batch_execute", tool_input:{commands:[{label:"l", command:$c}]}}'; }

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

# --- Assertion 10: a MALFORMED layer file fails CLOSED ----------------------
expect deny "$BROKEN" "$(jf _bmad-output/planning-artifacts/prd.md)" \
  "malformed layer file → deny even an unprotected path (fail closed)"
OUTB="$(raw "$BROKEN" "$(jf _bmad-output/planning-artifacts/prd.md)")"
printf '%s' "$OUTB" | grep -q 'protected-paths.json' \
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
