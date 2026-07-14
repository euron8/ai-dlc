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

# Order by the pass number embedded in the filename.
#
# THIS FUNCTION WAS THE BUG, AND IT FAILED EXACTLY WHERE IT MATTERED. It matched only
# `pass<N>` — but the reference consumer names its artifacts `...-p13.md`, so EVERY file
# in a 13-pass series fell to the `*)` arm, took key 999, and `sort -s` (stable) left them
# in the shell's glob order: 1 10 11 12 13 2 3 4 5 6 7 8 9. Lexicographic.
#
# Both order-dependent checks then read garbage:
#   C  compared p13 against p2 as if adjacent, inventing rises and missing the real ones.
#   D  read the LAST pass as p9 — not p13. Check D exists to make "the gate passed while
#      the last artifact said NOT met" impossible, and at >=10 passes it could do precisely
#      that, in either direction.
# It is dormant below ten passes and activates at ten — i.e. it breaks in the long-cycle
# case it exists to police, and nowhere else. That is why nobody saw it.
#
# The old comment claimed un-orderable files "are reported ... rather than silently folded
# into the chain." No such report existed. They were folded in. It does now.
order_key() { # -> zero-padded pass number, or empty if the name carries none
  local b tok
  b="$(basename "$1")"; b="${b%.md}"
  # LAST `pass<N>` / `p<N>` token in the name: `...-pass4-verification` -> 4, `...-p13` -> 13.
  tok="$(printf '%s' "$b" | grep -oE '(pass|p)[0-9]+' | tail -1)"
  tok="${tok//[!0-9]/}"
  [ -n "$tok" ] || return 0
  printf '%03d' "$tok" 2>/dev/null || return 0
}

UNORDERABLE=()
KEYED=()
for f in "${FILES[@]}"; do
  k="$(order_key "$f")"
  if [ -z "$k" ]; then UNORDERABLE+=("$f"); else KEYED+=("$k $f"); fi
done

# Two files claiming the same pass number cannot be chained: any order we pick is a guess,
# and C/D would silently adjudicate the guess. Say so instead.
DUPES="$(printf '%s\n' "${KEYED[@]:-}" | awk '{print $1}' | sort | uniq -d)"

SORTED=()
while IFS= read -r line; do
  [ -n "$line" ] && SORTED+=("${line#* }")
done < <(printf '%s\n' "${KEYED[@]:-}" | sort -k1,1n)

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

# --- ORDERING ---------------------------------------------------------------
# Report what could not be chained, rather than folding it in and adjudicating the fold.
for f in "${UNORDERABLE[@]:-}"; do
  [ -n "$f" ] || continue
  err "ORDER" "$f carries no pass number in its filename (expected \`pass<N>\` or \`p<N>\`).
      It cannot be placed in the series, and C/D are order-dependent: chaining it on a
      guess is how a 13-pass cycle got adjudicated in the order 1,10,11,12,13,2,3..."
done
if [ -n "$DUPES" ]; then
  err "ORDER" "two or more artifacts claim the same pass number ($(printf '%s' "$DUPES" | tr -d '0' | tr '\n' ' ')$(printf '%s' "$DUPES" | sed 's/^0*//' | tr '\n' ' ')).
      Any chaining is a guess. Give each pass a distinct number."
fi

PREV_CRIT=""
PREV_FILE=""
PREV_MAJOR=""
LAST_VERDICT=""
LAST_FILE=""
LAST_CRIT=""
LAST_MAJOR=""

# --- E. STALL (the plateau rung) --------------------------------------------
# Rule 8 had exactly two terminal states: CONVERGED (0 CRITICAL, 0 MAJOR) and DIVERGENT
# (CRITICALs rising). Everything else was "run another pass", unbounded. There was no cap
# and no plateau detector anywhere in core.
#
# S290's brief cycle sat at CRITICAL=0 / MAJOR=1 for passes 11, 12 and 13 -- thirteen
# passes, ~12 hours -- and NOTHING fired. It was not converging (MAJOR>0) and not diverging
# (CRITICALs at zero), so it fell through both rungs into "keep going". Worse, Check D's own
# advice for that shape was *"run another pass to a clean verdict"* -- which is the
# instruction that produced passes 11, 12 and 13.
#
# The shape is REPAIR-INDUCED, and that is what makes another pass futile:
#   p11  three of seven "DECIDES" sites are on the wrong pool  (brief claimed all seven correct)
#   p12  the repair's stated REASON is false                   ("the edit is right; the reason is wrong")
#   p13  a FOURTH wrong-pool site -- which falsifies the sentence p12 just wrote
# The artifact keeps asserting a universally-quantified claim nobody verified mechanically;
# each pass falsifies it with one more counterexample and the repair rewrites the prose.
# Another pass buys another counterexample. The remedy is not another pass.
#
# THRESHOLD, BACKTESTED (not chosen for elegance). Against every adversarial series the
# reference consumer has with severity data -- s289-rr, s289-teststrategy, s290-brief;
# six older series predate the v0.48.0 schema and carry no counts, so they can neither
# confirm nor deny:
#   K=2  fires on s290-brief at pass 13. No false fire: it never blocks a cycle that had
#        already stamped EXIT_CONDITION_MET.
#   K=3  fires NOWHERE in the entire corpus -- including the 13-pass loop it exists to
#        catch. A rung that has never fired is indistinguishable from no rung.
# So K=2: two consecutive passes that fail to REDUCE a nonzero MAJOR, at zero CRITICAL.
STALL_THRESHOLD=2
STALL_RUN=0
STALL_FROM=""

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

  # --- E. STALL accumulator -------------------------------------------------
  # A pass that holds a nonzero MAJOR at zero CRITICAL, and did not REDUCE it, is a pass
  # that bought nothing. Count the run; a decrease (or any CRITICAL, which is C's business)
  # resets it. Reset on unparseable counts too: an un-adjudicable pass proves nothing.
  if [ -n "$crit" ] && [ -n "$major" ] && [ "$crit" -eq 0 ] && [ "$major" -gt 0 ] \
     && [ -n "$PREV_MAJOR" ] && [ "$major" -ge "$PREV_MAJOR" ]; then
    STALL_RUN=$((STALL_RUN + 1))
    [ -n "$STALL_FROM" ] || STALL_FROM="$f"
  else
    STALL_RUN=0
    STALL_FROM=""
  fi

  if [ -n "$crit" ]; then PREV_CRIT="$crit"; PREV_FILE="$f"; fi
  if [ -n "$major" ]; then PREV_MAJOR="$major"; fi
  LAST_VERDICT="$verdict"
  LAST_FILE="$f"
  LAST_CRIT="$crit"
  LAST_MAJOR="$major"
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
    # E takes precedence over D's generic branch. D's advice for this shape is "run
    # another pass to a clean verdict" -- and on a repair-induced plateau that advice IS
    # the defect. Diagnose the stall and give the remedy that actually terminates.
    if [ -n "$LAST_CRIT" ] && [ -n "$LAST_MAJOR" ] && [ "$LAST_CRIT" -eq 0 ] \
       && [ "$LAST_MAJOR" -gt 0 ] && [ "$STALL_RUN" -ge "$STALL_THRESHOLD" ]; then
      err "E -- STALL" "the series ends at $LAST_FILE having held MAJOR at $LAST_MAJOR
      with ZERO CRITICAL across $((STALL_RUN + 1)) consecutive passes (from $STALL_FROM).
      The cycle is neither converging nor diverging -- it is STALLED, and no existing rung
      catches that: MAJOR>0 means not converged, CRITICAL=0 means not divergent, so the
      cycle falls through to 'run another pass' forever.
      ANOTHER PASS IS NOT THE REMEDY. A plateau at zero CRITICAL is repair-induced: each
      repair rewrites the prose around a claim nobody verified, and the next pass falsifies
      the rewrite with one more counterexample. Passes are buying counterexamples, not
      convergence.
      Do ONE of these, then re-run the cycle:
        (a) VERIFY THE DISPUTED FACT MECHANICALLY. If the artifact asserts a universal
            ('all seven sites are correct'), stop arguing it in prose -- enumerate it in
            code and paste the enumeration. A universal nobody checked is what the
            adversary keeps falsifying.
        (b) CUT THE CLAIM. If it cannot be verified cheaply, delete it. An unverifiable
            assertion is not load-bearing; it is the thing generating the MAJORs.
        (c) ESCALATE to the operator with the standing MAJOR and its cost. A HARD_BLOCK
            the operator adjudicates in one turn beats a cycle that never terminates."
    elif [ "$SCOPE_GREW" -gt 0 ]; then
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
