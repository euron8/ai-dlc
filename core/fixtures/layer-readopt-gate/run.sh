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
if [ "$rc" -eq 1 ] && grep -q 'STALE-CORE-TEXT' <<<"$out"; then
  ok "--check RED: override body carries core text theirs no longer has"
else
  bad "--check did NOT fire on an override copying a superseded core clause (rc=$rc)"
  printf '%s\n' "$out" | sed 's/^/        /'
fi

# The gate must name the actual superseded sentence, not merely exit 1.
if grep -q 'more CRITICALs than pass N' <<<"$out"; then
  ok "--check names the superseded clause verbatim"
else
  bad "--check fired but did not identify the stale line"
fi

echo "== B. a bare re-stamp is REFUSED while the body is stale =="

before_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$OVR" | head -1)"
out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --stamp readopt 2>&1)"; rc=$?
after_sha="$(sed -n 's/^base_sha:[[:space:]]*//p' "$OVR" | head -1)"

if [ "$rc" -ne 0 ] && grep -q 'REFUSED' <<<"$out"; then
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
if [ "$rc" -ne 0 ] && grep -q 'REQUIRES --note' <<<"$out"; then
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

echo "== B4. the dossier must RENDER a block-scalar reason, not its indicator =="

# The twin of B3, in the other direction. B3 proved the WRITER tracks a block scalar; the
# READER did not. `fm()` is `… | head -1`, so on `reason: |` it captured the indicator and
# nothing else and the dossier's rationale panel printed a bare `|`. Eight of the reference
# consumer's sixteen overrides declare `reason:` as a block; every one rendered empty.
#
# SKILL.md step 7's retire / readopt / reaffirm decision turns on that field, so the operator
# adjudicated a re-adoption against a blank rationale — and a blank rationale reads as an
# override with no stated purpose, which is an argument for retiring it.
BL="$CONS/.claude/skills/ai-dlc/overrides/SKILL__BlockReason.md"
cat > "$BL" <<EOF
---
shadows: SKILL.md#Rule 7
base_sha: ${BASE}
reason: |
  UNIQUE-BLOCK-SENTINEL the first line of the block.
  And a continuation line that must also survive.
---
Body.
EOF
out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$BL" 2>&1)"
if grep -q 'UNIQUE-BLOCK-SENTINEL' <<<"$out"; then
  ok "the dossier renders a block-scalar reason's text"
else
  bad "the dossier did NOT render the block-scalar reason — step 7's readopt decision turns on a field the operator cannot see"
  printf '%s\n' "$out" | sed -n '/WHY THIS OVERRIDE EXISTS/,+3p' | sed 's/^/        /'
fi
if grep -q 'continuation line that must also survive' <<<"$out"; then
  ok "the block's continuation lines render too (not just line 1)"
else
  bad "the dossier rendered only the block's first line — a 99-line reason still reads as a one-liner"
fi
# Non-vacuity in the other direction: the INLINE form must not regress.
cat > "$BL" <<EOF
---
shadows: SKILL.md#Rule 7
base_sha: ${BASE}
reason: UNIQUE-INLINE-SENTINEL a single-line reason.
---
Body.
EOF
out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$BL" 2>&1)"
if grep -q 'UNIQUE-INLINE-SENTINEL' <<<"$out"; then
  ok "an INLINE reason still renders (the block reader did not break the common path)"
else
  bad "the inline reason stopped rendering — fixing the block form broke the single-line form"
  printf '%s\n' "$out" | head -12 | sed 's/^/        /'
fi
rm -f "$BL"

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
if [ "$rc" -eq 0 ] && grep -q 'MERGED' <<<"$out"; then
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

echo "== C0b. a MULTI-ANCHOR override merges per anchor, not by hand =="

# This used to be `REFUSED ... merge them one at a time by hand`, which routed the
# operator into the exact procedure C0 exists to abolish. It is also disproportionate:
# Rule 7 and Rule 9 are BYTE-IDENTICAL base..theirs, so three of the four anchors need
# no work at all -- only Rule 8 drifted. The differential is that the two unchanged
# sections must come out byte-for-byte, INCLUDING their consumer deltas: a merge that
# re-flows a section core never touched is indistinguishable, in a diff, from one that
# quietly rewrote it.
cat > "$OVR" <<EOF
---
shadows: SKILL.md#Rule 7, SKILL.md#Rule 8, SKILL.md#Rule 9
base_sha: ${BASE}
reason: consumer rewrites of three rule sections; only one of them drifted upstream.
---

Preamble prose no anchor covers. Must survive verbatim.

## Rule 7 -- Something Else

CONSUMER-DELTA-SEVEN kept exactly as written.

## Rule 8 -- Validation Depth

Validation intensity by path: service/ and infra/ are FULL; scripts/ and docs/ are LIGHT.

**Divergence is a HARD_BLOCK, not a reason for another pass.** If pass N+1
reports more CRITICALs than pass N, the repair step is injecting defects faster
than review removes them; another pass only finds the next wave. STOP.

## Rule 9 -- Trailing

CONSUMER-DELTA-NINE kept exactly as written.
EOF

out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --merge 2>&1)"; rc=$?
if [ "$rc" -eq 0 ]; then
  ok "--merge accepted a multi-anchor override (was: REFUSED, exit 2)"
else
  bad "--merge still refuses a multi-anchor override (rc=$rc): $out"
fi
if grep -q '1 merged, 2 unchanged, 0 conflicted' <<<"$out"; then
  ok "only the anchor that drifted was merged (1 merged, 2 unchanged)"
else
  bad "expected '1 merged, 2 unchanged, 0 conflicted', got: $out"
fi
if grep -Fqx 'CONSUMER-DELTA-SEVEN kept exactly as written.' "$OVR" \
   && grep -Fqx 'CONSUMER-DELTA-NINE kept exactly as written.' "$OVR"; then
  ok "the two unchanged sections came out byte-for-byte"
else
  bad "an unchanged section was rewritten -- --merge must not touch what core did not change"
fi
if grep -Fqx 'Preamble prose no anchor covers. Must survive verbatim.' "$OVR"; then
  ok "prose outside every anchor span survived verbatim"
else
  bad "--merge dropped body prose no anchor covers"
fi
if grep -q 'IN THE SCOPE THE PRIOR PASS ALSO REVIEWED' "$OVR" \
   && grep -q 'Validation intensity by path' "$OVR" \
   && ! grep -q 'more CRITICALs than pass N' "$OVR"; then
  ok "the drifted anchor took upstream's clause, kept the delta, dropped the superseded line"
else
  bad "the drifted anchor did not merge correctly"
fi
bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --check >/dev/null 2>&1 \
  && ok "--check green after the multi-anchor merge" \
  || bad "--check still red after the multi-anchor merge"

echo "== C0c. --merge invents no whitespace the file did not have =="

# Found on the reference consumer, NOT here: its override has no blank line after the
# `---` fence, and --merge emitted one because the writer appended a separator
# unconditionally. A whitespace-only edit is still an edit to a file whose promise is that
# untouched sections come out byte-for-byte, and it lands in every reviewer's diff. The
# fixture's other overrides all happen to have that blank, so none of them could see it.
cat > "$OVR" <<EOF
---
shadows: SKILL.md#Rule 7, SKILL.md#Rule 8
base_sha: ${BASE}
reason: no blank line after the fence, and none may be added.
---
FLUSH-PREAMBLE immediately after the fence.

## Rule 7 -- Something Else

CONSUMER-DELTA-SEVEN kept exactly as written.

## Rule 8 -- Validation Depth

**Divergence is a HARD_BLOCK, not a reason for another pass.** If pass N+1
reports more CRITICALs than pass N, the repair step is injecting defects faster
than review removes them; another pass only finds the next wave. STOP.
EOF
before_line10="$(sed -n '6p' "$OVR")"
bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --merge >/dev/null 2>&1
if [ "$(sed -n '5p' "$OVR")" = '---' ] && [ "$(sed -n '6p' "$OVR")" = "$before_line10" ]; then
  ok "no blank line invented after the frontmatter fence"
else
  bad "--merge inserted whitespace after the fence: line 6 was '$before_line10', now '$(sed -n '6p' "$OVR")'"
fi
if [ -n "$(tail -c 1 "$OVR")" ] || [ "$(tail -n 1 "$OVR")" != "" ]; then
  ok "no trailing blank line appended at EOF"
else
  bad "--merge appended a trailing blank line at EOF"
fi

echo "== C1. a stamp cannot outrun an unresolved CONFLICT =="

printf '\n<<<<<<< override (yours)\nfoo\n=======\nbar\n>>>>>>> core\n' >> "$OVR"
out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$OVR" --stamp readopt 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && grep -q 'conflict markers' <<<"$out"; then
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
if [ "$rc" -ne 0 ] && grep -q 'UNDECIDABLE' <<<"$out"; then
  ok "--check on an unresolvable anchor: UNDECIDABLE, not 'clean'"
else
  bad "--check reported an unresolvable anchor as clean (rc=$rc) -- a check that cannot fail"
fi

out="$(bash "$READOPT" "$DIST" "$THEIRS" "$CONS" "$GHOST" --stamp readopt 2>&1)"; rc=$?
if [ "$rc" -ne 0 ] && grep -q 'REFUSED' <<<"$out"; then
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
  if [ -n "$anchor" ] && grep -qiF "$anchor" <<<"$(git -C "$DIST" show "${BASE}:core/team-roles/tea.md")"; then
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

echo "== C3. an override that delegates INTO the section it shadows =="

# Precedence is overrides > extensions > core, so a whole-section shadow deletes every
# construct defined inside that section -- including one the override's own body points
# the lead at. It reads as a correct single-source delegation and behaves as a dropped
# one. Both real instances on the reference consumer were reported OVERRIDE-OK while
# doing exactly this, which is why the two questions must be asked separately.
DRIFT="$(pick "$HERE/../../skills/ai-dlc-update/reconcile/layer-drift.sh" \
              "$HERE/../../../core/skills/ai-dlc-update/reconcile/layer-drift.sh" \
              "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/layer-drift.sh")"
if [ -z "$DRIFT" ]; then
  bad "FIXTURE BROKEN — cannot locate layer-drift.sh; C3 would pass by not running"
else
  ld_out="$(bash "$DRIFT" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>&1)"
  st_of() { printf '%s\n' "$ld_out" | awk -F'\t' -v e="$1" '$2 ~ e {print $1}'; }

  if grep -qx OVERRIDE-DELEGATES-INTO-SHADOW <<<"$(st_of 'SKILL__Rule-10\.md$')"; then
    ok "an override naming a construct defined inside its own shadow is REPORTED"
  else
    bad "the delegation went undetected — every future change to that construct fails to arrive while every check reports green"
  fi

  # THE CONTROL, and it must be able to fail. Same shape, same file, delegating to a
  # construct defined OUTSIDE the shadowed span. Without it the assertion above passes
  # for a detector that flags every override carrying a backticked term.
  if grep -qx OVERRIDE-DELEGATES-INTO-SHADOW <<<"$(st_of 'SKILL__Rule-10-control\.md$')"; then
    bad "an override delegating OUTSIDE its shadow was reported — the detector fires on every legitimate cross-section pointer"
  else
    ok "  and delegating to a construct outside the shadow stays silent"
  fi

  # It answers a DIFFERENT question than the drift arm. Both rows must appear for the
  # same entry: folding this into `worst` would hide it behind an OVERRIDE-OK, which is
  # precisely how both live instances stayed invisible.
  if grep -qx OVERRIDE-OK <<<"$(st_of 'SKILL__Rule-10\.md$')"; then
    ok "  and the entry is STILL OVERRIDE-OK on drift (the two questions are independent)"
  else
    bad "  but the delegation status displaced the drift status — one entry, two questions, two rows"
  fi

  # THE MEASURED FALSE POSITIVE, and the only assertion that can catch its return.
  # When the backticked term is in the ANCHOR heading itself, naming it is
  # self-description, not delegation. Dropping the anchor-heading exclusion re-fires
  # this (1 of 13 on the reference consumer) and every other assertion here stays green.
  if grep -qx OVERRIDE-DELEGATES-INTO-SHADOW <<<"$(st_of 'SKILL__Rule-12-anchor\.md$')"; then
    bad "an override naming a term from the heading it OVERRIDES was reported — the anchor heading is not being excluded, and every self-describing override now fires"
  else
    ok "  and naming a term from the overridden heading itself stays silent"
  fi

  # Report-only. It must not block `apply`, or a consumer cannot take a security fix
  # until it has restructured its own overrides.
  if grep -q DELEGATES <<<"$(printf '%s\n' "$ld_out" | awk -F'\t' '$1 ~ /^HARD-/{print $1}')"; then
    bad "OVERRIDE-DELEGATES-INTO-SHADOW carries a HARD- prefix — it would block apply"
  else
    ok "  and it is report-only, never a blocker"
  fi

  # --- OVERRIDE-ASSERTS-SHADOW-SURVIVES, the sibling status ---------------------------
  # Same mechanism as the delegation arm, opposite failure: that one points the lead at
  # text precedence has removed, this one TELLS the lead the text is still there. Measured
  # on the reference consumer: a bare survival-vocabulary scan matches 5 of 13 overrides
  # with only 2 real; restricting the claim's noun to the shadowed grain takes the
  # false-positive set to zero. The three controls below are those three false positives.
  if grep -qx OVERRIDE-ASSERTS-SHADOW-SURVIVES <<<"$(st_of 'SKILL__Rule-13-survives\.md$')"; then
    ok "an override asserting its own shadowed span survives is REPORTED"
  else
    bad "the survival claim went undetected — the body states something false about its own effect and every check reports green"
  fi

  # THE WRAP, isolated in its own entry so exactly ONE assertion is sensitive to it. The
  # claim splits across a newline between 'Every other part of' and 'Rule 16', where the
  # real instance splits. A line-based predicate returns zero here, which reads identically
  # to compliance. Nothing else in this file would notice the flattening being removed.
  if grep -qx OVERRIDE-ASSERTS-SHADOW-SURVIVES <<<"$(st_of 'SKILL__Rule-16-wrapped\.md$')"; then
    ok "  and a claim WRAPPING across a newline is still found (the body is flattened)"
  else
    bad "  the wrapped claim was missed — a line-based scan reports a false zero on the real shape"
  fi

  # It answers a DIFFERENT question than the drift arm, same as its sibling. Both real
  # instances were OVERRIDE-OK while making the claim.
  if grep -qx OVERRIDE-OK <<<"$(st_of 'SKILL__Rule-13-survives\.md$')"; then
    ok "  and the entry is STILL OVERRIDE-OK on drift (two questions, two rows)"
  else
    bad "  but the survival status displaced the drift status — it would hide behind an OVERRIDE-OK"
  fi

  # CONTROL 1 — the shape the grain warning names as legitimate, and the reason the noun
  # set excludes `file`. An override shadowing ONE section that says the rest of the FILE
  # is unchanged is telling the truth, in the same vocabulary. Widening the predicate to
  # any survival claim re-fires this and every other assertion here stays green.
  if grep -qx OVERRIDE-ASSERTS-SHADOW-SURVIVES <<<"$(st_of 'SKILL__Rule-14-file-claim\.md$')"; then
    bad "an override correctly saying the rest of the FILE is unchanged was reported — the noun restriction is gone and every honest scoping sentence now fires"
  else
    ok "  and a true claim about the rest of the FILE stays silent"
  fi

  # CONTROL 2 — the measured false-positive class: survival vocabulary whose subject is a
  # DIFFERENT named unit, plus a self-reference to the override's own body. Both shapes
  # occur on the reference consumer and both must stay silent.
  if grep -qx OVERRIDE-ASSERTS-SHADOW-SURVIVES <<<"$(st_of 'SKILL__Rule-15-other-unit\.md$')"; then
    bad "an override whose survival claim names a DIFFERENT unit was reported — this is the 3-of-5 false-positive set returning"
  else
    ok "  and survival vocabulary about another unit stays silent"
  fi

  # Report-only, for the same reason as its sibling.
  if grep -q ASSERTS <<<"$(printf '%s\n' "$ld_out" | awk -F'\t' '$1 ~ /^HARD-/{print $1}')"; then
    bad "OVERRIDE-ASSERTS-SHADOW-SURVIVES carries a HARD- prefix — it would block apply"
  else
    ok "  and it is report-only, never a blocker"
  fi

  # --- OVERRIDE-LOOSE-ANCHOR: the pull-time counterpart of E7 --------------------------
  # E7 rejects an anchor that resolves only by the REVERSE arm at AUTHORING time. That
  # validator is consumer-run and skippable; the pull is not, and an anchor finer than a
  # heading silently widens the shadow to the whole section either way.
  #
  # NOT a "mirror of E7". Even now that both read `shadows:` through the same shadow_parts,
  # E7 resolves against the consumer's on-disk core and this resolves against THEIRS — the
  # incoming distribution — so they answer the same question about two different trees.
  if grep -qx OVERRIDE-LOOSE-ANCHOR <<<"$(st_of 'SKILL__Rule-11-loose\.md$')"; then
    ok "an anchor that CONTAINS its heading is REPORTED at pull time"
  else
    bad "the loose anchor went undetected — the entry shadows the whole section while the operator believes it shadowed a paragraph"
  fi

  # CONTROL — the legitimate id-prefix grain, in the same vocabulary. `#Rule 8` naming
  # `## Rule 8 -- Validation Depth` is a consumer naming a rule by its id, and it is what
  # nearly every entry here does. If this fires, the arm has been inverted and every
  # well-formed override in the consumer reports.
  if grep -qx OVERRIDE-LOOSE-ANCHOR <<<"$(st_of 'SKILL__Rule-8\.md$')"; then
    bad "a FORWARD-matching id-prefix anchor was reported loose — the containment direction is inverted and every honest entry now fires"
  else
    ok "  and a FORWARD-matching id-prefix anchor stays silent"
  fi

  if grep -qx OVERRIDE-OK <<<"$(st_of 'SKILL__Rule-11-loose\.md$')"; then
    ok "  and the entry is STILL OVERRIDE-OK on drift (two questions, two rows)"
  else
    bad "  but the loose status displaced the drift status — it would hide behind an OVERRIDE-OK"
  fi

  # --- OVERRIDE-DOUBLE-SHADOW: a finding that exists only ACROSS entries ---------------
  # Each entry is individually well-formed. Precedence resolves the overlap silently, so
  # which body governs is an ordering accident no entry declares, and every commit touching
  # the span invalidates BOTH stamps while reconciling one looks complete.
  ds_a="$(printf '%s\n' "$(st_of 'SKILL__Rule-7-dup-a\.md$')" | grep -cx OVERRIDE-DOUBLE-SHADOW || true)"
  ds_b="$(printf '%s\n' "$(st_of 'SKILL__Rule-7-dup-b\.md$')" | grep -cx OVERRIDE-DOUBLE-SHADOW || true)"
  if [ "$ds_a" -eq 1 ] && [ "$ds_b" -eq 1 ]; then
    ok "two entries claiming one (file, anchor) are BOTH reported"
  else
    bad "double shadow filed under a=$ds_a b=$ds_b (want 1 and 1) — a row under only one of them leaves the other reading clean on the finding it is half of"
  fi

  # CONTROL — a single-claimant anchor. Without this the check could be counting every
  # anchor as its own duplicate and both assertions above would still be green.
  if grep -qx OVERRIDE-DOUBLE-SHADOW <<<"$(st_of 'SKILL__Rule-13-survives\.md$')"; then
    bad "a single-claimant anchor was reported as a double shadow — the key is collapsing entries that do not collide"
  else
    ok "  and an anchor only one entry claims stays silent"
  fi

  # Report-only, and the reason is on the record: the one live instance is DELIBERATE and
  # says so in prose. An ERROR would fire on a case the consumer already reasoned about.
  if grep -qE 'LOOSE-ANCHOR|DOUBLE-SHADOW' <<<"$(printf '%s\n' "$ld_out" | awk -F'\t' '$1 ~ /^HARD-/{print $1}')"; then
    bad "a new pull-time status carries a HARD- prefix — it would block apply on a report-only finding"
  else
    ok "  and both new statuses are report-only, never blockers"
  fi

  # --- MUTANTS: the two discriminators this predicate was MEASURED into ----------------
  # Both are the difference between a shippable check and the 5-of-13 keyword scan that was
  # rejected. Each is a COPY guarded by `cmp -s`, asserts a POSITIVE outcome, and is aimed
  # so that exactly one seeded entry changes verdict -- the others are the proof of that.
  MUTD="$ROOT/mut"; rm -rf "$MUTD"; mkdir -p "$MUTD"
  cp "$(dirname "$DRIFT")"/*.sh "$MUTD/" 2>/dev/null || true

  # THE UNMUTATED CONTROL. Both mutants are copies into a fresh directory; a copy that
  # cannot source lib.sh emits nothing, and "no rows" would otherwise score as a kill for
  # both mutations below.
  cp "$DRIFT" "$MUTD/layer-drift.sh"
  ctl_n="$(bash "$MUTD/layer-drift.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null \
           | awk -F'\t' '$1=="OVERRIDE-ASSERTS-SHADOW-SURVIVES"{c++} END{print c+0}')"
  if [ "$ctl_n" -eq 2 ]; then
    ok "  mutation control: an unmutated copy still reports both seeded claims"
  else
    bad "  mutation control: unmutated copy reported $ctl_n of 2 — a copy that cannot run scores as a kill"
  fi

  # The same control for the two new statuses. The mutants below assert an ABSENCE, and a
  # copy that cannot run produces the same absence.
  ctl_l="$(bash "$MUTD/layer-drift.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null \
           | awk -F'\t' '$1=="OVERRIDE-LOOSE-ANCHOR"{c++} END{print c+0}')"
  ctl_d="$(bash "$MUTD/layer-drift.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null \
           | awk -F'\t' '$1=="OVERRIDE-DOUBLE-SHADOW"{c++} END{print c+0}')"
  if [ "$ctl_l" -eq 1 ] && [ "$ctl_d" -eq 2 ]; then
    ok "  mutation control: and the same copy reports 1 loose anchor and 2 double-shadow rows"
  else
    bad "  mutation control: unmutated copy reported loose=$ctl_l (want 1) double=$ctl_d (want 2)"
  fi

  # MUTANT 1 — drop the flattening. The wrapped entry must go silent and the single-line
  # entry must NOT, or the two are entangled and the wrap assertion proves nothing.
  sed "s@| tr '\\\\n' ' ' | tr -s ' ' \\\\@| tr -s ' ' \\\\@" "$DRIFT" > "$MUTD/layer-drift.sh"
  if cmp -s "$DRIFT" "$MUTD/layer-drift.sh"; then
    bad "  mutation flatten: the mutation matched nothing, so the flattening assertion is unproven"
  else
    m1="$(bash "$MUTD/layer-drift.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"
    m1w="$(printf '%s\n' "$m1" | awk -F'\t' '$1=="OVERRIDE-ASSERTS-SHADOW-SURVIVES" && $2 ~ /Rule-16-wrapped/{c++} END{print c+0}')"
    m1s="$(printf '%s\n' "$m1" | awk -F'\t' '$1=="OVERRIDE-ASSERTS-SHADOW-SURVIVES" && $2 ~ /Rule-13-survives/{c++} END{print c+0}')"
    if [ "$m1w" -eq 0 ] && [ "$m1s" -eq 1 ]; then
      ok "  mutation flatten: without it the WRAPPED claim vanishes and the single-line one does not"
    else
      bad "  mutation flatten: wrapped=$m1w (want 0) single-line=$m1s (want 1) — the flattening assertion is vacuous or the two entries are entangled"
    fi
  fi

  # MUTANT 2 — widen the noun set to include `file`. The legitimate rest-of-the-FILE claim
  # must start firing, and the two real claims must keep firing. This is the 3-of-5
  # false-positive set returning, and it is the only assertion that can catch it.
  sed 's@(section|check|rule|clause)@(section|check|rule|clause|file)@' "$DRIFT" > "$MUTD/layer-drift.sh"
  if cmp -s "$DRIFT" "$MUTD/layer-drift.sh"; then
    bad "  mutation noun-set: the mutation matched nothing, so the noun restriction is unproven"
  else
    m2="$(bash "$MUTD/layer-drift.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null \
          | awk -F'\t' '$1=="OVERRIDE-ASSERTS-SHADOW-SURVIVES"{print $2}')"
    if grep -q 'Rule-14-file-claim' <<<"$m2"; then
      ok "  mutation noun-set: widening it to \`file\` re-fires the true claim — the restriction is load-bearing"
    else
      bad "  mutation noun-set: the honest rest-of-the-FILE claim stayed silent even with \`file\` in the noun set, so the control above is vacuous"
    fi
  fi

  # MUTANT 3 — delete the REVERSE arm, which is the whole loose-anchor predicate. The loose
  # row must vanish and the double-shadow rows must NOT: they are computed from a different
  # accumulator and a mutant that took both would prove neither.
  awk '!/^      REVERSE:\*\) loose=/' "$DRIFT" > "$MUTD/layer-drift.sh"
  if cmp -s "$DRIFT" "$MUTD/layer-drift.sh"; then
    bad "  mutation loose-arm: the mutation matched nothing, so the loose-anchor assertion is unproven"
  else
    m3="$(bash "$MUTD/layer-drift.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"
    m3l="$(printf '%s\n' "$m3" | awk -F'\t' '$1=="OVERRIDE-LOOSE-ANCHOR"{c++} END{print c+0}')"
    m3d="$(printf '%s\n' "$m3" | awk -F'\t' '$1=="OVERRIDE-DOUBLE-SHADOW"{c++} END{print c+0}')"
    if [ "$m3l" -eq 0 ] && [ "$m3d" -eq 2 ]; then
      ok "  mutation loose-arm: without the REVERSE arm the loose anchor goes silent, and only that"
    else
      bad "  mutation loose-arm: loose=$m3l (want 0) double=$m3d (want 2) — the assertion is vacuous or the two statuses are entangled"
    fi
  fi

  # MUTANT 4 — require THREE claimants instead of two, which is the off-by-one a duplicate
  # check is most likely to ship with. The double-shadow rows must vanish and the loose row
  # must not.
  sed 's/if (n\[key\] > 1)/if (n[key] > 2)/' "$DRIFT" > "$MUTD/layer-drift.sh"
  if cmp -s "$DRIFT" "$MUTD/layer-drift.sh"; then
    bad "  mutation dup-threshold: the mutation matched nothing, so the double-shadow assertion is unproven"
  else
    m4="$(bash "$MUTD/layer-drift.sh" "$DIST" "$BASE" "$THEIRS" "$CONS" 2>/dev/null)"
    m4d="$(printf '%s\n' "$m4" | awk -F'\t' '$1=="OVERRIDE-DOUBLE-SHADOW"{c++} END{print c+0}')"
    m4l="$(printf '%s\n' "$m4" | awk -F'\t' '$1=="OVERRIDE-LOOSE-ANCHOR"{c++} END{print c+0}')"
    if [ "$m4d" -eq 0 ] && [ "$m4l" -eq 1 ]; then
      ok "  mutation dup-threshold: raising the duplicate threshold silences the pair, and only that"
    else
      bad "  mutation dup-threshold: double=$m4d (want 0) loose=$m4l (want 1) — the assertion is vacuous or the two statuses are entangled"
    fi
  fi
fi

# --- OVERRIDE-SUPERSEDED: core declaring an entry is no longer NEEDED ------------------
#
# Every other status asks whether the override is still CORRECT. This one asks whether it
# is still needed, and it is the only status whose answer is "delete this entry". Without
# it a superseded override presents as ordinary section drift -- which reads as "re-adopt
# the new wording", not "you can retire this" -- so the entry survives and goes on freezing
# every unrelated line in its shadowed span at base_sha. That is how a real core fix failed
# to reach the reference consumer.
if [ -z "$DRIFT" ]; then
  bad "FIXTURE BROKEN — no layer-drift.sh; the supersession arm would pass by not running"
else
  mkdir -p "$DIST/core/skills/ai-dlc"

  # A CORE FILE THE SURPLUS ARMS CAN BE MEASURED AGAINST, committed BEFORE the declaration so an
  # entry can carry it as its own `base_sha`. Every other SUP__ entry below shadows a file that
  # does not exist in this seed at all — which is the UNMEASURABLE case, asserted in its own right
  # further down. Without this commit the surplus arms would only ever exercise that branch, and a
  # measurement that never runs reports the same silence as one that found nothing.
  #
  # `### 3. Widget schema.` is FIVE non-blank lines including its heading. The two entries seeded
  # against it differ by exactly three lines, so the expected numbers below are seeded rather than
  # recomputed — a fixture that re-derives the answer with the same expression it is testing
  # agrees with itself.
  mkdir -p "$DIST/core/skills/ai-dlc/steps"
  cat > "$DIST/core/skills/ai-dlc/steps/widget.md" <<'WIDGET'
# Widget

### 3. Widget schema.

Core line one.
Core line two.
Core line three.

### 4. Other section.

Untouched.
WIDGET
  git -C "$DIST" add -A >/dev/null 2>&1
  git -C "$DIST" -c user.email=f@x -c user.name=f commit -qm "core carries the widget schema" >/dev/null 2>&1
  WBASE="$(git -C "$DIST" rev-parse --short HEAD)"

  cat > "$DIST/core/skills/ai-dlc/layer-contract.yaml" <<'YML'
contract_version: 13
override_supersessions:
  - shadows: steps/widget.md#3. Widget schema.
    since_core_version: "9.9.9"
    replaces_with:
      settings_env_key: AI_DLC_WIDGET_EXTRA
  - shadows: steps/widget.md#5. Adopted section.
    since_core_version: "9.9.9"
    reason: core took this entry's paragraph verbatim; there is nothing to configure.
  - shadows: steps/widget.md#6. Two-key section.
    since_core_version: "9.9.9"
    replaces_with:
      settings_env_keys:
        - AI_DLC_WIDGET_ALPHA
        - AI_DLC_WIDGET_BETA
absorbed_from:
  - path: core/skills/ai-dlc/extensions/README.md
YML
  git -C "$DIST" add -A >/dev/null 2>&1
  git -C "$DIST" -c user.email=f@x -c user.name=f commit -qm "declare a supersession" >/dev/null 2>&1
  THEIRS2="$(git -C "$DIST" rev-parse --short HEAD)"

  # The MATCH and its CONTROL differ in one field: the anchor. Same file, same shape, same
  # base_sha -- so an arm that fires on both is matching "is an override", not "is superseded".
  #
  # SUP__multi and SUP__multictl are the MULTI-ANCHOR pair, and they are the case the join was
  # blind to. The declared anchor is deliberately FIRST in SUP__multi's list -- see the mutant
  # below, which keeps only the LAST part and must therefore silence THIS entry while leaving
  # single-anchor SUP__match firing. Their own difference is one anchor: SUP__multictl bundles
  # two anchors core declares nothing about, so an arm that fires on it is matching "shadows more
  # than one thing", not "shadows something core superseded".
  for pair in "SUP__match:steps/widget.md#3. Widget schema." "SUP__control:steps/widget.md#4. Other section." "SUP__adopted:steps/widget.md#5. Adopted section." "SUP__twokey:steps/widget.md#6. Two-key section." "SUP__multi:steps/widget.md#3. Widget schema., #4. Other section." "SUP__multictl:steps/widget.md#4. Other section., #7. Also undeclared."; do
    nm="${pair%%:*}"; sh_v="${pair#*:}"
    cat > "$CONS/.claude/skills/ai-dlc/overrides/${nm}.md" <<EOF
---
shadows: ${sh_v}
base_sha: ${BASE}
reason: fixture entry
conforms_to: 13
---

# body
EOF
  done

  # THE TWO SURPLUS ENTRIES. Same anchor, same base_sha, same declaration — they differ ONLY in
  # whether the shadowed span carries lines core does not have. That is what makes the pair a
  # test of the measurement rather than of the entry's size.
  cat > "$CONS/.claude/skills/ai-dlc/overrides/SUP__surplus.md" <<EOF
---
shadows: steps/widget.md#3. Widget schema.
base_sha: ${WBASE}
reason: fixture entry carrying three lines core does not have
conforms_to: 13
---

### 3. Widget schema.

Core line one.
Core line two.
Core line three.
Consumer surplus A.
Consumer surplus B.
Consumer surplus C.
EOF
  cat > "$CONS/.claude/skills/ai-dlc/overrides/SUP__nosurplus.md" <<EOF
---
shadows: steps/widget.md#3. Widget schema.
base_sha: ${WBASE}
reason: fixture entry whose span is byte-identical to core's
conforms_to: 13
---

### 3. Widget schema.

Core line one.
Core line two.
Core line three.
EOF

  sup_out="$(bash "$DRIFT" "$DIST" "$BASE" "$THEIRS2" "$CONS" 2>&1)"
  sup_st() { printf '%s\n' "$sup_out" | awk -F'\t' -v e="$1" '$2 ~ e {print $1}'; }

  if grep -qx OVERRIDE-SUPERSEDED <<<"$(sup_st 'SUP__match\.md$')"; then
    ok "an override core declares SUPERSEDED is reported as retirable"
  else
    bad "a superseded override was not reported — it survives the pull and keeps freezing its shadowed span"
  fi

  if grep -qx OVERRIDE-SUPERSEDED <<<"$(sup_st 'SUP__control\.md$')"; then
    bad "CONTROL: an override on a DIFFERENT anchor was reported superseded — the arm matches any override"
  else
    ok "  and an override on an undeclared anchor stays silent"
  fi

  # THE TOKEN CONTRACT WITH apply.sh, which is where this can rot silently. apply.sh reads
  # `replaces_with=<KEY> ::` off the front of the detail to expand ONE superseded row into an
  # ORDERED, ATOMIC two-step worklist. If this prefix ever changes, apply falls back to a
  # single unordered row -- still green, still emitted, and the ordering constraint that keeps
  # a retire from re-imposing the core rule before its replacement is written is simply gone.
  # A degradation that keeps passing is the shape this repo names; assert the join, not the row.
  sup_detail="$(printf '%s\n' "$sup_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__match\.md$/ {print $4}')"
  case "$sup_detail" in
    "replaces_with=AI_DLC_WIDGET_EXTRA ::"*)
      ok "  the detail leads with the replaces_with= token apply.sh parses, carrying the declared key" ;;
    *)
      bad "the replaces_with= token is missing or malformed -- apply.sh silently drops to a single unordered row: ${sup_detail:0:60}" ;;
  esac

  # NON-VACUITY. The two assertions above are both satisfied by a run that emitted nothing
  # at all for the control and something for the match; assert the run itself is alive.
  if [ "$(printf '%s\n' "$sup_out" | grep -c 'SUP__control')" -ge 1 ]; then
    ok "  CONTROL is present in the output under some other status (so its silence above is a real zero)"
  else
    bad "the control entry produced NO row at all — its silence proves nothing"
  fi

  # A SUPERSESSION NEEDS NO CONFIGURATION TO BE ONE.
  #
  # Core stops needing an override two ways: it turns a hardcoded set into an AI_DLC_* key
  # the consumer declares its value in (the row above), or it simply ADOPTS the entry's
  # prose, where there is no key because there is nothing to configure. The emission used to
  # be gated on `settings_env_key`, so the second kind could be authored in the contract and
  # would silently never fire — a declaration with no reader, which is the cannot-fire class
  # arriving through the data side where I36 does not look. Measured on the reference
  # consumer: three of eleven overrides retire by adoption, none by configuration.
  if grep -qx OVERRIDE-SUPERSEDED <<<"$(sup_st 'SUP__adopted\.md$')"; then
    ok "  a supersession declaring NO settings_env_key still fires (core adopted the prose)"
  else
    bad "an env-keyless supersession was not reported — the cheapest retirement class is undeclarable, and the contract row that declares it has no reader"
  fi

  # THE OTHER HALF OF THE apply.sh TOKEN CONTRACT. apply.sh strips a leading
  # `replaces_with=<KEY> ::` and, finding none, emits the SINGLE worklist row. If the
  # env-less detail carried the token with an empty key, apply would instead emit
  # "1/2 ATOMIC — write  into .claude/settings.json" and hand the operator an instruction
  # naming nothing. Assert the absence, because that failure is green on every other check.
  sup_adopted="$(printf '%s\n' "$sup_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__adopted\.md$/ {print $4}')"
  case "$sup_adopted" in
    replaces_with=*) bad "the env-keyless detail leads with replaces_with= anyway — apply.sh will emit a 1/2 ATOMIC row telling the operator to write an empty key: ${sup_adopted:0:70}" ;;
    "")              bad "the env-keyless supersession produced an empty detail" ;;
    *)               ok "  and its detail omits the replaces_with= token, so apply.sh renders the single retire row" ;;
  esac

  # A SUPERSESSION MAY NEED MORE THAN ONE KEY, AND ONE PER ROW WAS NEVER A DECISION.
  # It was the only shape anyone had needed, so a retirement requiring two keys could not
  # be expressed at all and the entry stayed shadowed over a mechanism gap rather than over
  # a disagreement. The list form joins on a comma into the same field the single form
  # fills, and apply.sh splits it into N+1 ATOMIC rows.
  sup_twokey="$(printf '%s\n' "$sup_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__twokey\.md$/ {print $4}')"
  case "$sup_twokey" in
    "replaces_with=AI_DLC_WIDGET_ALPHA,AI_DLC_WIDGET_BETA ::"*)
      ok "  a settings_env_keys: LIST carries BOTH keys, comma-joined, in the token apply.sh parses" ;;
    "") bad "the two-key supersession produced no detail at all" ;;
    *)  bad "the settings_env_keys: list did not render both keys in order: ${sup_twokey:0:80}" ;;
  esac

  # THE LIST MUST NOT BLEED. Its items begin with a dash, exactly like the rows of the
  # block itself, so a loose item pattern would swallow the next `- shadows:` and attribute
  # one entry's keys to another. The single-key row that follows it in the contract is the
  # control: if it still carries exactly its own key, the list terminated where it should.
  sup_still="$(printf '%s\n' "$sup_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__match\.md$/ {print $4}')"
  case "$sup_still" in
    "replaces_with=AI_DLC_WIDGET_EXTRA ::"*)
      ok "  and the neighbouring single-key row still carries exactly its own key (the list did not bleed)" ;;
    *)  bad "the single-key row was contaminated by the list above it: ${sup_still:0:80}" ;;
  esac

  # --- THE SURPLUS THE REMEDY DROPS IS STATED AS A NUMBER --------------------------------
  #
  # THE REPORT BEHIND THIS. The consumer was told to narrow `shadows:` because core superseded
  # ONE ARM of an anchor, while their span under it carried 119 lines core does not have. The row
  # already warned, in prose, that narrowing "releases every unrelated line that anchor's span
  # froze at base_sha" — and an unquantified warning beside a concrete instruction reads as
  # boilerplate. The obvious remedy is to declare the ARM, and an arm is NOT ADDRESSABLE:
  # `override_supersessions` keys on `<file>#<anchor>` with no span vocabulary, the real case's
  # 231-line span carries exactly one sub-heading with the superseded machinery on BOTH sides of
  # it, and the other superseded arm is not in the shadowed file at all. So the row states the
  # size of what the operator is about to drop, which needs no new declaration.
  sup_surp="$(printf '%s\n' "$sup_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__surplus\.md$/ {print $4}')"
  case "$sup_surp" in
    *"against core's 4 at ${WBASE}, and 3 of yours appear nowhere in core's"*)
      ok "the row MEASURES the surplus: 3 consumer-only line(s) against core's span at ${WBASE} — the operator is told the size of what narrowing drops" ;;
    "") bad "the surplus entry produced no OVERRIDE-SUPERSEDED detail at all, so this arm asserts nothing" ;;
    *"could NOT be measured"*)
      bad "the surplus went UNMEASURABLE on an entry whose span and core span both exist. Either the anchor is not resolving in one of the two, or base_sha is not being read — and the fallback sentence then hides it behind honest-sounding prose: ${sup_surp:0:200}" ;;
    *)  bad "the surplus was measured wrongly (want 3 consumer-only against core's 4): $(printf %s "$sup_surp" | grep -oE 'MEASURED:.*' | head -1 || echo "<no MEASURED clause in the detail at all>")" ;;
  esac

  # THE CONTROL, and it is what stops the arm being "print the entry's size". Same anchor, same
  # base_sha, same declaration; the only difference is that this span carries nothing core lacks.
  sup_nosurp="$(printf '%s\n' "$sup_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__nosurplus\.md$/ {print $4}')"
  case "$sup_nosurp" in
    *"and 0 of yours appear nowhere in core's"*)
      ok "  CONTROL: an identical span reports 0 consumer-only lines — the number is a comparison, not the entry's length" ;;
    "") bad "the no-surplus control produced no detail at all, so the assertion above is unpaired" ;;
    *)  bad "CONTROL: a span byte-identical to core's did not report 0 consumer-only lines: ${sup_nosurp:0:220}" ;;
  esac

  # UNMEASURABLE IS SAID OUT LOUD. SUP__match shadows a section its own body does not contain, so
  # neither span resolves. The clause must SAY that rather than fall back to the qualitative
  # sentence alone — a warning that quietly loses its number reads exactly like one that never had
  # a subject, which is the defect class this whole arm belongs to.
  case "$sup_still" in
    *"could NOT be measured"*)
      ok "  an entry whose span does not resolve says so in the row, instead of dropping silently to prose" ;;
    *"appear nowhere in core's"*)
      bad "an entry with no resolvable span reported a MEASUREMENT anyway, so the numbers in the two assertions above cannot be trusted: ${sup_still:0:200}" ;;
    *)  bad "an entry whose span does not resolve carries neither a measurement nor the unmeasurable notice: ${sup_still:0:200}" ;;
  esac

  # MUTATION — drop the comparison and count the whole span. The surplus entry still looks right
  # (8 lines, and 8 would be reported), so ONLY the control can see this; that is why it is paired.
  MUTS="$ROOT/drift-mutant-surplus"; rm -rf "$MUTS"; mkdir -p "$MUTS"
  cp "$(dirname "$DRIFT")"/* "$MUTS"/ 2>/dev/null
  sed 's/| grep -Fxv -f <(printf .%s\\n. "\$cs") | grep -c \./| grep -c ./' "$DRIFT" > "$MUTS/layer-drift.sh"
  if cmp -s "$DRIFT" "$MUTS/layer-drift.sh"; then
    bad "  mutation surplus-comparison: the mutation matched nothing, so the control above proves nothing"
  else
    ms="$(bash "$MUTS/layer-drift.sh" "$DIST" "$BASE" "$THEIRS2" "$CONS" 2>/dev/null \
          | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__nosurplus\.md$/ {print $4}')"
    if [ -z "$ms" ]; then
      bad "  mutation surplus-comparison: the mutant emitted no row for the control, so it broke the arm rather than the comparison"
    elif grep -qF "and 0 of yours appear nowhere" <<<"$ms"; then
      bad "  mutation surplus-comparison: counting the WHOLE span still reported 0 consumer-only lines — the control is not reading the number it claims to"
    else
      ok "  MUTATION: without the comparison the identical span reports a non-zero surplus, so the control is load-bearing"
    fi
  fi

  # --- A MULTI-ANCHOR OVERRIDE IS THE CASE THIS ARM WAS BLIND TO ------------------------------
  #
  # The join compared `norm` of the WHOLE `shadows:` value against `norm` of the declaration's,
  # so an entry bundling several anchors could never match a declaration naming ONE of them --
  # and the more anchors an entry bundles the more unrelated core text it freezes, which is
  # exactly the entry a retirement signal exists for. Measured on the reference consumer at
  # 0.310.0 and it was a LIVE miss: `overrides/steps__retro__domain-sections.md` shadows four
  # retro anchors, one of which core declared superseded at 0.281.0. Whole-string join on the
  # real tree over the real pull range: 0 rows. Same tree, that anchor alone in `shadows:`: 1.
  if grep -qx OVERRIDE-SUPERSEDED <<<"$(sup_st 'SUP__multi\.md$')"; then
    ok "a MULTI-anchor override is reported when core supersedes ONE of its anchors"
  else
    bad "a multi-anchor override naming a declared supersession went unreported — the join reads the whole shadows: string, so the entries that freeze the most core text are the ones it cannot see"
  fi

  if grep -qx OVERRIDE-SUPERSEDED <<<"$(sup_st 'SUP__multictl\.md$')"; then
    bad "CONTROL: a multi-anchor override with NO declared anchor was reported — the arm is matching 'shadows more than one thing', not 'shadows something superseded'"
  else
    ok "  and a multi-anchor override with no declared anchor stays silent"
  fi

  # NON-VACUITY for that control, same reasoning as SUP__control's above.
  if [ "$(printf '%s\n' "$sup_out" | grep -c 'SUP__multictl')" -ge 1 ]; then
    ok "  CONTROL is present under some other status (so its silence is a real zero)"
  else
    bad "the multi-anchor control produced NO row at all — its silence proves nothing"
  fi

  # THE REMEDY IS NOT THE SAME REMEDY, AND SAYING SO IS THE POINT OF THE TOKEN.
  # `readopt-override.sh --stamp retire` DELETES THE FILE; there is no per-anchor retire. On a
  # multi-anchor entry that discards the anchors core has NOT superseded, and every section they
  # shadowed silently reverts to core. apply.sh renders the last worklist row off `retire_anchor=`
  # (asserted end to end in apply-worklist-rows), so a lost token is a row telling the operator
  # to delete an entry core asked them to narrow.
  sup_multi="$(printf '%s\n' "$sup_out" | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED" && $2 ~ /SUP__multi\.md$/ {print $4}')"
  case "$sup_multi" in
    "replaces_with=AI_DLC_WIDGET_EXTRA :: retire_anchor=steps/widget.md#3. Widget schema. ::"*)
      ok "  its detail carries retire_anchor= after replaces_with=, naming the entry's OWN spelling of the superseded anchor" ;;
    *retire_anchor=*)
      bad "the retire_anchor= token is present but not in the ordered prefix apply.sh parses: ${sup_multi:0:100}" ;;
    *)
      bad "the multi-anchor detail carries NO retire_anchor= token, so apply.sh renders '--stamp retire' and tells the operator to delete an entry core asked them to narrow: ${sup_multi:0:100}" ;;
  esac

  # AND THE SINGLE-ANCHOR DETAIL MUST NOT GAIN THE TOKEN. For a one-anchor entry deleting the
  # file really IS the remedy, and a token there would turn the correct instruction into
  # "remove the only anchor", leaving an override that shadows nothing.
  case "$sup_still" in
    *retire_anchor=*) bad "the SINGLE-anchor detail gained a retire_anchor= token — apply.sh would tell the operator to strip the entry's only anchor instead of retiring it" ;;
    *)                ok "  and the single-anchor detail is unchanged: no token, so its remedy is still the retire stamp" ;;
  esac

  # --- MUTANT: the entry side back to ONE part ------------------------------------------------
  # A COPY of the whole reconcile directory (layer-drift sources lib.sh from beside it, and a
  # lone script copy dies before printing anything), `cmp -s`-guarded so a sed that matched
  # nothing cannot pass as a mutation. Dropping the accumulator keeps only the LAST harvested
  # part, and SUP__multi lists its declared anchor FIRST — so this mutant must silence SUP__multi
  # while leaving single-anchor SUP__match firing. Two verdicts from one mutant, and they are the
  # disentanglement: a mutation that killed both would be testing "the arm runs", not the join.
  SMUT="$ROOT/supmut"; rm -rf "$SMUT"; mkdir -p "$SMUT"
  cp "$(dirname "$DRIFT")"/*.sh "$SMUT/" 2>/dev/null || true
  cp "$DRIFT" "$SMUT/layer-drift.sh"
  sctl="$(bash "$SMUT/layer-drift.sh" "$DIST" "$BASE" "$THEIRS2" "$CONS" 2>/dev/null | awk -F'\t' '$1=="OVERRIDE-SUPERSEDED"' | wc -l | tr -d ' ')"
  if [ "$sctl" -ge 2 ]; then
    ok "CONTROL: an unmutated copy in a fresh directory still reports both the single- and multi-anchor entries ($sctl rows)"
  else
    bad "CONTROL: the unmutated copy reported $sctl supersession row(s) — the mutant verdict below would be unreadable"
  fi

  sed 's@^    ent_keys="\${ent_keys}\$(norm @    ent_keys="$(norm @' "$DRIFT" > "$SMUT/layer-drift.sh"
  if cmp -s "$DRIFT" "$SMUT/layer-drift.sh"; then
    bad "the multi-anchor MUTANT did not apply — the ent_keys accumulator has been respelled, so it proves nothing"
  else
    smut_out="$(bash "$SMUT/layer-drift.sh" "$DIST" "$BASE" "$THEIRS2" "$CONS" 2>/dev/null)"
    smut_st() { printf '%s\n' "$smut_out" | awk -F'\t' -v e="$1" '$2 ~ e {print $1}'; }
    if grep -qx OVERRIDE-SUPERSEDED <<<"$(smut_st 'SUP__multi\.md$')"; then
      bad "MUTANT SURVIVED: SUP__multi is still reported with only its last anchor harvested, so the multi-anchor assertion is not testing the per-part join"
    else
      ok "MUTANT (entry side keeps one part): the multi-anchor entry goes silent — the accumulation is what makes every anchor joinable"
    fi
    if grep -qx OVERRIDE-SUPERSEDED <<<"$(smut_st 'SUP__match\.md$')"; then
      ok "  and the single-anchor entry still fires under it — the two arms are not entangled"
    else
      bad "  the mutant also silenced the single-anchor entry: it is testing whether the arm RUNS, not how it joins"
    fi
  fi
fi

rm -rf "$ROOT"
echo ""
if [ "$fails" -eq 0 ]; then echo "layer-readopt-gate: PASS"; exit 0; fi
echo "layer-readopt-gate: FAIL ($fails)"; exit 1
