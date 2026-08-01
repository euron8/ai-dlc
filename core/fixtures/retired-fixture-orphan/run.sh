#!/usr/bin/env bash
# retired-fixture-orphan — assert the detector sees a core fixture the consumer still
# carries after core stopped shipping it, and stays silent on the consumer's own.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH. `install.sh` and `apply.sh` copy a core fixture into
# the consumer. When core later marks it `.dist-only` — or deletes it — both stop copying
# it, correctly, and the copy already installed becomes unreachable by every mechanism core
# has. It is not drift (nobody edited it) and not a missing file (the consumer has one), so
# no bucket claims it. It freezes at whatever core last shipped, forever.
#
# Measured on the reference consumer at 0.232.0: `tests/fixtures/enforcement-map-sites/`
# was core's copy from 2026-07-14, 110 lines against core's 1,782 that day, carried for 177
# releases after core marked the fixture `.dist-only`.
#
# WHY THIS FIXTURE SEEDS ITS OWN ORPHAN RATHER THAN POINTING AT ONE. The reference
# consumer's single live instance was retired by hand in the same week this shipped, so an
# arm anchored to it would have gone quiet on a clean tree and read exactly like a passing
# check. Every subject below is built here, at runtime, in a scratch repo.
#
# THE FOUR HALVES ARE EQUALLY LOAD-BEARING:
#   1. arm A fires on a `.dist-only` fixture the consumer still holds
#   2. arm B fires on a fixture core DELETED, distinguished from the consumer's own
#      ONLY by core's history — which is the half that makes the arm shippable
#   3. the consumer's OWN fixture stays silent. Without this the arm reports 28 false
#      positives on the reference consumer's first run and gets switched off.
#   4. arm B REFUSES rather than answering when core's history is unavailable. A shallow
#      clone answers empty for every candidate, and a check that cannot fire reads exactly
#      like one that passed.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

# The real reconcile directory, resolved INDEPENDENTLY of the detector under test. The
# detector delegates its path mapping to `preclassify.sh` beside it, so a mutant copy living
# in a scratch directory has no mapper — the first cut resolved the mapper from the
# detector's own dirname and every mutant run died with a FIXTURE ERROR before reaching an
# assertion, which the battery then read as zero reds and scored as a survival.
if [ -n "$ROOT" ] && [ -d "$ROOT/core/skills/ai-dlc-update/reconcile" ]; then
  SRC_DIR="$ROOT/core/skills/ai-dlc-update/reconcile"
elif [ -n "$ROOT" ] && [ -d "$ROOT/.claude/skills/ai-dlc-update/reconcile" ]; then
  SRC_DIR="$ROOT/.claude/skills/ai-dlc-update/reconcile"
else
  echo "FIXTURE ERROR: reconcile/ not found in either layout" >&2
  exit 2
fi

if false; then :
elif [ -n "${AI_DLC_RFO_DETECT:-}" ] && [ -f "${AI_DLC_RFO_DETECT}" ]; then
  # The mutant battery at the foot of this file re-executes this script with a MUTATED copy
  # of the detector. Without this arm the re-run silently exercised the real detector, every
  # mutant reported zero reds, and the unmutated control passed for the same wrong reason —
  # caught only because five kills arriving at once is not a thing a real battery does.
  DETECT="${AI_DLC_RFO_DETECT}"
elif [ -n "$ROOT" ] && [ -f "$ROOT/core/skills/ai-dlc-update/reconcile/retired-fixtures.sh" ]; then
  DETECT="$ROOT/core/skills/ai-dlc-update/reconcile/retired-fixtures.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/.claude/skills/ai-dlc-update/reconcile/retired-fixtures.sh" ]; then
  DETECT="$ROOT/.claude/skills/ai-dlc-update/reconcile/retired-fixtures.sh"
else
  echo "FIXTURE ERROR: retired-fixtures.sh not found in either layout" >&2
  exit 2
fi

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

git_q() { git -C "$1" -c user.email=f@x -c user.name=f -c commit.gpgsign=false "${@:2}" >/dev/null 2>&1; }

# ---------------------------------------------------------------- the scratch distribution
# A real git repo, because arm B's whole predicate is a history question and a fake one
# would let the arm pass on a tree where the real thing cannot answer.
DIST="$WORK/dist"
mkdir -p "$DIST/core/skills/ai-dlc-update/reconcile"
cp "$DETECT" "$DIST/core/skills/ai-dlc-update/reconcile/retired-fixtures.sh"
# The mapper is delegated, not copied — so the fixture must supply the real one, and a
# change to map_consumer() that broke fixture paths would fail here rather than silently.
awk '/^map_consumer\(\) \{/,/^\}/' \
  "$SRC_DIR/preclassify.sh" > "$DIST/core/skills/ai-dlc-update/reconcile/preclassify.sh" 2>/dev/null
if ! grep -q 'core/fixtures' "$DIST/core/skills/ai-dlc-update/reconcile/preclassify.sh"; then
  echo "FIXTURE ERROR: could not extract map_consumer() with its core/fixtures arm" >&2; exit 2
fi

for n in still-shipped will-be-distonly will-be-deleted; do
  mkdir -p "$DIST/core/fixtures/$n"
  printf '#!/usr/bin/env bash\necho %s\n' "$n" > "$DIST/core/fixtures/$n/run.sh"
done
git_q "$DIST" init -q .
git_q "$DIST" add -A
git_q "$DIST" commit -m "seed: three fixtures, all shipped"

# Core retires two of them, in the two different ways.
: > "$DIST/core/fixtures/will-be-distonly/.dist-only"
rm -rf "$DIST/core/fixtures/will-be-deleted"
git_q "$DIST" add -A
git_q "$DIST" commit -m "retire: one marked .dist-only, one deleted"
THEIRS="$(git -C "$DIST" rev-parse HEAD)"

# ---------------------------------------------------------------- the scratch consumer
# It holds all three core fixtures (installed before the retirement) plus one of its own.
CONS="$WORK/consumer"
for n in still-shipped will-be-distonly will-be-deleted consumer-authored-only; do
  mkdir -p "$CONS/tests/fixtures/$n"
  printf '#!/usr/bin/env bash\necho %s\n' "$n" > "$CONS/tests/fixtures/$n/run.sh"
done

UNDER_TEST="$DIST/core/skills/ai-dlc-update/reconcile/retired-fixtures.sh"
out="$(bash "$UNDER_TEST" "$DIST" "$THEIRS" "$CONS" 2>/dev/null)"
rc=$?

# --- the run itself is a control: a detector that died reports nothing, which is also
# --- what a clean tree reports.
[ "$rc" -eq 0 ] && ok "detector exits 0 (classifier, never blocks)" \
                || bad "detector exited $rc — a classifier must never block"
[ -n "$out" ] && ok "detector produced output (the run is not a silent death)" \
              || bad "detector produced NOTHING — every assertion below would pass vacuously"

n_orph="$(printf '%s\n' "$out" | grep -c '^RETIRED-FIXTURE-ORPHAN' || true)"

# 1. arm A — the .dist-only fixture the consumer still holds
if grep -q '^RETIRED-FIXTURE-ORPHAN.*tests/fixtures/will-be-distonly' <<<"$out"; then
  ok "arm A reports the .dist-only fixture the consumer still carries"
else
  bad "arm A MISSED the .dist-only orphan — the lifecycle hole this ships to close"
fi

# 2. arm B — the fixture core deleted outright
if grep -q '^RETIRED-FIXTURE-ORPHAN.*tests/fixtures/will-be-deleted' <<<"$out"; then
  ok "arm B reports the fixture core DELETED"
else
  bad "arm B MISSED the deleted fixture — only history separates it from a consumer's own"
fi

# 3. the two that must stay silent. This is the false-positive half, and on the reference
#    consumer it is 28 directories wide.
if grep -q 'consumer-authored-only' <<<"$out"; then
  bad "the consumer's OWN fixture was reported — 28 false positives on the reference consumer"
else
  ok "the consumer's own fixture is silent (core's history never had it)"
fi
if grep -q 'still-shipped' <<<"$out"; then
  bad "a fixture core STILL SHIPS was reported as an orphan"
else
  ok "a still-shipped fixture is silent"
fi

# 4. nothing OUTSIDE the four seeded names. This catches an arm that reports everything and
#    happens to include the right answers.
#
#    IT IS DELIBERATELY NOT A COUNT. `[ "$n_orph" -eq 2 ]` was the first cut, and it is
#    entangled with assertions 1, 2 and 3 by construction: any mutant that drops arm A moves
#    the count too, so it would fail two assertions and §7 says one of them is then vacuous.
#    Scoped to subjects outside the seeded set, this cell moves on its own.
extra="$(printf '%s\n' "$out" | grep '^RETIRED-FIXTURE-ORPHAN' \
  | grep -vE 'will-be-distonly|will-be-deleted|consumer-authored-only|still-shipped' | grep -c . || true)"
if [ "$extra" -eq 0 ]; then
  ok "no orphan reported outside the seeded set (${n_orph} reported, all of them seeded)"
else
  bad "${extra} orphan(s) reported outside the seeded set — the arm's subject set is wider than its predicate"
fi

# 5. the remedy names the consumer's path, not core's. An operator reads this line while
#    deciding whether to delete a directory.
if grep -q 'rm -rf <consumer>/tests/fixtures/will-be-distonly' <<<"$out"; then
  ok "the remedy names the consumer path the operator must remove"
else
  bad "the remedy does not name a removable consumer path — an un-transcribable remedy"
fi

# ---------------------------------------------------------------- 6. the zero guard
# Arm B's question is answerable only from history. Strip it and the arm must REFUSE,
# not answer zero. Built by re-cloning to depth 1 rather than by deleting refs, so the
# repo is a shape git itself produces.
SHALLOW="$WORK/shallow"
if git clone -q --depth 1 "file://$DIST" "$SHALLOW" 2>/dev/null && [ -d "$SHALLOW/.git" ]; then
  s_out="$(bash "$UNDER_TEST" "$SHALLOW" HEAD "$CONS" 2>/dev/null)"

  # FIRST, PROVE THE STATE UNDER TEST WAS ACTUALLY BUILT, and prove it with the question
  # arm B ASKS rather than with a neighbouring one. The first cut of this fixture gated on
  # `log -- core/fixtures`, which on a depth-1 clone still returns the tip commit — so the
  # arm skipped, the guard was never exercised, and the guard was WRONG (it probed the same
  # surviving path). The deleted directory's own log is the reading that discriminates: 0
  # here, non-zero on the full clone two lines down.
  s_gone="$(git -C "$SHALLOW" log --all --format=%H -- core/fixtures/will-be-deleted 2>/dev/null | grep -c . || true)"
  f_gone="$(git -C "$DIST"    log --all --format=%H -- core/fixtures/will-be-deleted 2>/dev/null | grep -c . || true)"
  if [ "$s_gone" -eq 0 ] && [ "$f_gone" -gt 0 ]; then
    ok "the truncated state IS built: the deleted fixture's history reads 0 here and ${f_gone} on the full clone"

    if grep -q '^RETIRED-FIXTURE-HISTORY-UNAVAILABLE' <<<"$s_out"; then
      ok "arm B REFUSES on a truncated clone instead of answering zero"
    else
      bad "arm B answered silently on a truncated clone — a check that cannot fire reads as one that passed"
    fi

    # Arm A must be UNAFFECTED: it needs no history, and a guard that takes the whole scan
    # down with it would trade one blind spot for a larger one.
    if grep -q 'tests/fixtures/will-be-distonly' <<<"$s_out"; then
      ok "arm A still answers on a truncated clone (it needs no history)"
    else
      bad "arm A went silent with arm B — the guard is too wide"
    fi

    # And the arm must NOT have quietly reported the deleted fixture anyway: refusing and
    # answering are different outcomes, and only one of them is honest here.
    if grep -q 'will-be-deleted' <<<"$s_out"; then
      bad "arm B named the deleted fixture from a clone whose history cannot support that claim"
    else
      ok "arm B makes no claim about the deleted fixture it cannot see"
    fi
  else
    bad "FIXTURE BROKEN: the truncated state was not built (shallow=${s_gone}, full=${f_gone}), so the zero guard was never exercised"
  fi
else
  bad "FIXTURE BROKEN: could not build a shallow clone, so the zero guard was never exercised"
fi

# ---------------------------------------------------------------- 7. the mapper delegation
# The detector must refuse rather than guess when map_consumer() cannot be loaded. A
# private path table here would answer for one layout and be silently wrong in the other.
NOMAP="$WORK/nomap"
cp -R "$DIST" "$NOMAP"
: > "$NOMAP/core/skills/ai-dlc-update/reconcile/preclassify.sh"
if ! cmp -s "$DIST/core/skills/ai-dlc-update/reconcile/preclassify.sh" \
            "$NOMAP/core/skills/ai-dlc-update/reconcile/preclassify.sh"; then
  m_out="$(bash "$NOMAP/core/skills/ai-dlc-update/reconcile/retired-fixtures.sh" "$NOMAP" "$THEIRS" "$CONS" 2>/dev/null)"
  if grep -q '^HARD-RETIRED-FIXTURE-SCAN-UNAVAILABLE' <<<"$m_out"; then
    ok "refuses loudly when map_consumer() cannot be loaded"
  else
    bad "scanned with no path mapper — it would print an empty result that reads as no orphans"
  fi
else
  bad "FIXTURE BROKEN: the no-mapper copy is identical to the original, so nothing was tested"
fi

# ---------------------------------------------------------------- the mutant battery
# Every assertion above is now proven non-vacuous: a copy of the detector is broken in one
# specific way and MUST turn exactly ONE of them red. Two reds means the assertions are
# entangled and one of them is proving nothing, which is why assertion 4 is scoped to
# subjects outside the seeded set rather than being a count.
#
# The mutants are COPIES, never in-place edits, and every one is guarded by `cmp -s` so a
# sed that matched nothing reports itself instead of scoring a kill it did not earn. The
# unmutated control is the arm that catches a battery which is broken as a whole — a copy
# that cannot run emits no FAIL lines, and "no output" would otherwise score as a kill on
# every mutant at once.
#
# Re-entrancy: this whole section runs the fixture's own assertion body against a swapped
# detector, so it is driven by re-executing THIS script with AI_DLC_RFO_DETECT set. The
# recursion is one level deep and the guard below is what ends it.
if [ -n "${AI_DLC_RFO_DETECT:-}" ]; then
  if [ "$fails" -eq 0 ]; then echo "PASS retired-fixture-orphan"; exit 0; fi
  echo "FAIL retired-fixture-orphan ($fails)"; exit 1
fi

MUT="$WORK/mutants"; mkdir -p "$MUT"
mut_reds() {  # $1 = label, $2 = sed program ("" for the unmutated control)
  local label="$1" prog="$2" copy="$MUT/$1.sh"
  if [ -z "$prog" ]; then
    cp "$DETECT" "$copy"
  else
    sed "$prog" "$DETECT" > "$copy" 2>/dev/null
    if cmp -s "$DETECT" "$copy"; then
      printf 'UNMUTATED\n'; return 0        # the sed matched nothing — say so, never pass
    fi
  fi
  AI_DLC_RFO_DETECT="$copy" bash "$HERE/run.sh" 2>/dev/null | grep '^  FAIL  ' | sed 's/^  FAIL  //'
}

battery_fails=0
# EACH MUTANT DECLARES ITS FULL EXPECTED RED SET, and the observed set must equal it —
# not merely contain it. Most mutants below move exactly one assertion, which is §7's rule.
# M1 moves THREE, and that is structural rather than sloppy: arm A's `emit` is the
# precondition for the remedy assertion and for the arm-A-survives-the-guard assertion, so
# nothing can silence arm A and leave them standing. §7's rule exists to catch a VACUOUS
# assertion, so the answer is to prove those two independently rather than to pretend M1 is
# narrow — M5 moves the remedy alone and M6 moves the guard-width alone. Every assertion in
# this fixture is therefore moved by at least one mutant that moves nothing else.
expect_set() {  # $1 = label, $2 = expected red count, $3 = ERE all reds must match, $4 = sed
  local reds n unmatched
  reds="$(mut_reds "$1" "$4")"
  if [ "$reds" = "UNMUTATED" ]; then
    bad "MUTANT $1: the sed matched nothing — no mutation was applied, so nothing was proven"
    battery_fails=$((battery_fails+1)); return
  fi
  n="$(printf '%s\n' "$reds" | grep -c . || true)"
  unmatched="$(printf '%s\n' "$reds" | grep -c . || true)"
  unmatched="$(printf '%s\n' "$reds" | grep -vE "$3" | grep -c . || true)"
  if [ "$n" -eq "$2" ] && [ "$unmatched" -eq 0 ]; then
    ok "MUTANT $1 moves exactly the $2 assertion(s) it should, and no others"
  else
    bad "MUTANT $1: expected $2 red(s) all matching '$3', got ${n} (${unmatched} unexpected): $(printf '%s' "$reds" | tr '\n' ';')"
    battery_fails=$((battery_fails+1))
  fi
}

# The unmutated control FIRST. If a plain copy of the detector does not come back clean,
# every kill below is unearned and the battery is measuring its own harness.
ctl="$(mut_reds control "")"
if [ -z "$ctl" ]; then
  ok "CONTROL: an unmutated copy of the detector passes every assertion"
else
  bad "CONTROL: an unmutated copy FAILED ($(printf '%s' "$ctl" | tr '\n' ';')) — every kill below is unearned"
  battery_fails=$((battery_fails+1))
fi

# M1 — arm A stops emitting. Only the .dist-only subject moves.
expect_set armA-silent 3 'arm A MISSED|remedy does not name|arm A went silent' \
  's@emit RETIRED-FIXTURE-ORPHAN "$cons_rel"@: RETIRED-FIXTURE-ORPHAN "$cons_rel"@'

# M2 — arm B drops the HISTORY half of its predicate, keeping "not in core's shipped set".
# That is the unmeasured lint: on the reference consumer it reports all 29 non-core
# directories instead of the 1 that was ever core's. Here it reports the consumer's own.
expect_set armB-no-history 1 "consumer's OWN fixture was reported" \
  's@\[ -n "$(git -C "$DIST" log --all --format=%H -1 -- "core/fixtures/${n}" 2>/dev/null)" \] || continue@:@'

# M3 — the zero guard goes back to the probe that SURVIVES truncation. This is the defect
# this fixture actually caught during authoring: the guard passed and arm B false-zeroed.
expect_set guard-surviving-probe 1 'answered silently on a truncated clone' \
  's@dist_shallow="$(git -C "$DIST" rev-parse --is-shallow-repository 2>/dev/null)"@dist_shallow=false@'

# M4 — the mapper refusal is removed, so a missing map_consumer() scans nothing quietly.
expect_set nomap-silent 1 'scanned with no path mapper' \
  's@^  emit HARD-RETIRED-FIXTURE-SCAN-UNAVAILABLE "-" \\@  : HARD-RETIRED-FIXTURE-SCAN-UNAVAILABLE "-" \\@'

# M5 — the remedy stops naming a removable consumer path. The operator reads that line
# while deciding whether to delete a directory, and v0.225.0 shipped a release for exactly
# this class of un-transcribable remedy.
expect_set remedy-unusable 1 'does not name a removable consumer path' \
  's@rm -rf <consumer>/${cons_rel}@remove it@'

# M6 — the zero guard takes the WHOLE scan down instead of only arm B. Arm A needs no
# history, so a guard this wide trades one blind spot for a larger one. This is the mutant
# that proves the arm-A-survives assertion is not riding on M1.
expect_set guard-too-wide 1 'arm A went silent with arm B' \
  's@      \[ -d "${CONSUMER}/${cons_rel}" \] || continue@      [ -d "${CONSUMER}/${cons_rel}" ] || continue\
      [ "$(git -C "$DIST" rev-parse --is-shallow-repository 2>/dev/null)" = true ] \&\& continue@'

if [ "$fails" -eq 0 ]; then
  echo "PASS retired-fixture-orphan"
  exit 0
fi
echo "FAIL retired-fixture-orphan ($fails)"
exit 1
