#!/usr/bin/env bash
# scope-confirmation/seed.sh — a project tree plus the two artifacts Check 34 joins.
#
# Both ends of the join are seeded from the SHIPPING code rather than hand-written:
# the answers file is produced by driving the real capture hook, so the record grammar
# under test is the one the hook actually emits. A hand-written capture file would let
# the hook's format drift while this fixture stayed green — which is the failure mode
# where a fixture proves the fixture.
#
# Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$ROOT" ] && [ -f "$ROOT/core/hooks/ai-dlc-answer-capture.sh" ]; then
  HOOK="$ROOT/core/hooks/ai-dlc-answer-capture.sh"
  VALIDATOR="$ROOT/core/scripts/validate-scope-confirmation.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/hooks/ai-dlc-answer-capture.sh" ]; then
  HOOK="$ROOT/.claude/hooks/ai-dlc-answer-capture.sh"
  VALIDATOR="$ROOT/scripts/ai-dlc/validate-scope-confirmation.sh"
else
  echo "FIXTURE ERROR: ai-dlc-answer-capture.sh not found in either layout" >&2; exit 2
fi
[ -f "$VALIDATOR" ] || { echo "FIXTURE ERROR: validate-scope-confirmation.sh not found beside the hook" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/scope-confirm.XXXXXX")" || exit 2
mkdir -p "$WORK/proj/_bmad-output"

# The operator's selection, put through the real hook so the answers file is the
# hook's own output. ANSWER is exported so run.sh can hash it independently and
# compare against what the hook recorded.
ANSWER='Correct it — the ETH-REWARDS Base v4 pool indexing track, not the carry-over items'
QUESTION='Is this the scope you asked for?'

python3 - "$QUESTION" "$ANSWER" <<'PY' > "$WORK/payload.json"
import json, sys
print(json.dumps({
    "session_id": "sess-1",
    "tool_use_id": "toolu_seed",
    "tool_name": "AskUserQuestion",
    "tool_response": {"questions": [sys.argv[1]], "answers": {sys.argv[1]: sys.argv[2]}},
}))
PY

CLAUDE_PROJECT_DIR="$WORK/proj" bash "$HOOK" < "$WORK/payload.json" >/dev/null 2>&1 || true

ANSWERS="$WORK/proj/_bmad-output/operator-answers-history.md"
SHA="$(sed -n 's/^- SHA256: //p' "$ANSWERS" 2>/dev/null | tail -1)"

# An empty capture file: header only, no entries. This is the operator dismissing the
# prompt, and it is the ONLY state in which `scope_confirmed_cite: none` is honest.
EMPTY="$WORK/answers-empty.md"
printf '# Operator Answers\n\nheader prose, deliberately containing no entry\n\n---\n\n' > "$EMPTY"

# --- snapshots ---------------------------------------------------------------
# `- <field>: <value>` is the routing-record grammar the router writes and
# route-defect-classification/seed.sh already encodes; this fixture must not invent a
# second one.
snap() {
  f="$WORK/snap-$1.md"; shift
  {
    echo "# Pipeline Snapshot"
    echo
    echo "## Pipeline Position"
    echo "- user_request_verbatim: Sprint 300: take the ETH-REWARDS Base v4 pool indexing track through to production."
    echo "- user_request_cite: 0000000000000000000000000000000000000000000000000000000000000000"
    [ -n "${1:-}" ] && echo "- scope_confirmed: $1"
    [ -n "${2:-}" ] && echo "- scope_confirmed_cite: $2"
  } > "$f"
  return 0
}

snap good       corrected "$SHA"
snap confirmed  confirmed "$SHA"
snap nofield    "" ""
snap badvalue   n-a       "$SHA"
snap nocite     confirmed ""
snap citenone   confirmed none
snap fabricated confirmed "$(printf 'd%.0s' $(seq 1 64))"

# A snapshot with no routing record at all — predates the release that created one.
printf '# Pipeline Snapshot\n\n## Pipeline Position\ncurrent_step: steps/discovery.md\n' \
  > "$WORK/snap-premigration.md"

# THE GRAMMAR THE REFERENCE CONSUMER ACTUALLY WRITES, copied from its live snapshot:
# a prose bullet with the fields inline and backticked, several to a line, rather than
# one field per line. The first version of this check was written against the
# line-anchored form only and reported "no routing record" on the real thing — the
# fail-OPEN direction, caught by running it against the corpus instead of against this
# fixture. `scope_confirmed_cite` is deliberately written BEFORE `scope_confirmed` here,
# because the former has the latter as a string prefix and a careless extractor reads
# the digest as the value.
cat > "$WORK/snap-inline.md" <<INLINE
# Pipeline Snapshot

## Pipeline Position
- **Routing record (Step 6, written once, never rewritten):** \`user_request_verbatim\` — canonical
  (CAP-1..10 memlog) — read one of those, never a paraphrase. \`bug_signal_present: no\`.
  \`carryover_or_sprint_signal_present: yes\`. \`clarification_asked: n-a\`.
  \`scope_confirmed_cite: $SHA\`. \`scope_confirmed: corrected\`.
INLINE

cat > "$WORK/env.sh" <<ENV
HOOK="$HOOK"
VALIDATOR="$VALIDATOR"
WORK="$WORK"
PROJ="$WORK/proj"
ANSWERS="$ANSWERS"
ANSWERS_EMPTY="$EMPTY"
SHA="$SHA"
ANSWER='$ANSWER'
ENV

printf '%s\n' "$WORK"
