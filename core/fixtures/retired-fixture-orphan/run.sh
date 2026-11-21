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
# detector delegates its path mapping to `preclassify.sh` beside it, so a copy living
# in a scratch directory has no mapper.
if [ -n "$ROOT" ] && [ -d "$ROOT/core/skills/ai-dlc-update/reconcile" ]; then
  SRC_DIR="$ROOT/core/skills/ai-dlc-update/reconcile"
elif [ -n "$ROOT" ] && [ -d "$ROOT/.claude/skills/ai-dlc-update/reconcile" ]; then
  SRC_DIR="$ROOT/.claude/skills/ai-dlc-update/reconcile"
else
  echo "FIXTURE ERROR: reconcile/ not found in either layout" >&2
  exit 2
fi

if [ -n "$ROOT" ] && [ -f "$ROOT/core/skills/ai-dlc-update/reconcile/retired-fixtures.sh" ]; then
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

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
[ -f "$HERE/../lib/mutant.sh" ] || { echo "FIXTURE BROKEN: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: sourcing lib/mutant.sh failed" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"
. "$HERE/../lib/world.sh" || { echo "FIXTURE BROKEN: cannot source lib/world.sh" >&2; exit 2; }

# --- the pre-wrap consumer gate (BL-878): a consumer runs its OWN installed detector, which can predate the
# in-process wrap. Neither half -> SKIP (never an ok); one half -> FAIL naming it; unreadable -> FIXTURE ERROR.
rf_def=0; rf_guard=0
grep -q '^rf_main() {$' "$DETECT"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $DETECT (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || rf_def=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$DETECT"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $DETECT (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || rf_guard=1
if [ "$rf_def$rf_guard" = 00 ]; then echo "SKIP: subject predates the in-process wrap"; exit 0; fi
if [ "$rf_def" = 0 ]; then echo "   FAIL  $DETECT carries the column-0 source guard but no \`rf_main() {\` line -- a respelled subject this fixture cannot drive" >&2; echo "retired-fixture-orphan: FAIL (1)" >&2; exit 1; fi
if [ "$rf_guard" = 0 ]; then echo "   FAIL  $DETECT defines \`rf_main() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run rf_main in this shell" >&2; echo "retired-fixture-orphan: FAIL (1)" >&2; exit 1; fi

# One in-process pass: a subshell that sources ONE copy of the detector (the copy decides SELF, so its
# siblings are the ones beside it) and calls rf_main. The detector sources lib.sh inside rf_main, so in a
# subshell lib.sh builds no memo of its own (BASH_SUBSHELL > 0) and goes direct; an exported
# AI_DLC_RECONCILE_MEMO is still borrowed, which the memo cell below relies on.
rf_run() { # <detector copy> <args...>
  ( _c="$1"; shift
    fx_inproc "$_c"
    . "$_c" || exit 2
    declare -F rf_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $_c defined no rf_main" >&2; exit 2; }
    rf_main "$@" ); }

git_q() { world_git -C "$1" -c user.email=f@x -c user.name=f -c commit.gpgsign=false "${@:2}" >/dev/null 2>&1; }

# ---------------------------------------------------------------- the scratch distribution
# A real git repo, because arm B's whole predicate is a history question and a fake one
# would let the arm pass on a tree where the real thing cannot answer.
DIST="$WORK/dist"
mkdir -p "$DIST/core/skills/ai-dlc-update/reconcile"
cp "$DETECT" "$DIST/core/skills/ai-dlc-update/reconcile/retired-fixtures.sh"
# The detector SOURCES consumer-read.sh from beside itself; without it every run exits 2.
cp "$SRC_DIR/consumer-read.sh" "$DIST/core/skills/ai-dlc-update/reconcile/consumer-read.sh"
echo "HERMETIC-CONSUMED $DETECT"
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
out="$(rf_run "$UNDER_TEST" "$DIST" "$THEIRS" "$CONS" 2>/dev/null)"
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
#    IT IS DELIBERATELY NOT A COUNT. A count is entangled with assertions 1, 2 and 3 by
#    construction. Scoped to subjects outside the seeded set, this cell moves on its own.
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
if world_git clone -q --depth 1 "file://$DIST" "$SHALLOW" 2>/dev/null && [ -d "$SHALLOW/.git" ]; then
  s_out="$(rf_run "$UNDER_TEST" "$SHALLOW" HEAD "$CONS" 2>/dev/null)"

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
  m_out="$(rf_run "$NOMAP/core/skills/ai-dlc-update/reconcile/retired-fixtures.sh" "$NOMAP" "$THEIRS" "$CONS" 2>/dev/null)"
  if grep -q '^HARD-RETIRED-FIXTURE-SCAN-UNAVAILABLE' <<<"$m_out"; then
    ok "refuses loudly when map_consumer() cannot be loaded"
  else
    bad "scanned with no path mapper — it would print an empty result that reads as no orphans"
  fi
else
  bad "FIXTURE BROKEN: the no-mapper copy is identical to the original, so nothing was tested"
fi

# --- A memo listing that is SERVED and then FAILS does not double arm A -------------------------
# lib.sh's memo returns 125 when a cached status cannot be read, AFTER its bytes reached stdout.
# Arm A read `{ memo | grep; } || git ls-tree`, so that failure ran the fallback too and every
# marker was listed twice: two identical orphan rows at rc 0. One row per orphan, whatever the memo.
# The detector copy under test sits in the scratch dist with no lib.sh beside it, so it never loads
# the memo; this cell runs it from its own directory WITH lib.sh. Keyed on DOUBLING: a detector whose
# arm A emits nothing is arm A's own arm above, not this one.
# The copy sits under the subject's own relative path so its in-process passes count on the declared inproc: row.
RD="$WORK/rfo-memo-dir/core/skills/ai-dlc-update/reconcile"; mkdir -p "$RD"
cp "$UNDER_TEST" "$RD/retired-fixtures.sh"; cp "$DIST/core/skills/ai-dlc-update/reconcile/preclassify.sh" "$RD/"
cp "$SRC_DIR/lib.sh" "$RD/lib.sh"; cp "$SRC_DIR/consumer-read.sh" "$RD/consumer-read.sh"
RM="$(mktemp -d "$WORK/rfo-memo.XXXXXX")"
( export AI_DLC_RECONCILE_MEMO="$RM"; rf_run "$RD/retired-fixtures.sh" "$DIST" "$THEIRS" "$CONS" ) > "$WORK/rm.ctl" 2>/dev/null
rm_c="$(grep -c '^RETIRED-FIXTURE-ORPHAN.*tests/fixtures/will-be-distonly' "$WORK/rm.ctl")" || rm_c=0
rm_n=0
for rm_f in "$RM"/"t "*.s; do [ -f "$rm_f" ] || continue; : > "$rm_f"; rm_n=$((rm_n + 1)); done
rm_out="$(export AI_DLC_RECONCILE_MEMO="$RM"; rf_run "$RD/retired-fixtures.sh" "$DIST" "$THEIRS" "$CONS" 2>/dev/null)"
rm_a="$(printf '%s\n' "$rm_out" | grep -c '^RETIRED-FIXTURE-ORPHAN.*tests/fixtures/will-be-distonly')" || rm_a=0
if [ "$rm_n" -lt 1 ]; then
  bad "FIXTURE BROKEN — no tree-listing memo key was written, so the served-then-failed memo cell asserts nothing"
elif [ "$rm_a" -le 1 ] && [ "$rm_a" -eq "$rm_c" ]; then
  ok "a memo listing whose status cannot be read yields the same arm-A rows as a healthy one ($rm_a), never a doubled set"
else
  bad "a memo listing whose status cannot be read printed the arm-A orphan $rm_a time(s) against $rm_c healthy — the fallback listing ran on top of the served one"
fi

# --- the cli cells (cells.decl): the detector run as a PROGRAM once per distinct CLI outcome ----------------------
# The detector always exits 0; its outcomes are the row class on stdout: orphan rows, the history-unavailable
# refusal row (shallow clone), and the scan-unavailable row (no mapper). One `FXCELL=<id> bash <copy>` start per
# outcome, each compared with the in-process call on the same inputs: stdout, stderr and exit separately, byte for
# byte. Each cell also asserts its own outcome, and the three outcomes must differ.
EQ="$WORK/eq"; mkdir -p "$EQ"
eqv() { # <cell-id> <detector copy> <args...> -> $EQ/<id>.{ip,cl}.{out,err,rc}
  local id="$1" c="$2"; shift 2
  rf_run "$c" "$@" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" bash "$c" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(cat "$EQ/$1.ip.out")" "$(cat "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(cat "$EQ/$1.cl.out")" "$(cat "$EQ/$1.cl.err")"; }
if eqv cli-orphans "$UNDER_TEST" "$DIST" "$THEIRS" "$CONS" && [ "$(cat "$EQ/cli-orphans.cl.rc")" = 0 ] \
   && grep -q '^RETIRED-FIXTURE-ORPHAN.*tests/fixtures/will-be-deleted' "$EQ/cli-orphans.cl.out"; then
  ok "cli-orphans: the program reports the orphans exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-orphans: the program and the in-process call differ, or no orphan row ($(eq_twin cli-orphans))"; fi
if [ -d "$SHALLOW/.git" ] && eqv cli-shallow "$UNDER_TEST" "$SHALLOW" HEAD "$CONS" && [ "$(cat "$EQ/cli-shallow.cl.rc")" = 0 ] \
   && grep -q '^RETIRED-FIXTURE-HISTORY-UNAVAILABLE' "$EQ/cli-shallow.cl.out"; then
  ok "cli-shallow: the program refuses arm B on a truncated clone exactly as the in-process call does"
else bad "cli-shallow: the program and the in-process call differ, or no history-unavailable row ($(eq_twin cli-shallow 2>/dev/null))"; fi
if eqv cli-nomap "$NOMAP/core/skills/ai-dlc-update/reconcile/retired-fixtures.sh" "$NOMAP" "$THEIRS" "$CONS" \
   && [ "$(cat "$EQ/cli-nomap.cl.rc")" = 0 ] && grep -q '^HARD-RETIRED-FIXTURE-SCAN-UNAVAILABLE' "$EQ/cli-nomap.cl.out"; then
  ok "cli-nomap: the program refuses with no mapper exactly as the in-process call does"
else bad "cli-nomap: the program and the in-process call differ, or no scan-unavailable row ($(eq_twin cli-nomap))"; fi
if ! cmp -s "$EQ/cli-orphans.cl.out" "$EQ/cli-shallow.cl.out" && ! cmp -s "$EQ/cli-shallow.cl.out" "$EQ/cli-nomap.cl.out" \
   && ! cmp -s "$EQ/cli-orphans.cl.out" "$EQ/cli-nomap.cl.out"; then
  ok "cli cells discriminate: the orphan rows, the history refusal and the mapper refusal give different output"
else bad "two cli cells gave identical output -- the cells do not discriminate"; fi

echo ""
report_end retired-fixture-orphan
