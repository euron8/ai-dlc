#!/usr/bin/env bash
# command-args-citation/run.sh — prove --cite accepts a slash-command's ARGUMENTS, that it
# accepts ONLY the arguments, and that Check B was not widened along with it.
#
# THE DEFECT. genuineOperatorText returns "" for any text opening with `<command-`. A slash
# command reaches the transcript as exactly that envelope, so --cite structurally could not
# accept any text an operator supplied to one. Because /ai-dlc IS the sprint kickoff, the
# uncitable class was the sprint's own scope — the largest single body of operator prose the
# requirement chain rests on. Measured on the reference consumer: 643 of 5508 operator records
# rejected by that arm, 304 carrying non-empty args, 148 of them /ai-dlc.
#
# What it cost: a lead recorded `user_request_verbatim` as a POINTER to the previous sprint's
# locked block, planned three stories sharing not one identifier with the ask, and passed four
# consecutive gates. Nothing could refute the pointer, because the operator's own words were
# invisible to the only verifier that could have.
#
# THE HAZARD THE FIX MUST NOT CREATE. The envelope also carries <command-name>, which the
# HARNESS wrote. A fix accepting the whole envelope would let a lead cite the token `/ai-dlc`
# — composed by nobody — as operator authorization. Assertion 2 guards that. And any record
# can QUOTE an args tag; only the record's own opening tag says an operator composed it.
# Assertion 3 guards that.
set -uo pipefail
# Clear every inherited AI_DLC_* tunable and CLAUDE_PROJECT_DIR so a bare run judges the code, not the caller environment.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"
# The REQUIRED input of inputs.decl: every assertion below drives this file, and seed.sh has
# already resolved it, so this is the point the declaration is consumed.
echo "HERMETIC-CONSUMED $VALIDATOR"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
# Capture, never pipe. --cite exits 2 on NOMATCH, and under `set -o pipefail` a
# `cite ... | grep -q NOMATCH` pipeline inherits that 2 even when grep matched.
# A literal-tail path, never `. "$VAR"`: in a fixture opted in by an inproc: row, P1 reads an opaque source as a drive.
[ -f "$HERE/../lib/mutant.sh" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$HERE/../lib/mutant.sh" || { echo "FIXTURE BROKEN: cannot source lib/mutant.sh" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

# IN PROCESS (BL-878). The validator is SOURCED once (its column-0 guard returns after defining sb_main) and every
# assertion calls sb_main in a subshell, so the validator's own `exit`, `set -u` and variables stay in that subshell.
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A consumer can receive this file one pull before the wrapped validator, and
# sourcing a pre-wrap one would run its argument loop and `exit` in this shell. So the shape is checked first, on its
# two halves: neither the `sb_main() {` line nor the column-0 source guard is a subject that predates the wrap, which
# prints SKIP and exits 0 -- never an ok. Exactly one half is a respelled subject this fixture can no longer drive,
# which FAILS. An unreadable subject is FIXTURE ERROR.
sb_def=0; sb_guard=0
grep -q '^sb_main() {$' "$VALIDATOR"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $VALIDATOR (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || sb_def=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$VALIDATOR"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $VALIDATOR (grep exit $_gx) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || sb_guard=1
if [ "$sb_def$sb_guard" = 00 ]; then echo "SKIP: subject predates the in-process wrap"; exit 0; fi
if [ "$sb_def" = 0 ]; then echo "   FAIL  $VALIDATOR carries the column-0 source guard but no \`sb_main() {\` line -- a respelled subject this fixture cannot drive" >&2; echo "command-args-citation: FAIL (1)" >&2; exit 1; fi
if [ "$sb_guard" = 0 ]; then echo "   FAIL  $VALIDATOR defines \`sb_main() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run sb_main in this shell" >&2; echo "command-args-citation: FAIL (1)" >&2; exit 1; fi
fx_inproc "$VALIDATOR"
. "$VALIDATOR" || { echo "FIXTURE BROKEN: sourcing $VALIDATOR failed" >&2; exit 2; }
declare -F sb_main > /dev/null || { echo "FIXTURE BROKEN: sourcing $VALIDATOR defined no sb_main" >&2; exit 2; }

cite()  { fx_inproc "$VALIDATOR"; ( sb_main --transcript "$1" --cite "$2" ) 2>/dev/null || true; }

echo "command-args-citation:"

# --- Assertion 1: THE FIX — slash-command ARGUMENTS are citable ----------------
R="$(cite "$CMD" "$ARGS")"
case "$R" in
  MATCH*) ok "a /ai-dlc invocation's arguments cite as a genuine operator message" ;;
  *)      bad "the operator's own sprint ask still cannot be cited ($R) — the scope of every sprint remains unverifiable" ;;
esac

# --- Assertion 2: THE HAZARD — the harness-written COMMAND NAME is not citable --
# Same record, same bytes. If this matches, a lead can cite the command name as operator
# authorization. The verdict must be the PLAIN `NOMATCH` -- the records were read and none carried
# it. `NOMATCH-SHORT` would be the citation floor refusing the needle before any record was read,
# which says nothing about the extraction; the seeded name is fourteen characters so it cannot.
CMDNAME_NLEN="$(printf '%s' "$CMDNAME" | tr -s '[:space:]' ' ' | sed 's/^ //; s/ $//' | wc -c | tr -d ' ')"
if [ "$CMDNAME_NLEN" -ge 12 ]; then
  ok "the cited command name '$CMDNAME' is $CMDNAME_NLEN characters, above the citation floor, so assertions 2 and 5 reach the extraction"
else
  bad "FIXTURE BROKEN: the cited command name '$CMDNAME' is $CMDNAME_NLEN characters, under the floor of 12 -- every assertion citing it is decided by NOMATCH-SHORT, not by the extraction"
fi
R="$(cite "$CMD" "$CMDNAME")"
case "$R" in
  NOMATCH) ok "the harness-written <command-name> is NOT citable (plain NOMATCH) — only the args side is read" ;;
  *)       bad "FABRICATION VECTOR OPEN or WRONG REASON ($R): want the plain NOMATCH a read corpus gives" ;;
esac

# --- Assertion 3: THE HAZARD — a QUOTED args tag in another record is not citable
# Its bytes are an envelope's bytes. Only the record's own opening tag decides provenance.
R="$(cite "$FORGED" "$FORGERY")"
case "$R" in
  NOMATCH*) ok "an args tag quoted inside a task-notification is rejected — the record's own opening tag decides, not the bytes" ;;
  *)        bad "FABRICATION VECTOR OPEN ($R): any agent that can emit a task notification can now mint operator authorization" ;;
esac

# --- Assertion 4: command OUTPUT is not operator INPUT -------------------------
R="$(cite "$STDOUT" "$STDOUTTEXT")"
case "$R" in
  NOMATCH*) ok "local-command-stdout stays uncitable — the arm did not widen to command output" ;;
  *)        bad "text the HARNESS printed now cites as an operator message ($R)" ;;
esac

# --- Assertion 5: an argument-less invocation says nothing ---------------------
R="$(cite "$EMPTY" "$CMDNAME")"
case "$R" in
  NOMATCH) ok "an empty-args invocation carries nothing citable (plain NOMATCH, not the floor)" ;;
  *)        bad "the envelope alone made a string citable ($R) — presence of a command is not speech" ;;
esac

# --- Assertion 6: REGRESSION — a freely-typed message still cites --------------
R="$(cite "$TYPED" "$TYPEDTEXT")"
case "$R" in
  MATCH*) ok "a freely-typed operator message still cites (the original path is intact)" ;;
  *)      bad "the third arm broke plain typed-message citation ($R) — the regression this change must not cause" ;;
esac

# --- Assertion 7: Check B was NOT widened -------------------------------------
# A /ai-dlc invocation is followed by advancing calls BY DESIGN. On the reference consumer,
# 305 of 643 command-envelope records are followed by an advancing call, against 183 for the
# free-typed records that are Check B's real subject — so widening genuineOperatorText instead
# of adding this arm would have nearly tripled Check B's candidate set with sprint starts.
fx_inproc "$VALIDATOR"
COUNT="$( ( sb_main --transcript "$CMD" --count ) 2>/dev/null)"
if [ "$COUNT" = "0" ]; then
  ok "Check B counts 0 on /ai-dlc -> advance (the predicate was split, not widened)"
else
  bad "Check B counted $COUNT on a sprint kickoff the operator invoked to be executed — every sprint start now reads as a steamroll"
fi

# --- the cli cells (cells.decl): the validator run as a PROGRAM once per distinct CLI outcome ---------------------
# The outcomes this fixture reaches are exit 0 with a MATCH line, exit 2 with the plain NOMATCH, and exit 0 with the
# --count integer. One `FXCELL=<id> bash "$VALIDATOR"` start per outcome, each compared with the in-process call on the
# same input: stdout, stderr and exit separately, byte for byte. A cell also asserts its own outcome (a positive
# conjunct, so two runs that both printed nothing cannot read as equivalent), and the cells must differ.
EQ="$WORK/eq"; mkdir -p "$EQ"
eqv() { # <cell-id> <args...> -> $EQ/<id>.{ip,cl}.{out,err,rc}
  local id="$1"; shift
  fx_inproc "$VALIDATOR"
  ( sb_main "$@" ) > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" bash "$VALIDATOR" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
  cmp -s "$EQ/$id.ip.out" "$EQ/$id.cl.out" && cmp -s "$EQ/$id.ip.err" "$EQ/$id.cl.err" && cmp -s "$EQ/$id.ip.rc" "$EQ/$id.cl.rc"
}
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(cat "$EQ/$1.ip.out")" "$(cat "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(cat "$EQ/$1.cl.out")" "$(cat "$EQ/$1.cl.err")"; }
echo "== cli cells"
if eqv cli-match --transcript "$CMD" --cite "$ARGS" && [ "$(cat "$EQ/cli-match.cl.rc")" = 0 ] \
   && case "$(cat "$EQ/cli-match.cl.out")" in MATCH\ *) true ;; *) false ;; esac \
   && grep -q "^cite: scanned 1 transcript" "$EQ/cli-match.cl.err"; then
  ok "cli-match: the program cites the args exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-match: the program and the in-process call differ, or the outcome is not exit 0 with a MATCH line ($(eq_twin cli-match))"; fi
if eqv cli-nomatch --transcript "$CMD" --cite "$CMDNAME" && [ "$(cat "$EQ/cli-nomatch.cl.rc")" = 2 ] \
   && [ "$(cat "$EQ/cli-nomatch.cl.out")" = "NOMATCH" ] \
   && grep -q "no genuine operator message carried it" "$EQ/cli-nomatch.cl.err"; then
  ok "cli-nomatch: the program refuses the command name exactly as the in-process call does (stdout, stderr, exit 2)"
else bad "cli-nomatch: the program and the in-process call differ, or the outcome is not exit 2 with NOMATCH ($(eq_twin cli-nomatch))"; fi
if eqv cli-count --transcript "$CMD" --count && [ "$(cat "$EQ/cli-count.cl.rc")" = 0 ] \
   && [ "$(cat "$EQ/cli-count.cl.out")" = "0" ] && [ ! -s "$EQ/cli-count.cl.err" ]; then
  ok "cli-count: the program counts 0 exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-count: the program and the in-process call differ, or the outcome is not exit 0 with the integer 0 ($(eq_twin cli-count))"; fi
if ! cmp -s "$EQ/cli-match.cl.out" "$EQ/cli-nomatch.cl.out" && ! cmp -s "$EQ/cli-match.cl.rc" "$EQ/cli-nomatch.cl.rc"; then
  ok "cli cells discriminate: the passing and the refusing input give different stdout and exit"
else bad "cli cells do not discriminate: cli-match and cli-nomatch gave the same stdout or exit"; fi

echo
report_end command-args-citation
