#!/usr/bin/env bash
# layer-catalog-collision — assert the layer detectors tell the four catalog states
# apart, and that the title matcher is tight enough to be trusted as a join key.
#
# Usage: run.sh [path-to-validate-layer-entries.sh] [path-to-layer-drift.sh]
# Exit:  0 = every assertion holds, 1 = a detector regressed.
#
# NOTE ON PART 2. The obvious way to test the false-absorption regression — seed an
# extension-only check whose title merely overlaps a core check, and assert the linter
# stays quiet — is VACUOUS. `validate-layer-entries.sh` only consults the title for a
# number core ALSO defines, so an extension-only number never reaches the matcher and
# the assertion passes no matter how loose the matcher is (verified: it passes against
# the old 2-shared-token rule). The dangerous path is the CROSS-NUMBER title search in
# `layer-drift.sh`, which compares a title against EVERY upstream anchor. So Part 2
# tests the matching predicates themselves, directly. A fixture that cannot fail is
# not a fixture.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
LINTER="$(pick "${1:-}" "$HERE/../../../scripts/validate-layer-entries.sh" \
                        "$HERE/../../scripts/validate-layer-entries.sh" \
                        "$HERE/../../../core/scripts/validate-layer-entries.sh")"
DRIFT="$(pick "${2:-}" "$HERE/../../../core/skills/ai-dlc-update/reconcile/layer-drift.sh" \
                       "$HERE/../../skills/ai-dlc-update/reconcile/layer-drift.sh" \
                       "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/layer-drift.sh")"
[ -n "$LINTER" ] || { echo "FIXTURE ERROR: cannot locate validate-layer-entries.sh" >&2; exit 2; }

ROOT="$(bash "$HERE/seed.sh")"
trap 'rm -rf "$ROOT"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "layer-catalog-collision:"

# --- Part 1: the linter classifies the same-number states ---------------------
out="$(bash "$LINTER" "$ROOT" 2>&1)"

printf '%s' "$out" | grep -q "NUMBER COLLISION on '24\.'" \
  && ok "24 = COLLISION (core: adversarial convergence / ext: financial-display)" \
  || bad "24 not reported as a collision — a bare 'Check 24' in the gate log has no referent"

printf '%s' "$out" | grep -q "^ERROR.*COLLISION on '24\.'" \
  && ok "the collision is an ERROR, not a warning (it reaches the durable audit record)" \
  || bad "the collision is only a warning — a warning nobody reads is how this survived"

printf '%s' "$out" | grep -q "RESTATES core section '5\.'" \
  && ok "5 = RESTATEMENT (same number AND same title), not a collision" \
  || bad "5 misclassified — same number and same title is a restatement"

printf '%s' "$out" | grep -q "'7\.'" \
  && bad "core-only check 7 flagged — the detector is comparing the wrong sets" \
  || ok "core-only check 7 correctly silent"

# --- Part 2: the title predicates, tested directly -----------------------------
# Extract each matcher from its own file and exercise it. Both implement the same
# rule; both are load-bearing; both must agree.
TRAP_A='smoke test evidence deploy validate gate only'                                  # consumer check
TRAP_B='smoke test coverage for user facing changes implementation gates only'          # core check — DIFFERENT
ABS_A='cross story test strategy 3 deliverable presence sprint review gate only'        # consumer check 33
ABS_B='test strategy deliverable presence sprint review gate'                           # core check 21 — SAME check

extract() { # extract <file> <fn-name> — awk, not sed: BSD sed mis-parses the `{` in the address
  awk -v fn="$2" '$0 ~ "^" fn "\\(\\) \\{" {p=1} p {print} p && /^\}/ {exit}' "$1"
}
probe() { # probe <file> <fn-name> <a> <b> ; exit 0 = matched
  local f="$1" fn="$2" a="$3" b="$4"
  bash -c "
    $(extract "$f" "$fn")
    ${fn} \"\$1\" \"\$2\"
  " _ "$a" "$b" 2>/dev/null
}

for spec in "$LINTER|same_title|validate-layer-entries.sh" "$DRIFT|same_section|layer-drift.sh"; do
  f="${spec%%|*}"; rest="${spec#*|}"; fn="${rest%%|*}"; name="${rest##*|}"
  [ -n "$f" ] && [ -f "$f" ] || { bad "$name not found — cannot test its title matcher"; continue; }

  # SANITY FIRST. probe() reports "no match" for a function that failed to load, and
  # "no match" is what the near-miss assertion below WANTS — so a broken extraction
  # would score a false pass on the very regression this fixture exists to catch.
  # Identical titles must match; if they do not, the harness is broken, not the code.
  if ! probe "$f" "$fn" "$TRAP_A" "$TRAP_A"; then
    bad "$name/$fn: FIXTURE BROKEN — could not load the matcher (identical titles did not match). Every result below it would be a false pass."
    continue
  fi

  if probe "$f" "$fn" "$TRAP_A" "$TRAP_B"; then
    bad "$name/$fn: matched 'Smoke test evidence' to 'Smoke test coverage' on {smoke,test} — as a join key this proposes DELETING a live deploy-validate check"
  else
    ok "$name/$fn: rejects the {smoke,test} near-miss (a loose title match is worse than none)"
  fi

  if probe "$f" "$fn" "$ABS_A" "$ABS_B"; then
    ok "$name/$fn: matches the renumbered absorption (consumer 33 IS core 21)"
  else
    bad "$name/$fn: missed the renumbered absorption — a duplicate upstream already absorbed stays invisible, which is how two survived ~35 minor versions"
  fi
done

echo
if [ "$fails" -eq 0 ]; then echo "layer-catalog-collision: PASS"; exit 0; fi
echo "layer-catalog-collision: $fails assertion(s) FAILED" >&2
exit 1
