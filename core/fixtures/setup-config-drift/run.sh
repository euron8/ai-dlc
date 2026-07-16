#!/usr/bin/env bash
# setup-config-drift/run.sh — prove unregistered-drift.sh's setup-config-region exemption.
#
# THE DEFECT THIS EXISTS TO CATCH. ai-dlc-setup/SKILL.md is overwrite-on-pull core, but it was
# outside the drift detector's scan — so an in-place edit there fell to the both-changed
# classifier, whose default is keep-ours, silently perpetuating the drift the layer system
# forbids. The fix scans it AND exempts the declared STEP 2 model-strategy config region. This
# proves both halves: a config edit (STEP 2) is exempt; an edit to the rest of the wizard is HARD.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

CF="$CONSUMER/.claude/$REL"
BASECONTENT="$WORK/base.md"
git -C "$DIST" show "$BASE:core/$REL" > "$BASECONTENT"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

status_of() { # -> the STATUS token unregistered-drift.sh emits for our file
  bash "$SCRIPT" "$DIST" "$BASE" "$CONSUMER" 2>/dev/null \
    | awk -F'\t' -v f="$REL" '$2==f {print $1; exit}'
}

echo "setup-config-drift:"

# --- Assertion 0: SANITY — clean consumer is CORE-OK -------------------------
cp "$BASECONTENT" "$CF"
s="$(status_of)"
[ "$s" = "CORE-OK" ] && ok "byte-identical consumer → CORE-OK" \
  || { bad "FIXTURE BROKEN — clean consumer is '$s', not CORE-OK; negatives below are meaningless"; echo; echo "setup-config-drift: FIXTURE BROKEN" >&2; exit 2; }

# --- Assertion 1: STEP 2 config edit is EXEMPT (not drift) -------------------
# Rewrite the strategy line inside STEP 2 — a real per-project config choice.
sed 's/- Full: opus for planning roles, sonnet for implementation./- Balanced: opus for lead+architect only, sonnet elsewhere./' "$BASECONTENT" > "$CF"
if ! cmp -s "$BASECONTENT" "$CF"; then
  s="$(status_of)"
  [ "$s" = "CORE-TEMPLATE-SUBSTITUTED" ] && ok "an edit inside STEP 2 (model strategy) → CORE-TEMPLATE-SUBSTITUTED (declared config, exempt)" \
    || bad "a STEP 2 config edit classified '$s', expected CORE-TEMPLATE-SUBSTITUTED — the config region is not being exempted"
else
  bad "FIXTURE STALE: the STEP 2 strategy line did not change (base text drifted)"
fi

# --- Assertion 2: an edit OUTSIDE STEP 2 is HARD drift -----------------------
sed 's/Fixed rulebook prose./Fixed rulebook prose EDITED IN PLACE by the consumer./' "$BASECONTENT" > "$CF"
if ! cmp -s "$BASECONTENT" "$CF"; then
  s="$(status_of)"
  [ "$s" = "HARD-UNREGISTERED-CORE-DRIFT" ] && ok "an in-place edit to STEP 5 (rulebook prose) → HARD-UNREGISTERED-CORE-DRIFT (blocks apply)" \
    || bad "a non-config in-place edit classified '$s', expected HARD-UNREGISTERED-CORE-DRIFT — the drift gate is not firing outside the config region"
else
  bad "FIXTURE STALE: the STEP 5 line did not change"
fi

# --- Assertion 3: RESTORE → CORE-OK -----------------------------------------
cp "$BASECONTENT" "$CF"
s="$(status_of)"
[ "$s" = "CORE-OK" ] && ok "restored consumer → CORE-OK" || bad "restored consumer is '$s', not CORE-OK"

# --- Assertion 4: the STEP 2 site is actually DECLARED ----------------------
SITES="$(dirname "$SCRIPT")/setup-sites.md"
if grep -q "id: setup-model-strategy" "$SITES" && grep -q "'## STEP 2: API Tier and Model Strings'" "$SITES"; then
  ok "setup-sites.md declares the setup-model-strategy heading-block site"
else
  bad "setup-sites.md does not declare the STEP 2 config site — the exemption above rests on nothing"
fi

echo
if [ "$fails" -eq 0 ]; then echo "setup-config-drift: PASS"; exit 0; fi
echo "setup-config-drift: $fails assertion(s) FAILED" >&2
exit 1
