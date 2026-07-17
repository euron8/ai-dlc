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

echo
if [ "$fails" -eq 0 ]; then echo "enforcement-map-sites: PASS"; exit 0; fi
echo "enforcement-map-sites: $fails assertion(s) FAILED" >&2
exit 1
