#!/usr/bin/env bash
# receipt-bl981.sh -- the BL-981 receipt, both subjects. Each is a git-process cost that grows with its
# population, counted from GIT_TRACE2_EVENT `"event":"start"` records, never read off the source text.
#
#   rv  scripts/validate-release-version.sh `arm_ab` pays git starts PER COMMIT in the range. The
#       validator is SOURCED (its main runs only when executed) in a scratch repository of agreeing
#       release commits, `rv_init --range` resolves the list, and only `arm_ab` is traced, over the last
#       1 and the last 3 commits. PASS when the two runs differ by at most 4 starts, that is at most 2
#       per commit: the two `git show` blob reads of VERSION and CHANGELOG.md at that commit, which
#       BL-981 does not owe. At base `rev-parse --short` and `log -1` added 2 more per commit, so the cost was 4 per commit (4 and 12 over 1 and 3 commits); at the tip it reads 3 and 7.
#       Keyed on the TOTAL per-commit start count, so a swap of one per-commit call for another reads FAIL.
#   em  scripts/validate-enforcement-map.sh I14 pays one `git ls-files -s` per registered hook and one
#       per bare-path file. Driven as `--arms I14` against this tree. PASS when that run makes at most 2
#       git starts in all, of any command. At base it made one per registered tracked hook plus 2 (27 with 25 hooks); at the tip it makes 1.
#       AND I14 must still SEE a mode: the start count alone passes a rewrite that never errs (a mode that
#       parses empty skips every hook as untracked, at 1 start). So a second `--arms I14` run reads a COPY of
#       the index (GIT_INDEX_FILE, which reaches the validator's `git -C "$REPO_ROOT" ls-files`; the index is
#       found by `rev-parse --git-path index`, so a linked worktree's works) in which the registered tracked
#       hook in the MIDDLE of the sort order is `update-index --chmod=-x`; the run must print exactly one
#       `COMMITTED 100644` line, a `FAIL: hook '<that hook>' ...` line, and the unseeded run, the control,
#       none. Both outputs are read from captured files. The start count is taken on the unseeded run only.
#
# Exit 0 when both cells pass, 1 when one fails, 9 when it cannot measure: no root, a trace that recorded
# nothing, a scratch repository that did not build, an arm_ab pass that did not check exactly the commits
# asked for, an I14 run that never reached its verdict line, a tree with fewer than 3 registered tracked
# hooks (where the per-hook shape could not exceed the em bound, so a pass would prove nothing), or a mode
# probe that could not run (no index to copy, a seed that did not land at 100644, or an unseeded run that
# already reports a 0644 hook and so leaves the probe no clean control).
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
# An inherited git environment would point the scratch repository's writes at the caller's store.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_TRACE2_EVENT GIT_TRACE2 GIT_TRACE2_PERF

HERE="$(cd "$(dirname "$0")" && pwd)"
root=""; d="$HERE"
while [ -n "$d" ] && [ "$d" != "/" ]; do
  if [ -f "$d/scripts/validate-release-version.sh" ] && [ -f "$d/scripts/validate-enforcement-map.sh" ]; then root="$d"; break; fi
  d="$(dirname "$d")"
done
[ -n "$root" ] || { echo "receipt-bl981: cannot locate the repo root from $HERE" >&2; exit 9; }
RV="$root/scripts/validate-release-version.sh"
EM="$root/scripts/validate-enforcement-map.sh"
grep -q '^arm_ab()' "$RV" || { echo "receipt-bl981: $RV defines no arm_ab" >&2; exit 9; }
grep -q '^rv_init()' "$RV" || { echo "receipt-bl981: $RV defines no rv_init" >&2; exit 9; }

W="$(mktemp -d)" || exit 9
trap 'rm -rf "$W"' EXIT
starts() { local n; n="$(grep -c '"event":"start"' "$1")" || n=0; echo "$n"; }
fail=0

# --- rv: per-commit git starts of arm_ab ---------------------------------------------------------------
G="$W/rv"
git init -q "$G" >/dev/null 2>&1 || { echo "receipt-bl981: scratch repository did not initialise" >&2; exit 9; }
for i in 1 2 3 4; do
  printf '0.1.%s\n' "$i" > "$G/VERSION"
  printf '# Changelog\n\n## [0.1.%s] - x\n' "$i" > "$G/CHANGELOG.md"
  git -C "$G" add VERSION CHANGELOG.md >/dev/null 2>&1 \
    && git -C "$G" -c user.name=r -c user.email=r@r -c commit.gpgsign=false -c core.hooksPath=/dev/null \
         commit -q -m "0.1.$i — r" >/dev/null 2>&1 \
    || { echo "receipt-bl981: scratch commit $i failed" >&2; exit 9; }
done
rv_cost() { # <N> -> arm_ab's git starts over HEAD~N..HEAD; 9 when the pass did not check N agreeing commits
  local ev="$W/rv$1.ev" out="$W/rv$1.out"
  : > "$ev"
  ( cd "$G" || exit 9
    . "$RV"
    rv_init --range "HEAD~$1..HEAD"
    export GIT_TRACE2_EVENT="$ev"
    arm_ab
    unset GIT_TRACE2_EVENT
    echo "CHECKED $checked FAILS $fails" ) < /dev/null > "$out" 2>&1
  grep -qx "CHECKED $1 FAILS 0" "$out" || { echo "receipt-bl981: arm_ab over $1 commit(s) did not check $1 agreeing commits: $(tail -1 "$out")" >&2; return 9; }
  starts "$ev"
}
c1="$(rv_cost 1)" || exit 9
c3="$(rv_cost 3)" || exit 9
[ "$c1" -ge 1 ] || { echo "receipt-bl981: the trace recorded no git start for arm_ab over 1 commit" >&2; exit 9; }
grow=$((c3 - c1))
if [ "$grow" -le 4 ]; then
  echo "CELL rv PASS arm_ab git starts: $c1 over 1 commit, $c3 over 3 ($grow for 2 more commits, bound 4)"
else
  echo "CELL rv FAIL arm_ab git starts: $c1 over 1 commit, $c3 over 3 ($grow for 2 more commits, bound 4): per-commit reads remain"
  fail=1
fi

# --- em: git starts of the I14 unit ---------------------------------------------------------------------
TEMPLATE="$root/templates/settings.json.template"
[ -f "$TEMPLATE" ] || { echo "receipt-bl981: no $TEMPLATE" >&2; exit 9; }
reg=0 regl=""
while IFS= read -r p; do
  [ -n "$p" ] || continue
  if grep -q "${p##*/}" "$TEMPLATE"; then reg=$((reg + 1)); regl="$regl$p
"; fi
done <<<"$(git -C "$root" ls-files -- 'core/hooks/ai-dlc-*.sh' 2>/dev/null)"
# The mode probe's hook sits in the MIDDLE of the sort order, never first or last.
probe="$(printf '%s' "$regl" | sed -n "$(( (reg + 1) / 2 ))p")"
[ "$reg" -ge 3 ] || { echo "receipt-bl981: only $reg registered tracked hook(s); the per-hook shape cannot exceed the bound here" >&2; exit 9; }
: > "$W/em.ev"
( cd "$root" && GIT_TRACE2_EVENT="$W/em.ev" FXCELL="${R981_TAG:+$R981_TAG-em}" bash "$EM" --arms I14 ) < /dev/null > "$W/em.so" 2> "$W/em.se"; em_rc=$?
cat "$W/em.so" "$W/em.se" > "$W/em.out"
case "$em_rc" in 0|1) ;; *) echo "receipt-bl981: --arms I14 exited $em_rc" >&2; exit 9 ;; esac
grep -qE '^(OK|FAIL): ' "$W/em.out" || { echo "receipt-bl981: the --arms I14 run never reached its verdict line" >&2; exit 9; }
e="$(starts "$W/em.ev")"
# The mode probe: the same run over an index copy with one registered hook seeded 0644.
pb="${probe##*/}"
ctl="$(grep -c 'COMMITTED 100644' "$W/em.out")" || ctl=0
[ "$ctl" = 0 ] || { echo "receipt-bl981: the unseeded --arms I14 run already reports $ctl COMMITTED 100644 line(s), so the mode probe has no clean control" >&2; exit 9; }
idx="$(git -C "$root" rev-parse --path-format=absolute --git-path index 2>/dev/null)" && [ -f "$idx" ] \
  || { echo "receipt-bl981: cannot locate the index of $root" >&2; exit 9; }
cp "$idx" "$W/em.index" && GIT_INDEX_FILE="$W/em.index" git -C "$root" update-index --chmod=-x "$probe" \
  || { echo "receipt-bl981: could not seed $probe at 100644 in an index copy" >&2; exit 9; }
case "$(GIT_INDEX_FILE="$W/em.index" git -C "$root" ls-files -s -- "$probe")" in
  "100644 "*) ;; *) echo "receipt-bl981: the seeded index copy does not carry $probe at 100644" >&2; exit 9 ;;
esac
( cd "$root" && GIT_INDEX_FILE="$W/em.index" FXCELL="${R981_TAG:+$R981_TAG-emp}" bash "$EM" --arms I14 ) < /dev/null > "$W/emp.so" 2> "$W/emp.se"; emp_rc=$?
cat "$W/emp.so" "$W/emp.se" > "$W/emp.out"
case "$emp_rc" in 0|1) ;; *) echo "receipt-bl981: the seeded --arms I14 run exited $emp_rc" >&2; exit 9 ;; esac
grep -qE '^(OK|FAIL): ' "$W/emp.out" || { echo "receipt-bl981: the seeded --arms I14 run never reached its verdict line" >&2; exit 9; }
hit="$(grep -cF "FAIL: hook '$pb' is registered in templates/settings.json.template but is COMMITTED 100644" "$W/emp.out")" || hit=0
all="$(grep -c 'COMMITTED 100644' "$W/emp.out")" || all=0
if [ "$e" -le 2 ] && [ "$hit" = 1 ] && [ "$all" = 1 ]; then
  echo "CELL em PASS --arms I14 git starts: $e with $reg registered tracked hooks (bound 2); $pb seeded 0644 named by $hit of $all COMMITTED 100644 line(s), unseeded 0"
else
  echo "CELL em FAIL --arms I14 git starts: $e with $reg registered tracked hooks (bound 2); $pb seeded 0644 named by $hit of $all COMMITTED 100644 line(s) (want 1 of 1), unseeded 0"
  fail=1
fi

# THE EQUIVALENCE CELLS of the two cli starts above (R981_EQUIV=1, set by run.sh's live run only; the tag prefix is
# R981_TAG, and with it unset FXCELL is empty, an untagged start): each world runs again IN PROCESS, the validator
# sourced by absolute path in a subshell and run as `vem_entry --arms I14`, and must answer byte for byte as the
# started program did: stdout, stderr, exit, and on the unseeded world the git start count. GIT_TRACE2_EVENT and
# GIT_INDEX_FILE are EXPORTED there, because vem_entry unsets every unexported caller variable. A failed source exits
# 97, never the validator's own code. One `EQUIV <cell> same|DIFF` line each; no CELL line moves.
if [ "${R981_EQUIV:-}" = 1 ]; then
  ok() { :; }; bad() { :; }
  . "$HERE/../lib/mutant.sh" || { echo "receipt-bl981: cannot source lib/mutant.sh beside $HERE" >&2; exit 9; }
  for ql in em emp; do
    if [ "$ql" = em ]; then qr="$em_rc" qx=""; else qr="$emp_rc" qx="$W/em.index"; fi
    : > "$W/$ql.iev"
    fx_inproc "$EM"
    ( cd "$root" || exit 97; export GIT_TRACE2_EVENT="$W/$ql.iev"; [ -z "$qx" ] || export GIT_INDEX_FILE="$qx"
      . "$EM" || exit 97; vem_entry --arms I14 ) < /dev/null > "$W/$ql.iso" 2> "$W/$ql.ise"; q_rc=$?
    q_d=""
    cmp -s "$W/$ql.so" "$W/$ql.iso" || q_d="$q_d stdout"
    cmp -s "$W/$ql.se" "$W/$ql.ise" || q_d="$q_d stderr"
    [ "$qr" = "$q_rc" ] || q_d="$q_d exit=$qr/$q_rc"
    if [ "$ql" = em ] && [ "$(starts "$W/em.ev")" != "$(starts "$W/em.iev")" ]; then q_d="$q_d git-starts=$(starts "$W/em.ev")/$(starts "$W/em.iev")"; fi
    if [ -z "$q_d" ]; then echo "EQUIV ${R981_TAG:-}-$ql same exit $qr"; else echo "EQUIV ${R981_TAG:-}-$ql DIFF$q_d"; fi
  done
fi

exit "$fail"
