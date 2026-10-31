#!/usr/bin/env bash
# core/fixtures/bmad-invocation-resolve/receipt-bl884.sh -- the BL-884 backlog receipt: the shipped rulebook invokes only
# BMAD skills that exist in a BMAD 6.11+ install, and Check 32 can tell.
#
# Runs core/scripts/validate-bmad-invocations.sh (Check 32) against the shipped rulebook
# (core/skills/ai-dlc) and a skills tree BUILT HERE in mktemp, shaped like BMAD 6.11+:
# bmad-deep-recon, bmad-review (customize.toml carrying code = "adversarial"), bmad-sprint-planning
# (references/readiness-gate.md), plus a stub SKILL.md for every OTHER name the rulebook invokes.
# The list of names is derived from the rulebook with the validator's own slash grammar.
# The five names BMAD 6.11 removed (bmad-market-research, bmad-domain-research, bmad-technical-research,
# bmad-review-adversarial-general, bmad-check-implementation-readiness) get no stub, so a rulebook that
# still invokes one fails Check 32.
#
# Exit 0 when the shipped rulebook passes. 1 when it does not (the defect still reproduces).
# 9 when it cannot measure: no validator, no rulebook, no mktemp, or a tree that enumerates no names.
# Behaviour only: no rulebook text is read for a literal.
#
# SCORING MODES, by RECEIPT_BL884_MODE (default `tip`); each builds the named variant in mktemp and
# prints the validator's exit as this script's exit, so one script scores all four spellings:
#   tip  the shipped rulebook, the 6.11+ tree                                  want 0
#   A    a rulebook copy with one `/bmad-review-adversarial-general` call restored  want non-zero
#   B    the tree's bmad-review customize.toml without the adversarial lens     want non-zero
#   D    a rulebook copy with a call spelled `/bmad-review lenses=adversarial,edge-case-hunter`  want 0
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

r884_root() { # walk up from $1 for the rulebook; never count hops
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -d "$d/core/skills/ai-dlc" ] && [ -f "$d/core/scripts/validate-bmad-invocations.sh" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
ROOT="$(r884_root "$(cd "$(dirname "$0")" && pwd)")" || { echo "receipt-bl884: no repository root" >&2; exit 9; }
V="$ROOT/core/scripts/validate-bmad-invocations.sh"
RULES="$ROOT/core/skills/ai-dlc"
MODE="${RECEIPT_BL884_MODE:-tip}"

W="$(mktemp -d 2>/dev/null)" || { echo "receipt-bl884: no mktemp" >&2; exit 9; }
[ -n "$W" ] && [ -d "$W" ] || exit 9
SK="$W/skills"
mkdir -p "$SK/bmad-deep-recon" "$SK/bmad-review" "$SK/bmad-sprint-planning/references" || exit 9
printf '%s\n' '---' 'name: bmad-deep-recon' '---' > "$SK/bmad-deep-recon/SKILL.md"
printf '%s\n' '---' 'name: bmad-review' '---' > "$SK/bmad-review/SKILL.md"
printf '%s\n' '---' 'name: bmad-sprint-planning' '---' > "$SK/bmad-sprint-planning/SKILL.md"
printf '%s\n' '[[lens]]' 'code = "adversarial"' > "$SK/bmad-review/customize.toml"
: > "$SK/bmad-sprint-planning/references/readiness-gate.md"

# Every other name the shipped rulebook invokes, by the validator's own slash grammar.
NAMES="$(grep -rhoE '(^|[^A-Za-z0-9_.-])/bmad-[a-z0-9-]+([^A-Za-z0-9_/-]|$)' "$RULES" 2>/dev/null \
  | grep -oE '/bmad-[a-z0-9-]+' | sed 's#^/##' | sed 's/-$//' | sort -u)"
[ -n "$NAMES" ] || { echo "receipt-bl884: the rulebook enumerates no /bmad-* names" >&2; exit 9; }
for n in $NAMES; do
  case "$n" in
    bmad-market-research|bmad-domain-research|bmad-technical-research|bmad-review-adversarial-general|bmad-check-implementation-readiness) continue ;;
  esac
  [ -d "$SK/$n" ] && continue
  mkdir -p "$SK/$n" && printf '%s\n' '---' "name: $n" '---' > "$SK/$n/SKILL.md"
done

RB="$RULES"
case "$MODE" in
  tip) ;;
  A|D)
    RB="$W/rulebook"
    mkdir -p "$RB" && cp -R "$RULES/." "$RB/" || exit 9
    if [ "$MODE" = A ]; then
      printf '\n%s\n' 'Run `/bmad-review-adversarial-general` on the brief.' > "$RB/zz-regression-a.md"
    else
      printf '\n%s\n' 'Run `/bmad-review lenses=adversarial,edge-case-hunter` on the brief.' > "$RB/zz-spelling-d.md"
    fi ;;
  B) printf '%s\n' '[[lens]]' 'code = "structure"' > "$SK/bmad-review/customize.toml" ;;
  *) echo "receipt-bl884: unknown mode $MODE" >&2; exit 9 ;;
esac

bash "$V" --rules-root "$RB" --skills-root "$SK" >/dev/null 2>&1
rc=$?
[ "$rc" -eq 2 ] && exit 9
exit "$rc"
