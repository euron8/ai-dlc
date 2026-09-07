#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
# fixture-git-env-seam — a fixture run DIRECTLY, with git's repository environment
# inherited, must not touch the caller's index. This asserts the BEHAVIOUR, by
# driving a real fixture against a real victim repository, not that a scrub line
# is written down anywhere.
#
# THE DEFECT. Git exports GIT_DIR ABSOLUTE to any hook it runs from a linked
# worktree. `CLAUDE.md` tells a session debugging one fixture to run it by hand —
# `bash core/fixtures/X/run.sh` — and that invocation passes through NO seam: both
# pre-push hooks scrub before dispatching the pool, so the SUITE was never exposed
# and only the by-hand path is. Under an inherited GIT_DIR, `git init` SILENTLY
# SUCCEEDS WITHOUT CREATING A REPOSITORY in the target directory (`.git` absent
# afterwards, exit 0, no diagnostic), so every later git call in the fixture is
# redirected onto the caller's repository.
#
# MEASURED across eight fixtures before this fixture existed, fresh victim per
# trial, against an unarmed control that left all eight intact: 8 of 8 wiped a
# 757-entry index to single digits, and 6 of the 8 did it while exiting 0 with
# ZERO FAILs. The blast radius is the INDEX only — HEAD, refs and worktree files
# survive and `git reset --hard` recovers — but until someone works that out the
# victim reads as a catastrophic deletion.
#
# WHY THIS IS NOT A TEXT ANCHOR. A grep for the scrub line establishes that the
# line EXISTS. It cannot establish that the line executes, and the (m3) mutant
# below — the real scrub text present but COMMENTED OUT — satisfies every
# grep-shaped check while changing nothing. That mutant is the whole reason this
# fixture drives a victim instead of reading a file. The same distinction retired
# BL-191's original receipt, which 30 files containing nothing but `# env -i`
# could close.
#
# WHY THE VICTIM'S REPOSITORY-NESS IS ASSERTED AND NOT ASSUMED, which is the arm
# most likely to be removed by someone tidying up. A fixture that clobbers leaves
# the victim WITHOUT a repository, so an arm that reads that directory afterwards
# describes the OUTER repo instead — its before and after readings then both come
# from the wreckage and `after -eq before` holds BY CONSTRUCTION. An index-count
# guard alone prints "intact" over the damage. `[ -d "$victim/.git" ]` is what
# makes the count mean anything, and it is checked in both worlds.
#
# WHAT IT DRIVES. The shipping seam and a shipping fixture, unmodified, in a
# sandbox that is a real repository with a real linked worktree, with GIT_DIR
# exported the way git exports it. Every mutant is a COPY guarded by `cmp -s`, and
# the UNMUTATED copy runs through the same harness in the same battery, so a
# broken harness cannot let a mutant score a kill.
set -u

FAILS=0
ok()   { printf '  ok    %s\n' "$1"; }
fail() { printf '  FAIL  %s\n' "$1"; FAILS=$((FAILS + 1)); }
broken() { printf 'FIXTURE BROKEN: %s\n' "$1"; exit 9; }

# Resolve the repo root by walking UP for a marker. Counting `..` hops answers
# differently from the root, from a subdirectory, and from a sandbox copy — and
# the sandbox answer is the silent one. This fixture must hold from any cwd.
#
# THE MARKER IS THE SEAM ITSELF, NOT `VERSION`, and I55 is why. The content key
# does not hash `VERSION` (every release edits it, so including it would drive the
# skip's hit rate to zero), and a fixture reading an unhashed path is one whose
# input can change while the suite is skipped as unchanged. `core/fixtures/lib/`
# is inside the hashed set and is this fixture's own subject, so the marker moves
# exactly when the thing under test moves.
ROOT="$(cd "$(dirname "$0")" && pwd)"
while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/core/fixtures/lib/preamble.sh" ]; do ROOT="$(dirname "$ROOT")"; done
[ -f "$ROOT/core/fixtures/lib/preamble.sh" ] || broken "no core/fixtures/lib/preamble.sh above $0 — cannot locate the repo root, and the seam is this fixture's subject"

SEAM="$ROOT/core/fixtures/lib/preamble.sh"

# The DRIVEN fixture. Chosen because it builds a scratch repo and is unrelated to
# this subject, so it is not co-maintained with the thing under test.
SUBJECT="trunk-push-bound"
[ -f "$ROOT/core/fixtures/$SUBJECT/run.sh" ] || broken "driven fixture $SUBJECT is absent"

WORK="$(mktemp -d)" || broken "mktemp failed"
trap 'chmod -R u+rwX "$WORK" 2>/dev/null; rm -rf "$WORK"' EXIT

# --- the victim -------------------------------------------------------------
# A real repository with a real linked worktree, because GIT_DIR's exported form
# is a property of that shape and nothing else reproduces it.
new_victim() { # new_victim <dir> -> echoes the worktree admin dir
  local v="$1"
  rm -rf "$v"
  mkdir -p "$v/repo" || return 1
  (
    cd "$v/repo" || exit 1
    git init -q . || exit 1
    git config user.email f@x; git config user.name f
    # 40 tracked paths: enough that a clobber is unmistakable and cheap to build.
    for i in $(seq 1 40); do printf 'x\n' > "f$i"; done
    git add -A -f >/dev/null 2>&1 || exit 1
    git commit -qm base >/dev/null 2>&1 || exit 1
    git worktree add -q "$v/wt" -b probe >/dev/null 2>&1 || exit 1
  ) || return 1
  printf '%s\n' "$v/repo/.git/worktrees/wt"
}
victim_count() { # victim_count <admin> <wt>
  GIT_DIR="$1" git --work-tree="$2" ls-files 2>/dev/null | wc -l | tr -d ' '
}

# --- the harness ------------------------------------------------------------
# Run the driven fixture from TREE, with GIT_DIR armed at the victim, and report
# "<count-after> <victim-is-a-repo>".
drive() { # drive <tree> <victim-root> -> "<n> <yes|no>"
  local tree="$1" v="$2" admin
  admin="$(new_victim "$v")" || return 1
  ( cd "$tree" && GIT_DIR="$admin" bash "core/fixtures/$SUBJECT/run.sh" ) >/dev/null 2>&1
  local n repo=no
  n="$(victim_count "$admin" "$v/wt")"
  [ -d "$v/repo/.git" ] && repo=yes
  printf '%s %s\n' "$n" "$repo"
}

# A mutable copy of the tree. Every mutant edits THIS, never $ROOT.
#
# IT IS A WHOLE-TREE COPY, AND THE FIRST CUT OF THIS FIXTURE COPIED ONLY THE SEAM
# AND THE DRIVEN FIXTURE. That tree is missing the validators the driven fixture
# resolves at startup, so it exited `FIXTURE ERROR: cannot locate
# validate-audit-anchors.sh` BEFORE reaching any `git init` — and a fixture that
# never runs cannot clobber. All four mutants therefore "survived" against a
# pristine victim, which reads exactly like a seam that works. The tell was that
# arm A passed too: in a partial tree BOTH worlds are inert, so the arm was
# comparing two runs of nothing. Copy the whole tree.
mktree() { # mktree <dest>
  local dest="$1"
  rm -rf "$dest"
  # `git archive HEAD` would miss the uncommitted seam on the branch that adds it.
  # Copy the working tree, excluding .git so the copy is not itself a repository.
  mkdir -p "$dest" || return 1
  ( cd "$ROOT" && tar cf - --exclude='./.git' --exclude='./node_modules' . ) | ( cd "$dest" && tar xf - ) || return 1
  [ -f "$dest/core/fixtures/lib/preamble.sh" ] || return 1
  [ -f "$dest/core/fixtures/$SUBJECT/run.sh" ] || return 1
}

echo "fixture-git-env-seam"

# --- H. HARNESS SANITY, and it runs FIRST -----------------------------------
# A harness that cannot build a victim, or whose victim cannot be moved, would
# make every arm below pass for a reason unrelated to the seam.
admin="$(new_victim "$WORK/sanity")" || broken "could not build the victim repository"
base="$(victim_count "$admin" "$WORK/sanity/wt")"
[ "$base" -eq 40 ] || broken "victim baseline is $base, expected 40"
GIT_DIR="$admin" git --work-tree="$WORK/sanity/wt" rm --cached -q f1 2>/dev/null
moved="$(victim_count "$admin" "$WORK/sanity/wt")"
[ "$moved" -eq 39 ] || broken "the victim's index did not move when a path was removed ($moved); this harness cannot observe a clobber and every arm below would pass vacuously"
ok "H  harness: victim baseline 40, and the index MOVES when touched (39) — a clobber is observable"

# H2. THE DRIVEN FIXTURE MUST ACTUALLY RUN IN A COPY TREE, and this arm exists
# because its absence shipped a fully vacuous battery. A partial copy made
# $SUBJECT exit at its own startup check before reaching `git init`; it then
# clobbered nothing in EVERY world, so all four mutants "survived" against a
# pristine victim and arm A passed for the same reason. Two inert runs compare
# equal. Establish that the mutable copy can reach its git calls at all, in the
# UNMUTATED tree, before reading any mutant's verdict.
mktree "$WORK/canary" || broken "could not copy the tree"
canary_out="$( cd "$WORK/canary" && bash "core/fixtures/$SUBJECT/run.sh" 2>&1 )"
case "$canary_out" in
  *"FIXTURE ERROR"*|*"FIXTURE BROKEN"*)
    broken "the driven fixture $SUBJECT cannot run in a copied tree: $(printf '%s' "$canary_out" | head -1). Every mutant below would survive against an untouched victim and read as a working seam." ;;
esac
ok "H2 driven fixture $SUBJECT runs in the copy tree — mutant verdicts are about the seam, not about a broken copy"

# --- A. THE SHIPPING TREE ---------------------------------------------------
mktree "$WORK/ship" || broken "could not copy the tree"
read -r n_ship repo_ship <<EOF
$(drive "$WORK/ship" "$WORK/v_ship")
EOF
if [ "$n_ship" = "40" ] && [ "$repo_ship" = "yes" ]; then
  ok "A  shipping tree: caller's index intact at 40 AND the victim is still a repository"
else
  fail "A  shipping tree: index=$n_ship repo=$repo_ship — expected 40/yes. The seam is not protecting a directly-run fixture."
fi

# --- MUTANTS ----------------------------------------------------------------
# Each is a COPY, guarded by `cmp -s`: a mutation that did not apply reads exactly
# like a fix that works.
mutate() { # mutate <tree> <file> <sed-free transform via callback file>
  :
}

# (m1) THE SEAM'S BODY IS GONE. The file still exists and is still sourced, so
# every "does it source the preamble" check passes.
mktree "$WORK/m1" || broken "copy failed"
printf '# body removed by mutant m1\n' > "$WORK/m1/core/fixtures/lib/preamble.sh"
cmp -s "$WORK/m1/core/fixtures/lib/preamble.sh" "$SEAM" && broken "m1 did not apply — the mutated seam is byte-identical to the shipping one"
read -r n1 repo1 <<EOF
$(drive "$WORK/m1" "$WORK/v_m1")
EOF
if [ "$n1" != "40" ] || [ "$repo1" != "yes" ]; then
  ok "m1 seam body removed: victim clobbered (index=$n1 repo=$repo1) — arm A can fail"
else
  fail "m1 seam body removed and the victim survived (index=$n1 repo=$repo1). Arm A cannot distinguish a working seam from an empty one."
fi

# (m2) THE SOURCE LINE IS GONE from the driven fixture. The seam is intact and
# every other fixture still sources it.
mktree "$WORK/m2" || broken "copy failed"
grep -v 'preamble\.sh' "$ROOT/core/fixtures/$SUBJECT/run.sh" > "$WORK/m2/core/fixtures/$SUBJECT/run.sh" || broken "m2 rewrite failed"
chmod +x "$WORK/m2/core/fixtures/$SUBJECT/run.sh"
cmp -s "$WORK/m2/core/fixtures/$SUBJECT/run.sh" "$ROOT/core/fixtures/$SUBJECT/run.sh" && broken "m2 did not apply"
read -r n2 repo2 <<EOF
$(drive "$WORK/m2" "$WORK/v_m2")
EOF
if [ "$n2" != "40" ] || [ "$repo2" != "yes" ]; then
  ok "m2 source line removed: victim clobbered (index=$n2 repo=$repo2) — the seam must be SOURCED, not merely present"
else
  fail "m2 source line removed and the victim survived (index=$n2 repo=$repo2). This fixture would pass over a fixture that never sources the seam."
fi

# (m3) THE SCRUB IS PRESENT BUT COMMENTED OUT. This is the sharpest one: the file
# contains the exact correct text, so every grep-shaped check — including the
# receipt this entry replaces — reports the fix present.
mktree "$WORK/m3" || broken "copy failed"
sed_free_comment() { # prefix the unset line with '# ' by line surgery, never sed
  local src="$1" dst="$2"
  while IFS= read -r line; do
    case "$line" in
      unset\ GIT_DIR*) printf '# %s\n' "$line" ;;
      *) printf '%s\n' "$line" ;;
    esac
  done < "$src" > "$dst"
}
sed_free_comment "$SEAM" "$WORK/m3/core/fixtures/lib/preamble.sh" || broken "m3 rewrite failed"
cmp -s "$WORK/m3/core/fixtures/lib/preamble.sh" "$SEAM" && broken "m3 did not apply"
grep -q 'unset GIT_DIR' "$WORK/m3/core/fixtures/lib/preamble.sh" || broken "m3 removed the text instead of commenting it — the mutant's whole point is that the text is still THERE"
read -r n3 repo3 <<EOF
$(drive "$WORK/m3" "$WORK/v_m3")
EOF
if [ "$n3" != "40" ] || [ "$repo3" != "yes" ]; then
  ok "m3 scrub commented out (text still present): victim clobbered (index=$n3 repo=$repo3) — a text anchor cannot see this"
else
  fail "m3 scrub commented out and the victim survived (index=$n3 repo=$repo3). This fixture is keyed on the TEXT, not the behaviour."
fi

# (m4) THE SEAM UNSETS THE WRONG VARIABLE. Structurally a scrub, and it even
# matches a regex looking for `unset` beside a GIT_-shaped name.
mktree "$WORK/m4" || broken "copy failed"
printf '# m4: scrubs a variable git does not use\nunset GIT_DIRECTORY_OF_NOTHING\n' > "$WORK/m4/core/fixtures/lib/preamble.sh"
cmp -s "$WORK/m4/core/fixtures/lib/preamble.sh" "$SEAM" && broken "m4 did not apply"
read -r n4 repo4 <<EOF
$(drive "$WORK/m4" "$WORK/v_m4")
EOF
if [ "$n4" != "40" ] || [ "$repo4" != "yes" ]; then
  ok "m4 wrong variable unset: victim clobbered (index=$n4 repo=$repo4) — the arm is keyed on GIT_DIR specifically"
else
  fail "m4 unset an unrelated variable and the victim survived (index=$n4 repo=$repo4)."
fi

# --- V. THE VALIDATOR, driven rather than read ------------------------------
# The seam is half the remedy; the binding that a new fixture must source it is
# the other half, and a fixture nobody drives is a green light nobody earned.
V="$ROOT/scripts/validate-fixture-git-env.sh"
if [ ! -f "$V" ]; then
  fail "V  scripts/validate-fixture-git-env.sh is absent — the binding half of this remedy is gone"
else
  AI_DLC_PROJECT_ROOT="$ROOT" bash "$V" --max-unscrubbed 0 >/dev/null 2>&1
  v_rc=$?
  if [ "$v_rc" -eq 0 ]; then
    ok "V  validator passes on the shipping tree at ceiling 0"
  else
    fail "V  validator exits $v_rc on the shipping tree at ceiling 0 — a fixture in the population does not source the seam"
  fi
fi

echo
if [ "$FAILS" -eq 0 ]; then
  echo "fixture-git-env-seam: PASS"
  exit 0
fi
echo "fixture-git-env-seam: $FAILS FAILED"
exit 1
