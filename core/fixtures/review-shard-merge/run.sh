#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# review-shard-merge/run.sh -- partition-review-diff.sh and merge-review-shards.sh, the part set
# and the JOIN of a sharded gate-1 code review and of a sharded gate-2 QA validation (--gate qa;
# arms Q1-Q16, S7-S10, mutants MQ1-MQ9).
#
# WHAT IS AT STAKE. Check 1 in gate-validation.md reads ONE verdict line from ONE review file. A
# sharded review is N part reviewers plus one cross reviewer, and the merge writes that file. Its
# load-bearing claims are invisible to anything that only reads a finished review:
#   - the part set is RE-DERIVED from the manifest's inputs, never read off the shard directory;
#   - the merged verdict is the WORST shard verdict, never a count, the cross shard, or the last;
#   - the output matches Check 1's own pattern exactly once, and Check 1 reads the right value;
#   - every refusal writes nothing at --out.
#
# TWO SEEDED REPOSITORIES, ON PURPOSE. The merge re-runs the partition sibling, so a partition
# mutant runs inside every merge world. REPO A (dominant) puts every reviewable file under one top
# directory, `app/`: a first-path-component key sees one group and answers SERIAL, so only the
# adaptive split makes it partition -- arm P1 owns that. REPO B (equal) has three top directories
# of byte-identical numstat weight and is merged with --max-parts 3, where 3 x 1/3 of the weight
# never exceeds 1/K of the total, so adaptive and first-component keys give the SAME map; every
# merge world is built on B, so the first-component mutant moves P1 and nothing else.
#
# THE VERDICT WORLDS. W_disc {BLOCKED, APPROVED, APPROVED, cross APPROVED}: cross-wins, last-part-
# wins and majority all say APPROVED, worst-of says BLOCKED. W_bn {NEEDS_REWORK, BLOCKED,
# NEEDS_REWORK, cross APPROVED}: majority says NEEDS_REWORK, worst-of BLOCKED. W_ok (all APPROVED)
# stops "always BLOCKED" passing. W_c1 {NEEDS_REWORK, APPROVED, NEEDS_REWORK, cross NEEDS_REWORK}
# is the world where every one of those wrong rules AGREES with worst-of, so the Check-1 and
# conservation arms do not ride on the verdict mutants.
#
# CHECK 1'S PATTERN IS DERIVED from gate-validation.md with the sed gate-verdict-grep-shape uses,
# and the value is read back by this fixture's own reader, not by the merge's. The value rule is
# the one gate-validation.md Check 1 states, and it is cited there rather than restated here.
#
# The threshold key is named ONCE, in the unset below (fixtures scrub AI_DLC_*; I87). Everywhere
# else it is DERIVED from the partition script's own dereference site.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset AI_DLC_REVIEW_SHARD_MIN_FILES

HERE="$(cd "$(dirname "$0")" && pwd)"
NAME="review-shard-merge"

# The subjects and the files the merge derives from, found by walking UP in either layout --
# never by counting `..`. Distribution: core/scripts, core/skills, core/team-roles. Consumer:
# scripts/ai-dlc, .claude/skills, .claude/team-roles.
find_up() { # <rel-dist> <rel-consumer> -> first existing path walking up from $HERE
  local d="$HERE" c
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    for c in "$d/$1" "$d/$2"; do [ -f "$c" ] && { printf '%s' "$c"; return 0; }; done
    d="$(dirname "$d")"
  done
  return 1
}
PART="$(find_up core/scripts/partition-review-diff.sh scripts/ai-dlc/partition-review-diff.sh)" || PART=""
MERGE="$(find_up core/scripts/merge-review-shards.sh scripts/ai-dlc/merge-review-shards.sh)" || MERGE=""
GATE_MD="$(find_up core/skills/ai-dlc/steps/gate-validation.md .claude/skills/ai-dlc/steps/gate-validation.md)" || GATE_MD=""
ROLE_MD="$(find_up core/team-roles/code-reviewer.md .claude/team-roles/code-reviewer.md)" || ROLE_MD=""
GRAMMAR="$(find_up core/skills/ai-dlc/artifact-path-grammar.md .claude/skills/ai-dlc/artifact-path-grammar.md)" || GRAMMAR=""
STEP_MD="$(find_up core/skills/ai-dlc/steps/implementation.md .claude/skills/ai-dlc/steps/implementation.md)" || STEP_MD=""
QA_MD="$(find_up core/team-roles/qa.md .claude/team-roles/qa.md)" || QA_MD=""
for _p in PART MERGE GATE_MD ROLE_MD GRAMMAR STEP_MD QA_MD; do
  eval "_x=\${$_p}"
  [ -n "$_x" ] || { echo "FIXTURE ERROR: $_p not found above $HERE in either layout; nothing was asserted" >&2; exit 2; }
done
SRCDIR="$(cd "$(dirname "$MERGE")" && pwd)"
[ "$(cd "$(dirname "$PART")" && pwd)" = "$SRCDIR" ] || { echo "FIXTURE ERROR: the partition is not beside the merge" >&2; exit 2; }
[ -f "$SRCDIR/artifact-path-config.sh" ] || { echo "FIXTURE ERROR: artifact-path-config.sh is not beside the partition; it reads the scan roots there" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 not on PATH (the mutation helper)" >&2; exit 2; }
echo "$NAME: resolved subjects = $PART , $MERGE"

# THE KEY, derived from the partition's dereference site. Absent, the SERIAL and env arms below
# would assert about a name the program no longer reads.
KEY="$(sed -n 's/.*"\${\(AI_DLC_[A-Z0-9_]*\):-}".*/\1/p' "$PART" | head -1)"
[ -n "$KEY" ] || { echo "FIXTURE STALE: no \"\${AI_DLC_...:-}\" dereference in $PART" >&2; exit 2; }
# THE BUILT-IN DEFAULT, derived from its one assignment. The boundary seeds below are built at
# exactly DFLT-1 and DFLT reviewable files: a seed far from the boundary cannot tell `<` from
# `<=`, and a seed derived from a restated number goes stale silently when the default moves.
DFLT_N="$(grep -c '^REVIEW_SHARD_DEFAULT_MIN_FILES=' "$PART")" || DFLT_N=0
DFLT="$(sed -n 's/^REVIEW_SHARD_DEFAULT_MIN_FILES=\([0-9][0-9]*\)$/\1/p' "$PART")"
[ "$DFLT_N" = "1" ] && [ -n "$DFLT" ] && [ "$DFLT" -ge 2 ] \
  || { echo "FIXTURE STALE: $PART carries $DFLT_N 'REVIEW_SHARD_DEFAULT_MIN_FILES=<n>' line(s) (want 1, n >= 2)" >&2; exit 2; }

# CHECK 1'S PATTERN, lifted exactly as core/fixtures/gate-verdict-grep-shape lifts it.
PAT="$(sed -n "s/.*grep -inE '\(.*\)' <review-file>.*/\1/p" "$GATE_MD" | head -1)"
[ -n "$PAT" ] || { echo "FIXTURE STALE: no grep -inE '<pattern>' <review-file> directive in $GATE_MD" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/review-shard-merge.XXXXXX")" || exit 2
WORK="$(cd "$WORK" && pwd -P)"
trap 'rm -rf "$WORK"' EXIT

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
has() { local n; n="$(grep -cF -- "$2" "$1")" || n=0; [ "$n" -gt 0 ]; }

# The project root the merge reads gate-validation.md and code-reviewer.md from: a copy of the
# resolved bytes in the distribution layout, so an untracked .claude/ copy beside the dev
# checkout can never be what the merge reads.
PROJ="$WORK/proj"
mkdir -p "$PROJ/core/skills/ai-dlc/steps" "$PROJ/core/team-roles"
cp "$GATE_MD" "$PROJ/core/skills/ai-dlc/steps/gate-validation.md"
cp "$ROLE_MD" "$PROJ/core/team-roles/code-reviewer.md"
cp "$QA_MD" "$PROJ/core/team-roles/qa.md"

# ------------------------------------------------------------------------- seeded repositories
G() { git -c user.name=fixture -c user.email=fixture@example.invalid -c commit.gpgsign=false \
          -c core.hooksPath=/dev/null "$@"; }
lines() { # <file> <n> <tag> -> n distinct lines
  local i=0; mkdir -p "$(dirname "$1")"
  : > "$1"; while [ "$i" -lt "$2" ]; do i=$((i + 1)); printf '%s line %d\n' "$3" "$i" >> "$1"; done
}
new_repo() { # <dir> -> base commit holding the artifact-path grammar
  mkdir -p "$1/core/skills/ai-dlc" || return 1
  G init -q "$1" || return 1
  cp "$GRAMMAR" "$1/core/skills/ai-dlc/artifact-path-grammar.md"
  printf 'seed\n' > "$1/README"
  G -C "$1" add -A && G -C "$1" commit -q -m base || return 1
}
REPO_A="$WORK/repo-a"; REPO_B="$WORK/repo-b"
new_repo "$REPO_A" && new_repo "$REPO_B" || { echo "FIXTURE ERROR: git init/commit failed" >&2; exit 2; }
# A: every reviewable file under app/, one pipeline artifact under a scan root.
for f in app/api/a.py app/api/b.py app/web/c.js app/web/d.js app/core/e.py app/core/f.py; do
  lines "$REPO_A/$f" 10 "$f"
done
lines "$REPO_A/docs/reviews/s1/0-old-code-review.md" 10 review
G -C "$REPO_A" add -A && G -C "$REPO_A" commit -q -m frozen
# B: three top directories, two files each, every file 5 lines: identical weight per directory.
for f in alpha/a1.txt alpha/a2.txt beta/b1.txt beta/b2.txt gamma/g1.txt gamma/g2.txt; do
  lines "$REPO_B/$f" 5 "$f"
done
G -C "$REPO_B" add -A && G -C "$REPO_B" commit -q -m frozen
for r in "$REPO_A" "$REPO_B"; do
  [ -d "$r/.git" ] || { echo "FIXTURE ERROR: $r is not a repository (inherited GIT_DIR?)" >&2; exit 2; }
done
A_BASE="$(G -C "$REPO_A" rev-parse HEAD~1)"; A_SHA="$(G -C "$REPO_A" rev-parse HEAD)"
B_BASE="$(G -C "$REPO_B" rev-parse HEAD~1)"; B_SHA="$(G -C "$REPO_B" rev-parse HEAD)"
B_SHA12="$(printf '%s' "$B_SHA" | cut -c1-12)"
# A DIVERGED base: a sibling of the frozen sha minted on B_BASE's tree, so its two-dot diff to
# B_SHA is the same six files and a build without the ancestor check answers a FULL map (rc 0).
B_SIB="$(G -C "$REPO_B" commit-tree "${B_BASE}^{tree}" -p "$B_BASE" -m sibling < /dev/null)" \
  || { echo "FIXTURE ERROR: commit-tree for the diverged base failed" >&2; exit 2; }
# C: four top directories of identical weight and NO --max-parts, so the default K alone decides
# the part count (4 under K=4; 2 under K=2).
REPO_C="$WORK/repo-c"
new_repo "$REPO_C" || { echo "FIXTURE ERROR: git init/commit failed" >&2; exit 2; }
for f in w1/a.txt w1/b.txt w2/a.txt w2/b.txt w3/a.txt w3/b.txt w4/a.txt w4/b.txt; do
  lines "$REPO_C/$f" 5 "$f"
done
G -C "$REPO_C" add -A && G -C "$REPO_C" commit -q -m frozen
[ -d "$REPO_C/.git" ] || { echo "FIXTURE ERROR: $REPO_C is not a repository" >&2; exit 2; }
C_BASE="$(G -C "$REPO_C" rev-parse HEAD~1)"; C_SHA="$(G -C "$REPO_C" rev-parse HEAD)"
# LO / HI: the default's boundary, DFLT-1 and DFLT reviewable files, one top directory each so the
# map has independent groups. LO ALSO carries one pipeline artifact under a scan root, so its diff
# holds DFLT files and only the exclusion keeps it below the threshold.
REPO_LO="$WORK/repo-lo"; REPO_HI="$WORK/repo-hi"
new_repo "$REPO_LO" && new_repo "$REPO_HI" || { echo "FIXTURE ERROR: git init/commit failed" >&2; exit 2; }
_i=0; while [ "$_i" -lt "$DFLT" ]; do
  _i=$((_i + 1))
  [ "$_i" -lt "$DFLT" ] && lines "$REPO_LO/t$_i/f.txt" 5 "lo-$_i"
  lines "$REPO_HI/t$_i/f.txt" 5 "hi-$_i"
done
lines "$REPO_LO/docs/reviews/s1/0-old-code-review.md" 5 review
G -C "$REPO_LO" add -A && G -C "$REPO_LO" commit -q -m frozen
G -C "$REPO_HI" add -A && G -C "$REPO_HI" commit -q -m frozen
for r in "$REPO_LO" "$REPO_HI"; do
  [ -d "$r/.git" ] || { echo "FIXTURE ERROR: $r is not a repository" >&2; exit 2; }
done
LO_BASE="$(G -C "$REPO_LO" rev-parse HEAD~1)"; LO_SHA="$(G -C "$REPO_LO" rev-parse HEAD)"
HI_BASE="$(G -C "$REPO_HI" rev-parse HEAD~1)"; HI_SHA="$(G -C "$REPO_HI" rev-parse HEAD)"
# D: DFLT+2 reviewable files, the default-built MERGE world. Off the boundary on purpose, so the
# `<`/`<=` mutant is owned by the HI arm alone and this world owns what the manifest records.
REPO_D="$WORK/repo-d"
new_repo "$REPO_D" || { echo "FIXTURE ERROR: git init/commit failed" >&2; exit 2; }
_i=0; while [ "$_i" -lt "$((DFLT + 2))" ]; do _i=$((_i + 1)); lines "$REPO_D/u$_i/f.txt" 5 "d-$_i"; done
G -C "$REPO_D" add -A && G -C "$REPO_D" commit -q -m frozen
[ -d "$REPO_D/.git" ] || { echo "FIXTURE ERROR: $REPO_D is not a repository" >&2; exit 2; }
D_BASE="$(G -C "$REPO_D" rev-parse HEAD~1)"; D_SHA="$(G -C "$REPO_D" rev-parse HEAD)"
D_SHA12="$(printf '%s' "$D_SHA" | cut -c1-12)"

# --------------------------------------------------------------------------------- worlds
# A merge world: its own directory, the shard dir `1-code-review-<sha12>/` inside it holding the
# manifest the REAL partition (the predicate's own sibling) wrote, and --out beside it.
# new_world <script-dir> [repo] -> prints the shard dir
new_world() { # <script-dir> [repo] [dir-suffix] [pass-marker, e.g. -p2]
  local sd="$1" repo="${2:-$REPO_B}" sfx="${3:-code-review}" pm="${4:-}" w d
  w="$(mktemp -d "$WORK/w.XXXXXX")" || return 1
  d="$w/1-$sfx-$B_SHA12$pm"
  bash "$sd/partition-review-diff.sh" --map "$repo" "$B_BASE" "$B_SHA" --min-files 4 --max-parts 3 \
    --shard-dir "$d" > "$w/map" 2> "$w/map.err" < /dev/null || return 1
  [ -f "$d/.manifest" ] || return 1
  printf '%s' "$d"
}
out_of() { printf '%s/1-code-review.md' "$(dirname "$1")"; }

# shard <dir> <key> <verdict> <parts-cite> [reviewed-sha] [extra trailing text]
# Shaped on code-reviewer.md's Review Document Template (Summary, Findings with the three
# severity containers), with the shard lines in place of `## Verdict`.
shard() {
  local d="$1" k="$2" v="$3" cite="$4" sha="${5:-$B_SHA}" extra="${6:-}"
  {
    printf '# Code Review shard %s\n\nreviewed-sha: %s\nshard-verdict: %s\n\n' "$k" "$sha" "$v"
    printf '## Summary\nShard %s read its part. CONSERVE-%s-7f3a\n\n' "$k" "$k"
    printf '## Findings\n\n### Critical (must fix before merge)\n\n'
    printf '#### F-%s-1 an unchecked return in shard %s\nparts: %s\n\nBody of the finding.\n\n' "$k" "$k" "$cite"
    printf '### Important (should fix, can be follow-up)\n\n### Suggestions (optional improvements)\n\n'
    printf '## Architecture Alignment\nNothing further.\n'
    [ -n "$extra" ] && printf '%s\n' "$extra"
  } > "$d/$k.md"
}
world4() { # <script-dir> <v1> <v2> <v3> <vcross> -> shard dir with all four shards
  local d; d="$(new_world "$1")" || return 1
  shard "$d" 1 "$2" 1; shard "$d" 2 "$3" 2; shard "$d" 3 "$4" 3; shard "$d" cross "$5" "1, 3"
  printf '%s' "$d"
}

MO="$WORK/merge.out"
run_merge() { # <script-dir> <shard-dir> -> RC, $MO
  AI_DLC_PROJECT_ROOT="$PROJ" bash "$1/merge-review-shards.sh" "$2" --gate code-review --out "$(out_of "$2")" \
    > "$MO" 2>&1 < /dev/null; RC=$?
}
refused_clean() { # <token> <shard-dir>: exit 2, REFUSED:, the token, no file at --out, no temp
  local o; o="$(out_of "$2")"
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED:" && has "$MO" "$1" && [ ! -e "$o" ] \
    && [ -z "$(find "$(dirname "$o")" -maxdepth 1 -name '*.merge-tmp.*' 2>/dev/null)" ]
}
# Check 1's read of the FIRST match, by the value rule gate-validation.md Check 1 states. The merge
# writes a bare member on the line under `## Verdict`, so the strip below is that rule on every
# input this fixture produces.
check1_value() { # <file>
  local m ln txt v
  m="$(grep -inE -- "$PAT" "$1" | sed -n 1p)"; [ -n "$m" ] || return 1
  ln="${m%%:*}"; txt="${m#*:}"
  case "$txt" in *:*) v="${txt#*:}" ;; *) v="$(awk -v s="$ln" 'NR > s && /[^ \t]/ { print; exit }' "$1")" ;; esac
  printf '%s' "$v" | sed -e 's/^[ *]*//' -e 's/[ *]*$//'
}
check1_count() { local n; n="$(grep -ciE -- "$PAT" "$1")" || n=0; printf '%s' "$n"; }

# ------------------------------------------------------------------------------- predicates
# Each takes the SCRIPT DIRECTORY to drive, so the mutant battery scores the arm's own body.
p_part() { # repo A partitions to >= 2 parts, and the dominant app/ was split, never one key
  local sd="$1" out n spread
  out="$(bash "$sd/partition-review-diff.sh" --map "$REPO_A" "$A_BASE" "$A_SHA" --min-files 4 < /dev/null 2>&1)" || return 1
  n="$(grep -cE '^[0-9]+	' <<<"$out")" || n=0
  [ "$n" -ge 2 ] || return 1
  spread="$(grep -c 'app/' <<<"$out")" || spread=0
  [ "$spread" -ge 2 ] || return 1
  awk -F'\t' '{ split($2, k, ","); for (i in k) if (k[i] == "app/") bad = 1 } END { exit bad }' <<<"$out" || return 1
  ! grep -q 'docs/reviews/' <<<"$out"
}
p_dflt_lo() { # key unset, no flag, DFLT-1 reviewable (DFLT in the diff) -> SERIAL naming the default
  local sd="$1" d
  d="$(mktemp -d "$WORK/lo.XXXXXX")/sd"
  run_part "$sd" "$REPO_LO" "$LO_BASE" "$LO_SHA" --shard-dir "$d"
  [ "$PRC" -eq 3 ] && has "$PO" "SERIAL: $((DFLT - 1)) reviewable file(s) ($DFLT in the diff" \
    && has "$PO" "below the threshold of $DFLT (the built-in default" && has "$PO" "$KEY" && [ ! -e "$d/.manifest" ]
}
p_dflt_hi() { # key unset, no flag, exactly DFLT reviewable -> partitions
  local sd="$1" n
  run_part "$sd" "$REPO_HI" "$HI_BASE" "$HI_SHA"
  n="$(grep -cE '^[0-9]+	' "$PO")" || n=0
  [ "$PRC" -eq 0 ] && [ "$n" -ge 2 ]
}
p_off() { # the key at 0, and --min-files 0, each -> SERIAL saying sharding is disabled, no manifest
  local sd="$1" d
  d="$(mktemp -d "$WORK/off.XXXXXX")/sd"
  PRC=0; env "$KEY=0" bash "$sd/partition-review-diff.sh" --map "$REPO_HI" "$HI_BASE" "$HI_SHA" \
    --shard-dir "$d" > "$PO" 2> "$PE" < /dev/null || PRC=$?
  [ "$PRC" -eq 3 ] && has "$PO" "SERIAL: review sharding is disabled" && has "$PO" "$KEY is 0" \
    && [ ! -e "$d/.manifest" ] || return 1
  run_part "$sd" "$REPO_HI" "$HI_BASE" "$HI_SHA" --min-files 0 --shard-dir "$d"
  [ "$PRC" -eq 3 ] && has "$PO" "SERIAL: review sharding is disabled -- --min-files is 0" && [ ! -e "$d/.manifest" ]
}
p_refuse_val() { # the key set but EMPTY, WHITESPACE-only, or abc -> each REFUSED (exit 2), no manifest
  local sd="$1" d v
  d="$(mktemp -d "$WORK/rv.XXXXXX")/sd"
  for v in "" " " abc; do
    PRC=0; env "$KEY=$v" bash "$sd/partition-review-diff.sh" --map "$REPO_HI" "$HI_BASE" "$HI_SHA" \
      --shard-dir "$d" > "$PO" 2> "$PE" < /dev/null || PRC=$?
    part_refused "$KEY '$v' is not a non-negative integer" "$d" || return 1
  done
}
p_prec() { # flag and key both set, disagreeing across DFLT files: the FLAG wins, in both directions
  local sd="$1" n
  PRC=0; env "$KEY=4" bash "$sd/partition-review-diff.sh" --map "$REPO_HI" "$HI_BASE" "$HI_SHA" \
    --min-files "$((DFLT + 1))" > "$PO" 2> "$PE" < /dev/null || PRC=$?
  [ "$PRC" -eq 3 ] && has "$PO" "below the threshold of $((DFLT + 1)) (--min-files)" || return 1
  PRC=0; env "$KEY=$((DFLT + 1))" bash "$sd/partition-review-diff.sh" --map "$REPO_HI" "$HI_BASE" "$HI_SHA" \
    --min-files 4 > "$PO" 2> "$PE" < /dev/null || PRC=$?
  n="$(grep -cE '^[0-9]+	' "$PO")" || n=0
  [ "$PRC" -eq 0 ] && [ "$n" -ge 2 ]
}
p_dmerge() { # a merge world partitioned with the threshold UNSET, merged end to end
  local sd="$1" w d o k n mn first second
  w="$(mktemp -d "$WORK/dm.XXXXXX")" || return 1
  d="$w/1-code-review-$D_SHA12"
  bash "$sd/partition-review-diff.sh" --map "$REPO_D" "$D_BASE" "$D_SHA" --shard-dir "$d" \
    > "$w/map" 2> "$w/map.err" < /dev/null || return 1
  [ -f "$d/.manifest" ] || return 1
  # The NUMERIC threshold applied, never a source string: the merge hands it back as --min-files.
  mn="$(awk -F'\t' '$1 == "min-files" { print $2 }' "$d/.manifest")"
  case "$mn" in ""|*[!0-9]*) return 1 ;; esac
  n=0
  for k in $(cut -f1 "$w/map"); do n=$((n + 1)); shard "$d" "$k" APPROVED "$k" "$D_SHA"; done
  [ "$n" -ge 2 ] || return 1
  first="$(cut -f1 "$w/map" | sed -n 1p)"; second="$(cut -f1 "$w/map" | sed -n 2p)"
  shard "$d" cross APPROVED "$first, $second" "$D_SHA"
  o="$(out_of "$d")"; run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] || return 1
  # A second world with the flag AND the key set, disagreeing: the manifest records the FLAG's
  # number, the threshold actually applied, because that is what the merge hands back.
  w="$(mktemp -d "$WORK/dmf.XXXXXX")" || return 1
  d="$w/1-code-review-$D_SHA12"
  env "$KEY=4" bash "$sd/partition-review-diff.sh" --map "$REPO_D" "$D_BASE" "$D_SHA" \
    --min-files "$((DFLT + 1))" --shard-dir "$d" > "$w/map" 2> "$w/map.err" < /dev/null || return 1
  mn="$(awk -F'\t' '$1 == "min-files" { print $2 }' "$d/.manifest")"
  [ "$mn" = "$((DFLT + 1))" ]
}
p_env() { # the key set to 4 in the environment, no flag -> partitions
  local sd="$1" out n
  out="$(env "$KEY=4" bash "$sd/partition-review-diff.sh" --map "$REPO_B" "$B_BASE" "$B_SHA" < /dev/null 2>&1)" || return 1
  n="$(grep -cE '^[0-9]+	' <<<"$out")" || n=0
  [ "$n" -ge 2 ]
}
p_worst() { # three worlds where count/cross/last disagree with worst-of, and the all-APPROVED control
  local sd="$1" d o w want
  for w in "BLOCKED APPROVED APPROVED APPROVED BLOCKED" \
           "NEEDS_REWORK BLOCKED NEEDS_REWORK APPROVED BLOCKED" \
           "APPROVED APPROVED APPROVED APPROVED APPROVED"; do
    set -- $w; want="$5"
    d="$(world4 "$sd" "$1" "$2" "$3" "$4")" || return 1
    o="$(out_of "$d")"; run_merge "$sd" "$d"
    [ "$RC" -eq 0 ] && has "$MO" "verdict=$want " && [ -f "$o" ] && [ "$(check1_value "$o")" = "$want" ] || return 1
  done
}
p_c1() { # Check 1's pattern matches the merged file EXACTLY once, and reads NEEDS_REWORK
  local sd="$1" d o
  d="$(world4 "$sd" NEEDS_REWORK APPROVED NEEDS_REWORK NEEDS_REWORK)" || return 1
  o="$(out_of "$d")"; run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && [ -f "$o" ] && [ "$(check1_count "$o")" = "1" ] && [ "$(check1_value "$o")" = "NEEDS_REWORK" ]
}
p_conserve() { # a unique token from every part and from cross appears in the output
  local sd="$1" d o k
  d="$(world4 "$sd" NEEDS_REWORK APPROVED NEEDS_REWORK NEEDS_REWORK)" || return 1
  o="$(out_of "$d")"; run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && [ -f "$o" ] || return 1
  for k in 1 2 3 cross; do has "$o" "CONSERVE-$k-7f3a" && has "$o" "#### F-$k-1 " || return 1; done
}
p_miss_ord() { local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  rm -f "$d/2.md"; run_merge "$1" "$d"; refused_clean "shard 2 is missing from" "$d"; }
p_miss_cross() { local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  rm -f "$d/cross.md"; run_merge "$1" "$d"; refused_clean "shard cross is missing from" "$d"; }
p_dup() { local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  cp "$d/1.md" "$d/01.md"; run_merge "$1" "$d"; refused_clean "was delivered more than once" "$d"; }
p_part_cite() { local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  shard "$d" 2 APPROVED 3; run_merge "$1" "$d"
  refused_clean "a part shard reports only findings citing its own part alone" "$d"; }
p_cross_one() { local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  shard "$d" cross APPROVED 2; run_merge "$1" "$d"
  refused_clean "a cross finding cites two or more parts" "$d"; }
p_sha_dir() { # the manifest's sha is not the one the directory name carries
  local d n; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  n="$(dirname "$d")/1-code-review-000000000000"; mv "$d" "$n"
  run_merge "$1" "$n"; refused_clean "is not <idx>-code-review-<sha12>" "$n"; }
p_sha_rev() { # one shard reviewed another tree
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  shard "$d" 2 APPROVED 2 "$B_BASE"; run_merge "$1" "$d"
  refused_clean "not the frozen sha" "$d"; }
p_moved() { # the manifest was written, then the worktree's scan roots moved under it
  local sd="$1" w c d g
  w="$(mktemp -d "$WORK/mv.XXXXXX")" || return 1
  c="$w/repo"; cp -R "$REPO_B" "$c" || return 1
  d="$(new_world "$sd" "$c")" || return 1
  shard "$d" 1 APPROVED 1; shard "$d" 2 APPROVED 2; shard "$d" 3 APPROVED 3; shard "$d" cross APPROVED "1, 3"
  g="$c/core/skills/ai-dlc/artifact-path-grammar.md"
  awk '{ print } /^```scan-roots$/ { print "alpha/a1.txt" }' "$g" > "$g.new" && mv "$g.new" "$g"
  # The re-run must still PARTITION (5 reviewable >= 4), or the refusal is the wrong one.
  bash "$sd/partition-review-diff.sh" --map "$c" "$B_BASE" "$B_SHA" --min-files 4 --max-parts 3 > "$w/remap" 2>&1 < /dev/null || return 1
  ! cmp -s "$w/remap" "$(dirname "$d")/map" || return 1
  run_merge "$sd" "$d"
  refused_clean "differs from the map it records" "$d"
}
p_a3() { # a shard body carrying `## Verdict` -> two Check-1 matches -> refused
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  shard "$d" 2 APPROVED 2 "" "$(printf '## Verdict\nAPPROVED')"; run_merge "$1" "$d"
  refused_clean "matches Check 1's verdict pattern 2 time(s)" "$d"
}
# A partition refusal: exit 2, ONE stderr line `partition-review-diff: REFUSED — ...` carrying the
# token, nothing on stdout, and no manifest (nor its temp) in <dir>.
PO="$WORK/part.out"; PE="$WORK/part.err"
run_part() { # <script-dir> <args...> -> PRC, $PO, $PE
  local sd="$1"; shift
  bash "$sd/partition-review-diff.sh" --map "$@" > "$PO" 2> "$PE" < /dev/null; PRC=$?
}
part_refused() { # <token> <shard-dir>
  [ "$PRC" -eq 2 ] && has "$PE" "partition-review-diff: REFUSED" && has "$PE" "$1" && ! grep -q . "$PO" \
    && [ ! -e "$2/.manifest" ] && [ -z "$(find "$2" -maxdepth 1 -name '.manifest.tmp.*' 2>/dev/null)" ]
}
# A shard written by hand, for the bodies shard() cannot express.
raw_shard() { # <dir> <key> <body...>: the two shard lines, then the body lines verbatim
  local d="$1" k="$2"; shift 2
  { printf '# Code Review shard %s\n\nreviewed-sha: %s\nshard-verdict: APPROVED\n\n' "$k" "$B_SHA"
    printf '%s\n' "$@"; } > "$d/$k.md"
}
p_rerun() { # MC: an identical re-merge is UNCHANGED; after a shard changed, refused, file untouched
  local sd="$1" d o
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
  o="$(out_of "$d")"; run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] || return 1
  cp "$o" "$WORK/rerun.keep" || return 1
  run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "UNCHANGED:" && cmp -s "$o" "$WORK/rerun.keep" || return 1
  shard "$d" 1 BLOCKED 1; run_merge "$sd" "$d"
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED:" && has "$MO" "a review file is never overwritten" \
    && cmp -s "$o" "$WORK/rerun.keep" && [ -z "$(find "$(dirname "$o")" -maxdepth 1 -name '*.merge-tmp.*')" ]
}
p_anc() { # E1: a base that is not an ancestor of the frozen sha is refused, nothing written
  local sd="$1" d
  d="$(mktemp -d "$WORK/anc.XXXXXX")/sd"
  run_part "$sd" "$REPO_B" "$B_SIB" "$B_SHA" --min-files 4 --max-parts 3 --shard-dir "$d"
  part_refused "is not an ancestor of the frozen sha" "$d"
}
p_cross_sha() { # MF: the CROSS shard carrying the base sha as reviewed-sha
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  shard "$d" cross APPROVED "1, 3" "$B_BASE"; run_merge "$1" "$d"
  refused_clean "not the frozen sha" "$d"; }
p_bad_verdict() { # MG: `shard-verdict: PASS` is outside the three ranked values
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  shard "$d" 2 PASS 2; run_merge "$1" "$d"
  refused_clean "shard-verdict 'PASS' is not one of APPROVED NEEDS_REWORK BLOCKED" "$d"; }
p_noparts() { # MH: a `#### ` finding inside ## Findings with no parts: line
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  raw_shard "$d" 2 '## Findings' '' '### Critical (must fix before merge)' '' \
    '#### F-2-1 cited' 'parts: 2' '' '#### F-2-2 uncited' '' 'Body of the finding.'
  run_merge "$1" "$d"; refused_clean "finding carries 0 'parts:' lines" "$d"; }
p_manifest() { # MI: an identical re-run leaves the manifest; a --max-parts 2 re-run is refused
  local sd="$1" d keep
  d="$(new_world "$sd")" || return 1
  keep="$(dirname "$d")/manifest.keep"; cp "$d/.manifest" "$keep" || return 1
  run_part "$sd" "$REPO_B" "$B_BASE" "$B_SHA" --min-files 4 --max-parts 3 --shard-dir "$d"
  [ "$PRC" -eq 0 ] && cmp -s "$d/.manifest" "$keep" || return 1
  run_part "$sd" "$REPO_B" "$B_BASE" "$B_SHA" --min-files 4 --max-parts 2
  [ "$PRC" -eq 0 ] && ! cmp -s "$PO" "$(dirname "$d")/map" || return 1   # the two maps differ
  run_part "$sd" "$REPO_B" "$B_BASE" "$B_SHA" --min-files 4 --max-parts 2 --shard-dir "$d"
  [ "$PRC" -eq 2 ] && has "$PE" "a manifest is never overwritten" && cmp -s "$d/.manifest" "$keep" \
    && [ -z "$(find "$d" -maxdepth 1 -name '.manifest.tmp.*')" ]
}
p_two_sha() { # MK: a second reviewed-sha: line (the base) after the right one
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  shard "$d" 2 APPROVED 2 "" "reviewed-sha: $B_BASE"; run_merge "$1" "$d"
  refused_clean "carries 2 'reviewed-sha:' line(s)" "$d"; }
p_default_k() { # MM: four equal groups, no --max-parts -> exactly four parts
  local sd="$1" n
  run_part "$sd" "$REPO_C" "$C_BASE" "$C_SHA" --min-files 4
  [ "$PRC" -eq 0 ] || return 1
  n="$(grep -cE '^[0-9]+	' "$PO")" || n=0
  [ "$n" = "4" ]
}
p_stray() { # E3a: parts: outside a #### finding under ## Findings, in a shard that HAS ## Findings
  local sd="$1" d
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
  raw_shard "$d" 1 '## Findings' '' '### Critical (must fix before merge)' '' \
    '- **C-1** SQL injection in part 3 code' '  parts: 3'
  run_merge "$sd" "$d"
  refused_clean "carries a 'parts:' line outside a '#### ' finding under '## Findings'" "$d" || return 1
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
  raw_shard "$d" 1 '## Critical Issues' '' '#### C-1 boom' 'parts: 3' '' \
    '## Findings' '' '### Critical (must fix before merge)' '' '#### F-1-1 cited' 'parts: 1'
  run_merge "$sd" "$d"
  refused_clean "carries a 'parts:' line outside a '#### ' finding under '## Findings'" "$d"
}
p_nofind() { # E3b: a shard with no ## Findings section (and no parts: line anywhere)
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  raw_shard "$d" 1 '## Summary' 'Nothing to report.'
  run_merge "$1" "$d"; refused_clean "carries no '## Findings' section" "$d"; }
p_knob() { # E2: a value over 9 digits refuses before arithmetic; a 9-digit threshold is SERIAL
  local sd="$1" d
  d="$(mktemp -d "$WORK/knob.XXXXXX")/sd"
  run_part "$sd" "$REPO_B" "$B_BASE" "$B_SHA" --min-files 18446744073709551617 --shard-dir "$d"
  part_refused "'18446744073709551617' is longer than 9 digits" "$d" || return 1
  PRC=0; env "$KEY=18446744073709551617" bash "$sd/partition-review-diff.sh" --map "$REPO_B" "$B_BASE" "$B_SHA" \
    --shard-dir "$d" > "$PO" 2> "$PE" < /dev/null || PRC=$?
  part_refused "$KEY '18446744073709551617' is longer than 9 digits" "$d" || return 1
  run_part "$sd" "$REPO_B" "$B_BASE" "$B_SHA" --min-files 4 --max-parts 18446744073709551617 --shard-dir "$d"
  part_refused "--max-parts '18446744073709551617' is longer than 9 digits" "$d" || return 1
  # 65, not a 9-digit K: with the ceiling mutated away a 9-digit K spins the packer, and the
  # arm must die by a map appearing, not by the fixture hanging.
  run_part "$sd" "$REPO_B" "$B_BASE" "$B_SHA" --min-files 4 --max-parts 65 --shard-dir "$d"
  part_refused "--max-parts 65 is above 64" "$d" || return 1
  run_part "$sd" "$REPO_B" "$B_BASE" "$B_SHA" --min-files 999999999 --shard-dir "$d"
  [ "$PRC" -eq 3 ] && has "$PO" "SERIAL:" && [ ! -e "$d/.manifest" ]
}
# ------------------------------------------------------------------------- gate 2: --gate qa
# QA shards are the gate-1 grammar with qa.md's verdict set {PASS, NEEDS_REWORK}, the shard dir
# `<idx>-qa-validation-<sha12>[-p<M>]`, and two sections only the cross shard carries: the per-AC
# table under `## Acceptance Criteria` (exactly one) and `## Deferred ACs` (at most one). Shaped on
# qa.md's own output: a per-AC result is a PIPE-LED table row, which Check 1's pattern cannot match.
# THE REFUSAL TOKENS are the merge's own message fragments; each arm demands one, so an arm whose
# subject refused for another reason does not pass.
QT_PART_AC="(part shard 2) carries a '## Acceptance Criteria' section"
QT_PART_DEF="(part shard 3) carries a '## Deferred ACs' section"
QT_AC_0="carries 0 '## Acceptance Criteria' section(s) outside a fence; the cross shard carries exactly one"
QT_AC_2="carries 2 '## Acceptance Criteria' section(s) outside a fence; the cross shard carries exactly one"
QT_DEF_COUNT="carries 2 '## Deferred ACs' sections outside a fence; the cross shard carries at most one"
QT_VSET="qa.md's ## Verdict template declares"
QT_VSET_CR="code-reviewer.md's ## Verdict template declares"
QT_PASS="pass marker mismatch"
QT_SUFFIX="is not <idx>-qa-validation-<sha12>"
QT_SUFFIX_CR="is not <idx>-code-review-<sha12>"
QT_GATE="is not code-review or qa"
QT_RANK="shard-verdict 'APPROVED' is not one of PASS NEEDS_REWORK"
QA_SFX="qa-validation"
qout() { printf '%s/1-%s%s.md' "$(dirname "$1")" "${2:-$QA_SFX}" "${3:-}"; } # <dir> [sfx] [pass marker]
run_mg() { # <script-dir> <shard-dir> <gate> <out> [project-root] -> RC, $MO
  AI_DLC_PROJECT_ROOT="${5:-$PROJ}" bash "$1/merge-review-shards.sh" "$2" --gate "$3" --out "$4" \
    > "$MO" 2>&1 < /dev/null; RC=$?
}
refused_at() { # <token> <out>
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED:" && has "$MO" "$1" && [ ! -e "$2" ] \
    && [ -z "$(find "$(dirname "$2")" -maxdepth 1 -name '*.merge-tmp.*' 2>/dev/null)" ]
}
# qshard <dir> <key> <verdict> <cite> [extra trailing text] [handovers count]. The cross shard
# carries the per-AC table and the deferred-AC record; a part shard carries neither, and carries
# the declared `handovers: <n>` header line instead -- 0 unless the caller names the count its
# extra text hands over. The count is written by each caller, never computed from the text here:
# a helper that counted the text would be a second copy of the merge's parser.
qshard() {
  local d="$1" k="$2" v="$3" cite="$4" extra="${5:-}" hc="${6:-0}"
  {
    printf '# QA Validation shard %s\n\nreviewed-sha: %s\nshard-verdict: %s\n' "$k" "$B_SHA" "$v"
    [ "$k" = cross ] || [ "$hc" = OMIT ] || printf 'handovers: %s\n' "$hc"
    printf '\n'
    printf '## Summary\nShard %s validated its part. QCONSERVE-%s-91c2\n\n' "$k" "$k"
    printf '## Findings\n\n#### Q-%s-1 a missing caller in shard %s\nparts: %s\n\nBody.\n\n' "$k" "$k" "$cite"
    if [ "$k" = cross ]; then
      printf '## Acceptance Criteria\n\n| AC | Verdict | Evidence |\n|---|---|---|\n| AC1 | PASS | suite green |\n| AC2 | %s | replay |\n\n' "$v"
      printf '## Deferred ACs\n\nNone.\n'
    fi
    [ -n "$extra" ] && printf '%s\n' "$extra"
  } > "$d/$k.md"
}
qworld() { # <script-dir> <v1> <v2> <v3> <vcross> [pass marker] -> a qa shard dir with all four shards
  local d; d="$(new_world "$1" "$REPO_B" "$QA_SFX" "${6:-}")" || return 1
  qshard "$d" 1 "$2" 1; qshard "$d" 2 "$3" 2; qshard "$d" 3 "$4" 3; qshard "$d" cross "$5" "1, 3"
  printf '%s' "$d"
}
q_merge() { local o; o="$(qout "$2")"; run_mg "$1" "$2" qa "$o"; }
p_q_worst() { # Q1: worst-of over {PASS, NEEDS_REWORK}; the one-part-NR world is where an inverted rank answers PASS
  local sd="$1" d o w want
  for w in "PASS PASS PASS PASS PASS" "NEEDS_REWORK PASS PASS PASS NEEDS_REWORK" \
           "PASS PASS PASS NEEDS_REWORK NEEDS_REWORK"; do
    set -- $w; want="$5"
    d="$(qworld "$sd" "$1" "$2" "$3" "$4")" || return 1
    o="$(qout "$d")"; q_merge "$sd" "$d"
    [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$MO" "verdict=$want " && [ -f "$o" ] \
      && [ "$(check1_value "$o")" = "$want" ] || return 1
  done
}
p_q_table() { # Q2 (A6): a cross shard carrying a '| AC | Verdict |' table merges, Check 1 matching ONCE
  local sd="$1" d o k
  d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"; q_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && [ -f "$o" ] && has "$o" "| AC | Verdict | Evidence |" && [ "$(check1_count "$o")" = "1" ] || return 1
  for k in 1 2 3 cross; do has "$o" "QCONSERVE-$k-91c2" && has "$o" "#### Q-$k-1 " || return 1; done
}
p_q_title() { # Q3: the merged title names the gate -- `# Code Review:` for gate 1, `# QA Validation:` for gate 2
  local sd="$1" d o
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
  o="$(out_of "$d")"; run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && [ "$(sed -n 1p "$o")" = "# Code Review: 1 (merged from 4 shards)" ] || return 1
  d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"; q_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && [ "$(sed -n 1p "$o")" = "# QA Validation: 1 (merged from 4 shards)" ]
}
p_q_fenced() { # Q4 near-miss: a part shard quoting '## Acceptance Criteria' and '## Deferred ACs' inside a fence merges
  local sd="$1" d
  d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$(printf '```text\n## Acceptance Criteria\n## Deferred ACs\n```')"
  q_merge "$sd" "$d"; [ "$RC" -eq 0 ] && has "$MO" "MERGED:"
}
p_q_part_ac() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$(printf '## Acceptance Criteria\n\n| AC | Verdict |\n|---|---|\n| AC1 | PASS |')"
  o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_PART_AC" "$o"; }
p_q_part_def() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 3 PASS 3 "$(printf '## Deferred ACs\n\n- AC4: discharged by the deploy run')"
  o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_PART_DEF" "$o"; }
p_q_cross_noac() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  awk '/^## Acceptance Criteria$/ { print "## Per-AC results"; next } { print }' "$d/cross.md" > "$d/cross.tmp" \
    && mv "$d/cross.tmp" "$d/cross.md" && ! grep -q '^## Acceptance Criteria' "$d/cross.md" || return 1
  o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_AC_0" "$o"; }
p_q_cross_twoac() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" cross PASS "1, 3" "$(printf '\n## Acceptance Criteria\n\n| AC | Verdict |\n|---|---|\n| AC9 | PASS |')"
  o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_AC_2" "$o"; }
p_q_cross_twodef() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" cross PASS "1, 3" "$(printf '\n## Deferred ACs\n\n- AC5: deferred')"
  o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_DEF_COUNT" "$o"; }
p_q_nodef() { # Q-allow: a cross shard with NO '## Deferred ACs' merges (at most one, not exactly one)
  local d; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  awk '/^## Deferred ACs$/ { skip = 1; next } skip && /^## / { skip = 0 } !skip { print }' "$d/cross.md" > "$d/cross.tmp" \
    && mv "$d/cross.tmp" "$d/cross.md" && ! grep -q '^## Deferred ACs' "$d/cross.md" || return 1
  q_merge "$1" "$d"; [ "$RC" -eq 0 ] && has "$MO" "MERGED:"; }
p_q_secvar() { # Q16: the section counts take any heading VARIANT a shard writer produces -- case,
  # a trailing colon or word, two spaces, a `### ` level. One world, its part shards rewritten per
  # cell: a refusal writes nothing, so the world stays mergeable for the next cell.
  local sd="$1" d o h
  d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"
  for h in '## Acceptance Criteria:' '##  Acceptance Criteria' '## acceptance criteria' '### ACCEPTANCE CRITERIA'; do
    qshard "$d" 2 PASS 2 "$(printf '%s\n\n| AC | Verdict |\n|---|---|\n| AC1 | PASS |' "$h")"
    q_merge "$sd" "$d"; refused_at "$QT_PART_AC" "$o" || return 1
  done
  qshard "$d" 2 PASS 2
  for h in '### Deferred ACs' '## Deferred / operator-owned' '## deferred acs'; do
    qshard "$d" 3 PASS 3 "$(printf '%s\n\n- AC4: discharged by the deploy run' "$h")"
    q_merge "$sd" "$d"; refused_at "$QT_PART_DEF" "$o" || return 1
  done
  qshard "$d" 3 PASS 3
  qshard "$d" cross PASS "1, 3" "$(printf '\n## Acceptance Criteria:\n\n| AC | Verdict |\n|---|---|\n| AC9 | PASS |')"
  q_merge "$sd" "$d"; refused_at "$QT_AC_2" "$o" || return 1
  # Near-misses, which MERGE: the variants inside a fence, and a `#### ` FINDING titled with a
  # section name -- that level is a finding, never a section.
  qshard "$d" cross PASS "1, 3"
  qshard "$d" 2 PASS 2 "$(printf '```text\n## Acceptance Criteria:\n### deferred ACs\n```\n\n#### Acceptance criteria AC3 unmet\nparts: 2\n\nBody.\n\n#### Deferred AC4 has no predicate\nparts: 2\n\nBody.')"
  q_merge "$sd" "$d"; [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] && has "$o" "Acceptance criteria AC3 unmet"
}
p_q_rank() { # a qa shard carrying a gate-1 verdict is refused (APPROVED is not a QA verdict)
  local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 APPROVED 2; o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_RANK" "$o"; }
p_q_pm() { # A4, both gates: dir and --out pass markers agree -> merge; either one alone -> refused.
  # The merging cells assert MERGED and the file, never the verdict, so the verdict mutants are
  # owned by V1/Q1 alone.
  local sd="$1" d o
  d="$(qworld "$sd" PASS PASS PASS PASS -p2)" || return 1
  o="$(qout "$d" "$QA_SFX" -p2)"; run_mg "$sd" "$d" qa "$o"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] || return 1
  d="$(qworld "$sd" PASS PASS PASS PASS -p2)" || return 1
  o="$(qout "$d")"; run_mg "$sd" "$d" qa "$o"; refused_at "$QT_PASS" "$o" || return 1
  d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d" "$QA_SFX" -p2)"; run_mg "$sd" "$d" qa "$o"; refused_at "$QT_PASS" "$o" || return 1
  d="$(new_world "$sd" "$REPO_B" code-review -p3)" || return 1
  shard "$d" 1 APPROVED 1; shard "$d" 2 APPROVED 2; shard "$d" 3 APPROVED 3; shard "$d" cross APPROVED "1, 3"
  o="$(qout "$d" code-review -p3)"; run_mg "$sd" "$d" code-review "$o"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] || return 1
  o="$(qout "$d" code-review)"; run_mg "$sd" "$d" code-review "$o"; refused_at "$QT_PASS" "$o" || return 1
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
  o="$(qout "$d" code-review -p2)"; run_mg "$sd" "$d" code-review "$o"; refused_at "$QT_PASS" "$o"
}
p_q_suffix() { # a gate-1 shard dir merged as --gate qa, and a qa shard dir merged as --gate code-review
  local sd="$1" d o
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
  o="$(qout "$d")"; run_mg "$sd" "$d" qa "$o"; refused_at "$QT_SUFFIX" "$o" || return 1
  d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1
  o="$(out_of "$d")"; run_mg "$sd" "$d" code-review "$o"; refused_at "$QT_SUFFIX_CR" "$o"
}
p_q_gate() { # an unknown gate refuses, on a world either gate would merge
  local sd="$1" d o
  d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"; run_mg "$sd" "$d" deploy "$o"; refused_at "$QT_GATE" "$o"
}
# Two project roots for the verdict-set lift. QBAD: qa.md declares a third value -> --gate qa
# refuses. CRBAD (the ALLOW twin, one property apart): code-reviewer.md's verdict line broken,
# qa.md intact -> --gate qa still merges and --gate code-review refuses. A merge that lifted QA's
# set from code-reviewer.md fails both halves.
PROJ_QBAD="$WORK/proj-qbad"; PROJ_CRBAD="$WORK/proj-crbad"
for _r in "$PROJ_QBAD" "$PROJ_CRBAD"; do
  mkdir -p "$_r/core/skills/ai-dlc/steps" "$_r/core/team-roles"
  cp "$PROJ/core/skills/ai-dlc/steps/gate-validation.md" "$_r/core/skills/ai-dlc/steps/"
  cp "$PROJ/core/team-roles/code-reviewer.md" "$PROJ/core/team-roles/qa.md" "$_r/core/team-roles/"
done
sed -e 's/^PASS | NEEDS_REWORK$/PASS | NEEDS_REWORK | BLOCKED/' "$PROJ/core/team-roles/qa.md" > "$PROJ_QBAD/core/team-roles/qa.md"
sed -e 's/^APPROVED | NEEDS_REWORK | BLOCKED$/APPROVED | NEEDS_REWORK | BLOCKED | DEFERRED/' "$PROJ/core/team-roles/code-reviewer.md" > "$PROJ_CRBAD/core/team-roles/code-reviewer.md"
p_q_vset() {
  local sd="$1" d o
  d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"; run_mg "$sd" "$d" qa "$o" "$PROJ_QBAD"; refused_at "$QT_VSET" "$o" || return 1
  run_mg "$sd" "$d" qa "$o" "$PROJ_CRBAD"
  [ "$RC" -eq 0 ] && has "$MO" "verdict=PASS " && [ -f "$o" ] || return 1
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
  o="$(out_of "$d")"; run_mg "$sd" "$d" code-review "$o" "$PROJ_CRBAD"; refused_at "$QT_VSET_CR" "$o"
}
# HAND-OVERS (--gate qa). A part shard whose replay cannot reach a GREEN baseline hands the AC to
# the cross shard as a `handover: <AC>` line in a `#### ` finding; the cross shard records the
# replay it ran as `handover-run: <ordinal> <AC> <result>`. Seeded the way qa.md tells each writer
# to emit them: the part's finding under `### Important`, the cross's inside its `## Findings`.
# The hand-over sits in part 2, never the first part read.
QT_HO_UNM="hand-over '2 AC7' (part shard 2) has no 'handover-run:' line in cross.md"
QT_HO_ORPH="cross.md carries 'handover-run: 2 AC7' but part shard 2 handed over no such AC"
QT_HO_CROSS="carries a 'handover:' line; only a part shard hands an AC over"
QT_HO_PRUN="(part shard 3) carries a 'handover-run:' line; only the cross shard runs a handed-over replay"
QT_HO_CITE="a hand-over replay finding cites exactly the parts it ran replays for"
QT_HO_STRAY="carries a 'handover:' or 'handover-run:' line outside a '#### ' finding"
HO_PART2="$(printf '### Important\n\n#### Q-2-H AC7 replay cannot reach a GREEN baseline in the part worktree\nparts: 2\nhandover: AC7\n\nThe documented setup fails in a fresh worktree.')"
qcross() { # <dir> <verdict> <text inserted inside cross.md's ## Findings>
  {
    printf '# QA Validation shard cross\n\nreviewed-sha: %s\nshard-verdict: %s\n\n' "$B_SHA" "$2"
    printf '## Summary\nShard cross validated its part. QCONSERVE-cross-91c2\n\n'
    printf '## Findings\n\n#### Q-cross-1 a missing caller in shard cross\nparts: 1, 3\n\nBody.\n\n%s\n\n' "$3"
    printf '## Acceptance Criteria\n\n| AC | Verdict | Evidence |\n|---|---|---|\n| AC1 | PASS | suite green |\n\n## Deferred ACs\n\nNone.\n'
  } > "$1/cross.md"
}
ho_run() { printf '#### Q-cross-H hand-over replays\nparts: %s\nhandover-run: %s\n\nRan in the frozen worktree after setup.' "$1" "$2"; }
p_q_ho_ok() { # a hand-over matched by `handover-run: ... RED` merges at the shard verdicts' worst-of
  local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$HO_PART2" 1; qcross "$d" PASS "$(ho_run 2 '2 AC7 RED')"
  o="$(qout "$d")"; q_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "verdict=PASS " && [ "$(check1_value "$o")" = "PASS" ] && has "$o" "| 2 | AC7 | RED |"
}
p_q_ho_unm() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$HO_PART2" 1; o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_HO_UNM" "$o"; }
p_q_ho_orph() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qcross "$d" PASS "$(ho_run 2 '2 AC7 RED')"; o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_HO_ORPH" "$o"; }
p_q_ho_force() { # GREEN-SURVIVED and NO-BASELINE each force NEEDS_REWORK over four PASS shards
  local d o r
  for r in GREEN-SURVIVED NO-BASELINE; do
    d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
    qshard "$d" 2 PASS 2 "$HO_PART2" 1; qcross "$d" PASS "$(ho_run 2 "2 AC7 $r")"
    o="$(qout "$d")"; q_merge "$1" "$d"
    [ "$RC" -eq 0 ] && has "$MO" "verdict=NEEDS_REWORK " && [ "$(check1_value "$o")" = "NEEDS_REWORK" ] || return 1
  done
}
p_q_ho_cross() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qcross "$d" PASS "$(printf '#### Q-cross-H AC8 cannot be replayed\nparts: 1, 3\nhandover: AC8\n\nBody.')"
  o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_HO_CROSS" "$o"; }
p_q_ho_prun() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 3 PASS 3 "$(printf '#### Q-3-H ran AC7 myself\nparts: 3\nhandover-run: 3 AC7 RED\n\nBody.')"
  o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_HO_PRUN" "$o"; }
p_q_ho_fenced() { # a hand-over and a forcing replay QUOTED inside fences, inside findings, count as neither
  local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$(printf '#### Q-2-F quoting the grammar\nparts: 2\n\n```text\nhandover: AC7\n```')"
  qcross "$d" PASS "$(printf '#### Q-cross-F quoting the grammar\nparts: 1, 2\n\n~~~\nhandover-run: 2 AC9 GREEN-SURVIVED\n~~~')"
  o="$(qout "$d")"; q_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "verdict=PASS " && [ "$(check1_value "$o")" = "PASS" ]
}
p_q_ho_shape() { # a replay finding citing a part it ran nothing for, and a bulleted hand-over, each refused
  local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$HO_PART2" 1; qcross "$d" PASS "$(ho_run '1, 2' '2 AC7 RED')"
  o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_HO_CITE" "$o" || return 1
  qshard "$d" 2 PASS 2 "$(printf '#### Q-2-H AC7 replay cannot reach a GREEN baseline\nparts: 2\n- handover: AC7\n\nBody.')" 1
  qcross "$d" PASS ""
  q_merge "$1" "$d"; refused_at "$QT_HO_STRAY" "$o"
}
# THREE REFUSALS, EACH KEYED ON ITS OWN MESSAGE, each world shaped so that WITHOUT the refusal it
# MERGES rather than failing elsewhere: a two-AC line whose first AC is run (the second AC's
# replay is then run by nobody and the merge said PASS -- measured); two `handover:` lines in one
# finding, both run; the same hand-over in two findings, run once.
QT_HO_MULTI="handover: 'AC7 AC8' names more than one AC; a hand-over line names exactly one <AC-id>"
QT_HO_TWOLINE="finding carries 2 'handover:' lines; a hand-over finding names exactly one AC"
QT_HO_DUP="hand-over '2 AC7' (<ordinal> <AC-id>) is handed over more than once"
QT_HO_BAD="is a malformed hand-over line (decorated, quoted, hyphenated or missing its colon)"
QT_HO_ACID="is not an <AC-id> (one token beginning with a letter or digit)"
p_q_ho_multi() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$(printf '### Important\n\n#### Q-2-H AC7 and AC8 cannot reach GREEN\nparts: 2\nhandover: AC7 AC8\n\nBody.')" 1
  qcross "$d" PASS "$(ho_run 2 '2 AC7 RED')"
  o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_HO_MULTI" "$o"; }
p_q_ho_twoline() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$(printf '### Important\n\n#### Q-2-H AC7 and AC8 cannot reach GREEN\nparts: 2\nhandover: AC7\nhandover: AC8\n\nBody.')" 2
  qcross "$d" PASS "$(printf '#### Q-cross-H hand-over replays\nparts: 2\nhandover-run: 2 AC7 RED\nhandover-run: 2 AC8 RED\n\nRan both.')"
  o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_HO_TWOLINE" "$o"; }
p_q_ho_dup() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$(printf '%s\n\n#### Q-2-H2 AC7 again\nparts: 2\nhandover: AC7\n\nBody.' "$HO_PART2")" 2
  qcross "$d" PASS "$(ho_run 2 '2 AC7 RED')"
  o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_HO_DUP" "$o"; }
# A MISSPELLED HAND-OVER DROPS SILENTLY unless something refuses it: it is neither a hand-over nor
# a stray, so a part's unreachable AC merged with no replay owed. Each form in its own cell, in a
# part-2 finding where a real `handover:` line would sit. The near-miss (q_ho_prose) is prose
# that NAMES the hand-over -- at column 0, with a colon later in the line, and `Handover step`,
# which the no-colon form would read as an AC-id without the digit it requires.
#
# HOW THE FALSE-POSITIVE SET REACHED ZERO. The widened pattern was run outside fences, as the
# merge reads, over every tracked `*qa-validation*.md` and `*code-review*.md` of the reference
# consumer (333 files) and this repo's `docs/reviews/` (47): 0 lines refused -- a floor, since
# neither corpus carries the token at all. So it was also run over every tracked `*.md` of both
# trees (8511 and 291 files opened): 0 consumer lines, and 1 here, `qa.md`'s own backtick-quoted
# `handover-run:` grammar line, which is role prose the merge never reads. The no-colon form
# first matched any one-word line (`handover AC7` and `handover step` alike); it now requires the
# token to carry a digit, as every AC-id in both corpora does, and `Handover step` merges.
# The SECOND widening (any non-alphanumeric run as the separator, a token boundary after the AC-id
# instead of end of line, a `1. ` list prefix) was re-run the same way over the same two corpora,
# the lines the parser consumes first excluded: 0 graph lines of 8511 files opened (control: 3
# unfenced lines naming a hand-over), and the same 1 `qa.md` line here (control: 18). The prose
# near-miss H14 still merges because every prose form's next token carries no digit.
p_q_ho_deco() { # the label decorated, quoted or hyphenated -- each REFUSED as malformed
  local d o f; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"
  for f in '**handover:** AC7' '*handover*: AC7' '`handover: AC7`' '> handover: AC7' 'hand-over: AC7' \
           '**handover-run:** 2 AC7 RED' '`handover-run: 2 AC7 RED`' 'hand-over-run: 2 AC7 RED'; do
    qshard "$d" 2 PASS 2 "$(printf '### Important\n\n#### Q-2-H AC7 cannot reach GREEN\nparts: 2\n%s\n\nBody.' "$f")"
    q_merge "$1" "$d"; refused_at "$QT_HO_BAD" "$o" || return 1
  done
}
p_q_ho_nocolon() { # the label at column 0 with its colon missing -- each REFUSED as malformed
  local d o f; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"
  for f in 'handover - AC7' 'handover AC7' 'handover-run 2 AC7 RED' 'handover-run - 2 AC7 RED'; do
    qshard "$d" 2 PASS 2 "$(printf '### Important\n\n#### Q-2-H AC7 cannot reach GREEN\nparts: 2\n%s\n\nBody.' "$f")"
    q_merge "$1" "$d"; refused_at "$QT_HO_BAD" "$o" || return 1
  done
}
p_q_ho_prose() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$(printf '#### Q-2-P the handover step\nparts: 2\n\nThe handover step runs after setup.\nHandover of AC7 is not needed here.\nHandover to the cross shard: none, every replay reached GREEN.\nHandover step\nhand-over is not owed\n\nBody.')"
  o="$(qout "$d")"; q_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] && has "$o" "Handover to the cross shard: none"; }
p_q_ho_acid() { # an empty hand-over (parsed as `-`) and `.` -- each joins its run unless refused
  local d o a; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"
  for a in '' '.'; do
    qshard "$d" 2 PASS 2 "$(printf '### Important\n\n#### Q-2-H an AC cannot reach GREEN\nparts: 2\nhandover: %s\n\nBody.' "$a")" 1
    qcross "$d" PASS "$(ho_run 2 "2 ${a:--} RED")"
    q_merge "$1" "$d"; refused_at "$QT_HO_ACID" "$o" || return 1
  done
}
# THE DECLARED COUNT. Every part shard carries `handovers: <n>`, and the merge refuses a count that
# disagrees with the `handover:` lines it parsed. This is the fail-closed half: four adversary
# rounds each found a spelling the malformed-line pattern missed, and a pattern of bad spellings
# cannot converge, but a hand-over the parser did not read is ALWAYS one short of the declaration.
# H17's forms (a pipe-table row, an HTML comment) are ones the malformed-line pattern does not
# match, so that arm is the one only the count check can refuse; H16's em dash is the brief's own
# example, and under a dropped equality check the malformed-line refusal answers it with ANOTHER
# message, which this arm's token does not accept.
QT_HC_MIS1="declares 'handovers: 1' but the merge parsed 0 'handover:' line(s)"
QT_HC_MIS0="declares 'handovers: 0' but the merge parsed 1 'handover:' line(s)"
QT_HC_MISSING="(part shard 2) carries 0 'handovers:' line(s) outside a fence"
QT_HC_TWO="(part shard 2) carries 2 'handovers:' line(s) outside a fence"
QT_HC_CROSS="carries a 'handovers:' line; only a part shard declares a hand-over count"
ho_find() { printf '### Important\n\n#### Q-2-H AC7 cannot reach GREEN\nparts: 2\n%s\n\nBody.' "$1"; }
p_q_hc_dash() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$(ho_find 'handover — AC7')" 1
  o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_HC_MIS1" "$o"; }
p_q_hc_hidden() { # forms the malformed-line pattern does not match, each declared as one hand-over
  local d o f; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"
  for f in '| handover | AC7 |' '<!-- handover: AC7 -->'; do
    qshard "$d" 2 PASS 2 "$(ho_find "$f")" 1
    q_merge "$1" "$d"; refused_at "$QT_HC_MIS1" "$o" || return 1
  done
}
p_q_hc_zero() { # a correct, RUN hand-over under `handovers: 0` -- merges PASS unless the count is checked
  local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$HO_PART2" 0; qcross "$d" PASS "$(ho_run 2 '2 AC7 RED')"
  o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_HC_MIS0" "$o"; }
p_q_hc_missing() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "" OMIT; ! grep -q '^handovers:' "$d/2.md" || return 1
  o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_HC_MISSING" "$o"; }
p_q_hc_two() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "handovers: 0"
  o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_HC_TWO" "$o"; }
p_q_hc_nonint() { local d o v; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"
  # 18446744073709551616 is 2^64: bash 3.2 wraps it inside $((10#...)), so only the width guard
  # refuses it (round-5 adversary, measured: without the guard it merged PASS over a hidden hand-over).
  for v in x -1 18446744073709551616; do
    qshard "$d" 2 PASS 2 "" "$v"
    q_merge "$1" "$d"; refused_at "(part shard 2) 'handovers: $v' is not a non-negative integer" "$o" || return 1
  done
  # A GLOB VALUE MUST BE REFUSED FROM ANY CWD. Run from a cwd holding files named `0` and `1`, where
  # a word-split read expands `?` and `[1]` into a valid count.
  local g; g="$(mktemp -d "$WORK/hcglob.XXXXXX")" || return 1
  : > "$g/0"; : > "$g/1"
  for v in '?' '[1]'; do
    qshard "$d" 2 PASS 2 "" "$v"
    ( cd "$g" && q_merge "$1" "$d"; refused_at "(part shard 2) 'handovers: $v' is not a non-negative integer" "$o" ) || return 1
  done
}
p_q_hc_cross() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" cross PASS "1, 3" "handovers: 0"
  o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_HC_CROSS" "$o"; }
p_q_hc_none() { # the ALLOW twin: every part `handovers: 0`, no hand-over anywhere, merges PASS
  local d o k; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  for k in 1 2 3; do grep -qx 'handovers: 0' "$d/$k.md" || return 1; done
  ! grep -q '^handovers:' "$d/cross.md" || return 1
  o="$(qout "$d")"; q_merge "$1" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "verdict=PASS " && [ "$(check1_value "$o")" = "PASS" ]; }
# THE WIDENED MALFORMED-LINE PATTERN, each form under `handovers: 0` so the count agrees and only
# the malformed-line refusal can refuse it: separators that are not ` - ` (em dash, en dash, `=`,
# `->`), a trailing reason after the AC-id, a numbered-list prefix, and the same for handover-run.
p_q_ho_widen() { local d o f; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"
  for f in 'handover — AC7' 'handover – AC7' 'handover = AC7' 'handover -> AC7' \
           'handover - AC7 because the baseline fails' 'handover AC7 (no GREEN baseline)' \
           '1. handover AC7' '1. **handover:** AC7' 'handover-run — 2 AC7 RED'; do
    qshard "$d" 2 PASS 2 "$(ho_find "$f")" 0
    q_merge "$1" "$d"; refused_at "$QT_HO_BAD" "$o" || return 1
  done
}
Q_ALL="q_worst q_table q_title q_fenced q_part_ac q_part_def q_cross_noac q_cross_twoac q_cross_twodef q_nodef q_rank q_pm q_suffix q_gate q_vset q_secvar q_ho_ok q_ho_unm q_ho_orph q_ho_force q_ho_cross q_ho_prun q_ho_fenced q_ho_shape q_ho_multi q_ho_twoline q_ho_dup q_ho_deco q_ho_nocolon q_ho_prose q_ho_acid q_hc_dash q_hc_hidden q_hc_zero q_hc_missing q_hc_two q_hc_nonint q_hc_cross q_hc_none q_ho_widen"
P_ALL="part dflt_lo dflt_hi off refuse_val prec dmerge env worst c1 conserve miss_ord miss_cross dup part_cite cross_one sha_dir sha_rev moved a3 rerun anc cross_sha bad_verdict noparts manifest two_sha default_k stray nofind knob $Q_ALL"

# ---------------------------------------------------------------------------------- the arms
echo "$NAME:"

# Seed controls: the worlds must be able to express what the arms are named for.
A_NAMES="$(G -C "$REPO_A" diff --name-only "$A_BASE..$A_SHA")"
A_REV="$(grep -v '^docs/reviews/' <<<"$A_NAMES")"
na="$(grep -c . <<<"$A_REV")" || na=0
nn="$(grep -vc '^app/' <<<"$A_REV")" || nn=0
if [ "$na" -eq 6 ] && [ "$nn" -eq 0 ]; then
  ok "W0: repo A's 6 reviewable files all sit under app/, so a first-path-component key has one group"
else
  bad "W0: FIXTURE BROKEN -- repo A has $na reviewable file(s), $nn outside app/; P1 cannot discriminate"
fi
if n1="$(printf '## Verdict\nAPPROVED\n' > "$WORK/ctl.md"; check1_count "$WORK/ctl.md")" && [ "$n1" = "1" ] \
   && [ "$(check1_value "$WORK/ctl.md")" = "APPROVED" ]; then
  ok "W1: the derived Check 1 pattern matches a bare '## Verdict' heading once and reads APPROVED off the next line"
else
  bad "W1: FIXTURE BROKEN -- the derived Check 1 pattern [$PAT] does not read a seeded '## Verdict / APPROVED'"
fi

arm() { # <predicate> <label-ok> <label-bad>
  if "p_$1" "$SRCDIR"; then ok "$2"; else bad "$3 (rc=${RC:-?}): $(cat "$MO" 2>/dev/null | head -3)"; fi
}
arm part "P1: repo A (all files under app/) partitions to >= 2 parts above --min-files 4, app/ split across parts, no part keyed on bare app/, the docs/reviews/ artifact excluded" \
         "P1: repo A did not partition by adaptive depth"
arm dflt_lo "P2: key unset, no flag, $((DFLT - 1)) reviewable files ($DFLT in the diff, one under a scan root) -> exit 3, 'SERIAL:' naming the built-in default $DFLT and $KEY, no manifest" \
             "P2: below the built-in default did not answer SERIAL naming the default"
arm dflt_hi "P2b: key unset, no flag, exactly $DFLT reviewable files -> partitions to >= 2 parts (the default is ON, and the boundary is inclusive)" \
            "P2b: exactly the built-in default's file count did not partition"
arm off "P2c: $KEY=0, and --min-files 0, each on $DFLT files -> exit 3, 'SERIAL: review sharding is disabled' naming the source, no manifest" \
        "P2c: a zero threshold did not answer SERIAL disabled"
arm refuse_val "P2d: $KEY set but EMPTY, and $KEY=abc -> each REFUSED exit 2 'is not a non-negative integer', no manifest (empty is NOT unset)" \
               "P2d: an empty or non-numeric key was not refused"
arm prec "P2e: --min-files $((DFLT + 1)) with $KEY=4 on $DFLT files -> SERIAL naming --min-files; --min-files 4 with $KEY=$((DFLT + 1)) -> partitions (the flag wins both ways)" \
         "P2e: the key overrode --min-files"
arm dmerge "P2f: a repo of $((DFLT + 2)) files partitioned with the threshold UNSET records a NUMERIC min-files in its manifest and merges end to end (the merge hands it back as --min-files)" \
           "P2f: a default-built partition did not merge, or its manifest did not record the numeric threshold"
arm env "P3: the key set to 4 in the environment, no flag -> repo B partitions to >= 2 parts" \
        "P3: the environment threshold did not partition"
arm worst "V1: worst-of -- {B,A,A,xA} merges BLOCKED (cross, last and majority say APPROVED); {NR,B,NR,xA} merges BLOCKED (majority says NR); all-APPROVED merges APPROVED; each read back Check 1's way" \
          "V1: the merged verdict is not the worst shard verdict"
arm c1 "C1: the merged file matches Check 1's derived pattern exactly once and Check 1's read gives NEEDS_REWORK" \
       "C1: the merged file does not match Check 1 exactly once with the right value"
arm conserve "C2: conservation -- a unique token and the finding heading of each of parts 1-3 and cross appear in the merged file" \
             "C2: a shard's content was lost in the merge"
arm miss_ord "R1: part 2 missing -> REFUSED, exit 2, nothing at --out" "R1: a missing part was not refused cleanly"
arm miss_cross "R2: cross.md missing -> REFUSED, exit 2, nothing at --out" "R2: a missing cross shard was not refused cleanly"
arm dup "R3: 1.md beside 01.md -> REFUSED 'delivered more than once', exit 2, nothing at --out" "R3: a duplicate part was not refused cleanly"
arm part_cite "R4: part 2 reporting a finding citing part 3 -> REFUSED, exit 2, nothing at --out" "R4: a part citing another part was not refused cleanly"
arm cross_one "R5: a cross finding citing one part -> REFUSED, exit 2, nothing at --out" "R5: a one-part cross finding was not refused cleanly"
arm sha_dir "R6: a shard dir named for another sha12 than the manifest's -> REFUSED, exit 2, nothing at --out" "R6: a manifest/dir-name sha mismatch was not refused cleanly"
arm sha_rev "R7: a shard whose reviewed-sha is not the manifest's sha -> REFUSED, exit 2, nothing at --out" "R7: a reviewed-sha mismatch was not refused cleanly"
arm moved "R8: the worktree's scan roots moved after the manifest was written (the re-run still partitions, differently) -> REFUSED 'differs from the map it records', nothing at --out" \
          "R8: a manifest map that no longer matches a re-run partition was not refused cleanly"
arm a3 "R9: a shard body carrying '## Verdict' -> REFUSED on Check 1's count (2), exit 2, nothing at --out" "R9: a shard verdict heading was not refused"
arm rerun "R10: an identical re-merge is UNCHANGED; a re-merge after shard 1 changed -> REFUSED 'never overwritten', exit 2, the first review byte-unchanged" \
          "R10: a re-merge over a different existing review was not refused with the file intact"
arm anc "R11: a base that is not an ancestor of the frozen sha (a sibling commit, same two-dot file set) -> partition REFUSED on stderr, exit 2, no map, no manifest" \
        "R11: a diverged base was partitioned"
arm cross_sha "R12: cross.md whose reviewed-sha is the base -> REFUSED 'not the frozen sha', exit 2, nothing at --out" \
              "R12: a cross shard reviewing another tree was not refused"
arm bad_verdict "R13: 'shard-verdict: PASS' -> REFUSED, exit 2, nothing at --out" "R13: a verdict outside the ranked three was not refused"
arm noparts "R14: a '#### ' finding under ## Findings with no 'parts:' line -> REFUSED, exit 2, nothing at --out" \
            "R14: an uncited finding was not refused"
arm manifest "R15: an identical partition re-run leaves .manifest; a --max-parts 2 re-run (a different map) -> REFUSED 'never overwritten', manifest byte-unchanged" \
             "R15: a differing partition re-run over an existing manifest was not refused with the manifest intact"
arm two_sha "R16: a shard carrying two 'reviewed-sha:' lines (the right one first) -> REFUSED, exit 2, nothing at --out" \
            "R16: a second reviewed-sha line was not refused"
arm default_k "P4: four equal-weight groups and no --max-parts -> exactly 4 parts (the default K)" \
              "P4: the default part ceiling is not 4"
arm stray "R17: a 'parts:' line behind a bullet inside ## Findings, and a '#### ' citing part 3 under '## Critical Issues' beside a real ## Findings -> each REFUSED, exit 2, nothing at --out" \
          "R17: a parts: line outside a '#### ' finding under ## Findings was not refused"
arm nofind "R18: a shard with no '## Findings' section -> REFUSED, exit 2, nothing at --out" "R18: a shard without ## Findings was merged"
arm knob "R19: --min-files, the env key and --max-parts at 18446744073709551617 -> each REFUSED 'longer than 9 digits', no manifest; a 9-digit --min-files answers SERIAL" \
         "R19: a value over 9 digits was not refused before arithmetic"
# Gate 2. W2 first: the seeded per-AC table row must not be what Check 1 counts, or Q2 is vacuous.
if printf '| AC | Verdict | Evidence |\n| AC2 | NEEDS_REWORK | replay |\n' > "$WORK/qctl.md" && [ "$(check1_count "$WORK/qctl.md")" = "0" ] \
   && printf '## Acceptance Criteria\n**Verdict:** PASS\n' > "$WORK/qctl2.md" && [ "$(check1_count "$WORK/qctl2.md")" = "1" ]; then
  ok "W2: Check 1's derived pattern matches 0 pipe-led per-AC table rows and 1 bold 'Verdict:' label, so Q2's single match is the merge's own"
else
  bad "W2: FIXTURE BROKEN -- Check 1's pattern [$PAT] counts a pipe-led AC row, or misses a bold label; Q2 cannot discriminate"
fi
arm q_worst "Q1: --gate qa worst-of -- all PASS merges PASS; one part NEEDS_REWORK (cross PASS) merges NEEDS_REWORK; cross NEEDS_REWORK (parts PASS) merges NEEDS_REWORK; each read back Check 1's way" \
            "Q1: the merged QA verdict is not the worst shard verdict"
arm q_table "Q2: a cross shard carrying a '| AC | Verdict |' table under '## Acceptance Criteria' merges with exactly one Check-1 match, every shard's token and finding conserved" \
            "Q2: a QA cross shard with a per-AC table did not merge to exactly one Check-1 match"
arm q_title "Q3: the merged title is '# Code Review: 1 (merged from 4 shards)' for gate 1 and '# QA Validation: 1 (merged from 4 shards)' for gate 2" \
            "Q3: a merged title does not name its gate"
arm q_fenced "Q4: a part shard quoting '## Acceptance Criteria' and '## Deferred ACs' inside a fence merges (the section refusals skip fenced text)" \
             "Q4: a fenced section heading in a part shard was refused"
arm q_part_ac "Q5: a part shard carrying '## Acceptance Criteria' -> REFUSED, exit 2, nothing at --out" "Q5: a part shard's per-AC section was merged"
arm q_part_def "Q6: a part shard carrying '## Deferred ACs' -> REFUSED, exit 2, nothing at --out" "Q6: a part shard's deferred-AC section was merged"
arm q_cross_noac "Q7: cross.md without '## Acceptance Criteria' -> REFUSED, exit 2, nothing at --out" "Q7: a cross shard with no per-AC section was merged"
arm q_cross_twoac "Q8: cross.md with two '## Acceptance Criteria' sections -> REFUSED, exit 2, nothing at --out" "Q8: a cross shard with two per-AC sections was merged"
arm q_cross_twodef "Q9: cross.md with two '## Deferred ACs' sections -> REFUSED, exit 2, nothing at --out" "Q9: a cross shard with two deferred-AC sections was merged"
arm q_nodef "Q10: cross.md with NO '## Deferred ACs' merges (at most one, not exactly one)" "Q10: a cross shard without a deferred-AC section was refused"
arm q_rank "Q11: a qa shard carrying 'shard-verdict: APPROVED' -> REFUSED, exit 2 (gate 1's set is not gate 2's)" "Q11: a gate-1 verdict was ranked under --gate qa"
arm q_pm "Q12: pass markers, both gates -- dir -p2 with --out -p2 merges, dir -p2 with an unmarked --out and an unmarked dir with --out -p2 refuse (qa); the same three cells for code-review at -p3/-p2" \
         "Q12: a shard directory's pass marker and --out's disagree and the merge went ahead, or agree and it refused"
arm q_suffix "Q13: a <idx>-code-review-<sha12> dir merged --gate qa, and a <idx>-qa-validation-<sha12> dir merged --gate code-review -> each REFUSED, nothing at --out" \
             "Q13: a shard directory of the other gate was merged"
arm q_gate "Q14: --gate deploy -> REFUSED, exit 2, nothing at --out" "Q14: an unknown gate was not refused"
arm q_vset "Q15: qa.md declaring a third verdict -> --gate qa REFUSED; code-reviewer.md declaring a fourth -> --gate qa still merges PASS and --gate code-review refuses (QA's set is lifted from qa.md)" \
           "Q15: QA's verdict set is not lifted from qa.md alone"
arm q_secvar "Q16: part shards carrying '## Acceptance Criteria:', '##  Acceptance Criteria', '## acceptance criteria', '### ACCEPTANCE CRITERIA', '### Deferred ACs', '## Deferred / operator-owned', '## deferred acs', and a cross shard with a second '## Acceptance Criteria:' -> each REFUSED; the variants inside a fence and '#### ' findings titled with a section name merge" \
             "Q16: a section-heading variant escaped the count, or a fenced variant or a '#### ' finding was counted"
arm q_ho_ok "H1: part 2's 'handover: AC7' matched by cross's 'handover-run: 2 AC7 RED' merges PASS (the shard verdicts' worst-of), read back Check 1's way, the replay tabled" \
            "H1: a matched RED hand-over did not merge at the shard verdicts' worst-of"
arm q_ho_unm "H2: part 2's 'handover: AC7' with no 'handover-run:' in cross.md -> REFUSED naming '2 AC7', exit 2, nothing at --out" \
             "H2: an unmatched hand-over was merged -- its HARD GATE replay was run by nobody"
arm q_ho_orph "H3: cross.md's 'handover-run: 2 AC7 RED' with no hand-over in part 2 -> REFUSED, exit 2, nothing at --out" \
              "H3: an orphan handover-run was merged"
arm q_ho_force "H4: 'handover-run: 2 AC7 GREEN-SURVIVED', and NO-BASELINE, each over four PASS shards -> merges NEEDS_REWORK, read back Check 1's way" \
               "H4: an unmet hand-over replay did not force NEEDS_REWORK"
arm q_ho_cross "H5: a 'handover:' line in cross.md -> REFUSED, exit 2, nothing at --out" "H5: a cross-shard hand-over was merged"
arm q_ho_prun "H6: a 'handover-run:' line in part shard 3 -> REFUSED, exit 2, nothing at --out" "H6: a part-shard handover-run was merged"
arm q_ho_fenced "H7: 'handover: AC7' fenced in part 2 and 'handover-run: 2 AC9 GREEN-SURVIVED' fenced in cross merge PASS (neither is counted)" \
                "H7: a fenced hand-over line was counted"
arm q_ho_shape "H8: a replay finding citing '1, 2' for a part-2 replay, and a bulleted '- handover: AC7', each REFUSED" \
               "H8: a mis-cited replay finding or a bulleted hand-over was merged"
arm q_ho_multi "H9: part 2's 'handover: AC7 AC8' with only 'handover-run: 2 AC7 RED' in cross.md -> REFUSED 'names more than one AC', nothing at --out" \
               "H9: a two-AC hand-over line was merged -- the second AC's replay is run by nobody"
arm q_ho_twoline "H10: two 'handover:' lines in one part-2 finding, both run -> REFUSED on the per-finding count, nothing at --out" \
                 "H10: a finding carrying two hand-over lines was merged"
arm q_ho_dup "H11: two part-2 findings each 'handover: AC7', run once -> REFUSED 'handed over more than once', nothing at --out" \
             "H11: a duplicate hand-over was merged"
arm q_ho_deco "H12: '**handover:** AC7', '*handover*: AC7', a backtick-quoted and a '>'-quoted hand-over, 'hand-over: AC7', and the same for handover-run -> each REFUSED as a malformed hand-over" \
              "H12: a decorated, quoted or hyphenated hand-over line was merged -- the AC dropped with no replay owed"
arm q_ho_nocolon "H13: 'handover - AC7', 'handover AC7', 'handover-run 2 AC7 RED' and 'handover-run - 2 AC7 RED' at column 0 -> each REFUSED as a malformed hand-over" \
                 "H13: a column-0 hand-over missing its colon was merged"
arm q_ho_prose "H14: prose naming the hand-over at column 0 ('The handover step ...', 'Handover to the cross shard: none ...', 'Handover step', 'hand-over is not owed') merges PASS" \
               "H14: prose about the hand-over was refused as a malformed hand-over line"
arm q_ho_acid "H15: an empty 'handover:' (recorded as '-') and 'handover: .', each with its matching run -> REFUSED, an <AC-id> begins with a letter or digit" \
              "H15: a hand-over naming no AC was merged"
arm q_hc_dash "H16: part 2 declaring 'handovers: 1' with its hand-over written 'handover — AC7' (em dash, unparsed) -> REFUSED on the count mismatch, nothing at --out" \
              "H16: an em-dash hand-over under a declared count of 1 was not refused on the count"
arm q_hc_hidden "H17: 'handovers: 1' with the hand-over as a pipe-table row and as an HTML comment (forms the malformed-line pattern does not match) -> each REFUSED on the count mismatch" \
                "H17: a hand-over the malformed-line pattern cannot see merged with no replay owed"
arm q_hc_zero "H18: 'handovers: 0' over a correct, run 'handover: AC7' -> REFUSED on the count mismatch" \
              "H18: a declared count of 0 over a parsed hand-over was merged"
arm q_hc_missing "H19: a part shard with no 'handovers:' line -> REFUSED, nothing at --out" \
                 "H19: a part shard without its declared hand-over count was merged"
arm q_hc_two "H20: a part shard with two 'handovers:' lines -> REFUSED, nothing at --out" \
             "H20: a part shard declaring its hand-over count twice was merged"
arm q_hc_nonint "H21: 'handovers: x', '-1', 2^64, and '?' / '[1]' from a cwd holding files 0 and 1 -> each REFUSED as not a non-negative integer" \
                "H21: a non-integer hand-over count was merged"
arm q_hc_cross "H22: a 'handovers:' line in cross.md -> REFUSED, nothing at --out" \
               "H22: a cross shard declaring a hand-over count was merged"
arm q_hc_none "H23: every part shard 'handovers: 0', cross.md with none, no hand-over anywhere -> merges PASS, read back Check 1's way" \
              "H23: a world with no hand-overs and correct zero counts was refused"
arm q_ho_widen "H24: under 'handovers: 0', 'handover' followed by an em dash, en dash, '=', '->', a trailing reason, a parenthesised reason, a '1. ' list prefix (bare and bold), and 'handover-run —' -> each REFUSED as a malformed hand-over" \
               "H24: a hand-over spelling the widened malformed-line pattern names was merged"

# THE PROGRAMS ARE NOTHING IF THE LEAD IS NEVER TOLD TO RUN THEM. Every arm above drives the two
# programs directly, so a release that built them and never rewired the step file passes all of
# them and every consumer keeps dispatching one reviewer. Keyed on the EMISSION SITE: the
# paragraph implementation.md opens with `**Gate-1 dispatch:`, read outside fences, must name
# both programs -- a whole-file grep is satisfied by a mention anywhere, including a fence.
# The same for the role clause: the `## As a Shard` section must name the three grammar tokens
# the merge refuses without, or a shard written as the role file says is refused at the join.
step_para() { # <file> -> the Gate-1 dispatch paragraph, fenced lines dropped
  awk '/^```/ { f = !f; next } f { next }
       /^\*\*Gate-1 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { exit } p { print }' "$1"
}
p_step() { # <file>
  local t; t="$(step_para "$1")"
  [ -n "$t" ] && grep -qF 'partition-review-diff.sh' <<<"$t" && grep -qF 'merge-review-shards.sh' <<<"$t"
}
role_sect() { awk '/^## As a Shard/ { p = 1; next } p && /^## / { exit } p { print }' "$1"; }
p_role() { # <file>
  local t; t="$(role_sect "$1")"
  [ -n "$t" ] && grep -qF 'shard-verdict:' <<<"$t" && grep -qF 'reviewed-sha:' <<<"$t" && grep -qF 'parts:' <<<"$t"
}
# Self-probes, both directions, on copies: the names removed from the paragraph, and the names
# present only inside a fence, must each fail; the shipped file must pass.
sed -e '/^\*\*Gate-1 dispatch:/,/^[[:space:]]*$/s/merge-review-shards\.sh/MERGE-GONE/g' "$STEP_MD" > "$WORK/step-strip.md"
{ printf '%s\n' '**Gate-1 dispatch: decoy.** one reviewer.' '' '```' 'partition-review-diff.sh merge-review-shards.sh' '```'; } > "$WORK/step-fence.md"
sed -e '/^## As a Shard/,/^## /s/reviewed-sha:/REVIEWED-GONE/g' "$ROLE_MD" > "$WORK/role-strip.md"
if cmp -s "$STEP_MD" "$WORK/step-strip.md" || cmp -s "$ROLE_MD" "$WORK/role-strip.md"; then
  bad "S0: FIXTURE STALE -- a structural probe's sed matched nothing, so the probe would score the shipped text"
elif p_step "$WORK/step-strip.md" || p_step "$WORK/step-fence.md" || p_role "$WORK/role-strip.md"; then
  bad "S0: FIXTURE BROKEN -- a structural predicate passed a copy with a program or token removed, or present only in a fence"
else
  ok "S0: the structural predicates refuse a paragraph missing the merge, names only inside a fence, and a role clause missing reviewed-sha:"
fi
# THE STEP SAYS SHARDING IS ON BY DEFAULT, in the paragraph the lead acts on. A reverted step
# tells every consumer lead the old contract while the script shards anyway. Read as one joined
# line, so a wrapped sentence still matches. Two refusals inside THIS paragraph only:
#   - the word "opt-in";
#   - opt-in BEHAVIOUR without the word: a clause gating the partition on the variable being set,
#     "only when|if ... is set" or "unless ... is set", up to the clause's end.
# LIMIT, STATED: this arm pins WORDING, not behaviour. A paraphrase of the opt-in contract outside
# both shapes ("run the partition after configuring the variable") passes it. The behaviour is
# held by P2/P2b, which run the shipping script with the variable unset.
p_step_dflt() { # <file>
  local t; t="$(step_para "$1" | tr '\n' ' ' | tr -s ' ')"
  [ -n "$t" ] && ! grep -qi 'opt-in' <<<"$t" && grep -qF 'Review sharding is on by default' <<<"$t" \
    && grep -qF 'setting it to `0` turns review sharding off' <<<"$t" \
    && ! grep -qiE 'only (when|if) [^.;]*is set|unless [^.;]*is set' <<<"$t"
}
# Offender: the paragraph's default-on sentence reverted to the opt-in text.
awk '/^\*\*Gate-1 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { p = 0 }
     p && /^Review sharding is on by default/ { print "Review sharding is opt-in: the program answers `SERIAL:` (exit 3) unless"; next }
     { print }' "$STEP_MD" > "$WORK/step-optin.md"
# Offender: default-on kept, "opt-in" added inside the paragraph. Near-miss: "opt-in" in a
# paragraph of its own after the dispatch paragraph, which the arm must NOT read as a finding.
awk '/^\*\*Gate-1 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { if (!done) print "Older releases made review sharding opt-in."; done = 1; p = 0 } { print }' \
  "$STEP_MD" > "$WORK/step-optin-in.md"
awk '/^\*\*Gate-1 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { if (!done) { print; print "Older releases made review sharding opt-in." }; done = 1; p = 0 } { print }' \
  "$STEP_MD" > "$WORK/step-optin-out.md"
# Offenders without the word (W4): "only when ... is set" and "unless ... is set" added to the
# paragraph. Near-miss: the same "only when ... is set" sentence in the NEXT paragraph.
awk '/^\*\*Gate-1 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { if (!done) print "Run the partition only when `AI_DLC_REVIEW_SHARD_MIN_FILES` is set; otherwise dispatch one serial reviewer."; done = 1; p = 0 } { print }' \
  "$STEP_MD" > "$WORK/step-onlywhen.md"
awk '/^\*\*Gate-1 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { if (!done) print "Dispatch one serial reviewer unless the variable is set."; done = 1; p = 0 } { print }' \
  "$STEP_MD" > "$WORK/step-unless.md"
awk '/^\*\*Gate-1 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { if (!done) { print; print "Older releases ran the partition only when the variable is set." }; done = 1; p = 0 } { print }' \
  "$STEP_MD" > "$WORK/step-onlywhen-out.md"
_s6s=0
for _f in step-optin.md step-optin-in.md step-optin-out.md step-onlywhen.md step-unless.md step-onlywhen-out.md; do
  cmp -s "$STEP_MD" "$WORK/$_f" && _s6s=1
done
if [ "$_s6s" -ne 0 ]; then
  bad "S6-pre: FIXTURE STALE -- a default-on probe's edit matched nothing, so the probe would score the shipped text"
elif p_step_dflt "$WORK/step-optin.md" || p_step_dflt "$WORK/step-optin-in.md" \
     || p_step_dflt "$WORK/step-onlywhen.md" || p_step_dflt "$WORK/step-unless.md"; then
  bad "S6-pre: FIXTURE BROKEN -- the default-on predicate passed a paragraph reverted to opt-in, carrying 'opt-in', or gating the partition on the variable being set"
elif ! p_step_dflt "$WORK/step-optin-out.md" || ! p_step_dflt "$WORK/step-onlywhen-out.md"; then
  bad "S6-pre: FIXTURE BROKEN -- the default-on predicate refused 'opt-in' or 'only when ... is set' OUTSIDE the dispatch paragraph (near-misses)"
else
  ok "S6-pre: the default-on predicate refuses the reverted sentence, 'opt-in', 'only when ... is set' and 'unless ... is set' inside the paragraph, and accepts 'opt-in' and 'only when ... is set' in the next paragraph"
fi
if p_step_dflt "$STEP_MD"; then
  ok "S6: implementation.md's Gate-1 dispatch paragraph says review sharding is on by default and that \`0\` turns it off, and neither says opt-in nor gates the partition on the variable being set"
else
  bad "S6: implementation.md's Gate-1 dispatch paragraph does not state default-on sharding, or says opt-in, or gates the partition on the variable being set"
fi
if p_step "$STEP_MD"; then
  ok "S1: implementation.md's Gate-1 dispatch paragraph names partition-review-diff.sh and merge-review-shards.sh outside a fence"
else
  bad "S1: implementation.md's Gate-1 dispatch paragraph does not name both programs outside a fence -- the lead is never told to shard"
fi
if p_role "$ROLE_MD"; then
  ok "S2: code-reviewer.md's '## As a Shard' clause names shard-verdict:, reviewed-sha: and parts:, the grammar the merge refuses without"
else
  bad "S2: code-reviewer.md's '## As a Shard' clause does not carry the merge's shard grammar -- a shard written to it is refused at the join"
fi

# GATE 2 AT THE EMISSION SITE. The paragraph implementation.md opens with `**Gate-2 dispatch:`,
# fenced lines dropped, must name the partition, the merge and `--gate qa`; qa.md's `## As a Shard`
# must name the three grammar tokens plus `## Acceptance Criteria`, the one section the merge
# requires of the cross shard. And neither file may carry the serial-gate-2 sentences anywhere:
# `Gate 2 is dispatched serially` (the consumer's receipt is a substring match on qa.md) and
# `it has no shard merge`.
step2_para() { awk '/^```/ { f = !f; next } f { next }
       /^\*\*Gate-2 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ { exit } p { print }' "$1"; }
p_step2() { local t; t="$(step2_para "$1")"
  [ -n "$t" ] && grep -qF 'partition-review-diff.sh' <<<"$t" && grep -qF 'merge-review-shards.sh' <<<"$t" \
    && grep -qF -- '--gate qa' <<<"$t"; }
p_qrole() { local t; t="$(role_sect "$1")"
  [ -n "$t" ] && grep -qF 'shard-verdict:' <<<"$t" && grep -qF 'reviewed-sha:' <<<"$t" && grep -qF 'parts:' <<<"$t" \
    && grep -qF '## Acceptance Criteria' <<<"$t"; }
# Read WHITESPACE-NORMALISED: the base text wrapped "Gate 2" / "is dispatched serially" across
# two lines, so a per-line match was already true of the tree it was written to refuse.
p_noserial() { local t; t="$(tr -s '[:space:]' ' ' < "$1")"
  ! grep -qiF 'Gate 2 is dispatched serially' <<<"$t" && ! grep -qiF 'it has no shard merge' <<<"$t"; }
sed -e '/^\*\*Gate-2 dispatch:/,/^[[:space:]]*$/s/--gate qa/--gate QA-GONE/g' "$STEP_MD" > "$WORK/step2-strip.md"
{ printf '%s\n' '**Gate-2 dispatch: decoy.** one QA.' '' '```' 'partition-review-diff.sh merge-review-shards.sh --gate qa' '```'; } > "$WORK/step2-fence.md"
sed -e '/^## As a Shard/,/^## /s/## Acceptance Criteria/## AC-GONE/g' "$QA_MD" > "$WORK/qrole-strip.md"
awk '{ print } /^## Context Loading$/ && !d { print ""; print "Gate 2 is dispatched serially: your brief carries `shard: 1/1 <story-index>`."; d = 1 }' "$QA_MD" > "$WORK/qa-serial.md"
awk '{ print } /^\*\*DAR-fold preflight before gate-2 dispatch\.\*\*/ && !d { print "Gate 2 is dispatched `shard: 1/1 <story-index>`; it has no shard merge."; d = 1 }' "$STEP_MD" > "$WORK/step-nomerge.md"
# The serial sentences WRAPPED, each in the shape base shipped: implementation.md's qa bullet broke
# after "Gate 2" (base lines 127-128), and the no-merge clause wrapped after "it has no". A
# per-line match misses all three; that miss is asserted below so the kill is the normalisation's.
awk '/^- \*\*qa\*\* from `qa\.md`\./ && !d { print "- **qa** from `qa.md`. Validates acceptance criteria, runs tests. Gate 2"; print "  is dispatched serially, `shard: 1/1 <story-index>`."; d = 1; next } { print }' \
  "$STEP_MD" > "$WORK/step-serial-wrap.md"
awk '{ print } /^\*\*DAR-fold preflight before gate-2 dispatch\.\*\*/ && !d { print "Gate 2 is dispatched `shard: 1/1 <story-index>`; it has no"; print "shard merge."; d = 1 }' "$STEP_MD" > "$WORK/step-nomerge-wrap.md"
awk '{ print } /^## Context Loading$/ && !d { print ""; print "Gate 2"; print "is dispatched serially: your brief carries `shard: 1/1 <story-index>`."; d = 1 }' "$QA_MD" > "$WORK/qa-serial-wrap.md"
# The serial sentence in LOWER CASE, which an exact-case match misses; that miss is asserted below.
awk '{ print } /^## Context Loading$/ && !d { print ""; print "gate 2 is dispatched serially: your brief carries `shard: 1/1 <story-index>`."; d = 1 }' "$QA_MD" > "$WORK/qa-serial-lower.md"
_s7w=0
grep -qF 'Gate 2 is dispatched serially' "$WORK/qa-serial-lower.md" && _s7w=1
for _f in step-serial-wrap step-nomerge-wrap qa-serial-wrap; do
  grep -qF 'Gate 2 is dispatched serially' "$WORK/$_f.md" && _s7w=1
  grep -qF 'it has no shard merge' "$WORK/$_f.md" && _s7w=1
done
if cmp -s "$STEP_MD" "$WORK/step2-strip.md" || cmp -s "$QA_MD" "$WORK/qrole-strip.md" \
   || cmp -s "$QA_MD" "$WORK/qa-serial.md" || cmp -s "$STEP_MD" "$WORK/step-nomerge.md" \
   || cmp -s "$STEP_MD" "$WORK/step-serial-wrap.md" || cmp -s "$STEP_MD" "$WORK/step-nomerge-wrap.md" \
   || cmp -s "$QA_MD" "$WORK/qa-serial-wrap.md" || cmp -s "$QA_MD" "$WORK/qa-serial-lower.md"; then
  bad "S7-pre: FIXTURE STALE -- a gate-2 structural probe's edit matched nothing, so the probe would score the shipped text"
elif [ "$_s7w" -ne 0 ]; then
  bad "S7-pre: FIXTURE BROKEN -- a wrapped or lowercase serial-sentence copy matches exact-case on one line, so it cannot tell a per-line or case-sensitive predicate from the shipped one"
elif p_step2 "$WORK/step2-strip.md" || p_step2 "$WORK/step2-fence.md" || p_qrole "$WORK/qrole-strip.md" \
     || p_noserial "$WORK/qa-serial.md" || p_noserial "$WORK/step-nomerge.md" \
     || p_noserial "$WORK/step-serial-wrap.md" || p_noserial "$WORK/step-nomerge-wrap.md" \
     || p_noserial "$WORK/qa-serial-wrap.md" || p_noserial "$WORK/qa-serial-lower.md"; then
  bad "S7-pre: FIXTURE BROKEN -- a gate-2 predicate passed a copy missing --gate qa, naming it only in a fence, a role clause missing '## Acceptance Criteria', or a re-inserted serial sentence, one-line, wrapped or lowercase"
else
  ok "S7-pre: the gate-2 predicates refuse a paragraph missing --gate qa, names only inside a fence, a qa clause missing '## Acceptance Criteria', and either serial sentence re-inserted on one line, WRAPPED as base wrapped it (which a per-line match misses), or in lower case (which an exact-case match misses)"
fi
if p_step2 "$STEP_MD"; then
  ok "S7: implementation.md's Gate-2 dispatch paragraph names partition-review-diff.sh, merge-review-shards.sh and --gate qa outside a fence"
else
  bad "S7: implementation.md's Gate-2 dispatch paragraph does not name the partition, the merge and --gate qa outside a fence -- the lead is never told to shard gate 2"
fi
if p_qrole "$QA_MD"; then
  ok "S8: qa.md's '## As a Shard' clause names shard-verdict:, reviewed-sha:, parts: and '## Acceptance Criteria'"
else
  bad "S8: qa.md's '## As a Shard' clause does not carry the merge's QA shard grammar"
fi
_ser=""
p_noserial "$STEP_MD" || _ser="$_ser implementation.md"
p_noserial "$QA_MD" || _ser="$_ser qa.md"
if [ -z "$_ser" ]; then
  ok "S9: neither 'Gate 2 is dispatched serially' nor 'it has no shard merge' appears anywhere in implementation.md or qa.md"
else
  bad "S9: [${_ser# }] still says gate 2 is serial or has no shard merge"
fi

# WHO MAKES THE CLOSING WRITES, AND WHEN. The `done` transition, `deferred_acs` (taken from QA's
# verdict, so unknowable before gate 2), the upstream close-out and the closing commit are made by
# ONE `code-reviewer` the lead dispatches AFTER GATE 3, for every story, serial or sharded -- a
# dispatched agent, so the gate-remediation guard's agent_id arm allows its story-file edit while
# a verdict is FAIL. No gate-1 reviewer makes them, and the lead does not. The gate-1 REVIEW
# commit, which persists the review file Check 1 reads, is a different commit and is unchanged.
#
# PINS, each read as one joined line with `**` dropped so a wrapped or emphasised sentence still
# matches: the step's task item 4 (dispatch, timing, the four duties, the catch-up for a story
# already past gate 3), its Gate-1 paragraph, its section 7 precondition; the role's Ownership
# pointer, Responsibilities bullet, As a Shard sentence and As the Closing Writer brief.
#
# AND A REFUSAL OVER EACH WHOLE FILE, As the Closing Writer included. The file is split into
# clauses at `. ` and `; `. A clause naming a closing write -- `done` transition, `status: done`,
# `deferred_acs`, the closing commit, or the review commit beside `done`/`deferred_acs` -- must have the closing
# writer as its subject, or negate the WRITE VERB itself (`do/does NOT make|perform`). Any other
# " not " acquits nothing. Clauses that only describe the field or the lifecycle (a value of
# `deferred_acs`, a `done` story, Dev's earlier write) are acquitted by enumerated shapes below.
# FALSE-POSITIVE SET, measured on the shipped files before this arm was pinned: every clause the
# grammar flagged was reworded to name its subject, so the shipped set is 0. The enumerated
# acquittals are the narrowing story; widening one widens what a wrong build can say.
joined() { tr '\n' ' ' | tr -s ' ' | sed -e 's/\*\*//g'; }
close_item() { awk '/^4\. Closing writer/ { p = 1 } p && (/^[[:space:]]*$/ || /^### /) { exit } p { print }' "$1"; }
sect7() { awk '/^### 7\. All Gates Passed/ { p = 1; next } p && /^### / { exit } p { print }' "$1"; }
role_named() { # <file> <section heading text> -> that section's body
  awk -v h="## $2" '$0 == h { p = 1; next } p && /^## / { exit } p { print }' "$1"; }
role_bullet() { # <file> <section> <bullet prefix> -> that bullet, continuation lines included
  role_named "$1" "$2" | awk -v b="$3" 'index($0, b) == 1 { p = 1; print; next } p && /^- / { exit } p { print }'; }
p_own_step() { local t g s
  t="$(close_item "$1" | joined)"; g="$(step_para "$1" | joined)"; s="$(sect7 "$1" | joined)"
  grep -qF 'Once gate 3 passes, the lead dispatches one `code-reviewer` as the closing writer, `shard: 1/1 <story-index>`, for every story, serial or sharded.' <<<"$t" \
    && grep -qF 'the closing writer makes exactly these writes and nothing else' <<<"$t" \
    && grep -qF 'deferred_acs` in both sprint-status views taken from the merged QA file'"'"'s `## Deferred ACs`, or the deferred record in the serial file, the upstream close-out section 5 requires, and the closing commit' <<<"$t" \
    && grep -qF 'The lead does NOT make these writes.' <<<"$t" \
    && grep -qF 'The closing writer is also owed to a story already past gate 3 without its closing writes' <<<"$t" \
    && grep -qF 'the lead dispatches it at the lead'"'"'s next turn' <<<"$t" \
    && grep -qF 'A gate-1 reviewer, serial or shard, does NOT make the `done` transition, `deferred_acs` or the closing commit; the closing writer does, after gate 3.' <<<"$g" \
    && grep -qF 'Persisting the gate-1 review file is unchanged' <<<"$g" \
    && grep -qF 'the closing writer has landed every story'"'"'s closing commit, leaving every story `done` with a `deferred_acs` field in both sprint-status views' <<<"$s" \
    && grep -qF 'The closing writer has not run for a story past gate 3 that is still `review`, or `done` with no `deferred_acs` field in a view: dispatch the closing writer now (section 3, item 4)' <<<"$s"; }
p_own_role() { local o r s c
  o="$(role_named "$1" Ownership | joined)"; s="$(role_sect "$1" | joined)"; c="$(role_named "$1" 'As the Closing Writer' | joined)"
  r="$(role_bullet "$1" Responsibilities '- Dispatched as the closing writer' | joined)"
  grep -qF 'The closing writes belong to the closing writer, and only to it.' <<<"$o" \
    && grep -qF 'A gate-1 reviewer — serial `shard: 1/1`, a part shard or the cross shard — does NOT make any of them. After gate 3 passes, the lead dispatches one `code-reviewer` as the closing writer (see "As the Closing Writer")' <<<"$o" \
    && grep -qF 'in the review commit that Check 1 of `gate-validation.md` reads. That is unchanged, and the review commit carries no status write.' <<<"$o" \
    && grep -qF 'the closing writer updates the story file `Status:` header and `sprint-status.yaml` to `done`, writes the story'"'"'s `deferred_acs` beside `status: done` in both views, and makes the upstream close-out, all in the closing commit. As a gate-1 reviewer you do NOT make these writes.' <<<"$r" \
    && grep -qF 'you do NOT make the `done` transition, `deferred_acs` in both sprint-status views, or the closing commit; the closing writer does, after gate 3.' <<<"$s" \
    && grep -qF 'the lead dispatches you after gate 3 passes, for every story, serial or sharded' <<<"$c" \
    && grep -qF 'the closing writer makes exactly these writes and nothing else' <<<"$c" \
    && grep -qF 'the upstream close-out `implementation.md` section 5 requires' <<<"$c" \
    && grep -qF 'and the closing commit carrying all of them.' <<<"$c"; }
# One clause per line. Fenced lines and headings are dropped; `e.g.`/`i.e.` cannot split.
clauses() { awk '/^```/ { f = !f; next } f || /^#/ { next } { print }' "$1" | joined \
  | sed -e 's/e\.g\./eg/g' -e 's/i\.e\./ie/g' | awk '{ gsub(/\. /, ".\n"); gsub(/; /, ";\n"); print }'; }
# 0 when NO clause gives a closing write to anyone but the closing writer. Prints offenders on fd 3.
p_write_refuse() { # <file>
  clauses "$1" | awk '
    { s = tolower($0) }
    { w = (s ~ /`done` transition/ || s ~ /status: done/ || s ~ /deferred_acs/ || s ~ /closing commit/ \
           || (s ~ /review commit/ && (s ~ /`done`/ || s ~ /deferred_acs/))) }
    !w { next }
    s ~ /the closing writer/ { next }                                   # its subject is the writer
    s ~ /(do|does) not (make|perform)/ { next }                         # the WRITE VERB negated
    # Field and lifecycle descriptions, enumerated (the narrowing story):
    s ~ /^`?deferred_acs`? is not one single-line/ { next }
    s ~ /if the story has no deferred ac/ { next }
    s ~ /never a block list/ { next }
    s ~ /deploy-validate §4b clears/ { next }
    s ~ /`?deferred_acs: \[ac5, ac6\]`?\.?$/ { next }
    s ~ /^dev owns the earlier/ { next }
    { print > "/dev/fd/3"; bad = 1 } END { exit bad }'; }
# The header's THRESHOLD paragraph states the default, derived from the assignment, and the off
# spelling, and no longer calls sharding opt-in.
hdr_para() { awk '/^# THRESHOLD/ { p = 1; print; next } p && /^# [^ ]/ { exit } p { print }' "$1"; }
p_hdr() { local t; t="$(hdr_para "$1" | joined)"
  [ -n "$t" ] && ! grep -qi 'opt-in' <<<"$t" && grep -qF "the built-in default $DFLT" <<<"$t" && grep -qF "$KEY=0" <<<"$t"; }
# OFFENDERS, one per pinned or refused property, each a copy guarded by cmp -s.
#   step-early     item 4's dispatch moved before gate 3            (the tip adversary's W1, first round)
#   step-lead      the Gate-1 paragraph hands the writes to the lead
#   step-elsewhere item 4 de-timed, the pinned sentence added under another heading
#   step-noclose   the upstream close-out dropped from item 4's brief          (D1)
#   step-nocatch   the catch-up for a story already past gate 3 dropped       (D3)
#   step-s7        a section-7 clause where the LEAD makes the writes          (W3, step half)
#   role-nopointer the Ownership pointer bullet deleted                         (W2, first round)
#   role-resp      the Responsibilities bullet reverted to the pre-change text (W2)
#   role-incw      a clause INSIDE As the Closing Writer giving the serial gate-1 reviewer the writes (W1)
#   role-notlead   a clause giving the cross shard the writes, carrying an unrelated " not " (W3)
# NEAR-MISSES, which must pass:
#   role-negated   the role-notlead clause with its WRITE VERB negated
#   step-negated   a section-7 clause where the lead does NOT make the writes
sed -e 's/Once gate 3 passes, the lead/Once gate 2 passes, the lead/' "$STEP_MD" > "$WORK/own-step-early.md"
sed -e '/^\*\*Gate-1 dispatch:/,/^[[:space:]]*$/s/the closing writer does, after gate 3\./the lead performs them after the merge./' "$STEP_MD" > "$WORK/own-step-lead.md"
sed -e 's/Once gate 3 passes, the lead/Once gate 2 passes, the lead/' "$STEP_MD" \
  | awk '/^### 4\. Self-Validate/ { print "Once gate 3 passes, the lead dispatches one `code-reviewer` as the closing writer, `shard: 1/1 <story-index>`, for every story, serial or sharded."; print "" } { print }' \
  > "$WORK/own-step-elsewhere.md"
sed -e 's/^   upstream close-out section 5 requires, and the closing commit carrying$/   and the closing commit carrying/' "$STEP_MD" > "$WORK/own-step-noclose.md"
# The pre-change sentence, line for line: "taken from QA's verdict, the upstream close-out ...".
awk '/^   `deferred_acs` in both sprint-status views taken from the merged QA file.s$/ { print "   `deferred_acs` in both sprint-status views taken from QA'"'"'s verdict, the"; skip = 1; next }
     skip { skip = 0; next } { print }' "$STEP_MD" > "$WORK/own-step-qaverdict.md"
sed -e 's/The closing writer is also owed to a story/A story is also owed/' "$STEP_MD" > "$WORK/own-step-nocatch.md"
awk '/^### 7\. All Gates Passed/ { print; print ""; print "Before routing, the lead writes `status: done` and `deferred_acs` for every story itself and makes the closing commit."; next } { print }' \
  "$STEP_MD" > "$WORK/own-step-s7.md"
awk '/^### 7\. All Gates Passed/ { print; print ""; print "Before routing, the lead does NOT make the `done` transition or the closing commit for any story."; next } { print }' \
  "$STEP_MD" > "$WORK/own-step-negated.md"
awk '/^- \*\*The closing writes belong to the closing writer/ { skip = 1; next }
     skip && /^- / { skip = 0 } !skip { print }' "$ROLE_MD" > "$WORK/own-role-nopointer.md"
awk '/^- Dispatched as the closing writer after gate 3 passes/ { skip = 1
       print "- After approving the final gate for a story, update `sprint-status.yaml`"
       print "  and the story file `Status:` header to `done` in the review commit, with"
       print "  the story'"'"'s `deferred_acs` written beside `status: done` in both views."; next }
     skip && (/^- / || /^$/) { skip = 0 } !skip { print }' "$ROLE_MD" > "$WORK/own-role-resp.md"
awk '{ print } /^the story file and to `carry-over-backlog\.md`\.$/ && !d { print "A gate-1 serial reviewer that approves makes the `done` transition, `deferred_acs` and the closing commit itself at gate 1; dispatch a closing writer only for a sharded review."; d = 1 }' \
  "$ROLE_MD" > "$WORK/own-role-incw.md"
awk '/^## Constraints$/ { print "As the cross shard you make the closing commit and the `done` transition, not the lead."; print "" } { print }' \
  "$ROLE_MD" > "$WORK/own-role-notlead.md"
awk '/^## Constraints$/ { print "As the cross shard you do NOT make the closing commit or the `done` transition."; print "" } { print }' \
  "$ROLE_MD" > "$WORK/own-role-negated.md"
sed -e '/^# THRESHOLD/s/ON BY DEFAULT/OPT-IN/' "$PART" > "$WORK/hdr-optin.sh"
sed -e "/^# THRESHOLD/,/^# THE PART SET/s/the built-in default $DFLT/the built-in default $((DFLT + 1))/" "$PART" > "$WORK/hdr-num.sh"
_stale=0
grep -qF 'Once gate 2 passes, the lead' "$WORK/own-step-elsewhere.md" || { _stale=1; echo "  (item 4 not de-timed in own-step-elsewhere.md)"; }
for _p in "$STEP_MD:own-step-early.md" "$STEP_MD:own-step-lead.md" "$STEP_MD:own-step-elsewhere.md" \
          "$STEP_MD:own-step-noclose.md" "$STEP_MD:own-step-qaverdict.md" "$STEP_MD:own-step-nocatch.md" "$STEP_MD:own-step-s7.md" "$STEP_MD:own-step-negated.md" \
          "$ROLE_MD:own-role-nopointer.md" "$ROLE_MD:own-role-resp.md" "$ROLE_MD:own-role-incw.md" \
          "$ROLE_MD:own-role-notlead.md" "$ROLE_MD:own-role-negated.md" \
          "$PART:hdr-optin.sh" "$PART:hdr-num.sh"; do
  cmp -s "${_p%%:*}" "$WORK/${_p#*:}" && { _stale=1; echo "  (unchanged probe: ${_p#*:})"; }
done
# Each offender must be refused by the arm that OWNS it; the pins and the refusal are scored apart
# so a wrong build that slips one is still named.
_own_fail=""
for _o in own-step-early own-step-lead own-step-elsewhere own-step-noclose own-step-qaverdict own-step-nocatch; do
  p_own_step "$WORK/$_o.md" && _own_fail="$_own_fail $_o"
done
p_write_refuse "$WORK/own-step-s7.md" 3>/dev/null && _own_fail="$_own_fail own-step-s7"
p_own_role "$WORK/own-role-nopointer.md" && _own_fail="$_own_fail own-role-nopointer"
p_own_role "$WORK/own-role-resp.md" && _own_fail="$_own_fail own-role-resp(pin)"
p_write_refuse "$WORK/own-role-resp.md" 3>/dev/null && _own_fail="$_own_fail own-role-resp(refuse)"
p_write_refuse "$WORK/own-role-incw.md" 3>/dev/null && _own_fail="$_own_fail own-role-incw"
p_write_refuse "$WORK/own-role-notlead.md" 3>/dev/null && _own_fail="$_own_fail own-role-notlead"
p_hdr "$WORK/hdr-optin.sh" && _own_fail="$_own_fail hdr-optin"
p_hdr "$WORK/hdr-num.sh" && _own_fail="$_own_fail hdr-num"
_nm_fail=""
{ p_write_refuse "$WORK/own-role-negated.md" 3>/dev/null && p_own_role "$WORK/own-role-negated.md"; } || _nm_fail="$_nm_fail own-role-negated"
{ p_write_refuse "$WORK/own-step-negated.md" 3>/dev/null && p_own_step "$WORK/own-step-negated.md"; } || _nm_fail="$_nm_fail own-step-negated"
if [ "$_stale" -ne 0 ]; then
  bad "S3-pre: FIXTURE STALE -- an ownership or header probe's edit matched nothing, so the probe would score the shipped text"
elif [ -n "$_own_fail" ]; then
  bad "S3-pre: FIXTURE BROKEN -- an ownership or header predicate passed offender(s) [${_own_fail# }]"
elif [ -n "$_nm_fail" ]; then
  bad "S3-pre: FIXTURE BROKEN -- a predicate refused near-miss(es) [${_nm_fail# }], a clause whose write verb is negated"
else
  ok "S3-pre: 13 offenders refused by the arm that owns each (dispatch before gate 3, writes to the lead, dispatch outside item 4, no close-out, deferred_acs taken from 'QA's verdict' rather than the merged file's '## Deferred ACs', no catch-up, a lead-writes clause in section 7, no Ownership pointer, the Responsibilities bullet reverted, a contradiction inside As the Closing Writer, an unrelated 'not', OPT-IN, another number); 2 near-misses with the write verb negated pass"
fi
if p_own_step "$STEP_MD"; then
  ok "S3: implementation.md's item 4 dispatches the closing writer after gate 3 for every story with its four duties and the catch-up, the Gate-1 paragraph gives no gate-1 reviewer the writes and keeps review-file persistence, and section 7 routes only after every closing commit"
else
  bad "S3: implementation.md does not pin the post-gate-3 closing writer at item 4, the Gate-1 paragraph and section 7"
fi
if p_own_role "$ROLE_MD"; then
  ok "S4: code-reviewer.md's Ownership, Responsibilities, As a Shard and As the Closing Writer give the closing writes to the closing writer alone, after gate 3, upstream close-out included, and keep the review commit"
else
  bad "S4: code-reviewer.md does not give the closing writes to the post-gate-3 closing writer at all four sites"
fi
_sref=""
p_write_refuse "$ROLE_MD" 3>/dev/null || _sref="$_sref code-reviewer.md"
p_write_refuse "$STEP_MD" 3>/dev/null || _sref="$_sref implementation.md"
if [ -z "$_sref" ]; then
  ok "S4b: no clause in code-reviewer.md or implementation.md, As the Closing Writer included, gives a closing write to anyone but the closing writer unless its write verb is negated"
else
  bad "S4b: a clause in [${_sref# }] gives a closing write to a subject other than the closing writer"
fi
if p_hdr "$PART"; then
  ok "S5: partition-review-diff.sh's THRESHOLD paragraph states the built-in default $DFLT and $KEY=0, and does not say opt-in"
else
  bad "S5: partition-review-diff.sh's THRESHOLD paragraph still says opt-in, or does not state the default $DFLT and the off spelling"
fi

# A PART SHARD'S WORKTREE HAS NO DEPENDENCIES, AND A PART SHARD DELIVERS A PATH, NOT ROWS. A fresh
# `git worktree add --detach` carries none of the project's gitignored dependencies, so a RED
# replayed there without setup fails for a reason the mutation does not own -- measured on the
# reference consumer: its canonical interpreter is absent (rc 127) until its documented setup
# runs (rc 0). PINS, each read joined with `**` dropped, at the two emission sites: qa.md's
# `## As a Shard` (setup first, GREEN baseline before any mutation, the hand-over to the cross
# shard as a `#### ` finding, and the cross shard owning the handed-over replays), the Gate-2
# dispatch paragraph (the same three duties), and qa.md's "Deliver before idle" bullet (a part
# shard delivers its shard file path and shard-verdict, never per-AC rows).
p_qsetup_role() { local t; t="$(role_sect "$1" | joined)"
  grep -qF 'in it you first run the project'"'"'s canonical dependency setup, the setup the dev'"'"'s QA Handoff Evidence records or else the story'"'"'s documented setup, and confirm the canonical run of the anchor'"'"'s test is GREEN there before any mutation.' <<<"$t" \
    && grep -qF 'An AC whose replay cannot reach a GREEN baseline in your worktree is handed to the cross shard rather than scored: list it under `## Findings` as a `#### ` finding citing `parts: <your ordinal>` that names the AC and the reason.' <<<"$t" \
    && grep -qF 'the RED replays for any AC whose anchor lies in no part'"'"'s files or that a part shard handed over' <<<"$t"; }
p_qsetup_step() { local t; t="$(step2_para "$1" | joined)"
  grep -qF 'a part QA first runs the project'"'"'s canonical dependency setup (the setup the dev'"'"'s QA Handoff Evidence records, or the story'"'"'s documented setup) and confirms the canonical run of the anchor'"'"'s test is GREEN there before any mutation.' <<<"$t" \
    && grep -qF 'An AC whose replay cannot reach a GREEN baseline in the part'"'"'s worktree is handed to the cross QA, listed under the part shard'"'"'s findings with its reason, rather than scored.' <<<"$t" \
    && grep -qF 'the RED replays a part QA handed over' <<<"$t"; }
p_qdeliver() { local t; t="$(role_bullet "$1" Communication '- **Deliver before idle' | joined)"
  grep -qF 'A part shard delivers its shard file'"'"'s absolute path and its `shard-verdict:` value instead, never per-AC rows, which only the cross shard writes.' <<<"$t"; }
# OFFENDERS: each obligation dropped at its site; and each moved OUT of its section (into the
# paragraph after it), which a whole-file grep would still accept.
sed -e 's/^it you first run the project.s canonical dependency setup, the setup the dev.s$/it you run the replays directly, the setup the dev'"'"'s/' "$QA_MD" > "$WORK/qs-role-nosetup.md"
sed -e 's/^the canonical run of the anchor.s test is GREEN there before any mutation\. An$/the mutation directly. An/' "$QA_MD" > "$WORK/qs-role-nogreen.md"
sed -e 's/^AC whose replay cannot reach a GREEN baseline in your worktree is handed to the$/AC whose replay cannot reach a GREEN baseline in your worktree is scored REJECT by the/' "$QA_MD" > "$WORK/qs-role-nohand.md"
sed -e 's/^part.s files or that a part shard handed over, and the interactions between$/part'"'"'s files, and the interactions between/' "$QA_MD" > "$WORK/qs-role-nocross.md"
sed -e 's/^first runs the project.s canonical dependency setup (the setup the dev.s QA$/first runs the replays (the setup the dev'"'"'s QA/' "$STEP_MD" > "$WORK/qs-step-nosetup.md"
sed -e 's/^whose replay cannot reach a GREEN baseline in the part.s worktree is handed to$/whose replay cannot reach a GREEN baseline in the part'"'"'s worktree is REJECTed, not handed to/' "$STEP_MD" > "$WORK/qs-step-nohand.md"
awk '/^\*\*Gate-2 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ && !d { print; print "In that worktree a part QA first runs the project'"'"'s canonical dependency setup (the setup the dev'"'"'s QA Handoff Evidence records, or the story'"'"'s documented setup) and confirms the canonical run of the anchor'"'"'s test is GREEN there before any mutation."; d = 1; p = 0 }
     /^first runs the project.s canonical dependency setup \(the setup the dev.s QA$/ { print "first runs the replays (the setup the dev'"'"'s QA"; next } { print }' "$STEP_MD" > "$WORK/qs-step-moved.md"
# The moved copy must not still carry the sentence in place: assert the in-paragraph edit applied.
grep -q '^first runs the replays (the setup the dev.s QA$' "$WORK/qs-step-moved.md" || cp "$STEP_MD" "$WORK/qs-step-moved.md"
sed -e 's/^  path and its `shard-verdict:` value instead, never per-AC rows, which only$/  path, its `shard-verdict:` value and its per-AC rows, which only/' "$QA_MD" > "$WORK/qs-deliver-rows.md"
_s10s=0
for _p in "$QA_MD:qs-role-nosetup.md" "$QA_MD:qs-role-nogreen.md" "$QA_MD:qs-role-nohand.md" "$QA_MD:qs-role-nocross.md" \
          "$STEP_MD:qs-step-nosetup.md" "$STEP_MD:qs-step-nohand.md" "$STEP_MD:qs-step-moved.md" "$QA_MD:qs-deliver-rows.md"; do
  cmp -s "${_p%%:*}" "$WORK/${_p#*:}" && { _s10s=1; echo "  (unchanged probe: ${_p#*:})"; }
done
_s10f=""
for _o in qs-role-nosetup qs-role-nogreen qs-role-nohand qs-role-nocross; do p_qsetup_role "$WORK/$_o.md" && _s10f="$_s10f $_o"; done
for _o in qs-step-nosetup qs-step-nohand qs-step-moved; do p_qsetup_step "$WORK/$_o.md" && _s10f="$_s10f $_o"; done
p_qdeliver "$WORK/qs-deliver-rows.md" && _s10f="$_s10f qs-deliver-rows"
if [ "$_s10s" -ne 0 ]; then
  bad "S10-pre: FIXTURE STALE -- a part-shard setup or delivery probe's edit matched nothing, so the probe would score the shipped text"
elif [ -n "$_s10f" ]; then
  bad "S10-pre: FIXTURE BROKEN -- a part-shard setup or delivery predicate passed offender(s) [${_s10f# }]"
else
  ok "S10-pre: 8 offenders refused (setup, GREEN baseline, hand-over or cross ownership dropped from qa.md; setup or hand-over dropped from the Gate-2 paragraph; setup moved out of that paragraph; a part shard delivering per-AC rows)"
fi
_s10=""
p_qsetup_role "$QA_MD" || _s10="$_s10 qa.md-As-a-Shard"
p_qsetup_step "$STEP_MD" || _s10="$_s10 implementation.md-Gate-2-dispatch"
p_qdeliver "$QA_MD" || _s10="$_s10 qa.md-Deliver-before-idle"
if [ -z "$_s10" ]; then
  ok "S10: qa.md's As a Shard and implementation.md's Gate-2 paragraph make a part shard run the canonical dependency setup and reach a GREEN baseline before any mutation, hand an unreachable AC to the cross shard, and the cross shard owns it; a part shard delivers its shard path and shard-verdict, not per-AC rows"
else
  bad "S10: [${_s10# }] does not carry the part shard's dependency setup, GREEN baseline, hand-over, or path-and-verdict delivery"
fi

# A HAND-OVER IS RUN BY NOBODY UNLESS THE CROSS QA IS DISPATCHED AFTER THE PARTS AND TOLD TO READ
# THEM. Parts and cross in one wave left the cross shard no file to read, and nothing told it to
# read one. PINS, joined with `**` dropped, at the emission sites: the Gate-2 paragraph (parts
# first, cross only after every part shard file exists, its brief naming them, and the cross QA
# reading them for `handover:` lines before scoring); qa.md's As a Shard (the hand-over's
# `handover:` line under `### Important`, never a Deferred container, and the cross shard reading
# every part shard and writing `handover-run:`); the Deliver-before-idle bullet (the cross shard
# delivers the count of hand-overs it ran).
p_ho_step() { local t; t="$(step2_para "$1" | joined)"
  grep -qF 'The part QAs are dispatched first; the one `shard: cross/<N> cross` QA writing `cross.md` there is dispatched only after every part shard file exists, and its brief names the absolute path of every part shard file.' <<<"$t" \
    && grep -qF 'Before scoring, the cross QA reads every part shard file for `handover:` lines, runs each handed-over replay and records it as a `handover-run:` line' <<<"$t"; }
p_ho_role() { local t; t="$(role_sect "$1" | joined)"
  grep -qF 'The hand-over finding goes under `### Important`, never under a `### Deferred` container, and carries exactly one column-0 `handover: <AC-id>` line beside its `parts:` line.' <<<"$t" \
    && grep -qF 'Before scoring anything, the cross shard reads every part shard `<ordinal>.md` its brief names for `handover:` lines, runs each handed-over replay in the frozen worktree after the project'"'"'s canonical dependency setup, and records each one as a column-0 `handover-run: <ordinal> <AC-id> <RED|GREEN-SURVIVED|NO-BASELINE>` line' <<<"$t"; }
p_ho_deliver() { local t; t="$(role_bullet "$1" Communication '- **Deliver before idle' | joined)"
  grep -qF 'The cross shard delivers its shard file'"'"'s absolute path, its `shard-verdict:` value and the count of hand-overs it ran; its per-AC rows stay in the file.' <<<"$t"; }
# OFFENDERS: the one-wave dispatch restored; the cross-read dropped from each site; the hand-over
# placed under Deferred; the ordering sentence moved out of its paragraph; the cross delivery dropped.
sed -e 's/^("Split dispatch": files axis)\. The part QAs are dispatched first; the one$/("Split dispatch": files axis), together with the one/' "$STEP_MD" > "$WORK/ho-step-onewave.md"
sed -e 's/^the cross QA reads every part shard file for `handover:` lines, runs each$/the cross QA may read a part shard file for `handover:` lines, runs each/' "$STEP_MD" > "$WORK/ho-step-noread.md"
awk '/^\*\*Gate-2 dispatch:/ { p = 1 } p && /^[[:space:]]*$/ && !d { print; print "The part QAs are dispatched first; the one `shard: cross/<N> cross` QA writing `cross.md` there is dispatched only after every part shard file exists, and its brief names the absolute path of every part shard file."; d = 1; p = 0 }
     /^\("Split dispatch": files axis\)\. The part QAs are dispatched first; the one$/ { print "(\"Split dispatch\": files axis), together with the one"; next } { print }' "$STEP_MD" > "$WORK/ho-step-moved.md"
grep -q '^("Split dispatch": files axis), together with the one$' "$WORK/ho-step-moved.md" || cp "$STEP_MD" "$WORK/ho-step-moved.md"
sed -e 's/^`### Important`, never under a `### Deferred` container, and carries exactly$/`### Deferred ACs`, and carries exactly/' "$QA_MD" > "$WORK/ho-role-deferred.md"
sed -e 's/^parts\. Before scoring anything, the cross shard reads every part shard$/parts. After scoring, the cross shard may read a part shard/' "$QA_MD" > "$WORK/ho-role-noread.md"
sed -e 's/^  path, its `shard-verdict:` value and the count of hand-overs it ran; its$/  path and its `shard-verdict:` value; its/' "$QA_MD" > "$WORK/ho-deliver-nocount.md"
_s11s=0
for _p in "$STEP_MD:ho-step-onewave.md" "$STEP_MD:ho-step-noread.md" "$STEP_MD:ho-step-moved.md" \
          "$QA_MD:ho-role-deferred.md" "$QA_MD:ho-role-noread.md" "$QA_MD:ho-deliver-nocount.md"; do
  cmp -s "${_p%%:*}" "$WORK/${_p#*:}" && { _s11s=1; echo "  (unchanged probe: ${_p#*:})"; }
done
_s11f=""
for _o in ho-step-onewave ho-step-noread ho-step-moved; do p_ho_step "$WORK/$_o.md" && _s11f="$_s11f $_o"; done
for _o in ho-role-deferred ho-role-noread; do p_ho_role "$WORK/$_o.md" && _s11f="$_s11f $_o"; done
p_ho_deliver "$WORK/ho-deliver-nocount.md" && _s11f="$_s11f ho-deliver-nocount"
if [ "$_s11s" -ne 0 ]; then
  bad "S11-pre: FIXTURE STALE -- a hand-over ordering or cross-read probe's edit matched nothing, so the probe would score the shipped text"
elif [ -n "$_s11f" ]; then
  bad "S11-pre: FIXTURE BROKEN -- a hand-over ordering or cross-read predicate passed offender(s) [${_s11f# }]"
else
  ok "S11-pre: 6 offenders refused (parts and cross in one wave; the cross read dropped from the Gate-2 paragraph; the ordering moved out of it; the hand-over under '### Deferred ACs'; the cross read dropped from qa.md; the cross delivery without its hand-over count)"
fi
_s11=""
p_ho_step "$STEP_MD" || _s11="$_s11 implementation.md-Gate-2-dispatch"
p_ho_role "$QA_MD" || _s11="$_s11 qa.md-As-a-Shard"
p_ho_deliver "$QA_MD" || _s11="$_s11 qa.md-Deliver-before-idle"
if [ -z "$_s11" ]; then
  ok "S11: the Gate-2 paragraph dispatches the cross QA only after every part shard file exists, names them in its brief, and has it read them for hand-overs before scoring; qa.md places a hand-over under '### Important' with its 'handover:' line and has the cross shard read every part shard and write 'handover-run:'; the cross shard delivers its hand-over count"
else
  bad "S11: [${_s11# }] does not carry the parts-first dispatch, the cross shard's hand-over read, or its hand-over count"
fi

# THE DECLARED COUNT AT THE EMISSION SITES. A part shard written to qa.md or briefed from the Gate-2
# paragraph without `handovers: <n>` is refused at the join, so both sites must tell it to write
# one: qa.md's `## As a Shard` and the Gate-2 dispatch paragraph, read joined with `**` dropped.
p_hc_role() { local t; t="$(role_sect "$1" | joined)"
  grep -qF 'A part shard also carries, beside those two lines, exactly one column-0 `handovers: <n>` line counting its hand-overs however written, `0` when it handed nothing over; the cross shard carries none.' <<<"$t"; }
p_hc_step() { local t; t="$(step2_para "$1" | joined)"
  grep -qF 'every part shard carries one header line `handovers: <n>` counting its hand-overs, `0` when it handed nothing over (the grammar is `merge-review-shards.sh`'"'"'s header).' <<<"$t"; }
sed -e 's/^exactly one column-0 `handovers: <n>` line counting its hand-overs however written, `0`$/exactly one column-0 line counting its hand-overs however written, `0`/' "$QA_MD" > "$WORK/hc-role-strip.md"
sed -e 's/^shard carries one header line `handovers: <n>` counting its hand-overs, `0` when$/shard counts its hand-overs, `0` when/' "$STEP_MD" > "$WORK/hc-step-strip.md"
if cmp -s "$QA_MD" "$WORK/hc-role-strip.md" || cmp -s "$STEP_MD" "$WORK/hc-step-strip.md"; then
  bad "S12-pre: FIXTURE STALE -- a declared-count probe's edit matched nothing, so the probe would score the shipped text"
elif p_hc_role "$WORK/hc-role-strip.md" || p_hc_step "$WORK/hc-step-strip.md"; then
  bad "S12-pre: FIXTURE BROKEN -- a declared-count predicate passed a copy with 'handovers: <n>' removed"
else
  ok "S12-pre: the declared-count predicates refuse qa.md's As a Shard and the Gate-2 paragraph with 'handovers: <n>' removed"
fi
_s12=""
p_hc_role "$QA_MD" || _s12="$_s12 qa.md-As-a-Shard"
p_hc_step "$STEP_MD" || _s12="$_s12 implementation.md-Gate-2-dispatch"
if [ -z "$_s12" ]; then
  ok "S12: qa.md's As a Shard and implementation.md's Gate-2 paragraph tell every part shard to write 'handovers: <n>', 0 when it handed nothing over"
else
  bad "S12: [${_s12# }] does not tell a part shard to write its declared 'handovers: <n>' count"
fi

# ------------------------------------------------------------------------------ the mutants
mutdir() { # <name> -> a dir holding both subjects and the scan-root sibling
  local d s
  d="$(mktemp -d "$WORK/mut-$1.XXXXXX")" || return 1
  for s in partition-review-diff.sh merge-review-shards.sh artifact-path-config.sh; do cp "$SRCDIR/$s" "$d/"; done
  printf '%s' "$d"
}
apply() { # <file> <old> <new>: exactly one occurrence, else exit 3
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
score() { # <label> <script-dir> <expected dead set | NONE>
  local label="$1" sd="$2" want="$3" dead="" p
  for p in $P_ALL; do "p_$p" "$sd" || dead="$dead $p"; done
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
mutant() { # <label> <file> <expected> <old> <new> [<old2> <new2>]
  local label="$1" f="$2" want="$3" d; d="$(mutdir "${label%% *}")"
  if ! apply "$d/$f" "$4" "$5" || { [ $# -ge 7 ] && ! apply "$d/$f" "$6" "$7"; }; then
    bad "$label: FIXTURE STALE -- the mutation anchor is not in $f exactly once; re-anchor it, never relax the assertion"; return
  fi
  if cmp -s "$SRCDIR/$f" "$d/$f"; then bad "$label: FIXTURE STALE -- the mutated copy is byte-identical"; return; fi
  bash -n "$d/$f" 2>/dev/null || { bad "$label: FIXTURE BROKEN -- the mutated $f does not parse"; return; }
  score "$label" "$d" "$want"
}

C0="$(mutdir m0)"
if [ -f "$C0/partition-review-diff.sh" ] && [ -f "$C0/merge-review-shards.sh" ] && [ -f "$C0/artifact-path-config.sh" ]; then
  ok "MX-pre: the sandbox carries the merge, the partition it re-runs, and the scan-root resolver the partition calls"
  score "MX0 control (unmutated copy)" "$C0" NONE
else
  bad "MX-pre: FIXTURE BROKEN -- the sandbox lacks a subject or its sibling"
fi

WORST_LINE='if [ "$r" -gt "$WORST_R" ]; then WORST_R="$r"; WORST="$v"; fi'
HDR_LINE="  printf '# %s: %s (merged from %s shards)\\n\\n' \"\$TITLE\" \"\$IDX\" \"\$((K + 1))\""
# The worst-of line is SHARED by both gates, so each wrong rule dies in gate 1 (V1) and gate 2 (Q1).
# MX1 kills H4 too, and both findings are true: its majority recompute sits after the hand-over
# join, so it discards the forced NEEDS_REWORK as well as the worst-of.
mutant "MX1 verdict by majority count" merge-review-shards.sh "worst q_worst q_ho_force" \
  "$WORST_LINE" 'TALLY="${TALLY:-} $v"' \
  "$HDR_LINE" "  WORST=\"\$(printf '%s\\n' \$TALLY | sort | uniq -c | sort -k1,1nr -k2,2 | awk 'NR == 1 { print \$2 }')\"
$HDR_LINE"
mutant "MX2 verdict = the cross shard's" merge-review-shards.sh "worst q_worst" \
  "$WORST_LINE" 'if [ "$key" = cross ]; then WORST_R="$r"; WORST="$v"; fi'
mutant "MX3 verdict = the last part read" merge-review-shards.sh "worst q_worst" \
  "$WORST_LINE" 'if [ "$key" != cross ]; then WORST_R="$r"; WORST="$v"; fi'
# Short union: the owed-set check removed AND a missing shard skipped, so the mutant MERGES.
mutant "MX4 accepts a short union" merge-review-shards.sh "miss_ord miss_cross" \
  'for idx in $ORDINALS cross; do' 'for idx in ; do' \
  "  sf=\"\$(awk -F'\\t' -v k=\"\$key\" '\$1 == k { print \$2; exit }' \"\$T/shards\")\"" \
  "  sf=\"\$(awk -F'\\t' -v k=\"\$key\" '\$1 == k { print \$2; exit }' \"\$T/shards\")\"
  [ -n \"\$sf\" ] || continue"
# A second Check-1-matching line, added at the WRITE, downstream of the merge's own count guard.
# R10 dies too, and both findings are true: the file this mutant writes is not the merge it
# recomputes, so R10's identical re-merge reads a differing review and is refused, not UNCHANGED.
mutant "MX5 emits a second Check-1 line" merge-review-shards.sh "c1 rerun q_table" \
  'cp "$T/out" "$OUT.merge-tmp.$$" && mv' \
  '{ cat "$T/out"; printf '"'"'**Verdict:** %s\n'"'"' "$WORST"; } > "$OUT.merge-tmp.$$" && mv'
mutant "MX6 skips the manifest re-derivation" merge-review-shards.sh "moved" \
  'bash "$PART" --map "$M_WT" "$M_BASE" "$M_SHA" --min-files "$M_MIN" --max-parts "$M_MAX" > "$T/map" 2> "$T/map.err"; prc=$?' \
  'cp "$T/mfmap" "$T/map"; prc=$?'
mutant "MX7 first-path-component group key (no adaptive split)" partition-review-diff.sh "part" \
  'if (GW[g] * K <= tot) continue' 'continue'
# The merge's Check-1 count guard alone owns R9; C1 is the mirror one stage later (MX5).
mutant "MX8 Check-1 count guard disabled" merge-review-shards.sh "a3" \
  '[ "$n1" = "1" ] || refuse' '[ "$n1" = "1" ] || true'
mutant "MX9 an existing differing review is overwritten" merge-review-shards.sh "rerun" \
  '  refuse "$OUT already exists and differs from this merge; a review file is never overwritten"' '  :'
mutant "MX10 the ancestor check removed" partition-review-diff.sh "anc" \
  'git -C "$WT_ABS" merge-base --is-ancestor "$BASE_FULL" "$SHA_FULL" \' 'true \'
mutant "MX11 the cross shard's reviewed-sha is not checked" merge-review-shards.sh "cross_sha" \
  '  [ "${2:-}" = "$M_SHA" ] || refuse' '  [ "$key" = cross ] || [ "${2:-}" = "$M_SHA" ] || refuse'
mutant "MX12 an unranked verdict is accepted" merge-review-shards.sh "bad_verdict q_rank" \
  '[ "$r" -gt 0 ] || refuse' '[ "$r" -ge 0 ] || refuse'
mutant "MX13 a finding with no parts: is skipped" merge-review-shards.sh "noparts" \
  '    [ "$nlines" = "1" ] || refuse' '    [ "$nlines" = "0" ] && continue; [ "$nlines" = "1" ] || refuse'
mutant "MX14 the existing-manifest check removed" partition-review-diff.sh "manifest" \
  '  if [ -e "$SDIR/.manifest" ]; then' '  if false; then'
mutant "MX15 two reviewed-sha lines accepted" merge-review-shards.sh "two_sha" \
  "[ \"\${1:-0}\" = \"1\" ] || refuse \"\$sf carries \${1:-0} 'reviewed-sha:'" \
  "[ \"\${1:-0}\" -ge 1 ] || refuse \"\$sf carries \${1:-0} 'reviewed-sha:'"
mutant "MX16 default part ceiling 2" partition-review-diff.sh "default_k" \
  '[ -n "$MAXP" ] || MAXP=4' '[ -n "$MAXP" ] || MAXP=2'
mutant "MX17 a stray parts: line is not refused" merge-review-shards.sh "stray" \
  '  [ "${sl:-0}" = "0" ] \' '  true \'
mutant "MX18 a shard without ## Findings is not refused" merge-review-shards.sh "nofind" \
  "  [ \"\$(awk '\$1 == \"F\" { print \$2 }' \"\$P\")\" = \"1\" ] \\" '  true \'
mutant "MX19 the 9-digit cap removed" partition-review-diff.sh "knob" \
  'case "$MINF" in ??????????*) refuse' 'case "$MINF" in NEVER) refuse' \
  'case "$MAXP" in ??????????*) refuse' 'case "$MAXP" in NEVER) refuse'
mutant "MX20 the 64-part ceiling removed" partition-review-diff.sh "knob" \
  '[ "$MAXP" -le 64 ] || refuse' '[ "$MAXP" -le 64 ] || true'
# THE DEFAULT-ON THRESHOLD. Each mutant is a wrong build the contract names; the boundary one
# dies only because P2b's seed sits at exactly the default.
DFLT_LINE="REVIEW_SHARD_DEFAULT_MIN_FILES=$DFLT"
mutant "MX21 default 0 (always serial)" partition-review-diff.sh "dflt_lo dflt_hi dmerge" \
  "$DFLT_LINE" 'REVIEW_SHARD_DEFAULT_MIN_FILES=0'
mutant "MX22 default 1 (always shards)" partition-review-diff.sh "dflt_lo" \
  "$DFLT_LINE" 'REVIEW_SHARD_DEFAULT_MIN_FILES=1'
mutant "MX23 the boundary is exclusive (-le)" partition-review-diff.sh "dflt_hi" \
  'if [ "$NF_REV" -lt "$MINF" ]; then' 'if [ "$NF_REV" -le "$MINF" ]; then'
mutant "MX24 a zero threshold refuses" partition-review-diff.sh "off" \
  'echo "SERIAL: review sharding is disabled -- $MINF_SRC is 0"; exit 3' 'refuse "$MINF_SRC is 0"'
mutant "MX25 a zero threshold means the default" partition-review-diff.sh "off" \
  'MINF=$((10#$MINF))' 'MINF=$((10#$MINF)); [ "$MINF" -ne 0 ] || MINF="$REVIEW_SHARD_DEFAULT_MIN_FILES"'
mutant "MX26 a set-but-empty key reads as unset" partition-review-diff.sh "refuse_val" \
  'elif [ -n "${AI_DLC_REVIEW_SHARD_MIN_FILES+set}" ]; then' 'elif [ -n "${AI_DLC_REVIEW_SHARD_MIN_FILES:-}" ]; then'
# Two arms, both true: prec sees the partition answer move, dmerge's flagged world sees the
# manifest record the key's number instead of the flag's, which the merge would hand back.
mutant "MX27 the key overrides --min-files" partition-review-diff.sh "prec dmerge" \
  'if [ "$MINF_SET" -eq 1 ]; then' 'if [ "$MINF_SET" -eq 1 ] && [ -z "${AI_DLC_REVIEW_SHARD_MIN_FILES+set}" ]; then'
mutant "MX28 the manifest records the default's SOURCE, not its number" partition-review-diff.sh "dmerge" \
  '  MINF="$REVIEW_SHARD_DEFAULT_MIN_FILES"' '  MINF="$REVIEW_SHARD_DEFAULT_MIN_FILES"; MREC=default' \
  "printf 'min-files\\t%s\\n' \"\$MINF\"" "printf 'min-files\\t%s\\n' \"\${MREC:-\$MINF}\""
# GATE 2 (--gate qa). Each is a wrong build the contract names.
mutant "MQ1 the qa rank inverted (PASS worst)" merge-review-shards.sh "q_worst" \
  '    qa:PASS) echo 1 ;;' '    qa:PASS) echo 2 ;;' \
  '    qa:NEEDS_REWORK) echo 2 ;;' '    qa:NEEDS_REWORK) echo 1 ;;'
mutant "MQ2 the qa section refusals removed" merge-review-shards.sh "q_part_ac q_part_def q_cross_noac q_cross_twoac q_cross_twodef q_secvar" \
  '  if [ "$GATE" = "qa" ]; then' '  if false; then'
mutant "MQ3 QA's verdict set lifted from code-reviewer.md" merge-review-shards.sh "q_vset" \
  'ROLE_NAME="qa.md"; DSUF="qa-validation"' 'ROLE_NAME="code-reviewer.md"; DSUF="qa-validation"' \
  'WANT_VSET="NEEDS_REWORK PASS "' 'WANT_VSET="APPROVED BLOCKED NEEDS_REWORK "'
mutant "MQ4 the pass-marker check removed" merge-review-shards.sh "q_pm" \
  '[ "$OPASS" = "$DPASS" ] \' 'true \'
mutant "MQ5 gate-1 output changed (title)" merge-review-shards.sh "q_title" \
  'DSUF="code-review"; TITLE="Code Review"' 'DSUF="code-review"; TITLE="Code-Review"'
mutant "MQ6 an unknown gate is merged as qa" merge-review-shards.sh "q_gate" \
  '  qa)          ROLE_NAME=' '  *)          ROLE_NAME='
mutant "MQ7 the shard dir suffix is not the gate's" merge-review-shards.sh "q_suffix" \
  '  *-"$DSUF-$S12") IDX="${SB%-"$DSUF-$S12"}" ;;' '  *-*-"$S12") IDX="${SB%%-*}" ;;'
# The section counts, both directions: reverted to the exact-case `## ` match, and widened to
# every heading level (a `#### ` finding then counts as a section).
SEC_AC='    lc ~ /^###?[ \t]+acceptance criteria/ { nac++ }'
SEC_DEF='    lc ~ /^###?[ \t]+deferred/ { nda++ }'
mutant "MQ8 the section counts reverted to the exact '## ' heading" merge-review-shards.sh "q_secvar" \
  "$SEC_AC" '    /^## Acceptance Criteria[ \t]*$/ || /^## Acceptance Criteria[ \t]/ { nac++ }' \
  "$SEC_DEF" '    /^## Deferred ACs[ \t]*$/ || /^## Deferred ACs[ \t]/ { nda++ }'
mutant "MQ9 the section counts widened to every heading level" merge-review-shards.sh "q_secvar" \
  "$SEC_AC" '    lc ~ /^##+[ \t]+acceptance criteria/ { nac++ }' \
  "$SEC_DEF" '    lc ~ /^##+[ \t]+deferred/ { nda++ }'
# HAND-OVERS. Each is a wrong build the contract names.
mutant "MH1 the hand-over match check dropped" merge-review-shards.sh "q_ho_unm q_ho_orph" \
  '  d1="$(comm -23 "$T/hand.s" "$T/runs.s" | head -1)"' '  d1=""' \
  '  d1="$(comm -13 "$T/hand.s" "$T/runs.s" | head -1)"' '  d1=""'
mutant "MH2 an unmet replay does not force NEEDS_REWORK" merge-review-shards.sh "q_ho_force" \
  '  if [ -n "$FORCE" ]; then WORST="NEEDS_REWORK"' '  if false; then WORST="NEEDS_REWORK"'
# Fenced lines leak ONLY for the hand-over grammar, so every other fence arm stays green.
mutant "MH3 fenced hand-over lines counted" merge-review-shards.sh "q_ho_fenced" \
  '    fence { next }' '    fence && !/^handover/ { next }'
# Each refusal disabled alone; every world above MERGES PASS without it (MH4's world merged PASS on
# the release before H9 existed, with AC8's replay run by nobody).
mutant "MH4 a two-AC hand-over line accepted" merge-review-shards.sh "q_ho_multi" \
  '          [ -z "${a2:-}" ] || refuse' '          true || refuse'
mutant "MH5 two hand-over lines in one finding accepted" merge-review-shards.sh "q_ho_twoline" \
  '      [ "${nho:-0}" -le 1 ] || refuse' '      true || refuse'
mutant "MH6 a duplicate hand-over accepted" merge-review-shards.sh "q_ho_dup" \
  '  d1="$(sort "$T/hand" | uniq -d | head -1)"' '  d1=""'
# The widened malformed-line pattern reverted, one alternation family at a time: the decorated
# label back to the old stray pattern alone, then the column-0 no-colon forms dropped.
HM_DECO='    lc ~ /^[ \t>*_`+-]*([0-9]+\.[ \t]*)?[ \t>*_`+-]*hand[- ]?over(-run)?[*_` \t]*:/ \'
HM_NC='      || lc ~ /^([0-9]+\.[ \t]+)?hand-?over[^a-z0-9]+[a-z0-9][a-z0-9._-]*[0-9][a-z0-9._-]*([^a-z0-9._-]|$)/ \'
HM_NCR='      || lc ~ /^([0-9]+\.[ \t]+)?hand-?over-run[^a-z0-9]+[0-9]+[^a-z0-9]+[a-z0-9]/ { if (!hbad) hbad = NR }'
# The decorated family off kills H12 and, through `1. **handover:**`, H24's list cell.
mutant "MH7 the decorated hand-over label not refused" merge-review-shards.sh "q_ho_deco q_ho_widen" \
  "$HM_DECO" '    lc ~ /^NEVER-A-HAND-OVER$/ \'
mutant "MH8 a column-0 hand-over missing its colon not refused" merge-review-shards.sh "q_ho_nocolon q_ho_widen" \
  "$HM_NCR" '      { if (!hbad) hbad = NR }' \
  "$HM_NC" '      || 0 \'
# THE WIDENING REVERTED: the three alternations back to the pre-widening text. Every H12/H13 form
# is still refused by the old text, so H24 alone dies -- and the declared count does NOT rescue
# it, because H24 declares 0 and parses 0.
HM_DECO_OLD='    lc ~ /^[ \t>*_`+-]*hand[- ]?over(-run)?[*_` \t]*:/ \'
mutant "MH10 the malformed-line widening reverted" merge-review-shards.sh "q_ho_widen" \
  "$HM_DECO" "$HM_DECO_OLD" \
  "$HM_NC
$HM_NCR" '      || lc ~ /^hand-?over[ \t]+(-[ \t]+)?[a-z0-9][a-z0-9._-]*[0-9][a-z0-9._-]*[ \t]*$/ \
      || lc ~ /^hand-?over-run[ \t]+(-[ \t]+)?[0-9]+[ \t]+[a-z0-9]/ { if (!hbad) hbad = NR }'
# THE DECLARED COUNT. Dropping the equality lets H16 reach the malformed-line refusal (another
# message), H17's hidden forms merge, and H18 merge PASS.
mutant "MH11 the declared-count equality dropped" merge-review-shards.sh "q_hc_dash q_hc_hidden q_hc_zero" \
  '      [ "$((10#$hdv))" -eq "$nho_s" ] \' '      true \'
# A missing line read as a valid 0: both the line count relaxed and the absent value defaulted,
# or the non-integer refusal would still catch the `-` an absent value parses to.
mutant "MH12 a missing handovers: line accepted as 0" merge-review-shards.sh "q_hc_missing" \
  '      [ "$nhd" = "1" ] \' '      [ "$nhd" -le 1 ] \' \
  '    nhd="${nhd:-0}"; hdv="${hdv:--}"' '    nhd="${nhd:-0}"; hdv="${hdv:-0}"'
# The width guard alone: 2^64 wraps to 0 in bash 3.2's arithmetic, so only the guard refuses it.
mutant "MH13 the hand-over count's width guard dropped" merge-review-shards.sh "q_hc_nonint" \
  '      case "$hdv" in *[!0-9]*|??????????*) refuse' '      case "$hdv" in *[!0-9]*) refuse'
# The word-split read restored: `?` and `[1]` glob to a valid count in a cwd holding 0 and 1.
mutant "MH14 the hand-over count read by word-splitting" merge-review-shards.sh "q_hc_nonint" \
  '    read -r nhd hdv <<<"$(awk '"'"'$1 == "N" { print $2, $3 }'"'"' "$P")"' '    set -- $(awk '"'"'$1 == "N" { print $2, $3 }'"'"' "$P"); nhd="$1"; hdv="${2:-}"'
mutant "MH9 an <AC-id> may begin with any of its characters" merge-review-shards.sh "q_ho_acid" \
  "RE_AC='^[A-Za-z0-9][A-Za-z0-9._-]*\$'" "RE_AC='^[A-Za-z0-9._-]+\$'"

echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
