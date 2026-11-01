#!/usr/bin/env bash
# validate-fixture-inprocess.sh -- BL-879's STATIC half: the cells.decl grammar, the source guard on a `cli` subject,
# and the down-only scripts/fixture-inprocess-allowlist.txt. IT JUDGES GRAMMAR ONLY. Whether a fixture runs a subject
# as a separate program outside a declared cell is decided per counted run by the invocation judge's DYNAMIC arms
# (C1, C2's every-tag-is-declared half, C3, and the stale allowlist row), in scripts/validate-fixture-invocations.sh's
# fxc_judge, which core/scripts/hermetic-run.sh calls once per counted run; the hook's post-suite summary names every
# declared fixture with no counted pass under the current judge as PENDING.
#
# usage:  validate-fixture-inprocess.sh [--root R]             the gate (exit 0 clean, 1 FAIL, 2 refused or self-probe red)
#         validate-fixture-inprocess.sh --complete [--root R]  the gate, AND non-zero while any allowlist row remains or
#                                                              when zero fixtures were scanned (BL-878's receipt)
#         validate-fixture-inprocess.sh --derive [--root R]    write the allowlist from the tree (header + rows)
#
# THE GRAMMAR is the judge's own: core/fixtures/<f>/cells.decl rows `cli <subject> <cell-id>`,
# `e2e <subject> <cell-id> why=<reason>`, `nested <parent-subject> <child-subject> why=<reason>`, parsed by
# `validate-fixture-invocations.sh --static-join`, which reads every fixture through fxc_decl_rows, fxc_cells_parse and
# fxc_guarded. Every finding below is a row that join printed, except NP, which reads one field of a `nested` row
# that the judge's grammar does not constrain and is this file's own (np_rows).
#
# THE ARMS.
#   C2  (static half) a malformed row, an unknown kind, a cell id outside [A-Za-z0-9_.-]+, a duplicate id, or a cell
#       whose subject is no path row of the fixture's invocations.decl -> FAIL.
#   C4  an `e2e` or `nested` row with an empty or blank why= -> FAIL.
#   C5  a subject with a `cli` row whose file carries neither column-0 whole-line source guard statement
#       `[ "${BASH_SOURCE[0]}" = "$0" ] || return 0` nor `if [ "${BASH_SOURCE[0]}" = "$0" ]; then` -> FAIL. A data
#       string, a comment or an indented copy carrying the token does not satisfy it.
#   NP  a `nested` row whose parent path lies under core/fixtures/ -> FAIL, allowlisted or not: one e2e cell on a
#       fixture-local driver plus one nested row would cover any number of the child's starts. The parent must be
#       shipped code. Its narrowing is beside np_rows.
#   R   a fixture the join REFUSES -- a subject whose declared start count differs from its cell count with no nested
#       cover, which J3 + C1/C3 make an exact refusal -- that is not an allowlist row -> FAIL. So a new fixture that
#       starts a subject and ships no cells.decl fails the push from its first push, before any counted run.
#   A   the allowlist itself: a duplicate row, a row with no reason, a row naming no fixture -> FAIL; and M4, DOWN-ONLY
#       against origin/main (field 1), through THE ONE SHARED m4() extracted from scripts/validate-fixture-hygiene.sh
#       between its `# M4_BEGIN` and `# M4_END` lines. M4 SKIPs while origin/main carries no allowlist -- the release
#       that first ships it is the one seeding window.
#   N   scanned == listed: the join's per-fixture F rows must equal the count of core/fixtures/*/run.sh this script
#       listed, else REFUSED (an awk that never opened a file reads exactly like a clean one). Zero listed is REFUSED.
#   EXEMPT (undeclarable): printed from `validate-fixture-invocations.sh --b2-census`, the static walk over
#       core/fixtures/*/.undeclarable, never from the judge (which is never called for them).
#
# --derive IS A STATIC JOIN, deterministic (rows LC_ALL=C sorted, no time, no path): every fixture the join refuses,
# or the B2 census reports a gap for, becomes one `<fixture>\t<reason>` row. A missing cells.decl reads as an empty
# one, so a fixture whose every subject row is 0 passes with nothing to tag (lead ruling). A PASS here is a
# PREDICTION; which start carries which tag is visible only to the counted run.
#
# THE RESIDUAL LOOPHOLE, stated because it is not prevented: N `cli` cells for N starts of a guarded subject passes
# every arm here and in the judge. "One end-to-end run per distinct outcome" (fixture-mutants.md clause 6) is a claim
# about OUTCOMES, and the start log records starts, not outcomes, so it cannot be observed from the counter.
# THE BLIND ROUTES: a `bash -c` wrapper takes the tag and leaves the subject under it untagged (C1 fires on it); a
# start under its own `env -i` drops the tag with the counter itself; a fixture's own BASH_ENV replaces the trap that
# unsets FXCELL; a subject that sets FXCELL itself tags its own children.
#
# HOW THE FALSE-POSITIVE SET REACHED ITS FLOOR. The literal rule "no cells.decl and not allowlisted FAILs" refused all
# 257 declared fixtures; reading a missing cells.decl as an empty one (the lead's ruling, BL-879's predicate being a
# subject started as a separate program) removed the fixtures whose every subject row is 0. What remains refused is
# exact under J3 and is the allowlist, enumerated by --derive; the four reference fixtures BL-878 names are on it
# until U4 gives them their cells.decl.
#
# Standalone pre-push step in .githooks/pre-push, after PRESUITE_DONE so an AI_DLC_PRESUITE_SKIP push still runs it;
# NOT an arm of validate-enforcement-map.sh. Distribution-only: repo-root scripts/ is never installed.
set -uo pipefail

MODE=gate; ROOT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --complete) MODE=complete; shift ;;
    --derive) MODE=derive; shift ;;
    --root) [ -n "${2:-}" ] || { echo "usage: validate-fixture-inprocess.sh [--complete|--derive] [--root R]" >&2; exit 2; }; ROOT="$2"; shift 2 ;;
    *) echo "usage: validate-fixture-inprocess.sh [--complete|--derive] [--root R]" >&2; exit 2 ;;
  esac
done
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
if [ -z "$ROOT" ]; then
  ROOT="$HERE"
  while [ "$ROOT" != / ] && [ ! -f "$ROOT/VERSION" ]; do ROOT="$(dirname "$ROOT")"; done
  [ -f "$ROOT/VERSION" ] || { echo "validate-fixture-inprocess: REFUSED -- no VERSION marker above $HERE" >&2; exit 2; }
fi
ROOT="$(cd "$ROOT" && pwd -P)" || exit 2
JUDGE="$HERE/validate-fixture-invocations.sh"
HYG="$HERE/validate-fixture-hygiene.sh"
ALLOW_REL="scripts/fixture-inprocess-allowlist.txt"
M4_REMEDY="do not list the fixture; build it in-process and declare its remaining starts in cells.decl (.claude/rules/fixture-mutants.md, the reference fixtures BL-878 names) and delete the row."
for f in "$JUDGE" "$HYG"; do [ -f "$f" ] || { echo "validate-fixture-inprocess: REFUSED -- $f is absent" >&2; exit 2; }; done
WORK="$(mktemp -d)" || { echo "validate-fixture-inprocess: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

# THE ONE SHARED m4, extracted by its own boundaries; exactly one definition between the markers, else REFUSED.
awk '/^# M4_BEGIN$/ { on = 1; next } /^# M4_END$/ { on = 0 } on' "$HYG" > "$WORK/m4.sh"
[ "$(grep -c '^m4() {$' "$WORK/m4.sh")" = 1 ] && [ "$(tail -1 "$WORK/m4.sh")" = "}" ] \
  || { echo "validate-fixture-inprocess: REFUSED -- could not extract exactly one m4() between # M4_BEGIN and # M4_END in $HYG" >&2; exit 2; }
# shellcheck disable=SC1090
. "$WORK/m4.sh" || exit 2

# judge_tree <root> <out prefix>: the join and the census over one tree; writes <o>.join <o>.census <o>.listed.
judge_tree() {
  local r="$1" o="$2" d n=0
  for d in "$r"/core/fixtures/*/; do [ -f "$d/run.sh" ] && n=$((n + 1)); done
  printf '%s\n' "$n" > "$o.listed"
  [ "$n" -gt 0 ] || return 3
  bash "$JUDGE" --static-join "$r" > "$o.join" 2> "$o.join.err" || return 2
  bash "$JUDGE" --b2-census --root "$r" > "$o.census" 2>&1; [ $? -le 1 ] || return 2
  return 0
}
# np_rows <root>: arm NP, one awk over every <root>/core/fixtures/*/cells.decl. Prints `NP <fx>:<line>: ...` for a
# `nested` row whose PARENT path lies under core/fixtures/. Such a parent is a fixture-local driver, and one e2e cell
# on it plus one nested row covers every start the driver makes of the child, any number of them, so the row would
# hand the fixture's own loop the cover C1 exists to refuse. A parent must be shipped code (core/, scripts/, hooks).
# HOW ITS FALSE-POSITIVE SET REACHED ZERO: the predicate is the parent's own path prefix, `core/fixtures/`, read off
# field 2 of a `nested` row (comments and blanks skipped, the leading `./` a hand might type stripped), never a
# basename or a substring, so a shipped `core/scripts/fixtures-x.sh` parent is not one. Measured at this change over
# every core/fixtures/*/cells.decl: 4 nested rows in 2 fixtures (fixture-inprocess 1, story-evidence-scaffold 3),
# parents scripts/validate-fixture-inprocess.sh, core/scripts/validate-handoff-evidence.sh (twice) and
# core/scripts/record-only-diff.sh; 0 flagged.
np_rows() {
  local f n=0
  for f in "$1"/core/fixtures/*/cells.decl; do [ -f "$f" ] && n=$((n + 1)); done
  [ "$n" -gt 0 ] || return 0
  awk 'FNR == 1 { fx = FILENAME; sub(/\/cells\.decl$/, "", fx); sub(/.*\//, "", fx) }
    { sub(/\r$/, "") } $0 ~ /^[[:blank:]]*(#|$)/ { next }
    $1 == "nested" { p = $2; sub(/^(\.\/)+/, "", p)
      if (substr(p, 1, 14) == "core/fixtures/") print "NP " fx ":" FNR ": the nested row'"'"'s parent " $2 " lies under core/fixtures/ -- a fixture-local driver would cover any number of starts of " $3 "; a nested parent must be shipped code" }' \
    "$1"/core/fixtures/*/cells.decl
}
# verdict <root> <out prefix> <allowlist file>: the gate's findings as lines on stdout; rc 0 clean, 1 a finding.
verdict() {
  local r="$1" o="$2" al="$3" rc=0 sc
  sc="$(grep -c '^F	' "$o.join")" || sc=0
  if [ "$sc" != "$(cat "$o.listed")" ]; then echo "REFUSED N: listed $(cat "$o.listed") run.sh, the join scanned $sc"; return 2; fi
  : > "$o.al"; [ -f "$al" ] && awk -F'\t' '$0 !~ /^[[:space:]]*(#|$)/' "$al" > "$o.al"
  awk -F'\t' '
    FILENAME == ARGV[1] { if ($1 == "F") FX[$2] = 1; else if ($1 == "X") X[$2] = $3; next }
    FILENAME == ARGV[2] { if ($1 == "B2" && $2 == "GAP") { G[$3] = G[$3] " " $4 } next }
    { if ($1 in L) print "A DUP " $1; L[$1] = 1
      if (NF < 2 || $2 ~ /^[[:space:]]*$/) print "A NOREASON " $1
      if (!($1 in FX)) print "A NOFIXTURE " $1 }
    END { for (f in X) if (!(f in L)) print "R " f ": " X[f]
          for (f in G) if (!(f in L)) print "R " f ": B2 gap(s):" G[f] }' "$o.join" <(tr ' ' '\t' < "$o.census") "$o.al" | LC_ALL=C sort > "$o.rx"
  { awk -F'\t' '$1 == "E" { print $3 " " $2 ":" $4 ": " $5 }' "$o.join"; np_rows "$r"; } | LC_ALL=C sort > "$o.ex"
  cat "$o.ex" "$o.rx"
  [ -s "$o.ex" ] || [ -s "$o.rx" ] && rc=1
  return "$rc"
}
derive_rows() { # <out prefix>: the allowlist rows, sorted
  awk -F'\t' 'FILENAME == ARGV[1] { if ($1 == "X") X[$2] = $3; next }
    $1 == "B2" && $2 == "GAP" { G[$3] = G[$3] " " $4 }
    END { for (f in X) print f "\t" X[f]; for (f in G) if (!(f in X)) print f "\tB2 gap(s):" G[f] }' "$1.join" <(tr ' ' '\t' < "$1.census") | LC_ALL=C sort
}

# --- the self-probe, before the corpus, in mktemp, both directions ------------------------------------------------
SP_RED=0
spl() { printf '  %-5s self-probe %s\n' "$1" "$2"; [ "$1" = ok ] || SP_RED=1; }
P="$WORK/probe"
mkf() { # <fixture> <invocations.decl rows |-joined> <cells.decl rows |-joined, or ->
  mkdir -p "$P/core/fixtures/$1"; printf ':\n' > "$P/core/fixtures/$1/run.sh"
  printf '!core/scripts/g.sh\n!core/scripts/u.sh\n!core/scripts/d.sh\n' > "$P/core/fixtures/$1/inputs.decl"
  printf '%s\n' "$2" | tr '|' '\n' > "$P/core/fixtures/$1/invocations.decl"
  rm -f "$P/core/fixtures/$1/cells.decl"; [ "$3" = - ] || printf '%s\n' "$3" | tr '|' '\n' > "$P/core/fixtures/$1/cells.decl"
}
mkdir -p "$P/core/scripts" "$P/core/fixtures/und"
printf '#!/usr/bin/env bash\n[ "${BASH_SOURCE[0]}" = "$0" ] || return 0\n:\n' > "$P/core/scripts/g.sh"
printf '#!/usr/bin/env bash\n:\n' > "$P/core/scripts/u.sh"
printf '#!/usr/bin/env bash\necho "[ \\"${BASH_SOURCE[0]}\\" = \\"$0\\" ] || return 0"\n' > "$P/core/scripts/d.sh"
printf ':\n' > "$P/core/fixtures/und/run.sh"; printf 'probe: subject absent on a consumer\n' > "$P/core/fixtures/und/.undeclarable"
Z='0 core/scripts/g.sh|0 core/scripts/u.sh|0 core/scripts/d.sh'
mkf aok    "2 *|1 core/scripts/g.sh|0 core/scripts/u.sh|0 core/scripts/d.sh" 'cli core/scripts/g.sh a'
mkf azero  "1 *|$Z" -
mkf anew   "2 *|1 core/scripts/g.sh|0 core/scripts/u.sh|0 core/scripts/d.sh" -
mkf aextra "3 *|2 core/scripts/g.sh|0 core/scripts/u.sh|0 core/scripts/d.sh" 'cli core/scripts/g.sh a'
mkf ae2e   "3 *|2 core/scripts/g.sh|0 core/scripts/u.sh|0 core/scripts/d.sh" 'cli core/scripts/g.sh a|e2e core/scripts/g.sh b why=the wiring'
mkf awhy   "3 *|2 core/scripts/g.sh|0 core/scripts/u.sh|0 core/scripts/d.sh" 'cli core/scripts/g.sh a|e2e core/scripts/g.sh b why= '
mkf aunq   "2 *|0 core/scripts/g.sh|1 core/scripts/u.sh|0 core/scripts/d.sh" 'cli core/scripts/u.sh a'
mkf adata  "2 *|0 core/scripts/g.sh|0 core/scripts/u.sh|1 core/scripts/d.sh" 'cli core/scripts/d.sh a'
mkf aunqe  "2 *|0 core/scripts/g.sh|1 core/scripts/u.sh|0 core/scripts/d.sh" 'e2e core/scripts/u.sh a why=no guard needed end to end'
mkf adup   "3 *|2 core/scripts/g.sh|0 core/scripts/u.sh|0 core/scripts/d.sh" 'cli core/scripts/g.sh a|cli core/scripts/g.sh a'
mkf aheld  "3 *|2 core/scripts/g.sh|0 core/scripts/u.sh|0 core/scripts/d.sh" 'cli core/scripts/g.sh a'
mkf anp    "3 *|1 core/scripts/g.sh|0 core/scripts/u.sh|0 core/scripts/d.sh|1 core/fixtures/anp/drv.sh" 'e2e core/fixtures/anp/drv.sh d why=the driver|nested core/fixtures/anp/drv.sh core/scripts/g.sh why=the driver loops'
mkf anpq   "3 *|1 core/scripts/g.sh|1 core/scripts/u.sh|0 core/scripts/d.sh" 'cli core/scripts/g.sh a|nested core/scripts/g.sh core/scripts/u.sh why=g runs u'
printf '# probe\naheld\tseeded\n' > "$WORK/p-allow.txt"
if judge_tree "$P" "$WORK/p"; then
  verdict "$P" "$WORK/p" "$WORK/p-allow.txt" > "$WORK/p.v"; pv=$?
  want="$(printf '%s\n' \
    'C2 adup:2: cell id a is declared twice (first at line 1)' \
    'C4 awhy:2: an empty why= on an e2e row' \
    'C5 adata:1: cli subject core/scripts/d.sh carries no column-0 BASH_SOURCE source guard statement' \
    'C5 aunq:1: cli subject core/scripts/u.sh carries no column-0 BASH_SOURCE source guard statement' \
    'NP anp:2: the nested row'"'"'s parent core/fixtures/anp/drv.sh lies under core/fixtures/ -- a fixture-local driver would cover any number of starts of core/scripts/g.sh; a nested parent must be shipped code' \
    'R adata: static finding(s) above' \
    'R adup: core/scripts/g.sh declares 2 start(s) against 1 cell(s)' \
    'R aextra: core/scripts/g.sh declares 2 start(s) against 1 cell(s)' \
    'R anew: core/scripts/g.sh declares 1 start(s) against 0 cell(s)' \
    'R aunq: static finding(s) above' \
    'R awhy: core/scripts/g.sh declares 2 start(s) against 1 cell(s)')"
  if [ "$pv" = 1 ] && [ "$(cat "$WORK/p.v")" = "$want" ]; then
    spl ok "FIRES: a subject start with no cells.decl (anew), an extra start (aextra), a duplicate id (adup), an empty why= (awhy), an unguarded cli subject (aunq), a guard token inside a data string (adata), a nested row whose parent is a fixture-local driver (anp, NP); QUIET: the fixed twins aok, azero, ae2e, aunqe (an e2e row needs no guard), a nested row whose parent is shipped core/scripts/g.sh (anpq) and the allowlisted aheld"
  else spl FAIL "the probe verdict (rc $pv) was: $(tr '\n' '|' < "$WORK/p.v"), want: $(printf '%s' "$want" | tr '\n' '|')"; fi
  grep -qxF 'EXEMPT (undeclarable) und' "$WORK/p.census" && grep -qxF 'O	und	undeclarable' "$WORK/p.join" \
    && spl ok "EXEMPT (undeclarable) printed from the B2 census, and the join holds it out of population" || spl FAIL "the undeclarable probe fixture's EXEMPT line"
  derive_rows "$WORK/p" > "$WORK/p.d1"; derive_rows "$WORK/p" > "$WORK/p.d2"
  if cmp -s "$WORK/p.d1" "$WORK/p.d2" && [ "$(cut -f1 "$WORK/p.d1" | tr '\n' ' ')" = "adata adup aextra aheld anew aunq awhy " ]; then
    spl ok "--derive lists exactly the refused set (aheld included, its row derived rather than typed), twice byte-identical"
  else spl FAIL "--derive listed [$(cut -f1 "$WORK/p.d1" | tr '\n' ' ')]"; fi
  printf '# probe\naheld\tseeded\naheld\tagain\nazap\tgone\naok\t \n' > "$WORK/p-allow2.txt"
  verdict "$P" "$WORK/p" "$WORK/p-allow2.txt" > "$WORK/p.v2"
  grep -qxF 'A DUP aheld' "$WORK/p.v2" && grep -qxF 'A NOFIXTURE azap' "$WORK/p.v2" && grep -qxF 'A NOREASON aok' "$WORK/p.v2" && ! grep -q 'A .* aheld$' <(grep -v DUP "$WORK/p.v2") \
    && spl ok "the allowlist: a duplicate row, a row naming no fixture and a row with a blank reason FIRE; the well-formed aheld row does not" || spl FAIL "allowlist shape: $(tr '\n' '|' < "$WORK/p.v2")"
else
  spl FAIL "the probe tree could not be joined (rc $?): $(head -c 300 "$WORK/p.join.err" 2>/dev/null)"
fi
# scanned == listed: a join that skipped a fixture is REFUSED, never clean.
printf '1\n' > "$WORK/n.listed"; printf 'F\taok\nF\tazero\n' > "$WORK/n.join"; : > "$WORK/n.census"
verdict "$P" "$WORK/n" /dev/null > "$WORK/n.v"; nv=$?
[ "$nv" = 2 ] && grep -qF 'REFUSED N: listed 1 run.sh, the join scanned 2' "$WORK/n.v" && spl ok "N: a scanned count unequal to the listed count is REFUSED" || spl FAIL "N: rc $nv"
mkdir -p "$WORK/empty/core/fixtures/x"
judge_tree "$WORK/empty" "$WORK/e"; [ $? = 3 ] && spl ok "N: zero run.sh listed is REFUSED before any join" || spl FAIL "N: an empty corpus was not refused"
# M4's six cases on THIS list, through the shared m4 with this file's rel, arm and remedy.
pgit() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY \
  git -c user.name=probe -c user.email=probe@invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null -c init.defaultBranch=main "$@"; }
R="$WORK/m4-base"; RN="$WORK/m4-nofile"; RX="$WORK/m4-noorigin"
mkdir -p "$R/scripts" "$RN" "$RX"
{ pgit init -q "$R" && printf '# base\na\tr1\nb\tr2\n' > "$R/$ALLOW_REL" && pgit -C "$R" add "$ALLOW_REL" \
  && pgit -C "$R" commit -q -m base && pgit -C "$R" update-ref refs/remotes/origin/main HEAD \
  && pgit init -q "$RN" && printf 'x\n' > "$RN/other" && pgit -C "$RN" add other && pgit -C "$RN" commit -q -m n \
  && pgit -C "$RN" update-ref refs/remotes/origin/main HEAD && pgit init -q "$RX"; } >/dev/null 2>&1 \
  || { echo "validate-fixture-inprocess: REFUSED -- could not build the M4 probe repos" >&2; exit 2; }
m4c() { # <label> <repo> <want rc> <want first line> <rows...>
  local lab="$1" repo="$2" wrc="$3" want="$4" got rc; shift 4
  printf '# probe list\n' > "$WORK/m4-cur.txt"; printf '%s\n' "$@" >> "$WORK/m4-cur.txt"
  got="$(m4 "$repo" "$WORK/m4-cur.txt" "$WORK/m4-b.txt" "$ALLOW_REL" M4 "$M4_REMEDY")"; rc=$?
  [ "$rc" = "$wrc" ] && [ "$(printf '%s\n' "$got" | head -1)" = "$want" ] && return 0
  spl FAIL "M4 case $lab: rc $rc, want $wrc: $(printf '%s' "$got" | head -2 | tr '\n' ' ')"; return 1
}
M4F="FAIL M4: allowlist row(s) whose fixture is not on $ALLOW_REL at origin/main -- the list is DOWN-ONLY:"
M4O="OK M4: no allowlist row added against origin/main"
m4ok=0
m4c added "$R" 1 "$M4F" "$(printf 'a\tr1')" "$(printf 'b\tr2')" "$(printf 'c\tr3')" || m4ok=1
m4c swap "$R" 1 "$M4F" "$(printf 'a\tr1')" "$(printf 'c\tr3')" || m4ok=1
m4c shrink "$R" 0 "$M4O" "$(printf 'a\tr1')" || m4ok=1
m4c reworded "$R" 0 "$M4O" "$(printf 'a\tother words')" "$(printf 'b\tr2')" || m4ok=1
m4c nofile "$RN" 0 "SKIP M4: origin/main carries no $ALLOW_REL -- this is the release that first ships it" "$(printf 'c\tr')" || m4ok=1
m4c noorigin "$RX" 0 "SKIP M4: origin/main does not resolve here, so there is no base allowlist to compare against" "$(printf 'c\tr')" || m4ok=1
got="$(m4 "$R" "$WORK/m4-cur.txt" "$WORK/m4-b.txt" "$ALLOW_REL" M4 "$M4_REMEDY")"
printf '# probe list\nz\tr\n' > "$WORK/m4-cur.txt"; got="$(m4 "$R" "$WORK/m4-cur.txt" "$WORK/m4-b.txt" "$ALLOW_REL" M4 "$M4_REMEDY")"
grep -qxF "  Remedy: $M4_REMEDY" <<<"$got" || { spl FAIL "M4 the added-row failure does not carry this list's remedy"; m4ok=1; }
[ "$m4ok" = 0 ] && spl ok "M4 on $ALLOW_REL: added and swapped rows refused with this list's remedy; shrink and a reworded reason pass; both no-base states SKIP"
if [ "$SP_RED" != 0 ]; then echo "validate-fixture-inprocess: REFUSED -- the self-probe is red, so a verdict over the tree is unattributable" >&2; exit 2; fi

# --- the corpus -----------------------------------------------------------------------------------------------------
judge_tree "$ROOT" "$WORK/c"; jr=$?
case "$jr" in
  0) ;;
  3) echo "validate-fixture-inprocess: REFUSED -- zero core/fixtures/*/run.sh under $ROOT" >&2; exit 2 ;;
  *) echo "validate-fixture-inprocess: REFUSED -- the static join or the B2 census could not run: $(head -c 400 "$WORK/c.join.err")" >&2; exit 2 ;;
esac
if [ "$MODE" = derive ]; then
  sc="$(grep -c '^F	' "$WORK/c.join")" || sc=0
  [ "$sc" = "$(cat "$WORK/c.listed")" ] || { echo "validate-fixture-inprocess: REFUSED -- listed $(cat "$WORK/c.listed") run.sh, the join scanned $sc" >&2; exit 2; }
  { printf '%s\n' "# $ALLOW_REL -- the DERIVED, DOWN-ONLY allowlist of scripts/validate-fixture-inprocess.sh (BL-879): the fixtures" \
      "# that still run a subject as a separate program outside a declared cell. Rows <fixture><TAB><reason>, LC_ALL=C sorted." \
      "# Never typed: regenerate with \`bash scripts/validate-fixture-inprocess.sh --derive\`. A row is never added (M4); a" \
      "# conversion deletes its fixture's row in the same change, and the invocation judge FAILs a listed fixture that passes."
    derive_rows "$WORK/c"; } > "$ROOT/$ALLOW_REL.tmp.$$" && mv "$ROOT/$ALLOW_REL.tmp.$$" "$ROOT/$ALLOW_REL" \
    || { echo "validate-fixture-inprocess: could not write $ROOT/$ALLOW_REL" >&2; exit 2; }
  echo "validate-fixture-inprocess: --derive wrote $(awk -F'\t' '$0 !~ /^[[:space:]]*(#|$)/' "$ROOT/$ALLOW_REL" | awk 'END { print NR }') row(s) to $ALLOW_REL"
  exit 0
fi
rc=0
verdict "$ROOT" "$WORK/c" "$ROOT/$ALLOW_REL" > "$WORK/c.v"; vr=$?
[ "$vr" = 2 ] && { cat "$WORK/c.v" >&2; exit 2; }
grep '^EXEMPT (undeclarable) ' "$WORK/c.census"
nsc="$(cat "$WORK/c.listed")"
nal="$(awk 'END { print NR }' "$WORK/c.al")"
nx="$(grep -c '^X	' "$WORK/c.join")" || nx=0
np="$(grep -c '^P	' "$WORK/c.join")" || np=0
no="$(grep -c '^O	' "$WORK/c.join")" || no=0
echo "validate-fixture-inprocess: judges GRAMMAR only (the dynamic C1-C3 run per counted run in the invocation judge); $nsc fixture(s) scanned; $np predicted to pass, $nx refused, $no out of population; $nal allowlist row(s)"
if [ "$vr" = 1 ]; then
  rc=1
  sed 's/^/  FAIL  /' "$WORK/c.v"
  echo "  Remedy: $(sed -n 's/^FXC_CELLS_REMEDY="\(.*\)"$/\1/p' "$JUDGE" | sed 's/\\`/`/g'). An R row is a fixture whose declared starts of a subject differ from its declared cells; A rows are the allowlist's own shape."
fi
m4 "$ROOT" "$ROOT/$ALLOW_REL" "$WORK/m4-root.txt" "$ALLOW_REL" M4 "$M4_REMEDY" > "$WORK/m4.out"; [ $? = 0 ] || rc=1
cat "$WORK/m4.out"
if [ "$MODE" = complete ]; then
  if [ "$nsc" -eq 0 ]; then echo "  INCOMPLETE  zero fixtures scanned"; rc=1
  elif [ "$nal" -gt 0 ]; then echo "  INCOMPLETE  $nal allowlist row(s) remain in $ALLOW_REL"; rc=1; fi
fi
[ "$rc" = 0 ] && echo "OK: validate-fixture-inprocess -- self-probe fired both ways; $nsc fixture(s) scanned; no static finding; no unlisted refusal; the allowlist is down-only"
exit "$rc"
