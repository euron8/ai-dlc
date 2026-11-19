#!/usr/bin/env bash
# validate-fixture-inprocess.sh -- BL-879's STATIC half: the cells.decl grammar, the source guard on a `cli` subject,
# and the down-only scripts/fixture-inprocess-allowlist.txt. IT JUDGES GRAMMAR ONLY. Whether a fixture runs a subject
# as a separate program outside a declared cell is decided per counted run by the invocation judge's DYNAMIC arms
# (C1, C2's every-tag-is-declared half, C3, and the stale allowlist row), in scripts/validate-fixture-invocations.sh's
# fxc_judge, which core/scripts/hermetic-run.sh calls once per counted run; the hook's post-suite summary names every
# declared fixture with no counted pass under the current judge as PENDING.
#
# usage:  validate-fixture-inprocess.sh [--root R]             the gate (exit 0 clean, 1 FAIL, 2 refused)
#         validate-fixture-inprocess.sh --complete [--root R]  the gate, AND non-zero while any allowlist row remains or
#                                                              when zero fixtures were scanned (BL-878's receipt); a
#                                                              refusal CAUSED BY AN ABSENT OR UNOPENABLE INPUT (a sibling
#                                                              validator, a `cli` subject) exits 9 here, the ledger's
#                                                              could-not-measure code, and 2 in every other mode
#                                                              (absent_refuse); every other refusal exits 2
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
#       fixture refused for P2 rows alone takes no R row and no --derive allowlist row. A fixture `<family>-<letter>`
#       whose run.sh passes M4's shard-driver predicate (sf_driver, below) is judged under <family>'s name, each
#       (family, file:line) counted once (p2_shard_map): a shard reads its family's OWED baseline and acquits nothing new.
#       Its counting unit, pairing rule,
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
#       ONE NARROWING, by m4sf below: a row `<family>-<letter>` is not an ADDED row when (1) `<family>` is on the
#       origin/main list, (2) core/fixtures/<family>-<letter>/run.sh is a shard driver of that family -- exactly the eight
#       non-comment lines sf_driver names, ending in `exec bash "$IMPL" --group <letter>`, no other command -- and (3) the
#       family's own row is still on the current list. A shard split of a listed subject is a scheduling boundary and
#       starts it no more often than the family did; any other new row is still refused.
#       HOW ITS FALSE-POSITIVE SET REACHED ZERO: the first shape accepted any run.sh whose last line was an exec of the
#       sibling; a body of real commands before that exec passed it. The shape is now the whole file, line by line, and the
#       message line may carry no quote, `$`, backtick or backslash, so no second command rides in the echo.
#   N   scanned == listed: the join's per-fixture F rows must equal the count of core/fixtures/*/run.sh this script
#       listed, else REFUSED (an awk that never opened a file reads exactly like a clean one). Zero listed is REFUSED.
#   EXEMPT (undeclarable): printed from `validate-fixture-invocations.sh --b2-census`, the static walk over
#       core/fixtures/*/.undeclarable, never from the judge (which is never called for them).
#
#   W   a SHIPPING fixture (no .dist-only) whose run.sh loads a subject in process (inproc_load, inproc_run or fx_inproc,
#       outside a column-0 function body) and whose own code, BEFORE that first load, does not carry both wrap-half checks
#       -- a non-comment line that is a grep for the source guard `[ "${BASH_SOURCE[0]}" = "$0" ]` and a non-comment line
#       that is a grep for an entry line `<p>_main() {` -- FAILs: a consumer one pull behind carries the fixture with a
#       subject that predates the wrap, and the load would run its whole body (the gate is gate-resume's, through
#       lib/layout.sh fx_skip_exit). Bound to the emission site: a comment, or a gate AFTER the load, does not satisfy it.
#       W2 (the blind route, measured): a shipping fixture whose in-process loads sit ONLY inside column-0 function
#       bodies (18 at this commit, gate-resume among them) FAILs unless its non-comment code carries a source-guard line
#       and an entry-line (`() {` closed by a quote or `$`) line anywhere. File order against the function is NOT read:
#       the first-call widening read 11 ungated, 6 or more of them false (a gate present, a name collision on the way).
#       Three are exempt by name, and none is a wrapped subject this arm could gate: consumer-suite-pool and
#       postcompact-rulebook-recovery load UNWRAPPED subjects (the pre-push hooks and core/hooks/*.sh carry neither the
#       entry line nor the guard), push-drain-refusals checks only the `pd_main() {` half and degrades to a NOTE.
#       Measured gap, fixed in this change: review-reroute and wait-beat-liveness sourced a WRAPPED subject with no gate.
#       W3 (operand count): each wrapped subject (guard line plus `<p>_main() {` line) a loader has an `inproc:` row for
#       needs one source-guard grep line of its own, so one gate cannot cover a second subject. A gate spelled as a helper
#       called once per subject reads as one grep line, so the 12 fixtures below are OWED, enumerated in w_owed with the
#       count form (S wrapped subjects against O grep lines): cycle-commits-enforce 1/0, gate-resume 2/1,
#       layer-catalog-collision 3/1, layer-qualifier-grain 2/1, layer-readopt-gate 3/2, push-drain-refusals 1/0,
#       retro-audit-scans 2/1, story-evidence-scaffold 3/1, story-provenance 2/1, trunk-audit-gate 2/1,
#       upstream-routing 2/1, wait-stale-deliverable 1/0. Whether each is a helper or a real second-subject gap is NOT
#       measured per fixture; a NEW fixture over its count FAILs. The arm cannot tell which subject a grep names.
#       NO BASE RATCHET, deliberately: with the six fixed (and review-reroute, wait-beat-liveness) the tip false-positive
#       set is zero, so a blanket arm wedges nothing and no base is needed to acquit anyone.
#       NARROWING TO ZERO (measured over 221 shipping run.sh, 88 loaders): a rule keyed on fx_skip_exit alone cannot fire
#       (60 run.sh call it for unrelated SKIPs; the gate is a hand-rolled halves check per fixture); the guard-token
#       plus `_main() {` pair read on the code before the first top-level load left 6 ungated, 2 of them falsely (emit-report-refusal and reconcile-emit-report were gated in
#       reconcile-emit-report/seed.sh:32-43, which this arm does not read; each now also carries a redundant run.sh gate
#       the arm requires) and 4 genuine (ledger-reverify, ledger-reverify-unfalsifiable, story-evidence-scaffold,
#       readset-skip); review-reroute and wait-beat-liveness, found by the widening, were genuine too. readset-skip-b, -c and -d load nothing in
#       their own run.sh (they exec the parent) and are no population. A gate that is a library call is not read.
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
# absent_refuse <what>: a refusal caused by an absent or unopenable input -- exit 9 under --complete (read by
# scripts/validate-backlog-receipts.sh's cm_reason as could-not-measure), 2 otherwise.
absent_refuse() { echo "validate-fixture-inprocess: REFUSED -- $1" >&2; [ "$MODE" = complete ] && exit 9; exit 2; }
for f in "$JUDGE" "$HYG"; do { [ -f "$f" ] && { : < "$f"; } 2>/dev/null; } || absent_refuse "$f is absent or unopenable"; done
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
p2_ix() { GIT_INDEX_FILE="$P2_IDX" git -C "$P2_R" "$@"; }
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
  p2_shard_map "$r" "$o" || { echo "REFUSED P2 ratchet: the shard map could not be built" >&2; return 2; }
  LC_ALL=C awk -F'\t' 'function fl(l) { sub(/:[0-9]+$/, "", l); return l }
    FILENAME == ARGV[1] { SM[$1 SUBSEP $2] = $3; next }
    $1 == "B" { f = (("B" SUBSEP $2) in SM) ? SM["B" SUBSEP $2] : $2; if ((f SUBSEP $3) in BS) next; BS[f SUBSEP $3] = 1
      BC[f SUBSEP fl($3) SUBSEP $4]++; next }
    $1 == "E" && $3 == "P2" { f = (("T" SUBSEP $2) in SM) ? SM["T" SUBSEP $2] : $2; k = f SUBSEP fl($4) SUBSEP $6
      if (!((f SUBSEP $4) in TS)) { TS[f SUBSEP $4] = 1; TC[k]++ }; N++; RK[N] = k; RF[N] = $2; RL[N] = $4 }
    END { for (i = 1; i <= N; i++) print ((TC[RK[i]] > BC[RK[i]] + 0) ? "NEW" : "OWED") "\t" RF[i] "\t" RL[i] }' "$o.p2map" "$o.join" > "$o.p2cls" \
    || { echo "REFUSED P2 ratchet: the ratchet awk failed" >&2; return 2; }
  return 0
}
# p2_shard_map <root> <out prefix>: writes <o>.p2map, one `T|B\t<fx>\t<family>` row per fixture named by a P2 row (T, at
# the tip <root>) or a B row (B, in the materialised push base, the BASEROOT dir) whose run.sh passes M4's shard-driver
# predicate sf_driver for `<family>-<letter>` in THAT tree. The ratchet then judges the row under the family's name and
# counts each (family, file:line) once, so a shard's scan of its family's file reads the family's OWED baseline and
# adds no count of its own: a drive newly unpaired in the family file still reads NEW, in the family and in every shard.
p2_shard_map() {
  local r="$1" o="$2" T=$'\t' a fx f loc rest br="" fam
  : > "$o.p2map" || return 1
  while IFS="$T" read -r a fx f loc rest; do [ "$a" = BASEROOT ] && br="$fx"; done < "$o.join"
  awk -F'\t' '($1 == "E" && $3 == "P2") || $1 == "B" { print ($1 == "E" ? "T" : "B") "\t" $2 }' "$o.join" | LC_ALL=C sort -u > "$o.p2cand" || return 1
  while IFS="$T" read -r a fx; do
    case "$fx" in *-[a-z]) ;; *) continue ;; esac
    fam="${fx%-?}"
    if [ "$a" = T ]; then sf_driver "$r/core/fixtures/$fx/run.sh" "$fam" "${fx##*-}" || continue
    else [ -n "$br" ] && sf_driver "$br/core/fixtures/$fx/run.sh" "$fam" "${fx##*-}" || continue; fi
    printf '%s\t%s\t%s\n' "$a" "$fx" "$fam" >> "$o.p2map"
  done < "$o.p2cand"
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

# THE SHARD NARROWING of M4 (header above). m4sf <git repo> <fixture root> <current list> <out list> writes the current
# list minus every row that qualifies, and m4 then judges the OUT list. It filters only; a row that does not qualify
# stays in the list and m4 refuses it as before.
sf_listed() { grep -qxF -- "$1" "$2"; }        # <name> <file of base field-1 names>: the row is not an added one
sf_famlisted() { grep -qxF -- "$1" "$2"; }     # condition 1: <family> <file of base field-1 names>
sf_famrow() { grep -qxF -- "$1" "$2"; }        # <family> <file of current field-1 names>
sf_driver() { # <run.sh> <family> <letter> -> 0 when the file is exactly a shard driver of <family> for <letter>
  local l n=0 msg
  [ -f "$1" ] || return 1
  while IFS= read -r l; do
    n=$((n + 1))
    case "$n" in
      1) [ "$l" = 'set -uo pipefail' ] || return 1 ;;
      2) [ "$l" = 'HERE="$(cd "$(dirname "$0")" && pwd)"' ] || return 1 ;;
      3) [ "$l" = "IMPL=\"\$HERE/../$2/run.sh\"" ] || return 1 ;;
      4) [ "$l" = '[ -f "$IMPL" ] || {' ] || return 1 ;;
      5) case "$l" in '  echo "'*'" >&2') ;; *) return 1 ;; esac
         msg="${l#  echo \"}"; msg="${msg%\" >&2}"
         case "$msg" in *'"'*|*'$'*|*'`'*|*'\'*) return 1 ;; esac ;;
      6) [ "$l" = '  exit 2' ] || return 1 ;;
      7) [ "$l" = '}' ] || return 1 ;;
      8) [ "$l" = "exec bash \"\$IMPL\" --group $3" ] || return 1 ;;
      *) return 1 ;;
    esac
  done < <(grep -v -E '^[[:space:]]*(#|$)' "$1")
  [ "$n" = 8 ]
}
m4sf() {
  local repo="$1" fx="$2" cur="$3" out="$4" base="$WORK/sf-base.$$" names="$WORK/sf-names.$$" f fam ltr
  if [ -f "$cur" ]; then cp "$cur" "$out" || return 1; else : > "$out" || return 1; fi
  git -C "$repo" cat-file -e "origin/main:$ALLOW_REL" 2>/dev/null || return 0
  git -C "$repo" show "origin/main:$ALLOW_REL" 2>/dev/null | awk -F'\t' '/^[[:space:]]*(#|$)/ { next } { x = $1; gsub(/[[:space:]]/, "", x); print x }' > "$base"
  awk -F'\t' '/^[[:space:]]*(#|$)/ { next } { x = $1; gsub(/[[:space:]]/, "", x); print x }' "$out" > "$names"
  while IFS= read -r f; do
    case "$f" in *-[a-z]) ;; *) continue ;; esac
    sf_listed "$f" "$base" && continue
    fam="${f%-?}"; ltr="${f##*-}"
    sf_famlisted "$fam" "$base" && sf_famrow "$fam" "$names" && sf_driver "$fx/core/fixtures/$f/run.sh" "$fam" "$ltr" || continue
    awk -F'\t' -v n="$f" '{ x = $1; gsub(/[[:space:]]/, "", x); if (x != n) print }' "$out" > "$out.t" && mv "$out.t" "$out"
  done < "$names"
  rm -f "$base" "$names"
  return 0
}

# --- the corpus -----------------------------------------------------------------------------------------------------
CBASE=""; p2_base "$ROOT" "$WORK/cbase" git && CBASE="$WORK/cbase"
judge_tree "$ROOT" "$WORK/c" "$CBASE"; jr=$?
case "$jr" in
  0) ;;
  3) echo "validate-fixture-inprocess: REFUSED -- zero core/fixtures/*/run.sh under $ROOT" >&2; exit 2 ;;
  *) echo "validate-fixture-inprocess: REFUSED -- the static join or the B2 census could not run: $(head -c 400 "$WORK/c.join.err")" >&2; exit 2 ;;
esac
# The join's `A` rows: a `cli` subject absent or unopenable under the root is an absent input, never a C5 finding.
if grep -q '^A	' "$WORK/c.join"; then
  absent_refuse "cli subject(s) absent or unopenable: $(awk -F'\t' '$1 == "A" { printf "%s%s", s, $2; s = " " }' "$WORK/c.join")"
fi
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
m4sf "$ROOT" "$ROOT" "$ROOT/$ALLOW_REL" "$WORK/m4-narrowed.txt" || rc=1
m4 "$ROOT" "$WORK/m4-narrowed.txt" "$WORK/m4-root.txt" "$ALLOW_REL" M4 "$M4_REMEDY" > "$WORK/m4.out"; [ $? = 0 ] || rc=1
cat "$WORK/m4.out"
# ARM W (header above): one awk over every shipping fixture's run.sh. A shipping fixture is one with no .dist-only.
# The Remedy below names gate-resume/run.sh as the reference gate; a gate-resume directory whose run.sh is gone is an absent
# input (exit 9 under --complete, BL-878's receipt contract), never a corpus one fixture smaller.
[ ! -d "$ROOT/core/fixtures/gate-resume" ] || [ -f "$ROOT/core/fixtures/gate-resume/run.sh" ] \
  || absent_refuse "arm W's reference gate core/fixtures/gate-resume/run.sh is absent"
w_files=""; w_n=0
for d in "$ROOT"/core/fixtures/*/; do
  [ -f "${d}run.sh" ] && [ ! -e "${d}.dist-only" ] || continue
  w_files="$w_files ${d}run.sh"; w_n=$((w_n + 1))
done
[ "$w_n" -gt 0 ] || { echo "validate-fixture-inprocess: REFUSED -- arm W found zero shipping run.sh under $ROOT" >&2; exit 2; }
# shellcheck disable=SC2086 # paths carry no whitespace; the split is the point
awk '
  FNR == 1 { if (fn != "") w_emit(); fn = FILENAME; L = 0; FB = 0; G1 = 0; G2 = 0; A1 = 0; A2 = 0; O = 0; infn = 0; nf++ }
  /^[[:space:]]*#/ { next }
  { line = $0
    if (line ~ /^[A-Za-z_][A-Za-z0-9_]*\(\) *\{/ && line !~ /\}[[:space:]]*$/) infn = 1
    if (line ~ /grep[^|]*BASH_SOURCE\[0\]\}" = "\$0"/) O++
    if (!G1 && !L && line ~ /grep[^|]*BASH_SOURCE\[0\]\}" = "\$0"/) G1 = FNR
    if (!G2 && !L && line ~ /grep[^|]*\(\) \{/) G2 = FNR
    if (!A1 && line ~ /BASH_SOURCE\[0\]\}" = "\$0"/) A1 = FNR
    if (!A2 && line ~ /\(\) \{(["\047$\\])/) A2 = FNR
    if (line ~ /(^|[^A-Za-z_])(inproc_load|inproc_run|fx_inproc)([^A-Za-z_]|$)/) { if (infn) FB = 1; else if (!L) L = FNR }
    if (infn && line ~ /^\}/) infn = 0 }
  function w_emit() {
    if (!L && !FB) return
    nl++
    if (L && !(G1 && G2)) printf "W %s:%d: the first in-process load has no pre-wrap gate before it (source-guard grep line %s, entry-line grep line %s)\n", fn, L, (G1 ? G1 : "absent"), (G2 ? G2 : "absent")
    if (!L && !(A1 && A2) && fn !~ /\/(consumer-suite-pool|postcompact-rulebook-recovery|push-drain-refusals)\/run\.sh$/) printf "W %s: loads only inside function bodies and carries no source-guard line and entry-line pair anywhere\n", fn
    printf "WO %s %d\n", fn, O }
  END { w_emit(); printf "WSCAN %d %d\n", nf, nl }' $w_files > "$WORK/w.out" 2>&1 || { echo "validate-fixture-inprocess: REFUSED -- arm W's awk failed" >&2; exit 2; }
w_sc="$(awk '$1 == "WSCAN" { print $2 }' "$WORK/w.out")"; w_ld="$(awk '$1 == "WSCAN" { print $3 }' "$WORK/w.out")"
[ "$w_sc" = "$w_n" ] || { echo "validate-fixture-inprocess: REFUSED W: listed $w_n shipping run.sh, awk scanned ${w_sc:-none}" >&2; exit 2; }
# W, operand count: a loader's invocations.decl names each wrapped subject (guard line and a `<p>_main() {` line) it has an
# inproc: row for; the fixture needs at least as many source-guard greps as wrapped subjects, so one gate cannot cover two.
w_decls=""
for d in "$ROOT"/core/fixtures/*/; do
  [ -f "${d}run.sh" ] && [ ! -e "${d}.dist-only" ] && [ -f "${d}invocations.decl" ] && w_decls="$w_decls ${d}invocations.decl"
done
# shellcheck disable=SC2086
awk '$2 ~ /^inproc:/ { s = $2; sub(/^inproc:/, "", s); n = split(FILENAME, p, "/"); print p[n - 1] "\t" s }' $w_decls | LC_ALL=C sort -u > "$WORK/w.pairs"
w_subj=""
for s in $(cut -f2 "$WORK/w.pairs" | LC_ALL=C sort -u); do [ -f "$ROOT/$s" ] && w_subj="$w_subj $ROOT/$s"; done
# shellcheck disable=SC2086
awk 'FNR == 1 { if (f != "" && g && e) print substr(f, length(R) + 2); f = FILENAME; g = 0; e = 0 }
  $0 == "[ \"${BASH_SOURCE[0]}\" = \"$0\" ] || return 0" { g = 1 }
  /^[a-z_]+_main\(\) \{/ { e = 1 }
  END { if (f != "" && g && e) print substr(f, length(R) + 2) }' R="$ROOT" $w_subj | LC_ALL=C sort -u > "$WORK/w.wrapped"
grep -q . "$WORK/w.wrapped" || [ -z "$w_subj" ] || { echo "validate-fixture-inprocess: REFUSED W: no wrapped subject among the inproc: rows" >&2; exit 2; }
awk -F'\t' 'FILENAME == ARGV[1] { W[$1] = 1; next }
  FILENAME == ARGV[2] { if (($2 in W)) S[$1]++; next }
  FILENAME == ARGV[3] { split($0, a, " "); nm = a[2]; sub(/\/run\.sh$/, "", nm); n = split(nm, q, "/"); O[q[n]] = a[3] + 0 }
  END { for (f in O) if (S[f] > O[f]) printf "%s\tW core/fixtures/%s/run.sh: %d wrapped subject(s) with an inproc: row, %d source-guard grep(s) -- one gate cannot cover them all\n", f, f, S[f], O[f] }' \
  "$WORK/w.wrapped" "$WORK/w.pairs" <(grep '^WO ' "$WORK/w.out") | LC_ALL=C sort > "$WORK/w3.raw"
w_owed=" cycle-commits-enforce gate-resume layer-catalog-collision layer-qualifier-grain layer-readopt-gate push-drain-refusals retro-audit-scans story-evidence-scaffold story-provenance trunk-audit-gate upstream-routing wait-stale-deliverable "
awk -F'\t' -v o="$w_owed" 'index(o, " " $1 " ") == 0 { print $2 }' "$WORK/w3.raw" >> "$WORK/w.out"
if grep -q '^W ' "$WORK/w.out"; then
  rc=1
  grep '^W ' "$WORK/w.out" | LC_ALL=C sort | sed -e "s#$ROOT/##" -e 's/^/  FAIL  /'
  echo "  Remedy: before the first load, grep -qxF the subject for its \`<p>_main() {\` line and for the column-0 source guard, and on neither half SKIP through lib/layout.sh fx_skip_exit (core/fixtures/gate-resume/run.sh gr_halves); exactly one half FAILs."
fi
echo "validate-fixture-inprocess: arm W scanned $w_n shipping run.sh, $w_ld in-process loader(s)"
if [ "$MODE" = complete ]; then
  if [ "$nsc" -eq 0 ]; then echo "  INCOMPLETE  zero fixtures scanned"; rc=1
  elif [ "$nal" -gt 0 ]; then echo "  INCOMPLETE  $nal allowlist row(s) remain in $ALLOW_REL"; rc=1; fi
fi
[ "$rc" = 0 ] && echo "OK: validate-fixture-inprocess -- $nsc fixture(s) scanned; no static finding; no unlisted refusal; the allowlist is down-only"
exit "$rc"
