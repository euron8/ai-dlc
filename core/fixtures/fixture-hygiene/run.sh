#!/usr/bin/env bash
# fixture-hygiene -- drive the REAL scripts/validate-fixture-hygiene.sh against seeded probe projects and score one
# committed mutant per arm.
#
# THE SUBJECT is the shipping validator, copied byte-identical (cmp -s) with its sibling shard-stub resolver
# scripts/validate-fixture-invocations.sh into each probe project, which carries VERSION so the validator's root walk
# resolves to the PROBE, never to this repository; arm R asserts the corpus count it printed is the probe's. Nothing
# here re-implements a validator rule: every verdict is read off the validator's own output. This fixture never runs
# check mode on the real tree.
#
# THE WORLDS, each built once as a git repository (index only; the validator lists tracked files):
#   dirty  one offender per arm: H1 a `-d …/.git` skip, H2 a declared-tool skip, H3 a `sh -c` start, H5 a battery
#          with a mutation helper and no block, not on the allowlist.
#   clean  the near-miss of each, carrying the property a regression would key on: a `-d …/.git` that exits 2, a
#          declared tool that exits 2, `sh` inside an awk program, and a battery WITH a valid block.
# THE ARMS, each one read of a validator run:
#   D1 D2 D3 D5  the dirty run (rc 1) names exactly its arm's seeded line under `FAIL H<n>:`
#   C   the clean run is rc 0 with the OK line (the positive control: a run that scanned nothing cannot print it)
#   R   the clean run's OK line names the probe's corpus count (2 files), so the root walk resolved to the probe
#   DV  --derive over the dirty world prints exactly the battery's row
#   NM  a plain run executes no matrix-only cell (control: the per-push mutant drives ran)
# THE MUTANTS are copies of the dirty world with the validator's arm silenced, guarded by cmp -s and an exactly-once
# rewrite. Each is dead in every cell by construction: the validator's self-probe runs before the corpus and REFUSES
# (exit 2) on any silenced arm, so no arm of this fixture can hold under it -- what a mutant proves is that the
# validator's own self-probe catches the silenced arm, which is the defence a regression would meet first. Per push
# each runs its own D arm only, and the kill is scored on the refusal line naming that arm.
# MUTANT-MATRIX MH1 decides=D1,D2,D3,D5,C,R,DV twins=- why=the self-probe refuses the whole run when H1 is silenced
# MUTANT-MATRIX MH2 decides=D1,D2,D3,D5,C,R,DV twins=- why=the self-probe refuses the whole run when H2 is silenced
# MUTANT-MATRIX MH3 decides=D1,D2,D3,D5,C,R,DV twins=- why=the self-probe refuses the whole run when H3 is silenced
# MUTANT-MATRIX MH5 decides=D1,D2,D3,D5,C,R,DV twins=- why=the self-probe refuses the whole run when H5 is silenced
# MUTANT-MATRIX MH5N decides=D1,D2,D3,D5,C,R,DV twins=- why=the self-probe refuses the whole run when H5 reads a helper argument as a name
# MUTANT-MATRIX-REMEASURE bash core/fixtures/fixture-hygiene/run.sh --matrix
# Re-measure it whenever an arm or a mutant is added or changed.
#   MH1  H1's branch verdict made false        -> D1 reads the self-probe refusal naming H1
#   MH2  H2's branch verdict made false        -> D2 reads the self-probe refusal naming H2
#   MH3  H3's offender print removed           -> D3 reads the self-probe refusal naming H3
#   MH5  H5's FLOOR verdict made false         -> D5 reads the self-probe refusal naming H5
#   MH5N H5's join re-reads the 1st argument of the fixture's mutation helper as a mutant name (the extraction the
#        emission-site join removed) -> D5 reads the self-probe refusal naming H5 AND its got-only JOIN row on the
#        seeded world-letter call `ck_mut A mutant-x` (m5m:5), so the kill is the world-letter cell, not MH5's
#
# Usage: run.sh [--matrix]     Exit: 0 pass, 1 FAIL, 2 FIXTURE BROKEN.
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "fixture-hygiene: FIXTURE BROKEN: core/fixtures/lib/preamble.sh is absent" >&2; exit 2; }
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
MODE=plain; [ "${1:-}" = --matrix ] && MODE=matrix
ROOT=""; d="$HERE"
while [ -n "$d" ] && [ "$d" != / ]; do
  [ -f "$d/scripts/validate-fixture-hygiene.sh" ] && [ -f "$d/scripts/validate-fixture-invocations.sh" ] && { ROOT="$d"; break; }
  d="$(dirname "$d")"
done
[ -n "$ROOT" ] || { echo "FIXTURE ERROR: no scripts/validate-fixture-hygiene.sh walking up from $HERE" >&2; exit 2; }

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT
FAILS=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; FAILS=$((FAILS + 1)); }
. "$ROOT/core/fixtures/lib/mutant.sh"
VREL=scripts/validate-fixture-hygiene.sh
IREL=scripts/validate-fixture-invocations.sh
g() { env -u GIT_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE -u GIT_OBJECT_DIRECTORY git -c core.hooksPath=/dev/null "$@"; }

# --- the worlds -------------------------------------------------------------------------------------------------
put() { mkdir -p "$(dirname "$1")" && cat > "$1"; }
mk_world() { # <dir> <dirty|clean>
  local w="$1"
  mkdir -p "$w/scripts" && : > "$w/VERSION" && cp -p "$ROOT/$VREL" "$ROOT/$IREL" "$w/scripts/" || return 1
  cmp -s "$ROOT/$VREL" "$w/$VREL" && cmp -s "$ROOT/$IREL" "$w/$IREL" || return 1
  printf 'jq\n' > "$w/tools.tmp"
  if [ "$2" = dirty ]; then
    put "$w/core/fixtures/fa/run.sh" <<'EOF'
#!/usr/bin/env bash
if [ ! -d "$R/.git" ]; then
  echo "SKIP no history"
  exit 0
fi
command -v jq >/dev/null 2>&1 || { echo "SKIP no jq"; exit 0; }
sh -c 'exit 0' & p=$!
EOF
    put "$w/core/fixtures/fb/run.sh" <<'EOF'
#!/usr/bin/env bash
mkmut() { :; }
EOF
    cp "$w/tools.tmp" "$w/core/fixtures/fa/tools.decl"
  else
    put "$w/core/fixtures/fa/run.sh" <<'EOF'
#!/usr/bin/env bash
if [ ! -d "$R/.git" ]; then
  echo "FIXTURE BROKEN: no history; exit 0 would lie"
  exit 2
fi
command -v jq >/dev/null 2>&1 || { echo "FIXTURE BROKEN: no jq"; exit 2; }
awk '{ if (sh != "") print sh }' f
EOF
    put "$w/core/fixtures/fb/run.sh" <<'EOF'
#!/usr/bin/env bash
# MUTANT-MATRIX MA decides=R1.cellA twins=R2
# MUTANT-MATRIX-REMEASURE bash core/fixtures/fb/run.sh --matrix
mkmut() { :; }
mkmut MA x
EOF
    cp "$w/tools.tmp" "$w/core/fixtures/fa/tools.decl"
  fi
  rm -f "$w/tools.tmp"
  g init -q "$w" && g -C "$w" add -A core >/dev/null 2>&1
}
mk_world "$WORK/w-dirty" dirty && mk_world "$WORK/w-clean" clean \
  || { echo "FIXTURE BROKEN: could not build the probe worlds byte-identical" >&2; exit 2; }

# mk_mutant <name> <old> <new>: the dirty world copied whole, the validator changed exactly once.
mk_mutant() {
  local m="$WORK/mut-$1"
  cp -R "$WORK/w-dirty" "$m" || return 1
  OLD="$2" NEW="$3" awk '{ i = index($0, ENVIRON["OLD"]); if (i > 0) { $0 = substr($0, 1, i - 1) ENVIRON["NEW"] substr($0, i + length(ENVIRON["OLD"])); n++ } print }
    END { if (n != 1) exit 3 }' "$WORK/w-dirty/$VREL" > "$m/$VREL.new" || return 1
  mv "$m/$VREL.new" "$m/$VREL" || return 1
  cmp -s "$WORK/w-dirty/$VREL" "$m/$VREL" && return 1
  [ -f "$m/$IREL" ] || return 1
}
mk_mutant MH1 'if (fails_to_exit0(i, st, qe, neg, pre0)) print "H1\t"' 'if (0) print "H1\t"' \
  || { echo "FIXTURE BROKEN: mutant MH1 DID NOT APPLY" >&2; exit 2; }
mk_mutant MH2 'if (fails_to_exit0(i, st, WEND, neg, pre0)) print "H2\t"' 'if (0) print "H2\t"' \
  || { echo "FIXTURE BROKEN: mutant MH2 DID NOT APPLY" >&2; exit 2; }
mk_mutant MH3 'print "H3\t" REL ":" i "\t" trim(O[i])' 'H3N++' \
  || { echo "FIXTURE BROKEN: mutant MH3 DID NOT APPLY" >&2; exit 2; }
mk_mutant MH5 'if (!(f in LISTED)) print "FLOOR\t"' 'if (0) print "FLOOR\t"' \
  || { echo "FIXTURE BROKEN: mutant MH5 DID NOT APPLY" >&2; exit 2; }
mk_mutant MH5N 'if (ISRUN && !HDL[i] && O[i] ~' 'if (S1[FX] != "" && match(s, "(^|[[:space:];&|(!])" S1[FX] "[[:space:]]+")) { k = literal(wordat(O[i], RSTART + RLENGTH)); if (k != "") print "K\t" FX "\t" REL ":" i "\t" k }
    if (ISRUN && !HDL[i] && O[i] ~' \
  || { echo "FIXTURE BROKEN: mutant MH5N DID NOT APPLY" >&2; exit 2; }

# --- one validator run per distinct state -------------------------------------------------------------------------
drive() { # <tag> <world dir> [--derive]
  ( cd "$2" && unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE && bash "$2/$VREL" ${3:+"$3"} ) > "$WORK/c.$1.out" 2> "$WORK/c.$1.err"
  echo $? > "$WORK/c.$1.rc"
}
has()  { grep -qF -- "$2" "$WORK/c.$1.out" "$WORK/c.$1.err"; }
rcis() { [ "$(cat "$WORK/c.$1.rc" 2>/dev/null)" = "$2" ]; }
# section <tag> <arm>: the lines under `FAIL <arm>:` up to the next unindented line
section() { awk -v A="FAIL $2:" '$0 == A { on = 1; next } on && /^    / { print; next } on { exit }' "$WORK/c.$1.out"; }
verdict() { # <arm> <tag>
  local t="$2"
  case "$1" in
    D1) rcis "$t" 1 && [ "$(section "$t" H1)" = '    core/fixtures/fa/run.sh:2: if [ ! -d "$R/.git" ]; then' ] ;;
    D2) rcis "$t" 1 && [ "$(section "$t" H2)" = '    core/fixtures/fa/run.sh:6: command -v jq >/dev/null 2>&1 || { echo "SKIP no jq"; exit 0; }' ] ;;
    D3) rcis "$t" 1 && [ "$(section "$t" H3)" = "    core/fixtures/fa/run.sh:7: sh -c 'exit 0' & p=\$!" ] ;;
    D5) rcis "$t" 1 && [ "$(section "$t" H5)" = '    FLOOR fb: S1 mkmut()' ] ;;
    C)  rcis "$t" 0 && has "$t" 'OK: validate-fixture-hygiene -- self-probe fired both ways' ;;
    R)  rcis "$t" 0 && has "$t" '; 2 fixture .sh scanned;' ;;
    DV) rcis "$t" 0 && [ "$(cat "$WORK/c.$t.out")" = "$(printf 'fb\tno MUTANT-MATRIX block; floor: S1 mkmut()')" ] ;;
    *) return 1 ;;
  esac
}
REFUSAL() { printf 'self-probe %s: FAIL' "$1"; }

if [ "$MODE" = matrix ]; then
  : > "$WORK/mx.ran"
  for m in MH1 MH2 MH3 MH5 MH5N; do
    cp -R "$WORK/w-clean" "$WORK/mclean-$m" && cp -p "$WORK/mut-$m/$VREL" "$WORK/mclean-$m/$VREL" \
      || { echo "FIXTURE BROKEN: could not build the clean world for $m" >&2; exit 2; }
    drive "$m.d" "$WORK/mut-$m" & drive "$m.v" "$WORK/mut-$m" --derive & drive "$m.c" "$WORK/mclean-$m" &
  done; wait
  for m in MH1 MH2 MH3 MH5 MH5N; do
    dec=""; tw=""
    for a in D1 D2 D3 D5; do if verdict "$a" "$m.d"; then tw="$tw,$a"; else dec="$dec,$a"; fi; done
    for a in C R; do if verdict "$a" "$m.c"; then tw="$tw,$a"; else dec="$dec,$a"; fi; done
    if verdict DV "$m.v"; then tw="$tw,DV"; else dec="$dec,DV"; fi
    printf 'MATRIX %s decides=%s twins=%s\n' "$m" "${dec#,}" "${tw#,}"
  done
  exit 0
fi

drive dirty "$WORK/w-dirty" & drive clean "$WORK/w-clean" & drive derive "$WORK/w-dirty" --derive &
for m in MH1 MH2 MH3 MH5 MH5N; do drive "$m" "$WORK/mut-$m" & done
wait
B_DIRTY=0
for a in D1 D2 D3 D5; do
  if verdict "$a" dirty; then ok "$a the dirty world names exactly its seeded line"; : > "$WORK/base.$a"
  else bad "$a fails on the unmutated validator (rc $(cat "$WORK/c.dirty.rc")): $(head -c 800 "$WORK/c.dirty.out" | tr '\n' ' ')"; fi
done
verdict C clean && ok "C the clean world (every near-miss) is rc 0 with the OK line" \
  || bad "C the clean world is not clean (rc $(cat "$WORK/c.clean.rc")): $(head -c 800 "$WORK/c.clean.out" | tr '\n' ' ')"
verdict R clean && ok "R the validator resolved the PROBE root (2 fixture .sh scanned, not this repository's corpus)" \
  || bad "R the clean run did not report the probe's 2-file corpus"
verdict DV derive && ok "DV --derive prints exactly the unblocked battery's row" \
  || bad "DV --derive printed: $(head -c 400 "$WORK/c.derive.out" | tr '\n' '|')"
if [ -e "$WORK/base.D1" ] && verdict C clean; then
  echo "HERMETIC-CONSUMED $VREL"
  echo "HERMETIC-CONSUMED $IREL"
fi

# --- the mutants, each on its deciding arm --------------------------------------------------------------------------
score() { # <mutant> <arm> <arm label in the self-probe>; 0 when the arm fails for its reason
  if verdict "$2" "$1"; then bad "$1 SURVIVED: arm $2 still holds under it"; return 1; fi
  rcis "$1" 2 && has "$1" "$(REFUSAL "$3")" || { bad "$1: arm $2 fails under it, but not by the self-probe naming $3 (rc $(cat "$WORK/c.$1.rc"))"; return 1; }
}
flag() { [ -e "$WORK/base.$1" ] && echo 1 || echo 0; }
score MH1 D1 H1 && mutant_killed "$(flag D1)" MH1 "MH1: arm D1 fails by the self-probe refusal naming H1"
score MH2 D2 H2 && mutant_killed "$(flag D2)" MH2 "MH2: arm D2 fails by the self-probe refusal naming H2"
score MH3 D3 H3 && mutant_killed "$(flag D3)" MH3 "MH3: arm D3 fails by the self-probe refusal naming H3"
score MH5 D5 H5 && mutant_killed "$(flag D5)" MH5 "MH5: arm D5 fails by the self-probe refusal naming H5"
# MH5N must die on the world-letter cell itself: the refusal alone is MH5's signal too.
WL_ROW="$(printf 'got-only  JOIN\tcore/fixtures/m5m/run.sh:5')"
if score MH5N D5 H5; then
  if has MH5N "$WL_ROW"; then mutant_killed "$(flag D5)" MH5N "MH5N: arm D5 fails by the self-probe refusal naming H5, on the world-letter JOIN row m5m:5"
  else bad "MH5N: the self-probe refused, but not on the world-letter JOIN row m5m:5"; fi
fi

if [ ! -e "$WORK/mx.ran" ] && [ -e "$WORK/c.MH5.out" ] && [ -e "$WORK/c.MH1.out" ]; then ok "NM a plain run executes no matrix-only cell, and the per-push mutant drives ran"
else bad "NM a plain run reached the matrix, or its per-push mutant drives did not run"; fi

[ "$FAILS" = 0 ] || { echo "fixture-hygiene: $FAILS FAILED"; exit 1; }
echo "fixture-hygiene: PASS"
exit 0
