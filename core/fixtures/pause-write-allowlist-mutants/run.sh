#!/usr/bin/env bash
# pause-write-allowlist-mutants — the mutation battery behind Check 3's WRITE allowlist.
# DISTRIBUTION-ONLY.
#
# Usage: run.sh
# Exit:  0 = every arm is load-bearing and exclusively so, 1 = one is not, 2 = fixture broken.
#
# WHY IT EXISTS. `ai-dlc-acknowledge.sh` Check 3 carries a `case "$FP"` allowlist: four
# carve-out arms that ALLOW a write while the pipeline is paused, and one catch-all that
# DENIES everything else under `_bmad-output/`. Each arm is justified in a paragraph of prose,
# and prose is not a test. Before this battery `divergence-hard-block` asserted TWO of the four
# -- the resolution record and the pipeline snapshot -- plus one negative, and DELETING THE
# `ai-dlc-update/` ARM LEFT THE ENTIRE SUITE GREEN. An arm nothing can kill is an arm nobody
# can tell apart from a comment.
#
# WHAT A KILL IS HERE, AND IT IS THE OPPOSITE SHAPE FROM THE SIBLING BATTERY. Deleting a
# carve-out drops its path through to the catch-all, so the mutation turns exactly one path
# from ALLOW to DENY. A copy that dies on its own emits nothing, `verdict()` reads that as
# ALLOW, and the mutant SURVIVES -- a broken harness scores zero kills, not a full sweep. The
# CONTROL below still runs first, because the exclusivity half of every assertion ("and the
# other three still ALLOW") is precisely the half a dead copy answers green.
#
# WHY IT DOES NOT RE-RUN `divergence-hard-block`. That is the sibling battery's shape and it is
# the wrong shape for this subject. That fixture costs ~38s: nine `seed.sh` calls, each copying
# the convergence validator and shelling out to `sprint-status.sh roll`, and every byte of it
# serves Check 2a -- which sets ADVANCING_TOOL=0 for Write/Edit and adjudicates nothing this
# battery asks about. Six variants of that is ~228s against a ~447s suite pole, spent
# re-deriving an answer one hook invocation gives directly. So the battery drives the hook
# itself, and joins to the shipped fixture on NAMES instead (section 3): an arm must be
# load-bearing AND the shipped suite must be the thing that notices when it stops being.
set -uo pipefail

# HERMETIC -- scrub the operator's tuning before invoking any hook (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"
HOOK=""
[ -n "$ROOT" ] && [ -f "$ROOT/core/hooks/ai-dlc-acknowledge.sh" ] \
  && HOOK="$ROOT/core/hooks/ai-dlc-acknowledge.sh"
[ -n "$HOOK" ] \
  || { echo "FIXTURE ERROR: core/hooks/ai-dlc-acknowledge.sh not found — this fixture is distribution-only" >&2; exit 2; }
SUBJ="$HERE/../divergence-hard-block/run.sh"
[ -f "$SUBJ" ] || { echo "FIXTURE ERROR: sibling divergence-hard-block/run.sh not found" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq is required" >&2; exit 2; }

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# A PAUSED project with a live pipeline and NO adversarial series: the tree that reaches Check
# 3, which is the only check under test. Same shape as the sibling `updater-session-signals`,
# deliberately NOT `divergence-hard-block/seed.sh` -- that seed builds a pass series, copies
# the validator and rolls a sprint envelope, all of it for Check 2a, which never adjudicates a
# Write. Paying ~38s for state the subject never reads is how a battery becomes the suite pole.
W="$WORK/tree"
mkdir -p "$W/_bmad-output/planning-artifacts/s7" "$W/scripts/ai-dlc"
: > "$W/_bmad-output/pipeline-snapshot.md"
: > "$W/_bmad-output/pipeline-paused.flag"
printf '#!/bin/sh\necho 7\n' > "$W/scripts/ai-dlc/sprint-status.sh"
chmod +x "$W/scripts/ai-dlc/sprint-status.sh"

# THE FOUR CARVE-OUTS AND THE NEGATIVE, in one table. The negative is not decoration: "arm 2
# still allows" means nothing unless SOMETHING under _bmad-output/ is still denied, and the
# `carve-out-widened` mutant in section 2 is what proves this negative can itself go red -- a
# negative that cannot fail is the vacuous assertion this whole file exists to make impossible.
PROBE_NAME=( updater record snapshot history other )
PROBE_TOOL=( Write Write Edit Edit Write )
PROBE_PATH=(
  _bmad-output/ai-dlc-update/reconcile-report.md
  _bmad-output/planning-artifacts/s7/brief-resolution-p2.md
  _bmad-output/pipeline-snapshot.md
  _bmad-output/pipeline-snapshot-history.md
  _bmad-output/planning-artifacts/product-brief.md
)
BASELINE='ALLOW ALLOW ALLOW ALLOW DENY'

verdict() { # <hook copy> <tool> <relative path> -> ALLOW | DENY
  local out
  out="$(printf '{"session_id":"t","transcript_path":"","tool_name":"%s","tool_input":{"file_path":"%s"}}' \
           "$2" "$W/$3" | CLAUDE_PROJECT_DIR="$W" bash "$1" 2>/dev/null)"
  case "$out" in
    *'"permissionDecision": "deny"'*|*'"permissionDecision":"deny"'*) printf 'DENY' ;;
    *) printf 'ALLOW' ;;
  esac
}

row() { # <hook copy> -> the five verdicts in PROBE order, space separated
  local h="$1" i out=""
  for i in 0 1 2 3 4; do out="$out $(verdict "$h" "${PROBE_TOOL[$i]}" "${PROBE_PATH[$i]}")"; done
  printf '%s' "${out# }"
}

echo "pause-write-allowlist-mutants:"

# =============================================================================
# 0. THE UNMUTATED CONTROL, first.
# =============================================================================
# A copy that dies -- a bad edit, a missing interpreter, a path the copy cannot resolve --
# emits nothing, and nothing reads as ALLOW. Every "and the other arms still allow" clause
# below would then pass over a hook that never ran. Establish that an untouched copy answers
# the baseline before reading any mutant's answer as evidence.
cp "$HOOK" "$WORK/control.sh"
CTRL="$(row "$WORK/control.sh")"
if [ "$CTRL" = "$BASELINE" ]; then
  ok "CONTROL: an unmutated copy allows all four carve-outs and denies everything else under _bmad-output/"
else
  bad "CONTROL: an unmutated copy answers '$CTRL' over (${PROBE_NAME[*]}), not '$BASELINE' — the harness, not the mutants, is what the arms below measure"
fi

# =============================================================================
# 1. ONE ARM PER CARVE-OUT, DELETED WHOLE.
# =============================================================================
ARM_NAME=( arm1-updater-scratch-deleted arm2-resolution-record-deleted arm3-pipeline-snapshot-deleted arm4-snapshot-history-deleted )
ARM_LIT=(  'ai-dlc-update/*) ;;'        '-resolution-p*.md) ;;'        'pipeline-snapshot.md) ;;'     'pipeline-snapshot-history.md) ;;' )
ARM_SED=(  '/ai-dlc-update\/\*) ;;/d'   '/-resolution-p\*\.md) ;;/d'   '/pipeline-snapshot\.md) ;;/d' '/pipeline-snapshot-history\.md) ;;/d' )
ARM_WANT=( 'DENY ALLOW ALLOW ALLOW DENY'
           'ALLOW DENY ALLOW ALLOW DENY'
           'ALLOW ALLOW DENY ALLOW DENY'
           'ALLOW ALLOW ALLOW DENY DENY' )

for i in 0 1 2 3; do
  label="${ARM_NAME[$i]}"; lit="${ARM_LIT[$i]}"; copy="$WORK/$label.sh"

  # REVERT EVERY LAYER. A one-line delete proves only the layer it leaves standing: if the
  # same path were also allowed by a second, wider arm -- a `pipeline-snapshot*` glob added
  # "while we were in there" -- deleting this line would change nothing and the mutant would
  # come out green while the arm it names is dead weight. Assert the carve-out is spelled ONCE
  # before assuming one deletion reverts it. Zero hits is the other half: an arm this battery
  # names and the hook does not carry is a missing carve-out, not a passing mutant.
  n_arm="$(grep -cF -- "$lit" "$HOOK" || true)"
  if [ "$n_arm" -ne 1 ]; then
    bad "MUTANT $label: '$lit' appears $n_arm time(s) in the hook, not once. A layered carve-out is not reverted by deleting one line, and an absent one has no mutant to run."
    continue
  fi

  # Build the mutant as a COPY, never an in-place edit, and refuse a sed that matched nothing:
  # an unmutated copy answers the baseline and scores a survival on every clause.
  sed "${ARM_SED[$i]}" "$HOOK" > "$copy" 2>/dev/null
  if cmp -s "$HOOK" "$copy"; then
    bad "MUTANT $label: the sed matched nothing — no mutation was applied, so nothing was proven"
    continue
  fi
  # ...and refuse a MULTI-LINE delete. `cmp -s` only proves SOMETHING moved. A program that
  # took out two arms turns two paths red, fails two assertions, and reads as "entangled
  # assertions" when the truth is a bad mutation program. One line in, one line out.
  d=$(( $(wc -l < "$HOOK") - $(wc -l < "$copy") ))
  if [ "$d" -ne 1 ]; then
    bad "MUTANT $label: the sed deleted $d lines, not 1 — a mutant that removes more than its own arm cannot fail only its own assertion"
    continue
  fi

  got="$(row "$copy")"
  if [ "$got" = "${ARM_WANT[$i]}" ]; then
    ok "MUTANT $label turns exactly \`${PROBE_PATH[$i]}\` from ALLOW to DENY, and moves no other path"
  else
    bad "MUTANT $label: expected '${ARM_WANT[$i]}' over (${PROBE_NAME[*]}), got '$got'"
  fi
done

# =============================================================================
# 2. THE CARVE-OUT WIDENED — the negative must be able to go red.
# =============================================================================
# The direction that costs more. An arm that misfires denies a write the operator can retry;
# an arm that LEAKS turns the Rule 29 pause off for artifact production, and the pause exists
# because the lead will otherwise work straight through a waiting human. This widens arm 2 from
# `*-resolution-p*.md` to every file in planning-artifacts/ -- the plausible "simplify the
# glob" edit -- and the only thing that may move is the negative.
sed 's#planning-artifacts/\*-resolution-p\*\.md#planning-artifacts/*#g' "$HOOK" > "$WORK/carve-out-widened.sh" 2>/dev/null
if cmp -s "$HOOK" "$WORK/carve-out-widened.sh"; then
  bad "MUTANT carve-out-widened: the sed matched nothing — the negative assertion is unproven, and an unfalsifiable negative is what section 1 leans on"
else
  got="$(row "$WORK/carve-out-widened.sh")"
  if [ "$got" = 'ALLOW ALLOW ALLOW ALLOW ALLOW' ]; then
    ok "MUTANT carve-out-widened turns \`product-brief.md\` from DENY to ALLOW: the negative is falsifiable, so 'still denies' above means something"
  else
    bad "MUTANT carve-out-widened: expected 'ALLOW ALLOW ALLOW ALLOW ALLOW' over (${PROBE_NAME[*]}), got '$got'"
  fi
fi

# =============================================================================
# 3. THE JOIN — a load-bearing arm the SHIPPED suite does not assert is still uncovered.
# =============================================================================
# Sections 1-2 prove the arms are load-bearing IN THE HOOK. They do not prove any consumer
# would find out: this battery is `.dist-only` and never runs there. `divergence-hard-block` is
# the shipped fixture that drives this allowlist, so every carve-out must be named in it. This
# is deliberately a NAME join and not a re-run -- re-running the subject once per mutant is the
# ~228s the header refuses -- and it is the exact gap that let arm 1 sit uncovered: the arm
# existed, the prose explained it, and no fixture anywhere mentioned the path.
for i in 0 1 2 3; do
  if grep -qF -- "${PROBE_PATH[$i]#_bmad-output/}" "$SUBJ"; then
    ok "the shipped subject asserts the \`${PROBE_NAME[$i]}\` carve-out by name (a consumer's suite goes red when it is removed)"
  else
    bad "\`${PROBE_NAME[$i]}\` (${PROBE_PATH[$i]}) is load-bearing but divergence-hard-block never names it: the arm is proven here, in a fixture no consumer receives, and nowhere a consumer runs"
  fi
done

echo
if [ "$fails" -eq 0 ]; then echo "pause-write-allowlist-mutants: PASS"; exit 0; fi
echo "pause-write-allowlist-mutants: $fails assertion(s) FAILED" >&2
exit 1
