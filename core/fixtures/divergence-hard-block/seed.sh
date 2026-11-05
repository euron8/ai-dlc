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
#   <root>/_bmad-output/planning-artifacts/s<N>/*.md  the pass series, under the sprint slot
#   <root>/_bmad-output/implementation-artifacts/sprint-status.yaml  the DECLARED sprint
#   <root>/scripts/ai-dlc/validate-adversarial-convergence.sh  core/scripts/ -> consumer scripts/
#   <root>/scripts/ai-dlc/sprint-status.sh + <root>/.claude/schemas/sprint-status.json
#
# THE DECLARED SPRINT IS PART OF THE LAYOUT NOW, and leaving it out is not a smaller seed —
# it is a different test. Both hooks scope the live-series glob to `s<sprint-id>/`, so a tree
# with no envelope resolves no sprint, logs ADVERSARIAL_STATE_UNADJUDICABLE and arms nothing.
# That path has its own arm in run.sh; every arm here needs the sprint to actually resolve.
set -eu

CASE="${1:?case}"
HERE="$(cd "$(dirname "$0")" && pwd)"

pick_one() { for c in "$@"; do [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
VALIDATOR="$(pick_one "$HERE/../../scripts/validate-adversarial-convergence.sh" \
                      "$HERE/../../../scripts/ai-dlc/validate-adversarial-convergence.sh" \
                      "$HERE/../../core/scripts/validate-adversarial-convergence.sh")"
[ -n "$VALIDATOR" ] || { echo "FIXTURE ERROR: cannot locate the validator" >&2; exit 2; }
SPRINT_STATUS="$(pick_one "$HERE/../../scripts/sprint-status.sh" \
                          "$HERE/../../../scripts/ai-dlc/sprint-status.sh" \
                          "$HERE/../../core/scripts/sprint-status.sh")"
[ -n "$SPRINT_STATUS" ] || { echo "FIXTURE ERROR: cannot locate sprint-status.sh" >&2; exit 2; }
STATUS_SCHEMA="$(pick_one "$HERE/../../schemas/sprint-status.json" \
                          "$HERE/../../../.claude/schemas/sprint-status.json" \
                          "$HERE/../../core/schemas/sprint-status.json")"
[ -n "$STATUS_SCHEMA" ] || { echo "FIXTURE ERROR: cannot locate sprint-status.json" >&2; exit 2; }

# NOT 1. `sprint-id` returns 1 for a greenfield tree (route.md Step 6 rule 2), so a
# fixture seeded at sprint 1 cannot tell a RESOLVED sprint from the default -- and the
# no-envelope arm in run.sh would land on the same directory either way and prove nothing.
SPRINT=7
WORK="$(mktemp -d "${TMPDIR:-/tmp}/divergence-XXXXXX")"
ART="$WORK/_bmad-output/planning-artifacts/s${SPRINT}"
mkdir -p "$ART" "$WORK/scripts/ai-dlc" "$WORK/.claude/schemas"
touch "$WORK/_bmad-output/pipeline-snapshot.md"
cp "$VALIDATOR" "$WORK/scripts/ai-dlc/validate-adversarial-convergence.sh"
cp "$SPRINT_STATUS" "$WORK/scripts/ai-dlc/sprint-status.sh"
cp "$STATUS_SCHEMA" "$WORK/.claude/schemas/sprint-status.json"
bash "$WORK/scripts/ai-dlc/sprint-status.sh" roll --sprint "$SPRINT" --intensity full --root "$WORK" >/dev/null 2>&1 \
  || { echo "FIXTURE ERROR: sprint-status.sh roll failed; no declared sprint to scope on" >&2; exit 2; }
# The seed asserts its own precondition. Without this the hooks below would resolve no
# sprint, adjudicate nothing, and every ALLOW assertion in run.sh would pass for the wrong
# reason -- a fixture green because its subject never ran.
[ "$(cd "$WORK" && bash scripts/ai-dlc/sprint-status.sh sprint-id 2>/dev/null)" = "$SPRINT" ] \
  || { echo "FIXTURE ERROR: sprint-id does not resolve to $SPRINT in the seeded tree" >&2; exit 2; }

# $1 n  $2 crit  $3 prior  $4 major  $5 verdict  $6 sha  $7 resolves(optional)
# $8 shard_tool_use_ids (optional): a merged SHARDED pass's dispatch ids, which arm N reads
# PASS_DAY (optional, default 12): the July day every invoked_at falls on; the era-merge worlds move it.
pass() {
  local n="$1" crit="$2" prior="$3" major="$4" v="$5" sha="$6" res="${7:-}" ids="${8:-}"
  {
    printf '# Adversarial pass %s\n\n' "$n"
    printf '<!-- SKILL_INVOCATION_PROVENANCE v1\n'
    printf 'skill: ai-dlc-adversary-review\n'
    printf 'mode: subagent\n'
    printf 'invoked_at: %s\n' "$(printf '2026-07-%02dT%02d:00:00Z' "${PASS_DAY:-12}" "$n")"
    printf 'artifact: product-brief.md\n'
    printf 'artifact_sha: %s\n' "$sha"
    [ -n "$ids" ] && printf 'shard_tool_use_ids: %s\n' "$ids"
    [ -n "$res" ] && printf 'resolves_divergence: %s\n' "$res"
    printf 'findings_critical: %s\n' "$crit"
    printf 'findings_critical_prior_scope: %s\n' "$prior"
    printf 'findings_major: %s\n' "$major"
    printf 'findings_minor: 2\n'
    printf 'verdict: %s\n' "$v"
    printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'
  } > "$ART/brief-adversarial-p${n}.md"
}

# $1 resolves-basename  $2 kind  $3 sha_before  $4 sha_after  $5 bytes_before  $6 bytes_after
# $7 the pass number the record resolves (default 2, which every case but `ceiling` uses)
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
    printf 'operator_authorization: 2026-07-12T03:00:00Z | "revert the p1 to p2 repair wholesale"\n'
    printf 'ADVERSARIAL_RESOLUTION_END -->\n'
  } > "$ART/brief-resolution-p${7:-2}.md"
}

# THE CAP AND THE ERA (BL-911). The cap (arm M, `--cycle-state` CAPPED) and the derived width (arm N)
# bind only a series the ERA binds: the installed rulebook `.claude/skills/ai-dlc/steps/_gate-procedures.md`
# above the series carries the validator's ERA_TOKEN, and the series' FIRST invoked_at is at or after the
# OLDEST commit that added the token to that file. So the cap cases install the REAL rulebook, and every
# token world is a git repository whose commits carry FIXED literal dates (BL-868: no `date`, no clock):
#   rulebook notoken   the real file with the token sentence's opening reworded (count 0, asserted)
#   rulebook token     the real file (count 1, asserted)
# The engine's merge and its siblings are copied beside the validator: arm N's self-probe re-derives through
# the merge, and a gate run without it refuses with "no verdict".
RULEBOOK="$(pick_one "$HERE/../../skills/ai-dlc/steps/_gate-procedures.md" \
                     "$HERE/../../../.claude/skills/ai-dlc/steps/_gate-procedures.md" \
                     "$HERE/../../core/skills/ai-dlc/steps/_gate-procedures.md")"
ERA_TOKEN_LINE="$(grep -E "^ERA_TOKEN='[^']+'\$" "$VALIDATOR")" || ERA_TOKEN_LINE=""
ERA_TOKEN="${ERA_TOKEN_LINE#ERA_TOKEN=\'}"; ERA_TOKEN="${ERA_TOKEN%\'}"
cap_rulebook() { # <token|notoken>
  local rb="$WORK/.claude/skills/ai-dlc/steps/_gate-procedures.md" n
  [ -n "$RULEBOOK" ] && [ -n "$ERA_TOKEN" ] || { echo "FIXTURE ERROR: the rulebook or the validator's ERA_TOKEN line is not found" >&2; exit 2; }
  mkdir -p "$(dirname "$rb")"
  if [ "$1" = token ]; then cp "$RULEBOOK" "$rb"
  else T="$ERA_TOKEN" perl -pe 's/\Q$ENV{T}\E/A p3 that fails to stamp/g' "$RULEBOOK" > "$rb"; fi
  n="$(grep -cF -- "$ERA_TOKEN" "$rb")" || n=0
  case "$1:$n" in token:1|notoken:0) ;; *) echo "FIXTURE ERROR: the $1 rulebook carries the era token $n time(s)" >&2; exit 2 ;; esac
}
cap_siblings() {
  local s d; d="$(dirname "$VALIDATOR")"
  for s in merge-adversarial-shards.sh partition-document.sh partition-subject.sh validate-provenance-block.sh \
           validate-artifact-budget.sh validate-steering-budget.sh content-seal.sh; do
    [ -f "$d/$s" ] || { echo "FIXTURE ERROR: $s is not beside the validator" >&2; exit 2; }
    cp "$d/$s" "$WORK/scripts/ai-dlc/$s"
  done
}
cap_git() { # <iso date> <message> -- commit the scripts and the installed rulebook at that FIXED date
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
    g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$WORK" -c user.name=f -c user.email=f@example.invalid \
          -c core.hooksPath=/dev/null -c commit.gpgsign=false "$@"; }
    [ -d "$WORK/.git" ] || g init -q . || exit 1
    g add scripts .claude || exit 1
    GIT_COMMITTER_DATE="$1" GIT_AUTHOR_DATE="$1" g commit -q -m "$2" || exit 1 ) >/dev/null 2>&1 \
    || { echo "FIXTURE ERROR: git could not commit the $2 world" >&2; exit 2; }
}
# The capped series: p3 does not stamp EXIT_CONDITION_MET. CRITICALs fall 2 -> 1 -> 1 and MAJOR stays at 1
# (under the exit ceiling), so neither arm C (divergence) nor arm E (stall) claims the stop.
cap_series() {
  pass 1 2 2 1 EXIT_CONDITION_NOT_MET aaa1
  pass 2 1 1 1 EXIT_CONDITION_NOT_MET bbb2
  pass 3 1 1 1 EXIT_CONDITION_NOT_MET ccc3
}
cap_record() { # <the pass it resolves>
  {
    printf '# Cap resolution\n\n<!-- ADVERSARIAL_RESOLUTION v1\n'
    printf 'resolves: %s\nresolution: REVERT_REPAIR\nadjudicated_by: operator\nartifact: product-brief.md\n' "$1"
    printf 'artifact_sha_before: ccc3\nartifact_sha_after: aaa1\nartifact_bytes_before: 4200\nartifact_bytes_after: 4000\n'
    printf 'scope_delta: reverted the p1 to p3 repairs wholesale\n'
    printf 'operator_authorization: 2026-07-12T03:30:00Z | "revert the repairs back to the p1 text"\n'
    printf 'options_presented: 3\nrecommended_option: REVERT_REPAIR\n'
    printf 'ADVERSARIAL_RESOLUTION_END -->\n'
  } > "$ART/brief-resolution-p3.md"
  # The harness transcript the GATE verifies the citation against (F6): one genuine operator turn at the
  # cited time, after p3 opened (03:00), carrying the quoted words. Literal timestamps (BL-868).
  {
    printf '{"type":"user","timestamp":"2026-07-12T01:00:00Z","message":{"content":"/ai-dlc Sprint 7. Kick off the cycle."}}\n'
    printf '{"type":"assistant","timestamp":"2026-07-12T03:10:00Z","message":{"content":[{"type":"text","text":"p3 is CAPPED; pausing for your adjudication."}]}}\n'
    printf '{"type":"user","timestamp":"2026-07-12T03:30:00Z","message":{"content":"Revert the repairs back to the p1 text, then verify."}}\n'
  } > "$WORK/operator-transcript.jsonl"
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
    record brief-adversarial-p2.md REVERT_REPAIR bbb2 aaa1 4200 4000
    ;;

  # A blocking MAJOR count above MAJOR_EXIT_CEILING, at no more than CRITICAL_EXIT_CEILING
  # CRITICAL, not reduced across more than STALL_THRESHOLD consecutive passes.
  # THE PLATEAU IS PINNED ABOVE MAJOR_EXIT_CEILING, AND THE NUMBER IS LOAD-BEARING. The exit
  # criteria are 0 CRITICAL and at most 3 blocking MAJOR, so a plateau at 1 is a MET exit
  # condition rather than a stall -- arm B's business, not arm E's. Seeded at 1 this case would
  # assert the opposite of the shipped criteria and the hook would correctly ALLOW the dispatch.
  stalled)
    pass 1 2 1 5 EXIT_CONDITION_NOT_MET aaa1
    pass 2 0 0 4 EXIT_CONDITION_NOT_MET bbb2
    pass 3 0 0 4 EXIT_CONDITION_NOT_MET ccc3
    pass 4 0 0 4 EXIT_CONDITION_NOT_MET ddd4
    ;;

  # THE FOURTH rc-3 STATE. The series takes the sanctioned resolution exit TWICE, both times
  # with CHANGE_APPROACH -- a kind no byte-level predicate can check -- and has not converged,
  # so arm I reports CEILING. Every record is valid and every divergence is resolved, which is
  # what keeps arms C and E from claiming the stop: only the resolution COUNT separates it.
  # Same series shape as check-24's `ceiling-unanchored`.
  ceiling)
    pass 1 2 2 1 EXIT_CONDITION_NOT_MET aaa1
    pass 2 3 3 1 DIVERGENT_HARD_BLOCK   bbb2
    record brief-adversarial-p2.md CHANGE_APPROACH bbb2 ccc3 4000 4100 2
    pass 3 1 1 1 EXIT_CONDITION_NOT_MET ccc3 brief-resolution-p2.md
    pass 4 2 2 1 DIVERGENT_HARD_BLOCK   ddd4
    record brief-adversarial-p4.md CHANGE_APPROACH ddd4 eee5 4100 4200 4
    pass 5 1 1 1 EXIT_CONDITION_NOT_MET eee5 brief-resolution-p4.md
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
    record brief-adversarial-p2.md REVERT_REPAIR bbb2 aaa1 4200 4000
    pass 3 0 0 0 EXIT_CONDITION_MET     aaa1 brief-resolution-p2.md
    # The "touch" is an explicit, NEWER stamp than every other series file, never a `sleep 1` before
    # a plain touch (BL-868): the order the arm needs is written, not waited for. `-c` never creates
    # a file, and the head of `ls -t` (the hooks' own series pick) is asserted to be p2.
    for _f in "$ART"/*.md; do touch -c -t 202607120000.00 "$_f"; done
    touch -c -t 202607120100.00 "$ART/brief-adversarial-p2.md"
    [ "$(ls -t "$ART"/*adversarial*p*.md | head -1)" = "$ART/brief-adversarial-p2.md" ] \
      || { echo "FIXTURE ERROR: the touched divergent pass p2 is not the newest series file" >&2; exit 2; }
    ;;

  # ---- BL-911: the cap (arm M) and the era. Every token world commits its rulebook at a FIXED date before
  # the series opens (2026-07-12T01:00:00Z), so the era binds it; cap-notoken carries no token and no git.
  cap-notoken)
    cap_rulebook notoken; cap_siblings; cap_series ;;
  cap-bound)
    cap_rulebook token; cap_siblings; cap_git 2026-07-01T00:00:00Z engine-and-rulebook; cap_series ;;
  # A series that STARTS at p2 (s321 architecture's shape): p3 is its SECOND pass. The cap keys on the pass
  # NUMBER, so this caps; a cap keyed on position, or at p4, reads CONTINUE here.
  cap-from-p2)
    cap_rulebook token; cap_siblings; cap_git 2026-07-01T00:00:00Z engine-and-rulebook
    pass 2 1 1 1 EXIT_CONDITION_NOT_MET bbb2
    pass 3 1 1 1 EXIT_CONDITION_NOT_MET ccc3 ;;
  # p1, p2 unconverged in a bound tree: no pass is p3, nothing caps.
  cap-inprog)
    cap_rulebook token; cap_siblings; cap_git 2026-07-01T00:00:00Z engine-and-rulebook
    pass 1 2 2 1 EXIT_CONDITION_NOT_MET aaa1
    pass 2 1 1 1 EXIT_CONDITION_NOT_MET bbb2 ;;
  # A p4 WALKED past the capped p3: with no record, with a valid one, with one resolving a pass that is not there.
  cap-norecord|cap-record|cap-badrecord)
    cap_rulebook token; cap_siblings; cap_git 2026-07-01T00:00:00Z engine-and-rulebook; cap_series
    case "$CASE" in
      cap-norecord)  pass 4 0 0 0 EXIT_CONDITION_MET aaa1 ;;
      cap-record)    cap_record brief-adversarial-p3.md; pass 4 0 0 0 EXIT_CONDITION_MET aaa1 brief-resolution-p3.md ;;
      cap-badrecord) cap_record brief-adversarial-p9.md; pass 4 0 0 0 EXIT_CONDITION_MET aaa1 brief-resolution-p3.md ;;
    esac ;;
  # THE ERA, dated by the commit that put the token in the INSTALLED rulebook, never by the engine's install.
  # Both worlds commit the engine and a token-free rulebook at 2026-07-01, then the token: era-between at
  # 2026-07-20 (AFTER the series opened, 07-12: legacy), era-bound at 2026-07-05 (before it: bound). p2 is a
  # merged SHARDED pass with no shard_set_derived_from:, the field arm N requires of a bound series.
  era-between|era-bound)
    cap_rulebook notoken; cap_siblings; cap_git 2026-07-01T00:00:00Z engine-update
    cap_rulebook token
    if [ "$CASE" = era-between ]; then cap_git 2026-07-20T00:00:00Z rulebook-merge; else cap_git 2026-07-05T00:00:00Z rulebook-merge; fi
    pass 1 2 2 1 EXIT_CONDITION_NOT_MET aaa1
    pass 2 1 1 1 EXIT_CONDITION_NOT_MET bbb2 "" "1=toolu_01EraShardOne 2=toolu_01EraShardTwo cross=toolu_01EraShardCross"
    pass 3 1 1 1 EXIT_CONDITION_NOT_MET ccc3 ;;
  # THE ERA BY MERGE TOPOLOGY. The token is committed on main at 07-05 and reaches the sprint branch only by a
  # --no-ff merge at 07-20, so the token is dated by the merge, its first-parent arrival on this branch. The
  # series opens 07-10 (era-merge-before: legacy, the branch did not carry the token yet) or 07-21
  # (era-merge-after: bound). A plain `git log -S` dates it by the 07-05 commit and binds both.
  era-merge-before|era-merge-after)
    cap_rulebook notoken; cap_siblings
    ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
      g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$WORK" -c user.name=f -c user.email=f@example.invalid \
            -c core.hooksPath=/dev/null -c commit.gpgsign=false "$@"; }
      at() { GIT_COMMITTER_DATE="$1" GIT_AUTHOR_DATE="$1" g "${@:2}"; }
      g init -q . && g checkout -q -b main && g add scripts .claude && at 2026-07-01T00:00:00Z commit -q -m engine-update \
        && g checkout -q -b sprint || exit 1
      g checkout -q main && cap_rulebook token && g add .claude && at 2026-07-05T00:00:00Z commit -q -m rulebook-reconcile || exit 1
      g checkout -q sprint && printf 'sprint work\n' > "$WORK/sprint-note" && g add sprint-note \
        && at 2026-07-08T00:00:00Z commit -q -m sprint-work || exit 1
      at 2026-07-20T00:00:00Z merge -q --no-ff -m "merge main into sprint" main || exit 1
      # The topology the arm needs, asserted: the token on this branch, its commit reachable but OFF the first
      # parent chain (a fast-forward would put it there and both era implementations would agree).
      t="$(g log --format=%H -S"$ERA_TOKEN" main -- .claude/skills/ai-dlc/steps/_gate-procedures.md)" && [ -n "$t" ] || exit 1
      g merge-base --is-ancestor "$t" HEAD || exit 1
      ! g rev-list --first-parent HEAD | grep -qx "$t" || exit 1
      [ "$(g rev-parse --abbrev-ref HEAD)" = sprint ] || exit 1 ) >/dev/null 2>&1 \
      || { echo "FIXTURE ERROR: the era-merge topology (token on main 07-05, --no-ff merged into sprint 07-20) did not build" >&2; exit 2; }
    [ "$(grep -cF -- "$ERA_TOKEN" "$WORK/.claude/skills/ai-dlc/steps/_gate-procedures.md")" = 1 ] \
      || { echo "FIXTURE ERROR: the merged rulebook does not carry the era token once" >&2; exit 2; }
    if [ "$CASE" = era-merge-before ]; then PASS_DAY=10; else PASS_DAY=21; fi
    pass 1 2 2 1 EXIT_CONDITION_NOT_MET aaa1
    pass 2 1 1 1 EXIT_CONDITION_NOT_MET bbb2 "" "1=toolu_01EraShardOne 2=toolu_01EraShardTwo cross=toolu_01EraShardCross"
    pass 3 1 1 1 EXIT_CONDITION_NOT_MET ccc3 ;;

  *) echo "FIXTURE ERROR: unknown case '$CASE'" >&2; exit 2 ;;
esac

printf '%s\n' "$WORK"
