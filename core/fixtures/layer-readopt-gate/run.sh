#!/usr/bin/env bash
# layer-readopt-gate — assert the v0.52.0 landing machinery can actually LAND.
#
# Three properties, each of which fails RED against a real defect that shipped:
#
#   A. `readopt-override.sh --check` catches an override whose body still carries
#      core text upstream has SUPERSEDED. Un-caught, the core fix lands on disk and
#      the lead goes on obeying the old rule out of the override.
#   B. A bare re-stamp is REFUSED while the body is stale. Drift is computed
#      base_sha..theirs, so re-stamping ALONE makes the HARD status evaporate with
#      nothing migrated -- "proceed by doing nothing" wearing a stamp. This is the
#      single most important assertion in the file.
#   C. `unregistered-drift.sh` tells an in-place core rewrite apart from install.sh's
#      template substitution. Getting that wrong in EITHER direction is fatal: miss
#      the rewrite and `apply` silently deletes it; flag the substitution and the
#      check fires on 13 of 13 files on first contact and gets turned off. (It did,
#      in development -- a `$(...)` capture ate the trailing newline and every file
#      read as drift.)
#
# Usage: run.sh [readopt-override.sh] [unregistered-drift.sh]
# Exit:  0 = every assertion holds, 1 = a gate regressed.
set -uo pipefail

# HERMETIC — scrub the operator's tuning before invoking any hook.
#
# A fixture that INHERITS ambient config tests the config, not the code. The hooks honour
# thirteen AI_DLC_* tunables; a consumer that sets any of them in settings.json exports it
# into every session, `git push` inherits it, and the pre-push gate then runs this fixture
# against a hook configured differently from what the assertions assume.
#
# Observed live: a consumer pinned AI_DLC_MODEL_ROW=1M (the documented, sanctioned way to
# declare the model row). Its effective window became 300000 instead of 200000, every
# threshold shifted, and SEVEN assertions failed against a sensor that was behaving exactly
# as specified. The gate blocked every push on the repo. The distribution never caught it
# because the distribution sets none of these -- the check could not fire where it was
# authored.
#
# Unset ALL of them, by pattern, so a NEW tunable cannot reintroduce this. Per-command
# assignments (`AI_DLC_MODEL_ROW=1M "$HOOK"`) still work: those are the deliberate tests.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done


HERE="$(cd "$(dirname "$0")" && pwd)"

pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
READOPT="$(pick "${1:-}" \
  "$HERE/../../skills/ai-dlc-update/reconcile/readopt-override.sh" \
  "$HERE/../../../core/skills/ai-dlc-update/reconcile/readopt-override.sh" \
  "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/readopt-override.sh")"
UNREG="$(pick "${2:-}" \
  "$HERE/../../skills/ai-dlc-update/reconcile/unregistered-drift.sh" \
  "$HERE/../../../core/skills/ai-dlc-update/reconcile/unregistered-drift.sh" \
  "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/unregistered-drift.sh")"

[ -n "$READOPT" ] || { echo "FIXTURE ERROR: cannot locate readopt-override.sh" >&2; exit 2; }
[ -n "$UNREG" ]   || { echo "FIXTURE ERROR: cannot locate unregistered-drift.sh" >&2; exit 2; }

ROOT="$(bash "$HERE/seed.sh")"
DIST="$ROOT/dist"; CONS="$ROOT/consumer"
OVR="$CONS/.claude/skills/ai-dlc/overrides/SKILL__Rule-8.md"
BASE="$(git -C "$DIST" rev-parse --short HEAD~1)"
THEIRS="$(git -C "$DIST" rev-parse --short HEAD)"

fails=0
ok()   { printf '  ok    %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

echo "== A. the stale-core-text gate fires on the real shape =="

out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --check 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && printf '%s' "$out" | grep -q 'STALE-CORE-TEXT'; then
  ok "--check RED: override body carries core text theirs no longer has"
else
  bad "--check did NOT fire on an override copying a superseded core clause (rc=$rc)"
  printf '%s\n' "$out" | sed 's/^/        /'
fi

# The gate must name the actual superseded sentence, not merely exit 1.
if printf '%s' "$out" | grep -q 'more CRITICALs than pass N'; then
  ok "--check names the superseded clause verbatim"
else
  bad "--check fired but did not identify the stale line"
fi

echo "== B. a bare re-stamp is REFUSED while the body is stale =="

before_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$OVR" | head -1)"
out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --stamp readopt 2>&1)"; rc=$?
after_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$OVR" | head -1)"

if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'REFUSED'; then
  ok "--stamp readopt REFUSED while superseded text remains"
else
  bad "--stamp readopt SUCCEEDED on a stale body -- the block can be cleared by doing nothing (rc=$rc)"
fi
if [ "$before_sha" = "$after_sha" ]; then
  ok "base_sha untouched by the refused stamp ($before_sha)"
else
  bad "REFUSED stamp still rewrote base_sha ($before_sha -> $after_sha)"
fi

echo "== B2. reaffirm without a note is REFUSED =="
out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --stamp reaffirm 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'REQUIRES --note'; then
  ok "--stamp reaffirm demands a recorded reason"
else
  bad "--stamp reaffirm accepted with no note -- an unrecorded decision (rc=$rc)"
fi

echo "== C. the gate GOES GREEN once the body is genuinely re-adopted =="

# Re-adopt: carry theirs' clause into the override, keep the consumer's delta.
cat > "$OVR" <<EOF
---
shadows: SKILL.md#Rule 8
base_sha: ${BASE}
reason: consumer-specific validation-intensity table keyed to this repo's service paths.
---

## Rule 8 -- Validation Depth

Validation intensity by path: service/ and infra/ are FULL; scripts/ and docs/ are LIGHT.

**Divergence is a HARD_BLOCK, not a reason for another pass.** If pass N+1
reports more CRITICALs IN THE SCOPE THE PRIOR PASS ALSO REVIEWED
(\`findings_critical_prior_scope\`) than pass N reported in total, the repair step
is injecting defects. CRITICALs in scope the sprint ADDED are NOT divergence.
EOF

out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --check 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then ok "--check green after a real re-adoption"
else bad "--check still red after the body was re-adopted (rc=$rc)"; printf '%s\n' "$out" | sed 's/^/        /'; fi

out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --stamp readopt 2>&1)"; rc=$?
new_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$OVR" | head -1)"
if [ "$rc" -eq 0 ] && [ "$new_sha" = "$THEIRS" ]; then
  ok "--stamp readopt re-stamped base_sha $BASE -> $THEIRS"
else
  bad "--stamp readopt did not re-stamp (rc=$rc, base_sha=$new_sha, want $THEIRS)"
fi

# And the consumer's own delta must have SURVIVED the re-adoption.
if grep -q 'validation-intensity\|Validation intensity' "$OVR"; then
  ok "the consumer's delta survived re-adoption"
else
  bad "re-adoption destroyed the consumer's delta"
fi

echo "== B3. reaffirm must not CORRUPT a multi-line reason: block =="

# A `reason:` is routinely a multi-line YAML block — six of the reference consumer's
# overrides have one, the longest running 99 lines. Appending the note to the `reason:`
# LINE splices it into the middle of a sentence. That shipped, and it corrupted a live
# override. The reason is what the NEXT pull reads to decide "does upstream supersede
# this?"; corrupting it corrupts the record the whole workflow turns on.
ML="$CONS/.claude/skills/ai-dlc/overrides/SKILL__Multiline.md"
cat > "$ML" <<EOF
---
shadows: SKILL.md#Rule 7
base_sha: ${BASE}
reason: The core paragraph claims a thing that is
  not true in this consumer, and the second line
  finishes the sentence.
---
Body.
EOF
bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$ML" --stamp reaffirm --note "still stands" >/dev/null 2>&1

if grep -q 'reason: The core paragraph claims a thing that is$' "$ML"; then
  ok "the reason's first line is INTACT (note not spliced mid-sentence)"
else
  bad "reaffirm mangled the multi-line reason — spliced the note into line 1"
  grep -n '^reason:' "$ML" | sed 's/^/        /'
fi
if grep -q 'finishes the sentence.$' "$ML"; then
  ok "the reason's continuation lines survived"
else
  bad "reaffirm destroyed the reason's continuation lines"
fi
if [ "$(grep -c 'RE-AFFIRMED against' "$ML")" = "1" ] && \
   tail -n +2 "$ML" | awk '/^---$/{exit} {last=$0} END{exit !(last ~ /RE-AFFIRMED/)}'; then
  ok "the note is appended at the END of the reason block"
else
  bad "the note is not at the end of the reason block"
fi
rm -f "$ML"

echo "== C0. --merge re-adopts MECHANICALLY (no hand edit) =="

# The operator must never be told to "merge the new core text in, preserving your
# delta" by hand: that is asking them to run a three-way merge in their head, on prose,
# and a hand-merge is where half an upstream clause gets silently dropped. Re-seed the
# stale override and let --merge do it.
cat > "$OVR" <<EOF
---
shadows: SKILL.md#Rule 8
base_sha: ${BASE}
reason: consumer-specific validation-intensity table keyed to this repo's service paths.
---

## Rule 8 -- Validation Depth

Validation intensity by path: service/ and infra/ are FULL; scripts/ and docs/ are LIGHT.

**Divergence is a HARD_BLOCK, not a reason for another pass.** If pass N+1
reports more CRITICALs than pass N, the repair step is injecting defects faster
than review removes them; another pass only finds the next wave. STOP.
EOF

out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --merge 2>&1)"; rc=$?
if [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'MERGED'; then
  ok "--merge applied upstream's change with no hand edit"
else
  bad "--merge failed (rc=$rc): $out"
fi
if grep -q 'IN THE SCOPE THE PRIOR PASS ALSO REVIEWED' "$OVR"; then
  ok "upstream's new clause is IN the override body"
else
  bad "--merge did not bring upstream's clause into the body"
fi
if grep -q 'Validation intensity by path' "$OVR"; then
  ok "the consumer's delta survived the merge"
else
  bad "--merge destroyed the consumer's delta -- the whole reason the override exists"
fi
if grep -q 'more CRITICALs than pass N' "$OVR"; then
  bad "the superseded clause is STILL in the body after --merge"
else
  ok "the superseded clause is gone"
fi
# And the merged body must now pass the gate it previously failed.
bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --check >/dev/null 2>&1 \
  && ok "--check green after --merge (stamp is now permitted)" \
  || bad "--check still red after --merge -- the merge did not actually clear the block"

echo "== C1. a stamp cannot outrun an unresolved CONFLICT =="

printf '\n<<<<<<< override (yours)\nfoo\n=======\nbar\n>>>>>>> core\n' >> "$OVR"
out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --stamp readopt 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'conflict markers'; then
  ok "--stamp readopt REFUSED while conflict markers remain"
else
  bad "--stamp readopt shipped <<<<<<< into the rulebook the lead reads (rc=$rc)"
fi

echo "== C2. an UNRESOLVABLE anchor fails CLOSED (the vacuous-check hole) =="

# If `shadows:` names an anchor that resolves to no heading, the stale-text test
# compares two EMPTY sections, finds nothing, and reports the body clean. That is a
# check that cannot fail -- gating the very re-stamp it exists to withhold. It must
# refuse, not pass. (Found live: the anchor "Empirical gate validation (the
# `Enforcement:` paragraph)" resolves under layer-drift's matcher but not under a
# naive one, so the gate blocked and its remedy silently cleared the block.)
GHOST="$CONS/.claude/skills/ai-dlc/overrides/SKILL__Ghost.md"
cat > "$GHOST" <<EOF
---
shadows: SKILL.md#Rule 404 -- Does Not Exist
base_sha: ${BASE}
reason: anchor names no heading in core.
---
Body that copies nothing and can be proven safe by nobody.
EOF

out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$GHOST" --check 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'UNDECIDABLE'; then
  ok "--check on an unresolvable anchor: UNDECIDABLE, not 'clean'"
else
  bad "--check reported an unresolvable anchor as clean (rc=$rc) -- a check that cannot fail"
fi

out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$GHOST" --stamp readopt 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'REFUSED'; then
  ok "--stamp readopt REFUSED on an unresolvable anchor"
else
  bad "--stamp readopt cleared a HARD block via a vacuous test (rc=$rc)"
fi

# reaffirm --note is the sanctioned way past it: a human puts their name on it.
out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$GHOST" --stamp reaffirm --note "anchor is legacy; override still stands" 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then ok "--stamp reaffirm --note is the recorded way past an undecidable anchor"
else bad "reaffirm --note could not clear an undecidable anchor (rc=$rc) -- no path out means the gate gets routed around"; fi

rm -f "$GHOST"

echo "== D. unregistered drift vs sanctioned template substitution =="

tsv="$(bash "$UNREG" "$DIST" "$BASE" "$CONS" 2>&1)"

st() { printf '%s\n' "$tsv" | awk -F'\t' -v f="$1" '$2==f {print $1}'; }

if [ "$(st team-roles/tea.md)" = "HARD-UNREGISTERED-CORE-DRIFT" ]; then
  ok "in-place core rewrite (tea.md) -> HARD-UNREGISTERED-CORE-DRIFT"
else
  bad "in-place core rewrite NOT flagged (got '$(st team-roles/tea.md)') -- apply would silently delete it"
fi

if [ "$(st team-roles/dev.md)" = "CORE-TEMPLATE-SUBSTITUTED" ]; then
  ok "install.sh token substitution (dev.md) -> CORE-TEMPLATE-SUBSTITUTED, not drift"
else
  bad "template substitution misread as '$(st team-roles/dev.md)' -- this is the false positive that gets the check turned off"
fi

if [ "$(st skills/ai-dlc/SKILL.md)" = "CORE-OK" ]; then
  ok "untouched core file -> CORE-OK"
else
  bad "untouched core file reported '$(st skills/ai-dlc/SKILL.md)' -- trailing-newline regression is back"
fi

echo "== E. register-drift pulls an in-place edit INTO the layer system =="

# Detecting unregistered drift is half the job. Telling the operator to "refile the
# delta as an override with a base_sha" and leaving them to hand-author the YAML, pick
# the anchor, and copy the right section out is the other half, undone -- and a
# hand-picked anchor that resolves to no heading is how drift detection dies silently.
REG="$(pick "$HERE/../../skills/ai-dlc-update/reconcile/register-drift.sh" \
            "$HERE/../../../core/skills/ai-dlc-update/reconcile/register-drift.sh" \
            "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/register-drift.sh")"
if [ -z "$REG" ]; then
  bad "cannot locate register-drift.sh"
else
  out="$(bash "$REG" "$DIST" "$BASE" "$CONS" team-roles/tea.md --apply 2>&1)"; rc=$?
  NEW="$CONS/.claude/skills/ai-dlc/overrides/team-roles__tea__consumer-drift.md"

  if [ "$rc" -eq 0 ] && [ -f "$NEW" ]; then ok "authored the overrides/ entry"
  else bad "register-drift did not author an override (rc=$rc)"; fi

  # The anchor MUST resolve to a real heading in core, or drift detection is dead
  # for this entry from the day it is written.
  anchor="$(sed -n 's/^shadows:[[:space:]]*//p' "$NEW" 2>/dev/null | sed 's/.*#//; s/,.*//')"
  if [ -n "$anchor" ] && git -C "$DIST" show "${BASE}:core/team-roles/tea.md" | grep -qiF "$anchor"; then
    ok "shadows: anchors to a heading that EXISTS in core (#$anchor)"
  else
    bad "shadows: anchor '#$anchor' resolves to no heading -- drift detection is dead for this entry"
  fi

  # base_sha at BASE, not THEIRS. Stamping theirs would claim the consumer had already
  # read an upstream change it has not.
  b="$(sed -n 's/^base_sha:[[:space:]]*//p' "$NEW" 2>/dev/null)"
  if [ "$b" = "$BASE" ]; then ok "base_sha stamped at BASE (where the delta forked), not THEIRS"
  else bad "base_sha is '$b', want '$BASE' -- stamping theirs claims a read that never happened"; fi

  if grep -q 'Test Architect' "$NEW" 2>/dev/null; then ok "the consumer's text was carried into the override"
  else bad "the consumer's text was not carried into the override -- it is now LOST"; fi

  # core reverted, so the drift is gone
  if [ "$(bash "$UNREG" "$DIST" "$BASE" "$CONS" | awk -F'\t' '$2=="team-roles/tea.md"{print $1}')" = "CORE-OK" ]; then
    ok "core reverted; tea.md is no longer unregistered drift"
  else
    bad "tea.md still reports drift after register-drift --apply"
  fi

  # A hook has no override grain. It must REFUSE, not invent one.
  bash "$REG" "$DIST" "$BASE" "$CONS" hooks/ai-dlc-continue.sh --apply >/dev/null 2>&1
  if [ $? -eq 2 ]; then ok "refuses a HOOK (no override grain exists for hooks)"
  else bad "register-drift invented an override for a hook -- overrides shadow headings, hooks have none"; fi
fi

echo "== F. upstream ABSORBED the consumer's in-place delta =="

# Extensions have had this signal since v0.34.0 (EXTENSION-RETIRE-CANDIDATE). Core drift
# had NO equivalent, so a consumer whose hardening was upstreamed went on being told to
# "refile it as an override, or revert" — with nothing saying the revert was now the
# RIGHT answer. It would have blocked forever on a delta core already carried.
# (Live case: the reference consumer's handoff resume-prompt guard, v0.55.0.)
st_theirs="$(bash "$UNREG" "$DIST" "$BASE" "$CONS" "$THEIRS" | awk -F'\t' '$2=="hooks/guard.sh"{print $1}')"
st_base="$(bash "$UNREG" "$DIST" "$BASE" "$CONS" "$BASE"   | awk -F'\t' '$2=="hooks/guard.sh"{print $1}')"
st_none="$(bash "$UNREG" "$DIST" "$BASE" "$CONS"           | awk -F'\t' '$2=="hooks/guard.sh"{print $1}')"

if [ "$st_theirs" = "HARD-CORE-DRIFT-ABSORBED" ]; then
  ok "upstream absorbed the delta -> HARD-CORE-DRIFT-ABSORBED (remedy: revert, not override)"
else
  bad "absorption NOT detected (got '$st_theirs') — the consumer would be told to refile a delta core already carries, forever"
fi

# The control: at BASE, upstream does NOT have the lines, so it must NOT claim absorption.
# A detector that says 'absorbed' when nothing was absorbed invites the operator to
# DELETE consumer text upstream never took.
if [ "$st_base" = "HARD-UNREGISTERED-CORE-DRIFT" ]; then
  ok "not-yet-absorbed -> plain HARD-UNREGISTERED-CORE-DRIFT (no false 'absorbed')"
else
  bad "claimed absorption against a core that does NOT carry the delta (got '$st_base') — this would delete consumer text"
fi

if [ "$st_none" = "HARD-UNREGISTERED-CORE-DRIFT" ]; then
  ok "no theirs-ref -> old behaviour preserved"
else
  bad "behaviour changed when no theirs-ref is passed (got '$st_none')"
fi

# It must still BLOCK. Absorption changes the recommendation, not who decides: a revert
# deletes consumer content, and only the operator can confirm nothing was lost.
case "$st_theirs" in
  HARD-*) ok "absorption still BLOCKS apply (a revert deletes text; the operator confirms)" ;;
  *)      bad "absorption downgraded out of HARD- — apply would silently delete the consumer's hook" ;;
esac

rm -rf "$ROOT"
echo ""
if [ "$fails" -eq 0 ]; then echo "layer-readopt-gate: PASS"; exit 0; fi
echo "layer-readopt-gate: FAIL ($fails)"; exit 1
