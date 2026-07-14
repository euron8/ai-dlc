#!/usr/bin/env bash
# Seed a CONSUMER-SHAPED tree for the Rule 8 stop-state hooks.
#
#   seed.sh <case>   -> prints the WORK dir
#
# "Consumer-shaped" is load-bearing and the old seed was not. It wrote ONE pass file and
# no validator, so it could not exercise a series, an ordering, or a shell-out -- it could
# only exercise an awk scrape, which is precisely the thing v0.59.0 deleted. A fixture that
# can only test the implementation it was written against is not a fixture; it is a mirror.
#
# The real layout, which install.sh produces:
#   <root>/_bmad-output/pipeline-snapshot.md          the hooks' "is a pipeline running" gate
#   <root>/_bmad-output/planning-artifacts/*.md       the pass series
#   <root>/scripts/validate-adversarial-convergence.sh  core/scripts/ -> consumer scripts/
set -eu

CASE="${1:?case}"
HERE="$(cd "$(dirname "$0")" && pwd)"

VALIDATOR=""
for c in "$HERE/../../scripts/validate-adversarial-convergence.sh" \
         "$HERE/../../../scripts/validate-adversarial-convergence.sh" \
         "$HERE/../../core/scripts/validate-adversarial-convergence.sh"; do
  [ -f "$c" ] && VALIDATOR="$c" && break
done
[ -n "$VALIDATOR" ] || { echo "FIXTURE ERROR: cannot locate the validator" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/divergence-XXXXXX")"
ART="$WORK/_bmad-output/planning-artifacts"
mkdir -p "$ART" "$WORK/scripts"
touch "$WORK/_bmad-output/pipeline-snapshot.md"
cp "$VALIDATOR" "$WORK/scripts/validate-adversarial-convergence.sh"

# $1 n  $2 crit  $3 prior  $4 major  $5 verdict  $6 sha  $7 resolves(optional)
pass() {
  local n="$1" crit="$2" prior="$3" major="$4" v="$5" sha="$6" res="${7:-}"
  {
    printf '# Adversarial pass %s\n\n' "$n"
    printf '<!-- SKILL_INVOCATION_PROVENANCE v1\n'
    printf 'skill: ai-dlc-adversary-review\n'
    printf 'mode: subagent\n'
    printf 'invoked_at: %s\n' "$(printf '2026-07-12T%02d:00:00Z' "$n")"
    printf 'artifact: product-brief.md\n'
    printf 'artifact_sha: %s\n' "$sha"
    [ -n "$res" ] && printf 'resolves_divergence: %s\n' "$res"
    printf 'findings_critical: %s\n' "$crit"
    printf 'findings_critical_prior_scope: %s\n' "$prior"
    printf 'findings_major: %s\n' "$major"
    printf 'findings_minor: 2\n'
    printf 'verdict: %s\n' "$v"
    printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'
  } > "$ART/s1-brief-adversarial-p${n}.md"
}

# $1 resolves-basename  $2 kind  $3 sha_before  $4 sha_after  $5 bytes_before  $6 bytes_after
record() {
  {
    printf '# Divergence resolution — %s\n\n' "$2"
    printf '<!-- ADVERSARIAL_RESOLUTION v1\n'
    printf 'resolves: %s\n' "$1"
    printf 'resolution: %s\n' "$2"
    printf 'adjudicated_by: operator\n'
    printf 'artifact: product-brief.md\n'
    printf 'artifact_sha_before: %s\n' "$3"
    printf 'artifact_sha_after: %s\n' "$4"
    printf 'artifact_bytes_before: %s\n' "$5"
    printf 'artifact_bytes_after: %s\n' "$6"
    printf 'scope_delta: reverted the p1->p2 repair wholesale\n'
    printf 'ADVERSARIAL_RESOLUTION_END -->\n'
  } > "$ART/s1-brief-resolution-p2.md"
}

case "$CASE" in
  # The reference consumer's parked state: the terminal pass hard-blocks, unadjudicated.
  divergent)
    pass 1 2 2 1 EXIT_CONDITION_NOT_MET aaa1
    pass 2 3 3 1 DIVERGENT_HARD_BLOCK   bbb2
    ;;

  # THE RESUME. Same bytes, same series, ONE new file -- and the dispatch is legal again.
  divergent-resolved)
    pass 1 2 2 1 EXIT_CONDITION_NOT_MET aaa1
    pass 2 3 3 1 DIVERGENT_HARD_BLOCK   bbb2
    record s1-brief-adversarial-p2.md REVERT_REPAIR bbb2 aaa1 4200 4000
    ;;

  # A nonzero MAJOR held at zero CRITICAL. Neither converging nor diverging.
  stalled)
    pass 1 2 1 2 EXIT_CONDITION_NOT_MET aaa1
    pass 2 0 0 1 EXIT_CONDITION_NOT_MET bbb2
    pass 3 0 0 1 EXIT_CONDITION_NOT_MET ccc3
    pass 4 0 0 1 EXIT_CONDITION_NOT_MET ddd4
    ;;

  # THE DECOYS. A guard that fires on a cycle that is working gets ripped out.
  converged)
    pass 1 2 2 1 EXIT_CONDITION_NOT_MET aaa1
    pass 2 0 0 0 EXIT_CONDITION_MET     bbb2
    ;;
  in-progress)
    pass 1 3 3 2 EXIT_CONDITION_NOT_MET aaa1
    pass 2 1 1 1 EXIT_CONDITION_NOT_MET bbb2
    ;;

  # A cycle that diverged, was RESOLVED, and converged. Then someone touches the old
  # divergent pass -- a re-read, an editor, a `git checkout`. Under `ls -t` it becomes the
  # "newest" file and the old hook re-raised the hard block on a cycle that had finished.
  resolved-then-touched)
    pass 1 2 2 1 EXIT_CONDITION_NOT_MET aaa1
    pass 2 3 3 1 DIVERGENT_HARD_BLOCK   bbb2
    record s1-brief-adversarial-p2.md REVERT_REPAIR bbb2 aaa1 4200 4000
    pass 3 0 0 0 EXIT_CONDITION_MET     aaa1 s1-brief-resolution-p2.md
    sleep 1
    touch "$ART/s1-brief-adversarial-p2.md"
    ;;

  *) echo "FIXTURE ERROR: unknown case '$CASE'" >&2; exit 2 ;;
esac

printf '%s\n' "$WORK"
