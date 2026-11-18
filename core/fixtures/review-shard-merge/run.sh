#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# review-shard-merge/run.sh -- partition-review-diff.sh and merge-review-shards.sh, the part set
# and the JOIN of a sharded gate-1 code review and of a sharded gate-2 QA validation (--gate qa;
# arms Q1-Q16, S7-S10), and (BL-737) the seat's shard pre-check, the owner tails, the marker key, the
# content seal on review shards and the legacy rule (arms CS1-FT1). The predicates live in `lib.sh`
# beside this file; each runs the real, unmutated subject.
#
# IN PROCESS. Every cell asks its subject in process through lib.sh's ip_run: the merge, the partition and
# partition-document.sh each hold their program in a *_main function behind a BASH_SOURCE guard, content-seal.sh
# (seal_main) and wait-for-deliverable.sh (wfd_mark_main) already did, and the recorder hook is sourced in a
# subshell with its payload on stdin. The merge is sourced ONCE per script directory (ip_load). The end-to-end runs kept are EQ1-EQ8, one per distinct CLI outcome of each subject, each the same CLI
# line run both ways and compared byte for byte, with EQ0 proving the comparison can see a difference.
#
# WHAT IS AT STAKE. Check 1 in gate-validation.md reads ONE verdict line from ONE review file. A
# sharded review is N part reviewers plus one cross reviewer per cross group, and the merge writes that file. Its
# load-bearing claims are invisible to anything that only reads a finished review:
#   - the part set is RE-DERIVED from the manifest's inputs, never read off the shard directory;
#   - the merged verdict is the WORST shard verdict, never a count, the cross shard, or the last;
#   - the output matches Check 1's own pattern exactly once, and Check 1 reads the right value;
#   - every refusal writes nothing at --out.
#
# TWO SEEDED REPOSITORIES, ON PURPOSE. The merge re-runs the partition sibling. REPO A (dominant) puts
# every reviewable file under one top directory, `app/`: a first-path-component key sees one group and
# answers SERIAL, so only the adaptive split makes it partition -- arm P1 owns that. REPO B (equal) has
# three top directories of byte-identical numstat weight and is merged with --max-parts 3, where 3 x 1/3
# of the weight never exceeds 1/K of the total, so adaptive and first-component keys give the SAME map;
# every merge world is built on B.
#
# THE VERDICT WORLDS. W_disc {BLOCKED, APPROVED, APPROVED, cross APPROVED}: cross-wins, last-part-
# wins and majority all say APPROVED, worst-of says BLOCKED. W_bn {NEEDS_REWORK, BLOCKED,
# NEEDS_REWORK, cross APPROVED}: majority says NEEDS_REWORK, worst-of BLOCKED. W_ok (all APPROVED)
# stops "always BLOCKED" passing. W_c1 {NEEDS_REWORK, APPROVED, NEEDS_REWORK, cross NEEDS_REWORK}
# is the world where every one of those wrong rules AGREES with worst-of.
#
# CHECK 1'S PATTERN IS DERIVED from gate-validation.md with the sed gate-verdict-grep-shape uses,
# and the value is read back by this fixture's own reader, not by the merge's. The value rule is
# the one gate-validation.md Check 1 states, and it is cited there rather than restated here.
#
# The threshold key is named ONCE, in lib.sh's unset (fixtures scrub AI_DLC_*; I87). Everywhere
# else it is DERIVED from the partition script's own dereference site. lib.sh sets the shell
# options, scrubs AI_DLC_*, owns WORK and its one EXIT trap.
#
HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="review-shard-merge"
[ -f "$HERE/lib.sh" ] || { echo "FIXTURE BROKEN: $HERE/lib.sh is absent; nothing was asserted" >&2; exit 2; }
# ---------------------------------------------------------------------------- shards (BL-906)
# THIS FILE IS SEVEN SHARDS OF ONE FIXTURE, AND THE SPLIT IS A SCHEDULING BOUNDARY, NOT A SUBJECT BOUNDARY (the
# readset-skip shape). Every top-level arm sits inside a UNIT, `if sg <unit>; then` ... `fi # sg <unit>`, and `--group
# <x>` runs the units dealt to shard <x>. The siblings `review-shard-merge-{b,c,d,e,f,g}/run.sh` are one-line drivers that
# exec this file with `--group <letter>`; no `--group` is shard a. The seed (lib.sh, seed_controls) and the closing tally
# run in every shard.
#   a  seam gmaint story_hist   the in-process seam (EQ0-EQ8, every subject start), GM1 (lib.sh's G wrapper spawns no
#      files                    auto-maintenance, BL-868), BL-904's story history (receipt-bl904.sh), FL1
#   b  arms                     the P/V/R/Q/H/X/G arms, CS1 and OT1 (OT1 reads hand-offs the arms and CS1 save)
#   c  bl737                    the BL-737 serial, seal, key and verdict arms
#   d  bl885                    the BL-885 story arms, both lead arms (LR1; LR0 binds lead_rec and lead to ONE shard), AD1-AD3, SR2, QC1
#   e  canon                    CR1
#   f  run_rec bl808            BL-905's RR1 and BL-988's WR1, and BL-808's VB3-XC5
#   g  canon_merge wv955        CR2, WV955 and BIND956
#      bind956
# The step and role prose pins (S0-S13, XC-STEP) run no subject and live in process-rule-pins section 4i.
# THE COVERAGE JOIN (J0) runs in EVERY shard, and under --deal, before lib.sh builds anything: the declared units are
# DERIVED from this file's `if sg <unit>; then` lines, the dealt lists must be disjoint and their union exact, every
# arm line must sit inside a unit, and every declared shard must have a driver directory. It proves it can fire first,
# on a seeded duplicate and a seeded omission.
# --deal prints each shard's dealt units, arms and its static unit-cell count (an arm's `cell` declarations in its lib.sh
# predicate, at least 1), then exits 0.
SHARDS="a b c d e f g"
UNITS_a="seam gmaint story_hist files"
UNITS_b="arms"
UNITS_c="bl737"
UNITS_d="bl885"
UNITS_e="canon"
UNITS_f="run_rec bl808"
UNITS_g="canon_merge wv955 bind956"
GROUP=a; RSM_DEAL=0; RSM_TAB=0; _grp=0
while [ $# -gt 0 ]; do
  case "$1" in
    --group) _grp=1; GROUP="${2:-}"
      [ -n "$GROUP" ] || { echo "usage: run.sh [--group <shard> | --deal]: --group needs a shard name" >&2; exit 2; }
      shift; shift ;;
    --deal) RSM_DEAL=1; shift ;;
    --arm-table) RSM_TAB=1; shift ;;
    *) echo "usage: run.sh [--group <shard>] | --deal | --arm-table" >&2; exit 2 ;;
  esac
done
[ $((_grp + RSM_DEAL + RSM_TAB)) -le 1 ] || { echo "usage: run.sh [--group <shard>] | --deal | --arm-table: each takes no other" >&2; exit 2; }
case " $SHARDS " in *" $GROUP "*) ;; *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;; esac
eval "MINE=\"\${UNITS_$GROUP:-}\""
# MINE is the units whose ARMS run: the shard's deal, or every unit under --deal.
[ "$RSM_DEAL" = 0 ] || { MINE=""; for _s in $SHARDS; do eval "MINE=\"\$MINE \${UNITS_$_s}\""; done; MINE="${MINE# }"; }
[ "$GROUP" = a ] || NAME="review-shard-merge-$GROUP"
rsm_broken() { echo "FIXTURE BROKEN: $1" >&2; echo "$NAME: FIXTURE BROKEN" >&2; exit 2; }
[ -n "$MINE" ] || rsm_broken "shard '$GROUP' has no UNITS_$GROUP list; a shard dealt nothing passes everything it never checked"
sg() { case " $MINE " in *" $1 "*) return 0 ;; esac; return 1; }
rsm_partition_ok() { # <declared ids file> <dealt ids file> -> 0 when dealt is disjoint and covers declared exactly
  local dup miss extra
  dup="$(sort "$2" | uniq -d | tr '\n' ' ')"
  miss="$(sort -u "$2" | comm -23 <(sort -u "$1") - | tr '\n' ' ')"
  extra="$(sort -u "$2" | comm -13 <(sort -u "$1") - | tr '\n' ' ')"
  [ -z "$dup$miss$extra" ] && return 0
  echo "dealt twice: {${dup% }} dealt to no shard: {${miss% }} dealt but not declared: {${extra% }}"
  return 1
}
RSM_JW="$(mktemp -d "${TMPDIR:-/tmp}/review-shard-merge-join.XXXXXX")" || rsm_broken "mktemp failed"
printf '%s\n' u1 u2 u3 > "$RSM_JW/pd"; printf '%s\n' u1 u2 u2 u3 > "$RSM_JW/pdup"; printf '%s\n' u1 u3 > "$RSM_JW/pmiss"; printf '%s\n' u3 u1 u2 > "$RSM_JW/pok"
if rsm_partition_ok "$RSM_JW/pd" "$RSM_JW/pdup" > /dev/null || rsm_partition_ok "$RSM_JW/pd" "$RSM_JW/pmiss" > /dev/null \
   || ! rsm_partition_ok "$RSM_JW/pd" "$RSM_JW/pok" > /dev/null; then
  rm -rf "$RSM_JW"; rsm_broken "the coverage join's self-probe did not discriminate (duplicate, omission, exact)"
fi
RSM_SELF="$HERE/run.sh"
sed -n 's/^if sg \([a-z0-9_][a-z0-9_]*\); then$/\1/p' "$RSM_SELF" > "$RSM_JW/declared"
for _s in $SHARDS; do eval "printf '%s\n' \${UNITS_$_s}" | tr ' ' '\n'; done | grep . > "$RSM_JW/dealt"
_ndecl="$(grep -c . "$RSM_JW/declared")" || _ndecl=0
_ndup="$(sort "$RSM_JW/declared" | uniq -d | grep -c .)" || _ndup=0
[ "$_ndecl" -gt 0 ] && [ "$_ndup" = 0 ] || { rm -rf "$RSM_JW"; rsm_broken "$_ndecl unit guards derived from $RSM_SELF ($_ndup declared twice)"; }
_why="$(rsm_partition_ok "$RSM_JW/declared" "$RSM_JW/dealt")" || { rm -rf "$RSM_JW"; rsm_broken "the shard partition does not cover the guarded units exactly -- $_why"; }
# THE DIST-ONLY SHARDS: DIST_SHARDS reach no consumer. Each carries a non-empty .dist-only and no other shard does,
# and a consumer holds none of their directories, so only a DIST_SHARDS shard, whose inputs.decl declares its
# dist-only siblings, checks their drivers and markers; a shipped shard declares none and skips them.
DIST_SHARDS="e f g"
case " $DIST_SHARDS " in *" $GROUP "*) _me=dist ;; *) _me=ship ;; esac
[ ! -e "$HERE/.dist-only" ] || { rm -rf "$RSM_JW"; rsm_broken "shard 'a' carries $HERE/.dist-only, but shard a ships"; }
for _s in $SHARDS; do
  [ "$_s" = a ] && continue
  case " $DIST_SHARDS " in *" $_s "*) _do=1 ;; *) _do=0 ;; esac
  [ "$_do" = 1 ] && [ "$_me" = ship ] && continue
  _drv="$HERE/../review-shard-merge-$_s/run.sh"
  [ -f "$_drv" ] && grep -qF -- "--group $_s" "$_drv" || { rm -rf "$RSM_JW"; rsm_broken "shard '$_s' is declared but $_drv does not drive it"; }
  [ "$_do" = 0 ] || [ -s "${_drv%/run.sh}/.dist-only" ] || { rm -rf "$RSM_JW"; rsm_broken "shard '$_s' is in DIST_SHARDS but ${_drv%/run.sh}/.dist-only is absent or empty"; }
  [ "$_do" = 1 ] || [ ! -e "${_drv%/run.sh}/.dist-only" ] || { rm -rf "$RSM_JW"; rsm_broken "shard '$_s' carries ${_drv%/run.sh}/.dist-only but is not in DIST_SHARDS"; }
done
# Each arm line's unit (one awk): `<predicate> <unit>`, the unit `-` for an arm outside every guard.
awk '/^if sg [a-z0-9_]+; then$/ { u = $3; sub(/;$/, "", u) } /^fi # sg [a-z0-9_]+$/ { u = "" }
  /^[[:space:]]*arm2? [a-z0-9_]+ / { print $2 " " (u == "" ? "-" : u) }' "$RSM_SELF" > "$RSM_JW/arms"
_nout="$(grep -c ' -$' "$RSM_JW/arms")" || _nout=0
_narm="$(grep -c . "$RSM_JW/arms")" || _narm=0
[ "$_narm" -gt 0 ] && [ "$_nout" = 0 ] || { rm -rf "$RSM_JW"; rsm_broken "$_nout of $_narm arm line(s) sit outside every unit guard"; }
# THE ARM TABLE receipt-bl980.sh joins each receipt's call site to: `<arm> <unit> <shard> ship|dist`, one row per arm
# line above, kept past the join directory's removal.
: > "$RSM_JW/ushard"
for _s in $SHARDS; do
  case " $DIST_SHARDS " in *" $_s "*) _k=dist ;; *) _k=ship ;; esac
  eval "_us=\"\${UNITS_$_s}\""
  for _u in $_us; do printf '%s %s %s\n' "$_u" "$_s" "$_k" >> "$RSM_JW/ushard"; done
done
RSM_ARMTAB="$(awk 'NR == FNR { s[$1] = $2 " " $3; next } { print $1, $2, (($2 in s) ? s[$2] : "- -") }' "$RSM_JW/ushard" "$RSM_JW/arms")"
# --arm-table prints that table and exits: receipt-bl980.sh run on its own (its verify form) reads it from here.
[ "$RSM_TAB" = 0 ] || { rm -rf "$RSM_JW"; printf '%s\n' "$RSM_ARMTAB"; exit 0; }
if [ "$RSM_DEAL" = 1 ]; then
  # The static unit-cell count: an arm's `cell` declarations in its lib.sh body (at least 1).
  awk 'match($0, /^p_[a-z0-9_]+\(\) *\{/) { p = substr($0, 3, RLENGTH - 2); sub(/\(.*/, "", p); n[p] += 0 }
    /^[[:space:]]*#/ { next } p != "" { s = $0; while (match(s, /(^|[^a-z_])cell [a-z0-9]/)) { n[p]++; s = substr(s, RSTART + RLENGTH) } }
    /^}/ { p = "" } END { for (k in n) print k, n[k] }' "$HERE/lib.sh" > "$RSM_JW/cells"
  _total=0
  for _s in $SHARDS; do
    eval "_us=\"\${UNITS_$_s}\""
    _out="$(awk -v us=" $_us " 'FILENAME == ARGV[1] { c[$1] = $2; next }
      { if (index(us, " " $2 " ")) { na++; x = ($1 in c) && c[$1] > 0 ? c[$1] : 1; cl += x } }
      END { printf "arms=%d cells=%d\n", na, cl }' "$RSM_JW/cells" "$RSM_JW/arms")"
    echo "DEAL $_s units=$(printf '%s' "$_us" | tr ' ' ',') $_out"
    _c="${_out#*cells=}"; _total=$((_total + ${_c%% *}))
  done
  echo "DEAL-TOTAL cells=$_total"
fi
rm -rf "$RSM_JW"
echo "  [J0] coverage join: $_ndecl units derived from the sg guards, dealt disjointly across {$SHARDS}, union exact; $_narm arm lines each inside a unit; this shard runs {$MINE}"
[ "$RSM_DEAL" = 0 ] || exit 0
# I10 reads run.sh, not lib.sh, for the ambient-env scrub; this is the same scrub lib.sh performs.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
. "$(cd "$HERE/../lib" && pwd)/world.sh" || { echo "FIXTURE BROKEN: cannot source lib/world.sh" >&2; exit 2; }
. "$HERE/lib.sh"
# fx_inproc (the in-process pass logger).
. "$(cd "$HERE/../lib" && pwd)/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/world.sh"
echo "HERMETIC-CONSUMED core/scripts/partition-review-diff.sh"
echo "HERMETIC-CONSUMED core/scripts/merge-review-shards.sh"
echo "HERMETIC-CONSUMED core/scripts/content-seal.sh"
echo "HERMETIC-CONSUMED core/scripts/wait-for-deliverable.sh"
echo "HERMETIC-CONSUMED core/hooks/ai-dlc-content-seal.sh"
echo "HERMETIC-CONSUMED core/scripts/record-only-diff.sh"
echo "HERMETIC-CONSUMED core/scripts/sprint-status.sh"

# ---------------------------------------------------------------------------------- the arms
echo "$NAME:"
seed_controls

if sg seam; then
# ---------------------------------------------------------------- the in-process seam (EQ1-EQ8)
# Every arm below asks its subject IN PROCESS (lib.sh ip_run). These are the end-to-end runs kept, one per
# distinct CLI outcome of each subject: the same CLI line run in process and as a process must answer
# byte-identically (stdout, stderr, exit code, the files it writes), and the outcomes of one subject must
# differ from each other, so a seam that answered one fixed thing cannot pass.
eq_arm() { # <id> <label> <pair names...>: each pair passed eq_pair (EQP_<name>=1) and their answers pairwise differ
  local id="$1" lbl="$2" a b w=""; shift 2
  for a in "$@"; do eval "[ \"\${EQP_$a:-0}\" = 1 ]" || w="$w $a{$(eval "printf %s \"\${EQW_$a:-not run}\"")}"; done
  for a in "$@"; do for b in "$@"; do
    [ "$a" \< "$b" ] || continue
    ! cmp -s "$WORK/eq-$a.ans" "$WORK/eq-$b.ans" || w="$w $a=$b"
  done; done
  if [ -z "$w" ]; then ok "$id: $lbl"; else bad "$id: the in-process seam differs from the CLI, or two outcomes answered alike:$w"; fi
}
eqp() { # <name> <want rc> eq_pair-args... -> EQP_<name>, EQW_<name>
  local n="$1" want="$2"; shift 2
  if eq_pair "$n" "$@" && [ "$EQ_RC" = "$want" ]; then eval "EQP_$n=1"; else eval "EQP_$n=0; EQW_$n=\"rc=\$EQ_RC want $want\$EQ_WHY\""; fi
}
_eqd="$(world4 "$SRCDIR" APPROVED APPROVED APPROVED APPROVED)"; _eqo="$(out_of "$_eqd")"
EQ_FILES="$_eqo" eqp mrg_ok 0 -e "AI_DLC_PROJECT_ROOT=$PROJ" "$MERGE" mrs_main "$_eqd" --gate code-review --out "$_eqo"
ip_run -e "AI_DLC_PROJECT_ROOT=$PROJ" "$MERGE" mrs_main "$_eqd" --gate code-review --out "$_eqo" > /dev/null 2>&1 < /dev/null
EQ_FILES="$_eqo" eqp mrg_same 0 -e "AI_DLC_PROJECT_ROOT=$PROJ" "$MERGE" mrs_main "$_eqd" --gate code-review --out "$_eqo"
rm -f "$_eqo"
EQ_FILES="$_eqo" eqp chk_ok 0 -e "AI_DLC_PROJECT_ROOT=$PROJ" "$MERGE" mrs_main "$_eqd" --gate code-review --check-shard "$_eqd/1.md"
shard "$_eqd" 2 APPROVED 3
EQ_FILES="$_eqo" eqp chk_no 2 -e "AI_DLC_PROJECT_ROOT=$PROJ" "$MERGE" mrs_main "$_eqd" --gate code-review --check-shard "$_eqd/2.md"
EQ_FILES="$_eqo" eqp mrg_no 2 -e "AI_DLC_PROJECT_ROOT=$PROJ" "$MERGE" mrs_main "$_eqd" --gate code-review --out "$_eqo"
eq_arm EQ1 "merge-review-shards.sh in process answers byte-for-byte what the CLI does: MERGED (rc 0, the review written), UNCHANGED over its own output (rc 0), REFUSED on a part citing another part (rc 2, nothing written)" mrg_ok mrg_same mrg_no
eq_arm EQ2 "--check-shard in process answers byte-for-byte what the CLI does: SHARD-OK on a clean shard, REFUSED on a part citing another part" chk_ok chk_no
_eqs="$WORK/eq-serial-1-code-review.md"
{ printf '# Code Review: 1\n\n'; adv_l; printf '\n## Summary\nSerial.\n\n## Verdict\nAPPROVED\n\n## Findings\n\nNone.\n'; } > "$_eqs"
eqp ser_ok 0 -e "AI_DLC_PROJECT_ROOT=$PROJ" "$MERGE" mrs_main --check-serial "$_eqs" --gate code-review
printf '\n## Verdict\nBLOCKED\n' >> "$_eqs"
eqp ser_no 2 -e "AI_DLC_PROJECT_ROOT=$PROJ" "$MERGE" mrs_main --check-serial "$_eqs" --gate code-review
eq_arm EQ3 "--check-serial in process answers byte-for-byte what the CLI does: SERIAL-OK on one APPROVED verdict, REFUSED on two different verdict values" ser_ok ser_no
_eqw="$(mktemp -d "$WORK/eqp.XXXXXX")"
EQ_FILES="$_eqw/sd/.manifest" eqp prt_ok 0 "$PART" prd_main --map "$REPO_B" "$B_BASE" "$B_SHA" --min-files 4 --max-parts 3 --shard-dir "$_eqw/sd"
eqp prt_ser 3 -e "$KEY=0" "$PART" prd_main --map "$REPO_B" "$B_BASE" "$B_SHA"
eqp prt_no 2 "$PART" prd_main --map "$REPO_B" "$B_BASE" "$B_SHA" --max-parts 1
eq_arm EQ4 "partition-review-diff.sh in process answers byte-for-byte what the CLI does: a map and its manifest (rc 0), SERIAL with the key at 0 (rc 3), REFUSED on --max-parts 1 (rc 2)" prt_ok prt_ser prt_no
eqp pdc_ok 0 "$SRCDIR/partition-document.sh" pdoc_main --cross-groups 3
eqp pdc_no 64 "$SRCDIR/partition-document.sh" pdoc_main --cross-groups 1
eq_arm EQ5 "partition-document.sh --cross-groups in process answers byte-for-byte what the CLI does: the K=3 table (rc 0), the USAGE refusal at K=1 (rc 64)" pdc_ok pdc_no
_eqm="$(world4 "$SRCDIR" APPROVED APPROVED APPROVED APPROVED)"
fire "$_eqm/1.md" agent && fire "$_eqm/2.md" agent || bad "EQ6-EQ8: FIXTURE BROKEN -- the recorder wrote no row for the seam world"
EQ_FILES="$_eqm/1.md $LEDGER" eqp mk_ok 0 -e "AI_DLC_PROJECT_ROOT=$PROJ" "$WFD_SRC" wfd_mark_main --mark "$_eqm/1.md" implementation code-reviewer 1 findings=1
EQ_FILES="$_eqm/2.md $LEDGER" eqp mk_no 64 -e "AI_DLC_PROJECT_ROOT=$PROJ" "$WFD_SRC" wfd_mark_main --mark "$_eqm/2.md" implementation code-reviewer 3 findings=1
eq_arm EQ6 "wait-for-deliverable.sh --mark on a review shard in process (wfd_mark_main) answers byte-for-byte what the CLI does: marked (rc 0, the marker and its ledger row written), refused on a <shard> that is not the file key (rc 64, nothing written)" mk_ok mk_no
eqp seal_ok 0 "$SEAL_SRC" seal_main --review-shard "$_eqm/2.md"
sed -i.bak -e 's/^## Summary$/## Overview/' "$_eqm/2.md" && rm -f "$_eqm/2.md.bak"
eqp seal_no 1 "$SEAL_SRC" seal_main --review-shard "$_eqm/2.md"
eq_arm EQ7 "content-seal.sh --review-shard in process (seal_main) answers byte-for-byte what the CLI does: SEAL-OK on a sealed shard (rc 0), SEAL-REFUSED once a Bash rewrite moved it (rc 1)" seal_ok seal_no
# EQ7b, --first-tool-ts (FT1's mode): a state dir with a gate-part row prints its ts (rc 0); one that does not
# exist is refused (rc 2). The ledger row's ts is fixed so the answer names no clock.
_eqf="$(mktemp -d "$WORK/eqf.XXXXXX")"; mkdir -p "$_eqf/_bmad-output/planning-artifacts"
printf '{"v":1,"kind":"content-seal","ts":"2001-02-03T04:05:06Z","path":"gate-adjudication/g1.part-1.jsonl","actor":"agent","agent_id":"a0123456789abcdef","session":"s","tool":"Write","tool_use_id":"t","transcript_path":"/dev/null","root":"%s","sha256":"0"}\n' \
  "$(cd "$_eqf" && pwd -P)" > "$_eqf/_bmad-output/planning-artifacts/.artifact-writes.jsonl"
eqp fts_ok 0 "$SEAL_SRC" seal_main --first-tool-ts "$_eqf/_bmad-output"
eqp fts_no 2 "$SEAL_SRC" seal_main --first-tool-ts "$_eqf/absent"
eq_arm EQ7b "content-seal.sh --first-tool-ts in process (seal_main) answers byte-for-byte what the CLI does: the earliest tool row's ts (rc 0), and a missing state dir refused (rc 2)" fts_ok fts_no
printf '{"tool_name":"Write","tool_input":{"file_path":"%s"},"session_id":"fixture-session","tool_use_id":"toolu_fixture","transcript_path":"/dev/null","agent_id":"a0123456789abcdef","agent_type":"code-reviewer"}\n' "$_eqm/3.md" > "$WORK/eq-hook-row.json"
printf '{"tool_name":"Write","tool_input":{"file_path":"%s"},"session_id":"fixture-session","tool_use_id":"toolu_fixture","transcript_path":"/dev/null"}\n' "$WORK/eq-not-sealed.md" > "$WORK/eq-hook-none.json"
EQ_IN="$WORK/eq-hook-row.json" EQ_FILES="$LEDGER" eqp hk_row 0 -e "CLAUDE_PROJECT_DIR=$MAIN" "$HOOK" -
EQ_IN="$WORK/eq-hook-none.json" EQ_FILES="$LEDGER" eqp hk_none 0 -e "CLAUDE_PROJECT_DIR=$MAIN" "$HOOK" -
cp "$WORK/eq-hk_row.ans" "$WORK/eq-hk_row.ans.o"; { cat "$WORK/eq-hk_row.ans.o"; grep -c . "$LEDGER"; } > "$WORK/eq-hk_row.ans"
_hk1="$(grep -c . "$LEDGER")"; EQ_IN="$WORK/eq-hook-row.json" ip_run -e "CLAUDE_PROJECT_DIR=$MAIN" "$HOOK" - < "$WORK/eq-hook-row.json"; _hk2="$(grep -c . "$LEDGER")"
[ "$_hk2" = $((_hk1 + 1)) ] || EQP_hk_row=0 EQW_hk_row="the in-process recorder appended $((_hk2 - _hk1)) row(s), want 1"
# EQ0, the comparison's own control: the same partition pair with ONE argument added on the CLI side only
# (EQ_CLI_TAIL) must be reported as differing, so a comparison that cannot see a difference cannot pass EQ1-EQ8.
if EQ_CLI_TAIL="--max-parts=junk" eq_pair eq0 "$PART" prd_main --map "$REPO_B" "$B_BASE" "$B_SHA"; then
  bad "EQ0: FIXTURE BROKEN -- eq_pair called a CLI run with an extra argument byte-equal to the in-process run"
else ok "EQ0: eq_pair reports a CLI run given one extra argument as differing from the in-process run (${EQ_WHY# })"; fi
eq_arm EQ8 "the recorder hook sourced in process answers byte-for-byte what the CLI does on a review-shard Write (one ledger row appended) and on a path outside the sealed set (no row)" hk_row hk_none
fi # sg seam

arm() { # <predicate> <label-ok> <label-bad>
  if "p_$1" "$SRCDIR"; then ok "$2"; eval "ARMOK_$1=1"; else bad "$3 (rc=${RC:-?}): $(cat "$MO" 2>/dev/null | head -3)"; fi
}
arm2() { # <predicate> <label-ok> <label-bad> -- the predicate sets WHY to what it saw
  WHY=""
  if "p_$1" "$SRCDIR"; then ok "$2"; eval "ARMOK_$1=1"; else bad "$3:${WHY:- (no reason recorded)}"; fi
}
if sg arms; then
arm part "P1: repo A (all files under app/) partitions to >= 2 parts above --min-files 4, app/ split across parts, no part keyed on bare app/, the docs/reviews/ artifact excluded" \
         "P1: repo A did not partition by adaptive depth"
arm dflt_lo "P2: key unset, no flag, $((DFLT - 1)) reviewable files ($DFLT in the diff, one under a scan root) -> exit 3, 'SERIAL:' naming the built-in default $DFLT and $KEY, no manifest" \
             "P2: below the built-in default did not answer SERIAL naming the default"
arm dflt_hi "P2b: key unset, no flag, exactly $DFLT reviewable files -> partitions to >= 2 parts (the default is ON, and the boundary is inclusive)" \
            "P2b: exactly the built-in default's file count did not partition"
arm off "P2c: $KEY=0, and --min-files 0, each on $DFLT files -> exit 3, 'SERIAL: review sharding is disabled' naming the source, no manifest" \
        "P2c: a zero threshold did not answer SERIAL disabled"
arm refuse_val "P2d: $KEY set but EMPTY, and $KEY=abc -> each REFUSED exit 2 'is not a non-negative integer', no manifest (empty is NOT unset)" \
               "P2d: an empty or non-numeric key was not refused"
arm prec "P2e: --min-files $((DFLT + 1)) with $KEY=4 on $DFLT files -> SERIAL naming --min-files; --min-files 4 with $KEY=$((DFLT + 1)) -> partitions (the flag wins both ways)" \
         "P2e: the key overrode --min-files"
arm dmerge "P2f: a repo of $((DFLT + 2)) files partitioned with the threshold UNSET records a NUMERIC min-files in its manifest and merges end to end (the merge hands it back as --min-files)" \
           "P2f: a default-built partition did not merge, or its manifest did not record the numeric threshold"
arm env_key "P3: the key set to 4 in the environment, no flag -> repo B partitions to >= 2 parts" \
        "P3: the environment threshold did not partition"
arm worst "V1: worst-of -- {B,A,A,xA} merges BLOCKED (cross, last and majority say APPROVED); {NR,B,NR,xA} merges BLOCKED (majority says NR); all-APPROVED merges APPROVED; each read back Check 1's way" \
          "V1: the merged verdict is not the worst shard verdict"
arm c1 "C1: the merged file matches Check 1's derived pattern exactly once and Check 1's read gives NEEDS_REWORK" \
       "C1: the merged file does not match Check 1 exactly once with the right value"
arm conserve "C2: conservation -- a unique token and the finding heading of each of parts 1-3 and cross appear in the merged file" \
             "C2: a shard's content was lost in the merge"
arm miss_ord "R1: part 2 missing -> REFUSED, exit 2, nothing at --out" "R1: a missing part was not refused cleanly"
arm miss_cross "R2: cross.md missing -> REFUSED, exit 2, nothing at --out" "R2: a missing cross shard was not refused cleanly"
arm dup "R3: 1.md beside 01.md -> REFUSED 'delivered more than once', exit 2, nothing at --out" "R3: a duplicate part was not refused cleanly"
arm part_cite "R4: part 2 reporting a finding citing part 3 -> REFUSED, exit 2, nothing at --out" "R4: a part citing another part was not refused cleanly"
arm cross_one "R5: a cross finding citing one part -> REFUSED, exit 2, nothing at --out" "R5: a one-part cross finding was not refused cleanly"
arm sha_dir "R6: a shard dir named for another sha12 than the manifest's -> REFUSED, exit 2, nothing at --out" "R6: a manifest/dir-name sha mismatch was not refused cleanly"
arm sha_rev "R7: a shard whose reviewed-sha is not the manifest's sha -> REFUSED, exit 2, nothing at --out" "R7: a reviewed-sha mismatch was not refused cleanly"
arm moved "R8: the worktree's scan roots moved after the manifest was written (the re-run still partitions, differently) -> REFUSED 'differs from the map it records', nothing at --out" \
          "R8: a manifest map that no longer matches a re-run partition was not refused cleanly"
arm a3 "R9: a shard body carrying '## Verdict' -> REFUSED on Check 1's count (2), exit 2, nothing at --out" "R9: a shard verdict heading was not refused"
arm rerun "R10: an identical re-merge is UNCHANGED; a re-merge after shard 1 changed -> REFUSED 'never overwritten', exit 2, the first review byte-unchanged" \
          "R10: a re-merge over a different existing review was not refused with the file intact"
arm anc "R11: a base that is not an ancestor of the frozen sha (a sibling commit, same two-dot file set) -> partition REFUSED on stderr, exit 2, no map, no manifest" \
        "R11: a diverged base was partitioned"
arm cross_sha "R12: cross.md whose reviewed-sha is the base -> REFUSED 'not the frozen sha', exit 2, nothing at --out" \
              "R12: a cross shard reviewing another tree was not refused"
arm bad_verdict "R13: 'shard-verdict: PASS' -> REFUSED, exit 2, nothing at --out" "R13: a verdict outside the ranked three was not refused"
arm noparts "R14: a '#### ' finding under ## Findings with no 'parts:' line -> REFUSED, exit 2, nothing at --out" \
            "R14: an uncited finding was not refused"
arm manifest "R15: an identical partition re-run leaves .manifest; a --max-parts 2 re-run (a different map) -> REFUSED 'never overwritten', manifest byte-unchanged" \
             "R15: a differing partition re-run over an existing manifest was not refused with the manifest intact"
arm two_sha "R16: a shard carrying two 'reviewed-sha:' lines (the right one first) -> REFUSED, exit 2, nothing at --out" \
            "R16: a second reviewed-sha line was not refused"
arm default_k "P4: four equal-weight groups and no --max-parts -> exactly 4 parts (the default K)" \
              "P4: the default part ceiling is not 4"
arm stray "R17: a 'parts:' line behind a bullet inside ## Findings, and a '#### ' citing part 3 under '## Critical Issues' beside a real ## Findings -> each REFUSED, exit 2, nothing at --out" \
          "R17: a parts: line outside a '#### ' finding under ## Findings was not refused"
arm nofind "R18: a shard with no '## Findings' section -> REFUSED, exit 2, nothing at --out" "R18: a shard without ## Findings was merged"
arm knob "R19: --min-files, the env key and --max-parts at 18446744073709551617 -> each REFUSED 'longer than 9 digits', no manifest; a 9-digit --min-files answers SERIAL" \
         "R19: a value over 9 digits was not refused before arithmetic"
arm fence_nested "R20: a '#### ' finding inside a four-backtick fence holding a three-backtick block is not counted -> MERGED with the base world's findings count" \
                 "R20: a four-backtick fence closed on the inner three-backtick line and the fenced finding was counted"
arm q_worst "Q1: --gate qa worst-of -- all PASS merges PASS; one part NEEDS_REWORK (cross PASS) merges NEEDS_REWORK; cross NEEDS_REWORK (parts PASS) merges NEEDS_REWORK; each read back Check 1's way" \
            "Q1: the merged QA verdict is not the worst shard verdict"
arm q_table "Q2: a cross shard carrying a '| AC | Verdict |' table under '## Acceptance Criteria' merges with exactly one Check-1 match, every shard's token and finding conserved" \
            "Q2: a QA cross shard with a per-AC table did not merge to exactly one Check-1 match"
arm q_title "Q3: the merged title is '# Code Review: 1 (merged from 4 shards)' for gate 1 and '# QA Validation: 1 (merged from 4 shards)' for gate 2" \
            "Q3: a merged title does not name its gate"
arm q_fenced "Q4: a part shard quoting '## Acceptance Criteria' and '## Deferred ACs' inside a fence merges (the section refusals skip fenced text)" \
             "Q4: a fenced section heading in a part shard was refused"
arm q_part_ac "Q5: a part shard carrying '## Acceptance Criteria' -> REFUSED, exit 2, nothing at --out" "Q5: a part shard's per-AC section was merged"
arm q_part_def "Q6: a part shard carrying '## Deferred ACs' -> REFUSED, exit 2, nothing at --out" "Q6: a part shard's deferred-AC section was merged"
arm q_cross_noac "Q7: cross.md without '## Acceptance Criteria' -> REFUSED, exit 2, nothing at --out" "Q7: a cross shard with no per-AC section was merged"
arm q_cross_twoac "Q8: cross.md with two '## Acceptance Criteria' sections -> REFUSED, exit 2, nothing at --out" "Q8: a cross shard with two per-AC sections was merged"
arm q_cross_twodef "Q9: cross.md with two '## Deferred ACs' sections -> REFUSED, exit 2, nothing at --out" "Q9: a cross shard with two deferred-AC sections was merged"
arm q_nodef "Q10: cross.md with NO '## Deferred ACs' merges (at most one, not exactly one)" "Q10: a cross shard without a deferred-AC section was refused"
arm q_rank "Q11: a qa shard carrying 'shard-verdict: APPROVED' -> REFUSED, exit 2 (gate 1's set is not gate 2's)" "Q11: a gate-1 verdict was ranked under --gate qa"
arm q_pm "Q12: pass markers, both gates -- dir -p2 with --out -p2 merges, dir -p2 with an unmarked --out and an unmarked dir with --out -p2 refuse (qa); the same three cells for code-review at -p3/-p2" \
         "Q12: a shard directory's pass marker and --out's disagree and the merge went ahead, or agree and it refused"
arm q_suffix "Q13: a <idx>-code-review-<sha12> dir merged --gate qa, and a <idx>-qa-validation-<sha12> dir merged --gate code-review -> each REFUSED, nothing at --out" \
             "Q13: a shard directory of the other gate was merged"
arm q_gate "Q14: --gate deploy -> REFUSED, exit 2, nothing at --out" "Q14: an unknown gate was not refused"
arm q_vset "Q15: qa.md declaring a third verdict -> --gate qa REFUSED; code-reviewer.md declaring a fourth -> --gate qa still merges PASS and --gate code-review refuses (QA's set is lifted from qa.md)" \
           "Q15: QA's verdict set is not lifted from qa.md alone"
arm q_secvar "Q16: part shards carrying '## Acceptance Criteria:', '##  Acceptance Criteria', '## acceptance criteria', '### ACCEPTANCE CRITERIA', '### Deferred ACs', '## Deferred / operator-owned', '## deferred acs', and a cross shard with a second '## Acceptance Criteria:' -> each REFUSED; the variants inside a fence and '#### ' findings titled with a section name merge" \
             "Q16: a section-heading variant escaped the count, or a fenced variant or a '#### ' finding was counted"
arm q_ho_ok "H1: part 2's 'handover: AC7' matched by cross's 'handover-run: 2 AC7 RED' merges PASS (the shard verdicts' worst-of), read back Check 1's way, the replay tabled" \
            "H1: a matched RED hand-over did not merge at the shard verdicts' worst-of"
arm q_ho_unm "H2: part 2's 'handover: AC7' with no 'handover-run:' in cross.md -> REFUSED naming '2 AC7', exit 2, nothing at --out" \
             "H2: an unmatched hand-over was merged -- its HARD GATE replay was run by nobody"
arm q_ho_orph "H3: cross.md's 'handover-run: 2 AC7 RED' with no hand-over in part 2 -> REFUSED, exit 2, nothing at --out" \
              "H3: an orphan handover-run was merged"
arm q_ho_force "H4: 'handover-run: 2 AC7 GREEN-SURVIVED', and NO-BASELINE, each over four PASS shards -> merges NEEDS_REWORK, read back Check 1's way" \
               "H4: an unmet hand-over replay did not force NEEDS_REWORK"
arm q_ho_cross "H5: a 'handover:' line in cross.md -> REFUSED, exit 2, nothing at --out" "H5: a cross-shard hand-over was merged"
arm q_ho_prun "H6: a 'handover-run:' line in part shard 3 -> REFUSED, exit 2, nothing at --out" "H6: a part-shard handover-run was merged"
arm q_ho_fenced "H7: 'handover: AC7' fenced in part 2 and 'handover-run: 2 AC9 GREEN-SURVIVED' fenced in cross merge PASS (neither is counted)" \
                "H7: a fenced hand-over line was counted"
arm q_ho_shape "H8: a replay finding citing '1, 2' for a part-2 replay, and a bulleted '- handover: AC7', each REFUSED" \
               "H8: a mis-cited replay finding or a bulleted hand-over was merged"
arm q_ho_multi "H9: part 2's 'handover: AC7 AC8' with only 'handover-run: 2 AC7 RED' in cross.md -> REFUSED 'names more than one AC', nothing at --out" \
               "H9: a two-AC hand-over line was merged -- the second AC's replay is run by nobody"
arm q_ho_twoline "H10: two 'handover:' lines in one part-2 finding, both run -> REFUSED on the per-finding count, nothing at --out" \
                 "H10: a finding carrying two hand-over lines was merged"
arm q_ho_dup "H11: two part-2 findings each 'handover: AC7', run once -> REFUSED 'handed over more than once', nothing at --out" \
             "H11: a duplicate hand-over was merged"
arm q_ho_deco "H12: '**handover:** AC7', '*handover*: AC7', a backtick-quoted and a '>'-quoted hand-over, 'hand-over: AC7', and the same for handover-run -> each REFUSED as a malformed hand-over" \
              "H12: a decorated, quoted or hyphenated hand-over line was merged -- the AC dropped with no replay owed"
arm q_ho_nocolon "H13: 'handover - AC7', 'handover AC7', 'handover-run 2 AC7 RED' and 'handover-run - 2 AC7 RED' at column 0 -> each REFUSED as a malformed hand-over" \
                 "H13: a column-0 hand-over missing its colon was merged"
arm q_ho_prose "H14: prose naming the hand-over at column 0 ('The handover step ...', 'Handover to the cross shard: none ...', 'Handover step', 'hand-over is not owed') merges PASS" \
               "H14: prose about the hand-over was refused as a malformed hand-over line"
arm q_ho_acid "H15: an empty 'handover:' (recorded as '-') and 'handover: .', each with its matching run -> REFUSED, an <AC-id> begins with a letter or digit" \
              "H15: a hand-over naming no AC was merged"
arm q_hc_dash "H16: part 2 declaring 'handovers: 1' with its hand-over written 'handover — AC7' (em dash, unparsed) -> REFUSED on the count mismatch, nothing at --out" \
              "H16: an em-dash hand-over under a declared count of 1 was not refused on the count"
arm q_hc_hidden "H17: 'handovers: 1' with the hand-over as a pipe-table row and as an HTML comment (forms the malformed-line pattern does not match) -> each REFUSED on the count mismatch" \
                "H17: a hand-over the malformed-line pattern cannot see merged with no replay owed"
arm q_hc_zero "H18: 'handovers: 0' over a correct, run 'handover: AC7' -> REFUSED on the count mismatch" \
              "H18: a declared count of 0 over a parsed hand-over was merged"
arm q_hc_missing "H19: a part shard with no 'handovers:' line -> REFUSED, nothing at --out" \
                 "H19: a part shard without its declared hand-over count was merged"
arm q_hc_two "H20: a part shard with two 'handovers:' lines -> REFUSED, nothing at --out" \
             "H20: a part shard declaring its hand-over count twice was merged"
arm q_hc_nonint "H21: 'handovers: x', '-1', 2^64, and '?' / '[1]' from a cwd holding files 0 and 1 -> each REFUSED as not a non-negative integer" \
                "H21: a non-integer hand-over count was merged"
arm q_hc_cross "H22: a 'handovers:' line in cross.md -> REFUSED, nothing at --out" \
               "H22: a cross shard declaring a hand-over count was merged"
arm q_hc_none "H23: every part shard 'handovers: 0', cross.md with none, no hand-over anywhere -> merges PASS, read back Check 1's way" \
              "H23: a world with no hand-overs and correct zero counts was refused"
arm q_ho_widen "H24: under 'handovers: 0', 'handover' followed by an em dash, en dash, '=', '->', a trailing reason, a parenthesised reason, a '1. ' list prefix (bare and bold), and 'handover-run —' -> each REFUSED as a malformed hand-over" \
               "H24: a hand-over spelling the widened malformed-line pattern names was merged"
arm x_k8 "X1: K=8 -- eight parts and cross-1..6 (one per --cross-groups row) merge, titled 'merged from 14 shards', one body header per group" \
         "X1: a K=8 shard dir with every cross group was not merged as fourteen shards"
arm2 x_lone "X2: ONE cross.md in place of the groups at K>2 is ACCEPTED (BL-811) -- K=8 merges titled 9 shards, the parts then '## Shard: cross' last, a 1, 2 finding owned by it; a partial cross-1..5 set at K=8 REFUSED naming cross-6" \
          "X2: the lone cross shard at K>2 was refused, mis-merged, or a partial cross-<g> set was merged"
arm2 x_mix "X3: cross.md beside cross-1..3 -> REFUSED as a mix, nothing at --out" "X3: cross.md and cross-<g>.md merged together"
arm x_unknown "X4: cross-4 at K=3, and cross-1.md in place of cross.md at K=2 -> each REFUSED as a group --cross-groups does not print" \
              "X4: a cross shard naming a group the table does not print was merged"
arm x_owner "X5: K=8, a finding citing 1, 2 in cross-3 AND in its owner cross-1 -> REFUSED naming the owner; 1, 2, 7 in cross-3 alone merges, count +1; the same finding in cross-1 merges and the finding count rises by one" \
            "X5: a cross finding reported by a group that does not own it was merged, or its owner's copy was refused"
arm x_actable "X6: --gate qa, the per-AC table in cross-2 and the deferred record in cross-3 -> each REFUSED, only cross-1 writes them" \
              "X6: a per-AC table or deferred record outside cross-1 was merged"
arm x_horun "X7: --gate qa, part 2's hand-over replayed by cross-2 rather than cross-1 -> REFUSED, only cross-1 runs a replay" \
            "X7: a hand-over replayed by a cross group other than the execution owner was merged"
arm x_k2 "X8: K=2 -- cross.md merges under both gates, titled 'merged from 3 shards', its body header '## Shard: cross'" \
         "X8: a K=2 shard dir with its one cross.md did not merge as before"
arm x_seat "X9: one shard without 'seat-complete:' beside shards with it, a marker that is not the last non-blank line, and findings=3 over 1 finding -> each REFUSED; every shard ending in it (blank lines after) merges, the marker dropped" \
           "X9: an unfinished shard was merged beside finished ones, or finished shards were refused"
arm cr_ho_ok "G1: --gate code-review, parts 1 and 2 each hand over a disjoint replay, cross-1 runs both once -> merges APPROVED with both tabled; AC7 GREEN-SURVIVED merges NEEDS_REWORK" \
             "G1: gate-1 hand-overs owned by two parts and run once each did not merge, or an unmet replay did not force NEEDS_REWORK"
arm cr_ho_block "G2: --gate code-review, every shard BLOCKED and a NO-BASELINE replay -> merges BLOCKED (the forced NEEDS_REWORK never lowers a verdict)" \
                "G2: an unmet replay lowered a BLOCKED review to NEEDS_REWORK"
arm cr_ho_unm "G3: --gate code-review, part 2's hand-over run by no shard -> REFUSED, nothing at --out" \
              "G3: a gate-1 hand-over handed to no replay was merged"
arm cr_ho_runtwice "G4: --gate code-review, one hand-over replayed twice by cross-1 -> REFUSED 'more than one handover-run', nothing at --out" \
                   "G4: a hand-over replayed twice was merged"
arm cr_hc_missing "G5: --gate code-review, a part shard with no 'handovers:' line -> REFUSED, nothing at --out" \
                  "G5: a gate-1 part shard without its declared hand-over count was merged"
# BL-737's CS1 and OT1 sit in THIS unit: OT1 reads the named hand-offs (lib.sh hand_use) that CS1 and the arms above
# saved -- own_miss, own_dup, own_a3, own_qpm_set, own_cr_ho_unm, own_cr_ho_runtwice, x_owner_dup and cs_csc_partcite --
# and a hand-off is read in the run that saved it or FAILS, so the reader and every saver are dealt to one shard.
arm2 cs "CS1: --check-shard prints the full merge's REFUSED line byte-for-byte, the physical path through a symlinked alias, for $CS_N single-defect worlds (every per-shard class under both gates, the marker count, key= and <shard>, and the content seal; qa includes graph's '## Deferred live check (not scored here)' part heading); a clean shard answers SHARD-OK" \
         "CS1: --check-shard's verdict is not the merge's own"
arm2 owner "OT1: every refusal family's owner tail names the shard whose file must change -- per-shard, missing, unfinished, duplicate key (both files), hand-over join (part and cross-1), hand-over twice, replay twice, Check-1 multi-match, bad name and set-level (lead); the owner duplicate names the NON-owner, and --check-shard over the non-owner answers SHARD-OK while its owner is unsealed" \
           "OT1: an owner tail names the wrong shard"
fi # sg arms

if sg bl737; then
# ------------------------------------------------------------------------------------ BL-737
# Each predicate sets WHY to what it saw. A predicate that never ran leaves no `ok` line, so every arm
# here is presence-shaped: the receipt counts these labels' `ok` lines, never the exit alone. arm2
# itself is defined beside arm, above, because X2 and X3 use it too. CS1 and OT1 sit in unit arms (above).
arm2 copies "CP1: has_marker, content_hash, seal_body and seal_of in merge-review-shards.sh, and content-seal.sh's seal_review_body body, are byte-identical to wait-for-deliverable.sh's, extracted by name, and a one-byte drift in either copy is seen" \
             "CP1: the merge's copy of the seal reader is not wait-for-deliverable.sh's"
arm2 key "KY1: a set every seat wrote and --mark closed merges with each marker keyed by its own file name; a marker key= naming another shard, and a <shard> field naming another, each REFUSED [owner: 2]" \
         "KY1: the marker key check accepts a key that is not the file's, or refuses the right one"
arm2 mark "MK1: --mark on a review shard refuses a <shard> that is not the file key, a caller key= and a caller sha= word, and findings=3 over 1 finding -- each exit 64, the file byte-unchanged -- and the same call with the right fields marks it 'key=2'" \
          "MK1: --mark marked a review shard it should have refused, or refused the right call"
arm2 seal_rewrite "SE1: a qa part shard its seat wrote and marked reads SEAL-OK; rewritten by an in-place sed rewrite and re-marked, --mark refuses (64) with the re-dispatch remedy, the file unchanged" \
                  "SE1: a Bash-rewritten review shard was re-marked"
arm2 session "SE2: a seat-sealed set merges; after a top-level-session Edit row on shard 2 the merge REFUSES it [owner: 2]; after an agent Edit row it merges again" \
             "SE2: a shard last written by the session was merged, or the agent's re-write refused"
arm2 legacy "LG1: legacy markers over an old engine merge with the exact 'LEGACY: ... reviewed sha <full sha> predates the key= engine' line per shard (a Write then the old Bash append accepted on body_sha); the same Write then a sed rewrite, the sentinel engine at the frozen sha, and an engine in neither layout each REFUSED" \
            "LG1: the legacy rule acquitted what it should refuse, or refused a legitimate legacy shard"
arm2 layouts "LY1: from a linked worktree the seal reader names the MAIN checkout's ledger in a distribution-layout and a consumer-layout tree (never the worktree's own decoy); the recorder fired there writes MAIN's ledger, both readers read SEAL-OK, and a set sealed there merges" \
             "LY1: the review-shard ledger is not the main checkout's from a linked worktree"
arm2 first_ts "FT1: a review-shard row written before a gate part does not move --first-tool-ts; the same row without body_sha does" \
              "FT1: a review-shard row moved --first-tool-ts, or the control did not"
arm2 env "EV1: on a PATH built from tools.decl without jq, a seat-sealed set is REFUSED 'SEAL-UNAVAILABLE' [owner: lead] with no re-dispatch, and --mark exits 64 relaying it with the environment remedy, the file unchanged; the same set with jq added back merges" \
         "EV1: an environment that cannot read the seal was charged to a reviewer, or the jq control did not merge"
arm2 unmarked "UM1: adv-strip.sh's input -- every seat-complete line stripped, one verdict rewritten by sed -- over a sentinel-engine frozen sha with no seal rows is REFUSED 'carries no content-seal row'; the same steps over the old engine merge" \
              "UM1: an unmarked set over the key= engine merged without a seal row, or the old-engine control was refused"

# ------------------------------------------------------------------------------------ BL-740
# VERDICT BACKING. Every refusal is driven through the merge AND --check-shard, the two REFUSED lines
# byte-equal; every pass merges and answers SHARD-OK. Each cell writes its own WHY token.
arm2 vb_cr "VB1: --gate code-review -- NEEDS_REWORK with the empty findings template REFUSED with the stem, NEEDS_REWORK with one Important merges, BLOCKED with one Critical merges, BLOCKED with only a Suggestion REFUSED, APPROVED with a Critical REFUSED, APPROVED with an Important merges; each refusal byte-equal under --check-shard" \
           "VB1: a code-review verdict was not held to its own findings"
arm2 vb_qmode "VB2M: --gate qa over qa.md's three containers -- NEEDS_REWORK backed only by a Suggestions finding REFUSED, the severity mode alone" \
              "VB2M: QA verdict backing stayed count-only over a three-container qa.md"
arm2 vb_qa "VB2: --gate qa over qa.md's three containers -- NEEDS_REWORK with 0 findings REFUSED; with an Important finding merges, no LEGACY line; PASS with a Critical REFUSED, with an Important merges; a finding under no container REFUSED as unclassed; each refusal byte-equal under --check-shard" \
           "VB2: a qa verdict was not held to its own findings' severity"
arm2 vb_qleg "VB2L: --gate qa over a qa.md declaring NO container (a consumer between pull step 3 and the reconcile merge) -- the LEGACY count-only line and an uncontained NEEDS_REWORK finding merge; a qa.md declaring TWO containers REFUSED [owner: lead]; the code-review gate under that root still refuses an unclassed finding" \
             "VB2L: the zero-container fallback is not count-only, or a two-container qa.md was read"
arm2 fr_verdict "FR1: --gate qa, cross-1's per-AC table -- a PASS merge over an AC4 row reading FAIL, and FAIL under a Result column moved to position 3, each REFUSED [owner: cross-1]; FAIL only in Expected/Got, and all-PASS rows, merge PASS; NEEDS_REWORK carried by part 2's finding naming AC4 merges" \
                 "FR1: a QA merge read PASS over a per-AC FAIL row, or refused a row that does not fail"
arm2 fr_orphan "FR2: a FAIL row under a NEEDS_REWORK merge whose AC no '#### ' finding names is REFUSED as an orphan (the table's own mention does not count), a finding naming only AC10 does not name AC1; a finding naming AC1 beside AC10 merges" \
               "FR2: an orphan per-AC FAIL row merged, or the AC id matched as a substring"
arm2 fr_graph "FR4: graph 811ad3d7d story 3.1 qa p2 as two states, frozen over a tree whose INSTALLED qa.md declares no container and judged by today's -- cross-1 PASS with an AC4 FAIL row and the NEEDS_REWORK cross shard carrying only its AC10 finding REFUSED as an orphan FAIL row [owner: cross-1] (not the FAIL-under-PASS rule); with its hand-added uncontained AC4 finding the set merges NEEDS_REWORK with the severity-boundary LEGACY line naming cross-2" \
               "FR4: the graph AC4 orphan was not refused before its finding, or not accepted after it"
arm2 fr_bound "FRB: the severity boundary is read off qa.md AS INSTALLED AT THE FROZEN SHA -- graph's post-F2 set frozen over a container-less installed qa.md merges NEEDS_REWORK with the LEGACY line; frozen over the three-container one REFUSED unclassed [owner: cross-2], no LEGACY line; frozen over a tree installing no qa.md (unreadable) REFUSED the same way" \
               "FR4: the graph AC4 orphan was not refused before its finding, or not accepted after it"
arm2 fr_remedy "FR3: the orphan remedy is satisfiable -- cross-1 filing the AC4 finding under cross-2's own parts set is the owner-duplicate refusal, under a set cross-1 owns it merges, and the owning cross-2 naming AC4 in its own finding merges" \
               "FR3: the orphan FAIL row's remedy cannot be satisfied under the owner rule"
arm2 serial "SR1: --check-serial, gate 3's Check 1 rule and no stricter -- '## Verdict / PASS', 'Verdict: NEEDS_REWORK', 'Verdict: PASS (all ACs)', '## Verdict / PASS.' and two matches both reading PASS answer SERIAL-OK; the heading-then-'Verdict: PASS' union and two different values, 'PASS-pending', APPROVED under --gate qa, a renamed '## Result' code review (0 matches), a PASS over a FAIL or FAILED row (the latter under '### Acceptance criteria'), and FAIL rows named only by 'AC-4.1' or a 'handover:' line each REFUSED [owner: serial]; code-review APPROVED and a backed NEEDS_REWORK FAIL row answer SERIAL-OK" \
             "SR1: --check-serial accepted a malformed serial verdict, or refused a correct one"
fi # sg bl737
if sg canon; then
arm2 canon "CR1: --check-serial --gate qa, a PASS waits for its canonical run -- the run line plus a counted result, a bulleted pair and a '-p no:cacheprovider' near-miss answer SERIAL-OK; no run line, counts only on a RED replay line, -k, a path root and a marker the conventions do not declare, no result line, a NOT FINISHED result and a result with no count each REFUSED [owner: serial]; NEEDS_REWORK with no run SERIAL-OK; 'none, <reason>' over a record-only --range SERIAL-OK, over a range touching a test, a test module under test-results/, a seat-narrowed rework range, and a non-ancestor base, and with no range REFUSED; BL-895 STORY-BIND: a typo or a directory --story, a review-like file created in a record-only range, a listed story whose index is not the review's, a fresh story under the review's index listed under another key, and a review index that is a prefix of the story's (2 for story-2-1-y.md) REFUSED; the listed story whose row exists only at the frozen sha (not HEAD), under a -p2 review name, SERIAL-OK; N/A, TBD and skipped held to the same partition (refused over code); a bare none REFUSED; -m unit accepted with no conventions and declared, a declared path root accepted; a root whose qa.md lacks the sentinel prints LEGACY and accepts" \
           "CR1: --check-serial accepted a PASS with no canonical run, or refused a correct one"
fi # sg canon
if sg wv955; then
arm2 wv955 "WV955: the canonical-run waiver -- 'Canonical run: none, AC3 waives it' over a code range whose story carries the AC3 '## Canonical-run waivers' entry at a lead-written base SERIAL-OK (the lead's --lead-range over a recorded dispatch) and MERGED (the qa merge under the lead's partition record); no entry at either end, and the entry added only inside the range, REFUSED not record-only; the same world over the seat's --range and an unrecorded --lead-range REFUSED naming --record-dispatch, and the unrecorded merge REFUSED naming --record-partition; a waived claim whose --story is another (waived) story REFUSED by STORY-BIND [owner: serial]" \
           "WV955: canon_gate did not honour a base-time waiver over a lead-written base only"
fi # sg wv955
if sg bind956; then
arm2 bind956 "BIND956 (BL-956): STORY-BIND binds the bare review index through the implementation view's row -- 6-qa-validation.md binds story-1-6-a.md when row story-1-6 names it at the frozen sha, as a no-run and as a run claim (SERIAL-OK); a row naming another file, no row and a row keyed story-1-7 each REFUSED at the index on both claims; a second entry keyed story-6 in another directory REFUSED by the one-story loop, and a historic row story-1-6 naming story-q.md REFUSED by the view's history; --story story-1-1-x.md bound by a frozen row the range re-keyed to story-1-6 (story 6 absent or key-only at the base) REFUSED by the history's re-key check, which holds --story's pairs to the index from --base to frozen, so a story the lead re-keyed from story-1-7 before the base binds (SERIAL-OK); stem-names in sprint 3 reads story-3-3 as index 3 and story-3-1-3 as 1-3; receipt-bl956.sh (sprint 3, epic 1) holds its four cells" \
             "BIND956: STORY-BIND did not bind the bare index through the view's row, or bound one it must refuse"
fi # sg bind956
if sg canon_merge; then
arm2 canon_merge "CR2: the qa merge -- four PASS shards carrying the run merge with no LEGACY line; the execution owner's run lines removed REFUSED [owner: cross-1]; the same with a NEEDS_REWORK part merges NEEDS_REWORK; frozen over an installed qa.md with no label, LEGACY and merges; qa.md untracked at the frozen sha and on disk without the label LEGACY, with it held; --range on the merge REFUSED; BL-895: a record-only sharded diff whose execution owner claims none, with a non-story --story, REFUSED naming that owner; with the listed story MERGED" \
                 "CR2: the merge did not hold the execution owner's PASS to its canonical run, or held a legacy set"
fi # sg canon_merge
if sg bl885; then
arm2 story_path "BL-885 STORY PATH: record-only-diff.sh's story-base and paths resolve an absolute story spelled through a symlink, its physical spelling under a link-spelled -C, './' and './/' to the repo-relative story (status: review at the base -> 1; a story-only diff RECORD-ONLY, a diff adding app.py NOT-RECORD-ONLY naming it); /etc/hosts, 'stories/./s.md', 'stories//s.md', 'stories/../stories/s.md' and '' are exit 2 UNEVALUABLE (receipt-bl885.sh, all $SP_CELLS cells)" \
                "BL-885 STORY PATH: record-only-diff.sh resolved a story path wrongly"
arm2 story_frozen "BL-885 STORY FROZEN: record-only-diff.sh's story-base with the third operand <frozen> -- a typo, '<top>/.git/HEAD' and '.git/HEAD' (no file at the base or at the frozen sha), 'stories' (a tree at the base) and 'stories/later' (absent at the base, a tree at the frozen sha) exit 2 UNEVALUABLE; a story created after the base exits 0, one at status: review at the base 1; the two-operand typo keeps the old 0 (receipt-bl885-frozen.sh, all $SF_CELLS cells)" \
                  "BL-885 STORY FROZEN: record-only-diff.sh's story-base read a story that is no file as a gate-1 base, or refused a real one"
arm2 lead_rec "LR1: the lead's partition record (U1l) -- no record: LEGACY-UNRECORDED and MERGED; --record-partition's record read back by the merge MERGED; a record whose sha or base (a seat-moved .manifest) differs REFUSED [owner: lead]; a held era REFUSES a none claim over code in range though the range strips qa.md's sentinel (9a), a legacy era merges LEGACY; a run claim with the wrong --story REFUSED STORY-BIND on the merge and --check-serial, the right one accepted" \
              "LR1: the merge did not decide from the lead's partition record, or a run claim's --story went unbound"
# BL-790: THE ADVISOR LINE, per shard under both gates and through --check-serial, its absence keyed on
# the gate's role file AT THE FROZEN SHA (lead worlds a and b; the untracked fallback refuses).
AD_ARM="the sentinel world: absent REFUSED [owner: 1] naming the role file that prescribes it, called, unavailable and 'unavailable' with trailing blanks and CR merge with no LEGACY line, maybe, two lines, '- advisor: called' (naming the remediator near-miss) and '**advisor:** called' REFUSED; a fenced 'advisor: maybe' above the bare line, and graph's prose 'Advisor: ...' line beside it, merge; a role file at the frozen sha without the sentinel accepts the absence, and that prose line alone, with the LEGACY line by value and still refuses maybe; a role file unreadable at the sha REFUSED; world (a), frozen over the old role file with the new one on disk, LEGACY and merges; world (b), frozen over the new one with the old on disk, REFUSED; untracked at the sha with the new copy on disk REFUSED naming the on-disk fallback and the commit remedy, with the old copy on disk LEGACY naming it"
arm2 adv_qa "AD1: --gate qa -- $AD_ARM" "AD1: the qa merge did not hold the advisor line to its era"
arm2 adv_cr "AD2: --gate code-review -- $AD_ARM" "AD2: the code-review merge did not hold the advisor line to its era"
arm2 lead "LR1: the lead's re-run (--check-serial --lead-range <seat base> <go-signal sha>, its base the dispatch record --record-dispatch wrote) -- the writer prints RECORDED, keeps the first value on a second call (RECORD-KEPT) and its record reads back SERIAL-OK; the real world SERIAL-OK with no LEGACY line; no record SERIAL-OK with exactly one LEGACY-UNRECORDED line; a go-signal not descending from the recorded dispatch sha (a3's orphan pair), a pre-prescription seat base beside the record, a missing reviewed-sha line with the live sprint ref rewound to a pre-prescription commit, a reviewed-sha naming another sha, and a qa.md whose reviewed-sha prescription is stripped inside the range each REFUSED [owner: serial]; a dispatch sha whose qa.md prescribes neither line SERIAL-OK with the LEGACY reviewed-sha line; the review repository's working-tree qa.md edited to drop the canonical-run label never LEGACY and REFUSED; s1x, s1.Ab12, foo/s1, a symlink spelled s2 onto s1 and a relative path REFUSED by the physical slot; the seat's own run under docs/reviews/s1x/ REFUSED as carrying no sprint; a letter-led index (B1) RECORDED by --record-dispatch and read back SERIAL-OK by the lead's re-run, a slug index (5-browser-smoke) RECORDED, and s1-a/b, s1-.. and s1--x REFUSED with no record written" \
           "LR1: the lead's re-run accepted a review bound to a range, path or qa.md the lead did not choose, or refused the real one"
# LR0 (BL-906): the shared LR_D record. Exactly two subject writes of it over SRCDIR, the second byte-identical to the
# first in record and output, and at least one later cell served from those bytes: a share that never served, or served
# without the proof, fails here rather than reading like a cache that saved nothing.
if [ "$LR_REC_N" = 2 ] && [ "$LR_REC_PROOF" = 1 ] && [ "$LR_REC_HITS" -ge 1 ]; then
  ok "LR0: the lead cells' LR_D record is written by the subject twice, byte-identical, and served to $LR_REC_HITS later SRCDIR cells from those bytes"
else bad "LR0: the shared LR_D record read writes=$LR_REC_N proof=$LR_REC_PROOF served=$LR_REC_HITS, want 2, 1 and at least 1"; fi
arm2 adv_serial "AD3: --check-serial under both gates, over the installed role file carrying the sentinel -- absent, maybe, two lines and '- advisor: called' REFUSED [owner: serial], called, unavailable, a trailing CR and a fenced 'advisor: maybe' above the bare line SERIAL-OK; over a root whose role files lack it, absent SERIAL-OK with the LEGACY line by value" \
                 "AD3: --check-serial did not hold the advisor line to the installed role file's era"
# SR2 (BL-742 role text): qa.md's and code-reviewer.md's serial passages each name the --check-serial
# call; offenders with the step removed from either file are refused.
grep -vF -- "$SR_ROLE_CMD <validation file> --gate qa" "$QA_MD" > "$WORK/sr-qa-nostep.md"
grep -vF -- "$SR_ROLE_CMD <review file> --gate code-review" "$ROLE_MD" > "$WORK/sr-cr-nostep.md"
if cmp -s "$QA_MD" "$WORK/sr-qa-nostep.md" || cmp -s "$ROLE_MD" "$WORK/sr-cr-nostep.md"; then
  bad "SR2: FIXTURE STALE -- a serial-step offender's edit matched nothing, so the predicate would score the shipped text"
elif ! p_serial_role "$QA_MD" "$ROLE_MD"; then
  bad "SR2: qa.md or code-reviewer.md does not tell its serial seat to run --check-serial before returning"
elif p_serial_role "$WORK/sr-qa-nostep.md" "$ROLE_MD" || p_serial_role "$QA_MD" "$WORK/sr-cr-nostep.md"; then
  bad "SR2: FIXTURE BROKEN -- the serial-step predicate passed a role file with the step removed"
else
  ok "SR2: qa.md and code-reviewer.md each tell the serial seat to run merge-review-shards.sh --check-serial before returning; with the step removed from either, refused"
fi
arm2 qclass "QC1: --gate qa, the Class line lifted from qa.md -- a part shard's 'Class: FOO' REFUSED byte-equal under --check-shard naming qa.md's set, 'Class: EVIDENCE' merges and is SHARD-OK, and over a qa.md declaring no Class template the FOO shard merges and is SHARD-OK (nothing checked)" \
             "QC1: the qa merge did not hold the Class line to qa.md's template, or checked one with no template"
fi # sg bl885
if sg story_hist; then
arm2 story_hist "BL-904 STORY HISTORY: record-only-diff.sh's story-base refuses (1, 'existed before') a base where the story was \`git rm\`'d and later re-added, under both operand forms and behind a merge whose first-parent side never held it (plain rev-list hides that deletion); a story never in the base's history exits 0 under both forms, one at status: review at the base 1, a shallow repository exits 2, and a deleted-and-re-added story asked with -C a subdirectory refuses as from the top (receipt-bl904.sh, all \$SH_CELLS cells)" \
                "BL-904 STORY HISTORY: record-only-diff.sh's story-base read a deleted-and-re-added story as created after the base, or refused one that never existed"
fi # sg story_hist
if sg run_rec; then
arm2 run_rec "RR1 (BL-905): the canonical run is bound to a recorded run -- in a held era (qa.md at the base prescribes --record-run) a typed run and result with no record REFUSED [owner: cross], the same pair over a qa.md without the sentinel MERGED with one LEGACY line; --record-run's RECORDED-RESULT copied verbatim MERGED; a recorded run behind a Canonical run: naming another invocation REFUSED naming both, a recorded invocation RUN-FILTER narrows REFUSED; a verbose run cut off at a per-test progress line records nothing, pytest's session line is the summary over a later log line carrying a count, quiet output's own count line is the summary; this pass's run at another sha over code REFUSED, an earlier pass's run at the frozen sha MERGED with no --story, one at a sha whose change since is record-only MERGED, one whose change since touches code REFUSED naming the predicate's line; --record-run with the frozen worktree at another HEAD refused recording nothing, a runner exiting 1 after a summary recorded with exit 1, no summary refused recording nothing; a none claim needs no record;  serial --record-run with the worktree at another sha than --frozen refused recording nothing; the lead's --lead-range over a run recorded at another sha than the go-signal REFUSED; the lead's --lead-range over a base whose tracked qa.md lacks the sentinel SERIAL-OK with one LEGACY line though the installed qa.md carries it; a recorded run whose argv carries a quoted multi-word marker the conventions declare canonical recorded as the one shell line the Canonical run: copies, and MERGED, its bare-word twin MERGED; the lead's --lead-range over a base whose tracked qa.md lacks the canonical-run label SERIAL-OK with one canonical LEGACY line though the installed qa.md carries it, the seat's own form over the same file REFUSED" \
             "RR1: a canonical result was accepted with no run recorded at the frozen sha, or a recorded one refused"
arm2 wrap "WR1 (BL-988): a conventions-declared wrapper is one canonical-run language for record and check -- RUN-FILTER passes the declared stub wrapper with its declared options and a declared payload and RUN-SHAPE reads it as a run; an undeclared wrapper, a relative evil/ spelling of the declared one, no conventions file and a conventions file declaring no wrapper each read exactly as at base; a positional before the bare --, --adm, the prefix --pyth of --python, --admit-only and --prelude (also beside an option value ending in pytest) are refused naming the token, a filtered pytest run ahead of a wrapper run on one line keeps its refusal, an undeclared payload sub-path, -m slow and -k refused as pytest's own arguments; --prelude beside a count is still a run (RUN-SHAPE only widens); git checkout -- <file> and npm test -- --watch declare nothing; a quoted '--junitxml=x>y' is no shell operator, so the test file after it is refused, plain and in a wrapper payload; the conventions span an earlier draft looped on reads a run under a CPU and wall kill switch; --record-run records the declared wrapper (its stub's sentinel present) and --check-serial over its RECORDED-RUN copy reads SERIAL-OK with no LEGACY line, the same record behind a tampered Canonical result: count REFUSED; an undeclared wrapper and a run RUN-FILTER refuses are each REFUSED before anything runs, the sentinel absent and nothing recorded, while a program only RUN-SHAPE refuses is recorded as at base (the pre-check is RUN-FILTER alone, run_bind's own check); BL-988's receipt passes" \
          "WR1: a declared wrapper was refused, an undeclared or narrowed one accepted, the base reading moved without a declaration, the declaration read did not end, or --record-run ran or recorded what its check half refuses"
fi # sg run_rec
if sg files; then
arm2 files "FL1: the Files: line -- a CODE finding naming two paths tracked at the frozen sha is SHARD-OK; Files: on an EVIDENCE finding, two Files: lines, an empty list, a backticked entry, a ':line' entry and a path tracked nowhere are each REFUSED by --check-shard naming the line; a path the range deleted is SHARD-OK (fl-del)" \
           "FL1: --check-shard did not hold the Files: line to its grammar"
fi # sg files
if sg bl808; then
arm2 vb_r3 "VB3: graph s319 3.1's cross-1 shape (qa NEEDS_REWORK, its ## Findings saying the gap is another group's) REFUSED byte-equal under --check-shard, naming the set 'shard-verdict: PASS' exit first, then the file-here exit, and [owner: cross-1]" \
           "VB3: the cross-1 refusal does not name both exits and its owner"
arm2 vb_mark "VB4: --mark findings=0 on an empty NEEDS_REWORK code-review shard exits 64 relaying the stem, the file byte-unchanged; the same file with one Important finding re-written marks findings=1 key=2" \
             "VB4: --mark marked an unbacked NEEDS_REWORK, or refused the backed one"
# BL-763: every owner-duplicate refusal in one run, and --check-shard exits 2 on one (--mark keys on it).
arm2 x_dupall "X10: K=3 -- duplicates in cross-2 and cross-3 print two REFUSED lines (tails cross-2, cross-3), one prints one, an owner's own repeat merges, --check-shard over a duplicate exits 2 with no SHARD-OK, a duplicate then a later per-shard refusal print both (the duplicate first), an earlier per-shard refusal stands alone, and one shard's duplicate then its own verdict-backing refusal print two lines naming it; nothing written" \
              "X10: a merge did not name every owner duplicate in one run, or --check-shard passed a duplicate"
# BL-808: cited captures leave the threshold COUNT, never the file set (partition-review-diff.sh
# --exclude-captures). XC1 is the discriminating seed: a capture-heavy diff that stays sharded, so the
# merge's flagless re-derivation must reproduce the flagged map.
arm2 xc_merge "XC1: $((DFLT + 2)) code files and 10 captures partitioned WITH --exclude-captures into a shard dir (no exclude key in its manifest) merge end to end: the merge's flagless re-derivation reproduces the recorded map" \
              "XC1: a capture-heavy flagged partition did not merge through the flagless re-derivation"
arm2 xc_flip "XC2: $((DFLT - 1)) code files and 10 captures partition without the flag; with it -> exit 3, 'SERIAL: $((DFLT - 1)) reviewable file(s) (... 10 cited capture(s) not counted), below the threshold of $DFLT', no shard dir written" \
             "XC2: the flag did not flip a capture-heavy diff to SERIAL cleanly"
arm2 xc_count "XC3: the excluded count is the INTERSECTION -- a list of 13 lines (cap10 only as CRLF, an out-of-diff path, a scan-root path, a duplicate) prints '10 cited capture(s) not counted'; the same ten spelled './' print 0, in the same arm" \
              "XC3: the excluded count is not the list's intersection with the counted files"
arm2 xc_one "XC4: one code file and five captures under --min-files 1 partition without the flag and answer SERIAL 'a review of at most one counted file is never sharded' with it; two code files under the same flag still shard" \
            "XC4: a one-counted-file review was sharded, or a two-file one was not"
arm2 xc_missing "XC5: --exclude-captures naming a file that does not exist -> REFUSED exit 2, nothing on stdout, no manifest" \
                "XC5: an unreadable capture list was not refused"
fi # sg bl808
if sg gmaint; then
# A git with no `maintenance` subcommand (before 2.29) cannot spawn the child GM1 counts, so the arm stands down with a
# DISTINCT ok line claiming no spawn count; gm_vacuous exits 2 (FIXTURE BROKEN) when the git is 2.29 or later.
if ! gm_has_maint; then
gm_vacuous
ok "GM1 VACUOUS on git $GM_GITV: this git predates git maintenance (2.29), so no commit can spawn the child GM1 counts; no spawn was read and the arm asserts nothing here"
else
arm2 gmaint "GM1 (BL-868, BL-980): a commit through lib.sh's G spawns 0 'git maintenance run' children (trace2 child_start), so no detached repack races a later cp -R of the repository; the same commit through raw git spawns 1 (the control), and receipt-bl980.sh answers BL980 OK: every receipt-*.sh in this directory whose arm runs only in a dist-only shard (the line above names them), run as lib.sh runs it, commits and spawns 0 across its whole run, and every other one is metered at its shipped-shard call site (metered=), whose arm fails on a spawn" \
            "GM1: a commit through G or a receipt spawns auto-maintenance, or the arm cannot tell"
fi
fi # sg gmaint


echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
