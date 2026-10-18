# content-seal/seal-lib.sh -- the seal side of the content-seal fixture, sourced by each arm script
# AFTER the subject's own lib (adversarial-shard-merge/lib.sh, remediator-shard-join/lib.sh) or, for
# the gate arms, after they resolve the validator. The caller sets SRCDIR to the directory holding
# the reader it drives; the seal library is resolved as THAT reader's sibling, because that is where
# each reader looks for it (`$(dirname "$0")/content-seal.sh`), so a mutated copy tree is read
# end to end and never half from the real one.
#
# The recorder hook is resolved by walking UP from this file in both layouts, never by counting `..`.
# Every world gets its own copy of the library at `<world>/scripts/ai-dlc/content-seal.sh`, because
# the hook sources only that consumer spelling under CLAUDE_PROJECT_DIR.
[ -n "${SRCDIR:-}" ] || { echo "FIXTURE ERROR: seal-lib.sh sourced without SRCDIR" >&2; exit 2; }
CS_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEAL="$SRCDIR/content-seal.sh"
[ -f "$SEAL" ] || { echo "FIXTURE ERROR: $SEAL is not beside the reader under test; every arm would drive the absent-sibling path" >&2; exit 2; }
SEALHOOK=""
_d="$CS_LIB_DIR"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _c in "$_d/core/hooks/ai-dlc-content-seal.sh" "$_d/.claude/hooks/ai-dlc-content-seal.sh"; do
    if [ -f "$_c" ]; then SEALHOOK="$_c"; break 2; fi
  done
  _d="$(dirname "$_d")"
done
[ -n "$SEALHOOK" ] || { echo "FIXTURE ERROR: ai-dlc-content-seal.sh not found above $CS_LIB_DIR in either layout; no seal row can be written" >&2; exit 2; }
echo "content-seal: resolved seal library = $SEAL, recorder = $SEALHOOK"
echo "HERMETIC-CONSUMED core/scripts/content-seal.sh"
echo "HERMETIC-CONSUMED core/hooks/ai-dlc-content-seal.sh"

# seal_hook <world root> <tool> <file_path> <agent_id or ""> [transcript_path]
# -- the REAL recorder, driven with the PostToolUse payload a Write or Edit produces. An empty
# agent_id is the top-level session's payload, which carries no agent_id key at all.
seal_hook() {
  mkdir -p "$1/scripts/ai-dlc" && cp "$SEAL" "$1/scripts/ai-dlc/content-seal.sh" || return 1
  jq -nc --arg t "$2" --arg p "$3" --arg a "$4" --arg tp "${5:-$1/.harness/fx-session.jsonl}" \
    '{session_id:"fx-session", hook_event_name:"PostToolUse", tool_name:$t, tool_input:{file_path:$p},
      tool_use_id:"toolu_01FxSealWrite", transcript_path:$tp, tool_response:{}}
     + (if $a == "" then {} else {agent_id:$a, agent_type:"fixture"} end)' \
    | CLAUDE_PROJECT_DIR="$1" bash "$SEALHOOK" >/dev/null 2>&1
}
# seal_count <ledger> -> the number of content-seal rows in it (0 when it is absent)
seal_count() { local n; n="$(grep -c '"kind":"content-seal"' "$1" 2>/dev/null)" || n=0; printf '%s' "$n"; }
# in_set <path relative to the state dir> -> the DECLARATION's answer (content-seal.sh seal_sealed),
# read from the library itself, so no arm restates the sealed set.
in_set() { ( . "$SEAL" && seal_sealed "$1" ); }
