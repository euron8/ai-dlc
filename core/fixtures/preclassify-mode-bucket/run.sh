#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# preclassify-mode-bucket — the noop arms of the `A` and `M` branches must bucket on the
# consumer's EXEC BIT, not on content alone, and must not collapse the two mode-only cases
# into one.
#
# Usage: run.sh          (the suite runs it from the REPO ROOT, not from this directory)
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# preclassify.sh hashes CONTENT only -- `blob_hash` is `git rev-parse <rev>:<path>` and
# `file_hash` is `git hash-object <file>`. Neither carries a file mode. So a MODE-ONLY
# upstream change (same blob, 100644 -> 100755, the shape apply.sh's sync_mode_from_theirs
# exists to deliver) makes base_h = theirs_h = ours_h, and the M-branch's `ours_h = base_h
# -> UPSTREAM-ONLY` arm fires before the `ours_h = theirs_h -> ALREADY-AT-THEIRS` arm can.
# Every such file is filed UPSTREAM-ONLY regardless of what the consumer's bit actually is.
#
# THE OBVIOUS FIX IS A REGRESSION, AND THAT IS WHY THIS FIXTURE HAS TWO MODE-ONLY CASES.
# Swapping the two arms -- putting ALREADY-AT-THEIRS first -- fixes the consumer that is
# already 755 and BREAKS the consumer that is still 644, which genuinely needs the bit
# delivered and would now be bucketed as a noop. The two cases differ ONLY in the exec bit
# of a byte-identical file, so a fixture carrying one of them certifies whichever half its
# author happened to seed. Both are here, in the same run.
#
# THE SAME PAIR EXISTS IN THE OTHER DIRECTION. Upstream can DROP an exec bit (100755 ->
# 100644) as easily as add one, and a fix written against the gain direction alone reads
# the drop direction backwards. C3/C4 are that pair.
#
# AND THE SAME PAIR EXISTS ON THE `A` BRANCH, WHICH IS A SEPARATE SUBJECT AND WAS UNCOVERED
# HERE FOR ONE RELEASE. `ALREADY-PRESENT` carries the identical conjunct against a NET-NEW
# upstream file the consumer already holds byte-identically, with `ours_h = theirs_h ->
# UPSTREAM-ONLY-ADD` as its fall-through. Every case it carried was status `M`, and the
# blanket "all cases are M" assertion could not even
# express the other branch. A guard that cannot fire reads exactly like a guard that passed.
#
# NOTHING HERE RE-IMPLEMENTS EITHER BRANCH. Every assertion drives the shipping
# preclassify.sh over a synthetic three-ref tree and reads the BUCKET STRING out of its
# TSV. A fixture that recomputed the expected bucket from base/theirs/ours would be a
# second implementation of the subject, and the two would agree because one hand wrote
# both.

set -uo pipefail

# The gate inherits every AI_DLC_* tunable a consumer set in settings.json; a fixture that
# drives a script while inheriting them tests the CONFIG, not the code (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }

# WALK UP FROM THIS FILE FOR THE SUBJECT ITSELF, in either install layout, and never for
# `VERSION`. Counting `..` hops answers differently from core/fixtures/<name>/ here and
# tests/fixtures/<name>/ on a consumer, silently -- and VERSION is a content-key EXCLUDED
# path (I55), so a fixture that READS one can change behaviour without the pre-push suite
# ever re-running. install.sh SPLITS what shares a parent, so each candidate names its own
# full path rather than deriving one from the other (I33).
RECON=""
_d="$HERE"
while [ "$_d" != "/" ]; do
  if   [ -f "$_d/core/skills/ai-dlc-update/reconcile/preclassify.sh" ]; then
    RECON="$_d/core/skills/ai-dlc-update/reconcile"; break
  elif [ -f "$_d/.claude/skills/ai-dlc-update/reconcile/preclassify.sh" ]; then
    RECON="$_d/.claude/skills/ai-dlc-update/reconcile"; break
  fi
  _d="$(dirname "$_d")"
done

echo "preclassify-mode-bucket"

# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT: it reaches a consumer on one pull and the code
# it guards may land on the next, so an absent subject reports SKIP rather than the green
# line that would read as "checked, and fine".
if [ -z "$RECON" ]; then
  echo "  skip  reconcile/preclassify.sh not present in this tree (neither install layout)"
  echo "  0 failed, 1 skipped"
  fx_skip_exit "$HERE"
fi
# Print the RESOLVED path, so the log names the subject the arms loaded.
echo "  subject: $RECON/preclassify.sh"
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/preclassify.sh"
[ -f "$RECON/lib.sh" ] && echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/lib.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pc-mode.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
broken() { printf 'FIXTURE BROKEN: %s\n' "$1" >&2; exit 2; }
# A literal-tail path, never `. "$VAR"`: in a fixture opted in by an inproc: row, P1 reads an opaque source as a drive.
[ -f "$HERE/../lib/mutant.sh" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: sourcing lib/mutant.sh failed" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

# IN PROCESS (BL-878). The subject is SOURCED once into this shell (its guard returns after defining prec_main) and
# every arm calls prec_main in a subshell, so the subject's own `exit`, `set -u`, `set -f` and traps stay there. The
# source is one fx_inproc pass (the inproc: row). A subshell is never the top shell of the subject's failure signal
# (`kill -USR1 $$`), and no arm here forces a git failure, so this shell ignores USR1: a regressed subject that did
# signal would then leave a wrong answer for an arm to fail on, never end this run.
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A consumer can receive this file one pull before the wrapped
# preclassify.sh, and sourcing a pre-wrap subject would run its whole body in this shell. So the shape is checked
# first, on its two halves: neither the `prec_main() {` line nor the column-0 source guard is a subject that predates
# the wrap, which prints SKIP and exits 0 -- never an ok. Exactly one half is a respelled subject this fixture can no
# longer drive, which FAILS. The distribution cannot reach the SKIP unnoticed: C5 (validate-fixture-inprocess.sh)
# refuses a cli subject without the guard, and J3 refuses the start count moving.
PCS="$RECON/preclassify.sh"
prec_def=0; prec_guard=0
grep -q '^prec_main() {$' "$PCS"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $PCS (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || prec_def=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$PCS"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $PCS (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || prec_guard=1
if [ "$prec_def$prec_guard" = 00 ]; then echo "SKIP: subject predates the in-process wrap"; fx_skip_exit "$HERE"; fi
if [ "$prec_def" = 0 ]; then echo "   FAIL  $PCS carries the column-0 source guard but no \`prec_main() {\` line -- a respelled subject this fixture cannot drive" >&2; echo "preclassify-mode-bucket: FAIL (1)" >&2; exit 1; fi
if [ "$prec_guard" = 0 ]; then echo "   FAIL  $PCS defines \`prec_main() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run prec_main in this shell" >&2; echo "preclassify-mode-bucket: FAIL (1)" >&2; exit 1; fi
fx_inproc "$PCS"
. "$PCS" || { echo "FIXTURE BROKEN: sourcing $PCS failed" >&2; exit 2; }
declare -F prec_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $PCS defined no prec_main" >&2; exit 2; }
trap : USR1

# pc_ip <rows> <err> <subject args...> -> prec_main's exit status; stdout and stderr land in the two files
pc_ip() {
  local _r="$1" _e="$2"; shift 2
  fx_inproc "$PCS"
  ( prec_main "$@" ) > "$_r" 2> "$_e"
}

# --- the case table --------------------------------------------------------------------
# id | core/git-hooks/<file> | expected base..theirs STATUS | the bucket the FIXED code emits
#
# THE STATUS IS PER-CASE AND ASSERTED, NOT ASSUMED. It was a blanket "every case is M" for
# one release, and a blanket assertion cannot express a second branch -- so the `A` branch
# had no case and no assertion while the suite stayed green over it. This column
# is what lets one table drive both branches; S2 checks each cell against the diff git
# actually produces, and refuses if either branch's population has emptied.
#
# C1/C2 are the M-branch gain pair and C3/C4 the drop pair: within each pair base and theirs
# hold the SAME BLOB and differ only in mode, and the two members differ only in the
# consumer's exec bit. C7 is the M arm with no mode-only twin -- content already at theirs,
# bit still wrong.
#
# A2/A3 and A4/A5 are those two pairs one branch over, against a net-new upstream file the
# consumer already holds byte-identically. A3 and A5 are the cases that fire; A2 and A4 are
# their mode-matched siblings.
CASE_TABLE='C1|gain-consumer-755.sh|M|ALREADY-AT-THEIRS
C2|gain-consumer-644.sh|M|UPSTREAM-ONLY
C3|drop-consumer-644.sh|M|ALREADY-AT-THEIRS
C4|drop-consumer-755.sh|M|UPSTREAM-ONLY
C5|content-at-base.sh|M|UPSTREAM-ONLY
C6|content-at-theirs.sh|M|ALREADY-AT-THEIRS
C7|content-at-theirs-wrong-mode.sh|M|UPSTREAM-ONLY
C8|both-changed.sh|M|BOTH-CHANGED->CLASSIFY
C9|consumer-deleted.sh|M|UPSTREAM-MOD+consumer-deleted->CLASSIFY
A1|a-new-consumer-absent.sh|A|UPSTREAM-ONLY-ADD
A2|a-new-755-cons-755.sh|A|ALREADY-PRESENT
A3|a-new-755-cons-644.sh|A|UPSTREAM-ONLY-ADD
A4|a-new-644-cons-644.sh|A|ALREADY-PRESENT
A5|a-new-644-cons-755.sh|A|UPSTREAM-ONLY-ADD
A6|a-new-both-added.sh|A|BOTH-ADDED->CLASSIFY'

# --- a synthetic distribution, two commits ---------------------------------------------
DIST="$WORK/dist"
mkdir -p "$DIST/core/git-hooks" || broken "mkdir dist"
git -C "$DIST" init -q >/dev/null 2>&1 || broken "git init failed"
# core.fileMode MUST be on, or git records 100644 for everything, the mode-only delta this
# fixture is built around is not in the tree at all, and C1-C4 degenerate into four copies
# of "consumer untouched" -- which the UNFIXED branch also answers UPSTREAM-ONLY for.
git -C "$DIST" config core.fileMode true || broken "git config core.fileMode failed"
gitc() { git -C "$DIST" -c user.email=f@f -c user.name=fixture "$@"; }
gh()   { printf '%s\n' "$DIST/core/git-hooks/$1"; }
w()    { printf '#!/usr/bin/env bash\necho %s\n' "$2" > "$(gh "$1")"; }

# base -- the A cases are deliberately ABSENT here; that is what makes them status A.
w gain-consumer-755.sh            c1;      chmod 644 "$(gh gain-consumer-755.sh)"
w gain-consumer-644.sh            c2;      chmod 644 "$(gh gain-consumer-644.sh)"
w drop-consumer-644.sh            c3;      chmod 755 "$(gh drop-consumer-644.sh)"
w drop-consumer-755.sh            c4;      chmod 755 "$(gh drop-consumer-755.sh)"
w content-at-base.sh              c5-base; chmod 644 "$(gh content-at-base.sh)"
w content-at-theirs.sh            c6-base; chmod 644 "$(gh content-at-theirs.sh)"
w content-at-theirs-wrong-mode.sh c7-base; chmod 644 "$(gh content-at-theirs-wrong-mode.sh)"
w both-changed.sh                 c8-base; chmod 644 "$(gh both-changed.sh)"
w consumer-deleted.sh             c9-base; chmod 644 "$(gh consumer-deleted.sh)"
printf '1.0.0\n' > "$DIST/VERSION"
gitc add -A >/dev/null 2>&1 && gitc commit -q -m base >/dev/null 2>&1 || broken "base commit failed"
BASE="$(git -C "$DIST" rev-parse HEAD)"

# theirs: C1/C2 gain the bit and C3/C4 lose it, all four keeping their bytes. C5-C9 change
# bytes; C7 changes bytes AND gains the bit. A1-A6 are files that did not exist at base.
chmod 755 "$(gh gain-consumer-755.sh)" "$(gh gain-consumer-644.sh)"
chmod 644 "$(gh drop-consumer-644.sh)" "$(gh drop-consumer-755.sh)"
w content-at-base.sh              c5-theirs; chmod 644 "$(gh content-at-base.sh)"
w content-at-theirs.sh            c6-theirs; chmod 644 "$(gh content-at-theirs.sh)"
w content-at-theirs-wrong-mode.sh c7-theirs; chmod 755 "$(gh content-at-theirs-wrong-mode.sh)"
w both-changed.sh                 c8-theirs; chmod 644 "$(gh both-changed.sh)"
w consumer-deleted.sh             c9-theirs; chmod 644 "$(gh consumer-deleted.sh)"
w a-new-consumer-absent.sh        a1;        chmod 644 "$(gh a-new-consumer-absent.sh)"
w a-new-755-cons-755.sh           a2;        chmod 755 "$(gh a-new-755-cons-755.sh)"
w a-new-755-cons-644.sh           a3;        chmod 755 "$(gh a-new-755-cons-644.sh)"
w a-new-644-cons-644.sh           a4;        chmod 644 "$(gh a-new-644-cons-644.sh)"
w a-new-644-cons-755.sh           a5;        chmod 644 "$(gh a-new-644-cons-755.sh)"
w a-new-both-added.sh             a6-theirs; chmod 644 "$(gh a-new-both-added.sh)"
printf '2.0.0\n' > "$DIST/VERSION"
gitc add -A >/dev/null 2>&1 && gitc commit -q -m theirs >/dev/null 2>&1 || broken "theirs commit failed"
THEIRS="$(git -C "$DIST" rev-parse HEAD)"

# --- S1. THE M-BRANCH TREE CARRIES THE DELTA THE FIXTURE IS ABOUT ----------------------
# REFUSE unless the two modes DIFFER and the two blobs are the SAME. Both halves are the
# control: equal modes means the subject is absent, and unequal blobs means these cases
# quietly exercise the content arms instead of the mode arm.
tmode() { git -C "$DIST" ls-tree "$1" -- "core/git-hooks/$2" | awk '{print $1}'; }
for _pair in "gain-consumer-755.sh 100644 100755" "gain-consumer-644.sh 100644 100755" \
             "drop-consumer-644.sh 100755 100644" "drop-consumer-755.sh 100755 100644"; do
  set -- $_pair
  _bm="$(tmode "$BASE" "$1")"; _tm="$(tmode "$THEIRS" "$1")"
  [ "$_bm" = "$2" ] || broken "$1 records mode '$_bm' at base, expected $2 -- the mode delta is not in the tree"
  [ "$_tm" = "$3" ] || broken "$1 records mode '$_tm' at theirs, expected $3 -- the mode delta is not in the tree"
  [ "$_bm" != "$_tm" ] || broken "$1 has the SAME mode at base and theirs -- this fixture's whole subject is absent"
  [ "$(git -C "$DIST" rev-parse "$BASE:core/git-hooks/$1")" = "$(git -C "$DIST" rev-parse "$THEIRS:core/git-hooks/$1")" ] \
    || broken "$1 is not a MODE-ONLY change -- its blob moved too, so it exercises the content arms instead"
done
ok "S1 the M-branch tree carries a real mode-only delta in BOTH directions, same blob either side"

# --- S1b. THE A CASES ARE GENUINELY NEW, AT THE MODES THE TABLE CLAIMS -----------------
# An A case that already existed at base is an M case wearing an A label: it would be
# classified by the branch this fixture already covered, and the A-branch arms would then
# have no subject.
for _pair in "a-new-consumer-absent.sh 100644" "a-new-755-cons-755.sh 100755" \
             "a-new-755-cons-644.sh 100755" "a-new-644-cons-644.sh 100644" \
             "a-new-644-cons-755.sh 100644" "a-new-both-added.sh 100644"; do
  set -- $_pair
  git -C "$DIST" rev-parse -q --verify "$BASE:core/git-hooks/$1" >/dev/null 2>&1 \
    && broken "$1 EXISTS at base -- it is not a net-new upstream file and cannot reach the A branch"
  _tm="$(tmode "$THEIRS" "$1")"
  [ "$_tm" = "$2" ] || broken "$1 records mode '$_tm' at theirs, expected $2 -- the A-branch mode arm is not being exercised"
done
ok "S1b all 6 A cases are absent at base and carry the theirs-side modes the table declares"

# --- S2. EVERY CASE'S base..theirs STATUS IS THE ONE THE TABLE DECLARES ----------------
# PER-CASE, not blanket. The blanket form asserted "M" for all nine cases and read as a
# thorough check; what it actually did was make a second branch inexpressible, because any
# case written for it would have failed the assertion that was supposed to be protecting
# the fixture's inputs.
DIFF="$(git -C "$DIST" diff --name-status "$BASE" "$THEIRS" -- core/)"
_seen_m=0; _seen_a=0
while IFS='|' read -r id file st exp; do
  [ -n "$id" ] || continue
  got_st="$(printf '%s\n' "$DIFF" | awk -F'\t' -v p="core/git-hooks/$file" '$2==p{print $1}')"
  case "$got_st" in
    "$st"*) : ;;
    *) broken "$id ($file) has diff status '${got_st:-<absent>}', the table declares '$st' -- it does not reach the branch it was written for" ;;
  esac
  [ "$st" = M ] && _seen_m=$((_seen_m+1))
  [ "$st" = A ] && _seen_a=$((_seen_a+1))
done <<<"$CASE_TABLE"
# BOTH branches must have a live population. Per-case status alone is satisfied by a table
# that has drifted to one branch -- every remaining cell would still match -- and the result
# is the exact hole this column exists to close, one level up.
[ "$_seen_m" -gt 0 ] || broken "no case declares status M -- the M/rename branch has no population"
[ "$_seen_a" -gt 0 ] || broken "no case declares status A -- the A branch has no population, which is the hole this table's status column exists to close"
ok "S2 every case's diff status matches the table ($_seen_m on the M branch, $_seen_a on the A branch)"

# --- a consumer ------------------------------------------------------------------------
# core/git-hooks/X maps to .githooks/X. Every consumer file gets an EXPLICIT chmod: a
# umask-derived bit would make C1 and C2 the same case on some machines and not others.
CONS="$WORK/consumer"
mkdir -p "$CONS/.claude" "$CONS/.githooks" || broken "mkdir consumer"
cw() { printf '#!/usr/bin/env bash\necho %s\n' "$2" > "$CONS/.githooks/$1"; chmod "$3" "$CONS/.githooks/$1"; }
cw gain-consumer-755.sh            c1          755  # identical bytes, bit ALREADY delivered
cw gain-consumer-644.sh            c2          644  # identical bytes, bit STILL OWED
cw drop-consumer-644.sh            c3          644  # identical bytes, bit ALREADY removed
cw drop-consumer-755.sh            c4          755  # identical bytes, bit STILL TO REMOVE
cw content-at-base.sh              c5-base     644  # consumer untouched, upstream moved
cw content-at-theirs.sh            c6-theirs   644  # consumer already at theirs, mode right
cw content-at-theirs-wrong-mode.sh c7-theirs   644  # consumer already at theirs, mode WRONG
cw both-changed.sh                 c8-consumer 644  # both sides moved
# C9 and A1 are deliberately absent from the consumer.
cw a-new-755-cons-755.sh           a2          755  # net-new upstream file, already held, bit MATCHES
cw a-new-755-cons-644.sh           a3          644  # net-new upstream file, already held, bit MISSING
cw a-new-644-cons-644.sh           a4          644  # net-new upstream file, already held, bit MATCHES
cw a-new-644-cons-755.sh           a5          755  # net-new upstream file, already held, bit SPURIOUS
cw a-new-both-added.sh             a6-consumer 644  # both sides added it, different bytes
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$CONS/.claude/.ai-dlc-version"

# --- S3. the consumer's exec bits are what the case table says -------------------------
for _p in "gain-consumer-755.sh x" "gain-consumer-644.sh -" "drop-consumer-644.sh -" \
          "drop-consumer-755.sh x" "content-at-theirs-wrong-mode.sh -" \
          "a-new-755-cons-755.sh x" "a-new-755-cons-644.sh -" \
          "a-new-644-cons-644.sh -" "a-new-644-cons-755.sh x"; do
  set -- $_p
  if [ "$2" = x ]; then
    [ -x "$CONS/.githooks/$1" ] || broken "consumer $1 is not executable -- chmod did not take on this filesystem"
  else
    [ ! -x "$CONS/.githooks/$1" ] || broken "consumer $1 IS executable -- chmod did not take on this filesystem"
  fi
done
[ -e "$CONS/.githooks/consumer-deleted.sh" ] && broken "C9 must be absent from the consumer"
[ -e "$CONS/.githooks/a-new-consumer-absent.sh" ] && broken "A1 must be absent from the consumer"
ok "S3 the consumer's exec bits are as the case table declares"

# --- driving the subject ----------------------------------------------------------------
# The three helpers below each walk the case table ONCE, inside a single awk, rather than
# forking a reader per case. That is a COST decision, not a style one: this fixture runs
# twelve of them, and the per-case shape put roughly forty forks into each -- measured at
# 5.9s against 3.2s for the same assertions. The suite is pole-bound and a fixture that
# doubles for no added coverage is spending the operator's wall clock.
#
# THE TABLE AND THE SUBJECT'S OUTPUT REACH awk THROUGH `ENVIRON`, NEVER THROUGH `-v`.
# `awk -v` strips one level of escaping, which already cost this file one silent
# no-match (see M_ANCHOR below). `ENVIRON` does no escape processing at all, so a bucket
# name containing a backslash could not quietly become a different string.

# vector -> "C1=<bucket> C2=<bucket> ..." for every case, in table order.
# `<none>` when no row was emitted, so an arm demanding a bucket string is PRESENCE-shaped
# and a subject that emits nothing fails it by construction rather than passing quietly.
vector() {
  local out
  pc_ip "$WORK/vec.rows" /dev/null "$DIST" "$BASE" "$THEIRS" "$CONS"
  out="$(<"$WORK/vec.rows")"
  PCMB_TABLE="$CASE_TABLE" PCMB_OUT="$out" awk 'BEGIN {
    n = split(ENVIRON["PCMB_TABLE"], rows, "\n")
    m = split(ENVIRON["PCMB_OUT"], lines, "\n")
    for (i = 1; i <= m; i++) { split(lines[i], f, "\t"); if (f[2] != "") seen[f[2]] = f[4] }
    s = ""
    for (i = 1; i <= n; i++) {
      if (split(rows[i], c, "|") < 4) continue
      p = "core/git-hooks/" c[2]
      s = s c[1] "=" ((p in seen) ? seen[p] : "<none>") " "
    }
    sub(/ $/, "", s); printf "%s", s
  }'
}

# expected_sig -> the FIXED signature, "C1=<bucket> C2=<bucket> ...", derived from the case table so that it
# cannot drift away from it.
expected_sig() {
  PCMB_TABLE="$CASE_TABLE" awk 'BEGIN {
    n = split(ENVIRON["PCMB_TABLE"], rows, "\n")
    s = ""
    for (i = 1; i <= n; i++) {
      if (split(rows[i], c, "|") < 4) continue
      s = s c[1] "=" c[4] " "
    }
    sub(/ $/, "", s); printf "%s", s
  }'
}

# sig_diff <sig> -> "C1(want X got Y) ..." for the cells that differ from the fixed
# expectation, so a reader can see which cells moved without re-deriving the table.
sig_diff() {
  PCMB_TABLE="$CASE_TABLE" PCMB_SIG="$1" awk 'BEGIN {
    n = split(ENVIRON["PCMB_TABLE"], rows, "\n")
    m = split(ENVIRON["PCMB_SIG"], cellv, " ")
    for (i = 1; i <= m; i++) { k = index(cellv[i], "="); if (k > 1) got[substr(cellv[i], 1, k-1)] = substr(cellv[i], k+1) }
    o = ""
    for (i = 1; i <= n; i++) {
      if (split(rows[i], c, "|") < 4) continue
      g = (c[1] in got) ? got[c[1]] : ""
      if (g != c[4]) o = o c[1] "(want " c[4] " got " g ") "
    }
    printf "%s", (o == "" ? "<NOTHING -- no case differs>" : o)
  }'
}

EXPECTED="$(expected_sig)"
NCASES="$(grep -c . <<<"$CASE_TABLE")"

# --- A. THE FIXED SUBJECT, over every arm of both branches -------------------------------
SIG_CLEAN="$(vector)"
if [ "$SIG_CLEAN" = "$EXPECTED" ]; then
  ok "A the shipping preclassify.sh buckets all $NCASES cases correctly, across both branches"
else
  bad "A the shipping preclassify.sh mis-buckets $(sig_diff "$SIG_CLEAN")"
  bad "A   expected: $EXPECTED"
  bad "A   got:      $SIG_CLEAN"
fi

# --- the cli cells (cells.decl): the subject run as a PROGRAM once per distinct CLI outcome --------------------------
# The outcomes are exit x output class: 0 with the default mode's rows, 0 with --untangle's rows (below, in its own
# world), 2 with the refusal line on stderr. One `FXCELL=<id> bash "$PCS"` start per outcome, each compared with the
# in-process call on the same input: stdout, stderr and exit separately, byte for byte. A cell also asserts its own
# outcome (a positive conjunct, so two runs that both printed nothing cannot read as equivalent).
EQ="$WORK/eq"; mkdir -p "$EQ" || broken "mkdir eq"
eqv() { # <cell-id> <subject args...> -> $EQ/<id>.{ip,cl}.{out,err,rc}
  local id="$1"; shift
  pc_ip "$EQ/$id.ip.out" "$EQ/$id.ip.err" "$@"; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" bash "$PCS" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_twin() { printf 'in-process rc=%s rows=%s err=[%s] / program rc=%s rows=%s err=[%s]' "$(cat "$EQ/$1.ip.rc")" "$(grep -c . "$EQ/$1.ip.out")" \
  "$(head -1 "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(grep -c . "$EQ/$1.cl.out")" "$(head -1 "$EQ/$1.cl.err")"; }
if eqv cli-rows "$DIST" "$BASE" "$THEIRS" "$CONS" && [ "$(cat "$EQ/cli-rows.cl.rc")" = 0 ] \
   && [ "$(grep -c . "$EQ/cli-rows.cl.out")" -ge "$NCASES" ] && [ ! -s "$EQ/cli-rows.cl.err" ]; then
  ok "cli-rows: the program buckets the $NCASES cases exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-rows: the program and the in-process call differ, or the outcome is not exit 0 with a row per case ($(eq_twin cli-rows))"; fi
if eqv cli-refuse "$WORK/no-such-dist" "$BASE" "$THEIRS" "$CONS" && [ "$(cat "$EQ/cli-refuse.cl.rc")" = 2 ] && [ ! -s "$EQ/cli-refuse.cl.out" ] \
   && [ "$(cat "$EQ/cli-refuse.cl.err")" = "preclassify: dist-repo not a directory: $WORK/no-such-dist" ]; then
  ok "cli-refuse: the program refuses a dist that is not a directory exactly as the in-process call does (stdout, stderr, exit 2)"
else bad "cli-refuse: the program and the in-process call differ, or the outcome is not exit 2 with the refusal line ($(eq_twin cli-refuse))"; fi
if ! cmp -s "$EQ/cli-rows.cl.out" "$EQ/cli-refuse.cl.out" && ! cmp -s "$EQ/cli-rows.cl.rc" "$EQ/cli-refuse.cl.rc"; then
  ok "cli cells discriminate: the classifying and the refusing input give different stdout and exit"
else bad "cli cells do not discriminate: cli-rows and cli-refuse gave the same stdout or exit"; fi

# =========================================================================================
# BL-100 / BL-364 -- `--untangle` READS THE MODE, AND ITS MANIFEST LISTING IS NOT C-QUOTED
# =========================================================================================
# `--untangle` bucketed on `ours_h = base_h` alone, so a consumer copy holding base's bytes with
# the wrong exec bit read ALREADY-AT-THEIRS, "nothing to untangle". The decided bucket is
# UPSTREAM-ONLY-ADD -- the one the default mode's A branch gives content-present-bit-not -- never
# BOTH-CHANGED->CLASSIFY, which is a content tangle. Its manifest `ls-files` listed paths under the
# default core.quotePath, so a non-ASCII manifest file arrived C-quoted and mapped to no consumer path.
# Own world, base == theirs as the mode's contract requires:
#   U1 core/git-hooks/pre-push 100755, consumer 755   -> ALREADY-AT-THEIRS   (control)
#   U2 the same file, consumer 644                     -> UPSTREAM-ONLY-ADD
#   U3 core/rules/plain.md 100644, consumer 644        -> ALREADY-AT-THEIRS   (control, the 100644 direction)
#   U4 the same file, consumer 755                     -> UPSTREAM-ONLY-ADD
#   U5 core/rules/caf\303\251.md 100755, consumer 755  -> one row, raw path, ALREADY-AT-THEIRS
#   U6 core/rules/edited.md, consumer bytes differ     -> BOTH-CHANGED->CLASSIFY (control)
U_RUN=1
case "$RECON" in */core/skills/ai-dlc-update/reconcile) U_DIST=1 ;; *) U_DIST=0 ;; esac
# Keyed on the CODE of the --untangle arm, never on its trailing comment: a comment can be reworded
# with the conjunct intact (a false SKIP on a consumer) or survive the conjunct's removal.
if ! grep -qF '[ "$ours_h" = "$base_h" ] && mode_at_theirs "$path" "$cons"; then bucket="ALREADY-AT-THEIRS"' "$RECON/preclassify.sh"; then
  if [ "$U_DIST" = 0 ]; then
    printf '  SKIP  BL-100/BL-364 arms U1-U6 -- the installed preclassify.sh predates the --untangle mode conjunct; it lands with the pull that carries this fixture\n'
    U_RUN=0
  else
    printf '  --    (BL-100: this preclassify.sh carries no --untangle mode conjunct; in the distribution the arms run anyway and must go red)\n'
  fi
fi
if [ "$U_RUN" = 1 ]; then
  UD="$WORK/u-dist"; UC="$WORK/u-cons"
  CAFE="caf$(printf '\303\251').md"
  mkdir -p "$UD/core/git-hooks" "$UD/core/rules" "$UC/.githooks" "$UC/.claude/rules" || broken "mkdir untangle world"
  git -C "$UD" init -q >/dev/null 2>&1 || broken "git init untangle dist"
  git -C "$UD" config core.fileMode true || broken "git config core.fileMode on the untangle dist"
  printf '#!/usr/bin/env bash\necho hook\n' > "$UD/core/git-hooks/pre-push"; chmod 755 "$UD/core/git-hooks/pre-push"
  printf 'plain rule\n' > "$UD/core/rules/plain.md"; chmod 644 "$UD/core/rules/plain.md"
  # 100755 at both ends, so a mode check that demands +x cannot reach U5: U5 is quotePath's alone.
  printf 'accented rule\n' > "$UD/core/rules/$CAFE"; chmod 755 "$UD/core/rules/$CAFE"
  printf 'edited rule base\n' > "$UD/core/rules/edited.md"
  git -C "$UD" -c user.email=f@f -c user.name=fixture add -A >/dev/null 2>&1 \
    && git -C "$UD" -c user.email=f@f -c user.name=fixture commit -q -m base >/dev/null 2>&1 || broken "untangle dist commit"
  UH="$(git -C "$UD" rev-parse HEAD)" || broken "untangle dist rev-parse"
  # SEED CONTROL: the two modes are really in the tree, and the accented name really is C-quoted by
  # a default listing -- else U2/U4 and U5 cannot express their defects.
  [ "$(git -C "$UD" ls-tree "$UH" -- core/git-hooks/pre-push | cut -c1-6)" = 100755 ] || broken "the untangle seed's pre-push is not 100755"
  [ "$(git -C "$UD" ls-tree "$UH" -- core/rules/plain.md | cut -c1-6)" = 100644 ] || broken "the untangle seed's plain.md is not 100644"
  _u_ls="$(git -C "$UD" ls-files 'core/rules/*.md')" || broken "ls-files on the untangle seed failed"
  grep -q '^"' <<<"$_u_ls" || broken "a default ls-files does not C-quote the accented name here, so U5 cannot express BL-364"
  cp "$UD/core/git-hooks/pre-push" "$UC/.githooks/pre-push"
  cp "$UD/core/rules/plain.md" "$UC/.claude/rules/plain.md"
  cp "$UD/core/rules/$CAFE" "$UC/.claude/rules/$CAFE"; chmod 755 "$UC/.claude/rules/$CAFE"
  printf 'edited rule CONSUMER\n' > "$UC/.claude/rules/edited.md"
  u_rows() { pc_ip "$WORK/u.rows" /dev/null "$UD" "$UH" "$UH" "$UC" --untangle; cat "$WORK/u.rows"; }
  u_b() { printf '%s\n' "$1" | LC_ALL=C awk -F'\t' -v p="$2" '$2==p {print $4}'; }
  score_u() { # score_u <recon> -> failing cells, then `.`
    local _r="" r1 r2
    chmod 755 "$UC/.githooks/pre-push"; chmod 644 "$UC/.claude/rules/plain.md"
    r1="$(u_rows "$1")"
    chmod 644 "$UC/.githooks/pre-push"; chmod 755 "$UC/.claude/rules/plain.md"
    r2="$(u_rows "$1")"
    [ "$(u_b "$r1" core/git-hooks/pre-push)" = ALREADY-AT-THEIRS ] || _r="${_r}U1"
    [ "$(u_b "$r2" core/git-hooks/pre-push)" = UPSTREAM-ONLY-ADD ] || _r="${_r}U2"
    [ "$(u_b "$r1" core/rules/plain.md)" = ALREADY-AT-THEIRS ] || _r="${_r}U3"
    [ "$(u_b "$r2" core/rules/plain.md)" = UPSTREAM-ONLY-ADD ] || _r="${_r}U4"
    { [ "$(u_b "$r1" "core/rules/$CAFE")" = ALREADY-AT-THEIRS ] \
      && [ "$(printf '%s\n' "$r1" | grep -c 'caf')" = 1 ]; } || _r="${_r}U5"
    [ "$(u_b "$r1" core/rules/edited.md)" = 'BOTH-CHANGED->CLASSIFY' ] || _r="${_r}U6"
    printf '%s.' "$_r"
  }
  u_verdict() { got="$(score_u "$1")"; case "$got" in *.) got="${got%.}" ;; *) broken "the untangle cells did not complete against $1" ;; esac; }
  u_verdict "$RECON"
  if [ -z "$got" ]; then
    ok "BL-100 U1-U4: --untangle buckets base's bytes with the wrong exec bit UPSTREAM-ONLY-ADD in BOTH directions, and the mode-matched copies ALREADY-AT-THEIRS"
    ok "BL-364 U5: --untangle lists an accented manifest file once, under its raw path, at ALREADY-AT-THEIRS; U6 a content edit is still CLASSIFY"
  else
    bad "BL-100/BL-364 cell(s) [$got] failed on --untangle"
  fi

  # cli-untangle: the --untangle mode's rows, in the world u_verdict last scored, compared with the in-process call.
  chmod 755 "$UC/.githooks/pre-push"; chmod 644 "$UC/.claude/rules/plain.md"
  if eqv cli-untangle "$UD" "$UH" "$UH" "$UC" --untangle && [ "$(cat "$EQ/cli-untangle.cl.rc")" = 0 ] && [ ! -s "$EQ/cli-untangle.cl.err" ] \
     && [ "$(u_b "$(cat "$EQ/cli-untangle.cl.out")" core/rules/edited.md)" = 'BOTH-CHANGED->CLASSIFY' ] \
     && [ "$(u_b "$(cat "$EQ/cli-untangle.cl.out")" core/git-hooks/pre-push)" = ALREADY-AT-THEIRS ]; then
    ok "cli-untangle: the program lists the --untangle rows exactly as the in-process call does (stdout, stderr, exit 0)"
  else bad "cli-untangle: the program and the in-process call differ, or the outcome is not exit 0 with the untangle rows ($(eq_twin cli-untangle))"; fi

  # --- BL-685 D1: the untangle listing reads THEIRS' TREE, not the dist INDEX ------------------
  # A BARE dist has no index, so a plain `ls-files "$glob"` listed nothing and --untangle emitted
  # ZERO rows -- byte-identical to "nothing to untangle". U7 runs the same world with the dist
  # replaced by a bare clone and demands the rows the checkout yields. Gated like U1-U6: a consumer
  # whose installed preclassify.sh predates the fix SKIPs, the distribution runs and must go red.
  U7_FIX='ls-files --with-tree="$THEIRS" -- "$glob" || pc_fail'
  U7_RUN=1
  if ! grep -qF "$U7_FIX" "$RECON/preclassify.sh"; then
    if [ "$U_DIST" = 0 ]; then
      printf '  SKIP  BL-685 arm U7 -- the installed preclassify.sh predates the --untangle theirs-tree listing; it lands with the pull that carries this fixture\n'
      U7_RUN=0
    else
      printf '  --    (BL-685: this preclassify.sh lists the dist index; in the distribution U7 runs anyway and must go red)\n'
    fi
  fi
  if [ "$U7_RUN" = 1 ]; then
    UB="$WORK/u-bare"
    git clone -q --bare "$UD" "$UB" >/dev/null 2>&1 || broken "bare clone of the untangle dist"
    # SEED CONTROL: the bare clone's index really is empty, else U7 cannot express the defect.
    [ -z "$(git -C "$UB" ls-files 2>/dev/null)" ] || broken "a plain ls-files in the bare untangle clone listed paths, so U7 cannot express BL-685 D1"
    u7_n() { # u7_n <dist> -> how many rows --untangle emits against that dist
      local n
      pc_ip "$WORK/u7.rows" /dev/null "$1" "$UH" "$UH" "$UC" --untangle
      n="$(grep -c . "$WORK/u7.rows")" || n=0
      printf '%s\n' "$n"
    }
    u7_co="$(u7_n "$UD")"
    u7_bare="$(u7_n "$UB")"
    if [ "$u7_co" -gt 0 ] && [ "$u7_bare" = "$u7_co" ]; then
      ok "BL-685 U7: with a BARE dist --untangle lists its rows from theirs' tree ($u7_bare, as from the checkout)"
    else
      bad "BL-685 U7: a bare dist listed $u7_bare untangle row(s) against $u7_co from the checkout -- the listing reads the dist index, not theirs' tree"
    fi
  fi
fi

echo ""
report_end preclassify-mode-bucket
