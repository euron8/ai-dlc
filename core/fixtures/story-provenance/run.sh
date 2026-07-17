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
  "$DIR/../../../scripts/stamp-story-provenance.sh" \
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

echo "  ---- $ASSERTIONS assertions, $FAILURES failing ----"
[ "$FAILURES" -eq 0 ]
