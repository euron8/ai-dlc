#!/usr/bin/env bash
# consumer-machinery-inventory — assert LC-M1/E18 and LC-M2/W10 fire, and only where they should.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE GOAL THIS SERVES. Charter goal 2 is "consumer machinery confined to one declared home
# core can police." Eight predicates asking core to INFER which consumer executables are
# ai-dlc were measured and all eight refuted, and that refutation is sound. This mechanism
# does not re-attempt it: the CONSUMER declares its inventory, and core checks the one thing
# that is then decidable — whether a path the consumer has itself called ai-dlc machinery
# lives inside the declared home.
#
# WHY EACH ARM IS LOAD-BEARING:
#   1. E18 fires on a declared path OUTSIDE the home. This is the segregation itself.
#   2. E18 fires on a declared path that does not EXIST. An inventory naming absent files is
#      a list nothing checks, which is the forgeability this contract exists to remove.
#   3. A correctly segregated inventory is SILENT. Without this the arm is a blanket ERROR
#      and the first consumer to migrate is wedged by its own compliance.
#   4. The literal `none` is SILENT. An empty inventory is a complete answer.
#   5. W10 fires when the inventory is missing or carries no block at all — because a project
#      with no machinery and a project that has never looked must not be indistinguishable.
#      That was the reference consumer's state for an entire program.
#   6. BOTH arms are silent on a tree whose contract predates the declaration. v0.228.0
#      recorded what happens otherwise: two apply fixtures went red because their synthetic
#      distributions predate the contract entirely.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

if [ -n "${AI_DLC_CMI_VALIDATOR:-}" ] && [ -f "${AI_DLC_CMI_VALIDATOR}" ]; then
  # The mutant battery re-executes this script with a mutated validator. Without reading the
  # override here every mutant would exercise the real one, report zero reds, and score a
  # survival — the defect retired-fixture-orphan produced first and caught by its control.
  VAL="${AI_DLC_CMI_VALIDATOR}"
elif [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-layer-entries.sh" ]; then
  VAL="$ROOT/core/scripts/validate-layer-entries.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/validate-layer-entries.sh" ]; then
  VAL="$ROOT/scripts/ai-dlc/validate-layer-entries.sh"
else
  echo "FIXTURE ERROR: validate-layer-entries.sh not found in either layout" >&2; exit 2
fi
# The contract and manifest this fixture copies into its synthetic consumers, resolved in
# BOTH layouts. install.sh splits what shares a parent in core/, so a fixture that knows only
# the distribution path dies with exit 2 on every consumer — which the suite reports as a
# FAIL, not as a skip. Found by rehearsing this release's pull against a real consumer clone
# rather than by reading the code.
if [ -n "$ROOT" ] && [ -d "$ROOT/core/skills/ai-dlc" ]; then
  SRC="$ROOT/core/skills/ai-dlc"
elif [ -n "$ROOT" ] && [ -d "$ROOT/.claude/skills/ai-dlc" ]; then
  SRC="$ROOT/.claude/skills/ai-dlc"
else
  echo "FIXTURE ERROR: the ai-dlc skill dir was not found in either layout" >&2; exit 2
fi

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# Build a minimal consumer: the skill dir with the contract and the manifest, a home, and an
# inventory whose contents each case supplies.
mk_consumer() { # $1 = dest, $2 = inventory body ("" = no inventory file at all)
  local d="$1" body="$2"
  mkdir -p "$d/.claude/skills/ai-dlc/extensions" "$d/.claude/skills/ai-dlc/overrides"
  cp "$SRC/layer-contract.yaml" "$d/.claude/skills/ai-dlc/layer-contract.yaml"
  cp "$SRC/core-manifest.md"    "$d/.claude/skills/ai-dlc/core-manifest.md"
  mkdir -p "$d/scripts/ai-dlc-local"
  if [ -n "$body" ]; then
    printf 'x\n```\n%s\n```\n' "$body" > "$d/.claude/skills/ai-dlc/machinery.md"
  fi
}
run_val() { bash "$VAL" "$1" 2>/dev/null; }

# ---- 1 + 2: a declared path outside the home, and a declared path that does not exist
C1="$WORK/c1"; mk_consumer "$C1" "scripts/audit-rule-exercise.sh
scripts/ai-dlc-local/does-not-exist.sh"
printf '#!/bin/sh\n' > "$C1/scripts/audit-rule-exercise.sh"       # exists, wrong place
out1="$(run_val "$C1")"

grep -qE '^ERROR +E18' <<<"$out1" && ok "E18 fires on the seeded inventory" \
                         || bad "E18 did not fire at all — neither arm is reachable"
grep -q 'audit-rule-exercise.sh.*does not live under' <<<"$out1" \
  && ok "E18 names the declared path that sits OUTSIDE the home (the segregation itself)" \
  || bad "E18 missed a declared path outside the home — goal 2's whole subject"
grep -q 'does-not-exist.sh.*no such file' <<<"$out1" \
  && ok "E18 names the declared path that does not exist (an inventory nothing checks)" \
  || bad "E18 missed a declared path that does not exist"
grep -q 'git mv' <<<"$out1" \
  && ok "the remedy names both ends of the move" \
  || bad "the remedy does not name a runnable move — an un-transcribable remedy"

# ---- 3: a correctly segregated inventory is SILENT.
# Without this the arm is a blanket ERROR and compliance itself wedges the consumer.
C2="$WORK/c2"; mk_consumer "$C2" "scripts/ai-dlc-local/audit-rule-exercise.sh"
printf '#!/bin/sh\n' > "$C2/scripts/ai-dlc-local/audit-rule-exercise.sh"
out2="$(run_val "$C2")"
grep -qE '^ERROR +E18' <<<"$out2" \
  && bad "E18 fired on a correctly segregated inventory — compliance wedges the consumer" \
  || ok "a correctly segregated inventory is silent"
grep -qE '^WARN +W10' <<<"$out2" \
  && bad "W10 fired on a declared, non-empty inventory" \
  || ok "W10 is silent once the inventory is declared"

# ---- 4: the literal `none` is a complete answer
C3="$WORK/c3"; mk_consumer "$C3" "none"
out3="$(run_val "$C3")"
grep -qE '^(ERROR +E18|WARN +W10)' <<<"$out3" \
  && bad "an explicit 'none' was reported — an empty inventory is a legitimate answer" \
  || ok "the literal 'none' is silent (an empty inventory is a complete answer)"

# ---- 5: missing inventory, and an inventory with no block, both reach W10
C4="$WORK/c4"; mk_consumer "$C4" ""            # no machinery.md at all
out4="$(run_val "$C4")"
grep -qE '^WARN +W10' <<<"$out4" \
  && ok "W10 fires when the inventory has never been scaffolded" \
  || bad "an unscaffolded inventory is SILENT — a project with none and one that never looked are identical"
grep -qE '^ERROR +E18' <<<"$out4" \
  && bad "E18 fired with no inventory present — it has nothing to fire on" \
  || ok "E18 is silent when there is no inventory to check"

C5="$WORK/c5"; mk_consumer "$C5" "none"
printf 'prose only, no fenced block\n' > "$C5/.claude/skills/ai-dlc/machinery.md"
out5="$(run_val "$C5")"
grep -qE '^WARN +W10' <<<"$out5" \
  && ok "W10 fires when the inventory carries no block at all" \
  || bad "an inventory with no block is silent — silence and emptiness look alike again"

# ---- 6: a contract that predates the declaration leaves BOTH arms silent.
# v0.228.0's lesson: an arm that cannot tell "predates the key" from "failed to migrate"
# turns two unrelated fixtures red.
C6="$WORK/c6"; mk_consumer "$C6" ""
grep -v '^consumer_machinery_file:' "$C6/.claude/skills/ai-dlc/layer-contract.yaml" \
  > "$C6/.claude/skills/ai-dlc/lc.tmp" && mv "$C6/.claude/skills/ai-dlc/lc.tmp" "$C6/.claude/skills/ai-dlc/layer-contract.yaml"
if grep -q '^consumer_machinery_file:' "$C6/.claude/skills/ai-dlc/layer-contract.yaml"; then
  bad "FIXTURE BROKEN: could not remove the declaration, so case 6 tests nothing"
else
  out6="$(run_val "$C6")"
  grep -qE '^(ERROR +E18|WARN +W10)' <<<"$out6" \
    && bad "an arm fired on a contract that predates the declaration — v0.228.0's defect exactly" \
    || ok "both arms are silent on a contract with no machinery declaration"
fi

# ---- 7-9: EXISTENCE ON DISK IS NOT ENOUGH INSIDE A GIT REPOSITORY.
# The defect this covers hid a red trunk for four days in the reference consumer: a retirement
# deleted every tracked file under a declared directory, and a checkout that had once run the
# deleted tests still held an ignored `__pycache__/` inside it. `-e` was satisfied by the
# bytecode, so this clause read GREEN on that working tree and RED on a fresh clone of the SAME
# commit. A check reporting the opposite of trunk, on a tree `git status` calls clean.
#
# THE THREE ARMS ARE ONE CASE EACH AND NONE OF THEM IS REDUNDANT: the leftover must fire, a
# tracked file at the same path must NOT (or compliance wedges the consumer), and a project that
# is not a git repository at all must NOT (which is every case above this line, so the third arm
# is what stops the tightening from failing closed on a legitimate consumer state).
mk_git_consumer() { # $1 = dest, $2 = inventory body — same shape as mk_consumer, plus a repo
  mk_consumer "$1" "$2"
  git -C "$1" init -q 2>/dev/null
  git -C "$1" config user.email fixture@example.invalid
  git -C "$1" config user.name fixture
  printf '__pycache__/\n' > "$1/.gitignore"
}

# 7: the path exists ONLY as ignored leftovers. No tracked file is under it.
C7="$WORK/c7"; mk_git_consumer "$C7" "scripts/ai-dlc-local/retired-suite"
mkdir -p "$C7/scripts/ai-dlc-local/retired-suite/__pycache__"
printf 'stale bytecode\n' > "$C7/scripts/ai-dlc-local/retired-suite/__pycache__/x.cpython-314.pyc"
git -C "$C7" add -A >/dev/null 2>&1
git -C "$C7" commit -qm seed >/dev/null 2>&1
# FIXTURE CONTROL, and it is what makes the assertion below mean anything: the seed must
# reproduce the real shape — the path present, and git tracking nothing under it.
if [ ! -e "$C7/scripts/ai-dlc-local/retired-suite" ]; then
  bad "FIXTURE BROKEN: case 7's path is absent, so it tests the ORIGINAL arm and not the new one"
elif git -C "$C7" ls-files --error-unmatch -- scripts/ai-dlc-local/retired-suite >/dev/null 2>&1; then
  bad "FIXTURE BROKEN: case 7's leftover got TRACKED, so the seed is not the shape being tested"
else
  out7="$(run_val "$C7")"
  grep -q 'retired-suite.*git tracks no file there' <<<"$out7" \
    && ok "E18 fires when a declared path exists ONLY as ignored leftovers (green here, red on a clone)" \
    || bad "a declared path satisfied by ignored build output passed — the check reads the opposite of trunk"
  grep -q 'retired-suite.*no such file exists' <<<"$out7" \
    && bad "the leftover was reported as ABSENT — two different failures sharing one message" \
    || ok "the leftover is reported as its own failure, not as a missing path"
fi

# 8: the SAME path, tracked. The tightening must not fire on a compliant consumer.
C8="$WORK/c8"; mk_git_consumer "$C8" "scripts/ai-dlc-local/live-suite"
mkdir -p "$C8/scripts/ai-dlc-local/live-suite"
printf '#!/bin/sh\n' > "$C8/scripts/ai-dlc-local/live-suite/run.sh"
git -C "$C8" add -A >/dev/null 2>&1
git -C "$C8" commit -qm seed >/dev/null 2>&1
out8="$(run_val "$C8")"
grep -qE '^ERROR +E18' <<<"$out8" \
  && bad "E18 fired on a TRACKED declared path — the tightening wedges a compliant consumer" \
  || ok "a tracked declared path is silent (measured FP set on the reference consumer: 0 of 67)"

# 9: not a git repository. The tightening is SKIPPED, not failed — every case above this line
# relies on it, and failing closed here would wedge every consumer that is not version-controlled.
C9="$WORK/c9"; mk_consumer "$C9" "scripts/ai-dlc-local/untracked-but-present.sh"
printf '#!/bin/sh\n' > "$C9/scripts/ai-dlc-local/untracked-but-present.sh"
[ -e "$C9/.git" ] && bad "FIXTURE BROKEN: case 9 is a git repo, so it cannot test the non-repo path" || {
  out9="$(run_val "$C9")"
  grep -qE '^ERROR +E18' <<<"$out9" \
    && bad "E18 fired outside a git repository — 'not version-controlled' is a legitimate consumer state" \
    || ok "outside a git repository the tracked test is skipped rather than failed"
}

# ---- the run itself is a control: a validator that died prints nothing, and so does a clean tree
[ -n "$out1" ] && ok "the validator produced output (the run is not a silent death)" \
               || bad "the validator printed NOTHING — every assertion above is vacuous"

# ================================ mutant battery ================================
# Each mutant is a cmp -s guarded COPY and must turn exactly the assertions it should red.
if [ -n "${AI_DLC_CMI_VALIDATOR:-}" ]; then
  if [ "$fails" -eq 0 ]; then echo "PASS consumer-machinery-inventory"; exit 0; fi
  echo "FAIL consumer-machinery-inventory ($fails)"; exit 1
fi

MUT="$WORK/mutants"; mkdir -p "$MUT"
battery_fails=0
mut_reds() {
  local label="$1" prog="$2" copy="$MUT/$1.sh"
  if [ -z "$prog" ]; then cp "$VAL" "$copy"; else
    sed "$prog" "$VAL" > "$copy" 2>/dev/null
    if cmp -s "$VAL" "$copy"; then printf 'UNMUTATED\n'; return 0; fi
  fi
  AI_DLC_CMI_VALIDATOR="$copy" bash "$HERE/run.sh" 2>/dev/null | grep '^  FAIL  ' | sed 's/^  FAIL  //'
}
expect_set() { # $1 label, $2 expected count, $3 ERE every red must match, $4 sed
  local reds n unmatched
  reds="$(mut_reds "$1" "$4")"
  if [ "$reds" = "UNMUTATED" ]; then
    bad "MUTANT $1: the sed matched nothing — no mutation was applied, so nothing was proven"
    battery_fails=$((battery_fails+1)); return
  fi
  n="$(grep -c . <<<"$reds" || true)"
  unmatched="$(grep -vE "$3" <<<"$reds" | grep -c . || true)"
  if [ "$n" -eq "$2" ] && [ "$unmatched" -eq 0 ]; then
    ok "MUTANT $1 moves exactly the $2 assertion(s) it should, and no others"
  else
    bad "MUTANT $1: expected $2 red(s) matching '$3', got ${n} (${unmatched} unexpected): $(tr '\n' ';' <<<"$reds")"
    battery_fails=$((battery_fails+1))
  fi
}

ctl="$(mut_reds control "")"
[ -z "$ctl" ] && ok "CONTROL: an unmutated copy of the validator passes every assertion" \
              || { bad "CONTROL: an unmutated copy FAILED ($(tr '\n' ';' <<<"$ctl")) — every kill below is unearned"; battery_fails=$((battery_fails+1)); }

# M1 — the home comparison always matches, so nothing is ever "outside" it. The segregation
# arm goes silent while the existence arm keeps working.
expect_set home-always-matches 2 'outside the home|does not name a runnable move' \
  's@^          "\$MACHINERY_HOME"\*) ;;@          *) ;;@'

# M2 — the absent-path arm is removed. Only the absent-path assertion moves.
# REPOINTED at v0.240.0 and the repoint is the point: the old sed targeted a one-line
# `[ -e … ] || err E18` that the git-tracking arm turned into an if/elif, so it stopped matching
# and reported UNMUTATED rather than scoring a kill. That is the `cmp -s` guard doing its job --
# a mutation that matches nothing is indistinguishable from a surviving one without it.
expect_set no-existence-check 1 'does not exist' \
  's@^        if \[ ! -e "\$PROJECT_ROOT/\$mpath" \]; then@        if false; then@'

# M7 — the git-tracking arm is removed, so a path satisfied by ignored leftovers passes again.
# THIS IS THE DEFECT AS IT SHIPPED, held as a mutant: it read GREEN on a working tree while the
# same commit read RED on a fresh clone. ONE red, not two — the second case-7 assertion checks
# that the leftover is not reported as ABSENT, and with this arm gone nothing is reported at all.
expect_set no-tracked-check 1 'satisfied by ignored build output' \
  's@^        elif \[ -e "\$PROJECT_ROOT/.git" \] && ! git -C@        elif false \&\& ! git -C@'

# M3 — `none` stops being recognised, so an explicitly empty inventory is reported. This is
# the arm that keeps a compliant consumer from being punished for compliance.
expect_set none-not-honoured 1 "explicit 'none' was reported" \
  's@\[ "\$MACHINERY_LINES" = "none" \]@[ "$MACHINERY_LINES" = "NONEXX" ]@'

# M4 — the missing-inventory warning is removed. Silence and emptiness look alike again,
# which is the state the reference consumer sat in for the whole program.
expect_set no-missing-warning 1 'unscaffolded inventory is SILENT' \
  's@^    warn W10 "\$MACHINERY_REL: the ai-dlc machinery inventory has not been scaffolded@    : W10 "$MACHINERY_REL: the ai-dlc machinery inventory has not been scaffolded@'

# M5 — the arms stop being scoped to a contract that declares the key, so a consumer whose
# contract predates it is reported. v0.228.0's defect, reproduced deliberately.
expect_set unscoped-to-declaration 1 'predates the declaration' \
  's@^if \[ -n "\$MACHINERY_REL" \] && \[ -n "\$MACHINERY_HOME" \]; then@if [ -n "$MACHINERY_HOME" ]; then MACHINERY_REL="${MACHINERY_REL:-.claude/skills/ai-dlc/machinery.md}"@'

# M6 — the arm still fires and its remedy stops naming a runnable move. This is what keeps
# M1's two-cell expectation honest: without it the remedy cell is proven only by the mutant
# that silences the whole arm.
#
# IT SHIPPED INSIDE THE CHILD-RUN BRANCH AND HAD NEVER EXECUTED. `expect_set` and `mut_reds`
# are defined BELOW that branch, so in a child run the call was a command-not-found swallowed
# by the battery's own `2>/dev/null`, and in the parent run the branch is not taken at all.
# Measured: five MUTANT lines in the output and zero occurrences of this mutant's label.
# A mutant that cannot run reads exactly like one that killed — this repo's named class,
# produced inside the fixture whose control caught a different instance of it one release
# earlier.
expect_set remedy-unusable 1 'does not name a runnable move' \
  's@git mv @move @'

if [ "$fails" -eq 0 ]; then echo "PASS consumer-machinery-inventory"; exit 0; fi
echo "FAIL consumer-machinery-inventory ($fails)"; exit 1
