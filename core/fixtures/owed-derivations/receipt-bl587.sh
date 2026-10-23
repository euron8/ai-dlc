#!/usr/bin/env bash
# Receipt: the LIVING sweep blocks on a stale fence whose operand is ai-dlc CORE, and stays silent on one
# whose operand is consumer code, in the SAME world and with NO owed-derivations record (operator ruling (A)).
# Usage: receipt-bl587.sh [<root>]
# 0 = the REAL reader at <root>/core/scripts/check-owed-derivations.sh exits 1 over a world holding one
#     LIVING prd.md with a stale core-operand fence and a stale consumer-operand fence, and its ONLY OPEN
#     line is the core one, reason LIVING-STALE, log cell living-sweep.
# 1 = any other exit, or any other OPEN set (none: the sweep is gone or acquits; two: the filter is gone).
# 9 = no verdict: the reader or a sibling it needs (validator, core-paths.sh, the manifest) is absent, or
#     the world could not be built, or the seed is not what it claims (the validator must FAIL both fences).
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR 2>/dev/null || true
ROOT="${1:-.}"
ROOT="$(cd "$ROOT" 2>/dev/null && pwd -P)" || { echo "REFUSED: no root" >&2; exit 9; }
RD="$ROOT/core/scripts/check-owed-derivations.sh"
VAL="$ROOT/core/scripts/validate-artifact-derivations.sh"
CP="$ROOT/core/scripts/core-paths.sh"
MAN="$ROOT/core/skills/ai-dlc/core-manifest.md"
for f in "$RD" "$VAL" "$CP" "$MAN"; do [ -f "$f" ] || { echo "REFUSED: subject absent: $f" >&2; exit 9; }; done
D="$(mktemp -d "${TMPDIR:-/tmp}/bl587rcpt.XXXXXX")" || { echo "REFUSED: mktemp" >&2; exit 9; }
trap '[ -n "$D" ] && [ -d "$D" ] && rm -rf "$D"' EXIT
B="$D/bin"; W="$D/r"; F=_bmad-output/planning-artifacts/prd.md
mkdir -p "$B" "$W/scripts/ai-dlc" "$W/server" "$W/.claude/skills/ai-dlc" "$W/_bmad-output/planning-artifacts" || exit 9
cp "$RD" "$CP" "$B/" || exit 9
printf '#!/usr/bin/env bash\necho 1\n' > "$B/sprint-status.sh" || exit 9
cp "$VAL" "$W/scripts/ai-dlc/" || exit 9
cp "$MAN" "$W/.claude/skills/ai-dlc/core-manifest.md" || exit 9
printf 'qqalpha\n' > "$W/scripts/ai-dlc/x.sh" || exit 9
printf 'qqalpha\n' > "$W/server/x.py" || exit 9
CORE_CMD='grep -n -F qqalpha scripts/ai-dlc/x.sh'
CONS_CMD='grep -n -F qqalpha server/x.py'
printf '# PRD\n\n```derived\n$ %s\n9:qqalpha\n```\n\n```derived\n$ %s\n9:qqalpha\n```\n' "$CORE_CMD" "$CONS_CMD" > "$W/$F" || exit 9
# Captured to a file first: the validator exits 1 on a stale fence, so under pipefail a piped count would
# be overwritten by its fallback.
( cd "$W" && AI_DLC_PROJECT_ROOT="$W" bash scripts/ai-dlc/validate-artifact-derivations.sh "$W/$F" >/dev/null 2>"$D/v.err" )
nf="$(grep -c '^FAIL (STALE): ' "$D/v.err")" || nf=0
[ "$nf" = 2 ] || { echo "REFUSED: the seed is not two stale fences (the validator reported $nf)" >&2; exit 9; }
out="$( cd / && AI_DLC_PROJECT_ROOT="$W" bash "$B/check-owed-derivations.sh" 2>"$D/err" )"; rc=$?
open="$(printf '%s\n' "$out" | awk -F'\t' '$1 == "OPEN"')"
want="$(printf 'OPEN\t%s:4\tLIVING-STALE\t$ %s\t-\tliving-sweep' "$F" "$CORE_CMD")"
if [ "$rc" = 1 ] && [ "$open" = "$want" ]; then
  echo "PASS: the LIVING sweep blocks on the core-operand fence alone, with no record"; exit 0
fi
echo "FAIL: reader exit $rc, OPEN lines:"; printf '%s\n' "${open:-<none>}" | sed 's/^/  | /'; head -3 "$D/err" | sed 's/^/  err| /'
exit 1
