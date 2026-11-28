#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# adversarial-shard-merge/run.sh -- merge-adversarial-shards.sh, the JOIN that turns one
# adversary per story ordinal plus one cross-story adversary into the ONE pass file every gate
# reads. Its behavioural arms; the predicates and worlds live in `lib.sh` beside this file.
# The hard-coded `@` expectations go red in a consumer whose pair readers were carried at their pre-`@`
# version; read such a red as "a reader is carried", not as a merge or join regression.
#
# WHY A FIXTURE OF ITS OWN. No existing fixture owns this script: check-24-adversarial-convergence
# owns the convergence validator the merge's OUTPUT feeds, and it seeds pass files directly, so it
# never runs the merge. The merge is a new program with its own refusals, and its one
# load-bearing claim -- the merged verdict is RECOMPUTED from the summed residue, never taken from
# a shard -- is invisible to anything that only reads a finished pass file.
#
# THE DISCRIMINATING INPUT (B3). Three per-ordinal shards each holding 2 blocking MAJOR, each
# honestly stamped EXIT_CONDITION_MET because 2 is under the ceiling, and a clean cross shard. The
# artifact holds 6. A merge that took the worst shard verdict, or any one shard verdict, says MET;
# the recomputed verdict is NOT_MET, and the convergence validator must ACCEPT the merged file
# (--cycle-state CONTINUE, exit 0) rather than refuse it as unparseable.
#
# SEEDS ARE REAL CONSUMER BYTES, TRIMMED. `seed.<basename>` are the first 12 lines of three story
# files from one reference-consumer sprint, chosen because their LC_ALL=C order puts two
# NON-`story-` files (`192-ff-...`, `bug-...`) at ordinals 1 and 2: an ordinal key that only
# understood `story-<n>-` would refuse or mis-key them. `seed.finding-headings.txt` is the heading
# list of a real multi-story adversarial pass; every shard finding carries one of those titles.
# Only the severity word and the `stories:` line are added, because the real pass predates the
# shard grammar (see arm R6, which runs a heading exactly as the real pass wrote it).
#
# SECTION MODE (--document, arms D0-D6). `seed.doc-test-strategy.md` is a real consumer
# single-file artifact that partition-document.sh --map splits into three parts, and
# `seed.doc-serial-epics.md` a real one it calls SERIAL; D0 reads both off --map rather than
# assuming them. D2's seed is the one the receipt could not build: a finding carrying ONE
# `sections:` line and a `stories:` line, so the one-citation count passes it and only the axis
# guard refuses. D4's
# shard names a byte-identical COPY of the document, so the sha check passes and only the path
# check refuses; D3 is the mirror, the right path with other bytes' sha.
# `seed.files-b3-merged.expected` is the B3 output of the merge BEFORE section mode existed
# (origin/main at dd7e40ad), so D6 holds files mode to its old bytes rather than to whatever the
# current merge prints. Regenerated once for the cross groups (BL-464): K=3 now owes cross-1..3,
# and the diff against the earlier golden is confined to the cross headers, the shard count and
# the two id lines -- every ordinal shard's body is byte-identical. Regenerated again when the
# dispatch ids became DERIVED from the harness records: the diff is confined to the same two id
# lines (lines 118-119), now carrying the ids lib.sh's hr_ids derives from each shard's dir and name.
#
# Every arm that scores a merge calls its predicate as `p_<name> "$MERGE"` at the start of a
# line.
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="adversarial-shard-merge"
[ -f "$HERE/lib.sh" ] || { echo "FIXTURE BROKEN: $HERE/lib.sh is absent; nothing was asserted" >&2; exit 2; }
# ---------------------------------------------------------------------------- shards (BL-1095)
# THIS FILE IS FOUR SHARDS OF ONE FIXTURE, AND THE SPLIT IS A SCHEDULING BOUNDARY, NOT A SUBJECT BOUNDARY (the
# check-24-adversarial-convergence shape). Every arm section below is a UNIT guarded by `if sg <unit>; then` ... `fi # sg
# <unit>`, and `--group <x>` runs the units dealt to shard <x>. The siblings `adversarial-shard-merge-{b,c,d}/run.sh`
# are 8-line drivers that exec this file with their group, so the pre-push pool starts each on its own; no `--group`
# is shard a. The functions the units share (eq_pair, eq_arm) sit outside every unit; the rest of a unit's functions
# are defined by the unit.
#   a  core subj doc rs ch h   B3/clean files mode, the CLI seam (EQ), section mode D, subject mode U, --check-header, the
#                              reserved-form refusals, the cross-owner arms
#   b  xs fi fg                X (K=8 cross groups), the series stem S, the finding id FI, fences. DIST-ONLY: the shipped
#                              merge in place over worlds this file builds
#   c  dv b726 ri              the derived set DV/PC (BL-911), BL726, the repair-introduced class RI (BL-1175)
#   d  rr sd cs k t            re-run RR/DW, the summed prior scope, --check-shard CS, arm K, the dispatch id T (the
#                              real remediation-guard hook in place)
SHARDS="a b c d"
UNITS_a="core subj doc rs ch h"
UNITS_b="xs fi fg"
UNITS_c="dv b726 ri"
UNITS_d="rr sd cs k t"
DIST_SHARDS="b"
# The units whose verdict can depend on placement; the join fails if one is undeclared or dealt to a DIST_SHARDS
# shard: core runs the in-place merge CLI and --pair-sep readers; dv reads the located rulebook and runs the
# validator siblings in place; b726 reads the installed provenance schema; cs runs wait-for-deliverable in place;
# k reads the located schema; t drives the real located remediation-guard hook; ri runs the validator sibling in place.
PLACED_UNITS="core dv b726 cs k t ri"
GROUP=a
while [ $# -gt 0 ]; do
  _a="$1"; shift
  case "$_a" in
    --group) GROUP="${1:-}"; [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }; shift ;;
    *) echo "FIXTURE ERROR: unknown argument '$_a' (usage: run.sh [--group <shard>])" >&2; exit 2 ;;
  esac
done
case " $SHARDS " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac
[ "$GROUP" = a ] || NAME="adversarial-shard-merge-$GROUP"
broken() { printf '  FAIL  %s\n' "$1" >&2; echo "$NAME: FIXTURE BROKEN" >&2; exit 2; }
eval "DEALT=\"\${UNITS_$GROUP:-}\""
[ -n "$DEALT" ] || broken "shard '$GROUP' has no UNITS_$GROUP list; a shard dealt nothing passes everything it never checked"
sg() { case " $DEALT " in *" $1 "*) return 0 ;; esac; return 1; }
partition_ok() { # <declared ids file> <dealt ids file> -> 0 when dealt is disjoint and covers declared exactly
  local dup miss extra
  dup="$(sort "$2" | uniq -d | tr '\n' ' ')"
  miss="$(sort -u "$2" | comm -23 <(sort -u "$1") - | tr '\n' ' ')"
  extra="$(sort -u "$2" | comm -13 <(sort -u "$1") - | tr '\n' ' ')"
  [ -z "$dup$miss$extra" ] && return 0
  echo "dealt twice: {${dup% }} dealt to no shard: {${miss% }} dealt but not declared: {${extra% }}"
  return 1
}
# The ok lines of an arm outside every unit guard, after the arms' start: each would run in every shard.
ok_outside_units() { # <run.sh> -> the count of `ok "<LABEL>:` lines outside an `if sg` unit
  awk '/^echo "\$NAME:"$/ { on = 1 } /^if sg [a-z0-9_]+; then$/ { u = 1 } /^fi # sg [a-z0-9_]+$/ { u = 0 }
    on && !u && /ok "[A-Z][A-Za-z0-9_.-]*:/ { n++ } END { print n + 0 }' "$1"
}
JW="$(mktemp -d "${TMPDIR:-/tmp}/adv-join.XXXXXX")" || broken "mktemp failed"
printf '%s\n' u1 u2 u3 > "$JW/pd"; printf '%s\n' u1 u2 u2 u3 > "$JW/pdup"; printf '%s\n' u1 u3 > "$JW/pmiss"; printf '%s\n' u3 u1 u2 > "$JW/pok"
if partition_ok "$JW/pd" "$JW/pdup" > /dev/null || partition_ok "$JW/pd" "$JW/pmiss" > /dev/null \
   || ! partition_ok "$JW/pd" "$JW/pok" > /dev/null; then
  rm -rf "$JW"; broken "the coverage join's self-probe did not discriminate (duplicate, omission, exact)"
fi
printf '%s\n' 'echo "$NAME:"' 'if sg u; then' 'ok "A1: x"' 'fi # sg u' > "$JW/probe-in"
printf '%s\n' 'echo "$NAME:"' 'ok "A1: x"' 'if sg u; then' 'fi # sg u' > "$JW/probe-out"
if [ "$(ok_outside_units "$JW/probe-in")" != 0 ] || [ "$(ok_outside_units "$JW/probe-out")" != 1 ]; then
  rm -rf "$JW"; broken "the coverage join's unit-guard probe did not discriminate (an ok line outside a unit)"
fi
SELF="$HERE/run.sh"
[ -f "$SELF" ] || { rm -rf "$JW"; broken "cannot read $SELF for the coverage join"; }
sed -n 's/^if sg \([a-z0-9_][a-z0-9_]*\); then$/\1/p' "$SELF" > "$JW/declared"
for _s in $SHARDS; do eval "printf '%s\n' \${UNITS_$_s}" | tr ' ' '\n'; done | grep . > "$JW/dealt"
_ndecl="$(grep -c . "$JW/declared")" || _ndecl=0
_ndup="$(sort "$JW/declared" | uniq -d | grep -c .)" || _ndup=0
[ "$_ndecl" -gt 0 ] && [ "$_ndup" = 0 ] || { rm -rf "$JW"; broken "$_ndecl unit guards derived from $SELF ($_ndup declared twice)"; }
_why="$(partition_ok "$JW/declared" "$JW/dealt")" || { rm -rf "$JW"; broken "the shard partition does not cover the guarded units exactly -- $_why"; }
_decl=" "; while IFS= read -r _l; do _decl="$_decl$_l "; done < "$JW/declared"
for _u in $PLACED_UNITS; do
  case "$_decl" in *" $_u "*) ;; *) rm -rf "$JW"; broken "PLACED_UNITS names '$_u', which no unit guard declares" ;; esac
  for _s in $DIST_SHARDS; do
    eval "_l=\" \${UNITS_$_s} \""
    case "$_l" in *" $_u "*) rm -rf "$JW"; broken "unit '$_u' is in PLACED_UNITS but is dealt to dist-only shard '$_s'; it must stay in a shipped shard" ;; esac
  done
done
# THE DIST-ONLY SHARDS: DIST_SHARDS reach no consumer. Each carries a non-empty .dist-only and no other shard does,
# and a consumer holds none of their directories, so only a DIST_SHARDS shard, whose inputs.decl declares its
# dist-only siblings, checks their drivers and markers; a shipped shard declares none and skips them.
case " $DIST_SHARDS " in *" $GROUP "*) _me=dist ;; *) _me=ship ;; esac
[ ! -e "$HERE/.dist-only" ] || { rm -rf "$JW"; broken "shard 'a' carries $HERE/.dist-only, but shard a ships"; }
for _s in $SHARDS; do
  [ "$_s" = a ] && continue
  case " $DIST_SHARDS " in *" $_s "*) _do=1 ;; *) _do=0 ;; esac
  [ "$_do" = 1 ] && [ "$_me" = ship ] && continue
  _drv="$HERE/../adversarial-shard-merge-$_s/run.sh"
  [ -f "$_drv" ] && grep -qF -- "--group $_s" "$_drv" || { rm -rf "$JW"; broken "shard '$_s' is declared but $_drv does not drive it"; }
  [ "$_do" = 0 ] || [ -s "${_drv%/run.sh}/.dist-only" ] || { rm -rf "$JW"; broken "shard '$_s' is in DIST_SHARDS but ${_drv%/run.sh}/.dist-only is absent or empty"; }
  [ "$_do" = 1 ] || [ ! -e "${_drv%/run.sh}/.dist-only" ] || { rm -rf "$JW"; broken "shard '$_s' carries ${_drv%/run.sh}/.dist-only but is not in DIST_SHARDS"; }
done
_nout="$(ok_outside_units "$SELF")"
[ "$_nout" = 0 ] || { rm -rf "$JW"; broken "$_nout arm ok line(s) sit outside every unit guard, so every shard would run them"; }
rm -rf "$JW"
echo "  [J0] coverage join: $_ndecl units derived from the sg guards, dealt disjointly across {$SHARDS}, union exact; this shard runs {$DEALT}"
# Every arm asks the merge IN PROCESS (lib.sh mx: the merge sourced, merge_main called in a subshell); the
# CLI is driven once per distinct outcome by the EQ arms below, each byte-compared with its in-process twin.
ASM_RUN=mx
# Each world shape is built once and copied per use (lib.sh wc_get); WC0 below holds a copy to a fresh build.
ASM_WCACHE=1
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECTS. A present subject with neither the `<p>_main() {` line nor its source guard
# predates the in-process wrap, and sourcing it would run its whole body: SKIP and exit 0 (FIXTURE BROKEN in the
# distribution), never an ok. Exactly one half is a respelled subject this fixture cannot drive, which FAILS. An
# unreadable subject is FIXTURE ERROR. Each wrapped subject has its own two greps (merge_main, seal_main); mx sources both.
# The gate sources lib/layout.sh before lib.sh, so the AI_DLC_* scrub lib.sh owns runs here first as well.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
. "$HERE/../lib/layout.sh" || { echo "FIXTURE ERROR: lib/layout.sh not found" >&2; exit 2; }
asm_find() { # <basename> -> the sibling's path in either layout, found by walking UP; empty when absent
  local _d="$HERE" _c
  while [ -n "$_d" ] && [ "$_d" != "/" ]; do
    for _c in "$_d/core/scripts/$1" "$_d/scripts/ai-dlc/$1"; do [ -f "$_c" ] && { printf '%s' "$_c"; return 0; }; done
    _d="$(dirname "$_d")"
  done
}
_am="$(asm_find merge-adversarial-shards.sh)"; _as="$(asm_find content-seal.sh)"
_am_h=00; _as_h=00
if [ -n "$_am" ]; then
  grep -qxF 'merge_main() {' "$_am"; _x=$?
  [ "$_x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $_am (grep exit $_x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$_x" -ne 0 ] || _am_h="1${_am_h#?}"
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$_am"; _x=$?
  [ "$_x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $_am (grep exit $_x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$_x" -ne 0 ] || _am_h="${_am_h%?}1"
fi
if [ -n "$_as" ]; then
  grep -qxF 'seal_main() {' "$_as"; _x=$?
  [ "$_x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $_as (grep exit $_x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$_x" -ne 0 ] || _as_h="1${_as_h#?}"
  grep -qxF 'if [ "${BASH_SOURCE[0]}" = "$0" ]; then' "$_as"; _x=$?
  [ "$_x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $_as (grep exit $_x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$_x" -ne 0 ] || _as_h="${_as_h%?}1"
fi
_pre=""
for _s in "$_am:$_am_h" "$_as:$_as_h"; do
  [ -n "${_s%%:*}" ] || continue
  case "${_s##*:}" in
    11) : ;;
    00) _pre="$_pre ${_s%%:*}" ;;
    *) printf '  FAIL  %s carries one half of the in-process wrap (entry line, source guard: %s) -- a respelled subject this fixture cannot drive\n' "${_s%%:*}" "${_s##*:}" >&2
       echo "$NAME: FAIL" >&2; exit 1 ;;
  esac
done
if [ -n "$_pre" ]; then echo "SKIP: $NAME:$_pre predate(s) the in-process wrap"; fx_skip_exit "$HERE"; fi
. "$HERE/lib.sh"
echo "HERMETIC-CONSUMED $MERGE"
# Every marked shard the arms merge is admitted by the merge's sibling content-seal.sh --admit-marker (BL-750).
echo "HERMETIC-CONSUMED core/scripts/content-seal.sh"
# The gate arms run the validator beside the merge (it starts the merge for its derived set), and the CS arms mark through the wait-for-deliverable.sh sibling: both are declared subjects of this fixture.
echo "HERMETIC-CONSUMED core/scripts/validate-adversarial-convergence.sh"
echo "HERMETIC-CONSUMED core/scripts/wait-for-deliverable.sh"

# ---------------------------------------------------------------------------------- the arms
echo "$NAME:"

# The CLI seam's pair runner (eq_pair, eq_arm) is used by arms of several units, so it sits outside every unit.
# EQ: THE SEAM. Every arm below asks the merge in process (mx). Here each DISTINCT CLI OUTCOME runs once end to
# end and once in process on the SAME world, and stdout, stderr, the exit code and the pass file it writes must
# be byte-identical; the kept end-to-end run per outcome is the CLI half. The output is moved aside between the
# two halves, so both write it afresh. EQ0 then asserts the outcomes differ from each other.
eq_pair() { # <label> <shard dir or -> <args...> (@D is replaced by the shard dir) -> EQ_SAME, EQ_RC, $WORK/eq.<label>.*
  local lab="$1" d="$2" a o=""; shift 2
  local args=(); for a in "$@"; do args[${#args[@]}]="${a//@D/$d}"; done
  [ "$d" = - ] || o="$(out_of "$d")"
  FXCELL="cli-$lab" bash "$MERGE" "${args[@]}" > "$WORK/eq.$lab.c.out" 2> "$WORK/eq.$lab.c.err"; echo $? > "$WORK/eq.$lab.c.rc"
  [ -n "$o" ] && [ -f "$o" ] && mv "$o" "$WORK/eq.$lab.c.pass"
  mx "$MERGE" "${args[@]}" > "$WORK/eq.$lab.i.out" 2> "$WORK/eq.$lab.i.err"; echo $? > "$WORK/eq.$lab.i.rc"
  [ -n "$o" ] && [ -f "$o" ] && mv "$o" "$WORK/eq.$lab.i.pass"
  EQ_SAME=1; for a in out err rc; do cmp -s "$WORK/eq.$lab.c.$a" "$WORK/eq.$lab.i.$a" || EQ_SAME=0; done
  if [ -f "$WORK/eq.$lab.c.pass" ] || [ -f "$WORK/eq.$lab.i.pass" ]; then cmp -s "$WORK/eq.$lab.c.pass" "$WORK/eq.$lab.i.pass" || EQ_SAME=0; fi
  EQ_RC="$(cat "$WORK/eq.$lab.c.rc")"
}
eq_arm() { # <label> <want rc> <token in stdout or stderr> <describe> <shard dir or -> <args...>
  local lab="$1" want="$2" tok="$3" what="$4"; shift 4
  eq_pair "$lab" "$@"
  if [ "$EQ_SAME" = 1 ] && [ "$EQ_RC" = "$want" ] && grep -qF -- "$tok" "$WORK/eq.$lab.c.out" "$WORK/eq.$lab.c.err"; then
    ok "$lab: $what -- the CLI and merge_main in process answer byte-identically (stdout, stderr, rc $want, pass file)"
  else bad "$lab: $what -- same=$EQ_SAME rc=$EQ_RC (want $want, '$tok'): $(head -2 "$WORK/eq.$lab.c.out") | $(head -2 "$WORK/eq.$lab.i.out")"; fi
}

if sg core; then
# M0: the ordinal map covers every *.md, whatever its name, in C order.
p_m0() { # <merge> -> 0 iff --map keys the three real files, the two non-story- names included, in C order
  local d want; d="$(new_world)" || return 1
  map="$($ASM_RUN "$1" --map "$d")"
  want="$(printf '1\t192-ff-A-token-decimal-resolution.md\n2\tbug-192-il-accuracy.md\n3\tstory-1-rebalancer-il-accuracy.md')"
  [ "$map" = "$want" ]
}
if p_m0 "$MERGE"; then
  ok "M0: --map keys all three real files by ordinal, the two NON-story- names (192-ff-, bug-) included, in LC_ALL=C order"
else
  bad "M0: --map printed [$map], not the three ordinals over the real listing"
fi

eqd="$(b3_world)"
eq_arm EQ1 0 "verdict=EXIT_CONDITION_NOT_MET shards=6" "files mode MERGED (B3)" "$eqd" @D
[ -f "$WORK/eq.EQ1.c.pass" ] || bad "EQ1: FIXTURE BROKEN -- the CLI merge wrote no pass file, so the pass-file comparison compared nothing"
eqr="$(b3_world)"; rm -f "$eqr/1.md"
eq_arm EQ2 2 "REFUSED: " "files mode REFUSED (ordinal 1 missing)" "$eqr" @D
eq_arm EQ3 0 "192-ff-A-token-decimal-resolution.md" "--map" "$eqd" --map @D
eq_arm EQ4 0 "DRY-RUN: clean" "--dry-run clean" "$eqd" --dry-run @D
eq_arm EQ5 2 "REFUSED: " "--dry-run refusing" "$eqr" --dry-run @D
eq_arm EQ6 0 "@" "--pair-sep" - --pair-sep
sed '/^verdict:/d' "$eqd/1.md" > "$WORK/eq-nov.md"
eq_arm EQ7 1 "REFUSED: " "--check-header refusing" - --check-header "$WORK/eq-nov.md" --axis convergence
eq_pair EQ8 - --check-header "$eqd/1.md" --axis convergence
if [ "$EQ_SAME" = 1 ] && [ "$EQ_RC" = 0 ] && [ ! -s "$WORK/eq.EQ8.c.out" ]; then ok "EQ8: --check-header passing -- byte-identical, rc 0, nothing printed"
else bad "EQ8: --check-header passing: same=$EQ_SAME rc=$EQ_RC"; fi
eqw="$(HR_BOUND=0 b3_world)"; HR_BOUND=0 shard "$eqw" 1 2 EXIT_CONDITION_MET 1 "" 2026-08-24T13:00:00Z
eq_arm EQ9 0 "LEGACY" "a LEGACY WARN on stderr beside a MERGED line" "$eqw" @D
eq_arm EQ10 2 "usage: " "a usage refusal" - --document
eq_arm EQ11 0 "USAGE" "--help" - --help
# WC0: a COPIED world is the world a fresh build makes. eqd above is the FIRST b3 build (the cache template's own dir,
# asserted below), and EQ1's CLI run merged it first, so $WORK/eq.EQ1.c.pass is the pass file a fresh build merges to.
# A copy merges in process, and its pass file and the fresh one must be byte-identical, and the copy's ledger must
# name no other world's root. A1 below reads this same copy's merge (wcc, wc.c), so B3 is merged in process once more, not twice.
wcc="$(b3_world)"
[ "$wcc" != "$eqd" ] && [ "${ASM_WCACHE:-0}" = 1 ] && [ "$eqd" = "$WORK/$(cat "$WC_ROOT/wcache/b3.old" 2>/dev/null)/$(cat "$WC_ROOT/wcache/b3.rel" 2>/dev/null)" ] \
  || bad "WC0: FIXTURE BROKEN -- eqd is not the cache template's own fresh build, so the EQ1 pass file is not a fresh build's"
mx "$MERGE" "$wcc" > "$WORK/wc.c" 2>&1; wcrc=$?; wfrc="$(cat "$WORK/eq.EQ1.c.rc")"
wcr="$(dirname "$(hr_state "$wcc/1.md")")"; wce="$(dirname "$(hr_state "$eqd/1.md")")"
if [ "$wcc" != "$eqd" ] && [ "$wcrc" = 0 ] && [ "$wfrc" = 0 ] && cmp -s "$(out_of "$wcc")" "$WORK/eq.EQ1.c.pass" \
   && ! grep -qF "/${wce##*/}" "$wcr/_bmad-output/planning-artifacts/.artifact-writes.jsonl" \
   && grep -qF "/${wcr##*/}\"" "$wcr/_bmad-output/planning-artifacts/.artifact-writes.jsonl"; then
  ok "WC0: a copied B3 world merges to the pass file a fresh build merges to, byte for byte, and its ledger names its own root only"
else bad "WC0: the copied world (rc=$wcrc) and a fresh build (rc=$wfrc) differ, or its ledger names the template's root: $(head -1 "$WORK/wc.c")"; fi
eqx=1
for _p in "EQ1 EQ2" "EQ3 EQ4" "EQ4 EQ5" "EQ7 EQ8" "EQ1 EQ9"; do
  set -- $_p
  cmp -s "$WORK/eq.$1.c.out" "$WORK/eq.$2.c.out" && cmp -s "$WORK/eq.$1.c.err" "$WORK/eq.$2.c.err" && eqx=0
done
[ "$eqx" = 1 ] && ok "EQ0: each refusing outcome differs from its passing twin (EQ1/EQ2, EQ4/EQ5, EQ7/EQ8), and the mode outcomes from each other" \
  || bad "EQ0: two outcomes the EQ arms call distinct printed identical bytes; the equivalence pairs prove nothing"

# The worlds must differ from each other where the arms say they do, or the pair proves nothing.
d1="$(b3_world)"; d2="$(clean_world)"
if cmp -s "$d1/1.md" "$d2/1.md"; then bad "W0: FIXTURE BROKEN -- the B3 and clean worlds seed byte-identical shard 1"
else ok "W0: the B3 and clean worlds differ in shard bytes (count and stamped verdict), so the pair can split"; fi
n_met="$(grep -l '^verdict: EXIT_CONDITION_MET$' "$d1"/1.md "$d1"/2.md "$d1"/3.md | grep -c .)" || n_met=0
[ "$n_met" -eq 3 ] && ok "W1: every B3 shard stamps EXIT_CONDITION_MET (a worst-shard merge would say MET)" \
  || bad "W1: FIXTURE BROKEN -- only $n_met of 3 B3 shards stamp MET, so B3 no longer discriminates"

p_b3 "$MERGE" "$wcc" "$WORK/wc.c" "$wcrc" && ok "A1: B3 (3 shards x 2 blocking MAJOR, each stamped MET) merges NOT_MET with blocking=6, shards=4 beside a repair dir, and --cycle-state reads CONTINUE" \
  || bad "A1: the B3 input did not merge to a recomputed NOT_MET accepted by the convergence validator (rc=$RC): $(cat "$MO") $(cat "$CO" 2>/dev/null)"
p_clean "$MERGE" && ok "A2: every shard stamped NOT_MET, summed blocking 3 = the ceiling -> merged MET and CONVERGED (the mirror of A1)" \
  || bad "A2: the clean set did not merge to MET/CONVERGED (rc=$RC): $(cat "$MO")"
p_ceiling "$MERGE"; r=$?
if [ "$r" -eq 2 ]; then bad "A3: FIXTURE STALE -- MAJOR_EXIT_CEILING=3 is not a line of the convergence validator, so the ceiling copy changed nothing"
elif [ "$r" -eq 0 ]; then ok "A3: with the sibling's MAJOR_EXIT_CEILING at 6 the SAME B3 input merges MET (ceiling=6) -- the ceiling is read, not restated"
else bad "A3: a sibling ceiling of 6 did not move the B3 merge to MET: $(cat "$MO")"; fi
p_miss_ord "$MERGE"   && ok "R1: ordinal 1 (a non-story- file) with no shard -> REFUSED 'is missing', exit 2, nothing written" || bad "R1: a missing ordinal shard was not refused cleanly (rc=$RC): $(cat "$MO")"
p_miss_cross "$MERGE" && ok "R2: cross-2.md of the three cross groups absent -> REFUSED 'shard cross-2 is missing', exit 2, nothing written" || bad "R2: a missing cross shard was not refused cleanly (rc=$RC): $(cat "$MO")"
p_dup "$MERGE"        && ok "R3: 1.md beside 01.md -> REFUSED 'delivered more than once', exit 2, nothing written" || bad "R3: a duplicate shard was not refused cleanly (rc=$RC): $(cat "$MO")"
p_partition "$MERGE"  && ok "R4: a per-ordinal finding citing two stories, and a cross finding citing one, each REFUSED, nothing written" || bad "R4: a partition violation was not refused cleanly (rc=$RC): $(cat "$MO")"
p_ms "$MERGE"         && ok "A4: shards stamped 15:00:19.497Z and 15:00:19Z merge, the merged invoked_at is 15:00:19Z (the true earliest, not the raw-string least), and --cycle-state accepts it (exit 0)" \
  || bad "A4: a millisecond-stamped shard did not merge to the true-earliest invoked_at (rc=$RC): $(cat "$MO") $(cat "$CO" 2>/dev/null)"
p_sha "$MERGE"        && ok "R5: a shard notarizing another story's sha -> REFUSED 'reviewed other bytes', exit 2, nothing written" || bad "R5: a sha mismatch was not refused cleanly (rc=$RC): $(cat "$MO")"
fi # sg core

if sg doc; then
# ---- section mode. The seeds must reach the branches they are named for, or every D arm below
# asserts about a world that cannot express its defect.
DS0="$(new_doc_world)"; DS1="$(new_doc_world seed.doc-serial-epics.md)"
n_parts="$(bash "$PARTITION" --map "$(doc_of "$DS0")" | grep -c .)" || n_parts=0
bash "$PARTITION" --map "$(doc_of "$DS1")" > "$WORK/serial.map" 2>&1; r_serial=$?
if [ "$n_parts" -eq 3 ] && [ "$r_serial" -eq 3 ] && has "$WORK/serial.map" "SERIAL:"; then
  ok "D0: the document seed partitions into 3 parts and the SERIAL seed exits 3 with SERIAL: (both read from partition-document.sh --map, never assumed)"
else
  bad "D0: FIXTURE BROKEN -- the document seed maps to $n_parts part(s) (want 3) and the SERIAL seed exited $r_serial (want 3); the D arms cannot discriminate"
fi
p_doc_b3 "$MERGE" && ok "D1: three section shards x 2 MAJOR, each stamped MET, merge NOT_MET major=6; ONE artifact_sha equal to the document's; tool_use_id = cross-1's; a shard_wall entry per shard (cross-1..3 included); the convergence validator reads critical=0 major=6" \
  || bad "D1: the section B3 did not merge to a recomputed NOT_MET with one artifact_sha read 0/6 by the validator (rc=$RC): $(cat "$MO") $(grep -m1 'major=' "$CO" 2>/dev/null)"
p_doc_axis "$MERGE" && ok "D2: a finding carrying ONE sections: line AND a stories: line -> REFUSED by the axis guard (the one-citation count passes it), nothing written" \
  || bad "D2: a finding citing both axes was not refused by the axis guard (rc=$RC): $(cat "$MO")"
p_doc_sha "$MERGE" && ok "D3: a section shard notarizing other bytes at the right path -> REFUSED 'reviewed other bytes', nothing written" \
  || bad "D3: a whole-document sha mismatch was not refused cleanly (rc=$RC): $(cat "$MO")"
p_doc_path "$MERGE" && ok "D4: a section shard naming a byte-identical COPY of the document -> REFUSED 'reviewed another file' (the sha passes, the path does not), nothing written" \
  || bad "D4: an artifact path other than --document was not refused cleanly (rc=$RC): $(cat "$MO")"
p_doc_serial "$MERGE" && ok "D5: --document on a document partition-document.sh calls SERIAL -> REFUSED with its SERIAL: reason, nothing written" \
  || bad "D5: a SERIAL document was not refused cleanly (rc=$RC): $(cat "$MO")"
p_files_golden "$MERGE" && ok "D6: files mode on B3 is byte-identical to seed.files-b3-merged.expected, the output of the merge before section mode existed" \
  || bad "D6: files-mode output moved from the pre-section-mode golden (rc=$RC): $(cat "$MO")"
fi # sg doc

if sg subj; then
# ---- subject mode. U0: the seed must map to parts in at least two files, or a cross-file
# citation cannot be expressed and U3 asserts about nothing.
SW0="$(new_subj_world)"; SW0R="$(subj_root "$SW0")"
n_sp="$(grep -c . "$SW0R/subject.map")" || n_sp=0
n_sf="$(cut -f2 "$SW0R/subject.map" | sort -u | grep -c .)" || n_sf=0
if [ "$n_sp" -ge 4 ] && [ "$n_sf" -eq 2 ] && [ -f "$SW0R/$SUBJ_PA/s9/requirements-subject.md" ]; then
  ok "U0: the subject seed maps to $n_sp parts across both files (read from partition-subject.sh --map), manifest written"
else
  bad "U0: FIXTURE BROKEN -- the subject seed maps to $n_sp part(s) over $n_sf file(s): $(head -3 "$SW0R/subject.map")"
fi
p_subj_b3 "$MERGE" && ok "U1: subject shards each stamped MET with 1 MAJOR merge NOT_MET; artifact: = the manifest; artifact_sha: the four stems at disk bytes; ids = map ordinals + cross" \
  || bad "U1: the subject merge did not sum, recompute and notarize the manifest (rc=$RC): $(cat "$MO")"
p_subj_at "$MERGE" && ok "U1b: subject shards notarizing the old <stem>=<sha> form merge; the merged artifact_sha is the <stem>@<sha> list at disk bytes" \
  || bad "U1b: the merge did not read =-form shards into an @-form line (rc=$RC): $(cat "$MO")"
p_subj_miss_cross "$MERGE" && ok "U2: a subject shard set missing its LAST cross group -> REFUSED, nothing written" || bad "U2: (rc=$RC) $(cat "$MO")"
p_subj_xcite "$MERGE" && ok "U3: a part shard citing another file's ordinal -> REFUSED by the partition, nothing written" || bad "U3: (rc=$RC) $(cat "$MO")"
p_subj_sha "$MERGE" && ok "U4: one stem notarized at other bytes (the rest right) -> REFUSED naming that stem, nothing written" || bad "U4: (rc=$RC) $(cat "$MO")"
p_subj_stems "$MERGE" && ok "U5: a shard notarizing one of two stems -> REFUSED, nothing written" || bad "U5: (rc=$RC) $(cat "$MO")"
p_subj_art "$MERGE" && ok "U6: a shard naming prd.md instead of the manifest -> REFUSED, nothing written" || bad "U6: (rc=$RC) $(cat "$MO")"
p_subj_elicit "$MERGE" && ok "U7: --elicitation writes s9/requirements-elicitation.md with NO verdict (file or stdout); a verdict-bearing shard and a non-elicitation skill each REFUSED" \
  || bad "U7: the elicitation merge (rc=$RC): $(cat "$MO")"
p_subj_b4 "$MERGE" && ok "U8: --document into shards/requirements-p1 -> REFUSED 'merge it with --subject' (B4), nothing written" || bad "U8: (rc=$RC) $(cat "$MO")"
p_b4doc "$MERGE" && ok "U9: --document prd.md from shards/prd-p1 while s9/requirements-subject.md names it -> REFUSED naming the 'prd' stem and --subject 9 (B4 by document), nothing written" \
  || bad "U9: a --document merge of a manifest-named file was not refused (rc=$RC): $(cat "$MO")"
p_b4doc_nomf "$MERGE" && ok "U10: the same --document prd.md merge with NO manifest in the sprint -> MERGED prd-adversarial-p1 (U9's ALLOW twin)" \
  || bad "U10: the no-manifest twin did not merge (rc=$RC): $(cat "$MO")"
p_b4doc_other "$MERGE" && ok "U11: --document of an s9 file the manifest does NOT name, manifest present -> MERGED (B4 keys on the manifest's files, not on the manifest's presence)" \
  || bad "U11: a --document merge of a file outside the subject was refused beside a manifest (rc=$RC): $(cat "$MO")"

fi # sg subj
if sg xs; then
# ---- the cross groups (BL-464, BL-811). A K>=3 shard set carries ONE cross.md (the dispatched shape)
# or one cross shard per row of partition-document.sh --cross-groups <K>, never both, in EVERY mode;
# X1-X3 drive K=8 through each mode (and K=2 through files and --document), each predicate
# presence-shaped in every cell.
p_xfiles "$MERGE" && ok "X1: files mode, K=8: cross-1..6 merges (tool_use_id = cross-1's); cross.md alone MERGES titled K+1 shards, its body last under '## Shard: cross-story', tool_use_id the lone cross's, keyed cross=; cross-1..5 without cross-6 REFUSED; a finding in its owner AND another covering group REFUSED naming the owner, its owner alone merges major=1, a (1, 2, K-1) finding held only by a non-owner merges major=1; K=2 cross.md merges, K=2 cross-1.md REFUSED" \
  || bad "X1: files-mode cross groups (rc=$RC): $(cat "$MO")"
p_xdoc "$MERGE" && ok "X2: --document, K=8: the same five cells (the lone cross under '## Shard: cross-section'), and K=2 cross.md merges" \
  || bad "X2: --document cross groups (rc=$RC): $(cat "$MO")"
p_xelicit "$MERGE" && ok "X3: --subject --elicitation over the 6-part subject: cross-1..6 merges, cross.md alone MERGES (under '## Shard: cross-part'), a partial set REFUSED, the non-owner duplicate REFUSED, the owner alone counted once" \
  || bad "X3: elicitation cross groups (rc=$RC): $(cat "$MO")"
p_xmix "$MERGE" && ok "X4: cross.md beside cross-1..3.md -> REFUSED as a mix, nothing written" || bad "X4: (rc=$RC) $(cat "$MO")"
p_xunknown "$MERGE" && ok "X5: cross-7.md at K=3 -> REFUSED, the table does not print group 7, nothing written" || bad "X5: (rc=$RC) $(cat "$MO")"
p_xcomplete "$MERGE" && ok "X6: one shard ending in seat-complete: makes an unmarked shard an unfinished REFUSAL; every shard marked with its findings=<n> merges with the markers dropped; findings=3 over 2 findings REFUSED as truncated" \
  || bad "X6: seat-complete (rc=$RC): $(cat "$MO")"

# ---- the series stem is not the artifact. S1 is the defect graph s319 nearly shipped; S2 is its
# ALLOW twin one property apart (the dir name), with graph's real coe-p1 beside it; S3 is the
# near-miss that carries the word without ending in it; S4 is files mode and --map.
p_stem_series "$MERGE" && ok "S1: --document from shards/doc-adversarial-p1/ -> REFUSED 'names the series, not the artifact' (exit 2), and s9/ holds no *adversarial* file" \
  || bad "S1: a shard dir named for the series was not refused before any write (rc=$RC): $(cat "$MO")"
p_stem_control "$MERGE" && ok "S2: the same shards under shards/doc-p1/ and shards/coe-p1/ -> MERGED, writing doc-adversarial-p1.md and coe-adversarial-p1.md" \
  || bad "S2: the correctly named shard dir did not merge (rc=$RC): $(cat "$MO")"
p_stem_near "$MERGE" && ok "S3: shards/adversarial-notes-p1/ (the word, not the -adversarial suffix) -> MERGED" \
  || bad "S3: a stem containing 'adversarial' without ending in it was refused (rc=$RC): $(cat "$MO")"
p_stem_files "$MERGE" && ok "S4: files mode and --map on shards/stories-adversarial-p1/ -> each REFUSED naming the series, nothing written" \
  || bad "S4: files mode or --map accepted a series-named shard dir (rc=$RC): $(cat "$MO")"

fi # sg xs
if sg t; then
# ---- the dispatch id is DERIVED from the harness records, never self-reported (T1-T10). Every
# shard helper drives the REAL remediation-guard hook with a PreToolUse Write payload, and seeds the
# agent's meta file and an adversary spawn row; each cell below varies ONE of those for shard 2.
p_tuid_main "$MERGE" && ok "T1: self ids NOT_ACCESSIBLE, unavailable, absent and the forged toolu_cross1_g1_dispatch each merge; shard_tool_use_ids are the derived ids, tool_use_id is cross-1's, the forged string absent" \
  || bad "T1: a set with real records did not merge to the derived ids (rc=$RC): $(cat "$MO")"
p_tuid_norow "$MERGE" && ok "T2: shard 2 with no write-ledger row (a Bash write) and a toolu_-prefixed self id -> REFUSED 'has no row', nothing written" \
  || bad "T2: (rc=$RC) $(cat "$MO")"
p_tuid_nometa "$MERGE" && ok "T3: shard 2's writer has no meta file, no probe row, and a real-shaped self id -> REFUSED, nothing written" \
  || bad "T3: (rc=$RC) $(cat "$MO")"
p_tuid_selfdiff "$MERGE" && ok "T4: a real-shaped self id differing from the derived one -> REFUSED; the derived id self-reported merges" \
  || bad "T4: (rc=$RC) $(cat "$MO")"
p_tuid_role "$MERGE" && ok "T5: shard 2 written only by a remediator dispatch, and by an adversary plus a remediator -> each REFUSED naming the role" \
  || bad "T5: (rc=$RC) $(cat "$MO")"
p_tuid_twowriters "$MERGE" && ok "T6: two adversary dispatches wrote shard 2 -> REFUSED, neither taken" \
  || bad "T6: (rc=$RC) $(cat "$MO")"
p_tuid_oneagent "$MERGE" && ok "T7: one agent wrote shards 2 and 3 -> REFUSED 'one dispatch delivered two shards'" \
  || bad "T7: (rc=$RC) $(cat "$MO")"
p_tuid_nospawn "$MERGE" && ok "T8: the meta file's dispatch id has no spawn-ledger row -> REFUSED" \
  || bad "T8: (rc=$RC) $(cat "$MO")"
p_tuid_session "$MERGE" && ok "T9: payload session_id differs from the transcript stem -> the meta file is found by the row's transcript_path and agent_id, and the set merges" \
  || bad "T9: (rc=$RC) $(cat "$MO")"
p_tuid_pre "$MERGE" && ok "T10: a row with no transcript_path takes the probe row's id and merges; without the probe row it is REFUSED naming the agent and 'predates transcript_path'" \
  || bad "T10: (rc=$RC) $(cat "$MO")"
p_tuid_basename "$MERGE" && ok "T11: shard 2's only rows sit under shards/stories-p2/ and under s2/shards/stories-p1/ -> REFUSED 'has no row' (rows keyed on the full path, never the basename)" \
  || bad "T11: (rc=$RC) $(cat "$MO")"
p_tuid_probemeta "$MERGE" && ok "T12: the probe ledger names the meta's id AND another adversary dispatch for shard 2's agent -> REFUSED 'the meta file was rewritten after the agent stopped'" \
  || bad "T12: (rc=$RC) $(cat "$MO")"
p_tuid_tworoles "$MERGE" && ok "T13: shard 2's dispatch id carries two spawn rows, adversary and remediator -> REFUSED naming the remediator role" \
  || bad "T13: (rc=$RC) $(cat "$MO")"

fi # sg t
if sg rr; then
# ---- the re-dispatch of one shard (--rerun <shard>.md@<ISO>). RR1 is the contracted path; RR2 is
# graph s318 requirements-p1/cross-2, a genuine cross-shard write --rerun must never acquit; RR3 is
# the superseded writer posing as its own re-run.
p_rerun_join "$MERGE" && ok "RR1: a stalled adversary's 2.md and 2.md.draft before S, a NEW dispatch's 2.md after -> MERGED with --rerun 2.md@S, superseded=2, the rerun: line naming the stalled agent, 2= the new id" \
  || bad "RR1: (rc=$RC) $(cat "$MO")"
p_rerun_other "$MERGE" && ok "RR2: cross-1's own adversary edited 2.md before S -> REFUSED with --rerun, naming its cross-1.md row" \
  || bad "RR2: (rc=$RC) $(cat "$MO")"
p_rerun_same "$MERGE" && ok "RR3: the superseded writer writes 2.md again after S -> REFUSED, the re-run is a NEW dispatch" \
  || bad "RR3: (rc=$RC) $(cat "$MO")"

# ---- BL-946: DOUBLE-WRITE. A shard where NO --rerun start is admissible (a writer kept writing after another
# writer's first row) is refused as DOUBLE-WRITE, at the join's two-dispatch test, in both entry paths; a shard
# where some start is admissible keeps SAME (RR3, one writer) and the two-dispatch message (RR6f) byte-identical.
p_dw_rerun "$MERGE" && ok "RR6a: graph s322 coe-p2/cross.md -- O writes 2.md before S, the re-dispatch N after, O again after N -> --rerun 2.md@S REFUSED 'DOUBLE-WRITE 2.md:' naming both spans and 'no agent seal row', never SAME" \
  || bad "RR6a: (rc=$RC) $(cat "$MO")"
p_dw_plain "$MERGE" && ok "RR6n: the RR6a world with no --rerun -> REFUSED 'DOUBLE-WRITE 2.md:', never the two-dispatch --rerun remedy" \
  || bad "RR6n: (rc=$RC) $(cat "$MO")"
p_dw_twin "$MERGE" && ok "RR6b: RR6a's twin, O's last row before S -> MERGED with --rerun 2.md@S, superseded=2" \
  || bad "RR6b: (rc=$RC) $(cat "$MO")"
p_dw_tie "$MERGE" && ok "RR6c: O's last row ts equals N's first, --rerun at that tie -> REFUSED 'DOUBLE-WRITE 2.md:' (the comparison is strict)" \
  || bad "RR6c: (rc=$RC) $(cat "$MO")"
p_dw_out "$MERGE" && ok "RR6d: the RR6a world, O also writing 3.md.draft after its straddling row -> the OUT refusal, not DOUBLE-WRITE" \
  || bad "RR6d: (rc=$RC) $(cat "$MO")"
p_dw_role "$MERGE" && ok "RR6e: the RR6a world plus a remediator writing 2.md, no --rerun -> the role violation, not DOUBLE-WRITE" \
  || bad "RR6e: (rc=$RC) $(cat "$MO")"
p_dw_draft "$MERGE" && ok "RR6f: graph s318's shape, a draft-only agent inside N's span is no writer -> no --rerun: the two-dispatch refusal; --rerun 2.md@S: MERGED superseded=1" \
  || bad "RR6f: (rc=$RC) $(cat "$MO")"
p_dw_straddle_draft "$MERGE" && ok "RR6g: the straddle's late row is on 2.md.draft only (O 2.md at 20:00, N 2.md at 21:00, O 2.md.draft at 21:10) -> DOUBLE-WRITE with and without --rerun 2.md@S" \
  || bad "RR6g: (rc=$RC) $(cat "$MO")"

# ---- BL-536: a superseded writer is role-checked (D1), one dispatch writes one shard dir (D2), and
# the meta file is corroborated by the probe ledger (D4). Each refusal beside its MERGED twin.
p_rerun_role "$MERGE" && ok "RR4: --rerun superseding a stalled adversary AND a remediator -> REFUSED as a role violation; the same world with that writer an adversary MERGES superseded=2" \
  || bad "RR4: (rc=$RC) $(cat "$MO")"
p_xdir "$MERGE" && ok "XD1: shard 2's writer also wrote stories-p2/1.md, or stories-p10/1.md -> REFUSED 'under another shard dir', and under --rerun too; its own 2.md.draft, an unrelated agent in stories-p10, and --rerun without the p2 row each MERGE" \
  || bad "XD1: (rc=$RC) $(cat "$MO")"
p_probe_disagree "$MERGE" && ok "PR2: shard 2's meta file rewritten to another adversary dispatch after its adversary, or remediator, stopped -> each REFUSED 'the meta file was rewritten'; the unforged twin MERGES" \
  || bad "PR2: (rc=$RC) $(cat "$MO")"
p_probe_absent "$MERGE" && ok "PR1: a legitimate writer with no probe row, and a remediator with a forged meta and no probe row -> each REFUSED 'has not stopped'; the legitimate writer with its row MERGES" \
  || bad "PR1: (rc=$RC) $(cat "$MO")"
p_rerun_residual "$MERGE" && ok "RR5: KNOWN GAP, stated in the merge header -- a superseded remediator with no probe row and its meta forged to an adversary dispatch MERGES under --rerun; the same remediator WITH its probe row is REFUSED 'the meta file was rewritten'" \
  || bad "RR5: (rc=$RC) $(cat "$MO")"

fi # sg rr
if sg h; then
# ---- BL-544 / BL-554 / BL-548 (merge half). Each world is seeded the BL-536 way (shard -> harness
# record) because the dispatch-id derivation refuses a shard with no record before these checks run.
p_hdr "$MERGE" && ok "H1: a shard with NO ## Findings section whose finding opens '## F-1 (MAJOR)' and declares 0 findings -> REFUSED naming the line and the FINDING GRAMMAR; '## Notes' and the same heading inside a fence MERGE" \
  || bad "H1: (rc=$RC) $(cat "$MO")"
p_draft "$MERGE" && ok "H2: 2.md.draft beside a complete shard -> MERGED with 'NOTE: ignored draft 2.md.draft' on stderr and its body absent from the pass; notes.md and notes.md.draft still REFUSED" \
  || bad "H2: (rc=$RC) $(cat "$MO")"
p_dry "$MERGE" && ok "H3: --dry-run over two shards citing another story prints all four REFUSED lines, exit 2, no pass file; the clean set prints DRY-RUN: clean (exit 0), writes nothing, then merges for real" \
  || bad "H3: (rc=$RC) $(cat "$MO")"
p_dry_barrier "$MERGE" && ok "H4: --dry-run with shard 1 missing AND a finding refusal in shard 2 prints exactly the missing-shard line and reads no stdin (stdin is a file of poison in the shard grammar)" \
  || bad "H4: (rc=$RC) $(cat "$MO")"
# ---- BL-596: one tree. BL-597: a local-model lead's call_ ids. BL-598: the re-run start is bound.
p_tree "$MERGE" && ok "TR1: shard 2's only row is a write to a worktree's copy -> REFUSED 'not this tree'; the same write through a symlink alias of this tree, and a ledger with no root field, each MERGE" \
  || bad "TR1: (rc=$RC) $(cat "$MO")"
p_tuid_call "$MERGE" && ok "TC1: every dispatch id in the call_ shape -> MERGED with the derived call_ ids; a real-shaped call_ self id that differs -> REFUSED" \
  || bad "TC1: (rc=$RC) $(cat "$MO")"
p_rerun_bind "$MERGE" && ok "RB1: --rerun 2.md@1999-01-01T00:00:00Z on a normal round -> REFUSED past BACKDATE_TOL_S; 45 s after the recorded dispatch time -> MERGED, superseded: none" \
  || bad "RB1: (rc=$RC) $(cat "$MO")"

fi # sg h
if sg rs; then
# ---- BL-577: `### ` under `## Findings` is reserved for a finding (FINDING GRAMMAR). BL-575: one
# header check, owned by the merge, callable on one file as --check-header. These arms are INLINE,
# not `p_<name> "$MERGE"` predicates.
# RS1: the filed incident -- graph s319 requirements-p1/2.md, findings=0, a probes subsection.
p_rs1 "$MERGE" \
  && ok "RS1: '### Probes run (no finding)' under ## Findings, findings=0 -> REFUSED naming the reserved form and the fix (line 5), nothing written" \
  || bad "RS1: a severity-less ### under ## Findings was not refused with the reserved-form message (rc=$RC): $(cat "$MO")"
d="$(hdr_world "## Findings\n\n## Probes\n\n$PROBES")"; mk_markers "$d"; run_merge "$MERGE" "$d"
[ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$MO" "major=4" \
  && ok "RS1c: the same probes under their own ## Probes section -> MERGED, shard 2 counting 0 (major=4 = shards 1 and 3)" \
  || bad "RS1c: the probes moved to ## Probes did not merge with shard 2 at 0 (rc=$RC): $(cat "$MO")"
# RS2 / RS3: the F-form opens ONE finding; the bare severity form (s315-s317 wrote it, and J3 can never close
# it: no id) is REFUSED on the convergence axis since BL-958 (THE FINDING ID, merge header).
for cell in 'RS2|### F-1 (MAJOR) the ordinal map omits story 2' 'RS3|### MAJOR: the ordinal map omits story 2'; do
  id="${cell%%|*}"; h="${cell#*|}"
  d="$(hdr_world "## Findings\n\n$h\n\nstories: 2\n")"; set_major "$d/2.md" 1; mk_markers "$d"
  printf '\n' >> "$d/2.md"; sed 's/^seat-complete: stories adversary 2 findings=0$/seat-complete: stories adversary 2 findings=1/' "$d/2.md" > "$d/2.tmp" && mv "$d/2.tmp" "$d/2.md"
  run_merge "$MERGE" "$d"
  if [ "$id" = RS2 ]; then
    [ "$RC" -eq 0 ] && has "$MO" "major=5" \
      && ok "$id: '$h' counts as 1 MAJOR finding (findings=1 marker agrees; merged major=5)" \
      || bad "$id: '$h' was not counted as one MAJOR finding (rc=$RC): $(cat "$MO")"
  else
    refused_clean "2.md:5 is a MAJOR finding heading from which no finding id is derived" "$d" && has "$MO" "$KF_MAJ" \
      && ok "$id: '$h' (no finding id) -> REFUSED naming 2.md:5 and the keyed form, nothing written" \
      || bad "$id: '$h' was not refused as a keyless MAJOR (rc=$RC): $(cat "$MO")"
  fi
done
fi # sg rs
if sg fi; then
# ---- BL-958: THE FINDING ID (merge header). Predicates in lib.sh (p_t1 .. p_t1_dry).
p_t1 "$MERGE" && ok "FI1: '### MAJOR — wiring check' and '### CRITICAL: x', counts agreeing -> each REFUSED naming 2.md:5, the keyed form and J3's source token, nothing written" \
  || bad "FI1: (rc=$RC) $(cat "$MO")"
p_t2 "$MERGE" && ok "FI2: F-1, **F-2**, 'Finding 3:', '1.', [F-3] (all MAJOR) and a keyless MINOR -> MERGED major=9" \
  || bad "FI2: (rc=$RC) $(cat "$MO")"
p_t3a "$MERGE" && ok "FI3a: F-1 twice as MAJOR, and F-1 as MAJOR beside F-1 as MINOR -> each REFUSED naming 2.md:9 and line 5; shard 2's M1 beside shard 1's M1 -> MERGED major=5" \
  || bad "FI3a: (rc=$RC) $(cat "$MO")"
p_t3b "$MERGE" && ok "FI3b: '**F-1**' and 'F-1.' (raw-different, one normalised id) -> REFUSED naming 2.md:9 and line 5" \
  || bad "FI3b: (rc=$RC) $(cat "$MO")"
p_d1 "$MERGE" && ok "FIF: a fence left open at end of file after a counted finding -> REFUSED naming 2.md:9; the same fence closed -> MERGED major=5" \
  || bad "FIF: (rc=$RC) $(cat "$MO")"
p_elic "$MERGE" && ok "FIE: FI1's keyless MAJOR in an elicitation shard -> --check-header --axis elicitation passes (rc 0, silent): convergence axis only" \
  || bad "FIE: (rc=$RC) $(cat "$MO")"
p_t1_chk "$MERGE" && ok "FIC: --check-header --axis convergence refuses FI1's shard (rc 1) with the same refusal" \
  || bad "FIC: (rc=$RC) $(cat "$MO")"
p_t1_dry "$MERGE" && ok "FID: --dry-run refuses FI1's world (rc 2) with the same refusal and writes nothing" \
  || bad "FID: (rc=$RC) $(cat "$MO")"
p_sh_refuse "$MERGE" && ok "FIS: a shard's own '## Shard: story 3' in 2.md -> merge REFUSED naming 2.md:3 and the shard file J3 would key it under (3.md), nothing written; --check-header refuses 'part 04' in 5.md (J3: 4.md), 'cross-story group 2 (1,3)' in cross-1.md (cross-2.md), and 'story 2' followed by '## Shard: notes' in 2.md (?)" \
  || bad "FIS: (rc=$RC) $(cat "$MO")"
p_sh_accept "$MERGE" && ok "FISa: --check-header accepts a self-heading J3 maps to the shard's own file -- 'story 2' in 2.md, 'part 04' in 04.md, 'cross-story' in cross.md, 'cross-section group 01 (1,3)' in cross-1.md" \
  || bad "FISa: (rc=$RC) $(cat "$MO")"
# The finding-grammar binding of the merge, the join and J3 (BL-958, BB0-BB2) is core/fixtures/finding-grammar-binding.
# RS4: a non-finding ### inside a fence under ## Findings is ignored.
d="$(hdr_world "## Findings\n\n\`\`\`text\n$PROBES\n\`\`\`")"; mk_markers "$d"; run_merge "$MERGE" "$d"
[ "$RC" -eq 0 ] && has "$MO" "major=4" \
  && ok "RS4: the probes heading inside a fence under ## Findings -> ignored, MERGED at shard 2 = 0" \
  || bad "RS4: a fenced ### under ## Findings was not ignored (rc=$RC): $(cat "$MO")"

fi # sg fi
if sg fg; then
# ---- BL-660: one fence grammar (opener: no backtick in a backtick fence's info string; closer: a bare run of the opener's character)
p_fence_prose "$MERGE" && ok "FG1: a prose line opening with three backticks and carrying a backtick, then a real derived fence and two findings -> MERGED counting both (the filed instance)" \
  || bad "FG1: (rc=$RC) $(cat "$MO")"
p_fence_unclosed "$MERGE" && ok "FG2: a genuinely unclosed fence still hides its finding -> REFUSED on the count" || bad "FG2: (rc=$RC) $(cat "$MO")"
p_fence_tilde "$MERGE" && ok "FG3: a backtick fence holding a ~~~~^^^ line closes only on its own backtick line -> M1 stays hidden, MERGED major=4" || bad "FG3: (rc=$RC) $(cat "$MO")"
p_fence_four "$MERGE" && ok "FG4: a four-backtick opener with an info string opens and its bare four-backtick line closes -> MERGED major=5" || bad "FG4: (rc=$RC) $(cat "$MO")"
p_fence_sameset "$MERGE" && ok "FG5: same_set -- a cross finding duplicating its owner's set is REFUSED identically with and without a prose backtick line in the owner's shard" || bad "FG5: (rc=$RC) $(cat "$MO")"
p_fence_nested "$MERGE" && ok "FG6: a four-backtick fence holding a three-backtick block hides the finding before its own closer -> declared 0 MERGED major=4, declared 1 REFUSED on the count" || bad "FG6: (rc=$RC) $(cat "$MO")"
p_fence_nested_set "$MERGE" && ok "FG7: same_set -- the owner's finding after a four-backtick fence holding a three-backtick block is read, so the duplicate is REFUSED" || bad "FG7: (rc=$RC) $(cat "$MO")"

# ---- BL-664: a trailing ` #` comment is stripped from a provenance value (schema parser.comments)
p_hdr_comment "$MERGE" && ok "HC1: every provenance value carrying a ' # ' comment passes --check-header on both axes, and merges byte-identical to the files-mode golden; 'findings_major: 2#x' (no whitespace) is still refused as non-integer" \
  || bad "HC1: (rc=$RC) $(cat "$MO")"

fi # sg fg
if sg sd; then
# ---- BL-670: the merge stamps DIVERGENT_HARD_BLOCK from the summed prior scope (arm C on the sum)
p_sum_divergent "$MERGE" && ok "SD1: summed prior_scope 2 over p1's 1 CRITICAL -> DIVERGENT_HARD_BLOCK with the stamp line naming p1; over p1's 2 -> not divergent; pass 1 -> not divergent; p3 with p2 absent compares with p1; a two-block p1 stamps on its FIRST block; a block-less p2 is skipped" \
  || bad "SD1: (rc=$RC) $(cat "$MO")"
if p_sum_excl_drift "$MERGE"; then ok "SD3: a validator copy whose --series exclusion line drifted is REFUSED naming the exclusion line, rc 2"
else bad "SD3: the drifted exclusion line was not refused (rc=${RC:-?}): $(head -3 "$MO")"; fi
# SD2: the oracle, not spelled as a line-start predicate call.
if p_sum_divergent_oracle "$MERGE"; then ok "SD2: on five seeded series (a -pass1 and a zero-padded -p02 predecessor, a two-block and a block-less one) the merge stamps exactly where validate-adversarial-convergence.sh --series fires arm C on the unstamped twin"
else bad "SD2: the merge's stamp (${OR_ST:-?}) disagrees with arm C on the unstamped twin (${OR_C:-?}): $(grep -m2 'FAIL\|pass artifact' "$CO" 2>/dev/null)"; fi

fi # sg sd
if sg ch; then
# CH1-CH8: --check-header on one file. The base is a real B3 shard, which passes; each cell varies ONE field.
ch() { $ASM_RUN "$MERGE" --check-header "$1" --axis "$2" > "$MO" 2>&1; RC=$?; } # <shard file> <axis>
chv() { sed "$2" "$1" > "$3"; } # <src> <sed script> <dst>
d="$(b3_world)"; c="$WORK/ch"; mkdir -p "$c"
ch "$d/1.md" convergence
[ "$RC" -eq 0 ] && [ ! -s "$MO" ] && ok "CH1: --check-header on a complete shard (verdict: EXIT_CONDITION_MET) -> exit 0, nothing printed" \
  || bad "CH1: a complete shard did not pass --check-header silently (rc=$RC): $(cat "$MO")"
p_chv "$MERGE" \
  && ok "CH2: no verdict: line -> --check-header exit 1 with the merge's own refusal text (the same line the merge prints for that shard, path aside)" \
  || bad "CH2: the no-verdict shard: --check-header and the merge did not refuse with one text (rc=$RC): $(cat "$MO")"
for cell in "CH3|s/^verdict: .*/verdict: PENDING-LEAD/|declares verdict 'PENDING_LEAD'" \
            "CH4|/^lead_role:/d|declares no lead_role" \
            "CH5|s/^lead_role: .*/lead_role: <the step file that invoked or dispatched the evaluation>/|an unfilled template placeholder" \
            "CH6|s/^verdict: .*/verdict: <EXIT_CONDITION_MET|EXIT_CONDITION_NOT_MET|DIVERGENT_HARD_BLOCK>/|declares verdict 'EXIT_CONDITION_MET_EXIT_CONDITION_NOT_MET_DIVERGENT_HARD_BLOCK'" \
            "CH7|s/^verdict: .*/verdict:   # stamped by the adversary/|declares verdict '<none>'"; do
  id="${cell%%|*}"; rest="${cell#*|}"; tok="${rest##*|}"; scr="${rest%|*}"
  chv "$d/1.md" "$scr" "$c/$id.md"; ch "$c/$id.md" convergence
  [ "$RC" -eq 1 ] && has "$MO" "REFUSED: $c/$id.md" && has "$MO" "$tok" \
    && ok "$id: [$scr] -> --check-header exit 1, '$tok'" || bad "$id: [$scr] gave rc=$RC: $(cat "$MO")"
done
# CH7: a COMMENT-ONLY verdict. The trailing ` #` comment is stripped from the raw value before the
# trim (BL-664), so nothing is left and the shard is refused as '<none>'; the commented VALUE that
# passes is p_hdr_comment's (HC1 below).
cp "$d/1.md" "$c/m.md"; printf '\nseat-complete: stories adversary 1 findings=3\n' >> "$c/m.md"; ch "$c/m.md" convergence
[ "$RC" -eq 1 ] && has "$MO" "findings=3' but its ## Findings section heads 2 finding(s)" \
  && ok "CH8: a marker declaring findings=3 over 2 findings -> --check-header exit 1 with the merge's truncation refusal" \
  || bad "CH8: (rc=$RC) $(cat "$MO")"
cp "$d/1.md" "$c/m2.md"; printf '\nseat-complete: stories adversary 1 findings=2\n' >> "$c/m2.md"; ch "$c/m2.md" convergence
[ "$RC" -eq 0 ] && ok "CH8c: the same shard with findings=2 -> exit 0" || bad "CH8c: (rc=$RC) $(cat "$MO")"
chv "$d/1.md" 's/^skill: .*/skill: bmad-advanced-elicitation/;/^verdict:/d' "$c/el0.md"; ch "$c/el0.md" elicitation; r0=$RC
chv "$d/1.md" 's/^skill: .*/skill: bmad-advanced-elicitation/' "$c/el1.md"; ch "$c/el1.md" elicitation; r1=$RC
[ "$r0" -eq 0 ] && [ "$r1" -eq 1 ] && has "$MO" "declares a verdict; an elicitation shard carries none" \
  && ok "CH9: --axis elicitation: no verdict -> exit 0; with a verdict -> exit 1 'an elicitation shard carries none'" \
  || bad "CH9: elicitation axis gave no-verdict rc=$r0, with-verdict rc=$r1: $(cat "$MO")"
chv "$d/1.md" "s/^## Findings$/## Findings\\
\\
### Probes run (no finding)\\
/" "$c/rs.md"; ch "$c/rs.md" convergence
[ "$RC" -eq 1 ] && has "$MO" "$RESERVED" && ok "CH10: --check-header refuses the reserved-form heading the merge refuses" \
  || bad "CH10: (rc=$RC) $(cat "$MO")"
fi # sg ch

if sg cs; then
# CS1-CS7: --check-shard, ONE adversary shard at its seal (BL-974; header: THE SHARD CHECK). Each cell is a
# real seeded world; the sealed sibling is sealed by the REAL producer, wait-for-deliverable.sh --mark.
WFD="$SRCDIR/wait-for-deliverable.sh"
cs() { $ASM_RUN "$1" --check-shard "$2" --findings "$3" > "$MO" 2>&1; RC=$?; } # <merge> <shard file> <n>
cs_lr() { sed "s|^lead_role: .*|lead_role: $2|" "$1" > "$1.t" && mv "$1.t" "$1"; } # <shard file> <value>
cs_seal() { asm_cell wfd "$WFD"; FXCELL="$ASM_FX" bash "$WFD" --mark "$1" requirements adversary "$2" "findings=$3" >/dev/null 2>&1; } # <file> <shard> <n>
# The shipped mark now runs --check-shard (wait-for-deliverable.sh header term 7), so a SECOND sealed sibling that
# disagrees with the first is refused at its seal. That world is still reachable: a shard sealed by an engine half
# whose mark has no merge beside it (term 7's absent-sibling case, today's behaviour). cs_seal_presib is that mark,
# the shipped wait-for-deliverable.sh and content-seal.sh in a dir that holds no merge.
CS_PRESIB="$WORK/cs-presib"; mkdir -p "$CS_PRESIB" && cp "$WFD" "$SRCDIR/content-seal.sh" "$CS_PRESIB/" \
  || { echo "FIXTURE BROKEN: cannot build the pre-sibling mark dir" >&2; exit 2; }
cs_seal_presib() { bash "$CS_PRESIB/wait-for-deliverable.sh" --mark "$1" requirements adversary "$2" "findings=$3" >/dev/null 2>&1; }
p_cs_lead() { # lead_role against a SEALED sibling, both directions; an unsealed one and self are never the reference
  local m="$1" d w ok=1
  for w in "requirements|requirements.md" "requirements.md|requirements"; do
    d="$(subj_b3_world)" || return 1
    cs_lr "$d/1.md" "${w%|*}"; cs_seal "$d/1.md" 1 1 || return 1
    cs_lr "$d/2.md" "${w#*|}"; cs "$m" "$d/2.md" 1
    [ "$RC" -eq 2 ] && has "$MO" "REFUSED: $d/2.md declares lead_role '${w#*|}' where the sealed shard $d/1.md declares '${w%|*}'" || ok=0
    cs_lr "$d/2.md" "${w%|*}"; cs "$m" "$d/2.md" 1                     # near-miss: the reference spelling
    [ "$RC" -eq 0 ] && has "$MO" "SHARD-OK" || ok=0
  done
  d="$(subj_b3_world)" || return 1                                      # control: the sibling is NOT sealed
  cs_lr "$d/1.md" requirements; cs_lr "$d/2.md" requirements.md; cs "$m" "$d/2.md" 1
  [ "$RC" -eq 0 ] && has "$MO" "SHARD-OK" || ok=0
  d="$(subj_b3_world)" || return 1                                      # re-mark: self is sealed with the old spelling
  cs_lr "$d/2.md" requirements.md; cs_seal "$d/2.md" 2 1 || return 1
  sed 's|^lead_role: .*|lead_role: requirements|' "$d/2.md" > "$WORK/cs-remark.md" || return 1
  export AI_DLC_CHECK_BYTES="$WORK/cs-remark.md"; cs "$m" "$d/2.md" 1; unset AI_DLC_CHECK_BYTES
  [ "$RC" -eq 0 ] && has "$MO" "SHARD-OK" || ok=0
  d="$(subj_b3_world)" || return 1                                      # sealed siblings disagreeing: WARN, pass
  cs_lr "$d/1.md" requirements; cs_seal "$d/1.md" 1 1 || return 1
  cs_lr "$d/3.md" requirements.md; cs_seal_presib "$d/3.md" 3 1 || return 1
  cs "$m" "$d/2.md" 1
  [ "$RC" -eq 0 ] && has "$MO" "WARN: the sealed shards in" && has "$MO" "SHARD-OK" || ok=0
  [ "$ok" = 1 ]
}
p_cs_cite() { # a finding with no sections: line is refused at the seal; the same shard with it passes
  local m="$1" d; d="$(subj_b3_world)" || return 1
  cs "$m" "$d/1.md" 1; [ "$RC" -eq 0 ] && has "$MO" "SHARD-OK" || return 1
  awk 'k == 0 && /^sections: / { k = 1; next } { print }' "$d/1.md" > "$d/1.t" && mv "$d/1.t" "$d/1.md"
  cs "$m" "$d/1.md" 1
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED: $d/1.md:5 finding carries 0 sections: lines; each finding carries exactly one"
}
p_cs_stem() { # artifact_sha stem SPec@ against SPEC@ (the subject's own stem): refused; SPEC@ passes
  local m="$1" d; d="$(subj_b3_world)" || return 1
  has "$d/1.md" "SPEC@" || has "$d/1.md" "SPEC=" || return 1
  cs "$m" "$d/1.md" 1; [ "$RC" -eq 0 ] && has "$MO" "SHARD-OK" || return 1
  sed -E 's/^(artifact_sha:.* )SPEC([=@])/\1SPec\2/' "$d/1.md" > "$d/1.t" && mv "$d/1.t" "$d/1.md"
  cs "$m" "$d/1.md" 1
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED: $d/1.md artifact_sha names stem 'SPec', not a subject stem"
}
p_cs_opener() { # the provenance opener misspelt SKILL_INVOCATION_PROVENANCE_BEGIN: one REFUSED line, exit 2
  local m="$1" d n; d="$(b3_world)" || return 1
  cs "$m" "$d/1.md" 2; [ "$RC" -eq 0 ] && has "$MO" "SHARD-OK" || return 1
  sed 's/SKILL_INVOCATION_PROVENANCE v1/SKILL_INVOCATION_PROVENANCE_BEGIN/' "$d/1.md" > "$d/1.t" && mv "$d/1.t" "$d/1.md"
  cs "$m" "$d/1.md" 2; n="$(grep -c '^REFUSED: ' "$MO")" || n=0
  [ "$RC" -eq 2 ] && [ "$n" = 1 ] && has "$MO" "carries 0 provenance block opening(s) and 1 closing(s)"
}
p_cs_skip() { # dir-level non-subjects SKIP (exit 3); a real files-mode shard dir beside them is checked (exit 0)
  local m="$1" d s x ok=1; d="$(b3_world)" || return 1; s="$(dirname "$d")"
  cs "$m" "$d/1.md" 2; [ "$RC" -eq 0 ] && has "$MO" "SHARD-OK" || ok=0
  for x in stories-fences-p1 architecture-adversarial-p1; do
    mkdir -p "$s/$x"; sed 's|^artifact_sha: .*|artifact_sha: 0|' "$d/1.md" > "$s/$x/1.md"
    cs "$m" "$s/$x/1.md" 2
    [ "$RC" -eq 3 ] && has "$MO" "SKIP: " && ! has "$MO" "REFUSED" || ok=0
  done
  [ "$ok" = 1 ]
}
p_cs_bytes() { # AI_DLC_CHECK_BYTES: the bytes checked are that file's, the path named is the real shard's
  local m="$1" d; d="$(b3_world)" || return 1
  sed '/^verdict:/d' "$d/1.md" > "$WORK/cs-bytes.md"
  export AI_DLC_CHECK_BYTES="$WORK/cs-bytes.md"; cs "$m" "$d/1.md" 2; unset AI_DLC_CHECK_BYTES
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED: $d/1.md declares verdict '<none>'" && ! has "$MO" "$WORK/cs-bytes.md" || return 1
  cs "$m" "$d/1.md" 2; [ "$RC" -eq 0 ] || return 1                       # the real bytes: clean
  cs "$m" "$d/1.md" 3                                                    # --findings 3 over 2 findings, no marker
  [ "$RC" -eq 2 ] && has "$MO" "findings=3' but its ## Findings section heads 2 finding(s)" || return 1
  $ASM_RUN "$m" --check-shard "$d/1.md" > "$MO" 2>&1; [ "$?" -eq 64 ]
}
p_cs_lead "$MERGE" && ok "CS1: lead_role 'requirements.md' against a SEALED 'requirements' sibling, and the reverse -> REFUSED naming the sibling and its value; the reference spelling, an UNSEALED disagreeing sibling, and a re-mark of a shard sealed with the old spelling -> SHARD-OK; sealed siblings disagreeing among themselves -> WARN, SHARD-OK" \
  || bad "CS1: (rc=$RC) $(head -3 "$MO")"
p_cs_cite "$MERGE" && ok "CS2: a finding with no sections: line -> --check-shard exit 2 with the merge's own cite-line refusal; the shard with it -> SHARD-OK" \
  || bad "CS2: (rc=$RC) $(head -3 "$MO")"
p_cs_stem "$MERGE" && ok "CS3: artifact_sha stem SPec@ (the subject's is SPEC@) -> exit 2 with the merge's own stem refusal; SPEC@ -> SHARD-OK" \
  || bad "CS3: (rc=$RC) $(head -3 "$MO")"
p_cs_opener "$MERGE" && ok "CS4: a provenance opener misspelt SKILL_INVOCATION_PROVENANCE_BEGIN -> exactly one REFUSED line (0 openings, 1 closing), exit 2; the real opener -> SHARD-OK" \
  || bad "CS4: (rc=$RC) $(head -3 "$MO")"
p_cs_skip "$MERGE" && ok "CS5: a shard in stories-fences-p1 (no subject resolvable) and in architecture-adversarial-p1 (the series stem) -> SKIP, exit 3, no REFUSED; stories-p1 beside them -> SHARD-OK" \
  || bad "CS5: (rc=$RC) $(head -3 "$MO")"
p_cs_bytes "$MERGE" && ok "CS6: AI_DLC_CHECK_BYTES names the bytes checked and the refusal names the real shard path; --findings 3 over 2 markerless findings -> the truncation refusal; no --findings -> exit 64" \
  || bad "CS6: (rc=$RC) $(head -3 "$MO")"
p_cs_selffirst() { # the self-only checks run BEFORE a subject is resolved: in a dir with none, a misspelt opener is
  # REFUSED (exit 2, the block count), and the correct opener in the same dir is SKIP (exit 3) naming the checks run
  local m="$1" d s; d="$(b3_world)" || return 1; s="$(dirname "$d")/stories-fences-p1"
  mkdir -p "$s" && cp "$d/1.md" "$s/1.md" || return 1
  cs "$m" "$s/1.md" 2
  [ "$RC" -eq 3 ] && has "$MO" "SKIP: no subject resolvable" && has "$MO" "the self-only checks ran and passed (check_header" && ! has "$MO" "REFUSED" || return 1
  sed 's/SKILL_INVOCATION_PROVENANCE v1/SKILL_INVOCATION_PROVENANCE_BEGIN/' "$d/1.md" > "$s/1.md" || return 1
  cs "$m" "$s/1.md" 2
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED: $s/1.md carries 0 provenance block opening(s) and 1 closing(s)" && ! has "$MO" "SKIP" || return 1
  # A COLLECTED refusal (the block parses, the verdict is absent) in the same dir: the self-only verdict, not the block-count stop, decides it.
  sed '/^verdict:/d' "$d/1.md" > "$s/1.md" || return 1
  cs "$m" "$s/1.md" 2
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED: $s/1.md declares verdict '<none>'" && ! has "$MO" "SKIP"
}
p_cs_selffirst "$MERGE" && ok "CS9: in stories-fences-p1 (no subject resolvable) a SKILL_INVOCATION_PROVENANCE_BEGIN opener -> exit 2 naming the block count, and a verdict-less shard -> exit 2, never SKIP; the real opener in the same dir -> exit 3 SKIP naming the self-only checks that ran" \
  || bad "CS9: (rc=$RC) $(head -3 "$MO")"
p_cs_docsel() { # FILES MODE ONLY on an entry spelled EXACTLY <artifact> holding two or more story files, never on
  # `[ -d ]` alone: a same-name dir holding ONE document, and a case-variant dir (which a case-insensitive
  # filesystem reads as the same name), beside sections: shards whose artifact partitions -> SHARD-OK, document mode.
  # Document mode is proven, not inferred: the same shard with a sections: line removed -> the sections: cite refusal.
  local m="$1" d s ok=1
  d="$(doc_b3_world)" || return 1; s="$(dirname "$(dirname "$d")")"
  cs "$m" "$d/1.md" 2; [ "$RC" -eq 0 ] && has "$MO" "SHARD-OK" || ok=0          # control: no colliding entry
  mkdir -p "$s/test-strategy" && cp "$s/test-strategy.md" "$s/test-strategy/test-strategy.md" || return 1
  cs "$m" "$d/1.md" 2; [ "$RC" -eq 0 ] && has "$MO" "SHARD-OK" && ! has "$MO" "stories:" || ok=0
  awk 'k == 0 && /^sections: / { k = 1; next } { print }' "$d/1.md" > "$d/1.t" && mv "$d/1.t" "$d/1.md"
  cs "$m" "$d/1.md" 2
  [ "$RC" -eq 2 ] && has "$MO" "finding carries 0 sections: lines; each finding carries exactly one" || ok=0
  d="$(doc_b3_world)" || return 1; s="$(dirname "$(dirname "$d")")"
  mkdir -p "$s/TEST-STRATEGY" && cp "$s/test-strategy.md" "$s/TEST-STRATEGY/test-strategy.md" || return 1
  cs "$m" "$d/1.md" 2; [ "$RC" -eq 0 ] && has "$MO" "SHARD-OK" && ! has "$MO" "stories:" || ok=0
  [ "$ok" = 1 ]
}
p_cs_docsel "$MERGE" && ok "CS10: a same-name dir s1/test-strategy/ holding ONE document, and a case-variant dir s1/TEST-STRATEGY/, beside sections: shards -> SHARD-OK in document mode (a sections:-less finding there -> the sections: cite refusal), never files mode" \
  || bad "CS10: (rc=$RC) $(head -3 "$MO")"
p_cs_noblock() { # a file with NO provenance block (0 openings, 0 closings) in a dir resolving no subject -> SKIP, both a
  # stories-fences-p1 and a stories-amend-p1 repair-style part; one opening and no closing in that dir -> REFUSED
  local m="$1" d s x ok=1; d="$(b3_world)" || return 1
  for x in stories-fences-p1 stories-amend-p1; do
    s="$(dirname "$d")/$x"; mkdir -p "$s" || return 1
    printf '# repair part\n\n- **disposition:** repaired\n- **edit:** `stories/story-1.md:3`\n' > "$s/1.md"
    cs "$m" "$s/1.md" 0
    [ "$RC" -eq 3 ] && has "$MO" "SKIP: $s/1.md carries no provenance block" && ! has "$MO" "REFUSED" || ok=0
  done
  sed '/SKILL_INVOCATION_PROVENANCE_END/d' "$d/1.md" > "$s/1.md" || return 1
  cs "$m" "$s/1.md" 2
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED: $s/1.md carries 1 provenance block opening(s) and 0 closing(s)" && ! has "$MO" "SKIP" || ok=0
  [ "$ok" = 1 ]
}
p_cs_noblock "$MERGE" && ok "CS11: a file carrying no provenance block (0 openings, 0 closings) in stories-fences-p1 and stories-amend-p1 -> SKIP, exit 3; one opening and no closing in the same dir -> REFUSED naming the block count (CS9 holds 0 openings, 1 closing)" \
  || bad "CS11: (rc=$RC) $(head -3 "$MO")"
# CS13/CS14: THE DOCUMENT FROM A SEALED SIBLING (BL-974). A document-mode shard whose WHOLE provenance block is
# deleted carries no `artifact:`, so its own bytes name no document; the merge's join refuses it on the block count.
# --check-shard takes the document from the SEALED siblings (cs_sealed, the agreement's definition: a sha= marker
# the merge's own admission admits) when every one that declares an `artifact:` declares the same one. Worlds are
# CS10's (doc_b3_world: sections: shards of test-strategy.md) and CS11's (stories-fences-p1 repair parts); every
# seal is the REAL --mark. cs_noblk deletes the block's lines, opener to closer, and nothing else.
cs_noblk() { awk '/SKILL_INVOCATION_PROVENANCE v1/ { skip = 1 } !skip { print } /SKILL_INVOCATION_PROVENANCE_END/ { skip = 0 }' "$1" > "$1.t" && mv "$1.t" "$1"; }
p_cs_docfb() { # CS13: 2.md, block deleted, beside a SEALED 1.md -> REFUSED with the block-count line the merge's join prints;
  # beside two SEALED siblings that disagree on artifact: -> SKIP with the disagreement WARN
  # The merge is asked BEFORE 1.md is sealed: with one shard marked and 2.md not, its marker-set check refuses first.
  local m="$1" d j
  d="$(doc_b3_world)" || return 1
  cs_noblk "$d/2.md"; ! has "$d/2.md" "SKILL_INVOCATION_PROVENANCE" && has "$d/2.md" "## Findings" || return 1
  run_doc_merge "$m" "$d"; j="$(grep -F "REFUSED: $d/2.md carries 0 provenance block opening(s)" "$MO" | head -1)"
  [ "$RC" -eq 2 ] && [ -n "$j" ] || return 1
  cs_seal "$d/1.md" 1 2 || return 1
  cs "$m" "$d/2.md" 2
  [ "$RC" -eq 2 ] && has "$MO" "$j" && ! has "$MO" "SKIP" || return 1
  # (c) two SEALED siblings disagree on artifact: no document is taken, SKIP as before, and the WARN only the
  # fallback prints names the disagreement
  d="$(doc_b3_world)" || return 1
  cs_seal "$d/1.md" 1 2 || return 1
  sed 's|^artifact: .*|artifact: _bmad-output/planning-artifacts/s1/other.md|' "$d/3.md" > "$d/3.t" && mv "$d/3.t" "$d/3.md"
  cs_seal_presib "$d/3.md" 3 2 || return 1
  cs_noblk "$d/2.md"; cs "$m" "$d/2.md" 2
  [ "$RC" -eq 3 ] && has "$MO" "SKIP: $d/2.md carries no provenance block" && has "$MO" "WARN: the sealed shards in" \
    && has "$MO" "disagree on artifact among themselves" && ! has "$MO" "REFUSED"
}
p_cs_docfb_near() { # CS14: the same block-less 2.md keeps today's SKIP wherever no sealed sibling declares a document
  local m="$1" d s ok=1
  d="$(doc_b3_world)" || return 1                                    # (b) every sibling carries artifact:, none sealed
  cs_noblk "$d/2.md"; cs "$m" "$d/2.md" 2
  [ "$RC" -eq 3 ] && has "$MO" "SKIP: $d/2.md carries no provenance block" && ! has "$MO" "REFUSED" || ok=0
  d="$(b3_world)" || return 1; s="$(dirname "$d")/stories-fences-p1"  # (d) CS11's dir: a SEALED sibling with no artifact:
  mkdir -p "$s" || return 1
  printf '# repair part\n\n- **disposition:** repaired\n- **edit:** `stories/story-1.md:3`\n' > "$s/1.md"
  printf '# repair part\n\n- **disposition:** repaired\n- **edit:** `stories/story-1.md:4`\n' > "$s/2.md"
  cs_seal_presib "$s/2.md" 2 0 || return 1
  has "$s/2.md" "sha=" && mx "$(dirname "$m")/content-seal.sh" --admit-marker "$s/2.md" >/dev/null 2>&1 || return 1 # sealed as cs_sealed reads it
  cs "$m" "$s/1.md" 0
  [ "$RC" -eq 3 ] && has "$MO" "SKIP: $s/1.md carries no provenance block" && ! has "$MO" "REFUSED" || ok=0
  [ "$ok" = 1 ]
}
p_cs_docfb "$MERGE" && ok "CS13: a document-mode shard with its whole provenance block deleted, beside a SEALED sibling naming the document -> --check-shard exit 2 with the merge join's own block-count refusal line, never SKIP; beside two SEALED siblings disagreeing on artifact: -> SKIP and the disagreement WARN" \
  || bad "CS13: (rc=$RC) $(head -3 "$MO")"
p_cs_docfb_near "$MERGE" && ok "CS14: the same block-less shard beside UNSEALED siblings only, and in stories-fences-p1 beside a SEALED (admitted) sibling with no artifact: -> SKIP, exit 3, as before" \
  || bad "CS14: (rc=$RC) $(head -3 "$MO")"
p_cs_flags() { # --check-shard-dir and --check-shard are two modes, told apart in both directions in one world.
  # (a) --check-shard-dir on a dir holding a shard --check-shard refuses (2.md, no verdict:): exactly the one
  #     `OK<TAB><dir>` line, rc 0, and none of --check-shard's lines (REFUSED:, SHARD-OK, SKIP:, its usage).
  # (b) --check-shard on 1.md, a path --check-shard-dir refuses (its parent is no shards/ dir): rc 0 SHARD-OK
  #     and none of --check-shard-dir's tab lines (OK, SKIP, REFUSED) or its usage.
  local m="$1" d ok=1; d="$(b3_world)" || return 1
  sed '/^verdict:/d' "$d/2.md" > "$d/2.t" && mv "$d/2.t" "$d/2.md" || return 1
  $ASM_RUN "$m" --check-shard-dir "$d" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && [ "$(cat "$MO")" = "$(printf 'OK\t%s' "$d")" ] \
    && ! has "$MO" "REFUSED: " && ! has "$MO" "SHARD-OK" && ! has "$MO" "SKIP: " && ! has "$MO" "--check-shard <shard-file>" || ok=0
  $ASM_RUN "$m" --check-shard "$d/1.md" --findings 2 > "$MO.b" 2>&1; RC_B=$?
  [ "$RC_B" -eq 0 ] && has "$MO.b" "SHARD-OK" && ! grep -q "$(printf '^\\(OK\\|SKIP\\|REFUSED\\)\t')" "$MO.b" \
    && ! has "$MO.b" "--check-shard-dir <planning>" || ok=0
  [ "$ok" = 1 ] || { cat "$MO.b" >> "$MO"; RC="$RC/$RC_B"; return 1; }
}
p_cs_flags "$MERGE" && ok "CS12: --check-shard-dir on a shard dir holding a shard --check-shard refuses -> exactly OK<TAB><dir>, rc 0, no --check-shard line; --check-shard on a file path --check-shard-dir refuses -> SHARD-OK, rc 0, no --check-shard-dir line" \
  || bad "CS12: (rc=$RC) $(head -4 "$MO")"
csd="$(b3_world)"; sed '/^verdict:/d' "$csd/2.md" > "$csd/2.t" && mv "$csd/2.t" "$csd/2.md"
eq_arm CS7a 2 "REFUSED: " "--check-shard refusing" - --check-shard "$csd/2.md" --findings 2
eq_arm CS7b 0 "SHARD-OK" "--check-shard passing" - --check-shard "$csd/1.md" --findings 2
# CS8: END TO END. The REAL --check-shard refusal flows through the REAL wait-for-deliverable.sh --mark, the merge
# file's own sibling (header terms 7: the mark resolves the merge beside itself), never a stand-in. Each offender:
# exit 64, the shard's bytes
# unchanged (cmp), the merge's REFUSED line relayed and the mark's remedy; each corrected near-miss: MARKED.
cs_mk() { # <dir holding wait-for-deliverable.sh> <shard file> <shard> <n> -> RC, $MO, $WORK/cs-e2e.before
  cp "$2" "$WORK/cs-e2e.before" || return 1
  asm_cell wfd "$1/wait-for-deliverable.sh"; FXCELL="$ASM_FX" bash "$1/wait-for-deliverable.sh" --mark "$2" requirements adversary "$3" "findings=$4" > "$MO" 2>&1; RC=$?
}
cs_mk_refused() { # <shard file> <the merge's REFUSED line>
  [ "$RC" -eq 64 ] && cmp -s "$WORK/cs-e2e.before" "$1" && has "$MO" "$2" \
    && has "$MO" "the join's own check, refused '$1'; fix it in your file with Edit, then run the same --mark again"
}
cs_mk_marked() { # <shard file>
  [ "$RC" -eq 0 ] && has "$MO" "MARKED " && ! has "$MO" "REFUSED" && ! cmp -s "$WORK/cs-e2e.before" "$1" \
    && grep -q '^seat-complete: requirements adversary [0-9]* sha=[0-9a-f]\{64\} findings=1$' <<< "$(tail -1 "$1")"
}
p_cs_e2e() { # <merge>
  local m="$1" wd d w ok=1
  wd="$(dirname "$m")"; [ -f "$wd/wait-for-deliverable.sh" ] || cp "$WFD" "$wd/" || return 1
  for w in "requirements|requirements.md" "requirements.md|requirements"; do
    d="$(subj_b3_world)" || return 1
    cs_lr "$d/1.md" "${w%|*}"; cs_seal "$d/1.md" 1 1 || return 1
    cs_lr "$d/2.md" "${w#*|}"; cs_mk "$wd" "$d/2.md" 2 1
    cs_mk_refused "$d/2.md" "REFUSED: $d/2.md declares lead_role '${w#*|}' where the sealed shard $d/1.md declares '${w%|*}'" || ok=0
    cs_lr "$d/2.md" "${w%|*}"; cs_mk "$wd" "$d/2.md" 2 1                  # near-miss: the sealed sibling's spelling
    cs_mk_marked "$d/2.md" || ok=0
  done
  d="$(subj_b3_world)" || return 1
  has "$d/1.md" "SPEC@" || has "$d/1.md" "SPEC=" || return 1
  sed -E 's/^(artifact_sha:.* )SPEC([=@])/\1SPec\2/' "$d/1.md" > "$d/1.t" && mv "$d/1.t" "$d/1.md"
  cs_mk "$wd" "$d/1.md" 1 1
  cs_mk_refused "$d/1.md" "REFUSED: $d/1.md artifact_sha names stem 'SPec', not a subject stem" || ok=0
  sed -E 's/^(artifact_sha:.* )SPec([=@])/\1SPEC\2/' "$d/1.md" > "$d/1.t" && mv "$d/1.t" "$d/1.md"
  cs_mk "$wd" "$d/1.md" 1 1                                              # near-miss: the subject's own stem
  cs_mk_marked "$d/1.md" || ok=0
  [ "$ok" = 1 ]
}
p_cs_e2e "$MERGE" && ok "CS8: END TO END through the real wait-for-deliverable.sh --mark and the real merge --check-shard: lead_role 'requirements.md' against a SEALED 'requirements' sibling, the reverse, and artifact_sha stem SPec@ against SPEC@ -> exit 64, the shard byte-unchanged, the merge's REFUSED line relayed with the mark's remedy; each corrected spelling -> MARKED" \
  || bad "CS8: (rc=$RC) $(head -5 "$MO")"

fi # sg cs
if sg b726; then
# ---- BL726: a shard's invoked_at sits between its dispatch's spawn-ledger ts and its last write row,
# within BACKDATE_TOL_S, REFUSED only for a dispatch whose spawn row carries invoked_bound (LEGACY: WARN).
bl726_clean "$MERGE"
bl726_merged && grep -qx 'invoked_at: 2026-08-24T15:01:19Z' "$(out_of "$BL_D")" \
  && ok "BL726a: the B3 world, spawn ts 15:00:00Z and every shard stamped after it -> MERGED, invoked_at 15:01:19Z" \
  || bad "BL726a: (rc=$RC) $(cat "$MO")"
p_bl726b "$MERGE" \
  && ok "BL726b: shard 1 stamped 13:00:00Z, two hours before its bound dispatch -> REFUSED naming 1.md, both times, the tolerance and the --rerun remedy; nothing written" \
  || bad "BL726b: (rc=$RC) $(cat "$MO")"
p_bl726c "$MERGE" \
  && ok "BL726c: shard 2's only write row at 14:00:00Z, its stamp 15:02:19Z -> REFUSED naming 2.md and both times; nothing written" \
  || bad "BL726c: (rc=$RC) $(cat "$MO")"
bl726_near "$MERGE"
bl726_merged && ok "BL726d: shard 1 stamped 59 s before its dispatch (inside BACKDATE_TOL_S) -> MERGED" || bad "BL726d: (rc=$RC) $(cat "$MO")"
bl726_frac "$MERGE"
bl726_merged && ok "BL726e: shard 1 stamped 14:59:30.750Z, fractional and inside the tolerance -> MERGED (the fraction is stripped before the epoch)" || bad "BL726e: (rc=$RC) $(cat "$MO")"
p_bl726f "$MERGE" \
  && ok "BL726f: the 13:00:00Z shard under a dispatch with no invoked_bound key (an older guard's row) -> MERGED, stderr WARN naming 1.md, both times and LEGACY" \
  || bad "BL726f: (rc=$RC) $(cat "$MO") $(cat "$MO.err")"
HR_BOUND=0 bl726_late "$MERGE"
bl726_merged && has "$MO.err" "WARN: " && has "$MO.err" "last wrote it at 2026-08-24T14:00:00Z" && has "$MO.err" "LEGACY" \
  && ok "BL726g: the LATE shard under a dispatch with no invoked_bound key -> MERGED, stderr WARN naming the write time and LEGACY" \
  || bad "BL726g: (rc=$RC) $(cat "$MO") $(cat "$MO.err")"
p_bl726h "$MERGE" \
  && ok "BL726h: shard 2 written at 14:00:00Z and 15:30:00Z, stamped 15:02:19Z between them -> MERGED (bounded by its LAST write row, never its first)" \
  || bad "BL726h: (rc=$RC) $(cat "$MO") $(cat "$MO.err")"
bl726_nocal "$MERGE"
bl726_refused "1.md invoked_at 2026-08-24T24:00:00Z is not a calendar time" "--rerun 1.md@" \
  && ok "BL726i: shard 1 stamped 2026-08-24T24:00:00Z (the shape passes, the calendar does not) under a bound dispatch -> REFUSED naming 1.md and its stamp; nothing written" \
  || bad "BL726i: (rc=$RC) $(cat "$MO") $(cat "$MO.err")"
HR_BOUND=0 bl726_nocal "$MERGE"
bl726_merged && has "$MO.err" "WARN: " && has "$MO.err" "1.md invoked_at 2026-08-24T24:00:00Z is not a calendar time" && has "$MO.err" "LEGACY" \
  && ok "BL726j: the same hour-24 stamp under a dispatch with no invoked_bound key -> MERGED, stderr WARN naming 1.md and LEGACY (fail-open)" \
  || bad "BL726j: (rc=$RC) $(cat "$MO") $(cat "$MO.err")"
for _bv in false '"true"'; do
  HR_BOUND_V="$_bv" bl726_early "$MERGE"
  bl726_merged && has "$MO.err" "WARN: " && has "$MO.err" "1.md claims invoked_at 2026-08-24T13:00:00Z" && has "$MO.err" "LEGACY" \
    && ok "BL726k: invoked_bound:$_bv on the spawn row (only the JSON boolean true binds) with the 13:00:00Z shard -> MERGED, LEGACY WARN" \
    || bad "BL726k: invoked_bound:$_bv gave rc=$RC: $(cat "$MO") $(cat "$MO.err")"
done

# R6: a finding heading EXACTLY as the real pass wrote it carries no severity word, so the heads
# counted (0 MAJOR) disagree with findings_major -- refused, never counted as zero.
p_r6() { # <merge> -> 0 iff the real-pass heading (no severity word) under findings_major: 1 is REFUSED on its count
  local d; d="$(b3_world)"
  {
    printf '## Findings\n\n%s\n\nstories: 1\n\n' "$(sed -n 1p "$HERE/seed.finding-headings.txt")"
    sed -n '/SKILL_INVOCATION_PROVENANCE v1/,$p' "$d/1.md" | sed 's/^findings_major: 2$/findings_major: 1/'
  } > "$d/1.tmp" && mv "$d/1.tmp" "$d/1.md"
  run_merge "$1" "$d"
  refused_clean "Findings section heads 0 CRITICAL / 0 MAJOR" "$d"
}
p_r6 "$MERGE" \
  && ok "R6: a real-pass heading with no severity word -> REFUSED on the count, never merged as 0 MAJOR" \
  || bad "R6: a heading without a severity word was not refused on its count (rc=$RC): $(cat "$MO")"

# P1: the merged pass is a provenance block the READER accepts. Its artifact_sha is the files-mode
# list `<stem>@<sha> ...` (the `@` a current tree's merge emits; `=` before it), which the schema's single-sha pattern refused, so every sharded pass
# failed validate-provenance-block.sh while the convergence validator passed it. The two
# near-misses keep the widening honest: a list of ONE (a merge always has two or more stories)
# and a list carrying a short sha are both refused, and a bare sha is the control that still passes.
p_pb "$MERGE"; r_p1=$?
case "$r_p1" in
  0) ok "P1: the merged pass ($PB_NPAIRS <stem>@<sha> pairs) passes validate-provenance-block.sh; a one-pair list and a short sha are refused; a bare sha still passes" ;;
  2) bad "P1: FIXTURE BROKEN -- validate-provenance-block.sh is not beside the merge at $SRCDIR" ;;
  3) bad "P1: FIXTURE BROKEN -- the B3 merge did not write a multi-file <stem>@<sha> artifact_sha (rc=$RC, pairs=${PB_NPAIRS:-0}, first='${PB_FIRST:-}')" ;;
  4) bad "P1: FIXTURE BROKEN -- the short-sha near-miss did not apply to the @ list" ;;
  *) bad "P1: provenance reader on the merged forms gave ${PB_RS:-?} (want 0 non-0 non-0 0)" ;;
esac

fi # sg b726
if sg k; then
# ---- K: the separator the merge EMITS (--pair-sep). `@` only when every reader installed beside
# the merge accepts it: (a) validate-adversarial-convergence.sh and (b) partition-subject.sh each
# carry one `PAIR_SEP='[=@]'` line, and (c) validate-provenance-block.sh --accepts-at-pair exits 0
# on the schema ITS chain resolves. Each world is a tree laid out by hand in one layout -- `inst`
# (scripts/ai-dlc/ + .claude/schemas/, as install.sh lays a consumer out) or `core` (core/scripts/
# + core/schemas/) -- and every run sets AI_DLC_PROJECT_ROOT to the world (hermetic-run exports one).
# The three old readers are DERIVED from the current files at run time, never vendored: a pinned
# copy of core's own scripts under core/fixtures/ is a second corpus for the content-keyed arms.
# The key reads exactly three things, so each derivation removes exactly that one: the old VAC and
# the old partition-subject are the current files with their one `PAIR_SEP='[=@]'` line deleted;
# the old schema is the current one with the artifact_sha pattern's `[=@]` turned to `=` and
# `[^\s=@]` to `[^\s=]` (the pattern at 8df9b8ae6~1). Each derivation must differ from its source
# by `cmp -s`, and the schema's must make validate-provenance-block.sh --accepts-at-pair exit 1;
# otherwise K0 is FIXTURE BROKEN. Expectations are HARD-CODED, never read from --pair-sep: a
# merge that always printed `@` passes K1 and fails every K2 world, so the old worlds are what
# discriminates the key from a constant.
KSCH=""
_d="$SRCDIR"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _c in "$_d/core/schemas/provenance-block.json" "$_d/.claude/schemas/provenance-block.json"; do
    [ -f "$_c" ] && { KSCH="$_c"; break 2; }
  done
  _d="$(dirname "$_d")"
done
k_broken=""
for _f in "$KSCH" "$CONV" "$SRCDIR/partition-subject.sh" "$SRCDIR/validate-provenance-block.sh"; do
  [ -n "$_f" ] && [ -s "$_f" ] || k_broken="$k_broken ${_f:-<schema not found above $SRCDIR>}"
done
KOLD="$(mktemp -d "$WORK/kold.XXXXXX")" || exit 2
K_OLD_VAC="$KOLD/validate-adversarial-convergence.sh"; K_OLD_PS="$KOLD/partition-subject.sh"; K_OLD_SCH="$KOLD/provenance-block.json"
# Each derivation checks its anchor BEFORE it edits: an anchor not found exactly as expected is
# FIXTURE STALE, an edit leaving the file byte-identical is FIXTURE BROKEN; either names the anchor,
# no world is scored, and neither is ever a pass or a kill.
k_stale=""; K_A1=""; K_A0=""
k_drop_sep() { # <src> <out> <name> -- the source with its one PAIR_SEP='[=@]' line deleted
  local n0
  n0="$(grep -cxF "PAIR_SEP='[=@]'" "$1")" || n0=0
  [ "$n0" = 1 ] || { k_stale="$k_stale $3(anchor ^PAIR_SEP='[=@]'\$ found $n0 times, want 1)"; return 0; }
  grep -vxF "PAIR_SEP='[=@]'" "$1" > "$2"
  cmp -s "$1" "$2" && k_broken="$k_broken $3(deleting ^PAIR_SEP='[=@]'\$ left the file byte-identical)"
  return 0
}
k_old_schema() { # <src> <out> -- the artifact_sha pattern back to the `=`-only form; must make --accepts-at-pair exit 1
  local rc r a1 a0
  python3 - "$1" "$2" <<'PY'
import sys
src, out = sys.argv[1], sys.argv[2]
lines = open(src, encoding="utf-8").read().split("\n")
hits = [i for i, l in enumerate(lines) if l.lstrip().startswith('"artifact_sha": "^')]
if len(hits) != 1: sys.exit(3)
l = lines[hits[0]]
if l.count("[=@]") != 2 or l.count("[^\\\\s=@]") != 2: sys.exit(3)
lines[hits[0]] = l.replace("[=@]", "=").replace("[^\\\\s=@]", "[^\\\\s=]")
open(out, "w", encoding="utf-8").write("\n".join(lines))
PY
  rc=$?
  [ "$rc" = 3 ] && { k_stale="$k_stale old-schema(anchor: one \"artifact_sha\": \"^ pattern line carrying [=@] twice and [^\\\\s=@] twice, not found)"; return 0; }
  [ "$rc" = 0 ] || { k_broken="$k_broken old-schema(derivation exited $rc)"; return 0; }
  cmp -s "$1" "$2" && { k_broken="$k_broken old-schema(the [=@] / [^\\\\s=@] edit left the file byte-identical)"; return 0; }
  # The derivation must BITE: the current validator exits 1 over it, and 0 over its source.
  r="$(mktemp -d "$WORK/ksch.XXXXXX")" && mkdir -p "$r/core/schemas" && cp "$2" "$r/core/schemas/provenance-block.json" \
    || { k_broken="$k_broken old-schema(probe root did not build)"; return 0; }
  AI_DLC_PROJECT_ROOT="$r" bash "$SRCDIR/validate-provenance-block.sh" --accepts-at-pair >/dev/null 2>&1; a1=$?
  cp "$1" "$r/core/schemas/provenance-block.json"
  AI_DLC_PROJECT_ROOT="$r" bash "$SRCDIR/validate-provenance-block.sh" --accepts-at-pair >/dev/null 2>&1; a0=$?
  [ "$a1" = 1 ] && [ "$a0" = 0 ] || k_broken="$k_broken old-schema(--accepts-at-pair exited $a1 on the derivation and $a0 on its source, want 1 and 0)"
  K_A1="$a1"; K_A0="$a0"
  return 0
}
if [ -z "$k_broken" ]; then
  k_drop_sep "$CONV" "$K_OLD_VAC" old-VAC
  k_drop_sep "$SRCDIR/partition-subject.sh" "$K_OLD_PS" old-partition-subject
  k_old_schema "$KSCH" "$K_OLD_SCH"
fi
# kl_world <layout inst|core> <swap none|vac|ps|sch> <merge file> -> prints the world root
kl_world() {
  local w s c
  w="$(mktemp -d "$WORK/kw-$1-$2.XXXXXX")" || return 1
  if [ "$1" = inst ]; then s="$w/scripts/ai-dlc"; c="$w/.claude/schemas"
  else s="$w/core/scripts"; c="$w/core/schemas"; mkdir -p "$w/core/skills/ai-dlc" || return 1; fi
  mkdir -p "$s" "$c" || return 1
  cp "$3" "$s/merge-adversarial-shards.sh" && cp "$CONV" "$s/" && cp "$SRCDIR/partition-subject.sh" "$s/" \
    && cp "$SRCDIR/validate-provenance-block.sh" "$s/" && cp "$SRCDIR/partition-document.sh" "$s/" \
    && cp "$SRCDIR/validate-artifact-budget.sh" "$s/" \
    && cp "$KSCH" "$c/provenance-block.json" || return 1
  case "$2" in
    vac) cp "$K_OLD_VAC" "$s/validate-adversarial-convergence.sh" ;;
    ps)  cp "$K_OLD_PS" "$s/partition-subject.sh" ;;
    sch) cp "$K_OLD_SCH" "$c/provenance-block.json" ;;
  esac || return 1
  printf '%s' "$w"
}
k_dir() { [ "$1" = inst ] && printf 'scripts/ai-dlc' || printf 'core/scripts'; } # <layout>
# k_ps <world> <layout> [override root] -> the answer, as `@`, `=`, or `BAD(<rc>,<bytes>)`
k_ps() {
  local o="$WORK/kps.out" r n
  AI_DLC_PROJECT_ROOT="${3:-$1}" $ASM_RUN "$1/$(k_dir "$2")/merge-adversarial-shards.sh" --pair-sep > "$o" 2>/dev/null; r=$?
  n="$(wc -c < "$o" | tr -d ' ')"
  if [ "$r" -eq 0 ] && [ "$n" = 1 ] && { [ "$(cat "$o")" = "@" ] || [ "$(cat "$o")" = "=" ]; }; then cat "$o"
  else printf 'BAD(%s,%s)' "$r" "$n"; fi
}
# k_differs <world> <layout> <swap> -- the swapped reader really is not the current one (cmp)
k_differs() {
  case "$3" in
    vac) ! cmp -s "$CONV" "$1/$(k_dir "$2")/validate-adversarial-convergence.sh" ;;
    ps)  ! cmp -s "$SRCDIR/partition-subject.sh" "$1/$(k_dir "$2")/partition-subject.sh" ;;
    sch) if [ "$2" = inst ]; then ! cmp -s "$KSCH" "$1/.claude/schemas/provenance-block.json"
         else ! cmp -s "$KSCH" "$1/core/schemas/provenance-block.json"; fi ;;
  esac
}
if [ -n "$k_stale" ] || [ -n "$k_broken" ]; then
  [ -z "$k_stale" ] || bad "K0: FIXTURE STALE -- anchor not found:$k_stale; re-anchor the derivation, no K arm was asserted"
  [ -z "$k_broken" ] || bad "K0: FIXTURE BROKEN -- missing or unbuildable:$k_broken; no K arm was asserted"
else
  ok "K0: three old readers derived from the current files -- VAC and partition-subject each with its one PAIR_SEP='[=@]' line deleted (differ by cmp), the schema's artifact_sha pattern turned back to '='; validate-provenance-block.sh --accepts-at-pair exits $K_A1 on the derived schema and $K_A0 on its source"
  for L in inst core; do
    # K1: current readers -> `@`.
    w="$(kl_world "$L" none "$MERGE")" && a="$(k_ps "$w" "$L")" || a="BUILD"
    [ "$a" = "@" ] && ok "K1-$L: $L layout, every reader current -> --pair-sep prints exactly one byte '@', exit 0" \
      || bad "K1-$L: $L layout with current readers gave '$a' (want @)"
    # K2: ONE old reader, derived from the current file (K0) -> `=`, each world first proven to differ from the current one.
    # Only the vac world is asserted here; the ps and sch old readers are scored end to end by KE below.
    # Only in the inst layout: pair_sep reads VAC beside the merge in both layouts and answers '=' before
    # the layout-dependent schema chain, and K1-core holds the core layout's VAC lookup.
    [ "$L" = inst ] || continue
    for S in vac; do
      w="$(kl_world "$L" "$S" "$MERGE")" || { bad "K2$S-$L: FIXTURE BROKEN -- world did not build"; continue; }
      if ! k_differs "$w" "$L" "$S"; then bad "K2$S-$L: FIXTURE BROKEN -- the old-$S world is byte-identical to the current one"; continue; fi
      a="$(k_ps "$w" "$L")"
      [ "$a" = "=" ] && ok "K2$S-$L: $L layout, the old $S reader (derived from the current file, differs by cmp) -> --pair-sep prints '='" \
        || bad "K2$S-$L: $L layout with the old $S reader gave '$a' (want =)"
    done
  done
  # K3: an override root carrying the OLD schema in core/schemas, the install carrying the new ->
  # the validator's chain takes the override's first, so `=`. Its twin, an override root with NO
  # schema, falls through to the install's and prints `@`: the override is what moved the answer.
  w="$(kl_world inst none "$MERGE")"; ov="$(mktemp -d "$WORK/kov.XXXXXX")"; ov0="$(mktemp -d "$WORK/kov0.XXXXXX")"
  mkdir -p "$ov/core/schemas" && cp "$K_OLD_SCH" "$ov/core/schemas/provenance-block.json"
  a="$(k_ps "$w" inst "$ov")"; a0="$(k_ps "$w" inst "$ov0")"
  [ "$a" = "=" ] && [ "$a0" = "@" ] && ok "K3: AI_DLC_PROJECT_ROOT with the old schema in core/schemas over a current install -> '='; the same override with no schema -> '@'" \
    || bad "K3: override with the old schema gave '$a' (want =), override with none gave '$a0' (want @)"
  # KE: the EMITTER, end to end. K1-K3 read --pair-sep; this drives the merge itself (subject mode)
  # once per world and reads the separator of every pair in the artifact_sha list it wrote. One
  # subject world serves every drive: each output is moved aside, so the next drive writes afresh.
  # Expectations are hard-coded: `@` with every reader current, `=` in each old-reader world.
  ke_build() {
    KE_SD="$(new_subj_world)" && {
      for k in $(cut -f1 "$(subj_root "$KE_SD")/subject.map"); do sshard "$KE_SD" "$k" 0 "$k"; done
      for k in $(subj_xkeys "$KE_SD"); do sshard "$KE_SD" "$k" 0 "1, 2"; done; }
  }
  ke_build
  # k_drive <world> <merge in that world> -> `@` or `=` when every pair carries that one separator, else BAD(...)
  k_drive() {
    local o lst tok s seps="" n=0 r
    AI_DLC_PROJECT_ROOT="$1" $ASM_RUN "$2" --subject 9 "$KE_SD" > "$WORK/ke.out" 2>&1; r=$?
    o="$(subj_out_of "$KE_SD")"
    { [ "$r" -eq 0 ] && [ -f "$o" ]; } || { printf 'BAD(rc=%s:%s)' "$r" "$(head -1 "$WORK/ke.out")"; return 0; }
    lst="$(sed -n 's/^artifact_sha://p' "$o" | head -1)"
    mv "$o" "$(mktemp "$WORK/ke-out.XXXXXX")" || { printf 'BAD(mv)'; return 0; }
    for tok in $lst; do
      n=$((n + 1)); case "$tok" in *@*) s=@ ;; *=*) s='=' ;; *) s='?' ;; esac
      case "$seps" in *"$s"*) ;; *) seps="$seps$s" ;; esac
    done
    if [ "$n" -ge 2 ] && [ "${#seps}" = 1 ]; then printf '%s' "$seps"; else printf 'BAD(pairs=%s,seps=%s)' "$n" "$seps"; fi
  }
  ke_n="$(ls "$KE_SD" 2>/dev/null | grep -c '^cross.*\.md$')" || ke_n=0
  if [ -z "$KE_SD" ] || [ "$ke_n" -lt 1 ]; then
    bad "KE: FIXTURE BROKEN -- the subject world for the end-to-end drives did not build"
  else
    # One old reader per layout: ps in inst, sch in core.
    for L in inst core; do
      row=""
      if [ "$L" = inst ]; then ke_sw="none vac ps"; want=" none=@ vac== ps=="; else ke_sw="none vac sch"; want=" none=@ vac== sch=="; fi
      for S in $ke_sw; do
        w="$(kl_world "$L" "$S" "$MERGE")" && row="$row $S=$(k_drive "$w" "$w/$(k_dir "$L")/merge-adversarial-shards.sh")" || row="$row $S=BUILD"
      done
      [ "$row" = "$want" ] && ok "KE-$L: $L layout, the merge itself (subject mode) writes every artifact_sha pair with '@' when every reader is current and '=' in each old-reader world:$row" \
        || bad "KE-$L: the merge's emitted separators were$row (want$want)"
    done
  fi
fi

fi # sg k
if sg dv; then
# ---- THE DERIVED SET (BL-911): a document or subject pass after a series' first reviews only the repair; a
# stories (files-mode) pass owes the full map. lib.sh's dv worlds: eight
# stories, the rulebook carrying the era token committed at a fixed 2026-01-01, p1 merged, stories 3 and 6
# repaired on disk, only 3 cited by the joined repair record.
if ! dv_rulebook; then bad "DV: FIXTURE BROKEN -- _gate-procedures.md not found above $LIB_DIR; no derived-set arm can bind"
else
  echo "HERMETIC-CONSUMED $RULEBOOK"
  p_dv2 "$MERGE" && ok "DV2: files (stories) mode is never narrowed: p2's --derived-map prints the full map {$DV_ORDS}, derived from p1 with a full-width reason" || bad "DV2: ords [$DV_ORDS] hdr [$DV_HDR], want the full map 1..8 with a full-width reason"
  p_dv4d "$MERGE" && ok "DV4D: --document after p1, Section 2b inserted and Section 4 edited: {3 5 7}, the cited unchanged Section 6 owed at its NEW ordinal 7 (ordinal join {3 4 5 6 7 8}, cite-by-ordinal {3 5 6})" || bad "DV4D: ords [$DV_ORDS] hdr [$DV_HDR] ${PC_WHY:-}, want {3 5 7}"
  p_pc1 "$MERGE" && ok "PC1: a repack (Section 2 grows, Section 4 edited, seven parts become five): {2 3 4}, not the byte-identical Section 7 at another ordinal (ordinal and line-range joins {2 3 4 5})" || bad "PC1: ords [$DV_ORDS] hdr [$DV_HDR] ${PC_WHY:-}, want {2 3 4}"
  p_pcd "$MERGE" && ok "PCD: Section 3 rewritten into a byte copy of Section 5: both copies owed, {3 5 6} (a presence join owes {6})" || bad "PCD: ords [$DV_ORDS] ${PC_WHY:-}, want {3 5 6}"
  p_pct "$MERGE" && ok "PCT: a 260-row table cut into a notarized run, only the header piece changed: every member of p1's part_run owed (the content join alone owes one)" || bad "PCT: ords [$DV_ORDS] run [${PC_RUN:-}] ${PC_WHY:-}"
  p_pct2 "$MERGE" && ok "PCT2: a table cut into exactly two pieces, the header piece packed under Section 1, only the header changed: both pieces owed (ignoring the run owes {1})" || bad "PCT2: ords [$DV_ORDS] run [${PC_RUN:-}] ${PC_WHY:-}"
  p_pcc "$MERGE" && ok "PCC: a plain row before a run edited: {1} only, never the run beside it" || bad "PCC: ords [$DV_ORDS] run [${PC_RUN:-}] ${PC_WHY:-}, want {1}"
  p_pcsr "$MERGE" && ok "PCSR: subject, a table added since base inside prd, cut into a run mapped onto GLOBAL ordinals (every member a prd.md row, the header inside the first): its header changed, the whole run owed" || bad "PCSR: ords [$DV_ORDS] run [${PC_RUN:-}] ${PC_WHY:-}"
  p_pcs "$MERGE" && ok "PCS: subject, the SPEC leaves scope (ordinals drop by one), Goals grows, Requirements unchanged: {1 2}, the cited Sprint 9 part at its new ordinal 1 (cite-by-ordinal {2 3 4}, ordinal join the whole map)" || bad "PCS: ords [$DV_ORDS] ${PC_WHY:-}, want {1 2}"
  p_pcs2 "$MERGE" && ok "PCS2: subject, SPEC.md rewritten into the prd Requirements part's bytes: keyed (file, digest) only SPEC is owed, {1} (digest alone {1 4})" || bad "PCS2: ords [$DV_ORDS] ${PC_WHY:-}, want {1}"
  p_pck "$MERGE" && ok "PCK: K4 controls -- the unedited document world owes {6} and PCC's edited world {1}, narrowed in --derived-map and --derived-set alike" || bad "PCK: ${PC_CELL:-}: ${PC_WHY:-}"
  p_pcka "$MERGE" && ok "PCKa: p1 without part_sha: the FULL map with its reason, byte-identical in --derived-map and --derived-set" || bad "PCKa: ${PC_WHY:-}"
  p_pckb "$MERGE" && ok "PCKb: pass M without its own part_sha (p1 has one): --derived-set owes the FULL map with its reason, never narrowed" || bad "PCKb: ${PC_WHY:-}"
  p_pckc "$MERGE" && ok "PCKc: a malformed part_sha token in p1: the FULL map with its reason, both programs alike" || bad "PCKc: ${PC_WHY:-}"
  p_pckd "$MERGE" && ok "PCKd: p1's part_sha one entry short of its map: the FULL map with its reason, both programs alike" || bad "PCKd: ${PC_WHY:-}"
  p_pcke "$MERGE" && ok "PCKe: p1 without part_run: the FULL map with its reason, both programs alike" || bad "PCKe: ${PC_WHY:-}"
  p_pckf "$MERGE" && ok "PCKf: pass M without its own part_run: --derived-set owes the FULL map with its reason, never narrowed" || bad "PCKf: ${PC_WHY:-}"
  p_pckg "$MERGE" && ok "PCKg: p1's part_run naming an ordinal outside its map: the FULL map with its reason, both programs alike" || bad "PCKg: ${PC_WHY:-}"
  p_pckh "$MERGE" && ok "PCKh: a one-member run in p1's part_run: the FULL map with its reason, both programs alike" || bad "PCKh: ${PC_WHY:-}"
  p_pce "$MERGE" && ok "PCE: D1 -- a LEGACY series and a NOTOKEN rulebook each owe the FULL map with their reason, identical in --derived-map and --derived-set (bound: PCK's control {6})" || bad "PCE: cell ${PC_CELL:-?}: ${PC_WHY:-}"
  p_pcr "$MERGE" && ok "PCR: an identical re-merge over an old-engine document or subject pass (no part_sha:/part_run:) is UNCHANGED (and --dry-run clean) and leaves the file byte-for-byte; a same-engine re-merge is UNCHANGED; a pass with part_sha: but no part_run:, and one differing in a counted field, still refuse" || bad "PCR: cell ${PC_CELL:-?}: ${PC_WHY:-}"
  p_pckm "$MERGE" && ok "PCKm: a malformed, repeated or outside run in SECOND position of p1's part_run (1,2;3 / 1,2;2,3 / 1,2;3,99) owes the FULL map with its reason in both programs; near-misses: a good-only 1,2 narrows to {1}, a first-position 3;1,2 is FULL" || bad "PCKm: cell ${PC_CELL:-?}: ${PC_WHY:-}"
  p_pcmv "$MERGE" && ok "PCMV: SPEC.md moved between the part-digest hashing and the check (in-process seam, the merge's own sha_of wrapped) -> REFUSED naming it, p1 byte-unchanged; near-miss: the unhooked re-merge is UNCHANGED" || bad "PCMV: cell ${PC_CELL:-?}: ${PC_WHY:-}"
  p_pcn2 "$MERGE" && ok "PCN2: --part-sha --rows --scope-ref with a scope list the scoped map cannot read (rc=2) REFUSES and prints no run; near-miss: unwrapped, the same rows print the prd table's run" || bad "PCN2: cell ${PC_CELL:-?}: ${PC_WHY:-}"
  p_dv10 "$MERGE" && ok "DV10: p3 with no p2 on disk derives from p1 (series order) and owes the full map; a dispatch missing shard 1 is REFUSED, nothing written; the merge stamps p1 and notarizes all 8 stems at their disk shas; arm N reads p1 and owes the full pass the full map, an older engine's narrowed {3 6} pass its old derivation (no FAIL), and FAILs the full map less shard 1 (a subset)" \
    || bad "DV10: failed at stage ${DV_STAGE:-?}: rc=$RC ords [$DV_ORDS] hdr [$DV_HDR] $(head -1 "$MO") $(grep -m2 'FAIL (N' "$CO")"
  p_dva && ok "DVa: --derived-set on an old-engine narrowed stories p2: p1's open MAJOR on byte-unchanged story 5 keeps it owed, {3 5}; near-miss: the same finding MINOR owes {3}" || bad "DVa: cell ${PC_CELL:-?}: ${PC_WHY:-}"
  p_dvb && ok "DVb: --derived-set keys stories on BASENAME: a story sorting first shifts every ordinal, owed exactly {1 4 6 7 8} (new, changed 3 and 6, cited 5 and 7 at their new ordinals; unchanged uncited 2 3 5 9 absent)" || bad "DVb: ${PC_WHY:-}"
  p_dvc && ok "DVc: --derived-set over a p1 that notarizes no sha list: FULL with its 'notarizes no' reason, then 1..8; near-miss: the readable list narrows to {3} with no FULL line" || bad "DVc: cell ${PC_CELL:-?}: ${PC_WHY:-}"
  if [ -f "$SRCDIR/serial-remediation-worklist.sh" ]; then
    echo "HERMETIC-CONSUMED $SRCDIR/serial-remediation-worklist.sh"
    p_dvrs "$MERGE" && ok "DVRS: document mode, the shipped sequence (split on p1's sha, a section edited, assembled, the worklist consuming .before): --derived-map prints exactly the --map rows {4 6} with no full-width reason, the full map dispatched is REFUSED, the derived p2 merges derived from p1, the gate reads no FAIL (N, and arm N FAILs a superset and a subset of {4 6} (N4); a files world in the same arm prints the full map 1..8 with its full-width reason" \
      || bad "DVRS: rc=$RC ords [$DV_ORDS] $(head -2 "$WORK/dvrs.err" 2>/dev/null) | $(head -2 "$MO") | $(grep -m2 'FAIL (N' "$CO")"
    p_dvrss "$MERGE" && ok "DVRSS: subject mode, the shipped sequence (split on p1's sha list, a prd section edited, assembled, the worklist consuming prd's and SPEC's .before): exactly the --map rows {1 2}, the full map REFUSED, p2 merges derived from p1, the gate reads no FAIL (N, and arm N FAILs a superset and a subset (N4)" \
      || bad "DVRSS: rc=$RC $(head -2 "$WORK/dvrs.err" 2>/dev/null) | $(head -2 "$MO") | $(head -2 "$WORK/dvrss.split" 2>/dev/null) | $(grep -m2 'FAIL (N' "$CO")"
  else bad "DVRS: FIXTURE BROKEN -- serial-remediation-worklist.sh is not beside the merge; the shipped sequence cannot run"; fi
fi
fi # sg dv

if sg ri; then
echo
# RI: THE REPAIR-INTRODUCED CLASS (BL-1175 item 6), lib.sh ri_world: p1 and p2 merged, two repairs, p3's quoted
# shards merged end to end, the gate's arm R re-deriving each.
p_ri1 "$MERGE" && ok "RI1: p3 (8 MAJOR, 2 underived) quoting 3 spans only the second repair wrote, 2 the FIRST repair wrote, a mixed new+old, an old line and none: findings_major_repair_introduced 3, unjoined 1, keys {$RI_KEYS_WANT}; arm R re-derives and agrees, and FAILS the same pass edited to 2" \
  || bad "RI1: stage ${RI_STAGE:-?}: rc=${RC:-?} [$RI_GOT] $(grep -m1 'REFUSED' "$MO") $(grep -m2 '(R -- ' "$CO")"
[ -n "${RI_S:-}" ] && has "$MO" "blocking=5" && [ "$(ri_hdr "$RI_S" verdict)" = EXIT_CONDITION_NOT_MET ] \
  && ok "RI6: the margin -- RI1's merge reads blocking 8 - max(2, 3) = 5 > 3, EXIT_CONDITION_NOT_MET (a join reading p1 counts 5 and MET; one subtracting both counts 3 and MET)" \
  || bad "RI6: $(grep -m1 'blocking=' "$MO") verdict [$(ri_hdr "${RI_S:-/nonexistent}" verdict 2>/dev/null)]"
p_ri5 && ok "RI5: after three merges adversarial-snapshots/ holds 6 snapshots and git status lists none of them (it lists the p3 pass file)" \
  || bad "RI5: [$RI_GOT]"
p_ri7 "$MERGE" && ok "RI7: p2's snapshots deleted after p3 merged, p3 re-merged: the stored r 3 stands, UNCHANGED, the NOTE names the absent snapshot, the pass bytes unchanged" \
  || bad "RI7: stage ${RI_STAGE:-?}: [$RI_GOT] $(grep -m1 'NOTE' "$MO")"
p_ri8 "$MERGE" && ok "RI8: the merge's program rows moved to another clone root: p3 still reads attested (re-merge UNCHANGED, stored r stands, no gate note); p3 then edited to r 5 and MET: the gate reads it not attested and FAILS arm B on 8 blocking MAJOR, and the re-merge refuses it as not attested" \
  || bad "RI8: stage ${RI_STAGE:-?}: [$RI_GOT] $(grep -m1 -E 'NOTE|REFUSED' "$MO") $(grep -m1 -E 'ATTESTATION|FAIL \(B' "$CO")"
p_ri2 "$MERGE" && ok "RI2: p2's snapshots deleted, p1's kept: r 0, unjoined 8, no keys line, NOT_MET, the merge says why; arm R PENDING for p3, no FAIL" \
  || bad "RI2: stage ${RI_STAGE:-?}: rc=${RC:-?} [$RI_GOT] $(grep -m2 '(R -- ' "$CO")"
p_ri4 "$MERGE" && ok "RI4: the second repair rewrote over 25% of story 2: r 0, unjoined 8, NOT_MET, the merge names the stem" \
  || bad "RI4: stage ${RI_STAGE:-?}: rc=${RC:-?} [$RI_GOT] $(head -3 "$MO")"
p_ri9 && ok "RI9: pass 1 carrying 4 unquoted MAJOR prints no 'carry no quote: line' NOTE (the first-pass guard), while pass 2 of the same shards prints it" \
  || bad "RI9: stage ${RI_STAGE:-?}: $(grep -m1 'carry no quote' "${RI_S:-/nonexistent}/../ri_pass.1.out" 2>/dev/null)"
p_ri10 "$MERGE" rename && ok "RI10: a story renamed AND rewritten (story-2-k -> story-3-k, six of its lines replaced): the new stem is paired with the dropped one, the 25% ceiling applies, r 0, unjoined 8, the merge names story-3-k" \
  || bad "RI10: stage ${RI_STAGE:-?}: rc=${RC:-?} [$RI_GOT] $(head -3 "$MO")"
p_ri10 "$MERGE" add && ok "RI10n: the same story-3-k as a pure ADD (story-2-k stays): no dropped stem to pair with, no ceiling note, its quotes read NEW (r 3, unjoined 1)" \
  || bad "RI10n: stage ${RI_STAGE:-?}: rc=${RC:-?} [$RI_GOT] $(head -3 "$MO")"
fi # sg ri

echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
