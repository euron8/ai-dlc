#!/usr/bin/env bash
# escalation-status-vocabulary/run.sh — prove the vocabulary check fires, and that its
# vocabulary is DERIVED.
#
# THE DEFECT. gate-validation.md Check 2 branches on HARD_BLOCK / DECIDED_AUTONOMOUSLY /
# DEFERRAL_REQUEST and has no else. An entry on a fourth token satisfies no branch: Check 2
# does not block on it, does not surface it, and does not record it. It is silently skipped,
# and the gate reports Check 2 as passing. The failure is not a wrong verdict — it is an
# entry no verdict was ever computed for, which is a green indistinguishable from having
# examined nothing.
#
# Measured on the reference consumer: 8 entries on FILED and OPEN, accumulated across the
# sprints they were written in, every gate in that window reporting Check 2 as passing.
#
# Usage: run.sh [--matrix]
#
# THE MUTANT MATRIX (fixture-mutants.md 'One run per distinct state'). The four READER mutants are scored on the
# seven reader arms (a-off a-near b-off b-near d-off d-near M-mid: assertions 4 and 8-10, an offender and a near-miss
# per reading). PER PUSH a reader mutant runs only its DECIDING arm, which it must trip, and its TWIN, which it must
# leave GREEN; `--matrix` runs every arm and prints one `MATRIX <mutant> <arm> TRIPPED|GREEN` row per pair. The
# rows below are the one source: mx_row reads them from this file, and a per-push run refuses a mutant with none.
# The fifteen CELL-VECTOR mutants (the empty-file, refusal, posture and refusal-prose batteries) are each scored by
# one string of every cell of their battery against the whole vector they must produce, so each is a FULL row.
# The matrix is re-measured as .claude/rules/fixture-mutants.md clause 2 ("One run per distinct
# state") requires. Run it from the repo root:
# MUTANT-MATRIX-REMEASURE bash core/fixtures/escalation-status-vocabulary/run.sh --matrix
# Measured by the REMEASURE command: canon-guard-deleted also trips d-off (its token check), and first-wins-outright
# also trips a-off and b-off (the reading this change replaced is first-wins for both); each stands down for the
# deciding near-miss, which is the cell no other mutant here reaches.
# MUTANT-MATRIX canon-guard-deleted decides=d-near twins=b-near
# MUTANT-MATRIX line-anchored decides=M-mid twins=a-near
# MUTANT-MATRIX first-canonical-wins decides=a-off twins=b-off
# MUTANT-MATRIX first-wins-outright decides=b-near twins=d-near
# MUTANT-MATRIX-FULL M-revert worlds=A,B,C,D,E why=the empty-file arm asserts the whole five-cell vector equals 00111, so every cell is its decision
# MUTANT-MATRIX-FULL M-zero-records worlds=A,B,C,D,E why=the empty-file arm asserts the whole five-cell vector equals 11101, so every cell is its decision
# MUTANT-MATRIX-FULL R-revert-all worlds=A,B,C,D,E,F why=the refusal arm asserts the whole six-cell vector equals 000011, so every cell is its decision
# MUTANT-MATRIX-FULL R-nonregular worlds=A,B,C,D,E,F why=the refusal arm asserts the whole six-cell vector equals 100111, so every cell is its decision
# MUTANT-MATRIX-FULL R-no-symlink worlds=A,B,C,D,E,F why=the refusal arm asserts the whole six-cell vector equals 110111, so every cell is its decision
# MUTANT-MATRIX-FULL R-rc worlds=A,B,C,D,E,F why=the refusal arm asserts the whole six-cell vector equals 011011, so every cell is its decision
# MUTANT-MATRIX-FULL R-readable-never worlds=A,B,C,D,E,F why=the refusal arm asserts the whole six-cell vector equals 011111, so every cell is its decision
# MUTANT-MATRIX-FULL R-readable-always worlds=A,B,C,D,E,F why=the refusal arm asserts the whole six-cell vector equals 111011, so every cell is its decision
# MUTANT-MATRIX-FULL M-step-2 worlds=A,B,C why=the posture arm asserts the whole three-cell vector equals 011, so every cell is its decision
# MUTANT-MATRIX-FULL M-step-2a worlds=A,B,C why=the posture arm asserts the whole three-cell vector equals 101, so every cell is its decision
# MUTANT-MATRIX-FULL M-map worlds=A,B,C why=the posture arm asserts the whole three-cell vector equals 110, so every cell is its decision
# MUTANT-MATRIX-FULL RP-fail-sentence worlds=A,B,C,D2,D2a,Dm,E,PA,PB,PC why=the refusal-prose arm asserts the seven refusal cells and the three posture cells equal 1110111/111 together
# MUTANT-MATRIX-FULL RP-map-clause worlds=A,B,C,D2,D2a,Dm,E,PA,PB,PC why=the refusal-prose arm asserts the seven refusal cells and the three posture cells equal 0111111/111 together
# MUTANT-MATRIX-FULL RP-step-2a-tail worlds=A,B,C,D2,D2a,Dm,E,PA,PB,PC why=the refusal-prose arm asserts the seven refusal cells and the three posture cells equal 1101111/111 together
# MUTANT-MATRIX-FULL RP-check-26 worlds=A,B,C,D2,D2a,Dm,E,PA,PB,PC why=the refusal-prose arm asserts the seven refusal cells and the three posture cells equal 1111110/111 together
# MUTANT-MATRIX-FULL cwd-unpinned worlds=slash,root why=the cwd-invariance arm asserts the whole two-cwd vector equals 10,10, so each cwd cell is its decision
# MUTANT-MATRIX-FULL cwd-unpinned-ven worlds=A,B,C,D,E why=the whole-directory control's five-cell vector from / equals 11111 under the pin and differs without it, so every cell is its decision
# MUTANT-MATRIX-FULL cwd-unpinned-vr worlds=A,B,C,D,E,F why=the refusal control's six-cell vector from / equals 111111 under the pin and differs without it, so every cell is its decision
# The kills reach mutant_killed through variables, one name per scorer call:
# MUTANT-MATRIX-DYNAMIC reader-loop why=the reader loop passes each of the four reader mutant names above as $mname
# MUTANT-MATRIX-DYNAMIC ven_score why=ven_score passes M-revert and M-zero-records as its name argument
# MUTANT-MATRIX-DYNAMIC vr_score why=vr_score passes the six R- mutant names above as its name argument
# MUTANT-MATRIX-DYNAMIC en_score why=en_score passes M-step-2, M-step-2a and M-map as its name argument
# MUTANT-MATRIX-DYNAMIC rp_score why=rp_score passes the four RP- mutant names above as its name argument
set -uo pipefail
MATRIX=0
for _a in "$@"; do
  case "$_a" in
    --matrix) MATRIX=1 ;;
    *) echo "FIXTURE ERROR: unknown argument '$_a' (only --matrix)" >&2; exit 2 ;;
  esac
done
# The pre-push gate exports AI_DLC_* tunables; none is read here, but scrub them all the same.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
# The project root, found by walking UP from this script's own location for a marker (the ai_dlc_resolve_root()
# pattern), never from the cwd and never by counted `..` hops. Every copy of the validator the fixture builds sits
# under a mktemp dir with no marker above it, so it needs the root handed to it (ev below does that).
ESV_ROOT=""
_d="$HERE"
while [ -n "$_d" ] && [ "$_d" != "/" ] && [ "$_d" != "." ]; do
  if [ -e "$_d/.git" ] || [ -d "$_d/.claude" ] || [ -d "$_d/core/skills/ai-dlc" ]; then ESV_ROOT="$_d"; break; fi
  _d="$(dirname "$_d")"
done
[ -n "$ESV_ROOT" ] || { echo "FIXTURE ERROR: no .git, .claude/ or core/skills/ai-dlc marker above $HERE" >&2; exit 2; }
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
# A literal-tail path, never `. "$VAR"`: in a fixture opted in by an inproc: row, P1 reads an opaque source as a drive.
[ -f "$HERE/../lib/mutant.sh" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE ERROR: sourcing lib/mutant.sh failed" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

echo "escalation-status-vocabulary:"
echo "HERMETIC-CONSUMED $VALIDATOR"

# IN PROCESS (BL-878). Every copy of the validator -- the shipped one, the lone copy, the mutant control and every
# mutant -- is SOURCED by src_esv in THIS shell (its guard returns after defining esv_main; one fx_inproc pass per
# source, and a copy already sourced last is not sourced again), and `ev <copy> <args>` runs that copy's esv_main in
# a `( )` subshell, refusing any copy but the one sourced last. The subject's `exit` and `cd` stay in the subshell,
# and the env a drive needs is exported there. Every group of drives opens with src_esv on its copy, in this shell,
# never inside a `$( )`. Copies keep the subject's relative path (.../core/scripts/<name>), so each pass is counted
# under the inproc: row. A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT: a validator with neither the `esv_main() {` line
# nor the column-0 source guard predates the wrap and reads SKIP (exit 0, never an ok); exactly one half is a
# respelled subject and FAILs. The distribution cannot reach the SKIP unnoticed: C5 (validate-fixture-inprocess.sh)
# refuses a cli subject without the guard, and J3 refuses the start count moving.
ESV_SOURCED=""
src_esv() { # src_esv <copy>
  [ "$1" = "$ESV_SOURCED" ] && return 0
  unset -f esv_main
  fx_inproc "$1"
  . "$1" || { echo "FIXTURE BROKEN: sourcing $1 failed" >&2; exit 2; }
  declare -F esv_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $1 defined no esv_main" >&2; exit 2; }
  ESV_SOURCED="$1"
}
ev() { # ev <copy> <args...> -- one in-process run of <copy>, which must be the copy src_esv sourced last
  [ "$1" = "$ESV_SOURCED" ] || { echo "FIXTURE BROKEN: driving $1 while ${ESV_SOURCED:-nothing} is sourced" >&2; return 97; }
  # The program runs with `set -u` alone; this fixture runs with pipefail, which a subshell inherits. Turned off
  # first, so a pipeline inside esv_main answers in process exactly as it does when the validator is run as a program.
  # The root is pinned for every copy that would otherwise inherit an unresolved one. The lone copy (LONE_V) severs
  # itself by design and the script-relative copy (SIB_V) is handed its own root, so both are left exactly as they
  # set themselves. ESV_NOPIN=1 is the cwd-dependent resolution the cwd-invariance arm's mutant restores.
  local c="$1"
  shift
  (
    case "$c" in
      "${LONE_V:-}"|"${SIB_V:-}") : ;;
      *) if [ "${ESV_NOPIN:-0}" = 1 ]; then unset AI_DLC_PROJECT_ROOT CLAUDE_PROJECT_DIR; else export AI_DLC_PROJECT_ROOT="$ESV_ROOT"; fi ;;
    esac
  ( set +o pipefail; esv_main "$@" )
  )
}
ESV_REL="core/scripts/$(basename "$VALIDATOR")"
w_def=0; w_guard=0
grep -q '^esv_main() {$' "$VALIDATOR"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $VALIDATOR (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || w_def=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$VALIDATOR"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $VALIDATOR (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || w_guard=1
if [ "$w_def$w_guard" = 00 ]; then echo "SKIP: subject predates the in-process wrap"; exit 0; fi
if [ "$w_def" = 0 ]; then bad "$VALIDATOR carries the column-0 source guard but no \`esv_main() {\` line -- a respelled subject this fixture cannot drive"; echo "escalation-status-vocabulary: $fails assertion(s) FAILED" >&2; exit 1; fi
if [ "$w_guard" = 0 ]; then bad "$VALIDATOR defines \`esv_main() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run esv_main in this shell"; echo "escalation-status-vocabulary: $fails assertion(s) FAILED" >&2; exit 1; fi
src_esv "$VALIDATOR"

# --- the cli cells (cells.decl): the shipped validator run as a PROGRAM once per distinct CLI outcome -------------
# Outcomes, exit x output class: 0 the OK line (cli-pass); 0 OK: EXAMINED NOTHING (cli-empty); 1 a finding naming the
# out-of-vocabulary tokens (cli-finding); 2 the usage refusal on stderr (cli-usage). One `FXCELL=<id> bash
# "$VALIDATOR"` start each, compared byte for byte (stdout, stderr, exit) with the in-process call on the same input;
# the validator only reads. Each also asserts its own outcome.
EQ="$WORK/eq"; mkdir -p "$EQ"
eqv() { # eqv <cell-id> <args...>
  local id="$1"; shift
  ev "$VALIDATOR" "$@" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" bash "$VALIDATOR" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_rc() { cat "$EQ/$1.cl.rc"; }
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(head -c 300 "$EQ/$1.ip.out")" "$(head -c 300 "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(head -c 300 "$EQ/$1.cl.out")" "$(head -c 300 "$EQ/$1.cl.err")"; }
if eqv cli-pass "$CLEAN" "$SPEC_SRC" && [ "$(eq_rc cli-pass)" = 0 ] && grep -q '^OK: ' "$EQ/cli-pass.cl.out"; then
  ok "cli-pass: the program passes the published set exactly as the in-process call does (exit 0, an OK line)"
else bad "cli-pass: the program and the in-process call differ, or the outcome is not exit 0 with an OK line ($(eq_twin cli-pass))"; fi
if eqv cli-empty "$EMPTY" "$SPEC_SRC" && [ "$(eq_rc cli-empty)" = 0 ] && grep -qF 'EXAMINED NOTHING' "$EQ/cli-empty.cl.out"; then
  ok "cli-empty: the program examines nothing in an empty file exactly as the in-process call does (exit 0)"
else bad "cli-empty: the program and the in-process call differ, or the outcome is not exit 0 EXAMINED NOTHING ($(eq_twin cli-empty))"; fi
if eqv cli-finding "$DRIFT" "$SPEC_SRC" && [ "$(eq_rc cli-finding)" = 1 ] && grep -qF 'out-of-vocabulary status' "$EQ/cli-finding.cl.out" "$EQ/cli-finding.cl.err"; then
  ok "cli-finding: the program reports the drifted entries exactly as the in-process call does (exit 1)"
else bad "cli-finding: the program and the in-process call differ, or the outcome is not exit 1 with a finding ($(eq_twin cli-finding))"; fi
if eqv cli-usage && [ "$(eq_rc cli-usage)" = 2 ] && [ ! -s "$EQ/cli-usage.cl.out" ] && grep -qF 'FAIL: usage:' "$EQ/cli-usage.cl.err"; then
  ok "cli-usage: the program refuses no arguments exactly as the in-process call does (stderr, exit 2)"
else bad "cli-usage: the program and the in-process call differ, or the outcome is not exit 2 with the usage line ($(eq_twin cli-usage))"; fi
if ! cmp -s "$EQ/cli-pass.cl.rc" "$EQ/cli-finding.cl.rc" && ! cmp -s "$EQ/cli-finding.cl.rc" "$EQ/cli-usage.cl.rc" \
   && ! cmp -s "$EQ/cli-pass.cl.out" "$EQ/cli-empty.cl.out"; then
  ok "cli cells discriminate: pass, finding and usage exit 0, 1 and 2, and the pass and the empty file print different lines"
else bad "cli cells do not discriminate: two of cli-pass, cli-finding, cli-usage share an exit, or cli-pass printed what cli-empty did"; fi

# --- Assertion 1: POSITIVE CONTROL — the published set passes ----------------
# Without this, every assertion below is satisfied by a validator that reds on everything.
if ev "$VALIDATOR" "$CLEAN" "$SPEC_SRC" >/dev/null 2>&1; then
  ok "positive control: every token the spec publishes passes"
else
  bad "the check reds on entries using only the published set — it would fail every gate: $(ev "$VALIDATOR" "$CLEAN" "$SPEC_SRC" 2>&1 | grep FAIL | head -1)"
fi

# --- Assertion 2: THE DEFECT — out-of-vocabulary tokens FAIL -----------------
OUT="$(ev "$VALIDATOR" "$DRIFT" "$SPEC_SRC" 2>&1)"; rc=$?
if [ "$rc" -eq 1 ] && grep -q "FILED" <<<"$OUT" && grep -q "OPEN" <<<"$OUT"; then
  ok "drifted entries FAIL (rc=1) and both offending tokens are named"
else
  bad "out-of-vocabulary entries did not fail as expected (rc=$rc): $(printf '%s' "$OUT" | head -2 | tr '\n' ' ')"
fi

# --- Assertion 3: the count is exact, not approximate ------------------------
# 3 entries, 2 of them bad. A validator that reports "some" rather than which is not
# actionable, and one that over-counts is a validator nobody will keep enabled.
if grep -q "FAIL: 2 of 3 escalation entries" <<<"$OUT"; then
  ok "reports exactly 2 of 3 entries out of vocabulary"
else
  bad "wrong count: $(printf '%s\n' "$OUT" | grep 'of .* escalation entries' | head -1)"
fi

# --- Assertion 4: a Status field NOT at line start is still caught ------------
# The naive validator anyone writes first anchors `**Status:**` to line start. Check 2 has
# no such blind spot — it reads the entry — so a mid-entry token is just as silently
# skipped, and a checker that misses it reports a green it did not earn.
if ! ev "$VALIDATOR" "$MIDENTRY" "$SPEC_SRC" >/dev/null 2>&1; then
  ok "a mid-entry **Status:** token outside the set is caught (not only line-anchored ones)"
else
  bad "a mid-entry out-of-vocabulary token passed — the check has the line-anchored blind spot"
fi

# --- Assertion 5: THE DESIGN CLAIM — the set is DERIVED, not restated ---------
# This is the assertion that distinguishes this validator from the hand-listed copy it
# replaces. Add FILED to escalations.md's terminal-status line and the SAME drifted file
# must now pass. If it still fails, the script is carrying its own private set and the
# derivation is decoration.
SPEC_MUT="$WORK/escalations-mutant.md"
# APPEND to whatever the line publishes; do not restate its current contents. This
# anchor used to carry the literal `RESOLVED | OVERRIDDEN`, which made the fixture go
# STALE the moment a token was added to the published set — a hand-listed copy of the
# very set this fixture exists to prove is DERIVED. Insert before the closing backtick
# instead, so the mutant widens the vocabulary whatever it currently holds.
sed 's/^\(\*\*Terminal statuses\*\*.*\)`$/\1 | FILED | OPEN`/' \
  "$SPEC_SRC" > "$SPEC_MUT"
if ! grep -q 'FILED | OPEN' "$SPEC_MUT"; then
  bad "FIXTURE STALE: could not extend the terminal-status line — escalations.md's '**Terminal statuses**' line was reworded"
elif ev "$VALIDATOR" "$DRIFT" "$SPEC_MUT" >/dev/null 2>&1; then
  ok "widening escalations.md's published set makes the same entries pass — the vocabulary is read, not restated"
else
  bad "the drifted file STILL fails after escalations.md was widened — the script carries a private set and 'derived' is decoration"
fi

# --- Assertion 6: MUTANT — narrowing the source must break the clean file -----
# The other direction. If the derivation ignored the format block, the clean file would
# pass no matter what that line says.
SPEC_NARROW="$WORK/escalations-narrow.md"
sed 's/^\*\*Status:\*\* HARD_BLOCK.*/**Status:** HARD_BLOCK/' "$SPEC_SRC" > "$SPEC_NARROW"
if ! grep -qx '\*\*Status:\*\* HARD_BLOCK' "$SPEC_NARROW"; then
  bad "FIXTURE STALE: could not narrow the entry-format Status line — escalations.md's format block was reworded"
elif ! ev "$VALIDATOR" "$CLEAN" "$SPEC_NARROW" >/dev/null 2>&1; then
  ok "narrowing the format block's Status line reds the clean file — BOTH source lines are read"
else
  bad "the clean file still passes with DECIDED_AUTONOMOUSLY/DEFERRAL_REQUEST removed from the source — the format block is not being read"
fi

# --- Assertion 7: unreadable vocabulary source REFUSES, never passes ----------
# A validator that falls back to a built-in set when it cannot read escalations.md has
# reintroduced the hand-listed copy silently. Exit 2 (refusal), not 0 (clean).
# The lone copy sits at $LONE/core/scripts/ (its counted relative path), alone: nothing beside it, no marker above
# it, so it is severed from escalations.md exactly as a copy directly in $LONE was.
LONE="$WORK/lone"; mkdir -p "$LONE/core/scripts"
LONE_V="$LONE/$ESV_REL"
cp "$VALIDATOR" "$LONE_V"
src_esv "$LONE_V"
LONE_OUT="$(cd "$LONE" && unset AI_DLC_PROJECT_ROOT && export CLAUDE_PROJECT_DIR="$LONE" && ev "$LONE_V" "$DRIFT" 2>&1)"
lone_rc=$?
if [ "$lone_rc" -eq 2 ] && grep -q "will not guess" <<<"$LONE_OUT"; then
  ok "with escalations.md unreachable the check REFUSES (rc=2) instead of passing"
else
  bad "severed from its vocabulary source the check returned rc=$lone_rc — it guessed a built-in set or reported clean"
fi

# --- Assertion 7b: the SCRIPT-relative escalations.md is found beside the copy that is running ----------
# The validator's last candidate is <its own dir>/../skills/ai-dlc/escalations.md, and its own dir is read through
# BASH_SOURCE[0]. Run in process, `$0` names this fixture, so a validator reading `$0` looks beside run.sh, finds
# nothing and refuses (exit 2). Here the project root is pinned to the empty $LONE, so the first two candidates are
# absent and only the script-relative one can supply the vocabulary: the drifted file must then be JUDGED (exit 1).
SIB="$WORK/sib"; mkdir -p "$SIB/core/scripts" "$SIB/core/skills/ai-dlc"
SIB_V="$SIB/$ESV_REL"
cp "$VALIDATOR" "$SIB_V"; cp "$SPEC_SRC" "$SIB/core/skills/ai-dlc/escalations.md"
src_esv "$SIB_V"
SIB_OUT="$(export AI_DLC_PROJECT_ROOT="$LONE" && ev "$SIB_V" "$DRIFT" 2>&1)"; sib_rc=$?
if [ "$sib_rc" -eq 1 ] && grep -qF 'out-of-vocabulary status' <<<"$SIB_OUT"; then
  ok "the escalations.md beside the running copy supplies the vocabulary when the root has none (rc=1, judged)"
else
  bad "with the root pinned to an empty dir the copy did not read the escalations.md beside it (rc=$sib_rc): $(printf '%s' "$SIB_OUT" | head -1)"
fi

# --- Assertions 8-10: WHICH occurrence of `**Status:**` is the entry's status -----
# Assertion 4 above establishes that a non-line-start token is READ. These three establish
# which one is ADJUDICATED when an entry carries more than one, and each is a PAIR: the
# offender must be reported, the near-miss must not.
#
# `rc_tok <file>` -> sets RC to the validator's exit and TOK to the token it named, so an
# arm can assert the token and not merely the verdict. NOT a printing function called
# through `$( )`: a command substitution runs in a SUBSHELL and the exit code assigned
# inside it never reaches the caller, which would make every arm here read 0.
RC=0; TOK=""
rc_tok() {
  local out
  src_esv "$VALIDATOR"
  out="$(ev "$VALIDATOR" "$1" "$SPEC_SRC" 2>&1)"; RC=$?
  TOK="$(sed -n "s@.*out-of-vocabulary status '\([^']*\)'.*@\1@p" <<<"$out" | head -1)"
}

# --- Assertion 8: (a) an APPENDED resolution is the token adjudicated -------------
# escalations.md prescribes append-do-not-overwrite and sets the terminal status in a later
# edit, so a resolved entry's live status is its LAST field and the authorship token above
# it is the one it REPLACED. A first-wins reader adjudicates the replaced token and reports
# PASS on the appended one — in the validator whose entire job is rejecting it.
rc_tok "$APPENDED"
if [ "$RC" -eq 1 ] && [ "$TOK" = "$BAD_TOK" ]; then
  ok "(a) an appended resolution status is the token adjudicated"
else
  bad "(a) an appended out-of-vocabulary resolution was not adjudicated (rc=$RC, token '${TOK:-none}') — the reader takes the token the resolution REPLACED"
fi
rc_tok "$APPENDED_OK"
if [ "$RC" -eq 0 ]; then
  ok "(a) near-miss: an appended IN-vocabulary resolution is quiet"
else
  bad "(a) near-miss: an appended legitimate resolution was reported (rc=$RC, token '${TOK:-none}') — the check reds on a correctly resolved entry"
fi

# --- Assertion 9: (b) prose ABOVE the field does not outrank it -------------------
# The match is deliberately not line-anchored (assertion 4), so under first-wins a
# `**Status:**` written inside a sentence SHIELDS the real field beneath it: the widening
# catches a case it also creates. The near-miss carries the same two tokens swapped, so a
# reader that simply prefers prose fails it rather than passing both.
rc_tok "$PROSE_ABOVE"
if [ "$RC" -eq 1 ] && [ "$TOK" = "$BAD_TOK" ]; then
  ok "(b) prose **Status:** ABOVE the field does not outrank the field"
else
  bad "(b) a bad field below a prose **Status:** was not adjudicated (rc=$RC, token '${TOK:-none}') — prose is SHIELDING the field"
fi
rc_tok "$PROSE_ABOVE_OK"
if [ "$RC" -eq 0 ]; then
  ok "(b) near-miss: a bad token in prose above a good field is not adjudicated"
else
  bad "(b) near-miss: prose above the field was adjudicated (rc=$RC, token '${TOK:-none}') — a mention is being read as the field"
fi

# --- Assertion 10: (d) prose BELOW the field, AND THE NEAR-MISS IS THE WHOLE ARM ---
# THE OFFENDER ALONE DOES NOT DISCRIMINATE HERE, AND THAT IS WHY BOTH HALVES ARE ASSERTED
# AND WHY THE OFFENDER'S ARM READS THE TOKEN. The shipped reading and the minimal
# last-match-ANYWHERE one BOTH exit 1 on the offender — one on the entry's real bad field,
# the other on a junk token it extracted from the prose. Right verdict, wrong reason, and
# an arm reading only the exit code scores them identically.
#
# The near-miss is where they part: a GOOD field with prose below it. The shipped reading is
# quiet; last-anywhere reads the token `I` out of "It therefore" and emits a FALSE FINDING.
# That shape is the reference consumer's own pending.md, so this is the arm standing between
# the gate and a finding against a correctly-filed entry.
rc_tok "$PROSE_BELOW_OK"
if [ "$RC" -eq 0 ]; then
  ok "(d) THE DISCRIMINATING NEAR-MISS: a good field with prose below it is quiet"
else
  bad "(d) a correctly-filed entry with prose below its field was REPORTED (rc=$RC, token '${TOK:-none}') — a last-match-ANYWHERE reader is extracting a word out of the prose and failing the gate on it"
fi
rc_tok "$PROSE_BELOW"
if [ "$RC" -eq 1 ] && [ "$TOK" = "$BAD_TOK" ]; then
  ok "(d) prose **Status:** BELOW the field does not outrank it — and the token named is the FIELD's"
else
  bad "(d) the entry was judged on something other than its field (rc=$RC, token '${TOK:-none}', wanted '$BAD_TOK') — an exit 1 here is not evidence the field was read"
fi

# --- THE MUTANTS. Four properties, and no arm above proves ITSELF load-bearing ------
# Assertions 8-10 each have an offender and a near-miss, which establishes that the arm
# discriminates between two inputs — not that it discriminates at all. Only a mutant
# establishes the second, so every candidate reading of `**Status:**` that a later hand
# might take for a simplification is BUILT here and scored.
#
# Each mutant is keyed on ONE line of the awk record-builder and probed on ONE input, owned
# by ONE arm. The `cmp -s` guard turns a mutation that matched nothing into a loud BAD: an
# unmutated copy answers the baseline on every probe and scores a survival that reads
# exactly like a working arm.
#
# THE MUTATIONS ARE APPLIED BY AWK PROGRAMS, NOT BY `sed` SUBSTITUTIONS. The replacement
# text is awk source carrying `&` and backslashes, and an `&` in a sed replacement is the
# whole matched line — a mutation that silently re-inserts the line inside itself applies
# cleanly, passes `cmp -s`, and tests nothing.
MUTD="$WORK/mut"; mkdir -p "$MUTD"

# The CONTROL is presence-shaped and runs FIRST. A copy that cannot run at all reports
# nothing, and an arm reading only "the offender was not reported" would score that silence
# as a kill on every mutant below.
MCTL="$MUTD/control/$ESV_REL"; mkdir -p "${MCTL%/*}"
cp "$VALIDATOR" "$MCTL"
src_esv "$MCTL"
rc_ctl_bad=0; rc_ctl_ok=0
ev "$MCTL" "$PROSE_BELOW" "$SPEC_SRC" >/dev/null 2>&1; rc_ctl_bad=$?
ev "$MCTL" "$PROSE_BELOW_OK" "$SPEC_SRC" >/dev/null 2>&1; rc_ctl_ok=$?
if [ "$rc_ctl_bad" -eq 1 ] && [ "$rc_ctl_ok" -eq 0 ]; then
  ok "mutant control: an unmutated copy REPORTS the offender and stays quiet on the near-miss"
  B_MCTL=1
else
  bad "mutant control: an unmutated copy answered offender=$rc_ctl_bad near-miss=$rc_ctl_ok — the mutants below would be scoring the harness, not the reader"
fi

# name | awk program | probe file | the exit the mutant must produce | the arm that owns it
MUT_NAMES="canon-guard-deleted line-anchored first-canonical-wins first-wins-outright"

mut_prog() {  # <name> -> writes the awk program for that mutant to stdout
  case "$1" in
    # (d): drop the guard entirely and the reader becomes LAST ANYWHERE.
    canon-guard-deleted) cat <<'AWKP'
/^[[:space:]]*if \(canon && / { hits++; next }
{ print }
AWKP
      ;;
    # (M): anchor the rule's own pattern to line start. This is the candidate that reads
    # most like a tightening, and assertion 4 is the only thing in the repo that refuses it.
    line-anchored) cat <<'AWKP'
$0 == "  /\\*\\*[Ss]tatus:\\*\\*/ {" { hits++; print "  /^\\*\\*[Ss]tatus:\\*\\*/ {"; next }
{ print }
AWKP
      ;;
    # (a): keep the field-vs-prose distinction but take the FIRST field.
    first-canonical-wins) cat <<'AWKP'
/^[[:space:]]*if \(canon && / { hits++; print "    if (canon) next"; next }
{ print }
AWKP
      ;;
    # (b): the state this change replaced — first occurrence anywhere wins.
    first-wins-outright) cat <<'AWKP'
/^[[:space:]]*if \(canon && / { hits++; print "    if (status != \"\") next"; next }
{ print }
AWKP
      ;;
  esac
}

# THE SEVEN READER ARMS, the readings assertions 4 and 8-10 hold, as one predicate over a copy:
# rarm <arm> <copy> -> 0 when the arm's expectation HOLDS on that copy (GREEN), 1 when it is TRIPPED. The offender
# arms also demand the token named is the FIELD's (BAD_TOK), as assertions 8-10 do.
R_ARMS="a-off a-near b-off b-near d-off d-near M-mid"
rarm() {
  local a="$1" c="$2" f="" want="" o r t
  case "$a" in
    a-off) f="$APPENDED"; want=bad ;;      a-near) f="$APPENDED_OK"; want=0 ;;
    b-off) f="$PROSE_ABOVE"; want=bad ;;   b-near) f="$PROSE_ABOVE_OK"; want=0 ;;
    d-off) f="$PROSE_BELOW"; want=bad ;;   d-near) f="$PROSE_BELOW_OK"; want=0 ;;
    M-mid) f="$MIDENTRY"; want=nonzero ;;
    *) echo "FIXTURE BROKEN: unknown reader arm $a" >&2; exit 2 ;;
  esac
  o="$(ev "$c" "$f" "$SPEC_SRC" 2>&1)"; r=$?
  t="$(sed -n "s@.*out-of-vocabulary status '\([^']*\)'.*@\1@p" <<<"$o" | head -1)"
  case "$want" in
    0) [ "$r" -eq 0 ] ;;
    nonzero) [ "$r" -ne 0 ] ;;
    bad) [ "$r" -eq 1 ] && [ "$t" = "$BAD_TOK" ] ;;
  esac
}
mx_row() { grep -m 1 -F -- "# MUTANT-MATRIX $1 decides=" "$HERE/run.sh"; }
mx_field() { local l; l="$(mx_row "$1")"; l="${l#*"$2"=}"; printf '%s' "${l%% *}"; }
# The unmutated control copy's reading of every reader arm, so each kill is scored only where the arm it trips HELD
# on the same harness in this run (the base-pass flag mutant_killed requires).
src_esv "$MCTL"
for _ra in $R_ARMS; do
  if rarm "$_ra" "$MCTL"; then eval "RB_$(printf '%s' "$_ra" | tr '-' '_')=1"; else eval "RB_$(printf '%s' "$_ra" | tr '-' '_')=0"; fi
done
rb() { eval "printf '%s' \"\${RB_$(printf '%s' "$1" | tr '-' '_'):-0}\""; }
_rb_all=1; for _ra in $R_ARMS; do [ "$(rb "$_ra")" = 1 ] || _rb_all=0; done
if [ "$_rb_all" = 1 ]; then
  ok "baseline (unmutated control copy): all seven reader arms hold, so a reader mutant's tripped arm is the mutation's"; B_READERS=1
else bad "baseline (unmutated control copy): a reader arm does not hold on the control copy -- every reader mutant verdict below is void"; fi

# --- THE CWD-INVARIANCE ARM (BL-1007): the control's vector is the same from `/` and from the root -----------------
# The copies carry no marker above them, so a copy that resolves its root from the cwd answers rc 2 from `/` and the
# real verdict from the root. Offender then near-miss on the unmutated control copy, from each cwd; the whole
# vector is "<from />,<from root>" and must read 10,10. The LONE and SIB arms fix their own root, so a two-cwd cell
# of theirs cannot fail and is not coverage here. The mutant restores the cwd-dependent resolution (ESV_NOPIN=1).
cwd_vec() { # cwd_vec <cwd> <copy> <nopin> -> "<offender rc><near-miss rc>"
  ( cd "$1" || exit 9; ESV_NOPIN="$3"
    ev "$2" "$PROSE_BELOW" "$SPEC_SRC" >/dev/null 2>&1; _o=$?
    ev "$2" "$PROSE_BELOW_OK" "$SPEC_SRC" >/dev/null 2>&1; _n=$?
    printf '%s%s' "$_o" "$_n" )
}
CWD_CTL="$(cwd_vec / "$MCTL" 0),$(cwd_vec "$ESV_ROOT" "$MCTL" 0)"
B_CWD=0
if [ "$CWD_CTL" = "10,10" ]; then
  ok "cwd-invariance: the control copy reports the offender and stays quiet on the near-miss from / and from the root alike ($CWD_CTL)"
  B_CWD=1
else
  bad "cwd-invariance: the control copy's vector from / and from the root is $CWD_CTL, wanted 10,10 -- the copies resolve a project root from the cwd"
fi
CWD_MUT="$(cwd_vec / "$MCTL" 1),$(cwd_vec "$ESV_ROOT" "$MCTL" 1)"
if [ "$CWD_MUT" = "$CWD_CTL" ]; then
  bad "MUTANT cwd-unpinned did not apply: the cwd-dependent resolution answers $CWD_MUT, the same vector as the control, so the arm discriminates nothing"
else
  mutant_killed "$B_CWD" "cwd-unpinned" "MUTANT cwd-unpinned killed by the cwd-invariance arm: the cwd-dependent resolution scored $CWD_MUT against the control's $CWD_CTL"
fi
MX_CELLS=0
mut_why() {     # <name> -> which arm owns the kill, and what the mutant costs
  case "$1" in
    canon-guard-deleted)
      printf '%s' "(d)'s near-miss — last-match-ANYWHERE reads a word out of the prose and reports a correctly-filed entry" ;;
    line-anchored)
      printf '%s' "(M), assertion 4 — a mid-entry token goes unexamined, a coverage regression dressed as a tightening" ;;
    first-canonical-wins)
      printf '%s' "(a) — the appended resolution is ignored and the token it REPLACED is adjudicated" ;;
    first-wins-outright)
      printf '%s' "(b)'s near-miss — a prose mention above the field becomes the entry's status. (a) also moves under this mutant and stands down for (b): both are genuinely broken by first-wins, and (b) owns it because the near-miss is the cell no other mutant here reaches" ;;
  esac
}

for mname in $MUT_NAMES; do
  copy="$MUTD/$mname/$ESV_REL"; mkdir -p "${copy%/*}"
  mut_prog "$mname" > "$MUTD/$mname.awk"
  awk -f "$MUTD/$mname.awk" "$VALIDATOR" > "$copy" 2>/dev/null
  if cmp -s "$VALIDATOR" "$copy"; then
    bad "MUTANT $mname — the anchor matched nothing, so no mutation applied and nothing was proven. The awk record-builder was reworded; re-anchor it on the line that spells the rule, never relax the assertion."
    continue
  fi
  src_esv "$copy"
  if [ "$MATRIX" = 1 ]; then
    for _ra in $R_ARMS; do
      MX_CELLS=$((MX_CELLS + 1))
      if rarm "$_ra" "$copy"; then printf '  MATRIX %s %s GREEN\n' "$mname" "$_ra"; else printf '  MATRIX %s %s TRIPPED\n' "$mname" "$_ra"; fi
    done
    continue
  fi
  if [ -z "$(mx_row "$mname")" ]; then bad "MUTANT $mname has no MUTANT-MATRIX row in this file -- a per-push run cannot know its deciding arm or its twin"; continue; fi
  dec="$(mx_field "$mname" decides)"; tw="$(mx_field "$mname" twins)"
  MX_CELLS=$((MX_CELLS + 2))
  if rarm "$dec" "$copy"; then
    bad "MUTANT $mname SURVIVED its deciding arm $dec. The arm that should own this reading is not reading it."
  elif ! rarm "$tw" "$copy"; then
    bad "MUTANT $mname also tripped its twin $tw -- the matrix row for this mutant moved; re-measure with --matrix"
  else
    mutant_killed "$(( ${B_MCTL:-0} && ${B_READERS:-0} ))" "$mname" "MUTANT $mname killed by $(mut_why "$mname")"
  fi
done
# A plain run scores exactly two reader cells per mutant; --matrix scores every arm.
if [ "$MATRIX" = 1 ]; then
  [ "$MX_CELLS" -eq 28 ] && ok "MX matrix run measured $MX_CELLS reader mutant x arm cells (4 mutants x 7 arms)" \
    || bad "MX matrix run measured $MX_CELLS reader cells, 28 expected"
else
  [ "$MX_CELLS" -eq 8 ] && ok "MX matrix, per-push run: $MX_CELLS reader cells scored, each mutant's deciding arm and its twin only" \
    || bad "MX per-push run scored $MX_CELLS reader cells, 8 expected"
fi

# --- Assertions 11-15: an EMPTY file is the ABSENT state, and only an empty one -----
# A file that exists and holds no non-whitespace byte used to fall through to the parser and
# print `OK: n=[] no **Status:** entries found` -- the same line a POPULATED file whose entries
# carry no `**Status:**` field prints. The first is nothing to examine; the second is a
# grammar failure over live entries. Only the first may say EXAMINED NOTHING.
#
# FIVE CELLS, SCORED AS ONE STRING, so a mutant can be held to moving ONLY its own cell:
#   A empty                rc 0, the token, and the "present but empty" reason
#   B whitespace           the same -- a `[ -s ]` fix calls this file populated and fails here
#   C absent               rc 0, the token, the absent-file reason, NOT the empty one (unchanged)
#   D populated-zero-record  heading-only AND the bullet-entry shape: rc 0, the `n=[]` line,
#                          NO token. One cell, because no zero-record predicate can move one of
#                          the two without the other.
#   E finding              the drifted file: rc 1 (unchanged)
# Every cell is presence-shaped on at least one conjunct, so a subject that prints nothing
# fails every one of them.
VEN_CELLS=""
ven_cells() {  # <validator> -> sets VEN_CELLS
  local v="$1" o o2 rc rc2 c=""
  src_esv "$v"
  o="$(ev "$v" "$EMPTY" "$SPEC_SRC" 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 0 ] && grep -qF "EXAMINED NOTHING" <<<"$o" && grep -qF "present but empty" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  o="$(ev "$v" "$BLANK" "$SPEC_SRC" 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 0 ] && grep -qF "EXAMINED NOTHING" <<<"$o" && grep -qF "present but empty" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  o="$(ev "$v" "$WORK/pending-never-written.md" "$SPEC_SRC" 2>/dev/null)"; rc=$?
  if [ "$rc" -eq 0 ] && grep -qF "EXAMINED NOTHING" <<<"$o" && grep -qF "no escalations file" <<<"$o" \
     && ! grep -qF "present but empty" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  o="$(ev "$v" "$HEADING" "$SPEC_SRC" 2>/dev/null)"; rc=$?
  o2="$(ev "$v" "$UNPARSED" "$SPEC_SRC" 2>/dev/null)"; rc2=$?
  if [ "$rc" -eq 0 ] && [ "$rc2" -eq 0 ] && ! grep -qF "EXAMINED NOTHING" <<<"$o$o2" \
     && grep -qF "n=[]" <<<"$o" && grep -qF "n=[]" <<<"$o2"; then c="${c}1"; else c="${c}0"; fi
  o="$(ev "$v" "$DRIFT" "$SPEC_SRC" 2>&1)"; rc=$?
  if [ "$rc" -eq 1 ] && grep -qF "out-of-vocabulary status" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  VEN_CELLS="$c"
}
# vec_score <label> <got vector> <want vector> <base flag> <pass message> <fail message> -- one FULL-row mutant scored
# on its battery's whole cell vector, through mutant_killed. The name is the label's second word. Every caller fills
# the flag with a $(( )) conjunction of the B_ flags its battery's baseline and control set beside their own ok. The
# messages are each battery's own, unchanged. --matrix also prints the vector.
vec_score() {
  local n="${1#MUTANT }"; n="${n%% *}"
  [ "$MATRIX" = 1 ] && printf '  MATRIX %s FULL %s\n' "$n" "$2"
  if [ "$2" = "$3" ]; then mutant_killed "$4" "$n" "$5"; return 0; fi
  bad "$6"; return 1
}
VEN_IS_DIST=0
case "$(cd "$(dirname "$VALIDATOR")" && pwd)" in */core/scripts) VEN_IS_DIST=1 ;; esac
ven_cells "$VALIDATOR"
VEN_REAL="$VEN_CELLS"
# A SUBJECT THAT PREDATES THE FIX. This fixture ships and can reach a consumer one pull ahead of
# the validator: cells A and B read 0 and nothing else moves. SKIP there; FAIL here.
if [ "$(printf '%s' "$VEN_CELLS" | cut -c1-2)" = "00" ] && [ "$(printf '%s' "$VEN_CELLS" | cut -c3-5)" = "111" ] \
   && [ "$VEN_IS_DIST" -ne 1 ]; then
  printf '  SKIP  the empty-file arms -- the installed validator predates the empty-file verdict; this fixture ships one pull ahead of it\n'
else
  i=0
  for nm in "A empty file" "B whitespace-only file" "C absent file (unchanged)" \
            "D populated file parsing to zero records carries NO token" "E a real finding still exits 1"; do
    i=$((i + 1))
    if [ "$(printf '%s' "$VEN_CELLS" | cut -c"$i")" = "1" ]; then ok "empty-file cell $nm"
    else bad "empty-file cell $nm does not hold (cells=$VEN_CELLS)"; fi
  done
  if [ "$VEN_REAL" = 11111 ]; then ok "baseline (unmutated validator): all five empty-file cells hold, so the battery's mutants are scored"; B_VEN=1; fi

  # --- the mutants, each in a copy of the WHOLE scripts dir, with an unmutated control ------
  VEN_SRC_DIR="$(cd "$(dirname "$VALIDATOR")" && pwd)"
  VEN_BASE="$(basename "$VALIDATOR")"
  VEN_MW="$WORK/empty-mut"; mkdir -p "$VEN_MW"
  # ven_mk RUNS INSIDE `$( )`, so it cannot call `bad`: the failure count it bumped would die
  # with the subshell and a mutant that never built would score nothing at all. It writes its
  # reason to VEN_MW/<name>.why and prints no path; ven_score reads the empty path and fails.
  ven_mk() {  # <name> <literal anchor, exactly one line, or empty for the control> <replacement file>
    # The scripts dir is copied to <d>/core/scripts, so the copy keeps the subject's counted relative path.
    local d="$VEN_MW/$1" n s
    s="$d/core/scripts"
    mkdir -p "$d/core" && cp -R "$VEN_SRC_DIR" "$s" || { echo "could not copy $VEN_SRC_DIR" > "$VEN_MW/$1.why"; return 1; }
    [ -n "$2" ] || { printf '%s\n' "$s/$VEN_BASE"; return 0; }
    n="$(grep -cF -- "$2" "$VALIDATOR")" || n=0
    [ "$n" -eq 1 ] || { echo "anchor matches $n line(s), not 1 -- re-anchor it, never relax the arm" > "$VEN_MW/$1.why"; return 1; }
    awk -v A="$2" -v R="$3" '
      index($0, A) { while ((getline l < R) > 0) print l; close(R); next }
      { print }' "$VALIDATOR" > "$s/$VEN_BASE"
    if cmp -s "$VALIDATOR" "$s/$VEN_BASE"; then echo "changed no bytes -- it would score as a kill" > "$VEN_MW/$1.why"; return 1; fi
    bash -n "$s/$VEN_BASE" 2>/dev/null || { echo "does not parse" > "$VEN_MW/$1.why"; return 1; }
    printf '%s\n' "$s/$VEN_BASE"
  }
  ven_score() {  # <name> <path-or-empty> <want> <why> <mk-name>
    if [ -z "$2" ]; then bad "$1 was never built: $(cat "$VEN_MW/$5.why" 2>/dev/null || echo 'no reason recorded')"; return 0; fi
    ven_cells "$2"
    if [ "$5" = control ]; then
      if [ "$VEN_CELLS" = "$3" ]; then ok "$1 scored $VEN_CELLS -- $4"; B_VENC=1
      else bad "$1 scored $VEN_CELLS, wanted $3 -- $4"; fi
      # THE CWD-INVARIANCE ARM, whole-directory control: the same five cells from `/` (BL-1007), and the unpinned
      # resolution (ESV_NOPIN=1) from `/` must move the vector, so a pin dropped from this copy alone is caught.
      VEN_CWD="$(cd / && ven_cells "$2" && printf '%s' "$VEN_CELLS")"
      if [ "$VEN_CWD" = "$3" ]; then ok "cwd-invariance: the whole-directory control scores $VEN_CWD from / as from the root"; B_VENCWD=1
      else bad "cwd-invariance: the whole-directory control scores $VEN_CWD from /, wanted $3"; fi
      VEN_CWDM="$(cd / && ESV_NOPIN=1 && ven_cells "$2" && printf '%s' "$VEN_CELLS")"
      if [ "$VEN_CWDM" = "$3" ]; then bad "MUTANT cwd-unpinned-ven did not apply: the cwd-dependent resolution still scores $VEN_CWDM from /"
      else mutant_killed "${B_VENCWD:-0}" "cwd-unpinned-ven" "MUTANT cwd-unpinned-ven killed by the whole-directory cwd arm: the cwd-dependent resolution scored $VEN_CWDM from / against $3"; fi
      return 0
    fi
    vec_score "$1" "$VEN_CELLS" "$3" "$(( ${B_VEN:-0} && ${B_VENC:-0} ))" \
      "$1 scored $VEN_CELLS -- $4" "$1 scored $VEN_CELLS, wanted $3 -- $4"
    return 0
  }
  printf '%s\n' 'if false; then' > "$VEN_MW/r-revert"
  printf '%s\n' 'if [ -z "$RECORDS" ]; then echo "OK: EXAMINED NOTHING — zero parsed records ($ESCALATIONS)."; exit 0; fi' \
                'if [ -z "$RECORDS" ]; then' > "$VEN_MW/r-zero"
  VEN_CTL="$(ven_mk control "" "")" || VEN_CTL=""
  ven_score "MUTANT control (unmutated whole-dir copy)" "$VEN_CTL" 11111 "every cell holds, so a mutant's red cell is the mutation's" control
  VEN_M1="$(ven_mk revert 'if [ "$ESC_BLANK_RC" -eq 1 ]; then' "$VEN_MW/r-revert")" || VEN_M1=""
  ven_score "MUTANT M-revert" "$VEN_M1" 00111 "the fix removed: ONLY the empty and whitespace cells go red" revert
  VEN_M2="$(ven_mk zero-records 'if [ -z "$RECORDS" ]; then' "$VEN_MW/r-zero")" || VEN_M2=""
  ven_score "MUTANT M-zero-records" "$VEN_M2" 11101 "zero parsed records read as empty: ONLY the populated-zero-record cell goes red" zero-records
fi

# --- Assertions 16-18: at Checks 2 and 2a, `OK: EXAMINED NOTHING` IS a pass ----------------
# The escalations file exists only once something has been escalated, so its absence is
# exactly Check 2's predicate holding: no unresolved HARD_BLOCK. The three scripts have always
# said so. The enforcement map's postures for these two checks said the opposite -- "is not a
# pass, nothing was verified", the reading that is RIGHT at Checks 26/33/35, whose corpus must
# exist -- and the step text said nothing at all, so an adjudicator reading the map would fail
# every consumer that has never escalated.
#
# THREE CELLS, one per artifact an adjudicator reads, each scored over a FLATTENED section so a
# re-wrap of the prose cannot move a cell:
#   A gate-validation.md Check 2 section: states the absent/empty PASS, names the printed line,
#     and carries no "is not a pass"
#   B gate-validation.md Check 2a section: the same
#   C enforcement-map.yaml rows 2 and 2a: exactly three postures say IS a pass, none says
#     "is not a pass"
# Every cell is presence-shaped on its first conjunct, so an unreadable or missing file fails
# it rather than acquitting it.
EN_DIR="$(cd "$(dirname "$SPEC_SRC")" && pwd)"
EN_GV="$EN_DIR/steps/gate-validation.md"
EN_MAP="$EN_DIR/enforcement-map.yaml"
EN_PASS='IS a pass, because no escalation exists to be unresolved'
EN_CELLS=""
en_flat() {  # <file> <start-regex> <end-regex> -> the lines from start up to (not incl.) end, on one line
  awk -v s="$2" -v e="$3" '$0 ~ s { on = 1; print; next } on && $0 ~ e { exit } on { print }' "$1" 2>/dev/null \
    | tr '\n' ' ' | tr -s ' '
}
en_step_cell() {  # <flattened section> -> 1 or 0
  if grep -qF "An absent or empty \`pending.md\` is a PASS." <<<"$1" && grep -qF "$EN_PASS" <<<"$1" \
     && grep -qF 'OK: EXAMINED NOTHING' <<<"$1" && ! grep -qF 'is not a pass' <<<"$1"; then echo 1; else echo 0; fi
}
en_cells() {  # <gate-validation.md> <enforcement-map.yaml> -> sets EN_CELLS
  local s2 s2a m n
  s2="$(en_flat "$1" '^### 2\. ' '^### 2a\. ')"
  s2a="$(en_flat "$1" '^### 2a\. ' '^### 3\. ')"
  m="$(en_flat "$2" '^  - id: "2"$' '^  - id: "3"$')"
  n="$(grep -oF "$EN_PASS" <<<"$m" | grep -c .)" || n=0
  EN_CELLS="$(en_step_cell "$s2")$(en_step_cell "$s2a")"
  if [ "$n" -eq 3 ] && ! grep -qF 'is not a pass' <<<"$m"; then EN_CELLS="${EN_CELLS}1"; else EN_CELLS="${EN_CELLS}0"; fi
}
if [ ! -f "$EN_GV" ] || [ ! -f "$EN_MAP" ]; then
  bad "Checks 2/2a posture arms cannot run: gate-validation.md or enforcement-map.yaml is not beside $SPEC_SRC"
else
  en_cells "$EN_GV" "$EN_MAP"
fi
EN_REAL="$EN_CELLS"
# A TREE THAT PREDATES THE RULING. This fixture ships, and a consumer can run it against step
# and map files installed before the ruling: all three cells read 0. SKIP there; FAIL here.
if [ -f "$EN_GV" ] && [ -f "$EN_MAP" ] && [ "$EN_CELLS" = "000" ] && [ "$VEN_IS_DIST" -ne 1 ]; then
  printf '  SKIP  the Checks 2/2a posture arms -- the installed step and map files predate the absent-file-is-a-pass reading\n'
elif [ -f "$EN_GV" ] && [ -f "$EN_MAP" ]; then
  i=0
  for nm in "A Check 2's step text states an absent or empty pending.md is a PASS" \
            "B Check 2a's step text states an absent or empty pending.md is a PASS" \
            "C the map's three Check 2/2a postures say OK: EXAMINED NOTHING IS a pass"; do
    i=$((i + 1))
    if [ "$(printf '%s' "$EN_CELLS" | cut -c"$i")" = "1" ]; then ok "posture cell $nm"
    else bad "posture cell $nm does not hold (cells=$EN_CELLS)"; fi
  done
  if [ "$EN_REAL" = 111 ]; then ok "baseline (unmutated step and map files): all three posture cells hold, so the posture mutants are scored"; B_EN=1; fi

  # --- the mutants restore the old reading, each in ONE artifact, in copies ----------------
  EN_MW="$WORK/posture-mut"; mkdir -p "$EN_MW"
  en_mut() {  # <name> <file> <literal-anchor> <replacement> -> prints the copy, or nothing
    local n
    n="$(grep -cF -- "$3" "$2")" || n=0
    [ "$n" -ge 1 ] || { echo "anchor matches 0 line(s) of $(basename "$2")" > "$EN_MW/$1.why"; return 1; }
    awk -v A="$3" -v R="$4" '{ i = index($0, A); if (i) $0 = substr($0, 1, i - 1) R substr($0, i + length(A)); print }' \
      "$2" > "$EN_MW/$1"
    if cmp -s "$2" "$EN_MW/$1"; then echo "changed no bytes" > "$EN_MW/$1.why"; return 1; fi
    printf '%s\n' "$EN_MW/$1"
  }
  en_score() {  # <label> <gv> <map> <want> <why> <mk-name>
    if [ -z "$2" ] || [ -z "$3" ]; then bad "$1 was never built: $(cat "$EN_MW/$6.why" 2>/dev/null || echo 'no reason recorded')"; return 0; fi
    en_cells "$2" "$3"
    vec_score "$1" "$EN_CELLS" "$4" "$(( ${B_EN:-0} ))" \
      "$1 scored $EN_CELLS -- $5" "$1 scored $EN_CELLS, wanted $4 -- $5"
    return 0
  }
  # The step-text sentence is wrapped identically in both sections, so the anchor is each
  # section's OWN lead-in, which differs: Check 2's is a bullet, Check 2a's is a paragraph.
  EN_M1="$(en_mut gv-2 "$EN_GV" '- **An absent or empty `pending.md` is a PASS.** Both scripts' \
    '- **An absent or empty `pending.md` is not a pass, nothing was verified.** Both scripts')" || EN_M1=""
  en_score "MUTANT M-step-2 (Check 2 restores 'is not a pass')" "$EN_M1" "$EN_MAP" 011 "ONLY Check 2's step cell goes red" gv-2
  EN_M2="$(en_mut gv-2a "$EN_GV" '**An absent or empty `pending.md` is a PASS.** The script' \
    '**An absent or empty `pending.md` is not a pass, nothing was verified.** The script')" || EN_M2=""
  en_score "MUTANT M-step-2a (Check 2a restores 'is not a pass')" "$EN_M2" "$EN_MAP" 101 "ONLY Check 2a's step cell goes red" gv-2a
  EN_M3="$(en_mut map "$EN_MAP" 'with entries_scanned=0 when no escalations file exists or it holds nothing — IS a pass,' \
    'with entries_scanned=0 when no escalations file exists or it holds nothing — is not a pass, nothing was verified,')" || EN_M3=""
  en_score "MUTANT M-map (one Check 2 posture restores 'is not a pass')" "$EN_GV" "$EN_M3" 110 "ONLY the map cell goes red" map
fi

# fx_sub <src> <out> <anchor> <replacement> [<anchor> <replacement>]... -- a COPY of <src> with each
# anchor, which must sit on EXACTLY ONE line, replaced as a literal substring. Sets FX_WHY and returns
# 1 when an anchor matches 0 or 2+ lines or the copy is byte-identical. The strings reach awk through
# ENVIRON, never `-v`, because `-v` strips one level of backslash escaping.
FX_WHY=""
fx_sub() {
  local src="$1" out="$2" n
  shift 2
  cp "$src" "$out.work" || { FX_WHY="could not copy $src"; return 1; }
  while [ "$#" -ge 2 ]; do
    n="$(grep -cF -- "$1" "$out.work")" || n=0
    [ "$n" -eq 1 ] || { FX_WHY="anchor matches $n line(s), not 1 -- re-anchor it, never relax the arm: $1"; return 1; }
    A="$1" R="$2" awk '{ i = index($0, ENVIRON["A"]); if (i) $0 = substr($0, 1, i - 1) ENVIRON["R"] substr($0, i + length(ENVIRON["A"])); print }' \
      "$out.work" > "$out.next" || { FX_WHY="awk died applying: $1"; return 1; }
    mv "$out.next" "$out.work"
    shift 2
  done
  if cmp -s "$src" "$out.work"; then FX_WHY="changed no bytes -- it would score as a kill"; return 1; fi
  mv "$out.work" "$out"
}

# --- Assertions 19-24: an UNREADABLE or NON-REGULAR escalations path REFUSES, exit 2 ---------------
# `grep -q '[^[:space:]]'` exits 2 on a file it cannot read, and the validator used to branch on
# `-eq 1` alone: a status of 2 fell through, the parser's own read failure was swallowed, and the run
# printed an ordinary `OK: n=[]` line over entries nobody read. A DIRECTORY at the path failed `-f`
# and printed "no escalations file" -- the line Check 2 reads as a pass. Now both refuse: `REFUSED:`
# on stderr, exit 2, nothing on stdout.
#
# SIX CELLS, ONE STRING, so each mutant below is held to moving only the cells its layer owns:
#   A  mode-000 file carrying an out-of-vocabulary entry -> exit 2, `could not be read`
#   B  a DIRECTORY at the path                         -> exit 2, `is not a regular file`
#   C  a DANGLING SYMLINK at the path (fails -e AND -f) -> exit 2, `is not a regular file`
#   D  a READABLE file whose blank probe grep exits 2 (PATH stub; the stub must FIRE)
#                                                      -> exit 2, `failed (grep exited 2)`
#   E  near-miss: a whitespace-only readable file      -> exit 0, the existing "present but empty" line
#   F  near-miss: a readable file with a finding       -> exit 1, unchanged
# A through D are presence-shaped (a REFUSED line must appear), so a subject that prints nothing
# fails them. Cell A is `S` when mode 000 does not stop this process reading -- root does, and the
# guard deliberately does not refuse on the mode bit alone.
VR="$WORK/refusal"; mkdir -p "$VR"
VR_LOCKED="$VR/pending-locked.md"; cp "$DRIFT" "$VR_LOCKED"; chmod 000 "$VR_LOCKED"
VR_DIR="$VR/pending-dir.md"; mkdir -p "$VR_DIR"
VR_LINK="$VR/pending-dangling.md"; ln -s "$VR/pending-target-never-written.md" "$VR_LINK"
VR_IO="$VR/pending-io.md"; cp "$DRIFT" "$VR_IO"
VR_SKIP_A=""
if [ "$(id -u)" -eq 0 ]; then VR_SKIP_A="running as root, which reads a mode-000 file"
elif cat "$VR_LOCKED" >/dev/null 2>&1; then VR_SKIP_A="this host reads a mode-000 file, so the seed cannot express unreadable"; fi
[ -n "$VR_SKIP_A" ] && printf '  SKIP  refusal cell A (mode-000 file) -- %s\n' "$VR_SKIP_A"
if ! { [ -L "$VR_LINK" ] && [ ! -e "$VR_LINK" ]; }; then bad "FIXTURE BROKEN: the dangling-symlink seed is not a link to a missing target"; fi
# THE STUB claims only the blank probe's argv (`-q [^[:space:]] <file>`), logs each claimed call and
# execs the real grep for everything else.
VR_STUB="$VR/stub"; mkdir -p "$VR_STUB"
VR_REALGREP="$(command -v grep)" || { echo "FIXTURE ERROR: grep is not on PATH" >&2; exit 2; }
{
  printf '#!/bin/bash\ncase "$*" in\n'
  printf '  %s) printf "x\\n" >> "%s/LOG"; echo "grep: forced failure" >&2; exit 2 ;;\n' "'-q [^[:space:]] '*" "$VR_STUB"
  printf 'esac\nexec "%s" "$@"\n' "$VR_REALGREP"
} > "$VR_STUB/grep"
chmod +x "$VR_STUB/grep"
VR_RC=0; VR_O=""; VR_E=""
vr_run() {  # <validator> <file> [stub-dir] -> VR_RC VR_O VR_E
  local p="$PATH"
  [ -n "${3:-}" ] && p="$3:$PATH"
  : > "$VR_STUB/LOG"
  VR_O="$(export PATH="$p" && ev "$1" "$2" "$SPEC_SRC" 2>"$VR/err")"; VR_RC=$?
  VR_E="$(cat "$VR/err")"
}
vr_refused() {  # <reason-ERE> -> the last run refused, for that reason, with stdout empty
  [ "$VR_RC" -eq 2 ] && [ -z "$VR_O" ] && grep -qE "^REFUSED: .*$1" <<<"$VR_E"
}
VR_CELLS=""
vr_cells() {  # <validator> -> VR_CELLS
  local v="$1" c=""
  src_esv "$v"
  if [ -n "$VR_SKIP_A" ]; then c="${c}S"
  else vr_run "$v" "$VR_LOCKED"; if vr_refused 'could not be read'; then c="${c}1"; else c="${c}0"; fi; fi
  vr_run "$v" "$VR_DIR";  if vr_refused 'is not a regular file'; then c="${c}1"; else c="${c}0"; fi
  vr_run "$v" "$VR_LINK"; if vr_refused 'is not a regular file'; then c="${c}1"; else c="${c}0"; fi
  vr_run "$v" "$VR_IO" "$VR_STUB"
  if [ -s "$VR_STUB/LOG" ] && vr_refused 'failed \(grep exited 2\)'; then c="${c}1"; else c="${c}0"; fi
  vr_run "$v" "$BLANK"
  if [ "$VR_RC" -eq 0 ] && grep -qF 'present but empty' <<<"$VR_O" && ! grep -qF 'REFUSED' <<<"$VR_O$VR_E"; then c="${c}1"; else c="${c}0"; fi
  vr_run "$v" "$DRIFT"
  if [ "$VR_RC" -eq 1 ] && grep -qF 'out-of-vocabulary status' <<<"$VR_O$VR_E" && ! grep -qF 'REFUSED' <<<"$VR_O$VR_E"; then c="${c}1"; else c="${c}0"; fi
  VR_CELLS="$c"
}
vr_want() { if [ -n "$VR_SKIP_A" ]; then printf 'S%s' "${1#?}"; else printf '%s' "$1"; fi; }
vr_cells "$VALIDATOR"
VR_REAL="$VR_CELLS"
# A SUBJECT THAT PREDATES THE REFUSAL. This fixture ships one pull ahead of the validator: there B, C
# and D read 0 and E, F still hold. SKIP there; FAIL here.
if [ "$(printf '%s' "$VR_CELLS" | cut -c2-4)" = "000" ] && [ "$(printf '%s' "$VR_CELLS" | cut -c5-6)" = "11" ] \
   && [ "$VEN_IS_DIST" -ne 1 ]; then
  printf '  SKIP  the refusal arms -- the installed validator predates the unreadable-file refusal; this fixture ships one pull ahead of it\n'
else
  i=0
  for nm in "A mode-000 file refuses: exit 2, REFUSED could not be read, stdout empty" \
            "B a directory at the path refuses: exit 2, REFUSED is not a regular file" \
            "C a dangling symlink at the path refuses: exit 2, REFUSED is not a regular file" \
            "D a readable file whose blank probe exits 2 refuses: exit 2, REFUSED grep exited 2 (stub fired)" \
            "E near-miss: a whitespace-only readable file is still OK EXAMINED NOTHING, exit 0" \
            "F near-miss: a readable file with a finding still exits 1"; do
    i=$((i + 1))
    case "$(printf '%s' "$VR_CELLS" | cut -c"$i")" in
      1) ok "refusal cell $nm" ;;
      S) ;;
      *) bad "refusal cell $nm does not hold (cells=$VR_CELLS)" ;;
    esac
  done
  if [ "$VR_REAL" = "$(vr_want 111111)" ]; then ok "baseline (unmutated validator): every refusal cell holds, so the refusal mutants are scored"; B_VR=1; fi

  # --- the mutants: one per layer of the guard, plus one reverting EVERY layer ---------------------
  # Each mutant is built from VR_SRC, a copy in ONE copy of the whole scripts directory, into its own
  # $VR/m/<name>/core/scripts/ (the subject sources no sibling, and that path keeps its pass counted); the
  # unmutated control is built the same way, so a copy that cannot run fails the control's presence cells
  # rather than scoring as a kill.
  VR_MD="$VR/mut"
  cp -R "$(cd "$(dirname "$VALIDATOR")" && pwd)" "$VR_MD" || bad "refusal mutants: could not copy the scripts directory"
  VR_SRC="$VR_MD/$(basename "$VALIDATOR")"
  VR_G1='if { [ -e "$ESCALATIONS" ] || [ -L "$ESCALATIONS" ]; } && [ ! -f "$ESCALATIONS" ]; then'
  VR_G1L='{ [ -e "$ESCALATIONS" ] || [ -L "$ESCALATIONS" ]; }'
  VR_G2='if [ "$ESC_BLANK_RC" -gt 1 ]; then'
  VR_G3='if [ ! -r "$ESCALATIONS" ]; then'
  vr_score() {  # <label> <name> <want> <why> <anchor> <replacement> [...]
    local label="$1" name="$2" want out
    want="$(vr_want "$3")"
    shift 4
    out="$VR/m/$name/$ESV_REL"; mkdir -p "${out%/*}"
    if [ "$#" -eq 0 ]; then cp "$VR_SRC" "$out"
    elif ! fx_sub "$VR_SRC" "$out" "$@"; then bad "$label DID NOT APPLY: $FX_WHY"; return 0
    elif ! bash -n "$out" 2>/dev/null; then bad "$label DID NOT APPLY: the mutated copy does not parse"; return 0; fi
    vr_cells "$out"
    if [ "$name" = ctl ]; then
      if [ "$VR_CELLS" = "$want" ]; then ok "$label scored $VR_CELLS"; B_VRC=1
      else bad "$label scored $VR_CELLS, wanted $want"; fi
      # THE CWD-INVARIANCE ARM, refusal control: the same six cells from `/` (BL-1007), and the unpinned resolution
      # (ESV_NOPIN=1) from `/` must move the vector.
      VR_CWD="$(cd / && vr_cells "$out" && printf '%s' "$VR_CELLS")"
      if [ "$VR_CWD" = "$want" ]; then ok "cwd-invariance: the refusal control scores $VR_CWD from / as from the root"; B_VRCWD=1
      else bad "cwd-invariance: the refusal control scores $VR_CWD from /, wanted $want"; fi
      VR_CWDM="$(cd / && ESV_NOPIN=1 && vr_cells "$out" && printf '%s' "$VR_CELLS")"
      if [ "$VR_CWDM" = "$want" ]; then bad "MUTANT cwd-unpinned-vr did not apply: the cwd-dependent resolution still scores $VR_CWDM from /"
      else mutant_killed "${B_VRCWD:-0}" "cwd-unpinned-vr" "MUTANT cwd-unpinned-vr killed by the refusal cwd arm: the cwd-dependent resolution scored $VR_CWDM from / against $want"; fi
      return 0
    fi
    vec_score "$label" "$VR_CELLS" "$want" "$(( ${B_VR:-0} && ${B_VRC:-0} ))" \
      "$label scored $VR_CELLS" "$label scored $VR_CELLS, wanted $want"
    return 0
  }
  vr_score "MUTANT refusal-control (unmutated sibling copy): every cell holds" ctl 111111 ""
  vr_score "MUTANT R-revert-all (every layer removed, grep status 2 falls through): A-D red, E and F hold" \
    revert-all 000011 "" "$VR_G1" 'if false; then' "$VR_G2" 'if false; then'
  vr_score "MUTANT R-nonregular (the -e/-L guard removed): ONLY the directory and symlink cells go red" \
    nonregular 100111 "" "$VR_G1" 'if false; then'
  vr_score "MUTANT R-no-symlink (-L dropped beside -e): ONLY the dangling-symlink cell goes red" \
    no-symlink 110111 "" "$VR_G1L" '[ -e "$ESCALATIONS" ]'
  vr_score "MUTANT R-rc (the status > 1 guard removed): the mode-000 and I/O cells go red" \
    rc 011011 "" "$VR_G2" 'if false; then'
  vr_score "MUTANT R-readable-never (the -r test never true): ONLY the mode-000 cell's reason goes red" \
    readable-never 011111 "" "$VR_G3" 'if false; then'
  vr_score "MUTANT R-readable-always (the -r test always true): ONLY the I/O cell's reason goes red" \
    readable-always 111011 "" "$VR_G3" 'if true; then'
fi

# --- Assertions 25-31: the Check 2/2a text says an unreadable pending.md REFUSES, never "FAIL" -------
# The existing posture cells FAIL on the literal `is not a pass` in those sections and count three
# `IS a pass` phrases in the map. Neither sees a sentence that appends "treat that line as a FAIL" to
# the pass ruling, which re-inverts it for an adjudicator, nor the refusal clause being dropped. And
# Checks 26/33/35, whose corpus MUST exist, still carry the opposite reading.
#   A  map, Check 2/2a postures: exactly 3 carry the refusal clause
#   B  step text, Check 2: the refusal sentence and its `REFUSED:` / never-a-pass tail
#   C  step text, Check 2a: the same
#   D2, D2a, Dm  no sentence containing "treat that line as a FAIL" (any case) in step 2, step 2a, map 2/2a
#   E  map rows 26, 33, 35: "is not a pass, nothing was verified" once in each, 3 in total
RP_MAP='unreadable or non-regular `pending.md` is a REFUSAL, exit 2 with `REFUSED:` on stderr, never a pass'
RP_STEP='An unreadable or non-regular `pending.md` is a REFUSAL:'
RP_TAIL='with `REFUSED:` on stderr, and that is never a pass.'
RP_FAIL='treat that line as a fail'
RP_NOTPASS='is not a pass, nothing was verified'
RP_CELLS=""
rp_count() { local n; n="$(grep -oF -- "$1" <<<"$2" | grep -c .)" || n=0; printf '%s' "$n"; }
rp_has_fail() { local lc; lc="$(tr '[:upper:]' '[:lower:]' <<<"$1")"; grep -qF -- "$RP_FAIL" <<<"$lc"; }
rp_cells() {  # <gate-validation.md> <enforcement-map.yaml> -> RP_CELLS
  local s2 s2a m m26 m33 m35 c="" n26 n33 n35
  s2="$(en_flat "$1" '^### 2\. ' '^### 2a\. ')"
  s2a="$(en_flat "$1" '^### 2a\. ' '^### 3\. ')"
  m="$(en_flat "$2" '^  - id: "2"$' '^  - id: "3"$')"
  m26="$(en_flat "$2" '^  - id: "26"$' '^  - id: "')"
  m33="$(en_flat "$2" '^  - id: "33"$' '^  - id: "')"
  m35="$(en_flat "$2" '^  - id: "35"$' '^  - id: "')"
  if [ "$(rp_count "$RP_MAP" "$m")" -eq 3 ]; then c="${c}1"; else c="${c}0"; fi
  if grep -qF -- "$RP_STEP" <<<"$s2" && grep -qF -- "$RP_TAIL" <<<"$s2"; then c="${c}1"; else c="${c}0"; fi
  if grep -qF -- "$RP_STEP" <<<"$s2a" && grep -qF -- "$RP_TAIL" <<<"$s2a"; then c="${c}1"; else c="${c}0"; fi
  if [ -n "$s2" ] && ! rp_has_fail "$s2"; then c="${c}1"; else c="${c}0"; fi
  if [ -n "$s2a" ] && ! rp_has_fail "$s2a"; then c="${c}1"; else c="${c}0"; fi
  if [ -n "$m" ] && ! rp_has_fail "$m"; then c="${c}1"; else c="${c}0"; fi
  n26="$(rp_count "$RP_NOTPASS" "$m26")"; n33="$(rp_count "$RP_NOTPASS" "$m33")"; n35="$(rp_count "$RP_NOTPASS" "$m35")"
  if [ "$n26" -ge 1 ] && [ "$n33" -ge 1 ] && [ "$n35" -ge 1 ] && [ $((n26 + n33 + n35)) -eq 3 ]; then c="${c}1"; else c="${c}0"; fi
  RP_CELLS="$c"
}
# SELF-PROBE FIRST, on synthesized files, both directions: a conforming pair scores every cell, the
# same pair with "Treat that line as a FAIL." appended to step 2 moves ONLY D2, and a near-miss
# ("Treat that line as a PASS.") stays quiet.
RPP="$WORK/rp-probe"; mkdir -p "$RPP"
rpp_gv() {  # <extra sentence for step 2> -> a synthesized gate-validation.md on stdout
  printf '### 2. No unresolved HARD_BLOCKs?\n\nAbsent is a PASS. %s\n  REFUSAL: both scripts exit 2 %s%s\n\n' "$RP_STEP" "$RP_TAIL" "$1"
  printf '### 2a. Citation?\n\n%s\nREFUSAL: the script exits 2 %s\n\n### 3. Next.\n' "$RP_STEP" "$RP_TAIL"
}
{
  printf 'checks:\n  - id: "2"\n'
  for _p in a b c; do printf '    posture: IS a pass; an %s)\n' "$RP_MAP"; done
  printf '  - id: "3"\n'
  for _id in 26 33 35; do printf '  - id: "%s"\n    posture: %s\n' "$_id" "$RP_NOTPASS"; done
  printf '  - id: "36"\n'
} > "$RPP/map.yaml"
rpp_gv "" > "$RPP/gv-ok.md"
rpp_gv " Treat that line as a FAIL." > "$RPP/gv-fail.md"
rpp_gv " Treat that line as a PASS." > "$RPP/gv-near.md"
rp_cells "$RPP/gv-ok.md" "$RPP/map.yaml"; RPP_OK="$RP_CELLS"
rp_cells "$RPP/gv-fail.md" "$RPP/map.yaml"; RPP_FAIL="$RP_CELLS"
rp_cells "$RPP/gv-near.md" "$RPP/map.yaml"; RPP_NEAR="$RP_CELLS"
if [ "$RPP_OK" = 1111111 ] && [ "$RPP_FAIL" = 1110111 ] && [ "$RPP_NEAR" = 1111111 ]; then
  ok "refusal-prose self-probe: a conforming pair scores 1111111, the FAIL sentence moves ONLY D2, the near-miss is quiet"; B_RPP=1
else
  bad "refusal-prose self-probe read ok=$RPP_OK fail=$RPP_FAIL near=$RPP_NEAR, wanted 1111111/1110111/1111111 -- the cells cannot be trusted on the real files"
fi
if [ ! -f "$EN_GV" ] || [ ! -f "$EN_MAP" ]; then
  bad "refusal-prose arms cannot run: gate-validation.md or enforcement-map.yaml is not beside $SPEC_SRC"
else
  rp_cells "$EN_GV" "$EN_MAP"
  RP_REAL="$RP_CELLS"
  # A TREE THAT PREDATES THE REFUSAL SENTENCE: A, B and C all read 0 there. SKIP on a consumer only.
  if [ "$(printf '%s' "$RP_CELLS" | cut -c1-3)" = "000" ] && [ "$VEN_IS_DIST" -ne 1 ]; then
    printf '  SKIP  the refusal-prose arms -- the installed step and map files predate the unreadable-file refusal\n'
  else
    i=0
    for nm in "A the map's three Check 2/2a postures carry the refusal clause" \
              "B Check 2's step text carries the refusal sentence" \
              "C Check 2a's step text carries the refusal sentence" \
              "D2 Check 2's step text has no 'treat that line as a FAIL'" \
              "D2a Check 2a's step text has no 'treat that line as a FAIL'" \
              "Dm the map's Check 2/2a rows have no 'treat that line as a FAIL'" \
              "E Checks 26, 33 and 35 still say 'is not a pass, nothing was verified', once each"; do
      i=$((i + 1))
      if [ "$(printf '%s' "$RP_CELLS" | cut -c"$i")" = "1" ]; then ok "refusal-prose cell $nm"
      else bad "refusal-prose cell $nm does not hold (cells=$RP_CELLS)"; fi
    done
    if [ "$RP_REAL" = 1111111 ]; then ok "baseline (unmutated step and map files): all seven refusal-prose cells hold, so the refusal-prose mutants are scored"; B_RP=1; fi
    RP_MW="$WORK/rp-mut"; mkdir -p "$RP_MW"
    rp_score() {  # <label> <which: gv|map> <name> <want-rp> <want-en> <anchor> <replacement>
      local label="$1" which="$2" out gv="$EN_GV" map="$EN_MAP" wrp="$4" wen="$5"
      out="$RP_MW/$3"
      shift 5
      if [ "$which" = gv ]; then fx_sub "$EN_GV" "$out" "$@" && gv="$out"; else fx_sub "$EN_MAP" "$out" "$@" && map="$out"; fi
      if [ ! -f "$out" ]; then bad "$label DID NOT APPLY: $FX_WHY"; return 0; fi
      rp_cells "$gv" "$map"; en_cells "$gv" "$map"
      vec_score "$label" "$RP_CELLS/$EN_CELLS" "$wrp/$wen" \
        "$(( ${B_RP:-0} && ${B_EN:-0} && ${B_RPP:-0} ))" \
        "$label scored refusal=$RP_CELLS posture=$EN_CELLS" "$label scored refusal=$RP_CELLS posture=$EN_CELLS, wanted $wrp/$wen"
      return 0
    }
    # THE BL-353 GAP: the old posture cells stay 111 under this mutant, and only the new D2 cell sees it.
    rp_score "MUTANT RP-fail-sentence (step 2 appends 'Treat that line as a FAIL.'): ONLY D2 goes red; the old posture cells cannot see it" \
      gv fail-sentence 1110111 111 \
      'both scripts exit 2 with `REFUSED:` on stderr, and that is never a pass.' \
      'both scripts exit 2 with `REFUSED:` on stderr, and that is never a pass. Treat that line as a FAIL.'
    rp_score "MUTANT RP-map-clause (one Check 2 posture drops the refusal clause): ONLY A goes red" \
      map map-clause 0111111 111 \
      'because no escalation exists to be unresolved; an unreadable or non-regular' \
      'because no escalation exists to be unresolved; a missing'
    rp_score "MUTANT RP-step-2a-tail (Check 2a drops the REFUSED: tail): ONLY C goes red" \
      gv step2a-tail 1101111 111 \
      'REFUSAL: the script exits 2 with `REFUSED:` on stderr' 'REFUSAL: the script exits 2 on stderr'
    rp_score "MUTANT RP-check-26 (Check 26 turns 'is not a pass' into a pass): ONLY E goes red" \
      map check-26 1111110 111 \
      'is not a pass, nothing was verified — no verdict carried a gate_series_id' 'is a pass — no verdict carried a gate_series_id'
  fi
fi

echo
report_end escalation-status-vocabulary
