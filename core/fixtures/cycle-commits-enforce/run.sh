#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/preamble.sh"
# cycle-commits-enforce — prove validate-cycle-commits.sh enforces the >=3-cycle
# floor with matching log rows, that the enforcement is not vacuous (a guard
# mutation flips a real FAIL to green), and that mandatory-rules Check 2 actually
# delegates to it — engaging when a validation-cycle-log.md is present and SKIPping
# (never failing) when the producer is absent.
#
# THE DEFECTS THIS EXISTS TO CATCH.
#  - A validator that always PASSes is indistinguishable from one that works; the
#    guard-mutation assertion pins the >=3-log-rows predicate so its removal is
#    observable.
#  - A wired-but-uncalled delegation: Check 2 could SKIP forever after the sibling
#    shipped to core. The delegation assertions prove Check 2 runs the validator on
#    log-presence, and re-keys its SKIP to the log (not the sibling's presence).
#
# A retro branch is used because mandatory-rules Check 2 passes
# "ai-dlc/retro/sprint-<N>" to the validator: planning artifacts are squash-skipped,
# the retro artifact is validated.
#
# IN PROCESS (BL-878). validate-mandatory-rules.sh is SOURCED in a subshell and its vmr_main called (vmr_ip), with
# pipefail off as the program runs it; each source is one fx_inproc pass (the inproc: row). Two cli cells, exit 0
# (--check-clean-tree) and exit 1 (sprint 900), each compare the program's stdout, stderr and exit with the in-process
# call on the same input (cells.decl).
#
# THE MUTANT MATRIX (fixture-mutants.md 'One run per distinct state'). The four mutants copy validate-cycle-commits.sh;
# the arms (cce_arm) are the cells their kills read: valid (A1), rows (A2), prior (A6), vac (A9), carve (A13), each
# re-seeding its own branch and log. PER PUSH a mutant runs its deciding arm (the kill's own check, unchanged) and its
# TWIN, an arm the measured matrix shows GREEN for it, which must stay green (cce_twin). `--matrix` runs the unmutated
# validator (ctl) and every mutant on every arm and prints one `MATRIX <mutant> <arm> GREEN|TRIPPED` row per cell.
# RE-MEASURE whenever an arm or a mutant is added or changed, from the repo root:
# MUTANT-MATRIX-REMEASURE bash core/fixtures/cycle-commits-enforce/run.sh --matrix
# Measured: ctl GREEN on all five arms; each mutant trips its own arm alone (log-rows-guard rows, prior-sprint-test
# prior, non-vacuity vac, carve-out carve) and every other cell is GREEN.
# MUTANT-MATRIX log-rows-guard decides=rows twins=valid
# MUTANT-MATRIX prior-sprint-test decides=prior twins=valid
# MUTANT-MATRIX non-vacuity decides=vac twins=prior
# MUTANT-MATRIX carve-out decides=carve twins=valid
# MUTANT-MATRIX-CONTROL ctl why=the unmutated validate-cycle-commits.sh; every arm holds there, and the B_ flags gate every kill on its arm
set -uo pipefail
MATRIX=0
case "${1:-}" in
  "") ;;
  --matrix) MATRIX=1 ;;
  *) echo "FIXTURE ERROR: unknown argument '$1' (usage: run.sh [--matrix])" >&2; exit 2 ;;
esac

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

# install.sh maps core/scripts/<x> -> scripts/ai-dlc/<x> at the project root.
if   [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-cycle-commits.sh" ]; then
  VALIDATOR="$ROOT/core/scripts/validate-cycle-commits.sh"
  VMR="$ROOT/core/scripts/validate-mandatory-rules.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/validate-cycle-commits.sh" ]; then
  VALIDATOR="$ROOT/scripts/ai-dlc/validate-cycle-commits.sh"
  VMR="$ROOT/scripts/ai-dlc/validate-mandatory-rules.sh"
else
  echo "FIXTURE ERROR: validate-cycle-commits.sh not found in either layout" >&2
  exit 2
fi

command -v git     >/dev/null 2>&1 || { echo "FIXTURE ERROR: git not on PATH" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 not on PATH" >&2; exit 2; }

# Scrub ambient AI_DLC_* — a leaked AI_DLC_TRUNK would repoint the commit range.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: cannot source lib/mutant.sh beside $HERE" >&2; exit 2; }
B_carve=0; B_prior=0; B_rows=0; B_vac=0

# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A consumer can hold a validate-mandatory-rules.sh from before its
# vmr_main wrap, which sourcing would run as a whole series with this file's argv. Its two halves are read first:
# neither the `vmr_main() {` line nor the column-0 source guard is a subject that predates the wrap, and the Check 2
# arms below take the path they already take for an absent one (a note, never an ok; this fixture's own subject,
# validate-cycle-commits.sh, is still tested). Exactly one of the two is a respelled subject: FAIL. Unreadable
# (grep exit 2): FIXTURE ERROR.
VMR_PREWRAP=0
if [ -f "$VMR" ]; then
  vm_has() { grep -qxF -- "$1" "$VMR"; case $? in 0) printf 1 ;; 1) printf 0 ;; *) printf E ;; esac; }
  vm_gate="$(vm_has 'vmr_main() {')$(vm_has '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0')"
  case "$vm_gate" in
    11) ;;
    00) VMR_PREWRAP=1 ;;
    01|10) echo "  FAIL  $VMR carries only part of the in-process wrap (vmr_main, column-0 guard: $vm_gate) -- a respelled subject this fixture cannot drive"
           echo "cycle-commits-enforce: FAIL (1 assertion(s))"; exit 1 ;;
    *) echo "FIXTURE ERROR: cannot read $VMR (got '$vm_gate')" >&2; exit 2 ;;
  esac
fi
# vmr_ip <args...>: one in-process call of validate-mandatory-rules.sh, its streams and exit as the program's.
vmr_ip() {
  fx_inproc "$VMR"
  ( set +o pipefail; . "$VMR" || exit 97; vmr_main "$@" )
}

LOG="_bmad-output/validation-cycle-log.md"

# write_log <n-rows> — a "## Sprint 900 — retro" section with N numbered rows.
write_log() {
  mkdir -p "$WORK/_bmad-output"
  {
    printf '## Sprint 900 — retro\n\n'
    printf '| # | Cycle | Notes | SHA |\n'
    printf '|---|-------|-------|-----|\n'
    local i=1
    while [ "$i" -le "$1" ]; do
      printf '| %d | cycle-%d | note | TBD |\n' "$i" "$i"
      i=$((i+1))
    done
  } > "$WORK/$LOG"
}

cd "$WORK" || exit 2
git -c init.defaultBranch=main init -q . 2>/dev/null || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }
git config user.email f@example.com
git config user.name Fixture
git config commit.gpgsign false

echo "seed" > seed.txt
git add -A && git commit -q -m "init"
git branch -M main

# Retro branch with three retro cycle commits: party-mode + adversarial-review.
git checkout -q -b ai-dlc/retro/sprint-900
commit_cycle() { echo "$1" >> work.txt; git add -A; git commit -q -m "$1"; }
commit_cycle "Sprint 900 retro: party-mode cycle 1"
commit_cycle "Sprint 900 retro: adversarial-review pass 1"
commit_cycle "Sprint 900 retro: party-mode cycle 2"

# cce_arm <arm> <validator> -> 0 GREEN (the arm holds, as on the unmutated validator), 1 TRIPPED. Each arm seeds its
# own branch and log and puts back what it found -- the branch, the log and the sprint-status dir -- so it can run
# beside any assertion. The carve arm's branch, cce-arm/ts, is its own (built once, from the retro tip), never the
# feature/ts-carveout branch assertion 13 builds.
cce_arm() {
  local a="$1" v="$2" br had_log=0 had_ia=0 r br_run
  br="$(git rev-parse --abbrev-ref HEAD)"
  rm -rf "$WORK/.git/arm-save"; mkdir -p "$WORK/.git/arm-save"
  [ -f "$WORK/$LOG" ] && { cp -p "$WORK/$LOG" "$WORK/.git/arm-save/log"; had_log=1; }
  [ -d "$WORK/_bmad-output/implementation-artifacts" ] && { cp -Rp "$WORK/_bmad-output/implementation-artifacts" "$WORK/.git/arm-save/ia"; had_ia=1; }
  rm -rf "$WORK/_bmad-output/implementation-artifacts"
  br_run=ai-dlc/retro/sprint-900
  # Off the current branch the log and the sprint-status dir are this arm's to write; the saved copies come back after.
  rm -f "$WORK/$LOG"
  git checkout -q ai-dlc/retro/sprint-900 || { echo "FIXTURE ERROR: arm $a could not check out the retro branch" >&2; exit 2; }
  case "$a" in
    valid|rows) [ "$a" = valid ] && write_log 3 || write_log 2 ;;
    prior) write_log 3
      printf '\n## Sprint 136 — retro\n\n| # | Cycle | Notes | SHA |\n|---|-------|-------|-----|\n| 1 | party-mode cycle 1 | note | `deadbee` |\n| 2 | adversarial-review pass 1 | note | `deadbef` |\n| 3 | party-mode cycle 2 | note | `deadbf0` |\n' >> "$WORK/$LOG" ;;
    vac) mkdir -p "$WORK/_bmad-output"
      printf '## Sprint 800 — retro\n\n| # | Cycle | Notes | SHA |\n|---|-------|-------|-----|\n| 1 | party-mode cycle 1 | note | `%s` |\n| 2 | adversarial-review pass 1 | note | `%s` |\n| 3 | party-mode cycle 2 | note | `%s` |\n' \
        "$(git rev-parse HEAD)" "$(git rev-parse HEAD~1)" "$(git rev-parse HEAD~2)" > "$WORK/$LOG" ;;
    carve) br_run=cce-arm/ts
      if git rev-parse -q --verify refs/heads/cce-arm/ts >/dev/null; then git checkout -q cce-arm/ts
      else git checkout -q -b cce-arm/ts
        # work.txt alone, never `git add -A` (commit_cycle): the arm must not commit this run's untracked files.
        for _p in 1 2 3; do echo "Sprint 900 test-strategy: adversarial-review pass $_p" >> work.txt; git add work.txt
          git commit -q -m "Sprint 900 test-strategy: adversarial-review pass $_p"; done
      fi
      write_log 3
      printf '\n## Sprint 900 — Test Strategy\n\n| # | Cycle | Notes | SHA |\n|---|-------|-------|-----|\n| 1 | adversarial-review pass 1 | note | TBD |\n| 2 | adversarial-review pass 2 | note | TBD |\n| 3 | adversarial-review pass 3 | note | TBD |\n' >> "$WORK/$LOG" ;;
    *) echo "FIXTURE ERROR: no arm '$a'" >&2; exit 2 ;;
  esac
  bash "$v" "$br_run" > "$WORK/.git/arm.txt" 2>&1; r=$?
  case "$a" in
    valid) [ "$r" = 0 ] && grep -q 'RESULT: PASS' "$WORK/.git/arm.txt" ;;
    rows) [ "$r" = 1 ] && grep -q 'FAIL' "$WORK/.git/arm.txt" ;;
    prior) [ "$r" = 0 ] && grep -q 'UNVERIFIABLE (history rewritten)' "$WORK/.git/arm.txt" && grep -q 'RESULT: PASS' "$WORK/.git/arm.txt" ;;
    vac) [ "$r" = 4 ] && grep -q 'NOTHING MEASURED' "$WORK/.git/arm.txt" ;;
    carve) [ "$r" = 0 ] && grep -q 'EXEMPT (Rule 8 carve-out: convergence series, Check 24)' "$WORK/.git/arm.txt" ;;
  esac
  r=$?
  rm -f "$WORK/$LOG"; rm -rf "$WORK/_bmad-output/implementation-artifacts"
  git checkout -q "$br" || { echo "FIXTURE ERROR: arm $a could not return to $br" >&2; exit 2; }
  if [ "$had_log" = 1 ]; then cp -p "$WORK/.git/arm-save/log" "$WORK/$LOG"; else rm -f "$WORK/$LOG"; fi
  [ "$had_ia" = 1 ] && cp -Rp "$WORK/.git/arm-save/ia" "$WORK/_bmad-output/implementation-artifacts"
  rm -rf "$WORK/.git/arm-save"
  return "$r"
}
CCE_ARMS="valid rows prior vac carve"
# cce_twin <mutant copy> <twin arm> <mutant name> -> 0 when the twin holds under the mutant, so the kill is confined;
# otherwise one FAIL naming it. Run after the deciding check has been read.
cce_twin() {
  cce_arm "$2" "$1" && return 0
  bad "MUTATION $3: twin $2 tripped beside its deciding arm -- the kill is not confined to it; re-measure the matrix (--matrix)"
  return 1
}

echo "cycle-commits-enforce"

# --- 1. Valid tree passes -----------------------------------------------------
write_log 3
bash "$VALIDATOR" ai-dlc/retro/sprint-900 >"$WORK/out.txt" 2>&1
if [ "$?" = "0" ] && grep -q 'RESULT: PASS' "$WORK/out.txt"; then
  ok "3 cycle commits + 3 log rows + party-mode & adversarial-review passes"
else
  bad "a valid retro artifact failed"; sed 's/^/        /' "$WORK/out.txt"
fi

# --- 2. Fewer than 3 log rows fails (input reaction) --------------------------
write_log 2
if ! grep -q '| 2 |' "$WORK/$LOG" || grep -q '| 3 |' "$WORK/$LOG"; then
  bad "FIXTURE: 2-row log was not written as expected"
fi
bash "$VALIDATOR" ai-dlc/retro/sprint-900 >"$WORK/out.txt" 2>&1
if [ "$?" = "1" ] && grep -q 'FAIL' "$WORK/out.txt"; then
  ok "2 log rows (< 3) fails"; B_rows=1
else
  bad "an under-cycled artifact did not fail"; sed 's/^/        /' "$WORK/out.txt"
fi

# --- 3. MUTATION: neuter the >=3-log-rows guard -> the FAIL input goes green ---
MUTANT="$WORK/mutant.sh"
sed 's/log_rows < min_cycles/False/' "$VALIDATOR" > "$MUTANT" || exit 2
if cmp -s "$VALIDATOR" "$MUTANT"; then
  echo "FIXTURE ERROR: mutation matched nothing — the log-rows predicate was rewritten" >&2
  echo "  update the sed pattern in assertion 3 to match the real comparison" >&2
  exit 2
fi
bash "$MUTANT" ai-dlc/retro/sprint-900 >"$WORK/mut.txt" 2>&1
if [ "$?" = "0" ]; then
  cce_twin "$MUTANT" valid log-rows-guard &&
  mutant_killed "$B_rows" log-rows-guard "MUTATION: disabling the log-rows guard makes the 2-row input pass (FAIL was real)"
else
  bad "MUTATION: the 2-row input still failed without the guard"; sed 's/^/        /' "$WORK/mut.txt"
fi

# --- 4. Check 2 delegation ENGAGES when the log is present --------------------
write_log 3
if [ -f "$VMR" ] && [ "$VMR_PREWRAP" = 0 ]; then
  echo "HERMETIC-CONSUMED core/scripts/validate-mandatory-rules.sh"
  VOUT="$(vmr_ip 900 2>/dev/null || true)"
  if grep -q 'CHECK 2: PASS' <<<"$VOUT"; then
    ok "mandatory-rules Check 2 delegates to the validator and PASSes with a log present"
  else
    bad "Check 2 did not engage the validator with a log present"
    echo "$VOUT" | grep -i 'check 2' | sed 's/^/        /'
  fi

# --- 5. Check 2 SKIPs (never fails) when the producer is absent ---------------
  rm -f "$WORK/$LOG"
  VOUT="$(vmr_ip 900 2>/dev/null || true)"
  if grep -q 'CHECK 2: SKIP' <<<"$VOUT"; then
    ok "mandatory-rules Check 2 SKIPs when no validation-cycle-log.md (log-keyed opt-in)"
  else
    bad "Check 2 did not SKIP on a missing log"
    echo "$VOUT" | grep -i 'check 2' | sed 's/^/        /'
  fi

# --- 5b. THE CLI CELLS (cells.decl): the program once per distinct outcome, against the in-process call ---------
# exit 0 (--check-clean-tree: the toolchain beside the script is present) and exit 1 (sprint 900: checks fail in
# this tree). Each compares stdout, stderr and exit byte for byte; each asserts its own outcome, and the two differ.
# Both reach a `${BASH_SOURCE[0]}` site (:118 and :150), which a sourced call would resolve to run.sh under `$0`.
  EQ="$WORK/eq"; mkdir -p "$EQ"
  vmr_eqv() { # <cell-id> <args...> -> 0 when the program and the in-process call agree on all three streams
    local id="$1"; shift
    vmr_ip "$@" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
    FXCELL="$id" bash "$VMR" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
    cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
  }
  vmr_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
    "$(sed -n 1,2p "$EQ/$1.ip.out")" "$(sed -n 1,2p "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(sed -n 1,2p "$EQ/$1.cl.out")" "$(sed -n 1,2p "$EQ/$1.cl.err")"; }
  if vmr_eqv vmr-clean-tree --check-clean-tree && [ "$(cat "$EQ/vmr-clean-tree.cl.rc")" = 0 ] \
     && grep -q '^VALIDATE-MANDATORY-RULES: PASS (--check-clean-tree' "$EQ/vmr-clean-tree.cl.out"; then
    ok "vmr-clean-tree: --check-clean-tree as a program equals the in-process call (stdout, stderr, exit 0, PASS)"
  else bad "vmr-clean-tree: the program and the in-process call differ, or the outcome is not exit 0 PASS ($(vmr_twin vmr-clean-tree))"; fi
  if vmr_eqv vmr-sprint-900 900 && [ "$(cat "$EQ/vmr-sprint-900.cl.rc")" = 1 ] \
     && grep -q '^VALIDATE-MANDATORY-RULES: FAIL$' "$EQ/vmr-sprint-900.cl.out"; then
    ok "vmr-sprint-900: sprint 900 as a program equals the in-process call (stdout, stderr, exit 1, FAIL)"
  else bad "vmr-sprint-900: the program and the in-process call differ, or the outcome is not exit 1 FAIL ($(vmr_twin vmr-sprint-900))"; fi
  if ! cmp -s "$EQ/vmr-clean-tree.cl.rc" "$EQ/vmr-sprint-900.cl.rc"; then
    ok "vmr cli cells discriminate: the passing and the refusing input give different exits"
  else bad "vmr cli cells do not discriminate: both gave the same exit"; fi
elif [ "$VMR_PREWRAP" = 1 ]; then
  echo "  note  validate-mandatory-rules.sh predates the in-process wrap — delegation assertions skipped"
else
  echo "  note  validate-mandatory-rules.sh absent — delegation assertions skipped"
fi

# --- 6. A PRIOR sprint's unreachable SHAs must not fail every future retro -----
# The MERGED (prior sprint) carve-out needs EVERY row SHA to resolve in the repo. A squash-
# history rewrite, or a log row written before the SHA-citation convention, leaves a dead SHA
# the carve-out cannot fire on — so the row fell through to `FAIL (<N commits)` with no path
# back short of hand-editing a 150-sprint-old log. Check 2 reports this script's process-wide
# exit code as the retro's own verdict, so every future sprint inherited somebody else's dead
# history as its own opaque FAIL.
write_log 3
{
  printf '\n## Sprint 136 — retro\n\n'
  printf '| # | Cycle | Notes | SHA |\n'
  printf '|---|-------|-------|-----|\n'
  printf '| 1 | party-mode cycle 1 | note | `deadbee` |\n'
  printf '| 2 | adversarial-review pass 1 | note | `deadbef` |\n'
  printf '| 3 | party-mode cycle 2 | note | `deadbf0` |\n'
} >> "$WORK/$LOG"
bash "$VALIDATOR" ai-dlc/retro/sprint-900 >"$WORK/out.txt" 2>&1
rc=$?
if [ "$rc" = "0" ] && grep -q 'UNVERIFIABLE (history rewritten)' "$WORK/out.txt" \
   && grep -q 'RESULT: PASS' "$WORK/out.txt"; then
  ok "a prior sprint's unreachable SHAs report UNVERIFIABLE and do not fail the current sprint"; B_prior=1
else
  bad "a prior sprint's dead SHAs still fail the run (rc=$rc)"; sed 's/^/        /' "$WORK/out.txt"
fi

# The exemption must be SAID, not swallowed: a skip nobody can see reads as a check that
# scanned everything and found nothing.
if grep -q 'NOTE: 1 prior-sprint section(s) UNVERIFIABLE' "$WORK/out.txt"; then
  ok "the skipped section is named in the output, not silently dropped"
else
  bad "the UNVERIFIABLE exemption was applied without saying so"
fi

# --- 7. THE CURRENT sprint is never exempted this way -------------------------
# Without this, assertion 6 would read as a blanket amnesty for any dead SHA, and the check it
# is supposed to preserve — "MY sprint skipped its cycles" — would be gone.
#
# A NON-retro branch, deliberately: on a retro branch the current sprint's planning artifacts
# are already skipped as SQUASHED by an older carve-out, which would make this assertion pass
# for a reason that has nothing to do with the one under test.
git checkout -q -b ai-dlc/story/sprint-900
{
  printf '## Sprint 900 — brief\n\n'
  printf '| # | Cycle | Notes | SHA |\n'
  printf '|---|-------|-------|-----|\n'
  printf '| 1 | party-mode cycle 1 | note | `deadbee` |\n'
  printf '| 2 | adversarial-review pass 1 | note | `deadbef` |\n'
  printf '| 3 | party-mode cycle 2 | note | `deadbf0` |\n'
} > "$WORK/$LOG"
bash "$VALIDATOR" ai-dlc/story/sprint-900 >"$WORK/out.txt" 2>&1
rc=$?
if [ "$rc" = "1" ] && ! grep -q 'UNVERIFIABLE' "$WORK/out.txt"; then
  ok "the sprint UNDER VALIDATION with dead SHAs still FAILS (the exemption is not an amnesty)"
else
  bad "the current sprint was exempted as UNVERIFIABLE (rc=$rc) — the check it preserves is gone"
  sed 's/^/        /' "$WORK/out.txt"
fi
git checkout -q ai-dlc/retro/sprint-900

# --- 8. MUTATION: remove the prior-sprint test and assertion 6's input must FAIL again --
# The exemption keys on `sprint_n != current_sprint_n`. Flip that to never-true and the dead
# prior-sprint SHAs go back to failing the run, which is the state the consumer measured.
MUT2="$WORK/mutant-scope.sh"
sed 's/if not is_current(sprint_n):/if False:/' "$VALIDATOR" > "$MUT2" || exit 2
write_log 3
{
  printf '\n## Sprint 136 — retro\n\n'
  printf '| # | Cycle | Notes | SHA |\n'
  printf '|---|-------|-------|-----|\n'
  printf '| 1 | party-mode cycle 1 | note | `deadbee` |\n'
  printf '| 2 | adversarial-review pass 1 | note | `deadbef` |\n'
  printf '| 3 | party-mode cycle 2 | note | `deadbf0` |\n'
} >> "$WORK/$LOG"
if cmp -s "$VALIDATOR" "$MUT2"; then
  bad "MUTATION: the scope predicate was rewritten — assertion 6 is unproven until this sed is updated"
else
  bash "$MUT2" ai-dlc/retro/sprint-900 >"$WORK/mut2.txt" 2>&1
  if [ "$?" = "1" ] && ! grep -q 'UNVERIFIABLE' "$WORK/mut2.txt"; then
    cce_twin "$MUT2" valid prior-sprint-test &&
    mutant_killed "$B_prior" prior-sprint-test "MUTATION: without the prior-sprint test, dead SHAs fail the run again (assertion 6 is real)"
  else
    bad "MUTATION: the run still passed without the prior-sprint test — assertion 6 is vacuous"
    sed 's/^/        /' "$WORK/mut2.txt"
  fi
fi

# --- 9. NON-VACUITY: an exempted subject set is not a verified one -------------
# Measured on the reference consumer at sprint 302, whose log's newest section is 247: every
# section was exempted, zero cycles were counted, and the script printed
# `RESULT: PASS -- all artifacts have >=3 cycles`. Each carve-out was right; nothing was
# counting what survived them. Exit 4, never 0.
git checkout -q ai-dlc/retro/sprint-900
S1="$(git rev-parse HEAD)"; S2="$(git rev-parse HEAD~1)"; S3="$(git rev-parse HEAD~2)"
prior_only_log() {  # a log whose ONLY section is a prior sprint's, with LIVE SHAs
  mkdir -p "$WORK/_bmad-output"
  {
    printf '## Sprint %s — retro\n\n' "$1"
    printf '| # | Cycle | Notes | SHA |\n'
    printf '|---|-------|-------|-----|\n'
    printf '| 1 | party-mode cycle 1 | note | `%s` |\n' "$S1"
    printf '| 2 | adversarial-review pass 1 | note | `%s` |\n' "$S2"
    printf '| 3 | party-mode cycle 2 | note | `%s` |\n' "$S3"
  } > "$WORK/$LOG"
}
prior_only_log 800
bash "$VALIDATOR" ai-dlc/retro/sprint-900 >"$WORK/vac.txt" 2>&1
rc=$?
# The control is in the same run: the section must have been PARSED and exempted, not missed.
# A log this script failed to read would produce the same "nothing measured" for the opposite
# reason, and the two must not score the same.
if [ "$rc" = "4" ] && grep -q 'NOTHING MEASURED' "$WORK/vac.txt" \
   && ! grep -q 'RESULT: PASS' "$WORK/vac.txt" \
   && grep -q 'MERGED (prior sprint)' "$WORK/vac.txt" \
   && grep -q 'the log parsed 1 section(s)' "$WORK/vac.txt"; then
  ok "a log with only PRIOR-sprint sections exits 4 (NOTHING MEASURED), never a bare PASS"; B_vac=1
else
  bad "an all-exempted run still reported a pass (rc=$rc)"; sed 's/^/        /' "$WORK/vac.txt"
fi

# --- 9b. The 4 REACHES THE GATE. This is why it is an exit code and not a worklist line ----
# Check 2 captures this script's output into a variable, prints `CHECK 2: PASS` on exit 0 and
# never prints the capture. A worklist at exit 0 would be invisible at the only place the
# verdict is consumed. Assert the wedge is real and visible, because choosing to wedge a
# dormant-log consumer is the load-bearing half of that decision.
if [ -f "$VMR" ] && [ "$VMR_PREWRAP" = 0 ]; then
  echo "HERMETIC-CONSUMED core/scripts/validate-mandatory-rules.sh"
  # 2>&1, unlike the arms above: mandatory-rules prints its per-check verdict on stdout and
  # accumulates the DETAIL into FAILURE_MSGS, which it dumps to stderr at the end. Reading
  # only stdout would score a bare `CHECK 2: FAIL` as full disclosure.
  VOUT="$(vmr_ip 900 2>&1 || true)"
  if grep -q 'CHECK 2: FAIL' <<<"$VOUT" && grep -q 'exited 4' <<<"$VOUT" \
     && grep -q 'NOTHING MEASURED' <<<"$VOUT"; then
    ok "mandatory-rules Check 2 renders the 4 as FAIL and carries the code into its message"
  else
    bad "Check 2 did not surface the non-vacuity finding"
    echo "$VOUT" | grep -i -A2 'check 2' | sed 's/^/        /'
  fi
fi

# --- 10. The CURRENT sprint's own section, exempted as MERGED, is still nothing measured --
# `MERGED (prior sprint)` never asked which sprint. On the reference consumer it exempted the
# section of the sprint the run believed it was validating, one line under a NOTE claiming the
# current sprint is never exempted. The predicate is left alone deliberately — this asserts
# only that the exemption is no longer mistaken for a measurement.
git checkout -q -b ai-dlc/story/sprint-901 2>/dev/null || git checkout -q ai-dlc/story/sprint-901
prior_only_log 901
bash "$VALIDATOR" ai-dlc/story/sprint-901 >"$WORK/vac2.txt" 2>&1
rc=$?
if [ "$rc" = "4" ] && grep -q 'MERGED (prior sprint)' "$WORK/vac2.txt" \
   && grep -q 'all removed by a carve-out' "$WORK/vac2.txt" \
   && grep -q 'Sprint 901 retro \[MERGED\]' "$WORK/vac2.txt"; then
  ok "the CURRENT sprint's own section exempted as MERGED reports NOTHING MEASURED, naming it"
else
  bad "a current-sprint section eaten by MERGED still passed (rc=$rc)"
  sed 's/^/        /' "$WORK/vac2.txt"
fi

# --- 11. The sprint under validation is derived from OUTSIDE the log ----------
# THE ARM ABOVE CANNOT FIRE WITHOUT THIS. The old fallback took the log's own highest section
# number when the branch named no sprint, under which the log agrees with itself by
# construction and "no section for the sprint under validation" is unreachable. This is the
# isolating pair: same tree, same log, same branch — the only difference is whether an
# external declaration of the current sprint exists.
git checkout -q ai-dlc/retro/sprint-900
git checkout -q -b feature/misc-work 2>/dev/null || git checkout -q feature/misc-work
write_log 3   # a live Sprint 900 retro section; the branch's 3 retro commits count for it

rm -rf "$WORK/_bmad-output/implementation-artifacts"
bash "$VALIDATOR" feature/misc-work >"$WORK/nostat.txt" 2>&1
rc_nostat=$?

mkdir -p "$WORK/_bmad-output/implementation-artifacts"
printf 'sprint: 901\nstatus: in_progress\n' > "$WORK/_bmad-output/implementation-artifacts/sprint-status.yaml"
bash "$VALIDATOR" feature/misc-work >"$WORK/stat.txt" 2>&1
rc_stat=$?

if [ "$rc_nostat" = "0" ] && grep -q 'RESULT: PASS' "$WORK/nostat.txt"; then
  ok "CONTROL: with no external declaration the log's own newest sprint is validated (PASS)"
else
  bad "the control arm did not pass (rc=$rc_nostat) — assertion 11's pair is not isolating"
  sed 's/^/        /' "$WORK/nostat.txt"
fi
if [ "$rc_stat" = "4" ] && grep -q 'sprint-status.yaml' "$WORK/stat.txt" \
   && grep -q 'NO section in the log at all' "$WORK/stat.txt"; then
  ok "sprint-status.yaml names sprint 901, the log stops at 900 -> NOTHING MEASURED, source named"
else
  bad "the sprint under validation was still taken from the log (rc=$rc_stat)"
  sed 's/^/        /' "$WORK/stat.txt"
fi
rm -rf "$WORK/_bmad-output/implementation-artifacts"

# --- 12. MUTATION: neuter the non-vacuity arm -> assertion 9's input goes green --
MUT3="$WORK/mutant-vacuity.sh"
sed 's/^if measured_current == 0:/if False:/' "$VALIDATOR" > "$MUT3" || exit 2
git checkout -q ai-dlc/retro/sprint-900
prior_only_log 800
if cmp -s "$VALIDATOR" "$MUT3"; then
  bad "MUTATION: the non-vacuity predicate was rewritten — assertion 9 is unproven until this sed is updated"
else
  bash "$MUT3" ai-dlc/retro/sprint-900 >"$WORK/mut3.txt" 2>&1
  if [ "$?" = "0" ] && grep -q 'RESULT: PASS' "$WORK/mut3.txt"; then
    cce_twin "$MUT3" prior non-vacuity &&
    mutant_killed "$B_vac" non-vacuity "MUTATION: without the arm, the all-exempted log prints the old bare PASS (the 4 was real)"
  else
    bad "MUTATION: the all-exempted log did not pass without the arm — assertion 9 is vacuous"
    sed 's/^/        /' "$WORK/mut3.txt"
  fi
fi

# --- 13. Rule 8 carve-out: a `Test Strategy` section with AR-only commits is EXEMPT --
# 0.890.0 moved the test-strategy review to a convergence series with no party round. The
# carve-out keys on the normalized `test-strategy` artifact key, not on a version, and
# continues past the floor, party-mode and AR arms. The Sprint 900 retro section is the
# measured control (so the run is not NOTHING MEASURED), and its PASS shows the log parsed.
git checkout -q ai-dlc/retro/sprint-900
git checkout -q -b feature/ts-carveout 2>/dev/null || git checkout -q feature/ts-carveout
commit_cycle "Sprint 900 test-strategy: adversarial-review pass 1"
commit_cycle "Sprint 900 test-strategy: adversarial-review pass 2"
commit_cycle "Sprint 900 test-strategy: adversarial-review pass 3"
write_log 3
{
  printf '\n## Sprint 900 — Test Strategy\n\n'
  printf '| # | Cycle | Notes | SHA |\n'
  printf '|---|-------|-------|-----|\n'
  printf '| 1 | adversarial-review pass 1 | note | TBD |\n'
  printf '| 2 | adversarial-review pass 2 | note | TBD |\n'
  printf '| 3 | adversarial-review pass 3 | note | TBD |\n'
} >> "$WORK/$LOG"
bash "$VALIDATOR" feature/ts-carveout >"$WORK/ts.txt" 2>&1
rc=$?
if [ "$rc" = "0" ] && grep -q 'EXEMPT (Rule 8 carve-out: convergence series, Check 24)' "$WORK/ts.txt" \
   && grep -q 'Sprint 900 retro .*PASS' "$WORK/ts.txt" && ! grep -q 'FAIL (' "$WORK/ts.txt"; then
  ok "a Test Strategy section with AR-only commits reads EXEMPT, not FAIL (Rule 8 carve-out)"; B_carve=1
else
  bad "the Test Strategy section was not exempted (rc=$rc)"; sed 's/^/        /' "$WORK/ts.txt"
fi

# --- 14. MUTATION: remove the carve-out and the same section FAILs --------------
MUT4="$WORK/mutant-carveout.sh"
sed "s/if label == 'test-strategy':/if False:/" "$VALIDATOR" > "$MUT4" || exit 2
if cmp -s "$VALIDATOR" "$MUT4"; then
  bad "MUTATION: the carve-out predicate was rewritten — assertion 13 is unproven until this sed is updated"
else
  bash "$MUT4" feature/ts-carveout >"$WORK/mut4.txt" 2>&1
  if [ "$?" = "1" ] && grep -q 'test-strategy .*FAIL (missing cycle type: party-mode)' "$WORK/mut4.txt"; then
    cce_twin "$MUT4" valid carve-out &&
    mutant_killed "$B_carve" carve-out "MUTATION: without the carve-out the Test Strategy section FAILs (assertion 13 is real)"
  else
    bad "MUTATION: the Test Strategy section did not FAIL without the carve-out — assertion 13 is vacuous"
    sed 's/^/        /' "$WORK/mut4.txt"
  fi
fi

# THE MATRIX, printed only under --matrix: the unmutated validator (ctl) and every mutant copy on every arm.
if [ "$MATRIX" = 1 ]; then
  # The copies are moved under .git first: an arm switches branches, and a branch whose commit swept this run's
  # untracked files (assertion 13's commit_cycle) takes them out of the work tree when it is left.
  mkdir -p "$WORK/.git/mx"
  for _mx in "log-rows-guard:$MUTANT" "prior-sprint-test:$MUT2" "non-vacuity:$MUT3" "carve-out:$MUT4"; do
    cp -p "${_mx#*:}" "$WORK/.git/mx/${_mx%%:*}.sh" || { bad "MATRIX: ${_mx%%:*} has no copy at ${_mx#*:}"; }
  done
  for _mx in "ctl:$VALIDATOR" "log-rows-guard:$WORK/.git/mx/log-rows-guard.sh" "prior-sprint-test:$WORK/.git/mx/prior-sprint-test.sh" \
             "non-vacuity:$WORK/.git/mx/non-vacuity.sh" "carve-out:$WORK/.git/mx/carve-out.sh"; do
    _m="${_mx%%:*}"; _mv="${_mx#*:}"
    [ -f "$_mv" ] || { bad "MATRIX: $_m has no copy at $_mv"; continue; }
    for _a in $CCE_ARMS; do
      if cce_arm "$_a" "$_mv"; then printf '  MATRIX %s %s GREEN\n' "$_m" "$_a"; else printf '  MATRIX %s %s TRIPPED\n' "$_m" "$_a"; fi
    done
  done
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "cycle-commits-enforce: PASS"
  exit 0
fi
echo "cycle-commits-enforce: FAIL ($fails assertion(s))"
exit 1
