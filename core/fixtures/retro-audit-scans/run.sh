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
if [ "$rc" = "0" ] && printf '%s' "$out" | grep -q 'NARRATIVE_DRIFT: CLEAN'; then
  ok "clean corpus -> exit 0, every mechanized class CLEAN"
else
  bad "the clean control corpus did not pass (rc=$rc) — every assertion below is unreadable"
fi

# --- Assertion 1: narrative drift is DETECTED -------------------------------
fresh
echo 'The lead MUST retry, because we lost a sprint to this.' >> "$WORK/t/CLAUDE.md"
out="$(audit)"
printf '%s' "$out" | grep -q 'NARRATIVE_DRIFT: FLAGGED' \
  && ok "seeded 'because we' narrative -> NARRATIVE_DRIFT FLAGGED" \
  || bad "narrative drift went undetected — Class 1 cannot fire"
[ "$(rc_of "$AUDIT")" = "1" ] && ok "  and exit 1" || bad "  but exit was not 1"

# --- Assertion 2: a QUOTED mention is NOT drift ------------------------------
# The regression that produced 5 false positives on the reference consumer: the
# line DEFINING narrative drift was scored as narrative drift.
fresh
echo 'Rule text carrying "because we" justification is drift and FAILs the audit.' >> "$WORK/t/CLAUDE.md"
out="$(audit)"
printf '%s' "$out" | grep -q 'NARRATIVE_DRIFT: CLEAN' \
  && ok "a quoted mention of the pattern -> still CLEAN (mention is not use)" \
  || bad "the audit flagged its own definition — the quoted-span guard is gone"

# --- Assertion 3: rule weakness is DETECTED ----------------------------------
fresh
echo 'The dev should attach evidence; a missing attachment is a violation.' >> "$WORK/t/.claude/team-roles/dev.md"
printf '%s' "$(audit)" | grep -q 'RULE_WEAKNESS: FLAGGED' \
  && ok "seeded soft language beside a mandate -> RULE_WEAKNESS FLAGGED" \
  || bad "rule weakness went undetected — Class 2 cannot fire"

# --- Assertion 4: a NEGATIVE mandate is not weakness -------------------------
fresh
echo 'The dev should never merge unreviewed code; doing so is a violation.' >> "$WORK/t/.claude/team-roles/dev.md"
printf '%s' "$(audit)" | grep -q 'RULE_WEAKNESS: CLEAN' \
  && ok "'should never' beside a mandate -> CLEAN (negative mandate exempt)" \
  || bad "'should never' was flagged as soft language"

# --- Assertion 5: an incomplete Rule 26(c) triple is DETECTED ---------------
fresh
cat >> "$WORK/t/.claude/skills/ai-dlc/steps/example.md" <<'EOF'

**Minimum mechanism.** Failure caught: an unrecorded outcome reaching the gate.
EOF
printf '%s' "$(audit)" | grep -q 'INCOMPLETE_26C: FLAGGED' \
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
printf '%s' "$(audit)" | grep -q 'INCOMPLETE_26C: CLEAN' \
  && ok "a complete triple wrapping across lines -> CLEAN (section-scoped)" \
  || bad "a complete Rule 26(c) triple was flagged incomplete"

# --- Assertion 7: a dangling pointer is DETECTED ----------------------------
# The live defect this scan found on its first real run.
fresh
echo 'The convention is defined in `steps/rule-authoring.md`.' \
  >> "$WORK/t/.claude/skills/ai-dlc/extensions/README.md"
printf '%s' "$(audit)" | grep -q 'DANGLING_POINTER: FLAGGED' \
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
printf '%s' "$(audit)" | grep -q 'overrides/entry.md.*DANGLING_POINTER' \
  && ok "a dangling pointer inside overrides/ is reached by the scan" \
  || bad "overrides/ is outside the pointer scan — the scope bug is back"

# --- Assertion 9: a RESOLVABLE pointer is not flagged -----------------------
fresh
echo 'Rule text lives in `rule-authoring.md` and `team-roles/dev.md`.' \
  >> "$WORK/t/.claude/skills/ai-dlc/steps/example.md"
printf '%s' "$(audit)" | grep -q 'DANGLING_POINTER: CLEAN' \
  && ok "pointers to files that exist -> CLEAN" \
  || bad "a resolvable pointer was reported dangling"

# --- Assertion 10: dormancy reports N/A, never CLEAN, with no workflows -----
fresh
printf '%s' "$(audit)" | grep -q 'PATH_DORMANCY: N/A' \
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
printf '%s' "$(audit)" | grep -q 'COMPLEXITY_ACCRETION: DID-NOT-RUN' \
  && ok "complexity accretion reports DID-NOT-RUN, never CLEAN (lead-owned)" \
  || bad "Class 3 claimed a verdict it cannot compute"

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
printf '%s' "$out" | grep -q 'MISSING (manifest id, no anchor): 99' \
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
