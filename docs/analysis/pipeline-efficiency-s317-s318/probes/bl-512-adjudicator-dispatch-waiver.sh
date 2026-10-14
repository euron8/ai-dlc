#!/usr/bin/env bash
# BL-512 receipt probe: does the shipped dispatch guard refuse a gate-adjudicator dispatch that Check 22
# would discard, while allowing one it would not?
#
# Seeds layered-consumer scratch trees with a snapshot at sprint 317, a spawn ledger and a pending.md:
#   U  the real s317 tier-pin waiver body (core/fixtures/dispatch-model-guard/s317-tier-pin-waiver.md,
#      the entry whose waiver discarded gate nonce 230257Z): cites Check 22, names no spawn -> DENY
#   N  a Check 22 waiver naming a ledger tool_use_id                                     -> ALLOW
#   X  a remediator row recorded `shard: invalid-exception`, named by a waiver citing no
#      Rule 28 exception (the 124524Z / 011534Z form)                                    -> DENY
#   C  the same row, named by a waiver citing exception (4)                              -> ALLOW
# CONTROL: a non-adjudicator dispatch over U must produce no decision, or the guard is refusing for
# some other reason and this probe cannot measure (exit 9).
#
# exit 0 fixed (U and X denied, N and C allowed), 1 live, 9 precondition missing.
# Measured at origin/main fe7d5ec2: U allowed -> exit 1. Run from the repo root.
set -u
G=core/hooks/ai-dlc-dispatch-guard.sh
B=core/fixtures/dispatch-model-guard/s317-tier-pin-waiver.md
command -v jq >/dev/null 2>&1 && [ -f "$G" ] || exit 9
# The waiver body is part of this receipt's subject; absent at a base that predates it, the probe
# seeds the same entry's load-bearing lines so the base still answers.
root="$(mktemp -d)"
world() { # world <name> -> dir
  local p="$root/$1"
  mkdir -p "$p/.claude/team-roles" "$p/_bmad-output" "$p/docs/escalations"
  printf 'version: 0.0.0\n' > "$p/.claude/.ai-dlc-version"
  printf '{}\n' > "$p/.claude/settings.json"
  printf '# Role: gate-adjudicator\n' > "$p/.claude/team-roles/gate-adjudicator.md"
  printf '# Role: dev\n' > "$p/.claude/team-roles/dev.md"
  printf -- '- sprint_id: 317\n' > "$p/_bmad-output/pipeline-snapshot.md"
  { printf '{"v":1,"sprint":317,"name":"dev","role":"dev","tool_use_id":"toolu_01DEVROW000000000000001","shard":null}\n'
    printf '{"v":1,"sprint":317,"name":"code-reviewer","role":"code-reviewer","tool_use_id":"toolu_01CRROW0000000000000001","shard":null}\n'
  } > "$p/_bmad-output/spawn-ledger.jsonl"
  : > "$p/docs/escalations/pending.md"
  printf '%s\n' "$p"
}
waiver() { # waiver <file> <body-line>
  printf '\n## [S317-CHECK22-WAIVER] lead - 2026-10-10\n**Status:** OVERRIDDEN\n%s\n**Remediation:** outputs verified.\n' "$2" >> "$1"
}
decide() { # decide <dir> <role>; an allow is NO output -- default it to {} so jq says "none"
  local j o
  j="$(jq -nc --arg r "$2" '{tool_name:"Agent",tool_input:{description:"gate",
    prompt:("Your operating contract is `.claude/team-roles/" + $r + ".md`.")}}')"
  o="$(CLAUDE_PROJECT_DIR="$1" bash "$G" <<<"$j" 2>/dev/null)"
  [ -n "$o" ] || o='{}'
  jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"$o" 2>/dev/null
}
U="$(world U)"
if [ -f "$B" ]; then cat "$B" >> "$U/docs/escalations/pending.md"
else waiver "$U/docs/escalations/pending.md" "**Context:** Check 22 tier mismatch: 82 dev and 42 code-reviewer rows."; fi
N="$(world N)"; waiver "$N/docs/escalations/pending.md" "**Context:** Check 22 tier mismatch on toolu_01DEVROW000000000000001."
inv() { # inv <name> <remediation> -> dir
  local p; p="$(world "$1")"
  printf '{"v":1,"sprint":317,"name":"remediator","role":"remediator","tool_use_id":"toolu_01REMINV000000000000001","shard":"invalid-exception"}\n' \
    >> "$p/_bmad-output/spawn-ledger.jsonl"
  waiver "$p/docs/escalations/pending.md" "**Context:** Check 22 arm S3 on toolu_01REMINV000000000000001. $2"
  printf '%s\n' "$p"
}
X="$(inv X "No Rule 28 exception applies, and none is invented here.")"
C="$(inv C "The exception that applied is exception (4), a serial document.")"
[ "$(decide "$U" dev)" = none ] || exit 9
[ "$(decide "$U" gate-adjudicator)" = deny ] || exit 1
[ "$(decide "$N" gate-adjudicator)" = none ] || exit 1
[ "$(decide "$X" gate-adjudicator)" = deny ] || exit 1
[ "$(decide "$C" gate-adjudicator)" = none ] || exit 1
exit 0
