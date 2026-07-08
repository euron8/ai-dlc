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
