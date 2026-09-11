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

# --- the citation is a FIELD, not a LINE -----------------------------------------------------
# The cited substring used to be captured with `sed -n 's/.*"\(.*\)".*/\1/p'`, whose leading
# `.*` is GREEDY: on a field carrying more than one quoted segment the capture is the LAST one,
# and on an odd quote count it is the CONNECTIVE BETWEEN two of them. (p) and (q) are ONE
# PROPERTY APART -- the same two quoted segments in the two orders -- because the two directions
# of that bug are a false accusation and a fail-OPEN, and only the pair separates a parser that
# reads the field from one that refuses everything. pending-real.md and pending-fabricated.md
# are their single-segment near-miss twins and neither verdict may move.
echo
echo "  -- the citation is a FIELD: which quoted segment the parser takes --"
g pending-order-good-first.md 50 real.jsonl 0 "(p) genuine words first, other text after -> PASS"
g pending-order-good-last.md  50 real.jsonl 1 "(q) invented disposition first, genuine words trailing -> FAIL (the fail-open half)"
g pending-connective.md       50 real.jsonl 0 "(r) odd quote count -> the operator's words, not the connective between them"
g pending-unterminated.md     50 real.jsonl 0 "(s) citation continues on the next line -> the unterminated tail IS the quote"
says pending-order-good-last.md 50 real.jsonl "appears in NO genuine" "zzz no operator ever typed"
# (t) A transcript directory is LIVE -- measured, its listing digest moved four times across ten
# runs while the session writing it was merely idle -- so two runs over a byte-identical
# pending.md are two runs over two corpora. The sibling already prints which corpus state it
# read; this caller used to discard it.
gsx pending-crossfake.md corpus "" 1 "transcript(s) from" "IMPOSSIBLE-TOKEN-NEVER-EMITTED" \
    "(t) the accusation names the corpus STATE it was measured over"

# --- the citation's TIMESTAMP, at the READER ------------------------------------------------
echo
echo "  -- what the citation's timestamp bounds, and what a writer can do to it --"
# (u) THE FORGERY DIRECTION. The quote is a real operator turn from three weeks before the
# stamp, so `pending-real.md` beside it is the near-miss: same file shape, same corpus, same
# genuine words, and only the distance from the stamp differs.
g pending-before.md 50 real.jsonl 1 "(u) a genuine turn three weeks BEFORE the cited stamp -> FAIL"
says pending-before.md 50 real.jsonl "appears in NO genuine" "within the tolerance"
# (v) THE UNBOUNDED PASS, WHICH USED TO BE INVISIBLE. A space where the grammar wants `T`
# yields no bound, so the citation is verified against the whole corpus. It still PASSES -- a
# citation with no parseable timestamp may still be real, and one live consumer row is exactly
# that -- but the PASS now SAYS SO, and the canonical twin says zero in the same run.
g pending-space.md 50 real.jsonl 0 "(v) a space instead of T verifies unbounded -> PASS"
saysout() {  # $1 pending  $2 transcript  $3.. must-appear
  local f="$1" t="$2"; shift 2; N=$((N + 1))
  local out miss=""
  out="$(bash "$VALIDATOR" --escalations "$ROOT/$f" --sprint 50 --transcript "$ROOT/$t" 2>/dev/null)"
  local w; for w in "$@"; do grep -qF -- "$w" <<<"$out" || miss="$miss [$w]"; done
  if [ -z "$miss" ]; then printf '  ok   %-26s PASS line carries the count\n' "$f"
  else FAIL=$((FAIL + 1)); printf '  FAIL %-26s missing:%s\n       | %s\n' "$f" "$miss" "$out"; fi
}
saysout pending-space.md real.jsonl "unbounded-citation: 1"
# ...and the CANONICAL twin, one property apart, must say zero. Without it the count arm passes
# against a reader that prints the same number on every run.
saysout pending-real.md  real.jsonl "unbounded-citation: 0"
# (w) A ZONE OFFSET IS THE SAME INSTANT, not a naive time. Same quote and same corpus as
# pending-real.md; only the spelling of the stamp differs.
g pending-offset.md 50 real.jsonl 0 "(w) an offset stamp naming the same instant -> PASS"

# --- what the PASS path says about the corpus it was taken over -------------------------------
# THE FAIL-OPEN DIRECTION. The accusation branch names its corpus; the PASS branch captured the
# same report and discarded it, so the one verdict an operator cannot falsify was also the one
# that never said what produced it. A pass over the intended corpus and a pass over a nearly
# empty one were the same bytes.
#
# THE SEED HOLDS THE PATH FIXED AND MOVES THE CONTENT, because that is the measured phenomenon:
# a transcript directory is LIVE and the same `--transcript-dir` argument names a different set
# of files minutes apart. Two differently-named directories would be separated by an output that
# merely echoed its own argument, which is blind to exactly the thing that moves.
#
# ASSERT THE VALUE THAT VARIES, NEVER THE SENTENCE. `1 transcript(s)` against `2 transcript(s)`
# over one byte-identical pending.md is a difference no constant can produce -- and the DIFFER
# assertion beside it is what makes this an arm rather than two hardcoded strings, since a reader
# printing the same line on every run satisfies neither.
echo
echo "  -- the PASS path names the corpus state it was taken over --"
pass_corpus_pair() {  # $1 validator  -> 0 if the PASS output moves with the corpus
  local v="$1" a b ra rb
  rm -f "$ROOT/corpus-live"/*.jsonl
  cp "$ROOT/corpus/spoke.jsonl" "$ROOT/corpus-live/spoke.jsonl"
  local md5a; md5a="$(md5 -q "$ROOT/pending-crosssession.md" 2>/dev/null || md5sum "$ROOT/pending-crosssession.md" | cut -d' ' -f1)"
  a="$(bash "$v" --escalations "$ROOT/pending-crosssession.md" --sprint 50 --transcript-dir "$ROOT/corpus-live" 2>/dev/null)"; ra=$?
  cp "$ROOT/corpus/gate.jsonl" "$ROOT/corpus-live/gate.jsonl"
  local md5b; md5b="$(md5 -q "$ROOT/pending-crosssession.md" 2>/dev/null || md5sum "$ROOT/pending-crosssession.md" | cut -d' ' -f1)"
  b="$(bash "$v" --escalations "$ROOT/pending-crosssession.md" --sprint 50 --transcript-dir "$ROOT/corpus-live" 2>/dev/null)"; rb=$?
  PCP_WHY=""
  # The two sides must differ in the INPUT before their outputs are compared, and the one input
  # this arm claims is unchanged must be provably unchanged -- otherwise a difference in the
  # output says nothing about which side of the pair produced it.
  [ "$md5a" = "$md5b" ] || PCP_WHY="$PCP_WHY [pending.md moved between the runs: $md5a vs $md5b]"
  [ "$ra" -eq 0 ] && [ "$rb" -eq 0 ] || PCP_WHY="$PCP_WHY [not both PASS: rc=$ra,$rb]"
  grep -qF -- "1 transcript(s)" <<<"$a" || PCP_WHY="$PCP_WHY [run A does not report its 1-file corpus]"
  grep -qF -- "2 transcript(s)" <<<"$b" || PCP_WHY="$PCP_WHY [run B does not report its 2-file corpus]"
  [ "$a" != "$b" ] || PCP_WHY="$PCP_WHY [both PASSes are byte-identical over two different corpora]"
  [ -z "$PCP_WHY" ]
}
N=$((N + 1))
if pass_corpus_pair "$VALIDATOR"; then
  printf '  ok   %-30s (x) a PASS states the corpus state it was taken over\n' "corpus-live"
else
  FAIL=$((FAIL + 1)); printf '  FAIL %-30s%s  (x) the PASS path does not name its corpus\n' "corpus-live" "$PCP_WHY"
fi

# (y) THE ACCUSATION BRANCH DID NOT CHANGE SHAPE. The over-broad version of this fix -- render
# the report on every path -- passes (x) and gives the FAIL branch the report TWICE, where it
# already had it. Counted, not grepped: presence is true under both.
cite_lines() {  # $1 validator  -> how many corpus-report lines the FAIL output carries
  local v="$1" out n
  out="$(bash "$v" --escalations "$ROOT/pending-crossfake.md" --sprint 50 --transcript-dir "$ROOT/corpus" 2>&1)"
  n="$(grep -cF -- "cite: scanned" <<<"$out")" || n=0
  printf '%s' "$n"
}
N=$((N + 1))
CL="$(cite_lines "$VALIDATOR")"
if [ "$CL" -eq 1 ]; then printf '  ok   %-30s (y) the FAIL branch reports its corpus exactly once\n' "pending-crossfake.md"
else FAIL=$((FAIL + 1)); printf '  FAIL %-30s (y) the FAIL branch carries %s corpus-report line(s), not 1\n' "pending-crossfake.md" "$CL"; fi

# (z) A VERDICT THAT VERIFIED NOTHING NAMES NO CORPUS. The vacuous path exits before any
# citation is checked, so a corpus line there would attest a scan that never ran -- which is the
# same unfalsifiable claim this whole section removes, in the other direction. Asserted as a LINE
# COUNT, because a reader rendering an empty default there prints a line that greps as nothing.
vac_lines() {  # $1 validator  -> stdout line count of the nothing-in-scope PASS
  local v="$1" out
  out="$(bash "$v" --escalations "$ROOT/pending-clean.md" --sprint 50 --transcript "$ROOT/real.jsonl" 2>/dev/null)"
  printf '%s' "$(printf '%s\n' "$out" | grep -c .)"
}
N=$((N + 1))
VL="$(vac_lines "$VALIDATOR")"
if [ "$VL" -eq 1 ]; then printf '  ok   %-30s (z) a PASS that examined nothing names no corpus\n' "pending-clean.md"
else FAIL=$((FAIL + 1)); printf '  FAIL %-30s (z) the vacuous PASS printed %s line(s), not 1\n' "pending-clean.md" "$VL"; fi

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

# Mutant Q -- the pick reverts to LAST-segment-wins, which is what the greedy capture did. It
# owns BOTH order arms deliberately: they are one property from each other, so a mutant moving
# only one of them would mean the other arm is asserting something else. The single-segment
# twins must not move -- 98 of the reference consumer's 106 citations are that shape, and a
# mutant that moved them would mean these arms fire on every citation rather than on this one.
echo "  -- mutant Q: last quoted segment wins (the pre-fix greedy capture) --"
MQ="$(mutate last-segment-wins 's@\[ -n "\$_cq_pick" \] || _cq_pick="\$_cq_seg"@_cq_pick="$_cq_seg"@')" || FAIL=$((FAIL + 1))
if [ -n "${MQ:-}" ]; then
  gx pending-order-good-first.md 50 "" real.jsonl 1 "Q: (p) is red -- the trailing text is taken as the citation" "$MQ" && KILLS=$((KILLS + 1))
  gx pending-order-good-last.md  50 "" real.jsonl 0 "Q: (q) is red -- an invented disposition passes on a trailing genuine quote" "$MQ" && KILLS=$((KILLS + 1))
  gx pending-real.md             50 "" real.jsonl 0 "Q: (d) unchanged -- one segment, one answer" "$MQ"
  gx pending-fabricated.md       50 "" real.jsonl 1 "Q: (c) unchanged" "$MQ"
fi

# Mutant U -- the unterminated trailing segment is dropped. `split` on `"` puts the inside-quote
# fields at the EVEN indices and an odd quote count leaves the final field unterminated, also
# even-indexed; `i < n` skips exactly that one. Balanced citations are untouched, which is why
# (d) and (p) must stay green here.
echo "  -- mutant U: the unterminated trailing segment is dropped --"
MU="$(mutate drop-unterminated-tail 's@for (i = 2; i <= n; i += 2)@for (i = 2; i < n; i += 2)@')" || FAIL=$((FAIL + 1))
if [ -n "${MU:-}" ]; then
  gx pending-unterminated.md     50 "" real.jsonl 1 "U: (s) is red -- the tail is gone and the label line becomes the needle" "$MU" && KILLS=$((KILLS + 1))
  gx pending-connective.md       50 "" real.jsonl 1 "U: (r) is red -- only the too-short segment survives" "$MU" && KILLS=$((KILLS + 1))
  gx pending-real.md             50 "" real.jsonl 0 "U: (d) unchanged -- a balanced citation has no tail" "$MU"
  gx pending-order-good-first.md 50 "" real.jsonl 0 "U: (p) unchanged" "$MU"
fi

# Mutant V -- the sibling's corpus report is captured and then not printed. The verdict does not
# move, which is the whole point: this arm is about ATTRIBUTION, and the exit code cannot see it.
echo "  -- mutant V: the corpus report is dropped from the accusation --"
MV="$(mutate drop-corpus-report 's@\[ -n "\$CITE_REPORT" \] && printf@[ -n "" ] \&\& printf@')" || FAIL=$((FAIL + 1))
if [ -n "${MV:-}" ]; then
  gsx pending-crossfake.md corpus "" 1 "appears in NO genuine" "transcript(s) from" \
      "V: (t) is red -- the accusation no longer says which corpus produced it" "$MV" && KILLS=$((KILLS + 1))
fi

# Mutant T -- cite_ts TRUNCATES a zone offset, the shape it had before this round: the regex
# stops before `+`/`-`, the naive part is handed to the verifier, and the owner reads it as UTC.
# Kills (w) ONLY -- every other citation here carries `Z`, which the truncating form returns
# whole, so this mutant and the fixed one are the same program for them.
echo "  -- mutant T: cite_ts truncates a zone offset (expect ONLY (w) to go red) --"
MT="$(mutate ts-truncates-offset 's@(Z|\[+-\]\[0-9\]{2}:?\[0-9\]{2})?@Z?@')" || FAIL=$((FAIL + 1))
if [ -n "${MT:-}" ]; then
  gx pending-offset.md 50 "" real.jsonl 1 "T: (w) is red -- the offset stamp is read seven hours from the instant it names" "$MT" && KILLS=$((KILLS + 1))
  gx pending-real.md   50 "" real.jsonl 0 "T: (d) unchanged -- a Z stamp is returned whole either way" "$MT"
  gx pending-before.md 50 "" real.jsonl 1 "T: (u) unchanged" "$MT"
fi

# Mutant B2 -- the UNBOUNDED-VERIFY COUNT dropped from the PASS line. The verdict does not move,
# which is the whole point: a gate log then cannot tell a bounded pass from an unbounded one,
# and no exit code anywhere can see it.
echo "  -- mutant B2: the unbounded-verify count is not reported --"
MB2="$(mutate drop-unbounded-count 's@ unbounded-citation: \${UNBOUNDED} verified with no timestamp bound\.@@')" || FAIL=$((FAIL + 1))
if [ -n "${MB2:-}" ]; then
  N=$((N + 1))
  OUTB2="$(bash "$MB2" --escalations "$ROOT/pending-space.md" --sprint 50 --transcript "$ROOT/real.jsonl" 2>/dev/null)"; rcb2=$?
  if [ "$rcb2" -eq 0 ] && ! grep -qF -- "unbounded-citation:" <<<"$OUTB2"; then
    KILLS=$((KILLS + 1)); printf '  ok   %-26s B2: the count is gone while the verdict stays PASS -- (v) has teeth\n' "pending-space.md"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %-26s B2 DID NOT FAIL (rc=%s): the count survived the mutation, so (v) is not testing it\n' "pending-space.md" "$rcb2"
  fi
fi

# Mutant P1 -- the PASS path captures the corpus report and discards it, which is the shape this
# validator shipped with. The verdict does not move: every exit code, the FAIL branch and the
# vacuous branch are untouched, and only an operator asking WHAT the pass was taken over can see
# the difference. Kills (x) ONLY.
echo "  -- mutant P1: the PASS path discards the corpus report --"
MP1="$(mutate pass-drops-corpus 's@^echo "      \${CITE_REPORT:-@echo "      " #@')" || FAIL=$((FAIL + 1))
if [ -n "${MP1:-}" ]; then
  N=$((N + 1))
  if ! pass_corpus_pair "$MP1"; then
    KILLS=$((KILLS + 1)); printf '  ok   %-30s P1: (x) is red -- the PASS says nothing about its corpus\n' "corpus-live"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %-30s P1 SURVIVED: (x) passes with the render deleted, so it is not testing it\n' "corpus-live"
  fi
  N=$((N + 1))
  [ "$(cite_lines "$MP1")" -eq 1 ] && printf '  ok   %-30s P1: (y) unchanged\n' "pending-crossfake.md" \
    || { FAIL=$((FAIL + 1)); printf '  FAIL %-30s P1 moved (y) too -- the arms are entangled\n' "pending-crossfake.md"; }
fi

# Mutant P2 -- THE FIRST PLAUSIBLE WRONG FIX: the PASS path renders a fixed sentence instead of
# the verifier's own report. It satisfies every presence-shaped reading of "the PASS names its
# corpus" and is blind to the thing that moves, which is why (x) asserts the COUNT and asserts
# the two runs DIFFER rather than asserting a phrase. Kills (x) ONLY.
echo "  -- mutant P2: the PASS path renders a constant, not the corpus state --"
MP2="$(mutate pass-renders-constant 's@\${CITE_REPORT:-[^}]*}@cite: scanned the transcript corpus@')" || FAIL=$((FAIL + 1))
if [ -n "${MP2:-}" ]; then
  N=$((N + 1))
  if ! pass_corpus_pair "$MP2"; then
    KILLS=$((KILLS + 1)); printf '  ok   %-30s P2: (x) is red -- a constant renders identically over both corpora\n' "corpus-live"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %-30s P2 SURVIVED: (x) accepts a sentence that never moves\n' "corpus-live"
  fi
  N=$((N + 1))
  [ "$(vac_lines "$MP2")" -eq 1 ] && printf '  ok   %-30s P2: (z) unchanged\n' "pending-clean.md" \
    || { FAIL=$((FAIL + 1)); printf '  FAIL %-30s P2 moved (z) too -- the arms are entangled\n' "pending-clean.md"; }
fi

# Mutant P3 -- THE SECOND PLAUSIBLE WRONG FIX, and the one a hand builds by accident: render the
# report unconditionally, above the branch that forks. It satisfies (x) completely -- the PASS
# does name its corpus -- and gives the accusation the same line TWICE. Kills (y) ONLY, which is
# why (y) counts the lines instead of grepping for one: presence is true under both.
echo "  -- mutant P3: the report is rendered unconditionally, on both branches --"
MP3="$(mutate report-on-every-path 's@^if \[ "\$FAIL" -ne 0 \]; then@printf "      %s\\n" "$CITE_REPORT"; if [ "$FAIL" -ne 0 ]; then@')" || FAIL=$((FAIL + 1))
if [ -n "${MP3:-}" ]; then
  N=$((N + 1))
  MP3CL="$(cite_lines "$MP3")"
  if [ "$MP3CL" -ne 1 ]; then
    KILLS=$((KILLS + 1)); printf '  ok   %-30s P3: (y) is red -- the accusation carries %s corpus lines\n' "pending-crossfake.md" "$MP3CL"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %-30s P3 SURVIVED: an unconditional dump left the FAIL branch at one line\n' "pending-crossfake.md"
  fi
  # ...and it PASSES (x), which is the hazard: the over-broad shape reads as the fix.
  N=$((N + 1))
  if pass_corpus_pair "$MP3"; then printf '  ok   %-30s P3: (x) unchanged -- which is why this shape reads as a fix\n' "corpus-live"
  else FAIL=$((FAIL + 1)); printf '  FAIL %-30s P3 moved (x) too -- the arms are entangled\n' "corpus-live"; fi
fi

# Mutant P4 -- the corpus line is attached to the branch that VERIFIED NOTHING. No citation was
# checked there, so the line attests a scan that never ran: the same unfalsifiable claim, in the
# other direction. Kills (z) ONLY -- and (z) is absence-shaped, so nothing but a mutant can
# establish that it fires at all.
echo "  -- mutant P4: the nothing-in-scope PASS claims a corpus --"
MP4="$(mutate vacuous-claims-corpus 's@^  echo "OK: no S\${SPRINT_NUM} RESOLVED/OVERRIDDEN escalation requires an operator citation."@  echo "OK: no S${SPRINT_NUM} RESOLVED/OVERRIDDEN escalation requires an operator citation."; echo "      cite: scanned 0 transcript(s)"@')" || FAIL=$((FAIL + 1))
if [ -n "${MP4:-}" ]; then
  N=$((N + 1))
  MP4VL="$(vac_lines "$MP4")"
  if [ "$MP4VL" -ne 1 ]; then
    KILLS=$((KILLS + 1)); printf '  ok   %-30s P4: (z) is red -- the vacuous PASS printed %s lines\n' "pending-clean.md" "$MP4VL"
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %-30s P4 SURVIVED: (z) cannot see a corpus line on a path that verified nothing\n' "pending-clean.md"
  fi
  N=$((N + 1))
  if pass_corpus_pair "$MP4"; then printf '  ok   %-30s P4: (x) unchanged\n' "corpus-live"
  else FAIL=$((FAIL + 1)); printf '  FAIL %-30s P4 moved (x) too -- the arms are entangled\n' "corpus-live"; fi
fi

# KILL COUNT. A mutation that applied cleanly to a file the run never loaded reads exactly
# like an arm that cannot fire, and `cmp -s` cannot tell them apart. Zero kills is that state.
N=$((N + 1))
if [ "$KILLS" -ge 18 ]; then printf '  ok   %-30s %s mutant kill(s) -- these arms can fire\n' "KILL-COUNT" "$KILLS"
else FAIL=$((FAIL + 1)); printf '  FAIL %-30s %s kill(s); the mutants changed bytes in a file these arms never loaded\n' "KILL-COUNT" "$KILLS"; fi

echo
if [ "$FAIL" -gt 0 ]; then echo "FAIL: $FAIL of $N assertions wrong."; exit 1; fi
echo "PASS: all $N assertions correct."
exit 0
