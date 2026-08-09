#!/usr/bin/env bash
# updater-session-signals-mutants — the mutation battery behind `updater-session-signals`.
# DISTRIBUTION-ONLY.
#
# Usage: run.sh
# Exit:  0 = every mutant moves exactly its own assertions, 1 = one did not, 2 = fixture broken.
#
# WHY IT EXISTS. The shipped fixture has six arms across three disjoint signals, and the
# thing that makes them worth having is that each one covers an invocation path the other
# two cannot see. That claim is only worth as much as a demonstration that removing an arm
# turns exactly its own path red -- otherwise a fixture with three redundant arms and a
# fixture with three load-bearing ones read identically, both green.
#
# WHY IT IS SPLIT OUT (v0.230.0's rule): the battery re-runs the subject fixture once per
# mutant, so held together the pair costs several times the assertions alone, and what a
# unit COSTS is a property of the suite it runs in. It also mutates `ai-dlc-acknowledge.sh`,
# which is CORE's -- `ai-dlc-core-guard.sh` denies a consumer the in-place edit, so the
# surface these mutants perturb cannot change in a consumer tree. The consumer keeps every
# correctness arm and pays for none of this.
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

SUBJ="$HERE/../updater-session-signals/run.sh"
[ -f "$SUBJ" ] || { echo "FIXTURE ERROR: sibling updater-session-signals/run.sh not found" >&2; exit 2; }
if [ -n "$ROOT" ] && [ -f "$ROOT/core/hooks/ai-dlc-acknowledge.sh" ]; then
  HOOK="$ROOT/core/hooks/ai-dlc-acknowledge.sh"
else
  echo "FIXTURE ERROR: core/hooks/ai-dlc-acknowledge.sh not found — this fixture is distribution-only" >&2
  exit 2
fi

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# Build the mutant as a COPY, never an in-place edit, and refuse a sed that matched nothing:
# an unmutated copy runs the subject GREEN and scores as a kill.
mut_reds() { # <label> <sed program, empty for the control> -> the subject's FAIL lines
  local label="$1" prog="$2" copy="$WORK/$1.sh"
  if [ -z "$prog" ]; then
    cp "$HOOK" "$copy"
  else
    sed "$prog" "$HOOK" > "$copy" 2>/dev/null
    if cmp -s "$HOOK" "$copy"; then printf 'UNMUTATED\n'; return 0; fi
  fi
  AI_DLC_USS_HOOK="$copy" bash "$SUBJ" 2>/dev/null | sed -n 's/^  FAIL  //p'
}

expect_set() { # <label> <expected count> <ERE every red must match> <sed>
  local label="$1" want="$2" re="$3" prog="$4" reds n unmatched
  reds="$(mut_reds "$label" "$prog")"
  if [ "$reds" = "UNMUTATED" ]; then
    bad "MUTANT $label: the sed matched nothing — no mutation was applied, so nothing was proven"
    return
  fi
  n="$(printf '%s' "$reds" | grep -c . || true)"
  unmatched="$(printf '%s' "$reds" | grep -vE "$re" | grep -c . || true)"
  if [ "$n" -eq "$want" ] && [ "$unmatched" -eq 0 ]; then
    ok "MUTANT $label moves exactly the $want assertion(s) it should, and no others"
  else
    bad "MUTANT $label: expected $want red(s) matching '$re', got ${n} (${unmatched} unexpected): $(printf '%s' "$reds" | tr '\n' ';')"
  fi
}

echo "updater-session-signals-mutants:"

# THE UNMUTATED CONTROL, first. A mutant copy that dies on its own — a bad edit, a missing
# interpreter, a path the copy cannot resolve — emits no FAIL lines at all, and "no output"
# otherwise scores as a kill for every mutant below it.
CTRL="$(mut_reds control '')"
if [ -z "$CTRL" ]; then
  ok "CONTROL: an unmutated copy of the hook runs the subject fixture GREEN"
else
  bad "CONTROL: an unmutated copy already reds — the harness, not the mutants, is what these arms measure: $(printf '%s' "$CTRL" | tr '\n' ';')"
fi

# 1. THE PAYLOAD ARM, removed whole. It is the only signal that exists at the dispatch
#    itself, and it is also what lets a resume override a stale transcript.
expect_set payload-arm-deleted 2 'PC-S331 is back|stays exempt forever' \
  "/jq -r '\.tool_input\.skill/,/^esac\$/d"

# 2. THE TOOL_USE CASE ARM. Covers everything AFTER the dispatch — the updater's own
#    per-file fan-out, which no payload carries a skill field for.
expect_set tooluse-case-deleted 1 'per-file Agent dispatch was DENIED' \
  '/"skill":"ai-dlc-update".)/d'

# 3. THE COMMAND-NAME ALTERNATIVE. The pre-existing arm, and the ONLY signal a typed
#    invocation produces — a fix that replaced it rather than adding to it would come out
#    green on everything the consumer reported and break the operator's own path.
expect_set marker-alternative-deleted 1 'typed by the operator was DENIED' \
  's#<command-name>/ai-dlc(-update)?</command-name>|##'

# 4. THE PAYLOAD ARM WIDENED to any ai-dlc* skill — the leak that turns the Rule 29 pause
#    off for the pipeline skill it exists to stop.
expect_set payload-arm-widened 2 'exempts ANY Skill call|stays exempt forever' \
  's/ai-dlc-update) UPDATER_SESSION=1/ai-dlc*) UPDATER_SESSION=1/'

# 5. THE PAYLOAD'S NEGATIVE HALF. Granting on `ai-dlc-update` without revoking on `ai-dlc`
#    leaves a session that ever ran the updater exempt for the rest of its life.
expect_set payload-revoke-deleted 1 'stays exempt forever' \
  '/ai-dlc)        UPDATER_SESSION=0/d'

echo
if [ "$fails" -eq 0 ]; then echo "updater-session-signals-mutants: PASS"; exit 0; fi
echo "updater-session-signals-mutants: $fails assertion(s) FAILED" >&2
exit 1
