#!/usr/bin/env bash
# scripts/receipt-bl837-unbound-acquittal.sh [<hook>] -- the BL-837 backlog receipt: an UNBOUND
# gate verdict may convict but never acquit, by the arm-7b SUPPRESSED cover as much as by an
# empty fail set.
#
# Drives core/hooks/ai-dlc-gate-remediation-guard.sh (or <hook>) as a lead Edit of a planning
# artifact, on four worlds seeded from core/fixtures/gate-remediation-deny/seed.sh's `suppressed`
# case (sibling, catalog, citation verifier, transcript corpus, one genuine in-force entry
# suppressing `[core] 7`), with that case's verdict replaced. Every world gets the same spawn
# ledger: a gate-adjudicator dispatch at 19:31:00Z, which binds a 19:30:44Z nonce, and a
# remediator row at 20:55:00Z. Nothing binds 20:00:00Z or 21:00:00Z.
#
#   A  the BL-837 forgery. 19:30:44Z bound, plain FAIL on 7 and 3a; 21:00:00Z unbound, plain FAIL
#      on 7 only, which the entry covers. Want DENY naming 3a, and GATE_VERDICT_UNBOUND logged.
#   B  the `BOUND_STEM`-only read. 19:30:44Z bound and CLEAN; 20:00:00Z unbound, plain FAIL on 3a;
#      21:00:00Z unbound and CLEAN. Want DENY naming 3a, and GATE_VERDICT_UNBOUND logged. A guard
#      that substitutes only the newest bound pass finds it clean and allows without a word.
#   T  the ALLOW twin. As A, but the bound pass fails on 7 alone, so every FAIL in every pass is
#      covered. Want ALLOW, and GATE_VERDICT_UNBOUND still logged. This is the world that separates
#      re-partitioning the substitute against the SUPPRESSED cover from convicting on its raw
#      FAILs, and the one a guard that denies every covered pass fails.
#   C  the convict CONTROL. A with the 21:00:00Z pass removed: a bound live pass with an uncovered
#      FAIL. Base and fix both DENY. When it does not, the drive never reached the deny and this
#      receipt has measured nothing.
#
#   D  world A plus an old verdict file whose stem carries a space. Want DENY naming 3a.
#   D2 world T plus an IN-WINDOW verdict file whose stem carries a space and which records an
#      uncovered FAIL. Want DENY.
#   Z  world T plus an IN-WINDOW zero-byte verdict file with a safe stem. Want DENY.
#   U  world T plus an IN-WINDOW truncated verdict file that does not parse. Want DENY.
#   N  world T plus an IN-WINDOW file that parses to `null`. Want DENY.
#   TR an in-window file holding an object then a bare `1`, and a live pass failing 3a. Want DENY
#      naming 3a, with the live file not named unreadable.
#   L1, R8, R8-both  seed.sh's `subst-nobound-older-fail`, `subst-repair-unbound` and
#      `subst-repair-both`, driven as seeded; each is described where it is driven, below.
#
# Exit 0 when A, B, T, D, D2, Z, U, N, TR, L1, R8 and R8-both all hold. 1 when any of them does not (the defect still reproduces).
# 9 when it cannot measure: no jq, no python3, no repository root, no seed or hook, a seed that
# failed, or a control C that did not deny. Behaviour only: no hook text or line is read.
#
# Each world is seeded fresh. The guard caches arm 7b's rows on a key that does not include the
# hook itself, so a world driven twice is not driven twice.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
r837_root() { # walk up from $1 for a repository marker; never count hops
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -f "$d/core/fixtures/gate-remediation-deny/seed.sh" ] || [ -e "$d/.git" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
ROOT="$(r837_root "$HERE")" || ROOT=""
cant() { echo "receipt-bl837: cannot measure: $*" >&2; exit 9; }
[ -n "$ROOT" ] || cant "no repository root above $HERE"
command -v jq >/dev/null 2>&1 || cant "jq absent"
command -v python3 >/dev/null 2>&1 || cant "python3 absent"
SEED="$ROOT/core/fixtures/gate-remediation-deny/seed.sh"
HOOK="${1:-$ROOT/core/hooks/ai-dlc-gate-remediation-guard.sh}"
[ -f "$SEED" ] || cant "no seed at $SEED"
[ -f "$HOOK" ] || cant "no hook at $HOOK"

PARENT="$(mktemp -d "${TMPDIR:-/tmp}/bl837-receipt.XXXXXX" 2>/dev/null)" || PARENT=""
[ -n "$PARENT" ] && [ -d "$PARENT" ] || cant "mktemp -d failed"
trap 'case "$PARENT" in */bl837-receipt.??????) rm -rf "$PARENT" ;; esac' EXIT

GD="_bmad-output/gate-adjudication"
ART="_bmad-output/planning-artifacts/s302/test-strategy.md"

world() { # <name> -- sets W to a fresh `suppressed` world with no verdict
  W="$(TMPDIR="$PARENT" bash "$SEED" suppressed 2>/dev/null)" || W=""
  [ -n "$W" ] && [ -d "$W/$GD" ] || cant "seed.sh suppressed failed for world $1"
  rm -f "$W/$GD"/*.verdict.json
  printf '%s\n%s\n' \
    '{"v":1,"ts":"2026-08-11T19:31:00Z","sprint":302,"name":"gate-adjudicator-s302-story-real","role":"gate-adjudicator"}' \
    '{"v":1,"ts":"2026-08-11T20:55:00Z","sprint":302,"name":"remediator-s302-1","role":"remediator"}' \
    > "$W/_bmad-output/spawn-ledger.jsonl"
}
v() { # <stem> <check-id:verdict>...
  local s="$1"; shift
  local rows="[]" c
  for c in "$@"; do
    rows="$(jq -c --arg id "${c%%:*}" --arg vd "${c#*:}" '. + [{check_id:$id, verdict:$vd, evidence:"seeded"}]' <<<"$rows")"
  done
  jq -n --arg s "$s" --argjson vs "$rows" \
    '{schema_id:"GATE_ADJUDICATION_VERDICT v1", gate_type:"story", gate_nonce:$s,
      generated_at:"2026-08-11T19:30:44Z", adjudicator_agent_id:"gate-adjudicator@session-seed",
      catalog:"core", verdicts:$vs}' > "$W/$GD/$s.verdict.json"
}
DECISION=""; REASON=""; EVENT=0
drive() { # sets DECISION (DENY|ALLOW), REASON, EVENT (1 when GATE_VERDICT_UNBOUND was logged)
  local out
  out="$(jq -nc --arg f "$W/$ART" --arg tr "$W/sessions-jsonl/current.jsonl" \
          '{session_id:"t", tool_name:"Edit", transcript_path:$tr, tool_input:{file_path:$f}}' \
        | ( cd "$W" && CLAUDE_PROJECT_DIR="$W" AI_DLC_GATE_METRICS="" bash "$HOOK" 2>/dev/null ))"
  REASON="$(jq -r '.hookSpecificOutput.permissionDecisionReason // ""' <<<"$out" 2>/dev/null)" || REASON=""
  case "$(jq -r '.hookSpecificOutput.permissionDecision // ""' <<<"$out" 2>/dev/null)" in
    deny) DECISION=DENY ;; *) DECISION=ALLOW ;;
  esac
  EVENT=0
  grep -q -- '-- GATE_VERDICT_UNBOUND$' "$W/_bmad-output/pipeline-continuation-log.md" 2>/dev/null && EVENT=1
  return 0
}

fails=0
want() { # <world> <DENY|ALLOW> <event 0|1> [<check id the deny must name>]
  local ok=1
  [ "$DECISION" = "$2" ] || ok=0
  [ "$EVENT" = "$3" ] || ok=0
  if [ -n "${4:-}" ]; then
    case "$REASON" in *"$4"*) ;; *) ok=0 ;; esac
  fi
  if [ "$ok" = 1 ]; then
    echo "receipt-bl837: ok   $1: $DECISION, GATE_VERDICT_UNBOUND logged=$EVENT"
  else
    echo "receipt-bl837: FAIL $1: got $DECISION, GATE_VERDICT_UNBOUND logged=$EVENT; want $2, logged=$3${4:+, deny naming $4}"
    fails=$((fails + 1))
  fi
}

# C first: a receipt whose drive cannot deny reports 9, never a verdict.
world C; v story-20260811T193044Z 7:FAIL 3a:FAIL; drive
[ "$DECISION" = DENY ] || cant "control C (a bound live pass with an uncovered FAIL) did not DENY; the drive never reached the guard's deny"

world A; v story-20260811T193044Z 7:FAIL 3a:FAIL; v story-20260811T210000Z 7:FAIL; drive
want A DENY 1 3a
world B; v story-20260811T193044Z 2:PASS; v story-20260811T200000Z 3a:FAIL; v story-20260811T210000Z 2:PASS; drive
want B DENY 1 3a
world T; v story-20260811T193044Z 7:FAIL; v story-20260811T210000Z 7:FAIL; drive
want T ALLOW 1
# D: world A plus a decoy whose stem carries a SPACE and an old conforming timestamp. A guard that
# word-splits the stem list reads two non-files in its place, and the convict set comes out wrong.
world D; v story-20260811T193044Z 7:FAIL 3a:FAIL; v story-20260811T210000Z 7:FAIL
printf '{"verdicts":[]}\n' > "$W/$GD/old decoy-20200101T000000Z.verdict.json"; drive
want D DENY 1 3a
# D2: world T (every FAIL covered, so it would ALLOW) plus a decoy INSIDE the convict-set window,
# 20:00:00Z, whose stem carries a space and which records an uncovered FAIL on 3a. D's decoy is
# older than the bound pass, so a guard that windows first never reaches its name; this one it
# must reach. A guard that drops an unsafe stem instead of convicting it allows here.
world D2; v story-20260811T193044Z 7:FAIL; v story-20260811T210000Z 7:FAIL
printf '{"verdicts":[{"check_id":"3a","verdict":"FAIL","evidence":"seeded"}]}\n' > "$W/$GD/new decoy-20260811T200000Z.verdict.json"; drive
want D2 DENY 1
# Z: world T plus a ZERO-BYTE verdict file at 20:00:00Z, inside the window, with a safe stem. It
# yields no JSON document, so no convict row comes back for it. A guard that skips a candidate
# with no row, instead of convicting it as unreadable, allows here.
world Z; v story-20260811T193044Z 7:FAIL; v story-20260811T210000Z 7:FAIL
: > "$W/$GD/story-20260811T200000Z.verdict.json"; drive
want Z DENY 1
# U: world T plus a TRUNCATED verdict file at 20:00:00Z, inside the window: jq fails on it
# outright and returns no row at all. Z's empty file still yields a row, so only this world
# reaches a guard that skips a pass whose read produced nothing.
world U; v story-20260811T193044Z 7:FAIL; v story-20260811T210000Z 7:FAIL
printf '{"catalog":"core","verdicts":[' > "$W/$GD/story-20260811T200000Z.verdict.json"; drive
want U DENY 1
# N: world T plus an in-window file that parses to `null`, not a verdict object. Z convicts an
# empty file and U one that does not parse; only this world reaches a guard that scores a parsed
# non-object as a pass with no FAIL. `null` and not an array or a number: `.catalog` errors on
# those, so a read that lost its non-object test would still fail on them and convict anyway.
world N; v story-20260811T193044Z 7:FAIL; v story-20260811T210000Z 7:FAIL
printf 'null\n' > "$W/$GD/story-20260811T200000Z.verdict.json"; drive
want N DENY 1
# TR: a forger file at 20:00:00Z holding a valid object followed by a bare `1` and no trailing
# newline, so the file is not ONE verdict object; then a live pass at 21:00:00Z that fails 3a,
# uncovered. Want DENY naming 3a, and the live file NOT named unreadable: a reader that attributes
# the stream by position hands the forger's trailing value to the next file. A guard that scores a
# non-object document as clean allows nothing here only because the live FAIL convicts, so this
# world asserts the attribution, not the verdict alone.
world TR; v story-20260811T193044Z 7:FAIL; v story-20260811T210000Z 3a:FAIL
printf '{"catalog":"core","verdicts":[]}\n1' > "$W/$GD/story-20260811T200000Z.verdict.json"; drive
want TR DENY 1 3a
# The unreadable list is the text between `UNREADABLE GATE RECORDS:` and ` in `; the live file is
# elsewhere in the deny as the pass under judgment, so only that clause is searched.
TR_UNR=""
case "$REASON" in
  *'UNREADABLE GATE RECORDS: '*) TR_UNR="${REASON#*UNREADABLE GATE RECORDS: }"; TR_UNR="${TR_UNR%% in \`*}" ;;
esac
case "$TR_UNR" in
  *story-20260811T210000Z*)
    echo "receipt-bl837: FAIL TR: the deny names the live file story-20260811T210000Z as unreadable"
    fails=$((fails + 1)) ;;
esac

# The fixture's own seeds, driven as seeded.
seeded() { # <case> -- sets W to a fresh world of that seed.sh case, verdicts and ledger included
  W="$(TMPDIR="$PARENT" bash "$SEED" "$1" 2>/dev/null)" || W=""
  [ -n "$W" ] && [ -d "$W/$GD" ] || cant "seed.sh $1 failed"
}
# L1: NOTHING bound (the one dispatch predates every nonce). An older unbound pass fails 3a,
# uncovered; the live pass fails 7, covered. A guard that allows whenever nothing is bound fails.
seeded subst-nobound-older-fail; drive
want L1 DENY 1 3a
# R8 and R8-both: bound pass fails 3a; the unbound live pass fails 9 and carries a repair record
# on its OWN nonce. One record lifts one pass, so R8 must DENY naming 3a. R8-both adds the bound
# pass's own record for 3a, so every owed pass lifts: ALLOW. A lift that reads only the first
# owed pass allows R8; a guard that denies every unbound lift denies R8-both.
seeded subst-repair-unbound; drive
want R8 DENY 1 3a
seeded subst-repair-both; drive
want R8-both ALLOW 1

[ "$fails" -eq 0 ] || exit 1
exit 0
