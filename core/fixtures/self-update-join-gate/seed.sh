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
#   CONS_CURRENT  installed from the SAME ref the pull targets on the rulebook side, so a
#                 machinery-only pull against it must NOT defer.
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
DIST="$WORK/dist"
git clone -q "$D_ROOT" "$DIST" 2>/dev/null || {
  echo "FIXTURE ERROR: could not clone the distribution" >&2; exit 2; }

# BASE/THEIRS are DERIVED from the range that actually adds a check, never hardcoded to a
# release number. The subject is "a pull that crosses a check-adding commit", so the seed
# finds one: the newest commit that adds a CHECK_LOADED anchor, and its parent.
ADDED="$(git -C "$DIST" log --format=%H -S'<!-- CHECK_LOADED:' --pickaxe-regex \
           -- core/skills/ai-dlc/steps/gate-validation.md | head -1)"
if [ -z "$ADDED" ]; then
  echo "FIXTURE ERROR: no commit in history adds a CHECK_LOADED anchor, so there is no" >&2
  echo "  check-adding range to test and every assertion would pass vacuously." >&2
  exit 2
fi
BASE="$(git -C "$DIST" rev-parse "${ADDED}^")"

# THEIRS IS BOUNDED A FEW RELEASES PAST THE ANCHOR-ADDER, NOT HEAD, AND THE COST IS THE REASON.
#
# The subject is "a pull that crosses a check-adding commit", which needs $ADDED inside the
# range and nothing else. Taking HEAD made the range everything since $ADDED, and
# `self-update-gate.sh`'s `advise_safe_stop` spawns ONE NESTED FULL GATE INVOCATION per
# VERSION-touching commit in it (`:120-122`). Measured on this history: 111 VERSION commits in
# the range, ~1.4s per nested invocation, 153.7s of a 155.07s gate call -- 99.1% of the cost,
# for a term no assertion here reads. The range grew by one invocation per release that added
# no anchor, so this fixture got slower on its own and became the suite's longest pole.
#
# STILL DERIVED, NEVER A HARDCODED REF. The bound is "the Nth VERSION-touching commit after
# $ADDED", walked forward from the derived anchor commit, so it moves with history exactly as
# the old form did. A literal sha here would be the thing the block above exists to avoid.
#
# THE FLOOR KEEPS SAFE-STOP EXERCISED. Bounding to $ADDED itself would leave the safe-stop loop
# with zero candidates, and a fixture that runs the gate without ever entering that loop passes
# having tested less than it did before. The floor below asserts the loop still has work.
SUJG_SS_FLOOR=4
ss_after="$(git -C "$DIST" rev-list --reverse "${ADDED}..HEAD" -- VERSION)"
n_after="$(grep -c . <<<"$ss_after")"
if [ "${n_after:-0}" -ge "$SUJG_SS_FLOOR" ]; then
  THEIRS="$(sed -n "${SUJG_SS_FLOOR}p" <<<"$ss_after")"
  SUJG_BOUNDED=yes
else
  # Not enough history after the anchor-adder to bound against -- e.g. the anchor landed in the
  # last few releases. Fall back to the old unbounded end. This is the pre-existing behaviour,
  # so the fallback cannot be a regression, and it is why the floor below is asserted only in
  # the bounded case: failing here would wedge a push on a tree whose only fault is a recent
  # anchor commit.
  THEIRS="$(git -C "$DIST" rev-parse HEAD)"
  SUJG_BOUNDED=no
fi

# The candidate count the safe-stop loop will actually iterate: VERSION-touching commits in the
# range, minus THEIRS itself, which `:121` skips. Read into a variable and matched with a
# here-string -- `git ... | grep -q` reports the WRITER's EPIPE once output past the match
# exceeds the pipe buffer, which answers NOT-FOUND on input that contains the pattern.
ss_list="$(git -C "$DIST" rev-list "${BASE}..${THEIRS}" -- VERSION)"
ss_n="$(grep -c . <<<"$ss_list")"
ss_eff="${ss_n:-0}"
grep -qx "$THEIRS" <<<"$ss_list" && ss_eff=$((ss_n - 1))
if [ "$SUJG_BOUNDED" = yes ] && [ "$ss_eff" -lt 1 ]; then
  echo "FIXTURE ERROR: the bounded range leaves the safe-stop loop $ss_eff candidate(s)," >&2
  echo "  so advise_safe_stop would never enter its loop and the gate would be exercised" >&2
  echo "  less than it was before the range was bounded (target floor: $SUJG_SS_FLOOR)." >&2
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

cat > "$WORK/env.sh" <<EOF
DIST="$DIST"
BASE="$BASE"
THEIRS="$THEIRS"
CONS_OLD="$CONS_OLD"
CONS_CURRENT="$CONS_CURRENT"
EOF

printf '%s\n' "$WORK"
