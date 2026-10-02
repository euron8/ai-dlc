#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# push-drain-refusals — step 8's push_candidate drain honours the distribution's refusal record.
#
# Usage: run.sh
# Exit:  0 = every arm holds and every mutant is killed, OR the reader is absent (PENDING line);
#        1 = the reader regressed; 2 = fixture broken.
#
# THE SUBJECT is reconcile/push-drain.sh, in either layout (core/skills/ai-dlc-update/ in the
# distribution, .claude/skills/ai-dlc-update/ on a consumer). It splits every extension whose
# FRONTMATTER says `push_candidate: true` into ##/### blocks and emits PUSH-REFUSED or
# PUSH-CANDIDATE per block, joined on a digest of the block's own text against
# push-refusals.tsv read AT THEIRS through git. Before it existed the drain was prose, nothing
# read a standing verdict, and every pull re-proposed blocks the distribution had already
# declined — the reference consumer's implementation-push ledger row could never close.
#
# WHAT A WRONG READER LOOKS LIKE, and the arm that owns each. The join must be on the block's
# CONTENT: keyed on the heading, the file, the file plus heading or the file plus position, it
# refuses a changed proposal under an old title or loses a refusal when a block moves. Each of
# those keyings is a committed mutant below (M1, M5, M6, M7), built so the mutant SEEDS its own
# record through its own --digest — a mutant that is internally consistent can only be caught by
# the arm that discriminates its keying, not by a seed it cannot reproduce.
#
# WHEN THE READER IS ABSENT this prints a PENDING verdict line and exits 0. A core fixture ships
# ahead of its subject on a consumer pull, so absence is expected for one pull; the line says in
# words that nothing was checked, because exit 0 alone reads exactly like a pass.
set -uo pipefail

# HERMETIC -- scrub the operator's tuning before invoking anything (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# The seam above already does this; restated so a fixture-local edit cannot lose it before the
# first reader call, which runs git against a scratch dist.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

broken() { echo "FIXTURE BROKEN: push-drain-refusals -- $1" >&2; echo "FAIL  push-drain-refusals -- fixture broken: $1"; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd)" || broken "cannot resolve the fixture directory"

# Root by walking up for a marker, never by counting hops (both layouts, and a worktree).
pdr_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
ROOT="$(pdr_root "$(dirname "$HERE")")" || broken "no repo root above $HERE"

RD=""
for _c in "$ROOT/core/skills/ai-dlc-update/reconcile/push-drain.sh" \
          "$ROOT/.claude/skills/ai-dlc-update/reconcile/push-drain.sh"; do
  if [ -f "$_c" ]; then RD="$_c"; break; fi
done
if [ -z "$RD" ]; then
  echo "PENDING  push-drain-refusals -- reconcile/push-drain.sh is absent from both layouts under $ROOT (core/skills/ai-dlc-update/ and .claude/skills/ai-dlc-update/). NOTHING WAS CHECKED; this is not a pass. It clears on the pull that delivers the reader."
  exit 0
fi
command -v git >/dev/null 2>&1    || broken "no git on PATH"
command -v shasum >/dev/null 2>&1 || broken "no shasum on PATH"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/push-drain-refusals.XXXXXX")" || broken "mktemp failed"
trap 'case "$WORK" in */push-drain-refusals.*) rm -rf "$WORK" ;; esac' EXIT

RECREL="core/skills/ai-dlc-update/reconcile/push-refusals.tsv"
EXTREL=".claude/skills/ai-dlc/extensions"
X="$EXTREL/steps-domain"
TAB="$(printf '\t')"

# has_row <out> <status> <rel> <idx|*> <digest|*> <heading>  -- exact field match on one row.
has_row() {
  LC_ALL=C awk -F'\t' -v s="$2" -v r="$3" -v i="$4" -v d="$5" -v h="$6" '
    $1 == s && $2 == r && (i == "*" || $3 == i) && (d == "*" || $4 == d) && $5 == h { f = 1 }
    END { exit (f ? 0 : 1) }' "$1"
}
# field_of <out> <rel> <idx> <field#>
field_of() { LC_ALL=C awk -F'\t' -v r="$2" -v i="$3" -v k="$4" '$2 == r && $3 == i { print $k; exit }' "$1"; }
rows_for() { LC_ALL=C awk -F'\t' -v r="$2" '$2 == r { n++ } END { print n + 0 }' "$1"; }

CUR=""
chk() { # chk <arm-id> <text> <command...>  -- ok when the command exits 0
  local id="$1" t="$2"; shift 2
  if "$@"; then echo "ok    $id  $t" >> "$CUR"; else echo "FAIL  $id  $t" >> "$CUR"; fi
}
dg() { # dg <reader> <file> <heading> -- that block's digest per the reader's own --digest
  local o
  o="$(bash "$1" --digest "$2" 2>/dev/null)" || return 1
  LC_ALL=C awk -F'\t' -v h="$3" '$3 == h { print $2; exit }' <<<"$o"
}
gcommit() { git -C "$1" -c user.email=f@f -c user.name=f -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -qam "$2" >/dev/null 2>&1; }

# drive <reader> <world-dir> -- builds a fresh world, runs every arm, writes <world>/arms.
# Returns 2 when the world itself could not be built (never a verdict about the reader).
drive() {
  local R="$1" W="$2" C E D dA dC dD good mal dup rc O
  mkdir -p "$W/dist/core/skills/ai-dlc-update/reconcile" "$W/c/$X" "$W/c/$EXTREL/checks" || return 2
  CUR="$W/arms"; : > "$CUR" || return 2
  C="$(cd "$W/c" && pwd)" || return 2
  E="$C/$X"; D="$W/dist"; O="$W/out"

  # The discriminating member is NOT first: a-first sorts ahead of every steps-domain file.
  printf -- '---\nid: a-first\npush_candidate: true\n---\n\n## P first candidate\n\npi body.\n' > "$C/$EXTREL/checks/a-first.md"
  printf -- '---\nid: b-off\npush_candidate: false\n---\n\n## Q example\n\nA prose example of the flag follows.\npush_candidate: true\n' > "$E/b-off.md"
  printf -- '---\r\nid: c-crlf\r\npush_candidate: true\r\n---\r\n\r\n## R crlf block\r\n\r\nrho body.\r\n' > "$E/c-crlf.md"
  printf -- '---\nid: g-push\npush_candidate: true\n---\n\n## Group\n\n## F member\n\nphi body.\n' > "$E/g-push.md"
  printf -- '---\nid: h-push\npush_candidate: true\n---\n\n## F member\n\nphi body.\n' > "$E/h-push.md"
  printf -- '---\nid: m-push\npush_candidate: true\n---\n\n## D moved\n\ndelta body.\n' > "$E/m-push.md"
  printf -- '---\nid: w-push\npush_candidate: true\n---\n\n## C kept title\n\ngamma body one.\n' > "$E/w-push.md"
  printf -- '---\nid: x-push\npush_candidate: true\n---\n\n## A refused\n\nalpha body one.\n\n## B unnamed\n\nbeta body two.\n' > "$E/x-push.md"
  printf -- '---\nid: y-push\npush_candidate: true\n---\n\n## A refused\n\nalpha body OTHER.\n' > "$E/y-push.md"
  printf -- '---\nid: z-off\npush_candidate: false\n---\n\n## A refused\n\nalpha body one.\n' > "$E/z-off.md"

  # Seed the record through the subject's own --digest, the record's only producer, from the
  # VERSION 1 of w-push and m-push; then move both to version 2 before any drain.
  dA="$(dg "$R" "$E/x-push.md" "## A refused")"
  dC="$(dg "$R" "$E/w-push.md" "## C kept title")"
  dD="$(dg "$R" "$E/m-push.md" "## D moved")"
  [ -n "$dA" ] && [ -n "$dC" ] && [ -n "$dD" ] || return 2
  printf '%s\n' "$dA" "$dC" "$dD" > "$W/.digests"
  printf -- '---\nid: w-push\npush_candidate: true\n---\n\n## C kept title\n\ngamma body TWO.\n' > "$E/w-push.md"
  printf -- '---\nid: m-push\npush_candidate: true\n---\n\n## E new\n\nepsilon body.\n\n## D moved\n\ndelta body.\n' > "$E/m-push.md"

  printf '# refusal record\n\n%s\tx-push\tseeded refusal A\n%s\tw-push\tseeded refusal C v1\n%s\tm-push\tseeded refusal D\n' \
    "$dA" "$dC" "$dD" > "$W/rec.good"
  { cat "$W/rec.good"; printf 'not-a-digest\tx-push\tmalformed\n'; } > "$W/rec.mal"
  { cat "$W/rec.good"; printf '%s\tdup\tsecond row for A\n' "$dA"; } > "$W/rec.dup"
  cp "$W/rec.good" "$D/$RECREL" || return 2
  git -C "$D" init -q >/dev/null 2>&1 || return 2
  git -C "$D" add -A >/dev/null 2>&1 || return 2
  gcommit "$D" good || return 2
  good="$(git -C "$D" rev-parse HEAD)" || return 2
  cp "$W/rec.mal" "$D/$RECREL" && gcommit "$D" mal || return 2
  mal="$(git -C "$D" rev-parse HEAD)" || return 2
  cp "$W/rec.dup" "$D/$RECREL" && gcommit "$D" dup || return 2
  dup="$(git -C "$D" rev-parse HEAD)" || return 2
  printf '%s\n' "$good" > "$W/.ref.good"; printf '%s\n' "$mal" > "$W/.ref.mal"; printf '%s\n' "$dup" > "$W/.ref.dup"
  # The working tree holds the record of whichever ref is being read, so a reader of the WORKING
  # TREE fails only the arm built to separate the two (A10).
  cp "$W/rec.good" "$D/$RECREL" || return 2

  # ---- A0: cwd-invariance, and the main run.
  rc=0; (cd / && bash "$R" "$D" "$good" "$C") > "$O" 2> "$W/err" || rc=$?
  local rc2=0; (cd "$HERE" && bash "$R" "$D" "$good" "$C") > "$W/out.here" 2>/dev/null || rc2=$?
  chk A0 "the main run exits 0 with rows, byte-identical driven from / and from the fixture dir" \
    eval '[ "$rc" -eq 0 ] && [ "$rc2" -eq 0 ] && [ -s "$O" ] && cmp -s "$O" "$W/out.here"'

  chk A1 "refused -> refused: x-push block 1 reads PUSH-REFUSED with the recorded digest" \
    has_row "$O" PUSH-REFUSED "$X/x-push.md" 1 "$dA" "## A refused"
  chk A2 "unnamed -> candidate: x-push block 2 reads PUSH-CANDIDATE" \
    has_row "$O" PUSH-CANDIDATE "$X/x-push.md" 2 "*" "## B unnamed"
  chk A3 "same file, same heading, changed body -> candidate (w-push v2)" \
    has_row "$O" PUSH-CANDIDATE "$X/w-push.md" 1 "*" "## C kept title"
  chk A3b "other file, same heading, other body -> candidate (y-push)" \
    has_row "$O" PUSH-CANDIDATE "$X/y-push.md" 1 "*" "## A refused"
  chk A4 "refused block moved to index 2 stays refused; the new block 1 is a candidate" \
    eval 'has_row "$O" PUSH-REFUSED "$X/m-push.md" 2 "$dD" "## D moved" && has_row "$O" PUSH-CANDIDATE "$X/m-push.md" 1 "*" "## E new"'
  chk A5 "no recorded digest appears on any PUSH-CANDIDATE row (and rows exist)" \
    eval '[ -s "$O" ] && ! LC_ALL=C awk -F"\t" "NR==FNR{r[\$1]=1;next} \$1==\"PUSH-CANDIDATE\" && (\$4 in r){f=1} END{exit !f}" "$W/.digests" "$O"'
  chk A6 "push_candidate: false file is ignored (z-off carries a refused block and emits no row)" \
    eval '[ "$(rows_for "$O" "$X/z-off.md")" -eq 0 ] && [ "$(rows_for "$O" "$X/x-push.md")" -eq 2 ]'
  chk A7 "a body line push_candidate: true in a false file is ignored (b-off)" \
    eval '[ "$(rows_for "$O" "$X/b-off.md")" -eq 0 ] && [ -s "$O" ]'
  chk A8 "a CRLF candidate is found, its heading CR-free" \
    has_row "$O" PUSH-CANDIDATE "$X/c-crlf.md" 1 "*" "## R crlf block"
  chk A9 "exact row count 10, first row from the first-sorting file" \
    eval '[ "$(grep -c . "$O" || true)" -eq 10 ] && [ "$(LC_ALL=C awk -F"\t" "NR==1{print \$2}" "$O")" = "$EXTREL/checks/a-first.md" ]'
  chk A16 "a group heading merges into the next block, labelled with the FIRST heading, digesting differently from the member alone" \
    eval '[ "$(rows_for "$O" "$X/g-push.md")" -eq 1 ] && has_row "$O" PUSH-CANDIDATE "$X/g-push.md" 1 "*" "## Group" && [ -n "$(field_of "$O" "$X/g-push.md" 1 4)" ] && [ "$(field_of "$O" "$X/g-push.md" 1 4)" != "$(field_of "$O" "$X/h-push.md" 1 4)" ]'
  chk A17 "a run with candidates prints no zero-candidate NOTE" \
    eval '! grep -qF "push-drain: NOTE —" "$W/err"'

  # ---- A10: the record is read at THEIRS, not from the working tree.
  : > "$D/$RECREL"
  rc=0; bash "$R" "$D" "$good" "$C" > "$W/out.a10" 2>/dev/null || rc=$?
  chk A10 "an EMPTY working-tree record still refuses x-push block 1 at theirs" \
    eval '[ "$rc" -eq 0 ] && has_row "$W/out.a10" PUSH-REFUSED "$X/x-push.md" 1 "$dA" "## A refused"'
  cp "$W/rec.good" "$D/$RECREL" || return 2

  # ---- exit-2 arms; the main run (A0) is their exit-0 twin.
  rc=0; bash "$R" "$D" refs/heads/no-such-ref "$C" > "$W/out.a11" 2> "$W/err.a11" || rc=$?
  chk A11 "a theirs ref resolving to no commit exits 2 with a REFUSED line and no rows" \
    eval '[ "$rc" -eq 2 ] && grep -qF "push-drain: REFUSED —" "$W/err.a11" && [ ! -s "$W/out.a11" ]'
  cp "$W/rec.mal" "$D/$RECREL" || return 2
  rc=0; bash "$R" "$D" "$mal" "$C" > "$W/out.a12" 2> "$W/err.a12" || rc=$?
  chk A12 "a malformed record row exits 2 with a REFUSED line and no rows" \
    eval '[ "$rc" -eq 2 ] && grep -qF "push-drain: REFUSED —" "$W/err.a12" && grep -qF malformed "$W/err.a12" && [ ! -s "$W/out.a12" ]'
  cp "$W/rec.dup" "$D/$RECREL" || return 2
  rc=0; bash "$R" "$D" "$dup" "$C" > "$W/out.a13" 2> "$W/err.a13" || rc=$?
  chk A13 "a duplicate record digest exits 2 with a REFUSED line and no rows" \
    eval '[ "$rc" -eq 2 ] && grep -qF "push-drain: REFUSED —" "$W/err.a13" && grep -qF duplicate "$W/err.a13" && [ ! -s "$W/out.a13" ]'
  cp "$W/rec.good" "$D/$RECREL" || return 2

  # Consumers of one shape each, so a refusal cannot be preceded by another file's rows.
  mkdir -p "$W/cu/$X" "$W/cn/.claude/skills/ai-dlc" "$W/cz/$X" || return 2
  printf -- '---\nid: u-open\npush_candidate: true\n\n## U never closed\n\nupsilon body.\n' > "$W/cu/$X/u-open.md"
  cp "$E/z-off.md" "$W/cz/$X/z-off.md" || return 2
  rc=0; bash "$R" "$D" "$good" "$W/cu" > "$W/out.a14" 2> "$W/err.a14" || rc=$?
  chk A14 "an unterminated frontmatter on a candidate exits 2 with a REFUSED line and no rows" \
    eval '[ "$rc" -eq 2 ] && grep -qF "push-drain: REFUSED —" "$W/err.a14" && [ ! -s "$W/out.a14" ]'
  rc=0; bash "$R" "$D" "$good" "$W/cn" > "$W/out.a15" 2> "$W/err.a15" || rc=$?
  chk A15 "a consumer with no extensions dir exits 2 with a REFUSED line and no rows" \
    eval '[ "$rc" -eq 2 ] && grep -qF "push-drain: REFUSED —" "$W/err.a15" && [ ! -s "$W/out.a15" ]'
  rc=0; bash "$R" "$D" "$good" "$W/cz" > "$W/out.a18" 2> "$W/err.a18" || rc=$?
  chk A18 "zero candidates with the dir present exits 0, no rows, and the NOTE" \
    eval '[ "$rc" -eq 0 ] && [ ! -s "$W/out.a18" ] && grep -qF "push-drain: NOTE —" "$W/err.a18" && grep -qF "holds no push_candidate" "$W/err.a18"'
  return 0
}

fails=0
# ============================================================================
# THE SHIPPED READER
# ============================================================================
echo "push-drain-refusals -- reader: $RD"
drive "$RD" "$WORK/real" || broken "the world for the shipped reader could not be built"
cat "$WORK/real/arms"
n_arms="$(grep -c . "$WORK/real/arms" || true)"
[ "$n_arms" -eq 20 ] || broken "expected 20 arm lines from the shipped reader, got $n_arms"
n_bad="$(grep -c '^FAIL' "$WORK/real/arms" || true)"
fails=$((fails + n_bad))

# ============================================================================
# MUTANTS. Each is a COPY of the resolved reader, edited by awk keyed on exactly one line
# (exit 4 otherwise), guarded by cmp -s. A mutant scores KILLED only when its OWNER arm fails
# AND its A11 still passes -- A11 sits before every mutation site, so a copy that never ran
# (or died parsing) cannot score a kill. An unmutated copy runs first and must pass every arm.
# ============================================================================
mkmut() { # mkmut <id> <awk-program> -> mutant path on stdout
  local d="$WORK/mut-$1" r=0
  mkdir -p "$d" || return 2
  LC_ALL=C awk -v A="$PRINTF_ANCHOR" "$2" "$RD" > "$d/push-drain.sh" || r=$?
  [ "$r" -eq 0 ] || return 3
  if [ "$1" != CTL ] && cmp -s "$RD" "$d/push-drain.sh"; then return 1; fi
  printf '%s\n' "$d/push-drain.sh"
}
# awk -v strips one level of escaping, so this doubled form reaches awk as the reader's literal
# `printf "%s\t%s\t%s\n", k, h, t` line inside pd_split.
PRINTF_ANCHOR='printf "%s\\t%s\\t%s\\n", k, h, t'
mut_prog() { # mut_prog <id> -> the awk program for that mutant
  case "$1" in
    CTL) echo '{ print }' ;;
    M1)  echo '{ if (index($0, A)) { sub(/, k, h, t$/, ", k, h, h"); n++ } print } END { exit (n == 1 ? 0 : 4) }' ;;
    M5)  echo '{ if (index($0, A)) { sub(/, k, h, t$/, ", k, h, FILENAME"); n++ } print } END { exit (n == 1 ? 0 : 4) }' ;;
    M6)  echo '{ if (index($0, A)) { sub(/, k, h, t$/, ", k, h, FILENAME \"|\" h"); n++ } print } END { exit (n == 1 ? 0 : 4) }' ;;
    M7)  echo '{ if (index($0, A)) { sub(/, k, h, t$/, ", k, h, FILENAME \"|\" k"); n++ } print } END { exit (n == 1 ? 0 : 4) }' ;;
    M2)  echo '{ if (index($0, "then st=PUSH-REFUSED; else st=PUSH-CANDIDATE; fi")) { sub(/else st=PUSH-CANDIDATE; fi/, "else continue; fi"); n++ } print } END { exit (n == 1 ? 0 : 4) }' ;;
    M3)  echo '{ if (index($0, "[ ! -s \"$PD_T/bad\" ] ||") == 1) { $0 = "true" substr($0, 21); n++ } print } END { exit (n == 1 ? 0 : 4) }' ;;
    M4)  echo '{ if (index($0, "show \"${THEIRS_SHA}:${REC}\" > \"$PD_T/rec\"")) { $0 = "cat \"$DIST/$REC\" > \"$PD_T/rec\" 2>/dev/null || _rc=$?"; n++ } print } END { exit (n == 1 ? 0 : 4) }' ;;
    M8)  echo '{ if (index($0, "[ \"$pc\" = \"true\" ] || continue")) { $0 = "  [ -n \"$pc\" ] || continue"; n++ } print } END { exit (n == 1 ? 0 : 4) }' ;;
    M9)  echo '{ if (index($0, "[ \"$pc\" = \"true\" ] || continue")) { $0 = "  grep -q \"^push_candidate: true\" \"$f\" || continue"; n++ } print } END { exit (n == 1 ? 0 : 4) }' ;;
    M10) echo '{ if (index($0, "pd_is_refused() {") == 1) { $0 = "pd_is_refused() { return 1; }"; n++ } print } END { exit (n == 1 ? 0 : 4) }' ;;
  esac
}
# id|owner arm|what the mutant does
MUTANTS='M1|A3b|title-keyed: the digest is the heading alone
M2|A2|drops candidates: only PUSH-REFUSED rows are written
M3|A12|swallows a malformed record row
M4|A10|reads the record from the dist WORKING TREE, not at theirs
M5|A2|entry-keyed: the digest is the file path alone
M6|A3|path+title-keyed
M7|A4|path+index-keyed
M8|A6|ignores the flag value: any push_candidate key is a candidate
M9|A7|discovers candidates by a whole-file grep, not the frontmatter
M10|A5|never looks a digest up: every block is a candidate'

run_mut() { # run_mut <id> -> sets MP; returns non-zero if the mutant could not be built
  local prog
  prog="$(mut_prog "$1")"
  [ -n "$prog" ] || return 5
  MP="$(mkmut "$1" "$prog")"
}

MP=""; run_mut CTL || broken "the unmutated control copy could not be built"
[ -n "$MP" ] && [ -f "$MP" ] || broken "the unmutated control copy path is empty"
drive "$MP" "$WORK/w-CTL" || broken "the world for the unmutated control could not be built"
if grep -q '^FAIL' "$WORK/w-CTL/arms" || [ "$(grep -c '^ok' "$WORK/w-CTL/arms" || true)" -ne 20 ]; then
  echo "FAIL  CTL  the unmutated copy did not pass all 20 arms -- every mutant verdict below would be unreadable"
  sed 's/^/        /' "$WORK/w-CTL/arms"
  fails=$((fails + 1))
else
  echo "ok    CTL  an unmutated copy of the reader passes all 20 arms"
fi

killed=0; n_mut=0
while IFS='|' read -r mid owner what; do
  [ -n "$mid" ] || continue
  n_mut=$((n_mut + 1))
  MP=""; mrc=0; run_mut "$mid" || mrc=$?
  if [ "$mrc" -ne 0 ] || [ -z "$MP" ]; then
    echo "FAIL  $mid  DID NOT APPLY (mkmut exit $mrc) -- $what"; fails=$((fails + 1)); continue
  fi
  if ! drive "$MP" "$WORK/w-$mid"; then
    echo "FAIL  $mid  its world could not be built -- $what"; fails=$((fails + 1)); continue
  fi
  fset="$(LC_ALL=C awk '$1 == "FAIL" { printf "%s ", $2 }' "$WORK/w-$mid/arms")"
  if grep -q '^ok    A11 ' "$WORK/w-$mid/arms" && grep -q "^FAIL  $owner " "$WORK/w-$mid/arms"; then
    echo "ok    $mid  KILLED by $owner (fail set: ${fset% }) -- $what"; killed=$((killed + 1))
  else
    echo "FAIL  $mid  SURVIVED its owner arm $owner (fail set: ${fset:-none}) -- $what"; fails=$((fails + 1))
  fi
done <<<"$MUTANTS"
[ "$n_mut" -eq 10 ] || broken "expected 10 mutants, iterated $n_mut"

if [ "$fails" -eq 0 ]; then
  echo "PASS  push-drain-refusals -- 20 arms green, $killed/$n_mut mutants killed"
  exit 0
fi
echo "FAIL  push-drain-refusals -- $fails failure(s); $killed/$n_mut mutants killed"
exit 1
