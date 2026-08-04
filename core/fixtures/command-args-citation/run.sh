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

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); }
# Capture, never pipe. --cite exits 2 on NOMATCH, and under `set -o pipefail` a
# `cite ... | grep -q NOMATCH` pipeline inherits that 2 even when grep matched.
cite()  { bash "$VALIDATOR" --transcript "$1" --cite "$2" 2>/dev/null || true; }
citeV() { bash "$1" --transcript "$2" --cite "$3" 2>/dev/null || true; }

echo "command-args-citation:"

# --- Assertion 1: THE FIX — slash-command ARGUMENTS are citable ----------------
R="$(cite "$CMD" "$ARGS")"
case "$R" in
  MATCH*) ok "a /ai-dlc invocation's arguments cite as a genuine operator message" ;;
  *)      bad "the operator's own sprint ask still cannot be cited ($R) — the scope of every sprint remains unverifiable" ;;
esac

# --- Assertion 2: THE HAZARD — the harness-written COMMAND NAME is not citable --
# Same record, same bytes. If this matches, a lead can cite `/ai-dlc` as operator authorization.
R="$(cite "$CMD" "$CMDNAME")"
case "$R" in
  NOMATCH*) ok "the harness-written <command-name> is NOT citable — only the args side is read" ;;
  *)        bad "FABRICATION VECTOR OPEN ($R): a token no operator composed cites as operator authorization" ;;
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
  NOMATCH*) ok "an empty-args invocation carries nothing citable" ;;
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

# --- Assertion 8: UNMUTATED CONTROL -------------------------------------------
# The mutants below are copies. This validator is bash wrapping a node heredoc, and a copy that
# dies before reaching node emits nothing — which every NOMATCH assertion would score as a kill.
# An unmutated copy must behave exactly like the original, or the two mutant results are noise.
CTL="$WORK/validator-control.sh"
cp "$VALIDATOR" "$CTL"
R="$(citeV "$CTL" "$CMD" "$ARGS")"
case "$R" in
  MATCH*) ok "control: an unmutated copy still MATCHes — the copies below can actually run" ;;
  *)      bad "CONTROL FAILED ($R): an unmutated copy does not behave like the original, so neither mutant result means anything" ;;
esac

# --- Assertion 9: MUTANT A — args-only extraction is what makes 2 hold ---------
# Return the whole envelope instead of the args, exactly as a naive fix would. The
# harness-written command name MUST become citable. If it does not, assertion 2 passes for some
# other reason and proves nothing about the extraction.
MUT_A="$WORK/validator-mutant-a.sh"
sed 's|.*matchAll(/<command-args>.*|  out.push(txt);|' "$VALIDATOR" > "$MUT_A"
if cmp -s "$VALIDATOR" "$MUT_A"; then
  bad "FIXTURE STALE: mutant A is byte-identical to the original — commandArgsText's extraction line was reworded"
else
  R="$(citeV "$MUT_A" "$CMD" "$CMDNAME")"
  case "$R" in
    MATCH*) ok "mutant A: accepting the whole envelope makes <command-name> citable — assertion 2 has teeth" ;;
    *)      bad "MUTANT A DID NOT FAIL ($R) — the command name is uncitable even when the whole envelope is accepted, so assertion 2 is not testing the extraction" ;;
  esac
  # Mutant A must fail ONLY its own assertion. If it also breaks assertion 3, the two are
  # entangled and one of them is vacuous.
  R="$(citeV "$MUT_A" "$FORGED" "$FORGERY")"
  case "$R" in
    NOMATCH*) ok "mutant A leaves assertion 3 intact — the two assertions are not entangled" ;;
    *)        bad "mutant A ALSO broke assertion 3 ($R) — the extraction and the provenance guard are entangled, so one of the two assertions is vacuous" ;;
  esac
fi

# --- Assertion 10: MUTANT B — the provenance guard is what makes 3 hold --------
# Drop the `^<command-` guard. A quoted args tag in a task-notification MUST become citable.
MUT_B="$WORK/validator-mutant-b.sh"
sed 's|  if (!/\^<command-/.test(txt)) return "";||' "$VALIDATOR" > "$MUT_B"
if cmp -s "$VALIDATOR" "$MUT_B"; then
  bad "FIXTURE STALE: mutant B is byte-identical to the original — commandArgsText's envelope guard was reworded"
else
  R="$(citeV "$MUT_B" "$FORGED" "$FORGERY")"
  case "$R" in
    MATCH*) ok "mutant B: without the envelope guard a quoted args tag cites — assertion 3 has teeth" ;;
    *)      bad "MUTANT B DID NOT FAIL ($R) — the forgery stays uncitable even without the guard, so assertion 3 is not testing it" ;;
  esac
  # Mutant B must fail ONLY its own assertion.
  R="$(citeV "$MUT_B" "$CMD" "$CMDNAME")"
  case "$R" in
    NOMATCH*) ok "mutant B leaves assertion 2 intact — the two assertions are not entangled" ;;
    *)        bad "mutant B ALSO broke assertion 2 ($R) — the guard and the extraction are entangled, so one of the two assertions is vacuous" ;;
  esac
fi

echo
if [ "$fails" -eq 0 ]; then echo "command-args-citation: PASS"; exit 0; fi
echo "command-args-citation: $fails assertion(s) FAILED" >&2
exit 1
