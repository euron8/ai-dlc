#!/usr/bin/env bash
# BL-906 receipt (structural; no timing, no fixture run). Usage: bash receipt-bl906.sh [<review-shard-merge run.sh>]
# The pole was split into two shards (review-shard-merge, and review-shard-merge-b which execs it with --group b). This
# drives the fixture's own `--deal` mode, which runs the coverage join (J0) and prints each shard's deal without
# sourcing lib.sh or building a world, and asserts four binary attributes:
#   (1) J0 holds: --deal exits 0 and prints its `[J0] coverage join:` line (units dealt disjointly, union exact,
#       every arm inside a unit, every mutant dealt with its predicate's arm);
#   (2) kill-set identity: the union of the mutant ids the two shards are dealt, each id dealt once, equals the set of
#       `# MUTANT-MATRIX <id> decides=` rows in the same run.sh less the hand-scored ids (HAND, which have no mut_run
#       call), and contains every mutant_killed name at the base afea572a5, read off that revision's mut_run calls
#       (the emission site) with a stub -- so no pre-split mutant is lost and no recorded row goes undealt;
#   (3) each shard's dealt unit-cell count is below CEIL, the same-method count of the unsharded fixture at e311bf7e4;
#   (4) KS1, the per-shard kill-set arm, refuses and accepts: its verdict function ks1_judge and its join
#       rsm_partition_ok are extracted from the run.sh and run on a kill set one id short of its deal (must print
#       KS1's FAIL naming that id) and on one equal to it (must print ok), and the kill set is still collected at the
#       mutant_killed call. The receipt does not run the shards: that is the suite's pole. KS1-CTL in each shard run
#       asserts the same refusal over that run's real kill set, and that KS1 ran; a guard that skips KS1 (K1) is
#       caught there, not here.
# Exit 0 when all hold, 1 when one does not, 2 when an input is absent or the base cannot be read.
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
R="${1:-$HERE/run.sh}"
[ -f "$R" ] || { echo "receipt-bl906: $R absent" >&2; exit 2; }
CEIL=379
HAND="M73 K1 K2 K3"
fail=0; say() { echo "receipt-bl906: $*"; fail=1; }
stub_ids() { # <run.sh text on stdin> -> each mut_run id, one per line
  local calls
  calls="$(awk '/^[[:space:]]*(CS_ONLY=[^ ]+[[:space:]]+)?mut_run [A-Za-z]/ { p = 1 } p { print; if ($0 !~ /\\$/) p = 0 }')"
  [ -n "$calls" ] || return 1
  ( mut_run() { printf '%s\n' "$1"; }; eval "$calls" )
}
BASE=afea572a5
base_ids="$(git show "${BASE}:core/fixtures/review-shard-merge/run.sh" 2> /dev/null | stub_ids | sort)" \
  || { echo "receipt-bl906: the base mut_run calls at $BASE could not be read" >&2; exit 2; }
nbase="$(printf '%s\n' "$base_ids" | grep -c .)" || nbase=0
[ "$nbase" -gt 0 ] || { echo "receipt-bl906: no mutant id read at $BASE" >&2; exit 2; }
rows="$(sed -n 's/^# MUTANT-MATRIX \([^ ]*\) decides=.*/\1/p' "$R" | grep -vxF "$(printf '%s\n' $HAND)" | sort)"
nrows="$(printf '%s\n' "$rows" | grep -c .)" || nrows=0
[ "$nrows" -gt 0 ] || { echo "receipt-bl906: no MUTANT-MATRIX row read from $R" >&2; exit 2; }
deal="$(bash "$R" --deal 2>&1)"; drc=$?
[ "$drc" = 0 ] || say "(1) --deal exited $drc: $(printf '%s\n' "$deal" | grep -m1 'FIXTURE' || printf '%s\n' "$deal" | tail -1)"
grep -q '^  \[J0\] coverage join: .* union exact; ' <<< "$deal" || say "(1) no J0 coverage-join line"
shards="$(sed -n 's/^DEAL \([a-z]\) .*/\1/p' <<< "$deal")"
nsh="$(printf '%s\n' "$shards" | grep -c .)" || nsh=0
[ "$nsh" -ge 2 ] || say "(3) --deal named $nsh shard(s), want at least 2"
dealt="$(sed -n 's/^DEAL [a-z] .* ids=\([^ ]*\)$/\1/p' <<< "$deal" | tr ',' '\n' | grep . | sort)"
ndup="$(printf '%s\n' "$dealt" | uniq -d | grep -c .)" || ndup=0
[ "$ndup" = 0 ] || say "(2) $ndup mutant id(s) dealt to more than one shard"
lost="$(comm -23 <(printf '%s\n' "$rows") <(printf '%s\n' "$dealt" | sort -u) | tr '\n' ' ')"
new="$(comm -13 <(printf '%s\n' "$rows") <(printf '%s\n' "$dealt" | sort -u) | tr '\n' ' ')"
[ -z "$lost$new" ] || say "(2) the dealt union differs from the $nrows MUTANT-MATRIX rows less {$HAND}: dealt to no shard {${lost% }}, dealt with no row {${new% }}"
blost="$(comm -23 <(printf '%s\n' "$base_ids") <(printf '%s\n' "$dealt" | sort -u) | tr '\n' ' ')"
[ -z "$blost" ] || say "(2) kill names at $BASE dealt to no shard: {${blost% }}"
for s in $shards; do
  c="$(sed -n "s/^DEAL $s .* cells=\\([0-9][0-9]*\\) .*/\\1/p" <<< "$deal")"
  if [ -z "$c" ] || [ "$c" -le 0 ] || [ "$c" -ge "$CEIL" ]; then say "(3) shard $s deals ${c:-no} unit cells, want 0 < cells < $CEIL"; fi
done
# (4) behavioural: KS1's own verdict function and its join, extracted from $R and run, never re-implemented.
ks_src="$(awk '/^rsm_partition_ok\(\) \{/ { p = 1 } p { print } p && /^\}$/ { p = 0 }
  /^  ks1_judge\(\) \{/ { q = 1 } q { print } q && /^  \}$/ { q = 0 }' "$R")"
ks_run() { # <dealt ids> <scored ids, one per line> -> KS1's verdict line(s)
  ( w="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl906-ks.XXXXXX")" || exit 3
    ok() { printf 'OK %s\n' "$1"; }; bad() { printf 'BAD %s\n' "$1"; }
    KS1_N=0; WORK="$w"; MUT_MINE=" $1 "; MUT_MINE_N="$(printf '%s\n' $1 | grep -c .)"; MUT_SCORED="$2"
    eval "$ks_src" 2> /dev/null && ks1_judge; r=$?
    rm -f "$w/ks-dealt" "$w/ks-scored"; rmdir "$w"; exit "$r" )
}
case "$ks_src" in *"rsm_partition_ok() {"*"ks1_judge() {"*) ;; *) say "(4) KS1's ks1_judge or rsm_partition_ok was not found in $R" ;; esac
nl=$'\n'
ks_short="$(ks_run "Ka Kb Kc" "Ka${nl}Kb${nl}")"
case "$ks_short" in "BAD KS1: "*"dealt twice: {} dealt to no shard: {Kc} dealt but not declared: {}") ;;
  *) say "(4) KS1 did not refuse a kill set short of its deal by one id (Kc); it printed: ${ks_short:-nothing}" ;; esac
ks_equal="$(ks_run "Ka Kb Kc" "Kc${nl}Ka${nl}Kb${nl}")"
case "$ks_equal" in "OK KS1: "*) ;; *) say "(4) KS1 did not accept a kill set equal to its deal; it printed: ${ks_equal:-nothing}" ;; esac
grep -q 'mutant_killed "${B_rsm_ctl:-0}" "$id" .* && MUT_SCORED="$MUT_SCORED$id' "$R" || say "(4) KS1's kill set is not collected at the mutant_killed call"
[ "$fail" = 0 ] && echo "receipt-bl906: J0 holds, the $nsh shards deal the $nrows MUTANT-MATRIX rows (less $HAND) exactly once each, the $nbase kill names at $BASE among them, each shard below $CEIL unit cells, KS1 refuses a kill set one id short and accepts an equal one"
exit "$fail"
