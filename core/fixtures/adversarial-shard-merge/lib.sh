# adversarial-shard-merge/lib.sh -- the resolution, seeds, worlds and predicates of
# adversarial-shard-merge, sourced by that fixture's run.sh (the behavioural arms, shipped) (the retired mutation battery sourced it too).
# ONE copy, so the predicates the shipped arms run are never restated.
#
# The caller sets NAME and sources this file; nothing else. This file sets the shell options,
# scrubs AI_DLC_*, owns WORK and the ONE EXIT trap that removes it -- no caller sets a second.
# Every predicate takes the merge script to drive as its first argument, so a mutant is scored by
# the arm's own body.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ -n "${NAME:-}" ] || { echo "FIXTURE ERROR: lib.sh sourced without NAME set" >&2; exit 2; }

# Resolution walks up from THIS file's directory, so both callers resolve identically, and the
# seeds are read from beside it.
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SEED_DIR="$LIB_DIR"

# The subject, found by walking UP for a directory that carries it in either layout -- never by
# counting `..`. Distribution: <root>/core/scripts/. Consumer: <root>/scripts/ai-dlc/.
MERGE=""
_d="$LIB_DIR"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _c in "$_d/core/scripts/merge-adversarial-shards.sh" "$_d/scripts/ai-dlc/merge-adversarial-shards.sh"; do
    if [ -f "$_c" ]; then MERGE="$_c"; break 2; fi
  done
  _d="$(dirname "$_d")"
done
if [ -z "$MERGE" ]; then
  echo "FIXTURE ERROR: merge-adversarial-shards.sh not found above $LIB_DIR in either layout; nothing was asserted" >&2
  exit 2
fi
SRCDIR="$(cd "$(dirname "$MERGE")" && pwd)"
# The hook whose write ledger the merge derives each shard's dispatch id from. Every shard helper
# below drives it, so it is required: absent, every merge refuses "has no row" and every refusal arm
# would read as passing for that reason.
HOOK=""
_d="$LIB_DIR"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _c in "$_d/core/hooks/ai-dlc-gate-remediation-guard.sh" "$_d/.claude/hooks/ai-dlc-gate-remediation-guard.sh"; do
    if [ -f "$_c" ]; then HOOK="$_c"; break 2; fi
  done
  _d="$(dirname "$_d")"
done
[ -n "$HOOK" ] || { echo "FIXTURE ERROR: ai-dlc-gate-remediation-guard.sh not found above $LIB_DIR in either layout; no shard can carry a harness record" >&2; exit 2; }
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq is not on PATH; the hook records nothing and the merge derives nothing without it" >&2; exit 2; }
CONV="$SRCDIR/validate-adversarial-convergence.sh"
[ -f "$CONV" ] || { echo "FIXTURE ERROR: $CONV is not beside the merge; it reads its ceilings from there" >&2; exit 2; }
# Section mode reads its ordinal set from this sibling. Absent, the D arms would all refuse for
# THAT reason and the refusal arms would read as passing -- so its absence is an error, never a skip.
PARTITION="$SRCDIR/partition-document.sh"
[ -f "$PARTITION" ] || { echo "FIXTURE ERROR: $PARTITION is not beside the merge; section mode reads its --map" >&2; exit 2; }
# --rerun reads BACKDATE_TOL_S from this sibling. Absent, every --rerun cell would refuse for THAT reason.
[ -f "$SRCDIR/validate-artifact-budget.sh" ] || { echo "FIXTURE ERROR: $SRCDIR/validate-artifact-budget.sh is not beside the merge; --rerun reads its tolerance there" >&2; exit 2; }
for _s in seed.192-ff-A-token-decimal-resolution.md seed.bug-192-il-accuracy.md \
          seed.story-1-rebalancer-il-accuracy.md seed.finding-headings.txt \
          seed.doc-test-strategy.md seed.doc-serial-epics.md seed.files-b3-merged.expected; do
  [ -s "$SEED_DIR/$_s" ] || { echo "FIXTURE ERROR: seed $SEED_DIR/$_s is missing or empty" >&2; exit 2; }
done
echo "$NAME: resolved subject = $MERGE"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/$NAME.XXXXXX")" || exit 2
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
has() { local n; n="$(grep -cF -- "$2" "$1")" || n=0; [ "$n" -gt 0 ]; }

sha_of() {
  if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
  else sha256sum "$1" | cut -d' ' -f1; fi
}

# ---------------------------------------------------------------------------- world builder
# A world is a planning tree: s1/stories/<the three seeds>, s1/shards/stories-p1/ for the
# adversary shards, and -- ALWAYS -- s1/shards/stories-repair-p1/ holding a remediator part for
# the same pass. The two programs share `shards/` and never a directory; every merge below runs
# with the repair directory beside it and must count 4 shards, never 5.
# Each world is its own `mktemp -d`: a counter bumped inside `$(new_world)` dies with the
# subshell, and measured, every world then reused one directory and the second merge refused on
# the first one's output -- fourteen red rows that read like fourteen defects.
new_world() { # -> prints the shard dir of a fresh world
  local w pa s
  w="$(mktemp -d "$WORK/w.XXXXXX")" || return 1
  pa="$w/_bmad-output/planning-artifacts"
  mkdir -p "$pa/s1/stories" "$pa/s1/shards/stories-p1" "$pa/s1/shards/stories-repair-p1"
  for s in 192-ff-A-token-decimal-resolution.md bug-192-il-accuracy.md story-1-rebalancer-il-accuracy.md; do
    cp "$SEED_DIR/seed.$s" "$pa/s1/stories/$s"
  done
  printf -- '- **disposition:** repaired\n- **edit:** `stories/bug-192-il-accuracy.md:3`\n- **derivation:** a remediator part, not an adversary shard\n' \
    > "$pa/s1/shards/stories-repair-p1/01.md"
  printf '%s' "$pa/s1/shards/stories-p1"
}
out_of() { printf '%s' "$(dirname "$(dirname "$(dirname "$1")")")/s1/stories-adversarial-p1.md"; }
stories_of() { printf '%s' "$(dirname "$(dirname "$(dirname "$1")")")/s1/stories"; }

# Heading N of the real pass, re-prefixed with the severity word the merge's grammar reads.
real_title() { # <n> -> the title text after "### X# — "
  sed -n "${1}p" "$SEED_DIR/seed.finding-headings.txt" | sed 's/^### [A-Z][0-9]* — //'
}

# xkeys <K> -> the cross shard keys a lead dispatches for K units, one per line: `cross` when
# partition-document.sh --cross-groups prints one group (K=2), `cross-1 .. cross-<G>` otherwise.
# Read from the partitioner the lead reads, never restated here.
xkeys() {
  local g; g="$(bash "$PARTITION" --cross-groups "$1" | grep -c .)" || g=0
  [ "$g" -ge 1 ] || return 1
  if [ "$g" -eq 1 ]; then echo cross; else seq 1 "$g" | sed 's/^/cross-/'; fi
}
is_cross() { case "$1" in cross|cross-*) return 0 ;; esac; return 1; }

# ------------------------------------------------------------------- the harness records
# The merge derives each shard's dispatch id from three records the harness writes, never from the
# shard's own `tool_use_id:` (merge-adversarial-shards.sh, THE DISPATCH ID). Every shard helper
# below therefore seeds them, the write-ledger row by driving the REAL hook with the PreToolUse
# Write payload a dispatched agent's write produces:
#   write ledger   the hook appends `kind: "artifact-write"` (it is reached because the world holds
#                  <state>/pipeline-snapshot.md and the payload carries agent_id)
#   meta file      <transcript minus .jsonl>/subagents/agent-<agent_id>.meta.json, `toolUseId`
#   spawn ledger   <state>/spawn-ledger.jsonl, a row in ai-dlc-dispatch-guard.sh's shape
# IDENTITY IS A FUNCTION OF THE SHARD DIR AND FILE NAME ALONE (hr_ids), never of a temp path or a
# counter: the files-mode golden compares bytes, and a predicate that rewrites one shard twice must
# record ONE writer, not two. All shards of a world share one session and one transcript_path, as
# every subagent of one lead session does.
# Knobs, each scoped to one helper call by a prefix assignment (`HR_ROLE=remediator shard ...`):
#   HR_OFF=1      no record at all (a Bash-written shard)
#   HR_ROLE=<r>   the spawn row's role (default adversary)
#   HR_AGENT_O / HR_DID_O   override the derived agent id / dispatch id
#   HR_NOMETA=1   no meta file     HR_NOSPAWN=1  no spawn row
#   HR_PRE=1      the row carries no transcript_path (written before the hook recorded one)
#   HR_NOPROBE=1  no subagent-context.jsonl probe row (the writer has not stopped); by default one
#                 is written, agent_id -> dispatch id, except with HR_NOMETA=1 unless HR_PROBE=1
#   HR_SESSION=<s>  the payload's session_id (default fx-session, the transcript's own stem)
#   SELF_ID=<v>   the shard's self-reported tool_use_id (default NOT_ACCESSIBLE; ABSENT omits the line)
#   HR_IDFORM=call  the dispatch id in a local-model lead's shape, `call_` and 32 hex characters
#   HR_SPAWN_TS=<iso>  the spawn row's `ts`, the dispatch's recorded time (default 2026-10-15T20:00:00Z)
#   HR_FP_O=<path>  the payload's file_path, when the write is spelled from another tree or alias
hr_ids() { # <shard file> -> HR_AGENT, HR_DID
  local c
  c="$(printf '%s/%s' "$(basename "$(dirname "$1")")" "$(basename "$1")" | cksum)"; c="${c%% *}"
  HR_AGENT="$(printf 'a%016x' "$c")"
  if [ "${HR_IDFORM:-}" = call ]; then HR_DID="$(printf 'call_%032x' "$c")"
  else HR_DID="$(printf 'toolu_01AdvDispatch%011d' "$c")"; fi
}
did_of() { hr_ids "$1/$2.md"; printf '%s' "$HR_DID"; } # <shard dir> <key> -> the derived dispatch id
hr_state() { printf '%s' "$(dirname "$(dirname "$(dirname "$(dirname "$(dirname "$1")")")")")"; } # <shard file> -> <state>
harness_record() { # <shard file>
  [ "${HR_OFF:-0}" = 1 ] && return 0
  local f="$1" st root tp tpr role="${HR_ROLE:-adversary}"
  st="$(hr_state "$f")"; root="$(dirname "$st")"
  hr_ids "$f"
  [ -n "${HR_AGENT_O:-}" ] && HR_AGENT="$HR_AGENT_O"
  [ -n "${HR_DID_O:-}" ] && HR_DID="$HR_DID_O"
  tp="$root/.harness/fx-session.jsonl"
  mkdir -p "${tp%.jsonl}/subagents" || return 1
  [ -f "$st/pipeline-snapshot.md" ] || : > "$st/pipeline-snapshot.md"
  [ "${HR_NOMETA:-0}" = 1 ] || printf '{"agentType":"%s","description":"fixture shard writer","toolUseId":"%s","spawnDepth":1,"requestShape":"background"}\n' \
    "$role" "$HR_DID" > "${tp%.jsonl}/subagents/agent-$HR_AGENT.meta.json"
  [ "${HR_NOSPAWN:-0}" = 1 ] || printf '{"v":1,"ts":"%s","sprint":1,"name":null,"role":"%s","model_pinned":"opus","tier_pinned":null,"model_requested":"opus","model_bound":"definition","effort_bound":null,"role_contract_cited":true,"contract_via":"definition","role_file_readable":true,"definition_bound":true,"definition_stale":false,"name_stripped":null,"tool_use_id":"%s","shard":null}\n' \
    "${HR_SPAWN_TS:-2026-10-15T20:00:00Z}" "$role" "$HR_DID" >> "$st/spawn-ledger.jsonl"
  # The probe row ai-dlc-subagent-probe.sh writes when the writer STOPS, carrying the toolUseId it
  # read from the meta file -- so none without a meta file (the hook then records a null id).
  [ "${HR_NOPROBE:-0}" = 1 ] || { [ "${HR_NOMETA:-0}" = 1 ] && [ "${HR_PROBE:-0}" != 1 ]; } || printf '{"v":3,"ts":"2026-10-15T20:30:00Z","sprint":1,"agent_id":"%s","model":"opus","role":"%s","turns":9,"peak_tokens":1000,"compactions":0,"duration_s":60,"effort":null,"definition":null,"tool_use_id":"%s","transcript_version":null}\n' \
    "$HR_AGENT" "$role" "$HR_DID" >> "$st/subagent-context.jsonl"
  tpr="$tp"; [ "${HR_PRE:-0}" = 1 ] && tpr=""
  printf '{"session_id":"%s","transcript_path":"%s","cwd":"%s","hook_event_name":"PreToolUse","tool_name":"Write","tool_use_id":"toolu_01FxWriteCall%s","agent_id":"%s","agent_type":"%s","tool_input":{"file_path":"%s","content":"shard"}}' \
    "${HR_SESSION:-fx-session}" "$tpr" "$root" "${HR_DID#toolu_01AdvDispatch}" "$HR_AGENT" "$role" "${HR_FP_O:-$f}" \
    | CLAUDE_PROJECT_DIR="$root" bash "$HOOK" >/dev/null 2>&1
  return 0
}
self_line() { [ "${SELF_ID:-NOT_ACCESSIBLE}" = ABSENT ] || printf 'tool_use_id: %s\n' "${SELF_ID:-NOT_ACCESSIBLE}"; }

# shard <shard-dir> <key: ordinal|cross|cross-<g>> <n-major> <verdict> <stories-cite> [sha-override] [invoked_at]
shard() {
  local d="$1" k="$2" n="$3" v="$4" cite="$5" sha="${6:-}" at_o="${7:-}" i=0 b at hn
  if ! is_cross "$k" && [ -z "$sha" ]; then
    b="$(bash "$MERGE" --map "$d" | awk -F'\t' -v k="$k" '$1 + 0 == k + 0 { print $2 }')"
    sha="$(sha_of "$(stories_of "$d")/$b")"
  fi
  case "$k" in cross) at="2026-08-24T15:09:19Z" ;; cross-*) at="2026-08-24T15:09:1${k#cross-}Z" ;; *) at="2026-08-24T15:0${k}:19Z" ;; esac
  [ -n "$at_o" ] && at="$at_o"
  {
    printf '# stories -- adversarial shard %s\n\n## Findings\n\n' "$k"
    while [ "$i" -lt "$n" ]; do
      i=$((i + 1)); hn=$(( i % 10 + 1 ))
      printf '### M%s — MAJOR — %s\n\nstories: %s\n\nBody quoted from the real pass.\n\n' "$i" "$(real_title "$hn")" "$cite"
    done
    printf '## Probed and found sound\n\nNothing further.\n\n'
    printf '<!-- SKILL_INVOCATION_PROVENANCE v1\n'
    printf 'skill: ai-dlc-adversary-review\ninvoked_at: %s\n' "$at"; self_line
    printf 'mode: subagent\nlead_role: .claude/skills/ai-dlc/steps/stories-test-strategy.md\n'
    is_cross "$k" && printf 'artifact: _bmad-output/planning-artifacts/s1/stories\n'
    [ -n "$sha" ] && printf 'artifact_sha: %s\n' "$sha"
    printf 'findings_critical: 0\nfindings_critical_prior_scope: 0\nfindings_major: %s\n' "$n"
    printf 'findings_major_underived: 0\nfindings_minor: 0\nverdict: %s\n' "$v"
    printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'
  } > "$d/$k.md"
  harness_record "$d/$k.md"
}

# The B3 input: three ordinal shards, 2 MAJOR each, each stamped MET; clean cross shards, one per
# group of `--cross-groups 3` (cross-1..3).
b3_world() {
  local d x; d="$(new_world)"
  shard "$d" 1 2 EXIT_CONDITION_MET 1
  shard "$d" 2 2 EXIT_CONDITION_MET 2
  shard "$d" 3 2 EXIT_CONDITION_MET 3
  for x in $(xkeys 3); do shard "$d" "$x" 0 EXIT_CONDITION_MET "1, 3"; done
  printf '%s' "$d"
}
# The clean set: 1 MAJOR per ordinal shard (sum 3, AT the ceiling), clean cross shards -- and
# every shard stamped NOT_MET, the mirror of B3.
clean_world() {
  local d x; d="$(new_world)"
  shard "$d" 1 1 EXIT_CONDITION_NOT_MET 1
  shard "$d" 2 1 EXIT_CONDITION_NOT_MET 2
  shard "$d" 3 1 EXIT_CONDITION_NOT_MET 3
  for x in $(xkeys 3); do shard "$d" "$x" 0 EXIT_CONDITION_NOT_MET "1, 2"; done
  printf '%s' "$d"
}
# A files world of K story files (K >= 2), each distinct bytes, every ordinal shard clean and the
# cross shards the table names for K; no finding anywhere. -> the shard dir.
k_world() {
  local K="$1" w pa i o x
  w="$(mktemp -d "$WORK/kw.XXXXXX")" || return 1
  pa="$w/_bmad-output/planning-artifacts"
  mkdir -p "$pa/s1/stories" "$pa/s1/shards/stories-p1" || return 1
  i=0; while [ "$i" -lt "$K" ]; do i=$((i + 1)); printf '# Story %s\n\nBody of story %s.\n' "$i" "$i" > "$pa/s1/stories/story-$(printf '%02d' "$i")-k.md"; done
  if [ "${2:-}" != noshards ]; then
    for o in $(seq 1 "$K"); do shard "$pa/s1/shards/stories-p1" "$o" 0 EXIT_CONDITION_MET "$o"; done
    for x in $(xkeys "$K"); do shard "$pa/s1/shards/stories-p1" "$x" 0 EXIT_CONDITION_MET "1, 2"; done
  fi
  printf '%s' "$pa/s1/shards/stories-p1"
}

# ---------------------------------------------------------------- the cross groups (BL-464)
# Every mode at K=8 (files, --document, --subject --elicitation): cross-1..6 merges; cross.md alone
# refuses; a finding duplicated into a non-owner group refuses; and K=2 with cross.md merges.
# 8-section document, and an 8-unit subject built from the --document world's own partitioner.
doc8_world() { # -> the shard dir of a --document world over an 8-part document
  local w pa i
  w="$(mktemp -d "$WORK/d8.XXXXXX")" || return 1
  pa="$w/_bmad-output/planning-artifacts"
  mkdir -p "$pa/s1/shards/test-strategy-p1" || return 1
  { printf '# Test strategy\n\n'
    for i in 1 2 3 4 5 6 7 8; do printf '## Section %s\n\n' "$i"; slorem "sec$i" 15; printf '\n'; done; } > "$pa/s1/test-strategy.md"
  printf '%s' "$pa/s1/shards/test-strategy-p1"
}
# xset <mode> <shard dir> <K> <cross shape: groups|single> -- write every shard for that mode
xset() {
  local mode="$1" d="$2" K="$3" shape="$4" o x
  for o in $(seq 1 "$K"); do
    case "$mode" in
      files) shard "$d" "$o" 0 EXIT_CONDITION_MET "$o" ;;
      document) dshard "$d" "$o" 0 EXIT_CONDITION_MET "$o" ;;
      elicit) sshard "$d" "$o" 0 "$o" "" bmad-advanced-elicitation - ;;
    esac
  done
  if [ "$shape" = single ]; then x=cross; else x="$(xkeys "$K")"; fi
  for o in $x; do
    case "$mode" in
      files) shard "$d" "$o" 0 EXIT_CONDITION_MET "1, 2" ;;
      document) dshard "$d" "$o" 0 EXIT_CONDITION_MET "1, 2" ;;
      elicit) sshard "$d" "$o" 0 "1, 2" "" bmad-advanced-elicitation - ;;
    esac
  done
}
# xfind <mode> <shard dir> <key> <cite> -- rewrite one cross shard to hold one MAJOR citing <cite>
xfind() {
  case "$1" in
    files) shard "$2" "$3" 1 EXIT_CONDITION_MET "$4" ;;
    document) dshard "$2" "$3" 1 EXIT_CONDITION_MET "$4" ;;
    elicit) sshard "$2" "$3" 1 "$4" "" bmad-advanced-elicitation - ;;
  esac
}
xmerge() { # <merge> <mode> <shard dir> -> RC, $MO
  case "$2" in
    files) bash "$1" "$3" > "$MO" 2>&1; RC=$? ;;
    document) bash "$1" --document "$(doc_of "$3")" "$3" > "$MO" 2>&1; RC=$? ;;
    elicit) bash "$1" --subject 9 --elicitation "$3" > "$MO" 2>&1; RC=$? ;;
  esac
}
xworld() { # <mode> <K: 8|2> -> a fresh shard dir with no shards; K=2 only for files/document
  local w
  case "$1:$2" in
    files:8) k_world 8 noshards ;;
    files:2) w="$(new_world)"; rm -f "$(stories_of "$w")/story-1-rebalancer-il-accuracy.md"; printf '%s' "$w" ;;
    document:8) doc8_world ;;
    document:2) w="$(new_doc_world)"
      # Two byte-identical-length halves and no preamble: the largest part is exactly 50%, the
      # partitioner's MAX_SHARE_PCT, which is not OVER it -- the only K=2 shape a document can take.
      { printf '## A\n\n'; slorem a 15; printf '## B\n\n'; slorem b 15; } > "$(doc_of "$w")"; printf '%s' "$w" ;;
    elicit:8) w="$(subj_root "$(new_subj_world)")" || return 1
      mkdir -p "$w/$SUBJ_PA/s9/shards/requirements-elicitation"; printf '%s' "$w/$SUBJ_PA/s9/shards/requirements-elicitation" ;;
  esac
}
xk_of() { # <mode> <shard dir> -> the unit count the merge will read
  case "$1" in
    files) bash "$MERGE" --map "$2" | grep -c . ;;
    document) bash "$PARTITION" --map "$(doc_of "$2")" | grep -c . ;;
    elicit) grep -c . "$(subj_root "$(dirname "$2")/requirements-p1")/subject.map" ;;
  esac
}
# p_xgroups <merge> <mode>: the four cells for one mode, every one PRESENCE-shaped.
p_xgroups() {
  local m="$1" mode="$2" d K own non
  d="$(xworld "$mode" 8)" || return 1; K="$(xk_of "$mode" "$d")"
  [ "$K" -ge 5 ] || return 1                       # G = 6 needs K >= 5; the seed must express it
  xset "$mode" "$d" "$K" groups; xmerge "$m" "$mode" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" || return 1
  d="$(xworld "$mode" 8)"; xset "$mode" "$d" "$K" single; xmerge "$m" "$mode" "$d"
  [ "$RC" -eq 2 ] && has "$MO" "holds cross.md, but" || return 1
  # The duplicate: the pair (1, 2) sits in the first quarter, so SEVERAL groups cover it and exactly
  # one owns it. Seed the finding in its owner AND in another group that also covers it (the overlap
  # the owner rule exists for), and the merge must refuse naming the owner.
  own="$(bash "$PARTITION" --cross-owner "$K" "1,2")" || return 1
  non="$(bash "$PARTITION" --cross-groups "$K" | awk -F'\t' -v o="$own" '$1 != o && ("," $2 ",") ~ /,1,/ && ("," $2 ",") ~ /,2,/ { print $1; exit }')"
  [ -n "$non" ] || return 1
  d="$(xworld "$mode" 8)"; xset "$mode" "$d" "$K" groups
  xfind "$mode" "$d" "cross-$own" "1, 2"; xfind "$mode" "$d" "cross-$non" "1, 2"
  xmerge "$m" "$mode" "$d"
  [ "$RC" -eq 2 ] && has "$MO" "a finding owned by cross-$own" || return 1
  # Its ALLOW twin: the same finding in its owner alone merges, with major=1 (counted once).
  d="$(xworld "$mode" 8)"; xset "$mode" "$d" "$K" groups; xfind "$mode" "$d" "cross-$own" "1, 2"
  xmerge "$m" "$mode" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "major=1" || return 1
  # A finding citing (1, 2, K-1) reported ONLY by a non-owner holding 1 and K-1: a cross shard reads
  # the whole document, and its owner carries nothing identical, so it merges, counted once.
  local non3
  non3="$(bash "$PARTITION" --cross-groups "$K" | awk -F'\t' -v o="$own" -v z="$((K - 1))" '$1 != o && ("," $2 ",") ~ /,1,/ && ("," $2 ",") ~ ("," z ",") { print $1; exit }')"
  [ -n "$non3" ] || return 1
  d="$(xworld "$mode" 8)"; xset "$mode" "$d" "$K" groups; xfind "$mode" "$d" "cross-$non3" "1, 2, $((K - 1))"
  xmerge "$m" "$mode" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "major=1" || return 1
  # The merged tool_use_id is cross-1's DERIVED id and the id keys are cross-1..cross-6.
  local o; case "$mode" in files) o="$(out_of "$d")" ;; document) o="$(doc_out_of "$d")" ;; elicit) o="$(dirname "$(dirname "$d")")/requirements-elicitation.md" ;; esac
  grep -qx "tool_use_id: $(did_of "$d" cross-1)" "$o" && grep -q ' cross-6=' "$o" && ! grep -q ' cross=' "$o" || return 1
  [ "$mode" = elicit ] && return 0
  d="$(xworld "$mode" 2)"; [ "$(xk_of "$mode" "$d")" -eq 2 ] || return 1
  xset "$mode" "$d" 2 single; xmerge "$m" "$mode" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" || return 1
  d="$(xworld "$mode" 2)"; xset "$mode" "$d" 2 groups
  bash "$PARTITION" --cross-groups 2 >/dev/null || return 1
  # At K=2 the table has one row, so `cross-1.md` is the wrong spelling and refused.
  mv "$d/cross.md" "$d/cross-1.md" 2>/dev/null; xmerge "$m" "$mode" "$d"
  [ "$RC" -eq 2 ] && has "$MO" "which partition-document.sh --cross-groups 2 does not print"
}
p_xfiles() { p_xgroups "$1" files; }
p_xdoc() { p_xgroups "$1" document; }
p_xelicit() { p_xgroups "$1" elicit; }
p_xmix() { # cross.md beside cross-<g>.md -> refused as a mix
  local d; d="$(b3_world)"; shard "$d" cross 0 EXIT_CONDITION_MET "1, 3"; run_merge "$1" "$d"
  refused_clean "mixes cross.md with cross-<g>.md" "$d"
}
p_xunknown() { # cross-7.md at K=3 (three groups) -> refused by name
  local d; d="$(b3_world)"; shard "$d" cross-7 0 EXIT_CONDITION_MET "1, 3"; run_merge "$1" "$d"
  refused_clean "cross-7, which partition-document.sh --cross-groups 3 does not print" "$d"
}
p_xcomplete() { # seat-complete: one marked shard makes every unmarked one an unfinished refusal;
                # every shard marked merges and the markers are dropped; none marked merges (pre-release)
  local m="$1" d f o n
  d="$(b3_world)"; printf '\nseat-complete: stories adversary 1 findings=2\n' >> "$d/1.md"; run_merge "$m" "$d"
  refused_clean "does not end in 'seat-complete: '" "$d" || return 1
  # Every shard marked with its own finding count (B3: 2 per ordinal shard, 0 per cross shard).
  d="$(b3_world)"; o="$(out_of "$d")"
  for f in "$d"/*.md; do case "$(basename "$f")" in cross*) n=0 ;; *) n=2 ;; esac
    printf '\nseat-complete: stories adversary %s findings=%s\n\n' "$(basename "$f" .md)" "$n" >> "$f"; done
  run_merge "$m" "$d"
  [ "$RC" -eq 0 ] && [ -f "$o" ] && ! grep -q '^seat-complete: ' "$o" || return 1
  # All marked, one partial: 1.md declares findings=3 over the 2 it holds -> REFUSED as truncated.
  d="$(b3_world)"
  for f in "$d"/*.md; do case "$(basename "$f")" in cross*) n=0 ;; 1.md) n=3 ;; *) n=2 ;; esac
    printf '\nseat-complete: stories adversary %s findings=%s\n' "$(basename "$f" .md)" "$n" >> "$f"; done
  run_merge "$m" "$d"
  refused_clean "findings=3' but its ## Findings section heads 2 finding(s)" "$d"
}

# THE FIXED SCRATCH PATHS, all of them, bound in ONE place. Every predicate writes either under a
# fresh `mktemp -d "$WORK/..."` or to one of these two, so a caller that runs predicates
# CONCURRENTLY rebinds these by name (bind_scratch <own dir>) and shares nothing else that is
# written. A third fixed path added to a predicate must be added here, or two concurrent scorers
# write it at once.
bind_scratch() { # <dir> -> MO, CO under <dir>
  MO="$1/merge.out"; CO="$1/conv.out"
}
bind_scratch "$WORK"
run_merge() { # <merge-script> <shard-dir> -> RC, $MO
  bash "$1" "$2" > "$MO" 2>&1; RC=$?
}
refused_clean() { # <shard-dir> <token> -- exit 2, the token, nothing written, no temp left behind
  local o; o="$(out_of "$2")"
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED:" && has "$MO" "$1" && [ ! -e "$o" ] \
    && [ -z "$(find "$(dirname "$o")" -maxdepth 1 -name '*.merge-tmp.*' 2>/dev/null)" ]
}

# ------------------------------------------------------------------------------- predicates
# Each takes the merge script to drive, so the mutant battery scores the arm's OWN body.
p_b3() { # the recomputed verdict, and the convergence validator accepts the merged file
  local m="$1" d o c
  d="$(b3_world)"; o="$(out_of "$d")"; c="$(dirname "$m")/validate-adversarial-convergence.sh"
  run_merge "$m" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "verdict=EXIT_CONDITION_NOT_MET shards=6" && has "$MO" "blocking=6" \
    && [ -f "$o" ] && has "$o" "verdict: EXIT_CONDITION_NOT_MET" || return 1
  bash "$c" --series "$(dirname "$o")/stories-adversarial-p" --cycle-state > "$CO" 2>&1 || return 1
  has "$CO" "CONTINUE"
}
p_clean() { # every shard stamped NOT_MET, summed blocking == the ceiling -> MET, CONVERGED
  local m="$1" d o c
  d="$(clean_world)"; o="$(out_of "$d")"; c="$(dirname "$m")/validate-adversarial-convergence.sh"
  run_merge "$m" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "verdict=EXIT_CONDITION_MET shards=6" && has "$o" "verdict: EXIT_CONDITION_MET" || return 1
  bash "$c" --series "$(dirname "$o")/stories-adversarial-p" --cycle-state > "$CO" 2>&1 || return 1
  has "$CO" "CONVERGED"
}
p_ceiling() { # the ceiling is READ from the sibling: a copy whose sibling says 6 merges B3 as MET
  local m="$1" sd d o
  sd="$(mktemp -d "$WORK/ceil.XXXXXX")" || return 1
  cp "$m" "$sd/merge-adversarial-shards.sh"
  sed 's/^MAJOR_EXIT_CEILING=3$/MAJOR_EXIT_CEILING=6/' "$(dirname "$m")/validate-adversarial-convergence.sh" \
    > "$sd/validate-adversarial-convergence.sh"
  cp "$(dirname "$m")/validate-steering-budget.sh" "$sd/" 2>/dev/null
  # Every mode reads its cross groups from this sibling, files mode included.
  cp "$(dirname "$m")/partition-document.sh" "$sd/" || return 1
  cmp -s "$(dirname "$m")/validate-adversarial-convergence.sh" "$sd/validate-adversarial-convergence.sh" && return 2
  d="$(b3_world)"; o="$(out_of "$d")"
  run_merge "$sd/merge-adversarial-shards.sh" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "verdict=EXIT_CONDITION_MET" && has "$MO" "ceiling=6" || return 1
  bash "$sd/validate-adversarial-convergence.sh" --series "$(dirname "$o")/stories-adversarial-p" --cycle-state > "$CO" 2>&1 || return 1
  has "$CO" "CONVERGED"
}
p_miss_ord() { # ordinal 1 -- the NON-story file -- has no shard
  local d; d="$(b3_world)"; rm -f "$d/1.md"; run_merge "$1" "$d"
  refused_clean "shard 1 is missing from" "$d"
}
p_miss_cross() { # ONE of the three cross groups absent: every group is owed, not "some cross shard"
  local d; d="$(b3_world)"; rm -f "$d/cross-2.md"; run_merge "$1" "$d"
  refused_clean "shard cross-2 is missing from" "$d"
}
p_dup() { # 1.md and 01.md are one ordinal
  local d; d="$(b3_world)"; cp "$d/1.md" "$d/01.md"; run_merge "$1" "$d"
  refused_clean "was delivered more than once" "$d"
}
p_partition() { # a per-ordinal shard citing another story, and a cross shard citing one
  local d r1 r2; d="$(b3_world)"
  shard "$d" 2 2 EXIT_CONDITION_MET "1, 2"; run_merge "$1" "$d"
  refused_clean "a per-ordinal shard reports only findings citing its own ordinal alone" "$d"; r1=$?
  d="$(b3_world)"; shard "$d" cross-2 1 EXIT_CONDITION_MET 3; run_merge "$1" "$d"
  refused_clean "a cross-story finding cites two or more ordinals" "$d"; r2=$?
  [ "$r1" -eq 0 ] && [ "$r2" -eq 0 ]
}
p_sha() { # shard 3 notarized bytes that are not the story on disk
  local d; d="$(b3_world)"
  shard "$d" 3 2 EXIT_CONDITION_MET 3 "$(sha_of "$SEED_DIR/seed.bug-192-il-accuracy.md")"
  run_merge "$1" "$d"
  refused_clean "the shard reviewed other bytes" "$d"
}
p_ms() { # a shard stamped with milliseconds merges, and the merged invoked_at is the TRUE earliest
  # The discriminating pair is ONE second apart in neither direction: 15:00:19Z and 15:00:19.497Z.
  # By time 19Z is earlier; by raw string `.` (0x2E) sorts before `Z` (0x5A), so a raw comparison
  # picks 19.497Z. The consumer stamps both forms (4 of 317 real passes carry a fraction).
  local m="$1" d o c
  d="$(b3_world)"; o="$(out_of "$d")"; c="$(dirname "$m")/validate-adversarial-convergence.sh"
  shard "$d" 1 2 EXIT_CONDITION_MET 1 "" "2026-08-24T15:00:19.497Z"
  shard "$d" 2 2 EXIT_CONDITION_MET 2 "" "2026-08-24T15:00:19Z"
  run_merge "$m" "$d"
  [ "$RC" -eq 0 ] && has "$o" "invoked_at: 2026-08-24T15:00:19Z" || return 1
  # The validator must ACCEPT the merged value; which state it reaches is A1/A2's property, not
  # this cell's, so either healthy state passes here (asserting one entangled this cell with MX1).
  bash "$c" --series "$(dirname "$o")/stories-adversarial-p" --cycle-state > "$CO" 2>&1 || return 1
  has "$CO" "CONTINUE" || has "$CO" "CONVERGED"
}

# ------------------------------------------------------------------ section mode (--document)
# A document world: s1/test-strategy.md is a real consumer single-file artifact that
# partition-document.sh --map splits into three parts, and its shards sit in
# s1/shards/test-strategy-p1/. Every shard names the document by the project-relative token a
# real shard writes, so the merge must WALK UP to resolve it.
DOC_TOKEN="_bmad-output/planning-artifacts/s1/test-strategy.md"
new_doc_world() { # [seed] -> prints the shard dir of a fresh document world
  local w pa seed="${1:-seed.doc-test-strategy.md}"
  w="$(mktemp -d "$WORK/dw.XXXXXX")" || return 1
  pa="$w/_bmad-output/planning-artifacts"
  mkdir -p "$pa/s1/shards/test-strategy-p1" "$pa/s1/shards/test-strategy-repair-p1"
  cp "$SEED_DIR/$seed" "$pa/s1/test-strategy.md"
  printf -- '- **disposition:** repaired\n- **edit:** `test-strategy.md:9`\n' > "$pa/s1/shards/test-strategy-repair-p1/1.md"
  printf '%s' "$pa/s1/shards/test-strategy-p1"
}
doc_of() { printf '%s' "$(dirname "$(dirname "$1")")/test-strategy.md"; }
doc_out_of() { printf '%s' "$(dirname "$(dirname "$1")")/test-strategy-adversarial-p1.md"; }
run_doc_merge() { # <merge-script> <shard-dir> -> RC, $MO
  bash "$1" --document "$(doc_of "$2")" "$2" > "$MO" 2>&1; RC=$?
}
doc_refused_clean() { # <token> <shard-dir>
  local o; o="$(doc_out_of "$2")"
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED:" && has "$MO" "$1" && [ ! -e "$o" ] \
    && [ -z "$(find "$(dirname "$o")" -maxdepth 1 -name '*.merge-tmp.*' 2>/dev/null)" ]
}

# dshard <shard-dir> <key> <n-major> <verdict> <sections-cite> [sha] [artifact] [extra finding line]
dshard() {
  local d="$1" k="$2" n="$3" v="$4" cite="$5" sha="${6:-}" art="${7:-$DOC_TOKEN}" extra="${8:-}" i=0 at hn
  [ -n "$sha" ] || sha="$(sha_of "$(doc_of "$d")")"
  case "$k" in cross) at="2026-08-24T16:09:19Z" ;; cross-*) at="2026-08-24T16:09:1${k#cross-}Z" ;; *) at="2026-08-24T16:0${k}:19Z" ;; esac
  {
    printf '# test-strategy -- adversarial section shard %s\n\n## Findings\n\n' "$k"
    while [ "$i" -lt "$n" ]; do
      i=$((i + 1)); hn=$(( i % 10 + 1 ))
      printf '### M%s — MAJOR — %s\n\nsections: %s\n' "$i" "$(real_title "$hn")" "$cite"
      [ -n "$extra" ] && printf '%s\n' "$extra"
      printf '\nBody quoted from the real pass.\n\n'
    done
    printf '## Probed and found sound\n\nNothing further.\n\n'
    printf '<!-- SKILL_INVOCATION_PROVENANCE v1\n'
    printf 'skill: ai-dlc-adversary-review\ninvoked_at: %s\n' "$at"; self_line
    printf 'mode: subagent\nlead_role: .claude/skills/ai-dlc/steps/stories-test-strategy.md\n'
    printf 'artifact: %s\nartifact_sha: %s\n' "$art" "$sha"
    printf 'findings_critical: 0\nfindings_critical_prior_scope: 0\nfindings_major: %s\n' "$n"
    printf 'findings_major_underived: 0\nfindings_minor: 0\nverdict: %s\n' "$v"
    printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'
  } > "$d/$k.md"
  harness_record "$d/$k.md"
}
# The section-mode B3: three part shards of 2 MAJOR each, each stamped MET, and clean cross
# shards cross-1..3.
doc_b3_world() {
  local d x; d="$(new_doc_world)"
  dshard "$d" 1 2 EXIT_CONDITION_MET 1
  dshard "$d" 2 2 EXIT_CONDITION_MET 2
  dshard "$d" 3 2 EXIT_CONDITION_MET 3
  for x in $(xkeys 3); do dshard "$d" "$x" 0 EXIT_CONDITION_MET "1, 3"; done
  printf '%s' "$d"
}

p_doc_b3() { # sums, recomputes, ONE artifact_sha, a shard_wall entry per shard, validator reads 0/6
  local m="$1" d o c sha n_sha n_wall
  d="$(doc_b3_world)"; o="$(doc_out_of "$d")"; c="$(dirname "$m")/validate-adversarial-convergence.sh"
  sha="$(sha_of "$(doc_of "$d")")"
  run_doc_merge "$m" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "verdict=EXIT_CONDITION_NOT_MET shards=6" && has "$MO" "major=6" \
    && [ -f "$o" ] && has "$o" "verdict: EXIT_CONDITION_NOT_MET" || return 1
  n_sha="$(grep -c '^artifact_sha:' "$o")" || n_sha=0
  [ "$n_sha" -eq 1 ] && [ "$(grep '^artifact_sha:' "$o")" = "artifact_sha: $sha" ] || return 1
  # The merged tool_use_id is cross-1's -- the first group's dispatch, never the last one read.
  grep -qx "tool_use_id: $(did_of "$d" cross-1)" "$o" || return 1
  n_wall="$(grep '^shard_wall:' "$o" | tr ' ' '\n' | grep -cE '^(1|2|3|cross-1|cross-2|cross-3)=[0-9T:.Z-]+/[0-9T:Z-]+$')" || n_wall=0
  [ "$n_wall" -eq 6 ] || return 1
  # The per-file line of the validator's report (not --cycle-state, whose exit is the cycle's).
  bash "$c" --series "$(dirname "$o")/test-strategy-adversarial-p" > "$CO" 2>&1
  has "$CO" "verdict=EXIT_CONDITION_NOT_MET critical=0 major=6"
}
p_doc_axis() { # one sections: line AND a stories: line on the same finding -> the axis guard refuses
  local d; d="$(doc_b3_world)"
  dshard "$d" 2 2 EXIT_CONDITION_MET 2 "" "" "stories: 2"
  run_doc_merge "$1" "$d"
  doc_refused_clean "carries a 'stories:' line" "$d"
}
p_doc_sha() { # the right path, other bytes' sha
  local d; d="$(doc_b3_world)"
  dshard "$d" 2 2 EXIT_CONDITION_MET 2 "$(sha_of "$SEED_DIR/seed.doc-serial-epics.md")"
  run_doc_merge "$1" "$d"
  doc_refused_clean "the shard reviewed other bytes" "$d"
}
p_doc_path() { # the right bytes (so the sha check passes), another path
  local d cp_; d="$(doc_b3_world)"
  cp_="$(dirname "$(doc_of "$d")")/test-strategy-copy.md"; cp "$(doc_of "$d")" "$cp_"
  dshard "$d" 2 2 EXIT_CONDITION_MET 2 "" "_bmad-output/planning-artifacts/s1/test-strategy-copy.md"
  run_doc_merge "$1" "$d"
  doc_refused_clean "the shard reviewed another file" "$d"
}
p_doc_serial() { # a document partition-document.sh calls SERIAL is refused before any shard is read
  local d; d="$(new_doc_world seed.doc-serial-epics.md)"
  dshard "$d" 1 0 EXIT_CONDITION_MET 1
  dshard "$d" 2 0 EXIT_CONDITION_MET 2
  dshard "$d" cross 0 EXIT_CONDITION_MET "1, 2"
  run_doc_merge "$1" "$d"
  doc_refused_clean "does not partition (SERIAL:" "$d"
}
p_files_golden() { # files mode is byte-identical to the merge before section mode existed
  local m="$1" d o
  d="$(b3_world)"; o="$(out_of "$d")"
  run_merge "$m" "$d"
  [ "$RC" -eq 0 ] && cmp -s "$o" "$SEED_DIR/seed.files-b3-merged.expected"
}
# ------------------------------------------------------------------ subject mode (--subject)
# A subject world is a git repository (trunk main, sprint on a branch) holding the requirements
# subject, its manifest written by the REAL partition-subject.sh first map. Shards notarize the
# four stems and name the manifest; findings cite subject ordinals by `sections:`.
SG() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$1" -c user.name=f -c user.email=f@example.invalid -c core.hooksPath=/dev/null "${@:2}"; }
slorem() { local i; for i in $(seq 1 "$2"); do printf '%s line %d of the section, carrying enough prose to weigh something real.\n' "$1" "$i"; done; }
SUBJ_PA=_bmad-output/planning-artifacts
new_subj_world() { # -> prints the shard dir s9/shards/requirements-p1 of a fresh subject world
  local w pa; w="$(mktemp -d "$WORK/sw.XXXXXX")" || return 1; pa="$w/$SUBJ_PA"
  mkdir -p "$pa/s9/shards/requirements-p1" "$w/_bmad-output/specs/s9/kernel" || return 1
  { SG "$w" init -q . && SG "$w" checkout -q -b main
    { printf '# Brief\n\n## Vision\n\n'; slorem vision 10; } > "$pa/product-brief.md"
    { printf '# PRD\n\n## Current state\n\n'; slorem current 20; printf '\n## Sprint 8\n\n'; slorem s8 20; printf '\n'; } > "$pa/prd.md"
    SG "$w" add -A && SG "$w" commit -q -m base && SG "$w" checkout -q -b sprint-9; } >/dev/null 2>&1 || return 1
  printf 'A new brief line.\n' >> "$pa/product-brief.md"
  { printf '## Sprint 9\n\n### Goals\n\n'; slorem s9g 30; printf '\n### Requirements\n\n'; slorem s9r 30; } >> "$pa/prd.md"
  printf '# SPEC\n\ncap-1: THE system SHALL x.\n' > "$w/_bmad-output/specs/s9/kernel/SPEC.md"
  printf -- '- FR-S9-1: architecture_impact: none\n' > "$pa/s9/architecture-impact.md"
  AI_DLC_PROJECT_ROOT="$w" bash "$SRCDIR/partition-subject.sh" --map 9 > "$w/subject.map" 2>&1 || return 1
  printf '%s' "$pa/s9/shards/requirements-p1"
}
subj_root() { printf '%s' "$(dirname "$(dirname "$(dirname "$(dirname "$(dirname "$1")")")")")"; }
subj_out_of() { printf '%s' "$(dirname "$(dirname "$1")")/requirements-adversarial-p1.md"; }
subj_shas() { # <shard dir> -> the four-stem list as on disk
  local w; w="$(subj_root "$1")"
  printf 'product-brief=%s SPEC=%s prd=%s architecture-impact=%s' "$(sha_of "$w/$SUBJ_PA/product-brief.md")" \
    "$(sha_of "$w/_bmad-output/specs/s9/kernel/SPEC.md")" "$(sha_of "$w/$SUBJ_PA/prd.md")" "$(sha_of "$w/$SUBJ_PA/s9/architecture-impact.md")"
}
# sshard <dir> <key> <n-major> <cite> [sha-list] [skill] [verdict|-] [artifact]
sshard() {
  local d="$1" k="$2" n="$3" cite="$4" sl="${5:-}" sk="${6:-ai-dlc-adversary-review}" v="${7:-EXIT_CONDITION_MET}" i=0 mm
  local art="${8:-$SUBJ_PA/s9/requirements-subject.md}"
  [ -n "$sl" ] || sl="$(subj_shas "$d")"
  case "$k" in cross) mm=59 ;; cross-*) mm=$((50 + ${k#cross-})) ;; *) mm=$((10#$k)) ;; esac
  { printf '# requirements -- subject shard %s\n\n## Findings\n\n' "$k"
    while [ "$i" -lt "$n" ]; do i=$((i + 1)); printf '### M%s — MAJOR — %s\n\nsections: %s\n\nBody.\n\n' "$i" "$(real_title "$i")" "$cite"; done
    printf '<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: %s\ninvoked_at: 2026-10-01T10:%02d:00Z\n' "$sk" "$mm"
    self_line; printf 'mode: subagent\nlead_role: .claude/skills/ai-dlc/steps/requirements.md\n'
    printf 'artifact: %s\nartifact_sha: %s\n' "$art" "$sl"
    printf 'findings_critical: 0\nfindings_critical_prior_scope: 0\nfindings_major: %s\nfindings_major_underived: 0\nfindings_minor: 0\n' "$n"
    [ "$v" = "-" ] || printf 'verdict: %s\n' "$v"
    printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'; } > "$d/$k.md"
  harness_record "$d/$k.md"
}
subj_xkeys() { xkeys "$(grep -c . "$(subj_root "$1")/subject.map")"; } # <shard dir> -> its cross keys
subj_b3_world() { # every part shard 1 MAJOR stamped MET, summed over the ceiling; clean cross shards
  local d o; d="$(new_subj_world)" || return 1
  for o in $(cut -f1 "$(subj_root "$d")/subject.map"); do sshard "$d" "$o" 1 "$o"; done
  for o in $(subj_xkeys "$d"); do sshard "$d" "$o" 0 "1, 2"; done
  printf '%s' "$d"
}
run_subj_merge() { bash "$1" --subject 9 "${@:3}" "$2" > "$MO" 2>&1; RC=$?; }
subj_refused_clean() { # <token> <shard-dir>
  local o; o="$(subj_out_of "$2")"
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED:" && has "$MO" "$1" && [ ! -e "$o" ]
}
p_subj_b3() { # sums, recomputes, artifact = manifest, four stems, ids = ordinals + cross; validator reads it
  local m="$1" d o k want have
  d="$(subj_b3_world)" || return 1; o="$(subj_out_of "$d")"
  k="$(grep -c . "$(subj_root "$d")/subject.map")"
  run_subj_merge "$m" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "verdict=EXIT_CONDITION_NOT_MET" && has "$MO" "major=$k" && [ -f "$o" ] || return 1
  grep -qx "artifact: $SUBJ_PA/s9/requirements-subject.md" "$o" || return 1
  [ "$(grep '^artifact_sha:' "$o")" = "artifact_sha: $(subj_shas "$d")" ] || return 1
  want="$( { cut -f1 "$(subj_root "$d")/subject.map" | awk '{ print $1 + 0 }'; subj_xkeys "$d"; } | sort | tr '\n' ' ')"
  have="$(sed -n 's/^shard_tool_use_ids://p' "$o" | tr ' ' '\n' | awk -F= 'NF == 2 { k = $1; if (k ~ /^[0-9]+$/) k += 0; print k }' | sort | tr '\n' ' ')"
  [ "$want" = "$have" ]
}
p_subj_miss_cross() { # the LAST cross group absent (a merge requiring only cross-1 would accept it)
  local d x; d="$(subj_b3_world)" || return 1; x="$(subj_xkeys "$d" | tail -1)"
  [ "$x" != cross ] || return 1
  rm -f "$d/$x.md"; run_subj_merge "$1" "$d"; subj_refused_clean "shard $x is missing" "$d"; }
p_subj_xcite() { # a part shard citing ANOTHER file's ordinal (cross-file citation) -> refused
  local d; d="$(subj_b3_world)" || return 1
  sshard "$d" 1 1 "1, 3"
  run_subj_merge "$1" "$d"
  subj_refused_clean "a per-ordinal shard reports only findings citing its own ordinal alone" "$d"
}
p_subj_sha() { # one stem's sha is not the disk bytes (the prd moved), every other stem right
  local d sl; d="$(subj_b3_world)" || return 1
  sl="$(subj_shas "$d" | sed "s/prd=[0-9a-f]*/prd=$(sha_of "$SEED_DIR/seed.doc-serial-epics.md")/")"
  sshard "$d" 2 1 2 "$sl"
  run_subj_merge "$1" "$d"
  subj_refused_clean "notarizes prd=" "$d"
}
p_subj_stems() { # a shard notarizing three of the four stems
  local d sl; d="$(subj_b3_world)" || return 1
  sl="$(subj_shas "$d" | sed 's/ architecture-impact=[0-9a-f]*//')"
  sshard "$d" 2 1 2 "$sl"
  run_subj_merge "$1" "$d"
  subj_refused_clean "notarizes each of the four stems once" "$d"
}
p_subj_art() { # a shard naming prd.md, not the manifest
  local d; d="$(subj_b3_world)" || return 1
  sshard "$d" 2 1 2 "" "" "" "$SUBJ_PA/prd.md"
  run_subj_merge "$1" "$d"
  subj_refused_clean "not the subject manifest" "$d"
}
p_subj_elicit() { # elicitation: no verdict anywhere, skill required, own output; a verdict-bearing shard refused
  local m="$1" w e o; w="$(subj_root "$(new_subj_world)")" || return 1
  e="$w/$SUBJ_PA/s9/shards/requirements-elicitation"; mkdir -p "$e"; o="$w/$SUBJ_PA/s9/requirements-elicitation.md"
  for k in $(cut -f1 "$w/subject.map"); do sshard "$e" "$k" 1 "$k" "" bmad-advanced-elicitation -; done
  for k in $(xkeys "$(grep -c . "$w/subject.map")"); do sshard "$e" "$k" 0 "1, 2" "" bmad-advanced-elicitation -; done
  # Shards notarize via a path walk from the shard dir; subj_shas reads from the shard dir's world.
  bash "$m" --subject 9 --elicitation "$e" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && [ -f "$o" ] && ! grep -q '^verdict:' "$o" && ! grep -q 'verdict=' "$MO" && has "$o" "skill: bmad-advanced-elicitation" || return 1
  [ ! -e "$w/$SUBJ_PA/s9/requirements-adversarial-p1.md" ] || return 1
  rm -f "$o"; sshard "$e" 1 1 1 "" bmad-advanced-elicitation EXIT_CONDITION_MET
  bash "$m" --subject 9 --elicitation "$e" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$MO" "an elicitation shard carries none" && [ ! -e "$o" ] || return 1
  sshard "$e" 1 1 1 "" ai-dlc-adversary-review -
  bash "$m" --subject 9 --elicitation "$e" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$MO" "an elicitation shard runs bmad-advanced-elicitation" && [ ! -e "$o" ]
}
p_subj_b4() { # --document into requirements-p<M> refused before any shard is read
  local d w; d="$(subj_b3_world)" || return 1; w="$(subj_root "$d")"
  bash "$1" --document "$w/$SUBJ_PA/prd.md" "$d" > "$MO" 2>&1; RC=$?
  subj_refused_clean "merge it with --subject" "$d"
}
# B4 BY DOCUMENT (BL-461): a --document merge of a file the sprint's subject manifest NAMES is
# refused, whatever its shard dir is called. Three worlds, one property apart:
#   b4doc        manifest present, --document prd.md from shards/prd-p1          REFUSED naming the stem
#   b4doc_nomf   the same merge, no manifest in the sprint (the ALLOW twin)       MERGED prd-adversarial-p1
#   b4doc_other  manifest present, --document of an s9 file it does NOT name      MERGED (a guard refusing
#                every --document in a manifest sprint dies here, not on b4doc_nomf)
# The prd world's prd.md partitions unscoped (two `##` sections plus a third), so the merge would
# otherwise succeed; b4doc_nomf proves that.
b4_doc_shards() { # <world> <document rel> <shard dir> -> unscoped section shards over the document
  local w="$1" doc="$1/$2" d="$3" o sl
  mkdir -p "$d" || return 1; sl="$(sha_of "$doc")"
  for o in $(bash "$SRCDIR/partition-document.sh" --map "$doc" | cut -f1) \
           $(xkeys "$(bash "$SRCDIR/partition-document.sh" --map "$doc" | grep -c .)"); do
    sshard "$d" "$o" 0 "$o" "$sl" "" "" "$2"
  done
  [ -f "$d/1.md" ] && [ -f "$d/2.md" ]
}
b4_world() { # <with manifest: 1|0> -> the world root
  local d w; d="$(new_subj_world)" || return 1; w="$(subj_root "$d")"
  [ "$1" = 1 ] || rm -f "$w/$SUBJ_PA/s9/requirements-subject.md"
  printf '%s' "$w"
}
p_b4doc() {
  local w o; w="$(b4_world 1)" || return 1; o="$w/$SUBJ_PA/s9/prd-adversarial-p1.md"
  b4_doc_shards "$w" "$SUBJ_PA/prd.md" "$w/$SUBJ_PA/s9/shards/prd-p1" || return 1
  bash "$1" --document "$w/$SUBJ_PA/prd.md" "$w/$SUBJ_PA/s9/shards/prd-p1" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED:" && has "$MO" "is the 'prd' file of the requirements subject" \
    && has "$MO" "merge the subject with --subject 9" && [ ! -e "$o" ]
}
p_b4doc_nomf() {
  local w o; w="$(b4_world 0)" || return 1; o="$w/$SUBJ_PA/s9/prd-adversarial-p1.md"
  [ ! -e "$w/$SUBJ_PA/s9/requirements-subject.md" ] || return 1
  b4_doc_shards "$w" "$SUBJ_PA/prd.md" "$w/$SUBJ_PA/s9/shards/prd-p1" || return 1
  bash "$1" --document "$w/$SUBJ_PA/prd.md" "$w/$SUBJ_PA/s9/shards/prd-p1" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] && grep -qx "artifact: $SUBJ_PA/prd.md" "$o"
}
p_b4doc_other() {
  local w o doc; w="$(b4_world 1)" || return 1; o="$w/$SUBJ_PA/s9/test-strategy-adversarial-p1.md"
  [ -f "$w/$SUBJ_PA/s9/requirements-subject.md" ] || return 1
  doc="$SUBJ_PA/s9/test-strategy.md"; cp "$SEED_DIR/seed.doc-test-strategy.md" "$w/$doc" || return 1
  b4_doc_shards "$w" "$doc" "$w/$SUBJ_PA/s9/shards/test-strategy-p1" || return 1
  bash "$1" --document "$w/$doc" "$w/$SUBJ_PA/s9/shards/test-strategy-p1" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ]
}
# ------------------------------------------------------- the series stem is not the artifact
# A shard dir whose <artifact> ends in `-adversarial` names the SERIES (graph s319 derived
# `shards/coe-adversarial-p1/` from `coe-adversarial-p<M>.md`) and was merged silently into
# `coe-adversarial-adversarial-p1.md`. Every world here is a sprint s9 holding the 3-part document
# seed, with the shard set written into s9/shards/<base>/ -- the one property the cells vary.
STEM_TOKEN="_bmad-output/planning-artifacts/s9/test-strategy.md"
stem_world() { # <shard-dir basename> -> prints the shard dir of a fresh s9 document world, shards written
  local w pa d x
  w="$(mktemp -d "$WORK/sw.XXXXXX")" || return 1
  pa="$w/_bmad-output/planning-artifacts"; d="$pa/s9/shards/$1"
  mkdir -p "$d" || return 1
  cp "$SEED_DIR/seed.doc-test-strategy.md" "$pa/s9/test-strategy.md" || return 1
  dshard "$d" 1 0 EXIT_CONDITION_MET 1 "" "$STEM_TOKEN"
  dshard "$d" 2 0 EXIT_CONDITION_MET 2 "" "$STEM_TOKEN"
  dshard "$d" 3 0 EXIT_CONDITION_MET 3 "" "$STEM_TOKEN"
  for x in $(xkeys 3); do dshard "$d" "$x" 0 EXIT_CONDITION_MET "1, 3" "" "$STEM_TOKEN"; done
  printf '%s' "$d"
}
stem_s9() { printf '%s' "$(dirname "$(dirname "$1")")"; }
stem_merge() { bash "$1" --document "$(stem_s9 "$2")/test-strategy.md" "$2" > "$MO" 2>&1; RC=$?; }
stem_none() { # <s9 dir> -> 0 when no *adversarial* file and no merge temp sits in it
  [ -z "$(find "$1" -maxdepth 1 -type f \( -name '*adversarial*' -o -name '*.merge-tmp.*' \) 2>/dev/null)" ]
}
p_stem_series() { # document mode, shards/doc-adversarial-p1/ -> REFUSED naming the series, nothing written
  local d; d="$(stem_world doc-adversarial-p1)" || return 1
  stem_merge "$1" "$d"
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED: shard directory doc-adversarial-p1 names the series, not the artifact" \
    && has "$MO" "would write doc-adversarial-adversarial-p1.md" && stem_none "$(stem_s9 "$d")"
}
p_stem_control() { # the same shards under doc-p1/ and under graph's real coe-p1/ each MERGE
  local d s
  for s in doc coe; do
    d="$(stem_world "$s-p1")" || return 1
    stem_merge "$1" "$d"
    [ "$RC" -eq 0 ] && has "$MO" "MERGED: " && [ -f "$(stem_s9 "$d")/$s-adversarial-p1.md" ] || return 1
  done
}
p_stem_near() { # a stem CONTAINING the word, not ending in it, is legal: adversarial-notes-p1 MERGES
  local d; d="$(stem_world adversarial-notes-p1)" || return 1
  stem_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED: " && [ -f "$(stem_s9 "$d")/adversarial-notes-adversarial-p1.md" ]
}
p_stem_files() { # files mode and --map, shards/stories-adversarial-p1/ -> both REFUSED naming the series
  local d s9; d="$(stem_world stories-adversarial-p1)" || return 1; s9="$(stem_s9 "$d")"
  # The artifact dir the wrong name derives EXISTS with two stories, so without the refusal --map
  # prints its ordinal map (exit 0) and files mode reads on: only the refusal stops either.
  mkdir -p "$s9/stories-adversarial" && printf 'a\n' > "$s9/stories-adversarial/a.md" \
    && printf 'b\n' > "$s9/stories-adversarial/b.md" || return 1
  bash "$1" "$d" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED: shard directory stories-adversarial-p1 names the series" || return 1
  bash "$1" --map "$d" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED: shard directory stories-adversarial-p1 names the series" \
    && ! grep -q "$(printf '\t')a.md" "$MO" && stem_none "$s9"
}

# --------------------------------------------- the dispatch id is DERIVED, never self-reported
# Every world below is the B3 world with shard 2 (and only shard 2) written under the knob the cell
# varies; shards 1, 3 and cross-1..3 are written normally, so each refusal is that shard's alone.
# The ALLOW twin of each refusal sits in the same predicate wherever one property separates them.
tw() { # -> a B3 shard dir with every shard but 2 written and recorded
  local d x; d="$(new_world)"
  shard "$d" 1 2 EXIT_CONDITION_MET 1
  shard "$d" 3 2 EXIT_CONDITION_MET 3
  for x in $(xkeys 3); do shard "$d" "$x" 0 EXIT_CONDITION_MET "1, 3"; done
  printf '%s' "$d"
}
s2() { shard "$1" 2 2 EXIT_CONDITION_MET 2; } # <shard dir> -- shard 2, under whatever knobs prefix the call
REAL_OTHER=toolu_01ZZZZZZZZZZZZZZZZZZZZZZ   # real-shaped (toolu_ + 24 base62) and no fixture's derived id
FORGED=toolu_cross1_g1_dispatch             # a fabricated id the reference consumer merged; NOT real-shaped
p_tuid_main() { # self ids NOT_ACCESSIBLE / unavailable / absent / forged all merge, ids = the derived ones
  local m="$1" d o k want have sid
  for sid in NOT_ACCESSIBLE unavailable ABSENT "$FORGED"; do
    d="$(SELF_ID="$sid" b3_world)"; o="$(out_of "$d")"
    run_merge "$m" "$d"
    [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] || return 1
    want=""; for k in 1 2 3 cross-1 cross-2 cross-3; do want="$want $k=$(did_of "$d" "$k")"; done
    have="$(sed -n 's/^shard_tool_use_ids://p' "$o")"
    [ "$have" = "$want" ] || return 1
    grep -qx "tool_use_id: $(did_of "$d" cross-1)" "$o" || return 1
    ! grep -qF -- "$FORGED" "$o" || return 1
  done
}
p_tuid_norow() { # R1: shard 2 has no write-ledger row (a Bash write) -> REFUSED; no fallback to its self id
  local d; d="$(tw)"; SELF_ID="$FORGED" HR_OFF=1 s2 "$d"; run_merge "$1" "$d"
  refused_clean "2.md has no row in" "$d"
}
p_tuid_nometa() { # R2: the writer's meta file is absent, no probe row, a real-shaped self id -> REFUSED
  local d; d="$(tw)"; SELF_ID="$REAL_OTHER" HR_NOMETA=1 s2 "$d"; run_merge "$1" "$d"
  refused_clean "whose meta file" "$d" && has "$MO" "is absent; its dispatch id cannot be derived"
}
p_tuid_selfdiff() { # R3: a real-shaped self id that differs from the derived one -> REFUSED; equal merges
  local d; d="$(tw)"; SELF_ID="$REAL_OTHER" s2 "$d"; run_merge "$1" "$d"
  refused_clean "self-reports tool_use_id $REAL_OTHER, but the harness records derive" "$d" || return 1
  d="$(tw)"; SELF_ID="$(did_of "$d" 2)" s2 "$d"; run_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:"
}
p_tuid_role() { # R4: shard 2's only writer was dispatched as a remediator; R8: an adversary AND a
                # remediator wrote it -- each REFUSED naming the role
  local d; d="$(tw)"; HR_ROLE=remediator s2 "$d"; run_merge "$1" "$d"
  refused_clean "dispatched as role remediator; only an adversary writes an adversary shard" "$d" || return 1
  d="$(tw)"; s2 "$d"
  HR_ROLE=remediator HR_AGENT_O=a00000000000000r8 HR_DID_O=toolu_01RemediatorWrite000008 harness_record "$d/2.md"
  run_merge "$1" "$d"
  refused_clean "dispatched as role remediator; only an adversary writes an adversary shard" "$d"
}
p_tuid_twowriters() { # R6: two adversary dispatches wrote shard 2 -> REFUSED, never the first taken
  local d; d="$(tw)"; s2 "$d"
  HR_AGENT_O=a00000000000000r6 HR_DID_O=toolu_01SecondAdversary0000006 harness_record "$d/2.md"
  run_merge "$1" "$d"
  refused_clean "was written by more than one adversary dispatch" "$d"
}
p_tuid_oneagent() { # R5: one agent wrote shards 2 and 3 -> REFUSED, one dispatch delivered two shards
  local d x; d="$(new_world)"
  shard "$d" 1 2 EXIT_CONDITION_MET 1; s2 "$d"
  hr_ids "$d/2.md"
  HR_AGENT_O="$HR_AGENT" HR_DID_O="$HR_DID" shard "$d" 3 2 EXIT_CONDITION_MET 3
  for x in $(xkeys 3); do shard "$d" "$x" 0 EXIT_CONDITION_MET "1, 3"; done
  run_merge "$1" "$d"
  refused_clean "one dispatch delivered two shards" "$d"
}
p_tuid_nospawn() { # R7: the meta file's dispatch id has no spawn-ledger row -> REFUSED
  local d; d="$(tw)"; HR_NOSPAWN=1 s2 "$d"; run_merge "$1" "$d"
  refused_clean "which has no row in" "$d" && has "$MO" "spawn-ledger.jsonl"
}
p_tuid_session() { # the meta file is found from the ROW's transcript_path and agent_id: a payload whose
                   # session_id is not the transcript's stem still merges
  local d x; d="$(new_world)"
  for x in 1 2 3; do HR_SESSION=other-session shard "$d" "$x" 2 EXIT_CONDITION_MET "$x"; done
  for x in $(xkeys 3); do HR_SESSION=other-session shard "$d" "$x" 0 EXIT_CONDITION_MET "1, 3"; done
  run_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && grep -qx "tool_use_id: $(did_of "$d" cross-1)" "$(out_of "$d")"
}
p_tuid_pre() { # R9: a row with no transcript_path takes the probe row's id (merges); with no probe row
               # it is REFUSED naming the agent and "predates transcript_path"
  local d; d="$(tw)"; HR_PRE=1 HR_PROBE=1 s2 "$d"; run_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && grep -q " 2=$(did_of "$d" 2) " "$(out_of "$d")" || return 1
  d="$(tw)"; HR_PRE=1 HR_NOPROBE=1 s2 "$d"; hr_ids "$d/2.md"; run_merge "$1" "$d"
  refused_clean "agent $HR_AGENT in a row that predates transcript_path" "$d"
}
p_tuid_basename() { # rows are keyed on the FULL path under the shard dir: shard 2's only rows sit under
                    # ANOTHER shard dir of the same sprint and under the same dir name in ANOTHER sprint
  local d pa o; d="$(tw)"; pa="$(dirname "$(dirname "$(dirname "$d")")")"
  # ABSENT self id: a no-row shard then has nothing a self-report fallback (TM1) could take, so the
  # refusal is this cell's alone.
  SELF_ID=ABSENT HR_OFF=1 s2 "$d"
  for o in "$pa/s1/shards/stories-p2" "$pa/s2/shards/stories-p1"; do
    mkdir -p "$o" && harness_record "$o/2.md" || return 1
  done
  [ "$(grep -c '"path":"[^"]*/shards/stories-p[12]/2.md"' "$pa/.artifact-writes.jsonl")" -eq 2 ] || return 1
  run_merge "$1" "$d"
  refused_clean "2.md has no row in" "$d"
}
p_tuid_probemeta() { # the probe ledger carries TWO ids for shard 2's agent, the meta file's and another
                     # adversary dispatch's -> REFUSED: every probe row must carry the meta's id (BL-536 D4)
  local d st; d="$(tw)"; s2 "$d"; hr_ids "$d/2.md"; st="$(hr_state "$d/2.md")"
  printf '{"v":3,"agent_id":"%s","role":"adversary","tool_use_id":"%s"}\n' "$HR_AGENT" "$REAL_OTHER" >> "$st/subagent-context.jsonl"
  printf '{"v":1,"role":"adversary","tool_use_id":"%s"}\n' "$REAL_OTHER" >> "$st/spawn-ledger.jsonl"
  run_merge "$1" "$d"
  refused_clean "whose meta file names dispatch $HR_DID but" "$d" \
    && has "$MO" "for that agent; the meta file was rewritten after the agent stopped"
}
p_tuid_tworoles() { # ONE dispatch id carrying two spawn rows, adversary and remediator -> REFUSED
  local d st; d="$(tw)"; s2 "$d"; hr_ids "$d/2.md"; st="$(hr_state "$d/2.md")"
  printf '{"v":1,"role":"remediator","tool_use_id":"%s"}\n' "$HR_DID" >> "$st/spawn-ledger.jsonl"
  run_merge "$1" "$d"
  refused_clean "dispatch $HR_DID, dispatched as role remediator" "$d"
}
# ------------------------------------------------- the re-dispatch of one shard (--rerun)
# The hook stamps each row with the wall clock, so a cell that must place rows on either side of a
# re-run start re-stamps the rows ONE harness_record call appended, by line number, after the hook
# wrote them: hr_at <ts> <command...>. Nothing else in the row moves.
hr_at() {
  local ts="$1" led n0 n1; shift
  led="$(hr_state "$WORLD_SHARD")/planning-artifacts/.artifact-writes.jsonl"
  n0="$(grep -c . "$led" 2>/dev/null)" || n0=0
  "$@" || return 1
  n1="$(grep -c . "$led")" || n1=0
  [ "$n1" -gt "$n0" ] || return 1
  awk -v n0="$n0" -v ts="$ts" 'NR > n0 { sub(/"ts":"[^"]*"/, "\"ts\":\"" ts "\"") } { print }' "$led" > "$led.tmp" \
    && mv "$led.tmp" "$led"
}
# The re-run start. A merging --rerun cell's NEW dispatch records this as its spawn-ledger time
# (HR_SPAWN_TS), because the merge binds S to that time (BL-598).
RR_S=2026-10-15T20:30:00Z
p_rerun_join() { # a stalled adversary wrote 2.md and its draft before S; the re-dispatch, a NEW dispatch,
                 # wrote 2.md after it -> MERGED with --rerun, the rerun: line naming the superseded agent
  local d o; d="$(tw)"; WORLD_SHARD="$d/2.md"
  # The draft row is the stalled writer's own and is allowed; it is not a row ON 2.md, so it is not
  # among the superseded rows counted. The stalled writer never reached SubagentStop, so it carries
  # no probe row (HR_NOPROBE=1), which is what the real producer leaves behind.
  HR_NOPROBE=1 HR_AGENT_O=a0000000000stall HR_DID_O=toolu_01StalledAdversary000002 hr_at 2026-10-15T19:59:00Z harness_record "$d/2.md.draft" || return 1
  HR_NOPROBE=1 HR_AGENT_O=a0000000000stall HR_DID_O=toolu_01StalledAdversary000002 hr_at 2026-10-15T20:00:00Z s2 "$d" || return 1
  HR_NOPROBE=1 HR_AGENT_O=a0000000000stall HR_DID_O=toolu_01StalledAdversary000002 hr_at 2026-10-15T20:01:00Z s2 "$d" || return 1
  HR_SPAWN_TS="$RR_S" hr_at 2026-10-15T21:00:00Z s2 "$d" || return 1
  hr_ids "$d/2.md"; o="$(out_of "$d")"
  bash "$1" --rerun "2.md@$RR_S" "$d" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$MO" "superseded=2" && grep -q " 2=$HR_DID " "$o" \
    && grep -qx "rerun: 2.md since $RR_S; superseded: a0000000000stall (2 rows, 2026-10-15T20:00:00Z..2026-10-15T20:01:00Z)" "$o"
}
p_rerun_other() { # graph s318 requirements-p1/cross-2's shape: cross-1's OWN adversary edited shard 2
                  # before S, and a new dispatch wrote it after -> REFUSED; --rerun never acquits a
                  # cross-shard write
  local d c1a c1d; d="$(tw)"; WORLD_SHARD="$d/2.md"
  hr_ids "$d/cross-1.md"; c1a="$HR_AGENT"; c1d="$HR_DID"
  HR_AGENT_O="$c1a" HR_DID_O="$c1d" hr_at 2026-10-15T20:00:00Z s2 "$d" || return 1
  HR_SPAWN_TS="$RR_S" hr_at 2026-10-15T21:00:00Z s2 "$d" || return 1
  bash "$1" --rerun "2.md@$RR_S" "$d" > "$MO" 2>&1; RC=$?
  refused_clean "--rerun 2.md: $c1a is a superseded writer of 2.md and also wrote" "$d" && has "$MO" "cross-1.md at"
}
p_rerun_same() { # the superseded writer writes 2.md again after S, and nobody else does -> REFUSED: the
                 # re-run is a NEW dispatch
  local d; d="$(tw)"; WORLD_SHARD="$d/2.md"
  hr_at 2026-10-15T20:00:00Z s2 "$d" || return 1
  HR_SPAWN_TS="$RR_S" hr_at 2026-10-15T21:00:00Z s2 "$d" || return 1
  hr_ids "$d/2.md"
  bash "$1" --rerun "2.md@$RR_S" "$d" > "$MO" 2>&1; RC=$?
  refused_clean "--rerun 2.md: $HR_AGENT wrote" "$d" && has "$MO" "its writer must not be one of the writers it supersedes"
}
# ---------------------------------------------------------------- BL-536 D1, D2, D4
# Each refusing cell sits beside its MERGED twin one property apart. The discriminating member is
# seeded NOT first: D1's remediator sorts after the stalled adversary among the superseded writers,
# D2's offending row follows the agent's own in-dir row and an unrelated agent's row in another -p
# dir, and D4's shard 2 is the second ordinal the join reaches.
p_rerun_role() { # D1: a REMEDIATOR among the writers --rerun supersedes -> REFUSED as a role violation;
                 # the same world with that writer an adversary MERGES (superseded=2)
  local d role
  for role in remediator adversary; do
    d="$(tw)"; WORLD_SHARD="$d/2.md"
    HR_NOPROBE=1 HR_AGENT_O=a0000000000stall HR_DID_O=toolu_01StalledAdversary000002 hr_at 2026-10-15T20:00:00Z s2 "$d" || return 1
    HR_NOPROBE=1 HR_ROLE="$role" HR_AGENT_O=a000000000zremed HR_DID_O=toolu_01SupersededWriter0000r1 hr_at 2026-10-15T20:05:00Z s2 "$d" || return 1
    HR_SPAWN_TS="$RR_S" hr_at 2026-10-15T21:00:00Z s2 "$d" || return 1
    hr_ids "$d/2.md"
    bash "$1" --rerun "2.md@$RR_S" "$d" > "$MO" 2>&1; RC=$?
    if [ "$role" = remediator ]; then
      refused_clean "carries rows --rerun would supersede from agent a000000000zremed, dispatch toolu_01SupersededWriter0000r1, dispatched as role remediator" "$d" \
        && has "$MO" "a non-adversary write on a shard is a role violation, not a stale dispatch" || return 1
    else
      [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$MO" "superseded=2" && grep -q " 2=$HR_DID " "$(out_of "$d")" || return 1
    fi
  done
}
XP_A=a0000000000xpass; XP_D=toolu_01CrossPassAdversary000
p_xdir() { # D2: shard 2's sole writer also wrote under ANOTHER shards/<x>-p<M>/ dir -> REFUSED, with and
           # without --rerun, and stories-p10 is another dir than stories-p1. Twins: a .draft in this
           # dir, and an UNRELATED agent's row in stories-p10, each MERGE; --rerun without the p2 row MERGES
  local d sh o
  for o in stories-p2/1.md stories-p10/1.md own-draft other-agent-p10; do
    d="$(tw)"; sh="$(dirname "$d")"
    mkdir -p "$sh/stories-p3" "$sh/stories-p2" "$sh/stories-p10" || return 1
    harness_record "$sh/stories-p3/1.md"
    HR_AGENT_O="$XP_A" HR_DID_O="$XP_D" s2 "$d"
    case "$o" in
      own-draft) HR_AGENT_O="$XP_A" HR_DID_O="$XP_D" harness_record "$d/2.md.draft" ;;
      other-agent-p10) harness_record "$sh/stories-p10/1.md" ;;
      *) HR_AGENT_O="$XP_A" HR_DID_O="$XP_D" harness_record "$sh/$o" ;;
    esac
    run_merge "$1" "$d"
    case "$o" in
      own-draft|other-agent-p10) [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && grep -q " 2=$XP_D " "$(out_of "$d")" || return 1 ;;
      *) refused_clean "agent $XP_A wrote in _bmad-output/planning-artifacts/s1/shards/stories-p1/ and also wrote _bmad-output/planning-artifacts/s1/shards/$o at " "$d" \
           && has "$MO" "under another shard dir; one dispatch delivers one shard of one pass" || return 1 ;;
    esac
  done
  for o in refuse merge; do
    d="$(tw)"; sh="$(dirname "$d")"; WORLD_SHARD="$d/2.md"; mkdir -p "$sh/stories-p2" || return 1
    HR_AGENT_O="$XP_A" HR_DID_O="$XP_D" hr_at 2026-10-15T20:00:00Z s2 "$d" || return 1
    [ "$o" = merge ] || { HR_AGENT_O="$XP_A" HR_DID_O="$XP_D" hr_at 2026-10-15T20:01:00Z harness_record "$sh/stories-p2/1.md" || return 1; }
    HR_SPAWN_TS="$RR_S" hr_at 2026-10-15T21:00:00Z s2 "$d" || return 1
    hr_ids "$d/2.md"
    bash "$1" --rerun "2.md@$RR_S" "$d" > "$MO" 2>&1; RC=$?
    if [ "$o" = refuse ]; then
      refused_clean "agent $XP_A wrote in _bmad-output/planning-artifacts/s1/shards/stories-p1/ and also wrote _bmad-output/planning-artifacts/s1/shards/stories-p2/1.md at 2026-10-15T20:01:00Z, under another shard dir" "$d" || return 1
    else
      [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$MO" "superseded=1" && grep -q " 2=$HR_DID " "$(out_of "$d")" || return 1
    fi
  done
}
forge_meta() { # <shard file> <agent id> <toolUseId> -- rewrite that agent's meta file, as a lead Write would
  printf '{"agentType":"adversary","description":"rewritten","toolUseId":"%s","spawnDepth":1}\n' "$3" \
    > "$(dirname "$(hr_state "$1")")/.harness/fx-session/subagents/agent-$2.meta.json"
}
other_spawn() { # <shard dir> -- REAL_OTHER recorded as an adversary dispatch, so a forged meta naming it resolves
  printf '{"v":1,"role":"adversary","tool_use_id":"%s"}\n' "$REAL_OTHER" >> "$(hr_state "$1/2.md")/spawn-ledger.jsonl"
}
p_probe_disagree() { # D4: shard 2's meta file rewritten to another adversary dispatch after its writer
                     # stopped -- the writer an adversary, then a remediator -> each REFUSED 'rewritten';
                     # the unforged twin (same spawn rows) MERGES
  local d role
  d="$(tw)"; s2 "$d"; other_spawn "$d"; run_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && grep -q " 2=$(did_of "$d" 2) " "$(out_of "$d")" || return 1
  for role in adversary remediator; do
    d="$(tw)"; HR_ROLE="$role" s2 "$d"; other_spawn "$d"; hr_ids "$d/2.md"; forge_meta "$d/2.md" "$HR_AGENT" "$REAL_OTHER"
    run_merge "$1" "$d"
    refused_clean "agent $HR_AGENT, whose meta file names dispatch $REAL_OTHER but" "$d" \
      && has "$MO" "records $HR_DID for that agent; the meta file was rewritten after the agent stopped" || return 1
  done
}
p_rerun_residual() { # THE STATED KNOWN GAP (merge header RE-DISPATCH, "RESIDUAL, ACQUITTED"): a writer
                     # --rerun supersedes is held to probe EQUALITY only, so a remediator that never
                     # stopped (no probe row) with its meta rewritten to an adversary dispatch is set
                     # aside and the set MERGES. This cell is the exemption's own probe: it pins exactly
                     # what is acquitted, so a change that widens or closes the gap moves it. Its twin,
                     # one property apart, is the same remediator WITH its probe row (it stopped) ->
                     # REFUSED by the equality the superseded writer is still held to.
  local d probe
  for probe in 0 1; do
    d="$(tw)"; WORLD_SHARD="$d/2.md"; other_spawn "$d"
    HR_NOPROBE="$([ "$probe" = 1 ] && echo 0 || echo 1)" HR_ROLE=remediator HR_AGENT_O=a000000000zremed HR_DID_O=toolu_01SupersededWriter0000r1 \
      hr_at 2026-10-15T20:05:00Z s2 "$d" || return 1
    forge_meta "$d/2.md" a000000000zremed "$REAL_OTHER"
    HR_SPAWN_TS="$RR_S" hr_at 2026-10-15T21:00:00Z s2 "$d" || return 1
    hr_ids "$d/2.md"
    bash "$1" --rerun "2.md@$RR_S" "$d" > "$MO" 2>&1; RC=$?
    if [ "$probe" = 0 ]; then
      [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$MO" "superseded=1" && grep -q " 2=$HR_DID " "$(out_of "$d")" || return 1
    else
      refused_clean "agent a000000000zremed, whose meta file names dispatch $REAL_OTHER but" "$d" \
        && has "$MO" "records toolu_01SupersededWriter0000r1 for that agent; the meta file was rewritten after the agent stopped" || return 1
    fi
  done
}
p_probe_absent() { # D4: shard 2's writer has a meta file and NO probe row -- a legitimate adversary, and a
                   # remediator whose meta is forged to an adversary dispatch -> each REFUSED 'has not
                   # stopped'; the same legitimate world WITH its probe row MERGES
  local d
  d="$(tw)"; s2 "$d"; other_spawn "$d"; run_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && grep -q " 2=$(did_of "$d" 2) " "$(out_of "$d")" || return 1
  d="$(tw)"; HR_NOPROBE=1 s2 "$d"; other_spawn "$d"; hr_ids "$d/2.md"; run_merge "$1" "$d"
  refused_clean "agent $HR_AGENT, whose meta file names dispatch $HR_DID but" "$d" \
    && has "$MO" "has no row for that agent; an adversary that has not stopped has not delivered" || return 1
  d="$(tw)"; HR_ROLE=remediator HR_NOPROBE=1 s2 "$d"; other_spawn "$d"; hr_ids "$d/2.md"; forge_meta "$d/2.md" "$HR_AGENT" "$REAL_OTHER"
  run_merge "$1" "$d"
  refused_clean "agent $HR_AGENT, whose meta file names dispatch $REAL_OTHER but" "$d" \
    && has "$MO" "has no row for that agent; an adversary that has not stopped has not delivered"
}

# ------------------------------------------------ BL-544, BL-554, BL-548 (merge half)
# Every world below is the B3 world seeded the bl536 way (shard -> harness_record), because the
# dispatch-id derivation refuses a shard with no harness record before any of these checks runs.
hdr_world() { # <replacement for the `## Findings` line of shard 2> -> a B3 shard dir, shard 2 holding 0 findings
  local d; d="$(b3_world)" || return 1
  shard "$d" 2 0 EXIT_CONDITION_MET 2
  awk -v r="$1" '$0 == "## Findings" { print r; next } { print }' "$d/2.md" > "$d/2.tmp" && mv "$d/2.tmp" "$d/2.md" || return 1
  printf '%s' "$d"
}
p_hdr() { # BL-544: a finding opened with `## ` is REFUSED wherever it sits -- here in a shard with NO
          # `## Findings` section at all, declaring 0 findings, with no marker (the shape that merged as
          # zero findings). Twins one property apart: `## Notes` merges, and so does the same heading
          # inside a fence.
  local m="$1" d
  d="$(hdr_world '## F-1 (MAJOR) stories: 2')" || return 1; run_merge "$m" "$d"
  refused_clean 'opens a finding with `## `; findings are `### ` headings inside `## Findings`' "$d" && has "$MO" '2.md:3 opens' || return 1
  d="$(hdr_world '## Notes')" || return 1; run_merge "$m" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" || return 1
  d="$(hdr_world '```\n## F-1 (MAJOR) stories: 2\n```')" || return 1; run_merge "$m" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:"
}
p_draft() { # BL-554: `<valid shard name>.draft` beside its shard is skipped with a NOTE on stderr and never
            # merged; `notes.md` and a draft of a name that is no shard still REFUSE
  local m="$1" d o
  d="$(b3_world)"; o="$(out_of "$d")"; printf 'UNFINISHED-DRAFT-BODY\n' > "$d/2.md.draft"
  bash "$m" "$d" > "$MO" 2> "$MO.err"; RC=$?
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$MO.err" "NOTE: ignored draft 2.md.draft" \
    && [ -f "$o" ] && ! has "$o" "UNFINISHED-DRAFT-BODY" || return 1
  d="$(b3_world)"; printf 'x\n' > "$d/notes.md"; run_merge "$m" "$d"
  refused_clean "notes.md is not a shard name" "$d" || return 1
  d="$(b3_world)"; printf 'x\n' > "$d/notes.md.draft"; run_merge "$m" "$d"
  refused_clean "notes.md.draft is not a shard name" "$d" || return 1
  d="$(b3_world)"; printf 'x\n' > "$d/cross-9.md.draft"; run_merge "$m" "$d"
  refused_clean "cross-9.md.draft is a draft of cross-9, which is no shard of this set" "$d"
}
dry_merge() { # <merge> <shard dir> -> RC, $MO (stdout and stderr)
  bash "$1" --dry-run "$2" > "$MO" 2>&1; RC=$?
}
p_dry() { # BL-548: --dry-run prints every refusal of the first failing phase, writes nothing. Two shards each
          # cite another story (4 findings, 4 refusals): all four printed, exit 2, no output file. The clean
          # twin prints DRY-RUN: clean, exits 0, writes nothing -- and the same set then merges for real.
  local m="$1" d o n
  d="$(b3_world)"; o="$(out_of "$d")"
  shard "$d" 2 2 EXIT_CONDITION_MET 1; shard "$d" 3 2 EXIT_CONDITION_MET 1
  dry_merge "$m" "$d"
  n="$(grep -c '^REFUSED: ' "$MO")" || n=0
  [ "$RC" -eq 2 ] && [ "$n" -eq 4 ] && has "$MO" "(shard 2) cites 1; a per-ordinal shard" && has "$MO" "(shard 3) cites 1; a per-ordinal shard" \
    && [ ! -e "$o" ] || return 1
  d="$(b3_world)"; o="$(out_of "$d")"
  dry_merge "$m" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "DRY-RUN: clean" && [ ! -e "$o" ] || return 1
  run_merge "$m" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ]
}
p_dry_barrier() { # BL-548: the phases are barriers. Shard 1 missing (phase 2) beside a finding refusal in shard 2
                  # (phase 5) prints exactly the missing-shard line, and reads no stdin. Stdin is a regular FILE
                  # of POISON in the shard grammar (a provenance block whose verdict is the token): a stage that
                  # was handed the absent shard's empty path and fell back to stdin would parse it and print the
                  # token in its verdict refusal. No clock, no fifo: the arm turns on output, never on timing.
  local m="$1" d pz tok=ZZQPOISON
  pz="$(mktemp "$WORK/poison.XXXXXX")" || return 1
  printf '## Findings\n\n### F-1 (MAJOR) %s\n\nstories: 1\n\n<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: %s\nverdict: %s\nfindings_critical: 0\nfindings_major: 0\nSKILL_INVOCATION_PROVENANCE_END -->\n' "$tok" "$tok" "$tok" > "$pz"
  # CONTROL, in the same predicate: the poison, delivered as shard 1 with a harness record, is parsed by the
  # very stage under test and its verdict refusal prints the token -- so the poison is in that stage's grammar.
  d="$(b3_world)"; cp "$pz" "$d/1.md"; harness_record "$d/1.md"; run_merge "$m" "$d"
  [ "$RC" -eq 2 ] && has "$MO" "declares verdict '$tok'" || return 1
  d="$(b3_world)"; rm -f "$d/1.md"; shard "$d" 2 2 EXIT_CONDITION_MET 1
  bash "$m" --dry-run "$d" > "$MO" 2>&1 < "$pz"; RC=$?
  [ "$RC" -eq 2 ] && [ "$(grep -c . "$MO")" -eq 1 ] && has "$MO" "REFUSED: shard 1 is missing from" && ! has "$MO" "cites" && ! has "$MO" "$tok"
}

# ------------------------------------------------------------ BL-596, BL-597, BL-598
# Each refusal beside its MERGED twin one property apart.
TREE_WT=".claude/worktrees/wt1"
p_tree() { # BL-596: shard 2's only row is its adversary's write to a WORKTREE's copy of it -> REFUSED
           # 'not this tree'; the same write spelled through a symlink alias of THIS tree MERGES, and a
           # ledger whose rows carry no root (written before the field) MERGES as this tree's
  local d root st al led
  d="$(tw)"; root="$(dirname "$(hr_state "$d/2.md")")"
  HR_OFF=1 s2 "$d"
  HR_FP_O="$root/$TREE_WT/${d#"$root"/}/2.md" harness_record "$d/2.md"
  run_merge "$1" "$d"
  refused_clean "not this tree" "$d" && has "$MO" "/$TREE_WT" || return 1
  d="$(tw)"; root="$(dirname "$(hr_state "$d/2.md")")"; al="$(dirname "$root")/alias-${root##*/}"
  ln -s "$root" "$al" || return 1
  HR_OFF=1 s2 "$d"
  HR_FP_O="$al/${d#"$root"/}/2.md" harness_record "$d/2.md"
  run_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && grep -q " 2=$(did_of "$d" 2) " "$(out_of "$d")" || return 1
  d="$(tw)"; s2 "$d"; st="$(hr_state "$d/2.md")"; led="$st/planning-artifacts/.artifact-writes.jsonl"
  [ "$(grep -c '"root":' "$led")" -gt 0 ] || return 1
  jq -c 'del(.root)' "$led" > "$led.tmp" && mv "$led.tmp" "$led" || return 1
  [ "$(grep -c '"root":' "$led")" -eq 0 ] || return 1
  run_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:"
}
CALL_OTHER=call_ffffffffffffffffffffffffffffffff   # real-shaped under a local-model lead; no world's derived id
p_tuid_call() { # BL-597: every dispatch id in a local-model lead's `call_` shape -> MERGED with the derived
                # call_ ids; a real-shaped call_ self id that differs -> REFUSED, as a toolu_ one is
  local HR_IDFORM=call d o want k
  d="$(b3_world)"; o="$(out_of "$d")"
  run_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" || return 1
  want=""; for k in 1 2 3 cross-1 cross-2 cross-3; do want="$want $k=$(did_of "$d" "$k")"; done
  case "$want" in *=call_*) ;; *) return 1 ;; esac
  [ "$(sed -n 's/^shard_tool_use_ids://p' "$o")" = "$want" ] || return 1
  d="$(tw)"; SELF_ID="$CALL_OTHER" s2 "$d"; run_merge "$1" "$d"
  refused_clean "self-reports tool_use_id $CALL_OTHER, but the harness records derive" "$d"
}
p_rerun_bind() { # BL-598: the re-run start binds to the credited dispatch's recorded time. A normal round
                 # re-run from 1999-01-01T00:00:00Z -> REFUSED past BACKDATE_TOL_S; 45 s after the
                 # recorded time -> MERGED, superseded: none (a tolerance, never exact equality)
  local d
  d="$(tw)"; HR_SPAWN_TS="$RR_S" s2 "$d"
  bash "$1" --rerun "2.md@1999-01-01T00:00:00Z" "$d" > "$MO" 2>&1; RC=$?
  refused_clean "past BACKDATE_TOL_S=60" "$d" && has "$MO" "never a typed time" || return 1
  d="$(tw)"; HR_SPAWN_TS="$RR_S" s2 "$d"
  bash "$1" --rerun "2.md@2026-10-15T20:30:45Z" "$d" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && grep -qx "rerun: 2.md since 2026-10-15T20:30:45Z; superseded: none" "$(out_of "$d")"
}

# ------------------------------------------------ BL-660: one fence grammar
# A fence OPENS on a run of 3+ backticks whose info string carries no backtick, or on 3+ tildes, and
# CLOSES only on a bare run of its own character. fence_world <shard-2 replacement for the `## Findings`
# line> <findings_major> -> a B3 shard dir whose shard 2 carries that text and declares that many MAJOR.
fence_world() {
  local d; d="$(hdr_world "$1")" || return 1
  sed "s/^findings_major: .*/findings_major: $2/" "$d/2.md" > "$d/2.tmp" && mv "$d/2.tmp" "$d/2.md" || return 1
  printf '%s' "$d"
}
FW_M1='### M1 — MAJOR — first\n\nstories: 2\n'
FW_M2='### M2 — MAJOR — second\n\nstories: 2\n'
p_fence_prose() { # the filed instance: a prose line opening with three backticks and carrying a backtick in its
                  # text opens nothing, so M1 (between it and the real block) and M2 (after) both count
  local d
  d="$(fence_world "## Findings\n\n\`\`\`derived fence that \`x\` treats data == null as idle\n\n$FW_M1\n\`\`\`derived\n\$ echo hi\n\`\`\`\n\n$FW_M2" 2)" || return 1
  run_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$MO" "major=6"
}
p_fence_unclosed() { # a genuinely unclosed fence still hides the finding after it, so the declared 1 disagrees with 0
  local d
  d="$(fence_world "## Findings\n\n\`\`\`text\n$FW_M1" 1)" || return 1
  run_merge "$1" "$d"
  refused_clean "Findings section heads 0" "$d"
}
p_fence_tilde() { # a ``` fence holding a ~~~~^^^ line closes only on its own ``` line, so M1 inside it stays hidden
                  # (declared 0, merged major=4); the loose closer would end the fence there and count M1
  local d
  d="$(fence_world "## Findings\n\n\`\`\`text\n~~~~^^^\n$FW_M1\n\`\`\`" 0)" || return 1
  run_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$MO" "major=4"
}
p_fence_four() { # a four-backtick opener with an info string opens a fence, and its bare closer closes it
  local d
  d="$(fence_world "## Findings\n\n\`\`\`\`text\n$FW_M1\n\`\`\`\`\n\n$FW_M2" 1)" || return 1
  run_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$MO" "major=5"
}
p_fence_sameset() { # same_set: cross-2 duplicates the set cross-1 (its owner) carries. The owner's shard opens with a
                    # prose ``` line; the refusal must read the same with and without it
  local d i
  for i in plain prose; do
    d="$(doc_b3_world)" || return 1
    dshard "$d" cross-1 1 EXIT_CONDITION_MET "1, 2"; dshard "$d" cross-2 1 EXIT_CONDITION_MET "1, 2"
    if [ "$i" = prose ]; then
      awk '{ print } $0 == "## Findings" { print ""; print "```derived fence that `x` treats data == null as idle" }' "$d/cross-1.md" > "$d/cross-1.tmp" && mv "$d/cross-1.tmp" "$d/cross-1.md" || return 1
    fi
    run_doc_merge "$1" "$d"
    doc_refused_clean "a finding owned by cross-1" "$d" || return 1
  done
}
# A fence closes only on a run of its own character AT LEAST AS LONG as its opener's. The inner block
# opens with an info string, so a reader that closes on any bare run ends the outer fence at the inner
# bare ``` and then opens a phantom fence at the real ```` closer; a bare inner opener would hide M1
# under both readers and discriminate nothing.
FW_NEST='````md\n```text\nquoted\n```\n'
p_fence_nested() { # count: a ```` fence holding a ``` block, then M1, then the ```` closer -- M1 is hidden, so
                   # declared 0 merges (major=4) and declared 1 is REFUSED on the count
  local d
  d="$(fence_world "## Findings\n\n$FW_NEST$FW_M1\n\`\`\`\`" 0)" || return 1
  run_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$MO" "major=4" || return 1
  d="$(fence_world "## Findings\n\n$FW_NEST$FW_M1\n\`\`\`\`" 1)" || return 1
  run_merge "$1" "$d"
  refused_clean "Findings section heads 0" "$d"
}
p_fence_nested_set() { # same_set: the owner cross-1 opens its ## Findings with a ```` fence holding a ``` block,
                       # its finding AFTER the ```` closer; cross-2 duplicates its set -> REFUSED as cross-1's
  local d
  d="$(doc_b3_world)" || return 1
  dshard "$d" cross-1 1 EXIT_CONDITION_MET "1, 2"; dshard "$d" cross-2 1 EXIT_CONDITION_MET "1, 2"
  awk '{ print } $0 == "## Findings" { print ""; print "````md"; print "```text"; print "quoted"; print "```"; print "````" }' \
    "$d/cross-1.md" > "$d/cross-1.tmp" && mv "$d/cross-1.tmp" "$d/cross-1.md" || return 1
  run_doc_merge "$1" "$d"
  doc_refused_clean "a finding owned by cross-1" "$d"
}

# ------------------------------------------------ BL-664: a trailing ` #` comment is stripped
# The schema's parser.comments rule, as validate-provenance-block.sh spells it: whitespace, `#`, the
# rest of the line. hc_comment <shard file> -- every provenance value of the shard gets a trailing
# comment, the way a verbatim copy of the adversary template's region carries them. The file is
# rewritten in place after shard() wrote it; the harness identity is keyed on dir and name, so the
# write-ledger row still credits it.
hc_comment() {
  awk '/SKILL_INVOCATION_PROVENANCE v1/ { b = 1; print; next } /SKILL_INVOCATION_PROVENANCE_END/ { b = 0 }
       b && /^[a-z_]+:/ { print $0 " # copied with the template comment"; next } { print }' "$1" > "$1.hc" && mv "$1.hc" "$1"
}
p_hdr_comment() { # (a) --check-header on a convergence shard whose every value carries a ` #` comment -> exit 0;
                  # (b) the same on the elicitation axis; (c) a full merge with such a shard is byte-identical to
                  # the files-mode golden (no comment reaches a merged value); (d) `findings_major: 2#x` -- no
                  # whitespace before `#` -- is still refused as non-integer
  local m="$1" d o c
  d="$(b3_world)" || return 1; o="$(out_of "$d")"; c="$(dirname "$d")/hc"; mkdir -p "$c" || return 1
  cp "$d/1.md" "$c/conv.md"; hc_comment "$c/conv.md"
  grep -qx 'findings_major: 2 # copied with the template comment' "$c/conv.md" \
    && grep -qx 'verdict: EXIT_CONDITION_MET # copied with the template comment' "$c/conv.md" || return 1
  bash "$m" --check-header "$c/conv.md" --axis convergence > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && [ ! -s "$MO" ] || return 1
  sed 's/^skill: .*/skill: bmad-advanced-elicitation/;/^verdict:/d' "$d/1.md" > "$c/elic.md"; hc_comment "$c/elic.md"
  grep -qx 'skill: bmad-advanced-elicitation # copied with the template comment' "$c/elic.md" || return 1
  bash "$m" --check-header "$c/elic.md" --axis elicitation > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && [ ! -s "$MO" ] || return 1
  hc_comment "$d/1.md"; run_merge "$m" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && cmp -s "$o" "$SEED_DIR/seed.files-b3-merged.expected" || return 1
  sed 's/^findings_major: .*/findings_major: 2#x/' "$c/conv.md" > "$c/tight.md"
  bash "$m" --check-header "$c/tight.md" --axis convergence > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 1 ] && has "$MO" "does not declare integer findings_critical and findings_major"
}

# ------------------------------------------------ BL-670: the merge stamps the SUMMED divergence
# sd_world <pass> -> the shard dir s1/shards/stories-p<pass>/ of a world whose shards 1 and 2 each hold
# one CRITICAL in prior scope (prior_scope 1, summed 2), shard 3 and the cross shards clean, every shard
# stamped NOT_MET -- so no shard declares the divergence. Built through new_world and shard(); the
# CRITICAL is added after shard() wrote the file (identity is keyed on dir and name, no seal rows here).
# Earlier pass files are written into s1/ only AFTER the world is built (sd_prev).
sd_crit() { # <shard file> <ordinal>
  awk -v o="$2" '{ print } $0 == "## Findings" { print ""; print "### C1 — CRITICAL — summed divergence probe"; print ""; print "stories: " o }' "$1" \
    | sed 's/^findings_critical: 0$/findings_critical: 1/; s/^findings_critical_prior_scope: 0$/findings_critical_prior_scope: 1/' > "$1.sd" && mv "$1.sd" "$1"
}
sd_world() {
  local p="$1" w d x; w="$(new_world)" || return 1
  d="$(dirname "$w")/stories-p$p"; mkdir -p "$d" || return 1
  shard "$d" 1 0 EXIT_CONDITION_NOT_MET 1; sd_crit "$d/1.md" 1
  shard "$d" 2 0 EXIT_CONDITION_NOT_MET 2; sd_crit "$d/2.md" 2
  shard "$d" 3 0 EXIT_CONDITION_NOT_MET 3
  for x in $(xkeys 3); do shard "$d" "$x" 0 EXIT_CONDITION_NOT_MET "1, 3"; done
  grep -qx 'findings_critical_prior_scope: 1' "$d/2.md" || return 1
  printf '%s' "$d"
}
sd_s1() { printf '%s' "$(dirname "$(dirname "$(dirname "$1")")")/s1"; }    # <shard dir> -> s1/
sd_out() { printf '%s/stories-adversarial-p%s.md' "$(sd_s1 "$1")" "${1##*-p}"; }
sd_prev() { # <shard dir> <basename> <findings_critical | NONE | <first>/<second> (two blocks)>
  local f; f="$(sd_s1 "$1")/$2"
  blk() { printf '<!-- SKILL_INVOCATION_PROVENANCE v1\nskill: ai-dlc-adversary-review\nfindings_critical: %s\nfindings_major: 0\nverdict: EXIT_CONDITION_NOT_MET\nSKILL_INVOCATION_PROVENANCE_END -->\n' "$1"; }
  { printf '# stories -- adversarial pass (earlier)\n\n'
    case "$3" in NONE) printf 'No provenance block.\n' ;; */*) blk "${3%/*}"; printf '\n'; blk "${3#*/}" ;; *) blk "$3" ;; esac; } > "$f"
}
SD_LINE='DIVERGENT_HARD_BLOCK stamped by: summed findings_critical_prior_scope 2 > stories-adversarial-p1.md findings_critical 1.'
sd_stamped() { # <merge> <shard dir> -> 0 when merged DIVERGENT naming p1's count 1
  run_merge "$1" "$2"
  [ "$RC" -eq 0 ] && has "$MO" "verdict=DIVERGENT_HARD_BLOCK" && grep -qx 'verdict: DIVERGENT_HARD_BLOCK' "$(sd_out "$2")" \
    && grep -qxF "$SD_LINE" "$(sd_out "$2")"
}
sd_plain() { # <merge> <shard dir> -> 0 when merged NOT_MET, unstamped, no stamp line
  run_merge "$1" "$2"
  [ "$RC" -eq 0 ] && has "$MO" "verdict=EXIT_CONDITION_NOT_MET" && ! grep -q 'DIVERGENT_HARD_BLOCK' "$(sd_out "$2")"
}
p_sum_divergent() { # (a) summed prior 2 over p1's 1 CRITICAL -> DIVERGENT, the line naming p1; (b) over p1's 2 -> NOT
                    # divergent (kills >=); (c) pass 1, no earlier pass -> not divergent; (d) merging p3 with p2
                    # absent compares with p1; (e1) a two-block p1 stamps on the FIRST block's 1 (its second says 9);
                    # (e2) a block-less p2 is skipped and p3 compares with p1
  local m="$1" d
  d="$(sd_world 2)" || return 1; sd_prev "$d" stories-adversarial-p1.md 1; sd_stamped "$m" "$d" || return 1
  d="$(sd_world 2)" || return 1; sd_prev "$d" stories-adversarial-p1.md 2; sd_plain "$m" "$d" || return 1
  d="$(sd_world 1)" || return 1; sd_plain "$m" "$d" || return 1
  d="$(sd_world 3)" || return 1; sd_prev "$d" stories-adversarial-p1.md 1; sd_stamped "$m" "$d" || return 1
  d="$(sd_world 2)" || return 1; sd_prev "$d" stories-adversarial-p1.md 1/9; sd_stamped "$m" "$d" || return 1
  d="$(sd_world 3)" || return 1; sd_prev "$d" stories-adversarial-p1.md 1; sd_prev "$d" stories-adversarial-p2.md NONE
  sd_stamped "$m" "$d" || return 1
  # (f) a shard that itself declares DIVERGENT_HARD_BLOCK: the merge prints its shard-declared line
  d="$(sd_world 1)" || return 1; shard "$d" 3 0 DIVERGENT_HARD_BLOCK 3
  run_merge "$m" "$d"
  [ "$RC" -eq 0 ] && grep -qxF 'DIVERGENT_HARD_BLOCK stamped by: shard-declared.' "$(sd_out "$d")"
}
# (g) the merge restates the validator's --series exclusion line; a validator copy whose line drifted is REFUSED
p_sum_excl_drift() {
  local m="$1" sd d
  sd="$(mktemp -d "$WORK/excl.XXXXXX")" || return 1
  cp "$m" "$sd/merge-adversarial-shards.sh"
  sed 's/\*-repair-p\*|\*-repair-\*) continue/*-repair-*) continue/' "$(dirname "$m")/validate-adversarial-convergence.sh" > "$sd/validate-adversarial-convergence.sh"
  cp "$(dirname "$m")/validate-steering-budget.sh" "$sd/" 2>/dev/null
  cp "$(dirname "$m")/partition-document.sh" "$sd/" || return 1
  cmp -s "$(dirname "$m")/validate-adversarial-convergence.sh" "$sd/validate-adversarial-convergence.sh" && return 2
  d="$(sd_world 2)" || return 1; sd_prev "$d" stories-adversarial-p1.md 1
  run_merge "$sd/merge-adversarial-shards.sh" "$d"
  [ "$RC" -eq 2 ] && has "$MO" "series exclusion line"
}
# THE ORACLE: each series is
# merged, its merged pass's verdict reset to NOT_MET in a scratch copy (the unstamped twin), and
# validate-adversarial-convergence.sh --series run over it. Arm C must fire on the twin iff the merge
# stamped. One `-pass<N>` predecessor and one zero-padded `-p02` exercise the series grammar the merge
# extracts. Seeds carry no ` #` comments.
sd_oracle() { # <merge> <pass> <name:crit>... -> 0 when stamp and arm C agree; OR_ST / OR_C set
  local m="$1" p="$2" d o t n c; shift 2
  d="$(sd_world "$p")" || return 1
  for c in "$@"; do sd_prev "$d" "${c%%:*}" "${c#*:}"; done
  run_merge "$m" "$d"; [ "$RC" -eq 0 ] || return 1
  o="$(sd_out "$d")"; OR_ST=0; grep -qx 'verdict: DIVERGENT_HARD_BLOCK' "$o" && OR_ST=1
  t="$(mktemp -d "$WORK/or.XXXXXX")" || return 1
  cp "$(sd_s1 "$d")"/stories-adversarial-p* "$t/" || return 1
  sed 's/^verdict: DIVERGENT_HARD_BLOCK$/verdict: EXIT_CONDITION_NOT_MET/' "$o" > "$t/$(basename "$o")"
  n="$(ls "$t" | grep -c .)" || n=0
  bash "$(dirname "$m")/validate-adversarial-convergence.sh" --series "$t/stories-adversarial-p" > "$CO" 2>&1
  has "$CO" "adversarial convergence -- $n pass artifact(s)" || return 1
  OR_C=0; has "$CO" "FAIL (C -- DIVERGENCE)" && OR_C=1
  [ "$OR_ST" = "$OR_C" ]
}
p_sum_divergent_oracle() {
  local m="$1"
  sd_oracle "$m" 2 stories-adversarial-pass1.md:1 && [ "$OR_ST" = 1 ] || return 1
  sd_oracle "$m" 3 stories-adversarial-p02.md:2 && [ "$OR_ST" = 0 ] || return 1
  sd_oracle "$m" 3 stories-adversarial-p02.md:1 && [ "$OR_ST" = 1 ] || return 1
  sd_oracle "$m" 2 stories-adversarial-p1.md:1/9 && [ "$OR_ST" = 1 ] || return 1
  sd_oracle "$m" 3 stories-adversarial-p1.md:1 stories-adversarial-p2.md:NONE && [ "$OR_ST" = 1 ]
}


