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
#
# THE MUTANT MATRIX. Every kill is emitted through mutant_killed (core/fixtures/lib/mutant.sh) with
# a flag captured from the UNMUTATED arm the mutant decides, in this same run: a `$?` capture right
# after that arm against the shipped validator, the M-control, R-control and F-control copies for
# the empty-file, refusal and floor batteries (en-<cell>, er-<cell>, fl-<cell> tokens), and the
# unmutated cell of LR_CELLS (with the L-control copy) for the lead-interpretation battery. Arm
# tokens are the letters of the arms below, `l-prime` for (l'); fl-<cell> and the bare LR_NAMES are the
# cells of the floor and lead-interpretation vectors. A plain run scores each mutant on its deciding
# arms and the twins named here; `--matrix` runs every mutant against every arm of its family and
# prints one MATRIX row per pair.
# MUTANT-MATRIX no-dir-arm decides=i twins=h,j
# MUTANT-MATRIX dir-loses-order decides=k twins=i,j
# MUTANT-MATRIX revert-existence-only decides=l,l-prime,m twins=i,j,k
# MUTANT-MATRIX clear-after-chain decides=l,n twins=m,i,j
# MUTANT-MATRIX last-segment-wins decides=p,q twins=d,c
# MUTANT-MATRIX drop-unterminated-tail decides=s,r twins=d,p
# MUTANT-MATRIX drop-corpus-report decides=t twins=j
# MUTANT-MATRIX ts-truncates-offset decides=w twins=d,u
# MUTANT-MATRIX drop-unbounded-count decides=v twins=d
# MUTANT-MATRIX pass-drops-corpus decides=x twins=y
# MUTANT-MATRIX pass-renders-constant decides=x twins=z
# MUTANT-MATRIX report-on-every-path decides=y twins=x
# MUTANT-MATRIX vacuous-claims-corpus decides=z twins=x
# MUTANT-MATRIX-FULL F-m1 worlds=fl-P,fl-Q,fl-R,fl-S,fl-T,fl-t,fl-U,fl-V,fl-W,fl-X,fl-Np,fl-Nb,fl-Na,fl-Nab,fl-E,fl-Ea,fl-F11,fl-F12 why=the floor mutants are separated from each other only by cells their neighbours leave alone, so each is held to the whole 18-cell vector
# MUTANT-MATRIX-FULL F-m3 worlds=fl-P,fl-Q,fl-R,fl-S,fl-T,fl-t,fl-U,fl-V,fl-W,fl-X,fl-Np,fl-Nb,fl-Na,fl-Nab,fl-E,fl-Ea,fl-F11,fl-F12 why=separated from F-m1 by cell fl-W alone, which only the whole vector reads
# MUTANT-MATRIX-FULL F-m5 worlds=fl-P,fl-Q,fl-R,fl-S,fl-T,fl-t,fl-U,fl-V,fl-W,fl-X,fl-Np,fl-Nb,fl-Na,fl-Nab,fl-E,fl-Ea,fl-F11,fl-F12 why=held to moving only the two empty-needle cells, which only the whole vector reads
# MUTANT-MATRIX-FULL F-m6 worlds=fl-P,fl-Q,fl-R,fl-S,fl-T,fl-t,fl-U,fl-V,fl-W,fl-X,fl-Np,fl-Nb,fl-Na,fl-Nab,fl-E,fl-Ea,fl-F11,fl-F12 why=held to moving only the eleven-character cell, which only the whole vector reads
# MUTANT-MATRIX-FULL F-m2 worlds=fl-P,fl-Q,fl-R,fl-S,fl-T,fl-t,fl-U,fl-V,fl-W,fl-X,fl-Np,fl-Nb,fl-Na,fl-Nab,fl-E,fl-Ea,fl-F11,fl-F12 why=held to moving only the three --any-authorized cells, which only the whole vector reads
# MUTANT-MATRIX-FULL F-m4 worlds=fl-P,fl-Q,fl-R,fl-S,fl-T,fl-t,fl-U,fl-V,fl-W,fl-X,fl-Np,fl-Nb,fl-Na,fl-Nab,fl-E,fl-Ea,fl-F11,fl-F12 why=held to moving only the two NBSP --any-authorized cells, which only the whole vector reads
# MUTANT-MATRIX-FULL F-m2b worlds=fl-P,fl-Q,fl-R,fl-S,fl-T,fl-t,fl-U,fl-V,fl-W,fl-X,fl-Np,fl-Nb,fl-Na,fl-Nab,fl-E,fl-Ea,fl-F11,fl-F12 why=held to moving only the two caller-message cells, which only the whole vector reads
# MUTANT-MATRIX L-no-label-rule decides=free twins=strike
# MUTANT-MATRIX L-ignore-id decides=wrongid twins=free
# MUTANT-MATRIX L-no-disposition-match decides=mismatch twins=neither
# MUTANT-MATRIX L-gate-dq-into-auth decides=plain twins=nodq
# MUTANT-MATRIX L-any-dq-into-auth decides=shortq-any twins=plain-any
# MUTANT-MATRIX L-drop-sentinel decides=nodq twins=plain
# MUTANT-MATRIX L-rule-short-circuits decides=nohit twins=strike
# MUTANT-MATRIX L-header-tab-kept decides=hdrtab twins=plain
# MUTANT-MATRIX L-header-tab-kept-any decides=hdrtabq-any twins=shortq-any
# MUTANT-MATRIX-FULL M-revert worlds=en-A,en-B,en-C,en-D,en-E,en-F why=the empty-file mutants are each held to the whole six-cell vector so a mutant moving a cell it does not own fails
# MUTANT-MATRIX-FULL M-zero-records worlds=en-A,en-B,en-C,en-D,en-E,en-F why=held to moving only the populated-zero-record cell, which only the whole vector reads
# MUTANT-MATRIX-FULL M-hoist worlds=en-A,en-B,en-C,en-D,en-E,en-F why=held to moving only the --any-authorized cell, which only the whole vector reads
# MUTANT-MATRIX-FULL R-revert-all worlds=er-A,er-B,er-C,er-D,er-E,er-F why=the refusal mutants are each held to the whole six-cell vector, one per layer of the guard plus every layer reverted
# MUTANT-MATRIX-FULL R-nonregular worlds=er-A,er-B,er-C,er-D,er-E,er-F why=separated from R-no-symlink by cell er-B alone, which only the whole vector reads
# MUTANT-MATRIX-FULL R-no-symlink worlds=er-A,er-B,er-C,er-D,er-E,er-F why=held to moving only the dangling-symlink cell, which only the whole vector reads
# MUTANT-MATRIX-FULL R-rc worlds=er-A,er-B,er-C,er-D,er-E,er-F why=held to moving only the mode-000 and grep-status cells, which only the whole vector reads
# MUTANT-MATRIX-FULL R-readable-never worlds=er-A,er-B,er-C,er-D,er-E,er-F why=held to moving only the mode-000 cell, which only the whole vector reads
# MUTANT-MATRIX-FULL R-readable-always worlds=er-A,er-B,er-C,er-D,er-E,er-F why=held to moving only the grep-status cell, which only the whole vector reads
# MUTANT-MATRIX-DYNAMIC en-score why=en_score passes its 2nd argument to the kill helper; each call names a literal mutant carrying its own FULL row above
# MUTANT-MATRIX-DYNAMIC er-score why=er_score passes its 2nd argument to the kill helper; each call names a literal mutant carrying its own FULL row above
# MUTANT-MATRIX-DYNAMIC fl-score why=fl_score passes F-<name> from its 4th argument to the kill helper; each call names a literal mutant carrying its own FULL row above
# MUTANT-MATRIX-DYNAMIC lr-score why=lr_score passes L-<name> from its 1st argument to the kill helper; each call names a literal mutant carrying its own row above
# MUTANT-MATRIX-REMEASURE bash core/fixtures/escalation-citation/run.sh --matrix
#
# Usage: run.sh [--matrix]
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
MATRIX=0; MROWS=0
if [ "${1:-}" = "--matrix" ]; then MATRIX=1; fi

VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-escalation-resolution.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-escalation-resolution.sh" \
  "$DIR/../../core/scripts/validate-escalation-resolution.sh"; do
  [ -f "$cand" ] && VALIDATOR="$cand" && break
done
[ -n "$VALIDATOR" ] || { echo "FAIL: cannot locate validate-escalation-resolution.sh from $DIR"; exit 1; }

# The REQUIRED input of inputs.decl: every assertion below drives this file.
echo "HERMETIC-CONSUMED $(cd "$(dirname "$VALIDATOR")" && pwd)/$(basename "$VALIDATOR")"

ROOT="$(bash "$DIR/seed.sh" | tail -1)"
trap 'rm -rf "$ROOT"' EXIT
FAIL=0; N=0

# ok/bad in this fixture's own line format, the first word of the message being the label column.
# Defined before lib/mutant.sh is sourced, which refuses to load without them.
ok()  { printf '  ok   %-30s %s\n' "${1%% *}" "${1#* }"; }
bad() {
  FAIL=$((FAIL + 1))
  case "$1" in
    "FIXTURE BROKEN"*) printf '  FAIL %s\n' "$1" ;;
    *) printf '  FAIL %-30s %s\n' "${1%% *}" "${1#* }" ;;
  esac
}
[ -f "$DIR/../lib/mutant.sh" ] || { echo "FIXTURE ERROR: $DIR/../lib/mutant.sh is absent; no kill can be scored" >&2; exit 2; }
# shellcheck source=../lib/mutant.sh
. "$DIR/../lib/mutant.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
[ -f "$DIR/../lib/matrix.sh" ] || { echo "FIXTURE ERROR: $DIR/../lib/matrix.sh is absent" >&2; exit 2; }
# shellcheck source=../lib/matrix.sh
. "$DIR/../lib/matrix.sh"
echo "HERMETIC-CONSUMED core/fixtures/lib/matrix.sh"

# $1 pending-file  $2 sprint  $3 transcript-basename (or "")  $4 want-exit  $5 why  $6 optional validator
# Returns 0 when the arm held, 1 when it did not: a kill below captures that status as its base.
g() {
  local f="$1" sp="$2" t="$3" want="$4" why="$5" v="${6:-$VALIDATOR}"; N=$((N + 1))
  local args=(--escalations "$ROOT/$f" --sprint "$sp")
  [ -n "$t" ] && args+=(--transcript "$ROOT/$t")
  local out got
  out="$(bash "$v" "${args[@]}" 2>&1)"; got=$?
  if [ "$got" -eq "$want" ]; then printf '  ok   %-22s exit=%s  (%s)\n' "$f/${t:-none}" "$got" "$why"; return 0
  else FAIL=$((FAIL + 1)); printf '  FAIL %-22s exit=%s want=%s  (%s)\n' "$f/${t:-none}" "$got" "$want" "$why"; printf '%s\n' "$out" | sed 's/^/       | /'; return 1; fi
}
says() {
  local f="$1" sp="$2" t="$3"; shift 3; N=$((N + 1))
  local out miss=""
  out="$(bash "$VALIDATOR" --escalations "$ROOT/$f" --sprint "$sp" --transcript "$ROOT/$t" 2>&1)"
  local w; for w in "$@"; do grep -qF -- "$w" <<<"$out" || miss="$miss [$w]"; done
  if [ -z "$miss" ]; then printf '  ok   %-22s message names the cause\n' "$f(msg)"; return 0
  else FAIL=$((FAIL + 1)); printf '  FAIL %-22s missing:%s\n' "$f(msg)" "$miss"; return 1; fi
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
# GXQ=1 silences the ok line only (a FAIL still prints): a mutant arm that held is reported once,
# by the kill helper, which refuses it unless the unmutated arm held in this run.
GXQ=0
gxq()  { GXQ=1; gx "$@";  local r=$?; GXQ=0; return "$r"; }
gsxq() { GXQ=1; gsx "$@"; local r=$?; GXQ=0; return "$r"; }
gx() {
  local f="$1" sp="$2" d="$3" t="$4" want="$5" why="$6" v="${7:-$VALIDATOR}"; N=$((N + 1))
  local args=(--escalations "$ROOT/$f" --sprint "$sp")
  [ -n "$t" ] && args+=(--transcript "$ROOT/$t")
  [ -n "$d" ] && args+=(--transcript-dir "$ROOT/$d")
  local out got
  out="$(bash "$v" "${args[@]}" 2>&1)"; got=$?
  if [ "$got" -eq "$want" ]; then [ "$GXQ" = 1 ] || printf '  ok   %-26s exit=%s  (%s)\n' "$f" "$got" "$why"; return 0
  else FAIL=$((FAIL + 1)); printf '  FAIL %-26s exit=%s want=%s  (%s)\n' "$f" "$got" "$want" "$why"; printf '%s\n' "$out" | sed 's/^/       | /'; return 1; fi
}

echo
gx pending-crosssession.md 50 ""      corpus/gate.jsonl 1 "(h) genuine adjudication, wrong session named -> FAIL"
gx pending-crosssession.md 50 corpus  ""                0 "(i) same citation, verified over the corpus -> PASS"; RC_I=$?
gx pending-crossfake.md    50 corpus  ""                1 "(j) fabrication over the same corpus -> FAIL (teeth intact)"
gx pending-crosssession.md 50 corpus  corpus/gate.jsonl 0 "(k) corpus wins over the named file -> PASS"; RC_K=$?

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
  if [ -z "$why" ]; then [ "$GXQ" = 1 ] || printf '  ok   %-30s exit=%s  (%s)\n' "$f/${d:-nodir}/${t:-nofile}" "$got" "$why2"; return 0
  else FAIL=$((FAIL + 1)); printf '  FAIL %-30s%s  (%s)\n' "$f/${d:-nodir}/${t:-nofile}" "$why" "$why2"; return 1; fi
}

echo
echo "  -- an EMPTY corpus is ABSENT ground truth, not a fabrication --"
# (l) THE DEFECT, at its cheapest: the empty dir outranked the readable file it was passed
# beside, so a genuine, verifiable citation was rejected. This one IS exit-discriminating --
# it is 1 against the pre-fix predicate and 0 here.
gx pending-real.md 50 dir-empty   real.jsonl 0 "(l) an empty --transcript-dir must not outrank a readable transcript"; RC_L=$?
gx pending-real.md 50 dir-sidecar real.jsonl 0 "(l') a sidecar-only dir is as blind as an empty one -- the reader takes *.jsonl"; RC_LP=$?
# (m) the same absence with nothing to fall back to. Fail CLOSED is correct and settled; what
# is not correct is naming the operator a forger over a corpus that was never read.
gsx pending-real.md dir-empty "" 1 "no readable transcript was provided" "appears in NO genuine" \
    "(m) no corpus and no file: fail CLOSED naming the ABSENCE, not the operator"; RC_M=$?
# (n) THE TEETH, and the arm that catches the WRONG FIX SHAPE. Clearing STEER_FLAG after the
# if/elif chain rather than narrowing the predicate skips the `--transcript` fallback: this
# still exits 1, but for the wrong reason, and the message is the only place that shows.
gsx pending-real.md dir-empty silent.jsonl 1 "appears in NO genuine" "no readable transcript was provided" \
    "(n) empty dir + a silent file: the FILE was read, so the verdict is about the citation"; RC_N=$?
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
g pending-order-good-first.md 50 real.jsonl 0 "(p) genuine words first, other text after -> PASS"; RC_P=$?
g pending-order-good-last.md  50 real.jsonl 1 "(q) invented disposition first, genuine words trailing -> FAIL (the fail-open half)"; RC_Q=$?
g pending-connective.md       50 real.jsonl 0 "(r) odd quote count -> the operator's words, not the connective between them"; RC_R=$?
g pending-unterminated.md     50 real.jsonl 0 "(s) citation continues on the next line -> the unterminated tail IS the quote"; RC_S=$?
says pending-order-good-last.md 50 real.jsonl "appears in NO genuine" "zzz no operator ever typed"
# (t) A transcript directory is LIVE -- measured, its listing digest moved four times across ten
# runs while the session writing it was merely idle -- so two runs over a byte-identical
# pending.md are two runs over two corpora. The sibling already prints which corpus state it
# read; this caller used to discard it.
gsx pending-crossfake.md corpus "" 1 "transcript(s) from" "IMPOSSIBLE-TOKEN-NEVER-EMITTED" \
    "(t) the accusation names the corpus STATE it was measured over"; RC_T=$?

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
  if [ -z "$miss" ]; then printf '  ok   %-26s PASS line carries the count\n' "$f"; return 0
  else FAIL=$((FAIL + 1)); printf '  FAIL %-26s missing:%s\n       | %s\n' "$f" "$miss" "$out"; return 1; fi
}
saysout pending-space.md real.jsonl "unbounded-citation: 1"; RC_V=$?
# ...and the CANONICAL twin, one property apart, must say zero. Without it the count arm passes
# against a reader that prints the same number on every run.
saysout pending-real.md  real.jsonl "unbounded-citation: 0"
# (w) A ZONE OFFSET IS THE SAME INSTANT, not a naive time. Same quote and same corpus as
# pending-real.md; only the spelling of the stamp differs.
g pending-offset.md 50 real.jsonl 0 "(w) an offset stamp naming the same instant -> PASS"; RC_W=$?

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
pass_corpus_pair "$VALIDATOR"; RC_X=$?
if [ "$RC_X" -eq 0 ]; then
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
[ "$CL" -eq 1 ]; RC_Y=$?
if [ "$RC_Y" -eq 0 ]; then printf '  ok   %-30s (y) the FAIL branch reports its corpus exactly once\n' "pending-crossfake.md"
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
[ "$VL" -eq 1 ]; RC_Z=$?
if [ "$RC_Z" -eq 0 ]; then printf '  ok   %-30s (z) a PASS that examined nothing names no corpus\n' "pending-clean.md"
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
KILLS=0; KF_EXTRA=0
# --matrix: one row per cell of a vector-scored mutant, TRIPPED where its cell differs from the
# unmutated control's.  $1 mutant  $2 family prefix  $3 roster "X:name ..."  $4 control  $5 cells
cell_matrix() {
  local i=0 nm
  for nm in $3; do
    i=$((i + 1))
    if [ "$(printf '%s' "$5" | cut -c"$i")" = "$(printf '%s' "$4" | cut -c"$i")" ]; then matrix_row "$1" "$2-${nm%%:*}" 0 GREEN no
    else matrix_row "$1" "$2-${nm%%:*}" 1 TRIPPED yes; fi
    MROWS=$((MROWS + 1))
  done
}

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

# Mutant A -- the corpus arm is never taken. Scored on (i), with (h) and (j) as twins: (h) passes
# no dir, and (j) still FAILs because with no usable ground truth the gate fails closed for a
# different stated reason. MEASURED by --matrix, it also turns (k), (t), (x) and (y) red -- every
# other arm that reads the corpus -- so (i) is its cheapest deciding arm, not its only one.
echo "  -- mutant A: corpus arm disabled (expect (i) to go red; (h) and (j) unchanged) --"
MA="$(mutate no-dir-arm 's@steer_dir_has_transcript "\$TRANSCRIPT_DIR"; then@[ -n "" ]; then@')" || FAIL=$((FAIL + 1))
if [ -n "${MA:-}" ]; then
  gxq pending-crosssession.md 50 corpus "" 1 "A: (i) is red -- corpus no longer consulted" "$MA" \
    && mutant_killed "$([ "$RC_I" = 0 ] && echo 1 || echo 0)" no-dir-arm "pending-crosssession.md A: (i) is red -- corpus no longer consulted" && KILLS=$((KILLS + 1))
  gx pending-crosssession.md 50 ""     corpus/gate.jsonl 1 "A: (h) unchanged" "$MA"
  gx pending-crossfake.md    50 corpus "" 1 "A: (j) unchanged" "$MA"
fi

# Mutant C -- the corpus is consulted only when no single file was named, i.e. precedence
# inverted. Kills (k) ONLY: (i) and (j) pass no --transcript, so their branch is unchanged.
echo "  -- mutant C: precedence inverted (expect ONLY (k) to go red) --"
MC="$(mutate dir-loses-order 's@steer_dir_has_transcript "\$TRANSCRIPT_DIR"; then@steer_dir_has_transcript "$TRANSCRIPT_DIR" \&\& [ -z "$TRANSCRIPT" ]; then@')" || FAIL=$((FAIL + 1))
if [ -n "${MC:-}" ]; then
  gxq pending-crosssession.md 50 corpus corpus/gate.jsonl 1 "C: (k) is red -- named file beat the corpus" "$MC" \
    && mutant_killed "$([ "$RC_K" = 0 ] && echo 1 || echo 0)" dir-loses-order "pending-crosssession.md C: (k) is red -- named file beat the corpus" && KILLS=$((KILLS + 1))
  gx pending-crosssession.md 50 corpus ""                0 "C: (i) unchanged" "$MC"
  gx pending-crossfake.md    50 corpus ""                1 "C: (j) unchanged" "$MC"
fi

# Mutant R -- the narrowing REVERTED to the shipped-defect predicate, byte for byte. The
# corpus arm is still taken, so (h)/(i)/(j)/(k) are all unchanged; what moves is exactly the
# empty-corpus set, which is what makes those arms arms rather than restatements of the fix.
echo "  -- mutant R: the pre-fix existence-only predicate restored (expect ONLY the empty-corpus arms to go red) --"
MR="$(mutate revert-existence-only 's@steer_dir_has_transcript "\$TRANSCRIPT_DIR"; then@[ -n "$TRANSCRIPT_DIR" ] \&\& [ -d "$TRANSCRIPT_DIR" ]; then@')" || FAIL=$((FAIL + 1))
if [ -n "${MR:-}" ]; then
  gxq pending-real.md 50 dir-empty   real.jsonl 1 "R: (l) is red -- the empty dir outranks a readable transcript" "$MR" \
    && mutant_killed "$([ "$RC_L" = 0 ] && echo 1 || echo 0)" revert-existence-only "pending-real.md R: (l) is red -- the empty dir outranks a readable transcript" && KILLS=$((KILLS + 1))
  gxq pending-real.md 50 dir-sidecar real.jsonl 1 "R: (l') is red -- a sidecar-only dir does too" "$MR" \
    && mutant_killed "$([ "$RC_LP" = 0 ] && echo 1 || echo 0)" revert-existence-only "pending-real.md R: (l') is red -- a sidecar-only dir does too" && KILLS=$((KILLS + 1))
  gsxq pending-real.md dir-empty "" 1 "appears in NO genuine" "no readable transcript was provided" \
      "R: (m) is red -- the empty corpus is reported as the OPERATOR having said nothing" "$MR" \
    && mutant_killed "$([ "$RC_M" = 0 ] && echo 1 || echo 0)" revert-existence-only "pending-real.md R: (m) is red -- the empty corpus is reported as the OPERATOR having said nothing" && KILLS=$((KILLS + 1))
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
  gxq pending-real.md 50 dir-empty real.jsonl 1 "W: (l) is red -- the fallthrough to the named file is gone" "$MW" \
    && mutant_killed "$([ "$RC_L" = 0 ] && echo 1 || echo 0)" clear-after-chain "pending-real.md W: (l) is red -- the fallthrough to the named file is gone" && KILLS=$((KILLS + 1))
  gsxq pending-real.md dir-empty silent.jsonl 1 "no readable transcript was provided" "appears in NO genuine" \
      "W: (n) is red -- the file was never read, so the gate reports an absence it does not have" "$MW" \
    && mutant_killed "$([ "$RC_N" = 0 ] && echo 1 || echo 0)" clear-after-chain "pending-real.md W: (n) is red -- the file was never read, so the gate reports an absence it does not have" && KILLS=$((KILLS + 1))
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
  gxq pending-order-good-first.md 50 "" real.jsonl 1 "Q: (p) is red -- the trailing text is taken as the citation" "$MQ" \
    && mutant_killed "$([ "$RC_P" = 0 ] && echo 1 || echo 0)" last-segment-wins "pending-order-good-first.md Q: (p) is red -- the trailing text is taken as the citation" && KILLS=$((KILLS + 1))
  gxq pending-order-good-last.md  50 "" real.jsonl 0 "Q: (q) is red -- an invented disposition passes on a trailing genuine quote" "$MQ" \
    && mutant_killed "$([ "$RC_Q" = 0 ] && echo 1 || echo 0)" last-segment-wins "pending-order-good-last.md Q: (q) is red -- an invented disposition passes on a trailing genuine quote" && KILLS=$((KILLS + 1))
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
  gxq pending-unterminated.md     50 "" real.jsonl 1 "U: (s) is red -- the tail is gone and the label line becomes the needle" "$MU" \
    && mutant_killed "$([ "$RC_S" = 0 ] && echo 1 || echo 0)" drop-unterminated-tail "pending-unterminated.md U: (s) is red -- the tail is gone and the label line becomes the needle" && KILLS=$((KILLS + 1))
  gxq pending-connective.md       50 "" real.jsonl 1 "U: (r) is red -- only the too-short segment survives" "$MU" \
    && mutant_killed "$([ "$RC_R" = 0 ] && echo 1 || echo 0)" drop-unterminated-tail "pending-connective.md U: (r) is red -- only the too-short segment survives" && KILLS=$((KILLS + 1))
  gx pending-real.md             50 "" real.jsonl 0 "U: (d) unchanged -- a balanced citation has no tail" "$MU"
  gx pending-order-good-first.md 50 "" real.jsonl 0 "U: (p) unchanged" "$MU"
fi

# Mutant V -- the sibling's corpus report is captured and then not printed. The verdict does not
# move, which is the whole point: this arm is about ATTRIBUTION, and the exit code cannot see it.
echo "  -- mutant V: the corpus report is dropped from the accusation --"
MV="$(mutate drop-corpus-report 's@\[ -n "\$CITE_REPORT" \] && printf@[ -n "" ] \&\& printf@')" || FAIL=$((FAIL + 1))
if [ -n "${MV:-}" ]; then
  gsxq pending-crossfake.md corpus "" 1 "appears in NO genuine" "transcript(s) from" \
      "V: (t) is red -- the accusation no longer says which corpus produced it" "$MV" \
    && mutant_killed "$([ "$RC_T" = 0 ] && echo 1 || echo 0)" drop-corpus-report "pending-crossfake.md V: (t) is red -- the accusation no longer says which corpus produced it" && KILLS=$((KILLS + 1))
  # The twin: the verdict over the same corpus is unchanged -- only the attribution moved.
  gx pending-crossfake.md 50 corpus "" 1 "V: (j) unchanged -- the exit cannot see the dropped report" "$MV"
fi

# Mutant T -- cite_ts TRUNCATES a zone offset, the shape it had before this round: the regex
# stops before `+`/`-`, the naive part is handed to the verifier, and the owner reads it as UTC.
# Kills (w) ONLY -- every other citation here carries `Z`, which the truncating form returns
# whole, so this mutant and the fixed one are the same program for them.
echo "  -- mutant T: cite_ts truncates a zone offset (expect ONLY (w) to go red) --"
MT="$(mutate ts-truncates-offset 's@(Z|\[+-\]\[0-9\]{2}:?\[0-9\]{2})?@Z?@')" || FAIL=$((FAIL + 1))
if [ -n "${MT:-}" ]; then
  gxq pending-offset.md 50 "" real.jsonl 1 "T: (w) is red -- the offset stamp is read seven hours from the instant it names" "$MT" \
    && mutant_killed "$([ "$RC_W" = 0 ] && echo 1 || echo 0)" ts-truncates-offset "pending-offset.md T: (w) is red -- the offset stamp is read seven hours from the instant it names" && KILLS=$((KILLS + 1))
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
    mutant_killed "$([ "$RC_V" = 0 ] && echo 1 || echo 0)" drop-unbounded-count "pending-space.md B2: the count is gone while the verdict stays PASS -- (v) has teeth" && KILLS=$((KILLS + 1))
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %-26s B2 DID NOT FAIL (rc=%s): the count survived the mutation, so (v) is not testing it\n' "pending-space.md" "$rcb2"
  fi
  # The twin: a canonical citation's verdict does not move when only the count's rendering is gone.
  gx pending-real.md 50 "" real.jsonl 0 "B2: (d) unchanged -- the verdict never read the count" "$MB2"
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
    mutant_killed "$([ "$RC_X" = 0 ] && echo 1 || echo 0)" pass-drops-corpus "corpus-live P1: (x) is red -- the PASS says nothing about its corpus" && KILLS=$((KILLS + 1))
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
    mutant_killed "$([ "$RC_X" = 0 ] && echo 1 || echo 0)" pass-renders-constant "corpus-live P2: (x) is red -- a constant renders identically over both corpora" && KILLS=$((KILLS + 1))
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
    mutant_killed "$([ "$RC_Y" = 0 ] && echo 1 || echo 0)" report-on-every-path "pending-crossfake.md P3: (y) is red -- the accusation carries $MP3CL corpus lines" && KILLS=$((KILLS + 1))
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
    mutant_killed "$([ "$RC_Z" = 0 ] && echo 1 || echo 0)" vacuous-claims-corpus "pending-clean.md P4: (z) is red -- the vacuous PASS printed $MP4VL lines" && KILLS=$((KILLS + 1))
  else
    FAIL=$((FAIL + 1)); printf '  FAIL %-30s P4 SURVIVED: (z) cannot see a corpus line on a path that verified nothing\n' "pending-clean.md"
  fi
  N=$((N + 1))
  if pass_corpus_pair "$MP4"; then printf '  ok   %-30s P4: (x) unchanged\n' "corpus-live"
  else FAIL=$((FAIL + 1)); printf '  FAIL %-30s P4 moved (x) too -- the arms are entangled\n' "corpus-live"; fi
fi

# --matrix: every mutant above against every arm (a)..(z), each arm the same assertion its own row
# makes against the shipped validator, run in a subshell so its counters and output are discarded.
# GREEN = the arm holds against the mutant, as it does against the shipped validator in this run.
GX_ARMS="a b c d e f g h i j k l l-prime m n o p q r s t u v w x y z"
gx_arm() {  # $1 arm  $2 validator -> 0 when the arm holds
  ( v="$2"
    case "$1" in
      a) g pending-clean.md 50 real.jsonl 0 a "$v" ;;
      b) g pending-missing.md 50 real.jsonl 1 b "$v" ;;
      c) g pending-fabricated.md 50 real.jsonl 1 c "$v" ;;
      d) g pending-real.md 50 real.jsonl 0 d "$v" ;;
      e) g pending-legacy.md 50 real.jsonl 0 e "$v" ;;
      f) g pending-autonomous.md 50 real.jsonl 0 f "$v" ;;
      g) g pending-real.md 50 "" 1 g "$v" ;;
      h) gx pending-crosssession.md 50 "" corpus/gate.jsonl 1 h "$v" ;;
      i) gx pending-crosssession.md 50 corpus "" 0 i "$v" ;;
      j) gx pending-crossfake.md 50 corpus "" 1 j "$v" ;;
      k) gx pending-crosssession.md 50 corpus corpus/gate.jsonl 0 k "$v" ;;
      l) gx pending-real.md 50 dir-empty real.jsonl 0 l "$v" ;;
      l-prime) gx pending-real.md 50 dir-sidecar real.jsonl 0 l-prime "$v" ;;
      m) gsx pending-real.md dir-empty "" 1 "no readable transcript was provided" "appears in NO genuine" m "$v" ;;
      n) gsx pending-real.md dir-empty silent.jsonl 1 "appears in NO genuine" "no readable transcript was provided" n "$v" ;;
      o) gx pending-crossfake.md 50 corpus "" 1 o "$v" ;;
      p) g pending-order-good-first.md 50 real.jsonl 0 p "$v" ;;
      q) g pending-order-good-last.md 50 real.jsonl 1 q "$v" ;;
      r) g pending-connective.md 50 real.jsonl 0 r "$v" ;;
      s) g pending-unterminated.md 50 real.jsonl 0 s "$v" ;;
      t) gsx pending-crossfake.md corpus "" 1 "transcript(s) from" "IMPOSSIBLE-TOKEN-NEVER-EMITTED" t "$v" ;;
      u) g pending-before.md 50 real.jsonl 1 u "$v" ;;
      v) o="$(bash "$v" --escalations "$ROOT/pending-space.md" --sprint 50 --transcript "$ROOT/real.jsonl" 2>/dev/null)" \
           && grep -qF -- "unbounded-citation: 1" <<<"$o" ;;
      w) g pending-offset.md 50 real.jsonl 0 w "$v" ;;
      x) pass_corpus_pair "$v" ;;
      y) [ "$(cite_lines "$v")" -eq 1 ] ;;
      z) [ "$(vac_lines "$v")" -eq 1 ] ;;
      *) exit 3 ;;
    esac ) >/dev/null 2>&1
}
if [ "$MATRIX" = 1 ]; then
  echo "  -- MATRIX: each corpus-arm mutant against every arm (a)..(z) --"
  # The shipped validator first: the matrix reads a row as TRIPPED only against an arm that holds here.
  GX_BASE_RED=""
  for a in $GX_ARMS; do gx_arm "$a" "$VALIDATOR" || GX_BASE_RED="$GX_BASE_RED $a"; done
  if [ -z "$GX_BASE_RED" ]; then ok "MX-base every arm (a)..(z) holds against the shipped validator"
  else bad "MX-base arm(s)$GX_BASE_RED do not hold against the shipped validator; no matrix row below means anything"; fi
  for mv in "no-dir-arm|${MA:-}" "dir-loses-order|${MC:-}" "revert-existence-only|${MR:-}" \
            "clear-after-chain|${MW:-}" "last-segment-wins|${MQ:-}" "drop-unterminated-tail|${MU:-}" \
            "drop-corpus-report|${MV:-}" "ts-truncates-offset|${MT:-}" "drop-unbounded-count|${MB2:-}" \
            "pass-drops-corpus|${MP1:-}" "pass-renders-constant|${MP2:-}" "report-on-every-path|${MP3:-}" \
            "vacuous-claims-corpus|${MP4:-}"; do
    mp="${mv#*|}"
    [ -n "$mp" ] || { bad "MX-${mv%%|*} was never built, so it has no matrix row"; continue; }
    for a in $GX_ARMS; do
      if gx_arm "$a" "$mp"; then matrix_row "${mv%%|*}" "$a" 0 GREEN no
      else matrix_row "${mv%%|*}" "$a" 1 TRIPPED yes; fi
      MROWS=$((MROWS + 1))
    done
  done
fi

# --- an EMPTY escalations file is the ABSENT state, and only an empty one ---------------------
# A file that exists and holds no non-whitespace byte used to fall through to the parser, parse
# zero records and print the ordinary nothing-in-scope line -- a verdict over entries when there
# were none. The gate mode now prints the absent-file `EXAMINED NOTHING` line for it.
#
# SIX CELLS, SCORED AS ONE STRING, so a mutant can be held to moving ONLY its own cell:
#   A empty          rc 0, the token, and the "present but empty" reason
#   B whitespace     the same -- a `[ -s ]` fix calls this file populated and fails here
#   C absent         rc 0, the token, the absent-file reason and NOT the empty one (unchanged)
#   D zero-record    POPULATED, parsing to zero records, and NO token. Two seeds: heading-only
#                    (a title and a prose line) and pending-clean.md (entries, none in scope,
#                    which must still print the ordinary nothing-in-scope line). ONE cell,
#                    because both are zero-record files and no zero-record predicate can move
#                    one without the other -- as two cells, M-zero-records could never fail
#                    only its own.
#   E finding        pending-missing.md -> rc 1, the missing-citation message
#   F any-authorized an empty file is NO citation: rc 1 and `NONE:`, never the token
# Every cell is PRESENCE-shaped on at least one conjunct, so a subject that prints nothing
# fails every one of them.
echo
echo "  -- an empty escalations file EXAMINED NOTHING; a populated one never says so --"
EN_SRC_DIR="$(cd "$(dirname "$VALIDATOR")" && pwd)"
EN_BASE="$(basename "$VALIDATOR")"
EN_IS_DIST=0
case "$EN_SRC_DIR" in */core/scripts) EN_IS_DIST=1 ;; esac
EN_CELLS=""
en_cells() {  # $1 validator -> sets EN_CELLS to six 0/1 characters, A..F
  local v="$1" o o2 e rc rc2 c=""
  o="$(bash "$v" --escalations "$ROOT/pending-empty.md" --sprint 50 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 0 ] && grep -qF "EXAMINED NOTHING" <<<"$o" && grep -qF "present but empty" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  o="$(bash "$v" --escalations "$ROOT/pending-blank.md" --sprint 50 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 0 ] && grep -qF "EXAMINED NOTHING" <<<"$o" && grep -qF "present but empty" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  o="$(bash "$v" --escalations "$ROOT/pending-never-written.md" --sprint 50 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 0 ] && grep -qF "EXAMINED NOTHING" <<<"$o" && grep -qF "no escalations file" <<<"$o" \
     && ! grep -qF "present but empty" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  o="$(bash "$v" --escalations "$ROOT/pending-heading.md" --sprint 50 2>/dev/null)"; rc=$?
  o2="$(bash "$v" --escalations "$ROOT/pending-clean.md" --sprint 50 2>/dev/null)"; rc2=$?
  if [ "$rc" -eq 0 ] && [ "$rc2" -eq 0 ] && ! grep -qF "EXAMINED NOTHING" <<<"$o$o2" \
     && grep -qF "no S50 RESOLVED/OVERRIDDEN escalation requires" <<<"$o" \
     && grep -qF "no S50 RESOLVED/OVERRIDDEN escalation requires" <<<"$o2"; then c="${c}1"; else c="${c}0"; fi
  e="$(bash "$v" --escalations "$ROOT/pending-missing.md" --sprint 50 --transcript "$ROOT/real.jsonl" 2>&1 >/dev/null)"; rc=$?
  if [ "$rc" -eq 1 ] && grep -qF "carries no 'Operator authorization:'" <<<"$e"; then c="${c}1"; else c="${c}0"; fi
  o="$(bash "$v" --any-authorized "$ROOT/pending-empty.md" 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^NONE:' <<<"$o" && ! grep -qF "EXAMINED NOTHING" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  EN_CELLS="$c"
}
en_names="A:empty B:whitespace C:absent D:populated-zero-record E:finding F:any-authorized"
en_report() {  # $1 cells -> one ok/FAIL line per cell
  local i=0 nm
  for nm in $en_names; do
    i=$((i + 1)); N=$((N + 1))
    if [ "$(printf '%s' "$1" | cut -c"$i")" = "1" ]; then printf '  ok   %-30s empty-file cell %s holds\n' "${nm#*:}" "${nm%%:*}"
    else FAIL=$((FAIL + 1)); printf '  FAIL %-30s empty-file cell %s does not hold\n' "${nm#*:}" "${nm%%:*}"; fi
  done
}
en_cells "$VALIDATOR"
# A SUBJECT THAT PREDATES THE FIX. This fixture ships, and a consumer may run it one pull ahead
# of the validator: then cells A and B read 0 and nothing else moves. That is SKIP on a consumer
# and FAIL in the distribution, where the subject must be present.
if [ "$(printf '%s' "$EN_CELLS" | cut -c1-2)" = "00" ] && [ "$(printf '%s' "$EN_CELLS" | cut -c3-6)" = "1111" ] \
   && [ "$EN_IS_DIST" -ne 1 ]; then
  printf '  SKIP %-30s the installed validator predates the empty-file verdict; this fixture ships one pull ahead of it\n' "pending-empty.md"
else
  en_report "$EN_CELLS"

  # --- the three mutants, each in a copy of the WHOLE scripts dir -----------------------------
  # The validator resolves validate-steering-budget.sh beside itself, so a lone copy fails cell F
  # for a reason the mutant does not own. The control is the same copy, unmutated, and must score
  # all seven cells -- which include six presence rows, so a copy that never ran cannot pass it.
  EN_MW="$(mktemp -d)"; trap 'rm -rf "$ROOT" "$MWORK" "$EN_MW"' EXIT
  # en_mk RUNS INSIDE `$( )`: anything it echoes becomes the captured PATH and any counter it
  # bumps dies with the subshell. So it writes its refusal to EN_MW/<name>.why, prints no path,
  # and en_score fails the empty path with that reason.
  en_mk() {  # $1 name  $2 anchor (literal, must match exactly one line)  $3 replacement file
    local d="$EN_MW/$1" n
    cp -R "$EN_SRC_DIR" "$d" || { echo "could not copy $EN_SRC_DIR" > "$EN_MW/$1.why"; return 1; }
    [ -f "$d/validate-steering-budget.sh" ] || { echo "the steering sibling is missing from the copy" > "$EN_MW/$1.why"; return 1; }
    [ -n "$2" ] || { printf '%s\n' "$d/$EN_BASE"; return 0; }
    n="$(grep -cF -- "$2" "$VALIDATOR")" || n=0
    [ "$n" -eq 1 ] || { echo "anchor matches $n line(s), not 1 -- re-anchor it, never relax the arm" > "$EN_MW/$1.why"; return 1; }
    awk -v A="$2" -v R="$3" '
      index($0, A) { while ((getline l < R) > 0) print l; close(R); next }
      { print }' "$VALIDATOR" > "$d/$EN_BASE"
    cmp -s "$VALIDATOR" "$d/$EN_BASE" && { echo "changed no bytes -- it would score as a kill" > "$EN_MW/$1.why"; return 1; }
    bash -n "$d/$EN_BASE" 2>/dev/null || { echo "does not parse" > "$EN_MW/$1.why"; return 1; }
    printf '%s\n' "$d/$EN_BASE"
  }
  # $1 the base flag (EN_B: the unmutated copy scored every cell in this run)  $2 name
  # $3 path-or-empty  $4 expected cells  $5 why  $6 mk-name
  en_score() {
    N=$((N + 1))
    if [ -z "$3" ]; then
      FAIL=$((FAIL + 1)); printf '  FAIL %-30s was never built: %s\n' "$2" "$(cat "$EN_MW/$6.why" 2>/dev/null || echo 'no reason recorded')"; return
    fi
    en_cells "$3"
    [ "$MATRIX" = 1 ] && cell_matrix "$2" en "$en_names" 111111 "$EN_CELLS"
    if [ "$EN_CELLS" = "$4" ]; then mutant_killed "$1" "$2" "$2 $4 -> $EN_CELLS ($5)" && KILLS=$((KILLS + 1))
    else FAIL=$((FAIL + 1)); printf '  FAIL %-30s scored %s, wanted %s -- %s\n' "$2" "$EN_CELLS" "$4" "$5"; fi
  }
  EN_R="$EN_MW/replace"; mkdir -p "$EN_R"
  printf '%s\n' '  if false; then' > "$EN_R/revert"
  printf '%s\n' 'if [ -z "$RECORDS" ]; then echo "OK: EXAMINED NOTHING — zero parsed records ($ESCALATIONS)."; exit 0; fi' \
                'if [ -z "$RECORDS" ]; then' > "$EN_R/zero"
  printf '%s\n' 'STEER_SCRIPT="$(cd "$(dirname "$0")" && pwd)/validate-steering-budget.sh"' \
                'if [ -f "$ESCALATIONS" ] && ! grep -q '"'"'[^[:space:]]'"'"' "$ESCALATIONS"; then echo "OK: EXAMINED NOTHING — escalations file present but empty ($ESCALATIONS); nothing to check."; exit 0; fi' > "$EN_R/hoist"
  EN_CTL="$(en_mk control "" "")" || EN_CTL=""
  # M-control: the unmutated copy of the whole dir. EN_B, the base flag every empty-file kill is
  # gated on, is raised only in this arm's passing branch.
  N=$((N + 1)); EN_B=0
  if [ -n "$EN_CTL" ]; then en_cells "$EN_CTL"; else EN_CELLS="never-built:$(cat "$EN_MW/control.why" 2>/dev/null)"; fi
  if [ "$EN_CELLS" = 111111 ]; then
    EN_B=1; ok "M-control 111111 -> $EN_CELLS (an unmutated copy of the whole dir scores every cell)"
  else
    bad "M-control scored $EN_CELLS, wanted 111111 -- no empty-file mutant below can be scored"
  fi
  KF_EXTRA=$((KF_EXTRA + 3))
  EN_M1="$(en_mk revert 'if [ "$ESC_BLANK_RC" -eq 1 ]; then' "$EN_R/revert")" || EN_M1=""
  en_score "$EN_B" "M-revert" "$EN_M1" 001111 "the fix removed: ONLY the empty and whitespace cells go red" revert
  EN_M2="$(en_mk zero-records 'if [ -z "$RECORDS" ]; then' "$EN_R/zero")" || EN_M2=""
  en_score "$EN_B" "M-zero-records" "$EN_M2" 111011 "zero parsed records read as empty: ONLY the populated-zero-record cell goes red" zero-records
  EN_M3="$(en_mk hoist 'STEER_SCRIPT="$(cd "$(dirname "$0")" && pwd)/validate-steering-budget.sh"' "$EN_R/hoist")" || EN_M3=""
  en_score "$EN_B" "M-hoist" "$EN_M3" 111110 "the check above the mode split: ONLY the --any-authorized cell goes red" hoist
fi

# --- an UNREADABLE or NON-REGULAR escalations path REFUSES (gate mode), exit 2 ------------------------
# The blank probe's grep exits 2 on a file it cannot read, and the gate mode branched on `-eq 1` alone:
# the status fell through, the parser's read failure was swallowed, and the run printed the ordinary
# "no S<N> ... requires an operator citation" line over a file nobody read. A DIRECTORY at the path
# failed `-f` and printed "no escalations file" -- the line Check 2a reads as a pass.
#
# SIX CELLS, ONE STRING, each mutant held to the cells its layer owns:
#   A  mode-000 file carrying an S50 RESOLVED entry with no citation -> exit 2, `could not be read`
#   B  a DIRECTORY at the path                                   -> exit 2, `is not a regular file`
#   C  a DANGLING SYMLINK at the path                            -> exit 2, `is not a regular file`
#   D  a READABLE file whose blank probe grep exits 2 (PATH stub; must FIRE) -> exit 2, `grep exited 2`
#   E  near-miss: whitespace-only readable file                  -> exit 0, "present but empty"
#   F  near-miss: pending-missing.md, readable, a real finding   -> exit 1, unchanged
# A-D are presence-shaped. Cell A is `S` where mode 000 does not stop this process reading (root).
echo
echo "  -- an unreadable or non-regular escalations path REFUSES; a readable one is judged --"
ER="$(mktemp -d)"; trap 'chmod -R u+rwX "$ER" 2>/dev/null; rm -rf "$ROOT" "$MWORK" "${EN_MW:-}" "$ER"' EXIT
ER_LOCKED="$ER/pending-locked.md"; cp "$ROOT/pending-missing.md" "$ER_LOCKED"; chmod 000 "$ER_LOCKED"
ER_DIR="$ER/pending-dir.md"; mkdir -p "$ER_DIR"
ER_LINK="$ER/pending-dangling.md"; ln -s "$ER/pending-target-never-written.md" "$ER_LINK"
ER_IO="$ER/pending-io.md"; cp "$ROOT/pending-missing.md" "$ER_IO"
ER_SKIP_A=""
if [ "$(id -u)" -eq 0 ]; then ER_SKIP_A="running as root, which reads a mode-000 file"
elif cat "$ER_LOCKED" >/dev/null 2>&1; then ER_SKIP_A="this host reads a mode-000 file, so the seed cannot express unreadable"; fi
[ -n "$ER_SKIP_A" ] && printf '  SKIP %-30s refusal cell A -- %s\n' "pending-locked.md" "$ER_SKIP_A"
N=$((N + 1))
if [ -L "$ER_LINK" ] && [ ! -e "$ER_LINK" ]; then printf '  ok   %-30s the dangling-symlink seed is a link to a missing target\n' "pending-dangling.md"
else FAIL=$((FAIL + 1)); printf '  FAIL %-30s FIXTURE BROKEN: the dangling-symlink seed is not dangling\n' "pending-dangling.md"; fi
ER_STUB="$ER/stub"; mkdir -p "$ER_STUB"
ER_REALGREP="$(command -v grep)" || { echo "FIXTURE ERROR: grep is not on PATH" >&2; exit 2; }
{
  printf '#!/bin/bash\ncase "$*" in\n'
  printf '  %s) printf "x\\n" >> "%s/LOG"; echo "grep: forced failure" >&2; exit 2 ;;\n' "'-q [^[:space:]] '*" "$ER_STUB"
  printf 'esac\nexec "%s" "$@"\n' "$ER_REALGREP"
} > "$ER_STUB/grep"
chmod +x "$ER_STUB/grep"
ER_RC=0; ER_O=""; ER_E=""
er_run() {  # <validator> <file> [stub-dir] -> ER_RC ER_O ER_E
  local p="$PATH"
  [ -n "${3:-}" ] && p="$3:$PATH"
  : > "$ER_STUB/LOG"
  ER_O="$(PATH="$p" bash "$1" --escalations "$2" --sprint 50 --transcript "$ROOT/real.jsonl" 2>"$ER/err")"; ER_RC=$?
  ER_E="$(cat "$ER/err")"
}
er_refused() { [ "$ER_RC" -eq 2 ] && [ -z "$ER_O" ] && grep -qE "^REFUSED: .*$1" <<<"$ER_E"; }
ER_CELLS=""
er_cells() {  # <validator> -> ER_CELLS
  local v="$1" c=""
  if [ -n "$ER_SKIP_A" ]; then c="${c}S"
  else er_run "$v" "$ER_LOCKED"; if er_refused 'could not be read'; then c="${c}1"; else c="${c}0"; fi; fi
  er_run "$v" "$ER_DIR";  if er_refused 'is not a regular file'; then c="${c}1"; else c="${c}0"; fi
  er_run "$v" "$ER_LINK"; if er_refused 'is not a regular file'; then c="${c}1"; else c="${c}0"; fi
  er_run "$v" "$ER_IO" "$ER_STUB"
  if [ -s "$ER_STUB/LOG" ] && er_refused 'failed \(grep exited 2\)'; then c="${c}1"; else c="${c}0"; fi
  er_run "$v" "$ROOT/pending-blank.md"
  if [ "$ER_RC" -eq 0 ] && grep -qF 'present but empty' <<<"$ER_O" && ! grep -qF 'REFUSED' <<<"$ER_O$ER_E"; then c="${c}1"; else c="${c}0"; fi
  er_run "$v" "$ROOT/pending-missing.md"
  if [ "$ER_RC" -eq 1 ] && grep -qF "carries no 'Operator authorization:'" <<<"$ER_E" && ! grep -qF 'REFUSED' <<<"$ER_O$ER_E"; then c="${c}1"; else c="${c}0"; fi
  ER_CELLS="$c"
}
er_names="A:mode-000 B:directory C:dangling-symlink D:grep-status-2 E:whitespace-near-miss F:finding-near-miss"
er_want() { if [ -n "$ER_SKIP_A" ]; then printf 'S%s' "${1#?}"; else printf '%s' "$1"; fi; }
er_cells "$VALIDATOR"
# A SUBJECT THAT PREDATES THE REFUSAL: B, C, D read 0 and E, F hold. SKIP on a consumer; FAIL here.
if [ "$(printf '%s' "$ER_CELLS" | cut -c2-4)" = "000" ] && [ "$(printf '%s' "$ER_CELLS" | cut -c5-6)" = "11" ] \
   && [ "$EN_IS_DIST" -ne 1 ]; then
  printf '  SKIP %-30s the installed validator predates the unreadable-file refusal; this fixture ships one pull ahead of it\n' "pending-locked.md"
else
  i=0
  for nm in $er_names; do
    i=$((i + 1))
    case "$(printf '%s' "$ER_CELLS" | cut -c"$i")" in
      1) N=$((N + 1)); printf '  ok   %-30s refusal cell %s holds\n' "${nm#*:}" "${nm%%:*}" ;;
      S) ;;
      *) N=$((N + 1)); FAIL=$((FAIL + 1)); printf '  FAIL %-30s refusal cell %s does not hold (cells=%s)\n' "${nm#*:}" "${nm%%:*}" "$ER_CELLS" ;;
    esac
  done

  # --- the mutants: one per layer of the guard, and one reverting EVERY layer -----------------------
  # Siblings in ONE copy of the whole scripts dir, so validate-steering-budget.sh is beside each; the
  # unmutated sibling control must score every presence cell, so a copy that cannot run is not a kill.
  ER_MD="$ER/mut"
  cp -R "$EN_SRC_DIR" "$ER_MD" || { FAIL=$((FAIL + 1)); echo "  FAIL refusal mutants: could not copy $EN_SRC_DIR"; }
  ER_SRC="$ER_MD/$EN_BASE"
  N=$((N + 1))
  if [ -f "$ER_MD/validate-steering-budget.sh" ]; then printf '  ok   %-30s the mutant copy carries the steering sibling\n' "R-harness"
  else FAIL=$((FAIL + 1)); printf '  FAIL %-30s the steering sibling is missing from the mutant copy\n' "R-harness"; fi
  # er_sub <out> <anchor> <replacement> [...] -- a COPY of ER_SRC, each anchor on exactly one line.
  # Strings reach awk through ENVIRON, never `-v`, which strips a level of backslash escaping.
  ER_WHY=""
  er_sub() {
    local out="$1" n
    shift
    cp "$ER_SRC" "$out.work" || { ER_WHY="could not copy"; return 1; }
    while [ "$#" -ge 2 ]; do
      n="$(grep -cF -- "$1" "$out.work")" || n=0
      [ "$n" -eq 1 ] || { ER_WHY="anchor matches $n line(s), not 1 -- re-anchor it, never relax the arm: $1"; return 1; }
      A="$1" R="$2" awk '{ i = index($0, ENVIRON["A"]); if (i) $0 = substr($0, 1, i - 1) ENVIRON["R"] substr($0, i + length(ENVIRON["A"])); print }' \
        "$out.work" > "$out.next" || { ER_WHY="awk died applying: $1"; return 1; }
      mv "$out.next" "$out.work"
      shift 2
    done
    cmp -s "$ER_SRC" "$out.work" && { ER_WHY="changed no bytes -- it would score as a kill"; return 1; }
    mv "$out.work" "$out"
  }
  ER_G1='if { [ -e "$ESCALATIONS" ] || [ -L "$ESCALATIONS" ]; } && [ ! -f "$ESCALATIONS" ]; then'
  ER_G1L='{ [ -e "$ESCALATIONS" ] || [ -L "$ESCALATIONS" ]; }'
  ER_G2='if [ "$ESC_BLANK_RC" -gt 1 ]; then'
  ER_G3='if [ ! -r "$ESCALATIONS" ]; then'
  # <base flag: ER_B, the unmutated copy scored every cell in this run> <label> <name> <want>
  # <anchor> <replacement> [...]
  er_score() {
    local flag="$1" label="$2" name="$3" want out
    want="$(er_want "$4")"
    # A want that, once the SKIP mask is applied, equals the control's is a mutant whose every
    # deciding cell is masked on this host: its "kill" would be the control's own vector. SKIP it,
    # call no kill helper, and leave it out of KF_EXTRA (ER_SKIPPED).
    if [ "$want" = "$(er_want 111111)" ]; then
      ER_SKIPPED=$((ER_SKIPPED + 1))
      printf '  SKIP %-30s wants %s, which differs from the control only in a masked cell -- %s\n' "$label" "$4" "$ER_SKIP_A"
      return 0
    fi
    shift 4
    out="$ER_MD/_er_$name.sh"
    N=$((N + 1))
    if ! er_sub "$out" "$@"; then FAIL=$((FAIL + 1)); printf '  FAIL %-30s DID NOT APPLY: %s\n' "$label" "$ER_WHY"; return 0
    elif ! bash -n "$out" 2>/dev/null; then FAIL=$((FAIL + 1)); printf '  FAIL %-30s DID NOT APPLY: the copy does not parse\n' "$label"; return 0; fi
    er_cells "$out"
    [ "$MATRIX" = 1 ] && cell_matrix "$label" er "$er_names" "$ER_CTL_CELLS" "$ER_CELLS"
    if [ "$ER_CELLS" = "$want" ]; then mutant_killed "$flag" "$label" "$label $want -> $ER_CELLS" && KILLS=$((KILLS + 1))
    else FAIL=$((FAIL + 1)); printf '  FAIL %-30s scored %s, wanted %s\n' "$label" "$ER_CELLS" "$want"; fi
  }
  # R-control: the unmutated copy beside its sibling. ER_B, the base flag every refusal kill is
  # gated on, is raised only in this arm's passing branch.
  N=$((N + 1)); ER_B=0
  cp "$ER_SRC" "$ER_MD/_er_ctl.sh"
  er_cells "$ER_MD/_er_ctl.sh"; ER_CTL_CELLS="$ER_CELLS"
  if [ "$ER_CELLS" = "$(er_want 111111)" ]; then
    ER_B=1; ok "R-control $(er_want 111111) -> $ER_CELLS"
  else
    bad "R-control scored $ER_CELLS, wanted $(er_want 111111) -- no refusal mutant below can be scored"
  fi
  ER_SKIPPED=0
  er_score "$ER_B" "R-revert-all"      revert-all      000011 "$ER_G1" 'if false; then' "$ER_G2" 'if false; then'
  er_score "$ER_B" "R-nonregular"      nonregular      100111 "$ER_G1" 'if false; then'
  er_score "$ER_B" "R-no-symlink"      no-symlink      110111 "$ER_G1L" '[ -e "$ESCALATIONS" ]'
  er_score "$ER_B" "R-rc"              rc              011011 "$ER_G2" 'if false; then'
  er_score "$ER_B" "R-readable-never"  readable-never  011111 "$ER_G3" 'if false; then'
  er_score "$ER_B" "R-readable-always" readable-always 111011 "$ER_G3" 'if true; then'
  # Six refusal kills, less any a masked cell made unscorable on this host.
  KF_EXTRA=$((KF_EXTRA + 6 - ER_SKIPPED))
fi

# --- the citation FLOOR is measured on the NORMALISED needle, and the predicate owns it ----------
# Every caller compared bash `${#quote}` against 12 while `--cite` collapses whitespace and trims
# before matching, so `"          yes"` (13 raw, 3 normalised) and twelve spaces (EMPTY normalised,
# and `includes("")` is true of every turn) both verified against any operator turn in the window.
# corpus-short holds a genuine in-window operator turn carrying `yes`, so the pre-fix build MATCHES
# both: every cell below is about the floor and nothing else.
#
# FOURTEEN CELLS, ONE STRING, so each mutant is held to moving only the cells it owns:
#   P  padded quote                   -> rc 1, "(3 chars once whitespace is collapsed)"
#   Q  blank quote of 12 spaces       -> rc 1, "(0 chars once whitespace is collapsed)"
#   R  the incident, quoted WHOLE     -> rc 0, and the PASS names a 2-transcript corpus
#   S  the incident, half of it       -> rc 1, "(7 chars once whitespace is collapsed)"
#   T  --any-authorized, padded only  -> rc 1, `NONE: 1 RESOLVED/OVERRIDDEN`
#   t  --any-authorized, whole quote  -> rc 0, `AUTHORIZED: 1 of 1` (T's ALLOW twin)
#   U  --cite twelve spaces, corpus   -> rc 2, stdout exactly NOMATCH-SHORT
#   V  --cite twelve spaces, empty dir-> rc 2, NOMATCH-SHORT (pre-empts the no-records verdict)
#   W  --cite "yes", corpus           -> rc 2, NOMATCH-SHORT (short in RAW bytes too)
#   X  --cite the whole incident      -> rc 0, `MATCH 2026-10-05T13:25:14.171Z` (U's ALLOW twin)
#   Np/Nb   NBSP-padded `yes` / twelve NBSP at the gate   -> rc 1, the normalised length 3 / 0 named
#   Na/Nab  the same two under --any-authorized           -> rc 1, `NONE: 1 RESOLVED/OVERRIDDEN`
# Every cell is PRESENCE-shaped, so a subject that prints nothing scores 0 on all fourteen.
echo
echo "  -- the citation floor is measured on the NORMALISED needle --"
FL_SRC_DIR="$(cd "$(dirname "$VALIDATOR")" && pwd)"
FL_BASE="$(basename "$VALIDATOR")"
echo "  escalation-citation: resolved predicate = $FL_SRC_DIR/validate-steering-budget.sh"
# THE INCIDENT FILE IS NOT THE MEMBER THE READER OPENS FIRST. Asked of the reader's own call,
# because shell glob order and `readdirSync` order are two different claims about one directory.
FL_FIRST="$(node -e 'const fs=require("fs");console.log(fs.readdirSync(process.argv[1]).filter(f=>f.endsWith(".jsonl"))[0]||"")' "$ROOT/corpus-short" 2>/dev/null)"
N=$((N + 1))
if [ -n "$FL_FIRST" ] && [ "$FL_FIRST" != "b-incident.jsonl" ] \
   && [ "$(ls "$ROOT/corpus-short" | grep -c '\.jsonl$')" -ge 2 ]; then
  printf '  ok   %-30s the reader opens %s first; the incident turn is in the second member\n' "corpus-short" "$FL_FIRST"
else
  FAIL=$((FAIL + 1)); printf '  FAIL %-30s FIXTURE BROKEN: first member read is "%s" -- the incident must not be first in a >=2-file corpus\n' "corpus-short" "$FL_FIRST"
fi
FL_CELLS=""
fl_cells() {  # $1 directory holding the validator and its steering sibling -> FL_CELLS
  local d="$1" v="$1/$FL_BASE" s="$1/validate-steering-budget.sh" o rc c=""
  fl_g() { o="$(bash "$v" --escalations "$ROOT/$1" --sprint 50 --transcript-dir "$ROOT/corpus-short" 2>&1)"; rc=$?; }
  fl_g pending-padded.md
  if [ "$rc" -eq 1 ] && grep -qF "(3 chars once whitespace is collapsed), too short" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  fl_g pending-blankq.md
  if [ "$rc" -eq 1 ] && grep -qF "(0 chars once whitespace is collapsed), too short" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  fl_g pending-incident-whole.md
  if [ "$rc" -eq 0 ] && grep -qF "cite: scanned 2 transcript(s)" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  fl_g pending-incident-short.md
  if [ "$rc" -eq 1 ] && grep -qF "(7 chars once whitespace is collapsed), too short" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  o="$(bash "$v" --any-authorized "$ROOT/pending-padded.md" 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^NONE: 1 RESOLVED/OVERRIDDEN' <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  o="$(bash "$v" --any-authorized "$ROOT/pending-incident-whole.md" 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 0 ] && grep -q '^AUTHORIZED: 1 of 1 ' <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  o="$(bash "$s" --dir "$ROOT/corpus-short" --cite "            " 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 2 ] && [ "$o" = "NOMATCH-SHORT" ]; then c="${c}1"; else c="${c}0"; fi
  o="$(bash "$s" --dir "$ROOT/dir-empty" --cite "            " 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 2 ] && [ "$o" = "NOMATCH-SHORT" ]; then c="${c}1"; else c="${c}0"; fi
  o="$(bash "$s" --dir "$ROOT/corpus-short" --cite "yes" 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 2 ] && [ "$o" = "NOMATCH-SHORT" ]; then c="${c}1"; else c="${c}0"; fi
  o="$(bash "$s" --dir "$ROOT/corpus-short" --cite "1. Yes. 2. Yes." 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 0 ] && [ "$o" = "MATCH 2026-10-05T13:25:14.171Z" ]; then c="${c}1"; else c="${c}0"; fi
  # The NBSP pair. At the GATE either layer may refuse -- the caller naming its normalised length or
  # the predicate's NOMATCH-SHORT line naming the same 3 / 0 -- so these two cells hold the VERDICT
  # and the length and stay agnostic about which layer spoke. At --any-authorized the caller's own
  # measure is the whole check, which is the cell an ASCII-only normaliser cannot pass.
  fl_g pending-nbsp-padded.md
  if [ "$rc" -eq 1 ] && grep -qE "\(3 chars once whitespace is collapsed\), too short|NOMATCH-SHORT: the cited quote is 3 character" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  fl_g pending-nbsp-blank.md
  if [ "$rc" -eq 1 ] && grep -qE "\(0 chars once whitespace is collapsed\), too short|NOMATCH-SHORT: the cited quote is 0 character" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  o="$(bash "$v" --any-authorized "$ROOT/pending-nbsp-padded.md" 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^NONE: 1 RESOLVED/OVERRIDDEN' <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  o="$(bash "$v" --any-authorized "$ROOT/pending-nbsp-blank.md" 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^NONE: 1 RESOLVED/OVERRIDDEN' <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  # An EMPTY needle is still a citation. A build keying cite mode on the TEXT rather than on the
  # flag having been passed falls through to the checks mode, whose clean rc 0 a caller reads as
  # MATCH. With and without --authorized-at, because the bound is its own branch in the wrapper.
  o="$(bash "$s" --dir "$ROOT/corpus-short" --cite "" 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 2 ] && [ "$o" = "NOMATCH-SHORT" ]; then c="${c}1"; else c="${c}0"; fi
  o="$(bash "$s" --dir "$ROOT/corpus-short" --cite "" --authorized-at 2026-10-05T13:25:14Z 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 2 ] && [ "$o" = "NOMATCH-SHORT" ]; then c="${c}1"; else c="${c}0"; fi
  # THE FLOOR'S VALUE. Eleven normalised characters a genuine turn carries -> refused; twelve
  # from the same turn -> MATCH. A floor moved either way breaks exactly one of the pair.
  o="$(bash "$s" --dir "$ROOT/corpus-short" --cite "  go ahead ok  " 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 2 ] && [ "$o" = "NOMATCH-SHORT" ]; then c="${c}1"; else c="${c}0"; fi
  o="$(bash "$s" --dir "$ROOT/corpus-short" --cite "go ahead ok," 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 0 ] && [ "$o" = "MATCH 2026-10-05T12:05:00Z" ]; then c="${c}1"; else c="${c}0"; fi
  FL_CELLS="$c"
}
fl_names="P:padded Q:blank R:incident-whole S:incident-short T:any-authorized-padded t:any-authorized-whole U:cite-blank-corpus V:cite-blank-empty-dir W:cite-short-raw X:cite-whole-match Np:nbsp-padded Nb:nbsp-blank Na:any-authorized-nbsp-padded Nab:any-authorized-nbsp-blank E:cite-empty Ea:cite-empty-authorized-at F11:cite-eleven-refused F12:cite-twelve-match"
fl_cells "$FL_SRC_DIR"
# A SUBJECT THAT PREDATES THE FLOOR. This fixture ships, and a consumer may run it one pull ahead
# of its validators: the pre-fix build matched P, Q and both NBSP quotes, accepted T and both NBSP
# --any-authorized entries, has no NOMATCH-SHORT and a too-short message that names no length,
# while R, t, X and the twelve-character MATCH hold; an empty needle falls through to the checks
# mode and eleven characters verify. SKIP on a consumer; FAIL in the distribution.
if [ "$FL_CELLS" = "001001000100000001" ] && [ "$EN_IS_DIST" -ne 1 ]; then
  printf '  SKIP %-30s the installed validators predate the normalised citation floor; this fixture ships one pull ahead of them\n' "pending-padded.md"
else
  i=0
  for nm in $fl_names; do
    i=$((i + 1)); N=$((N + 1))
    if [ "$(printf '%s' "$FL_CELLS" | cut -c"$i")" = "1" ]; then printf '  ok   %-30s floor cell %s holds\n' "${nm#*:}" "${nm%%:*}"
    else FAIL=$((FAIL + 1)); printf '  FAIL %-30s floor cell %s does not hold (cells=%s)\n' "${nm#*:}" "${nm%%:*}" "$FL_CELLS"; fi
  done

  # --- the mutants, each in a copy of the WHOLE scripts dir -----------------------------------
  # The validator resolves the predicate beside itself, so every copy carries both; the unmutated
  # copy must score all fourteen presence cells before any mutant verdict is read. Strings reach awk
  # through ENVIRON, never `-v`, which strips a level of backslash escaping.
  FL_MW="$(mktemp -d)"; trap 'chmod -R u+rwX "${ER:-/nonexistent}" 2>/dev/null; rm -rf "$ROOT" "$MWORK" "${EN_MW:-}" "${ER:-}" "$FL_MW"' EXIT
  FL_WHY=""
  fl_mk() {  # $1 name  $2 target basename  $3 anchor (one line, exactly once)  $4 replacement -> FL_DIR
    local d="$FL_MW/$1" n
    FL_DIR=""
    cp -R "$FL_SRC_DIR" "$d" || { FL_WHY="could not copy $FL_SRC_DIR"; return 1; }
    [ -f "$d/validate-steering-budget.sh" ] && [ -f "$d/$FL_BASE" ] || { FL_WHY="the copy lacks the validator or its predicate"; return 1; }
    [ -n "$2" ] || { FL_DIR="$d"; return 0; }
    n="$(grep -cF -- "$3" "$FL_SRC_DIR/$2")" || n=0
    [ "$n" -eq 1 ] || { FL_WHY="anchor matches $n line(s) in $2, not 1 -- re-anchor it, never relax the arm"; return 1; }
    A="$3" R="$4" awk '{ i = index($0, ENVIRON["A"]); if (i) $0 = substr($0, 1, i - 1) ENVIRON["R"] substr($0, i + length(ENVIRON["A"])); print }' \
      "$FL_SRC_DIR/$2" > "$d/$2" || { FL_WHY="awk died"; return 1; }
    cmp -s "$FL_SRC_DIR/$2" "$d/$2" && { FL_WHY="changed no bytes -- it would score as a kill"; return 1; }
    bash -n "$d/$2" 2>/dev/null || { FL_WHY="does not parse"; return 1; }
    FL_DIR="$d"
  }
  # --matrix: one row per floor cell for the mutant whose vector FL_CELLS now holds; the control
  # copy scores every cell 1, so a 0 is a cell this mutant moved.
  fl_matrix() {  # $1 mutant name
    local i=0 nm
    for nm in $fl_names; do
      i=$((i + 1))
      if [ "$(printf '%s' "$FL_CELLS" | cut -c"$i")" = "1" ]; then matrix_row "$1" "fl-${nm%%:*}" 0 GREEN no
      else matrix_row "$1" "fl-${nm%%:*}" 1 TRIPPED yes; fi
      MROWS=$((MROWS + 1))
    done
  }
  # $1 the base flag (FL_B: the unmutated copy scored every cell in this run)  $2 label
  # $3 expected cells  $4 name  $5 target  $6 anchor  $7 replacement
  fl_score() {
    N=$((N + 1))
    if ! fl_mk "$4" "$5" "$6" "$7"; then
      FAIL=$((FAIL + 1)); printf '  FAIL %-30s DID NOT APPLY: %s\n' "$2" "$FL_WHY"; return 1
    fi
    fl_cells "$FL_DIR"
    [ "$MATRIX" = 1 ] && fl_matrix "F-$4"
    if [ "$FL_CELLS" = "$3" ]; then
      mutant_killed "$1" "F-$4" "$2 $3 -> $FL_CELLS" || return 1
      KILLS=$((KILLS + 1)); return 0
    else FAIL=$((FAIL + 1)); printf '  FAIL %-30s scored %s, wanted %s\n' "$2" "$FL_CELLS" "$3"; return 1; fi
  }
  FL_FLOOR='  if (needle.length < CITE_MIN_NORM_CHARS) {'
  # F-control: the unmutated copy of the whole dir. FL_B, the base flag every floor kill is gated
  # on, is raised only in this arm's passing branch.
  N=$((N + 1)); FL_B=0
  if fl_mk ctl "" "" ""; then fl_cells "$FL_DIR"; else FL_CELLS="never-built:$FL_WHY"; fi
  if [ "$FL_CELLS" = 111111111111111111 ]; then
    FL_B=1; ok "F-control 111111111111111111 -> $FL_CELLS"
  else
    bad "F-control scored $FL_CELLS, wanted 111111111111111111 -- no floor mutant below can be scored"
  fi
  # m1: the predicate's floor removed. ONLY the predicate-direct cells move: every caller refuses
  # on the normalised length before asking, so P, Q, S and the NBSP pair still FAIL at the caller.
  # The empty needle now scans and `includes("")` matches, and eleven characters verify.
  fl_score "$FL_B" "F-m1 floor removed"   111111000111110001 m1 validate-steering-budget.sh "$FL_FLOOR" '  if (false) {'
  # m3: the floor measured on the RAW needle, i.e. normalisation applied after it. Twelve spaces
  # is twelve raw characters and passes; `yes` is three raw and is still refused -- which is the
  # cell (W) that separates this mutant from m1. The padded eleven is fifteen raw and verifies.
  fl_score "$FL_B" "F-m3 floor before norm" 111111001111111101 m3 validate-steering-budget.sh "$FL_FLOOR" '  if (CITE_TEXT.length < CITE_MIN_NORM_CHARS) {'
  # m5: cite mode keyed on the needle's TEXT rather than on the flag. An empty needle skips the
  # citation block and the checks mode answers rc 0. Only the two empty-needle cells move.
  fl_score "$FL_B" "F-m5 cite mode keyed on text" 111111111111110011 m5 validate-steering-budget.sh \
    'const CITE = process.env.AI_DLC_CITE_SET === "1";' 'const CITE = !!process.env.AI_DLC_CITE;'
  # m6: the floor's VALUE lowered to 4, callers untouched. Every short needle in the other cells is
  # under 4 (or a caller refuses it first), so only the eleven-character cell moves.
  fl_score "$FL_B" "F-m6 floor is 4" 111111111111111101 m6 validate-steering-budget.sh \
    'const CITE_MIN_NORM_CHARS = 12;' 'const CITE_MIN_NORM_CHARS = 4;'
  # m2: --any-authorized measures the un-normalised quote again. It never calls the predicate, so
  # this site's own check is the whole check: the padded entry and both NBSP entries count.
  fl_score "$FL_B" "F-m2 any-authorized raw" 111101111111001111 m2 "$FL_BASE" \
    '    nquote="$(cite_norm "$(cite_quote "$authline")")"' '    nquote="$(cite_quote "$authline")"'
  # m4: cite_norm collapses ASCII whitespace only -- the first fix's body. At the gate the
  # predicate's own `\s` still refuses the NBSP quotes, so the ONLY cells that move are the two
  # --any-authorized NBSP entries, where the caller's measure is the whole check.
  fl_score "$FL_B" "F-m4 cite_norm ASCII-only" 111111111111001111 m4 "$FL_BASE" \
    '      gsub("\302\240|\341\232\200|\342\200[\200-\212]|\342\200\250|\342\200\251|\342\200\257|\342\201\237|\343\200\200|\357\273\277", " ", s)' \
    '      s = s'
  # m2b: the GATE site measures the un-normalised quote again. The predicate still refuses (rc
  # stays 1), so the cells that move are the messages naming the normalised length -- the defence
  # in depth the floor's single home is meant to provide, asserted separately below.
  if fl_score "$FL_B" "F-m2b gate-mode raw" 001111111111111111 m2b "$FL_BASE" \
       '  nquote="$(cite_norm "$quote")"' '  nquote="$quote"'; then
    N=$((N + 1))
    FL_O="$(bash "$FL_DIR/$FL_BASE" --escalations "$ROOT/pending-padded.md" --sprint 50 --transcript-dir "$ROOT/corpus-short" 2>&1)"; FL_RC=$?
    if [ "$FL_RC" -eq 1 ] && grep -qF "NOMATCH-SHORT" <<<"$FL_O"; then
      printf '  ok   %-30s m2b: the padded quote still FAILs -- the predicate refused it (NOMATCH-SHORT)\n' "pending-padded.md"
    else
      FAIL=$((FAIL + 1)); printf '  FAIL %-30s m2b: with the caller measuring raw bytes the padded quote was not refused by the predicate (rc=%s)\n' "pending-padded.md" "$FL_RC"
    fi
  fi
fi

# --- a LEAD-INTERPRETATION entry resolves only on an exact disposition option (BL-944) -----------
# requirements.md §3 derives a `(lead interpretation)` bullet's state from the captured answer body
# and never files free text as a disposition, and the entry's Decision/Question line names the id
# and the disposition (`LR-S<N>-<m> (lead interpretation) -- descope, ...` / `-- confirm, ...`).
# The validator used to check only that the operator SAID the quoted words, so a genuine free-text
# reply verified as a descope. Seeds: seed.sh, the `lr/` tree, one AskUserQuestion answer per hour.
# Every cell is PRESENCE-shaped (an exit AND a line that must appear), so a subject that prints
# nothing fails all of them:
#   free       labelled descope entry quoting the free text            -> FAIL, names the options
#   strike reword confirm recommend   the exact options, badge allowed -> PASS
#   wrongid    `Strike LR-S7-3` on LR-S7-2, that answer IN the corpus  -> FAIL (only the id refuses it)
#   mismatch   `Confirm LR-S7-2` on a descope line, IN the corpus      -> FAIL
#   nohit      exact `Strike LR-S7-5`, which nobody answered           -> FAIL at the lookup: the rule
#              passes it and must not short-circuit the transcript check
#   neither    the paused `awaiting operator:` form filed RESOLVED     -> FAIL
#   plain      unlabelled, the same free text                          -> PASS (the near-miss)
#   nodq       no Decision/Question line at all (an empty record field) -> PASS
#   plain-any nodq-any    --any-authorized on the two above            -> AUTHORIZED
#   shortq-any a 6-char quote beside a Decision/Question line carrying a long quoted phrase -> NONE
#   hdrtab     a TAB in the `## ` header, a quote nobody said, the Decision/Question line holding a
#              phrase the operator DID send at that hour                -> FAIL, names NO genuine
#   hdrtabq-any shortq with a TAB in its header                         -> NONE
# plain and shortq carry a >=12-char quoted phrase on their Decision/Question line, so a row that
# lets that field bleed into the authorization text cites the wrong segment and moves them.
LR_NAMES="free strike reword confirm recommend wrongid mismatch nohit neither plain nodq plain-any nodq-any shortq-any hdrtab hdrtabq-any"
lr_cell() {  # $1 validator  $2 cell -> 0 when the cell holds
  local v="$1" c="$2" f o rc
  f="${c%-any}"
  if [ "$f" != "$c" ]; then
    o="$(bash "$v" --any-authorized "$ROOT/lr/$f.md" 2>&1)"; rc=$?
  else
    o="$(bash "$v" --escalations "$ROOT/lr/$f.md" --sprint 7 --transcript-dir "$ROOT/lr/t" 2>&1)"; rc=$?
  fi
  case "$c" in
    free)     [ "$rc" -eq 1 ] && grep -qF "which is not the exact answer body Strike LR-S7-2 or Reword LR-S7-2" <<<"$o" ;;
    wrongid)  [ "$rc" -eq 1 ] && grep -qF "quotes 'Strike LR-S7-3', which is not the exact answer body" <<<"$o" ;;
    mismatch) [ "$rc" -eq 1 ] && grep -qF "quotes 'Confirm LR-S7-2', which is not the exact answer body Strike" <<<"$o" ;;
    nohit|hdrtab) [ "$rc" -eq 1 ] && grep -qF "appears in NO genuine" <<<"$o" ;;
    neither)  [ "$rc" -eq 1 ] && grep -qF "neither disposition" <<<"$o" ;;
    plain-any|nodq-any) [ "$rc" -eq 0 ] && grep -qF "AUTHORIZED: 1 of 1" <<<"$o" ;;
    shortq-any|hdrtabq-any) [ "$rc" -eq 1 ] && grep -qF "NONE: 1 RESOLVED/OVERRIDDEN" <<<"$o" ;;
    *)        [ "$rc" -eq 0 ] && grep -qF "OK: all 1 S7 RESOLVED/OVERRIDDEN" <<<"$o" ;;
  esac
}
echo
echo "  -- a lead-interpretation entry resolves only on an exact Strike/Reword/Confirm quote --"
LR_CELLS=""
for c in $LR_NAMES; do if lr_cell "$VALIDATOR" "$c"; then LR_CELLS="${LR_CELLS}1"; else LR_CELLS="${LR_CELLS}0"; fi; done
# A SUBJECT THAT PREDATES THE RULE. This fixture ships one pull ahead of its validator; the pre-fix
# build passes free, wrongid, mismatch and neither and holds every other cell, both header-tab
# cells included (measured against d87a5940f^: `NO genuine` at the gate, `NONE` at --any-authorized).
# SKIP on a consumer,
# FAIL in the distribution.
# 25, plus 3 empty-file and 6 refusal kills where those sections ran, less any refusal mutant a
# masked cell made unscorable (KF_EXTRA, raised inside each
# non-SKIP branch, so a consumer SKIP of either section does not demand kills it cannot score).
KILL_FLOOR=$((25 + KF_EXTRA))
if [ "$LR_CELLS" = "0111100101111111" ] && [ "$EN_IS_DIST" -ne 1 ]; then
  printf '  SKIP %-30s the installed validator predates the lead-interpretation rule; this fixture ships one pull ahead of it\n' "lr/"
else
  i=0
  for c in $LR_NAMES; do
    i=$((i + 1)); N=$((N + 1))
    if [ "$(printf '%s' "$LR_CELLS" | cut -c"$i")" = "1" ]; then printf '  ok   %-30s lead-interpretation cell holds\n' "lr/$c"
    else FAIL=$((FAIL + 1)); printf '  FAIL %-30s lead-interpretation cell does not hold (cells=%s)\n' "lr/$c" "$LR_CELLS"; fi
  done

  # The mutants. Each is a copy of the validator beside the steering sibling in $MWORK, built by
  # an exactly-once literal anchor (awk ENVIRON, never sed: the anchors carry `$`, `[` and `"`).
  # A mutant runs only the cell its arm decides and one twin that must NOT move.
  LR_WHY=""; LR_V=""
  lr_mk() {  # $1 name  $2 anchor  $3 replacement -> LR_V
    local d="$MWORK/lr-$1" n
    LR_V=""
    mkdir -p "$d" && cp "$SRC_DIR/validate-steering-budget.sh" "$d/" || { LR_WHY="could not copy the steering sibling"; return 1; }
    n="$(grep -cF -- "$2" "$VALIDATOR")" || n=0
    [ "$n" -eq 1 ] || { LR_WHY="anchor matches $n line(s), not 1 -- re-anchor it, never relax the arm"; return 1; }
    A="$2" R="$3" awk '{ i = index($0, ENVIRON["A"]); if (i) $0 = substr($0, 1, i - 1) ENVIRON["R"] substr($0, i + length(ENVIRON["A"])); print }' \
      "$VALIDATOR" > "$d/validate-escalation-resolution.sh" || { LR_WHY="awk died"; return 1; }
    cmp -s "$VALIDATOR" "$d/validate-escalation-resolution.sh" && { LR_WHY="changed no bytes -- it would score as a kill"; return 1; }
    bash -n "$d/validate-escalation-resolution.sh" 2>/dev/null || { LR_WHY="does not parse"; return 1; }
    LR_V="$d/validate-escalation-resolution.sh"
  }
  lr_score() {  # $1 label  $2 decisive cell  $3 twin cell  $4 anchor  $5 replacement
    N=$((N + 1))
    if [ "$LR_BASE" -ne 1 ]; then FAIL=$((FAIL + 1)); printf '  FAIL %-30s FIXTURE BROKEN: not scored -- the unmutated copy did not hold its cells in this run\n' "L-$1"; return 2; fi
    if ! lr_mk "$1" "$4" "$5"; then FAIL=$((FAIL + 1)); printf '  FAIL %-30s DID NOT APPLY: %s\n' "L-$1" "$LR_WHY"; return 1; fi
    [ "$MATRIX" = 1 ] && lr_matrix "L-$1"
    if lr_cell "$LR_V" "$2"; then FAIL=$((FAIL + 1)); printf '  FAIL %-30s SURVIVED: cell %s still holds\n' "L-$1" "$2"; return 1; fi
    if ! lr_cell "$LR_V" "$3"; then FAIL=$((FAIL + 1)); printf '  FAIL %-30s moved its twin %s too -- the arms are entangled\n' "L-$1" "$3"; return 1; fi
    # The base: the decisive cell AND its twin held against the shipped validator in this run
    # (LR_CELLS, above), and the unmutated copy held its control cells (LR_BASE).
    local lr_b
    lr_b="$(lr_held "$2" "$3")"
    mutant_killed "$([ "$lr_b" = 1 ] && echo 1 || echo 0)" "L-$1" "L-$1 $2 is red, $3 unchanged" && KILLS=$((KILLS + 1))
  }
  # lr_held <cell>... -> prints 1 when LR_BASE is 1 and every named cell held in LR_CELLS, else 0.
  lr_held() {
    local want c i nm held=1
    [ "$LR_BASE" = 1 ] || held=0
    for want in "$@"; do
      i=0; c=0
      for nm in $LR_NAMES; do
        i=$((i + 1))
        [ "$nm" = "$want" ] && c="$(printf '%s' "$LR_CELLS" | cut -c"$i")"
      done
      [ "$c" = 1 ] || held=0
    done
    printf '%s' "$held"
  }
  # --matrix: the mutant LR_V against every lead-interpretation cell. The shipped validator holds
  # every cell (LR_CELLS, above), so a cell that fails here is one this mutant moved.
  lr_matrix() {  # $1 mutant name
    local c
    for c in $LR_NAMES; do
      if lr_cell "$LR_V" "$c"; then matrix_row "$1" "$c" 0 GREEN no
      else matrix_row "$1" "$c" 1 TRIPPED yes; fi
      MROWS=$((MROWS + 1))
    done
  }
  # The unmutated control, in the same kind of directory, must PASS a cell that needs the sibling.
  # No mutant below is scored unless this control held in this same run.
  N=$((N + 1)); LR_BASE=0
  mkdir -p "$MWORK/lr-ctl" && cp "$SRC_DIR/validate-steering-budget.sh" "$VALIDATOR" "$MWORK/lr-ctl/"
  if lr_cell "$MWORK/lr-ctl/validate-escalation-resolution.sh" strike && lr_cell "$MWORK/lr-ctl/validate-escalation-resolution.sh" free; then
    LR_BASE=1; ok "L-control the unmutated copy holds strike and free"
  else bad "L-control the unmutated copy does not reproduce the baseline; no mutant verdict below means anything"; fi
  KILL_FLOOR=$((KILL_FLOOR + 9))
  # L1: the label rule removed. The free text verifies as a descope again (the filed defect).
  lr_score no-label-rule free strike '  if [ -n "$lr_id" ]; then' '  if false; then'
  # L2: the id ignored -- any `Strike/Reword/Confirm LR-S<x>-<y>` passes. Only the wrong-id entry
  # moves, because its answer IS in the corpus.
  lr_score ignore-id wrongid free '    lr_body="${nquote% (Recommended)}"' '    lr_body="${nquote% (Recommended)}"; lr_body="${lr_body% LR-S*} $lr_id"'
  # L3: the disposition not matched -- a descope line accepts a Confirm body.
  lr_score no-disposition-match mismatch neither \
    '      descope*) { [ "$lr_body" = "Strike $lr_id" ] ||' '      descope*) { [ "$lr_body" = "Confirm $lr_id" ] || [ "$lr_body" = "Strike $lr_id" ] ||'
  # L4: the gate row reads three fields, so the Decision/Question text joins the authorization and
  # its quoted phrase is cited instead of the operator's words. `dq` is still set (empty) so the
  # mutant fails on the citation and not on an unbound variable under `set -u`.
  lr_score gate-dq-into-auth plain nodq \
    'while IFS="$(printf '"'"'\t'"'"')" read -r header status dq authline; do' 'while IFS="$(printf '"'"'\t'"'"')" read -r header status authline; do dq="";'
  # L4b: the same in --any-authorized: the long quoted phrase on the Decision/Question line counts.
  lr_score any-dq-into-auth shortq-any plain-any \
    '  while IFS="$(printf '"'"'\t'"'"')" read -r header status _dq authline; do' '  while IFS="$(printf '"'"'\t'"'"')" read -r header status authline; do'
  # L5: the sentinel dropped. An entry with no Decision/Question line writes an empty field, bash
  # merges the tab run, and its citation is read as the Decision/Question value.
  lr_score drop-sentinel nodq plain '(dq == "" ? "__NODQ__" : dq)' 'dq'
  # L6: a label-rule PASS `continue`s past the transcript check. An exact option nobody chose passes.
  lr_score rule-short-circuits nohit strike '    if [ "$lr_ok" -ne 1 ]; then' '    [ "$lr_ok" -eq 1 ] && continue; if [ "$lr_ok" -ne 1 ]; then'
  # L7: the header written with its tab. Every later field shifts one variable right, the auth
  # variable reads `<Decision/Question><TAB><auth>`, and the Decision/Question phrase is cited: the
  # fabricated quote verifies at the gate (L7) and the 6-char quote authorizes (L7b).
  lr_score header-tab-kept hdrtab plain '      gsub(/\t/, " ", hh)' '      hh = hh'
  lr_score header-tab-kept-any hdrtabq-any shortq-any '      gsub(/\t/, " ", hh)' '      hh = hh'
fi

# MATRIX ROW COUNT. A plain run prints no matrix row; a --matrix run prints one per mutant x arm:
# 13 corpus-arm mutants x the arms (a)..(z), 7 floor mutants x the floor cells, 9 lead-interpretation
# mutants x their cells, the last two only where their sections ran (not a consumer SKIP).
N=$((N + 1))
if [ "$MATRIX" = 0 ]; then
  if [ "$MROWS" -eq 0 ]; then ok "MX plain run printed no matrix row"; else bad "MX plain run printed $MROWS matrix row(s)"; fi
else
  MX_WANT=$(( $(printf '%s\n' $GX_ARMS | grep -c .) * 13 ))
  [ -n "${EN_MW:-}" ] && MX_WANT=$(( MX_WANT + $(printf '%s\n' $en_names | grep -c .) * 3 ))
  [ -n "${ER_MD:-}" ] && MX_WANT=$(( MX_WANT + $(printf '%s\n' $er_names | grep -c .) * (6 - ER_SKIPPED) ))
  [ -n "${FL_MW:-}" ] && MX_WANT=$(( MX_WANT + $(printf '%s\n' $fl_names | grep -c .) * 7 ))
  [ -n "${LR_BASE:-}" ] && MX_WANT=$(( MX_WANT + $(printf '%s\n' $LR_NAMES | grep -c .) * 9 ))
  if [ "$MROWS" -eq "$MX_WANT" ]; then ok "MX matrix run measured $MROWS mutant x arm cells"
  else bad "MX matrix run measured $MROWS cells, $MX_WANT expected"; fi
fi

# KILL COUNT. A mutation that applied cleanly to a file the run never loaded reads exactly
# like an arm that cannot fire, and `cmp -s` cannot tell them apart. Zero kills is that state.
N=$((N + 1))
if [ "$KILLS" -ge "$KILL_FLOOR" ]; then printf '  ok   %-30s %s mutant kill(s) -- these arms can fire\n' "KILL-COUNT" "$KILLS"
else FAIL=$((FAIL + 1)); printf '  FAIL %-30s %s kill(s); the mutants changed bytes in a file these arms never loaded\n' "KILL-COUNT" "$KILLS"; fi

echo
if [ "$FAIL" -gt 0 ]; then echo "FAIL: $FAIL of $N assertions wrong."; exit 1; fi
echo "PASS: all $N assertions correct."
exit 0
