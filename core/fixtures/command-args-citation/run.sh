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
cite()  { bash "$VALIDATOR" --transcript "$1" --cite "$2" 2>/dev/null || true; }

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
COUNT="$(bash "$VALIDATOR" --transcript "$CMD" --count 2>/dev/null)"
if [ "$COUNT" = "0" ]; then
  ok "Check B counts 0 on /ai-dlc -> advance (the predicate was split, not widened)"
else
  bad "Check B counted $COUNT on a sprint kickoff the operator invoked to be executed — every sprint start now reads as a steamroll"
fi

echo
report_end command-args-citation
