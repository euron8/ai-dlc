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
#            and J (A, with section d's counted run reading a J3 FAIL) -> 1 under d:fork-budget (BL-1026)
#   exit 1   any of those differs
#   exit 9   the receipt cannot measure: a root could not be built (mktemp, git init, commit, a seed hook
#            that fails bash -n) or an input file is missing
#
# --gate <pre-push>: the BL-1055 gate world instead. Cuts the PREGATE_GATE span out of <pre-push> (preceded by the
#   one line that fills PUSH_LINES from stdin, followed by `echo PAST-THE-GATE`) and drives it from a two-commit repo G:
#   deny (an update line for HEAD, clean, no record) -> 1 naming the missing record; empty (no stdin, no record) -> past;
#   allow (record for HEAD's tree) -> past; tree (the line names HEAD~1, whose tree differs) -> 1 naming the tree;
#   dirty (record present, an untracked file) -> 1 naming the dirty tree. Then, unless --cut-only, the WHOLE <pre-push>
#   on the deny shape from a clean copy of G (E2E), which must stop at the gate. Prints one summary line; exit 0 when it
#   is the expected line, 1 when it differs, 9 when the world cannot be built.
set -uo pipefail
if [ "${1:-}" = --gate ]; then
  HK="${2:-}"; E2E_ON=1; [ "${3:-}" = --cut-only ] && E2E_ON=0
  [ -s "$HK" ] || exit 9
  case "$HK" in /*) : ;; *) HK="$PWD/$HK" ;; esac
  W="$(mktemp -d)" || exit 9
  trap '[ -n "$W" ] && rm -rf "$W"' EXIT
  G="$W/g"; mkdir -p "$G" || exit 9
  nb="$(grep -cxF '# PREGATE_GATE_BEGIN' "$HK")" || nb=0; ne="$(grep -cxF '# PREGATE_GATE_END' "$HK")" || ne=0
  [ "$nb" = 1 ] && [ "$ne" = 1 ] || { echo "gate receipt: PREGATE_GATE_BEGIN/END occur $nb/$ne times in $HK, expected 1/1" >&2; exit 9; }
  { printf '%s\n' '#!/usr/bin/env bash' 'PUSH_LINES="$(cat)"'
    sed -n '/^# PREGATE_GATE_BEGIN$/,/^# PREGATE_GATE_END$/p' "$HK"
    printf '%s\n' 'echo PAST-THE-GATE'; } > "$W/gate.sh" || exit 9
  bash -n "$W/gate.sh" || exit 9
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
  E2E=skip; E2En=skip
  if [ "$E2E_ON" = 1 ]; then
    cp -R "$G" "$W/e" || exit 9
    printf 'refs/heads/x %s refs/heads/x %s\n' "$H1" "$Z40" | ( cd "$W/e" && unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE \
      && AI_DLC_READSET_LIVE_TRACE=0 bash "$HK" origin file:///nowhere/x.git >"$W/e.out" 2>&1 ); E2E=$?
    E2En=no; grep -qF 'No green scripts/pregate-self-check.sh run is recorded for this tree' "$W/e.out" \
      && ! grep -q '^── ' "$W/e.out" && E2En=yes
  fi
  gdrive "refs/heads/x $H1 refs/heads/x $Z40" "$W/deny.out"; gdeny=$?
  gdenyn=no; grep -qF "No green scripts/pregate-self-check.sh run is recorded for this tree ($TR)" "$W/deny.out" && gdenyn=yes
  gdrive - "$W/empty.out"; gempty="$(past "$W/empty.out")"
  mkdir -p "$G/.git/ai-dlc-pregate-green" && printf '#format pg1\ntree %s\n' "$TR" > "$G/.git/ai-dlc-pregate-green/$TR" || exit 9
  gdrive "refs/heads/x $H1 refs/heads/x $Z40" "$W/allow.out"; gallow="$(past "$W/allow.out")"
  gdrive "refs/heads/x $H0 refs/heads/x $Z40" "$W/tree.out"; gtree=$?
  gtreen=no; grep -qF "delivers a tree that is not this work tree's HEAD tree" "$W/tree.out" && gtreen=yes
  echo stray > "$G/untracked.txt" || exit 9
  gdrive "refs/heads/x $H1 refs/heads/x $Z40" "$W/dirty.out"; gdirty=$?
  gdirtyn=no; grep -qF 'The work tree is not clean' "$W/dirty.out" && grep -qF 'untracked.txt' "$W/dirty.out" && gdirtyn=yes
  line="Gdeny=$gdeny Gdenyn=$gdenyn Gempty=$gempty Gallow=$gallow Gtree=$gtree Gtreen=$gtreen Gdirty=$gdirty Gdirtyn=$gdirtyn E2E=$E2E E2En=$E2En"
  echo "$line"
  want="Gdeny=1 Gdenyn=yes Gempty=0 Gallow=0 Gtree=1 Gtreen=yes Gdirty=1 Gdirtyn=yes"
  if [ "$E2E_ON" = 1 ]; then want="$want E2E=1 E2En=yes"; else want="$want E2E=skip E2En=skip"; fi
  [ "$line" = "$want" ] && exit 0
  exit 1
fi
SC="${1:-scripts/pregate-self-check.sh}"
FX=core/fixtures/procsub-staged-refusal
for f in "$SC" "$FX/procsub-spell.awk" "$FX/procsub-spell-probe.diff"; do [ -s "$f" ] || exit 9; done
W="$(mktemp -d)" || exit 9
trap '[ -n "$W" ] && rm -rf "$W"' EXIT
[ -d "$W" ] || exit 9
S="$W/self"
mkdir -p "$S/scripts" "$S/$FX" || exit 9
echo 0.0.1 > "$S/VERSION" || exit 9
cp "$SC" "$S/scripts/pregate-self-check.sh" || exit 9
cp "$FX/procsub-spell.awk" "$FX/procsub-spell-probe.diff" "$S/$FX/" || exit 9
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
  } > "$T/.githooks/pre-push"
  # No bash ever parses D's NUL-bearing text: bash versions differ on NUL in input, and this box has only 3.2 to probe.
  tr -d '\000' < "$T/.githooks/pre-push" > "$W/seed-$v.sh" || exit 9
  bash -n "$W/seed-$v.sh" || exit 9
  seedgit "$T" || exit 9
done
drive() { # <root> <out-file> -> the self-check's exit
  ( cd "$1" && AI_DLC_PREGATE_ROOT="$1" bash "$S/scripts/pregate-self-check.sh" HEAD </dev/null >"$2" 2>&1 )
}
# BL-1020 worlds: copies of root A (committed hook = A's), each with a different hook-path state.
#   Hcwd: A driven from a cwd that is not the root (it does NOT test the defensive relative-path join: the self-check cds to its root first). Hres: core.hooksPath -> an absolute dir whose hook differs from the
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
drive_away() { # <root> <out-file> -> the self-check's exit, run from a cwd other than the root
  ( cd "$W" && AI_DLC_PREGATE_ROOT="$1" bash "$S/scripts/pregate-self-check.sh" HEAD </dev/null >"$2" 2>&1 )
}
drive_away "$W/rootA" "$W/Hcwd.out"; hcwd=$?
drive "$W/rootHres" "$W/Hres.out"; hres=$?
drive_base() { # <root> <out-file> <base> -> the self-check's exit, with an explicit base ref
  ( cd "$1" && AI_DLC_PREGATE_ROOT="$1" bash "$S/scripts/pregate-self-check.sh" "$3" </dev/null >"$2" 2>&1 )
}
drive_base "$W/rootHtree" "$W/Htree.out" base0; htree=$?
drive_base "$W/rootHbehind" "$W/Hbehind.out" newbase; hbehind=$?
drive "$W/rootHabs" "$W/Habs.out"; habs=$?
hresn=no; grep -qF "$W/ext-res/pre-push" "$W/Hres.out" && grep -qF "$W/rootHres/.githooks/pre-push" "$W/Hres.out" && grep -qF 'the resolved hook moved relative to HEAD:.githooks/pre-push' "$W/Hres.out" && hresn=yes
htreen=no; grep -qF "$W/ext-tree/pre-push" "$W/Htree.out" && grep -qF "$W/rootHtree/.githooks/pre-push" "$W/Htree.out" && grep -qF 'the tree hook moved relative to base0:.githooks/pre-push; the branch edited the hook, but the push will run '"$W/ext-tree/pre-push"', not the edit' "$W/Htree.out" && ! grep -qF 'rebase onto' "$W/Htree.out" && htreen=yes
hbehindn=no; grep -qF "$W/ext-behind/pre-push" "$W/Hbehind.out" && grep -qF 'the tree hook moved relative to newbase:.githooks/pre-push; the branch is behind: rebase onto newbase' "$W/Hbehind.out" && hbehindn=yes
habsn=no; grep -qF 'would run no pre-push hook' "$W/Habs.out" && habsn=yes
drive "$W/rootA" "$W/A.out"; a=$?
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
  [ "$(sed -n 1p "$1/.git/ai-dlc-pregate-green/$t" 2>/dev/null)" = '#format pg1' ] && echo yes || echo no
}
arec="$(rec_of "$W/rootA")"; brec="$(rec_of "$W/rootB")"
drive "$W/rootWd" "$W/Wd.out"; wd=$?
wdrec="$(rec_of "$W/rootWd")"
wdn=no; grep -qF 'NO RECORD written: the work tree was not clean' "$W/Wd.out" && wdn=yes
seed_refusal() { # <name> <hook body above the marker> -> sets RC
  local T="$W/ref-$1"; mkdir -p "$T/.githooks" "$T/core/fixtures/validator-fork-budget" || exit 9
  echo 0.0.1 > "$T/VERSION"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/core/fixtures/validator-fork-budget/run.sh"
  # A green section d, so a mutant that lets one of these roots past section a reads its own exit (m1's noverdict -> 1).
  seed_counted "$T" ok || exit 9
  { printf '#!/usr/bin/env bash\nfail=0\n'; printf '%s\n' "$2"; printf 'step "fixture suite (12-way)" true\nexit $fail\n'; } > "$T/.githooks/pre-push"
  seedgit "$T" || exit 9
  drive "$T" "$T/out"; RC=$?
}
STEPFN='step() { printf '"'"'\n── %s\n'"'"' "$1"; shift; if "$@"; then printf '"'"'   PASS\n'"'"'; else printf '"'"'   FAIL\n'"'"'; fail=1; fi; }'
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
echo "A=$a B=$b C=$c noparse=$np nostep=$ns noverdict=$nv D=$d Dran=$dran Dnamed=$dnamed U=$u Unamed=$unamed J=$j Jnamed=$jnamed Hcwd=$hcwd Hres=$hres Hresn=$hresn Htree=$htree Htreen=$htreen Habs=$habs Habsn=$habsn Hbehind=$hbehind Hbehindn=$hbehindn Arec=$arec Brec=$brec Wd=$wd Wdrec=$wdrec Wdn=$wdn"
[ "$arec" = yes ] && [ "$brec" = no ] && [ "$wd" = 0 ] && [ "$wdrec" = no ] && [ "$wdn" = yes ] && [ "$a" = 0 ] && [ "$hcwd" = 0 ] && [ "$hres" = 2 ] && [ "$hresn" = yes ] && [ "$htree" = 2 ] && [ "$htreen" = yes ] && [ "$habs" = 2 ] && [ "$habsn" = yes ] && [ "$hbehind" = 2 ] && [ "$hbehindn" = yes ] && [ "$b" = 1 ] && grep -qF 'seeded red step' "$W/B.out" && [ "$c" = 2 ] \
  && [ "$np" = 2 ] && [ "$ns" = 2 ] && [ "$nv" = 2 ] \
  && [ "$d" = 2 ] && [ "$dran" = no ] && [ "$dnamed" = yes ] \
  && [ "$u" = 2 ] && [ "$unamed" = yes ] && [ "$j" = 1 ] && [ "$jnamed" = yes ] && exit 0
exit 1
