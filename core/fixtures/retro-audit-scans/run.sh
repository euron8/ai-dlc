#!/usr/bin/env bash
# retro-audit-scans/run.sh — prove the two scans that replaced retro Step 4's
# analyst dispatch can actually FAIL, and that they refuse to pass vacuously.
#
# THE DEFECT THIS EXISTS TO CATCH. Step 4's rule-file audit, path-filter
# dormancy scan and relocation-pointer scan were prose handed to an analyst
# subagent. The output was a table, and a table saying CLEAN is indistinguishable
# from a scan that never ran — sprint-295's pointer scan reported clean while a
# dangling `steps/rule-authoring.md` sat in extensions/README.md, because core's
# prose scoped the scan to SKILL.md + steps/*.md and the analyst obeyed it.
# Mechanizing the scan only helps if the scan can fail, so every class is
# asserted in BOTH directions: seeded violation -> FLAGGED, clean tree -> CLEAN.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
# Herestring, not a pipe: under `pipefail`, a `grep -q` that matches in the first
# few lines exits before the writer finishes and the pipeline reports the writer's
# SIGPIPE, so a MATCH is read as a failed assertion. Every tier-1 label prints at
# the top of the report, which is exactly where that bites.
has() { grep -q "$1" <<<"$2"; }

echo "retro-audit-scans:"

# A pristine copy per assertion, so one mutation never leaks into the next.
fresh() { rm -rf "$WORK/t"; cp -R "$PROJ" "$WORK/t"; }
audit() { ( cd "$WORK/t" && bash "$AUDIT" 2>&1 ); }
manifest() { ( cd "$WORK/t" && bash "$MANIFEST" .claude/skills/ai-dlc/steps/gate-validation.md 2>&1 ); }
rc_of() { ( cd "$WORK/t" && bash "$1" "${@:2}" >/dev/null 2>&1; echo $? ); }

GV=".claude/skills/ai-dlc/steps/gate-validation.md"

# ============================ audit-rule-files.sh ============================

# --- Assertion 0: SANITY — the clean corpus is clean -------------------------
fresh
out="$(audit)"; rc="$(rc_of "$AUDIT")"
if [ "$rc" = "0" ] && has 'NARRATIVE_DRIFT: CLEAN' "$out"; then
  ok "clean corpus -> exit 0, every mechanized class CLEAN"
else
  bad "the clean control corpus did not pass (rc=$rc) — every assertion below is unreadable"
fi

# --- Assertion 1: narrative drift is DETECTED -------------------------------
fresh
echo 'The lead MUST retry, because we lost a sprint to this.' >> "$WORK/t/CLAUDE.md"
out="$(audit)"
has 'NARRATIVE_DRIFT: FLAGGED' "$out" \
  && ok "seeded 'because we' narrative -> NARRATIVE_DRIFT FLAGGED" \
  || bad "narrative drift went undetected — Class 1 cannot fire"
[ "$(rc_of "$AUDIT")" = "1" ] && ok "  and exit 1" || bad "  but exit was not 1"

# --- Assertion 2: a QUOTED mention is NOT drift ------------------------------
# The regression that produced 5 false positives on the reference consumer: the
# line DEFINING narrative drift was scored as narrative drift.
fresh
echo 'Rule text carrying "because we" justification is drift and FAILs the audit.' >> "$WORK/t/CLAUDE.md"
out="$(audit)"
has 'NARRATIVE_DRIFT: CLEAN' "$out" \
  && ok "a quoted mention of the pattern -> still CLEAN (mention is not use)" \
  || bad "the audit flagged its own definition — the quoted-span guard is gone"

# --- Assertion 3: rule weakness is DETECTED ----------------------------------
fresh
echo 'The dev should attach evidence; a missing attachment is a violation.' >> "$WORK/t/.claude/team-roles/dev.md"
out="$(audit)"; has 'RULE_WEAKNESS: FLAGGED' "$out" \
  && ok "seeded soft language beside a mandate -> RULE_WEAKNESS FLAGGED" \
  || bad "rule weakness went undetected — Class 2 cannot fire"

# --- Assertion 4: a NEGATIVE mandate is not weakness -------------------------
fresh
echo 'The dev should never merge unreviewed code; doing so is a violation.' >> "$WORK/t/.claude/team-roles/dev.md"
out="$(audit)"; has 'RULE_WEAKNESS: CLEAN' "$out" \
  && ok "'should never' beside a mandate -> CLEAN (negative mandate exempt)" \
  || bad "'should never' was flagged as soft language"

# --- Assertion 5: an incomplete Rule 26(c) triple is DETECTED ---------------
fresh
cat >> "$WORK/t/.claude/skills/ai-dlc/steps/example.md" <<'EOF'

**Minimum mechanism.** Failure caught: an unrecorded outcome reaching the gate.
EOF
out="$(audit)"; has 'INCOMPLETE_26C: FLAGGED' "$out" \
  && ok "'Failure caught:' with no other two fields -> INCOMPLETE_26C FLAGGED" \
  || bad "an incomplete Rule 26(c) triple went undetected — Class 1b cannot fire"

# --- Assertion 6: a COMPLETE triple is not flagged --------------------------
# Section-scoped, not line-scoped: the fields wrap across lines mid-phrase.
fresh
cat >> "$WORK/t/.claude/skills/ai-dlc/steps/example.md" <<'EOF'

**Minimum mechanism.** Failure caught: an unrecorded outcome reaching the gate.
False-positive cost: one redundant line per step. Removal condition: retire
once the outcome is written structurally.
EOF
out="$(audit)"; has 'INCOMPLETE_26C: CLEAN' "$out" \
  && ok "a complete triple wrapping across lines -> CLEAN (section-scoped)" \
  || bad "a complete Rule 26(c) triple was flagged incomplete"

# --- Assertion 7: a dangling pointer is DETECTED ----------------------------
# The live defect this scan found on its first real run.
fresh
echo 'The convention is defined in `steps/rule-authoring.md`.' \
  >> "$WORK/t/.claude/skills/ai-dlc/extensions/README.md"
out="$(audit)"; has 'DANGLING_POINTER: FLAGGED' "$out" \
  && ok "pointer to a nonexistent skill file -> DANGLING_POINTER FLAGGED" \
  || bad "a dangling skill-content pointer went undetected"

# --- Assertion 8: the scan reaches extensions/, not just steps/ -------------
# Assertion 7 seeded into extensions/README.md specifically: core's prose scoped
# invariant 1 to SKILL.md + steps/*.md, which is why the real dangling pointer
# survived every prior retro.
fresh
mkdir -p "$WORK/t/.claude/skills/ai-dlc/overrides"
echo 'Canonical shape is defined in `steps/no-such-step.md`.' \
  > "$WORK/t/.claude/skills/ai-dlc/overrides/entry.md"
out="$(audit)"; has 'overrides/entry.md.*DANGLING_POINTER' "$out" \
  && ok "a dangling pointer inside overrides/ is reached by the scan" \
  || bad "overrides/ is outside the pointer scan — the scope bug is back"

# --- Assertion 9: a RESOLVABLE pointer is not flagged -----------------------
fresh
echo 'Rule text lives in `rule-authoring.md` and `team-roles/dev.md`.' \
  >> "$WORK/t/.claude/skills/ai-dlc/steps/example.md"
out="$(audit)"; has 'DANGLING_POINTER: CLEAN' "$out" \
  && ok "pointers to files that exist -> CLEAN" \
  || bad "a resolvable pointer was reported dangling"

# --- Assertion 10: dormancy reports N/A, never CLEAN, with no workflows -----
fresh
out="$(audit)"; has 'PATH_DORMANCY: N/A' "$out" \
  && ok "no .github/workflows/ -> PATH_DORMANCY N/A (not a silent CLEAN)" \
  || bad "an absent workflow dir did not report N/A"

# --- Assertion 11: an EMPTY corpus fails, never passes ----------------------
# A scan of nothing reports every class CLEAN. That is the exact shape of a
# check that cannot fire, so it must exit 2 instead.
rm -rf "$WORK/t"; mkdir -p "$WORK/t"
[ "$(rc_of "$AUDIT")" = "2" ] \
  && ok "empty corpus -> exit 2 (refuses to score nothing as clean)" \
  || bad "an empty corpus did not exit 2 — the audit can pass by scanning nothing"

# --- Assertion 12: Class 3 never reports CLEAN ------------------------------
fresh
out="$(audit)"; has 'COMPLEXITY_ACCRETION: DID-NOT-RUN' "$out" \
  && ok "complexity accretion reports DID-NOT-RUN, never CLEAN (lead-owned)" \
  || bad "Class 3 claimed a verdict it cannot compute"

# ------------------- tier 1: the prohibitions with no mechanism -------------
# rule-authoring.md forbids sprint references, version tags, parenthetical origin
# notes and embedded dates. None of the four was mechanized, and they are the
# shapes the corpus actually carried — narrative shipped twice while Class 1's
# five colloquial phrases reported CLEAN over it.
audit_mut() { ( cd "$WORK/t" && AI_DLC_AUDIT_MUTANT=1 bash "$AUDIT" 2>&1 ); }
rc_mut()    { ( cd "$WORK/t" && AI_DLC_AUDIT_MUTANT=1 bash "$AUDIT" "$@" >/dev/null 2>&1; echo $? ); }

# --- Assertion 12a: a version tag in rule prose is DETECTED -----------------
fresh
echo 'The lead MUST re-run the gate; this replaced the v0.42.0 behaviour.' >> "$WORK/t/CLAUDE.md"
out="$(audit)"; has 'ORIGIN_TAG: FLAGGED' "$out" \
  && ok "seeded version tag -> ORIGIN_TAG FLAGGED" \
  || bad "a version tag in rule prose went undetected"
[ "$(rc_of "$AUDIT" --fail-on=deterministic)" = "1" ] \
  && ok "  and it gates the push (--fail-on=deterministic -> exit 1)" \
  || bad "  but --fail-on=deterministic did not exit 1"

# --- Assertion 12b: a sprint reference is DETECTED --------------------------
fresh
echo 'The lead MUST cite the operator; this closes the S301 hole.' >> "$WORK/t/CLAUDE.md"
out="$(audit)"; has 'ORIGIN_TAG: FLAGGED' "$out" \
  && ok "seeded sprint reference -> ORIGIN_TAG FLAGGED" \
  || bad "a sprint reference in rule prose went undetected"

# --- Assertion 12c: a BACKTICKED version tag is not a violation -------------
# Same mention-is-not-use guard Assertion 2 asserts for Class 1. rule-authoring.md
# has to be able to name the shape it forbids.
fresh
echo 'A tag such as `v0.42.0` in rule prose FAILs this audit.' >> "$WORK/t/CLAUDE.md"
out="$(audit)"; has 'ORIGIN_TAG: CLEAN' "$out" \
  && ok "a backticked version tag -> still CLEAN (mention is not use)" \
  || bad "the audit flagged its own definition of the origin-tag shape"

# --- Assertion 12d: a parenthetical origin note is DETECTED -----------------
fresh
echo 'The lead MUST run the close gate (formerly the retro gate) before merging.' \
  >> "$WORK/t/CLAUDE.md"
out="$(audit)"; has 'ORIGIN_PARENTHETICAL: FLAGGED' "$out" \
  && ok "seeded parenthetical origin note -> ORIGIN_PARENTHETICAL FLAGGED" \
  || bad "a parenthetical origin note went undetected"

# --- Assertion 12e: an embedded date is DETECTED ----------------------------
fresh
echo 'The lead MUST attach evidence; this has been required since 2026-04-17.' \
  >> "$WORK/t/CLAUDE.md"
out="$(audit)"; has 'EMBEDDED_DATE: FLAGGED' "$out" \
  && ok "seeded embedded date -> EMBEDDED_DATE FLAGGED" \
  || bad "an embedded date went undetected"

# --- Assertion 12f: MUTATION CONTROL — tier 1 is what catches tier 1 --------
# Every seed above, in one corpus, with the tier-1 patterns stripped. If this
# still reports FLAGGED, some older class is matching the seeds and the new code
# is unproven — the assertions above would be passing for the wrong reason.
fresh
cat >> "$WORK/t/CLAUDE.md" <<'EOF'
The lead MUST re-run the gate; this replaced the v0.42.0 behaviour.
The lead MUST cite the operator; this closes the S301 hole.
The lead MUST run the close gate (formerly the retro gate) before merging.
The lead MUST attach evidence; this has been required since 2026-04-17.
EOF
out="$(audit_mut)"
if has 'ORIGIN_TAG: CLEAN' "$out" \
   && has 'ORIGIN_PARENTHETICAL: CLEAN' "$out" \
   && has 'EMBEDDED_DATE: CLEAN' "$out" \
   && [ "$(rc_mut --fail-on=deterministic)" = "0" ]; then
  ok "MUTANT: tier-1 patterns stripped -> the same corpus scores CLEAN"
else
  bad "MUTANT run still flagged the tier-1 seeds — an older class is catching them, so the new patterns are unproven"
fi
# And the same corpus WITHOUT the mutant must fail, or the control proves nothing.
[ "$(rc_of "$AUDIT" --fail-on=deterministic)" = "1" ] \
  && ok "  and the unmutated run on that corpus exits 1 (control is live)" \
  || bad "  but the unmutated run also passed — the differential is vacuous"

# ------------- tier 1: the GRANT, which is the other half of the above -------
# Every assertion above tests a PROHIBITION. rule-authoring.md's Style block also
# has to PERMIT a form for the stable identifier its own skill cites throughout,
# and for the whole life of the file it permitted none — leaving retro.md Step 4
# a prohibition it could enforce against any tag a rule carries and no form to
# point the author at. Nothing in the tree asserted the grant, so a fix that
# deleted it again would restore the defect with every check green.
RA=".claude/skills/ai-dlc/rule-authoring.md"

# --- Assertion 12m: the grant deleted, its own trailing PROHIBITION retained -
# THE DECISIVE INPUT, and the reason this arm is not anchored on the word
# "identifier". The grant's closing clause is itself a prohibition, so a Style
# block holding that clause ALONE is prohibitions-only, IS the defect, and still
# contains the word. Measured on a copy: an `identifier` anchor scores this CLEAN.
fresh
cp "$WORK/t/$RA" "$WORK/ra.pristine"
cat > "$WORK/t/$RA" <<'EOF'
# Rule authoring
Rules are imperative.

**Style:**

- An identifier is a name and MUST NOT encode a sprint, story, version,
  or date.
- No sprint or story references.
- No parenthetical origin notes after a directive.
EOF
if cmp -s "$WORK/ra.pristine" "$WORK/t/$RA"; then
  bad "FIXTURE BROKEN — the Class 1c mutant is byte-identical to the seed, so nothing was mutated and the arms below prove nothing"
else
  out="$(audit)"; has 'IDENTIFIER_GRANT: FLAGGED' "$out" \
    && ok "grant deleted with its trailing prohibition retained -> IDENTIFIER_GRANT FLAGGED" \
    || bad "a Style block that prohibits every way to carry an identifier and permits none went undetected"
  [ "$(rc_of "$AUDIT" --fail-on=deterministic)" = "1" ] \
    && ok "  and it gates the push (--fail-on=deterministic -> exit 1)" \
    || bad "  but --fail-on=deterministic did not exit 1"
  # MUTANT differential, on THIS corpus rather than 12f's: 12f seeds only CLAUDE.md,
  # where this class has no subject, so it scores the same either way there and
  # establishes nothing about Class 1c.
  has 'IDENTIFIER_GRANT: CLEAN' "$(audit_mut)" \
    && ok "  MUTANT: tier-1 stripped -> the same corpus scores CLEAN (no older class is catching it)" \
    || bad "  MUTANT run still flagged it — an older class is matching this seed and Class 1c is unproven"
fi

# --- Assertion 12n: a legitimately REWORDED grant is not a violation ---------
# The near-miss half. Different placeholder letter, different bullet order,
# different prose: the permitted form is still exhibited and the block is clean.
# Without this the arm could be keyed on the shipped wording and would fail every
# honest rewrite — the unmeasured lint an operator turns off.
fresh
cat > "$WORK/t/$RA" <<'EOF'
# Rule authoring
Rules are imperative.

**Style:**

- No sprint or story references.
- Carry a citable name in the rule's own heading: `Step <k>` for a step
  section, `Rule <k>` for a rule. An identifier MUST NOT encode a sprint,
  story, version, or date.
EOF
has 'IDENTIFIER_GRANT: CLEAN' "$(audit)" \
  && ok "a reworded grant exhibiting the same form -> still CLEAN" \
  || bad "the arm is keyed on the shipped wording rather than on the permitted form"

# --- Assertion 12o: no **Style:** block at all -> FLAGGED, for THAT reason ----
# Asserted on the reason, not the code. Deleting the block is the cheapest way to
# silence a check that reads inside it, and a finding that did not name the cause
# would send the reader looking for a missing bullet in a block that is gone.
fresh
cat > "$WORK/t/$RA" <<'EOF'
# Rule authoring
Rules are imperative.
EOF
out="$(audit)"
has 'no `\*\*Style:\*\*` block' "$out" \
  && ok "no Style block -> FLAGGED naming the absent block, not an absent bullet" \
  || bad "a rule-authoring.md with no Style block did not report the missing block as the cause"

# --- Assertion 12p: no subject -> N/A, never CLEAN ---------------------------
# A scan of nothing reporting CLEAN is the shape this whole fixture exists to
# refuse. Corpus membership is deliberately NOT this class's job — I23 in
# validate-enforcement-map.sh fails the push when a file install.sh ships is
# absent from `--list` — so the honest report here is N/A naming that arm.
fresh
rm -f "$WORK/t/$RA"
out="$(audit)"
if has 'IDENTIFIER_GRANT: N/A' "$out" && ! has 'IDENTIFIER_GRANT: CLEAN' "$out"; then
  ok "subject absent -> IDENTIFIER_GRANT N/A (not a silent CLEAN)"
else
  bad "with no rule-authoring.md the class reported CLEAN — a scan of nothing reading as a scan that passed"
fi

# --- Assertion 12g: the two thresholds differ, and NEITHER goes silent ------
# A tier-2-only corpus: the push is not gated, the retro still sees the finding.
fresh
echo 'The lead MUST retry, because we lost a sprint to this.' >> "$WORK/t/CLAUDE.md"
out="$(audit)"
if [ "$(rc_of "$AUDIT")" = "1" ] \
   && [ "$(rc_of "$AUDIT" --fail-on=deterministic)" = "0" ] \
   && has 'NARRATIVE_DRIFT: FLAGGED' "$out"; then
  ok "tier-2-only finding -> default exit 1, deterministic exit 0, still printed"
else
  bad "the tier split is wrong: a judgement finding must not gate the push, and must never go unprinted"
fi
out="$( cd "$WORK/t" && bash "$AUDIT" --fail-on=deterministic 2>&1 )"
has 'NARRATIVE_DRIFT: FLAGGED' "$out" \
  && ok "  and --fail-on=deterministic still PRINTS the tier-2 finding" \
  || bad "  but --fail-on=deterministic suppressed the tier-2 finding — a silent tier is the defect this audit exists to find"

# --- Assertion 12h: Class 2 sees a directive that wraps ---------------------
# The live shape it could not see: the primary directive says SHOULD and the
# MUST that qualifies it sits two lines down, so a per-line predicate scored the
# weakest sentence in the rulebook as clean.
fresh
cat >> "$WORK/t/.claude/team-roles/dev.md" <<'EOF'

Large read-only command output should be routed through the offload tool so its
bytes stay out of the resident prefix. Two hard limits: state-mutating commands
MUST run natively, and verbatim-load files MUST NOT be routed through it.
EOF
out="$(audit)"; has 'RULE_WEAKNESS: FLAGGED' "$out" \
  && ok "soft directive whose MUST wraps to a later line -> RULE_WEAKNESS FLAGGED" \
  || bad "Class 2 is still line-scoped — a wrapped mandate stays invisible"

# --- Assertion 12i: 'should be' is not exempt -------------------------------
fresh
echo 'The evidence should be attached before the gate; a gap is a violation.' \
  >> "$WORK/t/.claude/team-roles/dev.md"
out="$(audit)"; has 'RULE_WEAKNESS: FLAGGED' "$out" \
  && ok "'should be' beside a mandate -> FLAGGED (canonical soft-mandate form)" \
  || bad "'should be' was exempted — the scan is blind to the shape Rule 18 names first"

# --- Assertion 12j: a 26(c) block with NO fields at all is DETECTED ---------
# Anchoring Class 1b on 'Failure caught:' made the emptiest blocks the only ones
# it could not see: a block supplying none of the three has nothing to anchor on.
fresh
cat >> "$WORK/t/.claude/skills/ai-dlc/steps/example.md" <<'EOF'

## Minimum mechanism (Rule 26(c))

This gate exists to keep the outcome recorded and the sprint honest.
EOF
out="$(audit)"; has 'INCOMPLETE_26C: FLAGGED' "$out" \
  && ok "a 26(c) block supplying none of the three fields -> FLAGGED" \
  || bad "a fieldless 26(c) block went undetected — Class 1b still anchors on a field it may lack"

# --- Assertion 12k: the corpus reaches the whole skill, not SKILL.md + steps -
# escalations.md, rule-authoring.md and core-manifest.md ship to every consumer
# and were scanned by nothing.
fresh
echo 'The lead MUST escalate; this replaced the v0.42.0 protocol.' \
  > "$WORK/t/.claude/skills/ai-dlc/escalations.md"
out="$(audit)"; has 'escalations.md.*ORIGIN_TAG' "$out" \
  && ok "escalations.md is inside the corpus" \
  || bad "escalations.md ships to every consumer and is scanned by nothing"

# ===== Class 1: `used to` — the habitual past vs a reduced passive of PURPOSE =====
#
# THE DEFECT THIS EXISTS TO CATCH, IN BOTH DIRECTIONS. `used to` sat inside the
# NARRATIVE alternation, so every reduced passive of purpose in the corpus scored
# as a rule telling the story of its own history — "a health signal used to clear
# the operation", "MUST NOT be used to satisfy a per-element AC" — text that says
# what the rule requires TODAY and nothing about what it once said. Class 1 is the
# class a lead dispositions by hand, so a false positive there is a lead reading a
# correct line, waving it through, and learning to wave the next one through too.
# The mirror is a fix that clears the false positives by acquitting the true
# habitual lines as well, and the mutants below are eight separate ways to write
# it — two of them wrong fixes BUILT and scored rather than described.
#
# EVERY SEED IS PRODUCER TEXT, never text derived from the predicate. A seed read
# off the accept-set proves the reader accepts its own grammar. The purpose shapes
# come from `steps/deploy-validate.md`, the reference consumer's
# `docs/coding-conventions.md` and one of its check extensions; the habitual ones
# from `steps/artifact-consolidation.md`, `steps/discovery.md`,
# `ai-dlc-update/SKILL.md` and `steps/stories-test-strategy.md`. `ua`, `ub` and
# `uc` are the three constructed cases the predicate's second cut was driven on:
# an article in the PREVIOUS sentence, a backticked SUBJECT, and a negation
# between the copula and the participle.
#
# TWO PURPOSE SEEDS KEEP THEIR LINE WRAP, and that is load-bearing. Prose wraps
# exactly at `MUST NOT be` / `used to satisfy`, so the words that discriminate sit
# on the PREVIOUS line and a predicate reading one line in isolation sees a
# line-initial `used to` with nothing before it. `u_h4` is the same wrap carrying a
# HABITUAL clause, so the previous-line join cannot be a blanket acquittal.
#
# THE VERDICT IS ASSERTED WITH ITS EXACT `n=[...]` LIST, never a bare FLAGGED. The
# predicate decides per LINE; a bare FLAGGED is satisfied by any other hit anywhere
# in the corpus, and the same-file arm could not be written at all.
TR=".claude/team-roles"

u_p1() { cat > "$WORK/t/$TR/up1.md" <<'EOF'
- **Liveness must be absolute, not differential.** A health signal used to
  clear the operation MUST be an absolute progress reading against an
EOF
}
u_p2() { cat > "$WORK/t/$TR/up2.md" <<'EOF'
  source-string presence check (`assertIn("method_name", body)`) MUST NOT be
  used to satisfy a per-element AC.
EOF
}
u_p3() { cat > "$WORK/t/$TR/up3.md" <<'EOF'
same data-flow term as the value under test — e.g. a TEL-denominated total
used to validate a USD total derived from the same pool tick — is a
EOF
}
u_h1() { cat > "$WORK/t/$TR/uh1.md" <<'EOF'
The step used to say nothing here, and the silence is the defect.
EOF
}
u_h2() { cat > "$WORK/t/$TR/uh2.md" <<'EOF'
Where the blocks used to sit, write a pointer.
EOF
}
u_h3() { cat > "$WORK/t/$TR/uh3.md" <<'EOF'
This paragraph used to read "pass theirs as the base".
EOF
}
u_h4() { cat > "$WORK/t/$TR/uh4.md" <<'EOF'
**The one benign difference that**
used to exist here is gone.
EOF
}
u_h5() { cat > "$WORK/t/$TR/uh5.md" <<'EOF'
  disambiguation rule when more than one matches. The per-sprint working files
  that used to collide with it now sit under `s<N>/`, out of a non-recursive
EOF
}
u_mix() { cat > "$WORK/t/$TR/umix.md" <<'EOF'
- **Liveness must be absolute, not differential.** A health signal used to
  clear the operation MUST be an absolute progress reading against an

The step used to say nothing here, and the silence is the defect.
EOF
}
# The article window must stop at a sentence boundary: `a gate.` ends a sentence
# and the habitual clause after it is a new one.
u_a() { cat > "$WORK/t/$TR/ua.md" <<'EOF'
This is not a gate. The step used to stop here.
EOF
}
# A habitual line whose SUBJECT is a backticked span. `used()` blanks it, so the
# blanked prefix is empty while the RAW prefix is not — the line is not wrapped
# and must not borrow its predecessor's verdict.
u_b() { cat > "$WORK/t/$TR/ub.md" <<'EOF'
this is a normal sentence.
`validate-mandatory-rules.sh` used to run six checks.
EOF
}
# THE SAME SHAPE WITH A PREDECESSOR THAT WOULD ACQUIT IT. `ub.md`'s previous line
# ends in a sentence period, so the article window rejects it on its own and the
# arm cannot see which rule did the work; this one ends in a bare `an`, which the
# window accepts, so only the raw-text fall-through keeps the line FLAGGED. The
# previous line is `steps/deploy-validate.md`'s own continuation line.
u_b2() { cat > "$WORK/t/$TR/ub2.md" <<'EOF'
  clear the operation MUST be an absolute progress reading against an
`validate-mandatory-rules.sh` used to run six checks.
EOF
}
# A negation between the copula and the participle is still the passive of
# purpose: this says what the nonce is FOR, not what the rule once said.
u_c() { cat > "$WORK/t/$TR/uc.md" <<'EOF'
The nonce is not used to reconcile anything.
EOF
}

# --- Assertion 12u1: purpose after a noun phrase -> CLEAN --------------------
fresh; u_p1
has 'NARRATIVE_DRIFT: CLEAN' "$(audit)" \
  && ok "'A health signal used to clear …' -> NARRATIVE_DRIFT CLEAN (purpose, not history)" \
  || bad "a reduced passive of purpose on a noun phrase scored as narrative drift"

# --- Assertion 12u2: purpose after `be`, WRAPPED -> CLEAN --------------------
# The wrap is the point: `be` is on the previous line and `used to` opens this one.
fresh; u_p2
has 'NARRATIVE_DRIFT: CLEAN' "$(audit)" \
  && ok "'MUST NOT be' / 'used to satisfy …' across a line wrap -> CLEAN" \
  || bad "a passive of purpose wrapping at 'be' / 'used to' scored as narrative drift"

# --- Assertion 12u3: purpose after an article, WRAPPED -> CLEAN -------------
fresh; u_p3
has 'NARRATIVE_DRIFT: CLEAN' "$(audit)" \
  && ok "'a TEL-denominated total' / 'used to validate …' across a wrap -> CLEAN" \
  || bad "a reduced relative wrapping onto a line-initial 'used to' scored as drift"

# --- Assertion 12u4-12u8: the habitual past is still DETECTED, per line ------
fresh; u_h1
has "NARRATIVE_DRIFT: FLAGGED  n=\[$TR/uh1.md:1\]" "$(audit)" \
  && ok "'The step used to say nothing here' -> FLAGGED at uh1.md:1" \
  || bad "the habitual past went undetected — the purpose carve-out swallowed Class 1"

# No tense-shift marker anywhere on this line, deliberately: the marker fix reads
# as the obvious one and this is the seed that refuses it.
fresh; u_h2
has "NARRATIVE_DRIFT: FLAGGED  n=\[$TR/uh2.md:1\]" "$(audit)" \
  && ok "'Where the blocks used to sit' (no 'now'/'no longer') -> FLAGGED at uh2.md:1" \
  || bad "a habitual line carrying no tense-shift marker was acquitted"

fresh; u_h3
has "NARRATIVE_DRIFT: FLAGGED  n=\[$TR/uh3.md:1\]" "$(audit)" \
  && ok "'This paragraph used to read …' -> FLAGGED at uh3.md:1" \
  || bad "a habitual line whose object is a quoted span was acquitted"

# Line-initial AND habitual. The previous-line join must not acquit on its own.
fresh; u_h4
has "NARRATIVE_DRIFT: FLAGGED  n=\[$TR/uh4.md:2\]" "$(audit)" \
  && ok "a line-initial habitual 'used to exist here is gone' -> FLAGGED at uh4.md:2" \
  || bad "the previous-line join acquits every line-initial 'used to', purpose or not"

fresh; u_h5
has "NARRATIVE_DRIFT: FLAGGED  n=\[$TR/uh5.md:2\]" "$(audit)" \
  && ok "'that used to collide with it now sit …' -> FLAGGED at uh5.md:2" \
  || bad "a habitual line that DOES carry 'now' was acquitted"

# --- Assertion 12u9: one purpose line and one habitual line, SAME FILE -------
# The arm that proves the predicate decides per LINE and not per FILE. Both
# clauses are in one file; only the habitual line's number may appear.
fresh; u_mix
has "NARRATIVE_DRIFT: FLAGGED  n=\[$TR/umix.md:4\]" "$(audit)" \
  && ok "purpose at umix.md:1 + habitual at umix.md:4 -> FLAGGED naming ONLY line 4" \
  || bad "a file holding both shapes reported the wrong line set — the predicate is file-scoped"

# --- Assertion 12u9a: the article window stops at a sentence boundary --------
fresh; u_a
has "NARRATIVE_DRIFT: FLAGGED  n=\[$TR/ua.md:1\]" "$(audit)" \
  && ok "'This is not a gate. The step used to stop here.' -> FLAGGED at ua.md:1" \
  || bad "an indefinite article in the PREVIOUS sentence acquitted the habitual clause after it"

# --- Assertion 12u9b: a backticked SUBJECT is not a line wrap ----------------
fresh; u_b
has "NARRATIVE_DRIFT: FLAGGED  n=\[$TR/ub.md:2\]" "$(audit)" \
  && ok "'\`validate-mandatory-rules.sh\` used to run six checks.' -> FLAGGED at ub.md:2" \
  || bad "a habitual line whose subject is a backticked span was read as a wrap and took its predecessor's verdict"

# --- Assertion 12u9c: the same shape over a predecessor that WOULD acquit ----
# The discriminating input. 12u9b is FLAGGED under either fall-through rule
# because its previous line ends in a period; this one is FLAGGED only under the
# raw-text rule, and it is the seed mutant m7 moves.
fresh; u_b2
has "NARRATIVE_DRIFT: FLAGGED  n=\[$TR/ub2.md:2\]" "$(audit)" \
  && ok "the same line over a predecessor ending in a bare 'an' -> still FLAGGED at ub2.md:2" \
  || bad "a blanked prefix fell through to the previous line and borrowed its acquittal"

# --- Assertion 12u9d: a negated passive of purpose -> CLEAN -----------------
fresh; u_c
has 'NARRATIVE_DRIFT: CLEAN' "$(audit)" \
  && ok "'The nonce is not used to reconcile anything.' -> CLEAN (negated passive)" \
  || bad "a negation between the copula and the participle broke the passive-of-purpose clause"

# ---- MUTANTS: four ways to get this wrong, scored on one combined corpus ----
# A COPY of the shipping audit, `cmp -s` guarded, pointed at the SAME seeded tree.
# Each mutant is asserted on the EXACT hit set it produces, so a mutation that
# moves a cell it does not own fails its own arm rather than passing quietly.
mkmut() { # <name> <sed script>; 0 = applied, 1 = DID NOT APPLY
  cp "$AUDIT" "$WORK/$1.pre" || return 1
  sed "$2" "$WORK/$1.pre" > "$WORK/$1.sh" || return 1
  cmp -s "$WORK/$1.pre" "$WORK/$1.sh" && return 1
  return 0
}
audit_at() { ( cd "$WORK/t" && bash "$1" 2>&1 ); }

# The mutation guard's own control. Every anchor below is unique in the audit
# script; this proves a `sed` that matched NOTHING is reported as DID NOT APPLY
# rather than scored as a mutant that changed no cell.
if mkmut umx 's/ZZZ_NO_SUCH_ANCHOR_ZZZ/x/'; then
  bad "the impossible-anchor control APPLIED — mkmut cannot tell a live mutation from a no-op"
else
  ok "mutation guard: an impossible anchor reports DID NOT APPLY"
fi

fresh; u_p1; u_p2; u_p3; u_h1; u_h2; u_h3; u_h4; u_h5; u_a; u_b; u_b2; u_c
HAB="$TR/uh1.md:1,$TR/uh2.md:1,$TR/uh3.md:1,$TR/uh4.md:2,$TR/uh5.md:2"
ALLHITS="$TR/ua.md:1,$TR/ub.md:2,$TR/ub2.md:2,$HAB"
WITHUC="$TR/ua.md:1,$TR/ub.md:2,$TR/ub2.md:2,$TR/uc.md:1,$HAB"

# --- Assertion 12u10: UNMUTATED CONTROL, with a positive conjunct ------------
# Not "nothing went wrong": the eight habitual lines must be THERE and the four
# purpose lines must NOT, or a subject replaced by `exit 0` scores every mutant
# below as a kill.
has "NARRATIVE_DRIFT: FLAGGED  n=\[$ALLHITS\]" "$(audit)" \
  && ok "CONTROL: 4 purpose + 8 habitual in one corpus -> exactly the 8 habitual lines" \
  || bad "the unmutated control did not produce the baseline hit set — every mutant below is unreadable"

# --- Assertion 12u11: m1, the OLD grammar restored --------------------------
# `used to\b` back inside NARRATIVE, which is what the audit did before the split.
if mkmut um1 's/|measured:|/|measured:|used to\\b|/'; then
  has "NARRATIVE_DRIFT: FLAGGED  n=\[$WITHUC,$TR/up1.md:1,$TR/up2.md:2,$TR/up3.md:2\]" "$(audit_at "$WORK/um1.sh")" \
    && ok "MUTANT m1 (old NARRATIVE grammar) -> all four purpose lines flip to FLAGGED; killed" \
    || bad "MUTANT m1 restored 'used to' to NARRATIVE and no purpose arm moved — 12u1-12u3 prove nothing"
else
  bad "MUTANT m1 DID NOT APPLY — its anchor moved; 12u1-12u3 are unproven"
fi

# --- Assertion 12u12: m2, the tense-marker wrong fix -------------------------
# The fix the audit's own comment records as scored and rejected: require
# "now"/"no longer" on the line. It clears the same purpose sites AND silences
# every habitual line that does not announce its own tense shift.
if mkmut um2 's#^            return True$#            return bool(re.search(r"\\bnow\\b|\\btoday\\b|\\bcurrently\\b|no longer", t, re.I))#'; then
  has "NARRATIVE_DRIFT: FLAGGED  n=\[$TR/uh5.md:2\]" "$(audit_at "$WORK/um2.sh")" \
    && ok "MUTANT m2 (tense marker required) -> seven habitual lines go CLEAN, only 'now' survives; killed" \
    || bad "MUTANT m2 required a tense-shift marker and the habitual arms did not move — 12u4-12u8 prove nothing"
else
  bad "MUTANT m2 DID NOT APPLY — its anchor moved; 12u4-12u8 are unproven"
fi

# --- Assertion 12u13: m3, the predicate acquits everything -------------------
# uh5 is what separates m3 from m2: it carries "now", so m2 keeps it and m3 does
# not. Without that seed the two mutants have one footprint and neither is proven.
if mkmut um3 's#^            return True$#            return False#'; then
  has 'NARRATIVE_DRIFT: CLEAN' "$(audit_at "$WORK/um3.sh")" \
    && ok "MUTANT m3 (habitual_used_to always False) -> every habitual line goes CLEAN; killed" \
    || bad "MUTANT m3 acquitted every line and Class 1 still flagged — some other pattern is catching the seeds"
else
  bad "MUTANT m3 DID NOT APPLY — its anchor moved; 12u4-12u8 are unproven"
fi

# --- Assertion 12u14: m4, the previous-line join removed --------------------
# Owns BOTH wrapped purpose seeds: they are one property, and a mutant that moved
# only one of them would mean the other arm is reading something else.
if mkmut um4 's#            before = used(prev)#            before = ""#'; then
  has "NARRATIVE_DRIFT: FLAGGED  n=\[$ALLHITS,$TR/up2.md:2,$TR/up3.md:2\]" "$(audit_at "$WORK/um4.sh")" \
    && ok "MUTANT m4 (previous-line join removed) -> both WRAPPED purpose lines flip, up1 and uc do not; killed" \
    || bad "MUTANT m4 dropped the previous-line join and the wrapped arms did not move — 12u2/12u3 prove nothing"
else
  bad "MUTANT m4 DID NOT APPLY — its anchor moved; 12u2/12u3 are unproven"
fi

# --- Assertion 12u15: m5, the WRONG FIX, built rather than described ---------
# The plausible over-wide fix: acquit on ANY article rather than an indefinite
# one. It clears all three purpose sites, which is what makes it look finished,
# and takes "The step used to" and "the blocks used to" with it. Seeding the
# absent fix proves the arms fire; seeding the WRONG one proves they discriminate.
if mkmut um5 's#(a|an)#(a|an|the)#'; then
  has "NARRATIVE_DRIFT: FLAGGED  n=\[$TR/ub.md:2,$TR/ub2.md:2,$TR/uh3.md:1,$TR/uh4.md:2,$TR/uh5.md:2\]" "$(audit_at "$WORK/um5.sh")" \
    && ok "MUTANT m5 (definite article acquits too) -> ua, uh1 and uh2 go CLEAN; killed" \
    || bad "MUTANT m5 widened the article class and no habitual arm moved — the a/an narrowing is unbound"
else
  bad "MUTANT m5 DID NOT APPLY — its anchor moved; the article narrowing is unproven"
fi

# --- Assertion 12u16: m6, the OTHER wrong fix, also built -------------------
# "The word before it looks like a noun, so this is a reduced relative": both
# clauses replaced by a lowercase-word test. It fails in BOTH directions at once,
# which is why it needs seeds on both sides — it FLAGS the wrapped `be` purpose
# site (`be` is two letters, not a noun) and ACQUITS `The step used to`,
# `the blocks used to` and `This paragraph used to`, whose preceding words are
# nouns. Only the seeds whose cue ends in punctuation or in a blank survive it.
if mkmut um6 $'s#.*am|is|are.*#    r"([a-z]{3,}\\\\s*$)", re.I)#\n/directly|solely/d\n/explicitly|first/d\n/(a|an)/d'; then
  has "NARRATIVE_DRIFT: FLAGGED  n=\[$TR/ub.md:2,$TR/ub2.md:2,$TR/uh4.md:2,$TR/up2.md:2\]" "$(audit_at "$WORK/um6.sh")" \
    && ok "MUTANT m6 (noun-looking token before) -> up2 flips AND uh1/uh2/uh3/ua go CLEAN; killed" \
    || bad "MUTANT m6 replaced the two clauses with a noun heuristic and nothing moved — the clause split is unbound"
else
  bad "MUTANT m6 DID NOT APPLY — its anchor moved; the clause split is unproven"
fi

# --- Assertion 12u17: m7, the fall-through decided on BLANKED text ----------
# The state before the raw-text fix: a line whose only prefix is a backticked
# subject reads as line-initial and borrows the previous line's verdict. It moves
# exactly one cell, ub2, which is why ub2 had to be seeded — ub is FLAGGED under
# both rules and could never have shown this.
if mkmut um7 's#if not text#if not before#'; then
  has "NARRATIVE_DRIFT: FLAGGED  n=\[$TR/ua.md:1,$TR/ub.md:2,$HAB\]" "$(audit_at "$WORK/um7.sh")" \
    && ok "MUTANT m7 (fall-through on blanked text) -> ub2 alone goes CLEAN; killed" \
    || bad "MUTANT m7 restored the blanked-prefix fall-through and no arm moved — 12u9c proves nothing"
else
  bad "MUTANT m7 DID NOT APPLY — its anchor moved; 12u9c is unproven"
fi

# --- Assertion 12u18: m8, the adverb allowance removed ----------------------
# A copula with a negation between it and the participle is still a passive.
# Deleting the allowance moves exactly one cell, uc.
if mkmut um8 $'/directly|solely/d\ns#.*explicitly|first.*#    r"\\\\s*$"#'; then
  has "NARRATIVE_DRIFT: FLAGGED  n=\[$WITHUC\]" "$(audit_at "$WORK/um8.sh")" \
    && ok "MUTANT m8 (no adverb between copula and participle) -> uc alone flips to FLAGGED; killed" \
    || bad "MUTANT m8 removed the adverb allowance and uc did not flip — 12u9d proves nothing"
else
  bad "MUTANT m8 DID NOT APPLY — its anchor moved; 12u9d is unproven"
fi

# ========================= validate-gate-manifest.sh ========================

# --- Assertion 13: SANITY — a consistent manifest resolves ------------------
fresh
[ "$(rc_of "$MANIFEST" "$GV")" = "0" ] \
  && ok "consistent manifest + anchors -> exit 0" \
  || bad "the control gate-validation.md did not resolve"

# --- Assertion 14: a manifest id with no anchor -> MISSING ------------------
fresh
sed -i.bak 's/| retro     | 3 |/| retro     | 3, 99 |/' "$WORK/t/$GV" && rm -f "$WORK/t/$GV.bak"
out="$(manifest)"
has 'MISSING (manifest id, no anchor): 99' "$out" \
  && ok "manifest names check 99 with no anchor -> MISSING 99" \
  || bad "manifest drift (id with no anchor) went undetected"
[ "$(rc_of "$MANIFEST" "$GV")" = "1" ] && ok "  and exit 1" || bad "  but exit was not 1"

# --- Assertion 15: an anchor no row claims -> ORPHAN ------------------------
fresh
printf '\n### 4. Fourth\n<!-- CHECK_LOADED: 4 -->\n' >> "$WORK/t/$GV"
grep -q 'ORPHAN  (anchor, no manifest claim): 4' <<<"$(manifest)" \
  && ok "an anchor no manifest row claims -> ORPHAN 4" \
  || bad "drift in the anchor->manifest direction went undetected"

# --- Assertion 16: zero parseable rows -> exit 2, FOR THAT REASON -----------
# Asserted on the reason, not the code alone. `not rows` implies `no universal
# row`, so a bare exit-2 assertion here passes off the universal guard and the
# zero-rows guard stays unbound — denied for the wrong reason reads exactly like
# denied for the right one.
fresh
perl -0pi -e 's/\| universal \| 1, 2 \|\n\| retro     \| 3 \|\n//' "$WORK/t/$GV"
out="$(manifest)"; rc="$(rc_of "$MANIFEST" "$GV")"
if [ "$rc" = "2" ] && grep -q 'parsed zero rows' <<<"$out"; then
  ok "manifest with zero rows -> exit 2, reason 'parsed zero rows'"
else
  bad "zero-row manifest exited $rc / wrong reason — it can pass by comparing nothing"
fi

# --- Assertion 17: no universal row -> exit 2, FOR THAT REASON -------------
fresh
perl -0pi -e 's/\| universal \| 1, 2 \|\n//' "$WORK/t/$GV"
out="$(manifest)"; rc="$(rc_of "$MANIFEST" "$GV")"
if [ "$rc" = "2" ] && grep -q "no 'universal' row" <<<"$out"; then
  ok "manifest with rows but no universal row -> exit 2, reason 'no universal row'"
else
  bad "a manifest missing its always-loaded set exited $rc / wrong reason"
fi

# --- Assertion 18: no anchors at all -> exit 2 ------------------------------
fresh
sed -i.bak '/CHECK_LOADED/d' "$WORK/t/$GV" && rm -f "$WORK/t/$GV.bak"
rc="$(rc_of "$MANIFEST" "$GV")"
[ "$rc" = "2" ] \
  && ok "a file with no CHECK_LOADED anchors -> exit 2" \
  || bad "a file with no anchors exited $rc instead of refusing to resolve"

# ============ validate-gate-manifest.sh, THROUGH THE RULE 27 LAYERS ==========
#
# Assertions 13-18 all drive a PURE-CORE tree, and every one of them passes
# against the pre-v0.177.0 script that read core and nothing else. That is the
# defect: on a consumer whose manifest lives in an `overrides/` entry, the table
# this script resolved was not the table the lead loaded, and the resolve reported
# PASS on it. The cases below are the ones a core-only reader cannot answer.

LAYERS=".claude/skills/ai-dlc"

# The override's `shadows:` anchor must name the section heading the manifest
# sits under IN THE SEEDED CORPUS (`# Gate validation`) — the join is derived from
# the file, so a fixture that hard-codes core's real heading would test nothing.
ovr() { # <basename> <shadows-value>; body on stdin
  mkdir -p "$WORK/t/$LAYERS/overrides"
  { printf -- '---\nshadows: %s\nbase_sha: abc1234\nreason: fixture entry\n---\n\n' "$2"
    cat; } > "$WORK/t/$LAYERS/overrides/$1"
}
ext() { # <basename> <hooks-value> [<extra-frontmatter-line>]; body on stdin
  mkdir -p "$WORK/t/$LAYERS/extensions"
  { printf -- '---\nkind: check\nhooks: %s\nid: %s\n' "$2" "${1%.md}"
    if [ -n "${3:-}" ]; then printf -- '%s\n' "$3"; fi
    printf -- '---\n\n'
    cat; } > "$WORK/t/$LAYERS/extensions/$1"
}
# The override table core does not have: `34` joins the retro row.
ovr_manifest() {
  ovr manifest.md 'steps/gate-validation.md#Gate validation' <<'EOF'
# Gate validation — CONSUMER OVERRIDE

<!-- GATE_MANIFEST v1
| gate type | checks |
|-----------|--------|
| universal | 1, 2 |
| retro     | 3, 34 |
GATE_MANIFEST_END -->
EOF
}

# --- Assertion 19: the OVERRIDE's table is the one resolved ------------------
fresh
ovr_manifest
ext check-34.md 'steps/gate-validation.md' <<'EOF'
### 34. Protected core paths
<!-- CHECK_LOADED: 34 -->
EOF
out="$(manifest)"; rc="$(rc_of "$MANIFEST" "$GV")"
if [ "$rc" = "0" ] && has 'manifest source: overrides/manifest.md' "$out"; then
  ok "an overrides/ entry shadowing the manifest section supplies the table -> exit 0, attributed"
else
  bad "the resolve did not use the override's table (rc=$rc) — it validated a table nobody loads"
fi
has 'anchor sources: core(3) + extensions(1) + overrides(0) = 4 unique' "$out" \
  && ok "  and the extension's anchor is in the pool" \
  || bad "  but the extension's anchor was not counted — 34 would report MISSING"

# --- Assertion 20: the SAME tree, minus the extension's anchor -> MISSING ----
# Binds 19 to that exact anchor. Without this, 19 passes for any reason that
# happens to produce exit 0.
fresh
ovr_manifest
ext check-34.md 'steps/gate-validation.md' <<'EOF'
### 34. Protected core paths
<!-- CHECK_LOADED: 34 -->
EOF
E="$WORK/t/$LAYERS/extensions/check-34.md"
cp "$E" "$E.pre"
grep -v '^<!-- CHECK_LOADED: 34 -->$' "$E.pre" > "$E"
if cmp -s "$E" "$E.pre"; then
  bad "assertion 20's mutation matched nothing — the case below is vacuous"
else
  rm -f "$E.pre"
  out="$(manifest)"; rc="$(rc_of "$MANIFEST" "$GV")"
  if [ "$rc" = "1" ] && has 'MISSING (manifest id, no anchor): 34' "$out"; then
    ok "override claims 34, no layer defines its anchor -> MISSING 34, exit 1"
  else
    bad "a claimed-but-unloadable check exited $rc — the exact S305 consumer failure"
  fi
fi

# --- Assertion 21: an extension anchor no rendered row claims -> ORPHAN ------
fresh
ovr_manifest
ext check-34.md 'steps/gate-validation.md' <<'EOF'
### 34. Protected core paths
<!-- CHECK_LOADED: 34 -->

### 35. Unclaimed
<!-- CHECK_LOADED: 35 -->
EOF
out="$(manifest)"
has 'ORPHAN  (anchor, no manifest claim): 35' "$out" \
  && ok "an extension check no rendered row claims -> ORPHAN 35" \
  || bad "an unloadable extension check went undetected in the anchor->manifest direction"

# --- Assertion 22: two shadowing tables -> exit 2, FOR THAT REASON -----------
# Asserted on the reason: picking one silently would make every PASS above
# unattributable, and a bare exit-2 assertion cannot tell that apart from 23.
fresh
ovr_manifest
ovr second.md 'steps/gate-validation.md' <<'EOF'
<!-- GATE_MANIFEST v1
| gate type | checks |
|-----------|--------|
| universal | 1 |
GATE_MANIFEST_END -->
EOF
out="$(manifest)"; rc="$(rc_of "$MANIFEST" "$GV")"
if [ "$rc" = "2" ] && has 'two or more overrides/ entries each carry a' "$out"; then
  ok "two overrides each carrying a manifest -> exit 2, reason 'undecidable'"
else
  bad "an undecidable effective table exited $rc / wrong reason"
fi

# --- Assertion 23: the section shadowed AWAY -> exit 2, FOR THAT REASON ------
fresh
ovr gone.md 'steps/gate-validation.md#Gate validation' <<'EOF'
# Gate validation — CONSUMER OVERRIDE

This consumer replaced the section with prose and no table.
EOF
out="$(manifest)"; rc="$(rc_of "$MANIFEST" "$GV")"
if [ "$rc" = "2" ] && has 'replaces the manifest section' "$out"; then
  ok "an override that shadows the section away -> exit 2, not core's table"
else
  bad "the rendered document has no manifest at all and the scan exited $rc"
fi

# ============ gate_types: AND THE CHECK THAT FALLS BETWEEN BOTH ARMS =========
#
# Assertions 14/15 cover a manifest id with no anchor (MISSING) and an anchor no
# row claims (ORPHAN). A check DEFINED only as a heading has NEITHER, so it is in
# neither set and the resolve reports PASS. Measured on the reference consumer at
# 0.196.0: four such checks (`19b`, `2s`, `35`, and the retired tombstone `33`),
# each with a real Scope line, none of which had ever run — while this script
# printed `MISSING none / ORPHAN none / PASS`.

# --- Assertion 24: a heading with no anchor and no row -> UNLOADABLE ----------
fresh
ovr_manifest
ext check-34.md 'steps/gate-validation.md' <<'EOF'
### 34. Protected core paths
<!-- CHECK_LOADED: 34 -->

### 35. Defined and unreachable
EOF
out="$(manifest)"; rc="$(rc_of "$MANIFEST" "$GV")"
if [ "$rc" = "1" ] && has 'UNLOADABLE (check heading, no anchor and no row): 35' "$out"; then
  ok "a check defined as a heading with no anchor and no row -> UNLOADABLE 35, exit 1"
else
  bad "a check that can never load exited $rc and was reported by neither MISSING nor ORPHAN"
fi
has 'MISSING (manifest id, no anchor): none' "$out" \
  && ok "  and it is NOT reported as MISSING — that arm needs a manifest row" \
  || bad "  but MISSING also fired, so assertion 24 cannot say which arm caught it"

# --- Assertion 25: the SAME tree, minus that heading -> silent ----------------
# Binds 24 to the heading itself. Without it, 24 passes for any reason producing
# exit 1, and the ORPHAN arm one assertion up already produces exit 1.
fresh
ovr_manifest
ext check-34.md 'steps/gate-validation.md' <<'EOF'
### 34. Protected core paths
<!-- CHECK_LOADED: 34 -->

### 35. Defined and unreachable
EOF
E="$WORK/t/$LAYERS/extensions/check-34.md"
cp "$E" "$E.pre"
grep -v '^### 35\. Defined and unreachable$' "$E.pre" > "$E"
if cmp -s "$E" "$E.pre"; then
  bad "assertion 25's mutation matched nothing — assertion 24 is unproven"
else
  rm -f "$E.pre"
  out="$(manifest)"
  has 'UNLOADABLE (check heading, no anchor and no row): none' "$out" \
    && ok "removing the heading clears UNLOADABLE — 24 is bound to that heading" \
    || bad "UNLOADABLE still fires with the heading gone, so 24 proved something else"
fi

# --- Assertion 26: gate_types: claims the check with NO override -------------
# THE POINT OF THE KEY. Core's table, no shadowing entry, and the extension's
# check is still claimed — which is what makes the reference consumer's 130-line
# manifest override deletable rather than re-authorable.
fresh
ext check-34.md 'steps/gate-validation.md' 'gate_types: retro' <<'EOF'
### 34. Protected core paths
<!-- CHECK_LOADED: 34 -->
EOF
out="$(manifest)"; rc="$(rc_of "$MANIFEST" "$GV")"
if [ "$rc" = "0" ] && has 'manifest source: core' "$out" && has 'extension gate_types: 34->retro' "$out"; then
  ok "gate_types: claims an extension check against CORE's table -> exit 0, attributed"
else
  bad "gate_types: did not register the check (rc=$rc) — the override stays the only route"
fi
has 'ORPHAN  (anchor, no manifest claim): none' "$out" \
  && ok "  and the anchor is no longer an orphan" \
  || bad "  but the anchor still reports as an orphan, so the claim did not land"

# --- Assertion 27: the SAME tree, minus the declaration -> ORPHAN ------------
# Binds 26 to `gate_types:` and not to the mere absence of an override.
fresh
ext check-34.md 'steps/gate-validation.md' 'gate_types: retro' <<'EOF'
### 34. Protected core paths
<!-- CHECK_LOADED: 34 -->
EOF
E="$WORK/t/$LAYERS/extensions/check-34.md"
cp "$E" "$E.pre"
grep -v '^gate_types: retro$' "$E.pre" > "$E"
if cmp -s "$E" "$E.pre"; then
  bad "assertion 27's mutation matched nothing — assertion 26 is unproven"
else
  rm -f "$E.pre"
  out="$(manifest)"
  has 'ORPHAN  (anchor, no manifest claim): 34' "$out" \
    && ok "dropping gate_types: returns the check to ORPHAN — 26 is bound to the key" \
    || bad "the check stayed claimed without gate_types:, so 26 proved nothing"
fi

# --- Assertion 28: a gate type the rendered manifest has no row for ----------
# Asserted on THIS arm's wording. Three arms emit the GM2 preamble, and an
# assertion on the shared sentence would pass against any of the other two.
fresh
ext check-34.md 'steps/gate-validation.md' 'gate_types: nosuchtype' <<'EOF'
### 34. Protected core paths
<!-- CHECK_LOADED: 34 -->
EOF
out="$(manifest)"; rc="$(rc_of "$MANIFEST" "$GV")"
if [ "$rc" = "2" ] && has 'which the rendered manifest has no row for' "$out"; then
  ok "gate_types: naming a type with no row -> exit 2, reason 'no row for'"
else
  bad "a check filed under a nonexistent gate type exited $rc — it would never load"
fi

# --- Assertion 29: a declaration with no anchor to file ----------------------
fresh
ext check-34.md 'steps/gate-validation.md' 'gate_types: retro' <<'EOF'
### 34. Protected core paths
EOF
out="$(manifest)"; rc="$(rc_of "$MANIFEST" "$GV")"
if [ "$rc" = "2" ] && has 'carries no' "$out" && has 'claims loading for nothing' "$out"; then
  ok "gate_types: with no CHECK_LOADED anchor -> exit 2, reason 'claims loading for nothing'"
else
  bad "a declaration with no check id to file exited $rc"
fi

# --- Assertion 30: a declaration on an entry hooking another file ------------
fresh
ext elsewhere.md 'steps/retro.md' 'gate_types: retro' <<'EOF'
### 41. Somewhere else entirely
<!-- CHECK_LOADED: 41 -->
EOF
out="$(manifest)"; rc="$(rc_of "$MANIFEST" "$GV")"
if [ "$rc" = "2" ] && has "not 'steps/gate-validation.md'" "$out"; then
  ok "gate_types: on an entry hooking another file -> exit 2, reason 'not this file'"
else
  bad "a declaration against a file carrying no manifest exited $rc"
fi

# --- Assertion 31: UNMUTATED CONTROL — empty layer dirs change nothing -------
# Without this, every assertion above is consistent with a script that reports
# something different the moment `overrides/` merely EXISTS, and the seeded corpus
# creates it empty.
fresh
layered="$(manifest)"
rm -rf "${WORK:?}/t/$LAYERS/overrides" "${WORK:?}/t/$LAYERS/extensions"
unlayered="$(manifest)"
if [ "$layered" = "$unlayered" ] && has 'manifest source: core' "$layered"; then
  ok "empty layer dirs resolve byte-identically to no layer dirs, source 'core'"
else
  bad "an EMPTY overrides/ or extensions/ changed the resolve — the layered assertions above measure the wrong thing"
fi


# ======================= OWNERSHIP SPLIT (BL-193) ===========================
# A consumer cannot fix a core file -- Rule 27 forbids it and `apply` restores
# it -- so a finding in one must not fail that consumer's gate while its ONLY
# compliant remedy is a write it may not perform. Every finding carries an
# owner, and `--fail-on=local` gates on the half the reader can act on.
#
# THE FOUR WORLDS BELOW ARE ONE PROPERTY APART EACH, deliberately: clean,
# core-offender-only, plus-local-offender, and resolver-absent. A build that
# gets ownership wrong fails exactly one of them, which is what makes the set
# diagnostic rather than merely red.

# --- Assertion 25: a CORE-owned finding does NOT fail --fail-on=local --------
# The motivating case, measured on the reference consumer: 32 findings, 32 of
# them core-owned, and a retro that could clear none of them.
fresh
printf 'The lead MUST retry, because we lost a sprint to this.\n' >> "$WORK/t/.claude/skills/ai-dlc/SKILL.md"
out="$(audit)"
rc_local="$(rc_of "$AUDIT" --fail-on=local)"
if [ "$rc_local" = "0" ] && has '\[core\] .claude/skills/ai-dlc/SKILL.md' "$out"; then
  ok "a CORE-owned finding is tagged [core] and does NOT fail --fail-on=local"
else
  bad "a core-owned finding failed the local gate (rc=$rc_local) — the consumer is gated on a file it may not edit"
fi

# --- Assertion 26: and it is STILL REPORTED, at full volume ------------------
# The whole risk of this change is that it becomes a quieter audit. The core
# half must print, enumerated, or the finding is lost rather than routed.
if has 'NARRATIVE_DRIFT: FLAGGED' "$out" && has 'core 1 / local 0' "$out"; then
  ok "  and it still PRINTS, FLAGGED, with the split enumerated"
else
  bad "  but the core finding stopped being reported — routing requires it be visible"
fi

# --- Assertion 27: a LOCAL-owned finding DOES fail --fail-on=local -----------
# The discriminating input. Same corpus, same class, one property different:
# the file is the consumer's own. Without this arm, assertion 25 is satisfied
# by a gate that never fails at all.
fresh
printf 'The dev MUST comply, because we lost a sprint to this.\n' >> "$WORK/t/docs/coding-conventions.md"
out="$(audit)"
rc_local="$(rc_of "$AUDIT" --fail-on=local)"
if [ "$rc_local" = "1" ] && has '\[local\] docs/coding-conventions.md' "$out"; then
  ok "a LOCAL-owned finding is tagged [local] and DOES fail --fail-on=local"
else
  bad "a locally-owned finding did not fail the local gate (rc=$rc_local) — the gate cannot fire"
fi

# --- Assertion 28: an UNRESOLVED owner fails CLOSED --------------------------
# Ownership decides whether a finding gates, so a resolver that cannot answer
# must never be able to ACQUIT. Measured while building this fix: with the
# resolver removed, every finding scored `unknown` and the gate exited 0 over a
# 32-finding corpus -- a clean sheet, which is the false clean `--is-core`'s own
# exit-2 contract exists to prevent.
#
# The resolver is copied to a scratch dir and REMOVED there, never from the real
# tree: the audit finds it beside itself, so a sibling copy is the only way to
# express its absence without mutating the distribution.
fresh
SB="$WORK/nores"
rm -rf "$SB"; mkdir -p "$SB"
cp "$AUDIT" "$SB/audit-rule-files.sh"
if [ -f "$SB/core-paths.sh" ]; then
  bad "FIXTURE BROKEN — the scratch dir was seeded with a resolver, so the absent-resolver world is not the world under test"
else
  printf 'The lead MUST retry, because we lost a sprint to this.\n' >> "$WORK/t/.claude/skills/ai-dlc/SKILL.md"
  out_nr="$( cd "$WORK/t" && bash "$SB/audit-rule-files.sh" 2>&1 )"
  rc_nr="$( cd "$WORK/t" && bash "$SB/audit-rule-files.sh" --fail-on=local >/dev/null 2>&1; echo $? )"
  if [ "$rc_nr" = "1" ] && has 'unresolved 1' "$out_nr"; then
    ok "an UNRESOLVED owner counts as local and FAILS — a missing resolver cannot acquit"
  else
    bad "with no resolver the local gate returned rc=$rc_nr — an unresolvable owner acquitted the tree"
  fi
  # The control that makes the arm above readable: the SAME scratch copy, with
  # the resolver restored beside it, must go back to 0. Without this, "rc=1 with
  # no resolver" is equally consistent with a copy that simply cannot run.
  cp "$RESOLVER" "$SB/core-paths.sh"
  rc_ok="$( cd "$WORK/t" && bash "$SB/audit-rule-files.sh" --fail-on=local >/dev/null 2>&1; echo $? )"
  [ "$rc_ok" = "0" ] \
    && ok "  control: the same copy with the resolver restored returns 0 — the rc=1 above was the ABSENCE, not a broken copy" \
    || bad "  control FAILED: the scratch copy returns rc=$rc_ok even with its resolver — assertion 28 proves nothing"
fi

# --- Assertion 29: the other two thresholds are UNCHANGED --------------------
# This change must move which findings GATE and never which are REPORTED.
# `--fail-on=any` is what a bare invocation does and what every existing caller
# outside retro relies on.
fresh
printf 'The lead MUST retry, because we lost a sprint to this.\n' >> "$WORK/t/.claude/skills/ai-dlc/SKILL.md"
rc_any="$(rc_of "$AUDIT" --fail-on=any)"
rc_det="$(rc_of "$AUDIT" --fail-on=deterministic)"
if [ "$rc_any" = "1" ] && [ "$rc_det" = "0" ]; then
  ok "--fail-on=any still fails on a tier-2 core finding; --fail-on=deterministic still passes"
else
  bad "a threshold other than local moved (any=$rc_any det=$rc_det) — the change was not confined to the new gate"
fi

# --- Assertion 30: an unknown --fail-on value is still refused ---------------
# The flag parser gained a branch; a parser that accepts anything would make
# every arm above passable by a typo that silently selects the default.
fresh
rc_bad="$(rc_of "$AUDIT" --fail-on=nonsense)"
[ "$rc_bad" = "2" ] \
  && ok "an unrecognized --fail-on value still exits 2 rather than defaulting" \
  || bad "--fail-on=nonsense returned $rc_bad, not 2 — a typo silently selects a threshold"
echo
if [ "$fails" -eq 0 ]; then echo "retro-audit-scans: PASS"; exit 0; fi
echo "retro-audit-scans: $fails assertion(s) FAILED" >&2
exit 1
