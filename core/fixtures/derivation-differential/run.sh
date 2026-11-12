#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# derivation-differential — assert reconcile/derivation-differential.sh clears the
# `WORKLIST artifact-derivations` row on what THIS PULL broke, and on nothing else.
#
# Usage: run.sh [--matrix] [<path-to-derivation-differential.sh>]
#   The path argument existed for a retired mutation battery, which drove this file against
#   mutated copies. With no argument the subject is found beside this fixture in either layout.
#   `--matrix` runs every P mutant over every P world and prints one MATRIX row each.
#
# THE P MUTANT MATRIX (the P section's header says how each is built and scored). Re-measured whenever a P
# arm or mutant is added or changed, from the repo root, with AI_DLC_VERDICT_STORE set to a fresh mktemp dir.
# Per push each mutant runs its FIRST decides arm's world only; `decides` lists every arm the matrix found red.
# MUTANT-MATRIX dd-nocmp decides=Piii_nf,Piiip_nf twins=Piii_ctl
# MUTANT-MATRIX dd-trunc decides=Piiip_nf twins=Piiip_ctl
# MUTANT-MATRIX dd-noroots decides=Pv_nf,Ptpl_nf twins=Pv_ctl
# MUTANT-MATRIX dd-untracked decides=Pvi_nf twins=Pvi_ctl
# MUTANT-MATRIX dd-nocap decides=Pvii_nf twins=Pvii_ctl
# MUTANT-MATRIX dd-capoff1 decides=Pviic_sb twins=Pviic_ctl
# MUTANT-MATRIX dd-noskipline decides=Pvii_nf twins=Pvii_ctl
# MUTANT-MATRIX dd-cap256 decides=Pi_row,Pi_owed,Pii_sb,Pix_sb,Pcapabc_sb,Pcapzero_sb twins=Pi_ctl
# MUTANT-MATRIX dd-capvalid decides=Pcapzero_sb,Pcapabc_sb twins=Pcapzero_ctl
# MUTANT-MATRIX dd-capvalid-abc decides=Pcapabc_sb twins=Pcapabc_ctl
# MUTANT-MATRIX dd-notpl decides=Ptpl_nf twins=Ptpl_ctl
# MUTANT-MATRIX dd-noisy decides=Pii_nf,Piv_hb,Piv_pc,Pv_nf,Pvi_nf,Pix_nf,Ptpl_nf twins=Pii_sb
# MUTANT-MATRIX dd-baseroot decides=Pviii_nf twins=Pviii_tree
# MUTANT-MATRIX dd-lateowed decides=Pi_owed,Pii_sb twins=Pi_row
# MUTANT-MATRIX dd-unbounded decides=Pi_bound twins=Pi_ctl
# MUTANT-MATRIX vd-sidecar decides=Px_unset twins=Px_set
# MUTANT-MATRIX-DYNAMIC pscore why=pscore passes its first argument to mutant_killed; each of its sixteen callers names a literal mutant carrying its own row above
# MUTANT-MATRIX-REMEASURE bash core/fixtures/derivation-differential/run.sh --matrix
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
# `--matrix` scores every P mutant over every P world (see the P MUTANTS section); a plain run scores each on its
# deciding world only. hermetic-run.sh forwards no argument, so the matrix is re-measured by a direct run.
PMATRIX=0
case "${1:-}" in --matrix) PMATRIX=1; shift ;; esac
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
MUT_LIB="$HERE/../lib/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
printf 'HERMETIC-CONSUMED core/fixtures/lib/mutant.sh\n'

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
# NOTHING HERE EXECS `ps`, `sandbox-exec` OR ANY SETUID BINARY. `/bin/ps` is setuid root, and under
# the read-set tracer's `sandbox-exec` profile its exec is refused for every pid, so controls keyed
# on it failed there and took the fixture out of the trace; and the pre-push trace (`--local-map`)
# discards any fixture that execs a setuid binary or `sandbox-exec`. The controls read `kill -0`'s
# own answer instead. The refused-`ps` world is re-created with a SHIM (A12s..A12w below), not a
# sandbox, so the fixture stays traceable.
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
k0_dead="$(export LC_ALL=C; kill -0 "$DEADPID" 2>&1)"; k0_dead_rc=$?
k0_live="$(export LC_ALL=C; kill -0 "$$" 2>&1)"; k0_live_rc=$?
if [ "$k0_dead_rc" -ne 0 ] && [ "${k0_dead%No such process}" != "$k0_dead" ] && [ "$k0_live_rc" -eq 0 ]; then
  ok "A12 control: kill -0 answers ESRCH for the recorded dead PID and succeeds on the recorded live PID"
else
  bad "A12 control: kill -0 does not separate the seeded dead PID ($DEADPID: rc $k0_dead_rc, $k0_dead) from the live one ($$: rc $k0_live_rc) -- A12b and A12l are unreadable"
fi
# The FOREIGN control is the discriminating input: PID 1 is alive AND bare `kill -0` fails on it,
# with EPERM, so a test reading only the status calls it dead. Run as root, `kill -0 1` succeeds and
# the seed no longer exercises the EPERM branch; the control says so rather than letting A12e pass
# for the wrong reason.
k0_one="$(export LC_ALL=C; kill -0 1 2>&1)"; k0_one_rc=$?
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
# ---- A12 in the REFUSED-`ps` world: the read-set tracer's, re-created with a shim ----------------
# Inside the tracer's `sandbox-exec` profile `/bin/ps` is setuid and its exec is refused: run from a
# bash script, `ps -p <pid>` exits 126 and bash writes `<script>: line <N>: /bin/ps: Operation not
# permitted` (measured once, directly, under the profile shape derive-fixture-readsets.sh writes for
# `--tracer sandbox`). The shim answers exactly that, so a liveness test that execs `ps` reads EVERY
# PID dead here, as it did under the tracer, and names LIVE and FOREIGN. No sandbox is entered: the
# pre-push trace discards a fixture that execs `sandbox-exec` or a setuid binary, and the fixture
# must stay traceable. The real-sandbox anchor for this shim lives in BL-610's receipt.
PSHIM="$WORK/ps-refused"; mkdir -p "$PSHIM"
printf '#!/usr/bin/env bash\nprintf '"'"'%%s: line 1: /bin/ps: Operation not permitted\\n'"'"' "$0" >&2\nexit 126\n' > "$PSHIM/ps"
chmod +x "$PSHIM/ps"
shim_err="$(PATH="$PSHIM:$PATH" ps -p "$$" 2>&1 >/dev/null)"; shim_rc=$?
if [ "$shim_rc" -eq 126 ] && [ "${shim_err%: /bin/ps: Operation not permitted}" != "$shim_err" ] \
   && [ "$(PATH="$PSHIM:$PATH" command -v ps)" = "$PSHIM/ps" ]; then
  ok "A12s the shim is first on PATH and answers as the tracer's refusal: exit 126, '/bin/ps: Operation not permitted'"
else
  bad "A12s the ps shim does not answer as the tracer's refusal (rc $shim_rc: $shim_err) -- A12t..A12x are unreadable"
fi
# SELF-PROBE: the subject's own liveness function, fed the refusal as its answer, must read
# "cannot tell" -- live, never dead -- for a live PID, a reaped child and PID 1 alike, so no worktree
# is ever named on the strength of a refused probe. `kill` is overridden by a function inside a
# subshell, which shadows the builtin; nothing is exec'd.
PL_FN="$(awk '/^pid_live\(\) \{/,/^}$/' "$SUBJ")"
if [ -z "$PL_FN" ]; then
  bad "A12t the subject defines no pid_live() -- its liveness test cannot be fed the refusal"
else
  pl_dead=""
  for _p in "$$" "$DEADPID" 1; do
    ( eval "$PL_FN"
      kill() { printf '%s\n' "$shim_err" >&2; return 126; }
      pid_live "$_p" ) || pl_dead="$pl_dead $_p"
  done
  if [ -z "$pl_dead" ]; then
    ok "A12t pid_live reads the refused-ps answer as live (cannot tell) for \$\$, a reaped child and PID 1"
  else
    bad "A12t pid_live reads the refused-ps answer as DEAD for:$pl_dead -- a refused probe would name a worktree"
  fi
fi
OUT12P="$(cd / && PATH="$PSHIM:$PATH" TMPDIR="$DDTMP" bash "$SUBJ" "$(cat "$W6/.D")" "$(cat "$W6/.B")" "$W6" "$(cat "$W6/.T")" 2>&1)"; RC12P=$?
rc_is "A12u with ps refused the verdict is unchanged -> exit 1" 1 "$RC12P"
ck "A12v with ps refused the DEAD run's worktree is still NAMED" "$(printf 'NOTE\tworktree\t%s is a registered worktree' "$LEAK")" "$OUT12P"
nk "A12w near-miss with ps refused: the LIVE run's worktree is NOT named" "$LIVE" "$OUT12P"
nk "A12x near-miss with ps refused: the other-uid run's worktree (PID 1) is NOT named" "$FRGN" "$OUT12P"
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
    printf '#!/bin/bash\n'
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

# ---- P: the IGNORED-FILE OVERLAY ------------------------------------------------------------------
# A directory-walking derivation over a directory holding a consumer IGNORED file that predates the
# pull passes at the base worktree, which holds no ignored file, and fails at the consumer. The
# helper's second pass copies those files into its own base worktree and relabels the row STALE-BOTH
# only when both roots' FULL outputs are then byte-equal. Every P world is ONE property away from
# that relabel, and every arm asserts the exit AND the named row's status:
#   Pi    the consumer's shape: 300 ignored files in a tests __pycache__ (over the old 256 default,
#         under the 4096 one), recorded output over 160 columns, record mode -> STALE-BOTH + NOTE,
#         exit 0, no OWED row
#         Pi_bound: its relabel NOTE carries the count, exactly five paths and `… and 295 more`, under 1000 bytes;
#         Pi_two: a second artifact with the same fence relabels too, each key with its own bounded NOTE
#   Pii   Pi's fence beside a real line shift -> the shift NEWLY-FAILING and OWED, Pi's fence STALE-BOTH
#   Piii  a pre-existing ignored file AND a pull-made line in ONE fence -> NEWLY-FAILING
#   Piiip Piii with the pull-made line past column 160 of the joined output -> NEWLY-FAILING
#   Piv   a file the RANGE ADDS (untracked at hand-back, tracked post-commit) -> NEWLY-FAILING both states
#   Pv    an ignored file under an INSTALL ROOT (.claude/) -> NEWLY-FAILING
#   Pvi   an untracked-NOT-ignored pre-existing file -> NEWLY-FAILING (the documented residual)
#   Pvii  cap+1 ignored files, the cap overridden small (AI_DLC_DD_OVERLAY_CAP) -> NEWLY-FAILING and the
#         skip row naming the exact count and cap
#   Pviic exactly cap ignored files -> relabelled (the off-by-one twin of Pvii)
#   Pcap  AI_DLC_DD_OVERLAY_CAP=abc and =0 are refused, so Pi's 300 files relabel under the default
#   Pviii Pi under --base-root -> NEWLY-FAILING with the --base-root skip row, and that root is unchanged
#   Pix   Pii in the post-commit state (base root HEAD^)
#   Proot a fence whose operand is the project root -> NEWLY-FAILING with the root-operand skip row
#   Ptpl  an ignored TEMPLATE SITE (docs/coding-conventions.md) the pull rewrites -> NEWLY-FAILING
#   Pnots Pi driven by a helper copy with no template-sites.md beside it -> fails closed, NEWLY-FAILING
#   Pnoop a fence whose only path word is a glob, so no operand -> NEWLY-FAILING with the no-operand row
#   Plong an artifact path whose old-scheme sidecar name ran past 255 bytes -> relabelled
#   Pnosc, Psym, Pnest, Pcpfail: a consumer validator without the opt-in, an ignored symlink, an ignored
#         nested repository (a directory entry), an unreadable ignored file -> NEWLY-FAILING, each with
#         its own skip row, byte for byte; Piii/Piiip/Pv/Pvi assert theirs too
#   Px    the validator's AI_DLC_VD_FULL_OUT_DIR opt-in: unset, byte-identical to the opt-in stripped
#         out and no file written; set, one ordinal file per compared derivation, an index naming each,
#         and the same output
# THE IGNORED FILE IS TEXT WHEREVER AN ARM NEEDS IT SEEN. GNU grep >= 3.5 prints a binary match on
# stderr, which the validator discards, so a NUL-bearing seed would show no difference there and Pi
# would read red for no subject reason. Pi carries BOTH: a NUL `.pyc` (BSD grep's `Binary file P
# matches` on stdout, the consumer's exact shape) and a text `.pyc` any grep prints.
# Each world is built ONCE as a template and copied fresh for every run (the record, the post-commit
# commit and each copy driven below never share a tree).
g "$DIST" checkout -q "$BASE" 2>/dev/null
printf 'qqalpha\nqqgamma\nqqtok added by theirs\n' > "$DIST/core/scripts/toy.sh"
g "$DIST" add -A && g "$DIST" commit -qm theirs-tok
THEIRS_TOK="$(g "$DIST" rev-parse HEAD)"
g "$DIST" checkout -q "$BASE" 2>/dev/null
printf 'qqgamma\nqqdelta\n' > "$DIST/core/scripts/toy.sh"
printf 'qqtok blob\n' > "$DIST/core/scripts/blob.pyc"
g "$DIST" add -A && g "$DIST" commit -qm theirs-bin
THEIRS_BIN="$(g "$DIST" rev-parse HEAD)"
[ -n "$THEIRS_TOK" ] && [ -n "$THEIRS_BIN" ] && [ "$THEIRS_TOK" != "$THEIRS_BIN" ] \
  || { echo "FIXTURE ERROR: the P dist refs are unresolvable or equal" >&2; exit 2; }
P_LONG="$(printf '%0200d' 0 | tr 0 L)"
[ "${#P_LONG}" = 200 ] || { echo "FIXTURE ERROR: could not build the 200-column P seed line" >&2; exit 2; }

# ov_seed <dir> <kind> <phase: tracked|fences|after> -- the per-kind part of a P world
ov_seed() {
  local c="$1" k="$2" i n
  case "$2:$3" in
    i:tracked|ii:tracked|ix:tracked)
      mkdir -p "$c/rebal/tests"; printf '__pycache__/\n' > "$c/.gitignore"
      printf '# qqtok %s\n' "$P_LONG" > "$c/rebal/tests/test_a.py" ;;
    i:fences|ii:fences|ix:fences)
      printf 'The test files that carry the token.\n\n```derived\n$ grep -rn -F qqtok rebal/tests\nrebal/tests/test_a.py:1:# qqtok %s\n```\n\n' "$P_LONG"
      case "$k" in ii|ix) printf 'The line the gamma marker sits on.\n\n```derived\n$ grep -n qqgamma scripts/ai-dlc/toy.sh\n2:qqgamma\n```\n\n' ;; esac ;;
    i:after|ii:after|ix:after)
      mkdir -p "$c/rebal/tests/__pycache__"
      printf 'qqtok\000bin\n' > "$c/rebal/tests/__pycache__/test_a.cpython-311.pyc"
      printf 'qqtok cached\n' > "$c/rebal/tests/__pycache__/test_b.cpython-311.pyc"
      i=1; while [ "$i" -le 298 ]; do printf -v n 'f%03d.cpython-311.pyc' "$i"; printf 'x\n' > "$c/rebal/tests/__pycache__/$n"; i=$((i + 1)); done ;;
    iii:tracked|iiip:tracked)
      mkdir -p "$c/src"; printf '__pycache__/\n' > "$c/.gitignore"
      if [ "$k" = iii ]; then printf 'qqtok here\n' > "$c/src/a.txt"; else printf '# qqtok %s\n' "$P_LONG" > "$c/src/a.txt"; fi ;;
    iii:fences|iiip:fences)
      printf 'The source lines and the toy script lines that carry the token.\n\n```derived\n$ grep -rn -F qqtok src scripts/ai-dlc/toy.sh\n'
      sed 's#^#src/a.txt:1:#' "$c/src/a.txt"; printf '```\n\n' ;;
    iii:after|iiip:after)
      mkdir -p "$c/src/__pycache__"; printf 'qqtok cached\n' > "$c/src/__pycache__/a.cpython-311.pyc" ;;
    iv:tracked|ivpc:tracked) printf 'qqtok note\n' > "$c/scripts/ai-dlc/notes.txt" ;;
    iv:fences|ivpc:fences)
      printf 'The installed files that carry the token.\n\n```derived\n$ grep -rn -F qqtok scripts/ai-dlc\nscripts/ai-dlc/notes.txt:1:qqtok note\n```\n\n' ;;
    iv:after|ivpc:after) : ;;
    v:tracked) mkdir -p "$c/.claude/notes"; printf '*.pyc\n' > "$c/.gitignore"; printf 'qqtok note\n' > "$c/.claude/notes/n.txt" ;;
    v:fences) printf 'The notes that carry the token.\n\n```derived\n$ grep -rn -F qqtok .claude/notes\n.claude/notes/n.txt:1:qqtok note\n```\n\n' ;;
    v:after) printf 'qqtok cached\n' > "$c/.claude/notes/x.pyc" ;;
    vi:tracked) mkdir -p "$c/lib"; printf 'qqtok lib\n' > "$c/lib/l.txt" ;;
    vi:fences) printf 'The library files that carry the token.\n\n```derived\n$ grep -rn -F qqtok lib\nlib/l.txt:1:qqtok lib\n```\n\n' ;;
    vi:after) printf 'qqtok data\n' > "$c/lib/qqdata.blob" ;;
    vii:tracked|viic:tracked) mkdir -p "$c/cache"; printf '*.pyc\n' > "$c/.gitignore"; printf 'qqtok keep\n' > "$c/cache/keep.txt" ;;
    vii:fences|viic:fences) printf 'The cache files that carry the token.\n\n```derived\n$ grep -rn -F qqtok cache\ncache/keep.txt:1:qqtok keep\n```\n\n' ;;
    vii:after|viic:after)
      # P_CAP+1 ignored files (vii) or exactly P_CAP (viic), the cap set by the helper's override for these two runs
      printf 'qqtok cached\n' > "$c/cache/m000.pyc"
      n="$P_CAP"; [ "$k" = vii ] && n=$((P_CAP + 1))
      i=1; while [ "$i" -lt "$n" ]; do printf 'x\n' > "$c/cache/m00$i.pyc"; i=$((i + 1)); done ;;
    tplsite:tracked)
      # docs/coding-conventions.md is a TEMPLATE SITE the apply rewrites; this consumer ignores it
      mkdir -p "$c/docs"; printf 'docs/coding-conventions.md\n' > "$c/.gitignore"
      printf 'qqtok tracked\n' > "$c/docs/a.md"; printf 'conventions, pre-pull, no token\n' > "$c/docs/coding-conventions.md" ;;
    tplsite:fences) printf 'The docs that carry the token.\n\n```derived\n$ grep -rn -F qqtok docs\ndocs/a.md:1:qqtok tracked\n```\n\n' ;;
    tplsite:after) printf 'conventions, post-pull\nqqtok rule the pull added\n' > "$c/docs/coding-conventions.md" ;;
    long:tracked|nosc:tracked|sym:tracked|nest:tracked|cpfail:tracked)
      mkdir -p "$c/src"; printf '__pycache__/\n' > "$c/.gitignore"; printf 'qqtok here\n' > "$c/src/a.txt" ;;
    long:fences|nosc:fences|sym:fences|nest:fences|cpfail:fences)
      printf 'The source lines that carry the token.\n\n```derived\n$ grep -rn -F qqtok src\nsrc/a.txt:1:qqtok here\n```\n\n' ;;
    long:after|nosc:after|sym:after|nest:after|cpfail:after)
      mkdir -p "$c/src/__pycache__"; printf 'qqtok cached\n' > "$c/src/__pycache__/a.cpython-311.pyc"
      case "$k" in
        sym) ln -s ../a.txt "$c/src/__pycache__/l.pyc" ;;
        nest) mkdir -p "$c/src/__pycache__/sub"; g "$c/src/__pycache__/sub" init -q; printf 'qqtok nested\n' > "$c/src/__pycache__/sub/n.txt" ;;
      esac ;;
    root:tracked|root:after|noop:tracked|noop:after) : ;;
    noop:fences)
      # the only path word is a GLOB, which the operand reader skips: no word names an existing path
      printf 'The alpha count, through a glob.\n\n```derived\n$ grep -c qqalpha scripts/ai-dlc/to*.sh\n1\n```\n\n' ;;
    root:fences)
      # the recorded output is written by build_ov from a RUN of the command at the pre-apply commit (the walk order is grep's)
      printf 'Every file that names the alpha marker.\n\n```derived\n$ grep -rl qqalpha .\n@ROOT-OUTPUT@\n```\n\n' ;;
    x:tracked) : ;;
    x:fences)
      printf 'A command with no output and nothing recorded.\n\n```derived\n$ grep qqnothing scripts/ai-dlc/toy.sh\n```\n\n'
      printf 'A figure that was already wrong.\n\n```derived\n$ grep -c qqbeta scripts/ai-dlc/toy.sh\n7\n```\n\n'
      printf 'A command the checker refuses to run.\n\n```derived\n$ perl -ne print scripts/ai-dlc/toy.sh\nqqalpha\n```\n\n' ;;
    x:after) : ;;
    *) echo "FIXTURE ERROR: ov_seed has no $2:$3" >&2; exit 2 ;;
  esac
}
# psf <kind> -> the world's artifact path. `long` puts it under a 200-character directory, so the key's absolute
# path, encoded the way the validator first named its full-output files (`/` as %2F), runs past 255 bytes.
P_LONGDIR="$(printf '%0200d' 0 | tr 0 d)"
# the overlay reads template-sites.md beside the subject for the template sites it must never copy
[ -f "$(dirname "$SUBJ")/template-sites.md" ] || { echo "FIXTURE ERROR: template-sites.md is not beside the subject" >&2; exit 2; }
printf 'HERMETIC-CONSUMED core/skills/ai-dlc-update/reconcile/template-sites.md\n'
psf() { case "$1" in long) printf '_bmad-output/%s/story.md' "$P_LONGDIR" ;; *) printf '%s' "$SF" ;; esac; }
# build_ov <dir> <theirs> <kind> -- a hand-back consumer; the kinds ix and ivpc are then committed
# (the step-8 commit: the stamp re-written to theirs), so their base root is HEAD^.
build_ov() {
  local c="$1" t="$2" k="$3"
  mkdir -p "$c/scripts/ai-dlc" "$c/.claude" "$c/_bmad-output"
  g "$c" init -q
  cp "$VALIDATOR" "$c/scripts/ai-dlc/validate-artifact-derivations.sh"
  # the scope classifier as the installer places it: --record-owed classifies each row it records with it
  mkdir -p "$c/.claude/schemas"
  cp "$CLASSIFIER" "$c/scripts/ai-dlc/check-owed-derivations.sh"; cp "$SPRINTSH" "$c/scripts/ai-dlc/sprint-status.sh"
  cp "$SPRINTSCHEMA" "$c/.claude/schemas/sprint-status.json"
  printf 'qqprev\n' > "$c/scripts/ai-dlc/toy.sh"
  printf 'version: 0.9.0\ncommit: %s\n' "$PREV" > "$c/.claude/.ai-dlc-version"
  # nosc: the consumer's installed validator PREDATES the AI_DLC_VD_FULL_OUT_DIR opt-in (its two call sites removed)
  if [ "$k" = nosc ]; then
    awk '!index($0, "]; then vd_full_out \"$f\" \"$ln\"")' "$VALIDATOR" > "$c/scripts/ai-dlc/validate-artifact-derivations.sh"
  fi
  ov_seed "$c" "$k" tracked
  mkdir -p "$c/$(dirname "$(psf "$k")")"
  {
    printf '# Story\n\n'
    ov_seed "$c" "$k" fences
    printf 'A figure that holds on both sides.\n\n```derived\n$ grep -c qqgamma scripts/ai-dlc/toy.sh\n1\n```\n'
  } > "$c/$(psf "$k")"
  # Pi carries the consumer's real shape: a SECOND artifact with the same fence over the same >5-file cache, so two
  # keys relabel in one run (Pi_two)
  [ "$k" = i ] && cp "$c/$(psf "$k")" "$c/_bmad-output/story2.md"
  g "$c" add -A && g "$c" commit -qm "install 0.9.0"
  printf 'qqalpha\nqqgamma\n' > "$c/scripts/ai-dlc/toy.sh"
  printf 'version: 1.0.0\ncommit: %s\nskill_commit: %s\n' "$BASE" "$BASE" > "$c/.claude/.ai-dlc-version"
  g "$c" add -A && g "$c" commit -qm "pull to 1.0.0"
  if [ "$k" = root ]; then
    (cd "$c" && grep -rl qqalpha . > "$c/.root-out" 2>/dev/null)
    awk -v f="$c/.root-out" '$0 == "@ROOT-OUTPUT@" { while ((getline l < f) > 0) print l; next } { print }' \
      "$c/_bmad-output/story.md" > "$c/.story" && mv "$c/.story" "$c/_bmad-output/story.md"
    rm -f "$c/.root-out"
    g "$c" commit -qam "pull to 1.0.0" --amend
  fi
  g "$DIST" show "${t}:core/scripts/toy.sh" > "$c/scripts/ai-dlc/toy.sh"
  if g "$DIST" cat-file -e "${t}:core/scripts/blob.pyc" 2>/dev/null; then
    g "$DIST" show "${t}:core/scripts/blob.pyc" > "$c/scripts/ai-dlc/blob.pyc"
  fi
  ov_seed "$c" "$k" after
  case "$k" in
    ix|ivpc)
      printf 'version: 1.1.0\ncommit: %s\nskill_commit: %s\n' "$t" "$t" > "$c/.claude/.ai-dlc-version"
      g "$c" add -A && g "$c" commit -qm "reconcile 1.1.0" ;;
  esac
  printf '%s\n' "$t" > "$c/.T"; printf '%s\n' "$DIST" > "$c/.D"; printf '%s\n' "$BASE" > "$c/.B"
}
P_CAP=3
P_WORLDS="i ii iii iiip iv ivpc v vi vii viic viii ix root tplsite long nosc sym nest cpfail noop x"
for _w in $P_WORLDS; do
  case "$_w" in
    viii) continue ;;
    iii|iiip) _t="$THEIRS_TOK" ;;
    iv|ivpc) _t="$THEIRS_BIN" ;;
    *) _t="$THEIRS_BREAK" ;;
  esac
  build_ov "$WORK/tpl-$_w" "$_t" "$_w"
done
# pkey <world> <fixed string of the fence command> -> the row key of that fence
pkey() { local f; f="$(psf "$1")"; printf '%s:%s' "$f" "$(grep -n -F -- "\$ $2" "$WORK/tpl-$1/$f" | head -1 | cut -d: -f1)"; }
P_KI="$(pkey i 'grep -rn -F qqtok rebal/tests')"
P_KI2="_bmad-output/story2.md:${P_KI##*:}"
cmp -s "$WORK/tpl-i/$SF" "$WORK/tpl-i/_bmad-output/story2.md" || { echo "FIXTURE ERROR: Pi's second artifact does not carry the same fences" >&2; exit 2; }
P_KG="$(pkey i 'grep -c qqgamma')"
P_KII="$(pkey ii 'grep -n qqgamma')"
P_KIIS="$(pkey ii 'grep -rn -F qqtok rebal/tests')"
P_KIII="$(pkey iii 'grep -rn -F qqtok src')"
P_KIV="$(pkey iv 'grep -rn -F qqtok scripts/ai-dlc')"
P_KV="$(pkey v 'grep -rn -F qqtok .claude/notes')"
P_KVI="$(pkey vi 'grep -rn -F qqtok lib')"
P_KVII="$(pkey vii 'grep -rn -F qqtok cache')"
P_KROOT="$(pkey root 'grep -rl qqalpha .')"
P_KTPL="$(pkey tplsite 'grep -rn -F qqtok docs')"
P_KLONG="$(pkey long 'grep -rn -F qqtok src')"
P_KSRC="$(pkey nosc 'grep -rn -F qqtok src')"
P_KNOOP="$(pkey noop 'grep -c qqalpha scripts/ai-dlc/to*.sh')"
case "$P_KNOOP" in *:) echo "FIXTURE ERROR: the noop fence line was not found" >&2; exit 2 ;; esac
for _w in sym nest cpfail; do
  [ "$(pkey "$_w" 'grep -rn -F qqtok src')" = "$P_KSRC" ] || { echo "FIXTURE ERROR: the $_w story does not share nosc's fence layout" >&2; exit 2; }
done
for _k in "$P_KTPL" "$P_KLONG" "$P_KSRC" "$P_KROOT" "$P_KI" "$P_KG" "$P_KII" "$P_KIIS" "$P_KIII" "$P_KIV" "$P_KV" "$P_KVI" "$P_KVII"; do
  case "$_k" in *: ) echo "FIXTURE ERROR: a seeded P derivation line was not found" >&2; exit 2 ;; esac
done

# P0 SEED: every seeded file carries the porcelain code its arm is about, read the way the helper reads it.
pcode() { g "$1" status --porcelain --ignored -uall -- "$2" 2>/dev/null | cut -c1-2 | head -1; }
p0=""
for _s in "i rebal/tests/__pycache__/test_b.cpython-311.pyc !!" "i rebal/tests/__pycache__/test_a.cpython-311.pyc !!" \
          "ix rebal/tests/__pycache__/test_b.cpython-311.pyc !!" "iii src/__pycache__/a.cpython-311.pyc !!" \
          "iiip src/__pycache__/a.cpython-311.pyc !!" "iv scripts/ai-dlc/blob.pyc ??" "v .claude/notes/x.pyc !!" \
          "vi lib/qqdata.blob ??" "vii cache/m000.pyc !!" "viic cache/m000.pyc !!"; do
  set -f; set -- $_s; set +f
  [ "$(pcode "$WORK/tpl-$1" "$2")" = "$3" ] || p0="$p0 $1:$2(want $3, got [$(pcode "$WORK/tpl-$1" "$2")])"
done
[ -z "$(pcode "$WORK/tpl-ivpc" scripts/ai-dlc/blob.pyc)" ] && g "$WORK/tpl-ivpc" cat-file -e HEAD:scripts/ai-dlc/blob.pyc 2>/dev/null \
  || p0="$p0 ivpc:blob.pyc(not tracked post-commit)"
pign() { g "$1" status --porcelain --ignored -uall -- "$2" | awk '/^!! / { n++ } END { print n + 0 }'; }
[ "$(pign "$WORK/tpl-vii" cache)" = $((P_CAP + 1)) ] || p0="$p0 vii:($(pign "$WORK/tpl-vii" cache) ignored files, want $((P_CAP + 1)))"
[ "$(pign "$WORK/tpl-viic" cache)" = "$P_CAP" ] || p0="$p0 viic:($(pign "$WORK/tpl-viic" cache) ignored files, want $P_CAP)"
[ "$(pign "$WORK/tpl-i" rebal/tests)" = 300 ] || p0="$p0 i:($(pign "$WORK/tpl-i" rebal/tests) ignored files, want 300, over the old 256 default)"
[ "$(g "$WORK/tpl-ix" rev-parse HEAD^)" != "$(g "$WORK/tpl-ix" rev-parse HEAD)" ] \
  && grep -q "^commit: $THEIRS_BREAK" "$WORK/tpl-ix/.claude/.ai-dlc-version" || p0="$p0 ix:(not committed at theirs)"
# Proot's recorded output came from a run at the pre-apply commit: the two tracked files naming the marker, no .git path
_ro="$(awk '/^\$ grep -rl qqalpha \.$/ { on = 1; next } on && /^```/ { exit } on { print }' "$WORK/tpl-root/$SF" | LC_ALL=C sort | tr '\n' ' ')"
[ "$_ro" = "./_bmad-output/story.md ./scripts/ai-dlc/toy.sh " ] || p0="$p0 root:(recorded output [$_ro])"
# the new worlds: the template site ignored and rewritten, the nested repo listed as a DIRECTORY, the symlink ignored,
# nosc's validator without the opt-in, and the long key's old-scheme sidecar name past the 255-byte limit
[ "$(pcode "$WORK/tpl-tplsite" docs/coding-conventions.md)" = '!!' ] && grep -q qqtok "$WORK/tpl-tplsite/docs/coding-conventions.md" \
  || p0="$p0 tplsite:(conventions not ignored, or the pull's token not in it)"
grep -qxF 'docs/coding-conventions.md' <<<"$(awk '/^template_manifest:/{f=1; next} f && /^    consumer: /{print $2; next} f && /^[^ ]/{exit}' "$(dirname "$SUBJ")/template-sites.md" 2>/dev/null)" \
  || p0="$p0 tplsite:(template-sites.md beside the subject does not name docs/coding-conventions.md)"
grep -qx '!! src/__pycache__/sub/' <<<"$(g "$WORK/tpl-nest" status --porcelain --ignored -uall -- src)" || p0="$p0 nest:(sub/ not listed as an ignored directory)"
[ -L "$WORK/tpl-sym/src/__pycache__/l.pyc" ] && [ "$(pcode "$WORK/tpl-sym" src/__pycache__/l.pyc)" = '!!' ] || p0="$p0 sym:(l.pyc not an ignored symlink)"
! grep -q 'then vd_full_out "$f" "$ln"' "$WORK/tpl-nosc/scripts/ai-dlc/validate-artifact-derivations.sh" \
  && grep -q 'vd_full_out() {' "$WORK/tpl-nosc/scripts/ai-dlc/validate-artifact-derivations.sh" || p0="$p0 nosc:(validator still carries the opt-in call sites)"
_ln="$WORK/run-tip-long/$P_KLONG"; _ln="${_ln//[%]/%25}"; _ln="${_ln//\//%2F}"
[ "${#_ln}" -gt 255 ] || p0="$p0 long:(old-scheme sidecar name is ${#_ln} bytes, not over 255)"
if [ -z "$p0" ]; then
  ok "P0 seed: every P world's seeded file carries its porcelain code (!! ignored, ?? untracked, tracked post-commit), Pvii holds cap+1 ignored files, Pviic exactly cap, Pi 300"
else
  bad "P0 seed: a P world is not the shape its arm reads:$p0 -- the P arms are unreadable"
fi
if grep -q 'Binary file' <<<"$(cd "$WORK/tpl-i" && grep -rn -F qqtok rebal/tests 2>/dev/null)"; then
  printf '  info  P seed shape: this grep prints the NUL .pyc as `Binary file P matches` on stdout, so Pi carries the consumer'"'"'s exact line\n'
else
  printf '  info  P seed shape: this grep prints no binary notice on stdout, so Pi'"'"'s difference is its text .pyc alone\n'
fi

# pw <tag> <world> <subject> <tmpdir> -- one run of <subject> over a FRESH copy of world <world>'s template.
# Writes $WORK/o/<tag>/<world>.{out,rc,rec,t0,t1}: the output, the exit, the owed record (or <absent>), and for
# viii the --base-root tree before and after. Pi and Pii run in record mode with apply.sh's record path. viii,
# capabc and capzero drive a copy of Pi's template; vii and viic run with the cap overridden to P_CAP, capabc
# and capzero with the override set to a value the helper must refuse (it falls back to its default).
P_RUNS=""
ptree() { { g "$1" status --porcelain --ignored -uall; find "$1" -path "$1/.git" -prune -o -print | LC_ALL=C sort; } 2>/dev/null; }
# ptpl <world> -> the template that world is copied from
ptpl() { case "$1" in viii|capabc|capzero|nots) echo i ;; *) echo "$1" ;; esac; }
pw() {
  local tag="$1" w="$2" s="$3" td="$4" src d o rec="" brd="" cap=""
  src="$(ptpl "$w")"
  mkdir -p "$WORK/o/$tag"; o="$WORK/o/$tag/$w"
  d="$WORK/run-$tag-$w"; mkdir -p "$d"; cp -R "$WORK/tpl-$src/." "$d/"
  P_RUNS="$P_RUNS $d"
  # cpfail: an ignored file nobody can read, so the overlay's `cp -p` of it fails (made after the template copy,
  # which could not copy it either)
  # Root reads a mode-000 file anyway (a consumer CI in a container runs as root), so the copy would succeed and the
  # arm would read red for no subject reason: when the file is still readable the run records that, and Pcpfail_nf
  # prints a named SKIP line instead of a verdict.
  if [ "$w" = cpfail ]; then
    printf 'qqtok locked\n' > "$d/src/__pycache__/z.pyc"; chmod 000 "$d/src/__pycache__/z.pyc"
    if [ -r "$d/src/__pycache__/z.pyc" ]; then : > "$o.readable"; fi
  fi
  set --
  case "$w" in
    # Record mode classifies each RECORDED row with `check-owed-derivations.sh --scope`, which leaves a
    # check-owed-scope-* directory in TMPDIR (check-owed-derivations.sh:349 pipes into scope_batch, whose mktemp
    # and EXIT trap at :327-329 then live in the pipeline's subshell and never clean up). Only world ii records an
    # OWED row; world i relabels, records nothing and never reaches --scope, so it stays on the shared TMPDIR and
    # A10c still reads its record-mode cleanup. World ii is routed to its own TMPDIR until BL-995
    # (check-owed-derivations.sh:349 --scope leaks a dir) lands; drop this routing in that release.
    i) rec="$d/_bmad-output/ai-dlc-update/owed-derivations.tsv"; set -- --record-owed "$rec" ;;
    ii) rec="$d/_bmad-output/ai-dlc-update/owed-derivations.tsv"; set -- --record-owed "$rec"
        td="$td-rec"; mkdir -p "$td" ;;
    viii) brd="$WORK/run-$tag-viii-root"; g "$WORK" clone -q "$d" "$brd" 2>/dev/null; ptree "$brd" > "$o.t0"; set -- --base-root "$brd" ;;
    vii|viic) cap="$P_CAP" ;;
    capabc) cap=abc ;;
    capzero) cap=0 ;;
  esac
  (cd / || exit 2
   [ -z "$cap" ] || { AI_DLC_DD_OVERLAY_CAP="$cap"; export AI_DLC_DD_OVERLAY_CAP; }
   TMPDIR="$td" bash "$s" "$(cat "$d/.D")" "$(cat "$d/.B")" "$d" "$(cat "$d/.T")" "$@") > "$o.out" 2>&1
  echo "$?" > "$o.rc"
  # what this run left in its TMPDIR, and how many worktrees its consumer lists, read right after it (Pi_two)
  find "$td" -mindepth 1 2>/dev/null | awk 'END { print NR + 0 }' > "$o.tmpleft"
  wtcount "$d" > "$o.wt"
  if [ -n "$rec" ] && [ -f "$rec" ]; then cat "$rec" > "$o.rec"; else echo '<absent>' > "$o.rec"; fi
  [ -z "$brd" ] || ptree "$brd" > "$o.t1"
}
# rowst <outfile> <key> -> the status of the classified row for <key>, empty when it has none
rowst() { awk -F'\t' -v k="$2" '$2 == k && ($1 == "NEWLY-FAILING" || $1 == "STALE-BOTH" || $1 == "NEWLY-PASSING" || $1 == "UNASSESSABLE") { print $1; exit }' "$1"; }
# relnote <outfile> <key> -> 0 when a relabel NOTE row for <key> is present
relnote() { awk -F'\t' -v k="$2" '$1 == "NOTE" && $2 == k && index($3, "STALE-BOTH, not NEWLY-FAILING") { f = 1 } END { exit !f }' "$1"; }
prc() { cat "$WORK/o/$1/$2.rc" 2>/dev/null; }
# p_nf <tag> <world> <key>: exit 1, the key NEWLY-FAILING, no relabel NOTE for it, and a verdict was reached
p_nf() { local o="$WORK/o/$1/$2.out"
  [ "$(prc "$1" "$2")" = 1 ] && [ "$(rowst "$o" "$3")" = NEWLY-FAILING ] && ! relnote "$o" "$3" && grep -q '^VERDICT' "$o"; }
# p_ctl <tag> <world>: that world's holding fence has no row, and a verdict (not a refusal) was printed
p_ctl() { local o="$WORK/o/$1/$2.out" k
  k="$(pkey "$(ptpl "$2")" 'grep -c qqgamma')"
  case "$k" in *:) return 1 ;; esac
  [ -z "$(rowst "$o" "$k")" ] && grep -q '^VERDICT' "$o" && ! grep -q '^REFUSED' "$o"; }
# p_sb <tag> <world> <key> [<copied path>]: the key STALE-BOTH with base=STALE, and the NOTE naming the copied file
# (the NOTE lists at most the first 5 copied paths in byte order, so Pi's 300 files show f001..f005)
p_sb() { local o="$WORK/o/$1/$2.out" p="${4:-rebal/tests/__pycache__/f001.cpython-311.pyc}"
  [ "$(rowst "$o" "$3")" = STALE-BOTH ] \
    && grep -qF "$(printf 'STALE-BOTH\t%s\tbase=STALE consumer=STALE' "$3")" "$o" \
    && awk -F'\t' -v k="$3" -v p="$p" '$1 == "NOTE" && $2 == k && index($3, "STALE-BOTH, not NEWLY-FAILING") && index($3, p) { f = 1 } END { exit !f }' "$o"; }
# p_sbonly <tag> <world> <key> [<copied path>]: p_sb, the exit 0, no NEWLY-FAILING row and no overlay-skip row at all
p_sbonly() { local o="$WORK/o/$1/$2.out"
  [ "$(prc "$1" "$2")" = 0 ] && p_sb "$@" && [ "$(nrows NEWLY-FAILING "$(cat "$o")")" = 0 ] && ! grep -q 'overlay skipped' "$o"; }
# p_owed <tag> <world> <key> <want: 1|0>: the record exists, and an OWED row for <key> is in it (1) or not (0)
p_owed() { local r="$WORK/o/$1/$2.rec" n
  [ "$(head -1 "$r" 2>/dev/null)" != '<absent>' ] || return 1
  n="$(awk -F'\t' -v k="$3" '$1 == "OWED" && $2 == k { n++ } END { print n + 0 }' "$r")"
  if [ "$4" = 1 ]; then [ "$n" -ge 1 ]; else [ "$n" = 0 ]; fi; }
# p_note <tag> <world> <key> <text>: a NOTE row keyed on <key> whose text is EXACTLY <text>
p_note() { awk -F'\t' -v k="$3" -v s="$4" '$1 == "NOTE" && $2 == k && $3 == s { f = 1 } END { exit !f }' "$WORK/o/$1/$2.out"; }
# The helper's skip rows, byte for byte (derivation-differential.sh, dd_overlay_pass and the --base-root branch).
P_SKIP_CAP_FMT="overlay skipped: @N@ ignored file(s) under this fence's operands exceed the overlay cap @C@ (AI_DLC_DD_OVERLAY_CAP); the row keeps NEWLY-FAILING."
P_SKIP_BR="overlay skipped: --base-root names the operator's tree, which this script never writes, so no consumer ignored file was copied into it; the row keeps NEWLY-FAILING."
P_SKIP_ROOT="overlay skipped: this fence names the project root or a path above it ('.') as an operand, so its ignored files cannot be bounded to a directory; the row keeps NEWLY-FAILING."
# p_nonote <tag> <world> <key>: NO NOTE row is keyed on <key> -- a fence with no ignored file under its operands is a
# plain finding, and the overlay pass prints nothing for it
p_nonote() { awk -F'\t' -v k="$3" '$1 == "NOTE" && $2 == k { f = 1 } END { exit f }' "$WORK/o/$1/$2.out"; }
P_SKIP_DIFF="overlay skipped: with 1 ignored file(s) copied into the base root (src/__pycache__/a.cpython-311.pyc) the base and consumer full outputs still differ, so something besides those ignored files moved this derivation; the row keeps NEWLY-FAILING."
P_SKIP_NOSC="overlay skipped: the re-run with 1 ignored file(s) copied in (src/__pycache__/a.cpython-311.pyc) left no full output for this derivation on the base side and the consumer side (a validator without the AI_DLC_VD_FULL_OUT_DIR opt-in, or one that did not reach the comparison), so the two outputs cannot be compared; the row keeps NEWLY-FAILING."
P_SKIP_SYM="overlay skipped: the ignored path 'src/__pycache__/l.pyc' is a symbolic link, and copying it would copy whatever it points at, possibly from outside the tree; the row keeps NEWLY-FAILING."
P_SKIP_DIR="overlay skipped: \`git status --ignored\` listed 'src/__pycache__/sub/', a directory or a path outside the tree rather than one file, so the overlay cannot be expanded to files; the row keeps NEWLY-FAILING."
P_SKIP_NOTS="overlay skipped: reconcile/template-sites.md beside this script could not be read or names no template site, so the files this pull rewrites outside its install roots are unknown; the row keeps NEWLY-FAILING."
P_SKIP_NOOP="overlay skipped: no word of this fence's command names an existing path under the consumer root, so there is no operand to look for ignored files under; the row keeps NEWLY-FAILING."
P_SKIP_CP="overlay skipped: copying 'src/__pycache__/z.pyc' into the base worktree failed; the row keeps NEWLY-FAILING."
# p_bounded <tag> <world> <key>: the relabel NOTE carries Pi's count (300), EXACTLY the first five paths in byte order,
# `… and 295 more`, and the whole row is under 1000 bytes (the full list of 300 is about 13000)
P_BOUND_LIST="the consumer's 300 pre-existing IGNORED file(s) copied into the base root (rebal/tests/__pycache__/f001.cpython-311.pyc rebal/tests/__pycache__/f002.cpython-311.pyc rebal/tests/__pycache__/f003.cpython-311.pyc rebal/tests/__pycache__/f004.cpython-311.pyc rebal/tests/__pycache__/f005.cpython-311.pyc … and 295 more), and"
p_bounded() { local r
  r="$(awk -F'\t' -v k="$3" '$1 == "NOTE" && $2 == k && index($3, "STALE-BOTH, not NEWLY-FAILING") { print; exit }' "$WORK/o/$1/$2.out")"
  [ -n "$r" ] && grep -qF -- "$P_BOUND_LIST" <<<"$r" && [ "$(printf '%s' "$r" | wc -c | tr -d ' ')" -lt 1000 ]; }
p_skipcap() { local s="$P_SKIP_CAP_FMT"; s="${s/@N@/$4}"; s="${s/@C@/$5}"; p_note "$1" "$2" "$3" "$s"; }
# pcell <label> <tag> -> 0 when that arm holds on that tag's output
pcell() {
  case "$1" in
    Pi_row)    p_sbonly "$2" i "$P_KI" \
                 && grep -qF "$(printf 'VERDICT\t_bmad-output/\tzero NEWLY-FAILING')" "$WORK/o/$2/i.out" ;;
    Pi_bound)  p_bounded "$2" i "$P_KI" ;;
    Pi_two)    p_sb "$2" i "$P_KI2" && p_bounded "$2" i "$P_KI2" && p_bounded "$2" i "$P_KI" \
                 && [ "$(nrows STALE-BOTH "$(awk -F'\t' -v a="$P_KI" -v b="$P_KI2" '$2 == a || $2 == b' "$WORK/o/$2/i.out")")" = 2 ] \
                 && [ "$(cat "$WORK/o/$2/i.tmpleft" 2>/dev/null)" = 0 ] && [ "$(cat "$WORK/o/$2/i.wt" 2>/dev/null)" = 1 ] ;;
    Pi_owed)   p_owed "$2" i "$P_KI" 0 ;;
    Pi_ctl)    p_ctl "$2" i ;;
    Pii_nf)    p_nf "$2" ii "$P_KII" && p_owed "$2" ii "$P_KII" 1 && p_nonote "$2" ii "$P_KII" ;;
    Pii_sb)    p_sb "$2" ii "$P_KIIS" && p_owed "$2" ii "$P_KIIS" 0 ;;
    Piii_nf)   p_nf "$2" iii "$P_KIII" && p_note "$2" iii "$P_KIII" "$P_SKIP_DIFF" ;;
    Piii_ctl)  p_ctl "$2" iii ;;
    Piiip_nf)  p_nf "$2" iiip "$P_KIII" && p_note "$2" iiip "$P_KIII" "$P_SKIP_DIFF" ;;
    Piiip_ctl) p_ctl "$2" iiip ;;
    Piv_hb)    p_nf "$2" iv "$P_KIV" && p_ctl "$2" iv && p_nonote "$2" iv "$P_KIV" ;;
    Piv_pc)    p_nf "$2" ivpc "$P_KIV" && p_ctl "$2" ivpc && p_nonote "$2" ivpc "$P_KIV" ;;
    Pv_nf)     p_nf "$2" v "$P_KV" && p_nonote "$2" v "$P_KV" ;;
    Pv_ctl)    p_ctl "$2" v ;;
    Pvi_nf)    p_nf "$2" vi "$P_KVI" && p_nonote "$2" vi "$P_KVI" ;;
    Pvi_ctl)   p_ctl "$2" vi ;;
    Pvii_nf)   p_nf "$2" vii "$P_KVII" && p_skipcap "$2" vii "$P_KVII" "$((P_CAP + 1))" "$P_CAP" ;;
    Pvii_ctl)  p_ctl "$2" vii ;;
    Pviic_sb)  p_sbonly "$2" viic "$P_KVII" cache/m000.pyc ;;
    Pviic_ctl) p_ctl "$2" viic ;;
    Pviii_nf)  p_nf "$2" viii "$P_KI" && grep -qF "base root (--base-root $WORK/run-$2-viii-root)" "$WORK/o/$2/viii.out" \
                 && p_note "$2" viii "$P_KI" "$P_SKIP_BR" ;;
    Pviii_tree) [ -s "$WORK/o/$2/viii.t0" ] && cmp -s "$WORK/o/$2/viii.t0" "$WORK/o/$2/viii.t1" ;;
    Pix_nf)    p_nf "$2" ix "$P_KII" && p_nonote "$2" ix "$P_KII" ;;
    Pix_sb)    p_sb "$2" ix "$P_KIIS" ;;
    Proot_nf)  p_nf "$2" root "$P_KROOT" && p_note "$2" root "$P_KROOT" "$P_SKIP_ROOT" ;;
    Ptpl_nf)   p_nf "$2" tplsite "$P_KTPL" && p_nonote "$2" tplsite "$P_KTPL" ;;
    Ptpl_ctl)  p_ctl "$2" tplsite ;;
    Pnots_nf)  p_nf "$2" nots "$P_KI" && p_note "$2" nots "$P_KI" "$P_SKIP_NOTS" ;;
    Pnoop_nf)  p_nf "$2" noop "$P_KNOOP" && p_note "$2" noop "$P_KNOOP" "$P_SKIP_NOOP" ;;
    Plong_sb)  p_sbonly "$2" long "$P_KLONG" src/__pycache__/a.cpython-311.pyc ;;
    Pnosc_nf)  p_nf "$2" nosc "$P_KSRC" && p_note "$2" nosc "$P_KSRC" "$P_SKIP_NOSC" ;;
    Psym_nf)   p_nf "$2" sym "$P_KSRC" && p_note "$2" sym "$P_KSRC" "$P_SKIP_SYM" ;;
    Pnest_nf)  p_nf "$2" nest "$P_KSRC" && p_note "$2" nest "$P_KSRC" "$P_SKIP_DIR" ;;
    Pcpfail_nf) p_nf "$2" cpfail "$P_KSRC" && p_note "$2" cpfail "$P_KSRC" "$P_SKIP_CP" ;;
    # a non-numeric cap that reached `[ -gt ]` errors there and still relabels, so the error line is the observable
    Pcapabc_sb) p_sbonly "$2" capabc "$P_KI" && ! grep -q 'integer expression expected' "$WORK/o/$2/capabc.out" ;;
    Pcapabc_ctl) p_ctl "$2" capabc ;;
    Pcapzero_sb) p_sbonly "$2" capzero "$P_KI" ;;
    Pcapzero_ctl) p_ctl "$2" capzero ;;
    Px_unset)  [ -f "$WORK/o/$2/x.unset" ] && [ "$(cat "$WORK/o/$2/x.unset")" = ok ] ;;
    Px_set)    [ -f "$WORK/o/$2/x.set" ] && [ "$(cat "$WORK/o/$2/x.set")" = ok ] ;;
    *) return 2 ;;
  esac
}
P_CELLS="Pi_row Pi_owed Pi_ctl Pi_bound Pi_two Pii_nf Pii_sb Piii_nf Piii_ctl Piiip_nf Piiip_ctl Piv_hb Piv_pc Pv_nf Pv_ctl Pvi_nf Pvi_ctl Pvii_nf Pvii_ctl Pviic_sb Pviic_ctl Pviii_nf Pviii_tree Pix_nf Pix_sb Proot_nf Ptpl_nf Ptpl_ctl Pnots_nf Pnoop_nf Plong_sb Pnosc_nf Psym_nf Pnest_nf Pcpfail_nf Pcapabc_sb Pcapabc_ctl Pcapzero_sb Pcapzero_ctl Px_unset Px_set"
P_RUNWORLDS="i ii iii iiip iv ivpc v vi vii viic viii ix root tplsite long nosc sym nest cpfail noop capabc capzero"
# pworld <label> -> the world that label reads
pworld() { case "$1" in Pi_*) echo i ;; Pii_*) echo ii ;; Piii_*) echo iii ;; Piiip_*) echo iiip ;; Piv_hb) echo iv ;; Piv_pc) echo ivpc ;;
  Pv_*) echo v ;; Pvi_*) echo vi ;; Pvii_*) echo vii ;; Pviic_*) echo viic ;; Pviii_*) echo viii ;; Pix_*) echo ix ;;
  Proot_*) echo root ;; Ptpl_*) echo tplsite ;; Pnots_*) echo nots ;; Pnoop_*) echo noop ;; Plong_*) echo long ;; Pnosc_*) echo nosc ;; Psym_*) echo sym ;;
  Pnest_*) echo nest ;; Pcpfail_*) echo cpfail ;; Pcapabc_*) echo capabc ;; Pcapzero_*) echo capzero ;; Px_*) echo x ;; esac; }

# px <tag> <validator copy> -- arm Px over a fresh copy of world x, with <validator copy> installed at the
# consumer's own path (so no path string differs between the runs). Writes x.unset and x.set as ok|<why>.
# Base-shaped: the same copy with its two opt-in call sites removed. Unset: stdout, stderr and exit
# byte-identical to it, no file added under the tree and nothing left in TMPDIR. Set: the same output, and
# exactly one file per COMPARED derivation -- the hit, the no-output one (an EMPTY file), the stale one --
# and none for the refused one.
px() {
  local tag="$1" v="$2" d o vp fo n why
  d="$WORK/run-$tag-x"; o="$WORK/o/$tag"
  mkdir -p "$o" "$d" "$o/xtmp-s" "$o/xtmp-u" "$o/xtmp-f" "$o/fo"; cp -R "$WORK/tpl-x/." "$d/"
  vp="$d/scripts/ai-dlc/validate-artifact-derivations.sh"
  if ! pmut "$VALIDATOR" "$o/x-stripped.sh" \
       'if [ -n "${AI_DLC_VD_FULL_OUT_DIR:-}" ]; then vd_full_out "$f" "$ln" empty; fi' ':' \
       'if [ -n "${AI_DLC_VD_FULL_OUT_DIR:-}" ]; then vd_full_out "$f" "$ln"; fi' ':'; then
    echo "the opt-in call sites were not found in the validator" > "$o/x.unset"; echo "no base-shaped copy" > "$o/x.set"; return
  fi
  cp "$o/x-stripped.sh" "$vp"
  (cd "$d" && TMPDIR="$o/xtmp-s" AI_DLC_PROJECT_ROOT="$d" bash "$vp" "$SF" > "$o/x-s.out" 2> "$o/x-s.err"; echo "$?" > "$o/x-s.rc")
  cp "$v" "$vp"
  ptree "$d" > "$o/x-tree0"
  (cd "$d" && TMPDIR="$o/xtmp-u" AI_DLC_PROJECT_ROOT="$d" bash "$vp" "$SF" > "$o/x-u.out" 2> "$o/x-u.err"; echo "$?" > "$o/x-u.rc")
  ptree "$d" > "$o/x-tree1"
  (cd "$d" && TMPDIR="$o/xtmp-f" AI_DLC_PROJECT_ROOT="$d" AI_DLC_VD_FULL_OUT_DIR="$o/fo" bash "$vp" "$SF" > "$o/x-f.out" 2> "$o/x-f.err"; echo "$?" > "$o/x-f.rc")
  why=""
  [ "$(cat "$o/x-s.rc")" = 1 ] && grep -qF "story.md:${PX_STALE_KEY##*:}" <<<"$(cat "$o/x-s.out" "$o/x-s.err")" \
    || why="$why the base-shaped run did not report the stale fence (rc $(cat "$o/x-s.rc"));"
  cmp -s "$o/x-s.out" "$o/x-u.out" && cmp -s "$o/x-s.err" "$o/x-u.err" && cmp -s "$o/x-s.rc" "$o/x-u.rc" || why="$why unset output differs from the base-shaped copy;"
  cmp -s "$o/x-tree0" "$o/x-tree1" || why="$why the unset run added a file under the tree;"
  n="$(find "$o/xtmp-u" -mindepth 1 2>/dev/null | awk 'END { print NR + 0 }')"; [ "$n" = 0 ] || why="$why the unset run left $n path(s) in TMPDIR;"
  echo "${why:-ok}" > "$o/x.unset"
  why=""
  cmp -s "$o/x-u.out" "$o/x-f.out" && cmp -s "$o/x-u.err" "$o/x-f.err" && cmp -s "$o/x-u.rc" "$o/x-f.rc" || why="$why set output differs from unset;"
  # the opt-in names each output by ordinal (<n>.out) and maps it to its key in `index` (<n><TAB><file>:<line>)
  fo="$(cd "$o/fo" && find . -mindepth 1 -print 2>/dev/null | LC_ALL=C sort | tr '\n' ' ')"
  [ "$fo" = "./1.out ./2.out ./3.out ./index " ] || why="$why files [$fo], want [./1.out ./2.out ./3.out ./index ];"
  [ "$(awk 'END { print NR + 0 }' "$o/fo/index" 2>/dev/null)" = 3 ] || why="$why the index does not hold three lines;"
  n="$(pxout "$o/fo" "$PX_EMPTY")"; [ -n "$n" ] && [ -f "$o/fo/$n" ] && [ ! -s "$o/fo/$n" ] || why="$why the no-output derivation has no EMPTY file;"
  n="$(pxout "$o/fo" "$PX_HIT")"; grep -qx 1 "$o/fo/$n" 2>/dev/null || why="$why the hit file does not hold its output;"
  n="$(pxout "$o/fo" "$PX_STALE")"; grep -qx 0 "$o/fo/$n" 2>/dev/null || why="$why the stale file does not hold its output;"
  [ -z "$(pxout "$o/fo" "$PX_REFUSED")" ] || why="$why the refused derivation has an index line;"
  echo "${why:-ok}" > "$o/x.set"
}
# pxout <full-output dir> <file:line> -> the ordinal file the index names for that key, empty when none
pxout() { awk -F'\t' -v k="$2" '$2 == k { print $1 ".out"; exit }' "$1/index" 2>/dev/null; }
# pmut <src> <dst> <anchor> <replacement> [<anchor> <replacement>...] -- a COPY with each literal anchor replaced
# on exactly ONE line (awk index, the strings through ENVIRON, so no sed metacharacter reaches them); returns 1 when
# an anchor matched no line or more than one, or when the copy is byte-identical to its source.
pmut() {
  local src="$1" dst="$2" n=0
  shift 2
  while [ "$#" -ge 2 ]; do n=$((n + 1)); export "PMA$n=$1" "PMR$n=$2"; shift 2; done
  awk -v np="$n" '{ line = $0
      for (i = 1; i <= np; i++) { a = ENVIRON["PMA" i]; p = index(line, a)
        if (p > 0) { hit[i]++; line = substr(line, 1, p - 1) ENVIRON["PMR" i] substr(line, p + length(a)) } }
      print line }
    END { for (i = 1; i <= np; i++) if (hit[i] != 1) bad = 1; exit bad }' "$src" > "$dst"
  local r=$?
  while [ "$n" -gt 0 ]; do unset "PMA$n" "PMR$n"; n=$((n - 1)); done
  [ "$r" -eq 0 ] && ! cmp -s "$src" "$dst"
}
PX_HIT="$(pkey x 'grep -c qqgamma')"; PX_EMPTY="$(pkey x 'grep qqnothing')"; PX_STALE="$(pkey x 'grep -c qqbeta')"
PX_STALE_KEY="$PX_STALE"; PX_REFUSED="$(pkey x 'perl -ne print')"

# the comparator Pviii_tree reads must SEE a difference: a seeded file in a scratch clone changes its snapshot
PTC="$WORK/ptree-control"; g "$WORK" clone -q "$WORK/tpl-i" "$PTC" 2>/dev/null
ptree "$PTC" > "$WORK/ptc.0"; : > "$PTC/rebal/tests/seeded.pyc"; ptree "$PTC" > "$WORK/ptc.1"
if [ -s "$WORK/ptc.0" ] && ! cmp -s "$WORK/ptc.0" "$WORK/ptc.1"; then
  ok "P0 control: the tree snapshot Pviii_tree compares changes when one ignored file is added"
else
  bad "P0 control: the tree snapshot did not change when a file was added -- Pviii_tree is unreadable"
fi

# THE ARMS, against the shipped subject and validator: one run per world.
for _w in $P_RUNWORLDS; do pw tip "$_w" "$SUBJ" "$DDTMP"; done
# nots: Pi's world driven by a copy of the helper whose directory holds its siblings but NO template-sites.md, so
# the set of files the pull rewrites is unknown and the pass must fail closed (one named row per NEWLY-FAILING key)
P_NOTS="$WORK/nots"; mkdir -p "$P_NOTS"
for _f in derivation-differential.sh apply.sh preclassify.sh consumer-read.sh; do cp "$(dirname "$SUBJ")/$_f" "$P_NOTS/$_f"; done
[ ! -e "$P_NOTS/template-sites.md" ] || { echo "FIXTURE ERROR: the nots copy carries template-sites.md" >&2; exit 2; }
pw tip nots "$P_NOTS/derivation-differential.sh" "$DDTMP"
px tip "$VALIDATOR"
# Each arm's verdict on the shipped run. B_<arm>=1 is set in the passing branch only: it is the base-pass flag the
# mutant scoring below hands to mutant_killed. pbad <label> <message> reports a red arm with what that world printed.
pbad() {
  local w
  bad "$1 $2"; w="$(pworld "$1")"
  case "$w" in
    x) printf '        | unset: %s\n        | set: %s\n' "$(cat "$WORK/o/tip/x.unset")" "$(cat "$WORK/o/tip/x.set")" ;;
    *) printf '        | rc=%s\n' "$(prc tip "$w")"; grep -E '^(NEWLY-FAILING|STALE-BOTH|NOTE|VERDICT|REFUSED)' "$WORK/o/tip/$w.out" | cut -c1-300 | sed 's/^/        | /' | head -12 ;;
  esac
}
B_Pi_row=0; B_Pi_bound=0; B_Pi_two=0; B_Pi_owed=0; B_Pi_ctl=0; B_Piii_nf=0; B_Piii_ctl=0; B_Piiip_nf=0; B_Piiip_ctl=0; B_Pv_nf=0; B_Pv_ctl=0
B_Pvi_nf=0; B_Pvi_ctl=0; B_Pvii_nf=0; B_Pvii_ctl=0; B_Pviic_sb=0; B_Pviic_ctl=0; B_Pviii_nf=0; B_Pviii_tree=0
B_Pcapzero_sb=0; B_Pcapzero_ctl=0; B_Px_unset=0; B_Px_set=0; B_Pcapabc_sb=0; B_Pcapabc_ctl=0; B_Ptpl_nf=0; B_Ptpl_ctl=0; B_Pii_nf=0; B_Pii_sb=0
if pcell Pi_row tip; then ok "Pi_row the consumer's shape (300 ignored files in a tests __pycache__, under the default cap; recorded output over 160 columns) -> exit 0, STALE-BOTH base=STALE, a NOTE naming the copied file, no skip row"; B_Pi_row=1
else pbad Pi_row "the consumer's shape (300 ignored files in a tests __pycache__, under the default cap; recorded output over 160 columns) -> exit 0, STALE-BOTH base=STALE, a NOTE naming the copied file, no skip row"; fi
if pcell Pi_owed tip; then ok "Pi_owed and under --record-owed the record is written and holds no OWED row for it"; B_Pi_owed=1
else pbad Pi_owed "and under --record-owed the record is written and holds no OWED row for it"; fi
if pcell Pi_ctl tip; then ok "Pi_ctl and the holding fence beside it gets no row"; B_Pi_ctl=1
else pbad Pi_ctl "and the holding fence beside it gets no row"; fi
if pcell Pi_bound tip; then ok "Pi_bound and its relabel NOTE is BOUNDED: 300 files, exactly the first five paths, '… and 295 more', under 1000 bytes"; B_Pi_bound=1
else pbad Pi_bound "and its relabel NOTE is BOUNDED: 300 files, exactly the first five paths, '… and 295 more', under 1000 bytes"; fi
if pcell Pi_two tip; then ok "Pi_two a second artifact with the same fence over the same cache: both keys STALE-BOTH, each with its own bounded NOTE, no worktree left and TMPDIR empty after the run"; B_Pi_two=1
else pbad Pi_two "a second artifact with the same fence over the same cache: both keys STALE-BOTH, each with its own bounded NOTE, no worktree left and TMPDIR empty after the run"; fi
if pcell Pii_nf tip; then ok "Pii_nf a real line shift beside it -> exit 1, NEWLY-FAILING, and recorded OWED"; B_Pii_nf=1
else pbad Pii_nf "a real line shift beside it -> exit 1, NEWLY-FAILING, and recorded OWED"; fi
if pcell Pii_sb tip; then ok "Pii_sb and in that same run the ignored-file fence is STALE-BOTH with its NOTE and no OWED row"; B_Pii_sb=1
else pbad Pii_sb "and in that same run the ignored-file fence is STALE-BOTH with its NOTE and no OWED row"; fi
if pcell Piii_nf tip; then ok "Piii_nf a pre-existing ignored file AND a pull-made line in one fence -> exit 1, NEWLY-FAILING"; B_Piii_nf=1
else pbad Piii_nf "a pre-existing ignored file AND a pull-made line in one fence -> exit 1, NEWLY-FAILING"; fi
if pcell Piii_ctl tip; then ok "Piii_ctl and the holding fence beside it gets no row"; B_Piii_ctl=1
else pbad Piii_ctl "and the holding fence beside it gets no row"; fi
if pcell Piiip_nf tip; then ok "Piiip_nf the same, the pull-made line past column 160 of the joined output -> exit 1, NEWLY-FAILING"; B_Piiip_nf=1
else pbad Piiip_nf "the same, the pull-made line past column 160 of the joined output -> exit 1, NEWLY-FAILING"; fi
if pcell Piiip_ctl tip; then ok "Piiip_ctl and the holding fence beside it gets no row"; B_Piiip_ctl=1
else pbad Piiip_ctl "and the holding fence beside it gets no row"; fi
if pcell Piv_hb tip; then ok "Piv_hb a file the RANGE ADDS, untracked at hand-back -> exit 1, NEWLY-FAILING"; B_Piv_hb=1
else pbad Piv_hb "a file the RANGE ADDS, untracked at hand-back -> exit 1, NEWLY-FAILING"; fi
if pcell Piv_pc tip; then ok "Piv_pc and tracked after the step-8 commit (base root HEAD^) -> exit 1, NEWLY-FAILING"; B_Piv_pc=1
else pbad Piv_pc "and tracked after the step-8 commit (base root HEAD^) -> exit 1, NEWLY-FAILING"; fi
if pcell Pv_nf tip; then ok "Pv_nf an ignored file under an install root (.claude/) -> exit 1, NEWLY-FAILING"; B_Pv_nf=1
else pbad Pv_nf "an ignored file under an install root (.claude/) -> exit 1, NEWLY-FAILING"; fi
if pcell Pv_ctl tip; then ok "Pv_ctl and the holding fence beside it gets no row"; B_Pv_ctl=1
else pbad Pv_ctl "and the holding fence beside it gets no row"; fi
if pcell Pvi_nf tip; then ok "Pvi_nf an untracked-NOT-ignored pre-existing file -> exit 1, NEWLY-FAILING (it cannot be told from an apply addition)"; B_Pvi_nf=1
else pbad Pvi_nf "an untracked-NOT-ignored pre-existing file -> exit 1, NEWLY-FAILING (it cannot be told from an apply addition)"; fi
if pcell Pvi_ctl tip; then ok "Pvi_ctl and the holding fence beside it gets no row"; B_Pvi_ctl=1
else pbad Pvi_ctl "and the holding fence beside it gets no row"; fi
if pcell Pvii_nf tip; then ok "Pvii_nf cap+1 ignored files under the operand (the cap overridden to $P_CAP) -> exit 1, NEWLY-FAILING, and the skip row names the count and the cap"; B_Pvii_nf=1
else pbad Pvii_nf "cap+1 ignored files under the operand (the cap overridden to $P_CAP) -> exit 1, NEWLY-FAILING, and the skip row names the count and the cap"; fi
if pcell Pvii_ctl tip; then ok "Pvii_ctl and the holding fence beside it gets no row"; B_Pvii_ctl=1
else pbad Pvii_ctl "and the holding fence beside it gets no row"; fi
if pcell Pviic_sb tip; then ok "Pviic_sb exactly cap ignored files -> exit 0, relabelled STALE-BOTH with its NOTE, and no skip row"; B_Pviic_sb=1
else pbad Pviic_sb "exactly cap ignored files -> exit 0, relabelled STALE-BOTH with its NOTE, and no skip row"; fi
if pcell Pviic_ctl tip; then ok "Pviic_ctl and the holding fence beside it gets no row"; B_Pviic_ctl=1
else pbad Pviic_ctl "and the holding fence beside it gets no row"; fi
if pcell Pviii_nf tip; then ok "Pviii_nf the consumer's shape under --base-root -> exit 1, NEWLY-FAILING, from that root, with the --base-root skip row"; B_Pviii_nf=1
else pbad Pviii_nf "the consumer's shape under --base-root -> exit 1, NEWLY-FAILING, from that root, with the --base-root skip row"; fi
if pcell Pviii_tree tip; then ok "Pviii_tree and the --base-root tree is unchanged by the run"; B_Pviii_tree=1
else pbad Pviii_tree "and the --base-root tree is unchanged by the run"; fi
if pcell Pix_nf tip; then ok "Pix_nf post-commit (base root HEAD^): the real line shift -> exit 1, NEWLY-FAILING"; B_Pix_nf=1
else pbad Pix_nf "post-commit (base root HEAD^): the real line shift -> exit 1, NEWLY-FAILING"; fi
if pcell Pix_sb tip; then ok "Pix_sb and the ignored-file fence is STALE-BOTH with its NOTE"; B_Pix_sb=1
else pbad Pix_sb "and the ignored-file fence is STALE-BOTH with its NOTE"; fi
if pcell Proot_nf tip; then ok "Proot_nf a fence naming the project root ('.') as an operand -> exit 1, NEWLY-FAILING, with the root-operand skip row"; B_Proot_nf=1
else pbad Proot_nf "a fence naming the project root ('.') as an operand -> exit 1, NEWLY-FAILING, with the root-operand skip row"; fi
if pcell Ptpl_nf tip; then ok "Ptpl_nf an ignored TEMPLATE SITE (docs/coding-conventions.md) the pull rewrites with the token -> exit 1, NEWLY-FAILING, with the no-ignored-file skip row"; B_Ptpl_nf=1
else pbad Ptpl_nf "an ignored TEMPLATE SITE (docs/coding-conventions.md) the pull rewrites with the token -> exit 1, NEWLY-FAILING, with the no-ignored-file skip row"; fi
if pcell Ptpl_ctl tip; then ok "Ptpl_ctl and the holding fence beside it gets no row"; B_Ptpl_ctl=1
else pbad Ptpl_ctl "and the holding fence beside it gets no row"; fi
if pcell Pnots_nf tip; then ok "Pnots_nf no template-sites.md beside the helper -> the pass fails closed: Pi's key stays NEWLY-FAILING, exit 1, with the manifest-unreadable row"
else pbad Pnots_nf "no template-sites.md beside the helper -> the pass fails closed: Pi's key stays NEWLY-FAILING, exit 1, with the manifest-unreadable row"; fi
if pcell Pnoop_nf tip; then ok "Pnoop_nf a fence whose only path word is a glob (no operand) -> exit 1, NEWLY-FAILING, with the no-operand skip row"
else pbad Pnoop_nf "a fence whose only path word is a glob (no operand) -> exit 1, NEWLY-FAILING, with the no-operand skip row"; fi
if pcell Plong_sb tip; then ok "Plong_sb an artifact under a 200-character directory (the old sidecar name past 255 bytes) -> relabelled STALE-BOTH, exit 0"
else pbad Plong_sb "an artifact under a 200-character directory (the old sidecar name past 255 bytes) -> relabelled STALE-BOTH, exit 0"; fi
if pcell Pnosc_nf tip; then ok "Pnosc_nf a consumer validator without the full-output opt-in -> exit 1, NEWLY-FAILING, with the no-full-output skip row"
else pbad Pnosc_nf "a consumer validator without the full-output opt-in -> exit 1, NEWLY-FAILING, with the no-full-output skip row"; fi
if pcell Psym_nf tip; then ok "Psym_nf an ignored SYMLINK under the operand -> exit 1, NEWLY-FAILING, with the symlink skip row"
else pbad Psym_nf "an ignored SYMLINK under the operand -> exit 1, NEWLY-FAILING, with the symlink skip row"; fi
if pcell Pnest_nf tip; then ok "Pnest_nf an ignored nested repository (listed as a directory) -> exit 1, NEWLY-FAILING, with the directory-entry skip row"
else pbad Pnest_nf "an ignored nested repository (listed as a directory) -> exit 1, NEWLY-FAILING, with the directory-entry skip row"; fi
if [ -f "$WORK/o/tip/cpfail.readable" ]; then
  printf '  SKIP  Pcpfail_nf a mode-000 file is still readable here (running as root?), so no copy of it can fail; Pcpfail_nf was not scored\n'
elif pcell Pcpfail_nf tip; then ok "Pcpfail_nf an unreadable ignored file -> exit 1, NEWLY-FAILING, with the failed-copy skip row"
else pbad Pcpfail_nf "an unreadable ignored file -> exit 1, NEWLY-FAILING, with the failed-copy skip row"; fi
if pcell Pcapabc_sb tip; then ok "Pcapabc_sb AI_DLC_DD_OVERLAY_CAP=abc is refused and the default holds: Pi's 300 files still relabel, exit 0"; B_Pcapabc_sb=1
else pbad Pcapabc_sb "AI_DLC_DD_OVERLAY_CAP=abc is refused and the default holds: Pi's 300 files still relabel, exit 0"; fi
if pcell Pcapabc_ctl tip; then ok "Pcapabc_ctl and the holding fence beside it gets no row"; B_Pcapabc_ctl=1
else pbad Pcapabc_ctl "and the holding fence beside it gets no row"; fi
if pcell Pcapzero_sb tip; then ok "Pcapzero_sb AI_DLC_DD_OVERLAY_CAP=0 is refused and the default holds: Pi's 300 files still relabel, exit 0"; B_Pcapzero_sb=1
else pbad Pcapzero_sb "AI_DLC_DD_OVERLAY_CAP=0 is refused and the default holds: Pi's 300 files still relabel, exit 0"; fi
if pcell Pcapzero_ctl tip; then ok "Pcapzero_ctl and the holding fence beside it gets no row"; B_Pcapzero_ctl=1
else pbad Pcapzero_ctl "and the holding fence beside it gets no row"; fi
if pcell Px_unset tip; then ok "Px_unset the validator with AI_DLC_VD_FULL_OUT_DIR unset is byte-identical to the opt-in stripped out, and writes no file"; B_Px_unset=1
else pbad Px_unset "the validator with AI_DLC_VD_FULL_OUT_DIR unset is byte-identical to the opt-in stripped out, and writes no file"; fi
if pcell Px_set tip; then ok "Px_set with it set: the same output, and one file per compared derivation (an empty one for no output, none for a refusal)"; B_Px_set=1
else pbad Px_set "with it set: the same output, and one file per compared derivation (an empty one for no output, none for a refusal)"; fi

# ---- P MUTANTS: copies of the helper (with its declared siblings beside it) or of the validator ------------
# Each is a pmut copy (exactly one line per anchor, cmp -s against the source). PER PUSH it runs ONLY the world its
# deciding arm reads: the deciding arm must go red BY THE WRONG VERDICT (the key relabelled STALE-BOTH with exit 0,
# the OWED row present, a file written), and the twin, an arm of that same run, must stay green. A copy that never
# ran (no VERDICT row) is FIXTURE BROKEN, never scored. `--matrix` runs every mutant over every world and prints the
# red set; the rows below are that measurement.
P_MDIR="$WORK/pmut"; P_MTMP="$WORK/ddtmp-mut"; mkdir -p "$P_MDIR" "$P_MTMP"
for _f in derivation-differential.sh apply.sh preclassify.sh consumer-read.sh template-sites.md; do
  [ -f "$(dirname "$SUBJ")/$_f" ] || { echo "FIXTURE ERROR: $_f is not beside the subject, so no copy of the helper can run" >&2; exit 2; }
done
# pmutdir <name> <anchor> <replacement>... -> $P_MDIR/<name>/derivation-differential.sh, its siblings copied beside it
pmutdir() {
  local m="$1" f; shift
  mkdir -p "$P_MDIR/$m"
  for f in apply.sh preclassify.sh consumer-read.sh template-sites.md; do cp "$(dirname "$SUBJ")/$f" "$P_MDIR/$m/$f"; done
  pmut "$SUBJ" "$P_MDIR/$m/derivation-differential.sh" "$@"
}
# pwrong <label> <tag>: the WRONG verdict the deciding arm exists to refuse is present
pwrong() {
  local w r k; w="$(pworld "$1")"
  case "$1" in
    Pi_owed) p_owed "$2" i "$P_KI" 1 ;;
    # the unbounded list: the relabel NOTE for Pi's key is still printed, and runs to 1000 bytes or more
    Pi_bound) [ "$(awk -F'\t' -v k="$P_KI" '$1 == "NOTE" && $2 == k && index($3, "STALE-BOTH, not NEWLY-FAILING") { print length($0); exit }' "$WORK/o/$2/i.out")" -ge 1000 ] 2>/dev/null ;;
    Pcapabc_sb) grep -q 'integer expression expected' "$WORK/o/$2/capabc.out" ;;
    Pii_nf) awk -F'\t' -v k="$P_KII" '$1 == "NOTE" && $2 == k && index($3, "overlay skipped") { f = 1 } END { exit !f }' "$WORK/o/$2/ii.out" ;;
    Ptpl_nf) [ "$(prc "$2" tplsite)" = 0 ] && [ "$(rowst "$WORK/o/$2/tplsite.out" "$P_KTPL")" = STALE-BOTH ] ;;
    Px_unset) [ "$(cat "$WORK/o/$2/x.unset" 2>/dev/null)" != ok ] && ! cmp -s "$WORK/o/$2/x-tree0" "$WORK/o/$2/x-tree1" ;;
    Piii_nf|Piiip_nf) [ "$(prc "$2" "$w")" = 0 ] && [ "$(rowst "$WORK/o/$2/$w.out" "$P_KIII")" = STALE-BOTH ] ;;
    Pv_nf) [ "$(prc "$2" v)" = 0 ] && [ "$(rowst "$WORK/o/$2/v.out" "$P_KV")" = STALE-BOTH ] ;;
    Pvi_nf) [ "$(prc "$2" vi)" = 0 ] && [ "$(rowst "$WORK/o/$2/vi.out" "$P_KVI")" = STALE-BOTH ] ;;
    Pvii_nf)
      # the cap dropped (the key relabelled), or the skip row lost while the row stays NEWLY-FAILING
      { [ "$(prc "$2" vii)" = 0 ] && [ "$(rowst "$WORK/o/$2/vii.out" "$P_KVII")" = STALE-BOTH ]; } \
        || { p_nf "$2" vii "$P_KVII" && ! grep -q 'overlay skipped' "$WORK/o/$2/vii.out"; } ;;
    Pviii_nf) [ "$(prc "$2" viii)" = 0 ] && [ "$(rowst "$WORK/o/$2/viii.out" "$P_KI")" = STALE-BOTH ] ;;
    # an exact-cap or the old 256 default, or an override the helper should have refused: the key skipped and failing
    Pi_row|Pviic_sb|Pcapzero_sb)
      case "$1" in Pi_row) r=i; k="$P_KI" ;; Pviic_sb) r=viic; k="$P_KVII" ;; *) r=capzero; k="$P_KI" ;; esac
      p_nf "$2" "$r" "$k" && grep -q 'exceed the overlay cap' "$WORK/o/$2/$r.out" ;;
    *) return 1 ;;
  esac
}
# pscore <name> <deciding label> <twin label> <base flag> -- one subject copy, its deciding world, its verdict. The
# flag is the $(( )) conjunction of the deciding arm's and the twin's B_ flags, from the unmutated runs above.
pscore() {
  local m="$1" dec="$2" twin="$3" w r red="" c
  w="$(pworld "$dec")"
  if [ "$w" = x ]; then px "$m" "$P_MDIR/$m/validate-artifact-derivations.sh"
  else
    pw "$m" "$w" "$P_MDIR/$m/derivation-differential.sh" "$P_MTMP"
    grep -q '^VERDICT' "$WORK/o/$m/$w.out" \
      || { bad "FIXTURE BROKEN: $m -- the copy reached no verdict (exit $(prc "$m" "$w")), so nothing about it can be scored"; return; }
  fi
  if [ "$PMATRIX" = 1 ]; then
    if [ "$w" != x ]; then for r in $P_RUNWORLDS; do [ "$r" = "$w" ] || pw "$m" "$r" "$P_MDIR/$m/derivation-differential.sh" "$P_MTMP"; done; fi
    for c in $P_CELLS; do
      [ "$w" = x ] && [ "$(pworld "$c")" != x ] && continue
      [ "$w" != x ] && [ "$(pworld "$c")" = x ] && continue
      [ "$(pworld "$c")" = nots ] && continue  # nots drives its own fixed copy of the helper, never a mutant
      pcell "$c" "$m" || red="$red,$c"
    done
    printf 'MATRIX %s decides=%s twins=%s red=%s\n' "$m" "$dec" "$twin" "${red#,}"
  fi
  if pcell "$dec" "$m"; then bad "$m SURVIVED: its deciding arm $dec stayed green"
  elif ! pwrong "$dec" "$m"; then bad "$m: $dec went red, but not by the wrong verdict it exists to refuse -- not scored"
  elif ! pcell "$twin" "$m"; then bad "$m: its twin $twin went red too -- the change is not confined to its arm"
  else
    mutant_killed "$4" "$m" "mutant $m KILLED by $dec (the wrong verdict appeared); twin $twin holds"
  fi
}
if pmutdir dd-nocmp 'if ! cmp -s "$TMP/fo.b/$_vb.out" "$TMP/fo.t/$_vt.out"; then' 'if false; then'; then pscore dd-nocmp Piii_nf Piii_ctl "$(( ${B_Piii_nf:-0} && ${B_Piii_ctl:-0} ))"
else bad "dd-nocmp DID NOT APPLY: its anchor matched no line, or more than one"; fi
if pmutdir dd-trunc 'if ! cmp -s "$TMP/fo.b/$_vb.out" "$TMP/fo.t/$_vt.out"; then' \
     'if [ "$(tr "\n" "/" < "$TMP/fo.b/$_vb.out" | cut -c1-160)" != "$(tr "\n" "/" < "$TMP/fo.t/$_vt.out" | cut -c1-160)" ]; then'; then
  pscore dd-trunc Piiip_nf Piiip_ctl "$(( ${B_Piiip_nf:-0} && ${B_Piiip_ctl:-0} ))"
else bad "dd-trunc DID NOT APPLY: its anchor matched no line, or more than one"; fi
if pmutdir dd-noroots 'case "$_p" in "$_r"*) _q=1; break ;; esac' ':'; then pscore dd-noroots Pv_nf Pv_ctl "$(( ${B_Pv_nf:-0} && ${B_Pv_ctl:-0} ))"
else bad "dd-noroots DID NOT APPLY: its anchor matched no line, or more than one"; fi
if pmutdir dd-untracked "'!! '*) ;; *) continue ;; esac" "'!! '*|'?? '*) ;; *) continue ;; esac" '_p="${_e#!! }"' '_p="${_e#?? }"'; then
  pscore dd-untracked Pvi_nf Pvi_ctl "$(( ${B_Pvi_nf:-0} && ${B_Pvi_ctl:-0} ))"
else bad "dd-untracked DID NOT APPLY: its anchor matched no line, or more than one"; fi
if pmutdir dd-nocap 'if [ "$_n" -gt "$DD_OVERLAY_CAP" ]; then _over=1; continue; fi' ':'; then pscore dd-nocap Pvii_nf Pvii_ctl "$(( ${B_Pvii_nf:-0} && ${B_Pvii_ctl:-0} ))"
else bad "dd-nocap DID NOT APPLY: its anchor matched no line, or more than one"; fi
if pmutdir dd-capoff1 'if [ "$_n" -gt "$DD_OVERLAY_CAP" ]; then' 'if [ "$_n" -ge "$DD_OVERLAY_CAP" ]; then'; then
  pscore dd-capoff1 Pviic_sb Pviic_ctl "$(( ${B_Pviic_sb:-0} && ${B_Pviic_ctl:-0} ))"
else bad "dd-capoff1 DID NOT APPLY: its anchor matched no line, or more than one"; fi
if pmutdir dd-noskipline "dd_ov_note \"\$_k\" \"overlay skipped: \${_n} ignored file(s)" ": \"overlay skipped: \${_n} ignored file(s)"; then
  pscore dd-noskipline Pvii_nf Pvii_ctl "$(( ${B_Pvii_nf:-0} && ${B_Pvii_ctl:-0} ))"
else bad "dd-noskipline DID NOT APPLY: its anchor matched no line, or more than one"; fi
if pmutdir dd-cap256 'DD_OVERLAY_CAP=4096' 'DD_OVERLAY_CAP=256'; then pscore dd-cap256 Pi_row Pi_ctl "$(( ${B_Pi_row:-0} && ${B_Pi_ctl:-0} ))"
else bad "dd-cap256 DID NOT APPLY: its anchor matched no line, or more than one"; fi
if pmutdir dd-capvalid "''|*[!0-9]*|0*) ;;" "'') ;;"; then pscore dd-capvalid Pcapzero_sb Pcapzero_ctl "$(( ${B_Pcapzero_sb:-0} && ${B_Pcapzero_ctl:-0} ))"
else bad "dd-capvalid DID NOT APPLY: its anchor matched no line, or more than one"; fi
if pmutdir dd-notpl '_roots="$_roots$_ts$_nl${ART#"$CONSUMER"/}/$_nl"' '_roots="$_roots${ART#"$CONSUMER"/}/$_nl"'; then
  pscore dd-notpl Ptpl_nf Ptpl_ctl "$(( ${B_Ptpl_nf:-0} && ${B_Ptpl_ctl:-0} ))"
else bad "dd-notpl DID NOT APPLY: its anchor matched no line, or more than one"; fi
if pmutdir dd-noisy '[ "$_n" -gt 0 ] || continue' '[ "$_n" -gt 0 ] || { dd_ov_skip "$_k" "nothing to overlay"; continue; }'; then
  pscore dd-noisy Pii_nf Pii_sb "$(( ${B_Pii_nf:-0} && ${B_Pii_sb:-0} ))"
else bad "dd-noisy DID NOT APPLY: its anchor matched no line, or more than one"; fi
if pmutdir dd-unbounded 'NR <= 5 { l = l (NR > 1 ? " " : "") $0 }' '{ l = l (NR > 1 ? " " : "") $0 }'; then
  pscore dd-unbounded Pi_bound Pi_ctl "$(( ${B_Pi_bound:-0} && ${B_Pi_ctl:-0} ))"
else bad "dd-unbounded DID NOT APPLY: its anchor matched no line, or more than one"; fi
if pmutdir dd-capvalid-abc "''|*[!0-9]*|0*) ;;" "''|0*) ;;"; then pscore dd-capvalid-abc Pcapabc_sb Pcapabc_ctl "$(( ${B_Pcapabc_sb:-0} && ${B_Pcapabc_ctl:-0} ))"
else bad "dd-capvalid-abc DID NOT APPLY: its anchor matched no line, or more than one"; fi
if pmutdir dd-baseroot '[ "$N_NF" -gt 0 ] && [ "$BASE_ROOT_SET" -eq 0 ] && [ -n "$WT" ]' '[ "$N_NF" -gt 0 ]'; then
  pscore dd-baseroot Pviii_nf Pviii_tree "$(( ${B_Pviii_nf:-0} && ${B_Pviii_tree:-0} ))"
else bad "dd-baseroot DID NOT APPLY: its anchor matched no line, or more than one"; fi
if pmutdir dd-lateowed '[ -s "$TMP/relabel" ] && dd_classify' \
     '[ -s "$TMP/relabel" ] && { cp "$TMP/owed" "$TMP/owed.first"; dd_classify; cp "$TMP/owed.first" "$TMP/owed"; rm -f "$TMP/owed.first"; }'; then
  pscore dd-lateowed Pi_owed Pi_row "$(( ${B_Pi_owed:-0} && ${B_Pi_row:-0} ))"
else bad "dd-lateowed DID NOT APPLY: its anchor matched no line, or more than one"; fi
mkdir -p "$P_MDIR/vd-sidecar"
if pmut "$VALIDATOR" "$P_MDIR/vd-sidecar/validate-artifact-derivations.sh" \
     'local d="$AI_DLC_VD_FULL_OUT_DIR" n' 'local d="${AI_DLC_VD_FULL_OUT_DIR:-.}" n' \
     'if [ -n "${AI_DLC_VD_FULL_OUT_DIR:-}" ]; then vd_full_out "$f" "$ln" empty; fi' 'vd_full_out "$f" "$ln" empty' \
     'if [ -n "${AI_DLC_VD_FULL_OUT_DIR:-}" ]; then vd_full_out "$f" "$ln"; fi' 'vd_full_out "$f" "$ln"'; then
  pscore vd-sidecar Px_unset Px_set "$(( ${B_Px_unset:-0} && ${B_Px_set:-0} ))"
else bad "vd-sidecar DID NOT APPLY: its anchor matched no line, or more than one"; fi

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
for c in "$W1" "$W2" "$W3" "$W5" "$W5P" "$WSU" "$WSUN" "$W13" "$W13N" "$WS3" "$WS3N" "$W16" "$W16N" "$W17" "$W17N" "$W18" "$W19" "$WS1" "$WS1C" "$WS3S" "$WS2" "$WS2C" $P_RUNS; do
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
[ "$left" = 0 ] || find "$DDTMP" -mindepth 1 -maxdepth 3 2>/dev/null | sed 's/^/        | /' | head -10

if [ "$fails" -ne 0 ]; then
  printf '  %s assertion(s) FAILED\n' "$fails"; exit 1
fi
printf '  all assertions hold\n'
exit 0
