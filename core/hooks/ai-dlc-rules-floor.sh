#!/usr/bin/env bash
# ai-dlc-rules-floor.sh — SessionStart hook. Makes an INERT rule file LOUD.
#
# `.claude/rules/` is read by Claude Code's own loader and did not exist before
# **2.0.64**. Below that floor a rule file sits in the tree and NOTHING READS IT: the
# consumer's own audit scans it and reports CLEAN, `.ai-dlc-version` says the tree is
# current, and Rule 23's `**Carrier:**` names a carrier that is not carrying. That is
# a check that cannot fire reading exactly like one that passed -- this project's named
# recurring defect, exported to a consumer.
#
# WHY A HOOK AND NOT THE INSTALLER. The floor first shipped as a gate inside
# `install.sh`, which was wrong in a way MEASURED on a copy of the reference consumer:
# `install.sh` is the path a NEW consumer takes, and an existing one arrives through
# `ai-dlc-update`, whose `apply.sh` copies core files by a derived mapping and knows
# nothing about versions. The real pull, run 0.347.0 -> 0.349.0 against that copy with
# a shimmed 1.9.0, reported `RESOLVED pure-apply rules/ai-dlc-resident-discipline.md`,
# wrote the file, and re-stamped the tree as current. Two copy paths, one gate. Adding
# a second gate inside `apply.sh` would still miss the third case -- a consumer who
# installs on a current build and later DOWNGRADES -- and would put a per-path special
# case inside a deliberately derive-never-list copier.
#
# So the floor is not enforced at copy time at all. The file always ships; this hook is
# the single detector, and it runs every session regardless of how the file arrived.
#
# IT ALSO SNAPSHOTS `.claude/agents/` per session (THE AGENT-DEFINITION SNAPSHOT below), because it is
# the one SessionStart hook registered for every source.
#
# FAIL-OPEN, ALWAYS. A detector that blocks a session is worse than the defect it
# reports. Every path exits 0.

# The whole program is arf_main, so a fixture can SOURCE this file and call it in process; nothing above
# the guard at the end runs in the sourcing shell except that definition.
arf_main() {
set -u
hook_in="$(cat 2>/dev/null || true)"   # SessionStart input; `source` and `session_id` are read

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
RULES_DIR="$PROJECT_DIR/.claude/rules"
FLOOR_MAJOR=2; FLOOR_MINOR=0; FLOOR_PATCH=64

jstr() { printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/^/"/; s/$/"/'; }

# CONTEXT-MODE USER-SCOPE PRESENCE. WARN only (a user-facing systemMessage, never additionalContext), on
# source `startup` only. It sits BEFORE the no-rule-file exit below because a consumer with no shipped rule
# file still needs context-mode installed at user scope. Silent whenever the oracle cannot be read.
sysmsg=""
cm_id="context-mode@context-mode"
cm_cfg="${CLAUDE_CONFIG_DIR:-${HOME:-/nonexistent}/.claude}"
cm_f="$cm_cfg/plugins/installed_plugins.json"
if command -v jq >/dev/null 2>&1 && [ -r "$cm_f" ] \
   && [ "$(printf '%s' "$hook_in" | jq -r '.source // ""' 2>/dev/null)" = "startup" ] \
   && [ "$(jq -r --arg id "$cm_id" 'if (.version == 2 and (.plugins | type) == "object") then ([.plugins[$id][]? | select(.scope == "user" or .scope == "managed")] | length | tostring) else "unknown" end' "$cm_f" 2>/dev/null)" = "0" ]; then
  cm_optout=0
  for cm_s in "${CLAUDE_PROJECT_DIR:-.}/.claude/settings.json" "${CLAUDE_PROJECT_DIR:-.}/.claude/settings.local.json" "$cm_cfg/settings.json"; do
    [ -r "$cm_s" ] || continue
    [ "$(jq -r --arg id "$cm_id" '.enabledPlugins[$id] | if . == false then "off" else "" end' "$cm_s" 2>/dev/null)" = "off" ] && cm_optout=1
  done
  if [ "$cm_optout" = "0" ]; then
    sysmsg="AI/DLC: context-mode has no user-scope install on this machine. Install it once, for every project:
  claude plugin marketplace add mksglu/context-mode
  claude plugin install context-mode@context-mode --scope user"
  fi
fi

# THE AGENT-DEFINITION SNAPSHOT. The harness loads `.claude/agents/*.md` once, when the process
# starts, so the bodies a session's spawns receive are the ones on disk at `startup` or `resume`.
# They are copied to `<state dir>/.agent-definitions/<session_id>/`, and the dispatch guard
# credits a definition as the role-contract carrier only from this copy. NEVER on `compact` or
# `clear`: the process keeps its start-up definitions through both, so a copy taken then would
# record a body re-rendered mid-session that the process does not hold. Copies older than seven
# days are pruned first; a session that outlives that falls back to the prompt carrier.
if command -v jq >/dev/null 2>&1; then
  snap_kv="$(printf '%s' "$hook_in" | jq -r '"\(.source // "") \(.session_id // "")"' 2>/dev/null || true)"
  snap_src="${snap_kv%% *}"; snap_sid="${snap_kv#* }"
  case "$snap_sid" in ''|*[!A-Za-z0-9_-]*) snap_sid="" ;; esac
  STATE_DIR="${PROJECT_DIR}/${AI_DLC_STATE_DIR:-_bmad-output}"
  SNAP_ROOT="${STATE_DIR}/.agent-definitions"
  case "$snap_src" in
    startup|resume)
      if [ -n "$snap_sid" ] && [ -d "$PROJECT_DIR/.claude/agents" ]; then
        [ -d "$SNAP_ROOT" ] && find "$SNAP_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null
        mkdir -p "$SNAP_ROOT/$snap_sid" 2>/dev/null \
          && cp -p "$PROJECT_DIR/.claude/agents/"*.md "$SNAP_ROOT/$snap_sid/" 2>/dev/null
      fi ;;
  esac
fi

# Nothing shipped here -> nothing to be inert -> say nothing. This is also what keeps
# the hook silent on a consumer that has never pulled a release carrying a rule file.
shopt -s nullglob 2>/dev/null || true
shipped=("$RULES_DIR"/ai-dlc-*.md)
if [ "${#shipped[@]}" -eq 0 ]; then
  [ -z "$sysmsg" ] || printf '{"systemMessage":%s}\n' "$(jstr "$sysmsg")"
  exit 0
fi

# Resolve the running Claude Code version.
#
# `AI_AGENT` is set in the hook's own environment (measured: `claude-code_2-1-226_agent`)
# and costs nothing. `claude --version` is the fallback and costs ~40ms, which is why it
# is not the first choice. If NEITHER resolves we report that rather than assuming the
# floor is met -- an unresolvable version is the same epistemic state as a version below
# the floor, and silently treating it as "fine" is the exact failure this hook exists for.
ver=""
case "${AI_AGENT:-}" in
  claude-code_*_agent)
    ver="${AI_AGENT#claude-code_}"; ver="${ver%_agent}"; ver="${ver//-/.}" ;;
esac
if [ -z "$ver" ]; then
  ver="$(claude --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)"
fi

names="$(printf '%s\n' "${shipped[@]}" | while read -r p; do basename "$p"; done | paste -sd', ' -)"
# PROVENANCE MARKER -- PC-S306-UNSOLICITED-CONTEXT-HAS-NO-PROVENANCE-SIGNAL. The
# library is a SIBLING in both layouts (core/hooks/, .claude/hooks/), so this is a
# same-directory read and never a walk up from a resolved path. Fail-open: a hook
# that cannot mark its output still emits it.
_AI_DLC_PROV="$(dirname "${BASH_SOURCE[0]}")/ai-dlc-context-provenance.sh"
if [ -r "$_AI_DLC_PROV" ]; then . "$_AI_DLC_PROV"
else ai_dlc_provenance_wrap() { printf %s "${3:-}"; }; fi

# `emit` takes RAW text and does its own escaping, so the marker is prepended in ONE
# place rather than at each call site. Every call site below passes raw text.
#
# THIS HOOK CARRIES THE PROVENANCE CONTRACT FOR THE WHOLE FLEET -- the 4th argument -- and the
# siting is a BUDGET decision, not a topical one. The paragraph has to recur after a compaction,
# which means a SessionStart hook; attaching it to EVERY SessionStart emission put
# ai-dlc-recover.sh's recovery block at 10482 characters against a 9500 bound and a 10000 cliff
# past which the harness discards the whole block. This hook is SessionStart, runs every session,
# and carries almost no payload of its own, so it has the room. I98 binds the count to exactly
# one: two carriers would double the cost, and zero would leave a marker the lead never learns
# to check.
emit() { printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}%s}\n' \
           "$(jstr "$(ai_dlc_provenance_wrap ai-dlc-rules-floor SessionStart "$1" contract)")" \
           "${sysmsg:+,\"systemMessage\":$(jstr "$sysmsg")}"; }

if [ -z "$ver" ]; then
  emit "AI/DLC RULES FLOOR -- UNRESOLVED. Could not determine the Claude Code version from AI_AGENT or \`claude --version\`, so it is NOT known whether $names under .claude/rules/ is being read. Those files require Claude Code >= ${FLOOR_MAJOR}.${FLOOR_MINOR}.${FLOOR_PATCH}. Treat Rule 23 as carried by SKILL.md alone until this resolves."
  exit 0
fi

IFS=. read -r a b c <<EOF
$ver
EOF
a=${a:-0}; b=${b:-0}; c=${c:-0}
below=0
if   [ "$a" -lt "$FLOOR_MAJOR" ]; then below=1
elif [ "$a" -eq "$FLOOR_MAJOR" ] && [ "$b" -lt "$FLOOR_MINOR" ]; then below=1
elif [ "$a" -eq "$FLOOR_MAJOR" ] && [ "$b" -eq "$FLOOR_MINOR" ] && [ "$c" -lt "$FLOOR_PATCH" ]; then below=1
fi

if [ "$below" = "1" ]; then
  emit "AI/DLC RULES FLOOR NOT MET -- an installed rule file is INERT. Claude Code $ver is below ${FLOOR_MAJOR}.${FLOOR_MINOR}.${FLOOR_PATCH}, the release that added the .claude/rules/ loader. These file(s) are present and are NOT being read: $names. Rule 23 (resident-context discipline) is therefore carried by .claude/skills/ai-dlc/SKILL.md ALONE, and its Carrier declaration overstates what is in force -- do not rely on it surviving a compaction. Upgrade Claude Code, or treat SKILL.md as the only source. Nothing else in this tree reports this: the audit scans the file and passes, and .ai-dlc-version says the tree is current."
else
  # FLOOR MET. Before this release that was a silent exit, and it still says nothing about the
  # floor -- the empty body is deliberate. What it does carry is the provenance contract, which
  # is why this branch exists at all: the contract must reach the lead on EVERY session, not
  # only on the sessions where an unrelated check happens to fire.
  emit ""
fi

exit 0
}
# Executed, it runs; sourced, it has defined arf_main and returns.
[ "${BASH_SOURCE[0]}" = "$0" ] || return 0
arf_main "$@"
