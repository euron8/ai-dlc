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
# The REQUIRED inputs of inputs.decl: lib.sh was sourced above and retro.md was materialised into $SUBJ.
echo "HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/lib.sh"
echo "HERMETIC-CONSUMED core/skills/ai-dlc/steps/retro.md"

STEP_HEADING='4a. Close-Out Sweep'
ARTIFACT_RE='^#{3,6}[[:space:]]+`## Machine Audits`'

# shellcheck source=/dev/null
. "$DIR/../lib/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }
# okm/badm: the two-column assertion line (name, detail) through report.sh's ok/bad.
okm()  { local m; printf -v m '%-34s %s' "$1" "${2-}"; ok "$m"; }
badm() { local m; printf -v m '%-34s %s' "$1" "${2-}"; bad "$m"; }

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
  okm "artifact-heading-present" "\`## Machine Audits\` heading at line $hl"
else
  badm "artifact-heading-present" "no heading matching $ARTIFACT_RE — arm 2 below cannot fire, so its silence proves nothing"
fi
set -- $(span_of "$STEP_HEADING" < "$STEPS")
S="${1:-}"; E="${2:-}"
if [ -n "$S" ] && [ -n "$E" ]; then
  okm "step-span-resolves" "span_of '$STEP_HEADING' = $S $E"
else
  badm "step-span-resolves" "span_of returned nothing for '$STEP_HEADING' — the oracle is dead, not the property satisfied"
fi

# --- ARM 2: the property itself, ABSENCE-shaped ---
verdict="$(swallowed "$STEPS")"
case "$verdict" in
  no)  okm "artifact-not-swallowed" "the heading sits OUTSIDE $S..$E, so a shadow of '$STEP_HEADING' does not displace it" ;;
  yes) badm "artifact-not-swallowed" "the heading is INSIDE $S..$E — every consumer override shadowing '$STEP_HEADING' silently displaces the artifact's definition. Promote it to a sibling heading one level shallower." ;;
  *)   badm "artifact-not-swallowed" "could not decide (heading or span unresolvable) — a check that cannot fire reads exactly like one that passed" ;;
esac

# --- THE SPRINT-SHIP SLICER. Each is a pure helper of its arguments and of $STEPS-shaped files; arms 5-9 below call them.
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
# (SS_START, SS_BAND_MAX and the ss_* slicer helpers are declared once, above.)

# Counted through `printf '%s\n' "$raw"`. A direct `ss_span | wc -l` answers ONE HIGHER, because the pipe
# carries the final newline the command substitution strips.
ss_raw="$(ss_span "$STEPS")"
ss_lines="$(printf '%s\n' "$ss_raw" | wc -l | tr -d ' ')"
ss_txt="$(ss_norm "$ss_raw")"

# --- ARM 5: the span resolves and is IN BAND -------------------------------------------
if [ "$ss_lines" -gt 0 ] && [ "$ss_lines" -le "$SS_BAND_MAX" ]; then
  okm "ss-span-band" "'$SS_START' span is $ss_lines lines (band 1..$SS_BAND_MAX)"
else
  badm "ss-span-band" "span is $ss_lines lines, outside 1..$SS_BAND_MAX — the range ran past its terminator, and every content assertion below it is satisfied by the rest of the file rather than by this section"
fi

# --- ARM 6: the CONTROL, run against the same extraction in the same invocation ---------
# Absence here is a RESTRUCTURE, not a live defect: the counters have been renamed or the
# section moved, and arms 7-9 are then reading text that is not the subject. It is reported
# separately from the subject for exactly that reason.
ss_ctl="$(ss_cF 'consecutive-no-regression' "$ss_txt")"
ss_ctl2="$(ss_cF 'dual-counter: consecutive-deploy-clean:' "$ss_txt")"
if [ "$ss_ctl" -gt 0 ] && [ "$ss_ctl2" -gt 0 ]; then
  okm "ss-control" "the span still names both counters and the template line ($ss_ctl/$ss_ctl2) — the extraction ran"
else
  badm "ss-control" "the span names consecutive-no-regression $ss_ctl time(s) and the dual-counter template $ss_ctl2 time(s); at zero the section has been restructured and the arms below assert nothing about it"
fi

# --- ARM 7: the DEFECT is gone, read through any wrap ----------------------------------
ss_def="$(ss_cF 'EITHER counter reaches 5/5' "$ss_txt")"
if [ "$ss_def" -eq 0 ]; then
  okm "ss-disjunction-gone" "the bare 'EITHER counter reaches 5/5' does not appear in the normalised span"
else
  badm "ss-disjunction-gone" "the span still declares a sprint ship-quality when EITHER counter reaches 5/5 — a smoke FAIL carried across a sprint boundary pins consecutive-deploy-clean at 0 forever while the loose counter climbs, and the sprint is declared ship-quality with the FAIL live"
fi

# --- ARM 8: the CONJUNCTION REGRESSION is convicted by name ----------------------------
ss_conj="$(ss_cE '(BOTH counters reach|both counters reach|only when BOTH)' "$ss_txt")"
if [ "$ss_conj" -eq 0 ]; then
  okm "ss-not-a-conjunction" "the span does not require BOTH counters at 5/5"
else
  badm "ss-not-a-conjunction" "the span requires BOTH counters to reach 5/5. That is not a stricter spelling of the fix, it is a wedge: the reference consumer ran an essentially unbroken sequence of sprints at consecutive-deploy-clean 0/5 on a pre-existing FAIL it could not fix, and a conjunction blocks every one of their ship-quality declarations. The required shape is a QUALIFIED disjunction."
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
  okm "ss-qualified" "the strict counter declares ship-quality alone, the loose one only conditionally, and the condition is a recorded carry-over"
else
  badm "ss-qualified" "the span does not carry the qualified disjunction (strict-alone=$ss_strict loose-conditional=$ss_loose carry-over-record=$ss_carry, each wanted >0) — without all three the two counters carry equal authority again"
fi

echo
report_end artifact-section-heading-level
