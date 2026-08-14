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
skip() { # skip <what> <why> — tolerated only where the subject legitimately has not arrived
  if [ "${IS_DIST:-0}" = 1 ]; then bad "$1 -- $2 (HARD in the distribution: the subject must be present here)"
  else printf '  SKIP  %s -- %s\n' "$1" "$2"; fi
}

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

# --- Assertion 2b: the two mandatory Reads carry the SAME grade --------------
# Measured across 265 real compactions: the snapshot Read, written
# "**Your FIRST tool call MUST be**", landed 66% of the time; the step-file Read, written
# "Then `Read` the current step file", landed 41%. Both instructions were in THIS block, so
# rule loss cannot explain the gap -- the wording can. Derived rather than hand-matched: count
# the bolded tool-call mandates and require BOTH, so demoting either one fails here.
GRADE="$(grep -c '\*\*Your [A-Z]* tool call MUST be' <<<"$CTX")"
if [ "$GRADE" -ge 2 ]; then
  ok "both mandatory Reads carry a bolded MUST grade (found ${GRADE})"
else
  bad "only ${GRADE} bolded tool-call mandate(s); the step-file Read was demoted below the snapshot's grade and it is the one already running 25 points behind"
fi

# --- Assertion 2c: Rule 23 is CARRIED, not left to a rule the lead lost -------
# Rule 23 is the one rule whose absence causes the event that removes it: ctx_* calls per 1k
# assistant turns run 8.88 in sessions that never compacted and 0.67 after one, so each
# compaction makes the next likelier. Prose cannot fix it -- the prose is what is gone.
if grep -q 'ctx_execute_file' <<<"$CTX" && grep -q 'Rule 23' <<<"$CTX"; then
  ok "Rule 23's discipline is carried in the directive, naming a concrete tool"
else
  bad "Rule 23 has no carrier in the directive; it is past the re-attach cut, so nothing in the lead's context asks it to keep context small — and that is the self-amplifying one"
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

# --- Assertion 8b: MUTANT — demote the step-file Read, only 2b may go red -----
# The entanglement test for the grade arm. Demoting the sentence must not disturb the path,
# IN FULL, escape-closed, cliff or Rule 23 assertions -- if it does, 2b is not measuring grade.
MUT_G="$WORK/recover-demoted.sh"
sed 's|\*\*Your SECOND tool call MUST be \\`Read \${STEP_FILE}\\` in full\.\*\*|Then \\`Read\\` the current step file \\`\${STEP_FILE}\\` --|' "$HOOK" > "$MUT_G"
if cmp -s "$HOOK" "$MUT_G"; then
  bad "FIXTURE STALE: the step-file mandate was reworded, so the demotion mutant is byte-identical and assertion 2b proves nothing"
elif ! bash -n "$MUT_G" 2>/dev/null; then
  bad "FIXTURE STALE: the demotion mutant is not valid shell, so its silence would score as a kill"
else
  GCTX="$(fire "$MUT_G")"
  g="$(grep -c '\*\*Your [A-Z]* tool call MUST be' <<<"$GCTX")"
  keeps=0
  grep -q '\.claude/skills/ai-dlc/SKILL\.md' <<<"$GCTX" && keeps=$((keeps+1))
  grep -q 'ctx_execute_file' <<<"$GCTX" && keeps=$((keeps+1))
  grep -q 'do not ask the operator to re-invoke' <<<"$GCTX" && keeps=$((keeps+1))
  if [ -n "$GCTX" ] && [ "$g" -lt 2 ] && [ "$keeps" -eq 3 ]; then
    ok "mutant: demoting the step-file Read fails ONLY the grade arm — the assertions are not entangled"
  elif [ "$g" -ge 2 ]; then
    bad "MUTANT DID NOT FAIL — the grade arm still counts 2 mandates with the sentence demoted, so assertion 2b asserts nothing"
  else
    bad "MUTANT FAILED TOO MUCH — the demotion also broke $((3-keeps)) unrelated assertion(s), so 2b and they are entangled and one is vacuous"
  fi
fi

# --- Assertion 8c: MUTANT — push the block past the cliff, only 4 may go red --
# THE regression that matters. Every arm above ADDS prose to a block the harness replaces
# wholesale at 10,000 characters. This proves assertion 4 can actually fail.
MUT_C="$WORK/recover-oversize.sh"
awk '/^# AI\/DLC POST-COMPACT RECOVERY/ && !d {print; for(i=0;i<400;i++) print "padding line to push the injected block past the ten-thousand character cliff"; d=1; next} 1' "$HOOK" > "$MUT_C"
if cmp -s "$HOOK" "$MUT_C"; then
  bad "FIXTURE STALE: could not build the oversize mutant — the directive heading moved"
elif ! bash -n "$MUT_C" 2>/dev/null; then
  bad "FIXTURE STALE: the oversize mutant is not valid shell, so its silence would score as a kill"
else
  OCTX="$(fire "$MUT_C")"
  OLEN="$(printf '%s' "$OCTX" | wc -c | tr -d ' ')"
  if [ -n "$OCTX" ] && [ "$OLEN" -ge 9000 ]; then
    ok "mutant: an oversize directive is ${OLEN} chars and trips the cliff arm — assertion 4 can fail"
  else
    bad "MUTANT DID NOT FAIL — the padded directive measured ${OLEN} chars, under the ceiling, so assertion 4 never proves the cliff is watched"
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

# =============================================================================
# THE GATE — ai-dlc-recover-gate.sh
#
# Everything above proves the mandate is DELIVERED. Nothing above observes whether it was
# OBEYED, and that is the gap the reference consumer filed as
# PC-S303-POSTCOMPACT-RECOVERY-MANDATE-HAS-NO-STATED-EXCEPTION: one session skipped both
# mandated Reads twice silently, then stopped 773 of 1210 lines into the third.
#
# THE PROPERTY MOST OF THESE ARMS PROTECT IS NOT THE DENY. A PreToolUse hook with a deny path
# and a wrong arming condition does not fail loudly — it refuses every call the lead can make
# and the session is over. So the gate stands down in four states (no marker, an unresolvable
# step file, a mandated path missing, a marker written before it existed), and FOUR of the
# seven predicates below assert a stand-down rather than a deny.
#
# EVERY ONE OF THOSE IS ABSENCE-SHAPED: it passes when nothing fires, which is exactly what a
# gate replaced by `exit 0` also does. A seeded near-miss cannot tell those apart. So each
# predicate is a FUNCTION, run against the real gate for the arm and re-run against every
# mutant for the kill, and the mutant arms assert the exact SET of predicates that flips.
# A mutant that flips more than its own set means two arms are entangled and one is vacuous;
# a mutant that flips nothing means the arms it was built for cannot fire at all.
# =============================================================================

if [ -z "${GATE:-}" ]; then
  skip "gate arms" "ai-dlc-recover-gate.sh is in neither layout; this fixture ships one pull ahead of its subject"
elif ! command -v jq >/dev/null 2>&1; then
  skip "gate arms" "jq is absent, and the gate exits silently without it — every deny arm below would read as a stand-down"
else

# --- the harness ------------------------------------------------------------
# One gate invocation per call, because a call MUTATES gate state (the snapshot Read advances
# it). Reading the decision and the reason with two runs would double every transition.
gate_call() { # gate_call <gate> <project> <json> -> "<decision>|<reason on one line>"
  printf '%s' "$3" \
    | CLAUDE_PROJECT_DIR="$2" bash "$1" 2>/dev/null \
    | python3 -c 'import sys,json
try:
    o = json.load(sys.stdin)["hookSpecificOutput"]
    print(o.get("permissionDecision","") + "|" + o.get("permissionDecisionReason","").replace("\n"," "))
except Exception:
    print("|")'
}
allowed() { case "$1" in "|"*) return 0 ;; *) return 1 ;; esac; }

jcall() { # jcall <tool> <file_path|-> — `-` is a tool that carries no file_path at all
  if [ "$2" = "-" ]; then printf '{"tool_name":"%s","tool_input":{"command":"ls -la"}}' "$1"
  else printf '{"tool_name":"%s","tool_input":{"file_path":"%s"}}' "$1" "$2"; fi
}

# A fresh project per scenario. The gate's whole state is two dotfiles under _bmad-output/, so
# scenarios that shared a root would silently inherit each other's progress.
newproj() { # newproj <step-file-name|-> <create-that-file:yes|no> -> project dir
  _p="$(mktemp -d "$WORK/proj.XXXXXX")" || return 1
  mkdir -p "$_p/_bmad-output"
  {
    printf '# Pipeline Snapshot\n\n## Pipeline Position\n'
    [ "$1" != "-" ] && printf 'current_step_file: `%s`\n' "$1"
    printf 'last_gate_passed: planning-gate-2 @ 2026-08-04T10:00:00Z\n'
  } > "$_p/_bmad-output/pipeline-snapshot.md"
  [ "$2" = yes ] && printf 'step body\n' > "$_p/$1"
  printf 'in-flight edit work\n' > "$_p/decoy.md"
  printf '%s\n' "$_p"
}

# The marker is written by the REAL producer, never by hand. A hand-written marker would prove
# the gate accepts the grammar this fixture invented for it.
arm_marker() { # arm_marker <recover-hook> <project>
  printf '{"source":"compact","session_id":"fixture"}' \
    | CLAUDE_PROJECT_DIR="$2" bash "$1" >/dev/null 2>&1
}
mk="_bmad-output/.recover-fired"
pg="_bmad-output/.recover-gate-progress"

# --- the seven predicates ---------------------------------------------------
# Each prints PASS, or FAIL:<what it saw>. The arm prints the detail; the mutant arms keep
# only PASS/FAIL.

# 1. An ordinary tool call in an ordinary session. Overwhelmingly the common case: no
#    compaction is pending recovery, so the gate must not even look at the call.
p_inert() {
  _p="$(newproj architecture.md yes)"
  d="$(gate_call "$1" "$_p" "$(jcall Edit "$_p/decoy.md")")"
  allowed "$d" || { printf 'FAIL:denied an ordinary call in an unarmed session (%s)\n' "${d%%|*}"; return; }
  [ -e "$_p/$pg" ] && { printf 'FAIL:wrote gate progress in a session with no marker\n'; return; }
  [ -e "$_p/$mk" ] && { printf 'FAIL:invented a recovery marker\n'; return; }
  printf 'PASS\n'
}

# 2. Armed, and the first call is not one of the mandated Reads. Three shapes, because the
#    filed incident was a lead "continuing straight into in-flight edit work" and a gate that
#    only understood Read calls would have waved it through.
p_deny_first() {
  _p="$(newproj architecture.md yes)"; arm_marker "$HOOK" "$_p"
  for _c in "Edit:$_p/decoy.md" "Bash:-" "Read:$_p/decoy.md"; do
    d="$(gate_call "$1" "$_p" "$(jcall "${_c%%:*}" "${_c#*:}")")"
    allowed "$d" && { printf 'FAIL:%s was allowed as the first post-compact call\n' "${_c%%:*}"; return; }
    grep -q 'FIRST tool call must be' <<<"${d#*|}" || { printf 'FAIL:%s was denied without naming the mandated first Read\n' "${_c%%:*}"; return; }
    grep -q 'pipeline-snapshot\.md' <<<"${d#*|}" || { printf 'FAIL:the deny reason for %s names no path to comply with\n' "${_c%%:*}"; return; }
  done
  [ -e "$_p/$pg" ] && { printf 'FAIL:a denied call advanced the gate\n'; return; }
  printf 'PASS\n'
}

# 3/4. The compliance ladder, once per SPELLING. Both mandated paths are recorded relative to
#    the project root, and a lead may issue either spelling; a gate matching one of them denies
#    a compliant call, which is a wedge wearing a different hat. `abs` and `rel` are separate
#    predicates so a mutation that breaks one spelling is not hidden by the other passing.
p_ladder() { # p_ladder <gate> <abs|rel>
  _p="$(newproj architecture.md yes)"; arm_marker "$HOOK" "$_p"
  case "$2" in
    abs) s="$_p/_bmad-output/pipeline-snapshot.md"; f="$_p/architecture.md" ;;
    *)   s="_bmad-output/pipeline-snapshot.md";     f="architecture.md" ;;
  esac
  d="$(gate_call "$1" "$_p" "$(jcall Read "$s")")"
  allowed "$d" || { printf 'FAIL:%s: denied the mandated snapshot Read\n' "$2"; return; }
  [ "$(cat "$_p/$pg" 2>/dev/null)" = step ] || { printf 'FAIL:%s: the mandated snapshot Read did not advance the gate\n' "$2"; return; }
  d="$(gate_call "$1" "$_p" "$(jcall Read "$f")")"
  allowed "$d" || { printf 'FAIL:%s: denied the mandated step-file Read\n' "$2"; return; }
  [ -e "$_p/$mk" ] && { printf 'FAIL:%s: both mandated Reads happened and the gate stayed armed\n' "$2"; return; }
  [ -e "$_p/$pg" ] && { printf 'FAIL:%s: progress state survived the disarm\n' "$2"; return; }
  d="$(gate_call "$1" "$_p" "$(jcall Edit "$_p/decoy.md")")"
  allowed "$d" || { printf 'FAIL:%s: denied an ordinary call after both mandated Reads\n' "$2"; return; }
  printf 'PASS\n'
}

# 5. The snapshot names no step file the producer could resolve. There is then no single call
#    the gate could demand, so it must not arm — and it must LEAVE the marker, which is
#    ai-dlc-postcompact.sh's record that the injection happened.
p_standdown_r0() {
  _p="$(newproj - no)"; arm_marker "$HOOK" "$_p"
  grep -q '^step_file_resolved=0$' "$_p/$mk" 2>/dev/null \
    || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE — this snapshot still resolved a step file\n'; return; }
  d="$(gate_call "$1" "$_p" "$(jcall Edit "$_p/decoy.md")")"
  allowed "$d" || { printf 'FAIL:armed on a mandate that names no path, denying every call the lead can make\n'; return; }
  [ -e "$_p/$mk" ] || { printf 'FAIL:destroyed the injection record it had no business arming on\n'; return; }
  printf 'PASS\n'
}

# 6. The step file resolved but is not on disk. Denying a Read of something absent is the
#    unrecoverable wedge, so the gate stands down AND CLEARS the marker so it cannot re-arm on
#    the next call. The second call is the arm: clearing is what makes the stand-down permanent.
p_standdown_missing() {
  _p="$(newproj architecture.md no)"; arm_marker "$HOOK" "$_p"
  grep -q '^step_file_resolved=1$' "$_p/$mk" 2>/dev/null \
    || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE — the step file did not resolve, so this is the r0 case\n'; return; }
  d="$(gate_call "$1" "$_p" "$(jcall Edit "$_p/decoy.md")")"
  allowed "$d" || { printf 'FAIL:denied a call while demanding a Read of a file that is not there\n'; return; }
  [ -e "$_p/$mk" ] && { printf 'FAIL:stood down but left the marker, so the next call re-arms on the same absent file\n'; return; }
  d="$(gate_call "$1" "$_p" "$(jcall Edit "$_p/decoy.md")")"
  allowed "$d" || { printf 'FAIL:the second call was denied — the stand-down did not hold\n'; return; }
  printf 'PASS\n'
}

# 7. A marker written before these keys existed. An older marker is not evidence about a
#    mandate it never recorded, and a consumer mid-upgrade has exactly one of these on disk.
p_legacy() {
  [ -n "${LEGACY_PRODUCER:-}" ] || { printf 'FAIL:FIXTURE STALE — no legacy producer was built\n'; return; }
  _p="$(newproj architecture.md yes)"; arm_marker "$LEGACY_PRODUCER" "$_p"
  grep -qE '^(snapshot_path|step_file|step_file_resolved)=' "$_p/$mk" 2>/dev/null \
    && { printf 'FAIL:SEED CANNOT EXPRESS THE CASE — the legacy marker still carries the new keys\n'; return; }
  grep -q '^fired_at=' "$_p/$mk" 2>/dev/null \
    || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE — the legacy producer wrote no marker at all\n'; return; }
  d="$(gate_call "$1" "$_p" "$(jcall Edit "$_p/decoy.md")")"
  allowed "$d" || { printf 'FAIL:armed on a marker that records none of the state it arms on\n'; return; }
  [ -e "$_p/$mk" ] || { printf 'FAIL:deleted a marker it could not interpret\n'; return; }
  printf 'PASS\n'
}

# 8. THE MARKER FAST-PATH, ASSERTED ON COST BECAUSE IT HAS NO VERDICT.
#    `[ -f "$MARKER" ] || exit 0` flips NOTHING when deleted: with the marker absent every
#    `mval` returns empty and the key checks stand the gate down for the same cases. It was
#    a mutant here that established that. So the line is not a behavioural guard and an arm
#    looking for a decision change could never fire on it.
#
#    Its real subject is COST. This gate is registered against EVERY tool, so that line is
#    what keeps an ordinary call in an ordinary session from doing any work at all.
#
#    THE SIGNAL IS `sed`, AND PICKING IT WAS THE WHOLE DIFFICULTY. The obvious choice, `jq`,
#    is WRONG and measured wrong: `command -v jq` is a builtin lookup that executes nothing,
#    and the gate's first real `jq` call sits BELOW the stand-down checks — so an unarmed call
#    forks no jq whether the fast-path is there or not, and the arm passed against its own
#    mutant. `mval` is the first thing past the line that forks, so `sed` is the first
#    observable the line actually gates.
p_fastpath() {
  _p="$(newproj architecture.md yes)"
  _b="$WORK/shim.$$"; rm -rf "$_b"; mkdir -p "$_b"
  _sent="$_p/sed-was-called"
  _real="$(command -v sed)"
  { printf '#!/usr/bin/env bash\n'
    printf 'printf x >> "%s"\n' "$_sent"
    printf 'exec %s "$@"\n' "$_real"
  } > "$_b/sed"
  chmod +x "$_b/sed"

  # unarmed: no marker, so the gate must return before it parses anything
  PATH="$_b:$PATH" gate_call "$1" "$_p" "$(jcall Edit "$_p/decoy.md")" >/dev/null 2>&1
  [ -e "$_sent" ] && { printf 'FAIL:did work on an ordinary call in a session with no recovery pending\n'; return; }

  # CONTROL: armed, the gate must reach the parser — otherwise the absence above proves only
  # that the shim was never reachable, which is what a dead arm looks like.
  arm_marker "$HOOK" "$_p"
  PATH="$_b:$PATH" gate_call "$1" "$_p" "$(jcall Edit "$_p/decoy.md")" >/dev/null 2>&1
  [ -e "$_sent" ] || { printf 'FAIL:the sed shim was never reached even when armed, so the unarmed result proves nothing\n'; return; }
  printf 'PASS\n'
}

PREDS="inert deny_first ladder_abs ladder_rel standdown_r0 standdown_missing legacy fastpath"
verdicts() { # verdicts <gate> -> "name=PASS" lines, in PREDS order
  for _n in $PREDS; do
    case "$_n" in
      ladder_abs) r="$(p_ladder "$1" abs)" ;;
      ladder_rel) r="$(p_ladder "$1" rel)" ;;
      *)          r="$("p_$_n" "$1")" ;;
    esac
    printf '%s=%s\n' "$_n" "${r%%:*}"
  done
}
flips() { printf '%s ' $(verdicts "$1" | sed -n 's/=FAIL$//p'); }
# DERIVED, never typed: the control arm below reports how many verdicts it reproduced, and a
# hand-written count there goes stale the moment a predicate is added — which it already had.
NPREDS="$(printf '%s\n' $PREDS | wc -l | tr -d ' ')"

# --- the legacy producer ----------------------------------------------------
# Built by REMOVING the three new keys from the real producer, so the legacy marker is what
# the previous revision of this hook actually emitted rather than what the gate would accept.
LEGACY_PRODUCER="$WORK/recover-legacy.sh"
awk '!/printf .(snapshot_path|step_file|step_file_resolved)=/' "$HOOK" > "$LEGACY_PRODUCER"
if cmp -s "$HOOK" "$LEGACY_PRODUCER" || ! bash -n "$LEGACY_PRODUCER" 2>/dev/null; then
  bad "FIXTURE STALE: could not build the pre-change marker producer, so the legacy-marker arm is unfounded"
  LEGACY_PRODUCER=""
fi

# --- Assertions: every predicate, against the REAL gate ----------------------
for _n in $PREDS; do
  case "$_n" in
    ladder_abs) r="$(p_ladder "$GATE" abs)"; label="the compliance ladder holds for ABSOLUTE spellings of both mandated paths" ;;
    ladder_rel) r="$(p_ladder "$GATE" rel)"; label="the compliance ladder holds for RELATIVE spellings of both mandated paths" ;;
    inert)              r="$(p_inert "$GATE")";              label="inert with no marker: an ordinary call in an ordinary session is untouched" ;;
    deny_first)         r="$(p_deny_first "$GATE")";         label="armed: an edit, a tool with no file_path, and a Read of the wrong file are all denied, each told what to Read" ;;
    standdown_r0)       r="$(p_standdown_r0 "$GATE")";       label="stands down when the snapshot resolved no step file, and keeps the injection record" ;;
    standdown_missing)  r="$(p_standdown_missing "$GATE")";  label="stands down when a mandated path is missing, and CLEARS the marker so it cannot re-arm" ;;
    legacy)             r="$(p_legacy "$GATE")";             label="a marker predating these keys leaves the gate inert" ;;
    fastpath)           r="$(p_fastpath "$GATE")";           label="the marker fast-path does no work on an ordinary call, and DOES when armed (its subject is cost — it flips no verdict)" ;;
  esac
  if [ "$r" = PASS ]; then ok "gate: $label"; else bad "gate: $label — ${r#FAIL:}"; fi
done

# --- Assertion 17: UNMUTATED CONTROL, before any mutant is scored ------------
# The gate resolves paths, shells out and reads dotfiles. A copy of it in a temp root can fail
# for reasons that have nothing to do with a mutation, and every mutant verdict below is a
# difference measured against this one.
CTRL_G="$WORK/gate-control.sh"
cp "$GATE" "$CTRL_G"
cf="$(flips "$CTRL_G")"
if [ -z "${cf// /}" ]; then
  ok "control: an unmutated copy of the gate reproduces all ${NPREDS} verdicts — the flips below are the mutations"
else
  bad "CONTROL FAILED — an unmutated copy already flips {${cf}}, so every mutant verdict below is uninterpretable"
fi

# --- the mutant scorer ------------------------------------------------------
mutant_arm() { # mutant_arm <label> <mutant> <expected flip set, in PREDS order>
  if cmp -s "$GATE" "$2"; then
    bad "FIXTURE STALE: $1 — the mutant is byte-identical to the gate, so the mutation matched nothing"; return
  fi
  if ! bash -n "$2" 2>/dev/null; then
    bad "FIXTURE STALE: $1 — the mutant is not valid shell; it would emit nothing, and a silent gate is an ALLOW that would score as a kill"; return
  fi
  got="$(flips "$2")"
  if [ "$got" = "$3 " ]; then
    ok "mutant: $1 — flips exactly {$3}"
  elif [ -z "${got// /}" ]; then
    bad "MUTANT KILLED NOTHING: $1 — every gate arm stays green with the mutation applied, so {$3} cannot fire"
  else
    bad "MUTANT FLIP SET WRONG: $1 — expected {$3}, measured {$got}; the arms are entangled or one of them is vacuous"
  fi
}

# --- Assertion 18: MUTANT — the gate allows unconditionally ------------------
# The deny path emptied at its source, so every guard above it still runs and still decides;
# only the refusal is gone. Nothing but the deny arm may notice.
MG_ALLOW="$WORK/gate-allow-all.sh"
awk '/^deny\(\) \{$/{print; print "  exit 0"; next} 1' "$GATE" > "$MG_ALLOW"
mutant_arm "a gate that never refuses" "$MG_ALLOW" "deny_first"

# --- Assertion 19: MUTANT — the gate arms on an unresolvable mandate ---------
# BOTH layers of the precondition, because they are one guard: with only the flag check gone
# the empty step_file still stops it, and a mutant that killed nothing reads exactly like an
# arm that cannot fire.
MG_R0="$WORK/gate-arms-unresolved.sh"
awk '!(index($0,"[ \"$STEP_RESOLVED\" = \"1\" ] || exit 0") || index($0,"[ -n \"$STEP_REL\" ] || exit 0"))' "$GATE" > "$MG_R0"
mutant_arm "a gate that arms when the snapshot named no step file" "$MG_R0" "standdown_r0"

# --- Assertion 20: MUTANT — every arming precondition removed ----------------
# THE ARM THAT OWNS THE WHOLE STAND-DOWN FAMILY, and its flip set is 6 of 7 deliberately.
#
# `inert` is DEFENDED IN DEPTH and no narrower mutation reaches it. Measured, both narrow
# mutants built and scored: deleting ONLY the marker check flips nothing at all (an absent
# marker still dies on the empty keys), and deleting ONLY the three key checks flips
# {standdown_r0, legacy} — an absent marker still dies on the marker check. That is a property
# of the subject rather than of these arms, and it is why `inert` has no one-line killer.
#
# Removing all four is what those states are defended against, and its consequences run past
# the three inert arms: with no marker the unset paths resolve to the project directory, which
# is readable, so the gate arms in a session that never compacted AND re-arms after it has
# already disarmed, so both ladders' last call — an ordinary call after full compliance — is
# refused, and the missing-path stand-down no longer holds on the second call. Six genuine
# findings from one property: the gate arms only from a COMPLETE marker.
MG_WEDGE="$WORK/gate-no-standdown.sh"
awk '!(index($0,"[ -f \"$MARKER\" ] || exit 0") || index($0,"[ \"$STEP_RESOLVED\" = \"1\" ] || exit 0") || index($0,"[ -n \"$SNAP_REL\" ] || exit 0") || index($0,"[ -n \"$STEP_REL\" ] || exit 0"))' "$GATE" > "$MG_WEDGE"
mutant_arm "a gate with every arming precondition removed" "$MG_WEDGE" "inert ladder_abs ladder_rel standdown_r0 standdown_missing legacy fastpath"

# --- Assertion 21: MUTANT — one spelling only --------------------------------
# The call's path left unnormalised while the marker's stays resolved. The absolute ladder is
# unaffected, which is the point: this is the mutation a fixture that tested one spelling
# would ship green.
MG_SPELL="$WORK/gate-one-spelling.sh"
sed 's|FABS="\$(resolve "\$FPATH")"|FABS="$FPATH"|' "$GATE" > "$MG_SPELL"
mutant_arm "a gate that matches only the absolute spelling" "$MG_SPELL" "ladder_rel"

# --- Assertion 21b: MUTANT — the path-readability stand-down removed ---------
# THE PER-GUARD MUTANT FOR THE FOURTH STAND-DOWN, and the only one of the four that is
# constructible on its own. The other three cannot be split: deleting the marker check alone
# flips no verdict (assertion 22's arm exists because of that), and deleting the `-n` key
# checks alone flips nothing either, because a legacy marker carries no `step_file_resolved`
# and dies on THAT check first — the two are two readings of one producer fact, since
# `step_file_resolved=0` and an empty `step_file` are emitted together.
#
# This one has its own reachable subject: a marker whose paths resolved and whose step file is
# not on disk. With the block gone the gate demands a Read of a file that is not there, which
# is the unrecoverable wedge, and it keeps the marker so every later call is refused too.
MG_MISS="$WORK/gate-no-readability.sh"
awk 'index($0,"if [ ! -r \"$SNAP_ABS\" ] || [ ! -r \"$STEP_ABS\" ]; then"){d=4} d>0{d--; next} 1' "$GATE" > "$MG_MISS"
_d=$(( $(wc -l < "$GATE") - $(wc -l < "$MG_MISS") ))
if [ "$_d" -ne 4 ]; then
  bad "FIXTURE STALE: the readability mutant removed ${_d} lines, not the 4 of that block — the stand-down was reshaped and this mutant is cutting something else"
else
  mutant_arm "a gate with the path-readability stand-down removed" "$MG_MISS" "standdown_missing"
fi

# --- MUTANT — the marker fast-path deleted -----------------------------------
# THE ONE MUTANT THAT PROVES A COST ARM CAN FIRE. Removing this line changes NO decision, which
# is exactly why it needed an arm keyed on something other than a decision: with the line gone
# the gate parses the marker path on every ordinary call in every unarmed session — `sed`, not
# `jq`, which sits below the stand-downs — and only `fastpath`
# may notice. If this ever flips a second predicate, the line acquired a behavioural subject
# and the comment in the gate claiming it is a pure fast-path has gone stale.
MG_FAST="$WORK/gate-no-fastpath.sh"
awk '!index($0,"[ -f \"$MARKER\" ] || exit 0")' "$GATE" > "$MG_FAST"
mutant_arm "the marker fast-path deleted — the gate still works but parses on every call" "$MG_FAST" "fastpath"

# --- Assertion 22: MUTANT — the gate replaced by a dead hook -----------------
# THE CONTROL THE ALLOW-SHAPED ARMS REQUIRE. Four of the seven predicates pass when nothing
# fires, and `exit 0` is nothing firing. It must flip every arm that asserts an OBSERVABLE
# CONSEQUENCE — the deny, the two ladders' advance-and-disarm, the marker clearing — and it
# must NOT flip the three that assert a stand-down, because a stood-down gate and a dead gate
# are the same thing. That asymmetry is why those three carry assertion 20's mutant instead.
MG_DEAD="$WORK/gate-dead.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$MG_DEAD"
mutant_arm "the gate replaced by exit 0" "$MG_DEAD" "deny_first ladder_abs ladder_rel standdown_missing fastpath"

fi  # GATE present

# --- Assertion 23: the SECOND mandate never renders prose where a path goes --
# The old `${STEP_FILE}` fallback emitted: Your SECOND tool call MUST be `Read (named in
# Pipeline Position -- read the snapshot)` in full. A lead cannot execute that, and a MUST it
# cannot execute teaches it that the MUSTs in this block are negotiable — which is the standing
# the gate above depends on.
UNRES="$(mktemp -d "$WORK/unres.XXXXXX")"; mkdir -p "$UNRES/_bmad-output"
printf '# Pipeline Snapshot\n\n## Pipeline Position\nlast_gate_passed: planning-gate-2\n' \
  > "$UNRES/_bmad-output/pipeline-snapshot.md"
fire_at() { # fire_at <hook> <project>
  printf '{"source":"compact","session_id":"fixture"}' \
    | CLAUDE_PROJECT_DIR="$2" bash "$1" 2>/dev/null \
    | python3 -c 'import sys,json
try: print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])
except Exception: pass'
}
second_mandate_ok() { # second_mandate_ok <hook> -> PASS | FAIL:<what>
  t="$(fire_at "$1" "$UNRES")"
  [ -n "$t" ] || { printf 'FAIL:the hook emitted nothing for a snapshot naming no step file\n'; return; }
  grep -q 'POST-COMPACT RECOVERY' <<<"$t" || { printf 'FAIL:no directive was emitted at all\n'; return; }
  grep -q 'Read (' <<<"$t" && { printf 'FAIL:a MUST renders as `Read (<prose>)`, which is not an instruction the lead can execute\n'; return; }
  grep -q 'Read <' <<<"$t" || { printf 'FAIL:the second mandate offers the lead no placeholder to fill, so it names neither a path nor an action\n'; return; }
  grep -q 'Pipeline Position section of the snapshot' <<<"$t" || { printf 'FAIL:the second mandate never says where to resolve the path from\n'; return; }
  printf 'PASS\n'
}
r="$(second_mandate_ok "$HOOK")"
if [ "$r" = PASS ]; then
  ok "recover: with a snapshot naming no step file, the SECOND mandate names a takeable action and no prose placeholder"
else
  bad "recover: the SECOND mandate is unexecutable — ${r#FAIL:}"
fi

# --- Assertion 24: MUTANT — the old ${STEP_FILE} fallback restored -----------
# Both layers: the prose string back in the empty case AND the two-branch mandate collapsed to
# the single interpolated form. Reverting one alone leaves the other doing the work.
MUT_FB="$WORK/recover-old-fallback.sh"
sed -e 's|^  STEP_FILE=""$|  STEP_FILE="(named in Pipeline Position -- read the snapshot)"|' \
    -e 's|^if \[ "\$STEP_FILE_RESOLVED" -eq 1 \]; then$|if true; then|' "$HOOK" > "$MUT_FB"
# Anchored on the ASSIGNMENT, not the phrase: the hook's own comment quotes the old rendering
# verbatim, so a bare grep for it counts 2 in a correctly mutated file and reads as a stale seed.
lay="$(grep -c '^  STEP_FILE="(named in Pipeline Position' "$MUT_FB")"
lay2="$(grep -c '^if true; then$' "$MUT_FB")"
if cmp -s "$HOOK" "$MUT_FB"; then
  bad "FIXTURE STALE: the fallback mutant is byte-identical — the \${STEP_FILE} branch was reshaped"
elif [ "$lay" -ne 1 ] || [ "$lay2" -ne 1 ]; then
  bad "FIXTURE STALE: only $((lay + lay2)) of the fallback's 2 layers were reverted; a partial revert proves the layer left in place"
elif ! bash -n "$MUT_FB" 2>/dev/null; then
  bad "FIXTURE STALE: the fallback mutant is not valid shell, so its silence would score as a kill"
else
  r="$(second_mandate_ok "$MUT_FB")"
  MCTX2="$(fire "$MUT_FB")"
  if [ "$r" = PASS ]; then
    bad "MUTANT DID NOT FAIL — the old unexecutable fallback passes assertion 23, so that arm asserts nothing"
  elif [ "$MCTX2" != "$CTX" ]; then
    bad "MUTANT FAILED TOO MUCH — it also changed the directive emitted for a snapshot that DOES resolve, so assertion 23 is entangled with the text arms above"
  else
    ok "mutant: restoring the \${STEP_FILE} fallback fails ONLY the second-mandate arm — byte-identical output where the step file resolves"
  fi
fi

# --- Assertion 25: the block states the rule the gate cannot enforce ---------
# The gate reaches two of the three mandated Reads and none of the lead's prose. Where it
# cannot reach, the only carrier is disclosure — and a disclosure with no stated FORM is one
# the operator cannot grep the transcript for.
miss=""
grep -qi 'NO exception you may grant yourself' <<<"$CTX" || miss="$miss no-self-granted-exception-rule"
grep -q 'RECOVERY-SKIP:' <<<"$CTX" || miss="$miss RECOVERY-SKIP-disclosure-form"
grep -q 'ai-dlc-recover-gate\.sh' <<<"$CTX" || miss="$miss names-the-enforcer"
if [ -z "$miss" ]; then
  ok "the injected block states the no-self-granted-exception rule, names the gate, and gives the RECOVERY-SKIP disclosure form"
else
  bad "the injected block is missing:$miss — a lead that skips a mandated Read has nothing telling it the skip must be declared"
fi

echo
if [ "$fails" -eq 0 ]; then echo "postcompact-rulebook-recovery: PASS"; exit 0; fi
echo "postcompact-rulebook-recovery: $fails assertion(s) FAILED" >&2
exit 1
