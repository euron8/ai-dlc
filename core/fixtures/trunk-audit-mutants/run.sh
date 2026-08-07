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

# EVERY MUTANT RUN IS INDEPENDENT, SO THEY GO THROUGH A POOL, and the reason is the suite's
# critical path rather than this fixture in isolation. Each `expect_set` below builds one copy
# of the validator and drives the SIBLING fixture against it; the nineteen runs share nothing,
# and run end to end they cost 67s standalone and ~198s inside the 16-way pre-push suite. That
# suite is POLE-BOUND — its makespan tracks its longest single unit, measured 268s against a
# 268s wall clock — so an internally-serial fixture sets the wall clock for the whole push no
# matter what AI_DLC_FIXTURE_JOBS is.
#
# The file is therefore in three phases, and the middle section is deliberately UNCHANGED from
# the serial version: `expect_set` now REGISTERS a run instead of performing it, the call sites
# and their reasoning are byte-for-byte what they were, and a third phase evaluates them in
# declaration order. Rendering from the registry rather than from completion order is what
# keeps this fixture's stdout byte-comparable against the serial version it replaces.

RUNS="$WORK/runs"; : > "$RUNS"
OUTD="$WORK/out"; mkdir -p "$OUTD"

# expect_set <label> <expected count> <ERE every red must match> <sed>
#
# The sed program goes to a FILE rather than into the registry. These programs carry tabs,
# backslashes and both quote characters — M18's is a bracket class whose whole subject is a
# backslash-t — and a registry that stored them inline would have to survive one round of
# field-splitting each. A program that arrived at the worker subtly re-quoted would still
# apply, still satisfy `cmp -s`, and prove something other than what its call site says.
expect_set() {
  printf '%s' "$4" > "$MUT/$1.sed"
  printf '%s\t%s\t%s\n' "$1" "$2" "$3" >> "$RUNS"
}

# The control is registered like any other run and REPORTED first. Its own arm is what
# licenses every kill below, so an empty sed program is the whole of its mutation: the worker
# copies the validator untouched.
expect_set control "" ""  ""

# M1 — an unresolved class becomes a skip. Fail-closed becomes fail-open, which is the
# whole mechanism: the commits it cannot classify are the ones it exists to surface.
expect_set unresolved-skipped 2 'unresolvable commit was skipped|unresolved class exited' \
  's@^    if \[ -z "\$_ci" \]; then@    if [ -z "$_ci" ] \&\& false; then@'

# M2 — the validator's exit code stops deciding anything. The re-run still happens and its
# answer is discarded, which is the log-trusting shape this mode replaced.
# FIVE since v0.236.0, not four, and the fifth is re-derived rather than inherited: the
# capture pair's second half (11b) turns a captured value into a validator REJECTION, so an
# exit code that decides nothing takes that cell too. Same arm, one more fact about it.
expect_set exit-code-ignored 5 'bypassed merge was NOT reported|does not name the validator|finding exited|watermark advanced past a finding|capture did not vary with the commit' \
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

# ============================================================================
# M10-M18 — the CAPTURE arms, v0.236.0.
# ============================================================================

# M10 — substitution stops happening. The command still runs and the validator receives the
# literal `{sprint}`, which is the failure this grammar's whole declaration-time join exists
# to make impossible; here it is induced directly to prove the assertions can see it.
expect_set capture-not-substituted 2 "capture did not reach the validator|capture did not vary with the commit" \
  's@^        _cmd="\${_cmd//"{\$_sn}"/\$_sv}"@        _cmd="$_cmd"@'

# M11 — a capture matching nothing becomes a skip. Fail-closed becomes fail-open one level
# below the class: the class resolved, its obligation could not be built, and the audit says
# nothing. Same defect as M1, reached through the capture rather than through the class.
expect_set capture-zero-match-skipped 1 'unresolvable capture was skipped' \
  's@^      if \[ "\$_cnum" -eq 0 \]; then@      if [ "$_cnum" -eq 0 ] \&\& false; then@'

# M12 — an ambiguous capture silently takes the first value. TWO reds and they are a fan-out,
# not an entanglement: that it reported at all, and that the report names both candidates.
expect_set capture-ambiguity-guessed 2 'ambiguous capture did not report|ambiguity finding does not name the values' \
  's@^      elif \[ "\$_cnum" -gt 1 \]; then@      elif [ "$_cnum" -gt 1 ] \&\& false; then@'

# M13 — the safe-charset guard goes. The value is substituted into a command that is then
# `eval`ed, so this is the arm between a consumer's `(.*)` and arbitrary execution driven by
# a path in their own repository.
expect_set capture-unsafe-value-allowed 1 'unsafe capture value was substituted' \
  's@^          \*\[!A-Za-z0-9._-\]\*)@          *[!A-Za-z0-9._-Z]*)@'

# M14 — the {name}-to-capture join goes. This is the arm that makes the runtime "unsubstituted
# brace" check unnecessary; without it a typo'd {nosuch} ships and is discovered by whichever
# future commit first resolves to that class, which may be never.
expect_set capture-unbound-ref-accepted 1 'no capture behind it is a declaration error' \
  "s@^      decl_err \"class '\\\$_nm' has a validator: naming@      : \"class '\$_nm' has a validator: naming@"

# M15 — the anchor requirement goes, so an unanchored regex is ACCEPTED and extracts the
# path's unmatched remainder along with the value. The verdict still moves, which is the
# point: the value is silently wrong rather than absent.
#
# THE FIRST CUT OF THIS MUTANT SCORED TEN REDS AND WOULD HAVE PASSED AS A KILL. It replaced
# the anchored case PATTERN with a token nothing matches, which refuses every capture in the
# fixture rather than accepting the one unanchored one — proving that captures can be turned
# off, which no assertion here is about. Widening the arm to `|*)` is the mutation that
# isolates the cell. A mutant must fail ONLY its own assertion; ten failures meant the
# mutation was the wrong shape, not that the arms were entangled.
expect_set capture-unanchored-accepted 1 'UNANCHORED capture regex is refused' \
  "s@^              '\^'\*'\\\$') ;;@              '^'*'\$'|*) ;;@"

# M16 — the capturing-group requirement goes, same shape and for the same reason as M15.
expect_set capture-no-group-accepted 1 'NO capturing group is refused' \
  "s@^              \*'('\*) ;;@              *'('*|*) ;;@"

# M17 — a duplicate capture name is accepted, so the second regex is unreachable and the
# first silently wins. The same defect the duplicate-CLASS arm guards, one grain down.
expect_set capture-duplicate-name-accepted 1 'declared twice in one class is refused' \
  's@^            if grep -qE "\^\${_cnm} " "\$A_TMP/c\$A_N.cap" 2>/dev/null; then@            if false; then@'

# M18 — the sed bracket class goes back to the pre-v0.236.0 form. This is not a hypothetical:
# it is the defect as it actually shipped, and the mutant is how the fixture proves the fix
# is what changed rather than something else in the same release. In a POSIX bracket
# expression `[ \t]` is SPACE, BACKSLASH and `t`, so `capture: sprint` is truncated to
# `capture: sprin` and the parser reports a declaration nobody wrote.
# The replacement doubles the backslash because sed processes `\t` in the REPLACEMENT as a
# tab. The first cut emitted a real tab, which is a CORRECT bracket class -- so the mutant
# applied cleanly, `cmp -s` was satisfied, nothing was truncated, and it reported zero reds.
# A mutation that lands and does not mutate the behaviour is the shape `cmp -s` cannot catch.
expect_set decl-line-trailing-t-eaten 1 'name-only capture was misreported' \
  "s@| sed 's/\^\[\[:space:\]\]\*//; s/\[\[:space:\]\]\*\\\$//'@| sed 's/^[ \\\\t]*//; s/[ \\\\t]*\$//'@"

# ==================== PHASE 2: build and drive every mutant, in a pool ====================
# The zero guard is this fixture's own subject one level out: a registration grammar that
# stopped filling yields an empty list, and an empty list passes every assertion it never made.
N_RUNS="$(grep -c . "$RUNS" || true)"
if [ "$N_RUNS" -lt 10 ]; then
  echo "FIXTURE ERROR: registered only $N_RUNS mutant run(s) — the registry did not fill, so nothing below is evidence" >&2
  exit 2
fi

# EIGHT, AND FIXED RATHER THAN TUNABLE — the same number and the same reasoning the sibling
# pools state in place: this pool nests inside the pre-push suite's own, so a knob here
# multiplies against the knob there and the PRODUCT is what lands on the machine.
#
# The `cmp -s` guard stays INSIDE the worker, where the copy is made. It is the guard that
# stops a sed which matched nothing from scoring as a kill, and moving it to the parent would
# put it on the wrong side of the thing it checks.
TAM_JOBS=8
TAM_VAL="$VAL" TAM_SUBJ="$SUBJ" TAM_MUT="$MUT" TAM_OUT="$OUTD" \
  xargs -P "$TAM_JOBS" -I{} bash -c '
    l="$1"; copy="$TAM_MUT/$l.sh"; prog="$TAM_MUT/$l.sed"
    if [ -s "$prog" ]; then
      sed -f "$prog" "$TAM_VAL" > "$copy" 2>/dev/null
      if cmp -s "$TAM_VAL" "$copy"; then
        printf UNMUTATED > "$TAM_OUT/$l.state"
        printf done      > "$TAM_OUT/$l.done"
        exit 0
      fi
    else
      cp "$TAM_VAL" "$copy"
    fi
    AI_DLC_TAC_VALIDATOR="$copy" bash "$TAM_SUBJ" 2>/dev/null \
      | grep "^  FAIL  " | sed "s/^  FAIL  //" > "$TAM_OUT/$l.reds"
    printf done > "$TAM_OUT/$l.done"
  ' _ {} < <(cut -f1 "$RUNS")

# ================= PHASE 3: evaluate, serially, in DECLARATION order =================
while IFS=$'\t' read -r label want ere; do
  [ -n "$label" ] || continue

  # A MISSING VERDICT IS A FAILURE, not a gap. `.done` is written after the run, so its
  # absence means the pool dropped the job — which otherwise contributes exactly what a
  # passing mutant contributes: nothing.
  if [ ! -f "$OUTD/$label.done" ]; then
    bad "MUTANT $label produced no verdict — the pool dropped work, and a short green run reads exactly like a passing one"
    continue
  fi

  if [ -f "$OUTD/$label.state" ]; then
    bad "MUTANT $label: the sed matched nothing — no mutation was applied, so nothing was proven"
    continue
  fi

  reds="$(cat "$OUTD/$label.reds" 2>/dev/null)"

  if [ "$label" = control ]; then
    [ -z "$reds" ] && ok "CONTROL: an unmutated copy of the script passes every assertion" \
                   || bad "CONTROL: an unmutated copy FAILED ($(tr '\n' ';' <<<"$reds")) — every kill below is unearned"
    continue
  fi

  n="$(grep -c . <<<"$reds" || true)"
  unmatched="$(grep -vE "$ere" <<<"$reds" | grep -c . || true)"
  if [ "$n" -eq "$want" ] && [ "$unmatched" -eq 0 ]; then
    ok "MUTANT $label moves exactly the $want assertion(s) it should, and no others"
  else
    bad "MUTANT $label: expected $want red(s) matching '$ere', got ${n} (${unmatched} unexpected): $(tr '\n' ';' <<<"$reds")"
  fi
done < "$RUNS"

if [ "$fails" -eq 0 ]; then echo "PASS trunk-audit-mutants"; exit 0; fi
echo "FAIL trunk-audit-mutants ($fails)"; exit 1
