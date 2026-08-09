#!/usr/bin/env bash
# enforcement-map-derivations — assert the derivations validate-enforcement-map.sh runs
# in a LOOP still fire.
#
# Usage: run.sh [--run-one <assertion>]
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
#
# ONE TREE PER ASSERTION, IN ONE PROCESS PER ASSERTION, AND THE REASON IS WALL CLOCK.
# Same shape and the same argument as the sibling `enforcement-map-sites`, arrived at from
# the other end: that fixture was the suite's critical path until it grew an inner pool,
# and this one then became it. Every assertion below runs
# `validate-enforcement-map.sh` over a freshly copied tree, that validator is ~8.5s a call
# with no hot spot inside it (measured by cut-bisect: 3.66s at 30% of the file rising
# monotonically to 8.73s, i.e. ~76 invariants each scanning the tree, not one slow one),
# and there are ~16 of those calls here. The pre-push pool parallelizes ACROSS fixtures and
# every one of those calls was running SEQUENTIALLY inside a single pool slot, which is why
# the suite makespan sat at this file's duration and no `AI_DLC_FIXTURE_JOBS` value moved
# it: a pool's makespan is bounded below by its longest single unit.
#
# Nothing about that is a property of the assertions. Each one already re-copied a pristine
# tree and shared no state with any other, so they were independent before this driver
# existed; the serial `t="$(fresh)"` sequence was just the cheapest way to write them down.
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

fails=0
broken=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

SKILL_REL="core/skills/ai-dlc/SKILL.md"

# seed_tree — build this process's own pristine tree and scratch dir. Called by --run-one
# only, so a worker owns everything it touches and no two workers share a path.
seed_tree() {
  PRISTINE="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
  WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
}

# A fresh COPY of the pristine seed, never an edit of it. A mutation applied in place
# leaks into every later assertion, and the one that leaks reads as the one that fired.
# It stays a copy even now that each assertion has its own process: the arms of a single
# assertion still need a clean tree between them, and a `fresh()` that handed back the
# pristine root itself would put that back the way it was.
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
# its own and every "it fired as expected" below is a false pass. It exits 2 rather than 1
# because "nothing was tested" and "a check regressed" are different answers, and the
# driver runs this one first and alone so that a failure here stops the run instead of
# reporting fourteen unattributable kills.
A00_control() {
  t="$(fresh)"
  if bash "$t/scripts/validate-enforcement-map.sh" >/dev/null 2>&1; then
    ok "unmutated seed passes (the assertions below mean something)"
  else
    bad "FIXTURE BROKEN — the unmutated seed does not pass validate-enforcement-map.sh. Every assertion below would be a false pass."
    exit 2
  fi
}

# --- Assertion 1: I3 — the GATE_MANIFEST row loop -----------------------------
# I3 walks every manifest row and every comma-separated id inside it. A row naming a check
# the map has no entry for must be reported; if the per-id walk stops reaching the ids, a
# manifest requiring a check that does not exist gates nothing and says PASS.
A01_i3_manifest_row_loop() {
  t="$(fresh)"
  if edit "$t/core/skills/ai-dlc/steps/gate-validation.md" \
       '!done && /^\| universal +\| / { sub(/^\| universal +\| /, "&zz9, "); done=1 } { print }'; then
    assert_fires "I3  a GATE_MANIFEST row naming a check the map does not define is REPORTED" \
                 "GATE_MANIFEST names check zz9"
  fi
}

# --- Assertion 2: I9/W1 — the per-entry call_sites walk -----------------------
# W1 is the invariant that exists because validate-steering-budget.sh guarded eleven live
# violations from zero gates. Strip every call_sites block and each script-adjudicated
# entry must be named.
A02_i9_w1_call_sites_walk() {
  t="$(fresh)"
  if edit "$t/core/skills/ai-dlc/enforcement-map.yaml" \
       '/^    call_sites:/ { skip=1; next }
        skip && (/^    [a-z_]+:/ || /^  - id:/ || /^[a-z]/) { skip=0 }
        skip { next }
        { print }'; then
    assert_fires "I9  a script-adjudicated entry with NO call_sites is REPORTED (W1)" \
                 "is adjudication:script but declares NO call_sites"
  fi
}

# --- Assertion 3: I9/W2 — the per-(enforcer, site) resolution -----------------
# W2 resolves each declared site to a file and requires that file to name the enforcer.
# Repoint every site at a step file that has never heard of them.
A03_i9_w2_site_resolution() {
  t="$(fresh)"
  if edit "$t/core/skills/ai-dlc/enforcement-map.yaml" \
       '/^      - site: / { sub(/gate-validation\.md/, "retro.md") } { print }'; then
    assert_fires "I9  a call site whose file never names the enforcer is REPORTED (W2)" \
                 "The site is fictional"
  fi
}

# --- Assertion 4: I10 — the per-fixture hermeticity walk ----------------------
# The token is ASSEMBLED, not written. I10's own subject set is core/fixtures/*/run.sh --
# this file -- so spelling the hook path here in one piece makes I10 fire on the fixture
# that tests it, on the real tree, every push.
A04_i10_fixture_hermeticity() {
  t="$(fresh)"
  local hookish
  hookish="hooks/""ai-dlc-core-guard.sh"
  mkdir -p "$t/core/fixtures/zz-hookless"
  { printf '#!/usr/bin/env bash\n'
    printf '# drives %s and scrubs no ambient AI_DLC_* env\n' "$hookish"
    printf 'exit 0\n'; } > "$t/core/fixtures/zz-hookless/run.sh"
  assert_fires "I10 a hook-driving fixture that never scrubs AI_DLC_* is REPORTED" \
               "fixture 'zz-hookless' invokes a hook but never scrubs"
}

# --- Assertion 5: I22 — the per-role config resolution ------------------------
# I22 exists because the dispatch guard FAILS OPEN on an unresolvable model: the role runs
# on whatever it inherits and nothing says so at runtime. Point the first role at a key
# aiDlcModels does not define.
A05_i22_role_config_resolution() {
  t="$(fresh)"
  if edit "$t/templates/settings.json.template" \
       '/"aiDlcRoles"/ { inr=1 }
        inr && !done && /"model"[[:space:]]*:/ { sub(/:[[:space:]]*"[^"]*"/, ": \"no-such-model-key\""); done=1 }
        { print }'; then
    assert_fires "I22 a role naming a model key aiDlcModels does not define is REPORTED" \
                 "but aiDlcModels does not define it"
  fi
}

# --- Assertion 6: I23 — the per-rule-prose-file corpus join -------------------
# Both sides of I23 are derived: the shipped set from install.sh's copy paths, the corpus
# from `audit-rule-files.sh --list`. Drop the team-roles class from what --list returns --
# the BUILDER is untouched, so those files stay shipped and stop being scanned, which is
# precisely I23's subject.
A06_i23_rule_prose_corpus_join() {
  t="$(fresh)"
  if edit "$t/core/scripts/audit-rule-files.sh" \
       '/^if MODE == "--list":/ && !done { print "corpus = [p for p in corpus if not p.startswith(\"core/team-roles/\")]"; done=1 }
        { print }'; then
    assert_fires "I23 an installed rule-prose file absent from the audit corpus is REPORTED" \
                 "is absent from the audit-rule-files.sh corpus"
  fi
}

# --- Assertion 7: the per-seed root-resolution depth --------------------------
# A seed that resolves its root two dirs up lands at `tests/` in a consumer and every seed
# there dies -- correct in the distribution, broken on every consumer, which is why this
# has to be asserted here rather than noticed there.
A07_seed_root_resolution_depth() {
  t="$(fresh)"
  local victim
  victim="$(grep -lE '[DC]_ROOT="\$\(cd "\$HERE/\.\./\.\./\.\.' "$t"/core/fixtures/*/seed.sh 2>/dev/null | head -1)"
  if [ -z "$victim" ]; then
    bad "FIXTURE BROKEN — no seed in the tree resolves its root with \$HERE/../../.., so there is nothing to shorten and this assertion tests nothing."
  elif edit "$victim" \
         '/[DC]_ROOT="\$\(cd "\$HERE\// { sub(/\.\.\/\.\.\/\.\./, "../..") } { print }'; then
    assert_fires "root-depth: a seed resolving the repo root two dirs up is REPORTED" \
                 "must be '\$HERE/../../..'"
  fi
}

# --- I79: the carrier declaration on every rule below the re-attach cut ---------
# The rule this whole invariant exists for: a rule survives a compaction only if
# something other than the lead's memory carries it. Rule 19 held at 89% across the
# boundary because a dispatch template carries it; Rule 23 collapsed 13x with nothing
# but its own prose.

# THE ASSERTION THAT MATTERS MOST. The band must be DERIVED from the re-attach budget,
# never hardcoded: a band written as "14-30" silently stops matching the moment a rule is
# inserted, and it would keep printing this same clean line. Halving the window must move
# the reported band size. If this stops firing, every assertion below is scoped to a
# subject set the invariant chose rather than measured.
A08_i79_band_is_derived() {
  t="$(fresh)"
  local base_n moved_n
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
}

# A band rule that declares no carrier at all.
A09_i79_rule_with_no_carrier() {
  t="$(fresh)"
  if edit "$t/$SKILL_REL" \
        '/^\*\*Carrier:\*\* `scripts\/ai-dlc\/validate-spawn-ledger\.sh`$/ { next } { print }'; then
    assert_fires "I79: a band rule with NO **Carrier:** declaration is REPORTED" \
                 "declares no '**Carrier:**'"
  fi
}

# A carrier that names a path which does not exist. An unresolvable carrier carries
# nothing, and the declaration would otherwise keep reading like coverage.
A10_i79_carrier_path_absent() {
  t="$(fresh)"
  if edit "$t/$SKILL_REL" \
        '/^\*\*Carrier:\*\* `scripts\/ai-dlc\/validate-spawn-ledger\.sh`$/ { print "**Carrier:** `scripts/ai-dlc/validate-nothing-at-all.sh`"; next } { print }'; then
    assert_fires "I79: a carrier naming a path that does not exist is REPORTED" \
                 "does not exist in the tree"
  fi
}

# `none` with no reason. A declared exemption with no argument is the defect this repo
# keeps finding, so "none" may not be the cheap way out.
A11_i79_carrier_none_with_no_reason() {
  t="$(fresh)"
  if edit "$t/$SKILL_REL" \
        '/^\*\*Carrier:\*\* none -- write shape is invisible/ { print "**Carrier:** none"; next } { print }'; then
    assert_fires "I79: 'carrier: none' with no reason is REPORTED" \
                 "with no reason"
  fi
}

# RULE NUMBERS AND CHECK NUMBERS ARE UNRELATED NAMESPACES. Check 22 is "Teammate-spawn
# role binding", which is RULE 19's subject; Check 23 is "Analyst-draft sprint stamps
# (Rule 24)". A carrier naming a check must be one the MAP lists, and this proves the
# invariant looks it up rather than assuming Rule N is carried by Check N.
A12_i79_carrier_names_absent_check() {
  t="$(fresh)"
  if edit "$t/$SKILL_REL" \
        '/^\*\*Carrier:\*\* `scripts\/ai-dlc\/validate-spawn-ledger\.sh`$/ { print "**Carrier:** `Check 9999`"; next } { print }'; then
    assert_fires "I79: a carrier naming a check id absent from the map is REPORTED" \
                 "is not an id in enforcement-map.yaml"
  fi
}

# A carrier that is neither a mappable consumer path nor a check id. SKILL.md is a RUNTIME
# file, so a `core/...` path is a dead link for every consumer reading it.
A13_i79_carrier_maps_to_no_layout() {
  t="$(fresh)"
  if edit "$t/$SKILL_REL" \
        '/^\*\*Carrier:\*\* `scripts\/ai-dlc\/validate-spawn-ledger\.sh`$/ { print "**Carrier:** `somewhere in the codebase`"; next } { print }'; then
    assert_fires "I79: a carrier that maps to no layout is REPORTED" \
                 "neither a consumer path this invariant can map"
  fi
}

# The gap count is REPORTED rather than silently tolerated — a bound the invariant accepts
# must be visible, or an accepted gap reads as full coverage.
A14_i79_gap_count_is_reported() {
  t="$(fresh)"
  local out
  out="$(bash "$t/scripts/validate-enforcement-map.sh" 2>&1)"
  case "$out" in
    *"declared carrier gap(s)."*) ok "I79: the declared-gap count is reported, not silently accepted" ;;
    *) bad "I79: no gap count in the output — an accepted gap reads exactly like full coverage" ;;
  esac
}

# --- I84: the story corpus location is ONE declaration ------------------------
# Four arms, because the invariant has four ways to stop meaning anything and three of them
# are SILENT. The literal it bans had four copies in the tree before it existed.

# A restatement in a shipped program is REPORTED. The mutation is the exact regression: the
# protect hook's component-keyed pattern put back the way it was, which is the copy that
# would have gone inert — a protected-path pattern matching nothing ALLOWS.
A15_i84_restatement_is_reported() {
  t="$(fresh)"
  # THE PATH IS ASSEMBLED, NOT SPELLED, and spelling it is what this fixture's own control
  # caught: I10 scores a fixture that NAMES a hook as one that DRIVES a hook, and this file
  # deliberately sits outside that set (see A04's `hookish`) because the scrub loop I10 wants
  # has an ordering hazard against values the worker wrapper has already resolved. Mutating a
  # file that happens to live under core/hooks/ is not driving a hook.
  local protect
  protect="$t/core/hooks/""ai-dlc-protect.sh"
  if edit "$protect" \
       '!done && /^  "\*\/stories\/\*\.md"$/ { print "  \"_bmad-output/planning-artifacts/stories/*.md\""; done=1; next } { print }'; then
    assert_fires "I84 a shipped program restating an area-qualified story path is REPORTED" \
                 "restate an area-qualified story corpus path"
  fi
}

# The TEMPLATE losing its sprint slot is REPORTED. This is the silent one: every sprint then
# resolves to the same directory, which is the flat cross-sprint corpus rule 2 exists to end,
# and it resolves to a directory that EXISTS — so every reader reports a full corpus and none
# of them is looking at this sprint.
A16_i84_template_without_slot() {
  t="$(fresh)"
  if edit "$t/core/schemas/sprint-status.json" \
       '!done && /"stories_dir":/ { sub(/s\{sprint\}\//, ""); done=1 } { print }'; then
    assert_fires "I84 a stories_dir template with no sprint slot is REPORTED" \
                 "does not contain its own sprint slot"
  fi
}

# A reader that takes the template and never substitutes is REPORTED. It composes a path
# containing a literal `{sprint}`, which exists nowhere, so it finds an empty corpus — and an
# empty corpus is what a clean one looks like.
A17_i84_reader_never_substitutes() {
  t="$(fresh)"
  if edit "$t/core/scripts/validate-mandatory-rules.sh" \
       '/stories_dir_sprint_placeholder/ { next } { print }'; then
    assert_fires "I84 a reader of stories_dir that never names the slot is REPORTED" \
                 "never name its sprint slot"
  fi
}

# The declaration going missing from its home is REPORTED, rather than leaving every reader
# resolving an empty template — which composes the repo root, not nothing.
A18_i84_declaration_missing() {
  t="$(fresh)"
  if edit "$t/core/schemas/sprint-status.json" \
       '/"stories_dir":/ { next } { print }'; then
    assert_fires "I84 stories_dir absent from its declared home is REPORTED" \
                 "Both are required"
  fi
}

# ---------------------------------------------------------------------------
# THE DRIVER
# ---------------------------------------------------------------------------
# --- Assertion 19: I74(b) — install.sh must still DERIVE the ship set ---------
# install.sh's fixture loop was a hand-written list of 120 names until it became a
# derivation over `core/fixtures/*/` minus `.dist-only`. The invariant that used to join
# that list against the tree could not survive the change — joining a derivation to itself
# passes for a reason unrelated to anything being right — so what replaced it is an
# assertion that the derivation is THERE. Break the tree read.
A19_i74_install_derives() {
  t="$(fresh)"
  if edit "$t/scripts/install.sh" \
       '{ gsub(/core\/fixtures\/"\*\//, "core/schemas/\"*/") } { print }'; then
    assert_fires "I74 install.sh no longer deriving the ship set from core/fixtures/ is REPORTED" \
                 "does not read core/fixtures/"
  fi
}

# --- Assertion 20: I74(b) — and must still EXCLUDE the marker -----------------
# The other half, and the one that fails in the shipping direction: a derivation that
# reads the right directory but drops the `.dist-only` guard copies every
# distribution-only fixture into the consumer's suite schedule. That is v0.230.0's defect,
# where a distribution-only battery became the reference consumer's pole, and no join can
# see it because every join resolves the same marker this loop stopped resolving.
A20_i74_install_excludes_marker() {
  t="$(fresh)"
  if edit "$t/scripts/install.sh" \
       '{ sub(/\[ -f "\$_fd\.dist-only" \] && continue/, "") } { print }'; then
    assert_fires "I74 an install derivation that stops excluding .dist-only is REPORTED" \
                 "does not exclude"
  fi
}

# --- Assertion 21: I74(d) — a `.dist-only` marker with no reason --------------
# The marker excludes a fixture from every consumer. Empty, it says nothing about why, and
# the next author cannot tell a considered exclusion from one copied by pattern-match.
# Seven of the twelve were zero bytes when this arm was written. Truncation is the
# mutation, so `edit` is not the helper — it rewrites through awk and an empty result is
# what we want.
A21_i74_marker_with_no_reason() {
  t="$(fresh)"
  local m="$t/core/fixtures/plan-shape/.dist-only"
  if [ ! -s "$m" ]; then
    bad "FIXTURE BROKEN — plan-shape/.dist-only is already empty in the seed, so truncating it is not a mutation and the assertion below would test an unchanged tree."
    return 1
  fi
  : > "$m"
  assert_fires "I74 a .dist-only marker with an EMPTY body is REPORTED" \
               "EMPTY body"
}

# --- Assertion 22: I8 — uninstall.sh's list vs the derived ship set -----------
# uninstall.sh keeps a hand-written list on purpose: it runs on a consumer where
# core/fixtures/ does not exist, and it bounds a DESTRUCTIVE loop that must not glob the
# consumer's own tests/fixtures/. That is why it is the side I8 joins now that install.sh
# derives. Drop one name and the fixture is orphaned in every consumer's tree forever.
A22_i8_uninstall_orphan() {
  t="$(fresh)"
  if edit "$t/scripts/uninstall.sh" \
       '{ sub(/ check-23-draft-stamps /, " ") } { print }'; then
    assert_fires "I8  a fixture install ships that uninstall.sh does not name is REPORTED" \
                 "uninstall.sh never names"
  fi
}

# --- Assertion 23: I85 — a backtick that runs the operator's own answer -------
# Backticks inside a double-quoted string are command substitution: the shell runs the
# quoted word and substitutes its empty output, so the word DISAPPEARS from the message
# and the sentence still reads like a sentence. Measured live as PC-S320 — four sites in
# reconcile/layer-drift.sh, every one wrapping `still-additive`, which is the VERDICT an
# operator must record to clear a BLOCKING adjudication row. The row told them a verdict
# clears the block and deleted which verdict.
A23_i85_backtick_in_message() {
  t="$(fresh)"
  if edit "$t/core/skills/ai-dlc-update/reconcile/layer-drift.sh" \
       '{ gsub(/\\`still-additive\\`/, "`still-additive`") } { print }'; then
    assert_fires "I85 an unescaped backtick inside an operator-facing message is REPORTED" \
                 "command-substitute inside an operator-facing message"
  fi
}

# --- Assertion 24: I85 — the scanner must FAIL CLOSED when blinded -----------
# THE ASSERTION THAT MATTERS MOST HERE. A23 proves the scanner sees the defect; this
# proves that a scanner which has stopped seeing it says so instead of reporting clean.
# Break the character it matches on: the invariant's own positive probe must catch that
# in the same run, because "no findings" and "an instrument that cannot find anything"
# are the same output otherwise.
A24_i85_fails_closed_when_blind() {
  t="$(fresh)"
  if edit "$t/scripts/validate-enforcement-map.sh" \
       '{ sub(/if \(c == "`" && p != "\\\\"\) \{/, "if (c == \"~\" \&\& p != \"\\\\\\\\\") {") } { print }'; then
    assert_fires "I85 a BLINDED scanner reports its own probe rather than a clean tree" \
                 "positive probe was NOT reported"
  fi
}

# --- Assertion 25: I85 — the heredoc narrowing is load-bearing ---------------
# The crude form of this scan flags SEVEN files; six are Python inside `<<'PY'` quoted
# heredocs, where the shell expands nothing and a backtick is literal. Drop the heredoc
# tracking and those six correct files enter the finding set — which is how a lint gets
# turned off. The negative probe is what refuses that, so break the skip and require it.
A25_i85_heredoc_narrowing_holds() {
  t="$(fresh)"
  if edit "$t/scripts/validate-enforcement-map.sh" \
       '{ sub(/hd != "" \{ if \(\$0 == hd\) \{ hd = ""; hdq = 0 \} ; next \}/, "hd != \"\" { if ($0 == hd) { hd = \"\" } }") } { print }'; then
    assert_fires "I85 losing the quoted-heredoc narrowing is REPORTED by its own negative probe" \
                 "negative probe WAS reported"
  fi
}

# --- Assertion 26: I33b — the two-step walk across the install split ---------
# I33 catches `$(dirname "$X")/../<subtree>/` in ONE expression. The defect does not need
# one: whole-read-pool shipped the dirname into a variable and walked up off that on the
# next line, and I33's own pattern returns ZERO on it. The parent holds in core/ and is
# SPLIT by install.sh on every consumer, so the fixture was green here and exited 2 there —
# a permanent stop on the consumer's pre-push, which is how it was found (PC-S326).
A26_i33b_two_step_walk() {
  t="$(fresh)"
  if edit "$t/core/fixtures/whole-read-pool/run.sh" \
       '{ sub(/^  SPRINT_SCHEMA="\$ROOT\/core\/schemas\/sprint-status\.json"$/, "  SPRINT_SCHEMA=\"$SCRIPTS_DIR/../schemas/sprint-status.json\"") } { print }'; then
    assert_fires "I33b a dirname VARIABLE walked up into a sibling subtree is REPORTED" \
                 "walking up from a dirname VARIABLE"
  fi
}

# --- Assertion 27: I33b — one predicate, and it fails closed when blinded ----
# THE ASSERTION THAT MATTERS MOST HERE. An earlier draft inlined the detection twice, so
# blinding the corpus scan left the probe passing against its own private copy — a probe
# certifying an instrument it never exercised. Scan and probe now call ONE function, so
# breaking it must surface as the probe failing, not as a clean tree.
A27_i33b_fails_closed_when_blind() {
  t="$(fresh)"
  if edit "$t/scripts/validate-enforcement-map.sh" \
       '{ if ($0 ~ /grep -qE .*_v.*_f. 2>\/dev\/null && printf/ && !done) { sub(/grep -qE "[^"]*"/, "grep -qE \"ZZNOMATCHZZ\""); done=1 } } { print }'; then
    assert_fires "I33b a BLINDED predicate reports its own probe rather than a clean tree" \
                 "positive probe was NOT reported"
  fi
}

# --- Assertion 28: I86 — apply.sh must not restate the row token ------------
# layer-drift.sh declares ADJ_ROW_TOKEN and writes it into an OVERRIDE-SUPERSEDED row when a
# verdict is already recorded for that digest; apply.sh resolves that declaration and skips
# prescribing the retire sequence. A restated literal drifts silently — the case arm stops
# matching and a pull carrying an adjudicated row reads exactly like one carrying none.
A28_i86_apply_restates_token() {
  t="$(fresh)"
  if edit "$t/core/skills/ai-dlc-update/reconcile/apply.sh" \
       '{ if (!done && index($0, "ADJ_ROW_TOKEN=\"$(sed")) { print "ADJ_ROW_TOKEN=\"adjudicated\""; done=1; next } } { print }'; then
    assert_fires "I86 apply.sh restating the row token literal is REPORTED" \
                 "restates the adjudication row token literal"
  fi
}

# --- Assertion 29: I86 — the writer must still WRITE the token --------------
# The other direction, and the one that fails silently. A token with a home and no emitter
# leaves apply.sh's suppression unable to fire on any pull, forever — which is this repo's
# recurring class arriving inside the guard against it.
A29_i86_writer_stops_emitting() {
  t="$(fresh)"
  if edit "$t/core/skills/ai-dlc-update/reconcile/layer-drift.sh" \
       '{ gsub(/\$\{ADJ_ROW_TOKEN\}=/, "adjudicatedX=") } { print }'; then
    assert_fires "I86 a declared row token that is never written into a row is REPORTED" \
                 "never writes it into a row"
  fi
}

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
  trap 'rm -rf "$PRISTINE" "$WORK"' EXIT
  "$FN"
  [ "$fails" -eq 0 ] || exit 1
  exit 0
fi

# THE ASSERTION LIST IS DERIVED FROM THIS FILE'S OWN DEFINITIONS, in source order. A
# hand-written list here would be this fixture's own subject defect one level out: an
# assertion dropped from the list runs nothing and prints nothing, and a suite reporting 14
# greens instead of 15 reads exactly like a suite that passed. The zero guard is the same
# argument -- a naming grammar that stops matching yields an empty list, and an empty list
# passes every assertion it never made.
NAMES="$(grep -oE '^A[0-9]{2}_[a-z0-9_]+\(\) \{' "$0" | sed 's/() {$//')"
N_LISTED="$(printf '%s\n' "$NAMES" | grep -c . || true)"
if [ "$N_LISTED" -lt 10 ]; then
  echo "FIXTURE ERROR: derived $N_LISTED assertion(s) from this file — the A<nn>_ naming grammar moved" >&2
  exit 2
fi

echo "enforcement-map-derivations:"

OUT="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$OUT"' EXIT
SELF="$HERE/$(basename "$0")"

# The control, first and alone. Its verdict licenses every assertion after it, so a failure
# here stops the run rather than reporting fourteen unattributable kills.
CTL="$(printf '%s\n' "$NAMES" | head -1)"
bash "$SELF" --run-one "$CTL" > "$OUT/$CTL" 2>"$OUT/$CTL.err"
ctl_rc=$?
cat "$OUT/$CTL"
if [ "$ctl_rc" -ne 0 ]; then
  [ -s "$OUT/$CTL.err" ] && cat "$OUT/$CTL.err" >&2
  echo
  echo "enforcement-map-derivations: 1 assertion(s) FAILED" >&2
  exit 2
fi

# EIGHT, and it is a fixed number rather than a tunable for the reason the sibling states:
# this pool nests inside the pre-push suite's own pool, so a knob here multiplies against a
# knob there and the product is what lands on the machine.
#
# The worker wrapper's two variables are NOT named AI_DLC_*. I10 requires a fixture that
# drives a hook to scrub every ambient AI_DLC_* name, and a scrub is a `unset` loop that
# would have to be ordered ahead of values this wrapper has already resolved -- the sibling
# carries exactly that ordering hazard in a comment. This fixture assembles its one hook
# token rather than spelling it, so it is outside I10's set today; naming these two outside
# the AI_DLC_ namespace means it stays correct if that ever changes.
JOBS=8
printf '%s\n' "$NAMES" | tail -n +2 > "$OUT/list"
EMD_SELF="$SELF" EMD_OUT="$OUT" \
  xargs -P "$JOBS" -I{} bash -c '
    n="$1"
    bash "$EMD_SELF" --run-one "$n" \
      > "$EMD_OUT/$n" 2> "$EMD_OUT/$n.err"
    printf %s $? > "$EMD_OUT/$n.rc"
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
  # regressed` are different answers. Routing an assertion through a worker would otherwise
  # collapse them: the parent sees a nonzero rc, charges one assertion and exits 1 —
  # reporting a regression where the truth is that nothing was tested.
  if [ "$wrc" = "2" ]; then broken=1; fi
  if [ "$wrc" != "0" ]; then
    c="$(grep -c '^  FAIL' "$OUT/$n" || true)"
    [ "$c" -gt 0 ] || { printf '  FAIL  %s exited nonzero without an assertion line — the assertion did not run to a verdict\n' "$n"; c=1; }
    fails=$((fails + c))
  fi
done < "$OUT/list"

echo
if [ "$broken" -ne 0 ]; then
  echo "enforcement-map-derivations: FIXTURE BROKEN — an assertion could not run to a verdict" >&2
  exit 2
fi
if [ "$fails" -eq 0 ]; then
  echo "enforcement-map-derivations: PASS"
  exit 0
fi
echo "enforcement-map-derivations: $fails assertion(s) FAILED" >&2
exit 1
