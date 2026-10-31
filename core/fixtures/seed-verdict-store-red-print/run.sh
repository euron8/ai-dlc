#!/usr/bin/env bash
# seed-verdict-store-red-print -- drive scripts/seed-verdict-store.sh against stub fixtures and assert WHAT IT
# PRINTS when a fixture goes red (BL-882).
#
# THE DEFECT. The red branch printed `tail -5` of the fixture's output, so a J3 verdict row sitting above more than
# five trailing lines was never shown and the cause of a red seed was not derivable from the script's output.
#
# THE WORLD. One scratch git repo carries a stub .githooks/pre-push (a fxcount_arm that sets a counted store, which
# is all the subject extracts) and a stub core/scripts/hermetic-run.sh that emits three kinds of fixture output.
# ONE run of the subject covers all three, so a variant of the subject costs one run, whatever the arm count:
#   red-filter  a J3 row, then eight noise lines, then the runner trailer, exit 1 (the row is ABOVE five lines)
#   red-plain   eight lines naming no verdict token, then the trailer, exit 1 (nothing for the filter to match)
#   green       a line that must NOT be printed, exit 0 (the pass path stays unchanged)
#
# ARMS   a1 the J3 row is printed, the noise is not, and the trailer is printed
#        a2 with no verdict line the WHOLE output is printed (first line included)
#        a3 the pass path prints its `rc=0` line and none of the fixture's output
#
# MUTANTS (copies of the subject, each guarded by cmp -s so a sed that matched nothing cannot score)
#   m-tail5      the filtered print restored to `tail -5`            -- killed by a1
#   m-nofallback the whole-output fallback dropped                   -- killed by a2
# Both leave a3 untouched, which is their twin: the pass path must stay green under either.
# MUTANT-MATRIX m-tail5 decides=a1 twins=a3
# MUTANT-MATRIX m-nofallback decides=a2 twins=a3
# MUTANT-MATRIX-DYNAMIC score why=score() passes its first argument "$m" to mutant_killed; its two callers name m-tail5 and m-nofallback, each of which carries its own row above
# MUTANT-MATRIX-REMEASURE bash core/fixtures/seed-verdict-store-red-print/run.sh --matrix
#
# Usage: run.sh [--matrix]     Exit 0 = every arm and mutant hold, 1 = one regressed, 2 = fixture broken.
set -u
MODE=plain
case "${1:-}" in
  "") ;;
  --matrix) MODE=matrix ;;
  *) echo "seed-verdict-store-red-print: usage: run.sh [--matrix]" >&2; exit 2 ;;
esac

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
[ -f "$HERE/../lib/preamble.sh" ] || { echo "FIXTURE ERROR: lib/preamble.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/preamble.sh"
ROOT=""
for cand in "$HERE/../../.." "$HERE/../.."; do
  if [ -f "$cand/scripts/seed-verdict-store.sh" ]; then ROOT="$(cd "$cand" && pwd)"; break; fi
done
[ -n "$ROOT" ] || { echo "FIXTURE ERROR: no scripts/seed-verdict-store.sh above $HERE" >&2; exit 2; }
SUBJ="$ROOT/scripts/seed-verdict-store.sh"
echo "HERMETIC-CONSUMED scripts/seed-verdict-store.sh"

rc=0
ok()  { printf 'ok    %s\n' "$*"; }
bad() { printf 'FAIL  %s\n' "$*"; rc=1; }
MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
mkdir -p "$T/w/.githooks" "$T/w/core/scripts" "$T/tmp" "$T/v"
cat > "$T/w/.githooks/pre-push" <<EOF
fxcount_arm() {
  vk=aaaaaaaaaaaa
  AI_DLC_VERDICT_STORE="$T/store/counted-\$vk"; export AI_DLC_VERDICT_STORE
  mkdir -p "\$AI_DLC_VERDICT_STORE"
}
EOF
cat > "$T/w/core/scripts/hermetic-run.sh" <<'EOF'
#!/bin/bash
fx="$1"; n=1
case "$fx" in
  red-filter) echo "J3 mismatch: cell-x counted 9, declared 4"; while [ "$n" -le 8 ]; do echo "noise $n"; n=$((n + 1)); done; r=1 ;;
  red-plain)  while [ "$n" -le 8 ]; do echo "plain $n"; n=$((n + 1)); done; r=1 ;;
  green)      echo "okline-must-not-print"; r=0 ;;
  *) exit 2 ;;
esac
printf 'hermetic-run: %s: rc=%s sandbox_files=0 required_missing=0\n' "$fx" "$r"
exit "$r"
EOF
(
  cd "$T/w" || exit 2
  git init -q . && git add -A \
    && git -c core.hooksPath=/dev/null -c user.name=fx -c user.email=fx@example.invalid commit -q -m world
) >/dev/null 2>&1 || { echo "FIXTURE BROKEN: could not build the scratch repo" >&2; exit 2; }

# drive <variant file> <out file> -- one run of the subject over all three stub fixtures, from the scratch root.
drive() {
  ( cd "$T/w" && TMPDIR="$T/tmp" bash "$1" red-filter red-plain green > "$2" 2>&1; echo "exit=$?" >> "$2" )
}
has() { grep -qF -- "$2" "$1"; }
cell() { # <arm> <out file> -> 0 when the arm holds on that output
  case "$1" in
    a1) has "$2" "J3 mismatch: cell-x counted 9" && ! has "$2" "noise 3" && has "$2" "hermetic-run: red-filter: rc=1" ;;
    a2) has "$2" "plain 1" && has "$2" "plain 8" && has "$2" "hermetic-run: red-plain: rc=1" ;;
    a3) has "$2" "green rc=0" && ! has "$2" "okline-must-not-print" ;;
  esac
}

cp "$SUBJ" "$T/v/control.sh"
drive "$T/v/control.sh" "$T/control.out"
# The control must prove the subject RAN before any verdict is read: a harness that died prints neither line.
if has "$T/control.out" "counted store: $T/store/counted-aaaaaaaaaaaa" && has "$T/control.out" "red-filter rc=1" && has "$T/control.out" "exit=1"; then
  ok "control: the subject ran against the stub world and exited 1 on the reds"
else
  echo "FIXTURE BROKEN: the subject did not run against the scratch world"; sed 's/^/  | /' "$T/control.out"; exit 2
fi
B_a1=0; B_a2=0; B_a3=0
if cell a1 "$T/control.out"; then ok "a1 a red prints the J3 row above five trailing lines, not the noise, and the trailer"; B_a1=1
else bad "a1 the J3 row, the absence of noise, or the trailer is wrong"; sed 's/^/  | /' "$T/control.out"; fi
if cell a2 "$T/control.out"; then ok "a2 a red with no verdict line prints the whole output"; B_a2=1
else bad "a2 the whole-output fallback did not print"; sed 's/^/  | /' "$T/control.out"; fi
if cell a3 "$T/control.out"; then ok "a3 the pass path prints its rc line and none of the fixture's output"; B_a3=1
else bad "a3 the pass path changed"; sed 's/^/  | /' "$T/control.out"; fi

# mutate <name> <sed expr> -> builds $T/v/<name>.sh, refusing a mutation that applied to nothing or whose sed died.
mutate() {
  sed "$2" "$SUBJ" > "$T/v/$1.sh" || { bad "$1 -- DID NOT APPLY, sed died"; return 1; }
  if cmp -s "$SUBJ" "$T/v/$1.sh"; then bad "$1 -- the mutation matched nothing; its anchor moved"; return 1; fi
  drive "$T/v/$1.sh" "$T/$1.out"
  has "$T/$1.out" "counted store: $T/store/counted-aaaaaaaaaaaa" || { bad "$1 -- the mutant did not run"; return 1; }
}
# score <mutant> <deciding arm> <base flag> <others...>
score() {
  local m="$1" dec="$2" flag="$3" a g="" r=""
  shift 3
  if cell "$dec" "$T/$m.out"; then bad "$m SURVIVED -- $dec stayed green on it"; return; fi
  if ! cell a3 "$T/$m.out"; then bad "$m tripped its twin a3 -- the mutant is not confined"; return; fi
  mutant_killed "$flag" "$m" "$m scored by $dec and not by its twin a3"
  if [ "$MODE" = matrix ]; then
    for a in a1 a2 a3; do if cell "$a" "$T/$m.out"; then g="$g,$a"; else r="$r,$a"; fi; done
    printf 'MATRIX %s decides=%s twins=a3:GREEN green=%s red=%s\n' "$m" "$dec" "${g#,}" "${r#,}"
  fi
}
if mutate m-tail5 's#^.*grep -E "FAIL.*$#      tail -5 "$work/$fx.out"#'; then score m-tail5 a1 "$B_a1"; fi
if mutate m-nofallback 's#else cat "$work/$fx.out"; fi#else :; fi#'; then score m-nofallback a2 "$B_a2"; fi

[ "$rc" -eq 0 ] && echo "PASS  seed-verdict-store-red-print -- 3 arms, 2 mutants scored"
exit "$rc"
