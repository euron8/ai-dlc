#!/bin/bash
# BL-643 receipt. usage: receipt-bl643.sh [<pregate-self-check.sh>]; run from the repo root.
#   Seeds throwaway mini ROOTs (a stub hook, stub validators, a stub fork-budget fixture) and drives the
#   self-check against each in seconds. The self-check and its spelling grammar are copied from the tree
#   this runs in; nothing is read from another ref.
#   exit 0   A (today's hook shape) -> 0; B (an added failing above-pool step) -> 1 naming it; C (the
#            fixture-suite marker twice) -> 2; and an unparseable prefix, a prefix with no step, and a
#            step that prints no verdict each -> 2; and D (A plus a NUL byte above the marker and a step
#            below it that touches BELOW-RAN) -> 2 with BELOW-RAN absent and the NUL named (the fix is
#            present)
#   exit 1   any of those differs
#   exit 9   the receipt cannot measure: a root could not be built (mktemp, git init, commit, a seed hook
#            that fails bash -n) or an input file is missing
set -uo pipefail
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
seedgit() { # <root> -> commit everything in it
  ( cd "$1" && unset GIT_DIR GIT_INDEX_FILE GIT_WORK_TREE && git init -q . && git add -A \
    && git -c user.email=x@x -c user.name=x commit -q -m seed )
}
for v in A B C D; do
  T="$W/root$v"; mkdir -p "$T/.githooks" "$T/scripts" "$T/core/fixtures/validator-fork-budget" || exit 9
  echo 0.0.1 > "$T/VERSION"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/core/fixtures/validator-fork-budget/run.sh"
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
drive "$W/rootA" "$W/A.out"; a=$?
drive "$W/rootB" "$W/B.out"; b=$?
drive "$W/rootC" "$W/C.out"; c=$?
drive "$W/rootD" "$W/D.out"; d=$?
# D: refused (2), nothing below the marker ran, and the cause is named (the NUL byte).
dran=no; [ -e "$W/rootD/BELOW-RAN" ] && dran=yes
dnamed=no; grep -qF 'NUL byte' "$W/D.out" && dnamed=yes
seed_refusal() { # <name> <hook body above the marker> -> sets RC
  local T="$W/ref-$1"; mkdir -p "$T/.githooks" "$T/core/fixtures/validator-fork-budget" || exit 9
  echo 0.0.1 > "$T/VERSION"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$T/core/fixtures/validator-fork-budget/run.sh"
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
echo "A=$a B=$b C=$c noparse=$np nostep=$ns noverdict=$nv D=$d Dran=$dran Dnamed=$dnamed"
[ "$a" = 0 ] && [ "$b" = 1 ] && grep -qF 'seeded red step' "$W/B.out" && [ "$c" = 2 ] \
  && [ "$np" = 2 ] && [ "$ns" = 2 ] && [ "$nv" = 2 ] \
  && [ "$d" = 2 ] && [ "$dran" = no ] && [ "$dnamed" = yes ] && exit 0
exit 1
