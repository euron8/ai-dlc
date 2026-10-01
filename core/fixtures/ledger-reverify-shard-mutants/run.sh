#!/usr/bin/env bash
# ledger-reverify-shard-mutants — the mutation battery behind ledger-reverify's SHARD PROTOCOL
# (BL-406): the coverage join J0, the entered-set join J1, the stderr scan J2, the unit floor,
# the shared-control count, the drivers' shard-named-verdict check and the EXIT trap's LR_DONE
# guard. DISTRIBUTION-ONLY.
#
# Usage: run.sh
# Exit:  0 every mutant is KILLED by exactly the arm it targets; 1 a mutant survived or killed an
#        arm it does not own; 2 the harness is broken and no verdict is readable.
#
# THE SUBJECT IS RE-DEALT SMALL, IN EVERY COPY. A mutant driven through a real shard costs ~120s.
# Each copy is a tree holding core/ (minus every other fixture), the fixture and its `-b` driver;
# its deal is rewritten to SHARDS="a b" over four cheap units and every other unit's definition is
# stripped by its `} # end lr_unit_<slug>` marker. The protocol code under test is untouched by
# that preparation, so the control -- the prepared copy with no mutation -- is the exact control
# for every mutant below, and a run costs the seed plus the baseline engine call, ~6s.
#
# EACH EDIT IS REFUSED UNLESS ITS ANCHOR OCCURS EXACTLY ONCE and the copy then differs (`cmp -s`):
# a mutation that matched nothing is a mutant that never existed, and it reads as a survivor.
#
# A KILL IS THE EXACT SET OF RED PROTOCOL ARMS. The subject prints `  FAIL  [J1]` and the like;
# any OTHER FAIL line in a mutant's output means the mutation broke an assertion rather than the
# protocol, and is scored as entanglement. A J0 kill is an exit 2 naming `[J0]` before any seed.
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR 2>/dev/null || true

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$HERE"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/scripts/install.sh" ]; do ROOT="$(dirname "$ROOT")"; done
[ -f "$ROOT/scripts/install.sh" ] \
  || { echo "FIXTURE ERROR: no scripts/install.sh above $HERE — this battery is distribution-only" >&2; exit 2; }
FX="core/fixtures/ledger-reverify"
for f in "$FX/run.sh" "$FX/seed.sh" "$FX-b/run.sh" core/fixtures/lib/preamble.sh \
         core/skills/ai-dlc-update/reconcile/ledger-reverify.sh; do
  [ -f "$ROOT/$f" ] || { echo "FIXTURE ERROR: missing $ROOT/$f" >&2; exit 2; }
done
command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 not on PATH" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
case "$WORK" in /tmp/*|/private/*|/var/folders/*) trap 'rm -rf "$WORK"' EXIT ;; esac

echo "ledger-reverify-shard-mutants:"
fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# The four units the prepared copy keeps. Each asserts something on the shared seed and costs
# well under a second; backslash_anchor is the one that calls a hoisted helper (detail_lacks).
KEEP_A="nonid_manual backslash_anchor"
KEEP_B="name_signal short_id"

# mktree <dir>: core/ minus the other fixtures, plus the fixture, its lib and its `-b` driver.
mktree() {
  mkdir -p "$1/core/fixtures" || return 1
  for e in "$ROOT"/core/*; do
    [ "$(basename "$e")" = fixtures ] && continue
    cp -R "$e" "$1/core/" || return 1
  done
  cp -R "$ROOT/core/fixtures/lib" "$ROOT/$FX" "$ROOT/$FX-b" "$1/core/fixtures/" || return 1
  [ -f "$1/$FX/run.sh" ] && [ -f "$1/$FX-b/run.sh" ] && [ -f "$1/core/skills/ai-dlc-update/reconcile/lib.sh" ]
}
# prep <run.sh>: SHARDS="a b" over the four kept units, every other unit definition stripped.
prep() {
  KEEP_A="$KEEP_A" KEEP_B="$KEEP_B" python3 - "$1" <<'PY' || return 1
import os, re, sys
p = sys.argv[1]; L = open(p).read().split('\n')
keep = set(os.environ["KEEP_A"].split() + os.environ["KEEP_B"].split())
def once(pat):
    hits = [i for i, l in enumerate(L) if re.match(pat, l)]
    if len(hits) != 1:
        sys.stderr.write("prep: %s occurs %d times\n" % (pat, len(hits))); sys.exit(1)
    return hits[0]
L[once(r'^SHARDS="[a-z ]+"$')] = 'SHARDS="a b"'
L[once(r'^UNITS_a="')] = 'UNITS_a="%s"' % os.environ["KEEP_A"]
L[once(r'^UNITS_b="')] = 'UNITS_b="%s"' % os.environ["KEEP_B"]
drop = set([once(r'^UNITS_c="'), once(r'^UNITS_d="')])
out, skip, seen = [], None, set()
for i, l in enumerate(L):
    if i in drop: continue
    m = re.match(r'^lr_unit_([a-z0-9_]+)\(\) \{$', l)
    if m and skip is None and m.group(1) not in keep:
        skip = m.group(1); continue
    if m: seen.add(m.group(1))
    if skip is not None:
        if l == '} # end lr_unit_%s' % skip: skip = None
        continue
    out.append(l)
if skip is not None or seen != keep:
    sys.stderr.write("prep: unit strip incomplete (open=%s kept=%s)\n" % (skip, sorted(seen))); sys.exit(1)
open(p, 'w').write('\n'.join(out))
PY
}
# mut <file> <old> <new>: exactly-once replacement. 0 applied, 1 not.
mut() {
  cp "$1" "$1.orig" || return 1
  OLD="$2" NEW="$3" python3 - "$1" <<'PY' || { rm -f "$1.orig"; return 1; }
import os, sys
p = sys.argv[1]; s = open(p).read(); o = os.environ["OLD"]
if s.count(o) != 1:
    sys.stderr.write("anchor occurs %d times\n" % s.count(o)); sys.exit(1)
open(p, "w").write(s.replace(o, os.environ["NEW"]))
PY
  if cmp -s "$1" "$1.orig"; then rm -f "$1.orig"; return 1; fi
  rm -f "$1.orig"
}
N=0
newtree() {  # -> path on stdout of a prepared tree, empty on failure
  local t
  N=$((N+1)); t="$WORK/t-$N"
  mktree "$t" && prep "$t/$FX/run.sh" && bash -n "$t/$FX/run.sh" && printf '%s' "$t"
}
drive() {  # <tree> <shard> <out> -> rc. From the tree's root, as the pre-push runner drives it.
  local d="$1/$FX"; [ "$2" = a ] || d="$d-$2"
  ( cd "$1" && bash "$d/run.sh" ) > "$3" 2>&1
}
red_set() { sed -n 's/^  FAIL  \(\[[A-Za-z0-9]*\]\).*/\1/p' "$1" | sort -u | tr '\n' ' ' | sed 's/ $//'; }
other_fails() { grep '^  FAIL  ' "$1" | grep -cvE '^  FAIL  \[(J0|J1|J2|floor|shared)\]'; }

# --- CONTROL: the prepared, unmutated copy, both shards. Positive conjuncts: the J0 line, the
# --- exact PASS line, and an assertion count above the shared six.
T0="$(newtree)"; [ -n "$T0" ] || { echo "FIXTURE ERROR: could not build or prepare the control tree" >&2; exit 2; }
for g in a b; do
  drive "$T0" "$g" "$WORK/c-$g.out"; rc=$?
  n="$(sed -n "s/^PASS: all \([0-9]*\) assertions correct in shard '$g' of 'a b'\.\$/\1/p" "$WORK/c-$g.out")"
  if [ "$rc" -eq 0 ] && [ "${n:-0}" -gt 6 ] && grep -q "^  ok    \[J0\] coverage join: 4 units .* shard '$g' runs" "$WORK/c-$g.out" \
     && [ "$(red_set "$WORK/c-$g.out")" = "" ]; then
    ok "[C-$g] prepared copy, shard $g: J0 joined 4 units, PASS with $n assertions"
  else
    echo "FIXTURE BROKEN: the prepared control did not pass in shard $g (rc=$rc) — no mutant verdict is readable" >&2
    sed -n '1,30p' "$WORK/c-$g.out" >&2; exit 2
  fi
done

# run_kill <id> <shard> <want red set> <tree-or-empty>
run_kill() {
  local id="$1" g="$2" want="$3" t="$4" o rc got of
  [ -n "$t" ] || { bad "[$id] DID NOT APPLY (tree build, prep or anchor failed)"; return; }
  o="$WORK/$id.out"; drive "$t" "$g" "$o"; rc=$?
  if ! grep -qE "^(PASS|FAIL): .* in shard '$g' of 'a b'\.\$" "$o"; then
    bad "[$id] the fixture produced no verdict line (rc=$rc) — a harness failure, not a kill"; sed -n '1,15p' "$o" | sed 's/^/          | /'; return
  fi
  got="$(red_set "$o")"; of="$(other_fails "$o")" || of=0
  if [ "$rc" -eq 1 ] && [ "$got" = "$want" ] && [ "$of" -eq 0 ]; then
    ok "[$id] KILLED by exactly {$want}"
  elif [ -z "$got" ]; then
    bad "[$id] SURVIVED (rc=$rc)"
  else
    bad "[$id] red {$got} plus $of non-protocol FAIL line(s), declared {$want} (rc=$rc)"
  fi
}
# run_j0 <id> <tree-or-empty> <message fragment>: J0 refuses with exit 2, before any seed.
run_j0() {
  local id="$1" t="$2" frag="$3" o rc
  [ -n "$t" ] || { bad "[$id] DID NOT APPLY (tree build, prep or mutation failed)"; return; }
  o="$WORK/$id.out"; drive "$t" a "$o"; rc=$?
  if [ "$rc" -eq 2 ] && grep -q "^FIXTURE BROKEN: \[J0\] .*$frag" "$o" && ! grep -q '^ledger-reverify fixture$' "$o"; then
    ok "[$id] KILLED by [J0]: exit 2 before the seed, naming '$frag'"
  else
    bad "[$id] J0 did not refuse (rc=$rc)"; sed -n '1,10p' "$o" | sed 's/^/          | /'
  fi
}

# --- B1: the shard runs EVERY declared unit while its declared list is untouched. A count of loop
# iterations agrees with itself here; only the set comparison against UNITS_a's text sees it.
t="$(newtree)" && mut "$t/$FX/run.sh" 'eval "LR_MINE=\"\${UNITS_$GROUP}\""' \
  'LR_MINE="$(sed -n '"'"'s/^lr_unit_\([a-z0-9_]*\)() {$/\1/p'"'"' "$LR_SELF" | tr '"'"'\n'"'"' '"'"' '"'"')"' || t=""
run_kill B1-mine-is-every-unit a "[J1]" "$t"

# --- D1: a unit calls a helper this shard no longer defines. The premise first: with J2 disabled
# --- the same copy exits 0 and prints PASS, which is the defect J2 exists for.
t="$(newtree)" && mut "$t/$FX/run.sh" 'detail_lacks() {' 'detail_lacks_gone() {' || t=""
tp=""
[ -n "$t" ] && { tp="$WORK/t-d1-premise"; cp -R "$t" "$tp" \
  && mut "$tp/$FX/run.sh" "  if grep -qE 'run\\.sh: line [0-9]+: .*(command not found|unbound variable)\$' \"\$LR_UNIT_ERR\"; then" \
     "  if false; then" || tp=""; }
if [ -z "$tp" ]; then
  bad "[D1-premise] the J2-disabled copy DID NOT APPLY"
else
  drive "$tp" a "$WORK/d1p.out"; rc=$?
  if [ "$rc" -eq 0 ] && grep -q "^PASS: all [0-9]* assertions correct in shard 'a' of 'a b'\.\$" "$WORK/d1p.out" \
     && grep -q 'detail_lacks: command not found' "$WORK/d1p.out"; then
    ok "[D1-premise] with J2 disabled, a missing helper prints 'command not found' and the shard still reads PASS"
  else
    bad "[D1-premise] the J2-disabled copy did not read PASS over the missing helper (rc=$rc)"
  fi
fi
run_kill D1-missing-helper a "[J2]" "$t"

# --- D4: a unit returns before asserting anything.
t="$(newtree)" && mut "$t/$FX/run.sh" 'lr_unit_name_signal() {' 'lr_unit_name_signal() {
  return 0' || t=""
run_kill D4-unit-returns-early b "[floor]" "$t"

# --- the shared count: a body left at top level, outside every unit, runs in every shard.
t="$(newtree)" && mut "$t/$FX/run.sh" '# --- DISPATCH: ' 'row_is "Entry A" STILL-LIVE "a unit body left at top level"
# --- DISPATCH: ' || t=""
run_kill S6-stray-top-level-assertion a "[shared]" "$t"

# --- the missing driver: shard b is declared and its directory is gone.
t="$(newtree)"
if [ -n "$t" ] && [ -f "$t/$FX-b/run.sh" ]; then mv "$t/$FX-b" "$t/driver-b-moved-away" || t=""; else t=""; fi
run_j0 J0-missing-driver "$t" "shard 'b' is declared but"

# --- an undealt unit: shard b's list loses one declared unit.
t="$(newtree)" && mut "$t/$FX/run.sh" "UNITS_b=\"$KEEP_B\"" 'UNITS_b="name_signal"' || t=""
run_j0 J0-unit-dealt-nowhere "$t" "dealt to no shard: {short_id}"

# --- G2: the driver names shard b only inside a trailing comment and actually runs shard a.
t="$(newtree)" && mut "$t/$FX-b/run.sh" 'bash "$IMPL" --group b >' 'bash "$IMPL" --group a # --group b >' || t=""
run_j0 J0-driver-trailing-comment "$t" "shard 'b' is declared but"

# --- G1: the argument parser stops honouring --group, so driver b runs shard a and that shard
# --- prints its own PASS. The premise first: with the driver's verdict check reverted to the old
# --- `exec`, the same copy exits 0 on shard a's PASS and shard b runs nowhere.
G1_OLD='case "${1:-}" in'; G1_NEW='case "" in'
DRV_OLD='bash "$IMPL" --group b > "$LR_OUT"'
t="$(newtree)" && mut "$t/$FX/run.sh" "$G1_OLD" "$G1_NEW" || t=""
tp=""
[ -n "$t" ] && { tp="$WORK/t-g1-premise"; cp -R "$t" "$tp" && mut "$tp/$FX-b/run.sh" "$DRV_OLD" 'exec bash "$IMPL" --group b' || tp=""; }
if [ -z "$tp" ]; then
  bad "[G1-premise] the exec-driver copy DID NOT APPLY"
else
  drive "$tp" b "$WORK/g1p.out"; rc=$?
  if [ "$rc" -eq 0 ] && grep -q "^PASS: all [0-9]* assertions correct in shard 'a' of 'a b'\.\$" "$WORK/g1p.out"; then
    ok "[G1-premise] with an exec driver, an ignored --group runs shard a under driver b and exits 0"
  else
    bad "[G1-premise] the exec-driver copy did not read PASS for shard a under driver b (rc=$rc)"
  fi
fi
if [ -z "$t" ]; then
  bad "[G1-group-ignored] DID NOT APPLY (tree build, prep or anchor failed)"
else
  drive "$t" b "$WORK/g1.out"; rc=$?
  if [ "$rc" -eq 2 ] && grep -q "^FIXTURE BROKEN: the sibling's verdict does not name shard 'b'" "$WORK/g1.out" \
     && grep -q "^PASS: all [0-9]* assertions correct in shard 'a' of 'a b'\.\$" "$WORK/g1.out"; then
    ok "[G1-group-ignored] KILLED by the driver: shard a's PASS replayed, then exit 2 naming shard 'b'"
  else
    bad "[G1-group-ignored] SURVIVED (rc=$rc)"; sed -n '1,10p' "$WORK/g1.out" | sed 's/^/          | /'
  fi
fi

# --- E1: a unit calls `exit 0`. The premise first: with the trap's LR_DONE guard removed, the
# --- shard exits 0 with no verdict line, which the pool reads as green. Driven as shard a, which
# --- has no driver in front of it, so the sibling's own trap is the only thing that can catch it.
E1_UNIT='lr_unit_nonid_manual() {'
E1_GUARD='; [ "${LR_DONE:-}" = 1 ] || { echo "FIXTURE BROKEN: shard exited before dispatch completed" >&3; exit 2; }'"'"' EXIT'
t="$(newtree)" && mut "$t/$FX/run.sh" "$E1_UNIT" "$E1_UNIT
  exit 0" || t=""
tp=""
[ -n "$t" ] && { tp="$WORK/t-e1-premise"; cp -R "$t" "$tp" && mut "$tp/$FX/run.sh" "$E1_GUARD" "' EXIT" || tp=""; }
if [ -z "$tp" ]; then
  bad "[E1-premise] the guard-removed copy DID NOT APPLY"
else
  drive "$tp" a "$WORK/e1p.out"; rc=$?
  if [ "$rc" -eq 0 ] && ! grep -qE "^(PASS|FAIL): " "$WORK/e1p.out" && grep -q '^  ok    \[J0\]' "$WORK/e1p.out"; then
    ok "[E1-premise] without the LR_DONE guard, a unit's exit 0 ends the shard green with no verdict"
  else
    bad "[E1-premise] the guard-removed copy did not exit 0 verdictless (rc=$rc)"
  fi
fi
if [ -z "$t" ]; then
  bad "[E1-unit-exit-0] DID NOT APPLY (tree build, prep or anchor failed)"
else
  drive "$t" a "$WORK/e1.out"; rc=$?
  if [ "$rc" -eq 2 ] && grep -q '^FIXTURE BROKEN: shard exited before dispatch completed$' "$WORK/e1.out" \
     && ! grep -qE "^(PASS|FAIL): " "$WORK/e1.out" && grep -q '^  ok    \[J0\]' "$WORK/e1.out"; then
    ok "[E1-unit-exit-0] KILLED by the EXIT trap: exit 2, no verdict line"
  else
    bad "[E1-unit-exit-0] SURVIVED (rc=$rc)"; sed -n '1,10p' "$WORK/e1.out" | sed 's/^/          | /'
  fi
fi

# --- E2: a unit's legitimate refusal (`exit 2` after a FIXTURE ERROR on stderr) still surfaces
# --- its own text exactly once through the trap's replay, beside the trap's own line.
t="$(newtree)" && mut "$t/$FX/run.sh" "$E1_UNIT" "$E1_UNIT
  echo 'FIXTURE ERROR: E2 unit refusal probe' >&2; exit 2" || t=""
if [ -z "$t" ]; then
  bad "[E2-refusal-surfaces-once] DID NOT APPLY (tree build, prep or anchor failed)"
else
  drive "$t" a "$WORK/e2.out"; rc=$?
  e2n="$(grep -c '^FIXTURE ERROR: E2 unit refusal probe$' "$WORK/e2.out")" || e2n=0
  if [ "$rc" -eq 2 ] && [ "$e2n" -eq 1 ] && grep -q '^FIXTURE BROKEN: shard exited before dispatch completed$' "$WORK/e2.out"; then
    ok "[E2-refusal-surfaces-once] a unit's exit 2 refusal reaches stderr once, and the run is exit 2"
  else
    bad "[E2-refusal-surfaces-once] rc=$rc, the refusal text appeared $e2n time(s), want rc 2 and once"
  fi
fi

echo "ledger-reverify-shard-mutants: $fails FAIL"
[ "$fails" -eq 0 ]
