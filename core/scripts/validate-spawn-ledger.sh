#!/usr/bin/env bash
# validate-spawn-ledger.sh -- Check 22's mechanical arms, decided by a program instead
# of by an agent re-reading a paragraph at every implementation gate.
#
# WHY THIS EXISTS (v0.211.0). gate-validation.md Check 22 ("teammate-spawn role
# binding") publishes a fully decidable predicate: read `_bmad-output/spawn-ledger.jsonl`,
# filter to this sprint, and for EVERY row confirm that `model_bound` matches
# `aiDlcRoles.<role>.model`, that `role_contract_cited` is true, and that
# `role_file_readable` is not false. Three field comparisons per row against a JSON
# config. Its enforcement-map row carried `enforcer: []`, so a teammate performed all
# three by hand at every implementation-phase gate of every sprint.
#
# AND THE COMPARISON WAS ALREADY PROGRAMMED. `core/hooks/ai-dlc-dispatch-guard.sh`
# resolves the same pin and applies the same match tolerance at PreToolUse -- that is
# how `model_bound` gets its value in the first place. But a PreToolUse hook cannot run
# at a gate, so the gate restated the guard's rule in prose and asked an agent to
# execute it. That is the shape this program keeps finding: the program exists, in a
# copy nothing at the gate can reach.
#
# So `pin_key()` and `matches_pin()` below are the guard's, byte-identical, bound by
# I56 in scripts/validate-enforcement-map.sh. Two copies rather than a sourced helper
# for I25's reason -- a guard that sources a helper fails OPEN when a partial install
# omits it, and a dispatch guard that binds nothing is far worse than a duplicated
# eleven lines. What makes the duplication safe is the assertion, not the discipline:
# before this release the guard carried TWO definitions of `matches_pin()`, verbatim,
# with the first shadowed and dead, and nothing was looking.
#
# WHAT THIS DOES NOT DECIDE, deliberately. Check 22 stays `adjudication: llm`:
#
#   * A recorded tier mismatch has a CLEARING PATH with four arms, and arm 4 -- the
#     escalation entry states the remediation and names its artifact -- is a judgement
#     about content. Arm 3 is `validate-escalation-resolution.sh`, which this script
#     does not invoke: the two answer different questions about different files and the
#     gate runs both. This script reports the mismatch; the adjudicator decides whether
#     it is cleared.
#   * STORY ROUTING (a `protected_path_editor: true` story serviced by a
#     `protected-path-editor` spawn) is mechanical in form but its subject set is the
#     sprint's story files, which this script is not given and cannot derive -- the
#     ledger names spawns, not stories. Left with the adjudicator, and said so here
#     rather than implying whole-check coverage.
#   * A `model_requested` that disagrees with `model_bound` is REPORTED and does not
#     fail. That is Check 22's own rule: the guard caught the slip and the teammate ran
#     on the key its role names.
#
# PRE-LEDGER IS ITS OWN EXIT CODE, and that is the point of writing this down. Zero
# rows and zero spawns are different states, and Check 22 was rewritten once already
# because a reader that cannot tell them apart passes vacuously on exactly the sprint
# where the mechanism was missing. Exit 3 is neither a pass nor a finding: it says the
# ledger covers nothing for this sprint and the verdict must rest on the gate log's
# lead-authored spawn table instead. The counts print on every path, including this
# one, because "found no violation" and "examined nothing" must not read alike.
#
# USAGE
#   validate-spawn-ledger.sh --ledger <spawn-ledger.jsonl> --sprint <N> --settings <settings.json>
#
# EXIT
#   0  every row for this sprint carries a resolvable role file, a Rule 19(b) contract
#      citation, and a model matching its role's configured pin
#   1  at least one row does not (a Rule 19 violation, clearable only per Check 22's
#      four-arm disposition)
#   2  bad arguments, an unreadable settings.json, or no jq -- nothing was compared
#   3  PRE-LEDGER: the ledger names no row for this sprint. Not a pass.
set -u

LEDGER=""
SPRINT=""
SETTINGS=""
while [ $# -gt 0 ]; do
  # No MODE_DISPATCH markers here on purpose. I49 and I53 bind the MODES of core-paths.sh
  # and validate-escalation-resolution.sh -- verbs another file names in prose and calls by
  # name. These are three required arguments of one invocation, not modes, and nothing reads
  # a marker block in this file. Writing one anyway would put a marker here that looks bound
  # and is not.
  case "$1" in
    --ledger)   LEDGER="${2:-}"; shift 2 ;;
    --sprint)   SPRINT="${2:-}"; shift 2 ;;
    --settings) SETTINGS="${2:-}"; shift 2 ;;
    -h|--help)  sed -n '2,62p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# A fumbled invocation must not share an exit code with a finding. Every argument
# fault exits 2, so a caller reading 1 as "a spawn violated Rule 19" cannot be
# reading a typo, and a caller reading 3 as PRE-LEDGER cannot be reading a path
# that was never passed.
if [ -z "$LEDGER" ] || [ -z "$SPRINT" ] || [ -z "$SETTINGS" ]; then
  echo "FAIL: --ledger <spawn-ledger.jsonl>, --sprint <N> and --settings <settings.json> are all required" >&2
  exit 2
fi
SPRINT_NUM="$(printf '%s' "$SPRINT" | tr -cd '0-9')"
[ -n "$SPRINT_NUM" ] || { echo "FAIL: --sprint must contain a number (got '$SPRINT')" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || {
  echo "FAIL: jq is not on PATH. The ledger is JSONL and nothing here can be compared without it;" >&2
  echo "      this exits 2 rather than reporting a clean ledger it never read." >&2
  exit 2
}
# An unreadable settings.json is NOT a consumer that pins no models -- it is a run that
# cannot answer the model arm at all. `pin_key` treats the two identically by design
# (the guard must fail open), so the distinction has to be made HERE, before the loop,
# or every spawn silently clears the arm it was written to check.
[ -r "$SETTINGS" ] || {
  echo "FAIL: cannot read $SETTINGS. Every role would resolve to 'pins nothing' and every" >&2
  echo "      spawn would clear the model arm without a comparison. Exits 2, not 0." >&2
  exit 2
}

# --- SHARED WITH core/hooks/ai-dlc-dispatch-guard.sh, byte-identical (I56) ------
# See this file's header for why these are copies and not a sourced helper. Do not
# edit one without the other; validate-enforcement-map.sh fails the build on a fork,
# and on either file defining either function more than once.
pin_key() {
  pk_k=""; pk_m=""
  [ -r "$1" ] || return 0
  pk_k="$(jq -r --arg r "$2" '.aiDlcRoles[$r].model // empty' "$1" 2>/dev/null || true)"
  [ -n "$pk_k" ] || return 0
  pk_m="$(jq -r --arg k "$pk_k" '.aiDlcModels[$k] // empty' "$1" 2>/dev/null || true)"
  [ -n "$pk_m" ] && printf '%s\n' "$pk_k"
  return 0
}

matches_pin() {
  [ -n "$EXPECT" ] || return 1
  case "$1" in
    "$EXPECT")   return 0 ;;
    *"$EXPECT"*) return 0 ;;
    *)           return 1 ;;
  esac
}
# --- end shared ----------------------------------------------------------------

# An absent ledger and a ledger holding only other sprints' rows are ONE state, and
# Check 22 says so: a consumer that pulls the guard mid-sprint gets a file whose first
# row is the NEXT dispatch, so "the file exists" and "this sprint is covered" are
# different claims. Both land on exit 3 below.
TOTAL=0
RECORDS=""
if [ -f "$LEDGER" ]; then
  # A ledger jq CANNOT PARSE is not an empty one. `jq -s` fails on the whole file for a
  # single truncated line -- the shape a crashed or concurrent append leaves -- and
  # swallowing that failure would report "0 row(s)" and route to PRE-LEDGER, which reads
  # as "the guard was not installed yet" for a file that is full of rows. Exit 2: nothing
  # was compared, and the reason is not the one PRE-LEDGER states.
  TOTAL="$(jq -rs '[ .[] | select(type == "object") ] | length' "$LEDGER" 2>/dev/null)" || {
    echo "FAIL: $LEDGER is not parseable as JSONL. A single truncated line fails the whole" >&2
    echo "      file, and reporting zero rows for it would be indistinguishable from a" >&2
    echo "      sprint that predates the dispatch guard. Repair or rotate the ledger." >&2
    exit 2
  }
  case "$TOTAL" in ''|*[!0-9]*) TOTAL=0 ;; esac
  # One TAB-separated record per in-sprint row. `sprint` is written as a number by the
  # guard and compared as one; a row whose sprint is null belongs to no sprint and is
  # counted as unattributed rather than silently swept into this one.
  #
  # NO FIELD MAY BE EMPTY, and that is not cosmetic. TAB is an IFS *whitespace*
  # character, so `read` collapses a run of them into one delimiter: a row with a null
  # `model_requested` would shift `role_contract_cited` into the `requested` variable
  # and every later field one place left, and the loop would compare the wrong strings
  # while reporting normally. Absent values carry a sentinel and the loop restores
  # them. (Measured on the first draft of this script: a null `model_requested`
  # reported `requested model='true'`.)
  RECORDS="$(jq -rs --argjson s "$SPRINT_NUM" '
      # `tostring` renders JSON null as the four-character string "null", which would
      # be compared against the pin as though the dispatch had asked for a model
      # called null. Nulls are mapped to the sentinel BEFORE any stringification.
      def tok: if . == null then "__NONE__"
               else (tostring | if . == "" then "__NONE__" else . end) end;
      .[]
      | select(type == "object")
      | select((.sprint // null) == $s)
      | [ (.name | tok),
          (.role | tok),
          (.model_bound | tok),
          (.model_requested | tok),
          (if .role_contract_cited == true then "true" else "false" end),
          (if .role_file_readable == false then "false" else "true" end) ]
      | @tsv
    ' "$LEDGER" 2>/dev/null || true)"
fi

INSPRINT=0
if [ -n "$RECORDS" ]; then
  INSPRINT="$(printf '%s\n' "$RECORDS" | grep -c . || true)"
  case "$INSPRINT" in ''|*[!0-9]*) INSPRINT=0 ;; esac
fi

if [ "$INSPRINT" -eq 0 ]; then
  echo "PRE-LEDGER: ${TOTAL} row(s) in ${LEDGER}, NONE of them S${SPRINT_NUM}'s."
  echo "  This is not a pass. Zero rows and zero spawns are different states and this run"
  echo "  cannot tell them apart: a consumer that installed the dispatch guard mid-sprint"
  echo "  has a ledger whose first row is the NEXT dispatch. Fall back to the gate log's"
  echo "  spawn table and record in the gate log that the verdict rests on lead-authored"
  echo "  evidence rather than a machine record (Check 22)."
  exit 3
fi

CHECKED=0
VIOL=0
UNREADABLE=0
UNCITED=0
MISMATCH=0
CORRECTED=0
UNPINNED=0
while IFS="$(printf '\t')" read -r name role bound requested cited readable; do
  [ -n "$name" ] || continue
  CHECKED=$((CHECKED + 1))
  [ "$name" = "__NONE__" ] && name="<unnamed>"
  [ "$role" = "__NONE__" ] && role=""
  [ "$bound" = "__NONE__" ] && bound=""
  [ "$requested" = "__NONE__" ] && requested=""

  # Fail-closed arm, and it is unconditional: a teammate that ran without a resolvable
  # role-file binding is a Rule 19 violation, not a pass.
  if [ "$readable" = "false" ]; then
    echo "FAIL: [$name] role_file_readable=false -- role '${role:-<none>}' resolved to no readable" >&2
    echo "      role file, so this teammate ran with no contract at all (Rule 19, fail-closed)." >&2
    VIOL=$((VIOL + 1)); UNREADABLE=$((UNREADABLE + 1))
  fi

  # Rule 19(b): the dispatch named its role only via `subagent_type` and carried no
  # contract line. The guard bound the model anyway; the citation is still owed.
  if [ "$cited" != "true" ]; then
    echo "FAIL: [$name] role_contract_cited=false -- the dispatch named role '${role:-<none>}' via" >&2
    echo "      subagent_type alone and cited no Rule 19(b) role contract." >&2
    VIOL=$((VIOL + 1)); UNCITED=$((UNCITED + 1))
  fi

  # Rule 19(a). EXPECT is a global because `matches_pin` reads one -- it is the guard's
  # function verbatim and closes over the same name there.
  EXPECT="$(pin_key "$SETTINGS" "$role")"
  if [ -z "$EXPECT" ]; then
    # A role with no pin, or a key mapping to nothing, binds no model. The party
    # personas legitimately carry an effort and no model, so this is a normal state
    # and not a finding -- but it is COUNTED, because a settings.json that lost its
    # aiDlcRoles block would otherwise clear every row in silence.
    UNPINNED=$((UNPINNED + 1))
  elif ! matches_pin "$bound"; then
    echo "FAIL: [$name] ran on model_bound='${bound}' against role '${role}' pinned to" >&2
    echo "      aiDlcRoles.${role}.model='${EXPECT}'. This is a recorded Rule 19(a) tier" >&2
    echo "      mismatch. It is a fact about the past: clear it only through Check 22's" >&2
    echo "      four-arm disposition, never by re-running the gate." >&2
    VIOL=$((VIOL + 1)); MISMATCH=$((MISMATCH + 1))
  elif [ -n "$requested" ] && ! matches_pin "$requested"; then
    # Reported, NOT failed. Check 22 is explicit: the guard caught the slip before the
    # work ran and the teammate ran on the key its role names.
    echo "NOTE: [$name] requested model='${requested}' against pin '${EXPECT}'; the guard"
    echo "      corrected it to '${bound}' before dispatch. Recorded, not a failure."
    CORRECTED=$((CORRECTED + 1))
  fi
done <<EOF
$RECORDS
EOF

# The counts line prints on every outcome. A verdict that does not say what it compared
# cannot be told apart from one that compared nothing -- which is the whole reason this
# check has an enforcer.
echo "COUNTS: examined ${CHECKED} S${SPRINT_NUM} spawn row(s) of ${TOTAL} in ${LEDGER};"
echo "  ${UNREADABLE} unreadable role file(s), ${UNCITED} missing Rule 19(b) citation(s),"
echo "  ${MISMATCH} tier mismatch(es), ${CORRECTED} guard-corrected request(s) (not failures),"
echo "  ${UNPINNED} row(s) whose role pins no model in ${SETTINGS}."

if [ "$VIOL" -gt 0 ]; then
  echo "FAIL: ${VIOL} Rule 19 violation(s) across ${CHECKED} S${SPRINT_NUM} spawn row(s)." >&2
  exit 1
fi
# THE PIN CLAUSE OF THAT SENTENCE HAS TO HAVE BEEN TESTED TO BE SAID.
# Rule 19(a) is compared only where `EXPECT` is non-empty; a row whose role pins no
# model is COUNTED as UNPINNED and correctly not treated as a finding, because the party
# personas legitimately carry an effort and no model. The counting was already here, and
# the comment beside it already named the hazard -- a settings.json that lost its
# aiDlcRoles block clears every row in silence. But nothing ever READ the count, so the
# hazard it was counting for still ended in this sentence, which asserts every row's
# model matched a pin that was never fetched.
#
# Measured with one ledger, two settings files differing only in the key name
# (`aiDlcRoles` -> `aiDlcRolesXX`), both rows carrying a genuine tier mismatch:
# the intact settings gave `FAIL: 2 Rule 19 violation(s)` rc=1, and the renamed key gave
# the full OK sentence rc=0.
if [ "$CHECKED" -gt 0 ] && [ "$UNPINNED" -eq "$CHECKED" ]; then
  echo "OK WITH NO PIN COMPARED: all ${CHECKED} S${SPRINT_NUM} spawn row(s) carry a resolvable"
  echo "  role file and a Rule 19(b) contract citation. Rule 19(a) was NOT tested on any row:"
  echo "  every role pinned no model in ${SETTINGS}, so the comparison ran zero times."
  echo "  If that file is meant to carry an aiDlcRoles block, this is the shape a lost or"
  echo "  renamed key takes -- it clears every row rather than failing any."
  exit 0
fi
echo "OK: all ${CHECKED} S${SPRINT_NUM} spawn row(s) carry a resolvable role file, a Rule 19(b)"
echo "  contract citation, and a model matching their role's configured pin"
echo "  (${UNPINNED} row(s) pin no model and were not compared)."
exit 0
