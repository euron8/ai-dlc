#!/usr/bin/env bash
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
set -uo pipefail

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
  ok "2 log rows (< 3) fails"
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
  ok "MUTATION: disabling the log-rows guard makes the 2-row input pass (FAIL was real)"
else
  bad "MUTATION: the 2-row input still failed without the guard"; sed 's/^/        /' "$WORK/mut.txt"
fi

# --- 4. Check 2 delegation ENGAGES when the log is present --------------------
write_log 3
if [ -f "$VMR" ]; then
  VOUT="$(bash "$VMR" 900 2>/dev/null || true)"
  if grep -q 'CHECK 2: PASS' <<<"$VOUT"; then
    ok "mandatory-rules Check 2 delegates to the validator and PASSes with a log present"
  else
    bad "Check 2 did not engage the validator with a log present"
    echo "$VOUT" | grep -i 'check 2' | sed 's/^/        /'
  fi

# --- 5. Check 2 SKIPs (never fails) when the producer is absent ---------------
  rm -f "$WORK/$LOG"
  VOUT="$(bash "$VMR" 900 2>/dev/null || true)"
  if grep -q 'CHECK 2: SKIP' <<<"$VOUT"; then
    ok "mandatory-rules Check 2 SKIPs when no validation-cycle-log.md (log-keyed opt-in)"
  else
    bad "Check 2 did not SKIP on a missing log"
    echo "$VOUT" | grep -i 'check 2' | sed 's/^/        /'
  fi
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
  ok "a prior sprint's unreachable SHAs report UNVERIFIABLE and do not fail the current sprint"
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
    ok "MUTATION: without the prior-sprint test, dead SHAs fail the run again (assertion 6 is real)"
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
  ok "a log with only PRIOR-sprint sections exits 4 (NOTHING MEASURED), never a bare PASS"
else
  bad "an all-exempted run still reported a pass (rc=$rc)"; sed 's/^/        /' "$WORK/vac.txt"
fi

# --- 9b. The 4 REACHES THE GATE. This is why it is an exit code and not a worklist line ----
# Check 2 captures this script's output into a variable, prints `CHECK 2: PASS` on exit 0 and
# never prints the capture. A worklist at exit 0 would be invisible at the only place the
# verdict is consumed. Assert the wedge is real and visible, because choosing to wedge a
# dormant-log consumer is the load-bearing half of that decision.
if [ -f "$VMR" ]; then
  # 2>&1, unlike the arms above: mandatory-rules prints its per-check verdict on stdout and
  # accumulates the DETAIL into FAILURE_MSGS, which it dumps to stderr at the end. Reading
  # only stdout would score a bare `CHECK 2: FAIL` as full disclosure.
  VOUT="$(bash "$VMR" 900 2>&1 || true)"
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
    ok "MUTATION: without the arm, the all-exempted log prints the old bare PASS (the 4 was real)"
  else
    bad "MUTATION: the all-exempted log did not pass without the arm — assertion 9 is vacuous"
    sed 's/^/        /' "$WORK/mut3.txt"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "cycle-commits-enforce: PASS"
  exit 0
fi
echo "cycle-commits-enforce: FAIL ($fails assertion(s))"
exit 1
