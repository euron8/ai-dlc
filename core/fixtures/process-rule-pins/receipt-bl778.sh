#!/usr/bin/env bash
# Receipt: SKILL.md Rule 32 touchpoint I cites the advisor gate's window, and the post-compact digest
# carries the same text. Usage: receipt-bl778.sh [<root>]
# 0 = the I item (its `- **I --` line to the next `- **` line or blank line, HTML comments stripped)
#     names both `ai-dlc-advisor-gate.sh` and `window` (any case), and
#     `scripts/render-postcompact-digest.sh --check` passes, so the digest was re-rendered from it.
# 1 = the citation is absent, or the digest is stale.
# 9 = no verdict: SKILL.md absent, its `- **I --` anchor absent, or the renderer absent (a consumer
#     tree carries no renderer, so this receipt runs in the distribution only).
# The digest is judged by the renderer's own --check, never by a grep of the digest, because a
# hand-edited digest would satisfy a grep while SKILL.md and the digest disagree.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
ROOT="${1:-.}"
ROOT="$(cd "$ROOT" 2>/dev/null && pwd -P)" || { echo "REFUSED: no root" >&2; exit 9; }
SK="$ROOT/core/skills/ai-dlc/SKILL.md"; RD="$ROOT/scripts/render-postcompact-digest.sh"
[ -f "$SK" ] || { echo "REFUSED: subject absent: $SK" >&2; exit 9; }
n="$(grep -c '^- \*\*I --' "$SK")" || n=0
[ "$n" -ge 1 ] || { echo "REFUSED: no touchpoint I item in $SK" >&2; exit 9; }
[ -f "$RD" ] || { echo "REFUSED: renderer absent: $RD" >&2; exit 9; }
span="$(awk '
  { line = $0
    if (com) { c = index(line, "-->"); if (!c) next; line = substr(line, c + 3); com = 0 }
    while ((c = index(line, "<!--")) > 0) {
      r = substr(line, c + 4); d = index(r, "-->")
      if (d) line = substr(line, 1, c - 1) substr(r, d + 3); else { line = substr(line, 1, c - 1); com = 1 }
    }
    if (!on) { if (index(line, "- **I --") == 1) { on = 1; span = line }; next }
    if (line ~ /^[ \t]*$/ || index(line, "- **") == 1) exit
    span = span " " line }
  END { gsub(/[[:space:]]+/, " ", span); print span }' "$SK")"
rc=0
case "$span" in *ai-dlc-advisor-gate.sh*) : ;; *) echo "FAIL: touchpoint I does not name ai-dlc-advisor-gate.sh"; rc=1 ;; esac
lspan="$(printf '%s\n' "$span" | tr '[:upper:]' '[:lower:]')"
case "$lspan" in *window*) : ;; *) echo "FAIL: touchpoint I does not cite the hook's window"; rc=1 ;; esac
dout="$( cd "$ROOT" && bash "$RD" --check 2>&1 )"; drc=$?
[ "$drc" -eq 0 ] || { echo "FAIL: the post-compact digest is stale against SKILL.md (render --check exit $drc): $(printf '%s\n' "$dout" | head -1)"; rc=1; }
[ "$rc" -eq 0 ] && echo "PASS: touchpoint I cites the advisor gate's window and the digest carries it"
exit "$rc"
