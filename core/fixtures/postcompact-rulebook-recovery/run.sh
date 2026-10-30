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
# that reason. Its mutants are copies OUTSIDE the tree: I113 binds the count grammar
# byte-identically across three files, so a mutation applied in place would trip that invariant
# as well and the fixture's verdict would no longer be attributable to the fixture.
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
[ -n "${POSTCOMPACT:-}" ] && [ -f "$POSTCOMPACT" ] && echo "HERMETIC-CONSUMED $POSTCOMPACT"
[ -f "$(dirname "$HOOK")/ai-dlc-context-provenance.sh" ] && echo "HERMETIC-CONSUMED $(dirname "$HOOK")/ai-dlc-context-provenance.sh"
[ -f "$(dirname "$HOOK")/ai-dlc-handoff-pending.sh" ] && echo "HERMETIC-CONSUMED $(dirname "$HOOK")/ai-dlc-handoff-pending.sh"
[ -f "$(dirname "$VAL")/verdict.sh" ] && echo "HERMETIC-CONSUMED $(dirname "$VAL")/verdict.sh"
_PRS=""; for _c in "$HERE/../../schemas/pause-routing.json" "$HERE/../../../.claude/schemas/pause-routing.json"; do [ -f "$_c" ] && { _PRS="$(cd "$(dirname "$_c")" && pwd -P)/pause-routing.json"; break; }; done
[ -n "$_PRS" ] && echo "HERMETIC-CONSUMED $_PRS"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
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

# ONE RUN PER DISTINCT STATE FOR A MUTANT (fixture-mutants.md clause 2). Every battery below scores a
# mutant by the SET of its predicates that flip. On an ordinary run a mutant runs only the predicates it
# DECIDES plus its named TWINS (the cells one property apart that must stay green), and the verdict is
# still "flips exactly {decides}" over that selection. `--matrix` runs EVERY predicate of the battery
# against every mutant, prints one `MATRIX <mutant> decides=[...] measured=[...]` line each, and the
# same exact-set comparison then holds over the whole battery -- which is what licenses the selection.
# Re-run `bash core/fixtures/postcompact-rulebook-recovery/run.sh --matrix` whenever a predicate, a
# mutant or a twin list changes; every MATRIX line must read measured = decides.
MXMODE=0; [ "${1:-}" = --matrix ] && MXMODE=1
mx_sel() { # mx_sel <all predicates, in order> <decides> <twins|-> -> the members of <all> to run
  if [ "$MXMODE" = 1 ]; then printf '%s' "$1"; return; fi
  _mo=""; for _mx in $1; do case " $2 $3 " in *" $_mx "*) _mo="$_mo $_mx" ;; esac; done; printf '%s' "${_mo# }"
}
mx_note() { [ "$MXMODE" = 1 ] && printf 'MATRIX %s decides=[%s] measured=[%s]\n' "$1" "$2" "${3% }"; return 0; }

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
  ( set +u +e +o pipefail; hash -r; CLAUDE_PROJECT_DIR="$_hr_p"; export CLAUDE_PROJECT_DIR; . "$_hr_f" "$@" )
}
val_run() { # val_run [args...] -- the budget validator, in process; stdout, stderr and the exit are its own
  ( set +u +e +o pipefail; hash -r; . "$VAL" "$@" )
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
proto_of() { # proto_of <validator output> -> the reported protocol end offset, or empty
  sed -n 's/^protocol end offset : \([0-9][0-9]*\) bytes.*/\1/p' <<<"$1" | head -1
}
VB_WHOLE="$(whole_of "$VB_OUT")"
VB_REAL="$(wc -c < "$SKILL" | tr -d ' ')"
# THIS ARM OWNS ONE PROPERTY: THE FIGURE EXISTS AND IS THE WHOLE FILE. Delivery is 6b2's,
# because 6b2 DRIVES the renderer where this arm could only grep for the shape it needs, and
# the arm that runs the subject beats the one that reads its output. The three arms below all
# stand down when this one fires, so a validator with no figure -- or a wrong one -- produces
# ONE red arm rather than four true findings reported four times.
#
# `vb_owns` is the stand-down predicate, computed once and read by 6b2, 6b3 and 6c.
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

# --- Assertion 6c: MUTANT — bytes appended BELOW the protocol, only the whole-file figure moves
# THE ARM THAT PROVES 6b READS THE FILE AND NOT THE WINDOW. `protocol end offset` and
# `whole file` are both byte counts printed by the same program; a figure wired to the
# protocol window would satisfy 6b exactly as a correct one does, and a reader would have no
# way to tell. The mutation appends padding at the END of the file -- strictly below the
# protocol section, whose end boundary is the next `## ` heading far above -- so the protocol
# offset MUST hold still while the whole-file figure MUST move. Both directions in one arm.
#
# The padding carries no `## ` so it cannot become a section and re-bound anything, and the
# exit code must stay 0: an observation that can fail the gate is a gate.
# Built as a COPY, guarded by cmp -s per fixture-mutants.md.
#
# THIS ARM STANDS DOWN WHERE 6b ALREADY OWNS THE FINDING. A validator emitting no figure, or a
# wrong one, is 6b's case; without the stand-down both arms report it and one of the two is
# vacuous -- measured on the protocol-window and figure-deleted mutants, each of which tripped
# 6b AND this arm's staleness diagnostic. One mutant, one red arm.
MUT_BIG="$WORK/skill-appended-below.md"
{ cat "$SKILL"; printf 'padding below the protocol, carrying no heading\n'; } > "$MUT_BIG"
if [ "$vb_owns" = 1 ]; then
  defer "the whole-file figure MOVES with the file" "assertion 6b"
elif cmp -s "$SKILL" "$MUT_BIG"; then
  bad "FIXTURE STALE: the appended copy is byte-identical to SKILL.md, so the whole-file figure has nothing to move and assertion 6b is unproven"
else
  MB_OUT="$(val_run --skill "$MUT_BIG" 2>&1)"; mb_rc=$?
  MB_WHOLE="$(whole_of "$MB_OUT")"
  MB_PROTO="$(proto_of "$MB_OUT")"
  VB_PROTO="$(proto_of "$VB_OUT")"
  MB_REAL="$(wc -c < "$MUT_BIG" | tr -d ' ')"
  if [ "$mb_rc" -ne 0 ]; then
    bad "MUTANT CHANGED THE VERDICT — appending bytes below the protocol made the validator exit ${mb_rc}, so the whole-file figure is a GATE and not the observation this entry asked for"
  elif [ -z "$MB_WHOLE" ] || [ -z "$MB_PROTO" ] || [ -z "$VB_PROTO" ]; then
    bad "FIXTURE STALE: could not read both figures back from the validator (whole='${MB_WHOLE}' proto='${MB_PROTO}' base-proto='${VB_PROTO}') — the output lines were reshaped"
  elif [ "$MB_WHOLE" = "$VB_WHOLE" ]; then
    bad "MUTANT DID NOT FAIL — ${MB_REAL} bytes of file were reported as ${MB_WHOLE}, the same figure as the unappended copy, so the observation is not reading the whole file"
  elif [ "$MB_WHOLE" != "$MB_REAL" ]; then
    bad "the appended copy is ${MB_REAL} bytes and the validator reports ${MB_WHOLE} — the figure moved but does not track the file"
  elif [ "$MB_PROTO" != "$VB_PROTO" ]; then
    bad "MUTANT FAILED TOO MUCH — appending below the protocol moved the protocol end offset from ${VB_PROTO} to ${MB_PROTO}, so the two figures are entangled and the protocol arm is measuring something other than its window"
  else
    ok "mutant: bytes appended BELOW the protocol move the whole-file figure ${VB_WHOLE} -> ${MB_WHOLE} (= wc -c) while the protocol offset holds at ${VB_PROTO} and the exit stays 0"
  fi
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
  out="$(val_run --skill "$MUT_SKILL" --quiet 2>&1)"; rc=$?
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
# THE STALENESS GUARD COUNTS INSIDE THE SECTION, NOT `cmp -s` ON THE FILE. INITIALIZATION
# carries the same path far below, so a whole-file `cmp` stays quiet when the SECTION's copy
# is reworded and only INITIALIZATION's was mutated -- the guard could not fire for its stated
# reason. Per fixture-mutants.md: assert the post-mutation count within the section is 0
# against a non-zero unmutated count, both derived from the validator's own section bounds.
proto_count() { # proto_count <skill-file> -> occurrences of the router path inside the protocol section
  _s="$(grep -n '^## POST-COMPACT RECOVERY PROTOCOL' "$1" | head -1 | cut -d: -f1)"
  [ -n "$_s" ] || { printf '0\n'; return; }
  _e="$(awk -v s="$_s" 'NR>s && /^## / { print NR; exit }' "$1")"
  [ -n "$_e" ] || { printf '0\n'; return; }
  sed -n "${_s},$((_e - 1))p" "$1" | grep -c '\.claude/skills/ai-dlc/steps/route\.md'
}
MUT_ROUTE="$WORK/skill-no-router.md"
sed 's|\.claude/skills/ai-dlc/steps/route\.md|the router step|g' "$SKILL" > "$MUT_ROUTE"
if [ "$(proto_count "$SKILL")" -eq 0 ]; then
  bad "FIXTURE STALE: the shipped protocol section names the router path 0 times, so the router mutant has no subject to remove and assertion 6 is the only thing standing"
elif [ "$(proto_count "$MUT_ROUTE")" -ne 0 ]; then
  bad "FIXTURE STALE: the mutation left $(proto_count "$MUT_ROUTE") router path(s) inside the protocol section, so the mutant does not remove the whole property"
else
  out="$(val_run --skill "$MUT_ROUTE" --quiet 2>&1)"; rc=$?
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
  out="$(val_run --skill "$MUT_ROUTE_C" --quiet 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ] && grep -q 'does not send an un-routed session to the' <<<"$out"; then
    ok "mutant: a router path present only inside an HTML comment FAILS the router arm"
  elif [ "$rc" -ne 0 ]; then
    bad "MUTANT FAILED ON THE WRONG ARM — commenting out the router path tripped a different check. Output: $(head -1 <<<"$out")"
  else
    bad "MUTANT DID NOT FAIL — a router path inside an HTML comment satisfies the validator, so the arm is closable by a comment"
  fi
fi

# --- Assertion 7d: MUTANT — the router path survives only inside a MULTI-LINE comment ---
# The house-style form: 18 of the 20 HTML comments in SKILL.md span lines, and a one-line
# `sed 's/<!--.*-->//'` guard passed a path parked in one. The comment opens on the line
# before the path and closes on the line after, so a single-line stripper cannot see it.
MUT_ROUTE_M="$WORK/skill-router-multiline-comment.md"
awk '
  index($0, "`{project-root}/.claude/skills/ai-dlc/steps/route.md`") && !d {
    print "<!-- the router path, parked in a comment:"; print $0; print "-->"; d = 1; next
  }
  { print }' "$SKILL" > "$MUT_ROUTE_M"
if cmp -s "$SKILL" "$MUT_ROUTE_M"; then
  bad "FIXTURE STALE: the protocol's router mention was reworded, so the multi-line-comment mutant is byte-identical and the comment guard is unproven for the house-style form"
else
  out="$(val_run --skill "$MUT_ROUTE_M" --quiet 2>&1)"; rc=$?
  if [ "$rc" -ne 0 ] && grep -q 'does not send an un-routed session to the' <<<"$out"; then
    ok "mutant: a router path present only inside a MULTI-LINE HTML comment FAILS the router arm"
  elif [ "$rc" -ne 0 ]; then
    bad "MUTANT FAILED ON THE WRONG ARM — wrapping the router path in a multi-line comment tripped a different check. Output: $(head -1 <<<"$out")"
  else
    bad "MUTANT DID NOT FAIL — a router path inside a multi-line HTML comment satisfies the validator, which is the comment form this file actually uses"
  fi
fi

# --- Assertion 7e: CONTROL — a live path BRACKETED by two one-line comments still counts --
# The greedy `.*` failure: `<!-- a --> path <!-- b -->` on one line stripped the path with the
# comments. The stripper must remove only the commented spans, so this copy must PASS.
MUT_ROUTE_B="$WORK/skill-router-bracketed.md"
sed 's|`{project-root}/\.claude/skills/ai-dlc/steps/route\.md`|<!-- a --> `{project-root}/.claude/skills/ai-dlc/steps/route.md` <!-- b -->|' "$SKILL" > "$MUT_ROUTE_B"
if cmp -s "$SKILL" "$MUT_ROUTE_B"; then
  bad "FIXTURE STALE: the protocol's router mention was reworded, so the bracketed control is byte-identical and proves nothing"
elif val_run --skill "$MUT_ROUTE_B" --quiet >/dev/null 2>&1; then
  ok "control: a live router path bracketed by two one-line comments still PASSES — the stripper removes only the comments"
else
  bad "CONTROL FAILED — a live router path between two one-line comments was stripped with them, so the arm refuses a compliant protocol"
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
# the same few shapes were armed afresh by every predicate of every mutant pass. So each shape is
# armed ONCE by the real producer and copied. KEYED ON CONTENT, NOT ON A PATH: the template is used
# only when the producer handed in is byte-identical to $HOOK, so a producer MUTANT (the legacy
# producer, a whose-recovery or BL-684/BL-688 producer edit) always arms its own world live and is
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
verdicts() { # verdicts <gate> [predicates] -> "name=PASS" lines, in PREDS order
  for _n in ${2:-$PREDS}; do
    case "$_n" in
      ladder_abs)      r="$(p_ladder "$1" abs)" ;;
      ladder_rel)      r="$(p_ladder "$1" rel)" ;;
      ladder_consumer) r="$(p_ladder "$1" consumer)" ;;
      *)               r="$("p_$_n" "$1")" ;;
    esac
    printf '%s=%s\n' "$_n" "${r%%:*}"
  done
}
flips() { printf '%s ' $(verdicts "$1" "${2:-}" | sed -n 's/=FAIL$//p'); }
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
    mate_calls)         r="$(p_mate_calls "$GATE")";         label="armed: a teammate's Write, Bash and Agent are allowed, and the lead's identical calls are still denied" ;;
    mate_reads)         r="$(p_mate_reads "$GATE")";         label="armed: a teammate's two mandated Reads leave the lead's gate armed, and the lead's same Reads disarm it" ;;
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
mutant_arm() { # mutant_arm <label> <mutant> <expected flip set, in PREDS order> <twins|-> <name>
  if cmp -s "$GATE" "$2"; then
    bad "FIXTURE STALE: $1 — the mutant is byte-identical to the gate, so the mutation matched nothing"; return
  fi
  if ! bash -n "$2" 2>/dev/null; then
    bad "FIXTURE STALE: $1 — the mutant is not valid shell; it would emit nothing, and a silent gate is an ALLOW that would score as a kill"; return
  fi
  got="$(flips "$2" "$(mx_sel "$PREDS" "$3" "$4")")"; mx_note "$5" "$3" "$got"
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
# `mate_calls` is the fourth: its lead twin is a refusal.
mutant_arm "a gate that never refuses" "$MG_ALLOW" "deny_first full_snapshot full_step mate_calls" "ladder_abs standdown_r0" G-allow-all

# --- Assertion 19: MUTANT — the gate arms on an unresolvable mandate ---------
# BOTH layers of the precondition, because they are one guard: with only the flag check gone
# the empty step_file still stops it, and a mutant that killed nothing reads exactly like an
# arm that cannot fire.
MG_R0="$WORK/gate-arms-unresolved.sh"
awk '!(index($0,"[ \"$STEP_RESOLVED\" = \"1\" ] || exit 0") || index($0,"[ -n \"$STEP_REL\" ] || exit 0"))' "$GATE" > "$MG_R0"
mutant_arm "a gate that arms when the snapshot named no step file" "$MG_R0" "standdown_r0" "deny_first standdown_missing" G-arms-r0

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
#
# THE MARKER TEST IS TWO LINES, AND THIS MUTANT TAKES BOTH ON PURPOSE. The fast-path is the first;
# the second re-tests the marker just after the stage read (BL-658, the race battery below owns
# it). Both are arming preconditions on the same file. Kept, the second alone stands a markerless
# call down -- the unset paths resolve to the readable project directory, the stage defaults, and
# the re-test exits -- so `inert`, the three ladders and `standdown_missing` would stop flipping
# and this arm would read as entangled on a correct gate. The count below holds the removal to
# every copy of that line and refuses a mutant that left one behind.
MG_WEDGE="$WORK/gate-no-standdown.sh"
awk '!(index($0,"[ -f \"$MARKER\" ] || exit 0") || index($0,"[ \"$STEP_RESOLVED\" = \"1\" ] || exit 0") || index($0,"[ -n \"$SNAP_REL\" ] || exit 0") || index($0,"[ -n \"$STEP_REL\" ] || exit 0"))' "$GATE" > "$MG_WEDGE"
_mw_n="$(grep -cF '[ -f "$MARKER" ] || exit 0' "$GATE")" || _mw_n=0
_mw_m="$(grep -cF '[ -f "$MARKER" ] || exit 0' "$MG_WEDGE")" || _mw_m=0
if [ "$_mw_n" -lt 1 ] || [ "$_mw_m" -ne 0 ]; then
  bad "FIXTURE STALE: the every-precondition mutant left ${_mw_m} of ${_mw_n} marker tests in place"
else
  mutant_arm "a gate with every arming precondition removed" "$MG_WEDGE" "inert ladder_abs ladder_rel ladder_consumer standdown_r0 standdown_missing legacy fastpath" "full_snapshot full_step" G-no-standdown
fi

# --- Assertion 21: MUTANT — one spelling only --------------------------------
# The call's path left unnormalised while the marker's stays resolved. The absolute ladder is
# unaffected, which is the point: this is the mutation a fixture that tested one spelling
# would ship green.
MG_SPELL="$WORK/gate-one-spelling.sh"
sed 's|FABS="\$(resolve "\$FPATH")"|FABS="$FPATH"|' "$GATE" > "$MG_SPELL"
mutant_arm "a gate that matches only the absolute spelling" "$MG_SPELL" "ladder_rel" "ladder_abs" G-one-spelling

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
  mutant_arm "a gate with the path-readability stand-down removed" "$MG_MISS" "standdown_missing" "standdown_r0" G-no-readability
fi

# --- MUTANT — the marker fast-path deleted -----------------------------------
# THE ONE MUTANT THAT PROVES A COST ARM CAN FIRE. Removing this line changes NO decision, which
# is exactly why it needed an arm keyed on something other than a decision: with the line gone
# the gate parses the marker path on every ordinary call in every unarmed session — `sed`, not
# `jq`, which sits below the stand-downs — and only `fastpath`
# may notice. If this ever flips a second predicate, the line acquired a behavioural subject
# and the comment in the gate claiming it is a pure fast-path has gone stale.
#
# ANCHORED ON WHAT SEPARATES THE FAST-PATH FROM THE SECOND MARKER TEST (BL-658): the two lines are
# byte-identical, and only the fast-path is followed by the unindented `jq` lookup. Removing both
# would also remove the race battery's subject and the arm would stop being about cost alone.
MG_FAST="$WORK/gate-no-fastpath.sh"
MG_FAST_AT='prev == ENVIRON["F"] && $0 == ENVIRON["J"] { print NR - 1 } { prev = $0 }'
MG_FAST_F='[ -f "$MARKER" ] || exit 0'
MG_FAST_J='command -v jq >/dev/null 2>&1 || exit 0'
_mf_at="$(F="$MG_FAST_F" J="$MG_FAST_J" awk "$MG_FAST_AT" "$GATE")"
case "$_mf_at" in
  (''|*[!0-9]*) bad "FIXTURE STALE: the marker fast-path is not exactly one line directly above the jq lookup (found '${_mf_at}'), so its mutant has no subject" ;;
  (*)
    awk -v t="$_mf_at" 'NR != t' "$GATE" > "$MG_FAST"
    mutant_arm "the marker fast-path deleted — the gate still works but parses on every call" "$MG_FAST" "fastpath" "inert" G-no-fastpath
    ;;
esac

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
mutant_arm "the gate replaced by exit 0" "$MG_DEAD" "deny_first ladder_abs ladder_rel ladder_consumer standdown_missing fastpath full_snapshot full_step mate_calls mate_reads" "inert standdown_r0 legacy" G-dead

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
  mutant_arm "a gate that accepts a BOUNDED Read as compliance, at both sites" "$MG_NOFULL" "full_snapshot full_step" "ladder_abs" G-partial-ok
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
    mutant_arm "a gate that accepts a BOUNDED Read at the ${_site} stage only" "$MG_ONE" "full_${_site}" "$([ "$_site" = snapshot ] && echo full_step || echo full_snapshot)" "G-partial-ok-${_site}"
  fi
  _i=$((_i+1))
done

# --- MUTANTS — the BL-590 teammate exit, removed and widened -----------------
# Anchored on the exit's own line, asserted unique first, so a reworded exit reports STALE rather
# than a no-op scoring as a survivor. REMOVED is the pre-fix gate: a teammate's calls are refused
# and its Reads advance the lead's stages, so both teammate arms flip and nothing else does.
# WIDENED to every caller, the read path is dead for the lead too, so its set is exactly the dead
# gate's: `mate_calls` dies on its lead twin, which is the control this mutant exists to prove.
MG_EXIT_LINE='[ -z "$RG_AGENT" ] || exit 0'
if [ "$(grep -cxF -- "$MG_EXIT_LINE" "$GATE")" -ne 1 ]; then
  bad "FIXTURE STALE: the BL-590 teammate exit is not exactly one line in the gate, so neither of its mutants can be anchored"
else
  MG_NOMATE="$WORK/gate-no-teammate-exit.sh"
  awk -v l="$MG_EXIT_LINE" '$0==l{next} 1' "$GATE" > "$MG_NOMATE"
  mutant_arm "the teammate exit removed — a teammate is refused and its Reads disarm the lead" "$MG_NOMATE" "mate_calls mate_reads" "deny_first" G-no-mate-exit
  MG_ALLMATE="$WORK/gate-exit-every-caller.sh"
  awk -v l="$MG_EXIT_LINE" '$0==l{print "exit 0"; next} 1' "$GATE" > "$MG_ALLMATE"
  mutant_arm "the teammate exit widened to every caller" "$MG_ALLMATE" "deny_first ladder_abs ladder_rel ladder_consumer standdown_missing fastpath full_snapshot full_step mate_calls mate_reads" "inert standdown_r0 legacy" G-exit-every-caller
fi

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
rverdicts() { # rverdicts <recover-hook> [predicates]
  for _n in ${2:-$RPREDS}; do r="$("pr_$_n" "$1")"; printf '%s=%s\n' "$_n" "${r%%:*}"; done
}
rflips() { printf '%s ' $(rverdicts "$1" "${2:-}" | sed -n 's/=FAIL$//p'); }

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

rmutant_arm() { # rmutant_arm <label> <mutant> <expected flip set, in RPREDS order> <twins|-> <name>
  if cmp -s "$HOOK" "$2"; then
    bad "FIXTURE STALE: $1 — the mutant is byte-identical to the producer, so the mutation matched nothing"; return
  fi
  if ! bash -n "$2" 2>/dev/null; then
    bad "FIXTURE STALE: $1 — the mutant is not valid shell; it would emit no directive and write no marker, and both predicates would read that as a kill they did not earn"; return
  fi
  got="$(rflips "$2" "$(mx_sel "$RPREDS" "$3" "$4")")"; mx_note "$5" "$3" "$got"
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
  rmutant_arm "a producer that records the snapshot's bare basename raw and calls it resolved" "$MR_RAW" "consumer assurance" "-" P-raw-basename
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
  rmutant_arm "a producer that never resolves a bare basename under the steps directory" "$MR_RESOLVE" "consumer" "assurance" P-no-resolve
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
  rmutant_arm "a producer whose resolved flag means only that a grep matched something" "$MR_FLAG" "assurance" "consumer" P-flag-blind
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
  rmutant_arm "a producer that promises the gate armed whether or not it could" "$MR_ASSURE" "assurance" "consumer" P-assurance-always
fi

# =============================================================================
# THE ADVISOR STAGE — touchpoint R (BL-545)
#
# After both mandated Reads the gate holds the LEAD's Agent/Task/TaskCreate/Write/Edit/
# MultiEdit/NotebookEdit until its transcript shows an advisor attempt after the
# postcompact-digest.md Read. A third battery with its own predicates, control and mutants,
# holding the producer at the real one and mutating the gate. Every DENY cell has its ALLOW twin
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
# armed BY THE GATE UNDER TEST (its two Reads), so a mutant of the arming path is scored on its own
# template. `A_TPL_GATE` records which gate built it; a mismatch rebuilds, never reuses.
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
# (recover-gate line 269, no path), so a shim `sleep` first on PATH appends a line per call and
# returns at once. No grant line, R owed, the call's own line NEVER lands, RECOVER_GATE_NET=8:
# the real gate writes 0 lines; the mutant enters the loop and writes more. The CONTROL, same shim
# and seed WITH a grant that stays on, must write >0 lines, which proves the shim is reached.
a_nogrant_run() { # a_nogrant_run <gate> <project> <counter> -> decision on stdout
  _sd="$(mktemp -d "$WORK/sleepshim.XXXXXX")"
  printf '#!/bin/bash\necho x >> "%s"\nexit 0\n' "$3" > "$_sd/sleep"; chmod +x "$_sd/sleep"
  : > "$3"
  _no="$(printf '{"tool_name":"Agent","session_id":"sess-A","transcript_path":"%s","tool_use_id":"toolu_nogrant_never","tool_input":{}}' "$2/t.jsonl" \
    | PATH="$_sd:$PATH" RECOVER_GATE_NET=8 hook_run "$1" "$2" 2>/dev/null)"
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
MR_RECLEAR="$WORK/recover-no-reclear.sh"
awk '!index($0,"rm -f \"${STATE_DIR}/.recover-advisor-owed\"")' "$HOOK" > "$MR_RECLEAR"
if cmp -s "$HOOK" "$MR_RECLEAR" || ! bash -n "$MR_RECLEAR" 2>/dev/null; then
  bad "FIXTURE STALE: the window-clear mutant did not apply"
elif [ "$(a_reclear "$MR_RECLEAR")" = PASS ]; then
  bad "MUTANT KILLED NOTHING: a producer that does not clear the advisor window still passes"
else
  ok "mutant: a producer that does not clear the advisor window fails the re-clear arm"
fi

APREDS="deny after before unavail nogrant mate nodigest bound session"
averdicts() { a_tpl "$1"; for _n in ${2:-$APREDS}; do r="$("a_$_n" "$1")"; printf '%s=%s\n' "$_n" "${r%%:*}"; done; }
aflips() { printf '%s ' $(averdicts "$1" "${2:-}" | sed -n 's/=FAIL$//p'); }

a_tpl "$GATE"
for _n in $APREDS; do
  r="$("a_$_n" "$GATE")"
  case "$_n" in
    deny)     label="R: after the digest Read with no advisor attempt, Agent and Write are refused naming R, Bash is allowed" ;;
    after)    label="R: an advisor attempt after the digest Read clears the stage" ;;
    before)   label="R: an advisor attempt BEFORE the digest Read does not satisfy it" ;;
    unavail)  label="R: an 'unavailable' advisor result stands the stage down" ;;
    nogrant)  label="R: a lead with no advisor grant line is never held" ;;
    mate)     label="R: a teammate's dispatch is untouched while the lead owes R, and the lead is still held" ;;
    nodigest) label="R: no readable postcompact digest, no stage" ;;
    bound)    label="R: the escape bound -- three refusals, then the stage stands down" ;;
    session)  label="R: another session's call is not held on this lead's touchpoint" ;;
  esac
  if [ "$r" = PASS ]; then ok "$label"; else bad "$label — ${r#FAIL:}"; fi
done

CTRL_A="$WORK/gate-control-adv.sh"
cp "$GATE" "$CTRL_A"
acf="$(aflips "$CTRL_A")"
if [ -z "${acf// /}" ]; then
  ok "control: an unmutated copy of the gate reproduces every advisor-stage verdict"
else
  bad "CONTROL FAILED — an unmutated copy already flips {${acf}}, so every advisor-stage mutant below is uninterpretable"
fi

amutant_arm() { # amutant_arm <label> <mutant> <expected flip set, in APREDS order> <twins|-> <name>
  if cmp -s "$GATE" "$2"; then bad "FIXTURE STALE: $1 — the mutant is byte-identical to the gate"; return; fi
  if ! bash -n "$2" 2>/dev/null; then bad "FIXTURE STALE: $1 — the mutant is not valid shell"; return; fi
  got="$(aflips "$2" "$(mx_sel "$APREDS" "$3" "$4")")"; mx_note "$5" "$3" "$got"
  if [ "$got" = "$3 " ]; then ok "mutant: $1 — flips exactly {$3}"
  elif [ -z "${got// /}" ]; then bad "MUTANT KILLED NOTHING: $1 — {$3} cannot fire"
  else bad "MUTANT FLIP SET WRONG: $1 — expected {$3}, measured {$got}"; fi
}
amut() { # amut <name> <awk program> -> mutant path
  awk "$2" "$GATE" > "$WORK/gate-adv-$1.sh"; printf '%s\n' "$WORK/gate-adv-$1.sh"
}
# The program is bound to a variable first: bash 3.2 cannot scan a `$(` inside single quotes inside
# "$( )", reports "bad substitution", and abandons the rest of the enclosing top-level compound --
# which silently skipped every arm from here to the end of the GATE block.
AP_NOARM='index($0,"owed_put \"$(printf"){print "          :"; next} 1'
amutant_arm "the stage never arms (the owed write removed)" \
  "$(amut noarm "$AP_NOARM")" "deny before nogrant mate bound" "after" A-noarm
amutant_arm "the teammate stand-down removed at the stage" \
  "$(amut mate 'index($0,"[ -z \"$R_AID\" ] || exit 0"){next} 1')" "mate" "deny" A-mate
amutant_arm "an advisor attempt anywhere satisfies R" \
  "$(amut order '{gsub(/"\$\{R_ADV:-0\}" -gt "\$\{R_DIG:-0\}"/,"\"${R_ADV:-0}\" -gt 0")} 1')" "before" "after" A-order
amutant_arm "the unavailable stand-down removed" \
  "$(amut unavail 'index($0,"[ \"${R_RES:--}\" = U ]; then R_V=allow"){next} 1')" "unavail" "before" A-unavail
amutant_arm "the no-grant stand-down removed" \
  "$(amut grant 'index($0,"if [ \"${R_GRANT:-none}\" != on ]; then"){next} 1')" "nogrant" "deny" A-grant
amutant_arm "the digest-readability arming precondition removed" \
  "$(amut digest '{sub(/^        if digest_readable; then$/,"        if true; then")} 1')" "nodigest" "deny" A-digest
amutant_arm "the escape bound removed" \
  "$(amut bound '{sub(/R_MAX_DENIES=3/,"R_MAX_DENIES=999")} 1')" "bound" "deny" A-bound
amutant_arm "the session stand-down removed" \
  "$(amut session 'index($0,"if [ -n \"$R_OSID\" ] && [ -n \"$R_SID\" ] && [ \"$R_OSID\" != \"$R_SID\" ]; then"){print "  if false; then"; next} 1')" "session" "deny" A-session

# =============================================================================
# WHOSE RECOVERY — an update session is not the lead, and a marker has an owner
#
# A fourth battery with its own predicates, control and mutants. ai-dlc-recover.sh used to write
# the marker for ANY session that compacted and the gate denied ANY session's calls on it, so a
# consumer-pull session (/ai-dlc-update) was handed the lead's recovery mandate -- 2 of the 78
# updater transcripts on the reference consumer, one of them with no compaction in it at all,
# denied 11 seconds in by a marker another session left. Two stand-downs close that, and they
# are SEPARATE subjects: the producer writes nothing for an updater, and the gate stands down
# (marker kept) for an updater and for a marker owned by another session.
#
# THE TWO GATE STAND-DOWNS COVER EACH OTHER on the obvious seed (a stale marker, an updater
# calling): disabling either leaves the other doing the work and the mutant comes back green.
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
sflips() { # sflips <hook> <gate> [predicates] -> the predicates that FAIL, space separated
  for _n in ${3:-$SPREDS}; do
    r="$("sp_$_n" "$1" "$2")"
    [ "${r%%:*}" = PASS ] || printf '%s ' "$_n"
  done
}

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

SCTRL_H="$WORK/recover-control-whose.sh"; SCTRL_G="$WORK/gate-control-whose.sh"
cp "$HOOK" "$SCTRL_H"; cp "$GATE" "$SCTRL_G"
scf="$(sflips "$SCTRL_H" "$SCTRL_G")"
if [ -z "${scf// /}" ]; then
  ok "control: unmutated copies of the producer and the gate reproduce all 9 whose-recovery verdicts, deny cells included"
else
  bad "CONTROL FAILED — unmutated copies already flip {${scf}}, so every whose-recovery mutant verdict below is uninterpretable"
fi

# smut <src> <anchor line, whole> <out> <replacement line> [second replacement line]
# The anchor must occur exactly once as a WHOLE LINE, or the mutation is a lost subject.
smut() {
  [ "$(grep -cxF -- "$2" "$1")" -eq 1 ] || return 1
  A="$2" R1="$4" R2="${5:-}" awk '$0==ENVIRON["A"]{print ENVIRON["R1"]; if (ENVIRON["R2"]!="") print ENVIRON["R2"]; next} 1' "$1" > "$3"
  grep -qxF -- "$4" "$3"
}
smutant_arm() { # smutant_arm <label> <hook> <gate> <expected flips in SPREDS order> <twins|-> <name>
  if [ "$2" = "$HOOK" ] && [ "$3" = "$GATE" ]; then bad "FIXTURE STALE: $1 — neither file was mutated"; return; fi
  if [ "$2" != "$HOOK" ] && cmp -s "$HOOK" "$2"; then bad "FIXTURE STALE: $1 — the producer mutant is byte-identical"; return; fi
  if [ "$3" != "$GATE" ] && cmp -s "$GATE" "$3"; then bad "FIXTURE STALE: $1 — the gate mutant is byte-identical"; return; fi
  if ! bash -n "$2" 2>/dev/null || ! bash -n "$3" 2>/dev/null; then bad "FIXTURE STALE: $1 — a mutant is not valid shell, and its silence would score as a kill"; return; fi
  got="$(sflips "$2" "$3" "$(mx_sel "$SPREDS" "$4" "$5")")"; mx_note "$6" "$4" "$got"
  if [ "$got" = "$4 " ]; then ok "mutant: $1 — flips exactly {$4}"
  elif [ -z "${got// /}" ]; then bad "MUTANT KILLED NOTHING: $1 — every whose-recovery arm stays green, so {$4} cannot fire"
  else bad "MUTANT FLIP SET WRONG: $1 — expected {$4}, measured {$got}; the arms are entangled or one of them is vacuous"; fi
}
UPD_CASE='    *'"'"'/ai-dlc-update</command-name>'"'"'|*'"'"'"skill":"ai-dlc-update"'"'"') exit 0 ;;'
UPD_NEVER='    *'"'"'NEVER-MATCHES-X'"'"') exit 0 ;;'
UPD_RM='    *'"'"'/ai-dlc-update</command-name>'"'"'|*'"'"'"skill":"ai-dlc-update"'"'"') rm -f "$MARKER" "$PROGRESS" 2>/dev/null; exit 0 ;;'
KEY_LINE='if [ -n "$M_SID" ] && [ -n "$G_SID" ] && [ "$M_SID" != "$G_SID" ]; then'
KEY_RM='  rm -f "$MARKER" "$PROGRESS" 2>/dev/null || true'

# (a) The producer's updater stand-down removed. Killed by upd_compact ALONE: the marker appears.
# The gate's own updater test still stands down on that update session, so the Bash call stays
# silent -- the only observable is the marker, which is why C1 asserts it before the call.
SM_A="$WORK/recover-whose-a.sh"
if smut "$HOOK" "$UPD_CASE" "$SM_A" "$UPD_NEVER"; then
  smutant_arm "the producer writes a marker for an update session" "$SM_A" "$GATE" "upd_compact" "pipe_compact" W-a
else bad "FIXTURE STALE: the producer's updater stand-down is not exactly one whole line, so mutant (a) has no subject"; fi

# (b) The gate's updater stand-down removed. Killed by legacy_upd and ord_upd: an ownerless marker leaves
# the owner test nothing to compare, so only the updater test can stand down there. stale_upd stays
# green because the owner test covers it, which is exactly why legacy_upd exists.
SM_B="$WORK/gate-whose-b.sh"
if smut "$GATE" "$UPD_CASE" "$SM_B" "$UPD_NEVER"; then
  smutant_arm "the gate has no updater stand-down" "$HOOK" "$SM_B" "legacy_upd ord_upd" "stale_upd legacy_pipe" W-b
else bad "FIXTURE STALE: the gate's updater stand-down is not exactly one whole line, so mutant (b) has no subject"; fi

# (c) The owner test removed. Killed by stale_pipe and ord_pipe: a pipeline session has no updater test to
# fall back on. stale_upd stays green because the updater test covers it.
SM_C="$WORK/gate-whose-c.sh"
if smut "$GATE" "$KEY_LINE" "$SM_C" "if false; then"; then
  smutant_arm "the gate does not compare the marker's session_id with the call's" "$HOOK" "$SM_C" "stale_pipe ord_pipe" "stale_upd same_sess" W-c
else bad "FIXTURE STALE: the owner test is not exactly one whole line, so mutant (c) has no subject"; fi

# (d) Both stand-downs delete the marker before exiting. Killed by the five cells that assert the
# marker SURVIVES a stand-down: stale_upd and stale_pipe through the owner branch, legacy_upd through
# the updater branch, and ord_pipe and ord_upd the same two ways with the snapshot gone. No deny cell
# flips: the denied calls never reach either branch.
SM_D="$WORK/gate-whose-d.sh"; SM_D1="$WORK/gate-whose-d1.sh"
if smut "$GATE" "$KEY_LINE" "$SM_D1" "$KEY_LINE" "$KEY_RM" && smut "$SM_D1" "$UPD_CASE" "$SM_D" "$UPD_RM"; then
  smutant_arm "a stand-down deletes the marker it stood down on" "$HOOK" "$SM_D" "stale_upd stale_pipe legacy_upd ord_pipe ord_upd" "same_sess pipe_compact" W-d
else bad "FIXTURE STALE: mutant (d) could not be built from exactly one owner-test line and one updater-case line"; fi

# (e) BOTH stand-downs moved BELOW the readability block, before the tool-name parse that follows it.
# Nothing else changes, so every case where the snapshot is present behaves identically (the
# readability block is not entered). Killed by exactly ord_pipe and ord_upd: with the snapshot gone
# the readability block deletes the marker and exits silent first, so the call is silent but the
# marker is not kept. The block is relocated whole, so the order is the only difference.
SM_E="$WORK/gate-whose-e.sh"
awk '
  index($0, "G_SID=\"\"; G_TP=\"\"") == 1 { cap = 1 }
  cap { buf = buf $0 "\n"; if ($0 == "  esac") e = 1; if (e && $0 == "fi") { cap = 0; e = 0; held = 1 } next }
  index($0, "TOOL=\"$(printf '"'"'%s'"'"' \"$INPUT\" | jq -r '"'"'.tool_name // empty'"'"'") == 1 && held && !done { printf "%s", buf; done = 1 }
  1' "$GATE" > "$SM_E"
_e_at="$(grep -n 'G_SID=""; G_TP=""' "$SM_E" | head -1 | cut -d: -f1)"
_e_rd="$(grep -n 'if \[ ! -r "\$SNAP_ABS" \]' "$SM_E" | head -1 | cut -d: -f1)"
if [ -z "$_e_at" ] || [ -z "$_e_rd" ] || [ "$_e_at" -le "$_e_rd" ] || [ "$(wc -l < "$SM_E")" -ne "$(wc -l < "$GATE")" ]; then
  bad "FIXTURE STALE: mutant (e) did not relocate the stand-downs below the readability block (stand-down at line '${_e_at}', readability at '${_e_rd}')"
else
  smutant_arm "both stand-downs sit BELOW the readability block that deletes the marker" "$HOOK" "$SM_E" "ord_pipe ord_upd" "stale_pipe stale_upd" W-e
fi

fi  # whose-recovery arms present

# A10. THE NET IS NOT A DENY (BL-630). R owed, and the incoming call's own `tool_use` line NEVER
# lands (acall always appends it, so no predicate above can reach this branch): the safety net
# expires with R_SEEN=0, a transcript the stage cannot read. It must ALLOW, say why on stderr, and
# not count a refusal -- `denies=` unchanged. The pre-BL-630 gate denied here, so a correct advisor
# call whose line was merely late (load makes it later) was refused. Outside APREDS on purpose:
# it pays the net by construction, once for the gate and once for its mutant, so it runs with
# RECOVER_GATE_NET=2 (BL-730: the knob only shortens the 300s default) and greps a net-agnostic
# stderr reason.
a_net() {
  _p="$(a_world "$1" grant boundary digest)"
  [ -e "$_p/$OW" ] || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: the advisor stage did not arm\n'; return; }
  _d0="$(sed -n 's/^denies=//p' "$_p/$OW")"
  _e="$_p/net.err"
  d="$(printf '{"tool_name":"Agent","session_id":"sess-A","transcript_path":"%s","tool_use_id":"tin-never","tool_input":{}}' "$_p/t.jsonl" \
    | RECOVER_GATE_NET=2 hook_run "$1" "$_p" 2>"$_e")"
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
MR_NET="$WORK/gate-adv-net.sh"
awk 'index($0,"if [ \"${R_SEEN:-0}\" != 1 ]; then"){print "  if false; then"; next} 1' "$GATE" > "$MR_NET"
if cmp -s "$GATE" "$MR_NET" || ! bash -n "$MR_NET" 2>/dev/null; then
  bad "FIXTURE STALE: the time-only-ceiling mutant did not apply"
elif [ "$(a_net "$MR_NET")" = PASS ]; then
  bad "MUTANT KILLED NOTHING: a gate whose clock denies an unseen call still passes the net arm"
else
  ok "mutant: a gate whose net ceiling denies an unseen call fails the net arm"
fi

# =============================================================================
# ONE DECISION PER MESSAGE, AND A WAIT THAT OUTLASTS THE FLUSH (BL-730)
#
# Measured on graph transcript a367e62c: one message carried 19 Agent calls, the harness ran each
# call's PreToolUse as its block finished streaming (~7s apart, overlapping), and the message's
# lines reached disk together at message end. Calls 1-17 hit the old 10s net and were dispatched
# uncounted; calls 18 and 19, each still pending at the flush around 05:57:24, were refused. The
# gate now waits up to R_NET (300s) for the call's own line and counts one refusal per message.
#
# Four predicates with their own control and mutants. They run in the BACKGROUND, every predicate
# of every gate at once, because `rflush` waits 16s by construction and `rflush_ctl` waits out two
# short nets; serially the battery would pay that wall clock once per gate. Each child's pid is
# recorded and `wait`ed, and each writes its verdict to a file named for the predicate.
# =============================================================================

# rcall <gate> <project> <tool_use_id> <net> [stderr file] -> deny | empty, for an Agent call
rcall() {
  _rco="$(printf '{"tool_name":"Agent","session_id":"sess-A","transcript_path":"%s","tool_use_id":"%s","tool_input":{}}' "$2/t.jsonl" "$3" \
    | RECOVER_GATE_NET="$4" hook_run "$1" "$2" 2>"${5:-/dev/null}")"
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
# starts; a background writer appends it at 16s, past the old 10s net and inside RECOVER_GATE_NET=30.
# KEEP THE WRITER-VERSUS-NET10 WINDOW ABOVE THE POOL'S JITTER; do not shrink it again. The net10
# mutant's loop ends at 10s and the writer lands at 16s. The 6s margin is chosen against an
# UNMEASURED hook start-up and fork overhead under pool load, estimated at ~1s, which was the margin
# when the writer sat at 11s. No jitter figure has been measured.
# A gate that judges once at its start, or whose net is 10s, lets the call through uncounted.
a_rflush() {
  _p="$(a_world "$1" grant boundary digest)"
  [ -e "$_p/$OW" ] || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: the advisor stage did not arm\n'; return; }
  ( sleep 16; mline M-late toolu_rflush_late >> "$_p/t.jsonl" ) &
  _wp=$!
  _t0=$SECONDS
  d="$(rcall "$1" "$_p" toolu_rflush_late 30)"
  _el=$((SECONDS - _t0))
  wait "$_wp" || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: the background writer failed\n'; return; }
  grep -qF toolu_rflush_late "$_p/t.jsonl" || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: the late line never landed\n'; return; }
  [ "$d" = deny ] || { printf 'FAIL:a call whose own line landed at 16s while its hook still waited was let through (the hook answered after %ss)\n' "$_el"; return; }
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

# R3. A GRANT WITHDRAWN DURING THE WAIT: the call's own line lands at about 3s together with an
# `advisor_tool` attachment carrying available:false, toolChange:"remove". The hook must allow and
# the owed file must be gone; a gate that tests the grant only before the wait denies.
a_rwithdraw() {
  _p="$(a_world "$1" grant boundary digest)"
  [ -e "$_p/$OW" ] || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: the advisor stage did not arm\n'; return; }
  ( sleep 3; mline M-wd toolu_rwd_late >> "$_p/t.jsonl"; printf '{"type":"attachment","attachment":{"type":"advisor_tool","available":false,"toolChange":"remove"}}\n' >> "$_p/t.jsonl" ) &
  _wp=$!
  d="$(rcall "$1" "$_p" toolu_rwd_late 30)"
  wait "$_wp" || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: the background writer failed\n'; return; }
  grep -qF toolu_rwd_late "$_p/t.jsonl" || { printf 'FAIL:SEED CANNOT EXPRESS THE CASE: the call line never landed\n'; return; }
  [ "$d" = deny ] && { printf 'FAIL:a call whose grant was withdrawn during the wait was denied\n'; return; }
  [ -e "$_p/$OW" ] && { printf 'FAIL:the withdrawn grant left the owed file in place\n'; return; }
  printf 'PASS\n'
}

R7PREDS="rmsg rmsg_ctl rflush rflush_ctl rwithdraw"
r7_launch() { # r7_launch <gate> <outdir> [predicates] -- each predicate in the background, pids recorded
  a_tpl "$1"; mkdir -p "$2"; : > "$2/pids"; printf '%s\n' "${3:-$R7PREDS}" > "$2/preds"
  for _n in ${3:-$R7PREDS}; do
    ( r="$("a_$_n" "$1")"; printf '%s\n' "$r" > "$2/$_n" ) &
    printf '%s\n' "$!" >> "$2/pids"
  done
}
r7_wait() { while read -r _wp; do wait "$_wp"; done < "$1/pids"; } # r7_wait <outdir>
r7_flips() { # r7_flips <outdir> -> the predicates that ran there and did not PASS, space separated
  for _n in $(cat "$1/preds" 2>/dev/null); do
    r="$(cat "$1/$_n" 2>/dev/null)"
    [ "${r%%:*}" = PASS ] || printf '%s ' "$_n"
  done
}
r7mut() { # r7mut <name> <awk program> -> mutant path
  awk "$2" "$GATE" > "$WORK/gate-730-$1.sh"; printf '%s\n' "$WORK/gate-730-$1.sh"
}
# M-730-net10: the default net back to 10s and the knob ignored. M-730-noreread: the wait loop
# removed, so the verdict comes from the scan taken at the hook's start -- a gate that never reads
# again, which is what a harness that writes the line only after the hook returns would see.
# With no re-read the withdrawal is never seen, so M-730-noreread flips {rflush rwithdraw}: the
# grant is refreshed only inside the loop it removes.
# M-730-count: the denied_msg comparison removed, so every call counts.
# Programs bound to variables first, as AP_NOARM is: bash 3.2 cannot scan a `$(` inside single
# quotes inside "$( )".
R7P_NET10='$0=="  R_NET=300"{print "  R_NET=10"; next} index($0,"R_NET=$((10#$RECOVER_GATE_NET))"){print "    *) : ;;"; next} 1'
R7P_NORR='index($0,"  while [ \"$R_V\" = owed ] && [ \"${R_SEEN:-0}\" != 1 ]")==1{skip=1} skip{if($0=="  done")skip=0; next} 1'
R7P_COUNT='index($0,"if [ \"${R_MID:--}\" != - ] && [ \"$R_MID\" = \"$R_DMSG\" ]; then"){print "  if false; then"; next} 1'
R7_NET10="$(r7mut net10 "$R7P_NET10")"
R7_NORR="$(r7mut noreread "$R7P_NORR")"
R7P_GRANT='index($0,"[ \"${R_GRANT:-none}\" = on ] || { rm -f")==3{next} 1'
R7_GRANT="$(r7mut grant "$R7P_GRANT")"
R7_COUNT="$(r7mut count "$R7P_COUNT")"
R7_CTRL="$WORK/gate-control-730.sh"; cp "$GATE" "$R7_CTRL"

r7_launch "$GATE" "$WORK/r7-gate"
r7_launch "$R7_CTRL" "$WORK/r7-ctrl"
# Each mutant runs only the predicates it decides plus its twins (all of them under --matrix).
r7_launch "$R7_NET10" "$WORK/r7-net10" "$(mx_sel "$R7PREDS" rflush rflush_ctl)"
r7_launch "$R7_NORR" "$WORK/r7-noreread" "$(mx_sel "$R7PREDS" "rflush rwithdraw" rmsg)"
r7_launch "$R7_COUNT" "$WORK/r7-count" "$(mx_sel "$R7PREDS" rmsg rmsg_ctl)"
r7_launch "$R7_GRANT" "$WORK/r7-grant" "$(mx_sel "$R7PREDS" rwithdraw rflush_ctl)"
for _o in gate ctrl net10 noreread count grant; do r7_wait "$WORK/r7-$_o"; done

for _n in $R7PREDS; do
  r="$(cat "$WORK/r7-gate/$_n" 2>/dev/null)"
  case "$_n" in
    rmsg)       label="R (BL-730): two calls of one message are both refused and the message counts once (a_rmsg)" ;;
    rmsg_ctl)   label="R (BL-730): CONTROL -- a second message counts again, 1 then 2 (a_rmsg_ctl)" ;;
    rflush)     label="R (BL-730): a hook still pending when its own line lands at 16s DENIES, counted once (a_rflush)" ;;
    rwithdraw)  label="R (BL-730): a grant withdrawn during the wait allows the call and removes the owed file (a_rwithdraw)" ;;
    rflush_ctl) label="R (BL-730): CONTROL -- a line that never lands is silent and uncounted, and a second expiry stands the stage down (a_rflush_ctl)" ;;
  esac
  if [ "$r" = PASS ]; then ok "$label"; else bad "$label — ${r#FAIL:}"; fi
done
r7cf="$(r7_flips "$WORK/r7-ctrl")"
if [ -z "${r7cf// /}" ]; then
  ok "control: an unmutated copy of the gate reproduces every BL-730 verdict"
else
  bad "CONTROL FAILED — an unmutated copy already flips {${r7cf}}, so every BL-730 mutant below is uninterpretable"
fi
r7mutant_arm() { # r7mutant_arm <label> <mutant> <outdir> <expected flip set, in R7PREDS order>
  if cmp -s "$GATE" "$2"; then bad "FIXTURE STALE: $1 — the mutant is byte-identical to the gate"; return; fi
  if ! bash -n "$2" 2>/dev/null; then bad "FIXTURE STALE: $1 — the mutant is not valid shell"; return; fi
  got="$(r7_flips "$3")"; mx_note "$5" "$4" "$got"
  if [ "$got" = "$4 " ]; then ok "mutant: $1 — flips exactly {$4}"
  elif [ -z "${got// /}" ]; then bad "MUTANT KILLED NOTHING: $1 — {$4} cannot fire"
  else bad "MUTANT FLIP SET WRONG: $1 — expected {$4}, measured {$got}"; fi
}
if grep -qxF '  R_NET=10' "$R7_NET10" && ! grep -qF '10#$RECOVER_GATE_NET' "$R7_NET10"; then
  r7mutant_arm "M-730-net10: the net back to 10s, the knob ignored" "$R7_NET10" "$WORK/r7-net10" "rflush" M-730-net10
else bad "FIXTURE STALE: M-730-net10 did not replace both the default net and the knob"; fi
if ! grep -qF 'while [ "$R_V" = owed ]' "$R7_NORR"; then
  r7mutant_arm "M-730-noreread: the wait loop removed, judged once at the hook's start" "$R7_NORR" "$WORK/r7-noreread" "rflush rwithdraw" M-730-noreread
else bad "FIXTURE STALE: M-730-noreread did not remove the wait loop"; fi
r7mutant_arm "M-730-count: the denied_msg comparison removed, every call counts" "$R7_COUNT" "$WORK/r7-count" "rmsg" M-730-count
r7mutant_arm "M-730-grant: the post-wait grant check removed" "$R7_GRANT" "$WORK/r7-grant" "rwithdraw" M-730-grant

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
# OUTSIDE PREDS ON PURPOSE. Every mutant above is re-scored on every PREDS member, and most of
# them cannot carry the injection (the dead gate has no line to anchor on), so a race predicate
# there would fail for a reason that has nothing to do with the race.
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
RACE_WRONG='[ -f "$PROGRESS" ] || exit 0'
RACE_LINE='rm -f "$MARKER" "$PROGRESS" 2>/dev/null; : > "${STATE_DIR}/.race-injected"'
RACE_SENT="_bmad-output/.race-injected"
# What directly follows the stage read: yes (the re-test), no, or none (no stage read at all).
RACE_AT='prev == ENVIRON["S"] { print (($0 == ENVIRON["R"]) ? "yes" : "no"); f = 1; exit } { prev = $0 } END { if (!f) print "none" }'
# The two lines directly above the stage read, joined by a bar.
RACE_ABOVE='$0 == ENVIRON["S"] { print p2 "|" p1; exit } { p2 = p1; p1 = $0 }'
RACE_AFTER='{ print } $0 == ENVIRON["A"] { print ENVIRON["L"] }'
RACE_BEFORE='$0 == ENVIRON["A"] { print ENVIRON["L"] } { print }'
RACE_DROP='prev == ENVIRON["A"] && $0 == ENVIRON["L"] { prev = $0; next } { print; prev = $0 }'
RACE_SWAP='prev == ENVIRON["A"] && $0 == ENVIRON["L"] { print ENVIRON["W"]; prev = $0; next } { print; prev = $0 }'

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
RD_IN="$(race_dir)"; RD_CTL="$(race_dir)"; RD_PRE="$(race_dir)"
RD_M1="$(race_dir)"; RD_M2="$(race_dir)"; RD_M3="$(race_dir)"
if [ -z "$RD_IN" ] || [ -z "$RD_CTL" ] || [ -z "$RD_PRE" ] || [ -z "$RD_M1" ] || [ -z "$RD_M2" ] || [ -z "$RD_M3" ]; then
  bad "FIXTURE BROKEN: a whole-directory copy of the hooks did not carry every sibling, so no race variant below is evidence"
else
  # The shipped gate, the removal injected directly after the call-path normalisation.
  race_edit "$GATE" "$RD_IN/$RG" "$RACE_AFTER" "$RACE_FABS" "$RACE_LINE" \
    && [ "$(S="$RACE_STAGE" R="$RACE_RETEST" awk "$RACE_AT" "$RD_IN/$RG")" = yes ] || RD_IN=""
  # M2 twin: the shipped gate, the removal injected directly above the stage read.
  race_edit "$GATE" "$RD_PRE/$RG" "$RACE_BEFORE" "$RACE_STAGE" "$RACE_LINE" \
    && [ "$(S="$RACE_STAGE" awk "$RACE_ABOVE" "$RD_PRE/$RG" | sed 's/^.*|//')" = "$RACE_LINE" ] || RD_PRE=""
  # M1: the re-test removed, then the same injection as RD_IN.
  race_edit "$GATE" "$RD_M1/m.step1" "$RACE_DROP" "$RACE_STAGE" "$RACE_RETEST" \
    && race_edit "$RD_M1/m.step1" "$RD_M1/$RG" "$RACE_AFTER" "$RACE_FABS" "$RACE_LINE" \
    && [ "$(S="$RACE_STAGE" R="$RACE_RETEST" awk "$RACE_AT" "$RD_M1/$RG")" = no ] || RD_M1=""
  # M2: the re-test moved directly ABOVE the stage read, and the removal injected between the two.
  race_edit "$GATE" "$RD_M2/m.step1" "$RACE_DROP" "$RACE_STAGE" "$RACE_RETEST" \
    && race_edit "$RD_M2/m.step1" "$RD_M2/m.step2" "$RACE_BEFORE" "$RACE_STAGE" "$RACE_RETEST" \
    && race_edit "$RD_M2/m.step2" "$RD_M2/$RG" "$RACE_BEFORE" "$RACE_STAGE" "$RACE_LINE" \
    && [ "$(S="$RACE_STAGE" awk "$RACE_ABOVE" "$RD_M2/$RG")" = "${RACE_RETEST}|${RACE_LINE}" ] \
    && [ "$(S="$RACE_STAGE" R="$RACE_RETEST" awk "$RACE_AT" "$RD_M2/$RG")" = no ] || RD_M2=""
  # M3: the re-test keyed on the progress file instead of the marker. No injection: its subject is R2.
  race_edit "$GATE" "$RD_M3/$RG" "$RACE_SWAP" "$RACE_STAGE" "$RACE_RETEST" "$RACE_WRONG" \
    && [ "$(S="$RACE_STAGE" R="$RACE_WRONG" awk "$RACE_AT" "$RD_M3/$RG")" = yes ] || RD_M3=""
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

  # M1, the pre-fix gate: R1 flips to the stage-one deny, the injection still ran, R2 holds.
  if [ -z "$RD_M1" ]; then bad "FIXTURE STALE: M1 — the re-test could not be removed from directly after the stage read"
  else
    _rp="$(race_world "$RD_M1/$RG")"; _rv="$(race_read "$_rp")"; _r2="$(race_read "$(race_first "$RD_M1/$RG")")"
    if [ "$_rv" = first ] && race_ran "$_rp" && [ "$_r2" = first ]; then ok "mutant: re-test removed — the raced third Read is refused with the stage-one text, and only R1 flips"
    else bad "mutant: re-test removed — expected R1 'first' with the injection run and R2 'first', measured R1 '${_rv}' R2 '${_r2}'"; fi
  fi
  # M2: the re-test above the stage read leaves the window open. Its twin, the shipped gate with
  # the removal at the same point, still allows.
  if [ -z "$RD_M2" ] || [ -z "$RD_PRE" ]; then bad "FIXTURE STALE: M2 — the misplaced re-test or its twin could not be built around the stage read"
  else
    _rp="$(race_world "$RD_M2/$RG")"; _rv="$(race_read "$_rp")"; _r2="$(race_read "$(race_first "$RD_M2/$RG")")"
    _tp="$(race_world "$RD_PRE/$RG")"; _tv="$(race_read "$_tp")"
    if [ "$_rv" = first ] && race_ran "$_rp" && [ "$_r2" = first ] && [ "$_tv" = allow ] && race_ran "$_tp"; then
      ok "mutant: re-test placed BEFORE the stage read — the removal between them is refused with the stage-one text, while the shipped gate allows at the same point"
    else bad "mutant: re-test placed BEFORE the stage read — expected 'first' against a twin 'allow', measured '${_rv}' (R2 '${_r2}') against twin '${_tv}'"; fi
  fi
  # M3: the re-test keyed on the progress file. R1 still allows; R2 is waved through.
  if [ -z "$RD_M3" ]; then bad "FIXTURE STALE: M3 — the re-test could not be rekeyed on the progress file"
  else
    _rv="$(race_read "$(race_first "$RD_M3/$RG")")"
    _r1="$(race_read "$(race_world "$RD_M3/$RG")")"
    if [ "$_rv" = allow ] && [ "$_r1" = second ]; then ok "mutant: re-test keyed on the progress file — the genuine first call is waved through, and only R2 flips"
    else bad "mutant: re-test keyed on the progress file — expected R2 'allow' and the uninjected world 'second', measured R2 '${_rv}' world '${_r1}'"; fi
  fi

  # THE REMOVAL ORDER (BL-658). The fix holds only because the satisfying Read removes the MARKER
  # before the PROGRESS file: a concurrent call that sees the marker gone exits at the re-test, one
  # that sees the progress file gone but the marker present would take the default stage. Every
  # injection above supplies its OWN removal, so nothing above binds the shipped line's operand
  # order. This arm reads the line itself, whole-line and exact, and the mutant swaps its operands
  # in a copy of the whole hooks directory.
  RACE_RM='        rm -f "$MARKER" "$PROGRESS" 2>/dev/null || true'
  RACE_RMSW='        rm -f "$PROGRESS" "$MARKER" 2>/dev/null || true'
  RACE_RMNONE='        rm -f "$MARKER" "$PROGRESS" 2>/dev/null || true # impossible-anchor-bl658-zz'
  RACE_REPL='$0 == ENVIRON["A"] { print ENVIRON["W"]; next } { print }'
  race_rm_order() { printf '%s|%s\n' "$(grep -cxF -- "$RACE_RM" "$1")" "$(grep -cxF -- "$RACE_RMSW" "$1")"; }
  _ro="$(race_rm_order "$GATE")"; _rc="$(grep -cxF -- "$RACE_RMNONE" "$GATE")"
  if [ "$_ro" = "1|0" ] && [ "$_rc" = 0 ]; then
    ok "race order: the satisfying Read removes the marker BEFORE the progress file (exact line 1, swapped spelling 0, impossible-anchor control 0)"
  else bad "race order: expected exact line 1 and swapped spelling 0 with control 0, measured ${_ro} with control '${_rc}' in ${GATE}"; fi
  RD_M4="$(race_dir)"
  if [ -z "$RD_M4" ]; then bad "FIXTURE BROKEN: a whole-directory copy of the hooks did not carry every sibling, so the order mutant below is not evidence"
  else
    race_edit "$GATE" "$RD_M4/$RG" "$RACE_REPL" "$RACE_RM" "" "$RACE_RMSW" \
      && [ "$(race_rm_order "$RD_M4/$RG")" = "0|1" ] || RD_M4=""
    if [ -z "$RD_M4" ]; then bad "FIXTURE STALE: M4 — the removal operands could not be swapped on the whole-line anchor"
    else
      _mo="$(race_rm_order "$RD_M4/$RG")"
      if [ "$_mo" = "0|1" ] && [ "$_mo" != "$_ro" ]; then ok "mutant: removal operands swapped (progress file first) — the order arm reports exact 0 and swapped 1 against 1 and 0 unmutated"
      else bad "mutant: removal operands swapped — the order arm measured ${_mo} against ${_ro} unmutated, so it cannot tell the order"; fi
    fi
  fi
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
  # when it is absent. Each mutant is a whole-hooks-directory copy, asserted APPLIED by `cmp`, and
  # scored by its exact flip set over its own block's predicates only. The digest-allow mutants
  # use a block-scoped awk, because the allow's first line appears once per stage arm and
  # `race_edit` refuses an anchor that is not one unique whole line; the stage-write and clear
  # mutants go through `race_edit`.
  # ===========================================================================
  RC_DIGREL=".claude/skills/ai-dlc/postcompact-digest.md"
  RC_DIGKEY='"$FABS" = "${PROJECT_DIR}/.claude/skills/ai-dlc/postcompact-digest.md"'
  RC_DIGKEY2='"$FABS" = "${PROJECT_DIR}/core/skills/ai-dlc/postcompact-digest.md"'
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
  # presence-shaped half, and the unmutated control requires both.
  rp_s_killed() {
    _rq="$(rc_proj "$1" first)"; [ -n "$_rq" ] || { echo 'FAIL:SEED — no stage-one world formed'; return; }
    printf 'snapshot\n' > "$_rq/$pg"
    _rj="$(jcall Read "$_rq/_bmad-output/pipeline-snapshot.md")"
    ( ulimit -f 0; gate_call "$1/$RG" "$_rq" "$_rj" >/dev/null ) 2>/dev/null
    [ "$(cat "$_rq/$pg" 2>/dev/null)" = snapshot ] || { echo "FAIL:a killed stage write left the stage reading '$(cat "$_rq/$pg" 2>/dev/null)'"; return; }
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
  rp_r_owed() { # a new recovery clears an owed-file temp left by a killed owed_put
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
      s_killed)  echo "BL-666: a stage write killed by ulimit -f 0 leaves the stage reading snapshot" ;;
      s_garbage) echo "BL-666 control: a garbage stage is allowed through and the file removed" ;;
      s_struct)  echo "BL-666 structural: the stage write's temp is spelled from \${PROGRESS}, carries \$\$, and is renamed onto \$PROGRESS" ;;
      r_clear)   echo "BL-684: a new recovery clears the previous stage and its temp, and a first-call decoy Read gets the FIRST deny" ;;
      r_owed)    echo "BL-730: a new recovery clears an owed-file temp (.recover-advisor-owed.<pid>) left by a killed write" ;;
      r_ctl)     echo "BL-684 control: on a fresh recovery the same decoy Read gets the FIRST deny" ;;
    esac
  }
  rc_arms() { for _ra in $1; do _rr="$("rp_$_ra" "$RC_REAL")"; if [ "$_rr" = PASS ]; then ok "$(rc_label "$_ra")"; else bad "$(rc_label "$_ra") — ${_rr#FAIL:}"; fi; done; }
  rc_flips() { for _ra in $2; do _rr="$("rp_$_ra" "$1")"; [ "$_rr" = PASS ] || printf '%s ' "$_ra"; done; }
  rc_control() { # rc_control <preds> <block> -- an unmutated whole-directory copy reproduces every verdict
    _rd="$(race_dir)"
    if [ -z "$_rd" ]; then bad "FIXTURE BROKEN: $2 — a whole-directory copy of the hooks did not carry every sibling"; return; fi
    _rg="$(rc_flips "$_rd" "$1")"
    if [ -z "${_rg// /}" ]; then ok "control: $2 — an unmutated whole-directory copy passes every arm, so a flip below is its mutation"
    else bad "CONTROL FAILED: $2 — an unmutated copy already flips {${_rg}}, so no mutant verdict below is evidence"; fi
  }
  rc_score() { # rc_score <label> <dir> <file> <preds> <expected flips>
    if [ -z "$2" ]; then bad "FIXTURE STALE: $1 — the mutation did not apply to its anchor"; return; fi
    if cmp -s "$RC_REAL/$3" "$2/$3"; then bad "FIXTURE STALE: $1 — the mutant is byte-identical to $3, so it was not applied"; return; fi
    bash -n "$2/$3" 2>/dev/null || { bad "FIXTURE STALE: $1 — the mutant is not valid shell"; return; }
    # Twin: the first predicate of the block this mutant does NOT decide (the same-world control).
    _rtw="-"; for _rx in $4; do case " $5 " in *" $_rx "*) ;; *) _rtw="$_rx"; break ;; esac; done
    _rnm="${1%%:*}"; _rnm="$(printf '%s' "$_rnm" | tr -c 'A-Za-z0-9_+-' '_')"
    _rg="$(rc_flips "$2" "$(mx_sel "$4" "$5" "$_rtw")")"; mx_note "$_rnm" "$5" "$_rg"
    if [ "$_rg" = "$5 " ]; then ok "mutant: $1 — applied (cmp differs), killed by exactly {$5}"
    elif [ -z "${_rg// /}" ]; then bad "MUTANT SURVIVED: $1 — every arm stays green, so {$5} cannot fire"
    else bad "MUTANT FLIP SET WRONG: $1 — expected {$5}, measured {${_rg}}"; fi
  }

  # --- BL-658: the digest allow -------------------------------------------------
  # Detection key: a line carrying RC_DIGKEY, the FABS comparison against the installed digest path.
  _rk="$(grep -cF -- "$RC_DIGKEY" "$GATE")" || _rk=0
  if [ "$_rk" -lt 1 ]; then
    skip "BL-658 digest-allow arms" "the gate carries no full-Read allow comparing FABS to the digest path (key '${RC_DIGKEY}', found 0); this fixture ships one pull ahead of its subject"
  else
    RC_P658="d_step d_first d_decoy d_base d_bounded"
    rc_arms "$RC_P658"
    rc_control "$RC_P658" "BL-658 digest allow"
    # The block-scoped edit: a digest block is a stage-arm `if [ "$TOOL" = "Read" ]` block, closed
    # by its four-space `fi`, whose text names the digest. M picks the edit.
    RC_DIGAWK='
function lrep(s, a, b,   i, o) { o = ""; while ((i = index(s, a)) > 0) { o = o substr(s, 1, i - 1) b; s = substr(s, i + length(a)) } return o s }
function flush(   i, d, ln) {
  d = (index(buf, "postcompact-digest.md") > 0)
  if (d) n++
  if (d && (M == "drop" || (M == "drop1" && n == 1))) { nl = 0; buf = ""; inb = 0; return }
  if (d && M == "widen" && n == 2) print "    if [ \"$TOOL\" = \"Read\" ]; then exit 0; fi"
  for (i = 1; i <= nl; i++) {
    ln = L[i]
    if (d && M == "base") { ln = lrep(ln, ENVIRON["K1"], ENVIRON["KB"]); ln = lrep(ln, ENVIRON["K2"], ENVIRON["KB"]) }
    if (d && M == "nofull") ln = lrep(ln, " && is_full_read", "")
    if (d && M == "adv" && ln == "      exit 0") ln = "      " ENVIRON["X"] "; exit 0"
    print ln
  }
  nl = 0; buf = ""; inb = 0
}
BEGIN { M = ENVIRON["M"] }
inb { L[++nl] = $0; buf = buf $0 "\n"; if ($0 == "    fi") flush(); next }
/^    if \[ "\$TOOL" = "Read" \]/ { inb = 1; nl = 0; L[++nl] = $0; buf = $0 "\n"; next }
{ print }
END { if (inb) flush() }
'
    RC_KB='"${FABS##*/}" = "postcompact-digest.md"'
    rc_dig() { # rc_dig <mode> [X] -> a whole-directory copy with the gate edited, or empty
      _rd="$(race_dir)"; [ -n "$_rd" ] || return 0
      M="$1" X="${2:-}" K1="$RC_DIGKEY" K2="$RC_DIGKEY2" KB="$RC_KB" awk "$RC_DIGAWK" "$RC_REAL/$RG" > "$_rd/$RG" || return 0
      printf '%s\n' "$_rd"
    }
    rc_n() { _rc="$(grep -cF -- "$1" "$2")" || _rc=0; printf '%s' "$_rc"; }
    _rn0="$(rc_n "$RC_DIGKEY" "$RC_REAL/$RG")"
    _rd="$(rc_dig drop)"; [ -n "$_rd" ] && [ "$(rc_n "$RC_DIGKEY" "$_rd/$RG")" = 0 ] || _rd=""
    rc_score "M5-drop: the digest allow removed from both stage arms" "$_rd" "$RG" "$RC_P658" "d_step d_first"
    _rd="$(rc_dig widen)"; [ -n "$_rd" ] && [ "$(rc_n 'if [ "$TOOL" = "Read" ]; then exit 0; fi' "$_rd/$RG")" = 1 ] || _rd=""
    rc_score "M6-widen: any Read allowed at stage step" "$_rd" "$RG" "$RC_P658" "d_decoy d_base d_bounded"
    _rd="$(rc_dig adv 'echo step >"$PROGRESS"')"; [ -n "$_rd" ] && [ "$(rc_n 'echo step >"$PROGRESS"; exit 0' "$_rd/$RG")" = "$_rn0" ] || _rd=""
    rc_score "M7-advance (stage): the digest allow also writes the stage" "$_rd" "$RG" "$RC_P658" "d_first"
    _rd="$(rc_dig adv 'rm -f "$MARKER"')"; [ -n "$_rd" ] && [ "$(rc_n 'rm -f "$MARKER"; exit 0' "$_rd/$RG")" = "$_rn0" ] || _rd=""
    rc_score "M7-advance (marker): the digest allow also clears the marker" "$_rd" "$RG" "$RC_P658" "d_step d_first"
    _rd="$(rc_dig adv ': >"$OWED"')"; [ -n "$_rd" ] && [ "$(rc_n ': >"$OWED"; exit 0' "$_rd/$RG")" = "$_rn0" ] || _rd=""
    rc_score "M7-advance (advisor-owed): the digest allow also writes .recover-advisor-owed" "$_rd" "$RG" "$RC_P658" "d_step d_first"
    _rd="$(rc_dig drop1)"; [ -n "$_rd" ] && [ "$(rc_n "$RC_DIGKEY" "$_rd/$RG")" = "$((_rn0 - 1))" ] || _rd=""
    rc_score "M8-step-only: the digest allow in the step arm only" "$_rd" "$RG" "$RC_P658" "d_first"
    _rd="$(rc_dig base)"; [ -n "$_rd" ] && [ "$(rc_n "$RC_DIGKEY" "$_rd/$RG")" = 0 ] && [ "$(rc_n "$RC_KB" "$_rd/$RG")" != 0 ] || _rd=""
    rc_score "M-base: the digest matched on its basename" "$_rd" "$RG" "$RC_P658" "d_base"
    _rd="$(rc_dig nofull)"; [ -n "$_rd" ] && [ "$(rc_n 'is_full_read' "$_rd/$RG")" = "$(( $(rc_n 'is_full_read' "$RC_REAL/$RG") - _rn0 ))" ] || _rd=""
    rc_score "M-nofull: the digest allow without is_full_read" "$_rd" "$RG" "$RC_P658" "d_bounded"
  fi

  # --- BL-666: the renamed stage write -----------------------------------------
  # Detection key: RC_RENKEY, the rename of the $$ temp onto $PROGRESS.
  _rk="$(grep -cF -- "$RC_RENKEY" "$GATE")" || _rk=0
  if [ "$_rk" -lt 1 ]; then
    skip "BL-666 renamed-stage-write arms" "the gate does not rename a temp onto the stage (key '${RC_RENKEY}', found 0); this fixture ships one pull ahead of its subject"
  else
    RC_P666="s_inode s_killed s_garbage s_struct"
    rc_arms "$RC_P666"
    rc_control "$RC_P666" "BL-666 stage write"
    _rsw="$(grep -F -- "$RC_SWKEY" "$RC_REAL/$RG" | head -1)"
    _rfa='${PROGRESS}.$$'; _rfb='${PROGRESS}.tmp'
    rc_sw() { # rc_sw <replacement line> -> a whole-directory copy with the stage-write line replaced, or empty
      _rd="$(race_dir)"; [ -n "$_rd" ] || return 0
      race_edit "$RC_REAL/$RG" "$_rd/$RG.m" "$RACE_REPL" "$_rsw" "" "$1" && mv "$_rd/$RG.m" "$_rd/$RG" || return 0
      printf '%s\n' "$_rd"
    }
    rc_score "M9-inplace: the stage written in place" \
      "$(rc_sw $'        printf \'step\\n\' >"$PROGRESS" 2>/dev/null || true')" "$RG" "$RC_P666" "s_inode s_killed s_struct"
    rc_score "M10-no-rename: the temp written and never moved" \
      "$(rc_sw $'        printf \'step\\n\' >"${PROGRESS}.$$" 2>/dev/null || true')" "$RG" "$RC_P666" "s_inode s_struct"
    rc_score "M-unlink: the stage removed, then written in place" \
      "$(rc_sw $'        rm -f "$PROGRESS" 2>/dev/null; printf \'step\\n\' >"$PROGRESS" 2>/dev/null || true')" "$RG" "$RC_P666" "s_killed s_struct"
    rc_score "M-fixedname: a fixed temp name with no \$\$" \
      "$(rc_sw "${_rsw//"$_rfa"/$_rfb}")" "$RG" "$RC_P666" "s_struct"
  fi

  # --- BL-684: a new recovery clears the stale stage ---------------------------
  # Detection key: RC_CLRRE, an `rm -f` line in the producer naming .recover-gate-progress.
  _rk="$(grep -cE -- "$RC_CLRRE" "$RC_REAL/$RC_RH")" || _rk=0
  if [ "$_rk" -lt 1 ]; then
    skip "BL-684 stale-stage-clear arms" "ai-dlc-recover.sh has no rm -f line naming .recover-gate-progress (key '${RC_CLRRE}', found 0); this fixture ships one pull ahead of its subject"
  else
    RC_P684="r_clear r_owed r_ctl"
    rc_arms "$RC_P684"
    rc_control "$RC_P684" "BL-684 stale-stage clear"
    # EVERY clearing line is neutralised, not the first: a clear spelled over two lines (the stage
    # and its temps) would otherwise leave one layer in place and prove that layer.
    _rd="$(race_dir)"
    if [ -n "$_rd" ] && R="$RC_CLRRE" awk '$0 ~ ENVIRON["R"] { print ":"; next } { print }' "$RC_REAL/$RC_RH" > "$_rd/$RC_RH" \
       && ! grep -qE -- "$RC_CLRRE" "$_rd/$RC_RH"; then :; else _rd=""; fi
    rc_score "M-684: the new recovery's stage clear removed" "$_rd" "$RC_RH" "$RC_P684" "r_clear"
    # BL-730: the owed-temp clear. RC_CLRRE keys on .recover-gate-progress, so it cannot match this
    # line, and this mutant touches no stage line; each mutant therefore flips only its own predicate.
    RC_OWEDKEY='rm -f "${STATE_DIR}"/.recover-advisor-owed.*'
    _rn="$(grep -cF -- "$RC_OWEDKEY" "$RC_REAL/$RC_RH")" || _rn=0
    if [ "$_rn" -lt 1 ]; then
      skip "BL-730 owed-temp-clear mutant" "ai-dlc-recover.sh has no line '${RC_OWEDKEY}' (found 0)"
    else
      _rd="$(race_dir)"
      if [ -n "$_rd" ] && K="$RC_OWEDKEY" awk 'index($0, ENVIRON["K"]) == 1 { print ":"; next } { print }' "$RC_REAL/$RC_RH" > "$_rd/$RC_RH" \
         && [ "$(grep -cF -- "$RC_OWEDKEY" "$_rd/$RC_RH")" = 0 ]; then :; else _rd=""; fi
      rc_score "M-730: the owed-temp clear removed" "$_rd" "$RC_RH" "$RC_P684" "r_owed"
    fi
  fi

  # --- BL-688: an unwritable state directory stands the gate down ---------------
  # Every way out of a recovery is a write under _bmad-output, so with the directory unwritable
  # the snapshot Read advanced nothing and every later call was denied FIRST (wedge 1); made
  # unwritable after the stage reached `step`, every call was denied SECOND (wedge 2). Each 555
  # predicate is straight-line -- chmod 555, collect every decision, chmod 755, then judge -- so
  # no return path can leave the directory unwritable; the EXIT trap is the backstop.
  # Detection key: RC_WKEY, the per-call writability test in the gate.
  RC_WKEY='[ -w "$STATE_DIR" ]'
  RC_WLINE='[ -w "$STATE_DIR" ] || exit 0'
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
    rc_control "$RC_P688" "BL-688 unwritable stand-down"
    # The three mutants each remove the per-call test; A and B put back the two shapes the
    # contract first proposed, which cannot close either wedge.
    rc_w() { # rc_w <gate replacement line> -> a whole-directory copy with the writability line replaced, or empty
      _rd="$(race_dir)"; [ -n "$_rd" ] || return 0
      race_edit "$RC_REAL/$RG" "$_rd/$RG.m" "$RACE_REPL" "$RC_WLINE" "" "$1" && mv "$_rd/$RG.m" "$_rd/$RG" || return 0
      printf '%s\n' "$_rd"
    }
    rc_score "M-688-drop: the per-call writability test removed" "$(rc_w ':')" "$RG" "$RC_P688" "w_snap w_step"
    # Shape A: the failed stage write clears the marker instead (a removal cannot act in a 555 dir).
    _rd="$(rc_w ':')"
    _rsw="$(grep -F -- "$RC_SWKEY" "$RC_REAL/$RG" | head -1)"
    if [ -n "$_rd" ] && race_edit "$_rd/$RG" "$_rd/$RG.m" "$RACE_REPL" "$_rsw" "" \
         "${_rsw%%|| rm -f*}|| rm -f \"\$MARKER\" \"\$PROGRESS\" \"\${PROGRESS}.\$\$\" 2>/dev/null || true" \
       && mv "$_rd/$RG.m" "$_rd/$RG" && [ "$(grep -cF 'rm -f "$MARKER" "$PROGRESS" "${PROGRESS}.$$"' "$_rd/$RG")" = 1 ]; then :; else _rd=""; fi
    rc_score "M-688-A: the failed stage write clears the marker in place of the per-call test" "$_rd" "$RG" "$RC_P688" "w_snap w_step"
    # Shape B: the producer arms only when _bmad-output is writable (cannot see a chmod made later).
    _rd="$(rc_w ':')"
    _rrl="  printf 'step_file_resolved=%s\\n' \"\$STEP_FILE_RESOLVED\""
    if [ -n "$_rd" ] && race_edit "$RC_REAL/$RC_RH" "$_rd/$RC_RH" "$RACE_BEFORE" "$_rrl" '  [ -w "$STATE_DIR" ] || STEP_FILE_RESOLVED=0' \
       && [ "$(grep -cF -- "$RC_WKEY" "$_rd/$RC_RH")" = 1 ] && [ "$(grep -cF -- "$RC_WKEY" "$_rd/$RG")" = 0 ]; then :; else _rd=""; fi
    rc_score "M-688-B: the producer arms only when writable, in place of the per-call test" "$_rd" "$RG" "$RC_P688" "w_snap w_step"
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
    rc_control "$RC_P725" "BL-725 failed stage write"
    _rsw="$(grep -F -- "$RC_SWKEY" "$RC_REAL/$RG" | head -1)"
    _rmk=' "$MARKER"'
    rc_s725() { # rc_s725 <replacement line> -> a whole-directory copy with the stage-write line replaced, or empty
      _rd="$(race_dir)"; [ -n "$_rd" ] || return 0
      race_edit "$RC_REAL/$RG" "$_rd/$RG.m" "$RACE_REPL" "$_rsw" "" "$1" && mv "$_rd/$RG.m" "$_rd/$RG" || return 0
      printf '%s\n' "$_rd"
    }
    rc_score "M-725-pre: the failure branch back to the temp-only unlink" \
      "$(rc_s725 "${_rsw//"$_rmk"/}")" "$RG" "$RC_P725" "s_fail"
    rc_score "M-725-always: the marker also removed on a successful stage write" \
      "$(rc_s725 "${_rsw}; rm -f \"\$MARKER\"")" "$RG" "$RC_P725" "s_fail_ctl"
  fi

  # --- BL-687: a full step Read before the stage write is allowed, advancing nothing -------
  # A parallel step Read whose hook ran before the snapshot call's stage write was denied FIRST.
  # The allow must not open a step Read alone as a way to satisfy the recovery, a bounded step
  # Read, any other Read, or a compelled handoff.md Read (which would arm the handoff marker).
  # Detection key: RC_FLINE, the full-step-Read allow line in the snapshot arm.
  RC_FLINE='    if [ "$TOOL" = "Read" ] && [ -n "$FABS" ] && [ "$FABS" = "$STEP_ABS" ] && is_full_read; then'
  RC_FEXIT='        *) exit 0 ;;'
  RC_FHAND='        */steps/handoff.md|steps/handoff.md) : ;;'
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
    rc_control "$RC_P687" "BL-687 full step Read allow"
    rc_f() { # rc_f <awk program> <anchor> <line> [W] -> a whole-directory copy with the gate edited, or empty
      _rd="$(race_dir)"; [ -n "$_rd" ] || return 0
      race_edit "$RC_REAL/$RG" "$_rd/$RG.m" "$1" "$2" "$3" "${4:-}" && mv "$_rd/$RG.m" "$_rd/$RG" || return 0
      printf '%s\n' "$_rd"
    }
    _rfd="$(grep -F -- '    deny "AI/DLC post-compact recovery: your FIRST tool call must be' "$RC_REAL/$RG" | head -1)"
    rc_score "M-687-nofull: the allow without is_full_read" \
      "$(rc_f "$RACE_REPL" "$RC_FLINE" "" "${RC_FLINE/ && is_full_read/}")" "$RG" "$RC_P687" "f_bound"
    rc_score "M-687-adv: the allow also writes the stage" \
      "$(rc_f "$RACE_REPL" "$RC_FEXIT" "" "        *) printf 'step\\n' >\"\$PROGRESS\"; exit 0 ;;")" "$RG" "$RC_P687" "f_allow"
    rc_score "M-687-sat: the allow also clears the marker" \
      "$(rc_f "$RACE_REPL" "$RC_FEXIT" "" '        *) rm -f "$MARKER"; exit 0 ;;')" "$RG" "$RC_P687" "f_allow"
    rc_score "M-687-widen: any Read allowed with no stage file" \
      "$(rc_f "$RACE_BEFORE" "$_rfd" '    if [ "$TOOL" = "Read" ]; then exit 0; fi')" "$RG" "$RC_P687" "f_bound f_decoy f_hand"
    rc_score "M-687-nohand: the handoff.md carve-out removed" \
      "$(rc_f "$RACE_REPL" "$RC_FHAND" "" '        */steps/handoff.md|steps/handoff.md) exit 0 ;;')" "$RG" "$RC_P687" "f_hand"
    # drop: the whole block, from its if line through its own four-space fi, removed
    _rd="$(race_dir)"
    if [ -n "$_rd" ] && A="$RC_FLINE" awk 'd && $0 == "    fi" { d = 0; next } d { next } $0 == ENVIRON["A"] { d = 1; next } { print }' "$RC_REAL/$RG" > "$_rd/$RG" \
       && [ "$(grep -cxF -- "$RC_FLINE" "$_rd/$RG")" = 0 ] && [ "$(grep -cxF -- "$RC_FHAND" "$_rd/$RG")" = 0 ] \
       && [ "$(grep -c '^    fi$' "$RC_REAL/$RG")" = "$(( $(grep -c '^    fi$' "$_rd/$RG") + 1 ))" ]; then :; else _rd=""; fi
    rc_score "M-687-drop: the full step Read allow removed" "$_rd" "$RG" "$RC_P687" "f_allow"
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
# and S2c are the seeds that kill that narrowing, and mutant M6 is the one that builds it.
#
# THE MUTANTS ARE COPIES OUTSIDE THE TREE, for a reason particular to this subject. The count
# grammar is four strings byte-identical across three files and invariant I113 binds them, so a
# mutation applied to the tracked hook would trip I113 as well as this fixture -- two programs
# reporting one finding, and the fixture's verdict no longer attributable. The copies live
# under $WORK and are driven through CLAUDE_PROJECT_DIR exactly as the arms above drive the
# real hook, so each mutant is scored HERE and by nothing else.
#
# NOT ANCHORED ON THE UNRESOLVABLE-FALLBACK ASSIGNMENT. The old-fallback mutant at assertion 24
# rewrites that exact assignment and asserts the rewrite was TOTAL by COUNTING the substring, so
# the hook's refusal branch deliberately spells its own assignment the other way and no mutant
# below may re-introduce the collision by anchoring there. This paragraph does not spell it
# either: the count is over the mutated HOOK, but the same class has already fired three times
# on prose, twice in the hook's own comments, and a near-miss is not worth the second reading.
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
# EVERY FIELD IS A FACT THE HOOK EMITS, so a mutant that emits nothing scores DEAD and fails
# every arm by construction rather than passing any. The mandate cell distinguishes a mandate
# naming a PATH from one naming an ACTION from one rendering an EMPTY path -- M5's whole
# subject is the third, and a cell reading only "is there a second mandate" could not see it.
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

# --- the position mutant scorer ---------------------------------------------
# Each mutant is a COPY, guarded by `cmp -s` (a sed that matched nothing is not a mutation) and
# by `bash -n` (a mutant that dies emits nothing, and silence would otherwise score as a kill).
# It is scored by its FLIP SET against POS_EXPECTED: a mutant that flips more than its own set
# means two arms are entangled and one is vacuous, and one that flips nothing means the seeds
# it was built for cannot fire.
posflips() { # posflips <battery> -> the seed names (of those the battery ran) whose token differs from expected
  _pf=""
  for _pe in $POS_EXPECTED; do
    case " $1 " in *" ${_pe%%:*}:"*) ;; *) continue ;; esac
    case " $1 " in *" $_pe "*) ;; *) _pf="$_pf ${_pe%%:*}" ;; esac
  done
  printf '%s' "${_pf# }"
}
posmutant() { # posmutant <label> <mutant-path> <expected flip set> <what it proves> <twins> <name>
  if cmp -s "$HOOK" "$2"; then
    bad "FIXTURE STALE: $1 — the mutant is byte-identical to the hook, so the mutation matched nothing and proves nothing"; return
  fi
  if ! bash -n "$2" 2>/dev/null; then
    bad "FIXTURE STALE: $1 — the mutant is not valid shell; it would emit no directive, and that silence would score as a kill it did not earn"; return
  fi
  _pg="$(posbattery "$2" "$(mx_sel "$POS_SEEDS" "$3" "$5")")"
  _pfl="$(posflips "$_pg")"; mx_note "$6" "$3" "$_pfl"
  if [ "$_pfl" = "$3" ]; then
    ok "MUTANT $1: flips exactly {$3} — $4"
  elif [ -z "$_pfl" ]; then
    bad "MUTANT SURVIVED: $1 — every seed answers as the fixed hook does, so {$3} cannot fire and $4 is unproven"
  else
    bad "MUTANT FLIP SET WRONG: $1 — expected {$3}, measured {$_pfl}; the seeds are entangled or one of them is vacuous. Battery: [$_pg]"
  fi
}

# --- Assertion 27: UNMUTATED CONTROL, before any mutant verdict is read ------
# TWO INERT RUNS COMPARE EQUAL. A copy of the hook that died at startup would make every mutant
# below SURVIVE while this arm also passed, and the pair would read exactly like a fix that
# works. So the control is PRESENCE-shaped: it must reproduce the whole battery, not merely
# fail to complain.
POS_CTRL="$WORK/recover-pos-control.sh"
cp "$HOOK" "$POS_CTRL"
POS_C="$(posbattery "$POS_CTRL")"
if [ "$POS_C" = "$POS_EXPECTED" ]; then
  ok "control: an unmutated copy of the hook, driven from a scratch project, reproduces all ten seed tokens — a mutant's flip below is its mutation and not the copy"
else
  bad "CONTROL FAILED — an unmutated copy answers [$POS_C], not the battery the real hook answers, so every position-mutant verdict below is uninterpretable"
fi

# --- Assertion 28: M1 — the whole-file `grep -m1` reader restored ------------
# THE PRE-FIX HOOK. With the section count emptied every snapshot falls to the unchanged
# whole-file first-match reader, which is an answer whatever the snapshot says. S4 is in the
# flip set and it is the discriminating half: there the FIRST match in the file is the LABELLED
# prior, so first-match-wins mandates a superseded position that the label exists to retire.
MP1="$WORK/recover-pos-m1.sh"
sed 's/^POSITION_BULLETS="\$(awk /POSITION_BULLETS=""; _unused="$(awk /' "$HOOK" > "$MP1"
posmutant "M1 the whole-file first-match reader restored" "$MP1" "S1 S1b S4" \
  "both two-file seeds mandate whichever bullet the file happened to list first, and the labelled-prior-above seed mandates the PRIOR — the coin toss the count replaced" "S2" M1-first-match

# --- Assertion 29: M2 — section-scoped but `head -1` ------------------------
# The half-fix. The count is computed and then ignored: the refusal branch never fires and the
# first bullet wins. Only the two-file seeds may move — S4 stays green, which is what separates
# this from M1 and makes each attributable.
MP2="$WORK/recover-pos-m2.sh"
sed 's/^  if \[ "\$_pos_distinct" -ge 2 \]; then$/  if false; then/' "$HOOK" > "$MP2"
posmutant "M2 section-scoped, refusal dropped, first bullet wins" "$MP2" "S1 S1b" \
  "a hook that counts two and mandates the first one anyway — the label exclusion still works, so only the unlabelled pair moves" "S2 S4" M2-head1

# --- Assertion 30: M3 — section-scoped but `tail -1` ------------------------
# NEWEST-WINS IS NOT THE FIX EITHER, and this mutant is what says so. It answers `live.md` on
# both two-file seeds, which is the RIGHT file for the wrong reason: nothing in the snapshot
# says the later bullet is the live one, and on a stale-below-live section the same rule
# mandates the stale one. The arm demands a REFUSAL, so a hook that guessed correctly here
# still dies.
MP3="$WORK/recover-pos-m3.sh"
sed -e 's/^  if \[ "\$_pos_distinct" -ge 2 \]; then$/  if false; then/' \
    -e "s/| sed -n '1p'/| sed -n '\$p'/" "$HOOK" > "$MP3"
posmutant "M3 section-scoped, refusal dropped, LAST bullet wins" "$MP3" "S1 S1b" \
  "newest-wins names the file this seed happens to want and is still wrong — the arms assert a refusal, not a preferred guess" "S2" M3-tail1

# --- Assertion 31: M4 — the label exclusion dropped -------------------------
# A superseded position recorded under a labelled key is not a second live value, and this is
# the mutant that proves the exclusion is load-bearing in BOTH directions: with it gone the two
# labelled seeds refuse, and they are the only ones that move. S1/S1b stay red-free because
# their bullets carry no label at all, which is what makes this mutant's kill attributable to
# the exclusion rather than to the count.
MP4="$WORK/recover-pos-m4.sh"
sed "s/^AI_DLC_POS_LABEL_RE=.*$/AI_DLC_POS_LABEL_RE='zzz_no_such_label_zzz'/" "$HOOK" > "$MP4"
posmutant "M4 the label exclusion dropped" "$MP4" "S3 S4" \
  "a correctly labelled \`(prior)\` position becomes a second live bullet and the hook refuses a snapshot that is exactly right — the remedy it prints is the thing the consumer already did" "S2" M4-no-label

# --- Assertion 32: M5 — refused, and the mandate emitted anyway -------------
# THE HALF-REFUSAL, and it is worse than no refusal: `step_file_resolved=0` keeps the gate stood
# down while the block still renders a SECOND mandate — with an EMPTY path, because there is no
# value to interpolate. `Read ` in full is a MUST the lead cannot execute, and a MUST it cannot
# execute is what teaches it the MUSTs in this block are negotiable. Only the mandate cell of
# the two refusing seeds moves, which is why that cell distinguishes EMPTY from ACTION.
MP5="$WORK/recover-pos-m5.sh"
awk '!d && $0=="if [ \"$STEP_FILE_RESOLVED\" -eq 1 ]; then" {print "if true; then"; d=1; next} 1' "$HOOK" > "$MP5"
posmutant "M5 the refusal keeps resolved=0 but emits the mandate anyway" "$MP5" "S1 S1b" \
  "the block renders \`Read \` with an empty path where it refused to pick one — an unexecutable MUST, which is the standing the whole section depends on" "S2" M5-mandate-anyway

# --- Assertion 33: M6 — the STRICT key grammar ------------------------------
# THE CONSUMER-HISTORY MUTANT. This is the first draft of the fix, refuted by measurement: a
# key matching only the bolded prose spelling un-resolves 94 of the reference consumer's 2218
# snapshot revisions that the shipped alternation resolves. Both the bullet grammar and the
# fallback reader are narrowed, because narrowing one alone leaves the other resolving and the
# mutant would prove the layer left in place. Four seeds move and they are exactly the ones
# whose key the strict grammar cannot spell.
MP6="$WORK/recover-pos-m6.sh"
sed -E -e "s@^AI_DLC_POS_BULLET_RE=.*\$@AI_DLC_POS_BULLET_RE='^[[:space:]]*-[[:space:]]*\\\\*\\\\*Current step file:\\\\*\\\\*'@" \
       -e "s@grep -m1 -iE '\(current_step_file[^']*'@grep -m1 -iE '\\\\*\\\\*Current step file:\\\\*\\\\*'@" "$HOOK" > "$MP6"
posmutant "M6 the key alternation narrowed to one spelling" "$MP6" "S1b S2b S2c S7" \
  "the backticked KEY, the unbolded prose key, the \`(LIVE)\` spelling and the mixed-spelling pair all stop resolving — the 94-revision regression the first draft of this fix carried" "S2" M6-strict-key

# --- Assertion 34: M7 — the bullet-position clause dropped ------------------
# The clause that requires the key to sit at a dash bullet before the first colon. Without it a
# PROSE line that quotes the key name mid-sentence counts as a position, and the hook refuses a
# snapshot carrying exactly one live bullet. Measured on the consumer: 1 revision of 2218 has
# that shape, and it is the newest of the two-plus matches.
MP7="$WORK/recover-pos-m7.sh"
sed "s@^AI_DLC_POS_BULLET_RE='\^\[\[:space:\]\]\*-\[\^:\]\*@AI_DLC_POS_BULLET_RE='@" "$HOOK" > "$MP7"
posmutant "M7 the bullet-key position clause dropped" "$MP7" "S6" \
  "a paragraph that mentions the key name becomes a second live position and a correct snapshot is refused — only the prose seed moves, so the clause has its own subject" "S2" M7-no-bullet-clause

# --- Assertion 35: M8 — agreement treated as a duplicate --------------------
# AGREEMENT IS NOT A DUPLICATE, and refusing on it would un-gate the common case for nothing.
# Two bullets naming ONE file is the ordinary stale-plus-live state, and the basename reduction
# is what separates it from a real ambiguity. The mutation makes the de-duplication test
# unreachable so every repeated basename counts as distinct; only S5 moves.
MP8="$WORK/recover-pos-m8.sh"
sed 's|^      \*" \$_pos_b "\*) ;;$|      *"ZZ-unreachable-ZZ"*) ;;|' "$HOOK" > "$MP8"
posmutant "M8 two bullets naming the SAME file refuse" "$MP8" "S5" \
  "the stale-plus-live state that names one file is refused, which withholds a recovery the hook could have completed and leaves the lead with no mandate for no reason" "S2" M8-agreement-dup

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
# The arm runs all three, in harness order, and asserts the deny. The mutant restores the
# deletion and the arm goes red.
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

# MUTANT -- restore the deletion that shipped. `cmp -s` proves it applied; `bash -n` that it
# parses. The kill is the sequence arm alone: the compaction log must STILL read yes, because
# the deletion came after the read, which is exactly why the log never showed the hole.
MP_DEL="$WORK/postcompact-deletes.sh"
awk '{print} /^    RECOVERED="yes"$/ && !done {getline; print; print "  rm -f \"$MARKER\" 2>/dev/null || true"; done=1}' "$POSTCOMPACT" > "$MP_DEL"
if cmp -s "$POSTCOMPACT" "$MP_DEL"; then
  bad "FIXTURE STALE: the deletion mutant is byte-identical to postcompact.sh, so the mutation matched nothing"
elif ! bash -n "$MP_DEL" 2>/dev/null; then
  bad "FIXTURE STALE: the deletion mutant is not valid shell"
else
  rm_="$(p_sequence "$MP_DEL")"
  case "$rm_" in
    FAIL:postcompact\ DELETED*) ok "mutant: postcompact.sh restored to deleting the marker — the sequence arm goes red on exactly that line" ;;
    PASS) bad "MUTANT KILLED NOTHING: a postcompact.sh that deletes the marker still passes the sequence arm, so the arm cannot see the shipped defect" ;;
    *) bad "MUTANT FLIP WRONG: expected the deletion finding, measured '${rm_#FAIL:}'" ;;
  esac
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
pcflips() { for _n in ${2:-$PCPREDS}; do r="$("pc_$_n" "$1")"; [ "${r%%:*}" = PASS ] || printf '%s ' "$_n"; done; }
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
pcf="$(pcflips "$POSTCOMPACT")"
[ -z "${pcf// /}" ] && ok "control: the unmutated postcompact hook reproduces all 4 verdicts" || bad "CONTROL FAILED — postcompact already flips {${pcf}}"

pcmutant() { # pcmutant <label> <src-anchor-line> <replacement> <expected flips> <twins> <name>
  _m="$WORK/postcompact-whose-$$-$RANDOM.sh"
  if ! smut "$POSTCOMPACT" "$2" "$_m" "$3"; then bad "FIXTURE STALE: $1 — the anchor is not exactly one whole line"; return; fi
  cmp -s "$POSTCOMPACT" "$_m" && { bad "FIXTURE STALE: $1 — byte-identical"; return; }
  bash -n "$_m" 2>/dev/null || { bad "FIXTURE STALE: $1 — not valid shell"; return; }
  got="$(pcflips "$_m" "$(mx_sel "$PCPREDS" "$4" "$5")")"; mx_note "$6" "$4" "$got"
  if [ "$got" = "$4 " ]; then ok "mutant: $1 — flips exactly {$4}"
  elif [ -z "${got// /}" ]; then bad "MUTANT KILLED NOTHING: $1 — {$4} cannot fire"
  else bad "MUTANT FLIP SET WRONG: $1 — expected {$4}, measured {$got}"; fi
}
# (f) updater stand-down removed. Killed by upd_nomark (no marker -> logs `no` and prints the
# warning) and upd_foreign (foreign marker -> logs `no`); foreign and legacy are pipeline sessions.
pcmutant "postcompact has no updater stand-down" "$UPD_CASE" "$UPD_NEVER" "upd_nomark upd_foreign" "foreign" PC-f
# (g) owner test neutralised. Killed by foreign ALONE: upd_foreign still stands down on the
# updater test, and legacy has no owner to compare.
pcmutant "postcompact reads another session's marker as its own" \
  'if [ -n "$_MK_SID" ] && [ -n "$_EV_SID" ] && [ "$_MK_SID" != "$_EV_SID" ]; then _MK_FOREIGN=1; fi' ':' "foreign" "legacy" PC-g

fi

fi

# =============================================================================
# EQUIVALENCE -- the in-process answer is the CLI's, byte for byte, and these are the end-to-end runs
#
# Every cell above sources its subject in a subshell (hook_run / val_run). These cells run each
# subject ONCE MORE as the harness does, `bash <file>` with the payload on stdin, on a REFUSING and a
# PASSING input that differ, and require the two answers identical. They are also the fixture's
# end-to-end runs, one per distinct CLI outcome (fixture-mutants.md clauses 5-6). Each pair is taken on
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
# validator: PASSING = the shipped SKILL.md; REFUSING = the no-mandate copy assertion 7 built.
_vp_cli="$(eq_val cli "$SKILL")"; _vp_in="$(eq_val inproc "$SKILL")"
_vr_cli="$(eq_val cli "$MUT_SKILL")"; _vr_in="$(eq_val inproc "$MUT_SKILL")"
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
if [ "$fails" -eq 0 ]; then echo "postcompact-rulebook-recovery: PASS"; exit 0; fi
echo "postcompact-rulebook-recovery: $fails assertion(s) FAILED" >&2
exit 1
