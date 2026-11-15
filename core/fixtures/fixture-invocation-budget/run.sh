#!/usr/bin/env bash
# fixture-invocation-budget -- drive the REAL scripts/validate-fixture-invocations.sh through the REAL
# core/scripts/hermetic-run.sh against a probe project, armed and unarmed.
#
# THE SUBJECT is the invocation budget end to end: hermetic-run.sh's three-variable gate, its BASH_ENV/FXCOUNT_LOG
# passthrough into the sandboxed fixture, its judge call before the verdict-store write, and the judge's arms.
# Nothing here re-implements a judge rule: every verdict below is the shipping judge's, read off the runner's output.
#
# run.sh itself). The worlds, each
# built once: ok (declared 3 / 2), mis (declared 2 / 2), nodecl (no invocations.decl), untag and rel (A9, A10).
# built once: ok (declared 3 / 2), mis (declared 2 / 2), nodecl (no invocations.decl).
# THE ARMS, each one drive of the runner into a fresh counter dir and a fresh verdict store:
#   A1  ok, armed       -> rc 0, `invocation budget ok: 3 start(s)`, verdict recorded
#   A2  mis, armed      -> rc 1, the J3 row naming measured 3 and declared 2, NO store entry (control: rc=1 line)
#   A3  mis, unarmed    -> rc 0, verdict recorded, no judge line, no counter log created (ALLOW twin of A2)
#   A5  nodecl, armed   -> rc 1, J2 printing `3 *` and `2 core/scripts/sub.sh`
#   A6  mis, two of the three arming variables -> inert exactly as A3
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
# Usage: run.sh     Exit: 0 pass, 1 FAIL, 2 FIXTURE BROKEN.
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "fixture-invocation-budget: FIXTURE BROKEN: core/fixtures/lib/preamble.sh is absent" >&2; exit 2; }
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
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
# shellcheck source=/dev/null
. "$HERE/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }
JREL=scripts/validate-fixture-invocations.sh
RREL=core/scripts/hermetic-run.sh

# --- the subject tree ------------------------------------------------------------------------
mk_subject() { # <dir>
  mkdir -p "$1/scripts" "$1/core/scripts" "$1/core/fixtures/lib" \
    && cp -p "$ROOT/$JREL" "$1/scripts/" \
    && cp -p "$ROOT/$RREL" "$ROOT/core/scripts/core-paths.sh" "$1/core/scripts/" \
    && cp -p "$ROOT/core/fixtures/lib/mutant.sh" "$1/core/fixtures/lib/" \
    && mkdir -p "$1/.githooks" && cp -p "$ROOT/.githooks/pre-push" "$1/.githooks/" \
    && cp -p "$ROOT/scripts/collect-counted-stores.sh" "$1/scripts/"
}
SUBJ="$WORK/subj"
mk_subject "$SUBJ" && cmp -s "$ROOT/$JREL" "$SUBJ/$JREL" && cmp -s "$ROOT/$RREL" "$SUBJ/$RREL" \
  || { echo "FIXTURE BROKEN: could not copy the subject tree byte-identical into $SUBJ" >&2; exit 2; }

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
#   K1 the judge's --key-rows over a stub s-b (IMPL s), s and u: the stub's row is keyed on its IMPL, every row reads
#      `unlisted`
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
  R="$t/r"; mkdir -p "$R/core/fixtures/s" "$R/core/fixtures/s-b" "$R/core/fixtures/u" || exit 2
  printf 'exit 0\n' > "$R/core/fixtures/s/run.sh"; printf 'exit 0\n' > "$R/core/fixtures/u/run.sh"
  printf '%s\n' 'HERE="$(cd "$(dirname "$0")" && pwd)"' 'IMPL="$HERE/../s/run.sh"' 'exec bash "$IMPL" --group b' > "$R/core/fixtures/s-b/run.sh"
  bash "$J" --key-rows "$R" > "$t/k1"; r1=$?
  row() { awk -F'\t' -v f="$2" '$1 == f { split($2, j, " "); printf "%s:%s:%s", j[2], j[3], j[4] }' "$1"; }
  printf 'K1 rc=%s s-b=%s u=%s s=%s n=%s\n' "$r1" "$(row "$t/k1" s-b)" "$(row "$t/k1" u)" "$(row "$t/k1" s)" "$(awk 'END { print NR }' "$t/k1")" ;;
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
mk_world() { # <dir> <invocations.decl rows joined by |, or -> [fixture name, default probe] [tag 1|0] [rel 1|0]
  # Tagged (the default) the two sub.sh starts carry FXCELL=a and FXCELL=b and the fixture declares both as e2e cells;
  # untagged (the `untag` world) the same starts carry no tag and there is no cells.decl, which C1 refuses.
  # rel (the `rel` world): the second start is spelled relative to a cd'd directory, `( cd core && bash scripts/sub.sh )`.
  local w="$1" f="$1/core/fixtures/${3:-probe}" tg="${4:-1}" pa="" pb="" s2='bash core/scripts/sub.sh'
  [ "$tg" = 1 ] && { pa='FXCELL=a '; pb='FXCELL=b '; }
  [ "${5:-0}" = 1 ] && { s2='bash scripts/sub.sh )'; pb="( cd core && $pb"; }
  mkdir -p "$f" "$w/core/scripts" "$w/.githooks" "$w/scripts" || return 1
  cp -p "$ROOT/.githooks/pre-push" "$w/.githooks/pre-push" && cp -p "$ROOT/scripts/suite-content-key.sh" "$w/scripts/" || return 1
  printf 'printf "HERMETIC-CONSUMED core/scripts/sub.sh\\n"\n' > "$w/core/scripts/sub.sh"
  { printf '#!/usr/bin/env bash\n'
    printf 'set -u\n%sbash core/scripts/sub.sh\n%s%s\n' "$pa" "$pb" "$s2"; } > "$f/run.sh"
  [ "$tg" = 1 ] && printf 'e2e core/scripts/sub.sh a why=the probe wiring\ne2e core/scripts/sub.sh b why=the probe wiring, second start\n' > "$f/cells.decl"
  printf '!core/scripts/sub.sh\n' > "$f/inputs.decl"
  printf 'bash\n' > "$f/tools.decl"
  [ "$2" = - ] || printf '%s\n' "$2" | tr '|' '\n' > "$f/invocations.decl"
  ( cd "$w" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -qm probe ) >/dev/null 2>&1
}
mk_world "$WORK/w-ok" '3 *|2 core/scripts/sub.sh' \
  && mk_world "$WORK/w-mis" '2 *|2 core/scripts/sub.sh' \
  && mk_world "$WORK/w-nodecl" - \
  && mk_world "$WORK/w-untag" '3 *|2 core/scripts/sub.sh' probe 0 \
  && mk_world "$WORK/w-rel" '3 *|2 core/scripts/sub.sh' probe 1 1 \
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
  case "$2" in A1) w=ok ;; A2|A3|A6) w=mis ;; A5) w=nodecl ;; A9) w=untag ;; A10) w=rel ;; esac
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
    A5) rcis "$t" 1 && has "$t" 'probe: FAIL (J2)' && has "$t" '  3 *' && has "$t" '  2 core/scripts/sub.sh' ;;
    SP) rcis "$t" 0 && has "$t" 'self-probe: 103 cells, all green' ;;
    A8) rcis "$t" 0 && has "$t" 'A8 CHECK-OK call:' && has "$t" 'A8 CHECK-OK a-armed:' && has "$t" 'A8 CHECK-OK b-judge-absent:' \
          && has "$t" 'A8 CHECK-OK c-nested:' && ! has "$t" 'A8 CHECK-BAD' ;;
    K1) rcis "$t" 0 && has "$t" 'K1 rc=0 s-b=f1:s:unlisted u=f1:u:unlisted s=f1:s:unlisted n=3' ;;
    K2) rcis "$t" 0 && has "$t" 'K2 a=0 b=1 c=0 named=1' ;;
    K3) rcis "$t" 0 && has "$t" 'K3 unc=0:0:k|v cnt=0:#judge f1 probe unlisted tab=0:#judge f1 probe listed miss=1' ;;
    K4) rcis "$t" 0 && has "$t" 'K4 rc=0/0 f1=u,x, f2=v,' ;;
    K5) rcis "$t" 0 && has "$t" 'K5 rl=0 nl=1 a=skip b=run rw=0 jl=1 c=skip d=run' ;;
    K6) rcis "$t" 0 && has "$t" 'K6 dry=0:dead: counted-0123456789ab (2 file(s)); apply=0:removed: counted-0123456789ab (2 file(s)); left=6 gone=1' ;;
    *) return 1 ;;
  esac
}
ARMS="A1 A2 A3 A5 A6 A8 A9 A10 SP K1 K2 K3 K4 K5 K6"

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

report_end fixture-invocation-budget
