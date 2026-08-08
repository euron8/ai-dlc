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

# --- CWD INVARIANCE: a citation is story-relative, not caller-relative -------------
# EVERY ASSERTION ABOVE WAS CWD-DEPENDENT UNTIL v0.263.0, AND THE SUITE RUNNER'S CHOICE
# OF CWD IS WHAT HID IT. `resolve_artifact` tried `os.getcwd()/<cited>` BEFORE the story's
# own directory, and THIS DIRECTORY SHIPS A DECOY: `product-brief.md` here carries LR-1
# and LR-2, not the LR-S1-1 the matrix above cites. Both pre-push hooks run `bash
# "$d/run.sh"` from the repo root, where no `product-brief.md` exists, so the fixture was
# green for years; run it from its own directory -- which is what a human does, and what
# the reference consumer's differential harness did -- and the seven honest cases went red.
#
# The half that did not go red is the reason this block exists rather than a bug report.
# The seven FABRICATED cases stayed green from the decoy cwd, because a story is rejected
# for a dangling anchor exactly as it is rejected for fabricated text: same rc, different
# reason. Half the matrix was asserting nothing, and its output said `ok`.
#
# So the invariant is asserted directly: the SAME story gets the SAME verdict from three
# cwds, one of which is the decoy. Both polarities are run -- an honest story that stays
# accepted proves resolution reached the right brief, and a fabricated one that stays
# rejected proves the verdict came from the TEXT rather than from a failed lookup.
DECOY="$DIR"
EMPTY="$WORK/empty"; mkdir -p "$EMPTY"
printf '# story\n\n<!-- LOCKED_REQUIREMENTS -->\nfull_text_source: product-brief.md:LR-S1-1\n- LR-S1-1 pool fee is 3000\n<!-- END LOCKED_REQUIREMENTS -->\n' \
  > "$SP/cwd-honest.md"
printf '# story\n\n<!-- LOCKED_REQUIREMENTS -->\nfull_text_source: product-brief.md:LR-S1-1\n- LR-S1-1 pool fee is 500 FABRICATED\n<!-- END LOCKED_REQUIREMENTS -->\n' \
  > "$SP/cwd-fabricated.md"

# The decoy must actually be a decoy. If this directory's brief ever gains LR-S1-1 the
# assertions below still pass, having tested nothing -- so check, and fail loudly.
if [ ! -f "$DECOY/product-brief.md" ] || grep -q 'LR-S1-1' "$DECOY/product-brief.md"; then
  echo "FIXTURE ERROR: $DECOY/product-brief.md is no longer a decoy (missing, or it now carries LR-S1-1)." >&2
  echo "  the cwd-invariance assertions below cannot distinguish anything. Restore a brief without LR-S1-1." >&2
  rc=2
else
  cwd_case() { # cwd_case <validator> <label> <cwd> <story> <expected-rc> <what>
    ( cd "$3" && bash "$1" "$4" >/dev/null 2>&1 )
    local got=$?
    if [ "$got" -eq "$5" ]; then
      echo "ok: CWD INVARIANCE — $6 from cwd '$2'"
      return 0
    fi
    echo "FAIL: CWD INVARIANCE — $6 from cwd '$2': expected rc=$5, got rc=$got" >&2
    rc=1
    return 1
  }
  while IFS='|' read -r cwd_label cwd_path; do
    [ -n "$cwd_label" ] || continue
    cwd_case "$VALIDATOR" "$cwd_label" "$cwd_path" "$SP/cwd-honest.md"     0 "an honest story is ACCEPTED"
    cwd_case "$VALIDATOR" "$cwd_label" "$cwd_path" "$SP/cwd-fabricated.md" 1 "a fabricated story is REJECTED"
  done <<CWDS
decoy (this fixture dir)|$DECOY
empty|$EMPTY
story dir|$SP
CWDS

  # MUTATION: restore the shipped-until-v0.263.0 preference and require the decoy cwd to
  # go red. Without this the block above is three copies of one passing assertion.
  MUT3="$WORK/mutant-cwd-order.sh"
  MUT_OLD='        candidates.append(os.path.join(story_dir, cited))
        candidates.append(os.path.join(os.getcwd(), cited))'
  MUT_NEW='        candidates.append(os.path.join(os.getcwd(), cited))
        candidates.append(os.path.join(story_dir, cited))'
  MUT_OLD="$MUT_OLD" MUT_NEW="$MUT_NEW" python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
    "$VALIDATOR" "$MUT3"
  if cmp -s "$VALIDATOR" "$MUT3"; then
    echo "FIXTURE ERROR: the resolution-order mutation matched nothing — the cwd assertions above prove nothing." >&2
    echo "  update MUT_OLD in run.sh to match resolve_artifact's real candidate order." >&2
    rc=2
  else
    if ( cd "$DECOY" && bash "$MUT3" "$SP/cwd-honest.md" >/dev/null 2>&1 ); then
      echo "FAIL: MUTATION — cwd-first resolution still accepted the honest story from the decoy cwd; the invariance assertions prove nothing" >&2
      rc=1
    else
      echo "ok: MUTATION — cwd-first resolution reds the honest story from the decoy cwd (the ORDER is what the assertions test)"
    fi
    # Pairing: the same mutant must still accept it from a cwd with no decoy. A mutant
    # that reds everything would satisfy the assertion above while testing nothing.
    if ( cd "$EMPTY" && bash "$MUT3" "$SP/cwd-honest.md" >/dev/null 2>&1 ); then
      echo "ok: MUTATION PAIRING — the same mutant still accepts it from an empty cwd (it died of the decoy, not of the edit)"
    else
      echo "FAIL: MUTATION PAIRING — the mutant rejects the honest story from an empty cwd too; its verdict is unattributable" >&2
      rc=1
    fi
  fi
fi

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

# --- LOAD POINTERS ARE RESOLVED ----------------------------------------------------
# `requires_context:` was recognised as a PRESENCE and its target never resolved. The
# bullets under it are correctly never byte-matched — they are an abridged restatement
# by design — but the POINTER asserts one falsifiable fact, that the artifact and anchor
# are there to load, and nothing checked it. Measured on a reference consumer at the
# moment this shipped: all ten stories of the live sprint reported PASS with `0 claim(s)
# verified` because every block in that sprint cited only `requires_context:`, and
# across its 998-story corpus a nonzero claim count had NEVER ONCE occurred. 34 of 47
# pointers in that corpus named an anchor absent from the artifact they cite.
#
# The pair is the point. A dangling pointer must red AND an honest one must stay green
# (asserted above at requires-context-story.md) — a validator that failed every
# cite-by-reference block would satisfy the first alone.
if "$VALIDATOR" "$DIR/dangling-pointer-story.md" >/dev/null 2>&1; then
  echo "FAIL: dangling-pointer-story.md passed — a requires_context: anchor absent from the artifact is a load pointer to nothing" >&2
  rc=1
else
  echo "ok: dangling-pointer-story.md rejected (dangling load pointer)"
fi

MUT3="$WORK/mut-no-pointer-resolution.sh"; cp "$VALIDATOR" "$MUT3"
sed -i.bak 's|^REQUIRES_CTX_CITE_RE = re.compile(r"[^"]*")$|REQUIRES_CTX_CITE_RE = re.compile(r"^NEVER_MATCHES_ANY_LINE$")|' "$MUT3" && rm -f "$MUT3.bak"
if cmp -s "$VALIDATOR" "$MUT3"; then
  echo "FAIL: MUTATION setup — the pointer-citation regex was not mutated, so the arm below proves nothing" >&2
  rc=1
else
  if bash "$MUT3" "$DIR/dangling-pointer-story.md" >/dev/null 2>&1; then
    echo "ok: MUTATION — with pointer resolution reverted, the dangling pointer goes GREEN (resolution is what catches it)"
  else
    echo "FAIL: MUTATION — the dangling pointer still red with resolution reverted; some OTHER rejection is doing the work" >&2
    rc=1
  fi
  # Pairing: the mutant must still accept the honest pointer, so it died of ITS OWN edit.
  if bash "$MUT3" "$DIR/requires-context-story.md" >/dev/null 2>&1; then
    echo "ok: MUTATION PAIRING — the same mutant still accepts an honest pointer (it fails only its own assertion)"
  else
    echo "FAIL: MUTATION PAIRING — the mutant reds the honest pointer too; the two assertions are entangled" >&2
    rc=1
  fi
fi

# --- THE BYTE-MATCH IS SCOPED TO THE CITED ANCHOR ----------------------------------
# The anchor was consumed by the existence check and then discarded, so a requirement
# bullet satisfied the byte-match by appearing ANYWHERE in the source of record. That
# proves co-presence, not anchoring: a citation "verified" because the brief happens to
# contain the words in a section the citation does not name.
#
# The discriminating pair is one story text against two citations. Citing the anchor the
# text actually lives under must PASS; citing the OTHER section's anchor must FAIL. Only
# the pair separates "the anchor is wrong" from "the text is absent" — the shipped defect
# passed both, and a byte-match that rejected everything would pass the FAIL half alone.
AW="$WORK/anchorwin"; mkdir -p "$AW"
printf '# Brief\n\n## Section A\n\n- LR-A1: alpha requirement text, verbatim.\n\n## Section B\n\n- LR-B1: beta requirement text, verbatim.\n' \
  > "$AW/product-brief.md"
printf '# story\n\n<!-- LOCKED_REQUIREMENTS -->\nfull_text_source: product-brief.md:LR-B1\n- LR-B1: beta requirement text, verbatim.\n<!-- END LOCKED_REQUIREMENTS -->\n' \
  > "$AW/on-anchor.md"
printf '# story\n\n<!-- LOCKED_REQUIREMENTS -->\nfull_text_source: product-brief.md:LR-A1\n- LR-B1: beta requirement text, verbatim.\n<!-- END LOCKED_REQUIREMENTS -->\n' \
  > "$AW/off-anchor.md"

if bash "$VALIDATOR" "$AW/on-anchor.md" >/dev/null 2>&1; then
  echo "ok: on-anchor story accepted (the bullet is inside the section it cites)"
else
  echo "FAIL: on-anchor story rejected — the anchor window is too narrow to hold its own section" >&2
  rc=1
fi
if bash "$VALIDATOR" "$AW/off-anchor.md" >/dev/null 2>&1; then
  echo "FAIL: off-anchor story passed — the bullet lives under Section B and the block cites Section A" >&2
  rc=1
else
  echo "ok: off-anchor story rejected (byte-match is scoped to the cited anchor, not the whole file)"
fi

MUT4="$WORK/mut-whole-file-bytematch.sh"; cp "$VALIDATOR" "$MUT4"
sed -i.bak 's/source_norm = collapse_ws("\\n".join(windows))/source_norm = collapse_ws(source_text)/' "$MUT4" && rm -f "$MUT4.bak"
if cmp -s "$VALIDATOR" "$MUT4"; then
  echo "FAIL: MUTATION setup — the byte-match window was not mutated, so the arm below proves nothing" >&2
  rc=1
else
  if bash "$MUT4" "$AW/off-anchor.md" >/dev/null 2>&1; then
    echo "ok: MUTATION — with the byte-match reverted to whole-file, the off-anchor story goes GREEN (the shipped defect, on demand)"
  else
    echo "FAIL: MUTATION — the off-anchor story still red against a whole-file match; the scoping is not what catches it" >&2
    rc=1
  fi
  if bash "$MUT4" "$AW/on-anchor.md" >/dev/null 2>&1; then
    echo "ok: MUTATION PAIRING — the same mutant still accepts the on-anchor story (it fails only its own assertion)"
  else
    echo "FAIL: MUTATION PAIRING — the whole-file mutant reds the honest story too; the assertions are entangled" >&2
    rc=1
  fi
fi

# --- THE TWO ROADS TO EXIT 0 PRINT DIFFERENT LINES ---------------------------------
# "Every claim verified" and "there was nothing to check" still share exit code 0, and
# they should: a block that claims nothing has nothing to substantiate. What was wrong
# is that they also shared one REPORT LINE. The assertion is on the STRING.
NV_OUT="$("$VALIDATOR" "$DIR/nothing-verified-story.md" 2>&1)"
GD_OUT="$("$VALIDATOR" "$DIR/good-story.md" 2>&1)"
case "$NV_OUT" in
  *"NOTHING VERIFIED"*) echo "ok: a zero-verification story reports PASS — NOTHING VERIFIED" ;;
  *) echo "FAIL: a zero-verification story reports the same line as a verified one: $NV_OUT" >&2; rc=1 ;;
esac
case "$GD_OUT" in
  *"NOTHING VERIFIED"*) echo "FAIL: a VERIFIED story reported NOTHING VERIFIED — the two roads are swapped: $GD_OUT" >&2; rc=1 ;;
  *) echo "ok: OVER-FIRE CONTROL: a verified story does NOT report NOTHING VERIFIED" ;;
esac

MUT5="$WORK/mut-one-pass-line.sh"; cp "$VALIDATOR" "$MUT5"
sed -i.bak 's/^if claims_checked == 0 and pointers_checked == 0:$/if False:/' "$MUT5" && rm -f "$MUT5.bak"
if cmp -s "$VALIDATOR" "$MUT5"; then
  echo "FAIL: MUTATION setup — the two-road branch was not mutated, so the arm below proves nothing" >&2
  rc=1
else
  if bash "$MUT5" "$DIR/nothing-verified-story.md" 2>&1 | grep -q "NOTHING VERIFIED"; then
    echo "FAIL: MUTATION — the collapsed branch still distinguishes the two roads; the branch is not what does it" >&2
    rc=1
  else
    echo "ok: MUTATION — with the branch collapsed, a zero-verification story spells like a verified one (the defect, on demand)"
  fi
fi

# --- THE SOURCE OF RECORD IS TWO NAMES, AND THE SECOND IS ON ITS WAY OUT -----------
# discovery.md §4a used to append each sprint's LOCKED block to the durable brief and
# now writes it to `s<N>/locked-requirements.md`. Both names are accepted: refusing the
# legacy one would fail every story written before the move -- 31 of 62 anchored
# citations on the reference consumer, all resolvable, none defective -- which is this
# check reporting a migration as a fabrication.
#
# THREE ARMS, BECAUSE ACCEPTING TWO NAMES IS ONLY SAFE IF IT IS STILL REFUSING THE
# THIRD. A widening that also lets `prd.md` through has not widened, it has broken.
SOR="$WORK/sor"; mkdir -p "$SOR/s302/stories" || exit 2
cat > "$SOR/s302/locked-requirements.md" <<'SOREOF'
<!-- LOCKED_REQUIREMENTS — DO NOT MODIFY DURING VALIDATION -->
<!-- Source: user input -->
## LR-S302-1
- Rebalancing must never exceed a 2% slippage bound.
<!-- END LOCKED_REQUIREMENTS -->
SOREOF
cp "$SOR/s302/locked-requirements.md" "$SOR/product-brief.md"
cp "$SOR/s302/locked-requirements.md" "$SOR/s302/prd.md"
sor_story() { # sor_story <file> <cited-basename>
  cat > "$1" <<STOREOF
# Story
<!-- LOCKED_REQUIREMENTS -->
full_text_source: $2#LR-S302-1
- Rebalancing must never exceed a 2% slippage bound.
<!-- END LOCKED_REQUIREMENTS -->
STOREOF
}
sor_story "$SOR/s302/stories/new-sor.md"    "locked-requirements.md"
sor_story "$SOR/s302/stories/legacy-sor.md" "product-brief.md"
sor_story "$SOR/s302/stories/index-sor.md"  "prd.md"

if "$VALIDATOR" "$SOR/s302/stories/new-sor.md" >/dev/null 2>&1; then
  echo "ok: SoR — a citation at s<N>/locked-requirements.md is accepted"
else
  echo "FAIL: SoR — the sprint slot's locked-requirements.md was refused as a source of record" >&2
  rc=1
fi
if LEG_OUT="$("$VALIDATOR" "$SOR/s302/stories/legacy-sor.md" 2>&1)" \
   && grep -q "legacy 'product-brief.md'" <<<"$LEG_OUT"; then
  echo "ok: SoR — the legacy product-brief.md is still accepted AND counted on the PASS line"
else
  echo "FAIL: SoR — the legacy citation was refused or went uncounted: $LEG_OUT" >&2
  rc=1
fi
if "$VALIDATOR" "$SOR/s302/stories/index-sor.md" >/dev/null 2>&1; then
  echo "FAIL: SoR — prd.md was accepted as a full-text source; the widening broke the refusal" >&2
  rc=1
else
  echo "ok: SoR — CONTROL: prd.md is still refused, so accepting two names has not weakened (a)"
fi

# --- A CROSS-SPRINT ANCHOR READS THE SPRINT THE ANCHOR NAMES --------------------
# Rule 13 makes locked requirements cumulative, so a story can honestly cite an
# earlier sprint's requirement. With the block now in `s<N>/locked-requirements.md`
# the walk-up would reach the STORY'S OWN slot and report `anchor not found` -- a true
# statement about the wrong file, the failure this function was reordered in v0.263.0
# to stop producing. The story's own slot is seeded with a DIFFERENT requirement under
# a DIFFERENT anchor, so the arm below fails if the resolution order is wrong.
mkdir -p "$SOR/s299" || exit 2
cat > "$SOR/s299/locked-requirements.md" <<'SOREOF'
<!-- LOCKED_REQUIREMENTS — DO NOT MODIFY DURING VALIDATION -->
## LR-S299-1
- Carried: the rebalancer must publish a per-epoch delta.
<!-- END LOCKED_REQUIREMENTS -->
SOREOF
cat > "$SOR/s302/stories/cross-sprint.md" <<'STOREOF'
# Story
<!-- LOCKED_REQUIREMENTS -->
full_text_source: locked-requirements.md#LR-S299-1
- Carried: the rebalancer must publish a per-epoch delta.
<!-- END LOCKED_REQUIREMENTS -->
STOREOF
if "$VALIDATOR" "$SOR/s302/stories/cross-sprint.md" >/dev/null 2>&1; then
  echo "ok: cross-sprint — an anchor naming s299 resolves to s299/, not to the story's own slot"
else
  echo "FAIL: cross-sprint — a legal earlier-sprint anchor was rejected" >&2
  rc=1
fi
# CONTROL: the widening must not have disarmed the byte-match. A FABRICATED bullet
# under the same cross-sprint anchor still has to red, or the arm above only proved
# that something resolved.
sed 's/- Carried: the rebalancer must publish a per-epoch delta./- Carried: the rebalancer may publish whatever it likes./' \
  "$SOR/s302/stories/cross-sprint.md" > "$SOR/s302/stories/cross-sprint-bad.md"
if "$VALIDATOR" "$SOR/s302/stories/cross-sprint-bad.md" >/dev/null 2>&1; then
  echo "FAIL: cross-sprint CONTROL — a fabricated bullet passed under a cross-sprint anchor" >&2
  rc=1
else
  echo "ok: cross-sprint — CONTROL: a fabricated bullet still reds, so the byte-match is intact"
fi
# MUTATION: drop the sprint-slot candidates and demand the cross-sprint story reds.
MUT7="$WORK/mut-no-slot-resolve.sh"; cp "$VALIDATOR" "$MUT7"
sed -i.bak 's/^ANCHOR_SPRINT_RE = .*/ANCHOR_SPRINT_RE = re.compile(r"(?!x)x")/' "$MUT7" && rm -f "$MUT7.bak"
if cmp -s "$VALIDATOR" "$MUT7"; then
  echo "FAIL: MUTATION setup — ANCHOR_SPRINT_RE was not mutated, so the arm below proves nothing" >&2
  rc=1
elif bash "$MUT7" "$SOR/s302/stories/cross-sprint.md" >/dev/null 2>&1; then
  echo "FAIL: MUTATION — the cross-sprint story passed with slot resolution disabled; something else resolves it" >&2
  rc=1
else
  echo "ok: MUTATION — disabling sprint-slot resolution reds the cross-sprint story"
fi
# PAIRING: the same mutant must still accept a SAME-sprint story, or it died elsewhere.
if bash "$MUT7" "$SOR/s302/stories/new-sor.md" >/dev/null 2>&1; then
  echo "ok: MUTATION PAIRING — the same mutant still accepts a same-sprint citation (it fails only its own assertion)"
else
  echo "FAIL: MUTATION PAIRING — the mutant rejected the same-sprint story too; the assertions are entangled" >&2
  rc=1
fi

# MUTATION: collapse the pair back to one name and demand the OTHER one reds. Built as
# a copy and guarded with cmp -s so a sed that matched nothing cannot pass as a change.
MUT6="$WORK/mut-single-sor.sh"; cp "$VALIDATOR" "$MUT6"
sed -i.bak 's/^DEFAULT_SOR_BASENAMES = .*/DEFAULT_SOR_BASENAMES = ("locked-requirements.md",)/' "$MUT6" && rm -f "$MUT6.bak"
if cmp -s "$VALIDATOR" "$MUT6"; then
  echo "FAIL: MUTATION setup — DEFAULT_SOR_BASENAMES was not mutated, so the arm below proves nothing" >&2
  rc=1
elif bash "$MUT6" "$SOR/s302/stories/legacy-sor.md" >/dev/null 2>&1; then
  echo "FAIL: MUTATION — the legacy citation passed with the legacy name removed; the pair is not what accepts it" >&2
  rc=1
else
  echo "ok: MUTATION — dropping the legacy name reds the legacy citation (the acceptance is the pair, not the resolver)"
fi
# PAIRING: the same mutant must still accept the NEW name, or it died of something else.
if bash "$MUT6" "$SOR/s302/stories/new-sor.md" >/dev/null 2>&1; then
  echo "ok: MUTATION PAIRING — the same mutant still accepts locked-requirements.md (it fails only its own assertion)"
else
  echo "FAIL: MUTATION PAIRING — the mutant rejected the new name too; the two assertions are entangled" >&2
  rc=1
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
