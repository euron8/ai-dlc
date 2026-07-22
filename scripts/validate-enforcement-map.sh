#!/usr/bin/env bash
#
# validate-enforcement-map.sh
#
# Distribution-only integrity check for core/skills/ai-dlc/enforcement-map.yaml
# — the derived machine index of the gate-validation check catalog and its
# enforcement bindings. Runs upstream (repo-root scripts/, alongside
# audit-machinery-efficacy.js); NOT shipped to consumers via install.sh.
#
# The enforcement-map has no independent authority: it is only ever a VALIDATED
# view of steps/gate-validation.md. This script is what keeps it honest. It
# asserts:
#
#   I1  catalog ⊆ map   — every real CHECK_LOADED anchor in gate-validation.md
#                         has an entry under `checks:` in the map.
#   I2  map ⊆ catalog   — every `checks:` entry corresponds to a real anchor
#                         (catches a stale entry left after a check is removed).
#   I3  gate-type sync  — for every (gate_type, check) pair in the GATE_MANIFEST
#                         block, the map entry's gate_types list contains that
#                         type (the id/gate_type columns cannot drift from the
#                         authoritative manifest).
#   I4  no dormant binding — every enforcer/ci_workflow path the map references
#                         exists on disk; every named fixture exists under
#                         core/fixtures/. (This is the check the v0.27.0
#                         machinery-efficacy audit found missing.)
#   I5  core_manifest sync — core-manifest.md and reconcile/setup-sites.md list
#                         the same logical core file set (prefix-normalized).
#                         Both files flag this hand-synced duplication as a
#                         hazard; this asserts they never silently diverge.
#   I6  heading ⇔ anchor — every check heading is `### <id>.` (never
#                         `### Check <id>.`) and its id set equals the anchor set.
#                         Nothing tied the two together, so v0.48.0's
#                         `### Check 24.` passed I1-I5 while going invisible to
#                         every anchor extractor in the distribution and in the
#                         consumer-shipped layer linter at once.
#   I7  fixture ⇔ manifest — check-manifest-bypass/seed.sh seeds exactly the
#                         universal core + PLANNING row and none of the
#                         IMPLEMENTATION row. Its anchor list is hand-maintained and
#                         had already rotted (the manifest gained check 24, the
#                         fixture did not), so H1's self-test was seeding a slice
#                         that no longer existed.
#   I20 fixture ⇒ driver — every fixture under core/fixtures/ has a run.sh, or a
#                         README declaring why one is impossible. pre-push skips a
#                         driverless fixture silently, so it reads exactly like one
#                         that passed; two adversarial fixtures sat in that hole for
#                         their whole existence. Exemptions are derived from the
#                         READMEs, never hand-listed here.
#   I21 reconcile helpers single-homed — no reconcile/*.sh redefines a helper that
#                         reconcile/lib.sh already owns, and none calls one without
#                         sourcing lib.sh. `section_of()` shipped divergent twice
#                         (v0.52.0, v0.54.2); v0.90.0 collapsed the three copies but
#                         nothing stopped a fourth. The helper set is derived from
#                         lib.sh, never hand-listed.
#   I9  enforcer ⇒ call site — every `adjudication: script` entry declares
#                         `call_sites:` with a posture (W1), and no declared site
#                         is fictional — the file it names must at least know the
#                         enforcer exists (W2). W2 canNOT tell an invocation from a
#                         prose mention; see its inline note. The teeth are W1 plus
#                         the reviewable `posture:`. The map recorded WHO enforces each
#                         rule (38/38) and WHERE it runs (1/38), so "Enforced by
#                         validate-X.sh" was a claim nothing could falsify. That
#                         is how validate-steering-budget.sh came to sit on 11
#                         real starvation violations while invoked from zero
#                         gates, and why implementation.md could say it "fails
#                         the gate" when it ran at no gate at all.
#   I8  fixture packaging — core/fixtures/, install.sh's fixture loop, and
#                         uninstall.sh's fixture loop name the same set. All three
#                         are hardcoded and had drifted (9 on disk, 9 installed, 5
#                         uninstalled). A fixture missing from install.sh reaches no
#                         consumer at all — an adversarial self-test that silently
#                         does not exist, while the catalog claims coverage. Dist-only
#                         fixtures are DERIVED from a `.dist-only` marker beside the
#                         fixture, not a hand-maintained exemption string.
#   I10 fixture hermeticity — a fixture that drives a hook must scrub ambient AI_DLC_*
#                         first, or a consumer's sanctioned tunable makes it fail against
#                         a hook behaving correctly, and the pre-push gate blocks every push.
#   I11 convergence-cycle scope — the three sets that must be one set (steps that dispatch
#                         an adversarial REVIEW, steps that reference the REPAIR dispatch,
#                         and Check 24's Scope sentence) are DERIVED and asserted equal. A
#                         step in the first but not the third runs a convergence loop no
#                         gate reads — which reads exactly like a loop that converged. The
#                         list was hand-maintained and rotted twice (v0.58.0 caught two of
#                         three; carry-over-evaluation was the third).
#   I12 drift-scan coverage bound — reconcile/unregistered-drift.sh's hand-listed scan set is
#                         bound to a reviewed per-subtree policy: every core/skills/<skill>/ and
#                         core/<dir>/ is classified scan|exempt:<reason>, and the scan-marked set
#                         must EQUAL the tool's ls-tree. The list rotted twice (ai-dlc-setup/ in
#                         v0.63.0, schemas/ this release) — a new core dir escaping the scan reads
#                         exactly like a dir with no drift. Now a new subtree fails the build until
#                         it is classified.
#
# Tool dependencies: bash ≥3.2, grep, sed, awk, sort, comm. No hard dep on
# jq/yq/rg — the map is authored line-oriented so the portable subset parses it
# (same posture as validate-ci-gates.sh).
#
# Exit codes:
#   0 — all invariants hold
#   1 — one or more invariants violated (drift / dormant binding)
#   2 — tool-availability or missing-input failure

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GV="$REPO_ROOT/core/skills/ai-dlc/steps/gate-validation.md"
MAP="$REPO_ROOT/core/skills/ai-dlc/enforcement-map.yaml"
CORE_MANIFEST="$REPO_ROOT/core/skills/ai-dlc/core-manifest.md"
SETUP_SITES="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/setup-sites.md"

for f in "$GV" "$MAP" "$CORE_MANIFEST" "$SETUP_SITES"; do
  if [ ! -f "$f" ]; then
    echo "tool-fail: required input not found: $f" >&2
    exit 2
  fi
done

fail=0
err() { echo "FAIL: $*" >&2; fail=1; }

# --- Catalog anchor set -------------------------------------------------------
# Real anchors sit at column 0 directly under a check heading. Inline format
# EXAMPLES in the manifest/H1 prose are mid-line (backtick-prefixed) and carry
# the literal placeholder "<id>" — both are excluded.
anchors="$(grep -oE '^<!-- CHECK_LOADED: [^ ]+ -->' "$GV" \
           | sed -E 's/^<!-- CHECK_LOADED: (.+) -->$/\1/' \
           | grep -vF '<id>' | sort -u)"

# --- Map check-id set (under `checks:` only, not `non_catalog_units:`) ---------
map_ids="$(awk '
  /^checks:/ {inck=1; next}
  /^non_catalog_units:/ {inck=0}
  inck && /^  - id:/ { v=$0; sub(/^  - id:[ ]*/,"",v); gsub(/"/,"",v); print v }
' "$MAP" | sort -u)"

# I1 / I2: set equality between anchors and map ids
missing_in_map="$(comm -23 <(printf '%s\n' "$anchors") <(printf '%s\n' "$map_ids"))"
stale_in_map="$(comm -13 <(printf '%s\n' "$anchors") <(printf '%s\n' "$map_ids"))"
[ -n "$missing_in_map" ] && err "catalog check(s) with no enforcement-map entry: $(echo $missing_in_map)"
[ -n "$stale_in_map" ]   && err "enforcement-map entr(y/ies) with no CHECK_LOADED anchor: $(echo $stale_in_map)"

# --- I6: heading form <-> anchor set ------------------------------------------
# NOTHING tied a check's HEADING to its CHECK_LOADED anchor, so the heading could
# drift from the catalog with CI green. Not hypothetical: v0.48.0 shipped
# `### Check 24.` while every other check is `### 24.`, with a correct
# `<!-- CHECK_LOADED: 24 -->` under it. I1-I5 all passed. But every anchor
# extractor — here, in reconcile/layer-drift.sh, in the consumer-shipped
# validate-layer-entries.sh, and in audit-machinery-efficacy.js — keys on
# `^### <n>.`, so check 24 went invisible to all of them at once. That included
# the one check that would have caught the number collision v0.48.0 itself created,
# and the efficacy auditor, which silently folded check 24's token cost into 23.
# A one-character heading deviation disabled four tools. This is the invariant that
# was missing.
#
# Two word-titled checks (Core-layer immutability, the gate-failure protocol) carry
# anchors but are prose-headed by design. They are NAMED, not pattern-matched, so a
# third one has to be added here deliberately rather than slipping in.
WORD_ANCHORS='core-layer-immutability|failure'

bad_form="$(grep -nE '^#{2,4}[[:space:]]+Check[[:space:]]+[0-9]' "$GV")"
[ -n "$bad_form" ] && err "check heading(s) written '### Check <n>.' — the catalog form is '### <n>.'. Every anchor extractor keys on the latter, so this form hides the check from all of them: $(echo $bad_form)"

head_ids="$(grep -oE '^### ([0-9]+[a-z]?|H[0-9]+)\.' "$GV" | sed -E 's/^### //; s/\.$//' | sort -u)"
anchor_ids="$(printf '%s\n' "$anchors" | grep -vE "^($WORD_ANCHORS)$" | sort -u)"
no_anchor="$(comm -23 <(printf '%s\n' "$head_ids") <(printf '%s\n' "$anchor_ids"))"
no_head="$(comm -13 <(printf '%s\n' "$head_ids") <(printf '%s\n' "$anchor_ids"))"
[ -n "$no_anchor" ] && err "check heading(s) with no CHECK_LOADED anchor: $(echo $no_anchor)"
[ -n "$no_head" ]   && err "CHECK_LOADED anchor(s) with no '### <id>.' heading: $(echo $no_head)"

# --- I3: GATE_MANIFEST (gate_type, check) pairs vs map gate_types -------------
# Per-id gate_types csv from the map.
gt_lookup="$(awk '
  /^checks:/ {inck=1; next}
  /^non_catalog_units:/ {inck=0}
  inck && /^  - id:/ {
    if (id != "") print id"\t"gt;
    id=$0; sub(/^  - id:[ ]*/,"",id); gsub(/"/,"",id); gt=""
  }
  inck && /^    gate_types:/ {
    gt=$0; sub(/^    gate_types:[ ]*\[/,"",gt); sub(/\][ ]*$/,"",gt); gsub(/ /,"",gt)
  }
  END { if (id != "") print id"\t"gt }
' "$MAP")"

# Each manifest row: | <type> | <id, id, ...> |. Skip header + separator rows.
while IFS= read -r row; do
  case "$row" in
    *"Gate type"*|*"---"*) continue ;;
  esac
  gtype="$(printf '%s' "$row" | awk -F'|' '{gsub(/ /,"",$2); print $2}')"
  ids="$(printf '%s' "$row" | awk -F'|' '{print $3}')"
  [ -z "$gtype" ] && continue
  # split ids on comma
  oldIFS="$IFS"; IFS=','
  for cid in $ids; do
    cid="$(printf '%s' "$cid" | tr -d ' ')"
    [ -z "$cid" ] && continue
    entry="$(printf '%s\n' "$gt_lookup" | grep -E "^${cid}"$'\t' || true)"
    if [ -z "$entry" ]; then
      err "GATE_MANIFEST names check $cid ($gtype) but the map has no such entry"
    else
      csv="$(printf '%s' "$entry" | cut -f2)"
      case ",$csv," in
        *",$gtype,"*) : ;;
        *) err "map entry $cid omits gate_type '$gtype' that GATE_MANIFEST requires (has: $csv)" ;;
      esac
    fi
  done
  IFS="$oldIFS"
done <<EOF
$(awk '/<!-- GATE_MANIFEST v1 -->/{f=1;next} /<!-- GATE_MANIFEST_END -->/{f=0} f && /^\|/{print}' "$GV")
EOF

# --- I7: check-manifest-bypass fixture vs the manifest it exists to test -------
# The fixture seeds "universal core + the PLANNING row" and then declares gate type
# `implementation`, so H1 must fail on the implementation row's absent anchors.
# Both halves of that sentence are a hand-maintained anchor list inside seed.sh, and
# the planning half had already rotted: the manifest gained check 24 and the fixture
# did not, so the seed no longer seeded what its own prose claimed. A fixture that
# has drifted from the manifest is not a self-test, it is a decoration. Assert both
# directions against the live manifest instead of trusting the copy.
SEED="$REPO_ROOT/core/fixtures/check-manifest-bypass/seed.sh"
if [ -f "$SEED" ]; then
  manifest_row() { # manifest_row <gate-type> -> ids, one per line
    awk -v want="$1" '
      /<!-- GATE_MANIFEST v1 -->/{f=1;next} /<!-- GATE_MANIFEST_END -->/{f=0}
      f && /^\|/ {
        gt=$0; sub(/^\|[ ]*/,"",gt); sub(/[ ]*\|.*$/,"",gt)
        if (gt != want) next
        n=split($0, c, "|"); ids=c[3]; gsub(/ /,"",ids)
        n=split(ids, a, ","); for (i=1;i<=n;i++) if (a[i] != "") print a[i]
      }' "$GV"
  }
  seed_has() { grep -qF "<!-- CHECK_LOADED: $1 -->" "$SEED"; }

  # The universal half of that sentence was a hand-maintained copy too, and it had
  # rotted the same way every other copy of this set rotted: the seed carried the
  # 14 ids the old gate-validation.md PROSE listed and never gained 2a or 25. The
  # universal core is a manifest row as of v0.73.0, so derive it here like any other.
  for cid in $(manifest_row universal); do
    seed_has "$cid" || err "check-manifest-bypass/seed.sh seeds the UNIVERSAL core but omits check $cid, which the GATE_MANIFEST universal row requires — the fixture claims to seed 'universal core + the planning row' and does not, so H1's self-test runs against a slice no gate ever loads"
  done
  for cid in $(manifest_row planning); do
    seed_has "$cid" || err "check-manifest-bypass/seed.sh seeds the PLANNING slice but omits check $cid, which the GATE_MANIFEST planning row requires — the fixture no longer seeds what it claims, and H1's self-test is testing a slice that does not exist"
  done
  for cid in $(manifest_row implementation); do
    seed_has "$cid" && err "check-manifest-bypass/seed.sh contains check $cid from the IMPLEMENTATION row — the fixture's whole purpose is that those anchors are ABSENT so H1 fails; including one makes the self-test vacuous"
  done
fi

# --- I8: fixture packaging (core/fixtures == install loop == uninstall loop) ---
# The fixture dirs are shipped by a HARDCODED, enumerated loop in install.sh and
# removed by a second hardcoded loop in uninstall.sh. Nothing kept the three in sync,
# and they had already drifted: nine fixtures on disk, nine in install, FIVE in
# uninstall. A fixture missing from install never reaches a consumer at all — it is an
# adversarial self-test that silently does not exist, which is strictly worse than no
# fixture, because the catalog claims it is covered. Glob the truth and compare.
fixture_list() { # fixture_list <script> -> dir names, one per line
  awk '/^for fixture_dir in /{ sub(/^for fixture_dir in /,""); sub(/; do.*$/,""); print }' "$1" \
    | tr ' ' '\n' | grep -E '.' | sort -u
}
on_disk="$(find "$REPO_ROOT/core/fixtures" -mindepth 1 -maxdepth 1 -type d -exec basename {} \; 2>/dev/null | sort -u)"
in_install="$(fixture_list "$REPO_ROOT/scripts/install.sh")"
in_uninstall="$(fixture_list "$REPO_ROOT/scripts/uninstall.sh")"

# DIST-ONLY fixtures. A fixture is shipped so it can RUN on the consumer. One whose
# subject is not shipped cannot run there, and shipping it anyway plants a fixture that
# is permanently dormant on every consumer — the same "the catalog claims it is covered
# and it is not" failure this block exists to prevent, just pointed the other way. Such a
# fixture is named here and is NOT expected in install.sh's loop.
#
# The exemption is not self-certifying: each name below must ALSO be absent from
# install.sh's loop (a stale exemption for a now-shipped fixture would silently excuse it
# from the sync check above).
# DERIVED, not listed. A fixture is dist-only iff it carries a `.dist-only` marker file.
# It was a hand-maintained string here, and three readers had to agree about it: install.sh
# (which omitted it, correctly), map_consumer() (which shipped every core/fixtures/* on every
# pull, and therefore shipped it anyway), and this check. They did not agree, and the
# reference consumer ended up with tests/fixtures/enforcement-map-sites/ and no subject script
# beside it. A list two writers must remember to update is the bug. The marker sits next to
# the fixture it exempts, and every reader derives the same answer from the same file.
DIST_ONLY="$(cd "$REPO_ROOT/core/fixtures" 2>/dev/null && for d in */; do
  [ -f "${d}.dist-only" ] && printf '%s\n' "${d%/}"
done | sort -u)"
for f in $DIST_ONLY; do
  printf '%s\n' "$in_install" | grep -qx "$f" && err "fixture '$f' is listed DIST-ONLY in validate-enforcement-map.sh but install.sh ships it. Either drop the exemption or stop shipping it — as written, it is excused from the install/uninstall sync check for no reason."
  [ -d "$REPO_ROOT/core/fixtures/$f" ] || err "fixture '$f' is listed DIST-ONLY but does not exist in core/fixtures/ — stale exemption."
done

shippable="$(comm -23 <(printf '%s\n' "$on_disk") <(printf '%s\n' "$DIST_ONLY"))"
miss_install="$(comm -23 <(printf '%s\n' "$shippable") <(printf '%s\n' "$in_install"))"
[ -n "$miss_install" ] && err "fixture(s) in core/fixtures/ that install.sh never ships (so no consumer has them): $(echo $miss_install)"
ghost_install="$(comm -13 <(printf '%s\n' "$on_disk") <(printf '%s\n' "$in_install"))"
[ -n "$ghost_install" ] && err "install.sh ships fixture(s) that do not exist in core/fixtures/: $(echo $ghost_install)"
drift_uninstall="$(comm -3 <(printf '%s\n' "$in_install") <(printf '%s\n' "$in_uninstall") | tr -d '\t')"
[ -n "$drift_uninstall" ] && err "install.sh and uninstall.sh fixture loops disagree (uninstall would orphan or over-remove): $(echo $drift_uninstall)"

# --- I10: fixture hermeticity -------------------------------------------------
# A fixture that invokes a hook and INHERITS the operator's ambient config tests the
# CONFIG, not the code. The hooks honour thirteen AI_DLC_* tunables; a consumer that sets
# any one of them in settings.json exports it into every session, `git push` inherits it,
# and the pre-push gate then runs the fixture against a hook configured differently from
# what its assertions assume.
#
# Observed live: a consumer pinned AI_DLC_MODEL_ROW=1M — the documented way to declare the
# model row — and SEVEN context-sensor assertions failed against a sensor behaving exactly
# as specified. The gate blocked every push on that repo. The distribution never caught it
# because the distribution sets none of these: THE CHECK COULD NOT FIRE WHERE IT WAS
# AUTHORED, which is the same defect this file has now shipped three fixes for.
#
# So: any fixture that drives a hook must scrub AI_DLC_* first. Asserted, not trusted.
for d in "$REPO_ROOT"/core/fixtures/*/; do
  [ -f "$d/run.sh" ] || continue
  grep -qE 'hooks/ai-dlc|\$HOOK' "$d/run.sh" || continue          # not a hook fixture
  grep -qE 'unset "\$_v"|env -u AI_DLC' "$d/run.sh" \
    || err "fixture '$(basename "$d")' invokes a hook but never scrubs ambient AI_DLC_* env. A consumer that tunes any of the hooks' AI_DLC_* variables in settings.json will fail this fixture — and its pre-push gate will then block every push — against a hook that is behaving correctly. Scrub the env at the top of run.sh."
done

# --- I13: every shipped hook is REGISTERED. install.sh copies core/hooks/*.sh by GLOB, so a
# new hook always reaches the consumer's .claude/hooks/ — but it only ever RUNS if
# templates/settings.json.template names it in a matcher block (settings-merge.sh strips and
# re-appends by the ai-dlc-*.sh pattern on pull, so the template is the single registration
# site). Nothing asserted the two agree. A hook that is copied but never registered installs
# to every consumer, is present on disk, passes its own fixture, and silently never fires:
# a check that cannot fire, in the most literal form this repo has — the file is RIGHT THERE.
# The glob is what makes it invisible; the fixture is what makes it feel covered.
TEMPLATE="$REPO_ROOT/templates/settings.json.template"
if [ -r "$TEMPLATE" ]; then
  for h in "$REPO_ROOT"/core/hooks/ai-dlc-*.sh; do
    [ -f "$h" ] || continue
    hb="$(basename "$h")"
    grep -q "$hb" "$TEMPLATE" \
      || err "hook '$hb' exists in core/hooks/ but is never named in templates/settings.json.template. install.sh copies it by glob, so it WILL land in every consumer's .claude/hooks/ and WILL never run — no matcher block invokes it. Register it in the template (settings-merge.sh upserts it on pull), or delete the hook."
  done
  # And the inverse: a template entry naming a hook that no longer exists wires a consumer's
  # settings.json to a missing command on the next pull.
  while IFS= read -r hb; do
    [ -f "$REPO_ROOT/core/hooks/$hb" ] \
      || err "templates/settings.json.template registers '$hb', which does not exist in core/hooks/. Every consumer's settings.json would get a hook command pointing at a missing file."
  done < <(grep -oE 'ai-dlc-[a-z0-9-]+\.sh' "$TEMPLATE" | sort -u)
fi

# --- I14: a registered hook must be COMMITTED EXECUTABLE. Registration (I13) proves a hook is
# WIRED; it does not prove it can RUN. settings.json invokes a hook as a bare path, so a hook
# committed 0644 installs byte-perfect and inert — the harness cannot exec it, nothing errors
# loudly, and every content-diffing verification in the reconcile still reports green.
#
# This is I13's own blind spot, and it had already bitten twice before anyone looked:
# ai-dlc-driver-signal.sh (a Stop hook) and the session driver were both committed 0644. Fresh
# installs hid it because install.sh chmods the whole glob after copying; only a PULLING consumer
# ever saw the real mode. Assert the source mode, so the fix in reconcile/apply.sh (which now
# derives the bit from git's tree) has a correct bit to derive FROM.
for h in "$REPO_ROOT"/core/hooks/ai-dlc-*.sh; do
  [ -f "$h" ] || continue
  hb="$(basename "$h")"
  grep -q "$hb" "$TEMPLATE" 2>/dev/null || continue          # unregistered -> I13 already errs
  m="$(git -C "$REPO_ROOT" ls-files -s -- "core/hooks/$hb" 2>/dev/null | awk '{print $1}')"
  [ -n "$m" ] || continue                                     # untracked -> not shippable yet
  [ "$m" = "100755" ] \
    || err "hook '$hb' is registered in templates/settings.json.template but is COMMITTED $m, not 100755. settings.json invokes it as a bare path, so every consumer that PULLS it gets it non-executable and INERT — its enforcement silently absent while every content check reports green. Fix with: git update-index --chmod=+x core/hooks/$hb"
done

# Same rule for anything else a consumer executes as a bare path. The session driver and the
# pre-push git hook are both invoked directly, never via `bash <path>`. (Fixtures are exempt by
# construction: core/git-hooks/pre-push runs them as `bash "$d/run.sh"`, so their mode is inert.)
for rel in session-driver/ai-dlc-session-driver.sh git-hooks/pre-push; do
  [ -e "$REPO_ROOT/core/$rel" ] || continue
  m="$(git -C "$REPO_ROOT" ls-files -s -- "core/$rel" 2>/dev/null | awk '{print $1}')"
  [ -n "$m" ] || continue
  [ "$m" = "100755" ] \
    || err "core/$rel is executed as a bare path by consumers but is COMMITTED $m, not 100755. A pulling consumer gets it non-executable. Fix with: git update-index --chmod=+x core/$rel"
done

# --- I15: ONE anchor grammar. layer-drift.sh REPORTS a heading-number collision and
# relabel-extension-checks.sh FIXES it. They are two programs reading one thing, so a
# grammar that drifts between them means the operator is told to relabel a collision with
# a tool that cannot see the heading. relabel shipped the narrower copy for ~20 versions:
# it required `[0-9]+` first, so core's real `### H1.` / `### H2.` yielded no anchor and an
# extension colliding on H1 was unrelabellable.
#
# The two are now byte-identical by assertion rather than by hope. A sourced helper would
# be the textbook fix, but it must then be installed and resolved in both fixture layouts —
# the v0.55.2 dead-path failure mode — for a single shared line. Assert equality instead.
#
# NOT joined to validate-enforcement-map's own head_ids (line 149): that one is deliberately
# narrower and its sibling at line 146 BANS the `Check ` prefix ANCHOR_RE tolerates. It
# polices core's catalog form; these two read arbitrary consumer layer files. Different job.
ag_drift="$(sed -n 's/^ANCHOR_RE=//p' "$REPO_ROOT/core/skills/ai-dlc-update/reconcile/layer-drift.sh" | head -1)"
ag_relabel="$(sed -n 's/^ANCHOR_RE=//p' "$REPO_ROOT/core/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh" | head -1)"
if [ -z "$ag_drift" ] || [ -z "$ag_relabel" ]; then
  err "I15 cannot find an ANCHOR_RE definition in layer-drift.sh and/or relabel-extension-checks.sh. The check that binds the two anchor grammars just went vacuous — it must locate both or fail loudly, never pass by finding nothing."
elif [ "$ag_drift" != "$ag_relabel" ]; then
  err "the anchor grammar has forked: layer-drift.sh defines ANCHOR_RE=$ag_drift but relabel-extension-checks.sh defines ANCHOR_RE=$ag_relabel. layer-drift REPORTS collisions and relabel FIXES them; a narrower grammar in either means a reported collision no tool can resolve. Make them byte-identical."
fi

# --- I18: ONE bold-anchor rule. The SAME split as I15, one function down. layer-drift.sh
# classifies a pull; validate-layer-entries.sh lints at authoring time and runs in CI. Both
# must agree on what a bold `**7a-post. …**` anchor is versus a `**1. Narrative drift.** …`
# prose list item, because whichever the operator did not run is the one that is wrong.
#
# The narrower question — does the opening `**N.` alone make an anchor? — shipped as YES in
# both copies and read a consumer's three-item triage list as sections 1/2/3, colliding them
# with core's retro steps 1/2/3 forever, with a prescribed remedy ("label the heading") that
# cannot be applied to a sentence.
#
# Byte-identical by assertion, not by hope — same reasoning as I15: a sourced helper must then
# be installed and resolved in both fixture layouts (the v0.55.2 dead-path mode) for one shared
# function. The layer-catalog-collision fixture binds the two BEHAVIOURALLY on a real input;
# this binds them TEXTUALLY, and unlike the fixture it also runs when nobody seeds a consumer.
ba_fn() { awk '/^bold_anchors_of_file\(\) \{/,/^\}/' "$1" 2>/dev/null; }
ba_drift="$(ba_fn "$REPO_ROOT/core/skills/ai-dlc-update/reconcile/layer-drift.sh")"
ba_lint="$(ba_fn "$REPO_ROOT/core/scripts/validate-layer-entries.sh")"
if [ -z "$ba_drift" ] || [ -z "$ba_lint" ]; then
  err "I18 cannot find a bold_anchors_of_file() definition in layer-drift.sh and/or validate-layer-entries.sh. The check that binds the two bold-anchor rules just went vacuous — it must locate both or fail loudly, never pass by finding nothing."
elif [ "$ba_drift" != "$ba_lint" ]; then
  err "the bold-anchor rule has forked between layer-drift.sh and validate-layer-entries.sh. One classifies the pull and the other lints authoring and gates CI; a rule that differs between them means the two disagree about what a section IS, and the operator believes whichever they happened to run. Make bold_anchors_of_file() byte-identical."
fi

# --- I19: SKILL.md Rule 8's intensity table is the ONLY place the validation-cycle
# minimums are enumerated. Check 20 kept its own copy of them and the copy dropped a row:
# Rule 8 defines four intensities, Check 20 listed three, and `carry-over-single` appeared
# ZERO times in gate-validation.md. A gate declaring it reached the one check that enforces
# intensity and found no minimum to test against — indistinguishable from a gate that met it.
#
# Third instance in two releases of one class: a set declared twice, one copy drifts (the
# universal core across three sources; check-manifest-bypass's fourth copy of it; now this).
# Where the duplicate MUST exist the copies are bound (I15, I18). Here it must not exist at
# all, so assert it does not come back rather than binding a copy into permanence.
#
# The signal is an intensity name and an evaluation name on one line — how a minimum is
# written. Naming an intensity is fine and common (route.md declares one, discovery.md
# branches on one); RESTATING what it requires is the defect.
r8_dupes="$(grep -rnE '`(full|standard|lightweight|carry-over-single)`[^|]*(Party Mode|Advanced Elicitation|Adversarial Review)' \
             "$REPO_ROOT/core/skills/ai-dlc/steps/" 2>/dev/null | grep -v '^[^:]*:[0-9]*:.*Rule 8' || true)"
if [ -n "$r8_dupes" ]; then
  err "the validation-intensity minimums are enumerated outside SKILL.md Rule 8's table — that table is the single source and a second copy is what dropped carry-over-single from Check 20. Cite the table's 'Minimum cycle per planning artifact' column instead of restating it:
$r8_dupes"
fi

# --- I16: runtime-pipeline prose must cite CONSUMER paths, never `core/`-prefixed ones.
# install.sh maps core/<x> -> .claude/<x>, but that governs where files LAND, not path
# references in the prose INSIDE them. So installed core kept citing the distribution's own
# layout, which resolves nowhere at any consumer: Check 19 sent the reviewer to
# `core/team-roles/code-reviewer.md` for the Self-Discrimination Map, a dead path.
#
# Not cosmetic. That one unsubstituted ref is the only legitimate reason a consumer's Check-19
# extension forked from core at all — it localized the path, and in forking silently dropped
# core's ~28-line core-path wiring-citation clause. One dead link cost a live gate rule.
#
# DERIVE the directory list from core/*/ on disk. The hand-listed five-directory set this bug
# was first reported with already omitted four live subtrees (schemas, fixtures, ci-templates,
# git-hooks) — the same rot I8 exists to catch.
#
# Scope is the RUNTIME pipeline only. `core/skills/ai-dlc-update/**` reasons about the
# distribution layout by design (comparing core/ to .claude/), fixtures build real core/ trees
# on disk, and enforcement-map.yaml's `core/scripts/...` values are DATA this very script greps
# in that exact shape at I9. Markdown-only + the core-manifest exclusion keeps all of them out.
core_dirs="$(find "$REPO_ROOT/core" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort | paste -sd'|' -)"
if [ -z "$core_dirs" ]; then
  err "I16 derived an EMPTY core/ directory list — the prose-path check just went vacuous and would pass over any dead citation. Expected core/*/ subtrees to exist."
else
  while IFS= read -r hit; do
    [ -n "$hit" ] || continue
    err "runtime-pipeline prose cites a distribution path that does not exist at any consumer: ${hit}. install.sh maps core/<x> -> .claude/<x>, so an installed file citing 'core/...' is a dead link for every reader. Cite the consumer path (e.g. '.claude/team-roles/qa.md' — core's own convention, ~29 uses) or a bare filename."
  done < <(find "$REPO_ROOT/core/skills/ai-dlc" "$REPO_ROOT/core/team-roles" -name '*.md' -type f \
             ! -name 'core-manifest.md' 2>/dev/null \
           | sort \
           | xargs grep -InE "core/(${core_dirs})/" 2>/dev/null \
           | sed "s|^$REPO_ROOT/||" | cut -c1-160)
fi

# --- Fixture root-resolution depth: a seed that hand-resolves the repo root must use the
# SAME `$HERE/../../..` depth for BOTH layouts. A fixture lives at `core/fixtures/<name>/`
# upstream and `tests/fixtures/<name>/` in a consumer (install.sh's map) — BOTH exactly three
# dirs below root. A seed that resolves its consumer branch with `$HERE/../..` (two dirs) lands
# at `tests/` in a consumer, never finds its script/schema, and every seed dies with "not found
# in either layout" → the consumer's pre-push fixture suite FAILS against tooling that is
# correct in the distribution. This bit eight fixtures at once (the distribution takes the
# other branch, so it never exercised the buggy one — the distribution is not a consumer).
# Assert both cd-depths are three, so the next copy-paste cannot re-introduce it.
for d in "$REPO_ROOT"/core/fixtures/*/; do
  s="$d/seed.sh"; [ -f "$s" ] || continue
  while IFS= read -r depth; do
    [ "$depth" = "../../.." ] || err "fixture '$(basename "$d")' seed resolves a repo-root var with depth '\$HERE/$depth' — must be '\$HERE/../../..' (three dirs below root, matching BOTH core/fixtures/<name>/ and tests/fixtures/<name>/). A shallower depth passes in the distribution and fails in every consumer's pre-push."
  done < <(grep -oE '[DC]_ROOT="\$\(cd "\$HERE/(\.\./)*\.\.' "$s" | sed -E 's#.*\$HERE/##')
done

# --- Audit-anchors template is BOUND to its canonical schema. The housekeeping schema used to
# live in two places (this template + each project's live header) with nothing comparing them;
# they drifted (the template went stale, missing `audit_window`). Now the schema is canonical in
# core/schemas/audit-anchors.json, the template's header is RENDERED from it, and the entry
# validator loads it. Assert the shipped template still passes its own validator, so the template
# cannot silently re-stale from the schema.
AA_VALIDATOR="$REPO_ROOT/core/scripts/validate-audit-anchors.sh"
AA_TEMPLATE="$REPO_ROOT/templates/audit-anchors.md.template"
if [ -f "$AA_VALIDATOR" ] && [ -f "$AA_TEMPLATE" ]; then
  bash "$AA_VALIDATOR" "$AA_TEMPLATE" >/dev/null 2>&1 \
    || err "templates/audit-anchors.md.template no longer matches core/schemas/audit-anchors.json (header drift or a malformed bootstrap entry). Re-render its header with 'core/scripts/validate-audit-anchors.sh --render' and fix the entry — the template must never drift from the canonical schema again."
fi

# --- I11: the convergence-cycle scope list is DERIVED, not remembered ---------
# THREE SETS MUST BE ONE SET:
#   (a) steps whose file dispatches an adversarial REVIEW  (they run a convergence cycle)
#   (b) steps whose file references the adversarial REPAIR dispatch (a remediator repairs;
#       the LEAD must not — it is the most context-saturated agent in the pipeline, which is
#       the whole reason the remediator role exists)
#   (c) steps named in Check 24's Scope sentence            (a gate reads the verdict)
#
# A step in (a) but not (c) runs an unbounded convergence loop that NO GATE ADJUDICATES —
# and a loop nobody adjudicates reads exactly like a loop that converged. A step in (a) but
# not (b) has its own author repairing its own artifact, which is the failure the remediator
# was created to end.
#
# This list was hand-maintained and it rotted TWICE. v0.58.0 caught doc-repair-backfill and
# sprint-review-next running unadjudicated cycles and added them to Check 24's scope. The
# same sweep walked straight past carry-over-evaluation, which was running one too — Rule 8
# binds it ("per planning artifact"), its step file never said so, and the reference consumer
# ran a 2-pass cycle there with the lead repairing and no gate reading the verdict. The sweep
# missed it for exactly the reason I8's site table missed core/git-hooks/: the list was
# hand-maintained, so the check had no row for it, and a check that cannot fire reads exactly
# like a check that passed. Derive the list. Never hand-maintain it.
STEPS_DIR="$REPO_ROOT/core/skills/ai-dlc/steps"
if [ -d "$STEPS_DIR" ]; then
  # The python goes to a temp FILE, not a heredoc inside $( ). On bash 3.2 (macOS, the
  # floor this repo targets) a heredoc nested in a command substitution has its body
  # scanned for shell quotes BEFORE the heredoc is processed -- so a lone apostrophe in a
  # python comment ("Check 24's scope") is read as an opening quote and the whole script
  # fails to parse. Top-level heredocs are fine; nested ones are not.
  I11_PY="$(mktemp)"
  cat > "$I11_PY" <<'I11EOF'
import os, re, sys
steps_dir, gv = sys.argv[1], sys.argv[2]

def collapse(p):
    # The procedure names WRAP across lines in the step files (Adversarial review /
    # dispatch). A line-oriented grep misses them, and a check that cannot see the thing
    # it checks reads exactly like a check that passed. Collapse whitespace first.
    return re.sub(r"\s+", " ", open(p, encoding="utf-8").read())

steps = {}
for fn in sorted(os.listdir(steps_dir)):
    if not fn.endswith(".md") or fn.startswith("_"):
        continue
    steps[fn[:-3]] = collapse(os.path.join(steps_dir, fn))

review = set(n for n, t in steps.items() if "Adversarial review dispatch" in t)
repair = set(n for n, t in steps.items() if "Adversarial repair dispatch" in t)

# Check 24 Scope sentence. Only names that are REAL step files count -- the sentence also
# backticks `lightweight`, which is an intensity, not a step.
gvt = open(gv, encoding="utf-8").read()
m = re.search(r"^### 24\.(.*?)^### ", gvt, re.S | re.M)
scope = set()
if m:
    sm = re.search(r"Those steps are:(.*?)\n\n", m.group(1), re.S)
    if sm:
        scope = set(t for t in re.findall(r"`([a-z-]+)`", sm.group(1)) if t in steps)

def emit(names, msg):
    if names:
        sys.stdout.write("ERR\t" + " ".join(sorted(names)) + "\t" + msg + "\n")

emit(review - scope,
     "step(s) run an adversarial convergence cycle but are ABSENT from Check 24 scope -- the loop is adjudicated by nobody, which reads exactly like a loop that converged")
emit(scope - review,
     "Check 24 scope names step(s) that dispatch no adversarial review -- a stale scope entry makes the check self-skip on a gate it claims to cover")
emit(review - repair,
     "step(s) dispatch an adversarial REVIEW but never reference the adversarial REPAIR dispatch -- the lead will repair its own artifact, which is the failure the remediator role exists to end")
I11EOF
  I11_OUT="$(python3 "$I11_PY" "$STEPS_DIR" "$GV")"
  rm -f "$I11_PY"
  while IFS="$(printf '\t')" read -r tag names msg; do
    [ "$tag" = "ERR" ] || continue
    err "$msg: $names"
  done <<EOF
$I11_OUT
EOF
fi

# The THIRD writer. install.sh is not the only thing that puts core/ files into a
# consumer — `reconcile/preclassify.sh`'s map_consumer() does too, on every pull, and
# the two must agree on the destination or the consumer gets two copies at two paths
# and the live one goes stale. They HAD diverged: map_consumer had no `core/fixtures/`
# case, so the `core/*` catch-all filed fixtures under `.claude/fixtures/` while
# install.sh writes `tests/fixtures/` — the only path gate-validation and H1 reference.
# Evaluate the real function rather than trusting a grep of it.
PRECLASS="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/preclassify.sh"
if [ -f "$PRECLASS" ]; then
  maps_to() { bash -c "CONS=/nonexistent; $(awk '/^map_consumer\(\) \{/,/^\}/' "$PRECLASS"); map_consumer '$1'" 2>/dev/null; }

  # I17's probe. Compose the two functions exactly as apply.sh does at runtime — map_consumer
  # from preclassify, consumer_path from apply — and evaluate the result. Composing rather
  # than grepping means this stays honest whether apply.sh delegates (as it must) or someone
  # reintroduces a private case list: either way we measure where a real path LANDS.
  APPLY_SH="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/apply.sh"
  APPLIES_TO_OK=""
  if [ -f "$APPLY_SH" ]; then
    applies_to() { bash -c "
      CONSUMER=/nonexistent-consumer
      $(awk '/^map_consumer\(\) \{/,/^\}/' "$PRECLASS")
      $(awk '/^consumer_path\(\) \{/,/^\}/' "$APPLY_SH")
      consumer_path '$1'" 2>/dev/null; }
    if [ -n "$(applies_to 'team-roles/PROBE')" ]; then
      APPLIES_TO_OK=yes
    else
      err "I17 could not evaluate apply.sh's consumer_path() — the check that binds the pull's WRITER to install.sh just went vacuous, and a vacuous check reads exactly like a passing one. Expected 'consumer_path() {' in $APPLY_SH and 'map_consumer() {' in $PRECLASS, each with its closing brace in column 0."
    fi
  fi
  # <core dir>|<the destination install.sh writes>. Every core/ subtree the installer
  # ALSO places must be listed, or the catch-all silently invents a second home for it.
  # Three entries here were live bugs: fixtures landed in .claude/fixtures/ (dead, while
  # H1 reads tests/fixtures/), ci-templates in .claude/ci-templates/ (dead, while
  # workflows run from .github/workflows/ — which is why a real consumer's CI gates sat
  # dormant and never once fired), and git-hooks in .claude/git-hooks/ (dead, while
  # install.sh writes .githooks/ — so v0.53.0's pre-push gate, the CI replacement, reached
  # the reference consumer at a path no runner, no git config, and no script reads).
  #
  # THE TABLE IS NOW BOUND AT BOTH ENDS, AND THAT IS THE POINT. Listing sites by hand is
  # what let git-hooks through: the check passed because the row was simply absent, and a
  # check that cannot fire reads exactly like a check that passed. So:
  #   (a) COMPLETENESS — every core/<dir>/ on disk must have a row here. A new subtree with
  #       no row is an ERROR, not a silent fall-through to the `core/*` catch-all.
  #   (b) AGREEMENT    — map_consumer() must send each subtree to its stated destination.
  #   (c) INSTALLER    — the stated destination must actually appear in install.sh, so a
  #       row cannot be satisfied by writing a destination the installer never uses.
  SITES_TABLE="$(cat <<'SITES'
ci-templates|.github/workflows
fixtures|tests/fixtures
git-hooks|.githooks
schemas|.claude/schemas
hooks|.claude/hooks
scripts|scripts/ai-dlc
session-driver|.claude/session-driver
skills|.claude/skills
team-roles|.claude/team-roles
SITES
)"
  # (a) Completeness: every core/<dir>/ on disk is accounted for.
  for d in "$REPO_ROOT"/core/*/; do
    [ -d "$d" ] || continue
    cdir="$(basename "$d")"
    printf '%s\n' "$SITES_TABLE" | grep -q "^${cdir}|" || err "core/${cdir}/ has no destination row in I8's site table. map_consumer()'s \`core/*\` catch-all will file it under '.claude/${cdir}/' — add a row stating where install.sh actually writes it (or '.claude/${cdir}' if the catch-all is right). This is the check core/git-hooks/ slipped past by being absent."
  done
  # (b) Agreement + (c) installer binding.
  while IFS='|' read -r cdir dest; do
    [ -n "$cdir" ] || continue
    [ -d "$REPO_ROOT/core/$cdir" ] || continue
    got="$(maps_to "core/$cdir/PROBE")"
    [ "$got" = "$dest/PROBE" ] || err "the pull and the installer disagree on where core/$cdir/ goes: map_consumer() sends it to '$got', install.sh writes '$dest/'. The consumer gets two copies at two paths, and the one the pull keeps fresh is not the one anything reads."
    # Anchored at a path boundary, deliberately. A bare substring match is satisfied by
    # any destination that merely STARTS with this one (`.githooks-REMOVED` contains
    # `.githooks`), so the row would stay green against an installer that no longer
    # writes it — the check would be as hand-wavy as the list it replaced.
    dest_re="$(printf '%s' "$dest" | sed 's/[][\.^$*+?(){}|]/\\&/g')"
    grep -qE '\$PROJECT_ROOT/'"$dest_re"'([/"]|$)' "$REPO_ROOT/scripts/install.sh" || err "I8's site table says core/$cdir/ goes to '$dest/', but install.sh never writes \$PROJECT_ROOT/$dest. Either the row is wrong or the installer stopped shipping it."
    # (d) I17 — THE WRITER. map_consumer() only CLASSIFIES; on a pull, reconcile/apply.sh is
    # the thing that actually places files, and it was bound to nothing. It carried its own
    # hand-listed copy of this table and omitted core/session-driver/, core/ci-templates/ and
    # core/git-hooks/ — which therefore never applied, while the same run re-stamped
    # .ai-dlc-version anyway. A consumer's stamp claimed a version its tree did not have.
    # session-driver hid for releases because its only delta was ever a mode bit install.sh
    # had already set. Evaluate the real composed function; a grep would not have caught it.
    if [ -n "$APPLIES_TO_OK" ]; then
      got_a="$(applies_to "$cdir/PROBE")"
      [ "$got_a" = "/nonexistent-consumer/$dest/PROBE" ] || err "reconcile/apply.sh — the thing that WRITES on a pull — sends core/$cdir/ to '${got_a:-<nothing>}', but I8's table and install.sh say '$dest/'. A subtree apply.sh cannot place is silently skipped while the run still re-stamps, leaving a consumer whose .ai-dlc-version claims a version its tree lacks. apply.sh must derive every path from preclassify.sh's map_consumer(), never from a private table."
    fi
  done <<< "$SITES_TABLE"
fi

# --- I4: no dormant binding ---------------------------------------------------
# enforcer + ci_workflow file paths (distribution layout). Restricted to actual
# value lines (enforcer list items and ci_workflow: values) so prose/comment
# mentions of a path never register as a binding.
paths="$( {
  grep -oE '^      - core/(scripts|ci-templates)/[A-Za-z0-9._/-]+\.(sh|yml)' "$MAP" | sed -E 's/^      - //'
  grep -oE '^    ci_workflow: core/[A-Za-z0-9._/-]+\.yml' "$MAP" | sed -E 's/^    ci_workflow: //'
} | sort -u)"
for p in $paths; do
  [ -f "$REPO_ROOT/$p" ] || err "dormant binding: '$p' referenced in map but not on disk"
done
# fixtures: map uses consumer-runtime paths (tests/fixtures/<name>); upstream
# they live under core/fixtures/<name>. Resolve by basename.
fixtures="$(grep -oE 'tests/fixtures/[A-Za-z0-9._-]+' "$MAP" | sed -E 's#tests/fixtures/##' | sort -u)"
for d in $fixtures; do
  [ -d "$REPO_ROOT/core/fixtures/$d" ] || err "fixture '$d' named in map but missing under core/fixtures/"
done

# --- I9: every script enforcer declares WHERE it is invoked -------------------
# The map recorded `enforcer:` (WHO enforces a rule) on every entry and
# `call_sites:` (WHERE the enforcer is actually invoked) on ONE of them. So
# "Enforced by validate-X.sh" was a CLAIM, and nothing could tell a claim from a
# wiring. Measured on the reference consumer at v0.51.0:
#
#   validate-steering-budget.sh   11 real starvation violations, worst 10.0 min
#                                 -- invoked from NO gate. implementation.md:152
#                                 says "fails the gate on it"; that sentence was
#                                 false at every gate, in every phase.
#
# That is the mechanism behind three consecutive half-wired releases. A rule whose
# enforcer is called from nowhere is indistinguishable, in this file, from one
# called everywhere. I9 makes the difference representable and then required.
#
# Scope: `adjudication: script` only. An `llm` check is adjudicated by the lead
# READING gate-validation.md, so that file is inherently its call site; demanding
# a call_sites list there would be ceremony.
sites_of() { # sites_of <block> -> the file token of each site:, one per line
  printf '%s' "$1" | awk '
    /^    call_sites:/ {f=1; next}
    f && /^    [a-z_]+:/ {f=0}
    f && /^      - site:/ { v=$0; sub(/^      - site:[ ]*/,"",v); print v }
  '
}
enforcers_of() {
  printf '%s' "$1" | grep -oE '^      - core/(scripts|hooks)/[A-Za-z0-9._-]+' | sed -E 's#^      - ##'
}

# Resolve a site's leading file token to a real path under the skill.
resolve_site_file() {
  case "$1" in
    SKILL.md*)            echo "$REPO_ROOT/core/skills/ai-dlc/SKILL.md" ;;
    enforcement-map.yaml*) echo "" ;;
    *.md*)                echo "$REPO_ROOT/core/skills/ai-dlc/steps/${1%%[ ]*}" ;;
    *)                    echo "" ;;
  esac
}

while IFS= read -r blk_id; do
  [ -n "$blk_id" ] || continue
  block="$(awk -v want="$blk_id" '
    $0 ~ "^  - id: \"?" want "\"?$" {f=1; print; next}
    f && /^  - id: / {f=0}
    f {print}
  ' "$MAP")"
  adj="$(printf '%s' "$block" | sed -nE 's/^    adjudication: ([a-z]+).*/\1/p' | head -1)"
  [ "$adj" = "script" ] || continue

  sites="$(sites_of "$block")"

  # W1 -- a script enforcer with no declared call site.
  if [ -z "$sites" ]; then
    err "enforcement-map entry '$blk_id' is adjudication:script but declares NO call_sites. Its enforcer may be invoked from nowhere and nothing would notice — this is exactly how validate-steering-budget.sh came to guard 11 live violations from zero gates. Declare where it runs, with a posture."
    continue
  fi

  # W2 -- a declared call site must at least NAME the enforcer in the file it
  # points at. This catches a fictional site: an entry claiming to run at a step
  # whose file has never heard of the script.
  #
  # What W2 deliberately does NOT do, stated so nobody reads it as covered: it
  # cannot distinguish an INVOCATION from a PROSE MENTION. `retro.md:639` is a real
  # indented command; `implementation.md:152` ("validate-steering-budget.sh fails
  # the gate") is a sentence that was false for every gate that ever ran -- and a
  # basename grep passes both. Telling them apart means parsing English, and a
  # heuristic that fails closed on a legitimate new phrasing is an unpassable gate,
  # which gets turned off.
  #
  # The teeth are therefore in W1 + the `posture:` field, not here: an author must
  # WRITE DOWN where the enforcer runs and what happens when it fails, and that
  # declaration is reviewable. W2 only stops the declaration from naming a file
  # that does not know the script exists.
  #
  # Accept the bare form (`scripts/validate-X.sh`) and the verdict.sh wrapper
  # (`verdict.sh validate-X`), which is how gate-validation.md legitimately invokes
  # artifact-budget -- a basename-only grep misses the wrapped call entirely.
  for enf in $(enforcers_of "$block"); do
    base="$(basename "$enf")"
    stem="${base%.sh}"
    case "$enf" in core/hooks/*) continue ;; esac   # hooks are wired in settings, not step files
    while IFS= read -r site; do
      [ -n "$site" ] || continue
      f="$(resolve_site_file "$site")"
      [ -n "$f" ] || continue
      if [ ! -f "$f" ]; then
        err "entry '$blk_id' names call site '$site', but $f does not exist"
        continue
      fi
      if ! grep -qE "(${base}|verdict\.sh ${stem}\b)" "$f"; then
        err "entry '$blk_id' declares call site '$site', but $(basename "$f") never mentions ${base} (nor 'verdict.sh ${stem}'). The site is fictional: the file it names has never heard of the enforcer."
      fi
    done <<SITES
$sites
SITES
  done
done <<IDS
$(awk '/^checks:/{c=1} c && /^  - id:/ { v=$0; sub(/^  - id:[ ]*/,"",v); gsub(/"/,"",v); print v }' "$MAP")
IDS

# --- I5: core_manifest copies in sync (prefix-normalized) --------------------
norm_core_manifest() {
  awk '
    /^core_manifest:/ {f=1; next}
    f && /^  - / {v=$0; sub(/^  - /,"",v); print v; next}
    f {f=0}
  ' "$1" | sed -E 's#^core/skills/ai-dlc/##; s#^core/##' | sort -u
}
cm="$(norm_core_manifest "$CORE_MANIFEST")"
ss="$(norm_core_manifest "$SETUP_SITES")"
if [ "$cm" != "$ss" ]; then
  err "core_manifest copies diverge (core-manifest.md vs reconcile/setup-sites.md):"
  diff <(printf '%s\n' "$cm") <(printf '%s\n' "$ss") >&2 || true
fi

# --- I5b: the enumerated validators ARE core/scripts/, exactly ----------------
# Every other manifest entry is a glob, which needs no reconciliation with the
# tree. The validators are enumerated instead, because scripts/ is shared with the
# consumer and no glob can name our 25 without also naming their ~78.
#
# An enumeration that nothing joins to the directory is a hand-list, and this repo
# has watched a hand-list rot three times: uninstall.sh named 4 of 25 validators,
# map_consumer() had no case for a whole tree (v0.55.2), and unregistered-drift.sh
# missed two subtrees (v0.63.0). So the list and the directory are each other's
# check, in BOTH directions:
#
#   a validator added upstream with no manifest entry -> unguarded at edit time,
#     and it fails here rather than shipping silently unprotected.
#   a manifest entry with no file -> the guard denies edits to a path that does
#     not exist, and the deny reads as protection that is not there.
manifest_scripts="$(printf '%s\n' "$cm" | sed -n 's#^scripts/ai-dlc/##p' | sort -u)"
tree_scripts="$(ls "$REPO_ROOT/core/scripts" 2>/dev/null | sort -u)"
if [ "$manifest_scripts" != "$tree_scripts" ]; then
  err "core_manifest's scripts/ai-dlc/ enumeration does not match core/scripts/:"
  diff <(printf '%s\n' "$manifest_scripts") <(printf '%s\n' "$tree_scripts") >&2 || true
  echo "      < only in the manifest (entry with no file — a deny that protects nothing)" >&2
  echo "      > only in core/scripts/ (a validator no guard protects)" >&2
fi

# --- I12: unregistered-drift scan set is BOUND, not hand-listed ---------------
# reconcile/unregistered-drift.sh scans a HAND-LISTED set of core subtrees for in-place drift.
# Twice that list silently missed a subtree that carried silently-driftable content —
# ai-dlc-setup/ (v0.63.0) and schemas/ (this release) — each overwrite-on-pull, each undetected
# until a real pull hit it. A hand-list is exactly the shape that rots: the next core dir escapes
# the scan and reads, forever, like a dir with no drift. So bind the list to a REVIEWED per-subtree
# policy, and make a new core subtree FAIL the build until it is classified.
#
#   COMPLETENESS — every core/skills/<skill>/ and every other core/<dir>/ has a policy row.
#   SCAN-MATCH   — the rows marked `scan` are EXACTLY the subtrees the ls-tree scans.
# The reason string on each `exempt` row is the review: machinery breaks loudly (not silent prose
# drift), and the update skill self-updates its own tree — neither belongs in the drift scan.
UD="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/unregistered-drift.sh"
if [ -f "$UD" ]; then
  DRIFT_POLICY="$(cat <<'POL'
skills/ai-dlc|scan
skills/ai-dlc-setup|scan
skills/ai-dlc-update|exempt:self-update owns this subtree (step 2), not the drift scan
team-roles|scan
hooks|scan
schemas|scan
scripts|exempt:machinery — an in-place edit breaks loudly (a failing validator), not as silent prose drift
session-driver|exempt:machinery (automation shell), not consumer-read rulebook
ci-templates|exempt:CI templates run from .github/workflows, not consumer-read rulebook
git-hooks|exempt:machinery (git hook), not consumer-read rulebook
fixtures|exempt:adversarial test data, not consumer-authored rulebook
POL
)"
  # Subtrees actually scanned: the core/ paths on unregistered-drift's ls-tree pathspec line.
  ud_scanned="$(awk '/ls-tree -r --name-only/{f=1} f{print} /2>\/dev\/null/{f=0}' "$UD" \
    | grep -oE 'core/skills/[A-Za-z0-9_-]+|core/[A-Za-z0-9_-]+' | sed 's#^core/##' | sort -u)"
  # Units on disk: each skill under core/skills/, plus each other core/<dir>.
  ud_units="$( { for d in "$REPO_ROOT"/core/skills/*/; do [ -d "$d" ] && echo "skills/$(basename "$d")"; done
                 for d in "$REPO_ROOT"/core/*/; do b="$(basename "$d")"; [ "$b" = skills ] && continue; [ -d "$d" ] && echo "$b"; done; } | sort -u)"

  # COMPLETENESS — every unit on disk is classified.
  while IFS= read -r u; do
    [ -n "$u" ] || continue
    printf '%s\n' "$DRIFT_POLICY" | grep -q "^${u}|" \
      || err "core/${u}/ has no drift-scan policy row in validate-enforcement-map.sh I12. Classify it 'scan' (prose/schema a consumer could silently drift) or 'exempt:<reason>' (machinery / self-updated). This is the guard that stops the unregistered-drift scan set rotting the way ai-dlc-setup/ and schemas/ did."
  done <<EOF
$ud_units
EOF
  # Stale rows — every policy row names a real subtree.
  while IFS='|' read -r u disp; do
    [ -n "$u" ] || continue
    [ -d "$REPO_ROOT/core/$u" ] || err "I12 drift-scan policy names core/$u/, which does not exist — stale row."
  done <<EOF
$DRIFT_POLICY
EOF
  # SCAN-MATCH — the scan-marked policy set equals the tool's actual scan set.
  scan_policy="$(printf '%s\n' "$DRIFT_POLICY" | awk -F'|' '$2=="scan"{print $1}' | sort -u)"
  miss_scan="$(comm -23 <(printf '%s\n' "$scan_policy") <(printf '%s\n' "$ud_scanned"))"
  extra_scan="$(comm -13 <(printf '%s\n' "$scan_policy") <(printf '%s\n' "$ud_scanned"))"
  [ -n "$miss_scan" ]  && err "I12: policy marks these core subtrees 'scan' but unregistered-drift.sh does NOT scan them: $(echo $miss_scan). A scan-marked dir the tool skips is a silent-drift hole."
  [ -n "$extra_scan" ] && err "I12: unregistered-drift.sh scans these but the policy does not mark them 'scan': $(echo $extra_scan). Add a 'scan' row or drop them from the ls-tree."
fi

# --- I20: every fixture is DRIVEN, or declares in writing that it cannot be -----
# core/git-hooks/pre-push runs the fixture suite as
#
#     for d in tests/fixtures/*/; do
#       [ -f "$d/run.sh" ] || continue
#
# directly beneath the comment "a fixture never driven is a green light nobody earned."
# A fixture with no run.sh is therefore SKIPPED on every push, silently, while still
# being declared an adversarial self-test in the map. check-1c-bypass and
# check-15-bypass sat in that hole for their entire existence: both were `echo`
# statements describing artifacts they never created, both were bound to a check, and
# no gate, hook or suite could tell them from fixtures that passed.
#
# The hole is structural, not a property of those two — the NEXT driverless fixture
# disappears the same way. So require, of every fixture on disk: a run.sh, or a README
# that states plainly why one is impossible. Two fixtures legitimately cannot have one
# (check-h1-recursion tests an LLM's control flow; check-manifest-bypass tests an LLM's
# read of loaded context — no script observes either), and the exemption is DERIVED
# from each README rather than hand-listed here, because a hand-list is the shape that
# rots: the list itself becomes the thing nobody updates.
#
# Scope: this validator is a dev-repo gate (not installed, not called by pre-push), so
# I20 binds fixtures where they are AUTHORED. A fixture that reaches a consumer without
# a driver has already passed through here.
EXEMPT_MARKER='No `run.sh`, deliberately'
for d in "$REPO_ROOT"/core/fixtures/*/; do
  [ -d "$d" ] || continue
  name="$(basename "$d")"
  [ -f "$d/run.sh" ] && continue
  if [ ! -f "$d/README.md" ]; then
    err "I20 fixture '$name' has neither run.sh nor a README. pre-push skips it silently, so it is indistinguishable from a fixture that passed. Add a driver, or a README stating why one is impossible (marker: '$EXEMPT_MARKER')."
    continue
  fi
  grep -qF "$EXEMPT_MARKER" "$d/README.md" \
    || err "I20 fixture '$name' has no run.sh and its README does not declare the exemption. pre-push skips it silently ('[ -f \"\$d/run.sh\" ] || continue'), so it reads exactly like a fixture that passed. Add a driver, or state why one is impossible with the marker '$EXEMPT_MARKER' and the reason."
done

# --- I21: ONE home for the reconcile helpers, and nothing may grow a second.
#
# `section_of()` is THE section resolver the drift classifiers share, and its divergence
# has already SHIPPED TWICE:
#
#   v0.52.0 — readopt-override's copy was WEAKER than layer-drift's, so it could not
#             resolve the anchor layer-drift had just blocked on, found no stale lines,
#             and would have CLEARED the block.
#   v0.54.2 — register-drift's copy was STRICTER, so it misfiled a renamed section
#             (`## Escalation Protocol` vs core's `## Escalation`) as an ADDITION, which
#             would have rendered core's heading and the consumer's side by side.
#
# Both times the remedy was to hand-copy one body over the other, and both times the
# CHANGELOG recorded "there is one resolver" while nothing MADE it one — so the copies
# drifted again. v0.90.0 finally collapsed all three into reconcile/lib.sh, which the
# three classifiers now source. That fixed the INSTANCES. It did not fix the HOLE:
# nothing stops a fourth file from inlining its own `section_of()` tomorrow, and the
# failure mode is silent by construction — a private copy runs, resolves differently,
# and the tool reports a confident verdict computed from the wrong section.
#
# Same shape as I19, and the same remedy: where the duplicate MUST exist the copies are
# bound (I15, I18); here it must not exist at all, so assert it does not come back rather
# than binding a copy into permanence.
#
# The helper set is DERIVED from lib.sh's own definitions, never hand-listed — a
# hand-list is the thing that stops being updated (I8's site table, I12's scan set).
# Two failures, because a helper can go wrong in two directions: a file that REDEFINES
# it has a private copy that can drift, and a file that CALLS it without sourcing lib.sh
# has a call that cannot resolve at all.
RLIB="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
if [ ! -f "$RLIB" ]; then
  err "I21 cannot find core/skills/ai-dlc-update/reconcile/lib.sh. The check that keeps the shared drift helpers single-homed just went vacuous — it must locate the library or fail loudly, never pass by finding nothing to bind."
else
  lib_fns="$(sed -n 's/^\([a-z_][a-z0-9_]*\)() {.*/\1/p' "$RLIB")"
  if [ -z "$lib_fns" ]; then
    err "I21 found no function definitions in reconcile/lib.sh. Either the library was emptied or its definition form changed; either way the no-second-copy assertion is now testing nothing and would pass against a tree with four resolvers in it."
  else
    for f in "$REPO_ROOT"/core/skills/ai-dlc-update/reconcile/*.sh; do
      [ -f "$f" ] || continue
      fbase="$(basename "$f")"
      [ "$fbase" = "lib.sh" ] && continue
      # Comment lines are stripped: every classifier documents WHY it sources lib.sh,
      # and a check that reads its own documentation as a violation is a check that
      # gets switched off.
      fcode="$(grep -v '^[[:space:]]*#' "$f")"
      sources_lib=0
      printf '%s\n' "$fcode" | grep -q 'lib\.sh' && sources_lib=1
      for fn in $lib_fns; do
        if printf '%s\n' "$fcode" | grep -qE "^[[:space:]]*${fn}\(\)[[:space:]]*\{"; then
          err "I21 reconcile/$fbase defines its own ${fn}(), but reconcile/lib.sh is its ONE home. A private copy is exactly the shape that shipped divergent resolvers in v0.52.0 and v0.54.2: each tool reports a confident verdict computed from a different section, and no run compares them. Delete the local definition and source lib.sh."
        elif [ "$sources_lib" -eq 0 ] \
          && printf '%s\n' "$fcode" | grep -qE "(^|[^a-zA-Z0-9_])${fn}([[:space:]]|\$)"; then
          err "I21 reconcile/$fbase calls ${fn}() but never sources reconcile/lib.sh. The call resolves to nothing at runtime, and these scripts run on a consumer's pull — where the resulting empty section reads as 'no drift' rather than as an error. Add: . \"\$SELF/lib.sh\""
        fi
      done
    done
  fi
fi

# --- I22: every model-token role file is a declared setup-substitution site.
#
# `reconcile/setup-sites.md` is the SINGLE SOURCE OF TRUTH for "this looks like core
# divergence but is actually consumer config". A `{*_model_*}` token that is not listed
# there is not masked during the core-overwrite step, so a pull that touches the file
# writes the placeholder back over the consumer's live `/model` string. The role then
# dispatches against a literal `{reviewer_escalated_model_personal}` and the failure
# surfaces far from the pull that caused it.
#
# This has now shipped TWICE, and the first time it did the damage. `adversary.md`
# carried a model token from v0.30.0 (3727f68) and was not declared a site until
# v0.47.0 (e86cd9e) — seventeen versions, and that commit's own title is "the
# reconcile blanked the config it exists to preserve". Then v0.84.0 added
# `code-reviewer-escalated.md` carrying two tokens, wired it into ai-dlc-setup
# STEP 2, and again never added the manifest entries — caught only because a
# consumer's pull happened to preserve its live values and it reported the gap.
#
# The manifest's authoring rule says every entry MUST trace to a "Files to replace in"
# directive in ai-dlc-setup/SKILL.md. That rule is one-directional: it stops entries
# being invented, but nothing walked the other way and asked whether a file carrying a
# token had an entry. A hand-maintained list is the recurring bug here (I8's site table,
# I12's scan set), so DERIVE the subject set from the tokens on disk.
#
# Direction matters: a file with a token and no entry is the data-loss bug. A file with
# an entry and no token is harmless (a stale entry simply never matches), so this asserts
# one containment, not set equality.
SITES_MD="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/setup-sites.md"
if [ ! -f "$SITES_MD" ]; then
  err "I22 cannot find core/skills/ai-dlc-update/reconcile/setup-sites.md. The check that keeps every model token maskable just went vacuous — it must locate the manifest or fail loudly, never pass by finding nothing to compare."
else
  # NOT-sites carve-out: the party-persona roles are spawned by /bmad-party-mode, which
  # controls their model, so an ai-dlc token there would be inert. Derived from the
  # manifest's own "Explicitly NOT sites" section rather than restated here.
  not_sites="$(sed -n '/^## Explicitly NOT sites/,$p' "$SITES_MD" | grep -oE '`[a-z-]+\.md`' | tr -d '`' | sort -u)"
  declared="$(grep -oE 'core/team-roles/[a-z-]+\.md' "$SITES_MD" | sort -u)"
  tokened="$(grep -rlE '\{[a-z_]*model[a-z_]*\}' "$REPO_ROOT"/core/team-roles/*.md 2>/dev/null | sed "s|^$REPO_ROOT/||" | sort -u)"
  if [ -z "$tokened" ]; then
    err "I22 found no {*_model_*} tokens in core/team-roles/. Either the token form changed or the role files were emptied; either way this assertion is now testing nothing and would pass against a tree whose every model site is unlisted."
  else
    for tf in $tokened; do
      tbase="$(basename "$tf")"
      printf '%s\n' "$not_sites" | grep -qx "$tbase" && continue
      if ! printf '%s\n' "$declared" | grep -qx "$tf"; then
        err "I22 $tf carries a {*_model_*} token but setup-sites.md declares no site for it. On the next pull that touches this file the mask/reinject step will not know the token is consumer config, so it overwrites the consumer's live /model string with the placeholder and the role dispatches against a literal token. This is the adversary.md nine-version gap and the code-reviewer-escalated.md gap. Add the site entries, or list the file under 'Explicitly NOT sites' with the reason it carries an inert token."
      fi
    done
  fi
fi

# --- Verdict ------------------------------------------------------------------
if [ "$fail" -eq 0 ]; then
  n="$(printf '%s\n' "$map_ids" | grep -c .)"
  echo "OK: enforcement-map.yaml in sync with gate-validation.md ($n catalog checks), all bindings live, core_manifest copies match, drift-scan set bound (I12), every fixture driven or declared undrivable (I20), reconcile helpers single-homed (I21), every model token a declared setup site (I22)."
  exit 0
fi
exit 1
