#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# derivation-differential — assert reconcile/derivation-differential.sh clears the
# `WORKLIST artifact-derivations` row on what THIS PULL broke, and on nothing else.
#
# Usage: run.sh [<path-to-derivation-differential.sh>]
#   The argument existed for a retired mutation battery, which drove this file against
#   mutated copies. With no argument the subject is found beside this fixture in either layout.
# Exit: 0 every assertion holds | 1 something regressed | 2 the harness could not run.
#
# EVERY WORLD IS SEEDED AT HAND-BACK SHAPE, because that is the one moment the helper runs: the
# consumer's stamp reads <base> on BOTH roots (HEAD carries it, and the apply leaves it withheld),
# the apply is UNCOMMITTED in the working tree, and the helper finds the base root itself from
# the stamp. A world seeded after the step-8 commit would exercise a different base commit and a
# restored stamp-equality gate would pass it. The consumer's first-parent chain carries an OLDER
# stamp one commit down, so a walk that took the wrong end of the chain lands on a tree where the
# changed path holds different text.
#
# THE VALIDATOR IS THE REAL ONE, copied from this tree into each consumer as the installer would.
# An `exit 0` stub scores every derivation PASS on both sides, and every arm below would then be
# reading the helper's arithmetic over an empty FAIL set rather than over the validator's verdicts.
#
# ONE CORPUS CARRIES EVERY CLASS AT ONCE, so each arm asks WHICH derivation lands in a class, not
# only whether the class is non-empty: qqalpha passes at base and fails after the apply
# (NEWLY-FAILING), qqbeta is stale on both sides (STALE-BOTH), qqgamma reproduces on both (no
# row), and a `perl` line is refused by the allowlist (UNASSESSABLE). The clean-pair world is the
# near-miss of the offender and differs from it in ONE property: the applied text keeps qqalpha.
#
# EVERY REFUSAL ARM ASSERTS ITS DIAGNOSIS, NOT ONLY EXIT 2. Several guards in the helper refuse
# the same bad input in sequence; an arm keyed on the status alone passes with its own guard
# deleted whenever a later one catches the same world.
#
# ROOT RESOLUTION IS BY CANDIDATE PATHS FROM THIS FILE, NOT A WALK FOR `VERSION`. This fixture
# ships, and an installed consumer carries no VERSION file (I106).
set -uo pipefail

for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset CLAUDE_PROJECT_DIR 2>/dev/null || true

HERE="$(cd "$(dirname "$0")" && pwd)"
pick() { for c in "$@"; do [ -n "$c" ] && [ -f "$c" ] && { printf '%s' "$c"; return; }; done; }
SUBJ="$(pick "${1:-}" \
  "$HERE/../../skills/ai-dlc-update/reconcile/derivation-differential.sh" \
  "$HERE/../../../core/skills/ai-dlc-update/reconcile/derivation-differential.sh" \
  "$HERE/../../../.claude/skills/ai-dlc-update/reconcile/derivation-differential.sh")"

# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT: the fixture can arrive in one pull and the helper in
# the next, so an absent subject SKIPS LOUDLY rather than passing.
if [ -z "$SUBJ" ]; then
  echo "SKIP: derivation-differential.sh is not present in this tree yet (a core fixture ships ahead of its subject). Nothing was asserted."
  exit 0
fi
SUBJ="$(cd "$(dirname "$SUBJ")" && pwd)/$(basename "$SUBJ")"
printf 'HERMETIC-CONSUMED %s\n' "$SUBJ"

VALIDATOR="$(pick "$HERE/../../scripts/validate-artifact-derivations.sh" \
                  "$HERE/../../../scripts/ai-dlc/validate-artifact-derivations.sh" \
                  "$HERE/../../../core/scripts/validate-artifact-derivations.sh")"
[ -n "$VALIDATOR" ] || { echo "FIXTURE ERROR: cannot locate validate-artifact-derivations.sh, which the helper runs on both sides" >&2; exit 2; }
printf 'HERMETIC-CONSUMED %s\n' "$(cd "$(dirname "$VALIDATOR")" && pwd)/$(basename "$VALIDATOR")"

# THE SCOPE CLASSIFIER IS THE REAL ONE TOO. The helper's join keeps only the artifact files that
# `check-owed-derivations.sh --scope-batch` calls CURRENT or LIVING, and reads that script, its sibling
# sprint-status.sh and the schema sprint-status.sh loads out of the DISTRIBUTION at <theirs>. A stub
# would score every file in scope and the S arms below would read the helper over a classifier that
# never says PAST. Each is seeded into the FIRST commit of every distribution, so it is present and
# byte-identical at every ref and never enters the changed set (A8 counts changed paths exactly).
CLASSIFIER="$(pick "$HERE/../../scripts/check-owed-derivations.sh" \
                   "$HERE/../../../scripts/ai-dlc/check-owed-derivations.sh" \
                   "$HERE/../../../core/scripts/check-owed-derivations.sh")"
SPRINTSH="$(pick "$HERE/../../scripts/sprint-status.sh" \
                 "$HERE/../../../scripts/ai-dlc/sprint-status.sh" \
                 "$HERE/../../../core/scripts/sprint-status.sh")"
SPRINTSCHEMA="$(pick "$HERE/../../schemas/sprint-status.json" \
                     "$HERE/../../../.claude/schemas/sprint-status.json" \
                     "$HERE/../../../core/schemas/sprint-status.json")"
[ -n "$CLASSIFIER" ] && [ -n "$SPRINTSH" ] && [ -n "$SPRINTSCHEMA" ] \
  || { echo "FIXTURE ERROR: cannot locate check-owed-derivations.sh, sprint-status.sh or sprint-status.json, which the helper's scope join reads out of the distribution" >&2; exit 2; }

printf 'HERMETIC-CONSUMED core/scripts/check-owed-derivations.sh\n'
printf 'HERMETIC-CONSUMED core/scripts/sprint-status.sh\n'
printf 'HERMETIC-CONSUMED core/schemas/sprint-status.json\n'

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# The helper makes its scratch and base-worktree directories under $TMPDIR; pointing that at a
# directory this fixture owns is what lets arm A10 assert nothing was left behind.
DDTMP="$WORK/ddtmp"; mkdir -p "$DDTMP"

echo "derivation-differential:"
printf '  subject: %s\n' "$SUBJ"

g() { # g <dir> <git args...> -- hermetic identity, no hooks, no signing
  local d="$1"; shift
  git -C "$d" -c user.name=fixture -c user.email=fixture@example.invalid \
    -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"
}

fails=0
ok()  { printf '  ok    %s\n' "$1"; }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails + 1)); }
# HERE-STRINGS, NEVER `printf | grep -q` (I54/I54b).
ck() { if grep -qF -- "$2" <<<"$3"; then ok "$1"; else bad "$1 -- expected to find: $2"; printf '%s\n' "$3" | sed 's/^/        | /' | head -20; fi; }
nk() { if grep -qF -- "$2" <<<"$3"; then bad "$1 -- must NOT contain: $2"; else ok "$1"; fi; }
rc_is() { if [ "$2" = "$3" ]; then ok "$1"; else bad "$1 -- exit was $3, expected $2"; fi; }
# rows_of <status> <output> -> the keys (column 2) of every row with that status, one per line
rows_of() { awk -F'\t' -v s="$1" '$1 == s { print $2 }' <<<"$2"; }
# nrows <status> <output> -> how many rows carry that status (awk, so zero prints 0 and exits 0)
nrows() { awk -F'\t' -v s="$1" '$1 == s { n++ } END { print n + 0 }' <<<"$2"; }

# seed_cls <dist> -- the scope classifier and what it loads, into <dist>'s working tree
seed_cls() {
  mkdir -p "$1/core/scripts" "$1/core/schemas"
  cp "$CLASSIFIER" "$1/core/scripts/check-owed-derivations.sh"
  cp "$SPRINTSH" "$1/core/scripts/sprint-status.sh"
  cp "$SPRINTSCHEMA" "$1/core/schemas/sprint-status.json"
}

# ---- the distribution ---------------------------------------------------------------------
DIST="$WORK/dist"
mkdir -p "$DIST/core/scripts"
g "$DIST" init -q
printf 'qqprev\n' > "$DIST/core/scripts/toy.sh"
seed_cls "$DIST"
g "$DIST" add -A && g "$DIST" commit -qm prev
PREV="$(g "$DIST" rev-parse HEAD)"
printf 'qqalpha\nqqgamma\n' > "$DIST/core/scripts/toy.sh"
g "$DIST" add -A && g "$DIST" commit -qm base
BASE="$(g "$DIST" rev-parse HEAD)"
# THEIRS_BREAK drops qqalpha; THEIRS_KEEP keeps it and still changes the file, so both ranges
# carry the same changed path and only the verdict on qqalpha separates them.
printf 'qqgamma\nqqdelta\n' > "$DIST/core/scripts/toy.sh"
g "$DIST" add -A && g "$DIST" commit -qm theirs-break
THEIRS_BREAK="$(g "$DIST" rev-parse HEAD)"
g "$DIST" checkout -q "$BASE" 2>/dev/null
printf 'qqalpha\nqqgamma\nqqdelta\n' > "$DIST/core/scripts/toy.sh"
g "$DIST" add -A && g "$DIST" commit -qm theirs-keep
THEIRS_KEEP="$(g "$DIST" rev-parse HEAD)"
# SIDE is a commit off PREV that is neither <base> nor an ancestor of it: the near-miss of a
# `skill_commit:` that is legitimately BEHIND <base> (PREV).
g "$DIST" checkout -q "$PREV" 2>/dev/null
printf 'qqside\n' > "$DIST/core/scripts/side.sh"
g "$DIST" add -A && g "$DIST" commit -qm side
SIDE="$(g "$DIST" rev-parse HEAD)"
[ -n "$PREV" ] && [ -n "$BASE" ] && [ -n "$THEIRS_BREAK" ] && [ -n "$THEIRS_KEEP" ] && [ -n "$SIDE" ] \
  || { echo "FIXTURE ERROR: seeded dist refs unresolvable" >&2; exit 2; }
g "$DIST" merge-base --is-ancestor "$PREV" "$BASE" && ! g "$DIST" merge-base --is-ancestor "$SIDE" "$BASE" \
  || { echo "FIXTURE ERROR: PREV must be an ancestor of BASE and SIDE must not" >&2; exit 2; }
[ "$PREV" != "$BASE" ] && [ "$THEIRS_BREAK" != "$THEIRS_KEEP" ] \
  || { echo "FIXTURE ERROR: seeded dist refs are not distinct" >&2; exit 2; }

# ---- a consumer at hand-back shape -----------------------------------------------------------
# build_consumer <dir> <theirs-ref> <applied: 1|0> <validator: real|stub2|stubpass> [<skill_commit>]
# Writes <dir>/.T so every helper call drives this world with THIS world's theirs ref. The pre-apply
# stamp always carries `skill_commit:`, <base> by default as a completed reconcile writes it, or the
# fifth argument when given. The ABSENT-line case is exercised ONLY by the WS3N world (build_su).
build_consumer() {
  local c="$1" t="$2" applied="$3" vkind="$4" sk="${5:-$BASE}"
  mkdir -p "$c/scripts/ai-dlc" "$c/.claude" "$c/_bmad-output"
  g "$c" init -q
  cp "$VALIDATOR" "$c/scripts/ai-dlc/validate-artifact-derivations.sh"
  # the OLDER install, one commit down the first-parent chain
  printf 'qqprev\n' > "$c/scripts/ai-dlc/toy.sh"
  printf 'version: 0.9.0\ncommit: %s\n' "$PREV" > "$c/.claude/.ai-dlc-version"
  {
    printf '# Story\n\n'
    printf 'The count of alpha markers in the toy script.\n\n'
    printf '```derived\n$ grep -c qqalpha scripts/ai-dlc/toy.sh\n1\n```\n\n'
    printf 'A figure that was already wrong before this pull.\n\n'
    printf '```derived\n$ grep -c qqbeta scripts/ai-dlc/toy.sh\n7\n```\n\n'
    printf 'A figure that holds on both sides.\n\n'
    printf '```derived\n$ grep -c qqgamma scripts/ai-dlc/toy.sh\n1\n```\n\n'
    printf 'A command the checker refuses to run.\n\n'
    printf '```derived\n$ perl -ne print scripts/ai-dlc/toy.sh\nqqalpha\n```\n'
  } > "$c/_bmad-output/story.md"
  g "$c" add -A && g "$c" commit -qm "install 0.9.0"
  # the PRE-APPLY tree: the stamp reads <base>, and it is HEAD
  printf 'qqalpha\nqqgamma\n' > "$c/scripts/ai-dlc/toy.sh"
  printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$c/.claude/.ai-dlc-version"
  printf 'skill_commit: %s\n' "$sk" >> "$c/.claude/.ai-dlc-version"
  g "$c" add -A && g "$c" commit -qm "pull to 1.0.0"
  # the APPLY, uncommitted, stamp withheld
  if [ "$applied" = 1 ]; then
    g "$DIST" show "${t}:core/scripts/toy.sh" > "$c/scripts/ai-dlc/toy.sh"
  fi
  case "$vkind" in
    real) ;;
    stub2|stubpass)
      # ONE binary runs both sides, so a validator that fails on ONE side is a wrapper that
      # tells the sides apart by a marker only the consumer's tree carries. The pass-through
      # twin is the same wrapper with the exit replaced by a no-op: it proves the wrapper
      # itself is not what the refusal arm is reading.
      cp "$VALIDATOR" "$c/scripts/ai-dlc/real-validate.sh"
      : > "$c/.consumer-side"
      local act='exit 2'; [ "$vkind" = stubpass ] && act=':'
      {
        printf '#!/usr/bin/env bash\n'
        printf 'case "${1:-}" in --list) exec bash "$(dirname "$0")/real-validate.sh" "$@" ;; esac\n'
        printf 'if [ ! -f "${AI_DLC_PROJECT_ROOT:-}/.consumer-side" ]; then %s; fi\n' "$act"
        printf 'exec bash "$(dirname "$0")/real-validate.sh" "$@"\n'
      } > "$c/scripts/ai-dlc/validate-artifact-derivations.sh"
      ;;
  esac
  printf '%s\n' "$t" > "$c/.T"; printf '%s\n' "$DIST" > "$c/.D"; printf '%s\n' "$BASE" > "$c/.B"
}

# dd <consumer> [extra args...] -> sets OUT and RC. Run from `/`, so no arm leans on the cwd.
# Every ref comes from the world's own .D/.B/.T, so a world built on the second dist is driven
# with that dist's refs and never with the first's.
dd() {
  local c="$1"; shift
  OUT="$(cd / && TMPDIR="$DDTMP" bash "$SUBJ" "$(cat "$c/.D")" "$(cat "$c/.B")" "$c" "$(cat "$c/.T")" "$@" 2>&1)"; RC=$?
}
wtcount() { g "$1" worktree list 2>/dev/null | awk 'END { print NR + 0 }'; }

W1="$WORK/w1-break";   build_consumer "$W1" "$THEIRS_BREAK" 1 real
W2="$WORK/w2-clean";   build_consumer "$W2" "$THEIRS_KEEP"  1 real
W3="$WORK/w3-unapplied"; build_consumer "$W3" "$THEIRS_BREAK" 0 real
W5="$WORK/w5-stub2";   build_consumer "$W5" "$THEIRS_BREAK" 1 stub2
W5P="$WORK/w5-stubpass"; build_consumer "$W5P" "$THEIRS_BREAK" 1 stubpass

SF="_bmad-output/story.md"
line_of() { grep -n -- "$1" "$W1/$SF" | head -1 | cut -d: -f1; }
K_ALPHA="$SF:$(line_of 'grep -c qqalpha')"
K_BETA="$SF:$(line_of 'grep -c qqbeta')"
K_GAMMA="$SF:$(line_of 'grep -c qqgamma')"
K_PERL="$SF:$(line_of 'perl -ne')"
for k in "$K_ALPHA" "$K_BETA" "$K_GAMMA" "$K_PERL"; do
  case "$k" in *: ) echo "FIXTURE ERROR: a seeded derivation line was not found in $SF" >&2; exit 2 ;; esac
done

# ---- A0: the seed IS hand-back shape --------------------------------------------------------
# Measured, not assumed: both stamps read <base>, the apply is in the working tree only, and the
# first-parent chain carries a DIFFERENT older stamp one commit down.
s_head="$(g "$W1" show "HEAD:.claude/.ai-dlc-version" | sed -n 's/^commit: //p')"
s_wt="$(sed -n 's/^commit: //p' "$W1/.claude/.ai-dlc-version")"
s_prev="$(g "$W1" show "HEAD~1:.claude/.ai-dlc-version" | sed -n 's/^commit: //p')"
dirty="$(g "$W1" status --porcelain -- scripts/ai-dlc/toy.sh)"
if [ "$s_head" = "$BASE" ] && [ "$s_wt" = "$BASE" ] && [ "$s_prev" = "$PREV" ] && [ -n "$dirty" ]; then
  ok "A0 seed: HEAD and working-tree stamps both read <base>, HEAD~1 reads an older stamp, the apply is uncommitted"
else
  bad "A0 seed is not hand-back shape (head=$s_head wt=$s_wt prev=$s_prev dirty=[$dirty]); no arm below is readable"
fi

# ---- A1: passes at base, fails after the apply -> exit 1, and it is NAMED --------------------
dd "$W1"; OUT1="$OUT"; RC1="$RC"
rc_is "A1a a derivation broken by this apply -> exit 1" 1 "$RC1"
ck "A1b the NEWLY-FAILING row names that derivation" "$(printf 'NEWLY-FAILING\t%s\t' "$K_ALPHA")" "$OUT1"
n_nf="$(nrows NEWLY-FAILING "$OUT1")"
rc_is "A1c exactly one NEWLY-FAILING row in a corpus that also carries a STALE-BOTH derivation" 1 "$n_nf"
ck "A1d the verdict says this apply broke something" "$(printf 'VERDICT\t_bmad-output/\t1 derivation(s) reproduced before this apply')" "$OUT1"
ck "A1e the base root was FOUND from the stamp (no --base-root was passed)" "base root (worktree of " "$OUT1"
ck "A1f and the stamps are echoed as information, both at <base>" "stamp commit: $BASE; consumer stamp commit: $BASE" "$OUT1"

# ---- A2: stale on both sides -> STALE-BOTH, counted, NOT named -------------------------------
ck "A2a the already-stale derivation is listed STALE-BOTH" "$(printf 'STALE-BOTH\t%s\t' "$K_BETA")" "$OUT1"
nk "A2b and it is NOT named NEWLY-FAILING" "$(printf 'NEWLY-FAILING\t%s\t' "$K_BETA")" "$OUT1"
ck "A2c the summary counts it" "1 NEWLY-FAILING, 0 NEWLY-PASSING, 1 STALE-BOTH, 1 UNASSESSABLE, 1 reproduce on both sides" "$OUT1"

# ---- A3: the clean pair -> exit 0 ------------------------------------------------------------
# The near-miss of A1: the same changed path, the same corpus, the same STALE-BOTH debt. Only
# qqalpha surviving the apply differs.
dd "$W2"; OUT2="$OUT"; RC2="$RC"
rc_is "A3a a clean pair -> exit 0" 0 "$RC2"
rc_is "A3b no NEWLY-FAILING row" 0 "$(nrows NEWLY-FAILING "$OUT2")"
ck "A3c the verdict is the clear" "$(printf 'VERDICT\t_bmad-output/\tzero NEWLY-FAILING')" "$OUT2"
ck "A3d and the pre-existing debt is still LISTED, so the clear is not an empty run" "$(printf 'STALE-BOTH\t%s\t' "$K_BETA")" "$OUT2"

# ---- A4: an ALLOWLIST derivation -> UNASSESSABLE ---------------------------------------------
ck "A4a the allowlist-refused derivation is UNASSESSABLE" "$(printf 'UNASSESSABLE\t%s\t' "$K_PERL")" "$OUT1"
nk "A4b a derivation reproducing on both sides is not UNASSESSABLE" "$(printf 'UNASSESSABLE\t%s\t' "$K_GAMMA")" "$OUT1"
nk "A4c and it gets no row at all" "$(printf '\t%s\t' "$K_GAMMA")" "$OUT1"
nk "A4d the allowlist-refused derivation is never counted NEWLY-FAILING" "$(printf 'NEWLY-FAILING\t%s\t' "$K_PERL")" "$OUT1"

# ---- A5: a validator that exits 2 on one side -> exit 2 --------------------------------------
dd "$W5"; OUT5="$OUT"; RC5="$RC"
rc_is "A5a a validator exiting 2 on the base side -> exit 2" 2 "$RC5"
ck "A5b and the refusal names the side and the status" "$(printf 'REFUSED\tvalidator\tthe base-side run exited 2')" "$OUT5"
nk "A5c no verdict is printed over a refused side" "VERDICT" "$OUT5"
dd "$W5P"; OUT5P="$OUT"; RC5P="$RC"
rc_is "A5n near-miss: the same wrapper passing through -> exit 1, not a refusal" 1 "$RC5P"
ck "A5o and it names the broken derivation" "$(printf 'NEWLY-FAILING\t%s\t' "$K_ALPHA")" "$OUT5P"

# ---- A6/A7: an EMPTY --base-root and an EMPTY-DIRECTORY --base-root -> exit 2 ------------------
dd "$W1" --base-root ""; OUT6="$OUT"; RC6="$RC"
rc_is "A6a an empty --base-root -> exit 2" 2 "$RC6"
ck "A6b and the refusal says it is EMPTY" "$(printf 'REFUSED\tbase-root\t--base-root is EMPTY')" "$OUT6"
EMPTYDIR="$WORK/empty-root"; mkdir -p "$EMPTYDIR"
dd "$W1" --base-root "$EMPTYDIR"; OUT7="$OUT"; RC7="$RC"
rc_is "A7a an empty-directory --base-root -> exit 2" 2 "$RC7"
ck "A7b and the refusal says it is not a work tree" "is not a git work tree with a HEAD" "$OUT7"
# near-miss for both: a REAL checkout of the pre-apply commit, passed the same way
CLONE="$WORK/base-clone"
g "$WORK" clone -q "$W1" "$CLONE" 2>/dev/null
dd "$W1" --base-root "$CLONE"; OUT6N="$OUT"; RC6N="$RC"
rc_is "A6n near-miss: a real pre-apply checkout as --base-root -> exit 1" 1 "$RC6N"
ck "A6o and that root is the one used" "base root (--base-root $CLONE)" "$OUT6N"
ck "A6p and it names the broken derivation" "$(printf 'NEWLY-FAILING\t%s\t' "$K_ALPHA")" "$OUT6N"

# ---- A8: no changed path differs between the roots -> exit 2 ---------------------------------
dd "$W3"; OUT8="$OUT"; RC8="$RC"
rc_is "A8a the apply not yet run (no changed path differs) -> exit 2" 2 "$RC8"
ck "A8b and the refusal is the content control" "$(printf 'REFUSED\tcontrol\tnone of the 1 path(s)')" "$OUT8"
ck "A8n near-miss: with the apply in the tree the control passes and says so" "$(printf 'INFO\tcontrol\t1 of 1 changed path(s) differ')" "$OUT1"

# ---- A9: a root on which NOTHING reproduces -> exit 2 ----------------------------------------
# A git repo carrying only the <base> stamp: it passes every check on the root's SHAPE, and its
# changed path is absent, which the content control scores as a difference. Every derivation then
# fails at base. Without the zero-pass refusal the run reads STALE-BOTH everywhere and exits 0.
BROKEN="$WORK/broken-root"
mkdir -p "$BROKEN/.claude"
g "$BROKEN" init -q
printf 'version: 1.0.0\ncommit: %s\nskill_commit: %s\n' "$BASE" "$BASE" > "$BROKEN/.claude/.ai-dlc-version"
g "$BROKEN" add -A && g "$BROKEN" commit -qm stamp-only
dd "$W1" --base-root "$BROKEN"; OUT9="$OUT"; RC9="$RC"
rc_is "A9a a base root on which zero derivations reproduce -> exit 2" 2 "$RC9"
ck "A9b and the refusal names the broken-root signature" "ZERO derivations reproduce at the base root" "$OUT9"
nk "A9c and does not clear it" "zero NEWLY-FAILING" "$OUT9"
# near-miss: A6n above -- a real pre-apply checkout passed the same way reaches a verdict.

# ---- A11: a SELF-UPDATE commit above the pre-pull commit is not the base root ----------------
# Step 2 commits theirs' machinery slice and advances `skill_commit:` to theirs while `commit:`
# stays at <base>, so that commit is the newest one whose `commit:` resolves to <base>. Taken as
# the base root it already carries the range's machinery: a derivation over a machinery path the
# range broke fails on both sides, reads STALE-BOTH, and the run clears. A SECOND dist, because the
# range must change a machinery path (core/scripts/su.sh) AND a non-machinery one
# (core/rules/su.md): the apply writes only the second, and it is what makes the content control
# pass against the self-update tree, so a walk that stops there reaches a verdict and clears rather
# than refusing. The near-miss is the same world whose derivation names an UNCHANGED machinery path.
DIST2="$WORK/dist2"
mkdir -p "$DIST2/core/scripts" "$DIST2/core/rules"
g "$DIST2" init -q
printf 'qqsu\n' > "$DIST2/core/scripts/su.sh"; printf 'qqkeep\n' > "$DIST2/core/scripts/keep.sh"
printf 'rule-a\n' > "$DIST2/core/rules/su.md"
seed_cls "$DIST2"
g "$DIST2" add -A && g "$DIST2" commit -qm base2
BASE2="$(g "$DIST2" rev-parse HEAD)"
printf 'qqother\n' > "$DIST2/core/scripts/su.sh"; printf 'rule-b\n' > "$DIST2/core/rules/su.md"
g "$DIST2" add -A && g "$DIST2" commit -qm theirs2
THEIRS2="$(g "$DIST2" rev-parse HEAD)"
[ -n "$BASE2" ] && [ -n "$THEIRS2" ] && [ "$BASE2" != "$THEIRS2" ] \
  || { echo "FIXTURE ERROR: seeded dist2 refs unresolvable or equal" >&2; exit 2; }

# build_su <dir> <derivation-over-machinery: broken|unchanged> [<self-update skill_commit: theirs|empty|absent>] [<pre-pull skill_commit:>]
# The fourth argument is used ONLY by WS3N: it sets the pre-pull commit's `skill_commit:` to a value
# skill_commit_ok rejects, so the commit below the absent-line self-update commit cannot match.
build_su() {
  local c="$1" kind="$2" suk="${3:-theirs}" presk="${4:-$BASE2}"
  mkdir -p "$c/scripts/ai-dlc" "$c/.claude/rules" "$c/_bmad-output"
  g "$c" init -q
  cp "$VALIDATOR" "$c/scripts/ai-dlc/validate-artifact-derivations.sh"
  g "$DIST2" show "${BASE2}:core/scripts/su.sh" > "$c/scripts/ai-dlc/su.sh"
  g "$DIST2" show "${BASE2}:core/scripts/keep.sh" > "$c/scripts/ai-dlc/keep.sh"
  g "$DIST2" show "${BASE2}:core/rules/su.md" > "$c/.claude/rules/su.md"
  # the PRE-PULL tree: skill_commit: present and equal to commit:, as a completed reconcile writes it
  # (except under WS3N's fourth argument, which writes a value the walk rejects)
  printf 'version: 1.0.0\ncommit: %s\nskill_version: 1.0.0\nskill_commit: %s\n' "$BASE2" "$presk" > "$c/.claude/.ai-dlc-version"
  {
    printf '# Story\n\n'
    printf 'A rule figure that holds on both sides; it puts this file in the row.\n\n'
    printf '```derived\n$ grep -c rule .claude/rules/su.md\n1\n```\n\n'
    if [ "$kind" = broken ]; then
      printf 'A machinery figure this range breaks.\n\n'
      printf '```derived\n$ grep -c qqsu scripts/ai-dlc/su.sh\n1\n```\n'
    else
      printf 'A machinery figure over a path this range leaves alone.\n\n'
      printf '```derived\n$ grep -c qqkeep scripts/ai-dlc/keep.sh\n1\n```\n'
    fi
  } > "$c/_bmad-output/su.md"
  g "$c" add -A && g "$c" commit -qm "reconcile to base2"
  g "$c" rev-parse HEAD > "$c/.PRE"
  # step 2: the SELF-UPDATE commit -- theirs' machinery, commit: unchanged, skill_commit: -> theirs
  g "$DIST2" show "${THEIRS2}:core/scripts/su.sh" > "$c/scripts/ai-dlc/su.sh"
  case "$suk" in
    theirs) printf 'version: 1.0.0\ncommit: %s\nskill_version: 1.1.0\nskill_commit: %s\n' "$BASE2" "$THEIRS2" ;;
    empty)  printf 'version: 1.0.0\ncommit: %s\nskill_version: 1.1.0\nskill_commit: \n' "$BASE2" ;;
    absent) printf 'version: 1.0.0\ncommit: %s\nskill_version: 1.1.0\n' "$BASE2" ;;
  esac > "$c/.claude/.ai-dlc-version"
  g "$c" add -A && g "$c" commit -qm "self-update base2 -> theirs2"
  g "$c" rev-parse HEAD > "$c/.SU"
  # step 7: the gated apply, uncommitted, stamp withheld
  g "$DIST2" show "${THEIRS2}:core/rules/su.md" > "$c/.claude/rules/su.md"
  printf '%s\n' "$THEIRS2" > "$c/.T"; printf '%s\n' "$DIST2" > "$c/.D"; printf '%s\n' "$BASE2" > "$c/.B"
}
WSU="$WORK/w-selfupdate";   build_su "$WSU"  broken
WSUN="$WORK/w-selfupdate-n"; build_su "$WSUN" unchanged
PRE_SU="$(cat "$WSU/.PRE")"; SU_SU="$(cat "$WSU/.SU")"
K_SU="_bmad-output/su.md:$(grep -n -- 'grep -c qqsu' "$WSU/_bmad-output/su.md" | head -1 | cut -d: -f1)"
case "$K_SU" in *: ) echo "FIXTURE ERROR: the seeded machinery derivation was not found" >&2; exit 2 ;; esac

# A11 seed: measured, not assumed. HEAD is the self-update commit (commit: <base>, skill_commit:
# theirs), HEAD~1 is the pre-pull commit, and the broken derivation reproduces at HEAD~1 only.
su_head_c="$(g "$WSU" show "HEAD:.claude/.ai-dlc-version" | sed -n 's/^commit: //p')"
su_head_k="$(g "$WSU" show "HEAD:.claude/.ai-dlc-version" | sed -n 's/^skill_commit: //p')"
su_pre="$(g "$WSU" rev-parse HEAD~1)"
su_at_pre="$(g "$WSU" show "HEAD~1:scripts/ai-dlc/su.sh")"
su_at_head="$(g "$WSU" show "HEAD:scripts/ai-dlc/su.sh")"
if [ "$su_head_c" = "$BASE2" ] && [ "$su_head_k" = "$THEIRS2" ] && [ "$su_pre" = "$PRE_SU" ] \
   && [ "$su_at_pre" = qqsu ] && [ "$su_at_head" = qqother ]; then
  ok "A11 seed: HEAD is a self-update commit (commit: <base>, skill_commit: theirs, theirs' machinery) above the pre-pull commit"
else
  bad "A11 seed is not self-update shape (commit=$su_head_c skill_commit=$su_head_k pre=$su_pre at_pre=$su_at_pre at_head=$su_at_head); A11 is unreadable"
fi

dd "$WSU"; OUT11="$OUT"; RC11="$RC"
rc_is "A11a a machinery derivation broken by this range, under a self-update commit -> exit 1" 1 "$RC11"
ck "A11b the NEWLY-FAILING row names the machinery derivation" "$(printf 'NEWLY-FAILING\t%s\t' "$K_SU")" "$OUT11"
ck "A11c the base root is the PRE-PULL commit" "base root (worktree of $PRE_SU)" "$OUT11"
nk "A11d and never the self-update commit" "base root (worktree of $SU_SU)" "$OUT11"
nk "A11e the machinery derivation is not scored STALE-BOTH" "$(printf 'STALE-BOTH\t%s\t' "$K_SU")" "$OUT11"
dd "$WSUN"; OUT11N="$OUT"; RC11N="$RC"
rc_is "A11n near-miss: the same world, the derivation names an unchanged machinery path -> exit 0" 0 "$RC11N"
ck "A11o and it reaches the clear from the pre-pull commit" "base root (worktree of $(cat "$WSUN/.PRE"))" "$OUT11N"

# ---- A12: a leaked base worktree from an earlier run is NAMED and NOT removed -----------------
# A SIGKILLed run never reaches its EXIT trap. Seeded by registering a worktree under a directory
# spelled the way the helper spells its own. The near-miss is every other run above, which had its
# OWN such worktree registered while it ran and must not name it.
#
# THE RUN MUST BE DEAD. Each run records its PID beside its worktree, and a worktree is named only
# when `kill -0` on that PID fails with ESRCH ("No such process"): a CONCURRENT live run's worktree
# is spelled identically, and naming it with a removal remedy pulls the tree out from under that
# run. So three are seeded, one per branch of the helper's liveness test: LEAKED records the PID of
# a child this fixture started and reaped (ESRCH, dead), LIVE records this fixture's own PID (rc 0,
# alive for as long as the helper runs), and FOREIGN records PID 1 -- always alive and never ours,
# the shape of a concurrent run by ANOTHER uid, where bare `kill -0` fails with EPERM and read a
# live run as dead. Only LEAKED may be named.
#
# NO CONTROL HERE CALLS `ps`. `/bin/ps` is setuid root, and under a `sandbox-exec` profile (the
# read-set tracer's) its exec is refused for every pid, so controls keyed on it failed there and
# took the fixture out of the trace. The controls read `kill -0`'s own answer instead -- the same
# three inputs, the same three outcomes, inside a sandbox and out.
W6="$WORK/w6-leak"; build_consumer "$W6" "$THEIRS_BREAK" 1 real
LEAK="$WORK/derivation-differential-root-LEAKED/base"
LIVE="$WORK/derivation-differential-root-LIVE/base"
FRGN="$WORK/derivation-differential-root-FOREIGN/base"
mkdir -p "$(dirname "$LEAK")" "$(dirname "$LIVE")" "$(dirname "$FRGN")"
# git registers the PHYSICAL path (macOS: /var -> /private/var), so the arms compare against that.
LEAK="$(cd "$(dirname "$LEAK")" && pwd -P)/base"
LIVE="$(cd "$(dirname "$LIVE")" && pwd -P)/base"
FRGN="$(cd "$(dirname "$FRGN")" && pwd -P)/base"
bash -c 'exit 0' & DEADPID=$!
wait "$DEADPID" 2>/dev/null
printf '%s\n' "$DEADPID" > "${LEAK%/*}/pid"
printf '%s\n' "$$" > "${LIVE%/*}/pid"
printf '1\n' > "${FRGN%/*}/pid"
k0_dead="$(LC_ALL=C kill -0 "$DEADPID" 2>&1)"; k0_dead_rc=$?
k0_live="$(LC_ALL=C kill -0 "$$" 2>&1)"; k0_live_rc=$?
if [ "$k0_dead_rc" -ne 0 ] && [ "${k0_dead%No such process}" != "$k0_dead" ] && [ "$k0_live_rc" -eq 0 ]; then
  ok "A12 control: kill -0 answers ESRCH for the recorded dead PID and succeeds on the recorded live PID"
else
  bad "A12 control: kill -0 does not separate the seeded dead PID ($DEADPID: rc $k0_dead_rc, $k0_dead) from the live one ($$: rc $k0_live_rc) -- A12b and A12l are unreadable"
fi
# The FOREIGN control is the discriminating input: PID 1 is alive AND bare `kill -0` fails on it,
# with EPERM, so a test reading only the status calls it dead. Run as root, `kill -0 1` succeeds and
# the seed no longer exercises the EPERM branch; the control says so rather than letting A12e pass
# for the wrong reason.
k0_one="$(LC_ALL=C kill -0 1 2>&1)"; k0_one_rc=$?
if [ "$k0_one_rc" -ne 0 ] && [ "${k0_one%Operation not permitted}" != "$k0_one" ]; then
  ok "A12 control: kill -0 on PID 1 fails with EPERM, so FOREIGN exercises the other-uid branch"
else
  bad "A12 control: kill -0 on PID 1 did not fail with EPERM (rc $k0_one_rc: $k0_one; running as root?) -- A12e is unreadable"
fi
g "$W6" worktree add -q --detach "$LEAK" HEAD 2>/dev/null
g "$W6" worktree add -q --detach "$LIVE" HEAD 2>/dev/null
g "$W6" worktree add -q --detach "$FRGN" HEAD 2>/dev/null
dd "$W6"; OUT12="$OUT"; RC12="$RC"
rc_is "A12a a leaked worktree does not change the verdict -> exit 1" 1 "$RC12"
ck "A12b the leaked worktree whose run is DEAD is NAMED in a NOTE row" "$(printf 'NOTE\tworktree\t%s is a registered worktree' "$LEAK")" "$OUT12"
nk "A12l near-miss: the worktree of a LIVE run is NOT named" "$LIVE" "$OUT12"
nk "A12e near-miss: the worktree of a live run owned by ANOTHER uid (PID 1) is NOT named" "$FRGN" "$OUT12"
wt6="$(g "$W6" worktree list --porcelain 2>/dev/null)"
if grep -qxF "worktree $LEAK" <<<"$wt6"; then
  ok "A12c and it is still registered afterwards -- named, never removed"
else
  bad "A12c the leaked worktree was removed or unregistered; the helper must only name it"
fi
# A12 UNDER THE READ-SET TRACER'S SANDBOX. The same call, the same three worktrees, run inside
# `sandbox-exec` with the profile shape `core/scripts/derive-fixture-readsets.sh` writes for
# `--tracer sandbox` (allow default; file and process-exec reported under two subpaths). There every
# setuid exec is refused, so a liveness test that execs `/bin/ps` reads every PID as dead and names
# LIVE and FOREIGN. The control proves `ps` IS refused inside this profile on this host: where it is
# not, the arm cannot tell a `ps`-based test from the shipped one, and says so rather than passing.
# Where `sandbox-exec` does not exist the arm SKIPs, and a SKIP is not a pass.
# WHERE THE PROFILE CANNOT BE APPLIED THE ARM SKIPS TOO. A process already inside a sandbox -- this
# fixture run BY the tracer -- cannot apply a second, different profile: `sandbox-exec` exits 71
# "sandbox_apply: Operation not permitted" (measured). There the arms above already ran under the
# tracer's own sandbox, which is the world these four re-create. The ps control is read only after
# the profile is shown to apply, or a refused APPLY would pass for a refused `ps`.
SBT="$WORK/sb-tree"; SBM="$WORK/sb-mark"; mkdir -p "$SBT" "$SBM"
SBP="$WORK/sb.sb"
printf '(version 3)\n(allow default)\n(allow file* process-exec* (subpath "%s") (subpath "%s") (with report))\n(allow file-read-metadata file-test-existence (literal "%s"))\n' "$SBT" "$SBM" "$SBT" > "$SBP"
if ! command -v sandbox-exec >/dev/null 2>&1; then
  printf '  SKIP  A12q A12r A12v A12w: sandbox-exec is not on this host, so the tracer-sandbox arms did not run (not a pass)\n'
elif ! sandbox-exec -f "$SBP" true >/dev/null 2>&1; then
  printf '  SKIP  A12q A12r A12v A12w: sandbox-exec cannot apply the profile here (already inside a sandbox?), so the tracer-sandbox arms did not run (not a pass)\n'
else
  if sandbox-exec -f "$SBP" ps -p "$$" >/dev/null 2>&1; then
    bad "A12 sandbox control: ps -p runs inside the tracer's profile on this host, so the sandboxed arms cannot separate a ps-based liveness test from the shipped one -- A12q, A12r, A12v and A12w are unreadable"
  else
    ok "A12 sandbox control: ps -p is refused inside the tracer's profile, so a ps-based liveness test would read every PID dead there"
  fi
  OUT12S="$(cd / && TMPDIR="$DDTMP" sandbox-exec -f "$SBP" bash "$SUBJ" "$(cat "$W6/.D")" "$(cat "$W6/.B")" "$W6" "$(cat "$W6/.T")" 2>&1)"; RC12S=$?
  rc_is "A12q under the tracer's sandbox the verdict is unchanged -> exit 1" 1 "$RC12S"
  ck "A12r under the tracer's sandbox the DEAD run's worktree is still NAMED" "$(printf 'NOTE\tworktree\t%s is a registered worktree' "$LEAK")" "$OUT12S"
  nk "A12v near-miss under the tracer's sandbox: the LIVE run's worktree is NOT named" "$LIVE" "$OUT12S"
  nk "A12w near-miss under the tracer's sandbox: the other-uid run's worktree (PID 1) is NOT named" "$FRGN" "$OUT12S"
fi
nk "A12n near-miss: a run whose only root-* worktree is its OWN names none" "$(printf 'NOTE\tworktree\t')" "$OUT1"

# ---- A13: a STALE skill_commit: with no self-update is still the pre-pull tree ---------------
# Step 2 advances skill_commit: only when the machinery slice is non-empty, so after a pull with no
# self-update the pre-pull commit carries a skill_commit: that is a strict ANCESTOR of <base>. The
# walk must accept it and reach the break. The near-miss is the same world whose skill_commit:
# names a commit that is neither <base> nor an ancestor of it: nothing shows that tree is
# pre-pull, so the walk refuses rather than guessing.
W13="$WORK/w13-stale-sk";  build_consumer "$W13"  "$THEIRS_BREAK" 1 real "$PREV"
W13N="$WORK/w13-side-sk";  build_consumer "$W13N" "$THEIRS_BREAK" 1 real "$SIDE"
dd "$W13"; OUT13="$OUT"; RC13="$RC"
rc_is "A13a skill_commit: an ancestor of <base>, no self-update, the pull breaks a derivation -> exit 1" 1 "$RC13"
ck "A13b the NEWLY-FAILING row names it" "$(printf 'NEWLY-FAILING\t%s\t' "$K_ALPHA")" "$OUT13"
ck "A13c the base root is the pre-pull commit, HEAD" "base root (worktree of $(g "$W13" rev-parse HEAD))" "$OUT13"
dd "$W13N"; OUT13N="$OUT"; RC13N="$RC"
rc_is "A13n near-miss: skill_commit: names a commit that is not <base> or its ancestor -> exit 2" 2 "$RC13N"
ck "A13o and the refusal is the walk's, not a verdict" "$(printf 'REFUSED\tbase-root\tno commit on the consumer')" "$OUT13N"

# ---- A14: --base-root is held to the same skill_commit: test ----------------------------------
# A checkout of the self-update commit -- HEAD at hand-back, the obvious thing to pass -- carries
# `commit: <base>` and theirs' machinery. It must be refused. The near-miss is a checkout of the
# commit below it, passed the same way, which reaches the break.
SUROOT="$WORK/su-headroot"; g "$WORK" clone -q "$WSU" "$SUROOT" 2>/dev/null
PREROOT="$WORK/su-preroot"; g "$WORK" clone -q "$WSU" "$PREROOT" 2>/dev/null
g "$PREROOT" checkout -q --detach "$PRE_SU" 2>/dev/null
if [ "$(g "$SUROOT" rev-parse HEAD)" = "$SU_SU" ] && [ "$(g "$PREROOT" rev-parse HEAD)" = "$PRE_SU" ]; then
  ok "A14 seed: one checkout sits at the self-update commit, the other at the pre-pull commit"
else
  bad "A14 seed: the two --base-root checkouts are not at the self-update and pre-pull commits -- A14 is unreadable"
fi
dd "$WSU" --base-root "$SUROOT"; OUT14="$OUT"; RC14="$RC"
rc_is "A14a --base-root at the self-update commit -> exit 2" 2 "$RC14"
ck "A14b and the refusal names its skill_commit:" "$(printf 'REFUSED\tbase-root\t--base-root %s carries skill_commit' "$SUROOT")" "$OUT14"
nk "A14c and does not clear it" "zero NEWLY-FAILING" "$OUT14"
dd "$WSU" --base-root "$PREROOT"; OUT14N="$OUT"; RC14N="$RC"
rc_is "A14n near-miss: --base-root at the pre-pull commit -> exit 1" 1 "$RC14N"
ck "A14o and it names the machinery derivation" "$(printf 'NEWLY-FAILING\t%s\t' "$K_SU")" "$OUT14N"

# ---- A15: an EMPTY skill_commit: is a skip, not "absent" ---------------------------------------
# A self-update that wrote `skill_commit:` with no value says nothing about its machinery, so it is
# not shown to be pre-pull and the walk goes on down to the commit below it. The near-miss is the
# same self-update commit with NO skill_commit: line at all, the pre-migration stamp shape, which
# the walk accepts. The self-update commits differ in exactly one property, the presence of the line;
# WS3N's pre-pull commit also carries a skill_commit: the walk rejects, so the absent-line commit is
# the ONLY one it can accept (that keeps "newest match wins", A16, from sharing A15n's observable).
WS3="$WORK/w15-empty-sk";   build_su "$WS3"  broken empty
WS3N="$WORK/w15-absent-sk"; build_su "$WS3N" broken absent "$THEIRS2"
if grep -qx 'skill_commit: ' <<<"$(g "$WS3" show "HEAD:.claude/.ai-dlc-version")" \
   && ! grep -q '^skill_commit:' <<<"$(g "$WS3N" show "HEAD:.claude/.ai-dlc-version")" \
   && grep -qx "skill_commit: $THEIRS2" <<<"$(g "$WS3N" show "HEAD~1:.claude/.ai-dlc-version")"; then
  ok "A15 seed: one self-update commit carries an empty skill_commit: line, the other none, and the absent one's pre-pull commit is rejectable"
else
  bad "A15 seed: the empty/absent skill_commit: shapes, or WS3N's rejectable pre-pull stamp, were not written -- A15 is unreadable"
fi
dd "$WS3"; OUT15="$OUT"; RC15="$RC"
rc_is "A15a an empty skill_commit: on the self-update commit -> it is skipped, exit 1" 1 "$RC15"
ck "A15b the base root is the commit below it" "base root (worktree of $(cat "$WS3/.PRE"))" "$OUT15"
dd "$WS3N"; OUT15N="$OUT"; RC15N="$RC"
ck "A15n near-miss: NO skill_commit: line is accepted, so the walk stops at that commit" "base root (worktree of $(cat "$WS3N/.SU"))" "$OUT15N"

# ---- A16: the base root is the NEWEST pre-pull commit, not the oldest -------------------------
# A consumer commit ABOVE the pull commit, still stamped <base>, edits an operand, and a derivation
# is written against that edit. It reproduces at the newest pre-pull commit and fails after the
# apply overwrites the file. From the OLDEST commit stamped <base> it was already failing, reads
# STALE-BOTH, and the run clears. The near-miss is the same world whose applied tree KEEPS the
# consumer's edit, so the derivation reproduces on both sides.
build_local() { # build_local <dir> <applied keeps the local edit: 0|1>
  local c="$1" keep="$2"
  build_consumer "$c" "$THEIRS_KEEP" 0 real
  printf 'qqalpha\nqqgamma\nqqlocal\n' > "$c/scripts/ai-dlc/toy.sh"
  printf '# Local\n\nThe consumer'"'"'s own marker.\n\n```derived\n$ grep -c qqlocal scripts/ai-dlc/toy.sh\n1\n```\n' \
    > "$c/_bmad-output/local.md"
  g "$c" add -A && g "$c" commit -qm "local edit after the pull"
  g "$c" rev-parse HEAD > "$c/.NEW"; g "$c" rev-parse HEAD~1 > "$c/.OLD"
  g "$DIST" show "${THEIRS_KEEP}:core/scripts/toy.sh" > "$c/scripts/ai-dlc/toy.sh"
  [ "$keep" = 1 ] && printf 'qqlocal\n' >> "$c/scripts/ai-dlc/toy.sh"
  :
}
W16="$WORK/w16-newest";  build_local "$W16"  0
W16N="$WORK/w16-newest-n"; build_local "$W16N" 1
K_LOCAL="_bmad-output/local.md:$(grep -n -- 'grep -c qqlocal' "$W16/_bmad-output/local.md" | head -1 | cut -d: -f1)"
case "$K_LOCAL" in *: ) echo "FIXTURE ERROR: the seeded local derivation was not found" >&2; exit 2 ;; esac
s16a="$(g "$W16" show "HEAD:.claude/.ai-dlc-version" | sed -n 's/^commit: //p')"
s16b="$(g "$W16" show "HEAD~1:.claude/.ai-dlc-version" | sed -n 's/^commit: //p')"
t16a="$(g "$W16" show "HEAD:scripts/ai-dlc/toy.sh")"; t16b="$(g "$W16" show "HEAD~1:scripts/ai-dlc/toy.sh")"
if [ "$s16a" = "$BASE" ] && [ "$s16b" = "$BASE" ] \
   && grep -q qqlocal <<<"$t16a" && ! grep -q qqlocal <<<"$t16b"; then
  ok "A16 seed: TWO commits carry <base>, and only the newer one holds the operand the derivation was written against"
else
  bad "A16 seed: the newest-vs-oldest shape was not built -- A16 is unreadable"
fi
dd "$W16"; OUT16="$OUT"; RC16="$RC"
rc_is "A16a a derivation over a post-pull consumer edit that the apply overwrites -> exit 1" 1 "$RC16"
ck "A16b the NEWLY-FAILING row names it" "$(printf 'NEWLY-FAILING\t%s\t' "$K_LOCAL")" "$OUT16"
ck "A16c the base root is the NEWEST commit carrying <base>" "base root (worktree of $(cat "$W16/.NEW"))" "$OUT16"
nk "A16d and never the older one" "base root (worktree of $(cat "$W16/.OLD"))" "$OUT16"
dd "$W16N"; OUT16N="$OUT"; RC16N="$RC"
rc_is "A16n near-miss: the applied tree keeps the edit -> exit 0" 0 "$RC16N"
ck "A16o and it is reached from the newest commit carrying <base>" "base root (worktree of $(cat "$W16N/.NEW"))" "$OUT16N"

# ---- A17: a base-side COMPARISON that could not run is a refusal, never STALE-BOTH ------------
# The validator used to fold `diff` exiting 2 into STALE. On the base side that turned a derivation
# this pull broke -- qqalpha, which REPRODUCES at base -- into STALE-BOTH, and with qqgamma still
# passing at base the broken-root guard (A9) does not fire, so the run CLEARED: exit 0, "zero
# NEWLY-FAILING". The validator now reports that comparison UNRUN and exits 2, and this helper
# refuses any side status but 0 and 1.
#
# FORCED, NEVER SAMPLED: a `diff` stub on PATH fails ONLY the FIRST comparison on the BASE side
# (the side whose root lacks the untracked `.consumer-side` marker), which is qqalpha's, the first
# derivation in the file. The helper itself runs no bare `diff` (its range read is `git diff`), so
# the stub reaches the validator and nothing else. The PASS-THROUGH TWIN is the same stub, counting
# the same call, handing it to the real `diff`: it must reach A1's verdict and leave the sentinel,
# which proves the stub sits on the base side's PATH and is reached by the comparison.
REAL_DIFF="$(command -v diff)"
[ -n "$REAL_DIFF" ] || { echo "FIXTURE ERROR: diff is not on PATH, so the A17 stub cannot pass through" >&2; exit 2; }
W17="$WORK/w17-cmp";   build_consumer "$W17" "$THEIRS_BREAK" 1 real; : > "$W17/.consumer-side"
W17N="$WORK/w17-cmp-n"; build_consumer "$W17N" "$THEIRS_BREAK" 1 real; : > "$W17N/.consumer-side"
dstub() { # dstub <dir> <fail: 1|0> -- counts base-side calls in <dir>/SENT, fails the first when asked
  local d="$1" act=':'
  mkdir -p "$d"; : > "$d/SENT"
  [ "$2" = 1 ] && act='echo "diff: /dev/fd/63: Bad file descriptor" >&2; exit 2'
  {
    printf '#!/bin/sh\n'
    printf 'if [ ! -f "${AI_DLC_PROJECT_ROOT:-}/.consumer-side" ]; then\n'
    printf '  echo x >> "%s/SENT"\n' "$d"
    printf '  if [ "$(wc -l < "%s/SENT" | tr -d " ")" = 1 ]; then %s; fi\n' "$d" "$act"
    printf 'fi\n'
    printf 'exec "%s" "$@"\n' "$REAL_DIFF"
  } > "$d/diff"
  chmod +x "$d/diff"
}
dstub "$WORK/dstub-fail" 1
dstub "$WORK/dstub-pass" 0
_opath="$PATH"
PATH="$WORK/dstub-pass:$_opath"; dd "$W17N"; OUT17N="$OUT"; RC17N="$RC"
PATH="$WORK/dstub-fail:$_opath"; dd "$W17";  OUT17="$OUT";  RC17="$RC"
PATH="$_opath"
rc_is "A17n near-miss: the pass-through stub reaches A1's verdict -> exit 1" 1 "$RC17N"
ck "A17o and names the broken derivation" "$(printf 'NEWLY-FAILING\t%s\t' "$K_ALPHA")" "$OUT17N"
[ -s "$WORK/dstub-pass/SENT" ] && [ -s "$WORK/dstub-fail/SENT" ] \
  && ok "A17c control: both stubs were reached by a base-side comparison (sentinels written)" \
  || bad "A17c control: a stub was never reached on the base side -- A17a/A17b are not about the comparison"
rc_is "A17a a base-side comparison diff could not run -> exit 2" 2 "$RC17"
ck "A17b and the refusal names the base side and its status" "$(printf 'REFUSED\tvalidator\tthe base-side run exited 2')" "$OUT17"
nk "A17d the broken derivation is never scored STALE-BOTH" "$(printf 'STALE-BOTH\t%s\t' "$K_ALPHA")" "$OUT17"
nk "A17e and no clear is printed" "zero NEWLY-FAILING" "$OUT17"

# ---- A18: a NEWLY-FAILING row carries what the command printed then and now -------------------
# The receipt shape: a `grep -n` whose needle survives the range but moves to another line. The
# row must show both outputs, so the cause (a line re-point, not new text) is read off the shipped
# tool. Its OWN world: W1 asserts exact counts. The control is the STALE-BOTH row in the same run,
# which must exist and must NOT carry them -- a build appending to every status fails it.
W18="$WORK/w18-shift"; build_consumer "$W18" "$THEIRS_BREAK" 1 real
{
  printf '# Story\n\n'
  printf 'The line the gamma marker sits on.\n\n'
  printf '```derived\n$ grep -n qqgamma scripts/ai-dlc/toy.sh\n2:qqgamma\n```\n\n'
  printf 'A figure that was already wrong before this pull.\n\n'
  printf '```derived\n$ grep -c qqbeta scripts/ai-dlc/toy.sh\n7\n```\n'
} > "$W18/_bmad-output/story.md"
g "$W18" add _bmad-output/story.md && g "$W18" commit -qm "story: line citation"
K_SHIFT="$SF:$(grep -n -- 'grep -n qqgamma' "$W18/$SF" | head -1 | cut -d: -f1)"
K_BETA18="$SF:$(grep -n -- 'grep -c qqbeta' "$W18/$SF" | head -1 | cut -d: -f1)"
case "$K_SHIFT$K_BETA18" in *: | *::* ) echo "FIXTURE ERROR: a seeded A18 derivation line was not found" >&2; exit 2 ;; esac
dd "$W18"; OUT18="$OUT"; RC18="$RC"
rc_is "A18d the line-moved derivation breaks this pull -> exit 1" 1 "$RC18"
nf18="$(awk -F'\t' -v k="$K_SHIFT" '$1 == "NEWLY-FAILING" && $2 == k' <<<"$OUT18")"
ck "A18a the NEWLY-FAILING row carries the recorded and the actual output" \
  "recorded: 2:qqgamma  actual: 1:qqgamma" "$nf18"
sb18="$(awk -F'\t' -v k="$K_BETA18" '$1 == "STALE-BOTH" && $2 == k' <<<"$OUT18")"
if [ -n "$sb18" ] && ! grep -qF 'recorded:' <<<"$sb18"; then
  ok "A18b control: the STALE-BOTH row is present and carries no recorded/actual output"
else
  bad "A18b control: the STALE-BOTH row is absent or carries recorded/actual output: [$sb18]"
fi
rc_is "A18c exactly one NEWLY-FAILING row" 1 "$(nrows NEWLY-FAILING "$OUT18")"

# ---- A19: a record's SUPERSEDED derivation is in no count, so the broken-root refusal still fires --
# The validator skips a record command that a LATER byte-identical command in the same file
# re-derives, and prints `SUPERSEDED:` instead of a verdict. `--list` still names it, so without
# reading those lines this helper scores it PASS on both sides -- and one base-side "pass" is all it
# takes for the zero-pass refusal (A9) never to fire. The world is a slot RECORD holding one repeated
# command and a second command, and NOTHING else in the corpus, so the superseded key is the only
# derivation that could read as a base-side pass. Against A9's broken root it must REFUSE. The
# near-miss is the same world from the real pre-apply tree: it reaches a verdict, names the LATER
# copy NEWLY-FAILING, gives the superseded one no row, and counts it on the INFO row.
W19="$WORK/w19-superseded"; build_consumer "$W19" "$THEIRS_BREAK" 1 real
rm -f "$W19/$SF"
R19="_bmad-output/planning-artifacts/s1/story-repair-p1.md"
mkdir -p "$W19/${R19%/*}"
{
  printf '# Story repair p1\n\n'
  printf '```derived\n$ grep -c qqalpha scripts/ai-dlc/toy.sh\n1\n```\n\n'
  printf 'Re-derived after the edit.\n\n'
  printf '```derived\n$ grep -c qqalpha scripts/ai-dlc/toy.sh\n1\n$ grep -c qqgamma scripts/ai-dlc/toy.sh\n1\n```\n'
} > "$W19/$R19"
K19_EARLY="$R19:$(grep -n -- 'grep -c qqalpha' "$W19/$R19" | head -1 | cut -d: -f1)"
K19_LATE="$R19:$(grep -n -- 'grep -c qqalpha' "$W19/$R19" | sed -n 2p | cut -d: -f1)"
case "$K19_EARLY$K19_LATE" in *: | *::* ) echo "FIXTURE ERROR: a seeded A19 derivation line was not found" >&2; exit 2 ;; esac
[ "$K19_EARLY" != "$K19_LATE" ] || { echo "FIXTURE ERROR: the A19 record does not repeat its command" >&2; exit 2; }
dd "$W19" --base-root "$BROKEN"; OUT19="$OUT"; RC19="$RC"
rc_is "A19a a record with a superseded derivation over a broken base root -> exit 2" 2 "$RC19"
ck "A19b and the refusal is the broken-root signature" "$(printf 'REFUSED\tbase-root\tZERO derivations reproduce at the base root')" "$OUT19"
dd "$W19"; OUT19N="$OUT"; RC19N="$RC"
rc_is "A19n near-miss: the same record from the real pre-apply tree -> exit 1" 1 "$RC19N"
ck "A19o the superseded derivation is counted on the INFO row" "$(printf 'INFO\tsuperseded\t1 of 3 derivation(s)')" "$OUT19N"
ck "A19p the LATER copy carries the verdict" "$(printf 'NEWLY-FAILING\t%s\t' "$K19_LATE")" "$OUT19N"
nk "A19q and the superseded copy gets no row" "$(printf '\t%s\t' "$K19_EARLY")" "$OUT19N"

# ---- S: the join is SCOPED to the current sprint and the living documents ---------------------
# The classifier is the real one, read out of the distribution at <theirs>. S1 seeds W1's world with
# its only derivation-bearing file in a PAST sprint (s0) beside a canonical saying sprint 1 is in
# progress, plus one LIVING file that carries no derivation, so the corpus is not empty and the
# refusal is the join's "no fenced derivation" one rather than "lists no markdown file". S1c is the
# same world with the story under s1/ (CURRENT), the one property that differs: it must read as W1.
CANON="_bmad-output/implementation-artifacts/sprint-status.yaml"
build_scoped() { # build_scoped <dir> <slot dir under planning-artifacts> [<extra: past|none>]
  local c="$1" slot="$2" dest
  build_consumer "$c" "$THEIRS_BREAK" 1 real
  dest="_bmad-output/planning-artifacts/$slot/story.md"
  mkdir -p "$c/${dest%/*}" "$c/${CANON%/*}"
  mv "$c/$SF" "$c/$dest"
  printf '# Product requirements\n\nNo recorded derivation here.\n' > "$c/_bmad-output/planning-artifacts/prd.md"
  printf 'sprint: 1\nstatus: in_progress\n' > "$c/$CANON"
  if [ "${3:-none}" = past ]; then
    mkdir -p "$c/_bmad-output/planning-artifacts/s0"
    sed 's/Story/Old story/' "$c/$dest" > "$c/_bmad-output/planning-artifacts/s0/old.md"
  fi
  g "$c" add -A _bmad-output && g "$c" commit -qm "story under $slot"
}
WS1="$WORK/ws1-past";      build_scoped "$WS1"  s0
WS1C="$WORK/ws1c-current"; build_scoped "$WS1C" s1
WS3S="$WORK/ws3-both";     build_scoped "$WS3S" s1 past
K_S1="_bmad-output/planning-artifacts/s1/story.md:$(grep -n -- 'grep -c qqalpha' "$WS1C/_bmad-output/planning-artifacts/s1/story.md" | head -1 | cut -d: -f1)"
case "$K_S1" in *: ) echo "FIXTURE ERROR: the seeded S1 derivation line was not found" >&2; exit 2 ;; esac
if [ "$(tr -d ' \n' < "$WS1/$CANON")" = "sprint:1status:in_progress" ] && [ ! -f "$WS1/$SF" ] \
   && [ -f "$WS1/_bmad-output/planning-artifacts/s0/story.md" ] && [ -f "$WS1C/_bmad-output/planning-artifacts/s1/story.md" ]; then
  ok "S0 seed: a canonical names sprint 1 in progress, and the story sits under s0 in one world and s1 in the other"
else
  bad "S0 seed: the scoped worlds were not built -- S1 and S1c are unreadable"
fi
dd "$WS1"; OUTS1="$OUT"; RCS1="$RC"
rc_is "S1a the only derivation-bearing file is a PAST sprint's -> exit 2, a refusal" 2 "$RCS1"
ck "S1b and the refusal is the join's: no fenced derivation names a path (a past sprint's file has no row to clear)" "no fenced derivation names a path" "$OUTS1"
nk "S1e and no derivation was run: nothing is named NEWLY-FAILING" "NEWLY-FAILING" "$OUTS1"
dd "$WS1C"; OUTS1C="$OUT"; RCS1C="$RC"
rc_is "S1c near-miss: the same world, the story under s1/ (CURRENT) -> exit 1" 1 "$RCS1C"
ck "S1d and qqalpha is NEWLY-FAILING" "$(printf 'NEWLY-FAILING\t%s\t' "$K_S1")" "$OUTS1C"
dd "$WS3S"; OUTS3="$OUT"; RCS3="$RC"
rc_is "S3a a CURRENT file and a PAST file both break -> exit 1 on the CURRENT one alone" 1 "$RCS3"
ck "S3b the CURRENT file is NEWLY-FAILING" "$(printf 'NEWLY-FAILING\t%s\t' "$K_S1")" "$OUTS3"
rc_is "S3c exactly one NEWLY-FAILING row: the past sprint's file was never run" 1 "$(nrows NEWLY-FAILING "$OUTS3")"
ck "S3d the dropped file is NAMED by an INFO out-of-scope row" "$(printf 'INFO\tout-of-scope\tPAST\t_bmad-output/planning-artifacts/s0/old.md')" "$OUTS3"
nk "S3e and the CURRENT file is not named out-of-scope" "$(printf 'INFO\tout-of-scope\tPAST\t_bmad-output/planning-artifacts/s1')" "$OUTS3"

# S2: a classifier that cannot run is a refusal, never a guessed scope. THEIRS deletes it from the
# distribution and the consumer carries no copy, so neither source exists. The near-miss is the same
# distribution whose THEIRS keeps the classifier, and it reaches W1's verdict.
DIST3="$WORK/dist3"
mkdir -p "$DIST3/core/scripts"
g "$DIST3" init -q
printf 'qqprev\n' > "$DIST3/core/scripts/toy.sh"; seed_cls "$DIST3"
g "$DIST3" add -A && g "$DIST3" commit -qm prev3
PREV3="$(g "$DIST3" rev-parse HEAD)"
printf 'qqalpha\nqqgamma\n' > "$DIST3/core/scripts/toy.sh"
g "$DIST3" add -A && g "$DIST3" commit -qm base3
BASE3="$(g "$DIST3" rev-parse HEAD)"
printf 'qqgamma\nqqdelta\n' > "$DIST3/core/scripts/toy.sh"
g "$DIST3" add -A && g "$DIST3" commit -qm theirs3-keep
THEIRS3_KEEP="$(g "$DIST3" rev-parse HEAD)"
g "$DIST3" checkout -q "$BASE3" 2>/dev/null
printf 'qqgamma\nqqdelta\n' > "$DIST3/core/scripts/toy.sh"
g "$DIST3" rm -q core/scripts/check-owed-derivations.sh
g "$DIST3" add -A && g "$DIST3" commit -qm theirs3-no-classifier
THEIRS3_GONE="$(g "$DIST3" rev-parse HEAD)"
if [ -n "$PREV3" ] && [ -n "$BASE3" ] && [ "$THEIRS3_KEEP" != "$THEIRS3_GONE" ] \
   && g "$DIST3" cat-file -e "${THEIRS3_KEEP}:core/scripts/check-owed-derivations.sh" 2>/dev/null \
   && ! g "$DIST3" cat-file -e "${THEIRS3_GONE}:core/scripts/check-owed-derivations.sh" 2>/dev/null; then
  ok "S2 seed: one THEIRS carries the classifier and the other deletes it, both off the same BASE"
else
  bad "S2 seed: the classifier is not present at one THEIRS and absent at the other -- S2 is unreadable"
fi
build3() { ( DIST="$DIST3"; BASE="$BASE3"; PREV="$PREV3"; build_consumer "$1" "$2" 1 real ); }
WS2="$WORK/ws2-no-classifier"; build3 "$WS2" "$THEIRS3_GONE"
WS2C="$WORK/ws2c-classifier";  build3 "$WS2C" "$THEIRS3_KEEP"
[ ! -e "$WS2/scripts/ai-dlc/check-owed-derivations.sh" ] \
  || { echo "FIXTURE ERROR: the S2 consumer carries a classifier copy, so the fallback would be reachable" >&2; exit 2; }
dd "$WS2"; OUTS2="$OUT"; RCS2="$RC"
rc_is "S2a no classifier at THEIRS and none on the consumer -> exit 2" 2 "$RCS2"
ck "S2b and the refusal is the scope one" "$(printf 'REFUSED\tscope\t')" "$OUTS2"
nk "S2c and no verdict is printed over an unknown scope" "VERDICT" "$OUTS2"
dd "$WS2C"; OUTS2C="$OUT"; RCS2C="$RC"
rc_is "S2n near-miss: THEIRS keeps the classifier -> exit 1" 1 "$RCS2C"
ck "S2o and it names the broken derivation" "$(printf 'NEWLY-FAILING\t%s\t' "$K_ALPHA")" "$OUTS2C"

# ---- A10: the default base root leaves no worktree and no scratch behind --------------------
# CONTROL FIRST: the counter must see a worktree when one exists, or a 1 below is a counter that
# cannot count.
CTL="$WORK/wt-control"
g "$WORK" clone -q "$W1" "$CTL" 2>/dev/null
g "$CTL" worktree add -q --detach "$WORK/wt-control-extra" HEAD 2>/dev/null
c_ctl="$(wtcount "$CTL")"
if [ "$c_ctl" = 2 ]; then
  ok "A10a control: the counter reads 2 on a repository carrying one extra worktree"
else
  bad "A10a control: the counter read $c_ctl on a repository carrying one extra worktree, expected 2 -- A10b is unreadable"
fi
leaked=""
for c in "$W1" "$W2" "$W3" "$W5" "$W5P" "$WSU" "$WSUN" "$W13" "$W13N" "$WS3" "$WS3N" "$W16" "$W16N" "$W17" "$W17N" "$W18" "$W19" "$WS1" "$WS1C" "$WS3S" "$WS2" "$WS2C"; do
  # W6 is left out on purpose: it carries the seeded LEAKED worktree A12c asserts is kept.
  n="$(wtcount "$c")"; [ "$n" = 1 ] || leaked="$leaked $(basename "$c")=$n"
done
if [ -z "$leaked" ]; then
  ok "A10b every consumer the default base root was built on lists exactly one worktree afterwards, including the refused runs"
else
  bad "A10b a default-base-root run left a worktree registered:$leaked"
fi
left="$(find "$DDTMP" -mindepth 1 -maxdepth 1 2>/dev/null | awk 'END { print NR + 0 }')"
rc_is "A10c the helper left nothing under its TMPDIR" 0 "$left"

if [ "$fails" -ne 0 ]; then
  printf '  %s assertion(s) FAILED\n' "$fails"; exit 1
fi
printf '  all assertions hold\n'
exit 0
