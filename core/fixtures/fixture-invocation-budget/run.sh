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
#   A7  held, armed: a fixture with NO Mx row that is a row of the (seeded) scripts/fixture-matrix-allowlist.txt beside
#       the judge -> rc 0, `J5 EXEMPT, not judged`, verdict recorded (the exemption twin of A4, one property apart)
#   A8  the hook's ARMING: fxcount_arm extracted from the subject tree's .githooks/pre-push by its own boundaries
#       (exactly one definition, else BROKEN) and driven under a stub `step` with the FXCOUNT variables unset and the
#       store preset: (a) through the hook's own call-site line at depth 0, judge present -> FXCOUNT_RC (an rc under
#       the run dir), FXCOUNT_DIR (= <run dir>/log) and FXCOUNT_JUDGE are in a child `env` with those values, and
#       AI_DLC_VERDICT_STORE is <preset>/counted-<12 hex>; (b) no judge -> step rc non-zero, nothing exported, store
#       unchanged; (c) the call-site line at POOL_DEPTH_IN=1 -> the step runs (it is unconditional, so steps equal
#       verdicts at every depth) and returns 0 with the nested-pool line, and nothing is exported: no FXCOUNT variable
#       in a child env and the store not rewritten to counted-*. Also: exactly
#       one non-comment line before `step "fixture suite` calls fxcount_arm as a command word.
#   SP  the judge's --self-probe standalone -> rc 0, all cells green
#   NM  a plain run executes no matrix-only cell (control: the per-push mutant drives ran)
# THE MUTANTS are copies of the whole subject tree (judge, runner, its core-paths.sh, mutant.sh), one line changed,
# guarded by cmp -s and an exactly-one-match rewrite. Per push each runs its deciding arm and one twin; the full
# mutant x arm matrix is `--matrix`, measured from a real run and recorded here:
# MUTANT-MATRIX MJ3 decides=A2,A8,SP twins=A3
# MUTANT-MATRIX MGATE decides=A1,A2,A4,A5,A7 twins=A3
# MUTANT-MATRIX MPASS decides=A1,A2,A4,A5,A7 twins=A3
# MUTANT-MATRIX MEXEMPT decides=A7,A8,SP twins=A4
# MUTANT-MATRIX MARM decides=A8 twins=A1
# MUTANT-MATRIX-DYNAMIC score why=score passes its first argument to mutant_killed; the names are the five literals above
# MUTANT-MATRIX-REMEASURE bash core/fixtures/fixture-invocation-budget/run.sh --matrix
# Re-measure it whenever an arm or a mutant is added or changed. The matrix also shows A1, A4, A5, A6 and A7 green
# under MJ3, A3, A6, A8 and SP green under MGATE and MPASS, A1-A6 green under MEXEMPT, and every arm but A8 green under
# MARM; only the twin each mutant runs per push is named. A8 decides MJ3 and MEXEMPT because arming runs the subject
# judge's self-probe, which is red under both. Per push: MJ3 runs SP with twin A3 (the per-fixture judge no longer
# repeats the self-probe, so only the J3 cells and the A2 mismatch see it); MGATE runs A2 with twin A3; MPASS runs A1
# with twin A3; MEXEMPT runs A7 with twin A4 (the same unrowed Mx, judged rather than exempt); MARM runs A8 with twin A1.
#   MJ3      the judge's J3 compare removed            -> SP names the J3 off-by-one cell
#   MGATE    the runner's judge call disabled           -> A2 records a pass for a mismatching fixture
#   MPASS    the runner's BASH_ENV passthrough dropped  -> A1 is J1 BROKEN: the counter never loaded
#   MEXEMPT  the judge's J5 allowlist exemption removed -> A7 FAILs J5 on an allowlisted fixture
#   MARM     the hook's arming export drops FXCOUNT_DIR -> A8 names FXCOUNT_DIR absent from a child env (twin A1)
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
mk_subject() { # <dir>; the H5 allowlist beside the judge is SEEDED, listing only the probe fixture `held`
  mkdir -p "$1/scripts" "$1/core/scripts" "$1/core/fixtures/lib" \
    && printf '# seeded\nheld\tS1 a mutation helper\n' > "$1/scripts/fixture-matrix-allowlist.txt" \
    && cp -p "$ROOT/$JREL" "$1/scripts/" \
    && cp -p "$ROOT/$RREL" "$ROOT/core/scripts/core-paths.sh" "$1/core/scripts/" \
    && cp -p "$ROOT/core/fixtures/lib/mutant.sh" "$1/core/fixtures/lib/" \
    && mkdir -p "$1/.githooks" && cp -p "$ROOT/.githooks/pre-push" "$1/.githooks/"
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
mk_mutant MEXEMPT "$JREL" 'if [ -s "$log.mutants" ] && fxc_allowlisted "$key"; then' 'if false; then' \
  || { echo "FIXTURE BROKEN: mutant MEXEMPT DID NOT APPLY (the J5 allowlist exemption moved in $JREL)" >&2; exit 2; }
mk_mutant MARM .githooks/pre-push 'export FXCOUNT_RC FXCOUNT_DIR FXCOUNT_JUDGE' 'export FXCOUNT_RC FXCOUNT_JUDGE' \
  || { echo "FIXTURE BROKEN: mutant MARM DID NOT APPLY (the arming export moved in .githooks/pre-push)" >&2; exit 2; }

# --- A8's driver: fxcount_arm, extracted from the subject tree's hook by its own boundaries, under a stub `step` ---
# a8.sh <subject dir> <scratch dir>. Three modes, each in a subshell with the FXCOUNT variables unset and the verdict
# store preset: a (the judge present, depth 0, through the hook's own call-site line), b (no judge beside the cwd),
# c (depth 1, through the call-site line). Every check prints CHECK-OK or CHECK-BAD; any BAD exits 1.
cat > "$WORK/a8.sh" <<'A8'
#!/usr/bin/env bash
set -u
s="$1"; w="$2"; H="$s/.githooks/pre-push"; bad=0
mkdir -p "$w/nojudge" || exit 2
ok8()  { echo "A8 CHECK-OK $1"; }
bad8() { echo "A8 CHECK-BAD $1"; bad=1; }
[ -f "$H" ] || { echo "A8 BROKEN: no hook at $H"; exit 2; }
n="$(grep -c '^fxcount_arm() {$' "$H")" || n=0
[ "$n" = 1 ] || { echo "A8 BROKEN: fxcount_arm() is defined $n time(s) in $H, want exactly 1"; exit 2; }
awk '/^fxcount_arm\(\) \{$/ { on = 1 } on { print } on && /^}$/ { exit }' "$H" > "$w/a8.fn"
[ "$(tail -1 "$w/a8.fn")" = "}" ] || { echo "A8 BROKEN: fxcount_arm has no closing brace at column 0"; exit 2; }
# The call site: a non-comment line before the first `step "fixture suite` running fxcount_arm as a command word.
awk '/^step "fixture suite/ { seen = 1; exit } /^[[:space:]]*#/ { next } /^fxcount_arm\(\) \{$/ { skip = 1 }
  skip { if ($0 ~ /^}$/) skip = 0; next }
  /(^|[[:space:];&|])fxcount_arm([[:space:];&|)]|$)/ { print } END { if (!seen) print "NO-SUITE-STEP" }' "$H" > "$w/a8.call"
nc="$(grep -vc '^NO-SUITE-STEP$' "$w/a8.call")" || nc=0
if grep -q '^NO-SUITE-STEP$' "$w/a8.call"; then bad8 "call: the hook has no step \"fixture suite line"
elif [ "$nc" = 1 ]; then ok8 "call: the hook calls fxcount_arm on one non-comment line before the fixture suite"
else bad8 "call: $nc non-comment line(s) before the fixture suite call fxcount_arm, want exactly 1"; fi
mode() { # <label> <cwd> <POOL_DEPTH_IN>
  mkdir -p "$w/tmp.$1"
  ( cd "$2" || exit 2
    unset FXCOUNT_RC FXCOUNT_DIR FXCOUNT_JUDGE
    export AI_DLC_VERDICT_STORE="$w/store.$1" TMPDIR="$w/tmp.$1"
    POOL_DEPTH_IN="$3"
    step() { shift; "$@"; echo "STEP_RC=$?"; }
    . "$w/a8.fn"
    eval "$(grep -v '^NO-SUITE-STEP$' "$w/a8.call")"
    env > "$w/env.$1" ) > "$w/out.$1" 2>&1
}
ev() { awk -v k="$2" 'index($0, k "=") == 1 { print substr($0, length(k) + 2); f = 1 } END { exit f ? 0 : 1 }' "$w/env.$1"; }
mode a "$s" 0; mode b "$w/nojudge" 0; mode c "$s" 1
# (a) armed: every variable exported, each with its value.
abad=0
for v in FXCOUNT_RC FXCOUNT_DIR FXCOUNT_JUDGE AI_DLC_VERDICT_STORE; do ev a "$v" > /dev/null || { bad8 "a-exported: $v is not in a child env"; abad=1; }; done
grep -qx 'STEP_RC=0' "$w/out.a" || { bad8 "a-rc: the armed step did not return 0: $(tr '\n' ' ' < "$w/out.a" | cut -c1-300)"; abad=1; }
rc="$(ev a FXCOUNT_RC)"; d="$(ev a FXCOUNT_DIR)"; j="$(ev a FXCOUNT_JUDGE)"; st="$(ev a AI_DLC_VERDICT_STORE)"
case "$rc" in "$w/tmp.a/fxcount."*/fxcount.rc) [ -s "$rc" ] || { bad8 "a-rc-file: $rc is empty or absent"; abad=1; } ;;
  *) bad8 "a-rc-path: FXCOUNT_RC=$rc is not an rc under the run dir in $w/tmp.a"; abad=1 ;; esac
[ "$d" = "${rc%/*}/log" ] && [ -d "$d" ] || { bad8 "a-dir: FXCOUNT_DIR=$d, want the directory ${rc%/*}/log"; abad=1; }
[ "$j" = "$s/scripts/validate-fixture-invocations.sh" ] || { bad8 "a-judge: FXCOUNT_JUDGE=$j"; abad=1; }
grep -Eqx 'counted-[0-9a-f]{12}' <<< "${st#"$w/store.a/"}" && [ "${st%/*}" = "$w/store.a" ] \
  || { bad8 "a-store: AI_DLC_VERDICT_STORE=$st, want $w/store.a/counted-<12 hex>"; abad=1; }
[ "$abad" = 0 ] && ok8 "a-armed: RC, DIR, JUDGE and the counted-<12 hex> store are exported with their values"
# (b) the judge absent: a non-zero step, nothing exported, the store untouched.
bbad=0
grep -Eqx 'STEP_RC=[1-9][0-9]*' "$w/out.b" || { bad8 "b-rc: the step without a judge did not return non-zero"; bbad=1; }
for v in FXCOUNT_RC FXCOUNT_DIR FXCOUNT_JUDGE; do ev b "$v" > /dev/null && { bad8 "b-exported: $v reached a child env with no judge"; bbad=1; }; done
[ "$(ev b AI_DLC_VERDICT_STORE)" = "$w/store.b" ] || { bad8 "b-store: the store moved with no judge"; bbad=1; }
[ "$bbad" = 0 ] && ok8 "b-judge-absent: rc non-zero, nothing exported, the store unchanged"
# (c) nested: the call-site line does not arm.
cbad=0
grep -qx 'STEP_RC=0' "$w/out.c" || { bad8 "c-step: the unconditional arming step did not return 0 at POOL_DEPTH_IN=1: $(tr '\n' ' ' < "$w/out.c" | cut -c1-300)"; cbad=1; }
grep -qF 'nested pool (depth 1): the outer hook arms the counter; this copy stays inert' "$w/out.c" \
  || { bad8 "c-line: the step at POOL_DEPTH_IN=1 did not print the nested-pool line"; cbad=1; }
for v in FXCOUNT_RC FXCOUNT_DIR FXCOUNT_JUDGE; do ev c "$v" > /dev/null && { bad8 "c-exported: $v reached a child env at depth 1"; cbad=1; }; done
[ "$(ev c AI_DLC_VERDICT_STORE)" = "$w/store.c" ] || { bad8 "c-store: the store moved at depth 1"; cbad=1; }
[ "$cbad" = 0 ] && ok8 "c-nested: at POOL_DEPTH_IN=1 nothing is armed"
exit "$bad"
A8

# --- the probe worlds, each built once --------------------------------------------------------------------------
mk_world() { # <dir> <invocations.decl rows joined by |, or -> <Mx header row 1|0> [fixture name, default probe]
  local w="$1" f="$1/core/fixtures/${4:-probe}"
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
  && mk_world "$WORK/w-held" '3 *|2 core/scripts/sub.sh' 0 held \
  || { echo "FIXTURE BROKEN: could not build the probe worlds" >&2; exit 2; }

# --- one drive per cell -----------------------------------------------------------------------------------------
# drive <tag> <arm> <subject dir>: writes $WORK/c.<tag>.out and .rc, with its own counter dir and verdict store.
drive() {
  local t="$1" s="$3" w rcf fd="$WORK/fxd.$1" st="$WORK/store.$1"
  mkdir -p "$fd" "$st" || return 1
  if [ "$2" = SP ]; then
    bash "$s/$JREL" --self-probe > "$WORK/c.$t.out" 2>&1; echo $? > "$WORK/c.$t.rc"; return 0
  fi
  if [ "$2" = A8 ]; then
    bash "$WORK/a8.sh" "$s" "$WORK/a8.$t" > "$WORK/c.$t.out" 2>&1; echo $? > "$WORK/c.$t.rc"; return 0
  fi
  local fx=probe
  case "$2" in A1) w=ok ;; A2|A3|A6) w=mis ;; A4) w=nohdr ;; A5) w=nodecl ;; A7) w=held; fx=held ;; esac
  rcf="$(bash "$s/$JREL" --gen-rc "$WORK/rc.$t")" || return 1
  case "$2" in
    A3) env -u FXCOUNT_RC -u FXCOUNT_DIR -u FXCOUNT_JUDGE AI_DLC_VERDICT_STORE="$st" \
          bash "$s/$RREL" --root "$WORK/w-$w" "$fx" ;;
    A6) env -u FXCOUNT_JUDGE FXCOUNT_RC="$rcf" FXCOUNT_DIR="$fd" AI_DLC_VERDICT_STORE="$st" \
          bash "$s/$RREL" --root "$WORK/w-$w" "$fx" ;;
    *)  env FXCOUNT_RC="$rcf" FXCOUNT_DIR="$fd" FXCOUNT_JUDGE="$s/$JREL" AI_DLC_VERDICT_STORE="$st" \
          bash "$s/$RREL" --root "$WORK/w-$w" "$fx" ;;
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
    A7) rcis "$t" 0 && has "$t" 'held: J5 EXEMPT, not judged: held is a row of scripts/fixture-matrix-allowlist.txt' \
          && has "$t" 'held: verdict recorded in' && ! has "$t" '(J5): mutant_killed reported' ;;
    SP) rcis "$t" 0 && has "$t" 'self-probe: 53 cells, all green' ;;
    A8) rcis "$t" 0 && has "$t" 'A8 CHECK-OK call:' && has "$t" 'A8 CHECK-OK a-armed:' && has "$t" 'A8 CHECK-OK b-judge-absent:' \
          && has "$t" 'A8 CHECK-OK c-nested:' && ! has "$t" 'A8 CHECK-BAD' ;;
    *) return 1 ;;
  esac
}
ARMS="A1 A2 A3 A4 A5 A6 A7 A8 SP"
MUTANTS="MJ3 MGATE MPASS MEXEMPT MARM"

if [ "$MODE" = matrix ]; then
  # THE MATRIX: every mutant against every arm, never on a plain run (arm NM asserts that).
  : > "$WORK/mx.ran"
  for m in $MUTANTS; do for a in $ARMS; do drive "$m.$a" "$a" "$WORK/mut-$m" & done; done; wait
  for m in $MUTANTS; do
    dec=""; tw=""
    for a in $ARMS; do if verdict "$a" "$m.$a"; then tw="$tw,$a"; else dec="$dec,$a"; fi; done
    printf 'MATRIX %s decides=%s twins=%s\n' "$m" "${dec#,}" "${tw#,}"
  done
fi
# A SEPARATE exit, keyed on MODE: a matrix guard that wrongly opened on a plain run falls through to NM and FAILs.
[ "$MODE" = matrix ] && exit 0

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
drive MEXEMPT.A7 A7 "$WORK/mut-MEXEMPT" & drive MEXEMPT.A4 A4 "$WORK/mut-MEXEMPT" &
drive MARM.A8 A8 "$WORK/mut-MARM" & drive MARM.A1 A1 "$WORK/mut-MARM" &
wait
score MJ3 SP A3 'FAIL  self-probe J3 a * row off by one'
score MGATE A2 A3 'probe: verdict recorded in'
score MPASS A1 A3 'probe: FIXTURE BROKEN (J1)'
score MEXEMPT A7 A4 'held: FAIL (J5): mutant_killed reported Mx, which has no'
score MARM A8 A1 'A8 CHECK-BAD a-exported: FXCOUNT_DIR is not in a child env'

# NM: a plain run reached no matrix-only cell, and its per-push mutant drives did run.
if [ ! -e "$WORK/mx.ran" ] && [ -e "$WORK/c.MPASS.A1.out" ] && [ -e "$WORK/c.MJ3.SP.out" ]; then ok "NM a plain run executes no matrix-only cell, and the per-push mutant drives ran"
else bad "NM a plain run reached the matrix, or its per-push mutant drives did not run"; fi

[ "$FAILS" = 0 ] || { echo "fixture-invocation-budget: $FAILS FAILED"; exit 1; }
echo "fixture-invocation-budget: PASS"
exit 0
