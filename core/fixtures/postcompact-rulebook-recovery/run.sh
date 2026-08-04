#!/usr/bin/env bash
# postcompact-rulebook-recovery/run.sh — prove a compacted lead is told to recover the
# three quarters of its rulebook that the harness threw away, and that the telling cannot
# be deleted silently.
#
# THE DEFECT. Claude Code re-attaches only the first ~5,000 tokens of an invoked skill after
# a compaction. Nothing in the pipeline re-read SKILL.md: the three compaction hooks carried
# zero references to it, and Rules 21/22's re-read mandates name STEP files and the snapshot.
# The protocol's own remedy was to ask the OPERATOR to re-invoke `/ai-dlc`, gated on the lead
# first NOTICING that rules were missing.
#
# WHY THAT GATE CANNOT CLOSE. Measured over the reference consumer's 379 transcripts: 69 hold
# a `compact_boundary`, 261 post-boundary records carry a real re-attach, and the cut lands at
# 20,121 bytes in every one — identical at p10 through p90. That is under a quarter of the
# file. Most numbered rules, the handoff triggers and the snapshot schema are gone, INCLUDING
# the rules that mandate re-reading, so the instruction to recover them cannot come from a
# rule the lead still holds. Nothing marks where the cut fell. A lead cannot notice a rule it
# has never seen, and a rule it never saw is indistinguishable from one that does not exist.
#
# THE TWO ENDS. The hook DELIVERS the instruction at the moment of compaction; the validator
# REFUSES to ship a protocol that does not carry it. Either alone is a check that cannot fire:
# a hook nobody guards can lose the paragraph in a reword, and a validator guarding prose that
# never reaches the lead guards nothing.
set -uo pipefail

# The pre-push gate inherits every AI_DLC_* tunable a consumer set in settings.json. A fixture
# that drives a hook while inheriting them tests the CONFIG, not the code (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }

# Drive the hook exactly as the harness does: JSON on stdin, source=compact.
fire() { # <hook-path> -> prints additionalContext
  printf '{"source":"compact","session_id":"fixture"}' \
    | CLAUDE_PROJECT_DIR="$PROJECT" bash "$1" 2>/dev/null \
    | python3 -c 'import sys,json
try: print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])
except Exception: pass'
}

echo "postcompact-rulebook-recovery:"

# --- Assertion 0: SANITY — the hook produces a directive at all ---------------
# Without a snapshot the hook exits before building anything and every assertion about its
# TEXT would pass on an empty string, scoring silence as compliance.
CTX="$(fire "$HOOK")"
if [ -n "$CTX" ] && grep -q 'POST-COMPACT RECOVERY' <<<"$CTX"; then
  ok "seed: the hook emitted a recovery directive ($(printf '%s' "$CTX" | wc -c | tr -d ' ') chars)"
else
  bad "FIXTURE BROKEN — the hook emitted no directive; every text assertion below is vacuous"
  echo; echo "postcompact-rulebook-recovery: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 1: the directive names the skill file by its INSTALLED path ----
# The consumer path, not core/. A lead handed `core/skills/...` on a consumer tree gets a
# Read that fails, which reads to it as "the file is gone" rather than "the path is wrong".
if grep -q '\.claude/skills/ai-dlc/SKILL\.md' <<<"$CTX"; then
  ok "directive names .claude/skills/ai-dlc/SKILL.md — the path that resolves on a consumer"
else
  bad "the directive never names the installed SKILL.md path; the lead has nothing to Read"
fi

# --- Assertion 2: it demands the WHOLE file, not a look ----------------------
# "Check whether rules are missing" is the instruction that already failed — it asks the lead
# to detect an absence it structurally cannot see.
if grep -qi 'IN FULL' <<<"$CTX"; then
  ok "directive demands the file IN FULL, not a spot check for what looks missing"
else
  bad "the directive does not demand a full read; a partial read leaves the same silent gap"
fi

# --- Assertion 3: it does NOT fall back to asking the operator ---------------
# The old remedy. If it survives anywhere in the directive the lead has a sanctioned way to
# do nothing, and it will take it — the ask costs it a turn and the Read costs it tokens.
if grep -q 'do not ask the operator to re-invoke' <<<"$CTX"; then
  ok "the directive explicitly closes the ask-the-operator escape"
else
  bad "the ask-the-operator fallback is not closed; the lead can satisfy the directive by asking a human instead of reading a file that is already on disk"
fi

# --- Assertion 4: the block still fits under the harness's 10,000-char cliff --
# THE REGRESSION THIS FIXTURE MOST NEEDS. v0.35.0 shipped a hook emitting 31,881 characters;
# Claude Code replaced the whole thing with a file-path stub, so the snapshot directive was
# NEVER injected on any of three observed compactions. Adding prose to this hook is exactly
# how that recurs, and it recurs SILENTLY — the hook exits 0 either way.
LEN="$(printf '%s' "$CTX" | wc -c | tr -d ' ')"
if [ "$LEN" -lt 9000 ]; then
  ok "directive is ${LEN} chars, under the 9000 ceiling (10000 cliff - 1000 margin)"
else
  bad "directive is ${LEN} chars, at or past the 9000 ceiling — the harness will replace the ENTIRE block with a file-path stub and nothing gets injected"
fi

# --- Assertion 5: the hook records degraded=no -------------------------------
# The hook's own self-report. If it ever disagrees with assertion 4, one of the two is
# measuring something other than what ships.
if grep -q '^degraded=no$' "$PROJECT/_bmad-output/.recover-fired" 2>/dev/null; then
  ok "the hook's marker reports degraded=no"
else
  bad "the hook reported degraded=yes (or wrote no marker) — its injection did not land intact"
fi

# --- Assertion 6: the SHIPPED SKILL.md carries the mandate in its protocol ----
# The validator's new arm, run against the real file. This is the half that survives a
# consumer whose hooks are disabled.
if bash "$VAL" --skill "$SKILL" --quiet >/dev/null 2>&1; then
  ok "validate-reattach-budget.sh passes the shipped SKILL.md (budget AND mandate)"
else
  bad "the shipped SKILL.md fails its own re-attach budget validator"
fi

# --- Assertion 7: MUTANT — strip the mandate from SKILL.md, arm 6 must fail ---
# Built as a COPY, guarded by cmp -s so a sed that matched nothing cannot pass as a mutation.
MUT_SKILL="$WORK/skill-no-mandate.md"
sed 's|`Read \.claude/skills/ai-dlc/SKILL\.md` IN FULL|the lead may wish to review the rules|' \
  "$SKILL" > "$MUT_SKILL"
if cmp -s "$SKILL" "$MUT_SKILL"; then
  bad "FIXTURE STALE: the mandate sentence was reworded, so the mutant is a byte-identical copy and assertion 6 proves nothing"
else
  out="$(bash "$VAL" --skill "$MUT_SKILL" --quiet 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ] && grep -q 'does not tell the lead to re-read' <<<"$out"; then
    ok "mutant: a protocol without the mandate FAILS, on the mandate arm specifically"
  elif [ "$rc" -ne 0 ]; then
    bad "MUTANT FAILED ON THE WRONG ARM — it tripped the byte-budget instead of the mandate check, so the two assertions are entangled and one is vacuous. Output: $(head -1 <<<"$out")"
  else
    bad "MUTANT DID NOT FAIL — SKILL.md passes with the re-read mandate removed, so assertion 6 asserts nothing"
  fi
fi

# --- Assertion 8: MUTANT — strip the mandate from the HOOK, arms 1-3 must fail
# The other end of the join. A validator that guards SKILL.md's prose does not notice the
# hook losing the same instruction, and the hook is the copy the lead actually reads.
MUT_HOOK="$WORK/recover-no-mandate.sh"
awk '!/skills\/ai-dlc\/SKILL\.md/' "$HOOK" > "$MUT_HOOK"
if cmp -s "$HOOK" "$MUT_HOOK"; then
  bad "FIXTURE STALE: could not build the no-mandate hook mutant — the skill path moved"
elif ! bash -n "$MUT_HOOK" 2>/dev/null; then
  # cmp proves a mutation happened; bash -n proves the mutant is still a PROGRAM. A mutant
  # that dies before doing anything emits nothing, and "no output" otherwise scores as a kill.
  bad "FIXTURE STALE: the hook mutant is not valid shell, so its silence would score as a kill"
else
  MCTX="$(fire "$MUT_HOOK")"
  if [ -n "$MCTX" ] && ! grep -q '\.claude/skills/ai-dlc/SKILL\.md' <<<"$MCTX"; then
    ok "mutant: the hook still emits a directive but no longer names the skill — assertions 1-3 can fail"
  elif [ -z "$MCTX" ]; then
    bad "MUTANT EMITTED NOTHING — its silence is indistinguishable from a kill, so assertions 1-3 are unproven"
  else
    bad "MUTANT DID NOT FAIL — the directive still names the skill with the mandate stripped"
  fi
fi

# --- Assertion 9: UNMUTATED CONTROL ------------------------------------------
# The hook resolves paths and shells out; a lone copy in a temp root can die for reasons that
# have nothing to do with a mutation. If this copy does not reproduce the real verdict, every
# mutant result above is uninterpretable.
CTRL="$WORK/recover-control.sh"
cp "$HOOK" "$CTRL"
CCTX="$(fire "$CTRL")"
if [ -n "$CCTX" ] && grep -q '\.claude/skills/ai-dlc/SKILL\.md' <<<"$CCTX"; then
  ok "control: an unmutated copy reproduces the real directive — the mutants above failed on their mutation"
else
  bad "CONTROL FAILED — an unmutated copy does not reproduce the real directive, so the mutant kills above prove nothing about the mutations"
fi

echo
if [ "$fails" -eq 0 ]; then echo "postcompact-rulebook-recovery: PASS"; exit 0; fi
echo "postcompact-rulebook-recovery: $fails assertion(s) FAILED" >&2
exit 1
