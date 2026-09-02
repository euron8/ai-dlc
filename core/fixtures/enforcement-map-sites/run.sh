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

# ONE VALIDATOR RUN PER ASSERTION, AND THE ARM IT SELECTS IS DERIVED FROM THE CALLER'S NAME.
# `validate-enforcement-map.sh --arms I<n>` runs one selectable unit plus the prologue and the
# verdict block. Every assertion below already declares the invariant it tests in its own
# function name -- `A04_i12_scan_match` tests I12 -- so that embedded segment IS the selector.
# Nothing here hand-lists one, and that is the point: a second list would be this fixture's own
# subject defect one level out. A list that drifted from the assertions would select an arm for
# a mutation it never reads, the mutant would go unreported, and an unreported mutant reads
# exactly like a surviving one.
#
# THREE FAILURE SHAPES, and none of them may reach an assertion's predicate:
#   - a frame whose name carries no derivable `i<id>` segment;
#   - `--arms <id>` naming an id no arm declares, or any other selection/usage failure;
#   - a generated subprogram that never reached the verdict block.
# The validator answers all three with exit 2, which is never an invariant violation. Scoring
# one as a mutant surviving or dying would be a wrong answer in the exact register this file
# exists to protect, so each is FIXTURE BROKEN, named, with the validator's own message.
#
# THERE IS DELIBERATELY NO FALLBACK TO A FULL RUN. A fallback would run every arm, satisfy the
# grep, print the same green line, and leave a selector that resolves to nothing looking
# identical to one that resolved correctly -- a mechanism that cannot fire reading exactly like
# one that did.
#
# THE BROKEN SIGNAL GOES THROUGH A FILE, and that is not a style choice. `out="$(vrun)"` runs
# this function inside a command substitution, so an `exit 2` here kills the SUBSHELL: the
# assertion would carry on with an empty `$out`, fail its own grep, and report the mutant as
# surviving. `--run-one` reads the marker after the assertion returns and exits 2 itself, which
# is the code the driver already routes to FIXTURE BROKEN rather than to a regression.
VRUN_LOG=""
VRUN_BROKEN=""
vrun() {
  local frame seg id vout rc
  id=""
  for frame in "${FUNCNAME[@]}"; do
    case "$frame" in
      A[0-9]*_i[0-9]*)
        seg="${frame#A}"; seg="${seg#*_}"; seg="${seg%%_*}"
        case "$seg" in
          i[0-9]*) id="I${seg#i}"; break ;;
        esac
        ;;
    esac
  done
  if [ -z "$id" ]; then
    [ -n "$VRUN_BROKEN" ] && printf 'FIXTURE BROKEN: vrun found no A<nn>_i<id>_ frame to derive an --arms selector from (frames: %s). The naming grammar the selector is derived from has moved, and there is no full-run fallback on purpose.\n' "${FUNCNAME[*]}" >> "$VRUN_BROKEN"
    return 2
  fi
  vout="$(bash "$V" --arms "$id" 2>&1)"; rc=$?
  if [ "$rc" = "2" ]; then
    [ -n "$VRUN_BROKEN" ] && printf 'FIXTURE BROKEN: validate-enforcement-map.sh --arms %s exited 2. That is a SELECTION failure -- an unknown id, a malformed flag, or a generated subprogram that never reached the verdict -- not an invariant finding, so it is not scored as a mutant surviving or dying: %s\n' "$id" "$vout" >> "$VRUN_BROKEN"
    return 2
  fi
  [ -n "$VRUN_LOG" ] && printf '%s\n' "$id" >> "$VRUN_LOG"
  printf '%s\n' "$vout"
}

# --- Assertion 0: SANITY ------------------------------------------------------
# The pristine tree must PASS. If it does not, the validator is erroring for some reason
# of its own and every "it failed as expected" below is a false pass.
#
# THE ONE ASSERTION THAT KEEPS A FULL RUN, and its claim is why. "The pristine tree passes"
# is an ABSENCE over EVERY arm, not over one, so `--arms` would license only the arm it
# selected and the licence the assertions below rely on would be narrower than the set of
# arms they use. A selected run says nothing whatever about the arms it did not run.
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
#
# THE NEXT THREE ARE NAMED i17, NOT i8, AND THAT IS A MEASUREMENT. Their failure text says
# "I8's site table", and the table is I8's by history -- but the SELECTABLE UNIT that reads
# it is I17's, and `--arms` selects units. Measured on a seeded tree with the completeness
# mutation applied: `--arms I8` exits 0 and reports nothing, `--arms I17` exits 1 and prints
# the row-missing finding. I8's own unit is fixture packaging, several thousand lines away.
# Naming these i8 would have selected an arm that cannot see the mutation, and a mutation no
# arm reads scores as a survivor -- which is this file's whole subject. The name states which
# unit runs the check, because that is what the selector is derived from.
A01_i17_sitetable_completeness() {
mkdir -p "$ROOT/core/brand-new-subtree"
echo 'x' > "$ROOT/core/brand-new-subtree/thing.sh"
out="$(vrun)"
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
A02_i17_sitetable_agreement() {
grep -q 'core/git-hooks/\*)' "$PRECLASS" || bad "FIXTURE STALE: preclassify.sh has no core/git-hooks/ case to remove"
sed -i.bak '/core\/git-hooks\/\*)/d' "$PRECLASS"
out="$(vrun)"
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
A03_i17_sitetable_installer_binding() {
grep -q 'PROJECT_ROOT/.githooks' "$INSTALL" || bad "FIXTURE STALE: install.sh has no .githooks write to remove"
sed -i.bak 's|"\$PROJECT_ROOT/\.githooks|"$PROJECT_ROOT/.githooks-REMOVED|g' "$INSTALL"
out="$(vrun)"
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
  out="$(vrun)"
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
out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
out="$(vrun)"
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
out="$(vrun)"
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
out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
    out="$(vrun)"
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
    out="$(vrun)"
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
    out="$(vrun)"
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
# I45 is the CORE half of E15's partition, and it is the half a consumer cannot check.
# E15 tells an author to renumber into the band at 900; the only thing that makes that
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
# It is also the arm with the live detonation date: core is AT Rule 31, so Rule 32 is
# the next integer core allocates. The reference consumer no longer collides there — it
# has migrated its own rules into the reserved band (913-932), so the numbers it once
# held at 31 and 32 are free and core took 31. Re-measure before quoting this: the
# detonation is real only while a consumer still allocates below the floor.
cp "$SKB" "$SKB.orig"
printf '\n### Rule 900 -- A core rule allocated inside the consumer band\n\nBody.\n' >> "$SKB"
if cmp -s "$SKB.orig" "$SKB"; then
  bad "FIXTURE BROKEN: the I45 fire mutation did not change SKILL.md, so this assertion is unproven"
else
  out="$(vrun)"
  if grep -q "core allocates rule number(s) at or above the reserved consumer band" <<<"$out"; then
    ok "a core rule numbered 900 FAILS I45 (core cannot allocate from the range E15 tells consumers to move into)"
  else
    bad "core allocated Rule 900 and I45 stayed silent — the band is a promise to consumers with nothing holding core to it"
  fi
fi
restore

# ARM 1b — THE ALPHABETIC HALF, which is a separate partition and needs its own fire
# arm. A band is numeric and alphabetic ids have no ordering in one, so they are
# partitioned by a reserved PREFIX instead: the consumer takes `X…`, core takes
# everything else. The numeric arm above cannot reach this — `XAP` has no leading
# integer — so without this assertion core could allocate straight into the range a
# consumer renamed `AP` into, and I45 would report clean. On the reference consumer that
# is not hypothetical: it defines `AP`, `VH`, and its own `H1` which core also defines,
# and four releases of a numeric-only band could see none of them.
GVB="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"
cp "$GVB" "$GVB.orig"
printf '\n### XAP. A core check allocated inside the consumer alphabetic prefix\n<!-- CHECK_LOADED: XAP -->\n\nBody.\n' >> "$GVB"
if cmp -s "$GVB.orig" "$GVB"; then
  bad "FIXTURE BROKEN: the I45 alphabetic fire mutation did not change gate-validation.md, so this assertion is unproven"
else
  out="$(vrun)"
  if grep -q "core allocates alphabetic check id(s) beginning with the reserved consumer prefix" <<<"$out"; then
    ok "a core check id 'XAP' FAILS I45 (the alphabetic half of the partition has a mechanism, not just a paragraph)"
  else
    bad "core allocated check 'XAP' and I45 stayed silent — a consumer that renamed 'AP' into the reserved prefix has bought nothing, and the collision it migrated to escape reappears upstream for every consumer at once"
  fi
fi
restore

# ARM 1c — VACUITY, the prefix. Same shape as the floor arm below and for the same
# reason: an unreadable BAND_ALPHA_PREFIX makes every core alphabetic id conforming,
# which is this arm's PASS. It has to fail loudly instead.
VLE="$ROOT/core/scripts/validate-layer-entries.sh"
cp "$VLE" "$VLE.orig"
sed 's/^BAND_ALPHA_PREFIX=/BAND_ALPHA_SUFFIX=/' "$VLE.orig" > "$VLE"
if cmp -s "$VLE.orig" "$VLE"; then
  bad "FIXTURE BROKEN: the I45 alphabetic-prefix mutation matched nothing, so its vacuity assertion is unproven"
else
  out="$(vrun)"
  if grep -q "could not read BAND_ALPHA_PREFIX" <<<"$out"; then
    ok "an unreadable BAND_ALPHA_PREFIX FAILS I45 loudly (a prefix it cannot read would make every core alphabetic id conforming)"
  else
    bad "I45 reported clean with BAND_ALPHA_PREFIX renamed — the alphabetic half retires itself silently the moment the constant moves"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
  if grep -q "could not find a CHECK_HEAD_RE= assignment" <<<"$out"; then
    ok "a renamed CHECK_HEAD_RE FAILS I47 loudly (a join that cannot locate a side never passes by comparing nothing)"
  else
    bad "I47 reported clean with the assignment renamed — it was comparing nothing and calling it agreement"
  fi
fi
restore
VGM="$ROOT/core/scripts/validate-gate-manifest.sh"
VLE="$ROOT/core/scripts/validate-layer-entries.sh"

# ARM 3 — THE PAIR-OF-PAIRS FORK, and it is the one the other two cannot reach. Arms 1
# and 2 both move ONE detector, so both are caught by the lint-vs-resolver comparison
# alone. The failure this invariant was extended for moved NEITHER out of step with the
# other: the rewriter's ANCHOR_RE widened for alphabetic ids and the `—` terminator, both
# detectors stayed numeric-and-dot, and every pair-check stayed green while `Check AP` and
# `Check VH` were live and unreportable. So the mutation narrows BOTH detectors, together,
# back to that exact pre-release grammar — arm 1's comparison is satisfied by construction
# and only the detectors-vs-rewriter arm can fire.
#
# There is no fourth arm for the "cannot find ANCHOR_RE" branch on purpose. I15 reads the
# same assignment, so deleting or renaming it fails both invariants and neither mutant
# would be attributable — assertion 21 above already proves that absence fails loudly.
cp "$VGM" "$VGM.orig"; cp "$VLE" "$VLE.orig"
NARROW="CHECK_HEAD_RE='^#{2,4}[[:space:]]+(Check[[:space:]]+)?[0-9]+[a-z-]*\\\\.'"
sed "s|^CHECK_HEAD_RE=.*|$NARROW|" "$VGM.orig" > "$VGM"
sed "s|^CHECK_HEAD_RE=.*|$NARROW|" "$VLE.orig" > "$VLE"
if cmp -s "$VGM.orig" "$VGM" || cmp -s "$VLE.orig" "$VLE"; then
  bad "FIXTURE BROKEN: the I47 pair-of-pairs mutation matched nothing in one or both detectors, so this assertion is unproven"
elif ! cmp -s "$VGM" "$VLE" && ! diff <(grep '^CHECK_HEAD_RE=' "$VGM") <(grep '^CHECK_HEAD_RE=' "$VLE") >/dev/null; then
  bad "FIXTURE BROKEN: the two narrowed detectors are not byte-identical, so arm 1 could fire and this assertion would not be attributable"
else
  out="$(vrun)"
  if grep -q "the check-heading grammar has forked between" <<<"$out"; then
    bad "the pair-of-pairs mutant tripped arm 1 as well — the two mutations are entangled and this arm proves nothing"
  elif grep -q "the DETECTORS' check-heading grammar and the REWRITER's have forked" <<<"$out"; then
    ok "narrowing BOTH detectors in step FAILS I47 (a heading the rewriter relabels that no detector reports — green under every pair-check)"
  else
    bad "both detectors reverted to the numeric grammar and I47 stayed silent — the fork that hid two live unloadable checks can reopen"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
out="$(vrun)"
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
out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
    out="$(vrun)"
    if grep -q "reach a content-key-EXCLUDED path" <<<"$out"; then
      ok "a fixture reading an excluded path at the distribution root is REPORTED (its input could change with the suite never re-running)"
    else
      bad "a fixture took an unhashed path as input and I55 stayed silent — the skip would hold across a change to that fixture's own subject"
    fi
  fi
  mv "$ROOT/$I55_TGT.orig" "$ROOT/$I55_TGT"
fi

# --- arm 4: EVERY cross-run record moved INSIDE the tree the key hashes ----------
# THE MUTATION IS DERIVED FROM THE HOOK, and v0.229.0 is why it had to become so. This
# arm named `KEY_RECORD` for as long as the hook kept exactly one record. That release
# gave it a SECOND -- the fixture durations the pool dispatches on -- and made I55's
# subject set a grammar rather than a name. Mutating only the record this fixture
# happened to know would then prove the arm FIRES without proving it covers what it now
# claims to: a record outside the derived set would sit in the tree, and this arm would
# go on printing the same green line about the other one.
#
# So the mutation moves every `<NAME>_RECORD=` the hook declares, and the assertion
# counts the records the report NAMES against the records the hook DECLARES. Both sides
# are read off the hook, so a third record is covered the day someone writes it, and a
# subject set that quietly stopped growing fails here instead of passing quietly.
cp "$PREPUSH" "$PREPUSH.orig"
i55_declared="$(grep -cE '^[A-Z][A-Z0-9_]*_RECORD="' "$PREPUSH.orig" 2>/dev/null)"
case "$i55_declared" in ''|*[!0-9]*) i55_declared=0 ;; esac
sed -E 's@^([A-Z][A-Z0-9_]*_RECORD)="\.git/@\1="core/@' "$PREPUSH.orig" > "$PREPUSH"
if [ "$i55_declared" -lt 2 ]; then
  bad "FIXTURE BROKEN: the hook declares $i55_declared cross-run record(s) under .git/; this arm proves a DERIVED subject set and cannot do that over fewer than two"
elif cmp -s "$PREPUSH.orig" "$PREPUSH"; then
  bad "FIXTURE BROKEN: the I55 arm-4 mutation matched nothing, so the record-location arm is unproven"
else
  out="$(vrun)"
  i55_named="$(grep -oE '[A-Z][A-Z0-9_]*_RECORD=' <<<"$out" | sort -u | grep -c . 2>/dev/null)"
  case "$i55_named" in ''|*[!0-9]*) i55_named=0 ;; esac
  if grep -q "inside the working tree" <<<"$out" && [ "$i55_named" -eq "$i55_declared" ]; then
    ok "moving ALL $i55_declared cross-run records inside the tree they are hashed by is REPORTED, and the report names every one — the subject set is derived from the hook, not from a name this fixture knows"
  else
    bad "the cross-run records were moved into the hashed tree and I55 named $i55_named of $i55_declared — a record outside the derived subject set sits in the tree while the skip becomes machinery that runs on every push and never pays"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
#
# THE MUTATION NAMES ONLY THE POSTURE TERM, not the whole regex. It used to restate the
# expression from `exits?` onward, and v0.357.0's case-tolerant widening (`exits?` ->
# `[Ee]xits?`) left that restatement matching nothing — the arm reported itself broken and
# blocked the push, which is the guard working, but the arm was dead until someone repaired
# it. `required/` occurs exactly once in the validator (the closing delimiter pins it to the
# end of I57's own regex), so the smallest span that carries the semantics is also unique,
# and an edit to the case class, the quantifiers or the digit class no longer kills the probe.
cp "$V" "$V.orig"
sed 's@\[ \]+required/@[ ]+requiredZZZ/@' "$V.orig" > "$V"
if cmp -s "$V.orig" "$V"; then
  bad "FIXTURE BROKEN: the I57 grammar mutation matched nothing, so the liveness arm is unproven"
else
  out="$(vrun)"
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
# Same narrowed target as arm 4, for the same reason: widen the posture ALTERNATIVE only,
# and let the case class and quantifiers ahead of it change without killing this probe.
cp "$V" "$V.orig"
sed 's@\[ \]+required/@[ ]+(required|=)/@' "$V.orig" > "$V"
if cmp -s "$V.orig" "$V"; then
  bad "FIXTURE BROKEN: the I57 grammar widening matched nothing, so the narrowness arm is unproven"
else
  out="$(vrun)"
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

# ARM 1 — THE DEFECT ITSELF, and EVERY layer of the fix is reverted. A partial revert comes
# back green, proving whichever layer it left behind.
#
# THE MUTATION DERIVES ITS OWN TARGETS RATHER THAN NAMING THEM. It used to strip two hand-named
# sites — the `# Usage:` header line and the exit-2 usage string — and it went silently
# insufficient the moment a release added a third: v0.476.0's two-directional gate names
# `--merge` in its remedy prose, so the two-site mutant left the mode documented, I59 correctly
# stayed quiet, and this arm read as a regression in the change under test. So the deletion is
# keyed on I59's OWN documentation test, and the count it must reach is asserted here rather
# than assumed.
cp "$RO" "$RO.orig"
a33_doc_lines() { awk -v m='--merge' 'index($0,m) && ($0 ~ /^[[:space:]]*#/ || index($0,"usage"))' "$1" | grep -c .; }
awk 'index($0,"--merge") && $0 ~ /^[[:space:]]*#/ { next } { print }' "$RO.orig" \
  | sed 's@\[--check|--merge|--stamp <outcome>\]@[--check|--stamp <outcome>]@' > "$RO"
if cmp -s "$RO.orig" "$RO"; then
  bad "FIXTURE BROKEN: the I59 undocumented-mode mutation matched nothing, so the defect arm is unproven"
elif [ "$(a33_doc_lines "$RO")" -ne 0 ] || [ "$(a33_doc_lines "$RO.orig")" -eq 0 ]; then
  bad "FIXTURE BROKEN: after the mutation $(a33_doc_lines "$RO") line(s) still document --merge (the unmutated file has $(a33_doc_lines "$RO.orig")), so I59 staying silent below would say nothing about the invariant"
else
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
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
  out="$(vrun)"
  if grep -q "I59 found only 0 shipped script(s)" <<<"$out"; then
    ok "a corpus derivation that returns nothing FAILS I59 loudly (scanning zero files is not the same answer as finding zero findings)"
  else
    bad "I59's corpus derivation matched no files and the invariant reported clean — every mode in core/ was unchecked and the run said so nowhere"
  fi
fi
mv "$V.orig" "$V"
}

# --- Assertion 34: I60 — a CITED mode is a mode the target dispatches ---------
# The other half of I59's join, and the half no general invariant held. A file names
# `<script>.sh --mode`, the script does not accept it, and the call exits 2 — which I49's
# call site reads as "cannot determine what core is" and I53's reads as "no operator
# citation", so the same typo becomes an unreadable manifest at one gate and a FAIL on a
# clean tree at the other.
#
# FOUR ARMS. Three mutate the VALIDATOR rather than a subject, because this invariant
# reports an absence over two derived corpora and three separate things turn that absence
# into a lie: the citation grammar can stop matching, the dispatch grammar can widen until
# nothing is ever a ghost, and the corpus can collapse. Each arm names only its own message.
A34_i60_cited_modes() {

# ARM 1 — THE DEFECT ITSELF. Rename the mode at a REAL call site rather than planting a
# citation, so what is proven is the join reaching a live caller. The ghost spelling is
# ASSEMBLED, never written out: I60 excludes core/fixtures/ from its corpus, but this file
# is read by other invariants and a literal here is a citation somewhere.
GHOST="--is-""kore"
VICTIM="$(grep -rl -- 'core-paths\.sh --is-core' "$ROOT/core" --exclude-dir=fixtures 2>/dev/null | head -1)"
if [ -z "$VICTIM" ]; then
  bad "FIXTURE BROKEN: no file in the seed cites 'core-paths.sh --is-core', so the I60 defect arm has no live citation to rename and is unproven"
else
  cp "$VICTIM" "$VICTIM.orig"
  sed "s@core-paths\.sh --is-core@core-paths.sh $GHOST@" "$VICTIM.orig" > "$VICTIM"
  if cmp -s "$VICTIM.orig" "$VICTIM"; then
    bad "FIXTURE BROKEN: the I60 ghost-citation mutation matched nothing, so the defect arm is unproven"
  else
    out="$(vrun)"
    if grep -q -- "core-paths.sh $GHOST" <<<"$out"; then
      ok "a shipped file naming a core-paths.sh mode the dispatch rejects FAILS I60, named with its mode (the call would exit 2, and both hand-listed call sites misread that 2)"
    else
      bad "a shipped file named a resolver mode that does not exist and I60 stayed silent — the generalisation covers 25 targets on paper and reached none of them"
    fi
  fi
  mv "$VICTIM.orig" "$VICTIM"
fi
restore

# ARM 2 — THE NON-CASE DISPATCH FORM DIES. This is the arm that carries the row's actual
# finding. Six shipped scripts parse their mode with `[ "$1" = "--x" ]` rather than a case
# arm, and a dispatch side that reads only case arms turns every one of them into a false
# finding — the measured non-empty false-positive set that blocked this generalisation for
# two programs. The probe target dispatches one mode each way precisely so this regression
# is loud instead of quiet.
cp "$V" "$V.orig"
sed "s@grep -oE '==\?\[\[:space:\]\]+\"--\[a-z\]\[a-z0-9-\]\*\"'@grep -oE '--zzz-no-such-form'@" "$V.orig" > "$V"
if cmp -s "$V.orig" "$V"; then
  bad "FIXTURE BROKEN: the I60 non-case-dispatch mutation matched nothing, so the false-positive arm is unproven"
else
  out="$(vrun)"
  if grep -q "has lost the non-case form" <<<"$out"; then
    ok "a dispatch side that no longer reads \`[ \"\$1\" = \"--x\" ]\` FAILS I60 on its own probe (the empty false-positive set is held by a mechanism, not by a paragraph)"
  else
    bad "I60's non-case dispatch form was removed and the probe stayed silent — six shipped scripts become false findings, which is the shape that gets a lint turned off"
  fi
fi
mv "$V.orig" "$V"
restore

# ARM 3 — THE CITATION GRAMMAR DIES. A regex that matches nothing returns the same empty
# ghost set as a tree with no ghost in it. Break it and the PROBE is what fails.
cp "$V" "$V.orig"
sed "s@\[A-Za-z0-9_.-\]+\\\\\.sh\"?\[\[:space:\]\]+--\[a-z\]\[a-z0-9-\]\*@zzz-matches-no-citation@" "$V.orig" > "$V"
if cmp -s "$V.orig" "$V"; then
  bad "FIXTURE BROKEN: the I60 citation-grammar mutation matched nothing, so the liveness arm is unproven"
else
  out="$(vrun)"
  if grep -q "did not fire on its own probe" <<<"$out"; then
    ok "a citation grammar that can no longer match FAILS I60 against its own probe (an extraction that finds nothing never again reads as a tree with no ghost citation)"
  else
    bad "I60's citation extraction was broken so that it matches nothing and the invariant still printed clean — it would stop firing on its first grammar edit and no one would learn of it"
  fi
fi
mv "$V.orig" "$V"
restore

# ARM 4 — THE CORPUS COLLAPSES. The floor is what refuses a derivation that returns almost
# nothing. A probe that still passes plus a corpus of two pairs reads exactly like a clean
# tree, so the count is guarded separately from the grammar.
#
# The mutation repoints the CORPUS SCAN's root and leaves the probe's alone, and that is the
# whole point of the arm rather than an implementation detail. The first version of this arm
# broke the shared citation function instead: the probe reads it too, so the probe fired
# first, the floor was never reached, and the arm failed against a floor that was working.
# A guard downstream of a liveness probe can only be tested on an input the probe still
# passes.
cp "$V" "$V.orig"
sed 's@i60_citations "$REPO_ROOT"@i60_citations "$REPO_ROOT/nonexistent"@g' "$V.orig" > "$V"
if cmp -s "$V.orig" "$V"; then
  bad "FIXTURE BROKEN: the I60 corpus mutation matched nothing, so the floor arm is unproven"
else
  out="$(vrun)"
  if grep -q "I60 derived only" <<<"$out"; then
    ok "a citation corpus that collapses to nothing FAILS I60 loudly (scanning zero files is not the same answer as finding zero ghosts)"
  else
    bad "I60's citation corpus matched no files and the invariant reported clean — every cited mode in the tree was unchecked and the run said so nowhere"
  fi
fi
mv "$V.orig" "$V"
}
# `i93_token` -> the declared empty-subject verdict token, read out of the SEED's own owner.
#
# NEVER TYPED HERE, and that is the whole subject of I93 one level out. A fixture that
# restates a controlled vocabulary is a second copy of it, and a second copy drifts: the day
# the token changes at the owner, a hand-typed seed below would emit a string nothing declares
# and arm D would fire on it for the wrong reason, which is a green cell earned by accident.
# Callers must treat an empty result as FIXTURE BROKEN -- a seed emitting the empty string
# reaches no branch, arm D correctly stays quiet, and that silence would score as a kill.
i93_token() {
  awk '
    /^empty_subject_verdict:/ { on = 1; next }
    on && /^[^[:space:]#]/    { exit }
    on && /^  token:/         { sub(/^  token:[[:space:]]*/, ""); print; exit }
  ' "$ROOT/core/skills/ai-dlc/enforcement-map.yaml"
}

# --- Assertion 35: I93 arm D — the reverse join, over BOTH halves of its population ---
# Arms A and B ask whether every DECLARED emitter emits. Nothing asked the other direction
# until arm D, so a validator that adopted this vocabulary without registering joined it
# silently: docs/vocabulary-index.md under-reported the set, and nothing bound the new file to
# the token if the token ever changed. That is a join running one way, which is the mirror of a
# check that cannot fire -- green forever in the direction nobody watches.
#
# THE TWO POPULATION HALVES ARE SEPARATE ARMS ON PURPOSE. Arm D sweeps core/scripts/ (shipped)
# AND scripts/ (distribution-only), and the file that PROVED the gap -- the one exemption the
# arm carries -- lives in the second. An arm-1-only battery passes against a sweep narrowed to
# core/scripts/, and that narrowing deletes the only half with a live subject in it.
#
# ARM 2 IS THE SAME PATH AS ARM 1 WITH ONE CHARACTER CHANGED. arm D's false-positive narrowing
# is the emission SITE: a `#` line carrying the token is a validator's exit-code table, not an
# emission, and there are dozens of those. Seeding the near-miss at a different path would
# leave the two arms comparing two files; keeping the path fixed makes the pair a differential
# whose only variable is the thing the narrowing keys on.
A35_i93_reverse_join() {
esv_tok="$(i93_token)"
if [ -z "$esv_tok" ]; then
  bad "FIXTURE BROKEN: could not derive empty_subject_verdict.token from the seed's enforcement-map.yaml — every seed below would emit nothing, arm D would rightly stay quiet, and that silence would score as a kill"
  return
fi

# ARM 1 — AN UNDECLARED EMITTER UNDER core/scripts/. Deliberately not named validate-*.sh:
# arm D's population is every FILE in the directory, and a name matching the validator
# convention would leave the assertion unable to tell that from a narrower grammar.
esv_core_new="$ROOT/core/scripts/esv-newcomer.sh"
printf '%s\n' '#!/usr/bin/env bash' "echo \"$esv_tok: this run opened no file\"" > "$esv_core_new"
out="$(vrun)"
if grep -q "core/scripts/esv-newcomer.sh prints '$esv_tok' outside a comment" <<<"$out"; then
  ok "a core/scripts/ file emitting the declared token while the map declares it nowhere FAILS I93 (a validator cannot join this vocabulary without registering)"
else
  bad "an undeclared core/scripts/ emitter of the empty-subject verdict did not fail I93 — the reverse join is one-way again and docs/vocabulary-index.md under-reports the set by one file"
fi

# ARM 2 — THE NEAR-MISS, at the same path. The token in a COMMENT is what every emitter's
# exit-code table already carries; a whole-file `grep -qF` would fire on all of them.
printf '%s\n' '#!/usr/bin/env bash' "#   78 = $esv_tok, in an exit-code table" \
              "  #   and once more, indented, as a header records a retirement" > "$esv_core_new"
out="$(vrun)"
if grep -q 'esv-newcomer.sh' <<<"$out"; then
  bad "arm D fired on a file whose only mention of the token is a COMMENT — every emitter's own exit-code table is that shape, so the arm would demand a declaration for each of them"
elif grep -q '^OK: enforcement-map.yaml in sync' <<<"$out"; then
  ok "a core/scripts/ file carrying the token only in a comment does NOT fail I93, and the run still reaches its verdict (the narrowing is the emission site, not the token)"
else
  bad "the near-miss tree neither failed on the seeded path nor reached I93's OK verdict — the run did not get far enough for this arm's silence to mean anything"
fi
rm -f "$esv_core_new"

# ARM 3 — AN UNDECLARED EMITTER UNDER scripts/. This is the half a core/scripts-only reading
# of the arm would miss, and it is where the file that proved the gap lives.
esv_dist_new="$ROOT/scripts/esv-dist-newcomer.sh"
printf '%s\n' '#!/usr/bin/env bash' "echo \"$esv_tok: this run opened no file\"" > "$esv_dist_new"
out="$(vrun)"
if grep -q "scripts/esv-dist-newcomer.sh prints '$esv_tok' outside a comment" <<<"$out"; then
  ok "an undeclared emitter under scripts/ FAILS I93 too (the distribution-only half of arm D's population is swept, not just core/scripts/)"
else
  bad "an undeclared scripts/ emitter did not fail I93 — arm D's sweep has narrowed to core/scripts/, and the only file that ever demonstrated this gap lives in the half it stopped reading"
fi
rm -f "$esv_dist_new"

# ARM 3b — AN UNDECLARED EMITTER THAT IS NOT A SHELL SCRIPT. Arm D is deliberately wider than
# arm C: arm C sweeps `*.sh` because a retired SPELLING is a shell-grammar question, while
# this arm asks who joined a vocabulary, which no file extension answers. The seed is a `.js`
# because core/scripts/gen-architecture-index.js exists TODAY, so an `*.sh` narrowing would
# reintroduce the same one-way blindness one grain over -- and the two arms above cannot see
# that narrowing, because both of their seeds end in .sh.
esv_js_new="$ROOT/core/scripts/esv-newcomer.js"
printf '%s\n' "console.log(\"$esv_tok: this run opened no file\");" > "$esv_js_new"
out="$(vrun)"
if grep -q "core/scripts/esv-newcomer.js prints '$esv_tok' outside a comment" <<<"$out"; then
  ok "an undeclared emitter that is NOT a .sh FAILS I93 (arm D's population is the directory, not an extension, and a JS validator can join this vocabulary too)"
else
  bad "an undeclared .js emitter did not fail I93 — arm D has narrowed to *.sh, which is the blind spot it exists to close, moved one file type over"
fi
rm -f "$esv_js_new"

# ARM 4 — THE MUTANT, AND WHAT IT ESTABLISHES THAT ARM 1 DOES NOT. Arm 1 asserts a message
# APPEARS; it cannot tell whether arm D produced it or some other I93 arm did, and a kill
# credited to the wrong guard survives arm D's deletion. So arm D's reporter is neutered in a
# copy of the validator, with the SAME seed in place, and the two halves are asserted
# together: the seeded path is no longer named, AND the run still reaches its own OK verdict.
# The second half is what stops this being an absence — a subject replaced by `exit 0` prints
# no verdict and fails here — and it is also the check that the seed trips nothing else, which
# is what makes arm 1 arm D's kill rather than a finding it borrowed from a neighbour.
#
# ANCHORED ON `declares it neither an emitter`, which is arm D's reporter alone. Arm A's
# message and the exemption arm's both contain "outside a comment"; a mutation keyed on the
# shared phrase would edit more than one arm and move cells this assertion never earned.
printf '%s\n' '#!/usr/bin/env bash' "echo \"$esv_tok: this run opened no file\"" > "$esv_core_new"
cp "$V" "$V.orig"
sed 's@^\( *\)err "I93: .*declares it neither an emitter.*@\1:@' "$V.orig" > "$V"
if cmp -s "$V.orig" "$V"; then
  bad "FIXTURE BROKEN: the arm D reporter mutation matched nothing in the validator, so arm 1 above is a message somebody observed and not a finding attributed to arm D"
else
  out="$(vrun)"
  if grep -q 'esv-newcomer.sh' <<<"$out"; then
    bad "arm D's reporter was neutered and the seeded undeclared emitter was STILL named — the finding arm 1 scores as arm D's kill is coming from somewhere else, and deleting arm D would leave this battery green"
  elif grep -q '^OK: enforcement-map.yaml in sync' <<<"$out"; then
    ok "neutering arm D's reporter makes the SAME seeded emitter go unreported while the rest of I93 still reaches its verdict (arm 1's kill belongs to arm D, and the seed trips no other arm)"
  else
    bad "with arm D's reporter neutered the run neither named the seeded emitter nor reached I93's OK verdict — the mutant broke something other than the arm it aimed at, so it proves nothing about arm D"
  fi
fi
mv "$V.orig" "$V"
rm -f "$esv_core_new"
}

# --- Assertion 36: I93 arm D — the exemption is itself checked, in four directions ---
# Arm D carries one exemption: the distribution-only validator that must NOT be declared,
# because enforcement-map.yaml SHIPS and a declared path would resolve nowhere in a consumer
# tree and could never be falsified where it is wrong. An exemption is a hole in a guard, so
# every way the hole can silently widen is its own arm, and each asserts its OWN wording --
# all four would satisfy a grep for "I93".
#
# ARM 2 IS ARM D'S POSITIVE CONTROL AND IS THE ONE THAT MATTERS MOST. Arm D reports an
# ABSENCE. If its sweep stops reading the population, it reports that same absence forever;
# the exemption is the one path the sweep is REQUIRED to find emitting, in the same invocation
# as the zero. An arm-2 that cannot fire makes every zero arm D prints worthless.
A36_i93_exemption_arms() {
esv_tok="$(i93_token)"
# The exempt path is DERIVED from the validator's own ESV_EXEMPT line rather than typed, for
# the reason the token is: a hand-copied path stays green after the exemption moves.
esv_xp="$(awk -F"'" '/^[[:space:]]*ESV_EXEMPT=/ { split($2, a, " "); print a[1]; exit }' "$V")"
if [ -z "$esv_tok" ] || [ -z "$esv_xp" ] || [ ! -f "$ROOT/$esv_xp" ]; then
  bad "FIXTURE BROKEN: could not derive the token and an existing exempt path from the seed (token='$esv_tok', exempt='$esv_xp') — the mutations below would have no subject"
  return
fi

# ARM 1 — THE EXEMPT FILE IS GONE. An exemption naming a path that has moved reads exactly
# like an exemption doing its job, while the sweep's blind spot now covers nothing at all.
mv "$ROOT/$esv_xp" "$ROOT/$esv_xp.hidden"
out="$(vrun)"
mv "$ROOT/$esv_xp.hidden" "$ROOT/$esv_xp"
if grep -q "arm D exempts '$esv_xp' from the reverse join and no such file exists" <<<"$out"; then
  ok "an arm D exemption for a file that no longer exists FAILS I93 (a hole aimed at nothing is a hole nobody can audit)"
else
  bad "arm D exempted a path that is not in the tree and I93 reported clean — the exemption list can be left pointing at moved files indefinitely"
fi

# ARM 2 — THE EXEMPT FILE NO LONGER EMITS. Two readings, and the arm must refuse both: the
# exemption has gone vestigial, or the sweep is not reading its population. Mutating the
# token OUT of the file (rather than deleting the file) is what separates this from arm 1.
cp "$ROOT/$esv_xp" "$ROOT/$esv_xp.orig"
sed "s@$esv_tok@REDACTED BY THE FIXTURE@g" "$ROOT/$esv_xp.orig" > "$ROOT/$esv_xp"
if cmp -s "$ROOT/$esv_xp.orig" "$ROOT/$esv_xp"; then
  bad "FIXTURE BROKEN: the arm D positive-control mutation matched nothing in $esv_xp, so this assertion is unproven"
else
  out="$(vrun)"
  if grep -q "arm D exempts '$esv_xp' and arm D's own sweep found no line of it outside a comment" <<<"$out"; then
    ok "an exempt file that stopped emitting FAILS I93 (arm D's positive control fires in the same invocation as the zero it licenses)"
  else
    bad "the one file arm D's sweep is REQUIRED to find emitting stopped emitting and I93 said nothing — every 'no undeclared emitter' verdict from this arm is now a zero taken over a corpus nobody proved was read"
  fi
fi
mv "$ROOT/$esv_xp.orig" "$ROOT/$esv_xp"

# ARM 3 — BOTH DECLARED AND EXEMPT. Two opposite claims about one file, and nothing
# downstream can tell which was meant. Inserted into the owner's emitters list, scoped to the
# block: the file exists and does emit, so arm A stays quiet and this arm owns the case.
MAPY="$ROOT/core/skills/ai-dlc/enforcement-map.yaml"
cp "$MAPY" "$MAPY.orig"
awk -v add="$esv_xp" '
  /^empty_subject_verdict:/ { on = 1; print; next }
  on && /^[^[:space:]#]/    { on = 0 }
  on && /^  emitters:/      { print; print "    - " add; on = 0; next }
                            { print }
' "$MAPY.orig" > "$MAPY"
if cmp -s "$MAPY.orig" "$MAPY"; then
  bad "FIXTURE BROKEN: the I93 both-declared-and-exempt mutation matched nothing in enforcement-map.yaml, so this assertion is unproven"
else
  out="$(vrun)"
  if grep -q "'$esv_xp' is BOTH declared an emitter" <<<"$out"; then
    ok "a path that is both declared in the map and exempted from arm D FAILS I93 (the two are opposite claims and nothing downstream can resolve them)"
  else
    bad "one path was simultaneously declared an emitter and exempted from the reverse join and I93 accepted both — the map and the exemption list can disagree about the same file silently"
  fi
fi
mv "$MAPY.orig" "$MAPY"

# ARM 4 — AN EXEMPTION WITH NO REASON. An unreasoned exemption is indistinguishable from a
# forgotten declaration, and the next author cannot tell which it was. This one mutates the
# VALIDATOR, since the exemption list lives there. The run also reports the now-unexempted
# file as undeclared, which is correct and is why the assertion is on this arm's OWN wording:
# a grep for the undeclared-emitter message would be satisfied by arm D's ordinary finding.
cp "$V" "$V.orig"
sed "s@^\\([[:space:]]*ESV_EXEMPT='\\)\\([^ ']*\\) [^']*'@\\1\\2'@" "$V.orig" > "$V"
if cmp -s "$V.orig" "$V"; then
  bad "FIXTURE BROKEN: the I93 unreasoned-exemption mutation matched nothing in the validator, so this assertion is unproven"
else
  out="$(vrun)"
  if grep -q "exemption list carries '$esv_xp' with no reason after the path" <<<"$out"; then
    ok "an arm D exemption with no reason after the path FAILS I93 (a bare path reads exactly like a declaration somebody forgot)"
  else
    bad "arm D accepted an exemption with no reason — a hole in the guard can be opened with no record of why, and the next author reading it cannot tell it from an omission"
  fi
fi
mv "$V.orig" "$V"
}

# --- Assertion 37: I93 — arm D's four SELF-PROBE bits can actually fire ---------
# I93 runs a scored probe over a seeded tree BEFORE it reads the corpus, and arm D's decision
# (`esv_undeclared`) is factored out so the probe can drive it in all four directions. On a
# working tree that probe scores 0 and prints nothing, which is precisely the shape of a check
# that cannot fire: nothing else in this battery would notice if the four bits arm D added
# were unreachable, because every OTHER assertion here needs the probe to score 0 in order to
# reach the corpus at all.
#
# SO THE SUBJECT IS MUTATED, NOT THE TREE, and the assertion is on the EXACT SCORE. The score
# names which bits fired: a mutant that neuters the join and one that widens it to match
# everything must produce two DIFFERENT totals, and asserting on the number rather than on
# "the probe complained" is what stops one mutation scoring the other's kill.
A37_i93_probe_arm_d_bits() {
# ARM 1 — THE JOIN RETURNS NOTHING. `return 0` ahead of the body, so the guard matches
# NOTHING rather than everything: a widened guard often prints what the original printed and
# scores a kill it did not earn. Expected 1001000000 = +1000000 (the seeded undeclared path
# was not reported, which is the whole of arm D) +1000000000 (the result is not the one
# expected path). The declared/exempt suppression bits must stay quiet: an empty result
# contains neither, and a total that included them would mean the probe cannot tell a join
# that reports nothing from one that reports everything.
cp "$V" "$V.orig"
sed 's@^esv_undeclared() {$@esv_undeclared() { return 0@' "$V.orig" > "$V"
if cmp -s "$V.orig" "$V"; then
  bad "FIXTURE BROKEN: the I93 esv_undeclared neutering mutation matched nothing, so the probe's arm D bits are unproven"
else
  out="$(vrun)"
  if grep -q "I93's probe scored 1001000000" <<<"$out"; then
    ok "a reverse join that reports nothing is caught by I93's own probe BEFORE the corpus is read (arm D's +1000000 and +1000000000 bits are reachable)"
  else
    bad "esv_undeclared was neutered to return nothing and I93's probe still scored 0 — the four bits guarding arm D cannot fire, so arm D's silence over the real tree establishes only that it ran"
  fi
fi
mv "$V.orig" "$V"

# ARM 2 — THE JOIN REPORTS EVERYTHING. The two membership tests are anchored on the argument
# that SEPARATES them ($2 the declared list, $3 the exempt list), never on the shared call
# shape: one sed keyed on the common text would edit both lines, and a mutation that moves two
# cells scores a kill neither arm earned. Expected 1110000000 = +10000000 (a DECLARED emitter
# came back, so arm D would fire on every conforming file) +100000000 (an EXEMPT one came
# back, so the exemption is inert) +1000000000 (the result is not the one expected path). The
# +1000000 bit must stay quiet here: the undeclared path IS reported, and a total carrying it
# would mean the probe is scoring the mutation rather than the behaviour.
cp "$V" "$V.orig"
sed -e 's@in_lines "$esv_u_p" "$2" && continue@:@' \
    -e 's@in_lines "$esv_u_p" "$3" && continue@:@' "$V.orig" > "$V"
if cmp -s "$V.orig" "$V"; then
  bad "FIXTURE BROKEN: the I93 esv_undeclared widening mutation matched nothing, so the probe's suppression bits are unproven"
else
  out="$(vrun)"
  if grep -q "I93's probe scored 1110000000" <<<"$out"; then
    ok "a reverse join that reports DECLARED and EXEMPT files too is caught by the same probe (the suppression bits score separately from the fires-at-all bit)"
  else
    bad "esv_undeclared was widened to report every file it was handed and I93's probe did not score it — arm D could fail the tree as it stands, on files the map declares, with nothing upstream to catch it"
  fi
fi
mv "$V.orig" "$V"
}


# --- Assertion 38: I93 arm D -- an ABORTED sweep is attributed, and only once -----
# BSD awk ABORTS on a path it cannot open rather than skipping it, so ONE broken symlink in
# core/scripts/ or scripts/ ends arm D's walk. Before the scan-status arm existed the run still
# went red -- correctly, because the exemption control refused to certify a zero over a corpus
# nobody finished reading -- but the only message named the EXEMPTION, sending the reader to
# scripts/validate-plan-shape.sh when the cause was a dangling link somewhere else.
#
# THE ARM IS THE PAIR, NOT EITHER HALF. Asserting the new message APPEARS would pass while the
# exemption message also fired, which is the state this exists to end; asserting the exemption
# message is ABSENT would pass against a validator that stopped checking exemptions at all. So
# both are asserted in one arm, over one tree, and the finding COUNT is asserted too -- one
# cause must produce exactly one finding.
A38_i93_scan_status() {
esv_tok="$(i93_token)"
if [ -z "$esv_tok" ]; then
  bad "FIXTURE BROKEN: could not derive empty_subject_verdict.token from the seed, so this arm has no subject"
  return
fi

# A DANGLING SYMLINK, not a chmod 000 file: a permissions seed behaves differently for root,
# and a fixture whose subject depends on who runs it is a fixture that reports the runner.
esv_dangle="$ROOT/scripts/esv-dangling.sh"
ln -s /nonexistent/esv-target "$esv_dangle"
if [ -e "$esv_dangle" ]; then
  rm -f "$esv_dangle"
  bad "FIXTURE BROKEN: the seeded symlink RESOLVES, so awk can open it and this arm's subject does not exist"
  return
fi
out="$(vrun)"
rm -f "$esv_dangle"

esv_n="$(printf '%s\n' "$out" | grep -c '^FAIL: I93')"
if ! grep -q "did not finish reading its population" <<<"$out"; then
  bad "a path arm D cannot open ended its sweep and I93 did not say so -- the run's only diagnosis is a bare awk error on stderr, and every absence arm D reported came from a walk that stopped early"
elif grep -q "arm D exempts .* and arm D's own sweep found no line of it" <<<"$out"; then
  bad "an aborted sweep fired BOTH the scan-status arm and the exemption control -- one cause, two findings, and the second one names scripts/validate-plan-shape.sh, which is not the file at fault"
elif [ "$esv_n" -ne 1 ]; then
  bad "an aborted sweep produced $esv_n I93 finding(s) where exactly 1 is correct -- one cause must yield one finding, or the reader cannot tell which arm owns the case"
else
  ok "a path arm D cannot open is reported BY THE SCAN-STATUS ARM and by that arm alone (the exemption control stands down, so one cause yields one finding and it names the right question)"
fi

# THE STAND-DOWN MUST NOT HAVE DISARMED THE EXEMPTION CONTROL. Same tree, no dangling link,
# exempt file mutated to stop emitting: the control it just stood aside for must still fire on
# its OWN case. Without this, deleting the exemption check entirely would pass the arm above.
XP="$ROOT/scripts/validate-plan-shape.sh"
cp "$XP" "$XP.orig"
sed "s@$esv_tok@REDACTED BY THE FIXTURE@g" "$XP.orig" > "$XP"
if cmp -s "$XP.orig" "$XP"; then
  bad "FIXTURE BROKEN: the exempt-file mutation matched nothing, so the stand-down's counterpart is unproven"
else
  out="$(vrun)"
  if grep -q "arm D exempts .* and arm D's own sweep found no line of it" <<<"$out"; then
    ok "the exemption control still fires on its OWN case when the sweep COMPLETED (the stand-down narrowed it to the aborted-scan case rather than switching it off)"
  else
    bad "the exemption control no longer fires when an exempt file stops emitting -- the stand-down disarmed arm D's positive control, and every zero it licenses is now unproven"
  fi
fi
mv "$XP.orig" "$XP"
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
  # THE LEDGER AND THE BROKEN MARKER ARRIVE AS ARGUMENTS, NEVER AS ENVIRONMENT, for the same
  # reason --group does: this file scrubs every ambient AI_DLC_* name above, so an environment
  # variable would be unset before the line that read it, the ledger would be silently empty,
  # and the selection control at the foot would report a conversion that never happened.
  VRUN_LOG="${3:-}"
  VRUN_BROKEN="$(mktemp)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
  seed_tree
  trap 'rm -rf "$ROOT"; rm -f "$VRUN_BROKEN"' EXIT
  "$FN"
  # A SELECTION FAILURE IS NOT A FINDING. vrun cannot exit the process from inside a command
  # substitution, so it records here instead; 2 is the code the driver routes to FIXTURE
  # BROKEN, which is the answer "nothing was tested" rather than "the check regressed".
  if [ -s "$VRUN_BROKEN" ]; then
    cat "$VRUN_BROKEN" >&2
    exit 2
  fi
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

# ---------------------------------------------------------------------------
# THE SHARD SPLIT, AND IT IS A MEASUREMENT RATHER THAN A PREFERENCE
# ---------------------------------------------------------------------------
# This file's assertions were the pre-push suite's ENTIRE wall clock, and an inner pool did
# not fix it. The suite is POLE-BOUND: its makespan tracks its single longest unit, and the
# unit here is a DIRECTORY, because `core/fixtures/*/run.sh` is what the outer pool
# schedules. Measured across five outer pool sizes on one idle 18-core box, with this
# fixture's own 8-way inner pool already in place:
#
#     AI_DLC_FIXTURE_JOBS   16     12     10      8      4
#     suite makespan       256s   256s   248s   246s   (>240s)
#     this fixture         253s   ~250s  248s   246s
#
# The makespan EQUALS this unit at every setting, because it starts at t=0 and is still
# running when everything else has finished. No outer pool size reaches it, and no inner
# pool size does either: the inner pool is already 8-way and the unit still costs 130s with
# the machine entirely to itself.
#
# So the fixture is SHARDED ACROSS DIRECTORIES, which is the same move and the same reason
# as `trunk-audit-mutants` being split out of `trunk-audit-classes`. Each shard is a
# directory the outer pool can start independently and interleave with everything else.
#
# ROUND-ROBIN, NOT CONTIGUOUS THIRDS. These assertions differ by an order of magnitude in
# cost — several seed a tree and run one validator, a few run it three times over rebuilt
# trees — so a contiguous cut puts the expensive neighbours in one shard and rebuilds the
# pole inside it. Dealing them out in turn spreads that without anyone having to maintain a
# cost table that would go stale the first time an assertion changed.
#
# EVERY SHARD RUNS THE CONTROL. A00 is the arm that says the validator is not simply broken,
# and a shard without it would report its own assertions as kills earned against a tree
# nobody checked. It costs one validator run per shard and it is not optional.
SHARDS="a b c"

# THE SHARD ARRIVES AS AN ARGUMENT, NOT AS AN ENVIRONMENT VARIABLE, and that is not a style
# choice. This file scrubs every ambient AI_DLC_* name near the top for I10 — a fixture must
# not inherit a tunable that changes what it measures — and the scrub is deliberately ordered
# ahead of everything. An `AI_DLC_EMS_GROUP` would therefore be unset before this line ever
# read it, every shard would silently fall back to 'a', and the suite would run shard 'a'
# three times while reporting three green fixtures. Arguments survive the scrub.
GROUP=a
if [ "${1:-}" = "--group" ]; then
  GROUP="${2:-}"
  [ -n "$GROUP" ] || { echo "FIXTURE ERROR: --group needs a shard name" >&2; exit 2; }
fi
case " $SHARDS " in
  *" $GROUP "*) ;;
  *) echo "FIXTURE ERROR: unknown shard '$GROUP' (known: $SHARDS)" >&2; exit 2 ;;
esac

# THE COVERAGE JOIN. Sharding moves assertions out of this directory, so the failure mode it
# introduces is a shard whose directory is deleted, renamed, or never installed: the suite
# then runs fewer assertions and reports a shorter green run, which is this repository's
# named recurring defect wearing a new hat. Shard `a` therefore DERIVES the set of shards
# that actually exist beside it and refuses to pass if any declared shard has no driver.
# The control is the same grep finding this file's own sibling directories at all.
if [ "$GROUP" = a ]; then
  missing=""
  for _s in $SHARDS; do
    [ "$_s" = a ] && continue
    [ -f "$HERE/../enforcement-map-sites-$_s/run.sh" ] || missing="$missing $_s"
  done
  if [ -n "$missing" ]; then
    echo "FIXTURE ERROR: shard(s)$missing declared in SHARDS have no driver directory beside this one." >&2
    echo "  Their assertions would run NOWHERE, and this suite would report a shorter green run." >&2
    exit 2
  fi
fi

NAME="enforcement-map-sites"
[ "$GROUP" = a ] || NAME="enforcement-map-sites-$GROUP"

echo "$NAME:"

OUT="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$OUT"' EXIT
SELF="$HERE/$(basename "$0")"

# The control, first and alone. Its verdict licenses every assertion after it, so a failure
# here stops the run rather than reporting 28 unattributable kills.
CTL="$(printf '%s\n' "$NAMES" | head -1)"
bash "$SELF" --run-one "$CTL" "$OUT/$CTL.vrun" > "$OUT/$CTL" 2>"$OUT/$CTL.err"
ctl_rc=$?
cat "$OUT/$CTL"
if [ "$ctl_rc" -ne 0 ]; then
  [ -s "$OUT/$CTL.err" ] && cat "$OUT/$CTL.err" >&2
  echo
  echo "$NAME: 1 assertion(s) FAILED" >&2
  exit 2
fi

# EIGHT, and it is a fixed number rather than a tunable on purpose: this pool nests inside
# the pre-push suite's own pool, so a knob here multiplies against a knob there and the
# product is what lands on the machine. Eight against 18 cores leaves headroom for the
# seven sibling fixtures the suite runs beside this one.
JOBS=8
# Deal the non-control assertions out to the shards in turn. The partition is DERIVED from
# the same list the control came off, so an assertion added to this file lands in a shard
# automatically rather than needing a table updated in a second place.
printf '%s\n' "$NAMES" | tail -n +2 \
  | awk -v g="$GROUP" -v shards="$SHARDS" '
      BEGIN { n = split(shards, S, " ") }
      { if (S[((NR - 1) % n) + 1] == g) print }
    ' > "$OUT/list"
N_MINE="$(grep -c . "$OUT/list" || true)"
if [ "$N_MINE" -eq 0 ]; then
  echo "$NAME: FIXTURE ERROR — shard '$GROUP' was dealt no assertions out of $N_LISTED; an empty shard passes every assertion it never made" >&2
  exit 2
fi
AI_DLC_EMS_SELF="$SELF" AI_DLC_EMS_OUT="$OUT" \
  xargs -P "$JOBS" -I{} bash -c '
    n="$1"
    bash "$AI_DLC_EMS_SELF" --run-one "$n" "$AI_DLC_EMS_OUT/$n.vrun" \
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

# THE SELECTION CONTROL: A CONVERSION THAT STOPS SELECTING MUST BE RED, NOT MERELY SLOW.
# Each assertion runs the validator through `vrun`, which records the id it selected into a
# per-assertion ledger. A `vrun` call reverted to a full `bash "$V"` still passes its own
# predicate -- a full run contains everything a selected run would have printed -- so nothing
# in the assertions themselves can notice, and the only symptom would be the wall clock going
# back to where it was. That is exactly the shape of a mechanism that quietly stopped running.
#
# BOTH SIDES ARE DERIVED, and neither is a list. The expectation is this shard's own dealt
# assertion list; the observation is which of those wrote a ledger. The complement is derived
# too: the control assertion -- the one deliberately left on a FULL run, because "the pristine
# tree passes" is an absence-shaped claim over EVERY arm -- must have recorded nothing, so a
# control that quietly started selecting fails here as well. An empty dealt list is already a
# FIXTURE ERROR above, which is what stops this join being satisfied by having no subjects.
sel_got=0
sel_bad=""
while IFS= read -r n; do
  [ -n "$n" ] || continue
  if [ -s "$OUT/$n.vrun" ]; then sel_got=$((sel_got + 1)); else sel_bad="$sel_bad $n"; fi
done < "$OUT/list"
if [ -s "$OUT/$CTL.vrun" ]; then sel_bad="$sel_bad $CTL(selected an arm; it must stay a full run)"; fi
if [ "$sel_got" -ne "$N_MINE" ] || [ -n "$sel_bad" ]; then
  printf '  FAIL  arm selection did not happen as dealt: %d of %d assertion(s) in shard %s recorded an --arms run (offenders:%s). Every assertion but the control selects the one arm it tests; one that stopped is running every arm and asserting nothing more for it\n' "$sel_got" "$N_MINE" "$GROUP" "$sel_bad"
  fails=$((fails + 1))
fi

echo
if [ "$broken" -ne 0 ]; then
  echo "$NAME: FIXTURE BROKEN — an assertion could not run to a verdict" >&2
  exit 2
fi
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
