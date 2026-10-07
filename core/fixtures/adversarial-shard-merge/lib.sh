# adversarial-shard-merge/lib.sh -- the resolution, seeds, worlds and predicates of
# adversarial-shard-merge, sourced by that fixture's run.sh (the behavioural arms, shipped) and by
# adversarial-shard-merge-mutants/run.sh (the mutation battery, distribution-only). ONE copy, so
# the battery scores the predicates the shipped arms run and never a second implementation of them.
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
CONV="$SRCDIR/validate-adversarial-convergence.sh"
[ -f "$CONV" ] || { echo "FIXTURE ERROR: $CONV is not beside the merge; it reads its ceilings from there" >&2; exit 2; }
# Section mode reads its ordinal set from this sibling. Absent, the D arms would all refuse for
# THAT reason and the refusal arms would read as passing -- so its absence is an error, never a skip.
PARTITION="$SRCDIR/partition-document.sh"
[ -f "$PARTITION" ] || { echo "FIXTURE ERROR: $PARTITION is not beside the merge; section mode reads its --map" >&2; exit 2; }
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
    printf 'skill: ai-dlc-adversary-review\ninvoked_at: %s\ntool_use_id: toolu_014KW7m9L81QQd5tmf3J%s\n' "$at" "$k"
    printf 'mode: subagent\nlead_role: .claude/skills/ai-dlc/steps/stories-test-strategy.md\n'
    is_cross "$k" && printf 'artifact: _bmad-output/planning-artifacts/s1/stories\n'
    [ -n "$sha" ] && printf 'artifact_sha: %s\n' "$sha"
    printf 'findings_critical: 0\nfindings_critical_prior_scope: 0\nfindings_major: %s\n' "$n"
    printf 'findings_major_underived: 0\nfindings_minor: 0\nverdict: %s\n' "$v"
    printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'
  } > "$d/$k.md"
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
  # The merged tool_use_id is cross-1's and the id keys are cross-1..cross-6.
  local o; case "$mode" in files) o="$(out_of "$d")" ;; document) o="$(doc_out_of "$d")" ;; elicit) o="$(dirname "$(dirname "$d")")/requirements-elicitation.md" ;; esac
  grep -q '^tool_use_id: .*cross-1$' "$o" && grep -q ' cross-6=' "$o" && ! grep -q ' cross=' "$o" || return 1
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
  local m="$1" d f o
  d="$(b3_world)"; printf '\nseat-complete: stories adversary 1\n' >> "$d/1.md"; run_merge "$m" "$d"
  refused_clean "does not end in 'seat-complete: '" "$d" || return 1
  d="$(b3_world)"; o="$(out_of "$d")"
  for f in "$d"/*.md; do printf '\nseat-complete: stories adversary %s\n\n' "$(basename "$f" .md)" >> "$f"; done
  run_merge "$m" "$d"
  [ "$RC" -eq 0 ] && [ -f "$o" ] && ! grep -q '^seat-complete: ' "$o"
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
    printf 'skill: ai-dlc-adversary-review\ninvoked_at: %s\ntool_use_id: toolu_01DocShard9xQ%s\n' "$at" "$k"
    printf 'mode: subagent\nlead_role: .claude/skills/ai-dlc/steps/stories-test-strategy.md\n'
    printf 'artifact: %s\nartifact_sha: %s\n' "$art" "$sha"
    printf 'findings_critical: 0\nfindings_critical_prior_scope: 0\nfindings_major: %s\n' "$n"
    printf 'findings_major_underived: 0\nfindings_minor: 0\nverdict: %s\n' "$v"
    printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'
  } > "$d/$k.md"
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
  grep -qx 'tool_use_id: toolu_01DocShard9xQcross-1' "$o" || return 1
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
    printf 'tool_use_id: toolu_01Subj%s\nmode: subagent\nlead_role: .claude/skills/ai-dlc/steps/requirements.md\n' "$k"
    printf 'artifact: %s\nartifact_sha: %s\n' "$art" "$sl"
    printf 'findings_critical: 0\nfindings_critical_prior_scope: 0\nfindings_major: %s\nfindings_major_underived: 0\nfindings_minor: 0\n' "$n"
    [ "$v" = "-" ] || printf 'verdict: %s\n' "$v"
    printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'; } > "$d/$k.md"
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
P_ALL="b3 clean ceiling miss_ord miss_cross dup partition sha ms doc_b3 doc_axis doc_sha doc_path doc_serial files_golden subj_b3 subj_miss_cross subj_xcite subj_sha subj_stems subj_art subj_elicit subj_b4 b4doc b4doc_nomf b4doc_other xfiles xdoc xelicit xmix xunknown xcomplete"

