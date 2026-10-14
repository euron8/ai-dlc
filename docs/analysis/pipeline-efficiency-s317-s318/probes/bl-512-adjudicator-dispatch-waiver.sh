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
#   M  a waiver naming a ledger dispatch NAME only (no toolu_, no agent id)              -> ALLOW
#   P  U's waiver, with the snapshot at a LATER sprint                                   -> ALLOW
#   S  the X row, named by a Remediation stating a sharded re-dispatch (Check 22 arm 4's
#      other remedy for this class)                                                     -> ALLOW
#   R  an OVERRIDDEN Check 30 entry mentioning Rule 19(b) and Check-22 only in passing   -> ALLOW
#   H  a Check 22 waiver whose spawn list sits under a `###` subheading                  -> ALLOW
#   V  U's world, dispatched for a SPRINT-REVIEW gate (Check 22 is not in its manifest)   -> ALLOW
# Every adjudicator brief carries a gate nonce, as all 264 real ones do.
# CONTROL: a non-adjudicator dispatch over U must produce no decision, or the guard is refusing for
# some other reason and this probe cannot measure (exit 9).
#
# exit 0 fixed (U and X denied, every other world allowed), 1 live, 9 precondition missing.
# Measured at origin/main fe7d5ec2: U allowed -> exit 1. At d8ba8963: S, R and H denied -> exit 1.
# Run from the repo root.
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
decide() { # decide <dir> <role> [nonce]; an allow is NO output -- default it to {} so jq says "none"
  local j o
  j="$(jq -nc --arg r "$2" --arg n "${3:-implementation-20261010T230257Z}" '{tool_name:"Agent",tool_input:{description:"gate",
    prompt:("Your operating contract is `.claude/team-roles/" + $r + ".md`. gate_nonce: " + $n)}}')"
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
M="$(world M)"
printf '{"v":1,"sprint":317,"name":"s317-w8","role":"dev","tool_use_id":"toolu_01W8ROW0000000000000001","shard":null}\n' >> "$M/_bmad-output/spawn-ledger.jsonl"
waiver "$M/docs/escalations/pending.md" "**Context:** Check 22 tier mismatch on the dispatch s317-w8."
P="$(world P)"; cp "$U/docs/escalations/pending.md" "$P/docs/escalations/pending.md"
printf -- '- sprint_id: 318\n' > "$P/_bmad-output/pipeline-snapshot.md"
# A sprint-318 row, so the arm has keys to judge with and the allow is the sprint scope's, not a
# fail-open on an empty sprint.
printf '{"v":1,"sprint":318,"name":"s318-w1","role":"dev","tool_use_id":"toolu_01S318ROW00000000000001","shard":null}\n' >> "$P/_bmad-output/spawn-ledger.jsonl"
S="$(world S)"
printf '{"v":1,"sprint":317,"name":"remediator","role":"remediator","tool_use_id":"toolu_01REMINV000000000000001","shard":"invalid-exception"}\n' \
  >> "$S/_bmad-output/spawn-ledger.jsonl"
printf '\n## [S317-CHECK22-S3] lead - 2026-10-10\n**Status:** OVERRIDDEN\n**Context:** Check 22 arm S3 on toolu_01REMINV000000000000001.\n**Remediation:** the work was re-dispatched sharded as rem-p1a and rem-p1b; output verified.\n' \
  >> "$S/docs/escalations/pending.md"
R="$(world R)"
printf '\n## [S317-Z] lead - 2026-10-10\n**Status:** OVERRIDDEN\n**Blocker type:** Check 30 spec join ruling; unrelated to the Rule 19(b) binding.\n**Resolution:** disposition by the Check-22 pattern, by analogy.\n' \
  >> "$R/docs/escalations/pending.md"
H="$(world H)"
printf '\n## [S317-Y] lead - 2026-10-10\n**Status:** OVERRIDDEN\n**Context:** Check 22 tier mismatch waived.\n**Remediation:** verified.\n### Spawns waived\ntoolu_01DEVROW000000000000001\n' \
  >> "$H/docs/escalations/pending.md"
[ "$(decide "$U" dev)" = none ] || exit 9
[ "$(decide "$U" gate-adjudicator)" = deny ] || exit 1
[ "$(decide "$N" gate-adjudicator)" = none ] || exit 1
[ "$(decide "$X" gate-adjudicator)" = deny ] || exit 1
[ "$(decide "$C" gate-adjudicator)" = none ] || exit 1
[ "$(decide "$M" gate-adjudicator)" = none ] || exit 1
[ "$(decide "$P" gate-adjudicator)" = none ] || exit 1
[ "$(decide "$S" gate-adjudicator)" = none ] || exit 1
[ "$(decide "$R" gate-adjudicator)" = none ] || exit 1
[ "$(decide "$H" gate-adjudicator)" = none ] || exit 1
[ "$(decide "$U" gate-adjudicator sprint-review-20261011T101010Z)" = none ] || exit 1
exit 0
