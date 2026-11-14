#!/usr/bin/env bash
# snapshot-edit-deny/run.sh -- drive the REAL ai-dlc-snapshot-edit-deny.sh hook with static PreToolUse payloads
# on stdin, then drive a battery of mutants of it through the same cells.
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
#
# MUTANTS. Each is a copy at .../core/hooks/ai-dlc-snapshot-edit-deny.sh, built by mkmut (a literal or whole-line
# replacement, cmp -s guarded so a replacement that matched nothing reports DID NOT APPLY). Per push each runs the
# unit of its deciding arm, which must go RED, and the unit of its twin, which must stay GREEN; the kill goes through
# mutant_killed behind the shipped deciding arm's same-run pass and the control's. `--matrix` also drives every other
# unit and the red set must EQUAL the recorded one (the last argument of each score call).
#   m-nodeny      the deny printf replaced by `:` (the deny dropped)       -> every deny cell, REASON and JSON
#   m-nowrite     Write left out of the tool test                          -> WRITE
#   m-nomulti     MultiEdit left out of the tool test                      -> MULTI
#   m-nonb        notebook_path ignored (the NotebookEdit path is "")      -> NBEDIT
#   m-nbfile      NotebookEdit falls back to file_path                     -> NBFILE
#   m-anchor      the directory form anchored on */_bmad-output/           -> STATEDIR
#   m-nobare      the bare relative alternative dropped                    -> BARE
#   m-casesens    a case-sensitive literal match                           -> CASE
#   m-glob        pipeline-snapshot*.md                                    -> HIST
#   m-suffix      pipeline-snapshot.md*                                    -> BAK
#   m-unanchored  the directory form loses its `/`, a suffix match         -> XPIPE
#   m-anyfile     the allow branch removed: every path denied              -> every allow cell
#   m-noop        the reason names no op                                   -> REASON
#   m-oldremedy   the reason keeps its ops and routes back to the Edit tool -> REASON
#   m-fillroute   the FILL route reverts to --line-replace for every section -> REASON
#   m-badjson     a raw double quote in the reason: not JSON               -> JSON
# A control drives the UNMUTATED copy from the mutant directory through EDIT first and requires EDIT, REASON and JSON
# green on it, so a copy that cannot run is never read as a scored mutant.
#
# MUTANT-MATRIX m-nodeny decides=EDIT twins=HIST
# MUTANT-MATRIX m-nowrite decides=WRITE twins=EDIT
# MUTANT-MATRIX m-nomulti decides=MULTI twins=EDIT
# MUTANT-MATRIX m-nonb decides=NBEDIT twins=NBFILE
# MUTANT-MATRIX m-nbfile decides=NBFILE twins=NBEDIT
# MUTANT-MATRIX m-anchor decides=STATEDIR twins=EDIT
# MUTANT-MATRIX m-nobare decides=BARE twins=EDIT
# MUTANT-MATRIX m-casesens decides=CASE twins=EDIT
# MUTANT-MATRIX m-glob decides=HIST twins=BAK
# MUTANT-MATRIX m-suffix decides=BAK twins=HIST
# MUTANT-MATRIX m-unanchored decides=XPIPE twins=HIST
# MUTANT-MATRIX m-anyfile decides=NOTES twins=EDIT
# MUTANT-MATRIX m-noop decides=REASON twins=HIST
# MUTANT-MATRIX m-oldremedy decides=REASON twins=HIST
# MUTANT-MATRIX m-fillroute decides=REASON twins=HIST
# MUTANT-MATRIX m-badjson decides=JSON twins=HIST
# MUTANT-MATRIX-CONTROL control why=the unmutated copy from the mutant directory must pass EDIT, REASON and JSON so a mutant verdict is attributable to the mutation
# MUTANT-MATRIX-DYNAMIC mutants why=one scoring function passes every mutant name to mutant_killed and every name keeps its own row
# MUTANT-MATRIX-REMEASURE bash core/fixtures/snapshot-edit-deny/run.sh --matrix
set -uo pipefail

MODE=plain
case "${1:-}" in
  "") ;;
  --matrix) MODE=matrix ;;
  *) echo "snapshot-edit-deny: usage: run.sh [--matrix]" >&2; exit 2 ;;
esac

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
MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

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
# One literal line per arm, so each B_<arm>=1 sits in that arm's own passing branch.
if verdict ship EDIT; then ok "EDIT: an Edit of the snapshot is denied"; B_EDIT=1; else bad "EDIT: $MSG"; fi
if verdict ship REASON; then ok "REASON: the reason names snapshot-update.sh and its ops, not the Edit tool"; B_REASON=1; else bad "REASON: $MSG"; fi
if verdict ship JSON; then ok "JSON: the deny parses as a PreToolUse permissionDecision deny"; B_JSON=1; else bad "JSON: $MSG"; fi
if verdict ship WRITE; then ok "WRITE: a Write of the snapshot is denied"; B_WRITE=1; else bad "WRITE: $MSG"; fi
if verdict ship MULTI; then ok "MULTI: a MultiEdit of the snapshot is denied"; B_MULTI=1; else bad "MULTI: $MSG"; fi
if verdict ship NBEDIT; then ok "NBEDIT: a NotebookEdit naming the snapshot in notebook_path is denied"; B_NBEDIT=1; else bad "NBEDIT: $MSG"; fi
if verdict ship STATEDIR; then ok "STATEDIR: a snapshot outside _bmad-output is denied"; B_STATEDIR=1; else bad "STATEDIR: $MSG"; fi
if verdict ship BARE; then ok "BARE: the bare relative pipeline-snapshot.md is denied"; B_BARE=1; else bad "BARE: $MSG"; fi
if verdict ship CASE; then ok "CASE: Pipeline-Snapshot.MD is denied"; B_CASE=1; else bad "CASE: $MSG"; fi
if verdict ship HIST; then ok "HIST: pipeline-snapshot-history.md passes"; B_HIST=1; else bad "HIST: $MSG"; fi
if verdict ship BAK; then ok "BAK: pipeline-snapshot.md.bak passes"; B_BAK=1; else bad "BAK: $MSG"; fi
if verdict ship NOTES; then ok "NOTES: another directory's notes.md passes"; B_NOTES=1; else bad "NOTES: $MSG"; fi
if verdict ship XPIPE; then ok "XPIPE: xpipeline-snapshot.md passes"; B_XPIPE=1; else bad "XPIPE: $MSG"; fi
if verdict ship NBFILE; then ok "NBFILE: a NotebookEdit carrying file_path, not notebook_path, passes"; B_NBFILE=1; else bad "NBFILE: $MSG"; fi

# --- mutants -----------------------------------------------------------------------------------
# mkmut <src> <dst> <old> <new> [<old> <new> ...]: <dst> is <src> with each literal replaced once, in order; an <old>
# beginning `=` matches a WHOLE line. Each replacement must change the file (cmp -s).
mkmut() {
  local src="$1" dst="$2" cur="$WORK/mk.cur" nxt="$WORK/mk.nxt"; shift 2
  cp "$src" "$cur" || return 1
  while [ $# -ge 2 ]; do
    MM_OLD="$1" MM_NEW="$2" awk 'BEGIN { o = ENVIRON["MM_OLD"]; n = ENVIRON["MM_NEW"]; whole = (substr(o, 1, 1) == "="); if (whole) o = substr(o, 2) }
      { if (!done && whole && $0 == o) { $0 = n; done = 1 }
        else if (!done && !whole && index($0, o)) { i = index($0, o); $0 = substr($0, 1, i - 1) n substr($0, i + length(o)); done = 1 }
        print }' "$cur" > "$nxt" || return 1
    cmp -s "$cur" "$nxt" && { echo "DID NOT APPLY: $1" >&2; return 1; }
    mv "$nxt" "$cur"; shift 2
  done
  mkdir -p "$(dirname "$dst")" && mv "$cur" "$dst"
}
mpath() { printf '%s' "$WORK/mut-$1/core/hooks/ai-dlc-snapshot-edit-deny.sh"; }

CTL="$(mpath control)"; mkdir -p "$(dirname "$CTL")"; cp "$HOOK" "$CTL"
B_ctl=0
if [ "$MODE" = matrix ]; then
  for u in $UNITS; do drive "$CTL" control "$u"; done; red=""
  for a in $ARMS; do verdict control "$a" || red="$red $a"; done
  printf 'MATRIX control red=[%s]\n' "${red# }"
  if [ -z "$red" ]; then B_ctl=1
  else bad "control: the unmutated copy reddens [${red# }] -- no mutant verdict below can be read"; fi
else
  drive "$CTL" control EDIT
  if verdict control EDIT && verdict control REASON && verdict control JSON; then B_ctl=1
  else bad "control: the unmutated copy fails EDIT, REASON or JSON ($MSG) -- no mutant verdict below can be read"; fi
fi
[ "$B_ctl" = 1 ] && ok "control: the unmutated copy from the mutant directory denies EDIT with a JSON reason naming the ops"

# score <mutant> <deciding arm> <twin arm> <recorded red set> <flag> <old> <new> [...]
# <flag> is every caller's "$(( ${B_<deciding arm>:-0} && ${B_ctl:-0} ))": 1 only when the shipped hook's deciding arm
# and the control both passed in this run.
n_mut=0; n_kill=0
score() {
  local name="$1" dec="$2" tw="$3" want="$4" flag="$5" p ud ut u a red; shift 5
  p="$(mpath "$name")"
  mkmut "$HOOK" "$p" "$@" || { bad "$name: mutation did not apply"; return; }
  n_mut=$((n_mut + 1))
  ud="$(unit_of "$dec")"; ut="$(unit_of "$tw")"
  [ "$ud" != "$ut" ] || { bad "$name: deciding arm $dec and twin $tw share unit $ud"; return; }
  drive "$p" "$name" "$ud"; drive "$p" "$name" "$ut"
  if verdict "$name" "$dec"; then bad "$name: SURVIVED -- $dec still holds on the mutant"; return; fi
  if ! verdict "$name" "$tw"; then bad "$name: its twin $tw also fails ($MSG) -- the kill spread past the recorded matrix"; return; fi
  if [ "$MODE" = matrix ]; then
    for u in $UNITS; do [ "$u" = "$ud" ] || [ "$u" = "$ut" ] || drive "$p" "$name" "$u"; done
    red=""; for a in $ARMS; do verdict "$name" "$a" || red="$red $a"; done; red="${red# }"
    printf 'MATRIX %s decides=%s twins=%s red=[%s]\n' "$name" "$dec" "$tw" "$red"
    [ "$red" = "$want" ] || { bad "$name: red set [$red], recorded [$want] -- update the recorded set and the header"; return; }
  fi
  n_kill=$((n_kill + 1))
  mutant_killed "$flag" "$name" "$name: killed by $dec with twin $tw green"
}

N='[Pp][Ii][Pp][Ee][Ll][Ii][Nn][Ee]-[Ss][Nn][Aa][Pp][Ss][Hh][Oo][Tt]'
L62="  $N.[Mm][Dd]|*/$N.[Mm][Dd]) ;;"
PF="printf '%s\\n' '{\"hookSpecificOutput\""
DENYHEAD='{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":'
ALLDENY="EDIT REASON JSON WRITE MULTI NBEDIT STATEDIR BARE CASE"
score m-nodeny EDIT HIST "$ALLDENY" "$(( ${B_EDIT:-0} && ${B_ctl:-0} ))" "$PF" ": '{\"hookSpecificOutput\""
score m-nowrite WRITE EDIT "WRITE" "$(( ${B_WRITE:-0} && ${B_ctl:-0} ))" '.tool_name == "Edit" or .tool_name == "Write" or' '.tool_name == "Edit" or'
score m-nomulti MULTI EDIT "MULTI" "$(( ${B_MULTI:-0} && ${B_ctl:-0} ))" ' or .tool_name == "MultiEdit")' ')'
score m-nonb NBEDIT NBFILE "NBEDIT" "$(( ${B_NBEDIT:-0} && ${B_ctl:-0} ))" '(.tool_input.notebook_path // "")' '""'
score m-nbfile NBFILE NBEDIT "NBFILE" "$(( ${B_NBFILE:-0} && ${B_ctl:-0} ))" '(.tool_input.notebook_path // "")' '(.tool_input.notebook_path // .tool_input.file_path // "")'
score m-anchor STATEDIR EDIT "STATEDIR" "$(( ${B_STATEDIR:-0} && ${B_ctl:-0} ))" "=$L62" "  $N.[Mm][Dd]|*/_bmad-output/$N.[Mm][Dd]) ;;"
score m-nobare BARE EDIT "BARE" "$(( ${B_BARE:-0} && ${B_ctl:-0} ))" "=$L62" "  */$N.[Mm][Dd]) ;;"
score m-casesens CASE EDIT "CASE" "$(( ${B_CASE:-0} && ${B_ctl:-0} ))" "=$L62" "  pipeline-snapshot.md|*/pipeline-snapshot.md) ;;"
score m-glob HIST BAK "HIST" "$(( ${B_HIST:-0} && ${B_ctl:-0} ))" "=$L62" "  $N*.[Mm][Dd]|*/$N*.[Mm][Dd]) ;;"
score m-suffix BAK HIST "BAK" "$(( ${B_BAK:-0} && ${B_ctl:-0} ))" "=$L62" "  $N.[Mm][Dd]*|*/$N.[Mm][Dd]*) ;;"
score m-unanchored XPIPE HIST "XPIPE" "$(( ${B_XPIPE:-0} && ${B_ctl:-0} ))" "=$L62" "  $N.[Mm][Dd]|*$N.[Mm][Dd]) ;;"
score m-anyfile NOTES EDIT "HIST BAK NOTES XPIPE NBFILE" "$(( ${B_NOTES:-0} && ${B_ctl:-0} ))" '  *) exit 0 ;;' '  *) ;;'
score m-noop REASON HIST "REASON" "$(( ${B_REASON:-0} && ${B_ctl:-0} ))" "$PF" "printf '%s\\n' '$DENYHEAD\"AI/DLC: pipeline-snapshot.md is refused.\"}}'; exit 0; : '{\"hookSpecificOutput\""
score m-oldremedy REASON HIST "REASON" "$(( ${B_REASON:-0} && ${B_ctl:-0} ))" "$PF" "printf '%s\\n' '$DENYHEAD\"AI/DLC: make the change with the Edit tool (or Write), or with snapshot-update.sh --row-replace or --line-replace.\"}}'; exit 0; : '{\"hookSpecificOutput\""
FILLNEW="in Pipeline Position and Sprint Context, --line-delete <section> '\\''<!-- FILL'\\'' removes the placeholder, then one --set <key> <value> <section> per key writes the keys (--set refuses a key outside its create allowlist); in any other section, such as Deploy Baseline, --line-replace <section> '\\''<!-- FILL'\\'' <text> replaces the placeholder, then --line-add <section> <text> adds each further line."
FILLOLD="(Pipeline Position, Sprint Context, Deploy Baseline): --line-replace <section> '\\''<!-- FILL'\\'' <text> replaces the placeholder, then --line-add <section> <text> adds each further line, and --set <key> <value> <section> writes a key."
score m-fillroute REASON HIST "REASON" "$(( ${B_REASON:-0} && ${B_ctl:-0} ))" "placeholder line: $FILLNEW" "placeholder line $FILLOLD"
score m-badjson JSON HIST "JSON" "$(( ${B_JSON:-0} && ${B_ctl:-0} ))" "$PF" "printf '%s\\n' '$DENYHEAD\"AI/DLC: use snapshot-update.sh \"--row-replace\" or --line-replace; $FILLNEW\"}}'; exit 0; : '{\"hookSpecificOutput\""

[ "$n_mut" -gt 0 ] && [ "$n_kill" -eq "$n_mut" ] && ok "$n_kill of $n_mut mutants scored dead" || bad "$n_kill of $n_mut mutants scored dead"

# Clean up by name: every file this run wrote, never a recursive delete of a variable.
for d in "$WORK"/mut-*; do rm -f "$d/core/hooks/ai-dlc-snapshot-edit-deny.sh"; rmdir "$d/core/hooks" "$d/core" "$d" 2>/dev/null; done
rm -f "$WORK"/*.out "$WORK"/*.err "$WORK"/*.rc
rmdir "$WORK" 2>/dev/null

echo
report_end snapshot-edit-deny
