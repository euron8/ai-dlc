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
#   - a `/bmad-…` PATH SEGMENT is not counted as a call site, in all three shapes
#       the tree actually carries: the manifest bullet (`fixtures/bmad-x/**`), the
#       enforcement-map list (`[tests/fixtures/bmad-x]`), and the line-start form
#       where no leading path character exists and only the trailing separator
#       distinguishes it
#   - MUTATION: neutering the load-target resolution turns the dead shim green
#   - MUTATION: reverting the call-site grammar reds the clean run — and the
#       dangling-name assertion stays GREEN under it, which is what proves the
#       grammar narrowed the scan without neutering the check
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

# --- the path segment is not a call site --------------------------------------
# The seed puts three `/bmad-…` PATH segments in the scanned tree. None names a
# skill, so if any is enumerated the run above would already be red -- but assert
# the names directly too, because "exited 0" and "did not enumerate it" are two
# different claims and only the second one is what this arm fixes.
OUT="$(bash "$V" --skills-root "$S" --rules-root "$R" 2>&1 || true)"
for seg in bmad-invocation-resolve bmad-line-start-path; do
  if grep -q -- "$seg" <<<"$OUT"; then
    bad "a /bmad-… PATH SEGMENT was enumerated as an invocation: '$seg'"
  else
    ok "PATH SEGMENT not counted as a call site: '$seg'"
  fi
done
# Non-vacuity for the loop above, as a POSITIVE outcome rather than the absence of
# the old message: the clean rulebook invokes exactly two names, and the scan must
# say so. A run that printed nothing would score two silent oks above; a run that
# counted a path segment would say 3 or 4.
if grep -qF 'PASS (2 invoked name(s)' <<<"$OUT"; then
  ok "CONTROL: the scan enumerated exactly the 2 real call sites (so the two oks above are not silence)"
else
  bad "FIXTURE ERROR: expected 'PASS (2 invoked name(s)', got: $(tail -1 <<<"$OUT")"
fi

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

# --- MUTATION control: the call-site GRAMMAR is what excludes the path segment ---
# Revert the enumerator to the slash-only form. The clean rulebook must go RED,
# because the path segments become invented invocations. And the dangling-name
# assertion must stay GREEN under the same mutant -- that pairing is the whole
# claim: the grammar narrowed the scan without neutering the check. A mutant that
# reds both would mean the two assertions are entangled and one is vacuous.
MG="$ROOT/mutant-grammar.sh"
cp "$V" "$MG"
# Both sides passed through the environment and quoted with \Q..\E, so neither the
# bracket classes nor the `$` anchor is re-read as a regex by the mutator itself.
MUT_OLD='(^|[^A-Za-z0-9_.-])/bmad-[a-z0-9-]+([^A-Za-z0-9_/-]|$)' \
MUT_NEW='/bmad-[a-z0-9-]+' \
  perl -0pi -e 's/\Q$ENV{MUT_OLD}\E/$ENV{MUT_NEW}/' "$MG"
if cmp -s "$V" "$MG"; then
  bad "FIXTURE ERROR: the grammar mutation matched nothing — the path-segment assertions above prove nothing"
else
  bash "$MG" --skills-root "$S" --rules-root "$R" >/dev/null 2>&1
  [ $? -ne 0 ] && ok "MUTATION: the slash-only enumerator reds the clean rulebook (the grammar is what excludes the path segment)" \
               || bad "MUTATION: the slash-only enumerator still passed — something other than the grammar is excluding the path segment"

  # The anti-neutering pairing. Same mutant, a genuinely dangling name.
  printf 'Invoke `/bmad-no-such-skill` here.\n' > "$R/steps/dangling2.md"
  bash "$MG" --skills-root "$S" --rules-root "$R" >/dev/null 2>&1
  [ $? -eq 1 ] && ok "MUTATION PAIRING: a dangling name still FAILS under the mutant (the two assertions are not entangled)" \
               || bad "MUTATION PAIRING: the mutant stopped catching a dangling name — the two assertions are entangled"
  rm -f "$R/steps/dangling2.md"
fi

# Unmutated control from the same directory. A mutant copy that dies for its own
# reasons emits nothing, and "no output" would otherwise score as a kill.
MC="$ROOT/control-unmutated.sh"
cp "$V" "$MC"
bash "$MC" --skills-root "$S" --rules-root "$R" >/dev/null 2>&1
[ $? -eq 0 ] && ok "CONTROL: an UNMUTATED copy in the same directory still passes (the mutants died of their edits, not of being copies)" \
             || bad "CONTROL: the unmutated copy failed — every mutant verdict above is unattributable"

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
