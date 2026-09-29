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
for _s in seed.192-ff-A-token-decimal-resolution.md seed.bug-192-il-accuracy.md \
          seed.story-1-rebalancer-il-accuracy.md seed.finding-headings.txt; do
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
P_ALL="b3 clean ceiling miss_ord miss_cross dup partition sha ms"

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

# P1: the merged pass is a provenance block the READER accepts. Its artifact_sha is the files-mode
# list `<stem>=<sha> ...`, which the schema's single-sha pattern refused, so every sharded pass
# failed validate-provenance-block.sh while the convergence validator passed it. The two
# near-misses keep the widening honest: a list of ONE (a merge always has two or more stories)
# and a list carrying a short sha are both refused, and a bare sha is the control that still passes.
PB="$SRCDIR/validate-provenance-block.sh"
if [ ! -f "$PB" ]; then
  bad "P1: FIXTURE BROKEN -- validate-provenance-block.sh is not beside the merge at $SRCDIR"
else
  d="$(b3_world)"; o="$(out_of "$d")"; run_merge "$MERGE" "$d"
  pb() { bash "$PB" "$1" --require-skill ai-dlc-adversary-review > "$WORK/pb.out" 2>&1; }
  sha_line="$(grep '^artifact_sha:' "$o" 2>/dev/null)"
  n_pairs="$(printf '%s' "${sha_line#artifact_sha:}" | wc -w | tr -d ' ')"
  if [ "$RC" -ne 0 ] || [ "${n_pairs:-0}" -lt 2 ]; then
    bad "P1: FIXTURE BROKEN -- the B3 merge did not write a multi-file artifact_sha (rc=$RC, pairs=${n_pairs:-0})"
  else
    one="$WORK/pb-one.md"; short="$WORK/pb-short.md"; bare="$WORK/pb-bare.md"
    first="$(printf '%s' "${sha_line#artifact_sha: }" | cut -d' ' -f1)"
    sed "s/^artifact_sha:.*/artifact_sha: $first/" "$o" > "$one"
    sed -E 's/^(artifact_sha: [^ ]+=)[a-f0-9]{64}/\1abc123/' "$o" > "$short"
    sed "s/^artifact_sha:.*/artifact_sha: ${first#*=}/" "$o" > "$bare"
    pb "$o"; r_m=$?; pb "$one"; r_1=$?; pb "$short"; r_s=$?; pb "$bare"; r_b=$?
    if [ "$r_m" -eq 0 ] && [ "$r_1" -ne 0 ] && [ "$r_s" -ne 0 ] && [ "$r_b" -eq 0 ]; then
      ok "P1: the merged pass ($n_pairs <stem>=<sha> pairs) passes validate-provenance-block.sh; a one-pair list and a short sha are refused; a bare sha still passes"
    else
      bad "P1: provenance reader on the merged forms gave merged=$r_m one-pair=$r_1 short-sha=$r_s bare=$r_b (want 0 non-0 non-0 0)"
    fi
    # PM1: the schema reverted to the single-sha pattern -- the shipped defect on demand. Driven
    # through AI_DLC_PROJECT_ROOT, whose core/schemas/ the reader tries FIRST, so the validator
    # is the shipped one and only the schema differs. The bare-sha control must stay at 0, or the
    # mutant tree failed for a reason of its own.
    SCH=""
    _d="$SRCDIR"
    while [ -n "$_d" ] && [ "$_d" != "/" ]; do
      for _c in "$_d/core/schemas/provenance-block.json" "$_d/.claude/schemas/provenance-block.json"; do
        [ -f "$_c" ] && { SCH="$_c"; break 2; }
      done
      _d="$(dirname "$_d")"
    done
    mt="$(mktemp -d "$WORK/pm1.XXXXXX")"; mkdir -p "$mt/core/schemas"
    if [ -z "$SCH" ]; then
      bad "PM1: FIXTURE BROKEN -- provenance-block.json not found above $SRCDIR"
    else
      cp "$SCH" "$mt/core/schemas/provenance-block.json"
      M_OLD='"pattern_ref": "artifact_sha"' M_NEW='"pattern_ref": "sha256"' python3 - "$mt/core/schemas/provenance-block.json" <<'PY'
import os, sys
p = sys.argv[1]; t = open(p, encoding="utf-8").read(); o = os.environ["M_OLD"]
if t.count(o) != 1: sys.exit(3)
open(p, "w", encoding="utf-8").write(t.replace(o, os.environ["M_NEW"]))
PY
      if cmp -s "$SCH" "$mt/core/schemas/provenance-block.json"; then
        bad "PM1: FIXTURE STALE -- the pattern_ref anchor is not in the schema exactly once; re-anchor it, never relax P1"
      else
        AI_DLC_PROJECT_ROOT="$mt" bash "$PB" "$o" --require-skill ai-dlc-adversary-review > "$WORK/pb.out" 2>&1; m_m=$?
        AI_DLC_PROJECT_ROOT="$mt" bash "$PB" "$bare" --require-skill ai-dlc-adversary-review > "$WORK/pb.out" 2>&1; m_b=$?
        if [ "$m_m" -ne 0 ] && [ "$m_b" -eq 0 ]; then
          ok "PM1: the schema reverted to the single-sha pattern refuses the merged pass (rc=$m_m) while the bare-sha control holds at 0 -- P1 watches the pattern"
        else
          bad "PM1: with the single-sha pattern the merged pass gave rc=$m_m and the bare control rc=$m_b (want non-0 and 0)"
        fi
      fi
    fi
  fi
fi

# ------------------------------------------------------------------------------ the mutants
# A copy of the merge AND its sibling, one literal edit asserted to apply exactly once.
mutdir() { # <name> -> a dir holding the merge and the siblings it and the predicates resolve
  local d s
  d="$(mktemp -d "$WORK/mut-$1.XXXXXX")" || return 1
  for s in merge-adversarial-shards.sh validate-adversarial-convergence.sh validate-steering-budget.sh; do
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
if [ -f "$C0/validate-adversarial-convergence.sh" ] && [ -f "$C0/merge-adversarial-shards.sh" ]; then
  ok "MX-pre: the sandbox carries the merge and the convergence validator it reads its ceilings from"
  score "MX0 control (unmutated copy)" "$C0/merge-adversarial-shards.sh" NONE
else
  bad "MX-pre: FIXTURE BROKEN -- the sandbox lacks the merge or its sibling"
fi

# Two worlds own this, by construction: B3 (every shard MET, residue 6) and its mirror (every
# shard NOT_MET, residue at the ceiling). A worst-shard merge is wrong in both directions.
mutant "MX1 verdict = worst shard verdict, not recomputed" "b3 clean" \
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

echo
if [ "$fails" -eq 0 ]; then echo "adversarial-shard-merge: PASS"; exit 0; fi
echo "adversarial-shard-merge: $fails assertion(s) FAILED" >&2
exit 1
