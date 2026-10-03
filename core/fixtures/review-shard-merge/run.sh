#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# review-shard-merge/run.sh -- partition-review-diff.sh and merge-review-shards.sh, the part set
# and the JOIN of a sharded gate-1 code review.
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
# and the value is read back Check 1's way (text after `:`, else the next non-blank line) by this
# fixture's own reader, not by the merge's.
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
for _p in PART MERGE GATE_MD ROLE_MD GRAMMAR STEP_MD; do
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

# --------------------------------------------------------------------------------- worlds
# A merge world: its own directory, the shard dir `1-code-review-<sha12>/` inside it holding the
# manifest the REAL partition (the predicate's own sibling) wrote, and --out beside it.
# new_world <script-dir> [repo] -> prints the shard dir
new_world() {
  local sd="$1" repo="${2:-$REPO_B}" w d
  w="$(mktemp -d "$WORK/w.XXXXXX")" || return 1
  d="$w/1-code-review-$B_SHA12"
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
# Check 1's read, written here: the FIRST match, the text after `:`, else the next non-blank line.
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
p_serial() { # no flag, key unset -> exit 3, SERIAL: naming the key, and no manifest written
  local sd="$1" out rc d
  d="$(mktemp -d "$WORK/ser.XXXXXX")/sd"
  out="$(bash "$sd/partition-review-diff.sh" --map "$REPO_B" "$B_BASE" "$B_SHA" --shard-dir "$d" < /dev/null 2>&1)"; rc=$?
  [ "$rc" -eq 3 ] && [ "${out#SERIAL:}" != "$out" ] && [ "${out#*"$KEY"}" != "$out" ] && [ ! -e "$d/.manifest" ]
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
P_ALL="part serial env worst c1 conserve miss_ord miss_cross dup part_cite cross_one sha_dir sha_rev moved a3 rerun anc cross_sha bad_verdict noparts manifest two_sha default_k stray nofind knob"

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
arm serial "P2: no --min-files and the key unset -> exit 3, stdout 'SERIAL:' naming $KEY, no manifest written" \
           "P2: the unset threshold did not answer SERIAL naming the key"
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
HDR_LINE="  printf '# Code Review: %s (merged from %s shards)\\n\\n' \"\$IDX\" \"\$((K + 1))\""
mutant "MX1 verdict by majority count" merge-review-shards.sh "worst" \
  "$WORST_LINE" 'TALLY="${TALLY:-} $v"' \
  "$HDR_LINE" "  WORST=\"\$(printf '%s\\n' \$TALLY | sort | uniq -c | sort -k1,1nr -k2,2 | awk 'NR == 1 { print \$2 }')\"
$HDR_LINE"
mutant "MX2 verdict = the cross shard's" merge-review-shards.sh "worst" \
  "$WORST_LINE" 'if [ "$key" = cross ]; then WORST_R="$r"; WORST="$v"; fi'
mutant "MX3 verdict = the last part read" merge-review-shards.sh "worst" \
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
mutant "MX5 emits a second Check-1 line" merge-review-shards.sh "c1 rerun" \
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
mutant "MX12 an unranked verdict is accepted" merge-review-shards.sh "bad_verdict" \
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
  '  case "$MINF" in ??????????*) refuse' '  case "$MINF" in NEVER) refuse' \
  'case "$MAXP" in ??????????*) refuse' 'case "$MAXP" in NEVER) refuse'
mutant "MX20 the 64-part ceiling removed" partition-review-diff.sh "knob" \
  '[ "$MAXP" -le 64 ] || refuse' '[ "$MAXP" -le 64 ] || true'

echo
if [ "$fails" -eq 0 ]; then echo "$NAME: PASS"; exit 0; fi
echo "$NAME: $fails assertion(s) FAILED" >&2
exit 1
