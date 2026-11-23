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
# Usage: run.sh
set -uo pipefail
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

# IN PROCESS (BL-878). Every copy of the validator -- the shipped one, the lone copy, the sibling copy and each
# control copy -- is SOURCED by src_esv in THIS shell (its guard returns after defining esv_main; one fx_inproc pass per
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
  # set themselves.
  local c="$1"
  shift
  (
    case "$c" in
      "${LONE_V:-}"|"${SIB_V:-}") : ;;
      *) export AI_DLC_PROJECT_ROOT="$ESV_ROOT" ;;
    esac
  ( set +o pipefail; fx_inproc "$c" && esv_main "$@" )
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

# --- Assertion 4b: --open prints each NON-terminal entry (case M included) and no terminal one ----
# One drive: a terminal entry first, an open entry whose only Status is mid-line (case M), a canonical open entry,
# and a terminal entry last. Every printed row is required to APPEAR; the terminal bodies are required to be absent.
OPENF="$WORK/pending-open.md"
{
  printf '# Escalations\n\n'
  printf '## 2026-01-01 S1 closed-first\n**Status:** RESOLVED\nTERMINAL-BODY-ONE\n\n'
  printf '## 2026-01-02 S1 midline-open\nfiled by the lead -- **Status:** HARD_BLOCK\nMIDLINE-BODY\n\n'
  printf '## 2026-01-03 S1 canon-open\n**Status:** DEFERRAL_REQUEST\nCANON-BODY\n\n'
  printf '## 2026-01-04 S1 closed-last\n**Status:** HARD_BLOCK\n**Status:** RESOLVED\nTERMINAL-BODY-TWO\n'
} > "$OPENF"
ev "$VALIDATOR" --open "$OPENF" "$SPEC_SRC" > "$WORK/open.out" 2> "$WORK/open.err"; OPEN_RC=$?
if [ "$OPEN_RC" = 0 ] && grep -q '^L7-10 ## 2026-01-02 S1 midline-open$' "$WORK/open.out" \
   && grep -q '^MIDLINE-BODY$' "$WORK/open.out" && grep -q '^CANON-BODY$' "$WORK/open.out" \
   && grep -q '^OPEN 2 of 4$' "$WORK/open.out" && ! grep -q 'TERMINAL-BODY' "$WORK/open.out" \
   && ! grep -q 'closed-first\|closed-last' "$WORK/open.out"; then
  ok "--open prints the mid-line open entry and the canonical open one with their bodies, skips both terminal ones, and ends OPEN 2 of 4"
else
  bad "--open did not print exactly the two open entries (rc=$OPEN_RC out=[$(head -c 400 "$WORK/open.out")])"
fi

# --- Assertion 4c: --open prints bodies only for the statuses Check 2 acts on and COUNTS the rest ----
# One drive. DEFERRAL_REQUEST is filed BEFORE HARD_BLOCK, so HARD_BLOCK printing first is order, not file position.
# Two DECIDED_AUTONOMOUSLY entries are counted on one line, never printed. A statusless entry keeps its header.
# Two acted-on 8000-byte bodies overrun the 12000-byte budget: the second prints its header and a TRUNCATED line
# naming ONLY its own range, and a small third entry after it still prints its body.
OPENG="$WORK/pending-open-acted.md"
{
  printf '# Escalations\n\n'
  printf '## 2026-02-01 S1 deferral-first\n**Status:** DEFERRAL_REQUEST\nDEFER-BODY-BIG\n'
  head -c 8000 /dev/zero | tr '\0' 'x'; printf '\n\n'
  printf '## 2026-02-02 S1 hardblock-second\n**Status:** HARD_BLOCK\nHARD-BODY-BIG\n'
  head -c 8000 /dev/zero | tr '\0' 'y'; printf '\n\n'
  printf '## 2026-02-03 S1 decided-one\n**Status:** DECIDED_AUTONOMOUSLY\nDECIDED-BODY-ONE\n\n'
  printf '## 2026-02-04 S1 decided-two\n**Status:** DECIDED_AUTONOMOUSLY\nDECIDED-BODY-TWO\n\n'
  printf '## 2026-02-05 S1 no-status-entry\nNOSTATUS-BODY\n\n'
  printf '## 2026-02-06 S1 small-last\n**Status:** HARD_BLOCK\nSMALL-BODY\n'
} > "$OPENG"
ev "$VALIDATOR" --open "$OPENG" "$SPEC_SRC" > "$WORK/openg.out" 2> "$WORK/openg.err"; OPENG_RC=$?
if [ "$OPENG_RC" = 1 ] && grep -q '^OPEN-UNACTED DECIDED_AUTONOMOUSLY 2$' "$WORK/openg.out" \
   && ! grep -q 'DECIDED-BODY\|decided-one\|decided-two' "$WORK/openg.out" \
   && grep -q '^L[0-9]*-[0-9]* ## 2026-02-05 S1 no-status-entry$' "$WORK/openg.out" && ! grep -q 'NOSTATUS-BODY' "$WORK/openg.out" \
   && grep -q '^HARD-BODY-BIG$' "$WORK/openg.out" && grep -q '^SMALL-BODY$' "$WORK/openg.out" \
   && grep -q '^L[0-9]*-[0-9]* ## 2026-02-01 S1 deferral-first$' "$WORK/openg.out" && ! grep -q 'DEFER-BODY-BIG' "$WORK/openg.out" \
   && [ "$(grep -n 'hardblock-second' "$WORK/openg.out" | head -1 | cut -d: -f1)" -lt "$(grep -n 'deferral-first' "$WORK/openg.out" | head -1 | cut -d: -f1)" ] \
   && [ "$(grep -c '^TRUNCATED read lines ' "$WORK/openg.out")" = 1 ] && grep -q '^TRUNCATED read lines 3-7$' "$WORK/openg.out" \
   && grep -q '^OPEN 6 of 6$' "$WORK/openg.out"; then
  ok "--open: HARD_BLOCK prints first with its body, an unacted status is counted not printed, a statusless entry keeps its header, and each truncated body gets its own range"
else
  bad "--open acted-on/unacted split wrong (rc=$OPENG_RC out=[$(grep -v '^[xy]*$' "$WORK/openg.out" | head -c 700)])"
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
# instead, so the copy widens the vocabulary whatever it currently holds.
sed 's/^\(\*\*Terminal statuses\*\*.*\)`$/\1 | FILED | OPEN`/' \
  "$SPEC_SRC" > "$SPEC_MUT"
if ! grep -q 'FILED | OPEN' "$SPEC_MUT"; then
  bad "FIXTURE STALE: could not extend the terminal-status line — escalations.md's '**Terminal statuses**' line was reworded"
elif ev "$VALIDATOR" "$DRIFT" "$SPEC_MUT" >/dev/null 2>&1; then
  ok "widening escalations.md's published set makes the same entries pass — the vocabulary is read, not restated"
else
  bad "the drifted file STILL fails after escalations.md was widened — the script carries a private set and 'derived' is decoration"
fi

# --- Assertion 6: narrowing the source must break the clean file -----
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

# --- THE UNMODIFIED COPY CONTROL ------------------------------------------------------
# A copy of the validator at the subject's counted relative path, driven the same way as the subject.
MUTD="$WORK/mut"; mkdir -p "$MUTD"
MCTL="$MUTD/control/$ESV_REL"; mkdir -p "${MCTL%/*}"
cp "$VALIDATOR" "$MCTL"
src_esv "$MCTL"

# --- THE CWD-INVARIANCE ARM (BL-1007): the control's vector is the same from `/` and from the root -----------------
# The copies carry no marker above them, so a copy that resolves its root from the cwd answers rc 2 from `/` and the
# real verdict from the root. Offender then near-miss on the unmutated control copy, from each cwd; the whole
# vector is "<from />,<from root>" and must read 10,10. The LONE and SIB arms fix their own root, so a two-cwd cell
# of theirs cannot fail and is not coverage here.
cwd_vec() { # cwd_vec <cwd> <copy> -> "<offender rc><near-miss rc>"
  ( cd "$1" || exit 9
    ev "$2" "$PROSE_BELOW" "$SPEC_SRC" >/dev/null 2>&1; _o=$?
    ev "$2" "$PROSE_BELOW_OK" "$SPEC_SRC" >/dev/null 2>&1; _n=$?
    printf '%s%s' "$_o" "$_n" )
}
CWD_CTL="$(cwd_vec / "$MCTL"),$(cwd_vec "$ESV_ROOT" "$MCTL")"
if [ "$CWD_CTL" = "10,10" ]; then
  ok "cwd-invariance: the control copy reports the offender and stays quiet on the near-miss from / and from the root alike ($CWD_CTL)"
else
  bad "cwd-invariance: the control copy's vector from / and from the root is $CWD_CTL, wanted 10,10 -- the copies resolve a project root from the cwd"
fi

# --- Assertions 11-15: an EMPTY file is the ABSENT state, and only an empty one -----
# A file that exists and holds no non-whitespace byte used to fall through to the parser and
# print `OK: n=[] no **Status:** entries found` -- the same line a POPULATED file whose entries
# carry no `**Status:**` field prints. The first is nothing to examine; the second is a
# grammar failure over live entries. Only the first may say EXAMINED NOTHING.
#
# FIVE CELLS, SCORED AS ONE STRING:
#   A empty                rc 0, the token, and the "present but empty" reason
#   B whitespace           the same -- a `[ -s ]` fix calls this file populated and fails here
#   C absent               rc 0, the token, the absent-file reason, NOT the empty one (unchanged)
#   D populated-zero-record  heading-only AND a file of undated SECTION headers only: rc 0, the
#                          `n=[]` line, NO token. One cell, because no zero-record predicate can
#                          move one of the two without the other.
#   F statusless           FAIL-CLOSED: a DATED `## ` entry with no Status field exits 1 with one
#                          STATUSLESS line per entry and the STATUSLESS-ENTRY token. The bullet-entry
#                          shape (UNPARSED) names both entries; MIXED names only the S2 entry, not the
#                          section, the entry with a status, or the entry whose status sits under a `###`.
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
  o2="$(ev "$v" "$SECTIONS" "$SPEC_SRC" 2>/dev/null)"; rc2=$?
  if [ "$rc" -eq 0 ] && [ "$rc2" -eq 0 ] && ! grep -qF "EXAMINED NOTHING" <<<"$o$o2" \
     && grep -qF "n=[]" <<<"$o" && grep -qF "n=[]" <<<"$o2"; then c="${c}1"; else c="${c}0"; fi
  o="$(ev "$v" "$DRIFT" "$SPEC_SRC" 2>&1)"; rc=$?
  if [ "$rc" -eq 1 ] && grep -qF "out-of-vocabulary status" <<<"$o"; then c="${c}1"; else c="${c}0"; fi
  o="$(ev "$v" "$UNPARSED" "$SPEC_SRC" 2>&1)"; rc=$?
  o2="$(ev "$v" "$MIXED" "$SPEC_SRC" 2>&1)"; rc2=$?
  if [ "$rc" -eq 1 ] && [ "$rc2" -eq 1 ] && [ "$(grep -c '^FAIL: STATUSLESS ' <<<"$o")" -eq 2 ] \
     && grep -qF 'DA-283' <<<"$o" && grep -qF 'DA-284' <<<"$o" \
     && [ "$(grep -c '^FAIL: STATUSLESS ' <<<"$o2")" -eq 1 ] && grep -qF '[S2 gate]' <<<"$(grep '^FAIL: STATUSLESS ' <<<"$o2")" \
     && grep -qF 'STATUSLESS-ENTRY' <<<"$o$o2"; then c="${c}1"; else c="${c}0"; fi
  VEN_CELLS="$c"
}
VEN_IS_DIST=0
case "$(cd "$(dirname "$VALIDATOR")" && pwd)" in */core/scripts) VEN_IS_DIST=1 ;; esac
ven_cells "$VALIDATOR"
# A SUBJECT THAT PREDATES THE FIX. This fixture ships and can reach a consumer one pull ahead of
# the validator: cells A and B read 0 and nothing else moves. SKIP there; FAIL here.
if [ "$(printf '%s' "$VEN_CELLS" | cut -c1-2)" = "00" ] && [ "$(printf '%s' "$VEN_CELLS" | cut -c3-5)" = "111" ] \
   && [ "$VEN_IS_DIST" -ne 1 ]; then
  printf '  SKIP  the empty-file arms -- the installed validator predates the empty-file verdict; this fixture ships one pull ahead of it\n'
else
  i=0
  for nm in "A empty file" "B whitespace-only file" "C absent file (unchanged)" \
            "D populated file parsing to zero records carries NO token" "E a real finding still exits 1" \
            "F a dated entry with no Status field exits 1 naming it (fail-closed)"; do
    i=$((i + 1))
    if [ "$(printf '%s' "$VEN_CELLS" | cut -c"$i")" = "1" ]; then ok "empty-file cell $nm"
    else bad "empty-file cell $nm does not hold (cells=$VEN_CELLS)"; fi
  done

  # --- THROUGH verdict.sh: every shipped call site runs this validator behind it, and it keeps only lines that
  # begin with a verdict word. The offender world must surface the STATUSLESS line naming the entry AND the remedy;
  # the near-miss (a world with no entries) prints PASS. verdict.sh is the one beside the subject.
  VEN_VS="$(cd "$(dirname "$VALIDATOR")" && pwd)/verdict.sh"
  if [ -f "$VEN_VS" ]; then
    vo="$(AI_DLC_PROJECT_ROOT="$ESV_ROOT" bash "$VEN_VS" "$VALIDATOR" "$UNPARSED" "$SPEC_SRC" 2>&1)"; vrc=$?
    vn="$(AI_DLC_PROJECT_ROOT="$ESV_ROOT" bash "$VEN_VS" "$VALIDATOR" "$HEADING" "$SPEC_SRC" 2>&1)"; vnrc=$?
    if [ "$vrc" -eq 1 ] && grep -qF 'STATUSLESS' <<<"$vo" && grep -qF 'DA-283' <<<"$vo" && grep -qF 'DA-284' <<<"$vo" \
       && grep -qF 'remedy' <<<"$vo" && [ "$vnrc" -eq 0 ] && grep -q '^PASS' <<<"$vn"; then
      ok "through verdict.sh the offender world keeps its STATUSLESS lines and the remedy; the clean world prints PASS"
    else
      bad "through verdict.sh the STATUSLESS lines or remedy were dropped, or the clean world did not PASS (rc=$vrc/$vnrc)"
    fi
  fi

  # --- the whole-directory control: a copy of the WHOLE scripts dir at the subject's counted relative path ------
  VEN_SRC_DIR="$(cd "$(dirname "$VALIDATOR")" && pwd)"
  VEN_BASE="$(basename "$VALIDATOR")"
  VEN_D="$WORK/empty-ctl/control"; mkdir -p "$VEN_D/core"
  if cp -R "$VEN_SRC_DIR" "$VEN_D/core/scripts"; then
    VEN_CTL="$VEN_D/core/scripts/$VEN_BASE"
    # THE CWD-INVARIANCE ARM, whole-directory control: the same five cells from `/` (BL-1007).
    VEN_CWD="$(cd / && ven_cells "$VEN_CTL" && printf '%s' "$VEN_CELLS")"
    if [ "$VEN_CWD" = 111111 ]; then ok "cwd-invariance: the whole-directory control scores $VEN_CWD from / as from the root"
    else bad "cwd-invariance: the whole-directory control scores $VEN_CWD from /, wanted 111111"; fi
  else bad "whole-dir control: could not copy $VEN_SRC_DIR"; fi
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
fi

# --- Assertions 19-24: an UNREADABLE or NON-REGULAR escalations path REFUSES, exit 2 ---------------
# `grep -q '[^[:space:]]'` exits 2 on a file it cannot read, and the validator used to branch on
# `-eq 1` alone: a status of 2 fell through, the parser's own read failure was swallowed, and the run
# printed an ordinary `OK: n=[]` line over entries nobody read. A DIRECTORY at the path failed `-f`
# and printed "no escalations file" -- the line Check 2 reads as a pass. Now both refuse: `REFUSED:`
# on stderr, exit 2, nothing on stdout.
#
# SIX CELLS, ONE STRING:
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

  # --- the refusal control: a copy of the whole scripts directory, at the subject's counted relative path ------------
  VR_MD="$VR/ctl-scripts"
  cp -R "$(cd "$(dirname "$VALIDATOR")" && pwd)" "$VR_MD" || bad "refusal control: could not copy the scripts directory"
  VR_SRC="$VR_MD/$(basename "$VALIDATOR")"
  VR_OUT="$VR/m/ctl/$ESV_REL"; mkdir -p "${VR_OUT%/*}"
  cp "$VR_SRC" "$VR_OUT"
  VR_WANT="$(vr_want 111111)"
  # THE CWD-INVARIANCE ARM, refusal control: the same six cells from `/` (BL-1007).
  VR_CWD="$(cd / && vr_cells "$VR_OUT" && printf '%s' "$VR_CELLS")"
  if [ "$VR_CWD" = "$VR_WANT" ]; then ok "cwd-invariance: the refusal control scores $VR_CWD from / as from the root"
  else bad "cwd-invariance: the refusal control scores $VR_CWD from /, wanted $VR_WANT"; fi
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
  ok "refusal-prose self-probe: a conforming pair scores 1111111, the FAIL sentence moves ONLY D2, the near-miss is quiet"
else
  bad "refusal-prose self-probe read ok=$RPP_OK fail=$RPP_FAIL near=$RPP_NEAR, wanted 1111111/1110111/1111111 -- the cells cannot be trusted on the real files"
fi
if [ ! -f "$EN_GV" ] || [ ! -f "$EN_MAP" ]; then
  bad "refusal-prose arms cannot run: gate-validation.md or enforcement-map.yaml is not beside $SPEC_SRC"
else
  rp_cells "$EN_GV" "$EN_MAP"
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
  fi
fi

echo
report_end escalation-status-vocabulary
