#!/usr/bin/env bash
#
# AI/DLC Standing Rulings Consult  (PreToolUse: AskUserQuestion)
#
# An operator standing ruling is a row of `_bmad-output/operator-standing-rulings.md`, an index over
# `operator-answers-history.md` read by `standing-rulings.sh` (the single reader; this hook never
# parses the record). A question whose `header` EQUALS the `match:` of an ACTIVE, SOURCED row triggers
# a consult and decides nothing: the hook denies that call ONCE, and the reason cites SR-id, ruling
# and source and states the escape.
#
# CONTRACT
#
#   DENY iff the tool is AskUserQuestion and at least one question's `header` is found by
#   `standing-rulings.sh lookup <header>` (exit 0) AND that question's text does not carry
#   `not SR-<n>: <reason>` for the matched row's number <n>.
#
#   ESCAPE. A question whose text carries `not SR-<n>: <non-blank reason>` for the row it matched is
#   always allowed; the reason must open with a non-blank character on the same line.
#
#   MULTI-QUESTION CALL. A PreToolUse allow reason does not reach the model, so a call with one
#   match cannot be allowed with a note. ANY matched question denies the WHOLE call; the reason lists
#   the matched headers and the unmatched ones, and the lead re-asks the unmatched ones ALONE. A
#   question is never permanently withheld: the matched one is answered by a Rule 12 Tier 2
#   `DECIDED_AUTONOMOUSLY` entry citing the row, or re-asked with the escape.
#
#   FAIL OPEN. Nothing is denied when jq is absent, the reader is absent, the payload does not parse,
#   the record is absent (a row-less record is exit 1), or the reader exits 2 (record malformed,
#   unsourced row, schema missing). Any other reader exit is also an allow.
#
# FALSE-POSITIVE MEASUREMENT (read only, before shipping; the narrowing is part of the arm)
#   Population: every AskUserQuestion `questions[].header` in the graph transcripts, 668 asks, of
#   which the s321-s323 window is the subset dated 2026-10-30 onward. Record: one row per update
#   family the graph answers-history shows, drawn only from headers the grammar permits. The match is
#   EXACT string equality on the header, never a prefix or a substring: a prefix match denied
#   `Delete 16/20`..`Delete 20/20` as one family and `Check 2` for `Check 22 S4`, so equality is the
#   narrowing. The rows' `scope:` does not enter the hook; a `match:` that is a header a program
#   reads back is refused by `standing-rulings.sh check`, not here. See the sha message for the set.
#
# PROTOCOL. A deny is `permissionDecision: "deny"` on stdout, never exit code 2. Silence is exit 0.
# This hook always exits 0. Compatible with bash 3.2.

set -u

command -v jq >/dev/null 2>&1 || exit 0

# --- AI_DLC_ROOT ------------------------------------------------------------
ai_dlc_resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || exit 0
# --- end AI_DLC_ROOT --------------------------------------------------------
ROOT="$AI_DLC_ROOT"

READER=""
for c in "$ROOT/scripts/ai-dlc/standing-rulings.sh" "$ROOT/core/scripts/standing-rulings.sh"; do
  [ -f "$c" ] && { READER="$c"; break; }
done
[ -n "$READER" ] || exit 0

INPUT="$(cat)"

# One jq read: per question a line `<header>\t<ids>`, <ids> the `not SR-<n>: <reason>` numbers the
# question text carries, comma-joined. Tabs and newlines inside a header become spaces.
QS="$(jq -r 'if .tool_name == "AskUserQuestion" and ((.tool_input.questions // null) | type) == "array" then
    .tool_input.questions[] | ((.header // "") | tostring | gsub("[\t\n\r]"; " ")) + "\t" +
    ([(.question // "" | tostring | scan("not SR-([0-9]+): *[^ \t\n]") | .[0])] | join(","))
  else empty end' <<<"$INPUT" 2>/dev/null)" || exit 0
[ -n "$QS" ] || exit 0

export AI_DLC_PROJECT_ROOT="$ROOT"
MATCHED=""; UNMATCHED=""; N=0
while IFS=$'\t' read -r hdr ids; do
  [ -n "$hdr" ] || continue
  out="$(bash "$READER" lookup "$hdr" 2>/dev/null)"; rc=$?
  if [ "$rc" -ne 0 ]; then UNMATCHED="${UNMATCHED}\"${hdr}\", "; continue; fi
  sr="$(printf '%s\n' "$out" | sed -n 's/^### SR-\([0-9][0-9]*\)$/\1/p' | head -n 1)"
  [ -n "$sr" ] || { UNMATCHED="${UNMATCHED}\"${hdr}\", "; continue; }
  case ",${ids}," in *",${sr},"*) UNMATCHED="${UNMATCHED}\"${hdr}\", "; continue ;; esac
  ruling="$(printf '%s\n' "$out" | awk '/^- ruling: /{f=1; sub(/^- ruling: /,""); print; next} f && /^- (scope|status|source|match): /{f=0} f{print}')"
  src="$(printf '%s\n' "$out" | sed -n 's/^- source: //p' | head -n 1)"
  MATCHED="${MATCHED}  - header \"${hdr}\" matches SR-${sr}. Ruling (the operator's answer, verbatim): ${ruling}. Source: ${src}. Escape: re-ask with the question text carrying \`not SR-${sr}: <one-line reason>\`."$'\n'
  N=$((N + 1))
done <<<"$QS"

[ "$N" -gt 0 ] || exit 0
[ -n "$UNMATCHED" ] || UNMATCHED="none, "

REASON="AI/DLC standing ruling: ${N} question(s) in this AskUserQuestion call match an active, sourced operator standing ruling, so the whole call is held ONCE and nothing was asked.
${MATCHED}If the ruling decides the question: do not ask it. Record a Rule 12 Tier 2 DECIDED_AUTONOMOUSLY entry naming the row (SR-id and its source) as the entry's source, and proceed on the ruling.
If the ruling does NOT decide a question: re-ask it with its question text carrying the escape line above, \`not SR-<n>: <one-line reason>\` with the row's own number; a question carrying that escape is always allowed.
A ruling never decides a question on the Rule 11(a) sort's Outside list (scope confirmation, gate STOP adjudication or waiver, operator relief, Rule 12 Tier 1, a locked-requirement boundary, a step-reserved decision): ask that question with the escape.
Other questions in this call, held by no row (${UNMATCHED%, }): re-ask those ALONE in a fresh AskUserQuestion call; they are not withheld."

jq -nc --arg r "$REASON" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}' 2>/dev/null || exit 0
exit 0
