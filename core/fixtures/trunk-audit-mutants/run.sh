#!/usr/bin/env bash
# trunk-audit-mutants — the mutation battery behind `trunk-audit-classes`. DISTRIBUTION-ONLY.
#
# Usage: run.sh
# Exit:  0 = every mutant moves exactly its own assertions, 1 = one did not, 2 = fixture broken.
#
# WHY THIS IS SPLIT OUT, and it is a measurement rather than a preference. Held together with
# its assertions the fixture cost 21.6s and BECAME THE REFERENCE CONSUMER'S POLE: that suite's
# wall clock went 32.83s -> 42.31s, +28.9%, with the new unit at 0.02s slack. In this
# repository the same fixture had 112.93s of slack against a 162.9s pole and every reading
# said it was free. That is v0.230.0's finding exactly — what a fixture COSTS is a property of
# the suite it runs in, and measuring only where it is free is how the last one shipped.
#
# WHY THE BATTERY IS THE HALF THAT MOVES, stated as a principle rather than as convenience.
# It mutates `validate-cycle-commits.sh`, which is CORE's: `ai-dlc-core-guard.sh` denies a
# consumer the in-place edit, so the surface these mutants perturb cannot change in a consumer
# tree. Proving the assertions can fail is a question about a file only this repository edits.
# The consumer keeps every CORRECTNESS arm — all 22 of them, including both controls — and
# what it loses is a proof about something it is forbidden to alter.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

# The subject fixture is the SIBLING, resolved inside core/fixtures/ and never by walking up
# into a core subtree.
SUBJ="$HERE/../trunk-audit-classes/run.sh"
[ -f "$SUBJ" ] || { echo "FIXTURE ERROR: sibling trunk-audit-classes/run.sh not found" >&2; exit 2; }
if [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-cycle-commits.sh" ]; then
  VAL="$ROOT/core/scripts/validate-cycle-commits.sh"
else
  echo "FIXTURE ERROR: validate-cycle-commits.sh not found — this fixture is distribution-only" >&2; exit 2
fi

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
MUT="$WORK/mutants"; mkdir -p "$MUT"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

mut_reds() {
  local label="$1" prog="$2" copy="$MUT/$1.sh"
  if [ -z "$prog" ]; then cp "$VAL" "$copy"; else
    sed "$prog" "$VAL" > "$copy" 2>/dev/null
    if cmp -s "$VAL" "$copy"; then printf 'UNMUTATED\n'; return 0; fi
  fi
  AI_DLC_TAC_VALIDATOR="$copy" bash "$SUBJ" 2>/dev/null | grep '^  FAIL  ' | sed 's/^  FAIL  //'
}
expect_set() { # $1 label, $2 expected count, $3 ERE every red must match, $4 sed
  local reds n unmatched
  reds="$(mut_reds "$1" "$4")"
  if [ "$reds" = "UNMUTATED" ]; then
    bad "MUTANT $1: the sed matched nothing — no mutation was applied, so nothing was proven"
    return
  fi
  n="$(grep -c . <<<"$reds" || true)"
  unmatched="$(grep -vE "$3" <<<"$reds" | grep -c . || true)"
  if [ "$n" -eq "$2" ] && [ "$unmatched" -eq 0 ]; then
    ok "MUTANT $1 moves exactly the $2 assertion(s) it should, and no others"
  else
    bad "MUTANT $1: expected $2 red(s) matching '$3', got ${n} (${unmatched} unexpected): $(tr '\n' ';' <<<"$reds")"
  fi
}

ctl="$(mut_reds control "")"
[ -z "$ctl" ] && ok "CONTROL: an unmutated copy of the script passes every assertion" \
              || bad "CONTROL: an unmutated copy FAILED ($(tr '\n' ';' <<<"$ctl")) — every kill below is unearned"

# M1 — an unresolved class becomes a skip. Fail-closed becomes fail-open, which is the
# whole mechanism: the commits it cannot classify are the ones it exists to surface.
expect_set unresolved-skipped 2 'unresolvable commit was skipped|unresolved class exited' \
  's@^    if \[ -z "\$_ci" \]; then@    if [ -z "$_ci" ] \&\& false; then@'

# M2 — the validator's exit code stops deciding anything. The re-run still happens and its
# answer is discarded, which is the log-trusting shape this mode replaced.
expect_set exit-code-ignored 4 'bypassed merge was NOT reported|does not name the validator|finding exited|watermark advanced past a finding' \
  's@^        if ! _out="\$( cd "\$_wt" \&\& eval "\$_cmd" 2>\&1 )"; then@        if _out="$( cd "$_wt" \&\& eval "$_cmd" 2>\&1 )" \&\& false; then@'

# M3 — a declared validator missing from the audited tree is no longer NAMED as absent.
# ONE red, not two, and the reason is worth stating: `eval` on a path that is not there
# exits non-zero anyway, so the VERDICT is unchanged and only the DIAGNOSIS moves. Without
# this arm the report says the commit "reached the trunk without satisfying its class" when
# what actually happened is that the obligation was never evaluated — a confident wrong
# answer, which is worse than the opaque one it replaces.
expect_set absent-validator-ok 1 'absent validator passed silently' \
  's@^            if \[ ! -f "\$_wt/\$_bin" \]; then@            if [ ! -f "$_wt/$_bin" ] \&\& false; then@'

# M4 — the undeclared-taxonomy worklist stops being clean and starts wedging the trunk. The
# sed mutates the EXIT after that message and not the message, so the two assertions stay
# separable: a mutant that suppressed the line too would fail both and prove neither.
expect_set worklist-becomes-error 1 'unscaffolded taxonomy exited' \
  '/no PR-class taxonomy has been scaffolded/{n; s@    exit 0@    exit 1@;}'

# M5 — the empty-range zero loses its control. The reading is unchanged and it stops being
# evidence, which is the exact defect a bare zero always is here.
expect_set empty-range-bare-zero 1 'bare zero' \
  's@ (empty; control: the trunk holds @ (empty; the trunk holds @'

# M6 — the `none` literal stops being recognised, so a declared-empty taxonomy is reported
# as malformed and a compliant consumer is punished for having answered.
expect_set none-not-honoured 1 "explicit 'none' was not honoured" \
  's@^  if \[ "\$A_BLOCK" = "none" \]; then@  if [ "$A_BLOCK" = "NONEXX" ]; then@'

# M7 — a class with no validator is accepted. "Owes nothing" and "nobody said" collapse.
expect_set no-validator-accepted 2 'owing nothing by omission was accepted|did not say that nothing was audited' \
  's@^    if \[ ! -s "\$A_TMP/c\$_i.val" \]; then@    if [ ! -s "$A_TMP/c$_i.val" ] \&\& false; then@'

# M8 and M9 exist because M2 moves FOUR cells. That is a fan-out rather than an
# entanglement — detection, attribution, exit code and watermark are four different facts
# about one arm — but three of them would then be proven only by the mutant that removes the
# arm entirely, and a cell proven only by a total knock-out is a cell that can rot in place.
#
# M8 — the finding still fires and stops naming which validator rejected the tree.
expect_set finding-unattributed 1 'does not name the validator' \
  "s@_why=\"\\\${_why} '\\\$_cmd' exits non-zero@_why=\"\${_why} 'a validator' exits non-zero@"

# M9 — the watermark advances past a finding, so the next run starts after the commit that
# failed and the finding is never seen again. Detection is untouched; only recurrence moves.
expect_set watermark-advances-past-finding 1 'watermark advanced past a finding' \
  's@^      echo "  FAIL    \${_sha} (\${_class}):\${_why}"@      A_LAST_CLEAN="$_sha"; echo "  FAIL    ${_sha} (${_class}):${_why}"@'

if [ "$fails" -eq 0 ]; then echo "PASS trunk-audit-mutants"; exit 0; fi
echo "FAIL trunk-audit-mutants ($fails)"; exit 1
