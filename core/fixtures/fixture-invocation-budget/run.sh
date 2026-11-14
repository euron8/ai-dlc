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
#   A9  untag, armed: the same two sub.sh starts with no FXCELL tag and no cells.decl -> rc 1, the C1 row naming the
#       missing cells.decl, NO store entry. Its ALLOW twin is A1, whose world tags both starts as declared e2e cells
#       (`ok C: probe: 2 subject start(s), 2 tagged`), one property apart.
#   A10 rel, armed: the ok world with its second sub.sh start spelled relative to a cd'd directory, `( cd core &&
#       FXCELL=b bash scripts/sub.sh )` -> rc 0, the J3 path row reads 2 and both starts are tagged (twin A1)
#   SP  the judge's --self-probe standalone -> rc 0, all cells green
#   NM  a plain run executes no matrix-only cell (control: the per-push mutant drives ran)
# THE MUTANTS are copies of the whole subject tree (judge, runner, its core-paths.sh, mutant.sh), one line changed,
# guarded by cmp -s and an exactly-one-match rewrite. Per push each runs its deciding arm and one twin; the full
# mutant x arm matrix is `--matrix`, measured from a real run and recorded here:
# MUTANT-MATRIX MJ3 decides=A2,A8,SP,K2 twins=A3
# MUTANT-MATRIX MGATE decides=A1,A2,A4,A5,A7,A9,A10 twins=A3
# MUTANT-MATRIX MPASS decides=A1,A2,A4,A5,A7,A9,A10,K5 twins=A3
# MUTANT-MATRIX MEXEMPT decides=A7,A8,SP,K2 twins=A4
# MUTANT-MATRIX MARM decides=A8 twins=A1
# MUTANT-MATRIX MNRM decides=A8,SP,K2 twins=A3
# MUTANT-MATRIX MJ6 decides=A8,SP,K2 twins=A3
# MUTANT-MATRIX MC1 decides=A8,A9,SP,K2 twins=A3
# MUTANT-MATRIX MTAG decides=A1,A7,A8,A10,SP,K2 twins=A3
# MUTANT-MATRIX MREL decides=A8,A10,SP,K2 twins=A1
# MUTANT-MATRIX MKEY decides=A8,K1,K2 twins=K4
# MUTANT-MATRIX MIDC decides=K2 twins=K1
# MUTANT-MATRIX MLEG decides=A8,K2,K4 twins=K1
# MUTANT-MATRIX MUNC decides=K3,K5 twins=K1
# MUTANT-MATRIX MJROW decides=K5 twins=K1
# MUTANT-MATRIX MLOK decides=K5 twins=K1
# MUTANT-MATRIX MLDIR decides=K5 twins=K1
# MUTANT-MATRIX MCOL decides=K6 twins=K1
# MUTANT-MATRIX-DYNAMIC score why=score passes its first argument to mutant_killed; the names are the MUTANT-MATRIX literals above
# MUTANT-MATRIX-REMEASURE bash core/fixtures/fixture-invocation-budget/run.sh --matrix
# The matrix is re-measured as .claude/rules/fixture-mutants.md clause 2 ("One run per distinct state") requires.
# The matrix also shows A1, A4, A5, A6 and A7 green
# under MJ3, A3, A6, A8 and SP green under MGATE and MPASS, A1-A6 green under MEXEMPT, and every arm but A8 green under
# MARM, and A1-A7 green under MNRM and MJ6; only the twin each mutant runs per push is named. A8 decides MJ3, MEXEMPT, MNRM
# and MJ6 because arming runs the subject judge's self-probe, which is red under all four. MNRM and MJ6 run SP with twin A3. Per push: MJ3 runs SP with twin A3 (the per-fixture judge no longer
# repeats the self-probe, so only the J3 cells and the A2 mismatch see it); MGATE runs A2 with twin A3; MPASS runs A1
# with twin A3; MEXEMPT runs A7 with twin A4 (the same unrowed Mx, judged rather than exempt); MARM runs A8 with twin A1.
#   MJ3      the judge's J3 compare removed            -> SP names the J3 off-by-one cell
#   MGATE    the runner's judge call disabled           -> A2 records a pass for a mismatching fixture
#   MPASS    the runner's BASH_ENV passthrough dropped  -> A1 is J1 BROKEN: the counter never loaded
#   MEXEMPT  the judge's J5 allowlist exemption removed -> A7 FAILs J5 on an allowlisted fixture
#   MARM     the hook's arming export drops FXCOUNT_DIR -> A8 names FXCOUNT_DIR absent from a child env (twin A1)
#   MNRM     fxc_count's `.`/`..` normalisation removed (the old raw match) -> SP names the `..`-spelled cell (twin A3)
#   MJ6      fxc_b2's gap row reclassified as rowed (J6 dropped) -> SP names the unrowed-subject cell (twin A3); A8 decides
#            it too because arming runs the self-probe
#   MC1      fxc_cells_judge's C1 row dropped -> A9 passes the untagged world (twin A3); SP and A8 decide it too
#   MTAG     the rc's FXCELL field logged empty -> A1's tagged starts read untagged and FAIL C1 (twin A3); A7's world
#            tags the same way, and SP's real-rc leg and A8 decide it too
#   MREL     the rc logs a relative BASH_SOURCE as spelled (no `$PWD/` prefix) -> A10's cd-relative start matches no
#            row, so J3 reads 1 for 2 (twin A1); SP's relative-start cells and A8 decide it too
#   The K arms' mutants each run their deciding arm and twin K1 per push (twin K4 for MKEY, which moves K1):
#   MKEY     fxc_key_rows keys every fixture on itself, never its stub's IMPL -> K1's s-b row does not move
#   MIDC     fxc_identity_check passes every sha -> K2's code-edited copy passes
#   MLEG     fxc_legacy_ok drops the membership compare -> K4 lists s-b, whose membership changed
#   MUNC     readset_vs_input adds the judge row uncounted too -> K3's uncounted digest input fails
#   MJROW    readset_verdicts never compares the `#judge` row -> K5 reuses a counted pass under a moved row (d)
#   MLOK     readset_verdicts reads a legacy entry for any fixture -> K5 reuses one FXCOUNT_LEGACY_OK does not list (b)
#   MLDIR    readset_verdicts returns when the counted store has no directory -> K5's legacy reads (a) run
#   MCOL     the collector keeps the live store only -> K6 lists the legacy store dead
#   A judge mutant also reads red on K2 (its copy's sha is unpinned) and on A8 (arming checks the pin).
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
    && mkdir -p "$1/.githooks" && cp -p "$ROOT/.githooks/pre-push" "$1/.githooks/" \
    && cp -p "$ROOT/scripts/collect-counted-stores.sh" "$1/scripts/"
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
mk_mutant MNRM "$JREL" '? nrm($1) : $1 }' '? $1 : $1 }' \
  || { echo "FIXTURE BROKEN: mutant MNRM DID NOT APPLY (the fxc_count normalisation moved in $JREL)" >&2; exit 2; }
mk_mutant MJ6 "$JREL" "*) printf 'G" "*) printf 'B" \
  || { echo "FIXTURE BROKEN: mutant MJ6 DID NOT APPLY (fxc_b2's gap row moved in $JREL)" >&2; exit 2; }
mk_mutant MC1 "$JREL" 'print "C1\t" s "\t" $1 "\t" (par == "" ? "-" : par) }' 'next }' \
  || { echo "FIXTURE BROKEN: mutant MC1 DID NOT APPLY (fxc_cells_judge's C1 row moved in $JREL)" >&2; exit 2; }
mk_mutant MTAG "$JREL" '"${FXCELL:-}" "${FXCOUNT_PARENT:-}" >> "$FXCOUNT_LOG"' '"" "${FXCOUNT_PARENT:-}" >> "$FXCOUNT_LOG"' \
  || { echo "FIXTURE BROKEN: mutant MTAG DID NOT APPLY (the rc's FXCELL field moved in $JREL)" >&2; exit 2; }
mk_mutant MREL "$JREL" '*) __fxcp="$PWD/$__fxcp" ;;' '*) ;;' \
  || { echo "FIXTURE BROKEN: mutant MREL DID NOT APPLY (the rc's relative-path prefix moved in $JREL)" >&2; exit 2; }
mk_mutant MARM .githooks/pre-push 'export FXCOUNT_RC FXCOUNT_DIR FXCOUNT_JUDGE' 'export FXCOUNT_RC FXCOUNT_JUDGE' \
  || { echo "FIXTURE BROKEN: mutant MARM DID NOT APPLY (the arming export moved in .githooks/pre-push)" >&2; exit 2; }
mk_mutant MKEY "$JREL" '? I[$0] : fx' '? fx : fx' \
  || { echo "FIXTURE BROKEN: mutant MKEY DID NOT APPLY (fxc_key_rows' stub resolution moved in $JREL)" >&2; exit 2; }
mk_mutant MIDC "$JREL" 'END { exit (ok && n == 1) ? 0 : 1 }' 'END { exit 0 }' \
  || { echo "FIXTURE BROKEN: mutant MIDC DID NOT APPLY (fxc_identity_check's verdict moved in $JREL)" >&2; exit 2; }
mk_mutant MLEG "$JREL" ' && (((j[3] in A) ? "listed" : "unlisted") == j[4])' '' \
  || { echo "FIXTURE BROKEN: mutant MLEG DID NOT APPLY (fxc_legacy_ok's membership compare moved in $JREL)" >&2; exit 2; }
mk_mutant MUNC .githooks/pre-push '  [ -z "${FXCOUNT_JUDGE:-}" ] || readset_vs_judge "$1"' '  readset_vs_judge "$1"' \
  || { echo "FIXTURE BROKEN: mutant MUNC DID NOT APPLY (readset_vs_input's counted-only judge row moved in .githooks/pre-push)" >&2; exit 2; }
mk_mutant MJROW .githooks/pre-push 'FNR == 7 && vj && !leg {' 'FNR == 0 {' \
  || { echo "FIXTURE BROKEN: mutant MJROW DID NOT APPLY (readset_verdicts' judge-row compare moved in .githooks/pre-push)" >&2; exit 2; }
mk_mutant MLOK .githooks/pre-push ' && (!leg || (fx in LOK))' '' \
  || { echo "FIXTURE BROKEN: mutant MLOK DID NOT APPLY (readset_verdicts' legacy gate moved in .githooks/pre-push)" >&2; exit 2; }
mk_mutant MLDIR .githooks/pre-push '  [ -d "$store" ] || [ -n "$vld" ] || return 0' '  [ -d "$store" ] || return 0' \
  || { echo "FIXTURE BROKEN: mutant MLDIR DID NOT APPLY (readset_verdicts' store-directory gate moved in .githooks/pre-push)" >&2; exit 2; }
mk_mutant MCOL scripts/collect-counted-stores.sh '[ "$s" = "$live" ] || [ "$s" = "$legacy" ] && continue' '[ "$s" = "$live" ] && continue' \
  || { echo "FIXTURE BROKEN: mutant MCOL DID NOT APPLY (the collector's legacy keep moved in scripts/collect-counted-stores.sh)" >&2; exit 2; }

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

# --- the K arms: the counted store's per-fixture judge row (BL-1057) ----------------------------------------------
# k.sh <arm> <subject dir> <scratch dir>; K_ROOT names the repo root. Each arm prints one `K<n> ...` vector line.
#   K1 the judge's --key-rows over a stub s-b (IMPL s), s and u, under an allowlist without and with `s`: the stub's
#      row follows its IMPL's membership, u's does not move
#   K2 --identity-check: the judge as shipped passes, a copy with one code line added fails naming FXC-IDENTITY, a copy
#      with one comment line added passes
#   K3 READSET_VS's readset_vs_input from the subject hook: uncounted, no `#judge` row (line 5 is the first key row);
#      counted, line 5 is the judge's own row (one judge call), or the FXCOUNT_KEYROWS table's; a table without the
#      fixture gives no digest input
#   K4 --legacy-ok: membership changed (s-b) is not eligible, unchanged (u, x) is; the format must match (v under f2)
#   K5 the store reader end to end on a git world: an UNCOUNTED runner pass in the legacy store is reused for a fixture
#      FXCOUNT_LEGACY_OK lists (a) and not for one it does not (b); a COUNTED runner pass carries the `#judge` row (jl)
#      and is reused under the same row (c, through the judge call) and not under a moved one (d, through the table).
#      a and b run with the counted store's project directory absent, as on the first push after the store is renamed
#   K6 scripts/collect-counted-stores.sh on a seeded base: the dry run lists only the dead counted-<12 hex> store; the
#      apply removes it and keeps the live, the legacy and four near-miss names
cat > "$WORK/k.sh" <<'K'
#!/usr/bin/env bash
set -u
a="$1"; s="$2"; t="$3"; mkdir -p "$t" || exit 2
J="$s/scripts/validate-fixture-invocations.sh"
case "$a" in
K1)
  R="$t/r"; mkdir -p "$R/core/fixtures/s" "$R/core/fixtures/s-b" "$R/core/fixtures/u" "$t/j0/scripts" "$t/j1/scripts" || exit 2
  printf 'exit 0\n' > "$R/core/fixtures/s/run.sh"; printf 'exit 0\n' > "$R/core/fixtures/u/run.sh"
  printf '%s\n' 'HERE="$(cd "$(dirname "$0")" && pwd)"' 'IMPL="$HERE/../s/run.sh"' 'exec bash "$IMPL" --group b' > "$R/core/fixtures/s-b/run.sh"
  cp "$J" "$t/j0/scripts/" && cp "$J" "$t/j1/scripts/" || exit 2
  printf '# none listed\n' > "$t/j0/scripts/fixture-matrix-allowlist.txt"; printf 's\tS1 seeded\n' > "$t/j1/scripts/fixture-matrix-allowlist.txt"
  bash "$t/j0/scripts/validate-fixture-invocations.sh" --key-rows "$R" > "$t/k0"; r0=$?
  bash "$t/j1/scripts/validate-fixture-invocations.sh" --key-rows "$R" > "$t/k1"; r1=$?
  row() { awk -F'\t' -v f="$2" '$1 == f { split($2, j, " "); printf "%s:%s:%s", j[2], j[3], j[4] }' "$1"; }
  printf 'K1 rc=%s/%s s-b=%s>%s u=%s>%s s=%s>%s n=%s\n' "$r0" "$r1" "$(row "$t/k0" s-b)" "$(row "$t/k1" s-b)" \
    "$(row "$t/k0" u)" "$(row "$t/k1" u)" "$(row "$t/k0" s)" "$(row "$t/k1" s)" "$(awk 'END { print NR }' "$t/k1")" ;;
K2)
  for v in a b c; do mkdir -p "$t/$v/scripts" || exit 2; done
  cp "$J" "$t/a/scripts/x.sh" || exit 2
  awk '{ print } $0 == "set -u" && !d { print "FXC_K2_EXTRA=1"; d = 1 }' "$J" > "$t/b/scripts/x.sh"
  awk '{ print } $0 == "set -u" && !d { print "# one comment line the identity drops"; d = 1 }' "$J" > "$t/c/scripts/x.sh"
  { cmp -s "$J" "$t/b/scripts/x.sh" || cmp -s "$J" "$t/c/scripts/x.sh"; } && { echo "K2 BROKEN: a copy did not change"; exit 2; }
  for v in a b c; do bash "$t/$v/scripts/x.sh" --identity-check > "$t/$v.out" 2>&1; echo $? > "$t/$v.rc"; done
  printf 'K2 a=%s b=%s c=%s named=%s\n' "$(cat "$t/a.rc")" "$(cat "$t/b.rc")" "$(cat "$t/c.rc")" \
    "$(grep -c 'has no `# FXC-IDENTITY 1 <sha> <reason>` row' "$t/b.out")" ;;
K3)
  sed -n '/^# READSET_VS_BEGIN$/,/^# READSET_VS_END$/p' "$s/.githooks/pre-push" > "$t/vs.sh"
  grep -q '^readset_vs_input() ' "$t/vs.sh" || { echo "K3 BROKEN: no READSET_VS span with readset_vs_input"; exit 2; }
  R="$t/r"; mkdir -p "$R/core/fixtures/probe" && printf 'exit 0\n' > "$R/core/fixtures/probe/run.sh" || exit 2
  printf 'k\tv\n' > "$t/rows"; printf 'probe\t#judge f1 probe listed\n' > "$t/kr"; printf 'other\t#judge f1 other listed\n' > "$t/kr2"
  ( . "$t/vs.sh"; unset FXCOUNT_JUDGE FXCOUNT_KEYROWS; readset_vs_input probe "r f1" "$t/rows" "$R" ) > "$t/u" 2>/dev/null; ru=$?
  ( . "$t/vs.sh"; unset FXCOUNT_KEYROWS; FXCOUNT_JUDGE="$J"; readset_vs_input probe "r f1" "$t/rows" "$R" ) > "$t/c" 2>/dev/null; rc=$?
  ( . "$t/vs.sh"; FXCOUNT_JUDGE="$J"; FXCOUNT_KEYROWS="$t/kr"; readset_vs_input probe "r f1" "$t/rows" "$R" ) > "$t/k" 2>/dev/null; rk=$?
  ( . "$t/vs.sh"; FXCOUNT_JUDGE="$J"; FXCOUNT_KEYROWS="$t/kr2"; readset_vs_input probe "r f1" "$t/rows" "$R" ) > /dev/null 2>&1; rm2=$?
  l5() { sed -n 5p "$1" | tr '\t' '|'; }
  printf 'K3 unc=%s:%s:%s cnt=%s:%s tab=%s:%s miss=%s\n' "$ru" "$(grep -c '^#judge' "$t/u")" "$(l5 "$t/u")" "$rc" "$(l5 "$t/c")" "$rk" "$(l5 "$t/k")" "$rm2" ;;
K4)
  printf 's-b\t#judge f1 s unlisted\nu\t#judge f1 u unlisted\nx\t#judge f1 x listed\nv\t#judge f2 v unlisted\n' > "$t/kr"
  printf '# old\ns\tS1 seeded\nx\tS1 seeded\n' > "$t/old"
  o1="$(bash "$J" --legacy-ok "$t/old" "$t/kr" f1)"; r1=$?; o2="$(bash "$J" --legacy-ok "$t/old" "$t/kr" f2)"; r2=$?
  printf 'K4 rc=%s/%s f1=%s f2=%s\n' "$r1" "$r2" "$(printf '%s\n' "$o1" | tr '\n' ',')" "$(printf '%s\n' "$o2" | tr '\n' ',')" ;;
K5)
  W="$t/w"; mkdir -p "$W/.githooks" "$W/core/scripts" "$W/core/fixtures/decl" "$W/src" "$W/scripts" || exit 2
  cp "$s/.githooks/pre-push" "$W/.githooks/" && cp "$s/core/scripts/hermetic-run.sh" "$s/core/scripts/core-paths.sh" "$W/core/scripts/" \
    && cp "$K_ROOT/scripts/suite-content-key.sh" "$W/scripts/" || exit 2
  printf 'v1\n' > "$W/src/a.sh"
  printf '%s\n' 'if [ -f src/a.sh ]; then echo "HERMETIC-CONSUMED src/a.sh"; fi' 'exit 0' > "$W/core/fixtures/decl/run.sh"
  printf '!src/a.sh\n' > "$W/core/fixtures/decl/inputs.decl"; printf '1 *\n0 src/a.sh\n' > "$W/core/fixtures/decl/invocations.decl"
  ( cd "$W" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm k5 ) > /dev/null 2>&1 || exit 2
  root="$(cd "$W" && git rev-list --max-parents=0 HEAD)"
  env -u FXCOUNT_RC -u FXCOUNT_DIR -u FXCOUNT_JUDGE AI_DLC_VERDICT_STORE="$t/L" bash "$W/core/scripts/hermetic-run.sh" --root "$W" decl > "$t/hr.l" 2>&1; rl=$?
  nl="$(/usr/bin/find "$t/L" -type f | wc -l | tr -d ' ')"
  git clone -q "file://$W" "$t/B" > /dev/null 2>&1 || exit 2
  # The counted store has NO directory for this project until the counted write below, as on the first push after
  # the store is renamed: a and b read the legacy store with the counted one absent.
  [ ! -e "$t/S/$root" ] || { echo "K5 BROKEN: the counted store exists before any counted write"; exit 2; }
  sed -n '/# FIXTURE_POOL_BEGIN/,/# FIXTURE_POOL_END/p' "$s/.githooks/pre-push" > "$t/pool.sh"
  printf '%s\n' '. "$1" 2>/dev/null' 'for d in "$FXROOT"*/; do [ -f "$d/run.sh" ] && printf "%s\n" "$d"; done > "$2/list"' \
    'apply_readset_skip "$2/list" "$2" > "$2/ann" 2>&1' > "$t/drv.sh"
  printf 'decl\t#judge f1 decl unlisted\n' > "$t/kr.same"; printf 'decl\t#judge f1 decl listed\n' > "$t/kr.moved"
  printf 'decl\n' > "$t/lok.in"; printf 'other\n' > "$t/lok.out"
  dec() { # <tag> <keyrows file or -> <legacy-ok file or ->
    mkdir -p "$t/d.$1"
    ( cd "$t/B" || exit 2
      unset FXCOUNT_KEYROWS FXCOUNT_LEGACY_STORE FXCOUNT_LEGACY_OK
      [ "$2" = - ] || { FXCOUNT_KEYROWS="$2"; export FXCOUNT_KEYROWS; }
      [ "$3" = - ] || { FXCOUNT_LEGACY_STORE="$t/L"; FXCOUNT_LEGACY_OK="$3"; export FXCOUNT_LEGACY_STORE FXCOUNT_LEGACY_OK; }
      FXCOUNT_JUDGE="$J" AI_DLC_VERDICT_STORE="$t/S" AI_DLC_READSET_LIVE_TRACE=0 bash "$t/drv.sh" "$t/pool.sh" "$t/d.$1" ) > "$t/d.$1.log" 2>&1
    awk -F'\t' '$1 == "decl" && ($2 == "run" || $2 == "skip") { printf "%s", $2 }' "$t/d.$1/.kdec" 2>/dev/null
  }
  da="$(dec a "$t/kr.same" "$t/lok.in")"; db="$(dec b "$t/kr.same" "$t/lok.out")"
  rcf="$(bash "$J" --gen-rc "$t/rc")" && mkdir -p "$t/fxd" || exit 2
  env FXCOUNT_RC="$rcf" FXCOUNT_DIR="$t/fxd" FXCOUNT_JUDGE="$J" AI_DLC_VERDICT_STORE="$t/S" bash "$W/core/scripts/hermetic-run.sh" --root "$W" decl > "$t/hr.c" 2>&1; rw=$?
  jl="$(cat "$t/S/$root"/* 2>/dev/null | grep -cx '#judge f1 decl unlisted')"
  dc="$(dec c - -)"; dd="$(dec d "$t/kr.moved" -)"
  printf 'K5 rl=%s nl=%s a=%s b=%s rw=%s jl=%s c=%s d=%s\n' "$rl" "$nl" "$da" "$db" "$rw" "$jl" "$dc" "$dd" ;;
K6)
  B="$t/base"
  for d in counted-0123456789ab/r counted-cd68ce325a3d/r counted-b4f3542dc948/r counted-0123456789a counted-v2 counted-ABCDEF012345 notcounted-0123456789ab; do
    mkdir -p "$B/$d" && printf 'x\n' > "$B/$d/e1" || exit 2
  done
  printf 'x\n' > "$B/counted-0123456789ab/r/.tmp.1"
  ( cd "$s" && bash scripts/collect-counted-stores.sh --base "$B" ) > "$t/dry" 2>&1; rd=$?
  ( cd "$s" && bash scripts/collect-counted-stores.sh --apply --base "$B" ) > "$t/app" 2>&1; ra=$?
  printf 'K6 dry=%s:%s apply=%s:%s left=%s gone=%s\n' "$rd" "$(grep '^dead: ' "$t/dry" | tr '\n' ';')" "$ra" "$(grep '^removed: ' "$t/app" | tr '\n' ';')" \
    "$(/usr/bin/find "$B" -type f | wc -l | tr -d ' ')" "$([ -e "$B/counted-0123456789ab" ] && echo 0 || echo 1)" ;;
*) echo "k.sh: unknown arm $a"; exit 2 ;;
esac
K

# --- the probe worlds, each built once --------------------------------------------------------------------------
mk_world() { # <dir> <invocations.decl rows joined by |, or -> <Mx header row 1|0> [fixture name, default probe] [tag 1|0] [rel 1|0]
  # Tagged (the default) the two sub.sh starts carry FXCELL=a and FXCELL=b and the fixture declares both as e2e cells;
  # untagged (the `untag` world) the same starts carry no tag and there is no cells.decl, which C1 refuses.
  # rel (the `rel` world): the second start is spelled relative to a cd'd directory, `( cd core && bash scripts/sub.sh )`.
  local w="$1" f="$1/core/fixtures/${4:-probe}" tg="${5:-1}" pa="" pb="" s2='bash core/scripts/sub.sh'
  [ "$tg" = 1 ] && { pa='FXCELL=a '; pb='FXCELL=b '; }
  [ "${6:-0}" = 1 ] && { s2='bash scripts/sub.sh )'; pb="( cd core && $pb"; }
  mkdir -p "$f" "$w/core/scripts" "$w/core/fixtures/lib" "$w/.githooks" "$w/scripts" || return 1
  cp -p "$ROOT/.githooks/pre-push" "$w/.githooks/pre-push" && cp -p "$ROOT/scripts/suite-content-key.sh" "$w/scripts/" \
    && cp -p "$ROOT/core/fixtures/lib/mutant.sh" "$w/core/fixtures/lib/" || return 1
  printf 'printf "HERMETIC-CONSUMED core/scripts/sub.sh\\n"\n' > "$w/core/scripts/sub.sh"
  { printf '#!/usr/bin/env bash\n'
    [ "$3" = 1 ] && printf '%s MUTANT-MATRIX Mx decides=A twins=B\n' '#'
    printf 'set -u\nok() { :; }\nbad() { :; }\n. core/fixtures/lib/mutant.sh\n%sbash core/scripts/sub.sh\n%s%s\n' "$pa" "$pb" "$s2"
    printf '%s\n' ' mutant_killed 1 Mx probe'; } > "$f/run.sh"
  [ "$tg" = 1 ] && printf 'e2e core/scripts/sub.sh a why=the probe wiring\ne2e core/scripts/sub.sh b why=the probe wiring, second start\n' > "$f/cells.decl"
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
  && mk_world "$WORK/w-untag" '3 *|2 core/scripts/sub.sh' 1 probe 0 \
  && mk_world "$WORK/w-rel" '3 *|2 core/scripts/sub.sh' 1 probe 1 1 \
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
  case "$2" in K[1-6])
    K_ROOT="$ROOT" bash "$WORK/k.sh" "$2" "$s" "$WORK/k.$t" > "$WORK/c.$t.out" 2>&1; echo $? > "$WORK/c.$t.rc"; return 0 ;;
  esac
  local fx=probe
  case "$2" in A1) w=ok ;; A2|A3|A6) w=mis ;; A4) w=nohdr ;; A5) w=nodecl ;; A7) w=held; fx=held ;; A9) w=untag ;; A10) w=rel ;; esac
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
    A1) rcis "$t" 0 && has "$t" 'probe: invocation budget ok: 3 start(s)' && has "$t" 'probe: verdict recorded in' \
          && has "$t" 'ok C: probe: 2 subject start(s), 2 tagged, 0 covered by a nested row' ;;
    A9) rcis "$t" 1 && has "$t" 'probe: FAIL (C1): core/scripts/sub.sh started as a separate program with no FXCELL tag' \
          && has "$t" 'the fixture carries no cells.decl' && has "$t" 'hermetic-run: probe: rc=1' && [ "$(nstore "$t")" = 0 ] ;;
    A10) rcis "$t" 0 && has "$t" 'probe: invocation budget ok: 3 start(s)' && has "$t" 'probe: verdict recorded in' \
          && has "$t" 'ok C: probe: 2 subject start(s), 2 tagged, 0 covered by a nested row' ;;
    A2) rcis "$t" 1 && has "$t" 'probe: FAIL (J3): row "2 *": measured 3, declared 2 -- if this change was meant to alter how often the fixture runs its subject, set the row to 3; otherwise this is the regrowth fixture-mutants.md '"'"'One run per distinct state'"'"' forbids' \
          && has "$t" 'hermetic-run: probe: rc=1' && [ "$(nstore "$t")" = 0 ] ;;
    A3|A6) rcis "$t" 0 && has "$t" 'probe: verdict recorded in' && ! has "$t" 'invocation budget' && [ ! -e "$WORK/fxd.$t/probe" ] ;;
    A4) rcis "$t" 1 && has "$t" 'probe: FAIL (J5): mutant_killed reported Mx, which has no' ;;
    A5) rcis "$t" 1 && has "$t" 'probe: FAIL (J2)' && has "$t" '  3 *' && has "$t" '  2 core/scripts/sub.sh' ;;
    A7) rcis "$t" 0 && has "$t" 'held: J5 EXEMPT, not judged: held is a row of scripts/fixture-matrix-allowlist.txt' \
          && has "$t" 'held: verdict recorded in' && ! has "$t" '(J5): mutant_killed reported' ;;
    SP) rcis "$t" 0 && has "$t" 'self-probe: 118 cells, all green' ;;
    A8) rcis "$t" 0 && has "$t" 'A8 CHECK-OK call:' && has "$t" 'A8 CHECK-OK a-armed:' && has "$t" 'A8 CHECK-OK b-judge-absent:' \
          && has "$t" 'A8 CHECK-OK c-nested:' && ! has "$t" 'A8 CHECK-BAD' ;;
    K1) rcis "$t" 0 && has "$t" 'K1 rc=0/0 s-b=f1:s:unlisted>f1:s:listed u=f1:u:unlisted>f1:u:unlisted s=f1:s:unlisted>f1:s:listed n=3' ;;
    K2) rcis "$t" 0 && has "$t" 'K2 a=0 b=1 c=0 named=1' ;;
    K3) rcis "$t" 0 && has "$t" 'K3 unc=0:0:k|v cnt=0:#judge f1 probe unlisted tab=0:#judge f1 probe listed miss=1' ;;
    K4) rcis "$t" 0 && has "$t" 'K4 rc=0/0 f1=u,x, f2=v,' ;;
    K5) rcis "$t" 0 && has "$t" 'K5 rl=0 nl=1 a=skip b=run rw=0 jl=1 c=skip d=run' ;;
    K6) rcis "$t" 0 && has "$t" 'K6 dry=0:dead: counted-0123456789ab (2 file(s)); apply=0:removed: counted-0123456789ab (2 file(s)); left=6 gone=1' ;;
    *) return 1 ;;
  esac
}
ARMS="A1 A2 A3 A4 A5 A6 A7 A8 A9 A10 SP K1 K2 K3 K4 K5 K6"
MUTANTS="MJ3 MGATE MPASS MEXEMPT MARM MNRM MJ6 MC1 MTAG MREL MKEY MIDC MLEG MUNC MJROW MLOK MLDIR MCOL"

if [ "$MODE" = matrix ]; then
  # THE MATRIX: every mutant against every arm, never on a plain run (arm NM asserts that).
  : > "$WORK/mx.ran"
  # One mutant's arms at a time, so at most one row of drives runs at once.
  for m in $MUTANTS; do for a in $ARMS; do drive "$m.$a" "$a" "$WORK/mut-$m" & done; wait; done
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
[ -e "$WORK/base.K6" ] && echo "HERMETIC-CONSUMED scripts/collect-counted-stores.sh"

# --- the mutants, each on its deciding arm and one twin ---------------------------------------------------------
# score <mutant> <deciding arm> <twin arm> <the text the deciding arm's failure must carry>
score() {
  local m="$1" bp
  bp="$([ -e "$WORK/base.$2" ] && [ -e "$WORK/base.$3" ] && echo 1 || echo 0)"
  if verdict "$2" "$m.$2"; then bad "$m SURVIVED: arm $2 still holds under it"; return; fi
  has "$m.$2" "$4" || { bad "$m: arm $2 fails under it, but not for its reason (absent: $4)"; return; }
  verdict "$3" "$m.$3" || { bad "$m: its twin arm $3 fails too, so the failure is not attributable to $2"; return; }
  mutant_killed "$([ "$bp" = 1 ] && echo 1 || echo 0)" "$m" "$m: arm $2 fails for its reason, twin $3 holds"
}
drive MJ3.SP SP "$WORK/mut-MJ3" & drive MJ3.A3 A3 "$WORK/mut-MJ3" &
drive MGATE.A2 A2 "$WORK/mut-MGATE" & drive MGATE.A3 A3 "$WORK/mut-MGATE" &
drive MPASS.A1 A1 "$WORK/mut-MPASS" & drive MPASS.A3 A3 "$WORK/mut-MPASS" &
drive MEXEMPT.A7 A7 "$WORK/mut-MEXEMPT" & drive MEXEMPT.A4 A4 "$WORK/mut-MEXEMPT" &
drive MARM.A8 A8 "$WORK/mut-MARM" & drive MARM.A1 A1 "$WORK/mut-MARM" &
drive MNRM.SP SP "$WORK/mut-MNRM" & drive MNRM.A3 A3 "$WORK/mut-MNRM" &
drive MJ6.SP SP "$WORK/mut-MJ6" & drive MJ6.A3 A3 "$WORK/mut-MJ6" &
drive MC1.A9 A9 "$WORK/mut-MC1" & drive MC1.A3 A3 "$WORK/mut-MC1" &
drive MTAG.A1 A1 "$WORK/mut-MTAG" & drive MTAG.A3 A3 "$WORK/mut-MTAG" &
drive MREL.A10 A10 "$WORK/mut-MREL" & drive MREL.A1 A1 "$WORK/mut-MREL" &
drive MKEY.K1 K1 "$WORK/mut-MKEY" & drive MKEY.K4 K4 "$WORK/mut-MKEY" &
drive MIDC.K2 K2 "$WORK/mut-MIDC" & drive MIDC.K1 K1 "$WORK/mut-MIDC" &
drive MLEG.K4 K4 "$WORK/mut-MLEG" & drive MLEG.K1 K1 "$WORK/mut-MLEG" &
drive MUNC.K3 K3 "$WORK/mut-MUNC" & drive MUNC.K1 K1 "$WORK/mut-MUNC" &
drive MJROW.K5 K5 "$WORK/mut-MJROW" & drive MJROW.K1 K1 "$WORK/mut-MJROW" &
drive MLOK.K5 K5 "$WORK/mut-MLOK" & drive MLOK.K1 K1 "$WORK/mut-MLOK" &
drive MLDIR.K5 K5 "$WORK/mut-MLDIR" & drive MLDIR.K1 K1 "$WORK/mut-MLDIR" &
drive MCOL.K6 K6 "$WORK/mut-MCOL" & drive MCOL.K1 K1 "$WORK/mut-MCOL" &
wait
score MJ3 SP A3 'FAIL  self-probe J3 a * row off by one'
score MGATE A2 A3 'probe: verdict recorded in'
score MPASS A1 A3 'probe: FIXTURE BROKEN (J1)'
score MEXEMPT A7 A4 'held: FAIL (J5): mutant_killed reported Mx, which has no'
score MARM A8 A1 'A8 CHECK-BAD a-exported: FXCOUNT_DIR is not in a child env'
score MNRM SP A3 'FAIL  self-probe NRM dotdot counts 1'
score MJ6 SP A3 'FAIL  self-probe J6 an unrowed .sh bash subject FIRES'
score MC1 A9 A3 'probe: invocation budget ok: 3 start(s)'
score MTAG A1 A3 'probe: FAIL (C1): core/scripts/sub.sh started as a separate program with no FXCELL tag'
score MREL A10 A1 'probe: FAIL (J3): row "2 core/scripts/sub.sh": measured 1, declared 2'
score MKEY K1 K4 'K1 rc=0/0 s-b=f1:s-b:unlisted>f1:s-b:unlisted'
score MIDC K2 K1 'K2 a=0 b=0 c=0'
score MLEG K4 K1 'K4 rc=0/0 f1=s-b,u,x,'
score MUNC K3 K1 'K3 unc=1:0:'
score MJROW K5 K1 'c=skip d=skip'
score MLOK K5 K1 'a=skip b=skip'
score MLDIR K5 K1 'a=run b=run'
score MCOL K6 K1 'dead: counted-cd68ce325a3d (1 file(s))'

# NM: a plain run reached no matrix-only cell, and its per-push mutant drives did run.
if [ ! -e "$WORK/mx.ran" ] && [ -e "$WORK/c.MPASS.A1.out" ] && [ -e "$WORK/c.MJ3.SP.out" ]; then ok "NM a plain run executes no matrix-only cell, and the per-push mutant drives ran"
else bad "NM a plain run reached the matrix, or its per-push mutant drives did not run"; fi

[ "$FAILS" = 0 ] || { echo "fixture-invocation-budget: $FAILS FAILED"; exit 1; }
echo "fixture-invocation-budget: PASS"
exit 0
