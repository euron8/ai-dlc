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
#
# THE CROSS-SESSION ARM. A sprint spans sessions and `transcript_path` names the session ASKING
# permission, never the one the operator spoke in, so a single-file check rejects adjudications
# that really happened -- and it fails CLOSED, so the rejection is reported as the S290
# fabrication. Measured on the reference consumer: 4 of 4 operator-resolved HARD_BLOCKs rejected,
# all four quotes present in the corpus.
#   (h) DEFECT    genuine citation, gate names the wrong session        -> FAIL
#   (i) FIXED     the same citation, verified over the corpus           -> PASS
#   (j) CONTROL   a fabrication, over the same corpus                   -> FAIL (no fail-open)
#   (k) ORDER     both flags: the corpus wins over the named file       -> PASS
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-escalation-resolution.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-escalation-resolution.sh" \
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
  local w; for w in "$@"; do grep -qF -- "$w" <<<"$out" || miss="$miss [$w]"; done
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

# --- the cross-session corpus arm -----------------------------------------------------------
# $1 pending  $2 sprint  $3 dir-or-""  $4 single-transcript-or-""  $5 want-exit  $6 why
# $7 optional validator override, so the mutants below reuse exactly these assertions.
gx() {
  local f="$1" sp="$2" d="$3" t="$4" want="$5" why="$6" v="${7:-$VALIDATOR}"; N=$((N + 1))
  local args=(--escalations "$ROOT/$f" --sprint "$sp")
  [ -n "$t" ] && args+=(--transcript "$ROOT/$t")
  [ -n "$d" ] && args+=(--transcript-dir "$ROOT/$d")
  local out got
  out="$(bash "$v" "${args[@]}" 2>&1)"; got=$?
  if [ "$got" -eq "$want" ]; then printf '  ok   %-26s exit=%s  (%s)\n' "$f" "$got" "$why"; return 0
  else FAIL=$((FAIL + 1)); printf '  FAIL %-26s exit=%s want=%s  (%s)\n' "$f" "$got" "$want" "$why"; printf '%s\n' "$out" | sed 's/^/       | /'; return 1; fi
}

echo
gx pending-crosssession.md 50 ""      corpus/gate.jsonl 1 "(h) genuine adjudication, wrong session named -> FAIL"
gx pending-crosssession.md 50 corpus  ""                0 "(i) same citation, verified over the corpus -> PASS"
gx pending-crossfake.md    50 corpus  ""                1 "(j) fabrication over the same corpus -> FAIL (teeth intact)"
gx pending-crosssession.md 50 corpus  corpus/gate.jsonl 0 "(k) corpus wins over the named file -> PASS"

# --- mutants ---------------------------------------------------------------------------------
# Built as COPIES, guarded by `cmp -s` (a sed that matched nothing must not pass as a mutation)
# and `bash -n` (a mutant that is no longer a program emits nothing, and nothing scores as a
# kill). The validator resolves its steering sibling from `dirname "$0"`, so BOTH files are
# copied -- a lone copy dies with "cannot verify the citation" and that failure would be read as
# the mutant working.
echo
MWORK="$(mktemp -d)"; trap 'rm -rf "$ROOT" "$MWORK"' EXIT
SRC_DIR="$(cd "$(dirname "$VALIDATOR")" && pwd)"
cp "$SRC_DIR/validate-steering-budget.sh" "$MWORK/" 2>/dev/null \
  || { echo "  FAIL mutants: cannot copy the steering sibling from $SRC_DIR"; FAIL=$((FAIL + 1)); }
cp "$VALIDATOR" "$MWORK/control.sh"

mutate() {  # mutate <name> <sed-expr>  -> prints the mutant path
  local name="$1" expr="$2"
  cp "$VALIDATOR" "$MWORK/m-$name.sh" || { echo "  FAIL mutant $name: copy failed"; return 1; }
  sed -i.bak "$expr" "$MWORK/m-$name.sh" && rm -f "$MWORK/m-$name.sh.bak"
  if cmp -s "$VALIDATOR" "$MWORK/m-$name.sh"; then
    echo "  FAIL mutant $name changed no bytes -- its sed matched nothing and would score as a kill"; return 1
  fi
  bash -n "$MWORK/m-$name.sh" || { echo "  FAIL mutant $name does not parse; its silence would score as a kill"; return 1; }
  printf '%s\n' "$MWORK/m-$name.sh"
}

# Assertion 0 -- the UNMUTATED CONTROL COPY reproduces the whole corpus baseline. Refuse to
# believe any mutant until a copy in this same directory has produced all four verdicts.
echo "  -- unmutated control copy --"
gx pending-crosssession.md 50 ""      corpus/gate.jsonl 1 "control reproduces (h)" "$MWORK/control.sh"
gx pending-crosssession.md 50 corpus  ""                0 "control reproduces (i)" "$MWORK/control.sh"
gx pending-crossfake.md    50 corpus  ""                1 "control reproduces (j)" "$MWORK/control.sh"
gx pending-crosssession.md 50 corpus  corpus/gate.jsonl 0 "control reproduces (k)" "$MWORK/control.sh"

# Mutant A -- the corpus arm is never taken. Kills (i) ONLY: (h) passes no dir, and (j) still
# FAILs because with no usable ground truth the gate fails closed for a different stated reason.
echo "  -- mutant A: corpus arm disabled (expect ONLY (i) to go red) --"
MA="$(mutate no-dir-arm 's@\[ -n "\$TRANSCRIPT_DIR" \] && \[ -d "\$TRANSCRIPT_DIR" \]@[ -n "" ]@')" || FAIL=$((FAIL + 1))
if [ -n "${MA:-}" ]; then
  gx pending-crosssession.md 50 corpus "" 1 "A: (i) is red -- corpus no longer consulted" "$MA"
  gx pending-crosssession.md 50 ""     corpus/gate.jsonl 1 "A: (h) unchanged" "$MA"
  gx pending-crossfake.md    50 corpus "" 1 "A: (j) unchanged" "$MA"
fi

# Mutant C -- the corpus is consulted only when no single file was named, i.e. precedence
# inverted. Kills (k) ONLY: (i) and (j) pass no --transcript, so their branch is unchanged.
echo "  -- mutant C: precedence inverted (expect ONLY (k) to go red) --"
MC="$(mutate dir-loses-order 's@&& \[ -d "\$TRANSCRIPT_DIR" \]; then@\&\& [ -d "$TRANSCRIPT_DIR" ] \&\& [ -z "$TRANSCRIPT" ]; then@')" || FAIL=$((FAIL + 1))
if [ -n "${MC:-}" ]; then
  gx pending-crosssession.md 50 corpus corpus/gate.jsonl 1 "C: (k) is red -- named file beat the corpus" "$MC"
  gx pending-crosssession.md 50 corpus ""                0 "C: (i) unchanged" "$MC"
  gx pending-crossfake.md    50 corpus ""                1 "C: (j) unchanged" "$MC"
fi

echo
if [ "$FAIL" -gt 0 ]; then echo "FAIL: $FAIL of $N assertions wrong."; exit 1; fi
echo "PASS: all $N assertions correct."
exit 0
