#!/usr/bin/env bash
# self-update-join-gate/seed.sh — two consumer trees and a real distribution clone.
#
# REAL TREES, NOT SIMULATED ONES. The gate diffs a git range and reads the consumer's own
# gate-validation.md, so a hand-built stand-in would prove nothing about the part that
# actually runs. Both consumers are produced by install.sh from a real checkout, which is
# also what makes the CHECK_LOADED anchor sets genuine rather than authored here.
#
# The two consumers are the fixture's whole discrimination:
#   CONS_OLD      installed from a ref BEFORE a check was added -> its gate-validation.md
#                 has no anchor for that check, so the map/anchor join is broken.
#   CONS_CURRENT  installed from the SAME ref the pull targets on the rulebook side, with every
#                 script the range changes put back at BASE, so a machinery-only pull against it
#                 must NOT defer.
#
# Idempotent.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
D_ROOT="$(cd "$HERE/../../.." && pwd)"

[ -f "$D_ROOT/core/skills/ai-dlc-update/reconcile/self-update-gate.sh" ] || {
  echo "seed: not a distribution tree (no self-update-gate.sh)" >&2; exit 2; }

WORK="$(mktemp -d "${TMPDIR:-/tmp}/su-join-gate.XXXXXX")" || exit 2

# A PRIVATE TMPDIR PER RUN, POINTED INSIDE THIS RUN'S OWN WORK TREE.
#
# Everything this seed spawns -- git, install.sh, and whatever they spawn -- inherits it, so a
# run's scratch state is self-contained and is removed with the run instead of accumulating as
# loose siblings in a namespace shared with every other process on the box.
#
# WHAT THIS DOES NOT DO, stated because the failure it half-addresses is expensive and the next
# reader should not over-trust it: it does NOT make the work tree safe from an external
# `rm -rf "$TMPDIR"/su-join-gate.*`. Nothing can -- a shared parent directory is reachable by
# any glob written against it. Measured in this session: a concurrent cleanup of that pattern
# deleted a live run's consumer trees mid-pool, every gate child's copy step failed, and the
# fixture reported six "produced no verdict" FAILs. THOSE ARE BYTE-IDENTICAL TO THE VERDICT A
# GENUINELY DROPPED POOL PRODUCES, and no arm here can separate them: the completeness arm sees
# an absent `.done` marker either way. Re-running is the only discriminator. What is bounded is
# the blast radius of this fixture's OWN temp files, not the reachability of its work tree.
export TMPDIR="$WORK/tmp"
mkdir -p "$TMPDIR" || exit 2

# A clone, never the live repo: the gate runs `git -C "$DIST" checkout`-free reads, but a
# fixture that points a tool at the working repository can be perturbed by it.
#
# HARDLINKED, WHICH IS THE DEFAULT AND IS SAFE. The isolation this clone buys is isolation of
# the WORKING TREE and of HEAD, not of the object store. Git objects are immutable and
# content-addressed: `gc`/`repack` write new files and unlink old ones, so unlinking one
# hardlink cannot damage the other repository. `--no-hardlinks` bought nothing here and cost a
# byte copy of the whole pack, three times per seed.
# DO NOT "IMPROVE" THIS TO `--shared` OR `--reference`. Those are the genuinely unsafe forms:
# they install `objects/info/alternates` instead of copying, so a prune or a repack in the
# SOURCE repository can delete objects this clone still needs, and the failure surfaces later
# as a corrupt clone rather than at clone time.
# BASE AND THEIRS HAVE ONE DERIVATION, range.sh. It names the parent of the newest commit that adds a
# CHECK_LOADED anchor and the fourth VERSION-touching commit after that commit, and its header says why the bound
# is the cost of advise_safe_stop's walk. git.decl's `range @range.sh <paths>` line runs the same file once per
# push, keys the fixture on the range's commits that touch what the seed reads at either end, and in a hermetic
# sandbox packs that range and writes its ends as refs/hermetic/range-1/{base,theirs} in the sandbox ROOT
# repository. So: those refs when they exist, and range.sh run from the root otherwise. The sandbox repository has
# no branch, and a clone of a branchless repository carries nothing, so its HEAD branch is pointed at THEIRS there,
# and only there; a real checkout always has a branch and is never written.
if b="$(git -C "$D_ROOT" rev-parse -q --verify refs/hermetic/range-1/base 2>/dev/null)" \
   && t="$(git -C "$D_ROOT" rev-parse -q --verify refs/hermetic/range-1/theirs 2>/dev/null)"; then
  BASE="$b"; THEIRS="$t"
  if [ -z "$(git -C "$D_ROOT" for-each-ref --count=1 refs/heads)" ]; then
    hb="$(git -C "$D_ROOT" symbolic-ref -q HEAD)" && git -C "$D_ROOT" update-ref "$hb" "$THEIRS" || {
      echo "FIXTURE ERROR: could not give the branchless sandbox repository a HEAD branch at THEIRS" >&2; exit 2; }
  fi
else
  rng="$(cd "$D_ROOT" && bash "$HERE/range.sh")" || rng=""
  BASE="${rng%%..*}"; THEIRS="${rng#*..}"
  case "$rng" in ?*..?*) ;; *)
    echo "FIXTURE ERROR: range.sh derived no <base>..<theirs> (no commit adds a CHECK_LOADED anchor, or git failed)," >&2
    echo "  so there is no check-adding range to test and every assertion would pass vacuously." >&2
    exit 2 ;;
  esac
fi

DIST="$WORK/dist"
git clone -q "$D_ROOT" "$DIST" 2>/dev/null || {
  echo "FIXTURE ERROR: could not clone the distribution" >&2; exit 2; }
for _r in "$BASE" "$THEIRS"; do
  git -C "$DIST" cat-file -e "${_r}^{commit}" 2>/dev/null || {
    echo "FIXTURE ERROR: range end $_r is not a commit in the distribution clone" >&2; exit 2; }
done

# The candidate count the safe-stop loop will actually iterate: VERSION-touching commits in the
# range, minus THEIRS itself, which `:121` skips. Read into a variable and matched with a
# here-string -- `git ... | grep -q` reports the WRITER's EPIPE once output past the match
# exceeds the pipe buffer, which answers NOT-FOUND on input that contains the pattern.
ss_list="$(git -C "$DIST" rev-list "${BASE}..${THEIRS}" -- VERSION)"
ss_n="$(grep -c . <<<"$ss_list")"
ss_eff="${ss_n:-0}"
grep -qx "$THEIRS" <<<"$ss_list" && ss_eff=$((ss_n - 1))
if [ "$ss_eff" -lt 1 ]; then
  echo "FIXTURE ERROR: the range leaves the safe-stop loop $ss_eff candidate(s), so r_old's one real" >&2
  echo "  advise_safe_stop walk would never enter its loop (range.sh bounds THEIRS four releases past the anchor)." >&2
  exit 2
fi

# A range that adds no anchor would make assertion 1 vacuous. Prove it adds at least one.
n_base="$(git -C "$DIST" show "${BASE}:core/skills/ai-dlc/steps/gate-validation.md" 2>/dev/null \
          | grep -c '^<!-- CHECK_LOADED:' || true)"
n_theirs="$(git -C "$DIST" show "${THEIRS}:core/skills/ai-dlc/steps/gate-validation.md" 2>/dev/null \
          | grep -c '^<!-- CHECK_LOADED:' || true)"
if [ "${n_theirs:-0}" -le "${n_base:-0}" ]; then
  echo "FIXTURE ERROR: the derived range adds no anchor (base=$n_base theirs=$n_theirs);" >&2
  echo "  assertion 1 would test a pull with nothing to defer on." >&2
  exit 2
fi

install_at() { # install_at <ref> <dest>
  # TWO `local` STATEMENTS, AND THE SPLIT IS LOAD-BEARING. `local` is a BUILTIN: the whole
  # argument list is word-expanded before the builtin assigns anything, so in the one-statement
  # form this used to carry --
  #   local ref="$1" dest="$2" src="$WORK/src-${ref:0:8}"
  # -- `${ref:0:8}` expands against the ENCLOSING scope, not against the `ref` on the same
  # line. Measured on bash 3.2, this box's floor and the shell that runs this fixture: with an
  # outer `a=GLOBAL`, `local a="LOCAL" b="[$a]"` yields `b=[GLOBAL]`; here nothing outer is
  # named `ref`, so `${ref:0:8}` was the empty string and BOTH calls derived the same
  # `$WORK/src-`. Serially that is invisible -- `rm -rf "$src"` wipes it between calls -- so it
  # survived as a latent collision until the two calls were made concurrent, where the second
  # clone dies with `could not create work tree dir '.../src-': File exists`.
  local ref="$1" dest="$2"
  local src="$WORK/src-${ref:0:8}"
  # Hardlinked for the reason stated at the DIST clone above; NOT `--shared`/`--reference`.
  rm -rf "$src"; git clone -q "$DIST" "$src" 2>/dev/null || return 1
  git -C "$src" checkout -q "$ref" || return 1
  mkdir -p "$dest/_bmad"
  ( cd "$dest" && git init --quiet . ) || return 1
  ( cd "$dest" && bash "$src/scripts/install.sh" . >/dev/null 2>&1 ) || return 1
}

CONS_OLD="$WORK/cons-old"
CONS_CURRENT="$WORK/cons-current"
# The two installs are independent — distinct `ref`, distinct `dest`, a `$src` that is now
# genuinely derived from the ref (see the `local` split above; it was NOT before), and a
# $DIST that is read-only to both. So they run concurrently.
#
# EACH PID IS WAITED ON INDIVIDUALLY, AND THAT IS THE LOAD-BEARING PART. A naked `wait` returns
# 0 whatever the children did: a broken install would then reach the assertions as a seeded
# tree that is merely missing files, and the two failures would be indistinguishable from each
# other. The per-PID form keeps `install at BASE failed` and `install at THEIRS failed` as
# separate verdicts naming the ref that actually broke.
install_at "$BASE"   "$CONS_OLD"     & p_base=$!
install_at "$THEIRS" "$CONS_CURRENT" & p_theirs=$!
wait "$p_base"   || { echo "FIXTURE ERROR: install at BASE failed" >&2; exit 2; }
wait "$p_theirs" || { echo "FIXTURE ERROR: install at THEIRS failed" >&2; exit 2; }

for d in "$CONS_OLD" "$CONS_CURRENT"; do
  [ -f "$d/.claude/skills/ai-dlc/steps/gate-validation.md" ] || {
    echo "FIXTURE ERROR: $d has no installed gate-validation.md; the anchor join has no subject" >&2
    exit 2; }
done

# CONS_CURRENT'S SCRIPTS ARE PUT BACK AT BASE, SO "NO RULEBOOK CHANGE" HOLDS BY CONSTRUCTION.
#
# Assertion 3's consumer is "rulebook at theirs, machinery not yet pulled". An install at THEIRS
# gets the rulebook half right and the machinery half wrong: every core/scripts/*.sh the range
# changes is ALREADY at theirs, and the gate's pre-written arm (self-update-gate.sh, `ALREADY at
# theirs`) refuses that state as UNDECIDED -- correctly, it is what a re-run after step 2's write
# looks like. So assertion 3 went red the first time the derived range crossed a release that
# changed a gating script (0.805.0, validate-layer-entries.sh), and would again at any HEAD whose
# range moved one. Putting each such script back at its BASE bytes builds the state step 2 really
# gates: the pull's machinery is incoming, its rulebook already held. A script the range ADDS is
# removed. Each restore is checked by blob, and the list goes to env.sh for run.sh's mutant.
SUJG_RESTORED=""
sc_list="$(git -C "$DIST" -c core.quotePath=false diff --name-only "${BASE}..${THEIRS}" -- core/scripts/)" || {
  echo "FIXTURE ERROR: could not list core/scripts/ changes in ${BASE}..${THEIRS}" >&2; exit 2; }
while IFS= read -r sp; do
  [ -n "$sp" ] || continue
  cf="$CONS_CURRENT/scripts/ai-dlc/${sp#core/scripts/}"
  [ -f "$cf" ] || continue
  if bb="$(git -C "$DIST" rev-parse -q --verify "${BASE}:${sp}")"; then
    git -C "$DIST" show "${BASE}:${sp}" > "$cf" || { echo "FIXTURE ERROR: could not restore $sp at BASE" >&2; exit 2; }
    [ "$(git hash-object "$cf")" = "$bb" ] || { echo "FIXTURE ERROR: $cf is not BASE's blob after restore" >&2; exit 2; }
  else
    rm -f "$cf"
  fi
  SUJG_RESTORED="$SUJG_RESTORED ${sp#core/scripts/}"
done <<<"$sc_list"
SUJG_RESTORED="${SUJG_RESTORED# }"

cat > "$WORK/env.sh" <<EOF
DIST="$DIST"
BASE="$BASE"
THEIRS="$THEIRS"
CONS_OLD="$CONS_OLD"
CONS_CURRENT="$CONS_CURRENT"
SUJG_RESTORED="$SUJG_RESTORED"
EOF

printf '%s\n' "$WORK"
