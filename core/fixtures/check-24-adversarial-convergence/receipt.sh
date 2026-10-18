#!/usr/bin/env bash
# check-24-adversarial-convergence/receipt.sh [<validator>] -- the backlog receipt for an arm-C divergence
# (prior-scope CRITICALs rose, nobody stamped DIVERGENT_HARD_BLOCK) resolved on the record. It drives
# the SHIPPED validator in a mktemp world; it reads no fixture file.
#
#   exit 0   the fix is present
#   exit 1   it is not
#   exit 9   the receipt cannot measure: no subject, or its world could not be built
#
# The subject is resolved from this file's tree (core/scripts/ in the distribution, scripts/ai-dlc/ in
# an installed tree), never from the caller's cwd; an argument names another copy, which is how the
# base revision and a mutant are scored against the same receipt.
#
# ONE world, three series, all three in one run:
#   verified   p1 1C, p2 2C prior 2 NOT_MET, a valid CUT_SCOPE record, p3 0C MET declaring it
#              -> --cycle-state CONVERGED/0 AND the gate exits 0. Base and a terminal-only fix both
#              re-latch the divergence here (DIVERGENT/3, gate 1): that is the deadlock.
#   terminal   p1, p2 and the record, no p3 -> --cycle-state RESOLVED/0, the verification pass is legal.
#   invalid    p3 declares a CUT_SCOPE record whose bytes GREW -> --cycle-state DIVERGENT/3. A fix that
#              acquits every arm-C pass, or deletes arm C, passes `verified` and fails here.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
SUBJ="${1:-}"
if [ -z "$SUBJ" ]; then
  for c in "$HERE/../../scripts/validate-adversarial-convergence.sh" \
           "$HERE/../../../scripts/ai-dlc/validate-adversarial-convergence.sh"; do
    [ -f "$c" ] && { SUBJ="$c"; break; }
  done
fi
[ -n "$SUBJ" ] && [ -f "$SUBJ" ] || { echo "receipt: no validate-adversarial-convergence.sh to score" >&2; exit 9; }

W="$(mktemp -d "${TMPDIR:-/tmp}/bl665-receipt-XXXXXX")" || exit 9

pass() { # $1 file $2 n $3 crit $4 prior $5 verdict $6 sha [$7 resolves_divergence]
  {
    printf '# Adversarial review -- pass %s\n\n<!-- SKILL_INVOCATION_PROVENANCE v1\n' "$2"
    printf 'skill: ai-dlc-adversary-review\nmode: subagent\nlead_role: research-requirements\n'
    printf 'invoked_at: 2026-07-12T%02d:00:00Z\ntool_use_id: toolu_receipt_pass%s\n' "$2" "$2"
    printf 'artifact: product-brief.md\nartifact_sha: %s\n' "$6"
    [ -n "${7:-}" ] && printf 'resolves_divergence: %s\n' "$7"
    printf 'findings: %s CRITICAL, 0 MAJOR, 1 MINOR\nfindings_critical: %s\n' "$3" "$3"
    printf 'findings_critical_prior_scope: %s\nfindings_major: 0\nfindings_minor: 1\n' "$4"
    printf 'verdict: %s\nSKILL_INVOCATION_PROVENANCE_END -->\n' "$5"
  } > "$1"
}
record() { # $1 file $2 bytes_before $3 bytes_after
  {
    printf '# Divergence resolution\n\n<!-- ADVERSARIAL_RESOLUTION v1\n'
    printf 'resolves: s1-adversarial-p2.md\nresolution: CUT_SCOPE\nadjudicated_by: operator\n'
    printf 'artifact: product-brief.md\nartifact_sha_before: bbb2\nartifact_sha_after: ccc3\n'
    printf 'artifact_bytes_before: %s\nartifact_bytes_after: %s\n' "$2" "$3"
    printf 'scope_delta: cut the unverifiable claim\n'
    printf 'operator_authorization: 2026-07-12T03:00:00Z | "Cut the claim and re-verify the artifact"\n'
    printf 'options_presented: 3\nrecommended_option: CUT_SCOPE\nADVERSARIAL_RESOLUTION_END -->\n'
  } > "$1"
}
for s in verified terminal invalid; do
  mkdir -p "$W/$s" || exit 9
  pass "$W/$s/s1-adversarial-p1.md" 1 1 1 EXIT_CONDITION_NOT_MET aaa1
  pass "$W/$s/s1-adversarial-p2.md" 2 2 2 EXIT_CONDITION_NOT_MET bbb2
done
record "$W/verified/s1-resolution-p2.md" 4200 4000
record "$W/terminal/s1-resolution-p2.md" 4200 4000
record "$W/invalid/s1-resolution-p2.md"  4000 4200
pass "$W/verified/s1-adversarial-p3.md" 3 0 0 EXIT_CONDITION_MET ccc3 s1-resolution-p2.md
pass "$W/invalid/s1-adversarial-p3.md"  3 0 0 EXIT_CONDITION_MET ccc3 s1-resolution-p2.md
printf '%s\n' '{"type":"user","timestamp":"2026-07-12T03:00:00Z","message":{"content":"Cut the claim and re-verify the artifact."}}' \
  > "$W/operator.jsonl" || exit 9

cs() { # $1 series -> "<STATE>/<rc>"
  local o r
  o="$(bash "$SUBJ" --series "$W/$1/s1-adversarial-p" --cycle-state --transcript "$W/operator.jsonl" --transcript-dir "$W" 2>/dev/null)"; r=$?
  printf '%s/%s' "${o%%	*}" "$r"
}
bash "$SUBJ" --series "$W/verified/s1-adversarial-p" --transcript "$W/operator.jsonl" --transcript-dir "$W" >/dev/null 2>&1
gate=$?
got="verified=$(cs verified) gate=$gate terminal=$(cs terminal) invalid=$(cs invalid)"
want="verified=CONVERGED/0 gate=0 terminal=RESOLVED/0 invalid=DIVERGENT/3"
# A world the subject cannot read at all answers nothing about the fix.
case "$got" in *"=/"*) echo "receipt: the subject emitted no state ($got)" >&2; exit 9 ;; esac
[ "$got" = "$want" ] && exit 0
echo "receipt: $got (want $want)" >&2
exit 1
