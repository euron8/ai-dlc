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

status_of() { # status_of [rel] -> the STATUS token unregistered-drift.sh emits for that core file
  bash "$SCRIPT" "$DIST" "$BASE" "$CONSUMER" 2>/dev/null \
    | awk -F'\t' -v f="${1:-$REL}" '$2==f {print $1; exit}'
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

# --- Assertion 3b: a SCHEMA edit is scanned and flagged HARD -----------------
# schemas/ is core the consumer must not edit — no {token}, no config region, so any edit is
# silent drift. Proves unregistered-drift.sh actually scans core/schemas/ (the v0.63.2 gap).
SCF="$CONSUMER/.claude/$SCHEMA_REL"
printf '{\n  "schema_id": "FIXTURE v1",\n  "rule": "consumer-loosened-it"\n}\n' > "$SCF"
s="$(status_of "$SCHEMA_REL")"
[ "$s" = "HARD-UNREGISTERED-CORE-DRIFT" ] && ok "an in-place edit to a core schema → HARD-UNREGISTERED-CORE-DRIFT (schemas/ is scanned)" \
  || bad "a schema edit classified '$s', expected HARD — core/schemas/ is not being scanned"
git -C "$DIST" show "$BASE:core/$SCHEMA_REL" > "$SCF"   # restore

# --- Assertion 4: the STEP 2 site is actually DECLARED ----------------------
SITES="$(dirname "$SCRIPT")/setup-sites.md"
if grep -q "id: setup-model-strategy" "$SITES" && grep -q "'## STEP 2: API Tier and Model Strings'" "$SITES"; then
  ok "setup-sites.md declares the setup-model-strategy heading-block site"
else
  bad "setup-sites.md does not declare the STEP 2 config site — the exemption above rests on nothing"
fi

# --- Assertion 5: the substitution INSTRUCTIONS are NOT exempt ---------------
# The span used to run to `## STEP 3`, which swallowed the substitution instructions that
# follow the operator's choice — which files to open, which tokens to fill. Those are rulebook
# prose. Consequence, measured on the reference consumer: the `dev-escalated` / `analyst` /
# `remediator` model-fill blocks are present upstream and absent there, and neither reader
# ever said so.
#
# The edited line deliberately carries NO {token}. The token arm of the exemption is
# independent of the span and exempts any hunk whose base side holds one, so a `{token}` row
# proves nothing about the boundary — it would read as exempt under either declaration. Only a
# token-free instruction line isolates the span.
sed 's|Substitute in the /model directive lines ONLY|EDITED IN PLACE by the consumer|' "$BASECONTENT" > "$CF"
if ! cmp -s "$BASECONTENT" "$CF"; then
  s="$(status_of)"
  [ "$s" = "HARD-UNREGISTERED-CORE-DRIFT" ] && ok "an edit to a substitution INSTRUCTION row → HARD-UNREGISTERED-CORE-DRIFT (outside the narrowed span)" \
    || bad "a substitution-instruction edit classified '$s', expected HARD-UNREGISTERED-CORE-DRIFT — the span still swallows the wizard's fill instructions, so upstream can add a role's model-fill block and no layered consumer receives it"
else
  bad "FIXTURE STALE: the substitution row did not change (seed text drifted)"
fi
git -C "$DIST" show "$BASE:core/$REL" > "$CF"   # restore

# --- Assertion 6: an unresolvable terminator withholds the exemption ---------
# The old code widened the span to EOF when `next_heading` was not found at base — one stale
# anchor became a blanket exemption over the rest of the file, silently. Fail CLOSED instead:
# no exemption, so the drift is reported. Wrong in the recoverable direction.
# The engine is COPIED and the copy is perturbed — the real reconcile/ tree is never written
# to, so an interrupted run cannot leave the distribution dirty.
ENGINE="$WORK/engine"
mkdir -p "$ENGINE" && cp "$(dirname "$SCRIPT")/"* "$ENGINE/" 2>/dev/null
sed "s|next_heading: '\*\*\`.claude/team-roles/architect.md\`:\*\*'|next_heading: '## NO SUCH TERMINATOR EXISTS'|" \
  "$SITES" > "$ENGINE/setup-sites.md"
if ! cmp -s "$SITES" "$ENGINE/setup-sites.md"; then
  sed 's/- Full: opus for planning roles, sonnet for implementation./- Balanced: opus for lead+architect only, sonnet elsewhere./' "$BASECONTENT" > "$CF"
  s="$(bash "$ENGINE/unregistered-drift.sh" "$DIST" "$BASE" "$CONSUMER" 2>/dev/null \
        | awk -F'\t' -v f="$REL" '$2==f {print $1; exit}')"
  [ "$s" = "HARD-UNREGISTERED-CORE-DRIFT" ] && ok "an unresolvable terminator withholds the exemption (fail-closed), never widens the span to EOF" \
    || bad "with an unresolvable terminator the STEP 2 edit classified '$s' — the span is being widened to EOF again, which exempts the whole rest of the file on one stale anchor"
else
  bad "FIXTURE STALE: could not build the broken-terminator mutant — setup-sites.md's next_heading is not the expected line"
fi
git -C "$DIST" show "$BASE:core/$REL" > "$CF"   # restore

# --- BEHIND vs FORKED: the differential ---------------------------------------
#
# Every other status here measures the consumer against BASE, and BASE is the consumer's own
# stamp. A file excluded from apply — by a per-entry acceptance, say — freezes while the stamp
# advances, so its base-relative diff grows with staleness and reads as a fork that grew on its
# own. `absorbed_pct` cannot separate the two: a real fork upstream ignored scores 0 hits, and
# so does a stale file whose "added" lines are old upstream text upstream has since rewritten.
# On the reference consumer that produced three consecutive pulls of the wrong disposition.
#
# The pair below differ in ONE variable — which upstream blob the consumer's copy is anchored
# at. Assertion 2 above is the other half of this differential and must stay green: a consumer
# at base plus an edit is still DRIFT, because it best-matches base's own blob.
ASSERT_STALE="$(bash "$SCRIPT" "$DIST" "$BASE" "$STALE" 2>/dev/null | awk -F'\t' -v f="$REL" '$2==f {print $1; exit}')"
[ "$ASSERT_STALE" = "HARD-CORE-BEHIND" ] \
  && ok "a copy frozen at an ancestor of base, plus one line of its own → HARD-CORE-BEHIND (remedy is take-theirs, not refile-as-override)" \
  || bad "a stale copy classified '$ASSERT_STALE', expected HARD-CORE-BEHIND — upstream's own change since the old release is being read as consumer drift"

# The DETAIL must carry both numbers. The disposition turns on their RATIO, and an operator
# who sees only the base-relative one adjudicates a fork that is not there.
D="$(bash "$SCRIPT" "$DIST" "$BASE" "$STALE" 2>/dev/null | awk -F'\t' -v f="$REL" '$2==f {print $3; exit}')"
if printf '%s' "$D" | grep -q 'differs from core@.* by [0-9]* lines, but from .* by only [0-9]*'; then
  ok "the row states both distances — against base AND against the ancestor it is really anchored at"
else
  bad "the HARD-CORE-BEHIND detail does not carry both distances; the operator cannot see that the base-relative number is mostly upstream's own change"
fi

echo
if [ "$fails" -eq 0 ]; then echo "setup-config-drift: PASS"; exit 0; fi
echo "setup-config-drift: $fails assertion(s) FAILED" >&2
exit 1
