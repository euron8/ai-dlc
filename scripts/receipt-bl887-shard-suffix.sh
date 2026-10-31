#!/usr/bin/env bash
# scripts/receipt-bl887-shard-suffix.sh [<validator> [<hook>]] -- the BL-887 backlog receipt: a
# one-cross shard line whose ordinal list is COMPLETE but followed by a prose suffix is not an
# omission, by the Check 22 arm S4 validator as much as by the dispatch guard COVER DENY.
#
# Drives core/scripts/validate-spawn-ledger.sh (or <validator>) on seeded ledgers, and
# core/hooks/ai-dlc-dispatch-guard.sh (or <hook>) as a lead Agent dispatch of the shardable role
# `remediator` in a seeded consumer (.claude/.ai-dlc-version, .claude/settings.json,
# .claude/team-roles/remediator.md, _bmad-output/). A copy of a hook is driven from a copy of its
# whole directory, because the hook resolves siblings beside itself.
#
# Scoring. A hook ALLOW is a drive that printed no deny AND appended exactly one ledger row (after
# one epoch row) whose .shard equals the canonical value; a silent exit with no row is never an
# ALLOW. A hook DENY is a deny decision whose reason contains the stated text AND no appended row.
# A validator PASS is exit 0 with its S4 line printed; a FAIL is exit 1 naming the S4 refusal.
#
# Worlds, K=8 throughout unless stated:
#   P   plain `1,2,3,4,5,6,7,8`                  hook ALLOW, validator PASS   (the control)
#   S1  complete list + ` (you are the ONE cross QA ...)`      ALLOW / PASS
#   S2  complete list + ` -- all sections`, an em dash         ALLOW / PASS
#   S3  complete list + `. Step test-strategy-p3. Brief: x`    ALLOW / PASS  (a period suffix)
#   S4  SPACED list `1, 2, ..., 8` + ` (note)`, the second correct spelling   ALLOW / PASS
#   G   gap `1,...,7` + ` (note)`   hook DENY naming `omits part(s) 8 of 1..8`; validator FAIL
#   N   no list, `all sections`     hook DENY `omits part(s) 1..8 of 1..8`... every part; validator FAIL
#   E   an empty token `1,2,,4,5,6,7,8` + ` (note)`            DENY / FAIL
#   T   a trailing comma then a suffix `1,...,8, all sections` (decided edge)   DENY / FAIL
#   D   a digit-led suffix `1,...,8 2 reviewers` (decided edge)                DENY / FAIL
#
# Exit 0 when every world holds on both subjects. 1 when any does not (the defect still
# reproduces, or a regression refuses/accepts wrongly). 9 when it cannot measure: no jq, no repo
# root, no subject, a seed that failed, or the control P that did not hold.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
r887_root() { # walk up from $1 for a repository marker; never count hops
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -f "$d/core/scripts/validate-spawn-ledger.sh" ] || [ -e "$d/.git" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
cant() { echo "receipt-bl887: cannot measure: $*" >&2; exit 9; }
ROOT="$(r887_root "$HERE")" || ROOT=""
[ -n "$ROOT" ] || cant "no repository root above $HERE"
command -v jq >/dev/null 2>&1 || cant "jq absent"
VAL="${1:-$ROOT/core/scripts/validate-spawn-ledger.sh}"
HOOK="${2:-$ROOT/core/hooks/ai-dlc-dispatch-guard.sh}"
[ -f "$VAL" ] || cant "no validator at $VAL"
[ -f "$HOOK" ] || cant "no hook at $HOOK"

PARENT="$(mktemp -d "${TMPDIR:-/tmp}/bl887-receipt.XXXXXX" 2>/dev/null)" || PARENT=""
[ -n "$PARENT" ] && [ -d "$PARENT" ] || cant "mktemp -d failed"
trap 'case "$PARENT" in */bl887-receipt.??????) rm -rf "$PARENT" ;; esac' EXIT

# The consumer the hook runs in.
CONS="$PARENT/consumer"
mkdir -p "$CONS/.claude/team-roles" "$CONS/_bmad-output"
printf 'version: 0.70.0\ncommit: receipt\n' > "$CONS/.claude/.ai-dlc-version"
cat > "$CONS/.claude/settings.json" <<'SETTINGS'
{
  "aiDlcModels": { "opus": "claude-opus-5[1m]", "sonnet": "claude-sonnet-5[1m]" },
  "aiDlcRoles": {
    "gate-adjudicator": { "model": "opus", "effort": "high" },
    "remediator":       { "model": "opus", "effort": "high" }
  }
}
SETTINGS
printf '# Role: remediator\n\nThe remediator role.\n' > "$CONS/.claude/team-roles/remediator.md"
printf '# Role: gate-adjudicator\n\nThe adjudicator role.\n' > "$CONS/.claude/team-roles/gate-adjudicator.md"
printf -- '- **sprint_id:** 291\n' > "$CONS/_bmad-output/pipeline-snapshot.md"
LEDGER="$CONS/_bmad-output/spawn-ledger.jsonl"

# A hook under test runs from a copy of its whole directory (siblings resolve beside it).
HCOPY="$PARENT/hooks"
mkdir -p "$HCOPY"
cp -R "$(dirname "$HOOK")/." "$HCOPY/" 2>/dev/null || cant "hook directory copy failed"
HOOKC="$HCOPY/$(basename "$HOOK")"
[ -f "$HOOKC" ] || cant "hook copy missing"

payload() { # payload <role> [<brief line>] -> an Agent dispatch of <role> carrying the line
  local p; p="Your operating contract is \`.claude/team-roles/$1.md\`. Read it first."
  [ -n "${2-}" ] && p="$p"$'\n'"$2"
  jq -nc --arg p "$p"$'\n'"Do the work." '{tool_name:"Agent",tool_input:{name:"bl887",prompt:$p}}'
}

HDEC=""; HREASON=""; HROWS=0; HSHARD=""
hdrive() { # hdrive <shard value, after the "shard: " key> -> sets HDEC, HREASON, HROWS, HSHARD
  local out
  rm -f "$LEDGER"
  payload gate-adjudicator | CLAUDE_PROJECT_DIR="$CONS" bash "$HOOKC" >/dev/null 2>&1
  out="$(payload remediator "shard: $1" | CLAUDE_PROJECT_DIR="$CONS" bash "$HOOKC" 2>/dev/null)"
  HDEC="$(jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$out" 2>/dev/null)" || HDEC=none
  [ -n "$HDEC" ] || HDEC=none
  HREASON="$(jq -r '.hookSpecificOutput.permissionDecisionReason // ""' <<<"$out" 2>/dev/null)" || HREASON=""
  HROWS="$(wc -l < "$LEDGER" 2>/dev/null | tr -d ' ')"; HROWS="${HROWS:-0}"; HROWS=$((HROWS - 1))
  HSHARD=""
  if [ "$HROWS" = 1 ]; then HSHARD="$(tail -1 "$LEDGER" | jq -r '.shard | tostring' 2>/dev/null)" || HSHARD=""; fi
}

# The validator's world: an epoch row, then one adversary row carrying the shard value.
cat > "$PARENT/vsettings.json" <<'JSON'
{ "aiDlcModels": { "opus": "claude-opus-5[1m]" }, "aiDlcRoles": { "adversary": { "model": "opus" } } }
JSON
VOUT=""; VRC=0
vdrive() { # vdrive <canonical shard value> -> sets VRC, VOUT
  local l="$PARENT/v.jsonl"
  jq -nc '{v:1,sprint:900,name:"epoch",role:"dev",model_bound:"sonnet",model_requested:"sonnet",role_contract_cited:true,role_file_readable:true}' > "$l"
  jq -nc --arg s "$1" '{v:1,sprint:900,name:"bl887",role:"adversary",model_bound:"opus",model_requested:"opus",
    role_contract_cited:true,role_file_readable:true,shard:$s,tool_use_id:"toolu_BL887"}' >> "$l"
  VOUT="$(bash "$VAL" --ledger "$l" --sprint 900 --settings "$PARENT/vsettings.json" 2>&1)"; VRC=$?
}

fails=0
note() { echo "receipt-bl887: $*"; }
failw() { note "FAIL $*"; fails=$((fails + 1)); }

# world <name> <list+suffix, after "cross/<K> g1/1 "> <K> <allow|deny> [<deny reason text>]
world() {
  local name="$1" tail="$2" k="$3" want="$4" reason="${5-}"
  local canon="cross/$k g1/1 $tail" okh=1 okv=1
  hdrive "$canon"
  if [ "$want" = allow ]; then
    { [ "$HDEC" != deny ] && [ "$HROWS" = 1 ] && [ "$HSHARD" = "$canon" ]; } || okh=0
  else
    { [ "$HDEC" = deny ] && [ "$HROWS" = 0 ]; } || okh=0
    case "$HREASON" in *"$reason"*) ;; *) okh=0 ;; esac
  fi
  vdrive "$canon"
  if [ "$want" = allow ]; then
    { [ "$VRC" = 0 ] && grep -qF 'cover (S4)' <<<"$VOUT" && ! grep -qF 'does not name every section' <<<"$VOUT"; } || okv=0
  else
    { [ "$VRC" = 1 ] && grep -qF 'does not name every section' <<<"$VOUT"; } || okv=0
  fi
  if [ "$okh" = 1 ] && [ "$okv" = 1 ]; then
    note "ok   $name: hook $want, validator $([ "$want" = allow ] && echo PASS || echo FAIL)"
  else
    [ "$okh" = 1 ] || failw "$name hook: want $want${reason:+ naming '$reason'}; got decision=$HDEC rows=$HROWS shard='$HSHARD' reason='$(printf '%s' "$HREASON" | cut -c1-160)'"
    [ "$okv" = 1 ] || failw "$name validator: want $([ "$want" = allow ] && echo PASS || echo FAIL); got rc=$VRC"
  fi
}

# P first: a plain complete list must be allowed and pass, or the drive measures nothing.
hdrive "cross/8 g1/1 1,2,3,4,5,6,7,8"
{ [ "$HDEC" != deny ] && [ "$HROWS" = 1 ] && [ "$HSHARD" = "cross/8 g1/1 1,2,3,4,5,6,7,8" ]; } \
  || cant "control P (plain complete list) was not allowed with one row: decision=$HDEC rows=$HROWS shard='$HSHARD'"
vdrive "cross/8 g1/1 1,2,3,4,5,6,7,8"
{ [ "$VRC" = 0 ] && grep -qF 'cover (S4)' <<<"$VOUT"; } \
  || cant "control P (plain complete list) did not PASS the validator: rc=$VRC"
# The control that the drive CAN deny: a plain gap, no suffix.
hdrive "cross/8 g1/1 1,2,3,4,5,6,7"
{ [ "$HDEC" = deny ] && [ "$HROWS" = 0 ]; } || cant "control (plain gap) did not DENY: decision=$HDEC rows=$HROWS"

L8="1,2,3,4,5,6,7,8"
world S1 "$L8 (you are the ONE cross QA for this sprint)" 8 allow
world S2 "$L8 — all sections" 8 allow
world S3 "$L8. Step test-strategy-p3. Brief: x" 8 allow
world S4 "1, 2, 3, 4, 5, 6, 7, 8 (note)" 8 allow
world G "1,2,3,4,5,6,7 (you are the ONE cross QA)" 8 deny "omits part(s) 8 of 1..8"
world N "all sections" 8 deny "omits part(s) 1,2,3,4,5,6,7,8 of 1..8"
world E "1,2,,4,5,6,7,8 (note)" 8 deny "omits part(s) 1,2,3,4,5,6,7,8 of 1..8"
world T "$L8, all sections" 8 deny "omits part(s) 1,2,3,4,5,6,7,8 of 1..8"
world D "$L8 2 reviewers" 8 deny "omits part(s) 1,2,3,4,5,6,7,8 of 1..8"

[ "$fails" -eq 0 ] || exit 1
exit 0
