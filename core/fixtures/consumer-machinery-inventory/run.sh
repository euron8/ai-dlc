#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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

if [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-layer-entries.sh" ]; then
  VAL="$ROOT/core/scripts/validate-layer-entries.sh"
  echo "HERMETIC-CONSUMED core/scripts/validate-layer-entries.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/validate-layer-entries.sh" ]; then
  VAL="$ROOT/scripts/ai-dlc/validate-layer-entries.sh"
  echo "HERMETIC-CONSUMED scripts/ai-dlc/validate-layer-entries.sh"
else
  echo "FIXTURE ERROR: validate-layer-entries.sh not found in either layout" >&2; exit 2
fi

# IN PROCESS (BL-878). The validator is SOURCED ONCE into this shell (its guard returns after defining vle_main), and
# every drive calls vle_main inside a subshell, so its `exit`, `set -u`, EXIT trap and function definitions stay there.
# It starts as a program only in the cli cells (cells.decl). A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT: a subject with
# neither its `vle_main() {` line nor the column-0 source guard predates the wrap and reads SKIP (exit 0, never an ok);
# exactly one half is a respelled subject and FAILs; a subject grep cannot READ (exit 2) is FIXTURE ERROR.
wrap_gate() { # wrap_gate <file> <entry> -> 0 wrapped, 3 predates the wrap, 1 one half only (FAIL printed), 2 unreadable
  local d g
  grep -q "^$2() {\$" "$1"; d=$?
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$1"; g=$?
  if [ "$d" -gt 1 ] || [ "$g" -gt 1 ]; then
    echo "FIXTURE ERROR: cannot read $1 (grep exit $d/$g), so the in-process wrap cannot be judged; nothing was asserted" >&2
    return 2
  fi
  [ "$d$g" = 00 ] && return 0
  [ "$d$g" = 11 ] && return 3
  if [ "$d" = 1 ]; then echo "  FAIL  $1 carries the column-0 source guard but no \`$2() {\` line -- a respelled subject this fixture cannot drive"
  else echo "  FAIL  $1 defines \`$2() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run $2 in this shell"; fi
  return 1
}
wrap_gate "$VAL" vle_main; g_vle=$?
[ "$g_vle" = 2 ] && exit 2
[ "$g_vle" = 1 ] && { echo "consumer-machinery-inventory: 1 FAILED"; exit 1; }
[ "$g_vle" = 3 ] && { echo "SKIP: subject predates the in-process wrap"; exit 0; }
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

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
fx_inproc "$VAL"
. "$VAL" || { echo "FIXTURE ERROR: sourcing $VAL failed" >&2; exit 2; }
declare -F vle_main > /dev/null || { echo "FIXTURE ERROR: sourcing $VAL defined no vle_main" >&2; exit 2; }

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
run_val() { ( fx_inproc "$VAL"; vle_main "$1" ) 2>/dev/null; }

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

# ---- 10: AN UNREAD `consumer_machinery_home:` IS THE ONLY TRUE FALSE PASS IN THIS FILE.
#
# Every arm above is gated on `[ -n "$MACHINERY_REL" ] && [ -n "$MACHINERY_HOME" ]`, so an
# empty home retires the WHOLE of E18 and W10 with no finding: `rc` 1 -> 0 and the footer is
# fully plausible over a tree with a rogue path in it. Measured before the fix, one consumer
# with one path declared outside the home:
#
#   core-manifest.md readable   rc=1  errors=1  ERROR E18 <path> does not live under ...
#   same tree, mode 000         rc=0  errors=0  no finding, full footer, step() prints PASS
#
# Four trees, identical but for how the manifest is treated, because two of the states are
# indistinguishable in the output and the other two are opposites:
C10="$WORK/c10"; C11="$WORK/c11"; C12="$WORK/c12"; C13="$WORK/c13"
for _c in "$C10" "$C11" "$C12" "$C13"; do
  mk_consumer "$_c" "scripts/rogue.sh"
  printf '#!/bin/sh\n' > "$_c/scripts/rogue.sh"        # declared machinery, outside the home
done
chmod 000 "$C11/.claude/skills/ai-dlc/core-manifest.md"
# The key MISSPELLED in a fully readable file. This is not a variant of the mode-000 case:
# core-manifest.md is hand-maintained, so a typo needs no accident at all, and the guard is
# keyed on the VALUE rather than on any read's status precisely so it covers both.
sed 's/^consumer_machinery_home:/consumer_machinery_hom:/' \
  "$C12/.claude/skills/ai-dlc/core-manifest.md" > "$C12/.claude/skills/ai-dlc/cm.tmp"
mv "$C12/.claude/skills/ai-dlc/cm.tmp" "$C12/.claude/skills/ai-dlc/core-manifest.md"
rm -f "$C13/.claude/skills/ai-dlc/core-manifest.md"

# THE SEED ASSERTS ITSELF. chmod 000 does not make a file unreadable for root, and a `sed`
# that matched nothing leaves case 12 spelled correctly — either way the two refusal arms
# below would pass having asserted nothing.
if cat "$C11/.claude/skills/ai-dlc/core-manifest.md" >/dev/null 2>&1; then
  bad "FIXTURE BROKEN: case 11's manifest is still readable after chmod 000 (running as root?)"
elif grep -q '^consumer_machinery_home:' "$C12/.claude/skills/ai-dlc/core-manifest.md"; then
  bad "FIXTURE BROKEN: case 12's key was not misspelled, so it is a copy of case 10"
elif ! grep -q '^consumer_machinery_home:' "$C10/.claude/skills/ai-dlc/core-manifest.md"; then
  bad "FIXTURE BROKEN: case 10's manifest carries no consumer_machinery_home: to read"
else
  out10="$(run_val "$C10")"; out11="$(run_val "$C11")"
  out12="$(run_val "$C12")"; out13="$(run_val "$C13")"; rc13=$?
  chmod 644 "$C11/.claude/skills/ai-dlc/core-manifest.md" 2>/dev/null

  # THE CONTROL, and without it the three arms under it are vacuous: this group's trees have
  # to reach the segregation arm at all before "it stopped reaching it" means anything.
  grep -q 'rogue.sh.*does not live under' <<<"$out10" \
    && ok "READABLE home: the rogue path is reported, so this group's tree reaches the segregation arm" \
    || bad "READABLE home: no segregation finding — cases 11-13 below are asserting nothing"
  grep -q "could not read 'consumer_machinery_home:'" <<<"$out10" \
    && bad "the unread-home refusal fired on a manifest that reads perfectly well" \
    || ok "and the unread-home refusal stays quiet when the key reads"

  grep -q "could not read 'consumer_machinery_home:'" <<<"$out11" \
    && ok "UNREADABLE manifest: refuses instead of retiring E18 and W10 behind a clean footer" \
    || bad "UNREADABLE manifest: no finding — the false pass this arm exists to end"
  grep -q "could not read 'consumer_machinery_home:'" <<<"$out12" \
    && ok "MISSPELLED key, file readable: refuses too — the guard reads the VALUE, not a status" \
    || bad "MISSPELLED key: silent, so the guard is keyed on the read and misses the likelier typo"

  # THE ONE THAT MUST STAY QUIET. Every other seeded consumer in this suite is built by
  # mk_consumer, which copies core-manifest.md, so absence is a state only this case carries —
  # and an arm that erred on it would turn red every fixture whose tree was never meant to
  # hold the file. An exemption needs a probe proving it does not cover the arm's own subject.
  { [ "$rc13" -eq 0 ] && ! grep -qE '^ERROR +E18' <<<"$out13"; } \
    && ok "ABSENT manifest: silent and exit 0 — the refusal is scoped to a file that is there" \
    || bad "ABSENT manifest: reported, so the arm fires on trees that were never meant to carry it"
fi

# ---- the run itself is a control: a validator that died prints nothing, and so does a clean tree
[ -n "$out1" ] && ok "the validator produced output (the run is not a silent death)" \
               || bad "the validator printed NOTHING — every assertion above is vacuous"

# ---- the cli cells (cells.decl): the validator run as a PROGRAM once per distinct CLI outcome this fixture reads
# (exit 1 on the seeded E18 inventory, exit 0 on the correctly segregated one), each compared byte for byte with the
# in-process call on the same input: stdout, stderr and exit separately, and each asserting its own outcome.
EQ="$WORK/eq"; mkdir -p "$EQ" || exit 2
eqv() { # eqv <cell-id> <args...> -> $EQ/<id>.{ip,cl}.{out,err,rc}; 0 when the two answers are identical
  local id="$1"; shift
  ( fx_inproc "$VAL"; vle_main "$@" ) > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" bash "$VAL" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(tail -2 "$EQ/$1.ip.out")" "$(head -2 "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(tail -2 "$EQ/$1.cl.out")" "$(head -2 "$EQ/$1.cl.err")"; }
if eqv cli-fail "$C1" && [ "$(cat "$EQ/cli-fail.cl.rc")" = 1 ] && grep -qE '^ERROR +E18' "$EQ/cli-fail.cl.out"; then
  ok "cli-fail: the program refuses the seeded inventory exactly as the in-process call does (stdout, stderr, exit 1, an E18)"
else bad "cli-fail: the program and the in-process call differ, or the outcome is not exit 1 with an E18 ($(eq_twin cli-fail))"; fi
if eqv cli-pass "$C2" && [ "$(cat "$EQ/cli-pass.cl.rc")" = 0 ] && grep -q '^LAYER_CONFORMANCE v1 .* errors=0 ' "$EQ/cli-pass.cl.out"; then
  ok "cli-pass: the program passes the segregated inventory exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-pass: the program and the in-process call differ, or the outcome is not exit 0 with errors=0 ($(eq_twin cli-pass))"; fi
report_end consumer-machinery-inventory
