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
# is that they also shared one REPORT LINE. The assertion is on the STRING, and the string
# is the token declared at enforcement-map.yaml `empty_subject_verdict:`, bound by I93.
NV_OUT="$("$VALIDATOR" "$DIR/nothing-verified-story.md" 2>&1)"
GD_OUT="$("$VALIDATOR" "$DIR/good-story.md" 2>&1)"
case "$NV_OUT" in
  *"EXAMINED NOTHING"*) echo "ok: a zero-verification story reports PASS — EXAMINED NOTHING" ;;
  *) echo "FAIL: a zero-verification story reports the same line as a verified one: $NV_OUT" >&2; rc=1 ;;
esac
case "$GD_OUT" in
  *"EXAMINED NOTHING"*) echo "FAIL: a VERIFIED story reported EXAMINED NOTHING — the two roads are swapped: $GD_OUT" >&2; rc=1 ;;
  *) echo "ok: OVER-FIRE CONTROL: a verified story does NOT report EXAMINED NOTHING" ;;
esac

MUT5="$WORK/mut-one-pass-line.sh"; cp "$VALIDATOR" "$MUT5"
sed -i.bak 's/^if claims_checked == 0 and pointers_checked == 0:$/if False:/' "$MUT5" && rm -f "$MUT5.bak"
if cmp -s "$VALIDATOR" "$MUT5"; then
  echo "FAIL: MUTATION setup — the two-road branch was not mutated, so the arm below proves nothing" >&2
  rc=1
else
  if bash "$MUT5" "$DIR/nothing-verified-story.md" 2>&1 | grep -q "EXAMINED NOTHING"; then
    echo "FAIL: MUTATION — the collapsed branch still distinguishes the two roads; the branch is not what does it" >&2
    rc=1
  else
    echo "ok: MUTATION — with the branch collapsed, a zero-verification story spells like a verified one (the defect, on demand)"
  fi
fi

# --- THE LEGACY SOURCE OF RECORD IS ACCEPTED AND IS ON ITS WAY OUT -----------------
# discovery.md §4a used to append each sprint's LOCKED block to the durable brief and
# now writes it to `s<N>/locked-requirements.md`. The legacy name is still accepted:
# refusing it would fail every story written before the move -- 31 of 62 anchored
# citations on the reference consumer, all resolvable, none defective -- which is this
# check reporting a migration as a fabrication.
#
# THREE ARMS, BECAUSE A WIDER NAME SET IS ONLY SAFE IF IT IS STILL REFUSING AN INDEX.
# A widening that also lets `prd.md` through has not widened, it has broken.
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
# AND BESIDE THE STORY, WHICH IS WHAT MAKES THESE ARMS CWD-INVARIANT. `resolve_artifact`
# tries the story's own directory, THEN the caller's cwd, THEN the walk-up. With the brief
# only two directories up, the walk-up is the candidate that finds it -- and THIS FIXTURE
# DIRECTORY SHIPS A `product-brief.md` DECOY carrying LR-1/LR-2, so running from here the
# cwd candidate won first and the legacy arm failed on `anchor 'LR-S302-1' not found`.
# Measured: rc=1 from this directory, rc=0 from the repo root, for years, on an arm that is
# correct either way. A story-local copy makes the FIRST candidate the right file, so every
# arm in this block answers the same from any cwd.
cp "$SOR/s302/locked-requirements.md" "$SOR/s302/stories/product-brief.md"
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
  echo "ok: SoR — CONTROL: prd.md is still refused, so widening the name set has not weakened (a)"
fi

# --- A CARRY-OVER BACKLOG IS A SOURCE OF RECORD, AND prd.md STILL IS NOT -----------
# A carry-over item's closure condition is verbatim text in `carry-over-backlog.md`, and
# a document quoting one makes the same full-text claim a story makes about a locked
# requirement. While the backlog was refused BY BASENAME, the only byte-verbatim
# quotation checker in core could not reach such a quotation at all: a condition could
# be quoted with its operative clause elided -- asserting a condition met that the
# quoting document itself declines to meet -- and the check that would have caught it
# declared the artifact out of scope before reading a byte.
#
# The world below MIRRORS the consumer's layout: the backlog sits TWO directories above
# the story, which is where `resolve_artifact`'s walk-up reaches it, under the `## [id]`
# heading shape the backlog actually carries.
#
# THE FILE IS PREAMBLE-SHAPED, AND THAT IS THE DISCRIMINATING PART. A real carry-over
# backlog names its active ids in a summary sentence under the single `# ` title, ABOVE
# the first `##`. That mention has depth 1, so its section runs to the next depth-1
# heading -- EOF -- and an `anchor_window` that unions EVERY hit line then returns the
# whole document. The byte-match degenerates to co-presence: a story cites one item and
# quotes a bullet from an unrelated one hundreds of lines away, and passes. So this world
# mentions the probe id TWICE -- once in the preamble, once as its own `## [id]` heading
# -- and puts a DIFFERENT bullet inside the preamble's section-to-EOF span.
COB="$WORK/carryover"; mkdir -p "$COB/s302/stories" || exit 2
cat > "$COB/carry-over-backlog.md" <<'COBEOF'
# Carry-Over Backlog

The active items this sprint (`CO-S302-PROBE`) carry forward under triage.

## [CO-S302-DECOY] [lead] - 2026-01-01T00:00:00Z

- Closure condition: the indexer drops its stale cursor before the next epoch boundary.

## [CO-S302-PROBE] [lead] - 2026-01-01T00:00:00Z

- Closure condition: the rebalancer publishes a per-epoch delta (feeds a future sprint's scope).
COBEOF
# The decoy must BE a decoy: the probe id has to appear both as a non-heading mention and
# as a heading, and the foreign bullet must sit outside the heading's own section. If the
# world ever stops having that shape the arms below still pass, having tested nothing.
co_pre="$(grep -c '^The active items this sprint' "$COB/carry-over-backlog.md")" || co_pre=0
co_head="$(grep -c '^## \[CO-S302-PROBE\]' "$COB/carry-over-backlog.md")" || co_head=0
if [ "$co_pre" -ne 1 ] || [ "$co_head" -ne 1 ]; then
  echo "FIXTURE ERROR: the carry-over world is no longer preamble-shaped (preamble mention=$co_pre, heading=$co_head)." >&2
  echo "  the narrowing arms below cannot distinguish a heading hit from a mention." >&2
  rc=2
fi
# THE DECOY BASENAME: identical text, identical anchor, a name that is not a source of
# record. This is the arm that separates "a third name was added" from "every name is
# now accepted" -- the over-broad non-fix satisfies every other assertion in this block.
cp "$COB/carry-over-backlog.md" "$COB/prd.md"
co_story() { # co_story <file> <cited-basename> <bullet>
  cat > "$1" <<COSEOF
# Story
<!-- LOCKED_REQUIREMENTS -->
full_text_source: $2:CO-S302-PROBE
$3
<!-- END LOCKED_REQUIREMENTS -->
COSEOF
}
CO_FULL="- Closure condition: the rebalancer publishes a per-epoch delta (feeds a future sprint's scope)."
CO_ELIDED="- Closure condition: the rebalancer publishes a per-epoch delta ..."
# The CROSS-SECTION quotation: byte-present in the file, under a heading the citation does
# NOT name, and inside the span the preamble mention would open.
CO_FOREIGN="- Closure condition: the indexer drops its stale cursor before the next epoch boundary."
co_story "$COB/s302/stories/carry-over-sor.md"    "carry-over-backlog.md" "$CO_FULL"
co_story "$COB/s302/stories/carry-over-elided.md" "carry-over-backlog.md" "$CO_ELIDED"
co_story "$COB/s302/stories/carry-over-index.md"  "prd.md"                "$CO_FULL"
co_story "$COB/s302/stories/carry-over-cross.md"  "carry-over-backlog.md" "$CO_FOREIGN"

if "$VALIDATOR" "$COB/s302/stories/carry-over-sor.md" >/dev/null 2>&1; then
  echo "ok: carry-over — a closure-condition quotation citing carry-over-backlog.md is ACCEPTED"
else
  echo "FAIL: carry-over — a byte-verbatim closure-condition quotation was refused" >&2
  rc=1
fi
# THE MOTIVATING CASE, and the REASON matters as much as the verdict. The operative
# clause is replaced by an ellipsis; it must fail, and it must fail at the BYTE-MATCH.
# A rejection at (a) would mean the quotation was never adjudicated -- which is exactly
# the state this widening exists to leave, scoring green while proving nothing.
if CO_OUT="$("$VALIDATOR" "$COB/s302/stories/carry-over-elided.md" 2>&1)"; then
  echo "FAIL: carry-over — an elided closure condition PASSED; the operative clause is unbound" >&2
  rc=1
elif grep -qF "not byte-present" <<<"$CO_OUT"; then
  echo "ok: carry-over — an elided closure condition is REJECTED as not byte-present"
else
  echo "FAIL: carry-over — the elided quotation was refused for the WRONG reason (not the byte-match): $CO_OUT" >&2
  rc=1
fi
if "$VALIDATOR" "$COB/s302/stories/carry-over-index.md" >/dev/null 2>&1; then
  echo "FAIL: carry-over CONTROL — prd.md carrying the SAME anchor and the SAME text was accepted; the widening is accept-everything" >&2
  rc=1
else
  echo "ok: carry-over — CONTROL: prd.md is refused on identical text, so the NAME SET is what admits the backlog"
fi
# THE THIRD NAME IS NOT THE NAME MESSAGES PRESCRIBE. `sor_basename` is what every PASS
# line and every remedy names, and it must stay the sprint slot. A tuple that merely
# REORDERS admits an identical set -- every exit code above is unchanged by it -- while
# telling every author to write the wrong file. rc cannot see that, so assert the STRING.
if NS_OUT="$("$VALIDATOR" "$SOR/s302/stories/new-sor.md" 2>&1)" \
   && grep -qF "verified against 'locked-requirements.md'" <<<"$NS_OUT"; then
  echo "ok: carry-over — the PASS line still prescribes locked-requirements.md as the record"
else
  echo "FAIL: carry-over — the PASS line no longer prescribes locked-requirements.md: $NS_OUT" >&2
  rc=1
fi
# THE ANCHOR WINDOW IS THE HEADING'S SECTION, NOT EVERY LINE MENTIONING THE ID. The
# quotation below is byte-present in the artifact, under a heading the citation does not
# name. It must red -- and it must red at the byte-match, because a rejection anywhere
# earlier would mean the window was never the thing under test.
if CX_OUT="$("$VALIDATOR" "$COB/s302/stories/carry-over-cross.md" 2>&1)"; then
  echo "FAIL: carry-over — a bullet from a section the citation does not name PASSED; the window is the whole file and the byte-match proves only co-presence" >&2
  rc=1
elif grep -qF "not byte-present" <<<"$CX_OUT"; then
  echo "ok: carry-over — a cross-section quotation is REJECTED (the window is the cited heading's section)"
else
  echo "FAIL: carry-over — the cross-section quotation was refused for the WRONG reason: $CX_OUT" >&2
  rc=1
fi

# MUTATION: revert the narrowing so every hit line opens a section again, and demand the
# cross-section story goes GREEN -- the defect on demand. Copy-built and cmp -s guarded.
#
# BOTH LAYERS COME OUT, BECAUSE THE FIX IS LAYERED AND A PARTIAL REVERT PROVES THE LAYER
# LEFT IN PLACE. Reverting only heading-wins leaves the preamble hit a MENTION, which the
# fallback bound then stops at the next heading of any depth -- so the cross-section story
# stays red and the mutant reads as "the narrowing is not what catches it". Measured
# exactly that way before this second replacement was added.
MUT9="$WORK/mut-all-hit-window.sh"; cp "$VALIDATOR" "$MUT9"
MUT_OLD='    heading_hits = [i for i in hits if HEADING_RE.match(lines[i])]
    if heading_hits:
        hits = heading_hits
' MUT_NEW='' \
python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
  "$VALIDATOR" "$MUT9"
MUT_OLD='            if not i_is_heading or len(hm.group(1)) <= depth:' \
MUT_NEW='            if len(hm.group(1)) <= depth:' \
python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[1],"w").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
  "$MUT9"
if cmp -s "$VALIDATOR" "$MUT9"; then
  echo "FAIL: MUTATION setup — the anchor-window narrowing was not reverted, so the arm below proves nothing" >&2
  rc=1
elif grep -q 'if not i_is_heading' "$MUT9"; then
  echo "FIXTURE ERROR: only ONE of the two window layers was reverted — the mutant would prove the layer left in place" >&2
  rc=2
elif bash "$MUT9" "$COB/s302/stories/carry-over-cross.md" >/dev/null 2>&1; then
  echo "ok: MUTATION — with every hit line opening a section, the preamble mention widens the window to EOF and the cross-section quotation passes (the defect, on demand)"
else
  echo "FAIL: MUTATION — the cross-section story still reds with the narrowing reverted; the narrowing is not what catches it" >&2
  rc=1
fi
# PAIRING: the same mutant must still accept the honest in-section quotation, or it died
# of something other than its own edit.
if bash "$MUT9" "$COB/s302/stories/carry-over-sor.md" >/dev/null 2>&1; then
  echo "ok: MUTATION PAIRING — the same mutant still accepts the in-section quotation (it fails only its own assertion)"
else
  echo "FAIL: MUTATION PAIRING — the mutant reds the honest carry-over story too; the assertions are entangled" >&2
  rc=1
fi
# FALLBACK: an anchor carried by NO heading must still resolve -- AND ITS WINDOW MUST STILL
# BE BOUNDED. The heading-wins rule cannot help an id that has no heading anywhere, so the
# same-or-shallower walk from a depth-1 mention runs to EOF and reproduces the whole-file
# window on exactly those ids. Measured on a reference consumer: of six ids named in the
# preamble, five carry their own heading and one does not, and that one's window was 3553
# lines of a 3575-line file. A non-heading hit therefore runs to the next heading of ANY
# depth. This brief is long enough to HAVE somewhere foreign to quote from -- a positive
# arm alone cannot see the bound, because a flat brief with one bullet has no second
# region to reach into.
printf '%s\n' "# Brief" \
  "" "Loose text carrying LR-FLAT-1 and its requirement." \
  "" "- LR-FLAT-1: the flat requirement stated in full." \
  "" "### An unrelated later section" \
  "" "- LR-OTHER-9: a requirement that belongs to a different subject entirely." \
  > "$COB/s302/stories/product-brief.md"
flat_story() { # flat_story <file> <bullet>
  printf '%s\n' "<!-- LOCKED_REQUIREMENTS -->" \
    "full_text_source: product-brief.md:LR-FLAT-1" "$2" \
    "<!-- END LOCKED_REQUIREMENTS -->" > "$1"
}
flat_story "$COB/s302/stories/flat-anchor.md"  "- LR-FLAT-1: the flat requirement stated in full."
flat_story "$COB/s302/stories/flat-cross.md"   "- LR-OTHER-9: a requirement that belongs to a different subject entirely."
if "$VALIDATOR" "$COB/s302/stories/flat-anchor.md" >/dev/null 2>&1; then
  echo "ok: carry-over — FALLBACK: an anchor in NO heading still resolves (the all-hits reading is kept for unstructured artifacts)"
else
  echo "FAIL: carry-over — FALLBACK: the narrowing broke a heading-less anchor, which it is required to preserve" >&2
  rc=1
fi
if FC_OUT="$("$VALIDATOR" "$COB/s302/stories/flat-cross.md" 2>&1)"; then
  echo "FAIL: carry-over — FALLBACK: a bullet past a later heading was accepted under a heading-less anchor; the fallback window is unbounded" >&2
  rc=1
elif grep -qF "not byte-present" <<<"$FC_OUT"; then
  echo "ok: carry-over — FALLBACK: a bullet past the next heading is REJECTED (a mention's window stops at the next heading of ANY depth)"
else
  echo "FAIL: carry-over — FALLBACK: the cross-region quotation was refused for the WRONG reason: $FC_OUT" >&2
  rc=1
fi
# MUTATION: revert the fallback bound so a mention walks to the next SAME-OR-SHALLOWER
# heading again, and demand the cross-region story goes GREEN. Without this the two arms
# above cannot tell a bounded window from a lucky one.
MUT10="$WORK/mut-unbounded-mention.sh"; cp "$VALIDATOR" "$MUT10"
MUT_OLD='            if not i_is_heading or len(hm.group(1)) <= depth:' \
MUT_NEW='            if len(hm.group(1)) <= depth:' \
python3 -c 'import os,sys; s=open(sys.argv[1]).read(); open(sys.argv[2],"w").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
  "$VALIDATOR" "$MUT10"
if cmp -s "$VALIDATOR" "$MUT10"; then
  echo "FAIL: MUTATION setup — the fallback bound was not reverted, so the fallback arms prove nothing" >&2
  rc=1
elif bash "$MUT10" "$COB/s302/stories/flat-cross.md" >/dev/null 2>&1; then
  echo "ok: MUTATION — with a mention walking to the next same-or-shallower heading, the cross-region quotation passes (the whole-file window, on demand)"
else
  echo "FAIL: MUTATION — the cross-region story still reds with the bound reverted; the bound is not what catches it" >&2
  rc=1
fi
# PAIRING: the same mutant must still accept the honest heading-less quotation.
if bash "$MUT10" "$COB/s302/stories/flat-anchor.md" >/dev/null 2>&1; then
  echo "ok: MUTATION PAIRING — the same mutant still accepts the honest flat quotation (it fails only its own assertion)"
else
  echo "FAIL: MUTATION PAIRING — the mutant reds the honest flat story too; the assertions are entangled" >&2
  rc=1
fi

# --- THE SoR ARMS ARE CWD-INVARIANT, AND THEY ASSERT IT THEMSELVES ------------------
# The block above used to answer differently from this directory than from the repo root,
# because the legacy story's brief was only reachable by the walk-up and THIS DIRECTORY
# SHIPS A DECOY of that basename. Seeding a story-local copy fixed it; this asserts the
# fix rather than trusting it, because the driver's choice of cwd is what hid it before.
for cwd_label in "decoy (this fixture dir)|$DIR" "empty|$EMPTY"; do
  cl="${cwd_label%%|*}"; cp_="${cwd_label#*|}"
  for case_spec in \
    "legacy-sor|$SOR/s302/stories/legacy-sor.md|0" \
    "new-sor|$SOR/s302/stories/new-sor.md|0" \
    "index-sor (prd.md)|$SOR/s302/stories/index-sor.md|1" \
    "carry-over|$COB/s302/stories/carry-over-sor.md|0" \
    "carry-over cross-section|$COB/s302/stories/carry-over-cross.md|1"; do
    cn="${case_spec%%|*}"; rest="${case_spec#*|}"
    cf="${rest%%|*}"; want="${rest##*|}"
    ( cd "$cp_" && bash "$VALIDATOR" "$cf" >/dev/null 2>&1 )
    got=$?
    if [ "$got" -eq "$want" ]; then
      echo "ok: SoR CWD INVARIANCE — $cn answers rc=$want from cwd '$cl'"
    else
      echo "FAIL: SoR CWD INVARIANCE — $cn from cwd '$cl': expected rc=$want, got rc=$got" >&2
      rc=1
    fi
  done
done

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

# MUTATION: drop the THIRD name and demand the carry-over story reds. Built as a copy
# and guarded with cmp -s so a sed that matched nothing cannot pass as a change. Without
# this arm the acceptance above is satisfied by anything that resolves the file, and the
# name set is not what is being tested.
MUT8="$WORK/mut-no-carryover-sor.sh"; cp "$VALIDATOR" "$MUT8"
sed -i.bak 's/^DEFAULT_SOR_BASENAMES = .*/DEFAULT_SOR_BASENAMES = ("locked-requirements.md", "product-brief.md")/' "$MUT8" && rm -f "$MUT8.bak"
if cmp -s "$VALIDATOR" "$MUT8"; then
  echo "FAIL: MUTATION setup — DEFAULT_SOR_BASENAMES was not mutated to the two-name tuple, so the arm below proves nothing" >&2
  rc=1
elif bash "$MUT8" "$COB/s302/stories/carry-over-sor.md" >/dev/null 2>&1; then
  echo "FAIL: MUTATION — the carry-over citation passed with carry-over-backlog.md removed; the name set is not what admits it" >&2
  rc=1
else
  echo "ok: MUTATION — dropping carry-over-backlog.md reds the carry-over story (the acceptance is the tuple, not the resolver)"
fi
# PAIRING: the same mutant must still accept the NEW name, or it died of something else.
if bash "$MUT8" "$SOR/s302/stories/new-sor.md" >/dev/null 2>&1; then
  echo "ok: MUTATION PAIRING — the same mutant still accepts locked-requirements.md (it fails only its own assertion)"
else
  echo "FAIL: MUTATION PAIRING — the mutant rejected the new name too; the assertions are entangled" >&2
  rc=1
fi

# MUTATION: collapse the set back to one name and demand the OTHER one reds. Built as
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

# --- THE POINTER ROAD'S COUNT FIELDS SEPARATE A FABRICATION FROM A QUOTATION --------
#
# THE DEFECT THESE EXIST TO CATCH. A block whose bullets were pure fabrication scored
# BYTE-IDENTICALLY to one whose bullets were verbatim, whenever the block cited
# `requires_context:` -- same exit code AND same report line -- so nothing downstream of
# this script could tell them apart. The other two roads reject the identical
# fabrication, which is the control that the validator discriminates and that this road
# is where it did not.
#
# AND THE EXIT CODE MUST NOT MOVE, WHICH IS WHY THESE ARMS ASSERT IT SEPARATELY. An
# abridged cite-by-reference restatement is the honest shape on this road: measured over a
# reference consumer's corpus, 7 of the 13 stories that reach the observation carry at
# least one non-verbatim bullet and 49 of 51 bullets overall are not byte-present. As a
# failure condition that is a 54% red rate on honest blocks, and a builder who makes the
# fabricated story exit 1 has shipped that regression. Every arm below therefore pairs the
# count assertion with an exit-code assertion.
#
# THE ARMS KEY ON THE COUNT FIELDS, NEVER ON THE FIRST LINE, AND THAT IS MEASURED RATHER
# THAN STYLISTIC. The entry's receipt closes on EITHER an exit-code split OR a
# first-report-line split, and a change making the line differ for a reason unrelated to
# the bullets satisfies it while shipping nothing. Built and confirmed live: a mutant
# replacing the observation with a per-story run marker on the PASS line splits the two
# stories' first lines perfectly, closes the receipt, and reports nothing about any
# bullet. `MB1` below is that mutant and it must come out RED.
#
# `requires-context-story.md` IS NOT A SUBSTITUTE FOR THE ABRIDGED SEED. The file this
# fixture designates as the honest cite-by-reference case scores 1 byte-present / 0 not --
# its bullet is verbatim at the anchor -- so the false-positive set is EMPTY there and a
# builder measuring FP on it reads a false zero. The abridged world below is the shape the
# corpus lacked: an honest bullet shortened from a longer source sentence, which reports
# `not byte-present` WHILE STILL EXITING 0. That arm is what proves report-only is
# report-only, and a fixture without it cannot see an enforcing regression at all.
CTX="$WORK/ctxobs"; mkdir -p "$CTX" || exit 2
cat > "$CTX/product-brief.md" <<'CTXEOF'
# Brief

## LR-A1

- LR-A1: The indexer MUST publish a per-epoch delta, including the cursor
  position and the epoch boundary, before the next compaction begins.

## LR-A2

- LR-A2: The rebalancer MUST refuse a trade whose slippage exceeds two percent.
CTXEOF

ctx_story() { # ctx_story <file> <bullet>
  printf '%s\n' "# story" "" "<!-- LOCKED_REQUIREMENTS -->" \
    "requires_context: product-brief.md#LR-A1" "$2" \
    "<!-- END LOCKED_REQUIREMENTS -->" > "$1"
}
CTX_VERBATIM="- LR-A1: The indexer MUST publish a per-epoch delta, including the cursor position and the epoch boundary, before the next compaction begins."
CTX_FABRICATED="- LR-A1: The indexer MAY discard the epoch delta whenever it likes."
# THE ABRIDGED HONEST BULLET. Every word of it is drawn from the source sentence and it
# asserts nothing the source does not; it is shorter, which is what a cite-by-reference
# restatement is FOR. It must report not-byte-present and must exit 0.
CTX_ABRIDGED="- LR-A1: The indexer publishes a per-epoch delta before the next compaction."
# The CROSS-SECTION bullet: byte-present in the artifact, under a heading the pointer does
# not name. It separates "the observation matched the window" from "the observation
# matched the file".
CTX_FOREIGN="- LR-A2: The rebalancer MUST refuse a trade whose slippage exceeds two percent."

ctx_story "$CTX/h.md" "$CTX_VERBATIM"
ctx_story "$CTX/f.md" "$CTX_FABRICATED"
ctx_story "$CTX/a.md" "$CTX_ABRIDGED"
ctx_story "$CTX/x.md" "$CTX_FOREIGN"

# The sides must DIFFER, asserted before any comparison is read. Two stories built from
# one template with the same bullet produce the same counts for that reason and not
# because the observation works.
ctx_pairs_ok=1
for ctx_pair in "h f" "h a" "h x"; do
  set -- $ctx_pair
  if cmp -s "$CTX/$1.md" "$CTX/$2.md"; then
    echo "FIXTURE ERROR: the $1 and $2 probe stories are byte-identical — the count comparison below discriminates nothing" >&2
    rc=2; ctx_pairs_ok=0
  fi
done
[ "$ctx_pairs_ok" -eq 1 ] && echo "ok: ctx observation — the probe stories differ (the comparison has two sides)"

# Read the COUNT FIELDS out of the PASS line. Never the first line as a whole: a run
# marker, a timestamp or a path splits that and says nothing about a bullet.
ctx_counts() { # ctx_counts <validator> <story>  -> "<rc> <found>/<notfound>"
  local out got n
  out="$(bash "$1" "$2" 2>&1)"; got=$?
  n="$(sed -n 's/.*requires_context bullets \([0-9][0-9]*\) byte-present \/ \([0-9][0-9]*\) not byte-present.*/\1\/\2/p' <<<"$out")"
  printf '%s %s' "$got" "${n:-NONE}"
}

ctx_case() { # ctx_case <validator> <story> <want-rc> <want-counts> <what>
  local r want
  r="$(ctx_counts "$1" "$2")"
  want="$3 $4"
  if [ "$r" = "$want" ]; then
    echo "ok: ctx observation — $5 (rc=$3, $4 byte-present/not)"
    return 0
  fi
  echo "FAIL: ctx observation — $5: expected rc/counts '$want', got '$r'" >&2
  rc=1
  return 1
}

ctx_case "$VALIDATOR" "$CTX/h.md" 0 "1/0" "a VERBATIM bullet is counted byte-present"
ctx_case "$VALIDATOR" "$CTX/f.md" 0 "0/1" "a FABRICATED bullet is counted not byte-present AND STILL EXITS 0"
ctx_case "$VALIDATOR" "$CTX/a.md" 0 "0/1" "an ABRIDGED HONEST bullet is counted not byte-present AND STILL EXITS 0 — the observation is a report, not a verdict"
ctx_case "$VALIDATOR" "$CTX/x.md" 0 "0/1" "a bullet from a section the pointer does not name is not byte-present at the CITED anchor"

# THE FABRICATED/HONEST SPLIT, ASSERTED ON THE COUNTS THEMSELVES. Two stories one bullet
# apart must disagree on the count fields. This is the assertion the entry's receipt
# cannot make, because it closes on any difference in the line.
ctx_h="$(ctx_counts "$VALIDATOR" "$CTX/h.md")"
ctx_f="$(ctx_counts "$VALIDATOR" "$CTX/f.md")"
if [ "${ctx_h#* }" = "NONE" ] || [ "${ctx_f#* }" = "NONE" ]; then
  echo "FAIL: ctx observation — one of the two stories printed NO count fields at all, so the split below is unmeasurable (h='$ctx_h' f='$ctx_f')" >&2
  rc=1
elif [ "${ctx_h#* }" = "${ctx_f#* }" ]; then
  echo "FAIL: ctx observation — a verbatim and a fabricated block report the SAME count fields ('${ctx_h#* }'); nothing downstream of this validator can tell them apart" >&2
  rc=1
else
  echo "ok: ctx observation — the fabricated and honest blocks SPLIT on the count fields ('${ctx_f#* }' vs '${ctx_h#* }')"
fi
# ... and the exit codes must NOT split. The whole constraint on this road.
if [ "${ctx_h%% *}" = "0" ] && [ "${ctx_f%% *}" = "0" ]; then
  echo "ok: ctx observation — CONSTRAINT: both blocks still exit 0, so the byte-match did not become a failure condition on this road"
else
  echo "FAIL: ctx observation — CONSTRAINT BROKEN: the exit codes moved (h='$ctx_h' f='$ctx_f'). Byte-matching this road as a verdict reds 7 of every 13 honest stories that reach it" >&2
  rc=1
fi

# --- MB1: the RUN-MARKER mutant, which closes the receipt and ships nothing ---------
# Built as a copy and guarded by `cmp -s`. It replaces the count fields with a per-story
# marker: the two stories' first report lines then differ perfectly, the entry's receipt
# closes, and no bullet was examined. The arms above must come out RED on it.
MB1="$WORK/mut-run-marker.sh"
MUT_OLD='        ctx_note = (
            f", requires_context bullets {ctx_bullets_verbatim} byte-present / "
            f"{ctx_bullets_absent} not byte-present at the cited anchor(s) "
            f"(observation only — an abridged restatement is the honest shape on "
            f"this road and is never failed here)"
        )' \
MUT_NEW='        ctx_note = f", run-marker {os.path.basename(story_path)}"' \
python3 -c 'import os,sys; s=open(sys.argv[1],encoding="utf-8").read(); open(sys.argv[2],"w",encoding="utf-8").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
  "$VALIDATOR" "$MB1"
if cmp -s "$VALIDATOR" "$MB1"; then
  echo "FIXTURE ERROR: MB1 changed no bytes — the run-marker mutant did not apply, so the arms above prove nothing" >&2
  rc=2
else
  mb1_h="$(ctx_counts "$MB1" "$CTX/h.md")"
  mb1_f="$(ctx_counts "$MB1" "$CTX/f.md")"
  if [ "${mb1_h#* }" = "NONE" ] && [ "${mb1_f#* }" = "NONE" ]; then
    echo "ok: MUTATION MB1 — a per-story run marker prints NO count fields, so the arms above score it RED (they read the counts, not the line)"
  else
    echo "FAIL: MUTATION MB1 — the run-marker mutant still satisfies the count arms (h='$mb1_h' f='$mb1_f'); they are reading something a marker can forge" >&2
    rc=1
  fi
  # PAIRING, and it is what makes MB1 a statement about the RECEIPT rather than about the
  # mutant being broken: the mutant's FIRST LINES still differ, so the entry's
  # line-based receipt closes on it while it examines nothing.
  mb1_hl="$(bash "$MB1" "$CTX/h.md" 2>&1 | head -1)"
  mb1_fl="$(bash "$MB1" "$CTX/f.md" 2>&1 | head -1)"
  if [ "$mb1_hl" != "$mb1_fl" ]; then
    echo "ok: MUTATION MB1 PAIRING — the mutant's first report lines DO differ, so a receipt closing on a line split would close on it; only a count-keyed arm reds it"
  else
    echo "FAIL: MUTATION MB1 PAIRING — the mutant's first lines are identical, so it is not the receipt-weakness shape and MB1 above proves less than it claims" >&2
    rc=1
  fi
fi

# --- MB2: the ENFORCING mutant — the regression the exemption exists to avoid -------
# The observation becomes a failure condition. The fabricated story reds, which looks like
# an improvement, and the ABRIDGED HONEST story reds with it -- which is the 54% red rate
# on the real corpus. Only the abridged seed can see this, which is why it had to be built.
MB2="$WORK/mut-enforce-observation.sh"
MUT_OLD='            else:
                ctx_bullets_absent += 1' \
MUT_NEW='            else:
                ctx_bullets_absent += 1
                failures.append(f"block #{bidx}: MUTANT — observation enforced")' \
python3 -c 'import os,sys; s=open(sys.argv[1],encoding="utf-8").read(); open(sys.argv[2],"w",encoding="utf-8").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
  "$VALIDATOR" "$MB2"
if cmp -s "$VALIDATOR" "$MB2"; then
  echo "FIXTURE ERROR: MB2 changed no bytes — the enforcing mutant did not apply, so the report-only assertion above proves nothing" >&2
  rc=2
else
  mb2_a="$(ctx_counts "$MB2" "$CTX/a.md")"
  if [ "${mb2_a%% *}" = "0" ]; then
    echo "FAIL: MUTATION MB2 — with the observation appended to failures, the ABRIDGED HONEST story still exits 0; the report-only assertion is not what keeps it green" >&2
    rc=1
  else
    echo "ok: MUTATION MB2 — enforcing the observation REDS the abridged honest story (report-only is what keeps it green, and an enforcing regression is visible)"
  fi
  # PAIRING: the same mutant must still accept the VERBATIM story, or it reds everything
  # and its verdict is unattributable.
  mb2_h="$(ctx_counts "$MB2" "$CTX/h.md")"
  if [ "${mb2_h%% *}" = "0" ]; then
    echo "ok: MUTATION MB2 PAIRING — the same mutant still accepts the verbatim story (it fails only its own assertion)"
  else
    echo "FAIL: MUTATION MB2 PAIRING — the enforcing mutant reds the verbatim story too; it reds everything and MB2 above is unattributable" >&2
    rc=1
  fi
fi

# --- MB3: the WINDOW mutant — the observation must match the CITED anchor -----------
# Matching against the whole artifact instead of the resolved window degenerates the
# observation to co-presence: a bullet lifted from a section the pointer does not name
# would then count as byte-present. The cross-section story is the only seed that sees it.
MB3="$WORK/mut-ctx-whole-file.sh"
MUT_OLD='        ctx_norm = collapse_ws("\n".join(ctx_windows))' \
MUT_NEW='        ctx_norm = collapse_ws(open(resolved, "r", encoding="utf-8").read())' \
python3 -c 'import os,sys; s=open(sys.argv[1],encoding="utf-8").read(); open(sys.argv[2],"w",encoding="utf-8").write(s.replace(os.environ["MUT_OLD"],os.environ["MUT_NEW"],1))' \
  "$VALIDATOR" "$MB3"
if cmp -s "$VALIDATOR" "$MB3"; then
  echo "FIXTURE ERROR: MB3 changed no bytes — the window mutant did not apply, so the cross-section arm above proves nothing" >&2
  rc=2
else
  mb3_x="$(ctx_counts "$MB3" "$CTX/x.md")"
  if [ "${mb3_x#* }" = "1/0" ]; then
    echo "ok: MUTATION MB3 — matching the whole artifact counts a bullet from an uncited section as byte-present (the window is what scopes the observation)"
  else
    echo "FAIL: MUTATION MB3 — the cross-section bullet is still not byte-present with the window widened to the whole file (got '$mb3_x'); the window is not what the cross-section arm tests" >&2
    rc=1
  fi
  # PAIRING: the same mutant must still count the fabricated bullet as absent. A mutant
  # that counted everything present would satisfy the arm above while testing nothing.
  mb3_f="$(ctx_counts "$MB3" "$CTX/f.md")"
  if [ "${mb3_f#* }" = "0/1" ]; then
    echo "ok: MUTATION MB3 PAIRING — the same mutant still counts a fabricated bullet as absent (it widened the window, it did not disarm the match)"
  else
    echo "FAIL: MUTATION MB3 PAIRING — the whole-file mutant counts the fabricated bullet present too (got '$mb3_f'); it disarms the match rather than widening the window" >&2
    rc=1
  fi
fi

# --- THE DESIGNATED HONEST FILE CANNOT MEASURE THE FALSE-POSITIVE SET ---------------
# ASSERTED, NOT ASSUMED. `requires-context-story.md` is what this fixture's README names
# as the honest cite-by-reference case, and its bullet is VERBATIM at the anchor -- so it
# reports 1/0 and the FP set measured on it is empty by construction. A builder who reads
# that zero as "the observation never fires on honest prose" has measured the wrong file.
# If it ever stops being verbatim this arm says so, rather than the abridged seed above
# quietly becoming redundant.
rcs_counts="$(ctx_counts "$VALIDATOR" "$DIR/requires-context-story.md")"
if [ "$rcs_counts" = "0 1/0" ]; then
  echo "ok: ctx observation — the designated honest story is VERBATIM (1/0), so it cannot measure the false-positive set and the abridged seed above is what does"
else
  echo "FAIL: ctx observation — requires-context-story.md reports '$rcs_counts', not '0 1/0'. Either its bullet stopped being verbatim at the anchor or the observation stopped reaching it; re-derive before trusting any FP figure taken here" >&2
  rc=1
fi

# --- CWD INVARIANCE for the observation --------------------------------------------
# THIS DIRECTORY SHIPS A `product-brief.md` DECOY carrying LR-1/LR-2, and the observation
# resolves its window through the same `resolve_artifact` every other arm uses. An
# observation that answered differently from here would report byte-present counts about
# a file the story never cited. Both polarities, from the decoy cwd and from an empty one.
for ctx_cwd in "decoy (this fixture dir)|$DIR" "empty|$EMPTY"; do
  ctx_cl="${ctx_cwd%%|*}"; ctx_cp="${ctx_cwd#*|}"
  for ctx_spec in "verbatim|$CTX/h.md|0 1/0" "fabricated|$CTX/f.md|0 0/1" "abridged|$CTX/a.md|0 0/1"; do
    ctx_n="${ctx_spec%%|*}"; ctx_rest="${ctx_spec#*|}"
    ctx_file="${ctx_rest%%|*}"; ctx_want="${ctx_rest##*|}"
    ctx_got="$( cd "$ctx_cp" && ctx_counts "$VALIDATOR" "$ctx_file" )"
    if [ "$ctx_got" = "$ctx_want" ]; then
      echo "ok: ctx observation CWD INVARIANCE — $ctx_n answers '$ctx_want' from cwd '$ctx_cl'"
    else
      echo "FAIL: ctx observation CWD INVARIANCE — $ctx_n from cwd '$ctx_cl': expected '$ctx_want', got '$ctx_got'" >&2
      rc=1
    fi
  done
done

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
