#!/usr/bin/env bash
# Exercise validate-bmad-invocations.sh (gate-validation Check 32).
#
# Exit 0 iff:
#   - a rulebook invoking only healthy names          PASSES (0)
#   - a rulebook invoking a name with NO skill dir    FAILS (1)   -- dangling
#   - a rulebook invoking a DEAD SHIM                 FAILS (1)   -- the whole point:
#       the directory exists and SKILL.md exists, so a directory-existence check
#       passes; only resolving the LOAD target catches it
#   - a rulebook invoking a DEPRECATED but resolving skill PASSES (0) and PRINTS a
#       note -- a scheduled removal must be visible without blocking a working
#       pipeline
#   - a self-contained skill (no LOAD directive)      PASSES (0)  -- over-fire control
#   - no skills root                                  DISARMS (2), never 0
#   - zero enumerated call sites                      DISARMS (2), never 0
#   - MUTATION: neutering the load-target resolution turns the dead shim green
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

V=""
for cand in \
  "$DIR/../../scripts/validate-bmad-invocations.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-bmad-invocations.sh" \
  "$DIR/../../core/scripts/validate-bmad-invocations.sh"; do
  [ -f "$cand" ] && V="$cand" && break
done
[ -n "$V" ] || { echo "run.sh: could not locate validate-bmad-invocations.sh" >&2; exit 2; }

ROOT="$(bash "$DIR/seed.sh")"
trap 'rm -rf "$ROOT"' EXIT
S="$ROOT/.claude/skills"
R="$ROOT/rules"

rc=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1" >&2; rc=1; }
# Run, then read $?. Never `out=$(...)` for a verdict.
rcof() { bash "$V" --skills-root "$S" --rules-root "$R" >/dev/null 2>&1; echo $?; }

echo "bmad-invocation-resolve:"

g=$(rcof)
[ "$g" -eq 0 ] && ok "OVER-FIRE CONTROL: healthy names pass (a self-contained skill and a loader whose target exists)" \
               || bad "the clean rulebook exited $g, expected 0"

printf 'Invoke `/bmad-no-such-skill` here.\n' > "$R/steps/dangling.md"
g=$(rcof)
[ "$g" -eq 1 ] && ok "a name with no skill directory FAILS (dangling)" \
               || bad "a dangling name exited $g, expected 1"
rm -f "$R/steps/dangling.md"

printf 'Invoke `/bmad-dead-shim` here.\n' > "$R/steps/shim.md"
g=$(rcof)
[ "$g" -eq 1 ] && ok "a DEAD SHIM FAILS — directory and SKILL.md exist, LOAD target absent" \
               || bad "a dead shim exited $g, expected 1 — a directory-existence check would have passed it"
if bash "$V" --skills-root "$S" --rules-root "$R" 2>&1 | grep -q 'is a loader for'; then
  ok "the failure names the missing load target, not just the skill"
else
  bad "the dead-shim failure did not name the absent load target"
fi

# --- MUTATION control: the load-target resolution is what fails the shim -------
# Copy, then assert with cmp -s that the edit matched something. A sed that matches
# nothing yields a mutant identical to the subject, which then "fails as expected"
# for the wrong reason.
M="$ROOT/mutant.sh"
cp "$V" "$M"
sed -i.bak 's/if \[ -n "\$proot" \] \&\& \[ -e "\$proot\/\$t" \]; then/if true; then/' "$M" 2>/dev/null \
  || sed -i '' 's/if \[ -n "\$proot" \] \&\& \[ -e "\$proot\/\$t" \]; then/if true; then/' "$M" 2>/dev/null
rm -f "$M.bak"
if cmp -s "$V" "$M"; then
  bad "FIXTURE ERROR: mutation matched nothing — the dead-shim assertion above proves nothing"
else
  bash "$M" --skills-root "$S" --rules-root "$R" >/dev/null 2>&1
  if [ $? -eq 0 ]; then
    ok "MUTATION: neutering load-target resolution turns the dead shim green (that resolution is what fails it)"
  else
    bad "MUTATION: the mutant still rejected the dead shim — something other than load-target resolution produced the FAIL"
  fi
fi
rm -f "$R/steps/shim.md"

printf 'Invoke `/bmad-deprecated-one` here.\n' > "$R/steps/dep.md"
g=$(rcof)
[ "$g" -eq 0 ] && ok "a DEPRECATED but resolving skill passes (a working pipeline is not blocked)" \
               || bad "a deprecated resolving skill exited $g, expected 0"
if bash "$V" --skills-root "$S" --rules-root "$R" 2>&1 | grep -q 'DEPRECATED'; then
  ok "the deprecation is REPORTED (a scheduled removal must not arrive unannounced)"
else
  bad "a deprecated skill passed with no note — the removal deadline stays invisible"
fi
rm -f "$R/steps/dep.md"

# --- DISARM controls ----------------------------------------------------------
bash "$V" --skills-root "$ROOT/no-such-dir" --rules-root "$R" >/dev/null 2>&1
[ $? -eq 2 ] && ok "FAIL-CLOSED: a missing skills root exits 2, not 0" \
             || bad "a missing skills root did not exit 2 — with nothing to resolve against every name would 'pass'"

mkdir -p "$ROOT/empty-rules"
bash "$V" --skills-root "$S" --rules-root "$ROOT/empty-rules" >/dev/null 2>&1
[ $? -eq 2 ] && ok "FAIL-CLOSED: zero enumerated call sites exits 2, not 0" \
             || bad "a rulebook with no /bmad-* call sites did not exit 2 — an empty scan prints the same clean line as a full one"

echo
if [ "$rc" -eq 0 ]; then echo "bmad-invocation-resolve: PASS"; else echo "bmad-invocation-resolve: FAILED" >&2; fi
exit $rc
