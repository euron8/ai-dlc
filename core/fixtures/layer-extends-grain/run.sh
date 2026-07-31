#!/usr/bin/env bash
# layer-extends-grain — the charter's load-bearing `extends:` assertion, proved on the
# axis no fixture varies today: THE SPAN.
#
# THE ASSERTION (charter, fixtures table): a commit changing the hooked file OUTSIDE the
# declared anchor produces NO drift row for the anchored entry. That is what says the
# narrowing is real and not a relabelling.
#
# WHY THIS IS NOT layer-qualifier-grain RESTATED, since that fixture states the same
# sentence in its own header and asserts it in Part 1a. It asserts it by varying the
# ENTRY inside ONE span: three entries, three anchors, three verdicts from a single
# base..theirs. Every verdict there is attributable to something the entry declares, so a
# classifier keyed on anything entry-intrinsic — the id, the basename, merely WHETHER
# `extends:` is present — reproduces its entire result table without reading a section
# body at either ref. The charter's second arm is the one that closes that hole: the SAME
# entry, across a second span in which its OWN anchor moved. Held fixed, an entry cannot
# supply the difference, so the difference has to come from the bytes.
#
# The two runs are a full 2x2 and the two anchored entries SWAP verdicts between them:
#
#                       run 1  BASE..MID        run 2  MID..TIP
#   anchored-alpha      EXTENSION-OK            EXTENSION-ANCHOR-DRIFT
#   anchored-beta       EXTENSION-ANCHOR-DRIFT  EXTENSION-OK
#   unanchored          EXTENSION-HOOK-DRIFT    EXTENSION-HOOK-DRIFT
#
# Row 1 column 1 is the charter's arm. Row 1 column 2 is the same entry once its own
# anchor moves. Row 2 column 2 is the diagonal — a sibling staying quiet in the very run
# where its neighbour reports, which is what separates narrowing from silencing. Row 3 is
# the liveness witness: every EXTENSION-OK above is an ABSENCE of a drift row, and a
# classifier that had stopped emitting would satisfy all of them, so one entry has to
# report in both runs for any of it to mean anything.
#
# MUTANT SCORING IS BY EXACT VECTOR, not per row. Both branches under test are occupied
# twice in the table above — EXTENSION-OK at (alpha,run1) and (beta,run2), ANCHOR-DRIFT at
# (beta,run1) and (alpha,run2) — so a mutation of either branch necessarily moves two
# cells and per-row scoring would report entanglement on every mutant. Each mutant instead
# carries ONE assertion: the complete six-cell vector it must produce, stated positively
# and distinct from every other mutant's. Attribution stays exact and no assertion can be
# satisfied by a mutant that merely went quiet.
#
# Usage: run.sh [path-to-layer-drift.sh] [path-to-validate-layer-entries.sh]
# Exit:  0 = every assertion holds, 1 = something regressed, 2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"

# TWO LAYOUTS. install.sh splits what shares a parent here: core/fixtures/ becomes
# tests/fixtures/ and core/scripts/ becomes scripts/ai-dlc/. Every candidate is rooted at
# this file's own location and both layouts are named — I33 fails the build on a fixture
# that reaches a core subtree by walking up from a path some other resolver produced.
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
DRIFT="$(pick "${1:-}" "$HERE/../../skills/ai-dlc-update/reconcile/layer-drift.sh" \
                       "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/layer-drift.sh" \
                       "$HERE/../../../core/skills/ai-dlc-update/reconcile/layer-drift.sh")"
LINTER="$(pick "${2:-}" "$HERE/../../scripts/validate-layer-entries.sh" \
                        "$HERE/../../../scripts/ai-dlc/validate-layer-entries.sh" \
                        "$HERE/../../../core/scripts/validate-layer-entries.sh")"
[ -n "$DRIFT" ]  || { echo "FIXTURE ERROR: cannot locate layer-drift.sh from $HERE" >&2; exit 2; }
[ -n "$LINTER" ] || { echo "FIXTURE ERROR: cannot locate validate-layer-entries.sh from $HERE" >&2; exit 2; }

ROOT="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$ROOT"' EXIT
DIST="$ROOT/dist"; CONS="$ROOT/consumer"
CP="core/skills/ai-dlc/steps/demo.md"
BASE="$(git -C "$DIST" rev-parse --short HEAD~2)"
MID="$(git -C "$DIST" rev-parse --short HEAD~1)"
TIP="$(git -C "$DIST" rev-parse --short HEAD)"

fails=0
made=0
ok()  { printf '  ok    %s\n' "$1"; made=$((made+1)); }
bad() { printf '  FAIL  %s\n' "$1"; made=$((made+1)); fails=$((fails+1)); }

# EXPECTED_ASSERTIONS is not bookkeeping. The first run of this fixture lost an entire
# mutant to a missing space in a `mk_mutant` call: the helper got two arguments instead of
# three, `set -u` killed the SUBSHELL that `$( )` had opened, `if m="$( … )"` read that as
# a false branch, and the arm silently did not run. Seventeen assertions passed, the
# fixture printed PASS, and the mutant proving the load-bearing branch had disappeared —
# a check that cannot fire reading exactly like one that passed, inside a fixture written
# about that class. Counting what actually ran is what closes it, and the count has to be
# a literal here rather than derived from the assertions, or it disappears with them.
# 6 premises (2 span-changed + 4 section-identity) + 6 shipped arms + 1 lint + 1 control + 4 mutants.
EXPECTED_ASSERTIONS=18

echo "layer-extends-grain:"

# vector <drift-script> <base> <theirs> -> "alpha=<status> beta=<status> unanchored=<status>"
# A cell with no row reads as `-`, and a cell with two reads as both joined by `+`, so a
# classifier that emitted nothing and one that emitted twice are both distinguishable from
# the expected vector rather than collapsing into it.
vector() {
  local out cell v=""
  out="$(bash "$1" "$DIST" "$2" "$3" "$CONS" 2>&1)"
  for e in anchored-alpha anchored-beta unanchored; do
    cell="$(printf '%s\n' "$out" | awk -v e="/$e.md" -F'\t' 'index($2, e) {print $1}' \
            | grep '^EXTENSION-' | sort -u | paste -sd+ -)"
    v="$v${v:+ }${e#anchored-}=${cell:--}"
  done
  printf '%s' "$v"
}

V1="$(vector "$DRIFT" "$BASE" "$MID")"
V2="$(vector "$DRIFT" "$MID" "$TIP")"

WANT1='alpha=EXTENSION-OK beta=EXTENSION-ANCHOR-DRIFT unanchored=EXTENSION-HOOK-DRIFT'
WANT2='alpha=EXTENSION-ANCHOR-DRIFT beta=EXTENSION-OK unanchored=EXTENSION-HOOK-DRIFT'

# --- Part 0: the seed is two real spans, measured WITHOUT the code under test ----------
# The claims "the file moved" and "this section did not" are the fixture's own premises.
# Reading them back through lib.sh's section_of would make the premise and the conclusion
# the same measurement: a resolver that returned the empty string for everything would
# report every section unchanged AND make every anchored entry report EXTENSION-OK, and
# this fixture would call that a pass. So the sections are extracted here by an
# independent awk that shares no code with the classifier.
sect() { # sect <ref> <heading-text>
  git -C "$DIST" show "$1:$CP" 2>/dev/null \
    | awk -v h="## $2" 'index($0,h)==1 {f=1; next} f && /^## / {exit} f {print}'
}
premise() { # premise <label> <same|differ> <ref-a> <ref-b> <heading> <why>
  local want="$2" a b
  a="$(sect "$3" "$5")"; b="$(sect "$4" "$5")"
  [ -n "$a" ] && [ -n "$b" ] || { bad "$1 — the independent extractor read an EMPTY '$5' at $3 or $4, so this premise is unmeasured and every verdict below rests on it"; return; }
  if [ "$a" = "$b" ]; then
    [ "$want" = same ] && ok "$1" || bad "$1 — '$5' is byte-identical $3..$4 but the seed needs it to MOVE. $6"
  else
    [ "$want" = differ ] && ok "$1" || bad "$1 — '$5' changed $3..$4 but the seed needs it byte-identical. $6"
  fi
}
for span in "$BASE $MID run1" "$MID $TIP run2"; do
  set -- $span
  if git -C "$DIST" diff --quiet "$1" "$2" -- "$CP"; then
    bad "$3: the hooked file does not change $1..$2 at all — 'the anchored entry went quiet' would be trivially true and would hold against a classifier that had stopped running"
  else
    ok "$3: the hooked file really does change $1..$2 (so silence has to be earned)"
  fi
done
premise "run1 premise: '#Alpha gate' is byte-identical while the file moves" same   "$BASE" "$MID" "Alpha gate"  "This is THE charter arm; if it moved, the arm proves nothing."
premise "run1 premise: '#Beta review' is what moved"                        differ "$BASE" "$MID" "Beta review" "Without it the run-1 file change is not attributable."
premise "run2 premise: '#Alpha gate' is what moved"                         differ "$MID" "$TIP" "Alpha gate"   "This is the same-entry-second-span arm."
premise "run2 premise: '#Beta review' is byte-identical while the file moves" same "$MID" "$TIP" "Beta review"  "This is the diagonal."

# --- Part 1: the shipped verdicts, per arm --------------------------------------------
# Asserted per arm rather than as a vector so a regression names the arm it broke. The
# vector form is used for the mutants below, where attribution is what is at stake.
arm() { # arm <label> <vector> <key=status> <why>
  case " $2 " in *" $3 "*) ok "$1" ;;
    *) bad "$1 — got '${2}', wanted '$3'. $4" ;; esac
}
arm "run1  anchor OUTSIDE the change: EXTENSION-OK" "$V1" "alpha=EXTENSION-OK" \
  "anchored-alpha declares '#Alpha gate', which Part 0 measured byte-identical across this span while the file itself moved. A drift row here means the anchor is not being read and this is file grain wearing a new name."
arm "run1  anchor AT the change: EXTENSION-ANCHOR-DRIFT" "$V1" "beta=EXTENSION-ANCHOR-DRIFT" \
  "anchored-beta's declared span is the one body this span rewrites. A quiet row here is the narrowing swallowing a real change."
arm "run2  THE SAME ENTRY, span where its OWN anchor moved: EXTENSION-ANCHOR-DRIFT" "$V2" "alpha=EXTENSION-ANCHOR-DRIFT" \
  "anchored-alpha is byte-identical to the entry that went quiet in run 1 — same file, same frontmatter, same anchor. Only the span changed. If it stays quiet here, the run-1 silence was a property of the entry rather than of the bytes, and the narrowing is a relabelling."
arm "run2  THE DIAGONAL: sibling anchored elsewhere stays EXTENSION-OK in that same run" "$V2" "beta=EXTENSION-OK" \
  "anchored-beta must be quiet in the run where anchored-alpha reports, and loud in the run where it does not. One entry reporting proves the classifier can speak; this pair inverting in the same runs is what proves it is speaking about the declared span."
arm "run1  liveness: an entry declaring no anchor keeps file grain" "$V1" "unanchored=EXTENSION-HOOK-DRIFT" \
  "the narrowing must not reach entries that never asked for it, and without a row in this run every EXTENSION-OK above is satisfied by a classifier that emitted nothing."
arm "run2  liveness: an entry declaring no anchor keeps file grain" "$V2" "unanchored=EXTENSION-HOOK-DRIFT" \
  "same, for the second span."

# --- Part 2: the seeded entries are ones a consumer could actually author --------------
# E11 rejects several `extends:` spellings. If the seed's entries were among them, the
# whole table above would be describing classifier behaviour on input the authoring linter
# forbids — green here, unreachable in any real consumer.
LINT_OUT="$(bash "$LINTER" "$CONS" 2>&1)"
if grep -q '^ERROR' <<<"$LINT_OUT"; then
  bad "the seeded consumer draws authoring errors, so every verdict above is measured on entries no consumer could ship:
$(printf '%s' "$LINT_OUT" | grep '^ERROR' | sed 's/^/        /')"
else
  ok "the seeded consumer lints clean, so the classified entries are authorable"
fi

# --- Part 3: mutants -------------------------------------------------------------------
# COPIES, never in-place edits, each guarded by `cmp -s` so a sed that matched nothing
# cannot pass as a mutation.
#
# The copy is of the WHOLE reconcile/ directory, not of layer-drift.sh alone.
# `layer-drift.sh` sources `lib.sh` from beside itself and exits when it cannot, so a lone
# copy emits NOTHING — and "no output" is indistinguishable from "the mutated branch went
# quiet", i.e. it scores as a kill for every mutant at once. The unmutated control below is
# what detects that, and it runs FIRST for that reason. Two of the four mutations land in
# lib.sh rather than in the classifier, which the whole-directory copy also makes possible.
RECON="$(cd "$(dirname "$DRIFT")" && pwd)"
DRIFT_BN="$(basename "$DRIFT")"
MDIR="$ROOT/mutants"; mkdir -p "$MDIR"

cp -R "$RECON" "$MDIR/control"
c1="$(vector "$MDIR/control/$DRIFT_BN" "$BASE" "$MID")"
c2="$(vector "$MDIR/control/$DRIFT_BN" "$MID" "$TIP")"
if [ "$c1" = "$V1" ] && [ "$c2" = "$V2" ]; then
  ok "CONTROL: an unmutated copy reproduces both shipped vectors (the harness runs)"
else
  bad "CONTROL FAILED: an unmutated COPY of reconcile/ does not reproduce the shipped verdicts (run1 copy='$c1' shipped='$V1'; run2 copy='$c2' shipped='$V2'). Every mutant below would be scored against a harness that is not working, and a copy that cannot run scores as a kill for all of them."
fi

mk_mutant() { # mk_mutant <name> <file-relative-to-reconcile> <sed-expr> -> mutant drift path
  local name="$1" rel="$2" expr="$3" dir="$MDIR/$1"
  rm -rf "$dir"; cp -R "$RECON" "$dir"
  sed "$expr" "$RECON/$rel" > "$dir/$rel.mut" || { bad "MUTANT '$name': sed failed"; return 1; }
  if cmp -s "$dir/$rel.mut" "$RECON/$rel"; then
    bad "MUTANT '$name' changed nothing — its sed matched no line, so the assertion below would score a working classifier as a kill"
    rm -rf "$dir"; return 1
  fi
  mv "$dir/$rel.mut" "$dir/$rel"
  printf '%s' "$dir/$DRIFT_BN"
}

# ONE assertion per mutant: the exact six-cell vector it must produce. Stated as the
# vector rather than as "the old row is gone" so a mutant that broke the script outright
# fails its own assertion instead of passing it.
expect() { # expect <name> <what-it-proves> <mutant-drift> <want-run1> <want-run2>
  local g1 g2
  g1="$(vector "$3" "$BASE" "$MID")"; g2="$(vector "$3" "$MID" "$TIP")"
  if [ "$g1" = "$4" ] && [ "$g2" = "$5" ]; then
    ok "MUTANT $1 killed: $2"
  else
    bad "MUTANT $1 did not produce its expected vector, so the assertion it is meant to prove is unproven ($2).
          run1 got  '$g1'
          run1 want '$4'
          run2 got  '$g2'
          run2 want '$5'"
  fi
}

# M1 — read the declared span at THEIRS only, never at BASE. This is the narrowing with
# its comparison removed: the span still resolves, so ANCHOR-MISSING is unaffected, but
# nothing is ever compared against and every anchored entry reports OK forever. It is the
# exact shape of "narrower means quieter", and it moves ONLY the two ANCHOR-DRIFT cells.
if m="$(mk_mutant m1-no-base-side "$DRIFT_BN" 's|^      ext_old="[$](git_show .*|      ext_old="$ext_new"|')"; then
  expect m1-no-base-side \
    "with the BASE side of the span comparison gone, both ANCHOR-DRIFT cells become OK while the file-grain cells are untouched — the drift verdicts are produced by comparing the declared span at two refs, not by the entry having declared one" \
    "$m" \
    'alpha=EXTENSION-OK beta=EXTENSION-OK unanchored=EXTENSION-HOOK-DRIFT' \
    'alpha=EXTENSION-OK beta=EXTENSION-OK unanchored=EXTENSION-HOOK-DRIFT'
fi

# M2 — the narrowing leaks onto entries that never declared an anchor. Only the file-grain
# fallback's status changes, so the four anchored cells are untouched and this mutant is
# the one that proves the liveness witness is a witness rather than a constant.
if m="$(mk_mutant m2-narrowing-leaks "$DRIFT_BN" 's|^    emit EXTENSION-HOOK-DRIFT |    emit EXTENSION-OK |')"; then
  expect m2-narrowing-leaks \
    "an entry declaring no extends: stops keeping the whole file as its drift subject, and only that — so the six-cell table above cannot be satisfied by a classifier that reports OK for everything unanchored" \
    "$m" \
    'alpha=EXTENSION-OK beta=EXTENSION-ANCHOR-DRIFT unanchored=EXTENSION-OK' \
    'alpha=EXTENSION-ANCHOR-DRIFT beta=EXTENSION-OK unanchored=EXTENSION-OK'
fi

# M3 — every entry that declares an anchor watches the FIRST entry's anchor instead of its
# own. The narrowing still happens, the spans are still compared at both refs, and M1's
# and M2's assertions all survive: what dies is per-entry attribution. anchored-beta now
# tracks Alpha, so it goes quiet in run 1 and reports in run 2 — the diagonal inverts. This
# is the mutant the diagonal exists for, and nothing else in the table detects it.
if m="$(mk_mutant m3-shared-anchor "$DRIFT_BN" 's|^    ext_anc="[$](printf .*|    ext_anc="Alpha gate"|')"; then
  expect m3-shared-anchor \
    "when every anchored entry watches one shared span, the diagonal inverts — which is the only cell that moves, and the reason a sibling assertion is not a restatement of the load-bearing one" \
    "$m" \
    'alpha=EXTENSION-OK beta=EXTENSION-OK unanchored=EXTENSION-HOOK-DRIFT' \
    'alpha=EXTENSION-ANCHOR-DRIFT beta=EXTENSION-ANCHOR-DRIFT unanchored=EXTENSION-HOOK-DRIFT'
fi

# M4 — the anchor resolves, and then the "span" it resolves to is the whole file. The
# narrowing is present in form and absent in substance, which is precisely what a
# relabelling would look like: `extends:` declared, read, and ignored. Both OK cells become
# ANCHOR-DRIFT and the two drift cells stay put, so this is the mutant that proves the two
# EXTENSION-OK verdicts are earned by the span comparison rather than defaulted into.
# It lands in lib.sh's section_of(), which is byte-identical to the authoring linter's
# under I40 — mutating a throwaway copy does not touch that binding.
if m="$(mk_mutant m4-span-is-file lib.sh 's|^  \[ -n "[$]_s" \] && sed -n .*|  [ -n "$_s" ] \&\& cat "$_t"|')"; then
  expect m4-span-is-file \
    "with the declared span widened back to the whole file, both EXTENSION-OK cells become ANCHOR-DRIFT — the quiet verdicts are produced by comparing the anchor's own bytes, not by the presence of an extends: line" \
    "$m" \
    'alpha=EXTENSION-ANCHOR-DRIFT beta=EXTENSION-ANCHOR-DRIFT unanchored=EXTENSION-HOOK-DRIFT' \
    'alpha=EXTENSION-ANCHOR-DRIFT beta=EXTENSION-ANCHOR-DRIFT unanchored=EXTENSION-HOOK-DRIFT'
fi

echo
if [ "$made" -ne "$EXPECTED_ASSERTIONS" ]; then
  echo "layer-extends-grain: FAIL — $made assertions ran, $EXPECTED_ASSERTIONS were written. An arm did not execute at all, which is not the same as an arm that passed. Find the one that vanished before reading anything above as green."
  exit 1
fi
if [ "$fails" -eq 0 ]; then
  echo "layer-extends-grain: PASS ($made assertions)"
  exit 0
fi
echo "layer-extends-grain: $fails of $made assertion(s) failed"
exit 1
