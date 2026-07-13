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
#                         does not exist, while the catalog claims coverage.
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

miss_install="$(comm -23 <(printf '%s\n' "$on_disk") <(printf '%s\n' "$in_install"))"
[ -n "$miss_install" ] && err "fixture(s) in core/fixtures/ that install.sh never ships (so no consumer has them): $(echo $miss_install)"
ghost_install="$(comm -13 <(printf '%s\n' "$on_disk") <(printf '%s\n' "$in_install"))"
[ -n "$ghost_install" ] && err "install.sh ships fixture(s) that do not exist in core/fixtures/: $(echo $ghost_install)"
drift_uninstall="$(comm -3 <(printf '%s\n' "$in_install") <(printf '%s\n' "$in_uninstall") | tr -d '\t')"
[ -n "$drift_uninstall" ] && err "install.sh and uninstall.sh fixture loops disagree (uninstall would orphan or over-remove): $(echo $drift_uninstall)"

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
  # <core dir>|<the destination install.sh writes>. Every core/ subtree the installer
  # ALSO places must be listed, or the catch-all silently invents a second home for it.
  # Both entries here were live bugs: fixtures landed in .claude/fixtures/ (dead, while
  # H1 reads tests/fixtures/) and ci-templates in .claude/ci-templates/ (dead, while
  # workflows run from .github/workflows/ — which is why a real consumer's CI gates sat
  # dormant and never once fired).
  while IFS='|' read -r cdir dest; do
    [ -n "$cdir" ] || continue
    got="$(maps_to "core/$cdir/PROBE")"
    [ "$got" = "$dest/PROBE" ] || err "the pull and the installer disagree on where core/$cdir/ goes: map_consumer() sends it to '$got', install.sh writes '$dest/'. The consumer gets two copies at two paths, and the one the pull keeps fresh is not the one anything reads."
  done <<'SITES'
fixtures|tests/fixtures
ci-templates|.github/workflows
SITES
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

# --- Verdict ------------------------------------------------------------------
if [ "$fail" -eq 0 ]; then
  n="$(printf '%s\n' "$map_ids" | grep -c .)"
  echo "OK: enforcement-map.yaml in sync with gate-validation.md ($n catalog checks), all bindings live, core_manifest copies match."
  exit 0
fi
exit 1
