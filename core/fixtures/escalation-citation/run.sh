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
# Usage: run.sh
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

# The REQUIRED input of inputs.decl: every assertion below drives this file.
echo "HERMETIC-CONSUMED $(cd "$(dirname "$VALIDATOR")" && pwd)/$(basename "$VALIDATOR")"

ROOT="$(bash "$DIR/seed.sh" | tail -1)"
trap 'rm -rf "$ROOT"' EXIT
# shellcheck source=/dev/null
. "$DIR/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }

# IN PROCESS (BL-878). The validator is loaded ONCE (core/fixtures/lib/inproc.sh `inproc_load`: its column-0 guard
# returns after defining ver_main) and every drive below is `inproc_run "$v" ver_main ...`: a subshell that drops every
# fixture function and unexported fixture variable, takes a fresh bash's shell options and calls ver_main, so its
# `exit`, `set -u` and EXIT trap end with that subshell, and BASH_SOURCE inside it is the sourced file, so the siblings
# (validate-steering-budget.sh, validate-suppression-lifetime.sh) resolve beside it as they do for the program. A
# relocated copy (inf/inosib) is sourced inside its own subshell, so its location is still the property. The
# program runs only in the cells of cells.decl: one cli cell per distinct CLI outcome (exit 0, 1, 2), each compared
# byte for byte with the in-process call, and one e2e cell (sup/argv) whose bound is a `bash -x` trace.
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT: a validator with neither its `ver_main() {` line nor the column-0 source
# guard predates the wrap and reads SKIP through fx_skip_exit (exit 0 on a consumer, never an ok; FIXTURE BROKEN in the
# distribution); exactly one half FAILs; an unreadable one is FIXTURE ERROR.
. "$DIR/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
. "$DIR/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
grep -q '^ver_main() {$' "$VALIDATOR"; _wd=$?
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$VALIDATOR"; _wg=$?
if [ "$_wd" -gt 1 ] || [ "$_wg" -gt 1 ]; then
  echo "FIXTURE ERROR: cannot read $VALIDATOR (grep exit $_wd/$_wg), so the in-process wrap cannot be judged; nothing was asserted" >&2; exit 2
fi
case "$_wd$_wg" in
  00) ;;
  11) echo "SKIP: subject predates the in-process wrap"; fx_skip_exit "$DIR" ;;
  10) echo "  FAIL $VALIDATOR defines \`ver_main() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run ver_main in this shell"; echo "FAIL: 1 of 1 assertions wrong."; exit 1 ;;
  *) echo "  FAIL $VALIDATOR carries the column-0 source guard but no \`ver_main() {\` line -- a respelled subject this fixture cannot drive"; echo "FAIL: 1 of 1 assertions wrong."; exit 1 ;;
esac
VALIDATOR="$(cd "$(dirname "$VALIDATOR")" && pwd)/$(basename "$VALIDATOR")"
. "$DIR/../lib/inproc.sh" || { echo "FIXTURE BROKEN: cannot source lib/inproc.sh" >&2; exit 2; }
inproc_load "$VALIDATOR" || { echo "FIXTURE BROKEN: sourcing $VALIDATOR defined nothing" >&2; exit 2; }
declare -F ver_main >/dev/null || { echo "FIXTURE BROKEN: sourcing $VALIDATOR defined no ver_main" >&2; exit 2; }

# okf/badf <format> [<arg>...]: one ok/bad line whose message is printf-formatted (the label columns).
okf()  { local _m; printf -v _m "$@"; ok "$_m"; }
badf() { local _m; printf -v _m "$@"; bad "$_m"; }

# $1 pending-file  $2 sprint  $3 transcript-basename (or "")  $4 want-exit  $5 why  $6 optional validator
# Returns 0 when the arm held, 1 when it did not.
g() {
  local f="$1" sp="$2" t="$3" want="$4" why="$5" v="${6:-$VALIDATOR}"
  local args=(--escalations "$ROOT/$f" --sprint "$sp")
  [ -n "$t" ] && args+=(--transcript "$ROOT/$t")
  local out got
  out="$(inproc_run "$v" ver_main "${args[@]}" 2>&1)"; got=$?
  if [ "$got" -eq "$want" ]; then okf '%-22s exit=%s  (%s)' "$f/${t:-none}" "$got" "$why"; return 0
  else badf '%-22s exit=%s want=%s  (%s)' "$f/${t:-none}" "$got" "$want" "$why"; printf '%s\n' "$out" | sed 's/^/       | /'; return 1; fi
}
says() {
  local f="$1" sp="$2" t="$3"; shift 3
  local out miss=""
  out="$(inproc_run "$VALIDATOR" ver_main --escalations "$ROOT/$f" --sprint "$sp" --transcript "$ROOT/$t" 2>&1)"
  local w; for w in "$@"; do grep -qF -- "$w" <<<"$out" || miss="$miss [$w]"; done
  if [ -z "$miss" ]; then okf '%-22s message names the cause' "$f(msg)"; return 0
  else badf '%-22s missing:%s' "$f(msg)" "$miss"; return 1; fi
}

echo "escalation-citation proof (Check 2)"
# The candidate list above spans both install layouts and takes the first that EXISTS. Print
# what this run actually loaded.
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
# $7 optional validator override, so the control copy below reuses exactly these assertions.
gx() {
  local f="$1" sp="$2" d="$3" t="$4" want="$5" why="$6" v="${7:-$VALIDATOR}"
  local args=(--escalations "$ROOT/$f" --sprint "$sp")
  [ -n "$t" ] && args+=(--transcript "$ROOT/$t")
  [ -n "$d" ] && args+=(--transcript-dir "$ROOT/$d")
  local out got
  out="$(inproc_run "$v" ver_main "${args[@]}" 2>&1)"; got=$?
  if [ "$got" -eq "$want" ]; then okf '%-26s exit=%s  (%s)' "$f" "$got" "$why"; return 0
  else badf '%-26s exit=%s want=%s  (%s)' "$f" "$got" "$want" "$why"; printf '%s\n' "$out" | sed 's/^/       | /'; return 1; fi
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
  local f="$1" d="$2" t="$3" want="$4" yes="$5" no="$6" why2="$7" v="${8:-$VALIDATOR}"
  local args=(--escalations "$ROOT/$f" --sprint 50)
  [ -n "$t" ] && args+=(--transcript "$ROOT/$t")
  [ -n "$d" ] && args+=(--transcript-dir "$ROOT/$d")
  local out got why=""
  out="$(inproc_run "$v" ver_main "${args[@]}" 2>&1)"; got=$?
  [ "$got" -eq "$want" ] || why="$why [exit=$got want=$want]"
  grep -qF -- "$yes" <<<"$out" || why="$why [missing: $yes]"
  grep -qF -- "$no"  <<<"$out" && why="$why [PRESENT but must not be: $no]"
  if [ -z "$why" ]; then okf '%-30s exit=%s  (%s)' "$f/${d:-nodir}/${t:-nofile}" "$got" "$why2"; return 0
  else badf '%-30s%s  (%s)' "$f/${d:-nodir}/${t:-nofile}" "$why" "$why2"; return 1; fi
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
  local f="$1" t="$2"; shift 2
  local out miss=""
  out="$(inproc_run "$VALIDATOR" ver_main --escalations "$ROOT/$f" --sprint 50 --transcript "$ROOT/$t" 2>/dev/null)"
  local w; for w in "$@"; do grep -qF -- "$w" <<<"$out" || miss="$miss [$w]"; done
  if [ -z "$miss" ]; then okf '%-26s PASS line carries the count' "$f"; return 0
  else badf '%-26s missing:%s\n       | %s' "$f" "$miss" "$out"; return 1; fi
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
  a="$(inproc_run "$v" ver_main --escalations "$ROOT/pending-crosssession.md" --sprint 50 --transcript-dir "$ROOT/corpus-live" 2>/dev/null)"; ra=$?
  cp "$ROOT/corpus/gate.jsonl" "$ROOT/corpus-live/gate.jsonl"
  local md5b; md5b="$(md5 -q "$ROOT/pending-crosssession.md" 2>/dev/null || md5sum "$ROOT/pending-crosssession.md" | cut -d' ' -f1)"
  b="$(inproc_run "$v" ver_main --escalations "$ROOT/pending-crosssession.md" --sprint 50 --transcript-dir "$ROOT/corpus-live" 2>/dev/null)"; rb=$?
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
pass_corpus_pair "$VALIDATOR"; RC_X=$?
if [ "$RC_X" -eq 0 ]; then
  okf '%-30s (x) a PASS states the corpus state it was taken over' "corpus-live"
else
  badf '%-30s%s  (x) the PASS path does not name its corpus' "corpus-live" "$PCP_WHY"
fi

# (y) THE ACCUSATION BRANCH DID NOT CHANGE SHAPE. The over-broad version of this fix -- render
# the report on every path -- passes (x) and gives the FAIL branch the report TWICE, where it
# already had it. Counted, not grepped: presence is true under both.
cite_lines() {  # $1 validator  -> how many corpus-report lines the FAIL output carries
  local v="$1" out n
  out="$(inproc_run "$v" ver_main --escalations "$ROOT/pending-crossfake.md" --sprint 50 --transcript-dir "$ROOT/corpus" 2>&1)"
  n="$(grep -cF -- "cite: scanned" <<<"$out")" || n=0
  printf '%s' "$n"
}
CL="$(cite_lines "$VALIDATOR")"
[ "$CL" -eq 1 ]; RC_Y=$?
if [ "$RC_Y" -eq 0 ]; then okf '%-30s (y) the FAIL branch reports its corpus exactly once' "pending-crossfake.md"
else badf '%-30s (y) the FAIL branch carries %s corpus-report line(s), not 1' "pending-crossfake.md" "$CL"; fi

# (z) A VERDICT THAT VERIFIED NOTHING NAMES NO CORPUS. The vacuous path exits before any
# citation is checked, so a corpus line there would attest a scan that never ran -- which is the
# same unfalsifiable claim this whole section removes, in the other direction. Asserted as a LINE
# COUNT, because a reader rendering an empty default there prints a line that greps as nothing.
vac_lines() {  # $1 validator  -> stdout line count of the nothing-in-scope PASS
  local v="$1" out
  out="$(inproc_run "$v" ver_main --escalations "$ROOT/pending-clean.md" --sprint 50 --transcript "$ROOT/real.jsonl" 2>/dev/null)"
  printf '%s' "$(printf '%s\n' "$out" | grep -c .)"
}
VL="$(vac_lines "$VALIDATOR")"
[ "$VL" -eq 1 ]; RC_Z=$?
if [ "$RC_Z" -eq 0 ]; then okf '%-30s (z) a PASS that examined nothing names no corpus' "pending-clean.md"
else badf '%-30s (z) the vacuous PASS printed %s line(s), not 1' "pending-clean.md" "$VL"; fi

# --- scratch space for the sections below ------------------------------------------------------
echo
MWORK="$(mktemp -d)"; trap 'rm -rf "$ROOT" "$MWORK"' EXIT
SRC_DIR="$(cd "$(dirname "$VALIDATOR")" && pwd)"

# --- an EMPTY escalations file is the ABSENT state, and only an empty one ---------------------
# A file that exists and holds no non-whitespace byte used to fall through to the parser, parse
# zero records and print the ordinary nothing-in-scope line -- a verdict over entries when there
# were none. The gate mode now prints the absent-file `EXAMINED NOTHING` line for it.
#
# SIX CELLS, SCORED AS ONE STRING:
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
  o="$(inproc_run "$v" ver_main --escalations "$ROOT/pending-empty.md" --sprint 50 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 0 ] && grep -qF "EXAMINED NOTHING" <<<"$o" && grep -qF "present but empty" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  o="$(inproc_run "$v" ver_main --escalations "$ROOT/pending-blank.md" --sprint 50 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 0 ] && grep -qF "EXAMINED NOTHING" <<<"$o" && grep -qF "present but empty" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  o="$(inproc_run "$v" ver_main --escalations "$ROOT/pending-never-written.md" --sprint 50 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 0 ] && grep -qF "EXAMINED NOTHING" <<<"$o" && grep -qF "no escalations file" <<<"$o" \
     && ! grep -qF "present but empty" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  o="$(inproc_run "$v" ver_main --escalations "$ROOT/pending-heading.md" --sprint 50 2>/dev/null)"; rc=$?
  o2="$(inproc_run "$v" ver_main --escalations "$ROOT/pending-clean.md" --sprint 50 2>/dev/null)"; rc2=$?
  if [ "$rc" -eq 0 ] && [ "$rc2" -eq 0 ] && ! grep -qF "EXAMINED NOTHING" <<<"$o$o2" \
     && grep -qF "no S50 RESOLVED/OVERRIDDEN escalation requires" <<<"$o" \
     && grep -qF "no S50 RESOLVED/OVERRIDDEN escalation requires" <<<"$o2"; then c="${c}1"; else c="${c}0"; fi
  e="$(inproc_run "$v" ver_main --escalations "$ROOT/pending-missing.md" --sprint 50 --transcript "$ROOT/real.jsonl" 2>&1 >/dev/null)"; rc=$?
  if [ "$rc" -eq 1 ] && grep -qF "carries no 'Operator authorization:'" <<<"$e"; then c="${c}1"; else c="${c}0"; fi
  o="$(inproc_run "$v" ver_main --any-authorized "$ROOT/pending-empty.md" 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^NONE:' <<<"$o" && ! grep -qF "EXAMINED NOTHING" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  EN_CELLS="$c"
}
en_names="A:empty B:whitespace C:absent D:populated-zero-record E:finding F:any-authorized"
en_report() {  # $1 cells -> one ok/FAIL line per cell
  local i=0 nm
  for nm in $en_names; do
    i=$((i + 1))
    if [ "$(printf '%s' "$1" | cut -c"$i")" = "1" ]; then okf '%-30s empty-file cell %s holds' "${nm#*:}" "${nm%%:*}"
    else badf '%-30s empty-file cell %s does not hold' "${nm#*:}" "${nm%%:*}"; fi
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
fi

# --- an UNREADABLE or NON-REGULAR escalations path REFUSES (gate mode), exit 2 ------------------------
# The blank probe's grep exits 2 on a file it cannot read, and the gate mode branched on `-eq 1` alone:
# the status fell through, the parser's read failure was swallowed, and the run printed the ordinary
# "no S<N> ... requires an operator citation" line over a file nobody read. A DIRECTORY at the path
# failed `-f` and printed "no escalations file" -- the line Check 2a reads as a pass.
#
# SIX CELLS, ONE STRING:
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
if [ -L "$ER_LINK" ] && [ ! -e "$ER_LINK" ]; then okf '%-30s the dangling-symlink seed is a link to a missing target' "pending-dangling.md"
else badf '%-30s FIXTURE BROKEN: the dangling-symlink seed is not dangling' "pending-dangling.md"; fi
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
  ER_O="$(PATH="$p" inproc_run "$1" ver_main --escalations "$2" --sprint 50 --transcript "$ROOT/real.jsonl" 2>"$ER/err")"; ER_RC=$?
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
      1) okf '%-30s refusal cell %s holds' "${nm#*:}" "${nm%%:*}" ;;
      S) ;;
      *) badf '%-30s refusal cell %s does not hold (cells=%s)' "${nm#*:}" "${nm%%:*}" "$ER_CELLS" ;;
    esac
  done
fi

# --- the citation FLOOR is measured on the NORMALISED needle, and the predicate owns it ----------
# Every caller compared bash `${#quote}` against 12 while `--cite` collapses whitespace and trims
# before matching, so `"          yes"` (13 raw, 3 normalised) and twelve spaces (EMPTY normalised,
# and `includes("")` is true of every turn) both verified against any operator turn in the window.
# corpus-short holds a genuine in-window operator turn carrying `yes`, so the pre-fix build MATCHES
# both: every cell below is about the floor and nothing else.
#
# EIGHTEEN CELLS, ONE STRING:
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
if [ -n "$FL_FIRST" ] && [ "$FL_FIRST" != "b-incident.jsonl" ] \
   && [ "$(ls "$ROOT/corpus-short" | grep -c '\.jsonl$')" -ge 2 ]; then
  okf '%-30s the reader opens %s first; the incident turn is in the second member' "corpus-short" "$FL_FIRST"
else
  badf '%-30s FIXTURE BROKEN: first member read is "%s" -- the incident must not be first in a >=2-file corpus' "corpus-short" "$FL_FIRST"
fi
FL_CELLS=""
fl_cells() {  # $1 directory holding the validator and its steering sibling -> FL_CELLS
  local d="$1" v="$1/$FL_BASE" s="$1/validate-steering-budget.sh" o rc c=""
  fl_g() { o="$(inproc_run "$v" ver_main --escalations "$ROOT/$1" --sprint 50 --transcript-dir "$ROOT/corpus-short" 2>&1)"; rc=$?; }
  fl_g pending-padded.md
  if [ "$rc" -eq 1 ] && grep -qF "(3 chars once whitespace is collapsed), too short" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  fl_g pending-blankq.md
  if [ "$rc" -eq 1 ] && grep -qF "(0 chars once whitespace is collapsed), too short" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  fl_g pending-incident-whole.md
  if [ "$rc" -eq 0 ] && grep -qF "cite: scanned 2 transcript(s)" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  fl_g pending-incident-short.md
  if [ "$rc" -eq 1 ] && grep -qF "(7 chars once whitespace is collapsed), too short" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  o="$(inproc_run "$v" ver_main --any-authorized "$ROOT/pending-padded.md" 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^NONE: 1 RESOLVED/OVERRIDDEN' <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  o="$(inproc_run "$v" ver_main --any-authorized "$ROOT/pending-incident-whole.md" 2>/dev/null)"; rc=$?
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
  o="$(inproc_run "$v" ver_main --any-authorized "$ROOT/pending-nbsp-padded.md" 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 1 ] && grep -q '^NONE: 1 RESOLVED/OVERRIDDEN' <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  o="$(inproc_run "$v" ver_main --any-authorized "$ROOT/pending-nbsp-blank.md" 2>/dev/null)"; rc=$?
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
    i=$((i + 1))
    if [ "$(printf '%s' "$FL_CELLS" | cut -c"$i")" = "1" ]; then okf '%-30s floor cell %s holds' "${nm#*:}" "${nm%%:*}"
    else badf '%-30s floor cell %s does not hold (cells=%s)' "${nm#*:}" "${nm%%:*}" "$FL_CELLS"; fi
  done
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
    o="$(inproc_run "$v" ver_main --any-authorized "$ROOT/lr/$f.md" 2>&1)"; rc=$?
  else
    o="$(inproc_run "$v" ver_main --escalations "$ROOT/lr/$f.md" --sprint 7 --transcript-dir "$ROOT/lr/t" 2>&1)"; rc=$?
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
if [ "$LR_CELLS" = "0111100101111111" ] && [ "$EN_IS_DIST" -ne 1 ]; then
  printf '  SKIP %-30s the installed validator predates the lead-interpretation rule; this fixture ships one pull ahead of it\n' "lr/"
else
  i=0
  for c in $LR_NAMES; do
    i=$((i + 1))
    if [ "$(printf '%s' "$LR_CELLS" | cut -c"$i")" = "1" ]; then okf '%-30s lead-interpretation cell holds' "lr/$c"
    else badf '%-30s lead-interpretation cell does not hold (cells=%s)' "lr/$c" "$LR_CELLS"; fi
  done

fi

# --- a SUPPRESSED entry's citation is verified at the gate, archive included (BL-960) ----------
# Twelve cells over the sup/ layouts seed.sh writes, scored as one string. Every cell is PRESENCE-shaped: an rc AND a line that must
# appear, so a subject that prints nothing fails all of them.
#   sbad    gate, S50 SUPPRESSED citing invented words      rc 1, `appears in NO genuine`
#   sgood   gate, S50 SUPPRESSED citing the genuine turn    rc 0, `OK: all 1 S50` (base says `no S50`)
#   sany    --any-authorized, the same entry                rc 1, `NONE: 0 RESOLVED/OVERRIDDEN`
#   sanyres --any-authorized, the entry RESOLVED            rc 0, `AUTHORIZED: 1 of 1` (sany's twin)
#   apop    a fabricated S50 SUPPRESSED in the ARCHIVE      rc 1, `appears in NO genuine`
#   aabs    the same with no pending.md                     rc 1, `appears in NO genuine`
#   aemp    the same beside an empty pending.md             rc 1, `appears in NO genuine`
#   agood   the genuine one in the archive, no pending.md   rc 0, `OK: all 1 S50`
#   ares    an uncited S50 RESOLVED in the archive          rc 0, `no S50 RESOLVED/OVERRIDDEN`
#   bound   an archive preamble's authorization line must not complete pending.md's last entry
#                                                           rc 1, `carries no 'Operator authorization:'`
#   argv    a value-taking flag LAST on the command line    rc 2, `REFUSED: --any-authorized needs a value`
#   adir    pending-archive.md is a DIRECTORY beside a      rc 2, `REFUSED: escalation archive`
#           genuine pending.md (unrefused, it reads as absent and the run is OK)
# THE argv CELL IS BOUNDED BY STRUCTURE, NOT BY A CLOCK. Before its fix the parser re-dispatched
# the trailing flag forever (bash's `shift 2` with one positional left shifts nothing). The run
# is traced with `bash -x` into a file the subshell caps with `ulimit -f`: a fixed build writes
# under 1 KiB and refuses, a looping one fills the cap in a few hundred passes and dies on
# SIGXFSZ (rc 153). Neither verdict depends on load or on elapsed time.
SV_NAMES="sbad sgood sany sanyres apop aabs aemp agood ares bound argv adir"
sv_cell() {  # $1 validator  $2 cell -> 0 when the cell holds
  local v="$1" o rc d="$ROOT/sup"
  case "$2" in
    sany|sanyres) local f=anyonly; [ "$2" = sanyres ] && f=anyres
      o="$(inproc_run "$v" ver_main --any-authorized "$d/$f/pending.md" 2>&1)"; rc=$? ;;
    # e2e cell sup-argv (cells.decl): the bound is the program's own `bash -x` trace under `ulimit -f`; in process
    # inproc_run resets xtrace, so a looping parser would be bounded by nothing.
    argv) ( ulimit -f 64; FXCELL=sup-argv bash -x "$v" --escalations "$d/good/pending.md" --sprint 50 --any-authorized ) \
            </dev/null >"$MWORK/sv-argv.out" 2>"$MWORK/sv-argv.trace"; rc=$?
      o="$(cat "$MWORK/sv-argv.trace")" ;;
    *) local f="$2"; case "$2" in sbad) f=bad ;; sgood) f=good ;; esac
      o="$(inproc_run "$v" ver_main --escalations "$d/$f/pending.md" --sprint 50 --transcript "$ROOT/real.jsonl" 2>&1)"; rc=$? ;;
  esac
  case "$2" in
    sbad|apop|aabs|aemp) [ "$rc" -eq 1 ] && grep -qF "appears in NO genuine" <<<"$o" ;;
    sgood|agood) [ "$rc" -eq 0 ] && grep -qF "OK: all 1 S50" <<<"$o" ;;
    sany)    [ "$rc" -eq 1 ] && grep -qF "NONE: 0 RESOLVED/OVERRIDDEN" <<<"$o" ;;
    sanyres) [ "$rc" -eq 0 ] && grep -qF "AUTHORIZED: 1 of 1" <<<"$o" ;;
    ares)    [ "$rc" -eq 0 ] && grep -qF "no S50 RESOLVED/OVERRIDDEN escalation requires" <<<"$o" ;;
    bound)   [ "$rc" -eq 1 ] && grep -qF "carries no 'Operator authorization:'" <<<"$o" ;;
    argv)    [ "$rc" -eq 2 ] && grep -qF "REFUSED: --any-authorized needs a value" <<<"$o" ;;
    adir)    [ "$rc" -eq 2 ] && grep -qF "REFUSED: escalation archive" <<<"$o" ;;
    *) return 3 ;;
  esac
}
sv_cells() {  # $1 validator -> prints one 0/1 per SV_NAMES member
  local c s=""
  for c in $SV_NAMES; do if sv_cell "$1" "$c"; then s="${s}1"; else s="${s}0"; fi; done
  printf '%s' "$s"
}
echo
echo "  -- a SUPPRESSED citation is verified at the gate, the archive included (BL-960) --"
SV_CELLS="$(sv_cells "$VALIDATOR")"
# A SUBJECT THAT PREDATES THE RULE (measured against cb6e0ab80): sbad, sgood, apop, aabs, aemp,
# agood and bound read 0, sany, sanyres and ares hold, argv is SIGXFSZ, and adir reads 0 (that
# build has no archive refusal). SKIP on a consumer, FAIL in the distribution.
if [ "$SV_CELLS" = "001100001000" ] && [ "$EN_IS_DIST" -ne 1 ]; then
  printf '  SKIP %-30s the installed validator predates the SUPPRESSED citation check; this fixture ships one pull ahead of it\n' "sup/"
else
  i=0
  for c in $SV_NAMES; do
    i=$((i + 1))
    if [ "$(printf '%s' "$SV_CELLS" | cut -c"$i")" = "1" ]; then okf '%-30s SUPPRESSED-citation cell holds' "sup/$c"
    else badf '%-30s SUPPRESSED-citation cell does not hold (cells=%s)' "sup/$c" "$SV_CELLS"; fi
  done
fi

# --- a SUPPRESSED entry IN FORCE is checked whatever sprint its header names (BL-960, ruling (c)) ---
# Eight cells over the inf/ roots seed.sh writes (its note carries the layouts). Each runs at --sprint 50
# with AI_DLC_PROJECT_ROOT at its own root, so the in-force predicate the validator asks
# (validate-suppression-lifetime.sh, beside it) reads that root's two gates and two-id catalog.
#   ioff    S49 SUPPRESSED in force, invented words         rc 1, `appears in NO genuine`
#   ioffg   the same, the genuine turn                      rc 0, `OK: all 1 S50` and the split `SUPPRESSED 1)` (ioff's allow twin)
#   inone   no sprint token in force, invented words        rc 1, `appears in NO genuine`
#   iarch   S49 SUPPRESSED in force in the ARCHIVE, invented rc 1, `appears in NO genuine`
#   iexp    S49 SUPPRESSED EXPIRED, invented words          rc 0, `no S50 RESOLVED/OVERRIDDEN` (out of scope)
#   inosib  ioff's root, the validator with NO in-force sibling beside it
#                                                           rc 2, `REFUSED: an entry in`
#   icur    S50 SUPPRESSED in force, `- **Status:**` list-item status (this parser reads no status,
#           the sibling reads SUPPRESSED), invented words   rc 1, `appears in NO genuine`
#   icurg   the same, the genuine turn                      rc 0, `OK: all 1 S50` and `SUPPRESSED 1)` (icur's allow twin)
IF_NAMES="ioff ioffg inone iarch iexp inosib icur icurg"
if_cell() {  # $1 validator  $2 cell -> 0 when the cell holds
  local v="$1" f="$2" o rc
  if [ "$2" = inosib ]; then
    f=ioff
    mkdir -p "$MWORK/if-nosib" && cp "$SRC_DIR/validate-steering-budget.sh" "$MWORK/if-nosib/" && cp "$v" "$MWORK/if-nosib/validate-escalation-resolution.sh"
    v="$MWORK/if-nosib/validate-escalation-resolution.sh"
  fi
  o="$(AI_DLC_PROJECT_ROOT="$ROOT/inf/$f" inproc_run "$v" ver_main --escalations "$ROOT/inf/$f/docs/escalations/pending.md" --sprint 50 --transcript "$ROOT/real.jsonl" 2>&1)"; rc=$?
  case "$2" in
    ioff|inone|iarch|icur) [ "$rc" -eq 1 ] && grep -qF "appears in NO genuine" <<<"$o" ;;
    ioffg|icurg) [ "$rc" -eq 0 ] && grep -qF "OK: all 1 S50" <<<"$o" && grep -qF "SUPPRESSED 1)" <<<"$o" ;;
    iexp)   [ "$rc" -eq 0 ] && grep -qF "no S50 RESOLVED/OVERRIDDEN escalation requires" <<<"$o" ;;
    inosib) [ "$rc" -eq 2 ] && grep -qF "REFUSED: an entry in" <<<"$o" ;;
    *) return 3 ;;
  esac
}
if_cells() {  # $1 validator -> one 0/1 per IF_NAMES member
  local c s=""
  for c in $IF_NAMES; do if if_cell "$1" "$c"; then s="${s}1"; else s="${s}0"; fi; done
  printf '%s' "$s"
}
echo
echo "  -- an in-force SUPPRESSED entry is checked whatever sprint its header names (BL-960 (c)) --"
IF_CELLS="$(if_cells "$VALIDATOR")"
# A SUBJECT THAT PREDATES THE RULE (measured against 43c27ddd0 and origin/main at 0.1064.0, each
# beside its own siblings): only iexp holds -- nothing outside the header scope is read, so ioff,
# inone and iarch pass, ioffg says `no S50`, inosib needs no sibling, and icur/icurg read no status
# so nothing is in scope. SKIP on a consumer, FAIL in the distribution.
if [ "$IF_CELLS" = "00001000" ] && [ "$EN_IS_DIST" -ne 1 ]; then
  printf '  SKIP %-30s the installed validator predates the in-force SUPPRESSED scope; this fixture ships one pull ahead of it\n' "inf/"
else
  i=0
  for c in $IF_NAMES; do
    i=$((i + 1))
    if [ "$(printf '%s' "$IF_CELLS" | cut -c"$i")" = "1" ]; then okf '%-30s in-force SUPPRESSED cell holds' "inf/$c"
    else badf '%-30s in-force SUPPRESSED cell does not hold (cells=%s)' "inf/$c" "$IF_CELLS"; fi
  done
fi

# --- the cli cells (cells.decl): the validator run as a PROGRAM once per distinct CLI outcome ---------------------
# The outcomes this fixture reaches are exit 0 (a verified citation), exit 1 (a finding) and exit 2 (a refusal). One
# `FXCELL=<id> bash "$VALIDATOR"` start per outcome, each compared with the in-process call on the same input: stdout,
# stderr and exit separately, byte for byte. A cell also asserts its own outcome (a positive conjunct, so two runs that
# both printed nothing cannot read as equivalent), and the cells must differ.
echo
echo "  -- the cli cells: the program answers exactly as the in-process call --"
EQ="$MWORK/eq"; mkdir -p "$EQ"
eqv() { # <cell-id> <args...> -> $EQ/<id>.{ip,cl}.{out,err,rc}
  local id="$1"; shift
  inproc_run "$VALIDATOR" ver_main "$@" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" bash "$VALIDATOR" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(cat "$EQ/$1.ip.out")" "$(cat "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(cat "$EQ/$1.cl.out")" "$(cat "$EQ/$1.cl.err")"; }
if eqv cli-pass --escalations "$ROOT/pending-real.md" --sprint 50 --transcript "$ROOT/real.jsonl" \
   && [ "$(cat "$EQ/cli-pass.cl.rc")" = 0 ] && grep -qF "OK: all 1 S50" "$EQ/cli-pass.cl.out"; then
  okf '%-30s the program verifies the citation exactly as the in-process call does (stdout, stderr, exit 0)' "cli-pass"
else badf '%-30s the program and the in-process call differ, or the outcome is not exit 0 with OK (%s)' "cli-pass" "$(eq_twin cli-pass)"; fi
if eqv cli-finding --escalations "$ROOT/pending-missing.md" --sprint 50 --transcript "$ROOT/real.jsonl" \
   && [ "$(cat "$EQ/cli-finding.cl.rc")" = 1 ] && grep -qF "carries no 'Operator authorization:'" "$EQ/cli-finding.cl.err"; then
  okf '%-30s the program reports the missing citation exactly as the in-process call does (stdout, stderr, exit 1)' "cli-finding"
else badf '%-30s the program and the in-process call differ, or the outcome is not exit 1 naming the missing citation (%s)' "cli-finding" "$(eq_twin cli-finding)"; fi
if eqv cli-refused --escalations "$ER_DIR" --sprint 50 --transcript "$ROOT/real.jsonl" \
   && [ "$(cat "$EQ/cli-refused.cl.rc")" = 2 ] && grep -q '^REFUSED: .*is not a regular file' "$EQ/cli-refused.cl.err"; then
  okf '%-30s the program refuses a directory exactly as the in-process call does (stdout, stderr, exit 2)' "cli-refused"
else badf '%-30s the program and the in-process call differ, or the outcome is not exit 2 REFUSED (%s)' "cli-refused" "$(eq_twin cli-refused)"; fi
if ! cmp -s "$EQ/cli-pass.cl.rc" "$EQ/cli-finding.cl.rc" && ! cmp -s "$EQ/cli-finding.cl.rc" "$EQ/cli-refused.cl.rc" \
   && ! cmp -s "$EQ/cli-pass.cl.out" "$EQ/cli-finding.cl.out"; then
  okf '%-30s the passing, finding and refusing inputs give different exits' "cli cells discriminate"
else badf '%-30s two cli cells gave the same exit or stdout' "cli cells do not discriminate"; fi

echo
report_end escalation-citation
