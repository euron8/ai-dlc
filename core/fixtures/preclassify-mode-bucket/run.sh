#!/usr/bin/env bash
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
# author happened to seed. Both are here, in the same run, and the mutation battery below
# asserts that the arm swap kills one and the missing mode conjunct kills the other.
#
# THE SAME PAIR EXISTS IN THE OTHER DIRECTION. Upstream can DROP an exec bit (100755 ->
# 100644) as easily as add one, and a fix written against the gain direction alone reads
# the drop direction backwards. C3/C4 are that pair.
#
# AND THE SAME PAIR EXISTS ON THE `A` BRANCH, WHICH IS A SEPARATE SUBJECT AND WAS UNCOVERED
# HERE FOR ONE RELEASE. `ALREADY-PRESENT` carries the identical conjunct against a NET-NEW
# upstream file the consumer already holds byte-identically, with `ours_h = theirs_h ->
# UPSTREAM-ONLY-ADD` as its fall-through. Measured: reverting exactly that half -- conjunct
# dropped, fall-through deleted -- left this fixture at exit 0, while the same harness
# correctly killed a revert of the `ours_h = base_h` arm and a half-done mode fix. Every
# case it carried was status `M`, and the blanket "all cases are M" assertion could not even
# express the other branch. A guard that cannot fire reads exactly like a guard that passed.
#
# THE `A` HALF NEEDS TWO MUTANTS, NOT ONE. Dropping the conjunct and dropping the
# fall-through are different bugs that mis-file the SAME case to DIFFERENT buckets, so a
# single mutant cannot tell them apart and whichever one is written covers for the other.
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
  exit 0
fi
# Print the RESOLVED path. A mutation applied to a copy the run never loads leaves every
# arm green, and that reads exactly like an arm that cannot fire.
echo "  subject: $RECON/preclassify.sh"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/pc-mode.XXXXXX")" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
broken() { printf 'FIXTURE BROKEN: %s\n' "$1" >&2; exit 2; }

# --- the case table --------------------------------------------------------------------
# id | core/git-hooks/<file> | expected base..theirs STATUS | the bucket the FIXED code emits
#
# THE STATUS IS PER-CASE AND ASSERTED, NOT ASSUMED. It was a blanket "every case is M" for
# one release, and a blanket assertion cannot express a second branch -- so the `A` branch
# had no case, no mutant and no assertion while the suite stayed green over it. This column
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
# their mode-matched siblings, and without them a mutant that broke the arm outright would
# score their kill.
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
# classified by the branch this fixture already covered, and the A-branch mutants below
# would then have no subject while still reporting a kill count of zero for the right
# reason and the wrong cause.
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

# vector <reconcile-dir> -> "C1=<bucket> C2=<bucket> ..." for every case, in table order.
# `<none>` when no row was emitted, so an arm demanding a bucket string is PRESENCE-shaped
# and a subject that emits nothing fails it by construction rather than passing quietly.
vector() {
  local dir="$1" out
  out="$(bash "$dir/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null || true)"
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

# sig_with "C1=X;C3=Y" -> the FIXED signature with those cells overridden. Every mutant
# expectation is stated as a DELTA against the case table, so none of them restates the
# table and none can drift away from it.
sig_with() {
  PCMB_TABLE="$CASE_TABLE" PCMB_OV="${1:-}" awk 'BEGIN {
    n = split(ENVIRON["PCMB_TABLE"], rows, "\n")
    m = split(ENVIRON["PCMB_OV"], ovs, ";")
    for (i = 1; i <= m; i++) { k = index(ovs[i], "="); if (k > 1) ov[substr(ovs[i], 1, k-1)] = substr(ovs[i], k+1) }
    s = ""
    for (i = 1; i <= n; i++) {
      if (split(rows[i], c, "|") < 4) continue
      s = s c[1] "=" ((c[1] in ov) ? ov[c[1]] : c[4]) " "
    }
    sub(/ $/, "", s); printf "%s", s
  }'
}

# sig_diff <sig> -> "C1(want X got Y) ..." for the cells that differ from the fixed
# expectation. This is what makes each mutant's kill EXACT in the output, so a reader can
# tell two mutants apart without re-deriving the table.
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
    printf "%s", (o == "" ? "<NOTHING -- this mutant killed no case>" : o)
  }'
}

# cells <sig> <id-prefix> -> just that branch's cells, for the cross-contamination arm.
cells() { printf '%s\n' "$1" | tr ' ' '\n' | grep -E "^$2" | tr '\n' ' '; }

EXPECTED="$(sig_with '')"
NCASES="$(grep -c . <<<"$CASE_TABLE")"

# --- A. THE FIXED SUBJECT, over every arm of both branches -------------------------------
SIG_CLEAN="$(vector "$RECON")"
if [ "$SIG_CLEAN" = "$EXPECTED" ]; then
  ok "A the shipping preclassify.sh buckets all $NCASES cases correctly, across both branches"
else
  bad "A the shipping preclassify.sh mis-buckets $(sig_diff "$SIG_CLEAN")"
  bad "A   expected: $EXPECTED"
  bad "A   got:      $SIG_CLEAN"
fi

# --- the mutation battery -----------------------------------------------------------------
# Every mutant is a COPY of the whole reconcile directory (preclassify.sh reads
# setup-sites.md from `dirname $0`), the mutation is guarded by `cmp -s` so a pattern that
# matched nothing cannot pass as a mutation, and each mutant is driven by ITS OWN path --
# there is no candidate resolution here that could quietly load the unmutated original.
#
# EVERY MUTANT ASSERTS ITS FULL SIGNATURE, not a single cell. Several of these share a wrong
# cell; a single-cell assertion would let one score another's kill, and the signature makes
# each one's damage exact. The distinctness arm at the end proves they are not all measuring
# the same thing, and the cross-contamination arm proves the two branches are separately
# observable rather than covering for each other.

# branch_arm_line <file> <region-anchor-regex> <arm-regex> -> line number of the first line
# INSIDE the named case arm matching <arm-regex>. Each region is anchored on a string that
# appears exactly once in the file and is closed by the arm's own `;;`. Anchoring on a bucket
# name alone would not do, and the containments run three deep: `ALREADY-AT-THEIRS` is also
# emitted by --untangle mode, `UPSTREAM-ONLY` is a prefix of the A branch's
# `UPSTREAM-ONLY-ADD`, and `UPSTREAM-ONLY-ADD` is in turn a prefix of
# `UPSTREAM-ONLY-ADD+SETUP-TOKENS->SUBSTITUTE`. A file-wide sed would edit two arms, move two
# cells and score a kill the mutation did not earn.
branch_arm_line() {
  awk -v anchor="$2" -v re="$3" '
    !inreg && $0 ~ anchor { inreg=1 }
    inreg && /^[[:space:]]*;;[[:space:]]*$/ { exit }
    inreg && $0 ~ re { print NR; exit }
  ' "$1"
}
# `[+]` AND NOT `\+`, because these anchors travel through `awk -v`, WHICH STRIPS ONE LEVEL
# OF ESCAPING. Measured here: `\+` arrives as a bare `+`, the regex then reads `MOD+consumer`
# -- one-or-more `D` followed immediately by `consumer` -- and cannot match the literal `+`
# in its own subject. Both anchors returned nothing while looking correct. A bracket class
# has no escaping level to lose, so the site reads the same as it behaves.
M_ANCHOR='UPSTREAM-MOD[+]consumer-deleted->CLASSIFY'
A_ANCHOR='UPSTREAM-ONLY-ADD[+]SETUP-TOKENS->SUBSTITUTE'
m_arm_line() { branch_arm_line "$1" "$M_ANCHOR" "$2"; }
a_arm_line() { branch_arm_line "$1" "$A_ANCHOR" "$2"; }

# The mode derivation: the ONE `ls-tree` INVOCATION that is not the relocation pass's
# `--name-only` enumerator. Anchored on what SEPARATES the two, and on the invocation, never
# on a line that merely NAMES it. The header prose above the mode helper mentions
# `git ls-tree` twice, and a grammar that cannot tell a comment from a call mutates a
# comment, changes nothing, and reads as a mutant that killed nothing.
mode_ls_line() {
  awk '/^[[:space:]]*#/ { next } /git -C .* ls-tree/ && !/--name-only/ { print NR; exit }' "$1"
}

mkcopy() { rm -rf "$1"; cp -R "$RECON" "$1" || broken "cp -R of the reconcile dir failed"; }
del_line() {  # del_line <file> <n>
  awk -v n="$2" 'NR!=n' "$1" > "$1.new" && mv "$1.new" "$1" || broken "line deletion failed on $1"
}
swap_lines() { # swap_lines <file> <n1> <n2>
  awk -v n1="$2" -v n2="$3" '{L[NR]=$0} END{for(i=1;i<=NR;i++){ if(i==n1) print L[n2]; else if(i==n2) print L[n1]; else print L[i] }}' \
    "$1" > "$1.new" && mv "$1.new" "$1" || broken "line swap failed on $1"
}

LAST_SIG=""
run_mutant() { # run_mutant <id> <label> <dir> <expected-sig>   -> sets LAST_SIG
  local id="$1" label="$2" dir="$3" exp="$4" got
  if cmp -s "$RECON/preclassify.sh" "$dir/preclassify.sh"; then
    broken "mutation $id ($label) left preclassify.sh byte-identical -- the pattern matched nothing"
  fi
  bash -n "$dir/preclassify.sh" >/dev/null 2>&1 || broken "mutation $id ($label) produced invalid bash"
  got="$(vector "$dir")"
  LAST_SIG="$got"
  if [ "$got" = "$exp" ]; then
    ok "$id $label -- killed by exactly $(sig_diff "$got")"
  else
    bad "$id $label: the damage is not what this mutation is supposed to cause."
    bad "$id   expected: $exp"
    bad "$id   got:      $got"
  fi
}

# The two mode conjuncts are what this battery mutates. If either is not there, its mutants
# are no-ops on a subject that never had the property -- and a battery of no-ops reads
# exactly like a battery that killed nothing. Say so, loudly, per branch, and fail.
MAAT="$(m_arm_line "$RECON/preclassify.sh" 'bucket=.*ALREADY-AT-THEIRS')"
MBASE="$(m_arm_line "$RECON/preclassify.sh" 'base_h.*bucket=.*UPSTREAM-ONLY')"
AAP="$(a_arm_line "$RECON/preclassify.sh" 'bucket=.*ALREADY-PRESENT')"
AFALL="$(a_arm_line "$RECON/preclassify.sh" 'theirs_h.*bucket="UPSTREAM-ONLY-ADD"')"
MODE_LINE="$(mode_ls_line "$RECON/preclassify.sh")"
BATTERY=yes
if [ -z "$MAAT" ] || [ -z "$MBASE" ] || [ -z "$AAP" ] || [ -z "$AFALL" ] || [ -z "$MODE_LINE" ]; then
  BATTERY=no
  bad "B MUTATION BATTERY NOT RUN: could not locate an arm (M/ALREADY-AT-THEIRS=${MAAT:-none} M/ours_h=base_h=${MBASE:-none} A/ALREADY-PRESENT=${AAP:-none} A/fall-through=${AFALL:-none}) or the mode ls-tree (${MODE_LINE:-none}) in $RECON/preclassify.sh"
elif [ "$MAAT" -ge "$MBASE" ]; then
  BATTERY=no
  bad "B MUTATION BATTERY NOT RUN: the ALREADY-AT-THEIRS arm (line $MAAT) does not precede the \`ours_h = base_h\` arm (line $MBASE) -- the mode-blind arm order is present, or the M branch was restructured"
elif [ "$AAP" -ge "$AFALL" ]; then
  BATTERY=no
  bad "B MUTATION BATTERY NOT RUN: the ALREADY-PRESENT arm (line $AAP) does not precede its \`ours_h = theirs_h\` fall-through (line $AFALL) -- the A branch was restructured"
else
  for _n in "$MAAT M/ALREADY-AT-THEIRS" "$AAP A/ALREADY-PRESENT"; do
    set -- $_n
    if ! grep -q ' && ' <<<"$(sed -n "${1}p" "$RECON/preclassify.sh")"; then
      BATTERY=no
      bad "B MUTATION BATTERY NOT RUN: the $2 arm carries NO mode conjunct. Either the mode-blind bucket defect is present on that branch, or the fix was respelled and this battery no longer reaches it -- assertion A above says which."
    fi
  done
fi

SIG_M0=""; SIG_M1=""; SIG_M2=""; SIG_M3=""; SIG_M4=""
SIG_M5=""; SIG_M6=""; SIG_M7=""; SIG_M8=""; SIG_M9=""

if [ "$BATTERY" = yes ]; then
  # --- M0. the unmutated control ---------------------------------------------------------
  # NECESSARY AND NOT SUFFICIENT: a control asserting "nothing went wrong" passes against a
  # subject replaced by `exit 0`. This one asserts the POSITIVE -- the full expected
  # signature, every cell a specific bucket string -- so silence fails it. M9 drives that
  # home with an actual silent subject.
  M0="$WORK/m0"; mkcopy "$M0"
  cmp -s "$RECON/preclassify.sh" "$M0/preclassify.sh" || broken "the unmutated control copy already differs from the subject"
  SIG_M0="$(vector "$M0")"
  if [ "$SIG_M0" = "$EXPECTED" ]; then
    ok "M0 control: an unmutated COPY of the reconcile dir reproduces the full expected signature"
  else
    bad "M0 control: an unmutated copy does not reproduce the subject's own result -- the harness, not the subject, is what these mutants measure. got: $SIG_M0"
  fi

  # --- M1. M branch: swap ALREADY-AT-THEIRS with the `ours_h = base_h` arm ----------------
  # The arm ORDER is load-bearing on its own. With ALREADY-AT-THEIRS demoted below
  # `ours_h = base_h`, the mode conjunct still exists and still works -- it just never gets
  # asked, because a mode-only delta leaves ours == base as well as ours == theirs.
  M1="$WORK/m1"; mkcopy "$M1"
  _a="$(m_arm_line "$M1/preclassify.sh" 'bucket=.*ALREADY-AT-THEIRS')"
  _b="$(m_arm_line "$M1/preclassify.sh" 'base_h.*bucket=.*UPSTREAM-ONLY')"
  [ -n "$_a" ] && [ -n "$_b" ] && [ "$_a" != "$_b" ] || broken "M1 could not locate two distinct arms to swap (a=${_a:-none} b=${_b:-none})"
  swap_lines "$M1/preclassify.sh" "$_a" "$_b"
  run_mutant M1 "M branch, arm order: ALREADY-AT-THEIRS demoted below \`ours_h = base_h\`" "$M1" \
    "$(sig_with 'C1=UPSTREAM-ONLY;C3=UPSTREAM-ONLY')"
  SIG_M1="$LAST_SIG"

  # --- M2. M branch: delete the mode conjunct ---------------------------------------------
  # This is the NAIVE fix -- ALREADY-AT-THEIRS first, on content alone. It answers C1 and C3
  # correctly and files C2, C4 and C7 as noops while the consumer's bit is still wrong.
  M2="$WORK/m2"; mkcopy "$M2"
  _a="$(m_arm_line "$M2/preclassify.sh" 'bucket=.*ALREADY-AT-THEIRS')"
  MUTLINE="$_a" perl -pi -e 's/ && [^;]*; then/; then/ if $. == $ENV{MUTLINE}' "$M2/preclassify.sh" || broken "M2 perl failed"
  run_mutant M2 "M branch, the mode conjunct DELETED from the ALREADY-AT-THEIRS arm" "$M2" \
    "$(sig_with 'C2=ALREADY-AT-THEIRS;C4=ALREADY-AT-THEIRS;C7=ALREADY-AT-THEIRS')"
  SIG_M2="$LAST_SIG"

  # --- M3. M branch: invert the mode predicate ---------------------------------------------
  M3="$WORK/m3"; mkcopy "$M3"
  _a="$(m_arm_line "$M3/preclassify.sh" 'bucket=.*ALREADY-AT-THEIRS')"
  MUTLINE="$_a" perl -pi -e 's/ && / && ! / if $. == $ENV{MUTLINE}' "$M3/preclassify.sh" || broken "M3 perl failed"
  run_mutant M3 "M branch, the mode predicate INVERTED" "$M3" \
    "$(sig_with 'C1=UPSTREAM-ONLY;C2=ALREADY-AT-THEIRS;C3=UPSTREAM-ONLY;C4=ALREADY-AT-THEIRS;C6=UPSTREAM-ONLY;C7=ALREADY-AT-THEIRS')"
  SIG_M3="$LAST_SIG"

  # --- M4. M branch: the mode check SUCCEEDS unconditionally --------------------------------
  # Mutated at the ARM rather than at the helper, so it holds whether the fix spells the check
  # as a function call or as an inline comparison. It is BEHAVIOURALLY IDENTICAL to M2 -- a
  # conjunct that is always true and a conjunct that is absent are the same branch -- and the
  # arm below ASSERTS that equality rather than tolerating it, so the pair cannot quietly
  # become two mutants measuring one thing by accident.
  M4="$WORK/m4"; mkcopy "$M4"
  _a="$(m_arm_line "$M4/preclassify.sh" 'bucket=.*ALREADY-AT-THEIRS')"
  MUTLINE="$_a" perl -pi -e 's/ && [^;]*; then/ && true; then/ if $. == $ENV{MUTLINE}' "$M4/preclassify.sh" || broken "M4 perl failed"
  run_mutant M4 "M branch, the mode check forced to SUCCEED unconditionally" "$M4" \
    "$(sig_with 'C2=ALREADY-AT-THEIRS;C4=ALREADY-AT-THEIRS;C7=ALREADY-AT-THEIRS')"
  SIG_M4="$LAST_SIG"

  # --- M5. the SHARED helper keyed on BASE instead of THEIRS ---------------------------------
  # The subtlest of the set, and the only mutation that reaches both branches, because both
  # call the same helper. On the M branch the derivation still runs, still reads a real tree
  # and still returns 100644/100755 -- from the wrong ref. On the A branch the file does not
  # exist at base at all, `ls-tree` returns nothing, and the helper's `*) return 0` fires, so
  # the conjunct degenerates to always-true. One edit, two different failure shapes, and it is
  # the reason the cross-contamination arm below has to exempt M5 explicitly.
  M5="$WORK/m5"; mkcopy "$M5"
  _n="$(mode_ls_line "$M5/preclassify.sh")"
  MUTLINE="$_n" perl -pi -e 's/\$THEIRS/\$BASE/g if $. == $ENV{MUTLINE}' "$M5/preclassify.sh" || broken "M5 perl failed"
  run_mutant M5 "both branches, the mode derived from BASE (the consumer's stamp) instead of THEIRS" "$M5" \
    "$(sig_with 'C1=UPSTREAM-ONLY;C2=ALREADY-AT-THEIRS;C3=UPSTREAM-ONLY;C4=ALREADY-AT-THEIRS;C7=ALREADY-AT-THEIRS;A3=ALREADY-PRESENT;A5=ALREADY-PRESENT')"
  SIG_M5="$LAST_SIG"

  # --- M6. THE UNFIXED M BRANCH -- BOTH LAYERS REVERTED ---------------------------------------
  # A partial revert produces a mutant that proves whichever layer was left in place and comes
  # out green, so both go: the conjunct is deleted AND the arms are put back in their original
  # order, reconstructing the M branch as it was before the fix. Its damage is C1, C3 and C7 --
  # and note that is NOT the union of M1's and M2's, which is why neither of those alone
  # establishes that the fixed branch is doing anything.
  M6="$WORK/m6"; mkcopy "$M6"
  _a="$(m_arm_line "$M6/preclassify.sh" 'bucket=.*ALREADY-AT-THEIRS')"
  MUTLINE="$_a" perl -pi -e 's/ && [^;]*; then/; then/ if $. == $ENV{MUTLINE}' "$M6/preclassify.sh" || broken "M6 perl (conjunct) failed"
  _a="$(m_arm_line "$M6/preclassify.sh" 'bucket=.*ALREADY-AT-THEIRS')"
  _b="$(m_arm_line "$M6/preclassify.sh" 'base_h.*bucket=.*UPSTREAM-ONLY')"
  [ -n "$_a" ] && [ -n "$_b" ] && [ "$_a" != "$_b" ] || broken "M6 could not locate two distinct arms to swap after the conjunct was dropped"
  swap_lines "$M6/preclassify.sh" "$_a" "$_b"
  run_mutant M6 "THE UNFIXED M BRANCH (conjunct dropped AND arms reordered)" "$M6" \
    "$(sig_with 'C1=UPSTREAM-ONLY;C3=UPSTREAM-ONLY;C7=ALREADY-AT-THEIRS')"
  SIG_M6="$LAST_SIG"

  # --- M7. THE UNFIXED A BRANCH -- BOTH LAYERS REVERTED ---------------------------------------
  # THE ARM THE UNCOVERED BRANCH SURVIVED. The A half of the same fix is two lines -- a
  # conjunct on ALREADY-PRESENT and an `ours_h = theirs_h -> UPSTREAM-ONLY-ADD` fall-through
  # beneath it -- and reverting BOTH is what the partial-revert rule demands. This reconstructs
  # exactly the state this fixture used to pass over: A3 and A5 filed as noops with their bits
  # still wrong, A2 and A4 (their mode-matched siblings) still correct, and every M case
  # untouched. Those last two facts are what make the kill this arm's rather than a general
  # breakage.
  M7="$WORK/m7"; mkcopy "$M7"
  _a="$(a_arm_line "$M7/preclassify.sh" 'bucket=.*ALREADY-PRESENT')"
  MUTLINE="$_a" perl -pi -e 's/ && [^;]*; then/; then/ if $. == $ENV{MUTLINE}' "$M7/preclassify.sh" || broken "M7 perl (conjunct) failed"
  _f="$(a_arm_line "$M7/preclassify.sh" 'theirs_h.*bucket="UPSTREAM-ONLY-ADD"')"
  [ -n "$_f" ] || broken "M7 could not locate the A-branch fall-through after the conjunct was dropped"
  del_line "$M7/preclassify.sh" "$_f"
  run_mutant M7 "THE UNFIXED A BRANCH (ALREADY-PRESENT conjunct dropped AND its fall-through deleted)" "$M7" \
    "$(sig_with 'A3=ALREADY-PRESENT;A5=ALREADY-PRESENT')"
  SIG_M7="$LAST_SIG"

  # --- M8. A branch: the fall-through alone deleted --------------------------------------------
  # The conjunct and the fall-through are SEPARATE subjects, and one mutant cannot tell them
  # apart -- both mis-file A3 and A5, to DIFFERENT buckets. With the conjunct intact and the
  # fall-through gone, a consumer holding the right bytes at the wrong bit is handed to the
  # semantic classifier as a conflict instead of being applied. Nothing else moves, which is
  # what gives this arm a subject M7 cannot see.
  M8="$WORK/m8"; mkcopy "$M8"
  _f="$(a_arm_line "$M8/preclassify.sh" 'theirs_h.*bucket="UPSTREAM-ONLY-ADD"')"
  [ -n "$_f" ] || broken "M8 could not locate the A-branch fall-through arm"
  del_line "$M8/preclassify.sh" "$_f"
  run_mutant M8 "A branch, the \`ours_h = theirs_h\` fall-through DELETED (conjunct left intact)" "$M8" \
    "$(sig_with 'A3=BOTH-ADDED->CLASSIFY;A5=BOTH-ADDED->CLASSIFY')"
  SIG_M8="$LAST_SIG"

  # --- M9. a subject that emits nothing -----------------------------------------------------------
  # `exit 0` with no output. Every arm above demands a specific bucket STRING, so this must
  # fail every cell -- an absence-shaped arm would have passed it, which is how a battery
  # certifies a program that never ran. The expectation is DERIVED from the table rather than
  # written out, so adding a case cannot leave this mutant asserting a stale width.
  M9="$WORK/m9"; mkcopy "$M9"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$M9/preclassify.sh"
  _silent=""
  while IFS='|' read -r id file st exp; do
    [ -n "$id" ] || continue
    _silent="${_silent}${id}=<none>;"
  done <<<"$CASE_TABLE"
  run_mutant M9 "the subject replaced by \`exit 0\` (emits nothing)" "$M9" "$(sig_with "${_silent%;}")"
  SIG_M9="$LAST_SIG"

  # --- C. NO MUTANT CAN SCORE ANOTHER'S KILL -------------------------------------------------
  # Eight behaviourally distinct signatures from the control and seven mutations. If two
  # collapsed, one of them is not measuring what its label says, and its green reads exactly
  # like a guard the other one was covering for.
  REAL_SIGS="$(printf '%s\n%s\n%s\n%s\n%s\n%s\n%s\n%s\n' \
    "$SIG_M0" "$SIG_M1" "$SIG_M2" "$SIG_M3" "$SIG_M5" "$SIG_M6" "$SIG_M7" "$SIG_M8")"
  DISTINCT="$(printf '%s\n' "$REAL_SIGS" | sort -u | grep -c .)"
  if [ "$DISTINCT" = 8 ]; then
    ok "C the control and seven mutants produce 8 DISTINCT signatures -- none can score another's kill"
  else
    bad "C the control and seven mutants produce only $DISTINCT distinct signatures, expected 8 -- at least two mutations are indistinguishable, so one of them proves nothing"
  fi

  # M4 and M2 are the same branch reached from two places; assert the equality rather than
  # excusing it, so a future change that makes them differ is a finding and not a shrug.
  if [ "$SIG_M4" = "$SIG_M2" ]; then
    ok "C M4 (conjunct forced true) and M2 (conjunct deleted) are identical in effect, as a suppressed conjunct must be"
  else
    bad "C M4 and M2 differ, but forcing the mode conjunct true and deleting it are the same branch -- one of the two mutations is not doing what its label says"
  fi

  # THE TWO BRANCHES MUST BE SEPARATELY OBSERVABLE. Every M mutant must leave the A cells
  # alone and every A mutant must leave the C cells alone. If one branch's arms move the
  # other's cells, the two are covering for each other and a revert of either would still be
  # caught -- which is indistinguishable from both working, and is exactly how the A branch
  # went a release with nothing watching it. M5 is exempt BY CONSTRUCTION and is the only
  # exemption: it mutates the helper both branches share, and its expectation says so above.
  _mcells_clean="$(cells "$EXPECTED" 'C')"; _acells_clean="$(cells "$EXPECTED" 'A')"
  _cross=0
  for _s in "$SIG_M1" "$SIG_M2" "$SIG_M3" "$SIG_M4" "$SIG_M6"; do
    [ "$(cells "$_s" 'A')" = "$_acells_clean" ] || _cross=$((_cross+1))
  done
  for _s in "$SIG_M7" "$SIG_M8"; do
    [ "$(cells "$_s" 'C')" = "$_mcells_clean" ] || _cross=$((_cross+1))
  done
  if [ "$_cross" -eq 0 ]; then
    ok "C the 5 M mutants move no A cell and the 2 A mutants move no C cell -- the branches are separately observable"
  else
    bad "C $_cross mutant(s) moved a cell on the branch they do not mutate -- the two branches' arms are covering for each other"
  fi

  # And the silent subject's signature must not equal any real one.
  if grep -qxF "$SIG_M9" <<<"$REAL_SIGS"; then
    bad "C the silent subject's signature equals a real one -- an arm somewhere is absence-shaped"
  else
    ok "C a subject that emits nothing matches no real signature -- every arm is presence-shaped"
  fi
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "preclassify-mode-bucket: PASS"
  exit 0
fi
echo "preclassify-mode-bucket: FAIL ($fails assertion(s))"
exit 1
