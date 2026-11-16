#!/usr/bin/env bash
# advisor-gate-deny/run.sh — drive the REAL ai-dlc-advisor-gate.sh with synthesized PreToolUse
# JSON over seeded transcripts. The worlds, the cells, the arms and the scorer are in lib.sh
# beside this file; the arms are documented there.
#
# This fixture SHIPS and runs one pass: the shipped hook must fail no arm.
set -uo pipefail
# The pre-push gate exports AI_DLC_* tunables; none is read here, but scrub them all the same.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$HERE/lib.sh" ] || { echo "FIXTURE ERROR: $HERE/lib.sh is absent; no cell exists to score" >&2; exit 2; }
# shellcheck source=lib.sh
. "$HERE/lib.sh"
ARMS="PUSH REASON MCPCONSULT NOGRANT NOGRANTMCP WITHDRAWN ORDER BLOB ERRCLEAR UNAV REARM MERGE CLOSE DELETE MENTION UPDATE UPDATEREF UPDATECUT WRAP STACK BASHC QUOTEDPAT QUOTEDALT PATHGIT BODY QUOTEDC QUOTEDENV GHREPO MCPNAME DETACHED MATE MATEABSENT MATEPUSH MATEPATH MATEREWRITE REDISPATCH DENIED ENVELOPE FAILED REREAD WINDOW BMADONLY SELF SELFLAST PERKIND TWRITE TWRITEREAD GATELOG NOVERIFY HDRONLY FAILOPEN EXIT"

echo "advisor-gate-deny:"
printf '  hook  %s\n' "$HOOK"
printf '  cells %s\n' "$nc"

printf 'HERMETIC-CONSUMED %s\n' "$HOOK"
[ -x "$HOOK" ] || bad "hook is not executable: $HOOK -- settings.json invokes it as a bare path"
# NET_CELLS=1 for the shipped hook only: rr-never pays its ADVISOR_GATE_NET-shortened safety net once, here (lib.sh REREAD).
GOT="$(NET_CELLS=1 score "$HOOK" "$W/failed.shipped")"
if [ -z "$GOT" ]; then
  ok "shipped hook passes every arm (PUSH REASON MCPCONSULT NOGRANT NOGRANTMCP WITHDRAWN ORDER BLOB ERRCLEAR UNAV REARM MERGE CLOSE DELETE MENTION UPDATE UPDATEREF UPDATECUT WRAP STACK BASHC QUOTEDPAT QUOTEDALT PATHGIT BODY QUOTEDC QUOTEDENV GHREPO MCPNAME DETACHED MATE MATEABSENT MATEPUSH MATEPATH MATEREWRITE REDISPATCH DENIED ENVELOPE FAILED REREAD WINDOW BMADONLY SELF SELFLAST PERKIND TWRITE TWRITEREAD GATELOG NOVERIFY HDRONLY FAILOPEN EXIT)"
else
  bad "shipped hook fails arm(s): $GOT [cells: $(cells_of "$W/failed.shipped")]"
fi

[ -f "$PROV" ] && printf 'HERMETIC-CONSUMED %s\n' "$PROV"

# NOLIB: the detection library (BL-1136) beside the hook is what every arm above ran through. A copy
# of the hook with no library beside it must WARN on stderr and stay SILENT on a cell the shipped hook
# DENIES (PUSH's first cell, scored above as the control).
DETECT="$(dirname "$HOOK")/ai-dlc-advisor-detect.sh"
[ -f "$DETECT" ] && printf 'HERMETIC-CONSUMED %s\n' "$DETECT"
[ -f "$DETECT" ] || bad "the detection library is not beside the hook: $DETECT"
mkdir -p "$W/nolib" && cp "$HOOK" "$W/nolib/ai-dlc-advisor-gate.sh" || bad "could not copy the hook for NOLIB"
_nlc="$(awk -F'\t' '$2 == "PUSH:1" { print $1 }' "$MAN")"
if [ -z "$_nlc" ] || [ -e "$W/nolib/ai-dlc-advisor-detect.sh" ]; then
  bad "NOLIB cannot express the case (PUSH cell '$_nlc', or a library beside the copy)"
else
  ADVISOR_GATE_REREADS=0 ADVISOR_GATE_WINDOW=0 HOME="$W" CLAUDE_PROJECT_DIR="$CPD" bash "$W/nolib/ai-dlc-advisor-gate.sh" < "$CELLS/$_nlc.json" > "$W/nolib/out" 2> "$W/nolib/err"
  if [ -s "$W/nolib/out" ]; then bad "NOLIB: the hook without its library printed a decision"
  elif grep -q 'WARN: the advisor detection library is unreadable' "$W/nolib/err"; then ok "NOLIB: the hook without its library warns on stderr and is silent"
  else bad "NOLIB: the hook without its library gave no stderr WARN"; fi
fi
echo
if [ "$fails" -eq 0 ]; then echo "advisor-gate-deny: PASS"; exit 0; fi
echo "advisor-gate-deny: $fails assertion(s) FAILED" >&2
exit 1
