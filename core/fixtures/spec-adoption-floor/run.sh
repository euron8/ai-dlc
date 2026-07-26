#!/usr/bin/env bash
# Exercise validate-spec-adoption.sh — the spec-layer adoption floor.
#
# The floor exists because the obvious alternative (a scope clause that skips when
# no spec artifact is present) cannot be distinguished from the failure it masks: a
# project that never adopts, a project that quietly stopped, and a project with a
# perfect spec all print the same nothing. So the assertions below are mostly about
# what the tool REFUSES and what it PRINTS, not about happy paths.
#
# Exit 0 iff:
#   - no declaration          -> --verdict exits 2 (PENDING), never 0
#   - malformed declaration   -> --verdict exits 1, never 0
#   - pre-floor sprint        -> exits 0 AND prints SKIPPED-PRE-ADOPTION (the token
#                                is the mechanism; a silent skip is the defect)
#   - at/after floor          -> exits 0 AND prints IN-FORCE
#   - lowering the floor      -> REFUSED
#   - floor > current + 2     -> REFUSED
#   - floor already in force  -> any change REFUSED, same value still allowed
#   - --report                -> exits 0 always, and SAYS SO when undeclared
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

V=""
for cand in \
  "$DIR/../../scripts/validate-spec-adoption.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-spec-adoption.sh" \
  "$DIR/../../core/scripts/validate-spec-adoption.sh"; do
  [ -f "$cand" ] && V="$cand" && break
done
[ -n "$V" ] || { echo "run.sh: could not locate validate-spec-adoption.sh" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/spec-adoption-floor.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/docs/retro"
DECL="$WORK/_bmad-output/planning-artifacts/spec-adoption.md"

rc=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; rc=1; }
# Run, then read $?. Never `out=$(...)` for a verdict — command substitution moves
# the status into the assignment's and the fixture reads the wrong one.
rcof() { bash "$V" "$@" >/dev/null 2>&1; echo $?; }

echo "spec-adoption-floor:"

# --- undeclared ---------------------------------------------------------------
g=$(rcof --verdict 300 "$WORK")
[ "$g" -eq 2 ] && ok "undeclared: --verdict exits 2 (PENDING), never 0" \
               || bad "undeclared: --verdict exited $g, expected 2 — an undeclared floor that exits 0 is a blanket pass"

g=$(rcof --report "$WORK")
[ "$g" -eq 0 ] && ok "--report never fails, even undeclared" || bad "--report exited $g, expected 0"
if bash "$V" --report "$WORK" 2>&1 | grep -q 'UNDECLARED'; then
  ok "--report SAYS the floor is undeclared (visible on every push, not silent)"
else
  bad "--report printed nothing about the missing declaration — the absence stays invisible"
fi

# --- bounded deferral, checked BEFORE anything is on disk ---------------------
g=$(rcof --declare 900 --current 299 "$WORK")
[ "$g" -eq 1 ] && ok "REFUSED: a floor more than 2 sprints out (s900 from s299)" \
               || bad "declaring s900 from s299 exited $g, expected 1 — an unbounded deferral reads as adoption while nothing is enforced"
[ -f "$DECL" ] && bad "the refused --declare still wrote the declaration file"

# --- declare, then the two verdict states ------------------------------------
g=$(rcof --declare 300 --current 299 "$WORK")
[ "$g" -eq 0 ] && ok "declaring s300 from s299 is accepted" || bad "declaring s300 from s299 exited $g, expected 0"

if bash "$V" --verdict 299 "$WORK" 2>/dev/null | grep -q 'SKIPPED-PRE-ADOPTION'; then
  ok "a pre-floor sprint PRINTS SKIPPED-PRE-ADOPTION (the token is what makes the skip auditable)"
else
  bad "a pre-floor sprint printed no SKIPPED-PRE-ADOPTION token — indistinguishable from a check that ran and found nothing"
fi
g=$(rcof --verdict 299 "$WORK")
[ "$g" -eq 0 ] && ok "a pre-floor sprint exits 0 (out of scope is not a failure)" || bad "pre-floor verdict exited $g, expected 0"

if bash "$V" --verdict 300 "$WORK" 2>/dev/null | grep -q 'IN-FORCE'; then
  ok "a sprint at the floor PRINTS IN-FORCE"
else
  bad "a sprint at the floor did not print IN-FORCE"
fi

# --- monotone -----------------------------------------------------------------
g=$(rcof --declare 250 --current 299 "$WORK")
[ "$g" -eq 1 ] && ok "REFUSED: lowering the floor (s300 -> s250)" \
               || bad "lowering the floor exited $g, expected 1 — it would retroactively pull legacy sprints into scope"
grep -q 'adopted_from_sprint: 300' "$DECL" || bad "the refused --declare mutated the floor anyway"

# --- irrevocable once in force ------------------------------------------------
touch "$WORK/docs/retro/sprint-300.md"
g=$(rcof --declare 301 --current 301 "$WORK")
[ "$g" -eq 1 ] && ok "REFUSED: moving a floor that has been in force for a committed sprint" \
               || bad "moving an in-force floor exited $g, expected 1 — it rewrites which sprints were held to the spec layer, after the fact"
g=$(rcof --declare 300 --current 301 "$WORK")
[ "$g" -eq 0 ] && ok "re-declaring the SAME in-force value is allowed (idempotent, not a change)" \
               || bad "re-declaring the same value exited $g, expected 0 — an idempotent write must not be refused"

# --- malformed is not adopted -------------------------------------------------
grep -v '^rationale:' "$DECL" > "$WORK/tmp" && mv "$WORK/tmp" "$DECL"
g=$(rcof --verdict 300 "$WORK")
[ "$g" -eq 1 ] && ok "a declaration missing rationale: exits 1 (malformed), never 0" \
               || bad "a malformed declaration exited $g, expected 1 — a half-written declaration must not read as adopted"

printf 'adopted_from_sprint: 300\ndeclared_at_sha: abc1234\nrationale: x\n' > "$DECL"
g=$(rcof --verdict 300 "$WORK")
[ "$g" -eq 1 ] && ok "a declaration with no SPEC_ADOPTION version header exits 1" \
               || bad "an unversioned declaration exited $g, expected 1"

echo
if [ "$rc" -eq 0 ]; then echo "spec-adoption-floor: PASS"; else echo "spec-adoption-floor: FAILED" >&2; fi
exit $rc
