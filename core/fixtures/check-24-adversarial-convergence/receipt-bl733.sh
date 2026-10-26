#!/usr/bin/env bash
# check-24-adversarial-convergence/receipt-bl733.sh [<validator>] -- the backlog receipt for BL-733: a
# story split after a correctly sharded stories elicitation owes ONLY the delta -- the stories no
# ordinal shard names and the cross groups holding one of them -- elicited into
# s<N>/shards/stories-elicitation-delta-k<K>/, and arm L judges it by NAME. Drives the SHIPPED
# validator in a mktemp world and reads no fixture file.
#
#   exit 0   the fix is present        exit 1   it is not        exit 9   the receipt cannot measure
#
# The reference consumer's s319 shape: a base elicited complete at K=19, then the 8th story split in
# two (K=20), so every ordinal after the split point renumbers. Owed by name: story-08a, story-08b and
# ONE cross.md, or (accepted) cross groups {1,4,5} of `--cross-groups 20`; a diff of the two index
# lists answers {3,5,6}.
#   nodelta    base only                                   FAIL, remedy names the delta, no cross-3
#   full       base + the exact delta, one cross.md        PASS, exit 0
#   fullg      base + the delta, cross-1/4/5 per group     PASS, exit 0 (the per-group names accepted)
#   one        a base whose cross part is one cross.md + the delta   PASS, exit 0
#   nocross    the delta's ordinals, no cross shard        FAIL, names cross.md
#   miss       the delta without story-08b.md              FAIL, names story-08b.md
#   crossonly  the delta's cross shard, no ordinal shard   FAIL: a cross voice acquits no story
#   xnamed     nodelta whose base cross shards name TODAY's 20 stories (graph's live s319 cross
#              shards do): FAIL owing story-08a/08b -- a cross `<name>=` entry never acquits an ordinal
#   voice      base = ONE `shard: 1/1` voice naming every story by dir form, + the delta   FAIL
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR

HERE="$(cd "$(dirname "$0")" && pwd)"
SUBJ="${1:-}"
if [ -z "$SUBJ" ]; then
  for c in "$HERE/../../scripts/validate-adversarial-convergence.sh" \
           "$HERE/../../../scripts/ai-dlc/validate-adversarial-convergence.sh"; do
    [ -f "$c" ] && { SUBJ="$c"; break; }
  done
fi
[ -n "$SUBJ" ] && [ -f "$SUBJ" ] || { echo "receipt: no validate-adversarial-convergence.sh to score" >&2; exit 9; }
SD="$(cd "$(dirname "$SUBJ")" && pwd)"
[ -f "$SD/merge-adversarial-shards.sh" ] && [ -f "$SD/partition-document.sh" ] \
  || { echo "receipt: the merge or the partitioner is not beside $SUBJ" >&2; exit 9; }
command -v git >/dev/null 2>&1 || { echo "receipt: git is not on PATH" >&2; exit 9; }

B="$(mktemp -d "${TMPDIR:-/tmp}/bl733-receipt-XXXXXX")" || exit 9
B="$(cd "$B" && pwd -P)"
lg() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$1" -c user.name=r -c user.email=r@example.invalid \
       -c core.hooksPath=/dev/null -c commit.gpgsign=false "${@:2}"; }
BASE=""; NOW=""
for i in $(seq 1 19); do
  n="story-$(printf %02d "$i")"; BASE="$BASE $n"
  if [ "$i" -eq 8 ]; then NOW="$NOW story-08a story-08b"; else NOW="$NOW $n"; fi
done
world() {
  local w="$B/$1" n
  mkdir -p "$w/.claude" "$w/s9/stories" || return 1
  for n in $NOW; do printf '# %s\n\nAs the operator, I want %s.\n' "$n" "$n" > "$w/s9/stories/$n.md"; done
  printf 'sprint: 9\nvalidation_intensity: full\n' > "$w/s9/sprint-status.yaml"
  { printf '# stories -- adversarial pass 1\n\n<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: ai-dlc-adversary-review\n'
    printf 'invoked_at: 2026-10-07T00:00:00Z\ntool_use_id: toolu_receipt_l1\nshard_tool_use_ids: 1=toolu_receipt_l1a\n'
    printf 'mode: subagent\nlead_role: architect\nartifact: stories/\nfindings_critical: 0\nfindings_critical_prior_scope: 0\n'
    printf 'findings_major: 0\nfindings_major_underived: 0\nfindings_minor: 0\nverdict: EXIT_CONDITION_MET\nSKILL_INVOCATION_PROVENANCE_END -->\n'
  } > "$w/s9/stories-adversarial-p1.md"
}
ord() { # file story K ordinal
  printf '<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: bmad-advanced-elicitation\ninvoked_at: 2026-10-06T00:00:00Z\ntool_use_id: NOT_ACCESSIBLE\nmode: subagent\nlead_role: stories.md\nartifact: _bmad-output/planning-artifacts/s9/stories/%s.md\nartifact_sha: %064d\nfindings_critical: 0\nfindings_major: 0\nfindings_minor: 0\nSKILL_INVOCATION_PROVENANCE_END -->\n\n# Stories elicitation\n\nshard: %s/%s %s\n\nFindings: 0 critical, 0 major, 0 minor.\n' \
    "$2" 1 "$4" "$3" "$2" > "$1"
}
crs() { # file shard-line names...
  local f="$1" sl="$2" s="" n; shift 2
  for n in "$@"; do s="$s $n=$(printf %064d 2)"; done
  printf '<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: bmad-advanced-elicitation\ninvoked_at: 2026-10-06T00:00:00Z\ntool_use_id: NOT_ACCESSIBLE\nmode: subagent\nlead_role: stories.md\nartifact: _bmad-output/planning-artifacts/s9/stories/\nartifact_sha:%s\nfindings_critical: 0\nfindings_major: 0\nfindings_minor: 0\nSKILL_INVOCATION_PROVENANCE_END -->\n\n# Stories elicitation, cross shard\n\n%s\n\nFindings: 0 critical, 0 major, 0 minor.\n' \
    "$s" "$sl" > "$f"
}
base() { # world [xnamed: the cross shards name TODAY's stories, as graph's live s319 cross shards do | one: ONE cross.md]
  local d="$B/$1/s9/shards/stories-elicitation" i=0 n g names="$BASE"
  mkdir -p "$d" || return 1
  [ "${2:-}" = xnamed ] && names="$NOW"
  for n in $BASE; do i=$((i + 1)); ord "$d/$(printf %02d "$i").md" "$n" 19 "$(printf %02d "$i")"; done
  if [ "${2:-}" = one ]; then crs "$d/cross.md" "shard: cross/19 cross" $names; return; fi
  for g in 1 2 3 4 5 6; do crs "$d/cross-$g.md" "shard: cross/19 cross-$g" $names; done
}
delta() { # world [skip-story] [no-ordinals | groups: cross-1/4/5 | nocross]
  local d="$B/$1/s9/shards/stories-elicitation-delta-k20" n g
  mkdir -p "$d" || return 1
  if [ "${3:-}" != no-ordinals ]; then
    for n in story-08a story-08b; do [ "$n" = "${2:-}" ] || ord "$d/$n.md" "$n" 20 "$n"; done
  fi
  case "${3:-}" in
    nocross) ;;
    groups) for g in 1 4 5; do crs "$d/cross-$g.md" "shard: cross/20 cross-$g" $NOW; done ;;
    *) crs "$d/cross.md" "shard: cross/20 cross" $NOW ;;
  esac
}
stamp() {
  local w="$B/$1"
  printf 'version: 0.781.0\n' > "$w/.claude/.ai-dlc-version"
  ( lg "$w" init -q . && lg "$w" add -A \
      && GIT_COMMITTER_DATE=2026-10-01T00:00:00Z GIT_AUTHOR_DATE=2026-10-01T00:00:00Z lg "$w" commit -q -m stamp-0.781.0 || exit 1
    printf 'version: 0.782.0\n' > "$w/.claude/.ai-dlc-version" && lg "$w" add -A \
      && GIT_COMMITTER_DATE=2026-10-05T00:00:00Z GIT_AUTHOR_DATE=2026-10-05T00:00:00Z lg "$w" commit -q -m stamp-0.782.0 ) >/dev/null 2>&1
}
{ world nodelta && base nodelta && stamp nodelta \
  && world full && base full && delta full && stamp full \
  && world fullg && base fullg && delta fullg "" groups && stamp fullg \
  && world one && base one one && delta one && stamp one \
  && world nocross && base nocross && delta nocross "" nocross && stamp nocross \
  && world miss && base miss && delta miss story-08b && stamp miss \
  && world crossonly && base crossonly && delta crossonly "" no-ordinals && stamp crossonly \
  && world xnamed && base xnamed xnamed && stamp xnamed \
  && world voice && mkdir -p "$B/voice/s9/shards/stories-elicitation" \
  && crs "$B/voice/s9/shards/stories-elicitation/01.md" "shard: 1/1 stories" $NOW && delta voice && stamp voice; } \
  || { echo "receipt: a world could not be built under $B" >&2; exit 9; }
# THE WORLD IS WHAT IT CLAIMS: the split renumbers (today's ordinal 09 is story-08b), and the two
# owed-group derivations differ on it, so a receipt keyed on {1,4,5} discriminates.
mkdir -p "$B/map/s9/shards/stories-p1" && ln -s "$B/full/s9/stories" "$B/map/s9/stories" || exit 9
m="$(bash "$SD/merge-adversarial-shards.sh" --map "$B/map/s9/shards/stories-p1" 2>/dev/null)" || exit 9
case "$m" in *"09	story-08b.md"*) ;; *) echo "receipt: --map does not renumber at the split" >&2; exit 9 ;; esac
g19="$(bash "$SD/partition-document.sh" --cross-groups 19)" && g20="$(bash "$SD/partition-document.sh" --cross-groups 20)" || exit 9
idiff="$(awk -F'\t' 'FNR == NR { o[$1] = $2; next } o[$1] != $2 { printf "%s ", $1 }' <(printf '%s\n' "$g19") <(printf '%s\n' "$g20"))"
[ "$idiff" = "3 5 6 " ] || { echo "receipt: the index-diff control is '$idiff', not '3 5 6 '" >&2; exit 9; }

run() { OUT="$(GIT_CEILING_DIRECTORIES="$B" bash "$SUBJ" --series "$B/$1/s9/stories-adversarial-p" 2>&1)"; RC=$?; }
bad=""
run nodelta
[ "$RC" -eq 1 ] && [[ "$OUT" == *"FAIL (L -- ELICITATION)"* ]] \
  && [[ "$OUT" == *"stories: story-08a story-08b; cross: cross.md (or all of cross-1 cross-4 cross-5)"* ]] \
  && [[ "$OUT" == *"stories-elicitation-delta-k20/"* ]] && [[ "$OUT" != *"cross-3"* ]] || bad="$bad nodelta(rc=$RC)"
for w in full fullg one; do
  run "$w"
  [ "$RC" -eq 0 ] && [[ "$OUT" == *"OK (L -- ELICITATION)"* ]] && [[ "$OUT" == *"stories-elicitation-delta-k20/ holds exactly the delta owed"* ]] || bad="$bad $w(rc=$RC)"
done
run nocross
[ "$RC" -eq 1 ] && [[ "$OUT" == *"(c) delta cross shard missing: cross.md (or every owed group: cross-1.md cross-4.md cross-5.md;"* ]] || bad="$bad nocross(rc=$RC)"
run miss
[ "$RC" -eq 1 ] && [[ "$OUT" == *"FAIL (L -- ELICITATION)"* ]] && [[ "$OUT" == *"story-08b.md"* ]] || bad="$bad miss(rc=$RC)"
run crossonly
[ "$RC" -eq 1 ] && [[ "$OUT" == *"FAIL (L -- ELICITATION)"* ]] && [[ "$OUT" == *"story-08a.md story-08b.md"* ]] || bad="$bad crossonly(rc=$RC)"
run xnamed
[ "$RC" -eq 1 ] && [[ "$OUT" == *"stories: story-08a story-08b; cross: cross.md (or all of cross-1 cross-4 cross-5)"* ]] || bad="$bad xnamed(rc=$RC)"
run voice
[ "$RC" -eq 1 ] && [[ "$OUT" == *"FAIL (L -- ELICITATION)"* ]] && [[ "$OUT" != *"OK (L"* ]] || bad="$bad voice(rc=$RC)"
if [ -n "$bad" ]; then echo "receipt BL-733: NOT FIXED --$bad"; exit 1; fi
echo "receipt BL-733: fixed (delta owed by name {story-08a story-08b; cross.md or cross-1 cross-4 cross-5}, judged in stories-elicitation-delta-k20/)"
exit 0
