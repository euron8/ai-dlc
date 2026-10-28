#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# layer-qualifier-grain — assert the `extends:` / `kind: qualifier` grain is real:
# that declaring an anchor NARROWS pull-time drift to that anchor's span, that the
# narrowing cannot invent silence, and that the authoring arms discriminate.
#
# Usage: run.sh [--matrix] [path-to-validate-layer-entries.sh] [path-to-layer-drift.sh]
# Exit:  0 = every assertion holds, 1 = something regressed.
#
# THE LOAD-BEARING ASSERTION IS PART 1a: a commit that changes the hooked file
# OUTSIDE the declared anchor must produce NO drift row for the anchored entry,
# while the SAME commit still produces one for an entry that declared no anchor.
# Without the second half that assertion is worthless — a classifier that had
# stopped emitting anything at all would pass it. Together they say the narrowing
# is a narrowing and not a relabelling.
set -uo pipefail

# `--matrix` is an ARGUMENT (never an env var), parsed and shifted before the positional paths. It adds
# the mutant x arm MATRIX cells and nothing else. WANT_MATRIX is read off the raw argv independently of
# the guard below, so the final arm can tell a plain run from a run whose guard was broken open.
case " $* " in *" --matrix "*) WANT_MATRIX=1 ;; *) WANT_MATRIX=0 ;; esac
MATRIX=0
if [ "${1:-}" = "--matrix" ]; then MATRIX=1; shift; fi
MATRIX_EMITTED=0

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
[ "$MATRIX" = 1 ] && echo "MATRIX-MODE on"
. "$HERE/../lib/mutant.sh"

# status_for <entry-substring>  -> the status column of that entry's row
status_for() { printf '%s\n' "$DRIFT_OUT" | awk -v e="$1" -F'\t' '$2 ~ e {print $1}' | sort -u | tr '\n' ' '; }

echo "HERMETIC-CONSUMED $(cd "$(dirname "$DRIFT")" && pwd)/$(basename "$DRIFT")"
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

# --- Part 1d: an unresolved span does not mask a moved one --------------------
mm=" $(status_for missing-and-moved) "
case "$mm" in *" EXTENSION-ANCHOR-MISSING "*) mm_m=1 ;; *) mm_m=0 ;; esac
case "$mm_m$mm" in
  1*" EXTENSION-ANCHOR-DRIFT "*) ok "one span renamed and another rewritten: BOTH ANCHOR-DRIFT and ANCHOR-MISSING, so the moved span stays adjudicable" ;;
  *) bad "missing-and-moved reported '$(status_for missing-and-moved)' — '#Gamma review' was rewritten and '#Delta handoff' renamed in the same range, so it needs BOTH rows; MISSING alone drops the rewrite from the only row LC-E14 can adjudicate" ;;
esac

# --- Part 2: the authoring arms fire, one message each ------------------------
echo "HERMETIC-CONSUMED $(cd "$(dirname "$LINTER")" && pwd)/$(basename "$LINTER")"
L_DIR="$(cd "$(dirname "$LINTER")" && pwd -P)"
[ -f "$L_DIR/artifact-path-config.sh" ] && echo "HERMETIC-CONSUMED $L_DIR/artifact-path-config.sh"
BAD_OUT="$(bash "$LINTER" "$BAD" 2>&1)"

# The linter arms are DATA: <arm> -> message fragment. The same table scores the shipped linter below and
# every linter mutant's output, so a base arm and the cell a mutant is read against cannot drift.
LARMS="e10 e11-nomatch e11-reverse e11-otherfile e11-two e11-second e11-noanchor e11-emptyparts e12-extends e12-position e12-nonqualifier e13 e14"
lpat() {
  case "$1" in
    e10)              printf '%s' "kind 'qualifer' is not one of" ;;
    e11-nomatch)      printf '%s' "anchor 'No Such Heading Anywhere' matches no heading" ;;
    e11-reverse)      printf '%s' "CONTAINS the heading 'Beta'" ;;
    e11-otherfile)    printf '%s' "but hooks: names" ;;
    e11-two)          printf '%s' "declares 2 anchors ('#Alpha gate, #Gamma review') on kind 'qualifier'" ;;
    e11-second)       printf '%s' "anchor 'Second Anchor Nowhere' matches no heading" ;;
    e11-noanchor)     printf '%s' "carries no '#anchor'" ;;
    e11-emptyparts)   printf '%s' "extends: ',' declares no anchor at all" ;;
    e12-extends)      printf '%s' "requires 'extends:'" ;;
    e12-position)     printf '%s' "requires 'position:'" ;;
    e12-nonqualifier) printf '%s' "does not render inside a core section" ;;
    e13)              printf '%s' "is not 'append' or 'prepend'" ;;
    e14)              printf '%s' "Only a check is loaded from a GATE_MANIFEST row" ;;
  esac
}
# lint_holds <arm> <linter-output> -- 0 when the arm's message is present
lint_holds() { grep -qF -- "$(lpat "$1")" <<<"$2"; }

assert_msg() { # assert_msg <label> <arm>
  if lint_holds "$2" "$BAD_OUT"; then
    ok "$1"
    case "$2" in
      e10) B_e10=1 ;; e11-nomatch) B_e11_nomatch=1 ;; e11-reverse) B_e11_reverse=1 ;; e11-two) B_e11_two=1 ;;
      e11-second) B_e11_second=1 ;; e11-noanchor) B_e11_noanchor=1 ;; e11-emptyparts) B_e11_emptyparts=1 ;;
      e12-extends) B_e12_extends=1 ;; e13) B_e13=1 ;;
    esac
  else
    bad "$1 — no message matching /$(lpat "$2")/"
  fi
}
assert_msg "E10 rejects a kind the loader routes nowhere"        e10
assert_msg "E11 rejects an anchor matching no heading"           e11-nomatch
assert_msg "E11 rejects a reverse-only anchor, naming the real heading" e11-reverse
assert_msg "E11 rejects an anchor whose file is not the hooked file"    e11-otherfile
assert_msg "E11 rejects two anchors on a qualifier"              e11-two
assert_msg "E11 checks EVERY declared span, not the first"       e11-second
assert_msg "E11 rejects an extends: with no anchor"              e11-noanchor
assert_msg "E11 rejects an extends: whose every part is empty"   e11-emptyparts
assert_msg "E12 rejects a qualifier missing extends:"            e12-extends
assert_msg "E12 rejects a qualifier missing position:"           e12-position
assert_msg "E12 rejects position: on a non-qualifier"            e12-nonqualifier
assert_msg "E13 rejects a position outside append|prepend"       e13
assert_msg "E14 rejects gate_types: on a kind no row loads"      e14

# --- Part 3: THE DISCRIMINATION CONTROL ---------------------------------------
# Every arm above is an "it fired" assertion, and all of them are satisfied by a
# linter that errors on every entry. The clean tree is what says otherwise.
GOOD_OUT="$(bash "$LINTER" "$CONS" 2>&1)"
if grep -q '^ERROR' <<<"$GOOD_OUT"; then
  bad "the CLEAN consumer drew errors — the new arms fire on well-formed entries, so every Part 2 assertion above is consistent with a linter that simply rejects everything:
$(printf '%s' "$GOOD_OUT" | grep '^ERROR' | sed 's/^/        /')"
else
  ok "the clean consumer (including a well-formed kind: qualifier) draws ZERO errors"
fi

# --- Part 4: mutants -----------------------------------------------------------
# Mutant matrix block. Measured once by the --matrix run named on the REMEASURE line: every mutant is
# run once and read against EVERY arm of its subject (the five drift arms d-*, or the thirteen linter
# arms e*); FAIL = that arm's expectation no longer holds under the mutant, ok = it still holds. Per push
# each mutant is scored only on its DECIDING arm (must FAIL) and its TWIN (an arm the matrix shows ok,
# which must HOLD), both read off the ONE subject run the mutant already costs. The shipped subject keeps
# every base arm and world above. Arms that ALSO fail under a mutant (entanglement) are in the --matrix log.
# MUTANT-MATRIX m1-no-narrowing decides=d-elsewhere twins=d-noanchor
# MUTANT-MATRIX m2-missing-is-ok decides=d-vanished twins=d-elsewhere
# MUTANT-MATRIX m3-no-kind-enum decides=e10 twins=e11-nomatch
# MUTANT-MATRIX m4-accept-reverse decides=e11-reverse twins=e11-nomatch
# MUTANT-MATRIX m5-no-qualifier-keys decides=e12-extends twins=e13
# MUTANT-MATRIX m6-any-position decides=e13 twins=e10
# MUTANT-MATRIX m7-first-span-only decides=e11-second twins=e11-nomatch
# MUTANT-MATRIX m8-qualifier-any-anchors decides=e11-two twins=e11-nomatch
# MUTANT-MATRIX m9-missing-masks-drift decides=d-missmoved twins=d-vanished
# MUTANT-MATRIX m10-empty-parts-accepted decides=e11-emptyparts twins=e11-noanchor
# MUTANT-MATRIX-REMEASURE bash core/fixtures/layer-qualifier-grain/run.sh --matrix
# Re-measured whenever an arm or a mutant is added or changed.
#
# COPIES, never in-place edits, each guarded by `cmp -s` so a sed that matched
# nothing cannot pass as a mutation.
#
# The drift copies go into a copy of the WHOLE reconcile/ directory, not into a
# scratch dir of their own. `layer-drift.sh` sources `lib.sh` from beside itself
# and exits 1 when it cannot, so a lone copy emits NOTHING — and "no output" is
# indistinguishable from "the mutated check went quiet", i.e. it scores as a kill
# for every mutant at once. The unmutated control below is what detects that.
MDIR="$ROOT/mutants"; mkdir -p "$MDIR"
cp -R "$(dirname "$DRIFT")" "$MDIR/reconcile"
DRIFT_BN="$(basename "$DRIFT")"
cp "$MDIR/reconcile/$DRIFT_BN" "$MDIR/reconcile/drift-control.sh"
cp "$LINTER" "$MDIR/lint-control.sh"

# The unmutated controls run FIRST, ONE run per copy machinery. A copy that dies for an unrelated
# reason (a sibling it can no longer source, a path it resolved by accident) emits nothing, and "no
# output" otherwise scores as a kill for every mutant below it.
drift_run() { bash "$1" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1; }
statuses() { printf '%s\n' "$1" | awk -v e="$2" -F'\t' '$2 ~ e {print $1}' | sort -u | tr '\n' ' '; }
CTRL_DRIFT_OUT="$(drift_run "$MDIR/reconcile/drift-control.sh")"
if [ "$(statuses "$CTRL_DRIFT_OUT" anchored-elsewhere)" = "$(status_for anchored-elsewhere)" ]; then
  ok "CONTROL: an unmutated copy of layer-drift.sh reproduces the shipped verdict"
else
  bad "CONTROL FAILED: an unmutated COPY of layer-drift.sh does not reproduce the shipped verdict (copy='$(statuses "$CTRL_DRIFT_OUT" anchored-elsewhere)' shipped='$(status_for anchored-elsewhere)'). Every drift mutant below would be scored against a harness that is not working."
fi
if [ "$(bash "$MDIR/lint-control.sh" "$BAD" 2>&1 | grep -c '^ERROR')" -eq "$(printf '%s' "$BAD_OUT" | grep -c '^ERROR')" ]; then
  ok "CONTROL: an unmutated copy of validate-layer-entries.sh reproduces the shipped error count"
else
  bad "CONTROL FAILED: an unmutated COPY of the linter reports a different error count than the shipped one"
fi

# The drift arms, the same predicates as Part 1, over any drift output.
DARMS="d-elsewhere d-noanchor d-atchange d-vanished d-missmoved"
drift_holds() { # drift_holds <arm> <drift-output>
  local s
  case "$1" in
    d-elsewhere) s=" $(statuses "$2" anchored-elsewhere) "; case "$s" in *" EXTENSION-OK "*) return 0 ;; esac ;;
    d-noanchor)  s=" $(statuses "$2" no-anchor) ";          case "$s" in *" EXTENSION-HOOK-DRIFT "*) return 0 ;; esac ;;
    d-atchange)  s=" $(statuses "$2" anchored-at-change) "; case "$s" in *" EXTENSION-ANCHOR-DRIFT "*) return 0 ;; esac ;;
    d-vanished)  s=" $(statuses "$2" anchor-vanished) ";    case "$s" in *" EXTENSION-ANCHOR-MISSING "*) return 0 ;; esac ;;
    d-missmoved) s=" $(statuses "$2" missing-and-moved) ";  case "$s" in *" EXTENSION-ANCHOR-MISSING "*) case "$s" in *" EXTENSION-ANCHOR-DRIFT "*) return 0 ;; esac ;; esac ;;
  esac
  return 1
}
# Flags: set from the SHIPPED run's verdict on the arm each mutant is scored against, in THIS run.
if drift_holds d-elsewhere "$DRIFT_OUT"; then B_d_elsewhere=1; fi
if drift_holds d-vanished "$DRIFT_OUT"; then B_d_vanished=1; fi
if drift_holds d-missmoved "$DRIFT_OUT"; then B_d_missmoved=1; fi

# Flags: set from the SHIPPED run's verdict on the arm each drift mutant is scored against, in THIS run.
if drift_holds d-elsewhere "$DRIFT_OUT"; then B_d_elsewhere=1; fi
if drift_holds d-vanished "$DRIFT_OUT"; then B_d_vanished=1; fi
if drift_holds d-missmoved "$DRIFT_OUT"; then B_d_missmoved=1; fi

# EVERY CALLER INVOKES THIS INSIDE `$( )` TO CAPTURE THE MUTANT'S PATH, so this
# function cannot report anything by calling bad(): the diagnostic is captured as
# its OUTPUT and becomes the mutant path, and the fails++ happens in a subshell
# that dies at the closing paren. The remedy is to write it to a FILE, which no
# subshell can swallow, and assert on that file at the end where the count is visible.
MUT_UNLANDED="$MDIR/mutations-that-did-not-land"
: > "$MUT_UNLANDED"
mutate() { # mutate <name> <src> <sed-expr> [dest-dir]
  local out="${4:-$MDIR}/$1.sh"
  cp "$2" "$out"
  sed -i.orig "$3" "$out"
  if cmp -s "$out" "$out.orig"; then
    printf '%s\n' "$1" >> "$MUT_UNLANDED"
    rm -f "$out" "$out.orig"; return 1
  fi
  rm -f "$out.orig"; printf '%s' "$out"
}

# cells <mutant> <d|e> <output> -- the --matrix cells: EVERY arm of the subject read against the mutant's
# output. Emitted ONLY under --matrix; MATRIX_EMITTED counts them so a plain run can assert there were none.
cells() {
  [ "$MATRIX" = 1 ] || return 0
  local arm holds
  if [ "$2" = d ]; then
    for arm in $DARMS; do
      if drift_holds "$arm" "$3"; then holds=ok; else holds=FAIL; fi
      printf 'MATRIX\t%s\t%s\t%s\n' "$1" "$arm" "$holds"; MATRIX_EMITTED=$((MATRIX_EMITTED+1))
    done
  else
    for arm in $LARMS; do
      if lint_holds "$arm" "$3"; then holds=ok; else holds=FAIL; fi
      printf 'MATRIX\t%s\t%s\t%s\n' "$1" "$arm" "$holds"; MATRIX_EMITTED=$((MATRIX_EMITTED+1))
    done
  fi
}
# held <d|e> <arm> <output> -- 0 when the arm still holds on that output
held() { if [ "$1" = d ]; then drift_holds "$2" "$3"; else lint_holds "$2" "$3"; fi; }
# score <mutant> <d|e> <output> <deciding-arm> <twin-arm> <flag> <what-died> -- one decider that must
# FAIL (a kill, through mutant_killed) and one twin that must HOLD, both read off the ONE run in $3.
score() {
  cells "$1" "$2" "$3"
  if held "$2" "$4" "$3"; then
    bad "$1 SURVIVED: arm $4 still holds under the mutant — the assertion does not depend on the code mutated"
  else
    mutant_killed "$6" "$1" "$1: killed on arm $4 — $7"
  fi
  if held "$2" "$5" "$3"; then
    ok "$1: twin arm $5 holds (not entangled)"
  else
    bad "$1 also broke twin arm $5 — the two assertions are entangled and one of them is vacuous"
  fi
}
lstat() { bash "$1" "$BAD" 2>&1; }
DMUT="$MDIR/reconcile"

if m="$(mutate m1-no-narrowing "$DRIFT" 's/^  elif \[ -n "\$ext_ancs" \]; then$/  elif false; then/' "$DMUT")"; then
  score m1-no-narrowing d "$(drift_run "$m")" d-elsewhere d-noanchor "${B_d_elsewhere:-0}" "with the anchor branch off, anchored-elsewhere drifts at file grain again"
fi
if m="$(mutate m2-missing-is-ok "$DRIFT" 's/^      if \[ -z "\$ext_new" \]; then$/      if false; then/' "$DMUT")"; then
  score m2-missing-is-ok d "$(drift_run "$m")" d-vanished d-elsewhere "${B_d_vanished:-0}" "without the guard, a vanished anchor stops being reported"
fi
if m="$(mutate m3-no-kind-enum "$LINTER" "s/^  if \[ -n \"\\\$kind\" \] \&\& /  if false \&\& /")"; then
  score m3-no-kind-enum e "$(lstat "$m")" e10 e11-nomatch "${B_e10:-0}" "with the enum off, a typo'd kind is accepted in silence"
fi
if m="$(mutate m4-accept-reverse "$LINTER" 's/^            REVERSE:\*)$/            REVERSE_DISABLED:*)/')"; then
  score m4-accept-reverse e "$(lstat "$m")" e11-reverse e11-nomatch "${B_e11_reverse:-0}" "with the reverse arm disabled, a silently-widened span lints clean"
fi
if m="$(mutate m5-no-qualifier-keys "$LINTER" 's/^  if \[ "\$kind" = qualifier \]; then$/  if false; then/')"; then
  score m5-no-qualifier-keys e "$(lstat "$m")" e12-extends e13 "${B_e12_extends:-0}" "a qualifier with neither key lints clean"
fi
if m="$(mutate m6-any-position "$LINTER" "s/^      append|prepend) : ;;$/      append|prepend|middle) : ;;/")"; then
  score m6-any-position e "$(lstat "$m")" e13 e10 "${B_e13:-0}" "widening the vocabulary accepts the bad value"
fi
if m="$(mutate m7-first-span-only "$LINTER" 's/^      done <<<"\$ext_pairs"$/      done <<<"$(printf "%s\\n" "$ext_pairs" | head -1)"/')"; then
  score m7-first-span-only e "$(lstat "$m")" e11-second e11-nomatch "${B_e11_second:-0}" "checking only the first span lets a broken second anchor lint clean"
fi
if m="$(mutate m8-qualifier-any-anchors "$LINTER" 's/^    elif \[ "\$ext_n" -gt 1 \] && \[ "\$kind" = qualifier \]; then$/    elif false; then/')"; then
  score m8-qualifier-any-anchors e "$(lstat "$m")" e11-two e11-nomatch "${B_e11_two:-0}" "without the limit a qualifier with two sections to render into lints clean"
fi
if m="$(mutate m9-missing-masks-drift "$DRIFT" 's/^    if \[ -z "\$ext_moved" \]; then$/    if [ -z "$ext_moved" ] || [ -n "$ext_missing" ]; then/' "$DMUT")"; then
  score m9-missing-masks-drift d "$(drift_run "$m")" d-missmoved d-vanished "${B_d_missmoved:-0}" "with MISSING masking DRIFT, the rewritten span of missing-and-moved goes unreported"
fi
if m="$(mutate m10-empty-parts-accepted "$LINTER" 's/^    if \[ "\$ext_n" -lt 1 \]; then$/    if false; then/')"; then
  score m10-empty-parts-accepted e "$(lstat "$m")" e11-emptyparts e11-noanchor "${B_e11_emptyparts:-0}" "without the arm, an extends: of only commas lints clean"
fi

# --- CONTROL: every mutation above actually landed -----------------------------
# The ten scored mutants above are each guarded by `if m="$(mutate ...)"`, and a sed
# that matches nothing takes the false branch — no assertion, no diagnostic, and
# a PASS one line shorter than the run before it. This is where mutate()'s file
# is read, because this scope is the only one a `$( )` cannot swallow.
if [ ! -s "$MUT_UNLANDED" ]; then
  ok "control: all 10 mutations landed (a sed matching nothing cannot skip its assertion in silence)"
else
  bad "mutation(s) matched nothing and their assertions were SKIPPED, not failed: $(tr '\n' ' ' < "$MUT_UNLANDED")— each one leaves a check scoring as proven when nothing proved it"
fi

# --- CONTROL: a plain run executed no matrix-only cell --------------------------
# WANT_MATRIX is read off the raw argv, not off the guard, so a guard broken open is caught here.
if [ "$WANT_MATRIX" = 0 ]; then
  if [ "$MATRIX_EMITTED" -eq 0 ]; then
    ok "a plain run executed no matrix-only cell (0 MATRIX cells emitted)"
  else
    bad "a plain run emitted $MATRIX_EMITTED matrix-only cell(s) — the --matrix guard is open and every push pays the full mutant x arm matrix"
  fi
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "layer-qualifier-grain: PASS"
  exit 0
fi
echo "layer-qualifier-grain: $fails assertion(s) failed"
exit 1
