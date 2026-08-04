#!/usr/bin/env bash
# request-coverage/seed.sh — one captured request and FOUR briefs, differing only in what
# their sprint-42 LOCKED bullets commit to.
#
# The brief shapes are copied from a real consumer's product-brief.md, which matters in one
# specific way: the brief carries a PREVIOUS sprint's block that mentions the very identifiers
# sprint 42 dropped. That is not decoration. A coverage check that reads the whole block, or
# that picks "the block for this sprint" by which ids appear anywhere inside it, scores those
# mentions as coverage and passes the failure it exists to catch. covered/ and dropped/ differ
# ONLY in the sprint-42 bullets; the S41 block is byte-identical in both.
#
# Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
D_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
C_ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$D_ROOT" ] && [ -f "$D_ROOT/core/scripts/validate-request-coverage.sh" ]; then
  VALIDATOR="$D_ROOT/core/scripts/validate-request-coverage.sh"
elif [ -n "$C_ROOT" ] && [ -f "$C_ROOT/scripts/ai-dlc/validate-request-coverage.sh" ]; then
  VALIDATOR="$C_ROOT/scripts/ai-dlc/validate-request-coverage.sh"
else
  echo "FIXTURE ERROR: validate-request-coverage.sh not found in either layout" >&2; exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/req-cov.XXXXXX")" || exit 2

ASK='Sprint 42: take the WIDGET-SYNC indexing track (Epic-WGS, plus CO-S41-BACKFILL-GAP folded
in) from its locked S41 requirements through implementation to production. Author stories from
the LOCKED block (LR-S41-0..7) and the spec memlog (CAP-1..6). Carry-over: CO-S40-CREDS-TTL.
Stretch, if the epic completes early: CO-S41-PROMOTION-MANDATE.'

SHA="$(printf '%s' "$ASK" | { shasum -a 256 2>/dev/null || sha256sum; } | cut -d' ' -f1)"

cat > "$WORK/requests.md" <<EOF
# Operator Requests

---

## 2026-08-02T18:00:34Z -- /ai-dlc
- Session: sess-1
- Bytes: $(printf '%s' "$ASK" | wc -c | tr -d '[:space:]')
- SHA256: ${SHA}

\`\`\`text
${ASK}
\`\`\`

EOF

# A request naming NO identifiers at all. 5 of 23 measured asks look like this.
cat > "$WORK/requests-noids.md" <<'EOF'
# Operator Requests

---

## 2026-08-02T19:00:00Z -- /ai-dlc
- Session: sess-2
- Bytes: 96
- SHA256: 0000000000000000000000000000000000000000000000000000000000000000

```text
Rebalancing sometimes strands capital in the wallet. Find the root cause and fix it.
```

EOF

# ---- the PREVIOUS sprint's block. Identical in every brief below. --------------
# It carries WIDGET-SYNC, CAP-, LR-S41- and CO-S41-BACKFILL-GAP — every identifier sprint 42
# drops. This is the trap.
PRIOR=$(cat <<'MD'
<!-- LOCKED_REQUIREMENTS — DO NOT MODIFY DURING VALIDATION -->
### LOCKED block: S41
- **LR-S41-0 (WIDGET-SYNC pool identity, operator-specified):** index the WIDGET-SYNC
  pool. Capability coverage is CAP-1 through CAP-6 in the spec memlog.
- **LR-S41-3 (CO-S41-BACKFILL-GAP, folded in):** the backfill gap ships with this work.
- **LR-S41-7 (Epic-WGS):** the WIDGET-SYNC epic closes here.
<!-- END LOCKED_REQUIREMENTS -->
MD
)

mk_brief() {  # $1 dest, $2 sprint-42 bullets
  { printf '# Product Brief\n\n%s\n\n' "$PRIOR"
    printf '<!-- LOCKED_REQUIREMENTS — DO NOT MODIFY DURING VALIDATION -->\n'
    printf '### LOCKED block: S42\n'
    printf '%s\n' "$2"
    printf '<!-- END LOCKED_REQUIREMENTS -->\n'
  } > "$1"
}

# dropped/ — the reference failure. The sprint took the two carry-over items the ask listed
# last and dropped the headline epic. Note LR-S42-0's body MENTIONS LR-S41-2 as background:
# that mention must NOT count as coverage.
mk_brief "$WORK/brief-dropped.md" \
'- **LR-S42-0 (`CO-S40-CREDS-TTL`, preflight):** rotate the credential TTL preflight. Context:
  the failure mode resembles LR-S41-2, which is why the ordering matters.
- **LR-S42-1 (`CO-S41-BACKFILL-GAP`):** close the backfill gap.
<!-- NOT-IN-SCOPE: CO-S41-PROMOTION-MANDATE — operator marked this stretch -->'

# covered/ — same two bullets, plus the epic actually taken and the stretch item
# dispositioned by name.
mk_brief "$WORK/brief-covered.md" \
'- **LR-S42-0 (`CO-S40-CREDS-TTL`, preflight):** rotate the credential TTL preflight.
- **LR-S42-1 (`CO-S41-BACKFILL-GAP`):** close the backfill gap.
- **LR-S42-2 (WIDGET-SYNC, from `LR-S41-0..7`, capabilities `CAP-1..6`, `Epic-WGS`):** take the
  WIDGET-SYNC track through to production.
<!-- NOT-IN-SCOPE: CO-S41-PROMOTION-MANDATE — operator marked this stretch -->'

# dispositioned/ — the epic is NOT taken, and the brief says so by name for each identifier.
# A sprint is allowed to decline work; it is not allowed to be silent about it.
mk_brief "$WORK/brief-dispositioned.md" \
'- **LR-S42-0 (`CO-S40-CREDS-TTL`, preflight):** rotate the credential TTL preflight.
- **LR-S42-1 (`CO-S41-BACKFILL-GAP`):** close the backfill gap.
<!-- NOT-IN-SCOPE: LR-S41-0..7 — deferred to S43 by operator ruling -->
<!-- NOT-IN-SCOPE: CAP-1..6 — deferred with the epic -->
<!-- NOT-IN-SCOPE: Epic-WGS — deferred with the epic -->
<!-- NOT-IN-SCOPE: CO-S41-PROMOTION-MANDATE — operator marked this stretch -->'

# noscope/ — a brief with blocks, but none declaring an LR of sprint 42.
mk_brief_noscope() {
  { printf '# Product Brief\n\n%s\n' "$PRIOR"; } > "$WORK/brief-noscope.md"
}
mk_brief_noscope

cat > "$WORK/env.sh" <<ENV
VALIDATOR="$VALIDATOR"
WORK="$WORK"
REQ="$WORK/requests.md"
REQ_NOIDS="$WORK/requests-noids.md"
DROPPED="$WORK/brief-dropped.md"
COVERED="$WORK/brief-covered.md"
DISPOSITIONED="$WORK/brief-dispositioned.md"
NOSCOPE="$WORK/brief-noscope.md"
SHA="$SHA"
ENV

printf '%s\n' "$WORK"
