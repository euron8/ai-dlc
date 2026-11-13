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
# The provenance schema, found by walking UP in either layout. pb_merged pins every merge copy to it.
KSCH=""
_d="$LIB_DIR"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _c in "$_d/core/schemas/provenance-block.json" "$_d/.claude/schemas/provenance-block.json"; do
    [ -f "$_c" ] && { KSCH="$_c"; break 2; }
  done
  _d="$(dirname "$_d")"
done
CONV="$SRCDIR/validate-adversarial-convergence.sh"
[ -f "$CONV" ] || { echo "FIXTURE ERROR: $CONV is not beside the merge; it reads its ceilings from there" >&2; exit 2; }
# Section mode reads its ordinal set from this sibling. Absent, the D arms would all refuse for
# THAT reason and the refusal arms would read as passing -- so its absence is an error, never a skip.
PARTITION="$SRCDIR/partition-document.sh"
[ -f "$PARTITION" ] || { echo "FIXTURE ERROR: $PARTITION is not beside the merge; section mode reads its --map" >&2; exit 2; }
# Every merge reads BACKDATE_TOL_S from this sibling. Absent, every merge would refuse for THAT reason.
[ -f "$SRCDIR/validate-artifact-budget.sh" ] || { echo "FIXTURE ERROR: $SRCDIR/validate-artifact-budget.sh is not beside the merge; every merge reads its tolerance there" >&2; exit 2; }
for _s in seed.192-ff-A-token-decimal-resolution.md seed.bug-192-il-accuracy.md \
          seed.story-1-rebalancer-il-accuracy.md seed.finding-headings.txt \
          seed.doc-test-strategy.md seed.doc-serial-epics.md seed.files-b3-merged.expected; do
  [ -s "$SEED_DIR/$_s" ] || { echo "FIXTURE ERROR: seed $SEED_DIR/$_s is missing or empty" >&2; exit 2; }
done
echo "$NAME: resolved subject = $MERGE"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/$NAME.XXXXXX")" || exit 2
WC_ROOT="$WORK" # the world cache's root (wc_get); unlike WORK, nothing rebinds it
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
  legacy_roles "$w" || return 1
  printf '%s' "$pa/s1/shards/stories-p1"
}
# THE LEGACY WINDOW (BL-750; content-seal.sh header "THE MARKER ADMISSION"). Every arm here appends a
# BARE `seat-complete:` line to shards in the sealed set, which the merge admits only while the world's
# installed adversary role file still carries the pre-`--mark` fallback. Each world gets that file, with
# the retired sentence process-rule-pins pins out of the shipped role files, so these arms keep reading
# the header and count checks they were written for; content-seal/merge-arms.sh owns the admission arms.
legacy_roles() { # <world root>
  mkdir -p "$1/.claude/team-roles" || return 1
  printf 'Close the shard with `scripts/ai-dlc/wait-for-deliverable.sh --mark <shard path> <step> adversary <shard> findings=<n>`.\nIf that call fails with `unknown arg: --mark`, append the bare line `seat-complete: <step> <seat> <shard> findings=<n>` instead.\n' \
    > "$1/.claude/team-roles/adversary.md"
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
#   HR_SPAWN_TS=<iso>  the spawn row's `ts`, the dispatch's recorded time (default 2026-08-24T15:00:00Z,
#                      at or before every default shard stamp, so the merge's invoked_at bound holds)
#   HR_BOUND=0    the spawn row carries no `invoked_bound` key (an older guard's row: the merge's
#                 invoked_at bound WARNs as LEGACY instead of refusing); by default it carries true
#   HR_BOUND_V=<json>  the key's raw JSON value when present (default true; `false` and `"true"` are LEGACY)
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
  [ "${HR_NOSPAWN:-0}" = 1 ] || printf '{"v":1,"ts":"%s","sprint":1,"name":null,"role":"%s","model_pinned":"opus","tier_pinned":null,"model_requested":"opus","model_bound":"definition","effort_bound":null,"role_contract_cited":true,"contract_via":"definition","role_file_readable":true,"definition_bound":true,"definition_stale":false,"name_stripped":null,"tool_use_id":"%s","shard":null%s}\n' \
    "${HR_SPAWN_TS:-2026-08-24T15:00:00Z}" "$role" "$HR_DID" "$([ "${HR_BOUND:-1}" = 0 ] || printf ',"invoked_bound":%s' "${HR_BOUND_V:-true}")" >> "$st/spawn-ledger.jsonl"
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
    # ONE --map per world, not one per shard: a world's stories never change once its first shard is written.
    if [ "${OMAP_D:-}" != "$d" ]; then OMAP_V="$($ASM_RUN "$MERGE" --map "$d")"; OMAP_D="$d"; fi
    b="$(printf '%s\n' "$OMAP_V" | awk -F'\t' -v k="$k" '$1 + 0 == k + 0 { print $2 }')"
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

# ---------------------------------------------------------------- one build per world shape
# wc_get <key> <builder> [args] -> the shard dir of a fresh world of that shape. With ASM_WCACHE=1 (run.sh sets
# it) the builder runs ONCE per key; every later call copies the pristine copy kept under $WORK/wcache to a new
# mktemp dir of the same prefix and rewrites the one thing that names the old root: the absolute path the hook
# recorded in the write ledger (root, transcript_path), logical and physical spellings alike, both ending in the
# world dir's own name. Identity (hr_ids) is a function of the shard dir and file name alone, so every id, sha and
# golden byte is the one a fresh build writes. A call under any harness-record knob (HR_*, SELF_ID) builds afresh.
# The cache and every copy of it live under WC_ROOT, the WORK this file created, never under a later rebinding of
# WORK: a --matrix worker (run.sh mx_enqueue) rebinds WORK to its own dir and still copies the parent's pristine
# worlds, each copy a sibling of the template's original dir, so the one-name rewrite below stays exact. A worker
# that misses the cache builds afresh and caches nothing, so no two workers ever write one template.
WC_KNOBS="HR_OFF HR_ROLE HR_AGENT_O HR_DID_O HR_NOMETA HR_NOSPAWN HR_PRE HR_NOPROBE HR_PROBE HR_SESSION SELF_ID HR_IDFORM HR_SPAWN_TS HR_BOUND HR_BOUND_V HR_FP_O"
wc_get() {
  local key="$1" t d rel old nr f v; shift
  if [ "${ASM_WCACHE:-0}" != 1 ]; then "$@"; return; fi
  for v in $WC_KNOBS; do [ -z "${!v:-}" ] || { "$@"; return; }; done
  t="$WC_ROOT/wcache/$key"
  if [ ! -f "$t.rel" ]; then
    [ -z "${MX_WORKER:-}" ] || { "$@"; return; }
    mkdir -p "$WORK/wcache" || return 1
    d="$("$@")" || return 1
    case "$d" in "$WORK"/*/*) ;; *) return 1 ;; esac
    rel="${d#"$WORK"/}"; old="${rel%%/*}"
    cp -Rp "$WORK/$old" "$t.tpl" || return 1
    printf '%s' "$old" > "$t.old"; printf '%s' "${rel#*/}" > "$t.rel"
    printf '%s' "$d"; return 0
  fi
  old="$(cat "$t.old")"; rel="$(cat "$t.rel")"
  nr="$(mktemp -d "$WC_ROOT/${old%.*}.XXXXXX")" || return 1
  cp -Rp "$t.tpl/." "$nr/" || return 1
  for f in $(grep -rlF -- "/$old" "$nr" 2>/dev/null); do
    O="/$old" N="/${nr##*/}" perl -pi -e 's/\Q$ENV{O}\E/$ENV{N}/g' "$f" || return 1
  done
  printf '%s' "$nr/$rel"
}

# The B3 input: three ordinal shards, 2 MAJOR each, each stamped MET; clean cross shards, one per
# group of `--cross-groups 3` (cross-1..3).
b3_world() { wc_get b3 b3_world_build; }
clean_world() { wc_get clean clean_world_build; }
b3_world_build() {
  local d x; d="$(new_world)"
  shard "$d" 1 2 EXIT_CONDITION_MET 1
  shard "$d" 2 2 EXIT_CONDITION_MET 2
  shard "$d" 3 2 EXIT_CONDITION_MET 3
  for x in $(xkeys 3); do shard "$d" "$x" 0 EXIT_CONDITION_MET "1, 3"; done
  printf '%s' "$d"
}
# The clean set: 1 MAJOR per ordinal shard (sum 3, AT the ceiling), clean cross shards -- and
# every shard stamped NOT_MET, the mirror of B3.
clean_world_build() {
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
# merges too (BL-811, the dispatched shape); a partial cross-<g> set refuses; a finding duplicated
# into a non-owner group refuses; and K=2 with cross.md merges.
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
    files) $ASM_RUN "$1" "$3" > "$MO" 2>&1; RC=$? ;;
    document) $ASM_RUN "$1" --document "$(doc_of "$3")" "$3" > "$MO" 2>&1; RC=$? ;;
    elicit) $ASM_RUN "$1" --subject 9 --elicitation "$3" > "$MO" 2>&1; RC=$? ;;
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
    files) $ASM_RUN "$MERGE" --map "$2" | grep -c . ;;
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
  # THE LONE CROSS (BL-811): one cross.md in place of the groups at K=8 is the dispatched shape and
  # MERGES -- titled K+1 shards, the per-unit bodies first and the one cross body last under the
  # group-less header, tool_use_id the lone cross's derived id and its id keyed `cross=`, never `cross-`.
  local lo lx lh lp
  d="$(xworld "$mode" 8)"; xset "$mode" "$d" "$K" single; xmerge "$m" "$mode" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" || return 1
  case "$mode" in
    files) lo="$(out_of "$d")"; lh="## Shard: cross-story"; lp="## Shard: story $K" ;;
    document) lo="$(doc_out_of "$d")"; lh="## Shard: cross-section"; lp="## Shard: section $K" ;;
    elicit) lo="$(dirname "$(dirname "$d")")/requirements-elicitation.md"; lh="## Shard: cross-part"; lp="## Shard: part $K" ;;
  esac
  lx="$(grep -nx -- "$lh" "$lo" | cut -d: -f1)"; lp="$(grep -nx -- "$lp" "$lo" | cut -d: -f1)"
  [ -n "$lx" ] && [ -n "$lp" ] && [ "$lp" -lt "$lx" ] && ! grep -q '^## Shard: cross-[a-z]* group ' "$lo" \
    && grep -qF "(merged from $((K + 1)) shards)" "$lo" && grep -qx "tool_use_id: $(did_of "$d" cross)" "$lo" \
    && grep -q '^shard_tool_use_ids:.* cross=' "$lo" && ! grep -q '^shard_tool_use_ids:.* cross-[0-9]' "$lo" || return 1
  # A partial grouped set (cross-6 missing) is refused by name, never read as some other shape.
  d="$(xworld "$mode" 8)"; xset "$mode" "$d" "$K" groups; rm -f "$d/cross-6.md"; xmerge "$m" "$mode" "$d"
  [ "$RC" -eq 2 ] && has "$MO" "shard cross-6 is missing from" || return 1
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
# mx <merge file> <args...> -- the merge asked IN PROCESS: in one subshell, every fixture function and every
# unexported fixture variable is dropped (a caller's local would otherwise fill one of the merge's own reads),
# pipefail goes back off as the CLI runs it, the merge file is sourced (its BASH_SOURCE guard stops before
# merge_main) and merge_main is called with the arguments the CLI takes. Its `exit` ends the subshell, and the
# EXIT trap it sets is the subshell's own. Exported variables and prefix assignments (AI_DLC_PROJECT_ROOT=,
# PATH=) reach it as they reach the CLI; redirections stay at the call site. Every arm drives the merge
# through ASM_RUN, `bash` (the CLI, the default and content-seal/merge-arms.sh's) or `mx` (run.sh sets it).
ASM_RUN="${ASM_RUN:-bash}"
mx() {
  ( set +o pipefail +u
    _mx_keep='^(BASH.*|IFS|OPTIND|OPTERR|LINENO|RANDOM|SRANDOM|SECONDS|EPOCH.*|PIPESTATUS|FUNCNAME|GROUPS|EUID|UID|PPID|SHELLOPTS|HOSTNAME|HOSTTYPE|MACHTYPE|OSTYPE|DIRSTACK|PS[0-9]|SHLVL|PWD|OLDPWD|HOME|PATH|TMPDIR|_mx_.*)$'
    _mx_exp=" $(compgen -e | tr '\n' ' ') "
    for _mx_i in 1 2 3 4 5 6 7 8; do # a caller's local, unset, uncovers the caller's caller's binding: repeat
      _mx_n=0
      for _mx_v in $(compgen -v); do
        [[ $_mx_v =~ $_mx_keep ]] && continue
        case "$_mx_exp" in *" $_mx_v "*) continue ;; esac
        unset "$_mx_v" 2>/dev/null && _mx_n=$((_mx_n + 1))
      done
      [ "$_mx_n" -eq 0 ] && break
    done
    for _mx_v in $(compgen -A function); do [ "$_mx_v" = mx ] || unset -f "$_mx_v"; done
    unset _mx_keep _mx_exp _mx_i _mx_n _mx_v
    . "$1" || exit 90
    # MX_HOOK (exported, so the sweep above keeps it): code eval'd after the merge is sourced and before merge_main,
    # to inject a fault at a point the SHIPPED merge reaches (p_pcmv). Unset everywhere else, so nothing changes.
    [ -z "${MX_HOOK:-}" ] || eval "$MX_HOOK"
    shift; merge_main "$@" )
}
run_merge() { # <merge-script> <shard-dir> -> RC, $MO
  $ASM_RUN "$1" "$2" > "$MO" 2>&1; RC=$?
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
  # Every merge reads BACKDATE_TOL_S from this sibling (the invoked_at bound).
  cp "$(dirname "$m")/validate-artifact-budget.sh" "$sd/" || return 1
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
  $ASM_RUN "$1" --document "$(doc_of "$2")" "$2" > "$MO" 2>&1; RC=$?
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
doc_b3_world() { wc_get docb3 doc_b3_world_build; }
doc_b3_world_build() {
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
new_subj_world() { wc_get subj new_subj_world_build; }
new_subj_world_build() { # -> prints the shard dir s9/shards/requirements-p1 of a fresh subject world
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
subj_shas() { # <shard dir> -> the four-stem list as on disk, in the `@` form a current tree's merge emits
  local w; w="$(subj_root "$1")"
  printf 'product-brief@%s SPEC@%s prd@%s architecture-impact@%s' "$(sha_of "$w/$SUBJ_PA/product-brief.md")" \
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
subj_b3_world() { wc_get subjb3 subj_b3_world_build; }
subj_b3_world_build() { # every part shard 1 MAJOR stamped MET, summed over the ceiling; clean cross shards
  local d o; d="$(new_subj_world)" || return 1
  for o in $(cut -f1 "$(subj_root "$d")/subject.map"); do sshard "$d" "$o" 1 "$o"; done
  for o in $(subj_xkeys "$d"); do sshard "$d" "$o" 0 "1, 2"; done
  printf '%s' "$d"
}
run_subj_merge() { $ASM_RUN "$1" --subject 9 "${@:3}" "$2" > "$MO" 2>&1; RC=$?; }
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
p_subj_at() { # every shard notarizes the OLD `<stem>=<sha>` form: the merge reads it and EMITS the `@` list
  local m="$1" d o sl k
  d="$(new_subj_world)" || return 1; o="$(subj_out_of "$d")"
  sl="$(subj_shas "$d" | sed 's/@/=/g')"
  case "$sl" in *@*) return 1 ;; esac
  for k in $(cut -f1 "$(subj_root "$d")/subject.map"); do sshard "$d" "$k" 1 "$k" "$sl"; done
  for k in $(subj_xkeys "$d"); do sshard "$d" "$k" 0 "1, 2" "$sl"; done
  run_subj_merge "$m" "$d"
  [ "$RC" -eq 0 ] && [ -f "$o" ] && [ "$(grep '^artifact_sha:' "$o")" = "artifact_sha: $(subj_shas "$d")" ]
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
  sl="$(subj_shas "$d" | sed "s/prd@[0-9a-f]*/prd@$(sha_of "$SEED_DIR/seed.doc-serial-epics.md")/")"
  case "$sl" in *"prd@$(sha_of "$SEED_DIR/seed.doc-serial-epics.md")"*) ;; *) return 1 ;; esac
  sshard "$d" 2 1 2 "$sl"
  run_subj_merge "$1" "$d"
  subj_refused_clean "notarizes prd=" "$d"
}
p_subj_stems() { # a shard notarizing three of the four stems
  local d sl; d="$(subj_b3_world)" || return 1
  sl="$(subj_shas "$d" | sed 's/ architecture-impact@[0-9a-f]*//')"
  case "$sl" in *architecture-impact*) return 1 ;; esac
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
  $ASM_RUN "$m" --subject 9 --elicitation "$e" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && [ -f "$o" ] && ! grep -q '^verdict:' "$o" && ! grep -q 'verdict=' "$MO" && has "$o" "skill: bmad-advanced-elicitation" || return 1
  [ ! -e "$w/$SUBJ_PA/s9/requirements-adversarial-p1.md" ] || return 1
  rm -f "$o"; sshard "$e" 1 1 1 "" bmad-advanced-elicitation EXIT_CONDITION_MET
  $ASM_RUN "$m" --subject 9 --elicitation "$e" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$MO" "an elicitation shard carries none" && [ ! -e "$o" ] || return 1
  sshard "$e" 1 1 1 "" ai-dlc-adversary-review -
  $ASM_RUN "$m" --subject 9 --elicitation "$e" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$MO" "an elicitation shard runs bmad-advanced-elicitation" && [ ! -e "$o" ]
}
p_subj_b4() { # --document into requirements-p<M> refused before any shard is read
  local d w; d="$(subj_b3_world)" || return 1; w="$(subj_root "$d")"
  $ASM_RUN "$1" --document "$w/$SUBJ_PA/prd.md" "$d" > "$MO" 2>&1; RC=$?
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
  $ASM_RUN "$1" --document "$w/$SUBJ_PA/prd.md" "$w/$SUBJ_PA/s9/shards/prd-p1" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED:" && has "$MO" "is the 'prd' file of the requirements subject" \
    && has "$MO" "merge the subject with --subject 9" && [ ! -e "$o" ]
}
p_b4doc_nomf() {
  local w o; w="$(b4_world 0)" || return 1; o="$w/$SUBJ_PA/s9/prd-adversarial-p1.md"
  [ ! -e "$w/$SUBJ_PA/s9/requirements-subject.md" ] || return 1
  b4_doc_shards "$w" "$SUBJ_PA/prd.md" "$w/$SUBJ_PA/s9/shards/prd-p1" || return 1
  $ASM_RUN "$1" --document "$w/$SUBJ_PA/prd.md" "$w/$SUBJ_PA/s9/shards/prd-p1" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] && grep -qx "artifact: $SUBJ_PA/prd.md" "$o"
}
p_b4doc_other() {
  local w o doc; w="$(b4_world 1)" || return 1; o="$w/$SUBJ_PA/s9/test-strategy-adversarial-p1.md"
  [ -f "$w/$SUBJ_PA/s9/requirements-subject.md" ] || return 1
  doc="$SUBJ_PA/s9/test-strategy.md"; cp "$SEED_DIR/seed.doc-test-strategy.md" "$w/$doc" || return 1
  b4_doc_shards "$w" "$doc" "$w/$SUBJ_PA/s9/shards/test-strategy-p1" || return 1
  $ASM_RUN "$1" --document "$w/$doc" "$w/$SUBJ_PA/s9/shards/test-strategy-p1" > "$MO" 2>&1; RC=$?
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
stem_merge() { $ASM_RUN "$1" --document "$(stem_s9 "$2")/test-strategy.md" "$2" > "$MO" 2>&1; RC=$?; }
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
  $ASM_RUN "$1" "$d" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED: shard directory stories-adversarial-p1 names the series" || return 1
  $ASM_RUN "$1" --map "$d" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED: shard directory stories-adversarial-p1 names the series" \
    && ! grep -q "$(printf '\t')a.md" "$MO" && stem_none "$s9"
}

# --------------------------------------------- the dispatch id is DERIVED, never self-reported
# Every world below is the B3 world with shard 2 (and only shard 2) written under the knob the cell
# varies; shards 1, 3 and cross-1..3 are written normally, so each refusal is that shard's alone.
# The ALLOW twin of each refusal sits in the same predicate wherever one property separates them.
tw() { wc_get tw tw_build; }
tw_build() { # -> a B3 shard dir with every shard but 2 written and recorded
  local d x; d="$(new_world)"
  shard "$d" 1 2 EXIT_CONDITION_MET 1
  shard "$d" 3 2 EXIT_CONDITION_MET 3
  for x in $(xkeys 3); do shard "$d" "$x" 0 EXIT_CONDITION_MET "1, 3"; done
  printf '%s' "$d"
}
s2() { shard "$1" 2 2 EXIT_CONDITION_MET 2 "" "${2:-}"; } # <shard dir> [invoked_at] -- shard 2, under whatever knobs prefix the call
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
p_tuid_twowriters() { # R6: two adversary dispatches wrote shard 2 -> REFUSED, never the first taken. Each row
                      # carries a literal ts, the second strictly after the first, so a --rerun start exists and
                      # the refusal is the two-dispatch one (BL-946); two wall-clock stamps in one second would tie
                      # and make it DOUBLE-WRITE, a verdict that moved with load (BL-868)
  local d; d="$(tw)"; WORLD_SHARD="$d/2.md"; hr_at 2026-10-15T20:00:00Z s2 "$d" || return 1
  HR_AGENT_O=a00000000000000r6 HR_DID_O=toolu_01SecondAdversary0000006 hr_at 2026-10-15T21:00:00Z harness_record "$d/2.md" || return 1
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
# (HR_SPAWN_TS), because the merge binds S to that time (BL-598), and its shard stamps this as its
# invoked_at, because the merge bounds every shard's invoked_at by its dispatch time (BL-726).
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
  HR_SPAWN_TS="$RR_S" hr_at 2026-10-15T21:00:00Z s2 "$d" "$RR_S" || return 1
  hr_ids "$d/2.md"; o="$(out_of "$d")"
  $ASM_RUN "$1" --rerun "2.md@$RR_S" "$d" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$MO" "superseded=2" && grep -q " 2=$HR_DID " "$o" \
    && grep -qx "rerun: 2.md since $RR_S; superseded: a0000000000stall (2 rows, 2026-10-15T20:00:00Z..2026-10-15T20:01:00Z)" "$o"
}
p_rerun_other() { # graph s318 requirements-p1/cross-2's shape: cross-1's OWN adversary edited shard 2
                  # before S, and a new dispatch wrote it after -> REFUSED; --rerun never acquits a
                  # cross-shard write
  local d c1a c1d; d="$(tw)"; WORLD_SHARD="$d/2.md"
  hr_ids "$d/cross-1.md"; c1a="$HR_AGENT"; c1d="$HR_DID"
  HR_AGENT_O="$c1a" HR_DID_O="$c1d" hr_at 2026-10-15T20:00:00Z s2 "$d" || return 1
  HR_SPAWN_TS="$RR_S" hr_at 2026-10-15T21:00:00Z s2 "$d" "$RR_S" || return 1
  $ASM_RUN "$1" --rerun "2.md@$RR_S" "$d" > "$MO" 2>&1; RC=$?
  refused_clean "--rerun 2.md: $c1a is a superseded writer of 2.md and also wrote" "$d" && has "$MO" "cross-1.md at"
}
p_rerun_same() { # the superseded writer writes 2.md again after S, and nobody else does -> REFUSED: the
                 # re-run is a NEW dispatch
  local d; d="$(tw)"; WORLD_SHARD="$d/2.md"
  hr_at 2026-10-15T20:00:00Z s2 "$d" || return 1
  HR_SPAWN_TS="$RR_S" hr_at 2026-10-15T21:00:00Z s2 "$d" "$RR_S" || return 1
  hr_ids "$d/2.md"
  $ASM_RUN "$1" --rerun "2.md@$RR_S" "$d" > "$MO" 2>&1; RC=$?
  refused_clean "--rerun 2.md: $HR_AGENT wrote" "$d" && has "$MO" "its writer must not be one of the writers it supersedes"
}
# ------------------------------------------- BL-946: DOUBLE-WRITE, no admissible --rerun start
# graph s322 coe-p2/cross.md: the original seat O kept writing after its re-dispatch N wrote. O is a
# STOPPED adversary (it carries its probe row), so once the shard is left un-narrowed the join credits
# it and reaches the two-dispatch test rather than refusing O as unstopped. Every ts is a literal.
DW_O=a0000000000oseat; DW_OD=toolu_01OriginalSeat0000000002
DW_SPAN_O="$DW_O (2026-10-15T20:00:00Z..2026-10-15T21:10:00Z)"
dw_o() { HR_AGENT_O="$DW_O" HR_DID_O="$DW_OD" hr_at "$@"; } # <ts> <command...> -- a write by the original seat
dw_world() { # <shard dir> -- O at 20:00 < S, N (spawn S) at 21:00, O again at 21:10, its bytes on disk
  dw_o 2026-10-15T20:00:00Z s2 "$1" || return 1
  HR_SPAWN_TS="$RR_S" hr_at 2026-10-15T21:00:00Z s2 "$1" "$RR_S" || return 1
  dw_o 2026-10-15T21:10:00Z s2 "$1" "$RR_S"
}
dw_refused() { # <shard dir> -- DOUBLE-WRITE naming both spans in first order, no seal row, the remedy
  hr_ids "$1/2.md"
  refused_clean "REFUSED: DOUBLE-WRITE 2.md: " "$1" \
    && has "$MO" "was written by $DW_SPAN_O, $HR_AGENT (2026-10-15T21:00:00Z..2026-10-15T21:00:00Z); no --rerun 2.md@<ISO> start can pass" \
    && has "$MO" "no agent seal row exists for 2.md" && has "$MO" "re-dispatch a NEW adversary for 2.md"
}
p_dw_rerun() { # RR6a: the s322 interleave under --rerun 2.md@S -> DOUBLE-WRITE, never SAME
  local d; d="$(tw)"; WORLD_SHARD="$d/2.md"; dw_world "$d" || return 1
  $ASM_RUN "$1" --rerun "2.md@$RR_S" "$d" > "$MO" 2>&1; RC=$?
  dw_refused "$d" && ! has "$MO" "its writer must not be one of the writers it supersedes"
}
p_dw_plain() { # RR6n: the same world with no --rerun -> DOUBLE-WRITE, never the two-dispatch remedy
  local d; d="$(tw)"; WORLD_SHARD="$d/2.md"; dw_world "$d" || return 1
  run_merge "$1" "$d"
  dw_refused "$d" && ! has "$MO" "was written by more than one adversary dispatch"
}
p_dw_twin() { # RR6b: one property apart -- O's last row is before S -> MERGED with --rerun, superseded=2
  local d; d="$(tw)"; WORLD_SHARD="$d/2.md"
  dw_o 2026-10-15T20:00:00Z s2 "$d" || return 1
  dw_o 2026-10-15T20:10:00Z s2 "$d" || return 1
  HR_SPAWN_TS="$RR_S" hr_at 2026-10-15T21:00:00Z s2 "$d" "$RR_S" || return 1
  hr_ids "$d/2.md"
  $ASM_RUN "$1" --rerun "2.md@$RR_S" "$d" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$MO" "superseded=2" && grep -q " 2=$HR_DID " "$(out_of "$d")" \
    && grep -qx "rerun: 2.md since $RR_S; superseded: $DW_O (2 rows, 2026-10-15T20:00:00Z..2026-10-15T20:10:00Z)" "$(out_of "$d")"
}
p_dw_tie() { # RR6c: O's last row ts EQUALS N's first, and S is that tie -> DOUBLE-WRITE (no S is both > and <=)
  local d s=2026-10-15T21:00:00Z; d="$(tw)"; WORLD_SHARD="$d/2.md"
  dw_o 2026-10-15T20:00:00Z s2 "$d" || return 1
  HR_SPAWN_TS="$s" hr_at "$s" s2 "$d" "$s" || return 1
  dw_o "$s" s2 "$d" "$s" || return 1
  hr_ids "$d/2.md"
  $ASM_RUN "$1" --rerun "2.md@$s" "$d" > "$MO" 2>&1; RC=$?
  refused_clean "REFUSED: DOUBLE-WRITE 2.md: " "$d" \
    && has "$MO" "was written by $DW_O (2026-10-15T20:00:00Z..$s), $HR_AGENT ($s..$s); no --rerun"
}
p_dw_out() { # RR6d: the s322 world, and O ALSO wrote 3.md.draft AFTER its straddling row -> the OUT refusal, not
             # DOUBLE-WRITE. A draft is no shard, so the join never sees that row: only the OUT scan can.
  local d; d="$(tw)"; WORLD_SHARD="$d/2.md"; dw_world "$d" || return 1
  dw_o 2026-10-15T21:20:00Z harness_record "$d/3.md.draft" || return 1
  $ASM_RUN "$1" --rerun "2.md@$RR_S" "$d" > "$MO" 2>&1; RC=$?
  refused_clean "--rerun 2.md: $DW_O is a superseded writer of 2.md and also wrote" "$d" && has "$MO" "3.md.draft at 2026-10-15T21:20:00Z" \
    && ! has "$MO" "DOUBLE-WRITE"
}
p_dw_role() { # RR6e: the s322 world plus a REMEDIATOR writing 2.md, sorting LAST among its writers, no --rerun
              # -> the role violation, not DOUBLE-WRITE: the two-dispatch test waits for every writer
  local d; d="$(tw)"; WORLD_SHARD="$d/2.md"; dw_world "$d" || return 1
  HR_ROLE=remediator HR_AGENT_O=azzzzzzzzzzremed HR_DID_O=toolu_01RemediatorWrite00006e hr_at 2026-10-15T21:20:00Z harness_record "$d/2.md" || return 1
  run_merge "$1" "$d"
  refused_clean "was written by agent azzzzzzzzzzremed, dispatch toolu_01RemediatorWrite00006e, dispatched as role remediator" "$d" \
    && ! has "$MO" "DOUBLE-WRITE"
}
p_dw_draft() { # RR6f: graph s318 architecture-p1/cross-2's shape -- an agent D that wrote ONLY 2.md.draft is not a
               # writer. O at 20:00, N at 21:00 and 21:10, D's draft row at 21:05 inside N's span. No --rerun ->
               # the two-dispatch refusal (N's first row is after O's last: a start exists); --rerun 2.md@S -> MERGED
  local d o
  for o in plain rerun; do
    d="$(tw)"; WORLD_SHARD="$d/2.md"
    dw_o 2026-10-15T20:00:00Z s2 "$d" || return 1
    HR_SPAWN_TS="$RR_S" hr_at 2026-10-15T21:00:00Z s2 "$d" "$RR_S" || return 1
    HR_AGENT_O=a00000000000draft HR_DID_O=toolu_01DraftOnlyAdversary0006f hr_at 2026-10-15T21:05:00Z harness_record "$d/2.md.draft" || return 1
    HR_SPAWN_TS="$RR_S" hr_at 2026-10-15T21:10:00Z s2 "$d" "$RR_S" || return 1
    hr_ids "$d/2.md"
    if [ "$o" = plain ]; then
      run_merge "$1" "$d"
      refused_clean "2.md was written by more than one adversary dispatch (" "$d" && has "$MO" "$DW_OD" && has "$MO" "$HR_DID" \
        && ! has "$MO" "DOUBLE-WRITE" || return 1
    else
      $ASM_RUN "$1" --rerun "2.md@$RR_S" "$d" > "$MO" 2>&1; RC=$?
      [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$MO" "superseded=1" && grep -q " 2=$HR_DID " "$(out_of "$d")" || return 1
    fi
  done
}
p_dw_straddle_draft() { # RR6g: the straddle's late row is on 2.md.draft, not exact 2.md. O writes 2.md at 20:00 (< S), N (spawn S)
                        # writes 2.md at 21:00, O then writes ONLY 2.md.draft at 21:10. last(O) counts that draft row, so no start
                        # is admissible: DOUBLE-WRITE under --rerun 2.md@S (never SAME, never MERGED) and with no --rerun (never
                        # the two-dispatch remedy). Every ts is a literal.
  local d o
  for o in plain rerun; do
    d="$(tw)"; WORLD_SHARD="$d/2.md"
    dw_o 2026-10-15T20:00:00Z s2 "$d" || return 1
    HR_SPAWN_TS="$RR_S" hr_at 2026-10-15T21:00:00Z s2 "$d" "$RR_S" || return 1
    dw_o 2026-10-15T21:10:00Z harness_record "$d/2.md.draft" || return 1
    hr_ids "$d/2.md"
    if [ "$o" = plain ]; then
      run_merge "$1" "$d"
      refused_clean "REFUSED: DOUBLE-WRITE 2.md: " "$d" && ! has "$MO" "was written by more than one adversary dispatch" || return 1
    else
      $ASM_RUN "$1" --rerun "2.md@$RR_S" "$d" > "$MO" 2>&1; RC=$?
      refused_clean "REFUSED: DOUBLE-WRITE 2.md: " "$d" && ! has "$MO" "MERGED:" \
        && ! has "$MO" "its writer must not be one of the writers it supersedes" || return 1
    fi
  done
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
    HR_SPAWN_TS="$RR_S" hr_at 2026-10-15T21:00:00Z s2 "$d" "$RR_S" || return 1
    hr_ids "$d/2.md"
    $ASM_RUN "$1" --rerun "2.md@$RR_S" "$d" > "$MO" 2>&1; RC=$?
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
    HR_SPAWN_TS="$RR_S" hr_at 2026-10-15T21:00:00Z s2 "$d" "$RR_S" || return 1
    hr_ids "$d/2.md"
    $ASM_RUN "$1" --rerun "2.md@$RR_S" "$d" > "$MO" 2>&1; RC=$?
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
    HR_SPAWN_TS="$RR_S" hr_at 2026-10-15T21:00:00Z s2 "$d" "$RR_S" || return 1
    hr_ids "$d/2.md"
    $ASM_RUN "$1" --rerun "2.md@$RR_S" "$d" > "$MO" 2>&1; RC=$?
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
    && has "$MO" "has no row for that agent; an adversary that has not stopped has not delivered" \
    && has "$MO" "re-run the merge once the SubagentStop row for that agent lands" && has "$MO" "re-dispatch the shard"
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
  $ASM_RUN "$m" "$d" > "$MO" 2> "$MO.err"; RC=$?
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
  $ASM_RUN "$1" --dry-run "$2" > "$MO" 2>&1; RC=$?
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
  $ASM_RUN "$m" --dry-run "$d" > "$MO" 2>&1 < "$pz"; RC=$?
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
  d="$(tw)"; HR_SPAWN_TS="$RR_S" s2 "$d" "$RR_S"
  $ASM_RUN "$1" --rerun "2.md@1999-01-01T00:00:00Z" "$d" > "$MO" 2>&1; RC=$?
  refused_clean "past BACKDATE_TOL_S=60" "$d" && has "$MO" "never a typed time" || return 1
  d="$(tw)"; HR_SPAWN_TS="$RR_S" s2 "$d" "$RR_S"
  $ASM_RUN "$1" --rerun "2.md@2026-10-15T20:30:45Z" "$d" > "$MO" 2>&1; RC=$?
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
  $ASM_RUN "$m" --check-header "$c/conv.md" --axis convergence > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && [ ! -s "$MO" ] || return 1
  sed 's/^skill: .*/skill: bmad-advanced-elicitation/;/^verdict:/d' "$d/1.md" > "$c/elic.md"; hc_comment "$c/elic.md"
  grep -qx 'skill: bmad-advanced-elicitation # copied with the template comment' "$c/elic.md" || return 1
  $ASM_RUN "$m" --check-header "$c/elic.md" --axis elicitation > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && [ ! -s "$MO" ] || return 1
  hc_comment "$d/1.md"; run_merge "$m" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && cmp -s "$o" "$SEED_DIR/seed.files-b3-merged.expected" || return 1
  sed 's/^findings_major: .*/findings_major: 2#x/' "$c/conv.md" > "$c/tight.md"
  $ASM_RUN "$m" --check-header "$c/tight.md" --axis convergence > "$MO" 2>&1; RC=$?
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
  cp "$(dirname "$m")/validate-artifact-budget.sh" "$sd/" || return 1
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

# ------------------------------------------------ BL-726: invoked_at is bounded on both sides
# Every world is the B3 world under the default spawn ts 2026-08-24T15:00:00Z with `invoked_bound`
# on the spawn rows unless HR_BOUND=0 prefixes the call. bl726_<world> <merge> -> RC, $MO, $MO.err,
# BL_D (the shard dir). The write-ledger rows of shard 2 are re-stamped with hr_at, so its LAST row
# is the one the LATE arm compares; the fixture never touches an mtime.
bl726_run() { $ASM_RUN "$1" "$BL_D" > "$MO" 2> "$MO.err"; RC=$?; }
bl726_clean() { BL_D="$(b3_world)"; bl726_run "$1"; }
bl726_early() { BL_D="$(b3_world)"; shard "$BL_D" 1 2 EXIT_CONDITION_MET 1 "" 2026-08-24T13:00:00Z; bl726_run "$1"; }
bl726_late() { BL_D="$(tw)"; WORLD_SHARD="$BL_D/2.md"; hr_at 2026-08-24T14:00:00Z s2 "$BL_D" || return 1; bl726_run "$1"; }
bl726_near() { BL_D="$(b3_world)"; shard "$BL_D" 1 2 EXIT_CONDITION_MET 1 "" 2026-08-24T14:59:01Z; bl726_run "$1"; }
bl726_frac() { BL_D="$(b3_world)"; shard "$BL_D" 1 2 EXIT_CONDITION_MET 1 "" 2026-08-24T14:59:30.750Z; bl726_run "$1"; }
# Two write rows on shard 2, 14:00 and 15:30, its stamp 15:02:19Z between them: inside the LAST row,
# 3739 s past the EARLIEST. An earliest-row bound refuses it; the last-row bound merges it.
bl726_lastrow() {
  BL_D="$(tw)"; WORLD_SHARD="$BL_D/2.md"
  hr_at 2026-08-24T14:00:00Z s2 "$BL_D" && hr_at 2026-08-24T15:30:00Z harness_record "$BL_D/2.md" || return 1
  bl726_run "$1"
}
# Hour 24: RE_ISO accepts the shape, fromdateiso8601 refuses the calendar time.
bl726_nocal() { BL_D="$(b3_world)"; shard "$BL_D" 1 2 EXIT_CONDITION_MET 1 "" 2026-08-24T24:00:00Z; bl726_run "$1"; }
bl726_written() { [ -f "$(out_of "$BL_D")" ]; }
bl726_refused() { # <token>... -> rc 2, every token in stdout, nothing written
  local t; [ "$RC" -eq 2 ] && ! bl726_written || return 1
  for t in "$@"; do has "$MO" "$t" || return 1; done
}
bl726_merged() { [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && bl726_written; }



# ------------------------------------------------------------------ arms that were inline in run.sh
# Moved here so a mutant of the merge is scored by the arm's OWN body: p_<name> <merge> -> 0 iff the arm
# HOLDS. Every one builds its own worlds under a fresh mktemp (a merge writes its pass file into the world
# and refuses on write-ledger rows keyed to the world's absolute root, so a world is per-use).
mk_markers() { # <shard dir>: every shard ends in its seat-complete marker, n = its `### M<n>` findings
  local f n
  for f in "$1"/*.md; do
    n="$(grep -c '^### M[0-9]' "$f")" || n=0
    printf '\nseat-complete: stories adversary %s findings=%s\n' "$(basename "$f" .md)" "$n" >> "$f"
  done
}
set_major() { sed "s/^findings_major: .*/findings_major: $2/" "$1" > "$1.tmp" && mv "$1.tmp" "$1"; } # <shard file> <n>
PROBES='### Probes run (no finding)\n\nProbed the ordinal citation of every AC; each holds.'
RESERVED='is a `### ` heading under `## Findings` with no severity word'
# RS1: the filed incident -- graph s319 requirements-p1/2.md, findings=0, a probes subsection.
p_rs1() {
  local d; d="$(hdr_world "## Findings\n\n$PROBES")" || return 1; mk_markers "$d"; run_merge "$1" "$d"
  refused_clean "$RESERVED" "$d" && has "$MO" "move it under its own \`## \` section, or demote it to \`#### \`" && has "$MO" "2.md:5 is"
}
# CH2: the merge's own refusal of a verdict-less shard, and --check-header's, say the same thing.
chm() { $ASM_RUN "$1" --check-header "$2" --axis "$3" > "$MO" 2>&1; RC=$?; } # <merge> <shard file> <axis>
p_chv() {
  local m="$1" d dm c ch_out ch_rc m_line ch_tail m_tail
  d="$(b3_world)" || return 1; c="$(mktemp -d "$WORK/chv.XXXXXX")" || return 1
  sed '/^verdict:/d' "$d/1.md" > "$c/nov.md"; chm "$m" "$c/nov.md" convergence; ch_out="$(cat "$MO")"; ch_rc=$RC
  dm="$(b3_world)" || return 1; sed '/^verdict:/d' "$dm/1.md" > "$dm/1.tmp" && mv "$dm/1.tmp" "$dm/1.md"; run_merge "$m" "$dm"
  m_line="$(grep '^REFUSED:' "$MO")"
  ch_tail="${ch_out#* declares }"; m_tail="${m_line#* declares }"
  [ "$ch_rc" -eq 1 ] && [ "$RC" -eq 2 ] && [ "$ch_tail" != "$ch_out" ] && [ "$ch_tail" = "$m_tail" ] \
    && has "$c/nov.md" "findings_major:" && [ "${ch_out#REFUSED: }" != "$ch_out" ] \
    && case "$ch_tail" in "verdict '<none>', not one of"*) true ;; *) false ;; esac
}
# BL726 b/c/f/h: the four cells the bound's mutants are scored on.
p_bl726b() { bl726_early "$1"; bl726_refused "1.md claims invoked_at 2026-08-24T13:00:00Z" "7200 s before its dispatch" "recorded at 2026-08-24T15:00:00Z" "BACKDATE_TOL_S=60" "--rerun 1.md@"; }
p_bl726c() { bl726_late "$1"; bl726_refused "2.md claims invoked_at 2026-08-24T15:02:19Z" "s after its dispatch" "last wrote it at 2026-08-24T14:00:00Z" "--rerun 2.md@"; }
p_bl726f() {
  HR_BOUND=0 bl726_early "$1"
  bl726_merged && has "$MO.err" "WARN: " && has "$MO.err" "1.md claims invoked_at 2026-08-24T13:00:00Z" && has "$MO.err" "recorded at 2026-08-24T15:00:00Z" && has "$MO.err" "LEGACY"
}
p_bl726h() { bl726_lastrow "$1"; bl726_merged && ! has "$MO.err" "WARN: "; }
# ---- BL-958: THE FINDING ID (merge header). Every world is hdr_world's B3 world with shard 2's `## Findings` line
# replaced and its declared counts set to the headings it carries, so the count check passes and only check_keys
# can refuse. No marker is appended (a marker is checked only when present). Shards 1 and 3 hold 2 MAJOR each.
set_crit() { sed "s/^findings_critical: .*/findings_critical: $2/" "$1" > "$1.tmp" && mv "$1.tmp" "$1"; } # <shard file> <n>
kw() { # <findings body> <declared major> [declared critical] -> a B3 shard dir
  local d; d="$(hdr_world "$1")" || return 1
  set_major "$d/2.md" "$2" && set_crit "$d/2.md" "${3:-0}" || return 1
  printf '%s' "$d"
}
KF_MAJ='write it in the keyed form `### F-<n> — MAJOR — <title>`'
KF_J3='closes a MAJOR only by a `source: <shard>#<id>` token keyed on that id'
KF_DUP='2.md:9 repeats finding id F-1 of the heading at line 5'
KF_FENCE='2.md:9 opens a fence that is still open at end of file'
T1_BODY='## Findings\n\n### MAJOR — wiring check\n\nstories: 2\n'
# T1: a keyless MAJOR and a keyless CRITICAL heading are each REFUSED, naming file:line, the keyed form and J3's token.
p_t1() {
  local d
  d="$(kw "$T1_BODY" 1)" || return 1; run_merge "$1" "$d"
  refused_clean "2.md:5 is a MAJOR finding heading from which no finding id is derived" "$d" && has "$MO" "$KF_MAJ" && has "$MO" "$KF_J3" || return 1
  d="$(kw '## Findings\n\n### CRITICAL: x\n\nstories: 2\n' 0 1)" || return 1; run_merge "$1" "$d"
  refused_clean "2.md:5 is a CRITICAL finding heading from which no finding id is derived" "$d" \
    && has "$MO" 'write it in the keyed form `### F-<n> — CRITICAL — <title>`'
}
# T2: every keyed form J3 reads merges, each counted -- and a keyless MINOR stays allowed. Shard 2 holds 5 MAJOR.
p_t2() {
  local d
  d="$(kw '## Findings\n\n### F-1 — MAJOR — t\n\nstories: 2\n\n### **F-2** (MAJOR)\n\nstories: 2\n\n### Finding 3: MAJOR\n\nstories: 2\n\n### 1. MAJOR wiring\n\nstories: 2\n\n### [F-3] MAJOR\n\nstories: 2\n\n### MINOR — keyless\n\nstories: 2\n' 5)" || return 1
  run_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$MO" "major=9"
}
# T3a: two headings deriving the same id in one shard are REFUSED (MAJOR twice; a MINOR sharing a MAJOR's id); the
# same id in two DIFFERENT shards (shard 2's M1 beside shard 1's M1) merges.
p_t3a() {
  local d
  d="$(kw '## Findings\n\n### F-1 — MAJOR — a\n\nstories: 2\n\n### F-1 — MAJOR — b\n\nstories: 2\n' 2)" || return 1; run_merge "$1" "$d"
  refused_clean "$KF_DUP" "$d" && has "$MO" "one token cannot close two findings" || return 1
  d="$(kw '## Findings\n\n### F-1 — MAJOR — a\n\nstories: 2\n\n### F-1 — MINOR — b\n\nstories: 2\n' 1)" || return 1; run_merge "$1" "$d"
  refused_clean "$KF_DUP" "$d" || return 1
  d="$(kw '## Findings\n\n### M1 — MAJOR — a\n\nstories: 2\n' 1)" || return 1; run_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$MO" "major=5"
}
# T3b: a pair differing in raw bytes that NORMALISES to one id (emphasis; a trailing `.`) is REFUSED the same way.
p_t3b() {
  local d
  d="$(kw '## Findings\n\n### **F-1** — MAJOR — a\n\nstories: 2\n\n### F-1. — MAJOR — b\n\nstories: 2\n' 2)" || return 1; run_merge "$1" "$d"
  refused_clean "$KF_DUP" "$d"
}
# D1: a fence left open at end of file AFTER shard 2's counted finding is REFUSED; the same fence closed merges.
p_d1() {
  local d
  d="$(kw '## Findings\n\n### F-1 — MAJOR — a\n\nstories: 2\n\n```text\nopen' 1)" || return 1; run_merge "$1" "$d"
  refused_clean "$KF_FENCE" "$d" && has "$MO" "hides every later shard" || return 1
  d="$(kw '## Findings\n\n### F-1 — MAJOR — a\n\nstories: 2\n\n```text\nclosed\n```' 1)" || return 1; run_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$MO" "major=5"
}
# ELIC: the requirement is the CONVERGENCE axis only -- a keyless MAJOR in an elicitation shard passes
# --check-header --axis elicitation (rc 0, nothing printed).
p_elic() {
  local d c
  d="$(kw "$T1_BODY" 1)" || return 1; c="$(mktemp -d "$WORK/elic.XXXXXX")" || return 1
  sed -e '/^verdict:/d' -e 's/^skill: .*/skill: bmad-advanced-elicitation/' "$d/2.md" > "$c/2.md" || return 1
  has "$c/2.md" "### MAJOR — wiring check" && has "$c/2.md" "skill: bmad-advanced-elicitation" || return 1
  chm "$1" "$c/2.md" elicitation
  [ "$RC" -eq 0 ] && [ ! -s "$MO" ]
}
# CHK / DRY: --check-header (convergence) and --dry-run each refuse T1's shard with the same refusal.
p_t1_chk() {
  local d; d="$(kw "$T1_BODY" 1)" || return 1
  chm "$1" "$d/2.md" convergence
  [ "$RC" -eq 1 ] && has "$MO" "REFUSED: " && has "$MO" "2.md:5 is a MAJOR finding heading from which no finding id is derived" && has "$MO" "$KF_MAJ"
}
p_t1_dry() {
  local d; d="$(kw "$T1_BODY" 1)" || return 1
  $ASM_RUN "$1" --dry-run "$d" > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED: " && has "$MO" "2.md:5 is a MAJOR finding heading from which no finding id is derived" && [ ! -e "$(out_of "$d")" ]
}
# SH: a shard's OWN `## Shard: ` line. The merged pass carries it verbatim, and J3's j3_keys re-points every later
# finding at the shard file that heading maps to, so a heading naming another shard (or none) leaves the shard's
# MAJORs keyed where no `source: <own file>#<id>` token can close them. FIS refuses: one end-to-end merge (shard 2
# saying `story 3`), then --check-header cells on copies of that shard renamed and re-headed -- `part 04` in 5.md,
# `cross-story group 2 (1,3)` in cross-1.md, and `story 2` followed by a later `## Shard: notes` in 2.md (every
# heading is checked, not only the first). FISa is each ALLOW twin one property apart: `story 2` in 2.md, `part 04`
# in 04.md (the ordinal read as a number on both sides, BL-962), `cross-story` in cross.md, `cross-section group 01
# (1,3)` in cross-1.md. SH_REF names the refusal text.
SH_REF='is a `## Shard: ` heading, which J3 (validate-adversarial-convergence.sh j3_keys) reads as shard file'
sh_world() { # -> SH_D, a B3 world whose shard 2 opens `## Shard: story 3` above one keyed MAJOR
  SH_D="$(kw '## Shard: story 3\n\n## Findings\n\n### F-1 — MAJOR — a\n\nstories: 2\n' 1)"
}
sh_cell() { # <merge> <template shard> <dir> <file name> <heading replacing `## Shard: story 3`> [<line appended last>] -> RC, $MO
  mkdir -p "$3" && awk -v H="$5" -v T="${6:-}" '$0 == "## Shard: story 3" { print H; next } { print } END { if (T != "") { print ""; print T } }' "$2" > "$3/$4" || return 1
  has "$3/$4" "$5" || return 1
  chm "$1" "$3/$4" convergence
}
p_sh_refuse() {
  local d c
  sh_world || return 1; d="$SH_D"; run_merge "$1" "$d"
  refused_clean "2.md:3 $SH_REF 3.md, not this shard's own 2.md" "$d" && has "$MO" 'no `source: 2.md#<id>` token closes' || return 1
  c="$(mktemp -d "$WORK/sh.XXXXXX")" || return 1
  sh_cell "$1" "$d/2.md" "$c/a" 5.md '## Shard: part 04'
  [ "$RC" -eq 1 ] && has "$MO" "5.md:3 $SH_REF 4.md, not this shard's own 5.md" || return 1
  sh_cell "$1" "$d/2.md" "$c/b" cross-1.md '## Shard: cross-story group 2 (1,3)'
  [ "$RC" -eq 1 ] && has "$MO" "cross-1.md:3 $SH_REF cross-2.md, not this shard's own cross-1.md" || return 1
  sh_cell "$1" "$d/2.md" "$c/c" 2.md '## Shard: story 2' '## Shard: notes'
  [ "$RC" -eq 1 ] && has "$MO" "$SH_REF ?, not this shard's own 2.md" && ! has "$MO" "2.md:3 "
}
p_sh_accept() {
  local d c
  # Only shard 2's bytes are read here (--check-header reads one file), so the last world FIS built is reused.
  [ -n "${SH_D:-}" ] && [ -f "$SH_D/2.md" ] || sh_world || return 1
  d="$SH_D"; c="$(mktemp -d "$WORK/sha.XXXXXX")" || return 1
  sh_cell "$1" "$d/2.md" "$c/a" 2.md '## Shard: story 2'; [ "$RC" -eq 0 ] && [ ! -s "$MO" ] || return 1
  sh_cell "$1" "$d/2.md" "$c/b" 04.md '## Shard: part 04'; [ "$RC" -eq 0 ] && [ ! -s "$MO" ] || return 1
  sh_cell "$1" "$d/2.md" "$c/c" cross.md '## Shard: cross-story'; [ "$RC" -eq 0 ] && [ ! -s "$MO" ] || return 1
  sh_cell "$1" "$d/2.md" "$c/d" cross-1.md '## Shard: cross-section group 01 (1,3)'; [ "$RC" -eq 0 ] && [ ! -s "$MO" ] || return 1
  # The positive conjunct: the cell above really carried the heading under test (a template that lost it would pass).
  has "$c/d/cross-1.md" "## Shard: cross-section group 01 (1,3)" && has "$c/b/04.md" "## Shard: part 04"
}
# P1: the merged pass is a provenance block the READER accepts. Its artifact_sha is the files-mode
# list `<stem>@<sha> ...`; a list of ONE and a short sha are refused, a bare sha still passes. PBROOT,
# when set, is the AI_DLC_PROJECT_ROOT whose core/schemas/ the reader tries first (the schema mutant).
pb_validate() { # <file> -> the reader's rc
  if [ -n "${PBROOT:-}" ]; then
    AI_DLC_PROJECT_ROOT="$PBROOT" bash "$SRCDIR/validate-provenance-block.sh" "$1" --require-skill ai-dlc-adversary-review > "$MO.pb" 2>&1
  else
    bash "$SRCDIR/validate-provenance-block.sh" "$1" --require-skill ai-dlc-adversary-review > "$MO.pb" 2>&1
  fi
}
pb_merged() { # <merge> -> PB_O (the merged pass), PB_FIRST, PB_NPAIRS, PB_T; rc 0 when the pass is multi-file @-form
  local d sha_line
  PB_T="$(mktemp -d "$WORK/pb.XXXXXX")" || return 1
  # A mutated or control COPY lives outside the install layout, so its pair_sep() finds no schema beside it
  # and would emit `=`; AI_DLC_PROJECT_ROOT pins the shipped schema for every copy alike (K does the same).
  mkdir -p "$PB_T/root/core/schemas" && cp "${PBSCH:-$KSCH}" "$PB_T/root/core/schemas/provenance-block.json" || return 1
  d="$(b3_world)" || return 1; PB_O="$(out_of "$d")"; AI_DLC_PROJECT_ROOT="$PB_T/root" run_merge "$1" "$d"
  sha_line="$(grep '^artifact_sha:' "$PB_O" 2>/dev/null)"
  PB_NPAIRS="$(printf '%s' "${sha_line#artifact_sha:}" | wc -w | tr -d ' ')"
  PB_FIRST="$(printf '%s' "${sha_line#artifact_sha: }" | cut -d' ' -f1)"
  { [ "$RC" -eq 0 ] && [ "${PB_NPAIRS:-0}" -ge 2 ]; } || return 1
  case "$PB_FIRST" in *@*) return 0 ;; *) return 1 ;; esac
}
p_pb() {
  local one short bare r_m r_1 r_s r_b
  [ -f "$SRCDIR/validate-provenance-block.sh" ] || return 2
  pb_merged "$1" || return 3
  one="$PB_T/one.md"; short="$PB_T/short.md"; bare="$PB_T/bare.md"
  sed "s/^artifact_sha:.*/artifact_sha: $PB_FIRST/" "$PB_O" > "$one"
  sed -E 's/^(artifact_sha: [^ ]+@)[a-f0-9]{64}/\1abc123/' "$PB_O" > "$short"
  sed "s/^artifact_sha:.*/artifact_sha: ${PB_FIRST#*@}/" "$PB_O" > "$bare"
  cmp -s "$PB_O" "$short" && return 4
  pb_validate "$PB_O"; r_m=$?; pb_validate "$one"; r_1=$?; pb_validate "$short"; r_s=$?; pb_validate "$bare"; r_b=$?
  PB_RS="merged=$r_m one-pair=$r_1 short-sha=$r_s bare=$r_b"
  [ "$r_m" -eq 0 ] && [ "$r_1" -ne 0 ] && [ "$r_s" -ne 0 ] && [ "$r_b" -eq 0 ]
}
p_pbbare() { # the bare-sha control alone: a bare sha is accepted whatever the list pattern says
  local bare
  [ -f "$SRCDIR/validate-provenance-block.sh" ] || return 2
  pb_merged "$1" || return 3
  bare="$PB_T/bare.md"; sed "s/^artifact_sha:.*/artifact_sha: ${PB_FIRST#*@}/" "$PB_O" > "$bare"
  pb_validate "$bare"
}

# ------------------------------------------------------------------ THE DERIVED SET (BL-911)
# A pass after a series' first owes only the parts whose BYTES changed since the series predecessor
# notarized them, the parts the predecessor's CRITICAL/MAJOR findings cite, and the cross shard
# (merge-adversarial-shards.sh, header THE DERIVED SET). It binds only where the ERA binds: the installed
# rulebook above the sprint carries the validator's ERA_TOKEN and the series' first invoked_at is at or
# after the oldest commit adding it. So every world here installs the REAL rulebook and commits it in its
# own git repository at a FIXED date (2026-01-01, BL-868: no clock), before every pass (2026-08-24).
# Eight stories (story-01..08-k.md), every p1 shard written and merged by the shipped merge; then the
# REPAIR edits stories 3 and 6 on disk, and the remediator's joined record cites ONLY story 3 (6 is a
# serial edit no `edit:` names). World B also seeds a MAJOR on story 5 (unedited, still open) and one on
# story 7 dispositioned `repaired` with `edit: n/a (no edit)`. The worlds are built once (wc_get).
# Resolved LAZILY and fork-free (dv_rulebook): other fixtures source this lib (content-seal/merge-arms.sh),
# and an eager walk would fork in every one of them, moving their invocation budgets.
RULEBOOK=""
dv_rulebook() { # -> 0 and RULEBOOK set when the rulebook is found walking up from this lib, in either layout
  local d="$LIB_DIR" c
  [ -n "$RULEBOOK" ] && return 0
  while [ -n "$d" ]; do
    for c in "$d/core/skills/ai-dlc/steps/_gate-procedures.md" "$d/.claude/skills/ai-dlc/steps/_gate-procedures.md"; do
      [ -f "$c" ] && { RULEBOOK="$c"; return 0; }
    done
    d="${d%/*}"
  done
  return 1
}
dv_git() { # <world> -- commit the installed rulebook at a fixed date in the world's own repository
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
    g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$1" -c user.name=f -c user.email=f@example.invalid \
          -c core.hooksPath=/dev/null -c commit.gpgsign=false "${@:2}"; }
    g "$1" init -q . && g "$1" add .claude \
      && GIT_COMMITTER_DATE=2026-01-01T00:00:00Z GIT_AUTHOR_DATE=2026-01-01T00:00:00Z g "$1" commit -q -m rulebook ) >/dev/null 2>&1
}
dv_root() { # <world> -- the rulebook, the legacy role file, the repository
  mkdir -p "$1/.claude/skills/ai-dlc/steps" && cp "$RULEBOOK" "$1/.claude/skills/ai-dlc/steps/_gate-procedures.md" \
    && legacy_roles "$1" && dv_git "$1"
}
dv_world_build() { # <A|B> -> the s1 dir of a files world whose p1 is merged and repaired
  local w pa d o x n
  w="$(mktemp -d "$WORK/dv.XXXXXX")" || return 1
  pa="$w/_bmad-output/planning-artifacts"
  mkdir -p "$pa/s1/stories" "$pa/s1/shards/stories-p1" "$pa/s1/shards/stories-repair-p1" || return 1
  dv_root "$w" || return 1
  for o in 1 2 3 4 5 6 7 8; do printf '# Story %s\n\nBody of story %s.\n' "$o" "$o" > "$pa/s1/stories/story-0$o-k.md"; done
  d="$pa/s1/shards/stories-p1"
  for o in 1 2 3 4 5 6 7 8; do
    n=0; [ "$1" = B ] && { [ "$o" = 5 ] || [ "$o" = 7 ]; } && n=1
    shard "$d" "$o" "$n" EXIT_CONDITION_NOT_MET "$o"
  done
  for x in $(xkeys 8); do shard "$d" "$x" 0 EXIT_CONDITION_NOT_MET "1, 2"; done
  $ASM_RUN "$MERGE" "$d" >/dev/null 2>&1 && [ -f "$pa/s1/stories-adversarial-p1.md" ] || return 1
  printf 'Repaired.\n' >> "$pa/s1/stories/story-03-k.md"; printf 'Repaired.\n' >> "$pa/s1/stories/story-06-k.md"
  printf -- '### F-3 — MAJOR\n- **disposition:** repaired\n- **edit:** `stories/story-03-k.md:4`\n' > "$pa/s1/shards/stories-repair-p1/01.md"
  [ "$1" = B ] && printf -- '\n### F-7 — MAJOR\n- **disposition:** repaired\n- **edit:** n/a (no edit)\n' >> "$pa/s1/shards/stories-repair-p1/01.md"
  printf '%s' "$pa/s1"
}
dvA_world() { wc_get dvA dv_world_build A; }
dvB_world() { wc_get dvB dv_world_build B; }
# A section-mode world: a seven-section test-strategy.md, p1 merged by --document with a MAJOR on Section 6;
# the repair kept `shards/test-strategy-repair-p1/sections/.before`, then INSERTED a Section 2b ahead of
# Section 3 (every later ordinal shifts by one) and edited Section 4. The insertion is NOT at the top: part 1
# owns the document's title lines, so a heading inserted first moves them and changes part 1's bytes too,
# which widens the set and would hide a mis-keyed join. -> the s1 dir.
dvd_world_build() { # a COPY of the shipped-sequence document world (dvrs_doc_world, the same p1), then the repair
  local s doc rd
  s="$(dvrs_doc_world)" || return 1; doc="$s/test-strategy.md"; rd="$s/shards/test-strategy-repair-p1/sections"
  mkdir -p "$rd" && cp "$doc" "$rd/.before" || return 1
  { printf '## Section 2b\n\n'; slorem sec2b 15; printf '\n'; } > "$WORK/dvd-ins.md" || return 1
  awk -v ins="$WORK/dvd-ins.md" '/^## Section 3$/ { while ((getline l < ins) > 0) print l } { print } /^## Section 4$/ { print "\nRepaired line." }' \
    "$rd/.before" > "$doc" || return 1
  grep -qx '## Section 2b' "$doc" || return 1
  printf '%s' "$s"
}
dvd_world() { wc_get dvd dvd_world_build; }
# dv_map <merge> <s1 dir> <shard dir name> [--document <doc>] -> DV_ORDS ("3 6"), DV_HDR (stderr), RC
dv_map() {
  local m="$1" s="$2" sd="$2/shards/$3"; shift 3
  mkdir -p "$sd" || return 1
  $ASM_RUN "$m" "$@" --derived-map "$sd" > "$WORK/dv.out" 2> "$WORK/dv.err"; RC=$?
  DV_ORDS="$(cut -f1 "$WORK/dv.out" | awk 'NF { printf "%s%d", (n++ ? " " : ""), $1 }')"
  DV_HDR="$(cat "$WORK/dv.err")"
}
# DV2: story 6 changed on disk but no `edit:` names it (a serial remediator's edit) -> it is in the set.
p_dv2() { local s; s="$(dvA_world)" || return 1; dv_map "$1" "$s" stories-p2; [ "$RC" -eq 0 ] && case " $DV_ORDS " in *" 6 "*) true ;; *) false ;; esac; }
# DV3: B's p1 MAJORs on 5 (unedited) and 7 (`repaired`, `edit: n/a`) keep both in: exactly {3 5 6 7}.
p_dv3() { local s; s="$(dvB_world)" || return 1; dv_map "$1" "$s" stories-p2; [ "$RC" -eq 0 ] && [ "$DV_ORDS" = "3 5 6 7" ]; }
# DV4: B plus a story `story-00-a.md` that sorts FIRST, so every ordinal shifts by one. Keyed on basename:
# the new story (1), the changed 3 and 6 (now 4 and 7), the open 5 and 7 (now 6 and 8) -> {1 4 6 7 8}.
p_dv4() {
  local s; s="$(dvB_world)" || return 1
  printf '# Story 0\n\nA story the repair added.\n' > "$s/stories/story-00-a.md"
  dv_map "$1" "$s" stories-p2; [ "$RC" -eq 0 ] && [ "$DV_ORDS" = "1 4 6 7 8" ]
}
# DV4D: section mode narrows by part CONTENT, so a CITED part that the repair left unchanged is owed at its NEW
# ordinal. Section 2b inserted (every later ordinal shifts by one), Section 4 edited, p1's MAJOR on Section 6
# (p1 ordinal 6, now 7): owed {3 5 7} -- the new 2b, the edited 4, the cited 6 -- derived from p1, no full-width
# reason. THE SEED DISCRIMINATES, asserted before the verdict is read (pc_alt): an ordinal-keyed join owes
# {3 4 5 6 7 8} and a line-range join the same; a cite read as a current ordinal owes {3 5 6}.
p_dv4d() {
  local s; s="$(dvd_world)" || return 1
  pc_cur document "$s/test-strategy-adversarial-p1.md" "$s/test-strategy.md" || return 1
  pc_alt document 6 || return 1
  [ "$PC_CON" = "3 5 7" ] && [ "$PC_ORD" != "3 5 7" ] && [ "$PC_RNG" != "3 5 7" ] && [ "$PC_CBO" = "3 5 6" ] || { PC_WHY="seed does not discriminate: $PC_ALL"; return 1; }
  dv_map "$1" "$s" test-strategy-p2 --document "$s/test-strategy.md"
  [ "$RC" -eq 0 ] && [ "$DV_ORDS" = "3 5 7" ] \
    && case "$DV_HDR" in *"derived from test-strategy-adversarial-p1.md"*) true ;; *) false ;; esac && ! has "$WORK/dv.err" "full width"
}
# DV5: p1's artifact_sha line removed (an unreadable predecessor sha list) -> the FULL map, said so.
p_dv5() {
  local s p; s="$(dvA_world)" || return 1; p="$s/stories-adversarial-p1.md"
  sed '/^artifact_sha:/d' "$p" > "$p.n" && mv "$p.n" "$p" || return 1
  dv_map "$1" "$s" stories-p2
  [ "$RC" -eq 0 ] && [ "$DV_ORDS" = "1 2 3 4 5 6 7 8" ] && case "$DV_HDR" in *"full width: stories-adversarial-p1.md notarizes no"*) true ;; *) false ;; esac
}
# dv_gate <merge> <s1 dir>: the GATE (arm N) on the stories series, run with the validator beside <merge>.
dv_gate() { bash "$(dirname "$1")/validate-adversarial-convergence.sh" --series "$2/stories-adversarial-p" > "$CO" 2>&1; }
# DV10: a GAP in the series. A p3 dispatched with no p2 on disk derives from p1, the predecessor IN SERIES
# ORDER, never literal M-1 (graph's s320 stories has no p5).
# The GATE side of the same gap: that p3, merged over {3 6}, stamps shard_set_derived_from: p1, and arm N
# reads p1 as its predecessor -- no FAIL (N), on a run that judged the series.
# The same world carries three assertions no other arm checks (once DV1, DV6 and DV7): a dispatch adding the
# underived shard 1 is REFUSED, nothing written; the narrowed merge notarizes all 8 stems at their disk shas;
# and the same pass rewritten to dispatch {1 3 6} (a superset) fails arm N owed {3 6}.
p_dv10() {
  local m="$1" s d x o lst n st b sok=1 ids; DV_STAGE=derive; s="$(dvA_world)" || return 1; dv_map "$m" "$s" stories-p3
  [ "$RC" -eq 0 ] && [ "$DV_ORDS" = "3 6" ] && case "$DV_HDR" in *"derived from stories-adversarial-p1.md"*) true ;; *) false ;; esac || return 1
  d="$s/shards/stories-p3"; o="$s/stories-adversarial-p3.md"
  for x in 1 3 6; do shard "$d" "$x" 0 EXIT_CONDITION_MET "$x"; done
  for x in $(xkeys 8); do shard "$d" "$x" 0 EXIT_CONDITION_MET "3, 6"; done
  DV_STAGE=underived-refused; run_merge "$m" "$d"; [ "$RC" -eq 2 ] && has "$MO" "1.md is shard 1, outside the derived set {" && [ ! -e "$o" ] || return 1
  rm -f "$d/1.md"
  DV_STAGE=merge-stamps-p1; run_merge "$m" "$d"; [ "$RC" -eq 0 ] && has "$o" "shard_set_derived_from: stories-adversarial-p1.md" || return 1
  DV_STAGE=all-8-stems; lst="$(sed -n 's/^artifact_sha: //p' "$o" | head -1)"; n=0
  for st in $lst; do
    n=$((n + 1)); b="${st%%[=@]*}"
    [ "${st#*[=@]}" = "$(sha_of "$s/stories/$b.md")" ] || sok=0
  done
  [ "$n" -eq 8 ] && [ "$sok" -eq 1 ] || return 1
  DV_STAGE=gate-reads-p1; dv_gate "$m" "$s"; has "$CO" "pass artifact" && ! has "$CO" "FAIL (N -- WIDTH)" || return 1
  DV_STAGE=superset-fails; ids="$(grep '^shard_tool_use_ids:' "$o")" || return 1
  awk -v l="$ids" '/^shard_tool_use_ids:/ { print l " 1=toolu_01DvExtra000000000000"; next } { print }' "$o" > "$o.n" && mv "$o.n" "$o" || return 1
  dv_gate "$m" "$s"; has "$CO" "dispatched parts {1 3 6} but owed {3 6}"
}
# ---- THE SHIPPED SEQUENCE (BL-911). DV4D seeds a world that still holds its pre-repair snapshot; the lead's
# real flow never leaves one, and the narrowing never reads one (it joins p1's notarized `part_sha:`). These
# worlds stop at the p1 merge (cached), and each use then drives the shipped programs in order: the split keyed
# on p1's artifact_sha, one edit to a section copy, the assembly, the worklist WITHOUT --keep (which consumes the
# snapshot), --derived-map for p2 (narrowed), the full map dispatched and REFUSED, the derived dispatch plus its
# cross shards merged, and the gate both ways. The split, assembly and worklist run from $SRCDIR, never from
# beside a mutated merge, so a merge mutant moves only what the merge decides. Every merge call reads /dev/null,
# so a mutant that reads stdin reads nothing rather than the fixture's.
dvrs_doc_build() { # -> the s1 dir of a document world with p1 merged by --document, a MAJOR on Section 6
  local w pa d o x i doc
  w="$(mktemp -d "$WORK/dvrs.XXXXXX")" || return 1
  pa="$w/_bmad-output/planning-artifacts"; doc="$pa/s1/test-strategy.md"
  mkdir -p "$pa/s1/shards/test-strategy-p1" || return 1
  dv_root "$w" || return 1
  { printf '# Test strategy\n\n'; for i in 1 2 3 4 5 6 7; do printf '## Section %s\n\n' "$i"; slorem "sec$i" 15; printf '\n'; done; } > "$doc"
  d="$pa/s1/shards/test-strategy-p1"
  for o in 1 2 3 4 5 6 7; do if [ "$o" = 6 ]; then dshard "$d" "$o" 1 EXIT_CONDITION_NOT_MET "$o"; else dshard "$d" "$o" 0 EXIT_CONDITION_NOT_MET "$o"; fi; done
  for x in $(xkeys 7); do dshard "$d" "$x" 0 EXIT_CONDITION_NOT_MET "1, 2"; done
  $ASM_RUN "$MERGE" --document "$doc" "$d" < /dev/null > /dev/null 2>&1 && [ -f "$pa/s1/test-strategy-adversarial-p1.md" ] || return 1
  printf '%s' "$pa/s1"
}
dvrs_doc_world() { wc_get dvrs dvrs_doc_build; }
dvrs_subj_build() { # -> the s9 dir of a subject world (rulebook committed) with p1 merged by --subject, a MAJOR on part 2
  local d w o; d="$(new_subj_world_build)" || return 1; w="$(subj_root "$d")"
  dv_root "$w" || return 1
  for o in $(cut -f1 "$w/subject.map"); do
    if [ "$((10#$o))" = 2 ]; then sshard "$d" "$o" 1 "$((10#$o))" "" "" EXIT_CONDITION_NOT_MET; else sshard "$d" "$o" 0 "$((10#$o))" "" "" EXIT_CONDITION_NOT_MET; fi
  done
  for o in $(subj_xkeys "$d"); do sshard "$d" "$o" 0 "1, 2" "" "" EXIT_CONDITION_NOT_MET; done
  $ASM_RUN "$MERGE" --subject 9 "$d" < /dev/null > /dev/null 2>&1 && [ -f "$(subj_out_of "$d")" ] || return 1
  printf '%s' "$(dirname "$(dirname "$d")")"
}
dvrs_subj_world() { wc_get dvrss dvrs_subj_build; }
# dvrs_tail <merge> <mode document|subject> <sprint dir> <artifact> <p2 shard dir> <owed ordinals> <merge args...> --
# steps 4 and 5: the derived map is exactly the mode's own --map rows of <owed> (narrowed by part content, no
# full-width reason); the FULL map dispatched with its cross shards is REFUSED, nothing written; the owed parts
# alone merge, stamped derived from p1, and the gate judges the series with no FAIL (N. Then arm N is shown
# able to fire on this pass BOTH ways (N4): a part outside the owed set added to the dispatch ids (a SUPERSET:
# a pass wider than the recomputed derived set) and an owed part's id dropped (a SUBSET), each FAIL (N) owed <owed>.
dvrs_tail() {
  local m="$1" mode="$2" s="$3" art="$4" sd="$5" want="$6" o x k xo="" p l; shift 6
  p="$s/$art-adversarial-p2.md"
  mkdir -p "$sd" || return 1
  # The mode's own map, from its one speller (the merge's --map is files mode only).
  if [ "$mode" = document ]; then bash "$PARTITION" --map "$2" < /dev/null > "$WORK/dvrs.map" 2>/dev/null || return 1
  else ( cd "$(subj_root "$sd")" && AI_DLC_PROJECT_ROOT="$(subj_root "$sd")" bash "$SRCDIR/partition-subject.sh" --map 9 --read-only ) < /dev/null > "$WORK/dvrs.map" 2>/dev/null || return 1; fi
  [ -s "$WORK/dvrs.map" ] || return 1
  awk -F'\t' -v w=" $want " 'index(w, " " ($1 + 0) " ")' "$WORK/dvrs.map" > "$WORK/dvrs.want"
  [ "$(grep -c . "$WORK/dvrs.want")" = "$(printf '%s\n' $want | grep -c .)" ] || return 1
  $ASM_RUN "$m" "$@" --derived-map "$sd" < /dev/null > "$WORK/dvrs.dm" 2> "$WORK/dvrs.err" || return 1
  cmp -s "$WORK/dvrs.want" "$WORK/dvrs.dm" || return 1
  has "$WORK/dvrs.err" "derived from $art-adversarial-p1.md" && ! has "$WORK/dvrs.err" "full width" || return 1
  k="$(grep -c . "$WORK/dvrs.map")" || k=0
  for o in $(cut -f1 "$WORK/dvrs.map"); do
    if [ "$mode" = document ]; then dshard "$sd" "$((10#$o))" 0 EXIT_CONDITION_MET "$((10#$o))"; else sshard "$sd" "$o" 0 "$((10#$o))"; fi
  done
  for x in $(xkeys "$k"); do
    if [ "$mode" = document ]; then dshard "$sd" "$x" 0 EXIT_CONDITION_MET "$(printf '%s' "$want" | sed 's/ /, /g')"; else sshard "$sd" "$x" 0 "$(printf '%s' "$want" | sed 's/ /, /g')"; fi
  done
  # The full map is refused: a shard outside the derived set, and nothing written.
  $ASM_RUN "$m" "$@" "$sd" < /dev/null > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$MO" "outside the derived set {" && [ ! -e "$p" ] || return 1
  for o in $(cut -f1 "$WORK/dvrs.map"); do
    case " $want " in *" $((10#$o)) "*) continue ;; esac
    [ -n "$xo" ] || xo="$((10#$o))"
    if [ "$mode" = document ]; then rm -f "$sd/$((10#$o)).md"; else rm -f "$sd/$o.md"; fi
  done
  [ -n "$xo" ] || return 1
  $ASM_RUN "$m" "$@" "$sd" < /dev/null > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && has "$p" "shard_set_derived_from: $art-adversarial-p1.md" && has "$p" "part_sha: " || return 1
  bash "$(dirname "$m")/validate-adversarial-convergence.sh" --series "$s/$art-adversarial-p" < /dev/null > "$CO" 2>&1
  has "$CO" "pass artifact" && ! has "$CO" "FAIL (N" || return 1
  cp "$p" "$WORK/dvrs.p2" || return 1
  awk -v x="$xo" '/^shard_tool_use_ids:/ { print $0 " " x "=toolu_01DvExtra000000000000"; next } { print }' "$WORK/dvrs.p2" > "$p" || return 1
  bash "$(dirname "$m")/validate-adversarial-convergence.sh" --series "$s/$art-adversarial-p" < /dev/null > "$CO" 2>&1
  l="$(grep -F "but owed {$want}, derived from $art-adversarial-p1.md" "$CO")" || return 1
  grep -qE "parts \{([0-9]+ )*$xo( [0-9]+)*\} but" <<< "$l" || return 1
  awk -v x="${want%% *}" '/^shard_tool_use_ids:/ { sub(" 0*" x "=[^ ]+", "") } { print }' "$WORK/dvrs.p2" > "$p" || return 1
  bash "$(dirname "$m")/validate-adversarial-convergence.sh" --series "$s/$art-adversarial-p" < /dev/null > "$CO" 2>&1
  has "$CO" "but owed {$want}, derived from $art-adversarial-p1.md"
}
# DVRS: document mode, the shipped sequence; and, in the same arm, a FILES-mode twin that still narrows to {3 6}
# with no full-width reason -- so a merge printing full width everywhere fails this arm too.
p_dvrs() {
  local m="$1" s doc rd sha wl rc
  wl="$SRCDIR/serial-remediation-worklist.sh"; [ -f "$wl" ] || return 1
  s="$(dvrs_doc_world)" || return 1; doc="$s/test-strategy.md"; rd="$s/shards/test-strategy-repair-p1"
  sha="$(sed -n 's/^artifact_sha: //p' "$s/test-strategy-adversarial-p1.md" | head -1)"; [ -n "$sha" ] || return 1
  bash "$PARTITION" --split "$doc" "$rd" --expect-sha "$sha" < /dev/null > "$WORK/dvrs.split" 2>&1 || return 1
  [ -f "$rd/sections/.before" ] && [ -f "$rd/sections/4.md" ] || return 1
  printf 'Repaired line.\n' >> "$rd/sections/4.md"
  bash "$PARTITION" --assemble "$rd" < /dev/null > /dev/null 2>&1 || return 1
  grep -qx 'Repaired line.' "$doc" || return 1
  bash "$wl" "$rd" < /dev/null > "$WORK/dvrs.wl" 2>&1; rc=$?
  case "$rc" in 0|3) ;; *) return 1 ;; esac
  [ ! -e "$rd/sections/.before" ] && [ -f "$rd/sections/.manifest" ] || return 1
  dvrs_tail "$m" document "$s" test-strategy "$s/shards/test-strategy-p2" "4 6" --document "$doc" || return 1
  s="$(dvA_world)" || return 1
  dv_map "$m" "$s" stories-p2 < /dev/null
  [ "$RC" -eq 0 ] && [ "$DV_ORDS" = "3 6" ] && has "$WORK/dv.err" "derived from stories-adversarial-p1.md" && ! has "$WORK/dv.err" "full width"
}
# DVRSS: subject mode, the same sequence: a sectioned stem (prd) and a whole-file one (SPEC) each keep a snapshot
# at the split, and the worklist consumes both.
p_dvrss() {
  local m="$1" s w rd sha wl rc
  wl="$SRCDIR/serial-remediation-worklist.sh"; [ -f "$wl" ] || return 1
  s="$(dvrs_subj_world)" || return 1; w="$(dirname "$(dirname "$(dirname "$s")")")"; rd="$s/shards/requirements-repair-p1"
  sha="$(sed -n 's/^artifact_sha: //p' "$s/requirements-adversarial-p1.md" | head -1)"; [ -n "$sha" ] || return 1
  ( cd "$w" && AI_DLC_PROJECT_ROOT="$w" bash "$SRCDIR/partition-subject.sh" --split 9 "$rd" --expect-sha "$sha" ) < /dev/null > "$WORK/dvrss.split" 2>&1 || return 1
  [ -f "$rd/.subject" ] && [ -f "$rd/prd/sections/.before" ] && [ -f "$rd/.before/SPEC" ] && [ -f "$rd/prd/sections/1.md" ] || return 1
  printf 'Repaired in the section copy.\n' >> "$rd/prd/sections/1.md"
  ( cd "$w" && AI_DLC_PROJECT_ROOT="$w" bash "$SRCDIR/partition-subject.sh" --assemble "$rd" ) < /dev/null > /dev/null 2>&1 || return 1
  grep -qx 'Repaired in the section copy.' "$w/$SUBJ_PA/prd.md" || return 1
  ( cd "$w" && AI_DLC_PROJECT_ROOT="$w" bash "$wl" "$rd" ) < /dev/null > "$WORK/dvrss.wl" 2>&1; rc=$?
  case "$rc" in 0|3) ;; *) return 1 ;; esac
  [ ! -e "$rd/prd/sections/.before" ] && [ ! -e "$rd/.before/SPEC" ] && [ -f "$rd/.subject" ] || return 1
  # Owed {2 3}: p1's MAJOR cites part 2 (SPEC, unchanged), and prd's first in-scope section (`## Sprint 9`, part 3)
  # grew by the repaired line; Goals and Requirements moved down one line with their bytes unchanged.
  dvrs_tail "$m" subject "$s" requirements "$s/shards/requirements-p2" "2 3" --subject 9
}
# ---- THE PART-CONTENT DERIVED SET (BL-911: document and subject modes). Every document or subject pass
# notarizes `part_sha:`, one `<ordinal>=<sha256>` per map row; a later pass owes the parts whose digest
# (subject: (file, digest)) is not UNIQUE on both sides, the parts p1's CRITICAL/MAJOR findings cite mapped
# forward by that unique digest, and a cut table's whole run. Each arm below copies a cached p1 world, edits the
# DISK, and asks --derived-map; and each first asserts that its SEED DISCRIMINATES -- that the wrong join a
# feared regression would ship (pc_alt) answers differently from the owed set on that very seed -- before the
# merge's verdict is read. A seed on which the wrong join agrees proves nothing about the join.
# pc_cur <mode> <p1 pass file> <document | subject root> -> $WORK/pc.{pmap,pps,cmap,cps}: p1's embedded map and
# part_sha list, the CURRENT map from the mode's partitioner and each current row's digest taken HERE (one awk
# printing the row's lines first..last, then sha_of; no pipe, and every seeded file ends in a newline, so the slice
# is byte-equal to the one --split cuts), never by the merge or by partition-document.sh --part-sha.
pc_cur() {
  local mode="$1" p1="$2" src="$3" o f a z p
  awk '/^## Shard ordinal map[ \t]*$/ { s = 1; next } s == 1 && /^```/ { s = 2; next } s == 2 && /^```/ { exit } s == 2' "$p1" > "$WORK/pc.pmap"
  sed -n 's/^part_sha: //p' "$p1" | head -1 | tr ' ' '\n' | awk 'NF' > "$WORK/pc.pps"
  if [ "$mode" = document ]; then
    bash "$PARTITION" --map "$src" < /dev/null 2>/dev/null | awk -F'\t' -v d="$src" '{ print $1 "\t" d "\t" $2 "\t" $3 "\t" $4 }' > "$WORK/pc.cmap" || return 1
  else
    ( cd "$src" && AI_DLC_PROJECT_ROOT="$src" bash "$SRCDIR/partition-subject.sh" --map 9 --read-only ) < /dev/null > "$WORK/pc.cmap" 2>/dev/null || return 1
  fi
  : > "$WORK/pc.cps" || return 1
  while IFS="$(printf '\t')" read -r o f a z _; do
    case "$f" in /*) p="$f" ;; *) p="$src/$f" ;; esac
    awk -v a="$a" -v z="$z" 'NR > z { exit } NR >= a' "$p" > "$WORK/pc.slice" || return 1
    printf '%s=%s\n' "$o" "$(sha_of "$WORK/pc.slice")" >> "$WORK/pc.cps"
  done < "$WORK/pc.cmap"
  [ -s "$WORK/pc.pmap" ] && [ -s "$WORK/pc.pps" ] && [ -s "$WORK/pc.cmap" ] && [ "$(grep -c . "$WORK/pc.cps")" = "$(grep -c . "$WORK/pc.cmap")" ]
}
# pc_alt <mode> <p1 ordinals the p1 findings cite> -> PC_CON PC_ORD PC_RNG PC_CBO PC_PRS PC_DIG (space-joined owed
# sets) and PC_ALL, over pc_cur's files. CON is the content join with cites mapped forward and NO table-run
# widening; the rest are the wrong joins: ORD keyed on the ordinal (digest at the same ordinal), RNG on the row's
# (file, first, last), CBO the content join with each cite read as a CURRENT ordinal, PRS a part unchanged when its
# digest is merely PRESENT in p1 (duplicates not owed), DIG keyed on the digest alone (subject: file dropped).
pc_alt() {
  local l
  PC_CON=""; PC_ORD=""; PC_RNG=""; PC_CBO=""; PC_PRS=""; PC_DIG=""
  awk -F'\t' -v md="$1" -v cites="$2" '
    function put(nm, i) { S[nm, i] = 1 }
    FILENAME == ARGV[1] { p = index($0, "="); PS[substr($0, 1, p - 1) + 0] = substr($0, p + 1); next }
    FILENAME == ARGV[2] { p = index($0, "="); CS[substr($0, 1, p - 1) + 0] = substr($0, p + 1); next }
    FILENAME == ARGV[3] { np++; PO[np] = $1 + 0; if (md == "subject") { PF[np] = $2; PA[np] = $3; PZ[np] = $4 } else { PF[np] = "-"; PA[np] = $2; PZ[np] = $3 }; POS[$1 + 0] = np; next }
    { nc++; CO[nc] = $1 + 0; CF[nc] = (md == "subject") ? $2 : "-"; CA[nc] = $3; CZ[nc] = $4 }
    END {
      for (j = 1; j <= np; j++) { k = PF[j] SUBSEP PS[PO[j]]; PK[j] = k; PC[k]++; PD[j] = PS[PO[j]]; PDC[PD[j]]++ }
      for (i = 1; i <= nc; i++) { k = CF[i] SUBSEP CS[CO[i]]; CK[i] = k; CC[k]++; CI[k] = i; CD[i] = CS[CO[i]]; CDC[CD[i]]++; CDI[CD[i]] = i }
      for (i = 1; i <= nc; i++) {
        if (!(PC[CK[i]] == 1 && CC[CK[i]] == 1)) { put("CON", i); put("CBO", i) }
        if (!(CK[i] in PC)) put("PRS", i)
        if (!(PDC[CD[i]] == 1 && CDC[CD[i]] == 1)) put("DIG", i)
        o = CO[i]; j = POS[o]
        if (!(o in POS) || PS[o] != CS[o] || PF[j] != CF[i]) put("ORD", i)
        if (!(o in POS) || PF[j] != CF[i] || PA[j] != CA[i] || PZ[j] != CZ[i]) put("RNG", i)
      }
      n = split(cites, cc, " ")
      for (q = 1; q <= n; q++) {
        c = cc[q] + 0; j = POS[c]
        if (c <= nc) { put("ORD", c); put("RNG", c); put("CBO", c) }
        k = PK[j]; if (PC[k] == 1 && CC[k] == 1) { put("CON", CI[k]); put("PRS", CI[k]) }
        d = PD[j]; if (PDC[d] == 1 && CDC[d] == 1) put("DIG", CDI[d])
      }
      split("CON ORD RNG CBO PRS DIG", nm, " ")
      for (t = 1; t <= 6; t++) { o = ""; for (i = 1; i <= nc; i++) if ((nm[t], i) in S) o = o (o == "" ? "" : " ") CO[i]; print nm[t] "\t" o }
    }' "$WORK/pc.pps" "$WORK/pc.cps" "$WORK/pc.pmap" "$WORK/pc.cmap" > "$WORK/pc.alt" || return 1
  while IFS="$(printf '\t')" read -r l v; do
    case "$l" in CON) PC_CON="$v" ;; ORD) PC_ORD="$v" ;; RNG) PC_RNG="$v" ;; CBO) PC_CBO="$v" ;; PRS) PC_PRS="$v" ;; DIG) PC_DIG="$v" ;; esac
  done < "$WORK/pc.alt"
  PC_ALL="CON {$PC_CON} ORD {$PC_ORD} RNG {$PC_RNG} CBO {$PC_CBO} PRS {$PC_PRS} DIG {$PC_DIG}"
  [ "$(grep -c . "$WORK/pc.alt")" = 6 ]
}
pc_root() { printf '%s' "${1%/_bmad-output/planning-artifacts/s*}"; } # <sprint dir> -> its world root
# PC1: a REPACK. p1's seven one-section parts; the repair grows Section 2 by twenty lines and edits Section 4, so
# the packer's target rises and the map becomes five parts {S1, S2, S3+S4, S5+S6, S7}: every boundary after part 2
# moved, and ordinals 3-5 hold other sections. Owed {2 3 4} -- the grown S2, the part holding the edited S4, the
# part holding the cited S6 -- and NOT part 5 (S7, byte-identical at another ordinal). An ordinal or line-range
# join owes {2 3 4 5}.
p_pc1() {
  local s doc; s="$(dvrs_doc_world)" || return 1; doc="$s/test-strategy.md"
  awk '{ print } /^sec2 line 15 of/ { for (i = 1; i <= 20; i++) print "grown line " i " of section two, carrying prose to weigh something." } /^sec4 line 3 of/ { print "Repaired line." }' \
    "$doc" > "$doc.n" && mv "$doc.n" "$doc" || return 1
  pc_cur document "$s/test-strategy-adversarial-p1.md" "$doc" && pc_alt document 6 || return 1
  [ "$(grep -c . "$WORK/pc.cmap")" = 5 ] && [ "$PC_CON" = "2 3 4" ] && [ "$PC_ORD" != "2 3 4" ] && [ "$PC_RNG" != "2 3 4" ] \
    || { PC_WHY="seed does not discriminate: $PC_ALL"; return 1; }
  dv_map "$1" "$s" test-strategy-p2 --document "$doc" < /dev/null
  [ "$RC" -eq 0 ] && [ "$DV_ORDS" = "2 3 4" ] && has "$WORK/dv.err" "derived from test-strategy-adversarial-p1.md" && ! has "$WORK/dv.err" "full width"
}
# PCD: TWO IDENTICAL PARTS, BOTH OWED. The repair rewrites Section 3 into a byte copy of Section 5 (heading and
# body): part 3 changed, and part 5, unchanged, now shares its digest with it. Owed {3 5 6}: a digest is unchanged
# only when it is UNIQUE on both sides. A join that asks only whether the digest is PRESENT in p1 owes {6}.
p_pcd() {
  local s doc; s="$(dvrs_doc_world)" || return 1; doc="$s/test-strategy.md"
  awk '/^## Section 5$/ { c = 1 } c && /^## Section 6$/ { c = 0 } c { B[++n] = $0 } { L[NR] = $0 }
    END { for (i = 1; i <= NR; i++) { if (L[i] == "## Section 3") { for (j = 1; j <= n; j++) print B[j]; s = 1; continue }
          if (s && L[i] == "## Section 4") s = 0; if (!s) print L[i] } }' "$doc" > "$doc.n" && mv "$doc.n" "$doc" || return 1
  pc_cur document "$s/test-strategy-adversarial-p1.md" "$doc" && pc_alt document 6 || return 1
  [ "$PC_CON" = "3 5 6" ] && [ "$PC_PRS" != "3 5 6" ] || { PC_WHY="seed does not discriminate: $PC_ALL"; return 1; }
  dv_map "$1" "$s" test-strategy-p2 --document "$doc" < /dev/null
  [ "$RC" -eq 0 ] && [ "$DV_ORDS" = "3 5 6" ] && ! has "$WORK/dv.err" "full width"
}
# THE CUT-TABLE RUN (B1), NOTARIZED. partition-document.sh --part-sha prints one `run:<o>,<o>,...` line per cut
# table that spans two or more parts; the merge writes them as `part_run:` (`-` when none, runs joined by `;`)
# and derive_set owes a run whole when any member is owed, reading no heading. tbl_build is the engine's own
# probe shape: `## Section 1` of <s1> prose lines, `## Section 2` holding a header, a separator and <n> rows, then
# <k> sections of <s3> lines; p1 merged, no finding.
tbl_build() { # <s1> <n> <k> <s3> -> the s1 dir
  local w pa s doc d o x i j k
  w="$(mktemp -d "$WORK/tw.XXXXXX")" || return 1
  pa="$w/_bmad-output/planning-artifacts"; s="$pa/s1"; doc="$s/test-strategy.md"; d="$s/shards/test-strategy-p1"
  mkdir -p "$d" && dv_root "$w" || return 1
  { printf '# T\n\n## Section 1\n\n'; for i in $(seq 1 "$1"); do echo "one line $i of prose carrying weight here"; done
    printf '\n## Section 2\n\n| Col A | Col B |\n|---|---|\n'
    for i in $(seq 1 "$2"); do printf '| row %03d carrying a cell of prose | value %03d |\n' "$i" "$i"; done
    for j in $(seq 3 $((2 + $3))); do printf '\n## Section %s\n\n' "$j"; for i in $(seq 1 "$4"); do echo "sec $j line $i of prose"; done; done; } > "$doc"
  bash "$PARTITION" --map "$doc" < /dev/null > "$w/t.map" 2>/dev/null || return 1
  k="$(grep -c . "$w/t.map")" || k=0
  for o in $(cut -f1 "$w/t.map"); do dshard "$d" "$((10#$o))" 0 EXIT_CONDITION_NOT_MET "$((10#$o))"; done
  for x in $(xkeys "$k"); do dshard "$d" "$x" 0 EXIT_CONDITION_NOT_MET "1, 2"; done
  $ASM_RUN "$MERGE" --document "$doc" "$d" < /dev/null > /dev/null 2>&1 && [ -f "$s/test-strategy-adversarial-p1.md" ] || return 1
  printf '%s' "$s"
}
tbl_world() { wc_get "tbl$1x$2x$3x$4" tbl_build "$@"; }
# pc_run <pass file> -> PC_RUN (the members of its part_run:, space-joined; empty for `-`), PC_NRUN (runs)
pc_run() {
  local v; v="$(sed -n 's/^part_run: *//p' "$1" | head -1)"
  PC_NRUN=0; PC_RUN=""
  [ -n "$v" ] && [ "$v" != - ] || return 0
  PC_NRUN="$(printf '%s\n' "$v" | tr ';' '\n' | grep -c .)" || PC_NRUN=0
  PC_RUN="$(printf '%s\n' "$v" | tr ';,' '  ')"
}
tbl_hdr_edit() { sed 's/^| Col A | Col B |$/| Col X | Col Y |/' "$1" > "$1.n" && mv "$1.n" "$1"; }
# pc_hdr_row -> the current ordinal of the row holding the table's header line (pc.cmap, after pc_cur)
pc_hdr_row() {
  local h; h="$(grep -n '^| Col [AX] | Col [BY] |$' "$1" | head -1 | cut -d: -f1)"
  awk -F'\t' -v h="$h" '$3 <= h + 0 && h + 0 <= $4 { print ($1 + 0) "\t" $5 }' "$WORK/pc.cmap"
}
# PCT (B1): a 260-row table cut into a run of parts -- PCC's world (an 80-line Section 1 its own row, the run from
# row 2), shared rather than built a second time: its run is the long run this arm needs, and the packed-header
# shape is PCT2's. The repair renames the header cells, so only the run's first piece changes. Owed: every member
# of p1's notarized run. The seed holds first: one run of two or more parts, the content join (no run) owes exactly
# ONE part, a member of that run.
p_pct() {
  local s doc p1; s="$(tbl_world 80 260 1 12)" || return 1; doc="$s/test-strategy.md"; p1="$s/test-strategy-adversarial-p1.md"
  pc_run "$p1"; tbl_hdr_edit "$doc" || return 1
  pc_cur document "$p1" "$doc" && pc_alt document "" || return 1
  [ "$PC_NRUN" = 1 ] && [ "$(printf '%s\n' $PC_RUN | grep -c .)" -ge 2 ] && [ "$(printf '%s\n' $PC_CON | grep -c .)" = 1 ] \
    && case " $PC_RUN " in *" $PC_CON "*) true ;; *) false ;; esac || { PC_WHY="seed does not discriminate: run [$PC_RUN] $PC_ALL"; return 1; }
  dv_map "$1" "$s" test-strategy-p2 --document "$doc" < /dev/null
  [ "$RC" -eq 0 ] && [ "$DV_ORDS" = "$PC_RUN" ] && ! has "$WORK/dv.err" "full width"
}
# PCT2 (B1, the two-piece shape the heading heuristic could not see): a 20-row table cut into EXACTLY two pieces,
# the header piece packed under `## Section 1`, so `## Section 2` heads one row only. The header changed: BOTH owed.
# The seed holds first: the header's row is headed otherwise than `## Section 2`, one row is, the run has exactly
# two members, and the content join owes the header's row alone. Ignoring the run owes {1}.
p_pct2() {
  local s doc p1 hh n2; s="$(tbl_world 3 20 1 30)" || return 1; doc="$s/test-strategy.md"; p1="$s/test-strategy-adversarial-p1.md"
  pc_run "$p1"; tbl_hdr_edit "$doc" || return 1
  pc_cur document "$p1" "$doc" && pc_alt document "" || return 1
  hh="$(pc_hdr_row "$doc")"; n2="$(awk -F'\t' '$5 == "## Section 2"' "$WORK/pc.cmap" | grep -c .)" || n2=0
  [ "$(printf '%s' "$hh" | cut -f2)" != "## Section 2" ] && [ "$n2" = 1 ] && [ "$(printf '%s\n' $PC_RUN | grep -c .)" = 2 ] \
    && [ "$PC_CON" = "$(printf '%s' "$hh" | cut -f1)" ] || { PC_WHY="seed shape: header row [$hh] Section-2 rows $n2 run [$PC_RUN] $PC_ALL"; return 1; }
  dv_map "$1" "$s" test-strategy-p2 --document "$doc" < /dev/null
  [ "$RC" -eq 0 ] && [ "$DV_ORDS" = "$PC_RUN" ] && ! has "$WORK/dv.err" "full width"
}
# PCC: a PLAIN row BEFORE a run (an 80-line Section 1, then the 260-row table's run from row 2). An edit to row 1
# owes row 1 only: the run is the cut table's pieces, never its neighbour. The seed holds first: row 1 is outside
# the run and the run starts at row 2. Widening a run to the row before it owes {1} plus the whole run.
p_pcc() {
  local s doc p1; s="$(tbl_world 80 260 1 12)" || return 1; doc="$s/test-strategy.md"; p1="$s/test-strategy-adversarial-p1.md"
  pc_run "$p1"
  sed 's/^one line 5 of prose carrying weight here$/one line 5 of prose carrying MORE weight/' "$doc" > "$doc.n" && mv "$doc.n" "$doc" || return 1
  pc_cur document "$p1" "$doc" && pc_alt document "" || return 1
  [ "$PC_NRUN" = 1 ] && [ "${PC_RUN%% *}" = 2 ] && [ "$PC_CON" = 1 ] || { PC_WHY="seed shape: run [$PC_RUN] $PC_ALL"; return 1; }
  dv_map "$1" "$s" test-strategy-p2 --document "$doc" < /dev/null
  [ "$RC" -eq 0 ] && [ "$DV_ORDS" = 1 ] && ! has "$WORK/dv.err" "full width"
}
# PCSR: a SUBJECT cut-table run, mapped onto GLOBAL ordinals. Since base, prd gained a `## Table` of 260 rows that the
# scoped map cuts into pieces; partition-document.sh --part-sha --rows --scope-ref names the run in prd's local
# ordinals and maps it onto the subject's rows by (file, first, last). The header renamed: owed, every member. The
# seed holds first: p1 carries one run of two or more members, every member is a prd.md row of p1's map, the header
# line lies inside the FIRST member, and the content join owes that member alone.
dvst_build() { # -> the s9 dir of a subject world whose prd gained a cut table since base, p1 merged, no finding
  local d w pa o i
  d="$(new_subj_world_build)" || return 1; w="$(subj_root "$d")"; pa="$w/$SUBJ_PA"
  { printf '\n## Table\n\n| Col A | Col B |\n|---|---|\n'
    for i in $(seq 1 260); do printf '| row %03d carrying a cell of prose | value %03d |\n' "$i" "$i"; done
    printf '\n## After\n\n'; slorem after 12; } >> "$pa/prd.md"
  AI_DLC_PROJECT_ROOT="$w" bash "$SRCDIR/partition-subject.sh" --map 9 > "$w/subject.map" 2>&1 || return 1
  dv_root "$w" || return 1
  for o in $(cut -f1 "$w/subject.map"); do sshard "$d" "$o" 0 "$((10#$o))" "" "" EXIT_CONDITION_NOT_MET; done
  for o in $(subj_xkeys "$d"); do sshard "$d" "$o" 0 "1, 2" "" "" EXIT_CONDITION_NOT_MET; done
  $ASM_RUN "$MERGE" --subject 9 "$d" < /dev/null > /dev/null 2>&1 && [ -f "$(subj_out_of "$d")" ] || return 1
  printf '%s' "$(dirname "$(dirname "$d")")"
}
dvst_world() { wc_get dvst dvst_build; }
p_pcsr() {
  local s w p1 prd h f a z o bad=0; s="$(dvst_world)" || return 1; w="$(pc_root "$s")"; p1="$s/requirements-adversarial-p1.md"; prd="$w/$SUBJ_PA/prd.md"
  pc_run "$p1"; h="$(grep -n '^| Col A | Col B |$' "$prd" | head -1 | cut -d: -f1)"
  tbl_hdr_edit "$prd" || return 1
  pc_cur subject "$p1" "$w" && pc_alt subject "" || return 1
  for o in $PC_RUN; do
    f="$(awk -F'\t' -v o="$o" '$1 + 0 == o + 0 { print $2 }' "$WORK/pc.pmap")"; case "$f" in */prd.md) ;; *) bad=1 ;; esac
  done
  a="$(awk -F'\t' -v o="${PC_RUN%% *}" '$1 + 0 == o + 0 { print $3 }' "$WORK/pc.pmap")"; z="$(awk -F'\t' -v o="${PC_RUN%% *}" '$1 + 0 == o + 0 { print $4 }' "$WORK/pc.pmap")"
  [ "$PC_NRUN" = 1 ] && [ "$(printf '%s\n' $PC_RUN | grep -c .)" -ge 2 ] && [ "$bad" = 0 ] && [ -n "$h" ] && [ -n "$a" ] \
    && [ "$a" -le "$h" ] && [ "$h" -le "$z" ] && [ "$PC_CON" = "${PC_RUN%% *}" ] || { PC_WHY="seed shape: run [$PC_RUN] header line $h first member $a-$z $PC_ALL"; return 1; }
  dv_map "$1" "$s" requirements-p2 --subject 9 < /dev/null
  [ "$RC" -eq 0 ] && [ "$DV_ORDS" = "$PC_RUN" ] && ! has "$WORK/dv.err" "full width"
}
# PCS: SUBJECT mode, keyed (file, digest). p1's six parts {brief, SPEC, prd Sprint 9, Goals, Requirements, arch}
# with p1's MAJOR on part 2 (SPEC). The repair REVERTS the brief to base, so its part LEAVES the subject and every
# later ordinal drops by one; grows Goals by five lines (Requirements' boundaries move); edits Requirements in
# place. Owed {1 3 4}: the cited SPEC at its new ordinal 1, Goals, Requirements. Ordinal and range joins owe the
# whole map; a cite read as a current ordinal owes {2 3 4}.
p_pcs() {
  local s w pa; s="$(dvrs_subj_world)" || return 1; w="$(pc_root "$s")"; pa="$w/$SUBJ_PA"
  grep -v '^A new brief line\.$' "$pa/product-brief.md" > "$pa/product-brief.md.n" && mv "$pa/product-brief.md.n" "$pa/product-brief.md" || return 1
  awk '{ print } /^s9g line 30 of/ { for (i = 1; i <= 5; i++) print "grown goal " i " carrying enough prose to weigh something real." }
    /^s9r line 3 of/ { print "A repaired requirement line." }' "$pa/prd.md" > "$pa/prd.md.n" && mv "$pa/prd.md.n" "$pa/prd.md" || return 1
  pc_cur subject "$s/requirements-adversarial-p1.md" "$w" && pc_alt subject 2 || return 1
  [ "$(cut -f2 "$WORK/pc.cmap" | grep -c 'product-brief')" = 0 ] && [ "$PC_CON" = "1 3 4" ] && [ "$PC_ORD" != "1 3 4" ] \
    && [ "$PC_RNG" != "1 3 4" ] && [ "$PC_CBO" = "2 3 4" ] || { PC_WHY="seed does not discriminate: $PC_ALL"; return 1; }
  dv_map "$1" "$s" requirements-p2 --subject 9 < /dev/null
  [ "$RC" -eq 0 ] && [ "$DV_ORDS" = "1 3 4" ] && ! has "$WORK/dv.err" "full width"
}
# PCS2: THE SAME BYTES IN TWO FILES. The repair rewrites SPEC.md into a byte copy of architecture-impact.md. Keyed
# (file, digest), SPEC changed and arch did not: owed {2}. Keyed on the digest alone the two parts are a duplicate
# and both are owed: {2 6}.
p_pcs2() {
  local s w pa; s="$(dvrs_subj_world)" || return 1; w="$(pc_root "$s")"; pa="$w/$SUBJ_PA"
  cp "$pa/s9/architecture-impact.md" "$w/_bmad-output/specs/s9/kernel/SPEC.md" || return 1
  pc_cur subject "$s/requirements-adversarial-p1.md" "$w" && pc_alt subject 2 || return 1
  [ "$PC_CON" = 2 ] && [ "$PC_DIG" != 2 ] || { PC_WHY="seed does not discriminate: $PC_ALL"; return 1; }
  dv_map "$1" "$s" requirements-p2 --subject 9 < /dev/null
  [ "$RC" -eq 0 ] && [ "$DV_ORDS" = 2 ] && ! has "$WORK/dv.err" "full width"
}
# pc_ds <merge> <pass file> -> DS_ORDS, DS_FULL (the FULL reason, empty when narrowed), DS_RC: --derived-set.
pc_ds() {
  $ASM_RUN "$1" --derived-set "$2" < /dev/null > "$WORK/pc.ds" 2>&1; DS_RC=$?
  DS_ORDS="$(awk -F'\t' 'NF == 1 && /^[0-9]+$/ { printf "%s%d", (n++ ? " " : ""), $1 }' "$WORK/pc.ds")"
  DS_FULL="$(awk -F'\t' '$1 == "FULL" { print $2; exit }' "$WORK/pc.ds")"
}
# pc_fw -> the `full width:` reason --derived-map printed (dv_map's stderr), empty when none.
pc_fw() { sed -n 's/^# derived from [^ ]* (full width: \(.*\))$/\1/p' "$WORK/dv.err" | head -1; }
# pc_full <merge> <sprint dir> <want reason> [<full map ordinals>] -> 0 when --derived-map AND --derived-set (on a
# p2 that is p1's copy) both owe the full map (default: the seven-part test-strategy) with a reason containing
# <want reason>, the two reasons byte-identical.
pc_full() {
  local r1 fm="${4:-1 2 3 4 5 6 7}"
  dv_map "$1" "$2" test-strategy-p2 --document "$2/test-strategy.md" < /dev/null; r1="$(pc_fw)"
  [ "$RC" -eq 0 ] && [ "$DV_ORDS" = "$fm" ] || { PC_WHY="derived-map rc=$RC [$DV_ORDS] [$r1]"; return 1; }
  pc_ds "$1" "$2/test-strategy-adversarial-p2.md"
  [ "$DS_RC" -eq 0 ] && [ "$DS_ORDS" = "$fm" ] && [ -n "$DS_FULL" ] && [ "$DS_FULL" = "$r1" ] \
    && case "$r1" in *"$3"*) true ;; *) false ;; esac || { PC_WHY="derived-set rc=$DS_RC [$DS_ORDS] [$DS_FULL] vs [$r1], want [$3]"; return 1; }
}
pc_p2() { cp "$1/test-strategy-adversarial-p1.md" "$1/test-strategy-adversarial-p2.md"; } # <sprint dir>: a p2 carrying p1's record
# PCK (K4): EVERY UNJOINABLE LIST FALLS TO FULL WIDTH WITH ITS REASON, the same in the merge (--derived-map) and in
# the gate's recomputation (--derived-set). ONE ARM PER CELL (PCKa..PCKh), so a fallback mutant re-runs only the
# cell it breaks (fixture-mutants.md, one run per distinct state); PCK itself holds the two CONTROLS, each world's
# narrowed answer in both channels -- the unedited document world {6}, and PCC's world with row 1 edited {1} --
# so a full map in a cell is the fallback and not the world. Cells: (a) p1 without part_sha (an older engine
# merged it); (b) pass M (--derived-set only) without its own list while p1 has one -- never narrowed; (c) a
# malformed p1 token; (d) p1's list one entry short of its map; (e) p1 without `part_run:`; (f) pass M
# (--derived-set) without its own `part_run:`; (g) p1's run naming an ordinal outside its map; (h) a run of one
# member. Every cell takes its own fresh copy of a cached world (wc_get), so no cell or mutant re-run reads
# another's edits.
p_pck() {
  local m="$1" s
  s="$(dvrs_doc_world)" || return 1; pc_p2 "$s" || return 1
  dv_map "$m" "$s" test-strategy-p2 --document "$s/test-strategy.md" < /dev/null; pc_ds "$m" "$s/test-strategy-adversarial-p2.md"
  [ "$RC" -eq 0 ] && [ "$DV_ORDS" = 6 ] && [ "$DS_ORDS" = 6 ] && [ -z "$DS_FULL" ] || { PC_CELL=control; PC_WHY="[$DV_ORDS] [$DS_ORDS] [$DS_FULL]"; return 1; }
  s="$(pcc_edited)" || return 1; pc_p2 "$s" || return 1
  dv_map "$m" "$s" test-strategy-p2 --document "$s/test-strategy.md" < /dev/null; pc_ds "$m" "$s/test-strategy-adversarial-p2.md"
  [ "$RC" -eq 0 ] && [ "$DV_ORDS" = 1 ] && [ -z "$DS_FULL" ] || { PC_CELL=run-control; PC_WHY="[$DV_ORDS] [$DS_ORDS] [$DS_FULL]"; return 1; }
}
p_pcka() {
  local s p1; s="$(dvrs_doc_world)" || return 1; p1="$s/test-strategy-adversarial-p1.md"
  sed '/^part_sha:/d' "$p1" > "$p1.n" && mv "$p1.n" "$p1" && pc_p2 "$s" || return 1
  PC_CELL=a; pc_full "$1" "$s" "test-strategy-adversarial-p1.md carries no part_sha list (merged by an engine before document-mode narrowing)"
}
p_pckb() {
  local s; s="$(dvrs_doc_world)" || return 1; pc_p2 "$s" || return 1
  sed '/^part_sha:/d' "$s/test-strategy-adversarial-p2.md" > "$s/p2.n" && mv "$s/p2.n" "$s/test-strategy-adversarial-p2.md" || return 1
  PC_CELL=b; pc_ds "$1" "$s/test-strategy-adversarial-p2.md"
  [ "$DS_RC" -eq 0 ] && [ "$DS_ORDS" = "1 2 3 4 5 6 7" ] && [ "$DS_FULL" = "test-strategy-adversarial-p2.md carries no part_sha list of its own, so the set it owed cannot be recomputed" ] \
    || { PC_WHY="rc=$DS_RC [$DS_ORDS] [$DS_FULL]"; return 1; }
}
p_pckc() {
  local s p1; s="$(dvrs_doc_world)" || return 1; p1="$s/test-strategy-adversarial-p1.md"
  sed 's/^\(part_sha: 1=\)[0-9a-f]/\1/' "$p1" > "$p1.n" && mv "$p1.n" "$p1" && pc_p2 "$s" || return 1
  PC_CELL=c; pc_full "$1" "$s" "the part_sha of test-strategy-adversarial-p1.md is malformed: token 1="
}
p_pckd() {
  local s p1; s="$(dvrs_doc_world)" || return 1; p1="$s/test-strategy-adversarial-p1.md"
  sed 's/^\(part_sha:.*\) 7=[0-9a-f]*$/\1/' "$p1" > "$p1.n" && mv "$p1.n" "$p1" && pc_p2 "$s" || return 1
  PC_CELL=d; pc_full "$1" "$s" "the part_sha of test-strategy-adversarial-p1.md lists 6 parts but its shard ordinal map has 7 rows"
}
p_pcke() {
  local s p1 fm; s="$(pcc_edited)" || return 1; p1="$s/test-strategy-adversarial-p1.md"; fm="$(pc_fm "$p1")"
  sed '/^part_run:/d' "$p1" > "$p1.n" && mv "$p1.n" "$p1" && pc_p2 "$s" || return 1
  PC_CELL=e; pc_full "$1" "$s" "test-strategy-adversarial-p1.md carries no part_run list (merged by an engine before cut-table runs were notarized)" "$fm"
}
p_pckf() {
  local s fm; s="$(pcc_edited)" || return 1; pc_p2 "$s" || return 1; fm="$(pc_fm "$s/test-strategy-adversarial-p1.md")"
  sed '/^part_run:/d' "$s/test-strategy-adversarial-p2.md" > "$s/p2.n" && mv "$s/p2.n" "$s/test-strategy-adversarial-p2.md" || return 1
  PC_CELL=f; pc_ds "$1" "$s/test-strategy-adversarial-p2.md"
  [ "$DS_RC" -eq 0 ] && [ "$DS_ORDS" = "$fm" ] && [ "$DS_FULL" = "test-strategy-adversarial-p2.md carries no part_run list of its own, so the set it owed cannot be recomputed" ] \
    || { PC_WHY="rc=$DS_RC [$DS_ORDS] [$DS_FULL]"; return 1; }
}
p_pckg() {
  local s p1 fm; s="$(pcc_edited)" || return 1; p1="$s/test-strategy-adversarial-p1.md"; fm="$(pc_fm "$p1")"
  awk '/^part_run:/ { print "part_run: 2,99"; next } { print }' "$p1" > "$p1.n" && mv "$p1.n" "$p1" && pc_p2 "$s" || return 1
  PC_CELL=g; pc_full "$1" "$s" "the part_run of test-strategy-adversarial-p1.md names ordinal 99, outside its shard ordinal map" "$fm"
}
p_pckh() {
  local s p1 fm; s="$(pcc_edited)" || return 1; p1="$s/test-strategy-adversarial-p1.md"; fm="$(pc_fm "$p1")"
  awk '/^part_run:/ { print "part_run: 2"; next } { print }' "$p1" > "$p1.n" && mv "$p1.n" "$p1" && pc_p2 "$s" || return 1
  PC_CELL=h; pc_full "$1" "$s" "the part_run of test-strategy-adversarial-p1.md is malformed: run 2 is not <ordinal>,<ordinal>[,...]" "$fm"
}
# pc_fm <pass file> -> its embedded map's ordinals, space-joined
pc_fm() { awk '/^## Shard ordinal map[ \t]*$/ { s = 1; next } s == 1 && /^```/ { s = 2; next } s == 2 && /^```/ { exit } s == 2 { printf "%s%d", (n++ ? " " : ""), $1 }' "$1"; }
# pcc_edited -> a copy of PCC's world with row 1 edited (the narrowed answer {1})
pcc_edited() {
  local s; s="$(tbl_world 80 260 1 12)" || return 1
  sed 's/^one line 5 of prose carrying weight here$/one line 5 of prose carrying MORE weight/' "$s/test-strategy.md" > "$s/test-strategy.md.n" \
    && mv "$s/test-strategy.md.n" "$s/test-strategy.md" && printf '%s' "$s"
}
# PCR: AN IDENTICAL RE-MERGE OVER AN OLD-ENGINE PASS ANSWERS AS IT DID AT BASE. The document world's p1 rewritten
# as an engine before part_sha wrote it (its part_sha: and part_run: lines removed), then its OWN p1 shards merged
# again: `UNCHANGED:`, rc 0, the pass file byte-for-byte as it was -- never a refusal for the field the old engine
# could not write, and never an overwrite that adds it. The control: the same re-merge over the CURRENT engine's p1
# is UNCHANGED too, so the old-engine cell is not passing on a re-merge that answers UNCHANGED to anything; and a
# p1 with one counted field changed still REFUSES (`already exists and differs`), so the tolerance is the two
# fields and nothing else. --dry-run answers the old-engine pass alike (clean), and a pass carrying part_sha: but
# no part_run: -- either field present -- is compared byte for byte and refuses.
p_pcr() {
  local m="$1" s p1 d
  s="$(dvrs_doc_world)" || return 1; p1="$s/test-strategy-adversarial-p1.md"; d="$s/shards/test-strategy-p1"
  $ASM_RUN "$m" --document "$s/test-strategy.md" "$d" < /dev/null > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && has "$MO" "UNCHANGED: " || { PC_CELL=control; PC_WHY="rc=$RC $(head -1 "$MO")"; return 1; }
  s="$(dvrs_doc_world)" || return 1; p1="$s/test-strategy-adversarial-p1.md"; d="$s/shards/test-strategy-p1"
  sed '/^part_sha:/d; /^part_run:/d' "$p1" > "$WORK/pcr.old" && cp "$WORK/pcr.old" "$p1" || return 1
  ! has "$p1" "part_sha:" || return 1
  $ASM_RUN "$m" --document "$s/test-strategy.md" "$d" < /dev/null > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && has "$MO" "UNCHANGED: " && cmp -s "$WORK/pcr.old" "$p1" || { PC_CELL=old; PC_WHY="rc=$RC $(head -1 "$MO")"; return 1; }
  $ASM_RUN "$m" --dry-run --document "$s/test-strategy.md" "$d" < /dev/null > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && has "$MO" "DRY-RUN: clean" && cmp -s "$WORK/pcr.old" "$p1" || { PC_CELL=old-dry-run; PC_WHY="rc=$RC $(head -1 "$MO")"; return 1; }
  # part_sha: kept, part_run: gone -- a shape no engine writes: compared byte for byte, so it REFUSES.
  s="$(dvrs_doc_world)" || return 1; p1="$s/test-strategy-adversarial-p1.md"; d="$s/shards/test-strategy-p1"
  sed '/^part_run:/d' "$p1" > "$WORK/pcr.half" && cp "$WORK/pcr.half" "$p1" && has "$p1" "part_sha:" || return 1
  $ASM_RUN "$m" --document "$s/test-strategy.md" "$d" < /dev/null > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$MO" "already exists and differs from this merge" && cmp -s "$WORK/pcr.half" "$p1" || { PC_CELL=half; PC_WHY="rc=$RC $(head -1 "$MO")"; return 1; }
  s="$(dvrs_doc_world)" || return 1; p1="$s/test-strategy-adversarial-p1.md"; d="$s/shards/test-strategy-p1"
  sed '/^part_sha:/d; /^part_run:/d; s/^findings_minor: .*/findings_minor: 9/' "$p1" > "$WORK/pcr.dif" && cp "$WORK/pcr.dif" "$p1" || return 1
  $ASM_RUN "$m" --document "$s/test-strategy.md" "$d" < /dev/null > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$MO" "already exists and differs from this merge" && cmp -s "$WORK/pcr.dif" "$p1" || { PC_CELL=differs; PC_WHY="rc=$RC $(head -1 "$MO")"; return 1; }
  # Subject mode, the same old-engine shape: p1 of the subject world without its part_sha:/part_run:.
  s="$(dvrs_subj_world)" || return 1; p1="$s/requirements-adversarial-p1.md"; d="$s/shards/requirements-p1"
  sed '/^part_sha:/d; /^part_run:/d' "$p1" > "$WORK/pcr.sold" && cp "$WORK/pcr.sold" "$p1" || return 1
  $ASM_RUN "$m" --subject 9 "$d" < /dev/null > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && has "$MO" "UNCHANGED: " && cmp -s "$WORK/pcr.sold" "$p1" || { PC_CELL=subject-old; PC_WHY="rc=$RC $(head -1 "$MO")"; return 1; }
}
# pc_era <world root> <legacy|notoken>: the world's history replaced (an orphan branch) by a rulebook WITHOUT the
# NARROW_ERA_TOKEN sentence committed 2026-01-01 -- the cap's ERA_TOKEN kept, so the files-mode era still binds --
# and, for legacy, the real rulebook committed 2026-09-01, after the series' first pass (2026-08-24).
pc_era() {
  local rb="$1/.claude/skills/ai-dlc/steps/_gate-procedures.md"
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
    g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$1" -c user.name=f -c user.email=f@example.invalid \
          -c core.hooksPath=/dev/null -c commit.gpgsign=false "${@:2}"; }
    g "$1" checkout -q --orphan "era-$2" && sed 's/narrows by part content/narrows by part bytes/g' "$RULEBOOK" > "$rb" \
      && g "$1" add .claude && GIT_COMMITTER_DATE=2026-01-01T00:00:00Z GIT_AUTHOR_DATE=2026-01-01T00:00:00Z g "$1" commit -q -m stripped || exit 1
    [ "$2" = legacy ] || exit 0
    cp "$RULEBOOK" "$rb" && g "$1" add .claude && GIT_COMMITTER_DATE=2026-09-01T00:00:00Z GIT_AUTHOR_DATE=2026-09-01T00:00:00Z g "$1" commit -q -m token ) >/dev/null 2>&1 || return 1
  if [ "$2" = legacy ]; then has "$rb" "narrows by part content"; else ! has "$rb" "narrows by part content" && has "$rb" "A p3 that does not stamp"; fi
}
# PCE (D1): THE NARROWING ERA, each state on the unedited document world (narrowed: {6}, PCK's control). LEGACY (the
# sentence committed after the series opened) and NOTOKEN (no sentence installed) each owe the full map with
# their reason, the same in --derived-map and --derived-set.
p_pce() {
  local m="$1" s
  s="$(dvrs_doc_world)" || return 1; pc_era "$(pc_root "$s")" legacy && pc_p2 "$s" || { PC_WHY="legacy world did not build"; return 1; }
  PC_CELL=legacy; pc_full "$m" "$s" "document mode narrows only a series opened after the installed rulebook's 'narrows by part content' sentence was committed; this series is LEGACY" || return 1
  s="$(dvrs_doc_world)" || return 1; pc_era "$(pc_root "$s")" notoken && pc_p2 "$s" || { PC_WHY="notoken world did not build"; return 1; }
  PC_CELL=notoken; pc_full "$m" "$s" "the installed rulebook carries no 'narrows by part content' sentence, so document mode is not narrowed"
}
# ---- THE TIP-ADVERSARY FIXES, EACH SHOWN ABLE TO FIRE (BL-911). Every arm fires on a seeded offender AND stays
# quiet on its near-miss in the same arm.
# PCKm (D2): d_prun checks EVERY run before printing any, so a malformed run AFTER a good one still falls to full
# width. PCC's world, row 1 edited: p1's part_run replaced by (control, narrows) a good-only `1,2` -> {1}, no
# full-width reason; (near-miss, first position, which print-as-you-go also caught) `3;1,2` -> FULL; and three bad
# runs in SECOND position, each FULL with its reason in --derived-map and --derived-set alike: `1,2;3` (malformed),
# `1,2;2,3` (twice), `1,2;3,99` (outside the map). Printing the good run before the bad one owes {1} for all three.
pckm_cell() { # <merge> <part_run value> -> the sprint dir of a fresh copy whose p1 (and p2, its copy) carry it
  local s p1; s="$(pcc_edited)" || return 1; p1="$s/test-strategy-adversarial-p1.md"
  awk -v v="$2" '/^part_run:/ { print "part_run: " v; next } { print }' "$p1" > "$p1.n" && mv "$p1.n" "$p1" && pc_p2 "$s" || return 1
  grep -qx "part_run: $2" "$p1" && printf '%s' "$s"
}
p_pckm() {
  local m="$1" s fm lb="test-strategy-adversarial-p1.md"
  s="$(pckm_cell "$m" 1,2)" || return 1; fm="$(pc_fm "$s/test-strategy-adversarial-p1.md")"
  dv_map "$m" "$s" test-strategy-p2 --document "$s/test-strategy.md" < /dev/null; pc_ds "$m" "$s/test-strategy-adversarial-p2.md"
  [ "$RC" -eq 0 ] && [ "$DV_ORDS" = 1 ] && [ -z "$(pc_fw)" ] && [ "$DS_RC" -eq 0 ] && [ -z "$DS_FULL" ] \
    || { PC_CELL=good; PC_WHY="[$DV_ORDS] [$(pc_fw)] [$DS_FULL]"; return 1; }
  case " $fm " in *" 3 "*) ;; *) PC_CELL=seed; PC_WHY="the map [$fm] has no ordinal 3"; return 1 ;; esac
  s="$(pckm_cell "$m" '3;1,2')" || return 1
  PC_CELL=first; pc_full "$m" "$s" "the part_run of $lb is malformed: run 3 is not <ordinal>,<ordinal>[,...]" "$fm" || return 1
  s="$(pckm_cell "$m" '1,2;3')" || return 1
  PC_CELL=second-malformed; pc_full "$m" "$s" "the part_run of $lb is malformed: run 3 is not <ordinal>,<ordinal>[,...]" "$fm" || return 1
  s="$(pckm_cell "$m" '1,2;2,3')" || return 1
  PC_CELL=second-twice; pc_full "$m" "$s" "the part_run of $lb names ordinal 2 twice" "$fm" || return 1
  s="$(pckm_cell "$m" '1,2;3,99')" || return 1
  PC_CELL=second-outside; pc_full "$m" "$s" "the part_run of $lb names ordinal 99, outside its shard ordinal map" "$fm"
}
# PCMV (D1): a subject file that MOVES between the part-digest hashing and the check is refused, nothing written.
# THE SEAM is in process and runs the shipped code: mx sources the merge, MX_HOOK renames the merge's own sha_of
# (declare -f, its body unchanged) and wraps it so that, the first time it is asked to hash SPEC.md AFTER the merge's
# part-digest list exists ($T/psha non-empty -- the hashing is done and the check loop is the next reader), it
# appends one line to SPEC.md and then hashes it with the shipped body. No merge logic is restated: the refusal, its
# text and the write that does not happen are all the merge's. Near-miss: the same re-merge of p1 with no hook is
# UNCHANGED; the sentinel proves the fault fired (a seam the merge never reached would read as a pass).
PCMV_HOOK='eval "$(declare -f sha_of | sed "1s/^sha_of /_mx_sha_of_shipped /")"
sha_of() {
  case "$1" in *"/$MX_FAULT_REL")
    if [ -n "${T:-}" ] && [ -s "$T/psha" ] && [ ! -e "$MX_FAULT_SENT" ]; then printf "moved\n" >> "$1"; : > "$MX_FAULT_SENT"; fi ;;
  esac
  _mx_sha_of_shipped "$1"
}'
p_pcmv() {
  local m="$1" s p1 d rel=_bmad-output/specs/s9/kernel/SPEC.md sent
  s="$(dvrs_subj_world)" || return 1; d="$s/shards/requirements-p1"; p1="$s/requirements-adversarial-p1.md"
  cp "$p1" "$WORK/pcmv.p1" || return 1
  mx "$m" --subject 9 "$d" < /dev/null > "$MO" 2>&1; RC=$?
  [ "$RC" -eq 0 ] && has "$MO" "UNCHANGED: " && cmp -s "$WORK/pcmv.p1" "$p1" || { PC_CELL=near-miss; PC_WHY="rc=$RC $(head -1 "$MO")"; return 1; }
  s="$(dvrs_subj_world)" || return 1; d="$s/shards/requirements-p1"; p1="$s/requirements-adversarial-p1.md"
  cp "$p1" "$WORK/pcmv.p1" || return 1; sent="$(mktemp -d "$WORK/pcmv.XXXXXX")/fired"
  MX_HOOK="$PCMV_HOOK" MX_FAULT_REL="$rel" MX_FAULT_SENT="$sent" mx "$m" --subject 9 "$d" < /dev/null > "$MO" 2>&1; RC=$?
  [ -e "$sent" ] || { PC_CELL=seam; PC_WHY="the fault never fired: rc=$RC $(head -1 "$MO")"; return 1; }
  [ "$RC" -eq 2 ] && has "$MO" "$rel moved while the subject's parts were hashed" && cmp -s "$WORK/pcmv.p1" "$p1" \
    || { PC_CELL=offender; PC_WHY="rc=$RC $(head -1 "$MO")"; return 1; }
}
# PCN2 (N2): partition-document.sh --part-sha --rows --scope-ref REFUSES when a file's scoped map fails (rc other than
# 0 or 3), never answers with that file's runs silently dropped. The seam is in process: the partition-document.sh
# beside the merge under test is SOURCED (as the merge sources it) and its own scope_lines is renamed and wrapped to
# chmod the scope list it just wrote to 000, so the shipped map_of cannot read it and exits 2. Near-miss: the same
# call unwrapped, on dvst's world (a table cut into a run inside prd), prints its run line and exits 0.
PCN2_HOOK='eval "$(declare -f scope_lines | sed "1s/^scope_lines /_pc_scope_lines_shipped /")"
scope_lines() { _pc_scope_lines_shipped "$@"; chmod 000 "$SCOPE_TMP"; }'
pcn2_call() { # <partition-document.sh> <root> <base> <rows file> <hook or empty> -> $WORK/pcn2.{out,err}, PCN2_RC
  ( . "$1" || exit 90; [ -z "$5" ] || eval "$5"; pdoc_main --part-sha --rows "$2" --scope-ref "$3" ) < "$4" > "$WORK/pcn2.out" 2> "$WORK/pcn2.err"
  PCN2_RC=$?
}
p_pcn2() {
  local m="$1" s w pd base; pd="$(dirname "$m")/partition-document.sh"; [ -f "$pd" ] || return 1
  s="$(dvst_world)" || return 1; w="$(pc_root "$s")"
  base="$(awk '/REQUIREMENTS_SUBJECT v1/ { i = 1; next } /REQUIREMENTS_SUBJECT_END/ { i = 0 } i && index($0, "base: ") == 1 { print substr($0, 7); exit }' "$s/requirements-subject.md")"
  [ -n "$base" ] || { PC_CELL=seed; PC_WHY="no base in the subject manifest"; return 1; }
  awk -F'\t' '/^## Shard ordinal map[ \t]*$/ { s = 1; next } s == 1 && /^```/ { s = 2; next } s == 2 && /^```/ { exit }
    s == 2 { print $1 "\t" $2 "\t" $3 "\t" $4 }' "$s/requirements-adversarial-p1.md" > "$WORK/pcn2.rows" || return 1
  [ -s "$WORK/pcn2.rows" ] || { PC_CELL=seed; PC_WHY="p1 embeds no map"; return 1; }
  pcn2_call "$pd" "$w" "$base" "$WORK/pcn2.rows" ""
  [ "$PCN2_RC" -eq 0 ] && has "$WORK/pcn2.out" "run:" || { PC_CELL=near-miss; PC_WHY="rc=$PCN2_RC $(head -1 "$WORK/pcn2.err")"; return 1; }
  pcn2_call "$pd" "$w" "$base" "$WORK/pcn2.rows" "$PCN2_HOOK"
  [ "$PCN2_RC" -ne 0 ] && has "$WORK/pcn2.err" "failed (rc=2); its cut-table runs are unknown" && ! has "$WORK/pcn2.out" "run:" \
    || { PC_CELL=offender; PC_WHY="rc=$PCN2_RC $(head -1 "$WORK/pcn2.err")"; return 1; }
}
# NDP (D4): arm N's DOCUMENT self-probe can fail. dvA's files world, p3 merged over the derived {3 6} (as DV10), so
# the gate reaches arm N and runs its self-probes. Near-miss: the validator beside the merge under test passes them
# (no 'self-probe failed', not exit 2). Offender: a copy of that same sibling set whose merge keeps document mode at
# full width (`bound)` answering a FULL reason for a document) -- the gate exits 2 naming the document self-probe.
ndp_world() { # <merge> -> NDP_S, a fresh dvA copy with p3 merged over the derived {3 6}, so the gate reaches arm N
  local m="$1" s d x o
  s="$(dvA_world)" || return 1; dv_map "$m" "$s" stories-p3 < /dev/null; [ "$RC" -eq 0 ] && [ "$DV_ORDS" = "3 6" ] || return 1
  d="$s/shards/stories-p3"; o="$s/stories-adversarial-p3.md"
  for x in 3 6; do shard "$d" "$x" 0 EXIT_CONDITION_MET "$x"; done
  for x in $(xkeys 8); do shard "$d" "$x" 0 EXIT_CONDITION_MET "3, 6"; done
  run_merge "$m" "$d"; [ "$RC" -eq 0 ] && [ -f "$o" ] || { PC_CELL=seed; PC_WHY="p3 did not merge: $(head -1 "$MO")"; return 1; }
  NDP_S="$s"
}
p_ndp() {
  local m="$1" s nd
  ndp_world "$m" || return 1; s="$NDP_S"
  bash "$(dirname "$m")/validate-adversarial-convergence.sh" --series "$s/stories-adversarial-p" < /dev/null > "$CO" 2>&1; RC=$?
  [ "$RC" -ne 2 ] && has "$CO" "pass artifact" && ! has "$CO" "self-probe failed" || { PC_CELL=near-miss; PC_WHY="rc=$RC $(grep -m1 'self-probe' "$CO")"; return 1; }
  nd="$(mktemp -d "$WORK/ndp.XXXXXX")" && cp "$(dirname "$m")"/*.sh "$nd/" || return 1
  M_OLD='      bound) ;;' M_NEW='      bound) if [ "$mode" = document ]; then D_FULL="document mode held at full width (NDP)"; return 0; fi ;;' \
    python3 - "$nd/merge-adversarial-shards.sh" <<'PY' || { PC_CELL=seed; PC_WHY="the forced-full copy did not apply"; return 1; }
import os, sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read(); o = os.environ["M_OLD"]
if t.count(o) != 1: sys.exit(3)
open(p, "w", encoding="utf-8").write(t.replace(o, os.environ["M_NEW"]))
PY
  bash "$nd/validate-adversarial-convergence.sh" --series "$s/stories-adversarial-p" < /dev/null > "$CO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$CO" "arm N document self-probe failed" || { PC_CELL=offender; PC_WHY="rc=$RC $(grep -m1 'self-probe' "$CO")"; return 1; }
}
# NDC (N4): arm N's document self-probe holds when TMPDIR sits INSIDE a git work tree. The probe's rulebook root is
# a mktemp dir under TMPDIR; era_resolve runs `git -C <root>`, and git never excludes its own working directory from
# discovery, so a ceiling AT the root lets it climb to the outer tree, where the probe's rulebook is untracked: LEGACY,
# FULL, and a gate that refuses every run of a correct engine. The shipped ceiling is the root's PARENT. One arm, both
# ways, on NDP's world with TMPDIR inside a `git init` tree under WORK (the positive control: git, asked from inside
# that TMPDIR, answers it is in a work tree): the shipped sibling set passes the probe (no 'document self-probe
# failed', exit other than 2); a copy whose ceiling is put back AT the root exits 2 naming it. The two validators are
# asserted to differ before either verdict is read.
p_ndc() {
  local m="$1" s g tp nd a; a='GIT_CEILING_DIRECTORIES="$AC_T" bash "$N_MERGE"'
  ndp_world "$m" || return 1; s="$NDP_S"
  g="$(mktemp -d "$WORK/ndc.XXXXXX")" && mkdir -p "$g/tmp" || return 1
  ( unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR
    GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$g" -c core.hooksPath=/dev/null init -q . ) >/dev/null 2>&1 || return 1
  tp="$g/tmp"
  [ "$(GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$tp" rev-parse --is-inside-work-tree 2>/dev/null)" = true ] \
    || { PC_CELL=control; PC_WHY="git does not see the outer tree from $tp"; return 1; }
  nd="$(mktemp -d "$WORK/ndc-v.XXXXXX")" && cp "$(dirname "$m")"/*.sh "$nd/" || return 1
  M_OLD="$a" M_NEW='GIT_CEILING_DIRECTORIES="$AC_T/nd" bash "$N_MERGE"' python3 - "$nd/validate-adversarial-convergence.sh" <<'PY' \
    || { PC_CELL=seed; PC_WHY="the root-ceiling copy did not apply"; return 1; }
import os, sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read(); o = os.environ["M_OLD"]
if t.count(o) != 1: sys.exit(3)
open(p, "w", encoding="utf-8").write(t.replace(o, os.environ["M_NEW"]))
PY
  ! cmp -s "$(dirname "$m")/validate-adversarial-convergence.sh" "$nd/validate-adversarial-convergence.sh" || { PC_CELL=seed; PC_WHY="the two validators are identical"; return 1; }
  TMPDIR="$tp" bash "$(dirname "$m")/validate-adversarial-convergence.sh" --series "$s/stories-adversarial-p" < /dev/null > "$CO" 2>&1; RC=$?
  [ "$RC" -ne 2 ] && has "$CO" "pass artifact" && ! has "$CO" "document self-probe failed" || { PC_CELL=shipped; PC_WHY="rc=$RC $(grep -m1 'self-probe' "$CO")"; return 1; }
  TMPDIR="$tp" bash "$nd/validate-adversarial-convergence.sh" --series "$s/stories-adversarial-p" < /dev/null > "$CO" 2>&1; RC=$?
  [ "$RC" -eq 2 ] && has "$CO" "arm N document self-probe failed" || { PC_CELL=root-ceiling; PC_WHY="rc=$RC $(grep -m1 'self-probe' "$CO")"; return 1; }
}
