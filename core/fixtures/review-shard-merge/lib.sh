# review-shard-merge/lib.sh -- the resolution, seeded repositories, worlds and predicates of
# review-shard-merge, sourced by that fixture's run.sh (the behavioural arms, shipped) and by
# review-shard-merge-mutants/run.sh (the mutation battery, distribution-only). ONE copy, so the
# battery scores the predicates the shipped arms run and never a second implementation of them.
#
# The caller sets NAME and sources this file; nothing else. This file sets the shell options,
# scrubs AI_DLC_*, owns WORK and the ONE EXIT trap that removes it -- no caller sets a second.
#
# The threshold key is named ONCE, in the unset below (fixtures scrub AI_DLC_*; I87). Everywhere
# else it is DERIVED from the partition script's own dereference site.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset AI_DLC_REVIEW_SHARD_MIN_FILES
[ -n "${NAME:-}" ] || { echo "FIXTURE ERROR: lib.sh sourced without NAME set" >&2; exit 2; }

# Resolution walks up from THIS file's directory, so both callers resolve identically.
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The subjects and the files the merge derives from, found by walking UP in either layout --
# never by counting `..`. Distribution: core/scripts, core/skills, core/team-roles. Consumer:
# scripts/ai-dlc, .claude/skills, .claude/team-roles.
find_up() { # <rel-dist> <rel-consumer> -> first existing path walking up from $LIB_DIR
  local d="$LIB_DIR" c
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
  [ -n "$_x" ] || { echo "FIXTURE ERROR: $_p not found above $LIB_DIR in either layout; nothing was asserted" >&2; exit 2; }
done
SRCDIR="$(cd "$(dirname "$MERGE")" && pwd)"
[ "$(cd "$(dirname "$PART")" && pwd)" = "$SRCDIR" ] || { echo "FIXTURE ERROR: the partition is not beside the merge" >&2; exit 2; }
[ -f "$SRCDIR/artifact-path-config.sh" ] || { echo "FIXTURE ERROR: artifact-path-config.sh is not beside the partition; it reads the scan roots there" >&2; exit 2; }
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

WORK="$(mktemp -d "${TMPDIR:-/tmp}/$NAME.XXXXXX")" || exit 2
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

# THE FIXED SCRATCH PATHS, all of them, bound in ONE place. Every predicate writes either under a
# fresh `mktemp -d "$WORK/..."` or to one of these four, so a caller that runs predicates
# CONCURRENTLY rebinds these by name (bind_scratch <own dir>) and shares nothing else that is
# written. A fifth fixed path added to a predicate must be added here, or two concurrent scorers
# write it at once.
bind_scratch() { # <dir> -> MO, PO, PE, RERUN_KEEP under <dir>
  MO="$1/merge.out"; PO="$1/part.out"; PE="$1/part.err"; RERUN_KEEP="$1/rerun.keep"
}
bind_scratch "$WORK"
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
  cp "$o" "$RERUN_KEEP" || return 1
  run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "UNCHANGED:" && cmp -s "$o" "$RERUN_KEEP" || return 1
  shard "$d" 1 BLOCKED 1; run_merge "$sd" "$d"
  [ "$RC" -eq 2 ] && has "$MO" "REFUSED:" && has "$MO" "a review file is never overwritten" \
    && cmp -s "$o" "$RERUN_KEEP" && [ -z "$(find "$(dirname "$o")" -maxdepth 1 -name '*.merge-tmp.*')" ]
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

# Seed controls: the worlds must be able to express what the arms are named for. Both callers run
# them before any arm or mutant verdict is read.
seed_controls() { # W0, W1, W2
local A_NAMES A_REV na nn n1
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
# Gate 2: the seeded per-AC table row must not be what Check 1 counts, or Q2 is vacuous.
if printf '| AC | Verdict | Evidence |\n| AC2 | NEEDS_REWORK | replay |\n' > "$WORK/qctl.md" && [ "$(check1_count "$WORK/qctl.md")" = "0" ] \
   && printf '## Acceptance Criteria\n**Verdict:** PASS\n' > "$WORK/qctl2.md" && [ "$(check1_count "$WORK/qctl2.md")" = "1" ]; then
  ok "W2: Check 1's derived pattern matches 0 pipe-led per-AC table rows and 1 bold 'Verdict:' label, so Q2's single match is the merge's own"
else
  bad "W2: FIXTURE BROKEN -- Check 1's pattern [$PAT] counts a pipe-led AC row, or misses a bold label; Q2 cannot discriminate"
fi
}
