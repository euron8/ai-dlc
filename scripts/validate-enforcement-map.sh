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
#   I43 consumer machinery home is ONE string — the directory the core-guard tells an author
#                         to put their own pipeline tooling in was hand-written in five shipped
#                         surfaces and declared in none, joined by nothing. Both directions: no
#                         core file names a scripts/ai-dlc* path other than core's own home and
#                         the declared one, AND the guard's deny text still routes to the declared
#                         home. A home no affordance points at is one no author finds.
#   I44 core never writes the home — core-manifest.md and the guard both promise, in those
#                         words, that core "never reads, never writes and never overwrites" it.
#                         Nothing asserted it. Derived from install.sh/uninstall.sh's targets and
#                         the core_manifest globs, with a positive control so a broken extractor
#                         cannot report the same clean result as a correct one.
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

# Defined here rather than at I5 because I8 below needs it too, and I5's own use is
# further down the file. Pure function; its only input is $1.
norm_core_manifest() {
  awk '
    /^core_manifest:/ {f=1; next}
    f && /^  - / {v=$0; sub(/^  - /,"",v); print v; next}
    f {f=0}
  ' "$1" | sed -E 's#^core/skills/ai-dlc/##; s#^core/##' | sort -u
}

# --- I8: fixture packaging (core/fixtures == install loop == uninstall loop ==
# --- core_manifest's fixtures/ entries) ---------------------------------------
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
# fixture is NOT expected in install.sh's loop.
#
# The exemption is not self-certifying: a dist-only fixture must ALSO be absent from
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
  printf '%s\n' "$in_install" | grep -qx "$f" && err "fixture '$f' carries a .dist-only marker but install.sh ships it. Either delete the marker or stop shipping it — as written, it is excused from the install/uninstall sync check for no reason."
  [ -d "$REPO_ROOT/core/fixtures/$f" ] || err "fixture '$f' carries a .dist-only marker but does not exist in core/fixtures/ — stale marker."
done

shippable="$(comm -23 <(printf '%s\n' "$on_disk") <(printf '%s\n' "$DIST_ONLY"))"
miss_install="$(comm -23 <(printf '%s\n' "$shippable") <(printf '%s\n' "$in_install"))"
[ -n "$miss_install" ] && err "fixture(s) in core/fixtures/ that install.sh never ships (so no consumer has them): $(echo $miss_install)"
ghost_install="$(comm -13 <(printf '%s\n' "$on_disk") <(printf '%s\n' "$in_install"))"
[ -n "$ghost_install" ] && err "install.sh ships fixture(s) that do not exist in core/fixtures/: $(echo $ghost_install)"
drift_uninstall="$(comm -3 <(printf '%s\n' "$in_install") <(printf '%s\n' "$in_uninstall") | tr -d '\t')"
[ -n "$drift_uninstall" ] && err "install.sh and uninstall.sh fixture loops disagree (uninstall would orphan or over-remove): $(echo $drift_uninstall)"

# The manifest CLAIMS these fixtures for the core layer, and the claim must equal the
# set a consumer actually RECEIVES -- which is $shippable above, already computed and
# already bound to both install loops. One derivation, four readers: a .dist-only marker
# or an install-loop edit moves all of them together, so the manifest's fixture entries
# cannot become a fifth hand-list. Both directions:
#
#   a shipped fixture with NO entry -> ai-dlc-core-guard.sh permits an in-place edit to
#     upstream test data, and Check 16 audits it as consumer-authored -- a marker in a
#     core fixture becomes a gate FAIL whose only remediation VACATES the fixture,
#     because those markers are the payload its own assertions read.
#   an entry with no shippable fixture -> the guard denies edits to a path no consumer
#     has, and a deny that protects nothing reads as protection.
#
# core-manifest.md alone is sufficient: I5 binds the second copy to it.
cm_fixtures="$(norm_core_manifest "$CORE_MANIFEST" | sed -n 's#^fixtures/\(.*\)/\*\*$#\1#p' | sort -u)"
miss_entry="$(comm -23 <(printf '%s\n' "$shippable") <(printf '%s\n' "$cm_fixtures"))"
[ -n "$miss_entry" ] && err "fixture(s) install.sh ships to every consumer with NO core_manifest entry, so the core guard permits an in-place edit to upstream test data and Check 16 audits it as consumer-authored: $(echo $miss_entry). Add 'fixtures/<name>/**' to BOTH manifest copies."
ghost_entry="$(comm -13 <(printf '%s\n' "$shippable") <(printf '%s\n' "$cm_fixtures"))"
[ -n "$ghost_entry" ] && err "core_manifest claims fixture(s) that are not shippable — dist-only, or absent from core/fixtures/: $(echo $ghost_entry). The guard would deny edits to a path no consumer has, and a deny that protects nothing reads as protection."

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

# --- I36/I37/I38: the layer contract is joined to its enforcers, both ways -----
# THE STATE THESE MAKE UNREPRESENTABLE. Measured at v0.180.0: the consumer layer contract was
# 41 clauses across four files, of which SEVENTEEN had no enforcer — three saying so in their
# own prose. Both reporters returned 0 errors / 0 warnings on a tree carrying real violations.
# A contract nothing can fail is this repo's named defect class one level up from a check.
#
# The join is on a token the enforcer ALREADY emits (`E1`..`W4`, or a literal pull-time status),
# so nothing had to be sprinkled into a script to make it work and there is no second vocabulary
# to hand-sync. That is what lets I36 run in BOTH directions.
# PATH IS OVERRIDABLE so a fixture can mutate the CONTRACT without writing into the repo it is
# validating. It cannot be used to weaken the gate: I36's reverse direction requires every code
# the real enforcers emit to be claimed, so a stripped-down substitute fails louder than the
# original, not quieter. The enforcers and prose homes are always resolved against $REPO_ROOT.
lc_file="${AI_DLC_LAYER_CONTRACT:-$REPO_ROOT/core/skills/ai-dlc/layer-contract.yaml}"
if [ ! -f "$lc_file" ]; then
  err "I36 cannot find the layer contract at $lc_file. A scan over nothing reads exactly like agreement — the file is core_manifest machinery and must exist."
else
  # Parse the clause table. Three fields per clause; a clause missing any of them is I37's
  # subject, not a parse error to swallow.
  lc_ids="$(awk '/^  - id:/{print $3}' "$lc_file")"
  lc_n="$(printf '%s\n' "$lc_ids" | grep -c . )"
  if [ "$lc_n" -eq 0 ]; then
    err "I36 read ZERO clauses out of layer-contract.yaml. The contract cannot be empty and a zero here would make I36/I37/I38 all pass vacuously — the exact shape they exist to forbid."
  fi

  # --- I41: a clause id is unique. ------------------------------------------------------
  # HOW THIS SHIPPED. v0.187.0 added LC-O12 and v0.192.0 added a SECOND one, and the build
  # stayed green through both. Every existing invariant keys on something else: I36 joins on
  # `code:` (unique), I37 on the presence of three fields, I38 greps the prose home for the id
  # as a SUBSTRING — so two clauses sharing an id satisfy I38 on one line of prose. The id was
  # the one field nothing checked, which is why it was the one field that collided.
  #
  # It is not cosmetic. The id is the only handle a report, a CHANGELOG or an operator has for
  # naming which clause fired, and `overrides/README.md` had carried both under one label since
  # v0.192.0 — the reader-facing side of the contract had two different rules with one name. It
  # is also the key row 11's disposition register is specified to use, per (entry, clause, digest).
  #
  # The collision hid because the file is NOT in numeric order: LC-O12 sat ABOVE LC-O10 and
  # LC-O11, so an author appending after LC-O11 counted forward and landed on a taken number
  # without it ever appearing adjacent. Ordering is not the fix; a mechanism is.
  lc_dupes="$(printf '%s\n' "$lc_ids" | grep . | sort | uniq -d | tr '\n' ' ')"
  if [ -n "$lc_dupes" ]; then
    err "I41: layer-contract.yaml declares the same clause id more than once — ${lc_dupes% }. The id is the only name a report, a README or an operator has for a clause, so two clauses under one id make every citation of it ambiguous and let one clause satisfy I38 on the other's prose. Renumber the collision; the id space is append-only, so take the next free number rather than reordering the file."
  fi

  # --- I42: no clause is introduced at a contract_version the contract has not reached. --
  # `since:` is the whole retro-application rule — an entry declaring `conforms_to: N` is held
  # only to clauses with `since <= N` — and a clause with `since` ABOVE `contract_version` can
  # never satisfy that for any conforming entry. It is a clause that cannot fire wearing a
  # version number, which is this repo's named defect class at contract grain.
  #
  # MEASURED WHEN THIS WAS ADDED: contract_version was 2 while THREE clauses declared `since: 3`
  # (both LC-O12s and LC-O13). v0.183.0 set the 2; v0.187.0 and v0.192.0 each wrote a 3 past it.
  # Nothing read either field, so nothing objected — `conforms_to` has no reader anywhere in the
  # tree to this day, and that gap is recorded separately. This invariant does not create the
  # reader; it stops the declaration from drifting into a state no reader could ever honour.
  #
  # A missing `since:` or an unparseable `contract_version` is an ERROR, not a skip: either one
  # would let this scan pass by finding nothing.
  lc_cv="$(awk '/^contract_version:/{print $2; exit}' "$lc_file")"
  case "$lc_cv" in
    ''|*[!0-9]*)
      err "I42 cannot read a numeric contract_version out of layer-contract.yaml (got '${lc_cv:-<none>}'). Every clause's since: is compared against it, so an unreadable value would retire this check silently rather than failing it." ;;
    *)
      lc_i42="$(awk -v cv="$lc_cv" '
        /^  - id:/    { if (id != "") check(); id=$3; since=""; next }
        /^    since:/ { since=$2; next }
        END           { if (id != "") check() }
        function check() {
          if (since == "")                      printf "%s has no since:; ", id
          else if (since ~ /[^0-9]/)            printf "%s since %s is not a number; ", id, since
          else if (since + 0 > cv + 0)          printf "%s since %s > contract_version %s; ", id, since, cv
        }
      ' "$lc_file")"
      if [ -n "$lc_i42" ]; then
        err "I42: layer-contract.yaml carries a clause the contract's own version has not reached — $lc_i42 An entry declaring 'conforms_to: N' is held only to clauses with since <= N, so a clause above contract_version binds nobody. Bump contract_version in the same release that introduces the clause."
      fi ;;
  esac

  # --- I37: no prose-only clause. A clause must name a level, an enforcer and a code. ---
  # This is the invariant that keeps the seventeen-unenforced state out. `enforcement: pending`
  # is not a permitted value anywhere, deliberately: a placeholder is the same
  # declaration-without-a-mechanism defect wearing a new file's clothes.
  lc_i37="$(awk '
    /^  - id:/          { if (id != "") check(); id=$3; lvl=""; enf=""; code=""; next }
    /^    level:/       { lvl=$2; next }
    /^    enforcer:/    { enf=$2; next }
    /^    code:/        { code=$2; next }
    END                 { if (id != "") check() }
    function check() {
      if (lvl == "")  printf "%s has no level:; ", id
      if (enf == "")  printf "%s has no enforcer:; ", id
      if (code == "") printf "%s has no code:; ", id
      if (lvl != "" && lvl != "ERROR" && lvl != "WARN")
        printf "%s level %s is not ERROR or WARN; ", id, lvl
    }
  ' "$lc_file")"
  if [ -n "$lc_i37" ]; then
    err "I37: layer-contract.yaml carries a clause with no mechanism — $lc_i37 Every clause states level + enforcer + code, or it is prose pretending to be a rule, which is the state this contract was created to end. Ship the clause WITH its enforcer, or leave it in the CHANGELOG backlog until you have one."
  fi

  # --- I36 forward: every clause names a code its declared enforcer actually emits. ---
  while IFS='|' read -r cid cenf ccode; do
    [ -n "$cid" ] || continue
    if [ ! -f "$REPO_ROOT/$cenf" ]; then
      err "I36 $cid: declared enforcer '$cenf' does not exist. A clause bound to a missing script is unenforced with a citation, which reads better than nothing and is worth less."
    elif ! grep -qF -- "$ccode" "$REPO_ROOT/$cenf"; then
      err "I36 $cid: '$cenf' never emits the code '$ccode' this clause claims. The clause cannot fire, and a clause that cannot fire reads exactly like one that passed. Fix the code, or point the clause at the script that does emit it."
    fi
  done <<EOF
$(awk '
  /^  - id:/       { if (id != "") emit(); id=$3; enf=""; code="" ; next }
  /^    enforcer:/ { enf=$2; next }
  /^    code:/     { code=$2; next }
  END              { if (id != "") emit() }
  function emit() { if (enf != "" && code != "") printf "%s|%s|%s\n", id, enf, code }
' "$lc_file")
EOF

  # --- I36 reverse: every code an enforcer emits is claimed by exactly one clause. ---
  # THE DIRECTION THAT ACTUALLY CATCHES DRIFT. Forward-only, a new status could ship with no
  # clause and the contract would still build green — which is how a status reaches an operator
  # with no stated rule behind it, and how the seventeen-clause gap grew in the first place.
  #
  # The `*-OK` statuses are excluded by a DERIVED suffix rule, not a hand-list: an `-OK` row is
  # a clean state, not a finding, so it has no clause to state. A hand-list of exceptions here
  # would be the restated-enumeration defect I26 exists for.
  lc_claimed="$(awk '/^    code:/{print $2}' "$lc_file" | sort -u)"
  lc_declared_enf="$(awk '/^    enforcer:/{print $2}' "$lc_file" | sort -u)"
  for enf in $lc_declared_enf; do
    [ -f "$REPO_ROOT/$enf" ] || continue
    case "$enf" in
      *validate-layer-entries.sh) emitted="$(grep -oE '\b(E[1-9]|W[1-9])\b' "$REPO_ROOT/$enf" | sort -u)" ;;
      *layer-drift.sh)            emitted="$(grep -oE '\b(HARD-[A-Z0-9-]+|OVERRIDE-[A-Z0-9-]+|EXTENSION-[A-Z0-9-]+)\b' "$REPO_ROOT/$enf" | sort -u | grep -v -- '-OK$')" ;;
      *)                          emitted="" ;;
    esac
    if [ -z "$emitted" ]; then
      err "I36 reverse: found NO codes in declared enforcer '$enf'. Either the extraction pattern no longer matches that script's vocabulary or the script changed shape; a zero here silently retires this whole direction of the join."
    fi
    for code in $emitted; do
      if ! printf '%s\n' "$lc_claimed" | grep -qxF -- "$code"; then
        err "I36 reverse: '$enf' emits '$code' but NO clause in layer-contract.yaml claims it. An operator can be handed that verdict with no stated rule behind it. Add the clause, or stop emitting the code."
      fi
    done
  done

  # --- I38 forward: every clause id appears in the prose home it declares. ---
  # ONLY the forward direction ships, and the reason is measured. (It was written when the
  # contract was at version 1 and said so; the number was never updated across two bumps, which
  # is a small instance of exactly what I42 now guards — do not restate a version in prose.) The
  # reverse direction — every normative sentence carries a clause id — has no sound predicate
  # yet: a keyword scan (MUST|NEVER|never|cannot|only) over the two layer READMEs matches 26
  # lines against 10 real clauses, and the structural form is worse, because the two files do
  # not share one: all 10 bold-led clause bullets are in extensions/README.md and
  # overrides/README.md has ZERO, stating its clauses as prose paragraphs and section headings.
  # A structural predicate would therefore be unable to fire on half its subject. Normalising
  # that prose is a separate change; until then the reverse direction would be a lint with an
  # unmeasured false-positive set, which is the one this repo forbids shipping.
  while IFS='|' read -r cid chome; do
    [ -n "$cid" ] || continue
    if [ ! -f "$REPO_ROOT/$chome" ]; then
      err "I38 $cid: declared prose_home '$chome' does not exist."
    elif ! grep -qF -- "$cid" "$REPO_ROOT/$chome"; then
      err "I38 $cid: '$chome' never mentions '$cid'. The contract points a reader at prose that does not carry the clause, so the human-readable side and the enforced side have already diverged."
    fi
  done <<EOF
$(awk '
  /^  - id:/         { if (id != "") emit(); id=$3; home="" ; next }
  /^    prose_home:/ { home=$2; next }
  END                { if (id != "") emit() }
  function emit() { if (home != "") printf "%s|%s\n", id, home }
' "$lc_file")
EOF
fi

# --- I39: the ledger status vocabulary is one set across emitter and rulebook --
# THE STATE THIS MAKES UNREPRESENTABLE. `ledger-reverify.sh`'s statuses are a contract with
# three readers that do not check each other: the operator following SKILL.md step 3f, the
# report heading in emit-report.sh, and any consumer script grepping the TSV. Nothing joined
# them. Renaming a status in the emitter alone left step 3f documenting a token no run can
# produce and — the silent half — a status reaching an operator with no entry in the step that
# tells them what to do with it. Both halves read exactly like a complete rename.
#
# MEASURED at v0.186.0, renaming the `NAMED-*` status: five statuses emitted, five documented,
# the two sets equal, and the false-positive set of this predicate EMPTY. The bound matters —
# the same bullet grammar over the WHOLE of SKILL.md matches 20 tokens, 15 of them other
# detectors' statuses, so the reverse direction is scoped to step 3f's own span. Widening it
# would need those detectors joined too, and their emission styles are not uniform (layer-drift
# emits through variables), which is a zero waiting to happen in the extraction rather than a
# finding. One script, one uniform `emit <LITERAL>` style, both directions.
lr_file="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/ledger-reverify.sh"
lr_skill="$REPO_ROOT/core/skills/ai-dlc-update/SKILL.md"
if [ ! -f "$lr_file" ] || [ ! -f "$lr_skill" ]; then
  err "I39 cannot find ledger-reverify.sh or its ai-dlc-update/SKILL.md. A scan over a missing file reads exactly like agreement; both are core_manifest machinery and must exist."
else
  lr_emitted="$(grep -oE '^[[:space:]]*emit [A-Z][A-Z0-9-]+' "$lr_file" | awk '{print $2}' | sort -u)"
  lr_documented="$(awk '/^3f\. \*\*/{on=1} on && /^[0-9]+\. \*\*/{exit} on' "$lr_skill" \
    | grep -oE '^[[:space:]]*- `[A-Z][A-Z0-9-]+` →' | grep -oE '[A-Z][A-Z0-9-]+' | sort -u)"
  # Either side coming back empty is the failure this check exists to prevent, not a pass:
  # an extraction that has stopped matching reports agreement between two empty sets.
  if [ -z "$lr_emitted" ]; then
    err "I39 found NO statuses in ledger-reverify.sh. Either the emitter no longer uses 'emit <STATUS>' or the script changed shape; a zero here silently retires the whole check."
  elif [ -z "$lr_documented" ]; then
    err "I39 found NO documented statuses in ai-dlc-update/SKILL.md step 3f. Either the step was renumbered or its bullet grammar changed; a zero here silently retires the whole check."
  else
    for st in $lr_emitted; do
      printf '%s\n' "$lr_documented" | grep -qxF -- "$st" || \
        err "I39: ledger-reverify.sh emits '$st' but SKILL.md step 3f never documents it. The operator is handed a verdict the step that governs the ledger does not explain, which is how a status reaches a pull with no stated handling."
    done
    for st in $lr_documented; do
      printf '%s\n' "$lr_emitted" | grep -qxF -- "$st" || \
        err "I39: SKILL.md step 3f documents '$st' but ledger-reverify.sh never emits it. The step describes a row no run can produce — an operator waiting on a signal that cannot arrive reads it as 'nothing to do'."
    done
    # The heading emit-report.sh renders is the third reader, and it names a SUBSET by design
    # (the rows the operator acts on). A subset is checkable without hand-listing it: every
    # status the heading names must be one the emitter still produces.
    er_file="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/emit-report.sh"
    if [ -f "$er_file" ]; then
      for st in $(grep -oE 'Push-candidate ledger — [A-Z][A-Z0-9 /-]+' "$er_file" \
                  | grep -oE '\b[A-Z][A-Z0-9-]*-[A-Z][A-Z0-9-]*\b' | sort -u); do
        printf '%s\n' "$lr_emitted" | grep -qxF -- "$st" || \
          err "I39: emit-report.sh's push-candidate heading names '$st', which ledger-reverify.sh does not emit. The report promises the operator a section that can never have rows in it."
      done
    fi
  fi
fi

# --- I35: H1's fixture criterion states I20's contract, not a stricter one ----
# H1 is LLM-read at every gate and had RESTATED this contract instead of stating the
# property: it required a `README.md` and a `seed.sh` of every bound fixture, and
# attributed that to "the validate-enforcement-map.sh I20 contract". I20 requires
# neither. It requires a DRIVER, falling back to a README that declares why one is
# impossible. The restatement was strictly tighter than the mechanism it cited, and
# core itself violates it: 44 of 73 fixtures ship no README and 26 no seed.sh, all of
# them correct, all of them a gate FAIL under the old prose. A consumer hit it on two
# core-owned fixtures it cannot edit, behind a P0 fix.
#
# The marker is the joinable part: H1 tells the reader which string declares the
# exemption, and if I20's marker moves, H1 sends them looking for a string no README
# carries and compliant fixtures start failing. Bind the two, same shape as I15/I18/I34.
# The rest of the criterion is prose an LLM reads; this pins the one literal in it.
em_marker="$(sed -n "s/^EXEMPT_MARKER='\(.*\)'$/\1/p" "$REPO_ROOT/scripts/validate-enforcement-map.sh" | head -1)"
gv_file="$REPO_ROOT/core/skills/ai-dlc/steps/gate-validation.md"
if [ -z "$em_marker" ]; then
  err "I35 cannot read EXEMPT_MARKER out of validate-enforcement-map.sh. The check binding H1's stated exemption marker to I20's just went vacuous — it must locate the marker or fail loudly, never pass by finding nothing."
elif [ ! -f "$gv_file" ]; then
  err "I35 cannot find gate-validation.md at $gv_file. A scan over nothing reads exactly like agreement."
elif ! grep -qF -- "$em_marker" "$gv_file"; then
  err "I35: H1 in gate-validation.md does not quote I20's exemption marker '$em_marker'. H1 is read by an LLM at every gate and tells it which declaration makes a driverless fixture legitimate; if that string does not match the one I20 enforces, H1 sends the reader looking for text no README carries and FAILs compliant fixtures. Quote the marker verbatim in H1's fixture criterion, or change both together."
fi

# --- I34: ONE rule grammar. The SAME split as I15, in the RULE namespace. -----
# `validate-layer-entries.sh` (W4) REPORTS an extension rule number colliding with core's;
# `relabel-extension-checks.sh` FIXES it by writing the `[ext:<id>]` label. Two programs,
# one grammar. If the reporter's is wider, it names a collision the fixer cannot rewrite and
# the operator is handed a remedy that does not run — which is how the CHECK label went
# unadopted for three releases and is exactly the failure I15 was added for.
#
# Separate from I15 on purpose. ANCHOR_RE matches `### 24.` and terminates on `[.—]`; a rule
# heading is `### Rule 29 -- Steering budget` and has no terminator, so ANCHOR_RE matches
# 0 of core's 30 rules. Folding the word `Rule` into ANCHOR_RE would merge `Rule 29` and
# check `29` into one id and start joining two unrelated catalogs by integer.
rg_lint="$(sed -n 's/^RULE_RE=//p' "$REPO_ROOT/core/scripts/validate-layer-entries.sh" | head -1)"
rg_relabel="$(sed -n 's/^RULE_RE=//p' "$REPO_ROOT/core/skills/ai-dlc-update/reconcile/relabel-extension-checks.sh" | head -1)"
if [ -z "$rg_lint" ] || [ -z "$rg_relabel" ]; then
  err "I34 cannot find a RULE_RE definition in validate-layer-entries.sh and/or relabel-extension-checks.sh. The check that binds the two rule grammars just went vacuous — it must locate both or fail loudly, never pass by finding nothing."
elif [ "$rg_lint" != "$rg_relabel" ]; then
  err "the rule grammar has forked: validate-layer-entries.sh defines RULE_RE=$rg_lint but relabel-extension-checks.sh defines RULE_RE=$rg_relabel. The linter REPORTS rule-number collisions and relabel FIXES them; a narrower grammar in either means a reported collision no tool can resolve. Make them byte-identical."
fi

# --- I25: the core-path derivation is ONE rule, in two places, byte-identical --
# `hooks/ai-dlc-core-guard.sh` decides at EDIT time whether a path is core (and
# denies the write). `scripts/core-paths.sh` answers the same question for callers
# that are not a hook -- Check 16's stub audit asks it whether a marker sits in an
# upstream-owned file, because a core file can satisfy none of the four elements
# (no consumer backlog item can be added to a file the guard forbids editing).
#
# Same shape as I18, and the same reason it is a COPY rather than a source: the
# guard must stay self-contained. A guard that sources a helper stops denying core
# writes entirely when that helper is missing from a partial install -- it fails
# open, silently, and a disabled write guard is far worse than a duplicated
# 25-line parser. The duplication is only safe because this assertion exists: two
# copies bound byte-for-byte cannot drift, one copy with a fragile load path can
# vanish. If these two ever disagree, the edit-time guard and the gate-time check
# classify the same file differently -- the gate exempts what the guard protects,
# or the guard denies what the gate audits.
cp_fn() { awk "/^$2\(\) \{/,/^\}/" "$1" 2>/dev/null; }
CP_GUARD="$REPO_ROOT/core/hooks/ai-dlc-core-guard.sh"
CP_LIB="$REPO_ROOT/core/scripts/core-paths.sh"
for cp_f in parse_manifest to_consumer_glob; do
  cp_a="$(cp_fn "$CP_GUARD" "$cp_f")"
  cp_b="$(cp_fn "$CP_LIB" "$cp_f")"
  if [ -z "$cp_a" ] || [ -z "$cp_b" ]; then
    err "I25 cannot find a ${cp_f}() definition in ai-dlc-core-guard.sh and/or core-paths.sh. The check binding the edit-time and gate-time core-path rules just went vacuous — it must locate both or fail loudly, never pass by finding nothing."
  elif [ "$cp_a" != "$cp_b" ]; then
    err "the core-path derivation has forked between ai-dlc-core-guard.sh and core-paths.sh at ${cp_f}(). One denies edits to core, the other tells Check 16 which files are core; a rule that differs between them means a file the guard protects can be audited as consumer-authored, or a file the gate exempts can still be edited. Make ${cp_f}() byte-identical."
  fi
done

# --- I40: ONE reading of an anchor, across the linter and the pull classifier ---
# `core/scripts/validate-layer-entries.sh` ERRORs at authoring time on an anchor that resolves
# only by the reverse containment arm; `reconcile/layer-drift.sh` reports the same shape at pull
# time. They must agree about three things, and each disagreement has already shipped:
#
#   nrm_awk        is this the SAME heading? Three spellings existed — two awk copies in the
#                  linter and one inline in lib.sh's span_of — of the normalizer that every
#                  anchor join in the repo rests on.
#   shadow_parts   WHAT does this entry shadow? The linter read only the first comma-part
#                  (nineteen anchor instances unvalidated), then read every part but computed
#                  the file per part (the file-inheriting spelling skipped entirely, 1 of 4
#                  anchors checked); the classifier read ONE file for the whole entry and
#                  checked every anchor against it.
#   anchor_arm     WHICH DIRECTION resolved it? A narrower copy in either tool reports a loose
#                  anchor the other calls fine, and the operator believes whichever they ran.
#
# COPIES rather than a source, for I25's reason and I29's: core/scripts must not depend on the
# update skill, and I29 confines ai-dlc-update to reconcile/, so neither may source the other's
# file. The duplication is only safe because this assertion exists.
la_fn() { awk "/^$2\(\) \{/,/^\}/" "$1" 2>/dev/null; }
LA_LINT="$REPO_ROOT/core/scripts/validate-layer-entries.sh"
LA_LIB="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/lib.sh"
for la_f in nrm_awk anchor_arm shadow_parts; do
  la_a="$(la_fn "$LA_LINT" "$la_f")"
  la_b="$(la_fn "$LA_LIB" "$la_f")"
  if [ -z "$la_a" ] || [ -z "$la_b" ]; then
    err "I40 cannot find a ${la_f}() definition in validate-layer-entries.sh and/or reconcile/lib.sh. The check binding the authoring linter's anchor reading to the pull classifier's just went vacuous — it must locate both or fail loudly, never pass by finding nothing."
  elif [ "$la_a" != "$la_b" ]; then
    err "the anchor reading has forked between validate-layer-entries.sh and reconcile/lib.sh at ${la_f}(). The linter ERRORs at authoring time and the classifier reports at pull time; a copy that differs means the two disagree about what an entry shadows or about which heading an anchor names, and the operator believes whichever they happened to run. Make ${la_f}() byte-identical."
  fi
done

# --- I29: ai-dlc-update names no helper that is not in reconcile/ ---------------
# The skill's HARD CONSTRAINT is that it reads only its own reconcile/ files, which is why
# setup-sites.md carries a duplicate manifest at all. A step that tells the reader to use a
# helper living outside reconcile/ is not a wrong path -- it is an instruction to violate the
# constraint, and the reader's fallback is to hand-write what the helper would have done.
# Shipped once: step 2 said "Both helpers are in reconcile/" of map_consumer() (true) and
# to_consumer_glob() (in core/scripts/core-paths.sh and core/hooks/ai-dlc-core-guard.sh).
# Bind the claim to the directory rather than trusting prose.
UPD_SKILL="$REPO_ROOT/core/skills/ai-dlc-update/SKILL.md"
UPD_RECON="$REPO_ROOT/core/skills/ai-dlc-update/reconcile"
if [ ! -r "$UPD_SKILL" ] || [ ! -d "$UPD_RECON" ]; then
  err "I29 cannot read core/skills/ai-dlc-update/SKILL.md and/or its reconcile/ dir. A check that cannot locate either side scans nothing and reports clean."
else
  # Every `name()` the skill cites in backticks, that reconcile/ does not define.
  #
  # CARVE-OUT, deliberately narrow: a paragraph opening `Do NOT reach for` is a PROHIBITION,
  # not a citation -- it exists to stop the next author re-adding the bad instruction, and
  # naming the helper is the whole point of it. Citations there are skipped, and only there:
  # the exemption is one opening phrase and ends at the next blank line, so it cannot be
  # stretched to excuse a real citation.
  upd_missing=""
  while IFS= read -r fn; do
    [ -n "$fn" ] || continue
    grep -rqE "^[[:space:]]*(function[[:space:]]+)?${fn}\(\)" "$UPD_RECON" 2>/dev/null || upd_missing="$upd_missing $fn"
  done <<EOF
$(awk '/Do NOT reach for/{skip=1} skip&&/^[[:space:]]*$/{skip=0} !skip' "$UPD_SKILL" \
   | grep -oE '`[a-z_][a-z0-9_]*\(\)`' | tr -d '`()' | sort -u)
EOF
  if [ -n "$upd_missing" ]; then
    err "I29 ai-dlc-update/SKILL.md cites helper(s) that reconcile/ does not define:${upd_missing}. This skill's HARD CONSTRAINT is that it reads only its own reconcile/ files, so naming a helper from elsewhere instructs the reader to violate it — and the fallback is hand-writing the mapping the helper existed to make derivable. Either move the logic into reconcile/, or state the rule inline and say explicitly that the outside helper must NOT be read."
  fi
fi

# --- I28: layer grain is DECLARED and PARTITIONS the manifest -------------------
# `machinery` (no overrides/ or extensions/ grain) vs `rulebook` (consumer-layerable prose)
# decided three things and was written down in none of them: the core-guard's routing advice,
# and -- the one that bit -- which paths ai-dlc-update's self-update cycle may pull
# autonomously. That cycle pulled `skills/ai-dlc-update/**` plus the fixtures covering it,
# and those fixtures depend on machinery OUTSIDE that slice (core-paths.sh, core-manifest.md),
# so a red derived fixture HARD-STOPPED the self-update on a pull that broke nothing. The
# slice is now the machinery set, which needs the set to exist as data.
#
# PARTITION, not two lists that happen to agree: every non-fixtures/ entry must be in exactly
# one. In neither means a new entry is silently treated as rulebook and never reaches the
# self-update slice -- the same wedge again, one release later. In both means the two readers
# can disagree about the same path. fixtures/ is excluded: test data has no layer grain and
# its enumeration is already derived from core/fixtures/ minus .dist-only (I8).
norm_key() { # <file> <key> -> entries under that key, prefix-normalized like I5
  awk -v k="$2" '
    $0 == k ":" {f=1; next}
    f && /^  - / {v=$0; sub(/^  - /,"",v); print v; next}
    f && /^[^ \t]/ {f=0}
  ' "$1" | sed -E 's#^core/skills/ai-dlc/##; s#^core/##' | sort -u
}
cm_all="$(norm_core_manifest "$CORE_MANIFEST" | grep -v '^fixtures/' | sort -u)"
for lg_k in machinery rulebook; do
  a="$(norm_key "$CORE_MANIFEST" "$lg_k")"
  b="$(norm_key "$SETUP_SITES" "$lg_k")"
  if [ -z "$a" ] || [ -z "$b" ]; then
    err "I28 the '${lg_k}:' list is missing or unparseable in core-manifest.md and/or reconcile/setup-sites.md (found $(printf '%s' "$a" | grep -c . ) and $(printf '%s' "$b" | grep -c . ) entries). Layer grain decides the core-guard's routing and which paths the self-update may pull autonomously; an absent list makes both fall back to a default silently."
  elif [ "$a" != "$b" ]; then
    err "I28 the '${lg_k}:' lists diverge between core-manifest.md and reconcile/setup-sites.md:"
    diff <(printf '%s\n' "$a") <(printf '%s\n' "$b") >&2 || true
  fi
done
mach="$(norm_key "$CORE_MANIFEST" machinery)"
rule="$(norm_key "$CORE_MANIFEST" rulebook)"
lg_both="$(comm -12 <(printf '%s\n' "$mach") <(printf '%s\n' "$rule"))"
[ -n "$lg_both" ] && err "I28 entr(y/ies) declared BOTH machinery and rulebook: $(echo $lg_both). Layer grain is one answer per path; two readers would route the same file differently."
lg_neither="$(comm -23 <(printf '%s\n' "$cm_all") <(printf '%s\n' "$mach" "$rule" | sort -u))"
[ -n "$lg_neither" ] && err "I28 core_manifest entr(y/ies) with NO layer grain declared: $(echo $lg_neither). Add each to machinery: (no overrides/extensions grain — hooks, validators, schemas, templates, the setup/update engines) or rulebook: (consumer-layerable prose). Unclassified defaults to rulebook at every reader, which is how a machinery path silently stops reaching ai-dlc-update's self-update slice."
lg_ghost="$(comm -13 <(printf '%s\n' "$cm_all") <(printf '%s\n' "$mach" "$rule" | sort -u))"
[ -n "$lg_ghost" ] && err "I28 layer grain declared for path(s) that are not core_manifest entries: $(echo $lg_ghost). A grain for a path the manifest does not claim protects nothing and reads as coverage."

# --- I27: the in-flight marker is ONE path, written by apply.sh and read by pre-push --
# A pull writes core one file at a time, so mid-apply the tree is a mixture of two releases
# and its own fixture suite fails in BOTH directions -- a fixture newer than its subject
# asserts behaviour that is not installed, an older one breaks against a newer subject.
# apply.sh marks that state and pre-push refuses the suite while the mark is there.
#
# TWO FILES, ONE STRING. If they name different paths the marker is written and nothing
# reads it: the guard is silently absent and looks exactly like a guard that passed. That
# is the shape v0.55.2's map_consumer() and v0.63.0's drift-scan list both failed in, so
# bind the two ends rather than trusting them to agree.
MK_APPLY="$(sed -nE 's@^APPLYING="\$CONSUMER/(.+)"$@\1@p' \
  "$REPO_ROOT/core/skills/ai-dlc-update/reconcile/apply.sh" | head -1)"
MK_PP="$(sed -nE 's@^if \[ -f (\.[^ ]+) \]; then$@\1@p' \
  "$REPO_ROOT/core/git-hooks/pre-push" | grep 'applying' | head -1)"
if [ -z "$MK_APPLY" ] || [ -z "$MK_PP" ]; then
  err "I27 could not locate the in-flight marker path in apply.sh (\`APPLYING=\`) and/or core/git-hooks/pre-push (\`if [ -f ... ]\`). One end missing means the marker is written with nothing refusing on it, or refused on with nothing writing it — and either way this check just went vacuous. Found apply='${MK_APPLY:-<none>}' pre-push='${MK_PP:-<none>}'."
elif [ "$MK_APPLY" != "$MK_PP" ]; then
  err "I27 the in-flight marker path has forked: apply.sh writes '\$CONSUMER/${MK_APPLY}' but core/git-hooks/pre-push refuses on '${MK_PP}'. The writer and the reader must name the SAME path, or a mid-pull tree runs its own fixture suite and reports failures that are neither a regression nor the consumer's fault."
fi

# --- I26: core-layer-immutability keeps the core set DERIVED, never restated ---
# The check body used to tell the adjudicator to read core-manifest.md "for the
# authoritative path list" and then spell that list out inline. It named 6 of the
# manifest's 12 non-fixture entries, omitting templates/, session-driver/, schemas/,
# both ai-dlc-setup/ and ai-dlc-update/ subtrees, and scripts/ai-dlc/ -- so the retro
# backstop stopped firing on six core subtrees, and the omission read exactly like a
# clean pass. Same failure I24 records for H1's fixture set, in the one check whose
# entire job is a core-manifest intersection.
#
# A COUNT of manifest entries in the span is the wrong detector: the body legitimately
# cites rule-authoring.md for guidance and names hooks/ai-dlc-*.sh for a real
# behavioural carve-out (a changed core hook can have no overrides/ shadow, so it always
# FAILs). What distinguishes a restated LIST is punctuation adjacency -- a list puts the
# entries on one line, a reference stands alone. Measured against the pre-fix text: two
# lines carried three entries each; the fixed text carries at most one per line.
CLI_SPAN="$(awk '/<!-- CHECK_LOADED: core-layer-immutability -->/{on=1} on{print} on && /^### /&&!/core-layer-immutability/{exit}' \
  "$REPO_ROOT/core/skills/ai-dlc/steps/gate-validation.md" 2>/dev/null)"
if [ -z "$CLI_SPAN" ]; then
  err "I26 could not isolate the core-layer-immutability span in gate-validation.md. A span that does not resolve scans nothing and reports clean."
elif ! printf '%s\n' "$CLI_SPAN" | grep -q 'core-paths.sh --is-core'; then
  err "I26 the core-layer-immutability check body does not invoke \`core-paths.sh --is-core\`. It must DERIVE the core set from the same resolver the edit-time guard reads, not decide for itself which paths are core — a body that answers that question on its own is the restated list this invariant exists to prevent."
else
  # Entries derived from the manifest, never hand-listed here. Fixtures are excluded:
  # 66 of them would swamp the per-line test and none is a plausible restatement.
  cli_entries="$(norm_core_manifest "$CORE_MANIFEST" | grep -v '^fixtures/')"
  cli_bad=""
  while IFS= read -r cli_line; do
    cli_n=0
    while IFS= read -r cli_e; do
      [ -n "$cli_e" ] || continue
      # A LITERAL SUBSTRING TEST, NOT A FORK. `grep -qF` is the same predicate as a case glob on a
      # quoted variable, and this loop runs (span lines x manifest entries) -- about 2,300 greps per
      # validator run, and this validator runs 20 times inside core/fixtures/enforcement-map-sites/.
      # Measured: 7.18s -> 4.11s per run, output byte-identical, on the largest fixture in the suite.
      case "$cli_line" in *"$cli_e"*) cli_n=$((cli_n+1)) ;; esac
    done <<EOF
$cli_entries
EOF
    [ "$cli_n" -ge 2 ] && cli_bad="${cli_bad}
      ${cli_n} entries on: $(printf '%s' "$cli_line" | cut -c1-80)"
  done <<EOF
$(printf '%s\n' "$CLI_SPAN")
EOF
  if [ -n "$cli_bad" ]; then
    err "I26 the core-layer-immutability check body restates the core path set:${cli_bad}
      A line naming two or more manifest entries is a list, not a cross-reference. The set is DERIVED from core-paths.sh --is-core; a list here rots against the manifest in the one direction that matters, because every entry it omits is a core subtree this check silently stops firing on. It had already omitted six."
  fi
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
# norm_core_manifest() is defined above I8, which needs it too. One definition.
cm="$(norm_core_manifest "$CORE_MANIFEST")"
ss="$(norm_core_manifest "$SETUP_SITES")"
if [ "$cm" != "$ss" ]; then
  err "core_manifest copies diverge (core-manifest.md vs reconcile/setup-sites.md):"
  diff <(printf '%s\n' "$cm") <(printf '%s\n' "$ss") >&2 || true
fi

# --- I43: the consumer machinery home is ONE string across every surface -------
# THE DEFECT. `scripts/ai-dlc-local/` was advertised in FIVE independent hand-written
# spellings and declared in none: the core-guard's deny text routes an author there,
# `reconcile/warn-shadowed-local-validators.sh` defaults `LOCAL_DIR` to it, two fixtures
# write into it, and core-manifest.md said it in prose. Nothing compared them. This is
# the affordance-is-the-defect shape -- the guard PROMISES a home, and the promise was
# the only thing holding the value. A rename in any one surface leaves the guard routing
# authors to a directory the reader never walks, and both halves stay green because each
# is internally consistent.
#
# BOTH DIRECTIONS, and the reverse one is the one that matters:
#   forward  no core file names a `scripts/ai-dlc*` path other than core's own
#            `scripts/ai-dlc` and the declared home. Catches a rename or a second home.
#   reverse  the declared home is actually named by the core-guard's deny text. A home
#            no affordance routes to is one no author finds, so the declaration would be
#            live, self-consistent, and reachable by nobody.
#
# The grammar is `scripts/ai-dlc[A-Za-z0-9_-]*` and its false-positive set over the whole
# distribution is EMPTY: exactly two tokens exist, `scripts/ai-dlc` (458 occurrences) and
# `scripts/ai-dlc-local` (14). Measured before this check was written, per CLAUDE.md.
cmh_decl() { # <file> -> the declared home, trailing slash stripped
  sed -n 's/^consumer_machinery_home:[ \t]*//p' "$1" | head -1 | sed 's#/*$##'
}
CMH="$(cmh_decl "$CORE_MANIFEST")"
CMH_SS="$(cmh_decl "$SETUP_SITES")"
CORE_SCRIPTS_HOME="$(printf '%s\n' "$cm" | grep -E '^scripts/[A-Za-z0-9_-]+/\*$' | sed 's#/\*$##' | head -1)"

if [ -z "$CMH" ] || [ -z "$CMH_SS" ]; then
  err "I43 could not read 'consumer_machinery_home:' from core-manifest.md and/or reconcile/setup-sites.md (got '${CMH:-<none>}' and '${CMH_SS:-<none>}'). Both copies are required: the core-guard routes authors to this path and reconcile/ cannot read core-manifest.md at runtime, so an absent declaration leaves the two ends bound by nothing while this check reports the same line as agreement."
elif [ "$CMH" != "$CMH_SS" ]; then
  err "I43 the consumer machinery home differs between its two declarations — core-manifest.md says '$CMH', reconcile/setup-sites.md says '$CMH_SS'. ai-dlc-update reads its own copy, everything else reads the manifest's, so the guard would route an author to one directory while the reader walks another."
elif [ -z "$CORE_SCRIPTS_HOME" ]; then
  err "I43 could not derive core's own scripts home from the core_manifest entries (expected one 'scripts/<dir>/*' glob). Without it the token scan below cannot tell core's directory from the consumer's, so every occurrence would read as a violation or none would."
else
  # Forward: every scripts/ai-dlc* token in a shipped core file is one of the two homes.
  cmh_bad="$(grep -rhoE 'scripts/ai-dlc[A-Za-z0-9_-]*' \
               "$REPO_ROOT/core" "$REPO_ROOT/scripts" "$REPO_ROOT/templates" "$REPO_ROOT/.githooks" 2>/dev/null \
             | sort -u | grep -vxF "$CORE_SCRIPTS_HOME" | grep -vxF "$CMH" || true)"
  if [ -n "$cmh_bad" ]; then
    err "I43 shipped core file(s) name a scripts/ai-dlc* path that is neither core's own '$CORE_SCRIPTS_HOME' nor the declared consumer machinery home '$CMH': $(echo $cmh_bad). Either the home was renamed in one surface and not the declaration, or a second home was invented. Both leave the core-guard routing authors somewhere no reader walks. Offending file(s):"
    grep -rlE "$(printf '%s' "$cmh_bad" | paste -sd'|' -)" "$REPO_ROOT/core" "$REPO_ROOT/scripts" "$REPO_ROOT/templates" "$REPO_ROOT/.githooks" 2>/dev/null >&2 || true
  fi
  # Zero guard on the forward scan: the grammar must still match core's own home
  # somewhere, or an extraction that stopped matching would report a clean scan.
  if ! grep -rqoE 'scripts/ai-dlc[A-Za-z0-9_-]*' "$REPO_ROOT/core" 2>/dev/null; then
    err "I43's token scan matched NOTHING under core/, not even core's own '$CORE_SCRIPTS_HOME'. The grammar or the search root has moved, and an empty scan passes the forward arm exactly like a clean tree."
  fi
  # Reverse: the guard's deny text must route an author to the declared home.
  CMH_GUARD="$REPO_ROOT/core/hooks/ai-dlc-core-guard.sh"
  if [ ! -f "$CMH_GUARD" ]; then
    err "I43 could not read the core-guard at $CMH_GUARD, so the reverse arm compared nothing. A missing guard is not a passing one."
  elif ! grep -qF "$CMH" "$CMH_GUARD"; then
    err "I43 the declared consumer machinery home '$CMH' appears nowhere in core/hooks/ai-dlc-core-guard.sh. The guard's deny text is the ONLY thing that routes an author to this directory when it refuses a write under core's own scripts home; a declared home nothing points at is an affordance no author ever finds, and it fails silently because the declaration itself stays internally consistent."
  fi
fi

# --- I44: core never reads, never writes and never overwrites the home ---------
# core-manifest.md and the guard's deny text BOTH make this promise in those words.
# Nothing asserted it. A manifest entry or an install.sh target landing under the home
# would make the promise false while every reader of the prose still believes it -- and
# the consumer finds out when a pull clobbers a script it authored.
#
# Derived, not hand-listed: every literal `$PROJECT_ROOT/`-rooted path install.sh and
# uninstall.sh name, plus every core_manifest entry mapped to consumer form.
cmh_targets="$(grep -ohE '\$PROJECT_ROOT/[A-Za-z0-9_./$-]*' "$REPO_ROOT/scripts/install.sh" "$REPO_ROOT/scripts/uninstall.sh" 2>/dev/null \
               | sed 's|^\$PROJECT_ROOT/||' | sort -u)"
cmh_claims="$(printf '%s\n' "$cm" | sed -E '
  s@^team-roles/@.claude/team-roles/@;
  s@^hooks/@.claude/hooks/@;
  s@^session-driver/@.claude/session-driver/@;
  s@^schemas/@.claude/schemas/@;
  s@^skills/@.claude/skills/@;
  s@^fixtures/@tests/fixtures/@;
  s@^git-hooks/@.githooks/@' | sort -u)"
if [ -n "$CMH" ]; then
  if [ -z "$cmh_targets" ]; then
    err "I44 extracted ZERO \$PROJECT_ROOT-rooted targets from install.sh/uninstall.sh. An empty target set contains nothing under the home, so this invariant would pass on a tree that installs straight into it."
  elif ! printf '%s\n' "$cmh_targets" | grep -q "^${CORE_SCRIPTS_HOME:-scripts/ai-dlc}"; then
    err "I44's target extraction no longer sees core's own scripts home among install.sh's targets — the \$PROJECT_ROOT grammar has moved. Without that positive control a broken extractor reports the same clean result as a correct one."
  else
    cmh_hits="$(printf '%s\n%s\n' "$cmh_targets" "$cmh_claims" | sort -u | grep -E "^${CMH}(/|$)" || true)"
    [ -n "$cmh_hits" ] && err "I44 core writes or claims path(s) under the consumer machinery home '$CMH': $(echo $cmh_hits). core-manifest.md and the core-guard's deny text both promise core 'never reads, never writes and never overwrites' this directory, and a consumer that believed the promise has its own script clobbered by the next pull. Move the path out of the home, or retract the promise in both places."
  fi
fi

# I5b lived here until v0.160.0: it asserted the manifest's 27 enumerated validators
# equalled `ls core/scripts/`. The manifest now claims `scripts/ai-dlc/*`, so the
# direction that mattered -- a validator added upstream with no manifest entry, hence
# unguarded at edit time -- is structurally impossible rather than merely checked, and
# an entry with no file cannot occur. What the enumeration could still detect (a
# consumer file squatting in the core directory) measured zero occurrences and is now
# handled at edit time instead: the guard classifies a squatter as core and denies both
# the edit and the Write that would create it. core/fixtures/core-script-boundary/
# assertion 8 asserts that. Nothing else in the repo joined the manifest to
# core/scripts/, so nothing replaced it.

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
# The reason string on each `exempt` row is the review, and it must state a property that
# HOLDS: machinery breaks loudly (not silent prose drift), the update skill self-updates its own
# tree, and test data carries no rule to drift. `fixtures` was exempted as "not consumer-authored"
# until the reference consumer was measured carrying four edited fixture files — the exemption was
# right and its reason was false, which is the shape that survives review by being unread.
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
fixtures|exempt:test data, not layered rulebook — an in-place edit changes no rule the lead obeys and has no overrides/ entry to refile into, and it cannot be silently destroyed: apply writes only the base→theirs diff, where preclassify already buckets a consumer-edited file as BOTH-CHANGED->CLASSIFY
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

  # --- I31: every scan-marked subtree has a DISPOSITION in register-drift.sh -----
  # I12 above makes a scan-marked subtree REPORTABLE. It says nothing about what the operator
  # does next, and the report hands them exactly one command: register-drift.sh. That script
  # recognised `skills/ai-dlc/*` and `team-roles/*`, named a refusal for `hooks/*`, and dropped
  # everything else into `unrecognized core path` — a message that reads like a typo in a path
  # the REPORT ITSELF supplied. Measured: `skills/ai-dlc-setup` and `schemas` are both scan-marked
  # and both landed there, so a consumer with deliberate divergence in either had no sanctioned
  # disposition at all, and the pull re-reported HARD- forever.
  #
  # So bind the second list to the first. The case labels are DERIVED from the script — a hand
  # copy of them here would be the same rot one file over.
  RD="$REPO_ROOT/core/skills/ai-dlc-update/reconcile/register-drift.sh"
  if [ -f "$RD" ]; then
    rd_disposed="$(awk '/^case "\$REL" in/{f=1; next} f && /^esac/{exit} f' "$RD" \
      | grep -oE '^[[:space:]]*[a-z][A-Za-z0-9_./*|-]*\)' \
      | tr -d ' )' | tr '|' '\n' | sed 's#/\*$##' | grep -v '^\*$' | sort -u)"
    if [ -z "$rd_disposed" ]; then
      err "I31: could not parse any case label out of register-drift.sh — the check below would pass on nothing. Fix the parse, do not delete the check."
    else
      no_disp="$(comm -23 <(printf '%s\n' "$scan_policy") <(printf '%s\n' "$rd_disposed"))"
      [ -n "$no_disp" ] && err "I31: these core subtrees are I12 'scan' (so unregistered-drift.sh REPORTS them and the report hands the operator register-drift.sh) but register-drift.sh has no case for them: $(echo $no_disp). They fall to 'unrecognized core path', which reads as a bad path rather than a structural refusal. Give each one a registering case or a NAMED no-grain refusal."
    fi
  fi
fi

# --- I32: a Check 17 skill PIN names the skill its own step file invokes -------
# THE DEFECT. Check 17's arms pin a provenance block to a skill NAME, and the step file that
# runs the evaluation names the skill it INVOKES. Two files, one fact, nothing comparing them.
# v0.169.0 repointed `research-requirements.md` §3 from `/bmad-validate-prd` to `/bmad-prd` and
# left the arm pinning the old name, so the gate would have failed on a correctly-executed run
# — and nothing said so for three minors, because a pin and an invocation look identical when
# read one file at a time.
#
# SCOPED TO `bmad-*` PINS, on a stated and derivable ground. The native `ai-dlc-*` reviews are
# invoked by NO step file by design — team-roles/adversary.md is explicit that a convergence
# review "invoke[s] NO skill", so the story-readiness arm's `ai-dlc-adversary-review` appears in
# zero step files and always would. Measured before this check was written; a literal-invocation
# join over all arms would have fired on it. A prefix is the rule, not a hand-listed exemption.
GV="$REPO_ROOT/core/skills/ai-dlc/steps/gate-validation.md"
PB_SCHEMA="$REPO_ROOT/core/schemas/provenance-block.json"
if [ -f "$GV" ] && [ -f "$PB_SCHEMA" ]; then
  # Arms of Check 17, one per line: "<parenthetical>|<required skill>". Multi-line arms are
  # joined first — `--require-skill` routinely wraps onto the next line.
  arms="$(awk '/<!-- CHECK_LOADED: 17 -->/{on=1} /<!-- CHECK_LOADED: 18 -->/{on=0}
    on && /^- \*\*/ { if (buf != "") print buf; buf=$0; next }
    on && buf != ""  { buf = buf " " $0 }
    END { if (buf != "") print buf }' "$GV" \
    | sed -nE 's/^- \*\*[^(]*\(([^)]*)\).*--require-skill[[:space:]]+`?([A-Za-z0-9._-]+)`?.*$/\1|\2/p')"
  # Step-file basenames, DERIVED from the tree — never a second list to keep in sync.
  step_names="$(cd "$REPO_ROOT/core/skills/ai-dlc/steps" 2>/dev/null && ls *.md 2>/dev/null | sed 's/\.md$//')"
  n_bmad_arms=0
  while IFS='|' read -r hint skill; do
    [ -n "$skill" ] || continue
    case "$skill" in bmad-*) ;; *) continue ;; esac
    n_bmad_arms=$((n_bmad_arms + 1))
    step=""
    for s in $step_names; do
      case "$hint" in *"$s"*) [ ${#s} -gt ${#step} ] && step="$s" ;; esac
    done
    if [ -z "$step" ]; then
      err "I32: Check 17's arm '($hint)' pins '$skill' but its parenthetical names no step file under core/skills/ai-dlc/steps/. The arm has to say which step runs the evaluation, or the pin cannot be joined to anything."
      continue
    fi
    # The step may name the pinned skill or any name the schema records as the same evaluation
    # under a different release's name.
    accepted="$skill $(python3 - "$PB_SCHEMA" "$skill" <<'PY' 2>/dev/null
import json, sys
sup = {k: v for k, v in json.load(open(sys.argv[1])).get("superseded_skills", {}).items() if not k.startswith("$")}
want = sys.argv[2]
print(" ".join(sorted({v for k, v in sup.items() if k == want} | {k for k, v in sup.items() if v == want})))
PY
)"
    hit=0
    for a in $accepted; do
      grep -q -- "$a" "$REPO_ROOT/core/skills/ai-dlc/steps/$step.md" 2>/dev/null && hit=1 && break
    done
    [ "$hit" -eq 1 ] || err "I32: Check 17's '$hint' arm pins --require-skill '$skill', but steps/$step.md never names it (nor any superseded name for it). The gate then fails a correctly-executed run: the step invokes one skill and the pin demands another. Repoint whichever is stale — they are one fact in two files."
  done <<EOF
$arms
EOF
  # NON-VACUITY. Every guard above runs inside the loop, so an arm regex that stops matching
  # scans nothing and reports clean — which is the failure this whole check exists to end.
  [ "$n_bmad_arms" -gt 0 ] \
    || err "I32 matched no bmad-* skill pin in Check 17 at all. Either every arm lost its --require-skill, or the arm grammar changed and this check now compares nothing. 'Nothing to compare' must not read as 'the pins agree'."
fi

# --- I33: a fixture never reaches a core subtree by walking up from a RESOLVED script --
# THE DEFECT. `core/fixtures/story-provenance/run.sh` located the schema as
# `$(dirname "$WRITER")/../schemas/...`. That holds in the distribution, where the writer and
# the schema share a parent, and fails on EVERY consumer, where the install mapping splits
# them: core/scripts/<x> -> <root>/scripts/ai-dlc/<x> while core/schemas/ -> <root>/.claude/
# schemas/. The fixture was green here and red there, and because step 2 requires the derived
# fixtures green BEFORE the push, that red was a permanent stop on the consumer's self-update.
#
# The house pattern is already established and is not this: root the chain at the FIXTURE's own
# self-location and name both layouts explicitly (check-17-counts does), or ask the tool that
# owns the path (`stamp-story-provenance.sh --print-schema`). What must not happen is a second,
# private derivation hanging off a path some other resolver produced.
#
# MEASURED BEFORE WRITING: after the fix, this pattern occurs ZERO times across every
# core/fixtures/**/*.sh. The false-positive set is empty today, which is the only reason this
# is a check rather than a lint nobody can keep green. The subtree list is DERIVED from ls core/.
fx_walk_hits=""
fx_sh_count=0
if [ -d "$REPO_ROOT/core/fixtures" ]; then
  fx_sh_count="$(find "$REPO_ROOT/core/fixtures" -name '*.sh' -type f 2>/dev/null | wc -l | tr -d ' ')"
  for sub in $(ls -d "$REPO_ROOT"/core/*/ 2>/dev/null | sed 's|.*/core/||; s|/$||'); do
    [ "$sub" = "fixtures" ] && continue
    hits="$(grep -rlE "dirname \"\\\$[A-Za-z_][A-Za-z0-9_]*\"\)(/\.\.)+/$sub/" \
      "$REPO_ROOT/core/fixtures" --include='*.sh' 2>/dev/null || true)"
    [ -n "$hits" ] && fx_walk_hits="$fx_walk_hits $(echo $hits | sed "s|$REPO_ROOT/||g")"
  done
  if [ "$fx_sh_count" -eq 0 ]; then
    err "I33 found no *.sh under core/fixtures/ to scan. A scan over nothing reports clean, which is the shape this check exists to end."
  elif [ -n "$fx_walk_hits" ]; then
    err "I33: these fixtures reach a core subtree by walking up from a path another resolver produced:$fx_walk_hits. That parent-sharing holds in core/ and is broken by the install mapping on every consumer, so the fixture goes green here and red there — and step 2 turns a red derived fixture into a permanent stop on the self-update. Root the chain at the fixture's own self-location and name both layouts, or ask the tool that owns the path."
  fi
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
          && printf '%s\n' "$fcode" | grep -qE "(^|[^a-zA-Z0-9_])${fn}([^a-zA-Z0-9_]|\$)"; then
          err "I21 reconcile/$fbase calls ${fn}() but never sources reconcile/lib.sh. The call resolves to nothing at runtime, and these scripts run on a consumer's pull — where the resulting empty section reads as 'no drift' rather than as an error. Add: . \"\$SELF/lib.sh\""
        fi
      done
    done
  fi
fi

# --- I22: every role has a config entry, and every entry resolves.
#
# The role file no longer states a model or an effort — `aiDlcRoles.<role>` in the
# consumer's settings.json does, and `ai-dlc-dispatch-guard.sh` reads it there. Two
# ways that can be silently wrong, and the guard FAILS OPEN on both, so neither
# announces itself at runtime:
#
#   1. A role file with no `aiDlcRoles` entry. The guard finds no model and no effort
#      and binds nothing; that teammate runs on whatever it inherits.
#   2. An entry whose `model` names a key `aiDlcModels` does not define. The key does
#      not resolve, so again nothing is bound.
#
# Both sides are DERIVED — role files off disk, entries out of the shipped template —
# because a hand-maintained list is this repo's recurring bug (I8's site table, I12's
# scan set, and I22's own two earlier escapes).
SETTINGS_TMPL="$REPO_ROOT/templates/settings.json.template"
if [ ! -f "$SETTINGS_TMPL" ]; then
  err "I22 cannot find templates/settings.json.template. The check that keeps every role's model and effort resolvable just went vacuous — it must locate the shipped config or fail loudly, never pass by finding nothing to compare."
else
  role_files="$(ls "$REPO_ROOT"/core/team-roles/*.md 2>/dev/null | xargs -n1 basename 2>/dev/null | sed 's/\.md$//' | sort -u)"
  declared="$(jq -r '.aiDlcRoles // {} | keys[]' "$SETTINGS_TMPL" 2>/dev/null | sort -u)"
  model_keys="$(jq -r '.aiDlcModels // {} | keys[]' "$SETTINGS_TMPL" 2>/dev/null | sort -u)"

  if [ -z "$role_files" ]; then
    err "I22 found no role files in core/team-roles/. Either the directory moved or it was emptied; either way this assertion is testing nothing."
  elif [ -z "$declared" ]; then
    err "I22 templates/settings.json.template declares no aiDlcRoles entries. Every role would dispatch with no model and no effort bound, silently, because ai-dlc-dispatch-guard.sh fails open on a missing entry. Restore the block."
  elif [ -z "$model_keys" ]; then
    err "I22 templates/settings.json.template declares no aiDlcModels keys, so no role's model can resolve. Restore the block."
  else
    for r in $role_files; do
      printf '%s\n' "$declared" | grep -qx "$r" \
        || err "I22 core/team-roles/$r.md ships but templates/settings.json.template has no aiDlcRoles entry for '$r'. A consumer installing fresh gets a role with no model and no effort; the dispatch guard fails open and that teammate runs on whatever it inherits. Add the entry."
    done
    # Every entry's model (when it has one — the party personas legitimately have an
    # effort and no model) must be a key aiDlcModels defines.
    for r in $declared; do
      k="$(jq -r --arg r "$r" '.aiDlcRoles[$r].model // empty' "$SETTINGS_TMPL" 2>/dev/null)"
      [ -n "$k" ] || continue
      printf '%s\n' "$model_keys" | grep -qx "$k" \
        || err "I22 aiDlcRoles.$r names model key '$k' but aiDlcModels does not define it. The key does not resolve, so ai-dlc-dispatch-guard.sh binds no model for that role and takes its fail-open branch. Add the key, or point the role at one that exists."
    done
    # Effort is injected into the dispatch prompt as a `/effort <level>` directive, so
    # an unrecognised level would instruct a teammate to run a command that does not
    # exist. The guard drops one rather than passing it through; catch it here instead
    # of shipping a value that is silently ignored.
    for r in $declared; do
      e="$(jq -r --arg r "$r" '.aiDlcRoles[$r].effort // empty' "$SETTINGS_TMPL" 2>/dev/null)"
      [ -n "$e" ] || continue
      case "$e" in
        low|medium|high|xhigh|max) ;;
        *) err "I22 aiDlcRoles.$r declares effort '$e', which is not one of low/medium/high/xhigh/max. ai-dlc-dispatch-guard.sh drops an unrecognised level rather than injecting a directive for a command that does not exist, so that role would silently run at the session default." ;;
      esac
    done
  fi
fi

# --- I22b: the guard reads the blocks the template actually ships ---------------
# I22 checks the CONTENT of the config. Nothing checked that the guard still looks
# where that content lives. The hook resolves two top-level blocks by name; rename
# either in the template (or in the hook) and the lookups return empty, the guard
# takes its fail-open branch, and EVERY role dispatches unbound — with the suite
# green, because every other assertion here reads the template directly and would
# still pass. Bind the two ends: the block names are read OUT OF THE HOOK, never
# restated, and must exist in the shipped template.
DG_HOOK="$REPO_ROOT/core/hooks/ai-dlc-dispatch-guard.sh"
if [ ! -f "$DG_HOOK" ]; then
  err "I22b cannot find core/hooks/ai-dlc-dispatch-guard.sh."
elif [ ! -f "$SETTINGS_TMPL" ]; then
  : # I22 already reported the missing template
else
  blocks="$(grep -oE "\.aiDlc[A-Za-z]+\[" "$DG_HOOK" | sed 's/^\.//; s/\[$//' | sort -u)"
  if [ -z "$blocks" ]; then
    err "I22b found no .aiDlc*[...] lookup in ai-dlc-dispatch-guard.sh. Either the hook stopped reading its config or the lookup changed shape; either way this assertion can no longer tell which blocks the guard depends on and would pass without comparing anything."
  else
    for b in $blocks; do
      jq -e --arg b "$b" 'has($b)' "$SETTINGS_TMPL" >/dev/null 2>&1 \
        || err "I22b ai-dlc-dispatch-guard.sh reads the '$b' block but templates/settings.json.template does not ship one. Every lookup against it returns empty, the guard fails open, and every role dispatches with nothing bound — silently. Rename one end or the other, not just one."
    done
  fi
fi

# --- I24: H1's fixture set stays DERIVED, never restated in gate-validation.md --
# H1 used to carry a hand-typed check->fixture enumeration. It listed 7 checks while
# the map bound 11, so four checks shipped fixtures H1 could not see and the omission
# read exactly like coverage. The list is gone and the map is the single source; this
# asserts it does not grow back, and that every fixture the map names is one a check
# actually claims.
H1_SPAN="$(awk '/<!-- CHECK_LOADED: H1 -->/{on=1} on{print} on && /<!-- CHECK_LOADED: H2 -->/{exit}' \
  "$REPO_ROOT/core/skills/ai-dlc/steps/gate-validation.md" 2>/dev/null)"
if [ -z "$H1_SPAN" ]; then
  err "I24 could not isolate the H1 span in gate-validation.md. A span that does not resolve scans nothing and reports clean."
else
  # H1's OWN fixture is exempt: it proves H1's manifest-completeness pass, so naming it
  # is a self-test reference, not a restatement of the coverage set H1 reads from the map.
  # Derived from the map's H1 entry, never hand-listed here.
  own_fx="$(awk '/^  - id: "H1"/{on=1} on && /fixtures:/{print; exit}' \
    "$REPO_ROOT/core/skills/ai-dlc/enforcement-map.yaml" | grep -oE 'tests/fixtures/[a-z0-9-]+' | sort -u)"
  restated="$(printf '%s\n' "$H1_SPAN" | grep -oE 'tests/fixtures/[a-z0-9-]+' | sort -u \
    | { [ -n "$own_fx" ] && grep -vxF "$own_fx" || cat; })"
  if [ -n "$restated" ]; then
    err "I24 the H1 check body names fixture path(s) directly: $(echo $restated). H1's check->fixture set is derived from enforcement-map.yaml's \`fixtures:\` bindings; a path restated here is the hand-maintained list growing back, and it is what let Checks 2, 2a, 25 and 26 ship fixtures H1 could not see. Cite the map, not the path. (H1's own bound fixture is exempt.)"
  fi
  # And the reverse direction: a fixture bound in the map must exist on disk. I4 already
  # covers this for enforcer paths; this closes it for the fixture bindings H1 now reads.
  for fx in $(grep -oE 'tests/fixtures/[a-z0-9-]+' "$REPO_ROOT/core/skills/ai-dlc/enforcement-map.yaml" | sed 's|tests/fixtures/||' | sort -u); do
    [ -d "$REPO_ROOT/core/fixtures/$fx" ] \
      || err "I24 enforcement-map.yaml binds fixture '$fx' but core/fixtures/$fx does not exist. H1 reads these bindings as its coverage set, so a dangling one is a check reporting coverage it does not have."
  done
fi

# --- I23: every SHIPPED rule-prose file is in the audit corpus -----------------
# audit-rule-files.sh enforces Rule 18 and rule-authoring.md over a corpus it
# builds itself. Nothing compared that corpus to the set install.sh delivers, so
# a rule file could ship to every consumer while being scanned by nothing, and
# the audit would report CLEAN over it. Both sides are DERIVED: the shipped set
# from install.sh's own copy paths, the corpus from `--list`.
AUDIT_SH="$REPO_ROOT/core/scripts/audit-rule-files.sh"
INSTALL_SH="$REPO_ROOT/scripts/install.sh"
if [ ! -f "$AUDIT_SH" ] || [ ! -f "$INSTALL_SH" ]; then
  err "I23 cannot run: audit-rule-files.sh or install.sh is missing. A skipped corpus check reads exactly like a covered corpus."
else
  corpus_list="$(cd "$REPO_ROOT" && bash core/scripts/audit-rule-files.sh --list 2>/dev/null | sort -u)"
  if [ -z "$corpus_list" ]; then
    err "I23 audit-rule-files.sh --list returned nothing from the distribution root. The corpus builder cannot see the distribution layout, so every class it reports is scanned over zero files."
  else
    rule_prose="$(cd "$REPO_ROOT" && ls core/skills/ai-dlc/*.md core/skills/ai-dlc/steps/*.md \
                    core/skills/ai-dlc/templates/*.md core/skills/ai-dlc/extensions/*.md \
                    core/skills/ai-dlc/overrides/*.md core/team-roles/*.md \
                    core/skills/ai-dlc-setup/SKILL.md core/skills/ai-dlc-update/SKILL.md \
                    core/skills/ai-dlc-update/reconcile/*.md patterns/*.md 2>/dev/null | sort -u)"
    unshipped=""
    for rp in $rule_prose; do
      base="$(basename "$rp")"; dir="$(dirname "$rp")"
      # A skill-root file is matched by basename only: every skill-root path shares
      # the `core/skills/ai-dlc/` prefix, so a directory match there would call the
      # whole directory shipped and the check would assert nothing.
      if [ "$dir" = "core/skills/ai-dlc" ]; then
        grep -qF -- "$base" "$INSTALL_SH" || { unshipped="$unshipped $rp"; continue; }
      else
        grep -qF -- "$dir/" "$INSTALL_SH" || grep -qF -- "$base" "$INSTALL_SH" \
          || { unshipped="$unshipped $rp"; continue; }
      fi
      printf '%s\n' "$corpus_list" | grep -qx -- "$rp" \
        || err "I23 $rp is installed into every consumer but is absent from the audit-rule-files.sh corpus. Rule 18 and rule-authoring.md are unenforced over it, and the audit reports CLEAN having never opened it. Add it to the corpus builder."
    done
    for rp in $unshipped; do
      echo "  note: $rp is a rule-prose file that install.sh never ships; it is correctly outside the audit corpus." >&2
    done
  fi
fi

# --- I30: the two pre-push syntax globs are one set, mapped ---------------------
# A shipped script with a syntax error is a gate that cannot run at all, so both hooks
# run `bash -n` over every class of shipped script. The two lists are the same set
# expressed in two layouts, and nothing compared them: core validators moved to
# scripts/ai-dlc/ in v0.126.0, the distribution glob followed, the consumer glob did
# not. For four releases no shipped core validator -- and no part of the update engine
# that would deliver the fix -- was syntax-checked on any consumer, while the step
# printed the same green line either way.
#
# DERIVE the consumer set from the distribution set through the same map_consumer()
# apply.sh uses, and compare. A hand-kept pair is the bug; the pair is derivable.
syn_globs() { # <hook file> -> one glob per line, from the sentinel-bounded block
  # Join backslash continuations FIRST. A line-at-a-time reader drops every entry
  # after the first wrap, and it drops them from BOTH hooks alike -- so the compare
  # succeeds on two equally-truncated sets and reports agreement it never tested.
  # That is the exact vacuity this invariant is here to prevent, so it must not be
  # the way this invariant is implemented.
  sed -n '/# SYNTAX_GLOB_BEGIN/,/# SYNTAX_GLOB_END/p' "$1" \
    | awk '{ if (sub(/\\$/,"")) { printf "%s", $0 } else { print } }' \
    | sed -n 's/.*for f in \(.*\); *do.*/\1/p' \
    | tr -s ' \t' '\n' | grep -E '\*' | sort -u
}
PP_DIST="$REPO_ROOT/.githooks/pre-push"
PP_CONS="$REPO_ROOT/core/git-hooks/pre-push"
if [ ! -f "$PP_DIST" ] || [ ! -f "$PP_CONS" ]; then
  err "I30 could not read one of the pre-push hooks (dist='$PP_DIST' consumer='$PP_CONS'). With one end missing this invariant compares nothing and prints the same line as a pass."
else
  syn_dist="$(syn_globs "$PP_DIST")"
  syn_cons="$(syn_globs "$PP_CONS")"
  if [ -z "$syn_dist" ] || [ -z "$syn_cons" ]; then
    err "I30 parsed ZERO globs out of the syntax_all() block in $( [ -z "$syn_dist" ] && echo '.githooks/pre-push' || echo 'core/git-hooks/pre-push' ). The SYNTAX_GLOB_BEGIN/END sentinels or the \`for f in\` shape changed. An empty set compares equal to an empty set, so this invariant fails closed rather than reporting agreement it never checked."
  else
    # map_consumer(), same rules as reconcile/preclassify.sh:66-75.
    syn_expect="$(printf '%s\n' "$syn_dist" | sed -E '
      s@^core/scripts/@scripts/ai-dlc/@;
      s@^core/fixtures/@tests/fixtures/@;
      s@^core/ci-templates/@.github/workflows/@;
      s@^core/git-hooks/@.githooks/@;
      s@^core/@.claude/@' | sort -u)"
    if [ "$syn_expect" != "$syn_cons" ]; then
      only_dist="$(comm -23 <(printf '%s\n' "$syn_expect") <(printf '%s\n' "$syn_cons") | tr '\n' ' ')"
      only_cons="$(comm -13 <(printf '%s\n' "$syn_expect") <(printf '%s\n' "$syn_cons") | tr '\n' ' ')"
      err "I30 the pre-push syntax globs have forked. Classes the distribution checks but no consumer does:${only_dist:- <none>}. Classes only the consumer checks:${only_cons:- <none>}. A class missing from the consumer hook is a class of shipped script that reaches every consumer with no syntax check, and the step prints the same green line as a full scan. Update core/git-hooks/pre-push's SYNTAX_GLOB block to the mapped image of the distribution's."
    fi
  fi
fi

# --- Verdict ------------------------------------------------------------------
if [ "$fail" -eq 0 ]; then
  n="$(printf '%s\n' "$map_ids" | grep -c .)"
  echo "OK: enforcement-map.yaml in sync with gate-validation.md ($n catalog checks), all bindings live, core_manifest copies match, drift-scan set bound (I12), every fixture driven or declared undrivable (I20), reconcile helpers single-homed (I21), every role has a resolvable aiDlcRoles entry (I22) whose blocks the dispatch guard actually reads (I22b), every shipped rule file in the audit corpus (I23), H1 fixture set derived not restated (I24), core-path derivation byte-identical across guard and resolver (I25), core-layer-immutability derives the core set rather than restating it (I26), the mid-pull marker is one path across writer and reader (I27), layer grain declared and partitioning the manifest (I28), ai-dlc-update cites no helper outside reconcile/ (I29), both pre-push syntax globs one mapped set (I30), every scan-marked core subtree has a register-drift disposition (I31), every Check 17 bmad pin names the skill its own step file invokes (I32), no fixture reaches a core subtree by walking up from a resolved script (I33), rule grammar byte-identical across the W4 reporter and the relabeller (I34), H1's fixture criterion quotes I20's exemption marker (I35), every layer-contract clause names a code its enforcer emits and every emitted code is claimed (I36), no clause ships without a mechanism (I37), every clause id appears in its declared prose home (I38), the ledger status vocabulary is one set across its emitter, step 3f and the report heading (I39), the anchor reading is byte-identical across the authoring linter and the pull classifier (I40), every clause id is unique (I41), no clause is introduced above contract_version (I42), the consumer machinery home is one string across every surface that advertises it (I43), and core writes nothing under it (I44)."
  exit 0
fi
exit 1
