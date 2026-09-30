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
  MOUT="$(bash "$MUT" "$LA" 2>&1)"
  if ! grep -qE '^CLOSE-CANDIDATE	BL-114	' <<<"$MOUT"; then
    bad "mutation-no-parse" "the control row (BL-114 CLOSE-CANDIDATE) is gone — the mutant broke the engine, not the guard"
  elif M113="$(grep -E '	BL-113	' <<<"$MOUT")" && ! grep -q "MALFORMED sh receipt" <<<"$M113" \
       && grep -qE '^CLOSE-CANDIDATE	BL-115	' <<<"$MOUT"; then
    ok "mutation-no-parse" "with the guard disarmed the cut-quote receipt loses its MALFORMED diagnosis and the backslash one CLOSES — the guard is load-bearing in both directions"
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
LC="$WORK/c.md"
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

COUT="$(bash "$RV" "$LC" 2>&1)"
if why="$(route_ok "$COUT")"; then
  ok "exit-9-routing" "exit 9 reads NEEDS-REVIEW unresolved:, beside 0 CLOSE-CANDIDATE and 1/126/bare-127 STILL-LIVE"
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
  ok "exit-9-control" "the unmutated copy in the mutant root routes seed C correctly (baseline BL-122 STILL-LIVE present)"
else
  bad "exit-9-control" "the unmutated copy fails seed C, so the mutant root is broken and the verdicts below are void: $why"
fi
# Each mutant must fail route_ok while its baseline row (BL-122 STILL-LIVE) is still there —
# that row proves the copy RAN, so the failure is the mutation and not a dead engine.
score_route_mut() { # <arm> <description-of-regression>
  local mo why
  mo="$(bash "$MUT" "$LC" 2>&1)"
  if ! grep -qE '^STILL-LIVE	BL-122	' <<<"$mo"; then
    bad "$1" "the baseline row (BL-122 STILL-LIVE) is gone — the mutant broke the engine, not the routing"
  elif why="$(route_ok "$mo")"; then
    bad "$1" "SURVIVED: with $2 the arm still passes"
  else
    ok "$1" "killed: $2 — $why"
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
  score_route_mut "mutation-9-close" "exit 9 routed to CLOSE-CANDIDATE"
fi
# 2. 9 ROUTED TO HAND-REVIEW — the false close backlog-rotate.sh accepts. The detail is kept, so
#    only the STATUS moves and the kill cannot come from the `unresolved:` conjunct.
if ! sed 's/^\( *\)emit "NEEDS-REVIEW" "\$LABEL" "unresolved: the sh receipt exited 9,/\1emit "HAND-REVIEW" "$LABEL" "unresolved: the sh receipt exited 9,/' "$RV" > "$MUT"; then
  bad "mutation-9-hand" "DID NOT APPLY: sed failed"
elif cmp -s "$RV" "$MUT"; then
  bad "mutation-9-hand" "DID NOT APPLY: the mutation matched nothing, so the NEEDS-REVIEW route is unproven"
else
  score_route_mut "mutation-9-hand" "exit 9 routed to HAND-REVIEW"
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
  ok "stdin-receipt" "a receipt reading stdin leaves all four rows with their verdicts"
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
  ok "stdin-control" "the unmutated copy in the mutant root keeps all four rows"
else
  bad "stdin-control" "the unmutated copy fails seed D, so the mutant verdict below is void: $why"
fi
if ! sed 's@^\( *( unset \$LIB_VARS; unset -f \$LIB_FNS; cd "\$REPO_ROOT" && eval "\$REST"\) </dev/null ) >/dev/null 2>"\$ERRF"$@\1 ) >/dev/null 2>"$ERRF"@' "$RV" > "$MUT"; then
  bad "mutation-stdin" "DID NOT APPLY: sed failed"
elif cmp -s "$RV" "$MUT"; then
  bad "mutation-stdin" "DID NOT APPLY: the mutation matched nothing, so the closed stdin is unproven"
else
  MOUT="$(bash "$MUT" "$LD" 2>&1)"
  if ! grep -qE '	BL-131	' <<<"$MOUT"; then
    bad "mutation-stdin" "the reader's own row (BL-131) is gone -- the mutant broke the engine, not the redirect"
  elif why="$(stdin_ok "$MOUT")"; then
    bad "mutation-stdin" "SURVIVED: with the receipt's stdin inherited, seed D still keeps every row"
  else
    ok "mutation-stdin" "killed: with the receipt's stdin inherited the reader swallows the later entries -- $why"
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
  ok "memo-leak" "engine verdicts equal bare verdicts for BL-141/142, with and without a caller-exported memo"
else
  bad "memo-leak" "$why"
fi
[ -d "$INMEMO" ] && ok "memo-caller-owned" "a caller's memo directory survives the engine run" \
  || bad "memo-caller-owned" "the engine removed a memo directory its caller owns"
cp "$RV" "$MUT"
if why="$(leak_both "$MUT")"; then ok "memo-control" "the unmutated copy in the mutant root passes seed E both ways"
else bad "memo-control" "the unmutated copy fails seed E, so the mutant verdicts below are void: $why"; fi
score_leak_mut() { # <arm> <description>
  local why o
  o="$(env -u AI_DLC_RECONCILE_MEMO bash "$MUT" "$LE" 2>&1)"
  if ! grep -qE '^STILL-LIVE	BL-140	' <<<"$o"; then
    bad "$1" "the baseline row (BL-140 STILL-LIVE) is gone — the mutant broke the engine, not the unset"
  elif why="$(leak_both "$MUT")"; then
    bad "$1" "SURVIVED: with $2 seed E still passes"
  else
    ok "$1" "killed: $2 — $why"
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
  score_leak_mut "mutation-memo-export" "lib.sh's variables left exported to every receipt"
fi
# 2. DIFF-ONLY: the variable is no longer named outright, so a CALLER's memo leaks through.
if ! sed 's/^LIB_VARS="AI_DLC_RECONCILE_MEMO \$(_rv_added /LIB_VARS="$(_rv_added /' "$RV" > "$MUT"; then
  bad "mutation-memo-diffonly" "DID NOT APPLY: sed failed"
elif cmp -s "$RV" "$MUT"; then
  bad "mutation-memo-diffonly" "DID NOT APPLY: the mutation matched nothing"
else
  score_leak_mut "mutation-memo-diffonly" "only the variables lib.sh ADDED removed, a caller-exported memo kept"
fi
# 3. THE FUNCTIONS LEFT DEFINED in the receipt's shell.
if ! sed 's/^\( *\)( unset \$LIB_VARS; unset -f \$LIB_FNS; cd /\1( unset $LIB_VARS; cd /' "$RV" > "$MUT"; then
  bad "mutation-memo-fns" "DID NOT APPLY: sed failed"
elif cmp -s "$RV" "$MUT"; then
  bad "mutation-memo-fns" "DID NOT APPLY: the mutation matched nothing"
else
  score_leak_mut "mutation-memo-fns" "lib.sh's functions left defined in every receipt"
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
  ok "cant-measure" "missing helper and eval-time syntax error read NEEDS-REVIEW; three subject-side near-misses stay STILL-LIVE"
else
  bad "cant-measure" "$why"
fi
cp "$RV" "$MUT"
MOUT="$(bash "$MUT" "$LF" 2>&1)"
if why="$(cm_ok "$MOUT")"; then ok "cant-measure-control" "the unmutated copy in the mutant root passes seed F — its own name differs, so the prefix is derived, not fixed"
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
  MOUT="$(bash "$MUT" "$LF" 2>&1)"
  if ! grep -qE '^STILL-LIVE	BL-150	' <<<"$MOUT"; then
    bad "mutation-stderr-route" "the baseline row (BL-150 STILL-LIVE) is gone — the mutant broke the engine, not the routing"
  elif why="$(cm_ok "$MOUT")"; then
    bad "mutation-stderr-route" "SURVIVED: with the stderr routing dropped seed F still passes"
  else
    ok "mutation-stderr-route" "killed: stderr routing dropped — $why"
  fi
fi
# THE OWN-PREFIX DROPPED: the three strings matched on any stderr line. The near-misses must die.
PFN="$(grep -c '^      "\$SELF_NAME: line "\*|"\$SELF_NAME: eval: line "\*) ;;$' "$RV")" || PFN=0
if [ "$PFN" -eq 1 ]; then ok "prefix-anchor" "the own-interpreter prefix line is unique in the engine"
else bad "prefix-anchor" "the own-interpreter prefix line appears $PFN times; the mutation below needs exactly one"; fi
if ! sed 's/^\(      \)"\$SELF_NAME: line "\*|"\$SELF_NAME: eval: line "\*) ;;$/\1*) ;;/' "$RV" > "$MUT"; then
  bad "mutation-no-prefix" "DID NOT APPLY: sed failed"
elif cmp -s "$RV" "$MUT"; then
  bad "mutation-no-prefix" "DID NOT APPLY: the mutation matched nothing"
else
  MOUT="$(bash "$MUT" "$LF" 2>&1)"
  if ! grep -qE '^STILL-LIVE	BL-150	' <<<"$MOUT"; then
    bad "mutation-no-prefix" "the baseline row (BL-150 STILL-LIVE) is gone — the mutant broke the engine, not the prefix"
  elif why="$(cm_ok "$MOUT")"; then
    bad "mutation-no-prefix" "SURVIVED: with any stderr line counted, seed F still passes"
  else
    ok "mutation-no-prefix" "killed: any stderr line counted — $why"
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
