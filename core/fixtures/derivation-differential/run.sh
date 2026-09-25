#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# derivation-differential — assert reconcile/derivation-differential.sh clears the
# `WORKLIST artifact-derivations` row on what THIS PULL broke, and on nothing else.
#
# Usage: run.sh [<path-to-derivation-differential.sh>]
#   The argument exists for `derivation-differential-mutants`, which drives this file against
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

VALIDATOR="$(pick "$HERE/../../scripts/validate-artifact-derivations.sh" \
                  "$HERE/../../../scripts/ai-dlc/validate-artifact-derivations.sh" \
                  "$HERE/../../../core/scripts/validate-artifact-derivations.sh")"
[ -n "$VALIDATOR" ] || { echo "FIXTURE ERROR: cannot locate validate-artifact-derivations.sh, which the helper runs on both sides" >&2; exit 2; }

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

# ---- the distribution ---------------------------------------------------------------------
DIST="$WORK/dist"
mkdir -p "$DIST/core/scripts"
g "$DIST" init -q
printf 'qqprev\n' > "$DIST/core/scripts/toy.sh"
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
# Writes <dir>/.T so every helper call drives this world with THIS world's theirs ref. With a fifth
# argument the pre-apply stamp also carries `skill_commit: <that value>`; without one it has no
# such line at all, which is the ABSENT case the walk accepts.
build_consumer() {
  local c="$1" t="$2" applied="$3" vkind="$4" sk="${5:-}"
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
  [ -n "$sk" ] && printf 'skill_commit: %s\n' "$sk" >> "$c/.claude/.ai-dlc-version"
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
printf 'version: 1.0.0\ncommit: %s\n' "$BASE" > "$BROKEN/.claude/.ai-dlc-version"
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
g "$DIST2" add -A && g "$DIST2" commit -qm base2
BASE2="$(g "$DIST2" rev-parse HEAD)"
printf 'qqother\n' > "$DIST2/core/scripts/su.sh"; printf 'rule-b\n' > "$DIST2/core/rules/su.md"
g "$DIST2" add -A && g "$DIST2" commit -qm theirs2
THEIRS2="$(g "$DIST2" rev-parse HEAD)"
[ -n "$BASE2" ] && [ -n "$THEIRS2" ] && [ "$BASE2" != "$THEIRS2" ] \
  || { echo "FIXTURE ERROR: seeded dist2 refs unresolvable or equal" >&2; exit 2; }

# build_su <dir> <derivation-over-machinery: broken|unchanged> [<self-update skill_commit: theirs|empty|absent>]
build_su() {
  local c="$1" kind="$2" suk="${3:-theirs}"
  mkdir -p "$c/scripts/ai-dlc" "$c/.claude/rules" "$c/_bmad-output"
  g "$c" init -q
  cp "$VALIDATOR" "$c/scripts/ai-dlc/validate-artifact-derivations.sh"
  g "$DIST2" show "${BASE2}:core/scripts/su.sh" > "$c/scripts/ai-dlc/su.sh"
  g "$DIST2" show "${BASE2}:core/scripts/keep.sh" > "$c/scripts/ai-dlc/keep.sh"
  g "$DIST2" show "${BASE2}:core/rules/su.md" > "$c/.claude/rules/su.md"
  # the PRE-PULL tree: skill_commit: present and equal to commit:, as a completed reconcile writes it
  printf 'version: 1.0.0\ncommit: %s\nskill_version: 1.0.0\nskill_commit: %s\n' "$BASE2" "$BASE2" > "$c/.claude/.ai-dlc-version"
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
# when `ps -p` finds no process with that PID: a CONCURRENT live run's worktree is spelled
# identically, and naming it with a removal remedy pulls the tree out from under that run. So three
# are seeded: LEAKED records the PID of a child this fixture started and reaped (dead), LIVE records
# this fixture's own PID (alive for as long as the helper runs), and FOREIGN records PID 1 -- always
# alive and never ours, the shape of a concurrent run by ANOTHER uid, where `kill -0` fails with
# EPERM and read a live run as dead. Only LEAKED may be named.
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
if ! ps -p "$DEADPID" >/dev/null 2>&1 && ps -p "$$" >/dev/null 2>&1; then
  ok "A12 control: ps -p finds no recorded dead PID and finds the recorded live PID"
else
  bad "A12 control: ps -p does not separate the seeded dead PID ($DEADPID) from the live one ($$) -- A12b and A12l are unreadable"
fi
# The FOREIGN control is the discriminating input: PID 1 is alive AND `kill -0` fails on it, so
# the two liveness tests disagree there. Run as root, `kill -0 1` succeeds and the seed no longer
# separates them; the control says so rather than letting A12e pass for the wrong reason.
if ps -p 1 >/dev/null 2>&1 && ! kill -0 1 2>/dev/null; then
  ok "A12 control: PID 1 is alive under ps -p and fails kill -0 (EPERM), so FOREIGN separates the two tests"
else
  bad "A12 control: PID 1 does not separate ps -p from kill -0 here (running as root?) -- A12e is unreadable"
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
# the walk accepts -- the two differ in exactly one property, the presence of the line.
WS3="$WORK/w15-empty-sk";   build_su "$WS3"  broken empty
WS3N="$WORK/w15-absent-sk"; build_su "$WS3N" broken absent
if grep -qx 'skill_commit: ' <<<"$(g "$WS3" show "HEAD:.claude/.ai-dlc-version")" \
   && ! grep -q '^skill_commit:' <<<"$(g "$WS3N" show "HEAD:.claude/.ai-dlc-version")"; then
  ok "A15 seed: one self-update commit carries an empty skill_commit: line, the other none"
else
  bad "A15 seed: the empty/absent skill_commit: shapes were not written -- A15 is unreadable"
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
for c in "$W1" "$W2" "$W3" "$W5" "$W5P" "$WSU" "$WSUN" "$W13" "$W13N" "$WS3" "$WS3N" "$W16" "$W16N"; do
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
