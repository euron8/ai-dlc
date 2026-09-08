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
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
RV="$(pick "$HERE/../../../scripts/backlog-reverify.sh" "$HERE/../../scripts/backlog-reverify.sh")"
RT="$(pick "$HERE/../../../scripts/backlog-rotate.sh"   "$HERE/../../scripts/backlog-rotate.sh")"
# A MISSING SUBJECT IS NOT A PASS. Every assertion reads a tool's output, so a run that cannot
# invoke one produces empty output and would score green on anything phrased as an absence.
[ -n "$RV" ] || { echo "FIXTURE ERROR: cannot locate scripts/backlog-reverify.sh" >&2; exit 2; }
[ -n "$RT" ] || { echo "FIXTURE ERROR: cannot locate scripts/backlog-rotate.sh" >&2; exit 2; }

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

FAIL=0
echo "backlog-ledger fixture"
echo

ok()   { printf '  ok    %-18s %s\n' "$1" "$2"; }
bad()  { printf '  FAIL  %-18s %s\n' "$1" "$2"; FAIL=1; }
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
  ok "malformed-named" "the two-line receipt's refusal names it MALFORMED"
else
  bad "malformed-named" "BL-113's detail does not say MALFORMED: $(cut -c1-120 <<<"$BL113_ROW")"
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
MUT="$MROOT/scripts/backlog-reverify.sh"
# The guard line is the anchor for both; assert it is unique so a sed cannot edit a second copy.
GN="$(grep -c '^ *if ! bash -n -c "\$SH_PROG" >/dev/null 2>&1; then$' "$RV")" || GN=0
if [ "$GN" -eq 1 ]; then ok "parse-anchor" "the parse guard line is unique in the engine"
else bad "parse-anchor" "the parse guard line appears $GN times; the mutations below need exactly one"; fi
# 1. THE GUARD DISARMED. BL-113 regresses to STILL-LIVE (the filed silent mis-score) and BL-115
#    to CLOSE-CANDIDATE (the false close); BL-114 stays CLOSE-CANDIDATE, the control.
sed 's/^\( *\)if ! bash -n -c "\$SH_PROG" >\/dev\/null 2>&1; then$/\1if false; then/' "$RV" > "$MUT"
if cmp -s "$RV" "$MUT"; then
  bad "mutation-no-parse" "the mutation matched nothing, so the parse guard is unproven"
else
  MOUT="$(bash "$MUT" "$LA" 2>&1)"
  if ! grep -qE '^CLOSE-CANDIDATE	BL-114	' <<<"$MOUT"; then
    bad "mutation-no-parse" "the control row (BL-114 CLOSE-CANDIDATE) is gone — the mutant broke the engine, not the guard"
  elif grep -qE '^STILL-LIVE	BL-113	' <<<"$MOUT" && grep -qE '^CLOSE-CANDIDATE	BL-115	' <<<"$MOUT"; then
    ok "mutation-no-parse" "with the guard disarmed the cut-quote receipt reads STILL-LIVE and the backslash one CLOSES — the guard is load-bearing in both directions"
  else
    bad "mutation-no-parse" "guard disarmed and the seeds did not regress: $(grep -E '	BL-11[35]	' <<<"$MOUT" | cut -f1,2 | tr '\n' ' ')"
  fi
fi
# 2. THE BARE RECEIPT PARSED instead of the brace-wrapped copy — the first cut. BL-115's fragment
#    parses clean and exits 0, so it CLOSES; BL-113 is still refused, the control.
sed 's/^\( *\)if ! bash -n -c "\$SH_PROG" >\/dev\/null 2>&1; then$/\1if ! bash -n -c "$REST" >\/dev\/null 2>\&1; then/' "$RV" > "$MUT"
if cmp -s "$RV" "$MUT"; then
  bad "mutation-parse-bare" "the mutation matched nothing, so the brace wrap is unproven"
else
  MOUT="$(bash "$MUT" "$LA" 2>&1)"
  if ! grep -qE '^NEEDS-REVIEW	BL-113	' <<<"$MOUT"; then
    bad "mutation-parse-bare" "the control row (BL-113 NEEDS-REVIEW) is gone — the mutant broke the engine, not the wrap"
  elif grep -qE '^CLOSE-CANDIDATE	BL-115	' <<<"$MOUT" && grep -qE '^STILL-LIVE	BL-116	' <<<"$MOUT"; then
    ok "mutation-parse-bare" "parsing the bare receipt acquits the backslash fragment (CLOSES) and the heredoc opener (STILL-LIVE) — the brace wrap is what catches them"
  else
    bad "mutation-parse-bare" "bare parse and the seeds did not regress: $(grep -E '	BL-11[56]	' <<<"$MOUT" | cut -f1,2 | tr '\n' ' ')"
  fi
fi

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

echo
if [ "$FAIL" -eq 0 ]; then
  echo "PASS: every assertion holds."
  exit 0
fi
echo "FAIL: an assertion regressed." >&2
exit 1
