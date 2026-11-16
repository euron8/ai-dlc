#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# push-drain-refusals — step 8's push_candidate drain honours the distribution's refusal record.
#
# Usage: run.sh
# Exit:  0 = every arm holds, OR the reader is absent (PENDING line);
#        1 = the reader regressed; 2 = fixture broken.
#
# THE SUBJECT is reconcile/push-drain.sh, in either layout (core/skills/ai-dlc-update/ in the
# distribution, .claude/skills/ai-dlc-update/ on a consumer). It splits every extension whose
# FRONTMATTER says `push_candidate: true` into ##/### blocks and emits PUSH-REFUSED or
# PUSH-CANDIDATE per block, joined on a digest of the block's own text against
# push-refusals.tsv read AT THEIRS through git. Before it existed the drain was prose, nothing
# read a standing verdict, and every pull re-proposed blocks the distribution had already
# declined -- the reference consumer's implementation-push ledger row could never close.
#
# The join must be on the block's CONTENT: keyed on the heading, the file, the file plus heading or
# the file plus position, it refuses a changed proposal under an old title or loses a refusal when a
# block moves. The arms that discriminate those keyings seed the record through the reader's own
# --digest, so an internally consistent keying is caught by the arm that separates it.
#
# WHEN THE READER IS ABSENT this prints a PENDING verdict line and exits 0. A core fixture ships
# ahead of its subject on a consumer pull, so absence is expected for one pull; the line says in
# words that nothing was checked, because exit 0 alone reads exactly like a pass.
#
# IN PROCESS. Every reader call goes through pdx: push-drain.sh is SOURCED in a subshell (its
# BASH_SOURCE guard stops it after the definitions) and its CLI entry pd_main is called with the
# CLI's argv. The kept end-to-end runs are PEQ's three (`bash <reader>` on a drain, a refusal and a
# --digest), each compared byte-for-byte with the in-process answer. A reader that predates the guard
# is driven through `bash` by pdx itself, so this file reaches a consumer one pull behind safely.
set -uo pipefail
# THE ROOT IS READ BEFORE THE SCRUB. Under the hermetic runner the project root is the sandbox,
# handed over as AI_DLC_PROJECT_ROOT; the walk below, started from this file's own location,
# climbs past a sandbox that carries no .git and lands on the mktemp parent, which on an operator
# box can carry a `.claude/` of its own -- and the reader is then "absent" there, PENDING exit 0,
# nothing checked. Honour the override, then scrub it like every other tunable.
PDR_ROOT_OVERRIDE="${AI_DLC_PROJECT_ROOT:-}"
# HERMETIC -- scrub the operator's tuning before invoking anything (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# The seam above already does this; restated so a fixture-local edit cannot lose it before the
# first reader call, which runs git against a scratch dist.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

broken() { echo "FIXTURE BROKEN: push-drain-refusals -- $1" >&2; echo "FAIL  push-drain-refusals -- fixture broken: $1"; exit 2; }

HERE="$(cd "$(dirname "$0")" && pwd)" || broken "cannot resolve the fixture directory"
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }
# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || broken "no lib/report.sh beside $HERE"
MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || broken "no lib/mutant.sh beside $HERE"
# shellcheck source=/dev/null
. "$MUT_LIB"

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
if [ -n "$PDR_ROOT_OVERRIDE" ] && [ -d "$PDR_ROOT_OVERRIDE" ]; then
  ROOT="$(cd "$PDR_ROOT_OVERRIDE" && pwd -P)" || broken "cannot enter AI_DLC_PROJECT_ROOT=$PDR_ROOT_OVERRIDE"
else
  ROOT="$(pdr_root "$(dirname "$HERE")")" || broken "no repo root above $HERE"
fi

RD=""
for _c in "$ROOT/core/skills/ai-dlc-update/reconcile/push-drain.sh" \
          "$ROOT/.claude/skills/ai-dlc-update/reconcile/push-drain.sh"; do
  if [ -f "$_c" ]; then RD="$_c"; break; fi
done
if [ -z "$RD" ]; then
  echo "PENDING  push-drain-refusals -- reconcile/push-drain.sh is absent from both layouts under $ROOT (core/skills/ai-dlc-update/ and .claude/skills/ai-dlc-update/). NOTHING WAS CHECKED; this is not a pass. It clears on the pull that delivers the reader."
  fx_skip_exit "$HERE"
fi
echo "HERMETIC-CONSUMED $RD"
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
# pdx <reader> [<args>...] -- THE IN-PROCESS DRIVE. The reader is
# SOURCED in a subshell -- its BASH_SOURCE guard stops it after the definitions -- and its own CLI
# entry, pd_main, is called with the argv the CLI would get, so its `exit`, its EXIT trap and its
# `set -uo pipefail` all end with the subshell. A reader that predates the guard (a consumer one pull
# behind this fixture) has no pd_main and would RUN on being sourced, so it is driven through
# `bash <reader>` instead; that is the CLI, and the arms read the same rows either way.
# PEQ below proves the two drives answer byte-for-byte alike. fx_inproc is given an ABSOLUTE subject path under
# $ROOT: one drive runs from `cd /`, where a relative path logs
# as `//core/...` and the judge's count does not match it.
pdx() {
  local r="$1"; shift
  if grep -q '^pd_main() {$' "$r"; then
    ( # shellcheck source=/dev/null
      . "$r" || exit 2
      fx_inproc "$ROOT/core/skills/ai-dlc-update/reconcile/push-drain.sh"
      pd_main "$@" )
  else
    bash "$r" "$@"
  fi
}
dg() { # dg <reader> <file> <heading> -- that block's digest per the reader's own --digest
  local o
  o="$(pdx "$1" --digest "$2" 2>/dev/null)" || return 1
  LC_ALL=C awk -F'\t' -v h="$3" '$3 == h { print $2; exit }' <<<"$o"
}
gcommit() { git -C "$1" -c user.email=f@f -c user.name=f -c commit.gpgsign=false -c core.hooksPath=/dev/null commit -qam "$2" >/dev/null 2>&1; }

# drive <reader> <world-dir> -- builds a world, runs every arm, writes <world>/arms.
# Returns 2 when the world itself could not be built (never a verdict about the reader).
drive() {
  local R="$1" W="$2" C E D dA dB dC dD good mal dup alt rc O
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
  dB="$(dg "$R" "$E/x-push.md" "## B unnamed")"
  [ -n "$dA" ] && [ -n "$dB" ] && [ -n "$dC" ] && [ -n "$dD" ] || return 2
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
  # The dist's HEAD is a WELL-FORMED record that differs from every ref under test: the good
  # record plus a row refusing x-push block 2. Only a reader of HEAD sees that row (A19).
  { cat "$W/rec.good"; printf '%s\tx-push\trefused only at HEAD\n' "$dB"; } > "$W/rec.alt"
  cp "$W/rec.alt" "$D/$RECREL" && gcommit "$D" alt || return 2
  alt="$(git -C "$D" rev-parse HEAD)" || return 2
  printf '%s\n' "$good" > "$W/.ref.good"; printf '%s\n' "$mal" > "$W/.ref.mal"; printf '%s\n' "$dup" > "$W/.ref.dup"
  printf '%s\n' "$alt" > "$W/.ref.alt"
  # The working tree holds the record of whichever ref is being read, so a reader of the WORKING
  # TREE fails only the arm built to separate the two (A10).
  cp "$W/rec.good" "$D/$RECREL" || return 2
  # The one-shape consumers the refusal arms read, part of the world so they are copied with it.
  mkdir -p "$W/cu/$X" "$W/cn/.claude/skills/ai-dlc" "$W/cz/$X" || return 2
  printf -- '---\nid: u-open\npush_candidate: true\n\n## U never closed\n\nupsilon body.\n' > "$W/cu/$X/u-open.md"
  cp "$E/z-off.md" "$W/cz/$X/z-off.md" || return 2

  # ---- A0: cwd-invariance, and the main run.
  local rc2=0
  rc=0; (cd / && pdx "$R" "$D" "$good" "$C") > "$O" 2> "$W/err" || rc=$?
  (cd "$HERE" && pdx "$R" "$D" "$good" "$C") > "$W/out.here" 2>/dev/null || rc2=$?
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
  rc=0; pdx "$R" "$D" "$good" "$C" > "$W/out.a10" 2>/dev/null || rc=$?
  chk A10 "an EMPTY working-tree record still refuses x-push block 1 at theirs" \
    eval '[ "$rc" -eq 0 ] && has_row "$W/out.a10" PUSH-REFUSED "$X/x-push.md" 1 "$dA" "## A refused"'
  cp "$W/rec.good" "$D/$RECREL" || return 2

  # ---- A19: the record is read at THEIRS, not at the dist's HEAD. The working tree holds the
  # good record, so a working-tree reader passes here and only a HEAD reader fails; the arm
  # first asserts the two sides differ (HEAD is not theirs, and HEAD's record refuses dB).
  local recH recG
  recH="$(git -C "$D" show "HEAD:$RECREL")" || return 2
  recG="$(git -C "$D" show "${good}:$RECREL")" || return 2
  rc=0; pdx "$R" "$D" "$good" "$C" > "$W/out.a19" 2>/dev/null || rc=$?
  chk A19 "a dist HEAD carrying a different well-formed record does not refuse x-push block 2 at theirs" \
    eval '[ "$alt" != "$good" ] && [ "$(git -C "$D" rev-parse HEAD)" = "$alt" ] && grep -qF "$dB" <<<"$recH" && ! grep -qF "$dB" <<<"$recG" && [ "$rc" -eq 0 ] && has_row "$W/out.a19" PUSH-CANDIDATE "$X/x-push.md" 2 "*" "## B unnamed"'

  # ---- exit-2 arms; the main run (A0) is their exit-0 twin.
  rc=0; pdx "$R" "$D" refs/heads/no-such-ref "$C" > "$W/out.a11" 2> "$W/err.a11" || rc=$?
  chk A11 "a theirs ref resolving to no commit exits 2 with a REFUSED line and no rows" \
    eval '[ "$rc" -eq 2 ] && grep -qF "push-drain: REFUSED —" "$W/err.a11" && [ ! -s "$W/out.a11" ]'
  cp "$W/rec.mal" "$D/$RECREL" || return 2
  rc=0; pdx "$R" "$D" "$mal" "$C" > "$W/out.a12" 2> "$W/err.a12" || rc=$?
  chk A12 "a malformed record row exits 2 with a REFUSED line and no rows" \
    eval '[ "$rc" -eq 2 ] && grep -qF "push-drain: REFUSED —" "$W/err.a12" && grep -qF malformed "$W/err.a12" && [ ! -s "$W/out.a12" ]'
  cp "$W/rec.dup" "$D/$RECREL" || return 2
  rc=0; pdx "$R" "$D" "$dup" "$C" > "$W/out.a13" 2> "$W/err.a13" || rc=$?
  chk A13 "a duplicate record digest exits 2 with a REFUSED line and no rows" \
    eval '[ "$rc" -eq 2 ] && grep -qF "push-drain: REFUSED —" "$W/err.a13" && grep -qF duplicate "$W/err.a13" && [ ! -s "$W/out.a13" ]'
  cp "$W/rec.good" "$D/$RECREL" || return 2

  # Consumers of one shape each (built with the world), so a refusal cannot be preceded by another file's rows.
  rc=0; pdx "$R" "$D" "$good" "$W/cu" > "$W/out.a14" 2> "$W/err.a14" || rc=$?
  chk A14 "an unterminated frontmatter on a candidate exits 2 with a REFUSED line and no rows" \
    eval '[ "$rc" -eq 2 ] && grep -qF "push-drain: REFUSED —" "$W/err.a14" && [ ! -s "$W/out.a14" ]'
  rc=0; pdx "$R" "$D" "$good" "$W/cn" > "$W/out.a15" 2> "$W/err.a15" || rc=$?
  chk A15 "a consumer with no extensions dir exits 2 with a REFUSED line and no rows" \
    eval '[ "$rc" -eq 2 ] && grep -qF "push-drain: REFUSED —" "$W/err.a15" && [ ! -s "$W/out.a15" ]'
  rc=0; pdx "$R" "$D" "$good" "$W/cz" > "$W/out.a18" 2> "$W/err.a18" || rc=$?
  chk A18 "zero candidates with the dir present exits 0, no rows, and the NOTE" \
    eval '[ "$rc" -eq 0 ] && [ ! -s "$W/out.a18" ] && grep -qF "push-drain: NOTE —" "$W/err.a18" && grep -qF "holds no push_candidate" "$W/err.a18"'
  return 0
}

# ============================================================================
# THE SHIPPED READER
# ============================================================================
echo "push-drain-refusals -- reader: $RD"
drive "$RD" "$WORK/real" || broken "the world for the shipped reader could not be built"
cat "$WORK/real/arms"
n_arms="$(grep -c . "$WORK/real/arms" || true)"
[ "$n_arms" -eq 21 ] || broken "expected 21 arm lines from the shipped reader, got $n_arms"
n_bad="$(grep -c '^FAIL' "$WORK/real/arms" || true)"
n_ok="$(grep -c '^ok' "$WORK/real/arms" || true)"
# The arm lines are written by chk into the arms file, not by ok/bad, so their counts are added here.
fails=$((fails + n_bad)); oks=$((oks + n_ok))

# PEQ -- THE END-TO-END RUNS KEPT, one per distinct CLI outcome: `bash <reader>` on the shipped world's
# drain (exit 0, rows), its no-such-ref refusal (exit 2, REFUSED), and one --digest (exit 0). Each is
# compared byte-for-byte, stdout and stderr and exit apart, with the in-process pd_main on the same
# input, and the drain and the refusal must differ, so two empty drives cannot agree into a pass.
# The digest leg also asserts the reader carries the guard: on an unguarded reader pdx IS the CLI,
# and the comparison would be one program against itself.
pe_ok=1; pe_why=""
# A reader with no guard is legal ONLY in the consumer layout, one pull behind this fixture: pdx drove
# every arm through the CLI there, so there is no in-process answer to compare and PEQ is not evaluated.
# In the distribution layout the reader IS this release's, and a missing guard is a regression.
pe_skip=0
if ! grep -q '^pd_main() {$' "$RD"; then
  case "$RD" in
    "$ROOT/.claude/skills/"*) pe_skip=1 ;;
    *) pe_ok=0; pe_why="$pe_why no-pd_main-in-$RD" ;;
  esac
fi
if [ "$pe_skip" = 1 ]; then
  echo "NOTE  PEQ  not evaluated -- $RD predates the source guard (no pd_main), so every drive above was the CLI and there is no in-process answer to compare"
else
pe_D="$WORK/real/dist"; pe_C="$WORK/real/c"; pe_good="$(cat "$WORK/real/.ref.good")"
pe_cmp() { # pe_cmp <tag> <args...>
  local t="$1" ur=0 cr=0; shift
  pdx "$RD" "$@" > "$WORK/pe.$t.uo" 2> "$WORK/pe.$t.ue" || ur=$?
  FXCELL="cli-$t" bash "$RD" "$@" > "$WORK/pe.$t.co" 2> "$WORK/pe.$t.ce" || cr=$?
  # The staging dir's name is in no output; a REFUSED line names only inputs, so stderr compares exactly.
  cmp -s "$WORK/pe.$t.uo" "$WORK/pe.$t.co" && cmp -s "$WORK/pe.$t.ue" "$WORK/pe.$t.ce" && [ "$ur" = "$cr" ] \
    || { pe_ok=0; pe_why="$pe_why $t(unit=$ur cli=$cr)"; }
  echo "$cr" > "$WORK/pe.$t.rc"
}
pe_cmp pass "$pe_D" "$pe_good" "$pe_C"
pe_cmp refuse "$pe_D" refs/heads/no-such-ref "$pe_C"
pe_cmp digest --digest "$pe_C/$X/x-push.md"
[ "$(cat "$WORK/pe.pass.rc")" = 0 ] && [ -s "$WORK/pe.pass.co" ] && [ "$(cat "$WORK/pe.refuse.rc")" = 2 ] \
  && grep -qF 'push-drain: REFUSED —' "$WORK/pe.refuse.ce" && [ "$(cat "$WORK/pe.digest.rc")" = 0 ] \
  && [ "$(grep -c . "$WORK/pe.digest.co" || true)" -eq 2 ] || { pe_ok=0; pe_why="$pe_why outcomes"; }
if [ "$pe_ok" = 1 ]; then ok "PEQ  the in-process pd_main equals bash <reader> byte-for-byte on a drain (rc 0), a refusal (rc 2) and a --digest (rc 0)"
else bad "PEQ  the in-process drive differs from the CLI:$pe_why"; fi
fi

report_end push-drain-refusals
