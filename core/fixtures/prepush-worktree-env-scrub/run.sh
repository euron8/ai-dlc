#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh"
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
# defines functions at the top and invokes them at the bottom. The
# `scrub-after-dispatch` near-miss below SATISFIES that regex exactly once and
# still corrupts the repository, which is the whole of the difference.
#
# WHAT IT DRIVES. The shipping hook itself, run end to end, in a sandbox that is a
# real repository with a real linked worktree, with GIT_DIR exported the way git
# exports it. Nothing here re-implements the hook. Every mutant is a COPY guarded
# by `cmp -s`, and the UNMUTATED copy is driven in the same battery through the
# same harness, so a harness that broke cannot let a mutant score a kill.
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

fails=0
asserts=0
ok()  { printf '  ok    %s\n' "$1"; asserts=$((asserts+1)); }
bad() { printf '  FAIL  %s\n' "$1"; fails=$((fails+1)); asserts=$((asserts+1)); }
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

# The token every mutation below is keyed on, and the regex the receipt this replaces
# used. Held in one place so the near-miss arm can state what it satisfies.
ANCHOR_RE='^[[:space:]]*unset[[:space:]].*GIT_OBJECT_DIRECTORY'
SCRUB_LINE='unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY'

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

  mkdir -p "$sb/wt/.githooks" "$sb/wt/$fxdir/aaa-probe" || return 1
  hookfile="$sb/wt/.githooks/pre-push"

  case "$variant" in
    pristine)
      cp "$hooksrc" "$hookfile" || return 1
      ;;
    no-scrub)
      awk '!/^unset .*GIT_OBJECT_DIRECTORY/' "$hooksrc" > "$hookfile" || return 1
      ;;
    comment-only)
      awk '{ if ($0 ~ /^unset .*GIT_OBJECT_DIRECTORY/)
               print "# we deliberately do not unset GIT_OBJECT_DIRECTORY here"
             else print }' "$hooksrc" > "$hookfile" || return 1
      ;;
    scrub-after-dispatch)
      { awk '!/^unset .*GIT_OBJECT_DIRECTORY/' "$hooksrc"; printf '%s\n' "$SCRUB_LINE"; } \
        > "$hookfile" || return 1
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
  ( cd "$sb/wt" && env GIT_DIR="$gd" AI_DLC_FIXTURE_NO_SKIP=1 \
      bash "$hookfile" ) </dev/null > "$sb/hook.log" 2>&1

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
  local n_anchor n_token kills=0

  case "$hooksrc" in
    /*) ;;
    *) broken "$label: subject path is not absolute ($hooksrc) — this fixture would read a different file from a different cwd" ;;
  esac

  # PRINT THE FILE THIS BATTERY ACTUALLY RESOLVED. A fixture that names candidates in
  # both install layouts can mutate a copy the run never loads: `cmp -s` is satisfied
  # because the mutation applied cleanly, every arm stays green, and a mutant that
  # killed nothing reads exactly like an arm that cannot fire. The resolved path is
  # printed, the SAME path is what `seed_and_drive` copies into the sandbox, and the
  # sandbox copy is what `bash` is handed by absolute path — so the file mutated and
  # the file executed are one file by construction, not by convention.
  printf '  ..    %s: RESOLVED %s\n' "$label" "$hooksrc"

  # AND THE SAME SUBJECT MUST NOT BE BATTERED TWICE. Two candidates that resolved to
  # one file would print two sets of greens over one hook and leave the other
  # unguarded — a coverage claim of 2 backed by 1.
  case "$resolved_paths" in
    *"|$hooksrc|"*) broken "$label: $hooksrc was already exercised by an earlier subject — the two layout candidates resolved to the SAME file, so one hook is being tested twice and the other not at all" ;;
  esac
  resolved_paths="$resolved_paths|$hooksrc|"

  seed_and_drive "$slug-pristine" "$hooksrc" "$fxdir" pristine \
    || broken "$label: could not seed or drive the UNMUTATED hook"

  # THE CONTROL, AND IT COMES FIRST. The pristine arm below is absence-shaped: it
  # claims the repository was not touched. A probe that was never dispatched leaves
  # exactly the same evidence, so establish the dispatch happened before reading the
  # absence.
  if probe_ran "$slug-pristine"; then
    ok "$label: the probe fixture WAS dispatched by the unmutated hook (the absence arm below has a subject)"
  else
    broken "$label: the unmutated hook never dispatched the probe fixture — every arm below would pass over a hook that ran nothing. Hook log: $WORK/$slug-pristine/hook.log"
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
    bad "$label: the probe's sandbox commit landed on the REAL repository under an UNMUTATED hook"
  else
    ok "$label: the real repository is untouched — HEAD $(cut -c1-8 < "$WORK/$slug-pristine/head.before") still at subject '$(cat "$WORK/$slug-pristine/subj.after")'"
  fi

  # AND IF THE SUBJECT IS ALREADY BROKEN, THE MUTANTS ARE MOOT AND SAYING SO IS NOT
  # OPTIONAL. Mutating a hook that already lacks the scrub produces a byte-identical
  # file, `cmp -s` refuses it, and the fixture would exit 2 shouting FIXTURE BROKEN —
  # which reads as a defect in this harness rather than in the subject, the exact
  # misreading a red suite can least afford. The mutants exist to prove this arm
  # discriminates; an arm that just fired on the unmutated subject has proved that.
  if corrupted "$slug-pristine"; then
    printf '  ..    %s: mutant battery NOT run — the unmutated subject already redirects the sandbox commit, so no mutation of it could discriminate. The arm above already fired.\n' "$label"
    exercised=$((exercised + 1))
    return 0
  fi

  # A3-A5. Three mutants, each a copy, each guarded by `cmp -s` BEFORE its verdict is
  # read — a `sed`/`awk` that matched nothing produces a byte-identical file, and a
  # differential whose two sides are the same program reads as "no regression".
  for variant in no-scrub comment-only scrub-after-dispatch; do
    seed_and_drive "$slug-$variant" "$hooksrc" "$fxdir" "$variant" \
      || broken "$label/$variant: could not seed or drive the mutant"

    if cmp -s "$hooksrc" "$WORK/$slug-$variant/wt/.githooks/pre-push"; then
      broken "$label/$variant: the mutation produced a BYTE-IDENTICAL file. Both sides of this differential are the same program, so the comparison below would report agreement whatever the subject does."
    fi

    if ! probe_ran "$slug-$variant"; then
      broken "$label/$variant: the mutant never dispatched the probe fixture, so its failure below would be an artefact of the mutation rather than the defect"
    fi

    # The near-miss controls carry their own claim about what a TEXT anchor would
    # have said, because that is the entire reason they are here.
    if [ "$variant" = comment-only ]; then
      n_token="$(grep -c 'GIT_OBJECT_DIRECTORY' "$WORK/$slug-$variant/wt/.githooks/pre-push" 2>/dev/null)"
      case "$n_token" in ''|*[!0-9]*) n_token=0 ;; esac
      if [ "$n_token" -ge 1 ]; then
        ok "$label/$variant: the near-miss still CARRIES the token GIT_OBJECT_DIRECTORY ($n_token line(s)) — a token-presence check would accept it"
      else
        broken "$label/$variant: the comment-only near-miss does not carry the token, so it is not a near-miss for anything"
      fi
    fi
    if [ "$variant" = scrub-after-dispatch ]; then
      n_anchor="$(grep -cE "$ANCHOR_RE" "$WORK/$slug-$variant/wt/.githooks/pre-push" 2>/dev/null)"
      case "$n_anchor" in ''|*[!0-9]*) n_anchor=0 ;; esac
      if [ "$n_anchor" -eq 1 ]; then
        ok "$label/$variant: the near-miss SATISFIES the presence-only receipt regex exactly once, with the scrub moved below the dispatch"
      else
        broken "$label/$variant: expected the presence-only regex to match exactly once and it matched $n_anchor — this near-miss is not exercising the presence-vs-execution distinction it exists for"
      fi
    fi

    if corrupted "$slug-$variant"; then
      kills=$((kills + 1))
      ok "$label/$variant: KILLED — the probe's sandbox commit landed on the REAL repository (worktree HEAD moved to 'PROBE-SANDBOX-COMMIT')"
    else
      bad "$label/$variant: SURVIVED. With the scrub $variant the sandbox commit should have been redirected onto the repository under test and it was not. This arm cannot distinguish a fixed hook from a broken one, so it is asserting nothing."
    fi
  done

  # THE KILL COUNT IS THE ARM THAT WATCHES THE OTHER ARMS. Three mutants that all
  # SURVIVE is the signature of a battery mutating a file the run never loads: every
  # mutation applied, `cmp -s` was satisfied, and the subject under test was some
  # other copy. Zero kills is therefore not "the hook is very robust" — it is this
  # fixture having established nothing about this subject.
  if [ "$kills" -gt 0 ]; then
    ok "$label: kill count $kills of 3 — the battery reached the file it resolved ($hooksrc)"
  else
    bad "$label: kill count ZERO of 3. Every mutation applied cleanly and none changed the outcome, which is what mutating a file the run never loaded looks like. Resolved: $hooksrc"
  fi

  exercised=$((exercised + 1))
}

if [ -f "$SUBJ_PATH_1" ]; then
  run_subject s1 "$(cd "$(dirname "$SUBJ_PATH_1")" && pwd -P)/$(basename "$SUBJ_PATH_1")" \
    "$SUBJ_FXDIR_1" "$SUBJ_LABEL_1"
else
  printf '  ..    %s absent in this layout — not exercised\n' "$SUBJ_LABEL_1"
fi

if [ -f "$SUBJ_PATH_2" ]; then
  run_subject s2 "$(cd "$(dirname "$SUBJ_PATH_2")" && pwd -P)/$(basename "$SUBJ_PATH_2")" \
    "$SUBJ_FXDIR_2" "$SUBJ_LABEL_2"
else
  printf '  ..    %s absent in this layout — not exercised\n' "$SUBJ_LABEL_2"
fi

# A fixture that reached neither subject has established nothing, and the green line
# it would otherwise print is indistinguishable from one that checked both hooks.
[ "$exercised" -gt 0 ] \
  || broken "neither pre-push hook was found from $HERE (looked for ../../../.githooks/pre-push and ../../git-hooks/pre-push) — nothing was exercised"

printf '  ..    subjects exercised: %s\n' "$exercised"

if [ "$fails" -ne 0 ]; then
  printf 'prepush-worktree-env-scrub: FAIL (%s of %s assertions)\n' "$fails" "$asserts"
  exit 1
fi
printf 'prepush-worktree-env-scrub: ok (%s assertions)\n' "$asserts"
exit 0
