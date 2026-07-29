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
# into place, never edited in situ, and each one is `cmp -s`-guarded in BOTH directions:
# the mutated file must differ from the original (a sed that matched nothing cannot pass
# as a mutation), and the restored file must be byte-identical again (a restore that
# silently failed would make every later assertion a false pass). Each assertion asserts a
# POSITIVE outcome — the specific message its own arm emits — and no two assert the same
# string, so a mutant that fires the wrong arm is a failure here rather than a pass.
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

ROOT="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$ROOT"' EXIT

V="$ROOT/scripts/validate-enforcement-map.sh"
MANIFEST="$ROOT/core/skills/ai-dlc/core-manifest.md"
SITES="$ROOT/core/skills/ai-dlc-update/reconcile/setup-sites.md"
GUARD="$ROOT/core/hooks/ai-dlc-core-guard.sh"
WARN="$ROOT/core/skills/ai-dlc-update/reconcile/warn-shadowed-local-validators.sh"
INSTALL="$ROOT/scripts/install.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

SAVE="$ROOT/.fixture-save"
mkdir -p "$SAVE"

# mutate <file> <sed-program> — apply to a COPY, guard that bytes actually changed.
# Returns 1 (and leaves the original in place) if the sed matched nothing.
mutate() {
  local f="$1" prog="$2" b; b="$(basename "$f")"
  cp "$f" "$SAVE/$b"
  sed "$prog" "$SAVE/$b" > "$SAVE/$b.mut"
  if cmp -s "$SAVE/$b" "$SAVE/$b.mut"; then
    bad "MUTATION VACUOUS — the sed program matched nothing in $b, so the tree is unchanged and the assertion below would score a clean run as a kill"
    return 1
  fi
  cp "$SAVE/$b.mut" "$f"
}

# unmutate <file> — restore and PROVE the restore landed. A silently-failed restore
# leaves the previous mutation live and turns every later assertion into a false pass.
unmutate() {
  local f="$1" b; b="$(basename "$f")"
  cp "$SAVE/$b" "$f"
  cmp -s "$SAVE/$b" "$f" || { echo "FIXTURE ERROR: restore of $b did not land" >&2; exit 2; }
}

# fires <expected-substring> <label> — run the validator, require non-zero AND the
# expected message. Non-zero alone is not evidence: it is what a broken validator does.
fires() {
  local want="$1" label="$2" out rc
  out="$(bash "$V" 2>&1)"; rc=$?
  if [ "$rc" -eq 0 ]; then
    bad "$label — the validator still EXITED 0 on the mutated tree"
  elif grep -qF "$want" <<<"$out"; then
    ok "$label"
  else
    bad "$label — the validator failed, but not with its own message. Expected to see: $want"
  fi
}

echo "consumer-machinery-home:"

# --- Assertion 0: SANITY ------------------------------------------------------
# The pristine tree must PASS. If it does not, the validator is erroring for a reason of
# its own and every "it failed as expected" below is a false pass.
if bash "$V" >/dev/null 2>&1; then
  ok "pristine distribution tree passes (the negatives below mean something)"
else
  bad "FIXTURE BROKEN — the pristine tree does not pass validate-enforcement-map.sh. Every assertion below would be a false pass."
  echo; echo "consumer-machinery-home: $fails assertion(s) FAILED" >&2; exit 2
fi

# --- Assertion 1: I43 forward — a rename in ONE surface ------------------------
# THE headline defect: the READER drifts from the ROUTER. The guard still sends authors to
# the declared home and both declarations still agree, so every other arm is clean; only
# `warn-shadowed-local-validators.sh` now walks somewhere else, and it walks it silently
# because an absent directory is its documented no-op. Before I43 nothing compared them.
#
# The READER, not the guard, deliberately. Renaming the home in the GUARD fires two arms at
# once — it introduces an alien spelling AND stops the guard naming the declared home — so
# it cannot isolate either. Measured: 2 FAIL lines. This mutant fires exactly one.
if mutate "$WARN" "s#${_CORE_HOME}-local#${ALIEN_RENAME}#g"; then
  fires "is neither core's own" \
        "renaming the home in ONE surface (the reader's LOCAL_DIR) FAILS — a spelling no declaration knows about can no longer ship"
  unmutate "$WARN"
fi

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
if mutate "$GUARD" "s#${_CORE_HOME}-local##g"; then
  fires "appears nowhere in core/hooks/ai-dlc-core-guard.sh" \
        "a guard whose deny text no longer routes to the declared home FAILS — a home no affordance points at is one no author finds"
  unmutate "$GUARD"
fi

# --- Assertion 3: I43 — the two declarations diverge --------------------------
# ai-dlc-update reads its own copy (its HARD CONSTRAINT forbids reading core-manifest.md
# at runtime); everything else reads the manifest's. Divergence routes the guard to one
# directory and the reader to another, with each file internally consistent.
if mutate "$SITES" "s#^consumer_machinery_home: .*#consumer_machinery_home: ${ALIEN_SITES}/#"; then
  fires "differs between its two declarations" \
        "the two declarations diverging FAILS — the reader and the router can no longer be pointed at different homes"
  unmutate "$SITES"
fi

# --- Assertion 4: I43 — the declaration is absent ------------------------------
# The zero-guard. With no declaration there is nothing to compare any surface against, and
# a check that reads an empty value would otherwise report the same line as agreement.
if mutate "$MANIFEST" '/^consumer_machinery_home:/d'; then
  fires "could not read 'consumer_machinery_home:'" \
        "deleting the declaration FAILS LOUDLY rather than comparing nothing and passing"
  unmutate "$MANIFEST"
fi

# --- Assertion 5: I44 — core installs into the home ---------------------------
# core-manifest.md and the guard both promise core "never reads, never writes and never
# overwrites" this directory. This is the mutation that makes the promise false.
if mutate "$INSTALL" 's#^mkdir -p "$PROJECT_ROOT/scripts/ai-dlc"$#mkdir -p "$PROJECT_ROOT/scripts/ai-dlc"\nmkdir -p "$PROJECT_ROOT/scripts/ai-dlc-local/lib"#'; then
  fires "core writes or claims path(s) under the consumer machinery home" \
        "an installer target under the home FAILS — the never-writes promise is now asserted, not just stated"
  unmutate "$INSTALL"
fi

# --- Assertion 6: UNMUTATED CONTROL -------------------------------------------
# Five mutate/unmutate cycles have run over four files. A restore that silently failed, or
# a `sed` that left a byte behind, would make everything above unreliable — and the visible
# symptom of a broken harness is a clean run, indistinguishable from a healthy one. This is
# a SECOND pristine seed from the same directory, never mutated, so it fails only if the
# fixture's own machinery is what broke.
CTRL="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: control seed failed" >&2; exit 2; }
if bash "$CTRL/scripts/validate-enforcement-map.sh" >/dev/null 2>&1; then
  ok "an unmutated control copy still passes (the harness itself is not what failed)"
else
  bad "CONTROL FAILED — an unmutated copy of the tree does not pass. The assertions above tested the fixture's own machinery, not the invariants."
fi
rm -rf "$CTRL"

# Prove the working tree came back too: every mutated file byte-identical to its save.
for f in "$GUARD" "$WARN" "$SITES" "$MANIFEST" "$INSTALL"; do
  b="$(basename "$f")"
  [ -f "$SAVE/$b" ] || continue
  cmp -s "$SAVE/$b" "$f" || bad "RESTORE INCOMPLETE — $b did not return to its pristine bytes; the assertion ordering above is not trustworthy"
done

echo
if [ "$fails" -eq 0 ]; then
  echo "consumer-machinery-home: all assertions hold"
  exit 0
fi
echo "consumer-machinery-home: $fails assertion(s) FAILED" >&2
exit 1
