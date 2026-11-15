#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
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
# line EXISTS. It cannot establish that the line executes, so this fixture drives
# a victim instead of reading a file. The same distinction retired
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
# exported the way git exports it.
#
# THE CELLS. A and B are the armed cells (GIT_DIR inherited); U is the same driven fixture with GIT_DIR unset,
# the green twin that proves the driven fixture runs at all (arm URC reads its inner exit).
set -u

# shellcheck source=/dev/null
. "$(cd "$(dirname "$0")/../lib" && pwd)/report.sh" || { echo "FIXTURE ERROR: lib/report.sh not found" >&2; exit 2; }
fail() { bad "$1"; }
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
# "<count-after> <victim-is-a-repo> <core.bare> <user.name> <unarmed rc>".
#
# THE UNARMED BRANCH RECORDS THE INNER FIXTURE'S EXIT (BL-965), and arm URC asserts it is 0. The call discards
# the inner fixture's output, so before this field a runner that never started -- `env` undeclared in tools.decl,
# command-not-found under hermetic-run.sh -- left the victim untouched and scored U INTACT: the twin every mutant
# is compared against was a cell in which nothing ran. U_RUNNER is the command the branch runs through. The armed branch reports `-`.
U_RUNNER=env
drive() { # drive <tree> <victim-root> [fixture] [armed: yes|no] -> "<n> <yes|no> <bare> <name> <rc|->"
  local tree="$1" v="$2" who="${3:-$SUBJECT}" armed="${4:-yes}" admin urc=-
  admin="$(new_victim "$v")" || return 1
  if [ "$armed" = yes ]; then
    ( cd "$tree" && GIT_DIR="$admin" bash "core/fixtures/$who/run.sh" ) >/dev/null 2>&1
  else
    ( cd "$tree" && "$U_RUNNER" -u GIT_DIR bash "core/fixtures/$who/run.sh" ) >/dev/null 2>&1
    urc=$?
  fi
  local n repo=no
  n="$(victim_count "$admin" "$v/wt")"
  [ -d "$v/repo/.git" ] && repo=yes
  printf '%s %s %s %s %s\n' "$n" "$repo" "$(victim_bare "$v")" "$(victim_username "$v")" "$urc"
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

# A copy of the tree, so the driven fixtures run against a tree that is not $ROOT.
#
# IT IS A WHOLE-TREE COPY, AND THE FIRST CUT OF THIS FIXTURE COPIED ONLY THE SEAM
# AND THE DRIVEN FIXTURE. That tree is missing the validators the driven fixture
# resolves at startup, so it exited `FIXTURE ERROR: cannot locate
# validate-audit-anchors.sh` BEFORE reaching any `git init` — and a fixture that
# never runs cannot clobber. All four mutants therefore "survived" against a
# pristine victim, which reads exactly like a seam that works. The tell was that
# arm A passed too: in a partial tree BOTH worlds are inert, so the arm was
# comparing two runs of nothing. Copy the whole tree.
#
# `.claude/worktrees` IS THE CLAUDE CODE HARNESS'S OWN AGENT CHECKOUTS, NOT THIS PROJECT'S
# STATE AND NOT ANY PROJECT'S. It is gitignored under `.claude/*`, it appears in whatever
# number of concurrent sessions happen to be running, and this repo's own code names it only
# to record that `git ls-files` correctly drops it
# (`core/skills/ai-dlc-update/reconcile/ledger-reverify.sh:1992`). Copying it made this
# fixture's cost a function of ambient harness activity: measured on one tree, 34 agent
# checkouts, 871M of a 1.0G copy, 15x the file count, 8 copies per run -- ~10s each against
# ~0s with it excluded, three interleaved reps, sides asserted to differ first.
#
# IT ALSO RACED. `tar` walks those directories while another session is deleting one, which
# is the ONLY reason the breakage below was ever observed rather than shipping silently.
# The exclusion is narrow ON PURPOSE: `.claude/rules/**` is un-ignored by negation and is
# tracked, so excluding all of `.claude` would drop files this tree legitimately carries.
#
# THE COPY READS NO FILE'S DATA, AND THE COUNT IS THE COPY'S OWN LIST (BL-1117). A byte copy
# plus a second whole-tree `tar` just to count read every file's data twice, a burst the
# sandbox read-set tracer drops reports under. `mktree_clone` walks the tree ONCE with
# `scandir` (no stat per entry), clones each file with APFS clonefile(2), and prints the number
# of entries it walked; that number is the source count. Where clonefile is unavailable
# (another volume, a non-APFS filesystem, a refused clone) its first clone fails and it exits 3, the partial destination
# is removed, the tar copy runs instead, and the source count is a metadata-only `find` over
# the same three prunes. The path taken is printed, so a trace of the fallback says so.
mktree_clone() { # mktree_clone <src> <dest> -- prints the entries cloned; rc 3 = no clonefile
  python3 -I -c '
import ctypes, os, sys
src, dst = sys.argv[1], sys.argv[2]
try:
    libc = ctypes.CDLL("libc.dylib", use_errno=True)
    libc.clonefile.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_uint32]
except (OSError, AttributeError):
    sys.exit(3)
prune = {".git", "node_modules", os.path.join(".claude", "worktrees")}
n = cloned = 0
def walk(rel):
    global n, cloned
    with os.scandir(os.path.join(src, rel)) as it:
        for e in it:
            r = os.path.join(rel, e.name) if rel else e.name
            if r in prune:
                continue
            t = os.path.join(dst, r)
            if e.is_symlink():
                os.symlink(os.readlink(e.path), t)
            elif e.is_dir(follow_symlinks=False):
                os.mkdir(t)
                walk(r)
            elif libc.clonefile(e.path.encode(), t.encode(), 1) != 0:
                err = ctypes.get_errno()
                if cloned == 0:  # the first clone failed: no clone here at all
                    sys.exit(3)
                raise OSError(err, "clonefile failed: " + r)
            else:
                cloned += 1
            n += 1
walk("")
print(n)
' "$1" "$2"
}
mktree() { # mktree <dest>
  local dest="$1" src_n dst_n rc
  rm -rf "$dest"
  # `git archive HEAD` would miss the uncommitted seam on the branch that adds it.
  # Copy the working tree, excluding .git so the copy is not itself a repository.
  mkdir -p "$dest" || return 1
  src_n="$(mktree_clone "$ROOT" "$dest")"; rc=$?
  if [ "$rc" -eq 3 ]; then
    echo "  copy: tar (clonefile unavailable)"
    rm -rf "$dest" && mkdir -p "$dest" || return 1
    ( cd "$ROOT" && tar cf - --exclude='./.git' --exclude='./node_modules' --exclude='./.claude/worktrees' . ) \
      | ( cd "$dest" && tar xf - ) || return 1
    src_n="$( ( cd "$ROOT" && find . -mindepth 1 \( -path ./.git -o -path ./node_modules -o -path ./.claude/worktrees \) -prune -o -print 2>/dev/null ) | grep -c .)" || src_n=0
  elif [ "$rc" -ne 0 ]; then
    return 1
  else
    echo "  copy: clonefile"
  fi
  # THE TAR PIPE'S `||` READS THE *READER* TAR'S STATUS AND NOTHING ELSE. There is no `pipefail`
  # in this fixture or in `core/fixtures/lib/preamble.sh` (`set -u` at the top of this file is
  # the only `set` line), so a WRITER that fails mid-walk -- a vanishing directory, an
  # unreadable file -- exits non-zero into a reader that exits 0, and the pipeline reports 0.
  # Constructed and measured: a writer failing on a missing member exits 1 alone and 0 through
  # the pipe, landing 50 of 51 files. The two `[ -f ]` probes below pass on that tree, because
  # they name two files out of thousands.
  #
  # THAT IS THE EXACT STATE THE HEADER ABOVE SAYS IS UNDETECTABLE: a partial tree makes the
  # driven subject bail at its own startup check, every mutant "survives" against an untouched
  # victim, and the unmutated arm passes too because two inert runs compare equal. So the copy
  # asserts its own COMPLETENESS rather than the presence of two names, on either path, and it
  # fails CLOSED: any shortfall returns 1, which `broken` turns into FIXTURE BROKEN. Both counts
  # exclude the root entry (`-mindepth 1`; the clone walk never yields its own root).
  dst_n="$( ( cd "$dest" && find . -mindepth 1 2>/dev/null ) | grep -c .)" || dst_n=0
  # A zero on either side is a broken measurement, never a clean one: it would make the
  # comparison below pass by comparing two nothings, which is this fixture's own defect class.
  [ "$src_n" -gt 0 ] && [ "$dst_n" -gt 0 ] || return 1
  [ "$dst_n" -ge "$src_n" ] || {
    printf '    copy is SHORT: %s entries landed of %s in the stream\n' "$dst_n" "$src_n" >&2
    return 1
  }
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
# ONE COPY OF THE TREE SERVES EVERY ARM: the canary and arm A read the same bytes, driven unarmed and armed.
TREE="$WORK/tree"
mktree "$TREE" || broken "could not copy the tree"
SUBJECT_C="setup-config-drift"
canary_out="$( cd "$TREE" && bash "core/fixtures/$SUBJECT/run.sh" 2>&1 )"
case "$canary_out" in
  *"FIXTURE ERROR"*|*"FIXTURE BROKEN"*)
    broken "the driven fixture $SUBJECT cannot run in a copied tree: $(printf '%s' "$canary_out" | head -1). Every mutant below would survive against an untouched victim and read as a working seam." ;;
esac
ok "H2 driven fixture $SUBJECT runs in the copy tree — verdicts are about the seam, not about a broken copy"

# --- A. THE SHIPPING TREE, ON THREE CELLS ------------------------------------
# A cell is one driven fixture in the shared tree against a fresh victim:
#   A  $SUBJECT   with GIT_DIR armed at the victim (the arm the seam exists for)
#   B  $SUBJECT_C with GIT_DIR armed (the `git -C` form, init in its seed.sh)
#   U  $SUBJECT   with GIT_DIR UNSET: nothing is inherited, so nothing can reach the victim through the seam.
cell() { # <A|B|U> -> VERD (INTACT|WRECKED) and DET ("<n> <repo> <bare> <name> <rc|->")
  local who="$SUBJECT" armed=yes
  case "$1" in B) who="$SUBJECT_C" ;; U) armed=no ;; esac
  DET="$(drive "$TREE" "$WORK/v_cell" "$who" "$armed")"
  # shellcheck disable=SC2086
  if victim_intact $DET; then VERD=INTACT; else VERD=WRECKED; fi
  # URC, per U cell: the inner fixture RAN and passed. A U cell whose runner never started is INTACT for that reason alone.
  if [ "$armed" = no ]; then
    u_cells=$((u_cells + 1)); U_RC="$(printf '%s\n' "$DET" | awk '{ print $5 }')"
    if urc_ran "$U_RC"; then u_rc0=$((u_rc0 + 1)); else fail "URC U cell $u_cells: the unarmed $who exited $U_RC ($DET) -- the twin did not run, so its INTACT is not a measurement"; fi
  fi
}
u_cells=0; u_rc0=0
# The predicate URC reads.
urc_ran() { [ "$1" = 0 ]; }

if [ ! -f "$ROOT/core/fixtures/$SUBJECT_C/run.sh" ]; then
  broken "driven fixture $SUBJECT_C is absent -- the 'git -C' form has no subject in this battery"
fi
cell A; SV_A="$(printf '%s' "$VERD")"; DET_A="$DET"
if [ "$SV_A" = INTACT ]; then
  ok "A  shipping tree: index 40, victim still a repository, core.bare not true, user.name still the sentinel"
else
  fail "A  shipping tree: ($DET_A) — expected 40/yes/not-true/$VICTIM_SENTINEL. The seam is not protecting a directly-run fixture."
fi
# B1. SEAM INTACT on the `git -C` form (its init is in a seed.sh the run.sh never makes; the seam reaches it by inheritance).
cell B; SV_B="$(printf '%s' "$VERD")"; DET_B="$DET"
if [ "$SV_B" = INTACT ]; then
  ok "B1 $SUBJECT_C (git -C form, init in its seed.sh) with the seam: index 40, repo yes, bare not true, sentinel intact"
else
  fail "B1 $SUBJECT_C with the seam intact still moved the victim ($DET_B). The seam does not reach an init the run.sh never makes."
fi
cell U; SV_U="$(printf '%s' "$VERD")"; DET_U="$DET"
if [ "$SV_U" = INTACT ]; then
  ok "U  shipping tree, GIT_DIR unset: victim untouched on all four channels"
else
  fail "U  with GIT_DIR unset the victim still moved ($DET_U): the twin cell is not green"
fi

# URC: the one unarmed U cell ran its inner fixture to rc 0. A nonzero cell has already failed in cell(), by name.
if [ "$u_cells" = 1 ] && [ "$u_rc0" = 1 ]; then
  ok "URC this run drove $u_cells unarmed U cell and the inner $SUBJECT exited 0 in it -- the twin is a run, not an absence"
else
  fail "URC this run drove $u_cells U cell(s) (want 1), $u_rc0 of them at rc 0 (want 1)"
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
# THE TWO-HOP SHAPE (BL-988, review-shard-merge): run.sh SOURCES lib.sh, and lib.sh runs a sibling that inits. No
# arm above can seed it -- each puts the init in run.sh or in a sibling run.sh itself invokes.
mk_twohop_fixture() { # mk_twohop_fixture <root> <name> <seam:above|below>
  local r="$1"
  local n="$2"
  local where="$3"
  local d="$r/core/fixtures/$n"
  mkdir -p "$d" || return 1
  {
    printf '#!/usr/bin/env bash\n'
    [ "$where" = above ] && printf '. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"\n'
    printf '. "$(dirname "$0")/lib.sh"\n'
    [ "$where" = below ] && printf '. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"\n'
    printf 'exit 0\n'
  } > "$d/run.sh" || return 1
  printf '#!/usr/bin/env bash\nbash "$(dirname "$0")/receipt-x.sh" "$(mktemp -d)"\n' > "$d/lib.sh" || return 1
  printf '#!/usr/bin/env bash\ngit -C "$1" init -q\n' > "$d/receipt-x.sh" || return 1
  chmod +x "$d/run.sh" "$d/lib.sh" "$d/receipt-x.sh"
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
  mk_twohop_fixture "$r" "offender-seam-below-twohop" below || return 1   # seam after the sourcing line -> REPORTED
  mk_twohop_fixture "$r" "acquitted-seam-above-twohop" above || return 1  # seam before it                -> acquitted
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

  # W10/W11. THE TWO-HOP PAIR (BL-988). run.sh sources lib.sh, and lib.sh runs the sibling that inits: the site is the
  # sourcing line, so a seam BELOW it is REPORTED for its position, and a seam ABOVE it is acquitted.
  th_row="$(printf '%s\n' "$w_out" | grep -F 'offender-seam-below-twohop')" || th_row=""
  case "$th_row" in
    *"(seam-sourced-below-first-init)"*) ok "W10 a run.sh sourcing lib.sh, which runs the sibling that inits, with the seam BELOW the sourcing line is REPORTED for its position -- the second hop places the site" ;;
    *) fail "W10 the two-hop offender's row is '${th_row:-<none>}', not (seam-sourced-below-first-init): the second hop did not place the init site at run.sh's sourcing line." ;;
  esac
  # W11 is asserted POSITIVELY, on the count line: the validator prints no per-member verdict, so the acquittal is
  # read as the unscrubbed count equalling the number of offender-* trees this probe built (each one reported, W1-W10),
  # beside the twin's name being absent. An absence alone passes for a run that never judged the twin at all.
  n_off=0; for _o in "$Wp"/core/fixtures/offender-*/run.sh; do [ -f "$_o" ] && n_off=$((n_off + 1)); done
  case "$w_out" in
    *"acquitted-seam-above-twohop"*) fail "W11 the two-hop shape with the seam ABOVE its sourcing line was REPORTED -- the hop moved the site earlier than the program does, or left it unresolved." ;;
    *"validate-fixture-git-env: ${n_off} of "*)
      ok "W11 the same two-hop shape with the seam ABOVE the sourcing line stays acquitted: the unscrubbed count is exactly the ${n_off} offender trees, and it is not among them -- W10 discriminates on position, not on the shape" ;;
    *) fail "W11 the unscrubbed count is not the ${n_off} offender trees this probe built: $(printf '%s\n' "$w_out" | grep -F 'fixture run.sh build' | head -1)" ;;
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
  echo "HERMETIC-CONSUMED scripts/validate-fixture-git-env.sh"
  AI_DLC_PROJECT_ROOT="$ROOT" bash "$V" --max-unscrubbed 0 >/dev/null 2>&1
  v_rc=$?
  if [ "$v_rc" -eq 0 ]; then
    ok "V  validator passes on the shipping tree at ceiling 0"
  else
    fail "V  validator exits $v_rc on the shipping tree at ceiling 0 — a fixture in the population does not source the seam"
  fi
fi

echo
report_end fixture-git-env-seam
