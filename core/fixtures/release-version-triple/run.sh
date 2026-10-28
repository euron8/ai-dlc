#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# release-version-triple — assert the commit subject, VERSION and the CHANGELOG's
# top heading are joined, and that a disagreement between them fails.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# Three things name a release and nothing joined them. v0.124.1 was committed with
# the subject `fix(v0.124.1):` while VERSION still read `0.124.0` and CHANGELOG.md
# had no 0.124.1 heading. pre-push ran six gates and none of them read a version;
# it was found only because the author re-read the commit afterwards.
#
# check-version.sh does not cover this: it compares an INSTALLED consumer's stamp
# against the distribution's VERSION -- a different join, in the other direction,
# silent about the CHANGELOG and about the commit that made the claim.
#
# This fixture builds a THROWAWAY repository rather than asserting against this
# one's history. Asserting against real commits would make the fixture a snapshot
# of whatever the log happens to contain, and it would rot on the next release.


# MUTANT-MATRIX subject-compare decides=assertion-2,assertion-7b twins=assertion-5
# MUTANT-MATRIX unanchored-fallback decides=assertion-7c twins=assertion-7a
# MUTANT-MATRIX range-threshold decides=assertion-9,assertion-10 twins=assertion-8
# MUTANT-MATRIX branch-base-threshold decides=assertion-13 twins=assertion-15
# MUTANT-MATRIX pair-anchor decides=assertion-20 twins=assertion-2
# MUTANT-MATRIX drop-dollar decides=assertion-22 twins=assertion-2
# MUTANT-MATRIX m-no-removal decides=R1 twins=R2
# MUTANT-MATRIX m-exempt-all decides=R4 twins=R2
# MUTANT-MATRIX m-exempt-none decides=R3 twins=R2
# MUTANT-MATRIX m-search-tip decides=R5 twins=R2
# MUTANT-MATRIX-REMEASURE bash core/fixtures/release-version-triple/run.sh --matrix

set -uo pipefail

# --matrix replays every mutant against every assertion and prints the grid; a plain run replays
# each mutant on its deciding assertion and ONE named twin. The mode is printed either way.
MODE=PUSH
[ "${1:-}" = "--matrix" ] && MODE=FULL

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

# This validator is DISTRIBUTION tooling, not shipped to consumers -- it governs
# ai-dlc's own release discipline, and a consumer writes no ai-dlc CHANGELOG entry.
# So it lives in scripts/ beside validate-enforcement-map.sh, and unlike the
# core/scripts/ validators it has exactly one home to look in.
VALIDATOR="$ROOT/scripts/validate-release-version.sh"
if [ ! -f "$VALIDATOR" ]; then
  echo "FIXTURE SKIP: validate-release-version.sh not present (consumer install)" >&2
  echo "release-version-triple: PASS (skipped -- distribution-only validator)"
  exit 0
fi
echo "HERMETIC-CONSUMED scripts/validate-release-version.sh"

command -v git >/dev/null 2>&1 || { echo "FIXTURE ERROR: git not on PATH" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
made=0
ok()  { printf '  ok    %s\n' "$1"; made=$((made+1)); }
bad() { printf '  FAIL  %s\n' "$1"; made=$((made+1)); fails=$((fails+1)); }

# EXPECTED_ASSERTIONS is not bookkeeping. A sibling fixture lost an entire mutant
# when a helper call was mis-spaced: `set -u` killed the `$( )` subshell, the `if`
# read that as a false branch, and the arm never ran -- seventeen green lines and a
# PASS. Every assertion below reaches the validator through `$( )`, so the same
# shape is available here. A failed assertion is loud; one that never executed is
# not, and this is what tells them apart.
EXPECTED_ASSERTIONS=39

cd "$WORK" || exit 2
git init -q . 2>/dev/null || { echo "FIXTURE ERROR: git init failed" >&2; exit 2; }
git config user.email f@example.com
git config user.name Fixture
git config commit.gpgsign false

# commit <version> <changelog-version> <subject> -- PREPENDS the heading and keeps
# every one below it. It once rewrote CHANGELOG.md to a single heading, which made
# every commit here REPLACE the previous release's heading in place -- the exact
# shape arm C's removal check now refuses -- so assertions meant for predicates A
# and B would have read red for a range reason.
commit() {
  printf '%s' "$1" > VERSION
  if [ -f CHANGELOG.md ]; then
    { printf '# Changelog\n\n## [%s] — 2026-01-01\n\n- entry\n' "$2"
      tail -n +2 CHANGELOG.md; } > CHANGELOG.next
    mv CHANGELOG.next CHANGELOG.md
  else
    printf '# Changelog\n\n## [%s] — 2026-01-01\n\n- entry\n' "$2" > CHANGELOG.md
  fi
  git add -A
  git commit -q -m "$3" 2>/dev/null
}

# drive_src <validator-file> <outfile> [args...] -> the validator's own exit status, output in <outfile>.
# SOURCES the file in a subshell and calls the SAME functions its main body calls, in its order,
# minus arm_e and arm_f: those two self-probes each build a scratch repository, the bulk of the
# cost, and no drive through here asks about them. Assertion 1 executes the whole program, and
# assertion 22 drives the F mutant that way, so both arms are still proved to fire. An `exit` in an
# arm ends this subshell with the arm's status, exactly as it ends the script. A sourced copy that
# defines no arm_ab (an older validator) is refused rather than scored as a pass.
drive_src() {
  local v="$1" out="$2"; shift 2
  (
    # shellcheck disable=SC1090
    . "$v" || exit 97
    command -v arm_ab >/dev/null 2>&1 || exit 98
    rv_init "$@"; arm_c_range; arm_c; arm_d; arm_ab; rv_report
  ) >"$out" 2>&1
}

# --- THE CHECK REGISTRY AND THE MUTANT x ASSERTION MATRIX -----------------------------------
# reg <name> <kind> <want-exit> <pattern|-|!pattern> <validator args...> snapshots the repository
# the assertion just read (cwd) and records what it demands of the validator, so any validator
# file -- the shipped one or a mutant -- can be replayed against that same input later. kind: src
# (sourced drive, arms E/F skipped), exec (the whole program executed), pair (assertion 20's
# grammar binding; no repository). A pattern beginning `!` must NOT appear in the output.
# `bash core/fixtures/release-version-triple/run.sh --matrix` (from the repo root; an argument, so
# no env switch that hermetic-run's env -i could drop) replays EVERY mutant against EVERY check and prints
# one `MATRIX <mutant> <check> dead|green` line per cell; per push each mutant is replayed on its
# deciding input and one twin only (see the MUTANT-MATRIX header).
SNAP="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
SNAP="$(cd "$SNAP" && pwd)"
trap 'rm -rf "$WORK" "$SNAP"' EXIT
CK_N=0; CK_NAME=(); CK_KIND=(); CK_WANT=(); CK_PAT=(); CK_ARGS=(); CK_DIR=()
MX_N=0; MX_NAME=(); MX_FILE=(); MX_CELLS=0; TWIN_EVALS=0
reg() {
  local n="$CK_N"
  CK_NAME[$n]="$1"; CK_KIND[$n]="$2"; CK_WANT[$n]="$3"; CK_PAT[$n]="$4"; shift 4
  CK_ARGS[$n]="$*"; CK_DIR[$n]="$SNAP/$n"
  mkdir -p "$SNAP/$n" || exit 2
  if [ "${CK_KIND[$n]}" != pair ]; then cp -R "$PWD/." "$SNAP/$n/" || exit 2; fi
  CK_N=$((n+1))
}
regmut() { MX_NAME[$MX_N]="$1"; MX_FILE[$MX_N]="$2"; MX_N=$((MX_N+1)); }
ck_index() {
  local j=0
  while [ "$j" -lt "$CK_N" ]; do
    if [ "${CK_NAME[$j]}" = "$1" ]; then echo "$j"; return 0; fi
    j=$((j+1))
  done
  return 1
}
eval_check() { # <check index> <validator file> -> 0 when the check holds under that file
  local i="$1" v="$2" st pat out="$SNAP/eval.out"
  case "${CK_KIND[$i]}" in
    pair) pair_ok "$ENGINE" "$v"; return $? ;;
    src)  ( cd "${CK_DIR[$i]}" && drive_src "$v" "$out" ${CK_ARGS[$i]} ); st=$? ;;
    exec) ( cd "${CK_DIR[$i]}" && bash "$v" ${CK_ARGS[$i]} >"$out" 2>&1 ); st=$? ;;
    *) return 2 ;;
  esac
  [ "$st" = "${CK_WANT[$i]}" ] || return 1
  pat="${CK_PAT[$i]}"
  case "$pat" in
    -)   return 0 ;;
    '!'*) if grep -q -- "${pat#!}" "$out"; then return 1; fi; return 0 ;;
    *)   grep -q -- "$pat" "$out" ;;
  esac
}
twin_ok() { # <validator file> <check name> -> 0 when that check still holds under it
  local i
  i="$(ck_index "$2")" || { echo "FIXTURE ERROR: no registered check named $2" >&2; exit 2; }
  TWIN_EVALS=$((TWIN_EVALS+1))
  eval_check "$i" "$1"
}
matrix_run() {
  local r i f nm dead line hm dec tw d t rowi mxfail=0
  local rows_n=$((MX_N+1))
  DEAD=()
  r=0
  while [ "$r" -lt "$rows_n" ]; do
    if [ "$r" = 0 ]; then nm=ORIG; f="$VALIDATOR"; else nm="${MX_NAME[$((r-1))]}"; f="${MX_FILE[$((r-1))]}"; fi
    dead=""; i=0
    while [ "$i" -lt "$CK_N" ]; do
      MX_CELLS=$((MX_CELLS+1))
      if eval_check "$i" "$f"; then echo "MATRIX $nm ${CK_NAME[$i]} green"
      else echo "MATRIX $nm ${CK_NAME[$i]} kill"; dead="$dead ${CK_NAME[$i]}"; fi
      i=$((i+1))
    done
    DEAD[$r]="$dead"
    echo "MATRIX-KILLS $nm by:${dead:- (none)}"
    r=$((r+1))
  done
  [ -z "${DEAD[0]}" ] || { echo "MATRIX-FAIL the unmutated control (ORIG) has dead checks:${DEAD[0]}"; mxfail=1; }
  rowi=0
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    set -- $line
    [ "$#" -ge 5 ] || continue
    hm="$3"; dec="${4#decides=}"; tw="${5#twins=}"
    r=0; i=-1
    while [ "$r" -lt "$MX_N" ]; do [ "${MX_NAME[$r]}" = "$hm" ] && i=$((r+1)); r=$((r+1)); done
    if [ "$i" -lt 0 ]; then echo "MATRIX-FAIL header names mutant $hm, which the fixture never built"; mxfail=1; continue; fi
    rowi=$((rowi+1))
    for d in $(echo "$dec" | tr ',' ' '); do
      case " ${DEAD[$i]} " in *" $d "*) ;; *) echo "MATRIX-FAIL $hm: deciding check $d is GREEN, the mutant is not dead by it"; mxfail=1 ;; esac
    done
    for t in $(echo "$tw" | tr ',' ' '); do
      case " ${DEAD[$i]} " in *" $t "*) echo "MATRIX-FAIL $hm: twin $t is DEAD, a twin must stay green"; mxfail=1 ;; esac
    done
  done <<EOF_HDR
$(grep '^# MUTANT-MATRIX [^ ]' "$HERE/run.sh")
EOF_HDR
  [ "$rowi" = "$MX_N" ] || { echo "MATRIX-FAIL the header names $rowi mutants, the fixture built $MX_N"; mxfail=1; }
  if [ "$mxfail" = 0 ]; then echo "MATRIX-OK $MX_N mutants x $CK_N checks, every decides dead and every twin green"; fi
  return "$mxfail"
}

run() { # run <rev-or-range-flag> <value>
  drive_src "$VALIDATOR" "$WORK/out.txt" "$1" "$2"
  echo "$?"
}

echo "release-version-triple"

# --- 1. All three agreeing passes ---------------------------------------------
commit 0.1.0 0.1.0 'feat(v0.1.0): the first one'
# The ONE full-program drive of a passing input: the whole validator EXECUTED, so arms E and F run
# their probes and the summary names both as fired. Every other drive goes through drive_src.
bash "$VALIDATOR" --commit HEAD >"$WORK/out.txt" 2>&1; status=$?
if [ "$status" = "0" ] \
   && grep -q 'no committed conflict markers (probe fired both ways)' "$WORK/out.txt" \
   && grep -q 'no misspelled not-discharged citation (probe fired both ways)' "$WORK/out.txt"; then
  ok "subject, VERSION and CHANGELOG all agreeing passes, with arms E and F evaluated end to end"
else
  bad "an agreeing commit failed -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi
reg assertion-1 exec 0 'no misspelled not-discharged citation (probe fired both ways)' --commit HEAD

# --- 2. THE REAL DEFECT: subject ahead of VERSION ------------------------------
# v0.124.1 exactly: the subject announces a version the tree does not carry.
commit 0.1.0 0.1.0 'fix(v0.1.1): the resident path carried the incident'
status="$(run --commit HEAD)"
if [ "$status" = "1" ] && grep -q 'subject says v0.1.1, VERSION says 0.1.0' "$WORK/out.txt"; then
  ok "a subject naming a version VERSION does not carry fails, and both values are named"
else
  bad "the real defect was not caught -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi
reg assertion-2 src 1 'subject says v0.1.1, VERSION says 0.1.0' --commit HEAD
# The ONE executed run of a FAILING input. Every other failing drive is sourced (drive_src), which
# bypasses the BASH_SOURCE main guard; this one executes the program, so a guard that never calls
# rv_main would exit 0 and print nothing here and this arm would go red.
bash "$VALIDATOR" --commit HEAD >"$WORK/exec-fail.txt" 2>&1; exec_fail_status=$?
if [ "$exec_fail_status" = "1" ] && grep -q 'subject says v0.1.1, VERSION says 0.1.0' "$WORK/exec-fail.txt"; then
  ok "EXECUTED (not sourced) on a failing input the validator exits 1 and names both versions, so the main guard is wired"
else
  bad "the executed validator did not fail assertion 2's input -- exit $exec_fail_status; the BASH_SOURCE main guard may not call rv_main"
  sed 's/^/        /' "$WORK/exec-fail.txt"
fi

# --- 3. VERSION ahead of the CHANGELOG ----------------------------------------
# The other half of the same failure: bumped, announced, changelog never written.
commit 0.2.0 0.1.0 'feat(v0.2.0): bumped without a changelog entry'
status="$(run --commit HEAD)"
if [ "$status" = "1" ] && grep -q "CHANGELOG's top heading says 0.1.0" "$WORK/out.txt"; then
  ok "a VERSION ahead of the CHANGELOG heading fails"
else
  bad "a stale CHANGELOG heading was not caught -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi
reg assertion-3 src 1 "CHANGELOG's top heading says 0.1.0" --commit HEAD

# --- 4. A CHANGELOG with no heading at all fails -------------------------------
# Distinct from a stale heading: absence must not read as agreement.
printf '0.3.0' > VERSION
printf '# Changelog\n\nnothing here yet\n' > CHANGELOG.md
git add -A && git commit -q -m 'feat(v0.3.0): no heading'
status="$(run --commit HEAD)"
if [ "$status" = "1" ] && grep -q "no '## \[X.Y.Z\]' heading" "$WORK/out.txt"; then
  ok "a CHANGELOG with no version heading fails rather than passing vacuously"
else
  bad "a missing heading did not fail -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi
reg assertion-4 src 1 "no '## \[X.Y.Z\]' heading" --commit HEAD

# --- 5. A subject with NO version token is not a failure -----------------------
# Measured on the real repo: 14 of the last 30 bumps predate the convention. A
# check that is wrong about a third of the history it is pointed at gets turned
# off, and takes the working predicates with it. This assertion pins the rejected
# third predicate so it cannot return by accident.
commit 0.4.0 0.4.0 'chore: no version token in this subject'
status="$(run --commit HEAD)"
if [ "$status" = "0" ]; then
  ok "a subject with no version token passes (the rejected predicate stays rejected)"
else
  bad "a tokenless subject failed -- the rejected predicate came back"; sed 's/^/        /' "$WORK/out.txt"
fi
reg assertion-5 src 0 - --commit HEAD

# --- 6. MERGES ARE SKIPPED OVER A RANGE ----------------------------------------
# A merge's VERSION differs from its first parent by construction and its subject
# carries no token. Without the skip this fires on every merge to main.
git checkout -q -b side
commit 0.5.0 0.5.0 'feat(v0.5.0): on a branch'
git checkout -q -
git merge -q --no-ff -m 'Merge pull request #1 from side' side
# HEAD~1..HEAD, not HEAD~2: the range still spans the merge AND the side commit it
# brings in, and its base is assertion 5's commit. HEAD~2 is assertion 4's
# headingless commit, so with a cumulative changelog that range adds 0.4.0 and
# 0.5.0 and arm C would fire for a reason this assertion is not about.
status="$(run --range "HEAD~1..HEAD")"
if [ "$status" = "0" ]; then
  ok "a merge commit in the range is skipped, not indicted"
else
  bad "a merge fired -- the check would block every merge to main"; sed 's/^/        /' "$WORK/out.txt"
fi
reg assertion-6a src 0 - --range HEAD~1..HEAD
# And the commit the merge BROUGHT IN is still checked on its own, or the skip is
# a hole rather than a scope.
git checkout -q -b side2
commit 0.6.0 0.5.0 'feat(v0.6.0): bad commit behind a merge'
git checkout -q -
git merge -q --no-ff -m 'Merge pull request #2 from side2' side2
status="$(run --range "HEAD~2..HEAD")"
if [ "$status" = "1" ]; then
  ok "  and a bad commit behind a merge is still caught"
else
  bad "  a bad commit hid behind a merge -- the skip is a hole"; sed 's/^/        /' "$WORK/out.txt"
fi
reg assertion-6b src 1 - --range HEAD~2..HEAD

# --- 7. THE MUTATION TEST — prove assertion 2's red is predicate A's -----------
# Neuter the subject comparison on a COPY and demand assertion 2's input go green.
MUTANT="$WORK/mutant.sh"
sed 's/\[ "\$subj_ver" != "\$version" \]/false/' "$VALIDATOR" > "$MUTANT" || exit 2
if cmp -s "$VALIDATOR" "$MUTANT"; then
  echo "FIXTURE ERROR: mutation matched nothing -- predicate A was rewritten" >&2
  echo "  update the sed pattern in assertion 7 to match the real comparison" >&2
  exit 2
fi
commit 0.7.0 0.7.0 'fix(v0.7.1): subject ahead again'
drive_src "$MUTANT" "$WORK/mut.txt" --commit HEAD
mutant_status=$?
if [ "$mutant_status" = "0" ]; then
  ok "MUTATION: disabling the subject comparison makes assertion 2's input go green"
else
  bad "MUTATION: assertion 2's input still fails (exit $mutant_status) without predicate A"
  sed 's/^/        /' "$WORK/mut.txt"
fi
regmut subject-compare "$MUTANT"

# --- 7a-7d. THE BARE LEADING FORM IS A CLAIM ------------------------------------
# Release subjects in this repo read `0.754.0 — ...`, with no `v`. Under a v-only
# grammar predicate A bound none of them, so it could not fire on a current release.
# Every input above is `feat(vX.Y.Z)`, which is why nothing here noticed.
commit 0.8.0 0.8.0 '0.8.0 — agreeing'
status="$(run --commit HEAD)"
if [ "$status" = "0" ]; then
  ok "a bare leading version agreeing with VERSION passes"
else
  bad "a bare agreeing subject failed -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi
reg assertion-7a src 0 - --commit HEAD

commit 0.9.0 0.9.0 '0.9.1 — ahead'
status="$(run --commit HEAD)"
if [ "$status" = "1" ] && grep -q 'subject says v0.9.1, VERSION says 0.9.0' "$WORK/out.txt"; then
  ok "a bare leading version ahead of VERSION fails, and both values are named"
else
  bad "a bare leading version ahead of VERSION was not caught -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi
reg assertion-7b src 1 'subject says v0.9.1, VERSION says 0.9.0' --commit HEAD

# NEAR-MISS: the same token, mid-subject. A bare version there is a MENTION, not the
# commit's claim about itself, and the fallback is anchored at the start for that reason.
commit 0.9.0 0.9.0 'chore: 0.9.1 mentioned mid-subject'
mid_sha="$(git rev-parse HEAD)"
status="$(run --commit "$mid_sha")"
if [ "$status" = "0" ]; then
  ok "a bare version MID-subject is a mention, not a claim, and passes"
else
  bad "a mid-subject bare version was read as a claim -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi
reg assertion-7c src 0 - --commit "$mid_sha"

# MUTATION: drop the fallback's `^` and demand the near-miss go red. Without this the
# near-miss could pass because the fallback never ran at all.
ANCHOR="grep -oE '^[0-9]+"
n_anchor="$(grep -cF -- "$ANCHOR" "$VALIDATOR")" || n_anchor=0
n_never="$(grep -cF -- "grep -oE '^ZZQ-never-armA" "$VALIDATOR")" || n_never=0
if [ "$n_anchor" != 1 ] || [ "$n_never" != 0 ]; then
  echo "FIXTURE ERROR: the bare-fallback anchor matched $n_anchor time(s) (want 1; impossible control $n_never, want 0)" >&2
  echo "  update the anchor in assertion 7d to match the real fallback" >&2
  exit 2
fi
MUT_A="$WORK/mutant-unanchored.sh"
sed "s/grep -oE '^\\[0-9\\]+/grep -oE '[0-9]+/" "$VALIDATOR" > "$MUT_A" || exit 2
if cmp -s "$VALIDATOR" "$MUT_A"; then
  echo "FIXTURE ERROR: the unanchoring mutation matched nothing" >&2
  exit 2
fi
drive_src "$MUT_A" "$WORK/mut-a.txt" --commit "$mid_sha"
mut_a_status=$?
if [ "$mut_a_status" = "1" ] && grep -q 'subject says v0.9.1, VERSION says 0.9.0' "$WORK/mut-a.txt"; then
  ok "MUTATION: an unanchored fallback reads the mid-subject mention as a claim (the ^ is load-bearing)"
else
  bad "MUTATION: the near-miss still passes (exit $mut_a_status) with the fallback unanchored"
  sed 's/^/        /' "$WORK/mut-a.txt"
fi
regmut unanchored-fallback "$MUT_A"

# --- THE RANGE ARMS ------------------------------------------------------------
#
# THE DEFECT THESE EXIST TO CATCH, and it is a different one from assertions 1-7.
# A release branch was cut from a local `main` fourteen commits ahead of
# `origin/main`. The PR took `origin/main` as its merge-base and the squash carried
# three releases under one `feat(v0.217.0):` subject. The triple reported
# `PASS 15 commit(s)` on the branch and `PASS 1 commit(s)` on the squash -- BOTH
# PASS, because the commits that could have disagreed are precisely the ones the
# squash removed. So these assertions must show a red that the triple cannot
# produce, on an input the triple calls green.
#
# A SECOND SANDBOX, deliberately. The repository above is shaped for the triple --
# a headingless commit, merges, repeated headings -- and its history is not a
# release sequence. A clean cumulative changelog is what the arm is pointed at.
W2="$WORK/cumulative"
mkdir -p "$W2" && cd "$W2" || exit 2
git init -q . 2>/dev/null || { echo "FIXTURE ERROR: git init failed in W2" >&2; exit 2; }
git config user.email f@example.com
git config user.name Fixture
git config commit.gpgsign false

# release <version> <subject> -- PREPENDS a heading, the way a real CHANGELOG grows.
# VERSION always matches the newest heading, so the triple stays green throughout
# and every red below is attributable to a range arm.
release() {
  printf '%s' "$1" > VERSION
  if [ -f CHANGELOG.md ]; then
    { printf '# Changelog\n\n## [%s] — 2026-01-01\n\n- entry\n' "$1"
      tail -n +2 CHANGELOG.md; } > CHANGELOG.next
    mv CHANGELOG.next CHANGELOG.md
  else
    printf '# Changelog\n\n## [%s] — 2026-01-01\n\n- entry\n' "$1" > CHANGELOG.md
  fi
  git add -A
  git commit -q -m "$2" 2>/dev/null
}

release 0.1.0 'feat(v0.1.0): the first one'
base_sha="$(git rev-parse HEAD)"
release 0.2.0 'feat(v0.2.0): one release, on its own branch'
one_sha="$(git rev-parse HEAD)"

# --- 8. One release in a range is silent ---------------------------------------
status="$(run --range "$base_sha..$one_sha")"
if [ "$status" = "0" ]; then
  ok "a range adding ONE release heading passes -- the arm can be quiet"
else
  bad "a single-release range failed -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi
reg assertion-8 src 0 - --range "$base_sha..$one_sha"

# --- 9. Two releases in a range fail, and both are named -----------------------
release 0.3.0 'feat(v0.3.0): a second release on the same branch'
two_sha="$(git rev-parse HEAD)"
status="$(run --range "$base_sha..$two_sha")"
if [ "$status" = "1" ] \
   && grep -q 'adds 2 release headings' "$WORK/out.txt" \
   && grep -qF '0.2.0' "$WORK/out.txt" && grep -qF '0.3.0' "$WORK/out.txt"; then
  ok "a range adding TWO release headings fails, and names both versions"
else
  bad "a two-release range was not caught -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi
reg assertion-9 src 1 'adds 2 release headings' --range "$base_sha..$two_sha"

# --- 10. THE SQUASH ITSELF: one commit, two releases, triple in full agreement --
# This is the load-bearing assertion. The commit's subject, VERSION and top
# CHANGELOG heading all name 0.5.0, so predicates A and B are satisfied; only the
# range arm can produce a red here. Assertion 11 proves that claim rather than
# asserting it.
git checkout -q -b squashed "$two_sha"
printf '0.5.0' > VERSION
{ printf '# Changelog\n\n## [0.5.0] — 2026-01-01\n\n- entry\n\n## [0.4.0] — 2026-01-01\n\n- entry\n'
  tail -n +2 CHANGELOG.md; } > CHANGELOG.next
mv CHANGELOG.next CHANGELOG.md
git add -A
git commit -q -m 'feat(v0.5.0): two releases squashed into one commit (#1)'
squash_sha="$(git rev-parse HEAD)"
status="$(run --commit "$squash_sha")"
if [ "$status" = "1" ] && grep -q 'adds 2 release headings' "$WORK/out.txt"; then
  ok "a SQUASH carrying two releases fails, though its subject, VERSION and top heading all agree"
else
  bad "the squash shape was not caught -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi
reg assertion-10 src 1 'adds 2 release headings' --commit "$squash_sha"

# --- 11. CONTROL: an unmutated COPY still fails on assertion 10's input ---------
# Assertion 12 flips 10's input to green by editing a copy. That flip only means
# something if an UNEDITED copy, run the same way from the same directory, still
# goes red -- otherwise a copy that cannot execute would score as a kill.
COPY="$WORK/copy.sh"
cp "$VALIDATOR" "$COPY" || exit 2
drive_src "$COPY" "$WORK/copy.txt" --commit "$squash_sha"
copy_status=$?
if [ "$copy_status" = "1" ] && grep -q 'adds 2 release headings' "$WORK/copy.txt"; then
  ok "CONTROL: an unmutated copy of the validator still fails on the same input"
else
  bad "CONTROL: the unmutated copy did not reproduce the red (exit $copy_status) -- assertion 12 would prove nothing"
  sed 's/^/        /' "$WORK/copy.txt"
fi

# --- 12. MUTATION: neuter the range arm's threshold ----------------------------
MUT_C="$WORK/mutant-range.sh"
sed 's/-ge 2 \]; then/-ge 99 ]; then/' "$VALIDATOR" > "$MUT_C" || exit 2
if cmp -s "$VALIDATOR" "$MUT_C"; then
  echo "FIXTURE ERROR: the range-arm mutation matched nothing -- the threshold was rewritten" >&2
  echo "  update the sed pattern in assertion 12 to match the real comparison" >&2
  exit 2
fi
drive_src "$MUT_C" "$WORK/mut2.txt" --commit "$squash_sha"
mut_c_status=$?
if [ "$mut_c_status" = "0" ]; then
  ok "MUTATION: raising the range arm's threshold makes assertion 10's input go green"
else
  bad "MUTATION: assertion 10's input still fails (exit $mut_c_status) without the range arm"
  sed 's/^/        /' "$WORK/mut2.txt"
fi
regmut range-threshold "$MUT_C"

# --- THE BRANCH-BASE ARM -------------------------------------------------------
# The PRECONDITION of the squash above: commits sitting on local main and not on
# origin/main are behind the PR's merge-base, so they ride into it unremarked.
W3="$WORK/branchbase"
mkdir -p "$W3" && cd "$W3" || exit 2
git init -q . 2>/dev/null || { echo "FIXTURE ERROR: git init failed in W3" >&2; exit 2; }
git config user.email f@example.com
git config user.name Fixture
git config commit.gpgsign false
release 0.1.0 'feat(v0.1.0): the first one'
git branch -M main
# origin/main is a real ref, not a real remote -- the arm reads refs, not network.
git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)"
git commit -q --allow-empty -m 'chore: a tick committed to main and never pushed'
ahead_main="$(git rev-parse HEAD)"
git checkout -q -b release/0.2.0
release 0.2.0 'feat(v0.2.0): cut from a main that was ahead'

run0() { drive_src "$VALIDATOR" "$WORK/out.txt"; echo "$?"; }

# --- 13. A branch cut from an ahead main fails ---------------------------------
# Note the range arm stays quiet here: only 0.2.0 is added past origin/main. The
# red is the branch-base arm's alone.
status="$(run0)"
if [ "$status" = "1" ] && grep -q 'carries 1 commit(s) that are on local main and not on origin/main' "$WORK/out.txt"; then
  ok "a branch carrying an unpushed main commit fails, and the count is named"
else
  bad "the ahead-main precondition was not caught -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi
reg assertion-13 src 1 'carries 1 commit(s) that are on local main and not on origin/main'

# --- 14. MUTATION: neuter the branch-base arm ----------------------------------
MUT_D="$WORK/mutant-base.sh"
sed 's/-gt 0 \]; then/-gt 99 ]; then/' "$VALIDATOR" > "$MUT_D" || exit 2
if cmp -s "$VALIDATOR" "$MUT_D"; then
  echo "FIXTURE ERROR: the branch-base mutation matched nothing -- the comparison was rewritten" >&2
  echo "  update the sed pattern in assertion 14 to match the real comparison" >&2
  exit 2
fi
drive_src "$MUT_D" "$WORK/mut3.txt"
mut_d_status=$?
if [ "$mut_d_status" = "0" ]; then
  ok "MUTATION: raising the branch-base arm's threshold makes assertion 13's input go green"
else
  bad "MUTATION: assertion 13's input still fails (exit $mut_d_status) without the branch-base arm"
  sed 's/^/        /' "$WORK/mut3.txt"
fi
regmut branch-base-threshold "$MUT_D"

# --- 15. CONTROL: caught-up origin/main goes silent ----------------------------
# Keyed on the INHERITANCE, not on merely standing on a branch. Same branch, same
# commits, one ref moved.
git update-ref refs/remotes/origin/main "$ahead_main"
status="$(run0)"
if [ "$status" = "0" ]; then
  ok "CONTROL: the same branch passes once origin/main carries those commits"
else
  bad "a clean branch failed -- the arm fires on being on a branch at all"; sed 's/^/        /' "$WORK/out.txt"
fi
reg assertion-15 src 0 -

# --- 16. The remedy is not indicted --------------------------------------------
# Pushing main is HOW unpushed main commits reach origin. An arm that fires on the
# remedy is an arm that gets turned off, so it must be n/a there -- and must SAY
# it is n/a rather than reporting the same green as an evaluated run.
git update-ref refs/remotes/origin/main "$(git rev-parse main~1)"
git checkout -q main
status="$(run0)"
if [ "$status" = "0" ] && grep -q 'branch-base arm n/a on main' "$WORK/out.txt"; then
  ok "on main the branch-base arm is n/a, and the summary says so rather than claiming a green arm"
else
  bad "the arm fired on main, or reported an unevaluated arm as green -- exit $status"
  sed 's/^/        /' "$WORK/out.txt"
fi
reg assertion-16 src 0 'branch-base arm n/a on main'

# --- 17. An arm that CANNOT be evaluated announces itself ----------------------
# A quiet skip reads exactly like a pass. With no origin/main there is nothing to
# compare against, and that has to be visible in the output.
git checkout -q release/0.2.0
git update-ref -d refs/remotes/origin/main
status="$(run0)"
if [ "$status" = "0" ] \
   && grep -q 'branch-base arm not evaluated' "$WORK/out.txt" \
   && grep -q 'BRANCH-BASE ARM NOT EVALUATED' "$WORK/out.txt"; then
  ok "with no origin/main the arm announces it did not run, in the NOTE and in the summary"
else
  bad "an unevaluated arm passed silently -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi
reg assertion-17 src 0 'BRANCH-BASE ARM NOT EVALUATED'

# --- 18. An EMPTY range falls back to HEAD, and the verdict names the substitution
# With no commits of its own, a branch's HEAD is origin/main's tip -- somebody else's
# already-merged release, whose triple agrees by construction. A bare `PASS 1 commit(s)`
# there is a check that cannot fire reading exactly like one that passed, and it reads
# that way at the moment a rehearsal is most likely: before the release commit exists.
git checkout -q release/0.2.0
git update-ref refs/remotes/origin/main "$(git rev-parse HEAD)"
status="$(run0)"
if [ "$status" = "0" ] && grep -q 'range origin/main..HEAD was EMPTY' "$WORK/out.txt"; then
  ok "an empty range names the commit it fell back to instead of reporting a bare pass"
else
  bad "an empty range reported a pass without naming its substituted subject -- exit $status"
  sed 's/^/        /' "$WORK/out.txt"
fi
reg assertion-18 src 0 'range origin/main..HEAD was EMPTY'

# --- 19. CONTROL: the note is not unconditional --------------------------------
# On main the fallback IS the intended subject, and `branch-base arm n/a on main`
# already says where the run is. A note that printed everywhere would be noise, and
# noise is how a real signal stops being read.
git checkout -q main
status="$(run0)"
if [ "$status" = "0" ] && ! grep -q 'was EMPTY' "$WORK/out.txt"; then
  ok "CONTROL: on main the same empty range prints no note (so assertion 18 is not unconditional)"
else
  bad "the empty-range note fired on main, where the fallback is the intended subject -- exit $status"
  sed 's/^/        /' "$WORK/out.txt"
fi
reg assertion-19 src 0 '!was EMPTY'

# --- 20/21. ARM F'S CANONICAL GRAMMAR IS THE ENGINE'S, BYTE FOR BYTE ------------
# The consumer engine's `named_cited_filter` strips a citation line only in its exact
# form; arm F refuses every other spelling. Two copies of one regex in two trees (the
# engine ships, this validator does not), so they are bound here: each file must carry
# EXACTLY ONE `/^Not-discharged: ...$/` literal, and the two must be byte-identical.
# A copy that drifts narrower or wider lets arm F acquit a line the engine reads as an
# ordinary mention -- the false absorption the form exists to prevent.
ENGINE="$ROOT/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"
canon_of() { grep -o '/\^Not-discharged: [^/]*\$/' "$1" 2>/dev/null; }
pair_ok() { # <engine> <validator> -> 0 when each has exactly one literal and they agree
  local a b
  a="$(canon_of "$1")"; b="$(canon_of "$2")"
  [ "$(printf '%s\n' "$a" | grep -c .)" = 1 ] && [ "$(printf '%s\n' "$b" | grep -c .)" = 1 ] && [ "$a" = "$b" ]
}
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"
if [ ! -f "$ENGINE" ]; then
  bad "the engine is absent at $ENGINE, so the grammar pair cannot be compared"
elif pair_ok "$ENGINE" "$VALIDATOR"; then
  ok "arm F's canonical citation regex is byte-identical to the engine's: $(canon_of "$VALIDATOR")"
else
  bad "the citation grammar has forked: engine {$(canon_of "$ENGINE" | tr '\n' ' ')} validator {$(canon_of "$VALIDATOR" | tr '\n' ' ')}"
fi
reg assertion-20 pair 0 -
MUT_P="$WORK/pair-mutant.sh"
sed 's|/^Not-discharged: PC-S\[0-9\]+(-\[A-Za-z0-9_\.-\]+)\*\$/|/^Not-discharged: PC-S[0-9]+(-[A-Za-z0-9_.-]+)*$|' "$VALIDATOR" > "$MUT_P" || exit 2
if cmp -s "$VALIDATOR" "$MUT_P"; then
  bad "the pair mutation matched nothing -- the validator's canonical regex was rewritten"
elif pair_ok "$ENGINE" "$MUT_P"; then
  bad "a validator whose canonical regex lost its closing anchor still reads as paired -- the binding cannot fire"
else
  ok "MUTATION: editing one side of the pair (the validator's closing anchor) breaks the binding"
fi
regmut pair-anchor "$MUT_P"

# --- 22. ARM F'S OWN PROBE REFUSES A CANONICAL REGEX MISSING ITS \$ ----------------
# `Not-discharged: PC-S1-TRAIL (rejected, see BL-9)` is an ORDINARY mention to the engine.
# A validator whose canonical test lost its `$` would acquit it, so the self-probe seeds it
# as an offender, and this mutant must be refused by that probe before any corpus is read.
MUT_D="$WORK/drop-dollar.sh"
sed 's|if (\$0 !~ /^Not-discharged: PC-S\[0-9\]+(-\[A-Za-z0-9_\.-\]+)\*\$/) print|if ($0 !~ /^Not-discharged: PC-S[0-9]+(-[A-Za-z0-9_.-]+)*/) print|' "$VALIDATOR" > "$MUT_D" || exit 2
if cmp -s "$VALIDATOR" "$MUT_D"; then
  bad "the drop-\$ mutation matched nothing -- arm F's canonical test was rewritten"
else
  git checkout -q main
  bash "$MUT_D" --commit HEAD >"$WORK/out.txt" 2>&1; status=$?
  if [ "$status" = 1 ] && grep -q "arm F's own probe did not discriminate" "$WORK/out.txt"; then
    ok "MUTATION: a canonical test missing its \$ is refused by arm F's own probe (the trailing-text offender)"
  else
    bad "the drop-\$ mutant was not refused by arm F's probe -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
  fi
fi
reg assertion-22 exec 0 'no misspelled not-discharged citation (probe fired both ways)' --commit HEAD
regmut drop-dollar "$MUT_D"

# --- R1-R5. ARM C IN BOTH DIRECTIONS: REMOVED HEADINGS, RESTORED HEADINGS --------
#
# TWO DEFECTS A COUNT OF ADDED HEADINGS COULD NOT SEE. 0.806.0 (581ca289) turned
# the previous release's `## [0.805.0]` into `## [0.806.0]` in place: the set
# difference netted to one added heading and the release PASSED, with 0.805.0's
# body left filed under 0.806.0. And the repair of that shape (ed0fa33d restored
# `[0.805.0]`) plus the next release counted two and FAILED. So arm C now refuses
# a removed heading, and sets aside a below-the-base-top heading the base's own
# history already carried.
#
# A FOURTH SANDBOX, each world written out in full by `snap`, so every heading set
# is stated rather than inferred from a prepend history. Every world keeps VERSION
# equal to its top heading and every subject agreeing, so every red is arm C's.
W4="$WORK/headings"
mkdir -p "$W4" && cd "$W4" || exit 2
git init -q . 2>/dev/null || { echo "FIXTURE ERROR: git init failed in W4" >&2; exit 2; }
git config user.email f@example.com
git config user.name Fixture
git config commit.gpgsign false

# snap <version> <subject> <heading versions, top first...>
snap() {
  local v="$1" s="$2" h
  shift 2
  printf '%s' "$v" > VERSION
  { printf '# Changelog\n'
    for h in "$@"; do printf '\n## [%s] — 2026-01-01\n\n- entry\n' "$h"; done; } > CHANGELOG.md
  git add -A
  git commit -q -m "$s" 2>/dev/null
}

snap 0.1.0 '0.1.0 — first' 0.1.0
snap 0.2.0 '0.2.0 — second' 0.2.0 0.1.0
c2_sha="$(git rev-parse HEAD)"
# THE 0.806.0 SHAPE: 0.2.0's heading line becomes 0.3.0's, its body stays.
snap 0.3.0 '0.3.0 — replaces the previous heading in place' 0.3.0 0.1.0
r1_sha="$(git rev-parse HEAD)"
git checkout -q -b r2 "$c2_sha"
snap 0.3.0 '0.3.0 — inserted above, as a release should be' 0.3.0 0.2.0 0.1.0
r2_sha="$(git rev-parse HEAD)"
# THE ed0fa33d SHAPE: 0.2.0 is restored below the base's top, plus one new release.
git checkout -q -b r3 "$r1_sha"
snap 0.4.0 '0.4.0 — restores 0.2.0 and releases' 0.4.0 0.3.0 0.2.0 0.1.0
r3_sha="$(git rev-parse HEAD)"
git checkout -q -b r4 "$r1_sha"
snap 0.5.0 '0.5.0 — two genuinely new releases' 0.5.0 0.4.0 0.3.0 0.1.0
r4_sha="$(git rev-parse HEAD)"
# BELOW THE BASE TOP, NEVER IN HISTORY. Only the base's history decides it; a
# search from the TIP finds this very commit and would exempt it.
git checkout -q -b r5 "$r1_sha"
snap 0.4.0 '0.4.0 — invents a below-top heading' 0.4.0 0.3.0 0.2.5 0.1.0
r5_sha="$(git rev-parse HEAD)"

drive() { # drive <validator> <sha> <outfile> -> exit status
  drive_src "$1" "$3" --commit "$2"
  echo "$?"
}

status="$(drive "$VALIDATOR" "$r1_sha" "$WORK/out.txt")"
if [ "$status" = "1" ] && grep -q 'removes release heading(s) present at its base: 0.2.0' "$WORK/out.txt" \
   && ! grep -q 'adds 2 release headings' "$WORK/out.txt"; then
  ok "R1: a release that replaces the previous heading in place fails, naming the removed heading"
else
  bad "R1: an in-place heading replacement was not caught -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi
reg R1 src 1 'removes release heading(s) present at its base: 0.2.0' --commit "$r1_sha"

status="$(drive "$VALIDATOR" "$r2_sha" "$WORK/out.txt")"
if [ "$status" = "0" ] && grep -q 'no heading removed' "$WORK/out.txt"; then
  ok "R2: a normal insertion above the previous heading passes"
else
  bad "R2: a normal release failed -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi
reg R2 src 0 'no heading removed' --commit "$r2_sha"

status="$(drive "$VALIDATOR" "$r3_sha" "$WORK/out.txt")"
if [ "$status" = "0" ] && grep -q 'NOTE  restored historical heading(s), not counted: 0.2.0' "$WORK/out.txt"; then
  ok "R3: restoring a historical heading plus one new release passes, and the restore is NOTEd"
else
  bad "R3: a restored heading was counted as a release -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi
reg R3 src 0 'NOTE  restored historical heading(s), not counted: 0.2.0' --commit "$r3_sha"

status="$(drive "$VALIDATOR" "$r4_sha" "$WORK/out.txt")"
if [ "$status" = "1" ] && grep -q 'adds 2 release headings' "$WORK/out.txt"; then
  ok "R4: two genuinely new headings above the base top still fail"
else
  bad "R4: two new releases passed -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi
reg R4 src 1 'adds 2 release headings' --commit "$r4_sha"

status="$(drive "$VALIDATOR" "$r5_sha" "$WORK/out.txt")"
if [ "$status" = "1" ] && grep -q 'adds 2 release headings' "$WORK/out.txt" && grep -qF '0.2.5' "$WORK/out.txt"; then
  ok "R5: a below-top heading the base's history never carried counts as new"
else
  bad "R5: an invented below-top heading was exempted -- exit $status"; sed 's/^/        /' "$WORK/out.txt"
fi
reg R5 src 1 '0.2.5' --commit "$r5_sha"

# --- R-control: an UNMUTATED COPY reproduces both directions --------------------
# Positive conjuncts on both sides: the removal FAIL on R1's input AND the NOTE on
# R3's. A copy that cannot run prints neither, so silence cannot score as a kill.
COPY_R="$WORK/copy-r.sh"
cp "$VALIDATOR" "$COPY_R" || exit 2
s1="$(drive "$COPY_R" "$r1_sha" "$WORK/copy-r1.txt")"
s3="$(drive "$COPY_R" "$r3_sha" "$WORK/copy-r3.txt")"
if [ "$s1" = "1" ] && grep -q 'removes release heading(s) present at its base: 0.2.0' "$WORK/copy-r1.txt" \
   && [ "$s3" = "0" ] && grep -q 'NOTE  restored historical heading(s), not counted: 0.2.0' "$WORK/copy-r3.txt"; then
  ok "CONTROL: an unmutated copy reproduces R1's removal FAIL and R3's NOTE"
else
  bad "CONTROL: the unmutated copy did not reproduce R1 (exit $s1) and R3 (exit $s3) -- the mutants below would prove nothing"
  sed 's/^/        /' "$WORK/copy-r1.txt" "$WORK/copy-r3.txt"
fi

# mkmut <out> <literal> <replacement> -- a LITERAL replacement on a copy, refused
# unless the literal occurs exactly once (an impossible literal must count 0 in
# the same run) and the copy differs from the original.
n_never="$(grep -cF -- 'ZZQ-never-armC-literal' "$VALIDATOR")" || n_never=0
if [ "$n_never" != 0 ]; then
  echo "FIXTURE ERROR: the impossible-literal control counted $n_never, want 0" >&2; exit 2
fi
mkmut() {
  local n
  n="$(grep -cF -- "$2" "$VALIDATOR")" || n=0
  if [ "$n" != 1 ]; then
    echo "FIXTURE ERROR: mutation anchor [$2] occurs $n time(s), want 1 -- arm C was rewritten" >&2; exit 2
  fi
  A="$2" B="$3" awk 'BEGIN { a = ENVIRON["A"]; b = ENVIRON["B"] }
    { i = index($0, a); if (i) $0 = substr($0, 1, i - 1) b substr($0, i + length(a)); print }' \
    "$VALIDATOR" > "$1" || exit 2
  if cmp -s "$VALIDATOR" "$1"; then
    echo "FIXTURE ERROR: mutation [$2] did not apply" >&2; exit 2
  fi
}
EXEMPT_IF='if [ -n "$base_top" ] && semver_le "$hv" "$base_top" && [ -n "$(restored_in_history "$h")" ]; then'

mkmut "$WORK/m-no-removal.sh" 'if [ -n "$removed" ]; then' 'if false; then'
status="$(drive "$WORK/m-no-removal.sh" "$r1_sha" "$WORK/mut-r.txt")"
if [ "$status" = "0" ]; then
  ok "MUTATION m-no-removal: without the removal check R1's input goes green"
else
  bad "MUTATION m-no-removal: R1's input still fails (exit $status) without the removal check"; sed 's/^/        /' "$WORK/mut-r.txt"
fi
regmut m-no-removal "$WORK/m-no-removal.sh"

mkmut "$WORK/m-exempt-all.sh" "$EXEMPT_IF" 'if true; then'
status="$(drive "$WORK/m-exempt-all.sh" "$r4_sha" "$WORK/mut-r.txt")"
if [ "$status" = "0" ]; then
  ok "MUTATION m-exempt-all: exempting every added heading makes R4's input go green"
else
  bad "MUTATION m-exempt-all: R4's input still fails (exit $status) with every heading exempt"; sed 's/^/        /' "$WORK/mut-r.txt"
fi
regmut m-exempt-all "$WORK/m-exempt-all.sh"

mkmut "$WORK/m-exempt-none.sh" "$EXEMPT_IF" 'if false; then'
status="$(drive "$WORK/m-exempt-none.sh" "$r3_sha" "$WORK/mut-r.txt")"
if [ "$status" = "1" ] && grep -q 'adds 2 release headings' "$WORK/mut-r.txt"; then
  ok "MUTATION m-exempt-none: without the exemption R3's restore counts as a second release"
else
  bad "MUTATION m-exempt-none: R3's input still passes (exit $status) with no exemption"; sed 's/^/        /' "$WORK/mut-r.txt"
fi
regmut m-exempt-none "$WORK/m-exempt-none.sh"

mkmut "$WORK/m-search-tip.sh" '"$range_base" -- CHANGELOG.md' '"$range_tip" -- CHANGELOG.md'
status="$(drive "$WORK/m-search-tip.sh" "$r5_sha" "$WORK/mut-r.txt")"
if [ "$status" = "0" ] && grep -q 'not counted: 0.2.5' "$WORK/mut-r.txt"; then
  ok "MUTATION m-search-tip: searching from the tip exempts R5's invented heading (the base is load-bearing)"
else
  bad "MUTATION m-search-tip: R5's input still fails (exit $status) with the search from the tip"; sed 's/^/        /' "$WORK/mut-r.txt"
fi
regmut m-search-tip "$WORK/m-search-tip.sh"

# --- PER-PUSH TWINS, OR THE FULL MATRIX --------------------------------------------------------
# The assertions above drive each mutant on its deciding input. Each mutant's one named TWIN (the
# --matrix every mutant is replayed against every check instead and the grid is printed. The
# mode (FULL or PUSH) is printed either way, so a "matrix" log that is really the push run is visible.
echo "release-version-triple mode: $MODE"
if [ "$MODE" = FULL ]; then
  mx_rc=0; matrix_run || mx_rc=$?
  if [ "$mx_rc" = 0 ] && [ "$MX_CELLS" = $(( (MX_N + 1) * CK_N )) ]; then
    ok "MATRIX (--matrix): every mutant replayed against every assertion ($MX_CELLS cells), every decides caught, every twin green"
  else
    bad "MATRIX (--matrix): the grid disagrees with the MUTANT-MATRIX header (rc $mx_rc, $MX_CELLS cells)"
  fi
else
  tw_bad=""; n_hdr=0
  while IFS= read -r hdr; do
    [ -n "$hdr" ] || continue
    set -- $hdr
    [ "$#" -ge 5 ] || continue
    n_hdr=$((n_hdr+1))
    hm="$3"; htw="${5#twins=}"; hf=""; hj=0
    while [ "$hj" -lt "$MX_N" ]; do [ "${MX_NAME[$hj]}" = "$hm" ] && hf="${MX_FILE[$hj]}"; hj=$((hj+1)); done
    [ -n "$hf" ] || { tw_bad="$tw_bad [$hm never built]"; continue; }
    for ht in $(echo "$htw" | tr ',' ' '); do
      twin_ok "$hf" "$ht" || tw_bad="$tw_bad [twin $ht red under $hm]"
    done
  done <<EOF_TW
$(grep '^# MUTANT-MATRIX [^ ]' "$HERE/run.sh")
EOF_TW
  if [ -z "$tw_bad" ] && [ "$MX_CELLS" = 0 ] && [ "$n_hdr" = "$MX_N" ] && [ "$TWIN_EVALS" -ge "$n_hdr" ]; then
    ok "PUSH: no matrix-only cell ran ($MX_CELLS), and each of the $n_hdr mutants was replayed on its one named twin ($TWIN_EVALS)"
  else
    bad "PUSH: matrix cells ran in a plain run ($MX_CELLS), or a twin went red, or the header and the fixture disagree:$tw_bad (header $n_hdr, built $MX_N)"
  fi
fi

echo ""
if [ "$made" -ne "$EXPECTED_ASSERTIONS" ]; then
  echo "release-version-triple: FAIL — $made assertions ran, $EXPECTED_ASSERTIONS were written. An arm did not execute at all, which is not the same as an arm that passed. Find the one that vanished before reading anything above as green."
  exit 1
fi
if [ "$fails" -eq 0 ]; then
  echo "release-version-triple: PASS ($made assertions)"
  exit 0
fi
echo "release-version-triple: FAIL ($fails of $made assertion(s))"
exit 1
