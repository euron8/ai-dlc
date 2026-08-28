#!/usr/bin/env bash
# A heading that NAMES a rendered artifact section must be a SIBLING of the numbered step,
# never a CHILD of one.
#
# WHY THIS IS A BEHAVIOURAL PROPERTY AND NOT A STYLE RULE. Precedence replaces the WHOLE
# shadowed span at load time -- `core/skills/ai-dlc/layer-contract.yaml:543` and
# `core/skills/ai-dlc/overrides/README.md:127` both say so. So when a heading naming a
# rendered artifact section sits INSIDE a numbered step's span, every consumer override that
# shadows that step displaces the artifact's definition as a side effect, whether or not the
# override says one word about it. The consumer cannot fix that from its own layer: the three
# remedies available to it each drop something, and none addresses why the collision exists.
#
# Filed by the reference consumer as
# PC-S307-MACHINE-AUDITS-IS-A-CHILD-OF-4A-SO-EVERY-4A-SHADOW-SWALLOWS-IT. Measured there:
# ZERO overrides anchor the artifact heading directly, against a positive control of 9
# `shadows:` lines -- so promoting it breaks no entry and costs the consumer nothing.
#
# THE ORACLE IS THE SHIPPING `span_of`, NOT A GRAMMAR THIS FILE INVENTS. The property is
# "which lines does a shadow of the numbered step cover", and `span_of` is the one function
# that answers it -- `lib.sh` says in as many words that it is THE matcher and that a second
# copy is how two divergences already happened. A fixture that re-implemented the containment
# test would be asserting its own reading of the rule rather than the rule.
#
# THE ABSENCE-SHAPED ARM CARRIES A COMMITTED MUTANT, because it must. Arm 2 asserts the
# heading is OUTSIDE the span, which is what a tree that never ran also reports. The mutant
# re-nests the heading in a COPY and requires the same computation to put it INSIDE. Without
# that, this file passes against a `span_of` that returns nothing at all.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

# Both layouts. The distribution keeps core under core/; install.sh lands the skills at
# .claude/ and relocates fixtures to tests/fixtures/, which is THREE levels up rather than two.
LIB=""; STEPS=""; LOOKED=""
for cand in \
  "$DIR/../../skills/ai-dlc-update/reconcile/lib.sh" \
  "$DIR/../../../core/skills/ai-dlc-update/reconcile/lib.sh" \
  "$DIR/../../../.claude/skills/ai-dlc-update/reconcile/lib.sh"; do
  LOOKED="$LOOKED  $cand
"
  [ -f "$cand" ] && LIB="$cand" && break
done
for cand in \
  "$DIR/../../skills/ai-dlc/steps/retro.md" \
  "$DIR/../../../core/skills/ai-dlc/steps/retro.md" \
  "$DIR/../../../.claude/skills/ai-dlc/steps/retro.md"; do
  LOOKED="$LOOKED  $cand
"
  [ -f "$cand" ] && STEPS="$cand" && break
done
[ -n "$LIB" ] && [ -n "$STEPS" ] || {
  printf 'FAIL: cannot locate lib.sh and/or steps/retro.md from %s. Looked in:\n%s' "$DIR" "$LOOKED"
  exit 1
}

# shellcheck source=/dev/null
. "$LIB" || { echo "FAIL: could not source $LIB"; exit 1; }

# MATERIALISE THE SUBJECT ONCE, AND PREFER THE COMMITTED BLOB OVER THE WORKING TREE.
#
# MEASURED: this fixture passed solo and FAILED under the 12-way pool, and the cause was not
# this file. Sibling units in the suite create and switch branches, and the shared checkout
# came out of the run sitting on a different ref -- so a unit that reads
# `core/skills/ai-dlc/steps/retro.md` off the WORKING TREE can be handed a different revision
# of its own subject halfway through, and report a true finding about a file the branch under
# test does not contain. Green-solo/red-under-the-pool is the signature.
#
# A git blob is immutable, so resolving the subject through a sha captured ONCE closes that
# window: whatever any other unit does to the checkout afterwards, `git show` still returns the
# bytes this branch ships. The working-tree copy is the FALLBACK, not the preference, because a
# consumer runs this from an installed tree where the path is not tracked -- and there the file
# is the only truth there is. Copying rather than reading in place narrows the window either way.
SUBJ="$(mktemp -d)/retro.md"
ROOT="$(cd "$(dirname "$STEPS")" && pwd)"
SUBJ_SRC="working tree"
SHA="$(git -C "$ROOT" rev-parse HEAD 2>/dev/null || true)"
REL="$(git -C "$ROOT" ls-files --full-name "$STEPS" 2>/dev/null | head -1)"
if [ -n "$SHA" ] && [ -n "$REL" ] && git -C "$ROOT" show "${SHA}:${REL}" > "$SUBJ" 2>/dev/null && [ -s "$SUBJ" ]; then
  SUBJ_SRC="blob ${SHA} :${REL}"
else
  cp "$STEPS" "$SUBJ" || { echo "FAIL: could not materialise $STEPS"; exit 1; }
fi
STEPS="$SUBJ"

STEP_HEADING='4a. Close-Out Sweep'
ARTIFACT_RE='^#{3,6}[[:space:]]+`## Machine Audits`'

FAILURES=0
ASSERTIONS=0

ok()   { ASSERTIONS=$((ASSERTIONS + 1)); printf '  ok    %-34s %s\n' "$1" "$2"; }
bad()  { ASSERTIONS=$((ASSERTIONS + 1)); FAILURES=$((FAILURES + 1)); printf '  FAIL  %-34s %s\n' "$1" "$2"; }

# heading_line <file> -> 1-indexed line number of the artifact heading, empty if absent
heading_line() { grep -nE "$ARTIFACT_RE" "$1" | head -1 | cut -d: -f1; }

# swallowed <file> -> "yes" | "no" | "unknown"; is the artifact heading inside the step's span?
swallowed() {
  local f="$1" s e hl
  hl="$(heading_line "$f")"
  [ -n "$hl" ] || { echo unknown; return; }
  set -- $(span_of "$STEP_HEADING" < "$f")
  s="${1:-}"; e="${2:-}"
  [ -n "$s" ] && [ -n "$e" ] || { echo unknown; return; }
  if [ "$hl" -ge "$s" ] && [ "$hl" -le "$e" ]; then echo yes; else echo no; fi
}

echo "── subject: $STEPS  (source: $SUBJ_SRC)"

# --- ARM 1: the precondition, PRESENCE-shaped ------------------------------------------
# A vacuously-true property is the failure this repo names most often. If the heading or the
# step is gone, arm 2 cannot fire and its silence would read exactly like a pass.
hl="$(heading_line "$STEPS")"
if [ -n "$hl" ]; then
  ok "artifact-heading-present" "\`## Machine Audits\` heading at line $hl"
else
  bad "artifact-heading-present" "no heading matching $ARTIFACT_RE — arm 2 below cannot fire, so its silence proves nothing"
fi
set -- $(span_of "$STEP_HEADING" < "$STEPS")
S="${1:-}"; E="${2:-}"
if [ -n "$S" ] && [ -n "$E" ]; then
  ok "step-span-resolves" "span_of '$STEP_HEADING' = $S $E"
else
  bad "step-span-resolves" "span_of returned nothing for '$STEP_HEADING' — the oracle is dead, not the property satisfied"
fi

# --- ARM 2: the property itself, ABSENCE-shaped, and the mutant below is why it counts ---
verdict="$(swallowed "$STEPS")"
case "$verdict" in
  no)  ok  "artifact-not-swallowed" "the heading sits OUTSIDE $S..$E, so a shadow of '$STEP_HEADING' does not displace it" ;;
  yes) bad "artifact-not-swallowed" "the heading is INSIDE $S..$E — every consumer override shadowing '$STEP_HEADING' silently displaces the artifact's definition. Promote it to a sibling heading one level shallower." ;;
  *)   bad "artifact-not-swallowed" "could not decide (heading or span unresolvable) — a check that cannot fire reads exactly like one that passed" ;;
esac

# --- ARM 3: the MUTANT. Re-nest the heading in a COPY and require the verdict to INVERT ---
# Built as a copy and guarded with cmp -s, so a sed that matched nothing cannot pass as a
# mutation. The mutation is anchored on the heading's own level marker, which is the single
# thing that separates the fixed shape from the broken one.
#
# IT STANDS DOWN WHEN ARM 2 HAS ALREADY FIRED, AND THAT IS THE RULE RATHER THAN A CONVENIENCE.
# On a tree where the heading is still a child there is nothing to re-nest, so the sed matches
# nothing and this arm reports a second failure for the ONE defect arm 2 just named. Two
# failures for one cause is the entangled-assertion shape; measured here on the pre-fix tree,
# it read 2 of 5 wrong where 1 of 4 is the truth. Arm 2 OWNS the broken case -- and its firing
# on the real subject is itself proof that it discriminates, which is all the mutant was for.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
MUT="$TMP/retro-renested.md"
if [ "$verdict" != no ]; then
  printf '  --    %-34s stood down: arm 2 fired on the real subject, which is the discrimination this arm exists to prove\n' "mutant-killed"
else
sed -E "s|^###([[:space:]]+\`## Machine Audits\`)|####\1|" "$STEPS" > "$MUT"
if cmp -s "$STEPS" "$MUT"; then
  bad "mutant-applied" "re-nesting sed matched nothing — the mutant is a copy of the original and would score a kill it did not earn"
else
  ok "mutant-applied" "heading demoted to a child in the copy"
  mv="$(swallowed "$MUT")"
  if [ "$mv" = yes ]; then
    set -- $(span_of "$STEP_HEADING" < "$MUT")
    ok "mutant-killed" "re-nested copy reports SWALLOWED (span ${1:-?} ${2:-?}) — arm 2 discriminates"
  else
    bad "mutant-killed" "re-nested copy reports '$mv', want 'yes' — arm 2 cannot tell the broken shape from the fixed one"
  fi
fi
fi

# --- ARM 4: unmutated control, with a POSITIVE conjunct --------------------------------
# rc=0-and-nothing-reported is what a copy that died also looks like. So the control asserts a
# specific value is THERE, not merely that nothing went wrong.
CTL="$TMP/retro-control.md"
cp "$STEPS" "$CTL"
cv="$(swallowed "$CTL")"
chl="$(heading_line "$CTL")"
if [ "$cv" = "$verdict" ] && [ -n "$chl" ] && [ "$chl" = "$hl" ]; then
  ok "unmutated-control" "byte-identical copy reproduces verdict '$cv' and heading line $chl"
else
  bad "unmutated-control" "copy gave verdict '$cv' at line '${chl:-<none>}', want '$verdict' at line '${hl:-<none>}' — a copy that cannot run scores as a kill"
fi

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct."
exit 0
