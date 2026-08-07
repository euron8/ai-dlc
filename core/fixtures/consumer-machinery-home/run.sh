#!/usr/bin/env bash
# consumer-machinery-home — assert I43 and I44 cannot go quiet.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THESE EXIST TO CATCH. `scripts/ai-dlc-local/` — the directory the core-guard
# tells an author to put their own pipeline tooling in when it refuses a write under
# `scripts/ai-dlc/` — was written out by hand in FIVE shipped surfaces and declared as
# data in none: the guard's deny reason and its additionalContext, the LOCAL_DIR default
# in reconcile/warn-shadowed-local-validators.sh, two fixtures, and core-manifest.md's
# prose. Nothing compared them.
#
# That is the affordance-is-the-defect shape. The guard PROMISES the home; the promise was
# the only thing holding the value. Rename it in one surface and the guard keeps routing
# authors to a directory the reader never walks — and BOTH halves stay green, because each
# is internally consistent with itself. core-manifest.md and the guard also both promise,
# in those words, that core "never reads, never writes and never overwrites" the home, and
# nothing asserted that either; a manifest entry landing under it would make the promise
# false while every reader of the prose still believed it.
#
# So the assertions below are about the CHECKS, not about today's path. That the tree
# spells the home consistently right now proves nothing. What must hold is that a rename
# in one surface, a guard that stops routing there, a divergence between the two
# declarations, a missing declaration, and an installer target under the home each FAIL.
#
# MUTATION DISCIPLINE. Every mutation is applied to a COPY of the target file and moved
# into place, never edited in situ, and it is `cmp -s`-guarded: the mutated file must
# differ from the original, because a sed that matched nothing cannot pass as a mutation.
# Each assertion asserts a POSITIVE outcome — the specific message its own arm emits — and
# no two assert the same string, so a mutant that fires the wrong arm is a failure here
# rather than a pass.
#
# ONE TREE PER ASSERTION, AND IT REPLACES THE RESTORE DISCIPLINE RATHER THAN RELAXING IT.
# The serial version of this file mutated ONE shared tree and restored it between arms, so
# it needed `unmutate` to prove each restore landed and a closing sweep to prove all five
# files came back — a silently-failed restore would have left the previous mutation live and
# made every later assertion a false pass. Each assertion now runs in its own process against
# its own seeded tree and never sees another's bytes, so that failure has no way to occur:
# the hazard is removed, not merely detected. What is load-bearing — the `cmp -s` proof that
# the mutation landed at all — stays, and it stays inside the worker where the copy is made.
#
# WHY A POOL AT ALL: the suite's critical path. Seven runs of a ~8.5s validator, end to end,
# cost 58s standalone and ~190s inside the 16-way pre-push suite, and that suite is
# POLE-BOUND — its makespan tracks its single longest unit (measured 268s against a 268s wall
# clock). An internally-serial fixture therefore sets the wall clock for the whole push no
# matter what AI_DLC_FIXTURE_JOBS is set to.
#
# THE ALIEN TOKENS ARE ASSEMBLED, NOT WRITTEN. This file lives under core/fixtures/, which
# is inside I43's own forward scan, and that scan rejects any home spelling other than the
# two real ones. A mutation that wrote its alien path as a literal would therefore make I43
# fire on THIS FILE against the PRISTINE tree, and assertion 0 would report the fixture
# broken — which is exactly what happened twice while this was being written, once for the
# seds and once for a comment describing them. The seds below build their alien paths by
# concatenating core's own prefix at runtime, so no extra spelling exists on disk, and this
# comment describes the shape rather than reproducing it.
set -uo pipefail

# This fixture names a hook by path (it mutates the guard's deny TEXT; it never drives the
# hook). Scrub anyway — a fixture that touches hook files costs nothing to make hermetic,
# and I10's keyword scan is deliberately wider than "actually executes one".
#
# Ordered before HERE= and before the pool: the worker wrapper resolves its own variables in
# its `bash -c` ahead of anything it invokes, so unsetting them here cannot reach values that
# have already been resolved.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"

# Built from a prefix that IS core's own home, so neither literal appears in this file.
_CORE_HOME='scripts/ai-dlc'
ALIEN_RENAME="${_CORE_HOME}-elsewhere"
ALIEN_SITES="${_CORE_HOME}-mine"

# Distribution-only. `validate-enforcement-map.sh` is not shipped by install.sh (it checks
# the distribution's own writers against each other — a consumer has neither), so in a
# consumer tree there is nothing to test. Say so and stop; do not fake a pass.
if [ ! -f "$HERE/../../../scripts/validate-enforcement-map.sh" ]; then
  echo "consumer-machinery-home: SKIP — distribution-only (validate-enforcement-map.sh is not shipped to consumers)"
  exit 0
fi

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# The five mutable surfaces, as paths RELATIVE to a seeded root — each worker seeds its own,
# so an absolute path resolved here would point every worker at one tree and put back exactly
# the sharing this file now exists without.
MANIFEST_REL='core/skills/ai-dlc/core-manifest.md'
SITES_REL='core/skills/ai-dlc-update/reconcile/setup-sites.md'
GUARD_REL='core/hooks/ai-dlc-core-guard.sh'
WARN_REL='core/skills/ai-dlc-update/reconcile/warn-shadowed-local-validators.sh'
INSTALL_REL='scripts/install.sh'

RUNS="$WORK/runs"; : > "$RUNS"
SEDS="$WORK/seds"; mkdir -p "$SEDS"
OUTD="$WORK/out";  mkdir -p "$OUTD"

# reg <kind> <label> <relative-file> <sed program> <expected substring>
#
# The sed program goes to a FILE rather than into the registry. These programs carry `#`
# delimiters, `$` anchors and the assembled alien paths, and one that arrived at the worker
# subtly re-quoted would still apply, still satisfy `cmp -s`, and prove something other than
# what its call site says.
#
# PHASE 1 IS REGISTRATION ONLY. The arms below, and their reasoning, are in declaration order
# and the report is rendered in that same order — which is what keeps this fixture's stdout
# byte-comparable against the serial version it replaces.
reg() {
  printf '%s' "$4" > "$SEDS/$2.sed"
  printf '%s\t%s\t%s\t%s\n' "$1" "$2" "$3" "$5" >> "$RUNS"
}

echo "consumer-machinery-home:"

# --- Assertion 0: SANITY ------------------------------------------------------
# The pristine tree must PASS. If it does not, the validator is erroring for a reason of
# its own and every "it failed as expected" below is a false pass.
reg sanity a0-sanity '' '' ''

# --- Assertion 1: I43 forward — a rename in ONE surface ------------------------
# THE headline defect: the READER drifts from the ROUTER. The guard still sends authors to
# the declared home and both declarations still agree, so every other arm is clean; only
# `warn-shadowed-local-validators.sh` now walks somewhere else, and it walks it silently
# because an absent directory is its documented no-op. Before I43 nothing compared them.
#
# The READER, not the guard, deliberately. Renaming the home in the GUARD fires two arms at
# once — it introduces an alien spelling AND stops the guard naming the declared home — so
# it cannot isolate either. Measured: 2 FAIL lines. This mutant fires exactly one.
reg fires a1-reader-rename "$WARN_REL" "s#${_CORE_HOME}-local#${ALIEN_RENAME}#g" \
    "is neither core's own"

# --- Assertion 2: I43 reverse — the guard stops routing to the home -----------
# Distinct from assertion 1: nothing invents a second spelling, the guard simply stops
# naming the home at all. The forward arm sees a clean token set and passes. Only the
# reverse arm can see that the declared home is now an address no affordance points at.
#
# EVERY occurrence, not one. The guard names the home twice — once in the deny `reason`
# the author reads and once in the `additionalContext` — and a mutation that struck only
# the first came out GREEN here, because one surviving mention still answers "does the
# guard route there at all". That is the partial-revert trap: the mutant proved the
# occurrence it left in place. `g`, and the assertion below is what caught it.
reg fires a2-guard-unroutes "$GUARD_REL" "s#${_CORE_HOME}-local##g" \
    "appears nowhere in core/hooks/ai-dlc-core-guard.sh"

# --- Assertion 3: I43 — the two declarations diverge --------------------------
# ai-dlc-update reads its own copy (its HARD CONSTRAINT forbids reading core-manifest.md
# at runtime); everything else reads the manifest's. Divergence routes the guard to one
# directory and the reader to another, with each file internally consistent.
reg fires a3-declarations-diverge "$SITES_REL" \
    "s#^consumer_machinery_home: .*#consumer_machinery_home: ${ALIEN_SITES}/#" \
    "differs between its two declarations"

# --- Assertion 4: I43 — the declaration is absent ------------------------------
# The zero-guard. With no declaration there is nothing to compare any surface against, and
# a check that reads an empty value would otherwise report the same line as agreement.
reg fires a4-declaration-absent "$MANIFEST_REL" '/^consumer_machinery_home:/d' \
    "could not read 'consumer_machinery_home:'"

# --- Assertion 5: I44 — core installs into the home ---------------------------
# core-manifest.md and the guard both promise core "never reads, never writes and never
# overwrites" this directory. This is the mutation that makes the promise false.
reg fires a5-installs-into-home "$INSTALL_REL" \
    's#^mkdir -p "$PROJECT_ROOT/scripts/ai-dlc"$#mkdir -p "$PROJECT_ROOT/scripts/ai-dlc"\
mkdir -p "$PROJECT_ROOT/scripts/ai-dlc-local/lib"#' \
    "core writes or claims path(s) under the consumer machinery home"

# --- Assertion 6: UNMUTATED CONTROL -------------------------------------------
# A SECOND pristine seed, never mutated, run independently of assertion 0. With one tree per
# assertion it is no longer catching a failed restore — there is nothing to restore — but it
# still answers the question that makes every kill above interpretable: does a freshly seeded
# copy of this tree come out clean, reproducibly, and not just the first time? A seed that
# passed once and not again would otherwise show up as whichever mutant happened to run on
# the bad copy.
reg control a6-control '' '' ''

# ==================== PHASE 2: seed, mutate and validate, in a pool ====================
# The zero guard: a registration grammar that stopped filling yields an empty list, and an
# empty list passes every assertion it never made.
N_RUNS="$(grep -c . "$RUNS" || true)"
if [ "$N_RUNS" -lt 7 ]; then
  echo "FIXTURE ERROR: registered only $N_RUNS run(s) — the registry did not fill, so nothing below is evidence" >&2
  exit 2
fi

# SEVEN, and fixed rather than tunable for the reason the sibling pools state in place: this
# pool nests inside the pre-push suite's own, so a knob here multiplies against the knob
# there and the PRODUCT is what lands on the machine. Seven is the run count; a wider pool
# than there is work is pure contention for the sibling fixtures.
CMH_JOBS=7
CMH_HERE="$HERE" CMH_SEDS="$SEDS" CMH_OUT="$OUTD" CMH_RUNS="$RUNS" \
  xargs -P "$CMH_JOBS" -I{} bash -c '
    l="$1"
    f="$(awk -F"\t" -v k="$l" "\$2==k{print \$3}" "$CMH_RUNS")"
    root="$(bash "$CMH_HERE/seed.sh")" || { printf SEEDFAIL > "$CMH_OUT/$l.state"; printf done > "$CMH_OUT/$l.done"; exit 0; }
    if [ -n "$f" ]; then
      sed -f "$CMH_SEDS/$l.sed" "$root/$f" > "$root/$f.mut" 2>/dev/null
      if cmp -s "$root/$f" "$root/$f.mut"; then
        printf VACUOUS > "$CMH_OUT/$l.state"
        printf done    > "$CMH_OUT/$l.done"
        rm -rf "$root"; exit 0
      fi
      mv "$root/$f.mut" "$root/$f"
    fi
    bash "$root/scripts/validate-enforcement-map.sh" > "$CMH_OUT/$l.out" 2>&1
    printf %s $? > "$CMH_OUT/$l.rc"
    printf done  > "$CMH_OUT/$l.done"
    rm -rf "$root"
  ' _ {} < <(cut -f2 "$RUNS")

# ================= PHASE 3: evaluate, serially, in DECLARATION order =================
while IFS=$'\t' read -r kind label file want; do
  [ -n "$label" ] || continue

  # A MISSING VERDICT IS A FAILURE, not a gap. `.done` is written after the run, so its
  # absence means the pool dropped the job — which otherwise contributes exactly what a
  # passing assertion contributes: nothing.
  if [ ! -f "$OUTD/$label.done" ]; then
    bad "$label produced no verdict — the pool dropped work, and a short green run reads exactly like a passing one"
    continue
  fi

  if [ -f "$OUTD/$label.state" ]; then
    case "$(cat "$OUTD/$label.state")" in
      SEEDFAIL)
        echo "FIXTURE ERROR: seed failed for $label" >&2
        echo; echo "consumer-machinery-home: $((fails + 1)) assertion(s) FAILED" >&2; exit 2 ;;
      VACUOUS)
        bad "MUTATION VACUOUS — the sed program matched nothing in ${file##*/}, so the tree is unchanged and the assertion below would score a clean run as a kill" ;;
    esac
    continue
  fi

  out="$(cat "$OUTD/$label.out" 2>/dev/null)"
  rc="$(cat "$OUTD/$label.rc" 2>/dev/null)"

  case "$kind" in
    sanity)
      if [ "$rc" = "0" ]; then
        ok "pristine distribution tree passes (the negatives below mean something)"
      else
        bad "FIXTURE BROKEN — the pristine tree does not pass validate-enforcement-map.sh. Every assertion below would be a false pass."
        echo; echo "consumer-machinery-home: $fails assertion(s) FAILED" >&2; exit 2
      fi ;;

    control)
      if [ "$rc" = "0" ]; then
        ok "an unmutated control copy still passes (the harness itself is not what failed)"
      else
        bad "CONTROL FAILED — an unmutated copy of the tree does not pass. The assertions above tested the fixture's own machinery, not the invariants."
      fi ;;

    # Non-zero alone is not evidence: it is what a broken validator does. The message must
    # be the arm's own.
    fires)
      case "$label" in
        a1-reader-rename)        lbl="renaming the home in ONE surface (the reader's LOCAL_DIR) FAILS — a spelling no declaration knows about can no longer ship" ;;
        a2-guard-unroutes)       lbl="a guard whose deny text no longer routes to the declared home FAILS — a home no affordance points at is one no author finds" ;;
        a3-declarations-diverge) lbl="the two declarations diverging FAILS — the reader and the router can no longer be pointed at different homes" ;;
        a4-declaration-absent)   lbl="deleting the declaration FAILS LOUDLY rather than comparing nothing and passing" ;;
        a5-installs-into-home)   lbl="an installer target under the home FAILS — the never-writes promise is now asserted, not just stated" ;;
        *)                       lbl="$label" ;;
      esac
      if [ "$rc" = "0" ]; then
        bad "$lbl — the validator still EXITED 0 on the mutated tree"
      elif grep -qF "$want" <<<"$out"; then
        ok "$lbl"
      else
        bad "$lbl — the validator failed, but not with its own message. Expected to see: $want"
      fi ;;
  esac
done < "$RUNS"

echo
if [ "$fails" -eq 0 ]; then
  echo "consumer-machinery-home: all assertions hold"
  exit 0
fi
echo "consumer-machinery-home: $fails assertion(s) FAILED" >&2
exit 1
