#!/usr/bin/env bash
# fold-architect-ledger-join-mutants — the mutation battery behind the shipped
# `fold-architect-ledger-join` fixture. DISTRIBUTION-ONLY.
#
# Usage: run.sh
# Exit:  0 every mutant is KILLED by exactly the arms it owns; 1 a mutant survived, or killed an
#        arm it does not own; 2 the harness is broken and no verdict is readable.
#
# EACH MUTANT IS A COPY OF THE WHOLE TREE the fixture resolves (core/ and scripts/), never an
# in-place edit, and each edit is refused unless its anchor occurs EXACTLY ONCE and the copy then
# differs from the original (`cmp -s`). A mutation that matched nothing is a mutant that never
# existed, and it would read here exactly as a survivor.
#
# EVERY LAYER IS REVERTED. `validate-spawn-ledger.sh --fold-architect` runs its own two-direction
# self-probe before judging, and that probe exercises the role, ordering, uniqueness and SKIP
# clauses. Left in place, it refuses most of these mutants with exit 2 before the fixture's arms
# are reached, and every seed then reads rc=2 — an entangled kill the arms did not earn. So every
# mutant copy also bypasses the probe call (text mutants too, which keeps C1 their exact control
# and keeps the shard under its time bar), and the fixture must kill it on its own arms. For a
# subject mutant the probe's own verdict on the un-bypassed copy is reported beside the kill, as a
# separate fact.
#
# A KILL IS THE EXACT SET OF RED ARMS. The fixture prints `FAIL  [<id>]` per red arm; the set
# must equal the mutant's declared set. More is entanglement, fewer is a survivor.
#
# THE CONTROL HAS A POSITIVE CONJUNCT. The unmutated copy — with the probe bypass applied, so it
# differs from each subject mutant by the mutation alone — must print the fixture's full
# `70 ok, 0 FAIL` line. A copy that never ran prints nothing and cannot satisfy it.
#
# --- THE SHARD SPLIT, AND IT IS A MEASUREMENT RATHER THAN A PREFERENCE --------------------
# The pre-push suite is POLE-BOUND: its makespan tracks its single longest DIRECTORY, because
# `core/fixtures/*/run.sh` is what the outer pool globs. Unsharded, this battery took 436s solo
# for 20 runs of the shipped fixture (C0, C1 and 18 mutants, ~22s each) plus the M6 premise's
# three I32 runs, and a loaded cost runs well above a solo one, so it would have been the pole.
#
# THREE SHARDS, NOT TWO, AND THE FIXED COST IS WHY. Every shard pays the controls and the
# premise itself (below), about 65s solo, because a shard that skipped them could report a
# kill against a harness that never ran. Two shards would be ~65 + 9 x 22 = ~260s each, over
# the 200s bar; three are ~65 + 6 x 22 = ~200s.
#
# THE DEAL IS BY COST, AND NO MUTANT SHARES A PREREQUISITE WITH ANOTHER. Each mutant builds its
# own tree and makes one full run of the fixture; the only shared prerequisites are the controls
# and the premise, which every shard repeats. So the partition balances the two things that
# vary: a validate-spawn-ledger.sh mutant also pays the un-bypassed self-probe, and M13 also pays
# the D6 watchdog's 15-second timeout on the hang it re-creates. Round v3.3 dealt M19-M25 three,
# two and two, and bypassed the probe in EVERY copy: re-measured solo, one after another on this
# machine, a 135s, b 130s, c 145s (c carries M13). Round v3.4 re-measured the three before adding
# anything -- a 139s, b 135s, c 143s -- and dealt M26 and M27 both to b, the lowest.
#
# THE SHARD ARRIVES AS AN ARGUMENT (`--group b`), never from the environment: the scrub above
# unsets AI_DLC_*, and a fallback-to-'a' design would run shard 'a' three times and report three
# green fixtures. The sibling directories `-b` and `-c` are one-line drivers that exec this file.
#
# THE COVERAGE JOIN runs in EVERY shard, before any tree is built: the declared mutant set is
# DERIVED from this file's own `run_mutant M<n>-` lines, and the dealt lists must be disjoint and
# their union must equal it exactly, so no mutant can fall out of every shard; every declared shard
# must also have a driver directory. The join proves it can fire, on a seeded duplicate and a
# seeded omission, before it is trusted.
SHARDS="a b c"
MUTANTS_a="M1 M2 M3 M4 M5 M6 M19 M20 M25"
MUTANTS_b="M7 M8 M9 M10 M11 M14 M21 M22 M26 M27"
MUTANTS_c="M12 M13 M15 M16 M17 M18 M23 M24"
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR 2>/dev/null || true

GROUP=a
if [ "${1:-}" = "--group" ]; then
  GROUP="${2:-}"
  [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }
fi
case " $SHARDS " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac
eval "MINE=\"\${MUTANTS_$GROUP:-}\""
[ -n "$MINE" ] || { echo "FIXTURE ERROR: shard '$GROUP' has no MUTANTS_$GROUP list; a shard dealt nothing passes everything it never checked" >&2; exit 2; }
NAME="fold-architect-ledger-join-mutants"
[ "$GROUP" = a ] || NAME="$NAME-$GROUP"

HERE="$(cd "$(dirname "$0")" && pwd)"
SELF="$HERE/run.sh"
[ -f "$SELF" ] || { echo "FIXTURE ERROR: cannot read $SELF for the coverage join" >&2; exit 2; }

# partition_ok <declared ids file> <dealt ids file> -> 0 when dealt is disjoint and covers declared
# exactly; prints the offending ids otherwise.
partition_ok() {
  local dup miss extra
  dup="$(sort "$2" | uniq -d | tr '\n' ' ')"
  miss="$(sort -u "$2" | comm -23 <(sort -u "$1") - | tr '\n' ' ')"
  extra="$(sort -u "$2" | comm -13 <(sort -u "$1") - | tr '\n' ' ')"
  [ -z "$dup$miss$extra" ] && return 0
  echo "dealt twice: {${dup% }} dealt to no shard: {${miss% }} dealt but not declared: {${extra% }}"
  return 1
}
JW="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
printf '%s\n' M1 M2 M3 > "$JW/pd"
printf '%s\n' M1 M2 M2 M3 > "$JW/pdup"
printf '%s\n' M1 M3 > "$JW/pmiss"
printf '%s\n' M3 M1 M2 > "$JW/pok"
if partition_ok "$JW/pd" "$JW/pdup" >/dev/null || partition_ok "$JW/pd" "$JW/pmiss" >/dev/null \
   || ! partition_ok "$JW/pd" "$JW/pok" >/dev/null; then
  echo "FIXTURE BROKEN: the coverage join's self-probe did not discriminate (duplicate, omission, exact)" >&2
  rm -rf "$JW"; exit 2
fi
sed -n 's/^run_mutant \(M[0-9][0-9]*\)-.*/\1/p' "$SELF" > "$JW/declared"
for s in $SHARDS; do eval "printf '%s\n' \${MUTANTS_$s}"; done | grep . > "$JW/dealt"
ndecl="$(grep -c . "$JW/declared")" || ndecl=0
ndupdecl="$(sort "$JW/declared" | uniq -d | grep -c .)" || ndupdecl=0
if [ "$ndecl" -eq 0 ] || [ "$ndupdecl" -ne 0 ]; then
  echo "FIXTURE BROKEN: $ndecl run_mutant ids derived from $SELF ($ndupdecl declared twice)" >&2; rm -rf "$JW"; exit 2
fi
if ! why="$(partition_ok "$JW/declared" "$JW/dealt")"; then
  echo "FIXTURE BROKEN: the shard partition does not cover the declared mutants exactly -- $why" >&2; rm -rf "$JW"; exit 2
fi
for s in $SHARDS; do
  [ "$s" = a ] && continue
  drv="$HERE/../fold-architect-ledger-join-mutants-$s/run.sh"
  if [ ! -f "$drv" ] || ! grep -qF -- "--group $s" "$drv"; then
    echo "FIXTURE BROKEN: shard '$s' is declared but $drv does not drive it" >&2; rm -rf "$JW"; exit 2
  fi
done
rm -rf "$JW"
JOIN_LINE="[J0] coverage join: $ndecl mutants derived from run_mutant lines, dealt disjointly across {$SHARDS}, union exact; this shard runs {$MINE}"
ROOT="$HERE"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/scripts/install.sh" ]; do ROOT="$(dirname "$ROOT")"; done
[ -f "$ROOT/scripts/install.sh" ] \
  || { echo "FIXTURE ERROR: no scripts/install.sh above $HERE — this battery is distribution-only" >&2; exit 2; }
FX="core/fixtures/fold-architect-ledger-join"
VSL_REL="core/scripts/validate-spawn-ledger.sh"
GV_REL="core/skills/ai-dlc/steps/gate-validation.md"
BI_REL="core/skills/ai-dlc/steps/bug-investigation.md"
for f in "$FX/run.sh" "$FX/graph-ledger.jsonl" "$FX/graph-oneshot-s313.block" "$VSL_REL" "$GV_REL" "$BI_REL" \
         scripts/validate-enforcement-map.sh; do
  [ -f "$ROOT/$f" ] || { echo "FIXTURE ERROR: missing $ROOT/$f" >&2; exit 2; }
done
command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 not on PATH" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
case "$WORK" in /tmp/*|/private/*|/var/folders/*) trap 'rm -rf "$WORK"' EXIT ;; esac

echo "$NAME:"
printf '  subject: %s\n' "$ROOT/$VSL_REL"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
ok "$JOIN_LINE"

# The fixture's own tree: core/ minus the other fixtures, the fixture under test, and scripts/
# (validate-enforcement-map.sh, for the I32 premise below).
mktree() {  # <dir>
  mkdir -p "$1/core/fixtures" || return 1
  for e in "$ROOT"/core/*; do
    [ "$(basename "$e")" = fixtures ] && continue
    cp -R "$e" "$1/core/" || return 1
  done
  cp -R "$ROOT/$FX" "$1/core/fixtures/" && cp -R "$ROOT/scripts" "$1/" || return 1
  [ -f "$1/$VSL_REL" ] && [ -f "$1/$FX/run.sh" ] && [ -f "$1/core/scripts/gate-slice.sh" ] \
    && [ -f "$1/core/scripts/validate-provenance-block.sh" ] && [ -f "$1/core/schemas/provenance-block.json" ]
}
# mut <file> <old> <new>: exactly-once replacement. 0 applied, 1 not.
mut() {
  cp "$1" "$1.orig" || return 1
  OLD="$2" NEW="$3" python3 - "$1" <<'PY' || return 1
import os, sys
p = sys.argv[1]; s = open(p).read(); o = os.environ["OLD"]
if s.count(o) != 1:
    sys.stderr.write("anchor occurs %d times\n" % s.count(o)); sys.exit(1)
open(p, "w").write(s.replace(o, os.environ["NEW"]))
PY
  if cmp -s "$1" "$1.orig"; then rm -f "$1.orig"; return 1; fi
  rm -f "$1.orig"
}
BYPASS_OLD='  fa_self_probe || { echo'
BYPASS_NEW='  true || { echo'
red_set() { sed -n 's/^  FAIL  \[\([^]]*\)\].*/\1/p' "$1" | sort | tr '\n' ' ' | sed 's/ $//'; }
drive_fx() {  # <tree> <out> -> rc
  ( cd "$WORK" && bash "$1/$FX/run.sh" ) > "$2" 2>&1
}
probe_verdict() {  # <tree> -> refuses | holds
  bash "$1/$VSL_REL" --fold-architect "$WORK/nonexistent/fold-architecture-z.md" \
    "$WORK/nonexistent/bug-fix-oneshot-z.md" > "$WORK/pv.out" 2>&1
  if grep -q 'self-probe did not hold' "$WORK/pv.out"; then echo refuses; else echo holds; fi
}

# --- CONTROLS -------------------------------------------------------------------------------
T0="$WORK/t-pristine"; mktree "$T0" || { echo "FIXTURE ERROR: could not build the pristine tree" >&2; exit 2; }
drive_fx "$T0" "$WORK/c0.out"; c0=$?
if [ "$c0" -eq 0 ] && grep -q '^fold-architect-ledger-join: 70 ok, 0 FAIL, 0 stood down$' "$WORK/c0.out"; then
  ok "[C0] pristine copy: 70 ok, 0 FAIL"
else
  echo "FIXTURE BROKEN: the pristine copy did not pass (rc=$c0) — no mutant verdict is readable" >&2
  sed -n '1,40p' "$WORK/c0.out" >&2; exit 2
fi
[ "$(probe_verdict "$T0")" = holds ] || { echo "FIXTURE BROKEN: the pristine subject's own self-probe refuses" >&2; exit 2; }
T1="$WORK/t-bypass"; mktree "$T1" || { echo "FIXTURE ERROR: tree build failed" >&2; exit 2; }
mut "$T1/$VSL_REL" "$BYPASS_OLD" "$BYPASS_NEW" || { echo "FIXTURE BROKEN: the self-probe bypass DID NOT APPLY" >&2; exit 2; }
drive_fx "$T1" "$WORK/c1.out"; c1=$?
if [ "$c1" -eq 0 ] && grep -q '^fold-architect-ledger-join: 70 ok, 0 FAIL, 0 stood down$' "$WORK/c1.out"; then
  ok "[C1] probe-bypassed, otherwise unmutated copy: 70 ok, 0 FAIL"
else
  echo "FIXTURE BROKEN: the probe-bypass control did not pass (rc=$c1)" >&2; sed -n '1,40p' "$WORK/c1.out" >&2; exit 2
fi

# --- MUTANTS --------------------------------------------------------------------------------
# run_mutant <id> <owned arms, sorted, space-separated> <file> <bypass 1|0> <old> <new> [<old2> <new2>]
N=0
run_mutant() {
  local id="$1" want="$2" rel="$3" byp="$4" t got rc pv="n/a"
  case " $MINE " in *" ${id%%-*} "*) : ;; *) return ;; esac
  N=$((N+1)); t="$WORK/t-$N"
  mktree "$t" || { bad "[$id] tree build failed"; return; }
  if ! mut "$t/$rel" "$5" "$6"; then bad "[$id] DID NOT APPLY (anchor 1)"; return; fi
  if [ $# -ge 8 ] && ! mut "$t/$rel" "$7" "$8"; then bad "[$id] DID NOT APPLY (anchor 2)"; return; fi
  # EVERY COPY GETS THE BYPASS, so C1 is the exact control for every mutant, not only for the
  # validate-spawn-ledger.sh ones. It is also the shard's wall clock: the subject re-runs its
  # self-probe on every call, and a text-only mutant driven with the probe live cost ~74s solo
  # against ~5s bypassed (measured round v3.3). `byp` now says only whether the un-bypassed
  # subject's own verdict on the mutant is worth reporting.
  [ "$byp" = 1 ] && pv="$(probe_verdict "$t")"
  mut "$t/$VSL_REL" "$BYPASS_OLD" "$BYPASS_NEW" || { bad "[$id] probe bypass DID NOT APPLY"; return; }
  drive_fx "$t" "$WORK/m$N.out"; rc=$?
  if ! grep -q '^fold-architect-ledger-join: [0-9]* ok, [0-9]* FAIL' "$WORK/m$N.out"; then
    bad "[$id] the fixture produced no verdict line (rc=$rc) — a harness failure, not a kill"; return
  fi
  got="$(red_set "$WORK/m$N.out")"
  if [ "$rc" -ne 0 ] && [ "$got" = "$want" ]; then
    ok "[$id] KILLED by exactly {$want}; subject self-probe on the un-bypassed mutant: $pv"
  elif [ -z "$got" ]; then
    bad "[$id] SURVIVED (rc=$rc); subject self-probe: $pv"
  else
    bad "[$id] killed by {$got}, declared {$want} — entangled or mis-owned (rc=$rc)"
  fi
}

run_mutant M1-drop-ledger-join "A-sprint A-unknown A-v A-vi D1-1" "$VSL_REL" 1 \
  '  if [ -z "$hits" ]; then' '  if false; then' \
  '  if [ "$ok" -ne 1 ]; then' '  if false; then'
run_mutant M2-accept-any-role "A-v" "$VSL_REL" 1 \
  'if [ "$role" != "architect" ]; then' 'if false; then'
run_mutant M3-drop-ts-ordering "A-vi D1-1" "$VSL_REL" 1 \
  'if [ "$rte" = "__NONE__" ] || awk -v a="$rte" -v b="$one_e" '"'"'BEGIN { exit !(a + 0 < b + 0) }'"'"'; then' \
  'if false; then'
run_mutant M4-drop-uniqueness "A-vii" "$VSL_REL" 1 \
  '    if [ "$otui" = "$rtui" ]; then' '    if false; then'
run_mutant M5-drop-17-from-implementation-row "G1" "$GV_REL" 0 \
  '| implementation | 5, 6, 8, 9, 10, 11, 11a, 17, 19, 22 ' '| implementation | 5, 6, 8, 9, 10, 11, 11a, 19, 22     '
run_mutant M6-fold-pin-into-bug-fix-bullet "B1" "$GV_REL" 0 \
  '- **Fold architecture gate (bug-investigation):** for each folded bug-fix story,' \
  '  Fold architecture gate (bug-investigation): for each folded bug-fix story,'
run_mutant M7-empty-ledger-skip-reads-pass "A-empty A-viii B1-idless" "$VSL_REL" 1 \
  '    echo "SKIP-PRE-ADOPTION: the ledger carries no tool_use_id on any S${sprint} row, so no"' \
  '    echo "PASS: ${onebase} -> $(basename "$res"): nothing to join"'
run_mutant M8-writer-path-drift "B2" "$BI_REL" 0 \
  '`_bmad-output/planning-artifacts/s<N>/fold-architecture-<slug>.md` (the same' \
  '`_bmad-output/planning-artifacts/s<N>/fold-arch-<slug>.md` (the same'

# --- round v3.2: one mutant per new clause ---------------------------------------------------
# D1: ordering reads the lead-written invoked_at again, wherever the one-shot's own row resolved.
# The SKIP/FAIL path for an unresolved id and the printed ledger ts are left as shipped, so the
# only thing this reverts is which instant the architect row is compared against.
run_mutant M9-ordering-reads-invoked-at "D1-1" "$VSL_REL" 1 \
  '  one_ts="$(printf '"'"'%s\n'"'"' "$q" | awk -F'"'"'\t'"'"' '"'"'$1 == "ONE" { print $3; exit }'"'"')"' \
  '  one_ts="$(printf '"'"'%s\n'"'"' "$q" | awk -F'"'"'\t'"'"' '"'"'$1 == "ONE" { print $3; exit }'"'"')"
  [ "${one_e:-__NONE__}" = "__NONE__" ] || one_e="$(jq -rn --arg t "$(fa_field "$one" invoked_at)" '"'"'$t | fromdateiso8601'"'"')"'
# D4: the legacy name is NOT-OWED in every variant.
run_mutant M10-legacy-not-owed-everywhere "A-legacy D4-arch Dd-carry" "$VSL_REL" 1 \
  '  if [ "$onebase" = "bug-fix-oneshot.md" ]; then' \
  '  if [ "$onebase" = "bug-fix-oneshot.md" ]; then echo "NOT-OWED: $onebase is the legacy one-shot name"; return 3; fi; if false; then'
# Variant: an unknown variant reads as NOT-OWED.
run_mutant M11-unknown-variant-not-owed "V-unknown V-unknown-flag" "$VSL_REL" 1 \
  "      *)   echo \"FAIL: variant '" \
  "      *)   echo \"NOT-OWED: variant '\${FA_VARIANT}' is unknown\"; exit 0; echo \"FAIL: variant '"
# D5: artifact: compared by basename.
run_mutant M12-artifact-by-basename "D5-otherdir" "$VSL_REL" 1 \
  '  if [ "${rart#./}" != "${story#./}" ]; then' \
  '  if [ "$(basename "$rart")" != "$(basename "$story")" ]; then'
# D6: the no-value guard on --ledger removed, back to the pre-fix `${2:-}` form that spins.
run_mutant M13-ledger-no-value-guard "D6--ledger" "$VSL_REL" 1 \
  '      [ $# -ge 2 ] || { echo "FAIL: --ledger takes the path of spawn-ledger.jsonl" >&2; exit 2; }
      LEDGER="$2"; shift 2 ;;' \
  '      LEDGER="${2:-}"; shift 2 ;;'
# D3: the fold residue gets the "Repoint" message.
run_mutant M14-fold-residue-told-repoint "D3-fold" "core/scripts/validate-provenance-block.sh" 0 \
  '        if os.path.basename(artifact_path).startswith("fold-architecture-"):' \
  '        if False:'
# B1: Check 17's implementation-gate bullet also runs the cross-check.
run_mutant M15-impl-gate-runs-cross-check "B1-bug B1-idless B1-impl" "$GV_REL" 0 \
  '  and the fold architecture gate below. Both exit 0. Never run the' \
  '  then `scripts/ai-dlc/stamp-story-provenance.sh --terminal _bmad-output/planning-artifacts/s<N>/bug-fix-oneshot-<slug>.md --profile bug-story-provenance --check <story-file>`,
  and the fold architecture gate below. Both exit 0. Never run the'
# D5: the fold bullet's documented command passes a lead-typed --variant again. (Dropping
# `--ledger` or `--route` from it is an EQUIVALENT mutant: both defaults are the documented values.)
# Every arm that EXECUTES the fold command in an architecture world reads NOT-OWED where it demands
# a verdict, or the sprint-status cross-check refuses the typed `bug` with exit 2 where the world
# carries a carry-over sprint-status. B1-bug is the one executing arm it cannot reach: that world
# really is `bug`.
run_mutant M16-fold-cmd-types-variant "B1-idless B1-impl D5-cmd-fail D5-cmd-pass D5-cmd-skill Dd-carry" "$GV_REL" 0 \
  '--ledger _bmad-output/spawn-ledger.jsonl --route .claude/skills/ai-dlc/steps/route.md`;' \
  '--ledger _bmad-output/spawn-ledger.jsonl --route .claude/skills/ai-dlc/steps/route.md --variant bug`;'
# B-1, RE-ANCHORED. The fold gate is ONE command now, and the residue's shape check is the
# script's own call to its sibling validate-provenance-block.sh. The documented first command these
# two used to edit no longer exists, so they edit the call that replaced it; the observable is the
# same (a wrong-skill residue must not PASS) and so is the owning arm.
# M17: the internal call drops its pin. The wrong-skill residue is otherwise well-formed, so the
# unpinned validator passes it (measured, rc=0) and the fold reads PASS.
run_mutant M17-fold-cmd-drops-pin "D5-cmd-skill" "$VSL_REL" 1 \
  '  vout="$(bash "$FA_VPB" "$res" --require-skill bmad-review-adversarial-general 2>&1)"; vrc=$?' \
  '  vout="$(bash "$FA_VPB" "$res" 2>&1)"; vrc=$?'
# M18: the pin stays but validates the STORY, which the shipped stamp gave the pinned skill.
run_mutant M18-fold-cmd-pins-wrong-file "D5-cmd-skill" "$VSL_REL" 1 \
  '  vout="$(bash "$FA_VPB" "$res" --require-skill bmad-review-adversarial-general 2>&1)"; vrc=$?' \
  '  vout="$(bash "$FA_VPB" "$story" --require-skill bmad-review-adversarial-general 2>&1)"; vrc=$?'

# --- round v3.3: one mutant per new clause ---------------------------------------------------
# B-1 (script): the residue is read BEFORE the owed decision -- on the NOT-OWED answer and on the
# no-ids SKIP -- which is the old two-command gate's behaviour moved inside the script. Every
# NOT-OWED or no-ids SKIP world without a residue owns it; B1-bug and B1-idless are the ones that
# reach it through the EXTRACTED gate commands.
run_mutant M19-residue-read-before-owed "A-iv A-viii B1-bug B1-idless D4-bug Dd-bug V-bug V-legacy-bug" "$VSL_REL" 1 \
  '      no)  echo "NOT-OWED:' \
  '      no)  bash "$FA_VPB" "$FA_RES" --require-skill bmad-review-adversarial-general >/dev/null 2>&1 || { echo "FAIL: residue $(basename "$FA_RES") fails its shape check" >&2; exit 1; }; echo "NOT-OWED:' \
  '  if [ "${nid:-0}" -eq 0 ]; then' \
  '  if [ "${nid:-0}" -eq 0 ] && ! bash "$FA_VPB" "$res" --require-skill bmad-review-adversarial-general >/dev/null 2>&1; then echo "FAIL: residue $(basename "$res") fails its shape check" >&2; return 1; fi
  if [ "${nid:-0}" -eq 0 ]; then'
# B-1 (gate text): THE BLOCKER ITSELF. The fold bullet documents the separate residue command again,
# ahead of the fold command. Only an arm that executes the extracted commands in a world owing no
# fold can see it; in the carry-over world the residue exists and both commands pass.
run_mutant M20-fold-bullet-readds-residue-cmd "B1-bug B1-idless B1-impl D5-cmd-skill Dd-bug" "$GV_REL" 0 \
  '  `<residue>` and the one-shot `<one-shot>`. Run this ONE command,' \
  '  `<residue>` and the one-shot `<one-shot>`. Run `scripts/ai-dlc/validate-provenance-block.sh <residue> --require-skill bmad-review-adversarial-general`, then this ONE command,'
# D-a: the story-stamp id equality skipped. A one-shot re-pointed at a LATER adversary row after
# the stamp then anchors the ordering on that row, and the fold PASSES.
run_mutant M21-stamp-id-equality-skipped "Da-repoint" "$VSL_REL" 1 \
  '  if ! grep -qxF -- "$sid" <<<"$stids"; then' '  if false; then'
# D-b: the one-shot's own row need not be an ADVERSARY row. An id on an in-sprint architect row then
# resolves as the one-shot's dispatch, the role message never fires, and the fold PASSES -- in the
# fully adopted sprint and in the partially adopted one alike.
run_mutant M22-oneshot-row-any-role "Db-full Db-part" "$VSL_REL" 1 \
  '      | [ $sp[] | select((.tool_use_id // "") == $o and (.role // "") == "adversary")' \
  '      | [ $sp[] | select((.tool_use_id // "") == $o)'
# D-c: the sprint-status cross-check dropped. A snapshot saying `bug` is then NOT-OWED on its own.
# Re-anchored in round v3.4: the call moved into fa_resolve_variant, the one place the order lives.
run_mutant M23-sprint-status-xcheck-dropped "Dc-disagree" "$VSL_REL" 1 \
  '    fa_xcheck "$v" "$src" "$3" || return 2' '    true'
# D-c: the snapshot reader stops skipping fenced blocks; the fenced decoy above the real line wins.
run_mutant M24-snapshot-reads-fences "Dc-fence" "$VSL_REL" 1 \
  '    fence { next }' '    fence { }'
# D-c: the snapshot reader stops skipping HTML comments; the commented decoy wins.
run_mutant M25-snapshot-reads-comments "Dc-comment" "$VSL_REL" 1 \
  '      while ((p = index(raw, "<!--")) > 0) {' '      while (0) {'

# --- round v3.4: one mutant per new clause ---------------------------------------------------
# DEFECT 3: a snapshot that exists but yields no pipeline_variant line exits 2 again, before
# sprint-status is read. Both DEFECT 3 seeds own it: the fall-through to a `bug` sprint-status and
# the no-sprint-status OWED world each read rc=2 in its place.
run_mutant M26-unparseable-snapshot-exits-2 "V-legacy-bug V-legacy-none" "$VSL_REL" 1 \
  '    # A snapshot with no parseable line is not a refusal; it falls through to sprint-status.' \
  '    [ -f "$2" ] && [ -z "$v" ] && { echo "FAIL: $2 names no pipeline_variant, so whether an architecture step runs is unknown. Pass --variant." >&2; return 2; }'
# DEFECT 2: section 4's direct-fold paragraph types the residue command again. Nothing executes
# that paragraph, so only the arm that reads it can see this.
run_mutant M27-direct-fold-readds-residue-cmd "DF" "$BI_REL" 0 \
  'spells its commands. Type none of them here and run nothing else on the' \
  'spells its commands: first `scripts/ai-dlc/validate-provenance-block.sh <residue> --require-skill bmad-review-adversarial-general`, then the fold command. Run nothing else on the'

# --- M6's PREMISE: folded into the bullet above it, I32 loses that bullet's own pin -----------
# I32 reads each Check 17 arm's pin with a greedy `.*--require-skill`, so an arm carrying two pins
# is judged on the LAST. Both pins name the same skill today, so the fold is invisible to I32 —
# which is why B1 exists. The bullet directly above the fold bullet is the implementation-gate
# bullet, which names its own pin, so that is the pin staled: I32 fires on it with the bullets
# apart, and is silent with them folded.
i32() {  # <tree> -> sets I32RC, I32HIT
  ( cd "$WORK" && bash "$1/scripts/validate-enforcement-map.sh" --arms I32 ) > "$WORK/i32.out" 2>&1; I32RC=$?
  I32HIT="$(grep -c 'bmad-stale-pin-zz' "$WORK/i32.out")" || I32HIT=0
}
STALE_OLD='`scripts/ai-dlc/validate-provenance-block.sh <story-file> --require-skill bmad-review-adversarial-general`,'
STALE_NEW='`scripts/ai-dlc/validate-provenance-block.sh <story-file> --require-skill bmad-stale-pin-zz`,'
FOLD_OLD='- **Fold architecture gate (bug-investigation):** for each folded bug-fix story,'
FOLD_NEW='  Fold architecture gate (bug-investigation): for each folded bug-fix story,'
TA="$WORK/t-i32-apart"; TF="$WORK/t-i32-folded"
if mktree "$TA" && mktree "$TF" \
   && mut "$TA/$GV_REL" "$STALE_OLD" "$STALE_NEW" \
   && mut "$TF/$GV_REL" "$STALE_OLD" "$STALE_NEW" && mut "$TF/$GV_REL" "$FOLD_OLD" "$FOLD_NEW"; then
  i32 "$T0"; prc=$I32RC; phit=$I32HIT
  i32 "$TA"; arc=$I32RC; ahit=$I32HIT
  i32 "$TF"; frc=$I32RC; fhit=$I32HIT
  if [ "$prc" -eq 0 ] && [ "$phit" -eq 0 ] && [ "$arc" -ne 0 ] && [ "$ahit" -gt 0 ] && [ "$frc" -eq 0 ] && [ "$fhit" -eq 0 ]; then
    ok "[M6-premise] I32: pristine rc=0; stale pin apart rc=$arc (fires); stale pin folded rc=0 (old pin lost)"
  else
    bad "[M6-premise] I32 pristine rc=$prc/$phit, apart rc=$arc/$ahit, folded rc=$frc/$fhit"
  fi
else
  bad "[M6-premise] a premise mutation DID NOT APPLY"
fi

# Every mutant dealt to this shard must have RUN: a dealt id whose run_mutant line was deleted or
# renamed would otherwise leave this shard shorter and green.
nmine=0; for _m in $MINE; do nmine=$((nmine+1)); done
[ "$N" -eq "$nmine" ] || bad "[J1] shard '$GROUP' ran $N mutants, $nmine dealt"
echo "$NAME: $N mutants, $fails FAIL"
[ "$fails" -eq 0 ]
