#!/usr/bin/env bash
# enforcement-map-sites — assert I8's site table cannot go quiet.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH. install.sh and reconcile/preclassify.sh's
# map_consumer() are two writers of the same consumer files, and they must agree on the
# destination or the consumer gets two copies at two paths — and the one the pull keeps
# fresh is not the one anything reads. I8 asserts that agreement. It has now been wrong
# three times, and the third is why this fixture exists:
#
#   fixtures     -> .claude/fixtures/     (dead; H1 reads tests/fixtures/)
#   ci-templates -> .claude/ci-templates/ (dead; workflows run from .github/workflows/)
#   git-hooks    -> .claude/git-hooks/    (dead; install.sh writes .githooks/)
#
# The first two were found and I8 gained a row for each. git-hooks was NOT found, and the
# reason is the whole lesson: I8's site list was HAND-MAINTAINED, so the check did not
# fail on core/git-hooks/ — it simply had no row for it, and a check that cannot fire
# reads exactly like a check that passed. v0.53.0's pre-push gate — shipped as the
# replacement for the deleted CI workflow — therefore reached the reference consumer at a
# path no runner, no `core.hooksPath`, and no script reads. That consumer had Actions
# disabled, so its ONLY automated gate could not fire, and nothing said so for two minors.
#
# So the assertions below are about the CHECK, not about today's table. A table with the
# right rows in it today proves nothing; what must hold is that a missing row, a wrong
# mapping, or a destination the installer never writes each FAILS. Assertion 0 exists
# because every negative assertion here would score a false pass against a validator that
# is simply broken and erroring for unrelated reasons.
set -uo pipefail

# I10's scrub. Assertion 31 names a hook path (it mutates ai-dlc-dispatch-guard.sh to prove
# I56 fires), which puts this file in I10's hook-driving set. It never EXECUTES the hook, so
# the scrub is belt-and-braces rather than load-bearing — but the honest move on a check that
# fired is to satisfy it, not to narrow its grammar until it stops seeing this file.
#
# Ordered before HERE= and before the pool: the worker wrapper reads AI_DLC_EMS_SELF and
# AI_DLC_EMS_OUT in its own `bash -c`, ahead of the run.sh it then invokes, so unsetting them
# here cannot reach the values already resolved.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"

# Distribution-only. `validate-enforcement-map.sh` is not shipped by install.sh (it checks
# the distribution's own two writers against each other — a consumer has neither), so in a
# consumer tree there is nothing to test. Say so and stop; do not fake a pass.
if [ ! -f "$HERE/../../../scripts/validate-enforcement-map.sh" ]; then
  echo "enforcement-map-sites: SKIP — distribution-only (validate-enforcement-map.sh is not shipped to consumers)"
  exit 0
fi

# ONE TREE PER ASSERTION, IN ONE PROCESS PER ASSERTION, AND THE REASON IS WALL CLOCK.
# Every assertion here mutates a pristine copy of the distribution and runs
# `validate-enforcement-map.sh` over it. There are 42 of those runs at ~2.5s each, and run
# end to end they made this fixture the entire critical path of the 8-way pre-push suite:
# measured 2026-07-29, it started at t=5s and finished at t=124.9s in a 124.9s suite, while
# the next-longest unit finished at t=85s with 40s to spare. The suite's wall clock WAS
# this file.
#
# Nothing about that is a property of the assertions. Each one already re-seeded a pristine
# tree before it ran (the old `restore`), so no assertion could see another's mutation --
# they were independent and merely happened to be written in a row. So each is now a
# function, each runs in its own process against its own seed, and the driver at the foot
# of this file runs them through a worker pool.
#
# WHAT THIS MUST NOT COST: fidelity. Same subject set, same mutations, same predicates,
# same messages, same order in the output. The proof is a byte-identical differential of
# this file's whole stdout against the serial version, plus the knock-out control described
# at the driver.
#
# THE CONTROL STAYS SERIAL AND STAYS FIRST. Assertion 0 asserts the PRISTINE tree passes;
# without it every "it failed as expected" below is a false pass against a validator that
# is simply broken. Running it concurrently with the assertions it licenses would report
# them in an order where that licence had not yet been established.
seed_tree() {
  ROOT="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
  V="$ROOT/scripts/validate-enforcement-map.sh"
  PRECLASS="$ROOT/core/skills/ai-dlc-update/reconcile/preclassify.sh"
  INSTALL="$ROOT/scripts/install.sh"
}

fails=0
broken=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# Restore the seed to pristine between the ARMS of one assertion. Several assertions mutate
# the tree two or three times and need a clean one between arms; that is all this is for
# now. It no longer runs between assertions -- each gets its own tree at entry.
restore() { local old="$ROOT"; seed_tree; rm -rf "$old"; }

# --- Assertion 0: SANITY ------------------------------------------------------
# The pristine tree must PASS. If it does not, the validator is erroring for some reason
# of its own and every "it failed as expected" below is a false pass.
A00_sanity() {
if bash "$V" >/dev/null 2>&1; then
  ok "pristine distribution tree passes (the negatives below mean something)"
else
  bad "FIXTURE BROKEN — the pristine tree does not pass validate-enforcement-map.sh. Every assertion below would be a false pass."
fi
}

# --- Assertion 1: COMPLETENESS ------------------------------------------------
# A new core/<dir>/ with no row must be an ERROR, not a silent fall-through to the
# `core/*` catch-all. This is the one that would have caught git-hooks.
A01_i8_completeness() {
mkdir -p "$ROOT/core/brand-new-subtree"
echo 'x' > "$ROOT/core/brand-new-subtree/thing.sh"
out="$(bash "$V" 2>&1)"
if grep -q "core/brand-new-subtree/ has no destination row" <<<"$out"; then
  ok "a new core/ subtree with no site row FAILS (the catch-all can no longer swallow one silently)"
else
  bad "a new core/ subtree with no site row did NOT fail — I8 is hand-listed again, and the next core/<dir>/ ships to a path nothing reads"
fi
restore
}

# --- Assertion 2: AGREEMENT ---------------------------------------------------
# Delete map_consumer()'s git-hooks case and I8 must catch it. This replays the exact
# v0.55.1 state of the tree: install.sh writes .githooks/, the pull writes .claude/git-hooks/.
A02_i8_agreement() {
grep -q 'core/git-hooks/\*)' "$PRECLASS" || bad "FIXTURE STALE: preclassify.sh has no core/git-hooks/ case to remove"
sed -i.bak '/core\/git-hooks\/\*)/d' "$PRECLASS"
out="$(bash "$V" 2>&1)"
if grep -q "disagree on where core/git-hooks/ goes" <<<"$out"; then
  ok "map_consumer() losing its git-hooks case FAILS (the v0.53.0 regression cannot return)"
else
  bad "map_consumer() with no git-hooks case did NOT fail — the pre-push gate would ship to .claude/git-hooks/ again"
fi
restore
}

# --- Assertion 3: INSTALLER BINDING -------------------------------------------
# A row is only true if install.sh really writes there. Remove the .githooks write and the
# row must stop being satisfiable — otherwise the table could be kept "green" by asserting
# a destination the installer abandoned.
A03_i8_installer_binding() {
grep -q 'PROJECT_ROOT/.githooks' "$INSTALL" || bad "FIXTURE STALE: install.sh has no .githooks write to remove"
sed -i.bak 's|"\$PROJECT_ROOT/\.githooks|"$PROJECT_ROOT/.githooks-REMOVED|g' "$INSTALL"
out="$(bash "$V" 2>&1)"
if grep -q "install.sh never writes" <<<"$out"; then
  ok "a site row whose destination install.sh abandoned FAILS (the table is bound to the installer, not to itself)"
else
  bad "install.sh dropping .githooks did NOT fail — I8's table can assert a destination nothing writes"
fi
restore
}

# --- Assertion 4: I12 SCAN-MATCH ----------------------------------------------
# unregistered-drift.sh's scan set is bound to I12's per-subtree policy. Drop a scan-marked
# subtree from the tool's ls-tree and I12 must catch the divergence — this is what stops the
# scan set silently rotting the way ai-dlc-setup/ and schemas/ did.
A04_i12_scan_match() {
UD="$ROOT/core/skills/ai-dlc-update/reconcile/unregistered-drift.sh"
if grep -q 'core/hooks core/schemas' "$UD"; then
  sed -i.bak 's| core/hooks core/schemas | core/hooks |' "$UD"
  out="$(bash "$V" 2>&1)"
  if grep -q "I12:.*does NOT scan them: schemas" <<<"$out"; then
    ok "unregistered-drift.sh dropping core/schemas from its scan FAILS I12 (the scan set is bound, not hand-listed)"
  else
    bad "dropping core/schemas from the scan did NOT fail I12 — the scan set can rot silently again"
  fi
  restore
else
  bad "FIXTURE STALE: unregistered-drift.sh no longer scans 'core/hooks core/schemas'"
fi
}

# --- Assertion 5: I12 COMPLETENESS --------------------------------------------
# A new core/<dir>/ with no policy row must FAIL — a new subtree cannot silently escape the scan.
A05_i12_completeness() {
mkdir -p "$ROOT/core/brand-new-subtree"
echo 'x' > "$ROOT/core/brand-new-subtree/thing.md"
out="$(bash "$V" 2>&1)"
if grep -q "core/brand-new-subtree/ has no drift-scan policy row" <<<"$out"; then
  ok "a new core/ subtree with no I12 policy row FAILS (a new dir must be classified scan/exempt before it can ship)"
else
  bad "a new core/ subtree with no I12 policy row did NOT fail — the scan set is hand-listed again"
fi
restore
}

# --- Assertion 6: I15 GRAMMAR FORK --------------------------------------------
# layer-drift.sh REPORTS a heading-number collision; relabel-extension-checks.sh FIXES it.
# relabel shipped the narrower grammar for ~20 versions, so core's real `### H1.` yielded no
# anchor and a collision on it was unrelabellable — the operator was told to relabel with a
# tool that could not see the heading. Narrow one copy and I15 must catch the fork.
A06_i15_grammar_fork() {
RELABEL="$ROOT/core/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh"
if grep -q '^ANCHOR_RE=' "$RELABEL"; then
  sed -i.bak "s|^ANCHOR_RE=.*|ANCHOR_RE='^#{2,4} [0-9]+[a-z]*\\\\.'|" "$RELABEL"
  out="$(bash "$V" 2>&1)"
  if grep -q "the anchor grammar has forked" <<<"$out"; then
    ok "narrowing relabel's ANCHOR_RE FAILS I15 (the reporter and the fixer cannot drift apart)"
  else
    bad "narrowing relabel's ANCHOR_RE did NOT fail I15 — the two grammars can fork again and H1-style collisions go unrelabellable"
  fi
  restore
  RELABEL="$ROOT/core/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh"
else
  bad "FIXTURE STALE: relabel-extension-checks.sh no longer defines ANCHOR_RE"
fi
}

# --- Assertion 7: I15 NON-VACUITY ---------------------------------------------
# I15 greps both files for ANCHOR_RE. If a definition simply vanishes, the check must say so
# rather than find nothing and pass — "no definitions to compare" must never read as "equal".
A07_i15_non_vacuity() {
# Bound here rather than inherited: when this file ran as one long script the name was
# still set from the assertion above. Each assertion now runs in its own process against
# its own tree, so an inherited path would be an unset variable under `set -u`.
RELABEL="$ROOT/core/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh"

if grep -q '^ANCHOR_RE=' "$RELABEL"; then
  sed -i.bak '/^ANCHOR_RE=/d' "$RELABEL"
  out="$(bash "$V" 2>&1)"
  if grep -q "I15 cannot find an ANCHOR_RE definition" <<<"$out"; then
    ok "deleting an ANCHOR_RE definition FAILS I15 loudly (it cannot pass by comparing nothing)"
  else
    bad "deleting an ANCHOR_RE definition did NOT fail I15 — the check goes vacuous exactly when the grammar is missing"
  fi
  restore
fi
}

# --- Assertion 7b: I17 THE WRITER ---------------------------------------------
# map_consumer() only CLASSIFIES. reconcile/apply.sh is what actually PLACES files on a pull,
# and it was bound to nothing — it kept a private hand-listed copy of the site table and
# omitted session-driver, ci-templates and git-hooks, which therefore never applied while the
# same run re-stamped .ai-dlc-version anyway. Give apply.sh a private table again and I17
# must catch it, exactly as I8 catches map_consumer drifting.
A08_i17_the_writer() {
APPLY_F="$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh"
if grep -q '^consumer_path() {' "$APPLY_F"; then
  python3 - "$APPLY_F" <<'PY'
import re, sys
p = sys.argv[1]; s = open(p).read()
# Reintroduce the exact defect: a hand-listed table with no session-driver case.
mutant = '''consumer_path() {
  case "$1" in
    team-roles/*) printf '%s/.claude/team-roles/%s' "$CONSUMER" "${1#team-roles/}" ;;
    *) return 1 ;;
  esac
}'''
s = re.sub(r'^consumer_path\(\) \{.*?^\}', mutant, s, count=1, flags=re.S | re.M)
open(p, 'w').write(s)
PY
  out="$(bash "$V" 2>&1)"
  if grep -q "sends core/session-driver/ to" <<<"$out"; then
    ok "apply.sh regrowing a private path table FAILS I17 (the pull's WRITER is bound to the installer, not just the classifier)"
  else
    bad "apply.sh with a hand-listed table missing session-driver did NOT fail I17 — a subtree can silently not apply while the run re-stamps, and the consumer's stamp claims a version its tree lacks"
  fi
  restore
else
  bad "FIXTURE STALE: apply.sh no longer defines consumer_path()"
fi
}

# --- Assertion 8: I16 DEAD PROSE PATH -----------------------------------------
# The real bug: Check 19 cited `core/team-roles/code-reviewer.md`, a path that exists in the
# distribution and at NO consumer. install.sh maps core/<x> -> .claude/<x>, but that moves
# FILES, not the paths written inside them. Plant one and I16 must fire.
A09_i16_dead_prose_path() {
printf '\nSee `core/team-roles/dev.md` for the map.\n' >> "$ROOT/core/skills/ai-dlc/steps/gate-validation.md"
out="$(bash "$V" 2>&1)"
if grep -q "runtime-pipeline prose cites a distribution path" <<<"$out"; then
  ok "a core/-prefixed prose path in a runtime step file FAILS I16 (installed core cannot ship a dead citation)"
else
  bad "a core/-prefixed prose path did NOT fail I16 — installed core can cite the distribution's layout again, and one dead link already cost a live gate rule"
fi
restore
}

# --- Assertion 9: I16 PRECISION -----------------------------------------------
# The other side of the same check, and the one that keeps it usable. The word "core" is
# everywhere in this rulebook ("core rule", "core catalog", "core-path wiring"), and the
# update machinery cites `core/...` paths BY DESIGN — comparing distribution to consumer is
# its whole job. If I16 flags either, it gets switched off and stops catching the real thing.
A10_i16_precision() {
printf '\nThe core rule lives in the core catalog; core-path wiring is a core concern.\n' \
  >> "$ROOT/core/skills/ai-dlc/steps/gate-validation.md"
printf '\nDiff base->theirs restricted to `core/skills/ai-dlc-update/**` and `core/team-roles/dev.md`.\n' \
  >> "$ROOT/core/skills/ai-dlc-update/SKILL.md"
out="$(bash "$V" 2>&1)"
if grep -q "runtime-pipeline prose cites a distribution path" <<<"$out"; then
  bad "I16 fired on the English word 'core' or on ai-dlc-update's by-design core/ citations — a check with false positives is a check the operator turns off"
else
  ok "I16 ignores the English word 'core' and ai-dlc-update's by-design core/ paths (precise enough to stay on)"
fi
restore
}

# --- Assertion 10: I21 FOURTH COPY --------------------------------------------
# `section_of()` shipped divergent twice (v0.52.0 weaker, v0.54.2 stricter), and both
# times the remedy was a hand-copy and a CHANGELOG line saying "there is one resolver".
# v0.90.0 collapsed the three copies into lib.sh — that fixed the INSTANCES. The HOLE is
# that nothing stopped a fourth file inlining its own, and a private resolver fails
# silently: the tool reports a confident verdict computed from a different section.
A11_i21_fourth_copy() {
RLIB_F="$ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
APPLY_F="$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh"
printf '\nsection_of() { echo private; }\n' >> "$APPLY_F"
out="$(bash "$V" 2>&1)"
if grep -q "I21 reconcile/apply.sh defines its own section_of()" <<<"$out"; then
  ok "a fourth inline section_of() FAILS I21 (the resolver cannot fork a third time)"
else
  bad "a fourth inline section_of() did NOT fail I21 — the divergence that shipped in v0.52.0 and v0.54.2 can return, and nothing compares the copies"
fi
restore
RLIB_F="$ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
}

# --- Assertion 11: I21 UNSOURCED CALL -----------------------------------------
# The other direction. A classifier that calls section_of() without sourcing lib.sh gets
# an EMPTY section back on a consumer's pull, and an empty section reads as "no drift"
# rather than as an error — the same shape as the v0.52.0 cleared block.
A12_i21_unsourced_call() {
REG_F="$ROOT/core/skills/ai-dlc-update/reconcile/register-drift.sh"
if grep -q '^\. "\$SELF/lib\.sh"' "$REG_F"; then
  sed -i.bak '/^\. "\$SELF\/lib\.sh"/d' "$REG_F"
  out="$(bash "$V" 2>&1)"
  if grep -q "I21 reconcile/register-drift.sh calls section_of() but never sources" <<<"$out"; then
    ok "a classifier that drops its lib.sh source FAILS I21 (a call that resolves to nothing cannot ship)"
  else
    bad "register-drift.sh dropping its lib.sh source did NOT fail I21 — section_of() resolves to nothing on a real pull and the empty section reads as 'no drift'"
  fi
  restore
  RLIB_F="$ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
else
  bad "FIXTURE STALE: register-drift.sh no longer sources lib.sh at the expected anchor"
fi
}

# --- Assertion 12: I21 NON-VACUITY --------------------------------------------
# I21 derives the helper set from lib.sh's own definitions. If those stop matching — the
# library emptied, or its definition form changed — the check must say so rather than bind
# an empty set and pass. "Nothing to compare" must never read as "no second copy exists".
A13_i21_non_vacuity() {
# Bound here rather than inherited: when this file ran as one long script the name was
# still set from the assertion above. Each assertion now runs in its own process against
# its own tree, so an inherited path would be an unset variable under `set -u`.
RLIB_F="$ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"

if grep -qE '^[a-z_]+\(\) \{' "$RLIB_F"; then
  grep -vE '^[a-z_]+\(\) \{' "$RLIB_F" > "$RLIB_F.tmp" && mv "$RLIB_F.tmp" "$RLIB_F"
  out="$(bash "$V" 2>&1)"
  if grep -q "I21 found no function definitions" <<<"$out"; then
    ok "lib.sh losing its definitions FAILS I21 loudly (it cannot pass by binding an empty helper set)"
  else
    bad "emptying lib.sh did NOT fail I21 — the check goes vacuous exactly when the single home stops being one"
  fi
  restore
else
  bad "FIXTURE STALE: reconcile/lib.sh no longer defines helpers in the '<name>() {' form I21 derives from"
fi
}

# --- Assertion 13: I31 SCAN SET HAS A DISPOSITION -----------------------------
# I12 makes a subtree REPORTABLE; it says nothing about what the operator does next, and the
# report hands them exactly one command. `skills/ai-dlc-setup` and `schemas` were both
# scan-marked and both fell to register-drift.sh's `unrecognized core path` — a message that
# reads like a typo in a path the report itself supplied. Drop the named no-grain refusal and
# I31 must name the subtrees left without a disposition.
A14_i31_disposition() {
RD_F="$ROOT/core/skills/ai-dlc-update/reconcile/register-drift.sh"
if grep -q '^  schemas/\*|skills/ai-dlc-setup/\*)' "$RD_F"; then
  sed -i.bak 's@^  schemas/\*|skills/ai-dlc-setup/\*)@  never-matches-a-real-path/*)@' "$RD_F"
  out="$(bash "$V" 2>&1)"
  if grep -q "I31: these core subtrees are I12 'scan'" <<<"$out"; then
    ok "removing register-drift's no-grain refusal FAILS I31 (a scan-marked subtree cannot reach an unnamed refusal)"
  else
    bad "removing the no-grain refusal did NOT fail I31 — a scan-marked subtree can be reported with no sanctioned disposition again"
  fi
  restore
  RD_F="$ROOT/core/skills/ai-dlc-update/reconcile/register-drift.sh"
else
  bad "FIXTURE STALE: register-drift.sh no longer carries the schemas/ai-dlc-setup no-grain case"
fi
}

# --- Assertion 14: I31 NON-VACUITY --------------------------------------------
# I31 derives register-drift's side by parsing its `case` labels. If that parse yields nothing
# — the case block moved, or its formatting changed — the comparison binds an empty set and
# EVERY scan subtree reads as undisposed, or worse, the check quietly passes. It must say so.
A15_i31_non_vacuity() {
# Bound here rather than inherited: when this file ran as one long script the name was
# still set from the assertion above. Each assertion now runs in its own process against
# its own tree, so an inherited path would be an unset variable under `set -u`.
RD_F="$ROOT/core/skills/ai-dlc-update/reconcile/register-drift.sh"

if grep -q '^case "\$REL" in' "$RD_F"; then
  # Remove the parse's opening anchor. Everything after it is untouched, so the case labels are
  # still there on disk and only the DERIVATION goes blind — which is the vacuity being tested.
  grep -v '^case "\$REL" in' "$RD_F" > "$RD_F.tmp" && mv "$RD_F.tmp" "$RD_F"
  out="$(bash "$V" 2>&1)"
  if grep -q "I31: could not parse any case label" <<<"$out"; then
    ok "an unparseable case block FAILS I31 loudly (it cannot pass by comparing against nothing)"
  else
    bad "an unparseable case block did NOT fail I31 — the check goes vacuous exactly when register-drift's dispositions become unreadable"
  fi
  restore
else
  bad "FIXTURE STALE: register-drift.sh no longer opens with 'case \"\$REL\" in'"
fi
}

# --- Assertion 15: I32 PIN vs INVOCATION --------------------------------------
# Check 17's arms pin a provenance block to a skill NAME; the step file that runs the
# evaluation names the skill it INVOKES. Two files, one fact, nothing comparing them —
# v0.169.0 repointed research-requirements.md §3 to /bmad-prd and left the arm pinning the
# old name, and no check said so for three minors. Repoint an arm at a bmad skill its own
# step file does not name and I32 must catch it.
A16_i32_pin_vs_invocation() {
GV_F="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"
if grep -qE '^  bmad-prd`\.$' "$GV_F"; then
  sed -i.bak 's/^  bmad-prd`\.$/  bmad-party-mode`./' "$GV_F"
  out="$(bash "$V" 2>&1)"
  if grep -q "I32: Check 17's 'research-requirements phase' arm" <<<"$out"; then
    ok "an arm pinning a skill its step file never invokes FAILS I32 (a pin and an invocation are one fact in two files)"
  else
    bad "repointing the PRD arm at an uninvoked skill did NOT fail I32 — the pin can fork from the step again"
  fi
  restore
  GV_F="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"
else
  bad "FIXTURE STALE: Check 17's PRD arm no longer pins bmad-prd on its own line"
fi
}

# --- Assertion 16: I32 NON-VACUITY --------------------------------------------
# Every I32 guard runs INSIDE the per-arm loop, so an arm grammar that stops matching scans
# nothing and reports clean — which is precisely the shape this check exists to end. Break
# the flag the arms are parsed on and the check must say it compared nothing.
A17_i32_non_vacuity() {
# Bound here rather than inherited: when this file ran as one long script the name was
# still set from the assertion above. Each assertion now runs in its own process against
# its own tree, so an inherited path would be an unset variable under `set -u`.
GV_F="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"

if grep -q -- '--require-skill' "$GV_F"; then
  sed -i.bak 's/--require-skill/--require-SKILL/g' "$GV_F"
  out="$(bash "$V" 2>&1)"
  if grep -q "I32 matched no bmad-\* skill pin" <<<"$out"; then
    ok "an unparseable arm grammar FAILS I32 loudly ('nothing to compare' never reads as 'the pins agree')"
  else
    bad "breaking the arm grammar did NOT fail I32 — the check goes vacuous exactly when the arms become unreadable"
  fi
  restore
else
  bad "FIXTURE STALE: Check 17's arms no longer carry --require-skill"
fi
}

# --- Assertion 17: I33 FIXTURE PATH WALK --------------------------------------
# A fixture that locates a core file by walking up from a path ANOTHER resolver produced is
# green in the distribution and red on every consumer, because the install mapping splits the
# subtrees (core/scripts -> scripts/ai-dlc, core/schemas -> .claude/schemas). Step 2 requires
# the derived fixtures green BEFORE the push, so that red is a permanent stop on the
# self-update — it shipped once and blocked a consumer's cycle. Reintroduce the walk and I33
# must name the offending fixture.
A18_i33_fixture_path_walk() {
SP_F="$ROOT/core/fixtures/story-provenance/run.sh"
# The walk is COMPOSED, never written literally. I33 greps for the pattern, so a fixture that
# spelled its own mutant out would flag itself — the same self-reference trap the ledger's close
# vocabulary hit. Split across the quote boundary, the two halves are not adjacent in THIS file
# and are adjacent in the file it writes, which is the only place it matters.
if grep -q -- '--print-schema' "$SP_F"; then
  walk='$(dirname "$WRITER")/..'"/schemas/provenance-block.json"
  sed -i.bak "s@^SCHEMA_SRC=.*\$@SCHEMA_SRC=\"$walk\"@" "$SP_F"
  out="$(bash "$V" 2>&1)"
  if grep -q "I33: these fixtures reach a core subtree by walking up" <<<"$out"; then
    ok "a fixture walking up from a resolved script into another core subtree FAILS I33"
  else
    bad "the walk-up path was not caught by I33 — a fixture can go green here and red on every consumer again"
  fi
  restore
  SP_F="$ROOT/core/fixtures/story-provenance/run.sh"
else
  bad "FIXTURE STALE: story-provenance/run.sh no longer resolves its schema via --print-schema"
fi
}

# --- Assertion 18: I33 NON-VACUITY --------------------------------------------
# I33 greps a tree. Empty that tree and it finds nothing and reports clean — the exact reading
# ("no hits" = "no defect") that the check exists to distinguish from a real pass.
A19_i33_non_vacuity() {
if [ -d "$ROOT/core/fixtures" ]; then
  find "$ROOT/core/fixtures" -name '*.sh' -type f -delete 2>/dev/null
  out="$(bash "$V" 2>&1)"
  if grep -q "I33 found no \*.sh under core/fixtures/" <<<"$out"; then
    ok "an empty fixture tree FAILS I33 loudly (a scan over nothing never reads as clean)"
  else
    bad "I33 reported clean over an empty fixture tree — 'no hits' is indistinguishable from 'no defect'"
  fi
  restore
else
  bad "FIXTURE STALE: the seed no longer copies core/fixtures/"
fi
}

# --- Assertion 19: I26 — the core set stays DERIVED, never restated -----------
# I26 HAD NO FIXTURE AT ALL until v0.190.0, and it was found the way this repo usually finds
# them: while making the invariant FASTER. An optimisation to a check nothing self-tests is a
# change whose only evidence is that the output looked the same, which is the same standard the
# restated list itself passed for six releases.
#
# The mutation plants exactly what I26 exists to reject: one line naming three derived manifest
# entries, which is a LIST. A reference stands alone; a list puts them on one line, and that
# punctuation adjacency is the whole predicate. The entries are taken from the manifest the
# check derives from, so the mutation cannot go stale against a hand-list here.
A20_i26_derived_core_set() {
GV="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"
if ! grep -q '<!-- CHECK_LOADED: core-layer-immutability -->' "$GV" 2>/dev/null; then
  bad "FIXTURE STALE: gate-validation.md has no core-layer-immutability span to mutate"
else
  cp "$GV" "$GV.orig"
  awk '{ print }
       /<!-- CHECK_LOADED: core-layer-immutability -->/ {
         print "The authoritative core paths are `team-roles/*.md`, `steps/*.md` and `templates/*.md`."
       }' "$GV.orig" > "$GV"
  if cmp -s "$GV.orig" "$GV"; then
    bad "FIXTURE BROKEN: the I26 mutation matched nothing, so this assertion is unproven"
  else
    out="$(bash "$V" 2>&1)"
    if grep -q "restates the core path set" <<<"$out"; then
      ok "a line naming three manifest entries FAILS I26 (the derived set cannot be quietly replaced by a list)"
    else
      bad "a restated core path list did NOT fail I26 — the check that stopped six core subtrees being silently skipped is not firing"
    fi
  fi
  restore
fi
}

# --- Assertion 20: I40 — the anchor reading cannot fork -----------------------
# Three functions are byte-identical across `core/scripts/validate-layer-entries.sh` (ERRORs at
# authoring time) and `reconcile/lib.sh` (reports at pull time). They are COPIES because neither
# tree may source the other's file — I25's reason and I29's — so an assertion is the only thing
# stopping the drift, and every one of the three has already forked once in this repo's history.
#
# TWO ARMS, because the vacuity arm is the one that matters: I40 LOCATES its subjects by awk
# range, and a renamed or deleted function makes it find nothing. "Found nothing" and "found two
# identical bodies" are the same green unless the check says so itself.
A21_i40_anchor_reading() {
LIBSH="$ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
if [ ! -f "$LIBSH" ]; then
  bad "FIXTURE STALE: the seed no longer copies reconcile/lib.sh, so I40 has nothing to bind"
else
  cp "$LIBSH" "$LIBSH.orig"

  # ARM 1 — FORK. `length(hn) > 3` is the reverse-arm noise floor shared with span_of. Nudging
  # it in ONE copy is the exact shape of the divergence I40 exists to catch: both tools still
  # run, both still report, and they disagree about which anchors are loose.
  sed 's/if (length(hn) > 3 \&\& w != "" \&\& index(w, hn) > 0/if (length(hn) > 5 \&\& w != "" \&\& index(w, hn) > 0/' "$LIBSH.orig" > "$LIBSH"
  if cmp -s "$LIBSH.orig" "$LIBSH"; then
    bad "FIXTURE BROKEN: the I40 fork mutation matched nothing, so this assertion is unproven"
  else
    out="$(bash "$V" 2>&1)"
    if grep -q "the anchor reading has forked" <<<"$out"; then
      ok "a one-copy change to the anchor arm FAILS I40 (the linter and the pull classifier cannot disagree)"
    else
      bad "a forked anchor_arm() did NOT fail I40 — the two tools can now answer the same question differently and the operator believes whichever they ran"
    fi
  fi

  # ARM 2 — VACUITY. Delete one subject outright. I40 must say it cannot find it, not pass.
  awk 'BEGIN{s=0} /^shadow_parts\(\) \{/{s=1} s==0{print} /^\}/{if(s==1){s=2; next}}' "$LIBSH.orig" > "$LIBSH"
  if cmp -s "$LIBSH.orig" "$LIBSH"; then
    bad "FIXTURE BROKEN: the I40 deletion mutation matched nothing, so the vacuity assertion is unproven"
  else
    out="$(bash "$V" 2>&1)"
    if grep -q "I40 cannot find a shadow_parts() definition" <<<"$out"; then
      ok "a MISSING bound function FAILS I40 loudly (finding nothing never reads as agreement)"
    else
      bad "I40 reported clean with shadow_parts() deleted from one side — a rename silently retires the binding"
    fi
  fi
  restore
fi
}

# --- Assertion 21: I45 — core stays out of the reserved consumer band ---------
# I45 is the CORE half of W5's partition, and it is the half a consumer cannot check.
# W5 tells an author to renumber into the band at 900; the only thing that makes that
# advice safe is core never allocating there. If I45 stops firing, nothing anywhere
# notices until core ships the allocation, and by then the collision has landed
# retroactively across gate logs that are the audit record.
#
# THREE ARMS, and the two vacuity arms are the load-bearing ones. I45 reports an
# ABSENCE — "no core number is in the band" — so every way of finding nothing produces
# its PASS. It reads its floor and its two catalog extractors out of
# validate-layer-entries.sh, and a rename at either end returns empty rather than
# wrong. Arm 1 proves it can fire; arms 2 and 3 prove that not-firing means something.
#
# Each arm asserts on its OWN message, never on the shared token "I45": the fire arm
# and the vacuity arms would otherwise both match a grep for the invariant's name, and
# an assertion two arms can satisfy is one that tests neither.
A22_i45_reserved_band() {
SKB="$ROOT/core/skills/ai-dlc/SKILL.md"
VLE="$ROOT/core/scripts/validate-layer-entries.sh"

# ARM 1 — FIRE, on the RULE side deliberately. The check side entangles: a `### 900.`
# heading in gate-validation.md also trips the CHECK_LOADED-anchor arm, so it produces
# two failures and neither one isolates I45. Measured, not assumed — 2 FAIL lines. The
# rulebook has no such second reader, so this mutation fires exactly one assertion.
#
# It is also the arm with the live detonation date: core is AT Rule 30, so Rule 31 is
# the next integer core allocates and the reference consumer already carries 31 and 32.
cp "$SKB" "$SKB.orig"
printf '\n### Rule 900 -- A core rule allocated inside the consumer band\n\nBody.\n' >> "$SKB"
if cmp -s "$SKB.orig" "$SKB"; then
  bad "FIXTURE BROKEN: the I45 fire mutation did not change SKILL.md, so this assertion is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "core allocates rule number(s) at or above the reserved consumer band" <<<"$out"; then
    ok "a core rule numbered 900 FAILS I45 (core cannot allocate from the range W5 tells consumers to move into)"
  else
    bad "core allocated Rule 900 and I45 stayed silent — the band is a promise to consumers with nothing holding core to it"
  fi
fi
restore
VLE="$ROOT/core/scripts/validate-layer-entries.sh"

# ARM 2 — VACUITY, the floor. Rename BAND_FLOOR and I45 can no longer say which
# numbers are core's. Reporting nothing would be indistinguishable from a conforming
# tree, and it would stay that way through every later release.
cp "$VLE" "$VLE.orig"
sed 's/^BAND_FLOOR=/BAND_CEILING=/' "$VLE.orig" > "$VLE"
if cmp -s "$VLE.orig" "$VLE"; then
  bad "FIXTURE BROKEN: the I45 floor mutation matched nothing, so the vacuity assertion is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "could not read BAND_FLOOR" <<<"$out"; then
    ok "an unreadable BAND_FLOOR FAILS I45 loudly (a floor it cannot read would make every core number conforming)"
  else
    bad "I45 reported clean with BAND_FLOOR renamed — the invariant retires itself silently the moment the constant moves"
  fi
fi
restore
VLE="$ROOT/core/scripts/validate-layer-entries.sh"

# ARM 3 — VACUITY, the catalog. I45 runs the SHIPPING extractors rather than copies of
# their grammars, which is what stops it answering differently from the check it
# complements — but it also means a renamed extractor returns an empty catalog, and an
# empty catalog contains nothing above the floor. That is I45's PASS reached by finding
# nothing, which is this repo's named defect class sitting inside the invariant.
cp "$VLE" "$VLE.orig"
sed 's/^defined_anchors() {/defined_anchor_set() {/' "$VLE.orig" > "$VLE"
if cmp -s "$VLE.orig" "$VLE"; then
  bad "FIXTURE BROKEN: the I45 extractor mutation matched nothing, so the catalog vacuity assertion is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "extracted ZERO check anchors" <<<"$out"; then
    ok "a renamed catalog extractor FAILS I45 loudly (an empty catalog never reads as a conforming one)"
  else
    bad "I45 reported clean with defined_anchors() renamed — it was scanning nothing and calling it agreement"
  fi
fi
restore
}

# --- Assertion 22: I47 — the check-heading grammar cannot fork ----------------
# CHECK_HEAD_RE decides what counts as a check DEFINITION, and two tools reach
# opposite verdicts if it forks. The linter uses it to harvest the ids a layer
# entry allocates; the manifest resolver uses it to report a definition that never
# became loadable (GM1). GM1's whole subject is checks that NOTHING else reports —
# neither MISSING (needs a row) nor ORPHAN (needs an anchor) — so a narrowed copy
# in the resolver restores exactly the silence GM1 was written to end, with a green
# build and no other symptom anywhere.
#
# TWO ARMS, and the second is the load-bearing one for the same reason I45's are:
# I47 reports an absence, so a rename at either end makes it find nothing and pass.
# Each asserts on its OWN message — "has forked" vs "could not find" — because a
# grep for "I47" is satisfied by both and would test neither.
A23_i47_check_heading() {
VGM="$ROOT/core/scripts/validate-gate-manifest.sh"
VLE="$ROOT/core/scripts/validate-layer-entries.sh"

# ARM 1 — FORK. Narrow the resolver's copy to headings of two or more digits. That
# is a real regression shape rather than a nonsense one: it still matches, still
# looks like the grammar, and silently drops every single-digit check definition.
cp "$VGM" "$VGM.orig"
sed "s/^CHECK_HEAD_RE='.*\$/CHECK_HEAD_RE='^#{2,4}[[:space:]]+(Check[[:space:]]+)?[0-9][0-9]+[a-z-]*\\\\.'/" "$VGM.orig" > "$VGM"
if cmp -s "$VGM.orig" "$VGM"; then
  bad "FIXTURE BROKEN: the I47 fork mutation matched nothing, so this assertion is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "the check-heading grammar has forked" <<<"$out"; then
    ok "a narrowed CHECK_HEAD_RE in the resolver FAILS I47 (a definition one tool sees and the other cannot)"
  else
    bad "the two copies of the check-heading grammar diverged and I47 stayed silent — GM1's subject set can shrink with the build green"
  fi
fi
restore
VGM="$ROOT/core/scripts/validate-gate-manifest.sh"
VLE="$ROOT/core/scripts/validate-layer-entries.sh"

# ARM 2 — VACUITY. Rename the assignment in the linter and I47 locates one side of
# the join. Comparing against nothing is its PASS.
cp "$VLE" "$VLE.orig"
sed "s/^CHECK_HEAD_RE=/CHECK_HEADING_RE=/" "$VLE.orig" > "$VLE"
if cmp -s "$VLE.orig" "$VLE"; then
  bad "FIXTURE BROKEN: the I47 vacuity mutation matched nothing, so the second arm is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "could not find a CHECK_HEAD_RE= assignment" <<<"$out"; then
    ok "a renamed CHECK_HEAD_RE FAILS I47 loudly (a join that cannot locate a side never passes by comparing nothing)"
  else
    bad "I47 reported clean with the assignment renamed — it was comparing nothing and calling it agreement"
  fi
fi
restore
}

# --- Assertion 23: I49 — a mode named in prose is a mode the script dispatches --
# Three of core's enforcement surfaces reach `core-paths.sh` through a STRING typed into a
# rule file an AGENT follows. A mode that does not exist prints usage and exits 2, and 2 is
# this resolver's "cannot determine what core is" — so a typo in a paragraph and an
# unreadable manifest arrive at the gate as the same answer, and the recoverable one wears
# the irrecoverable one's clothes.
#
# THREE ARMS, each asserting on its OWN message. A grep for "I49" is satisfied by all three
# and would test none of them — row 4's recorded trap, where two arms quoting one string let
# an assertion pass against a reverted fix.
A24_i49_resolver_modes() {
CP="$ROOT/core/scripts/core-paths.sh"
GV="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"

# ARM 1 — GHOST MODE. The gate check body names a mode one character off. This is the
# realistic shape: a rename lands in the script and the paragraph keeps the old spelling.
#
# The ghost spelling is ASSEMBLED, never written out. I49 excludes core/fixtures/ from its
# citation corpus for exactly this reason, and a fixture that leans on that exclusion to
# hold its own text would go red the day the exclusion is reconsidered — for a reason with
# nothing to do with what it tests.
ghost="--audit-diff""s"
cp "$GV" "$GV.orig"
sed "s@core-paths\\.sh --audit-diff@core-paths.sh ${ghost}@" "$GV.orig" > "$GV"
if cmp -s "$GV.orig" "$GV"; then
  bad "FIXTURE BROKEN: the I49 ghost-mode mutation matched nothing, so this assertion is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "mode(s) the script does not dispatch" <<<"$out"; then
    ok "a rule file naming a core-paths.sh mode the dispatch rejects FAILS I49 (the call would exit 2, which the caller reads as 'cannot determine')"
  else
    bad "the gate check body named a nonexistent resolver mode and I49 stayed silent — a typo in a paragraph now reports as an unreadable manifest"
  fi
fi
restore
CP="$ROOT/core/scripts/core-paths.sh"
GV="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"

# ARM 2 — UNDOCUMENTED MODE. Drop a mode from usage(). The callers are prose, updated by
# whoever read the usage text, so a mode missing from it is a mode no rename can reach.
cp "$CP" "$CP.orig"
grep -v 'core-paths.sh --list \[<manifest>\]" >&2' "$CP.orig" > "$CP"
if cmp -s "$CP.orig" "$CP"; then
  bad "FIXTURE BROKEN: the I49 undocumented-mode mutation matched nothing, so the second arm is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "its own usage() never names" <<<"$out"; then
    ok "a dispatched mode missing from usage() FAILS I49 (a mode no operator can discover)"
  else
    bad "a mode vanished from usage() and I49 reported clean — the discoverable set and the dispatched set can now diverge"
  fi
fi
restore
CP="$ROOT/core/scripts/core-paths.sh"
GV="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"

# ARM 3 — VACUITY. Rename the sentinel the dispatch extraction is bounded by. I49 reports an
# ABSENCE (nothing cited that is not dispatched), and an empty dispatched set makes every
# citation a ghost — or, without the zero guard, makes `comm` compare against nothing and
# report agreement it never computed.
cp "$CP" "$CP.orig"
sed 's@# MODE_DISPATCH_BEGIN@# MODE_TABLE_BEGIN@' "$CP.orig" > "$CP"
if cmp -s "$CP.orig" "$CP"; then
  bad "FIXTURE BROKEN: the I49 vacuity mutation matched nothing, so the third arm is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "parsed ZERO modes" <<<"$out"; then
    ok "a renamed dispatch sentinel FAILS I49 loudly (an empty set is a subset of everything, so the join must refuse rather than agree)"
  else
    bad "the dispatch extraction found nothing and I49 did not say so — it was comparing against an empty set and calling it agreement"
  fi
fi
restore
}

# --- Assertion 24: I50 — a validator named in prose is a validator core ships --
# install.sh DERIVES scripts/ai-dlc/ from core/scripts/, so a citation naming a file core
# does not ship resolves to nothing in every consumer tree. The agent told to run it gets
# a command that fails to start, and no report — which is what a clean run looks like.
#
# THREE ARMS. The two ghost arms differ by which half of the corpus they mutate and each
# asserts on ITS OWN ghost NAME, never on the shared message: an arm that greps only for
# "does not ship" would be satisfied by the other arm's mutation and would prove nothing
# about the corpus boundary it exists to hold.
#
# Both ghost names are ASSEMBLED at runtime. I50 excludes core/fixtures/ because thirteen
# fixtures deliberately name validators that do not exist, and an assertion that leans on
# that exclusion to hold its own text goes red the day the exclusion is reconsidered.
A25_i50_shipped_validators() {
DEV="$ROOT/core/team-roles/dev.md"
TPL="$ROOT/templates/audit-anchors.md.template"

# ARM 1 — GHOST IN A ROLE FILE. The realistic shape: a validator is renamed and the
# paragraph that tells the dev to run it keeps the old filename.
ghost_a="validate-mutation""-gone.sh"
cp "$DEV" "$DEV.orig"
sed "s@scripts/ai-dlc/validate-mutation-red\\.sh@scripts/ai-dlc/${ghost_a}@" "$DEV.orig" > "$DEV"
if cmp -s "$DEV.orig" "$DEV"; then
  bad "FIXTURE BROKEN: the I50 role-file ghost mutation matched nothing, so this assertion is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "$ghost_a" <<<"$out"; then
    ok "a role file naming a validator core does not ship FAILS I50 (the command does not exist in any consumer tree)"
  else
    bad "a role file told an agent to run a validator core does not ship and I50 stayed silent — the command that never ran reports what a clean run reports"
  fi
fi
# Restoring the one mutated file, rather than re-seeding the whole tree: each `restore`
# copies ~1.4 MB and this fixture is already the suite's wall-clock floor. The mutation is
# one file plus its own .orig, so moving it back leaves the seed pristine.
mv "$DEV.orig" "$DEV"

# ARM 2 — GHOST IN A TEMPLATE. templates/ is installed into the consumer's tree, so a dead
# citation there is dead in the same place for the same reader. This arm exists because the
# corpus boundary is the part of I50 that can narrow silently: drop templates/ from the
# grep and arm 1 still passes.
ghost_b="validate-audit""-vanished.sh"
cp "$TPL" "$TPL.orig"
sed "/RENDERED from it by/s@scripts/ai-dlc/validate-audit-anchors\\.sh@scripts/ai-dlc/${ghost_b}@" "$TPL.orig" > "$TPL"
if cmp -s "$TPL.orig" "$TPL"; then
  bad "FIXTURE BROKEN: the I50 template ghost mutation matched nothing, so the second arm is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "$ghost_b" <<<"$out"; then
    ok "a consumer-installed template naming a validator core does not ship FAILS I50 (templates/ is inside the corpus)"
  else
    bad "a template cited a validator core does not ship and I50 reported clean — half its corpus is outside what it reads"
  fi
fi
mv "$TPL.orig" "$TPL"

# ARM 3 — VACUITY. I50 reports an ABSENCE (nothing cited that is not shipped). With the
# shipped set empty every citation is a ghost, and without the zero guard `comm` compares
# against nothing and reports an agreement it never computed. Other invariants also error
# in this run — core/scripts/ is where several of them read from — which is why the
# assertion is on I50's own EMPTY-set wording and not on the validator's exit status.
mv "$ROOT/core/scripts" "$ROOT/core/scripts.hidden"
out="$(bash "$V" 2>&1)"
mv "$ROOT/core/scripts.hidden" "$ROOT/core/scripts"
if grep -q "I50 derived an EMPTY set" <<<"$out"; then
  ok "an empty shipped-validator set FAILS I50 loudly (an empty set contains nothing, so every citation would be a ghost and the join must refuse)"
else
  bad "the shipped-validator set was empty and I50 did not say so — it was comparing citations against nothing"
fi
# The mv back above is the restore: this arm moved a directory and moved it home again.
}

# --- Assertion 22: I51 — the licensed commit has one subject in two files ------
# Step 5b licenses one commit to the trunk outside a PR (not the pipeline's only one — §7a-post
# commits the log rotation there too — but the only one bounded at push time), and the subject
# it tells the lead to type is matched at push time by a regex in the schema. The two are
# not derivable from each other by equality — one is a template with <N>/<PR>, the other a
# regex — so the join fills the template and matches it, exactly as the lead and then the
# matcher do. Drift here surfaces at the worst possible moment: the retro PR has already
# merged, the SHA is only knowable now, and the one commit that carries it will not land.
#
# THREE ARMS, each asserting its OWN wording. All three would match a grep for "I51", so an
# assertion on the invariant's name is one that tests none of them.
A26_i51_licensed_commit() {
AAJ="$ROOT/core/schemas/audit-anchors.json"
RTR="$ROOT/core/skills/ai-dlc/steps/retro.md"

# ARM 1 — PROSE DRIFTS FROM THE MATCHER. The template still parses (it keeps the
# chore(s<N>) opening the extractor keys on), so this reaches the comparison rather than
# the vacuity arm. That distinction is the whole point of having arm 3 as well.
cp "$RTR" "$RTR.orig"
sed 's@SHA after retro PR #<PR> merge@SHA for retro PR #<PR>@' "$RTR.orig" > "$RTR"
if cmp -s "$RTR.orig" "$RTR"; then
  bad "FIXTURE BROKEN: the I51 template mutation matched nothing, so the prose-drift arm is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "tells the lead to write a subject the shipped matcher rejects" <<<"$out"; then
    ok "a Step 5b template the schema regex rejects FAILS I51 (a lead following the step file would write an unlandable commit)"
  else
    bad "the step file and the push-time matcher disagreed on the licensed subject and I51 reported clean"
  fi
fi
mv "$RTR.orig" "$RTR"

# ARM 2 — THE REMEDY CONTRADICTS THE RULE. --trunk-push prints subject_example as the fix
# on every rejection. An example its own pattern rejects sends the consumer round the loop
# a second time, which is worse than no example at all.
cp "$AAJ" "$AAJ.orig"
sed 's@"subject_example": "chore(s299)@"subject_example": "chore(S299)@' "$AAJ.orig" > "$AAJ"
if cmp -s "$AAJ.orig" "$AAJ"; then
  bad "FIXTURE BROKEN: the I51 example mutation matched nothing, so the remedy arm is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "subject_example does not match backfill_commit.subject_pattern" <<<"$out"; then
    ok "an example its own pattern rejects FAILS I51 (the rejection message would hand the consumer a subject the same run refuses)"
  else
    bad "backfill_commit carried an example its own pattern rejects and I51 reported clean"
  fi
fi
mv "$AAJ.orig" "$AAJ"

# ARM 3 — VACUITY. I51 reports an ABSENCE (no disagreement). Both sides are EXTRACTED —
# one by a JSON key, one by a regex over prose — and prose is the side that moves. Delete
# the template and there is nothing to disagree with, which is indistinguishable from
# agreement unless the derivation refuses. This arm is why the ZERO branch exists.
cp "$RTR" "$RTR.orig"
sed '/chore(s<N>): backfill audit-anchor SHA/d' "$RTR.orig" > "$RTR"
if cmp -s "$RTR.orig" "$RTR"; then
  bad "FIXTURE BROKEN: the I51 vacuity mutation matched nothing, so the zero guard is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "I51 could not derive both sides" <<<"$out"; then
    ok "a retro.md with no subject template FAILS I51 loudly (nothing to compare must not read as the two agreeing)"
  else
    bad "the prose side of I51 vanished and the invariant reported agreement it never computed"
  fi
fi
mv "$RTR.orig" "$RTR"
}

# --- Assertion 25: I52 — the drivability exemption marker cannot fork ----------
# `validate-fixture-drivability.sh` is SHIPPED and wired into the consumer's pre-push,
# and it judges tests/fixtures/ — where install.sh puts CORE's fixtures. Two of core's
# are legitimately driverless and pass only by carrying I20's marker in their READMEs.
# A diverged marker therefore does not fail the author who moved it; it fails every
# consumer's next push, on core files they did not write. That is why the join exists
# and why its arms assert on their own wording rather than on the exit status.
A27_i52_exemption_marker() {
FDS="$ROOT/core/scripts/validate-fixture-drivability.sh"

# ARM 1 — DIVERGENCE. The realistic shape: the marker is reworded in one home. Asserted
# on the GHOST text, not on the word "differs", so the vacuity arm below cannot satisfy it.
ghost_m="No \`driver.sh\`"", deliberately"
cp "$FDS" "$FDS.orig"
sed "s@^EXEMPT_MARKER='.*'\$@EXEMPT_MARKER='${ghost_m}'@" "$FDS.orig" > "$FDS"
if cmp -s "$FDS.orig" "$FDS"; then
  bad "FIXTURE BROKEN: the I52 divergence mutation matched nothing, so this assertion is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -qF "$ghost_m" <<<"$out"; then
    ok "a reworded marker in the shipped validator FAILS I52 (core's two driverless fixtures would fail every consumer's push)"
  else
    bad "the shipped validator's exemption marker diverged from I20's and I52 stayed silent — core's own fixtures would start failing consumers who changed nothing"
  fi
fi
mv "$FDS.orig" "$FDS"

# ARM 2 — VACUITY. I52 compares two EXTRACTED strings, and the extraction is a sed over a
# line shape. Break the shape and both sides can come back empty, where `!=` is false and
# the join reports an agreement it never computed. Asserted on I52's own read-failure
# wording, which names the file it could not read — arm 1's message never contains it.
cp "$FDS" "$FDS.orig"
sed "s@^EXEMPT_MARKER=.*\$@EXEMPT_MARKER=\"whatever\"@" "$FDS.orig" > "$FDS"
if cmp -s "$FDS.orig" "$FDS"; then
  bad "FIXTURE BROKEN: the I52 vacuity mutation matched nothing, so the zero guard is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "cannot read EXEMPT_MARKER out of validate-fixture-drivability.sh" <<<"$out"; then
    ok "an unreadable marker in the shipped validator FAILS I52 loudly (two empty strings compare equal, and that is not agreement)"
  else
    bad "I52 could not extract the shipped validator's marker and passed anyway — it compared nothing against nothing"
  fi
fi
mv "$FDS.orig" "$FDS"
}

# --- Assertion 26: I53 — a mode one core script asks another for is one it dispatches --
# `core-paths.sh --audit-diff` decides whether the operator authorized an in-place core edit
# by CALLING `validate-escalation-resolution.sh --any-authorized` instead of restating that
# script's citation grammar. Delegation beats restatement only while the mode on the other
# side is real: an unknown argument exits 2, the caller reads any non-zero as "no citation",
# and the backstop starts FAILing consumers whose trees are clean.
#
# Three arms, each on its OWN wording — I49's arrangement, and row 4's recorded trap is why.
A28_i53_escalation_modes() {
ESR="$ROOT/core/scripts/validate-escalation-resolution.sh"
CPS="$ROOT/core/scripts/core-paths.sh"

# ARM 1 — GHOST MODE. The caller keeps the old spelling after a rename. Assembled, never
# written out: I53 excludes core/fixtures/ from its citation corpus, and a fixture leaning on
# that exclusion to hold its own text goes red the day the exclusion is reconsidered.
i53_ghost="--any-authorize""d-by"
cp "$CPS" "$CPS.orig"
sed "s@validate-escalation-resolution\\.sh\" --any-authorized@validate-escalation-resolution.sh\" ${i53_ghost}@" "$CPS.orig" > "$CPS"
if cmp -s "$CPS.orig" "$CPS"; then
  bad "FIXTURE BROKEN: the I53 ghost-mode mutation matched nothing, so this assertion is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "mode(s) it does not dispatch" <<<"$out"; then
    ok "one core script invoking a mode the other does not dispatch FAILS I53 (the call exits 2, and the citation arm reads that as 'no operator citation')"
  else
    bad "core-paths.sh called an escalation mode that does not exist and I53 stayed silent — the core-layer-immutability backstop would FAIL trees that are clean"
  fi
fi
mv "$CPS.orig" "$CPS"

# ARM 2 — UNDOCUMENTED MODE. Drop a mode from the USAGE block. The delegation is code, but
# the operator reproducing it by hand reads that block.
cp "$ESR" "$ESR.orig"
grep -v '^#   validate-escalation-resolution.sh --any-authorized' "$ESR.orig" > "$ESR"
if cmp -s "$ESR.orig" "$ESR"; then
  bad "FIXTURE BROKEN: the I53 undocumented-mode mutation matched nothing, so the second arm is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "its own USAGE block never names" <<<"$out"; then
    ok "a dispatched escalation mode missing from the USAGE block FAILS I53 (a mode no operator can discover)"
  else
    bad "a mode vanished from the USAGE block and I53 reported clean — the discoverable set and the dispatched set can now diverge"
  fi
fi
mv "$ESR.orig" "$ESR"

# ARM 3 — VACUITY. Rename the sentinel bounding the dispatch extraction. I53 reports an
# ABSENCE, and an empty dispatched set makes `comm` compare against nothing and agree.
cp "$ESR" "$ESR.orig"
sed 's@# MODE_DISPATCH_BEGIN@# ARG_TABLE_BEGIN@' "$ESR.orig" > "$ESR"
if cmp -s "$ESR.orig" "$ESR"; then
  bad "FIXTURE BROKEN: the I53 vacuity mutation matched nothing, so the third arm is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "parsed ZERO modes out of validate-escalation-resolution.sh" <<<"$out"; then
    ok "a renamed dispatch sentinel FAILS I53 loudly (an empty set is a subset of everything, so the join must refuse rather than agree)"
  else
    bad "the escalation dispatch extraction found nothing and I53 did not say so — it was comparing against an empty set and calling it agreement"
  fi
fi
mv "$ESR.orig" "$ESR"
}

A29_i54_early_exit_reader() {
# I54 bans writing a shell variable into a reader that stops at its first match. Under
# pipefail such a pipeline reports the WRITER's status, and a writer that still had bytes
# to push has taken EPIPE -- so the test answers "not found" on input containing the
# pattern. Where a match means the tree is BAD that is a permanent, silent pass.
#
# EVERY LITERAL OF THE BANNED SHAPE IS ASSEMBLED AT RUNTIME. I54's scan covers
# core/fixtures/, so a fixture that spelled the shape out would be reported by the very
# invariant it exists to test -- the trap v0.194.0 paid for twice. `$_g` below is the
# reader; nothing on any line here forms the pattern I54 matches.
_g="gre""p -q"
I54_TGT="core/fixtures/ledger-rotate/run.sh"

# ARM 1 — THE BAN FIRES, and names the file. The injected line is inert (guarded by a
# false test) because I54 reads text and must not need the code to run; a realistic site
# is a line in a real script, not a scratch file no manifest knows about.
printf '\nif false; then\n  printf %s "$_i54" | %s I54_SENTINEL_ALPHA\nfi\n' "'%s'" "$_g" >> "$ROOT/$I54_TGT"
out="$(bash "$V" 2>&1)"
if grep -qF "$I54_TGT" <<<"$out" && grep -q 'I54 found' <<<"$out"; then
  ok "a variable written into a first-match reader FAILS I54, naming the file (under pipefail that test answers 'not found' on input that contains the pattern)"
else
  bad "the banned reader idiom was reintroduced and I54 stayed silent — the check that keeps a negative assertion able to fire is itself unable to fire"
fi

# ARM 2 — NO FALSE POSITIVE ON THE PERMITTED SHAPE. An ordinary command piped into the
# same reader is safe and ubiquitous; a blanket ban would be the unmeasured lint
# CLAUDE.md warns about. Asserted on I54 being SILENT about this file, with arm 1's
# injection removed first so the two cannot be confused.
git -C "$ROOT" checkout -- "$I54_TGT" 2>/dev/null || sed -i.bak '/I54_SENTINEL_ALPHA/,+1d' "$ROOT/$I54_TGT"
printf '\nif false; then\n  git log --oneline | %s I54_SENTINEL_BETA\nfi\n' "$_g" >> "$ROOT/$I54_TGT"
out="$(bash "$V" 2>&1)"
if grep -q 'I54 found' <<<"$out"; then
  bad "I54 reported an ordinary command piped into a first-match reader — that shape is permitted, and a check with that false-positive set is one the operator switches off"
else
  ok "an ordinary command piped into the same reader does NOT fail I54 (the subject set is a builtin writing a variable, not every pipe)"
fi

# ARM 3 — VACUITY. I54 reports an ABSENCE, so a grammar that matches nothing prints the
# same clean line as a tree with no defect. It carries a probe of the banned shape and
# must refuse when its own grammar stops matching it. Asserted on that refusal's wording,
# which arm 1's message never contains.
cp "$V" "$V.orig"
sed 's@\[|\]\[\[:space:\]\]\*grep@[|][[:space:]]*NOSUCHREADER@' "$V.orig" > "$V"
if cmp -s "$V.orig" "$V"; then
  bad "FIXTURE BROKEN: the I54 grammar mutation matched nothing, so the vacuity guard is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "grammar no longer matches the shape it bans" <<<"$out"; then
    ok "a grammar that stops matching its own probe FAILS I54 loudly (a scan that matches nothing reads exactly like a clean tree)"
  else
    bad "I54's grammar was broken and it reported a clean tree — it was scanning for a shape it could no longer match"
  fi
fi
mv "$V.orig" "$V"

# ARM 4 — OVER-WIDTH. The opposite failure: a grammar loose enough to match any pipe
# would fire on nearly every script. I54 carries a probe of the PERMITTED shape too and
# must refuse when it starts matching that. Asserted on its own distinct wording.
cp "$V" "$V.orig"
# The realistic over-width is a "simplification": drop the writer and its quoted
# argument and keep only the pipe-into-reader tail. A mutation that merely adds an
# alternative to the writer group changes bytes without widening anything -- cmp -s
# passes it and the assertion below is what catches it, which is the recorded trap.
sed 's@^i54_re=".*\[|\]@i54_re="[|]@' "$V.orig" > "$V"
if cmp -s "$V.orig" "$V"; then
  bad "FIXTURE BROKEN: the I54 over-width mutation matched nothing, so the false-positive guard is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "matches an ordinary command piped into" <<<"$out"; then
    ok "a grammar that starts matching the permitted shape FAILS I54 loudly (a check nobody can leave on enforces nothing)"
  else
    bad "I54's grammar was widened to match ordinary pipelines and it did not object — its false-positive set is unguarded"
  fi
fi
mv "$V.orig" "$V"
}

A30_i55_suite_content_key() {
# I55 guards the fixture-suite content key: the pre-push hook skips the entire suite when
# the key is unchanged since the last fully green run, and the ONLY thing holding that up
# is that the key covers a superset of the suite's inputs. Four arms, four mutants, each
# asserted on its own distinct wording rather than on the shared token "I55" -- row 4's
# recorded trap, where two arms quoting the same subject let a reverted fix pass.
KEY="$ROOT/scripts/suite-content-key.sh"
PREPUSH="$ROOT/.githooks/pre-push"
if [ ! -f "$KEY" ] || [ ! -f "$PREPUSH" ]; then
  bad "FIXTURE BROKEN: the seed carries no scripts/suite-content-key.sh or .githooks/pre-push, so I55 has nothing to read"
  return
fi

# --- arm 1: an exclusion that is not a bare top-level name excludes NOTHING ----
cp "$KEY" "$KEY.orig"
sed 's@^docs$@docs/analysis@' "$KEY.orig" > "$KEY"
if cmp -s "$KEY.orig" "$KEY"; then
  bad "FIXTURE BROKEN: the I55 arm-1 mutation matched nothing, so the exclusion-shape arm is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "not bare top-level names" <<<"$out"; then
    ok "an exclusion carrying a slash is REPORTED (it matches no top-level entry and silently excludes nothing)"
  else
    bad "suite-content-key.sh declared an exclusion that its own exact-match filter can never apply, and the build stayed green"
  fi
fi
mv "$KEY.orig" "$KEY"

# --- arm 2: dropping .git from the exclusion set --------------------------------
cp "$KEY" "$KEY.orig"
sed '/^# EXCLUDE_BEGIN$/,/^# EXCLUDE_END$/{/^\.git$/d;}' "$KEY.orig" > "$KEY"
if cmp -s "$KEY.orig" "$KEY"; then
  bad "FIXTURE BROKEN: the I55 arm-2 mutation matched nothing, so the .git arm is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "no longer excludes .git" <<<"$out"; then
    ok "including .git in the key is REPORTED (it moves every commit, so the skip could never fire again)"
  else
    bad "the content key was widened to cover the object store and nothing objected — the suite skip became unreachable silently"
  fi
fi
mv "$KEY.orig" "$KEY"

# --- arm 3: a fixture reaching an EXCLUDED path at the distribution root ---------
# Written into a real fixture's run.sh, because that is the corpus arm 3 reads.
#
# THE PROBE IS ASSEMBLED AT RUNTIME AND NOTHING ON ANY LINE HERE SPELLS IT OUT.
# Arm 3's scan covers core/fixtures/, so a literal would be reported by the very
# invariant this assertion exists to test -- and it was, on the first run, which is
# the trap v0.194.0 recorded and paid for twice.
I55_PROBE='probe="$'"RO""OT/do""cs/analysis\""
I55_TGT="core/fixtures/ledger-rotate/run.sh"
if [ ! -f "$ROOT/$I55_TGT" ]; then
  bad "FIXTURE BROKEN: $I55_TGT is not in the seed, so I55 arm 3 has no subject"
else
  cp "$ROOT/$I55_TGT" "$ROOT/$I55_TGT.orig"
  printf '%s\n' "$I55_PROBE" >> "$ROOT/$I55_TGT"
  if cmp -s "$ROOT/$I55_TGT.orig" "$ROOT/$I55_TGT"; then
    bad "FIXTURE BROKEN: the I55 arm-3 mutation changed no bytes"
  else
    out="$(bash "$V" 2>&1)"
    if grep -q "reach a content-key-EXCLUDED path" <<<"$out"; then
      ok "a fixture reading an excluded path at the distribution root is REPORTED (its input could change with the suite never re-running)"
    else
      bad "a fixture took an unhashed path as input and I55 stayed silent — the skip would hold across a change to that fixture's own subject"
    fi
  fi
  mv "$ROOT/$I55_TGT.orig" "$ROOT/$I55_TGT"
fi

# --- arm 4: the record moved INSIDE the tree the key hashes ---------------------
cp "$PREPUSH" "$PREPUSH.orig"
sed 's@^KEY_RECORD="\.git/@KEY_RECORD="core/@' "$PREPUSH.orig" > "$PREPUSH"
if cmp -s "$PREPUSH.orig" "$PREPUSH"; then
  bad "FIXTURE BROKEN: the I55 arm-4 mutation matched nothing, so the record-location arm is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "inside the working tree" <<<"$out"; then
    ok "storing the key inside the tree it hashes is REPORTED (writing the record would invalidate it and no push could ever hit)"
  else
    bad "the key record was moved into the hashed tree and nothing objected — the skip becomes machinery that runs on every push and never pays"
  fi
fi
mv "$PREPUSH.orig" "$PREPUSH"
}

# --- Assertion 31: I56 — the model pin cannot fork, and cannot be defined twice --
# `ai-dlc-dispatch-guard.sh` decides a role's pin at dispatch and binds the teammate's model
# to it; `validate-spawn-ledger.sh` re-asks the same question at the gate for Check 22. They
# share `pin_key()` and `matches_pin()` as byte-identical COPIES — I25's reason: a guard that
# sources a helper fails OPEN on a partial install, and a dispatch guard binding nothing is
# far worse than eleven duplicated lines.
#
# THREE ARMS, EACH ON ITS OWN WORDING. Arm 3 is the one with a real history: the guard shipped
# TWO definitions of `matches_pin()`, verbatim apart from one word of comment, with the first
# shadowed and dead. An awk-range extraction concatenates both spans, so a duplicate does not
# fork the rule — it disables the check that would have caught a fork. Arms 2 and 3 both land
# on I56's count message, so they are distinguished by the COUNT they report, never by the
# shared token: row 4's recorded trap.
A31_i56_model_pin_binding() {
GUARD="$ROOT/core/hooks/ai-dlc-dispatch-guard.sh"
LEDGERV="$ROOT/core/scripts/validate-spawn-ledger.sh"
if [ ! -f "$GUARD" ] || [ ! -f "$LEDGERV" ]; then
  bad "FIXTURE BROKEN: the seed carries no ai-dlc-dispatch-guard.sh or validate-spawn-ledger.sh, so I56 has nothing to bind"
  return
fi

# --- arm 1: FORK. Narrow the match tolerance in ONE copy. -------------------
# Dropping the containment case is the exact divergence I56 exists to catch: both files still
# run and both still answer, but the gate now reports a Rule 19(a) mismatch on every spawn the
# guard bound from a full model string (`claude-opus-5[1m]` against the key `opus`).
cp "$LEDGERV" "$LEDGERV.orig"
sed 's@^    \*"\$EXPECT"\*) return 0 ;;@    *"$EXPECT"*) return 1 ;;@' "$LEDGERV.orig" > "$LEDGERV"
if cmp -s "$LEDGERV.orig" "$LEDGERV"; then
  bad "FIXTURE BROKEN: the I56 fork mutation matched nothing, so this assertion is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "the model pin has forked" <<<"$out"; then
    ok "a one-copy change to the match tolerance FAILS I56 (the gate cannot classify a binding differently from the hook that made it)"
  else
    bad "matches_pin() forked between the dispatch guard and the gate validator and I56 stayed silent — Check 22 would fail spawns the guard bound correctly"
  fi
fi
mv "$LEDGERV.orig" "$LEDGERV"

# --- arm 2: VACUITY. Delete one subject outright. ---------------------------
# I56 LOCATES its subjects by name. A rename or a deletion makes it find nothing, and
# "found nothing" reads exactly like "found two identical bodies" unless it says so.
cp "$LEDGERV" "$LEDGERV.orig"
awk 'BEGIN{s=0} /^pin_key\(\) \{/{s=1} s==0{print} /^\}/{if(s==1){s=2; next}}' "$LEDGERV.orig" > "$LEDGERV"
if cmp -s "$LEDGERV.orig" "$LEDGERV"; then
  bad "FIXTURE BROKEN: the I56 deletion mutation matched nothing, so the vacuity arm is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "validate-spawn-ledger.sh (found 0)" <<<"$out"; then
    ok "a MISSING bound function FAILS I56 loudly, naming the count it found (a rename never retires the binding in silence)"
  else
    bad "pin_key() was deleted from the gate validator and I56 did not report a zero count — the binding can be retired by a rename"
  fi
fi
mv "$LEDGERV.orig" "$LEDGERV"

# --- arm 3: DUPLICATE. Define matches_pin() twice in the guard. -------------
# The state the guard actually shipped in until v0.211.0. Byte-identity alone passes it,
# because the extraction returns both spans from one side and one from the other — so the
# count arm has to come first.
cp "$GUARD" "$GUARD.orig"
{ cat "$GUARD.orig"
  printf 'matches_pin() {\n  [ -n "$EXPECT" ] || return 1\n  case "$1" in\n    "$EXPECT")   return 0 ;;\n    *)           return 1 ;;\n  esac\n}\n'
} > "$GUARD"
if cmp -s "$GUARD.orig" "$GUARD"; then
  bad "FIXTURE BROKEN: the I56 duplicate mutation wrote no second definition, so the third arm is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "ai-dlc-dispatch-guard.sh (found 2)" <<<"$out"; then
    ok "a SECOND definition of a bound function FAILS I56, naming the count (the later one shadows the earlier and the fork arm would compare two spans against one)"
  else
    bad "the dispatch guard defined matches_pin() twice and I56 reported clean — this is the exact state it shipped in, and a genuine fork could hide behind it"
  fi
fi
mv "$GUARD.orig" "$GUARD"
}

A32_i57_predicate_binding() {
GVF="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"
MAPF="$ROOT/core/skills/ai-dlc/enforcement-map.yaml"
if [ ! -f "$GVF" ] || [ ! -f "$MAPF" ]; then
  bad "FIXTURE BROKEN: the seed carries no gate-validation.md or enforcement-map.yaml, so I57 has nothing to join"
  return
fi

# --- arm 1: THE DEFECT, REPLAYED. Not a mutant — the state the tree shipped in. ---
# Until v0.212.0 nothing bound stamp-story-provenance.sh, while Check 17's two story
# readiness arms each say "exit 0 required" over it. Deleting the unit row restores exactly
# that tree, so this arm proves I57 fires on the real thing rather than on a contrivance.
cp "$MAPF" "$MAPF.orig"
awk '/^  - id: story-provenance-cross-check$/{s=1} s==1 && /^  - id: h2-attestation$/{s=0} s==0{print}' "$MAPF.orig" > "$MAPF"
if cmp -s "$MAPF.orig" "$MAPF"; then
  bad "FIXTURE BROKEN: the I57 unit-row deletion matched nothing, so the replay arm is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "Check 17: stamp-story-provenance.sh" <<<"$out"; then
    ok "an unbound validator whose exit code the check's own body requires FAILS I57, named with its check (the v0.211.0 state of Check 17, replayed)"
  else
    bad "Check 17 states 'exit 0 required' over stamp-story-provenance.sh with nothing in the map binding it, and I57 reported clean — the class this invariant exists to end is still open"
  fi
fi
mv "$MAPF.orig" "$MAPF"
restore; MAPF="$ROOT/core/skills/ai-dlc/enforcement-map.yaml"

# --- arm 2: THE TWO RESOLUTIONS. Break only the call-site route. -------------
# Check 14 cites the validator THROUGH verdict.sh (`verdict.sh validate-artifact-budget`),
# and its binding lives on the artifact-budget unit rather than on its own row. Repointing
# that one site is the only mutation here, and the message it must produce names
# validate-artifact-budget.sh at Check 14 — a string I57 can only print if it resolved the
# dispatcher's first argument AND looked at non_catalog_units call sites. A join that reads
# basenames and check rows alone prints nothing here, and prints five phantoms elsewhere.
cp "$MAPF" "$MAPF.orig"
sed 's@^      - site: gate-validation.md Check 14$@      - site: gate-validation.md Check 44@' "$MAPF.orig" > "$MAPF"
if cmp -s "$MAPF.orig" "$MAPF"; then
  bad "FIXTURE BROKEN: the I57 call-site repoint matched nothing, so the resolution arm is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "Check 14: validate-artifact-budget.sh" <<<"$out"; then
    ok "a validator cited through the verdict.sh DISPATCHER and bound on a non_catalog_units call site is resolved both ways by I57 (repointing the site alone reports it)"
  else
    bad "the artifact-budget unit stopped naming Check 14 as a call site and I57 did not report it — either the dispatcher's argument or the call-site route is not being resolved, and the join is reading wrapper basenames"
  fi
fi
mv "$MAPF.orig" "$MAPF"
restore; GVF="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"

# --- arm 3: THE DISCRIMINATOR IS THE SENTENCE, NOT THE CITATION. ------------
# Check 25 cites wait-for-deliverable.sh as the REMEDY it offers on FAIL. That citation is
# correct and must stay unbound. Giving that same sentence an exit-code posture — and
# changing nothing else, not the citation, not the map — must flip it into the subject set.
# This is the arm that proves the release's actual claim: an imperative naming a validator
# is not the predicate; an assertion that its exit code binds the gate is.
cp "$GVF" "$GVF.orig"
sed 's@^  count\.$@  count; exit 0 required.@' "$GVF.orig" > "$GVF"
if cmp -s "$GVF.orig" "$GVF"; then
  bad "FIXTURE BROKEN: the I57 posture-injection matched nothing, so the discriminator arm is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "Check 25: wait-for-deliverable.sh" <<<"$out"; then
    ok "adding an exit-code posture to an On-FAIL REMEDY — same citation, same map — moves it into I57's subject set (the discriminator reads the sentence, not the mention)"
  else
    bad "Check 25's remedy citation gained 'exit 0 required' and I57 stayed silent — the selection is not keying on the posture, so it cannot be separating predicates from producers and remedies either"
  fi
fi
mv "$GVF.orig" "$GVF"
restore

# --- arm 4: THE LIVENESS PROBE. Kill the grammar; the probe must say so. -----
# With Check 17 bound there is no live subject left, so a grammar that stops matching
# reports the same clean line as one that found nothing to report. I57 answers that with a
# probe it builds itself. Break the posture term and the probe — not the corpus — is what
# fails.
cp "$V" "$V.orig"
sed 's@exits?\[ \]+\[0-9\]\[ \]+required/@exits?[ ]+[0-9][ ]+requiredZZZ/@' "$V.orig" > "$V"
if cmp -s "$V.orig" "$V"; then
  bad "FIXTURE BROKEN: the I57 grammar mutation matched nothing, so the liveness arm is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "did not fire on a probe" <<<"$out"; then
    ok "a posture grammar that can no longer match FAILS I57 against its own probe (an empty subject set never again reads as a clean tree)"
  else
    bad "I57's posture grammar was broken so that it matches nothing, and the invariant still printed clean — the liveness probe is not wired, and this check would silently stop firing on its first grammar edit"
  fi
fi
mv "$V.orig" "$V"
restore

# --- arm 5: THE NARROWNESS PROBE. Widen it back to the legend form. ---------
# `exit 0 = dropped, exit 1 = consumer-owned` is how Check 16 DESCRIBES a delegation
# validate-stub-audit.sh makes internally — correctly carried under reads:, and the nearest
# miss in the measured corpus. Widening the grammar to accept `=` is the one-character
# change that would report it, so the negative probe holds that door shut.
# (The same widening also reports Check 16 itself; that is the false positive the narrow
# grammar exists to avoid, and this arm asserts the probe's message, not the count.)
cp "$V" "$V.orig"
sed 's@exits?\[ \]+\[0-9\]\[ \]+required/@exits?[ ]+[0-9][ ]+(required|=)/@' "$V.orig" > "$V"
if cmp -s "$V.orig" "$V"; then
  bad "FIXTURE BROKEN: the I57 grammar widening matched nothing, so the narrowness arm is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "exit-code LEGEND" <<<"$out"; then
    ok "widening the posture to accept an exit-code LEGEND FAILS I57's negative probe (the measured-empty false-positive set is held by a mechanism, not by a paragraph)"
  else
    bad "I57's posture grammar was widened to match 'exit 0 = ...' and the negative probe stayed silent — nothing stops this check from growing back onto delegations that are correctly carried under reads:"
  fi
fi
mv "$V.orig" "$V"
}

# --- Assertion 33: I59 — a dispatched mode is a documented mode ---------------
# A `case` arm no line of prose names is a mode that exists and cannot be found. Nothing
# breaks, so nothing reports it: at v0.213.1 a consumer read `readopt-override.sh`'s usage
# block, concluded `--merge` did not exist, and filed a correct instruction as a defect.
#
# FOUR ARMS, each asserting its OWN wording. Three of them mutate the VALIDATOR rather than
# a subject, because this invariant reports an absence over a derived corpus and three
# separate things can turn that absence into a lie: the extraction can stop matching, the
# one enumerated exemption can widen, and the corpus can collapse to nothing. Each failure
# mode has its own message and each arm names only its own.
A33_i59_documented_modes() {
RO="$ROOT/core/skills/ai-dlc-update/reconcile/readopt-override.sh"

# ARM 1 — THE DEFECT ITSELF, and BOTH layers of the fix are reverted. `--merge` is named in
# two places in that file (the `# Usage:` header and the exit-2 usage string), so a mutant
# that removes one proves only the other. A partial revert here comes back green.
cp "$RO" "$RO.orig"
grep -v '<override> --merge    # three-way' "$RO.orig" \
  | sed 's@\[--check|--merge|--stamp <outcome>\]@[--check|--stamp <outcome>]@' > "$RO"
if cmp -s "$RO.orig" "$RO"; then
  bad "FIXTURE BROKEN: the I59 undocumented-mode mutation matched nothing, so the defect arm is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "readopt-override.sh --merge" <<<"$out"; then
    ok "a dispatched mode named in neither the usage header nor the usage string FAILS I59, named with its file (the v0.213.1 defect, replayed)"
  else
    bad "readopt-override.sh dispatched --merge with nothing naming it and I59 stayed silent — the mode is invisible again, and the next operator to read that block files the instruction that uses it as a defect"
  fi
fi
mv "$RO.orig" "$RO"
restore

# ARM 2 — THE EXTRACTION DIES. I59 reports an ABSENCE over a regex against a shell
# construct, and a regex that matches nothing returns the same empty set as a clean tree.
# The invariant answers that with a probe file it writes itself; break the grammar and the
# PROBE is what fails, not the corpus.
#
# The mutation targets the pipeline's FINAL filter, not the case-arm regex. The first
# attempt at this arm edited the regex's leading alternation group — which is `(...)*`,
# so dropping it changed bytes and changed nothing: `cmp -s` passed, the mutant ran, and
# the arm reported a real failure against a validator that was still working. A byte
# guard proves the sed matched; only the assertion proves the mutant BITES.
cp "$V" "$V.orig"
sed "s@grep '\^--'@grep '\^ZZ'@" "$V.orig" > "$V"
if cmp -s "$V.orig" "$V"; then
  bad "FIXTURE BROKEN: the I59 grammar mutation matched nothing, so the liveness arm is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "did not fire on its own probe" <<<"$out"; then
    ok "a case-arm grammar that can no longer match FAILS I59 against its own probe (an extraction that finds nothing never again reads as a documented tree)"
  else
    bad "I59's mode extraction was broken so that it matches nothing and the invariant still printed clean — it would stop firing on its first grammar edit and no one would learn of it"
  fi
fi
mv "$V.orig" "$V"
restore

# ARM 3 — THE EXEMPTION DIES. `--help` is the ONE enumerated carve-out and it is what makes
# the measured false-positive set empty: six scripts dispatch `-h|--help` to print their own
# header. Remove it and those six become findings — the shape that gets a lint turned off.
cp "$V" "$V.orig"
grep -v 'I59_HELP_EXEMPTION' "$V.orig" > "$V"
if cmp -s "$V.orig" "$V"; then
  bad "FIXTURE BROKEN: the I59 exemption mutation matched nothing, so the carve-out arm is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "reported the exempt --help arm on its own probe" <<<"$out"; then
    ok "losing the --help carve-out FAILS I59 on its own probe (the measured-empty false-positive set is held by a mechanism, not by a paragraph)"
  else
    bad "I59's --help exemption was deleted and the probe stayed silent — six scripts that dispatch -h|--help to print their own header become findings, and the carve-out is unheld"
  fi
fi
mv "$V.orig" "$V"
restore

# ARM 4 — THE CORPUS COLLAPSES. The subject set is derived by `find`, not `git ls-files`,
# precisely because this fixture seeds a copy with no `.git` — and an empty corpus prints
# the same clean line as a fully documented one. The floor is what refuses.
cp "$V" "$V.orig"
sed "s@-type f -name '\*\.sh' -not -path@-type f -name '*.zzz' -not -path@" "$V.orig" > "$V"
if cmp -s "$V.orig" "$V"; then
  bad "FIXTURE BROKEN: the I59 corpus mutation matched nothing, so the floor arm is unproven"
else
  out="$(bash "$V" 2>&1)"
  if grep -q "I59 found only 0 shipped script(s)" <<<"$out"; then
    ok "a corpus derivation that returns nothing FAILS I59 loudly (scanning zero files is not the same answer as finding zero findings)"
  else
    bad "I59's corpus derivation matched no files and the invariant reported clean — every mode in core/ was unchecked and the run said so nowhere"
  fi
fi
mv "$V.orig" "$V"
}

# ---------------------------------------------------------------------------
# THE DRIVER
# ---------------------------------------------------------------------------
# `--run-one <assertion>` is one assertion, in one process, against one freshly seeded
# tree. It is the unit the pool schedules and it is also how a human runs a single
# assertion while working on it.
if [ "${1:-}" = "--run-one" ]; then
  FN="${2:-}"
  declare -F "$FN" >/dev/null 2>&1 || {
    echo "FIXTURE ERROR: --run-one needs an assertion function name; '$FN' is not one" >&2
    exit 2
  }
  seed_tree
  trap 'rm -rf "$ROOT"' EXIT
  "$FN"
  [ "$fails" -eq 0 ] || exit 1
  exit 0
fi

# THE ASSERTION LIST IS DERIVED FROM THIS FILE'S OWN DEFINITIONS, in source order. A
# hand-written list here would be this fixture's own subject defect one level out: an
# assertion dropped from the list runs nothing and prints nothing, and a suite reporting 28
# greens instead of 29 reads exactly like a suite that passed. The zero guard is the same
# argument -- a naming grammar that stops matching yields an empty list, and an empty list
# passes every assertion it never made.
NAMES="$(grep -oE '^A[0-9]{2}_[a-z0-9_]+\(\) \{' "$0" | sed 's/() {$//')"
N_LISTED="$(printf '%s\n' "$NAMES" | grep -c . || true)"
if [ "$N_LISTED" -lt 10 ]; then
  echo "FIXTURE ERROR: derived $N_LISTED assertion(s) from this file — the A<nn>_ naming grammar moved" >&2
  exit 2
fi

echo "enforcement-map-sites:"

OUT="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$OUT"' EXIT
SELF="$HERE/$(basename "$0")"

# The control, first and alone. Its verdict licenses every assertion after it, so a failure
# here stops the run rather than reporting 28 unattributable kills.
CTL="$(printf '%s\n' "$NAMES" | head -1)"
bash "$SELF" --run-one "$CTL" > "$OUT/$CTL" 2>"$OUT/$CTL.err"
ctl_rc=$?
cat "$OUT/$CTL"
if [ "$ctl_rc" -ne 0 ]; then
  [ -s "$OUT/$CTL.err" ] && cat "$OUT/$CTL.err" >&2
  echo
  echo "enforcement-map-sites: 1 assertion(s) FAILED" >&2
  exit 2
fi

# EIGHT, and it is a fixed number rather than a tunable on purpose: this pool nests inside
# the pre-push suite's own pool, so a knob here multiplies against a knob there and the
# product is what lands on the machine. Eight against 18 cores leaves headroom for the
# seven sibling fixtures the suite runs beside this one.
JOBS=8
printf '%s\n' "$NAMES" | tail -n +2 > "$OUT/list"
AI_DLC_EMS_SELF="$SELF" AI_DLC_EMS_OUT="$OUT" \
  xargs -P "$JOBS" -I{} bash -c '
    n="$1"
    bash "$AI_DLC_EMS_SELF" --run-one "$n" \
      > "$AI_DLC_EMS_OUT/$n" 2> "$AI_DLC_EMS_OUT/$n.err"
    printf %s $? > "$AI_DLC_EMS_OUT/$n.rc"
  ' _ {} < "$OUT/list"

# Rendered in SOURCE order, never completion order, so the output is byte-comparable
# against the serial version and diffable across runs.
#
# A MISSING VERDICT IS A FAILURE, not a gap. Serially, an assertion that never ran could
# not print an `ok` -- the loop and the report were the same thing. With a pool they are
# not, and a dropped job is silent. So the verdict file's absence is asserted, and a worker
# that exited nonzero without printing a FAIL line (a crash, a failed seed) is charged one
# rather than counted as clean.
while IFS= read -r n; do
  [ -n "$n" ] || continue
  if [ ! -f "$OUT/$n.rc" ]; then
    printf '  FAIL  %s produced no verdict — the pool dropped work, and a short green run reads exactly like a passing one\n' "$n"
    fails=$((fails + 1))
    continue
  fi
  cat "$OUT/$n"
  [ -s "$OUT/$n.err" ] && cat "$OUT/$n.err" >&2
  wrc="$(cat "$OUT/$n.rc")"
  # 2 IS NOT 1. `FIXTURE BROKEN` (a failed seed, an unbuildable mutant) and `an assertion
  # regressed` are different answers, and this file has always used exit 2 for the first.
  # Routing an assertion through a worker would otherwise collapse them: the parent sees a
  # nonzero rc, charges one assertion and exits 1 — reporting a regression where the truth is
  # that nothing was tested.
  if [ "$wrc" = "2" ]; then broken=1; fi
  if [ "$wrc" != "0" ]; then
    c="$(grep -c '^  FAIL' "$OUT/$n" || true)"
    [ "$c" -gt 0 ] || { printf '  FAIL  %s exited nonzero without an assertion line — the assertion did not run to a verdict\n' "$n"; c=1; }
    fails=$((fails + c))
  fi
done < "$OUT/list"

echo
if [ "$broken" -ne 0 ]; then
  echo "enforcement-map-sites: FIXTURE BROKEN — an assertion could not run to a verdict" >&2
  exit 2
fi
if [ "$fails" -eq 0 ]; then echo "enforcement-map-sites: PASS"; exit 0; fi
echo "enforcement-map-sites: $fails assertion(s) FAILED" >&2
exit 1
