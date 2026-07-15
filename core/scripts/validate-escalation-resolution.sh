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
# USAGE
#   validate-escalation-resolution.sh --escalations <pending.md> --sprint <N> [--transcript PATH]
#
# EXIT
#   0  every current-sprint RESOLVED/OVERRIDDEN entry cites a verified operator message (or none
#      are in scope)
#   1  a current-sprint resolution cites no genuine operator message, or omits the citation, or
#      (gate mode) no transcript was provided to verify against
#   2  bad arguments / unreadable escalations file
set -u

ESCALATIONS=""
SPRINT=""
TRANSCRIPT=""
while [ $# -gt 0 ]; do
  case "$1" in
    --escalations) ESCALATIONS="${2:-}"; shift 2 ;;
    --sprint)      SPRINT="${2:-}"; shift 2 ;;
    --transcript)  TRANSCRIPT="${2:-}"; shift 2 ;;
    -h|--help)     sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

# The sibling steering-budget validator owns THE genuine-operator predicate (--cite). Resolve it
# relative to $0 so this works in the distribution (core/scripts/) and the consumer (scripts/).
STEER_SCRIPT="$(cd "$(dirname "$0")" && pwd)/validate-steering-budget.sh"

if [ -z "$ESCALATIONS" ] || [ -z "$SPRINT" ]; then
  echo "FAIL: --escalations <pending.md> and --sprint <N> are required" >&2
  exit 2
fi
# No escalations file is a legitimate clean state -- nothing to adjudicate.
[ -f "$ESCALATIONS" ] || { echo "OK: no escalations file ($ESCALATIONS); nothing to check."; exit 0; }

# Normalize the sprint token: accept "290" or "S290".
SPRINT_NUM="$(printf '%s' "$SPRINT" | tr -cd '0-9')"
[ -n "$SPRINT_NUM" ] || { echo "FAIL: --sprint must contain a number (got '$SPRINT')" >&2; exit 2; }

# Split pending.md into entries and, for each CURRENT-SPRINT entry whose Status is RESOLVED or
# OVERRIDDEN, emit one TAB-separated record: <header>\t<STATUS>\t<auth-line-or-__MISSING__>.
# The auth line is whatever follows an "Operator authorization:" (or "operator_authorization:")
# label, verbatim, so bash can parse the timestamp + quoted substring exactly as F6 does.
RECORDS="$(awk -v sprint="$SPRINT_NUM" '
  function flush() {
    if (header == "") return
    # In scope only if the header names THIS sprint (S<N> not followed by another digit).
    if (header ~ ("[Ss]" sprint "([^0-9]|$)") && (status == "RESOLVED" || status == "OVERRIDDEN")) {
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
  tolower($0) ~ /operator[_ ]authorization:/ {
    a = $0
    sub(/^[^:]*:[[:space:]]*/, "", a)
    if (auth == "") auth = a
    next
  }
  END { flush() }
' "$ESCALATIONS")"

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

  if [ -z "$TRANSCRIPT" ] || [ ! -r "$TRANSCRIPT" ]; then
    # Gate fails CLOSED: an operator-gated resolution cannot be accepted with no ground truth to
    # verify it against. (This runs at the gate; there is no fail-open hook tier here.)
    echo "FAIL: [$short] is $status and cites an operator, but no readable transcript was provided" >&2
    echo "      (--transcript) to verify it. The gate cannot accept an unverifiable operator disposition." >&2
    FAIL=1; FAILN=$((FAILN + 1)); continue
  fi
  if [ ! -f "$STEER_SCRIPT" ]; then
    echo "FAIL: [$short] cannot verify the citation -- $STEER_SCRIPT is missing. Reinstall ai-dlc." >&2
    FAIL=1; FAILN=$((FAILN + 1)); continue
  fi

  bash "$STEER_SCRIPT" --transcript "$TRANSCRIPT" --cite "$quote" --quiet >/dev/null 2>&1
  rc=$?
  if [ "$rc" -eq 2 ]; then
    echo "FAIL: [$short] operator authorization quotes \"${quote}\", which appears in NO genuine" >&2
    echo "      operator message in the transcript. A lead-authored 'operator disposition' is not" >&2
    echo "      an operator adjudication. This is the S290 failure." >&2
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
