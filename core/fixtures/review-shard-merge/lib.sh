# review-shard-merge/lib.sh -- the resolution, seeded repositories, worlds and predicates of
# review-shard-merge, sourced by that fixture's run.sh (the behavioural arms, shipped) (the retired mutation battery sourced it too).
# ONE copy, so the predicates the shipped arms run are never restated.
#
# The caller sets NAME and sources this file; nothing else. This file sets the shell options,
# scrubs AI_DLC_*, owns WORK and the ONE EXIT trap that removes it -- no caller sets a second.
#
# The threshold key is named ONCE, in the unset below (fixtures scrub AI_DLC_*; I87). Everywhere
# else it is DERIVED from the partition script's own dereference site.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset AI_DLC_REVIEW_SHARD_MIN_FILES
# THE WORLD TEMPLATES are the mutation battery's alone (tpl_* below). Plain shell variables, unset HERE
# so no exported value can switch them on in the shipped arms; the battery sets them after sourcing.
unset RSM_TPL RSM_TPL_FILL RSM_TPL_HITS
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
[ -f "$SRCDIR/partition-document.sh" ] || { echo "FIXTURE ERROR: partition-document.sh is not beside the merge; it reads the cross groups there" >&2; exit 2; }
# BL-737: the seal reader and the seal writer the merge and --mark resolve beside themselves, and the
# recorder hook that writes the rows they read (distribution core/hooks, consumer .claude/hooks).
SEAL_SRC="$SRCDIR/content-seal.sh"; WFD_SRC="$SRCDIR/wait-for-deliverable.sh"
HOOK="$(find_up core/hooks/ai-dlc-content-seal.sh .claude/hooks/ai-dlc-content-seal.sh)" || HOOK=""
for _p in SEAL_SRC WFD_SRC HOOK; do
  eval "_x=\${$_p}"
  [ -n "$_x" ] && [ -f "$_x" ] || { echo "FIXTURE ERROR: $_p ($_x) not found beside the merge or above $LIB_DIR; nothing was asserted" >&2; exit 2; }
done
command -v jq >/dev/null 2>&1 || { echo "FIXTURE ERROR: jq is not on PATH; content-seal.sh reads its ledger with it" >&2; exit 2; }
echo "$NAME: resolved subjects = $PART , $MERGE , $SEAL_SRC , $WFD_SRC , $HOOK"

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
# THE ENGINE AT THE FROZEN SHA (the merge's LEGACY rule reads it from the manifest's worktree). It
# sits in the BASE commit, never the frozen one: a file in the base..sha diff would move every map.
# `old` is the subject's own wait-for-deliverable.sh with its one sentinel line removed (the engine
# that predates key=), in the consumer layout; `new` is the subject itself, in the distribution layout.
OLD_ENGINE="$WORK/old-engine.sh"
grep -vF '# MARK-KEY-WRITER v1' "$WFD_SRC" > "$OLD_ENGINE"
new_repo() { # <dir> [old|new] -> base commit holding the artifact-path grammar, and the engine named
  mkdir -p "$1/core/skills/ai-dlc" || return 1
  G init -q "$1" || return 1
  cp "$GRAMMAR" "$1/core/skills/ai-dlc/artifact-path-grammar.md"
  printf 'seed\n' > "$1/README"
  case "${2:-}" in
    old) mkdir -p "$1/scripts/ai-dlc" && cp "$OLD_ENGINE" "$1/scripts/ai-dlc/wait-for-deliverable.sh" || return 1 ;;
    new) mkdir -p "$1/core/scripts" && cp "$WFD_SRC" "$1/core/scripts/wait-for-deliverable.sh" || return 1 ;;
  esac
  G -C "$1" add -A && G -C "$1" commit -q -m base || return 1
}
REPO_A="$WORK/repo-a"; REPO_B="$WORK/repo-b"
new_repo "$REPO_A" && new_repo "$REPO_B" old || { echo "FIXTURE ERROR: git init/commit failed" >&2; exit 2; }
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
# E / F: eight and two top directories of identical weight, merged with --max-parts 8 and 2, so
# the map has K=8 (six cross groups, the largest G) and K=2 (one cross group, `cross.md`).
REPO_E="$WORK/repo-e"; REPO_F="$WORK/repo-f"
new_repo "$REPO_E" old && new_repo "$REPO_F" || { echo "FIXTURE ERROR: git init/commit failed" >&2; exit 2; }
for _i in 1 2 3 4 5 6 7 8; do lines "$REPO_E/e$_i/a.txt" 5 "e$_i-a"; lines "$REPO_E/e$_i/b.txt" 5 "e$_i-b"; done
# Six files, off the --min-files 4 boundary, so the `<`/`<=` mutant is owned by P2b alone.
for _i in 1 2; do for _f in a b c; do lines "$REPO_F/f$_i/$_f.txt" 5 "f$_i-$_f"; done; done
G -C "$REPO_E" add -A && G -C "$REPO_E" commit -q -m frozen
G -C "$REPO_F" add -A && G -C "$REPO_F" commit -q -m frozen
for r in "$REPO_E" "$REPO_F"; do
  [ -d "$r/.git" ] || { echo "FIXTURE ERROR: $r is not a repository" >&2; exit 2; }
done
E_BASE="$(G -C "$REPO_E" rev-parse HEAD~1)"; E_SHA="$(G -C "$REPO_E" rev-parse HEAD)"
F_BASE="$(G -C "$REPO_F" rev-parse HEAD~1)"; F_SHA="$(G -C "$REPO_F" rev-parse HEAD)"
# S / N: B's six files, so the map is B's (K=3), over a base whose engine is the key= engine itself
# (S, the sentinel present, distribution layout) or absent in both layouts (N).
REPO_S="$WORK/repo-s"; REPO_N="$WORK/repo-n"
new_repo "$REPO_S" new && new_repo "$REPO_N" || { echo "FIXTURE ERROR: git init/commit failed" >&2; exit 2; }
for r in "$REPO_S" "$REPO_N"; do
  for f in alpha/a1.txt alpha/a2.txt beta/b1.txt beta/b2.txt gamma/g1.txt gamma/g2.txt; do lines "$r/$f" 5 "$f"; done
  G -C "$r" add -A && G -C "$r" commit -q -m frozen
  [ -d "$r/.git" ] || { echo "FIXTURE ERROR: $r is not a repository" >&2; exit 2; }
done
S_BASE="$(G -C "$REPO_S" rev-parse HEAD~1)"; S_SHA="$(G -C "$REPO_S" rev-parse HEAD)"
N_BASE="$(G -C "$REPO_N" rev-parse HEAD~1)"; N_SHA="$(G -C "$REPO_N" rev-parse HEAD)"

# THE REVIEW TREE (BL-737). content-seal.sh --review-shard places a shard with `git rev-parse
# --show-toplevel` and refuses one that is not at docs/reviews/s<N>/shards/<idx>-code-review-<sha12>/
# (or -qa-validation-), so every merge world lives in MAIN, a git repository, at that path, one
# `s1.XXXXXX` per world. MAIN is in the CONSUMER layout because the recorder hook sources
# ${CLAUDE_PROJECT_DIR}/scripts/ai-dlc/content-seal.sh; its ledger is MAIN's own state dir. LW is a
# linked worktree of MAIN, whose shards' rows go to MAIN's ledger, never to LW/_bmad-output.
MAIN="$WORK/main"; LW="$WORK/lw"
mkdir -p "$MAIN/scripts/ai-dlc" && G init -q "$MAIN" && cp "$SEAL_SRC" "$MAIN/scripts/ai-dlc/content-seal.sh" \
  && printf 'main\n' > "$MAIN/README" && G -C "$MAIN" add README scripts && G -C "$MAIN" commit -q -m main \
  && [ -d "$MAIN/.git" ] && G -C "$MAIN" worktree add -q --detach "$LW" HEAD 2>/dev/null \
  && mkdir -p "$MAIN/docs/reviews" "$LW/docs/reviews" \
  || { echo "FIXTURE ERROR: the review tree $MAIN (and its linked worktree) could not be built" >&2; exit 2; }
LEDGER="$MAIN/_bmad-output/planning-artifacts/.artifact-writes.jsonl"
# DMAIN: the same shape in the DISTRIBUTION layout (core/scripts/), with its own linked worktree DLW.
DMAIN="$WORK/dmain"; DLW="$WORK/dlw"
mkdir -p "$DMAIN/core/scripts" && G init -q "$DMAIN" && cp "$SEAL_SRC" "$DMAIN/core/scripts/content-seal.sh" \
  && printf 'dmain\n' > "$DMAIN/README" && G -C "$DMAIN" add README core && G -C "$DMAIN" commit -q -m dmain \
  && [ -d "$DMAIN/.git" ] && G -C "$DMAIN" worktree add -q --detach "$DLW" HEAD 2>/dev/null \
  || { echo "FIXTURE ERROR: the distribution-layout tree $DMAIN could not be built" >&2; exit 2; }
# A symlinked ALIAS of MAIN's docs/: --check-shard is driven through it, so a refusal naming the
# physical path proves the target was resolved the way the merge's staging resolves it.
ALIAS="$WORK/alias-docs"
ln -s "$MAIN/docs" "$ALIAS" || { echo "FIXTURE ERROR: cannot create the alias $ALIAS" >&2; exit 2; }
wdir() { # -> a fresh <tree>/docs/reviews/s1.XXXXXX/shards, the tree $WROOT (default MAIN)
  local w; w="$(mktemp -d "${WROOT:-$MAIN}/docs/reviews/s1.XXXXXX")" || return 1
  mkdir "$w/shards" && printf '%s' "$w/shards"
}

# --------------------------------------------------------------------------------- worlds
# A merge world: its own directory, the shard dir `1-code-review-<sha12>/` inside it holding the
# manifest the REAL partition (the predicate's own sibling) wrote, and --out beside it.
# WORLD TEMPLATES. With RSM_TPL unset (the shipped fixture, always) every builder runs its subject as
# below and nothing else here is reached. The battery sets RSM_TPL to a directory the PARENT filled once
# (RSM_TPL_FILL set: each builder publishes the world it just built, before any shard is written into
# it), and then only for a scorer whose builder-run scripts are byte-identical to SRCDIR's; such a
# scorer clones the world into its own fresh directory instead of re-running the partition. The key is
# the builder's whole argument tuple; every other input -- the seeded repos, the environment, the
# scripts -- is the same run's, which is what makes the key sufficient. No world records its own path.
tpl_key() { printf '%s\n' "$@" | shasum | cut -c1-16; }
tpl_has() { [ -n "$1" ] && [ -n "${RSM_TPL:-}" ] && [ -z "${RSM_TPL_FILL:-}" ] && [ -d "$RSM_TPL/$1" ]; }
tpl_hit() { [ -z "${RSM_TPL_HITS:-}" ] || printf '%s\n' "$1" >> "$RSM_TPL_HITS"; }
tpl_put() { # <key> <world dir>: fill mode only, and never over a published template
  [ -n "$1" ] && [ -n "${RSM_TPL:-}" ] && [ -n "${RSM_TPL_FILL:-}" ] || return 0
  [ -d "$RSM_TPL/$1" ] && return 0
  mkdir "$RSM_TPL/$1" && cp -R "$2/." "$RSM_TPL/$1/"
}
# new_world <script-dir> [repo] -> prints the shard dir
new_world() { # <script-dir> [repo] [dir-suffix] [pass-marker, e.g. -p2]
  local sd="$1" repo="${2:-$REPO_B}" sfx="${3:-code-review}" pm="${4:-}" w d tk=""
  w="$(wdir)" || return 1
  d="$w/1-$sfx-$B_SHA12$pm"
  [ -z "${RSM_TPL:-}" ] || tk="$(tpl_key nw "$repo" "$B_BASE" "$B_SHA" 4 3 "$sfx" "$pm")"
  if tpl_has "$tk"; then
    cp -R "$RSM_TPL/$tk/." "$w/" || return 1; tpl_hit "$tk"
  else
    bash "$sd/partition-review-diff.sh" --map "$repo" "$B_BASE" "$B_SHA" --min-files 4 --max-parts 3 \
      --shard-dir "$d" > "$w/map" 2> "$w/map.err" < /dev/null || return 1
    tpl_put "$tk" "$w" || return 1
  fi
  [ -f "$d/.manifest" ] || return 1
  printf '%s' "$d"
}
out_of() { printf '%s/1-code-review.md' "$(dirname "$1")"; }

# shard <dir> <key> <verdict> <parts-cite> [reviewed-sha] [extra trailing text]
# Shaped on code-reviewer.md's Review Document Template (Summary, Findings with the three
# severity containers), with the shard lines in place of `## Verdict`.
# THE ONE FINDING'S CONTAINER FOLLOWS THE VERDICT (BL-740, the merge's VERDICT BACKING): an APPROVED
# shard carries no finding under Critical, so its finding sits under Important (which APPROVED
# allows); NEEDS_REWORK, BLOCKED and any other verdict keep it under Critical, which backs them. The
# headings and the finding are byte-identical to the pre-BL-740 seed; only the APPROVED placement moved.
shard_find() { printf '#### F-%s-1 an unchecked return in shard %s\nparts: %s\n\nBody of the finding.\n\n' "$1" "$1" "$2"; }
# THE ADVISOR LINE (BL-790), written by every shard and serial emitter below beside shard-verdict:, as
# qa.md and code-reviewer.md tell each writer to. SHARD_ADV overrides it for one world: set to the
# text of the line, or to the empty string to write none.
adv_l() { [ -z "${SHARD_ADV-advisor: called}" ] || printf '%s\n' "${SHARD_ADV-advisor: called}"; }
shard() {
  local d="$1" k="$2" v="$3" cite="$4" sha="${5:-${SHARD_SHA:-$B_SHA}}" extra="${6:-}"
  {
    printf '# Code Review shard %s\n\nreviewed-sha: %s\nshard-verdict: %s\n' "$k" "$sha" "$v"; adv_l
    # A part shard declares its hand-over count under both gates (code-reviewer.md "As a Shard").
    case "$k" in cross*) ;; *) printf 'handovers: 0\n' ;; esac
    printf '\n## Summary\nShard %s read its part. CONSERVE-%s-7f3a\n\n' "$k" "$k"
    printf '## Findings\n\n### Critical (must fix before merge)\n\n'
    [ "$v" = APPROVED ] || shard_find "$k" "$cite"
    printf '### Important (should fix, can be follow-up)\n\n'
    [ "$v" != APPROVED ] || shard_find "$k" "$cite"
    printf '### Suggestions (optional improvements)\n\n'
    printf '## Architecture Alignment\nNothing further.\n'
    [ -n "$extra" ] && printf '%s\n' "$extra"
  } > "$d/$k.md"
}
# THE CROSS SHARDS of a world, one per row of the subject's own sibling
# `partition-document.sh --cross-groups <K>` (K = the manifest's part count), keyed `cross` when it
# prints one row and `cross-<g>` otherwise. Each carries one finding citing its row's FIRST and
# LAST ordinal: those lie in the row's two different quarters, and a pair of quarters has exactly
# one group, so the finding is that row's own by the construction -- derived from the quarter
# definition, never from asking --cross-owner what the merge will accept.
# xshards <script-dir> <shard-dir> <verdict> [code-review|qa]
xshards() {
  local sd="$1" d="$2" v="$3" gate="${4:-code-review}" k n g gl first last key tk=""
  k="$(awk -F'\t' '$1 == "part" { n++ } END { print n + 0 }' "$d/.manifest")"
  [ -z "${RSM_TPL:-}" ] || tk="$(tpl_key xs "$k")"
  if tpl_has "$tk"; then
    cp "$RSM_TPL/$tk/groups" "$d.groups" || return 1; tpl_hit "$tk"
  else
    bash "$sd/partition-document.sh" --cross-groups "$k" > "$d.groups" 2> /dev/null < /dev/null || return 1
    if [ -n "$tk" ] && [ -n "${RSM_TPL_FILL:-}" ] && [ ! -d "$RSM_TPL/$tk" ]; then
      mkdir "$RSM_TPL/$tk" && cp "$d.groups" "$RSM_TPL/$tk/groups" || return 1
    fi
  fi
  n="$(grep -c . "$d.groups")" || n=0
  [ "$n" -ge 1 ] || return 1
  while IFS='	' read -r g gl; do
    first="${gl%%,*}"; last="${gl##*,}"
    if [ "$n" -eq 1 ]; then key=cross; else key="cross-$g"; fi
    if [ "$gate" = qa ]; then qshard "$d" "$key" "$v" "$first, $last"; else shard "$d" "$key" "$v" "$first, $last"; fi
    [ -f "$d/$key.md" ] || return 1
  done < "$d.groups"
  return 0
}
world4() { # <script-dir> <v1> <v2> <v3> <vcross> -> shard dir with the three parts and every cross shard
  local d; d="$(new_world "$1")" || return 1
  shard "$d" 1 "$2" 1; shard "$d" 2 "$3" 2; shard "$d" 3 "$4" 3; xshards "$1" "$d" "$5" || return 1
  printf '%s' "$d"
}
# A world over any repo and part ceiling, every part and cross shard written. SHARD_SHA is the
# frozen sha the shard writers stamp; each caller binds it `local` for its world.
# kworld <script-dir> <repo> <base> <sha> <max-parts> <dir-suffix> <verdict> [code-review|qa]
kworld() {
  local sd="$1" repo="$2" base="$3" sha="$4" mp="$5" sfx="$6" v="$7" gate="${8:-code-review}" w d k tk=""
  w="$(wdir)" || return 1
  d="$w/1-$sfx-$(printf '%s' "$sha" | cut -c1-12)"
  [ -z "${RSM_TPL:-}" ] || tk="$(tpl_key kw "$repo" "$base" "$sha" 4 "$mp" "$sfx")"
  if tpl_has "$tk"; then
    cp -R "$RSM_TPL/$tk/." "$w/" || return 1; tpl_hit "$tk"
  else
    bash "$sd/partition-review-diff.sh" --map "$repo" "$base" "$sha" --min-files 4 --max-parts "$mp" \
      --shard-dir "$d" > "$w/map" 2> "$w/map.err" < /dev/null || return 1
    tpl_put "$tk" "$w" || return 1
  fi
  [ -f "$d/.manifest" ] || return 1
  for k in $(cut -f1 "$w/map"); do
    if [ "$gate" = qa ]; then qshard "$d" "$k" "$v" "$k"; else shard "$d" "$k" "$v" "$k"; fi
    [ -f "$d/$k.md" ] || return 1
  done
  xshards "$sd" "$d" "$v" "$gate" || return 1
  printf '%s' "$d"
}

# THE FIXED SCRATCH PATHS, all of them, bound in ONE place. Every predicate writes either under a
# fresh `mktemp -d "$WORK/..."` or to one of these four, so a caller that runs predicates
# CONCURRENTLY rebinds these by name (bind_scratch <own dir>) and shares nothing else that is
# written. A fifth fixed path added to a predicate must be added here, or two concurrent scorers
# write it at once.
bind_scratch() { # <dir> -> MO, PO, PE, RERUN_KEEP, CO, MKO under <dir>
  MO="$1/merge.out"; PO="$1/part.out"; PE="$1/part.err"; RERUN_KEEP="$1/rerun.keep"; CO="$1/check.out"; MKO="$1/mark.out"
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
  local sd="$1" w d o k n mn
  w="$(wdir)" || return 1
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
  ( SHARD_SHA="$D_SHA"; xshards "$sd" "$d" APPROVED ) || return 1
  o="$(out_of "$d")"; run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] || return 1
  # A second world with the flag AND the key set, disagreeing: the manifest records the FLAG's
  # number, the threshold actually applied, because that is what the merge hands back.
  w="$(wdir)" || return 1
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
p_fence_nested() { # a ```` fence holding a ``` block, then a '#### ' finding citing part 2, then the ```` closer,
  # under shard 2's ## Findings: the finding is inside the fence, so the merge counts exactly the base
  # world's findings. A closer without the length rule ends the fence at the inner bare ``` and counts it.
  local sd="$1" d n0
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
  run_merge "$sd" "$d"; [ "$RC" -eq 0 ] || return 1
  n0="$(sed -n 's/.* findings=\([0-9]*\) .*/\1/p' "$MO")"; [ -n "$n0" ] || return 1
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
  awk '{ print } /^### Important/ && !x { x = 1; print ""; print "````md"; print "```text"; print "quoted"; print "```"
         print "#### F-2-9 a finding quoted inside the outer fence"; print "parts: 2"; print "````"; print "" }' \
    "$d/2.md" > "$d/2.tmp" && mv "$d/2.tmp" "$d/2.md" && grep -q '^#### F-2-9 ' "$d/2.md" || return 1
  run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "findings=$n0 "
}
p_conserve() { # a unique token from every part and from cross appears in the output
  local sd="$1" d o k
  d="$(world4 "$sd" NEEDS_REWORK APPROVED NEEDS_REWORK NEEDS_REWORK)" || return 1
  o="$(out_of "$d")"; run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && [ -f "$o" ] || return 1
  for k in 1 2 3 cross-1 cross-2 cross-3; do has "$o" "CONSERVE-$k-7f3a" && has "$o" "#### F-$k-1 " || return 1; done
}
p_miss_ord() { local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  rm -f "$d/2.md"; run_merge "$1" "$d"; refused_clean "shard 2 is missing from" "$d"; }
p_miss_cross() { # a cross shard that is not the first one missing
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  [ -f "$d/cross-2.md" ] || return 1
  rm -f "$d/cross-2.md"; run_merge "$1" "$d"; refused_clean "shard cross-2 is missing from" "$d"; }
p_dup() { local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  cp "$d/1.md" "$d/01.md"; run_merge "$1" "$d"; refused_clean "was delivered more than once" "$d"; }
p_part_cite() { local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  shard "$d" 2 APPROVED 3; run_merge "$1" "$d"
  refused_clean "a part shard reports only findings citing its own part alone" "$d"; }
p_cross_one() { local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  shard "$d" cross-1 APPROVED 2; run_merge "$1" "$d"
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
  shard "$d" 1 APPROVED 1; shard "$d" 2 APPROVED 2; shard "$d" 3 APPROVED 3; xshards "$sd" "$d" APPROVED || return 1
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
  { printf '# Code Review shard %s\n\nreviewed-sha: %s\nshard-verdict: APPROVED\n' "$k" "$B_SHA"; adv_l
    case "$k" in cross*) ;; *) printf 'handovers: 0\n' ;; esac
    printf '\n'; printf '%s\n' "$@"; } > "$d/$k.md"
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
p_cross_sha() { # MF: a CROSS shard (not the first) carrying the base sha as reviewed-sha
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  shard "$d" cross-2 APPROVED "1, 3" "$B_BASE"; run_merge "$1" "$d"
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
  AI_DLC_PROJECT_ROOT="${5:-${VB_PROJ:-$PROJ}}" bash "$1/merge-review-shards.sh" "$2" --gate "$3" --out "$4" \
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
# CANON_BLK (BL-769): the execution owner's canonical run, as qa.md tells it to write one -- the
# invocation line and the summary line with counts. Every first-cross QA shard and every serial QA
# file carries it, so a PASS merges; the canonical-run cells below remove or rewrite it.
CANON_BLK="$(printf 'Canonical run: `python3 -m pytest -q` from the frozen worktree root\nCanonical result: 812 passed, 3 skipped, 0 failed, 0 deselected')"
qshard() {
  local d="$1" k="$2" v="$3" cite="$4" extra="${5:-}" hc="${6:-0}"
  {
    printf '# QA Validation shard %s\n\nreviewed-sha: %s\nshard-verdict: %s\n' "$k" "${SHARD_SHA:-$B_SHA}" "$v"; adv_l
    case "$k" in cross*) ;; *) [ "$hc" = OMIT ] || printf 'handovers: %s\n' "$hc" ;; esac
    printf '\n'
    printf '## Summary\nShard %s validated its part. QCONSERVE-%s-91c2\n\n' "$k" "$k"
    { [ "$k" = cross ] || [ "$k" = cross-1 ]; } && printf '%s\n\n' "$CANON_BLK"
    printf '## Findings\n\n### Important (should fix, can be follow-up)\n\n#### Q-%s-1 a missing caller in shard %s\nparts: %s\n\nBody.\n\n' "$k" "$k" "$cite"
    # The per-AC table and the deferred record: the FIRST cross shard's alone (the execution owner).
    if [ "$k" = cross ] || [ "$k" = cross-1 ]; then
      printf '## Acceptance Criteria\n\n| AC | Verdict | Evidence |\n|---|---|---|\n| AC1 | PASS | suite green |\n| AC2 | %s | replay |\n\n' "$v"
      printf '## Deferred ACs\n\nNone.\n'
    fi
    [ -n "$extra" ] && printf '%s\n' "$extra"
  } > "$d/$k.md"
}
qworld() { # <script-dir> <v1> <v2> <v3> <vcross> [pass marker] -> a qa shard dir with all four shards
  local d; d="$(new_world "$1" "$REPO_B" "$QA_SFX" "${6:-}")" || return 1
  qshard "$d" 1 "$2" 1; qshard "$d" 2 "$3" 2; qshard "$d" 3 "$4" 3; xshards "$1" "$d" "$5" qa || return 1
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
  for k in 1 2 3 cross-1 cross-2 cross-3; do has "$o" "QCONSERVE-$k-91c2" && has "$o" "#### Q-$k-1 " || return 1; done
}
p_q_title() { # Q3: the merged title names the gate -- `# Code Review:` for gate 1, `# QA Validation:` for gate 2
  local sd="$1" d o
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
  o="$(out_of "$d")"; run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && [ "$(sed -n 1p "$o")" = "# Code Review: 1 (merged from 6 shards)" ] || return 1
  d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"; q_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && [ "$(sed -n 1p "$o")" = "# QA Validation: 1 (merged from 6 shards)" ]
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
  awk '/^## Acceptance Criteria$/ { print "## Per-AC results"; next } { print }' "$d/cross-1.md" > "$d/cross.tmp" \
    && mv "$d/cross.tmp" "$d/cross-1.md" && ! grep -q '^## Acceptance Criteria' "$d/cross-1.md" || return 1
  o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_AC_0" "$o"; }
p_q_cross_twoac() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" cross-1 PASS "1, 2" "$(printf '\n## Acceptance Criteria\n\n| AC | Verdict |\n|---|---|\n| AC9 | PASS |')"
  o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_AC_2" "$o"; }
p_q_cross_twodef() { local d o; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  qshard "$d" cross-1 PASS "1, 2" "$(printf '\n## Deferred ACs\n\n- AC5: deferred')"
  o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_DEF_COUNT" "$o"; }
p_q_nodef() { # Q-allow: a cross shard with NO '## Deferred ACs' merges (at most one, not exactly one)
  local d; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  awk '/^## Deferred ACs$/ { skip = 1; next } skip && /^## / { skip = 0 } !skip { print }' "$d/cross-1.md" > "$d/cross.tmp" \
    && mv "$d/cross.tmp" "$d/cross-1.md" && ! grep -q '^## Deferred ACs' "$d/cross-1.md" || return 1
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
  qshard "$d" cross-1 PASS "1, 2" "$(printf '\n## Acceptance Criteria:\n\n| AC | Verdict |\n|---|---|\n| AC9 | PASS |')"
  q_merge "$sd" "$d"; refused_at "$QT_AC_2" "$o" || return 1
  # Near-misses, which MERGE: the variants inside a fence, and a `#### ` FINDING titled with a
  # section name -- that level is a finding, never a section.
  qshard "$d" cross-1 PASS "1, 2"
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
  shard "$d" 1 APPROVED 1; shard "$d" 2 APPROVED 2; shard "$d" 3 APPROVED 3; xshards "$sd" "$d" APPROVED || return 1
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
# BL-746: two more qa.md roots, derived from the subject's own qa.md. QLEG is the qa.md a consumer runs
# the engine against from pull step 3 until the reconcile merge: its `## Findings Template` section
# (to the next `## ` heading outside a fence) removed, so the template declares NO container. Q2 keeps
# the section and drops its Suggestions container, so it declares two. Each carries its own control:
# QLEG must lose the section and keep the verdict set, Q2 must differ from the subject by one line.
PROJ_QLEG="$WORK/proj-qleg"; PROJ_Q2="$WORK/proj-q2"
for _r in "$PROJ_QLEG" "$PROJ_Q2"; do
  mkdir -p "$_r/core/skills/ai-dlc/steps" "$_r/core/team-roles"
  cp "$PROJ/core/skills/ai-dlc/steps/gate-validation.md" "$_r/core/skills/ai-dlc/steps/"
  cp "$PROJ/core/team-roles/code-reviewer.md" "$_r/core/team-roles/"
done
awk '/^```/ { f = !f } !f && /^## / { skip = ($0 ~ /^## Findings Template[ \t]*$/) } !skip' "$PROJ/core/team-roles/qa.md" > "$PROJ_QLEG/core/team-roles/qa.md"
grep -v '^### Suggestions ' "$PROJ/core/team-roles/qa.md" > "$PROJ_Q2/core/team-roles/qa.md"
_q_t="$(grep -c '^## Findings Template' "$PROJ/core/team-roles/qa.md")" || _q_t=0
_q_l="$(grep -c '^### \(Critical\|Important\|Suggestions\) ' "$PROJ_QLEG/core/team-roles/qa.md")" || _q_l=0
_q_v="$(grep -c '^PASS | NEEDS_REWORK$' "$PROJ_QLEG/core/team-roles/qa.md")" || _q_v=0
_q_2=$(( $(wc -l < "$PROJ/core/team-roles/qa.md") - $(wc -l < "$PROJ_Q2/core/team-roles/qa.md") ))
[ "$_q_t" = 1 ] && [ "$_q_l" = 0 ] && [ "$_q_v" = 1 ] && [ "$_q_2" = 1 ] \
  || { echo "FIXTURE STALE: the qa.md roots cannot express the container states (template $_q_t, legacy containers $_q_l, legacy verdict line $_q_v, two-container diff $_q_2)" >&2; exit 2; }
# THE SEVERITY BOUNDARY's two frozen trees (BL-746). B's six files over a base that INSTALLS qa.md at the
# consumer path .claude/team-roles/qa.md -- QL the container-less one (PROJ_QLEG's, graph's installed
# shape), QS the subject's own. The installed copy sits in the BASE commit, so the map is B's (K=3).
# REPO_B itself installs no qa.md: the unreadable side.
REPO_QL="$WORK/repo-ql"; REPO_QS="$WORK/repo-qs"
for _r in "$REPO_QL" "$REPO_QS"; do
  new_repo "$_r" old || { echo "FIXTURE ERROR: git init/commit failed" >&2; exit 2; }
  mkdir -p "$_r/.claude/team-roles"
  if [ "$_r" = "$REPO_QL" ]; then cp "$PROJ_QLEG/core/team-roles/qa.md" "$_r/.claude/team-roles/qa.md"
  else cp "$PROJ/core/team-roles/qa.md" "$_r/.claude/team-roles/qa.md"; fi
  G -C "$_r" add -A && G -C "$_r" commit -q --amend -m base || { echo "FIXTURE ERROR: the installed qa.md was not committed" >&2; exit 2; }
  for f in alpha/a1.txt alpha/a2.txt beta/b1.txt beta/b2.txt gamma/g1.txt gamma/g2.txt; do lines "$_r/$f" 5 "$f"; done
  G -C "$_r" add -A && G -C "$_r" commit -q -m frozen || { echo "FIXTURE ERROR: git commit failed" >&2; exit 2; }
done
QL_BASE="$(G -C "$REPO_QL" rev-parse HEAD~1)"; QL_SHA="$(G -C "$REPO_QL" rev-parse HEAD)"
QS_BASE="$(G -C "$REPO_QS" rev-parse HEAD~1)"; QS_SHA="$(G -C "$REPO_QS" rev-parse HEAD)"
_ql="$(G -C "$REPO_QL" show "${QL_SHA}:.claude/team-roles/qa.md" | grep -c '^## Findings Template')" || _ql=0
_qs="$(G -C "$REPO_QS" show "${QS_SHA}:.claude/team-roles/qa.md" | grep -c '^## Findings Template')" || _qs=0
_qb=0; G -C "$REPO_B" cat-file -e "${B_SHA}:.claude/team-roles/qa.md" 2>/dev/null && _qb=1
[ "$_ql" = 0 ] && [ "$_qs" = 1 ] && [ "$_qb" = 0 ] \
  || { echo "FIXTURE STALE: the frozen trees cannot express the severity boundary (QL template $_ql, QS template $_qs, B carries qa.md $_qb)" >&2; exit 2; }
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
QT_HO_UNM="hand-over '2 AC7' (part shard 2) has no 'handover-run:' line in cross-1.md"
QT_HO_ORPH="cross-1.md carries 'handover-run: 2 AC7' but part shard 2 handed over no such AC"
QT_HO_CROSS="carries a 'handover:' line; only a part shard hands an AC over"
QT_HO_PRUN="(part shard 3) carries a 'handover-run:' line; only the cross shard runs a handed-over replay"
QT_HO_CITE="a hand-over replay finding cites exactly the parts it ran replays for"
QT_HO_STRAY="carries a 'handover:' or 'handover-run:' line outside a '#### ' finding"
HO_PART2="$(printf '### Important\n\n#### Q-2-H AC7 replay cannot reach a GREEN baseline in the part worktree\nparts: 2\nhandover: AC7\n\nThe documented setup fails in a fresh worktree.')"
qcross() { # <dir> <verdict> <text inserted inside cross-1.md's ## Findings> -- the execution owner
  {
    printf '# QA Validation shard cross-1\n\nreviewed-sha: %s\nshard-verdict: %s\n' "$B_SHA" "$2"; adv_l; printf '\n'
    printf '## Summary\nShard cross-1 validated its part. QCONSERVE-cross-1-91c2\n\n%s\n\n' "$CANON_BLK"
    printf '## Findings\n\n### Important (should fix, can be follow-up)\n\n#### Q-cross-1-1 a missing caller in shard cross-1\nparts: 1, 2\n\nBody.\n\n%s\n\n' "$3"
    printf '## Acceptance Criteria\n\n| AC | Verdict | Evidence |\n|---|---|---|\n| AC1 | PASS | suite green |\n\n## Deferred ACs\n\nNone.\n'
  } > "$1/cross-1.md"
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
  qshard "$d" cross-2 PASS "1, 3" "handovers: 0"
  o="$(qout "$d")"; q_merge "$1" "$d"; refused_at "$QT_HC_CROSS" "$o"; }
p_q_hc_none() { # the ALLOW twin: every part `handovers: 0`, no hand-over anywhere, merges PASS
  local d o k; d="$(qworld "$1" PASS PASS PASS PASS)" || return 1
  for k in 1 2 3; do grep -qx 'handovers: 0' "$d/$k.md" || return 1; done
  for k in cross-1 cross-2 cross-3; do [ -f "$d/$k.md" ] && ! grep -q '^handovers:' "$d/$k.md" || return 1; done
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
# ------------------------------------------------------------------- the sharded cross reviewer
# The cross reviewer is one shard per row of `partition-document.sh --cross-groups <K>`. Each arm
# below demands the merge's own refusal message, so a world refused for another reason fails it.
QT_X_ONLY="a single cross shard is owed only at K=2"
QT_X_MIX="mixes cross.md with cross-<g>.md"
QT_X_OWNER="a finding owned by cross-1 (partition-document.sh --cross-owner)"
QT_X_AC="(cross-2) carries a '## Acceptance Criteria' section; only cross-1, the execution owner"
QT_X_DEF="(cross-3) carries a '## Deferred ACs' section; only cross-1, the execution owner"
QT_X_HORUN="(cross-2) carries a 'handover-run:' line; only cross-1, the execution owner"
QT_X_SEAT="does not end in 'seat-complete: ' while another shard"
QT_X_COUNT="findings=3' but its ## Findings section heads 1 finding(s)"
# <shard-file> <heading-id> <cite>: a second finding, inside ## Findings, under ### Important (inserted
# before ### Suggestions). Under Important, not Critical: every shard it is used on is APPROVED, and an
# APPROVED shard carrying a Critical finding is refused by the merge's VERDICT BACKING (BL-740) at cross-1,
# which the merge checks before cross-3 -- pre-empting the owner-duplicate refusal X5 and OT1 assert.
xfinding() {
  awk -v h="$2" -v c="$3" '/^### Suggestions/ && !d { printf "#### %s an interaction\nparts: %s\n\nBody.\n\n", h, c; d = 1 } { print }' \
    "$1" > "$1.x" && mv "$1.x" "$1" && grep -q "^#### $2 " "$1"
}
nparts() { awk -F'\t' '$1 == "part" { n++ } END { print n + 0 }' "$1/.manifest"; }
p_x_k8() { # X1: K=8 -> eight parts and cross-1..6 merge; the title counts 14 shards; one body header per group
  local sd="$1" d o g SHARD_SHA="$E_SHA"
  d="$(kworld "$sd" "$REPO_E" "$E_BASE" "$E_SHA" 8 code-review APPROVED)" || return 1
  [ "$(nparts "$d")" = 8 ] || return 1
  for g in 1 2 3 4 5 6; do [ -f "$d/cross-$g.md" ] || return 1; done
  [ ! -e "$d/cross-7.md" ] && [ ! -e "$d/cross.md" ] || return 1
  o="$(out_of "$d")"; run_merge "$sd" "$d"
  # The shard COUNT only: the title's gate wording is Q3's.
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && grep -qF '(merged from 14 shards)' <<<"$(sed -n 1p "$o")" \
    && has "$o" "## Shard: cross-1 (1,2,3,4)" && has "$o" "## Shard: cross-6 (5,6,7,8)" && has "$o" "#### F-cross-6-1 "
}
p_x_only() { # X2: K=8 (and K=3) with ONE cross.md in place of the groups -> REFUSED, nothing written
  local sd="$1" d g SHARD_SHA="$E_SHA"
  d="$(kworld "$sd" "$REPO_E" "$E_BASE" "$E_SHA" 8 code-review APPROVED)" || return 1
  for g in 1 2 3 4 5 6; do rm -f "$d/cross-$g.md"; done
  shard "$d" cross APPROVED "1, 8"; run_merge "$sd" "$d"; refused_clean "$QT_X_ONLY" "$d" || return 1
  SHARD_SHA="$B_SHA"; d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
  rm -f "$d"/cross-*.md; shard "$d" cross APPROVED "1, 3"; run_merge "$sd" "$d"; refused_clean "$QT_X_ONLY" "$d"
}
p_x_mix() { # X3: cross.md beside cross-1..3 -> REFUSED
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  shard "$d" cross APPROVED "1, 3"; run_merge "$1" "$d"; refused_clean "$QT_X_MIX" "$d"; }
p_x_unknown() { # X4: cross-4 at K=3 (G=3), and cross-1.md in place of cross.md at K=2 (G=1) -> each REFUSED
  local sd="$1" d SHARD_SHA="$B_SHA"
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
  shard "$d" cross-4 APPROVED "1, 3"; run_merge "$sd" "$d"
  refused_clean "is cross-4, which partition-document.sh --cross-groups 3 does not print" "$d" || return 1
  SHARD_SHA="$F_SHA"; d="$(kworld "$sd" "$REPO_F" "$F_BASE" "$F_SHA" 2 code-review APPROVED)" || return 1
  [ "$(nparts "$d")" = 2 ] && [ -f "$d/cross.md" ] || return 1
  mv "$d/cross.md" "$d/cross-1.md"; run_merge "$sd" "$d"
  refused_clean "is cross-1, which partition-document.sh --cross-groups 2 does not print" "$d"
}
p_x_owner() { # X5: K=8; a finding citing 1, 2 (inside groups 1, 2 and 3; owned by 1) reported by
  # cross-3 AND by its owner cross-1 -> REFUSED, the identical set. A finding citing 1, 2, 7 reported
  # by cross-3 alone (owned by 1, which holds no 7) merges: a cross reviewer reads the whole diff.
  # The ALLOW twin, same run: the 1, 2 finding reported by cross-1 alone merges and the conserved
  # finding count rises by exactly one.
  local sd="$1" d o n0 SHARD_SHA="$E_SHA"
  d="$(kworld "$sd" "$REPO_E" "$E_BASE" "$E_SHA" 8 code-review APPROVED)" || return 1
  grep -q '^parts: 1, 2$' "$d/cross-3.md" && return 1   # the seed must not already carry it
  xfinding "$d/cross-3.md" F-dup "1, 2" || return 1; xfinding "$d/cross-1.md" F-own "1, 2" || return 1
  o="$(out_of "$d")"; run_merge "$sd" "$d"; refused_clean "$QT_X_OWNER" "$d" || return 1
  d="$(kworld "$sd" "$REPO_E" "$E_BASE" "$E_SHA" 8 code-review APPROVED)" || return 1
  o="$(out_of "$d")"; run_merge "$sd" "$d"; [ "$RC" -eq 0 ] || return 1
  n0="$(sed -n 's/.* findings=\([0-9]*\) .*/\1/p' "$MO")"; rm -f "$o"
  xfinding "$d/cross-3.md" F-tri "1, 2, 7" || return 1
  run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "findings=$((n0 + 1)) " && has "$o" "#### F-tri " || return 1
  d="$(kworld "$sd" "$REPO_E" "$E_BASE" "$E_SHA" 8 code-review APPROVED)" || return 1
  o="$(out_of "$d")"; run_merge "$sd" "$d"; [ "$RC" -eq 0 ] || return 1
  n0="$(sed -n 's/.* findings=\([0-9]*\) .*/\1/p' "$MO")"; rm -f "$o"
  xfinding "$d/cross-1.md" F-dup "1, 2" || return 1
  run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "findings=$((n0 + 1)) " && has "$o" "#### F-dup "
}
p_x_actable() { # X6 (--gate qa): the per-AC table in cross-2, and the deferred record in cross-3 -> each REFUSED
  local sd="$1" d o
  d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1
  o="$(qout "$d")"
  qshard "$d" cross-2 PASS "1, 3" "$(printf '## Acceptance Criteria\n\n| AC | Verdict |\n|---|---|\n| AC9 | PASS |')"
  q_merge "$sd" "$d"; refused_at "$QT_X_AC" "$o" || return 1
  qshard "$d" cross-2 PASS "1, 3"
  qshard "$d" cross-3 PASS "2, 3" "$(printf '## Deferred ACs\n\n- AC5: deferred')"
  q_merge "$sd" "$d"; refused_at "$QT_X_DEF" "$o"
}
p_x_horun() { # X7 (--gate qa): part 2's hand-over replayed by cross-2, not cross-1 -> REFUSED
  local sd="$1" d o
  d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1
  qshard "$d" 2 PASS 2 "$HO_PART2" 1
  qshard "$d" cross-2 PASS "1, 3" "$(ho_run 2 '2 AC7 RED')"
  ! grep -q '^handover-run:' "$d/cross-1.md" || return 1
  o="$(qout "$d")"; q_merge "$sd" "$d"; refused_at "$QT_X_HORUN" "$o"
}
p_x_k2() { # X8: K=2 -> cross.md, both gates merge; the title counts 3 shards, the body header is `## Shard: cross`
  local sd="$1" d o SHARD_SHA="$F_SHA"
  d="$(kworld "$sd" "$REPO_F" "$F_BASE" "$F_SHA" 2 code-review APPROVED)" || return 1
  [ "$(nparts "$d")" = 2 ] && [ -f "$d/cross.md" ] && [ ! -e "$d/cross-1.md" ] || return 1
  o="$(out_of "$d")"; run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && grep -qF '(merged from 3 shards)' <<<"$(sed -n 1p "$o")" \
    && has "$o" "## Shard: cross" && ! has "$o" "## Shard: cross-" || return 1
  d="$(kworld "$sd" "$REPO_F" "$F_BASE" "$F_SHA" 2 "$QA_SFX" PASS qa)" || return 1
  o="$(qout "$d")"; q_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && has "$o" "| AC | Verdict | Evidence |"
}
p_x_seat() { # X9: seat-complete -- one shard without the marker beside shards with it, and a shard
  # whose marker is not its last non-blank line -> each REFUSED; every shard ending in it merges,
  # trailing blank lines skipped, and the marker is not in the merged file.
  local sd="$1" d o k
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
  for k in 1 2 3 cross-1 cross-2 cross-3; do printf 'seat-complete: implementation code-reviewer %s findings=1\n\n' "$k" >> "$d/$k.md"; done
  shard "$d" 2 APPROVED 2
  o="$(out_of "$d")"; run_merge "$sd" "$d"; refused_clean "$QT_X_SEAT" "$d" || return 1
  printf 'seat-complete: implementation code-reviewer 2 findings=1\n#### F-2-late a finding after the marker\n' >> "$d/2.md"
  run_merge "$sd" "$d"; refused_clean "$QT_X_SEAT" "$d" || return 1
  # All marked, one partial: shard 2 declares findings=3 over the 1 it holds -> REFUSED as truncated.
  shard "$d" 2 APPROVED 2; printf 'seat-complete: implementation code-reviewer 2 findings=3\n' >> "$d/2.md"
  run_merge "$sd" "$d"; refused_clean "$QT_X_COUNT" "$d" || return 1
  shard "$d" 2 APPROVED 2; printf 'seat-complete: implementation code-reviewer 2 findings=1\n' >> "$d/2.md"
  run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] && ! has "$o" "seat-complete:"
}
# X10 (BL-763): every owner-duplicate refusal in one run. K=3 world (groups 1:(1,2) 2:(1,3) 3:(2,3), each
# default cross shard citing its own group's set). Seven cases on one world, each reset from a clean copy;
# each row that answers wrongly writes its own WHY token, so M21 (only the first duplicate printed) and
# M22 (the --check-shard barrier dropped) are each scored on the one row they move.
xcrit() { # <shard-file>: a '#### ' finding under '### Critical' citing the shard's own set -- refused under APPROVED
  awk '/^### Critical/ && !d { print; printf "\n#### F-crit a critical interaction\nparts: 1, 3\n\nBody.\n"; d = 1; next } { print }' \
    "$1" > "$1.x" && mv "$1.x" "$1" && grep -q '^#### F-crit ' "$1"
}
xd_tails() { grep '^REFUSED:' "$MO" | sed -n 's/.*\[owner: \([^]]*\)\]$/\1/p' | tr '\n' ' '; }
xd_first() { local l; l="$(grep -m1 '^REFUSED:' "$MO")"; if grep -q 'identical set' <<<"$l"; then echo dup; else echo other; fi; }
xd_w() { if [ -e "$1" ]; then echo y; else echo n; fi; }
xd_row() { # <token> <want> <got>
  [ "$2" = "$3" ] || WHY="$WHY $1{want '$2' got '$3'}"
}
xd_zero_sha() { sed 's/^reviewed-sha: .*/reviewed-sha: 0000000000000000000000000000000000000000/' "$1" > "$1.x" && mv "$1.x" "$1"; }
p_x_dupall() {
  local sd="$1" d c o SHARD_SHA="$B_SHA"
  WHY=""
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || { WHY="the K=3 world was not built"; return 1; }
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || { WHY="the clean copy was not made"; return 1; }
  o="$(out_of "$d")"
  # two duplicates in two seats: cross-2 cites 1, 2 (owned by cross-1) and cross-3 cites 1, 3 (owned by cross-2)
  if cell two; then
    xfinding "$d/cross-2.md" F-dupA "1, 2" && xfinding "$d/cross-3.md" F-dupB "1, 3" || { WHY="two: the seed did not apply"; return 1; }
    run_merge "$sd" "$d"; xd_row two "rc=2 n=2 tails=cross-2 cross-3  written=n" "rc=$RC n=$(nref "$MO") tails=$(xd_tails) written=$(xd_w "$o")"
    rm -f "$o"; cs_reset "$d" "$c"
  fi
  if cell one; then
    xfinding "$d/cross-2.md" F-dupA "1, 2" || { WHY="one: the seed did not apply"; return 1; }
    run_merge "$sd" "$d"; xd_row one "rc=2 n=1 tails=cross-2  written=n" "rc=$RC n=$(nref "$MO") tails=$(xd_tails) written=$(xd_w "$o")"
    rm -f "$o"; cs_reset "$d" "$c"
  fi
  # near-miss: cross-1 cites its own set 1, 2 a second time -> merges
  if cell near; then
    xfinding "$d/cross-1.md" F-ownB "1, 2" || { WHY="near: the seed did not apply"; return 1; }
    run_merge "$sd" "$d"; xd_row near "rc=0 merged=y" "rc=$RC merged=$(has "$MO" "MERGED:" && echo y || echo n)"
    rm -f "$o"; cs_reset "$d" "$c"
  fi
  # --check-shard over the duplicating seat, its owner sealed: the exit code is what --mark seals on
  if cell check; then
    xfinding "$d/cross-2.md" F-dupA "1, 2" || { WHY="check: the seed did not apply"; return 1; }
    lmark "$d/cross-1.md" - cross-1 key=cross-1
    run_check "$sd" "$d" code-review "$d/cross-2.md"
    xd_row check "rc=2 n=1 ok=n" "rc=$CRC n=$(nref "$CO") ok=$(has "$CO" "SHARD-OK" && echo y || echo n)"
    cs_reset "$d" "$c"
  fi
  # precedence (a): the duplicate in cross-2, then a per-shard structural refusal in cross-3
  if cell preca; then
    xfinding "$d/cross-2.md" F-dupA "1, 2" || { WHY="preca: the seed did not apply"; return 1; }
    xd_zero_sha "$d/cross-3.md"
    run_merge "$sd" "$d"; xd_row preca "rc=2 n=2 tails=cross-2 cross-3  first=dup written=n" "rc=$RC n=$(nref "$MO") tails=$(xd_tails) first=$(xd_first) written=$(xd_w "$o")"
    rm -f "$o"; cs_reset "$d" "$c"
  fi
  # precedence (b): the structural refusal in cross-1, the duplicate after it in cross-3 -> the first alone
  if cell precb; then
    xd_zero_sha "$d/cross-1.md"
    xfinding "$d/cross-3.md" F-dupB "1, 3" || { WHY="precb: the seed did not apply"; return 1; }
    run_merge "$sd" "$d"; xd_row precb "rc=2 n=1 tails=cross-1  written=n" "rc=$RC n=$(nref "$MO") tails=$(xd_tails) written=$(xd_w "$o")"
    rm -f "$o"; cs_reset "$d" "$c"
  fi
  # one shard, two lines: cross-2's duplicate, then cross-2's own later verdict-backing refusal
  if cell same; then
    xfinding "$d/cross-2.md" F-dupA "1, 2" && xcrit "$d/cross-2.md" || { WHY="same: the seed did not apply"; return 1; }
    run_merge "$sd" "$d"; xd_row same "rc=2 n=2 tails=cross-2 cross-2  first=dup written=n" "rc=$RC n=$(nref "$MO") tails=$(xd_tails) first=$(xd_first) written=$(xd_w "$o")"
    rm -f "$o"; cs_reset "$d" "$c"
  fi
  [ -z "$WHY" ]
}
X_ALL="x_k8 x_only x_mix x_unknown x_owner x_actable x_horun x_k2 x_seat x_dupall"
# ------------------------------------------------------- gate-1 hand-overs (--gate code-review)
# A code-review part shard replays its own part's mutation-REDs and hands over only what its own
# worktree cannot bring to GREEN; the execution owner (cross-1) runs the hand-overs. The grammar
# and the join are the QA ones, read under both gates. Seeded as code-reviewer.md tells each
# writer to emit them: the hand-over under `### Important` in a part shard, the replays inside
# cross-1's `## Findings`, the part's `handovers: <n>` beside `reviewed-sha:`.
# crs <dir> <key> <verdict> <cite> <handovers count | OMIT | -> [text inside ### Important]
crs() {
  local d="$1" k="$2" v="$3" cite="$4" hc="$5" body="${6:-}"
  {
    printf '# Code Review shard %s\n\nreviewed-sha: %s\nshard-verdict: %s\n' "$k" "${SHARD_SHA:-$B_SHA}" "$v"; adv_l
    case "$hc" in OMIT|-) ;; *) printf 'handovers: %s\n' "$hc" ;; esac
    printf '\n## Summary\nShard %s read its part. CONSERVE-%s-7f3a\n\n' "$k" "$k"
    # The finding's container follows the verdict, as shard()'s does (BL-740).
    printf '## Findings\n\n### Critical (must fix before merge)\n\n'
    [ "$v" = APPROVED ] || shard_find "$k" "$cite"
    printf '### Important (should fix, can be follow-up)\n\n'
    [ "$v" != APPROVED ] || shard_find "$k" "$cite"
    printf '%s\n\n### Suggestions (optional improvements)\n' "$body"
  } > "$d/$k.md"
}
crho() { printf '#### F-%s-H %s replay cannot reach a GREEN baseline in the part worktree\nparts: %s\nhandover: %s\n\nThe documented setup fails in a fresh worktree.' "$1" "$2" "$1" "$2"; }
crrun() { printf '#### F-cross-H hand-over replays\nparts: %s\n' "$1"; shift; for _r in "$@"; do printf 'handover-run: %s\n' "$_r"; done; printf '\nRan in the frozen worktree after setup.'; }
QT_HO_RUN2="hand-over '2 AC7' has more than one 'handover-run:' line in cross-1.md"
p_cr_ho_ok() { # G1: parts 1 and 2 each hand over a DISJOINT replay; cross-1 runs both exactly once
  # -> merges APPROVED with both tabled; the same world with AC7 GREEN-SURVIVED merges NEEDS_REWORK.
  local sd="$1" d o r
  for r in RED GREEN-SURVIVED; do
    d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
    crs "$d" 1 APPROVED 1 1 "$(crho 1 AC3)"; crs "$d" 2 APPROVED 2 1 "$(crho 2 AC7)"
    crs "$d" cross-1 APPROVED "1, 2" - "$(crrun '1, 2' '1 AC3 RED' "2 AC7 $r")"
    o="$(out_of "$d")"; run_merge "$sd" "$d"
    if [ "$r" = RED ]; then
      [ "$RC" -eq 0 ] && has "$MO" "verdict=APPROVED " && [ "$(check1_value "$o")" = APPROVED ] \
        && has "$o" "| 1 | AC3 | RED |" && has "$o" "| 2 | AC7 | RED |" || return 1
    else
      [ "$RC" -eq 0 ] && has "$MO" "verdict=NEEDS_REWORK " && [ "$(check1_value "$o")" = NEEDS_REWORK ] || return 1
    fi
  done
}
p_cr_ho_block() { # G2: every shard BLOCKED (every wrong rule agrees), an unmet replay -> stays BLOCKED
  local sd="$1" d o
  d="$(world4 "$sd" BLOCKED BLOCKED BLOCKED BLOCKED)" || return 1
  crs "$d" 2 BLOCKED 2 1 "$(crho 2 AC7)"
  crs "$d" cross-1 BLOCKED "1, 2" - "$(crrun 2 '2 AC7 NO-BASELINE')"
  o="$(out_of "$d")"; run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "verdict=BLOCKED " && [ "$(check1_value "$o")" = BLOCKED ]
}
p_cr_ho_unm() { # G3: part 2's hand-over run by no shard -> REFUSED, nothing written
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  crs "$d" 2 APPROVED 2 1 "$(crho 2 AC7)"; run_merge "$1" "$d"; refused_clean "$QT_HO_UNM" "$d"; }
p_cr_ho_runtwice() { # G4: one hand-over replayed twice by cross-1, in two findings -> REFUSED
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  crs "$d" 2 APPROVED 2 1 "$(crho 2 AC7)"
  crs "$d" cross-1 APPROVED "1, 2" - "$(printf '%s\n\n%s' "$(crrun 2 '2 AC7 RED')" "$(crrun 2 '2 AC7 RED' | sed 's/F-cross-H/F-cross-H2/')")"
  [ "$(grep -c '^handover-run: 2 AC7 RED$' "$d/cross-1.md")" = 2 ] || return 1
  run_merge "$1" "$d"; refused_clean "$QT_HO_RUN2" "$d"; }
p_cr_hc_missing() { # G5: a code-review part shard without its declared count -> REFUSED
  local d; d="$(world4 "$1" APPROVED APPROVED APPROVED APPROVED)" || return 1
  crs "$d" 2 APPROVED 2 OMIT; ! grep -q '^handovers:' "$d/2.md" || return 1
  run_merge "$1" "$d"; refused_clean "$QT_HC_MISSING" "$d"; }
C_ALL="cr_ho_ok cr_ho_block cr_ho_unm cr_ho_runtwice cr_hc_missing"
Q_ALL="q_worst q_table q_title q_fenced q_part_ac q_part_def q_cross_noac q_cross_twoac q_cross_twodef q_nodef q_rank q_pm q_suffix q_gate q_vset q_secvar q_ho_ok q_ho_unm q_ho_orph q_ho_force q_ho_cross q_ho_prun q_ho_fenced q_ho_shape q_ho_multi q_ho_twoline q_ho_dup q_ho_deco q_ho_nocolon q_ho_prose q_ho_acid q_hc_dash q_hc_hidden q_hc_zero q_hc_missing q_hc_two q_hc_nonint q_hc_cross q_hc_none q_ho_widen"

# ===================================================================== BL-737: the shard pre-check,
# owner tails, the marker key, the content seal on review shards, and the legacy rule. Every predicate
# below sets WHY to what it saw when it fails; each takes the SCRIPT DIRECTORY so a mutant copy drives it.
#
# THE ROWS ARE THE RECORDER'S. fire() hands the SHIPPED PostToolUse hook a payload exactly as the harness
# would -- `agent_id` present for a dispatched seat, absent for the top-level session -- with
# CLAUDE_PROJECT_DIR the main checkout, and fails unless the hook APPENDED a row: a silent hook must never
# let a "no row" refusal pass for the wrong reason.
fire() { # <file> <agent|session> [tool] [project root] -> 0 when the recorder appended a row
  local f="$1" who="$2" tool="${3:-Write}" root="${4:-$MAIN}" l n0 n1 pl
  l="$root/_bmad-output/planning-artifacts/.artifact-writes.jsonl"
  n0="$(grep -c . "$l" 2>/dev/null)" || n0=0
  pl="$(jq -nc --arg t "$tool" --arg fp "$f" --arg who "$who" \
    '{tool_name: $t, tool_input: {file_path: $fp}, session_id: "fixture-session", tool_use_id: "toolu_fixture",
      transcript_path: "/dev/null"} + (if $who == "agent" then {agent_id: "a0123456789abcdef", agent_type: "code-reviewer"} else {} end)')" \
    || return 1
  CLAUDE_PROJECT_DIR="$root" bash "$HOOK" <<<"$pl" > /dev/null 2>&1
  n1="$(grep -c . "$l" 2>/dev/null)" || n1=0
  [ "$n1" -gt "$n0" ]
}
# The pre-key= --mark's marker, typed the way the old engine wrote it: `sha=` the body's hash (so
# seal_of reads it sealed), `findings=` the shard's '#### ' count unless given. <n> is `-` for that count.
lmark() { # <file> <n|-> <field words...>
  local f="$1" n="$2" h; shift 2
  h="$(shasum -a 256 < "$f" | cut -d' ' -f1)"
  [ "$n" != - ] || { n="$(grep -c '^#### ' "$f")" || n=0; }
  printf 'seat-complete: implementation code-reviewer %s sha=%s findings=%s\n' "$*" "$h" "$n" >> "$f"
}
lmark_all() { local f; for f in "$1"/*.md; do lmark "$f" - "$(basename "$f" .md)"; done; }
mark_args() { # <script-dir> <args to --mark...> -> MRC, $MKO
  local sd="$1"; shift
  AI_DLC_PROJECT_ROOT="$PROJ" bash "$sd/wait-for-deliverable.sh" --mark "$@" > "$MKO" 2>&1 < /dev/null; MRC=$?
}
seal_mark() { # <script-dir> <file> <seat>: the seat's own close, `<shard>` the file's key
  local k n; k="$(basename "$2" .md)"; n="$(grep -c '^#### ' "$2")" || n=0
  mark_args "$1" "$2" implementation "$3" "$k" "findings=$n"
}
# seal_world <script-dir> <code-review|qa> -> a shard dir whose every shard its seat wrote (one recorder
# row each) and closed with the real --mark. Run under WROOT to build it in another tree.
seal_world() {
  local sd="$1" g="$2" d f seat=code-reviewer
  if [ "$g" = qa ]; then d="$(qworld "$sd" PASS PASS PASS PASS)" || return 1; seat=qa
  else d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1; fi
  for f in "$d"/*.md; do
    fire "$f" agent || { echo "the recorder wrote no row for $f" > "$MKO"; return 1; }
    seal_mark "$sd" "$f" "$seat"; [ "$MRC" -eq 0 ] || return 1
  done
  printf '%s' "$d"
}
alias_of() { printf '%s' "$ALIAS${1#"$MAIN/docs"}"; }
reline() { grep '^REFUSED:' "$1"; }
nref() { local n; n="$(grep -c '^REFUSED:' "$1")" || n=0; printf '%s' "$n"; }
owner_in() { # <output file> <want>: exactly one REFUSED line, ending in [owner: <want>]
  local l; [ "$(nref "$1")" = 1 ] || return 1; l="$(reline "$1")"
  case "$l" in *" [owner: $2]") return 0 ;; esac; return 1
}
run_check() { # <script-dir> <shard-dir> <gate> <target> [--findings n] -> CRC, $CO; driven through the alias
  local sd="$1" d="$2" g="$3" t="$4"; shift 4
  AI_DLC_PROJECT_ROOT="${VB_PROJ:-$PROJ}" bash "$sd/merge-review-shards.sh" "$(alias_of "$d")" --gate "$g" \
    --check-shard "$(alias_of "$t")" "$@" > "$CO" 2>&1 < /dev/null; CRC=$?
}
cs_reset() { rm -f "$1"/*.md "$1/notes.txt"; cp "$2"/*.md "$1"/; }

# ---- CS1: --check-shard IS the merge's per-shard code. One defect per world, in a shard that is not
# the first read; the full merge and --check-shard each print exactly one REFUSED line, and they are
# byte-equal. The check is driven through ALIAS, so the shared line naming the PHYSICAL path is the
# resolution's proof. Each csc_* seeds one class into $CSD and names its target in CS_T.
csc_two_sha() { CS_T=2; shard "$CSD" 2 APPROVED 2 "" "reviewed-sha: $B_BASE"; }
csc_sha_rev() { CS_T=2; shard "$CSD" 2 APPROVED 2 "$B_BASE"; }
csc_bad_verdict() { CS_T=2; shard "$CSD" 2 PASS 2; }
csc_nofind() { CS_T=2; raw_shard "$CSD" 2 '## Summary' 'Nothing to report.'; }
csc_stray() { CS_T=2; raw_shard "$CSD" 2 '## Findings' '' '### Critical (must fix before merge)' '' '- **C-1** an issue' '  parts: 2'; }
csc_partcite() { CS_T=2; shard "$CSD" 2 APPROVED 3; }
csc_crossone() { CS_T=cross-2; shard "$CSD" cross-2 APPROVED 2; }
csc_noparts() { CS_T=2; raw_shard "$CSD" 2 '## Findings' '' '### Critical (must fix before merge)' '' \
  '#### F-2-1 cited' 'parts: 2' '' '#### F-2-2 uncited' '' 'Body.'; }
csc_outrange() { CS_T=cross-2; shard "$CSD" cross-2 APPROVED "1, 9"; }
csc_hc_missing() { CS_T=2; crs "$CSD" 2 APPROVED 2 OMIT; }
csc_hc_nonint() { CS_T=2; crs "$CSD" 2 APPROVED 2 x; }
csc_hc_mismatch() { CS_T=2; crs "$CSD" 2 APPROVED 2 1; }
csc_hc_cross() { CS_T=cross-2; shard "$CSD" cross-2 APPROVED "1, 3" "handovers: 0"; }
csc_malformed() { CS_T=2; crs "$CSD" 2 APPROVED 2 0 "$(printf '#### F-2-H AC7 cannot reach GREEN\nparts: 2\n**handover:** AC7\n\nBody.')"; }
csc_ho_cross() { CS_T=cross-1; crs "$CSD" cross-1 APPROVED "1, 2" - "$(printf '#### F-c-H AC8 cannot be replayed\nparts: 1, 3\nhandover: AC8\n\nBody.')"; }
csc_ho_multi() { CS_T=2; crs "$CSD" 2 APPROVED 2 1 "$(printf '#### F-2-H AC7 and AC8\nparts: 2\nhandover: AC7 AC8\n\nBody.')"; }
csc_hr_part() { CS_T=3; crs "$CSD" 3 APPROVED 3 0 "$(printf '#### F-3-H ran AC7\nparts: 3\nhandover-run: 3 AC7 RED\n\nBody.')"; }
csc_hr_cross2() { CS_T=cross-2; crs "$CSD" cross-2 APPROVED "1, 3" - "$(crrun 2 '2 AC7 RED')"; }
# The marker classes: every other shard carries a legacy marker the old engine at B's frozen sha
# accepts, so the full merge prints LEGACY lines before it reaches the target; only REFUSED lines compare.
csc_mk_count() { CS_T=2; lmark_all "$CSD"; shard "$CSD" 2 APPROVED 2; lmark "$CSD/2.md" 3 2; }
csc_mk_key() { CS_T=2; lmark_all "$CSD"; shard "$CSD" 2 APPROVED 2; lmark "$CSD/2.md" - 2 key=3; }
csc_mk_field() { CS_T=2; lmark_all "$CSD"; shard "$CSD" 2 APPROVED 2; lmark "$CSD/2.md" - 1/3 key=2; }
csc_mk_twokey() { CS_T=2; lmark_all "$CSD"; shard "$CSD" 2 APPROVED 2; lmark "$CSD/2.md" - 2 key=2 key=2; }
# The content seal: a seat's Write (a recorder row), then a Bash rewrite.
csc_seal() { fire "$CSD/2.md" agent || return 1
  sed -i.bak -e 's/^## Summary$/## Overview/' "$CSD/2.md" && rm -f "$CSD/2.md.bak" && grep -q '^## Overview$' "$CSD/2.md" || return 1
  CS_T=2; CS_TOK="changed after its last sealed write"; }
# --gate qa. The second instance's own seed: a part seat's `## Deferred live check (not scored here)`.
csq_part_ac() { CS_T=2; qshard "$CSD" 2 PASS 2 "$(printf '## Acceptance Criteria\n\n| AC | Verdict |\n|---|---|\n| AC1 | PASS |')"; }
csq_graph_deferred() { CS_T=2; CS_TOK="(part shard 2) carries a '## Deferred ACs' section"
  qshard "$CSD" 2 PASS 2 "$(printf '## Deferred live check (not scored here)\n\nThe live check runs at deploy.')"; }
csq_cross_noac() { CS_T=cross-1; awk '/^## Acceptance Criteria$/ { print "## Per-AC results"; next } { print }' "$CSD/cross-1.md" > "$CSD/x.tmp" \
  && mv "$CSD/x.tmp" "$CSD/cross-1.md"; }
csq_cross_twodef() { CS_T=cross-1; qshard "$CSD" cross-1 PASS "1, 2" "$(printf '\n## Deferred ACs\n\n- AC5: deferred')"; }
csq_cross2_ac() { CS_T=cross-2; qshard "$CSD" cross-2 PASS "1, 3" "$(printf '## Acceptance Criteria\n\n| AC | Verdict |\n|---|---|\n| AC9 | PASS |')"; }
csq_rank() { CS_T=2; qshard "$CSD" 2 APPROVED 2; }
# BL-790: a shard with no advisor: line, over REPO_B (no role file at the frozen sha, so held).
csc_adv_absent() { CS_T=2; CS_TOK="carries no column-0 'advisor:' line"; SHARD_ADV="" shard "$CSD" 2 APPROVED 2; }
csq_adv_absent() { CS_T=2; CS_TOK="carries no column-0 'advisor:' line"; SHARD_ADV="" qshard "$CSD" 2 PASS 2; }
CS_CR="two_sha sha_rev bad_verdict nofind stray partcite crossone noparts outrange hc_missing hc_nonint hc_mismatch hc_cross malformed ho_cross ho_multi hr_part hr_cross2 mk_count mk_key mk_field mk_twokey seal adv_absent"
CS_QA="part_ac graph_deferred cross_noac cross_twodef cross2_ac rank adv_absent"
CS_N="$(printf '%s\n' $CS_CR $CS_QA | grep -c .)"
cs_same() { # <script-dir> <shard-dir> <gate> <target>
  local sd="$1" d="$2" g="$3" t="$4" o
  if [ "$g" = qa ]; then o="$(qout "$d")"; else o="$(out_of "$d")"; fi
  run_mg "$sd" "$d" "$g" "$o"
  run_check "$sd" "$d" "$g" "$t"
  CS_LAST="merge rc=$RC [$(reline "$MO")] check rc=$CRC [$(reline "$CO")]"
  [ "$RC" -eq 2 ] && [ "$CRC" -eq 2 ] && [ "$(nref "$MO")" = 1 ] && [ "$(nref "$CO")" = 1 ] \
    && [ "$(reline "$MO")" = "$(reline "$CO")" ] && ! has "$CO" "SHARD-OK:" && [ ! -e "$o" ] && has "$CO" "$t" \
    && { [ -z "$CS_TOK" ] || has "$CO" "$CS_TOK"; }
}
cs_run() { # <script-dir> <gate> <seeder> <clean copy>
  # A seeder's exit is not its verdict (the shard writers end in a conditional printf); CS_T is: every
  # seeder names its target only once its seed is written, and the seal seeder only once it applied.
  CS_T=""; CS_TOK=""
  "$3"
  if [ -n "$CS_T" ] && [ -f "$CSD/$CS_T.md" ]; then
    cs_same "$1" "$CSD" "$2" "$CSD/$CS_T.md" || WHY="$WHY ${3}{$CS_LAST}"
  else WHY="$WHY ${3}{the seed did not apply}"; fi
  cs_reset "$CSD" "$4"
}
cs_sel() { [ -z "${CS_ONLY:-}" ] || [ "$1" = "$CS_ONLY" ]; }
# cell <name>: 0 when this cell runs (no CS_ONLY, or CS_ONLY names it), counting it in CS_RAN. Every
# predicate a mutant drives gates each of its cells on it (BL-755), so a mutant runs the one cell its
# kill token names and nothing else; run.sh's mut_run asserts exactly one cell ran.
cell() { cs_sel "$1" || return 1; CS_RAN=$(( ${CS_RAN:-0} + 1 )); }
p_cs() {
  local sd="$1" c n any=0
  WHY=""
  CSD="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || { WHY="the code-review world was not built"; return 1; }
  c="$(dirname "$CSD")/clean"; mkdir "$c" && cp "$CSD"/*.md "$c"/ || return 1
  run_check "$sd" "$CSD" code-review "$CSD/1.md"
  [ "$CRC" -eq 0 ] && [ "$(cat "$CO")" = "SHARD-OK: $CSD/1.md findings=1" ] \
    || { WHY="control: a clean shard answered rc=$CRC [$(head -1 "$CO")]"; return 1; }
  for n in $CS_CR; do cell "$n" || continue; any=1; cs_run "$sd" code-review "csc_$n" "$c"; done
  for n in $CS_QA; do cell "$n" || continue; any=1
    if [ -z "${CS_QD:-}" ]; then
      CSD="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="$WHY the qa world was not built"; return 1; }
      CS_QD=1; c="$(dirname "$CSD")/clean"; mkdir "$c" && cp "$CSD"/*.md "$c"/ || return 1
    fi
    cs_run "$sd" qa "csq_$n" "$c"
  done
  CS_QD=""
  [ "$any" = 1 ] && [ -z "$WHY" ]
}

# ---- CP1: the seal reader the merge copies (it cannot source wait-for-deliverable.sh, which executes on
# load) is byte-identical to wait-for-deliverable.sh's, each function extracted by NAME from both.
fn_body() { awk -v n="$2" 'index($0, n "() {") == 1 { p = 1 } p { print } p && /^}$/ { exit }' "$1"; }
p_copies() {
  local m="$1/merge-review-shards.sh" w="$1/wait-for-deliverable.sh" fn a nl drift="$WORK/drift-merge.sh"
  WHY=""
  for fn in has_marker content_hash seal_body seal_of; do
    a="$(fn_body "$m" "$fn")"; nl="$(printf '%s\n' "$a" | grep -c .)" || nl=0
    [ "$nl" -ge 3 ] && [ "$a" = "$(fn_body "$w" "$fn")" ] || WHY="$WHY $fn($nl lines, differs)"
  done
  [ "$(grep -cxF 'MARK_TOKEN="seat-complete: "' "$m")" = 1 ] && [ "$(grep -cxF 'MARK_TOKEN="seat-complete: "' "$w")" = 1 ] \
    || WHY="$WHY MARK_TOKEN"
  # The control: one byte drifted inside the merge's seal_body is seen by the same extraction.
  sed -e 's/k == 1/k == 2/' "$m" > "$drift"
  if cmp -s "$m" "$drift"; then WHY="$WHY control(the drift did not apply)"
  elif [ "$(fn_body "$drift" seal_body)" = "$(fn_body "$w" seal_body)" ]; then WHY="$WHY control(a one-byte drift was not seen)"; fi
  # content-seal.sh's seal_review_body hashes the bytes --mark's seal_body binds: its BODY (the lines
  # after the name line, so the two names may differ) is byte-identical, with the same one-byte control.
  local c="$1/content-seal.sh" cdrift="$WORK/drift-seal.sh" cb
  cb="$(fn_body "$c" seal_review_body | sed 1d)"; nl="$(printf '%s\n' "$cb" | grep -c .)" || nl=0
  [ "$nl" -ge 2 ] && [ "$cb" = "$(fn_body "$w" seal_body | sed 1d)" ] || WHY="$WHY seal_review_body($nl lines, differs from seal_body)"
  sed -e 's/k == 1/k == 2/' "$c" > "$cdrift"
  if cmp -s "$c" "$cdrift"; then WHY="$WHY control-seal(the drift did not apply)"
  elif [ "$(fn_body "$cdrift" seal_review_body | sed 1d)" = "$(fn_body "$w" seal_body | sed 1d)" ]; then WHY="$WHY control-seal(a one-byte drift was not seen)"; fi
  [ -z "$WHY" ]
}

# ---- OT1: the owner tail of every refusal family names the shard whose FILE must change.
own_case() { owner_in "${3:-$MO}" "$2" || WHY="$WHY $1{want [owner: $2], got $(reline "${3:-$MO}")}"; }
p_owner() {
  local sd="$1" d c o SHARD_SHA
  WHY=""
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || { WHY="the world was not built"; return 1; }
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || return 1
  if cell per-shard; then shard "$d" 2 APPROVED 3; run_merge "$sd" "$d"; own_case per-shard 2; cs_reset "$d" "$c"; fi
  if cell missing; then rm -f "$d/2.md"; run_merge "$sd" "$d"; own_case missing 2; cs_reset "$d" "$c"; fi
  if cell unfinished; then lmark_all "$d"; shard "$d" 2 APPROVED 2; run_merge "$sd" "$d"; own_case unfinished 2; cs_reset "$d" "$c"; fi
  if cell dup-key; then cp "$d/1.md" "$d/01.md"; run_merge "$sd" "$d"; own_case dup-key "01.md 1.md"; cs_reset "$d" "$c"; fi
  if cell handover-unrun; then crs "$d" 2 APPROVED 2 1 "$(crho 2 AC7)"; run_merge "$sd" "$d"; own_case handover-unrun "2 cross-1"; cs_reset "$d" "$c"; fi
  if cell run-orphan; then crs "$d" cross-1 APPROVED "1, 2" - "$(crrun 2 '2 AC7 RED')"; run_merge "$sd" "$d"; own_case run-orphan "2 cross-1"; cs_reset "$d" "$c"; fi
  if cell handover-twice; then
    crs "$d" 2 APPROVED 2 2 "$(printf '%s\n\n%s' "$(crho 2 AC7)" "$(crho 2 AC7 | sed 's/F-2-H/F-2-H2/')")"
    crs "$d" cross-1 APPROVED "1, 2" - "$(crrun 2 '2 AC7 RED')"; run_merge "$sd" "$d"; own_case handover-twice 2; cs_reset "$d" "$c"
  fi
  if cell run-twice; then
    crs "$d" 2 APPROVED 2 1 "$(crho 2 AC7)"
    crs "$d" cross-1 APPROVED "1, 2" - "$(printf '%s\n\n%s' "$(crrun 2 '2 AC7 RED')" "$(crrun 2 '2 AC7 RED' | sed 's/F-cross-H/F-cross-H2/')")"
    run_merge "$sd" "$d"; own_case run-twice cross-1; cs_reset "$d" "$c"
  fi
  if cell check1-multi; then shard "$d" 2 APPROVED 2 "" "$(printf '## Verdict\nAPPROVED')"; run_merge "$sd" "$d"; own_case check1-multi 2; cs_reset "$d" "$c"; fi
  if cell bad-name; then printf 'x\n' > "$d/notes.txt"; run_merge "$sd" "$d"; own_case bad-name lead; cs_reset "$d" "$c"; fi
  if cell set-level; then o="$(qout "$d" code-review -p2)"; run_mg "$sd" "$d" code-review "$o"; own_case set-level lead; fi
  # The owner duplicate, K=8: cross-3 and its owner cross-1 report the identical set -> the NON-owner.
  # Under --check-shard the owner is read only once it is finished and sealed: unmarked, cross-3 passes.
  # The two --check-shard cells read the state the cell before them left, so selecting one runs its
  # prerequisite steps without counting them as cells.
  if cs_sel dup-merge || cs_sel dup-check-owner-unsealed || cs_sel dup-check-owner-sealed; then
    SHARD_SHA="$E_SHA"
    d="$(kworld "$sd" "$REPO_E" "$E_BASE" "$E_SHA" 8 code-review APPROVED)" || { WHY="$WHY the K=8 world was not built"; return 1; }
    xfinding "$d/cross-3.md" F-dup "1, 2" && xfinding "$d/cross-1.md" F-own "1, 2" || return 1
    if cell dup-merge; then run_merge "$sd" "$d"; own_case dup-merge cross-3; fi
    if cell dup-check-owner-unsealed; then
      run_check "$sd" "$d" code-review "$d/cross-3.md"
      [ "$CRC" -eq 0 ] && has "$CO" "SHARD-OK: $d/cross-3.md" || WHY="$WHY dup-check-owner-unsealed{rc=$CRC $(head -1 "$CO")}"
    fi
    if cell dup-check-owner-sealed; then
      lmark "$d/cross-1.md" - cross-1 key=cross-1
      run_check "$sd" "$d" code-review "$d/cross-3.md"; own_case dup-check-owner-sealed cross-3 "$CO"
    fi
  fi
  [ -z "$WHY" ]
}

# ---- KY1: the marker's key=. A set every seat wrote and --mark closed merges, each marker keyed by its
# own file name; the same set with one marker's key= (then its <shard> field) naming another key refuses.
p_key() {
  local sd="$1" d f k o
  WHY=""
  d="$(seal_world "$sd" code-review)" || { WHY="the sealed world was not built: $(head -2 "$MKO")"; return 1; }
  o="$(out_of "$d")"; run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && ! has "$MO" "LEGACY:" || { WHY="the seat-sealed set did not merge: $(head -2 "$MO")"; return 1; }
  for f in "$d"/*.md; do k="$(basename "$f" .md)"
    grep -qE "^seat-complete: implementation code-reviewer $k key=$k sha=[0-9a-f]{64} findings=1\$" "$f" \
      || { WHY="$f does not end in a marker keyed $k: $(tail -1 "$f")"; return 1; }
  done
  rm -f "$o"
  awk '{ sub(/ 2 key=2 sha=/, " 2 key=3 sha=") } { print }' "$d/2.md" > "$d/2.tmp" && mv "$d/2.tmp" "$d/2.md"
  run_merge "$sd" "$d"
  refused_clean "carries key=3, not this shard's key 2" "$d" && owner_in "$MO" 2 || WHY="$WHY key=3{$(head -1 "$MO")}"
  awk '{ sub(/ code-reviewer 2 key=3 /, " code-reviewer 1/3 key=2 ") } { print }' "$d/2.md" > "$d/2.tmp" && mv "$d/2.tmp" "$d/2.md"
  run_merge "$sd" "$d"
  refused_clean "names shard '1/3', not this shard's key 2" "$d" && owner_in "$MO" 2 || WHY="$WHY field-1/3{$(head -1 "$MO")}"
  [ -z "$WHY" ]
}

# ---- MK1: --mark on a review shard refuses a <shard> that is not the file's key, a caller key= or
# sha= word, and a findings count the merge's check refuses -- each exit 64, the file byte-unchanged --
# and the ALLOW twin, same file, same row, marks it keyed by its own name.
mark_refused() { [ "$MRC" -eq 64 ] && has "$MKO" "$1" && has "$MKO" "Nothing was written." && cmp -s "$2" "$3"; }
p_mark() {
  local sd="$1" d f s
  WHY=""
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || { WHY="the world was not built"; return 1; }
  f="$d/2.md"; s="$(dirname "$d")/2.snap"
  fire "$f" agent || { WHY="the recorder wrote no row for $f"; return 1; }
  cp "$f" "$s" || return 1
  if cell shard-3; then mark_args "$sd" "$f" implementation code-reviewer 3 findings=1
    mark_refused "the <shard> field '3' is not this file's key, 2" "$s" "$f" || WHY="$WHY shard-3{rc=$MRC $(head -1 "$MKO")}"; fi
  if cell caller-key; then mark_args "$sd" "$f" implementation code-reviewer 2 key=2 findings=1
    mark_refused "carries key= or sha=" "$s" "$f" || WHY="$WHY caller-key{rc=$MRC $(head -1 "$MKO")}"; fi
  if cell caller-sha; then mark_args "$sd" "$f" implementation code-reviewer 2 sha=0123abcd findings=1
    mark_refused "carries key= or sha=" "$s" "$f" || WHY="$WHY caller-sha{rc=$MRC $(head -1 "$MKO")}"; fi
  if cell findings-3; then mark_args "$sd" "$f" implementation code-reviewer 2 findings=3
    mark_refused "findings=3' but its ## Findings section heads 1 finding(s)" "$s" "$f" || WHY="$WHY findings-3{rc=$MRC $(head -3 "$MKO")}"; fi
  if cell allow; then mark_args "$sd" "$f" implementation code-reviewer 2 findings=1
    [ "$MRC" -eq 0 ] && grep -qE '^seat-complete: implementation code-reviewer 2 key=2 sha=[0-9a-f]{64} findings=1$' "$f" \
      || WHY="$WHY allow{rc=$MRC $(head -2 "$MKO")}"; fi
  [ -z "$WHY" ]
}

# ---- SE1: the second instance's lead path. A part shard its seat wrote and marked reads SEAL-OK (the
# control); rewritten through Bash (`sed -i` on a heading) and re-marked, --mark refuses (64), naming
# the re-dispatch remedy, with the file byte-unchanged.
p_seal_rewrite() {
  local sd="$1" d f s
  WHY=""
  # One cell: every step below reads the state the step before it left.
  cell seal-rewrite || return 0
  d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="the qa world was not built"; return 1; }
  f="$d/2.md"; s="$(dirname "$d")/2.snap"
  fire "$f" agent || { WHY="the recorder wrote no row for $f"; return 1; }
  mark_args "$sd" "$f" implementation qa 2 findings=1
  [ "$MRC" -eq 0 ] || { WHY="the seat's own --mark failed: $(head -2 "$MKO")"; return 1; }
  grep -qE '^seat-complete: implementation qa 2 key=2 sha=' "$f" \
    || { WHY="the seat's --mark did not take the review-shard branch (its marker carries no key=): $(tail -1 "$f")"; return 1; }
  bash "$sd/content-seal.sh" --review-shard "$f" > "$CO" 2>&1 < /dev/null; CRC=$?
  [ "$CRC" -eq 0 ] && has "$CO" "SEAL-OK:" || { WHY="control: the seat's own seal did not read SEAL-OK (rc=$CRC $(head -1 "$CO"))"; return 1; }
  sed -i.bak -e 's/^## Summary$/## Overview/' "$f" && rm -f "$f.bak" && grep -q '^## Overview$' "$f" \
    || { WHY="the in-place sed rewrite did not apply"; return 1; }
  cp "$f" "$s" || return 1
  mark_args "$sd" "$f" implementation qa 2 findings=1
  mark_refused "SEAL-REFUSED:" "$s" "$f" && has "$MKO" "re-dispatch the reviewer for that shard" \
    || { WHY="the Bash-rewritten shard was re-marked: rc=$MRC $(head -2 "$MKO")"; return 1; }
}

# ---- SE2: a shard whose last TOOL row is the top-level session's (a lead Edit) is refused at the merge.
# The control is the same set before that row; the ALLOW twin, one property apart, is an agent Edit after it.
p_session() {
  local sd="$1" d o
  WHY=""
  d="$(seal_world "$sd" code-review)" || { WHY="the sealed world was not built: $(head -2 "$MKO")"; return 1; }
  o="$(out_of "$d")"; run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" || { WHY="control: the seat-sealed set did not merge: $(head -2 "$MO")"; return 1; }
  rm -f "$o"
  fire "$d/2.md" session Edit || { WHY="the recorder wrote no session row"; return 1; }
  run_merge "$sd" "$d"
  refused_clean "was last written by the top-level session" "$d" && owner_in "$MO" 2 || { WHY="a session-last shard: $(head -1 "$MO")"; return 1; }
  fire "$d/2.md" agent Edit || { WHY="the recorder wrote no agent row"; return 1; }
  run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" || { WHY="allow: an agent Edit after the session's did not merge: $(head -1 "$MO")"; return 1; }
}

# ---- LG1: the legacy rule. Over B's frozen sha (the engine without the sentinel), a set of legacy
# markers merges and prints the exact LEGACY line naming the full sha -- one shard a seat's Write then the
# old Bash append, which body_sha accepts. The same Write then a sed rewrite is refused. The sentinel
# engine at the frozen sha refuses, and an engine in neither layout refuses.
p_legacy() {
  local sd="$1" d n SHARD_SHA
  WHY=""
  if cell old-engine; then
    d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || { WHY="the world was not built"; return 1; }
    fire "$d/2.md" agent || { WHY="the recorder wrote no row"; return 1; }
    lmark_all "$d"; run_merge "$sd" "$d"
    n="$(grep -c '^LEGACY: ' "$MO")" || n=0
    [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ "$n" = 6 ] \
      && grep -qxF "LEGACY: $d/1.md accepted without key= only because reviewed sha $B_SHA predates the key= engine" "$MO" \
      && grep -qxF "LEGACY: $d/2.md accepted without key= only because reviewed sha $B_SHA predates the key= engine" "$MO" \
      || { WHY="old engine: rc=$RC, $n LEGACY line(s): $(grep -v '^LEGACY: ' "$MO" | head -1)"; return 1; }
  fi
  if cell rewrite; then
    d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || return 1
    fire "$d/2.md" agent || { WHY="the recorder wrote no row"; return 1; }
    sed -i.bak -e 's/^## Summary$/## Overview/' "$d/2.md" && rm -f "$d/2.md.bak" || return 1
    lmark_all "$d"; run_merge "$sd" "$d"
    refused_clean "changed after its last sealed write" "$d" && owner_in "$MO" 2 || WHY="$WHY rewrite{$(head -1 "$MO")}"
  fi
  if cell sentinel; then
    SHARD_SHA="$S_SHA"
    d="$(kworld "$sd" "$REPO_S" "$S_BASE" "$S_SHA" 3 code-review APPROVED)" || { WHY="$WHY the sentinel world was not built"; return 1; }
    lmark_all "$d"; run_merge "$sd" "$d"
    refused_clean "the frozen sha $S_SHA's core/scripts/wait-for-deliverable.sh is the key= engine" "$d" || WHY="$WHY sentinel{$(head -1 "$MO")}"
  fi
  if cell absent; then
    SHARD_SHA="$N_SHA"
    d="$(kworld "$sd" "$REPO_N" "$N_BASE" "$N_SHA" 3 code-review APPROVED)" || { WHY="$WHY the engine-absent world was not built"; return 1; }
    lmark_all "$d"; run_merge "$sd" "$d"
    refused_clean "cannot be read at the frozen sha $N_SHA" "$d" || WHY="$WHY absent{$(head -1 "$MO")}"
  fi
  [ -z "$WHY" ]
}

# ---- LY1: from a LINKED worktree the ledger is the MAIN checkout's, in both layouts: the reader in a
# consumer-layout tree (scripts/ai-dlc/) and in a distribution-layout tree (core/scripts/) each name
# <main>/_bmad-output/... for a shard in its linked worktree, never the worktree's own stale copy
# (seeded as a decoy holding a matching row). The recorder fired from the linked worktree writes into
# MAIN's ledger, both readers then read SEAL-OK, and a set sealed there merges.
lay_one() { # <main> <linked worktree> <reader>
  local d f rel
  mkdir -p "$2/docs/reviews" && d="$(mktemp -d "$2/docs/reviews/s9.XXXXXX")/shards/1-code-review-$B_SHA12" && mkdir -p "$d" || return 1
  f="$d/1.md"; printf '# shard\n\nreviewed-sha: %s\n' "$B_SHA" > "$f"; rel="${f#"$2"/}"
  mkdir -p "$2/_bmad-output/planning-artifacts" || return 1
  jq -nc --arg p "$rel" --arg r "$2" --arg s "$(shasum -a 256 < "$f" | cut -d' ' -f1)" \
    '{v: 1, kind: "content-seal", ts: "2000-01-01T00:00:00Z", path: $p, actor: "agent", agent_id: "a0123456789abcdef", root: $r, sha256: $s}' \
    >> "$2/_bmad-output/planning-artifacts/.artifact-writes.jsonl" || return 1
  bash "$3" --review-shard "$f" > "$CO" 2>&1 < /dev/null; CRC=$?
  LAY_F="$f"
  [ "$CRC" -eq 1 ] && has "$CO" "carries no content-seal row in $1/_bmad-output/planning-artifacts/.artifact-writes.jsonl" \
    && ! has "$CO" "$2/_bmad-output"
}
p_layouts() {
  local sd="$1" f n d o rd
  WHY=""
  lay_one "$DMAIN" "$DLW" "$DMAIN/core/scripts/content-seal.sh" || WHY="$WHY dist{rc=$CRC $(head -1 "$CO")}"
  lay_one "$MAIN" "$LW" "$MAIN/scripts/ai-dlc/content-seal.sh" || WHY="$WHY consumer{rc=$CRC $(head -1 "$CO")}"
  f="$LAY_F"
  fire "$f" agent || { WHY="$WHY the recorder wrote no row into $LEDGER for $f"; return 1; }
  n="$(jq -c --arg p "${f#"$LW"/}" --arg r "$LW" 'select(.path == $p and .root == $r and has("body_sha"))' "$LEDGER" | grep -c .)" || n=0
  [ "$n" = 1 ] || WHY="$WHY ledger-row{$n rows for the linked worktree's shard in $LEDGER}"
  [ "$(grep -c . "$LW/_bmad-output/planning-artifacts/.artifact-writes.jsonl")" = 1 ] || WHY="$WHY the recorder wrote into the linked worktree's own state dir"
  for rd in "$MAIN/scripts/ai-dlc/content-seal.sh" "$DMAIN/core/scripts/content-seal.sh"; do
    bash "$rd" --review-shard "$f" > "$CO" 2>&1 < /dev/null; CRC=$?
    [ "$CRC" -eq 0 ] && has "$CO" "SEAL-OK:" || WHY="$WHY read-from-$rd{rc=$CRC $(head -1 "$CO")}"
  done
  d="$(WROOT="$LW" seal_world "$sd" code-review)" || { WHY="$WHY the linked-worktree set was not sealed: $(head -2 "$MKO")"; return 1; }
  o="$(out_of "$d")"; run_merge "$sd" "$d"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && ! has "$MO" "LEGACY:" || WHY="$WHY lw-merge{$(head -1 "$MO")}"
  [ -z "$WHY" ]
}

# ---- FT1: a review-shard row written BEFORE a gate part does not move --first-tool-ts (rows carrying
# body_sha are skipped); the control is the same ledger with that row's body_sha deleted, which does.
# Its own tree, so the gate part's row and the review row share one root.
p_first_ts() {
  local sd="$1" ft f p l t1 t2 r
  WHY=""
  ft="$(mktemp -d "$WORK/ft.XXXXXX")" || return 1
  mkdir -p "$ft/scripts/ai-dlc" && G init -q "$ft" && cp "$SEAL_SRC" "$ft/scripts/ai-dlc/content-seal.sh" && [ -d "$ft/.git" ] \
    || { WHY="FIXTURE ERROR: the tree $ft was not built"; return 1; }
  f="$ft/docs/reviews/s1/shards/1-code-review-$B_SHA12/1.md"; mkdir -p "$(dirname "$f")" && printf '# shard\n' > "$f"
  fire "$f" agent Write "$ft" || { WHY="the recorder wrote no review row"; return 1; }
  # The recorder stamps ts with date -u at one-second resolution, so the review row's ts is pinned to a
  # fixed earlier stamp (jq, selected by body_sha) rather than slept past: the real hook still wrote both rows.
  jq -c 'if has("body_sha") then .ts = "2000-01-01T00:00:00Z" else . end' "$ft/_bmad-output/planning-artifacts/.artifact-writes.jsonl" > "$ft/ts.tmp" \
    && mv "$ft/ts.tmp" "$ft/_bmad-output/planning-artifacts/.artifact-writes.jsonl" || { WHY="the review row ts was not pinned"; return 1; }
  p="$ft/_bmad-output/gate-adjudication/g1.part-1.jsonl"; mkdir -p "$(dirname "$p")" && printf '{}\n' > "$p"
  fire "$p" agent Write "$ft" || { WHY="the recorder wrote no gate-part row"; return 1; }
  l="$ft/_bmad-output/planning-artifacts/.artifact-writes.jsonl"
  t1="$(jq -r 'select(has("body_sha")) | .ts' "$l")"; t2="$(jq -r 'select(has("body_sha") | not) | .ts' "$l")"
  [ -n "$t1" ] && [ -n "$t2" ] && [ "$t1" \< "$t2" ] || { WHY="FIXTURE BROKEN: the review row ($t1) is not strictly before the part row ($t2)"; return 1; }
  r="$(bash "$sd/content-seal.sh" --first-tool-ts "$ft/_bmad-output" 2>&1)"
  [ "$r" = "$t2" ] || WHY="$WHY review-row-moved-it{$r, want $t2}"
  jq -c 'del(.body_sha)' "$l" > "$l.tmp" && mv "$l.tmp" "$l" || return 1
  r="$(bash "$sd/content-seal.sh" --first-tool-ts "$ft/_bmad-output" 2>&1)"
  [ "$r" = "$t1" ] || WHY="$WHY control{without body_sha the row read $r, want $t1}"
  [ -z "$WHY" ]
}

# ---- EV1: an ENVIRONMENT that cannot read the seal is the lead's, never a reviewer's. A seat-sealed set
# merged on a PATH built from this fixture's own tools.decl WITHOUT jq is REFUSED [owner: lead], naming
# SEAL-UNAVAILABLE and no re-dispatch; --mark on a fresh shard under it exits 64 relaying the same text.
# The control is the SAME set on the same PATH with jq added back, which merges -- so the built PATH lacks
# jq and nothing else the merge needs.
p_env() {
  local sd="$1" d o nb jb t f s
  WHY=""
  nb="$WORK/nojq-bin"; jb="$WORK/jq-bin"
  if [ ! -d "$nb" ]; then
    mkdir -p "$nb" "$jb" || return 1
    while IFS= read -r t; do
      case "$t" in ""|"#"*|jq) continue ;; esac
      f="$(command -v "$t")" && [ -x "$f" ] && ln -s "$f" "$nb/$t" || { WHY="FIXTURE ERROR: $t from tools.decl is not on PATH"; return 1; }
    done < "$LIB_DIR/tools.decl"
    ln -s "$(command -v jq)" "$jb/jq" || return 1
  fi
  # Resolved in a FRESH process: this shell's command hash table keeps /opt/homebrew/bin/jq from earlier arms
  # and answers `command -v jq` from it whatever PATH says.
  [ ! -e "$nb/jq" ] && env -i PATH="$nb" "$nb/bash" -c 'command -v git > /dev/null 2>&1 && ! command -v jq > /dev/null 2>&1' \
    || { WHY="FIXTURE BROKEN: the jq-less PATH $nb still resolves jq, or lacks git"; return 1; }
  d="$(seal_world "$sd" code-review)" || { WHY="the sealed world was not built: $(head -2 "$MKO")"; return 1; }
  o="$(out_of "$d")"
  PATH="$nb" AI_DLC_PROJECT_ROOT="$PROJ" "$nb/bash" "$sd/merge-review-shards.sh" "$d" --gate code-review --out "$o" \
    > "$MO" 2>&1 < /dev/null; RC=$?
  refused_clean "SEAL-UNAVAILABLE:" "$d" && has "$MO" "jq is not on PATH" && owner_in "$MO" lead \
    && ! has "$MO" "re-dispatch the reviewer" || WHY="$WHY nojq-merge{rc=$RC $(head -1 "$MO")}"
  PATH="$nb:$jb" AI_DLC_PROJECT_ROOT="$PROJ" "$nb/bash" "$sd/merge-review-shards.sh" "$d" --gate code-review --out "$o" \
    > "$MO" 2>&1 < /dev/null; RC=$?
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" || WHY="$WHY control-with-jq{rc=$RC $(head -1 "$MO")}"
  # --mark: a seat-written shard, its row recorded with jq present, marked on the jq-less PATH.
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || { WHY="$WHY the mark world was not built"; return 1; }
  f="$d/2.md"; s="$(dirname "$d")/2.snap"
  fire "$f" agent || { WHY="$WHY the recorder wrote no row for $f"; return 1; }
  cp "$f" "$s" || return 1
  PATH="$nb" AI_DLC_PROJECT_ROOT="$PROJ" "$nb/bash" "$sd/wait-for-deliverable.sh" --mark "$f" implementation code-reviewer 2 findings=1 \
    > "$MKO" 2>&1 < /dev/null; MRC=$?
  mark_refused "SEAL-UNAVAILABLE:" "$s" "$f" && has "$MKO" "repair the environment, then mark again." \
    || WHY="$WHY nojq-mark{rc=$MRC $(head -2 "$MKO")}"
  [ -z "$WHY" ]
}

# ---- UM1: an UNMARKED set over the key= engine takes the NON-legacy seal. Seeded exactly as the tip
# adversary's D2 repro (adv-strip.sh): a set of shards (here closed with markers), every `seat-complete:`
# line stripped with `awk '!/^seat-complete: /'`, one shard's verdict rewritten with sed, then merged over
# a frozen sha whose engine carries the sentinel and a ledger with no rows for them -> REFUSED, no seal
# row. The control is the same steps over B's frozen sha (the old engine), which merges with no LEGACY
# line (no marker is left to be legacy).
# THE REWRITE IS TO BLOCKED, NOT THE REPRO'S APPROVED (BL-740): the worlds are NEEDS_REWORK, so shard 2's
# one finding sits under Critical, and an APPROVED shard over a Critical finding is now refused by the
# merge's VERDICT BACKING -- a cause UM1 does not own, which would refuse the old-engine control. BLOCKED
# over a Critical finding is backed, so the control still merges, and the sentinel half still refuses at
# shard 1's seal before shard 2 is read. The property UM1 holds (no marker left, one verdict rewritten by
# sed, no seal row) is unchanged.
um_strip() { # <shard dir>: the repro's steps -- strip every marker, rewrite shard 2's verdict
  local f
  for f in "$1"/*.md; do awk '!/^seat-complete: /' "$f" > "$f.t" && mv "$f.t" "$f" || return 1; done
  sed -e 's/^shard-verdict: .*/shard-verdict: BLOCKED/' "$1/2.md" > "$1/2.t" && mv "$1/2.t" "$1/2.md" || return 1
  grep -q '^shard-verdict: BLOCKED$' "$1/2.md" && [ "$(cat "$1"/*.md | grep -c '^seat-complete: ')" = 0 ]
}
p_unmarked() {
  local sd="$1" d SHARD_SHA
  WHY=""
  if cell unmarked-sentinel; then
    SHARD_SHA="$S_SHA"
    d="$(kworld "$sd" "$REPO_S" "$S_BASE" "$S_SHA" 3 code-review NEEDS_REWORK)" || { WHY="the sentinel world was not built"; return 1; }
    lmark_all "$d"; um_strip "$d" || { WHY="FIXTURE BROKEN: the repro's strip and rewrite did not apply"; return 1; }
    run_merge "$sd" "$d"
    refused_clean "carries no content-seal row" "$d" || WHY="$WHY unmarked-sentinel{rc=$RC $(head -1 "$MO")}"
  fi
  if cell control-old-engine; then
    SHARD_SHA="$B_SHA"
    d="$(world4 "$sd" NEEDS_REWORK NEEDS_REWORK NEEDS_REWORK NEEDS_REWORK)" || { WHY="$WHY the old-engine world was not built"; return 1; }
    lmark_all "$d"; um_strip "$d" || { WHY="FIXTURE BROKEN: the repro's strip and rewrite did not apply (control)"; return 1; }
    run_merge "$sd" "$d"
    [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && ! has "$MO" "LEGACY:" || WHY="$WHY control-old-engine{rc=$RC $(head -1 "$MO")}"
  fi
  [ -z "$WHY" ]
}

# ===================================================================== BL-740: VERDICT BACKING.
# A shard's verdict is backed by its OWN findings, read off the merge's --gate. Each case overwrites shard
# 2 of a clean world (the first read is shard 1, so the refusal is the case's own), and is driven through
# the full merge AND --check-shard: a refusal must be one REFUSED line, byte-equal between the two
# (cs_same, CS1's comparison), carrying the case's own token; a pass must MERGE and answer SHARD-OK. Every
# case writes its own WHY token, `<case>{...}`, so a mutant's kill is read on the cell it moved.
# THE TOKENS are the merge's own message fragments. The code-review ones stop before the Important name
# on purpose: a container lift that loses that name changes the text after it, and the cell that owns
# that defect is cr-nr-imp, not the refusals beside it.
VB_STEM="a shard's verdict is backed by its own findings"
VB_CR_NR="carries 'shard-verdict: NEEDS_REWORK' but no '#### ' finding under '### Critical'"
VB_CR_BL="carries 'shard-verdict: BLOCKED' but no '#### ' finding under '### Critical'"
VB_CR_AP="carries 'shard-verdict: APPROVED' but 1 '#### ' finding(s) under '### Critical'; a Critical finding is not approvable"
VB_Q_NR="carries 'shard-verdict: NEEDS_REWORK' but no '#### ' finding in its '## Findings'"
# BL-746: the severity-mode tokens under --gate qa, the unclassed-finding refusal (both gates), the
# legacy line, and the wrong-count refusal.
VB_Q_SEV_NR="carries 'shard-verdict: NEEDS_REWORK' but no '#### ' finding under '### Critical' or '### Important'"
VB_Q_PASS_CRIT="carries 'shard-verdict: PASS' but 1 '#### ' finding(s) under '### Critical'; a Critical finding is not approvable"
VB_MOVE="or move the finding this shard already files under '### Suggestions' there"
VB_UNC="finding under '## Findings' with no '### ' container above it"
VB_LEG="declares no severity containers; QA verdict backing is count-only"
VB_Q2="qa.md's ## Findings template declares 2 severity container(s)"
# R3's three exact substrings: both satisfiable exits and the owner tail.
VB_R3_LEAD="If the finding belongs to another shard, set 'shard-verdict: PASS'"
VB_R3_FILE="otherwise file the finding that makes it NEEDS_REWORK here, as a '#### ' heading under '### Critical' or '### Important'"
VB_R3_SET="set 'shard-verdict: PASS' here and let that shard's verdict carry it"
VB_R3_OWN="[owner: cross-1]"
# The graph s319 story 3.1 cross-1 shard's own ## Findings body, verbatim: a qa NEEDS_REWORK whose gap
# it says is owned by another group's shard, and no '#### ' finding.
VB_R3_BODY="(none filed by cross-1. The AC4 gap below is owned by cross group g4, parts 2 and 3, under the brief's group table; filing it here would be refused as a duplicate of that owner.)"
# vb_c <dir> <key> <verdict> <cite> <crit|imp|sug|none>: code-reviewer.md's three containers, the one
# finding (shard_find) under the named one; `none` is the empty findings template.
vb_c() {
  local d="$1" k="$2" v="$3" cite="$4" at="$5" c
  {
    printf '# Code Review shard %s\n\nreviewed-sha: %s\nshard-verdict: %s\n' "$k" "${SHARD_SHA:-$B_SHA}" "$v"; adv_l
    case "$k" in cross*) ;; *) printf 'handovers: 0\n' ;; esac
    printf '\n## Summary\nShard %s read its part. CONSERVE-%s-7f3a\n\n## Findings\n\n' "$k" "$k"
    for c in crit imp sug; do
      case "$c" in
        crit) printf '### Critical (must fix before merge)\n\n' ;;
        imp) printf '### Important (should fix, can be follow-up)\n\n' ;;
        sug) printf '### Suggestions (optional improvements)\n\n' ;;
      esac
      [ "$c" != "$at" ] || shard_find "$k" "$cite"
    done
    printf '## Architecture Alignment\nNothing further.\n'
  } > "$d/$k.md"
}
# vb_q <dir> <key> <verdict> <## Findings body, verbatim; empty for none>: a qa shard; the first cross
# shard carries the per-AC table and the deferred record, as qshard's does.
vb_q() {
  local d="$1" k="$2" v="$3" body="$4"
  {
    printf '# QA Validation shard %s\n\nreviewed-sha: %s\nshard-verdict: %s\n' "$k" "${SHARD_SHA:-$B_SHA}" "$v"; adv_l
    case "$k" in cross*) ;; *) printf 'handovers: 0\n' ;; esac
    printf '\n## Summary\nShard %s validated its part. QCONSERVE-%s-91c2\n\n## Findings\n\n' "$k" "$k"
    [ -z "$body" ] || printf '%s\n\n' "$body"
    if [ "$k" = cross ] || [ "$k" = cross-1 ]; then
      printf '## Acceptance Criteria\n\n| AC | Verdict | Evidence |\n|---|---|---|\n| AC1 | PASS | suite green |\n| AC4 | %s | gap |\n\n' "$v"
      printf '## Deferred ACs\n\nNone.\n'
    fi
  } > "$d/$k.md"
}
vb_refuse() { # <script-dir> <shard-dir> <gate> <target key> <case> <token> [second token]
  CS_TOK="$6"
  if cs_same "$1" "$2" "$3" "$2/$4.md" && { [ -z "${7:-}" ] || has "$CO" "$7"; }; then :
  else WHY="$WHY $5{$CS_LAST}"; fi
  CS_TOK=""
}
vb_pass() { # <script-dir> <shard-dir> <gate> <target key> <case>
  local o
  if [ "$3" = qa ]; then o="$(qout "$2")"; else o="$(out_of "$2")"; fi
  run_mg "$1" "$2" "$3" "$o"
  run_check "$1" "$2" "$3" "$2/$4.md"
  [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ -f "$o" ] && [ "$CRC" -eq 0 ] && has "$CO" "SHARD-OK: $2/$4.md" \
    || WHY="$WHY $5{merge rc=$RC [$(head -1 "$MO")] check rc=$CRC [$(head -1 "$CO")]}"
  rm -f "$o"
}
# ---- VB1 (code-review): NEEDS_REWORK and BLOCKED need a Critical or Important finding; APPROVED carries
# no Critical one. Each refusal has its ALLOW twin one container apart.
p_vb_cr() {
  local sd="$1" d c
  WHY=""
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || { WHY="the code-review world was not built"; return 1; }
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || return 1
  if cell cr-nr-empty; then vb_c "$d" 2 NEEDS_REWORK 2 none; vb_refuse "$sd" "$d" code-review 2 cr-nr-empty "$VB_CR_NR" "$VB_STEM"; cs_reset "$d" "$c"; fi
  if cell cr-nr-imp; then vb_c "$d" 2 NEEDS_REWORK 2 imp; vb_pass "$sd" "$d" code-review 2 cr-nr-imp; cs_reset "$d" "$c"; fi
  if cell cr-blocked-crit; then vb_c "$d" 2 BLOCKED 2 crit; vb_pass "$sd" "$d" code-review 2 cr-blocked-crit; cs_reset "$d" "$c"; fi
  if cell cr-blocked-sug; then vb_c "$d" 2 BLOCKED 2 sug; vb_refuse "$sd" "$d" code-review 2 cr-blocked-sug "$VB_CR_BL" "$VB_STEM"; cs_reset "$d" "$c"; fi
  if cell cr-approved-crit; then vb_c "$d" 2 APPROVED 2 crit; vb_refuse "$sd" "$d" code-review 2 cr-approved-crit "$VB_CR_AP"; cs_reset "$d" "$c"; fi
  if cell cr-approved-imp; then vb_c "$d" 2 APPROVED 2 imp; vb_pass "$sd" "$d" code-review 2 cr-approved-imp; cs_reset "$d" "$c"; fi
  [ -z "$WHY" ]
}
# qf <container first word|none> -> one finding of shard 2, under that container (none: no `### `).
qf() { if [ "$1" = none ]; then printf '#### Q-2-9 a gap\nparts: 2\n\nBody.'; else printf '### %s (seeded)\n\n#### Q-2-9 a gap\nparts: 2\n\nBody.' "$1"; fi; }
# ---- VB2 (qa, BL-746): qa.md declares the three containers, so the SEVERITY rule is the code-review
# rule: NEEDS_REWORK needs a Critical or Important finding, PASS carries no Critical, and a finding with
# no container is refused as unclassed. Each refusal has its ALLOW twin one container apart. No LEGACY
# line under the three-container qa.md.
p_vb_qa() {
  local sd="$1" d c
  WHY=""
  d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="the qa world was not built"; return 1; }
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || return 1
  if cell q-nr-empty; then vb_q "$d" 2 NEEDS_REWORK ""; vb_refuse "$sd" "$d" qa 2 q-nr-empty "$VB_Q_SEV_NR" "$VB_STEM"; cs_reset "$d" "$c"; fi
  if cell q-nr-sug; then vb_q "$d" 2 NEEDS_REWORK "$(qf Suggestions)"; vb_refuse "$sd" "$d" qa 2 q-nr-sug "$VB_Q_SEV_NR" "$VB_MOVE"; cs_reset "$d" "$c"; fi
  if cell q-nr-imp; then vb_q "$d" 2 NEEDS_REWORK "$(qf Important)"; vb_pass "$sd" "$d" qa 2 q-nr-imp
    ! has "$MO" "$VB_LEG" || WHY="$WHY q-sev-legacy-line{$(head -1 "$MO")}"; cs_reset "$d" "$c"; fi
  if cell q-pass-crit; then vb_q "$d" 2 PASS "$(qf Critical)"; vb_refuse "$sd" "$d" qa 2 q-pass-crit "$VB_Q_PASS_CRIT"; cs_reset "$d" "$c"; fi
  if cell q-pass-imp; then vb_q "$d" 2 PASS "$(qf Important)"; vb_pass "$sd" "$d" qa 2 q-pass-imp; cs_reset "$d" "$c"; fi
  if cell q-unclassed; then vb_q "$d" 2 PASS "$(qf none)"; vb_refuse "$sd" "$d" qa 2 q-unclassed "$VB_UNC"; cs_reset "$d" "$c"; fi
  [ -z "$WHY" ]
}
# ---- VB2M (qa, BL-746): the MODE alone, in one cell, so a mutant that keeps QA count-only under a
# three-container qa.md moves exactly this assertion -- VB2's cells all move with the mode too, which is
# why M12 is scored here and not there. NEEDS_REWORK backed only by a Suggestions finding is REFUSED.
p_vb_qmode() {
  local sd="$1" d
  WHY=""
  cell q-mode-sug || return 0
  d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="the qa world was not built"; return 1; }
  vb_q "$d" 2 NEEDS_REWORK "$(qf Suggestions)"; vb_refuse "$sd" "$d" qa 2 q-mode-sug "$VB_Q_SEV_NR" "$VB_MOVE"
  [ -z "$WHY" ]
}
# ---- VB2L (qa, BL-746 delivery path): the qa.md a consumer has installed until the reconcile merge
# declares NO container, and the rule stays count-only -- an uncontained NEEDS_REWORK finding merges,
# and an empty NEEDS_REWORK is refused with the count-only text; stdout carries the LEGACY line. A
# qa.md declaring TWO containers is REFUSED, never read as either mode. The code-review gate is not
# affected by qa.md's state (a cr world under the legacy root still refuses an unclassed finding).
p_vb_qleg() {
  local sd="$1" d c o
  WHY=""
  d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="the qa world was not built"; return 1; }
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || return 1
  VB_PROJ="$PROJ_QLEG"
  if cell q-leg-nr-one; then vb_q "$d" 2 NEEDS_REWORK "$(qf none)"; vb_pass "$sd" "$d" qa 2 q-leg-nr-one
    has "$MO" "LEGACY: $PROJ_QLEG/core/team-roles/qa.md $VB_LEG" || WHY="$WHY q-leg-line{$(head -1 "$MO")}"; cs_reset "$d" "$c"; fi
  if cell q-leg-pass-crit; then vb_q "$d" 2 PASS "$(qf Critical)"; vb_pass "$sd" "$d" qa 2 q-leg-pass-crit; cs_reset "$d" "$c"; fi
  if cell q-leg-nr-empty; then vb_q "$d" 2 NEEDS_REWORK ""; vb_refuse "$sd" "$d" qa 2 q-leg-nr-empty "$VB_Q_NR" "$VB_STEM"; cs_reset "$d" "$c"; fi
  if cell q-two-containers; then
    VB_PROJ="$PROJ_Q2"
    o="$(qout "$d")"; run_mg "$sd" "$d" qa "$o"
    refused_at "$VB_Q2" "$o" && owner_in "$MO" lead || WHY="$WHY q-two-containers{rc=$RC $(reline "$MO")}"
    VB_PROJ="$PROJ_QLEG"
  fi
  if cell cr-unclassed; then
    d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || { VB_PROJ=""; WHY="$WHY the code-review world was not built"; return 1; }
    raw_shard "$d" 2 '## Findings' '' '#### F-2-9 uncontained' 'parts: 2' '' 'Body.'
    vb_refuse "$sd" "$d" code-review 2 cr-unclassed "$VB_UNC"
  fi
  VB_PROJ=""
  [ -z "$WHY" ]
}
# ---- VB3 (R3): the graph cross-1 shape. A qa cross-1 at NEEDS_REWORK whose ## Findings says the gap is
# another group's shard's: REFUSED, byte-equal under --check-shard, naming BOTH exits and its owner.
p_vb_r3() {
  local sd="$1" d
  WHY=""
  # One cell: every assertion below reads the one merge of the graph cross-1 shape.
  cell r3-graph-cross1 || return 0
  d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="the qa world was not built"; return 1; }
  [ -f "$d/cross-1.md" ] || { WHY="FIXTURE BROKEN: the qa world has no cross-1"; return 1; }
  vb_q "$d" cross-1 NEEDS_REWORK "$VB_R3_BODY"
  vb_refuse "$sd" "$d" qa cross-1 r3-graph-cross1 "$VB_Q_SEV_NR" "$VB_STEM"
  has "$MO" "$VB_R3_FILE" || WHY="$WHY r3-file-exit{$(reline "$MO")}"
  has "$MO" "$VB_R3_SET" || WHY="$WHY r3-set-pass-exit{$(reline "$MO")}"
  has "$MO" "$VB_R3_LEAD" || WHY="$WHY r3-owner-first{$(reline "$MO")}"
  local mo_txt_
  mo_txt_="$(reline "$MO")"
  case "$mo_txt_" in *"$VB_R3_LEAD"*"$VB_R3_FILE"*) ;; *) WHY="$WHY r3-owner-first-order{${mo_txt_}}" ;; esac
  has "$MO" "$VB_R3_OWN" && owner_in "$MO" cross-1 || WHY="$WHY r3-owner{$(reline "$MO")}"
  [ -z "$WHY" ]
}
# ---- VB4 (--mark): findings=0 on an empty NEEDS_REWORK code-review shard exits 64 relaying the stem, the
# file byte-unchanged; the ALLOW twin, same file, one Important finding filed and re-written by the seat,
# marks it findings=1 keyed 2.
p_vb_mark() {
  local sd="$1" d f s
  WHY=""
  d="$(world4 "$sd" APPROVED APPROVED APPROVED APPROVED)" || { WHY="the mark world was not built"; return 1; }
  f="$d/2.md"; s="$(dirname "$d")/2.snap"
  vb_c "$d" 2 NEEDS_REWORK 2 none
  fire "$f" agent || { WHY="the recorder wrote no row for $f"; return 1; }
  cp "$f" "$s" || return 1
  mark_args "$sd" "$f" implementation code-reviewer 2 findings=0
  mark_refused "$VB_CR_NR" "$s" "$f" && has "$MKO" "$VB_STEM" || WHY="$WHY mark-nr-empty{rc=$MRC $(head -3 "$MKO")}"
  vb_c "$d" 2 NEEDS_REWORK 2 imp
  fire "$f" agent || { WHY="$WHY the recorder wrote no row for the re-written $f"; return 1; }
  mark_args "$sd" "$f" implementation code-reviewer 2 findings=1
  [ "$MRC" -eq 0 ] && grep -qE '^seat-complete: implementation code-reviewer 2 key=2 sha=[0-9a-f]{64} findings=1$' "$f" \
    || WHY="$WHY mark-allow{rc=$MRC $(head -2 "$MKO")}"
  [ -z "$WHY" ]
}

# ---- FR1-FR3 (BL-747): the first cross shard's per-AC table against the merged verdict and every
# shard's findings. The table is qa.md's own shape (`| AC | Result | Expected | Got |`) unless a case
# names another header; the FAIL row is AC4, never the first row. fr_x1 rewrites cross-1 only.
FR_TBL='| AC | Result | Expected | Got |'
FR_VERD="reads FAIL but the QA verdict is PASS"
FR_ORPH="reads FAIL but no '#### ' finding names"
FR_DUP="a finding owned by cross-2"
# fr_x1 <dir> <verdict> <extra findings text, may be empty> <header row> <AC4 row>
fr_x1() {
  local g1 f1 l1
  g1="$(awk -F'\t' '$1 == 1 { print $2; exit }' "$1.groups")"; f1="${g1%%,*}"; l1="${g1##*,}"
  {
    printf '# QA Validation shard cross-1\n\nreviewed-sha: %s\nshard-verdict: %s\n' "${SHARD_SHA:-$B_SHA}" "$2"; adv_l; printf '\n'
    printf '## Summary\nShard cross-1 validated its part. QCONSERVE-cross-1-91c2\n\n%s\n\n' "$CANON_BLK"
    printf '## Findings\n\n### Important (should fix, can be follow-up)\n\n#### Q-cross-1-1 a missing caller in shard cross-1\nparts: %s, %s\n\nBody.\n\n' "$f1" "$l1"
    [ -z "$3" ] || printf '%s\n\n' "$3"
    printf '## Acceptance Criteria\n\n%s\n|---|---|---|---|\n| AC1 | PASS | suite green | green |\n%s\n| AC5 | PASS | x | y |\n\n' "$4" "$5"
    printf '## Deferred ACs\n\nNone.\n'
  } > "$1/cross-1.md"
}
fr_find2() { printf '### Important (seeded)\n\n#### Q-2-9 %s\nparts: 2\n\n%s' "$1" "$2"; } # <heading> <body>
fr_merged() { # <script-dir> <dir> <case> <want verdict>
  local o; o="$(qout "$2")"; q_merge "$1" "$2"
  [ "$RC" -eq 0 ] && has "$MO" "verdict=$4 " || WHY="$WHY $3{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
  rm -f "$o"
}
fr_refused() { # <script-dir> <dir> <case> <token>
  local o; o="$(qout "$2")"; q_merge "$1" "$2"
  refused_at "$4" "$o" && owner_in "$MO" cross-1 || WHY="$WHY $3{rc=$RC $(reline "$MO")}"
  # A mutant that MERGES here writes --out; left on disk it makes the NEXT cell's merge refuse as
  # "already exists and differs", so the mutant would move a second cell for a reason it does not own.
  rm -f "$o"
}
# FR1: the verdict rule. PASS over a FAIL row is refused in three spellings and in a reordered table;
# a FAIL only in Expected, and FAILED-free rows, merge; NEEDS_REWORK carried by another shard merges.
p_fr_verdict() {
  local sd="$1" d c
  WHY=""
  d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="the qa world was not built"; return 1; }
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || return 1
  if cell fr-plain; then fr_x1 "$d" PASS "" "$FR_TBL" '| AC4 | FAIL | a RED | none |'; fr_refused "$sd" "$d" fr-plain "$FR_VERD"; cs_reset "$d" "$c"; fi
  if cell fr-bold; then fr_x1 "$d" PASS "" "$FR_TBL" '| AC4 | **FAIL** | a RED | none |'; fr_refused "$sd" "$d" fr-bold "$FR_VERD"; cs_reset "$d" "$c"; fi
  if cell fr-paren; then fr_x1 "$d" PASS "" "$FR_TBL" '| `AC4` (committed RED) | FAIL (no RED) | a RED | none |'; fr_refused "$sd" "$d" fr-paren "$FR_VERD"; cs_reset "$d" "$c"; fi
  if cell fr-reorder; then fr_x1 "$d" PASS "" '| AC | Expected | Result | Got |' '| AC4 | green | FAIL | none |'; fr_refused "$sd" "$d" fr-reorder "$FR_VERD"; cs_reset "$d" "$c"; fi
  # The near-miss puts FAIL in Got, the column AFTER the named one, so a read-by-position mutant (M16,
  # rc = ac + 1, which lands on Expected) moves only fr-reorder, never this cell.
  if cell fr-expected-only; then fr_x1 "$d" PASS "" '| AC | Expected | Verdict | Got |' '| AC4 | green | PASS | FAIL then green |'; fr_merged "$sd" "$d" fr-expected-only PASS; cs_reset "$d" "$c"; fi
  if cell fr-all-pass; then fr_x1 "$d" PASS "" "$FR_TBL" '| AC4 | PASS | a RED | RED |'; fr_merged "$sd" "$d" fr-all-pass PASS; cs_reset "$d" "$c"; fi
  if cell fr-nr-elsewhere; then vb_q "$d" 2 NEEDS_REWORK "$(fr_find2 'AC4 has no committed RED' 'Body.')"
    fr_x1 "$d" PASS "" "$FR_TBL" '| AC4 | FAIL | a RED | none |'; fr_merged "$sd" "$d" fr-nr-elsewhere NEEDS_REWORK; cs_reset "$d" "$c"; fi
  [ -z "$WHY" ]
}
# FR2: the orphan rule. A FAIL row under a NEEDS_REWORK merge whose AC no finding names is refused --
# the table's own mention of AC4 does not count -- and AC10 does not name AC1; the twins merge.
p_fr_orphan() {
  local sd="$1" d c
  WHY=""
  d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="the qa world was not built"; return 1; }
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || return 1
  if cell fr-orphan; then vb_q "$d" 2 NEEDS_REWORK "$(fr_find2 'a gap with no AC named' 'Body.')"
    fr_x1 "$d" PASS "" "$FR_TBL" '| AC4 | FAIL | a RED for AC4 | none |'; fr_refused "$sd" "$d" fr-orphan "$FR_ORPH AC4"; cs_reset "$d" "$c"; fi
  if cell fr-ac10; then vb_q "$d" 2 NEEDS_REWORK "$(fr_find2 'a gap' 'AC10 has no committed RED.')"
    fr_x1 "$d" PASS "" "$FR_TBL" '| AC1 | FAIL | a RED | none |'; fr_refused "$sd" "$d" fr-ac10 "$FR_ORPH AC1"; cs_reset "$d" "$c"; fi
  if cell fr-ac1; then vb_q "$d" 2 NEEDS_REWORK "$(fr_find2 'a gap' 'AC1 has no committed RED; AC10 is fine.')"
    fr_x1 "$d" PASS "" "$FR_TBL" '| AC1 | FAIL | a RED | none |'; fr_merged "$sd" "$d" fr-ac1 NEEDS_REWORK; cs_reset "$d" "$c"; fi
  [ -z "$WHY" ]
}
# FR4: graph 811ad3d7d, story 3.1 qa p2 (read-only), as two states. There cross-1 carried `| AC4 | FAIL |`
# under `shard-verdict: PASS`, and cross-4 (NEEDS_REWORK; F1 about AC10, its findings under NO `### `
# container, `parts: 2, 3`) named no AC4; a hand-added `#### F2 — AC4 ...`, uncontained, same parts, let
# the merge through. That set ran against the consumer's installed qa.md, which declared no container,
# so the world runs under PROJ_QLEG. Here K=3, so the non-first cross shard is cross-2 standing in for
# cross-4, citing its own group's pair. Each state asserts the refusal it is refused ON (its message),
# and that it is not the other FAIL-row refusal.
fr_g_cross() { # <dir> <first> <last> <with F2: 0|1>
  {
    printf '# QA Validation shard cross-2\n\nreviewed-sha: %s\nshard-verdict: NEEDS_REWORK\n' "${SHARD_SHA:-$B_SHA}"; adv_l; printf '\n'
    printf '## Summary\nShard cross-2 validated its part. QCONSERVE-cross-2-91c2\n\n## Findings\n\n'
    printf '#### F1 — AC10 two-pair and unpriced-token totals are driven from hand-built rows, not the real parser\n\nparts: %s, %s\n\nBody.\n\n' "$2" "$3"
    [ "$4" = 0 ] || printf '#### F2 — AC4 has no committed mutation-RED reaching its discriminating fixture\n\nparts: %s, %s\n\nBody.\n\n' "$2" "$3"
    printf '## Items checked, no finding\n\nNone.\n'
  } > "$1/cross-2.md"
}
FR_BLEG="held to the count-only QA rule only because the frozen sha"
# fr_g_world <script-dir> <repo> <base> <sha> <with F2: 0|1> -> the graph-shaped qa set frozen over
# <repo>, every shard PASS but cross-1's AC4 FAIL row and cross-2's NEEDS_REWORK (graph's cross-4).
fr_g_world() {
  local sd="$1" d g2 f2 l2
  SHARD_SHA="$4"
  d="$(kworld "$sd" "$2" "$3" "$4" 3 qa-validation PASS qa)" || return 1
  [ -f "$d/cross-2.md" ] && [ -f "$d.groups" ] || return 1
  g2="$(awk -F'\t' '$1 == 2 { print $2; exit }' "$d.groups")"; f2="${g2%%,*}"; l2="${g2##*,}"
  fr_x1 "$d" PASS "" "$FR_TBL" '| AC4 | FAIL | Committed mutation-RED for each discriminating fixture in AC4. | No committed RED. |'
  fr_g_cross "$d" "$f2" "$l2" "$5"
  printf '%s' "$d"
}
# FR4: graph's two states, the set frozen over a tree whose INSTALLED qa.md declares no container
# (graph's, measured at 50eb567df), judged by today's three-container qa.md.
p_fr_graph() {
  local sd="$1" d SHARD_SHA
  WHY=""
  d="$(fr_g_world "$sd" "$REPO_QL" "$QL_BASE" "$QL_SHA" 0)" || { WHY="the frozen-QL world was not built"; return 1; }
  fr_refused "$sd" "$d" fr-graph-pre-f2 "$FR_ORPH AC4"
  ! has "$MO" "$FR_VERD" || WHY="$WHY fr-graph-pre-f2-wrong-rule{$(reline "$MO")}"
  d="$(fr_g_world "$sd" "$REPO_QL" "$QL_BASE" "$QL_SHA" 1)" || { WHY="$WHY the frozen-QL post-F2 world was not built"; return 1; }
  fr_merged "$sd" "$d" fr-graph-post-f2 NEEDS_REWORK
  has "$MO" "LEGACY: $d/cross-2.md $FR_BLEG $QL_SHA's .claude/team-roles/qa.md" || WHY="$WHY fr-graph-post-f2-legacy-line{$(head -2 "$MO" | tr '\n' ' ')}"
  [ -z "$WHY" ]
}
# FRB: THE SEVERITY BOUNDARY, one cell per side. The post-F2 set (cross-2's findings uncontained):
# frozen over the container-less installed qa.md -> merges NEEDS_REWORK with the LEGACY line; frozen
# over the three-container one -> REFUSED unclassed [owner: cross-2], no LEGACY line; frozen over a tree
# installing no qa.md (unreadable) -> REFUSED the same way, never acquitted.
p_fr_bound() {
  local sd="$1" d o SHARD_SHA
  WHY=""
  if cell frb-legacy; then
    d="$(fr_g_world "$sd" "$REPO_QL" "$QL_BASE" "$QL_SHA" 1)" || { WHY="the frozen-QL world was not built"; return 1; }
    fr_merged "$sd" "$d" frb-legacy NEEDS_REWORK
    has "$MO" "$FR_BLEG" || WHY="$WHY frb-legacy-line{$(head -1 "$MO")}"
  fi
  if cell frb-severity; then
    d="$(fr_g_world "$sd" "$REPO_QS" "$QS_BASE" "$QS_SHA" 1)" || { WHY="$WHY the frozen-QS world was not built"; return 1; }
    o="$(qout "$d")"; q_merge "$sd" "$d"
    refused_at "$VB_UNC" "$o" && owner_in "$MO" cross-2 && ! has "$MO" "$FR_BLEG" || WHY="$WHY frb-severity{rc=$RC $(reline "$MO")}"
    rm -f "$o"
  fi
  if cell frb-unreadable; then
    d="$(fr_g_world "$sd" "$REPO_B" "$B_BASE" "$B_SHA" 1)" || { WHY="$WHY the unreadable world was not built"; return 1; }
    o="$(qout "$d")"; q_merge "$sd" "$d"
    refused_at "$VB_UNC" "$o" && owner_in "$MO" cross-2 && ! has "$MO" "$FR_BLEG" || WHY="$WHY frb-unreadable{rc=$RC $(reline "$MO")}"
    rm -f "$o"
  fi
  [ -z "$WHY" ]
}
# FR3: the remedy is SATISFIABLE under the owner rule (graph s319 3-1 p2 cross-1: AC4 FAIL, the gap's
# set owned by another cross group). cross-1 filing the AC4 finding under cross-2's own set is the
# owner-duplicate refusal; filing it under a set cross-1 owns merges; so does the owning shard naming
# AC4 in the finding it already carries.
p_fr_remedy() {
  local sd="$1" d c g2 f2 l2 g1 f1 l1
  WHY=""
  d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="the qa world was not built"; return 1; }
  [ -f "$d/cross-2.md" ] || { WHY="FIXTURE BROKEN: the qa world has no cross-2"; return 1; }
  c="$(dirname "$d")/clean"; mkdir "$c" && cp "$d"/*.md "$c"/ || return 1
  g1="$(awk -F'\t' '$1 == 1 { print $2; exit }' "$d.groups")"; f1="${g1%%,*}"; l1="${g1##*,}"
  g2="$(awk -F'\t' '$1 == 2 { print $2; exit }' "$d.groups")"; f2="${g2%%,*}"; l2="${g2##*,}"
  fr_x1 "$d" NEEDS_REWORK "$(printf '#### Q-cross-1-4 AC4 has no committed RED\nparts: %s, %s\n\nBody.' "$f2" "$l2")" "$FR_TBL" '| AC4 | FAIL | a RED | none |'
  fr_refused "$sd" "$d" fr-dup-blocks "$FR_DUP"; cs_reset "$d" "$c"
  fr_x1 "$d" NEEDS_REWORK "$(printf '#### Q-cross-1-4 AC4 has no committed RED\nparts: %s, %s\n\nBody.' "$f1" "$l1")" "$FR_TBL" '| AC4 | FAIL | a RED | none |'
  fr_merged "$sd" "$d" fr-own-set NEEDS_REWORK; cs_reset "$d" "$c"
  qshard "$d" cross-2 NEEDS_REWORK "$f2, $l2"
  awk '/^#### Q-cross-2-1 / { print "#### Q-cross-2-1 AC4: a missing caller in shard cross-2"; next } { print }' "$d/cross-2.md" > "$d/x.tmp" && mv "$d/x.tmp" "$d/cross-2.md"
  fr_x1 "$d" PASS "" "$FR_TBL" '| AC4 | FAIL | a RED | none |'
  fr_merged "$sd" "$d" fr-owner-names NEEDS_REWORK
  [ -z "$WHY" ]
}

# ---- SR1 (BL-742): --check-serial runs the merge's own Check 1 read-back and set membership over ONE
# serial file, and under --gate qa the FAIL ROWS rules. Each refusal has its ALLOW twin one line apart.
SR_COUNT="time(s) reading 2 different values"
SR_SET="which is not one of"
SR_OWN="[owner: serial]"
# sr_file <path> <verdict block, verbatim> [per-AC FAIL row] [findings body] [per-AC heading]
sr_file() {
  {
    printf '# QA Validation: 1\n\n'; adv_l
    printf '\n## Summary\nSerial.\n\n%s\n\n%s\n\n## Findings\n\n%s\n\n' "${SR_CANON-$CANON_BLK}" "$2" "${4:-### Critical (must fix before PASS)

None.}"
    printf '%s\n\n| AC | Result | Expected | Got |\n|---|---|---|---|\n| AC1 | PASS | x | y |\n' "${5:-## Acceptance Criteria}"
    [ -z "${3:-}" ] || printf '%s\n' "$3"
  } > "$1"
}
sr_run() { # <script-dir> <file> <gate> -> SRC, $CO
  AI_DLC_PROJECT_ROOT="$PROJ" bash "$1/merge-review-shards.sh" --check-serial "$2" --gate "$3" > "$CO" 2>&1 < /dev/null; SRC=$?
}
sr_ok() { # <script-dir> <file> <gate> <case> <verdict>
  sr_run "$1" "$2" "$3"
  [ "$SRC" -eq 0 ] && has "$CO" "SERIAL-OK: $2 verdict=$5" || WHY="$WHY $4{rc=$SRC $(head -1 "$CO")}"
}
sr_no() { # <script-dir> <file> <gate> <case> <token>
  sr_run "$1" "$2" "$3"
  [ "$SRC" -eq 2 ] && [ "$(nref "$CO")" = 1 ] && has "$CO" "$5" && has "$CO" "$SR_OWN" && ! has "$CO" "SERIAL-OK" \
    || WHY="$WHY $4{rc=$SRC $(head -1 "$CO")}"
}
p_serial() {
  local sd="$1" f="$WORK/serial-1-qa-validation.md" g="$WORK/serial-1-code-review.md"
  WHY=""
  if cell sr-q-heading; then sr_file "$f" "$(printf '## Verdict\nPASS')"; sr_ok "$sd" "$f" qa sr-q-heading PASS; fi
  if cell sr-q-line; then sr_file "$f" 'Verdict: NEEDS_REWORK' '' "$(printf '### Important (x)\n\n#### Q-1 a gap\n\nBody.')"; sr_ok "$sd" "$f" qa sr-q-line NEEDS_REWORK; fi
  if cell sr-q-union; then sr_file "$f" "$(printf '## Verdict\n\nVerdict: PASS')"; sr_no "$sd" "$f" qa sr-q-union "$SR_COUNT"; fi
  if cell sr-q-set; then sr_file "$f" "$(printf '## Verdict\nAPPROVED')"; sr_no "$sd" "$f" qa sr-q-set "$SR_SET"; fi
  if cell sr-cr-approved; then sr_file "$g" "$(printf '## Verdict\nAPPROVED')"; sr_ok "$sd" "$g" code-review sr-cr-approved APPROVED; fi
  if cell sr-cr-renamed; then sr_file "$g" "$(printf '## Result\nAPPROVED')"; sr_no "$sd" "$g" code-review sr-cr-renamed "matches Check 1's verdict pattern 0 time(s)"; fi
  if cell sr-q-fail; then sr_file "$f" "$(printf '## Verdict\nPASS')" '| AC4 | FAIL | a RED | none |'; sr_no "$sd" "$f" qa sr-q-fail "$FR_VERD"; fi
  if cell sr-q-fail-backed; then
    sr_file "$f" "$(printf '## Verdict\nNEEDS_REWORK')" '| AC4 | FAIL | a RED | none |' "$(printf '### Important (x)\n\n#### Q-1 AC4 has no committed RED\n\nBody.')"
    sr_ok "$sd" "$f" qa sr-q-fail-backed NEEDS_REWORK
  fi
  # D3: gate 3's own count and value rule, no stricter. A trailing parenthetical and a period read the
  # member; two matches reading ONE value are one verdict; a hyphen suffix is the whole token.
  if cell sr-q-paren; then sr_file "$f" 'Verdict: PASS (all ACs)'; sr_ok "$sd" "$f" qa sr-q-paren PASS; fi
  if cell sr-q-period; then sr_file "$f" "$(printf '## Verdict\n\nPASS.')"; sr_ok "$sd" "$f" qa sr-q-period PASS; fi
  if cell sr-q-twosame; then sr_file "$f" "$(printf '**Verdict:** PASS\n\nQA verdict: PASS')"; sr_ok "$sd" "$f" qa sr-q-twosame PASS; fi
  if cell sr-q-suffix; then sr_file "$f" 'Verdict: PASS-pending'; sr_no "$sd" "$f" qa sr-q-suffix "Check 1 reads 'PASS-pending'"; fi
  if cell sr-q-twodiff; then sr_file "$f" "$(printf '**Verdict:** PASS\n\nQA verdict: NEEDS_REWORK')"; sr_no "$sd" "$f" qa sr-q-twodiff "$SR_COUNT"; fi
  # N2 and N3 through the serial file's own table (one fail_gate for the merge and the serial check):
  # FAILED fires, under a `### Acceptance criteria` heading; AC-4.1 does not name AC-4; a `handover:`
  # line does not name its AC.
  if cell sr-q-failed; then sr_file "$f" "$(printf '## Verdict\nPASS')" '| AC4 | FAILED | a RED | none |' '' '### Acceptance criteria (per AC)'; sr_no "$sd" "$f" qa sr-q-failed "$FR_VERD"; fi
  if cell sr-q-dotted; then
    sr_file "$f" "$(printf '## Verdict\nNEEDS_REWORK')" '| AC-4 | FAIL | a RED | none |' "$(printf '### Important (x)\n\n#### Q-1 a gap\n\nAC-4.1 has no committed RED.')"
    sr_no "$sd" "$f" qa sr-q-dotted "$FR_ORPH AC-4"
  fi
  if cell sr-q-hoonly; then
    sr_file "$f" "$(printf '## Verdict\nNEEDS_REWORK')" '| AC4 | FAIL | a RED | none |' "$(printf '### Important (x)\n\n#### Q-1 a gap\nparts: 1\nhandover: AC4\n\nBody.')"
    sr_no "$sd" "$f" qa sr-q-hoonly "$FR_ORPH AC4"
  fi
  [ -z "$WHY" ]
}
# ---- CR1 (BL-769): a QA PASS waits for its canonical run. Serial cells, each refusal with its ALLOW twin
# one property apart. The record-only cells run --story/--range against CR_REPO, seeded below: a commit
# touching only records (CR_REC) and one touching a test file (CR_CODE), each over CR_BASE.
CR_NORUN="carries no 'Canonical run:' line"
CR_FILT="selects tests by name"
CR_FILE="names a file or test node"
CR_MARK="selects by marker"
CR_PATH="narrows the collection to the path"
CR_DESEL="deselects tests"
CR_GATE1="is not the story's gate-1 base"
CR_NOANC="is not an ancestor of"
CR_NORES="with no 'Canonical result:' line"
CR_UNFIN="says the run has not finished"
CR_NOCNT="carries no count"
CR_NOTRO="is not record-only for"
CR_NORNG="no --story and --range were given"
CR_REPO="$WORK/repo-cr"; CR_STORY=stories/story-1.md
mkdir -p "$CR_REPO/stories" "$CR_REPO/tests" "$CR_REPO/docs/reviews/s1" "$CR_REPO/test-results" \
  && G init -q "$CR_REPO" && printf -- '---\nstatus: ready-for-dev\n---\n# Story 1\n' > "$CR_REPO/$CR_STORY" && printf 'def test_a(): pass\n' > "$CR_REPO/tests/test_a.py" \
  && G -C "$CR_REPO" add -A && G -C "$CR_REPO" commit -q -m base || { echo "FIXTURE ERROR: the canonical-run repo was not seeded" >&2; exit 2; }
CR_BASE="$(G -C "$CR_REPO" rev-parse HEAD)"
printf -- '---\nstatus: review\n---\n# Story 1\nFull-collection run: none, record-only\n' > "$CR_REPO/$CR_STORY"; printf '# r\n' > "$CR_REPO/docs/reviews/s1/1-qa-validation.md"; printf '$ x\n' > "$CR_REPO/test-results/h.txt"
G -C "$CR_REPO" add -A && G -C "$CR_REPO" commit -q -m rec || { echo "FIXTURE ERROR: commit failed" >&2; exit 2; }
CR_REC="$(G -C "$CR_REPO" rev-parse HEAD)"
printf 'def test_a(): assert 1\n' > "$CR_REPO/tests/test_a.py"
G -C "$CR_REPO" add -A && G -C "$CR_REPO" commit -q -m code || { echo "FIXTURE ERROR: commit failed" >&2; exit 2; }
CR_CODE="$(G -C "$CR_REPO" rev-parse HEAD)"
# CR_P2: the rework after a NEEDS_REWORK with no run touches only the story. CR_CODE..CR_P2 is
# record-only; CR_BASE..CR_P2 is not. A seat passing the pass-1 frozen sha as base narrows the range.
printf -- '---\nstatus: review\n---\n# Story 1\nFull-collection run: `pytest -q`: 1 passed\n' > "$CR_REPO/$CR_STORY"
G -C "$CR_REPO" add -A && G -C "$CR_REPO" commit -q -m rework || { echo "FIXTURE ERROR: commit failed" >&2; exit 2; }
CR_P2="$(G -C "$CR_REPO" rev-parse HEAD)"
# CR_EVIL: over CR_BASE, a record-only diff plus a collectable module under test-results/.
G -C "$CR_REPO" checkout -q -b evil "$CR_REC" && printf 'def test_evil():\n    assert False\n' > "$CR_REPO/test-results/test_evil.py" \
  && G -C "$CR_REPO" add -A && G -C "$CR_REPO" commit -q -m evil && CR_EVIL="$(G -C "$CR_REPO" rev-parse HEAD)" \
  && G -C "$CR_REPO" checkout -q - || { echo "FIXTURE ERROR: the evil branch was not seeded" >&2; exit 2; }
# PROJ_CRS: a serial root whose qa.md predates the label (the LEGACY branch of --check-serial).
PROJ_CRS="$WORK/proj-crs"
mkdir -p "$PROJ_CRS/core/skills/ai-dlc/steps" "$PROJ_CRS/core/team-roles" \
  && cp "$PROJ/core/skills/ai-dlc/steps/gate-validation.md" "$PROJ_CRS/core/skills/ai-dlc/steps/" \
  && grep -vF 'column-0 `Canonical run:`' "$QA_MD" > "$PROJ_CRS/core/team-roles/qa.md" || { echo "FIXTURE ERROR: the legacy serial root was not seeded" >&2; exit 2; }
_crs0="$(grep -cF 'column-0 `Canonical run:`' "$PROJ_CRS/core/team-roles/qa.md")" || _crs0=0
[ "$_crs0" = 0 ] || { echo "FIXTURE STALE: the legacy serial root still carries the label" >&2; exit 2; }
# ---- AD (BL-790): THE ADVISOR LINE's era. The sentinel is read from the subject's own files; each
# legacy role file is the subject's with every line carrying it removed, the sentinel-less world the
# reference consumer runs from pull step 3 until the reconcile merge.
AD_SENT='column-0 `advisor:`'
AD_QS="$(grep -cF "$AD_SENT" "$QA_MD")" || AD_QS=0
AD_CS="$(grep -cF "$AD_SENT" "$ROLE_MD")" || AD_CS=0
[ "$AD_QS" -ge 1 ] && [ "$AD_CS" -ge 1 ] \
  || { echo "FIXTURE STALE: qa.md ($AD_QS) or code-reviewer.md ($AD_CS) carries no '$AD_SENT' on one line; every advisor world would be LEGACY" >&2; exit 2; }
AD_LEGQ="$WORK/ad-legacy-qa.md"; AD_LEGC="$WORK/ad-legacy-code-reviewer.md"
grep -vF "$AD_SENT" "$QA_MD" > "$AD_LEGQ"; grep -vF "$AD_SENT" "$ROLE_MD" > "$AD_LEGC"
# PROJ_ADL: a serial root whose two role files lack the advisor sentinel (and keep the canonical one, so
# only the advisor era moves). PROJ_CRS lacks the canonical sentinel and keeps the advisor one.
PROJ_ADL="$WORK/proj-adl"
mkdir -p "$PROJ_ADL/core/skills/ai-dlc/steps" "$PROJ_ADL/core/team-roles" \
  && cp "$PROJ/core/skills/ai-dlc/steps/gate-validation.md" "$PROJ_ADL/core/skills/ai-dlc/steps/" \
  && cp "$AD_LEGQ" "$PROJ_ADL/core/team-roles/qa.md" && cp "$AD_LEGC" "$PROJ_ADL/core/team-roles/code-reviewer.md" \
  || { echo "FIXTURE ERROR: the advisor-legacy serial root was not seeded" >&2; exit 2; }
_ad0="$(cat "$PROJ_ADL/core/team-roles/qa.md" "$PROJ_ADL/core/team-roles/code-reviewer.md" | grep -cF "$AD_SENT")" || _ad0=0
_ad1="$(grep -cF 'column-0 `Canonical run:`' "$PROJ_ADL/core/team-roles/qa.md")" || _ad1=0
[ "$_ad0" = 0 ] && [ "$_ad1" = 1 ] || { echo "FIXTURE STALE: the advisor-legacy root carries the sentinel ($_ad0) or lost the canonical one ($_ad1)" >&2; exit 2; }
# The frozen trees, B's six files over a base that commits both role files at the consumer path:
#   ADP  the sentinel at the frozen sha (the post-reconcile world)
#   ADL  no sentinel at the frozen sha
#   ADA  lead world (a): no sentinel at the frozen sha, the NEW role files written over them on disk after
#        the freeze (the reconcile merged mid-sprint), shards written without the line
#   ADB  lead world (b): the sentinel at the frozen sha, the OLD role files on disk
#   ADU  the untracked world: no role file committed, the NEW ones on disk only
#   ADUL the untracked world over OLD on-disk role files
ad_repo() { # <dir> <committed: new|old|none> <on disk after freeze: new|old|same>
  local r="$1" q c f
  new_repo "$r" old || return 1
  case "$2" in
    new) q="$QA_MD"; c="$ROLE_MD" ;;
    old) q="$AD_LEGQ"; c="$AD_LEGC" ;;
    none) q=""; c="" ;;
  esac
  if [ -n "$q" ]; then
    mkdir -p "$r/.claude/team-roles" && cp "$q" "$r/.claude/team-roles/qa.md" && cp "$c" "$r/.claude/team-roles/code-reviewer.md" \
      && G -C "$r" add -A && G -C "$r" commit -q --amend -m base || return 1
  fi
  for f in alpha/a1.txt alpha/a2.txt beta/b1.txt beta/b2.txt gamma/g1.txt gamma/g2.txt; do lines "$r/$f" 5 "$f"; done
  G -C "$r" add -A && G -C "$r" commit -q -m frozen || return 1
  case "$3" in
    new) mkdir -p "$r/.claude/team-roles" && cp "$QA_MD" "$r/.claude/team-roles/qa.md" && cp "$ROLE_MD" "$r/.claude/team-roles/code-reviewer.md" ;;
    old) mkdir -p "$r/.claude/team-roles" && cp "$AD_LEGQ" "$r/.claude/team-roles/qa.md" && cp "$AD_LEGC" "$r/.claude/team-roles/code-reviewer.md" ;;
  esac
}
REPO_ADP="$WORK/repo-adp"; REPO_ADL="$WORK/repo-adl"; REPO_ADA="$WORK/repo-ada"; REPO_ADB="$WORK/repo-adb"
REPO_ADU="$WORK/repo-adu"; REPO_ADUL="$WORK/repo-adul"
ad_repo "$REPO_ADP" new same && ad_repo "$REPO_ADL" old same && ad_repo "$REPO_ADA" old new \
  && ad_repo "$REPO_ADB" new old && ad_repo "$REPO_ADU" none new && ad_repo "$REPO_ADUL" none old \
  || { echo "FIXTURE ERROR: the advisor-era repositories were not seeded" >&2; exit 2; }
# Each world's refs, and its own control: the committed copy's sentinel count and the on-disk copy's.
ad_at() { # <repo> <role basename> -> "<count at HEAD, or u when untracked> <count on disk, or u>"
  local a b
  if G -C "$1" cat-file -e "HEAD:.claude/team-roles/$2" 2>/dev/null; then
    a="$(G -C "$1" show "HEAD:.claude/team-roles/$2" | grep -cF "$AD_SENT")" || a=0; else a=u; fi
  if [ -f "$1/.claude/team-roles/$2" ]; then b="$(grep -cF "$AD_SENT" "$1/.claude/team-roles/$2")" || b=0; else b=u; fi
  printf '%s %s' "$a" "$(echo "$b" | sed 's/^[1-9][0-9]*$/1/')"
}
for _p in "ADP:1 1" "ADL:0 0" "ADA:0 1" "ADB:1 0" "ADU:u 1" "ADUL:u 0"; do
  eval "_r=\$REPO_${_p%%:*}"
  for _f in qa.md code-reviewer.md; do
    _g="$(ad_at "$_r" "$_f" | sed 's/^[1-9][0-9]* /1 /')"
    [ "$_g" = "${_p#*:}" ] || { echo "FIXTURE STALE: advisor world ${_p%%:*} $_f reads '$_g', want '${_p#*:}' (frozen sha, on disk)" >&2; exit 2; }
  done
done
AD_ABS="carries no column-0 'advisor:' line"
AD_TWO="carries 2 'advisor:' lines outside a fence"
AD_VAL="'advisor: maybe' is not called or unavailable"
AD_MAL="is a malformed advisor line"
AD_NEAR="not the remediator's bulleted '- advisor: called'"
AD_UNR="cannot be read at the frozen sha"
AD_HELD="prescribes it"
ad_leg() { printf 'LEGACY: advisor: line not checked: %s prescribes no %s label' "$1" "$AD_SENT"; } # <path as named>
# ad_var <shard dir> <clean copy> <variant>: every shard back to the clean copy (each carries
# `advisor: called`), then that line rewritten: ABSENT deletes it, TWO doubles it, anything else
# replaces it with the variant's text verbatim (a CR rides in ENVIRON, never through awk -v).
ad_var() {
  local f
  cs_reset "$1" "$2"
  for f in "$1"/*.md; do
    AD_V="$3" awk '$0 == "advisor: called" { v = ENVIRON["AD_V"]
        if (v == "ABSENT") next; if (v == "TWO") { print; print; next }; print v; next } { print }' "$f" > "$f.x" \
      && mv "$f.x" "$f" || return 1
  done
}
# ad_world <script-dir> <gate> <repo tag> -> AD_D (shard dir), AD_C (its clean copy), AD_S (frozen sha),
# AD_R (the repo); every shard carries `advisor: called`.
ad_world() {
  local sd="$1" g="$2" b SHARD_SHA sfx v
  eval "AD_R=\$REPO_$3"
  b="$(G -C "$AD_R" rev-parse HEAD~1)"; AD_S="$(G -C "$AD_R" rev-parse HEAD)"; SHARD_SHA="$AD_S"
  if [ "$g" = qa ]; then sfx=qa-validation; v=PASS; else sfx=code-review; v=APPROVED; fi
  AD_D="$(kworld "$sd" "$AD_R" "$b" "$AD_S" 3 "$sfx" "$v" "$g")" && [ -d "$AD_D" ] || return 1
  AD_C="$(dirname "$AD_D")/clean"; mkdir "$AD_C" && cp "$AD_D"/*.md "$AD_C"/
}
ad_out() { if [ "$2" = qa ]; then qout "$1"; else out_of "$1"; fi; }
ad_ok() { # <script-dir> <gate> <case> <variant> [LEGACY line, by value]: merges, the LEGACY line exactly when named
  local o; o="$(ad_out "$AD_D" "$2")"
  ad_var "$AD_D" "$AD_C" "$4" || { WHY="$WHY $3{the variant did not apply}"; return; }
  run_mg "$1" "$AD_D" "$2" "$o"
  if [ -n "${5:-}" ]; then
    [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && [ "$(grep -c '^LEGACY: advisor:' "$MO")" = 1 ] && grep -qxF -- "$5" "$MO" \
      || WHY="$WHY $3{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
  else
    [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && ! has "$MO" "LEGACY: advisor:" || WHY="$WHY $3{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
  fi
  rm -f "$o"
}
ad_no() { # <script-dir> <gate> <case> <variant> <token> [second token]: REFUSED [owner: 1], the first shard read
  local o; o="$(ad_out "$AD_D" "$2")"
  ad_var "$AD_D" "$AD_C" "$4" || { WHY="$WHY $3{the variant did not apply}"; return; }
  run_mg "$1" "$AD_D" "$2" "$o"
  refused_at "$5" "$o" && owner_in "$MO" 1 && { [ -z "${6:-}" ] || has "$MO" "$6"; } && ! has "$MO" "LEGACY: advisor:" \
    || WHY="$WHY $3{rc=$RC $(reline "$MO")}"
  rm -f "$o"
}
# AD1 (BL-790): THE ADVISOR LINE through the merge, one gate per call. Cells are named ad-<q|c>-<case>.
p_adv_gate() { # <script-dir> <gate>
  local sd="$1" g="$2" x CR; CR="$(printf '\r')"
  if [ "$g" = qa ]; then x=q; else x=c; fi
  WHY=""
  if cs_sel "ad-$x-present-absent" || cs_sel "ad-$x-called" || cs_sel "ad-$x-unavailable" || cs_sel "ad-$x-cr" \
     || cs_sel "ad-$x-maybe" || cs_sel "ad-$x-two" || cs_sel "ad-$x-bullet" || cs_sel "ad-$x-deco"; then
    ad_world "$sd" "$g" ADP || { WHY="the sentinel world was not built"; return 1; }
    if cell "ad-$x-present-absent"; then ad_no "$sd" "$g" "ad-$x-present-absent" ABSENT "$AD_ABS" "$AD_HELD"; fi
    if cell "ad-$x-called"; then ad_ok "$sd" "$g" "ad-$x-called" 'advisor: called'; fi
    if cell "ad-$x-unavailable"; then ad_ok "$sd" "$g" "ad-$x-unavailable" 'advisor: unavailable'; fi
    if cell "ad-$x-cr"; then ad_ok "$sd" "$g" "ad-$x-cr" "advisor: unavailable  $CR"; fi
    if cell "ad-$x-maybe"; then ad_no "$sd" "$g" "ad-$x-maybe" 'advisor: maybe' "$AD_VAL"; fi
    if cell "ad-$x-two"; then ad_no "$sd" "$g" "ad-$x-two" TWO "$AD_TWO"; fi
    if cell "ad-$x-bullet"; then ad_no "$sd" "$g" "ad-$x-bullet" '- advisor: called' "$AD_MAL" "$AD_NEAR"; fi
    if cell "ad-$x-deco"; then ad_no "$sd" "$g" "ad-$x-deco" '**advisor:** called' "$AD_MAL"; fi
  fi
  # The era: the role file the shards were written under, read at the frozen sha.
  if cell "ad-$x-legacy-absent"; then ad_world "$sd" "$g" ADL || { WHY="$WHY the legacy world was not built"; return 1; }
    ad_ok "$sd" "$g" "ad-$x-legacy-absent" ABSENT "$(ad_leg ".claude/team-roles/$(ad_role "$g") at $AD_S")"
    ad_no "$sd" "$g" "ad-$x-legacy-absent" 'advisor: maybe' "$AD_VAL"; fi
  if cell "ad-$x-unreadable-absent"; then ad_world "$sd" "$g" B || { WHY="$WHY the unreadable world was not built"; return 1; }
    ad_no "$sd" "$g" "ad-$x-unreadable-absent" ABSENT "$AD_ABS" "$AD_UNR"; fi
  # Lead world (a): frozen before the reconcile, the new role file on disk; world (b) the reverse.
  if cell "ad-$x-world-a"; then ad_world "$sd" "$g" ADA || { WHY="$WHY world (a) was not built"; return 1; }
    ad_ok "$sd" "$g" "ad-$x-world-a" ABSENT "$(ad_leg ".claude/team-roles/$(ad_role "$g") at $AD_S")"; fi
  if cell "ad-$x-world-b"; then ad_world "$sd" "$g" ADB || { WHY="$WHY world (b) was not built"; return 1; }
    ad_no "$sd" "$g" "ad-$x-world-b" ABSENT "$AD_ABS" ".claude/team-roles/$(ad_role "$g") at $AD_S prescribes it"; fi
  # Untracked at the frozen sha: the on-disk copy decides; with the sentinel the absence is REFUSED
  # naming the fallback and its remedy, without it LEGACY naming the on-disk path.
  if cell "ad-$x-untracked-new"; then ad_world "$sd" "$g" ADU || { WHY="$WHY the untracked world was not built"; return 1; }
    ad_no "$sd" "$g" "ad-$x-untracked-new" ABSENT "$AD_ABS" \
      "$(ad_role "$g") is untracked at $AD_S, read on disk at $AD_R/.claude/team-roles/$(ad_role "$g"), which prescribes it. The on-disk copy may postdate the shards: commit .claude/team-roles/ so the frozen sha decides, or write the line"; fi
  if cell "ad-$x-untracked-old"; then ad_world "$sd" "$g" ADUL || { WHY="$WHY the untracked-old world was not built"; return 1; }
    ad_ok "$sd" "$g" "ad-$x-untracked-old" ABSENT "$(ad_leg "$AD_R/.claude/team-roles/$(ad_role "$g") (on disk, untracked at $AD_S)")"; fi
  [ -z "$WHY" ]
}
ad_role() { if [ "$1" = qa ]; then printf 'qa.md'; else printf 'code-reviewer.md'; fi; }
p_adv_qa() { p_adv_gate "$1" qa; }
p_adv_cr() { p_adv_gate "$1" code-review; }
# AD2 (BL-790): --check-serial, both gates, keyed on the INSTALLED role file (PROJ: the sentinel;
# PROJ_ADL: none). Every cell writes the whole file it reads.
ad_srun() { # <script-dir> <file> <gate> <root> -> SRC, $CO
  AI_DLC_PROJECT_ROOT="$4" bash "$1/merge-review-shards.sh" --check-serial "$2" --gate "$3" > "$CO" 2>&1 < /dev/null; SRC=$?
}
ad_sok() { # <script-dir> <file> <gate> <case> <line text, empty for none>
  SHARD_ADV="$5" sr_file "$2" "$AD_VB"; ad_srun "$1" "$2" "$3" "$PROJ"
  [ "$SRC" -eq 0 ] && has "$CO" "SERIAL-OK: $2" && ! has "$CO" "LEGACY: advisor:" || WHY="$WHY $4{rc=$SRC $(head -1 "$CO")}"
}
ad_sno() { # <script-dir> <file> <gate> <case> <line text, empty for none> <token>
  SHARD_ADV="$5" sr_file "$2" "$AD_VB"; ad_srun "$1" "$2" "$3" "$PROJ"
  [ "$SRC" -eq 2 ] && [ "$(nref "$CO")" = 1 ] && has "$CO" "$6" && has "$CO" "$SR_OWN" && ! has "$CO" "SERIAL-OK" \
    || WHY="$WHY $4{rc=$SRC $(head -1 "$CO")}"
}
p_adv_serial() {
  local sd="$1" g x f CR; CR="$(printf '\r')"
  WHY=""
  for g in qa code-review; do
    if [ "$g" = qa ]; then x=q; AD_VB="$(printf '## Verdict\nPASS')"; f="$WORK/ads-1-qa-validation.md"
    else x=c; AD_VB="$(printf '## Verdict\nAPPROVED')"; f="$WORK/ads-1-code-review.md"; fi
    if cell "ad-s$x-absent"; then ad_sno "$sd" "$f" "$g" "ad-s$x-absent" '' "$AD_ABS"; fi
    if cell "ad-s$x-called"; then ad_sok "$sd" "$f" "$g" "ad-s$x-called" 'advisor: called'; fi
    if cell "ad-s$x-unavailable"; then ad_sok "$sd" "$f" "$g" "ad-s$x-unavailable" 'advisor: unavailable'; fi
    if cell "ad-s$x-cr"; then ad_sok "$sd" "$f" "$g" "ad-s$x-cr" "advisor: unavailable $CR"; fi
    if cell "ad-s$x-maybe"; then ad_sno "$sd" "$f" "$g" "ad-s$x-maybe" 'advisor: maybe' "$AD_VAL"; fi
    if cell "ad-s$x-two"; then ad_sno "$sd" "$f" "$g" "ad-s$x-two" "$(printf 'advisor: called\nadvisor: called')" "$AD_TWO"; fi
    if cell "ad-s$x-bullet"; then ad_sno "$sd" "$f" "$g" "ad-s$x-bullet" '- advisor: called' "$AD_NEAR"; fi
    if cell "ad-s$x-legacy-absent"; then
      SHARD_ADV='' sr_file "$f" "$AD_VB"; ad_srun "$sd" "$f" "$g" "$PROJ_ADL"
      [ "$SRC" -eq 0 ] && has "$CO" "SERIAL-OK: $f" && grep -qxF -- "$(ad_leg "$PROJ_ADL/core/team-roles/$(ad_role "$g")")" "$CO" \
        || WHY="$WHY ad-s$x-legacy-absent{rc=$SRC $(head -2 "$CO" | tr '\n' ' ')}"
    fi
  done
  [ -z "$WHY" ]
}
cr_run() { # <script-dir> <file> [extra args...] -> SRC, $CO (CR_ROOT overrides the project root)
  local sd="$1" f="$2"; shift 2
  AI_DLC_PROJECT_ROOT="${CR_ROOT:-$PROJ}" bash "$sd/merge-review-shards.sh" --check-serial "$f" --gate qa "$@" > "$CO" 2>&1 < /dev/null; SRC=$?
}
cr_ok() { local sd="$1" f="$2" c="$3"; shift 3; cr_run "$sd" "$f" "$@"
  [ "$SRC" -eq 0 ] && has "$CO" "SERIAL-OK:" || WHY="$WHY $c{rc=$SRC $(head -1 "$CO")}"; }
cr_no() { local sd="$1" f="$2" c="$3" t="$4"; shift 4; cr_run "$sd" "$f" "$@"
  [ "$SRC" -eq 2 ] && [ "$(nref "$CO")" = 1 ] && has "$CO" "$t" && has "$CO" "$SR_OWN" && ! has "$CO" "SERIAL-OK" \
    || WHY="$WHY $c{rc=$SRC $(head -1 "$CO")}"; }
p_canon() {
  local sd="$1" f="$CR_REPO/docs/reviews/s1/cr-1-qa-validation.md" pv nv; pv="$(printf '## Verdict\nPASS')"
  WHY=""
  # Every cell is gated by `cell` (BL-755), so a mutant runs only the cell its kill token names. Each
  # cell writes the whole file it reads, and the conventions-file cells write and remove their own copy.
  cr_f() { SR_CANON="$(printf 'Canonical run: `%s` from the root\nCanonical result: 9 passed' "$1")" sr_file "$f" "$pv"; }
  cr_conv() { printf -- '- canonical: `pytest suite/tests` and `<venv>/bin/python -m pytest -m unit`\n' > "$CR_REPO/docs/coding-conventions.md"; }
  cr_noconv() { rm -f "$CR_REPO/docs/coding-conventions.md"; }
  SR_NONE='Canonical run: none, the diff is record-only (story, reviews, test-results)'
  if cell cr-ok; then SR_CANON="$CANON_BLK" sr_file "$f" "$pv"; cr_ok "$sd" "$f" cr-ok; fi
  if cell cr-norun; then SR_CANON='' sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-norun "$CR_NORUN"; fi
  # graph s319 5.1 p1's shape: the only counts are on a RED replay line, and the run line says nothing.
  if cell cr-redonly; then SR_CANON="$(printf 'RED replay: 1 failed, 4 passed\nThe canonical run is still in progress.')" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-redonly "$CR_NORUN"; fi
  # The filter grammar (record-only-diff.sh RUN-FILTER). With no docs/coding-conventions.md, -m is
  # accepted and a path refused; cr_conv declares `pytest -m unit` and `pytest suite/tests`.
  if cell cr-filter-k; then cr_noconv; cr_f 'pytest -k test_new'; cr_no "$sd" "$f" cr-filter-k "$CR_FILT"; fi
  if cell cr-filter-kglued; then cr_noconv; cr_f 'pytest -ktest_new'; cr_no "$sd" "$f" cr-filter-kglued "$CR_FILT"; fi
  if cell cr-filter-kquoted; then cr_noconv; cr_f 'pytest -k"test_new"'; cr_no "$sd" "$f" cr-filter-kquoted "$CR_FILT"; fi
  if cell cr-filter-keyword; then cr_noconv; cr_f 'pytest --keyword=x'; cr_no "$sd" "$f" cr-filter-keyword "$CR_FILT"; fi
  if cell cr-deselect; then cr_noconv; cr_f 'pytest --deselect tests/test_a.py::t'; cr_no "$sd" "$f" cr-deselect "$CR_DESEL"; fi
  if cell cr-file; then cr_noconv; cr_f 'pytest tests/test_one.py'; cr_no "$sd" "$f" cr-file "$CR_FILE"; fi
  if cell cr-node; then cr_noconv; cr_f 'pytest tests/test_one.py::test_a'; cr_no "$sd" "$f" cr-node "$CR_FILE"; fi
  if cell cr-m-noconv; then cr_noconv; cr_f '.venv/bin/python -m pytest -m unit -q'; cr_ok "$sd" "$f" cr-m-noconv; fi
  if cell cr-path-noconv; then cr_noconv; cr_f 'pytest suite/tests -n auto'; cr_no "$sd" "$f" cr-path-noconv "$CR_PATH"; fi
  if cell cr-m-conv; then cr_conv; cr_f '.venv/bin/python -m pytest -m unit -q'; cr_ok "$sd" "$f" cr-m-conv; cr_noconv; fi
  if cell cr-m-glued-conv; then cr_conv; cr_f '.venv/bin/python -m pytest -munit'; cr_ok "$sd" "$f" cr-m-glued-conv; cr_noconv; fi
  if cell cr-m-other; then cr_conv; cr_f 'pytest -m "not slow"'; cr_no "$sd" "$f" cr-m-other "$CR_MARK"; cr_noconv; fi
  if cell cr-path-conv; then cr_conv; cr_f 'cd /w && pytest suite/tests -n auto > out.txt 2>&1'; cr_ok "$sd" "$f" cr-path-conv; cr_noconv; fi
  if cell cr-path-other; then cr_conv; cr_f 'pytest other/tests'; cr_no "$sd" "$f" cr-path-other "$CR_PATH"; cr_noconv; fi
  # Narrowing to any runner (BL-769 fold): a test-file argument, go's -run, --lf, -x with --ff, and an
  # argument after `--`; --ff alone runs everything. A path root CONTAINING the declared root is a
  # superset of it, accepted; one inside it is narrowing.
  if cell cr-filter-suffix; then cr_noconv; cr_f 'npx vitest run web/src/foo.test.jsx --root web'; cr_no "$sd" "$f" cr-filter-suffix "$CR_FILE"; fi
  if cell cr-filter-gorun; then cr_noconv; cr_f 'go test ./pkg/one -run TestX'; cr_no "$sd" "$f" cr-filter-gorun "$CR_FILT"; fi
  if cell cr-filter-lf; then cr_conv; cr_f 'pytest suite/tests -x --lf'; cr_no "$sd" "$f" cr-filter-lf "re-runs only the last failures"; cr_noconv; fi
  if cell cr-filter-xff; then cr_conv; cr_f 'pytest suite/tests -x --ff'; cr_no "$sd" "$f" cr-filter-xff "stops at the first of the previous failures"; cr_noconv; fi
  if cell cr-filter-ff; then cr_conv; cr_f 'pytest suite/tests --ff'; cr_ok "$sd" "$f" cr-filter-ff; cr_noconv; fi
  if cell cr-filter-dd; then cr_noconv; cr_f 'npm test -- src/pages'; cr_no "$sd" "$f" cr-filter-dd "hands the runner a path after --"; fi
  if cell cr-path-super; then cr_conv; cr_f 'python3 -m pytest -q suite -p no:cacheprovider -p no:randomly'; cr_ok "$sd" "$f" cr-path-super; cr_noconv; fi
  # A runner the built-in list does not name is a run only when the conventions declare it canonical.
  if cell cr-conv-runner; then printf -- '- canonical: `tox -e all` from the repository root\n' > "$CR_REPO/docs/coding-conventions.md"; cr_f 'tox -e all'; cr_ok "$sd" "$f" cr-conv-runner; cr_noconv; fi
  if cell cr-conv-runner-none; then cr_noconv; cr_f 'tox -e all'; cr_no "$sd" "$f" cr-conv-runner-none "$CR_NORNG"; fi
  if cell cr-path-sub; then cr_conv; cr_f 'pytest suite/tests/unit'; cr_no "$sd" "$f" cr-path-sub "$CR_PATH"; cr_noconv; fi
  if cell cr-nearfilter; then SR_CANON="$(printf 'Canonical run: `pytest -p no:cacheprovider` from the root, see tests/foo-k.py\nCanonical result: 9 passed')" sr_file "$f" "$pv"; cr_ok "$sd" "$f" cr-nearfilter; fi
  if cell cr-nores; then SR_CANON='Canonical run: `pytest -q` from the root' sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-nores "$CR_NORES"; fi
  if cell cr-unfin; then SR_CANON="$(printf 'Canonical run: `pytest -q`\nCanonical result: NOT FINISHED at 44%%, 3801 passed so far')" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-unfin "$CR_UNFIN"; fi
  if cell cr-nocnt; then SR_CANON="$(printf 'Canonical run: `pytest -q`\nCanonical result: green')" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-nocnt "$CR_NOCNT"; fi
  if cell cr-bullet; then SR_CANON="$(printf -- '- Canonical run: `pytest -q` from the root\n- Canonical result: 12 failed, 8799 passed, 0 deselected')" sr_file "$f" "$pv"; cr_ok "$sd" "$f" cr-bullet; fi
  # NEEDS_REWORK with no run at all: an early REJECT is legitimate.
  if cell cr-nr-norun; then SR_CANON='' sr_file "$f" 'Verdict: NEEDS_REWORK' '' "$(printf '### Important (x)\n\n#### Q-1 the handoff lacks the run\n\nBody.')"; cr_ok "$sd" "$f" cr-nr-norun; fi
  # The exemption: record-only PASS accepted over CR_BASE..CR_REC, refused over CR_BASE..CR_CODE and with no range.
  if cell cr-exempt-rec; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_ok "$sd" "$f" cr-exempt-rec --story "$CR_STORY" --range "$CR_BASE" "$CR_REC"; fi
  if cell cr-exempt-code; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-exempt-code "$CR_NOTRO" --story "$CR_STORY" --range "$CR_BASE" "$CR_CODE"; fi
  if cell cr-exempt-norange; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-exempt-norange "$CR_NORNG"; fi
  # A collectable module under test-results/ is not a record.
  if cell cr-exempt-evil; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-exempt-evil "$CR_NOTRO" --story "$CR_STORY" --range "$CR_BASE" "$CR_EVIL"; fi
  # The exemption's base is a gate-1 base. The pass-2 sequence (code at CR_CODE, a story-only rework at
  # CR_P2) is refused over the seat's narrowed CR_CODE..CR_P2 (the story at CR_CODE is already
  # `review`), and an empty CR_CODE..CR_CODE too; over the whole story the partition refuses it.
  if cell cr-exempt-narrow; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-exempt-narrow "$CR_GATE1" --story "$CR_STORY" --range "$CR_CODE" "$CR_P2"; fi
  if cell cr-exempt-empty; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-exempt-empty "$CR_GATE1" --story "$CR_STORY" --range "$CR_CODE" "$CR_CODE"; fi
  if cell cr-exempt-whole; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-exempt-whole "$CR_NOTRO" --story "$CR_STORY" --range "$CR_BASE" "$CR_P2"; fi
  if cell cr-exempt-nonanc; then SR_CANON="$SR_NONE" sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-exempt-nonanc "$CR_NOANC" --story "$CR_STORY" --range "$CR_CODE" "$CR_REC"; fi
  if cell cr-bare; then SR_CANON='Canonical run: none' sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-bare "gives no reason" --story "$CR_STORY" --range "$CR_BASE" "$CR_REC"; fi
  # A no-run claim spelled other than none is held to the partition, accepted on a record range.
  if cell cr-norun-na; then SR_CANON='Canonical run: N/A, docs-only story' sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-norun-na "$CR_NOTRO" --story "$CR_STORY" --range "$CR_BASE" "$CR_CODE"; fi
  # The none is read before the run shape: a none whose reason names a runner span is a no-run claim.
  if cell cr-norun-nonebt; then SR_CANON='Canonical run: none, `pytest -q` is not needed for a docs-only story' sr_file "$f" "$pv"; cr_no "$sd" "$f" cr-norun-nonebt "$CR_NOTRO" --story "$CR_STORY" --range "$CR_BASE" "$CR_CODE"; fi
  if cell cr-norun-other; then
    for nv in 'TBD' 'skipped, no code of note'; do
      SR_CANON="Canonical run: $nv" sr_file "$f" "$pv"
      cr_no "$sd" "$f" "cr-norun-other[$nv]" "$CR_NOTRO" --story "$CR_STORY" --range "$CR_BASE" "$CR_CODE"
    done
  fi
  if cell cr-norun-rec; then
    for nv in 'N/A, docs-only story' 'TBD' 'skipped, no code of note'; do
      SR_CANON="Canonical run: $nv" sr_file "$f" "$pv"
      cr_ok "$sd" "$f" "cr-norun-rec[$nv]" --story "$CR_STORY" --range "$CR_BASE" "$CR_REC"
    done
  fi
  # --check-serial against a root whose qa.md lacks the sentinel prints LEGACY and accepts.
  if cell cr-serial-legacy; then
    SR_CANON='' sr_file "$f" "$pv"
    CR_ROOT="$PROJ_CRS" cr_run "$sd" "$f"
    [ "$SRC" -eq 0 ] && has "$CO" "LEGACY: canonical-run lines not checked:" && has "$CO" "SERIAL-OK:" || WHY="$WHY cr-serial-legacy{rc=$SRC $(head -1 "$CO")}"
  fi
  rm -f "$f"
  [ -z "$WHY" ]
}
# CR2: the merge holds the execution owner's file (cross-1) to the rule, and a frozen tree whose
# INSTALLED qa.md carries no label is LEGACY. QS installs the subject's qa.md, QL a container-less copy
# that also predates the label (it is derived from the subject, so the label is stripped explicitly).
CR_LEG="LEGACY: canonical-run lines not checked:"
p_canon_merge() {
  local sd="$1" d o SHARD_SHA
  WHY=""
  crm_strip() { grep -v '^Canonical r' "$1/cross-1.md" > "$1/x.tmp" && mv "$1/x.tmp" "$1/cross-1.md"; }
  if cell crm-ok; then
    d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="the qa world was not built"; return 1; }
    o="$(qout "$d")"; q_merge "$sd" "$d"
    [ "$RC" -eq 0 ] && has "$MO" "MERGED:" && ! has "$MO" "$CR_LEG" || WHY="$WHY crm-ok{rc=$RC $(head -1 "$MO")}"
    rm -f "$o"
  fi
  if cell crm-norun; then
    d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="$WHY the qa world was not built"; return 1; }
    crm_strip "$d"; o="$(qout "$d")"; q_merge "$sd" "$d"
    refused_at "$CR_NORUN" "$o" && owner_in "$MO" cross-1 || WHY="$WHY crm-norun{rc=$RC $(reline "$MO")}"
    rm -f "$o"
  fi
  if cell crm-nr-norun; then
    d="$(qworld "$sd" PASS NEEDS_REWORK PASS PASS)" || { WHY="$WHY the qa world was not built"; return 1; }
    crm_strip "$d"; o="$(qout "$d")"; q_merge "$sd" "$d"
    [ "$RC" -eq 0 ] && has "$MO" "verdict=NEEDS_REWORK" || WHY="$WHY crm-nr-norun{rc=$RC $(head -1 "$MO")}"
    rm -f "$o"
  fi
  if cell crm-legacy; then
    SHARD_SHA="$CRL_SHA"
    d="$(kworld "$sd" "$REPO_CRL" "$CRL_BASE" "$CRL_SHA" 3 qa-validation PASS qa)" || { WHY="$WHY the legacy world was not built"; return 1; }
    crm_strip "$d"; o="$(qout "$d")"; q_merge "$sd" "$d"
    [ "$RC" -eq 0 ] && has "$MO" "$CR_LEG" && has "$MO" "MERGED:" || WHY="$WHY crm-legacy{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
    rm -f "$o"
  fi
  # qa.md NOT tracked at the frozen sha, installed on disk in the manifest's worktree: the on-disk copy
  # decides. Without the label: LEGACY and merges. With it: held, a run-less PASS refused. Neither: held,
  # naming both paths. Each cell writes (or removes) the on-disk copy itself and removes it after.
  if cell crm-disk-legacy; then
    SHARD_SHA="$CRU_SHA"; cp "$CRU_OLD" "$REPO_CRU/.claude/team-roles/qa.md"
    d="$(kworld "$sd" "$REPO_CRU" "$CRU_BASE" "$CRU_SHA" 3 qa-validation PASS qa)" || { WHY="$WHY the untracked world was not built"; return 1; }
    crm_strip "$d"; o="$(qout "$d")"; q_merge "$sd" "$d"
    [ "$RC" -eq 0 ] && has "$MO" "$CR_LEG" && has "$MO" "(on disk, untracked at" && has "$MO" "MERGED:" || WHY="$WHY crm-disk-legacy{rc=$RC $(head -2 "$MO" | tr '\n' ' ')}"
    rm -f "$o" "$REPO_CRU/.claude/team-roles/qa.md"
  fi
  if cell crm-disk-held; then
    SHARD_SHA="$CRU_SHA"; cp "$QA_MD" "$REPO_CRU/.claude/team-roles/qa.md"
    d="$(kworld "$sd" "$REPO_CRU" "$CRU_BASE" "$CRU_SHA" 3 qa-validation PASS qa)" || { WHY="$WHY the untracked world was not built"; return 1; }
    crm_strip "$d"; o="$(qout "$d")"; q_merge "$sd" "$d"
    refused_at "$CR_NORUN" "$o" && ! has "$MO" "$CR_LEG" || WHY="$WHY crm-disk-held{rc=$RC $(reline "$MO")}"
    rm -f "$o" "$REPO_CRU/.claude/team-roles/qa.md"
  fi
  if cell crm-neither; then
    SHARD_SHA="$CRU_SHA"; rm -f "$REPO_CRU/.claude/team-roles/qa.md"
    d="$(kworld "$sd" "$REPO_CRU" "$CRU_BASE" "$CRU_SHA" 3 qa-validation PASS qa)" || { WHY="$WHY the untracked world was not built"; return 1; }
    crm_strip "$d"; o="$(qout "$d")"; q_merge "$sd" "$d"
    refused_at "$CR_NORUN" "$o" && has "$MO" "nor on disk at $REPO_CRU/.claude/team-roles/qa.md" || WHY="$WHY crm-neither{rc=$RC $(reline "$MO")}"
    rm -f "$o"
  fi
  # The merge takes no --range (it would only narrow the manifest's whole-story range).
  if cell crm-range; then
    d="$(qworld "$sd" PASS PASS PASS PASS)" || { WHY="$WHY the qa world was not built"; return 1; }
    o="$(qout "$d")"
    AI_DLC_PROJECT_ROOT="$PROJ" bash "$sd/merge-review-shards.sh" "$d" --gate qa --out "$o" --story x.md --range "$B_SHA" "$B_SHA" > "$MO" 2>&1 < /dev/null; RC=$?
    refused_at "--range is read only by --check-serial" "$o" || WHY="$WHY crm-range{rc=$RC $(reline "$MO")}"
    rm -f "$o"
  fi
  [ -z "$WHY" ]
}
# REPO_CRL: B's six files over a base installing a qa.md WITHOUT the canonical-run label (consumer layout).
REPO_CRL="$WORK/repo-crl"
new_repo "$REPO_CRL" old && mkdir -p "$REPO_CRL/.claude/team-roles" \
  && grep -vF 'column-0 `Canonical run:`' "$QA_MD" > "$REPO_CRL/.claude/team-roles/qa.md" \
  && G -C "$REPO_CRL" add -A && G -C "$REPO_CRL" commit -q --amend -m base || { echo "FIXTURE ERROR: the legacy qa.md repo was not seeded" >&2; exit 2; }
for f in alpha/a1.txt alpha/a2.txt beta/b1.txt beta/b2.txt gamma/g1.txt gamma/g2.txt; do lines "$REPO_CRL/$f" 5 "$f"; done
G -C "$REPO_CRL" add -A && G -C "$REPO_CRL" commit -q -m frozen || { echo "FIXTURE ERROR: commit failed" >&2; exit 2; }
CRL_BASE="$(G -C "$REPO_CRL" rev-parse HEAD~1)"; CRL_SHA="$(G -C "$REPO_CRL" rev-parse HEAD)"
_crl="$(G -C "$REPO_CRL" show "${CRL_SHA}:.claude/team-roles/qa.md" | grep -cF 'column-0 `Canonical run:`')" || _crl=0
_crs="$(grep -cF 'column-0 `Canonical run:`' "$QA_MD")" || _crs=0
[ "$_crl" = 0 ] && [ "$_crs" -ge 1 ] \
  || { echo "FIXTURE STALE: the legacy qa.md cannot express the canonical-run boundary (installed $_crl, subject $_crs)" >&2; exit 2; }
# REPO_CRU: B's six files with NO qa.md tracked at either sha; the cells write the on-disk copy.
REPO_CRU="$WORK/repo-cru"; CRU_OLD="$WORK/qa-nolabel.md"
grep -vF 'column-0 `Canonical run:`' "$QA_MD" > "$CRU_OLD"
new_repo "$REPO_CRU" old && mkdir -p "$REPO_CRU/.claude/team-roles" || { echo "FIXTURE ERROR: the untracked qa.md repo was not seeded" >&2; exit 2; }
for f in alpha/a1.txt alpha/a2.txt beta/b1.txt beta/b2.txt gamma/g1.txt gamma/g2.txt; do lines "$REPO_CRU/$f" 5 "$f"; done
G -C "$REPO_CRU" add -A && G -C "$REPO_CRU" commit -q -m frozen || { echo "FIXTURE ERROR: commit failed" >&2; exit 2; }
CRU_BASE="$(G -C "$REPO_CRU" rev-parse HEAD~1)"; CRU_SHA="$(G -C "$REPO_CRU" rev-parse HEAD)"
G -C "$REPO_CRU" cat-file -e "${CRU_SHA}:.claude/team-roles/qa.md" 2>/dev/null \
  && { echo "FIXTURE STALE: qa.md is tracked in the untracked-qa.md repo" >&2; exit 2; }
# Role text (BL-742): each serial seat is told to run --check-serial before returning. Keyed on the
# command spelling in each role file's serial passage.
SR_ROLE_CMD='merge-review-shards.sh --check-serial'
p_serial_role() { # <qa.md> <code-reviewer.md>
  local nq nc
  nq="$(grep -cF -- "$SR_ROLE_CMD <validation file> --gate qa" "$1")" || nq=0
  nc="$(grep -cF -- "$SR_ROLE_CMD <review file> --gate code-review" "$2")" || nc=0
  [ "$nq" -ge 1 ] && [ "$nc" -ge 1 ]
}

# Seed controls: the worlds must be able to express what the arms are named for. Both callers run
# them before any arm or mutant verdict is read.
seed_controls() { # W0, W1, W2, W3, W4
local A_NAMES A_REV na nn n1 c1 c0 nb ns nr0 nr1 pf
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
# W3: the engines at the frozen shas. The subject carries the sentinel once, the derived old engine
# none; B's frozen sha holds the old one (consumer layout), S's the subject (distribution layout), N's
# neither -- and N's commit IS readable (its README), so "absent" is not "unreadable".
c1="$(grep -c '# MARK-KEY-WRITER v1' "$WFD_SRC")" || c1=0
c0="$(grep -c '# MARK-KEY-WRITER v1' "$OLD_ENGINE")" || c0=0
nb="$(G -C "$REPO_B" show "${B_SHA}:scripts/ai-dlc/wait-for-deliverable.sh" 2>/dev/null | grep -c '# MARK-KEY-WRITER v1')" || nb=0
ns="$(G -C "$REPO_S" show "${S_SHA}:core/scripts/wait-for-deliverable.sh" 2>/dev/null | grep -c '# MARK-KEY-WRITER v1')" || ns=0
if [ "$c1" = 1 ] && [ "$c0" = 0 ] && ! cmp -s "$WFD_SRC" "$OLD_ENGINE" && [ "$nb" = 0 ] && [ "$ns" = 1 ] \
   && G -C "$REPO_B" cat-file -e "${B_SHA}:scripts/ai-dlc/wait-for-deliverable.sh" 2>/dev/null \
   && ! G -C "$REPO_N" cat-file -e "${N_SHA}:scripts/ai-dlc/wait-for-deliverable.sh" 2>/dev/null \
   && ! G -C "$REPO_N" cat-file -e "${N_SHA}:core/scripts/wait-for-deliverable.sh" 2>/dev/null \
   && G -C "$REPO_N" cat-file -e "${N_SHA}:README" 2>/dev/null; then
  ok "W3: the subject's --mark carries the sentinel once and the derived old engine none; B's frozen sha holds the old engine, S's the sentinel engine, N's neither (N's README read as the control)"
else
  bad "W3: FIXTURE BROKEN -- the engine blobs cannot express the legacy rule (subject $c1, old $c0, at B $nb, at S $ns)"
fi
# W4: the recorder writes. MAIN's sourced copy is the subject's bytes; a fire on a review-shard path
# appends one row carrying path, physical root and body_sha; a fire on a path outside the sealed sets
# appends none (the control that the count can stay put).
pf="$MAIN/docs/reviews/s0.probe/shards/1-code-review-$B_SHA12/1.md"; mkdir -p "$(dirname "$pf")" && printf '# probe\n' > "$pf"
nr0="$(grep -c . "$LEDGER" 2>/dev/null)" || nr0=0
printf 'x\n' > "$MAIN/notes.md"; fire "$MAIN/notes.md" agent; nr1="$(grep -c . "$LEDGER" 2>/dev/null)" || nr1=0
if cmp -s "$SEAL_SRC" "$MAIN/scripts/ai-dlc/content-seal.sh" && cmp -s "$SEAL_SRC" "$DMAIN/core/scripts/content-seal.sh" \
   && [ "$nr1" = "$nr0" ] && fire "$pf" agent \
   && [ "$(jq -c --arg r "$MAIN" 'select(.path == "docs/reviews/s0.probe/shards/1-code-review-'"$B_SHA12"'/1.md" and .root == $r and has("body_sha"))' "$LEDGER" | grep -c .)" = 1 ]; then
  ok "W4: the recorder hook, fired with a seat's payload, appends one review-shard row (path, physical root, body_sha) to the main checkout's ledger, and none for a path outside the sealed sets"
else
  bad "W4: FIXTURE BROKEN -- the recorder hook did not write the review-shard row the seal arms read (rows $nr0 -> $nr1 on a non-shard path)"
fi
}
