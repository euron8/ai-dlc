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
#
# THE VICTIM CARRIES A SENTINEL user.name, AND THE INDEX IS NOT THE ONLY CHANNEL.
# Measured across the 27 fixtures whose `git ... init` form the validator's first
# grammar could not spell: 26 clobbered, but THREE of them -- consumer-suite-pool,
# suite-dispatch-order, layer-anchor-declaration -- left the index at 40 and
# wrecked the victim through CONFIG alone, setting `core.bare=true` and rewriting
# `user.name`. Afterwards `git status` in that victim answers `fatal: this
# operation must be run in a work tree`. An index-count guard scores those three as
# INTACT, so a verdict reading only the count would have reported a seam working on
# a victim it had destroyed. The verdict below is the triple (count, bare,
# user.name) and every arm asserts all three.
VICTIM_SENTINEL="VICTIM_SENTINEL"
new_victim() { # new_victim <dir> -> echoes the worktree admin dir
  local v="$1"
  rm -rf "$v"
  mkdir -p "$v/repo" || return 1
  (
    cd "$v/repo" || exit 1
    git init -q . || exit 1
    git config user.email f@x; git config user.name "$VICTIM_SENTINEL"
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
# Read the config channel from the victim's OWN config file rather than by running
# git inside it: once `core.bare` is true, a git command run there can refuse
# outright, and a refusal's empty output would read as "unset" -- which is the
# value an intact victim also gives. The file is the only reading both worlds can
# produce.
victim_bare() { # victim_bare <victim-root>
  local out
  out="$(git config -f "$1/repo/.git/config" --get core.bare 2>/dev/null)" || out=""
  printf '%s\n' "${out:-unset}"
}
victim_username() { # victim_username <victim-root>
  local out
  out="$(git config -f "$1/repo/.git/config" --get user.name 2>/dev/null)" || out=""
  printf '%s\n' "${out:-none}"
}

# --- the harness ------------------------------------------------------------
# Run the driven fixture from TREE, with GIT_DIR armed at the victim, and report
# "<count-after> <victim-is-a-repo> <core.bare> <user.name>".
drive() { # drive <tree> <victim-root> [fixture] -> "<n> <yes|no> <bare> <name>"
  local tree="$1" v="$2" who="${3:-$SUBJECT}" admin
  admin="$(new_victim "$v")" || return 1
  ( cd "$tree" && GIT_DIR="$admin" bash "core/fixtures/$who/run.sh" ) >/dev/null 2>&1
  local n repo=no
  n="$(victim_count "$admin" "$v/wt")"
  [ -d "$v/repo/.git" ] && repo=yes
  printf '%s %s %s %s\n' "$n" "$repo" "$(victim_bare "$v")" "$(victim_username "$v")"
}

# One predicate for "the victim came through untouched", so no arm can assert a
# subset of the triple by accident. `unset` is the value an intact victim's
# core.bare reads as -- `git init` writes `false` into a non-bare repository's
# config, and both readings are intact; what a clobber produces is `true`.
victim_intact() { # victim_intact <n> <repo> <bare> <name>
  [ "$1" = "40" ] || return 1
  [ "$2" = "yes" ] || return 1
  [ "$3" != "true" ] || return 1
  [ "$4" = "$VICTIM_SENTINEL" ] || return 1
  return 0
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

# H1b. THE CONFIG CHANNEL MUST BE OBSERVABLE TOO, and it is asserted in both
# directions for the same reason the index is. Three of the 27 fixtures that
# motivated this channel left the index at 40 and wrecked the victim through
# config alone; an arm reading a value that never moves would report those three
# INTACT forever, and nothing about it would say so.
s_bare="$(victim_bare "$WORK/sanity")"; s_name="$(victim_username "$WORK/sanity")"
[ "$s_bare" != "true" ] || broken "a fresh victim already reads core.bare=true; the bare channel cannot discriminate and every arm below would report a clobber"
[ "$s_name" = "$VICTIM_SENTINEL" ] || broken "a fresh victim's user.name is '$s_name', not the sentinel; the name channel is not reading the victim's own config"
git config -f "$WORK/sanity/repo/.git/config" core.bare true 2>/dev/null
git config -f "$WORK/sanity/repo/.git/config" user.name WRECKED 2>/dev/null
[ "$(victim_bare "$WORK/sanity")" = "true" ] || broken "core.bare was set to true and the reader still does not see it; this channel cannot observe the config-only wreck"
[ "$(victim_username "$WORK/sanity")" = "WRECKED" ] || broken "user.name was rewritten and the reader still returns the sentinel; this channel cannot observe the config-only wreck"
ok "H1b harness: core.bare reads not-true and user.name reads the sentinel on a fresh victim, and BOTH move when written — the config-only wreck is observable"

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
read -r n_ship repo_ship bare_ship name_ship <<EOF
$(drive "$WORK/ship" "$WORK/v_ship")
EOF
if victim_intact "$n_ship" "$repo_ship" "$bare_ship" "$name_ship"; then
  ok "A  shipping tree: index 40, victim still a repository, core.bare not true, user.name still the sentinel"
else
  fail "A  shipping tree: index=$n_ship repo=$repo_ship bare=$bare_ship name=$name_ship — expected 40/yes/not-true/$VICTIM_SENTINEL. The seam is not protecting a directly-run fixture."
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
read -r n1 repo1 bare1 name1 <<EOF
$(drive "$WORK/m1" "$WORK/v_m1")
EOF
if ! victim_intact "$n1" "$repo1" "$bare1" "$name1"; then
  ok "m1 seam body removed: victim clobbered (index=$n1 repo=$repo1 bare=$bare1 name=$name1) — arm A can fail"
else
  fail "m1 seam body removed and the victim survived (index=$n1 repo=$repo1 bare=$bare1 name=$name1). Arm A cannot distinguish a working seam from an empty one."
fi

# (m2) THE SOURCE LINE IS GONE from the driven fixture. The seam is intact and
# every other fixture still sources it.
mktree "$WORK/m2" || broken "copy failed"
grep -v 'preamble\.sh' "$ROOT/core/fixtures/$SUBJECT/run.sh" > "$WORK/m2/core/fixtures/$SUBJECT/run.sh" || broken "m2 rewrite failed"
chmod +x "$WORK/m2/core/fixtures/$SUBJECT/run.sh"
cmp -s "$WORK/m2/core/fixtures/$SUBJECT/run.sh" "$ROOT/core/fixtures/$SUBJECT/run.sh" && broken "m2 did not apply"
read -r n2 repo2 bare2 name2 <<EOF
$(drive "$WORK/m2" "$WORK/v_m2")
EOF
if ! victim_intact "$n2" "$repo2" "$bare2" "$name2"; then
  ok "m2 source line removed: victim clobbered (index=$n2 repo=$repo2 bare=$bare2 name=$name2) — the seam must be SOURCED, not merely present"
else
  fail "m2 source line removed and the victim survived (index=$n2 repo=$repo2 bare=$bare2 name=$name2). This fixture would pass over a fixture that never sources the seam."
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
read -r n3 repo3 bare3 name3 <<EOF
$(drive "$WORK/m3" "$WORK/v_m3")
EOF
if ! victim_intact "$n3" "$repo3" "$bare3" "$name3"; then
  ok "m3 scrub commented out (text still present): victim clobbered (index=$n3 repo=$repo3 bare=$bare3 name=$name3) — a text anchor cannot see this"
else
  fail "m3 scrub commented out and the victim survived (index=$n3 repo=$repo3 bare=$bare3 name=$name3). This fixture is keyed on the TEXT, not the behaviour."
fi

# (m4) THE SEAM UNSETS THE WRONG VARIABLE. Structurally a scrub, and it even
# matches a regex looking for `unset` beside a GIT_-shaped name.
mktree "$WORK/m4" || broken "copy failed"
printf '# m4: scrubs a variable git does not use\nunset GIT_DIRECTORY_OF_NOTHING\n' > "$WORK/m4/core/fixtures/lib/preamble.sh"
cmp -s "$WORK/m4/core/fixtures/lib/preamble.sh" "$SEAM" && broken "m4 did not apply"
read -r n4 repo4 bare4 name4 <<EOF
$(drive "$WORK/m4" "$WORK/v_m4")
EOF
if ! victim_intact "$n4" "$repo4" "$bare4" "$name4"; then
  ok "m4 wrong variable unset: victim clobbered (index=$n4 repo=$repo4 bare=$bare4 name=$name4) — the arm is keyed on GIT_DIR specifically"
else
  fail "m4 unset an unrelated variable and the victim survived (index=$n4 repo=$repo4 bare=$bare4 name=$name4)."
fi

# --- B. THE `git -C` FORM, WHICH THE FIRST GRAMMAR COULD NOT SPELL ----------
# Every arm above drives $SUBJECT, whose init is the LITERAL `git init`. That is
# one input SHAPE, and a battery of one shape agrees with itself: the validator's
# population grammar was keyed on that same literal for as long as this fixture
# has existed, so 27 fixture directories running `git -C "$X" init` or
# `git -c k=v init` sat outside the population AND outside this battery, and both
# read clean over them. This arm drives a member of that set.
#
# THE SUBJECT'S INIT IS IN ITS seed.sh, NOT ITS run.sh, WHICH IS THE POINT. The
# seam goes in run.sh and reaches the seed by INHERITANCE; a fixture whose run.sh
# touches no repository still clobbers through its seed, and only driving it says
# so. Measured on this pair, whole-tree copies, fresh victim each: seam intact,
# index 40 / bare false / sentinel intact at exit 0; seam stripped, index 2 and
# core.bare TRUE, ALSO at exit 0 with no diagnostic.
SUBJECT_C="setup-config-drift"
if [ ! -f "$ROOT/core/fixtures/$SUBJECT_C/run.sh" ]; then
  fail "B  driven fixture $SUBJECT_C is absent — the 'git -C' form has no subject in this battery"
else
  # B1. SEAM INTACT: the victim survives on all four channels.
  mktree "$WORK/cship" || broken "copy failed"
  read -r nc repoc barec namec <<EOF
$(drive "$WORK/cship" "$WORK/v_cship" "$SUBJECT_C")
EOF
  if victim_intact "$nc" "$repoc" "$barec" "$namec"; then
    ok "B1 $SUBJECT_C (git -C form, init in its seed.sh) with the seam: index 40, repo yes, bare not true, sentinel intact"
  else
    fail "B1 $SUBJECT_C with the seam intact still moved the victim (index=$nc repo=$repoc bare=$barec name=$namec). The seam does not reach an init the run.sh never makes."
  fi

  # B2. SEAM STRIPPED: it must clobber. Without this half, B1 passing is
  # consistent with a subject that never reaches a git write at all.
  mktree "$WORK/cstrip" || broken "copy failed"
  grep -v 'preamble\.sh' "$ROOT/core/fixtures/$SUBJECT_C/run.sh" > "$WORK/cstrip/core/fixtures/$SUBJECT_C/run.sh" || broken "B2 rewrite failed"
  chmod +x "$WORK/cstrip/core/fixtures/$SUBJECT_C/run.sh"
  cmp -s "$WORK/cstrip/core/fixtures/$SUBJECT_C/run.sh" "$ROOT/core/fixtures/$SUBJECT_C/run.sh" && broken "B2 did not apply — the stripped run.sh is byte-identical to the shipping one"
  grep -qE '^[[:space:]]*(\.|source)[[:space:]]+.*preamble\.sh' "$WORK/cstrip/core/fixtures/$SUBJECT_C/run.sh" && broken "B2 left a seam-sourcing line behind; the mutant would prove nothing"
  read -r ns repos bares names <<EOF
$(drive "$WORK/cstrip" "$WORK/v_cstrip" "$SUBJECT_C")
EOF
  if ! victim_intact "$ns" "$repos" "$bares" "$names"; then
    ok "B2 $SUBJECT_C with the seam stripped: victim wrecked (index=$ns repo=$repos bare=$bares name=$names) — B1 is a measurement, not a subject that never runs"
  else
    fail "B2 $SUBJECT_C with the seam stripped and the victim survived (index=$ns repo=$repos bare=$bares name=$names). B1 cannot tell a working seam from a fixture that reaches no git write."
  fi
fi

# --- W. THE VALIDATOR'S POPULATION GRAMMAR, driven against a probe tree ------
# Arm V below asserts the validator is GREEN on the shipping tree, which a
# validator whose population excluded every offender also is. This arm asserts it
# can FIRE on the form that motivated the widening, and that the OLD grammar
# cannot — so a revert to the literal `git init` population fails here rather than
# passing quietly.
#
# THE PROBE TREE IS A mktemp, AND ITS ROOT IS PASSED IN. This validator walks up
# from its own directory for a VERSION marker unless AI_DLC_PROJECT_ROOT is set,
# so a probe entered with `cd` alone is discarded and the run answers about the
# DISTRIBUTION. The output is read for a path that could only have come from the
# probe: a green/red verdict alone cannot tell the two trees apart.
Wp="$WORK/probe"
mk_probe_fixture() { # mk_probe_fixture <root> <name> <seam:yes|no> <scrub:none|above|below>
  # One `local` per variable, deliberately. A single `local a="$1" b="$a"` expands
  # every word BEFORE the builtin assigns any of them, so the second reference is
  # unbound and `set -u` aborts the fixture with no verdict.
  local r="$1"
  local n="$2"
  local seam="$3"
  local scrub="$4"
  local f="$r/core/fixtures/$n/run.sh"
  mkdir -p "$r/core/fixtures/$n" || return 1
  {
    printf '#!/usr/bin/env bash\n'
    [ "$seam" = yes ] && printf '. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"\n'
    [ "$scrub" = above ] && printf 'unset GIT_DIR GIT_WORK_TREE\n'
    printf 'd="$(mktemp -d)"\n'
    printf 'git -C "$d" init -q\n'
    [ "$scrub" = below ] && printf 'unset GIT_DIR GIT_WORK_TREE\n'
    printf 'exit 0\n'
  } > "$f" || return 1
  chmod +x "$f"
}
# mk_literal_filler writes the LITERAL `git init` form, which is the one the OLD
# grammar could spell. The fillers exist so the probe carries a population under
# BOTH grammars: the validator refuses below a floor of 10, and a refusal (exit 2)
# is not a finding -- it would make W5's "the old grammar acquits" unreadable,
# because a refusal and an acquittal are different claims that share a verdict
# line. Measured while building this arm: with every probe fixture in the `git -C`
# form, the old-grammar mutant derived a population of 0 and REFUSED, and W1 read
# green off that same exit-2 refusal.
mk_literal_filler() { # mk_literal_filler <root> <name>
  local r="$1"
  local n="$2"
  local f="$r/core/fixtures/$n/run.sh"
  mkdir -p "$r/core/fixtures/$n" || return 1
  {
    printf '#!/usr/bin/env bash\n'
    printf '. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"\n'
    printf 'd="$(mktemp -d)"\n'
    printf 'cd "$d" && git init -q .\n'
    printf 'exit 0\n'
  } > "$f" || return 1
  chmod +x "$f"
}
# THE SEED-CALL SHAPE, WHICH IS THE MAJORITY OF THE REAL POPULATION AND WHICH THE
# PROBE ABOVE CANNOT EXPRESS. 30 of the 69 live members have NO init in their own
# run.sh: the init is in a seed.sh the run.sh invokes, and the scrub reaches it by
# inheritance. A position arm reading run.sh alone finds no init line for those,
# falls through, and acquits a run.sh whose seam sits BELOW its `bash seed.sh`
# call -- which drives a 40-entry victim to 0. Every case above puts the init in
# run.sh, so none of them can seed this.
mk_seedcall_fixture() { # mk_seedcall_fixture <root> <name> <seam:above|below>
  local r="$1"
  local n="$2"
  local where="$3"
  local d="$r/core/fixtures/$n"
  mkdir -p "$d" || return 1
  {
    printf '#!/usr/bin/env bash\n'
    [ "$where" = above ] && printf '. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"\n'
    printf 'd="$(mktemp -d)"\n'
    printf 'bash "$(dirname "$0")/seed.sh" "$d"\n'
    printf 'echo mid\n'
    [ "$where" = below ] && printf '. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"\n'
    printf 'exit 0\n'
  } > "$d/run.sh" || return 1
  # The init lives HERE, never in run.sh -- that is the whole point of the shape.
  {
    printf '#!/usr/bin/env bash\n'
    printf 'git -C "$1" init -q\n'
    printf 'git -C "$1" add -A 2>/dev/null\n'
  } > "$d/seed.sh" || return 1
  chmod +x "$d/run.sh" "$d/seed.sh"
}
build_probe() { # build_probe <root>
  local r="$1"
  rm -rf "$r"; mkdir -p "$r/core/fixtures/lib" "$r/scripts" || return 1
  printf '0.0.0\n' > "$r/VERSION" || return 1
  cp "$SEAM" "$r/core/fixtures/lib/preamble.sh" || return 1
  local i=1
  while [ "$i" -le 12 ]; do mk_literal_filler "$r" "filler$i" || return 1; i=$((i + 1)); done
  mk_probe_fixture "$r" "offender-c-form"   no  none  || return 1  # git -C, no seam  -> REPORTED
  mk_probe_fixture "$r" "acquitted-seam"    yes none  || return 1  # git -C, seam     -> acquitted
  mk_probe_fixture "$r" "offender-scrub-below" no below || return 1 # scrub after init -> REPORTED
  mk_probe_fixture "$r" "acquitted-scrub-above" no above || return 1 # scrub before init -> acquitted
  mk_seedcall_fixture "$r" "offender-seam-below-seedcall" below || return 1  # seam after the call -> REPORTED
  mk_seedcall_fixture "$r" "acquitted-seam-above-seedcall" above || return 1 # seam before it    -> acquitted
  cp "$V_SRC" "$r/scripts/validate-fixture-git-env.sh" || return 1
  chmod +x "$r/scripts/validate-fixture-git-env.sh"
  # THE PROBE MUST BE A GIT REPOSITORY WITH ITS FILES TRACKED. The validator
  # derives its population with `git grep`, which searches TRACKED content only:
  # against a plain directory it returns nothing, the population collapses to 0,
  # and the run REFUSES with exit 2 -- a refusal that reads as a finding to an arm
  # testing only for a non-zero exit. GIT_DIR is already scrubbed here by this
  # fixture's own seam line, which is why `git -C` reaches this directory at all.
  git -C "$r" init -q . >/dev/null 2>&1 || return 1
  git -C "$r" add -A -f >/dev/null 2>&1 || return 1
  return 0
}
V_SRC="$ROOT/scripts/validate-fixture-git-env.sh"
if [ ! -f "$V_SRC" ]; then
  fail "W  scripts/validate-fixture-git-env.sh is absent — the grammar has no subject"
else
  build_probe "$Wp" || broken "could not build the validator probe tree"
  w_out="$(AI_DLC_PROJECT_ROOT="$Wp" bash "$Wp/scripts/validate-fixture-git-env.sh" --max-unscrubbed 0 2>&1)"
  w_rc=$?

  # W0. THE OUTPUT MUST NAME THE PROBE TREE. A validator that resolved its own root
  # answers about the distribution, and its verdict would read identically.
  case "$w_out" in
    *"offender-c-form"*) ok "W0 the run answers about the PROBE tree — its output names core/fixtures/offender-c-form, a path that exists in no other tree" ;;
    *) fail "W0 the validator's output never names the probe's own fixture; it resolved some other root and every verdict below is about the wrong tree. Output: $(printf '%s' "$w_out" | head -2)" ;;
  esac

  # W1. THE `git -C` OFFENDER IS REPORTED, and the run is non-zero at ceiling 0.
  #
  # EXIT 1 SPECIFICALLY, NOT MERELY NON-ZERO. This validator answers 2 when it
  # cannot establish its own population -- a REFUSAL, which is the opposite claim
  # from a finding and shares its "non-zero" shape. Measured while building this
  # arm: a probe tree that was not a git repository gave `git grep` nothing, the
  # population collapsed to 0, the run refused with exit 2, and W1 scored that as a
  # kill. The offender must also be NAMED, so the exit is joined to the subject.
  case "$w_out" in
    *"offender-c-form"*)
      if [ "$w_rc" -eq 1 ]; then
        ok "W1 a fixture whose only init is \`git -C \"\$d\" init -q\`, with no seam, is REPORTED and fails the ceiling — exit 1"
      else
        fail "W1 the offender is named but the run exits $w_rc, not 1. Exit 2 is a REFUSAL over a collapsed population, not a finding."
      fi ;;
    *)
      fail "W1 the validator exits $w_rc without naming the seam-less \`git -C\` fixture: the population grammar cannot spell its own subject." ;;
  esac

  # W2. THE SEAM-CARRYING TWIN IS ACQUITTED. Without this half, W1 passing is
  # consistent with an arm that reports every fixture it sees.
  case "$w_out" in
    *"acquitted-seam"*) fail "W2 the seam-carrying \`git -C\` fixture was REPORTED too — this arm flags everything and discriminates nothing." ;;
    *) ok "W2 the same fixture WITH the seam line is acquitted — the arm reads the seam, it does not report the whole population" ;;
  esac

  # W3/W4. THE POSITION PAIR. A scrub BELOW the first init scrubs nothing; a scrub
  # ABOVE it is a real fix and must stay acquitted. Measured live before this arm
  # existed: self-update-fixture-log scrubs at run.sh:694 with its first init at
  # run.sh:88, self-update-gate at 819 against 159, and both were acquitted by the
  # whole-file exemption while clobbering the victim at exit 0.
  case "$w_out" in
    *"offender-scrub-below"*) ok "W3 an inline \`unset GIT_DIR\` BELOW the first init is REPORTED — the exemption is keyed on position, not on the file containing the text" ;;
    *) fail "W3 a fixture whose scrub sits after its init was acquitted; the inline exemption is position-blind and acquits its own subject." ;;
  esac
  case "$w_out" in
    *"acquitted-scrub-above"*) fail "W4 an inline scrub ABOVE the first init was REPORTED — the position arm is refusing a genuine inline fix." ;;
    *) ok "W4 an inline \`unset GIT_DIR\` ABOVE the first init stays acquitted — the position arm did not swallow the inline-scrub exemption" ;;
  esac

  # W6/W7. THE SEED-CALL PAIR. The init is in a seed.sh the run.sh INVOKES, which
  # is the shape 30 of the 69 live members have and which no arm above can seed --
  # every case above puts its init in run.sh. A position arm reading run.sh alone
  # finds no init line here, falls through, and acquits. Measured on a probe tree
  # before this arm existed: the seam-below-the-seed-call shape takes a 40-entry
  # victim to 0, and its inline-scrub twin does the same.
  case "$w_out" in
    *"offender-seam-below-seedcall"*) ok "W6 a run.sh with NO init of its own, sourcing the seam BELOW its \`bash seed.sh\` call, is REPORTED — the init site is resolved through the directory, not through run.sh alone" ;;
    *) fail "W6 a run.sh whose seam sits after the seed call that inits was acquitted. The position arms read run.sh only, and 30 of the live population have no init there — this is the arm's own subject, one file over." ;;
  esac
  case "$w_out" in
    *"acquitted-seam-above-seedcall"*) fail "W7 the seam-ABOVE-the-seed-call shape was REPORTED — the site resolution moved the line earlier than the program does, and it would flag 30 correct fixtures." ;;
    *) ok "W7 the same shape with the seam ABOVE the seed call stays acquitted — W6 discriminates on position rather than on the shape itself" ;;
  esac

  # W8. THE run.sh-ONLY DERIVATION, RESTORED AS A MUTANT. W6 asserts the seed-call
  # offender is reported; this asserts that the OLD site derivation is what fails
  # to report it, so a revert to reading run.sh alone dies here rather than
  # passing. The mutation neuters the sibling half of init_site_line by making its
  # loop body unreachable, which is the whole of the difference.
  # THE ANCHOR IS MATCHED WITH `grep -F`, NOT WITH A `case` GLOB. The line carries
  # `*`, which a case pattern reads as a wildcard rather than as the character --
  # written as a case arm the mutation silently matched NOTHING, and `bash -n`
  # cannot see that. Asserted unique in the file first, so the mutation cannot
  # quietly edit two lines or none.
  SIB_ANCHOR='  for s in "$dir"/*.sh; do'
  anchor_n="$(grep -cF "$SIB_ANCHOR" "$V_SRC")" || anchor_n=0
  [ "$anchor_n" -eq 1 ] || broken "W8 anchor matches $anchor_n lines in the validator, expected exactly 1 — the mutation would edit the wrong thing or nothing"
  smut="$Wp/scripts/mutant-runsh-only.sh"
  while IFS= read -r line; do
    printf '%s\n' "$line"
    if [ "$line" = "$SIB_ANCHOR" ]; then printf '    continue\n'; fi
  done < "$V_SRC" > "$smut"
  cmp -s "$smut" "$V_SRC" && broken "W8 mutant did not apply — the run.sh-only copy is byte-identical to the shipping validator, so its silence would prove nothing"
  bash -n "$smut" || broken "W8 mutant does not parse"
  chmod +x "$smut"
  smut_out="$(AI_DLC_PROJECT_ROOT="$Wp" bash "$smut" --max-unscrubbed 0 2>&1)"
  smut_rc=$?
  # It must still SEE the run.sh-init offender -- otherwise it is failing for some
  # reason other than the site derivation and W6's attribution is unproven.
  #
  # AND THE KILL IS READ OFF THE REASON, NOT OFF THE OFFENDER'S PRESENCE. With the
  # sibling half dead, the seed-call member's site resolves by NEITHER route, so
  # the refusal branch reports it as `(init-site-unresolved)` -- it is still named,
  # for a completely different reason, and an arm keyed on the NAME scores that as
  # survival. Measured: this arm's first cut read exactly that and failed. The
  # discriminating observable is which suffix the row carries.
  smut_row="$(printf '%s\n' "$smut_out" | grep -F 'offender-seam-below-seedcall')" || smut_row=""
  ship_row="$(printf '%s\n' "$w_out" | grep -F 'offender-seam-below-seedcall')" || ship_row=""
  case "$ship_row" in
    *"(seam-sourced-below-first-init)"*) : ;;
    *) fail "W8 precondition: the SHIPPING run does not report the seed-call offender as (seam-sourced-below-first-init); its row is '${ship_row:-<none>}', so there is no position verdict for the mutant to lose." ;;
  esac
  case "$smut_out" in
    *"offender-c-form"*)
      case "$smut_row" in
        *"(seam-sourced-below-first-init)"*)
          fail "W8 the run.sh-only derivation ALSO reached a POSITION verdict on the seed-call offender (exit $smut_rc). W6 is then not a measurement of the site resolution — something else is doing the work." ;;
        *"(init-site-unresolved)"*)
          ok "W8 with the sibling half dead the seed-call offender loses its POSITION verdict and falls to (init-site-unresolved) — the directory-wide resolution is what makes W6 fire, and the refusal branch is what stops the loss becoming an acquittal" ;;
        "")
          fail "W8 the run.sh-only mutant does not name the seed-call offender at all (exit $smut_rc) — it was ACQUITTED, which is the pre-repair behaviour and means the refusal branch did not fire." ;;
        *)
          fail "W8 the seed-call offender is reported by the mutant with an unexpected reason: '$smut_row'." ;;
      esac ;;
    *)
      fail "W8 the run.sh-only mutant does not report the run.sh-init offender either (exit $smut_rc); it is broken rather than narrowed, so W6's attribution is unproven. Output: $(printf '%s' "$smut_out" | head -2)" ;;
  esac

  # W5. THE OLD GRAMMAR MUST ACQUIT THE PROBE. This is what makes W1 a statement
  # about the WIDENING rather than about the arm beside it: a mutant validator
  # carrying the literal `git init` population, run against the same probe, must
  # see no offender at all. A `cmp -s` guard because a mutation that did not apply
  # reads exactly like a fix that works.
  mut="$Wp/scripts/mutant-old-grammar.sh"
  # Line surgery, never `sed`: the grammar line carries `[`, `(`, `*` and `$`, and
  # an `&` in a sed replacement is the whole match.
  while IFS= read -r line; do
    case "$line" in
      INIT_RE=*) printf "INIT_RE='git init'\n" ;;
      *) printf '%s\n' "$line" ;;
    esac
  done < "$V_SRC" > "$mut"
  cmp -s "$mut" "$V_SRC" && broken "W5 mutant did not apply — the old-grammar copy is byte-identical to the shipping validator, so its acquittal would prove nothing"
  grep -qF "INIT_RE='git init'" "$mut" || broken "W5 mutant does not carry the old literal grammar; the mutation matched nothing"
  chmod +x "$mut"
  mut_out="$(AI_DLC_PROJECT_ROOT="$Wp" bash "$mut" --max-unscrubbed 0 2>&1)"
  mut_rc=$?
  case "$mut_out" in
    *"offender-c-form"*)
      fail "W5 the OLD literal grammar also reported the \`git -C\` offender (exit $mut_rc). W1 is then not a measurement of the widening — something else in the file is doing the work." ;;
    *)
      # Exit 0 and only exit 0. A refusal (2) also fails to name the offender, and
      # "the old grammar could not see it" and "the old grammar could not run" are
      # different claims sharing one silence.
      if [ "$mut_rc" -eq 0 ]; then
        ok "W5 the old literal \`git init\` grammar ACQUITS the same probe at exit 0 — the widened population is what makes W1 fire"
      else
        fail "W5 the old-grammar mutant exits $mut_rc without naming the offender; it is failing for some reason other than the population, so W1's attribution is unproven. Output: $(printf '%s' "$mut_out" | head -2)"
      fi ;;
  esac

  # W9. AN UNRESOLVABLE INIT SITE IS REPORTED, NOT ACQUITTED. A member joins the
  # population by running an init somewhere in its directory, so a site resolving
  # to nothing means run.sh reaches it by a route this reader cannot see, and the
  # position arms cannot judge it. Seeded by a fixture whose seed.sh inits and
  # whose run.sh NEVER invokes it -- the file it names sits in a comment, which is
  # not a call. THIS ARM RUNS LAST AND MUTATES THE PROBE TREE, so every reading
  # above is taken against the unmodified probe.
  ud="$Wp/core/fixtures/unresolved-site"
  mkdir -p "$ud" || broken "W9 could not extend the probe tree"
  printf '#!/usr/bin/env bash\n# this comment names seed.sh and is not a call\necho nothing\n' > "$ud/run.sh"
  printf '#!/usr/bin/env bash\ngit -C "$1" init -q\n' > "$ud/seed.sh"
  chmod +x "$ud/run.sh" "$ud/seed.sh"
  ( cd "$Wp" && git add -A -f ) >/dev/null 2>&1 || broken "W9 could not track the seeded case; git grep would not see it and the arm would pass vacuously"
  u_out="$(AI_DLC_PROJECT_ROOT="$Wp" bash "$Wp/scripts/validate-fixture-git-env.sh" --max-unscrubbed 0 2>&1)"
  case "$u_out" in
    *"unresolved-site/run.sh(init-site-unresolved)"*) ok "W9 a member whose init site resolves by NEITHER route is REPORTED as (init-site-unresolved) — an unreadable file is not acquitted, and a comment naming seed.sh is not a call" ;;
    *"unresolved-site"*) fail "W9 the unresolvable member is reported, but not as (init-site-unresolved) — some other branch fired and the refusal branch is untested." ;;
    *) fail "W9 a member whose init site cannot be resolved was ACQUITTED. The position arms then pass silently over exactly the file nobody can reason about." ;;
  esac
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
