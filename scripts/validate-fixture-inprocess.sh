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
#   P2  (the join's, BL-982 (b)) in EVERY declared fixture, opted in by an `inproc:` row or not, an in-process drive of
#       a declared bash subject (a call of a guarded subject's entry function, a source of an unguarded one) with no
#       fx_inproc call on it -> FAIL, allowlisted or not, when THE P2 RATCHET (p2_ratchet, below) reads the row NEW
#       against the push base (merge-base of HEAD and origin/main, scanned); a row already present there prints as `OWED P2 ...` with a count line and never fails, and a
#       fixture refused for P2 rows alone takes no R row and no --derive allowlist row. Its counting unit, pairing rule,
#       blind routes and false-positive floor are ARM P2's, above fxc_p2_scan in the judge. It subsumes P1.
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

# judge_tree <root> <out prefix> [<base dir>]: the join and the census over one tree; writes <o>.join <o>.census
# <o>.listed. With a base dir the join also scans it (--p2-base) for the P2 ratchet.
judge_tree() {
  local r="$1" o="$2" b="${3:-}" d n=0
  for d in "$r"/core/fixtures/*/; do [ -f "$d/run.sh" ] && n=$((n + 1)); done
  printf '%s\n' "$n" > "$o.listed"
  [ "$n" -gt 0 ] || return 3
  if [ -n "$b" ]; then bash "$JUDGE" --static-join "$r" --p2-base "$b" > "$o.join" 2> "$o.join.err" || return 2
  else bash "$JUDGE" --static-join "$r" > "$o.join" 2> "$o.join.err" || return 2; fi
  bash "$JUDGE" --b2-census --root "$r" > "$o.census" 2>&1; [ $? -le 1 ] || return 2
  return 0
}
# p2_base <root> <dir> <git runner>: THE PUSH BASE of the P2 ratchet, materialised. It is `git merge-base HEAD
# origin/main` (release-version's form), never origin/main itself: a branch BEHIND main would otherwise read every line
# main has since edited as added. A branch stacked on unlanded commits still reads what those commits added as ADDED,
# so a peer's unlanded unpaired drive fires in this push: the fail-closed direction, because the ratchet cannot tell
# whose line it is, and acquitting a line for being someone else's would let it land unrouted through whichever push
# goes first. The base's core/ (with scripts/ and .githooks/ when the tree has them) is written into <dir> through a
# PRIVATE index (read-tree --index-output, then ls-files | checkout-index --prefix under GIT_INDEX_FILE): git only, so
# no tool a fixture sandbox may lack (tar), and the repository's own index is never touched. The join scans <dir> with
# the tip's own scan (--p2-base). Returns 1 when there is no base.
p2_ix() { if [ "$P2_RG" = pgit ]; then env -u GIT_DIR -u GIT_WORK_TREE -u GIT_OBJECT_DIRECTORY GIT_INDEX_FILE="$P2_IDX" git -C "$P2_R" "$@"
          else GIT_INDEX_FILE="$P2_IDX" git -C "$P2_R" "$@"; fi; }
p2_base() {
  local r="$1" b="$2" rg="$3" mb
  mb="$("$rg" -C "$r" merge-base HEAD origin/main 2>/dev/null)" && [ -n "$mb" ] || return 1
  set -- core; [ -d "$r/scripts" ] && set -- "$@" scripts; [ -d "$r/.githooks" ] && set -- "$@" .githooks
  mkdir -p "$b" || return 1
  P2_RG="$rg"; P2_R="$r"; P2_IDX="$b.index"
  # read-tree runs under GIT_INDEX_FILE=<private index> (p2_ix): `--index-output` alone still takes the repository
  # index's lock, which a peer holding it would refuse.
  p2_ix read-tree "$mb" > /dev/null 2>&1 || return 1
  p2_ix ls-files -z -- "$@" | p2_ix checkout-index -z --stdin --prefix="$b/" || return 1
  [ -d "$b/core/fixtures" ] || return 1
  return 0
}
# p2_ratchet <root> <out prefix> <- for every row NEW, or base>: THE P2 RATCHET (operator ruling). Writes <o>.p2cls, one
# `NEW|OWED\t<fx>\t<file:line>` per P2 row of <o>.join. THE BASE IS SCANNED TOO (the join's B rows, the same scan over
# the materialised push base): a row is NEW when the count of UNPAIRED drives with its (fixture, file, normalised line
# text) at the tip exceeds that count at the base. So a moved-but-unchanged line, a pure deletion, and the deletion of a
# paired drive together with its fx_inproc stay quiet; an added drive, an edited owed line, a deleted or displaced
# fx_inproc (a comment, an `echo` between, a new drive taking the pairing), and a subject newly declared `!` all FAIL.
# RESIDUALS, stated: deleting one unpaired drive and adding another with the same text in the same file passes; a
# renamed or moved file is absent at the base under its new path, so all its rows read NEW (fail-closed). NO BASE
# (no BASEROOT row: origin/main or the merge-base does not resolve) with one or more P2 rows is REFUSED (rc 2), never a
# SKIP: a SKIP would acquit every seeded drive in a tree with no origin, the fixture-inprocess sandbox included; with no
# P2 row there is nothing to judge and it prints SKIP. COST: one awk (the base scan is inside the join, no extra bash).
p2_ratchet() {
  local r="$1" o="$2" mode="$3" T=$'\t' a fx f loc rest n=0 hb=0
  : > "$o.p2cls"
  while IFS="$T" read -r a fx f loc rest; do
    [ "$a" = E ] && [ "$f" = P2 ] && n=$((n + 1)); [ "$a" = BASEROOT ] && hb=1
  done < "$o.join"
  [ "$n" -gt 0 ] || { [ "$mode" = - ] || echo "SKIP P2 ratchet: no P2 row to judge"; return 0; }
  if [ "$mode" = - ]; then
    awk -F'\t' '$1 == "E" && $3 == "P2" { print "NEW\t" $2 "\t" $4 }' "$o.join" > "$o.p2cls"; return 0
  fi
  [ "$hb" = 1 ] || { echo "REFUSED P2 ratchet: $n P2 row(s) and no push base under $r (origin/main or its merge-base with HEAD does not resolve), so no row can be judged new or owed" >&2; return 2; }
  LC_ALL=C awk -F'\t' 'function fl(l) { sub(/:[0-9]+$/, "", l); return l }
    $1 == "B" { BC[$2 SUBSEP fl($3) SUBSEP $4]++; next }
    $1 == "E" && $3 == "P2" { k = $2 SUBSEP fl($4) SUBSEP $6; TC[k]++; N++; RK[N] = k; RF[N] = $2; RL[N] = $4 }
    END { for (i = 1; i <= N; i++) print ((TC[RK[i]] > BC[RK[i]] + 0) ? "NEW" : "OWED") "\t" RF[i] "\t" RL[i] }' "$o.join" > "$o.p2cls" \
    || { echo "REFUSED P2 ratchet: the ratchet awk failed" >&2; return 2; }
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
    FILENAME == ARGV[1] { if ($1 == "F") FX[$2] = 1; else if ($1 == "X") X[$2] = $3; else if ($1 == "E") { if ($3 == "P2") HP[$2] = 1; else NP2[$2] = 1 } next }
    FNR == 1 && FILENAME == ARGV[2] { for (f in X) if (X[f] == "static finding(s) above" && (f in HP) && !(f in NP2)) delete X[f] }
    FILENAME == ARGV[2] { if ($1 == "B2" && $2 == "GAP") { G[$3] = G[$3] " " $4 } next }
    { if ($1 in L) print "A DUP " $1; L[$1] = 1
      if (NF < 2 || $2 ~ /^[[:space:]]*$/) print "A NOREASON " $1
      if (!($1 in FX)) print "A NOFIXTURE " $1 }
    END { for (f in X) if (!(f in L)) print "R " f ": " X[f]
          for (f in G) if (!(f in L)) print "R " f ": B2 gap(s):" G[f] }' "$o.join" <(tr ' ' '\t' < "$o.census") "$o.al" | LC_ALL=C sort > "$o.rx"
  # A P2 row FAILs only when the ratchet (p2_ratchet, its .p2cls) reads it NEW; an OWED one prints, never fails. With no
  # .p2cls every P2 row is NEW.
  [ -f "$o.p2cls" ] || : > "$o.p2cls"
  { awk -F'\t' 'FILENAME == ARGV[1] { if ($1 == "OWED") OW[$2 SUBSEP $3] = 1; next }
      $1 == "E" && !($3 == "P2" && (($2 SUBSEP $4) in OW)) { print $3 " " $2 ":" $4 ": " $5 }' "$o.p2cls" "$o.join"; np_rows "$r"; } | LC_ALL=C sort > "$o.ex"
  awk -F'\t' 'FILENAME == ARGV[1] { if ($1 == "OWED") OW[$2 SUBSEP $3] = 1; next }
      $1 == "E" && $3 == "P2" && (($2 SUBSEP $4) in OW) { print "OWED P2 " $2 ":" $4 ": " $5 }' "$o.p2cls" "$o.join" | LC_ALL=C sort > "$o.ow"
  cat "$o.ex" "$o.rx"
  [ -s "$o.ex" ] || [ -s "$o.rx" ] && rc=1
  return "$rc"
}
derive_rows() { # <out prefix>: the allowlist rows, sorted; a fixture refused for P2 rows alone is no allowlist row (D5)
  awk -F'\t' 'FILENAME == ARGV[1] { if ($1 == "X") X[$2] = $3; else if ($1 == "E") { if ($3 == "P2") HP[$2] = 1; else NP2[$2] = 1 } next }
    FNR == 1 { for (f in X) if (X[f] == "static finding(s) above" && (f in HP) && !(f in NP2)) delete X[f] }
    $1 == "B2" && $2 == "GAP" { G[$3] = G[$3] " " $4 }
    END { for (f in X) { r = X[f]; gsub(/ declares [0-9]+ start\(s\) against [0-9]+ cell\(s\)/, " runs outside a declared cell", r); print f "\t" r }; for (f in G) if (!(f in X)) print f "\tB2 gap(s):" G[f] }' "$1.join" <(tr ' ' '\t' < "$1.census") | LC_ALL=C sort
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
# P2 (D5, D6): the receipt seed, an unrouted source of the unguarded u.sh in a fixture NOT opted in (apin), FAILs with a
# P2 row and its R row; the same seed in an ALLOWLISTED fixture (apheld) still prints its P2 row; the paired twin apinq
# stays quiet.
mkf apin   "1 *|$Z" -; printf '. "$d/core/scripts/u.sh"\n' > "$P/core/fixtures/apin/run.sh"
mkf apheld "1 *|$Z" -; printf '. "$d/core/scripts/u.sh"\n' > "$P/core/fixtures/apheld/run.sh"
mkf apinq  "1 *|$Z" -; printf 'fx_inproc u\n. "$d/core/scripts/u.sh"\n' > "$P/core/fixtures/apinq/run.sh"
printf '# probe\naheld\tseeded\napheld\tseeded\n' > "$WORK/p-allow.txt"
# THE P2 RATCHET's worlds, inside this same probe tree so they cost no extra join: P becomes a git repo. Commit A is the
# base; commit M (origin/main) then adds an fx_inproc in rt8 and HEAD is reset to A, so the branch is BEHIND main and
# its merge-base is A. The tip working tree then edits A. A whole-repo git call drops GIT_DIR and its siblings (pgit):
# a pushing linked worktree exports GIT_DIR, and `git -C <probe repo>` would otherwise read the real repository.
#   rt  a, b, c unpaired; the tip deletes c, moves and re-indents a, edits b into b2, adds n: NEW n and b2, OWED a.
#   rt2 a paired drive whose fx_inproc the tip deletes: NEW.   rt3 the same, with `# fx_inproc u` left as a comment: NEW.
#   rt4 `echo hi` inserted between the fx_inproc and its drive: NEW.   rt5 a new drive inserted between them takes
#   the pairing and leaves the old one unpaired: NEW (the old one).   rt6 a paired drive deleted WITH its fx_inproc in a
#   file holding an owed drive: the owed one stays OWED (no wedge).   rt7 a line becomes a drive with no text change
#   because inputs.decl newly declares its subject (v.sh) `!`: NEW.   rt8 the branch is behind a main that paired its
#   drive: OWED (the base is the merge-base A, not origin/main).
pgit() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY \
  git -c user.name=probe -c user.email=probe@invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null -c init.defaultBranch=main \
  -c maintenance.auto=false "$@"; }
printf '#!/usr/bin/env bash\n:\n' > "$P/core/scripts/v.sh"
U1='. "$d/core/scripts/u.sh"'
mkf rt "1 *|$Z" -; printf '%s\n' "$U1 a" "$U1 b" "$U1 c" > "$P/core/fixtures/rt/run.sh"
for x in rt2 rt3 rt4 rt5; do mkf "$x" "1 *|$Z" -; printf '%s\n' 'fx_inproc u' "$U1 p" > "$P/core/fixtures/$x/run.sh"; done
mkf rt6 "1 *|$Z" -; printf '%s\n' 'fx_inproc u' "$U1 p" "$U1 q" > "$P/core/fixtures/rt6/run.sh"
mkf rt7 "1 *|$Z" -; printf '%s\n' '. "$d/core/scripts/v.sh" z' > "$P/core/fixtures/rt7/run.sh"
mkf rt8 "1 *|$Z" -; printf '%s\n' "$U1 r" > "$P/core/fixtures/rt8/run.sh"
rtok=0
{ pgit -C "$P" init -q && pgit -C "$P" add -A && pgit -C "$P" commit -qm A \
  && printf '%s\n' 'fx_inproc u' "$U1 r" > "$P/core/fixtures/rt8/run.sh" && pgit -C "$P" commit -qam M \
  && pgit -C "$P" update-ref refs/remotes/origin/main HEAD && pgit -C "$P" reset -q --hard HEAD~1; } >/dev/null 2>&1 || rtok=1
printf '%s\n' ':' ':' "  $U1   a" "$U1 n" "$U1 b2" > "$P/core/fixtures/rt/run.sh"
printf '%s\n' ':' "$U1 p" > "$P/core/fixtures/rt2/run.sh"
printf '%s\n' '# fx_inproc u' "$U1 p" > "$P/core/fixtures/rt3/run.sh"
printf '%s\n' 'fx_inproc u' 'echo hi' "$U1 p" > "$P/core/fixtures/rt4/run.sh"
printf '%s\n' 'fx_inproc u' "$U1 n" "$U1 p" > "$P/core/fixtures/rt5/run.sh"
printf '%s\n' "$U1 q" > "$P/core/fixtures/rt6/run.sh"
printf '!core/scripts/v.sh\n' >> "$P/core/fixtures/rt7/inputs.decl"; printf '0 core/scripts/v.sh\n' >> "$P/core/fixtures/rt7/invocations.decl"
pbok=0; p2_base "$P" "$WORK/pbase" pgit || pbok=1
PBD=""; [ "$pbok" = 0 ] && PBD="$WORK/pbase"
if judge_tree "$P" "$WORK/p" "$PBD"; then
  p2_ratchet "$P" "$WORK/p" -
  verdict "$P" "$WORK/p" "$WORK/p-allow.txt" > "$WORK/p.v"; pv=$?
  P2W='the source of unguarded bash subject core/scripts/u.sh ($d/core/scripts/u.sh) -- an unrouted in-process pass: call fx_inproc <subject> on the line before it and declare the pass as an inproc: row'
  want="$(printf '%s\n' \
    'C2 adup:2: cell id a is declared twice (first at line 1)' \
    'C4 awhy:2: an empty why= on an e2e row' \
    'C5 adata:1: cli subject core/scripts/d.sh carries no column-0 BASH_SOURCE source guard statement' \
    'C5 aunq:1: cli subject core/scripts/u.sh carries no column-0 BASH_SOURCE source guard statement' \
    'NP anp:2: the nested row'"'"'s parent core/fixtures/anp/drv.sh lies under core/fixtures/ -- a fixture-local driver would cover any number of starts of core/scripts/g.sh; a nested parent must be shipped code' \
    "P2 apheld:apheld/run.sh:1: $P2W" \
    "P2 apin:apin/run.sh:1: $P2W" \
    "P2 rt2:rt2/run.sh:2: $P2W" \
    "P2 rt3:rt3/run.sh:2: $P2W" \
    "P2 rt4:rt4/run.sh:3: $P2W" \
    "P2 rt5:rt5/run.sh:3: $P2W" \
    "P2 rt6:rt6/run.sh:1: $P2W" \
    "P2 rt7:rt7/run.sh:1: ${P2W//u.sh/v.sh}" \
    "P2 rt8:rt8/run.sh:1: $P2W" \
    "P2 rt:rt/run.sh:3: $P2W" \
    "P2 rt:rt/run.sh:4: $P2W" \
    "P2 rt:rt/run.sh:5: $P2W" \
    'R adata: static finding(s) above' \
    'R adup: core/scripts/g.sh declares 2 start(s) against 1 cell(s)' \
    'R aextra: core/scripts/g.sh declares 2 start(s) against 1 cell(s)' \
    'R anew: core/scripts/g.sh declares 1 start(s) against 0 cell(s)' \
    'R aunq: static finding(s) above' \
    'R awhy: core/scripts/g.sh declares 2 start(s) against 1 cell(s)')"
  if [ "$pv" = 1 ] && [ "$(cat "$WORK/p.v")" = "$want" ]; then
    spl ok "FIRES: a subject start with no cells.decl (anew), an extra start (aextra), a duplicate id (adup), an empty why= (awhy), an unguarded cli subject (aunq), a guard token inside a data string (adata), a nested row whose parent is a fixture-local driver (anp, NP), an unrouted in-process drive in a fixture not opted in (apin, P2) and the same drive in an allowlisted fixture (apheld, P2 printed allowlisted or not); QUIET: the fixed twins aok, azero, ae2e, aunqe (an e2e row needs no guard), a nested row whose parent is shipped core/scripts/g.sh (anpq), the paired drive apinq and the allowlisted aheld"
  else spl FAIL "the probe verdict (rc $pv) was: $(tr '\n' '|' < "$WORK/p.v"), want: $(printf '%s' "$want" | tr '\n' '|')"; fi
  grep -qxF 'EXEMPT (undeclarable) und' "$WORK/p.census" && grep -qxF 'O	und	undeclarable' "$WORK/p.join" \
    && spl ok "EXEMPT (undeclarable) printed from the B2 census, and the join holds it out of population" || spl FAIL "the undeclarable probe fixture's EXEMPT line"
  derive_rows "$WORK/p" > "$WORK/p.d1"; derive_rows "$WORK/p" > "$WORK/p.d2"
  if cmp -s "$WORK/p.d1" "$WORK/p.d2" && [ "$(cut -f1 "$WORK/p.d1" | tr '\n' ' ')" = "adata adup aextra aheld anew aunq awhy " ] \
      && [ "$(awk -F'\t' '$1 == "anew" { print $2 }' "$WORK/p.d1")" = "core/scripts/g.sh runs outside a declared cell" ]; then
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
# COST, with GIT_DIR unset (`--complete`, same-tree swap at 3f3b99ae1, two agreeing runs per side): bash starts 5 -> 5,
# git processes 35 -> 14 (under the M4 probe repos 30 -> 11, two auto-maintenance children 2 -> 0); output byte-identical.
# M4's six cases on THIS list, through the shared m4 with this file's rel, arm and remedy. The scratch repos come from
# the shared m4_probe_repo (one fast-import each). A case with a repo runs the whole of m4 with the corpus call's own
# arguments (once per origin/main state: added, nofile, noorigin); a case with - runs m4cmp alone over the base the
# `added` case wrote. The remedy check reads the `added` case's own whole-m4 output, so m4's hand-off of this file's
# remedy to m4cmp is what it reads. A whole-m4 case drops GIT_DIR and its siblings, as validate-fixture-hygiene.sh's
# M4 cases do: a pushing linked worktree exports GIT_DIR, and `git -C <probe repo>` then reads the real repository.
R="$WORK/m4-base"; RN="$WORK/m4-nofile"; RX="$WORK/m4-noorigin"
{ m4_probe_repo "$R" "$ALLOW_REL" $'# base\na\tr1\nb\tr2\n' && m4_probe_repo "$RN" other $'x\n' && m4_probe_repo "$RX"; } >/dev/null 2>&1 \
  || { echo "validate-fixture-inprocess: REFUSED -- could not build the M4 probe repos" >&2; exit 2; }
M4GOT=""
m4c() { # <label> <repo | -> <want rc> <want first line> <rows...>
  local lab="$1" repo="$2" wrc="$3" want="$4" got rc; shift 4
  printf '# probe list\n' > "$WORK/m4-cur.txt"; printf '%s\n' "$@" >> "$WORK/m4-cur.txt"
  if [ "$repo" = - ]; then got="$(m4cmp "$WORK/m4-cur.txt" "$WORK/m4-b.added.txt" "$ALLOW_REL" M4 "$M4_REMEDY" fixture)"; rc=$?
  else got="$(unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_OBJECT_DIRECTORY
              m4 "$repo" "$WORK/m4-cur.txt" "$WORK/m4-b.$lab.txt" "$ALLOW_REL" M4 "$M4_REMEDY")"; rc=$?; fi
  M4GOT="$got"
  [ "$rc" = "$wrc" ] && [ "$(printf '%s\n' "$got" | head -1)" = "$want" ] && return 0
  spl FAIL "M4 case $lab: rc $rc, want $wrc: $(printf '%s' "$got" | head -2 | tr '\n' ' ')"; return 1
}
M4F="FAIL M4: allowlist row(s) whose fixture is not on $ALLOW_REL at origin/main -- the list is DOWN-ONLY:"
M4O="OK M4: no allowlist row added against origin/main"
m4ok=0
m4c added "$R" 1 "$M4F" "$(printf 'a\tr1')" "$(printf 'b\tr2')" "$(printf 'c\tr3')" || m4ok=1
grep -qxF "  Remedy: $M4_REMEDY" <<<"$M4GOT" || { spl FAIL "M4 the added-row failure does not carry this list's remedy"; m4ok=1; }
m4c swap - 1 "$M4F" "$(printf 'a\tr1')" "$(printf 'c\tr3')" || m4ok=1
m4c shrink - 0 "$M4O" "$(printf 'a\tr1')" || m4ok=1
m4c reworded - 0 "$M4O" "$(printf 'a\tother words')" "$(printf 'b\tr2')" || m4ok=1
m4c nofile "$RN" 0 "SKIP M4: origin/main carries no $ALLOW_REL -- this is the release that first ships it" "$(printf 'c\tr')" || m4ok=1
m4c noorigin "$RX" 0 "SKIP M4: origin/main does not resolve here, so there is no base allowlist to compare against" "$(printf 'c\tr')" || m4ok=1
[ "$m4ok" = 0 ] && spl ok "M4 on $ALLOW_REL: added and swapped rows refused with this list's remedy; shrink and a reworded reason pass; both no-base states SKIP"
# THE P2 RATCHET in ONE run, over the probe tree's own join and its scanned merge-base (the rt worlds above). Then the
# same rows with no push base are REFUSED (rc 2), never acquitted, and p2_base reports no base once origin/main is gone.
if [ "$rtok" = 0 ] && [ "$pbok" = 0 ] && [ -f "$WORK/p.join" ]; then
  p2_ratchet "$P" "$WORK/p" base > "$WORK/rt.msg" 2>&1; rr=$?
  got="$(awk -F'\t' '$2 ~ /^rt[0-9]?$/' "$WORK/p.p2cls" | LC_ALL=C sort | tr '\t\n' ' |')"
  wnt="NEW rt rt/run.sh:4|NEW rt rt/run.sh:5|NEW rt2 rt2/run.sh:2|NEW rt3 rt3/run.sh:2|NEW rt4 rt4/run.sh:3|NEW rt5 rt5/run.sh:3|NEW rt7 rt7/run.sh:1|OWED rt rt/run.sh:3|OWED rt6 rt6/run.sh:1|OWED rt8 rt8/run.sh:1|"
  [ "$rr" = 0 ] && [ "$got" = "$wnt" ] \
    && spl ok "P2 RATCHET: NEW an added drive, an edited owed one, a deleted fx_inproc, one left as a comment, an echo between, a new drive taking the pairing, a subject newly declared; OWED a moved re-indented one, an owed drive beside a paired drive deleted with its fx_inproc, and one a later main paired (base = merge-base); a pure deletion prints nothing" \
    || spl FAIL "P2 RATCHET: rc $rr, classified [$got], want [$wnt]"
  awk -F'\t' '$1 != "BASEROOT" && $1 != "B"' "$WORK/p.join" > "$WORK/nb.join"
  p2_ratchet "$P" "$WORK/nb" base > "$WORK/rt.msg" 2>&1; rr=$?
  pgit -C "$P" update-ref -d refs/remotes/origin/main >/dev/null 2>&1
  p2_base "$P" "$WORK/pbase2" pgit; pb2=$?
  [ "$rr" = 2 ] && grep -qF 'REFUSED P2 ratchet' "$WORK/rt.msg" && [ "$pb2" = 1 ] \
    && spl ok "P2 RATCHET: with no push base the same rows are REFUSED (rc 2), never acquitted, and p2_base reports none once origin/main is gone" || spl FAIL "P2 RATCHET: no base gave rc $rr, p2_base rc $pb2"
else spl FAIL "P2 RATCHET: the probe tree could not be committed or its base materialised (rc $rtok, base $pbok)"; fi
if [ "$SP_RED" != 0 ]; then echo "validate-fixture-inprocess: REFUSED -- the self-probe is red, so a verdict over the tree is unattributable" >&2; exit 2; fi

# --- the corpus -----------------------------------------------------------------------------------------------------
CBASE=""; p2_base "$ROOT" "$WORK/cbase" git && CBASE="$WORK/cbase"
judge_tree "$ROOT" "$WORK/c" "$CBASE"; jr=$?
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
      "# conversion deletes its fixture's row in the same change, and the invocation judge FAILs a listed fixture that passes." \
      "# The reason names the subjects and carries NO count: nothing reads field 2, so a name that goes stale is accepted, and the" \
      "# live count is the validator's R diagnostic, computed fresh on every run."
    derive_rows "$WORK/c"; } > "$ROOT/$ALLOW_REL.tmp.$$" && mv "$ROOT/$ALLOW_REL.tmp.$$" "$ROOT/$ALLOW_REL" \
    || { echo "validate-fixture-inprocess: could not write $ROOT/$ALLOW_REL" >&2; exit 2; }
  echo "validate-fixture-inprocess: --derive wrote $(awk -F'\t' '$0 !~ /^[[:space:]]*(#|$)/' "$ROOT/$ALLOW_REL" | awk 'END { print NR }') row(s) to $ALLOW_REL"
  exit 0
fi
rc=0
p2_ratchet "$ROOT" "$WORK/c" base || exit 2
verdict "$ROOT" "$WORK/c" "$ROOT/$ALLOW_REL" > "$WORK/c.v"; vr=$?
[ "$vr" = 2 ] && { cat "$WORK/c.v" >&2; exit 2; }
grep '^EXEMPT (undeclarable) ' "$WORK/c.census"
nsc="$(cat "$WORK/c.listed")"
nal="$(awk 'END { print NR }' "$WORK/c.al")"
nx="$(grep -c '^X	' "$WORK/c.join")" || nx=0
np="$(grep -c '^P	' "$WORK/c.join")" || np=0
no="$(grep -c '^O	' "$WORK/c.join")" || no=0
nxp="$(awk -F'\t' '$1 == "X" && $3 == "static finding(s) above" { X[$2] = 1 } $1 == "E" { if ($3 == "P2") HP[$2] = 1; else NP2[$2] = 1 }
  END { for (f in X) if ((f in HP) && !(f in NP2)) n++; print n + 0 }' "$WORK/c.join")"
echo "validate-fixture-inprocess: judges GRAMMAR only (the dynamic C1-C3 run per counted run in the invocation judge); $nsc fixture(s) scanned; $np predicted to pass, $nx refused ($nxp of them for P2 rows alone, which the P2 ratchet judges), $no out of population; $nal allowlist row(s)"
if [ -s "$WORK/c.ow" ]; then
  sed 's/^/  /' "$WORK/c.ow"
  echo "P2 OWED: $(awk 'END { print NR }' "$WORK/c.ow") unpaired in-process drive(s) already present at the push base (merge-base of HEAD and origin/main), in $(awk '{ s = $3; sub(/:.*/, "", s); F[s] = 1 } END { for (f in F) n++; print n + 0 }' "$WORK/c.ow") fixture(s) -- not failing (the P2 ratchet); BL-982 names them as its remainder"
fi
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
