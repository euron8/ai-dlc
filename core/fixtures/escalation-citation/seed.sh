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

# --- the CROSS-SESSION corpus ---------------------------------------------------------------
# A sprint spans sessions. The operator adjudicates on Monday (spoke.jsonl) and the gate re-runs
# on Friday, when `transcript_path` names Friday's session (gate.jsonl) -- which by construction
# does not contain Monday's words. A single-file check calls the honest lead a forger and stops
# the gate; the corpus is where the citation actually lives.
mkdir -p "$ROOT/corpus"
cat > "$ROOT/corpus/spoke.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-07-12T03:00:00Z","message":{"content":"Cut the contested clause and proceed to stories."}}
JSONL
cat > "$ROOT/corpus/gate.jsonl" <<'JSONL'
{"type":"user","timestamp":"2026-07-15T09:00:00Z","message":{"content":"/ai-dlc resume"}}
{"type":"assistant","timestamp":"2026-07-15T09:01:00Z","message":{"content":[{"type":"text","text":"Resuming at the planning gate."}]}}
JSONL

CITE_CROSS='2026-07-12T03:00:00Z | "Cut the contested clause and proceed to stories."'
CITE_CROSS_FAKE='2026-07-12T03:00:00Z | "zzz no operator ever typed this phrase zzz"'

# (h) S50 RESOLVED citing a GENUINE operator message that lives in a session the gate cannot name.
: > "$ROOT/pending-crosssession.md"; entry "$ROOT/pending-crosssession.md" S50-ITEM-6 RESOLVED "$CITE_CROSS"

# (i) S50 RESOLVED citing words no operator typed ANYWHERE in the corpus. The corpus arm must not
#     widen into fail-open: scanning more sessions must never turn a fabrication into a pass.
: > "$ROOT/pending-crossfake.md";    entry "$ROOT/pending-crossfake.md"    S50-ITEM-7 RESOLVED "$CITE_CROSS_FAKE"

printf '%s\n' "$ROOT"
