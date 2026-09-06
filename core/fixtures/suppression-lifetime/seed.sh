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

# --- 10. a suppression declared by its FIELDS but classified as something else ---
# The reproduced defect. `**Status:**` is read as the first [A-Z_] run after the label,
# so this line classifies as DECIDED_AUTONOMOUSLY, the `case` has no branch for it, and
# the three fields below are never read. The tool's `suppressed=` figure is identical
# whether this entry exists or not.
f="$(mkcase attempt-first-token)"
cat > "$f" <<EOF
## [S400 gate — dispatch guard] [lead] - ${A0}
**Status:** DECIDED_AUTONOMOUSLY (root cause), with a SUPPRESSED marker on Check 32 below.
**Suppresses:** [core] 32 — bmad-invocation-resolves
**Expires after:** 2 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF

# --- 11. NEAR-MISS: the word SUPPRESSED on the status line, no suppression fields ---
# Separates the arm from the rule that was measured and rejected. Flagging a second
# vocabulary token anywhere on the status line scores 5 of 108 lines on the reference
# consumer and all five are negations of this exact shape. This entry must stay SILENT.
f="$(mkcase attempt-word-only)"
cat > "$f" <<EOF
## [S400 gate — a finding, not a disposition] [lead] - ${A0}
**Status:** DECIDED_AUTONOMOUSLY (Rule 12 Tier 2) — not a HARD_BLOCK and not a SUPPRESSED entry.

Body text mentioning Check 16 in prose.
EOF

# --- 12. NEAR-MISS: the same fields under a status that DOES classify SUPPRESSED ---
# The corrected form of case 10. Same fields, same target, same citation; only the
# status token differs. If this fires, the arm is keyed on the fields alone and every
# legitimate suppression in the corpus trips it.
f="$(mkcase attempt-corrected)"
cat > "$f" <<EOF
## [S400 gate — dispatch guard] [lead] - ${A0}
**Status:** SUPPRESSED (operator, ${A0})
**Suppresses:** [core] 32 — bmad-invocation-resolves
**Expires after:** 3 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF

# --- 13. the same discard reached through a TERMINAL branch ----------------------
# RESOLVED has its own `case` branch, so an arm written as the case's `else` would never
# see this entry. Its suppression fields are discarded exactly as case 10's are.
f="$(mkcase attempt-under-terminal)"
cat > "$f" <<EOF
## [S400 gate — closed out] [lead] - ${A0}
**Status:** RESOLVED (the SUPPRESSED marker below carries the authorization)
**Suppresses:** [core] 16 — gate-dormancy
**Expires after:** 2 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF

# ---- THE CWD WORLDS --------------------------------------------------------
# The metrics file is the ONE input this script locates for itself, and it is located while
# the process cwd is whatever the caller happened to be in. `ai-dlc-gate-remediation-guard.sh`
# arm 7b and `validate-gate-adjudication.sh` both invoke it with the project root in the
# environment and no `--gate-metrics`, from a cwd that is a different project as often as not.
# So each world below is a PAIR: a root that carries the timeline the answer must come from,
# and a decoy cwd carrying a DIFFERENT timeline that must not be read. Every case above passes
# `--gate-metrics` explicitly and therefore cannot express this at all.
#
# The catalog is seeded INSIDE each root, at the root-anchored candidate, so a run that never
# received the root refuses instead of falling back to a catalog it found some other way.
sl_gm_series() { # <file> <n-gates> — n distinct gate events after A0, check 32 FAILing
  local f="$1" n="$2" i=1
  mkdir -p "$(dirname "$f")"
  : > "$f"
  while [ "$i" -le "$n" ]; do
    if [ "$((i % 2))" -eq 1 ]; then
      emit_unspaced "2026-05-0${i}T01:00:00Z" "32" "FAIL" >> "$f"
    else
      emit_spaced   "2026-05-0${i}T01:00:00Z" "32" "FAIL" >> "$f"
    fi
    i=$((i + 1))
  done
}

sl_world_root() { # <dir> — a project root: catalog at the root-anchored candidate + pending.md
  mkdir -p "$1/core/skills/ai-dlc"
  cp "$MAP" "$1/core/skills/ai-dlc/enforcement-map.yaml"
  cat > "$1/pending.md" <<EOF
## [S400 gate — bmad invocation] [lead] - ${A0}
**Status:** SUPPRESSED
**Suppresses:** [core] 32 — bmad-invocation-resolves
**Expires after:** 3 gates
**Operator authorization:** ${A0} | "Override, proceed, file backlog item"
EOF
}

# WORLD A — the root HAS a timeline (2 gates, inside the entry's 3-gate lifetime) and the decoy
# cwd has a longer one (9 gates, past it). The two answers are in force / not in force, so an
# arm reading `in_force` alone discriminates.
SL_CWD_A_ROOT="$WORK/cwd-a/root"
SL_CWD_A_DECOY="$WORK/cwd-a/decoy"
mkdir -p "$SL_CWD_A_ROOT" "$SL_CWD_A_DECOY"
sl_world_root "$SL_CWD_A_ROOT"
sl_gm_series "$SL_CWD_A_ROOT/_bmad-output/implementation-artifacts/gate-metrics.jsonl" 2
sl_gm_series "$SL_CWD_A_DECOY/_bmad-output/implementation-artifacts/gate-metrics.jsonl" 9

# WORLD B — the root has NO timeline at any candidate and the decoy cwd has a SHORT one, which
# would leave the entry in force if the resolver ever fell back to the cwd. This is the world
# that separates the fix from "look at the root first, then the cwd": that wrong fix is
# invisible in world A, where the root answers on the first candidate.
SL_CWD_B_ROOT="$WORK/cwd-b/root"
SL_CWD_B_DECOY="$WORK/cwd-b/decoy"
mkdir -p "$SL_CWD_B_ROOT" "$SL_CWD_B_DECOY"
sl_world_root "$SL_CWD_B_ROOT"
sl_gm_series "$SL_CWD_B_DECOY/_bmad-output/implementation-artifacts/gate-metrics.jsonl" 1

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
SL_CWD_A_ROOT="$SL_CWD_A_ROOT"
SL_CWD_A_DECOY="$SL_CWD_A_DECOY"
SL_CWD_B_ROOT="$SL_CWD_B_ROOT"
SL_CWD_B_DECOY="$SL_CWD_B_DECOY"
EOF

printf '%s\n' "$WORK"
