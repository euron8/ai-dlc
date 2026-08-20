#!/usr/bin/env bash
# derivation-capture-mutants — the mutation battery behind ai-dlc-derivation-capture.sh.
# DISTRIBUTION-ONLY.
#
# Usage: run.sh
# Exit:  0 = every arm is load-bearing and exclusively so, 1 = one is not, 2 = fixture broken.
#
# WHY IT EXISTS. Nine of the sibling's eighteen assertions are ABSENCE-shaped -- they require
# the hook to exit 0 and print nothing -- and every one of them passes against a hook replaced
# by `exit 0`. A seeded near-miss establishes that the arm DISCRIMINATES between two inputs;
# only a mutant establishes that it discriminates at all. So each mutation below deletes or
# widens one behaviour of the hook and DECLARES the exact set of arms that must redden.
#
# WHAT A KILL IS HERE. The sibling prints one `  ok    ` or `  FAIL  ` line per arm. A kill is
# that fixture reporting FAIL on exactly the declared set and ok on every other arm. Reddening
# an arm the mutation does not own is not a stronger kill, it is an entangled assertion, and
# this battery fails on it exactly as it fails on a survivor.
#
# EIGHT OF THE NINE MUTATIONS DECLARE ONE ARM. The ninth -- the payload index ignored, so
# every pair is submitted -- declares three, and that is the honest shape rather than a
# weakened rule: A3, A4 and A5 differ in the INPUT they present (a reproducing pair, prose
# alone, a reproducing pair beside a stale sibling), and one deletion makes all three wrong at
# once. Splitting it into three mutations that each redden all three would assert less, not
# more.
#
# HOW THE MUTANT REACHES THE SIBLING. `seed.sh` resolves the hook and the validator from its
# own directory's grandparent, so the battery builds a THROWAWAY DISTRIBUTION -- core/hooks/,
# core/scripts/, core/fixtures/derivation-capture/ -- and mutates the hook there. Nothing in
# the shipped fixture carries a test-only override, and the sibling under mutation is the same
# bytes as the sibling on disk.
#
# THREE ARMS CARRY NO MUTANT, and that is stated rather than left to be noticed. A0 is
# structural (the files exist). A1 is the positive control: it asserts the seeded artifact is
# 2-of-4 stale UNDER THE REAL VALIDATOR, which is the conjunct that keeps a dead harness from
# scoring silence as a sweep. A11 (a Read payload is ignored) is produced by three independent
# guards -- the tool-name case, the empty-payload guard, and the empty mask -- so no single
# deletion owns it; the redundancy is deliberate, because the tool-name case is also what
# defends a consumer who registers this hook against a wider matcher than the template's.
set -uo pipefail

# HERMETIC -- scrub the operator's tuning before invoking any hook (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
[ -n "$ROOT" ] && [ -f "$ROOT/core/hooks/ai-dlc-derivation-capture.sh" ] \
  || { echo "FIXTURE ERROR: core/hooks/ai-dlc-derivation-capture.sh not found — this fixture is distribution-only" >&2; exit 2; }
SIB="$HERE/../derivation-capture"
[ -f "$SIB/run.sh" ] && [ -f "$SIB/seed.sh" ] \
  || { echo "FIXTURE ERROR: sibling derivation-capture/ is missing its driver or seed" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq is required" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# Build the throwaway distribution once; each mutant gets a fresh copy of the hook.
TREE="$WORK/dist"
mkdir -p "$TREE/core/hooks" "$TREE/core/scripts" "$TREE/core/fixtures/derivation-capture"
cp "$ROOT/core/hooks/ai-dlc-derivation-capture.sh" "$TREE/core/hooks/"
cp "$ROOT/core/scripts/validate-artifact-derivations.sh" "$TREE/core/scripts/"
cp "$SIB/run.sh" "$SIB/seed.sh" "$TREE/core/fixtures/derivation-capture/"
chmod +x "$TREE/core/fixtures/derivation-capture/run.sh" "$TREE/core/fixtures/derivation-capture/seed.sh"
PRISTINE="$WORK/hook.pristine"
cp "$ROOT/core/hooks/ai-dlc-derivation-capture.sh" "$PRISTINE"
MUT_HOOK="$TREE/core/hooks/ai-dlc-derivation-capture.sh"

# THE RESOLVED SUBJECT, printed. A mutation applied to a file the run never loads leaves every
# arm green and reads exactly like an arm that cannot fire.
printf '  subject: %s\n' "$MUT_HOOK"

# run_sibling -> writes the sibling's output to $WORK/out, sets SIB_RC
run_sibling() {
  bash "$TREE/core/fixtures/derivation-capture/run.sh" > "$WORK/out" 2>&1
  SIB_RC=$?
}

# failing_arms -> the sibling's FAIL lines, one per line, whitespace-collapsed
failing_arms() { sed -n 's/^  FAIL  //p' "$WORK/out"; }

echo "derivation-capture-mutants:"

# --- 0. CONTROL: the unmutated copy passes, and passes for a reason ------------
# Presence-shaped, not merely rc=0: a subject replaced by `exit 0` produces a sibling that
# reports FAIL everywhere, but a BROKEN HARNESS produces no arm lines at all, and "no FAIL
# lines" would otherwise score as a clean control.
run_sibling
CTL_OKS=$(grep -c '^  ok    ' "$WORK/out" || true)
if [ "$SIB_RC" = 0 ] && [ "$CTL_OKS" -ge 16 ]; then
  ok "control: the unmutated hook passes all $CTL_OKS sibling arms"
else
  bad "control: the unmutated hook exited $SIB_RC with $CTL_OKS ok lines — the harness is broken, so every kill below is unreadable"
  printf '%s\n' "$(sed -n '1,25p' "$WORK/out")" >&2
  exit 2
fi

# mutate <label> <owned-arm-substrings, `|`-separated> <sed-expr>
# Applies the mutation to a fresh copy, guards with cmp -s so a sed that matched nothing
# cannot pass as a mutation, runs the sibling, and requires the set of reddened arms to be
# EXACTLY the declared set -- every declared arm present, and no arm beyond them.
mutate() {
  local label="$1" owned="$2" expr="$3" n other
  cp "$PRISTINE" "$MUT_HOOK"
  sed "$expr" "$PRISTINE" > "$WORK/mutated" 2>/dev/null
  if cmp -s "$PRISTINE" "$WORK/mutated"; then
    bad "$label: the mutation matched nothing — the expression is stale against the hook's text"
    return
  fi
  cp "$WORK/mutated" "$MUT_HOOK"
  run_sibling
  cp "$PRISTINE" "$MUT_HOOK"
  # NEVER `failing_arms | grep -q`: grep leaves at its first match while the writer is
  # still pushing, and under pipefail the pipeline then answers with the writer's EPIPE
  # and reports NOT-FOUND on input that contains the pattern (I54b).
  local red; red="$(failing_arms)"
  n=$(printf '%s' "$red" | grep -c . || true)
  if [ "$n" = 0 ]; then
    bad "$label: SURVIVED — every sibling arm still passes with this behaviour removed"
    return
  fi
  printf '%s\n' "$owned" | tr '|' '\n' | grep -v '^$' > "$WORK/expect"
  local miss=0 e
  while IFS= read -r e; do
    grep -qF "$e" <<< "$red" || { bad "$label: declares '$e' but that arm still passes"; miss=1; }
  done < "$WORK/expect"
  [ "$miss" = 0 ] || return
  # Every reddened arm must be one this mutation declared.
  other=0
  while IFS= read -r a; do
    [ -n "$a" ] || continue
    grep -qF "$a" "$WORK/expect" 2>/dev/null && continue
    # the declared strings are SUBSTRINGS of the arm text, so test that direction too
    local matched=0
    while IFS= read -r e; do case "$a" in *"$e"*) matched=1 ;; esac; done < "$WORK/expect"
    [ "$matched" = 1 ] || { other=$((other+1)); bad "$label: also reddened an undeclared arm: $a"; }
  done <<< "$red"
  [ "$other" = 0 ] || return
  ok "$label: reddens exactly the arm(s) it declares"
}

# --- 1. pair grain -> block grain ---------------------------------------------
# The mask keeps a pair only when the payload contains one of its lines. Widen it to keep
# every pair of any block that has one touched pair, and an edit to a reproducing pair starts
# dragging its stale sibling in with it.
mutate "block-grain mask" "the reproducing pair of a mixed block" \
  's/? L\[k\] : "")/? L[k] : "") # MUTANT/; s/(pid\[k\]>0 \&\& tch\[pid\[k\]\]) ? L\[k\]/(pid[k]>0 \&\& any) ? L[k]/'

# --- 2. touch keyed on the command line alone ---------------------------------
mutate "command-line-only touch" "an output-only rewrite" \
  's/if (cur>0 \&\& (L\[k\] in PAY)) tch\[cur\]=1/if (cur>0 \&\& (L[k] in PAY) \&\& index(L[k],"$ ")==1) tch[cur]=1/'

# --- 3. MultiEdit payload dropped ---------------------------------------------
mutate "MultiEdit edits[] unread" "MultiEdit exited" \
  's/((\.tool_input\.edits \/\/ \[\]) | map(\.new_string \/\/ empty) | join("\\n"))/(.tool_input.no_such_field \/\/ empty)/'

# --- 4. Write payload dropped -------------------------------------------------
mutate "Write content unread" "a whole-file Write exited" \
  's/(\.tool_input\.content \/\/ empty),/(.tool_input.no_such_field \/\/ empty),/'

# --- 5. missing validator fails CLOSED ----------------------------------------
mutate "fail-closed on a missing validator" "with the validator absent" \
  's/\[ -r "\$VALIDATOR" \] || exit 0/[ -r "$VALIDATOR" ] || exit 2/'

# --- 6. the mask path is never rewritten to the artifact ----------------------
mutate "mask path left in the report" "does not cite stories-repair-p1.md" \
  's/^REL="\${FILE#"\$PROJECT_DIR"\/}"/REL="$MASK"/'

# --- 7. any non-zero exit read as a verdict -----------------------------------
mutate "rc 2 read as a verdict" "refused to start" \
  's/^\[ "\$RC" = 1 \] || exit 0/[ "$RC" != 0 ] || exit 0/'

# --- 8b. the payload index ignored: every pair submitted, i.e. file grain ------
# This is the design the measurement rejected — 12 of the 40 fence-carrying files in the
# reference consumer's active sprint already fail whole-file validation, so it refuses an
# unrelated edit in 30% of them. Three arms present three different inputs it gets wrong.
mutate "payload index ignored (file grain)" \
  "edit writing a reproducing pair|an edit that wrote no derivation|the reproducing pair of a mixed block" \
  's/if (cur>0 \&\& (L\[k\] in PAY)) tch\[cur\]=1/if (cur>0) tch[cur]=1/'

# --- 8. the markdown filter removed -------------------------------------------
mutate "markdown filter removed" "a .txt path exited" \
  's/^case "\$FILE" in \*\.md) ;; \*) exit 0 ;; esac/case "$FILE" in *) ;; esac/'

if [ "$fails" -gt 0 ]; then
  printf '  %s mutation(s) did not behave\n' "$fails"
  exit 1
fi
exit 0
