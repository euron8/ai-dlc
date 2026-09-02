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

# --- corpora that EXIST and hold no ground truth ---------------------------------------------
# `--transcript-dir` was tested for EXISTENCE only, never for CONTENT. With nothing to search,
# the citation query returned NOMATCH and this validator reported the OPERATOR as having said
# nothing -- an accusation ("This is the S290 failure"), where the true state is that the gate
# had no corpus. The two exits are both 1, so only the MESSAGE separates them.
#
# The corpus reader selects `*.jsonl` and only those (`validate-steering-budget.sh:427`), so a
# directory of sidecar files is exactly as blind as an empty one. Both shapes are seeded
# because a narrowing keyed on "the directory has no entries" passes one and fails the other.
mkdir -p "$ROOT/dir-empty"

mkdir -p "$ROOT/dir-sidecar"
printf 'not a transcript\n'           > "$ROOT/dir-sidecar/README.md"
printf '{"note":"summary sidecar"}\n' > "$ROOT/dir-sidecar/summary.json"
printf 'session-abc123\n'             > "$ROOT/dir-sidecar/.session-id"

# --- the citation is a FIELD, and a line-oriented greedy regex read the wrong half of it ------
# Every shape below is one the reference consumer actually wrote. Measured over the 106 distinct
# `Operator authorization:` citations in the whole history of its `pending.md` and
# `pending-archive.md`: 98 carry exactly one quoted segment and are unaffected by any of this;
# 8 do not, and those 8 are the population these four entries stand in for.
#
# The two ORDER seeds are one property from each other -- same two quoted segments, swapped --
# because the pre-fix extractor took the LAST one. That made a genuine citation with anything
# after it a reported S290 fabrication, and made an INVENTED disposition pass whenever a real
# operator substring trailed it. `pending-real.md` and `pending-fabricated.md` above are the
# near-miss twins: one quoted segment each, and neither verdict may move.
CITE_ORDER_GOOD_FIRST='2026-07-12T03:00:00Z | "reframe the AC as a class invariant" / "zzz no operator ever typed this phrase zzz"'
CITE_ORDER_GOOD_LAST='2026-07-12T03:00:00Z | "zzz no operator ever typed this phrase zzz" / "reframe the AC as a class invariant"'

# An ODD quote count: the capture used to be the CONNECTIVE BETWEEN two quotes. The consumer's
# own `"1. RETIRE" and "This work was already done in` yielded ` and `, five characters, and
# failed as "too short" naming none of the operator's words.
CITE_CONNECTIVE='2026-07-12T03:00:00Z | "1. RETIRE" and "reframe the AC as a class invariant'

# A citation that continues on the NEXT line. The producing awk is line-oriented, so the closing
# quote is on a line it never reads; the old fallback then kept the opening `"` inside the
# needle, and no operator message contains that character there. This one also carries no `|`,
# which is the shape that made the fallback return the whole label line.
CITE_UNTERMINATED='2026-07-12T03:00:00Z, this session, verbatim: "reframe the AC as a class invariant'

: > "$ROOT/pending-order-good-first.md"; entry "$ROOT/pending-order-good-first.md" S50-ITEM-8  RESOLVED "$CITE_ORDER_GOOD_FIRST"
: > "$ROOT/pending-order-good-last.md";  entry "$ROOT/pending-order-good-last.md"  S50-ITEM-9  RESOLVED "$CITE_ORDER_GOOD_LAST"
: > "$ROOT/pending-connective.md";       entry "$ROOT/pending-connective.md"       S50-ITEM-10 RESOLVED "$CITE_CONNECTIVE"
: > "$ROOT/pending-unterminated.md";     entry "$ROOT/pending-unterminated.md"     S50-ITEM-11 RESOLVED "$CITE_UNTERMINATED"

printf '%s\n' "$ROOT"
