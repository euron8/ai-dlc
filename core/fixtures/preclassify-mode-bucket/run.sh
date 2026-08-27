#!/usr/bin/env bash
# preclassify-mode-bucket — the M/rename branch must bucket on the consumer's EXEC BIT,
# not on content alone, and must not collapse the two mode-only cases into one.
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
# NOTHING HERE RE-IMPLEMENTS THE BRANCH. Every assertion drives the shipping
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
# id | core/git-hooks/<file> | the bucket the FIXED branch must emit
#
# C1/C2 are the gain pair and C3/C4 the drop pair: within each pair base and theirs hold
# the SAME BLOB and differ only in mode, and the two members differ only in the consumer's
# exec bit. C7 is the arm with no mode-only twin -- content already at theirs, bit still
# wrong -- and it is the case a fix that merely reordered arms silently mis-files.
CASE_TABLE='C1|gain-consumer-755.sh|ALREADY-AT-THEIRS
C2|gain-consumer-644.sh|UPSTREAM-ONLY
C3|drop-consumer-644.sh|ALREADY-AT-THEIRS
C4|drop-consumer-755.sh|UPSTREAM-ONLY
C5|content-at-base.sh|UPSTREAM-ONLY
C6|content-at-theirs.sh|ALREADY-AT-THEIRS
C7|content-at-theirs-wrong-mode.sh|UPSTREAM-ONLY
C8|both-changed.sh|BOTH-CHANGED->CLASSIFY
C9|consumer-deleted.sh|UPSTREAM-MOD+consumer-deleted->CLASSIFY'

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

# base
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
# bytes; C7 changes bytes AND gains the bit.
chmod 755 "$(gh gain-consumer-755.sh)" "$(gh gain-consumer-644.sh)"
chmod 644 "$(gh drop-consumer-644.sh)" "$(gh drop-consumer-755.sh)"
w content-at-base.sh              c5-theirs; chmod 644 "$(gh content-at-base.sh)"
w content-at-theirs.sh            c6-theirs; chmod 644 "$(gh content-at-theirs.sh)"
w content-at-theirs-wrong-mode.sh c7-theirs; chmod 755 "$(gh content-at-theirs-wrong-mode.sh)"
w both-changed.sh                 c8-theirs; chmod 644 "$(gh both-changed.sh)"
w consumer-deleted.sh             c9-theirs; chmod 644 "$(gh consumer-deleted.sh)"
printf '2.0.0\n' > "$DIST/VERSION"
gitc add -A >/dev/null 2>&1 && gitc commit -q -m theirs >/dev/null 2>&1 || broken "theirs commit failed"
THEIRS="$(git -C "$DIST" rev-parse HEAD)"

# --- S1. THE TREE ACTUALLY CARRIES THE DELTA THE FIXTURE IS ABOUT ----------------------
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
ok "S1 the synthetic tree carries a real mode-only delta in BOTH directions, same blob either side"

# --- S2. every case is in the base..theirs diff, with status M -------------------------
# A mode-only change git did not report would make C1-C4 silently absent from preclassify's
# input, and an absent row reads as "no finding" in every arm below.
DIFF="$(git -C "$DIST" diff --name-status "$BASE" "$THEIRS" -- core/)"
while IFS='|' read -r id file exp; do
  [ -n "$id" ] || continue
  st="$(printf '%s\n' "$DIFF" | awk -F'\t' -v p="core/git-hooks/$file" '$2==p{print $1}')"
  case "$st" in
    M*) : ;;
    *)  broken "$id ($file) has diff status '${st:-<absent>}', not M -- the M/rename branch never sees it" ;;
  esac
done <<<"$CASE_TABLE"
ok "S2 all 9 cases reach the M/rename branch (status M in base..theirs)"

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
# C9 is deliberately absent from the consumer.
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$CONS/.claude/.ai-dlc-version"

# --- S3. the consumer's exec bits are what the case table says -------------------------
for _p in "gain-consumer-755.sh x" "gain-consumer-644.sh -" "drop-consumer-644.sh -" \
          "drop-consumer-755.sh x" "content-at-theirs-wrong-mode.sh -"; do
  set -- $_p
  if [ "$2" = x ]; then
    [ -x "$CONS/.githooks/$1" ] || broken "consumer $1 is not executable -- chmod did not take on this filesystem"
  else
    [ ! -x "$CONS/.githooks/$1" ] || broken "consumer $1 IS executable -- chmod did not take on this filesystem"
  fi
done
[ -e "$CONS/.githooks/consumer-deleted.sh" ] && broken "C9 must be absent from the consumer"
ok "S3 the consumer's exec bits are as the case table declares"

# --- driving the subject ----------------------------------------------------------------
# vector <reconcile-dir> -> "C1=<bucket> C2=<bucket> ..." for every case, in table order.
# `<none>` when no row was emitted, so an arm demanding a bucket string is PRESENCE-shaped
# and a subject that emits nothing fails it by construction rather than passing quietly.
vector() {
  local dir="$1" out sig id file exp b
  out="$(bash "$dir/preclassify.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null || true)"
  sig=""
  while IFS='|' read -r id file exp; do
    [ -n "$id" ] || continue
    b="$(printf '%s\n' "$out" | awk -F'\t' -v p="core/git-hooks/$file" '$2==p{print $4}')"
    sig="${sig}${id}=${b:-<none>} "
  done <<<"$CASE_TABLE"
  printf '%s' "${sig% }"
}

# sig_with "C1=X;C3=Y" -> the FIXED signature with those cells overridden. Every mutant
# expectation is stated as a DELTA against the case table, so none of them restates the
# table and none can drift away from it.
sig_with() {
  local ov="${1:-}" sig="" id file exp new
  while IFS='|' read -r id file exp; do
    [ -n "$id" ] || continue
    new="$(printf '%s\n' "$ov" | tr ';' '\n' | awk -F= -v i="$id" '$1==i{print $2}')"
    sig="${sig}${id}=${new:-$exp} "
  done <<<"$CASE_TABLE"
  printf '%s' "${sig% }"
}

# sig_diff <sig> -> "C1(want X got Y) ..." for the cells that differ from the fixed
# expectation. This is what makes each mutant's kill EXACT in the output, so a reader can
# tell two mutants apart without re-deriving the table.
sig_diff() {
  local sig="$1" out="" id file exp g
  while IFS='|' read -r id file exp; do
    [ -n "$id" ] || continue
    g="$(printf '%s\n' "$sig" | tr ' ' '\n' | awk -F= -v i="$id" '$1==i{print $2}')"
    [ "$g" = "$exp" ] || out="${out}${id}(want $exp got $g) "
  done <<<"$CASE_TABLE"
  printf '%s' "${out:-<NOTHING -- this mutant killed no case>}"
}

EXPECTED="$(sig_with '')"

# --- A. THE FIXED SUBJECT, over every arm of the branch ---------------------------------
SIG_CLEAN="$(vector "$RECON")"
if [ "$SIG_CLEAN" = "$EXPECTED" ]; then
  ok "A the shipping preclassify.sh buckets all 9 cases correctly"
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
# EVERY MUTANT ASSERTS ITS FULL 9-CELL SIGNATURE, not a single cell. Several of these share
# a wrong cell; a single-cell assertion would let one score another's kill, and the
# signature makes each one's damage exact. The distinctness arm at the end proves they are
# not all measuring the same thing.

# m_arm_line <file> <regex> -> line number of the first line INSIDE the M/rename case arm
# matching <regex>. The region is anchored on `UPSTREAM-MOD+consumer-deleted->CLASSIFY`,
# which appears exactly once in the file, and closed by the arm's own `;;`. Anchoring on a
# bucket name alone would not do: `ALREADY-AT-THEIRS` is also emitted by --untangle mode
# and `UPSTREAM-ONLY` is a prefix of the A-branch's `UPSTREAM-ONLY-ADD`, so a file-wide sed
# would edit two arms, move two cells and score a kill the mutation did not earn.
m_arm_line() {
  awk -v re="$2" '
    !inreg && /UPSTREAM-MOD\+consumer-deleted->CLASSIFY/ { inreg=1 }
    inreg && /^[[:space:]]*;;[[:space:]]*$/ { exit }
    inreg && $0 ~ re { print NR; exit }
  ' "$1"
}
# The mode derivation: the ONE `ls-tree` INVOCATION that is not the relocation pass's
# `--name-only` enumerator. Anchored on what SEPARATES the two, not on the `ls-tree` they
# share -- and on the invocation, never on a line that merely NAMES it. The header prose
# above the mode helper mentions `git ls-tree` twice, and a grammar that cannot tell a
# comment from a call mutates a comment, changes nothing, and reads as a mutant that
# killed nothing.
mode_ls_line() {
  awk '/^[[:space:]]*#/ { next } /git -C .* ls-tree/ && !/--name-only/ { print NR; exit }' "$1"
}

mkcopy() { rm -rf "$1"; cp -R "$RECON" "$1" || broken "cp -R of the reconcile dir failed"; }

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

# The fix's mode conjunct is what the whole battery mutates. If it is not there, every
# mutation below is a no-op on a subject that never had the property -- and a battery of
# no-ops reads exactly like a battery that killed nothing. Say so, loudly, and fail.
AAT_LINE="$(m_arm_line "$RECON/preclassify.sh" 'bucket=.*ALREADY-AT-THEIRS')"
BASE_LINE="$(m_arm_line "$RECON/preclassify.sh" 'base_h.*bucket=.*UPSTREAM-ONLY')"
MODE_LINE="$(mode_ls_line "$RECON/preclassify.sh")"
BATTERY=yes
if [ -z "$AAT_LINE" ] || [ -z "$BASE_LINE" ] || [ -z "$MODE_LINE" ]; then
  BATTERY=no
  bad "B MUTATION BATTERY NOT RUN: could not locate the M-branch arms (ALREADY-AT-THEIRS=${AAT_LINE:-none} ours_h=base_h=${BASE_LINE:-none}) or the mode ls-tree (${MODE_LINE:-none}) in $RECON/preclassify.sh"
elif [ "$AAT_LINE" -ge "$BASE_LINE" ]; then
  BATTERY=no
  bad "B MUTATION BATTERY NOT RUN: the ALREADY-AT-THEIRS arm (line $AAT_LINE) does not precede the \`ours_h = base_h\` arm (line $BASE_LINE) -- the mode-blind arm order is present, or the branch was restructured"
elif ! grep -q ' && ' <<<"$(sed -n "${AAT_LINE}p" "$RECON/preclassify.sh")"; then
  BATTERY=no
  bad "B MUTATION BATTERY NOT RUN: the ALREADY-AT-THEIRS arm carries NO mode conjunct. Either the mode-blind bucket defect is present, or the fix was respelled and this battery no longer reaches it -- assertion A above says which."
fi

SIG_M0=""; SIG_M1=""; SIG_M2=""; SIG_M3=""; SIG_M4=""; SIG_M5=""; SIG_M6=""; SIG_M7=""

if [ "$BATTERY" = yes ]; then
  # --- M0. the unmutated control ---------------------------------------------------------
  # NECESSARY AND NOT SUFFICIENT: a control asserting "nothing went wrong" passes against a
  # subject replaced by `exit 0`. This one asserts the POSITIVE -- the full expected
  # signature, every cell a specific bucket string -- so silence fails it. M8 drives that
  # home with an actual silent subject.
  M0="$WORK/m0"; mkcopy "$M0"
  cmp -s "$RECON/preclassify.sh" "$M0/preclassify.sh" || broken "the unmutated control copy already differs from the subject"
  SIG_M0="$(vector "$M0")"
  if [ "$SIG_M0" = "$EXPECTED" ]; then
    ok "M0 control: an unmutated COPY of the reconcile dir reproduces the full expected signature"
  else
    bad "M0 control: an unmutated copy does not reproduce the subject's own result -- the harness, not the subject, is what these mutants measure. got: $SIG_M0"
  fi

  # --- M1. swap the ALREADY-AT-THEIRS arm with the `ours_h = base_h` arm -----------------
  # The arm ORDER is load-bearing on its own. With ALREADY-AT-THEIRS demoted below
  # `ours_h = base_h`, the mode conjunct still exists and still works -- it just never gets
  # asked, because a mode-only delta leaves ours == base as well as ours == theirs.
  M1="$WORK/m1"; mkcopy "$M1"
  _a="$(m_arm_line "$M1/preclassify.sh" 'bucket=.*ALREADY-AT-THEIRS')"
  _b="$(m_arm_line "$M1/preclassify.sh" 'base_h.*bucket=.*UPSTREAM-ONLY')"
  [ -n "$_a" ] && [ -n "$_b" ] && [ "$_a" != "$_b" ] || broken "M1 could not locate two distinct arms to swap (a=${_a:-none} b=${_b:-none})"
  awk -v n1="$_a" -v n2="$_b" '{L[NR]=$0} END{for(i=1;i<=NR;i++){ if(i==n1) print L[n2]; else if(i==n2) print L[n1]; else print L[i] }}' \
    "$M1/preclassify.sh" > "$M1/pc.new" && mv "$M1/pc.new" "$M1/preclassify.sh" || broken "M1 rewrite failed"
  run_mutant M1 "arm order: ALREADY-AT-THEIRS demoted below \`ours_h = base_h\`" "$M1" \
    "$(sig_with 'C1=UPSTREAM-ONLY;C3=UPSTREAM-ONLY')"
  SIG_M1="$LAST_SIG"

  # --- M2. delete the mode conjunct --------------------------------------------------------
  # This is the NAIVE fix -- ALREADY-AT-THEIRS first, on content alone. It answers C1 and C3
  # correctly and files C2, C4 and C7 as noops while the consumer's bit is still wrong.
  M2="$WORK/m2"; mkcopy "$M2"
  _a="$(m_arm_line "$M2/preclassify.sh" 'bucket=.*ALREADY-AT-THEIRS')"
  MUTLINE="$_a" perl -pi -e 's/ && [^;]*; then/; then/ if $. == $ENV{MUTLINE}' "$M2/preclassify.sh" || broken "M2 perl failed"
  run_mutant M2 "the mode conjunct DELETED from the ALREADY-AT-THEIRS arm" "$M2" \
    "$(sig_with 'C2=ALREADY-AT-THEIRS;C4=ALREADY-AT-THEIRS;C7=ALREADY-AT-THEIRS')"
  SIG_M2="$LAST_SIG"

  # --- M3. invert the mode predicate --------------------------------------------------------
  M3="$WORK/m3"; mkcopy "$M3"
  _a="$(m_arm_line "$M3/preclassify.sh" 'bucket=.*ALREADY-AT-THEIRS')"
  MUTLINE="$_a" perl -pi -e 's/ && / && ! / if $. == $ENV{MUTLINE}' "$M3/preclassify.sh" || broken "M3 perl failed"
  run_mutant M3 "the mode predicate INVERTED" "$M3" \
    "$(sig_with 'C1=UPSTREAM-ONLY;C2=ALREADY-AT-THEIRS;C3=UPSTREAM-ONLY;C4=ALREADY-AT-THEIRS;C6=UPSTREAM-ONLY;C7=ALREADY-AT-THEIRS')"
  SIG_M3="$LAST_SIG"

  # --- M4. the mode check SUCCEEDS unconditionally ------------------------------------------
  # Mutated at the ARM rather than at the helper, so it holds whether the fix spells the
  # check as a function call or as an inline comparison. It is BEHAVIOURALLY IDENTICAL to M2
  # -- a conjunct that is always true and a conjunct that is absent are the same branch --
  # and the arm below ASSERTS that equality rather than tolerating it, so the pair cannot
  # quietly become two mutants measuring one thing by accident.
  M4="$WORK/m4"; mkcopy "$M4"
  _a="$(m_arm_line "$M4/preclassify.sh" 'bucket=.*ALREADY-AT-THEIRS')"
  MUTLINE="$_a" perl -pi -e 's/ && [^;]*; then/ && true; then/ if $. == $ENV{MUTLINE}' "$M4/preclassify.sh" || broken "M4 perl failed"
  run_mutant M4 "the mode check forced to SUCCEED unconditionally" "$M4" \
    "$(sig_with 'C2=ALREADY-AT-THEIRS;C4=ALREADY-AT-THEIRS;C7=ALREADY-AT-THEIRS')"
  SIG_M4="$LAST_SIG"

  # --- M5. the mode derived from the consumer's stamp (BASE) instead of THEIRS --------------
  # The subtlest of the set: the derivation still runs, still reads a real tree, still
  # returns 100644/100755 -- from the wrong ref. It answers every case where base and theirs
  # share a mode, which is most of a real pull, and inverts exactly the ones the branch
  # exists for.
  M5="$WORK/m5"; mkcopy "$M5"
  _n="$(mode_ls_line "$M5/preclassify.sh")"
  MUTLINE="$_n" perl -pi -e 's/\$THEIRS/\$BASE/g if $. == $ENV{MUTLINE}' "$M5/preclassify.sh" || broken "M5 perl failed"
  run_mutant M5 "the mode derived from BASE (the consumer's stamp) instead of THEIRS" "$M5" \
    "$(sig_with 'C1=UPSTREAM-ONLY;C2=ALREADY-AT-THEIRS;C3=UPSTREAM-ONLY;C4=ALREADY-AT-THEIRS;C7=ALREADY-AT-THEIRS')"
  SIG_M5="$LAST_SIG"

  # --- M6. THE UNFIXED SUBJECT -- BOTH LAYERS OF THE FIX REVERTED ------------------------------
  # THIS IS THE ARM THAT MATTERS. A partial revert produces a mutant that proves whichever
  # layer was left in place and comes out green, so both go: the conjunct is deleted AND the
  # arms are put back in their original order, reconstructing the branch as it was before the
  # fix. Its damage is C1, C3 and C7 -- and note that is NOT the union of M1's and M2's, which
  # is why neither of those alone establishes that the fixed branch is doing anything.
  M6="$WORK/m6"; mkcopy "$M6"
  _a="$(m_arm_line "$M6/preclassify.sh" 'bucket=.*ALREADY-AT-THEIRS')"
  MUTLINE="$_a" perl -pi -e 's/ && [^;]*; then/; then/ if $. == $ENV{MUTLINE}' "$M6/preclassify.sh" || broken "M6 perl (conjunct) failed"
  _a="$(m_arm_line "$M6/preclassify.sh" 'bucket=.*ALREADY-AT-THEIRS')"
  _b="$(m_arm_line "$M6/preclassify.sh" 'base_h.*bucket=.*UPSTREAM-ONLY')"
  [ -n "$_a" ] && [ -n "$_b" ] && [ "$_a" != "$_b" ] || broken "M6 could not locate two distinct arms to swap after the conjunct was dropped"
  awk -v n1="$_a" -v n2="$_b" '{L[NR]=$0} END{for(i=1;i<=NR;i++){ if(i==n1) print L[n2]; else if(i==n2) print L[n1]; else print L[i] }}' \
    "$M6/preclassify.sh" > "$M6/pc.new" && mv "$M6/pc.new" "$M6/preclassify.sh" || broken "M6 rewrite failed"
  run_mutant M6 "THE UNFIXED BRANCH (conjunct dropped AND arms reordered)" "$M6" \
    "$(sig_with 'C1=UPSTREAM-ONLY;C3=UPSTREAM-ONLY;C7=ALREADY-AT-THEIRS')"
  SIG_M6="$LAST_SIG"

  # --- M7. a subject that emits nothing ---------------------------------------------------------
  # `exit 0` with no output. Every arm above demands a specific bucket STRING, so this must
  # fail all nine cells -- an absence-shaped arm would have passed it, which is how a battery
  # certifies a program that never ran.
  M7="$WORK/m7"; mkcopy "$M7"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$M7/preclassify.sh"
  run_mutant M7 "the subject replaced by \`exit 0\` (emits nothing)" "$M7" \
    "$(sig_with 'C1=<none>;C2=<none>;C3=<none>;C4=<none>;C5=<none>;C6=<none>;C7=<none>;C8=<none>;C9=<none>')"
  SIG_M7="$LAST_SIG"

  # --- C. NO MUTANT CAN SCORE ANOTHER'S KILL -------------------------------------------------
  # Six behaviourally distinct signatures from the control and five mutations. If two
  # collapsed, one of them is not measuring what its label says, and its green reads exactly
  # like a guard the other one was covering for.
  REAL_SIGS="$(printf '%s\n%s\n%s\n%s\n%s\n%s\n' \
    "$SIG_M0" "$SIG_M1" "$SIG_M2" "$SIG_M3" "$SIG_M5" "$SIG_M6")"
  DISTINCT="$(printf '%s\n' "$REAL_SIGS" | sort -u | grep -c .)"
  if [ "$DISTINCT" = 6 ]; then
    ok "C the control and five mutants produce 6 DISTINCT signatures -- none can score another's kill"
  else
    bad "C the control and five mutants produce only $DISTINCT distinct signatures, expected 6 -- at least two mutations are indistinguishable, so one of them proves nothing"
  fi

  # M4 and M2 are the same branch reached from two places; assert the equality rather than
  # excusing it, so a future change that makes them differ is a finding and not a shrug.
  if [ "$SIG_M4" = "$SIG_M2" ]; then
    ok "C M4 (conjunct forced true) and M2 (conjunct deleted) are identical in effect, as a suppressed conjunct must be"
  else
    bad "C M4 and M2 differ, but forcing the mode conjunct true and deleting it are the same branch -- one of the two mutations is not doing what its label says"
  fi

  # And the silent subject's signature must not equal any real one.
  if grep -qxF "$SIG_M7" <<<"$REAL_SIGS"; then
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
