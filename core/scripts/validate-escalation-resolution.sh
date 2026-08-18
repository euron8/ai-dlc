#!/usr/bin/env bash
# validate-escalation-resolution.sh -- an operator-gated HARD_BLOCK must not be marked
# RESOLVED by an operator who never spoke.
#
# WHY THIS EXISTS (v0.61.0). gate-validation.md Check 2 ("no unresolved HARD_BLOCKs") reads
# docs/escalations/pending.md and blocks on any HARD_BLOCK that is not RESOLVED. But "RESOLVED"
# was a token the LEAD writes, checked by nobody. A HARD_BLOCK exists precisely because the
# decision is the operator's (Rule 8 / Rule 11(a)); marking it RESOLVED asserts the operator
# adjudicated it. Nothing tied that assertion to a real operator message.
#
# Measured on the reference consumer's S290: during a window with ZERO operator messages, the
# lead authored six `## S290-* Lead (...)` escalation entries and flipped each to RESOLVED --
# "operator dispositions" the operator never made. The consumer's own carry-over-evaluation
# filed CO-S290-ESCALATION-SCHEMA-AND-CHECK2-VALIDATOR against exactly this gap. This is it.
#
# WHAT IT CHECKS. For each escalation entry in the CURRENT sprint whose Status is RESOLVED or
# OVERRIDDEN (the two operator-decision terminal states), the entry MUST carry an
# `Operator authorization:` CITATION -- an ISO timestamp plus a verbatim substring of the
# operator's own message -- and that substring must appear in a GENUINE operator message in the
# session transcript. Verification delegates to validate-steering-budget.sh --cite, THE
# genuine-operator predicate (shared with Rule 29 Check B and the convergence validator's F6),
# so there is one definition of "a real human said this", never several that can drift.
#
# SCOPE IS THE CURRENT SPRINT, and that is load-bearing. pending.md accumulates RESOLVED entries
# from many prior sprints, resolved in sessions this transcript never saw. Requiring a
# current-transcript citation for all of them would fail every gate on legacy data. The entry
# headers carry the sprint (`## S290-...`, `### HB-S290-...`), so we check only this sprint's
# resolutions -- the ones whose operator adjudication, if real, is in THIS transcript.
#
# DECIDED_AUTONOMOUSLY is deliberately NOT required to cite. It is the honest-attribution escape
# valve: a decision the lead genuinely made on its own is labeled as such (and Check 2 treats it
# as informational, non-blocking). The dishonest move this stops is claiming the OPERATOR decided.
#   Residual (documented, not closed here): a lead could relabel a HARD_BLOCK's resolution as
#   DECIDED_AUTONOMOUSLY to dodge the citation. That bypass PRE-DATES this check (Check 2 already
#   treats DECIDED_AUTONOMOUSLY as non-blocking); closing it needs a baseline diff of who was ever
#   a HARD_BLOCK, which is a later increment.
#
# --any-authorized: THE SAME DEFINITION, ASKED WITHOUT A TRANSCRIPT. `core-paths.sh
# --audit-diff` offers the operator an escape hatch from the core-layer-immutability backstop,
# and until now it decided whether one had been granted with `grep -q 'Operator authorization:'`
# over the whole of pending.md. That is a SECOND definition of "the operator authorized this",
# and it had already drifted from this one in every direction that matters: it counts a line in
# the file preamble that belongs to no entry, a line inside an entry the lead resolved on its own
# authority (`DECIDED_AUTONOMOUSLY`, which escalations.md says needs no citation and is not an
# operator adjudication), and prose that merely SAYS the words. Measured on the reference
# consumer: of the 8 lines that satisfy the grep, one sits in the preamble, three are prose
# discussing the convention -- one of them the sentence "No `Operator authorization:` citation
# exists or is required for this status" -- and four are real fields, of which one is on a
# DECIDED_AUTONOMOUSLY entry. The negation of the thing satisfied the check for the thing.
#
# So the hatch now ASKS THIS SCRIPT, which owns the grammar, instead of restating a looser one.
# This mode answers the one question a caller with no transcript can answer: does this file
# carry at least one citation that is SHAPED like a citation and sits on an entry whose status
# says the operator, not the lead, decided? It does NOT claim the citation covers any particular
# change -- that is still the adjudicator's call, and --audit-diff still says so in its output.
#
# --transcript-dir: THE CORPUS THE CITATION ACTUALLY LIVES IN, and it takes precedence over
# --transcript. A sprint spans sessions; an escalation resolved on Monday is re-gated on Friday,
# and `transcript_path` is always the session ASKING permission -- never the one in which the
# operator spoke. Checking a single file therefore rejected adjudications the operator really
# made, and this arm fails CLOSED, so the rejection reads as an accusation: the entry is reported
# as the S290 fabrication and the gate stops. Supplying ground truth was strictly worse than
# supplying none, because a readable transcript merely LACKING the quote fails while an absent
# one at least names its own ignorance.
#
# MEASURED ON THE REFERENCE CONSUMER, not inferred. The gate invocation gate-validation.md
# specifies, run against the live pending.md at the current sprint with the newest session
# transcript, failed 4 of 4 operator-resolved HARD_BLOCKs. All four quotes are GENUINE -- a
# --dir scan of the 382-transcript corpus matches every one (control: an invented phrase
# NOMATCHes, so the scan discriminates). Three of the four are AskUserQuestion option labels,
# which is the shape a real adjudication takes when the lead offers choices.
#
# This is the same defect validate-adversarial-convergence.sh carries a dir arm for, in the
# sibling that shares its citation predicate. Fixing one and not the other left the deadlock
# reachable through the other door.
#
# USAGE
#   validate-escalation-resolution.sh --escalations <pending.md> --sprint <N> [--transcript PATH]
#   validate-escalation-resolution.sh --escalations <pending.md> --sprint <N> [--transcript-dir DIR]
#   validate-escalation-resolution.sh --any-authorized <pending.md>
#
# EXIT
#   0  every current-sprint RESOLVED/OVERRIDDEN entry cites a verified operator message (or none
#      are in scope); --any-authorized: at least one well-formed citation on a terminal entry
#   1  a current-sprint resolution cites no genuine operator message, or omits the citation, or
#      (gate mode) no transcript was provided to verify against; --any-authorized: no entry in
#      the file carries a well-formed operator citation
#   2  bad arguments / unreadable escalations file
set -u

# A DIRECTORY IS NOT A CORPUS. `-d` answers whether the path EXISTS, never whether it holds
# any ground truth. With nothing to search, the message below reports the operator as having
# said nothing — an accusation, where the true state is that the gate had no corpus. The
# corpus reader selects `*.jsonl` (`validate-steering-budget.sh:427`), so a directory holding
# only sidecar files is exactly as blind as an empty one and this counts what that reader
# would count. Failing here falls through to the single-file branch. This predicate is
# byte-identical in `validate-adversarial-convergence.sh` and `core/hooks/`
# `ai-dlc-gate-remediation-guard.sh`; invariant I92 holds the three copies to one text and
# refuses a fourth.
steer_dir_has_transcript() { # $1 dir -> 0 if it holds a readable *.jsonl
  [ -n "${1:-}" ] && [ -d "$1" ] || return 1
  for _sdht in "$1"/*.jsonl; do
    [ -r "$_sdht" ] && return 0
  done
  return 1
}

ESCALATIONS=""
SPRINT=""
TRANSCRIPT=""
TRANSCRIPT_DIR=""
ANY_AUTHORIZED=0
while [ $# -gt 0 ]; do
  case "$1" in
# MODE_DISPATCH_BEGIN
    --escalations) ESCALATIONS="${2:-}"; shift 2 ;;
    --sprint)      SPRINT="${2:-}"; shift 2 ;;
    --transcript)  TRANSCRIPT="${2:-}"; shift 2 ;;
    --transcript-dir) TRANSCRIPT_DIR="${2:-}"; shift 2 ;;
    --any-authorized) ANY_AUTHORIZED=1; ESCALATIONS="${2:-}"; shift 2 ;;
# MODE_DISPATCH_END
    -h|--help)     sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# The sibling steering-budget validator owns THE genuine-operator predicate (--cite). Resolve it
# relative to $0 so this works in the distribution (core/scripts/) and the consumer (scripts/).
STEER_SCRIPT="$(cd "$(dirname "$0")" && pwd)/validate-steering-budget.sh"

if [ "$ANY_AUTHORIZED" -eq 1 ]; then
  [ -n "$ESCALATIONS" ] || { echo "FAIL: --any-authorized <pending.md> needs a path" >&2; exit 2; }
  # An absent file is a clean state for the gate mode above and the OPPOSITE here: no file is no
  # citation, and a caller asking "was this authorized?" must not read "nothing to check" as yes.
  [ -f "$ESCALATIONS" ] || { echo "NONE: no escalations file ($ESCALATIONS), so no operator citation exists."; exit 1; }
  SPRINT_NUM=""
else
  if [ -z "$ESCALATIONS" ] || [ -z "$SPRINT" ]; then
    echo "FAIL: --escalations <pending.md> and --sprint <N> are required" >&2
    exit 2
  fi
  # No escalations file is a legitimate clean state -- nothing to adjudicate.
  [ -f "$ESCALATIONS" ] || { echo "OK: no escalations file ($ESCALATIONS); nothing to check."; exit 0; }

  # Normalize the sprint token: accept "290" or "S290".
  SPRINT_NUM="$(printf '%s' "$SPRINT" | tr -cd '0-9')"
  [ -n "$SPRINT_NUM" ] || { echo "FAIL: --sprint must contain a number (got '$SPRINT')" >&2; exit 2; }
fi

# Split pending.md into entries and, for each CURRENT-SPRINT entry whose Status is RESOLVED or
# OVERRIDDEN, emit one TAB-separated record: <header>\t<STATUS>\t<auth-line-or-__MISSING__>.
# The auth line is whatever follows an "Operator authorization:" (or "operator_authorization:")
# label, verbatim, so bash can parse the timestamp + quoted substring exactly as F6 does.
RECORDS="$(awk -v sprint="$SPRINT_NUM" -v anyauth="$ANY_AUTHORIZED" '
  function flush() {
    if (header == "") return
    if (status != "RESOLVED" && status != "OVERRIDDEN") return
    # --any-authorized asks about the FILE, so every terminal entry is in scope. The gate mode is
    # in scope only if the header names THIS sprint (S<N> not followed by another digit).
    if (anyauth == 1 || header ~ ("[Ss]" sprint "([^0-9]|$)")) {
      printf "%s\t%s\t%s\n", header, status, (auth == "" ? "__MISSING__" : auth)
    }
  }
  /^#{2,3} / {
    flush()
    header = $0; status = ""; auth = ""
    next
  }
  # Status token: first ALL-CAPS word after the label.
  /^\*\*[Ss]tatus:\*\*/ {
    s = $0
    sub(/^\*\*[Ss]tatus:\*\*[[:space:]]*/, "", s)
    if (match(s, /[A-Z_]+/)) status = substr(s, RSTART, RLENGTH)
    next
  }
  # Operator-authorization citation line (with or without ** markdown, _ or space).
  #
  # THE LABEL MUST OPEN THE LINE. escalations.md writes this as a FIELD of an entry, beside
  # **Status:** and **Context:**, and a field is the thing at the start of its own line. This
  # test used to be "the label appears anywhere on the line", which also matched an entry
  # discussing the convention in prose -- including, on the reference consumer, a sentence
  # reading "No `Operator authorization:` citation exists or is required for this status."
  # A body that says a citation does not exist is not a citation. Leading blockquote, list and
  # emphasis markers are stripped first so `> `, `- ` and `**` spellings all still count.
  {
    lbl = $0
    gsub(/^[[:space:]>*_-]+/, "", lbl)
  }
  tolower(lbl) ~ /^operator[_ ]authorization:/ {
    a = $0
    sub(/^[^:]*:[[:space:]]*/, "", a)
    if (auth == "") auth = a
    next
  }
  END { flush() }
' "$ESCALATIONS")"

# --- --any-authorized: shape only, no transcript, no sprint ------------------------------------
# Reports the COUNTS it compared, because "no citation found" and "no entry was ever examined"
# are different facts and a caller that cannot tell them apart will read the second as the first.
if [ "$ANY_AUTHORIZED" -eq 1 ]; then
  TERMINAL=0; AUTHORIZED=0; FIRST=""
  while IFS="$(printf '\t')" read -r header status authline; do
    [ -n "$header" ] || continue
    TERMINAL=$((TERMINAL + 1))
    [ "$authline" = "__MISSING__" ] && continue
    [ -n "$authline" ] || continue
    quote="$(printf '%s' "$authline" | sed -n 's/.*"\(.*\)".*/\1/p')"
    [ -z "$quote" ] && quote="$(printf '%s' "${authline#*|}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    [ "${#quote}" -lt 12 ] && continue
    AUTHORIZED=$((AUTHORIZED + 1))
    [ -n "$FIRST" ] || FIRST="$(printf '%s' "$header" | sed -E 's/^#+ //' | cut -c1-72)"
  done <<EOF
$RECORDS
EOF
  if [ "$AUTHORIZED" -gt 0 ]; then
    echo "AUTHORIZED: ${AUTHORIZED} of ${TERMINAL} RESOLVED/OVERRIDDEN entr(ies) in ${ESCALATIONS} carry a"
    echo "  well-formed 'Operator authorization:' citation. First: ${FIRST}"
    exit 0
  fi
  echo "NONE: ${TERMINAL} RESOLVED/OVERRIDDEN entr(ies) in ${ESCALATIONS}, none carrying a well-formed"
  echo "  'Operator authorization:' field (a line-leading label, an ISO timestamp and a verbatim"
  echo "  operator quote of >=12 characters -- escalations.md). A DECIDED_AUTONOMOUSLY entry is the"
  echo "  lead's own call and is not one; prose naming the convention is not one either."
  exit 1
fi

if [ -z "$RECORDS" ]; then
  echo "OK: no S${SPRINT_NUM} RESOLVED/OVERRIDDEN escalation requires an operator citation."
  exit 0
fi

FAIL=0
FAILN=0
CHECKED=0
while IFS="$(printf '\t')" read -r header status authline; do
  [ -n "$header" ] || continue
  CHECKED=$((CHECKED + 1))
  short="$(printf '%s' "$header" | sed -E 's/^#+ //; s/ - [0-9].*$//' | cut -c1-60)"

  if [ "$authline" = "__MISSING__" ] || [ -z "$authline" ]; then
    echo "FAIL: [$short] is $status but carries no 'Operator authorization:' citation." >&2
    echo "      A $status HARD_BLOCK asserts the operator adjudicated it. Cite the operator's own" >&2
    echo "      words: Operator authorization: <ISO-8601 UTC ts> | \"<verbatim substring, >=12 chars>\"" >&2
    echo "      If you decided this yourself, its status is DECIDED_AUTONOMOUSLY, not $status." >&2
    FAIL=1; FAILN=$((FAILN + 1)); continue
  fi

  quote="$(printf '%s' "$authline" | sed -n 's/.*"\(.*\)".*/\1/p')"
  [ -z "$quote" ] && quote="$(printf '%s' "${authline#*|}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
  if [ "${#quote}" -lt 12 ]; then
    echo "FAIL: [$short] operator authorization quotes '${quote}', too short (>=12 chars) to verify." >&2
    FAIL=1; FAILN=$((FAILN + 1)); continue
  fi

  # The corpus wins over the single file. A resolution OUTLIVES the session that recorded it,
  # so the one transcript a caller can name is the least likely place the operator spoke.
  # SCALARS, NOT AN ARRAY. `arr=()` then `${#arr[@]}` under `set -u` is an unbound-variable
  # error on bash 3.2, which is what macOS ships and what this repo has already shipped a
  # silent fail-open on once.
  STEER_FLAG=""; STEER_ARG=""
  if steer_dir_has_transcript "$TRANSCRIPT_DIR"; then
    STEER_FLAG="--dir"; STEER_ARG="$TRANSCRIPT_DIR"
  elif [ -n "$TRANSCRIPT" ] && [ -r "$TRANSCRIPT" ]; then
    STEER_FLAG="--transcript"; STEER_ARG="$TRANSCRIPT"
  fi
  if [ -z "$STEER_FLAG" ]; then
    # Gate fails CLOSED: an operator-gated resolution cannot be accepted with no ground truth to
    # verify it against. (This runs at the gate; there is no fail-open hook tier here.)
    echo "FAIL: [$short] is $status and cites an operator, but no readable transcript was provided" >&2
    echo "      (--transcript-dir, or --transcript) to verify it. The gate cannot accept an" >&2
    echo "      unverifiable operator disposition." >&2
    FAIL=1; FAILN=$((FAILN + 1)); continue
  fi
  if [ ! -f "$STEER_SCRIPT" ]; then
    echo "FAIL: [$short] cannot verify the citation -- $STEER_SCRIPT is missing. Reinstall ai-dlc." >&2
    FAIL=1; FAILN=$((FAILN + 1)); continue
  fi

  bash "$STEER_SCRIPT" "$STEER_FLAG" "$STEER_ARG" --cite "$quote" --quiet >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ]; then
    # NAME THE CORPUS THAT WAS SEARCHED. The sibling prints its own corpus identity and this
    # caller discards it, so this accusation is otherwise made over a corpus the reader cannot
    # see -- and a wrong-corpus run reads exactly like a real S290 fabrication.
    echo "FAIL: [$short] operator authorization quotes \"${quote}\", which appears in NO genuine" >&2
    echo "      operator message in the transcript searched (${STEER_ARG}). A lead-authored" >&2
    echo "      'operator disposition' is not an operator adjudication. This is the S290 failure." >&2
    FAIL=1; FAILN=$((FAILN + 1)); continue
  elif [ "$rc" -ne 0 ]; then
    echo "FAIL: [$short] operator authorization could not be verified (validator rc=$rc)." >&2
    FAIL=1; FAILN=$((FAILN + 1)); continue
  fi
done <<EOF
$RECORDS
EOF

if [ "$FAIL" -ne 0 ]; then
  echo "FAIL: ${FAILN} of ${CHECKED} S${SPRINT_NUM} operator-resolved HARD_BLOCK(s) not backed by a real operator message." >&2
  exit 1
fi
echo "OK: all ${CHECKED} S${SPRINT_NUM} RESOLVED/OVERRIDDEN escalation(s) cite a verified operator message."
exit 0
