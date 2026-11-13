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
# MUTANT-MATRIX um1 decides=U twins=P1
# MUTANT-MATRIX um2 decides=U twins=P1
# MUTANT-MATRIX um3 decides=U twins=P1
# MUTANT-MATRIX um4 decides=U twins=P1
# MUTANT-MATRIX um5 decides=U twins=P1
# MUTANT-MATRIX um6 decides=U twins=P1
# MUTANT-MATRIX um7 decides=U twins=P1
# MUTANT-MATRIX um8 decides=U twins=P1
# MUTANT-MATRIX umr decides=U twins=P1
# MUTANT-MATRIX uq1 decides=UQ twins=P1
# MUTANT-MATRIX uq2 decides=UQ twins=P1
# MUTANT-MATRIX uq3 decides=UQ twins=P1
# MUTANT-MATRIX uq4 decides=UQ twins=P1
# MUTANT-MATRIX uq5 decides=UQ twins=P1
# MUTANT-MATRIX uq6 decides=UQ twins=P1
# MUTANT-MATRIX uq7 decides=UQ twins=P1
# MUTANT-MATRIX uq8 decides=UQ twins=P1
# MUTANT-MATRIX uq9 decides=UQ twins=P1
# MUTANT-MATRIX uq10 decides=UQ twins=P1
# MUTANT-MATRIX uq11 decides=UQ twins=P1
# MUTANT-MATRIX uq12 decides=UQ twins=P1
# MUTANT-MATRIX uq13 decides=UQ twins=P1
# MUTANT-MATRIX uq14 decides=UQ twins=P1
# MUTANT-MATRIX uq15 decides=UQ twins=P1
# MUTANT-MATRIX uq16 decides=UQ twins=P1
# MUTANT-MATRIX uq17 decides=UQ twins=P1
# MUTANT-MATRIX umf decides=P1 twins=U
# MUTANT-MATRIX umo decides=P1 twins=U
# MUTANT-MATRIX m1 decides=D twins=P1
# MUTANT-MATRIX m2 decides=D twins=P1
# MUTANT-MATRIX tier1-strip decides=T twins=P1
# MUTANT-MATRIX grant-strip decides=G twins=P1
# MUTANT-MATRIX ld-ownerblind decides=LDc twins=- why=it edits only the exit predicate, so no class row moves in any world; LDl, LD2 and LDu read unchanged under it (measured)
# MUTANT-MATRIX ld-tierblind decides=LD2 twins=- why=it edits only the exit predicate, so no class row moves in any world; LDc, LDl and LDu read unchanged under it (measured)
# MUTANT-MATRIX ld-unresdrop decides=LDu twins=- why=it edits only the t1-local counter, so no class row moves in any world; LDc, LDl and LD2 read unchanged under it (measured)
# MUTANT-MATRIX hook-det decides=HKc twins=- why=it edits only the consumer hook argv; the receipt's local-t1 and local-t2 cells read unchanged under it (measured)
# MUTANT-MATRIX-REMEASURE bash core/fixtures/retro-audit-scans/run.sh --matrix
# Names above are WORLDS, the same tokens the MATRIX-ROW lines print: U the used-to corpus, UQ the clause-opening used-to corpus, P1 the tier-2
# corpus, T the tier-1 origin corpus, G the identifier-grant corpus, D the distribution tree; LDc, LDl, LD2 and LDu
# the four --fail-on=local-deterministic worlds, HKc the whole consumer hook's core-owned tier-1 cell. A twin is a world
# where the mutant changes no class row (0 in its row), driven every push beside the deciding world.
# Measured co-trips, stated plainly: tier1-strip and grant-strip are ONE env switch (AI_DLC_AUDIT_MUTANT=1)
# that strips every tier-1 class, so each moves T, G and D; each is DECIDED by the world whose arm scores it
# (T by 12f, G by 12m) and its other two dead worlds are the same fault seen again, not separate kills.
# Every other mutant changes rows in exactly its deciding world. The matrix is re-measured as
# .claude/rules/fixture-mutants.md clause 2 ("One run per distinct state") requires. Run the command
# above. A plain run never drives a matrix-only cell.
set -uo pipefail
# Clear every inherited AI_DLC_* tunable and CLAUDE_PROJECT_DIR so a bare run judges the code, not the caller environment.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR
# The whole-hook arm (receipt-bl977.sh) git-inits a scratch consumer repo. A direct invocation from a linked
# worktree inherits GIT_DIR, and `git init` under it creates no repository and redirects every later git call onto
# the caller's index; the same five variables lib/preamble.sh unsets, scrubbed inline (scripts/validate-fixture-git-env.sh).
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

HERE="$(cd "$(dirname "$0")" && pwd)"
MATRIX=0
[ "${1:-}" = --matrix ] && MATRIX=1
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"
echo "HERMETIC-CONSUMED core/scripts/audit-rule-files.sh"
echo "HERMETIC-CONSUMED core/scripts/validate-gate-manifest.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
# Herestring, not a pipe: under `pipefail`, a `grep -q` that matches in the first
# few lines exits before the writer finishes and the pipeline reports the writer's
# SIGPIPE, so a MATCH is read as a failed assertion. Every tier-1 label prints at
# the top of the report, which is exactly where that bites.
has() { grep -q "$1" <<<"$2"; }
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

echo "retro-audit-scans:"
if [ "$MATRIX" = 1 ]; then echo "retro-audit-scans mode: FULL (--matrix)"; else echo "retro-audit-scans mode: PUSH"; fi

# A pristine copy per assertion, so one mutation never leaks into the next.
fresh() { rm -rf "$WORK/t"; cp -R "$PROJ" "$WORK/t"; }

# ONE real invocation per distinct (tree bytes, script bytes, args, mutant flag). The subject is
# the only expensive thing here (about 0.2s a call), and most arms ask two questions of one world
# (its report AND its exit code) or rebuild a world an earlier arm already scored. Both now cost
# nothing: the key is the tree's NAMES and BYTES (never mtimes, so a rebuilt identical copy hits)
# plus the script's own bytes, so a mutant copy and the real script can never share an answer.
# The "memo self-probe" arm below proves a one-byte-different world is a MISS.
MEMO="$WORK/memo"; mkdir -p "$MEMO"
# The audit finds its ownership resolver beside itself; a mutant copy built in $WORK needs one there too,
# or its rows carry a different owner tag from the real script and a row comparison reads that as a change.
cp "$RESOLVER" "$WORK/core-paths.sh"
fp() { ( cd "$1" 2>/dev/null && { LC_ALL=C find . -type f | LC_ALL=C sort | while IFS= read -r f; do printf '%s\n' "$f"; cat "$f"; done; LC_ALL=C find . -type d | LC_ALL=C sort; } | cksum ); }
runs() { awk 'END{print NR+0}' "$MEMO/runs" 2>/dev/null || echo 0; }
memo() { # <out|rc> <mutant 0|1> <dir> <script> [args...]
  local what="$1" mut="$2" dir="$3" script="$4" key o
  shift 4
  key="$( { printf '%s|%s|%s\n' "$mut" "$script" "$*"; cksum < "$script"; fp "$dir"; } | cksum )"
  key="${key// /_}"
  if [ ! -f "$MEMO/$key.rc" ]; then
    o="$( cd "$dir" && if [ "$mut" = 1 ]; then AI_DLC_AUDIT_MUTANT=1 bash "$script" "$@" 2>&1; else bash "$script" "$@" 2>&1; fi; echo "@@RC=$?" )"
    printf '%s' "${o%@@RC=*}" > "$MEMO/$key.out"
    printf '%s' "${o##*@@RC=}" > "$MEMO/$key.rc"
    echo x >> "$MEMO/runs"
  fi
  if [ "$what" = out ]; then cat "$MEMO/$key.out"; else cat "$MEMO/$key.rc"; fi
}
audit() { memo out 0 "$WORK/t" "$AUDIT" "$@"; }
manifest() { memo out 0 "$WORK/t" "$MANIFEST" .claude/skills/ai-dlc/steps/gate-validation.md; }
rc_of() { memo rc 0 "$WORK/t" "$1" "${@:2}"; }
audit_mut() { memo out 1 "$WORK/t" "$AUDIT" "$@"; }
rc_mut()    { memo rc 1 "$WORK/t" "$AUDIT" "$@"; }

GV=".claude/skills/ai-dlc/steps/gate-validation.md"

# ============================ audit-rule-files.sh ============================


T2=.claude/team-roles
SD=.claude/skills/ai-dlc/steps

# --- World W0: the clean corpus, scored ONCE. Assertions 0, 10 and 12 all read it. --------
fresh
out="$(audit)"; rc="$(rc_of "$AUDIT")"
if [ "$rc" = "0" ] && has 'NARRATIVE_DRIFT: CLEAN' "$out"; then
  ok "clean corpus -> exit 0, every mechanized class CLEAN"
else
  bad "the clean control corpus did not pass (rc=$rc) — every assertion below is unreadable"
fi
# Assertion 10: dormancy reports N/A, never CLEAN, with no workflows.
has 'PATH_DORMANCY: N/A' "$out" \
  && ok "no .github/workflows/ -> PATH_DORMANCY N/A (not a silent CLEAN)" \
  || bad "an absent workflow dir did not report N/A"
# Assertion 12: Class 3 never reports CLEAN.
has 'COMPLEXITY_ACCRETION: DID-NOT-RUN' "$out" \
  && ok "complexity accretion reports DID-NOT-RUN, never CLEAN (lead-owned)" \
  || bad "Class 3 claimed a verdict it cannot compute"

# --- Memo self-probe: the cache must be able to MISS, or every arm below reads a stale answer.
# An identical rebuilt world is a hit (no new invocation); a world one byte apart is a miss.
n0="$(runs)"; fresh; audit >/dev/null; n1="$(runs)"
fresh; audit >/dev/null; n2="$(runs)"
printf ' \n' >> "$WORK/t/CLAUDE.md"; audit >/dev/null; n3="$(runs)"
if [ "$n1" = "$n0" ] && [ "$n2" = "$n1" ] && [ "$n3" = "$((n2 + 1))" ]; then
  ok "memo self-probe: a rebuilt identical world is a hit, a one-byte-different world is a miss"
else
  bad "memo self-probe failed (runs $n0/$n1/$n2/$n3) — a cached answer could stand in for a different world"
fi

# --- Assertion 11: an EMPTY corpus fails, never passes ----------------------
# A scan of nothing reports every class CLEAN. That is the exact shape of a
# check that cannot fire, so it must exit 2 instead.
rm -rf "$WORK/t"; mkdir -p "$WORK/t"
[ "$(rc_of "$AUDIT")" = "2" ] \
  && ok "empty corpus -> exit 2 (refuses to score nothing as clean)" \
  || bad "an empty corpus did not exit 2 — the audit can pass by scanning nothing"

# ===== World P1: every TIER-2 seed in ONE corpus, each in its own file, asserted per file:line.
# Classes 1, 1b and 2 are independent output rows, and each seed sits in a file of its own so a
# finding can only come from its own seed. Near-misses (the quoted mention, the negative mandate,
# the complete triples) carry a flagged twin in the SAME file, so "absent" is never read off a
# file the scan did not reach. mf and mo (12u19, 12u20) are scored on this world too.
p1_world() {
  fresh
  printf 'The lead MUST retry, because we lost a sprint to this.\n' >> "$WORK/t/CLAUDE.md"
  # dev.md: soft language beside a mandate (3), and the Opus line the consumer-layout arm reads (4).
  echo 'The dev should attach evidence; a missing attachment is a violation.' >> "$WORK/t/$T2/dev.md"
  echo 'You are dispatched on the Opus tier.' >> "$WORK/t/$T2/dev.md"
  # qa.md: a QUOTED mention (1) is not drift; its unquoted twin (3) is.
  printf 'Rule text carrying "because we" justification is drift and FAILs the audit.\n\nThe lead MUST retry, because we lost a sprint to this.\n' > "$WORK/t/$T2/qa.md"
  # ops.md: a NEGATIVE mandate (1) is not weakness; its soft twin (3) is.
  printf 'The dev should never merge unreviewed code; doing so is a violation.\n\nThe dev should attach evidence; a missing attachment is a violation.\n' > "$WORK/t/$T2/ops.md"
  # sm.md: "should be" is not exempt (12i).
  echo 'The evidence should be attached before the gate; a gap is a violation.' > "$WORK/t/$T2/sm.md"
  # tea.md: a directive whose MUST wraps two lines down (12h). A per-line predicate scored it clean.
  cat > "$WORK/t/$T2/tea.md" <<'EOF'
Large read-only command output should be routed through the offload tool so its
bytes stay out of the resident prefix. Two hard limits: state-mutating commands
MUST run natively, and verbatim-load files MUST NOT be routed through it.
EOF
  # Rule 26(c): one file per shape.
  cat > "$WORK/t/$SD/s5.md" <<'EOF'
**Minimum mechanism.** Failure caught: an unrecorded outcome reaching the gate.
EOF
  cat > "$WORK/t/$SD/s6.md" <<'EOF'
**Minimum mechanism.** Failure caught: an unrecorded outcome reaching the gate.
False-positive cost: one redundant line per step. Removal condition: retire
once the outcome is written structurally.
EOF
  cat > "$WORK/t/$SD/s6a.md" <<'EOF'
**Minimum mechanism.** Failures caught: an unrecorded outcome reaching the gate,
and a stale outcome re-read. False-positive cost: one redundant line per step.
Removal condition: retire once the outcome is written structurally.
EOF
  printf 'Failures caught: an unrecorded outcome reaching the gate.\n' > "$WORK/t/$SD/s6b.md"
  cat > "$WORK/t/$SD/s12j.md" <<'EOF'
## Minimum mechanism (Rule 26(c))

This gate exists to keep the outcome recorded and the sprint honest.
EOF
}
p1_world
out="$(audit)"
has "CLAUDE.md:4  NARRATIVE_DRIFT" "$out" \
  && ok "seeded 'because we' narrative -> NARRATIVE_DRIFT FLAGGED" \
  || bad "narrative drift went undetected — Class 1 cannot fire"
[ "$(rc_of "$AUDIT")" = "1" ] && ok "  and exit 1" || bad "  but exit was not 1"
{ ! has "$T2/qa.md:1  NARRATIVE_DRIFT" "$out"; } && has "$T2/qa.md:3  NARRATIVE_DRIFT" "$out" \
  && ok "a quoted mention of the pattern -> still CLEAN (mention is not use)" \
  || bad "the audit flagged its own definition — the quoted-span guard is gone"
has "$T2/dev.md:3  RULE_WEAKNESS" "$out" \
  && ok "seeded soft language beside a mandate -> RULE_WEAKNESS FLAGGED" \
  || bad "rule weakness went undetected — Class 2 cannot fire"
{ ! has "$T2/ops.md:1  RULE_WEAKNESS" "$out"; } && has "$T2/ops.md:3  RULE_WEAKNESS" "$out" \
  && ok "'should never' beside a mandate -> CLEAN (negative mandate exempt)" \
  || bad "'should never' was flagged as soft language"
has "$T2/sm.md:1  RULE_WEAKNESS" "$out" \
  && ok "'should be' beside a mandate -> FLAGGED (canonical soft-mandate form)" \
  || bad "'should be' was exempted — the scan is blind to the shape Rule 18 names first"
has "$T2/tea.md:[0-9]*  RULE_WEAKNESS" "$out" \
  && ok "soft directive whose MUST wraps to a later line -> RULE_WEAKNESS FLAGGED" \
  || bad "Class 2 is still line-scoped — a wrapped mandate stays invisible"
has "$SD/s5.md:[0-9]*  INCOMPLETE_26C" "$out" \
  && ok "'Failure caught:' with no other two fields -> INCOMPLETE_26C FLAGGED" \
  || bad "an incomplete Rule 26(c) triple went undetected — Class 1b cannot fire"
{ ! has "$SD/s6.md:[0-9]*  INCOMPLETE_26C" "$out"; } \
  && ok "a complete triple wrapping across lines -> CLEAN (section-scoped)" \
  || bad "a complete Rule 26(c) triple was flagged incomplete"
{ ! has "$SD/s6a.md:[0-9]*  INCOMPLETE_26C" "$out"; } \
  && ok "a headed complete triple with plural 'Failures caught:' -> CLEAN" \
  || bad "a complete plural-field Rule 26(c) triple was flagged incomplete — FC is singular-only"
has "$SD/s6b.md:[0-9]*  INCOMPLETE_26C" "$out" \
  && ok "a headless plural 'Failures caught:' with no other two fields -> FLAGGED" \
  || bad "a headless plural-opened incomplete block went undetected — FIELD_OPENER is singular-only"
has "$SD/s12j.md:[0-9]*  INCOMPLETE_26C" "$out" \
  && ok "a 26(c) block supplying none of the three fields -> FLAGGED" \
  || bad "a fieldless 26(c) block went undetected — Class 1b still anchors on a field it may lack"
# Assertion 37: consumer layout -> N/A, never a scan of the consumer's own files (dev.md carries the Opus line).
has 'ROLE_MODEL_NAMING: N/A' "$out" \
  && ok "consumer layout -> ROLE_MODEL_NAMING N/A (the arm runs in the distribution only)" \
  || bad "Class 1d ran in a consumer layout, over text the consumer cannot edit"

# --- Assertion 12g: the two thresholds differ, and NEITHER goes silent ------
# P1 holds tier-2 findings only: the push is not gated, the retro still sees them.
if [ "$(rc_of "$AUDIT")" = "1" ] \
   && [ "$(rc_of "$AUDIT" --fail-on=deterministic)" = "0" ] \
   && has 'NARRATIVE_DRIFT: FLAGGED' "$out"; then
  ok "tier-2-only finding -> default exit 1, deterministic exit 0, still printed"
else
  bad "the tier split is wrong: a judgement finding must not gate the push, and must never go unprinted"
fi
has 'NARRATIVE_DRIFT: FLAGGED' "$(audit --fail-on=deterministic)" \
  && ok "  and --fail-on=deterministic still PRINTS the tier-2 finding" \
  || bad "  but --fail-on=deterministic suppressed the tier-2 finding — a silent tier is the defect this audit exists to find"

# ===== World P2: the pointer scan (tier 1). Seven, eight and nine in one corpus, per file. ===
fresh
echo 'The convention is defined in `steps/rule-authoring.md`.' \
  >> "$WORK/t/.claude/skills/ai-dlc/extensions/README.md"
echo 'Canonical shape is defined in `steps/no-such-step.md`.' \
  > "$WORK/t/.claude/skills/ai-dlc/overrides/entry.md"
echo 'Rule text lives in `rule-authoring.md` and `team-roles/dev.md`.' > "$WORK/t/$SD/ptr9.md"
out="$(audit)"
has 'DANGLING_POINTER: FLAGGED' "$out" && has 'extensions/README.md.*DANGLING_POINTER' "$out" \
  && ok "pointer to a nonexistent skill file -> DANGLING_POINTER FLAGGED" \
  || bad "a dangling skill-content pointer went undetected"
# Assertion 8: the scan reaches overrides/, not just steps/ (core scoped it to SKILL.md + steps/*.md).
has 'overrides/entry.md.*DANGLING_POINTER' "$out" \
  && ok "a dangling pointer inside overrides/ is reached by the scan" \
  || bad "overrides/ is outside the pointer scan — the scope bug is back"
# Assertion 9: a RESOLVABLE pointer is not flagged (its flagged twins are in the same corpus).
{ ! has 'steps/ptr9.md.*DANGLING_POINTER' "$out"; } \
  && ok "pointers to files that exist -> CLEAN" \
  || bad "a resolvable pointer was reported dangling"

# ===== World T: every TIER-1 origin seed in ONE corpus. Assertions 12a-12f and 12k. ==========
# CLAUDE.md:4 version tag, :5 sprint reference, :6 parenthetical origin note, :7 embedded date, :8 a
# BACKTICKED version tag (mention is not use), plus a version tag in escalations.md (the corpus reaches
# the whole skill). One --fail-on=deterministic run is both the report and the exit code; the MUTANT run
# of 12f strips tier 1 from the same corpus, so the unmutated exit 1 beside it is the live control.
wt_world() {
  fresh
cat >> "$WORK/t/CLAUDE.md" <<'EOF'
The lead MUST re-run the gate; this replaced the v0.42.0 behaviour.
The lead MUST cite the operator; this closes the S301 hole.
The lead MUST run the close gate (formerly the retro gate) before merging.
The lead MUST attach evidence; this has been required since 2026-04-17.
A tag such as `v0.42.0` in rule prose FAILs this audit.
EOF
echo 'The lead MUST escalate; this replaced the v0.42.0 protocol.' \
  > "$WORK/t/.claude/skills/ai-dlc/escalations.md"
}
wt_world
out="$(audit --fail-on=deterministic)"
has "CLAUDE.md:4  ORIGIN_TAG  origin tag 'v0.42.0'" "$out" && has 'ORIGIN_TAG: FLAGGED.*tier 1' "$out" \
  && ok "seeded version tag -> ORIGIN_TAG FLAGGED" \
  || bad "a version tag in rule prose went undetected"
[ "$(rc_of "$AUDIT" --fail-on=deterministic)" = "1" ] \
  && ok "  and it gates the push (--fail-on=deterministic -> exit 1)" \
  || bad "  but --fail-on=deterministic did not exit 1"
has "CLAUDE.md:5  ORIGIN_TAG  origin tag 'S301'" "$out" \
  && ok "seeded sprint reference -> ORIGIN_TAG FLAGGED" \
  || bad "a sprint reference in rule prose went undetected"
{ ! has "CLAUDE.md:8  ORIGIN_TAG" "$out"; } \
  && ok "a backticked version tag -> still CLEAN (mention is not use)" \
  || bad "the audit flagged its own definition of the origin-tag shape"
has "CLAUDE.md:6  ORIGIN_PARENTHETICAL" "$out" \
  && ok "seeded parenthetical origin note -> ORIGIN_PARENTHETICAL FLAGGED" \
  || bad "a parenthetical origin note went undetected"
has "CLAUDE.md:7  EMBEDDED_DATE" "$out" \
  && ok "seeded embedded date -> EMBEDDED_DATE FLAGGED" \
  || bad "an embedded date went undetected"
has 'escalations.md.*ORIGIN_TAG' "$out" \
  && ok "escalations.md is inside the corpus" \
  || bad "escalations.md ships to every consumer and is scanned by nothing"
# --- Assertion 12f: MUTATION CONTROL — tier 1 is what catches tier 1 --------
# Every seed above, tier-1 patterns stripped. If this still reports FLAGGED, some older class is
# matching the seeds and the new code is unproven.
# The unmutated run on the same corpus must fail, or the control proves nothing.
if [ "$(rc_of "$AUDIT" --fail-on=deterministic)" = "1" ]; then
  ok "  the unmutated run on that corpus exits 1 (control is live)"; B_t=1
else
  bad "  the unmutated run also passed — the differential is vacuous"
fi
out_m="$(audit_mut --fail-on=deterministic)"
if has 'ORIGIN_TAG: CLEAN' "$out_m" \
   && has 'ORIGIN_PARENTHETICAL: CLEAN' "$out_m" \
   && has 'EMBEDDED_DATE: CLEAN' "$out_m" \
   && [ "$(rc_mut --fail-on=deterministic)" = "0" ]; then
  mutant_killed "${B_t:-0}" tier1-strip "MUTANT: tier-1 patterns stripped -> the same corpus scores CLEAN"
else
  bad "tier1-strip SURVIVED: MUTANT run still flagged the tier-1 seeds — an older class is catching them, so the new patterns are unproven"
fi


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
wg_world() {
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
}
wg_world
if cmp -s "$WORK/ra.pristine" "$WORK/t/$RA"; then
  bad "FIXTURE BROKEN — the Class 1c mutant is byte-identical to the seed, so nothing was mutated and the arms below prove nothing"
else
  out="$(audit)"
  if has 'IDENTIFIER_GRANT: FLAGGED' "$out"; then
    ok "grant deleted with its trailing prohibition retained -> IDENTIFIER_GRANT FLAGGED"; B_gr=1
  else
    bad "a Style block that prohibits every way to carry an identifier and permits none went undetected"
  fi
  [ "$(rc_of "$AUDIT" --fail-on=deterministic)" = "1" ] \
    && ok "  and it gates the push (--fail-on=deterministic -> exit 1)" \
    || bad "  but --fail-on=deterministic did not exit 1"
  # MUTANT differential, on THIS corpus rather than 12f's: 12f seeds only CLAUDE.md,
  # where this class has no subject, so it scores the same either way there and
  # establishes nothing about Class 1c.
  if has 'IDENTIFIER_GRANT: CLEAN' "$(audit_mut)"; then
    mutant_killed "${B_gr:-0}" grant-strip "  MUTANT: tier-1 stripped -> the same corpus scores CLEAN (no older class is catching it)"
  else
    bad "  grant-strip SURVIVED: MUTANT run still flagged it — an older class is matching this seed and Class 1c is unproven"
  fi
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
# `the reason is` is a POINTER in every corpus line that carries it, never a story: the
# three shapes the distribution holds (a lowercase "not restated here", a lowercase rule
# citation, an uppercase heading wrapping at the token), then one habitual line that MUST
# still flag. Line 4's predecessor ends in the wrapped token, so a restored alternative
# moves lines 1-3 and leaves 4 where it was.
u_r() { cat > "$WORK/t/$TR/uhr.md" <<'EOF'
the reason is not restated here.
the reason is Rule 27.
**THE NUMBER IS THE SPRINT THAT CLOSED, AND THE REASON IS
The step used to stop here.
EOF
}

# --- Assertions 12u1-12u9d: ONE combined corpus, asserted per file ------------------------------
# The predicate decides per LINE and each seed sits in a file of its own, so one run answers all of
# them. 12u10 below asserts this corpus's EXACT hit list, so a purpose line missing from it and a
# habitual line present in it are each held to a single line.
wu_world() { fresh; u_p1; u_p2; u_p3; u_h1; u_h2; u_h3; u_h4; u_h5; u_a; u_b; u_b2; u_c; u_r; }
wu_world
HAB="$TR/uh1.md:1,$TR/uh2.md:1,$TR/uh3.md:1,$TR/uh4.md:2,$TR/uh5.md:2,$TR/uhr.md:4"
ALLHITS="$TR/ua.md:1,$TR/ub.md:2,$TR/ub2.md:2,$HAB"
WITHUC="$TR/ua.md:1,$TR/ub.md:2,$TR/ub2.md:2,$TR/uc.md:1,$HAB"
cout="$(audit)"
nl="$(grep 'NARRATIVE_DRIFT: FLAGGED' <<<"$cout")"

{ ! has "$TR/up1.md" "$nl"; } \
  && ok "'A health signal used to clear …' -> NARRATIVE_DRIFT CLEAN (purpose, not history)" \
  || bad "a reduced passive of purpose on a noun phrase scored as narrative drift"
# The wrap is the point: `be` is on the previous line and `used to` opens this one.
{ ! has "$TR/up2.md" "$nl"; } \
  && ok "'MUST NOT be' / 'used to satisfy …' across a line wrap -> CLEAN" \
  || bad "a passive of purpose wrapping at 'be' / 'used to' scored as narrative drift"
{ ! has "$TR/up3.md" "$nl"; } \
  && ok "'a TEL-denominated total' / 'used to validate …' across a wrap -> CLEAN" \
  || bad "a reduced relative wrapping onto a line-initial 'used to' scored as drift"

has "$TR/uh1.md:1[],]" "$nl" \
  && ok "'The step used to say nothing here' -> FLAGGED at uh1.md:1" \
  || bad "the habitual past went undetected — the purpose carve-out swallowed Class 1"
# No tense-shift marker anywhere on this line, deliberately: the marker fix reads
# as the obvious one and this is the seed that refuses it.
has "$TR/uh2.md:1[],]" "$nl" \
  && ok "'Where the blocks used to sit' (no 'now'/'no longer') -> FLAGGED at uh2.md:1" \
  || bad "a habitual line carrying no tense-shift marker was acquitted"
has "$TR/uh3.md:1[],]" "$nl" \
  && ok "'This paragraph used to read …' -> FLAGGED at uh3.md:1" \
  || bad "a habitual line whose object is a quoted span was acquitted"
# Line-initial AND habitual. The previous-line join must not acquit on its own.
has "$TR/uh4.md:2[],]" "$nl" \
  && ok "a line-initial habitual 'used to exist here is gone' -> FLAGGED at uh4.md:2" \
  || bad "the previous-line join acquits every line-initial 'used to', purpose or not"
has "$TR/uh5.md:2[],]" "$nl" \
  && ok "'that used to collide with it now sit …' -> FLAGGED at uh5.md:2" \
  || bad "a habitual line that DOES carry 'now' was acquitted"
# Assertion 12u9e: `the reason is` is no NARRATIVE alternative. Three pointer shapes stay CLEAN and
# the habitual line beside them still flags; mutant umr (12u21) restores the token and is killed here.
{ ! has "$TR/uhr.md:[123][],]" "$nl"; } \
  && ok "'the reason is not restated here.' / 'the reason is Rule 27.' / '… AND THE REASON IS' -> CLEAN" \
  || bad "a 'the reason is' pointer line scored as narrative drift"
has "$TR/uhr.md:4[],]" "$nl" \
  && ok "'The step used to stop here.' after the pointer lines -> FLAGGED at uhr.md:4" \
  || bad "the habitual line beside the pointer lines was acquitted"

# --- Assertion 12u9: one purpose line and one habitual line, SAME FILE -------
# The arm that proves the predicate decides per LINE and not per FILE. Both
# clauses are in one file; only the habitual line's number may appear. (Its own world.)
fresh; u_mix
has "NARRATIVE_DRIFT: FLAGGED  n=\[$TR/umix.md:4\]" "$(audit)" \
  && ok "purpose at umix.md:1 + habitual at umix.md:4 -> FLAGGED naming ONLY line 4" \
  || bad "a file holding both shapes reported the wrong line set — the predicate is file-scoped"

has "$TR/ua.md:1[],]" "$nl" \
  && ok "'This is not a gate. The step used to stop here.' -> FLAGGED at ua.md:1" \
  || bad "an indefinite article in the PREVIOUS sentence acquitted the habitual clause after it"
has "$TR/ub.md:2[],]" "$nl" \
  && ok "'\`validate-mandatory-rules.sh\` used to run six checks.' -> FLAGGED at ub.md:2" \
  || bad "a habitual line whose subject is a backticked span was read as a wrap and took its predecessor's verdict"
# The discriminating input. ub is FLAGGED under either fall-through rule because its previous line
# ends in a period; ub2 is FLAGGED only under the raw-text rule, and it is the seed mutant m7 moves.
has "$TR/ub2.md:2[],]" "$nl" \
  && ok "the same line over a predecessor ending in a bare 'an' -> still FLAGGED at ub2.md:2" \
  || bad "a blanked prefix fell through to the previous line and borrowed its acquittal"
{ ! has "$TR/uc.md" "$nl"; } \
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

wu_world
HAB="$TR/uh1.md:1,$TR/uh2.md:1,$TR/uh3.md:1,$TR/uh4.md:2,$TR/uh5.md:2,$TR/uhr.md:4"
ALLHITS="$TR/ua.md:1,$TR/ub.md:2,$TR/ub2.md:2,$HAB"
WITHUC="$TR/ua.md:1,$TR/ub.md:2,$TR/ub2.md:2,$TR/uc.md:1,$HAB"

# --- Assertion 12u10: UNMUTATED CONTROL, with a positive conjunct ------------
# Not "nothing went wrong": the eight habitual lines must be THERE and the four
# purpose lines must NOT, or a subject replaced by `exit 0` scores every mutant
# below as a kill.
if has "NARRATIVE_DRIFT: FLAGGED  n=\[$ALLHITS\]" "$(audit)"; then
  ok "CONTROL: 4 purpose + 8 habitual in one corpus -> exactly the 8 habitual lines"; B_u10=1
else
  bad "the unmutated control did not produce the baseline hit set — every mutant below is unreadable"
fi

# --- Assertion 12u11: m1, the OLD grammar restored --------------------------
# `used to\b` back inside NARRATIVE, which is what the audit did before the split.
if mkmut um1 's/|measured:|/|measured:|used to\\b|/'; then
  if has "NARRATIVE_DRIFT: FLAGGED  n=\[$WITHUC,$TR/up1.md:1,$TR/up2.md:2,$TR/up3.md:2\]" "$(audit_at "$WORK/um1.sh")"; then
    mutant_killed "${B_u10:-0}" um1 "MUTANT m1 (old NARRATIVE grammar) -> all four purpose lines flip to FLAGGED; killed"
  else
    bad "um1 SURVIVED: MUTANT m1 restored 'used to' to NARRATIVE and no purpose arm moved — 12u1-12u3 prove nothing"
  fi
else
  bad "MUTANT m1 DID NOT APPLY — its anchor moved; 12u1-12u3 are unproven"
fi

# --- Assertion 12u12: m2, the tense-marker wrong fix -------------------------
# The fix the audit's own comment records as scored and rejected: require
# "now"/"no longer" on the line. It clears the same purpose sites AND silences
# every habitual line that does not announce its own tense shift.
if mkmut um2 's#^            return True$#            return bool(re.search(r"\\bnow\\b|\\btoday\\b|\\bcurrently\\b|no longer", t, re.I))#'; then
  if has "NARRATIVE_DRIFT: FLAGGED  n=\[$TR/uh5.md:2\]" "$(audit_at "$WORK/um2.sh")"; then
    mutant_killed "${B_u10:-0}" um2 "MUTANT m2 (tense marker required) -> seven habitual lines go CLEAN, only 'now' survives; killed"
  else
    bad "um2 SURVIVED: MUTANT m2 required a tense-shift marker and the habitual arms did not move — 12u4-12u8 prove nothing"
  fi
else
  bad "MUTANT m2 DID NOT APPLY — its anchor moved; 12u4-12u8 are unproven"
fi

# --- Assertion 12u13: m3, the predicate acquits everything -------------------
# uh5 is what separates m3 from m2: it carries "now", so m2 keeps it and m3 does
# not. Without that seed the two mutants have one footprint and neither is proven.
if mkmut um3 's#^            return True$#            return False#'; then
  if has 'NARRATIVE_DRIFT: CLEAN' "$(audit_at "$WORK/um3.sh")"; then
    mutant_killed "${B_u10:-0}" um3 "MUTANT m3 (habitual_used_to always False) -> every habitual line goes CLEAN; killed"
  else
    bad "um3 SURVIVED: MUTANT m3 acquitted every line and Class 1 still flagged — some other pattern is catching the seeds"
  fi
else
  bad "MUTANT m3 DID NOT APPLY — its anchor moved; 12u4-12u8 are unproven"
fi

# --- Assertion 12u14: m4, the previous-line join removed --------------------
# Owns BOTH wrapped purpose seeds: they are one property, and a mutant that moved
# only one of them would mean the other arm is reading something else.
if mkmut um4 's#            before = used(prev)#            before = ""#'; then
  if has "NARRATIVE_DRIFT: FLAGGED  n=\[$ALLHITS,$TR/up2.md:2,$TR/up3.md:2\]" "$(audit_at "$WORK/um4.sh")"; then
    mutant_killed "${B_u10:-0}" um4 "MUTANT m4 (previous-line join removed) -> both WRAPPED purpose lines flip, up1 and uc do not; killed"
  else
    bad "um4 SURVIVED: MUTANT m4 dropped the previous-line join and the wrapped arms did not move — 12u2/12u3 prove nothing"
  fi
else
  bad "MUTANT m4 DID NOT APPLY — its anchor moved; 12u2/12u3 are unproven"
fi

# --- Assertion 12u15: m5, the WRONG FIX, built rather than described ---------
# The plausible over-wide fix: acquit on ANY article rather than an indefinite
# one. It clears all three purpose sites, which is what makes it look finished,
# and takes "The step used to" and "the blocks used to" with it. m5, m6 and m7 also switch off
# the BL-1001 indefinite-subject test (the `if False:` line), because that test now flags what each of
# them acquits or re-acquits and would hide their footprint. Seeding the
# absent fix proves the arms fire; seeding the WRONG one proves they discriminate.
if mkmut um5 's#(a|an)#(a|an|the)#;s#if article_opens_clause(before, prev, bool(text\[:m.start()\].strip()), after_clause(t\[m.end():\], used(nxt))):#if False:#'; then
  if has "NARRATIVE_DRIFT: FLAGGED  n=\[$TR/ub.md:2,$TR/ub2.md:2,$TR/uh3.md:1,$TR/uh4.md:2,$TR/uh5.md:2\]" "$(audit_at "$WORK/um5.sh")"; then
    mutant_killed "${B_u10:-0}" um5 "MUTANT m5 (definite article acquits too, indefinite-subject test off) -> ua, uh1 and uh2 go CLEAN; killed"
  else
    bad "um5 SURVIVED: MUTANT m5 widened the article class and no habitual arm moved — the a/an narrowing is unbound"
  fi
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
if mkmut um6 $'s#.*am|is|are.*#    r"([a-z]{3,}\\\\s*$)", re.I)#\n/directly|solely/d\n/explicitly|first/d\n/(a|an)/d\ns#if article_opens_clause(before, prev, bool(text\[:m.start()\].strip()), after_clause(t\[m.end():\], used(nxt))):#if False:#'; then
  if has "NARRATIVE_DRIFT: FLAGGED  n=\[$TR/ub.md:2,$TR/ub2.md:2,$TR/uh4.md:2,$TR/up2.md:2\]" "$(audit_at "$WORK/um6.sh")"; then
    mutant_killed "${B_u10:-0}" um6 "MUTANT m6 (noun-looking token before) -> up2 flips AND uh1/uh2/uh3/ua go CLEAN; killed"
  else
    bad "um6 SURVIVED: MUTANT m6 replaced the two clauses with a noun heuristic and nothing moved — the clause split is unbound"
  fi
else
  bad "MUTANT m6 DID NOT APPLY — its anchor moved; the clause split is unproven"
fi

# --- Assertion 12u17: m7, the fall-through decided on BLANKED text ----------
# The state before the raw-text fix: a line whose only prefix is a backticked
# subject reads as line-initial and borrows the previous line's verdict. It moves
# exactly one cell, ub2, which is why ub2 had to be seeded — ub is FLAGGED under
# both rules and could never have shown this.
if mkmut um7 's#if not text#if not before#;s#if article_opens_clause(before, prev, bool(text\[:m.start()\].strip()), after_clause(t\[m.end():\], used(nxt))):#if False:#'; then
  if has "NARRATIVE_DRIFT: FLAGGED  n=\[$TR/ua.md:1,$TR/ub.md:2,$HAB\]" "$(audit_at "$WORK/um7.sh")"; then
    mutant_killed "${B_u10:-0}" um7 "MUTANT m7 (fall-through on blanked text) -> ub2 alone goes CLEAN; killed"
  else
    bad "um7 SURVIVED: MUTANT m7 restored the blanked-prefix fall-through and no arm moved — 12u9c proves nothing"
  fi
else
  bad "MUTANT m7 DID NOT APPLY — its anchor moved; 12u9c is unproven"
fi

# --- Assertion 12u18: m8, the adverb allowance removed ----------------------
# A copula with a negation between it and the participle is still a passive.
# Deleting the allowance moves exactly one cell, uc.
if mkmut um8 $'/directly|solely/d\ns#.*explicitly|first.*#    r"\\\\s*$"#'; then
  if has "NARRATIVE_DRIFT: FLAGGED  n=\[$WITHUC\]" "$(audit_at "$WORK/um8.sh")"; then
    mutant_killed "${B_u10:-0}" um8 "MUTANT m8 (no adverb between copula and participle) -> uc alone flips to FLAGGED; killed"
  else
    bad "um8 SURVIVED: MUTANT m8 removed the adverb allowance and uc did not flip — 12u9d proves nothing"
  fi
else
  bad "MUTANT m8 DID NOT APPLY — its anchor moved; 12u9d is unproven"
fi

# --- World UQ (BL-1001): an indefinite-subject habitual clause is flagged, a purpose clause is not --
# The audit's header (CLAUSE 2 AS SHIPPED) carries the rule; this world holds its arms. SELF-PROBE FIRST:
# every offender is producer text (the two lines BL-1001 cites and the verifier's probe lines) and every
# near-miss carries the property a wrong fix keys on. OFFENDERS (flagged): uqa "Where a ... used to sit",
# uqb "— a ... used to" (wrapped), uqe the wrapped cue, uqh1-uqh3 ", and" / ", but" / "and", uqi
# "Before 0.9,", uqj "Before:", uqk "(...)", uql sentence-initial, uqn1-uqn3 a finite verb that only
# follows a cut (and / where / which). NEAR-MISSES (clear): uqc a comma-initial noun with a modal after,
# uqd a cue before a passive, uqm1/uqm2 an imperative object (one line and wrapped), uqp1-uqp5 a purpose
# noun after a verb or a copula (the verifier's B2 shapes, one wrapped), uqp6 a cue with a finite verb
# after, plus the producer purpose lines up1, up2, up3.
wq_world() { fresh
  printf '%s\n' 'Where a per-sprint block used to sit, write a pointer.' > "$WORK/t/$TR/uqa.md"
  printf '%s\n' 'Before this gate it did not deadlock — a failed push used to' 'commit locally and not block the run.' > "$WORK/t/$TR/uqb.md"
  printf '%s\n' 'Where it fails, a health signal used to clear the operation MUST be absolute.' > "$WORK/t/$TR/uqc.md"
  printf '%s\n' 'Where a probe is used to validate a total, read it twice.' > "$WORK/t/$TR/uqd.md"
  printf '%s\n' 'Write the pointer where' 'a block used to sit here.' > "$WORK/t/$TR/uqe.md"
  printf '%s\n' 'Pushes are slow, and a failed push used to commit locally.' > "$WORK/t/$TR/uqh1.md"
  printf '%s\n' 'Pushes are slow, but a failed push used to commit locally.' > "$WORK/t/$TR/uqh2.md"
  printf '%s\n' 'Pushes are slow and a failed push used to commit locally.' > "$WORK/t/$TR/uqh3.md"
  printf '%s\n' 'Before 0.9, a failed push used to commit locally.' > "$WORK/t/$TR/uqi.md"
  printf '%s\n' 'Before: a failed push used to commit locally.' > "$WORK/t/$TR/uqj.md"
  printf '%s\n' '(a failed push used to commit locally)' > "$WORK/t/$TR/uqk.md"
  printf '%s\n' 'A step used to say nothing.' > "$WORK/t/$TR/uql.md"
  printf '%s\n' 'Use a token used to identify the run.' > "$WORK/t/$TR/uqm1.md"
  printf '%s\n' 'Use' 'a token used to identify the run.' > "$WORK/t/$TR/uqm2.md"
  printf '%s\n' 'A step used to say nothing and the lead has to guess.' > "$WORK/t/$TR/uqn1.md"
  printf '%s\n' 'A step used to fail where it now must pass.' > "$WORK/t/$TR/uqn2.md"
  printf '%s\n' 'A failed push used to commit locally which is worse.' > "$WORK/t/$TR/uqn3.md"
  printf '%s\n' 'The hook reads a variable used to override the root.' > "$WORK/t/$TR/uqp1.md"
  printf '%s\n' 'It takes an argument used to name the file.' > "$WORK/t/$TR/uqp2.md"
  printf '%s\n' 'You can pass a flag used to select the root.' > "$WORK/t/$TR/uqp3.md"
  printf '%s\n' 'This is a flag used to select the root.' > "$WORK/t/$TR/uqp4.md"
  printf '%s\n' 'The hook reads' 'a variable used to override the root.' > "$WORK/t/$TR/uqp5.md"
  printf '%s\n' 'Where a flag used to select the root is set, read it.' > "$WORK/t/$TR/uqp6.md"
  printf '%s\n' 'The hook reads the root.' 'A step used to say nothing here.' > "$WORK/t/$TR/uqr.md"
  printf '%s\n' 'Pushes are slow - a failed push used to commit locally.' > "$WORK/t/$TR/uqs1.md"
  printf '%s\n' 'Pushes are slow – a failed push used to commit locally.' > "$WORK/t/$TR/uqs2.md"
  printf '%s\n' 'Pass a token, e.g. a variable used to override the root.' > "$WORK/t/$TR/uqt1.md"
  printf '%s\n' 'Pass a token, i.e. a path used to name the file.' > "$WORK/t/$TR/uqt2.md"
  printf '%s\n' 'A file used to record the verdicts was removed in 0.9.' > "$WORK/t/$TR/uqu1.md"
  printf '%s\n' "A script used to seed the store won't move." > "$WORK/t/$TR/uqu2.md"
  u_p1; u_p2; u_p3
}
wq_world
Q="$TR/uq"
U1="${Q}a.md:1,${Q}b.md:1,${Q}e.md:2,${Q}h1.md:1,${Q}h2.md:1,${Q}h3.md:1,${Q}i.md:1,${Q}j.md:1,${Q}k.md:1,${Q}l.md:1"
U2="${Q}n1.md:1,${Q}n2.md:1,${Q}n3.md:1"
U3="${Q}r.md:2,${Q}s1.md:1,${Q}s2.md:1"
UQALL="$U1,$U2,$U3"
uqout="$(audit)"
if has "NARRATIVE_DRIFT: FLAGGED  n=\[$UQALL\]" "$uqout"; then
  ok "CONTROL UQ: the 16 habitual indefinite-subject lines -> exactly those; the 16 purpose near-misses and 3 producer purpose lines CLEAN"; B_uq=1
else
  bad "World UQ did not flag exactly the sixteen habitual lines — an indefinite-subject habitual clause is acquitted or a purpose clause flagged"
fi
{ ! has "$TR/uqc.md" "$uqout"; } && { ! has "$TR/uqd.md" "$uqout"; } && { ! has "$TR/uqm1.md" "$uqout"; } && { ! has "$TR/uqm2.md" "$uqout"; } \
  && { ! has "$TR/uqp[1-6].md" "$uqout"; } && { ! has "$TR/uqt[12].md" "$uqout"; } && { ! has "$TR/uqu[12].md" "$uqout"; } && { ! has "$TR/up1.md" "$uqout"; } && { ! has "$TR/up2.md" "$uqout"; } && { ! has "$TR/up3.md" "$uqout"; } \
  && ok "comma-initial with a modal, cue before a passive, imperative objects, purpose nouns after a verb or copula (one wrapped), cue with a finite verb, and the three producer purpose lines -> CLEAN" \
  || bad "a purpose clause was flagged by the indefinite-subject test"

# Mutants, each moving the cells of its own property only (the expected set is asserted exactly).
# uq1 whole test off; uq2 previous line not read (uqm2 and the wrapped uqp5 flip); uq3 passive rescue off (uqd);
# uq4 sentence-initial test off (uql and uqn1-uqn3); uq5 `:` / uq6 `(` / uq7 `,` / uq8 `and|but` dropped from
# the clause-initial test (uqj / uqk / uqi / uqh1-uqh3, each decided by that one token; a comma before `and` does not end the segment); uq9 finite-verb rescue off
# (uqc, up1, up3 flip to flagged); uq10 clause cut at and/where/which off (uqn1-uqn3 clear); uq11 cue rescue off
# (uqp6 flips); uq12 clause-initial gate off (the imperative and B2 near-misses flip).
uqscore() { # <mutant> <sed script> <expected n list>: 0 = the expected set, 1 = another set, 2 = DID NOT APPLY
  mkmut "$1" "$2" || return 2
  has "NARRATIVE_DRIFT: FLAGGED  n=\[$3\]" "$(audit_at "$WORK/$1.sh")" && return 0
  return 1
}
if mkmut uq1 's#if article_opens_clause(before, prev, bool(text\[:m.start()\].strip()), after_clause(t\[m.end():\], used(nxt))):#if False:#'; then
  if has "NARRATIVE_DRIFT: CLEAN" "$(audit_at "$WORK/uq1.sh")"; then
    mutant_killed "${B_uq:-0}" uq1 "MUTANT uq1 (old clause 2: any article acquits) -> all sixteen habitual lines go CLEAN; killed"
  else
    bad "uq1 SURVIVED: the old clause 2 restored and an indefinite-subject habitual line still flagged"
  fi
else
  bad "MUTANT uq1 DID NOT APPLY — its anchor moved; the indefinite-subject test is unproven"
fi
uqscore uq2 's#        pre = used(prev)#        pre = ""#' "$U1,${Q}m2.md:2,$U2,${Q}p5.md:2,$U3"; r=$?
if [ "$r" = 0 ]; then
  mutant_killed "${B_uq:-0}" uq2 "MUTANT uq2 (previous line not read) -> the wrapped uqm2 and uqp5 flip to FLAGGED; killed"
elif [ "$r" = 1 ]; then
  bad "uq2 SURVIVED: the previous-line read removed and no wrapped arm moved"
else
  bad "MUTANT uq2 DID NOT APPLY — its anchor moved; its property is unproven"
fi
uqscore uq3 's#if q.groupdict().get("be"):#if False:#' "${Q}a.md:1,${Q}b.md:1,${Q}d.md:1,${UQALL#${Q}a.md:1,${Q}b.md:1,}"; r=$?
if [ "$r" = 0 ]; then
  mutant_killed "${B_uq:-0}" uq3 "MUTANT uq3 (passive rescue removed) -> uqd alone flips to FLAGGED; killed"
elif [ "$r" = 1 ]; then
  bad "uq3 SURVIVED: the passive rescue removed and the cue-before-passive near-miss did not move"
else
  bad "MUTANT uq3 DID NOT APPLY — its anchor moved; its property is unproven"
fi
uqscore uq4 's#return seg == "" or bool#return bool#' "${U1%,${Q}l.md:1},${Q}s1.md:1,${Q}s2.md:1"; r=$?
if [ "$r" = 0 ]; then
  mutant_killed "${B_uq:-0}" uq4 "MUTANT uq4 (sentence-initial test off) -> uql, uqn1-uqn3 and the wrapped uqr go CLEAN; killed"
elif [ "$r" = 1 ]; then
  bad "uq4 SURVIVED: the sentence-initial test removed and its arms did not move"
else
  bad "MUTANT uq4 DID NOT APPLY — its anchor moved; its property is unproven"
fi
uqscore uq5 's#\[,;:(#[,;(#' "${UQALL/,${Q}j.md:1/}"; r=$?
if [ "$r" = 0 ]; then
  mutant_killed "${B_uq:-0}" uq5 "MUTANT uq5 (':' dropped from the clause-initial test) -> uqj alone goes CLEAN; killed"
elif [ "$r" = 1 ]; then
  bad "uq5 SURVIVED: ':' dropped and uqj did not move"
else
  bad "MUTANT uq5 DID NOT APPLY — its anchor moved; its property is unproven"
fi
uqscore uq6 's#\[,;:(#[,;:#' "${UQALL/,${Q}k.md:1/}"; r=$?
if [ "$r" = 0 ]; then
  mutant_killed "${B_uq:-0}" uq6 "MUTANT uq6 (open paren dropped from the clause-initial test) -> uqk alone goes CLEAN; killed"
elif [ "$r" = 1 ]; then
  bad "uq6 SURVIVED: the open paren dropped and uqk did not move"
else
  bad "MUTANT uq6 DID NOT APPLY — its anchor moved; its property is unproven"
fi
uqscore uq7 's#\[,;:(#[;:(#' "${UQALL/,${Q}i.md:1/}"; r=$?
if [ "$r" = 0 ]; then
  mutant_killed "${B_uq:-0}" uq7 "MUTANT uq7 (comma dropped from the clause-initial test) -> uqi alone goes CLEAN; killed"
elif [ "$r" = 1 ]; then
  bad "uq7 SURVIVED: the comma dropped and uqi did not move"
else
  bad "MUTANT uq7 DID NOT APPLY — its anchor moved; its property is unproven"
fi
uqscore uq8 's#|\\b(and|but))#)#' "${UQALL/,${Q}h1.md:1,${Q}h2.md:1,${Q}h3.md:1/}"; r=$?
if [ "$r" = 0 ]; then
  mutant_killed "${B_uq:-0}" uq8 "MUTANT uq8 (and/but dropped from the clause-initial test) -> uqh1-uqh3 go CLEAN; killed"
elif [ "$r" = 1 ]; then
  bad "uq8 SURVIVED: and/but dropped and uqh3 did not move"
else
  bad "MUTANT uq8 DID NOT APPLY — its anchor moved; its property is unproven"
fi
uqscore uq9 's#^    if finite:$#    if False:#' "$TR/up1.md:1,${Q}a.md:1,${Q}b.md:1,${Q}c.md:1,${UQALL#${Q}a.md:1,${Q}b.md:1,},${Q}u1.md:1,${Q}u2.md:1"; r=$?
if [ "$r" = 0 ]; then
  mutant_killed "${B_uq:-0}" uq9 "MUTANT uq9 (finite-verb rescue off) -> uqc, up1, uqu1 and uqu2 flip to FLAGGED (up3 stays clear: its e.g. is no sentence end); killed"
elif [ "$r" = 1 ]; then
  bad "uq9 SURVIVED: the finite-verb rescue removed and no purpose arm moved"
else
  bad "MUTANT uq9 DID NOT APPLY — its anchor moved; its property is unproven"
fi
uqscore uq10 's#|\\b(?:and|but|which|where|while|whereas|because|although|though)\\b##' "${UQALL/,$U2/}"; r=$?
if [ "$r" = 0 ]; then
  mutant_killed "${B_uq:-0}" uq10 "MUTANT uq10 (clause not cut at and/where/which) -> uqn1-uqn3 go CLEAN; killed"
elif [ "$r" = 1 ]; then
  bad "uq10 SURVIVED: the clause cut removed and uqn1-uqn3 did not move"
else
  bad "MUTANT uq10 DID NOT APPLY — its anchor moved; its property is unproven"
fi
uqscore uq11 's#return not finite#return True#' "$U1,$U2,${Q}p6.md:1,$U3"; r=$?
if [ "$r" = 0 ]; then
  mutant_killed "${B_uq:-0}" uq11 "MUTANT uq11 (cue rescue off) -> uqp6 alone flips to FLAGGED; killed"
elif [ "$r" = 1 ]; then
  bad "uq11 SURVIVED: the cue rescue removed and uqp6 did not move"
else
  bad "MUTANT uq11 DID NOT APPLY — its anchor moved; its property is unproven"
fi
uqscore uq12 's#return seg == "" or bool(CLAUSE_INIT.search(seg))#return True#' "$U1,${Q}m1.md:1,${Q}m2.md:2,$U2,${Q}p1.md:1,${Q}p2.md:1,${Q}p3.md:1,${Q}p4.md:1,${Q}p5.md:2,$U3,${Q}t1.md:1,${Q}t2.md:1"; r=$?
if [ "$r" = 0 ]; then
  mutant_killed "${B_uq:-0}" uq12 "MUTANT uq12 (clause-initial gate off) -> the imperative objects, uqp1-uqp5 and the e.g./i.e. near-misses flip to FLAGGED; killed"
elif [ "$r" = 1 ]; then
  bad "uq12 SURVIVED: the clause-initial gate removed and no purpose-after-a-verb arm moved"
else
  bad "MUTANT uq12 DID NOT APPLY — its anchor moved; its property is unproven"
fi
uqscore uq13 's#\\u2013##' "${UQALL/,${Q}s2.md:1/}"; r=$?
if [ "$r" = 0 ]; then
  mutant_killed "${B_uq:-0}" uq13 "MUTANT uq13 (en dash dropped from the clause-initial test) -> uqs2 alone goes CLEAN; killed"
elif [ "$r" = 1 ]; then
  bad "uq13 SURVIVED: the en dash dropped and uqs2 did not move"
else
  bad "MUTANT uq13 DID NOT APPLY — its anchor moved; its property is unproven"
fi
uqscore uq14 's#|\\s-|#|#' "${UQALL/,${Q}s1.md:1/}"; r=$?
if [ "$r" = 0 ]; then
  mutant_killed "${B_uq:-0}" uq14 "MUTANT uq14 (spaced hyphen dropped from the clause-initial test) -> uqs1 alone goes CLEAN; killed"
elif [ "$r" = 1 ]; then
  bad "uq14 SURVIVED: the spaced hyphen dropped and uqs1 did not move"
else
  bad "MUTANT uq14 DID NOT APPLY — its anchor moved; its property is unproven"
fi
uqscore uq15 's#(?<!\\be\\.g)(?<!\\bi\\.e)##' "$UQALL,${Q}t1.md:1,${Q}t2.md:1"; r=$?
if [ "$r" = 0 ]; then
  mutant_killed "${B_uq:-0}" uq15 "MUTANT uq15 (e.g./i.e. read as a sentence end) -> uqt1 and uqt2 flip to FLAGGED; killed"
elif [ "$r" = 1 ]; then
  bad "uq15 SURVIVED: the abbreviation lookbehinds removed and no e.g./i.e. near-miss moved"
else
  bad "MUTANT uq15 DID NOT APPLY — its anchor moved; its property is unproven"
fi
uqscore uq16 's#(?:\\s+|\$)#\\s+#' "${UQALL/,${Q}r.md:2/}"; r=$?
if [ "$r" = 0 ]; then
  mutant_killed "${B_uq:-0}" uq16 "MUTANT uq16 (a sentence end needs a trailing space) -> the wrapped uqr goes CLEAN; killed"
elif [ "$r" = 1 ]; then
  bad "uq16 SURVIVED: the line-end sentence boundary removed and uqr did not move"
else
  bad "MUTANT uq16 DID NOT APPLY — its anchor moved; its property is unproven"
fi
uqscore uq17 's#|was|were|had|\\w\*n.t##' "$UQALL,${Q}u1.md:1,${Q}u2.md:1"; r=$?
if [ "$r" = 0 ]; then
  mutant_killed "${B_uq:-0}" uq17 "MUTANT uq17 (past and contracted forms out of FINITE_AFTER) -> uqu1 and uqu2 flip to FLAGGED; killed"
elif [ "$r" = 1 ]; then
  bad "uq17 SURVIVED: the widened finite list reverted and no past-tense near-miss moved"
else
  bad "MUTANT uq17 DID NOT APPLY — its anchor moved; its property is unproven"
fi
wu_world

# --- Assertion 12u21: mr, `the reason is` restored to NARRATIVE --------------
# Moves exactly the three pointer lines of uhr.md; line 4 is flagged either way.
if mkmut umr 's/|measured:|it turned out/|measured:|the reason is\\b|it turned out/'; then
  if has "NARRATIVE_DRIFT: FLAGGED  n=\[$TR/ua.md:1,$TR/ub.md:2,$TR/ub2.md:2,$TR/uh1.md:1,$TR/uh2.md:1,$TR/uh3.md:1,$TR/uh4.md:2,$TR/uh5.md:2,$TR/uhr.md:1,$TR/uhr.md:2,$TR/uhr.md:3,$TR/uhr.md:4\]" "$(audit_at "$WORK/umr.sh")"; then
    mutant_killed "${B_u10:-0}" umr "MUTANT mr ('the reason is' restored) -> the three pointer lines flip to FLAGGED; killed"
  else
    bad "umr SURVIVED: MUTANT mr restored 'the reason is' and no pointer line moved — 12u9e proves nothing"
  fi
else
  bad "MUTANT mr DID NOT APPLY — its anchor moved; 12u9e is unproven"
fi

# --- Assertion 12u19 and 12u20: mf and mo, scored on World P1 (the tier-2 corpus) ----------------
# mf reverts FC to the singular-only form and owns 6a alone: the headed plural triple is read as
# missing its failure field. mo reverts FIELD_OPENER and owns 6b alone: with no heading and no opener
# the headless block is never seen. Each is asserted against BOTH twins, so neither can move the
# other's cell.
p1_world
base_out="$(audit)"
if ! has "$SD/s6a.md:[0-9]*  INCOMPLETE_26C" "$base_out" && has "$SD/s6b.md:[0-9]*  INCOMPLETE_26C" "$base_out"; then
  ok "CONTROL: World P1 scores the headed plural triple CLEAN and the headless plural block FLAGGED"; B_p1=1
else
  bad "the unmutated World P1 did not score 6a CLEAN and 6b FLAGGED — mf and mo are unreadable"
fi
if mkmut umf 's/failures?\\s+caught/failure\\s+caught/'; then
  mf_out="$(audit_at "$WORK/umf.sh")"
  if has "$SD/s6a.md:[0-9]*  INCOMPLETE_26C" "$mf_out" && has "$SD/s6b.md:[0-9]*  INCOMPLETE_26C" "$mf_out"; then
    mutant_killed "${B_p1:-0}" umf "MUTANT mf (FC singular-only) -> the headed plural triple flips CLEAN to FLAGGED; killed"
  else
    bad "umf SURVIVED: MUTANT mf reverted FC and the headed plural arm did not move — 6a proves nothing"
  fi
else
  bad "MUTANT mf DID NOT APPLY — its anchor moved; 6a is unproven"
fi
if mkmut umo 's/Failures? caught:/Failure caught:/'; then
  mo_out="$(audit_at "$WORK/umo.sh")"
  if ! has "$SD/s6b.md:[0-9]*  INCOMPLETE_26C" "$mo_out" && ! has "$SD/s6a.md:[0-9]*  INCOMPLETE_26C" "$mo_out"; then
    mutant_killed "${B_p1:-0}" umo "MUTANT mo (FIELD_OPENER singular-only) -> the headless plural block flips FLAGGED to CLEAN; killed"
  else
    bad "umo SURVIVED: MUTANT mo reverted FIELD_OPENER and the headless plural arm did not move — 6b proves nothing"
  fi
else
  bad "MUTANT mo DID NOT APPLY — its anchor moved; 6b is unproven"
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
  out_nr="$( cd "$WORK/t" && bash "$SB/audit-rule-files.sh" --fail-on=local 2>&1; echo "@@RC=$?" )"
  rc_nr="${out_nr##*@@RC=}"; out_nr="${out_nr%@@RC=*}"
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

# --- Assertion 31: a STALLED resolver REFUSES; it is not scored as ownership --
# Assertion 28 owns the ABSENT resolver, which fails closed as `unresolved`. A
# PRESENT resolver whose `--list` stalls past the timeout is a different fact: a
# fault in this run. Swallowed, it scored every owner `unknown`, counted them as
# local, and exited 1 with nothing naming the timeout -- a stall read as a sheet of
# ownership findings. The audit must name the timeout and exit 2.
#
# Forced in a scratch sibling dir, as assertion 28 does, with the unmodified script
# copied in and its resolver replaced by a shim. No elapsed time decides either arm
# (BL-868). The stall arm's shim stops itself and never answers, so any timeout
# fires; it runs at a small AI_DLC_AUDIT_RESOLVER_TIMEOUT so the unit does not pay
# the shipped 30s, and asserts that exact value is the one named. The control's
# shim blocks on a fifo this fixture holds and runs the REAL resolver only once the
# fixture writes to it, with the seam at `none`, so the control's wait ends on that
# write and never on how long `--list` takes under the pool.
# STATED LIMIT: "none never times out" is not separable from "30s" by a load-free arm; the
# fifo-release probe recorded in commit 0ed48124a's message is the evidence for it.
fresh
SS="$WORK/stall"
rm -rf "$SS"; mkdir -p "$SS"
cp "$AUDIT" "$SS/audit-rule-files.sh"
cp "$RESOLVER" "$SS/core-paths.real.sh"
cmp -s "$RESOLVER" "$SS/core-paths.real.sh" || bad "FIXTURE BROKEN — the real resolver was not copied beside the scratch audit"
FIFO="$SS/release"
if ! mkfifo "$FIFO"; then
  bad "FIXTURE BROKEN — mkfifo failed, so the control cannot gate its resolver on an event"
else
  # The stall NEVER ENDS: the shim stops itself, so the timeout always fires first.
  # The timeout's SIGKILL ends a stopped process, so nothing is orphaned.
  printf '#!/usr/bin/env bash\nkill -STOP $$\n' > "$SS/core-paths.sh"
  printf 'The dev MUST comply, because we lost a sprint to this.\n' >> "$WORK/t/docs/coding-conventions.md"
  rc_st="$( cd "$WORK/t" && AI_DLC_AUDIT_RESOLVER_TIMEOUT=0.5 bash "$SS/audit-rule-files.sh" --fail-on=local >"$SS/out" 2>"$SS/err"; echo $? )"
  if [ "$rc_st" = "2" ] && grep -q 'timed out after 0.5s' "$SS/err" && ! grep -q '\[unknown\]' "$SS/out"; then
    ok "a STALLED resolver names the timeout and exits 2 — it is not scored as unresolved ownership"
  else
    bad "a stalled resolver returned rc=$rc_st without naming the 0.5s timeout — the stall read as ownership findings, or the seam was ignored"
  fi
  # A seam value that is neither a positive number nor `none` is refused BY NAME before
  # any wait. rc=2 alone cannot tell: with the check deleted, `abc` and `0` become
  # non-positive timeouts that expire at once and refuse as `timed out after`.
  inv_ok=1
  for v in abc 0; do
    rc_iv="$( cd "$WORK/t" && AI_DLC_AUDIT_RESOLVER_TIMEOUT="$v" bash "$SS/audit-rule-files.sh" --fail-on=local >"$SS/out" 2>"$SS/err"; echo $? )"
    { [ "$rc_iv" = "2" ] && grep -q 'is neither a positive number nor' "$SS/err" && ! grep -q 'timed out after' "$SS/err"; } || { inv_ok=0; inv_bad="$v rc=$rc_iv"; }
  done
  [ "$inv_ok" = 1 ] \
    && ok "an AI_DLC_AUDIT_RESOLVER_TIMEOUT that is neither a positive number nor \`none\` is refused by name, before any wait" \
    || bad "an invalid resolver-timeout seam value was not refused by name (${inv_bad:-?}) — it became a timeout"
  # Control: the same scratch dir, its resolver answering once released, scores
  # the seeded local finding (rc=1) and names no timeout. Without this, rc=2 above
  # is equally consistent with a sibling-dir copy that refuses for any reason.
  # fd 9 holds the fifo open read-write for the whole run: the write below cannot
  # block whether or not the shim has opened it yet, and its bytes stay buffered
  # until the shim reads them. It is closed only after the audit has exited.
  printf '#!/usr/bin/env bash\nread -r _ < "%s"\nexec bash "%s" "$@"\n' "$FIFO" "$SS/core-paths.real.sh" > "$SS/core-paths.sh"
  exec 9<>"$FIFO"
  ( cd "$WORK/t" && AI_DLC_AUDIT_RESOLVER_TIMEOUT=none bash "$SS/audit-rule-files.sh" --fail-on=local >"$SS/out" 2>"$SS/err"; echo $? > "$SS/rc" ) &
  sc_pid=$!
  printf 'go\n' >&9
  wait "$sc_pid"
  exec 9>&-
  rc_sc="$(cat "$SS/rc" 2>/dev/null)"
  if [ "$rc_sc" = "1" ] && grep -q '\[local\] docs/coding-conventions.md' "$SS/out" && ! grep -q 'timed out after' "$SS/err"; then
    ok "  control: the same scratch dir with the real resolver scores the local finding (rc=1) — the refusal above was the STALL"
  else
    bad "  control FAILED: the scratch copy with its real resolver returned rc=$rc_sc — assertion 31 proves nothing"
  fi

  # --- Assertion 32: a resolver that FAILS or answers EMPTY refuses too --------
  # The same fault class without a stall: `--list` exiting non-zero (its own
  # unparseable-manifest code is 2) and `--list` exiting 0 with no globs. Both
  # used to become an empty glob set and score every owner `unknown`. Same
  # seeded tree and scratch dir as 31, whose control has just shown this copy
  # scores the finding when the resolver answers.
  printf '#!/usr/bin/env bash\nexit 2\n' > "$SS/core-paths.sh"
  rc_f="$( cd "$WORK/t" && bash "$SS/audit-rule-files.sh" --fail-on=local >"$SS/out" 2>"$SS/err"; echo $? )"
  f_named=0; grep -q 'core-paths.sh --list` exited 2' "$SS/err" && f_named=1
  printf '#!/usr/bin/env bash\nexit 0\n' > "$SS/core-paths.sh"
  rc_e="$( cd "$WORK/t" && bash "$SS/audit-rule-files.sh" --fail-on=local >"$SS/out" 2>"$SS/err"; echo $? )"
  e_named=0; grep -q 'exited 0 with no globs' "$SS/err" && e_named=1
  if [ "$rc_f" = "2" ] && [ "$f_named" = 1 ] && [ "$rc_e" = "2" ] && [ "$e_named" = 1 ]; then
    ok "a resolver exiting non-zero, or exiting 0 with no globs, names the cause and exits 2"
  else
    bad "a failing/empty resolver was not refused (non-zero: rc=$rc_f named=$f_named; empty: rc=$rc_e named=$e_named) — it was scored as ownership"
  fi
fi

# ============== --fail-on=local-deterministic: TIER 1 AND (LOCAL OR UNRESOLVED) ==============
# The consumer pre-push's threshold. `deterministic` is owner-blind (a core-owned tier-1 finding
# blocks a push whose only remedy is a write Rule 27 forbids) and `local` counts the judgement tier
# (a tier-2 finding would block a push the hook says only tier 1 gates). Four worlds, ONE seed each,
# so each wrong predicate moves exactly one cell:
#   LDc  core-owned tier-1      -> rc 0, ORIGIN_TAG printed `[core 1`     (kills owner-blind)
#   LDl  local tier-1           -> rc 1, ORIGIN_TAG printed `[local]`
#   LD2  local tier-2 only      -> rc 0, NARRATIVE_DRIFT printed `[core 0 / local 1` (kills tier-blind)
#   LDu  tier-1, resolver gone  -> rc 1, `unresolved 1`                    (kills unresolved-dropped)
# Every rc-0 cell carries a presence conjunct, so a subject that scans nothing cannot pass it.
LD=--fail-on=local-deterministic
LDTAG='The lead MUST re-run the gate; this replaced the v0.42.0 behaviour.'
ldc_world() { fresh; echo "$LDTAG" >> "$WORK/t/.claude/skills/ai-dlc/SKILL.md"; }
ldl_world() { fresh; echo "$LDTAG" >> "$WORK/t/docs/coding-conventions.md"; }
ld2_world() { fresh; printf 'The dev MUST comply, because we lost a sprint to this.\n' >> "$WORK/t/docs/coding-conventions.md"; }
LDU="$WORK/ldnores"; mkdir -p "$LDU"
ld_c() { # <script> -> "rc|presence" in LDc
  ldc_world; local o r
  o="$(memo out 0 "$WORK/t" "$1" "$LD")"; r="$(memo rc 0 "$WORK/t" "$1" "$LD")"
  if has 'ORIGIN_TAG: FLAGGED.*\[core 1 / local 0\]' "$o" && has 'locally-owned: 0   unresolved: 0' "$o"; then echo "$r|1"; else echo "$r|0"; fi
}
ld_l() { ldl_world; local o r
  o="$(memo out 0 "$WORK/t" "$1" "$LD")"; r="$(memo rc 0 "$WORK/t" "$1" "$LD")"
  if has '\[local\] docs/coding-conventions.md:[0-9]*  ORIGIN_TAG' "$o"; then echo "$r|1"; else echo "$r|0"; fi
}
ld_2() { ld2_world; local o r
  o="$(memo out 0 "$WORK/t" "$1" "$LD")"; r="$(memo rc 0 "$WORK/t" "$1" "$LD")"
  if has 'NARRATIVE_DRIFT: FLAGGED.*\[core 0 / local 1\]' "$o" && has 'tier-1 findings: 0 ' "$o"; then echo "$r|1"; else echo "$r|0"; fi
}
ld_u() { # <script> -> "rc|presence" in LDc's world, the script copied ALONE (no resolver beside it)
  ldc_world; local o r s="$LDU/${1##*/}"
  cp "$1" "$s"
  if [ -f "$LDU/core-paths.sh" ]; then echo "broken|0"; return; fi
  o="$(memo out 0 "$WORK/t" "$s" "$LD")"; r="$(memo rc 0 "$WORK/t" "$s" "$LD")"
  if has 'ORIGIN_TAG: FLAGGED.*unresolved 1\]' "$o"; then echo "$r|1"; else echo "$r|0"; fi
}

c="$(ld_c "$AUDIT")"
[ "$c" = "0|1" ] \
  && { ok "LDc: a CORE-owned tier-1 finding prints [core 1 and does NOT fail $LD"; B_ldc=1; } \
  || bad "LDc: a core-owned tier-1 finding under $LD gave rc|printed=$c, want 0|1 — the consumer push is gated on a file it may not edit, or the finding went silent"
c="$(ld_l "$AUDIT")"
[ "$c" = "1|1" ] \
  && ok "LDl: a LOCAL tier-1 finding prints [local] and DOES fail $LD" \
  || bad "LDl: a locally-owned tier-1 finding under $LD gave rc|printed=$c, want 1|1 — the gate cannot fire"
c="$(ld_2 "$AUDIT")"
[ "$c" = "0|1" ] \
  && { ok "LD2: a LOCAL tier-2-only finding prints [local 1 and does NOT fail $LD (only tier 1 gates the push)"; B_ld2=1; } \
  || bad "LD2: a local tier-2-only finding under $LD gave rc|printed=$c, want 0|1 — the judgement tier gates the push"
c="$(ld_u "$AUDIT")"
[ "$c" = "1|1" ] \
  && { ok "LDu: a tier-1 finding with NO resolver counts as unresolved and FAILS $LD — a missing resolver cannot acquit"; B_ldu=1; } \
  || bad "LDu: an unresolved tier-1 finding under $LD gave rc|printed=$c, want 1|1 — an unresolvable owner acquitted the push"
# The control that makes LDu readable: the same world through the real script WITH its resolver is LDc,
# which must be rc 0. LDu's rc 1 is therefore the resolver's absence, not a copy that cannot run.
[ "${B_ldc:-0}" = 1 ] \
  && ok "  control: the LDu world with the resolver present is LDc (rc 0) — LDu's rc 1 is the absence" \
  || bad "  control FAILED: LDc did not pass, so LDu's rc 1 is unreadable"

# MUTANTS of the new threshold, each a COPY beside $WORK/core-paths.sh, `cmp -s` guarded by mkmut.
# Each is scored by its own cell ALONE; the other three cells read the same under it (measured).
#   ld-ownerblind  the gate counts every tier-1 finding          -> LDc moves to rc 1
#   ld-tierblind   the gate counts local + unresolved, any tier  -> LD2 moves to rc 1
#   ld-unresdrop   the counter drops the unresolved half          -> LDu moves to rc 0
if mkmut ld-ownerblind 's/^    _gated = t1_local_findings$/    _gated = t1_findings/'; then
  c="$(ld_c "$WORK/ld-ownerblind.sh")"
  if [ "$c" = "1|1" ]; then
    mutant_killed "${B_ldc:-0}" ld-ownerblind "MUTANT ld-ownerblind (gate = every tier-1 finding) -> LDc's core-owned finding fails the push; killed"
  else
    bad "ld-ownerblind SURVIVED: LDc gave rc|printed=$c under the owner-blind gate — LDc cannot tell the threshold from deterministic"
  fi
else
  bad "ld-ownerblind DID NOT APPLY — its anchor in audit-rule-files.sh is gone, so LDc is unproven"
fi
if mkmut ld-tierblind 's/^    _gated = t1_local_findings$/    _gated = local_findings + unresolved_findings/'; then
  c="$(ld_2 "$WORK/ld-tierblind.sh")"
  if [ "$c" = "1|1" ]; then
    mutant_killed "${B_ld2:-0}" ld-tierblind "MUTANT ld-tierblind (gate = local + unresolved, both tiers) -> LD2's tier-2 finding fails the push; killed"
  else
    bad "ld-tierblind SURVIVED: LD2 gave rc|printed=$c under the tier-blind gate — LD2 cannot tell the threshold from local"
  fi
else
  bad "ld-tierblind DID NOT APPLY — its anchor in audit-rule-files.sh is gone, so LD2 is unproven"
fi
if mkmut ld-unresdrop 's/^        t1_local_findings += n_local + n_unknown$/        t1_local_findings += n_local/'; then
  c="$(ld_u "$WORK/ld-unresdrop.sh")"
  if [ "$c" = "0|1" ]; then
    mutant_killed "${B_ldu:-0}" ld-unresdrop "MUTANT ld-unresdrop (unresolved dropped from the gate) -> LDu's unresolved tier-1 finding acquits; killed"
  else
    bad "ld-unresdrop SURVIVED: LDu gave rc|printed=$c with the unresolved half dropped — the safety property is unguarded"
  fi
else
  bad "ld-unresdrop DID NOT APPLY — its anchor in audit-rule-files.sh is gone, so LDu is unproven"
fi

# ============== THE CONSUMER HOOK, EXECUTED WHOLE (receipt-bl977.sh) ==============
# A static gate cannot see the hook's audit argv: a misspelled flag VALUE passes every one and wedges
# every consumer push with exit 2. So the WHOLE hook is driven in a scratch consumer git repo by the
# BL-977 receipt, and the verdict is the PASS/FAIL closing the hook's `rule-file audit` block.
# The hook is resolved as agent-definition-render resolves it: `core/git-hooks/pre-push` in the
# distribution, `.githooks/pre-push` installed (in the distribution that path is the distribution's
# OWN runner, not the subject). A consumer that carried a diverged hook holds no local-deterministic
# step until the step-7 merge; there the arm reports PENDING rather than wedging live work. In the
# distribution layout it asserts unconditionally.
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd)"
HOOK=""; HLAYOUT=""
if [ -f "$ROOT/core/git-hooks/pre-push" ]; then
  HOOK="$ROOT/core/git-hooks/pre-push"; HLAYOUT=distribution
elif [ "$AUDIT" = "$ROOT/scripts/ai-dlc/audit-rule-files.sh" ] && [ -f "$ROOT/.githooks/pre-push" ]; then
  HOOK="$ROOT/.githooks/pre-push"; HLAYOUT=installed
fi
if [ -z "$HOOK" ]; then
  bad "FIXTURE BROKEN — the consumer pre-push hook was found in neither layout (core/git-hooks/pre-push, or .githooks/pre-push installed)"
elif [ "$HLAYOUT" = installed ] && ! grep -q -- '--fail-on=local-deterministic' "$HOOK"; then
  echo "  hook:    ${HOOK#"$ROOT"/} ($HLAYOUT)"
  # The grep above READ the hook and decided this branch, so the required input was consumed; without this
  # line hermetic-run fails the PENDING state as an unconsumed input, which is the wedge PENDING exists to avoid.
  echo "HERMETIC-CONSUMED ${HOOK#"$ROOT"/}"
  echo "  PENDING: installed hook carries no local-deterministic audit step (carried hook awaits the step-7 merge)"
else
  echo "  hook:    ${HOOK#"$ROOT"/} ($HLAYOUT)"
  echo "HERMETIC-CONSUMED ${HOOK#"$ROOT"/}"
  ro="$(bash "$HERE/receipt-bl977.sh" --root "$ROOT" --hook "$HOOK" 2>&1)"; rrc=$?
  if [ "$rrc" = 0 ] && has '^CELL core-t1 block=PASS core1=yes$' "$ro" && has '^CELL local-t1 block=FAIL local1=yes$' "$ro" \
     && has '^CELL local-t2 rc=0 drift-local=yes$' "$ro"; then
    ok "the WHOLE consumer hook: core-owned tier-1 -> audit block PASS with [core 1 printed; local tier-1 -> block FAIL (receipt-bl977 rc 0)"; B_hook=1
  else
    bad "the consumer hook's rule-file audit block did not gate on ownership (receipt rc=$rrc): $(grep -E '^CELL|BROKEN' <<<"$ro" | paste -sd';' -)"
  fi
  # MUTANT: a COPY of the RESOLVED hook with the flag reverted. Killed by the core-t1 cell alone.
  HM="$WORK/hookmut"; mkdir -p "$HM"
  sed 's/--fail-on=local-deterministic/--fail-on=deterministic/' "$HOOK" > "$HM/pre-push"
  if cmp -s "$HOOK" "$HM/pre-push"; then
    bad "hook-det DID NOT APPLY — the resolved hook carries no --fail-on=local-deterministic to revert"
  else
    mo="$(bash "$HERE/receipt-bl977.sh" --root "$ROOT" --hook "$HM/pre-push" 2>&1)"
    if has '^CELL core-t1 block=FAIL core1=yes$' "$mo" && has '^CELL local-t1 block=FAIL local1=yes$' "$mo"; then
      mutant_killed "${B_hook:-0}" hook-det "MUTANT hook-det (hook flag reverted to deterministic) -> the core-owned tier-1 finding blocks the push; killed"
    else
      bad "hook-det SURVIVED: $(grep -E '^CELL|BROKEN' <<<"$mo" | paste -sd';' -) — the hook arm cannot see the flag"
    fi
  fi
fi

# ================= Class 1d: ROLE_MODEL_NAMING (distribution layout) =================
# The arm runs only in the distribution layout, so it gets its own DISTRIBUTION tree:
# the consumer corpus above can only ever show its N/A line. Every assertion is
# PRESENCE-shaped (a named verdict line must APPEAR), so a subject that emits nothing
# fails them, and two committed mutants prove the arm and its self-probe each fire.
DW="$WORK/dist"
dfresh() {
  rm -rf "$DW"
  mkdir -p "$DW/core/skills/ai-dlc/steps" "$DW/core/team-roles" \
           "$DW/core/skills/ai-dlc-update" "$DW/core/skills/ai-dlc-setup"
  printf '# Skill\n\nThe lead MUST run the gate.\n' > "$DW/core/skills/ai-dlc/SKILL.md"
  printf '# Core manifest\n\ncore_manifest:\n  - SKILL.md\n  - steps/*.md\n' \
    > "$DW/core/skills/ai-dlc/core-manifest.md"
  printf 'The step runs on a fresh, independent context.\n' > "$DW/core/skills/ai-dlc/steps/example.md"
  printf '# Role: Developer\n\nYou implement the story.\n' > "$DW/core/team-roles/dev.md"
  printf '# Update\n\nSetup-token defaults are resolved from `aiDlcRoles`.\n' \
    > "$DW/core/skills/ai-dlc-update/SKILL.md"
  printf '# Setup\n\nThe `model` enum is opus, sonnet or haiku.\n' > "$DW/core/skills/ai-dlc-setup/SKILL.md"
}
daudit() { ( cd "$DW" && bash "${1:-$AUDIT}" --fail-on=deterministic 2>&1 ); }
drc()    { ( cd "$DW" && bash "${1:-$AUDIT}" --fail-on=deterministic >/dev/null 2>&1; echo $? ); }

dfresh
out="$(daudit)"
if has 'layout: distribution' "$out" && has 'ROLE_MODEL_NAMING: CLEAN' "$out" && [ "$(drc)" = "0" ]; then
  ok "distribution tree with model names only in ai-dlc-setup -> ROLE_MODEL_NAMING CLEAN, exit 0"
else
  bad "the clean distribution tree did not score ROLE_MODEL_NAMING CLEAN at exit 0 — Class 1d's arms below are unreadable"
fi

# World D: every FIRING seed in ONE distribution tree, each on its own line, so a line number can only
# come from its own seed. dev.md:4 Opus tier (34), :5 R1, :6 E1; ai-dlc-update/SKILL.md:4 the reversed
# coupling (35), :5 R2, :6 E2; steps/example.md:2 R3, :3 E3; ai-dlc/SKILL.md:4 T1.
#   R1 ranks with no tier word, R2 is the coupling model-before-adversary, R3 is the stale claim that a
#   role FILE pins the model. E1/E2 are the natural rewordings of code-reviewer-escalated.md:62 and :66 at
#   fc71a7b10, the sites the arm was built on; E3 is a bare "of the escalation" suffix; T1 names a tier-1
#   class but is not the "tier-<n> finding stays at this tier" shape. Only "of the escalation ladder" and
#   that one shape are exempt, so all four must fire.
dworld() {
  dfresh
  echo 'You are dispatched on the Opus tier.' >> "$DW/core/team-roles/dev.md"
  echo 'You run on a more capable model than `dev`.' >> "$DW/core/team-roles/dev.md"
  echo 'The lead binds your tier of the escalation by routing the review to you.' >> "$DW/core/team-roles/dev.md"
  echo 'Defaults: the `adversary`'"'"'s model is taken for `gate-adjudicator`.' \
    >> "$DW/core/skills/ai-dlc-update/SKILL.md"
  echo '`gate-adjudicator` defaults to the model `adversary` uses.' \
    >> "$DW/core/skills/ai-dlc-update/SKILL.md"
  echo 'the lead chose this tier of the escalation by routing the review here.' \
    >> "$DW/core/skills/ai-dlc-update/SKILL.md"
  echo 'the dispatch guard binds `dev`'"'"'s model to `dev.md`'"'"'s pin' \
    >> "$DW/core/skills/ai-dlc/steps/example.md"
  echo 'you are already on this tier of the escalation path.' >> "$DW/core/skills/ai-dlc/steps/example.md"
  echo 'A tier-1 finding is routed here because the lead chose this tier for the review.' \
    >> "$DW/core/skills/ai-dlc/SKILL.md"
}
dworld
out="$(daudit)"
if has 'core/team-roles/dev.md:4  ROLE_MODEL_NAMING' "$out" && has 'ROLE_MODEL_NAMING: FLAGGED' "$out" \
   && [ "$(drc)" = "1" ]; then
  ok "seeded 'the Opus tier' in a role file -> ROLE_MODEL_NAMING FLAGGED, --fail-on=deterministic exit 1"; B_d34=1
else
  bad "a model named in a role file went undetected — Class 1d cannot fire"
fi
has 'core/skills/ai-dlc-update/SKILL.md:4  ROLE_MODEL_NAMING' "$out" \
  && ok "the adversary-model -> gate-adjudicator coupling, reversed word order -> FLAGGED" \
  || bad "the stale coupling went undetected when spelled adversary-first"
has 'core/team-roles/dev.md:5  ROLE_MODEL_NAMING' "$out" \
  && ok "R1 'a more capable model than dev' in a role file -> FLAGGED" \
  || bad "R1, a model ranking with no tier word, went undetected"
has 'core/skills/ai-dlc-update/SKILL.md:5  ROLE_MODEL_NAMING' "$out" \
  && ok "R2 'gate-adjudicator defaults to the model adversary uses' -> FLAGGED" \
  || bad "R2, the coupling spelled model-before-adversary, went undetected"
has 'core/skills/ai-dlc/steps/example.md:2  ROLE_MODEL_NAMING' "$out" \
  && ok "R3 'binds dev's model to dev.md's pin' in a step file -> FLAGGED" \
  || bad "R3, the stale role-file-pins-the-model claim, went undetected"
has 'core/team-roles/dev.md:6  ROLE_MODEL_NAMING' "$out" \
  && ok "E1 'binds your tier of the escalation' -> FLAGGED" \
  || bad "E1, the reworded :62 site, was acquitted by a bare 'of the escalation' exemption"
has 'core/skills/ai-dlc-update/SKILL.md:6  ROLE_MODEL_NAMING' "$out" \
  && ok "E2 'chose this tier of the escalation' -> FLAGGED" \
  || bad "E2, the reworded :66 site, was acquitted by a bare 'of the escalation' exemption"
has 'core/skills/ai-dlc/steps/example.md:3  ROLE_MODEL_NAMING' "$out" \
  && ok "E3 'this tier of the escalation path' -> FLAGGED" \
  || bad "E3, a bare 'of the escalation' suffix, was acquitted"
has 'core/skills/ai-dlc/SKILL.md:4  ROLE_MODEL_NAMING' "$out" \
  && ok "T1 'a tier-1 finding ... the lead chose this tier' -> FLAGGED" \
  || bad "T1 was acquitted by a whole-line tier-<n> guard"

# --- Assertion 36: near-misses INSIDE the population stay quiet
dfresh
printf 'Record `model_family=OPUS` in the row.\nThe three-tier escalation stays.\n' \
  >> "$DW/core/skills/ai-dlc/steps/example.md"
printf 'A tier-1 finding stays at this tier until the retro dispositions it.\n' \
  >> "$DW/core/skills/ai-dlc/steps/example.md"
printf 'When the story leaves your tier of the escalation ladder, message the lead.\n' \
  >> "$DW/core/team-roles/dev.md"
out="$(daudit)"
has 'ROLE_MODEL_NAMING: CLEAN' "$out" \
  && ok "model_family=OPUS, 'three-tier escalation', 'tier-1 ... this tier', 'your tier of the escalation' -> CLEAN" \
  || bad "a mechanism enum, the escalation ladder or a finding tier was flagged as a role-model claim"


# --- Assertion 38: MUTANTS, each a copy of the audit beside its real resolver ---------
# M1 empties the corpus emit: the seeded role-file hit must then score CLEAN, which
# proves Assertion 34's FLAGGED came from this arm. M2 blinds the regex: the self-probe
# must then refuse with exit 2 BEFORE any corpus verdict, which proves the probe fires.
DM="$WORK/dmut"; mkdir -p "$DM"
cp "$(dirname "$AUDIT")/core-paths.sh" "$DM/core-paths.sh"
sed 's/emit("ROLE_MODEL_NAMING", model_hits(_pop), 1/emit("ROLE_MODEL_NAMING", [], 1/' "$AUDIT" > "$DM/m1.sh"
sed 's/m = MODEL_RX.search(raw)/m = None/' "$AUDIT" > "$DM/m2.sh"
if cmp -s "$AUDIT" "$DM/m1.sh" || cmp -s "$AUDIT" "$DM/m2.sh"; then
  bad "a Class 1d mutation DID NOT APPLY — its anchor is gone, so the mutant proves nothing"
else
  dworld
  out1="$(daudit "$DM/m1.sh")"; rc2="$(drc "$DM/m2.sh")"; err2="$(daudit "$DM/m2.sh")"
  if has 'ROLE_MODEL_NAMING: CLEAN' "$out1" && [ "$(drc)" = "1" ]; then
    mutant_killed "${B_d34:-0}" m1 "MUTANT m1 (arm emits nothing) -> the seeded hit scores CLEAN; unmutated exits 1 on the same tree"
  else
    bad "m1 SURVIVED: MUTANT m1 survived or its control is dead — Assertion 34 is not proven by Class 1d"
  fi
  if [ "$rc2" = "2" ] && has 'ROLE_MODEL_NAMING self-probe' "$err2"; then
    mutant_killed "${B_d34:-0}" m2 "MUTANT m2 (regex blinded) -> the self-probe refuses with exit 2 before the corpus"
  else
    bad "m2 SURVIVED: rc=$rc2 — the self-probe cannot fire"
  fi
fi

# ======================= twins (every push) and the matrix (--matrix only) ==========================
# A row signature is every class row of a report without its tier or owner suffix. A cell is the set of
# class rows a mutant CHANGES in one world against the real script on the same world. Both runs go
# through the memo, so a (world, script) pair already driven above costs nothing here.
sig() { grep -E '^  [A-Z][A-Z_0-9]*: ' <<<"$1" | sed 's/  (.*//'; }
chg() { # <base report> <mutant report> -> comma list of changed class rows, ALL for an empty report, none
  local b m
  b="$(sig "$1")"; m="$(sig "$2")"
  if [ -z "$m" ]; then echo ALL; return; fi
  { diff <(echo "$b") <(echo "$m") | grep '^>' | sed -E 's/^> +([A-Z_0-9]+):.*/\1/' | sort -u | paste -sd, -; } || true
}
cell() { # <world fn> <mutant script> <mutant env 0|1>
  local dir args base mut r
  "$1"
  if [ "$1" = dworld ]; then dir="$DW"; args=--fail-on=deterministic; else dir="$WORK/t"; args=; fi
  base="$(memo out 0 "$dir" "$AUDIT" $args)"
  mut="$(memo out "$3" "$dir" "$2" $args)"
  r="$(chg "$base" "$mut")"
  # A mutant that REFUSES (exit 2, the self-probe) where the real script does not has moved every row.
  if [ "$(memo rc "$3" "$dir" "$2" $args)" = 2 ] && [ "$(memo rc 0 "$dir" "$AUDIT" $args)" != 2 ]; then r=REFUSED; fi
  echo "${r:-none}"
}
twin() { # <twin arm> <mutant id> <world fn> <script> <env>
  local c
  c="$(cell "$3" "$4" "$5")"
  if [ "$c" = none ]; then
    ok "TWIN world $1: mutant $2 changes no row in world $3 (stays green)"
  else
    bad "TWIN world $1: mutant $2 moved rows [$c] in world $3 — the mutation is not confined to its deciding arm"
  fi
}
if [ -f "$WORK/um1.sh" ] && [ -f "$WORK/uq17.sh" ] && [ -f "$WORK/umo.sh" ] && [ -f "$DM/m2.sh" ]; then
  for _m in um1 um2 um3 um4 um5 um6 um7 um8 umr; do twin P1 "$_m" p1_world "$WORK/$_m.sh" 0; done
  for _m in uq1 uq2 uq3 uq4 uq5 uq6 uq7 uq8 uq9 uq10 uq11 uq12 uq13 uq14 uq15 uq16 uq17; do twin P1 "$_m" p1_world "$WORK/$_m.sh" 0; done
  twin U umf wu_world "$WORK/umf.sh" 0
  twin U umo wu_world "$WORK/umo.sh" 0
  twin P1 m1 p1_world "$DM/m1.sh" 0
  twin P1 m2 p1_world "$DM/m2.sh" 0
  twin P1 tier1-strip p1_world "$AUDIT" 1
  twin P1 grant-strip p1_world "$AUDIT" 1
else
  bad "FIXTURE BROKEN — a mutant copy the twins drive does not exist, so the twin arms prove nothing"
fi

mcells=0
if [ "$MATRIX" = 1 ]; then
  echo "MATRIX: one row per mutant; dead= the worlds (arms) where it changes a row, green= where it changes none"
  for _e in "um1|$WORK/um1.sh|0" "um2|$WORK/um2.sh|0" "um3|$WORK/um3.sh|0" "um4|$WORK/um4.sh|0" \
            "um5|$WORK/um5.sh|0" "um6|$WORK/um6.sh|0" "um7|$WORK/um7.sh|0" "um8|$WORK/um8.sh|0" \
            "umr|$WORK/umr.sh|0" "uq1|$WORK/uq1.sh|0" "uq2|$WORK/uq2.sh|0" "uq3|$WORK/uq3.sh|0" "uq4|$WORK/uq4.sh|0" "uq5|$WORK/uq5.sh|0" "uq6|$WORK/uq6.sh|0" "uq7|$WORK/uq7.sh|0" "uq8|$WORK/uq8.sh|0" "uq9|$WORK/uq9.sh|0" "uq10|$WORK/uq10.sh|0" "uq11|$WORK/uq11.sh|0" "uq12|$WORK/uq12.sh|0" "uq13|$WORK/uq13.sh|0" "uq14|$WORK/uq14.sh|0" "uq15|$WORK/uq15.sh|0" "uq16|$WORK/uq16.sh|0" "uq17|$WORK/uq17.sh|0" "umf|$WORK/umf.sh|0" "umo|$WORK/umo.sh|0" "m1|$DM/m1.sh|0" "m2|$DM/m2.sh|0" \
            "tier1-strip|$AUDIT|1" "grant-strip|$AUDIT|1"; do
    _id="${_e%%|*}"; _r="${_e#*|}"; _sc="${_r%%|*}"; _ev="${_r##*|}"
    _dead=""; _green=""
    for _w in wu_world:U wq_world:UQ p1_world:P1 wt_world:T wg_world:G dworld:D; do
      _c="$(cell "${_w%%:*}" "$_sc" "$_ev")"; mcells=$((mcells+1))
      if [ "$_c" = none ]; then _green="$_green ${_w##*:}=0"; else _dead="$_dead ${_w##*:}=1[$_c]"; fi
    done
    echo "MATRIX-ROW $_id dead:${_dead:- -} green:${_green:- -}"
  done
  [ "$mcells" = 192 ] \
    && ok "matrix mode: 192 mutant x world cells measured (32 mutants x 6 worlds)" \
    || bad "matrix mode measured $mcells cells, not 192"
else
  [ "$mcells" = 0 ] \
    && ok "plain run: no matrix-only cell was driven" \
    || bad "a plain run drove $mcells matrix-only cells"
fi
echo
if [ "$fails" -eq 0 ]; then echo "retro-audit-scans: PASS"; exit 0; fi
echo "retro-audit-scans: $fails assertion(s) FAILED" >&2
exit 1
