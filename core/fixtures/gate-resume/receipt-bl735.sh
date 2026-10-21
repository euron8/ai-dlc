#!/usr/bin/env bash
# BL-735 receipt. Usage: bash receipt-bl735.sh <ai-dlc-recover.sh> <gate-resume/run.sh>
# Two keys, both required, because either alone can be closed without the fix:
#   1. the fixture's WC arm demands a margin: run.sh sets WC_MARGIN=<n> with 200 <= n < 10000,
#      and the line that zeroes `wc` asserts BOTH the sidecar-note field ("$4" against 1) and
#      a bound written with WC_MARGIN. A length bound alone misses the note drop, because the
#      emission FALLS when the note goes.
#   2. the hook, fired once in the WC world as _mkc457 builds it (31-char implementation-<UTC>
#      nonce opened through the real gate-checkpoint.sh, sidecar, unresolvable step file),
#      emits the sidecar note AND fewer than 10000 - n characters.
# 0 = both hold. 1 = the arm lacks the margin or the note assertion, or the hook's worst case
#     is inside the margin or has lost the note.
# 9 = the receipt could not measure: a file, a hook library, gate-checkpoint.sh, jq or python3
#     is missing, the nonce would not open, or the hook emitted nothing parseable.
set -uo pipefail
H="${1:-}"; F="${2:-}"
[ -n "$H" ] && [ -f "$H" ] && [ -n "$F" ] && [ -f "$F" ] || { echo "REFUSED: usage: bash receipt-bl735.sh <ai-dlc-recover.sh> <run.sh>" >&2; exit 9; }
HD="$(dirname "$H")"
CK=""
for c in core/scripts/gate-checkpoint.sh scripts/ai-dlc/gate-checkpoint.sh; do
  [ -f "$c" ] && { CK="$c"; break; }
done
[ -n "$CK" ] || { echo "REFUSED: no gate-checkpoint.sh" >&2; exit 9; }
command -v jq >/dev/null && command -v python3 >/dev/null || { echo "REFUSED: jq or python3 missing" >&2; exit 9; }

# --- key 1: the arm ---
m="$(sed -n 's/^WC_MARGIN=\([0-9][0-9]*\)[[:space:]]*$/\1/p' "$F")"
[ "$(printf '%s\n' "$m" | grep -c .)" = 1 ] || { echo "FAIL: run.sh sets no single WC_MARGIN=<n>"; exit 1; }
[ "$m" -ge 200 ] && [ "$m" -lt 10000 ] || { echo "FAIL: WC_MARGIN=$m is outside [200, 10000)"; exit 1; }
wl="$(grep -E '\|\|[[:space:]]*wc=0' "$F")" || wl=""
[ "$(printf '%s\n' "$wl" | grep -c .)" = 1 ] || { echo "FAIL: run.sh has no single line zeroing wc"; exit 1; }
grep -qE '"\$4"[[:space:]]*(=|-eq)[[:space:]]*1' <<<"$wl" || { echo "FAIL: the WC line does not assert the sidecar-note field"; exit 1; }
grep -qE '10000[[:space:]]*-[[:space:]]*\$?\{?WC_MARGIN' <<<"$wl" || { echo "FAIL: the WC line's bound is not written with WC_MARGIN"; exit 1; }

# --- key 2: the hook, one fire in the WC world ---
d="$(mktemp -d)" || exit 9
trap 'rm -rf "$d"' EXIT
mkdir -p "$d/_bmad-output" "$d/.claude/skills/ai-dlc/steps" "$d/.claude/hooks" "$d/scripts/ai-dlc" || exit 9
cp "$H" "$d/.claude/hooks/ai-dlc-recover.sh" || exit 9
for l in ai-dlc-handoff-pending.sh ai-dlc-context-provenance.sh; do
  cp "$HD/$l" "$d/.claude/hooks/" 2>/dev/null || { echo "REFUSED: no $l beside the hook" >&2; exit 9; }
done
cp "$CK" "$d/scripts/ai-dlc/gate-checkpoint.sh" && chmod +x "$d/scripts/ai-dlc/gate-checkpoint.sh" || exit 9
printf '# Pipeline Snapshot\n\n## Pipeline Position\n- **Current step file:** `implementation.md`\n\n## Sprint Context\nsprint_id: 300\n' > "$d/_bmad-output/pipeline-snapshot.md"
printf '# precompact sidecar\nbranch: main\n' > "$d/_bmad-output/pipeline-snapshot.precompact.md"
bash "$CK" --root "$d" --nonce "implementation-20261006T120000Z" open >/dev/null 2>&1 || { echo "REFUSED: the WC nonce would not open" >&2; exit 9; }
o="$(printf '{"source":"compact","session_id":"receipt"}' | CLAUDE_PROJECT_DIR="$d" bash "$d/.claude/hooks/ai-dlc-recover.sh" 2>/dev/null)"
r="$(python3 -c 'import sys,json
c=json.loads(sys.argv[1])["hookSpecificOutput"]["additionalContext"]
print(len(c), int("Mechanical state captured immediately before this compaction" in c), int("RESUME it, do not restart it" in c))' "$o" 2>/dev/null)" || { echo "REFUSED: the hook emitted nothing parseable" >&2; exit 9; }
set -- $r
[ "${3:-0}" = 1 ] || { echo "REFUSED: no gate section in the WC world" >&2; exit 9; }
[ "$2" = 1 ] || { echo "FAIL: the WC world emits $1 chars WITHOUT the sidecar note"; exit 1; }
[ "$1" -lt $((10000 - m)) ] || { echo "FAIL: the WC world emits $1 chars, inside the ${m}-byte margin"; exit 1; }
echo "OK: WC emits $1 chars with the sidecar note, under $((10000 - m)) (WC_MARGIN=$m)"
exit 0
