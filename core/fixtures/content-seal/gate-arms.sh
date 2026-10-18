#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# content-seal/gate-arms.sh -- the content seal and the DERIVED adjudicator id at
# `validate-gate-adjudication.sh --merge`. Driven by run.sh.
# Each world: a gate's escalated set (read from the validator's own --expected, never hand-listed)
# split across two part files, each written by a gate-adjudicator whose meta file and spawn-ledger
# row say so, and each sealed by driving the REAL recorder with the subagent's PostToolUse payload.
set -uo pipefail
NAME="content-seal-gate"
CS_HERE="$(cd "$(dirname "$0")" && pwd)"
# The validator, its schema and the map, found by walking UP in both layouts; never by counting `..`.
V=""; SCHEMA=""; MAP=""
_d="$CS_HERE"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  if [ -f "$_d/core/scripts/validate-gate-adjudication.sh" ]; then
    V="$_d/core/scripts/validate-gate-adjudication.sh"; SCHEMA="$_d/core/schemas/gate-adjudication-verdict.json"
    MAP="$_d/core/skills/ai-dlc/enforcement-map.yaml"; break
  elif [ -f "$_d/scripts/ai-dlc/validate-gate-adjudication.sh" ]; then
    V="$_d/scripts/ai-dlc/validate-gate-adjudication.sh"; SCHEMA="$_d/.claude/schemas/gate-adjudication-verdict.json"
    MAP="$_d/.claude/skills/ai-dlc/enforcement-map.yaml"; break
  fi
  _d="$(dirname "$_d")"
done
[ -n "$V" ] && [ -f "$SCHEMA" ] && [ -f "$MAP" ] || { echo "FIXTURE ERROR: validate-gate-adjudication.sh, its schema or the enforcement map not found above $CS_HERE; nothing was asserted" >&2; exit 2; }
command -v jq >/dev/null 2>&1 && command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq or python3 absent" >&2; exit 2; }
SRCDIR="$(cd "$(dirname "$V")" && pwd)"
. "$CS_HERE/seal-lib.sh"
echo "HERMETIC-CONSUMED $V"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/$NAME.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT
fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
TOKEN="changed after its last sealed write"
GT=implementation; NONCE=implementation-20261017T120000Z
IDS="$(AI_DLC_ENFORCEMENT_MAP="$MAP" AI_DLC_VERDICT_SCHEMA="$SCHEMA" bash "$V" --expected "$GT")" || { echo "FIXTURE ERROR: --expected failed" >&2; exit 2; }
NIDS="$(printf '%s\n' $IDS | grep -c .)"
[ "$NIDS" -ge 2 ] || { echo "FIXTURE ERROR: the $GT gate escalates $NIDS check(s); two parts need two" >&2; exit 2; }
A1=a0000000000000001; A2=a0000000000000002

# world -> a fresh root. Env knobs, each scoped to one call: SELF (both parts' self-reported id),
# SELF1/SELF2 (one part's), NOSEAL=1 (no seal rows: today's tree).
world() {
  local w i k aid tuid tp half cid self
  w="$(mktemp -d "$WORK/g.XXXXXX")" || return 1
  mkdir -p "$w/_bmad-output/gate-adjudication" "$w/_bmad-output/planning-artifacts" "$w/.harness/sess/subagents" || return 1
  tp="$w/.harness/sess.jsonl"; half=$(( (NIDS + 1) / 2 )); k=0
  : > "$w/p1"; : > "$w/p2"
  for cid in $IDS; do
    k=$((k + 1)); i=1; [ "$k" -gt "$half" ] && i=2
    if [ "$i" = 1 ]; then self="${SELF1-${SELF-gate-adjudicator}}"; else self="${SELF2-${SELF-gate-adjudicator}}"; fi
    jq -nc --arg n "$NONCE" --arg s "$self" --arg c "$cid" \
      '{gate_nonce:$n, gate_series_id:"implementation-s1-20261017T110000Z", catalog:"core", adjudicator_agent_id:$s,
        check_id:$c, verdict:"PASS", evidence:("fixture evidence for " + $c)}' >> "$w/p$i"
  done
  for i in 1 2; do
    mv "$w/p$i" "$w/_bmad-output/gate-adjudication/$NONCE.part-${i}of2.jsonl"
    aid="a000000000000000$i"; tuid="toolu_01GateAdjDispatch00000000$i"
    printf '{"toolUseId":"%s"}\n' "$tuid" > "$w/.harness/sess/subagents/agent-$aid.meta.json"
    printf '{"v":1,"ts":"2026-10-17T12:01:00Z","role":"gate-adjudicator","tool_use_id":"%s"}\n' "$tuid" >> "$w/_bmad-output/spawn-ledger.jsonl"
    [ "${NOSEAL:-0}" = 1 ] && continue
    seal_hook "$w" Write "$w/_bmad-output/gate-adjudication/$NONCE.part-${i}of2.jsonl" "$aid" "$tp"
  done
  printf '%s' "$w"
}
gmerge() { # <root> -> RC, OUT, VJ
  local d="$1/_bmad-output/gate-adjudication"
  VJ="$d/$NONCE.verdict.json"
  OUT="$(AI_DLC_ENFORCEMENT_MAP="$MAP" AI_DLC_VERDICT_SCHEMA="$SCHEMA" bash "$V" --merge "$GT" "$VJ" "$d/$NONCE.part-1of2.jsonl" "$d/$NONCE.part-2of2.jsonl" 2>&1)"; RC=$?
}
part_of() { printf '%s' "$1/_bmad-output/gate-adjudication/$NONCE.part-$2of2.jsonl"; }

echo "$NAME:"

# CS-G0: control, unsealed parts with a real-shaped self id merge as written (today's path).
w="$(NOSEAL=1 SELF=a0123456789abcdef world)"; gmerge "$w"
if [ "$RC" = 0 ] && grep -q '"adjudicator_agent_id": "a0123456789abcdef"' "$VJ"; then ok "CS-G0: unsealed parts merge with the self-reported id as written (the control)"
else bad "CS-G0: the unsealed control did not merge as written (rc=$RC): $(printf '%s' "$OUT" | head -2)"; fi

# CS-G1: sealed parts carrying an INVENTED self id (`gate-adjudicator`, the s319 second instance)
# -> MERGED with the DERIVED ids; the invented one is absent from the verdict.
w="$(world)"; gmerge "$w"
if [ "$RC" = 0 ] && grep -q "\"adjudicator_agent_id\": \"$A1, $A2\"" "$VJ" && ! grep -q 'gate-adjudicator"' "$VJ"; then
  ok "CS-G1: sealed parts self-reporting 'gate-adjudicator': MERGED with the derived ids $A1, $A2; the invented id is absent"
else bad "CS-G1: the derived id was not merged (rc=$RC, verdict id: $(grep adjudicator_agent_id "$VJ" 2>/dev/null)): $(printf '%s' "$OUT" | head -2)"; fi
if grep -q '"actor":"program:validate-gate-adjudication"' "$w/_bmad-output/planning-artifacts/.artifact-writes.jsonl" 2>/dev/null; then
  ok "CS-G1b: --merge appended its own program seal row"
else bad "CS-G1b: no program:validate-gate-adjudication seal row after a sealed --merge"; fi

# CS-G2: the control for CS-G1 -- a REAL-SHAPED self id that differs from the derived one -> REFUSED.
w="$(SELF=a0123456789abcdef world)"; gmerge "$w"
if [ "$RC" = 2 ] && grep -q "self-reports adjudicator_agent_id 'a0123456789abcdef'" <<< "$OUT" && [ ! -e "$VJ" ]; then
  ok "CS-G2: a real-shaped self id differing from the derived one: REFUSED, nothing written"
else bad "CS-G2: a real-shaped differing self id was not refused (rc=$RC): $(printf '%s' "$OUT" | head -2)"; fi
# CS-G2b, its ALLOW twin: real-shaped self ids EQUAL to the derived ones -> MERGED.
w="$(SELF1=$A1 SELF2=$A2 world)"; gmerge "$w"
if [ "$RC" = 0 ] && grep -q "\"adjudicator_agent_id\": \"$A1, $A2\"" "$VJ"; then ok "CS-G2b: real-shaped self ids equal to the derived ones: MERGED"
else bad "CS-G2b: equal real-shaped self ids did not merge (rc=$RC): $(printf '%s' "$OUT" | head -2)"; fi

# CS-G3: a python3 open-for-write of a sealed part (the s319 adjudicator's interpreter write) ->
# REFUSED, naming the part and its sealed writer.
w="$(world)"; pt="$(part_of "$w" 2)"
python3 -c "import sys;p=sys.argv[1];t=open(p).read();open(p,'w').write(t.replace('gate-adjudicator','$A2'))" "$pt"
gmerge "$w"
if [ "$RC" = 2 ] && grep -q "part-2of2.jsonl $TOKEN" <<< "$OUT" && grep -q "agent $A2 (Write)" <<< "$OUT" && [ ! -e "$VJ" ]; then
  ok "CS-G3: python3 open-for-write of a sealed part: REFUSED naming the part and agent $A2"
else bad "CS-G3: a python3 rewrite of a sealed part was not refused (rc=$RC): $(printf '%s' "$OUT" | head -2)"; fi

# CS-G4: D2, a part with NO seal row once the recorder was live. Parts written through python3 only
# (NOSEAL=1), so neither carries a row; another file in the tree is sealed by the REAL recorder, whose
# row is stamped now. Three cells, one property apart:
#   refuse  the nonce is AFTER that row (minted an hour ahead) -> REFUSED naming the part, nothing written
#   merge   the nonce is BEFORE that row (the fixed past nonce) -> MERGED: a gate older than the recorder
#   merge   the same future nonce, no seal row anywhere in the ledger -> MERGED
seal_other() { # <world> -- one tool seal row on a file outside the gate dir
  local f="$1/_bmad-output/planning-artifacts/s1/shards/stories-p1/1.md"
  mkdir -p "${f%/*}" && printf 'an adversary shard\n' > "$f" && seal_hook "$1" Write "$f" "$A1"
}
FUT="$GT-$(python3 -c 'import time; print(time.strftime("%Y%m%dT%H%M%SZ", time.gmtime(time.time() + 3600)))')"
PAST="$NONCE"
w="$(NONCE="$FUT" NOSEAL=1 world)"; seal_other "$w"; NONCE="$FUT" gmerge "$w"
nr="$(seal_count "$w/_bmad-output/planning-artifacts/.artifact-writes.jsonl")"
if [ "$RC" = 2 ] && grep -q "part-1of2.jsonl carries no content-seal row" <<< "$OUT" && grep -q "Re-dispatch the gate-adjudicator" <<< "$OUT" && [ "$nr" -ge 1 ] && [ ! -e "$VJ" ]; then
  ok "CS-G4: a part with no seal row, nonce after the tree's first tool seal: REFUSED naming the part, nothing written"
else bad "CS-G4: a sealless part after the recorder existed was not refused (rc=$RC, seal rows $nr): $(printf '%s' "$OUT" | head -2)"; fi
w="$(NONCE="$PAST" NOSEAL=1 world)"; seal_other "$w"; NONCE="$PAST" gmerge "$w"
if [ "$RC" = 0 ] && [ -f "$VJ" ]; then ok "CS-G4b: the same sealless parts, nonce before the first tool seal: MERGED (a gate older than the recorder)"
else bad "CS-G4b: a sealless part whose nonce predates the first seal did not merge (rc=$RC): $(printf '%s' "$OUT" | head -2)"; fi
w="$(NONCE="$FUT" NOSEAL=1 world)"; NONCE="$FUT" gmerge "$w"
if [ "$RC" = 0 ] && [ -f "$VJ" ]; then ok "CS-G4c: the same sealless parts and future nonce, a ledger with no seal rows: MERGED"
else bad "CS-G4c: sealless parts with no seal row in the ledger did not merge (rc=$RC): $(printf '%s' "$OUT" | head -2)"; fi

echo "$NAME: $fails failure(s)"
[ "$fails" -eq 0 ]
