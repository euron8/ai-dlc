#!/bin/bash
#
# AI/DLC Sprint-Scope Confirmation Validator  (Check 34)
#
# WHAT IT ASKS. Did the Rule 3(d) sprint-scope pause point actually happen, and does
# the routing record's claim about it resolve to an operator selection the lead did
# not write?
#
# WHY IT IS NOT PART OF CHECK 33. Check 33 joins the identifiers in the captured ask
# to the LOCKED block, and on the 5 of 23 measured asks that name no identifier it
# correctly reports NOT-APPLICABLE. Hanging the scope-confirmation verdict off that
# check would make it silent on roughly a fifth of sprints while still printing a
# clean line -- a check that cannot fire, which is this repo's recurring defect. The
# pause point is unconditional, so its verifier has to be too.
#
# WHY IT IS NOT PART OF CHECK 27. Check 27 is scoped to non-bug planning variants and
# asks whether a defect was subordinated. Different subject, narrower population.
#
# THE SELF-DECLARATION HOLE THIS CLOSES. `scope_confirmed` is a field the LEAD writes
# about a conversation the LEAD had. On its own it is worth nothing: the router that
# misresolved the scope also writes the boolean saying the operator blessed it. What
# makes it checkable is `scope_confirmed_cite` -- a SHA256 into
# `operator-answers-history.md`, which is written by the PostToolUse hook from the
# hook's own payload before any agent sees it. The lead can choose which hash to copy;
# it cannot author the record the hash resolves to.
#
# THE MIGRATION DISCRIMINATOR IS DERIVED, NOT DECLARED. The obvious rule -- "no
# `scope_confirmed` field means the snapshot predates this release, report PENDING" --
# is indistinguishable from a lead on the current release that simply skipped the
# pause point, and it fails in the OPEN direction on exactly the conduct the check
# exists to catch. So pre-migration is decided by an artifact no agent authors:
#
#   * no `operator-answers-history.md` at all -> the capture hook is not installed,
#     nothing could have been recorded whatever the lead did, and there is no evidence
#     in either direction. PENDING (exit 3), reported loudly.
#   * the file exists -> the hook is live, so a missing or unresolvable
#     `scope_confirmed` is the lead's, and it FAILS.
#
# A `none` CITE IS NOT A FREE PASS. `scope_confirmed_cite: none` is honest only when
# there was nothing to cite. If the capture file holds entries and the record still
# says `none`, the pause point either did not happen or its answer was not the one
# recorded -- both FAIL. `none` against an empty file passes, because that is the
# operator dismissing the prompt and the lead saying so.
#
# NEVER A CLEAN LINE ON AN ABSENCE. `answers_entries_scanned:` prints on every path,
# including PENDING and NOT-APPLICABLE. A run that scanned nothing and a run that
# scanned forty healthy entries must not look alike.
#
# USAGE
#   validate-scope-confirmation.sh [--snapshot PATH] [--answers PATH] [--quiet]
#
# EXIT
#   0  scope_confirmed present, well-formed, and its cite resolves
#   1  missing, malformed, or a cite that resolves to nothing
#   2  input unreadable -- no snapshot at the resolved path
#   3  PENDING: routing record predates the routing-record release, or the capture
#      hook is not installed. Never a silent pass; the caller reports it.

set -u

# --- AI_DLC_ROOT ------------------------------------------------------------
# Resolve the project root by walking UP for a marker, never by a fixed number of
# `..` hops. This script runs from three layouts:
#   <root>/core/scripts/X      distribution
#   <root>/scripts/ai-dlc/X    consumer, v0.126.0+
#   <root>/scripts/X           consumer, pre-v0.126.0
# and no fixed hop count fits all three. v0.126.0 moved the validators one level
# deeper, which silently turned every `dirname $0/..` root into <root>/scripts:
# this script then found no docs/retro/, printed "Scanned 0 retros, 0 gates
# declared, 0 dormant" and exited 0 — a check that could no longer fire, reading
# exactly like one that passed.
# Inline on purpose, in every script that needs it: a shared lib cannot fix this,
# because locating the lib is the same unsolved problem. Duplication is correct
# here. core/fixtures/validator-path-resolution asserts both layouts agree.
ai_dlc_resolve_root() {
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -e "$d/.git" ] || [ -d "$d/.claude" ] || [ -d "$d/core/skills/ai-dlc" ]; then
      printf '%s\n' "$d"; return 0
    fi
    d="$(dirname "$d")"
  done
  return 1
}
AI_DLC_SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AI_DLC_ROOT="${AI_DLC_PROJECT_ROOT:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$AI_DLC_SELF_DIR" || true)"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="${CLAUDE_PROJECT_DIR:-}"
[ -n "$AI_DLC_ROOT" ] || AI_DLC_ROOT="$(ai_dlc_resolve_root "$(pwd)" || true)"
[ -n "$AI_DLC_ROOT" ] || {
  echo "ERROR: cannot resolve the project root from ${AI_DLC_SELF_DIR} (no .git or" >&2
  echo "  .claude/ marker in any parent). Set AI_DLC_PROJECT_ROOT to the repo root." >&2
  exit 2
}
# --- end AI_DLC_ROOT --------------------------------------------------------

PROJECT_DIR="$AI_DLC_ROOT"
SNAPSHOT="${PROJECT_DIR}/_bmad-output/pipeline-snapshot.md"
ANSWERS="${PROJECT_DIR}/_bmad-output/operator-answers-history.md"
QUIET=0

while [ $# -gt 0 ]; do
  case "$1" in
    --snapshot) SNAPSHOT="$2"; shift 2 ;;
    --answers)  ANSWERS="$2";  shift 2 ;;
    --quiet)    QUIET=1; shift ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

say() { [ "$QUIET" -eq 1 ] || printf '%s\n' "$*"; }

if [ ! -f "$SNAPSHOT" ]; then
  echo "answers_entries_scanned: 0" >&2
  echo "FAIL: cannot read the pipeline snapshot -- no such file: $SNAPSHOT" >&2
  echo "      Exit 2 is a FAIL. A scope-confirmation verdict computed against a" >&2
  echo "      snapshot that is not there would be a verdict about nothing." >&2
  exit 2
fi

# Entry count first, so every path below can print it. Counted from the hook's own
# record grammar (`- SHA256: <hex>`), not from the `## ` headings, because the header
# block of the file carries prose that must never score as an entry.
if [ -f "$ANSWERS" ]; then
  ENTRIES="$(grep -c '^- SHA256: [0-9a-f]' "$ANSWERS" 2>/dev/null || true)"
else
  ENTRIES=0
fi
[ -n "$ENTRIES" ] || ENTRIES=0

say "answers_entries_scanned: ${ENTRIES}"

# -----------------------------------------------------------------------------
# FIELD EXTRACTION, AND WHY IT IS NOT ANCHORED TO THE START OF A LINE.
# -----------------------------------------------------------------------------
# There are two routing-record grammars in the wild and a parser that knows only one
# is worse than useless, because it fails in whichever direction that grammar happens
# to miss. The synthetic form is one field per line:
#
#     - scope_confirmed: confirmed
#
# The form the reference consumer actually writes is a prose bullet with the fields
# inline and backticked, several to a line:
#
#     - **Routing record (Step 6, written once, never rewritten):** `user_request_verbatim`
#       ... `bug_signal_present: no`. `carryover_or_sprint_signal_present: yes`.
#       `clarification_asked: n-a`.
#
# An anchored `^[[:space:]]*-` pattern reads the second one as a snapshot with no
# routing record at all -- which this check would report as PENDING, the fail-OPEN
# direction, on the one real snapshot available to measure against. It was written
# anchored, and the corpus said so.
#
# Both values this check reads are single tokens from closed sets (confirmed|corrected;
# a hex digest or `none`), so the value runs to the first space, backtick or sentence
# punctuation. Nothing here needs to survive a value containing spaces, and a parser
# that tried would swallow the rest of a prose line.
# NORMALIZE THE LINE, THEN MATCH. ENUMERATING WRAPPERS AROUND THE NAME IS WHAT FAILED.
#
# This used to spell the backtick as an optional character on each side of the NAME, which
# handles exactly the two grammars its own comment block documents and misparses every other
# one. Two of the failures are silent and one of them is an ACCUSATION:
#
#   - **scope_confirmed:** confirmed    ->  `**`    -> FAIL "not one of confirmed|corrected"
#   - **scope_confirmed**: confirmed    ->  empty   -> FAIL "a Rule 3(d) pause point that did
#                                                      not happen"
#
# The second is the harsher one: a well-formed snapshot carrying a correct value is read as
# evidence the lead skipped a MANDATORY operator pause. `scope_confirmed_cite` reached the
# same fate through the same function.
#
# THE FILED REPORT NAMED TWO GRAMMARS AND SIX WERE MEASURED. Driving the pre-fix function over
# a grammar table, the ones it got wrong were: bold with the colon inside the span, bold with
# the colon outside it, a BACKTICKED VALUE (the value class excluded a backtick, so
# `` `confirmed` `` matched nothing and returned empty), a bold span wrapping the whole pair
# (`confirmed**`), `__underscore bold__`, and a bold name with a backticked value. Only the
# first two were reported.
#
# WHY THE REPORT'S PRESCRIBED FIX WAS NOT ADOPTED -- it was transcribed and RUN, and it does
# not fix the case the report itself reproduces. It places the wrapper BEFORE the colon while
# the colon-inside form puts the closing `**` BETWEEN the colon and the value, so that form
# still returns `**`; on the colon-outside form it is strictly worse, capturing the whole line
# as the value. It also spells its alternation `\|`, a GNU BRE extension this machine's `grep`
# honours and BSD `sed` does not -- and the second leg here IS a `sed`, so half of it would
# have applied with no error at all.
#
# WHAT STILL DOES NOT PARSE, STATED RATHER THAN IMPLIED: single-character emphasis around the
# name -- `*scope_confirmed*` or `_scope_confirmed_`. A single `_` CANNOT be stripped, because
# the field name contains one; stripping it destroys the name this function is looking for.
# Both forms return empty here and returned empty before, so neither is a regression, and
# neither appears in the producer's output. This is the residue, and it is named because a
# separation that makes a wrong answer unlikely is not one that makes it unconstructible.
#
# KEEP THIS FUNCTION SELF-CONTAINED. `docs/backlog.md`'s receipt for this defect lifts it by
# its own definition boundaries -- `sed -n '/^field_of() {/,/^}/p'` -- and evals it alone, so a
# correct fix that delegated to a helper would leave the helper undefined and report the defect
# STILL-LIVE against working code. Measured: the helper-delegating form exits 9 there.
field_of() {
  sed -e 's/\*\*//g' -e 's/__//g' -e 's/`//g' "$2" 2>/dev/null \
    | grep -o "$1[[:space:]]*:[[:space:]]*[^[:space:]]\{1,\}" \
    | head -1 \
    | sed -e "s/^.*$1[[:space:]]*:[[:space:]]*//" -e 's/[.,;:]\{1,\}$//'
}

# --- routing record present at all? -----------------------------------------
# `user_request_verbatim` is the field the routing record has carried since the
# release that created the record. Its absence means there is no routing record to
# read, not that this check failed. Matched as a bare token rather than as
# `name:` -- the consumer grammar above names the field and then describes it in
# prose, with the colon nowhere near it.
if ! grep -q 'user_request_verbatim' "$SNAPSHOT"; then
  say "PENDING: the snapshot carries no routing record, so it was written before the"
  say "         router recorded one. Nothing to confirm; this is not a skipped pause point."
  exit 3
fi

# --- is the capture hook live? ----------------------------------------------
if [ ! -f "$ANSWERS" ]; then
  say "PENDING: no operator-answers-history.md, so the PostToolUse capture hook is not"
  say "         installed on this consumer. Whatever the lead did at the pause point,"
  say "         nothing could have recorded it, and a FAIL here would blame the lead for"
  say "         a missing hook. Install it and this check becomes decidable."
  exit 3
fi

# --- the field itself --------------------------------------------------------
VALUE="$(field_of scope_confirmed "$SNAPSHOT")"
if [ -z "$VALUE" ]; then
  echo "FAIL: the routing record carries no 'scope_confirmed' field, and the capture" >&2
  echo "      hook IS installed (${ENTRIES} recorded answers), so this is a Rule 3(d)" >&2
  echo "      pause point that did not happen rather than a consumer that predates it." >&2
  echo "      route.md Step 6 makes the sprint-scope confirmation MANDATORY and" >&2
  echo "      unconditional; a sprint may not plan against a scope no operator saw." >&2
  exit 1
fi

case "$VALUE" in
  confirmed|corrected) ;;
  *)
    echo "FAIL: scope_confirmed is '${VALUE}', which is not one of confirmed|corrected." >&2
    echo "      There is deliberately no third value. 'n-a' would assert the pause point" >&2
    echo "      did not apply, and it always applies -- every sprint resolves a scope." >&2
    exit 1 ;;
esac

# --- the cite ----------------------------------------------------------------
CITE="$(field_of scope_confirmed_cite "$SNAPSHOT")"
if [ -z "$CITE" ]; then
  echo "FAIL: scope_confirmed is '${VALUE}' but there is no scope_confirmed_cite." >&2
  echo "      Without it the field is the lead's account of a conversation the lead had," >&2
  echo "      which is the self-declaration hole the cite exists to close. Copy the" >&2
  echo "      SHA256 of the matching operator-answers-history.md entry, or write 'none'." >&2
  exit 1
fi

if [ "$CITE" = "none" ]; then
  if [ "$ENTRIES" -gt 0 ]; then
    echo "FAIL: scope_confirmed_cite is 'none', but operator-answers-history.md holds" >&2
    echo "      ${ENTRIES} recorded answers. 'none' claims the operator selected nothing" >&2
    echo "      this hook could see; the hook says otherwise. Either the pause point's" >&2
    echo "      answer was never recorded as the confirmation, or a different answer was." >&2
    echo "      Cite the entry, do not write 'none' over it." >&2
    exit 1
  fi
  say "PASS  scope_confirmed: ${VALUE}; cite 'none' against an empty capture file."
  say "      Honest gap: the operator dismissed the prompt and the lead said so."
  exit 0
fi

case "$CITE" in
  *[!0-9a-f]* | "")
    echo "FAIL: scope_confirmed_cite '${CITE}' is not a hex SHA256 and is not 'none'." >&2
    exit 1 ;;
esac

if ! grep -q "^- SHA256: ${CITE}\$" "$ANSWERS"; then
  echo "FAIL: scope_confirmed_cite '${CITE}' resolves to no entry in" >&2
  echo "      ${ANSWERS} (${ENTRIES} entries scanned)." >&2
  echo "      The hash must be COPIED from a hook-written record, never computed by the" >&2
  echo "      lead: a hash the lead computed over text the lead chose resolves perfectly" >&2
  echo "      and proves nothing. A cite that resolves to nothing is a fabricated one." >&2
  exit 1
fi

say "PASS  scope_confirmed: ${VALUE}; cite resolves to a hook-written answer record."
exit 0
