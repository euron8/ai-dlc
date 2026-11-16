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
#
# THE THIRD SUBJECT, far below: the hook's reading of `current_step_file`, which is
# single-valued and was decided by whichever match came first. That section seeds SEVEN
# DISTINCT INPUT SHAPES over ten snapshots -- two unlabelled live bullets, one live bullet, a
# labelled prior, two bullets naming one file, a prose line quoting the key, the `(LIVE)`
# inverse label, and mixed key spellings across a pair -- and counts shapes rather than arms
# because channels written by different hands converge on the obvious seed and then agree for
# that reason.
set -uo pipefail

# The pre-push gate inherits every AI_DLC_* tunable a consumer set in settings.json. A fixture
# that drives a hook while inheriting them tests the CONFIG, not the code (I10).
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
# The chmod comes first: the BL-688 arms make a 555 directory under $WORK, and an interrupt
# between their chmod 555 and chmod 755 would otherwise leave `rm -rf` unable to empty it.
trap 'chmod -R u+w "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

# Sentinels for the declared REQUIRED inputs, printed where env.sh first hands them to the run.
# The gate, postcompact hook, sourced siblings and verdict.sh are tolerated absent below, so
# each of those is guarded by [ -f ].
echo "HERMETIC-CONSUMED $HOOK"
echo "HERMETIC-CONSUMED $VAL"
[ -n "${GATE:-}" ] && [ -f "$GATE" ] && echo "HERMETIC-CONSUMED $GATE"
[ -n "${GATE:-}" ] && [ -f "$(dirname "$GATE")/ai-dlc-advisor-detect.sh" ] && echo "HERMETIC-CONSUMED $(dirname "$GATE")/ai-dlc-advisor-detect.sh"
[ -n "${POSTCOMPACT:-}" ] && [ -f "$POSTCOMPACT" ] && echo "HERMETIC-CONSUMED $POSTCOMPACT"
[ -f "$(dirname "$HOOK")/ai-dlc-context-provenance.sh" ] && echo "HERMETIC-CONSUMED $(dirname "$HOOK")/ai-dlc-context-provenance.sh"
[ -f "$(dirname "$HOOK")/ai-dlc-handoff-pending.sh" ] && echo "HERMETIC-CONSUMED $(dirname "$HOOK")/ai-dlc-handoff-pending.sh"
[ -f "$(dirname "$VAL")/verdict.sh" ] && echo "HERMETIC-CONSUMED $(dirname "$VAL")/verdict.sh"
_PRS=""; for _c in "$HERE/../../schemas/pause-routing.json" "$HERE/../../../.claude/schemas/pause-routing.json"; do [ -f "$_c" ] && { _PRS="$(cd "$(dirname "$_c")" && pwd -P)/pause-routing.json"; break; }; done
[ -n "$_PRS" ] && echo "HERMETIC-CONSUMED $_PRS"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
skip() { # skip <what> <why> — tolerated only where the subject legitimately has not arrived
  if [ "${IS_DIST:-0}" = 1 ]; then bad "$1 -- $2 (HARD in the distribution: the subject must be present here)"
  else printf '  SKIP  %s -- %s\n' "$1" "$2"; fi
}
# defer <what> <owner> — an arm standing down because ANOTHER arm owns the finding, which is a
# different state from `skip` and must not escalate in the distribution. `skip` means the
# subject has not arrived and the run learned nothing; `defer` means the run DID learn it, once,
# from the named arm, and reporting it again would be one finding counted twice. Without this
# split a single wrong figure fails four arms and three of them are vacuous.
defer() { printf '  ----  %s -- stands down; %s owns this finding\n' "$1" "$2"; }

# IN PROCESS. Every subject here -- the recovery hook, the gate, the postcompact hook and the budget
# validator -- is a whole script that reads its payload on stdin (or its arguments) and EXITS, so
# each call SOURCES the subject in a subshell of its own with the payload piped in: the content-seal
# recorder pattern. `exit` ends that subshell and never this script; BASH_SOURCE inside the sourced
# file is the subject's own path, so its sibling libraries resolve exactly as under `bash <file>`.
# Shell options are reset to what a fresh `bash` starts with (this script runs `set -uo pipefail`;
# a fresh bash has neither), and each subject then sets its own. Env knobs (`RECOVER_GATE_NET`, a
# shim `PATH`, `AI_DLC_PROJECT_ROOT`) are given as assignments before the call, which bash keeps in
# effect for the function and its subshell. A subshell's `$$` is THIS script's pid; the gate spells
# its stage and owed-file temps with `$$`, which is harmless because no two calls ever run at once in
# one project (the BL-730 background predicates each own a project). The equivalence cells below
# hold the in-process answer byte-identical to the CLI's, `bash <file>`, on a refusing and a passing
# input of each subject.
hook_run() { # hook_run <subject> <project> [args...] -- stdin is the payload
  _hr_f="$1"; _hr_p="$2"; shift 2
  # `hash -r`: a shim PATH given for this call (the sed and sleep shims) must win over a command this
  # script already looked up, exactly as it does in a fresh bash that has looked up nothing.
  ( set +u +e +o pipefail; hash -r; CLAUDE_PROJECT_DIR="$_hr_p"; export CLAUDE_PROJECT_DIR; [[ "$_hr_f" != */core/hooks/* ]] || fx_inproc "$_hr_f"; . "$_hr_f" "$@" )
}
val_run() { # val_run [args...] -- the budget validator, in process; stdout, stderr and the exit are its own
  ( set +u +e +o pipefail; hash -r; fx_inproc "$VAL" && . "$VAL" "$@" )
}
# THE PAYLOADS ARE BUILT WITH printf, NOT jq, and they carry only fixture-chosen ids and paths under
# $WORK. A $WORK that a JSON string could not carry verbatim is refused here, once, so a TMPDIR with a
# quote or a backslash breaks the run loudly instead of handing a hook a malformed payload that would
# read as a stand-down.
case "$WORK" in *'"'*|*'\'*) echo "FIXTURE BROKEN: \$WORK ($WORK) carries a quote or a backslash; printf-built payloads cannot carry it" >&2; exit 2 ;; esac
# ctx_of / dec_of: the one jq read of a hook's stdout, and no read at all when it printed nothing.
# They replace a python3 reader: dec_of answers `|` (allowed) for an empty or unparseable output,
# exactly as that reader's `except` did.
ctx_of() { [ -n "$1" ] || return 0; printf '%s' "$1" | jq -r '.hookSpecificOutput.additionalContext // empty' 2>/dev/null; }
dec_of() {
  [ -n "$1" ] || { printf '|\n'; return 0; }
  printf '%s' "$1" | jq -r '(.hookSpecificOutput // {}) | ((.permissionDecision // "") + "|" + ((.permissionDecisionReason // "") | gsub("\n"; " ")))' 2>/dev/null \
    || printf '|\n'
}

# Drive the hook exactly as the harness does: JSON on stdin, source=compact. `fire` is the
# seeded project; `fire_at` is any project, and `fire` is written in terms of it so the two
# cannot come to drive the hook differently.
fire_at() { # fire_at <hook-path> <project> -> prints additionalContext
  _fo="$(printf '{"source":"compact","session_id":"sess-A"}' | hook_run "$1" "$2" 2>/dev/null)"
  ctx_of "$_fo"
}
fire() { # <hook-path> -> prints additionalContext
  fire_at "$1" "$PROJECT"
}

# STRIP THE PROVENANCE MARKER BEFORE COMPARING TWO EMISSIONS. Every hook emission now opens with
# a marker line carrying a per-emission nonce, so two invocations of the SAME hook differ BY
# DESIGN and a raw byte comparison reports a difference for a reason that has nothing to do with
# the subject. Only the marker LINE is dropped -- every other byte is still compared -- so this
# normalizes the arm rather than weakening it.
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
if val_run --skill "$SKILL" --quiet >/dev/null 2>&1; then
  ok "validate-reattach-budget.sh passes the shipped SKILL.md (budget AND mandate)"
else
  bad "the shipped SKILL.md fails its own re-attach budget validator"
fi

# --- Assertion 6b: the WHOLE-FILE byte observation is reported, and it is the whole file --
# The only reader of SKILL.md's total size in the tree. It is an OBSERVATION -- it must never
# move the exit code -- so an arm keyed on a verdict could not fire on it at all, and its
# subject is the FIGURE.
#
# TWO INDEPENDENTLY DERIVED VALUES, COMPARED. The fixture takes `wc -c` of the file itself and
# the validator prints its own; reading the number back off the validator's rendering and
# declaring it correct would be a count read off a rendering, which is not a derived count.
VB_OUT="$(val_run --skill "$SKILL" 2>&1)"
whole_of() { # whole_of <validator output> -> the reported whole-file byte figure, or empty
  sed -n 's/^whole file  *: \([0-9][0-9]*\) bytes.*/\1/p' <<<"$1" | head -1
}
VB_WHOLE="$(whole_of "$VB_OUT")"
VB_REAL="$(wc -c < "$SKILL" | tr -d ' ')"
# THIS ARM OWNS ONE PROPERTY: THE FIGURE EXISTS AND IS THE WHOLE FILE. Delivery is 6b2's,
# because 6b2 DRIVES the renderer where this arm could only grep for the shape it needs, and
# the arm that runs the subject beats the one that reads its output. The three arms below all
# stand down when this one fires, so a validator with no figure -- or a wrong one -- produces
# ONE red arm rather than four true findings reported four times.
#
# `vb_owns` is the stand-down predicate, computed once and read by 6b2 and 6b3.
vb_owns=0
{ [ -z "$VB_WHOLE" ] || [ "$VB_WHOLE" != "$VB_REAL" ]; } && vb_owns=1
if [ -z "$VB_WHOLE" ] && [ "${IS_DIST:-0}" != 1 ]; then
  skip "the whole-file byte observation" "this validator predates it; the fixture ships one pull ahead of its subject"
elif [ -z "$VB_WHOLE" ]; then
  bad "the validator reports no whole-file byte figure at all — SKILL.md's total size has no reader in the tree, so a section added anywhere below the protocol moves nothing anybody prints"
elif [ "$VB_WHOLE" != "$VB_REAL" ]; then
  bad "the validator reports ${VB_WHOLE} bytes where wc -c of the same file gives ${VB_REAL} — the figure is not the whole file"
else
  ok "the validator reports whole file = ${VB_WHOLE} bytes, equal to an independently derived wc -c"
fi

# --- Assertion 6b2: the figure survives verdict.sh, which is the CONSUMER'S ONLY PATH ------
# THE ARM THAT OWNS DELIVERY, and the one the entry's whole purpose rests on. `verdict.sh`
# renders a passing validator's evidence with a grep anchored on `ok|warn|OK:|PASS|WARN|OVER`
# at line start; it is the only path by which this validator reaches a consumer, because the
# consumer's own `core/git-hooks/pre-push` never invokes it. Measured with the figure on a
# line of its own, and again on a six-space continuation of the PASS line: verdict.sh carried
# it 0 times each, against a control of 1 for the slack figure in the same run. The figure
# therefore has to sit INSIDE the PASS line's body, and only running the renderer proves it --
# a fixture grepping for the shape would be a second implementation of verdict.sh's filter.
#
# THE CONTROL IS IN THE SAME INVOCATION. A byte-figure count of 0 could mean the figure was
# dropped OR that verdict.sh printed nothing at all, and those are different facts; the slack
# figure is a token this rendering already carried before the change, so it discriminates a
# dropped figure from a dead renderer.
VD="$(dirname "$VAL")/verdict.sh"
if [ ! -f "$VD" ]; then
  skip "verdict.sh delivery of the byte figure" "verdict.sh is not beside the validator in this layout"
elif [ "$vb_owns" = 1 ]; then
  defer "verdict.sh delivery of the byte figure" "assertion 6b"
else
  VD_OUT="$(bash "$VD" "$(basename "$VAL")" --skill "$SKILL" 2>&1)"
  vd_fig="$(grep -cF "$VB_REAL" <<<"$VD_OUT")" || vd_fig=0
  vd_ctl="$(grep -c 'tokens of slack' <<<"$VD_OUT")" || vd_ctl=0
  if [ "$vd_ctl" -eq 0 ]; then
    bad "FIXTURE STALE: verdict.sh rendered no slack figure either, so its evidence filter or this call is broken and the byte figure's absence proves nothing about delivery"
  elif [ "$vd_fig" -eq 0 ]; then
    bad "verdict.sh renders the verdict WITHOUT the whole-file byte figure (control: the slack figure came through ${vd_ctl}x in the same run) — the observation does not reach a consumer's gate log, and verdict.sh is the only path that would carry it there"
  else
    ok "verdict.sh carries the whole-file figure into its evidence cell (${vd_fig} hit(s), control: slack ${vd_ctl})"
  fi
fi

# --- Assertion 6b3: the BARE invocation reports it too ------------------------------------
# EVERY OTHER CHANNEL PASSES `--skill`, AND `verdict.sh --all` DOES NOT. A validator that
# emitted the figure only under an explicit `--skill` would satisfy the receipt and every arm
# above while the consumer's actual `--all` call -- the one that runs with no arguments --
# reported nothing. The probe root is consumer-SHAPED because that is the layout the default
# path resolves in: the validator defaults to `<root>/.claude/skills/ai-dlc/SKILL.md`.
#
# AI_DLC_PROJECT_ROOT, not a `cd`. This validator resolves its own root by walking up, so a
# probe tree entered with `cd` is discarded and the run answers about the distribution.
BARE_P="$(mktemp -d "$WORK/bare.XXXXXX")"
mkdir -p "$BARE_P/.claude/skills/ai-dlc"
cp "$SKILL" "$BARE_P/.claude/skills/ai-dlc/SKILL.md"
BARE_REAL="$(wc -c < "$BARE_P/.claude/skills/ai-dlc/SKILL.md" | tr -d ' ')"
BARE_OUT="$(AI_DLC_PROJECT_ROOT="$BARE_P" val_run 2>&1)"; bare_rc=$?
BARE_WHOLE="$(whole_of "$BARE_OUT")"
if [ "$vb_owns" = 1 ]; then
  defer "the bare invocation's byte figure" "assertion 6b"
elif [ "$bare_rc" -ne 0 ]; then
  bad "FIXTURE STALE: the bare invocation against a consumer-shaped probe root exited ${bare_rc}, so it never reached the figure and this arm measures nothing. Output: $(head -1 <<<"$BARE_OUT")"
elif [ -z "$BARE_WHOLE" ]; then
  bad "the validator reports NO whole-file figure when invoked BARE — verdict.sh --all calls it with no arguments, so a figure emitted only under --skill never reaches the consumer path that actually runs"
elif [ "$BARE_WHOLE" != "$BARE_REAL" ]; then
  bad "the bare invocation reports ${BARE_WHOLE} bytes where wc -c of the resolved file gives ${BARE_REAL}"
else
  ok "the BARE invocation resolves its default SKILL.md and reports whole file = ${BARE_WHOLE} bytes (= wc -c of that copy)"
fi

# --- Assertion 6b4: --quiet suppresses the observation entirely ---------------------------
# THE OBSERVATION MUST GO THROUGH `say`, AND ONLY THE QUIET SIDE CAN ESTABLISH THAT. A raw
# `printf`, or a `say()` that ignores --quiet, emits the identical loud output and satisfies
# every arm above -- the loud and quiet halves are one property seen from two sides, and
# 6b/6b2/6b3 can only ever see the loud one. --quiet is what a caller uses to read the exit
# code alone, and a validator that prints anyway breaks that contract for every caller.
Q_OUT="$(val_run --skill "$SKILL" --quiet 2>&1)"; q_rc=$?
q_lines="$(printf '%s' "$Q_OUT" | grep -c '')" || q_lines=0
[ -z "$Q_OUT" ] && q_lines=0
if [ "$q_rc" -ne 0 ]; then
  bad "FIXTURE STALE: the shipped SKILL.md fails its own validator under --quiet (rc=${q_rc}), so this arm cannot measure suppression"
elif [ "$q_lines" -ne 0 ]; then
  bad "--quiet printed ${q_lines} line(s) on a passing run: $(head -1 <<<"$Q_OUT") — the observation (or another line) is not going through the say helper, so --quiet no longer means quiet for any caller that reads only the exit code"
else
  ok "--quiet suppresses every line including the observation, and still exits 0 — the figure goes through the say helper"
fi

# The validator's REFUSING input for the equivalence cell at the end of this file: SKILL.md with the digest
# path stripped, which the validator's mandate arm refuses.
NOMANDATE_SKILL="$WORK/skill-no-mandate.md"
sed 's|\.claude/skills/ai-dlc/postcompact-digest\.md|the rulebook digest|' "$SKILL" > "$NOMANDATE_SKILL"

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
# predicate is a FUNCTION, run against the real gate and asserted on its observable consequence.
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
  _go="$(printf '%s' "$3" | hook_run "$1" "$2" 2>/dev/null)"
  dec_of "$_go"
}
allowed() { case "$1" in "|"*) return 0 ;; *) return 1 ;; esac; }

jcall() { # jcall <tool> <file_path|-> — `-` is a tool that carries no file_path at all
  # session_id is the marker's owner (arm_marker writes sess-A), so the ladder below runs the
  # owner-equal path, which is the one production takes; with no id it ran only the no-id branch.
  if [ "$2" = "-" ]; then printf '{"tool_name":"%s","session_id":"sess-A","tool_input":{"command":"ls -la"}}' "$1"
  else printf '{"tool_name":"%s","session_id":"sess-A","tool_input":{"file_path":"%s"}}' "$1" "$2"; fi
}

# A BOUNDED Read, which is the shape the third filed skip took. `-` omits the field entirely, so
# `jbounded <p> - -` and `jcall Read <p>` are the same call and the two spellings cannot drift.
jbounded() { # jbounded <file_path> <limit|-> <offset|->
  _j="{\"tool_name\":\"Read\",\"session_id\":\"sess-A\",\"tool_input\":{\"file_path\":\"$1\""
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
  # The session id is `sess-A`, the one the advisor battery's calls carry: the gate's read stages
  # stand down for a call from a session other than the one the marker records, so a marker owned
  # by a different id would be invisible to every call below that names its session.
  printf '{"source":"compact","session_id":"sess-A"}' | hook_run "$1" "$2" >/dev/null 2>&1
}
mk="_bmad-output/.recover-fired"
pg="_bmad-output/.recover-gate-progress"

# ONE ARMED WORLD PER SHAPE, COPIED PER CELL (fixture-mutants.md clause 4). A cell whose subject is
# the GATE (or postcompact) needs a project the real producer armed, and arming is a producer run;
# the same few shapes were armed afresh by every predicate. So each shape is
# armed ONCE by the real producer and copied. KEYED ON CONTENT, NOT ON A PATH: the template is used
# only when the producer handed in is byte-identical to $HOOK, so any other producer (the legacy
# producer) always arms its own world live and is
# scored on what it writes. Cells whose subject IS the arming (the producer battery, a re-arm, the
# updater stand-down) never come through here. Every path the marker records is relative to the
# project, so a copy is the armed state of the project it lands in.
# The optional fourth argument adds files BEFORE arming, exactly where the inline seeds put them:
# `digest` the installed postcompact digest (the advisor battery), `rc` the digest plus a
# same-basename decoy under x/ (the BL-658..687 battery).
armed_proj() { # armed_proj <producer> <step-file-name|-> <consumer|flat|none> [digest|rc] -> a fresh armed project
  if cmp -s "$1" "$HOOK"; then
    _ak="$WORK/tpl/arm.$2.$3.${4:-plain}"
    if [ ! -d "$_ak" ]; then
      _ab="$(newproj "$2" "$3")"; proj_extra "$_ab" "${4:-}"; arm_marker "$HOOK" "$_ab"
      [ -f "$_ab/$mk" ] || { echo "FIXTURE BROKEN: the real producer armed no template for $2/$3/${4:-plain}" >&2; exit 2; }
      mkdir -p "$WORK/tpl"; mv "$_ab" "$_ak"
    fi
    _ap="$(mktemp -d "$WORK/proj.XXXXXX")" && cp -R "$_ak/." "$_ap/" && printf '%s\n' "$_ap"
  else
    _ap="$(newproj "$2" "$3")"; proj_extra "$_ap" "${4:-}"; arm_marker "$1" "$_ap"; printf '%s\n' "$_ap"
  fi
}
proj_extra() { # proj_extra <project> <''|digest|rc>
  case "$2" in
    digest) mkdir -p "$1/.claude/skills/ai-dlc"; printf 'digest\n' > "$1/.claude/skills/ai-dlc/postcompact-digest.md" ;;
    rc) mkdir -p "$1/.claude/skills/ai-dlc" "$1/x"
        printf 'digest body\n' > "$1/.claude/skills/ai-dlc/postcompact-digest.md"
        printf 'not the digest\n' > "$1/x/postcompact-digest.md" ;;
  esac
}

# --- the seven predicates ---------------------------------------------------
# Each prints PASS, or FAIL:<what it saw>. The arm prints the detail.

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
  _p="$(armed_proj "$HOOK" architecture.md flat)"
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
    consumer) _p="$(armed_proj "$HOOK" architecture.md consumer)" ;;
    *)        _p="$(armed_proj "$HOOK" architecture.md flat)" ;;
  esac
  case "$2" in
    abs) s="$_p/_bmad-output/pipeline-snapshot.md"; f="$_p/architecture.md" ;;
    rel) s="_bmad-output/pipeline-snapshot.md";     f="architecture.md" ;;
    consumer)
      # ABSOLUTE on purpose. The subject here is the LAYOUT, not the spelling, and the two
      # ladders above already own the spelling. With relative spellings instead, a gate that
      # matched one spelling only would fail this arm as well as `ladder_rel` -- two arms
      # reporting one finding.
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
  _p="$(armed_proj "$HOOK" - none)"
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
  _p="$(armed_proj "$HOOK" architecture.md flat)"
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
  _p="$(armed_proj "$LEGACY_PRODUCER" architecture.md flat)"
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
#    `mval` returns empty and the key checks stand the gate down for the same cases. So the
#    line is not a behavioural guard and an arm looking for a decision change could never fire
#    on it.
#
#    Its real subject is COST. This gate is registered against EVERY tool, so that line is
#    what keeps an ordinary call in an ordinary session from doing any work at all.
#
#    THE SIGNAL IS `sed`, AND PICKING IT WAS THE WHOLE DIFFICULTY. The obvious choice, `jq`,
#    is WRONG and measured wrong: `command -v jq` is a builtin lookup that executes nothing,
#    and the gate's first real `jq` call sits BELOW the stand-down checks — so an unarmed call
#    forks no jq whether the fast-path is there or not. `mval` is the first thing past the
#    line that forks, so `sed` is the first observable the line actually gates.
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
  _p="$(armed_proj "$HOOK" architecture.md flat)"
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
  _p="$(armed_proj "$HOOK" architecture.md flat)"
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

# 11/12. THE READ STAGES BIND THE LEAD ONLY (BL-590). The marker is project-wide, so before the
#    gate's teammate exit a teammate's call in the lead's recovery window was refused with the
#    lead's text (253 such denials measured on the reference consumer), and a teammate's two
#    Reads disarmed the LEAD's gate (graph session d5ba4ec4: the lead then edited the snapshot
#    unrefused and read its step file two minutes later). `jmate` is `jcall` plus `agent_id`, so
#    each teammate cell and its lead twin are one property apart and cannot drift.
jmate() { # jmate <tool> <file_path|-> <agent_id> -- jcall's call, made inside a teammate
  _jm="$(jcall "$1" "$2")"; printf '%s,"agent_id":"%s"}' "${_jm%\}}" "$3"
}
#    11. A teammate's Write/Bash/Agent while armed is allowed, and the LEAD's identical call in
#        the same state is still refused naming the first Read -- the twin that a gate exiting
#        for every caller fails.
p_mate_calls() {
  _p="$(armed_proj "$HOOK" architecture.md flat)"
  for _c in "Write:$_p/decoy.md" "Bash:-" "Agent:-"; do
    d="$(gate_call "$1" "$_p" "$(jmate "${_c%%:*}" "${_c#*:}" agent-m1)")"
    allowed "$d" || { printf 'FAIL:a teammate %s was refused during the lead recovery window\n' "${_c%%:*}"; return; }
    [ -e "$_p/$mk" ] || { printf 'FAIL:a teammate %s disarmed the lead gate\n' "${_c%%:*}"; return; }
    d="$(gate_call "$1" "$_p" "$(jcall "${_c%%:*}" "${_c#*:}")")"
    allowed "$d" && { printf 'FAIL:the lead %s was allowed before recovery\n' "${_c%%:*}"; return; }
    grep -q 'FIRST tool call must be' <<<"${d#*|}" || { printf 'FAIL:the lead %s was denied without naming the mandated first Read\n' "${_c%%:*}"; return; }
  done
  [ -e "$_p/$pg" ] && { printf 'FAIL:a teammate call or a denied lead call advanced the gate\n'; return; }
  printf 'PASS\n'
}
#    12. A teammate's two mandated Reads, full, leave the lead's gate armed at stage one; the
#        lead's same two Reads then advance and disarm it (the near-miss, one property apart).
p_mate_reads() {
  _p="$(armed_proj "$HOOK" architecture.md flat)"
  s="$_p/_bmad-output/pipeline-snapshot.md"; f="$_p/architecture.md"
  d="$(gate_call "$1" "$_p" "$(jmate Read "$s" agent-m1)")"
  allowed "$d" || { printf 'FAIL:a teammate Read of the snapshot was refused\n'; return; }
  [ -e "$_p/$pg" ] && { printf 'FAIL:a teammate snapshot Read advanced the lead recovery\n'; return; }
  d="$(gate_call "$1" "$_p" "$(jmate Read "$f" agent-m1)")"
  allowed "$d" || { printf 'FAIL:a teammate Read of the step file was refused\n'; return; }
  [ -e "$_p/$mk" ] || { printf 'FAIL:a teammate two Reads disarmed the lead gate\n'; return; }
  d="$(gate_call "$1" "$_p" "$(jcall Read "$s")")"
  allowed "$d" || { printf 'FAIL:the lead snapshot Read was denied after the teammate Reads\n'; return; }
  [ "$(cat "$_p/$pg" 2>/dev/null)" = step ] || { printf 'FAIL:the lead snapshot Read did not advance the gate\n'; return; }
  d="$(gate_call "$1" "$_p" "$(jcall Read "$f")")"
  allowed "$d" || { printf 'FAIL:the lead step Read was denied\n'; return; }
  [ -e "$_p/$mk" ] && { printf 'FAIL:the lead two Reads did not disarm the gate\n'; return; }
  printf 'PASS\n'
}

PREDS="inert deny_first ladder_abs ladder_rel ladder_consumer standdown_r0 standdown_missing legacy fastpath full_snapshot full_step mate_calls mate_reads"

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
    mate_calls)         r="$(p_mate_calls "$GATE")";         label="armed: a teammate's Write, Bash and Agent are allowed, and the lead's identical calls are still denied" ;;
    mate_reads)         r="$(p_mate_reads "$GATE")";         label="armed: a teammate's two mandated Reads leave the lead's gate armed, and the lead's same Reads disarm it" ;;
  esac
  if [ "$r" = PASS ]; then ok "gate: $label"; else bad "gate: $label — ${r#FAIL:}"; fi
done

# =============================================================================
# THE PRODUCER — ai-dlc-recover.sh, on the layout the protocol actually specifies
#
# Everything above drives the GATE. Two of the three defects this section
# was added for are in the INJECTOR, and one of them is invisible from the gate's side because
# the gate behaved correctly on the input it was given: the marker said the mandated file was
# `discovery.md`, no such file existed at the project root, and standing down was the right
# answer to a wrong question.
#
# So this is a SECOND battery, with its own predicates. It holds the gate at the real one and
# drives the producer, which is the only way a marker-content defect can be scored.
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
  # layout as the control this predicate went red on a producer that never resolves a bare
  # basename -- correctly, since nothing resolves there and the block then discloses -- but that is the OTHER arm's
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

for _n in $RPREDS; do
  case "$_n" in
    consumer)  r="$(pr_consumer "$HOOK")";  label="producer: a BARE BASENAME in the snapshot resolves under the steps directory, the mandate names the resolved path, and the gate ARMS instead of deleting its own marker" ;;
    assurance) r="$(pr_assurance "$HOOK")"; label="producer: the gate-assurance paragraph is made only where the gate can arm, and IS made where it can" ;;
  esac
  if [ "$r" = PASS ]; then ok "$label"; else bad "$label — ${r#FAIL:}"; fi
done


# =============================================================================
# THE ADVISOR STAGE — touchpoint R (BL-545)
#
# After both mandated Reads the gate holds the LEAD's Agent/Task/TaskCreate/Write/Edit/
# MultiEdit/NotebookEdit until its transcript shows an advisor attempt after the
# postcompact-digest.md Read. A third battery with its own predicates,
# holding the producer at the real one and driving the gate. Every DENY cell has its ALLOW twin
# in the same predicate (a Bash call in the same state), so a stage that refuses everything
# fails as surely as one that refuses nothing. The transcript is seeded in the harness's own
# line shapes, and the incoming call's own `tool_use` line is ON DISK with its id in the
# payload, which is the state where the stage's re-read stops at once.
# =============================================================================

OW="_bmad-output/.recover-advisor-owed"
# aproj [nodigest] -> a consumer-layout project, recovery armed by the REAL producer and both
# mandated Reads issued by the lead in session `sess-A`; the digest exists unless `nodigest`.
aproj() {
  if [ "${1:-}" = nodigest ]; then armed_proj "$HOOK" architecture.md consumer
  else armed_proj "$HOOK" architecture.md consumer digest; fi
}
# areads <gate> <project> [agent_id] -- the two mandated Reads, full, from the lead or a mate.
areads() {
  _sf="$(marker_step "$2")"
  for _f in "$2/_bmad-output/pipeline-snapshot.md" "$2/$_sf"; do
    if [ -n "${3:-}" ]; then _aj="$(jmate Read "$_f" "$3")"; else _aj="$(jcall Read "$_f")"; fi
    printf '%s' "$_aj" | hook_run "$1" "$2" >/dev/null 2>&1
  done
}
# tline <kind> <project> -> one transcript line in the harness's shape
tline() {
  case "$1" in
    grant)    printf '{"type":"attachment","attachment":{"type":"advisor_tool","available":true,"model":"m","toolChange":"add"}}\n' ;;
    boundary) printf '{"type":"system","subtype":"compact_boundary"}\n' ;;
    digest)   printf '{"type":"assistant","message":{"id":"m-dig","content":[{"type":"tool_use","id":"t-dig","name":"Read","input":{"file_path":"%s/.claude/skills/ai-dlc/postcompact-digest.md"}}]}}\n' "$2" ;;
    adv)      printf '{"type":"assistant","message":{"id":"m-adv%s","content":[{"type":"server_tool_use","id":"s-adv","name":"advisor","input":{}}]}}\n' "$RANDOM" ;;
    advok)    printf '{"type":"assistant","message":{"id":"m-res","content":[{"type":"advisor_tool_result","tool_use_id":"s-adv","content":{"type":"advisor_result","text":"ok"}}]}}\n' ;;
    advunav)  printf '{"type":"assistant","message":{"id":"m-res","content":[{"type":"advisor_tool_result","tool_use_id":"s-adv","content":{"type":"advisor_tool_result_error","error_code":"unavailable"}}]}}\n' ;;
    grantoff) printf '{"type":"attachment","attachment":{"type":"advisor_tool","available":false,"model":"m","toolChange":"remove"}}\n' ;;
    roster)   printf '{"type":"attachment","attachment":{"type":"deferred_tools_delta","addedNames":["mcp__advisor__consult"],"removedNames":[]}}\n' ;;
    consult)  printf '{"type":"assistant","message":{"id":"m-con%s","content":[{"type":"tool_use","id":"t-con%s","name":"mcp__advisor__consult","input":{"question":"q"}}]}}\n' "$RANDOM" "$RANDOM" ;;
    blobadv)  printf '{"type":"api-request-blob","hash":"h","sessionId":"sess-A","message":{"role":"user","content":[{"type":"server_tool_use","id":"s-adv","name":"advisor","input":{}}]}}\n' ;;
  esac
}
# acall <gate> <project> <tool> <transcript> [agent_id] [session] -> "<decision>|<reason>"
# Appends the incoming call's own tool_use line first, so it is on disk as the harness would
# have it after the race.
acall() {
  _id="tin-$RANDOM$RANDOM"
  printf '{"type":"assistant","message":{"id":"m-%s","content":[{"type":"tool_use","id":"%s","name":"%s","input":{}}]}}\n' "$_id" "$_id" "$3" >> "$4"
  _aa=""; [ -n "${5:-}" ] && _aa=",\"agent_id\":\"$5\""
  _ao="$(printf '{"tool_name":"%s","session_id":"%s","transcript_path":"%s","tool_use_id":"%s","tool_input":{"file_path":"x.md","command":"ls"}%s}' \
      "$3" "${6:-sess-A}" "$4" "$_id" "$_aa" | hook_run "$1" "$2" 2>/dev/null)"
  dec_of "$_ao"
}
# ONE SEEDED WORLD PER GATE PER PASS, COPIED PER PREDICATE. Seeding a world costs a producer run
# and two gate Reads (~0.6s at load 60) against ~0.02s for a copy, and the battery builds 17 worlds
# per pass over 11 passes, so seeding each one inline cost the fixture ~70s. The template is still
# armed BY THE GATE UNDER TEST (its two Reads). `A_TPL_GATE` records which gate built it; a
# mismatch rebuilds, never reuses.
A_TPL=""; A_TPL_GATE=""
a_tpl() { # a_tpl <gate> -- (re)build the template for this gate
  [ "$A_TPL_GATE" = "$1" ] && [ -d "$A_TPL" ] && return 0
  A_TPL="$(aproj)"; areads "$1" "$A_TPL"; A_TPL_GATE="$1"
}
# a_world <gate> <transcript-kinds...> -> project; the transcript is <project>/t.jsonl
a_world() {
  _g="$1"; shift
  a_tpl "$_g"
  _p="$(mktemp -d "$WORK/aw.XXXXXX")" || return 1
  cp -R "$A_TPL/." "$_p/"
  : > "$_p/t.jsonl"
  for _k in "$@"; do tline "$_k" "$_p" >> "$_p/t.jsonl"; done
  printf '%s\n' "$_p"
}

# A1. Digest read, no advisor since: every dispatch/write tool refused, naming R; Bash allowed.
a_deny() {
  _p="$(a_world "$1" grant boundary digest)"
  [ -e "$_p/$OW" ] || { printf 'FAIL:the satisfying step Read did not arm the advisor stage\n'; return; }
  d="$(acall "$1" "$_p" Bash "$_p/t.jsonl")"
  allowed "$d" || { printf 'FAIL:a Bash call (the wait-beat R puts first) was refused\n'; return; }
  # One refusal per tool, so the count resets between them (a second world per pair keeps the
  # escape bound of 3 from becoming this arm's subject).
  for _t in Agent Task TaskCreate Write Edit MultiEdit NotebookEdit; do
    _p="$(a_world "$1" grant boundary digest)"
    d="$(acall "$1" "$_p" "$_t" "$_p/t.jsonl")"
    allowed "$d" && { printf 'FAIL:%s was allowed with touchpoint R owed\n' "$_t"; return; }
    grep -q 'touchpoint R' <<<"${d#*|}" || { printf 'FAIL:%s was denied for some reason other than R\n' "$_t"; return; }
  done
  printf 'PASS\n'
}
# A2. An advisor attempt AFTER the digest Read clears the stage and removes its file.
a_after() {
  _p="$(a_world "$1" grant boundary digest adv advok)"
  d="$(acall "$1" "$_p" Agent "$_p/t.jsonl")"
  allowed "$d" || { printf 'FAIL:an Agent call after the R advisor attempt was denied\n'; return; }
  [ -e "$_p/$OW" ] && { printf 'FAIL:the stage cleared but left its file\n'; return; }
  printf 'PASS\n'
}
# A3. An advisor attempt BEFORE the digest Read does not satisfy R.
a_before() {
  _p="$(a_world "$1" grant boundary adv advok digest)"
  d="$(acall "$1" "$_p" Agent "$_p/t.jsonl")"
  allowed "$d" && { printf 'FAIL:an advisor attempt before the digest Read satisfied R\n'; return; }
  printf 'PASS\n'
}
# A4. The latest advisor result is `unavailable`: no call can clear it, so the stage stands down.
#     Same shape as A3 save the result kind, so only the unavailable test separates them.
a_unavail() {
  _p="$(a_world "$1" grant boundary adv advunav digest)"
  d="$(acall "$1" "$_p" Agent "$_p/t.jsonl")"
  allowed "$d" || { printf 'FAIL:an Agent call was refused while the advisor answers unavailable\n'; return; }
  printf 'PASS\n'
}
# A5. No grant line (a lead on a local model): never held.
# The pre-wait grant line of the hook is a COST fast-path, not the verdict guard: with it deleted
# the post-wait grant check stands the same call down after the wait. So this arm asserts that the
# wait loop is never ENTERED, as a COUNT load cannot move. The hook's loop calls a bare `sleep`
# (recover-gate line 274, no path), so a shim `sleep` first on PATH appends a line per call and
# returns at once. No grant line, R owed, the call's own line NEVER lands, RECOVER_GATE_NET=8:
# the real gate writes 0 lines; a gate that entered the loop would write more. The CONTROL, same shim
# and seed WITH a grant that stays on, must write >0 lines, which proves the shim is reached.
a_nogrant_run() { # a_nogrant_run <gate> <project> <counter> -> decision on stdout
  _sd="$(mktemp -d "$WORK/sleepshim.XXXXXX")"
  printf '#!/bin/bash\necho x >> "%s"\nexit 0\n' "$3" > "$_sd/sleep"; chmod +x "$_sd/sleep"
  : > "$3"
  _no="$(printf '{"tool_name":"Agent","session_id":"sess-A","transcript_path":"%s","tool_use_id":"toolu_nogrant_never","tool_input":{}}' "$2/t.jsonl" \
    | PATH="$_sd:$PATH" AI_DLC_TEST_RECOVER_GATE_NO_WALL=1 RECOVER_GATE_NET=8 hook_run "$1" "$2" 2>/dev/null)"
  _nd="$(dec_of "$_no")"; printf '%s\n' "${_nd%%|*}"
}
a_nogrant() {
  _p="$(a_world "$1" boundary digest)"
  _pc="$(a_world "$1" grant boundary digest)"
  [ -e "$_pc/$OW" ] && [ -e "$_p/$OW" ] || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: the lead Reads did not arm the advisor stage\n'; return; }
  _ctl="$(a_nogrant_run "$1" "$_pc" "$_pc/sleeps")"
  [ "$_ctl" = deny ] && { printf 'FAIL:CONTROL: an unseen call was denied at the net\n'; return; }
  [ "$(wc -l < "$_pc/sleeps")" -gt 0 ] || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: the sleep shim was never reached with a grant on\n'; return; }
  d="$(a_nogrant_run "$1" "$_p" "$_p/sleeps")"
  [ "$d" = deny ] && { printf 'FAIL:a lead with no advisor grant was held on R\n'; return; }
  [ -e "$_p/$OW" ] && { printf 'FAIL:a lead with no advisor grant kept the owed file\n'; return; }
  [ "$(wc -l < "$_p/sleeps")" -eq 0 ] || { printf 'FAIL:a lead with no advisor grant entered the wait loop (%s sleeps)\n' "$(wc -l < "$_p/sleeps" | tr -d ' ')"; return; }
  printf 'PASS\n'
}
# A6. A teammate is not the lead: its dispatch is untouched, and the lead's owed R survives it.
#     THE SEED IS SATISFIED BY THE LEAD'S READS, never a teammate's. The recovery is the lead's:
#     a teammate reading the snapshot reloads nothing into the lead's context, so the read stages
#     do not count it (BL-590), and whether a teammate's Read arms R is no longer a question this
#     stage can be asked -- the read battery's `mate_reads` owns it. The twin is the lead's own
#     Agent call in the same state, one property apart, still refused naming R.
a_mate() {
  _p="$(a_world "$1" grant boundary digest)"
  [ -e "$_p/$OW" ] || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: the lead Reads did not arm the advisor stage\n'; return; }
  d="$(acall "$1" "$_p" Agent "$_p/t.jsonl" agent-x1)"
  allowed "$d" || { printf 'FAIL:a teammate Agent call was refused on the lead R touchpoint\n'; return; }
  [ -e "$_p/$OW" ] || { printf 'FAIL:a teammate call discharged the lead owed R\n'; return; }
  d="$(acall "$1" "$_p" Agent "$_p/t.jsonl")"
  allowed "$d" && { printf 'FAIL:the lead Agent call after a teammate call was allowed with R still owed\n'; return; }
  grep -q 'touchpoint R' <<<"${d#*|}" || { printf 'FAIL:the lead Agent call was denied for some reason other than R\n'; return; }
  printf 'PASS\n'
}
# A7. No readable digest: R is not owed, so the satisfying step Read does not arm the stage.
a_nodigest() {
  _p="$(aproj nodigest)"; areads "$1" "$_p"
  [ -e "$_p/$mk" ] && { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: the read stages did not disarm\n'; return; }
  [ -e "$_p/$OW" ] && { printf 'FAIL:the stage armed in a tree with no postcompact digest\n'; return; }
  printf 'PASS\n'
}
# A8. The bounded escape: three refusals, then the stage stands down and removes its file.
a_bound() {
  _p="$(a_world "$1" grant boundary digest)"
  for _i in 1 2 3; do
    d="$(acall "$1" "$_p" Agent "$_p/t.jsonl")"
    allowed "$d" && { printf 'FAIL:refusal %s of 3 was an allow\n' "$_i"; return; }
  done
  d="$(acall "$1" "$_p" Agent "$_p/t.jsonl")"
  allowed "$d" || { printf 'FAIL:a fourth refusal -- the escape bound does not hold\n'; return; }
  [ -e "$_p/$OW" ] && { printf 'FAIL:stood down but kept its file\n'; return; }
  printf 'PASS\n'
}
# A9. A call from another session in the same project: the owed file is stale, not this lead's.
a_session() {
  _p="$(a_world "$1" grant boundary digest)"
  d="$(acall "$1" "$_p" Agent "$_p/t.jsonl" "" sess-B)"
  allowed "$d" || { printf 'FAIL:another session was held on this lead R touchpoint\n'; return; }
  printf 'PASS\n'
}
# A12. No grant, but the lead HOLDS mcp__advisor__consult (BL-1136): held, naming that tool, file
#      kept; a consult after the digest Read clears it and removes the file (the ALLOW twin, one
#      line apart); a consult BEFORE the digest Read does not.
a_holder() {
  _p="$(a_world "$1" roster boundary digest)"
  [ -e "$_p/$OW" ] || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: the lead Reads did not arm the advisor stage\n'; return; }
  d="$(acall "$1" "$_p" Agent "$_p/t.jsonl")"
  allowed "$d" && { printf 'FAIL:a no-grant lead holding the consult was not held on R\n'; return; }
  grep -q 'call mcp__advisor__consult' <<<"${d#*|}" || { printf 'FAIL:the no-grant deny does not name mcp__advisor__consult\n'; return; }
  [ -e "$_p/$OW" ] || { printf 'FAIL:the held no-grant lead lost its owed file\n'; return; }
  _p="$(a_world "$1" roster boundary digest consult)"
  d="$(acall "$1" "$_p" Agent "$_p/t.jsonl")"
  allowed "$d" || { printf 'FAIL:a consult after the digest Read did not clear the no-grant lead\n'; return; }
  [ -e "$_p/$OW" ] && { printf 'FAIL:the consult cleared the stage but left its file\n'; return; }
  _p="$(a_world "$1" roster boundary consult digest)"
  d="$(acall "$1" "$_p" Agent "$_p/t.jsonl")"
  allowed "$d" && { printf 'FAIL:a consult BEFORE the digest Read satisfied R\n'; return; }
  printf 'PASS\n'
}
# A13. A granted lead's consult is not its attempt; a withdrawn grant with the consult held is held
#      on the consult. The deny texts name the built-in tool and the consult respectively.
a_grantcons() {
  _p="$(a_world "$1" grant boundary digest consult)"
  d="$(acall "$1" "$_p" Agent "$_p/t.jsonl")"
  allowed "$d" && { printf 'FAIL:a consult cleared a GRANTED lead\n'; return; }
  grep -q 'You hold the built-in advisor tool' <<<"${d#*|}" || { printf 'FAIL:the granted deny does not name the built-in tool\n'; return; }
  _p="$(a_world "$1" grant grantoff roster boundary digest)"
  d="$(acall "$1" "$_p" Agent "$_p/t.jsonl")"
  allowed "$d" && { printf 'FAIL:a withdrawn grant with the consult held was not held\n'; return; }
  grep -q 'call mcp__advisor__consult' <<<"${d#*|}" || { printf 'FAIL:the withdrawn-grant deny does not name mcp__advisor__consult\n'; return; }
  printf 'PASS\n'
}
# A14. An advisor attempt re-carried on an `api-request-blob` line clears nothing (BL-1137). The
#      ALLOW twin is A2: the same attempt on an assistant line clears.
a_blob() {
  _p="$(a_world "$1" grant boundary digest blobadv)"
  d="$(acall "$1" "$_p" Agent "$_p/t.jsonl")"
  allowed "$d" && { printf 'FAIL:a blob-carried advisor attempt cleared R\n'; return; }
  [ -e "$_p/$OW" ] || { printf 'FAIL:a blob-carried advisor attempt removed the owed file\n'; return; }
  printf 'PASS\n'
}
# A15. The detection library unreadable: the stage WARNS on stderr and is silent, file kept. The
#      control is the same world through the shipped gate, which refuses.
a_nolib() {
  _p="$(a_world "$1" grant boundary digest)"
  _c="$(a_world "$1" grant boundary digest)"
  d="$(acall "$1" "$_c" Agent "$_c/t.jsonl")"
  allowed "$d" && { printf 'FAIL:CONTROL: the shipped gate did not refuse the owed call\n'; return; }
  _ld="$(mktemp -d "$WORK/nolib.XXXXXX")"; cp "$1" "$_ld/ai-dlc-recover-gate.sh"
  [ -e "$_ld/ai-dlc-advisor-detect.sh" ] && { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: the library is beside the copy\n'; return; }
  _id="tin-nolib$RANDOM"
  printf '{"type":"assistant","message":{"id":"m-%s","content":[{"type":"tool_use","id":"%s","name":"Agent","input":{}}]}}\n' "$_id" "$_id" >> "$_p/t.jsonl"
  _no="$(printf '{"tool_name":"Agent","session_id":"sess-A","transcript_path":"%s","tool_use_id":"%s","tool_input":{}}' "$_p/t.jsonl" "$_id" \
    | hook_run "$_ld/ai-dlc-recover-gate.sh" "$_p" 2>"$_ld/err")"
  _ne="$(cat "$_ld/err")"
  [ -z "$_no" ] || { printf 'FAIL:the gate without its library printed a decision\n'; return; }
  grep -q 'WARN: ai-dlc-recover-gate: the advisor detection library is unreadable' <<<"$_ne" || { printf 'FAIL:the gate without its library gave no stderr WARN\n'; return; }
  [ -e "$_p/$OW" ] || { printf 'FAIL:the gate without its library removed the owed file\n'; return; }
  printf 'PASS\n'
}

# NO ARM ASSERTS THAT THE INJECTED BLOCK NAMES R, because it does not. The block has no room
# to spare for it: the headroom under the cliff in gate-resume's worst gate-in-flight world is
# held by gate-resume's WC arm (WC_MARGIN), and an R clause would spend it. R reaches the lead
# through SKILL.md's Rule 32 entry, which the digest the lead has just read carries verbatim,
# and through the deny text, which names R and its remedy.
#
# A11. A NEW recovery clears a window the previous one left open (the producer, arg 1).
a_reclear() {
  _p="$(a_world "$GATE" grant boundary digest)"
  [ -e "$_p/$OW" ] || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: no open window to clear\n'; return; }
  arm_marker "$1" "$_p"
  [ -e "$_p/$OW" ] && { printf 'FAIL:a new recovery left the previous advisor window open\n'; return; }
  printf 'PASS\n'
}
r_re="$(a_reclear "$HOOK")"
if [ "$r_re" = PASS ]; then ok "R: a new recovery clears the advisor window the previous one left"
else bad "R: a new recovery clears the advisor window the previous one left — ${r_re#FAIL:}"; fi

APREDS="deny after before unavail nogrant mate nodigest bound session holder grantcons blob nolib"

a_tpl "$GATE"
for _n in $APREDS; do
  r="$("a_$_n" "$GATE")"
  case "$_n" in
    deny)     label="R: after the digest Read with no advisor attempt, Agent and Write are refused naming R, Bash is allowed" ;;
    after)    label="R: an advisor attempt after the digest Read clears the stage" ;;
    before)   label="R: an advisor attempt BEFORE the digest Read does not satisfy it" ;;
    unavail)  label="R: an 'unavailable' advisor result stands the stage down" ;;
    nogrant)  label="R: a lead holding neither advisor is never held" ;;
    holder)   label="R: a no-grant lead holding mcp__advisor__consult is held until a consult after the digest Read" ;;
    grantcons) label="R: a granted lead's consult does not clear it; a withdrawn grant with the consult held is held" ;;
    blob)     label="R: an advisor attempt on an api-request-blob line clears nothing" ;;
    nolib)    label="R: the detection library unreadable -> stderr WARN, silent, owed file kept" ;;
    mate)     label="R: a teammate's dispatch is untouched while the lead owes R, and the lead is still held" ;;
    nodigest) label="R: no readable postcompact digest, no stage" ;;
    bound)    label="R: the escape bound -- three refusals, then the stage stands down" ;;
    session)  label="R: another session's call is not held on this lead's touchpoint" ;;
  esac
  if [ "$r" = PASS ]; then ok "$label"; else bad "$label — ${r#FAIL:}"; fi
done

# =============================================================================
# WHOSE RECOVERY — an update session is not the lead, and a marker has an owner
#
# A fourth battery with its own predicates. ai-dlc-recover.sh used to write
# the marker for ANY session that compacted and the gate denied ANY session's calls on it, so a
# consumer-pull session (/ai-dlc-update) was handed the lead's recovery mandate -- 2 of the 78
# updater transcripts on the reference consumer, one of them with no compaction in it at all,
# denied 11 seconds in by a marker another session left. Two stand-downs close that, and they
# are SEPARATE subjects: the producer writes nothing for an updater, and the gate stands down
# (marker kept) for an updater and for a marker owned by another session.
#
# THE TWO GATE STAND-DOWNS COVER EACH OTHER on the obvious seed (a stale marker, an updater
# calling): disabling either leaves the other doing the work.
# So each has a case only it can reach. `legacy_upd` carries no owner, so only the updater test
# can stand down; `stale_pipe` is a pipeline session, so only the owner test can. The stale
# marker is always written by the REAL producer, never by hand; the legacy marker is that same
# output with its `session_id=` line removed, which is what the previous revision emitted.
#
# TRANSCRIPT SEEDS ARE THE HARNESS'S RECORD SHAPE for the typed command, the first alternative of
# the I126 regex, with the JSON-escaped newline between the two tags as the real files carry it.
# =============================================================================

if ! grep -qF 'mval session_id' "$GATE" || ! grep -qF 'printf '"'"'session_id=%s' "$HOOK"; then
  skip "whose-recovery arms" "the installed recovery hooks predate the session_id key; this fixture ships one pull ahead of its subject"
else

stx() { # stx <upd|pipe> <path> -- a transcript whose LAST ai-dlc marker is the updater / the pipeline
  _sk="ai-dlc"; [ "$1" = upd ] && _sk="ai-dlc-update"
  { printf '%s\n' '{"type":"user","message":{"role":"user","content":"an earlier prompt"}}'
    printf '%s\n' '{"type":"user","message":{"role":"user","content":"<command-message>'"$_sk"'</command-message>\n<command-name>/'"$_sk"'</command-name>"}}'
  } > "$2"
}
sarm() { # sarm <recover-hook> <project> <session> <transcript> -- the producer, driven as SessionStart:compact
  printf '{"source":"compact","session_id":"%s","transcript_path":"%s"}' "$3" "$4" | hook_run "$1" "$2" >/dev/null 2>&1
}
sdec() { # sdec <gate> <project> <session> <transcript> -> deny | silent, for a Bash call
  _o="$(printf '{"tool_name":"Bash","session_id":"%s","transcript_path":"%s","tool_input":{"command":"ls"}}' "$3" "$4" \
    | hook_run "$1" "$2" 2>/dev/null)"
  _o="$(dec_of "$_o")"
  if [ "${_o%%|*}" = deny ]; then printf 'deny\n'; else printf 'silent\n'; fi
}
# armed_sa <producer> <transcript name> -> a consumer project whose pipeline transcript is <name>,
# armed by <producer> as session S-A. The same content-keyed template rule as armed_proj: a copy of
# the real producer's world when <producer> is byte-identical to $HOOK, a live arming otherwise. The
# marker records no transcript path, so the copy is the armed state of the project it lands in.
armed_sa() {
  if cmp -s "$1" "$HOOK"; then
    _sk2="$WORK/tpl/sa.$2"
    if [ ! -d "$_sk2" ]; then
      _sb="$(newproj architecture.md consumer)"; stx pipe "$_sb/$2"; sarm "$HOOK" "$_sb" S-A "$_sb/$2"
      grep -qx 'session_id=S-A' "$_sb/$mk" 2>/dev/null || { echo "FIXTURE BROKEN: the real producer armed no S-A template" >&2; exit 2; }
      mkdir -p "$WORK/tpl"; mv "$_sb" "$_sk2"
    fi
    _sp="$(mktemp -d "$WORK/proj.XXXXXX")" && cp -R "$_sk2/." "$_sp/" && printf '%s\n' "$_sp"
  else
    _sp="$(newproj architecture.md consumer)"; stx pipe "$_sp/$2"; sarm "$1" "$_sp" S-A "$_sp/$2"; printf '%s\n' "$_sp"
  fi
}
sunowned() { # sunowned <project> -- the marker as the previous revision wrote it: no owner
  grep -v '^session_id=' "$1/$mk" > "$1/$mk.n" 2>/dev/null; mv "$1/$mk.n" "$1/$mk"
}

# C1. An update session compacts: the producer writes NO marker, and the gate is silent.
sp_upd_compact() { # <hook> <gate>
  _p="$(newproj architecture.md consumer)"; stx upd "$_p/t.jsonl"
  sarm "$1" "$_p" S-U "$_p/t.jsonl"
  [ -e "$_p/$mk" ] && { printf 'FAIL:the producer wrote a recovery marker for an update session\n'; return; }
  [ "$(sdec "$2" "$_p" S-U "$_p/t.jsonl")" = silent ] || { printf 'FAIL:the gate denied a Bash call in an update session\n'; return; }
  printf 'PASS\n'
}
# C2. THE CONTROL THAT THE STAND-DOWN IS NOT A BLANKET DISABLE: the same shape with a pipeline marker.
sp_pipe_compact() {
  _p="$(newproj architecture.md consumer)"; stx pipe "$_p/t.jsonl"
  sarm "$1" "$_p" S-P "$_p/t.jsonl"
  [ -e "$_p/$mk" ] || { printf 'FAIL:the producer wrote no marker for a pipeline session that compacted\n'; return; }
  grep -qx 'session_id=S-P' "$_p/$mk" || { printf 'FAIL:the marker does not record the session that compacted\n'; return; }
  [ "$(sdec "$2" "$_p" S-P "$_p/t.jsonl")" = deny ] || { printf 'FAIL:the gate let a pipeline session'"'"'s first post-compact Bash call through\n'; return; }
  printf 'PASS\n'
}
# C3. A stale marker from session A, no compaction in B, and B is an update session: silent, marker kept.
sp_stale_upd() {
  _p="$(armed_sa "$1" tA.jsonl)"; stx upd "$_p/tB.jsonl"
  grep -qx 'session_id=S-A' "$_p/$mk" 2>/dev/null || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE — no marker owned by session A\n'; return; }
  [ "$(sdec "$2" "$_p" S-B "$_p/tB.jsonl")" = silent ] || { printf 'FAIL:an update session was denied on a marker another session left\n'; return; }
  [ -e "$_p/$mk" ] || { printf 'FAIL:the stand-down deleted a marker that is another session'"'"'s pending recovery\n'; return; }
  printf 'PASS\n'
}
# C4. A stale marker from session A, B is a PIPELINE session: only the owner test can stand down.
sp_stale_pipe() {
  _p="$(armed_sa "$1" tA.jsonl)"; stx pipe "$_p/tB.jsonl"
  grep -qx 'session_id=S-A' "$_p/$mk" 2>/dev/null || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE — no marker owned by session A\n'; return; }
  [ "$(sdec "$2" "$_p" S-B "$_p/tB.jsonl")" = silent ] || { printf 'FAIL:session B was denied on a recovery owed to session A\n'; return; }
  [ -e "$_p/$mk" ] || { printf 'FAIL:the stand-down deleted session A'"'"'s marker\n'; return; }
  printf 'PASS\n'
}
# C5. THE SAME-SESSION CONTROL for C3/C4: the owner, a pipeline session, is denied.
sp_same_sess() {
  _p="$(armed_sa "$1" tA.jsonl)"
  [ "$(sdec "$2" "$_p" S-A "$_p/tA.jsonl")" = deny ] || { printf 'FAIL:the session that owns the marker was let through\n'; return; }
  printf 'PASS\n'
}
# C6. BACK-COMPAT: a marker with no session_id (an older hook wrote it) still gates a pipeline session.
sp_legacy_pipe() {
  _p="$(armed_sa "$1" tA.jsonl)"; stx pipe "$_p/tB.jsonl"; sunowned "$_p"
  grep -q '^session_id=' "$_p/$mk" 2>/dev/null && { printf 'FAIL:SEED CANNOT EXPRESS THE CASE — the marker still carries an owner\n'; return; }
  grep -q '^step_file_resolved=1$' "$_p/$mk" 2>/dev/null || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE — the marker is not armable\n'; return; }
  [ "$(sdec "$2" "$_p" S-B "$_p/tB.jsonl")" = deny ] || { printf 'FAIL:an ownerless marker stopped gating a pipeline session\n'; return; }
  printf 'PASS\n'
}
# C7. An ownerless marker and an UPDATE session: only the updater test can stand down. Marker kept.
sp_legacy_upd() {
  _p="$(armed_sa "$1" tA.jsonl)"; stx upd "$_p/tB.jsonl"; sunowned "$_p"
  grep -q '^session_id=' "$_p/$mk" 2>/dev/null && { printf 'FAIL:SEED CANNOT EXPRESS THE CASE — the marker still carries an owner\n'; return; }
  [ "$(sdec "$2" "$_p" S-B "$_p/tB.jsonl")" = silent ] || { printf 'FAIL:an update session was denied on an ownerless marker\n'; return; }
  [ -e "$_p/$mk" ] || { printf 'FAIL:the updater stand-down deleted a marker that may be a real lead'"'"'s pending recovery\n'; return; }
  printf 'PASS\n'
}

# C8/C9. ORDER: the stand-downs sit ABOVE the readability block, which DELETES the marker. A call
# that is not owed the recovery must not be the one to clear it, and with the snapshot present the
# readability block is never reached, so no case above can see the order. Each predicate deletes the
# snapshot, asserts the stand-down is silent AND the marker survives, and carries a control in a
# second project proving the seed reaches the readability block (the same-owner / pipeline call
# there stands down AND clears the marker).
sp_ord_pipe() {
  _p="$(armed_sa "$1" tA.jsonl)"; stx pipe "$_p/tB.jsonl"
  grep -qx 'session_id=S-A' "$_p/$mk" 2>/dev/null || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE — no marker owned by session A\n'; return; }
  rm -f "$_p/_bmad-output/pipeline-snapshot.md"
  [ -e "$_p/_bmad-output/pipeline-snapshot.md" ] && { printf 'FAIL:SEED CANNOT EXPRESS THE CASE — the snapshot did not vanish\n'; return; }
  [ "$(sdec "$2" "$_p" S-B "$_p/tB.jsonl")" = silent ] || { printf 'FAIL:session B was denied on a recovery owed to session A\n'; return; }
  [ -e "$_p/$mk" ] || { printf 'FAIL:a non-owner call cleared the lead'"'"'s pending recovery through the readability block\n'; return; }
  _q="$(armed_sa "$1" tA.jsonl)"; rm -f "$_q/_bmad-output/pipeline-snapshot.md"
  sdec "$2" "$_q" S-A "$_q/tA.jsonl" >/dev/null
  [ -e "$_q/$mk" ] && { printf 'FAIL:CONTROL — the owner'"'"'s call on a vanished snapshot left the marker, so the seed never reaches the readability block\n'; return; }
  printf 'PASS\n'
}
sp_ord_upd() {
  _p="$(armed_sa "$1" tA.jsonl)"; stx upd "$_p/tU.jsonl"; sunowned "$_p"
  grep -q '^session_id=' "$_p/$mk" 2>/dev/null && { printf 'FAIL:SEED CANNOT EXPRESS THE CASE — the marker still carries an owner\n'; return; }
  rm -f "$_p/_bmad-output/pipeline-snapshot.md"
  [ "$(sdec "$2" "$_p" S-U "$_p/tU.jsonl")" = silent ] || { printf 'FAIL:an update session was denied on an ownerless marker\n'; return; }
  [ -e "$_p/$mk" ] || { printf 'FAIL:an update session'"'"'s call cleared a lead'"'"'s pending recovery through the readability block\n'; return; }
  _q="$(armed_sa "$1" tA.jsonl)"; sunowned "$_q"; rm -f "$_q/_bmad-output/pipeline-snapshot.md"
  sdec "$2" "$_q" S-B "$_q/tA.jsonl" >/dev/null
  [ -e "$_q/$mk" ] && { printf 'FAIL:CONTROL — a pipeline call on a vanished snapshot left the marker, so the seed never reaches the readability block\n'; return; }
  printf 'PASS\n'
}

SPREDS="upd_compact pipe_compact stale_upd stale_pipe same_sess legacy_pipe legacy_upd ord_pipe ord_upd"

for _n in $SPREDS; do
  r="$("sp_$_n" "$HOOK" "$GATE")"
  case "$_n" in
    upd_compact) label="whose: an update session that compacts gets NO marker and a silent gate" ;;
    pipe_compact) label="whose: CONTROL — a pipeline session that compacts gets a marker naming it, and its first Bash call is DENIED" ;;
    stale_upd) label="whose: an update session is silent on another session's stale marker, and the marker survives" ;;
    stale_pipe) label="whose: a pipeline session is silent on a marker owned by ANOTHER session, and the marker survives" ;;
    same_sess) label="whose: CONTROL — the session that owns the marker is denied" ;;
    legacy_pipe) label="whose: BACK-COMPAT — a marker with no session_id still gates a pipeline session" ;;
    legacy_upd) label="whose: an update session is silent on an ownerless marker, and the marker survives" ;;
    ord_pipe) label="whose: ORDER — a non-owner call on a vanished snapshot is silent and does NOT clear the owner's marker" ;;
    ord_upd) label="whose: ORDER — an update session's call on a vanished snapshot is silent and does NOT clear an ownerless marker" ;;
  esac
  if [ "$r" = PASS ]; then ok "$label"; else bad "$label — ${r#FAIL:}"; fi
done

fi  # whose-recovery arms present

# A10. THE NET IS NOT A DENY (BL-630). R owed, and the incoming call's own `tool_use` line NEVER
# lands (acall always appends it, so no predicate above can reach this branch): the safety net
# expires with R_SEEN=0, a transcript the stage cannot read. It must ALLOW, say why on stderr, and
# not count a refusal -- `denies=` unchanged. The pre-BL-630 gate denied here, so a correct advisor
# call whose line was merely late (load makes it later) was refused. Outside APREDS on purpose:
# it pays the net by construction, so it runs with
# RECOVER_GATE_NET=2 (BL-730: the knob only shortens the 300s default) and greps a net-agnostic
# stderr reason.
a_net() {
  _p="$(a_world "$1" grant boundary digest)"
  [ -e "$_p/$OW" ] || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: the advisor stage did not arm\n'; return; }
  _d0="$(sed -n 's/^denies=//p' "$_p/$OW")"
  _e="$_p/net.err"
  d="$(printf '{"tool_name":"Agent","session_id":"sess-A","transcript_path":"%s","tool_use_id":"tin-never","tool_input":{}}' "$_p/t.jsonl" \
    | AI_DLC_TEST_RECOVER_GATE_NO_WALL=1 RECOVER_GATE_NET=2 hook_run "$1" "$_p" 2>"$_e")"
  d="$(dec_of "$d")"; d="${d%%|*}"
  [ "$d" = deny ] && { printf 'FAIL:an unseen call was denied when the safety net expired\n'; return; }
  grep -q 'did not land within the' "$_e" || { printf 'FAIL:the stand-down gave no stderr reason\n'; return; }
  [ -e "$_p/$OW" ] || { printf 'FAIL:the stand-down removed the owed file, so R is forgotten for the next dispatch\n'; return; }
  [ "$(sed -n 's/^denies=//p' "$_p/$OW")" = "$_d0" ] || { printf 'FAIL:the stand-down counted a refusal\n'; return; }
  printf 'PASS\n'
}
r_net="$(a_net "$GATE")"
if [ "$r_net" = PASS ]; then ok "R: the safety net's expiry with the incoming call's line unseen allows, uncounted, with a stderr reason"
else bad "R: the safety net's expiry with the incoming call's line unseen — ${r_net#FAIL:}"; fi

# =============================================================================
# ONE DECISION PER MESSAGE, AND A WAIT THAT OUTLASTS THE FLUSH (BL-730)
#
# Measured on graph transcript a367e62c: one message carried 19 Agent calls, the harness ran each
# call's PreToolUse as its block finished streaming (~7s apart, overlapping), and the message's
# lines reached disk together at message end. Calls 1-17 hit the old 10s net and were dispatched
# uncounted; calls 18 and 19, each still pending at the flush around 05:57:24, were refused. The
# gate now waits up to R_NET (300s) for the call's own line and counts one refusal per message.
#
# Five predicates. They run in the BACKGROUND, every predicate
# at once, because `rflush_ctl` waits out two short nets (`rflush` and `rwithdraw`
# count the gate's ticks through a shim and wait no wall clock); serially the battery would pay that wall clock. Each child's pid is
# recorded and `wait`ed, and each writes its verdict to a file named for the predicate.
# =============================================================================

# rcall <gate> <project> <tool_use_id> <net> [stderr file] -> deny | empty, for an Agent call
rcall() {
  _rco="$(printf '{"tool_name":"Agent","session_id":"sess-A","transcript_path":"%s","tool_use_id":"%s","tool_input":{}}' "$2/t.jsonl" "$3" \
    | AI_DLC_TEST_RECOVER_GATE_NO_WALL=1 RECOVER_GATE_NET="$4" hook_run "$1" "$2" 2>"${5:-/dev/null}")"
  _rco="$(dec_of "$_rco")"; printf '%s\n' "${_rco%%|*}"
}
# mline <message id> <tool_use id...> -> ONE assistant line carrying those Agent tool_use blocks,
# which is the shape a parallel dispatch is recorded in.
mline() {
  _m="$1"; shift; _c=""
  for _u in "$@"; do _c="${_c:+$_c,}{\"type\":\"tool_use\",\"id\":\"$_u\",\"name\":\"Agent\",\"input\":{}}"; done
  printf '{"type":"assistant","message":{"id":"%s","content":[%s]}}\n' "$_m" "$_c"
}
owv() { sed -n "s/^$2=//p" "$1/$OW" 2>/dev/null | head -1; } # owv <project> <key>

# R1. Two calls of ONE message, both lines on disk: both refused, and the message counts once.
a_rmsg() {
  _p="$(a_world "$1" grant boundary digest)"
  [ -e "$_p/$OW" ] || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: the advisor stage did not arm\n'; return; }
  mline M1 toolu_rmsg_a toolu_rmsg_b >> "$_p/t.jsonl"
  [ "$(rcall "$1" "$_p" toolu_rmsg_a 2)" = deny ] || { printf 'FAIL:the first call of message M1 was not refused\n'; return; }
  [ "$(rcall "$1" "$_p" toolu_rmsg_b 2)" = deny ] || { printf 'FAIL:the second call of a refused message was let through\n'; return; }
  [ "$(owv "$_p" denies)" = 1 ] || { printf 'FAIL:two calls of one message counted %s refusals, not 1\n' "$(owv "$_p" denies)"; return; }
  [ "$(owv "$_p" denied_msg)" = M1 ] || { printf 'FAIL:the owed file does not record the refused message (denied_msg=%s)\n' "$(owv "$_p" denied_msg)"; return; }
  printf 'PASS\n'
}
# R1c. CONTROL that the per-message rule is not a count frozen at 1: a call in M1, then a call in
# M2, counts 1 then 2.
a_rmsg_ctl() {
  _p="$(a_world "$1" grant boundary digest)"
  [ -e "$_p/$OW" ] || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: the advisor stage did not arm\n'; return; }
  mline M1 toolu_rctl_a >> "$_p/t.jsonl"; mline M2 toolu_rctl_b >> "$_p/t.jsonl"
  [ "$(rcall "$1" "$_p" toolu_rctl_a 2)" = deny ] || { printf 'FAIL:the call in M1 was not refused\n'; return; }
  [ "$(owv "$_p" denies)" = 1 ] || { printf 'FAIL:one refused message counted %s\n' "$(owv "$_p" denies)"; return; }
  [ "$(rcall "$1" "$_p" toolu_rctl_b 2)" = deny ] || { printf 'FAIL:the call in a second message M2 was not refused\n'; return; }
  [ "$(owv "$_p" denies)" = 2 ] || { printf 'FAIL:a second message counted to %s, not 2\n' "$(owv "$_p" denies)"; return; }
  printf 'PASS\n'
}
# R2. THE DISCRIMINATING WORLD: THE HOOK IS STILL PENDING WHEN ITS OWN MESSAGE'S LINE LANDS, AND IT
# MUST DENY. This is a367e62c's calls 18 and 19, each refused by a hook still waiting at the flush
# around 05:57:24, while calls 1-17 had already given up. The call's line is absent when the hook
# starts, and it lands on the gate's 22nd wait tick: past every tick a 10s net can take (8 quarter
# ticks then 1s ticks, 16 in all) and inside RECOVER_GATE_NET=30 (36 ticks).
# THE LATE WRITER IS THE GATE'S OWN CLOCK, NEVER A RACING SLEEP (BL-868). The gate's wait loop calls a
# bare `sleep` (the seam a_nogrant uses), so a per-predicate shim first on PATH counts each tick,
# returns at once, and on tick R7_LATE_TICK appends the call's line. Which tick the line lands on is
# therefore fixed, whatever the load: a writer racing the hook on wall time read a loaded pool as a
# gate that gave up. A gate that judges once at its start, or whose net is 10s, never reaches that
# tick and lets the call through uncounted.
R7_LATE_TICK=22
# r7_shim <project> <tick> <line file> -> a shim dir whose `sleep` appends <line file> to the
# project's transcript on call <tick>, in ONE write; every call is counted in <project>/ticks.
r7_shim() {
  _sd="$(mktemp -d "$WORK/r7shim.XXXXXX")"; : > "$1/ticks"
  printf '#!/bin/bash\necho x >> "%s"\nn=0; while read -r _; do n=$((n + 1)); done < "%s"\n[ "$n" -ne %s ] || cat "%s" >> "%s"\nexit 0\n' \
    "$1/ticks" "$1/ticks" "$2" "$3" "$1/t.jsonl" > "$_sd/sleep"
  chmod +x "$_sd/sleep"; printf '%s\n' "$_sd"
}
r7_ticks() { _tn=0; while read -r _; do _tn=$((_tn + 1)); done < "$1/ticks"; printf '%s\n' "$_tn"; }
a_rflush() {
  _p="$(a_world "$1" grant boundary digest)"
  [ -e "$_p/$OW" ] || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: the advisor stage did not arm\n'; return; }
  mline M-late toolu_rflush_late > "$_p/late.line"
  _sd="$(r7_shim "$_p" "$R7_LATE_TICK" "$_p/late.line")"
  d="$(PATH="$_sd:$PATH" rcall "$1" "$_p" toolu_rflush_late 30)"
  _tk="$(r7_ticks "$_p")"
  # A gate that never reached the tick never saw the line; it lands now, so every later check reads
  # one transcript whichever gate ran, and the verdict below is the one the gate gave without it.
  grep -qF toolu_rflush_late "$_p/t.jsonl" || cat "$_p/late.line" >> "$_p/t.jsonl"
  [ "$d" = deny ] || { printf 'FAIL:a call whose own line landed on wait tick %s while its hook still waited was let through (the hook waited %s tick(s))\n' "$R7_LATE_TICK" "$_tk"; return; }
  [ "$_tk" = "$R7_LATE_TICK" ] || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: the deny came after %s wait tick(s), not on tick %s, where the line landed\n' "$_tk" "$R7_LATE_TICK"; return; }
  [ "$(owv "$_p" denies)" = 1 ] || { printf 'FAIL:the late-flush refusal counted %s, not 1\n' "$(owv "$_p" denies)"; return; }
  printf 'PASS\n'
}
# R2c. CONTROL: the line never lands, RECOVER_GATE_NET=2. Silent, uncounted, file kept with a
# stderr reason (A10's shape at the short knob); a SECOND expiry in the recovery deletes the file,
# which is what bounds the stall at 2 x R_NET.
a_rflush_ctl() {
  _p="$(a_world "$1" grant boundary digest)"
  [ -e "$_p/$OW" ] || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: the advisor stage did not arm\n'; return; }
  _d0="$(owv "$_p" denies)"
  [ "$(rcall "$1" "$_p" toolu_rfctl_never 2 "$_p/ctl.err")" = deny ] && { printf 'FAIL:an unseen call was denied at the net\n'; return; }
  grep -q 'did not land within the' "$_p/ctl.err" || { printf 'FAIL:the stand-down gave no stderr reason\n'; return; }
  [ -e "$_p/$OW" ] || { printf 'FAIL:the first expiry removed the owed file\n'; return; }
  [ "$(owv "$_p" denies)" = "$_d0" ] || { printf 'FAIL:the expiry counted a refusal\n'; return; }
  [ "$(rcall "$1" "$_p" toolu_rfctl_never2 2)" = deny ] && { printf 'FAIL:a second unseen call was denied at the net\n'; return; }
  [ -e "$_p/$OW" ] && { printf 'FAIL:a second expiry in the recovery kept the owed file, so the stall is unbounded\n'; return; }
  printf 'PASS\n'
}

# R3. A GRANT WITHDRAWN DURING THE WAIT: the call's own line lands on the gate's 2nd wait tick, in
# the same write as an `advisor_tool` attachment carrying available:false, toolChange:"remove" (the
# r7_shim clock, as R2). The hook must allow and the owed file must be gone; a gate that tests the
# grant only before the wait denies.
a_rwithdraw() {
  _p="$(a_world "$1" grant boundary digest)"
  [ -e "$_p/$OW" ] || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: the advisor stage did not arm\n'; return; }
  { mline M-wd toolu_rwd_late; printf '{"type":"attachment","attachment":{"type":"advisor_tool","available":false,"toolChange":"remove"}}\n'; } > "$_p/wd.lines"
  _sd="$(r7_shim "$_p" 2 "$_p/wd.lines")"
  d="$(PATH="$_sd:$PATH" rcall "$1" "$_p" toolu_rwd_late 30)"
  grep -qF toolu_rwd_late "$_p/t.jsonl" || cat "$_p/wd.lines" >> "$_p/t.jsonl"
  [ "$d" = deny ] && { printf 'FAIL:a call whose grant was withdrawn during the wait was denied\n'; return; }
  [ -e "$_p/$OW" ] && { printf 'FAIL:the withdrawn grant left the owed file in place\n'; return; }
  [ "$(r7_ticks "$_p")" = 2 ] || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: the allow came after %s wait tick(s), not on tick 2, where the withdrawal landed\n' "$(r7_ticks "$_p")"; return; }
  printf 'PASS\n'
}

R7PREDS="rmsg rmsg_ctl rflush rflush_ctl rwithdraw"
r7_launch() { # r7_launch <gate> <outdir> -- each predicate in the background, pids recorded
  a_tpl "$1"; mkdir -p "$2"; : > "$2/pids"
  for _n in $R7PREDS; do
    ( r="$("a_$_n" "$1")"; printf '%s\n' "$r" > "$2/$_n" ) &
    printf '%s\n' "$!" >> "$2/pids"
  done
}
r7_wait() { while read -r _wp; do wait "$_wp"; done < "$1/pids"; } # r7_wait <outdir>

r7_launch "$GATE" "$WORK/r7-gate"
r7_wait "$WORK/r7-gate"

for _n in $R7PREDS; do
  r="$(cat "$WORK/r7-gate/$_n" 2>/dev/null)"
  case "$_n" in
    rmsg)       label="R (BL-730): two calls of one message are both refused and the message counts once (a_rmsg)" ;;
    rmsg_ctl)   label="R (BL-730): CONTROL -- a second message counts again, 1 then 2 (a_rmsg_ctl)" ;;
    rflush)     label="R (BL-730): a hook still pending when its own line lands on wait tick 22 DENIES, counted once (a_rflush)" ;;
    rwithdraw)  label="R (BL-730): a grant withdrawn during the wait allows the call and removes the owed file (a_rwithdraw)" ;;
    rflush_ctl) label="R (BL-730): CONTROL -- a line that never lands is silent and uncounted, and a second expiry stands the stage down (a_rflush_ctl)" ;;
  esac
  if [ "$r" = PASS ]; then ok "$label"; else bad "$label — ${r#FAIL:}"; fi
done

# R4. THE NO-WALL SEAM (BL-868). rcall and a_net set AI_DLC_TEST_RECOVER_GATE_NO_WALL=1, which drops
# the wait loop's SECONDS clause, so a loaded box cannot end the wait before the tick the r7_shim
# writer lands on. Unset (every consumer), the clause stays. Both cells drive an INJECTED CLOCK: a
# shell function `sleep` (functions win over PATH, and the sourced gate inherits it) counts the tick
# and advances SECONDS by 100, so no wall time passes and none decides (a stall before the first
# loop test would need 10 real seconds to move a cell). RECOVER_GATE_NET=10, the line never lands:
# unset, the SECONDS clause ends the wait after exactly 1 tick; set, only the slept bound ends it,
# after exactly 16 (8 quarter ticks, then 8 one-second ticks). Both cells are judged before the
# verdict, so both are read whole.
a_nowall_run() { # a_nowall_run <gate> <project> <seam value|''> -> tick count
  _nwt="$2/nwticks"; : > "$_nwt"
  ( sleep() { echo x >> "$_nwt"; SECONDS=$((SECONDS + 100)); }
    printf '{"tool_name":"Agent","session_id":"sess-A","transcript_path":"%s","tool_use_id":"toolu_nowall_never","tool_input":{}}' "$2/t.jsonl" \
      | if [ -n "$3" ]; then AI_DLC_TEST_RECOVER_GATE_NO_WALL="$3" RECOVER_GATE_NET=10 hook_run "$1" "$2"; else RECOVER_GATE_NET=10 hook_run "$1" "$2"; fi ) >/dev/null 2>&1
  r7_ticks_f "$2/nwticks"
}
r7_ticks_f() { _tn=0; while read -r _; do _tn=$((_tn + 1)); done < "$1"; printf '%s\n' "$_tn"; }
a_nowall() { # a_nowall <gate> -> PASS | FAIL:<flipped cells>:<why>
  _p="$(a_world "$1" grant boundary digest)"
  [ -e "$_p/$OW" ] || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: the advisor stage did not arm\n'; return; }
  _u="$(a_nowall_run "$1" "$_p" '')"
  _q="$(a_world "$1" grant boundary digest)"
  _s="$(a_nowall_run "$1" "$_q" 1)"
  _nf=""; _nwhy=""
  [ "$_u" = 1 ] || { _nf="unset"; _nwhy="with the seam unset the wall clause did not end the wait after 1 tick ($_u ticks), so a consumer gate is no longer bounded by SECONDS"; }
  [ "$_s" = 16 ] || { _nf="${_nf:+$_nf+}set"; _nwhy="${_nwhy:+$_nwhy; }with the seam set the wait ran $_s tick(s), not the 16 the slept bound allows, so the SECONDS clause still decides"; }
  if [ -n "$_nf" ]; then printf 'FAIL:%s:%s\n' "$_nf" "$_nwhy"; else printf 'PASS\n'; fi
}
r_nw="$(a_nowall "$GATE")"
if [ "$r_nw" = PASS ]; then ok "R (BL-868): the no-wall seam drops only the SECONDS clause; unset it still bounds the wait (a_nowall)"
else bad "R (BL-868): the no-wall seam — ${r_nw#FAIL:}"; fi

# =============================================================================
# THE SAME-MESSAGE RACE AT THE READ STAGES (BL-658)
#
# Measured on the reference consumer: a lead issued the snapshot Read, the step Read and the digest
# Read together as parallel calls, both mandated Reads succeeded, and the digest Read was DENIED with the
# stage-one text. Three invocations of the gate ran side by side. The third passed the marker
# fast-path while recovery was owed; the second then satisfied the mandate and removed the marker
# and the progress file; the third read no progress file, took the default stage, and refused.
#
# THE RACE IS FORCED, NEVER TIMED. A timed race passes on a quiet box and proves nothing. Each
# variant is a copy of the WHOLE hooks directory whose gate carries one injected line doing what
# the concurrent satisfying call does -- removing both files -- plus a sentinel write, at a fixed
# point between the fast-path and the stage read. The world is armed by the real producer and
# advanced to stage two by the REAL gate, so the variant judges only the third call.
#
# OUTSIDE PREDS ON PURPOSE: the race arms drive their own injected copies of the gate.
#
# FOUR SHAPES. R1 the injected shipped gate ALLOWS. R2 the genuine first call (marker, no progress)
# is DENIED with the stage-one text -- the call a fix keyed on the progress file waves through.
# R3 the injected line RAN: sentinel present, both files gone. And an uninjected copy of the same
# world is denied with the stage-TWO text, so the allow in R1 belongs to the injection and the
# re-test and not to a copy that went inert.
# =============================================================================
RACE_FABS='[ -n "$FPATH" ] && FABS="$(resolve "$FPATH")"'
RACE_STAGE='STAGE="$(cat "$PROGRESS" 2>/dev/null || printf '"'"'snapshot'"'"')"'
RACE_RETEST='[ -f "$MARKER" ] || exit 0'
RACE_LINE='rm -f "$MARKER" "$PROGRESS" 2>/dev/null; : > "${STATE_DIR}/.race-injected"'
RACE_SENT="_bmad-output/.race-injected"
# What directly follows the stage read: yes (the re-test), no, or none (no stage read at all).
RACE_AT='prev == ENVIRON["S"] { print (($0 == ENVIRON["R"]) ? "yes" : "no"); f = 1; exit } { prev = $0 } END { if (!f) print "none" }'
# The two lines directly above the stage read, joined by a bar.
RACE_AFTER='{ print } $0 == ENVIRON["A"] { print ENVIRON["L"] }'

_race_at="$(S="$RACE_STAGE" R="$RACE_RETEST" awk "$RACE_AT" "$GATE")"
if [ "$_race_at" != yes ]; then
  skip "race arms" "the gate does not re-test the marker directly after its stage read (found: ${_race_at}); this fixture ships one pull ahead of its subject"
else

race_dir() { # race_dir -> a fresh copy of the WHOLE hooks directory, or nothing when a sibling did not arrive
  _rd="$(mktemp -d "$WORK/race.XXXXXX")" || return 0
  _rs="$(dirname "$GATE")"
  cp "$_rs"/*.sh "$_rd"/ 2>/dev/null
  [ "$(ls "$_rs"/*.sh | wc -l)" -eq "$(ls "$_rd"/*.sh | wc -l)" ] || return 0
  [ -f "$_rd/ai-dlc-recover-gate.sh" ] || return 0
  printf '%s\n' "$_rd"
}
# race_edit <src> <out> <awk program> <anchor> <line> [W] -- refused unless the anchor is ONE whole
# line, the output differs and it parses. The caller checks the shape it wanted.
race_edit() {
  [ "$(grep -cxF -- "$4" "$1")" -eq 1 ] || return 1
  A="$4" L="$5" W="${6:-}" awk "$3" "$1" > "$2" || return 1
  cmp -s "$1" "$2" && return 1
  bash -n "$2" 2>/dev/null
}
# race_world <gate> -> project; the third Read's answer is in <project>/race.d
race_world() {
  _p="$(armed_proj "$HOOK" architecture.md flat)"
  gate_call "$GATE" "$_p" "$(jcall Read "$_p/_bmad-output/pipeline-snapshot.md")" >/dev/null
  if [ "$(cat "$_p/$pg" 2>/dev/null)" = step ] && [ -e "$_p/$mk" ]; then
    gate_call "$1" "$_p" "$(jcall Read "$_p/decoy.md")" > "$_p/race.d"
  else
    printf 'SEED\n' > "$_p/race.d"
  fi
  printf '%s\n' "$_p"
}
# race_first <gate> -> project; the genuine first call (marker present, no progress file yet)
race_first() {
  _p="$(armed_proj "$HOOK" architecture.md flat)"
  if [ -e "$_p/$mk" ] && [ ! -e "$_p/$pg" ]; then
    gate_call "$1" "$_p" "$(jcall Read "$_p/decoy.md")" > "$_p/race.d"
  else
    printf 'SEED\n' > "$_p/race.d"
  fi
  printf '%s\n' "$_p"
}
race_read() { # race_read <project> -> seed | allow | first | second | other
  _d="$(cat "$1/race.d" 2>/dev/null)"
  case "$_d" in
    (SEED|'') printf 'seed\n' ;;
    ('|'*) printf 'allow\n' ;;
    (*'FIRST tool call must be'*) printf 'first\n' ;;
    (*'SECOND tool call must be'*) printf 'second\n' ;;
    (*) printf 'other\n' ;;
  esac
}
race_ran() { [ -e "$1/$RACE_SENT" ] && [ ! -e "$1/$mk" ] && [ ! -e "$1/$pg" ]; }

RG=ai-dlc-recover-gate.sh
RD_IN="$(race_dir)"; RD_CTL="$(race_dir)"
if [ -z "$RD_IN" ] || [ -z "$RD_CTL" ]; then
  bad "FIXTURE BROKEN: a whole-directory copy of the hooks did not carry every sibling, so no race variant below is evidence"
else
  # The shipped gate, the removal injected directly after the call-path normalisation.
  race_edit "$GATE" "$RD_IN/$RG" "$RACE_AFTER" "$RACE_FABS" "$RACE_LINE" \
    && [ "$(S="$RACE_STAGE" R="$RACE_RETEST" awk "$RACE_AT" "$RD_IN/$RG")" = yes ] || RD_IN=""
  cmp -s "$GATE" "$RD_CTL/$RG" || RD_CTL=""

  # R1 and R3, one world.
  if [ -z "$RD_IN" ]; then
    bad "FIXTURE STALE: R1 — the removal could not be injected after the call-path normalisation, so the race has no forcing point"
  else
    _rp="$(race_world "$RD_IN/$RG")"; _rv="$(race_read "$_rp")"
    if race_ran "$_rp"; then ok "race R3: the injected removal ran — sentinel written, marker and progress file gone"
    else bad "race R3: the injected removal did not run, so R1 measures the ordinary stage-two world (answer: ${_rv})"; fi
    if [ "$_rv" = allow ]; then ok "race R1: the satisfying call removed both files mid-call, and the third Read is ALLOWED"
    else bad "race R1: the satisfying call removed both files mid-call, and the third Read got '${_rv}' instead of an allow"; fi
  fi
  # The uninjected copy: the same world is refused at stage TWO, so the copy is live.
  if [ -z "$RD_CTL" ]; then
    bad "FIXTURE BROKEN: the uninjected race copy differs from the gate"
  else
    _rp="$(race_world "$RD_CTL/$RG")"; _rv="$(race_read "$_rp")"
    if [ "$_rv" = second ] && [ ! -e "$_rp/$RACE_SENT" ]; then ok "race control: an uninjected copy refuses the same third Read with the stage-two text"
    else bad "race control: an uninjected copy answered '${_rv}' where the stage-two deny was expected, so the race variants are not evidence"; fi
  fi
  # R2, against the shipped gate.
  _rv="$(race_read "$(race_first "$GATE")")"
  if [ "$_rv" = first ]; then ok "race R2: the genuine first call (marker present, no progress file) is DENIED with the stage-one text"
  else bad "race R2: the genuine first call answered '${_rv}' where the stage-one deny was expected"; fi


  # THE REMOVAL ORDER (BL-658). The fix holds only because the satisfying Read removes the MARKER
  # before the PROGRESS file: a concurrent call that sees the marker gone exits at the re-test, one
  # that sees the progress file gone but the marker present would take the default stage. Every
  # injection above supplies its OWN removal, so nothing above binds the shipped line's operand
  # order. This arm reads the line itself, whole-line and exact, with the swapped spelling and an
  # impossible anchor as its controls.
  RACE_RM='        rm -f "$MARKER" "$PROGRESS" 2>/dev/null || true'
  RACE_RMSW='        rm -f "$PROGRESS" "$MARKER" 2>/dev/null || true'
  RACE_RMNONE='        rm -f "$MARKER" "$PROGRESS" 2>/dev/null || true # impossible-anchor-bl658-zz'
  race_rm_order() { printf '%s|%s\n' "$(grep -cxF -- "$RACE_RM" "$1")" "$(grep -cxF -- "$RACE_RMSW" "$1")"; }
  _ro="$(race_rm_order "$GATE")"; _rc="$(grep -cxF -- "$RACE_RMNONE" "$GATE")"
  if [ "$_ro" = "1|0" ] && [ "$_rc" = 0 ]; then
    ok "race order: the satisfying Read removes the marker BEFORE the progress file (exact line 1, swapped spelling 0, impossible-anchor control 0)"
  else bad "race order: expected exact line 1 and swapped spelling 0 with control 0, measured ${_ro} with control '${_rc}' in ${GATE}"; fi
fi

  # ===========================================================================
  # THE DIGEST ALLOW (BL-658), THE RENAMED STAGE WRITE (BL-666), THE STALE-STAGE CLEAR (BL-684)
  #
  # BL-658, cases (ii) and (iii). The lead issues the snapshot, step and digest Reads in parallel.
  # The digest call can land at stage `step` (SECOND-call deny) or before the snapshot call wrote
  # any stage (FIRST-call deny), and both refuse a Read the injected block itself asks for. The
  # fix allows a FULL Read of the digest path, in both stage arms, WITHOUT advancing anything.
  #
  # BL-666. The stage write truncated `$PROGRESS` in place, so a concurrent reader could see an
  # empty stage, fall to the garbage arm and delete it, resetting the recovery. The fix writes a
  # sibling temp named with `$$` and renames it over the stage. The hard-link probe forces the
  # question deterministically: an in-place write rewrites the linked inode, a rename does not.
  # NO BEHAVIOURAL ARM SEES A CROSS-FILESYSTEM TEMP FILE -- a temp project cannot put the temp on
  # another device -- so the structural arm checks the temp is spelled from `${PROGRESS}`.
  #
  # BL-684. A new recovery cleared the satisfaction breadcrumb and the advisor window but not the
  # stage, so a stale `step` skipped the next recovery's snapshot mandate.
  #
  # SHIP-AHEAD. Each block detects its own fix by a stable spelling and calls `skip` with that key
  # when it is absent. Every arm here runs against the real hooks directory.
  # ===========================================================================
  RC_DIGREL=".claude/skills/ai-dlc/postcompact-digest.md"
  RC_DIGKEY='"$FABS" = "${PROJECT_DIR}/.claude/skills/ai-dlc/postcompact-digest.md"'
  RC_SWKEY="printf 'step\\n' >\""
  RC_RENKEY='mv -f "${PROGRESS}.$$" "$PROGRESS"'
  RC_CLRRE='^[[:space:]]*rm -f .*\.recover-gate-progress'
  RC_REAL="$(dirname "$GATE")"
  RC_RH=ai-dlc-recover.sh

  rc_dec() { case "$1" in ('|'*) echo allow ;; (*'FIRST tool call must be'*) echo first ;; (*'SECOND tool call must be'*) echo second ;; (*) echo other ;; esac; }
  rc_call() { rc_dec "$(gate_call "$1/$RG" "$2" "$3")"; } # rc_call <hooks-dir> <project> <json> -> allow|first|second|other
  # rc_proj <hooks-dir> <first|step> -> a project armed by that directory's own producer, at the
  # named stage, carrying the digest and a same-basename decoy; empty when the world did not form.
  rc_proj() {
    _rq="$(armed_proj "$1/$RC_RH" architecture.md flat rc)"
    { [ -e "$_rq/$mk" ] && [ ! -e "$_rq/$pg" ]; } || return 0
    if [ "$2" = step ]; then
      gate_call "$1/$RG" "$_rq" "$(jcall Read "$_rq/_bmad-output/pipeline-snapshot.md")" >/dev/null
      { [ "$(cat "$_rq/$pg" 2>/dev/null)" = step ] && [ -e "$_rq/$mk" ]; } || return 0
    fi
    printf '%s\n' "$_rq"
  }
  rc_post() { # rc_post <project> <step|none> -> empty when nothing moved, else what did
    _rm=""
    [ -e "$1/$mk" ] || _rm="$_rm marker-cleared"
    if [ "$2" = none ]; then [ -e "$1/$pg" ] && _rm="$_rm stage-written"
    else [ "$(cat "$1/$pg" 2>/dev/null)" = "$2" ] || _rm="$_rm stage-moved"; fi
    [ -e "$1/_bmad-output/.recover-satisfied" ] && _rm="$_rm recover-satisfied-written"
    [ -e "$1/_bmad-output/.recover-advisor-owed" ] && _rm="$_rm recover-advisor-owed-written"
    printf '%s' "${_rm# }"
  }

  # --- the predicates, each PASS or FAIL:<what it saw> ------------------------
  rp_d_step() { # (a) a full digest Read at stage step is allowed and advances nothing
    _rq="$(rc_proj "$1" step)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-two world formed'; return; }
    _rv="$(rc_call "$1" "$_rq" "$(jcall Read "$_rq/$RC_DIGREL")")"
    [ "$_rv" = allow ] || { echo "FAIL:a full digest Read at stage step answered '${_rv}'"; return; }
    _rm="$(rc_post "$_rq" step)"; [ -z "$_rm" ] || { echo "FAIL:the digest allow at stage step moved state: ${_rm}"; return; }
    echo PASS
  }
  rp_d_first() { # (b) case iii: marker present, no stage file, a full digest Read is allowed and advances nothing
    _rq="$(rc_proj "$1" first)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-one world formed'; return; }
    _rv="$(rc_call "$1" "$_rq" "$(jcall Read "$_rq/$RC_DIGREL")")"
    [ "$_rv" = allow ] || { echo "FAIL:a full digest Read with no stage file answered '${_rv}'"; return; }
    _rm="$(rc_post "$_rq" none)"; [ -z "$_rm" ] || { echo "FAIL:the digest allow with no stage file moved state: ${_rm}"; return; }
    echo PASS
  }
  rp_d_decoy() { # control: any other Read at stage step still gets the SECOND deny
    _rq="$(rc_proj "$1" step)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-two world formed'; return; }
    _rv="$(rc_call "$1" "$_rq" "$(jcall Read "$_rq/decoy.md")")"
    [ "$_rv" = second ] || { echo "FAIL:a decoy Read at stage step answered '${_rv}', not the SECOND deny"; return; }
    echo PASS
  }
  rp_d_base() { # control: x/postcompact-digest.md shares the basename and is denied at both stages
    _rq="$(rc_proj "$1" first)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-one world formed'; return; }
    _rv="$(rc_call "$1" "$_rq" "$(jcall Read "$_rq/x/postcompact-digest.md")")"
    [ "$_rv" = first ] || { echo "FAIL:the same-basename decoy at stage one answered '${_rv}'"; return; }
    _rq="$(rc_proj "$1" step)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-two world formed'; return; }
    _rv="$(rc_call "$1" "$_rq" "$(jcall Read "$_rq/x/postcompact-digest.md")")"
    [ "$_rv" = second ] || { echo "FAIL:the same-basename decoy at stage step answered '${_rv}'"; return; }
    echo PASS
  }
  rp_d_bounded() { # control: a BOUNDED digest Read (limit=1) is denied at both stages
    _rq="$(rc_proj "$1" first)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-one world formed'; return; }
    _rv="$(rc_call "$1" "$_rq" "$(jbounded "$_rq/$RC_DIGREL" 1 -)")"
    [ "$_rv" = first ] || { echo "FAIL:a limit=1 digest Read at stage one answered '${_rv}'"; return; }
    _rq="$(rc_proj "$1" step)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-two world formed'; return; }
    _rv="$(rc_call "$1" "$_rq" "$(jbounded "$_rq/$RC_DIGREL" 1 -)")"
    [ "$_rv" = second ] || { echo "FAIL:a limit=1 digest Read at stage step answered '${_rv}'"; return; }
    echo PASS
  }
  rp_s_inode() { # the snapshot Read replaces the stage inode: a hard link to it still reads snapshot
    _rq="$(rc_proj "$1" first)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-one world formed'; return; }
    printf 'snapshot\n' > "$_rq/$pg"
    ln "$_rq/$pg" "$_rq/rc.link" 2>/dev/null || { echo 'FAIL:SEED — the hard link could not be made'; return; }
    _rv="$(rc_call "$1" "$_rq" "$(jcall Read "$_rq/_bmad-output/pipeline-snapshot.md")")"
    [ "$_rv" = allow ] || { echo "FAIL:the full snapshot Read answered '${_rv}'"; return; }
    [ "$(cat "$_rq/$pg" 2>/dev/null)" = step ] || { echo "FAIL:the stage reads '$(cat "$_rq/$pg" 2>/dev/null)', not step"; return; }
    [ "$_rq/$pg" -ef "$_rq/rc.link" ] && { echo 'FAIL:the stage is still the linked inode, so it was written in place'; return; }
    [ "$(cat "$_rq/rc.link" 2>/dev/null)" = snapshot ] || { echo "FAIL:the linked old inode reads '$(cat "$_rq/rc.link" 2>/dev/null)', so it was rewritten"; return; }
    echo PASS
  }
  # A write killed by the file-size limit must leave the old stage whole. This arm alone cannot
  # tell a gate that never reached the write from one that wrote safely; rp_s_inode is the
  # presence-shaped half, and the two together are the stage-write guard.
  rp_s_ulimit() {
    _rq="$(rc_proj "$1" first)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-one world formed'; return; }
    printf 'snapshot\n' > "$_rq/$pg"
    _rj="$(jcall Read "$_rq/_bmad-output/pipeline-snapshot.md")"
    ( ulimit -f 0; gate_call "$1/$RG" "$_rq" "$_rj" >/dev/null ) 2>/dev/null
    [ "$(cat "$_rq/$pg" 2>/dev/null)" = snapshot ] || { echo "FAIL:a stage write cut off by ulimit left the stage reading '$(cat "$_rq/$pg" 2>/dev/null)'"; return; }
    echo PASS
  }
  rp_s_garbage() { # control: a garbage stage is allowed through and the file removed
    _rq="$(rc_proj "$1" first)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-one world formed'; return; }
    printf 'garbage\n' > "$_rq/$pg"
    _rv="$(rc_call "$1" "$_rq" "$(jcall Read "$_rq/_bmad-output/pipeline-snapshot.md")")"
    [ "$_rv" = allow ] || { echo "FAIL:a garbage stage answered '${_rv}'"; return; }
    [ -e "$_rq/$pg" ] && { echo 'FAIL:a garbage stage was not removed'; return; }
    echo PASS
  }
  rp_s_struct() { # the one stage write names a temp spelled from ${PROGRESS} with $$, renamed onto $PROGRESS
    _rn="$(grep -cF -- "$RC_SWKEY" "$1/$RG")" || _rn=0
    [ "$_rn" = 1 ] || { echo "FAIL:${_rn} stage-write lines, where one was expected"; return; }
    _rl="$(grep -F -- "$RC_SWKEY" "$1/$RG")"
    _rt="${_rl#*"$RC_SWKEY"}"; _rt="${_rt%%\"*}"
    case "$_rt" in ('${PROGRESS}'?*'$$'*) ;; (*) echo "FAIL:the stage write targets '${_rt}', not a temp spelled from \${PROGRESS} carrying \$\$"; return ;; esac
    case "$_rl" in (*"mv -f \"${_rt}\" \"\$PROGRESS\""*) ;; (*) echo "FAIL:the temp '${_rt}' is never renamed onto \$PROGRESS on the stage-write line"; return ;; esac
    echo PASS
  }
  # The probe Read is the decoy, not the step file: a full step Read with no stage is ALLOWED
  # since BL-687, so it no longer tells a cleared stage (FIRST) from a stale one (SECOND); the
  # decoy is denied at either stage and still does.
  rp_r_clear() { # a new recovery clears the previous stage and its temps; a decoy Read then gets FIRST
    _rq="$(rc_proj "$1" step)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-two world formed'; return; }
    : > "$_rq/$pg.4242"
    arm_marker "$1/$RC_RH" "$_rq"
    [ -e "$_rq/$mk" ] || { echo 'FAIL:SEED — the new recovery wrote no marker'; return; }
    [ -e "$_rq/$pg" ] && { echo "FAIL:a new recovery left the previous stage '$(cat "$_rq/$pg" 2>/dev/null)' on disk"; return; }
    [ -e "$_rq/$pg.4242" ] && { echo 'FAIL:a new recovery left a stage temp file on disk'; return; }
    _rv="$(rc_call "$1" "$_rq" "$(jcall Read "$_rq/decoy.md")")"
    [ "$_rv" = first ] || { echo "FAIL:a decoy Read after a new recovery answered '${_rv}', not the FIRST deny"; return; }
    echo PASS
  }
  rp_r_owed() { # a new recovery clears an owed-file temp left by an interrupted owed_put
    _rq="$(rc_proj "$1" step)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-two world formed'; return; }
    : > "$_rq/${pg%/*}/.recover-advisor-owed.4242"
    [ -e "$_rq/${pg%/*}/.recover-advisor-owed.4242" ] || { echo 'FAIL:SEED — the owed temp was not seeded'; return; }
    arm_marker "$1/$RC_RH" "$_rq"
    [ -e "$_rq/$mk" ] || { echo 'FAIL:SEED — the new recovery wrote no marker'; return; }
    [ -e "$_rq/${pg%/*}/.recover-advisor-owed.4242" ] && { echo 'FAIL:a new recovery left an owed-file temp on disk'; return; }
    echo PASS
  }
  rp_r_ctl() { # control: on a fresh recovery the same decoy Read gets FIRST
    _rq="$(rc_proj "$1" first)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-one world formed'; return; }
    _rv="$(rc_call "$1" "$_rq" "$(jcall Read "$_rq/decoy.md")")"
    [ "$_rv" = first ] || { echo "FAIL:a decoy Read on a fresh recovery answered '${_rv}'"; return; }
    echo PASS
  }
  rc_label() {
    case "$1" in
      d_step)    echo "BL-658 (a): a full digest Read at stage step is ALLOWED; marker kept, stage still step, no .recover-satisfied, no .recover-advisor-owed" ;;
      d_first)   echo "BL-658 (b): a full digest Read with the marker present and no stage file (case iii) is ALLOWED; marker kept, no stage written, no .recover-satisfied, no .recover-advisor-owed" ;;
      d_decoy)   echo "BL-658 control: a decoy Read at stage step still gets the SECOND deny" ;;
      d_base)    echo "BL-658 control: a same-basename decoy x/postcompact-digest.md is denied at both stages" ;;
      d_bounded) echo "BL-658 control: a bounded digest Read (limit=1) is denied at both stages" ;;
      s_inode)   echo "BL-666: a full snapshot Read replaces the stage inode — the hard link still reads snapshot, the stage reads step" ;;
      s_ulimit)  echo "BL-666: a stage write cut off by ulimit -f 0 leaves the stage reading snapshot" ;;
      s_garbage) echo "BL-666 control: a garbage stage is allowed through and the file removed" ;;
      s_struct)  echo "BL-666 structural: the stage write's temp is spelled from \${PROGRESS}, carries \$\$, and is renamed onto \$PROGRESS" ;;
      r_clear)   echo "BL-684: a new recovery clears the previous stage and its temp, and a first-call decoy Read gets the FIRST deny" ;;
      r_owed)    echo "BL-730: a new recovery clears an owed-file temp (.recover-advisor-owed.<pid>) left by an interrupted write" ;;
      r_ctl)     echo "BL-684 control: on a fresh recovery the same decoy Read gets the FIRST deny" ;;
    esac
  }
  rc_arms() { for _ra in $1; do _rr="$("rp_$_ra" "$RC_REAL")"; if [ "$_rr" = PASS ]; then ok "$(rc_label "$_ra")"; else bad "$(rc_label "$_ra") — ${_rr#FAIL:}"; fi; done; }

  # --- BL-658: the digest allow -------------------------------------------------
  # Detection key: a line carrying RC_DIGKEY, the FABS comparison against the installed digest path.
  _rk="$(grep -cF -- "$RC_DIGKEY" "$GATE")" || _rk=0
  if [ "$_rk" -lt 1 ]; then
    skip "BL-658 digest-allow arms" "the gate carries no full-Read allow comparing FABS to the digest path (key '${RC_DIGKEY}', found 0); this fixture ships one pull ahead of its subject"
  else
    RC_P658="d_step d_first d_decoy d_base d_bounded"
    rc_arms "$RC_P658"
  fi

  # --- BL-666: the renamed stage write -----------------------------------------
  # Detection key: RC_RENKEY, the rename of the $$ temp onto $PROGRESS.
  _rk="$(grep -cF -- "$RC_RENKEY" "$GATE")" || _rk=0
  if [ "$_rk" -lt 1 ]; then
    skip "BL-666 renamed-stage-write arms" "the gate does not rename a temp onto the stage (key '${RC_RENKEY}', found 0); this fixture ships one pull ahead of its subject"
  else
    RC_P666="s_inode s_ulimit s_garbage s_struct"
    rc_arms "$RC_P666"
  fi

  # --- BL-684: a new recovery clears the stale stage ---------------------------
  # Detection key: RC_CLRRE, an `rm -f` line in the producer naming .recover-gate-progress.
  _rk="$(grep -cE -- "$RC_CLRRE" "$RC_REAL/$RC_RH")" || _rk=0
  if [ "$_rk" -lt 1 ]; then
    skip "BL-684 stale-stage-clear arms" "ai-dlc-recover.sh has no rm -f line naming .recover-gate-progress (key '${RC_CLRRE}', found 0); this fixture ships one pull ahead of its subject"
  else
    RC_P684="r_clear r_owed r_ctl"
    rc_arms "$RC_P684"
  fi

  # --- BL-688: an unwritable state directory stands the gate down ---------------
  # Every way out of a recovery is a write under _bmad-output, so with the directory unwritable
  # the snapshot Read advanced nothing and every later call was denied FIRST (wedge 1); made
  # unwritable after the stage reached `step`, every call was denied SECOND (wedge 2). Each 555
  # predicate is straight-line -- chmod 555, collect every decision, chmod 755, then judge -- so
  # no return path can leave the directory unwritable; the EXIT trap is the backstop.
  # Detection key: RC_WKEY, the per-call writability test in the gate.
  RC_WKEY='[ -w "$STATE_DIR" ]'
  _rk="$(grep -cF -- "$RC_WKEY" "$GATE")" || _rk=0
  _rpp="$(mktemp -d "$WORK/perm.XXXXXX")"; chmod 555 "$_rpp"
  if ( : > "$_rpp/w" ) 2>/dev/null; then _rpw=1; else _rpw=0; fi
  chmod 755 "$_rpp"
  if [ "$_rk" -lt 1 ]; then
    skip "BL-688 unwritable-state arms" "the gate carries no per-call writability test (key '${RC_WKEY}', found 0); this fixture ships one pull ahead of its subject"
  elif [ "$_rpw" = 1 ]; then
    skip "BL-688 unwritable-state arms" "a write into a 555 directory succeeded, so this run ignores permissions and no unwritable state can be built"
  else
    rp_w_snap() { # wedge 1: unwritable before the snapshot Read; the Edit after it is not denied, nothing moved
      _rq="$(rc_proj "$1" first)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-one world formed'; return; }
      chmod 555 "$_rq/_bmad-output"
      _rs="$(rc_call "$1" "$_rq" "$(jcall Read "$_rq/_bmad-output/pipeline-snapshot.md")")"
      _rv="$(rc_call "$1" "$_rq" "$(jcall Edit "$_rq/decoy.md")")"
      chmod 755 "$_rq/_bmad-output"
      [ "$_rs" = allow ] || { echo "FAIL:the full snapshot Read under an unwritable _bmad-output answered '${_rs}'"; return; }
      [ "$_rv" = allow ] || { echo "FAIL:an Edit after the snapshot Read under an unwritable _bmad-output answered '${_rv}'"; return; }
      _rm="$(rc_post "$_rq" none)"; [ -z "$_rm" ] || { echo "FAIL:the stand-down moved state: ${_rm}"; return; }
      echo PASS
    }
    rp_w_step() { # wedge 2: unwritable after the stage reached step; the step Read and the Edit after it are not denied
      _rq="$(rc_proj "$1" step)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-two world formed'; return; }
      chmod 555 "$_rq/_bmad-output"
      _rs="$(rc_call "$1" "$_rq" "$(jcall Read "$_rq/architecture.md")")"
      _rv="$(rc_call "$1" "$_rq" "$(jcall Edit "$_rq/decoy.md")")"
      chmod 755 "$_rq/_bmad-output"
      [ "$_rs" = allow ] || { echo "FAIL:the full step Read under an unwritable _bmad-output answered '${_rs}'"; return; }
      [ "$_rv" = allow ] || { echo "FAIL:an Edit after the step Read under an unwritable _bmad-output answered '${_rv}'"; return; }
      _rm="$(rc_post "$_rq" step)"; [ -z "$_rm" ] || { echo "FAIL:the stand-down moved state: ${_rm}"; return; }
      echo PASS
    }
    rp_w_ctl() { # control: writable, the same snapshot Read advances to step and the Edit gets SECOND
      _rq="$(rc_proj "$1" first)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-one world formed'; return; }
      _rs="$(rc_call "$1" "$_rq" "$(jcall Read "$_rq/_bmad-output/pipeline-snapshot.md")")"
      _rv="$(rc_call "$1" "$_rq" "$(jcall Edit "$_rq/decoy.md")")"
      [ "$_rs" = allow ] || { echo "FAIL:the full snapshot Read answered '${_rs}'"; return; }
      [ "$_rv" = second ] || { echo "FAIL:an Edit after the snapshot Read answered '${_rv}', not the SECOND deny"; return; }
      _rm="$(rc_post "$_rq" step)"; [ -z "$_rm" ] || { echo "FAIL:the writable sequence did not stop at step: ${_rm}"; return; }
      echo PASS
    }
    rc_wlabel() {
      case "$1" in
        w_snap) echo "BL-688 wedge 1: with _bmad-output unwritable, the snapshot Read is allowed and the Edit after it is NOT denied; marker kept, no stage written, nothing satisfied" ;;
        w_step) echo "BL-688 wedge 2: with _bmad-output made unwritable at stage step, the step Read and the Edit after it are NOT denied; marker kept, stage still step, nothing satisfied" ;;
        w_ctl)  echo "BL-688 control: writable, the same snapshot Read advances to step and the Edit gets the SECOND deny" ;;
      esac
    }
    RC_P688="w_snap w_step w_ctl"
    for _ra in $RC_P688; do _rr="$("rp_$_ra" "$RC_REAL")"; if [ "$_rr" = PASS ]; then ok "$(rc_wlabel "$_ra")"; else bad "$(rc_wlabel "$_ra") — ${_rr#FAIL:}"; fi; done
  fi

  # --- BL-725: a failed stage write stands the recovery down -------------------
  # A writable directory whose stage write FAILS (SIGXFSZ ignored so the write returns an error the
  # way ENOSPC does) must clear the marker: the snapshot Read is allowed and the call after it is
  # not denied. The control runs the same seed unlimited and keeps the marker (SECOND deny).
  # Detection key: "$MARKER" on the RC_SWKEY line, the unlink in the failure branch.
  _rk="$(grep -F -- "$RC_SWKEY" "$GATE" | grep -cF -- '"$MARKER"')" || _rk=0
  if [ "$_rk" -lt 1 ]; then
    skip "BL-725 failed-stage-write arms" "the stage-write line does not unlink the marker on failure (key '\"\$MARKER\"' on the RC_SWKEY line, found 0); this fixture ships one pull ahead of its subject"
  else
    rp_s_fail() { # stage one, write fails: Read allowed, marker gone, no temp left, the next Edit allowed
      _rq="$(rc_proj "$1" first)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-one world formed'; return; }
      _rj="$(jcall Read "$_rq/_bmad-output/pipeline-snapshot.md")"
      _rs="$( trap '' XFSZ; ulimit -f 0; gate_call "$1/$RG" "$_rq" "$_rj" 2>/dev/null )"
      _rs="$(rc_dec "$_rs")"
      [ "$_rs" = allow ] || { echo "FAIL:the full snapshot Read with a failing stage write answered '${_rs}'"; return; }
      [ -e "$_rq/$pg" ] && { echo "FAIL:the stage write was expected to fail and left '$(cat "$_rq/$pg" 2>/dev/null)'"; return; }
      [ -e "$_rq/$mk" ] && { echo 'FAIL:a failed stage write left the marker, so the recovery stays armed'; return; }
      _rt="$(ls "$_rq/_bmad-output" 2>/dev/null | grep -c 'recover-gate-progress')" || _rt=0
      [ "$_rt" = 0 ] || { echo "FAIL:a failed stage write left ${_rt} stage temp file(s) behind"; return; }
      _rv="$(rc_call "$1" "$_rq" "$(jcall Edit "$_rq/decoy.md")")"
      [ "$_rv" = allow ] || { echo "FAIL:an Edit after the failed stage write answered '${_rv}', not allow"; return; }
      echo PASS
    }
    rp_s_fail_ctl() { # control: the same seed without the limit advances to step, keeps the marker, and the Edit gets SECOND
      _rq="$(rc_proj "$1" first)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-one world formed'; return; }
      _rs="$(rc_call "$1" "$_rq" "$(jcall Read "$_rq/_bmad-output/pipeline-snapshot.md")")"
      [ "$_rs" = allow ] || { echo "FAIL:the unlimited full snapshot Read answered '${_rs}'"; return; }
      [ "$(cat "$_rq/$pg" 2>/dev/null)" = step ] || { echo "FAIL:the unlimited stage write left '$(cat "$_rq/$pg" 2>/dev/null)', not step"; return; }
      [ -e "$_rq/$mk" ] || { echo 'FAIL:a successful stage write cleared the marker'; return; }
      _rv="$(rc_call "$1" "$_rq" "$(jcall Edit "$_rq/decoy.md")")"
      [ "$_rv" = second ] || { echo "FAIL:an Edit after the successful stage write answered '${_rv}', not the SECOND deny"; return; }
      echo PASS
    }
    rc_l725() {
      case "$1" in
        s_fail)     echo "BL-725: a snapshot Read whose stage write fails is allowed, the marker is gone, no stage temp remains, and the Edit after it is NOT denied" ;;
        s_fail_ctl) echo "BL-725 control: the same seed without the limit writes step, keeps the marker, and the Edit gets the SECOND deny" ;;
      esac
    }
    RC_P725="s_fail s_fail_ctl"
    for _ra in $RC_P725; do _rr="$("rp_$_ra" "$RC_REAL")"; if [ "$_rr" = PASS ]; then ok "$(rc_l725 "$_ra")"; else bad "$(rc_l725 "$_ra") — ${_rr#FAIL:}"; fi; done
  fi

  # --- BL-687: a full step Read before the stage write is allowed, advancing nothing -------
  # A parallel step Read whose hook ran before the snapshot call's stage write was denied FIRST.
  # The allow must not open a step Read alone as a way to satisfy the recovery, a bounded step
  # Read, any other Read, or a compelled handoff.md Read (which would arm the handoff marker).
  # Detection key: RC_FLINE, the full-step-Read allow line in the snapshot arm.
  RC_FLINE='    if [ "$TOOL" = "Read" ] && [ -n "$FABS" ] && [ "$FABS" = "$STEP_ABS" ] && is_full_read; then'
  _rk="$(grep -cxF -- "$RC_FLINE" "$GATE")" || _rk=0
  if [ "$_rk" -lt 1 ]; then
    skip "BL-687 full-step-Read allow arms" "the gate carries no full step Read allow in its snapshot arm (key '${RC_FLINE# *}', found 0); this fixture ships one pull ahead of its subject"
  else
    rp_f_allow() { # a full step Read with the marker present and no stage is allowed, and nothing moves
      _rq="$(rc_proj "$1" first)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-one world formed'; return; }
      _rv="$(rc_call "$1" "$_rq" "$(jcall Read "$_rq/architecture.md")")"
      [ "$_rv" = allow ] || { echo "FAIL:a full step Read with no stage file answered '${_rv}'"; return; }
      _rm="$(rc_post "$_rq" none)"; [ -z "$_rm" ] || { echo "FAIL:the full step Read with no stage file moved state: ${_rm}"; return; }
      echo PASS
    }
    rp_f_seq() { # the sequential snapshot Read then step Read still satisfies the recovery
      _rq="$(rc_proj "$1" first)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-one world formed'; return; }
      _rs="$(rc_call "$1" "$_rq" "$(jcall Read "$_rq/_bmad-output/pipeline-snapshot.md")")"
      _rv="$(rc_call "$1" "$_rq" "$(jcall Read "$_rq/architecture.md")")"
      [ "$_rs" = allow ] && [ "$_rv" = allow ] || { echo "FAIL:snapshot then step Read answered '${_rs}' then '${_rv}'"; return; }
      { [ ! -e "$_rq/$mk" ] && [ -e "$_rq/_bmad-output/.recover-satisfied" ]; } || { echo 'FAIL:snapshot then step Read did not remove the marker and write .recover-satisfied'; return; }
      echo PASS
    }
    rp_f_bound() { # control: a BOUNDED step Read (limit=1) with no stage is still denied FIRST
      _rq="$(rc_proj "$1" first)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-one world formed'; return; }
      _rv="$(rc_call "$1" "$_rq" "$(jbounded "$_rq/architecture.md" 1 -)")"
      [ "$_rv" = first ] || { echo "FAIL:a limit=1 step Read with no stage file answered '${_rv}'"; return; }
      echo PASS
    }
    rp_f_decoy() { # control: any other Read with no stage is still denied FIRST
      _rq="$(rc_proj "$1" first)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-one world formed'; return; }
      _rv="$(rc_call "$1" "$_rq" "$(jcall Read "$_rq/decoy.md")")"
      [ "$_rv" = first ] || { echo "FAIL:a decoy Read with no stage file answered '${_rv}'"; return; }
      echo PASS
    }
    rp_f_hand() { # carve-out: a recovery whose step file is steps/handoff.md keeps the FIRST deny on it
      _rq="$(newproj handoff.md consumer)"
      arm_marker "$1/$RC_RH" "$_rq"
      _rsf="$(marker_step "$_rq")"
      case "$_rsf" in */steps/handoff.md|steps/handoff.md) ;; *) echo "FAIL:SEED — the recovery recorded step_file '${_rsf}', not a steps/handoff.md"; return ;; esac
      { [ -e "$_rq/$mk" ] && [ ! -e "$_rq/$pg" ]; } || { echo 'FAIL:SEED — no stage-one world formed'; return; }
      _rv="$(rc_call "$1" "$_rq" "$(jcall Read "$_rq/$_rsf")")"
      [ "$_rv" = first ] || { echo "FAIL:a full handoff.md step Read with no stage file answered '${_rv}', not the FIRST deny"; return; }
      echo PASS
    }
    rc_flabel() {
      case "$1" in
        f_allow) echo "BL-687: a full step Read with the marker present and no stage file is ALLOWED; marker kept, no stage written, no .recover-satisfied, no .recover-advisor-owed" ;;
        f_seq)   echo "BL-687: a sequential snapshot Read then step Read still satisfies the recovery (marker removed, .recover-satisfied written)" ;;
        f_bound) echo "BL-687 control: a bounded step Read (limit=1) with no stage file is still denied FIRST" ;;
        f_decoy) echo "BL-687 control: a decoy Read with no stage file is still denied FIRST" ;;
        f_hand)  echo "BL-687 carve-out: a full Read of a steps/handoff.md step file with no stage file is still denied FIRST" ;;
      esac
    }
    RC_P687="f_allow f_seq f_bound f_decoy f_hand"
    for _ra in $RC_P687; do _rr="$("rp_$_ra" "$RC_REAL")"; if [ "$_rr" = PASS ]; then ok "$(rc_flabel "$_ra")"; else bad "$(rc_flabel "$_ra") — ${_rr#FAIL:}"; fi; done
  fi

fi  # race subject present

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

# =============================================================================
# THE POSITION COUNT — a `## Pipeline Position` naming TWO live step files
#
# THE DEFECT. `current_step_file` is single-valued and overwritten in place, and this hook
# used to decide it with a whole-file `grep -m1`: on a section carrying a stale bullet above a
# live one it mandated whichever came FIRST, while the excerpt at the bottom of the same block
# printed BOTH. One block told the lead to Read one step file and displayed another, and the
# gate armed on the coin toss. Where the section names two DIFFERENT step files the hook now
# REFUSES: no mandate naming a path, `step_file_resolved=0`, and a disclosure that says it
# found TWO -- because "names two" and "names none" are different states and the block used to
# describe only the second.
#
# SEVEN DISTINCT INPUT SHAPES, not seven arms. Channels written by different hands converge on
# the obvious seed and then agree for that reason; the gap is always in the SEED. The shapes:
#
#   1 TWO UNLABELLED live bullets naming different files   (S1, S1b)
#   2 ONE live bullet                                      (S2, S2b, S2c)
#   3 a LABELLED prior beside a live bullet                (S3 below it, S4 above it)
#   4 TWO bullets naming the SAME file                     (S5)
#   5 a PROSE line quoting the key name mid-sentence       (S6)
#   6 an INVERSE label, `(LIVE)`                           (S7)
#   7 MIXED key spellings across the two bullets           (S1b)
#
# Shapes 1 and 2 are the pair the whole refusal turns on and they are asserted to DIFFER in
# this run, in one invocation: a hook that refused everything and a hook that refused nothing
# both satisfy either seed alone.
#
# EVERY SEED IS SPELLED IN MORE THAN ONE KEY FORM, and that is measured rather than stylistic.
# Over 2218 revisions of the reference consumer's snapshot the dominant spellings are
# `- **Current step file:**` (1353) and the backticked `- **\`current_step_file\`:**` (18); a
# strict `current_step_file:`-only key un-resolves 94 revisions this hook resolves today. S2b
# and S2c are the seeds that catch that narrowing.
# =============================================================================

# A project whose steps directory holds BOTH candidate files, so a snapshot naming either one
# resolves and the refusal is about the COUNT rather than about a path that is not there.
# Each seed is a WHOLE snapshot written from scratch: a world that edited only the position
# line would leave the previous world's sections on disk and the next arm would read a shape
# nobody seeded.
posproj() { # posproj <tag> <position-line-1> [position-line-2] -> project dir
  _pp="$(mktemp -d "$WORK/pos-$1.XXXXXX")" || return 1
  mkdir -p "$_pp/_bmad-output" "$_pp/${STEPS_REL}"
  printf 'live step body\n'  > "$_pp/${STEPS_REL}/live.md"
  printf 'stale step body\n' > "$_pp/${STEPS_REL}/stale.md"
  {
    printf '# Pipeline Snapshot\n\n## Pipeline Position\n'
    printf -- '- pipeline_variant: sprint\n'
    printf '%s\n' "$2"
    [ -n "${3:-}" ] && printf '%s\n' "$3"
    printf -- '- last_gate_passed: planning-gate-2 @ 2026-08-04T10:00:00Z\n'
    printf '\n## Sprint Context\n- sprint_id: 300\n'
  } > "$_pp/_bmad-output/pipeline-snapshot.md"
  printf 'in-flight edit work\n' > "$_pp/decoy.md"
  printf '%s\n' "$_pp"
}

# postok <hook> <project> -> <resolved>/<basename the marker recorded>/<disclosed count>/<2nd mandate>
#
# EVERY FIELD IS A FACT THE HOOK EMITS, so a hook that emits nothing scores DEAD and fails
# every arm by construction rather than passing any. The mandate cell distinguishes a mandate
# naming a PATH from one naming an ACTION from one rendering an EMPTY path, which a cell reading
# only "is there a second mandate" could not see.
postok() { # postok <hook-path> <project>
  _ph="$1"; _pp="$2"
  rm -f "$_pp/_bmad-output/.recover-fired"
  _pc="$(fire_at "$_ph" "$_pp")"
  [ -n "$_pc" ] || { printf 'DEAD'; return; }
  _p1="$(tr '\n' ' ' <<<"$_pc")"
  _pr="$(sed -n 's/^step_file_resolved=//p' "$_pp/_bmad-output/.recover-fired" 2>/dev/null | head -1)"
  [ -n "$_pr" ] || _pr=x
  _ps="$(sed -n 's/^step_file=//p' "$_pp/_bmad-output/.recover-fired" 2>/dev/null | head -1)"
  _pb="${_ps##*/}"; [ -n "$_pb" ] || _pb=-
  _pd="$(sed -n 's/.*names \([0-9][0-9]*\) DIFFERENT step files.*/\1/p' <<<"$_p1" | head -1)"
  [ -n "$_pd" ] || _pd=-
  _pm="$(sed -n 's/.*SECOND tool call MUST be `Read \([^`]*\)`.*/\1/p' <<<"$_p1" | head -1)"
  case "$_pm" in
    '<that path>') _pm=ACTION ;;
    '') grep -q 'SECOND tool call MUST be' <<<"$_p1" && _pm=EMPTY || _pm=NOMANDATE ;;
    *)  _pm="${_pm%% *}"; _pm="${_pm##*/}" ;;
  esac
  printf '%s/%s/%s/%s' "$_pr" "$_pb" "$_pd" "$_pm"
}

# THE TEN SEEDS, SPELLED AS THE PRODUCER WRITES THEM, never as the reader accepts them. A seed
# derived from the reader's own accept-set proves the reader accepts its own grammar and stays
# green through a change to both.
POS_LIVE='- **Current step file:** live.md'
# EACH SEED WORLD IS BUILT ONCE (clause 4). postok clears the marker before every drive and the
# recovery hook writes nothing else a later drive reads, so one world per seed serves every hook.
POS_SEEDS="S1 S1b S2 S2b S2c S3 S4 S5 S6 S7"
posseed() { # posseed <seed> -> its world, built on first use
  [ -d "$WORK/tpl/pos.$1" ] && { printf '%s\n' "$WORK/tpl/pos.$1"; return; }
  case "$1" in
    S1)  _ps="$(posproj s1  '- **Current step file:** stale.md' "$POS_LIVE")" ;;
    S1b) _ps="$(posproj s1b '- current_step_file: stale.md' '- **`current_step_file`:** `live.md`')" ;;
    S2)  _ps="$(posproj s2  "$POS_LIVE")" ;;
    S2b) _ps="$(posproj s2b '- **`current_step_file`:** `live.md`')" ;;
    S2c) _ps="$(posproj s2c '- Current step file: live.md')" ;;
    S3)  _ps="$(posproj s3  "$POS_LIVE" '- **(prior) Current step file:** stale.md')" ;;
    S4)  _ps="$(posproj s4  '- **(prior) Current step file:** stale.md' "$POS_LIVE")" ;;
    S5)  _ps="$(posproj s5  "$POS_LIVE" '- current_step_file: live.md')" ;;
    S6)  _ps="$(posproj s6  "$POS_LIVE" 'The block below records current_step_file: as its own key name, in prose.')" ;;
    S7)  _ps="$(posproj s7  '- **current_step_file (LIVE):** live.md')" ;;
  esac
  mkdir -p "$WORK/tpl"; mv "$_ps" "$WORK/tpl/pos.$1"; printf '%s\n' "$WORK/tpl/pos.$1"
}
for _s in $POS_SEEDS; do posseed "$_s" >/dev/null; done
posbattery() { # posbattery <hook-path> [seeds] -> one token per seed
  _pt=""
  for _s in ${2:-$POS_SEEDS}; do _pt="$_pt $_s:$(postok "$1" "$(posseed "$_s")")"; done
  printf '%s' "${_pt# }"
}

POS_EXPECTED="S1:0/-/2/ACTION S1b:0/-/2/ACTION S2:1/live.md/-/live.md S2b:1/live.md/-/live.md S2c:1/live.md/-/live.md S3:1/live.md/-/live.md S4:1/live.md/-/live.md S5:1/live.md/-/live.md S6:1/live.md/-/live.md S7:1/live.md/-/live.md"

# --- Assertion 26: the ten seeds, against the REAL hook ----------------------
POS_GOT="$(posbattery "$HOOK")"
if [ "$POS_GOT" = "$POS_EXPECTED" ]; then
  ok "position: two unlabelled bullets naming different step files REFUSE in both key spellings (no path in the mandate, step_file_resolved=0, the disclosure says TWO); a single bullet resolves in all three real spellings including the backticked KEY and the unbolded prose key; a labelled \`(prior)\` above or below a live bullet resolves; two bullets naming ONE file resolve; a prose line quoting the key mid-sentence does not count; and \`(LIVE)\` stays a live value"
else
  bad "position: the ten-seed battery did not answer as expected — wanted [$POS_EXPECTED], got [$POS_GOT]"
fi

# --- Assertion 26b: S1 and S2 DIFFER, in this invocation ---------------------
# THE DISCRIMINATION IS THE CLAIM, and neither seed alone establishes it: a hook that refused
# every snapshot passes S1, a hook that refused none passes S2, and each reads as a working
# reader from the other's side. `verification-discipline.md` requires the two candidate
# semantics computed and compared before either verdict is read.
POS_S1="$(postok "$HOOK" "$(posseed S1)")"
POS_S2="$(postok "$HOOK" "$(posseed S2)")"
if [ "$POS_S1" = DEAD ] || [ "$POS_S2" = DEAD ]; then
  bad "position: the hook emitted nothing for one of the two discriminating seeds, so their comparison measures nothing"
elif [ "$POS_S1" = "$POS_S2" ]; then
  bad "position: the two-bullet seed and the one-bullet seed BOTH answer [$POS_S1] — the count does not discriminate, and one of the two verdicts above is being read off a hook that answers the same way whatever the snapshot says"
else
  ok "position: the two-bullet and one-bullet seeds answer DIFFERENTLY in one invocation ([$POS_S1] vs [$POS_S2]) — the refusal is keyed on the count and not on a constant"
fi

# --- Assertion 26c: the REFUSAL's disclosure names the state, not an absence --
# "Names two" and "names none" are different states, and the injected text described only the
# second. A lead recovering from an ambiguous snapshot was told the snapshot named NO step
# file, which is false, and was being asked in the same block to report its state.
POS_A="$(fire_at "$HOOK" "$(posseed S1)")"
posmiss=""
grep -q 'names 2 DIFFERENT step' <<<"$POS_A"  || posmiss="$posmiss says-how-many"
grep -q 'stale\.md' <<<"$POS_A"               || posmiss="$posmiss names-the-first-candidate"
grep -q 'live\.md'  <<<"$POS_A"               || posmiss="$posmiss names-the-second-candidate"
grep -q 'CANNOT ARM' <<<"$POS_A"              || posmiss="$posmiss discloses-the-gate-stood-down"
grep -q 'do not report it as' <<<"$POS_A"     || posmiss="$posmiss warns-against-reporting-an-absent-field"
# THE NEAR-MISS IS IN THE SAME ARM. A single bullet must carry NONE of this, or the paragraph
# is unconditional and the arm above would pass against a hook that discloses ambiguity always.
POS_B="$(fire_at "$HOOK" "$(posseed S2)")"
posextra=""
grep -q 'DIFFERENT step' <<<"$POS_B" && posextra="$posextra discloses-ambiguity-on-a-single-bullet"
grep -q 'CANNOT ARM'     <<<"$POS_B" && posextra="$posextra stands-the-gate-down-on-a-single-bullet"
if [ -z "$posmiss" ] && [ -z "$posextra" ]; then
  ok "position: the refusal discloses the COUNT and both candidate files, says the gate cannot arm, and tells the lead not to report it as an absent field — and a single-bullet snapshot in the same run carries none of that"
elif [ -n "$posmiss" ]; then
  bad "position: the two-file disclosure is missing:$posmiss — the lead is told the snapshot names no step file, which is false, and it is the state it has just been asked to report"
else
  bad "position: the ambiguity disclosure fires on a snapshot with ONE live bullet:$posextra — the paragraph is unconditional, so the arm above proves nothing"
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

# =============================================================================
# THE THREE-HOOK SEQUENCE -- the arm that could only be written after the field
#
# Every gate arm above seeds the marker with the real producer and then drives the gate. That
# is two of the three hooks the harness runs, and the one it skips is the one that mattered:
# `ai-dlc-postcompact.sh` fires on PostCompact, AFTER SessionStart:compact wrote the marker and
# BEFORE the first PreToolUse, and it used to delete the marker after reading it for the
# compaction log. So the gate found nothing, exited 0 on its fast path, and every arm above
# stayed green -- correctly, about a sequence no consumer executes. Measured: 636 of 637
# logged compactions on the reference consumer read `recovery_injected: yes` (postcompact READ
# the file), the gate's deny text in 0 of 256 transcripts, and all ten post-compaction first
# calls in one session non-mandated and undenied.
#
# The arm runs all three, in harness order, and asserts the deny.
# =============================================================================
if [ -z "${POSTCOMPACT:-}" ]; then
  if [ "$IS_DIST" = 1 ]; then bad "ai-dlc-postcompact.sh is absent from the distribution tree"
  else skip "three-hook sequence" "ai-dlc-postcompact.sh is in neither layout"; fi
elif [ -z "${GATE:-}" ] || ! command -v jq >/dev/null 2>&1; then
  skip "three-hook sequence" "the gate or jq is absent; the deny cannot be observed"
else

p_sequence() { # p_sequence <postcompact-hook> -> PASS | FAIL:<what it saw>
  _p="$(armed_proj "$HOOK" route.md consumer)"
  [ -f "$_p/$mk" ] || { printf 'FAIL:SEED — the producer wrote no marker, so the sequence has nothing to lose\n'; return; }
  printf '{"trigger":"auto","session_id":"sess-A","compact_summary":"seeded"}' | hook_run "$1" "$_p" >/dev/null 2>&1
  grep -q 'recovery_injected: yes' "$_p/_bmad-output/compaction-log.md" 2>/dev/null \
    || { printf 'FAIL:postcompact did not log the injection, so it never read the marker and this arm measured nothing\n'; return; }
  [ -f "$_p/$mk" ] || { printf 'FAIL:postcompact DELETED the marker the gate arms on, one event before the gate can read it\n'; return; }
  d="$(gate_call "$GATE" "$_p" "$(jcall Bash -)")"
  allowed "$d" && { printf 'FAIL:the first tool call after a real three-hook compaction was ALLOWED (%s)\n' "${d%%|*}"; return; }
  printf 'PASS\n'
}

r="$(p_sequence "$POSTCOMPACT")"
if [ "$r" = PASS ]; then
  ok "three-hook sequence: recover.sh -> postcompact.sh -> gate, the marker survives postcompact and the first non-mandated call is DENIED"
else
  bad "three-hook sequence: ${r#FAIL:}"
fi

# --- postcompact.sh: WHOSE COMPACTION IT LOGS ---------------------------------------------------
# This hook decided "recovery injected?" from whether `.recover-fired` EXISTS. With the producer
# standing down for /ai-dlc-update that read an update session's compaction as `no` (the retro's
# failure signal for a lead resuming from the summary alone), and a lead's marker still on disk
# read as `yes` with the lead's byte count. Every case asserts the logged VALUE, or that nothing
# was logged and nothing printed. Transcripts and the marker use the whose-recovery helpers, so
# this block runs only where they are defined.
if grep -qF 'mval session_id' "$GATE" && grep -qF 'printf '"'"'session_id=%s' "$HOOK"; then

pcall() { # pcall <postcompact> <project> <session> <transcript> -> its stdout
  printf '{"trigger":"auto","session_id":"%s","transcript_path":"%s","compact_summary":"seeded"}' "$3" "$4" | hook_run "$1" "$2" 2>/dev/null
}
plog() { cat "$1/_bmad-output/compaction-log.md" 2>/dev/null || true; }

# P7. An update session compacts with NO marker on disk: nothing logged, nothing printed.
pc_upd_nomark() {
  _p="$(newproj architecture.md consumer)"; stx upd "$_p/tU.jsonl"
  [ -e "$_p/$mk" ] && { printf 'FAIL:SEED CANNOT EXPRESS THE CASE — a marker exists\n'; return; }
  _o="$(pcall "$1" "$_p" S-U "$_p/tU.jsonl")"
  [ -z "$_o" ] || { printf 'FAIL:printed into an update session: %s\n' "$_o"; return; }
  [ -z "$(plog "$_p")" ] || { printf 'FAIL:wrote a compaction-log entry for an update session\n'; return; }
  printf 'PASS\n'
}
# P6. A lead's marker for session A is on disk and an update session compacts: still nothing.
pc_upd_foreign() {
  _p="$(armed_sa "$HOOK" tA.jsonl)"; stx upd "$_p/tU.jsonl"
  [ -e "$_p/$mk" ] || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE — no marker\n'; return; }
  _o="$(pcall "$1" "$_p" S-U "$_p/tU.jsonl")"
  [ -z "$_o" ] || { printf 'FAIL:printed into an update session: %s\n' "$_o"; return; }
  [ -z "$(plog "$_p")" ] || { printf 'FAIL:logged an update session'"'"'s compaction against the lead'"'"'s marker\n'; return; }
  printf 'PASS\n'
}
# P6b. A PIPELINE session compacts and the marker is another session's: the report is `no`, with
# no byte count -- never `yes` for a recovery that was not this session's.
pc_foreign() {
  _p="$(armed_sa "$HOOK" tA.jsonl)"; stx pipe "$_p/tB.jsonl"
  _o="$(pcall "$1" "$_p" S-B "$_p/tB.jsonl")"
  _l="$(plog "$_p")"
  grep -qx -- '- recovery_injected: no' <<<"$_l" || { printf 'FAIL:did not log `no` for a marker owned by another session\n'; return; }
  grep -q '^- injected_bytes:' <<<"$_l" && { printf 'FAIL:logged another session'"'"'s byte count\n'; return; }
  printf 'PASS\n'
}
# P6c. CONTROL / BACK-COMPAT: an ownerless marker and a pipeline session still log `yes` with bytes.
pc_legacy() {
  _p="$(armed_sa "$HOOK" tB.jsonl)"; sunowned "$_p"
  pcall "$1" "$_p" S-B "$_p/tB.jsonl" >/dev/null
  _l="$(plog "$_p")"
  grep -qx -- '- recovery_injected: yes' <<<"$_l" || { printf 'FAIL:an ownerless marker stopped reading as an injection\n'; return; }
  grep -q '^- injected_bytes: [0-9]' <<<"$_l" || { printf 'FAIL:the byte count was not logged for an ownerless marker\n'; return; }
  printf 'PASS\n'
}
PCPREDS="upd_nomark upd_foreign foreign legacy"
for _n in $PCPREDS; do
  r="$("pc_$_n" "$POSTCOMPACT")"
  case "$_n" in
    upd_nomark)  label="postcompact: an update session's compaction with no marker logs nothing and prints nothing" ;;
    upd_foreign) label="postcompact: an update session's compaction beside a lead's marker logs nothing and prints nothing" ;;
    foreign)     label="postcompact: a marker owned by another session is logged as \`no\` with no byte count, never \`yes\`" ;;
    legacy)      label="postcompact: CONTROL — an ownerless marker still reads \`yes\` with its byte count" ;;
  esac
  if [ "$r" = PASS ]; then ok "$label"; else bad "$label — ${r#FAIL:}"; fi
done

fi

fi

# =============================================================================
# EQUIVALENCE -- the in-process answer is the CLI's, byte for byte, and these are the end-to-end runs
#
# Every cell above sources its subject in a subshell (hook_run / val_run). These cells run each
# subject ONCE MORE as the harness does, `bash <file>` with the payload on stdin, on a REFUSING and a
# PASSING input that differ, and require the two answers identical. They are also the fixture's
# end-to-end runs, one per distinct CLI outcome. Each pair is taken on
# two `cp -R` copies of ONE seeded world, because a call mutates the state it is judged on.
# Normalised only where the subject is nondeterministic BY DESIGN: the recovery hook mints a fresh
# provenance nonce on every SessionStart (dropped with `demark`, and the marker's `fired_at=` line),
# and postcompact stamps its log heading with the time (its `## ` line dropped).
# =============================================================================
eqv() { # eqv <label> <cli answer> <in-process answer>
  if [ "$2" = "$3" ]; then return 0; fi
  bad "EQUIVALENCE: $1 -- the in-process answer differs from the CLI's: cli [$(printf '%s' "$2" | head -c 300)] in-process [$(printf '%s' "$3" | head -c 300)]"
  return 1
}
cp_world() { _cw="$(mktemp -d "$WORK/eq.XXXXXX")" && cp -R "$1/." "$_cw/" && printf '%s\n' "$_cw"; }
# recover: <project> <mode cli|inproc> -> the demarked context, the exit, and the marker without fired_at
eq_rec() {
  if [ "$2" = cli ]; then
    _eo="$(printf '{"source":"compact","session_id":"sess-A"}' | CLAUDE_PROJECT_DIR="$1" bash "$HOOK" 2>&1)"; _er=$?
  else
    _eo="$(printf '{"source":"compact","session_id":"sess-A"}' | hook_run "$HOOK" "$1" 2>&1)"; _er=$?
  fi
  printf 'rc=%s\n%s\n--marker--\n%s' "$_er" "$(demark "$(ctx_of "$_eo")")" "$(grep -v '^fired_at=' "$1/$mk" 2>/dev/null)"
}
eq_gate() { # <project> <cli|inproc> <json> -> raw stdout, exit, and the gate state left on disk
  if [ "$2" = cli ]; then
    _eo="$(printf '%s' "$3" | CLAUDE_PROJECT_DIR="$1" bash "$GATE" 2>&1)"; _er=$?
  else
    _eo="$(printf '%s' "$3" | hook_run "$GATE" "$1" 2>&1)"; _er=$?
  fi
  printf 'rc=%s\n%s\n--state--\nmarker=%s progress=%s' "$_er" "$_eo" "$([ -e "$1/$mk" ] && echo y || echo n)" "$(cat "$1/$pg" 2>/dev/null)"
}
eq_pc() { # <project> <cli|inproc> <session> -> stdout, exit, and the log without its time heading
  _ej="$(printf '{"trigger":"auto","session_id":"%s","compact_summary":"seeded"}' "$3")"
  if [ "$2" = cli ]; then
    _eo="$(printf '%s' "$_ej" | CLAUDE_PROJECT_DIR="$1" bash "$POSTCOMPACT" 2>&1)"; _er=$?
  else
    _eo="$(printf '%s' "$_ej" | hook_run "$POSTCOMPACT" "$1" 2>&1)"; _er=$?
  fi
  printf 'rc=%s\n%s\n--log--\n%s' "$_er" "$_eo" "$(grep -v '^## ' "$1/_bmad-output/compaction-log.md" 2>/dev/null)"
}
eq_val() { # <cli|inproc> <skill> -> stdout+stderr and exit of the validator
  if [ "$1" = cli ]; then _eo="$(bash "$VAL" --skill "$2" 2>&1)"; _er=$?
  else _eo="$(val_run --skill "$2" 2>&1)"; _er=$?; fi
  printf 'rc=%s\n%s' "$_er" "$_eo"
}
eq_n=0
# recovery hook: PASSING = a resolvable single position (a mandate naming the file); REFUSING = two
# live position bullets (no mandate path, step_file_resolved=0).
_ew_pass="$(posproj eqp "$POS_LIVE")"; _ew_ref="$(posproj eqr '- **Current step file:** stale.md' "$POS_LIVE")"
_a="$(cp_world "$_ew_pass")"; _b="$(cp_world "$_ew_pass")"; _c="$(cp_world "$_ew_ref")"; _d="$(cp_world "$_ew_ref")"
_rp_cli="$(eq_rec "$_a" cli)"; _rp_in="$(eq_rec "$_b" inproc)"; _rr_cli="$(eq_rec "$_c" cli)"; _rr_in="$(eq_rec "$_d" inproc)"
if [ "$_rp_cli" = "$_rr_cli" ] || ! grep -q '^step_file_resolved=1$' <<<"$_rp_cli" || ! grep -q '^step_file_resolved=0$' <<<"$_rr_cli"; then
  bad "EQUIVALENCE: recover -- the passing and refusing inputs did not separate under the CLI (resolved=1 vs 0), so the comparison below measures nothing"
else
  eqv "recover, passing input" "$_rp_cli" "$_rp_in" && eqv "recover, refusing input" "$_rr_cli" "$_rr_in" && eq_n=$((eq_n + 1))
fi
if [ -n "${GATE:-}" ] && command -v jq >/dev/null 2>&1; then
  # gate: one armed world; REFUSING = an Edit as the first call (deny), PASSING = the full snapshot Read
  # (allow, advances the stage). Each answer on its own copy, CLI and in process.
  # The payload names a RELATIVE path, which the gate resolves against CLAUDE_PROJECT_DIR, so one
  # payload is the same call in every copy (an absolute path would name the template, not the copy).
  _ew="$(armed_proj "$HOOK" architecture.md flat)"
  _jd="$(jcall Edit decoy.md)"; _ja="$(jcall Read _bmad-output/pipeline-snapshot.md)"
  _gd_cli="$(eq_gate "$(cp_world "$_ew")" cli "$_jd")"; _gd_in="$(eq_gate "$(cp_world "$_ew")" inproc "$_jd")"
  _ga_cli="$(eq_gate "$(cp_world "$_ew")" cli "$_ja")"; _ga_in="$(eq_gate "$(cp_world "$_ew")" inproc "$_ja")"
  if [ "$_gd_cli" = "$_ga_cli" ] || ! grep -q '"permissionDecision": *"deny"' <<<"$_gd_cli" || ! grep -q 'progress=step$' <<<"$_ga_cli"; then
    bad "EQUIVALENCE: gate -- the deny and the allow did not separate under the CLI, so the comparison below measures nothing"
  else
    eqv "gate, refusing input" "$_gd_cli" "$_gd_in" && eqv "gate, passing input" "$_ga_cli" "$_ga_in" && eq_n=$((eq_n + 1))
  fi
  if [ -n "${POSTCOMPACT:-}" ]; then
    # postcompact: the marker's owner compacts -> `yes`; another session compacts -> `no`.
    _ew="$(armed_proj "$HOOK" architecture.md flat)"
    _py_cli="$(eq_pc "$(cp_world "$_ew")" cli sess-A)"; _py_in="$(eq_pc "$(cp_world "$_ew")" inproc sess-A)"
    _pn_cli="$(eq_pc "$(cp_world "$_ew")" cli sess-Z)"; _pn_in="$(eq_pc "$(cp_world "$_ew")" inproc sess-Z)"
    if [ "$_py_cli" = "$_pn_cli" ] || ! grep -q 'recovery_injected: yes' <<<"$_py_cli" || ! grep -q 'recovery_injected: no' <<<"$_pn_cli"; then
      bad "EQUIVALENCE: postcompact -- the owner's and a foreign session's compaction did not separate under the CLI"
    else
      eqv "postcompact, owner" "$_py_cli" "$_py_in" && eqv "postcompact, foreign session" "$_pn_cli" "$_pn_in" && eq_n=$((eq_n + 1))
    fi
  fi
fi
# THE SILENT OUTCOME, for the two hooks that have one: an UPDATE session compacts. The recovery hook
# writes no marker and prints nothing; postcompact logs nothing and prints nothing. CLI and in process,
# each on its own copy of one world, compared on stdout, exit and what is left on disk.
if [ -n "${POSTCOMPACT:-}" ] && grep -qF 'printf '"'"'session_id=%s' "$HOOK"; then
  _ew="$(newproj architecture.md consumer)"
  { printf '%s\n' '{"type":"user","message":{"role":"user","content":"<command-message>ai-dlc-update</command-message>\n<command-name>/ai-dlc-update</command-name>"}}'; } > "$_ew/tU.jsonl"
  eq_silent() { # <project> <cli|inproc> <subject> <json>
    if [ "$2" = cli ]; then _eo="$(printf '%s' "$4" | CLAUDE_PROJECT_DIR="$1" bash "$3" 2>&1)"; _er=$?
    else _eo="$(printf '%s' "$4" | hook_run "$3" "$1" 2>&1)"; _er=$?; fi
    printf 'rc=%s out=[%s] marker=%s log=%s' "$_er" "$_eo" "$([ -e "$1/$mk" ] && echo y || echo n)" "$([ -e "$1/_bmad-output/compaction-log.md" ] && echo y || echo n)"
  }
  _sa="$(cp_world "$_ew")"; _sb="$(cp_world "$_ew")"; _sc="$(cp_world "$_ew")"; _sd2="$(cp_world "$_ew")"
  _js="$(printf '{"source":"compact","session_id":"S-U","transcript_path":"%s/tU.jsonl"}' "$_sa")"
  _rs_cli="$(eq_silent "$_sa" cli "$HOOK" "$_js")"
  _js="$(printf '{"source":"compact","session_id":"S-U","transcript_path":"%s/tU.jsonl"}' "$_sb")"
  _rs_in="$(eq_silent "$_sb" inproc "$HOOK" "$_js")"
  _js="$(printf '{"trigger":"auto","session_id":"S-U","transcript_path":"%s/tU.jsonl","compact_summary":"seeded"}' "$_sc")"
  _ps_cli="$(eq_silent "$_sc" cli "$POSTCOMPACT" "$_js")"
  _js="$(printf '{"trigger":"auto","session_id":"S-U","transcript_path":"%s/tU.jsonl","compact_summary":"seeded"}' "$_sd2")"
  _ps_in="$(eq_silent "$_sd2" inproc "$POSTCOMPACT" "$_js")"
  if [ "$_rs_cli" != 'rc=0 out=[] marker=n log=n' ] || [ "$_ps_cli" != 'rc=0 out=[] marker=n log=n' ]; then
    bad "EQUIVALENCE: the update-session compaction is not silent under the CLI (recover [$_rs_cli], postcompact [$_ps_cli]), so the silent outcome has no end-to-end run"
  else
    eqv "recover, silent (update session)" "$_rs_cli" "$_rs_in" && eqv "postcompact, silent (update session)" "$_ps_cli" "$_ps_in" \
      && ok "equivalence: the silent outcome -- an update session's compaction -- is silent, exit 0 and writes nothing, CLI and in process alike, for recover and postcompact"
  fi
fi
# validator: PASSING = the shipped SKILL.md; REFUSING = the no-mandate copy built above.
_vp_cli="$(eq_val cli "$SKILL")"; _vp_in="$(eq_val inproc "$SKILL")"
_vr_cli="$(eq_val cli "$NOMANDATE_SKILL")"; _vr_in="$(eq_val inproc "$NOMANDATE_SKILL")"
if [ "$_vp_cli" = "$_vr_cli" ] || [ "${_vp_cli%%$'\n'*}" != rc=0 ] || [ "${_vr_cli%%$'\n'*}" != rc=1 ]; then
  bad "EQUIVALENCE: validator -- the shipped and the no-mandate SKILL.md did not separate under the CLI (rc 0 vs 1)"
else
  eqv "validator, passing input" "$_vp_cli" "$_vp_in" && eqv "validator, refusing input" "$_vr_cli" "$_vr_in" && eq_n=$((eq_n + 1))
fi
_eq_want=2; [ -n "${GATE:-}" ] && _eq_want=3; [ -n "${GATE:-}" ] && [ -n "${POSTCOMPACT:-}" ] && _eq_want=4
if [ "$eq_n" = "$_eq_want" ]; then
  ok "equivalence: for each of the ${eq_n} subjects, \`bash <file>\` and the in-process call give byte-identical answers on a refusing and a passing input that differ"
fi

echo
report_end postcompact-rulebook-recovery
