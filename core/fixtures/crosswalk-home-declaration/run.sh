#!/usr/bin/env bash
# crosswalk-home-declaration — I69: prose naming where `consumer_crosswalk_file:` LIVES
# must name a file that carries it.
#
# THE DEFECT. The release that moved the crosswalk table to a consumer-owned path shipped
# four statements of where the declaration lives, and all four named `core-manifest.md`.
# The key has never been in that file — it is in `layer-contract.yaml`, and the contract's
# own header explains at length why it is there rather than in the manifest. One of the four
# was W8's remedy string: the single sentence an operator reads WHILE migrating their rows
# told them to open a file with no declaration in it. That is v0.225.0's `anchor_form` class
# one string over — a remedy whose instructions cannot be followed literally.
#
# WHY THE GRAMMAR IS A HOME CLAIM AND NOT A CO-OCCURRENCE, which is the whole of its
# false-positive set. Two paragraphs name `core-manifest.md` next to the token precisely to
# say the declaration is NOT there, with the measurement behind the choice. A rule keyed on
# proximity reports both, and a check that fires on the rationale for its own subject is one
# the operator turns off. Measured against the tree that carried the defect, the shipped
# grammar returns the four real sites and neither rationale paragraph.
#
# WHY THIS FIXTURE MIRRORS RATHER THAN MUTATES IN PLACE. Its subjects — `extensions/README.md`
# and the scaffold template — are read by `layer-crosswalk-home` and by I68 in the same suite,
# and the suite runs 16-way. An in-place mutation with a restoring trap is the established
# idiom in `enforcement-map-sites`, and under a pool it is a cross-talk failure waiting for a
# scheduler: a sibling reading core's README mid-mutation sees bytes no commit ever had.
# `core/` and `scripts/` copy in under a tenth of a second, so the isolated form is also the
# cheap one.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the invariant regressed, 2 = fixture broken.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"       # .dist-only: this fixture is never installed, so there is one layout
VEM="$ROOT/scripts/validate-enforcement-map.sh"
[ -f "$VEM" ] || { echo "FIXTURE ERROR: cannot locate scripts/validate-enforcement-map.sh from $HERE" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/crosswalk-home-decl.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT

fails=0
made=0
ok()  { printf '  ok    %s\n' "$1"; made=$((made+1)); }
bad() { printf '  FAIL  %s\n' "$1"; made=$((made+1)); fails=$((fails+1)); }

# 1 premise + 1 control + 4 mutants.
EXPECTED_ASSERTIONS=6

echo "crosswalk-home-declaration:"

README_REL='core/skills/ai-dlc/extensions/README.md'
TPL_REL='core/skills/ai-dlc/templates/crosswalk.md'

# A disposable mirror. The validator derives its REPO_ROOT from its own location, so a copy
# of core/ and scripts/ under one parent IS a repo as far as it is concerned.
mirror() { # mirror <name> -> <root>
  local m="$WORK/$1"
  mkdir -p "$m" || return 1
  cp -R "$ROOT/core" "$ROOT/scripts" "$m/" || return 1
  printf '%s' "$m"
}

# The I69 lines only. The mirror carries no .githooks/, VERSION or CHANGELOG, so several
# unrelated invariants fail in it and the exit code says nothing about this one. Keying on
# the count of I69 findings is what makes each verdict attributable to the arm under test —
# and the knock-out mutant at the end is what proves the count is coming from I69 rather
# than from the run having died before reaching it.
i69_count() { # i69_count <root> -> n
  bash "$1/scripts/validate-enforcement-map.sh" 2>&1 | grep -c 'I69' || true
}

# mutate <root> <file-rel> <perl-expr> -> 0 if the file actually changed
mutate() { # the cmp -s guard: an expression that matched nothing must not score a kill
  local r="$1" f="$2" e="$3"
  cp "$r/$f" "$WORK/before.$$" || return 1
  perl -0pi -e "$e" "$r/$f" || return 1
  if cmp -s "$WORK/before.$$" "$r/$f"; then rm -f "$WORK/before.$$"; return 1; fi
  rm -f "$WORK/before.$$"; return 0
}

# ---------------------------------------------------------------------------
# premise — the shipped tree states the home somewhere, or every mutant below is
# rewriting text that is not there and the control's zero means nothing
# ---------------------------------------------------------------------------
CLAIMS=$(grep -c 'declares as `consumer_crosswalk_file' "$ROOT/$README_REL" "$ROOT/core/skills/ai-dlc/layer-contract.yaml" 2>/dev/null | awk -F: '{s+=$2} END{print s+0}')
if [ "$CLAIMS" -ge 2 ]; then
  ok "premise: core states the declaration's home in $CLAIMS place(s) — there is a claim to get wrong"
else
  bad "premise: found $CLAIMS home claim(s) in the shipped tree, expected at least 2. Every mutant below would rewrite absent text and the cmp -s guard would report it, but the CONTROL's zero would read as clean."
fi

# ---------------------------------------------------------------------------
# the control — an unmutated mirror is SILENT on I69
# ---------------------------------------------------------------------------
M0="$(mirror control)" || { echo "FIXTURE ERROR: mirror failed" >&2; exit 2; }
N0="$(i69_count "$M0")"
[ "$N0" -eq 0 ] \
  && ok "CONTROL: an unmutated mirror reports I69 zero times — the mutants below run against a tree the invariant accepts" \
  || bad "CONTROL: the unmutated mirror already reports I69 $N0 time(s); every mutant verdict below is meaningless"

# ---------------------------------------------------------------------------
# M1 — the same-line home claim names a file with no declaration in it
# ---------------------------------------------------------------------------
M1="$(mirror m1)" || exit 2
if mutate "$M1" "$README_REL" 's/`layer-contract\.yaml` declares as/`core-manifest.md` declares as/'; then
  N1="$(i69_count "$M1")"
  [ "$N1" -eq 1 ] \
    && ok "MUTANT killed: a README claiming the declaration lives in core-manifest.md is reported once" \
    || bad "MUTANT m1: expected exactly 1 I69 finding, got $N1 — the shipped grammar does not see a same-line home claim"
else
  bad "MUTANT m1 did not apply (the expression matched nothing) — a mutation that changes nothing scores a kill it has not earned"
fi

# ---------------------------------------------------------------------------
# M2 — the claim WRAPS. The window is two lines for exactly this reason: the
# template's claim spanned a line break, a line-scoped reader missed it, and its
# control fired anyway on the sites that happened to fit on one line.
# ---------------------------------------------------------------------------
M2="$(mirror m2)" || exit 2
if mutate "$M2" "$TPL_REL" 's/`consumer_crosswalk_file:` in `\.claude\/skills\/ai-dlc\/layer-contract\.yaml`/`consumer_crosswalk_file:` in\n`.claude\/skills\/ai-dlc\/core-manifest.md`/'; then
  N2="$(i69_count "$M2")"
  [ "$N2" -eq 1 ] \
    && ok "MUTANT killed: a home claim broken across a line break is still read, and still reported once" \
    || bad "MUTANT m2: expected exactly 1 I69 finding, got $N2 — a claim that wraps escapes the grammar, which is the shape the real defect had"
else
  bad "MUTANT m2 did not apply (the expression matched nothing) — the template's claim is not where this fixture thinks it is"
fi

# ---------------------------------------------------------------------------
# M3 — the ZERO GUARD. Every fix to this invariant removes one of its own
# subjects, so its failure mode is going quiet rather than going wrong.
# ---------------------------------------------------------------------------
M3="$(mirror m3)" || exit 2
if mutate "$M3" "$README_REL" 's/declares as `consumer_crosswalk_file:`/is bound to the reader by/' \
   && mutate "$M3" "$TPL_REL" 's/declared as\n`consumer_crosswalk_file:` in/bound to the reader by\n`consumer_crosswalk_file:` via/' \
   && mutate "$M3" 'core/skills/ai-dlc/layer-contract.yaml' 's/declares as `consumer_crosswalk_file:`/is bound to the reader by/g'; then
  N3="$(i69_count "$M3")"
  [ "$N3" -eq 1 ] \
    && ok "MUTANT killed: with every home claim reworded away the ZERO GUARD speaks — an empty subject set is reported, not accepted" \
    || bad "MUTANT m3: expected exactly 1 I69 finding (the zero guard), got $N3 — a grammar that stopped matching would read exactly like core having stopped restating the home"
else
  bad "MUTANT m3 did not apply to all three claim sites — the zero guard is unproven"
fi

# ---------------------------------------------------------------------------
# M4 — the KNOCK-OUT. Deleting I69's own err line from the mirrored validator must
# take M1's finding with it. Without this arm every count above could be coming
# from a run that died before reaching this invariant.
# ---------------------------------------------------------------------------
M4="$(mirror m4)" || exit 2
if mutate "$M4" "$README_REL" 's/`layer-contract\.yaml` declares as/`core-manifest.md` declares as/' \
   && mutate "$M4" 'scripts/validate-enforcement-map.sh' 's/      err "I69 \$_cf names/      : "I69 \$_cf names/'; then
  N4="$(i69_count "$M4")"
  [ "$N4" -eq 0 ] \
    && ok "KNOCK-OUT: with I69's err disabled the same violating tree reports nothing — M1's kill is attributable to this invariant" \
    || bad "KNOCK-OUT: expected 0 I69 findings with the err disabled, got $N4 — the counts above are not measuring what this fixture claims"
else
  bad "KNOCK-OUT did not apply — the arm's attribution is unproven"
fi

# ---------------------------------------------------------------------------
if [ "$made" -ne "$EXPECTED_ASSERTIONS" ]; then
  echo "  FAIL  assertion count: ran $made, expected $EXPECTED_ASSERTIONS — an arm did not execute, and one that never ran is silent, not green"
  fails=$((fails+1))
fi

echo
if [ "$fails" -eq 0 ]; then
  echo "crosswalk-home-declaration: PASS ($made assertions)"; exit 0
else
  echo "crosswalk-home-declaration: FAIL ($fails of $made)"; exit 1
fi
