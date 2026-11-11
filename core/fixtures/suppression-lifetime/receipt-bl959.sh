#!/usr/bin/env bash
# receipt-bl959.sh -- BL-959: a fresh in-force SUPPRESSED entry for the same [catalog] check stands an
# expired entry's re-fire down, and says so.
#
# THE WORLD (the consumer's shape, on the short timeline). Two gates recorded after both
# authorizations. OLD suppresses [core] 32 for 1 gate (past its lifetime at 2 elapsed); the latest
# row for 32 is the PREVIOUS gate's FAIL_WAIVED naming OLD. NEW suppresses [core] 32 for 3 gates,
# authorized at a different timestamp (in force at 2 elapsed).
#   T1: OLD + NEW -> exit 0, one `WARN: superseded:` line naming both entries, superseded=1.
#   T9: OLD alone -> exit 1 with the expiry FAIL on OLD (the control; same timeline, same OLD).
# Both run in this one invocation, so a validator that exits 0 on everything fails T9 and one that
# never stands down fails T1.
#
# The validator is resolved from the repo root, found by walking up from this file for a marker,
# never by counting `..` hops; both install layouts are tried. Prints `receipt-bl959: PASS` and exits
# 0, or `receipt-bl959: FAIL <why>` and exits 1; exit 2 when the validator cannot be located.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
d="$HERE"; ROOT=""
while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
  if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then ROOT="$d"; break; fi
  d="$(dirname "$d")"
done
[ -n "$ROOT" ] || { echo "receipt-bl959: BROKEN no repo root marker above $HERE" >&2; exit 2; }
V=""
for c in "$ROOT/core/scripts/validate-suppression-lifetime.sh" "$ROOT/scripts/ai-dlc/validate-suppression-lifetime.sh"; do
  [ -f "$c" ] && { V="$c"; break; }
done
[ -n "$V" ] || { echo "receipt-bl959: BROKEN validate-suppression-lifetime.sh not found under $ROOT" >&2; exit 2; }

W="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl959.XXXXXX")" || exit 2
trap 'rm -rf "$W"' EXIT
mkdir -p "$W/t1" "$W/t9"

A0="2026-04-30T00:00:00Z"; A1="2026-04-30T12:00:00Z"
OLD="[S401 gate — an expired bmad suppression] [lead] - ${A0}"
NEW="[S401 gate — a fresh bmad suppression] [lead] - ${A1}"
cat > "$W/map.yaml" <<'YAML'
checks:
  - id: 16
    title: gate-dormancy
    enforcer: []
    adjudication: script
  - id: 32
    title: bmad-invocation-resolves
    enforcer: []
    adjudication: script
YAML
{
  printf '{"v":1,"sprint":401,"gate":"planning","phase":"a→b","ts":"2026-05-01T01:00:00Z","sha":"deadbeef","catalog":"core","check":"32","title":"t","verdict":"FAIL","defect_class":null,"evidence":"e","tok_slice":1}\n'
  printf '{"v": 1, "sprint": 401, "gate": "planning", "phase": "a→b", "ts": "2026-05-02T01:00:00Z", "sha": "deadbeef", "catalog": "core", "check": "32", "title": "t", "verdict": "FAIL_WAIVED", "waiver_id": "%s", "defect_class": null, "evidence": "e", "tok_slice": 1}\n' "$OLD"
} > "$W/gm.jsonl"
old() { printf '## %s\n**Status:** SUPPRESSED\n**Suppresses:** [core] 32 — bmad-invocation-resolves\n**Expires after:** 1 gates\n**Operator authorization:** %s | "Override, proceed, file backlog item"\n\n' "$OLD" "$A0"; }
new() { printf '## %s\n**Status:** SUPPRESSED\n**Suppresses:** [core] 32 — bmad-invocation-resolves\n**Expires after:** 3 gates\n**Operator authorization:** %s | "Re-suppress 32 for three gates"\n\n' "$NEW" "$A1"; }
{ old; new; } > "$W/t1/pending.md"
old > "$W/t9/pending.md"

o1="$(bash "$V" --escalations "$W/t1/pending.md" --gate-metrics "$W/gm.jsonl" --enforcement-map "$W/map.yaml" 2>&1)"; r1=$?
o9="$(bash "$V" --escalations "$W/t9/pending.md" --gate-metrics "$W/gm.jsonl" --enforcement-map "$W/map.yaml" 2>&1)"; r9=$?

why=""
l1="$(grep -F "WARN: superseded: check '32' [core] -- expired entry '## $OLD'" <<<"$o1")" || l1=""
[ "$r1" = 0 ] || why="$why T1-exited-$r1"
grep -qF "stood down by the in-force SUPPRESSED entry '## $NEW'." <<<"$l1" || why="$why T1-no-WARN-superseded-line-naming-both"
grep -qE '[[:space:]]superseded=1([[:space:]]|$)' <<<"$o1" || why="$why T1-no-superseded=1"
[ "$r9" = 1 ] || why="$why T9-control-exited-$r9"
grep -qF 'is past its lifetime and the check is' <<<"$o9" && grep -qF "entry: ## $OLD" <<<"$o9" || why="$why T9-control-no-expiry-FAIL-on-OLD"

if [ -z "$why" ]; then echo "receipt-bl959: PASS"; exit 0; fi
echo "receipt-bl959: FAIL$why"
exit 1
