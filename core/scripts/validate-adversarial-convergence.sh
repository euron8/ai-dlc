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

  # --- C. DIVERGENCE --------------------------------------------------------
  if [ -n "$crit" ] && [ -n "$PREV_CRIT" ] && [ "$crit" -gt "$PREV_CRIT" ]; then
    if [ "$verdict" != "DIVERGENT_HARD_BLOCK" ]; then
      err "C -- DIVERGENCE" "$f reports $crit CRITICAL, up from $PREV_CRIT in
      $PREV_FILE, and does not stamp DIVERGENT_HARD_BLOCK.
      Rule 8: divergence is a HARD_BLOCK, not a reason for another pass. Rising
      CRITICALs mean the REPAIR step is injecting defects faster than review removes
      them; pass N+1 only finds the next wave. STOP and escalate. Usual cause: an
      artifact over its Rule 25(d) budget, too cross-referenced to edit safely."
    fi
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
    err "D -- TERMINAL" "the series ends at $LAST_FILE with $LAST_VERDICT.
      The gate is being asked to pass over an adversarial cycle whose own last
      artifact says the exit condition is not met. Either run another pass to a
      clean verdict, or -- if the residue is already clean -- stamp the verdict the
      residue supports. Do not pass the gate by overriding the field in prose." ;;
esac

if [ "$ERRORS" -gt 0 ]; then
  echo "FAIL: $ERRORS convergence violation(s)."
  exit 1
fi

echo "PASS: the cycle converged -- last pass stamps EXIT_CONDITION_MET, no divergent pass, every verdict adjudicable."
exit 0
