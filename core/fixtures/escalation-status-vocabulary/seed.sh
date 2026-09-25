#!/usr/bin/env bash
# escalation-status-vocabulary/seed.sh — escalation files that Check 2 cannot adjudicate.
#
# Check 2 is three branches with no else. An entry whose Status is outside the published
# set satisfies none of them: not blocked, not surfaced, not recorded. No verdict is
# computed for it and the gate reports Check 2 as passing. run.sh proves the validator
# catches that, and — the load-bearing part — that its vocabulary is DERIVED from
# escalations.md rather than restated in the script.
#
# Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/scripts/validate-escalation-status-vocabulary.sh" ]; then
  VALIDATOR="$D_ROOT/core/scripts/validate-escalation-status-vocabulary.sh"
  SPEC_SRC="$D_ROOT/core/skills/ai-dlc/escalations.md"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/scripts/ai-dlc/validate-escalation-status-vocabulary.sh" ]; then
  VALIDATOR="$C_ROOT/scripts/ai-dlc/validate-escalation-status-vocabulary.sh"
  SPEC_SRC="$C_ROOT/.claude/skills/ai-dlc/escalations.md"
else
  echo "FIXTURE ERROR: validate-escalation-status-vocabulary.sh not found in either layout" >&2
  exit 2
fi
[ -f "$SPEC_SRC" ] || { echo "FIXTURE ERROR: escalations.md not found at $SPEC_SRC" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/esc-vocab.XXXXXX")" || exit 2

# ---- CLEAN: every token in the published set, DERIVED ----------------------
# GENERATED FROM THE SPEC, never hand-listed. This block used to enumerate the tokens by
# hand, and the hand-list is what broke: publishing a new terminal status made the clean
# file cover 5 of 6, and — worse — a consumer whose escalations.md predates the token got
# a clean file asserting a status its own spec does not publish, so the fixture went red
# on a pull that broke nothing. That is the machinery-vs-rulebook coupling the self-update
# gate now defers on, reproduced inside a fixture: the seed is machinery, escalations.md
# is rulebook, and a hand-list welds them to each other's versions.
#
# Deriving also makes the POSITIVE CONTROL mean what it claims. "Every published token
# passes" is only true if the file actually carries every published token.
{
  echo "# Pending Escalations"
  echo
  i=0
  awk '
    /^\*\*Status:\*\*/ || /^\*\*Terminal statuses\*\*/ {
      s = $0
      sub(/^[^:]*:[[:space:]]*/, "", s); gsub(/`/, "", s)
      n = split(s, parts, /[|]/)
      for (j = 1; j <= n; j++) { t = parts[j]; gsub(/[^A-Z_]/, "", t); if (t != "") print t }
    }
  ' "$SPEC_SRC" | sort -u | while IFS= read -r tok; do
    [ -n "$tok" ] || continue
    i=$((i + 1))
    echo "## S300-$i Dev - 2026-07-21T10:0${i}Z"
    echo "**Status:** $tok"
    echo "**Context:** derived from the published set"
    echo
  done
} > "$WORK/pending-clean.md"

# A derived file that derived NOTHING is the false zero this fixture would never notice:
# an empty clean file passes the validator trivially and the positive control means nothing.
if [ "$(grep -c '^\*\*Status:\*\*' "$WORK/pending-clean.md")" -lt 2 ]; then
  echo "FIXTURE ERROR: derived fewer than 2 status tokens from $SPEC_SRC; the clean file would pass vacuously" >&2
  exit 2
fi

# ---- DRIFTED: two tokens core never defined --------------------------------
# FILED and OPEN are the exact tokens the reference consumer accumulated 8 entries on.
cat > "$WORK/pending-drift.md" <<'MD'
# Pending Escalations

## S300-1 Dev - 2026-07-21T10:00Z
**Status:** HARD_BLOCK
**Context:** needs an operator call

## CO-S300-CARRIED-FORWARD - 2026-07-21T13:00Z
**Status:** FILED
**Context:** carried to the next sprint

## CO-S300-STILL-OPEN - 2026-07-21T14:00Z
**Status:** OPEN
**Context:** nobody has looked at it
MD

# ---- MID-ENTRY: the Status field is not at line start -----------------------
# The ledger's own measuring regex anchored `**Status:**` to line start and called its
# count a lower bound for exactly this reason. A token invisible to the naive validator
# anyone writes first is no less invisible to Check 2.
cat > "$WORK/pending-midentry.md" <<'MD'
# Pending Escalations

## S300-6 Dev - 2026-07-21T15:00Z
Carried from the prior sprint. **Status:** TRIAGED — see the triage log.
**Context:** filed against the wrong component
MD

# ---- WHICH OCCURRENCE OF `**Status:**` IS THE ENTRY'S STATUS -----------------
# The four files below are one property each, and each is a PAIR: an offender that must
# be reported and a near-miss that must not. One direction alone leaves a validator that
# flags everything looking identical to one that discriminates.
#
# BOTH TOKENS ARE DERIVED, NOT TYPED. A hand-written in-vocabulary token welds this seed
# to whatever escalations.md published the day it was written — the same coupling the
# clean file above was rewritten to remove — and a hand-written out-of-vocabulary token
# silently becomes a legitimate status the release someone publishes it, at which point
# every offender here turns into a near-miss and the file goes quietly vacuous.
VOCAB_ALL="$(awk '
  /^\*\*Status:\*\*/ || /^\*\*Terminal statuses\*\*/ {
    s = $0
    sub(/^[^:]*:[[:space:]]*/, "", s); gsub(/`/, "", s)
    n = split(s, parts, /[|]/)
    for (j = 1; j <= n; j++) { t = parts[j]; gsub(/[^A-Z_]/, "", t); if (t != "") print t }
  }
' "$SPEC_SRC" | sort -u)"
GOOD_TOK="$(printf '%s\n' "$VOCAB_ALL" | head -1)"
BAD_TOK="NOT_A_PUBLISHED_STATUS"

# Both halves of the pair are CHECKED, in the same invocation, because each one silently
# inverts every assertion below if it is wrong. The out-of-vocabulary half is the one a
# reader assumes: a token nobody has published today becomes a legitimate status the
# release somebody publishes it, and on that day every offender here turns into a
# near-miss while the file keeps printing `ok`.
[ -n "$GOOD_TOK" ] || {
  echo "FIXTURE ERROR: derived no in-vocabulary token from $SPEC_SRC; every near-miss below would assert nothing" >&2
  exit 2
}
if grep -qx "$BAD_TOK" <<VOCAB
$VOCAB_ALL
VOCAB
then
  echo "FIXTURE ERROR: '$BAD_TOK' is now a PUBLISHED status in $SPEC_SRC. Every offender" >&2
  echo "      below is a near-miss and this whole file asserts nothing. Pick another token." >&2
  exit 2
fi

# (a) AN APPENDED RESOLUTION IS THE TOKEN ADJUDICATED.
# Seeded from what the PRODUCER writes, never from what the reader accepts: escalations.md
# prescribes "**Escalation entry format (append, do not overwrite):**" and its resolution
# lifecycle sets the terminal status in a later edit, carrying the
# `**Operator authorization:**` line with it. So the live status of a resolved entry is its
# LAST field and the authorship token above it is the one it REPLACED. A first-wins reader
# adjudicates the replaced token — which is how a validator whose entire job is rejecting an
# out-of-vocabulary status came to report PASS on one.
cat > "$WORK/pending-appended.md" <<MD
# Pending Escalations

## S300-7 Dev - 2026-07-21T16:00Z
**Status:** HARD_BLOCK
**Context:** needs an operator call
**Operator authorization:** 2026-07-21T17:00Z | "go ahead and close it out"
**Status:** $BAD_TOK
MD

cat > "$WORK/pending-appended-ok.md" <<MD
# Pending Escalations

## S300-7 Dev - 2026-07-21T16:00Z
**Status:** HARD_BLOCK
**Context:** needs an operator call
**Operator authorization:** 2026-07-21T17:00Z | "go ahead and close it out"
**Status:** $GOOD_TOK
MD

# (b) PROSE ABOVE THE FIELD DOES NOT OUTRANK IT.
# The match is deliberately not line-anchored, so under a first-wins tie-break a
# `**Status:**` written inside a sentence SHIELDS the real field below it: the widening
# catches a case it also created. The near-miss is the same shape with the tokens swapped,
# so a reader that simply prefers prose fails it.
cat > "$WORK/pending-prose-above.md" <<MD
# Pending Escalations

## S300-8 Dev - 2026-07-21T18:00Z
**Context:** this entry carried **Status:** $GOOD_TOK for one sprint before it was refiled.
**Status:** $BAD_TOK
MD

cat > "$WORK/pending-prose-above-ok.md" <<MD
# Pending Escalations

## S300-8 Dev - 2026-07-21T18:00Z
**Context:** this entry carried **Status:** $BAD_TOK for one sprint before it was refiled.
**Status:** $GOOD_TOK
MD

# (d) PROSE BELOW THE FIELD DOES NOT OUTRANK IT EITHER, AND THE NEAR-MISS IS THE WHOLE ARM.
# This pair is the one that separates the shipped reading from the minimal
# last-match-ANYWHERE one, and the OFFENDER ALONE CANNOT DO IT: both readings report the
# offender, one on the real bad token and one on a junk token it extracted from the prose —
# the right verdict for the wrong reason. The near-miss is where they part. Its body is the
# reference consumer's own shape, an entry whose field is a published status and whose prose
# below mentions the field by name; last-anywhere reads the token `I` out of "It therefore"
# and emits a FALSE FINDING on the file the gate actually reads.
#
# THE TRAILING SENTENCE SHARES A LINE WITH THE MENTION, AND THAT IS THE WHOLE PROPERTY.
# The reader walks LINES: the junk token a last-anywhere reading extracts has to sit on a
# line that ITSELF carries `**Status:**`. Soft-wrapping "It therefore" onto the next line —
# which reads like an innocent reflow, and is how this pair was first written — moves the
# token out of the mutant's reach, the near-miss goes quiet under BOTH readings, and the
# canon-guard mutant scores as SURVIVED against an arm that is working. Measured: one line
# gives rc=1 token=I, wrapped gives rc=0 token=none. Keep the sentence on this line.
cat > "$WORK/pending-prose-below-ok.md" <<MD
# Pending Escalations

## S300-9 Dev - 2026-07-21T19:00Z
**Status:** $GOOD_TOK
**Context:** the entry carried NO \`**Status:**\` line from filing until 2026-07-20. It therefore matched no branch.
MD

cat > "$WORK/pending-prose-below.md" <<MD
# Pending Escalations

## S300-9 Dev - 2026-07-21T19:00Z
**Status:** $BAD_TOK
**Context:** the entry carried NO \`**Status:**\` line from filing until 2026-07-20. It therefore matched no branch.
MD

# ---- EMPTY, BLANK, HEADING-ONLY and UNPARSED --------------------------------
# The first two hold no non-whitespace byte and are the ABSENT state. The other two are
# POPULATED files that parse to zero records, and must never be reported as empty. The last
# is the reference consumer's own shape (live DA- entries written as bullets, no
# `**Status:**` field anywhere): a grammar failure, not an absence.
: > "$WORK/pending-empty.md"
printf '\n \n' > "$WORK/pending-blank.md"
printf '# Pending Escalations\nNo escalation has been filed this sprint.\n' > "$WORK/pending-heading.md"
cat > "$WORK/pending-unparsed.md" <<'MD'
# Pending Escalations

## DA-283 — deferral of the ingest retry story
- Status: awaiting operator
- Raised by: lead, 2026-07-21
- Decision needed: defer to the next sprint or split the story

## DA-284 — scope of the audit backfill
- Status: awaiting operator
- Decision needed: backfill all sprints or only the current one
MD

cat > "$WORK/env.sh" <<ENV
VALIDATOR="$VALIDATOR"
SPEC_SRC="$SPEC_SRC"
WORK="$WORK"
CLEAN="$WORK/pending-clean.md"
DRIFT="$WORK/pending-drift.md"
MIDENTRY="$WORK/pending-midentry.md"
GOOD_TOK="$GOOD_TOK"
BAD_TOK="$BAD_TOK"
APPENDED="$WORK/pending-appended.md"
APPENDED_OK="$WORK/pending-appended-ok.md"
PROSE_ABOVE="$WORK/pending-prose-above.md"
PROSE_ABOVE_OK="$WORK/pending-prose-above-ok.md"
PROSE_BELOW="$WORK/pending-prose-below.md"
PROSE_BELOW_OK="$WORK/pending-prose-below-ok.md"
EMPTY="$WORK/pending-empty.md"
BLANK="$WORK/pending-blank.md"
HEADING="$WORK/pending-heading.md"
UNPARSED="$WORK/pending-unparsed.md"
ENV

printf '%s\n' "$WORK"
