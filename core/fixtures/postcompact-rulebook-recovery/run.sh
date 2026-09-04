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

# Drive the hook exactly as the harness does: JSON on stdin, source=compact. `fire` is the
# seeded project; `fire_at` is any project, and `fire` is written in terms of it so the two
# cannot come to drive the hook differently.
fire_at() { # fire_at <hook-path> <project> -> prints additionalContext
  printf '{"source":"compact","session_id":"fixture"}' \
    | CLAUDE_PROJECT_DIR="$2" bash "$1" 2>/dev/null \
    | python3 -c 'import sys,json
try: print(json.load(sys.stdin)["hookSpecificOutput"]["additionalContext"])
except Exception: pass'
}
fire() { # <hook-path> -> prints additionalContext
  fire_at "$1" "$PROJECT"
}

# STRIP THE PROVENANCE MARKER BEFORE COMPARING TWO EMISSIONS. Every hook emission now opens with
# a marker line carrying a per-emission nonce, so two invocations of the SAME hook differ BY
# DESIGN and a raw byte comparison reports entanglement for a reason that has nothing to do with
# the mutation under test. Only the marker LINE is dropped -- every other byte the mutant could
# have changed is still compared -- so this normalizes the arm rather than weakening it.
demark() { grep -v '^\[AI-DLC-HOOK-PROVENANCE ' <<<"$1" || true; }

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

# --- Assertion 1b: the directive names the DIGEST by its INSTALLED path -------
# The recovery Read. SKILL.md is ~102 KB and re-reading it after every compaction is what
# brings the next compaction closer, so the mandated Read is now
# `.claude/skills/ai-dlc/postcompact-digest.md` -- a rendered selection of SKILL.md's own
# bytes past the cut. Named by the consumer path for the same reason assertion 1 is: a lead
# handed a `core/` path on a consumer tree reads the failure as "the file is gone".
if grep -q '\.claude/skills/ai-dlc/postcompact-digest\.md' <<<"$CTX"; then
  ok "directive names .claude/skills/ai-dlc/postcompact-digest.md — the recovery Read"
else
  bad "the directive never names the installed digest path; the lead is told its rulebook is missing and given nothing to Read"
fi

# --- Assertion 2: it demands the WHOLE file, not a look ----------------------
# "Check whether rules are missing" is the instruction that already failed — it asks the lead
# to detect an absence it structurally cannot see. The subject is now the two GATED Reads --
# the snapshot and the step file -- which `ai-dlc-recover-gate.sh` refuses when bounded by
# `limit` or a late `offset`. The digest is not in this arm's scope: it is small enough that
# a partial read is not the failure mode, and assertion 2d carries what it needs instead.
if grep -qi 'IN FULL' <<<"$CTX"; then
  ok "directive demands the file IN FULL, not a spot check for what looks missing"
else
  bad "the directive does not demand a full read; a partial read leaves the same silent gap"
fi

# --- Assertion 2d: the digest is disclosed as an INDEX, not as the rulebook ---
# THE FAILURE MODE THE DIGEST INTRODUCES, and the reason this arm exists at all. The digest
# carries every heading past the cut with its operative opening, which is enough for a lead to
# learn a rule EXISTS and what it governs -- and not enough to APPLY one. A lead that reads an
# entry and acts as though it had read the rule is worse off than one that read nothing, because
# it has no signal that it is missing anything. So the block must say so and must name SKILL.md
# as where the full text lives. Both halves, because the caveat without the path is a warning
# with no remedy.
if grep -q 'INDEX' <<<"$CTX" && grep -q '\.claude/skills/ai-dlc/SKILL\.md' <<<"$CTX"; then
  ok "directive discloses the digest as an INDEX and names SKILL.md for a rule's full text"
else
  bad "the directive presents the digest without saying it is not enough to apply a rule; a lead will act on a heading and never learn it was missing the rule"
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
# THE BOUND IS 9500, NOT 9000, AND THE DIFFERENCE IS DELIBERATE. 9000 is the ceiling the
# DIRECTIVE is held to -- it is the payload and cannot be dropped. The Pipeline Position
# excerpt is droppable, and the hook now FITS it to the space left rather than adding up to
# 1,200 bytes blind or nothing at all, so a block carrying one may run up to
# CONTEXT_LIMIT - EXCERPT_RESERVE. Asserting 9000 here would fail every run that includes an
# excerpt, which is the common case; asserting 10000 would assert only the cliff and stop
# watching the reserve. 9500 is the bound the hook's own arithmetic promises.
LEN="$(printf '%s' "$CTX" | wc -c | tr -d ' ')"
if [ "$LEN" -lt 9500 ]; then
  ok "directive is ${LEN} chars, under the 9500 bound (10000 cliff - 500 excerpt reserve)"
else
  bad "directive is ${LEN} chars, at or past the 9500 bound — it has eaten the reserve that keeps it clear of the 10000 cliff, where the harness replaces the ENTIRE block with a file-path stub and nothing gets injected"
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
# THE MUTATION MOVED WITH THE MANDATE. It used to strip `Read ... SKILL.md` IN FULL; the
# recovery Read is now the digest, and the validator arm requires BOTH paths -- the digest to
# recover FROM and SKILL.md for a rule's full text. Killing either half must fail the arm, so
# the mutant strips the digest path, which is the half that did not exist before.
MUT_SKILL="$WORK/skill-no-mandate.md"
sed 's|\.claude/skills/ai-dlc/postcompact-digest\.md|the rulebook digest|' \
  "$SKILL" > "$MUT_SKILL"
if cmp -s "$SKILL" "$MUT_SKILL"; then
  bad "FIXTURE STALE: the mandate sentence was reworded, so the mutant is a byte-identical copy and assertion 6 proves nothing"
else
  out="$(bash "$VAL" --skill "$MUT_SKILL" --quiet 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ] && grep -q 'does not tell the lead how to recover' <<<"$out"; then
    ok "mutant: a protocol without the mandate FAILS, on the mandate arm specifically"
  elif [ "$rc" -ne 0 ]; then
    bad "MUTANT FAILED ON THE WRONG ARM — it tripped the byte-budget instead of the mandate check, so the two assertions are entangled and one is vacuous. Output: $(head -1 <<<"$out")"
  else
    bad "MUTANT DID NOT FAIL — SKILL.md passes with the re-read mandate removed, so assertion 6 asserts nothing"
  fi
fi

# --- Assertion 7b: MUTANT — strip the ROUTER path from SKILL.md, only the router arm red
# The protocol's third mandate, and the one a fresh `/ai-dlc resume` session depends on: it
# loads the whole file, reads this section as its resume procedure, and never reaches
# INITIALIZATION's router Read far below -- so the section itself must carry the path, and the
# validator must refuse a protocol that does not. Built as a COPY, guarded by cmp -s. The
# mutation edits every occurrence in the file; the validator reads only the section, so the
# kill is attributable to the section's copy and INITIALIZATION's is incidental.
# ONE MUTANT, ONE RED ARM: the digest and SKILL.md paths are untouched, so the mandate arm
# (assertion 7's) must stay quiet and the failure must name the router specifically.
MUT_ROUTE="$WORK/skill-no-router.md"
sed 's|\.claude/skills/ai-dlc/steps/route\.md|the router step|g' "$SKILL" > "$MUT_ROUTE"
if cmp -s "$SKILL" "$MUT_ROUTE"; then
  bad "FIXTURE STALE: the router path is spelled differently in SKILL.md, so the router mutant is a byte-identical copy and the router arm is unproven"
else
  out="$(bash "$VAL" --skill "$MUT_ROUTE" --quiet 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ] && grep -q 'does not send an un-routed session to the' <<<"$out"; then
    ok "mutant: a protocol that names no router FAILS, on the router arm specifically"
  elif [ "$rc" -ne 0 ]; then
    bad "MUTANT FAILED ON THE WRONG ARM — stripping the router path tripped a different check, so the arms are entangled and one is vacuous. Output: $(head -1 <<<"$out")"
  else
    bad "MUTANT DID NOT FAIL — SKILL.md passes with the router path removed from its protocol, so a resumed lead can be sent past the router and nothing refuses to ship it"
  fi
fi

# --- Assertion 7c: MUTANT — the router path survives only inside an HTML comment ---
# The comment-satisfiable receipt is this repo's most-repeated receipt defect. A protocol that
# carries the path in `<!-- -->` reads as compliant to a bare grep and instructs the lead of
# nothing. The mutation wraps the section's live mention; the arm strips single-line comments
# before matching, so this must fail on the router arm too.
MUT_ROUTE_C="$WORK/skill-router-commented.md"
sed 's|`{project-root}/\.claude/skills/ai-dlc/steps/route\.md`|<!-- .claude/skills/ai-dlc/steps/route.md -->|' "$SKILL" > "$MUT_ROUTE_C"
if cmp -s "$SKILL" "$MUT_ROUTE_C"; then
  bad "FIXTURE STALE: the protocol's router mention was reworded, so the commented-out mutant is byte-identical and the comment guard is unproven"
else
  out="$(bash "$VAL" --skill "$MUT_ROUTE_C" --quiet 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ] && grep -q 'does not send an un-routed session to the' <<<"$out"; then
    ok "mutant: a router path present only inside an HTML comment FAILS the router arm"
  elif [ "$rc" -ne 0 ]; then
    bad "MUTANT FAILED ON THE WRONG ARM — commenting out the router path tripped a different check. Output: $(head -1 <<<"$out")"
  else
    bad "MUTANT DID NOT FAIL — a router path inside an HTML comment satisfies the validator, so the arm is closable by a comment"
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

# --- Assertion 8c: MUTANT — strip the DIGEST path from the hook, only 1b red --
# Assertion 8 above strips `skills/ai-dlc/SKILL.md`, which the digest path does not match, so
# it leaves assertion 1b standing. Without this mutant 1b is an arm nobody has shown can fail:
# it would read `ok` against a hook that names the digest nowhere, and the lead would be told
# its rulebook is gone and handed no path. Anchored on the digest filename alone so it cannot
# reach the SKILL.md sentence assertions 1 and 2d key on -- one mutant, one red arm.
MUT_HOOK_D="$WORK/recover-no-digest.sh"
awk '!/postcompact-digest\.md/' "$HOOK" > "$MUT_HOOK_D"
if cmp -s "$HOOK" "$MUT_HOOK_D"; then
  bad "FIXTURE STALE: could not build the no-digest hook mutant — the digest path moved, so assertion 1b proves nothing"
elif ! bash -n "$MUT_HOOK_D" 2>/dev/null; then
  bad "FIXTURE STALE: the no-digest hook mutant is not valid shell, so its silence would score as a kill"
else
  DCTX="$(fire "$MUT_HOOK_D")"
  if [ -z "$DCTX" ]; then
    bad "MUTANT EMITTED NOTHING — its silence is indistinguishable from a kill, so assertion 1b is unproven"
  elif grep -q 'postcompact-digest\.md' <<<"$DCTX"; then
    bad "MUTANT DID NOT FAIL — the directive still names the digest with its path stripped"
  elif ! grep -q '\.claude/skills/ai-dlc/SKILL\.md' <<<"$DCTX" || ! grep -q 'INDEX' <<<"$DCTX"; then
    bad "MUTANT FAILED ON THE WRONG ARMS — stripping the digest path also took out assertion 1 or 2d, so the three arms are entangled and one of them is vacuous"
  else
    ok "mutant: the hook emits a directive naming no digest — assertion 1b can fail, and only it"
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
  if [ -n "$OCTX" ] && [ "$OLEN" -ge 9500 ]; then
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

# A BOUNDED Read, which is the shape the third filed skip took. `-` omits the field entirely, so
# `jbounded <p> - -` and `jcall Read <p>` are the same call and the two spellings cannot drift.
jbounded() { # jbounded <file_path> <limit|-> <offset|->
  _j="{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\"$1\""
  [ "$2" != "-" ] && _j="$_j,\"limit\":$2"
  [ "$3" != "-" ] && _j="$_j,\"offset\":$3"
  printf '%s}}' "$_j"
}

# A fresh project per scenario. The gate's whole state is two dotfiles under _bmad-output/, so
# scenarios that shared a root would silently inherit each other's progress.
#
# WHERE THE STEP FILE SITS IS A PARAMETER BECAUSE THE TWO PLACEMENTS ARE DIFFERENT TREES, and
# `consumer` is the one the protocol actually specifies. `route.md:46-47` resolves
# `current_step_file` as `{project-root}/.claude/skills/ai-dlc/steps/{current_step_file}`, so the
# snapshot records a BARE BASENAME and the file is under that directory. `flat` puts the same
# basename at the project root -- a tree the reference consumer does not produce, kept because
# a lead may also record a path-carrying spelling and the gate must serve both.
newproj() { # newproj <step-file-name|-> <where: consumer|flat|none> -> project dir
  _p="$(mktemp -d "$WORK/proj.XXXXXX")" || return 1
  mkdir -p "$_p/_bmad-output"
  {
    printf '# Pipeline Snapshot\n\n## Pipeline Position\n'
    [ "$1" != "-" ] && printf 'current_step_file: `%s`\n' "$1"
    printf 'last_gate_passed: planning-gate-2 @ 2026-08-04T10:00:00Z\n'
  } > "$_p/_bmad-output/pipeline-snapshot.md"
  case "$2" in
    consumer) mkdir -p "$_p/${STEPS_REL}"; printf 'step body\n' > "$_p/${STEPS_REL}/$1" ;;
    flat)     printf 'step body\n' > "$_p/$1" ;;
  esac
  printf 'in-flight edit work\n' > "$_p/decoy.md"
  printf '%s\n' "$_p"
}

# The step path the PRODUCER recorded, read back from the marker it wrote. Never re-derived here:
# a fixture that computed the expected path itself would be a second implementation of the
# resolver under test, and it would agree with a broken one.
marker_step() { # marker_step <project> -> the recorded step_file, or empty
  sed -n 's/^step_file=//p' "$1/$mk" 2>/dev/null | head -1
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
  _p="$(newproj architecture.md flat)"
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
  _p="$(newproj architecture.md flat)"; arm_marker "$HOOK" "$_p"
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
#    `consumer` is the THIRD spelling and it is the reference layout rather than a variation on
#    it: the snapshot carries a bare basename, the producer resolves it under the steps
#    directory, and the lead's compliant Read names the resolved path. It is the ANTI-WEDGE arm
#    for that layout -- full compliance must be allowed end to end and must disarm the gate.
#    Its step path is taken from the MARKER, never recomputed here.
p_ladder() { # p_ladder <gate> <abs|rel|consumer>
  case "$2" in
    consumer) _p="$(newproj architecture.md consumer)" ;;
    *)        _p="$(newproj architecture.md flat)" ;;
  esac
  arm_marker "$HOOK" "$_p"
  case "$2" in
    abs) s="$_p/_bmad-output/pipeline-snapshot.md"; f="$_p/architecture.md" ;;
    rel) s="_bmad-output/pipeline-snapshot.md";     f="architecture.md" ;;
    consumer)
      # ABSOLUTE on purpose. The subject here is the LAYOUT, not the spelling, and the two
      # ladders above already own the spelling. Measured with relative spellings instead, the
      # one-spelling mutant flipped this arm as well as `ladder_rel` -- two arms reporting one
      # finding, which is the entanglement the flip sets exist to expose.
      s="$_p/_bmad-output/pipeline-snapshot.md"; f="$(marker_step "$_p")"
      case "$f" in
        */*) : ;;
        *) printf 'FAIL:SEED CANNOT EXPRESS THE CASE — the producer recorded "%s", a bare basename, so this ladder is the flat one again\n' "$f"; return ;;
      esac
      [ -r "$_p/$f" ] \
        || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE — the recorded step path "%s" is not readable, so no compliant Read exists to allow\n' "$f"; return; }
      f="$_p/$f"
      ;;
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
  _p="$(newproj - none)"; arm_marker "$HOOK" "$_p"
  grep -q '^step_file_resolved=0$' "$_p/$mk" 2>/dev/null \
    || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE — this snapshot still resolved a step file\n'; return; }
  d="$(gate_call "$1" "$_p" "$(jcall Edit "$_p/decoy.md")")"
  allowed "$d" || { printf 'FAIL:armed on a mandate that names no path, denying every call the lead can make\n'; return; }
  [ -e "$_p/$mk" ] || { printf 'FAIL:destroyed the injection record it had no business arming on\n'; return; }
  printf 'PASS\n'
}

# 6. The step file resolved and then VANISHED. Denying a Read of something absent is the
#    unrecoverable wedge, so the gate stands down AND CLEARS the marker so it cannot re-arm on
#    the next call. The second call is the arm: clearing is what makes the stand-down permanent.
#
#    THE SEED IS A VANISH, NOT AN ABSENCE, AND IT HAD TO BECOME ONE. This predicate used to seed
#    a snapshot naming a step file that was never created, and read `step_file_resolved=1` off
#    the marker to prove the case was expressible. That stopped being constructible when the
#    producer began deriving the flag from READABILITY: an absent path now records
#    `step_file_resolved=0`, which is predicate 5's case, and this one reported SEED CANNOT
#    EXPRESS. The gate's re-check is not thereby vacuous -- its stated subject is "a path that
#    vanished mid-session", which is a state no producer can write and only the passage of time
#    can create. So the seed arms on a file that IS there and then removes it, which is the only
#    tree that reaches this branch and is also the one the guard's own comment describes.
p_standdown_missing() {
  _p="$(newproj architecture.md flat)"; arm_marker "$HOOK" "$_p"
  grep -q '^step_file_resolved=1$' "$_p/$mk" 2>/dev/null \
    || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE — the step file did not resolve at arming time, so this is the r0 case\n'; return; }
  rm -f "$_p/architecture.md"
  [ -e "$_p/architecture.md" ] \
    && { printf 'FAIL:SEED CANNOT EXPRESS THE CASE — the mandated path did not vanish\n'; return; }
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
  _p="$(newproj architecture.md flat)"; arm_marker "$LEGACY_PRODUCER" "$_p"
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
  _p="$(newproj architecture.md flat)"
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

# 9/10. "IN FULL" IS PART OF THE MANDATE AND THE GATE USED TO JOIN ON TOOL NAME AND PATH ALONE.
#    `Read <mandated file> limit=1` cleared the marker exactly as a full Read did: measured on
#    the pre-fix gate, the bounded snapshot Read was ALLOWED and advanced the stage, and the
#    bounded step Read was ALLOWED and disarmed the gate -- 1 line of 1210 loaded, gate inert.
#    That is the THIRD skip shape the filing records, and it was the one taken in the open.
#
#    TWO PREDICATES, ONE PER STAGE, BECAUSE THEY ARE TWO CALL SITES. A single predicate would be
#    satisfied by a gate that tests only the stage it happened to reach first, and the pre-fix
#    gate had exactly two places to fix.
#
#    EACH CARRIES ITS OWN CONTROL, IN THE SAME PREDICATE. A deny is easy to produce by breaking
#    the gate, so the arm is not "the bounded Read is refused" but "the bounded Read is refused
#    AND the unbounded one is allowed". The `offset:1` call is the near-miss: a Read starting at
#    line 1 is a full read and must be allowed, so a test widened to "any offset field is a
#    partial" fails here rather than passing as a stricter gate.
p_full_snapshot() {
  _p="$(newproj architecture.md flat)"; arm_marker "$HOOK" "$_p"
  for _b in "1:-" "-:800"; do
    d="$(gate_call "$1" "$_p" "$(jbounded "$_p/_bmad-output/pipeline-snapshot.md" "${_b%%:*}" "${_b#*:}")")"
    allowed "$d" && { printf 'FAIL:a snapshot Read bounded by {limit=%s offset=%s} was allowed as the mandated FIRST call\n' "${_b%%:*}" "${_b#*:}"; return; }
    grep -q 'IN FULL' <<<"${d#*|}" || { printf 'FAIL:the bounded snapshot Read {limit=%s offset=%s} was denied for some other reason than being partial\n' "${_b%%:*}" "${_b#*:}"; return; }
    [ -e "$_p/$pg" ] && { printf 'FAIL:a bounded snapshot Read advanced the gate — the partial cleared the stage\n'; return; }
  done
  # CONTROL: the same Read with neither field, and the near-miss that must NOT be treated as
  # partial. Without these the arm would pass against a gate that denies every Read there is.
  d="$(gate_call "$1" "$_p" "$(jbounded "$_p/_bmad-output/pipeline-snapshot.md" - 1)")"
  allowed "$d" || { printf 'FAIL:a snapshot Read at offset 1 is a FULL read and was denied — the test widened past its subject\n'; return; }
  [ "$(cat "$_p/$pg" 2>/dev/null)" = step ] || { printf 'FAIL:the offset-1 snapshot Read did not advance the gate\n'; return; }
  printf 'PASS\n'
}

p_full_step() {
  _p="$(newproj architecture.md flat)"; arm_marker "$HOOK" "$_p"
  gate_call "$1" "$_p" "$(jcall Read "$_p/_bmad-output/pipeline-snapshot.md")" >/dev/null
  [ "$(cat "$_p/$pg" 2>/dev/null)" = step ] \
    || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE — the full snapshot Read did not reach stage two\n'; return; }
  for _b in "1:-" "-:800"; do
    d="$(gate_call "$1" "$_p" "$(jbounded "$_p/architecture.md" "${_b%%:*}" "${_b#*:}")")"
    allowed "$d" && { printf 'FAIL:a step-file Read bounded by {limit=%s offset=%s} satisfied the SECOND mandate\n' "${_b%%:*}" "${_b#*:}"; return; }
    grep -q 'IN FULL' <<<"${d#*|}" || { printf 'FAIL:the bounded step Read {limit=%s offset=%s} was denied for some other reason than being partial\n' "${_b%%:*}" "${_b#*:}"; return; }
    [ -e "$_p/$mk" ] || { printf 'FAIL:a bounded step Read disarmed the gate\n'; return; }
    [ "$(cat "$_p/$pg" 2>/dev/null)" = step ] || { printf 'FAIL:a bounded step Read moved the gate off stage two\n'; return; }
  done
  # CONTROL: the unbounded Read of the same file must be allowed AND must disarm. This is the
  # anti-wedge half -- the always-available action the deny above sends the lead to.
  d="$(gate_call "$1" "$_p" "$(jcall Read "$_p/architecture.md")")"
  allowed "$d" || { printf 'FAIL:the unbounded step Read was denied, so the deny above is not satisfiable and the gate is a wedge\n'; return; }
  [ -e "$_p/$mk" ] && { printf 'FAIL:the unbounded step Read was allowed but the gate stayed armed\n'; return; }
  printf 'PASS\n'
}

PREDS="inert deny_first ladder_abs ladder_rel ladder_consumer standdown_r0 standdown_missing legacy fastpath full_snapshot full_step"
verdicts() { # verdicts <gate> -> "name=PASS" lines, in PREDS order
  for _n in $PREDS; do
    case "$_n" in
      ladder_abs)      r="$(p_ladder "$1" abs)" ;;
      ladder_rel)      r="$(p_ladder "$1" rel)" ;;
      ladder_consumer) r="$(p_ladder "$1" consumer)" ;;
      *)               r="$("p_$_n" "$1")" ;;
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
    ladder_consumer) r="$(p_ladder "$GATE" consumer)"; label="ANTI-WEDGE on the REFERENCE layout: a bare basename in the snapshot, and full compliance is allowed end to end and disarms the gate" ;;
    full_snapshot)   r="$(p_full_snapshot "$GATE")";   label="a BOUNDED Read of the snapshot is refused and does not advance the gate, while the unbounded one and an offset-1 Read are allowed" ;;
    full_step)       r="$(p_full_step "$GATE")";       label="a BOUNDED Read of the step file is refused and does not disarm the gate, while the unbounded one is allowed and does" ;;
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
# only the refusal is gone. Only the arms that assert a REFUSAL may notice, and there are three
# of them because the gate refuses three distinct things: a call that is not a mandated Read at
# all, a bounded Read at stage one, and a bounded Read at stage two. Each is a separate finding
# about a separate call site -- the single-site mutants below prove the two stage arms are
# reachable one at a time -- and no stand-down arm may appear here, because a gate that never
# refuses stands down by accident everywhere.
MG_ALLOW="$WORK/gate-allow-all.sh"
awk '/^deny\(\) \{$/{print; print "  exit 0"; next} 1' "$GATE" > "$MG_ALLOW"
mutant_arm "a gate that never refuses" "$MG_ALLOW" "deny_first full_snapshot full_step"

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
# already disarmed, so every ladder's last call — an ordinary call after full compliance — is
# refused, and the missing-path stand-down no longer holds on the second call. Seven genuine
# findings from one property: the gate arms only from a COMPLETE marker.
#
# `ladder_consumer` is in the set for the same reason as the other two and for no reason of its
# own: it is a third ladder and its last call is refused too. The two `full_*` arms are NOT here,
# and that is the discriminating part — a re-armed gate still refuses a bounded Read, so the
# in-full test is untouched by this mutation.
MG_WEDGE="$WORK/gate-no-standdown.sh"
awk '!(index($0,"[ -f \"$MARKER\" ] || exit 0") || index($0,"[ \"$STEP_RESOLVED\" = \"1\" ] || exit 0") || index($0,"[ -n \"$SNAP_REL\" ] || exit 0") || index($0,"[ -n \"$STEP_REL\" ] || exit 0"))' "$GATE" > "$MG_WEDGE"
mutant_arm "a gate with every arming precondition removed" "$MG_WEDGE" "inert ladder_abs ladder_rel ladder_consumer standdown_r0 standdown_missing legacy fastpath"

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
# THE CONTROL THE ALLOW-SHAPED ARMS REQUIRE. Four of the predicates pass when nothing fires, and
# `exit 0` is nothing firing. It must flip every arm that asserts an OBSERVABLE CONSEQUENCE — the
# deny, the three ladders' advance-and-disarm, the marker clearing, and both in-full arms — and
# it must NOT flip the three that assert a stand-down, because a stood-down gate and a dead gate
# are the same thing. That asymmetry is why those three carry assertion 20's mutant instead.
#
# The two `full_*` arms are killed here on their CONTROL halves as much as on their denies: a
# dead gate neither refuses the bounded Read nor advances on the unbounded one, and an arm that
# only watched for a refusal would score this silence as a pass.
MG_DEAD="$WORK/gate-dead.sh"
printf '#!/usr/bin/env bash\nexit 0\n' > "$MG_DEAD"
mutant_arm "the gate replaced by exit 0" "$MG_DEAD" "deny_first ladder_abs ladder_rel ladder_consumer standdown_missing fastpath full_snapshot full_step"

# --- MUTANT — "in full" unenforced, ALL THREE LAYERS reverted ----------------
# THE PRE-FIX GATE, reconstructed rather than asserted: the two `jq` field extractions gone, the
# `is_full_read` definition gone, and both call sites unconditional again. Reverting only the
# call sites would leave a test nothing calls and the mutant would still prove the extraction;
# reverting only the extraction would leave `is_full_read` reading unset variables under `set -u`
# and the mutant would die on a shell error, whose silence is an ALLOW that scores as a kill.
#
# It must flip BOTH stage arms and nothing else. A third flip would mean a bounded Read is doing
# work somewhere the two arms above do not name.
MG_NOFULL="$WORK/gate-partial-ok.sh"
awk '
  index($0,".tool_input.limit // empty")  {next}
  index($0,".tool_input.offset // empty") {next}
  $0=="is_full_read() {" {inf=1; next}
  inf && $0=="}" {inf=0; next}
  inf {next}
  $0=="      if is_full_read; then" {print "      if true; then"; next}
  1' "$GATE" > "$MG_NOFULL"
# Anchored on the EMITTING lines, never on the header prose: the gate's own comment names
# `is_full_read()` and quotes `limit`/`offset`, so a loose grep counts a correctly reverted
# mutant as unreverted and the arm would report FIXTURE STALE forever.
lay=0
[ "$(grep -c 'tool_input\.limit // empty' "$MG_NOFULL")"  -eq 0 ] && lay=$((lay+1))
[ "$(grep -c 'tool_input\.offset // empty' "$MG_NOFULL")" -eq 0 ] && lay=$((lay+1))
[ "$(grep -c '^is_full_read() {$' "$MG_NOFULL")"          -eq 0 ] && lay=$((lay+1))
[ "$(grep -c '^      if is_full_read; then$' "$MG_NOFULL")" -eq 0 ] && lay=$((lay+1))
[ "$(grep -c '^      if true; then$' "$MG_NOFULL")"       -eq 2 ] && lay=$((lay+1))
if [ "$lay" -ne 5 ]; then
  bad "FIXTURE STALE: only ${lay} of the in-full fix's 5 layers were reverted; a partial revert comes out green and proves the layer left in place"
else
  mutant_arm "a gate that accepts a BOUNDED Read as compliance, at both sites" "$MG_NOFULL" "full_snapshot full_step"
fi

# --- MUTANT — "in full" unenforced at ONE site, once per site ----------------
# THE ENTANGLEMENT TEST FOR THE TWO STAGE ARMS. The mutant above proves the fix is load-bearing;
# these two prove the arms are separable, which is the failure mode where one stage is guarded
# and the fixture reports both as guarded. Each replaces exactly ONE of the two identical call
# sites, so each must flip exactly one predicate.
_i=1
for _site in snapshot step; do
  MG_ONE="$WORK/gate-partial-ok-${_site}.sh"
  awk -v want="$_i" '
    $0=="      if is_full_read; then" { n++; if (n==want) { print "      if true; then"; next } }
    1' "$GATE" > "$MG_ONE"
  if [ "$(grep -c '^      if true; then$' "$MG_ONE")" -ne 1 ] \
  || [ "$(grep -c '^      if is_full_read; then$' "$MG_ONE")" -ne 1 ]; then
    bad "FIXTURE STALE: the single-site in-full mutant for the ${_site} stage did not land on exactly one of the two call sites"
  else
    mutant_arm "a gate that accepts a BOUNDED Read at the ${_site} stage only" "$MG_ONE" "full_${_site}"
  fi
  _i=$((_i+1))
done

# =============================================================================
# THE PRODUCER — ai-dlc-recover.sh, on the layout the protocol actually specifies
#
# Everything above holds the GATE fixed and mutates it. Two of the three defects this section
# was added for are in the INJECTOR, and one of them is invisible from the gate's side because
# the gate behaved correctly on the input it was given: the marker said the mandated file was
# `discovery.md`, no such file existed at the project root, and standing down was the right
# answer to a wrong question.
#
# So this is a SECOND battery, with its own predicates, its own unmutated control and its own
# mutants. It holds the gate at the real one and mutates the producer, which is the only way a
# marker-content defect can be scored. The two batteries never share a mutant, so a flip in
# either is attributable to the file that was mutated.
# =============================================================================

# R1. THE GATE NEVER ARMED ON THE REFERENCE-CONSUMER LAYOUT. `route.md:46-47` resolves
#     `current_step_file` as `{project-root}/.claude/skills/ai-dlc/steps/{current_step_file}`,
#     so the snapshot carries a BARE BASENAME. Recorded raw, the mandate named a file that does
#     not exist at the project root, and the gate resolved `${PROJECT_DIR}/discovery.md`, found
#     nothing, took its "a mandated path vanished, stand down" branch, DELETED ITS OWN MARKER and
#     allowed the call. The first post-compact tool call -- any call -- disarmed it permanently.
#
#     The predicate asserts the whole chain, because each link alone is satisfiable by a
#     regression in the next: a resolved marker whose path the mandate does not name leaves the
#     lead reading a different file, and both of those are consistent with a gate that never
#     arms.
pr_consumer() { # pr_consumer <recover-hook>
  _p="$(newproj discovery.md consumer)"
  arm_marker "$1" "$_p"
  sf="$(marker_step "$_p")"
  [ -n "$sf" ] || { printf 'FAIL:the producer recorded no step_file at all\n'; return; }
  [ -r "$_p/$sf" ] \
    || { printf 'FAIL:the producer recorded step_file=%s, which is not readable from the project root — the mandate names a file the lead cannot Read and the gate has nothing armable\n' "$sf"; return; }
  t="$(fire_at "$1" "$_p")"
  grep -qF "Read ${sf}\` in full" <<<"$t" \
    || { printf 'FAIL:the marker resolved to %s but the SECOND mandate does not name that path, so the lead is sent somewhere else\n' "$sf"; return; }
  d="$(gate_call "$GATE" "$_p" "$(jcall Edit "$_p/decoy.md")")"
  allowed "$d" \
    && { printf 'FAIL:an ordinary Edit was ALLOWED as the first post-compact call on the reference layout — the gate never armed\n'; return; }
  [ -e "$_p/$mk" ] \
    || { printf 'FAIL:the gate deleted its own marker on the first post-compact call, so it is disarmed for the rest of the session\n'; return; }
  printf 'PASS\n'
}

# R2. THE ASSURANCE IS A CLAIM ABOUT THE GATE AND WAS EMITTED WHERE THE GATE CANNOT ARM.
#     "Both files were confirmed to exist before it armed" went into every block, including
#     every session where nothing was watching. That is worse than silence: the RECOVERY-SKIP
#     disclosure is the only thing binding those sessions, and a lead that believes it is
#     mechanically gated has no reason to reach it.
#
#     BOTH DIRECTIONS, IN ONE PREDICATE. The offender is a snapshot naming a file that exists
#     nowhere; the control is the reference layout, where the assurance is TRUE and must still
#     be stated. Without the control, deleting the paragraph outright would pass -- and silence
#     is not the fix either, because the armed session is the one the claim is for.
pr_assurance() { # pr_assurance <recover-hook>
  _g="$(newproj ghost.md none)"
  arm_marker "$1" "$_g"
  grep -q '^step_file_resolved=0$' "$_g/$mk" 2>/dev/null \
    || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE — the producer reported a step file it can nowhere read as resolved\n'; return; }
  t="$(fire_at "$1" "$_g")"
  [ -n "$t" ] || { printf 'FAIL:the hook emitted nothing for a snapshot naming an unreachable step file\n'; return; }
  grep -q 'refuses any other first tool call' <<<"$t" \
    && { printf 'FAIL:the block promises the gate refuses any other first tool call, in a session where the gate cannot arm\n'; return; }
  grep -q 'confirmed readable' <<<"$t" \
    && { printf 'FAIL:the block claims both files were confirmed readable before the gate armed, and it never armed\n'; return; }
  grep -q 'CANNOT ARM' <<<"$t" \
    || { printf 'FAIL:the block neither promises nor disclaims enforcement, so the lead cannot tell which session it is in\n'; return; }
  grep -q 'RECOVERY-SKIP:' <<<"$t" \
    || { printf 'FAIL:the gate cannot arm and the disclosure form is absent, so nothing at all binds this session\n'; return; }
  # CONTROL: a layout where the flag is 1, so the assurance is true and must be made.
  #
  # FLAT, NOT THE REFERENCE LAYOUT, AND THAT WAS MEASURED RATHER THAN CHOSEN. With the reference
  # layout as the control this predicate went red under the resolution-only mutant -- correctly,
  # since nothing resolves there and the block then discloses -- but that is the OTHER arm's
  # finding reported twice. A flat project reaches `step_file_resolved=1` without the candidate
  # -root loop, so what remains here is the only thing this arm should own: whether the
  # paragraph tracks the flag.
  _c="$(newproj architecture.md flat)"
  arm_marker "$1" "$_c"
  t2="$(fire_at "$1" "$_c")"
  grep -q 'CANNOT ARM' <<<"$t2" \
    && { printf 'FAIL:the block disclaims enforcement in a session where the gate does arm\n'; return; }
  grep -q 'refuses any other first tool call' <<<"$t2" \
    || { printf 'FAIL:the block never states the assurance even where the gate armed — the paragraph was deleted rather than made conditional\n'; return; }
  printf 'PASS\n'
}

RPREDS="consumer assurance"
rverdicts() { # rverdicts <recover-hook>
  for _n in $RPREDS; do r="$("pr_$_n" "$1")"; printf '%s=%s\n' "$_n" "${r%%:*}"; done
}
rflips() { printf '%s ' $(rverdicts "$1" | sed -n 's/=FAIL$//p'); }

for _n in $RPREDS; do
  case "$_n" in
    consumer)  r="$(pr_consumer "$HOOK")";  label="producer: a BARE BASENAME in the snapshot resolves under the steps directory, the mandate names the resolved path, and the gate ARMS instead of deleting its own marker" ;;
    assurance) r="$(pr_assurance "$HOOK")"; label="producer: the gate-assurance paragraph is made only where the gate can arm, and IS made where it can" ;;
  esac
  if [ "$r" = PASS ]; then ok "$label"; else bad "$label — ${r#FAIL:}"; fi
done

# --- UNMUTATED CONTROL for the producer battery ------------------------------
RCTRL="$WORK/recover-control-producer.sh"
cp "$HOOK" "$RCTRL"
rcf="$(rflips "$RCTRL")"
if [ -z "${rcf// /}" ]; then
  ok "control: an unmutated copy of the producer reproduces both verdicts — the flips below are the mutations"
else
  bad "CONTROL FAILED — an unmutated copy of the producer already flips {${rcf}}, so every producer-mutant verdict below is uninterpretable"
fi

rmutant_arm() { # rmutant_arm <label> <mutant> <expected flip set, in RPREDS order>
  if cmp -s "$HOOK" "$2"; then
    bad "FIXTURE STALE: $1 — the mutant is byte-identical to the producer, so the mutation matched nothing"; return
  fi
  if ! bash -n "$2" 2>/dev/null; then
    bad "FIXTURE STALE: $1 — the mutant is not valid shell; it would emit no directive and write no marker, and both predicates would read that as a kill they did not earn"; return
  fi
  got="$(rflips "$2")"
  if [ "$got" = "$3 " ]; then
    ok "mutant: $1 — flips exactly {$3}"
  elif [ -z "${got// /}" ]; then
    bad "MUTANT KILLED NOTHING: $1 — both producer arms stay green with the mutation applied, so {$3} cannot fire"
  else
    bad "MUTANT FLIP SET WRONG: $1 — expected {$3}, measured {$got}; the arms are entangled or one of them is vacuous"
  fi
}

# --- MUTANT — the whole basename fix reverted, BOTH layers -------------------
# The resolution loop and the readability-derived flag are two layers of one edit, and reverting
# either alone leaves the other doing the work. This is the pre-fix producer: the grep's raw
# capture recorded verbatim, and `step_file_resolved=1` meaning "a grep matched something".
MR_RAW="$WORK/recover-raw-basename.sh"
awk '
  $0=="  case \"$STEP_FILE\" in" {inb=1; next}
  inb && $0=="  esac" {inb=0; if (!e) {print "  :"; e=1} next}
  inb {next}
  index($0,"[ -r \"$_step_abs\" ] || STEP_FILE_RESOLVED=0") {next}
  1' "$HOOK" > "$MR_RAW"
lay=0
[ "$(grep -c '_cand' "$MR_RAW")"     -eq 0 ] && lay=$((lay+1))
[ "$(grep -c '_step_abs' "$MR_RAW")" -eq 0 ] && lay=$((lay+1))
[ "$(grep -c '^  :$' "$MR_RAW")"     -eq 1 ] && lay=$((lay+1))
if [ "$lay" -ne 3 ]; then
  bad "FIXTURE STALE: only ${lay} of the basename fix's 3 layers were reverted; a partial revert comes out green and proves the layer left in place"
else
  rmutant_arm "a producer that records the snapshot's bare basename raw and calls it resolved" "$MR_RAW" "consumer assurance"
fi

# --- MUTANT — the resolution reverted, the readability flag KEPT -------------
# THE ENTANGLEMENT TEST, one layer each. With the loop gone the basename never becomes a path,
# so the flag correctly reads 0 and the block correctly discloses -- the gate does not arm and
# does not lie about it. Only the reference-layout arm may notice.
MR_RESOLVE="$WORK/recover-no-resolve.sh"
awk '
  !d && $0=="  case \"$STEP_FILE\" in" {inb=1; d=1; next}
  inb && $0=="  esac" {inb=0; next}
  inb {next}
  1' "$HOOK" > "$MR_RESOLVE"
if [ "$(grep -c '_cand' "$MR_RESOLVE")" -ne 0 ] || [ "$(grep -c '_step_abs' "$MR_RESOLVE")" -eq 0 ]; then
  bad "FIXTURE STALE: the resolution-only mutant did not cut exactly the candidate-root loop"
else
  rmutant_arm "a producer that never resolves a bare basename under the steps directory" "$MR_RESOLVE" "consumer"
fi

# --- MUTANT — the readability flag reverted, the resolution KEPT -------------
# The other half. Resolution still works, so the reference layout is unaffected; what returns is
# `step_file_resolved=1` for a name that resolves nowhere, which is the input the false assurance
# was rendered from.
MR_FLAG="$WORK/recover-flag-blind.sh"
awk '
  $0=="  case \"$STEP_FILE\" in" {n++; if (n==2) {inb=1; next}}
  inb && $0=="  esac" {inb=0; next}
  inb {next}
  index($0,"[ -r \"$_step_abs\" ] || STEP_FILE_RESOLVED=0") {next}
  1' "$HOOK" > "$MR_FLAG"
if [ "$(grep -c '_step_abs' "$MR_FLAG")" -ne 0 ] || [ "$(grep -c '_cand' "$MR_FLAG")" -eq 0 ]; then
  bad "FIXTURE STALE: the flag-only mutant did not cut exactly the readability test"
else
  rmutant_arm "a producer whose resolved flag means only that a grep matched something" "$MR_FLAG" "assurance"
fi

# --- MUTANT — the assurance emitted unconditionally --------------------------
# THE ARM'S OWN KILLER, and the one that owns the false-assurance case: the flag is computed
# correctly and the paragraph ignores it, which is exactly the shipped defect. Anchored on the
# SECOND occurrence of the branch condition -- the first is the second-mandate branch, and a
# mutant that collapsed both would be scoring two changes as one.
MR_ASSURE="$WORK/recover-assurance-always.sh"
awk '
  $0=="if [ \"$STEP_FILE_RESOLVED\" -eq 1 ]; then" { n++; if (n==2) { print "if true; then"; next } }
  1' "$HOOK" > "$MR_ASSURE"
if [ "$(grep -c '^if true; then$' "$MR_ASSURE")" -ne 1 ] \
|| [ "$(grep -c '^if \[ "\$STEP_FILE_RESOLVED" -eq 1 \]; then$' "$MR_ASSURE")" -ne 1 ]; then
  bad "FIXTURE STALE: the unconditional-assurance mutant did not land on exactly the second of the two branch conditions"
else
  rmutant_arm "a producer that promises the gate armed whether or not it could" "$MR_ASSURE" "assurance"
fi

fi  # GATE present

# --- Assertion 23: the SECOND mandate never renders prose where a path goes --
# The old `${STEP_FILE}` fallback emitted: Your SECOND tool call MUST be `Read (named in
# Pipeline Position -- read the snapshot)` in full. A lead cannot execute that, and a MUST it
# cannot execute teaches it that the MUSTs in this block are negotiable — which is the standing
# the gate above depends on.
UNRES="$(mktemp -d "$WORK/unres.XXXXXX")"; mkdir -p "$UNRES/_bmad-output"
printf '# Pipeline Snapshot\n\n## Pipeline Position\nlast_gate_passed: planning-gate-2\n' \
  > "$UNRES/_bmad-output/pipeline-snapshot.md"
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

# --- Assertion 23b: the cliff, measured on the LARGER of the two branches -----
# ASSERTION 4 MEASURES THE SEEDED PROJECT AND THAT IS NO LONGER THE BIGGEST BLOCK. The hook now
# has two shapes and the unresolvable one is the longer: it replaces a one-line mandate with a
# paragraph telling the lead how to resolve the path itself, and replaces the gate assurance with
# the cannot-arm disclaimer. Measured, same hook, same run: 8696 characters where the step file
# resolves and 8927 where it does not — a 231-character spread against 304 characters of
# headroom, all of it on the branch assertion 4 does not see.
#
# THAT SPREAD WAS TAKEN WITH THE SNAPSHOT HELD CONSTANT and it is not the difference between the
# two figures this fixture prints. The unresolvable project below carries no Pipeline Position
# body, so its excerpt is shorter and its total lands lower than the 8927 above while still being
# the larger of the two BRANCHES. Reading the two printed numbers as the branch cost would
# under-state it.
#
# The predicate is assertion 4's, and assertion 8c is what proves that predicate can fire; this
# arm adds a second population, not a second check.
# Measured the way assertion 4 measures, through a variable: piping `fire_at` straight into
# `wc -c` counts python's trailing newline and the two figures would differ by one byte.
UCTX="$(fire_at "$HOOK" "$UNRES")"
ULEN="$(printf '%s' "$UCTX" | wc -c | tr -d ' ')"
if [ "$ULEN" -lt 9500 ]; then
  ok "the LARGER branch — no resolvable step file — is ${ULEN} chars, also under the 9500 bound"
else
  bad "the block is ${ULEN} chars when the snapshot names no resolvable step file, at or past the 9500 bound — the harness replaces the ENTIRE block with a file-path stub for exactly the recoveries that have the least going for them"
fi

# --- Assertion 24: MUTANT — the old ${STEP_FILE} fallback restored -----------
# Both layers: the prose string back in the empty case AND the two-branch mandate collapsed to
# the single interpolated form. Reverting one alone leaves the other doing the work.
#
# ANCHORED ON THE FIRST OCCURRENCE OF THE BRANCH CONDITION, NOT ON EVERY ONE. A second consumer
# of `STEP_FILE_RESOLVED` was added -- the gate-assurance paragraph -- and a blanket `sed`
# collapsed both, which is two mutations scored as one and reported here as three layers where
# the mutant has two.
MUT_FB="$WORK/recover-old-fallback.sh"
awk '
  $0=="  STEP_FILE=\"\"" {print "  STEP_FILE=\"(named in Pipeline Position -- read the snapshot)\""; next}
  !d && $0=="if [ \"$STEP_FILE_RESOLVED\" -eq 1 ]; then" {print "if true; then"; d=1; next}
  1' "$HOOK" > "$MUT_FB"
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
  elif [ "$(demark "$MCTX2")" != "$(demark "$CTX")" ]; then
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
