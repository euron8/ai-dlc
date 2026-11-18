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
  ADVISOR_GATE_REREADS=0 ADVISOR_GATE_WINDOW=0 HOME="$W" CLAUDE_PROJECT_DIR="$CPD" adg_ip "$W/nolib/ai-dlc-advisor-gate.sh" < "$CELLS/$_nlc.json" > "$W/nolib/out" 2> "$W/nolib/err"
  if [ -s "$W/nolib/out" ]; then bad "NOLIB: the hook without its library printed a decision"
  elif grep -q 'WARN: the advisor detection library is unreadable' "$W/nolib/err"; then ok "NOLIB: the hook without its library warns on stderr and is silent"
  else bad "NOLIB: the hook without its library gave no stderr WARN"; fi
fi

# --- the cli cells (cells.decl): the hook run as a PROGRAM once per distinct CLI outcome -------------------------
# The hook exits 0 on every path, so its outcomes are output classes: a deny decision on stdout, a WARN
# (additionalContext, no decision), silence, and silence with the fail-open reason on stderr. Each is one
# `FXCELL=<id> bash "$HOOK"` start on a plain cell's payload (no append, sequence, window, net, fast or consumer
# file), compared byte for byte with the in-process call on the same payload and the same knobs: stdout, stderr and
# exit separately. Each cell also asserts its own outcome, so two runs that both printed nothing cannot read as equal.
EQ="$W/eq"; mkdir -p "$EQ" || { echo "FIXTURE ERROR: mkdir $EQ" >&2; exit 2; }
plain_cell() { # <want> <check glob> -> the first manifest cell with that verdict and check and no side file
  local n id check arm want x
  while IFS=$'\t' read -r n id check arm want; do
    [ "$want" = "$1" ] || continue
    case "$check" in $2) ;; *) continue ;; esac
    for x in app seq win net fast cpd; do [ ! -f "$CELLS/$n.$x" ] || continue 2; done
    printf '%s' "$n"; return 0
  done < "$MAN"
}
eqv() { # <cell-id> <manifest cell> -> $EQ/<id>.{ip,cl}.{out,err,rc}; 0 when the two agree byte for byte
  local id="$1" n="$2"
  ADVISOR_GATE_REREADS=0 ADVISOR_GATE_WINDOW=0 HOME="$W" CLAUDE_PROJECT_DIR="$CPD" adg_ip "$HOOK" < "$CELLS/$n.json" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  ADVISOR_GATE_REREADS=0 ADVISOR_GATE_WINDOW=0 HOME="$W" CLAUDE_PROJECT_DIR="$CPD" FXCELL="$id" bash "$HOOK" < "$CELLS/$n.json" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_twin() { printf 'in-process rc=%s out=%sB err=%sB / program rc=%s out=%sB err=%sB' "$(cat "$EQ/$1.ip.rc")" "$(wc -c < "$EQ/$1.ip.out" | tr -d ' ')" \
  "$(wc -c < "$EQ/$1.ip.err" | tr -d ' ')" "$(cat "$EQ/$1.cl.rc")" "$(wc -c < "$EQ/$1.cl.out" | tr -d ' ')" "$(wc -c < "$EQ/$1.cl.err" | tr -d ' ')"; }
# <cell-id> <want> <check glob> <outcome test on the program's files> <outcome words>
cli_cell() {
  local id="$1" n; n="$(plain_cell "$2" "$3")"
  if [ -z "$n" ]; then bad "$id: no plain $2 cell in the manifest to run as a program"; return; fi
  if eqv "$id" "$n" && [ "$(cat "$EQ/$id.cl.rc")" = 0 ] && eval "$4"; then
    ok "$id: the program gives $5 exactly as the in-process call does (cell $n; stdout, stderr, exit 0)"
  else
    bad "$id: the program and the in-process call differ, or the outcome is not $5 (cell $n; $(eq_twin "$id"))"
  fi
}
cli_cell cli-deny DENY '*' 'grep -q "\"permissionDecision\": \"deny\"" "$EQ/$id.cl.out"' "a deny decision on stdout"
cli_cell cli-warn WARN '*' 'grep -q "NOT blocked" "$EQ/$id.cl.out" && ! grep -q permissionDecision "$EQ/$id.cl.out"' "a WARN with no decision"
cli_cell cli-allow SILENT '-' '[ ! -s "$EQ/$id.cl.out" ] && [ ! -s "$EQ/$id.cl.err" ]' "silence on both streams"
cli_cell cli-failopen SILENT 'E:*' '[ ! -s "$EQ/$id.cl.out" ] && grep -q "ai-dlc-advisor-gate: " "$EQ/$id.cl.err"' "silence with the fail-open reason on stderr"
echo
if [ "$fails" -eq 0 ]; then echo "advisor-gate-deny: PASS"; exit 0; fi
echo "advisor-gate-deny: $fails assertion(s) FAILED" >&2
exit 1
