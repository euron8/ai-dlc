#!/usr/bin/env bash
# audit-anchors-schema/run.sh — prove the audit-anchors housekeeping schema is single-source and
# enforced: the header is RENDERED from schemas/audit-anchors.json, --check catches header drift,
# validate catches entry shape drift, and the reader fails CLOSED on an unreadable schema.
#
# THE DEFECT THIS EXISTS TO CATCH. The schema lived in two places — templates/audit-anchors.md.template
# (never shipped) and each project's live audit-anchors.md header (hand-carried) — with nothing
# comparing them. They diverged, and the de-facto schema survived only in whichever file was carried
# forward. Fresh installs would have seeded the stale shape. This proves the second copy is gone.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "audit-anchors-schema:"

# --- Assertion 0: SANITY — render is non-empty and deterministic -------------
R1="$(bash "$VALIDATOR" --render)"; R2="$(bash "$VALIDATOR" --render)"
[ -n "$R1" ] && [ "$R1" = "$R2" ] && ok "--render is non-empty and deterministic" \
  || bad "--render is empty or non-deterministic — the schema render is the source of truth"

# --- Assertion 1: rendered header + valid entries → validate PASS ------------
GOOD="$WORK/good.md"
{ bash "$VALIDATOR" --render; cat <<'EOF'

## Entries

```yaml
- sprint: 167
  sha: 6e8d254f9edefc2a180d9a9d6d95d27c1a2b064c
  closed_at: 2026-04-24T18:39:00Z
  audit_window: <pre-S167-baseline>..6e8d254f
- sprint: 168
  sha: PENDING
  closed_at: PENDING
```
EOF
} > "$GOOD"
if bash "$VALIDATOR" "$GOOD"; then ok "rendered header + well-formed entries → validate PASS" \
  ; else bad "a valid audit-anchors file was rejected"; fi

# --- Assertion 2: header hand-edited → --check FAIL --------------------------
DRIFT="$WORK/drift.md"
sed 's/integer sprint number\. REQUIRED\./integer sprint number./' "$GOOD" > "$DRIFT"
if ! cmp -s "$GOOD" "$DRIFT"; then
  bash "$VALIDATOR" --check "$DRIFT" 2>/dev/null && bad "a hand-edited header passed --check (drift undetected)" \
    || ok "a hand-edited header region → --check FAIL (drift caught)"
else
  bad "FIXTURE STALE: the header edit changed nothing"
fi

# --- Assertion 3: missing header region → --check FAIL ----------------------
NOHDR="$WORK/nohdr.md"
printf '# Audit Anchors\n\n## Entries\n\n- sprint: 1\n  sha: PENDING\n' > "$NOHDR"
bash "$VALIDATOR" --check "$NOHDR" 2>/dev/null && bad "a file with no GENERATED header passed --check" \
  || ok "no GENERATED header region → --check FAIL"

# --- Assertion 4: entry missing a REQUIRED field (sha) → validate FAIL -------
MISS="$WORK/missing-sha.md"
{ bash "$VALIDATOR" --render; printf '\n## Entries\n\n```yaml\n- sprint: 42\n  closed_at: PENDING\n```\n'; } > "$MISS"
bash "$VALIDATOR" "$MISS" 2>/dev/null && bad "an entry missing the required 'sha' passed validate" \
  || ok "entry missing required 'sha' → validate FAIL (fail-closed on shape)"

# --- Assertion 5a: non-integer sprint → validate FAIL (structural) ----------
BADSPRINT="$WORK/bad-sprint.md"
{ bash "$VALIDATOR" --render; printf '\n## Entries\n\n```yaml\n- sprint: forty-two\n  sha: PENDING\n```\n'; } > "$BADSPRINT"
bash "$VALIDATOR" "$BADSPRINT" 2>/dev/null && bad "an entry with a non-integer sprint passed validate" \
  || ok "entry with non-integer 'sprint' → validate FAIL"

# --- Assertion 5b: a real sha with an inline YAML '# comment' → PASS ---------
# Real consumer files carry backfill notes after the value; the parser must strip the comment.
COMMENTED="$WORK/commented.md"
{ bash "$VALIDATOR" --render; printf '\n## Entries\n\n```yaml\n- sprint: 285\n  sha: ad6ecefb72f264771250371541e9f41e3a4a6272 # backfilled on main after retro PR merge\n```\n'; } > "$COMMENTED"
bash "$VALIDATOR" "$COMMENTED" >/dev/null 2>&1 && ok "a sha with an inline '# comment' → validate PASS (comment stripped)" \
  || bad "a real sha with a trailing '# comment' was rejected — the parser did not strip the comment"

# --- Assertion 6b: MIGRATION-SAFE — --entries passes a file with valid entries but no header ---
# A consumer file predating this schema has no GENERATED region. --entries (Check 18) must NOT
# wedge it, while full validate + --check (producer side) still require the header.
MIG="$WORK/pre-schema.md"
printf '# Audit Anchors\n\n## Entries\n\n```yaml\n- sprint: 200\n  sha: 6e8d254f9edefc2a180d9a9d6d95d27c1a2b064c\n  closed_at: 2026-04-24T18:39:00Z\n```\n' > "$MIG"
if bash "$VALIDATOR" --entries "$MIG" 2>/dev/null; then
  bash "$VALIDATOR" "$MIG" 2>/dev/null && bad "full validate passed a headerless file (should require the region)" \
    || ok "--entries passes a headerless (pre-schema) file while full validate still fails — migration-safe"
else
  bad "--entries wedged a pre-schema file with valid entries — Check 18 would fail-closed on a not-yet-migrated consumer"
fi

# --- Assertion 6: unreadable/malformed schema → fail CLOSED -----------------
AI_DLC_AUDIT_ANCHORS_SCHEMA="$BAD_SCHEMA" bash "$VALIDATOR" --render >/dev/null 2>&1 \
  && bad "a malformed schema still rendered — the reader degraded instead of failing closed" \
  || ok "malformed schema → exit 1 (fail-closed, never degrades to no-schema)"

echo
if [ "$fails" -eq 0 ]; then echo "audit-anchors-schema: PASS"; exit 0; fi
echo "audit-anchors-schema: $fails assertion(s) FAILED" >&2
exit 1
