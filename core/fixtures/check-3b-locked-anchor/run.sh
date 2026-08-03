#!/usr/bin/env bash
# Exercise validate-locked-anchor.sh against the check-3b fixture set.
# Exit 0 iff:
#   - bad-story.md FAILS            (mis-anchor / summarized propagation)
#   - good-story.md PASSES          (honest verbatim full-text claim)
#   - uncheckable-story.md FAILS    (bullets, no full_text_source AND no requires_context)
#   - requires-context-story.md PASSES (honest cite-by-reference; guard must NOT over-fire)
#   - the MUTATION control holds    (neuter the uncheckable guard -> uncheckable-story
#                                    goes green, proving the guard is what fails it)
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"
# Locate the validator: installed consumer path first, then upstream core path.
VALIDATOR=""
for cand in \
  "$DIR/../../scripts/validate-locked-anchor.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-locked-anchor.sh" \
  "$DIR/../../core/scripts/validate-locked-anchor.sh"; do
  [ -f "$cand" ] && VALIDATOR="$cand" && break
done
if [ -z "$VALIDATOR" ]; then
  echo "run.sh: could not locate validate-locked-anchor.sh" >&2
  exit 2
fi

rc=0

if "$VALIDATOR" "$DIR/bad-story.md" >/dev/null 2>&1; then
  echo "FAIL: bad-story.md should have been rejected but passed" >&2
  rc=1
else
  echo "ok: bad-story.md rejected"
fi

if "$VALIDATOR" "$DIR/good-story.md" >/dev/null 2>&1; then
  echo "ok: good-story.md accepted"
else
  echo "FAIL: good-story.md should have passed but was rejected" >&2
  rc=1
fi

if "$VALIDATOR" "$DIR/uncheckable-story.md" >/dev/null 2>&1; then
  echo "FAIL: uncheckable-story.md should have been rejected but passed" >&2
  rc=1
else
  echo "ok: uncheckable-story.md rejected"
fi

if "$VALIDATOR" "$DIR/requires-context-story.md" >/dev/null 2>&1; then
  echo "ok: requires-context-story.md accepted (honest cite-by-reference not red)"
else
  echo "FAIL: requires-context-story.md should have passed but was rejected" >&2
  rc=1
fi

# --- MUTATION control: prove the uncheckable guard is what fails uncheckable-story ---
# Assertions above show uncheckable-story FAILS, but a FAIL is only evidence for THIS
# guard if removing the guard makes it PASS. Neuter the guard condition in a copy and
# require uncheckable-story to go green; if it still fails, some OTHER rejection is
# doing the work and the assertion above proves nothing.
WORK="$(mktemp -d 2>/dev/null)" || { echo "run.sh: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
MUTANT="$WORK/mutant.sh"
sed 's/if bullets and not any(REQUIRES_CTX_RE.match(ln) for ln in lines):/if False:  # MUTANT: uncheckable guard disabled/' \
  "$VALIDATOR" > "$MUTANT" || { echo "run.sh: sed failed" >&2; exit 2; }
if cmp -s "$VALIDATOR" "$MUTANT"; then
  echo "FIXTURE ERROR: mutation matched nothing — the uncheckable guard was renamed." >&2
  echo "  update the sed pattern in run.sh to match the real guard condition." >&2
  rc=2
elif bash "$MUTANT" "$DIR/uncheckable-story.md" >/dev/null 2>&1; then
  echo "ok: MUTATION — neutering the guard lets uncheckable-story.md pass (guard fires)"
else
  echo "FAIL: MUTATION — uncheckable-story.md still rejected without the guard; the FAIL above proves nothing" >&2
  rc=1
fi

# --- the SENTINEL SPELLING matrix -------------------------------------------------
# `steps/discovery.md` templates ONE closer and assumes ONE block per artifact. Real
# briefs accumulate a block per sprint, so consumers invented per-block discriminators
# — a need the template never met. SEVEN spellings were measured in one reference
# consumer, and this script recognised ONE of them.
#
# What made that a defect rather than untidiness: a block whose closer was not
# recognised extracted as NOTHING, and zero blocks fell through to the PASS line with
# `claims_checked = 0`. Same fabricated requirement, two spellings, measured:
#   <!-- END S1 LOCKED requirements -->   PASS (0 block(s), 0 claim(s))  exit 0
#   <!-- END LOCKED_REQUIREMENTS -->      FAIL — not byte-present         exit 1
# One word in a comment disarmed a `hard_block: true` check.
#
# So each spelling is asserted TWICE: it must fail a FABRICATED requirement and pass an
# HONEST one. Only the pair proves the block was parsed — "fails everything" and
# "parses correctly" are different claims, and a grammar that matched nothing would
# satisfy the first alone.
SP="$WORK/spell"; mkdir -p "$SP"
printf '# brief\n\n<!-- LOCKED_REQUIREMENTS -->\n- LR-S1-1 pool fee is 3000\n<!-- END LOCKED_REQUIREMENTS -->\n' \
  > "$SP/product-brief.md"

spell_case() { # spell_case <label> <opener> <closer> <bullet> <expected-rc>
  printf '# story\n\n%s\nfull_text_source: product-brief.md:LR-S1-1\n- %s\n%s\n' \
    "$2" "$4" "$3" > "$SP/s.md"
  bash "$VALIDATOR" "$SP/s.md" >/dev/null 2>&1
  local got=$?
  if [ "$got" -eq "$5" ]; then
    echo "ok: spelling '$1' — $6"
  else
    echo "FAIL: spelling '$1' — $6: expected rc=$5, got rc=$got" >&2
    rc=1
  fi
}

# Every spelling measured in the field, plus core's own template form.
while IFS='|' read -r label opener closer; do
  [ -n "$label" ] || continue
  spell_case "$label" "$opener" "$closer" "LR-S1-1 pool fee is 500 FABRICATED" 1 "a fabricated requirement is REJECTED"
  spell_case "$label" "$opener" "$closer" "LR-S1-1 pool fee is 3000"           0 "an honest requirement is ACCEPTED"
done <<'SPELLINGS'
core template|<!-- LOCKED_REQUIREMENTS — DO NOT MODIFY DURING VALIDATION -->|<!-- END LOCKED_REQUIREMENTS -->
bare|<!-- LOCKED_REQUIREMENTS -->|<!-- END LOCKED_REQUIREMENTS -->
sprint-suffixed closer|<!-- LOCKED_REQUIREMENTS -->|<!-- END S1 LOCKED requirements -->
closer with trailing note|<!-- LOCKED_REQUIREMENTS -->|<!-- END LOCKED_REQUIREMENTS S1 note -->
sprint-infixed closer|<!-- LOCKED_REQUIREMENTS -->|<!-- END S1 LOCKED_REQUIREMENTS -->
BEGIN/END pair|<!-- LOCKED_REQUIREMENTS_BEGIN -->|<!-- LOCKED_REQUIREMENTS_END -->
whole block in one comment|<!-- LOCKED_REQUIREMENTS|END LOCKED_REQUIREMENTS -->
SPELLINGS

# --- the UNCLOSED-BLOCK guard ------------------------------------------------------
# An opener with no closer must FAIL, not pass with zero blocks. Three real story files
# in the reference consumer were in exactly this state and had been passing.
printf '# story\n\n<!-- LOCKED_REQUIREMENTS -->\nfull_text_source: product-brief.md:LR-S1-1\n- LR-S1-1 pool fee is 500 FABRICATED\n' \
  > "$SP/unclosed.md"
if bash "$VALIDATOR" "$SP/unclosed.md" >/dev/null 2>&1; then
  echo "FAIL: an UNCLOSED LOCKED block passed — that is the zero-blocks road to PASS this guard exists to close" >&2
  rc=1
else
  echo "ok: an UNCLOSED LOCKED block is REJECTED (not passed with 0 blocks verified)"
fi
# Over-fire control: a story with NO LOCKED block at all is not this guard's business.
printf '# story\n\nNo locked block here at all.\n' > "$SP/noblock.md"
if bash "$VALIDATOR" "$SP/noblock.md" >/dev/null 2>&1; then
  echo "ok: OVER-FIRE CONTROL: a story with no LOCKED block is not failed by the unclosed guard"
else
  echo "FAIL: OVER-FIRE — a story with no LOCKED block was rejected" >&2
  rc=1
fi

# --- MUTATION: the widened grammar is what catches the non-core spellings ----------
# BOTH LAYERS REVERTED, because the fix is layered and a partial revert proves the layer
# left in place. Narrowing CLOSE_RE alone does not reproduce the shipped defect — the
# unclosed-block guard then catches what the grammar no longer sees, and the mutant
# comes out RED for the wrong reason. The shipped defect needed the narrow grammar AND
# no guard, so the mutant removes both. Then the sprint-suffixed case goes GREEN on a
# FABRICATED requirement: the original bug, reproduced on demand.
MUT2="$WORK/mutant-grammar.sh"
MUT_OLD='r"^(?:<!--[ \t]*)?(?:END[ \t]+[^\n]*LOCKED[^\n]*|LOCKED_REQUIREMENTS_END\b[^\n]*)-->[ \t]*$")' \
MUT_NEW='r"^<!--[ \t]*END LOCKED_REQUIREMENTS[ \t]*-->[ \t]*$")' \
python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
  "$VALIDATOR" "$MUT2"
MUT_OLD='if dangling:' MUT_NEW='if False:  # MUTANT: unclosed-block guard disabled' \
python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[1],"w").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
  "$MUT2"
if cmp -s "$VALIDATOR" "$MUT2"; then
  echo "FIXTURE ERROR: the CLOSE_RE mutation matched nothing — the spelling matrix above proves nothing" >&2
  rc=2
elif ! grep -q 'MUTANT: unclosed-block guard disabled' "$MUT2"; then
  echo "FIXTURE ERROR: only ONE of the two layers was reverted — the mutant would prove the layer left in place" >&2
  rc=2
else
  printf '# story\n\n<!-- LOCKED_REQUIREMENTS -->\nfull_text_source: product-brief.md:LR-S1-1\n- LR-S1-1 pool fee is 500 FABRICATED\n<!-- END S1 LOCKED requirements -->\n' \
    > "$SP/s.md"
  if bash "$MUT2" "$SP/s.md" >/dev/null 2>&1; then
    echo "ok: MUTATION — with core's single closer spelling, a FABRICATED requirement passes (the widening is what catches it)"
  else
    echo "FAIL: MUTATION — the narrowed grammar still caught it; the spelling matrix proves nothing" >&2
    rc=1
  fi
  # Pairing: the mutant must still catch the CORE spelling. A mutant that reds or greens
  # everything tests nothing.
  printf '# story\n\n<!-- LOCKED_REQUIREMENTS -->\nfull_text_source: product-brief.md:LR-S1-1\n- LR-S1-1 pool fee is 500 FABRICATED\n<!-- END LOCKED_REQUIREMENTS -->\n' \
    > "$SP/s.md"
  if bash "$MUT2" "$SP/s.md" >/dev/null 2>&1; then
    echo "FAIL: MUTATION PAIRING — the narrowed grammar stopped catching core's OWN spelling too; the mutant is too broad to attribute" >&2
    rc=1
  else
    echo "ok: MUTATION PAIRING — the narrowed grammar still catches core's own spelling (the two assertions are not entangled)"
  fi
fi

# Unmutated control from the same directory.
MC="$WORK/control-unmutated.sh"; cp "$VALIDATOR" "$MC"
if bash "$MC" "$DIR/good-story.md" >/dev/null 2>&1; then
  echo "ok: CONTROL: an UNMUTATED copy still accepts good-story.md (the mutants died of their edits)"
else
  echo "FAIL: CONTROL: the unmutated copy rejected good-story.md — every mutant verdict is unattributable" >&2
  rc=1
fi

[ "$rc" -eq 0 ] && echo "check-3b fixture: PASS"
exit "$rc"
