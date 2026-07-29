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

HERE="$(cd "$(dirname "$0")" && pwd)"

# Distribution-only. `validate-enforcement-map.sh` is not shipped by install.sh (it checks
# the distribution's own two writers against each other — a consumer has neither), so in a
# consumer tree there is nothing to test. Say so and stop; do not fake a pass.
if [ ! -f "$HERE/../../../scripts/validate-enforcement-map.sh" ]; then
  echo "enforcement-map-sites: SKIP — distribution-only (validate-enforcement-map.sh is not shipped to consumers)"
  exit 0
fi

ROOT="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$ROOT"' EXIT

V="$ROOT/scripts/validate-enforcement-map.sh"
PRECLASS="$ROOT/core/skills/ai-dlc-update/reconcile/preclassify.sh"
INSTALL="$ROOT/scripts/install.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# Restore the seed to pristine between mutations.
restore() { rm -rf "$ROOT/core" "$ROOT/scripts"; local d; d="$(bash "$HERE/seed.sh")"; rm -rf "$ROOT"; ROOT="$d"; V="$ROOT/scripts/validate-enforcement-map.sh"; PRECLASS="$ROOT/core/skills/ai-dlc-update/reconcile/preclassify.sh"; INSTALL="$ROOT/scripts/install.sh"; }

echo "enforcement-map-sites:"

# --- Assertion 0: SANITY ------------------------------------------------------
# The pristine tree must PASS. If it does not, the validator is erroring for some reason
# of its own and every "it failed as expected" below is a false pass.
if bash "$V" >/dev/null 2>&1; then
  ok "pristine distribution tree passes (the negatives below mean something)"
else
  bad "FIXTURE BROKEN — the pristine tree does not pass validate-enforcement-map.sh. Every assertion below would be a false pass."
  echo; echo "enforcement-map-sites: $fails assertion(s) FAILED" >&2; exit 2
fi

# --- Assertion 1: COMPLETENESS ------------------------------------------------
# A new core/<dir>/ with no row must be an ERROR, not a silent fall-through to the
# `core/*` catch-all. This is the one that would have caught git-hooks.
mkdir -p "$ROOT/core/brand-new-subtree"
echo 'x' > "$ROOT/core/brand-new-subtree/thing.sh"
out="$(bash "$V" 2>&1)"
if printf '%s' "$out" | grep -q "core/brand-new-subtree/ has no destination row"; then
  ok "a new core/ subtree with no site row FAILS (the catch-all can no longer swallow one silently)"
else
  bad "a new core/ subtree with no site row did NOT fail — I8 is hand-listed again, and the next core/<dir>/ ships to a path nothing reads"
fi
restore

# --- Assertion 2: AGREEMENT ---------------------------------------------------
# Delete map_consumer()'s git-hooks case and I8 must catch it. This replays the exact
# v0.55.1 state of the tree: install.sh writes .githooks/, the pull writes .claude/git-hooks/.
grep -q 'core/git-hooks/\*)' "$PRECLASS" || bad "FIXTURE STALE: preclassify.sh has no core/git-hooks/ case to remove"
sed -i.bak '/core\/git-hooks\/\*)/d' "$PRECLASS"
out="$(bash "$V" 2>&1)"
if printf '%s' "$out" | grep -q "disagree on where core/git-hooks/ goes"; then
  ok "map_consumer() losing its git-hooks case FAILS (the v0.53.0 regression cannot return)"
else
  bad "map_consumer() with no git-hooks case did NOT fail — the pre-push gate would ship to .claude/git-hooks/ again"
fi
restore

# --- Assertion 3: INSTALLER BINDING -------------------------------------------
# A row is only true if install.sh really writes there. Remove the .githooks write and the
# row must stop being satisfiable — otherwise the table could be kept "green" by asserting
# a destination the installer abandoned.
grep -q 'PROJECT_ROOT/.githooks' "$INSTALL" || bad "FIXTURE STALE: install.sh has no .githooks write to remove"
sed -i.bak 's|"\$PROJECT_ROOT/\.githooks|"$PROJECT_ROOT/.githooks-REMOVED|g' "$INSTALL"
out="$(bash "$V" 2>&1)"
if printf '%s' "$out" | grep -q "install.sh never writes"; then
  ok "a site row whose destination install.sh abandoned FAILS (the table is bound to the installer, not to itself)"
else
  bad "install.sh dropping .githooks did NOT fail — I8's table can assert a destination nothing writes"
fi
restore

# --- Assertion 4: I12 SCAN-MATCH ----------------------------------------------
# unregistered-drift.sh's scan set is bound to I12's per-subtree policy. Drop a scan-marked
# subtree from the tool's ls-tree and I12 must catch the divergence — this is what stops the
# scan set silently rotting the way ai-dlc-setup/ and schemas/ did.
UD="$ROOT/core/skills/ai-dlc-update/reconcile/unregistered-drift.sh"
if grep -q 'core/hooks core/schemas' "$UD"; then
  sed -i.bak 's| core/hooks core/schemas | core/hooks |' "$UD"
  out="$(bash "$V" 2>&1)"
  if printf '%s' "$out" | grep -q "I12:.*does NOT scan them: schemas"; then
    ok "unregistered-drift.sh dropping core/schemas from its scan FAILS I12 (the scan set is bound, not hand-listed)"
  else
    bad "dropping core/schemas from the scan did NOT fail I12 — the scan set can rot silently again"
  fi
  restore
else
  bad "FIXTURE STALE: unregistered-drift.sh no longer scans 'core/hooks core/schemas'"
fi

# --- Assertion 5: I12 COMPLETENESS --------------------------------------------
# A new core/<dir>/ with no policy row must FAIL — a new subtree cannot silently escape the scan.
mkdir -p "$ROOT/core/brand-new-subtree"
echo 'x' > "$ROOT/core/brand-new-subtree/thing.md"
out="$(bash "$V" 2>&1)"
if printf '%s' "$out" | grep -q "core/brand-new-subtree/ has no drift-scan policy row"; then
  ok "a new core/ subtree with no I12 policy row FAILS (a new dir must be classified scan/exempt before it can ship)"
else
  bad "a new core/ subtree with no I12 policy row did NOT fail — the scan set is hand-listed again"
fi
restore

# --- Assertion 6: I15 GRAMMAR FORK --------------------------------------------
# layer-drift.sh REPORTS a heading-number collision; relabel-extension-checks.sh FIXES it.
# relabel shipped the narrower grammar for ~20 versions, so core's real `### H1.` yielded no
# anchor and a collision on it was unrelabellable — the operator was told to relabel with a
# tool that could not see the heading. Narrow one copy and I15 must catch the fork.
RELABEL="$ROOT/core/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh"
if grep -q '^ANCHOR_RE=' "$RELABEL"; then
  sed -i.bak "s|^ANCHOR_RE=.*|ANCHOR_RE='^#{2,4} [0-9]+[a-z]*\\\\.'|" "$RELABEL"
  out="$(bash "$V" 2>&1)"
  if printf '%s' "$out" | grep -q "the anchor grammar has forked"; then
    ok "narrowing relabel's ANCHOR_RE FAILS I15 (the reporter and the fixer cannot drift apart)"
  else
    bad "narrowing relabel's ANCHOR_RE did NOT fail I15 — the two grammars can fork again and H1-style collisions go unrelabellable"
  fi
  restore
  RELABEL="$ROOT/core/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh"
else
  bad "FIXTURE STALE: relabel-extension-checks.sh no longer defines ANCHOR_RE"
fi

# --- Assertion 7: I15 NON-VACUITY ---------------------------------------------
# I15 greps both files for ANCHOR_RE. If a definition simply vanishes, the check must say so
# rather than find nothing and pass — "no definitions to compare" must never read as "equal".
if grep -q '^ANCHOR_RE=' "$RELABEL"; then
  sed -i.bak '/^ANCHOR_RE=/d' "$RELABEL"
  out="$(bash "$V" 2>&1)"
  if printf '%s' "$out" | grep -q "I15 cannot find an ANCHOR_RE definition"; then
    ok "deleting an ANCHOR_RE definition FAILS I15 loudly (it cannot pass by comparing nothing)"
  else
    bad "deleting an ANCHOR_RE definition did NOT fail I15 — the check goes vacuous exactly when the grammar is missing"
  fi
  restore
fi

# --- Assertion 7b: I17 THE WRITER ---------------------------------------------
# map_consumer() only CLASSIFIES. reconcile/apply.sh is what actually PLACES files on a pull,
# and it was bound to nothing — it kept a private hand-listed copy of the site table and
# omitted session-driver, ci-templates and git-hooks, which therefore never applied while the
# same run re-stamped .ai-dlc-version anyway. Give apply.sh a private table again and I17
# must catch it, exactly as I8 catches map_consumer drifting.
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
  if printf '%s' "$out" | grep -q "sends core/session-driver/ to"; then
    ok "apply.sh regrowing a private path table FAILS I17 (the pull's WRITER is bound to the installer, not just the classifier)"
  else
    bad "apply.sh with a hand-listed table missing session-driver did NOT fail I17 — a subtree can silently not apply while the run re-stamps, and the consumer's stamp claims a version its tree lacks"
  fi
  restore
else
  bad "FIXTURE STALE: apply.sh no longer defines consumer_path()"
fi

# --- Assertion 8: I16 DEAD PROSE PATH -----------------------------------------
# The real bug: Check 19 cited `core/team-roles/code-reviewer.md`, a path that exists in the
# distribution and at NO consumer. install.sh maps core/<x> -> .claude/<x>, but that moves
# FILES, not the paths written inside them. Plant one and I16 must fire.
printf '\nSee `core/team-roles/dev.md` for the map.\n' >> "$ROOT/core/skills/ai-dlc/steps/gate-validation.md"
out="$(bash "$V" 2>&1)"
if printf '%s' "$out" | grep -q "runtime-pipeline prose cites a distribution path"; then
  ok "a core/-prefixed prose path in a runtime step file FAILS I16 (installed core cannot ship a dead citation)"
else
  bad "a core/-prefixed prose path did NOT fail I16 — installed core can cite the distribution's layout again, and one dead link already cost a live gate rule"
fi
restore

# --- Assertion 9: I16 PRECISION -----------------------------------------------
# The other side of the same check, and the one that keeps it usable. The word "core" is
# everywhere in this rulebook ("core rule", "core catalog", "core-path wiring"), and the
# update machinery cites `core/...` paths BY DESIGN — comparing distribution to consumer is
# its whole job. If I16 flags either, it gets switched off and stops catching the real thing.
printf '\nThe core rule lives in the core catalog; core-path wiring is a core concern.\n' \
  >> "$ROOT/core/skills/ai-dlc/steps/gate-validation.md"
printf '\nDiff base->theirs restricted to `core/skills/ai-dlc-update/**` and `core/team-roles/dev.md`.\n' \
  >> "$ROOT/core/skills/ai-dlc-update/SKILL.md"
out="$(bash "$V" 2>&1)"
if printf '%s' "$out" | grep -q "runtime-pipeline prose cites a distribution path"; then
  bad "I16 fired on the English word 'core' or on ai-dlc-update's by-design core/ citations — a check with false positives is a check the operator turns off"
else
  ok "I16 ignores the English word 'core' and ai-dlc-update's by-design core/ paths (precise enough to stay on)"
fi
restore

# --- Assertion 10: I21 FOURTH COPY --------------------------------------------
# `section_of()` shipped divergent twice (v0.52.0 weaker, v0.54.2 stricter), and both
# times the remedy was a hand-copy and a CHANGELOG line saying "there is one resolver".
# v0.90.0 collapsed the three copies into lib.sh — that fixed the INSTANCES. The HOLE is
# that nothing stopped a fourth file inlining its own, and a private resolver fails
# silently: the tool reports a confident verdict computed from a different section.
RLIB_F="$ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
APPLY_F="$ROOT/core/skills/ai-dlc-update/reconcile/apply.sh"
printf '\nsection_of() { echo private; }\n' >> "$APPLY_F"
out="$(bash "$V" 2>&1)"
if printf '%s' "$out" | grep -q "I21 reconcile/apply.sh defines its own section_of()"; then
  ok "a fourth inline section_of() FAILS I21 (the resolver cannot fork a third time)"
else
  bad "a fourth inline section_of() did NOT fail I21 — the divergence that shipped in v0.52.0 and v0.54.2 can return, and nothing compares the copies"
fi
restore
RLIB_F="$ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"

# --- Assertion 11: I21 UNSOURCED CALL -----------------------------------------
# The other direction. A classifier that calls section_of() without sourcing lib.sh gets
# an EMPTY section back on a consumer's pull, and an empty section reads as "no drift"
# rather than as an error — the same shape as the v0.52.0 cleared block.
REG_F="$ROOT/core/skills/ai-dlc-update/reconcile/register-drift.sh"
if grep -q '^\. "\$SELF/lib\.sh"' "$REG_F"; then
  sed -i.bak '/^\. "\$SELF\/lib\.sh"/d' "$REG_F"
  out="$(bash "$V" 2>&1)"
  if printf '%s' "$out" | grep -q "I21 reconcile/register-drift.sh calls section_of() but never sources"; then
    ok "a classifier that drops its lib.sh source FAILS I21 (a call that resolves to nothing cannot ship)"
  else
    bad "register-drift.sh dropping its lib.sh source did NOT fail I21 — section_of() resolves to nothing on a real pull and the empty section reads as 'no drift'"
  fi
  restore
  RLIB_F="$ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
else
  bad "FIXTURE STALE: register-drift.sh no longer sources lib.sh at the expected anchor"
fi

# --- Assertion 12: I21 NON-VACUITY --------------------------------------------
# I21 derives the helper set from lib.sh's own definitions. If those stop matching — the
# library emptied, or its definition form changed — the check must say so rather than bind
# an empty set and pass. "Nothing to compare" must never read as "no second copy exists".
if grep -qE '^[a-z_]+\(\) \{' "$RLIB_F"; then
  grep -vE '^[a-z_]+\(\) \{' "$RLIB_F" > "$RLIB_F.tmp" && mv "$RLIB_F.tmp" "$RLIB_F"
  out="$(bash "$V" 2>&1)"
  if printf '%s' "$out" | grep -q "I21 found no function definitions"; then
    ok "lib.sh losing its definitions FAILS I21 loudly (it cannot pass by binding an empty helper set)"
  else
    bad "emptying lib.sh did NOT fail I21 — the check goes vacuous exactly when the single home stops being one"
  fi
  restore
else
  bad "FIXTURE STALE: reconcile/lib.sh no longer defines helpers in the '<name>() {' form I21 derives from"
fi

# --- Assertion 13: I31 SCAN SET HAS A DISPOSITION -----------------------------
# I12 makes a subtree REPORTABLE; it says nothing about what the operator does next, and the
# report hands them exactly one command. `skills/ai-dlc-setup` and `schemas` were both
# scan-marked and both fell to register-drift.sh's `unrecognized core path` — a message that
# reads like a typo in a path the report itself supplied. Drop the named no-grain refusal and
# I31 must name the subtrees left without a disposition.
RD_F="$ROOT/core/skills/ai-dlc-update/reconcile/register-drift.sh"
if grep -q '^  schemas/\*|skills/ai-dlc-setup/\*)' "$RD_F"; then
  sed -i.bak 's@^  schemas/\*|skills/ai-dlc-setup/\*)@  never-matches-a-real-path/*)@' "$RD_F"
  out="$(bash "$V" 2>&1)"
  if printf '%s' "$out" | grep -q "I31: these core subtrees are I12 'scan'"; then
    ok "removing register-drift's no-grain refusal FAILS I31 (a scan-marked subtree cannot reach an unnamed refusal)"
  else
    bad "removing the no-grain refusal did NOT fail I31 — a scan-marked subtree can be reported with no sanctioned disposition again"
  fi
  restore
  RD_F="$ROOT/core/skills/ai-dlc-update/reconcile/register-drift.sh"
else
  bad "FIXTURE STALE: register-drift.sh no longer carries the schemas/ai-dlc-setup no-grain case"
fi

# --- Assertion 14: I31 NON-VACUITY --------------------------------------------
# I31 derives register-drift's side by parsing its `case` labels. If that parse yields nothing
# — the case block moved, or its formatting changed — the comparison binds an empty set and
# EVERY scan subtree reads as undisposed, or worse, the check quietly passes. It must say so.
if grep -q '^case "\$REL" in' "$RD_F"; then
  # Remove the parse's opening anchor. Everything after it is untouched, so the case labels are
  # still there on disk and only the DERIVATION goes blind — which is the vacuity being tested.
  grep -v '^case "\$REL" in' "$RD_F" > "$RD_F.tmp" && mv "$RD_F.tmp" "$RD_F"
  out="$(bash "$V" 2>&1)"
  if printf '%s' "$out" | grep -q "I31: could not parse any case label"; then
    ok "an unparseable case block FAILS I31 loudly (it cannot pass by comparing against nothing)"
  else
    bad "an unparseable case block did NOT fail I31 — the check goes vacuous exactly when register-drift's dispositions become unreadable"
  fi
  restore
else
  bad "FIXTURE STALE: register-drift.sh no longer opens with 'case \"\$REL\" in'"
fi

# --- Assertion 15: I32 PIN vs INVOCATION --------------------------------------
# Check 17's arms pin a provenance block to a skill NAME; the step file that runs the
# evaluation names the skill it INVOKES. Two files, one fact, nothing comparing them —
# v0.169.0 repointed research-requirements.md §3 to /bmad-prd and left the arm pinning the
# old name, and no check said so for three minors. Repoint an arm at a bmad skill its own
# step file does not name and I32 must catch it.
GV_F="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"
if grep -qE '^  bmad-prd`\.$' "$GV_F"; then
  sed -i.bak 's/^  bmad-prd`\.$/  bmad-party-mode`./' "$GV_F"
  out="$(bash "$V" 2>&1)"
  if printf '%s' "$out" | grep -q "I32: Check 17's 'research-requirements phase' arm"; then
    ok "an arm pinning a skill its step file never invokes FAILS I32 (a pin and an invocation are one fact in two files)"
  else
    bad "repointing the PRD arm at an uninvoked skill did NOT fail I32 — the pin can fork from the step again"
  fi
  restore
  GV_F="$ROOT/core/skills/ai-dlc/steps/gate-validation.md"
else
  bad "FIXTURE STALE: Check 17's PRD arm no longer pins bmad-prd on its own line"
fi

# --- Assertion 16: I32 NON-VACUITY --------------------------------------------
# Every I32 guard runs INSIDE the per-arm loop, so an arm grammar that stops matching scans
# nothing and reports clean — which is precisely the shape this check exists to end. Break
# the flag the arms are parsed on and the check must say it compared nothing.
if grep -q -- '--require-skill' "$GV_F"; then
  sed -i.bak 's/--require-skill/--require-SKILL/g' "$GV_F"
  out="$(bash "$V" 2>&1)"
  if printf '%s' "$out" | grep -q "I32 matched no bmad-\* skill pin"; then
    ok "an unparseable arm grammar FAILS I32 loudly ('nothing to compare' never reads as 'the pins agree')"
  else
    bad "breaking the arm grammar did NOT fail I32 — the check goes vacuous exactly when the arms become unreadable"
  fi
  restore
else
  bad "FIXTURE STALE: Check 17's arms no longer carry --require-skill"
fi

# --- Assertion 17: I33 FIXTURE PATH WALK --------------------------------------
# A fixture that locates a core file by walking up from a path ANOTHER resolver produced is
# green in the distribution and red on every consumer, because the install mapping splits the
# subtrees (core/scripts -> scripts/ai-dlc, core/schemas -> .claude/schemas). Step 2 requires
# the derived fixtures green BEFORE the push, so that red is a permanent stop on the
# self-update — it shipped once and blocked a consumer's cycle. Reintroduce the walk and I33
# must name the offending fixture.
SP_F="$ROOT/core/fixtures/story-provenance/run.sh"
# The walk is COMPOSED, never written literally. I33 greps for the pattern, so a fixture that
# spelled its own mutant out would flag itself — the same self-reference trap the ledger's close
# vocabulary hit. Split across the quote boundary, the two halves are not adjacent in THIS file
# and are adjacent in the file it writes, which is the only place it matters.
if grep -q -- '--print-schema' "$SP_F"; then
  walk='$(dirname "$WRITER")/..'"/schemas/provenance-block.json"
  sed -i.bak "s@^SCHEMA_SRC=.*\$@SCHEMA_SRC=\"$walk\"@" "$SP_F"
  out="$(bash "$V" 2>&1)"
  if printf '%s' "$out" | grep -q "I33: these fixtures reach a core subtree by walking up"; then
    ok "a fixture walking up from a resolved script into another core subtree FAILS I33"
  else
    bad "the walk-up path was not caught by I33 — a fixture can go green here and red on every consumer again"
  fi
  restore
  SP_F="$ROOT/core/fixtures/story-provenance/run.sh"
else
  bad "FIXTURE STALE: story-provenance/run.sh no longer resolves its schema via --print-schema"
fi

# --- Assertion 18: I33 NON-VACUITY --------------------------------------------
# I33 greps a tree. Empty that tree and it finds nothing and reports clean — the exact reading
# ("no hits" = "no defect") that the check exists to distinguish from a real pass.
if [ -d "$ROOT/core/fixtures" ]; then
  find "$ROOT/core/fixtures" -name '*.sh' -type f -delete 2>/dev/null
  out="$(bash "$V" 2>&1)"
  if printf '%s' "$out" | grep -q "I33 found no \*.sh under core/fixtures/"; then
    ok "an empty fixture tree FAILS I33 loudly (a scan over nothing never reads as clean)"
  else
    bad "I33 reported clean over an empty fixture tree — 'no hits' is indistinguishable from 'no defect'"
  fi
  restore
else
  bad "FIXTURE STALE: the seed no longer copies core/fixtures/"
fi

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
    if printf '%s' "$out" | grep -q "restates the core path set"; then
      ok "a line naming three manifest entries FAILS I26 (the derived set cannot be quietly replaced by a list)"
    else
      bad "a restated core path list did NOT fail I26 — the check that stopped six core subtrees being silently skipped is not firing"
    fi
  fi
  restore
fi

# --- Assertion 20: I40 — the anchor reading cannot fork -----------------------
# Three functions are byte-identical across `core/scripts/validate-layer-entries.sh` (ERRORs at
# authoring time) and `reconcile/lib.sh` (reports at pull time). They are COPIES because neither
# tree may source the other's file — I25's reason and I29's — so an assertion is the only thing
# stopping the drift, and every one of the three has already forked once in this repo's history.
#
# TWO ARMS, because the vacuity arm is the one that matters: I40 LOCATES its subjects by awk
# range, and a renamed or deleted function makes it find nothing. "Found nothing" and "found two
# identical bodies" are the same green unless the check says so itself.
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
    if printf '%s' "$out" | grep -q "the anchor reading has forked"; then
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
    if printf '%s' "$out" | grep -q "I40 cannot find a shadow_parts() definition"; then
      ok "a MISSING bound function FAILS I40 loudly (finding nothing never reads as agreement)"
    else
      bad "I40 reported clean with shadow_parts() deleted from one side — a rename silently retires the binding"
    fi
  fi
  restore
fi

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
  if printf '%s' "$out" | grep -q "core allocates rule number(s) at or above the reserved consumer band"; then
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
  if printf '%s' "$out" | grep -q "could not read BAND_FLOOR"; then
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
  if printf '%s' "$out" | grep -q "extracted ZERO check anchors"; then
    ok "a renamed catalog extractor FAILS I45 loudly (an empty catalog never reads as a conforming one)"
  else
    bad "I45 reported clean with defined_anchors() renamed — it was scanning nothing and calling it agreement"
  fi
fi
restore

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
  if printf '%s' "$out" | grep -q "the check-heading grammar has forked"; then
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
  if printf '%s' "$out" | grep -q "could not find a CHECK_HEAD_RE= assignment"; then
    ok "a renamed CHECK_HEAD_RE FAILS I47 loudly (a join that cannot locate a side never passes by comparing nothing)"
  else
    bad "I47 reported clean with the assignment renamed — it was comparing nothing and calling it agreement"
  fi
fi
restore

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
  if printf '%s' "$out" | grep -q "mode(s) the script does not dispatch"; then
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
  if printf '%s' "$out" | grep -q "its own usage() never names"; then
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
  if printf '%s' "$out" | grep -q "parsed ZERO modes"; then
    ok "a renamed dispatch sentinel FAILS I49 loudly (an empty set is a subset of everything, so the join must refuse rather than agree)"
  else
    bad "the dispatch extraction found nothing and I49 did not say so — it was comparing against an empty set and calling it agreement"
  fi
fi
restore

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
  if printf '%s' "$out" | grep -q "$ghost_a"; then
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
  if printf '%s' "$out" | grep -q "$ghost_b"; then
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
if printf '%s' "$out" | grep -q "I50 derived an EMPTY set"; then
  ok "an empty shipped-validator set FAILS I50 loudly (an empty set contains nothing, so every citation would be a ghost and the join must refuse)"
else
  bad "the shipped-validator set was empty and I50 did not say so — it was comparing citations against nothing"
fi
# The mv back above is the restore: this arm moved a directory and moved it home again.

echo
if [ "$fails" -eq 0 ]; then echo "enforcement-map-sites: PASS"; exit 0; fi
echo "enforcement-map-sites: $fails assertion(s) FAILED" >&2
exit 1
