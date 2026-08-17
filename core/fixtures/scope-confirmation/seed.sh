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

# ROOT IS RESOLVED BY WALKING UP FOR A MARKER, NOT BY COUNTING `..` HOPS. The hop count
# that was here (`$HERE/../../..`) is 3 in both layouts today by coincidence, and a
# coincidence is not a resolver: it answers differently the moment either tree moves a
# level, and the wrong answer is a FIXTURE ERROR that reads like a missing hook.
#
# THE MARKER IS THE HOOK ITSELF, in whichever layout holds it, rather than a proxy file.
# `VERSION` is the marker this repo's validators walk for and it is the WRONG one here:
# measured, `scripts/install.sh` has ZERO sites copying a VERSION file into a consumer
# (against a control of 91 sites writing under PROJECT_ROOT), so a VERSION walk resolves
# nothing on the tree this fixture SHIPS to. Marker-walking on the artifact cannot pick a
# root that does not hold the artifact.
HOOK=""; VALIDATOR=""; ROOT=""
CAND_DIST=""; CAND_CONS=""
_d="$HERE"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  if [ -f "$_d/core/hooks/ai-dlc-answer-capture.sh" ]; then
    ROOT="$_d"
    CAND_DIST="$_d/core/scripts/validate-scope-confirmation.sh"
    CAND_CONS="$_d/scripts/ai-dlc/validate-scope-confirmation.sh"
    HOOK="$_d/core/hooks/ai-dlc-answer-capture.sh"
    VALIDATOR="$CAND_DIST"
    break
  fi
  if [ -f "$_d/.claude/hooks/ai-dlc-answer-capture.sh" ]; then
    ROOT="$_d"
    CAND_DIST="$_d/core/scripts/validate-scope-confirmation.sh"
    CAND_CONS="$_d/scripts/ai-dlc/validate-scope-confirmation.sh"
    HOOK="$_d/.claude/hooks/ai-dlc-answer-capture.sh"
    VALIDATOR="$CAND_CONS"
    break
  fi
  _d="$(dirname "$_d")"
done
[ -n "$HOOK" ] || { echo "FIXTURE ERROR: ai-dlc-answer-capture.sh not found in either layout walking up from $HERE" >&2; exit 2; }
[ -f "$VALIDATOR" ] || { echo "FIXTURE ERROR: validate-scope-confirmation.sh not found beside the hook (named candidates: $CAND_DIST | $CAND_CONS)" >&2; exit 2; }

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

# --- THE GRAMMAR THE PRODUCER ACTUALLY EMITS ----------------------------------
# SEEDED FROM THE PRODUCER, NOT FROM THE READER. The two snapshots above are the two
# grammars `field_of` was written to accept, so an arm built on them proves the reader
# accepts its own accept-set and nothing else. Re-derived on the reference consumer's live
# `_bmad-output/pipeline-snapshot.md`: 14 bold `- **name:** value` field lines against 10
# plain `- name: value` ones, and EVERY sibling of `scope_confirmed` inside the routing
# record block itself is bold — `user_request_cite`, `bug_signal_present`,
# `carryover_or_sprint_signal_present`, `clarification_asked`, `user_request_verbatim`.
# Only the two lines this check consumes had been hand-converted to plain, so the corpus
# this validator will meet is the bold one and the fixture had no seed for it.
#
# Three shapes are copied from that file rather than invented:
#   * the colon INSIDE the bold span      - **bug_signal_present:** yes
#   * a value carrying trailing prose     - **clarification_asked:** n-a — defect and ...
#   * a bold name with a BACKTICKED value - **user_request_cite:** `63b1ab53...`
# The colon-OUTSIDE, `__underscore__` and whole-pair forms are the same author's sibling
# markdown habits; they are seeded because the fix normalizes rather than enumerates, and
# an arm on each is what stops a later author narrowing the normalizer back to a list.
prod() {
  f="$WORK/snap-prod-$1.md"; shift
  {
    echo '# Pipeline Snapshot'
    echo
    echo '### Routing record (Check 27 re-adjudicates this at every planning gate; written'
    echo 'once by route.md Step 6, never rewritten)'
    echo '- **user_request_cite:** `0000000000000000000000000000000000000000000000000000000000000000`'
    echo '  (`_bmad-output/operator-requests-history.md`, 1376 bytes)'
    echo '- **bug_signal_present:** yes — AC16 discharged negative; the live Create L2 at 75%'
    echo '  minted against the full balance and swapped unchunked.'
    echo '- **carryover_or_sprint_signal_present:** yes — six `CO-S302-*` identifiers named.'
    echo '- **clarification_asked:** n-a — defect and carry-over signals co-occur, but the'
    echo '  operator pre-directed priority, discharging the Step 4 MUST-ASK.'
    for _l in "$@"; do printf '%s\n' "$_l"; done
    echo '- **user_request_verbatim:**'
    echo
    echo '```text'
    echo 'Fix the create-position capital-sizing seam.'
    echo '```'
  } > "$f"
  return 0
}

# colon INSIDE the bold span, prose after the value, cite bold + backticked. This is the
# producer's dominant form, line for line.
prod bold     "- **scope_confirmed:** confirmed — the operator accepted the scope as put." \
              "- **scope_confirmed_cite:** \`$SHA\`" \
              "  (\`_bmad-output/operator-answers-history.md\`, 23 bytes)"

# colon OUTSIDE the bold span, and the value is `corrected` rather than `confirmed` so an
# arm on it cannot pass against a parser that answers `confirmed` unconditionally. The cite
# is written BEFORE the value, as in snap-inline: `scope_confirmed` is a string PREFIX of
# `scope_confirmed_cite`, and normalization moves the wrapper without moving that hazard.
prod boldout  "- **scope_confirmed_cite**: $SHA" \
              "- **scope_confirmed**: corrected"

# plain name, BACKTICKED VALUE. The pre-fix value class excluded a backtick, so this
# returned empty and routed to the skipped-pause-point accusation.
prod btval    "- scope_confirmed: \`confirmed\`" \
              "- scope_confirmed_cite: \`$SHA\`"

# `__underscore bold__`. Named as residue-adjacent in the validator: the single-underscore
# form CANNOT be normalized because the field name contains one, but the doubled form can.
prod uscore   "- __scope_confirmed__: confirmed" \
              "- __scope_confirmed_cite__: $SHA"

# a bold span wrapping the whole NAME-AND-VALUE pair; the pre-fix read the value as
# `confirmed**` and reported it malformed.
prod boldpair "- **scope_confirmed: confirmed**" \
              "- **scope_confirmed_cite: $SHA**"

# THE NEGATIVE ARM. Every sibling field bold, and no `scope_confirmed` at all. The correct
# answer is EMPTY and the accusation is the RIGHT behaviour. Without this, an arm asserting
# only that the bold forms yield `confirmed` passes against `field_of() { echo confirmed; }`
# -- a fix that closes the check by breaking it, which BL-065's own receipt accepts.
prod nofield

# a bold field carrying a value outside the closed set. Both the pre-fix and the fixed
# parser exit 1 here, so the EXIT CODE cannot tell them apart -- the pre-fix reports the
# value as `**` and the fixed one as `n-a`. The arm reads the message.
prod badvalue "- **scope_confirmed:** n-a" \
              "- **scope_confirmed_cite:** \`$SHA\`"

cat > "$WORK/env.sh" <<ENV
CAND_DIST="$CAND_DIST"
CAND_CONS="$CAND_CONS"
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
