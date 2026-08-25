#!/usr/bin/env bash
# Seed a CONSUMER-SHAPED tree for the wait-aware Stop hook (ai-dlc-continue.sh
# Check 2b, v0.81.0).
#
#   seed.sh <case>   -> prints the WORK dir
#
# The hook's decision inputs are exactly four files under _bmad-output/:
#   pipeline-snapshot.md      Check 2 "is a pipeline running" gate (must EXIST)
#   pipeline-paused.flag      Check 1 operator pause (allow)
#   .beat-inflight            Check 2b live-beat marker (allow iff epoch > now)
#   pipeline-block-state.txt  Check 3 rapid-fire backoff counter
#
# The deliverable files are DELIBERATELY absent from every case: Check 2b keys off
# the marker, NOT off deliverable existence, and the whole point of the redesign
# is that "deliverable absent" is the unsafe sensor. So the snapshot always
# carries a populated In-Flight Teammates table with absent deliverables, and the
# decision must still track the marker alone -- that is the "ignores the row
# wording" property, proven by live-marker (allow) vs no-marker (block) over the
# identical snapshot.
set -eu

CASE="${1:?case}"
NOW="$(date +%s)"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/join-yield-XXXXXX")"
OUT="$WORK/_bmad-output"
mkdir -p "$OUT"
SNAP="$OUT/pipeline-snapshot.md"
MARK="$OUT/.beat-inflight"

# A realistic snapshot: Check 2 needs the file present, the block-reason grep
# reads current_step / last_gate, and the In-Flight Teammates table is here so the
# allow/block cases prove the hook never parses it.
write_snapshot() {
  cat > "$SNAP" <<'EOF'
# Pipeline Snapshot

## Pipeline Position
- current_step_file: .claude/skills/ai-dlc/steps/implementation.md
- last_gate_passed: gate-1 (story-1) @ 2026-07-17T20:00:00Z

## In-Flight Teammates
| teammate         | role | deliverable                  | dispatched_at        |
|------------------|------|------------------------------|----------------------|
| dev-s292-story-4 | dev  | docs/reviews/story-S292-4.md | 2026-07-17T20:40:00Z |
| qa-s292-story-2  | qa   | docs/qa/story-S292-2.md      | 2026-07-17T20:41:00Z |
EOF
}

case "$CASE" in
  # The genuine stall: active pipeline, no live beat. MUST block.
  no-marker)      write_snapshot ;;

  # A live backgrounded beat is sleeping. MUST allow (Check 2b).
  live-marker)    write_snapshot; printf '%s' "$(( NOW + 100 ))" > "$MARK" ;;

  # Fail-safe: every non-live marker state MUST fall through to block.
  expired-marker) write_snapshot; printf '%s' "$(( NOW - 5 ))"   > "$MARK" ;;   # SIGKILLed beat's stale marker
  garbage-marker) write_snapshot; printf 'not-a-number'          > "$MARK" ;;   # non-numeric epoch
  empty-marker)   write_snapshot; : > "$MARK" ;;                                # zero-byte marker
  marker-is-dir)  write_snapshot; mkdir -p "$MARK" ;;                           # unreadable -> -f is false

  # Precedence: the operator pause (Check 1) precedes Check 2b. A live marker is
  # also present to prove the allow is credited to PAUSE, not to the live beat.
  paused)         write_snapshot; printf '%s' "$(( NOW + 100 ))" > "$MARK"; touch "$OUT/pipeline-paused.flag" ;;

  # Gating: Check 2b must sit behind Check 2. A live marker with NO snapshot must
  # not manufacture an allow of its own.
  no-snapshot)    printf '%s' "$(( NOW + 100 ))" > "$MARK" ;;

  # A bare active pipeline with no marker and no block state, for the SEQUENCE
  # arms. Those drive the hook repeatedly and toggle the marker themselves,
  # because the property under test is a state machine over several turns and no
  # single-invocation seed can express it. Identical on disk to no-marker; the
  # name is what tells a reader which arm owns it.
  sequence)       write_snapshot ;;

  *) echo "FIXTURE ERROR: unknown case '$CASE'" >&2; exit 2 ;;
esac

printf '%s\n' "$WORK"
