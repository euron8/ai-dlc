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
printf '%s' "$(manifest)" | grep -q 'ORPHAN  (anchor, no manifest claim): 4' \
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
if [ "$rc" = "2" ] && printf '%s' "$out" | grep -q 'parsed zero rows'; then
  ok "manifest with zero rows -> exit 2, reason 'parsed zero rows'"
else
  bad "zero-row manifest exited $rc / wrong reason — it can pass by comparing nothing"
fi

# --- Assertion 17: no universal row -> exit 2, FOR THAT REASON -------------
fresh
perl -0pi -e 's/\| universal \| 1, 2 \|\n//' "$WORK/t/$GV"
out="$(manifest)"; rc="$(rc_of "$MANIFEST" "$GV")"
if [ "$rc" = "2" ] && printf '%s' "$out" | grep -q "no 'universal' row"; then
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

echo
if [ "$fails" -eq 0 ]; then echo "retro-audit-scans: PASS"; exit 0; fi
echo "retro-audit-scans: $fails assertion(s) FAILED" >&2
exit 1
