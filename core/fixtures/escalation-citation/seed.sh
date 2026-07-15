#!/usr/bin/env bash
# Seed for validate-escalation-resolution.sh -- an operator-gated HARD_BLOCK must not be marked
# RESOLVED by an operator who never spoke (the literal S290 fabrication surface: six
# `## S290-* Lead (...)` entries flipped to RESOLVED in an operator-silent window).
set -eu
ROOT="$(mktemp -d)"

# One entry. $1 file  $2 header-id  $3 status  $4 (optional) authorization line value
entry() {
  local file="$1" id="$2" status="$3" auth="${4:-}"
  {
    printf '## %s Lead (gate [planning]) - 2026-07-12\n' "$id"
    printf '**Status:** %s\n' "$status"
    printf '**Blocker type:** trade-off\n'
    printf '**Context:** a decision was needed on the item.\n'
    printf '**Decision/Question:** which approach to take.\n'
    [ -n "$auth" ] && printf '**Operator authorization:** %s\n' "$auth"
    printf '\n'
  } >> "$file"
}

CITE_REAL='2026-07-12T03:00:00Z | "reframe the AC as a class invariant"'
CITE_FAKE='2026-07-12T03:00:00Z | "the operator authorized this disposition"'

# (b) S50 RESOLVED, NO citation -- the S290 shape (Lead-authored, no operator message).
: > "$ROOT/pending-missing.md";     entry "$ROOT/pending-missing.md"     S50-ITEM-1 RESOLVED

# (c) S50 RESOLVED, citation whose words appear in NO genuine operator message.
: > "$ROOT/pending-fabricated.md";  entry "$ROOT/pending-fabricated.md"  S50-ITEM-2 RESOLVED "$CITE_FAKE"

# (d) S50 RESOLVED, citation verbatim in a genuine operator message.
: > "$ROOT/pending-real.md";        entry "$ROOT/pending-real.md"        S50-ITEM-3 RESOLVED "$CITE_REAL"

# (e) LEGACY: a prior-sprint RESOLVED HARD_BLOCK with no citation. Checking --sprint 50 must NOT
#     flag it -- it was resolved in a session this transcript never saw.
: > "$ROOT/pending-legacy.md";      entry "$ROOT/pending-legacy.md"      S49-OLD-1 RESOLVED

# (f) DECIDED_AUTONOMOUSLY: the honest-attribution escape valve. A decision the lead openly made
#     on its own needs no operator citation.
: > "$ROOT/pending-autonomous.md";  entry "$ROOT/pending-autonomous.md"  S50-ITEM-4 DECIDED_AUTONOMOUSLY

# (a) VACUOUS: only a legacy entry and an autonomous one -- nothing in scope needs a citation.
: > "$ROOT/pending-clean.md"
entry "$ROOT/pending-clean.md" S49-OLD-2 RESOLVED
entry "$ROOT/pending-clean.md" S50-ITEM-5 DECIDED_AUTONOMOUSLY

# --- transcripts ---------------------------------------------------------------------------
cat > "$ROOT/real.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-07-12T01:00:00Z","message":{"content":"/ai-dlc Sprint 50."}}
{"type":"user","timestamp":"2026-07-12T03:00:00Z","message":{"content":"Reframe the AC as a class invariant, not a per-site fix."}}
JSONL

cat > "$ROOT/silent.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-07-12T01:00:00Z","message":{"content":"/ai-dlc Sprint 50."}}
{"type":"assistant","timestamp":"2026-07-12T02:30:00Z","message":{"content":[{"type":"text","text":"Two HARD_BLOCKs open; pausing for your adjudication."}]}}
JSONL

printf '%s\n' "$ROOT"
