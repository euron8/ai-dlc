#!/usr/bin/env bash
# backlog-ledger — assert the carry-over backlog's two tools produce every verdict they
# claim, refuse the receipts they claim to refuse, and never archive a live entry.
#
# WHY EACH HALF IS HERE.
#
# `backlog-reverify.sh` is a CLASSIFIER that exits 0 always, so a run that emitted nothing at
# all would look identical to a clean backlog. Every arm below therefore asserts a POSITIVE
# verdict on a seeded entry, never the absence of a complaint.
#
# `backlog-rotate.sh` MOVES FILE CONTENT, which makes its failure mode data loss rather than a
# wrong report. Its decoy arm is the one that matters: an OPEN entry whose prose QUOTES the
# closing annotation while explaining it is the realistic way a rotation eats live work, and it
# is what the real docs/backlog.md preamble contains. Measured while the tool was being
# written: the first predicate swept exactly that entry AND the acceptance test reported PASS,
# because reverify shared the defect and the test reads their agreement. The two predicates are
# now deliberately different — rotate requires a numeric version at line start, reverify only
# line start — and arm `subset` pins that relation, because if they ever converge again the
# acceptance test goes quietly vacuous.
#
# THE SEEDS DO NOT COME FROM WHAT THE READER ACCEPTS. Entry shape comes from
# core/fixtures/ledger-rotate/seed.sh — the consumer ledger's own seed, written for a different
# tool by a different hand — so this fixture and the parser it tests cannot encode one
# understanding twice.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = one regressed, 2 = fixture broken.
# THE MUTANT BATTERY IS SCORED ON ONE DECIDING ARM PER MUTANT PLUS ONE NAMED TWIN. A mutant is a
# mutated copy of one component (the classifier, the rotator, lib.sh or the receipt library); an ARM
# is one seeded world plus its predicate, run against a root assembled from the real components with
# that one substituted. Per push each mutant runs its deciding arm (it must trip) and its twin (it must
# stay green, which proves the effect is confined). The full mutant x arm matrix is MEASURED by the
# --matrix argv mode and is re-measured whenever an arm or a mutant is added or changed. The recorded
# matrix plus the twin replaces the exact-vector assertion that a mutant fails only its own assertion.
# MUTANT-MATRIX mutation-no-parse decides=parse twins=route
# MUTANT-MATRIX mutation-parse-bare decides=parse twins=route
# MUTANT-MATRIX mutation-9-close decides=route twins=stdin
# MUTANT-MATRIX mutation-9-hand decides=route twins=stdin
# MUTANT-MATRIX mutation-stdin decides=stdin twins=route
# MUTANT-MATRIX mutation-memo-export decides=memo twins=stdin
# MUTANT-MATRIX mutation-memo-diffonly decides=memo twins=stdin
# MUTANT-MATRIX mutation-memo-fns decides=memo twins=stdin
# MUTANT-MATRIX mutation-stderr-route decides=cm twins=stdin
# MUTANT-MATRIX mutation-no-prefix decides=cm twins=route
# MUTANT-MATRIX mutation-check-empty decides=checkempty twins=sha
# MUTANT-MATRIX mutation-apply-marker decides=applymarker twins=sha
# MUTANT-MATRIX mutation-marker-presence decides=quoted twins=sha
# MUTANT-MATRIX mutation-no-census decides=census twins=sha
# MUTANT-MATRIX mutation-apply-unvalidated decides=declvalid twins=sha
# MUTANT-MATRIX mutation-sha-greedy decides=sha twins=census
# MUTANT-MATRIX mutation-loose decides=phantom twins=parse
# MUTANT-MATRIX mutation-heading-only decides=phantom twins=route
# MUTANT-MATRIX-REMEASURE bash core/fixtures/backlog-ledger/run.sh --matrix
set -uo pipefail
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "backlog-ledger: FIXTURE BROKEN: core/fixtures/lib/preamble.sh is absent" >&2; exit 2; }
# Ambient AI_DLC_* cleared, as the suite does: seed E sets AI_DLC_RECONCILE_MEMO itself on the
# drive that needs it, and an inherited one would otherwise decide which drive is "no memo".
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
RV="$(pick "$HERE/../../../scripts/backlog-reverify.sh" "$HERE/../../scripts/backlog-reverify.sh")"
RT="$(pick "$HERE/../../../scripts/backlog-rotate.sh"   "$HERE/../../scripts/backlog-rotate.sh")"
# A MISSING SUBJECT IS NOT A PASS. Every assertion reads a tool's output, so a run that cannot
# invoke one produces empty output and would score green on anything phrased as an absence.
[ -n "$RV" ] || { echo "FIXTURE ERROR: cannot locate scripts/backlog-reverify.sh" >&2; exit 2; }
[ -n "$RT" ] || { echo "FIXTURE ERROR: cannot locate scripts/backlog-rotate.sh" >&2; exit 2; }
# The could-not-measure rule the engine sources from beside itself. Every root below that carries a
# copy of the engine carries this too, or the copy refuses INPUT-UNRESOLVED and emits no row.
RLIB="$(dirname "$RV")/backlog-receipt-lib.sh"
[ -f "$RLIB" ] || { echo "FIXTURE ERROR: cannot locate scripts/backlog-receipt-lib.sh beside $RV" >&2; exit 2; }
echo "HERMETIC-CONSUMED $(cd "$(dirname "$RV")" && pwd)/${RV##*/}"
echo "HERMETIC-CONSUMED $(cd "$(dirname "$RT")" && pwd)/${RT##*/}"

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

FAIL=0
echo "backlog-ledger fixture"
echo

ok()   { printf '  ok    %-18s %s\n' "$1" "${2-}"; }
bad()  { printf '  FAIL  %-18s %s\n' "$1" "${2-}"; FAIL=1; }
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
. "$(cd "$HERE/../lib" && pwd)/matrix.sh" || { echo "FIXTURE ERROR: lib/matrix.sh not found" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/matrix.sh"
MATRIX=0
if [ "${1:-}" = "--matrix" ]; then MATRIX=1; fi
MROWS=0
# keep_mut <id> <rv|rt|lib|rlib> <file> -- save the mutated component of one mutant so any arm can be
# run against it later without rebuilding it.
KM="$WORK/km"; mkdir -p "$KM"
KM_IDS=""
keep_mut() { cp "$3" "$KM/$1.$2" && KM_IDS="$KM_IDS $1"; }
want() { # want <arm> <expected-status> <entry> <output>
  if grep -qE "^$2	$3	" <<<"$4"; then ok "$3" "$2  ($1)"
  else bad "$3" "expected $2, got: $(grep -E "	$3	" <<<"$4" | cut -f1 | tr "\n" " ")"; fi
}

# ---------------------------------------------------------------------------------------
# Seed A — one entry per verdict the classifier can produce.
# ---------------------------------------------------------------------------------------
LA="$WORK/a.md"
cat > "$LA" <<'EOM'
# Probe ledger

Preamble prose. Explains the closing form `**LANDED (v<version>, verified <sha>).**` inline,
which must NOT close anything.

## Receipts

A prose section that must not parse as an entry.

## BL-101 — has, anchor present

verify: has VERSION "."

## BL-102 — lacks, anchor present

verify: lacks VERSION "."

## BL-103 — sh exits zero

verify: sh true

## BL-104 — sh exits non-zero

verify: sh false

## BL-105 — no receipt

Body with no verify line.

## BL-106 — a CONSUMER verb, which this engine must refuse

verify: theirs_has VERSION "."

## BL-107 — empty substring

verify: has VERSION ""

## BL-108 — path absent from the tree

verify: has no/such/file.txt "x"

## BL-109 — greps the ledger itself

verify: has docs/backlog.md "BL-"

## BL-110 — backslash in the anchor

verify: lacks VERSION "foo\"bar"

## BL-111 — annotated closed

<br>**LANDED (v0.370.0, verified d4fd318).** Done.

verify: has VERSION "."

## BL-112 — sh with no command

verify: sh

## BL-113 — sh written across two lines, cut inside its quote (the engine reads one line)

verify: sh grep -q "alpha
beta" VERSION

## BL-114 — sh ending in a comment, valid on one line, the near-miss for the parse guard

verify: sh true # exits 0 -- the fix is present

## BL-115 — sh written across two lines joined by a trailing backslash; the fragment EXITS 0

verify: sh test -f VERSION \
  && test -f no-such-file-zz

## BL-116 — sh whose first line opens a heredoc; the fragment parses clean bare

verify: sh cat <<EOF | grep -q zz
zz
EOF
EOM

OUT="$(bash "$RV" "$LA" 2>&1)"

# POSITIVE CONTROL, FIRST. If the classifier emitted nothing, every `want` below would report
# its own failure but the cause would read as fourteen unrelated regressions rather than one dead
# harness. Assert it produced rows at all before asking what they say.
ROWS="$(grep -c '	' <<<"$OUT")"
if [ "$ROWS" -lt 16 ]; then
  echo "FIXTURE BROKEN: backlog-reverify.sh produced $ROWS rows over a 16-entry seed. Every"
  echo "assertion below reads those rows, so this is a dead harness, not sixteen regressions." >&2
  printf '%s\n' "$OUT" >&2
  exit 2
fi
ok "harness"          "classifier produced $ROWS rows over a 16-entry seed"

want "anchor present"     CLOSE-CANDIDATE BL-101 "$OUT"
want "anchor present"     STILL-LIVE      BL-102 "$OUT"
want "sh true"            CLOSE-CANDIDATE BL-103 "$OUT"
want "sh false"           STILL-LIVE      BL-104 "$OUT"
want "no receipt"         NEEDS-REVIEW    BL-105 "$OUT"
want "consumer verb"      NEEDS-REVIEW    BL-106 "$OUT"
want "empty substring"    NEEDS-REVIEW    BL-107 "$OUT"
want "missing path"       NEEDS-REVIEW    BL-108 "$OUT"
want "self-reference"     NEEDS-REVIEW    BL-109 "$OUT"
want "backslash anchor"   NEEDS-REVIEW    BL-110 "$OUT"
want "annotated"          ALREADY-CLOSED  BL-111 "$OUT"
want "empty sh"           NEEDS-REVIEW    BL-112 "$OUT"
want "two-line sh"        NEEDS-REVIEW    BL-113 "$OUT"
want "sh with comment"    CLOSE-CANDIDATE BL-114 "$OUT"
want "trailing backslash" NEEDS-REVIEW    BL-115 "$OUT"
want "open heredoc"       NEEDS-REVIEW    BL-116 "$OUT"

# A TWO-LINE `sh` RECEIPT IS REFUSED BY NAME, NOT MERELY NOT-CLOSED (BL-113). The engine reads a
# receipt as one line, so BL-113 arrives cut inside its quote; evaluated, `eval` dies at exit 2
# and the entry read STILL-LIVE forever with no hint — the filed defect. The refusal must name
# the cause so the author learns the receipt never ran.
#
# BL-114 is the near-miss, and it EXITS 0 ON PURPOSE. The first cut seeded `false # …` and an
# adversarial hand showed that cannot discriminate: `false` and a syntax error both exit non-zero
# and both read STILL-LIVE, so a guard that parsed the receipt and then ran a DIFFERENT string
# passed this arm. A receipt that exits 0 reads CLOSE-CANDIDATE only if it actually RAN.
#
# BL-115 and BL-116 are the two shapes a bare `bash -n` acquits — a trailing backslash and an
# open heredoc both parse clean as fragments — and BL-115's fragment exits 0, so before the
# brace-wrapped parse it read CLOSE-CANDIDATE: a live entry proposed for close on half a receipt.
BL113_ROW="$(grep -E '	BL-113	' <<<"$OUT")"
if grep -q "MALFORMED sh receipt" <<<"$BL113_ROW"; then
  ok "malformed-named" "the two-line receipt's refusal names it MALFORMED"; B_malformed=1
else
  bad "malformed-named" "BL-113's detail does not say MALFORMED: $(cut -c1-120 <<<"$BL113_ROW")"
fi
# The base-pass control the two parse-guard mutants below are scored on: the cells they move, read off the
# unmutated engine's run in one assertion (the generic `want` rows above carry no flag).
if grep -qE '^NEEDS-REVIEW	BL-115	' <<<"$OUT" && grep -qE '^NEEDS-REVIEW	BL-116	' <<<"$OUT" && grep -qE '^CLOSE-CANDIDATE	BL-114	' <<<"$OUT"; then
  ok "parse-base" "unmutated: BL-115 and BL-116 read NEEDS-REVIEW, BL-114 CLOSE-CANDIDATE"; B_parse=1
else
  bad "parse-base" "unmutated: BL-115/BL-116 are not NEEDS-REVIEW or BL-114 is not CLOSE-CANDIDATE, so the parse-guard mutants below have no base"
fi

# TWO MUTANTS. Whole-file copy, `cmp -s` refuses a sed that matched nothing. THE COPY NEEDS A
# ROOT: the engine walks up from its own directory for `VERSION` and sources reconcile/lib.sh
# beneath that root, so a bare copy in $WORK reports INPUT-UNRESOLVED and every row is absent —
# which scored as "the mutant broke the engine" on this arm's first run. Build the two markers.
MROOT="$WORK/mut-root"
mkdir -p "$MROOT/scripts" "$MROOT/core/skills/ai-dlc-update/reconcile"
printf '0.0.0\n' > "$MROOT/VERSION"
cp "$(dirname "$RV")/../core/skills/ai-dlc-update/reconcile/lib.sh" "$MROOT/core/skills/ai-dlc-update/reconcile/lib.sh" 2>/dev/null \
  || cp "$(dirname "$RV")/../../core/skills/ai-dlc-update/reconcile/lib.sh" "$MROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
cp "$RLIB" "$MROOT/scripts/backlog-receipt-lib.sh"
MUT="$MROOT/scripts/backlog-reverify.sh"
# The guard line is the anchor for both; assert it is unique so a sed cannot edit a second copy.
GN="$(grep -c '^ *if ! bash -n -c "\$SH_PROG" >/dev/null 2>&1; then$' "$RV")" || GN=0
if [ "$GN" -eq 1 ]; then ok "parse-anchor" "the parse guard line is unique in the engine"
else bad "parse-anchor" "the parse guard line appears $GN times; the mutations below need exactly one"; fi
# 1. THE GUARD DISARMED. BL-115 regresses to CLOSE-CANDIDATE (the false close) and BL-113 loses
#    its MALFORMED naming; BL-114 stays CLOSE-CANDIDATE, the control. BL-113 no longer falls to
#    STILL-LIVE: the stderr route (seed F) also catches an eval-time syntax error, so the two
#    guards OVERLAP on that seed and the parse guard's own contribution there is the diagnosis
#    that the receipt was cut at a newline. BL-115 is the subject only the parse guard can see —
#    its fragment exits 0 and writes nothing to stderr.
sed 's/^\( *\)if ! bash -n -c "\$SH_PROG" >\/dev\/null 2>&1; then$/\1if false; then/' "$RV" > "$MUT"
if cmp -s "$RV" "$MUT"; then
  bad "mutation-no-parse" "the mutation matched nothing, so the parse guard is unproven"
else
  keep_mut mutation-no-parse rv "$MUT"
  MOUT="$(bash "$MUT" "$LA" 2>&1)"
  if ! grep -qE '^CLOSE-CANDIDATE	BL-114	' <<<"$MOUT"; then
    bad "mutation-no-parse" "the control row (BL-114 CLOSE-CANDIDATE) is gone — the mutant broke the engine, not the guard"
  elif M113="$(grep -E '	BL-113	' <<<"$MOUT")" && ! grep -q "MALFORMED sh receipt" <<<"$M113" \
       && grep -qE '^CLOSE-CANDIDATE	BL-115	' <<<"$MOUT"; then
    mutant_killed "$(( ${B_malformed:-0} && ${B_parse:-0} ))" mutation-no-parse "mutation-no-parse: with the guard disarmed the cut-quote receipt loses its MALFORMED diagnosis and the backslash one CLOSES — the guard is load-bearing in both directions"
  else
    bad "mutation-no-parse" "SURVIVED: guard disarmed and the seeds did not regress: $(grep -E '	BL-11[35]	' <<<"$MOUT" | cut -f1,2 | tr '\n' ' ')"
  fi
fi
# 2. THE BARE RECEIPT PARSED instead of the brace-wrapped copy — the first cut. BL-115's fragment
#    parses clean and exits 0, so it CLOSES; BL-113 is still refused, the control.
sed 's/^\( *\)if ! bash -n -c "\$SH_PROG" >\/dev\/null 2>&1; then$/\1if ! bash -n -c "$REST" >\/dev\/null 2>\&1; then/' "$RV" > "$MUT"
if cmp -s "$RV" "$MUT"; then
  bad "mutation-parse-bare" "the mutation matched nothing, so the brace wrap is unproven"
else
  keep_mut mutation-parse-bare rv "$MUT"
  MOUT="$(bash "$MUT" "$LA" 2>&1)"
  if ! grep -qE '^NEEDS-REVIEW	BL-113	' <<<"$MOUT"; then
    bad "mutation-parse-bare" "the control row (BL-113 NEEDS-REVIEW) is gone — the mutant broke the engine, not the wrap"
  elif grep -qE '^CLOSE-CANDIDATE	BL-115	' <<<"$MOUT" && grep -qE '^STILL-LIVE	BL-116	' <<<"$MOUT"; then
    mutant_killed "$(( ${B_malformed:-0} && ${B_parse:-0} ))" mutation-parse-bare "mutation-parse-bare: parsing the bare receipt acquits the backslash fragment (CLOSES) and the heredoc opener (STILL-LIVE) — the brace wrap is what catches them"
  else
    bad "mutation-parse-bare" "SURVIVED: bare parse and the seeds did not regress: $(grep -E '	BL-11[56]	' <<<"$MOUT" | cut -f1,2 | tr '\n' ' ')"
  fi
fi

# ---------------------------------------------------------------------------------------
# Seed C — how an `sh` receipt's EXIT CODE routes (BL-089).
# ---------------------------------------------------------------------------------------
# Exit 9 is this corpus's could-not-measure code, and it read STILL-LIVE — the same words as a
# genuine reproduction. It must read NEEDS-REVIEW with an `unresolved:` detail, and NOTHING
# ELSE: CLOSE-CANDIDATE proposes the close outright, and HAND-REVIEW is what backlog-rotate.sh
# accepts as permission to move an annotated entry, so either turns "I could not tell" into a
# false close. The controls sit in the SAME seed, one exit code apart: 0 must still close, and
# 1, 126 and a BARE 127 (no diagnostic from the receipt's own shell) must still read STILL-LIVE
# — so a fix widened from "9" to "any code that is not 1" is caught. BL-124 is the receipt's own
# shell reporting `command not found`: that is the stderr route (seed E owns it), and here it
# pins that the route reads NEEDS-REVIEW and never a close.
LC="$WORK/c.md"; LC_ROUTE="$WORK/c-route.md"
cat > "$LC" <<'EOM'
# Probe ledger — exit routing

## BL-121 — sh exits 0

verify: sh exit 0

## BL-122 — sh exits 1

verify: sh exit 1

## BL-123 — sh exits 9, the could-not-measure code

verify: sh exit 9

## BL-124 — sh exits 127, a command that is not there

verify: sh no-such-command-bl089-zz

## BL-125 — sh exits 126

verify: sh exit 126

## BL-126 — sh exits a bare 127, nothing on stderr

verify: sh exit 127
EOM

# route_ok <output> — 0 when every row of seed C routes correctly, else 1 with the reason on
# stdout. Every conjunct is PRESENCE-shaped, so an engine that emitted nothing fails it.
route_ok() {
  local o="$1" id n
  for id in 121 122 123 124 125 126; do
    n="$(grep -cE "	BL-$id	" <<<"$o")" || n=0
    [ "$n" -eq 1 ] || { echo "BL-$id has $n rows, want 1"; return 1; }
  done
  grep -qE '^CLOSE-CANDIDATE	BL-121	' <<<"$o" || { echo "exit 0 is not CLOSE-CANDIDATE"; return 1; }
  grep -qE '^STILL-LIVE	BL-122	'      <<<"$o" || { echo "exit 1 is not STILL-LIVE"; return 1; }
  grep -qE '^NEEDS-REVIEW	BL-124	unresolved:' <<<"$o" || { echo "exit 127 with the receipt's own 'command not found' is not NEEDS-REVIEW unresolved:"; return 1; }
  grep -qE '^STILL-LIVE	BL-125	'      <<<"$o" || { echo "exit 126 is not STILL-LIVE"; return 1; }
  grep -qE '^STILL-LIVE	BL-126	'      <<<"$o" || { echo "a bare exit 127 is not STILL-LIVE"; return 1; }
  grep -qE '^NEEDS-REVIEW	BL-123	unresolved:' <<<"$o" \
    || { echo "exit 9 reads '$(grep -E '	BL-123	' <<<"$o" | cut -f1)', want NEEDS-REVIEW with an unresolved: detail"; return 1; }
  return 0
}

cp "$LC" "$LC_ROUTE"
COUT="$(bash "$RV" "$LC" 2>&1)"
if why="$(route_ok "$COUT")"; then
  ok "exit-9-routing" "exit 9 reads NEEDS-REVIEW unresolved:, beside 0 CLOSE-CANDIDATE and 1/126/bare-127 STILL-LIVE"; B_route=1
else
  bad "exit-9-routing" "$why"
fi

# THREE COPIES OF THE ENGINE, SAME ROOT AS THE MUTANTS ABOVE. The unmutated control runs FIRST:
# a copy that cannot find VERSION or lib.sh emits INPUT-UNRESOLVED and no rows, and every mutant
# driven through that root would then fail route_ok for THAT reason and score a kill it did not
# earn. So the control must PASS route_ok, which requires the baseline rows to be there.
[ -f "$MROOT/VERSION" ] && [ -f "$MROOT/core/skills/ai-dlc-update/reconcile/lib.sh" ] \
  || bad "exit-9-mut-root" "the mutant root lacks VERSION or reconcile/lib.sh, so no mutant verdict below means anything"
cp "$RV" "$MUT"
MOUT="$(bash "$MUT" "$LC" 2>&1)"
if why="$(route_ok "$MOUT")" && grep -qE '^STILL-LIVE	BL-122	' <<<"$MOUT"; then
  ok "exit-9-control" "the unmutated copy in the mutant root routes seed C correctly (baseline BL-122 STILL-LIVE present)"; B_route_ctl=1
else
  bad "exit-9-control" "the unmutated copy fails seed C, so the mutant root is broken and the verdicts below are void: $why"
fi
# Each mutant must fail route_ok while its baseline row (BL-122 STILL-LIVE) is still there —
# that row proves the copy RAN, so the failure is the mutation and not a dead engine.
score_route_mut() { # <arm> <description-of-regression> <base-pass flag>
  local mo why
  keep_mut "$1" rv "$MUT"
  mo="$(bash "$MUT" "$LC" 2>&1)"
  if ! grep -qE '^STILL-LIVE	BL-122	' <<<"$mo"; then
    bad "$1" "the baseline row (BL-122 STILL-LIVE) is gone — the mutant broke the engine, not the routing"
  elif why="$(route_ok "$mo")"; then
    bad "$1" "SURVIVED: with $2 the arm still passes"
  else
    mutant_killed "$3" "$1" "$1: killed: $2 — $why"
  fi
}
# Anchors, each asserted unique so a sed cannot edit a second copy.
A0N="$(grep -c '^ *if \[ "\$SH_RC" -eq 0 \]; then$' "$RV")" || A0N=0
A9N="$(grep -c '^ *emit "NEEDS-REVIEW" "\$LABEL" "unresolved: the sh receipt exited 9,' "$RV")" || A9N=0
if [ "$A0N" -eq 1 ] && [ "$A9N" -eq 1 ]; then ok "exit-9-anchors" "both routing anchors are unique in the engine"
else bad "exit-9-anchors" "routing anchors appear $A0N and $A9N times; the mutations below need exactly one each"; fi
# 1. 9 ROUTED TO CLOSE-CANDIDATE — the false close proposed outright.
if ! sed 's/^\( *\)if \[ "\$SH_RC" -eq 0 \]; then$/\1if [ "$SH_RC" -eq 0 ] || [ "$SH_RC" -eq 9 ]; then/' "$RV" > "$MUT"; then
  bad "mutation-9-close" "DID NOT APPLY: sed failed"
elif cmp -s "$RV" "$MUT"; then
  bad "mutation-9-close" "DID NOT APPLY: the mutation matched nothing, so the exit-0 guard is unproven"
else
  score_route_mut "mutation-9-close" "exit 9 routed to CLOSE-CANDIDATE" "$(( ${B_route:-0} && ${B_route_ctl:-0} ))"
fi
# 2. 9 ROUTED TO HAND-REVIEW — the false close backlog-rotate.sh accepts. The detail is kept, so
#    only the STATUS moves and the kill cannot come from the `unresolved:` conjunct.
if ! sed 's/^\( *\)emit "NEEDS-REVIEW" "\$LABEL" "unresolved: the sh receipt exited 9,/\1emit "HAND-REVIEW" "$LABEL" "unresolved: the sh receipt exited 9,/' "$RV" > "$MUT"; then
  bad "mutation-9-hand" "DID NOT APPLY: sed failed"
elif cmp -s "$RV" "$MUT"; then
  bad "mutation-9-hand" "DID NOT APPLY: the mutation matched nothing, so the NEEDS-REVIEW route is unproven"
else
  score_route_mut "mutation-9-hand" "exit 9 routed to HAND-REVIEW" "$(( ${B_route:-0} && ${B_route_ctl:-0} ))"
fi

# ---------------------------------------------------------------------------------------
# Seed D — an `sh` receipt that READS STDIN must not swallow the entries after it.
# ---------------------------------------------------------------------------------------
# The receipt loop is fed by a heredoc of ledger records, so an eval that inherits stdin hands
# a stdin-reading receipt EVERY LATER RECORD. Measured before the fix: first receipt
# `sh cat >/dev/null` over three entries produced ONE row -- the later entries were neither
# STILL-LIVE nor CLOSE-CANDIDATE, they were simply absent. The reader is FIRST on purpose, and
# the entries after it carry three different verdicts, so a swallow of any length and a
# mis-scored row are both visible: every conjunct is PRESENCE-shaped.
LD="$WORK/d.md"
cat > "$LD" <<'EOM'
# Probe ledger — a receipt that reads stdin

## BL-131 — sh receipt reading stdin, first

verify: sh cat >/dev/null

## BL-132 — sh exits non-zero, after the reader

verify: sh false

## BL-133 — sh exits zero, after the reader

verify: sh true

## BL-134 — a non-sh receipt, after the reader

verify: lacks VERSION "."
EOM
stdin_ok() { # <output> — 0 when all four rows are present, once each, with the right verdict
  local o="$1" id n
  for id in 131 132 133 134; do
    n="$(grep -cE "	BL-$id	" <<<"$o")" || n=0
    [ "$n" -eq 1 ] || { echo "BL-$id has $n rows, want 1"; return 1; }
  done
  grep -qE '^CLOSE-CANDIDATE	BL-131	' <<<"$o" || { echo "the reader itself is not CLOSE-CANDIDATE (cat over a closed stdin exits 0)"; return 1; }
  grep -qE '^STILL-LIVE	BL-132	'      <<<"$o" || { echo "BL-132 (sh false) is not STILL-LIVE"; return 1; }
  grep -qE '^CLOSE-CANDIDATE	BL-133	' <<<"$o" || { echo "BL-133 (sh true) is not CLOSE-CANDIDATE"; return 1; }
  grep -qE '^STILL-LIVE	BL-134	'      <<<"$o" || { echo "BL-134 (lacks, anchor present) is not STILL-LIVE"; return 1; }
  return 0
}
DOUT="$(bash "$RV" "$LD" 2>&1)"
if why="$(stdin_ok "$DOUT")"; then
  ok "stdin-receipt" "a receipt reading stdin leaves all four rows with their verdicts"; B_stdin=1
else
  bad "stdin-receipt" "a stdin-reading receipt swallowed later entries: $why"
fi
# THE MUTANT: the redirect removed. Same mutant root as above, and its unmutated control runs
# first on the same seed so a dead root cannot score the kill. The kill needs BL-131's row
# PRESENT (the copy ran) and the rows after it missing.
DAN="$(grep -c '^ *( unset \$LIB_VARS; unset -f \$LIB_FNS; cd "\$REPO_ROOT" && eval "\$REST" </dev/null ) >/dev/null 2>"\$ERRF"$' "$RV")" || DAN=0
if [ "$DAN" -eq 1 ]; then ok "stdin-anchor" "the receipt eval line is unique in the engine"
else bad "stdin-anchor" "the receipt eval line appears $DAN times; the mutation below needs exactly one"; fi
cp "$RV" "$MUT"
MOUT="$(bash "$MUT" "$LD" 2>&1)"
if why="$(stdin_ok "$MOUT")"; then
  ok "stdin-control" "the unmutated copy in the mutant root keeps all four rows"; B_stdin_ctl=1
else
  bad "stdin-control" "the unmutated copy fails seed D, so the mutant verdict below is void: $why"
fi
if ! sed 's@^\( *( unset \$LIB_VARS; unset -f \$LIB_FNS; cd "\$REPO_ROOT" && eval "\$REST"\) </dev/null ) >/dev/null 2>"\$ERRF"$@\1 ) >/dev/null 2>"$ERRF"@' "$RV" > "$MUT"; then
  bad "mutation-stdin" "DID NOT APPLY: sed failed"
elif cmp -s "$RV" "$MUT"; then
  bad "mutation-stdin" "DID NOT APPLY: the mutation matched nothing, so the closed stdin is unproven"
else
  keep_mut mutation-stdin rv "$MUT"
  MOUT="$(bash "$MUT" "$LD" 2>&1)"
  if ! grep -qE '	BL-131	' <<<"$MOUT"; then
    bad "mutation-stdin" "the reader's own row (BL-131) is gone -- the mutant broke the engine, not the redirect"
  elif why="$(stdin_ok "$MOUT")"; then
    bad "mutation-stdin" "SURVIVED: with the receipt's stdin inherited, seed D still keeps every row"
  else
    mutant_killed "$(( ${B_stdin:-0} && ${B_stdin_ctl:-0} ))" mutation-stdin "mutation-stdin: killed: with the receipt's stdin inherited the reader swallows the later entries -- $why"
  fi
fi

# ---------------------------------------------------------------------------------------
# Seed E — a receipt must not inherit the state reconcile/lib.sh put in the engine (BL-382).
# ---------------------------------------------------------------------------------------
# The engine sources lib.sh, which EXPORTS `AI_DLC_RECONCILE_MEMO` and defines its functions,
# and a receipt that drives a reconcile script then borrows the engine's memo: BL-308's receipt
# read exit 1 through the engine and 0 alone. BL-141 is sensitive to the variable, BL-142 to the
# functions. The arm compares the engine's verdict against the BARE verdict — the same receipt
# run in a clean shell — and asserts the world discriminates first: with the variable set,
# BL-141 alone must exit non-zero, or this seed cannot see a leak at all.
#
# TWO DRIVES. With no inbound memo, lib.sh makes one and the variable is NEW to the engine. With
# one EXPORTED BY THE CALLER (backlog-rotate.sh drives this engine as a child), the variable was
# already there before lib.sh ran, so a fix that only removes what the source ADDED leaks it.
LE="$WORK/e.md"
cat > "$LE" <<'EOM'
# Probe ledger — lib.sh state leaking into a receipt

## BL-140 — sh exits 1, the baseline

verify: sh exit 1

## BL-141 — the receipt passes only when no memo is exported to it

verify: sh [ -z "${AI_DLC_RECONCILE_MEMO:-}" ]

## BL-142 — the receipt passes only when lib.sh's functions are absent

verify: sh ! type ai_dlc_memo_dir >/dev/null 2>&1
EOM
rc2v() { case "$1" in 0) echo CLOSE-CANDIDATE ;; 9) echo NEEDS-REVIEW ;; *) echo STILL-LIVE ;; esac; }
bare_rc() { # <receipt> — run one receipt in a clean shell, as an author would
  env -u AI_DLC_RECONCILE_MEMO bash -c "$1" </dev/null >/dev/null 2>&1; echo $?
}
R141='[ -z "${AI_DLC_RECONCILE_MEMO:-}" ]'
R142='! type ai_dlc_memo_dir >/dev/null 2>&1'
INMEMO="$WORK/inbound-memo"; mkdir -p "$INMEMO"
LEAK_RC="$(AI_DLC_RECONCILE_MEMO="$INMEMO" bash -c "$R141" </dev/null >/dev/null 2>&1; echo $?)"
if [ "$LEAK_RC" -ne 0 ] && [ "$(bare_rc "$R141")" -eq 0 ]; then
  ok "memo-discriminates" "BL-141 exits 0 bare and $LEAK_RC with the memo exported — the seed can see a leak"
else
  bad "memo-discriminates" "BL-141 exits $(bare_rc "$R141") bare and $LEAK_RC with the memo set; the seed cannot separate a leak from none"
fi
# leak_ok <output> — every row present once, BL-140 STILL-LIVE (the copy ran), and BL-141/142
# carrying their BARE verdicts. Presence-shaped throughout.
leak_ok() {
  local o="$1" id n want
  for id in 140 141 142; do
    n="$(grep -cE "	BL-$id	" <<<"$o")" || n=0
    [ "$n" -eq 1 ] || { echo "BL-$id has $n rows, want 1"; return 1; }
  done
  grep -qE '^STILL-LIVE	BL-140	' <<<"$o" || { echo "baseline BL-140 is not STILL-LIVE"; return 1; }
  want="$(rc2v "$(bare_rc "$R141")")"
  grep -qE "^$want	BL-141	" <<<"$o" || { echo "BL-141 reads '$(grep -E '	BL-141	' <<<"$o" | cut -f1)' through the engine, '$want' bare — the memo variable leaked"; return 1; }
  want="$(rc2v "$(bare_rc "$R142")")"
  grep -qE "^$want	BL-142	" <<<"$o" || { echo "BL-142 reads '$(grep -E '	BL-142	' <<<"$o" | cut -f1)' through the engine, '$want' bare — lib.sh's functions leaked"; return 1; }
  return 0
}
leak_both() { # <engine> — both drives; prints the first failure
  local e="$1" o why
  o="$(env -u AI_DLC_RECONCILE_MEMO bash "$e" "$LE" 2>&1)"
  why="$(leak_ok "$o")" || { echo "no inbound memo: $why"; return 1; }
  o="$(AI_DLC_RECONCILE_MEMO="$INMEMO" bash "$e" "$LE" 2>&1)"
  why="$(leak_ok "$o")" || { echo "caller-exported memo: $why"; return 1; }
  return 0
}
if why="$(leak_both "$RV")"; then
  ok "memo-leak" "engine verdicts equal bare verdicts for BL-141/142, with and without a caller-exported memo"; B_memo=1
else
  bad "memo-leak" "$why"
fi
[ -d "$INMEMO" ] && ok "memo-caller-owned" "a caller's memo directory survives the engine run" \
  || bad "memo-caller-owned" "the engine removed a memo directory its caller owns"
cp "$RV" "$MUT"
if why="$(leak_both "$MUT")"; then ok "memo-control" "the unmutated copy in the mutant root passes seed E both ways"; B_memo_ctl=1
else bad "memo-control" "the unmutated copy fails seed E, so the mutant verdicts below are void: $why"; fi
score_leak_mut() { # <arm> <description> <base-pass flag>
  local why o
  keep_mut "$1" rv "$MUT"
  o="$(env -u AI_DLC_RECONCILE_MEMO bash "$MUT" "$LE" 2>&1)"
  if ! grep -qE '^STILL-LIVE	BL-140	' <<<"$o"; then
    bad "$1" "the baseline row (BL-140 STILL-LIVE) is gone — the mutant broke the engine, not the unset"
  else
    # The no-inbound-memo drive was already run above as `o`; leak_ok on it is leak_both's first
    # drive, so only the caller-exported drive is run here (one engine run fewer per mutant).
    if why="$(leak_ok "$o")"; then
      o="$(AI_DLC_RECONCILE_MEMO="$INMEMO" bash "$MUT" "$LE" 2>&1)"
      why="$(leak_ok "$o")" && why="" || why="caller-exported memo: $why"
    else
      why="no inbound memo: $why"
    fi
    if [ -z "$why" ]; then
      bad "$1" "SURVIVED: with $2 seed E still passes"
    else
      mutant_killed "$3" "$1" "$1: killed: $2 — $why"
    fi
  fi
}
UVN="$(grep -c '^ *( unset \$LIB_VARS; unset -f \$LIB_FNS; cd ' "$RV")" || UVN=0
NMN="$(grep -c '^LIB_VARS="AI_DLC_RECONCILE_MEMO \$(_rv_added ' "$RV")" || NMN=0
if [ "$UVN" -eq 1 ] && [ "$NMN" -eq 1 ]; then ok "memo-anchors" "the unset line and the named-variable line are unique in the engine"
else bad "memo-anchors" "anchors appear $UVN and $NMN times; the mutations below need exactly one each"; fi
# 1. THE VARIABLES RE-EXPORTED to the receipt: the unset of lib.sh's variables removed.
if ! sed 's/^\( *\)( unset \$LIB_VARS; unset -f \$LIB_FNS; cd /\1( unset -f $LIB_FNS; cd /' "$RV" > "$MUT"; then
  bad "mutation-memo-export" "DID NOT APPLY: sed failed"
elif cmp -s "$RV" "$MUT"; then
  bad "mutation-memo-export" "DID NOT APPLY: the mutation matched nothing"
else
  score_leak_mut "mutation-memo-export" "lib.sh's variables left exported to every receipt" "$(( ${B_memo:-0} && ${B_memo_ctl:-0} ))"
fi
# 2. DIFF-ONLY: the variable is no longer named outright, so a CALLER's memo leaks through.
if ! sed 's/^LIB_VARS="AI_DLC_RECONCILE_MEMO \$(_rv_added /LIB_VARS="$(_rv_added /' "$RV" > "$MUT"; then
  bad "mutation-memo-diffonly" "DID NOT APPLY: sed failed"
elif cmp -s "$RV" "$MUT"; then
  bad "mutation-memo-diffonly" "DID NOT APPLY: the mutation matched nothing"
else
  score_leak_mut "mutation-memo-diffonly" "only the variables lib.sh ADDED removed, a caller-exported memo kept" "$(( ${B_memo:-0} && ${B_memo_ctl:-0} ))"
fi
# 3. THE FUNCTIONS LEFT DEFINED in the receipt's shell.
if ! sed 's/^\( *\)( unset \$LIB_VARS; unset -f \$LIB_FNS; cd /\1( unset $LIB_VARS; cd /' "$RV" > "$MUT"; then
  bad "mutation-memo-fns" "DID NOT APPLY: sed failed"
elif cmp -s "$RV" "$MUT"; then
  bad "mutation-memo-fns" "DID NOT APPLY: the mutation matched nothing"
else
  score_leak_mut "mutation-memo-fns" "lib.sh's functions left defined in every receipt" "$(( ${B_memo:-0} && ${B_memo_ctl:-0} ))"
fi

# ---------------------------------------------------------------------------------------
# Seed F — a receipt that exits non-zero having MEASURED NOTHING (BL-089, second subject).
# ---------------------------------------------------------------------------------------
# BL-151 is BL-081's filed shape: a helper the receipt calls is gone, `$( )` swallows the 127,
# and the test on the empty result exits 1. BL-152 is BL-066's: a fragment that parses as a
# receipt and dies at eval time. Both used to read STILL-LIVE; both must read NEEDS-REVIEW with
# an `unresolved:` detail.
#
# THE NEAR-MISSES CARRY THE STRINGS AND THE EXIT CODES. BL-153's SUBJECT prints `No such file or
# directory` and exits 1 — the ordinary way a receipt observes a live defect. BL-154's subject
# is a child script whose own shell prints `<path>: line 1: ...: No such file or directory`,
# so a rule keyed on `line N:` without the engine's own name is caught. BL-155's child script
# calls a helper it does not ship and exits 127 with `command not found`, so a rule keyed on 127
# or on the string alone is caught. All three must stay STILL-LIVE.
SUBJ="$WORK/subjects"; mkdir -p "$SUBJ"
printf 'cat "%s/absent-input.txt"\n' "$SUBJ" > "$SUBJ/reads-missing.sh"
printf 'grep -q x < "%s/absent-input.txt"\n' "$SUBJ" > "$SUBJ/redirect-missing.sh"
printf 'subject_helper_bl089_zz\n' > "$SUBJ/calls-missing.sh"
LF="$WORK/f.md"
{
  printf '# Probe ledger — could-not-measure\n\n'
  printf '## BL-150 — sh exits 1, the baseline\n\nverify: sh exit 1\n\n'
  printf '## BL-151 — a helper the receipt calls is gone\n\nverify: sh b=$(receipt_helper_bl089_zz x); [ -n "$b" ]\n\n'
  printf '## BL-152 — an extracted fragment that dies at eval time\n\nverify: sh eval "f() { echo"; f\n\n'
  printf '## BL-153 — the subject reports a missing file and exits 1\n\nverify: sh bash "%s/reads-missing.sh"\n\n' "$SUBJ"
  printf '## BL-154 — a child shell reports a missing file on a line-numbered prefix\n\nverify: sh bash "%s/redirect-missing.sh"\n\n' "$SUBJ"
  printf '## BL-155 — the subject calls a helper it does not ship, exit 127\n\nverify: sh bash "%s/calls-missing.sh"\n\n' "$SUBJ"
} > "$LF"
cm_ok() {
  local o="$1" id n
  for id in 150 151 152 153 154 155; do
    n="$(grep -cE "	BL-$id	" <<<"$o")" || n=0
    [ "$n" -eq 1 ] || { echo "BL-$id has $n rows, want 1"; return 1; }
  done
  grep -qE '^STILL-LIVE	BL-150	' <<<"$o" || { echo "baseline BL-150 is not STILL-LIVE"; return 1; }
  grep -qE '^NEEDS-REVIEW	BL-151	unresolved:.*command not found' <<<"$o" || { echo "BL-151 (missing helper) reads '$(grep -E '	BL-151	' <<<"$o" | cut -f1)', want NEEDS-REVIEW naming 'command not found'"; return 1; }
  grep -qE '^NEEDS-REVIEW	BL-152	unresolved:.*syntax error' <<<"$o" || { echo "BL-152 (eval-time syntax error) reads '$(grep -E '	BL-152	' <<<"$o" | cut -f1)', want NEEDS-REVIEW naming 'syntax error'"; return 1; }
  grep -qE '^STILL-LIVE	BL-153	' <<<"$o" || { echo "BL-153 (subject prints No such file, exit 1) is not STILL-LIVE"; return 1; }
  grep -qE '^STILL-LIVE	BL-154	' <<<"$o" || { echo "BL-154 (a child shell's line-numbered No such file) is not STILL-LIVE"; return 1; }
  grep -qE '^STILL-LIVE	BL-155	' <<<"$o" || { echo "BL-155 (the subject's own command not found, exit 127) is not STILL-LIVE"; return 1; }
  return 0
}
FOUT="$(bash "$RV" "$LF" 2>&1)"
if why="$(cm_ok "$FOUT")"; then
  ok "cant-measure" "missing helper and eval-time syntax error read NEEDS-REVIEW; three subject-side near-misses stay STILL-LIVE"; B_cm=1
else
  bad "cant-measure" "$why"
fi
cp "$RV" "$MUT"
MOUT="$(bash "$MUT" "$LF" 2>&1)"
if why="$(cm_ok "$MOUT")"; then ok "cant-measure-control" "the unmutated copy in the mutant root passes seed F — its own name differs, so the prefix is derived, not fixed"; B_cm_ctl=1
else bad "cant-measure-control" "the unmutated copy fails seed F, so the mutant verdict below is void: $why"; fi
CMN="$(grep -c '^ *elif \[ -n "\$SH_WHY" \]; then$' "$RV")" || CMN=0
if [ "$CMN" -eq 1 ]; then ok "cant-measure-anchor" "the stderr routing line is unique in the engine"
else bad "cant-measure-anchor" "the stderr routing line appears $CMN times; the mutation below needs exactly one"; fi
# THE STDERR ROUTING DROPPED: every could-not-measure receipt falls back to STILL-LIVE.
if ! sed 's/^\( *\)elif \[ -n "\$SH_WHY" \]; then$/\1elif false; then/' "$RV" > "$MUT"; then
  bad "mutation-stderr-route" "DID NOT APPLY: sed failed"
elif cmp -s "$RV" "$MUT"; then
  bad "mutation-stderr-route" "DID NOT APPLY: the mutation matched nothing"
else
  keep_mut mutation-stderr-route rv "$MUT"
  MOUT="$(bash "$MUT" "$LF" 2>&1)"
  if ! grep -qE '^STILL-LIVE	BL-150	' <<<"$MOUT"; then
    bad "mutation-stderr-route" "the baseline row (BL-150 STILL-LIVE) is gone — the mutant broke the engine, not the routing"
  elif why="$(cm_ok "$MOUT")"; then
    bad "mutation-stderr-route" "SURVIVED: with the stderr routing dropped seed F still passes"
  else
    mutant_killed "$(( ${B_cm:-0} && ${B_cm_ctl:-0} ))" mutation-stderr-route "mutation-stderr-route: killed: stderr routing dropped — $why"
  fi
fi
# THE OWN-PREFIX DROPPED: the three strings matched on any stderr line. The near-misses must die.
# The prefix rule lives in scripts/backlog-receipt-lib.sh, which the engine sources from beside
# itself, so the mutation edits the mutant root's COPY of that helper and drives an unmutated engine.
PFN="$(grep -c '^      "\$SELF_NAME: line "\*|"\$SELF_NAME: eval: line "\*) ;;$' "$RLIB")" || PFN=0
if [ "$PFN" -eq 1 ]; then ok "prefix-anchor" "the own-interpreter prefix line is unique in the helper"
else bad "prefix-anchor" "the own-interpreter prefix line appears $PFN times; the mutation below needs exactly one"; fi
cp "$RV" "$MUT"
MLIB="$MROOT/scripts/backlog-receipt-lib.sh"
if ! sed 's/^\(      \)"\$SELF_NAME: line "\*|"\$SELF_NAME: eval: line "\*) ;;$/\1*) ;;/' "$RLIB" > "$MLIB"; then
  bad "mutation-no-prefix" "DID NOT APPLY: sed failed"
elif cmp -s "$RLIB" "$MLIB"; then
  bad "mutation-no-prefix" "DID NOT APPLY: the mutation matched nothing"
else
  keep_mut mutation-no-prefix rlib "$MLIB"
  MOUT="$(bash "$MUT" "$LF" 2>&1)"
  if ! grep -qE '^STILL-LIVE	BL-150	' <<<"$MOUT"; then
    bad "mutation-no-prefix" "the baseline row (BL-150 STILL-LIVE) is gone — the mutant broke the engine, not the prefix"
  elif why="$(cm_ok "$MOUT")"; then
    bad "mutation-no-prefix" "SURVIVED: with any stderr line counted, seed F still passes"
  else
    mutant_killed "$(( ${B_cm:-0} && ${B_cm_ctl:-0} ))" mutation-no-prefix "mutation-no-prefix: killed: any stderr line counted — $why"
  fi
fi
# Restore the mutant root's helper: every later drive through this root must use the clean rule.
cp "$RLIB" "$MLIB"

# The preamble and the `## Receipts` prose section must contribute NO row. A parser that
# treated any heading as an entry produced a phantom `Receipts` entry that came back
# ALREADY-CLOSED, because that section quotes the closing form while explaining it.
if grep -qE '	(Receipts|Probe ledger)	' <<<"$OUT"; then
  bad "no-phantom-entry" "prose parsed as an entry"
else
  ok "no-phantom-entry" "preamble and prose sections contribute no row"
fi

# The consumer verb must be refused BY NAME, not merely land in NEEDS-REVIEW for some other
# reason — that is the whole mechanical basis for the two ledgers not being interchangeable.
BL106_ROW="$(grep -E '	BL-106	' <<<"$OUT")"
if grep -q "theirs_has" <<<"$BL106_ROW"; then
  ok "scope-separation" "the consumer's verb is named in the refusal"
else
  bad "scope-separation" "BL-106's detail does not name theirs_has"
fi

# ---------------------------------------------------------------------------------------
# Seed B — rotation, and the decoy that must survive it.
# ---------------------------------------------------------------------------------------
LB="$WORK/b.md"
cat > "$LB" <<'EOM'
# Probe backlog

Preamble that must never move.

## BL-201 — open

verify: has VERSION "."

## BL-202 — closed, moves

<br>**LANDED (v0.370.0, verified d4fd318).** Done.

verify: has VERSION "."

## BL-203 — DECOY: open, prose quotes the annotation form mid-sentence

The author writes **LANDED (vX.Y.Z, verified <sha>).** only once the receipt goes green.

verify: lacks VERSION "."
EOM

ROT="$(bash "$RT" "$LB" --check 2>&1)"
if grep -q "BL-202" <<<"$ROT"; then ok "rotate-moves" "the annotated entry is selected"
else bad "rotate-moves" "the annotated entry was NOT selected: $ROT"; fi

if grep -q "BL-203" <<<"$ROT"; then
  bad "rotate-decoy" "an OPEN entry whose prose QUOTES the annotation form was selected for archive — this is the data-loss case"
else
  ok "rotate-decoy" "prose quoting the annotation form does not close an entry"
fi

if grep -q "check PASS" <<<"$ROT"; then ok "rotate-check" "the acceptance test passes on a correct rotation"
else bad "rotate-check" "--check did not report PASS: $ROT"; fi

bash "$RT" "$LB" --apply >/dev/null 2>&1
if grep -q "BL-203" "$LB" && grep -q "BL-201" "$LB" && grep -q "must never move" "$LB"; then
  ok "rotate-preserves" "open entries and the preamble survive --apply"
else
  bad "rotate-preserves" "--apply removed a live entry or the preamble"
fi
if [ -f "$WORK/backlog.archive.md" ] && grep -q "BL-202" "$WORK/backlog.archive.md"; then
  ok "rotate-archives" "the closed entry landed in the archive — moved, not deleted"
else
  bad "rotate-archives" "the closed entry is not in the archive"
fi
if grep -q "BL-202" "$LB"; then bad "rotate-removes" "the closed entry is still in the live ledger"
else ok "rotate-removes" "the closed entry left the live ledger"; fi

# THE SUBSET RELATION, PINNED. rotate's closed-set must stay a STRICT subset of reverify's, or
# the acceptance test compares two readers that share a defect. Seeded: an entry reverify calls
# closed (annotation at line start) but rotate must NOT move (version is not numeric).
LC="$WORK/c.md"
cat > "$LC" <<'EOM'
# Probe

## BL-301 — annotated at line start, non-numeric version

<br>**LANDED (vNEXT, verified abc1234).** Done.

verify: has VERSION "."
EOM
RVC="$(bash "$RV" "$LC" 2>&1)"
RTC="$(bash "$RT" "$LC" 2>&1)"
if grep -q '^ALREADY-CLOSED	BL-301' <<<"$RVC" && grep -q "nothing to move" <<<"$RTC"; then
  ok "subset" "reverify closes it, rotate refuses to move it — the predicates still differ"
else
  bad "subset" "the two predicates have converged; --check is now self-confirming"
fi

# ---------------------------------------------------------------------------------------
# Seed G — rotating the LAST entry declares the ledger empty.
# ---------------------------------------------------------------------------------------
# The rotator is the single producer of the empty marker: it appends it after the conservation
# check, only when the remainder parses to zero entries, with the text the classifier prints.
# The marker is read from `--print-marker`, never typed here.
MARK="$(bash "$RV" --print-marker 2>/dev/null)"
[ -n "$MARK" ] && ok "marker-source" "backlog-reverify.sh --print-marker yields the marker" \
  || bad "marker-source" "backlog-reverify.sh --print-marker returned nothing; no arm below can be built"
# B (above) rotated with entries remaining: no marker may have been written.
if [ -z "$MARK" ] || ! grep -qF -- "$MARK" "$LB"; then
  ok "no-marker-with-entries" "a rotation that left live entries wrote no marker"; B_nomarker=1
else
  bad "no-marker-with-entries" "a rotation that left live entries wrote the empty marker"
fi
LG="$WORK/g/backlog.md"; mkdir -p "$WORK/g"
cat > "$LG" <<'EOM'
# Probe backlog — the last entry

Preamble that must never move. Legend: verify: sh, verify: manual.

## BL-401 — closed, the last live entry

<br>**LANDED (v0.370.0, verified d4fd318).** Done.

verify: has VERSION "."
EOM
cp "$LG" "$LG.orig"
G_O="$(wc -l < "$LG.orig" | tr -d ' ')"
G_P="$(awk '/^## BL-/ { print NR - 1; exit }' "$LG.orig")"
GROT="$(bash "$RT" "$LG" --check 2>&1)"
if grep -q "check PASS" <<<"$GROT"; then ok "last-check" "--check passes when the last entry rotates"
else bad "last-check" "--check did not PASS on the last entry: $(printf '%s' "$GROT" | tail -3 | tr '\n' ' ')"; fi
bash "$RT" "$LG" --apply >/dev/null 2>&1
G_LAST="$(awk '/[^ \t]/ { l = $0 } END { print l }' "$LG")"
if [ -n "$MARK" ] && [ "$G_LAST" = "$MARK" ]; then ok "last-marker" "the marker is the last non-blank line after --apply"
else bad "last-marker" "the last non-blank line is '$G_LAST', not the marker"; fi
# CONSERVATION, BYTE-EXACT ON BOTH SIDES: the preamble is a prefix of the new ledger, the entry is
# the tail of the archive, and the ledger grew by exactly k = 2 lines (a blank and the marker).
G_L="$(wc -l < "$LG" | tr -d ' ')"
G_T1="$(tail -n $(( G_O - G_P )) "$WORK/g/backlog.archive.md")"; G_T2="$(tail -n $(( G_O - G_P )) "$LG.orig")"
if [ -z "$G_T1" ] || [ -z "$G_T2" ]; then
  echo "backlog-ledger: FIXTURE BROKEN: the last-conserves tail substitutions are empty (tail absent?), so the equality below would pass vacuously." >&2
  exit 2
fi
if [ "$G_L" -eq $(( G_P + 2 )) ] && [ "$(head -n "$G_P" "$LG")" = "$(head -n "$G_P" "$LG.orig")" ] \
   && [ "$G_T1" = "$G_T2" ]; then
  ok "last-conserves" "preamble ($G_P lines) kept as a prefix, the entry ($(( G_O - G_P )) lines) is the archive's tail, ledger = preamble + 2"
else
  bad "last-conserves" "conservation broken: ledger $G_L lines, want $(( G_P + 2 )); or a prefix/tail differs"
fi
GRV="$(bash "$RV" "$LG" 2>&1)"
if [ "$(printf '%s\n' "$GRV" | grep -c .)" -eq 1 ] && grep -qE '^DECLARED-EMPTY	' <<<"$GRV"; then
  ok "last-reverify" "the rotated ledger reads exactly one DECLARED-EMPTY row"
else bad "last-reverify" "the rotated ledger reads: $(cut -f1 <<<"$GRV" | tr '\n' ' ')"; fi
# The near-miss: the same remainder emptied BY HAND, no marker, is still unresolved.
head -n "$G_P" "$LG.orig" > "$WORK/g/hand.md"
GHV="$(bash "$RV" "$WORK/g/hand.md" 2>&1)"
if grep -qE '^INPUT-UNRESOLVED	.*ZERO entries' <<<"$GHV" && ! grep -q '^DECLARED-EMPTY' <<<"$GHV"; then
  ok "hand-emptied" "the same remainder emptied by hand reads INPUT-UNRESOLVED"
else bad "hand-emptied" "a hand-emptied ledger reads: $(cut -f1 <<<"$GHV" | tr '\n' ' ')"; fi

# TWO ROTATOR MUTANTS, in a root of their own. `scripts/backlog-reverify.sh` there is a WRAPPER
# over a real copy that adds one live row for the ledger named in DRIFT_LEDGER, and only in row
# mode: the drift --check exists to catch, which the shipped pair cannot produce (arm `subset`
# pins rotate's closed set inside reverify's). Unset, it is a passthrough.
RR="$WORK/rot-root"
mkdir -p "$RR/scripts" "$RR/core/skills/ai-dlc-update/reconcile"
printf '0.0.0\n' > "$RR/VERSION"
cp "$MROOT/core/skills/ai-dlc-update/reconcile/lib.sh" "$RR/core/skills/ai-dlc-update/reconcile/lib.sh"
cp "$RLIB" "$RR/scripts/backlog-receipt-lib.sh"
cp "$RV" "$RR/scripts/backlog-reverify.real.sh"
cat > "$RR/scripts/backlog-reverify.sh" <<'EOW'
#!/usr/bin/env bash
H="$(cd "$(dirname "$0")" && pwd)"
out="$(bash "$H/backlog-reverify.real.sh" "$@")"; rc=$?
[ -n "$out" ] && printf '%s\n' "$out"
case " $* " in *" --"*) exit "$rc" ;; esac
if [ -n "${DRIFT_LEDGER:-}" ] && [ "${1:-}" = "$DRIFT_LEDGER" ]; then
  printf 'STILL-LIVE\tBL-999\ta live row the rotation would lose, seeded by the fixture\n'
fi
exit "$rc"
EOW
RRT="$RR/scripts/backlog-rotate.sh"
mkdir -p "$WORK/h"; LH="$WORK/h/backlog.md"; cp "$LG.orig" "$LH"
# CONTROL, FIRST: the unmutated rotator in this root must FAIL --check on the drift, and the root
# must be live (its passthrough reads the last-entry seed as DECLARED-EMPTY after rotation).
cp "$RT" "$RRT"
HC="$(DRIFT_LEDGER="$LH" bash "$RRT" "$LH" --check 2>&1)"; HC_RC=$?
if [ "$HC_RC" -eq 2 ] && grep -q "check FAIL" <<<"$HC" && grep -q "BL-999" <<<"$HC"; then
  ok "drift-control" "the unmutated rotator fails --check when the original carries a live row and the remainder is DECLARED-EMPTY"; B_drift=1
else
  bad "drift-control" "the unmutated rotator exited $HC_RC on the drift seed; the mutant below would be scored against nothing"
fi
# 1. --check ACCEPTS DECLARED-EMPTY UNCONDITIONALLY: the `BEFORE is empty` conjunct removed.
DCN="$(grep -c '^  elif \[ -z "\$BEFORE" \] && \[ "\$AFTER_N" = 1 \] && \[ "\$AFTER_ST" = "DECLARED-EMPTY" \]; then$' "$RT")" || DCN=0
if [ "$DCN" -ne 1 ]; then bad "mutation-check-empty" "the --check acceptance line appears $DCN times; the mutation needs exactly one"
elif ! sed 's/^  elif \[ -z "\$BEFORE" \] && \[ "\$AFTER_N" = 1 \] && /  elif /' "$RT" > "$RRT"; then
  bad "mutation-check-empty" "DID NOT APPLY: sed failed"
elif cmp -s "$RT" "$RRT"; then bad "mutation-check-empty" "DID NOT APPLY: the mutation matched nothing"
else
  keep_mut mutation-check-empty rt "$RRT"
  HM="$(DRIFT_LEDGER="$LH" bash "$RRT" "$LH" --check 2>&1)"; HM_RC=$?
  if [ "$HM_RC" -eq 0 ] && grep -q "check PASS" <<<"$HM"; then
    mutant_killed "${B_drift:-0}" mutation-check-empty "mutation-check-empty: killed: accepting DECLARED-EMPTY whatever BEFORE holds passes a rotation that loses a live row"
  else bad "mutation-check-empty" "SURVIVED: the widened acceptance still exited $HM_RC"; fi
fi
# 2. --apply WRITES THE MARKER UNCONDITIONALLY: the zero-entry guard removed. Seed B's shape
#    (entries remain) must then end in the marker, where the shipped rotator writes none.
MKN="$(grep -c '^if \[ "\$LIVE_ENTRIES" -eq 0 \]; then$' "$RT")" || MKN=0
if [ "$MKN" -ne 1 ]; then bad "mutation-apply-marker" "the zero-entry guard appears $MKN times; the mutation needs exactly one"
elif ! sed 's/^if \[ "\$LIVE_ENTRIES" -eq 0 \]; then$/if true; then/' "$RT" > "$RRT"; then
  bad "mutation-apply-marker" "DID NOT APPLY: sed failed"
elif cmp -s "$RT" "$RRT"; then bad "mutation-apply-marker" "DID NOT APPLY: the mutation matched nothing"
else
  keep_mut mutation-apply-marker rt "$RRT"
  mkdir -p "$WORK/i"; LI="$WORK/i/backlog.md"
  printf '# Probe\n\n## BL-501 — open\n\nverify: has VERSION "."\n\n## BL-502 — closed\n\n<br>**LANDED (v0.370.0, verified d4fd318).** Done.\n\nverify: has VERSION "."\n' > "$LI"
  bash "$RRT" "$LI" --apply >/dev/null 2>&1
  if grep -q '^## BL-501' "$LI" && [ -n "$MARK" ] && grep -qF -- "$MARK" "$LI"; then
    mutant_killed "${B_nomarker:-0}" mutation-apply-marker "mutation-apply-marker: killed: with the guard removed a rotation that leaves BL-501 live writes the empty marker"
  else bad "mutation-apply-marker" "SURVIVED: the unguarded rotator left no marker (or lost BL-501)"; fi
fi

# 3. THE ROTATOR ASKS --marker-last BEFORE APPENDING, so a presence-keyed position rule in the
#    classifier makes it skip the marker whenever the preamble QUOTES it. Seed: the last entry,
#    below a preamble that quotes the marker on its own line followed by more prose. Control: the
#    unmutated pair appends it. Mutant: the classifier's marker_last swapped for a whole-file grep.
mkdir -p "$WORK/q"; LQ="$WORK/q/backlog.md"
{ printf '# Probe backlog — the marker quoted\n\nThe rotator writes this line when the ledger empties:\n\n%s\n\nIt is a declaration, not prose.\n\n' "$MARK"
  printf '## BL-601 — closed, the last live entry\n\n<br>**LANDED (v0.370.0, verified d4fd318).** Done.\n\nverify: has VERSION "."\n'; } > "$LQ"
cp "$LQ" "$LQ.orig"
cp "$RT" "$RRT"
bash "$RRT" "$LQ" --apply >/dev/null 2>&1
Q_LAST="$(awk '/[^ \t]/ { l = $0 } END { print l }' "$LQ")"
if [ -n "$MARK" ] && [ "$Q_LAST" = "$MARK" ]; then
  ok "quoted-marker" "a preamble quoting the marker still gets it appended as the last line"; B_quoted=1
else bad "quoted-marker" "with the marker quoted in the preamble the last line is '$Q_LAST'"; fi
MPN="$(grep -cF 'END { exit (last == m) ? 0 : 1 }' "$RV")" || MPN=0
if [ "$MPN" -ne 1 ]; then bad "mutation-marker-presence" "the position rule's line appears $MPN times; the mutation needs exactly one"
elif ! sed 's@^  awk -v m="\$EMPTY_MARKER" .*END { exit (last == m) ? 0 : 1 }.*$@  grep -qF -- "$EMPTY_MARKER" "$1"@' "$RV" > "$RR/scripts/backlog-reverify.real.sh"; then
  bad "mutation-marker-presence" "DID NOT APPLY: sed failed"
elif cmp -s "$RV" "$RR/scripts/backlog-reverify.real.sh"; then bad "mutation-marker-presence" "DID NOT APPLY: the mutation matched nothing"
else
  keep_mut mutation-marker-presence rv "$RR/scripts/backlog-reverify.real.sh"
  cp "$LQ.orig" "$LQ"
  bash "$RRT" "$LQ" --apply >/dev/null 2>&1
  Q_LAST="$(awk '/[^ \t]/ { l = $0 } END { print l }' "$LQ")"
  if grep -q '^## BL-601' "$LQ"; then
    bad "mutation-marker-presence" "the entry was not rotated under the mutant — the root broke, not the rule"
  elif [ "$Q_LAST" != "$MARK" ]; then
    mutant_killed "${B_quoted:-0}" mutation-marker-presence "mutation-marker-presence: killed: a presence-keyed position rule leaves a zero-entry ledger without its trailing marker"
  else bad "mutation-marker-presence" "SURVIVED: the presence-keyed rule still appended the marker"; fi
fi
cp "$RV" "$RR/scripts/backlog-reverify.real.sh"

# ---------------------------------------------------------------------------------------
# Seed J — a LIVE entry the parser cannot see, below the last entry it can.
# ---------------------------------------------------------------------------------------
# Each spelling below is not an entry boundary to lib.sh, so the split absorbs it into the closed
# BL-500 above it, BEFORE reads no live row, and the DECLARED-EMPTY acceptance would archive it.
# The rotator's id census must refuse: --check exits 2, and --apply writes neither file.
mkdir -p "$WORK/j"
j_seed() { # j_seed <file> <live-heading-line>
  { printf '# Carry-over backlog\n\nOpen work only. Each entry ends in a receipt line.\n\n## Receipts\n\n'
    printf 'verify: sh <one-liner> -- exit 0 means fixed. verify: manual -- a human closes it.\n\n'
    printf '## BL-500 — closed, the last entry the parser sees\n\n<br>**LANDED (v0.370.0, verified d4fd318).** Done.\n\nverify: has VERSION "."\n\n'
    printf '%s — live, spelled so the boundary rule cannot see it\n\nverify: manual\n' "$2"; } > "$1"
}
J_SPELL_1='## `BL-501`'; J_SPELL_2='# BL-501'; J_SPELL_3=' ## BL-501'; J_SPELL_4='-**BL-501**'
for j_i in 1 2 3 4; do
  eval "j_sp=\"\$J_SPELL_$j_i\""
  LJ="$WORK/j/backlog-$j_i.md"; j_seed "$LJ" "$j_sp"; cp "$LJ" "$LJ.orig"
  JC="$(bash "$RT" "$LJ" --check 2>&1)"; JC_RC=$?
  bash "$RT" "$LJ" --apply --archive "$WORK/j/archive-$j_i.md" >/dev/null 2>&1; JA_RC=$?
  if [ "$JC_RC" -eq 2 ] && grep -q "entry-like id lines" <<<"$JC" && grep -qF "BL-501" <<<"$JC" \
     && [ "$JA_RC" -eq 2 ] && cmp -s "$LJ" "$LJ.orig" && [ ! -e "$WORK/j/archive-$j_i.md" ]; then
    ok "census-$j_i" "'$j_sp' below the last parseable entry: --check exits 2 naming it, --apply writes nothing"
    case "$j_i" in 1) B_census_1=1 ;; esac
  else
    bad "census-$j_i" "'$j_sp': --check rc=$JC_RC, --apply rc=$JA_RC, ledger $(cmp -s "$LJ" "$LJ.orig" && echo unchanged || echo CHANGED), archive $([ -e "$WORK/j/archive-$j_i.md" ] && echo WRITTEN || echo absent)"
  fi
done
# CONTROL: the census does not fire on a plain last-entry rotation (seed G's shape, re-run).
mkdir -p "$WORK/jc"; cp "$LG.orig" "$WORK/jc/backlog.md"
# Captured first and read from a here-string: `grep -q` fed by a pipe answers with the writer's
# EPIPE under pipefail and reads NOT-FOUND on output that contains the pattern.
JCC="$(bash "$RT" "$WORK/jc/backlog.md" --check 2>&1)"
if grep -q "check PASS" <<<"$JCC"; then
  ok "census-control" "a plain last-entry rotation still passes --check with the census in place"; B_census_ctl=1
else bad "census-control" "the census fires on a plain last-entry rotation"; fi
# MUTANT: the census removed. The backticked spelling must then pass --check (the sweep).
CSN="$(grep -c '^  if \[ "\$CENSUS_N" -gt "\$MOVED_COUNT" \]; then$' "$RT")" || CSN=0
if [ "$CSN" -ne 1 ]; then bad "mutation-no-census" "the census line appears $CSN times; the mutation needs exactly one"
elif ! sed 's/^  if \[ "\$CENSUS_N" -gt "\$MOVED_COUNT" \]; then$/  if false; then/' "$RT" > "$RRT"; then
  bad "mutation-no-census" "DID NOT APPLY: sed failed"
elif cmp -s "$RT" "$RRT"; then bad "mutation-no-census" "DID NOT APPLY: the mutation matched nothing"
else
  keep_mut mutation-no-census rt "$RRT"
  LJ="$WORK/j/backlog-1.md"
  JM="$(bash "$RRT" "$LJ" --check 2>&1)"; JM_RC=$?
  if [ "$JM_RC" -eq 0 ] && grep -q "check PASS" <<<"$JM"; then
    mutant_killed "$(( ${B_census_1:-0} && ${B_census_ctl:-0} ))" mutation-no-census "mutation-no-census: killed: without the census a backticked live heading passes --check and would be archived"
  else bad "mutation-no-census" "SURVIVED: with the census removed --check still exited $JM_RC"; fi
fi

# --apply WITHOUT --check must not write an invalid declaration: a preamble mentioning BL-1 leaves
# a zero-entry remainder the classifier will not call declared, so --apply refuses before writing.
mkdir -p "$WORK/k"; LK="$WORK/k/backlog.md"
{ printf '# Probe backlog\n\nHistory: BL-1 was the first entry ever filed.\n\n'
  printf '## BL-700 — closed, the last entry\n\n<br>**LANDED (v0.370.0, verified d4fd318).** Done.\n\nverify: has VERSION "."\n'; } > "$LK"
cp "$LK" "$LK.orig"
KA="$(bash "$RT" "$LK" --apply 2>&1)"; KA_RC=$?
if [ "$KA_RC" -eq 2 ] && grep -q "declared-empty answers" <<<"$KA" && cmp -s "$LK" "$LK.orig" && [ ! -e "$WORK/k/backlog.archive.md" ]; then
  ok "apply-declares-valid" "--apply refuses a zero-entry remainder whose preamble carries a BL- id, and writes nothing"; B_declvalid=1
else bad "apply-declares-valid" "--apply exited $KA_RC on a remainder that cannot be declared; ledger $(cmp -s "$LK" "$LK.orig" && echo unchanged || echo CHANGED)"; fi
DVN="$(grep -c '^  if \[ "\$DE" -ne 0 \]; then$' "$RT")" || DVN=0
if [ "$DVN" -ne 1 ]; then bad "mutation-apply-unvalidated" "the --apply validation line appears $DVN times; the mutation needs exactly one"
elif ! sed 's/^  if \[ "\$DE" -ne 0 \]; then$/  if false; then/' "$RT" > "$RRT"; then
  bad "mutation-apply-unvalidated" "DID NOT APPLY: sed failed"
elif cmp -s "$RT" "$RRT"; then bad "mutation-apply-unvalidated" "DID NOT APPLY: the mutation matched nothing"
else
  keep_mut mutation-apply-unvalidated rt "$RRT"
  cp "$LK.orig" "$LK"
  bash "$RRT" "$LK" --apply >/dev/null 2>&1; KM_RC=$?
  if [ "$KM_RC" -eq 0 ] && ! cmp -s "$LK" "$LK.orig"; then
    mutant_killed "${B_declvalid:-0}" mutation-apply-unvalidated "mutation-apply-unvalidated: killed: without the check --apply writes a declaration the classifier refuses"
  else bad "mutation-apply-unvalidated" "SURVIVED: the unvalidated --apply exited $KM_RC and left the ledger unchanged"; fi
fi

# SHA READ ANCHORED ON THE ANNOTATION FORM. The ledger must live in a GIT repo, or the rotator's sha arm
# SKIPS and nothing below can fire. Seeds: A = LANDED line whose LATER prose says "was verified against"
# (the greedy read took `a`); B = near-miss, no later "verified" (reads the same as before); C = the
# form without its <br> prefix.
mkdir -p "$WORK/s"; GS="$WORK/s/repo"; mkdir -p "$GS"
git -C "$GS" init -q . && git -C "$GS" -c user.email=f@x -c user.name=f commit -q --allow-empty -m seed
GSHA="$(git -C "$GS" rev-parse --short=9 HEAD)"
LS="$GS/backlog.md"
{ printf '# Probe\n\n## BL-801 — prose after\n\nbody\n\n<br>**LANDED (v0.370.0, verified %s).** Done; it was verified against the shipping join.\n\nverify: manual\n\n' "$GSHA"
  printf '## BL-802 — near miss\n\nbody\n\n<br>**LANDED (v0.370.0, verified %s).** Done.\n\nverify: manual\n\n' "$GSHA"
  printf '## BL-803 — prose before\n\nbody\n\n**LANDED (v0.370.0, verified %s).** Done.\n\nverify: manual\n\n' "$GSHA"
  printf '## BL-805 — dot inside the parens\n\nbody\n\n<br>**LANDED (v0.607.0, verified %s.)**\n\nverify: manual\n\n' "$GSHA"
  printf '## BL-804 — live\n\nbody\n\nverify: manual\n'; } > "$LS"
SA="$(bash "$RT" "$LS" --check 2>&1)"
n_res="$(grep -c "\[sha $GSHA resolves\]" <<<"$SA")" || n_res=0
if [ "$n_res" -eq 4 ] &&! grep -q "DOES NOT RESOLVE" <<<"$SA"; then
  ok "sha-anchored" "all four LANDED lines resolve their OWN sha, including the one whose later prose says \"verified against\" and the archive form ending \"<sha>.)**\""; B_sha=1
else bad "sha-anchored" "$n_res of 4 LANDED lines resolved $GSHA; output: $(grep -E 'sha ' <<<"$SA" | tr '\n' '|')"; fi
# MUTANT: the greedy read restored.
SHN="$(grep -cF 'verified \([0-9a-f]\{7,\}\)[^0-9a-f].*/\2/p' "$RT")" || SHN=0
if [ "$SHN" -ne 1 ]; then bad "mutation-sha-greedy" "the anchored sha read appears $SHN times; the mutation needs exactly one"
else
  # ENVIRON carries both strings, because awk -v would strip one level of backslash escaping.
  MUT_NEEDLE='verified \([0-9a-f]\{7,\}\)[^0-9a-f].*/\2/p' \
  MUT_LINE='  SHA="$(printf '"'"'%s\n'"'"' "$ANN" | sed -n '"'"'s/.*verified \([0-9a-f][0-9a-f]*\).*/\1/p'"'"')"' \
    awk 'index($0, ENVIRON["MUT_NEEDLE"]) { print ENVIRON["MUT_LINE"]; next } { print }' "$RT" > "$RRT"
  if cmp -s "$RT" "$RRT"; then bad "mutation-sha-greedy" "DID NOT APPLY: the mutation matched nothing"
  elif ! grep -qF 's/.*verified \([0-9a-f][0-9a-f]*\).*/\1/p' "$RRT"; then bad "mutation-sha-greedy" "DID NOT APPLY: the greedy read is absent from the mutant"
  else
    keep_mut mutation-sha-greedy rt "$RRT"
    SM="$(bash "$RRT" "$LS" --check 2>&1)"
    if grep -q "sha a DOES NOT RESOLVE" <<<"$SM"; then
      mutant_killed "${B_sha:-0}" mutation-sha-greedy "mutation-sha-greedy: killed: the greedy read takes \`a\` from the later prose and refuses a correct entry"
    else bad "mutation-sha-greedy" "SURVIVED: the greedy read still resolved every sha"; fi
  fi
fi

# ---------------------------------------------------------------------------------------
# Seed P — a PROSE LEAD-IN BULLET inside an entry body is not an entry (BL-820).
# `- **BL-632 is LANDED** prose` sits inside BL-150, BEFORE BL-150's receipt. A loose label
# rule opens a phantom BL-632 there, the phantom takes the receipt, and BL-150 reads
# NEEDS-REVIEW "carries no 'verify:'". BL-151 is the legitimate list form, `- **BL-151** — t`,
# which must keep parsing: a rule that stopped labelling bullets at all would pass the phantom
# arm and lose it. Two mutants of the label rule in reconcile/lib.sh, each in its own root with
# the unmutated engine copied beside it, and each guarded by `cmp -s`.
# ---------------------------------------------------------------------------------------
LP="$WORK/p.md"
printf '# Probe ledger\n\n## BL-150 — host\n\nBody.\n\n- **BL-632 is LANDED** prose about another entry\n\nverify: sh true\n\n- **BL-151** — a list entry\n\nverify: sh true\n' > "$LP"
p_ok() { # p_ok <output> — 0 when the host keeps its receipt, the list entry parses, and no phantom row exists
  grep -qE '^CLOSE-CANDIDATE	BL-150	' <<<"$1" || { echo "BL-150 lost its receipt: $(grep -E '	BL-150	' <<<"$1" | cut -f1,3 | cut -c1-80)"; return 1; }
  grep -qE '^CLOSE-CANDIDATE	BL-151	' <<<"$1" || { echo "the list entry BL-151 has no CLOSE-CANDIDATE row"; return 1; }
  ! grep -qE '	BL-632	' <<<"$1" || { echo "a phantom BL-632 row exists"; return 1; }
  [ "$(grep -c '	' <<<"$1")" -eq 2 ] || { echo "$(grep -c '	' <<<"$1") rows, want 2"; return 1; }
  return 0
}
PO="$(bash "$RV" "$LP" 2>&1)"
if pm="$(p_ok "$PO")"; then ok "phantom-bullet" "a '- **BL-632 is LANDED**' lead-in inside BL-150 opens no entry; BL-150 keeps its receipt and the list entry BL-151 parses (2 rows)"; B_phantom=1
else bad "phantom-bullet" "$pm"; fi
LIBP="$MROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
LN="$(grep -c 'if (line !~ /^BL-' "$LIBP")" || LN=0
LZ="$(grep -c 'ZQ-NEVER-IN-LIB-QZ' "$LIBP")" || LZ=0
if [ "$LN" -eq 1 ] && [ "$LZ" -eq 0 ]; then ok "label-anchor" "the strict bullet test is unique in lib.sh (control: an impossible token reads 0)"
else bad "label-anchor" "the strict bullet test appears $LN times (control $LZ); the mutations below need exactly one"; fi
p_mut() { # p_mut <name> <sed-expr> -> echoes the mutated engine path, empty when the sed did not apply
  local r="$WORK/$1"
  mkdir -p "$r/scripts" "$r/core/skills/ai-dlc-update/reconcile"
  printf '0.0.0\n' > "$r/VERSION"
  cp "$RV" "$r/scripts/backlog-reverify.sh"
  cp "$RLIB" "$r/scripts/backlog-receipt-lib.sh"
  sed "$2" "$LIBP" > "$r/core/skills/ai-dlc-update/reconcile/lib.sh" || return 1
  cmp -s "$LIBP" "$r/core/skills/ai-dlc-update/reconcile/lib.sh" && return 1
  printf '%s' "$r/scripts/backlog-reverify.sh"
}
# m-loose: the strict test deleted, so the label rule is the loose one the defect shipped with.
PM="$(p_mut mut-loose '/if (line !~ \/^BL-/d')"
if [ -z "$PM" ]; then bad "mutation-loose" "DID NOT APPLY: the strict bullet test was not found"
else
  keep_mut mutation-loose lib "$(dirname "$(dirname "$PM")")/core/skills/ai-dlc-update/reconcile/lib.sh"
  MO="$(bash "$PM" "$LP" 2>&1)"
  if grep -qE '^CLOSE-CANDIDATE	BL-151	' <<<"$MO" && grep -qE '	BL-632	' <<<"$MO" \
     && grep -qE '^NEEDS-REVIEW	BL-150	' <<<"$MO"; then
    mutant_killed "${B_phantom:-0}" mutation-loose "mutation-loose: killed: the loose rule opens a phantom BL-632 that takes BL-150's receipt (BL-150 NEEDS-REVIEW), while BL-151 still parses"
  else bad "mutation-loose" "SURVIVED: $(cut -f1,2 <<<"$MO" | tr '\n' ' ')"; fi
fi
# m-heading-only: bullets never take a label, so the list entry vanishes.
PM="$(p_mut mut-heading-only 's/if (line !~ /if (1 || line !~ /')"
if [ -z "$PM" ]; then bad "mutation-heading-only" "DID NOT APPLY: the strict bullet test was not found"
else
  keep_mut mutation-heading-only lib "$(dirname "$(dirname "$PM")")/core/skills/ai-dlc-update/reconcile/lib.sh"
  MO="$(bash "$PM" "$LP" 2>&1)"
  if grep -qE '^CLOSE-CANDIDATE	BL-150	' <<<"$MO" && ! grep -qE '	BL-151	' <<<"$MO"; then
    mutant_killed "${B_phantom:-0}" mutation-heading-only "mutation-heading-only: killed: with bullets never labelled the list entry BL-151 has no row, while BL-150 still parses"
  else bad "mutation-heading-only" "SURVIVED: $(cut -f1,2 <<<"$MO" | tr '\n' ' ')"; fi
fi

# =======================================================================================
# ARMS, TWINS AND THE MATRIX. An arm = a seeded world + a predicate, run against a root built from the
# REAL components with at most one substituted by a kept mutant copy. Every arm returns 0 when it is
# GREEN (the behaviour holds) and non-zero when it TRIPS. Each arm owns a fresh directory per cell.
# =======================================================================================
AX="$WORK/ax"; mkdir -p "$AX"
AXN=0
mk_root() { # mk_root <mutant id or -> -> prints the root dir; components default to the real ones
  local id="$1" r f
  r="$(mktemp -d "$AX/r.XXXXXX")"
  mkdir -p "$r/scripts" "$r/core/skills/ai-dlc-update/reconcile"
  printf '0.0.0\n' > "$r/VERSION"
  cp "$RV" "$r/scripts/backlog-reverify.real.sh"
  cp "$RT" "$r/scripts/backlog-rotate.sh"
  cp "$RLIB" "$r/scripts/backlog-receipt-lib.sh"
  cp "$MROOT/core/skills/ai-dlc-update/reconcile/lib.sh" "$r/core/skills/ai-dlc-update/reconcile/lib.sh"
  if [ "$id" != "-" ]; then
    [ -f "$KM/$id.rv" ]   && cp "$KM/$id.rv"   "$r/scripts/backlog-reverify.real.sh"
    [ -f "$KM/$id.rt" ]   && cp "$KM/$id.rt"   "$r/scripts/backlog-rotate.sh"
    [ -f "$KM/$id.rlib" ] && cp "$KM/$id.rlib" "$r/scripts/backlog-receipt-lib.sh"
    [ -f "$KM/$id.lib" ]  && cp "$KM/$id.lib"  "$r/core/skills/ai-dlc-update/reconcile/lib.sh"
  fi
  cat > "$r/scripts/backlog-reverify.sh" <<'EOW'
#!/usr/bin/env bash
H="$(cd "$(dirname "$0")" && pwd)"
out="$(bash "$H/backlog-reverify.real.sh" "$@")"; rc=$?
[ -n "$out" ] && printf '%s\n' "$out"
case " $* " in *" --"*) exit "$rc" ;; esac
if [ -n "${DRIFT_LEDGER:-}" ] && [ "${1:-}" = "$DRIFT_LEDGER" ]; then
  printf 'STILL-LIVE\tBL-999\ta live row the rotation would lose, seeded by the fixture\n'
fi
exit "$rc"
EOW
  printf '%s' "$r"
}
last_nonblank() { awk '/[^ \t]/ { l = $0 } END { print l }' "$1"; }
arm_parse() { local r o; r="$(mk_root "$1")"; o="$(bash "$r/scripts/backlog-reverify.real.sh" "$LA" 2>&1)"
  grep -q "MALFORMED sh receipt" <<<"$(grep -E '	BL-113	' <<<"$o")" \
    && grep -qE '^NEEDS-REVIEW	BL-115	' <<<"$o" && grep -qE '^NEEDS-REVIEW	BL-116	' <<<"$o" \
    && grep -qE '^CLOSE-CANDIDATE	BL-114	' <<<"$o"; }
arm_route()   { local r; r="$(mk_root "$1")"; route_ok "$(bash "$r/scripts/backlog-reverify.real.sh" "$LC_ROUTE" 2>&1)" >/dev/null; }
arm_stdin()   { local r; r="$(mk_root "$1")"; stdin_ok "$(bash "$r/scripts/backlog-reverify.real.sh" "$LD" 2>&1)" >/dev/null; }
arm_memo()    { local r; r="$(mk_root "$1")"; leak_both "$r/scripts/backlog-reverify.real.sh" >/dev/null; }
arm_cm()      { local r; r="$(mk_root "$1")"; cm_ok "$(bash "$r/scripts/backlog-reverify.real.sh" "$LF" 2>&1)" >/dev/null; }
arm_phantom() { local r; r="$(mk_root "$1")"; p_ok "$(bash "$r/scripts/backlog-reverify.real.sh" "$LP" 2>&1)" >/dev/null; }
arm_checkempty() { local r d o rcv; r="$(mk_root "$1")"; d="$(mktemp -d "$AX/ce.XXXXXX")"; cp "$LG.orig" "$d/backlog.md"
  o="$(DRIFT_LEDGER="$d/backlog.md" bash "$r/scripts/backlog-rotate.sh" "$d/backlog.md" --check 2>&1)"; rcv=$?
  [ "$rcv" -eq 2 ] && grep -q "check FAIL" <<<"$o" && grep -q "BL-999" <<<"$o"; }
arm_applymarker() { local r d; r="$(mk_root "$1")"; d="$(mktemp -d "$AX/am.XXXXXX")"
  printf '# Probe\n\n## BL-501 — open\n\nverify: has VERSION "."\n\n## BL-502 — closed\n\n<br>**LANDED (v0.370.0, verified d4fd318).** Done.\n\nverify: has VERSION "."\n' > "$d/backlog.md"
  bash "$r/scripts/backlog-rotate.sh" "$d/backlog.md" --apply >/dev/null 2>&1
  grep -q '^## BL-501' "$d/backlog.md" && ! grep -qF -- "$MARK" "$d/backlog.md"; }
arm_quoted() { local r d; r="$(mk_root "$1")"; d="$(mktemp -d "$AX/qu.XXXXXX")"; cp "$LQ.orig" "$d/backlog.md"
  bash "$r/scripts/backlog-rotate.sh" "$d/backlog.md" --apply >/dev/null 2>&1
  [ "$(last_nonblank "$d/backlog.md")" = "$MARK" ] && ! grep -q '^## BL-601' "$d/backlog.md"; }
arm_census() { local r d o rcv; r="$(mk_root "$1")"; d="$(mktemp -d "$AX/ce2.XXXXXX")"; cp "$WORK/j/backlog-1.md.orig" "$d/backlog.md"
  o="$(bash "$r/scripts/backlog-rotate.sh" "$d/backlog.md" --check 2>&1)"; rcv=$?
  [ "$rcv" -eq 2 ] && grep -q "entry-like id lines" <<<"$o"; }
arm_declvalid() { local r d rcv; r="$(mk_root "$1")"; d="$(mktemp -d "$AX/dv.XXXXXX")"; cp "$LK.orig" "$d/backlog.md"
  bash "$r/scripts/backlog-rotate.sh" "$d/backlog.md" --apply >/dev/null 2>&1; rcv=$?
  [ "$rcv" -eq 2 ] && cmp -s "$d/backlog.md" "$LK.orig" && [ ! -e "$d/backlog.archive.md" ]; }
arm_sha() { local r o n; r="$(mk_root "$1")"; o="$(bash "$r/scripts/backlog-rotate.sh" "$LS" --check 2>&1)"
  n="$(grep -c "\[sha $GSHA resolves\]" <<<"$o")" || n=0
  [ "$n" -eq 4 ] && ! grep -q "DOES NOT RESOLVE" <<<"$o"; }
ARMS="parse route stdin memo cm phantom checkempty applymarker quoted census declvalid sha"
arm_run() { "arm_$1" "$2"; }   # arm_run <arm> <mutant id or -> -> 0 green, non-zero tripped
twin_of() {
  case "$1" in
    mutation-no-parse) echo route ;;
    mutation-parse-bare) echo route ;;
    mutation-9-close) echo stdin ;;
    mutation-9-hand) echo stdin ;;
    mutation-stdin) echo route ;;
    mutation-memo-export) echo stdin ;;
    mutation-memo-diffonly) echo stdin ;;
    mutation-memo-fns) echo stdin ;;
    mutation-stderr-route) echo stdin ;;
    mutation-no-prefix) echo route ;;
    mutation-check-empty) echo sha ;;
    mutation-apply-marker) echo sha ;;
    mutation-marker-presence) echo sha ;;
    mutation-no-census) echo sha ;;
    mutation-apply-unvalidated) echo sha ;;
    mutation-sha-greedy) echo census ;;
    mutation-loose) echo parse ;;
    mutation-heading-only) echo route ;;
  esac
}
decider_of() {
  case "$1" in
    mutation-no-parse) echo parse ;;
    mutation-parse-bare) echo parse ;;
    mutation-9-close) echo route ;;
    mutation-9-hand) echo route ;;
    mutation-stdin) echo stdin ;;
    mutation-memo-export) echo memo ;;
    mutation-memo-diffonly) echo memo ;;
    mutation-memo-fns) echo memo ;;
    mutation-stderr-route) echo cm ;;
    mutation-no-prefix) echo cm ;;
    mutation-check-empty) echo checkempty ;;
    mutation-apply-marker) echo applymarker ;;
    mutation-marker-presence) echo quoted ;;
    mutation-no-census) echo census ;;
    mutation-apply-unvalidated) echo declvalid ;;
    mutation-sha-greedy) echo sha ;;
    mutation-loose) echo phantom ;;
    mutation-heading-only) echo phantom ;;
  esac
}
# The unmutated control: every arm is GREEN on the real components. A harness that tripped here would
# make every kill below the harness failing and not the mutation.
ctl_bad=""
for a in $ARMS; do arm_run "$a" - || ctl_bad="$ctl_bad $a"; done
if [ -z "$ctl_bad" ]; then ok "mutant-control" "the UNMUTATED copy of every component is green on all 12 arms, so the roots below run the shipped behaviour"; B_matrix_ctl=1
else bad "mutant-control" "the unmutated roots trip these arms:$ctl_bad -- every twin and matrix verdict below is void"; fi
# PER PUSH: each mutant's deciding arm TRIPS and its twin stays GREEN.
for m in $KM_IDS; do
  da="$(decider_of "$m")"; tw="$(twin_of "$m")"
  if arm_run "$da" "$m"; then bad "[$da] $m" "the deciding arm stayed GREEN on the mutant: it does not decide it"
  else ok "[$da] $m" "deciding arm trips on the mutant's component copy"; fi
  if arm_run "$tw" "$m"; then ok "[$tw] $m" "twin stays green: the effect of $m is confined to $da"
  else bad "[$tw] $m" "the twin TRIPPED on $m, so the kill is not confined to its deciding arm"; fi
done
if [ "$MATRIX" = 1 ]; then
  for m in $KM_IDS; do
    for a in $ARMS; do
      if arm_run "$a" "$m"; then matrix_row "$m" "$a" 0 GREEN no; else matrix_row "$m" "$a" 1 TRIPPED yes; fi
      MROWS=$((MROWS + 1))
    done
  done
  n_km="$(printf '%s\n' $KM_IDS | grep -c .)"
  if [ "$n_km" -eq 18 ] && [ "$MROWS" -eq 216 ]; then ok "[MX]" "the matrix run measured $MROWS cells for $n_km mutants"; else bad "[MX]" "matrix rows=$MROWS for $n_km mutants, 216 for 18 expected"; fi
else
  if [ "$MROWS" -eq 0 ]; then ok "[MX]" "a plain run executed no matrix-only cell (rows=0)"; else bad "[MX]" "a plain run executed $MROWS matrix rows"; fi
fi

echo
if [ "$FAIL" -eq 0 ]; then
  echo "PASS: every assertion holds."
  exit 0
fi
echo "FAIL: an assertion regressed." >&2
exit 1
