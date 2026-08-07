#!/usr/bin/env bash
# Drive the check-17-bypass fixture against the REAL validators and assert the
# expected pass/fail matrix. Exit 0 = the forgery floor holds.
#
# This is what H2 item (2) re-drives. It replaces an `echo` that described the
# assertions without making them.
#
#   V1..V4  must FAIL validate-provenance-block.sh   (malformed / absent block)
#   V5      must PASS validate-provenance-block.sh   (well-formed block)
#           and FAIL validate-retro-evidence.sh      (SHA does not match the blob)
#
# V5 is the whole point. The lightweight script says so itself: "a motivated forger
# can paste a well-formed block without invoking the Skill." V5 IS that forger. If
# V5 fails the lightweight script for some unrelated reason, the heavyweight
# byte-match assertion is never reached and the floor is untested -- so a V5 that
# fails the FIRST script is a fixture bug, not a pass, and this script says so.
#
# Usage: run.sh [--scripts DIR]
#   --scripts DIR  where the validators live (default: autodetect core/scripts
#                  from the distribution, else ./scripts in a consumer)

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS=""

while [ $# -gt 0 ]; do
  case "$1" in
    --scripts) SCRIPTS="${2:-}"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ -z "$SCRIPTS" ]; then
  # Consumer validators live at scripts/ai-dlc/ since v0.126.0 — that candidate MUST be
  # present, or the fixture cannot self-locate in an installed tree and misreports the
  # miss as "pass --scripts DIR". scripts/ (bare) stays as a pre-relocation fallback.
  for cand in "$HERE/../../scripts" "$HERE/../../../scripts/ai-dlc" "$HERE/../../../scripts" "$HERE/../../../core/scripts"; do
    [ -f "$cand/validate-provenance-block.sh" ] && { SCRIPTS="$(cd "$cand" && pwd)"; break; }
  done
fi
[ -n "$SCRIPTS" ] && [ -f "$SCRIPTS/validate-provenance-block.sh" ] || {
  echo "FAIL: cannot locate validate-provenance-block.sh (pass --scripts DIR)" >&2
  exit 2
}

PROV="$SCRIPTS/validate-provenance-block.sh"
EVID="$SCRIPTS/validate-retro-evidence.sh"

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

bash "$HERE/seed.sh" "$WORK" >/dev/null

fails=0
note() { printf '  %-6s %-44s %s\n' "$1" "$2" "$3"; }

echo "check-17-bypass: driving the real validators"
echo

# ---- V1..V4 must FAIL the lightweight validator -------------------------------
for v in 901 902 903 904; do
  if bash "$PROV" "$WORK/docs/retro/s$v/retro.md" >/dev/null 2>&1; then
    note "BAD" "sprint-$v.md" "PASSED validate-provenance-block.sh — expected FAIL"
    fails=$((fails + 1))
  else
    note "ok" "sprint-$v.md" "correctly rejected by validate-provenance-block.sh"
  fi
done

# ---- V5 must PASS the lightweight validator -----------------------------------
# This is the assertion that was silently false for the life of the fixture.
if bash "$PROV" "$WORK/docs/retro/s905/retro.md" >/dev/null 2>&1; then
  note "ok" "sprint-905.md" "passes validate-provenance-block.sh (as it must)"
else
  note "BAD" "sprint-905.md" "FAILED validate-provenance-block.sh — the forgery floor is UNTESTED"
  echo
  echo "      V5 must reach validate-retro-evidence.sh to test anything. Failing the" >&2
  echo "      lightweight script first means the byte-match assertion never runs and" >&2
  echo "      H2 reports PASS on a property it never checked. This is exactly the bug" >&2
  echo "      the fixture was rewritten to fix (it used to carry mode: solo)." >&2
  bash "$PROV" "$WORK/docs/retro/s905/retro.md" 2>&1 | sed 's/^/        /' >&2
  fails=$((fails + 1))
fi

# ---- V6: solo native review must be rejected BY THE SOLO RUNG -----------------
#
# THE EXIT CODE IS NOT THE ASSERTION. A solo `ai-dlc-adversary-review` block exits
# non-zero under BOTH the correct build and the broken one:
#   name IS in KNOWN_SKILLS  -> rejected by the Rule 20 solo rung   (correct)
#   name is NOT in the enum  -> rejected by "not in the known set"  (broken: the solo
#                               rung never even evaluated, and if `skill:` were made
#                               optional instead, NOTHING would reject it)
# Asserting only `exit != 0` therefore passes on the bug. Assert the MESSAGE.
V6="$WORK/_bmad-output/planning-artifacts/s999-brief-adversarial-p2.md"
V6_ERR="$(bash "$PROV" "$V6" 2>&1)"
V6_RC=$?
if [ "$V6_RC" -eq 0 ]; then
  note "BAD" "s999...-p2.md (V6 solo)" "PASSED — a solo convergence review is unpoliced"
  fails=$((fails + 1))
elif grep -q 'not in the known set' <<<"$V6_ERR"; then
  note "BAD" "s999...-p2.md (V6 solo)" "rejected as an UNKNOWN SKILL, not as solo"
  echo
  echo "      'ai-dlc-adversary-review' is missing from KNOWN_SKILLS. The block failed," >&2
  echo "      but on the WRONG RUNG: the Rule 20 solo assertion never evaluated it. Check" >&2
  echo "      17's only teeth are disarmed for every convergence pass, and the exit code" >&2
  echo "      looks identical to a healthy reject." >&2
  fails=$((fails + 1))
elif grep -qi 'mode: solo' <<<"$V6_ERR"; then
  note "ok" "s999...-p2.md (V6 solo)" "rejected by the Rule 20 solo rung (the right one)"
else
  note "BAD" "s999...-p2.md (V6 solo)" "rejected for an unexpected reason"
  printf '%s\n' "$V6_ERR" | sed 's/^/        /' >&2
  fails=$((fails + 1))
fi

# ---- V7: the honest native review must be ACCEPTED ----------------------------
# This is the enum's mutant-detector: drop ai-dlc-adversary-review from KNOWN_SKILLS
# and V7 goes red, because every real convergence pass would fail Check 17.
V7="$WORK/_bmad-output/planning-artifacts/s999-brief-adversarial-p3.md"
if bash "$PROV" "$V7" >/dev/null 2>&1; then
  note "ok" "s999...-p3.md (V7 native)" "accepted (mode: subagent, no Skill claimed)"
else
  note "BAD" "s999...-p3.md (V7 native)" "REJECTED — the native convergence review is un-gateable"
  bash "$PROV" "$V7" 2>&1 | sed 's/^/        /' >&2
  fails=$((fails + 1))
fi

# ---- V8: mode: solo with NO skill field must still be rejected AS SOLO --------
# The decoupling's only witness. Restore the `skill in KNOWN_SKILLS and` guard on the
# solo rung and this block still exits 1 (missing required field) -- but the solo rung
# never fires, and a schema that drops `skill:` would walk straight through Check 17.
V8="$WORK/_bmad-output/planning-artifacts/s999-brief-adversarial-p4.md"
V8_ERR="$(bash "$PROV" "$V8" 2>&1)"
if [ $? -eq 0 ]; then
  note "BAD" "s999...-p4.md (V8 solo)" "PASSED — solo is unpoliced without a skill field"
  fails=$((fails + 1))
elif grep -qi 'mode: solo' <<<"$V8_ERR"; then
  note "ok" "s999...-p4.md (V8 solo)" "rejected AS SOLO even with no skill: field"
else
  note "BAD" "s999...-p4.md (V8 solo)" "rejected, but NOT on the solo rung"
  echo
  echo "      The Rule 20 solo assertion is gated on enum membership again. A block with" >&2
  echo "      no 'skill:' field can carry mode: solo and never be seen by it. That is the" >&2
  echo "      check-cannot-fire shape: it exits 1 today only because a DIFFERENT rung" >&2
  echo "      caught the missing field." >&2
  printf '%s\n' "$V8_ERR" | sed 's/^/        /' >&2
  fails=$((fails + 1))
fi

# ---- V9: a retired --require-skill pin must SAY SO, not just fail -------------
# The consumer migration mechanism. Without the retired-pin branch this still exits 1 --
# on the generic "no block cites that skill" -- which is true, useless, and fires
# mid-sprint on a consumer's first story. Assert the message carries the repair.
V9="$WORK/_bmad-output/planning-artifacts/s999-story-1.md"
V9_ERR="$(bash "$PROV" "$V9" --require-skill bmad-review-adversarial-general 2>&1)"
if [ $? -eq 0 ]; then
  note "BAD" "s999-story-1.md (V9 pin)" "PASSED — a retired pin certified a story it never checked"
  fails=$((fails + 1))
elif grep -q 'RETIRED PIN' <<<"$V9_ERR"; then
  note "ok" "s999-story-1.md (V9 pin)" "names the retired pin and the repair"
else
  note "BAD" "s999-story-1.md (V9 pin)" "fails, but does not name the retired pin"
  echo "      A consumer hits this mid-sprint. 'no block cites that skill' does not tell" >&2
  echo "      them the cycle went native in v0.58.0 or which flag to change." >&2
  fails=$((fails + 1))
fi
# ...and the correct pin must PASS, or the migration has no destination.
if bash "$PROV" "$V9" --require-skill ai-dlc-adversary-review >/dev/null 2>&1; then
  note "ok" "s999-story-1.md (V9 pin)" "the repointed pin passes"
else
  note "BAD" "s999-story-1.md (V9 pin)" "the repointed pin FAILS — there is nowhere to migrate to"
  fails=$((fails + 1))
fi

# ---- V10: an UPSTREAM RENAME must not invalidate what was stamped before it ----
# `bmad-validate-prd` was consolidated into `bmad-prd`'s validate intent and now ships as a
# deprecated shim. Repointing Check 17's PRD pin to the current name would, on its own, fail
# every PRD stamped before the rename — 74 such blocks on the reference consumer, each a
# correct record of a correct run. The schema's `superseded_skills` records that the two names
# denote ONE evaluation, and the pin accepts either, in both directions.
#
# Deliberately distinct from V9 above. That is a WRONG PIN, diagnosed; this is the SAME
# evaluation under two release names, accepted. Conflating them would make the retired-pin
# diagnostic unreachable, so both assertions live here side by side.
V10D="$WORK/_bmad-output/planning-artifacts"
mk_prd_block() { # $1 file  $2 skill
  cat > "$1" <<EOF
# PRD (V10 rename case)

<!-- SKILL_INVOCATION_PROVENANCE v1
skill: $2
invoked_at: 2026-01-02T03:04:05Z
tool_use_id: toolu_FIXTUREaaaaaaaa
mode: subagent
lead_role: pm
artifact: $(basename "$1")
findings_critical: 0
findings_major: 1
findings_minor: 2
SKILL_INVOCATION_PROVENANCE_END -->
EOF
}
mk_prd_block "$V10D/v10-old-prd.md" bmad-validate-prd
mk_prd_block "$V10D/v10-new-prd.md" bmad-prd
mk_prd_block "$V10D/v10-other-prd.md" bmad-party-mode

if bash "$PROV" "$V10D/v10-old-prd.md" --require-skill bmad-prd >/dev/null 2>&1; then
  note "ok" "v10-old-prd.md" "a block stamped before the rename satisfies a pin on the current name"
else
  note "BAD" "v10-old-prd.md" "repointing the pin invalidated every PRD stamped before the rename"
  fails=$((fails + 1))
fi
if bash "$PROV" "$V10D/v10-new-prd.md" --require-skill bmad-validate-prd >/dev/null 2>&1; then
  note "ok" "v10-new-prd.md" "a consumer override still pinning the old name accepts a current block"
else
  note "BAD" "v10-new-prd.md" "a consumer whose override pins the old name fails on a correct run"
  fails=$((fails + 1))
fi
# THE PRECISION SIDE. Without it the two assertions above would also pass against a pin that
# accepted anything, and the pin would be decoration.
if bash "$PROV" "$V10D/v10-other-prd.md" --require-skill bmad-prd >/dev/null 2>&1; then
  note "BAD" "v10-other-prd.md" "an UNRELATED skill satisfied the pin — the acceptance is blanket, not a rename"
  fails=$((fails + 1))
else
  note "ok" "v10-other-prd.md" "an unrelated skill still fails the pin (the acceptance is the rename, not everything)"
fi

# ---- V5 must then FAIL the heavyweight validator on the SHA -------------------
# validate-retro-evidence.sh resolves the cited SHA against git, so the fixture
# needs a real repo with a real retro branch and a real committed transcript.
if [ ! -f "$EVID" ]; then
  note "SKIP" "sprint-905.md" "validate-retro-evidence.sh not found — SHA floor not driven"
  fails=$((fails + 1))
else
  REPO="$WORK/repo"
  mkdir -p "$REPO/_bmad-output/party-mode-transcripts/s999" "$REPO/docs/retro"
  (
    cd "$REPO"
    git init -q .
    git config user.email fixture@ai-dlc.local
    git config user.name  "check-17-bypass fixture"
    git commit -q --allow-empty -m "base"
    git branch -M main

    git checkout -q -b ai-dlc/retro/sprint-999
    # A real, non-trivial transcript, committed to the retro branch.
    {
      echo "# Sprint 999 Retro — Party Mode Transcript"
      echo
      for p in "PM" "Architect" "Dev" "SM" "TEA" "QA"; do
        echo "## $p"
        echo "Discovery / Implementation / Retrospective notes from $p."
        printf 'Detail line for %s.\n%.0s' "$p" $(seq 1 40)
        echo
      done
    } > _bmad-output/party-mode-transcripts/s999/retro.md
    mkdir -p docs/retro/s999 && cp "$WORK/docs/retro/s905/retro.md" docs/retro/s999/retro.md
    git add -A
    git commit -q -m "Sprint 999 retro party-mode transcript"
  ) >/dev/null 2>&1

  # The retro doc cites @deadbee, which names no blob in this repo.
  if ( cd "$REPO" && bash "$EVID" ai-dlc/retro/sprint-999 999 >/dev/null 2>&1 ); then
    note "BAD" "sprint-999 (git)" "validate-retro-evidence.sh PASSED a fabricated SHA"
    fails=$((fails + 1))
  else
    note "ok" "sprint-999 (git)" "fabricated SHA rejected by validate-retro-evidence.sh"
  fi

  # ---- Origin-only ref resolution — the CI checkout condition ----------------
  # CI runners (GitHub Actions) fetch refs into origin/* and keep NO local branch
  # per ref, so a plain branch name fed to `git ls-tree` resolved nothing and the
  # transcript read as "not committed" — a false COMMIT_MISSING with nothing to do
  # with the retro. Reproduce it exactly: clone so the retro branch exists ONLY as
  # origin/ai-dlc/retro/sprint-999, then run with the plain name. The retro cites
  # @deadbee, so it FAILS overall either way; the tell is Marker 2 — did ls-tree
  # find the transcript ON the branch? "transcript committed: OK" iff resolution
  # reached origin/<name>.
  # $REPO's HEAD sits on the retro branch, so a plain `git clone` would create a
  # LOCAL ai-dlc/retro/sprint-999 and defeat the whole premise. Detach and delete
  # it, leaving the branch reachable ONLY as origin/ai-dlc/retro/sprint-999 — the
  # exact CI condition. The mutation control below is what caught this.
  CLONE="$WORK/retro-clone"
  git clone -q "$REPO" "$CLONE" >/dev/null 2>&1
  (
    cd "$CLONE"
    git checkout -q --detach
    git branch -D ai-dlc/retro/sprint-999
  ) >/dev/null 2>&1
  NEW_OUT="$( cd "$CLONE" && bash "$EVID" ai-dlc/retro/sprint-999 999 2>&1 )"
  if grep -Eq 'transcript committed.*: OK' <<<"$NEW_OUT"; then
    note "ok" "sprint-999 (origin-only)" "retro branch resolves via origin/<name> (ls-tree found the transcript)"
  else
    note "BAD" "sprint-999 (origin-only)" "the origin-only branch did NOT resolve — the CI-checkout bug is back"
    fails=$((fails + 1))
  fi

  # Fail-fast: a branch that resolves NEITHER locally NOR as origin/ must fail
  # immediately, naming both refs it tried — not die opaquely in merge-base later.
  FF_OUT="$( cd "$CLONE" && bash "$EVID" no-such-retro-branch 999 2>&1 )"
  if grep -Eq 'not found — tried: no-such-retro-branch, origin/no-such-retro-branch' <<<"$FF_OUT"; then
    note "ok" "fail-fast" "an unresolvable branch fails fast, naming both refs tried"
  else
    note "BAD" "fail-fast" "an unresolvable branch did not fail-fast naming both refs"
    fails=$((fails + 1))
  fi

  # MUTATION control: revert the resolution to the old verbatim-name behaviour
  # (retro_branch stays the plain name) and require the origin-only branch to STOP
  # resolving — Marker 2 must flip to FAIL. A pass above is evidence for the
  # resolution only if removing it removes the pass.
  MUT="$WORK/retro-evidence.mutant.sh"
  sed 's/^retro_branch = _resolved$/retro_branch = retro_branch  # MUTANT: keep the unresolved name/' "$EVID" > "$MUT"
  if cmp -s "$EVID" "$MUT"; then
    note "BAD" "sprint-999 (origin-only)" "MUTATION matched nothing — the resolution reassignment was renamed"
    fails=$((fails + 1))
  else
    MUT_OUT="$( cd "$CLONE" && bash "$MUT" ai-dlc/retro/sprint-999 999 2>&1 )"
    if grep -Eq 'transcript committed.*: FAIL' <<<"$MUT_OUT"; then
      note "ok" "sprint-999 (origin-only)" "MUTATION — without resolution the origin-only branch is unresolved (ls-tree FAIL)"
    else
      note "BAD" "sprint-999 (origin-only)" "MUTATION — the branch resolved with resolution disabled; the assertion proves nothing"
      fails=$((fails + 1))
    fi
  fi
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "PASS  check-17-bypass: V1-V4 rejected, V5 passes the lightweight script and is"
  echo "      caught by the SHA byte-match, V6 is rejected ON THE SOLO RUNG and V7 (the"
  echo "      honest native review) is accepted. The forgery floor holds."
  exit 0
fi
echo "FAIL  check-17-bypass: $fails assertion(s) violated." >&2
exit 1
