#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }

echo "layer-qualifier-grain:"

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

# The linter arms are DATA: <arm> -> message fragment.
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

echo
report_end layer-qualifier-grain
