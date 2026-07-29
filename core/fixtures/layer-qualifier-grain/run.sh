#!/usr/bin/env bash
# layer-qualifier-grain — assert the `extends:` / `kind: qualifier` grain is real:
# that declaring an anchor NARROWS pull-time drift to that anchor's span, that the
# narrowing cannot invent silence, and that the authoring arms discriminate.
#
# Usage: run.sh [path-to-validate-layer-entries.sh] [path-to-layer-drift.sh]
# Exit:  0 = every assertion holds, 1 = something regressed.
#
# THE LOAD-BEARING ASSERTION IS PART 1a: a commit that changes the hooked file
# OUTSIDE the declared anchor must produce NO drift row for the anchored entry,
# while the SAME commit still produces one for an entry that declared no anchor.
# Without the second half that assertion is worthless — a classifier that had
# stopped emitting anything at all would pass it. Together they say the narrowing
# is a narrowing and not a relabelling.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
LINTER="$(pick "${1:-}" "$HERE/../../../scripts/ai-dlc/validate-layer-entries.sh" \
                        "$HERE/../../scripts/validate-layer-entries.sh" \
                        "$HERE/../../../core/scripts/validate-layer-entries.sh")"
DRIFT="$(pick "${2:-}" "$HERE/../../../core/skills/ai-dlc-update/reconcile/layer-drift.sh" \
                       "$HERE/../../skills/ai-dlc-update/reconcile/layer-drift.sh" \
                       "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/layer-drift.sh")"
[ -n "$LINTER" ] || { echo "FIXTURE ERROR: cannot locate validate-layer-entries.sh" >&2; exit 2; }
[ -n "$DRIFT" ]  || { echo "FIXTURE ERROR: cannot locate layer-drift.sh" >&2; exit 2; }

ROOT="$(bash "$HERE/seed.sh")"
trap 'rm -rf "$ROOT"' EXIT
DIST="$ROOT/dist"; CONS="$ROOT/consumer"; BAD="$ROOT/bad-consumer"
BASE="$(git -C "$DIST" rev-parse --short HEAD~1)"
THEIRS="$(git -C "$DIST" rev-parse --short HEAD)"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "layer-qualifier-grain:"

# status_for <entry-substring>  -> the status column of that entry's row
status_for() { printf '%s\n' "$DRIFT_OUT" | awk -v e="$1" -F'\t' '$2 ~ e {print $1}' | sort -u | tr '\n' ' '; }

DRIFT_OUT="$(bash "$DRIFT" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1)"

# --- Part 0: the seed is a real range, and the classifier ran ------------------
# Every assertion below is shaped "this status did NOT appear". A run that produced
# no rows at all satisfies all of them, so the count is checked before any of them.
rows="$(printf '%s\n' "$DRIFT_OUT" | grep -c 'EXTENSION-')"
if [ "$rows" -ge 5 ]; then
  ok "the classifier emitted $rows extension rows (a zero here would pass every absence assertion below)"
else
  bad "only $rows extension rows — the classifier did not run over the five seeded entries, so every assertion in Part 1 would pass vacuously"
fi
if git -C "$DIST" diff --quiet "$BASE" "$THEIRS" -- core/skills/ai-dlc/steps/demo.md; then
  bad "the seeded range does not change the hooked file at all — 'no anchor drift' would be trivially true"
else
  ok "the seeded range really does change the hooked file (so silence has to be earned)"
fi

# --- Part 1a: THE LOAD-BEARING PAIR -------------------------------------------
case " $(status_for anchored-elsewhere) " in
  *" EXTENSION-OK "*) ok "anchor OUTSIDE the change: EXTENSION-OK — drift narrowed to the declared span" ;;
  *) bad "anchored-elsewhere reported '$(status_for anchored-elsewhere)' — the entry declared '#Alpha gate', which is byte-identical across the range, so a drift row here means the anchor is not being read and this is file grain wearing a new name" ;;
esac
case " $(status_for no-anchor) " in
  *" EXTENSION-HOOK-DRIFT "*) ok "same commit, entry with NO anchor: EXTENSION-HOOK-DRIFT — file grain preserved where nothing was declared" ;;
  *) bad "no-anchor reported '$(status_for no-anchor)' — an entry that declares no extends: must keep the whole file as its drift subject, or the narrowing silently applied to entries that never asked for it" ;;
esac

# --- Part 1b: the anchor that IS at the change --------------------------------
case " $(status_for anchored-at-change) " in
  *" EXTENSION-ANCHOR-DRIFT "*) ok "anchor AT the change: EXTENSION-ANCHOR-DRIFT — the narrowing still reports what it must" ;;
  *) bad "anchored-at-change reported '$(status_for anchored-at-change)' — '#Gamma review' is the one body the range rewrites, so a quiet row here is the narrowing swallowing a real change" ;;
esac

# --- Part 1c: the narrowing cannot invent silence -----------------------------
# A span that no longer resolves compares empty against empty. This is the arm that
# stops "narrower" from meaning "quieter about things that matter".
case " $(status_for anchor-vanished) " in
  *" EXTENSION-ANCHOR-MISSING "*) ok "anchor renamed upstream: EXTENSION-ANCHOR-MISSING, not silence" ;;
  *) bad "anchor-vanished reported '$(status_for anchor-vanished)' — core renamed '## Delta handoff' to '## Epsilon handoff', so this entry's declared span resolves to nothing and would answer clean for every future change to the section it claims to augment" ;;
esac

# --- Part 2: the authoring arms fire, one message each ------------------------
BAD_OUT="$(bash "$LINTER" "$BAD" 2>&1)"
assert_msg() { # assert_msg <label> <grep-pattern>
  printf '%s' "$BAD_OUT" | grep -q "$2" && ok "$1" || bad "$1 — no message matching /$2/"
}
assert_msg "E10 rejects a kind the loader routes nowhere"        "kind 'qualifer' is not one of"
assert_msg "E11 rejects an anchor matching no heading"           "anchor 'No Such Heading Anywhere' matches no heading"
assert_msg "E11 rejects a reverse-only anchor, naming the real heading" "CONTAINS the heading 'Beta'"
assert_msg "E11 rejects an anchor whose file is not the hooked file"    "but hooks: names"
assert_msg "E11 rejects two anchors"                             "declares 2 anchors"
assert_msg "E11 rejects an extends: with no anchor"              "carries no '#anchor'"
assert_msg "E12 rejects a qualifier missing extends:"            "requires 'extends:'"
assert_msg "E12 rejects a qualifier missing position:"           "requires 'position:'"
assert_msg "E12 rejects position: on a non-qualifier"            "does not render inside a core section"
assert_msg "E13 rejects a position outside append|prepend"       "is not 'append' or 'prepend'"
assert_msg "E14 rejects gate_types: on a kind no row loads"      "Only a check is loaded from a GATE_MANIFEST row"

# --- Part 3: THE DISCRIMINATION CONTROL ---------------------------------------
# Every arm above is an "it fired" assertion, and all of them are satisfied by a
# linter that errors on every entry. The clean tree is what says otherwise.
GOOD_OUT="$(bash "$LINTER" "$CONS" 2>&1)"
if printf '%s' "$GOOD_OUT" | grep -q '^ERROR'; then
  bad "the CLEAN consumer drew errors — the new arms fire on well-formed entries, so every Part 2 assertion above is consistent with a linter that simply rejects everything:
$(printf '%s' "$GOOD_OUT" | grep '^ERROR' | sed 's/^/        /')"
else
  ok "the clean consumer (including a well-formed kind: qualifier) draws ZERO errors"
fi

# --- Part 4: mutants -----------------------------------------------------------
# COPIES, never in-place edits, each guarded by `cmp -s` so a sed that matched
# nothing cannot pass as a mutation. Each mutant must fail ONLY its own assertion;
# two failures would mean the assertions are entangled and one is vacuous.
#
# The drift copies go into a copy of the WHOLE reconcile/ directory, not into a
# scratch dir of their own. `layer-drift.sh` sources `lib.sh` from beside itself
# and exits 1 when it cannot, so a lone copy emits NOTHING — and "no output" is
# indistinguishable from "the mutated check went quiet", i.e. it scores as a kill
# for every mutant at once. The unmutated control below is what detects that, and
# on this fixture's first run it did exactly that.
MDIR="$ROOT/mutants"; mkdir -p "$MDIR"
cp -R "$(dirname "$DRIFT")" "$MDIR/reconcile"
DRIFT_BN="$(basename "$DRIFT")"
cp "$MDIR/reconcile/$DRIFT_BN" "$MDIR/reconcile/drift-control.sh"
cp "$LINTER" "$MDIR/lint-control.sh"

# The unmutated controls run FIRST. A copy that dies for an unrelated reason (a
# sibling it can no longer source, a path it resolved by accident) emits nothing,
# and "no output" otherwise scores as a kill for every mutant below it.
dstat() { bash "$1" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1 | awk -v e="$2" -F'\t' '$2 ~ e {print $1}' | sort -u | tr '\n' ' '; }
if [ "$(dstat "$MDIR/reconcile/drift-control.sh" anchored-elsewhere)" = "$(status_for anchored-elsewhere)" ]; then
  ok "CONTROL: an unmutated copy of layer-drift.sh reproduces the shipped verdict"
else
  bad "CONTROL FAILED: an unmutated COPY of layer-drift.sh does not reproduce the shipped verdict (copy='$(dstat "$MDIR/reconcile/drift-control.sh" anchored-elsewhere)' shipped='$(status_for anchored-elsewhere)'). Every drift mutant below would be scored against a harness that is not working."
fi
if [ "$(bash "$MDIR/lint-control.sh" "$BAD" 2>&1 | grep -c '^ERROR')" -eq "$(printf '%s' "$BAD_OUT" | grep -c '^ERROR')" ]; then
  ok "CONTROL: an unmutated copy of validate-layer-entries.sh reproduces the shipped error count"
else
  bad "CONTROL FAILED: an unmutated COPY of the linter reports a different error count than the shipped one"
fi

mutate() { # mutate <name> <src> <sed-expr> [dest-dir]
  local out="${4:-$MDIR}/$1.sh"
  cp "$2" "$out"
  sed -i.orig "$3" "$out"
  if cmp -s "$out" "$out.orig"; then
    bad "MUTANT '$1' changed nothing — its sed matched no line, so the assertion below would score a working check as a kill"
    rm -f "$out"; return 1
  fi
  rm -f "$out.orig"; printf '%s' "$out"
}

# M1 — the narrowing itself. Force the anchor branch off, so a declared anchor
# falls back to file grain. Kills ONLY the load-bearing assertion.
if m="$(mutate m1-no-narrowing "$DRIFT" 's/^  elif \[ -n "\$ext_anc" \]; then$/  elif false; then/' "$MDIR/reconcile")"; then
  case " $(dstat "$m" anchored-elsewhere) " in
    *" EXTENSION-OK "*) bad "MUTANT m1 (anchor branch disabled) still reports EXTENSION-OK for an entry anchored away from the change — the load-bearing assertion does not depend on the narrowing code and proves nothing" ;;
    *) ok "MUTANT m1 killed: with the anchor branch off, anchored-elsewhere drifts at file grain again" ;;
  esac
fi

# M2 — the anti-silence arm. Treat an unresolvable span as unchanged, which is
# what a narrowing does when nobody guards it. Kills ONLY Part 1c.
if m="$(mutate m2-missing-is-ok "$DRIFT" 's/^    if \[ -z "\$ext_new" \]; then$/    if false; then/' "$MDIR/reconcile")"; then
  case " $(dstat "$m" anchor-vanished) " in
    *" EXTENSION-ANCHOR-MISSING "*) bad "MUTANT m2 (unresolvable span no longer reported) still emits EXTENSION-ANCHOR-MISSING — the guard under test is not what produces that row" ;;
    *) ok "MUTANT m2 killed: without the guard, a vanished anchor stops being reported" ;;
  esac
fi

lstat() { bash "$1" "$BAD" 2>&1; }
# M3 — the kind enum.
if m="$(mutate m3-no-kind-enum "$LINTER" "s/^  if \[ -n \"\\\$kind\" \] \&\& ! printf/  if false \&\& ! printf/")"; then
  lstat "$m" | grep -q "kind 'qualifer' is not one of" \
    && bad "MUTANT m3 (enum check disabled) still rejects the bad kind — E10's assertion is being satisfied by something else" \
    || ok "MUTANT m3 killed: with the enum off, a typo'd kind is accepted in silence"
fi

# M4 — the REVERSE arm only. Rename the pattern so a REVERSE result no longer
# matches it and falls through to the no-match arm. A ONE-TOKEN edit on one line,
# because the first version of this mutant inserted `\n` through BSD sed — which
# emits a literal `n`, not a newline — and produced a syntactically broken script.
# That script emitted nothing, both greps failed, and the fixture reported it as
# entanglement between two assertions that were in fact fine. A mutant must leave
# the program RUNNABLE or it tests the interpreter, not the check.
if m="$(mutate m4-accept-reverse "$LINTER" 's/^          REVERSE:\*)$/          REVERSE_DISABLED:*)/')"; then
  # CAPTURED, then matched with `case` — not `lstat "$m" | grep -q … && … || …`.
  # Two greps in that form against the same producer gave a false ENTANGLEMENT
  # report here: `grep -q` exits on its first match and closes the pipe, and what
  # the `&&`/`||` chain then reads is the pipeline's last stage rather than the
  # question asked. The repo's standing rule is never to read `$?` after a pipe;
  # this is that rule inside a fixture, where the cost was a real assertion
  # reporting a defect that did not exist.
  m4out="$(lstat "$m")"
  case "$m4out" in
    *"CONTAINS the heading 'Beta'"*) bad "MUTANT m4 (reverse arm renamed) still reports the reverse-only anchor" ;;
    *) ok "MUTANT m4 killed: with the reverse arm disabled, a silently-widened span lints clean" ;;
  esac
  case "$m4out" in
    *"matches no heading"*) ok "MUTANT m4 leaves the no-match arm alive (the two E11 arms are not entangled)" ;;
    *) bad "MUTANT m4 also killed the no-match arm — the two assertions are entangled and one of them is vacuous. Mutant emitted $(printf '%s' "$m4out" | grep -c '^ERROR') ERROR line(s)." ;;
  esac
fi

# M5 — the qualifier's required keys.
if m="$(mutate m5-no-qualifier-keys "$LINTER" 's/^  if \[ "\$kind" = qualifier \]; then$/  if false; then/')"; then
  lstat "$m" | grep -q "requires 'extends:'" \
    && bad "MUTANT m5 (qualifier key requirement disabled) still demands extends:" \
    || ok "MUTANT m5 killed: a qualifier with neither key lints clean"
fi

# M6 — the position vocabulary.
if m="$(mutate m6-any-position "$LINTER" "s/^      append|prepend) : ;;$/      append|prepend|middle) : ;;/")"; then
  lstat "$m" | grep -q "is not 'append' or 'prepend'" \
    && bad "MUTANT m6 (vocabulary widened to accept 'middle') still rejects it" \
    || ok "MUTANT m6 killed: widening the vocabulary accepts the bad value"
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "layer-qualifier-grain: PASS"
  exit 0
fi
echo "layer-qualifier-grain: $fails assertion(s) failed"
exit 1
