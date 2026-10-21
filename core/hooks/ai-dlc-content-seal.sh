#!/bin/bash
#
# AI/DLC Content Seal Recorder (PostToolUse, Write|Edit|MultiEdit)
#
# PURPOSE
# Record, after every sanctioned write to a file a join program READS, the sha256 of the bytes that write left,
# so the join programs can refuse a file whose bytes changed afterwards through a channel no hook
# sees. The sealed set, the row shape and the comparison all live in `scripts/ai-dlc/content-seal.sh`,
# which this hook SOURCES; read that file's header for what is sealed and why, and for the readers.
#
# WHY POSTTOOLUSE. `ai-dlc-gate-remediation-guard.sh` records a dispatched agent's write at
# PreToolUse, which is an ATTEMPT: it cannot know the bytes. Only after the tool has run is there a
# file to hash, so the seal is taken here. A row is written for the top-level session's writes too
# (no `agent_id`), because a lead Edit is a sanctioned channel and must re-seal, or the next reader
# would refuse the lead's own Edit as a Bash amendment.
#
# MEASURED, the precondition this rests on (batch 236, headless scratch sessions, CC 2.x): the
# PostToolUse payload of a subagent's Write and of a subagent's Edit carries `agent_id` and
# `agent_type`; the top-level session's Write and Edit carry neither. Every one carries
# `tool_use_id`, `transcript_path` and `tool_response`.
#
# LIMITS, stated so a clean merge is not over-read:
#  - A Bash write to `.artifact-writes.jsonl` can FORGE a seal: append a row carrying the sha of the
#    Bash-written bytes. That is the floor every ledger in this pipeline shares; the guard denies Write
#    and Edit on the ledger's directory, and nothing denies Bash.
#  - The snapshot is NOT sealed. Its stamp check (`ai-dlc-derivation-capture.sh`) sees Write and Edit
#    only, and a Bash `sed -i` on the snapshot stays open.
#  - A top-level AGENT-TEAMS TEAMMATE is unmeasured: whether its payload carries `agent_id` was not
#    observed. If it carries none its rows read as the top-level session's.
#  - MultiEdit is in the matcher and was not exercised: the measured harness offered no MultiEdit tool.
#  - A seal attests the channel of the LAST write, not who should have made it: any Write or Edit,
#    by any actor, re-seals the file.
#  - REVIEW SHARDS (`docs/reviews/s<N>/shards/<idx>-code-review-|-qa-validation-<sha12>[-p<M>]/*.md`)
#    sit outside the state dir, usually in a linked worktree. Their row is written into THIS
#    session's LOG_DIR ledger; the reader (`content-seal.sh --review-shard`) finds the ledger through
#    the shard's git common dir. The two name the same file only when CLAUDE_PROJECT_DIR is the main
#    checkout (the common dir's parent) and AI_DLC_STATE_DIR is spelled the same in both. When they
#    differ the reader finds no row and REFUSES -- the conservative direction, never an acquittal.
#  - A sealed-set file that has never had a Write or Edit carries no row and is never compared,
#    except a gate part, which `--merge` refuses when this tree's ledger holds a tool seal row older
#    than the part's nonce. A failed append here is silent, so it reads the same as a Bash-written
#    part and is refused toward re-dispatch: the conservative direction.
#
# OUTPUT: nothing, ever, and exit 0 on every path. A recorder that can fail a tool call makes the
# pipeline's ability to write a file depend on the recorder's ability to run. A lost row surfaces at
# the reader only if an earlier row for that file exists, as a refusal naming the earlier writer.
#
# INSTALL
# 1. Place at .claude/hooks/ai-dlc-content-seal.sh, chmod +x
# 2. Register under PostToolUse, matcher "Write|Edit|MultiEdit" (templates/settings.json.template)

set -u

INPUT=$(cat)

# Fork-free pre-filter: the payload must name a path that could be sealed at all -- a shard file, a
# joined `-repair` record, or a gate part. `-repair` is admitted so that the serial remediator's Edit
# append to a sealed joined record leaves a seal row; without it that append is refused. Everything else -- the overwhelming majority of
# writes -- leaves here before any jq. A token this lets through that `seal_sealed` then rejects
# costs one jq and writes nothing; a sealed path this drops would lose its row, so it is a superset.
case "$INPUT" in
  *'/shards/'*|*'gate-adjudication/'*|*'-repair'*) ;;
  *) exit 0 ;;
esac
command -v jq >/dev/null 2>&1 || exit 0

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
SEAL_LIB="${PROJECT_DIR}/scripts/ai-dlc/content-seal.sh"
[ -r "$SEAL_LIB" ] || exit 0
# shellcheck source=/dev/null
. "$SEAL_LIB" 2>/dev/null || exit 0
command -v seal_sealed >/dev/null 2>&1 || exit 0

_STATE_DIR="${AI_DLC_STATE_DIR:-_bmad-output}"
STATE_DIR_NAME="$(basename "$_STATE_DIR")"
case "$_STATE_DIR" in
  /*) LOG_DIR="$_STATE_DIR" ;;
  *)  LOG_DIR="${PROJECT_DIR}/${_STATE_DIR}" ;;
esac

# One jq for every field, unit-separated so an empty agent_id does not shift the fields after it.
US="$(printf '\037')"
FIELDS="$(jq -r '[(.tool_name // ""), (.tool_input.file_path // ""), (.agent_id // ""),
                  (.session_id // ""), (.tool_use_id // ""), (.transcript_path // "")]
                 | map(tostring) | join("\u001f")' <<< "$INPUT" 2>/dev/null)" || exit 0
IFS="$US" read -r TOOL_NAME FP AGENT_ID SESSION_ID TOOL_USE_ID TRANSCRIPT <<< "$FIELDS"
case "$TOOL_NAME" in Write|Edit|MultiEdit) ;; *) exit 0 ;; esac
[ -n "$FP" ] || exit 0

case "$FP" in /*) HASH_PATH="$FP" ;; *) HASH_PATH="${PROJECT_DIR}/${FP}" ;; esac
if command -v seal_review_locate >/dev/null 2>&1; then
  # REVIEW SHARDS (content-seal.sh header). A path naming `docs/reviews/s<N>/shards/` is never
  # placed by seal_norm: it lives in whatever tree the seat wrote it (the frozen dev worktree), and
  # its row goes into THIS session's LOG_DIR ledger, project-root-relative, with that tree's root.
  case "$FP" in
    */docs/reviews/s[0-9]*/shards/*/*.md|docs/reviews/s[0-9]*/shards/*/*.md)
      [ -f "$HASH_PATH" ] || exit 0
      seal_review_locate "$HASH_PATH" || exit 0
      seal_sealed_review "$_RV_REL" || exit 0
      if [ -n "$AGENT_ID" ]; then ACTOR=agent; else ACTOR=session; fi
      mkdir -p "${LOG_DIR}/planning-artifacts" 2>/dev/null || exit 0
      seal_review_record_row "${LOG_DIR}/planning-artifacts/.artifact-writes.jsonl" "$HASH_PATH" "$ACTOR" \
        "$AGENT_ID" "$SESSION_ID" "$TOOL_NAME" "$TOOL_USE_ID" "$TRANSCRIPT" 2>/dev/null
      exit 0 ;;
  esac
fi

seal_norm "$FP" "$STATE_DIR_NAME" "$LOG_DIR" || exit 0
seal_sealed "${SEAL_REL#*/}" || exit 0

[ -f "$HASH_PATH" ] || exit 0
SHA="$(seal_sha "$HASH_PATH")"
[ -n "$SHA" ] || exit 0

if [ -n "$AGENT_ID" ]; then ACTOR=agent; else ACTOR=session; fi
mkdir -p "${LOG_DIR}/planning-artifacts" 2>/dev/null || exit 0
seal_append "${LOG_DIR}/planning-artifacts/.artifact-writes.jsonl" "$SEAL_REL" "$SEAL_ROOT" "$ACTOR" \
  "$AGENT_ID" "$SESSION_ID" "$TOOL_NAME" "$TOOL_USE_ID" "$TRANSCRIPT" "$SHA" 2>/dev/null
exit 0
