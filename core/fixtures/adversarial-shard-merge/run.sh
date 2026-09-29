#!/usr/bin/env bash
# adversarial-shard-merge/run.sh -- merge-adversarial-shards.sh, the JOIN that turns one
# adversary per story ordinal plus one cross-story adversary into the ONE pass file every gate
# reads.
#
# WHY A FIXTURE OF ITS OWN. No existing fixture owns this script: check-24-adversarial-convergence
# owns the convergence validator the merge's OUTPUT feeds, and it seeds pass files directly, so it
# never runs the merge. The merge is a new program with its own refusals, and its one
# load-bearing claim -- the merged verdict is RECOMPUTED from the summed residue, never taken from
# a shard -- is invisible to anything that only reads a finished pass file.
#
# THE DISCRIMINATING INPUT (B3). Three per-ordinal shards each holding 2 blocking MAJOR, each
# honestly stamped EXIT_CONDITION_MET because 2 is under the ceiling, and a clean cross shard. The
# artifact holds 6. A merge that took the worst shard verdict, or any one shard verdict, says MET;
# the recomputed verdict is NOT_MET, and the convergence validator must ACCEPT the merged file
# (--cycle-state CONTINUE, exit 0) rather than refuse it as unparseable.
#
# SEEDS ARE REAL CONSUMER BYTES, TRIMMED. `seed.<basename>` are the first 12 lines of three story
# files from one reference-consumer sprint, chosen because their LC_ALL=C order puts two
# NON-`story-` files (`192-ff-...`, `bug-...`) at ordinals 1 and 2: an ordinal key that only
# understood `story-<n>-` would refuse or mis-key them. `seed.finding-headings.txt` is the heading
# list of a real multi-story adversarial pass; every shard finding below carries one of those
# titles. Only the severity word and the `stories:` line are added, because the real pass predates
# the shard grammar (see arm R6, which runs a heading exactly as the real pass wrote it).
#
# SECTION MODE (--document, arms D0-D6). `seed.doc-test-strategy.md` is a real consumer
# single-file artifact that partition-document.sh --map splits into three parts, and
# `seed.doc-serial-epics.md` a real one it calls SERIAL; D0 reads both off --map rather than
# assuming them. D2's seed is the one the receipt could not build: a finding carrying ONE
# `sections:` line and a `stories:` line, so the one-citation count passes it and only the axis
# guard refuses -- MX6b asserts that, with the guard gone, the same seed merges. D4's shard names a
# byte-identical COPY of the document, so the sha check passes and only the path check refuses;
# D3 is the mirror, the right path with other bytes' sha. `seed.files-b3-merged.expected` is the
# B3 output of the merge BEFORE section mode existed (origin/main at dd7e40ad), so D6 holds files
# mode to its old bytes rather than to whatever the current merge prints.
#
# THE MUTANTS AT THE END are copies of the merge (and the convergence validator it reads its
# ceilings from, which must sit beside it), each scored against the SAME predicates the arms
# assert, with the expected kill set compared for EQUALITY.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"

# The subject, found by walking UP for a directory that carries it in either layout -- never by
# counting `..`. Distribution: <root>/core/scripts/. Consumer: <root>/scripts/ai-dlc/.
MERGE=""
_d="$HERE"
while [ -n "$_d" ] && [ "$_d" != "/" ]; do
  for _c in "$_d/core/scripts/merge-adversarial-shards.sh" "$_d/scripts/ai-dlc/merge-adversarial-shards.sh"; do
    if [ -f "$_c" ]; then MERGE="$_c"; break 2; fi
  done
  _d="$(dirname "$_d")"
done
if [ -z "$MERGE" ]; then
  echo "FIXTURE ERROR: merge-adversarial-shards.sh not found above $HERE in either layout; nothing was asserted" >&2
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
  [ -s "$HERE/$_s" ] || { echo "FIXTURE ERROR: seed $HERE/$_s is missing or empty" >&2; exit 2; }
done
echo "adversarial-shard-merge: resolved subject = $MERGE"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/adversarial-shard-merge.XXXXXX")" || exit 2
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
    cp "$HERE/seed.$s" "$pa/s1/stories/$s"
  done
  printf -- '- **disposition:** repaired\n- **edit:** `stories/bug-192-il-accuracy.md:3`\n- **derivation:** a remediator part, not an adversary shard\n' \
    > "$pa/s1/shards/stories-repair-p1/01.md"
  printf '%s' "$pa/s1/shards/stories-p1"
}
out_of() { printf '%s' "$(dirname "$(dirname "$(dirname "$1")")")/s1/stories-adversarial-p1.md"; }
stories_of() { printf '%s' "$(dirname "$(dirname "$(dirname "$1")")")/s1/stories"; }

# Heading N of the real pass, re-prefixed with the severity word the merge's grammar reads.
real_title() { # <n> -> the title text after "### X# — "
  sed -n "${1}p" "$HERE/seed.finding-headings.txt" | sed 's/^### [A-Z][0-9]* — //'
}

# shard <shard-dir> <key: ordinal|cross> <n-major> <verdict> <stories-cite> [sha-override] [invoked_at]
shard() {
  local d="$1" k="$2" n="$3" v="$4" cite="$5" sha="${6:-}" at_o="${7:-}" i=0 b at hn
  if [ "$k" != "cross" ] && [ -z "$sha" ]; then
    b="$(bash "$MERGE" --map "$d" | awk -F'\t' -v k="$k" '$1 + 0 == k + 0 { print $2 }')"
    sha="$(sha_of "$(stories_of "$d")/$b")"
  fi
  case "$k" in cross) at="2026-08-24T15:09:19Z" ;; *) at="2026-08-24T15:0${k}:19Z" ;; esac
  [ -n "$at_o" ] && at="$at_o"
  {
    printf '# stories -- adversarial shard %s\n\n## Findings\n\n' "$k"
    while [ "$i" -lt "$n" ]; do
      i=$((i + 1)); hn=$(( (i + ${k#cross}0) % 10 + 1 ))
      printf '### M%s — MAJOR — %s\n\nstories: %s\n\nBody quoted from the real pass.\n\n' "$i" "$(real_title "$hn")" "$cite"
    done
    printf '## Probed and found sound\n\nNothing further.\n\n'
    printf '<!-- SKILL_INVOCATION_PROVENANCE v1\n'
    printf 'skill: ai-dlc-adversary-review\ninvoked_at: %s\ntool_use_id: toolu_014KW7m9L81QQd5tmf3J%s\n' "$at" "$k"
    printf 'mode: subagent\nlead_role: .claude/skills/ai-dlc/steps/stories-test-strategy.md\n'
    [ "$k" = "cross" ] && printf 'artifact: _bmad-output/planning-artifacts/s1/stories\n'
    [ -n "$sha" ] && printf 'artifact_sha: %s\n' "$sha"
    printf 'findings_critical: 0\nfindings_critical_prior_scope: 0\nfindings_major: %s\n' "$n"
    printf 'findings_major_underived: 0\nfindings_minor: 0\nverdict: %s\n' "$v"
    printf 'SKILL_INVOCATION_PROVENANCE_END -->\n'
  } > "$d/$k.md"
}

# The B3 input: three ordinal shards, 2 MAJOR each, each stamped MET; a clean cross shard.
b3_world() {
  local d; d="$(new_world)"
  shard "$d" 1 2 EXIT_CONDITION_MET 1
  shard "$d" 2 2 EXIT_CONDITION_MET 2
  shard "$d" 3 2 EXIT_CONDITION_MET 3
  shard "$d" cross 0 EXIT_CONDITION_MET "1, 3"
  printf '%s' "$d"
}
# The clean set: 1 MAJOR per ordinal shard (sum 3, AT the ceiling), a cross finding citing two
# ordinals with 0 MAJOR counted elsewhere -- and every shard stamped NOT_MET, the mirror of B3.
clean_world() {
  local d; d="$(new_world)"
  shard "$d" 1 1 EXIT_CONDITION_NOT_MET 1
  shard "$d" 2 1 EXIT_CONDITION_NOT_MET 2
  shard "$d" 3 1 EXIT_CONDITION_NOT_MET 3
  shard "$d" cross 0 EXIT_CONDITION_NOT_MET "1, 2"
  printf '%s' "$d"
}

MO="$WORK/merge.out"; CO="$WORK/conv.out"
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
  [ "$RC" -eq 0 ] && has "$MO" "verdict=EXIT_CONDITION_NOT_MET shards=4" && has "$MO" "blocking=6" \
    && [ -f "$o" ] && has "$o" "verdict: EXIT_CONDITION_NOT_MET" || return 1
  bash "$c" --series "$(dirname "$o")/stories-adversarial-p" --cycle-state > "$CO" 2>&1 || return 1
  has "$CO" "CONTINUE"
}
p_clean() { # every shard stamped NOT_MET, summed blocking == the ceiling -> MET, CONVERGED
  local m="$1" d o c
  d="$(clean_world)"; o="$(out_of "$d")"; c="$(dirname "$m")/validate-adversarial-convergence.sh"
  run_merge "$m" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "verdict=EXIT_CONDITION_MET shards=4" && has "$o" "verdict: EXIT_CONDITION_MET" || return 1
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
p_miss_cross() {
  local d; d="$(b3_world)"; rm -f "$d/cross.md"; run_merge "$1" "$d"
  refused_clean "shard cross is missing from" "$d"
}
p_dup() { # 1.md and 01.md are one ordinal
  local d; d="$(b3_world)"; cp "$d/1.md" "$d/01.md"; run_merge "$1" "$d"
  refused_clean "was delivered more than once" "$d"
}
p_partition() { # a per-ordinal shard citing another story, and a cross shard citing one
  local d r1 r2; d="$(b3_world)"
  shard "$d" 2 2 EXIT_CONDITION_MET "1, 2"; run_merge "$1" "$d"
  refused_clean "a per-ordinal shard reports only findings citing its own ordinal alone" "$d"; r1=$?
  d="$(b3_world)"; shard "$d" cross 1 EXIT_CONDITION_MET 3; run_merge "$1" "$d"
  refused_clean "a cross-story finding cites two or more ordinals" "$d"; r2=$?
  [ "$r1" -eq 0 ] && [ "$r2" -eq 0 ]
}
p_sha() { # shard 3 notarized bytes that are not the story on disk
  local d; d="$(b3_world)"
  shard "$d" 3 2 EXIT_CONDITION_MET 3 "$(sha_of "$HERE/seed.bug-192-il-accuracy.md")"
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
  cp "$HERE/$seed" "$pa/s1/test-strategy.md"
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
  case "$k" in cross) at="2026-08-24T16:09:19Z" ;; *) at="2026-08-24T16:0${k}:19Z" ;; esac
  {
    printf '# test-strategy -- adversarial section shard %s\n\n## Findings\n\n' "$k"
    while [ "$i" -lt "$n" ]; do
      i=$((i + 1)); hn=$(( (i + ${k#cross}0) % 10 + 1 ))
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
# The section-mode B3: three part shards of 2 MAJOR each, each stamped MET, and a clean cross.
doc_b3_world() {
  local d; d="$(new_doc_world)"
  dshard "$d" 1 2 EXIT_CONDITION_MET 1
  dshard "$d" 2 2 EXIT_CONDITION_MET 2
  dshard "$d" 3 2 EXIT_CONDITION_MET 3
  dshard "$d" cross 0 EXIT_CONDITION_MET "1, 3"
  printf '%s' "$d"
}

p_doc_b3() { # sums, recomputes, ONE artifact_sha, a shard_wall entry per shard, validator reads 0/6
  local m="$1" d o c sha n_sha n_wall
  d="$(doc_b3_world)"; o="$(doc_out_of "$d")"; c="$(dirname "$m")/validate-adversarial-convergence.sh"
  sha="$(sha_of "$(doc_of "$d")")"
  run_doc_merge "$m" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "verdict=EXIT_CONDITION_NOT_MET shards=4" && has "$MO" "major=6" \
    && [ -f "$o" ] && has "$o" "verdict: EXIT_CONDITION_NOT_MET" || return 1
  n_sha="$(grep -c '^artifact_sha:' "$o")" || n_sha=0
  [ "$n_sha" -eq 1 ] && [ "$(grep '^artifact_sha:' "$o")" = "artifact_sha: $sha" ] || return 1
  n_wall="$(grep '^shard_wall:' "$o" | tr ' ' '\n' | grep -cE '^(1|2|3|cross)=[0-9T:.Z-]+/[0-9T:Z-]+$')" || n_wall=0
  [ "$n_wall" -eq 4 ] || return 1
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
  dshard "$d" 2 2 EXIT_CONDITION_MET 2 "$(sha_of "$HERE/seed.doc-serial-epics.md")"
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
  [ "$RC" -eq 0 ] && cmp -s "$o" "$HERE/seed.files-b3-merged.expected"
}
P_ALL="b3 clean ceiling miss_ord miss_cross dup partition sha ms doc_b3 doc_axis doc_sha doc_path doc_serial files_golden"

# ---------------------------------------------------------------------------------- the arms
echo "adversarial-shard-merge:"

# M0: the ordinal map covers every *.md, whatever its name, in C order.
d="$(new_world)"
map="$(bash "$MERGE" --map "$d")"
want="$(printf '1\t192-ff-A-token-decimal-resolution.md\n2\tbug-192-il-accuracy.md\n3\tstory-1-rebalancer-il-accuracy.md')"
if [ "$map" = "$want" ]; then
  ok "M0: --map keys all three real files by ordinal, the two NON-story- names (192-ff-, bug-) included, in LC_ALL=C order"
else
  bad "M0: --map printed [$map], not the three ordinals over the real listing"
fi

# The worlds must differ from each other where the arms say they do, or the pair proves nothing.
d1="$(b3_world)"; d2="$(clean_world)"
if cmp -s "$d1/1.md" "$d2/1.md"; then bad "W0: FIXTURE BROKEN -- the B3 and clean worlds seed byte-identical shard 1"
else ok "W0: the B3 and clean worlds differ in shard bytes (count and stamped verdict), so the pair can split"; fi
n_met="$(grep -l '^verdict: EXIT_CONDITION_MET$' "$d1"/1.md "$d1"/2.md "$d1"/3.md | grep -c .)" || n_met=0
[ "$n_met" -eq 3 ] && ok "W1: every B3 shard stamps EXIT_CONDITION_MET (a worst-shard merge would say MET)" \
  || bad "W1: FIXTURE BROKEN -- only $n_met of 3 B3 shards stamp MET, so B3 no longer discriminates"

p_b3 "$MERGE" && ok "A1: B3 (3 shards x 2 blocking MAJOR, each stamped MET) merges NOT_MET with blocking=6, shards=4 beside a repair dir, and --cycle-state reads CONTINUE" \
  || bad "A1: the B3 input did not merge to a recomputed NOT_MET accepted by the convergence validator (rc=$RC): $(cat "$MO") $(cat "$CO" 2>/dev/null)"
p_clean "$MERGE" && ok "A2: every shard stamped NOT_MET, summed blocking 3 = the ceiling -> merged MET and CONVERGED (the mirror of A1)" \
  || bad "A2: the clean set did not merge to MET/CONVERGED (rc=$RC): $(cat "$MO")"
p_ceiling "$MERGE"; r=$?
if [ "$r" -eq 2 ]; then bad "A3: FIXTURE STALE -- MAJOR_EXIT_CEILING=3 is not a line of the convergence validator, so the ceiling copy changed nothing"
elif [ "$r" -eq 0 ]; then ok "A3: with the sibling's MAJOR_EXIT_CEILING at 6 the SAME B3 input merges MET (ceiling=6) -- the ceiling is read, not restated"
else bad "A3: a sibling ceiling of 6 did not move the B3 merge to MET: $(cat "$MO")"; fi
p_miss_ord "$MERGE"   && ok "R1: ordinal 1 (a non-story- file) with no shard -> REFUSED 'is missing', exit 2, nothing written" || bad "R1: a missing ordinal shard was not refused cleanly (rc=$RC): $(cat "$MO")"
p_miss_cross "$MERGE" && ok "R2: no cross.md -> REFUSED 'shard cross is missing', exit 2, nothing written" || bad "R2: a missing cross shard was not refused cleanly (rc=$RC): $(cat "$MO")"
p_dup "$MERGE"        && ok "R3: 1.md beside 01.md -> REFUSED 'delivered more than once', exit 2, nothing written" || bad "R3: a duplicate shard was not refused cleanly (rc=$RC): $(cat "$MO")"
p_partition "$MERGE"  && ok "R4: a per-ordinal finding citing two stories, and a cross finding citing one, each REFUSED, nothing written" || bad "R4: a partition violation was not refused cleanly (rc=$RC): $(cat "$MO")"
p_ms "$MERGE"         && ok "A4: shards stamped 15:00:19.497Z and 15:00:19Z merge, the merged invoked_at is 15:00:19Z (the true earliest, not the raw-string least), and --cycle-state accepts it (exit 0)" \
  || bad "A4: a millisecond-stamped shard did not merge to the true-earliest invoked_at (rc=$RC): $(cat "$MO") $(cat "$CO" 2>/dev/null)"
p_sha "$MERGE"        && ok "R5: a shard notarizing another story's sha -> REFUSED 'reviewed other bytes', exit 2, nothing written" || bad "R5: a sha mismatch was not refused cleanly (rc=$RC): $(cat "$MO")"

# ---- section mode. The seeds must reach the branches they are named for, or every D arm below
# asserts about a world that cannot express its defect.
DS0="$(new_doc_world)"; DS1="$(new_doc_world seed.doc-serial-epics.md)"
n_parts="$(bash "$PARTITION" --map "$(doc_of "$DS0")" | grep -c .)" || n_parts=0
bash "$PARTITION" --map "$(doc_of "$DS1")" > "$WORK/serial.map" 2>&1; r_serial=$?
if [ "$n_parts" -eq 3 ] && [ "$r_serial" -eq 3 ] && has "$WORK/serial.map" "SERIAL:"; then
  ok "D0: the document seed partitions into 3 parts and the SERIAL seed exits 3 with SERIAL: (both read from partition-document.sh --map, never assumed)"
else
  bad "D0: FIXTURE BROKEN -- the document seed maps to $n_parts part(s) (want 3) and the SERIAL seed exited $r_serial (want 3); the D arms cannot discriminate"
fi
p_doc_b3 "$MERGE" && ok "D1: three section shards x 2 MAJOR, each stamped MET, merge NOT_MET major=6; ONE artifact_sha equal to the document's; a shard_wall entry per shard; the convergence validator reads critical=0 major=6" \
  || bad "D1: the section B3 did not merge to a recomputed NOT_MET with one artifact_sha read 0/6 by the validator (rc=$RC): $(cat "$MO") $(grep -m1 'major=' "$CO" 2>/dev/null)"
p_doc_axis "$MERGE" && ok "D2: a finding carrying ONE sections: line AND a stories: line -> REFUSED by the axis guard (the one-citation count passes it), nothing written" \
  || bad "D2: a finding citing both axes was not refused by the axis guard (rc=$RC): $(cat "$MO")"
p_doc_sha "$MERGE" && ok "D3: a section shard notarizing other bytes at the right path -> REFUSED 'reviewed other bytes', nothing written" \
  || bad "D3: a whole-document sha mismatch was not refused cleanly (rc=$RC): $(cat "$MO")"
p_doc_path "$MERGE" && ok "D4: a section shard naming a byte-identical COPY of the document -> REFUSED 'reviewed another file' (the sha passes, the path does not), nothing written" \
  || bad "D4: an artifact path other than --document was not refused cleanly (rc=$RC): $(cat "$MO")"
p_doc_serial "$MERGE" && ok "D5: --document on a document partition-document.sh calls SERIAL -> REFUSED with its SERIAL: reason, nothing written" \
  || bad "D5: a SERIAL document was not refused cleanly (rc=$RC): $(cat "$MO")"
p_files_golden "$MERGE" && ok "D6: files mode on B3 is byte-identical to seed.files-b3-merged.expected, the output of the merge before section mode existed" \
  || bad "D6: files-mode output moved from the pre-section-mode golden (rc=$RC): $(cat "$MO")"

# R6: a finding heading EXACTLY as the real pass wrote it carries no severity word, so the heads
# counted (0 MAJOR) disagree with findings_major -- refused, never counted as zero.
d="$(b3_world)"
{
  printf '## Findings\n\n%s\n\nstories: 1\n\n' "$(sed -n 1p "$HERE/seed.finding-headings.txt")"
  sed -n '/SKILL_INVOCATION_PROVENANCE v1/,$p' "$d/1.md" | sed 's/^findings_major: 2$/findings_major: 1/'
} > "$d/1.tmp" && mv "$d/1.tmp" "$d/1.md"
run_merge "$MERGE" "$d"
refused_clean "Findings section heads 0 CRITICAL / 0 MAJOR" "$d" \
  && ok "R6: a real-pass heading with no severity word -> REFUSED on the count, never merged as 0 MAJOR" \
  || bad "R6: a heading without a severity word was not refused on its count (rc=$RC): $(cat "$MO")"

# ------------------------------------------------------------------------------ the mutants
# A copy of the merge AND its sibling, one literal edit asserted to apply exactly once.
mutdir() { # <name> -> a dir holding the merge and the siblings it and the predicates resolve
  local d s
  d="$(mktemp -d "$WORK/mut-$1.XXXXXX")" || return 1
  for s in merge-adversarial-shards.sh validate-adversarial-convergence.sh validate-steering-budget.sh partition-document.sh; do
    [ -f "$SRCDIR/$s" ] && cp "$SRCDIR/$s" "$d/"
  done
  printf '%s' "$d"
}
apply() { # <file> <old> <new>
  M_OLD="$2" M_NEW="$3" python3 - "$1" <<'PY'
import os, sys
p = sys.argv[1]; old, new = os.environ["M_OLD"], os.environ["M_NEW"]
t = open(p, encoding="utf-8").read()
n = t.count(old)
if n != 1:
    sys.stderr.write("ANCHOR MATCHED %d TIMES, EXPECTED 1\n" % n); sys.exit(3)
open(p, "w", encoding="utf-8").write(t.replace(old, new))
PY
}
score() { # <label> <merge> <expected dead set, space separated, or NONE>
  local label="$1" m="$2" want="$3" dead="" p
  for p in $P_ALL; do "p_$p" "$m" || dead="$dead $p"; done
  dead="${dead# }"
  if [ "$want" = "NONE" ]; then
    [ -z "$dead" ] && ok "$label: every predicate HOLDS on the unmutated sandbox copy, so each kill below is the mutation's" \
      || bad "$label: the UNMUTATED copy failed [$dead]; every mutant verdict below is about a broken harness"
    return
  fi
  if [ -z "$dead" ]; then bad "$label SURVIVED -- no arm watches the line it edits"
  elif [ "$dead" = "$want" ]; then ok "$label: KILLED by [$want] and nothing else"
  else bad "$label killed [$dead], expected exactly [$want] -- an arm is entangled or does not own this property"; fi
}
mutant() { # <label> <expected> <old> <new> [<old2> <new2>]
  local label="$1" want="$2" d; d="$(mutdir "${label%% *}")"
  if ! apply "$d/merge-adversarial-shards.sh" "$3" "$4" || { [ $# -ge 6 ] && ! apply "$d/merge-adversarial-shards.sh" "$5" "$6"; }; then
    bad "$label: FIXTURE STALE -- the mutation anchor is not in the merge exactly once; re-anchor it, never relax the assertion"; return
  fi
  if cmp -s "$MERGE" "$d/merge-adversarial-shards.sh"; then bad "$label: FIXTURE STALE -- the mutated copy is byte-identical"; return; fi
  score "$label" "$d/merge-adversarial-shards.sh" "$want"
}

C0="$(mutdir m0)"
if [ -f "$C0/validate-adversarial-convergence.sh" ] && [ -f "$C0/merge-adversarial-shards.sh" ] && [ -f "$C0/partition-document.sh" ]; then
  ok "MX-pre: the sandbox carries the merge, the convergence validator it reads its ceilings from, and the partition section mode reads its --map from"
  score "MX0 control (unmutated copy)" "$C0/merge-adversarial-shards.sh" NONE
else
  bad "MX-pre: FIXTURE BROKEN -- the sandbox lacks the merge or its sibling"
fi

# Two worlds own this, by construction: B3 (every shard MET, residue 6) and its mirror (every
# shard NOT_MET, residue at the ceiling). A worst-shard merge is wrong in both directions. The
# section-mode B3 (D1) and the files-mode golden (D6) are the same property in the other mode and
# in bytes, so they die with it.
mutant "MX1 verdict = worst shard verdict, not recomputed" "b3 clean doc_b3 files_golden" \
  'elif [ "$S_CRIT" -le "$CRIT_CEIL" ] && [ "$BLOCKING" -le "$MAJOR_CEIL" ]; then VERDICT="EXIT_CONDITION_MET"' \
  'elif [ "${WORST_NOT_MET:-0}" -eq 0 ]; then VERDICT="EXIT_CONDITION_MET"' \
  '    EXIT_CONDITION_MET|EXIT_CONDITION_NOT_MET) ;;' \
  '    EXIT_CONDITION_MET) ;;
    EXIT_CONDITION_NOT_MET) WORST_NOT_MET=1 ;;'
mutant "MX2 ceiling hard-coded, not read" "ceiling" \
  'MAJOR_CEIL="$(read_ceiling MAJOR_EXIT_CEILING)"' \
  'MAJOR_CEIL=3'
mutant "MX3 missing-shard check removed" "miss_ord miss_cross" \
  'for idx in $ORDINALS cross; do' \
  'for idx in ; do'
mutant "MX4 earliest shard by raw string, not by time" "ms" \
  'if [ -z "$EARLIEST" ] || [[ "$AT_KEY" < "$EARLIEST_KEY" ]]; then' \
  'if [ -z "$EARLIEST" ] || [[ "$at" < "$EARLIEST" ]]; then'
mutant "MX5 invoked_at fraction refused" "ms" \
  ':[0-9]{2}(\.[0-9]{1,9})?Z$' \
  ':[0-9]{2}Z$'
# Section mode. D2's seed carries exactly one sections: line, so with the guard gone the finding
# passes the one-citation count and the merge SUCCEEDS -- the kill is D2's alone.
mutant "MX6 wrong-axis guard removed" "doc_axis" \
  '[ "${wrong:-0}" = "0" ] || refuse' \
  '[ "${wrong:-0}" = "0" ] || true'
# MX6b: the kill above would ALSO be scored if some other rule refused D2's seed, so assert what
# separates them: with the guard gone the same seed MERGES (exit 0), i.e. nothing else refuses it.
M6="$(mutdir m6b)"
if apply "$M6/merge-adversarial-shards.sh" '[ "${wrong:-0}" = "0" ] || refuse' '[ "${wrong:-0}" = "0" ] || true' 2>/dev/null \
   && ! cmp -s "$MERGE" "$M6/merge-adversarial-shards.sh"; then
  d="$(doc_b3_world)"; dshard "$d" 2 2 EXIT_CONDITION_MET 2 "" "" "stories: 2"
  run_doc_merge "$M6/merge-adversarial-shards.sh" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" \
    && ok "MX6b: without the axis guard D2's seed MERGES (exit 0) -- no other rule refuses it, so the guard alone owns the refusal" \
    || bad "MX6b: without the axis guard D2's seed still did not merge (rc=$RC) -- another rule refuses it first and D2 cannot see the guard: $(cat "$MO")"
else
  bad "MX6b: FIXTURE STALE -- the axis-guard anchor is not in the merge exactly once"
fi
mutant "MX7 whole-document sha check removed" "doc_sha" \
  '[ "$sha" = "$DOC_SHA" ] || refuse' \
  '[ "$sha" = "$DOC_SHA" ] || true'
mutant "MX8 artifact-path check removed" "doc_path" \
  '[ "$ART_ABS" = "$DOCUMENT" ] \' \
  'true || [ "$ART_ABS" = "$DOCUMENT" ] \'
echo
if [ "$fails" -eq 0 ]; then echo "adversarial-shard-merge: PASS"; exit 0; fi
echo "adversarial-shard-merge: $fails assertion(s) FAILED" >&2
exit 1
