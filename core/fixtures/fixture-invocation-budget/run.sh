#!/usr/bin/env bash
# fixture-invocation-budget -- drive the REAL scripts/validate-fixture-invocations.sh through the REAL
# core/scripts/hermetic-run.sh against a probe project, armed and unarmed, and score three committed mutants.
#
# THE SUBJECT is the invocation budget end to end: hermetic-run.sh's three-variable gate, its BASH_ENV/FXCOUNT_LOG
# passthrough into the sandboxed fixture, its judge call before the verdict-store write, and the judge's arms.
# Nothing here re-implements a judge rule: every verdict below is the shipping judge's, read off the runner's output.
#
# THE PROBE. One project, one fixture `probe` whose run.sh starts `bash core/scripts/sub.sh` twice (3 starts with
# run.sh itself) and reports one mutant name, Mx, through the real core/fixtures/lib/mutant.sh. Four worlds, each
# built once: ok (declared 3 / 2, header rows Mx), mis (declared 2 / 2), nohdr (declared right, no Mx row), nodecl.
# THE ARMS, each one drive of the runner into a fresh counter dir and a fresh verdict store:
#   A1  ok, armed       -> rc 0, `invocation budget ok: 3 start(s)`, verdict recorded
#   A2  mis, armed      -> rc 1, the J3 row naming measured 3 and declared 2, NO store entry (control: rc=1 line)
#   A3  mis, unarmed    -> rc 0, verdict recorded, no judge line, no counter log created (ALLOW twin of A2)
#   A4  nohdr, armed    -> rc 1, J5 naming Mx
#   A5  nodecl, armed   -> rc 1, J2 printing `3 *` and `2 core/scripts/sub.sh`
#   A6  mis, two of the three arming variables -> inert exactly as A3
#   SP  the judge's --self-probe standalone -> rc 0, all cells green
#   NM  a plain run executes no matrix-only cell (control: the per-push mutant drives ran)
# THE MUTANTS are copies of the whole subject tree (judge, runner, its core-paths.sh, mutant.sh), one line changed,
# guarded by cmp -s and an exactly-one-match rewrite. Per push each runs its deciding arm and one twin; the full
# mutant x arm matrix is `--matrix`, measured from a real run and recorded here:
# MUTANT-MATRIX MJ3 decides=A2,SP twins=A3
# MUTANT-MATRIX MGATE decides=A1,A2,A4,A5 twins=A3
# MUTANT-MATRIX MPASS decides=A1,A2,A4,A5 twins=A3
# MUTANT-MATRIX-REMEASURE bash core/fixtures/fixture-invocation-budget/run.sh --matrix
# Re-measure it whenever an arm or a mutant is added or changed. The matrix also shows A1, A4, A5 and A6 green under
# MJ3, and A6 and SP green under MGATE and MPASS; only A3 is named as the twin, because only A3 runs per push. Per
# push: MJ3 runs SP with twin A3 (the per-fixture judge no longer repeats the self-probe, so only the J3 cells and the
# A2 mismatch see it); MGATE runs A2 with twin A3; MPASS runs A1 with twin A3.
#   MJ3    the judge's J3 compare removed            -> SP names the J3 off-by-one cell
#   MGATE  the runner's judge call disabled           -> A2 records a pass for a mismatching fixture
#   MPASS  the runner's BASH_ENV passthrough dropped  -> A1 is J1 BROKEN: the counter never loaded
#
# Usage: run.sh [--matrix]     Exit: 0 pass, 1 FAIL, 2 FIXTURE BROKEN.
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "fixture-invocation-budget: FIXTURE BROKEN: core/fixtures/lib/preamble.sh is absent" >&2; exit 2; }
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MODE=plain; [ "${1:-}" = --matrix ] && MODE=matrix
ROOT=""; d="$HERE"
while [ -n "$d" ] && [ "$d" != / ]; do
  [ -f "$d/scripts/validate-fixture-invocations.sh" ] && [ -f "$d/core/scripts/hermetic-run.sh" ] && { ROOT="$d"; break; }
  d="$(dirname "$d")"
done
[ -n "$ROOT" ] || { echo "FIXTURE ERROR: no scripts/validate-fixture-invocations.sh beside core/scripts/hermetic-run.sh walking up from $HERE" >&2; exit 2; }
for p in scripts/validate-fixture-invocations.sh core/scripts/hermetic-run.sh core/scripts/core-paths.sh .githooks/pre-push scripts/suite-content-key.sh core/fixtures/lib/mutant.sh; do
  [ -f "$ROOT/$p" ] || { echo "FIXTURE BROKEN: $p is absent under $ROOT" >&2; exit 2; }
done

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT
FAILS=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; FAILS=$((FAILS + 1)); }
. "$ROOT/core/fixtures/lib/mutant.sh"
JREL=scripts/validate-fixture-invocations.sh
RREL=core/scripts/hermetic-run.sh

# --- the subject tree, and mutants of it ------------------------------------------------------------------------
mk_subject() { # <dir>
  mkdir -p "$1/scripts" "$1/core/scripts" "$1/core/fixtures/lib" \
    && cp -p "$ROOT/$JREL" "$1/scripts/" \
    && cp -p "$ROOT/$RREL" "$ROOT/core/scripts/core-paths.sh" "$1/core/scripts/" \
    && cp -p "$ROOT/core/fixtures/lib/mutant.sh" "$1/core/fixtures/lib/"
}
SUBJ="$WORK/subj"
mk_subject "$SUBJ" && cmp -s "$ROOT/$JREL" "$SUBJ/$JREL" && cmp -s "$ROOT/$RREL" "$SUBJ/$RREL" \
  || { echo "FIXTURE BROKEN: could not copy the subject tree byte-identical into $SUBJ" >&2; exit 2; }
mk_mutant() { # <name> <file, subject-relative> <old> <new>: the whole tree copied, one line changed exactly once
  local m="$WORK/mut-$1"
  mk_subject "$m" || return 1
  OLD="$3" NEW="$4" awk '{ i = index($0, ENVIRON["OLD"]); if (i > 0) { $0 = substr($0, 1, i - 1) ENVIRON["NEW"] substr($0, i + length(ENVIRON["OLD"])); n++ } print }
    END { if (n != 1) exit 3 }' "$SUBJ/$2" > "$m/$2.new" || return 1
  mv "$m/$2.new" "$m/$2" && chmod +x "$m/$2" || return 1
  cmp -s "$SUBJ/$2" "$m/$2" && return 1
  [ -f "$m/core/scripts/core-paths.sh" ] && [ -f "$m/core/fixtures/lib/mutant.sh" ] || return 1
  return 0
}
mk_mutant MJ3 "$JREL" 'if [ "$m" != "$dcl" ]; then' 'if false; then' \
  || { echo "FIXTURE BROKEN: mutant MJ3 DID NOT APPLY (the J3 compare moved in $JREL)" >&2; exit 2; }
mk_mutant MGATE "$RREL" 'if [ "$hr_fxc" = 1 ] && [ "$hr_rc" -eq 0 ]; then' 'if false; then' \
  || { echo "FIXTURE BROKEN: mutant MGATE DID NOT APPLY (the judge call moved in $RREL)" >&2; exit 2; }
mk_mutant MPASS "$RREL" ' "BASH_ENV=$FXCOUNT_RC"' '' \
  || { echo "FIXTURE BROKEN: mutant MPASS DID NOT APPLY (the BASH_ENV passthrough moved in $RREL)" >&2; exit 2; }

# --- the probe worlds, each built once --------------------------------------------------------------------------
mk_world() { # <dir> <invocations.decl rows joined by |, or -> <Mx header row 1|0>
  local w="$1" f="$1/core/fixtures/probe"
  mkdir -p "$f" "$w/core/scripts" "$w/core/fixtures/lib" "$w/.githooks" "$w/scripts" || return 1
  cp -p "$ROOT/.githooks/pre-push" "$w/.githooks/pre-push" && cp -p "$ROOT/scripts/suite-content-key.sh" "$w/scripts/" \
    && cp -p "$ROOT/core/fixtures/lib/mutant.sh" "$w/core/fixtures/lib/" || return 1
  printf 'printf "HERMETIC-CONSUMED core/scripts/sub.sh\\n"\n' > "$w/core/scripts/sub.sh"
  { printf '#!/usr/bin/env bash\n'
    [ "$3" = 1 ] && printf '%s MUTANT-MATRIX Mx decides=A twins=B\n' '#'
    printf 'set -u\nok() { :; }\nbad() { :; }\n. core/fixtures/lib/mutant.sh\nbash core/scripts/sub.sh\nbash core/scripts/sub.sh\n'
    printf '%s\n' ' mutant_killed 1 Mx probe'; } > "$f/run.sh"
  printf '!core/scripts/sub.sh\ncore/fixtures/lib/\n' > "$f/inputs.decl"
  printf 'bash\n' > "$f/tools.decl"
  [ "$2" = - ] || printf '%s\n' "$2" | tr '|' '\n' > "$f/invocations.decl"
  ( cd "$w" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm probe ) >/dev/null 2>&1
}
mk_world "$WORK/w-ok" '3 *|2 core/scripts/sub.sh' 1 \
  && mk_world "$WORK/w-mis" '2 *|2 core/scripts/sub.sh' 1 \
  && mk_world "$WORK/w-nohdr" '3 *|2 core/scripts/sub.sh' 0 \
  && mk_world "$WORK/w-nodecl" - 1 \
  || { echo "FIXTURE BROKEN: could not build the probe worlds" >&2; exit 2; }

# --- one drive per cell -----------------------------------------------------------------------------------------
# drive <tag> <arm> <subject dir>: writes $WORK/c.<tag>.out and .rc, with its own counter dir and verdict store.
drive() {
  local t="$1" s="$3" w rcf fd="$WORK/fxd.$1" st="$WORK/store.$1"
  mkdir -p "$fd" "$st" || return 1
  if [ "$2" = SP ]; then
    bash "$s/$JREL" --self-probe > "$WORK/c.$t.out" 2>&1; echo $? > "$WORK/c.$t.rc"; return 0
  fi
  case "$2" in A1) w=ok ;; A2|A3|A6) w=mis ;; A4) w=nohdr ;; A5) w=nodecl ;; esac
  rcf="$(bash "$s/$JREL" --gen-rc "$WORK/rc.$t")" || return 1
  case "$2" in
    A3) env -u FXCOUNT_RC -u FXCOUNT_DIR -u FXCOUNT_JUDGE AI_DLC_VERDICT_STORE="$st" \
          bash "$s/$RREL" --root "$WORK/w-$w" probe ;;
    A6) env -u FXCOUNT_JUDGE FXCOUNT_RC="$rcf" FXCOUNT_DIR="$fd" AI_DLC_VERDICT_STORE="$st" \
          bash "$s/$RREL" --root "$WORK/w-$w" probe ;;
    *)  env FXCOUNT_RC="$rcf" FXCOUNT_DIR="$fd" FXCOUNT_JUDGE="$s/$JREL" AI_DLC_VERDICT_STORE="$st" \
          bash "$s/$RREL" --root "$WORK/w-$w" probe ;;
  esac > "$WORK/c.$t.out" 2>&1
  echo $? > "$WORK/c.$t.rc"
}
has()  { grep -qF -- "$2" "$WORK/c.$1.out"; }
rcis() { [ "$(cat "$WORK/c.$1.rc" 2>/dev/null)" = "$2" ]; }
nstore() { /usr/bin/find "$WORK/store.$1" -type f | wc -l | tr -d ' '; }
# verdict <arm> <tag>: 0 when the arm holds on that cell's drive
verdict() {
  local t="$2"
  case "$1" in
    A1) rcis "$t" 0 && has "$t" 'probe: invocation budget ok: 3 start(s)' && has "$t" 'probe: verdict recorded in' ;;
    A2) rcis "$t" 1 && has "$t" 'probe: FAIL (J3): row "2 *": measured 3, declared 2 -- if this change was meant to alter how often the fixture runs its subject, set the row to 3; otherwise this is the regrowth fixture-mutants.md '"'"'One run per distinct state'"'"' forbids' \
          && has "$t" 'hermetic-run: probe: rc=1' && [ "$(nstore "$t")" = 0 ] ;;
    A3|A6) rcis "$t" 0 && has "$t" 'probe: verdict recorded in' && ! has "$t" 'invocation budget' && [ ! -e "$WORK/fxd.$t/probe" ] ;;
    A4) rcis "$t" 1 && has "$t" 'probe: FAIL (J5): mutant_killed reported Mx, which has no' ;;
    A5) rcis "$t" 1 && has "$t" 'probe: FAIL (J2)' && has "$t" '  3 *' && has "$t" '  2 core/scripts/sub.sh' ;;
    SP) rcis "$t" 0 && has "$t" 'self-probe: 29 cells, all green' ;;
    *) return 1 ;;
  esac
}
ARMS="A1 A2 A3 A4 A5 A6 SP"
MUTANTS="MJ3 MGATE MPASS"

if [ "$MODE" = matrix ]; then
  # THE MATRIX: every mutant against every arm, never on a plain run (arm NM asserts that).
  : > "$WORK/mx.ran"
  for m in $MUTANTS; do for a in $ARMS; do drive "$m.$a" "$a" "$WORK/mut-$m" & done; done; wait
  for m in $MUTANTS; do
    dec=""; tw=""
    for a in $ARMS; do if verdict "$a" "$m.$a"; then tw="$tw,$a"; else dec="$dec,$a"; fi; done
    printf 'MATRIX %s decides=%s twins=%s\n' "$m" "${dec#,}" "${tw#,}"
  done
  exit 0
fi

# --- the unmutated arms -----------------------------------------------------------------------------------------
for a in $ARMS; do drive "base.$a" "$a" "$SUBJ" & done; wait
for a in $ARMS; do
  if verdict "$a" "base.$a"; then ok "$a holds on the unmutated subject"; : > "$WORK/base.$a"
  else bad "$a fails on the unmutated subject (rc $(cat "$WORK/c.base.$a.rc" 2>/dev/null)): $(head -c 600 "$WORK/c.base.$a.out" | tr '\n' ' ')"; fi
done
if [ -e "$WORK/base.A1" ] && [ -e "$WORK/base.A2" ]; then
  echo "HERMETIC-CONSUMED $JREL"
  echo "HERMETIC-CONSUMED $RREL"
fi

# --- the mutants, each on its deciding arm and one twin ---------------------------------------------------------
# score <mutant> <deciding arm> <twin arm> <the text the deciding arm's failure must carry>
score() {
  local m="$1" flag=0
  [ -e "$WORK/base.$2" ] && [ -e "$WORK/base.$3" ] && flag=1
  if verdict "$2" "$m.$2"; then bad "$m SURVIVED: arm $2 still holds under it"; return; fi
  has "$m.$2" "$4" || { bad "$m: arm $2 fails under it, but not for its reason (absent: $4)"; return; }
  verdict "$3" "$m.$3" || { bad "$m: its twin arm $3 fails too, so the failure is not attributable to $2"; return; }
  mutant_killed "$flag" "$m" "$m: arm $2 fails for its reason, twin $3 holds"
}
drive MJ3.SP SP "$WORK/mut-MJ3" & drive MJ3.A3 A3 "$WORK/mut-MJ3" &
drive MGATE.A2 A2 "$WORK/mut-MGATE" & drive MGATE.A3 A3 "$WORK/mut-MGATE" &
drive MPASS.A1 A1 "$WORK/mut-MPASS" & drive MPASS.A3 A3 "$WORK/mut-MPASS" &
wait
score MJ3 SP A3 'FAIL  self-probe J3 a * row off by one'
score MGATE A2 A3 'probe: verdict recorded in'
score MPASS A1 A3 'probe: FIXTURE BROKEN (J1)'

# NM: a plain run reached no matrix-only cell, and its per-push mutant drives did run.
if [ ! -e "$WORK/mx.ran" ] && [ -e "$WORK/c.MPASS.A1.out" ] && [ -e "$WORK/c.MJ3.SP.out" ]; then ok "NM a plain run executes no matrix-only cell, and the per-push mutant drives ran"
else bad "NM a plain run reached the matrix, or its per-push mutant drives did not run"; fi

[ "$FAILS" = 0 ] || { echo "fixture-invocation-budget: $FAILS FAILED"; exit 1; }
echo "fixture-invocation-budget: PASS"
exit 0
