#!/usr/bin/env bash
# standing-rulings-hook/run.sh -- drive the REAL ai-dlc-standing-rulings.sh PreToolUse hook (on AskUserQuestion)
# with static payloads over a seeded consumer-layout world, and the reader's `grammar` mode against the real tree.
#
# THE SUBJECT. A question whose `header` EQUALS the `match:` of an active, SOURCED row of the standing-rulings
# record triggers a consult: the hook denies the whole call ONCE, the reason citing SR-id, ruling and source and
# stating the escape `not SR-<n>: <one-line reason>`, which it always allows. It fails open on every unreadable
# state. The hook reads rows only through standing-rulings.sh (the one reader).
#
# THE WORLD is built once and copied: an answers-history written in the answer-capture hook's entry format (two
# entries, so the first is cited while NOT last) and a record of two rows, SR-1 (match `Pull auth`) and SR-2
# (match `Check 32`), each citing its entry's heading line and carrying the answer's sha256.
#
# UNITS (one hook start each) and the ARMS read off them; every DENY has its ALLOW twin one property apart:
#   MATCH     header `Pull auth`                                   -> deny
#   REASON    read off MATCH: cites SR-1, the ruling verbatim, the source, the escape text, DECIDED_AUTONOMOUSLY
#   JSON      read off MATCH: parses as a PreToolUse deny
#   ESCAPE    MATCH + `not SR-1: <reason>` in the question text    -> allow (twin of MATCH)
#   WRONGESC  MATCH + `not SR-2: <reason>` (another row's number)  -> deny  (twin of ESCAPE)
#   NOREASON  MATCH + `not SR-1: ` with no reason                  -> deny  (twin of ESCAPE)
#   UNMATCH   header `Other`                                       -> allow (twin of MATCH)
#   MULTI     `Other` + `Check 32`                                 -> deny whole; the reason lists `Other` as unheld
#   MULTIESC  the same call, `Check 32` carrying `not SR-2: r`    -> allow (twin of MULTI)
#   OTHERTOOL tool_name Bash                                       -> allow
#   ABSENT    MATCH over a world with no record                    -> allow (twin of MATCH)
#   MALFORMED MATCH over a world whose record row lacks fields     -> allow (twin of MATCH)
#   NOREADER  MATCH over a world with no reader                    -> allow (twin of MATCH)
#   GRAMMAR   the shipped `standing-rulings.sh grammar` over the real tree prints an `ok` line per emitter anchor
#   GRAMMARX  the same over a world where one emitter's anchor text is removed: exit 1 and a FAIL line (twin)
# The GRAMMAR arms need the emitters at their distribution paths; on a consumer they are absent and the pair
# prints SKIP while every hook arm still decides the exit; in the distribution absent emitters are a failed arm.
#   OUTSIDE   a row whose proposal names an Outside-list class: check exits 1 naming the list, the hook allows
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_CODE_SESSION_ID CLAUDE_PROJECT_DIR

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
. "$HERE/../lib/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }

pick() { local c; for c in "$@"; do [ -f "$c" ] && { printf '%s' "$c"; return 0; }; done; return 1; }
HOOK="$(pick "$ROOT/core/hooks/ai-dlc-standing-rulings.sh" "$ROOT/.claude/hooks/ai-dlc-standing-rulings.sh")" || { echo "FIXTURE ERROR: ai-dlc-standing-rulings.sh not found in either layout" >&2; exit 2; }
READER="$(pick "$ROOT/core/scripts/standing-rulings.sh" "$ROOT/scripts/ai-dlc/standing-rulings.sh")" || { echo "FIXTURE ERROR: standing-rulings.sh not found in either layout" >&2; exit 2; }
SCHEMA="$(pick "$ROOT/core/schemas/operator-standing-rulings.json" "$ROOT/.claude/schemas/operator-standing-rulings.json")" || { echo "FIXTURE ERROR: operator-standing-rulings.json not found in either layout" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FIXTURE BROKEN: jq not found; the hook fails open without it, so no deny cell could fire" >&2; exit 2; }
printf 'HERMETIC-CONSUMED %s\nHERMETIC-CONSUMED %s\nHERMETIC-CONSUMED %s\n' "$HOOK" "$READER" "$SCHEMA"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/standing-rulings-hook.XXXXXX")" || exit 2

# --- the world, built once -------------------------------------------------------------------------------------
sha() { printf '%s' "$1" | { shasum -a 256 2>/dev/null || sha256sum; } | cut -d' ' -f1; }
build_world() {   # <dir>
  local d="$1" a1="Standing: pull authorisation is pre-granted" a2="Standing: gate check 32 waits for the upstream fix"
  mkdir -p "$d/.claude/hooks" "$d/.claude/schemas" "$d/scripts/ai-dlc" "$d/_bmad-output"
  cp "$HOOK" "$d/.claude/hooks/ai-dlc-standing-rulings.sh"
  cp "$SCHEMA" "$d/.claude/schemas/operator-standing-rulings.json"
  cp "$READER" "$d/scripts/ai-dlc/standing-rulings.sh"
  {
    printf '## 2026-11-01T00:00:01Z -- AskUserQuestion\n- Session: s\n- Tool-use: t1\n- Question (lead-authored, NOT covered by the hash): Pull auth: record as standing? Standing ruling proposal: match=Pull auth; class=update-family\n- Bytes: %s\n- SHA256: %s\n\n```text\n%s\n```\n\n' "${#a1}" "$(sha "$a1")" "$a1"
    printf '## 2026-11-01T00:00:02Z -- AskUserQuestion\n- Session: s\n- Tool-use: t2\n- Question (lead-authored, NOT covered by the hash): Check 32: record as standing? Standing ruling proposal: match=Check 32; class=pipeline-family\n- Bytes: %s\n- SHA256: %s\n\n```text\n%s\n```\n\n' "${#a2}" "$(sha "$a2")" "$a2"
  } > "$d/_bmad-output/operator-answers-history.md"
  printf '### SR-1\n- match: Pull auth\n- ruling: %s\n- source: _bmad-output/operator-answers-history.md:1\n- scope: both\n- status: active\n\n### SR-2\n- match: Check 32\n- ruling: %s\n- source: _bmad-output/operator-answers-history.md:12\n- scope: both\n- status: active\n' "$a1" "$a2" > "$d/_bmad-output/operator-standing-rulings.md"
}
W0="$WORK/w0"; build_world "$W0"
for v in absent malformed noreader outside; do cp -R "$W0" "$WORK/w-$v"; done
sed 's/class=update-family/class=scope-confirmation/' "$W0/_bmad-output/operator-answers-history.md" > "$WORK/w-outside/_bmad-output/oah.tmp" \
  && mv "$WORK/w-outside/_bmad-output/oah.tmp" "$WORK/w-outside/_bmad-output/operator-answers-history.md"
rm -f "$WORK/w-absent/_bmad-output/operator-standing-rulings.md"
printf '### SR-1\n- match: Pull auth\n' > "$WORK/w-malformed/_bmad-output/operator-standing-rulings.md"
rm -f "$WORK/w-noreader/scripts/ai-dlc/standing-rulings.sh"

q() { printf '{"header":"%s","question":"%s"}' "$1" "$2"; }
ask() { printf '{"tool_name":"AskUserQuestion","tool_input":{"questions":[%s]}}' "$1"; }
payload() {
  case "$1" in
    MATCH|ABSENT|MALFORMED|NOREADER|OUTSIDE) ask "$(q 'Pull auth' 'Authorize the pull?')" ;;
    ESCAPE)    ask "$(q 'Pull auth' 'Authorize the pull? not SR-1: this pull rewrites the engine')" ;;
    WRONGESC)  ask "$(q 'Pull auth' 'Authorize the pull? not SR-2: other row')" ;;
    NOREASON)  ask "$(q 'Pull auth' 'Authorize the pull? not SR-1: ')" ;;
    UNMATCH)   ask "$(q 'Other' 'Anything else?')" ;;
    MULTI)     ask "$(q 'Other' 'Anything else?'),$(q 'Check 32' 'Hold the gate?')" ;;
    MULTIESC)  ask "$(q 'Other' 'Anything else?'),$(q 'Check 32' 'Hold the gate? not SR-2: the fix landed')" ;;
    OTHERTOOL) printf '{"tool_name":"Bash","tool_input":{"command":"true"}}' ;;
    *) echo "FIXTURE BROKEN: unknown unit $1" >&2; exit 2 ;;
  esac
}
world_of() { case "$1" in ABSENT) echo "$WORK/w-absent" ;; MALFORMED) echo "$WORK/w-malformed" ;; NOREADER) echo "$WORK/w-noreader" ;; OUTSIDE) echo "$WORK/w-outside" ;; *) echo "$W0" ;; esac; }
lc() { printf '%s' "$1" | tr 'A-Z' 'a-z'; }

# drive <unit>: one start of the hook, tagged ship.<unit> for the invocation judge
drive() {
  local u="$1" w f
  w="$(world_of "$u")"; f="$WORK/ship.$u"
  payload "$u" | AI_DLC_PROJECT_ROOT="$w" bash "$w/.claude/hooks/ai-dlc-standing-rulings.sh" > "$f.out" 2> "$f.err"
  echo "$?" > "$f.rc"
}
UNITS="MATCH ESCAPE WRONGESC NOREASON UNMATCH MULTI MULTIESC OTHERTOOL ABSENT MALFORMED NOREADER OUTSIDE"
MSG=""
verdict() {   # <arm> -> 0 green
  local a="$1" u f out err rc
  case "$a" in REASON|JSON) u=MATCH ;; *) u="$a" ;; esac
  f="$WORK/ship.$u"; out="$(cat "$f.out")"; err="$(cat "$f.err")"; rc="$(cat "$f.rc")"
  MSG="rc=$rc out=[$(printf '%s' "$out" | cut -c1-160)] err=[$err]"
  [ "$rc" = 0 ] && [ -z "$err" ] || return 1
  case "$a" in
    MATCH|WRONGESC|NOREASON|MULTI) case "$out" in *'"permissionDecision":"deny"'*) return 0 ;; esac; return 1 ;;
    JSON) jq -e '.hookSpecificOutput.hookEventName == "PreToolUse" and .hookSpecificOutput.permissionDecision == "deny"' < "$f.out" > /dev/null 2>&1 && return 0; return 1 ;;
    REASON)
      local r; r="$(jq -r '.hookSpecificOutput.permissionDecisionReason' < "$f.out" 2>/dev/null)"
      case "$r" in *"SR-1"*) ;; *) MSG="no SR-1: $MSG"; return 1 ;; esac
      case "$r" in *"Standing: pull authorisation is pre-granted"*) ;; *) MSG="ruling missing: $MSG"; return 1 ;; esac
      case "$r" in *"_bmad-output/operator-answers-history.md:1"*) ;; *) MSG="source missing: $MSG"; return 1 ;; esac
      case "$r" in *'not SR-1: <one-line reason>'*) ;; *) MSG="escape text missing: $MSG"; return 1 ;; esac
      case "$r" in *DECIDED_AUTONOMOUSLY*) return 0 ;; esac; MSG="DECIDED_AUTONOMOUSLY missing: $MSG"; return 1 ;;
    ESCAPE|UNMATCH|MULTIESC|OTHERTOOL|ABSENT|MALFORMED|NOREADER|OUTSIDE) [ -z "$out" ] && return 0; return 1 ;;
  esac
  return 1
}
multi_lists_other() {   # the MULTI reason matches Check 32 and names Other as not held
  local r; r="$(jq -r '.hookSpecificOutput.permissionDecisionReason' < "$WORK/ship.MULTI.out" 2>/dev/null)"
  case "$r" in *'header "Check 32" matches SR-2'*'"Other"'*) return 0 ;; esac; return 1
}

echo "standing-rulings-hook:"
for u in $UNITS; do drive "$u"; done
if verdict MATCH; then ok "MATCH: a header equal to an active sourced row's match is denied"; else bad "MATCH: $MSG"; fi
if verdict REASON; then ok "REASON: the deny cites SR-1, its ruling verbatim, its source, the escape text and DECIDED_AUTONOMOUSLY"; else bad "REASON: $MSG"; fi
if verdict JSON; then ok "JSON: the deny parses as a PreToolUse permissionDecision deny"; else bad "JSON: $MSG"; fi
if verdict ESCAPE; then ok "ESCAPE: the same question carrying not SR-1: <reason> is allowed"; else bad "ESCAPE: $MSG"; fi
if verdict WRONGESC; then ok "WRONGESC: an escape naming another row's number is denied"; else bad "WRONGESC: $MSG"; fi
if verdict NOREASON; then ok "NOREASON: an escape with no reason is denied"; else bad "NOREASON: $MSG"; fi
if verdict UNMATCH; then ok "UNMATCH: a header no row matches is allowed"; else bad "UNMATCH: $MSG"; fi
if verdict MULTI && multi_lists_other; then ok "MULTI: one matched question denies the whole call and names the unmatched header"; else bad "MULTI: $MSG"; fi
if verdict MULTIESC; then ok "MULTIESC: the same call with the matched question escaped is allowed"; else bad "MULTIESC: $MSG"; fi
if verdict OTHERTOOL; then ok "OTHERTOOL: a Bash call is allowed"; else bad "OTHERTOOL: $MSG"; fi
if verdict ABSENT; then ok "ABSENT: no record -> allowed"; else bad "ABSENT: $MSG"; fi
if verdict MALFORMED; then ok "MALFORMED: a malformed record -> allowed"; else bad "MALFORMED: $MSG"; fi
if verdict NOREADER; then ok "NOREADER: no reader installed -> allowed"; else bad "NOREADER: $MSG"; fi
orc=0; oerr="$(AI_DLC_PROJECT_ROOT="$WORK/w-outside" bash "$WORK/w-outside/scripts/ai-dlc/standing-rulings.sh" check 2>&1 >/dev/null)" || orc=$?
if verdict OUTSIDE && [ "$orc" = 1 ] && case "$oerr" in *"Outside list"*) true ;; *) false ;; esac; then ok "OUTSIDE: a row whose proposal names an Outside-list class is refused by check and never denies"; else bad "OUTSIDE: check rc=$orc err=[$oerr] $MSG"; fi

# --- GRAMMAR: the reader's emitter binding, run over the real tree and over a world missing one anchor --------------
EM="core/skills/ai-dlc/steps/requirements.md core/skills/ai-dlc-update/reconcile/apply.sh core/skills/ai-dlc/steps/route-fresh-start.md"
have_em=1; for e in $EM; do [ -f "$ROOT/$e" ] || have_em=0; done
if [ "$have_em" = 1 ]; then
  gout="$(AI_DLC_PROJECT_ROOT="$ROOT" FXCELL=ship.grammar bash "$READER" grammar 2>&1)"; grc=$?
  nok="$(printf '%s\n' "$gout" | grep -c '^ok   ')"
  if [ "$grc" = 0 ] && [ "$nok" -ge 3 ]; then ok "GRAMMAR: the real tree prints an ok line per forbidden-header emitter ($nok)"; else bad "GRAMMAR: rc=$grc ok-lines=$nok out=[$gout]"; fi
  GW="$WORK/gw"; mkdir -p "$GW/.claude/schemas" "$GW/scripts/ai-dlc"
  cp "$SCHEMA" "$GW/.claude/schemas/"; cp "$READER" "$GW/scripts/ai-dlc/"
  for e in $EM; do mkdir -p "$GW/$(dirname "$e")"; cp "$ROOT/$e" "$GW/$e"; done
  sed "s/Re-approve the reconcile report for this pull?/REMOVED/" "$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh" > "$GW/core/skills/ai-dlc-update/reconcile/apply.sh"
  if cmp -s "$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh" "$GW/core/skills/ai-dlc-update/reconcile/apply.sh"; then bad "GRAMMARX: the seeded emitter is identical to the real one; the twin proves nothing"
  else
    xout="$(AI_DLC_PROJECT_ROOT="$GW" bash "$GW/scripts/ai-dlc/standing-rulings.sh" grammar 2>&1)"; xrc=$?
    case "$xout" in *"FAIL update-re-approval"*) [ "$xrc" = 1 ] && ok "GRAMMARX: with one anchor removed, grammar exits 1 and names FAIL update-re-approval" || bad "GRAMMARX: rc=$xrc out=[$xout]" ;; *) bad "GRAMMARX: no FAIL line: rc=$xrc out=[$xout]" ;; esac
  fi
else
  if fx_dist_layout "$HERE"; then bad "GRAMMAR: emitters absent in the distribution layout"
  else echo "SKIP: GRAMMAR and GRAMMARX need the emitters at their distribution paths"; fi
fi

# Clean up by name: every world this run built, never a recursive delete of a variable beyond its own directory.
rm -rf "$WORK"
echo
report_end standing-rulings-hook
