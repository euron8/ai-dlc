#!/usr/bin/env bash
# layer-readopt-gate — assert the v0.52.0 landing machinery can actually LAND.
#
# Three properties, each of which fails RED against a real defect that shipped:
#
#   A. `readopt-override.sh --check` catches an override whose body still carries
#      core text upstream has SUPERSEDED. Un-caught, the core fix lands on disk and
#      the lead goes on obeying the old rule out of the override.
#   B. A bare re-stamp is REFUSED while the body is stale. Drift is computed
#      base_sha..theirs, so re-stamping ALONE makes the HARD status evaporate with
#      nothing migrated -- "proceed by doing nothing" wearing a stamp. This is the
#      single most important assertion in the file.
#   C. `unregistered-drift.sh` tells an in-place core rewrite apart from install.sh's
#      template substitution. Getting that wrong in EITHER direction is fatal: miss
#      the rewrite and `apply` silently deletes it; flag the substitution and the
#      check fires on 13 of 13 files on first contact and gets turned off. (It did,
#      in development -- a `$(...)` capture ate the trailing newline and every file
#      read as drift.)
#
# Usage: run.sh [readopt-override.sh] [unregistered-drift.sh]
# Exit:  0 = every assertion holds, 1 = a gate regressed.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
READOPT="$(pick "${1:-}" \
  "$HERE/../../skills/ai-dlc-update/reconcile/readopt-override.sh" \
  "$HERE/../../../core/skills/ai-dlc-update/reconcile/readopt-override.sh" \
  "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/readopt-override.sh")"
UNREG="$(pick "${2:-}" \
  "$HERE/../../skills/ai-dlc-update/reconcile/unregistered-drift.sh" \
  "$HERE/../../../core/skills/ai-dlc-update/reconcile/unregistered-drift.sh" \
  "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/unregistered-drift.sh")"

[ -n "$READOPT" ] || { echo "FIXTURE ERROR: cannot locate readopt-override.sh" >&2; exit 2; }
[ -n "$UNREG" ]   || { echo "FIXTURE ERROR: cannot locate unregistered-drift.sh" >&2; exit 2; }

ROOT="$(bash "$HERE/seed.sh")"
DIST="$ROOT/dist"; CONS="$ROOT/consumer"
OVR="$CONS/.claude/skills/ai-dlc/overrides/SKILL__Rule-8.md"
BASE="$(git -C "$DIST" rev-parse --short HEAD~1)"
THEIRS="$(git -C "$DIST" rev-parse --short HEAD)"

fails=0
ok()   { printf '  ok    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "== A. the stale-core-text gate fires on the real shape =="

out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --check 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'STALE-CORE-TEXT'; then
  ok "--check RED: override body carries core text theirs no longer has"
else
  bad "--check did NOT fire on an override copying a superseded core clause (rc=$rc)"
  printf '%s\n' "$out" | sed 's/^/        /'
fi

# The gate must name the actual superseded sentence, not merely exit 1.
if printf '%s' "$out" | grep -q 'more CRITICALs than pass N'; then
  ok "--check names the superseded clause verbatim"
else
  bad "--check fired but did not identify the stale line"
fi

echo "== B. a bare re-stamp is REFUSED while the body is stale =="

before_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$OVR" | head -1)"
out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --stamp readopt 2>&1)"; rc=$?
after_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$OVR" | head -1)"

if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'REFUSED'; then
  ok "--stamp readopt REFUSED while superseded text remains"
else
  bad "--stamp readopt SUCCEEDED on a stale body -- the block can be cleared by doing nothing (rc=$rc)"
fi
if [ "$before_sha" = "$after_sha" ]; then
  ok "base_sha untouched by the refused stamp ($before_sha)"
else
  bad "REFUSED stamp still rewrote base_sha ($before_sha -> $after_sha)"
fi

echo "== B2. reaffirm without a note is REFUSED =="
out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --stamp reaffirm 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'REQUIRES --note'; then
  ok "--stamp reaffirm demands a recorded reason"
else
  bad "--stamp reaffirm accepted with no note -- an unrecorded decision (rc=$rc)"
fi

echo "== C. the gate GOES GREEN once the body is genuinely re-adopted =="

# Re-adopt: carry theirs' clause into the override, keep the consumer's delta.
cat > "$OVR" <<EOF
---
shadows: SKILL.md#Rule 8
base_sha: ${BASE}
reason: consumer-specific validation-intensity table keyed to this repo's service paths.
---

## Rule 8 -- Validation Depth

Validation intensity by path: service/ and infra/ are FULL; scripts/ and docs/ are LIGHT.

**Divergence is a HARD_BLOCK, not a reason for another pass.** If pass N+1
reports more CRITICALs IN THE SCOPE THE PRIOR PASS ALSO REVIEWED
(\`findings_critical_prior_scope\`) than pass N reported in total, the repair step
is injecting defects. CRITICALs in scope the sprint ADDED are NOT divergence.
EOF

out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --check 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then ok "--check green after a real re-adoption"
else bad "--check still red after the body was re-adopted (rc=$rc)"; printf '%s\n' "$out" | sed 's/^/        /'; fi

out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --stamp readopt 2>&1)"; rc=$?
new_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$OVR" | head -1)"
if [ "$rc" -eq 0 ] && [ "$new_sha" = "$THEIRS" ]; then
  ok "--stamp readopt re-stamped base_sha $BASE -> $THEIRS"
else
  bad "--stamp readopt did not re-stamp (rc=$rc, base_sha=$new_sha, want $THEIRS)"
fi

# And the consumer's own delta must have SURVIVED the re-adoption.
if grep -q 'validation-intensity\|Validation intensity' "$OVR"; then
  ok "the consumer's delta survived re-adoption"
else
  bad "re-adoption destroyed the consumer's delta"
fi

echo "== C2. an UNRESOLVABLE anchor fails CLOSED (the vacuous-check hole) =="

# If `shadows:` names an anchor that resolves to no heading, the stale-text test
# compares two EMPTY sections, finds nothing, and reports the body clean. That is a
# check that cannot fail -- gating the very re-stamp it exists to withhold. It must
# refuse, not pass. (Found live: the anchor "Empirical gate validation (the
# `Enforcement:` paragraph)" resolves under layer-drift's matcher but not under a
# naive one, so the gate blocked and its remedy silently cleared the block.)
GHOST="$CONS/.claude/skills/ai-dlc/overrides/SKILL__Ghost.md"
cat > "$GHOST" <<EOF
---
shadows: SKILL.md#Rule 404 -- Does Not Exist
base_sha: ${BASE}
reason: anchor names no heading in core.
---
Body that copies nothing and can be proven safe by nobody.
EOF

out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$GHOST" --check 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'UNDECIDABLE'; then
  ok "--check on an unresolvable anchor: UNDECIDABLE, not 'clean'"
else
  bad "--check reported an unresolvable anchor as clean (rc=$rc) -- a check that cannot fail"
fi

out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$GHOST" --stamp readopt 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'REFUSED'; then
  ok "--stamp readopt REFUSED on an unresolvable anchor"
else
  bad "--stamp readopt cleared a HARD block via a vacuous test (rc=$rc)"
fi

# reaffirm --note is the sanctioned way past it: a human puts their name on it.
out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$GHOST" --stamp reaffirm --note "anchor is legacy; override still stands" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then ok "--stamp reaffirm --note is the recorded way past an undecidable anchor"
else bad "reaffirm --note could not clear an undecidable anchor (rc=$rc) -- no path out means the gate gets routed around"; fi

rm -f "$GHOST"

echo "== D. unregistered drift vs sanctioned template substitution =="

tsv="$(bash "$UNREG" "$DIST" "$BASE" "$CONS" 2>&1)"

st() { printf '%s\n' "$tsv" | awk -F'\t' -v f="$1" '$2==f {print $1}'; }

if [ "$(st team-roles/tea.md)" = "HARD-UNREGISTERED-CORE-DRIFT" ]; then
  ok "in-place core rewrite (tea.md) -> HARD-UNREGISTERED-CORE-DRIFT"
else
  bad "in-place core rewrite NOT flagged (got '$(st team-roles/tea.md)') -- apply would silently delete it"
fi

if [ "$(st team-roles/dev.md)" = "CORE-TEMPLATE-SUBSTITUTED" ]; then
  ok "install.sh token substitution (dev.md) -> CORE-TEMPLATE-SUBSTITUTED, not drift"
else
  bad "template substitution misread as '$(st team-roles/dev.md)' -- this is the false positive that gets the check turned off"
fi

if [ "$(st skills/ai-dlc/SKILL.md)" = "CORE-OK" ]; then
  ok "untouched core file -> CORE-OK"
else
  bad "untouched core file reported '$(st skills/ai-dlc/SKILL.md)' -- trailing-newline regression is back"
fi

rm -rf "$ROOT"
echo ""
if [ "$fails" -eq 0 ]; then echo "layer-readopt-gate: PASS"; exit 0; fi
echo "layer-readopt-gate: FAIL ($fails)"; exit 1
