#!/usr/bin/env bash
# validate-adversarial-convergence.sh -- the adversarial review cycle must CONVERGE.
#
# WHY THIS EXISTS (v0.48.0). v0.46.0 gave the adversary permission to converge --
# "a clean verdict is a valid outcome" -- but gave it no VOCABULARY to declare one.
# The SKILL_INVOCATION_PROVENANCE schema had no verdict field at all, so the role
# invented one. The measured result on S289's research-requirements cycle:
#
#   pass 4 returned 0 CRITICAL, 0 MAJOR, wrote "The repair wave converged" in its
#   prose -- and then stamped `verdict: EXIT CONDITION NOT MET`, the identical
#   string pass 3 emitted. The lead read the prose, applied the two one-line
#   deletions, and passed the S5 planning gate anyway. The gate therefore passed
#   while the last adversarial artifact of record said the exit condition was NOT
#   met. Termination came from the lead overriding the adversary's own field, not
#   from the machinery converging.
#
# That is the failure this script makes impossible to commit. Rule 8 already says
# the cycle "must CONVERGE to leave it" and that "divergence is a HARD_BLOCK";
# until now nothing counted a CRITICAL or read a verdict.
#
# WHAT IT CHECKS. Given a pass series (pass1..passN artifacts for ONE step's
# adversarial cycle), each carrying a SKILL_INVOCATION_PROVENANCE block:
#
#   A  VOCABULARY   every pass declares `verdict:` from the enumerated set.
#   B  CONSISTENCY  the verdict agrees with the severity residue it reports.
#                   0 CRITICAL + 0 MAJOR means the exit condition IS met -- the
#                   ladder in team-roles/adversary.md puts MINOR/NIT in the
#                   nitpick bucket, and the step's exit condition is "continue
#                   until only nitpicks remain". A pass that reports a clean
#                   residue and still stamps NOT_MET is refusing to converge.
#   C  DIVERGENCE   CRITICALs rising pass-over-pass is a HARD_BLOCK, not a reason
#                   for another pass (Rule 8). A rising pass MUST stamp
#                   DIVERGENT_HARD_BLOCK; anything else is the endless cycle.
#   D  TERMINAL     the LAST pass in the series must be EXIT_CONDITION_MET. This
#                   is the gate-passed-over-an-unmet-verdict catch.
#
# It does NOT enforce the per-intensity pass FLOOR ("2+ passes"). Rule 8 delegates
# that to each planning step's own intensity gate, and duplicating it here would
# fail every legitimate `standard`/`lightweight` single-pass cycle.
#
# USAGE
#   validate-adversarial-convergence.sh --series <path-prefix>
#       Globs <path-prefix>*, orders by the passN in each filename.
#       e.g. --series _bmad-output/planning-artifacts/s289-rr-adversarial-pass
#   validate-adversarial-convergence.sh <file> [<file>...]
#       Explicit series, in pass order.
#
# EXIT
#   0  the cycle converged: every pass is adjudicable, consistent, non-divergent,
#      and the last pass stamps EXIT_CONDITION_MET.
#   1  any check above failed (offenders named), or no series was resolved.
set -u

SERIES_PREFIX=""
FILES=()

while [ $# -gt 0 ]; do
  case "$1" in
    --series) SERIES_PREFIX="$2"; shift 2 ;;
    -h|--help) sed -n '2,50p' "$0"; exit 0 ;;
    -*) echo "unknown argument: $1" >&2; exit 1 ;;
    *) FILES+=("$1"); shift ;;
  esac
done

if [ -n "$SERIES_PREFIX" ]; then
  for f in "$SERIES_PREFIX"*; do
    [ -f "$f" ] && FILES+=("$f")
  done
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "FAIL: no adversarial pass artifacts resolved."
  if [ -n "$SERIES_PREFIX" ]; then
    echo "      --series '$SERIES_PREFIX' matched nothing."
  else
    echo "      pass --series <path-prefix> or an explicit file list."
  fi
  echo
  echo "An adversarial cycle that wrote no artifact is a cycle that did not run."
  echo "Rule 20: the file IS the deliverable; an absent file is non-delivery."
  exit 1
fi

# Order by the pass number embedded in the filename (pass1, pass2, ... pass10).
# Files with no passN sort last, in encounter order, and are reported as
# un-orderable rather than silently folded into the chain.
order_key() {
  case "$1" in
    *pass[0-9]*)
      n="${1##*pass}"; n="${n%%[!0-9]*}"
      printf '%03d' "$n" 2>/dev/null || echo 999
      ;;
    *) echo 999 ;;
  esac
}

SORTED=()
while IFS= read -r line; do
  SORTED+=("${line#* }")
done < <(
  for f in "${FILES[@]}"; do
    printf '%s %s\n' "$(order_key "$f")" "$f"
  done | sort -s -k1,1
)

# ---- provenance field extraction -------------------------------------------
# The block is an HTML comment; fields are `key: value` lines inside it.
block_field() {
  # $1 file, $2 key
  awk -v key="$2" '
    /SKILL_INVOCATION_PROVENANCE v1/ { inblk=1; next }
    /SKILL_INVOCATION_PROVENANCE_END/ { inblk=0 }
    inblk {
      if ($0 ~ "^" key ":") { sub("^" key ":[ \t]*", ""); print; exit }
    }
  ' "$1"
}

# Severity count for one class. Prefers the structured field the v0.48.0 schema
# mandates (findings_critical:); falls back to parsing the free-text `findings:`
# summary line so a pre-v0.48.0 artifact is still adjudicable where it can be.
# Prints the integer, or empty when neither source yields one.
severity_count() {
  # $1 file, $2 CRITICAL|MAJOR|MINOR
  local f="$1" class="$2" lower structured free
  lower="$(printf '%s' "$class" | tr '[:upper:]' '[:lower:]')"

  structured="$(block_field "$f" "findings_${lower}")"
  structured="$(printf '%s' "$structured" | tr -cd '0-9')"
  if [ -n "$structured" ]; then
    printf '%s' "$structured"
    return
  fi

  # Fallback: "findings: 14 (4 CRITICAL, 6 MAJOR, ...)" / "findings: 7 CRITICAL, 6 MAJOR, ..."
  free="$(block_field "$f" 'findings')"
  printf '%s' "$free" | grep -oiE '[0-9]+[ ]+'"$class" | head -1 | tr -cd '0-9'
}

normalize_verdict() {
  printf '%s' "$1" \
    | tr '[:lower:]' '[:upper:]' \
    | sed -e 's/[^A-Z]\{1,\}/_/g' -e 's/^_//' -e 's/_$//'
}

VALID_VERDICTS="EXIT_CONDITION_MET EXIT_CONDITION_NOT_MET DIVERGENT_HARD_BLOCK"

# Passes that found CRITICALs in scope the previous pass never saw. Derived from
# findings_critical vs findings_critical_prior_scope; Check D turns it into the
# remedy. Stays 0 for a pre-v0.52.0 series (absent field => prior == crit).
SCOPE_GREW=0

ERRORS=0
err() { ERRORS=$((ERRORS + 1)); printf 'FAIL (%s): %s\n' "$1" "$2"; }

echo "adversarial convergence -- ${#SORTED[@]} pass artifact(s)"
echo

PREV_CRIT=""
PREV_FILE=""
LAST_VERDICT=""
LAST_FILE=""

for f in "${SORTED[@]}"; do
  raw_verdict="$(block_field "$f" 'verdict')"
  verdict="$(normalize_verdict "$raw_verdict")"
  crit="$(severity_count "$f" CRITICAL)"
  major="$(severity_count "$f" MAJOR)"

  printf '  %s\n' "$f"
  printf '    verdict=%s critical=%s major=%s\n' \
    "${verdict:-<none>}" "${crit:-<unparseable>}" "${major:-<unparseable>}"

  # --- A. VOCABULARY --------------------------------------------------------
  if [ -z "$verdict" ]; then
    err "A -- VOCABULARY" "$f declares no 'verdict:' in its SKILL_INVOCATION_PROVENANCE block.
      A pass with no verdict is un-adjudicable: the cycle cannot be shown to have
      converged, and the gate downstream has nothing to read. Emit one of:
      $VALID_VERDICTS"
  elif ! printf '%s' "$VALID_VERDICTS" | tr ' ' '\n' | grep -qx "$verdict"; then
    err "A -- VOCABULARY" "$f declares verdict '$raw_verdict', which is not in the
      enumerated set. Free-text verdicts are why v0.46.0 half-landed. Emit one of:
      $VALID_VERDICTS"
  fi

  # --- B. CONSISTENCY -------------------------------------------------------
  if [ -n "$crit" ] && [ -n "$major" ]; then
    if [ "$verdict" = "EXIT_CONDITION_MET" ] && { [ "$crit" -gt 0 ] || [ "$major" -gt 0 ]; }; then
      err "B -- CONSISTENCY" "$f stamps EXIT_CONDITION_MET while reporting
      $crit CRITICAL and $major MAJOR. The exit condition is 'only nitpicks remain'
      (team-roles/adversary.md severity ladder: MINOR/NIT is the nitpick bucket).
      A CRITICAL or a MAJOR is not a nitpick. This verdict claims a convergence the
      residue contradicts."
    fi
    if [ "$verdict" = "EXIT_CONDITION_NOT_MET" ] && [ "$crit" -eq 0 ] && [ "$major" -eq 0 ]; then
      err "B -- CONSISTENCY" "$f reports 0 CRITICAL and 0 MAJOR and still stamps
      EXIT_CONDITION_NOT_MET. Under the severity ladder that residue IS 'only
      nitpicks remain' -- the exit condition is MET. This is the S289 pass-4 shape:
      the review converged, said so in its prose, and then refused to say so in the
      field the gate reads. Stamp EXIT_CONDITION_MET, or reclassify the residue."
    fi
  fi

  # --- C. DIVERGENCE (scope-relative) ---------------------------------------
  # findings_critical counts a POPULATION. Comparing two of them across passes
  # assumes both counted the same document -- and between pass N and N+1 the sprint
  # can ADD SCOPE, at which point the comparison is not a comparison.
  #
  # Measured on the reference consumer, S290: CRITICALs ran 3,1,1,2,2,2,3,2 and the
  # bare predicate hard-blocked twice (p4: 2>1, p7: 3>2). BOTH times its stated cause
  # was false. Pass 7, first line: "The rise is NOT pass 6's repairs injecting
  # defects -- I probed those and they hold. Every new CRITICAL is in the scope the
  # sprint ADDED after pass 6 closed." The adversary wrote PROSE to override the field
  # it had just stamped -- v0.48.0's defect inverted, and it cost two operator
  # adjudications. The two conditions have OPPOSITE remedies: "your repairs are bad"
  # vs "the sprint grew; cut it".
  #
  # findings_critical_prior_scope partitions the count: of your CRITICALs, how many
  # sit in text the PREVIOUS pass also reviewed. Only THOSE are comparable.
  #
  # FAIL-CLOSED DEFAULT: absent field => prior := crit => this degrades to EXACTLY
  # the pre-v0.52.0 predicate. It can only make C stricter, never laxer, so the
  # missing field cannot be used to dodge a hard block -- which is what makes it safe
  # to adopt mid-cycle against passes stamped under the old schema.
  prior="$(block_field "$f" 'findings_critical_prior_scope' | tr -cd '0-9')"
  [ -z "$prior" ] && prior="$crit"

  # Sanity: the partition cannot exceed the whole. Catches a typo and a dishonest
  # field in the same assertion.
  if [ -n "$crit" ] && [ -n "$prior" ] && [ "$prior" -gt "$crit" ]; then
    err "C -- DIVERGENCE" "$f declares findings_critical_prior_scope=$prior but only
      $crit CRITICAL. The prior-scope count is a SUBSET of your CRITICALs -- it cannot
      exceed them."
  fi

  if [ -n "$prior" ] && [ -n "$PREV_CRIT" ] && [ "$prior" -gt "$PREV_CRIT" ]; then
    if [ "$verdict" != "DIVERGENT_HARD_BLOCK" ]; then
      err "C -- DIVERGENCE" "$f reports $prior CRITICAL in scope the previous pass had
      already reviewed, up from $PREV_CRIT in $PREV_FILE, and does not stamp
      DIVERGENT_HARD_BLOCK.
      Rule 8: divergence is a HARD_BLOCK, not a reason for another pass. These are
      defects the REPAIR injected into text that had already been cleared; pass N+1
      only finds the next wave. STOP and escalate.
      (CRITICALs in scope the sprint ADDED since the previous pass are NOT divergence
      and do not count here -- if that is what you found, declare
      findings_critical_prior_scope and stamp EXIT_CONDITION_NOT_MET instead.)"
    fi
  fi

  # Did this pass find CRITICALs in scope that did not exist at the previous pass?
  # Derived from the one field; no second field. Check D reads it.
  if [ -n "$crit" ] && [ -n "$prior" ] && [ "$crit" -gt "$prior" ]; then
    SCOPE_GREW=$((SCOPE_GREW + 1))
  fi

  if [ -n "$crit" ]; then PREV_CRIT="$crit"; PREV_FILE="$f"; fi
  LAST_VERDICT="$verdict"
  LAST_FILE="$f"
done

echo

# --- D. TERMINAL ------------------------------------------------------------
case "$LAST_VERDICT" in
  EXIT_CONDITION_MET) ;;
  DIVERGENT_HARD_BLOCK)
    err "D -- TERMINAL" "the series ends at $LAST_FILE with DIVERGENT_HARD_BLOCK.
      The cycle diverged and was never brought back. A gate cannot pass over an
      escalated hard block -- resolve the divergence (shrink the artifact, change
      approach), then re-run the cycle to a clean pass." ;;
  "")
    err "D -- TERMINAL" "the series ends at $LAST_FILE with no verdict at all.
      The gate has nothing to read." ;;
  *)
    if [ "$SCOPE_GREW" -gt 0 ]; then
      # The cycle is not failing to converge. It is being asked to converge on a
      # MOVING ARTIFACT, and it cannot. S290 ran EIGHT passes this way: every repair
      # subtracted, and the sprint grew underneath them faster than the passes could
      # cut. "Run another pass" is the advice that produced passes 2 through 8.
      err "D -- TERMINAL" "the series ends at $LAST_FILE with $LAST_VERDICT after
      $SCOPE_GREW pass(es) that found CRITICALs in scope ADDED since the pass before
      them.
      The cycle is not failing to converge -- it is being asked to converge on a
      MOVING ARTIFACT. Another pass is NOT the remedy: the next one will review
      whatever was added since this one, and the series will not terminate.
      FREEZE the artifact under review, CUT the added scope (Rule 25(d)), and run the
      cycle to a clean pass on the frozen scope. The exit condition is reachable --
      it is reachable the moment the document stops moving."
    else
      err "D -- TERMINAL" "the series ends at $LAST_FILE with $LAST_VERDICT.
      The gate is being asked to pass over an adversarial cycle whose own last
      artifact says the exit condition is not met. Either run another pass to a
      clean verdict, or -- if the residue is already clean -- stamp the verdict the
      residue supports. Do not pass the gate by overriding the field in prose."
    fi ;;
esac

if [ "$ERRORS" -gt 0 ]; then
  echo "FAIL: $ERRORS convergence violation(s)."
  exit 1
fi

echo "PASS: the cycle converged -- last pass stamps EXIT_CONDITION_MET, no divergent pass, every verdict adjudicable."
exit 0
