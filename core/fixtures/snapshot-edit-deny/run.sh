#!/usr/bin/env bash
# snapshot-edit-deny/run.sh -- drive the REAL ai-dlc-snapshot-edit-deny.sh hook with static PreToolUse payloads
# on stdin.
#
# THE SUBJECT. pipeline-snapshot.md has one sanctioned writer, snapshot-update.sh, which judges the stamps it adds
# before it writes. The hook refuses every Edit, Write, MultiEdit and NotebookEdit of the snapshot, whatever
# directory holds it and in any letter case, and its reason names the snapshot-update.sh ops. Deny B -- the Bash
# half, in ai-dlc-foreground-budget.sh -- is held by core/fixtures/foreground-budget-deny and is not driven here.
#
# THE PAYLOADS are static JSON literals; nothing reads a clock, the load or the filesystem the paths name (the
# hook tests the path TEXT, so no path below needs to exist). B is a default state dir, S a relocated one.
#
# UNITS (one hook start each) and the ARMS read off them:
#   EDIT      Edit      B/pipeline-snapshot.md                         -> deny (raw "permissionDecision":"deny"), exit 0
#   REASON    read off EDIT: the reason names snapshot-update.sh, --row-replace and --line-replace, and NOT `Edit tool`;
#             in Pipeline Position and Sprint Context it routes a FILL placeholder through --line-delete then --set
#             (snapshot-update.sh refuses a key-shaped --line-replace/--line-add line there)
#   JSON      read off EDIT: the output parses as JSON with hookEventName PreToolUse and permissionDecision deny
#   WRITE     Write     B/pipeline-snapshot.md                         -> deny
#   MULTI     MultiEdit B/pipeline-snapshot.md                         -> deny
#   NBEDIT    NotebookEdit, notebook_path B/pipeline-snapshot.md       -> deny
#   STATEDIR  Edit      S/pipeline-snapshot.md (no _bmad-output)       -> deny
#   BARE      Edit      pipeline-snapshot.md (bare relative)           -> deny
#   CASE      Edit      B/Pipeline-Snapshot.MD                         -> deny
#   HIST      Edit      B/pipeline-snapshot-history.md                 -> allow (exit 0, nothing printed)
#   BAK       Edit      B/pipeline-snapshot.md.bak                     -> allow
#   NOTES     Edit      /proj/other/notes.md                           -> allow
#   XPIPE     Edit      B/xpipeline-snapshot.md                        -> allow
#   NBFILE    NotebookEdit carrying file_path B/pipeline-snapshot.md   -> allow (the notebook's path field is absent)
# Every deny cell's allow twin is one property apart: HIST/BAK/XPIPE sit beside EDIT in B, NBFILE is NBEDIT with the
# field renamed, NOTES is a path in another directory.
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
HOOK=""
for c in "$ROOT/core/hooks/ai-dlc-snapshot-edit-deny.sh" "$ROOT/.claude/hooks/ai-dlc-snapshot-edit-deny.sh"; do
  [ -f "$c" ] && { HOOK="$c"; break; }
done
[ -n "$HOOK" ] || { echo "FIXTURE ERROR: ai-dlc-snapshot-edit-deny.sh not found in either layout" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FIXTURE BROKEN: jq not found; the hook fails open without it, so no deny cell could fire" >&2; exit 2; }
echo "HERMETIC-CONSUMED $HOOK"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/snapshot-edit-deny.XXXXXX")" || exit 2

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }

B='/proj/_bmad-output'; S='/proj/state'
UNITS="EDIT WRITE MULTI NBEDIT STATEDIR BARE CASE HIST BAK NOTES XPIPE NBFILE"
ARMS="EDIT REASON JSON WRITE MULTI NBEDIT STATEDIR BARE CASE HIST BAK NOTES XPIPE NBFILE"
unit_of() { case "$1" in REASON|JSON) echo EDIT ;; *) echo "$1" ;; esac; }
# edit <path>: a static Edit payload naming <path>
edit() { printf '{"tool_name":"Edit","tool_input":{"file_path":"%s","old_string":"- a: 1","new_string":"- a: 2"}}' "$1"; }
payload() {
  case "$1" in
    EDIT)     edit "$B/pipeline-snapshot.md" ;;
    WRITE)    printf '{"tool_name":"Write","tool_input":{"file_path":"%s","content":"# Pipeline Snapshot\\n"}}' "$B/pipeline-snapshot.md" ;;
    MULTI)    printf '{"tool_name":"MultiEdit","tool_input":{"file_path":"%s","edits":[{"old_string":"a","new_string":"b"}]}}' "$B/pipeline-snapshot.md" ;;
    NBEDIT)   printf '{"tool_name":"NotebookEdit","tool_input":{"notebook_path":"%s","new_source":"x"}}' "$B/pipeline-snapshot.md" ;;
    NBFILE)   printf '{"tool_name":"NotebookEdit","tool_input":{"file_path":"%s","new_source":"x"}}' "$B/pipeline-snapshot.md" ;;
    STATEDIR) edit "$S/pipeline-snapshot.md" ;;
    BARE)     edit "pipeline-snapshot.md" ;;
    CASE)     edit "$B/Pipeline-Snapshot.MD" ;;
    HIST)     edit "$B/pipeline-snapshot-history.md" ;;
    BAK)      edit "$B/pipeline-snapshot.md.bak" ;;
    NOTES)    edit "/proj/other/notes.md" ;;
    XPIPE)    edit "$B/xpipeline-snapshot.md" ;;
    *) echo "FIXTURE BROKEN: unknown unit $1" >&2; exit 2 ;;
  esac
}
lc() { printf '%s' "$1" | tr 'A-Z' 'a-z'; }

# drive <program> <tag> <unit>: one start of the hook, tagged <tag>.<unit> for the invocation judge; its stdout,
# stderr and exit status land in $WORK/<tag>.<UNIT>.{out,err,rc}
drive() {
  local p="$1" t="$2" u="$3" f="$WORK/$2.$3"
  payload "$u" | FXCELL="$t.$(lc "$u")" bash "$p" > "$f.out" 2> "$f.err"
  echo "$?" > "$f.rc"
}
# verdict <tag> <arm>: 0 GREEN, 1 RED, over the files its unit's drive left; MSG carries a red cell's reason
MSG=""
verdict() {
  local t="$1" a="$2" f out err rc
  f="$WORK/$t.$(unit_of "$a")"; out="$(cat "$f.out")"; err="$(cat "$f.err")"; rc="$(cat "$f.rc")"
  MSG="rc=$rc out=[$(printf '%s' "$out" | cut -c1-120)] err=[$err]"
  [ "$rc" = 0 ] && [ -z "$err" ] || return 1
  case "$a" in
    REASON)
      case "$out" in *'Edit tool'*) MSG="the reason names the Edit tool: $MSG"; return 1 ;; esac
      case "$out" in *snapshot-update.sh*--row-replace*) ;; *) return 1 ;; esac
      case "$out" in *"Pipeline Position and Sprint Context, --line-delete <section> '<!-- FILL'"*"one --set <key> <value> <section> per key"*) ;;
        *) MSG="the reason does not route Pipeline Position and Sprint Context through --line-delete then --set: $MSG"; return 1 ;; esac
      case "$out" in *--line-replace*) return 0 ;; esac; return 1 ;;
    JSON)
      jq -e '.hookSpecificOutput.hookEventName == "PreToolUse" and .hookSpecificOutput.permissionDecision == "deny"' \
        < "$f.out" > /dev/null 2>&1 && return 0
      MSG="the output does not parse as a PreToolUse deny: $MSG"; return 1 ;;
    EDIT|WRITE|MULTI|NBEDIT|STATEDIR|BARE|CASE)
      case "$out" in *'"permissionDecision":"deny"'*) return 0 ;; esac; return 1 ;;
    HIST|BAK|NOTES|XPIPE|NBFILE)
      [ -z "$out" ] && return 0; return 1 ;;
  esac
  return 1
}

echo "snapshot-edit-deny:"
# --- the shipped hook: every unit once ---------------------------------------------------------
for u in $UNITS; do drive "$HOOK" ship "$u"; done
if verdict ship EDIT; then ok "EDIT: an Edit of the snapshot is denied"; else bad "EDIT: $MSG"; fi
if verdict ship REASON; then ok "REASON: the reason names snapshot-update.sh and its ops, not the Edit tool"; else bad "REASON: $MSG"; fi
if verdict ship JSON; then ok "JSON: the deny parses as a PreToolUse permissionDecision deny"; else bad "JSON: $MSG"; fi
if verdict ship WRITE; then ok "WRITE: a Write of the snapshot is denied"; else bad "WRITE: $MSG"; fi
if verdict ship MULTI; then ok "MULTI: a MultiEdit of the snapshot is denied"; else bad "MULTI: $MSG"; fi
if verdict ship NBEDIT; then ok "NBEDIT: a NotebookEdit naming the snapshot in notebook_path is denied"; else bad "NBEDIT: $MSG"; fi
if verdict ship STATEDIR; then ok "STATEDIR: a snapshot outside _bmad-output is denied"; else bad "STATEDIR: $MSG"; fi
if verdict ship BARE; then ok "BARE: the bare relative pipeline-snapshot.md is denied"; else bad "BARE: $MSG"; fi
if verdict ship CASE; then ok "CASE: Pipeline-Snapshot.MD is denied"; else bad "CASE: $MSG"; fi
if verdict ship HIST; then ok "HIST: pipeline-snapshot-history.md passes"; else bad "HIST: $MSG"; fi
if verdict ship BAK; then ok "BAK: pipeline-snapshot.md.bak passes"; else bad "BAK: $MSG"; fi
if verdict ship NOTES; then ok "NOTES: another directory's notes.md passes"; else bad "NOTES: $MSG"; fi
if verdict ship XPIPE; then ok "XPIPE: xpipeline-snapshot.md passes"; else bad "XPIPE: $MSG"; fi
if verdict ship NBFILE; then ok "NBFILE: a NotebookEdit carrying file_path, not notebook_path, passes"; else bad "NBFILE: $MSG"; fi
# Clean up by name: every file this run wrote, never a recursive delete of a variable.
rm -f "$WORK"/*.out "$WORK"/*.err "$WORK"/*.rc
rmdir "$WORK" 2>/dev/null

echo
report_end snapshot-edit-deny
