#!/usr/bin/env bash
# absorbed-specifics-survive — text a consumer DELETED ITS OWN COPY OF may not silently vanish
# from core.
#
# Usage: run.sh [path-to-SKILL.md]
# Exit:  0 = every absorbed specific is still present, 1 = one was lost, 2 = fixture broken.
#
# WHY THIS FIXTURE IS DIFFERENT FROM A PROSE LINT, AND WHY IT SHIPS.
#
# Two sections of `SKILL.md` were changed at v0.353.0 in response to filings from the reference
# consumer, and both changes exist so that consumer can RETIRE its own duplicate sections from
# `extensions/steps-domain/SKILL-push.md`. That retirement is the point: Rule 27(c) forbids
# restating core, so as long as the consumer's copies exist they are a standing violation, and
# `layer-drift.sh` correctly reports them as `EXTENSION-TITLE-MATCHES-CORE`.
#
# THE ASYMMETRY THAT MAKES A PIN NECESSARY. Once the consumer deletes its copies, NOTHING on the
# consumer's side carries these specifics any more. A later edit here that drops one is not a
# regression against a second copy that would notice — the second copy is gone, deleted on the
# strength of this text. The loss is silent by construction. That is the exact shape of an
# absorption that goes bad, and it is why this fixture SHIPS rather than being distribution-only:
# the consumer's own suite is what protects the consumer's own retirement.
#
# WHAT IT DOES NOT DO. It does not check wording, tone, or line breaks, and it must not — a pin
# that fails on a rewrap is a pin the operator turns off. Each arm anchors on the shortest string
# that carries the CLAIM, and section 3 proves each of those strings can actually go missing.
set -uo pipefail

# HERMETIC -- scrub the operator's tuning before reading anything (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"

# BOTH LAYOUTS, each named outright rather than derived from the other (I33).
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
SKILL="${1:-}"
[ -n "$SKILL" ] || SKILL="$(pick "$HERE/../../skills/ai-dlc/SKILL.md" \
                                "$HERE/../../../.claude/skills/ai-dlc/SKILL.md" \
                                "$HERE/../../../core/skills/ai-dlc/SKILL.md")"
[ -n "$SKILL" ] && [ -f "$SKILL" ] \
  || { echo "FIXTURE ERROR: cannot locate SKILL.md in either layout" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# <claim label> <literal that carries it>. The literal is the SHORTEST span that cannot survive
# the claim being removed, so a rewrap or a retitle does not fire this and a deletion does.
CLAIM=(
  "self-scheduled payloads are limited to inert reminders or read-only checks"
  "background work already re-invokes the lead, so a self-fire is unnecessary"
  "a self-fired payload is a lead-conduct finding at retro"
  "the sprint-PR merge exclusion is scoped to core AS SHIPPED, not universal"
  "a project whose deploy policy defines the procedure HAS the gate"
  "and that project needs no extension to say so"
)
LIT=(
  'inert reminders or read-only status checks'
  're-invoke the lead when they finish'
  '**lead-conduct finding** at retro'
  'in core AS SHIPPED the sprint-PR merge has none'
  'the same test makes it a human gate there'
  'Do NOT write an extension to say so'
)

echo "absorbed-specifics-survive:"

# =============================================================================
# 0. THE CONTROL — this is the right file, and the reader works.
# =============================================================================
# Every arm below is a presence check, and a presence check over the WRONG FILE, or over a file
# the reader cannot open, fails for a reason that has nothing to do with the claim. Anchor on a
# heading that must be in SKILL.md and would not be in a step file.
if grep -qF 'No self-scheduling skill re-entry' "$SKILL" \
   && grep -qF 'Pending operator approvals do not transfer across handoff' "$SKILL"; then
  ok "CONTROL: both host sections are present in $(basename "$SKILL") — the arms below read the right file"
else
  bad "FIXTURE BROKEN: one or both host sections are absent, so every arm below fails for the wrong reason"
  echo; echo "absorbed-specifics-survive: FIXTURE BROKEN" >&2; exit 2
fi

# =============================================================================
# 1-2. EVERY ABSORBED SPECIFIC IS STILL HERE.
# =============================================================================
for i in 0 1 2 3 4 5; do
  if grep -qF -- "${LIT[$i]}" "$SKILL"; then
    ok "${CLAIM[$i]}"
  else
    bad "LOST: ${CLAIM[$i]} — the reference consumer deleted its own copy of this on the strength of core carrying it, so nothing else states it any more"
  fi
done

# =============================================================================
# 3. EACH PIN CAN ACTUALLY FIRE.
# =============================================================================
# A presence check whose literal is a substring of something structural — a heading, a word that
# appears twice — passes forever and reads exactly like a pin that is doing work. Delete each
# literal from a COPY and confirm its own arm, and ONLY its own arm, goes red.
for i in 0 1 2 3 4 5; do
  copy="$WORK/mut-$i.md"
  # EACH LITERAL MUST SIT ON EXACTLY ONE LINE, AND APPEAR ONCE. Both halves are load-bearing.
  # A literal spanning a wrap cannot be expressed to `awk -v` at all -- a raw newline in an
  # assignment is a syntax error, the mutant is never built, and the run reads as entanglement
  # rather than as a broken program (measured: two of these six, written that way first). And a
  # literal appearing TWICE would have only its first occurrence removed here, leaving the arm
  # above green over a mutation that did fire -- a survival scored as a kill.
  n_lit="$(grep -cF -- "${LIT[$i]}" "$SKILL" || true)"
  if [ "$n_lit" -ne 1 ]; then
    bad "MUTANT $i: its literal is on $n_lit line(s), not exactly 1 — a multi-line or repeated anchor cannot be removed cleanly, so '${CLAIM[$i]}' is unproven"
    continue
  fi
  awk -v lit="${LIT[$i]}" '{ p=index($0,lit); if(p) $0 = substr($0,1,p-1) substr($0,p+length(lit)); print }' "$SKILL" > "$copy"
  if cmp -s "$SKILL" "$copy"; then
    bad "MUTANT $i: the literal for '${CLAIM[$i]}' could not be removed, so its arm above proves nothing"
    continue
  fi
  reds=0; own=0
  for j in 0 1 2 3 4 5; do
    if ! grep -qF -- "${LIT[$j]}" "$copy"; then
      reds=$((reds+1)); [ "$j" -eq "$i" ] && own=1
    fi
  done
  if [ "$reds" -eq 1 ] && [ "$own" -eq 1 ]; then
    ok "  and it is falsifiable: removing it reds exactly its own arm, and no other"
  else
    bad "  MUTANT $i moved $reds arm(s) (own=$own) — the pins are entangled, so at least one of them is not measuring what it names"
  fi
done

echo
if [ "$fails" -eq 0 ]; then echo "absorbed-specifics-survive: PASS"; exit 0; fi
echo "absorbed-specifics-survive: $fails assertion(s) FAILED" >&2
exit 1
