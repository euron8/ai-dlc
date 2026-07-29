#!/usr/bin/env bash
# Proof for the operator-CITATION gate (validate-adversarial-convergence.sh arm F6). v0.61.0.
#
# THE 3-STEP PROOF (this repo's discipline: a new check must be shown to pass vacuously, fail
# on the real defect, and pass once the defect is fixed -- a green run otherwise proves only
# that the check cannot fire):
#
#   (a) VACUOUS   a converging cycle never reaches the citation gate     -> PASS
#   (b) FAIL      the S290 shape: a resolution citing words absent from
#                 an operator-silent transcript                          -> FAIL CLOSED
#   (c) PASS      the same series with a genuine operator turn present    -> PASS
#
# Plus two things a bare 3-step proof would miss:
#   (d) GUARD     the quoted span exists only inside a tool_result -- the classifier reuse
#                 (not a naive grep of the file) is load-bearing          -> FAIL
#   (e) TWO-TIER  the hook fails OPEN on a missing transcript (never wedge) but LOGS it; the
#                 gate fails CLOSED. And when a transcript IS present, the hook denies a
#                 fabricated citation too.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-adversarial-convergence.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-adversarial-convergence.sh" \
  "$DIR/../../core/scripts/validate-adversarial-convergence.sh"; do
  [ -f "$cand" ] && VALIDATOR="$cand" && break
done
[ -n "$VALIDATOR" ] || { echo "FAIL: cannot locate validate-adversarial-convergence.sh from $DIR"; exit 1; }

ROOT="$(bash "$DIR/seed.sh" | tail -1)"
trap 'rm -rf "$ROOT"' EXIT
FAIL=0; N=0

# gate-mode exit-code assertion. $1 case  $2 want-exit  $3 why  $4 (optional) transcript basename
g() {
  local c="$1" want="$2" why="$3" t="${4:-}"; N=$((N + 1))
  local args=(--series "$ROOT/$c/s-adversarial-p")
  [ -n "$t" ] && args+=(--transcript "$ROOT/$t")
  local out got
  out="$(bash "$VALIDATOR" "${args[@]}" 2>&1)"; got=$?
  if [ "$got" -eq "$want" ]; then
    printf '  ok   %-30s exit=%s  (%s)\n' "$c/${t:-none}" "$got" "$why"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL %-30s exit=%s want=%s  (%s)\n' "$c/${t:-none}" "$got" "$want" "$why"
    printf '%s\n' "$out" | sed 's/^/       | /'
  fi
}

# message assertion. $1 case  $2 transcript  $3... required substrings
says() {
  local c="$1" t="$2"; shift 2; N=$((N + 1))
  local out miss=""
  out="$(bash "$VALIDATOR" --series "$ROOT/$c/s-adversarial-p" --transcript "$ROOT/$t" 2>&1)"
  local w; for w in "$@"; do grep -qF -- "$w" <<<"$out" || miss="$miss [$w]"; done
  if [ -z "$miss" ]; then printf '  ok   %-30s message names the cause\n' "$c(msg)"
  else FAIL=$((FAIL + 1)); printf '  FAIL %-30s missing:%s\n' "$c(msg)" "$miss"; fi
}

# cycle-state (hook) assertion. $1 case  $2 want-state  $3 want-rc  $4 why  $5 (optional) transcript
st() {
  local c="$1" ws="$2" wr="$3" why="$4" t="${5:-}"; N=$((N + 1))
  local args=(--series "$ROOT/$c/s-adversarial-p" --cycle-state)
  [ -n "$t" ] && args+=(--transcript "$ROOT/$t")
  local out rc s
  out="$(bash "$VALIDATOR" "${args[@]}" 2>/dev/null)"; rc=$?
  s="$(printf '%s' "$out" | cut -f1)"
  if [ "$s" = "$ws" ] && [ "$rc" -eq "$wr" ]; then
    printf '  ok   %-30s %s/%s  (%s)\n' "$c/${t:-none}" "$s" "$rc" "$why"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL %-30s %s/%s want=%s/%s  (%s)\n' "$c/${t:-none}" "${s:-<none>}" "$rc" "$ws" "$wr" "$why"
  fi
}

# stderr-marker assertion: the fail-open path must LEAVE A TRACE, or a silent fail-open is
# indistinguishable from a verified pass -- the exact defect class this whole change is about.
logs() {
  local c="$1" mark="$2"; N=$((N + 1))
  local err
  err="$(bash "$VALIDATOR" --series "$ROOT/$c/s-adversarial-p" --cycle-state 2>&1 >/dev/null)"
  if grep -qF -- "$mark" <<<"$err"; then printf '  ok   %-30s logs %s\n' "$c" "$mark"
  else FAIL=$((FAIL + 1)); printf '  FAIL %-30s did NOT log %s\n' "$c" "$mark"; fi
}

echo "adversarial-citation proof (arm F6)"
echo

# (a) VACUOUS -----------------------------------------------------------------------------
g clean 0 "no divergence: citation gate dormant" silent.jsonl

# (b) FAIL (the S290 shape) ----------------------------------------------------------------
g    resolved 1 "cited words absent from an operator-silent transcript -> FAIL CLOSED" silent.jsonl
says resolved silent.jsonl "appears in NO genuine" "operator did not say this"

# (c) PASS --------------------------------------------------------------------------------
g resolved 0 "cited words verbatim in a genuine operator turn -> PASS" real.jsonl

# (d) GUARD: classifier reuse, not a naive grep -------------------------------------------
g resolved 1 "phrase only inside a tool_result -> classifier rejects -> FAIL" toolresult.jsonl

# (e) TWO-TIER ----------------------------------------------------------------------------
# hook, transcript present: a fabricated citation is denied at the hook too (not just the gate)
st terminal DIVERGENT 3 "hook denies: NOMATCH -> not RESOLVED" silent.jsonl
st terminal RESOLVED  0 "hook allows: real citation -> RESOLVED"   real.jsonl
# hook, no transcript: fail OPEN (never wedge the pipeline) but LOG the gap
st   terminal RESOLVED 0 "fail-open: no transcript -> allow"
logs terminal ADVERSARIAL_CITATION_UNVERIFIABLE
# gate, no transcript: fail CLOSED
g    resolved 1 "gate fail-closed: no transcript to verify against"

echo
if [ "$FAIL" -gt 0 ]; then
  echo "FAIL: $FAIL of $N assertions wrong."
  exit 1
fi
echo "PASS: all $N assertions correct."
exit 0
