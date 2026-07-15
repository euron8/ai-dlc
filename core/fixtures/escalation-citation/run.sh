#!/usr/bin/env bash
# Proof for validate-escalation-resolution.sh (Check 2 teeth). v0.61.0.
#
# THE 3-STEP PROOF plus the scoping guards that keep it from wedging the gate on legacy data:
#   (a) VACUOUS   only legacy + autonomous entries in scope            -> PASS
#   (b) FAIL      S<N> RESOLVED with NO citation (the S290 shape)      -> FAIL
#   (c) FAIL      S<N> RESOLVED citing words no operator ever typed    -> FAIL
#   (d) PASS      S<N> RESOLVED citing a genuine operator message      -> PASS
#   (e) SKIP      a legacy (prior-sprint) RESOLVED entry               -> not flagged
#   (f) SKIP      DECIDED_AUTONOMOUSLY (honest self-attribution)       -> not flagged
#   (g) CLOSED    a real citation but no transcript to verify against  -> FAIL (gate posture)
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-escalation-resolution.sh" \
  "$DIR/../../../scripts/validate-escalation-resolution.sh" \
  "$DIR/../../core/scripts/validate-escalation-resolution.sh"; do
  [ -f "$cand" ] && VALIDATOR="$cand" && break
done
[ -n "$VALIDATOR" ] || { echo "FAIL: cannot locate validate-escalation-resolution.sh from $DIR"; exit 1; }

ROOT="$(bash "$DIR/seed.sh" | tail -1)"
trap 'rm -rf "$ROOT"' EXIT
FAIL=0; N=0

# $1 pending-file  $2 sprint  $3 transcript-basename (or "")  $4 want-exit  $5 why
g() {
  local f="$1" sp="$2" t="$3" want="$4" why="$5"; N=$((N + 1))
  local args=(--escalations "$ROOT/$f" --sprint "$sp")
  [ -n "$t" ] && args+=(--transcript "$ROOT/$t")
  local out got
  out="$(bash "$VALIDATOR" "${args[@]}" 2>&1)"; got=$?
  if [ "$got" -eq "$want" ]; then printf '  ok   %-22s exit=%s  (%s)\n' "$f/${t:-none}" "$got" "$why"
  else FAIL=$((FAIL + 1)); printf '  FAIL %-22s exit=%s want=%s  (%s)\n' "$f/${t:-none}" "$got" "$want" "$why"; printf '%s\n' "$out" | sed 's/^/       | /'; fi
}
says() {
  local f="$1" sp="$2" t="$3"; shift 3; N=$((N + 1))
  local out miss=""
  out="$(bash "$VALIDATOR" --escalations "$ROOT/$f" --sprint "$sp" --transcript "$ROOT/$t" 2>&1)"
  local w; for w in "$@"; do printf '%s' "$out" | grep -qF -- "$w" || miss="$miss [$w]"; done
  if [ -z "$miss" ]; then printf '  ok   %-22s message names the cause\n' "$f(msg)"
  else FAIL=$((FAIL + 1)); printf '  FAIL %-22s missing:%s\n' "$f(msg)" "$miss"; fi
}

echo "escalation-citation proof (Check 2)"
echo

g pending-clean.md       50 real.jsonl     0 "only legacy + autonomous in scope -> PASS (vacuous)"
g pending-missing.md     50 real.jsonl     1 "S50 RESOLVED, no citation (the S290 shape) -> FAIL"
g pending-fabricated.md  50 real.jsonl     1 "S50 RESOLVED, words no operator typed -> FAIL"
says pending-fabricated.md 50 real.jsonl "appears in NO genuine" "This is the S290 failure"
g pending-real.md        50 real.jsonl     0 "S50 RESOLVED, verified operator citation -> PASS"
g pending-legacy.md      50 real.jsonl     0 "prior-sprint RESOLVED entry out of scope -> SKIP -> PASS"
g pending-autonomous.md  50 real.jsonl     0 "DECIDED_AUTONOMOUSLY needs no citation -> PASS"
g pending-real.md        50 ""             1 "gate fail-closed: real citation but no transcript -> FAIL"

echo
if [ "$FAIL" -gt 0 ]; then echo "FAIL: $FAIL of $N assertions wrong."; exit 1; fi
echo "PASS: all $N assertions correct."
exit 0
