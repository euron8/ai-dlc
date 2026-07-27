#!/usr/bin/env bash
# Exercise stamp-story-provenance.sh (writer + --check) against the story-provenance fixture.
#
# Exit 0 iff every seeded case behaves correctly. This fixture is the teeth of Check 17's
# story-provenance cross-check: the story-file terminal residue used to be hand-transcribed "per
# precedent" and drifted (one sprint with artifact_sha, one without, free-text comments the parser
# ignores). The writer makes the write side mechanical; this fixture proves the check FIRES on the
# drift, PASSES on a mechanical stamp, is idempotent, refuses a placeholder tool_use_id, and
# refuses to stamp an unconverged cycle.
#
# WHERE EXIT CODES COINCIDE, ASSERT ON THE MESSAGE (this repo's own rule — a check that cannot
# fire reads exactly like one that passed). The refuse-placeholder and refuse-unconverged cases
# both exit 1, as does the drift case; each asserts the DISTINGUISHING message.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

WRITER=""
for cand in \
  "$DIR/../../scripts/stamp-story-provenance.sh" \
  "$DIR/../../../scripts/ai-dlc/stamp-story-provenance.sh" \
  "$DIR/../../core/scripts/stamp-story-provenance.sh"; do
  [ -f "$cand" ] && WRITER="$cand" && break
done
if [ -z "$WRITER" ]; then
  echo "FAIL: cannot locate stamp-story-provenance.sh from $DIR"
  exit 1
fi

ROOT="$(bash "$DIR/seed.sh" | tail -1)"
trap 'rm -rf "$ROOT"' EXIT

REAL_TID="toolu_FIXTUREaaaaaaaa"
FAILURES=0
ASSERTIONS=0

# $1 label  $2 want-exit  $3 want-substring (or "")  then command...
expect() {
  local label="$1" want="$2" needle="$3"; shift 3
  local out got
  ASSERTIONS=$((ASSERTIONS + 1))
  out="$("$@" 2>&1)"; got=$?
  local ok=1
  [ "$got" -eq "$want" ] || ok=0
  if [ -n "$needle" ] && ! printf '%s' "$out" | grep -qF "$needle"; then ok=0; fi
  if [ "$ok" -eq 1 ]; then
    printf '  ok    %-46s exit=%s\n' "$label" "$got"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-46s exit=%s want=%s needle=%q\n' "$label" "$got" "$want" "$needle"
    printf '        out: %s\n' "$(printf '%s' "$out" | tr '\n' ' ' | cut -c1-200)"
  fi
}

C="$ROOT/converged"

# 1. --check on the pre-stamp stories (one missing block, one drifted) MUST report DRIFT.
expect "converged: --check pre-stamp = DRIFT" 1 "DRIFT" \
  bash "$WRITER" --series "$C/s1-stories-adversarial" --check "$C/stories/story-1.md" "$C/stories/story-2.md"

# 2. Stamp for real.
expect "converged: stamp" 0 "stamped 2 of 2" \
  bash "$WRITER" --series "$C/s1-stories-adversarial" "$C/stories/story-1.md" "$C/stories/story-2.md"

# 3. --check now passes (mechanical block matches; idempotent).
expect "converged: --check post-stamp = OK" 0 "OK" \
  bash "$WRITER" --series "$C/s1-stories-adversarial" --check "$C/stories/story-1.md" "$C/stories/story-2.md"

# 4. Re-stamp writes nothing (idempotent).
expect "converged: re-stamp idempotent" 0 "stamped 0 of 2" \
  bash "$WRITER" --series "$C/s1-stories-adversarial" "$C/stories/story-1.md" "$C/stories/story-2.md"

# 5. MUTANT: tamper a field in a stamped block -> --check MUST fail. Proves the check is not vacuous.
sed -i.bak 's/^findings_minor: 2/findings_minor: 9/' "$C/stories/story-1.md"
expect "converged: tampered block = DRIFT" 1 "DRIFT" \
  bash "$WRITER" --series "$C/s1-stories-adversarial" --check "$C/stories/story-1.md"
mv "$C/stories/story-1.md.bak" "$C/stories/story-1.md"

# 6. MUTANT: tamper the story BODY after stamping -> artifact_sha goes stale -> --check MUST fail.
printf '\nedited after stamping.\n' >> "$C/stories/story-2.md"
expect "converged: stale artifact_sha = DRIFT" 1 "DRIFT" \
  bash "$WRITER" --series "$C/s1-stories-adversarial" --check "$C/stories/story-2.md"

P="$ROOT/placeholder"

# 7. Placeholder terminal tool_use_id, NO override -> REFUSE (not a valid toolu_ id).
expect "placeholder: refuse without override" 1 "not a valid toolu_ id" \
  bash "$WRITER" --series "$P/s1-stories-adversarial" "$P/stories/story-1.md"

# 8. Placeholder terminal + --tool-use-id -> stamps AND backfills the SoR.
expect "placeholder: stamp+backfill with override" 0 "backfilled tool_use_id" \
  bash "$WRITER" --series "$P/s1-stories-adversarial" --tool-use-id "$REAL_TID" "$P/stories/story-1.md"

# 9. After backfill, --check runs override-free (SoR now holds the real id).
expect "placeholder: --check override-free post-backfill = OK" 0 "OK" \
  bash "$WRITER" --series "$P/s1-stories-adversarial" --check "$P/stories/story-1.md"

# 10. MUTANT: a garbage override is refused, not accepted.
expect "placeholder: garbage override refused" 1 "not a valid toolu_ id" \
  bash "$WRITER" --series "$P/s1-stories-adversarial" --tool-use-id "nope" "$P/stories/story-1.md"

U="$ROOT/unconverged"

# 11. SAFETY: terminal verdict is not EXIT_CONDITION_MET -> refuse to stamp.
expect "unconverged: refuse to stamp" 1 "not EXIT_CONDITION_MET" \
  bash "$WRITER" --series "$U/s1-stories-adversarial" "$U/stories/story-1.md"

O="$ROOT/oneshot"

# --- The bug variant. A ONE-SHOT stamps no verdict and cites the bmad skill, so the default
# profile refuses it by construction and nothing else writes a block onto a bug story. Two
# consecutive bug-variant stories shipped with none. Assertions 12-17 are the two doors and the
# proof that neither opens the other.

# 12. THE DEFECT: the default profile cannot stamp a bug story at all.
expect "oneshot: default profile refuses the bmad skill" 1 "expected 'ai-dlc-adversary-review'" \
  bash "$WRITER" --terminal "$O/s1-bug-fix-oneshot.md" "$O/stories/story-bug-1.md"

# 13. --check before the stamp is DRIFT (a bug story with no block is not silently fine).
expect "oneshot: --check pre-stamp = DRIFT" 1 "DRIFT" \
  bash "$WRITER" --terminal "$O/s1-bug-fix-oneshot.md" --profile bug-story-provenance --check \
    "$O/stories/story-bug-1.md"

# 14. Stamp with the bug profile. The summary must NOT print a bare `None` where the verdict
#     would be: a field the producer is forbidden to write reads as a parse failure otherwise.
expect "oneshot: stamp under the bug profile" 0 "one-shot, no verdict" \
  bash "$WRITER" --terminal "$O/s1-bug-fix-oneshot.md" --profile bug-story-provenance \
    "$O/stories/story-bug-1.md"

# 15. --check now passes, and the block cites the skill Check 17's bug arm requires.
expect "oneshot: --check post-stamp = OK" 0 "OK" \
  bash "$WRITER" --terminal "$O/s1-bug-fix-oneshot.md" --profile bug-story-provenance --check \
    "$O/stories/story-bug-1.md"
ASSERTIONS=$((ASSERTIONS + 1))
if grep -q '^skill: bmad-review-adversarial-general$' "$O/stories/story-bug-1.md" \
   && ! grep -q '^verdict:' "$O/stories/story-bug-1.md"; then
  printf '  ok    %-46s\n' "oneshot: block cites the bmad skill, no verdict"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-46s\n' "oneshot: block cites the bmad skill, no verdict"
fi

# 16. THE REVERSE DOOR. A convergence pass carrying the one-shot's skill name must still be
#     refused by the one-shot profile — on the VERDICT rule, not the skill pin. Without this the
#     bug profile would be a hole through which an unconverged cycle reaches a story with its
#     verdict silently dropped.
expect "oneshot: verdict-bearing pass refused" 1 "must carry no verdict" \
  bash "$WRITER" --terminal "$O/s1-bug-fix-oneshot-with-verdict.md" --profile bug-story-provenance \
    "$O/stories/story-bug-1.md"

# 17. An unknown profile is a usage error, not a silent fall-back to the default.
expect "unknown profile is refused (exit 2)" 2 "is not a profile in the schema" \
  bash "$WRITER" --terminal "$O/s1-bug-fix-oneshot.md" --profile no-such-profile \
    "$O/stories/story-bug-1.md"

# 18. MUTATION — the verdict rule is DERIVED from the profile, so deleting `verdict` from the
#     CONVERGENCE profile's batch_invariant must turn assertion 11 (refuse-unconverged) into a
#     pass-through. Mutating the SCHEMA rather than the script is the point: it proves the guard
#     reads the profile and is not a constant the script happens to agree with.
# ASK THE WRITER where its schema is; never walk up from it. The install mapping SPLITS the
# two — core/scripts/<x> lands at <root>/scripts/ai-dlc/<x> while core/schemas/ lands at
# <root>/.claude/schemas/ — so "../schemas" and "../../schemas" are both right in the
# distribution and both wrong on every consumer. This fixture already resolves the WRITER
# through a chain that names the consumer path; the schema lookup was a private second copy of
# a derivation the writer owns, and it made the fixture red on every consumer while staying
# green here. Step 2 requires the derived fixtures green BEFORE the push, so that red was a
# permanent stop on the self-update, not a nuisance.
SCHEMA_SRC="$(bash "$WRITER" --print-schema 2>/dev/null)"
MUTROOT="$ROOT/mut"; mkdir -p "$MUTROOT/scripts" "$MUTROOT/schemas"
cp "$WRITER" "$MUTROOT/scripts/stamp-story-provenance.sh"
ASSERTIONS=$((ASSERTIONS + 1))
if [ ! -f "$SCHEMA_SRC" ]; then
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-46s\n' "FIXTURE BROKEN: writer --print-schema resolved nothing (got: ${SCHEMA_SRC:-<empty>})"
else
  # The subject: a CONVERGENCE pass (right skill) carrying NO verdict at all, and a fresh story.
  # Under the real schema `verdict` is batch-invariant, so its absence is not EXIT_CONDITION_MET
  # and the writer refuses. Under the mutant the profile has become a one-shot profile, no verdict
  # is present to object to, and the stamp goes through — which is the derived behaviour under test.
  grep -v '^verdict:' "$C/s1-stories-adversarial-p2.md" > "$MUTROOT/noverdict-p1.md"
  mk_mut_story() { printf '# Story mut\n\n## Acceptance Criteria\n- AC(a): thing.\n' > "$MUTROOT/story-mut.md"; }
  mut_run() { # -> the writer's output, resolving the schema from $MUTROOT/schemas/
    mk_mut_story
    bash "$MUTROOT/scripts/stamp-story-provenance.sh" \
      --terminal "$MUTROOT/noverdict-p1.md" "$MUTROOT/story-mut.md" 2>&1
  }
  # CONTROL — the same writer, the same tree, the UNMUTATED schema. It must still refuse, or the
  # harness itself is what kills the guard and the mutant below proves nothing.
  cp "$SCHEMA_SRC" "$MUTROOT/schemas/provenance-block.json"
  ctl="$(mut_run)"
  # MUTANT — drop `verdict` from the CONVERGENCE profile's batch_invariant and nothing else.
  python3 - "$SCHEMA_SRC" "$MUTROOT/schemas/provenance-block.json" <<'PY'
import json, sys
s = json.load(open(sys.argv[1]))
p = s["profiles"]["story-provenance"]
p["batch_invariant"] = [f for f in p["batch_invariant"] if f != "verdict"]
json.dump(s, open(sys.argv[2], "w"), indent=2)
PY
  mut="$(mut_run)"

  if ! printf '%s' "$ctl" | grep -qF "not EXIT_CONDITION_MET"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-46s\n' "FIXTURE BROKEN: control run does not refuse"
    printf '        out: %s\n' "$(printf '%s' "$ctl" | tr '\n' ' ' | cut -c1-160)"
  elif printf '%s' "$mut" | grep -qF "not EXIT_CONDITION_MET"; then
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-46s\n' "mutation: schema mutant had no effect"
  elif ! printf '%s' "$mut" | grep -qF "stamped 1 of 1"; then
    # Absence of the refusal is not a kill on its own — the run could have died for an unrelated
    # reason. The kill is the guard letting an UNCONVERGED pass through to a real stamp.
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-46s\n' "mutation: mutant neither refused nor stamped"
    printf '        out: %s\n' "$(printf '%s' "$mut" | tr '\n' ' ' | cut -c1-160)"
  else
    printf '  ok    %-46s\n' "mutation: dropping verdict from the profile disarms the guard"
  fi
fi

echo "  ---- $ASSERTIONS assertions, $FAILURES failing ----"
[ "$FAILURES" -eq 0 ]
