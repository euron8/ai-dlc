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
# The candidate list above spans both install layouts and takes the first that EXISTS. Print
# what this run actually loaded: a mutant applied to the other copy leaves every arm green
# and reads exactly like an arm that cannot fire, and `cmp -s` cannot tell the two apart.
echo "escalation-citation: resolved subject = $(cd "$(dirname "$VALIDATOR")" && pwd)/$(basename "$VALIDATOR")"
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

# --- an EMPTY corpus is ABSENT ground truth, not a fabrication --------------------------------
# `-d` answers whether the path EXISTS, never whether it holds any ground truth. With nothing
# to search, the citation query returned NOMATCH and this validator printed "appears in NO
# genuine operator message ... This is the S290 failure" -- an ACCUSATION, over a corpus it
# never read. Both states exit 1, which is why no arm above could see this: the exit code is
# identical and only the sentence differs.
#
# $1 pending  $2 dir-or-""  $3 transcript-or-""  $4 want-exit  $5 must-appear  $6 must-NOT-appear
# $7 why  $8 optional validator override.
gsx() {
  local f="$1" d="$2" t="$3" want="$4" yes="$5" no="$6" why2="$7" v="${8:-$VALIDATOR}"; N=$((N + 1))
  local args=(--escalations "$ROOT/$f" --sprint 50)
  [ -n "$t" ] && args+=(--transcript "$ROOT/$t")
  [ -n "$d" ] && args+=(--transcript-dir "$ROOT/$d")
  local out got why=""
  out="$(bash "$v" "${args[@]}" 2>&1)"; got=$?
  [ "$got" -eq "$want" ] || why="$why [exit=$got want=$want]"
  grep -qF -- "$yes" <<<"$out" || why="$why [missing: $yes]"
  grep -qF -- "$no"  <<<"$out" && why="$why [PRESENT but must not be: $no]"
  if [ -z "$why" ]; then printf '  ok   %-30s exit=%s  (%s)\n' "$f/${d:-nodir}/${t:-nofile}" "$got" "$why2"; return 0
  else FAIL=$((FAIL + 1)); printf '  FAIL %-30s%s  (%s)\n' "$f/${d:-nodir}/${t:-nofile}" "$why" "$why2"; return 1; fi
}

echo
echo "  -- an EMPTY corpus is ABSENT ground truth, not a fabrication --"
# (l) THE DEFECT, at its cheapest: the empty dir outranked the readable file it was passed
# beside, so a genuine, verifiable citation was rejected. This one IS exit-discriminating --
# it is 1 against the pre-fix predicate and 0 here.
gx pending-real.md 50 dir-empty   real.jsonl 0 "(l) an empty --transcript-dir must not outrank a readable transcript"
gx pending-real.md 50 dir-sidecar real.jsonl 0 "(l') a sidecar-only dir is as blind as an empty one -- the reader takes *.jsonl"
# (m) the same absence with nothing to fall back to. Fail CLOSED is correct and settled; what
# is not correct is naming the operator a forger over a corpus that was never read.
gsx pending-real.md dir-empty "" 1 "no readable transcript was provided" "appears in NO genuine" \
    "(m) no corpus and no file: fail CLOSED naming the ABSENCE, not the operator"
# (n) THE TEETH, and the arm that catches the WRONG FIX SHAPE. Clearing STEER_FLAG after the
# if/elif chain rather than narrowing the predicate skips the `--transcript` fallback: this
# still exits 1, but for the wrong reason, and the message is the only place that shows.
gsx pending-real.md dir-empty silent.jsonl 1 "appears in NO genuine" "no readable transcript was provided" \
    "(n) empty dir + a silent file: the FILE was read, so the verdict is about the citation"
# (o) a real corpus still adjudicates a fabrication. Without this, deleting the corpus arm
# outright makes every arm above pass.
gx pending-crossfake.md 50 corpus "" 1 "(o) a corpus with content still FAILs a fabrication (teeth intact)"

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
KILLS=0

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
MA="$(mutate no-dir-arm 's@steer_dir_has_transcript "\$TRANSCRIPT_DIR"; then@[ -n "" ]; then@')" || FAIL=$((FAIL + 1))
if [ -n "${MA:-}" ]; then
  gx pending-crosssession.md 50 corpus "" 1 "A: (i) is red -- corpus no longer consulted" "$MA" && KILLS=$((KILLS + 1))
  gx pending-crosssession.md 50 ""     corpus/gate.jsonl 1 "A: (h) unchanged" "$MA"
  gx pending-crossfake.md    50 corpus "" 1 "A: (j) unchanged" "$MA"
fi

# Mutant C -- the corpus is consulted only when no single file was named, i.e. precedence
# inverted. Kills (k) ONLY: (i) and (j) pass no --transcript, so their branch is unchanged.
echo "  -- mutant C: precedence inverted (expect ONLY (k) to go red) --"
MC="$(mutate dir-loses-order 's@steer_dir_has_transcript "\$TRANSCRIPT_DIR"; then@steer_dir_has_transcript "$TRANSCRIPT_DIR" \&\& [ -z "$TRANSCRIPT" ]; then@')" || FAIL=$((FAIL + 1))
if [ -n "${MC:-}" ]; then
  gx pending-crosssession.md 50 corpus corpus/gate.jsonl 1 "C: (k) is red -- named file beat the corpus" "$MC" && KILLS=$((KILLS + 1))
  gx pending-crosssession.md 50 corpus ""                0 "C: (i) unchanged" "$MC"
  gx pending-crossfake.md    50 corpus ""                1 "C: (j) unchanged" "$MC"
fi

# Mutant R -- the narrowing REVERTED to the shipped-defect predicate, byte for byte. The
# corpus arm is still taken, so (h)/(i)/(j)/(k) are all unchanged; what moves is exactly the
# empty-corpus set, which is what makes those arms arms rather than restatements of the fix.
echo "  -- mutant R: the pre-fix existence-only predicate restored (expect ONLY the empty-corpus arms to go red) --"
MR="$(mutate revert-existence-only 's@steer_dir_has_transcript "\$TRANSCRIPT_DIR"; then@[ -n "$TRANSCRIPT_DIR" ] \&\& [ -d "$TRANSCRIPT_DIR" ]; then@')" || FAIL=$((FAIL + 1))
if [ -n "${MR:-}" ]; then
  gx pending-real.md 50 dir-empty   real.jsonl 1 "R: (l) is red -- the empty dir outranks a readable transcript" "$MR" && KILLS=$((KILLS + 1))
  gx pending-real.md 50 dir-sidecar real.jsonl 1 "R: (l') is red -- a sidecar-only dir does too"                 "$MR" && KILLS=$((KILLS + 1))
  gsx pending-real.md dir-empty "" 1 "appears in NO genuine" "no readable transcript was provided" \
      "R: (m) is red -- the empty corpus is reported as the OPERATOR having said nothing" "$MR" && KILLS=$((KILLS + 1))
  # ...and the four corpus verdicts do not move. More failures than these would mean the
  # assertions are entangled and one of them is vacuous.
  gx pending-crosssession.md 50 corpus  ""                0 "R: (i) unchanged" "$MR"
  gx pending-crossfake.md    50 corpus  ""                1 "R: (j) unchanged" "$MR"
  gx pending-crosssession.md 50 corpus  corpus/gate.jsonl 0 "R: (k) unchanged" "$MR"
fi

# Mutant W -- the WRONG FIX SHAPE, and the one the entry's own prose lists as a legitimate
# option: the existence-only predicate left where it was, and the narrowing moved BELOW the
# if/elif chain as a clearing of STEER_FLAG. It repairs (m) -- which is why it looks like a
# fix -- and skips the `--transcript` fallback entirely, so a caller that passed BOTH flags
# loses the file that holds the words. `steps/gate-validation.md` instructs the operator to
# pass both, so that caller is the normal one.
echo "  -- mutant W: the narrowing moved below the chain (expect (l) and (n) to go red, (m) not) --"
MW="$(mutate clear-after-chain 's@steer_dir_has_transcript "\$TRANSCRIPT_DIR"; then@[ -n "$TRANSCRIPT_DIR" ] \&\& [ -d "$TRANSCRIPT_DIR" ]; then@; s@^  if \[ -z "\$STEER_FLAG" \]; then@  [ "$STEER_FLAG" = "--dir" ] \&\& ! steer_dir_has_transcript "$STEER_ARG" \&\& { STEER_FLAG=""; STEER_ARG=""; }; if [ -z "$STEER_FLAG" ]; then@')" || FAIL=$((FAIL + 1))
if [ -n "${MW:-}" ]; then
  gx pending-real.md 50 dir-empty real.jsonl 1 "W: (l) is red -- the fallthrough to the named file is gone" "$MW" && KILLS=$((KILLS + 1))
  gsx pending-real.md dir-empty silent.jsonl 1 "no readable transcript was provided" "appears in NO genuine" \
      "W: (n) is red -- the file was never read, so the gate reports an absence it does not have" "$MW" && KILLS=$((KILLS + 1))
  # (m) is UNCHANGED under W. That is the whole hazard: the shape repairs the case with no
  # fallback available and breaks only the case that has one.
  gsx pending-real.md dir-empty "" 1 "no readable transcript was provided" "appears in NO genuine" \
      "W: (m) unchanged -- which is why this shape reads as a fix" "$MW"
  gx pending-crosssession.md 50 corpus "" 0 "W: (i) unchanged" "$MW"
  gx pending-crossfake.md    50 corpus "" 1 "W: (j) unchanged" "$MW"
fi

# KILL COUNT. A mutation that applied cleanly to a file the run never loaded reads exactly
# like an arm that cannot fire, and `cmp -s` cannot tell them apart. Zero kills is that state.
N=$((N + 1))
if [ "$KILLS" -ge 7 ]; then printf '  ok   %-30s %s mutant kill(s) -- these arms can fire\n' "KILL-COUNT" "$KILLS"
else FAIL=$((FAIL + 1)); printf '  FAIL %-30s %s kill(s); the mutants changed bytes in a file these arms never loaded\n' "KILL-COUNT" "$KILLS"; fi

echo
if [ "$FAIL" -gt 0 ]; then echo "FAIL: $FAIL of $N assertions wrong."; exit 1; fi
echo "PASS: all $N assertions correct."
exit 0
