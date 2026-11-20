#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# prepush-worktree-env-scrub — the pre-push hook must SCRUB git's exported
# repository environment out of the parent shell BEFORE it dispatches fixtures,
# and this asserts that it RUNS, not that the line is written down.
#
# THE DEFECT. `git push` issued from a LINKED WORKTREE has git export GIT_DIR into
# the hook's process environment, pointed at that worktree's private
# `.git/worktrees/<name>` directory; a push from the primary checkout exports
# nothing. MEASURED here, by running a real push from a real linked worktree
# against a hook that printed its own environment: exactly one variable arrives,
# `GIT_DIR`, and it names the worktree admin dir.
#
# Every fixture in this suite builds its own isolated sandbox — `mktemp -d`, then
# `git init`, `git add`, `git commit` — and relies on git's upward repository
# DISCOVERY to find that sandbox. Discovery is the branch git takes only when
# GIT_DIR is unset. Inherited unscrubbed, the sandbox sequence is silently
# redirected onto the repository being pushed: MEASURED, the sandbox's own
# `git log` shows the REAL repository's history and the real worktree's HEAD moves
# to the sandbox's commit. The suite corrupts the tree it is testing, and every
# verdict it prints is still `ok`.
#
# WHY THIS IS NOT A TEXT ANCHOR, and the reason this fixture exists at all. The
# receipt this replaces was `grep -qE '^[[:space:]]*unset[[:space:]].*GIT_OBJECT_DIRECTORY'`
# against both hooks. That establishes a line EXISTS. It cannot establish that the
# line executes, that it executes in the PARENT shell, or that it executes BEFORE
# the dispatch — and textual line order is not execution order in a file that
# defines functions at the top and invokes them at the bottom.
#
# WHAT IT DRIVES. The shipping hook itself, run end to end, in a sandbox that is a
# real repository with a real linked worktree, with GIT_DIR exported the way git
# exports it. Nothing here re-implements the hook.
#
# BOTH SUBJECTS, NAMED FROM THIS FIXTURE'S OWN LOCATION. install.sh splits what
# shares a parent in this repo: the hook a consumer runs is `core/git-hooks/pre-push`
# here and `.githooks/pre-push` there, while `.githooks/pre-push` here is the
# distribution's own runner. I66 binds the two runners to be one program, so both
# are exercised where both exist. Neither is reached by walking up from a path the
# other resolver produced (I33). On a consumer only one candidate exists; this
# reports WHICH halves it exercised and fails as FIXTURE BROKEN if it exercised
# none, rather than printing a green line over an absent subject.
#
# CWD-INVARIANCE IS THIS FIXTURE'S OWN, not a property of how the suite drives it.
# `$HERE` is absolutised from `$0` and every subject, sandbox and probe path is
# absolute from there; nothing below reads the process working directory. The
# suite runs this from the repository root; it behaves identically from its own
# directory.
set -uo pipefail

# HERMETICITY, in both of the directions that can lie here.
#
# AI_DLC_* first: the hook reads AI_DLC_FIXTURE_JOBS and AI_DLC_FIXTURE_NO_SKIP, and
# an operator carrying either in their environment would change what the drives below
# actually exercise — a content-key HIT would skip the dispatch entirely and every
# "the repository is untouched" arm would pass for the reason that nothing ran.
#
# GIT_* second, and this one is the defect pointed at its own detector: if the suite
# running this fixture was itself dispatched by an unscrubbed hook, then GIT_DIR is
# already in THIS process and the seeding below would build its sandbox inside the
# real repository. Scrub, then export GIT_DIR deliberately per drive.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

HERE="$(cd "$(dirname "$0")" && pwd)"
. "$HERE/../lib/hook-drive.sh" || { echo "FIXTURE BROKEN: cannot source lib/hook-drive.sh" >&2; exit 2; }

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
broken() {
  printf '  FAIL  %s\n' "$1" >&2
  echo "prepush-worktree-env-scrub: FIXTURE BROKEN" >&2
  exit 2
}
echo "prepush-worktree-env-scrub:"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/prepush-worktree-env-scrub.XXXXXX")" || broken "mktemp failed"
trap 'rm -rf "$WORK"' EXIT

# The subject's fixture dispatch reads a different directory in each layout, so the
# probe has to be planted where THAT hook will look for it. A probe planted in the
# wrong directory is never dispatched, the repository is never touched, and the
# pristine arm passes for a reason that has nothing to do with the scrub.
SUBJ_PATH_1="$HERE/../../../.githooks/pre-push"      # the distribution's own runner
SUBJ_FXDIR_1="core/fixtures"
SUBJ_LABEL_1=".githooks/pre-push"
SUBJ_PATH_2="$HERE/../../git-hooks/pre-push"         # the consumer's, as it sits here
SUBJ_FXDIR_2="tests/fixtures"
SUBJ_LABEL_2="core/git-hooks/pre-push"

# On a CONSUMER the second candidate does not exist and the first one IS the shipped
# consumer hook, installed at `.githooks/pre-push` — which globs `tests/fixtures/`,
# not `core/fixtures/`. Detect the layout from the file rather than assuming it, so
# the probe lands where that copy actually dispatches.
if [ -f "$SUBJ_PATH_1" ] && [ ! -f "$SUBJ_PATH_2" ]; then
  SUBJ_FXDIR_1="tests/fixtures"
  SUBJ_LABEL_1=".githooks/pre-push (installed consumer hook)"
fi

# ------------------------------------------------------------------ the harness --
# seed_and_drive <tag> <hook-source> <fixture-dir> <variant>
#
# Builds a repository with a LINKED WORKTREE, plants the hook copy and one probe
# fixture in that worktree, and runs the hook from inside it with GIT_DIR exported
# exactly as git exports it to a pre-push hook launched from a linked worktree.
#
# Leaves four files in "$WORK/<tag>":
#   head.before   the worktree's HEAD before the drive
#   head.after    the worktree's HEAD after it
#   subj.after    the subject line of the worktree's HEAD commit after it
#   probe.ran     present iff the probe fixture was actually dispatched
#   probe.gitdir  what the dispatched worker saw in GIT_DIR
seed_and_drive() {
  local tag="$1" hooksrc="$2" fxdir="$3" variant="$4"
  local sb="$WORK/$tag" gd hookfile

  mkdir -p "$sb" || return 1
  git init -q "$sb/main" >/dev/null 2>&1 || return 1
  git -C "$sb/main" config user.email f@x >/dev/null 2>&1
  git -C "$sb/main" config user.name  f   >/dev/null 2>&1
  git -C "$sb/main" commit -q --allow-empty -m base >/dev/null 2>&1 || return 1
  git -C "$sb/main" worktree add -q "$sb/wt" -b probe-branch >/dev/null 2>&1 || return 1
  gd="$sb/main/.git/worktrees/wt"
  [ -d "$gd" ] || return 1

  mkdir -p "$sb/wt/.githooks" "$sb/wt/$fxdir/aaa-probe" "$sb/wt/scripts" || return 1
  hookfile="$sb/wt/.githooks/pre-push"
  # THE WORLD CARRIES WHAT A REAL TREE CARRIES: a scripts/install.sh, here a stub that lays one shipping fixture
  # into its target. The distribution hook builds its consumer-layout tree with it at pool depth 0, the depth the
  # drive below runs at, and without one that build fails closed before any dispatch: removing the stub reads
  # FIXTURE BROKEN.
  printf '%s\n' '#!/usr/bin/env bash' \
    'mkdir -p "$1/tests/fixtures/stub-shipping" && printf "#!/usr/bin/env bash\nexit 0\n" > "$1/tests/fixtures/stub-shipping/run.sh"' \
    > "$sb/wt/scripts/install.sh" || return 1

  case "$variant" in
    pristine)
      cp "$hooksrc" "$hookfile" || return 1
      ;;
    *) return 1 ;;
  esac
  chmod +x "$hookfile"

  # The probe: a fixture-shaped sandbox sequence, and nothing more. It exits 0 in
  # both worlds, so the suite's own verdict is not the signal — where the commit
  # LANDED is.
  cat > "$sb/wt/$fxdir/aaa-probe/run.sh" <<EOF
#!/usr/bin/env bash
printf 'ran\n' > "$sb/probe.ran"
printf '%s\n' "\${GIT_DIR:-<unset>}" > "$sb/probe.gitdir"
s="\$(mktemp -d)"
git -C "\$s" init -q . >/dev/null 2>&1
printf 'x\n' > "\$s/f"
git -C "\$s" add f >/dev/null 2>&1
git -C "\$s" -c user.email=p@x -c user.name=p commit -q -m PROBE-SANDBOX-COMMIT >/dev/null 2>&1
exit 0
EOF

  git --git-dir="$gd" rev-parse HEAD > "$sb/head.before" 2>/dev/null || return 1

  # `</dev/null` because the consumer hook drains the ref protocol from stdin and
  # would otherwise inherit whatever the suite handed this fixture.
  # Every validator step fails in this sandbox for want of scripts; the hook still dispatches aaa-probe (BL-1048).
  # The world's own verdict store: a consumer-layout pass the drive records lands here, never in the caller's store.
  # The drive is a PUSH, so it runs at a push's pool depth 0 whatever depth this fixture runs at (plain, or in the
  # gate's pool at depth 1): one world, one verdict and one invocation count either way.
  ( cd "$sb/wt" && env -u PREPUSH_POOL_DEPTH FXCELL="e2e-$tag" GIT_DIR="$gd" AI_DLC_FIXTURE_NO_SKIP=1 AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_VERDICT_STORE="$sb/vs" \
      bash "$hookfile" ) </dev/null > "$sb/hook.log" 2>&1
  printf '%s\n' "$?" > "$sb/hook.rc"

  git --git-dir="$gd" rev-parse HEAD > "$sb/head.after" 2>/dev/null || : > "$sb/head.after"
  git --git-dir="$gd" log -1 --format=%s > "$sb/subj.after" 2>/dev/null || : > "$sb/subj.after"
  return 0
}

# corrupted <tag> — did the probe's sandbox commit land on the REAL repository?
# Two independently derived readings of the same event, and they must agree: the
# worktree HEAD moved, and the commit it now names is the probe's. A HEAD that
# moved with a different subject is not this defect and is not scored as one.
corrupted() {
  local sb="$WORK/$1" before after subj
  before="$(cat "$sb/head.before" 2>/dev/null)"
  after="$(cat "$sb/head.after" 2>/dev/null)"
  subj="$(cat "$sb/subj.after" 2>/dev/null)"
  if [ "$before" != "$after" ] && [ "$subj" = "PROBE-SANDBOX-COMMIT" ]; then return 0; fi
  return 1
}

probe_ran() { [ -f "$WORK/$1/probe.ran" ]; }

# ------------------------------------------------------------------ the battery --
exercised=0
resolved_paths=""

run_subject() { # run_subject <slug> <hook-source> <fixture-dir> <label>
  local slug="$1" hooksrc="$2" fxdir="$3" label="$4"

  case "$hooksrc" in
    /*) ;;
    *) broken "$label: subject path is not absolute ($hooksrc) — this fixture would read a different file from a different cwd" ;;
  esac

  # PRINT THE FILE THIS RUN ACTUALLY RESOLVED. The resolved path is printed, the SAME
  # path is what `seed_and_drive` copies into the sandbox, and the sandbox copy is what
  # `bash` is handed by absolute path.
  printf '  ..    %s: RESOLVED %s\n' "$label" "$hooksrc"

  # AND THE SAME SUBJECT MUST NOT BE DRIVEN TWICE. Two candidates that resolved to
  # one file would print two sets of greens over one hook and leave the other
  # unguarded — a coverage claim of 2 backed by 1.
  case "$resolved_paths" in
    *"|$hooksrc|"*) broken "$label: $hooksrc was already exercised by an earlier subject — the two layout candidates resolved to the SAME file, so one hook is being tested twice and the other not at all" ;;
  esac
  resolved_paths="$resolved_paths|$hooksrc|"

  seed_and_drive "$slug-pristine" "$hooksrc" "$fxdir" pristine \
    || broken "$label: could not seed or drive the shipped hook"

  # THE CONTROL, AND IT COMES FIRST. The pristine arm below is absence-shaped: it
  # claims the repository was not touched. A probe that was never dispatched leaves
  # exactly the same evidence, so establish the dispatch happened before reading the
  # absence.
  if probe_ran "$slug-pristine"; then
    ok "$label: the probe fixture WAS dispatched by the shipped hook (the absence arm below has a subject)"
  else
    broken "$label: the shipped hook never dispatched the probe fixture — every arm below would pass over a hook that ran nothing. Hook log: $WORK/$slug-pristine/hook.log"
  fi

  # A1. With the scrub present, the dispatched worker sees no GIT_DIR at all. This is
  # the mechanism; the arm after it is the consequence.
  if [ "$(cat "$WORK/$slug-pristine/probe.gitdir" 2>/dev/null)" = "<unset>" ]; then
    ok "$label: GIT_DIR is UNSET in the dispatched worker's environment"
  else
    bad "$label: the dispatched worker inherited GIT_DIR=$(cat "$WORK/$slug-pristine/probe.gitdir" 2>/dev/null) — the scrub did not run before the dispatch"
  fi

  # A2. The consequence: the real repository is exactly as the drive found it.
  if corrupted "$slug-pristine"; then
    bad "$label: the probe's sandbox commit landed on the REAL repository under the shipped hook"
  else
    ok "$label: the real repository is untouched — HEAD $(cut -c1-8 < "$WORK/$slug-pristine/head.before") still at subject '$(cat "$WORK/$slug-pristine/subj.after")'"
  fi

  exercised=$((exercised + 1))
}

if [ -f "$SUBJ_PATH_1" ]; then
  echo "HERMETIC-CONSUMED .githooks/pre-push"
  run_subject s1 "$(cd "$(dirname "$SUBJ_PATH_1")" && pwd -P)/$(basename "$SUBJ_PATH_1")" \
    "$SUBJ_FXDIR_1" "$SUBJ_LABEL_1"
else
  printf '  ..    %s absent in this layout — not exercised\n' "$SUBJ_LABEL_1"
fi

if [ -f "$SUBJ_PATH_2" ]; then
  echo "HERMETIC-CONSUMED core/git-hooks/pre-push"
  run_subject s2 "$(cd "$(dirname "$SUBJ_PATH_2")" && pwd -P)/$(basename "$SUBJ_PATH_2")" \
    "$SUBJ_FXDIR_2" "$SUBJ_LABEL_2"
else
  printf '  ..    %s absent in this layout — not exercised\n' "$SUBJ_LABEL_2"
fi

# ------------------------------------------------- BL-1048: a red step records --
# A red step above the suite must not stop it: the pool still runs, every pass lands in the verdict store, and the
# push stays BLOCKED. The world is a plain repository holding the distribution hook, the REAL core/scripts/
# hermetic-run.sh (the store's only writer) and core-paths.sh beside it, one declared fixture aaa-rec reading
# lib/x.txt, and a scripts/validate-fixture-inprocess.sh seeded red. Both drives run with AI_DLC_PRESUITE_SKIP=1
# (every pre-suite validator is absent here), at PREPUSH_POOL_DEPTH=1 (no consumer-layout tree), into a world-local
# store. Drive 1: the seeded red. Then aaa-rec's key record goes, so only the store can skip it, and the red is
# fixed and committed. Drive 2: the re-push. Cells, read off one finished receipt <tag>:
#   rec      drive 1 ran aaa-rec ok and left exactly one store entry       (RED: the pool did not run or record)
#   skip     drive 2 skipped aaa-rec on that entry and did not re-run it    (RED: the pass was not reused)
#   blocked  drive 1 exited non-zero and said BLOCKED                      (RED: the red did not hold the push)
# On a consumer the receipt is not run: the consumer hook has no step above its suite that this could stop.
RC_HR="$HERE/../../scripts/hermetic-run.sh"
RC_CP="$HERE/../../scripts/core-paths.sh"
rcpt_drive() { # <tag> <hook-source> <pristine>
  local w="$WORK/$1/w" h rt
  mkdir -p "$w/.githooks" "$w/core/scripts" "$w/core/fixtures/aaa-rec" "$w/lib" "$w/scripts" || return 1
  h="$w/.githooks/pre-push"
  case "$3" in
    pristine) cp "$2" "$h" || return 1 ;;
    *) return 1 ;;
  esac
  cp "$RC_HR" "$RC_CP" "$w/core/scripts/" || return 1
  printf 'x\n' > "$w/lib/x.txt"
  printf '#!/usr/bin/env bash\n[ -f lib/x.txt ] || exit 1\nexit 0\n' > "$w/core/fixtures/aaa-rec/run.sh"
  printf 'lib/x.txt\n' > "$w/core/fixtures/aaa-rec/inputs.decl"
  printf '#!/usr/bin/env bash\necho seeded red; exit 1\n' > "$w/scripts/validate-fixture-inprocess.sh"
  ( cd "$w" && git init -q . && git add -A && git -c user.email=f@x -c user.name=f -c commit.gpgsign=false commit -qm seed ) \
    > /dev/null 2>&1 || return 1
  rcpt_push "$1" 1
  rt="$(git -C "$w" rev-list --max-parents=0 HEAD)" || return 1
  find "$w.vs/$rt" -type f 2>/dev/null | grep -c . > "$WORK/$1/n1"
  rm -f "$w.vs/fixture-keys/$rt/aaa-rec.key"
  printf '#!/usr/bin/env bash\nexit 0\n' > "$w/scripts/validate-fixture-inprocess.sh"
  ( cd "$w" && git -c user.email=f@x -c user.name=f -c commit.gpgsign=false commit -qam fix ) > /dev/null 2>&1 || return 1
  rcpt_push "$1" 2
  return 0
}
rcpt_push() { # <tag> <n>: one push of the world; log in <tag>/log.<n>, exit in <tag>/rc.<n>
  local w="$WORK/$1/w"
  ( unset FXCOUNT_DIR FXCOUNT_RC FXCOUNT_JUDGE
    hook_drive "$w" "$WORK/$1/log.$2" FXCELL="e2e-$1-$2" PREPUSH_POOL_DEPTH=1 AI_DLC_PRESUITE_SKIP=1 AI_DLC_VERDICT_STORE="$w.vs" ) > "$WORK/$1/rc.$2"
}
rcpt_red() { # <cell> <tag>: 0 RED, 1 GREEN
  local t="$WORK/$2"
  case "$1" in
    rec) ! { grep -qx '   ok    aaa-rec' "$t/log.1" 2>/dev/null && [ "$(cat "$t/n1" 2>/dev/null)" = 1 ]; } ;;
    skip) ! { grep -qx '   ..    verdict store: 1 fixture(s) skipped on a pass recorded elsewhere: aaa-rec' "$t/log.2" 2>/dev/null \
              && ! grep -qx '   ok    aaa-rec' "$t/log.2" 2>/dev/null; } ;;
    blocked) ! { [ "$(cat "$t/rc.1" 2>/dev/null)" != 0 ] && grep -q '^pre-push: BLOCKED' "$t/log.1" 2>/dev/null; } ;;
    *) return 2 ;;
  esac
}
if [ -f "$SUBJ_PATH_1" ] && [ -f "$SUBJ_PATH_2" ]; then
  [ -f "$RC_HR" ] && [ -f "$RC_CP" ] || broken "BL-1048 receipt: core/scripts/hermetic-run.sh or core-paths.sh is not beside $HERE/../.."
  RC_HOOK="$(cd "$(dirname "$SUBJ_PATH_1")" && pwd -P)/$(basename "$SUBJ_PATH_1")"
  rcpt_drive rc-pristine "$RC_HOOK" pristine || broken "BL-1048 receipt: could not seed or drive the shipped hook"
  # The control: drive 2 is the red FIXED, so it must exit 0; a harness that died would not.
  [ "$(cat "$WORK/rc-pristine/rc.2")" = 0 ] || broken "BL-1048 receipt: the re-push with the red fixed exited $(cat "$WORK/rc-pristine/rc.2"), so the world itself is red. Log: $WORK/rc-pristine/log.2"
  if rcpt_red blocked rc-pristine; then bad "BL-1048 blocked: a red step did not hold the push (rc $(cat "$WORK/rc-pristine/rc.1"); BLOCKED required)"
  else ok "BL-1048 blocked: under the seeded red step the push exits $(cat "$WORK/rc-pristine/rc.1"), BLOCKED"; fi
  if awk '/^   a step above is red; this push is BLOCKED/ { n = 1; next } n && $0 == "     fixture in-process cells, static half (scripts/validate-fixture-inprocess.sh; grammar only)" { f = 1 } END { exit f ? 0 : 1 }' "$WORK/rc-pristine/log.1"
  then ok "BL-1048 named: the suite step names the seeded red step before it runs"
  else bad "BL-1048 named: the suite step did not name the seeded red step"; fi
  if rcpt_red rec rc-pristine; then bad "BL-1048 rec: under a red step the suite did not run aaa-rec and record its pass ($(cat "$WORK/rc-pristine/n1") store entries)"
  else ok "BL-1048 rec: under a red step the suite ran aaa-rec and its pass is in the verdict store"; fi
  if rcpt_red skip rc-pristine; then bad "BL-1048 skip: the re-push with the red fixed did not skip aaa-rec on the recorded pass"
  else ok "BL-1048 skip: the re-push with the red fixed skipped aaa-rec on the pass the red push recorded"; fi
else
  printf '  ..    BL-1048 receipt: not the distribution layout -- not exercised\n'
fi

# A fixture that reached neither subject has established nothing, and the green line
# it would otherwise print is indistinguishable from one that checked both hooks.
[ "$exercised" -gt 0 ] \
  || broken "neither pre-push hook was found from $HERE (looked for ../../../.githooks/pre-push and ../../git-hooks/pre-push) — nothing was exercised"

printf '  ..    subjects exercised: %s\n' "$exercised"

report_end prepush-worktree-env-scrub
