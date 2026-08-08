#!/usr/bin/env bash
# changelog-sprint-slot — assert every core site that prescribes appending a changelog
# names the sprint slot, and that the one canonical declaration behind them exists.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# WHAT THIS EXISTS FOR.
#
# Rule 15 says "append a brief changelog to the artifact". Six core sites restated that
# and four of them named a DURABLE target — the brief, the PRD, the architecture doc, and
# "all modified artifacts". A changelog entry is a record of one sprint's passes, so a
# durable target puts sprint-scoped content at a sprint-independent path: the same defect
# artifact-consolidation.md had for its four working files, and the same one item 10 was
# opened to eliminate.
#
# Measured on the reference consumer before this changed: the live product-brief.md was
# 1030 lines, of which 223 (21%) were four changelog entries ALL dated 2026-08-05 and ALL
# belonging to one sprint — inside an artifact validate-artifact-budget.sh pools as a
# whole read. Across its durable artifacts the live total was 260 lines (223 in the brief,
# 37 in docs/architecture.md, 0 in prd.md); the remaining ~9,800 changelog lines sit in
# `-history.md` files that is_archive() already exempts and that are not this fixture's
# subject.
#
# WHY NO EXISTING CHECK CAUGHT IT. Identical to consolidation-residue's reason and worth
# restating rather than cross-referencing: I82 binds prescribed paths to the artifact path
# grammar, but the grammar detects a sprint TOKEN outside the slot. "the brief" is not a
# path at all, and `s<N>/changelog-prd.md` and `planning-artifacts/prd.md` are BOTH
# syntactically conforming. Only the site that writes the file knows which it is, so the
# assertion has to live against the sites.
#
# THE SITE SET IS DERIVED, NEVER HAND-LISTED. Assertion 1 finds every prescribing site by
# searching for the instruction, then classifies each. A hand-list would go stale the first
# time a step file gained a convergence line — which is exactly how four of these six came
# to disagree with each other in the first place.

set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

if [ -n "$ROOT" ] && [ -d "$ROOT/core/skills/ai-dlc/steps" ]; then
  SKILLDIR="$ROOT/core/skills/ai-dlc"
elif [ -n "$ROOT" ] && [ -d "$ROOT/.claude/skills/ai-dlc/steps" ]; then
  SKILLDIR="$ROOT/.claude/skills/ai-dlc"
else
  echo "FIXTURE ERROR: ai-dlc skill directory not found in either layout" >&2
  echo "  looked in: $ROOT/core/skills/ai-dlc (distribution), $ROOT/.claude/skills/ai-dlc (consumer)" >&2
  exit 2
fi
GATEPROC="$SKILLDIR/steps/_gate-procedures.md"
[ -f "$GATEPROC" ] || { echo "FIXTURE ERROR: _gate-procedures.md not found at $GATEPROC" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# The instruction, as a line pattern. Deliberately loose on what sits between the verb and
# the noun -- "append a changelog", "append a brief changelog", "Append the step's
# changelog" and "append changelog" are all in the tree and all prescribe the same thing.
PRESCRIBE='[Aa]ppend[a-z]*[^.]{0,48}changelog'

# One prescription, flattened with the three lines after it: the path lands on the NEXT
# line at every multi-line site, so a line-scoped classifier would call all of them
# offenders. Emits "<file>:<lineno><TAB><flattened text>".
prescriptions() {
  local f
  for f in "$@"; do
    awk -v F="$f" -v P="$PRESCRIBE" '
      $0 ~ P {
        n = NR; s = $0
        for (i = 1; i <= 3; i++) { if ((getline nx) > 0) s = s " " nx; else break }
        gsub(/[ \t]+/, " ", s)
        printf "%s:%d\t%s\n", F, n, s
      }' "$f"
  done
}

# Every file that carries the instruction at all. Derived, so a new step file joins the
# subject set by existing rather than by being remembered here.
site_files() {
  grep -rlE "$PRESCRIBE" "$SKILLDIR/steps" "$SKILLDIR/SKILL.md" 2>/dev/null | sort -u
}

# A prescription is CONFORMING when it names the slotted changelog path OR names the one
# canonical declaration that holds it, and EXEMPT when its target is a story file -- a
# story already lives in s<N>/stories/, so it carries its own sprint and has no durable
# artifact to pollute. Anything else is the finding.
#
# Naming the declaration counts as naming the target ON PURPOSE. _gate-procedures.md's own
# step-loop line says "append the step's changelog (\"Where a changelog is written\"
# below)", and requiring it to restate the path would be requiring the second copy this
# release exists to remove.
offenders() {
  prescriptions "$@" \
    | grep -v 's<N>/changelog-' \
    | grep -v 'Where a changelog is written' \
    | grep -vi 'story' || true
}

echo "changelog-sprint-slot"

mapfile_files="$WORK/files"
site_files > "$mapfile_files"
n_files="$(grep -c . < "$mapfile_files" || true)"
# shellcheck disable=SC2046
set -- $(cat "$mapfile_files")

# --- 1. NO PRESCRIPTION NAMES A DURABLE TARGET --------------------------------
n_off="$(offenders "$@" | grep -c . || true)"
if [ "$n_off" -eq 0 ]; then
  ok "every changelog prescription names the sprint slot or a story file"
else
  bad "$n_off prescription(s) name neither the sprint slot nor a story"
  offenders "$@" | cut -c1-160 | sed 's/^/        /'
fi

# --- 2. CONTROL: the instruction is FOUND, and in more than one file ----------
# Without this, assertion 1 passes over a tree where the pattern matches nothing -- a
# renamed instruction, a moved directory, a typo in $PRESCRIBE. An absence is not a
# finding until something proves the search could have found one.
n_pre="$(prescriptions "$@" | grep -c . || true)"
n_slot="$(prescriptions "$@" | grep -c 's<N>/changelog-' || true)"
if [ "$n_files" -ge 4 ] && [ "$n_pre" -ge 6 ] && [ "$n_slot" -ge 4 ]; then
  ok "  control: $n_pre prescription(s) across $n_files file(s), $n_slot slotted -- assertion 1 is not vacuous"
else
  bad "  control failed: $n_pre prescription(s) across $n_files file(s), $n_slot slotted -- assertion 1 proves nothing"
fi

# --- 3. THE CANONICAL DECLARATION EXISTS AND IS THE ONLY FULL SPELLING --------
# The four convergence lines point at one declaration rather than restating the rule, so
# that a future change to the path is one edit. If the declaration goes, they point at
# nothing and the next author restates it -- which is how these sites diverged before.
# Keyed on the HEADING, not on the phrase. The phrase also occurs in every pointer, so a
# phrase-keyed test would be satisfied by the pointers alone -- green with the section they
# point at deleted, which is the exact shape of a check that cannot fail.
if grep -qE '^#{2,3} Where a changelog is written' "$GATEPROC"; then
  ok "the canonical declaration section is in _gate-procedures.md"
else
  bad "no 'Where a changelog is written' SECTION in _gate-procedures.md -- the pointers dangle"
fi
n_point="$(grep -rl 'Where a changelog is written' "$SKILLDIR/steps" "$SKILLDIR/SKILL.md" 2>/dev/null | wc -l | tr -d ' ')"
if [ "$n_point" -ge 5 ]; then
  ok "  $n_point file(s) reference the declaration rather than restating the path"
else
  bad "  only $n_point file(s) reference the declaration -- the path is being restated again"
fi

# --- 4. MUTATION: point one convergence line back at the durable artifact -----
# Prove assertion 1 measures the TARGET rather than the presence of the word. Built as a
# copy and guarded with cmp -s so a sed that matched nothing cannot pass as a mutation.
SRC="$SKILLDIR/steps/research-requirements.md"
[ -f "$SRC" ] || { echo "FIXTURE ERROR: research-requirements.md not found at $SRC" >&2; exit 2; }
# The revert this mutant models is the WHOLE prescription going back to naming the durable
# artifact -- the path AND the pointer, since leaving either behind would let the
# classifier pass it for a reason a real regression would not supply.
MUT1="$WORK/mutant-durable.md"
# Two independent substitutions rather than one, because the prescription wraps across
# four lines and the path and the pointer land on different ones.
sed -e 's|_bmad-output/planning-artifacts/s<N>/changelog-prd.md|the PRD|' \
    -e 's|"Where a changelog is written"|the step loop|' \
    "$SRC" > "$MUT1" || exit 2
if cmp -s "$SRC" "$MUT1"; then
  echo "FIXTURE ERROR: mutation matched nothing -- the convergence line was rewritten" >&2
  echo "  update the sed patterns in assertion 4 to match the real prescription" >&2
  exit 2
fi
if grep -q 's<N>/changelog-prd.md' "$MUT1" || grep -q 'Where a changelog is written' "$MUT1"; then
  echo "FIXTURE ERROR: mutation left the slot path or the pointer in place -- it would be" >&2
  echo "  measuring the leftover rather than the revert" >&2
  exit 2
fi
if [ "$(offenders "$MUT1" | grep -c . || true)" -ge 1 ]; then
  ok "MUTATION: a prescription pointed back at the durable artifact is reported"
else
  bad "MUTATION: a durable target was NOT reported -- assertion 1 proves nothing"
fi

# --- 5. MUTATION: delete the canonical declaration ----------------------------
# Assertion 3 and assertion 1 must fail for DIFFERENT reasons, so this mutant is checked
# against assertion 3 only and then asserted NOT to trip assertion 1. Two failures would
# mean the assertions are entangled and one of them is vacuous.
MUT2="$WORK/mutant-nodecl.md"
grep -vE '^#{2,3} Where a changelog is written' "$GATEPROC" > "$MUT2" || exit 2
if cmp -s "$GATEPROC" "$MUT2"; then
  echo "FIXTURE ERROR: mutation matched nothing -- the declaration heading was renamed" >&2
  exit 2
fi
if grep -qE '^#{2,3} Where a changelog is written' "$MUT2"; then
  bad "MUTATION: the declaration survived its own deletion -- assertion 3 proves nothing"
else
  ok "MUTATION: deleting the canonical declaration is detected"
fi
if [ "$(offenders "$MUT2" | grep -c . || true)" -eq 0 ]; then
  ok "  and it leaves assertion 1 green -- the two assertions are not entangled"
else
  bad "  the declaration mutant also tripped the target assertion -- one of them is vacuous"
fi

# --- 6. UNMUTATED CONTROL -----------------------------------------------------
# A copy made the same way, unmutated. Without it a mutant that dies on a malformed copy
# emits nothing, and "no offenders" scores as a pass rather than as a broken run.
CTRL="$WORK/control.md"
cp "$SRC" "$CTRL" || exit 2
if [ "$(prescriptions "$CTRL" | grep -c . || true)" -ge 1 ] \
   && [ "$(offenders "$CTRL" | grep -c . || true)" -eq 0 ]; then
  ok "  control: an unmutated copy read the same way is still clean and still non-empty"
else
  bad "  the unmutated copy did not read clean -- assertions 4-5 are measuring the harness"
fi

echo ""
if [ "$fails" -eq 0 ]; then
  echo "changelog-sprint-slot: PASS"
  exit 0
fi
echo "changelog-sprint-slot: FAIL ($fails assertion(s))"
exit 1
