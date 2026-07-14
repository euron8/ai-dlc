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
  for cand in "$HERE/../../scripts" "$HERE/../../../scripts" "$HERE/../../../core/scripts"; do
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
  if bash "$PROV" "$WORK/docs/retro/sprint-$v.md" >/dev/null 2>&1; then
    note "BAD" "sprint-$v.md" "PASSED validate-provenance-block.sh — expected FAIL"
    fails=$((fails + 1))
  else
    note "ok" "sprint-$v.md" "correctly rejected by validate-provenance-block.sh"
  fi
done

# ---- V5 must PASS the lightweight validator -----------------------------------
# This is the assertion that was silently false for the life of the fixture.
if bash "$PROV" "$WORK/docs/retro/sprint-905.md" >/dev/null 2>&1; then
  note "ok" "sprint-905.md" "passes validate-provenance-block.sh (as it must)"
else
  note "BAD" "sprint-905.md" "FAILED validate-provenance-block.sh — the forgery floor is UNTESTED"
  echo
  echo "      V5 must reach validate-retro-evidence.sh to test anything. Failing the" >&2
  echo "      lightweight script first means the byte-match assertion never runs and" >&2
  echo "      H2 reports PASS on a property it never checked. This is exactly the bug" >&2
  echo "      the fixture was rewritten to fix (it used to carry mode: solo)." >&2
  bash "$PROV" "$WORK/docs/retro/sprint-905.md" 2>&1 | sed 's/^/        /' >&2
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
elif printf '%s' "$V6_ERR" | grep -q 'not in the known set'; then
  note "BAD" "s999...-p2.md (V6 solo)" "rejected as an UNKNOWN SKILL, not as solo"
  echo
  echo "      'ai-dlc-adversary-review' is missing from KNOWN_SKILLS. The block failed," >&2
  echo "      but on the WRONG RUNG: the Rule 20 solo assertion never evaluated it. Check" >&2
  echo "      17's only teeth are disarmed for every convergence pass, and the exit code" >&2
  echo "      looks identical to a healthy reject." >&2
  fails=$((fails + 1))
elif printf '%s' "$V6_ERR" | grep -qi 'mode: solo'; then
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
elif printf '%s' "$V8_ERR" | grep -qi 'mode: solo'; then
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
elif printf '%s' "$V9_ERR" | grep -q 'RETIRED PIN'; then
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

# ---- V5 must then FAIL the heavyweight validator on the SHA -------------------
# validate-retro-evidence.sh resolves the cited SHA against git, so the fixture
# needs a real repo with a real retro branch and a real committed transcript.
if [ ! -f "$EVID" ]; then
  note "SKIP" "sprint-905.md" "validate-retro-evidence.sh not found — SHA floor not driven"
  fails=$((fails + 1))
else
  REPO="$WORK/repo"
  mkdir -p "$REPO/_bmad-output/party-mode-transcripts" "$REPO/docs/retro"
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
    } > _bmad-output/party-mode-transcripts/sprint-999-retro.md
    cp "$WORK/docs/retro/sprint-905.md" docs/retro/sprint-999.md
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
