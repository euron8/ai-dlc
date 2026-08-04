#!/usr/bin/env bash
# enforcement-map-derivations — assert the derivations validate-enforcement-map.sh runs
# in a LOOP still fire.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = a check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH, and why it is a separate fixture from
# enforcement-map-sites. Six of that validator's invariants evaluate a predicate once per
# item over a corpus -- once per manifest row, once per map entry, once per fixture, once
# per role, once per rule-prose file, once per seed. None of the six had an assertion
# anywhere in the tree. They were rewritten in v0.205.0 to read each corpus once instead
# of forking per item, and the only evidence available at the time was a one-off
# differential against the pre-change copy, which does not survive the merge.
#
# That is this repo's named class one layer out: the invariants were live and correct, and
# a rewrite that quietly emptied any one of their subject sets would have produced the
# same green line. So the differential is made permanent here in the shape that outlives
# it -- mutate the tree, require the message.
#
# Each assertion mutates a PRISTINE copy of the seed and asserts a POSITIVE outcome (the
# specific message appears), never the absence of an old one. Assertion 0 is the unmutated
# control: without it a validator erroring for reasons of its own scores every negative
# below as a kill.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
D_ROOT="$(cd "$HERE/../../.." && pwd)"

# Distribution-only, same as the sibling: validate-enforcement-map.sh checks the
# distribution's own two writers against each other and install.sh does not ship it, so in
# a consumer tree there is nothing to test. Say so and stop; do not fake a pass.
if [ ! -f "$D_ROOT/scripts/validate-enforcement-map.sh" ]; then
  echo "enforcement-map-derivations: SKIP — distribution-only (validate-enforcement-map.sh is not shipped to consumers)"
  exit 0
fi

PRISTINE="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$PRISTINE" "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "enforcement-map-derivations:"

# A fresh COPY of the pristine seed, never an edit of it. A mutation applied in place
# leaks into every later assertion, and the one that leaks reads as the one that fired.
fresh() {
  rm -rf "$WORK/t"
  cp -R "$PRISTINE" "$WORK/t"
  printf '%s' "$WORK/t"
}

# edit <file> <awk program> — rewrite a file through awk, then REQUIRE the bytes changed.
# A program that matched nothing leaves a tree that is not a mutant, and the assertion
# built on it would report the check passing on input that never violated it.
edit() {
  local f="$1" prog="$2"
  awk "$prog" "$f" > "$f.mut" || { bad "FIXTURE BROKEN — awk failed on $f"; return 1; }
  if cmp -s "$f" "$f.mut"; then
    bad "FIXTURE BROKEN — the mutation of ${f##*/} changed nothing; the assertion below would test a clean tree"
    rm -f "$f.mut"; return 1
  fi
  mv "$f.mut" "$f"
}

# assert <label> <expected substring> — run the validator in $t and require the message.
assert_fires() {
  local label="$1" want="$2" out
  out="$(bash "$t/scripts/validate-enforcement-map.sh" 2>&1)"
  case "$out" in
    *"$want"*) ok "$label" ;;
    *)         bad "$label — the validator did NOT report it. The predicate no longer reaches this subject, and a corpus it cannot see reads exactly like a corpus with nothing wrong in it." ;;
  esac
}

# --- Assertion 0: CONTROL -----------------------------------------------------
# The unmutated seed must PASS. If it does not, the validator is failing for a reason of
# its own and every "it fired as expected" below is a false pass.
t="$(fresh)"
if bash "$t/scripts/validate-enforcement-map.sh" >/dev/null 2>&1; then
  ok "unmutated seed passes (the assertions below mean something)"
else
  bad "FIXTURE BROKEN — the unmutated seed does not pass validate-enforcement-map.sh. Every assertion below would be a false pass."
  echo; echo "enforcement-map-derivations: $fails assertion(s) FAILED" >&2; exit 2
fi

# --- Assertion 1: I3 — the GATE_MANIFEST row loop -----------------------------
# I3 walks every manifest row and every comma-separated id inside it. A row naming a check
# the map has no entry for must be reported; if the per-id walk stops reaching the ids, a
# manifest requiring a check that does not exist gates nothing and says PASS.
t="$(fresh)"
if edit "$t/core/skills/ai-dlc/steps/gate-validation.md" \
     '!done && /^\| universal +\| / { sub(/^\| universal +\| /, "&zz9, "); done=1 } { print }'; then
  assert_fires "I3  a GATE_MANIFEST row naming a check the map does not define is REPORTED" \
               "GATE_MANIFEST names check zz9"
fi

# --- Assertion 2: I9/W1 — the per-entry call_sites walk -----------------------
# W1 is the invariant that exists because validate-steering-budget.sh guarded eleven live
# violations from zero gates. Strip every call_sites block and each script-adjudicated
# entry must be named.
t="$(fresh)"
if edit "$t/core/skills/ai-dlc/enforcement-map.yaml" \
     '/^    call_sites:/ { skip=1; next }
      skip && (/^    [a-z_]+:/ || /^  - id:/ || /^[a-z]/) { skip=0 }
      skip { next }
      { print }'; then
  assert_fires "I9  a script-adjudicated entry with NO call_sites is REPORTED (W1)" \
               "is adjudication:script but declares NO call_sites"
fi

# --- Assertion 3: I9/W2 — the per-(enforcer, site) resolution -----------------
# W2 resolves each declared site to a file and requires that file to name the enforcer.
# Repoint every site at a step file that has never heard of them.
t="$(fresh)"
if edit "$t/core/skills/ai-dlc/enforcement-map.yaml" \
     '/^      - site: / { sub(/gate-validation\.md/, "retro.md") } { print }'; then
  assert_fires "I9  a call site whose file never names the enforcer is REPORTED (W2)" \
               "The site is fictional"
fi

# --- Assertion 4: I10 — the per-fixture hermeticity walk ----------------------
# The token is ASSEMBLED, not written. I10's own subject set is core/fixtures/*/run.sh --
# this file -- so spelling the hook path here in one piece makes I10 fire on the fixture
# that tests it, on the real tree, every push.
t="$(fresh)"
hookish="hooks/""ai-dlc-core-guard.sh"
mkdir -p "$t/core/fixtures/zz-hookless"
{ printf '#!/usr/bin/env bash\n'
  printf '# drives %s and scrubs no ambient AI_DLC_* env\n' "$hookish"
  printf 'exit 0\n'; } > "$t/core/fixtures/zz-hookless/run.sh"
assert_fires "I10 a hook-driving fixture that never scrubs AI_DLC_* is REPORTED" \
             "fixture 'zz-hookless' invokes a hook but never scrubs"

# --- Assertion 5: I22 — the per-role config resolution ------------------------
# I22 exists because the dispatch guard FAILS OPEN on an unresolvable model: the role runs
# on whatever it inherits and nothing says so at runtime. Point the first role at a key
# aiDlcModels does not define.
t="$(fresh)"
if edit "$t/templates/settings.json.template" \
     '/"aiDlcRoles"/ { inr=1 }
      inr && !done && /"model"[[:space:]]*:/ { sub(/:[[:space:]]*"[^"]*"/, ": \"no-such-model-key\""); done=1 }
      { print }'; then
  assert_fires "I22 a role naming a model key aiDlcModels does not define is REPORTED" \
               "but aiDlcModels does not define it"
fi

# --- Assertion 6: I23 — the per-rule-prose-file corpus join -------------------
# Both sides of I23 are derived: the shipped set from install.sh's copy paths, the corpus
# from `audit-rule-files.sh --list`. Drop the team-roles class from what --list returns --
# the BUILDER is untouched, so those files stay shipped and stop being scanned, which is
# precisely I23's subject.
t="$(fresh)"
if edit "$t/core/scripts/audit-rule-files.sh" \
     '/^if MODE == "--list":/ && !done { print "corpus = [p for p in corpus if not p.startswith(\"core/team-roles/\")]"; done=1 }
      { print }'; then
  assert_fires "I23 an installed rule-prose file absent from the audit corpus is REPORTED" \
               "is absent from the audit-rule-files.sh corpus"
fi

# --- Assertion 7: the per-seed root-resolution depth --------------------------
# A seed that resolves its root two dirs up lands at `tests/` in a consumer and every seed
# there dies -- correct in the distribution, broken on every consumer, which is why this
# has to be asserted here rather than noticed there.
t="$(fresh)"
victim="$(grep -lE '[DC]_ROOT="\$\(cd "\$HERE/\.\./\.\./\.\.' "$t"/core/fixtures/*/seed.sh 2>/dev/null | head -1)"
if [ -z "$victim" ]; then
  bad "FIXTURE BROKEN — no seed in the tree resolves its root with \$HERE/../../.., so there is nothing to shorten and this assertion tests nothing."
elif edit "$victim" \
       '/[DC]_ROOT="\$\(cd "\$HERE\// { sub(/\.\.\/\.\.\/\.\./, "../..") } { print }'; then
  assert_fires "root-depth: a seed resolving the repo root two dirs up is REPORTED" \
               "must be '\$HERE/../../..'"
fi

# --- I79: the carrier declaration on every rule below the re-attach cut ---------
# The rule this whole invariant exists for: a rule survives a compaction only if
# something other than the lead's memory carries it. Rule 19 held at 89% across the
# boundary because a dispatch template carries it; Rule 23 collapsed 13x with nothing
# but its own prose.
SKILL_REL="core/skills/ai-dlc/SKILL.md"

# THE ASSERTION THAT MATTERS MOST. The band must be DERIVED from the re-attach budget,
# never hardcoded: a band written as "14-30" silently stops matching the moment a rule is
# inserted, and it would keep printing this same clean line. Halving the window must move
# the reported band size. If this stops firing, every assertion below is scoped to a
# subject set the invariant chose rather than measured.
t="$(fresh)"
base_n="$(bash "$t/scripts/validate-enforcement-map.sh" 2>&1 | sed -n 's/.*I79: \([0-9]*\) rule(s).*/\1/p')"
if edit "$t/core/scripts/validate-reattach-budget.sh" \
      '/^BUDGET=/ { print "BUDGET=\"${AI_DLC_REATTACH_BUDGET:-2500}\""; next } { print }'; then
  moved_n="$(bash "$t/scripts/validate-enforcement-map.sh" 2>&1 | sed -n 's/.*I79: \([0-9]*\) rule(s).*/\1/p')"
  if [ -n "$base_n" ] && [ -n "$moved_n" ] && [ "$moved_n" -gt "$base_n" ]; then
    ok "I79: halving the re-attach window GROWS the band ($base_n -> $moved_n) — it is derived, not hardcoded"
  else
    bad "I79: the band did not move when the window changed (base='$base_n' moved='$moved_n') — it is hardcoded, and a rule inserted into the band would never be scanned"
  fi
fi

# A band rule that declares no carrier at all.
t="$(fresh)"
if edit "$t/$SKILL_REL" \
      '/^\*\*Carrier:\*\* `scripts\/ai-dlc\/validate-spawn-ledger\.sh`$/ { next } { print }'; then
  assert_fires "I79: a band rule with NO **Carrier:** declaration is REPORTED" \
               "declares no '**Carrier:**'"
fi

# A carrier that names a path which does not exist. An unresolvable carrier carries
# nothing, and the declaration would otherwise keep reading like coverage.
t="$(fresh)"
if edit "$t/$SKILL_REL" \
      '/^\*\*Carrier:\*\* `scripts\/ai-dlc\/validate-spawn-ledger\.sh`$/ { print "**Carrier:** `scripts/ai-dlc/validate-nothing-at-all.sh`"; next } { print }'; then
  assert_fires "I79: a carrier naming a path that does not exist is REPORTED" \
               "does not exist in the tree"
fi

# `none` with no reason. A declared exemption with no argument is the defect this repo
# keeps finding, so "none" may not be the cheap way out.
t="$(fresh)"
if edit "$t/$SKILL_REL" \
      '/^\*\*Carrier:\*\* none -- write shape is invisible/ { print "**Carrier:** none"; next } { print }'; then
  assert_fires "I79: 'carrier: none' with no reason is REPORTED" \
               "with no reason"
fi

# RULE NUMBERS AND CHECK NUMBERS ARE UNRELATED NAMESPACES. Check 22 is "Teammate-spawn
# role binding", which is RULE 19's subject; Check 23 is "Analyst-draft sprint stamps
# (Rule 24)". A carrier naming a check must be one the MAP lists, and this proves the
# invariant looks it up rather than assuming Rule N is carried by Check N.
t="$(fresh)"
if edit "$t/$SKILL_REL" \
      '/^\*\*Carrier:\*\* `scripts\/ai-dlc\/validate-spawn-ledger\.sh`$/ { print "**Carrier:** `Check 9999`"; next } { print }'; then
  assert_fires "I79: a carrier naming a check id absent from the map is REPORTED" \
               "is not an id in enforcement-map.yaml"
fi

# A carrier that is neither a mappable consumer path nor a check id. SKILL.md is a RUNTIME
# file, so a `core/...` path is a dead link for every consumer reading it.
t="$(fresh)"
if edit "$t/$SKILL_REL" \
      '/^\*\*Carrier:\*\* `scripts\/ai-dlc\/validate-spawn-ledger\.sh`$/ { print "**Carrier:** `somewhere in the codebase`"; next } { print }'; then
  assert_fires "I79: a carrier that maps to no layout is REPORTED" \
               "neither a consumer path this invariant can map"
fi

# The gap count is REPORTED rather than silently tolerated — a bound the invariant accepts
# must be visible, or an accepted gap reads as full coverage.
t="$(fresh)"
out="$(bash "$t/scripts/validate-enforcement-map.sh" 2>&1)"
case "$out" in
  *"declared carrier gap(s)."*) ok "I79: the declared-gap count is reported, not silently accepted" ;;
  *) bad "I79: no gap count in the output — an accepted gap reads exactly like full coverage" ;;
esac

echo
if [ "$fails" -eq 0 ]; then
  echo "enforcement-map-derivations: PASS"
  exit 0
fi
echo "enforcement-map-derivations: $fails assertion(s) FAILED" >&2
exit 1
