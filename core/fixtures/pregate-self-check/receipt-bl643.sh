#!/bin/bash
# BL-643 receipt. usage: receipt-bl643.sh [<pregate-self-check.sh>]; run from the repo root.
#   Seeds throwaway mini ROOTs (a stub hook, stub validators, a stub fork-budget fixture) and drives the
#   self-check against each in seconds. The self-check and its spelling grammar are copied from the tree
#   this runs in; nothing is read from another ref.
#   exit 0   A (today's hook shape) -> 0; B (an added failing above-pool step) -> 1 naming it; C (the
#            fixture-suite marker twice) -> 2; and an unparseable prefix, a prefix with no step, and a
#            step that prints no verdict each -> 2; and D (A plus a NUL byte above the marker and a step
#            below it that touches BELOW-RAN) -> 2 with BELOW-RAN absent and the NUL named (the fix is
#            present); and U (A, with section d's counted run printing no judge pass line) -> 2 naming it,
#            and J (A, with section d's counted run reading a J3 FAIL) -> 1 under d:fork-budget (BL-1026); and A's
#            section d ran through seed-verdict-store.sh into its hook's counted store (BL-1064), Wd's (dirty) too,
#            through --dirty-ok (BL-1066); and, under --member (BL-1082), Mt (a clean committed branch that edited its
#            hook, the push running the base bytes) -> 0 naming the tree's own hook and writing no pregate record
#            (no record dir at all), and Mr (A with a red step seeded between PRESUITE_DONE=1 and the fixture-suite
#            marker, same hook-path state) -> 1 naming that step; and Htree's edited-hook refusal names --member;
#            and section e (BL-1069): A skips; Mt runs its 3 hook-naming fixtures and 1 wrapper green; Er (Mt with
#            a runner the hook edit breaks) -> 1 under e:hook-fixtures naming the red; Ts (edits a script the hook
#            names) runs it green; Tn (adds a script no hook names) skips
#   exit 1   any of those differs
#   exit 9   the receipt cannot measure: a root could not be built (mktemp, git init, commit, a seed hook
#            that fails bash -n) or an input file is missing
#
# --gate <pre-push>: the BL-1055 gate world instead. Cuts the PREGATE_GATE span out of <pre-push> (preceded by the
#   one line that fills PUSH_LINES from stdin, followed by `echo PAST-THE-GATE`) and drives it from a two-commit repo G:
#   deny (an update line for HEAD, clean, no record) -> 1 naming the missing record; empty (no stdin, no record) -> past;
#   allow (record for HEAD's tree) -> past; tree (the line names HEAD~1, whose tree differs) -> 1 naming the tree;
#   dirty (record present, an untracked file) -> 1 naming the dirty tree. Then the WHOLE <pre-push>
#   on the deny shape from a clean copy of G (E2E), which must stop at the gate. Prints one summary line; exit 0 when it
#   is the expected line, 1 when it differs, 9 when the world cannot be built.
set -uo pipefail
if [ "${1:-}" = --gate ]; then
  HK="${2:-}"
  [ -s "$HK" ] || exit 9
  case "$HK" in /*) : ;; *) HK="$PWD/$HK" ;; esac
  W="$(mktemp -d)" || exit 9
  trap '[ -n "$W" ] && rm -rf "$W"' EXIT
  G="$W/g"; mkdir -p "$G" || exit 9
  nb="$(grep -cxF '# PREGATE_GATE_BEGIN' "$HK")" || nb=0; ne="$(grep -cxF '# PREGATE_GATE_END' "$HK")" || ne=0
  [ "$nb" = 1 ] && [ "$ne" = 1 ] || { echo "gate receipt: PREGATE_GATE_BEGIN/END occur $nb/$ne times in $HK, expected 1/1" >&2; exit 9; }
  # The gate resolves its record through the RECORD_HOME and READSET_VS spans it reads out of its own file, so the cut
  # carries both after its last line; G's records live in G's own store, $G.vs.
  { printf '%s\n' '#!/usr/bin/env bash' 'PUSH_LINES="$(cat)"'
    sed -n '/^# PREGATE_GATE_BEGIN$/,/^# PREGATE_GATE_END$/p' "$HK"
    printf '%s\n' 'echo PAST-THE-GATE' 'exit 0'
    sed -n '/^# READSET_VS_BEGIN$/,/^# READSET_VS_END$/p;/^# RECORD_HOME_BEGIN$/,/^# RECORD_HOME_END$/p' "$HK"; } > "$W/gate.sh" || exit 9
  bash -n "$W/gate.sh" || exit 9
  export AI_DLC_VERDICT_STORE="$G.vs"
  ( cd "$G" && unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE && git init -q . && echo one > f && git add -A \
    && git -c user.email=x@x -c user.name=x commit -q -m one && echo two > f \
    && git -c user.email=x@x -c user.name=x commit -q -am two ) || exit 9
  gx() { ( cd "$G" && unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE && git "$@" ); }
  H1="$(gx rev-parse HEAD)" && H0="$(gx rev-parse HEAD~1)" && TR="$(gx rev-parse 'HEAD^{tree}')" || exit 9
  Z40=0000000000000000000000000000000000000000
  gdrive() { # <stdin text|-> <out> -> the cut gate's exit; `-` is an empty stdin
    if [ "$1" = - ]; then ( cd "$G" && unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE && bash "$W/gate.sh" </dev/null >"$2" 2>&1 )
    else printf '%s\n' "$1" | ( cd "$G" && unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE && bash "$W/gate.sh" >"$2" 2>&1 ); fi
  }
  past() { grep -qxF PAST-THE-GATE "$1" && echo 0 || echo 1; }
  cp -R "$G" "$W/e" || exit 9
    printf 'refs/heads/x %s refs/heads/x %s\n' "$H1" "$Z40" | ( cd "$W/e" && unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE \
      && AI_DLC_READSET_LIVE_TRACE=0 bash "$HK" origin file:///nowhere/x.git >"$W/e.out" 2>&1 ); E2E=$?
  E2En=no; grep -qF 'No green scripts/pregate-self-check.sh run is recorded for this tree' "$W/e.out" \
    && ! grep -q '^── ' "$W/e.out" && E2En=yes
  gdrive "refs/heads/x $H1 refs/heads/x $Z40" "$W/deny.out"; gdeny=$?
  gdenyn=no; grep -qF "No green scripts/pregate-self-check.sh run is recorded for this tree ($TR)" "$W/deny.out" && gdenyn=yes
  gdrive - "$W/empty.out"; gempty="$(past "$W/empty.out")"
  PG="$G.vs/pregate-green/$(gx rev-list --max-parents=0 HEAD)"
  mkdir -p "$PG" && printf '#format pg1\ntree %s\n' "$TR" > "$PG/$TR" || exit 9
  gdrive "refs/heads/x $H1 refs/heads/x $Z40" "$W/allow.out"; gallow="$(past "$W/allow.out")"
  gdrive "refs/heads/x $H0 refs/heads/x $Z40" "$W/tree.out"; gtree=$?
  gtreen=no; grep -qF "delivers a tree that is not this work tree's HEAD tree" "$W/tree.out" && gtreen=yes
  echo stray > "$G/untracked.txt" || exit 9
  gdrive "refs/heads/x $H1 refs/heads/x $Z40" "$W/dirty.out"; gdirty=$?
  gdirtyn=no; grep -qF 'The work tree is not clean' "$W/dirty.out" && grep -qF 'untracked.txt' "$W/dirty.out" && gdirtyn=yes
  line="Gdeny=$gdeny Gdenyn=$gdenyn Gempty=$gempty Gallow=$gallow Gtree=$gtree Gtreen=$gtreen Gdirty=$gdirty Gdirtyn=$gdirtyn E2E=$E2E E2En=$E2En"
  echo "$line"
  want="Gdeny=1 Gdenyn=yes Gempty=0 Gallow=0 Gtree=1 Gtreen=yes Gdirty=1 Gdirtyn=yes E2E=1 E2En=yes"
  [ "$line" = "$want" ] && exit 0
  exit 1
fi
SC="${1:-scripts/pregate-self-check.sh}"
FX=core/fixtures/procsub-staged-refusal
for f in "$SC" "$FX/procsub-spell.awk" "$FX/procsub-spell-probe.diff" scripts/seed-verdict-store.sh; do [ -s "$f" ] || exit 9; done
W="$(mktemp -d)" || exit 9
trap '[ -n "$W" ] && rm -rf "$W"' EXIT
[ -d "$W" ] || exit 9
S="$W/self"
mkdir -p "$S/scripts" "$S/$FX" || exit 9
echo 0.0.1 > "$S/VERSION" || exit 9
cp "$SC" "$S/scripts/pregate-self-check.sh" || exit 9
cp "$FX/procsub-spell.awk" "$FX/procsub-spell-probe.diff" "$S/$FX/" || exit 9
cp scripts/seed-verdict-store.sh "$S/scripts/" || exit 9
# A clean root's section d runs through the self tree's seed-verdict-store.sh, which arms with the root hook's
# fxcount_arm. This stub, appended below each stub hook's exit, sets the four variables it exports and names a
# counted store nothing writes (the stub runner records nothing).
ARMFN='fxcount_arm() {
  local vk=000000000000
  FXCOUNT_RC=stub FXCOUNT_DIR=stub FXCOUNT_JUDGE=stub AI_DLC_VERDICT_STORE="$PWD/.stub-store/counted-$vk"; export FXCOUNT_RC FXCOUNT_DIR FXCOUNT_JUDGE AI_DLC_VERDICT_STORE
}'
# The pregate record's home is the hook's RECORD_HOME span (with READSET_VS, which it calls), read by the self-check out
# of the root's hook; each stub hook carries both spans, cut from the real hook, below its exit. Each root's records live
# in that root's own store, <root>.vs (drive and its siblings export it).
RHSPANS="$(sed -n '/^# READSET_VS_BEGIN$/,/^# READSET_VS_END$/p;/^# RECORD_HOME_BEGIN$/,/^# RECORD_HOME_END$/p' .githooks/pre-push)"
[ "$(grep -c '^rec_home() {' <<< "$RHSPANS")" = 1 ] || exit 9
seedgit() { # <root> -> commit everything in it; the root pushes through .githooks, as the distribution does (BL-1020)
  ( cd "$1" && unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE && git init -q . && git config core.hooksPath .githooks && git add -A \
    && git -c user.email=x@x -c user.name=x commit -q -m seed )
}
# Section d runs the fork-budget fixture through core/scripts/hermetic-run.sh with the counter armed by
# scripts/validate-fixture-invocations.sh --gen-rc. Every reaching root gets a stub of each: the judge stub
# writes a one-line rc; the runner stub prints what the real runner prints for one outcome. ok: the judge's
# pass line, exit 0. unarmed: exit 0 with NO judge line, which is what an unarmed run looks like (BL-1026).
# j3: the judge's J3 FAIL line, exit 1, as a seeded wrong invocations.decl row reads.
seed_counted() { # <root> <ok|unarmed|j3>
  local l
  mkdir -p "$1/core/scripts" "$1/scripts" || return 1
  printf '%s\n' '#!/usr/bin/env bash' '[ "${1:-}" = --gen-rc ] && { echo "# stub rc" > "$2/rc" && printf "%s\n" "$2/rc"; exit 0; }' 'exit 0' \
    > "$1/scripts/validate-fixture-invocations.sh" || return 1
  case "$2" in
    ok)      l='echo "validator-fork-budget: invocation budget ok: 1 start(s)"; exit 0' ;;
    unarmed) l='echo "PASS  validator-fork-budget (uncounted)"; exit 0' ;;
    j3)      l='echo "validator-fork-budget: FAIL (J3): row \"1 *\": measured 2, declared 1"; exit 1' ;;
    *)       return 1 ;;
  esac
  printf '%s\n' '#!/usr/bin/env bash' "$l" > "$1/core/scripts/hermetic-run.sh"
}
for v in A B C D U J; do
  T="$W/root$v"; mkdir -p "$T/.githooks" "$T/scripts" "$T/core/fixtures/validator-fork-budget" || exit 9
  echo 0.0.1 > "$T/VERSION"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/core/fixtures/validator-fork-budget/run.sh"
  # Section e's population (BL-1069): hookfx names the hook, hookfx-w wraps hookfx's run.sh, and the two the ruling
  # names; validator-fork-budget names neither. So a triggered run derives 3 + 1 wrapper.
  mkdir -p "$T/core/fixtures/hookfx" "$T/core/fixtures/hookfx-w" "$T/core/fixtures/backlog-real-ledger" "$T/core/fixtures/hermetic-runner" || exit 9
  printf '#!/usr/bin/env bash\nbash .githooks/pre-push </dev/null\n' > "$T/core/fixtures/hookfx/run.sh"
  printf '#!/usr/bin/env bash\nIMPL="$HERE/../hookfx/run.sh"\n' > "$T/core/fixtures/hookfx-w/run.sh"
  for n in backlog-real-ledger hermetic-runner; do printf '#!/usr/bin/env bash\nexit 0\n' > "$T/core/fixtures/$n/run.sh"; done
  case "$v" in U) seed_counted "$T" unarmed ;; J) seed_counted "$T" j3 ;; *) seed_counted "$T" ok ;; esac || exit 9
  for s in validate-enforcement-map.sh validate-shell-portability.sh; do printf '#!/usr/bin/env bash\nexit 0\n' > "$T/scripts/$s"; done
  {
    printf '#!/usr/bin/env bash\nfail=0\nstep() {\n  printf '"'"'\\n── %%s\\n'"'"' "$1"; shift\n  if "$@"; then printf '"'"'   PASS\\n'"'"'; else printf '"'"'   FAIL\\n'"'"'; fail=1; fi\n}\n'
    printf 'step "enforcement-map integrity" \\\n  bash scripts/validate-enforcement-map.sh\n'
    printf 'step "shell portability" \\\n  bash scripts/validate-shell-portability.sh\n'
    printf 'step "fixture git-env scrub" true\n'
    [ "$v" = B ] && printf 'step "seeded red step" false\n'
    [ "$v" = D ] && printf '# bin\000ary\n'
    printf 'step "fixture suite (12-way)" true\n'
    [ "$v" = C ] && printf 'step "fixture suite (12-way)" true\n'
    [ "$v" = D ] && printf 'step "below the pool" touch BELOW-RAN\n'
    printf 'exit $fail\n'
    printf '%s\n' "$ARMFN"
    printf '%s\n' "$RHSPANS"
  } > "$T/.githooks/pre-push"
  # No bash ever parses D's NUL-bearing text: bash versions differ on NUL in input, and this box has only 3.2 to probe.
  tr -d '\000' < "$T/.githooks/pre-push" > "$W/seed-$v.sh" || exit 9
  bash -n "$W/seed-$v.sh" || exit 9
  seedgit "$T" || exit 9
done
drive() { # <root> <out-file> -> the self-check's exit
  ( cd "$1" && AI_DLC_VERDICT_STORE="$1.vs" AI_DLC_PREGATE_ROOT="$1" bash "$S/scripts/pregate-self-check.sh" HEAD </dev/null >"$2" 2>&1 )
}
# BL-1020 worlds: copies of root A (committed hook = A's), each with a different hook-path state.
#   World A itself is driven from a cwd that is not the root (drive_away; it does NOT test the defensive relative-path join: the self-check cds to its root first). Hres: core.hooksPath -> an absolute dir whose hook differs from the
#   committed one (the resolved hook moved). Htree: hooksPath -> an absolute dir holding the committed bytes, the tree's
#   own hook then edited (the tree hook moved). Habs: no core.hooksPath (a push runs no hook).
gitin() { ( cd "$1" && shift && unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE && git "$@" ); }
for h in Hres Htree Hbehind Habs Wd; do cp -R "$W/rootA" "$W/root$h" || exit 9; done
# Wd (BL-1055): root A with one untracked file, so every section is green and the pregate record must NOT be written.
echo stray > "$W/rootWd/stray.txt" || exit 9
mkdir -p "$W/ext-res" "$W/ext-tree" || exit 9
{ cat "$W/rootA/.githooks/pre-push"; printf '# resolved hook moved\n'; } > "$W/ext-res/pre-push" || exit 9
cp "$W/rootA/.githooks/pre-push" "$W/ext-tree/pre-push" || exit 9
# Htree: the branch COMMITS a hook edit on top of the base tag (edited case). Hbehind: the base tag is a later commit
# carrying the updated hook, which the resolved hook also holds, while the tree stays at the old commit (behind case).
gitin "$W/rootHtree" tag base0 || exit 9
printf '# tree hook moved\n' >> "$W/rootHtree/.githooks/pre-push" || exit 9
gitin "$W/rootHtree" -c user.email=x@x -c user.name=x commit -q -am "branch edits the hook" || exit 9
{ cat "$W/rootA/.githooks/pre-push"; printf '# base hook updated\n'; } > "$W/ext-behind-pre-push" || exit 9
mkdir -p "$W/ext-behind" && cp "$W/ext-behind-pre-push" "$W/ext-behind/pre-push" || exit 9
gitin "$W/rootHbehind" checkout -q -b updbase || exit 9
cp "$W/ext-behind/pre-push" "$W/rootHbehind/.githooks/pre-push" || exit 9
gitin "$W/rootHbehind" -c user.email=x@x -c user.name=x commit -q -am "base updates the hook" || exit 9
gitin "$W/rootHbehind" tag newbase || exit 9
gitin "$W/rootHbehind" checkout -q --detach HEAD~1 || exit 9
gitin "$W/rootHbehind" config core.hooksPath "$W/ext-behind" || exit 9
gitin "$W/rootHres" config core.hooksPath "$W/ext-res" || exit 9
gitin "$W/rootHtree" config core.hooksPath "$W/ext-tree" || exit 9
gitin "$W/rootHabs" config --unset core.hooksPath || exit 9
# Member mode (BL-1082). Mt: a copy of Htree, so clean, committed, a fresh tree, and the push running ext-tree's base
# bytes; a record would be written there if the mode allowed one. Mr: root A on tag base0 plus one commit seeding a red
# step between PRESUITE_DONE=1 and the fixture-suite marker, the push again running ext-tree (A's bytes, no such step).
cp -R "$W/rootHtree" "$W/rootMt" || exit 9
cp -R "$W/rootA" "$W/rootMr" || exit 9
gitin "$W/rootMr" tag base0 || exit 9
awk '/^step "fixture suite/ && !d { print "PRESUITE_DONE=1"; print "step \"seeded post-presuite step\" false"; d = 1 } { print }' \
  "$W/rootA/.githooks/pre-push" > "$W/rootMr/.githooks/pre-push" || exit 9
grep -qxF 'step "seeded post-presuite step" false' "$W/rootMr/.githooks/pre-push" && bash -n "$W/rootMr/.githooks/pre-push" || exit 9
gitin "$W/rootMr" -c user.email=x@x -c user.name=x commit -q -am "branch adds a red step after PRESUITE_DONE" || exit 9
gitin "$W/rootMr" config core.hooksPath "$W/ext-tree" || exit 9
# Section e (BL-1069). Er: Mt, whose runner fails hookfx while the tree hook carries Mt's edit, so the hook edit breaks
# a hook-driving world. Ts: A on tag base0 plus a commit editing a script the hook names. Tn: the same with a script the
# hook does not name. A (no diff against HEAD) is the skip.
# Er's runner is committed BELOW base0, so its diff is the hook edit alone and section f skips it (no script changed).
cp -R "$W/rootA" "$W/rootEr" || exit 9
printf '%s\n' '#!/usr/bin/env bash' \
  'case "$1" in hookfx) grep -qxF "# tree hook moved" .githooks/pre-push && { echo "hookfx: FAIL: the hook edit broke this world"; exit 1; } ;; esac' \
  'echo "validator-fork-budget: invocation budget ok: 1 start(s)"; exit 0' > "$W/rootEr/core/scripts/hermetic-run.sh" || exit 9
gitin "$W/rootEr" -c user.email=x@x -c user.name=x commit -q -am "a runner that a hook edit breaks" && gitin "$W/rootEr" tag base0 || exit 9
printf '# tree hook moved\n' >> "$W/rootEr/.githooks/pre-push" || exit 9
gitin "$W/rootEr" -c user.email=x@x -c user.name=x commit -q -am "branch edits the hook" || exit 9
gitin "$W/rootEr" config core.hooksPath "$W/ext-tree" || exit 9
# A stub predictor for sections e and f: RUN is the root's pred.run, and the composer's parse (out/.dparse) its
# pred.dparse, so a world declares which units the push would run and which D/F routes their declarations carry.
PREDSTUB='#!/usr/bin/env bash
mkdir -p "$2/out" && cp "$1/pred.dparse" "$2/out/.dparse" || exit 2
echo "RUN $(grep -c . "$1/pred.run")"; sed "s/^/run /" "$1/pred.run"'
pred_stub() { # <root> <pred.dparse body> <unit>... -> the stub predictor and its two files, committed
  local t="$1" b="$2"; shift 2
  printf '%s\n' "$PREDSTUB" > "$t/scripts/predict-push-set.sh" && printf '%s' "$b" > "$t/pred.dparse" \
    && printf '%s\n' "$@" | sort > "$t/pred.run" || return 1
  gitin "$t" add scripts/predict-push-set.sh pred.dparse pred.run && gitin "$t" -c user.email=x@x -c user.name=x commit -q -m "a stub predictor"
}
# Ep: Mt plus a stub scripts/predict-push-set.sh that predicts hookfx alone, so section e runs that one and reuses the
# other three (Mt itself has no predictor and runs all four).
cp -R "$W/rootMt" "$W/rootEp" || exit 9
printf '%s\n' '#!/usr/bin/env bash' 'mkdir -p "$2/out" && printf "hookfx\tN\n" > "$2/out/.dparse" || exit 2' 'echo "RUN 1"' 'echo "run hookfx"' > "$W/rootEp/scripts/predict-push-set.sh" || exit 9
gitin "$W/rootEp" add scripts/predict-push-set.sh && gitin "$W/rootEp" -c user.email=x@x -c user.name=x commit -q -m "a predictor naming hookfx" || exit 9
# Mt and Mr (hook-editing member worlds the other sections read) get a predictor naming nothing, so their section e
# reuses all four and starts no seed; Er, with no predictor, is the world that says so and runs the whole set.
for t in Mt Mr; do
  printf '%s\n' '#!/usr/bin/env bash' 'echo "RUN 0"' > "$W/root$t/scripts/predict-push-set.sh" || exit 9
  gitin "$W/root$t" add scripts/predict-push-set.sh && gitin "$W/root$t" -c user.email=x@x -c user.name=x commit -q -m "a predictor naming nothing" || exit 9
done
# Ts and Tn carry a predictor below base0 naming all five fixtures, each declared with no D/F row, so section f reads a
# changed script that no RUN unit reaches.
for t in Ts Tn; do
  cp -R "$W/rootA" "$W/root$t" || exit 9
  pred_stub "$W/root$t" "$(printf '%s\tN\n' backlog-real-ledger hermetic-runner hookfx hookfx-w validator-fork-budget)
" backlog-real-ledger hermetic-runner hookfx hookfx-w validator-fork-budget && gitin "$W/root$t" tag base0 || exit 9
done
printf '# edited\n' >> "$W/rootTs/scripts/validate-shell-portability.sh" || exit 9
gitin "$W/rootTs" -c user.email=x@x -c user.name=x commit -q -am "edit a script the hook names" || exit 9
printf '#!/usr/bin/env bash\nexit 0\n' > "$W/rootTn/scripts/unnamed.sh" || exit 9
gitin "$W/rootTn" add scripts/unnamed.sh && gitin "$W/rootTn" -c user.email=x@x -c user.name=x commit -q -m "add a script no hook names" || exit 9
# Section f (BL-1122, BL-1129). Fs: A plus five fixtures and core/scripts/fx-sub.sh below base0, then an edit of
# fx-sub.sh. The RUN set is fdir (a D row core/scripts), ffile (an F row fx-sub.sh), fname (its run.sh names fx-sub.sh)
# and fnear (a D row core/scriptsx, an F row fx-sub.shx, run.sh naming xfx-sub.sh), sorted so fnear is last; fout
# reaches fx-sub.sh by all three routes but is not in RUN. The runner reds fname, so the section's own finding shows.
cp -R "$W/rootA" "$W/rootFs" || exit 9
for n in fdir ffile fname fnear fout; do mkdir -p "$W/rootFs/core/fixtures/$n" || exit 9; done
printf '#!/usr/bin/env bash\nexit 0\n' > "$W/rootFs/core/fixtures/fdir/run.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$W/rootFs/core/fixtures/ffile/run.sh"
printf '#!/usr/bin/env bash\nbash core/scripts/fx-sub.sh\n' > "$W/rootFs/core/fixtures/fname/run.sh"
printf '#!/usr/bin/env bash\nbash core/scripts/xfx-sub.sh\n' > "$W/rootFs/core/fixtures/fnear/run.sh"
printf '#!/usr/bin/env bash\nbash core/scripts/fx-sub.sh\n' > "$W/rootFs/core/fixtures/fout/run.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$W/rootFs/core/scripts/fx-sub.sh" || exit 9
printf '%s\n' '#!/usr/bin/env bash' \
  'case "$1" in fname) echo "fname: FAIL (J3): row \"3 *\": measured 2, declared 3"; exit 1 ;; esac' \
  'echo "validator-fork-budget: invocation budget ok: 1 start(s)"; exit 0' > "$W/rootFs/core/scripts/hermetic-run.sh" || exit 9
gitin "$W/rootFs" add -A && gitin "$W/rootFs" -c user.email=x@x -c user.name=x commit -q -m "five fixtures and fx-sub.sh" || exit 9
pred_stub "$W/rootFs" "$(printf 'fdir\tN\nfdir\tD\tcore/scripts\t1\tcore/scripts\nffile\tN\nffile\tF\tcore/scripts/fx-sub.sh\t0\tcore/scripts/fx-sub.sh\nfname\tN\nfnear\tN\nfnear\tD\tcore/scriptsx\t1\tcore/scriptsx\nfnear\tF\tcore/scripts/fx-sub.shx\t0\tcore/scripts/fx-sub.shx\nfout\tN\nfout\tD\tcore/scripts\t1\tcore/scripts\nfout\tF\tcore/scripts/fx-sub.sh\t1\tcore/scripts/fx-sub.sh')
" fdir ffile fname fnear && gitin "$W/rootFs" tag base0 || exit 9
printf '# edited\n' >> "$W/rootFs/core/scripts/fx-sub.sh" || exit 9
gitin "$W/rootFs" -c user.email=x@x -c user.name=x commit -q -am "edit fx-sub.sh" || exit 9
drive_away() { # <root> <out-file> -> the self-check's exit, run from a cwd other than the root
  ( cd "$W" && AI_DLC_VERDICT_STORE="$1.vs" AI_DLC_PREGATE_ROOT="$1" bash "$S/scripts/pregate-self-check.sh" HEAD </dev/null >"$2" 2>&1 )
}
drive "$W/rootHres" "$W/Hres.out"; hres=$?
drive_base() { # <root> <out-file> <base> -> the self-check's exit, with an explicit base ref
  ( cd "$1" && AI_DLC_VERDICT_STORE="$1.vs" AI_DLC_PREGATE_ROOT="$1" bash "$S/scripts/pregate-self-check.sh" "$3" </dev/null >"$2" 2>&1 )
}
drive_base "$W/rootHtree" "$W/Htree.out" base0; htree=$?
drive_base "$W/rootHbehind" "$W/Hbehind.out" newbase; hbehind=$?
drive "$W/rootHabs" "$W/Habs.out"; habs=$?
hresn=no; grep -qF "$W/ext-res/pre-push" "$W/Hres.out" && grep -qF "$W/rootHres/.githooks/pre-push" "$W/Hres.out" && grep -qF 'the resolved hook moved relative to HEAD:.githooks/pre-push' "$W/Hres.out" && hresn=yes
htreen=no; grep -qF "$W/ext-tree/pre-push" "$W/Htree.out" && grep -qF "$W/rootHtree/.githooks/pre-push" "$W/Htree.out" && grep -qF 'the tree hook moved relative to base0:.githooks/pre-push; the branch edited the hook, but the push will run '"$W/ext-tree/pre-push"', not the edit' "$W/Htree.out" && ! grep -qF 'rebase onto' "$W/Htree.out" && htreen=yes
hbehindn=no; grep -qF "$W/ext-behind/pre-push" "$W/Hbehind.out" && grep -qF 'the tree hook moved relative to newbase:.githooks/pre-push; the branch is behind: rebase onto newbase' "$W/Hbehind.out" && hbehindn=yes
habsn=no; grep -qF 'would run no pre-push hook' "$W/Habs.out" && habsn=yes
drive_away "$W/rootA" "$W/A.out"; a=$?
drive "$W/rootB" "$W/B.out"; b=$?
drive "$W/rootC" "$W/C.out"; c=$?
drive "$W/rootD" "$W/D.out"; d=$?
# D: refused (2), nothing below the marker ran, and the cause is named (the NUL byte).
dran=no; [ -e "$W/rootD/BELOW-RAN" ] && dran=yes
dnamed=no; grep -qF 'NUL byte' "$W/D.out" && dnamed=yes
# U: section d's counted run exits 0 with no judge pass line -> refused (2), the missing judgment named.
# J: section d's counted run reads a J3 FAIL -> a finding (1) under d:fork-budget, the J3 line shown.
drive "$W/rootU" "$W/U.out"; u=$?
drive "$W/rootJ" "$W/J.out"; j=$?
unamed=no; grep -qF 'the judge printed no pass line for validator-fork-budget' "$W/U.out" && unamed=yes
jnamed=no; grep -qF 'FAIL (J3): row "1 *"' "$W/J.out" && grep -qF 'FINDINGS in d:fork-budget' "$W/J.out" && jnamed=yes
# The pregate record (BL-1055): A (green, clean) writes one for its HEAD tree; B (a finding) and Wd (green, dirty) do not,
# and Wd names why.
rec_of() { # <root> -> yes when a pg1 record names the root's HEAD tree
  local t; t="$(gitin "$1" rev-parse 'HEAD^{tree}')" || { echo err; return; }
  [ "$(sed -n 1p "$1.vs/pregate-green/$(gitin "$1" rev-list --max-parents=0 HEAD)/$t" 2>/dev/null)" = '#format pg1' ] && echo yes || echo no
}
arec="$(rec_of "$W/rootA")"; brec="$(rec_of "$W/rootB")"
drive "$W/rootWd" "$W/Wd.out"; wd=$?
wdrec="$(rec_of "$W/rootWd")"
wdn=no; grep -qF 'NO RECORD written: the work tree was not clean' "$W/Wd.out" && wdn=yes
# BL-1064: A (clean) runs section d through seed-verdict-store.sh into the counted store its hook's fxcount_arm names;
# BL-1066: Wd (dirty) runs it there too, through --dirty-ok.
aseed=no; grep -qF "counted store $W/rootA/.stub-store/counted-000000000000 (clean tree" "$W/A.out" && aseed=yes
wdseed=no; grep -qF "counted store $W/rootWd/.stub-store/counted-000000000000 (dirty tree" "$W/Wd.out" && wdseed=yes
drive_member() { # <root> <out-file> <base> -> the self-check's exit under --member
  ( cd "$1" && AI_DLC_VERDICT_STORE="$1.vs" AI_DLC_PREGATE_ROOT="$1" bash "$S/scripts/pregate-self-check.sh" --member "$3" </dev/null >"$2" 2>&1 )
}
drive_member "$W/rootMt" "$W/Mt.out" base0; mt=$?
mtn=no; grep -qF "member mode: running the tree's own hook $W/rootMt/.githooks/pre-push (" "$W/Mt.out" \
  && grep -qF 'member mode wrote no pregate record' "$W/Mt.out" && mtn=yes
mtrec=no; [ -e "$W/rootMt.vs/pregate-green" ] && mtrec=yes
drive_member "$W/rootMr" "$W/Mr.out" base0; mr=$?
mrn=no; grep -qF 'FAIL: seeded post-presuite step' "$W/Mr.out" && grep -qF 'FINDINGS in a:hook-steps' "$W/Mr.out" && mrn=yes
# The edited-hook refusal is the member mode's carrier: Htree's refusal names --member.
htreem=no; grep -qF 'before READY run this script with --member' "$W/Htree.out" && htreem=yes
# Section e (BL-1069): A skips; Mt runs the derived 4 green; Er's hook edit reds hookfx -> 1 under e:hook-fixtures;
# Ts triggers on the named script and runs green; Tn's unnamed script skips.
eskip=no; grep -qE '^   SKIPPED: the diff from [0-9a-f]+ touches neither pre-push hook' "$W/A.out" && eskip=yes
# Section f (BL-1122, BL-1129): A's diff touches no script, so f skips.
fskip=no; grep -qE '^   SKIPPED: the diff from [0-9a-f]+ touches no core/scripts/\*\.sh or scripts/\*\.sh path$' "$W/A.out" && fskip=yes
mte=no; grep -qF '   triggered by: .githooks/pre-push ' "$W/Mt.out" && grep -qF '   4 fixture(s): 3 naming a hook or named by the ruling, 1 wrapper(s) in 2 round(s); ' "$W/Mt.out" \
  && grep -qF '   predict-push-set.sh: 4 of 4 hold a counted pass on their current key rows (reused); 0 to run' "$W/Mt.out" \
  && grep -qF '   ok: 0 fixture(s) run green' "$W/Mt.out" && mte=yes
# Ep: the predictor's subset runs (hookfx alone); Epall would read yes if the whole set ran, Epnone if none did.
drive_member "$W/rootEp" "$W/Ep.out" base0; ep=$?
epn=no; grep -qF '   predict-push-set.sh: 3 of 4 hold a counted pass on their current key rows (reused); 1 to run' "$W/Ep.out" \
  && grep -qxF '     hookfx rc=0' "$W/Ep.out" && grep -qF '   ok: 1 fixture(s) run green' "$W/Ep.out" && epn=yes
epall=no; grep -qxF '     hookfx-w rc=0' "$W/Ep.out" && epall=yes
epnone=no; grep -qE '^     [A-Za-z0-9._-]+ rc=[0-9]+$' "$W/Ep.out" || epnone=yes
drive_member "$W/rootEr" "$W/Er.out" base0; er=$?
ern=no; grep -qF '   PREDICTION UNAVAILABLE (no ' "$W/Er.out" && grep -qxF '     hookfx-w rc=0' "$W/Er.out" \
  && grep -qxF '   FAIL: red: hookfx' "$W/Er.out" && grep -qF 'hookfx: FAIL: the hook edit broke this world' "$W/Er.out" && grep -qF 'FINDINGS in e:hook-fixtures' "$W/Er.out" && ern=yes
drive_base "$W/rootTs" "$W/Ts.out" base0; ts=$?
tsn=no; grep -qxF '   triggered by: scripts/validate-shell-portability.sh ' "$W/Ts.out" && grep -qF '   ok: 4 fixture(s) run green' "$W/Ts.out" && tsn=yes
drive_base "$W/rootTn" "$W/Tn.out" base0; tn=$?
tnn=no; grep -qE '^   SKIPPED: the diff from [0-9a-f]+ touches neither pre-push hook' "$W/Tn.out" && tnn=yes
# Tn: f reads the added script and no RUN unit reaches it (the near-miss of Fs).
tnf=no; grep -qxF '   1 changed script(s): scripts/unnamed.sh ' "$W/Tn.out" \
  && grep -qF '   predict-push-set.sh: 0 of 5 RUN unit(s) reach a changed script (DIR 0, DECLFILE 0, NAME 0); 0 already run in section e; 0 to run' "$W/Tn.out" \
  && grep -qF '   ok: 0 fixture(s) run green' "$W/Tn.out" && tnf=yes
# Fs: f runs exactly the three RUN units that reach fx-sub.sh, one route each, and fname's red is its finding.
drive_base "$W/rootFs" "$W/Fs.out" base0; fs=$?
fsn=no; grep -qF '   predict-push-set.sh: 3 of 4 RUN unit(s) reach a changed script (DIR 1, DECLFILE 1, NAME 1); 0 already run in section e; 3 to run' "$W/Fs.out" \
  && grep -qxF '     fdir  DIR:core/scripts' "$W/Fs.out" && grep -qxF '     ffile  DECLFILE:core/scripts/fx-sub.sh' "$W/Fs.out" \
  && grep -qxF '     fname  NAME:fx-sub.sh' "$W/Fs.out" && grep -qxF '     fdir rc=0' "$W/Fs.out" && grep -qxF '     ffile rc=0' "$W/Fs.out" \
  && grep -qxF '     fname rc=1' "$W/Fs.out" && grep -qxF '   FAIL: red: fname' "$W/Fs.out" && grep -qF 'FINDINGS in f:reached-fixtures' "$W/Fs.out" && fsn=yes
fsnear=no; grep -qE '^     (fnear|fout)( |$)' "$W/Fs.out" && fsnear=yes
seed_refusal() { # <name> <hook body above the marker> -> sets RC
  local T="$W/ref-$1"; mkdir -p "$T/.githooks" "$T/core/fixtures/validator-fork-budget" || exit 9
  echo 0.0.1 > "$T/VERSION"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/core/fixtures/validator-fork-budget/run.sh"
  # A green section d, so a root that gets past section a reads its own exit.
  seed_counted "$T" ok || exit 9
  { printf '#!/usr/bin/env bash\nfail=0\n'; printf '%s\n' "$2"; printf 'step "fixture suite (12-way)" true\nexit $fail\n'; printf '%s\n' "$ARMFN"; } > "$T/.githooks/pre-push"
  seedgit "$T" || exit 9
  drive "$T" "$T/out"; RC=$?
}
STEPFN='step() { printf '"'"'\n── %s\n'"'"' "$1"; shift; if "$@"; then printf '"'"'   PASS\n'"'"'; else printf '"'"'   FAIL\n'"'"'; fail=1; fi; }'
np=99; ns=99; nv=99
seed_refusal noparse "$STEPFN
step \"broken\" true
if then"
np=$RC
seed_refusal nostep "$STEPFN
true"
ns=$RC
seed_refusal noverdict "$STEPFN
step \"one\" true
step \"dies mid-step\" exit 3
step \"never reached\" true"
nv=$RC
# World A's own output, printed ABOVE the summary only when A is not clean, so a caller can read why; the
# summary stays the last line.
[ "$a" = 0 ] || sed 's/^/A| /' "$W/A.out"
echo "A=$a B=$b C=$c noparse=$np nostep=$ns noverdict=$nv D=$d Dran=$dran Dnamed=$dnamed U=$u Unamed=$unamed J=$j Jnamed=$jnamed Hres=$hres Hresn=$hresn Htree=$htree Htreen=$htreen Habs=$habs Habsn=$habsn Hbehind=$hbehind Hbehindn=$hbehindn Arec=$arec Brec=$brec Wd=$wd Wdrec=$wdrec Wdn=$wdn Aseed=$aseed Wdseed=$wdseed Mt=$mt Mtn=$mtn Mtrec=$mtrec Mr=$mr Mrn=$mrn Htreem=$htreem Eskip=$eskip Mte=$mte Er=$er Ern=$ern Ts=$ts Tsn=$tsn Tn=$tn Tnn=$tnn Ep=$ep Epn=$epn Epall=$epall Epnone=$epnone Fskip=$fskip Tnf=$tnf Fs=$fs Fsn=$fsn Fsnear=$fsnear"
shared_ok=0; base_ok=0; e_ok=0
[ "$a" = 0 ] && [ "$aseed" = yes ] && [ "$arec" = yes ] && [ "$mt" = 0 ] && [ "$mtn" = yes ] && [ "$mtrec" = no ] \
  && [ "$eskip" = yes ] && [ "$mte" = yes ] && shared_ok=1
[ "$htreem" = yes ] && [ "$mr" = 1 ] && [ "$mrn" = yes ] \
  && [ "$wdseed" = yes ] && [ "$brec" = no ] && [ "$wd" = 0 ] && [ "$wdrec" = no ] && [ "$wdn" = yes ] && [ "$hres" = 2 ] && [ "$hresn" = yes ] && [ "$htree" = 2 ] && [ "$htreen" = yes ] && [ "$habs" = 2 ] && [ "$habsn" = yes ] && [ "$hbehind" = 2 ] && [ "$hbehindn" = yes ] && [ "$b" = 1 ] && grep -qF 'seeded red step' "$W/B.out" && [ "$c" = 2 ] \
  && [ "$np" = 2 ] && [ "$ns" = 2 ] && [ "$nv" = 2 ] \
  && [ "$d" = 2 ] && [ "$dran" = no ] && [ "$dnamed" = yes ] \
  && [ "$u" = 2 ] && [ "$unamed" = yes ] && [ "$j" = 1 ] && [ "$jnamed" = yes ] && base_ok=1
[ "$ep" = 0 ] && [ "$epn" = yes ] && [ "$epall" = no ] && [ "$epnone" = no ] \
  && [ "$er" = 1 ] && [ "$ern" = yes ] && [ "$ts" = 0 ] && [ "$tsn" = yes ] && [ "$tn" = 0 ] && [ "$tnn" = yes ] \
  && [ "$fskip" = yes ] && [ "$tnf" = yes ] && [ "$fs" = 1 ] && [ "$fsn" = yes ] && [ "$fsnear" = no ] && e_ok=1
[ "$shared_ok$base_ok$e_ok" = 111 ] && exit 0
exit 1
