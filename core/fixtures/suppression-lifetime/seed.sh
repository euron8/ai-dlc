#!/usr/bin/env bash
# suppression-lifetime/seed.sh — cases for the suppression lifetime arm.
#
# THE METRICS FILE IS SEEDED IN BOTH JSON SPACINGS ON PURPOSE. The reference
# consumer's real gate-metrics.jsonl carries 337 rows written `"check":"1"` and 386
# written `"check": "1"` — the two spellings track which lead session wrote them. A
# validator anchored to one spacing reads 47% of the corpus and reports clean over the
# rest. Every case file here mixes both so an assertion cannot pass by reading only the
# convenient half.
#
# Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
if [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-suppression-lifetime.sh" ]; then
  VALIDATOR="$ROOT/core/scripts/validate-suppression-lifetime.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/validate-suppression-lifetime.sh" ]; then
  VALIDATOR="$ROOT/scripts/ai-dlc/validate-suppression-lifetime.sh"
else
  echo "FIXTURE ERROR: validate-suppression-lifetime.sh not found in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/supp-lifetime.XXXXXX")" || exit 2
mkdir -p "$WORK/cases"

# ---- the catalog -----------------------------------------------------------
MAP="$WORK/enforcement-map.yaml"
cat > "$MAP" <<'YAML'
checks:
  - id: 2
    title: no-unresolved-hard-blocks
    enforcer: []
    adjudication: llm
  - id: 16
    title: gate-dormancy
    enforcer: []
    adjudication: script
  - id: 32
    title: bmad-invocation-resolves
    enforcer: []
    adjudication: script
  - id: H1
    title: harness-meta-check
    enforcer: []
    adjudication: lead
YAML

# ---- gate metrics ----------------------------------------------------------
# G1 < G2 < G3, all after the authorization timestamp A0 used by the entries below.
# Rows alternate spacing deliberately: odd rows unspaced, even rows spaced.
G1="2026-05-01T01:00:00Z"
G2="2026-05-02T01:00:00Z"
G3="2026-05-03T01:00:00Z"

emit_unspaced() { # <ts> <check> <verdict>
  printf '{"v":1,"sprint":400,"gate":"planning","phase":"a→b","ts":"%s","sha":"deadbeef","catalog":"core","check":"%s","title":"t","verdict":"%s","defect_class":null,"evidence":"e","tok_slice":1}\n' "$1" "$2" "$3"
}
emit_spaced() {   # <ts> <check> <verdict>  — the majority form in the real corpus
  printf '{"v": 1, "sprint": 400, "gate": "planning", "phase": "a→b", "ts": "%s", "sha": "deadbeef", "catalog": "core", "check": "%s", "title": "t", "verdict": "%s", "defect_class": null, "evidence": "e", "tok_slice": 1}\n' "$1" "$2" "$3"
}

# still-failing: check 32 FAILs at every gate. Check 32's rows use the SPACED form only,
# so an extractor that reads just the unspaced half cannot see this check at all.
GM_FAILING="$WORK/gm-failing.jsonl"
{
  emit_unspaced "$G1" "16" "PASS"; emit_spaced "$G1" "32" "FAIL"
  emit_unspaced "$G2" "16" "PASS"; emit_spaced "$G2" "32" "FAIL"
  emit_unspaced "$G3" "16" "PASS"; emit_spaced "$G3" "32" "FAIL"
  emit_spaced   "$G1" "H1" "PASS"; emit_unspaced "$G2" "H1" "PASS"
} > "$GM_FAILING"

# fixed: check 32 FAILs at G1/G2 then PASSes at G3 — the "cause was fixed" case.
GM_FIXED="$WORK/gm-fixed.jsonl"
{
  emit_unspaced "$G1" "16" "PASS"; emit_spaced "$G1" "32" "FAIL"
  emit_unspaced "$G2" "16" "PASS"; emit_spaced "$G2" "32" "FAIL"
  emit_unspaced "$G3" "16" "PASS"; emit_spaced "$G3" "32" "PASS"
} > "$GM_FIXED"

# unparseable — exists but carries no readable ts/check/verdict at all.
GM_BROKEN="$WORK/gm-broken.jsonl"
printf 'not json at all\n{oops\n' > "$GM_BROKEN"

A0="2026-04-30T00:00:00Z"   # authorization, before every gate above

mkcase() { mkdir -p "$WORK/cases/$1"; printf '%s' "$WORK/cases/$1/pending.md"; }

# --- 1. well-formed SUPPRESSED, still inside its lifetime -------------------
f="$(mkcase in-force)"
cat > "$f" <<EOF
## [S400 gate — bmad invocation] [lead] - ${A0}
**Status:** SUPPRESSED
**Suppresses:** [core] 32 — bmad-invocation-resolves
**Expires after:** 3 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"

Body text mentioning Check 32 in prose.
EOF

# --- 2. well-formed SUPPRESSED, PAST its lifetime, check still failing ------
f="$(mkcase expired-still-failing)"
cat > "$f" <<EOF
## [S400 gate — bmad invocation] [lead] - ${A0}
**Status:** SUPPRESSED
**Suppresses:** [core] 32 — bmad-invocation-resolves
**Expires after:** 1 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF

# --- 3. PAST its lifetime, but the cause was FIXED --------------------------
f="$(mkcase expired-but-fixed)"
cat > "$f" <<EOF
## [S400 gate — bmad invocation] [lead] - ${A0}
**Status:** SUPPRESSED
**Suppresses:** [core] 32 — bmad-invocation-resolves
**Expires after:** 1 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF

# --- 4. malformed: no **Suppresses:** --------------------------------------
# THE DELIMITER REGRESSION. This entry's Suppresses field is EMPTY while later fields
# are populated. If the record delimiter is IFS whitespace, `read` collapses the empty
# field, every later field shifts left, and this reads as a well-formed entry naming
# nothing — malformed input scoring as clean.
f="$(mkcase malformed-no-target)"
cat > "$f" <<EOF
## [S400 gate — no target named] [lead] - ${A0}
**Status:** SUPPRESSED
**Expires after:** 2 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF

# --- 5. malformed: expiry out of the permitted 1..3 -------------------------
f="$(mkcase expiry-out-of-range)"
cat > "$f" <<EOF
## [S400 gate — forever] [lead] - ${A0}
**Status:** SUPPRESSED
**Suppresses:** [core] 32 — bmad-invocation-resolves
**Expires after:** 99 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF

# --- 6. suppresses an id that is not in the catalog (the "Check 924" class) --
f="$(mkcase unknown-check-id)"
cat > "$f" <<EOF
## [S400 gate — third leg] [lead] - ${A0}
**Status:** SUPPRESSED
**Suppresses:** [core] 924 — a token that is not a check
**Expires after:** 1 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF

# --- 7. RESOLVED closing an entry that names a still-failing check ----------
f="$(mkcase terminal-names-failing)"
cat > "$f" <<EOF
## [S400] [Lead] - ${A0} — gate BLOCKED
**Status:** RESOLVED
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"

The gate blocked on Check 32 and the operator waved it through.
EOF

# --- 8. RESOLVED naming only a PASSING check — must not fire ---------------
f="$(mkcase terminal-names-passing)"
cat > "$f" <<EOF
## [S400] [Lead] - ${A0} — gate note
**Status:** RESOLVED
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"

Check 16 was discussed and is green.
EOF

# --- 9. nothing in scope at all --------------------------------------------
f="$(mkcase empty)"
cat > "$f" <<EOF
## [S400] [Lead] - ${A0} — informational
**Status:** DECIDED_AUTONOMOUSLY

No check named here.
EOF

# ---- baseline files --------------------------------------------------------
printf 'TERMINAL:##[S400][Lead]-%s—gateBLOCKED\n' "$A0" > "$WORK/baseline-good.txt"
printf 'TERMINAL:##[S400][Lead]-%s—gateBLOCKED\nEXPIRED:16\n' "$A0" > "$WORK/baseline-stale.txt"

cat > "$WORK/env.sh" <<EOF
VALIDATOR="$VALIDATOR"
WORK="$WORK"
MAP="$MAP"
GM_FAILING="$GM_FAILING"
GM_FIXED="$GM_FIXED"
GM_BROKEN="$GM_BROKEN"
CASES="$WORK/cases"
BASELINE_GOOD="$WORK/baseline-good.txt"
BASELINE_STALE="$WORK/baseline-stale.txt"
EOF

printf '%s\n' "$WORK"
