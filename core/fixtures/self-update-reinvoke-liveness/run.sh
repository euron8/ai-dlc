#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# self-update-reinvoke-liveness -- a change to what step 3 onward executes is LIVE on the pull that
# delivers it, because step 2 STOPS and re-invokes /ai-dlc-update and the fresh invocation loads the
# updated logic. Only what the FIRST invocation's step 1 executed ran the pre-update version.
#
# Usage: run.sh
# Exit:  0 = every case and mutant behaved, 1 = one did not, 2 = fixture broken.
#
# WHAT IS REAL AND WHAT IS MODELLED. Real: the slice (the machinery: list in setup-sites.md, resolved by
# the shipped machinery_paths() lifted out of preclassify.sh, intersected with the base->theirs diff) and
# the consumer destinations (the shipped map_consumer()). Modelled: the distribution and the consumer (two
# tiny git repos), the probes (a script step 1 runs and an engine script step 3 runs, each printing a
# version marker), and the invocation. An invocation LOADS its logic once, at its start: this fixture
# copies the consumer's logic dirs to a snapshot and runs every step of that invocation from the
# snapshot, which is the SKILL.md claim "an in-flight agent cannot hot-reload its own instructions". The
# re-invoke is a NEW snapshot taken after step 2 merged. The self-update gate is NOT driven:
# SELF-UPDATE-DEFER is an input to the model (the gate's own fixtures are self-update-gate*).
#
# Modelled SKILL.md text (core/skills/ai-dlc-update/SKILL.md, step 2), asserted present below:
#   "THIS invocation is still executing the PRE-update logic"  /  "do NOT proceed to step 3 on stale logic"
#   "carrying the operator's original arguments IN FULL"
#   "The fresh invocation loads the updated logic and runs the reconcile on it."
#   "On `SELF-UPDATE-DEFER` or `SELF-UPDATE-UNDECIDED`: **do NOT cut the branch and do NOT push.**"
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do [ "$_v" = AI_DLC_PROJECT_ROOT ] || unset "$_v"; done
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

HERE="$(cd "$(dirname "$0")" && pwd)"
# Root by walking up for the marker, never by counting hops. Either layout.
ROOT="$HERE"; RECON=""; SKILL=""
while [ "$ROOT" != "/" ]; do
  for c in "core/skills/ai-dlc-update" ".claude/skills/ai-dlc-update"; do
    if [ -f "$ROOT/$c/reconcile/preclassify.sh" ]; then RECON="$ROOT/$c/reconcile"; SKILL="$ROOT/$c/SKILL.md"; break 2; fi
  done
  ROOT="$(dirname "$ROOT")"
done
[ -n "$RECON" ] && [ -f "$SKILL" ] && [ -f "$RECON/setup-sites.md" ] \
  || { echo "FIXTURE ERROR: cannot locate reconcile/ and SKILL.md in either layout" >&2; exit 2; }
echo "HERMETIC-CONSUMED $SKILL"
echo "HERMETIC-CONSUMED $RECON/preclassify.sh"
echo "HERMETIC-CONSUMED $RECON/setup-sites.md"

W="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$W"' EXIT
FAILS=0
ok()   { echo "ok   $1"; }
bad()  { echo "FAIL $1"; FAILS=$((FAILS+1)); }
eq()   { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1: got [$2] want [$3]"; fi; }
G()    { git -c user.name=fx -c user.email=fx@fx -c commit.gpgsign=false "$@"; }

# ---- the text being modelled still says what the model assumes ------------------------------------
for s in "THIS invocation is" "do NOT proceed to step 3 on stale logic" "fresh invocation loads the updated logic" \
         "carrying the operator's original arguments IN FULL" "do NOT cut the branch and do NOT push"; do
  n="$(grep -cF -- "$s" "$SKILL")" || n=0
  if [ "$n" -ge 1 ]; then ok "SKILL.md carries: $s"; else bad "SKILL.md no longer carries: $s"; fi
done
n="$(grep -cF -- "ZZ-NEVER-IN-SKILL-ZZ" "$SKILL")" || n=0
eq "text control: an impossible phrase is absent from SKILL.md" "$n" "0"

grep -q '^map_consumer() {' "$RECON/preclassify.sh" && grep -q '^machinery_paths() {' "$RECON/preclassify.sh" \
  || { echo "FIXTURE ERROR: cannot lift map_consumer()/machinery_paths() from preclassify.sh" >&2; exit 2; }

# ---- the real functions, lifted the way the shipped scripts lift them ------------------------------
mkdrv() { # <dir> <setup-sites.md source>
  mkdir -p "$1"; cp "$2" "$1/setup-sites.md"
  { echo 'set -u'
    awk '/^map_consumer\(\) \{/,/^\}/' "$RECON/preclassify.sh"
    awk '/^machinery_paths\(\) \{/,/^\}/' "$RECON/preclassify.sh"
    echo 'DIST="$1"; BASE="$2"; THEIRS="$3"; machinery_paths'
  } > "$1/mp.sh"
  { awk '/^map_consumer\(\) \{/,/^\}/' "$RECON/preclassify.sh"; echo 'map_consumer "$1"'; } > "$1/mc.sh"
}

# ---- the distribution: A (old) and B (new) ----------------------------------------------------------
D="$W/dist"; mkdir -p "$D/core/skills/ai-dlc-update/reconcile" "$D/core/scripts" "$D/core/skills/ai-dlc/steps"
git -C "$D" init -q && git -C "$D" symbolic-ref HEAD refs/heads/main
mk() { # <ver>
  printf 'echo "ENGINE-MARKER %s"\n' "$1" > "$D/core/skills/ai-dlc-update/reconcile/engine-probe.sh"
  printf 'echo "STEP1-MARKER %s"\n'  "$1" > "$D/core/scripts/step1-probe.sh"
  printf 'rulebook %s\n' "$1"          > "$D/core/skills/ai-dlc/steps/x.md"
}
mk A; git -C "$D" add -A; G -C "$D" commit -qm A; A="$(git -C "$D" rev-parse HEAD)"
mk B; git -C "$D" add -A; G -C "$D" commit -qm B; B="$(git -C "$D" rev-parse HEAD)"
[ "$A" != "$B" ] || { echo "FIXTURE ERROR: A and B are the same commit" >&2; exit 2; }

mkdrv "$W/drv" "$RECON/setup-sites.md"
ENGINE_C=".claude/skills/ai-dlc-update/reconcile/engine-probe.sh"
STEP1_C="scripts/ai-dlc/step1-probe.sh"
[ "$(bash "$W/drv/mc.sh" core/skills/ai-dlc-update/reconcile/engine-probe.sh)" = "$ENGINE_C" ] \
  && [ "$(bash "$W/drv/mc.sh" core/scripts/step1-probe.sh)" = "$STEP1_C" ] \
  || { echo "FIXTURE ERROR: lifted map_consumer() does not map the probes as the model assumes" >&2; exit 2; }

# slice <drv dir>: base->theirs diff intersected with machinery_paths. One core path per line.
slice() {
  local drv="$1" mset p
  mset="$(bash "$drv/mp.sh" "$D" "$A" "$B" 2>/dev/null)" || return 1
  git -C "$D" diff --name-only "$A" "$B" | while IFS= read -r p; do
    if grep -qxF -- "$p" <<<"$mset"; then printf '%s\n' "$p"; fi
  done
}
mkcons() { # <dir> : the consumer at A
  local c="$1" p dest
  mkdir -p "$c"; git -C "$c" init -q; git -C "$c" symbolic-ref HEAD refs/heads/main
  for p in core/skills/ai-dlc-update/reconcile/engine-probe.sh core/scripts/step1-probe.sh core/skills/ai-dlc/steps/x.md; do
    dest="$(bash "$W/drv/mc.sh" "$p")"; mkdir -p "$c/$(dirname "$dest")"
    git -C "$D" show "${A}:${p}" > "$c/$dest"
  done
  git -C "$c" add -A; G -C "$c" commit -qm A
}
snapshot() { # <consumer> <dest> : an invocation LOADS its logic once
  mkdir -p "$2"; cp -R "$1/scripts" "$2/scripts"; cp -R "$1/.claude" "$2/.claude"
}
write_slice() { # <consumer> <slice list> : the cycle writes on a branch, then merges
  local c="$1" p dest
  G -C "$c" checkout -q -b self-update
  printf '%s\n' "$2" | while IFS= read -r p; do
    [ -n "$p" ] || continue
    dest="$(bash "$W/drv/mc.sh" "$p")"; mkdir -p "$c/$(dirname "$dest")"
    git -C "$D" show "${B}:${p}" > "$c/$dest"
  done
  git -C "$c" add -A; G -C "$c" commit -qm "self-update"
  G -C "$c" checkout -q main; G -C "$c" merge -q --no-ff -m merge self-update
}
not_at_theirs() { # <consumer> <slice list> : the content question that makes step 2 terminate
  local c="$1" p dest
  printf '%s\n' "$2" | while IFS= read -r p; do
    [ -n "$p" ] || continue
    dest="$(bash "$W/drv/mc.sh" "$p")"
    if ! git -C "$D" show "${B}:${p}" | cmp -s - "$c/$dest" 2>/dev/null; then printf '%s\n' "$p"; fi
  done
}
run_probe() { bash "$1" 2>&1; }
cnt() { grep -c . || true; }

# flow <name> <setup-sites.md> <defer 0|1> <reinvoke live|pre> ; key=value lines into $W/<name>.out
flow() {
  local name="$1" ss="$2" defer="$3" re="$4" c out s1 s2 sl left
  c="$W/$name.cons"; out="$W/$name.out"; s1="$W/$name.s1"; s2="$W/$name.s2"
  : > "$out"
  mkdrv "$W/$name.drv" "$ss"
  mkcons "$c"
  snapshot "$c" "$W/$name.pre"
  snapshot "$c" "$s1"                                                    # invocation 1 loads A
  echo "inv1.step1=$(run_probe "$s1/$STEP1_C")" >> "$out"
  sl="$(slice "$W/$name.drv")"
  echo "slice.n=$(printf '%s\n' "$sl" | cnt)" >> "$out"
  echo "slice.has_engine=$(printf '%s\n' "$sl" | grep -cxF core/skills/ai-dlc-update/reconcile/engine-probe.sh || true)" >> "$out"
  echo "slice.has_step1=$(printf '%s\n' "$sl" | grep -cxF core/scripts/step1-probe.sh || true)" >> "$out"
  echo "slice.has_rulebook=$(printf '%s\n' "$sl" | grep -cxF core/skills/ai-dlc/steps/x.md || true)" >> "$out"
  if [ "$defer" = 2 ]; then
    # UN-SYNCED (SKILL.md step 2): no gate, no branch, no slice write, no re-invoke; step 6 refuses apply, so nothing lands.
    echo "tree_after_step2.engine=$(run_probe "$c/$ENGINE_C")" >> "$out"
    echo "inv1.step3=$(run_probe "$s1/$ENGINE_C")" >> "$out"
    echo "branches=$(git -C "$c" branch --list | cnt)" >> "$out"
    echo "slice_left_unwritten=$(not_at_theirs "$c" "$sl" | cnt)" >> "$out"
    return 0
  fi
  if [ "$defer" = 1 ]; then
    # SELF-UPDATE-DEFER: step 2 cuts no branch, writes nothing; invocation 1 CONTINUES to step 3 on A.
    echo "tree_after_step2.engine=$(run_probe "$c/$ENGINE_C")" >> "$out"
    echo "inv1.step3=$(run_probe "$s1/$ENGINE_C")" >> "$out"
    write_slice "$c" "$sl"                                               # step 7 gated apply lands the carried slice
    snapshot "$c" "$W/$name.s7"
    echo "after7.step3=$(run_probe "$W/$name.s7/$ENGINE_C")" >> "$out"
    return 0
  fi
  write_slice "$c" "$sl"                                                 # step 2 writes + merges, then STOPS
  echo "tree_after_step2.engine=$(run_probe "$c/$ENGINE_C")" >> "$out"
  if [ "$re" = pre ]; then cp -R "$W/$name.pre" "$s2"; else snapshot "$c" "$s2"; fi   # the re-invoke LOADS the logic
  echo "inv2.step1=$(run_probe "$s2/$STEP1_C")" >> "$out"
  echo "inv2.step3=$(run_probe "$s2/$ENGINE_C")" >> "$out"
  left="$(not_at_theirs "$c" "$sl")"; echo "inv2.slice_left=$(printf '%s\n' "$left" | cnt)" >> "$out"
}
val() { grep -m1 "^$2=" "$W/$1.out" | cut -d= -f2-; }

# ---- the cases ------------------------------------------------------------------------------------
flow base "$RECON/setup-sites.md" 0 live
eq "slice derived from the real machinery list: reconcile engine is in it"        "$(val base slice.has_engine)" "1"
eq "slice derived from the real machinery list: core/scripts step-1 probe is in it" "$(val base slice.has_step1)" "1"
eq "slice control: a rulebook file that changed A->B is NOT in the slice"          "$(val base slice.has_rulebook)" "0"
eq "slice size: exactly the two machinery paths"                                   "$(val base slice.n)" "2"
eq "invocation 1 step 1 ran the PRE-update probe (control: not live in the first pass)" "$(val base inv1.step1)" "STEP1-MARKER A"
eq "step 2 wrote and merged the slice into the consumer tree"                       "$(val base tree_after_step2.engine)" "ENGINE-MARKER B"
eq "re-invoke: step 3 runs the NEW reconcile engine on the delivering pull"          "$(val base inv2.step3)" "ENGINE-MARKER B"
eq "re-invoke: the fresh invocation's own step 1 is the new probe"                   "$(val base inv2.step1)" "STEP1-MARKER B"
eq "second invocation's slice is empty by CONTENT (the cycle terminates)"            "$(val base inv2.slice_left)" "0"

flow defer "$RECON/setup-sites.md" 1 live
eq "DEFER: step 2 wrote nothing, the tree still holds the old engine"             "$(val defer tree_after_step2.engine)" "ENGINE-MARKER A"
eq "DEFER: step 3 of the delivering invocation runs the OLD engine"                "$(val defer inv1.step3)" "ENGINE-MARKER A"
eq "DEFER: the carried slice is live once step 7 has landed it"                   "$(val defer after7.step3)" "ENGINE-MARKER B"

# UN-SYNCED world, one property apart from DEFER (neither writes in step 2; DEFER lands at step 7, UN-SYNCED never does).
# Modelled (SKILL.md step 2): "On a branch step 1 left UN-SYNCED, step 2 DEFERS a non-empty slice, before the gate.
# Do not run `reconcile/self-update-gate.sh`, do not cut the self-update branch, do not write the slice ... then
# continue to step 3." / "step 6 refuses that apply on this state, so nothing records the slice for later" /
# "No self-update landed, so the re-invoke rule below does not fire and steps 3-5 run on this invocation's logic."
n="$(grep -cF -- "On a branch step 1 left UN-SYNCED, step 2 DEFERS a non-empty slice" "$SKILL")" || n=0
eq "SKILL.md carries the UN-SYNCED passage" "$n" "1"
flow unsynced "$RECON/setup-sites.md" 2 live
eq "UN-SYNCED: slice is non-empty (2) yet nothing is written" "$(val unsynced slice.n) $(val unsynced tree_after_step2.engine)" "2 ENGINE-MARKER A"
eq "UN-SYNCED: step 3 of the delivering invocation runs the OLD engine, no re-invoke" "$(val unsynced inv1.step3)" "ENGINE-MARKER A"
eq "UN-SYNCED: no self-update branch cut (main only) and both slice paths still unwritten" "$(val unsynced branches) $(val unsynced slice_left_unwritten)" "1 2"
eq "self-probe: UN-SYNCED step 3 (A) and OK re-invoke step 3 (B) differ" \
   "$( [ "$(val unsynced inv1.step3)" != "$(val base inv2.step3)" ] && echo differ || echo same )" "differ"
eq "UN-SYNCED vs DEFER: same step 3 value, but only DEFER lands at step 7" "$(val unsynced inv1.step3)/$(val defer inv1.step3)/$(val defer after7.step3)" "ENGINE-MARKER A/ENGINE-MARKER A/ENGINE-MARKER B"

# ---- mutants: each must change a value the cases assert, and is proven to apply --------------------
# M1: the simulated re-invoke reads the engine from the PRE-step-2 tree.
flow m1 "$RECON/setup-sites.md" 0 pre
eq "M1 applies: the re-invoke snapshot differs from the merged tree" \
   "$( [ "$(val m1 tree_after_step2.engine)" != "$(val m1 inv2.step3)" ] && echo differs || echo same )" "differs"
eq "M1 killed: the base case's inv2.step3 assertion fails on it" \
   "$( [ "$(val m1 inv2.step3)" = "$(val base inv2.step3)" ] && echo survived || echo killed )" "killed"
eq "M1 control: its step-2 write still happened (only the re-invoke source is mutated)" "$(val m1 tree_after_step2.engine)" "ENGINE-MARKER B"

# M2: the slice excludes reconcile/* (the ai-dlc-update subtree line removed from the machinery: list).
SS2="$W/setup-sites.m2.md"
# The same line also sits in the core_manifest: block, which machinery_paths() never reads; the anchor
# and the deletion are both scoped to the machinery: block, the block the shipped reader consumes.
mblock() { awk -v want="$1" '/^machinery:/{f=1;next} f&&/^  - /{ if ($0 == want) c++; next } f{exit} END{print c+0}' "$RECON/setup-sites.md"; }
n="$(mblock '  - core/skills/ai-dlc-update/**')"
z="$(mblock '  - core/skills/ai-dlc-update/ZZ-NEVER')"
eq "M2 anchor is unique in the machinery: block (control: an impossible anchor returns 0)" "$n $z" "1 0"
awk '/^machinery:/{f=1} f&&$0=="  - core/skills/ai-dlc-update/**"{next} f&&!/^machinery:/&&!/^  - /{f=0} {print}' "$RECON/setup-sites.md" > "$SS2"
if cmp -s "$RECON/setup-sites.md" "$SS2"; then bad "M2 DID NOT APPLY"; else ok "M2 applies: mutated list differs from the real one"; fi
flow m2 "$SS2" 0 live
eq "M2 killed: the slice no longer holds the reconcile engine"                     "$(val m2 slice.has_engine)" "0"
eq "M2 killed: step 3 after the re-invoke still runs the OLD engine"                "$(val m2 inv2.step3)" "ENGINE-MARKER A"
eq "M2 control: the step-1 probe is still in the slice (only the engine entry was removed)" "$(val m2 slice.has_step1)" "1"

# ---- self-probe: the harness distinguishes A from B in the same invocation -------------------------
eq "self-probe: re-invoke step 3 (B) and DEFER step 3 (A) are different values" \
   "$( [ "$(val base inv2.step3)" != "$(val defer inv1.step3)" ] && echo differ || echo same )" "differ"

if [ "$FAILS" -eq 0 ]; then echo "PASS self-update-reinvoke-liveness"; exit 0; fi
echo "FAILED $FAILS"; exit 1
