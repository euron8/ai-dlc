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

# =======================================================================================
# ARMS 5-9: THE SPRINT-SHIP DISJUNCTION. Same file, same materialised blob, same `$STEPS`.
#
# THE DEFECT. `### Sprint-Ship Verification` defines two counters and then declared a
# sprint ship-quality when EITHER reached 5/5. `consecutive-deploy-clean` resets on ANY
# smoke FAIL "regardless of whether the FAIL is new or pre-existing"; a FAIL carried across
# a sprint boundary pins it at 0 forever while `consecutive-no-regression` climbs to 5/5,
# and the disjunction then declares ship-quality with the FAIL live. The strict counter
# could not decide anything the loose one did not already decide.
#
# THE FIX IS A QUALIFIED DISJUNCTION AND A BARE CONJUNCTION IS A REGRESSION. Measured
# read-only over the reference consumer's `docs/retro/`: 105 dual-counter readings, 4 in
# the exact wedge state (deploy-clean=0 AND no-regression>=5), and 32 readings at
# deploy-clean>=5 as the same-invocation control that the strict counter IS reachable. So
# the defect is live — and requiring BOTH counters would have blocked that consumer's
# ship-quality declaration across an essentially unbroken run of `deploy-clean: 0/5`
# sprints, on a pre-existing FAIL it could not fix. That is `mechanism-design.md`'s "never
# ship a check that wedges live work", and arm 8 convicts the conjunction by name rather
# than letting it read as an acceptable second spelling.
#
# WHY THE ANCHOR IS READ OFF WHITESPACE-NORMALISED TEXT. The disjunction is a WRAP-SPANNING
# string — it sat on one line only by accident of the current wrap. A literal line-keyed
# `grep -qF` scores a REFLOW-ONLY copy, defect word for word intact, as CLOSED while the
# control still reads 1: a control agreeing with the verdict. Normalising first reads the
# defect through any wrap.
#
# WHY THE SPAN LENGTH IS ASSERTED. `awk '/start/,/end/'` runs to EOF when either boundary
# moves, and a span of the whole file trivially satisfies every content assertion in it.
# Derived with THIS slicer on the subject: the span is 30 lines and the file is 1336, so a
# runaway reads 496. The band refuses rather than scoring such a tree either way.
SS_START='^### Sprint-Ship Verification'
SS_BAND_MAX=60

# grep -c prints its zero AND exits 1. Capture first, default on failure.
ss_cF() { local n; n="$(grep -cF -- "$1" <<<"$2")" || n=0; printf '%s' "$n"; }
ss_cE() { local n; n="$(grep -cE -- "$1" <<<"$2")" || n=0; printf '%s' "$n"; }

# The span: from the heading to the NEXT heading at `###` or shallower. Keying on heading
# LEVEL rather than on the literal `### 5. Human Commentary` survives an ordinary rename of
# the neighbour, which is not this work; the band below is what speaks when it does not.
ss_span() { awk '/^### Sprint-Ship Verification/{f=1} f&&/^#{1,3} /&&!/^### Sprint-Ship Verification/{exit} f' "$1"; }
ss_norm() { printf '%s ' $1; }

# Counted through the same `printf '%s\n' "$raw"` the mutant scorer uses. A direct
# `ss_span | wc -l` answers ONE HIGHER, because the pipe carries the final newline the
# command substitution strips — and the unmutated control caught exactly that, which is
# what it is for: two readings of one span that disagree by a constant make every band
# comparison below approximate.
ss_raw="$(ss_span "$STEPS")"
ss_lines="$(printf '%s\n' "$ss_raw" | wc -l | tr -d ' ')"
ss_txt="$(ss_norm "$ss_raw")"

# --- ARM 5: the span resolves and is IN BAND -------------------------------------------
if [ "$ss_lines" -gt 0 ] && [ "$ss_lines" -le "$SS_BAND_MAX" ]; then
  ok "ss-span-band" "'$SS_START' span is $ss_lines lines (band 1..$SS_BAND_MAX)"
else
  bad "ss-span-band" "span is $ss_lines lines, outside 1..$SS_BAND_MAX — the range ran past its terminator, and every content assertion below it is satisfied by the rest of the file rather than by this section"
fi

# --- ARM 6: the CONTROL, run against the same extraction in the same invocation ---------
# Absence here is a RESTRUCTURE, not a live defect: the counters have been renamed or the
# section moved, and arms 7-9 are then reading text that is not the subject. It is reported
# separately from the subject for exactly that reason.
ss_ctl="$(ss_cF 'consecutive-no-regression' "$ss_txt")"
ss_ctl2="$(ss_cF 'dual-counter: consecutive-deploy-clean:' "$ss_txt")"
if [ "$ss_ctl" -gt 0 ] && [ "$ss_ctl2" -gt 0 ]; then
  ok "ss-control" "the span still names both counters and the template line ($ss_ctl/$ss_ctl2) — the extraction ran"
else
  bad "ss-control" "the span names consecutive-no-regression $ss_ctl time(s) and the dual-counter template $ss_ctl2 time(s); at zero the section has been restructured and the arms below assert nothing about it"
fi

# --- ARM 7: the DEFECT is gone, read through any wrap ----------------------------------
ss_def="$(ss_cF 'EITHER counter reaches 5/5' "$ss_txt")"
if [ "$ss_def" -eq 0 ]; then
  ok "ss-disjunction-gone" "the bare 'EITHER counter reaches 5/5' does not appear in the normalised span"
else
  bad "ss-disjunction-gone" "the span still declares a sprint ship-quality when EITHER counter reaches 5/5 — a smoke FAIL carried across a sprint boundary pins consecutive-deploy-clean at 0 forever while the loose counter climbs, and the sprint is declared ship-quality with the FAIL live"
fi

# --- ARM 8: the CONJUNCTION REGRESSION is convicted by name ----------------------------
ss_conj="$(ss_cE '(BOTH counters reach|both counters reach|only when BOTH)' "$ss_txt")"
if [ "$ss_conj" -eq 0 ]; then
  ok "ss-not-a-conjunction" "the span does not require BOTH counters at 5/5"
else
  bad "ss-not-a-conjunction" "the span requires BOTH counters to reach 5/5. That is not a stricter spelling of the fix, it is a wedge: the reference consumer ran an essentially unbroken sequence of sprints at consecutive-deploy-clean 0/5 on a pre-existing FAIL it could not fix, and a conjunction blocks every one of their ship-quality declarations. The required shape is a QUALIFIED disjunction."
fi

# --- ARM 9: the QUALIFICATION is present, as three separate properties -----------------
# Three, not one, because a single anchor on any one of them is satisfied by prose that
# drops the other two — and the carry-over RECORD is the whole of what makes the loose
# counter safe to rely on. A competent second spelling of the fix satisfies all three; the
# conjunction and the pre-fix disjunction satisfy none.
ss_strict="$(ss_cE 'consecutive-deploy-clean`?[^.]*(on its own|alone)' "$ss_txt")"
ss_loose="$(ss_cE 'consecutive-no-regression`?[^.]*(only where|only when|sufficient only)' "$ss_txt")"
ss_carry="$(ss_cE 'carry-over|carried over' "$ss_txt")"
if [ "$ss_strict" -gt 0 ] && [ "$ss_loose" -gt 0 ] && [ "$ss_carry" -gt 0 ]; then
  ok "ss-qualified" "the strict counter declares ship-quality alone, the loose one only conditionally, and the condition is a recorded carry-over"
else
  bad "ss-qualified" "the span does not carry the qualified disjunction (strict-alone=$ss_strict loose-conditional=$ss_loose carry-over-record=$ss_carry, each wanted >0) — without all three the two counters carry equal authority again"
fi

# --- ARMS 10-13: THE MUTANTS. Every arm above is ABSENCE- or presence-of-prose-shaped,
# which is what a tree that never ran also reports. Each mutant is a COPY, guarded by
# `cmp -s`, and built by rewriting the whole paragraph rather than by a `sed` whose `&`
# would re-insert the match. Each names the ONE arm it must move.
ss_mut() { # ss_mut <name> <file> ; prints "<lines> <ctl> <def> <conj> <qualified>"
  local f="$2" raw txt ln ctl def conj s l c q
  raw="$(ss_span "$f")"; ln="$(printf '%s\n' "$raw" | wc -l | tr -d ' ')"
  txt="$(ss_norm "$raw")"
  ctl="$(ss_cF 'consecutive-no-regression' "$txt")"
  def="$(ss_cF 'EITHER counter reaches 5/5' "$txt")"
  conj="$(ss_cE '(BOTH counters reach|both counters reach|only when BOTH)' "$txt")"
  s="$(ss_cE 'consecutive-deploy-clean`?[^.]*(on its own|alone)' "$txt")"
  l="$(ss_cE 'consecutive-no-regression`?[^.]*(only where|only when|sufficient only)' "$txt")"
  c="$(ss_cE 'carry-over|carried over' "$txt")"
  q=0; [ "$s" -gt 0 ] && [ "$l" -gt 0 ] && [ "$c" -gt 0 ] && q=1
  printf '%s %s %s %s %s' "$ln" "$ctl" "$def" "$conj" "$q"
}
# M1 AND M2 STAND DOWN WHEN ARM 7 HAS ALREADY FIRED, AND THAT IS THE RULE RATHER THAN A
# CONVENIENCE. Both rewrite the FIXED paragraph, so on a tree still carrying the pre-fix
# disjunction their anchors match nothing and each reports DID NOT APPLY — two extra
# failures for the ONE defect arm 7 just named, which is the entangled-assertion shape.
# Arm 7 OWNS the unfixed tree, and its firing there is itself the proof that it
# discriminates, which is all these mutants were for. M3 does NOT stand down: its anchor is
# the section heading, which exists either way, so it stays armed on every tree.
ss_prefix=0
[ "$ss_def" -gt 0 ] && ss_prefix=1

# M1 — REFLOW. The defect restored WORD FOR WORD and rewrapped at 66 columns, inside this
# span's own measured prose band. A line-keyed literal anchor scores this CLOSED.
SS_M1="$TMP/ss-reflow.md"
if [ "$ss_prefix" -eq 1 ]; then
  printf '  --    %-34s stood down: arm 7 fired on the real subject, so the fixed paragraph this mutant rewrites is not present to rewrite\n' "ss-m1"
else
awk '
  /^Each counter is tracked against its own 5\/5 target, and the two do not$/ { skip=1 }
  skip && /^reads\.$/ {
    print "Each counter is tracked against its own 5/5 target and both are"
    print "reported. A sprint is ship-quality when EITHER counter reaches"
    print "5/5."
    skip=0; next
  }
  skip { next }
  { print }
' "$STEPS" > "$SS_M1"
if cmp -s "$STEPS" "$SS_M1"; then
  bad "ss-m1-applied" "the reflow rewrite produced a byte-identical copy — DID NOT APPLY, so the kill below would be scored against the original"
else
  ok "ss-m1-applied" "reflow copy differs from the subject"
  set -- $(ss_mut m1 "$SS_M1")
  if [ "$3" -gt 0 ] && [ "$2" -gt 0 ] && [ "$1" -le "$SS_BAND_MAX" ]; then
    ok "ss-m1-killed" "the reflowed defect is still read (defect=$3) with the control alive (ctl=$2) — arm 7 sees through a wrap"
  else
    bad "ss-m1-killed" "reflow copy scored lines=$1 ctl=$2 defect=$3; arm 7 has gone blind to a defect that survived a rewrap word for word, which is exactly the shape where the control passes and the subject arm does not"
  fi
fi
fi

# M2 — CONJUNCTION. The regression. Arm 8 must own it; arm 7 must NOT also fire, or the two
# assertions are entangled and one of them is vacuous.
SS_M2="$TMP/ss-conjunction.md"
if [ "$ss_prefix" -eq 1 ]; then
  printf '  --    %-34s stood down: arm 7 fired on the real subject, so the fixed paragraph this mutant rewrites is not present to rewrite\n' "ss-m2"
else
awk '
  /^Each counter is tracked against its own 5\/5 target, and the two do not$/ { skip=1 }
  skip && /^reads\.$/ {
    print "Each counter is tracked against its own 5/5 target. A sprint is"
    print "ship-quality only when BOTH counters reach 5/5."
    skip=0; next
  }
  skip { next }
  { print }
' "$STEPS" > "$SS_M2"
if cmp -s "$STEPS" "$SS_M2"; then
  bad "ss-m2-applied" "the conjunction rewrite produced a byte-identical copy — DID NOT APPLY"
else
  ok "ss-m2-applied" "conjunction copy differs from the subject"
  set -- $(ss_mut m2 "$SS_M2")
  if [ "$4" -gt 0 ] && [ "$3" -eq 0 ] && [ "$2" -gt 0 ]; then
    ok "ss-m2-killed" "the conjunction is convicted by arm 8 (conj=$4) and arm 7 correctly stays quiet (defect=$3) — one mutant, one failing assertion"
  else
    bad "ss-m2-killed" "conjunction copy scored ctl=$2 defect=$3 conj=$4; wanted conj>0 and defect=0. A conjunction that no arm convicts reads as an acceptable second spelling of the fix, and it wedges the consumer."
  fi
fi
fi

# M3 — RUNAWAY SPAN. Every heading after the section demoted below the slicer's band, so the
# range genuinely reaches EOF with the FIX INTACT. Without this world the band in arm 5 is a
# check that cannot fire, which reads exactly like one that passed.
SS_M3="$TMP/ss-runaway.md"
awk -v start="$SS_START" '
  $0 ~ start { seen=1; print; next }
  seen && /^#{1,3} / { sub(/^#/, "##"); print; next }
  { print }
' "$STEPS" > "$SS_M3"
if cmp -s "$STEPS" "$SS_M3"; then
  bad "ss-m3-applied" "the heading-demotion rewrite produced a byte-identical copy — DID NOT APPLY"
else
  ok "ss-m3-applied" "runaway copy differs from the subject"
  set -- $(ss_mut m3 "$SS_M3")
  if [ "$1" -gt "$SS_BAND_MAX" ]; then
    ok "ss-m3-killed" "the span runs to $1 lines and arm 5 refuses it — a section assertion satisfied by the rest of the file is caught rather than scored"
  else
    bad "ss-m3-killed" "runaway copy's span read $1 lines, still inside the band, so arm 5 cannot fire on a range that reached EOF and every content arm above it is being satisfied by unrelated prose"
  fi
fi

# M4 — UNMUTATED CONTROL, with a positive conjunct. A copy that cannot be read reproduces
# "nothing wrong" exactly; this demands the same five numbers come back.
SS_M4="$TMP/ss-control.md"
cp "$STEPS" "$SS_M4"
ss_base="$ss_lines $ss_ctl $ss_def $ss_conj $( [ "$ss_strict" -gt 0 ] && [ "$ss_loose" -gt 0 ] && [ "$ss_carry" -gt 0 ] && echo 1 || echo 0 )"
ss_copy="$(ss_mut m4 "$SS_M4")"
if [ "$ss_copy" = "$ss_base" ] && [ "$ss_ctl" -gt 0 ]; then
  ok "ss-unmutated-control" "byte-identical copy reproduces lines/ctl/defect/conj/qualified = $ss_copy"
else
  bad "ss-unmutated-control" "copy scored '$ss_copy', subject scored '$ss_base' — the two runs disagree, so a mutant verdict above is evidence about a reader that is not stable"
fi

echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct."
exit 0
