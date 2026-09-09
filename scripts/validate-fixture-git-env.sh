#!/usr/bin/env bash
# validate-fixture-git-env.sh — a fixture that builds a scratch repository must
# scrub the inherited git environment first.
#
# THE SUBJECT. Git exports GIT_DIR absolute to any hook run from a linked
# worktree. A fixture invoked DIRECTLY -- `bash core/fixtures/X/run.sh`, the way
# CLAUDE.md tells a session to debug one -- inherits it, and its `git init` then
# silently succeeds WITHOUT creating a repository, redirecting every later git
# call onto the caller's index. Measured across eight fixtures against an unarmed
# control: 8 of 8 wiped a 757-entry index, 6 at exit 0 with zero FAILs.
#
# WHY THIS IS A STANDALONE PROGRAM AND NOT AN ARM OF validate-enforcement-map.sh.
# That validator is invoked by 25 fixture directories, so an arm added there is
# multiplied by the sharded batteries and lands on the suite POLE's wall clock --
# CLAUDE.md requires such a change be timed before and after from inside the repo.
# This subject needs no join against the enforcement map, so it pays none of that:
# it is dispatched once, from the hook, like the other ten standalone validators.
#
# THE FALSE-POSITIVE SET IS WHY THIS REPORTS RATHER THAN FAILS BY DEFAULT. The
# population is every fixture directory running any `git ... init` form in any of
# its own scripts, keyed to that directory's run.sh. Of the eight driven,
# six genuinely clobbered and two never reached a git write, so a fail-by-default
# arm would have wedged the push over findings a third of which cannot fire. It
# ships REPORT-ONLY with `--max-unscrubbed N`, a ceiling that only ever moves
# DOWN -- the shape validate-write-format-steering.sh already uses, for the same
# reason: a check that wedges first contact is a check the operator turns off.
#
# Exit 0 clean or under the ceiling, 1 over the ceiling or on a broken
# declaration, 2 when it cannot establish its own population (refusal, not a
# finding -- an empty population agrees with every claim).
set -u

SELF_DIR="$(cd "$(dirname "$0")" && pwd)"

# Resolve the repo root by WALKING UP for a marker, never by counting `..` hops:
# a hop count answers differently from the root, from a subdirectory and from a
# sandbox copy, and the sandbox answer is the silent one.
ROOT="${AI_DLC_PROJECT_ROOT:-}"
if [ -z "$ROOT" ]; then
  ROOT="$SELF_DIR"
  while [ "$ROOT" != "/" ] && [ ! -f "$ROOT/VERSION" ]; do ROOT="$(dirname "$ROOT")"; done
fi
[ -f "$ROOT/VERSION" ] || { echo "validate-fixture-git-env: REFUSED — no VERSION marker above $SELF_DIR; cannot establish a repo root." >&2; exit 2; }
cd "$ROOT" || exit 2

MAX_UNSCRUBBED=""
REPORT_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --max-unscrubbed) MAX_UNSCRUBBED="${2:-}"; shift 2 ;;
    --report) REPORT_ONLY=1; shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) echo "validate-fixture-git-env: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

# THE POPULATION IS DERIVED, never listed. A fixture joins it by running `git
# init` in ANY of its own scripts; the next one is covered the day it is written.
#
# IT KEYS ON THE DIRECTORY, NOT ON run.sh, AND THE FIRST CUT DID NOT. Scoped to
# `*/run.sh` it missed 13 fixture directories whose `seed.sh` runs `git init`
# while their `run.sh` does not -- those `run.sh` sourced nothing, so the seed
# inherited an armed GIT_DIR and clobbered. Measured against the tree carrying
# the run.sh-only fix: `layer-conforms-to` took a 762-entry index to 2 at exit 0
# with ZERO FAILs, while `trunk-push-bound` in the same run stayed 762 -- the
# discrimination control proving the fix worked where it reached and that these
# were surviving it. The seam still goes in `run.sh`, which is the entry point;
# the scrub reaches the seed by INHERITANCE, which is why the two dirs whose
# run.sh already `git init`s were fixed by the first cut.
#
# AND THE GRAMMAR ITSELF SCORED ITS OWN SUBJECT AS A NON-INSTANCE. Keyed on the
# LITERAL string `git init`, the population was 43 fixture directories where 70
# run some `git ... init` form: `git -C "$X" init`, `git -c init.defaultBranch=main
# init -q .`, chained `-c`/`-C`. The 27 in the difference sat OUTSIDE the
# population entirely, none of their run.sh sourced the seam, and this validator
# reported `0 unscrubbed` at ceiling 0 over them -- a clean sheet computed over a
# set that excluded every one of them. Driven directly under an armed GIT_DIR
# against a fresh 40-entry victim, whole-tree copy, harness self-probed both ways:
# 26 of those 27 clobbered, 13 of them at exit 0.
#
# THE FORM IS WHY, AND IT IS NOT A VARIANT OF THE SAME FAILURE. Under an armed
# GIT_DIR, `git -C X init`, `git -C X init .` and `git -c k=v init <path>` all exit
# 0, create NO repository at the target, AND FLIP THE VICTIM'S `core.bare` TO TRUE.
# Three of the 27 -- consumer-suite-pool, suite-dispatch-order,
# layer-anchor-declaration -- left the victim's index at 40 and wrecked it through
# config alone (`core.bare=true`, `user.name` rewritten), after which `git status`
# in the victim answers `fatal: this operation must be run in a work tree`. An
# index-count guard scores those three as INTACT, which is why
# core/fixtures/fixture-git-env-seam/run.sh reads bare and user.name too.
#
# THE GRAMMAR BELOW IS POSIX-CLASS ONLY, DELIBERATELY. `git grep -E` implements
# neither `\b` nor `\s` and returns a CLEAN ZERO rather than an error, so an
# escape that works in the `grep -E` beside it silently empties this one. Measured
# on the real corpus: this pattern resolves the identical 74 files under
# `git grep -E` and under `/usr/bin/grep -E`. FALSE-POSITIVE SET, measured before
# it shipped: the pattern matches a COMMENT naming `git init`, and zero fixture
# scripts join the population by a comment-only hit -- every matching file carries
# at least one non-comment match. `git config init.defaultBranch main`,
# `git commit -m init`, `git-init` and `legit initiate` are all refused, because
# `init` must be a whole word preceded only by `-c`/`-C` options.
INIT_RE='(^|[^[:alnum:]_-])git([[:space:]]+-[cC][[:space:]]*[^[:space:]]+)*[[:space:]]+init([[:space:]]|$)'

POP="$(git -C "$ROOT" grep -lE "$INIT_RE" -- 'core/fixtures/*/*.sh' 2>/dev/null \
       | sed 's#/[^/]*$##' | sort -u \
       | while IFS= read -r d; do [ -f "$ROOT/$d/run.sh" ] && printf '%s/run.sh\n' "$d"; done | sort -u)"
POP_N="$(printf '%s\n' "$POP" | grep -c . || true)"

# A population that collapsed is a REFUSAL. An empty set is consistent with every
# fixture being clean and with the grammar having stopped matching, and those two
# read identically in a verdict line.
if [ "$POP_N" -lt 10 ]; then
  echo "validate-fixture-git-env: REFUSED — the derived population is ${POP_N} fixture run.sh files, below the floor of 10." >&2
  echo "  Either the grammar stopped matching or core/fixtures/ moved. This refuses rather than" >&2
  echo "  reporting a clean sheet it did not compute." >&2
  exit 2
fi

SEAM="core/fixtures/lib/preamble.sh"
if [ ! -f "$ROOT/$SEAM" ]; then
  echo "validate-fixture-git-env: FAIL — the seam ${SEAM} does not exist, so no fixture can source it." >&2
  exit 1
fi
# The seam must actually SCRUB. Binding on the file's existence alone would pass
# over an empty file, and every sourcing fixture would then be reported clean.
if ! grep -qE '^[[:space:]]*unset([[:space:]]+[A-Z_]+)*[[:space:]]+GIT_DIR([[:space:]]|$)' "$ROOT/$SEAM"; then
  echo "validate-fixture-git-env: FAIL — ${SEAM} exists but does not unset GIT_DIR. Every fixture" >&2
  echo "  sourcing it would be reported scrubbed while inheriting the caller's repository." >&2
  exit 1
fi

# THE GRAMMARS ARE SINGLE-SOURCED, because each is now read twice -- once to ask
# WHETHER a file carries the thing and once to ask WHERE. A pattern spelled twice
# is one chance to drift, and the two readings would then disagree silently.
SEAM_RE='^[[:space:]]*(\.|source)[[:space:]]+.*preamble\.sh'
SCRUB_RE='^[[:space:]]*unset([[:space:]]+[A-Z_]+)*[[:space:]]+GIT_DIR([[:space:]]|$)'
ENVSCRUB_RE='^[[:space:]]*env[[:space:]]+(-u[[:space:]]+GIT_DIR|-i)([[:space:]]|$)'

# first_line_re <file> <ere> -> the line number of the first match, or empty.
# `grep -n` rather than `awk -v`: awk strips one level of escaping from a -v
# value, so `preamble\.sh` would arrive as a bare `.` and widen the match
# invisibly -- a correct site would look wrong and a wrong one would look right.
first_line_re() {
  local out
  out="$(grep -nE "$2" "$1" 2>/dev/null)" || return 0
  [ -n "$out" ] || return 0
  # `sed -n 1s` rather than `head -1 | cut`: head leaves at its first line while
  # the writer is still pushing, and a reader fed from a pipe that way answers with
  # the writer's EPIPE the day the upstream grows past the pipe buffer.
  printf '%s\n' "$out" | sed -n '1s/:.*//p'
}

# THE POSITION THAT MATTERS IS WHERE run.sh REACHES AN INIT, NOT WHERE run.sh
# CONTAINS ONE, AND THE FIRST CUT OF THE POSITION ARMS CONFLATED THE TWO. The
# population joins on ANY *.sh in the directory, and 30 of its 69 members have no
# init in their own run.sh at all -- their init is in a seed.sh the run.sh
# INVOKES. For those the run.sh-only reading is empty, both position branches fall
# through on `[ -n "$init_ln" ]`, and a run.sh whose seam sits BELOW its
# `bash seed.sh` call is acquitted. Measured on a probe tree: such a fixture takes
# a 40-entry victim to 0, and its inline-scrub twin does the same. Live exposure
# was zero -- all 30 carry the seam at line 2 -- so it was a trap rather than a
# hole, and it was the exact defect these arms exist to catch, one file over.
#
# So the init SITE is the earliest of: the first init in run.sh, and the first
# line of run.sh that INVOKES a sibling script which itself carries an init.
# Keyed on the invocation rather than on any mention of the sibling's name: a
# comment naming seed.sh is not a call, and keying on the name alone would move
# the site earlier than the program does.
# THE PRECEDING CLASS IS SEPARATORS, NOT "ANY NON-WORD CHARACTER", AND THE FIRST
# CUT WAS THE LOOSE FORM. Written `[^[:alnum:]_-]` it matched the `sh` inside the
# FILENAME `seed.sh`, so a COMMENT merely naming the sibling scored as an
# invocation -- the whole-file-grep weakness these arms exist to refuse, inside the
# reader meant to replace it. Caught by this fixture's own W9 arm, which seeds
# exactly that comment. A command starts the line or follows whitespace or a
# `;`/`&`/`|`/`(` separator; it never follows a dot.
INVOKE_RE='(^|[[:space:]]|[;&|(])(bash|sh|source|\.)[[:space:]]'
init_site_line() { # init_site_line <dir> <run.sh-path> -> earliest reaching line, or empty
  local dir="$1"
  local run="$2"
  local best
  local s
  local b
  local hits
  local ln
  best="$(first_line_re "$run" "$INIT_RE")"
  for s in "$dir"/*.sh; do
    [ -f "$s" ] || continue
    b="$(basename "$s")"
    [ "$b" = "run.sh" ] && continue
    grep -qE "$INIT_RE" "$s" || continue
    # Two greps, not one: the sibling's basename is a LITERAL (`-F`) and the
    # invocation is a pattern, and spelling a filename into an ERE turns its dot
    # into a wildcard.
    hits="$(grep -nE "$INVOKE_RE" "$run" 2>/dev/null)" || hits=""
    [ -n "$hits" ] || continue
    ln="$(printf '%s\n' "$hits" | grep -F "$b" | sed -n '1s/:.*//p')" || ln=""
    [ -n "$ln" ] || continue
    if [ -z "$best" ] || [ "$ln" -lt "$best" ]; then best="$ln"; fi
  done
  printf '%s\n' "$best"
}

UNSCRUBBED=""
N_UNSCRUBBED=0
for f in $POP; do
  # A SCRUB BELOW THE FIRST `git ... init` IN THE SAME FILE IS NOT A SCRUB, and
  # both halves of this loop were POSITION-BLIND until they were measured. The
  # re-arm note below already stated the general form for the seam branch; the
  # inline-scrub exemption had it live. Measured: self-update-fixture-log scrubs
  # at run.sh:694 with its first init at run.sh:88, and self-update-gate scrubs at
  # run.sh:819 with its first init at run.sh:159. Both were acquitted by the
  # inline exemption on the whole-file grep alone, and both clobbered the victim
  # silently at exit 0 -- an exemption acquitting the arm's own subject. Both also
  # omit GIT_COMMON_DIR and GIT_OBJECT_DIRECTORY, which the seam unsets.
  # handoff-completion-assertion is the discriminating near-miss: its scrub sits at
  # run.sh:56 and seed.sh:24, above every git call in each file, and it genuinely
  # survives a drive -- it must stay acquitted, so this arm compares LINE NUMBERS
  # and never merely counts scrubs.
  #
  # The site is resolved through the whole DIRECTORY, per init_site_line above: a
  # run.sh that never inits itself still reaches one through the seed it invokes.
  init_ln="$(init_site_line "$ROOT/$(dirname "$f")" "$ROOT/$f")"

  # AN UNRESOLVABLE SITE IS A FINDING, NOT AN ACQUITTAL. Every member of this
  # population runs an init somewhere in its directory -- that is how it joined --
  # so a site that resolves to nothing means run.sh reaches that init by a route
  # this reader cannot see, and the position arms below are then unable to judge
  # it. Falling through would acquit exactly the file nobody can reason about.
  # FALSE-POSITIVE SET, measured over the live population before this shipped:
  # ZERO of 69 fail to resolve -- 34 by an init in run.sh, 30 by an invoked
  # sibling, 5 by both. It ships as a finding because there is no correct input it
  # can fire on today.
  if [ -z "$init_ln" ]; then
    UNSCRUBBED="${UNSCRUBBED} ${f}(init-site-unresolved)"
    N_UNSCRUBBED=$((N_UNSCRUBBED + 1))
    continue
  fi

  # Key on the SOURCING SITE, not on a whole-file grep: a comment naming the
  # preamble satisfies `grep -qF` over the file and changes no behaviour.
  if grep -qE "$SEAM_RE" "$ROOT/$f"; then
    # THE SEAM LINE MUST PRECEDE THE FIRST INIT TOO. By convention it is line 2,
    # immediately after the shebang, so this arm has no live subject today and is a
    # trap for the next author -- the same status, and the same treatment, as the
    # re-arm check below. Asserted rather than assumed: a convention is not a
    # mechanism, and a seam sourced after the init scrubs nothing.
    seam_ln="$(first_line_re "$ROOT/$f" "$SEAM_RE")"
    if [ -n "$seam_ln" ] && [ "$seam_ln" -gt "$init_ln" ]; then
      UNSCRUBBED="${UNSCRUBBED} ${f}(seam-sourced-below-first-init)"
      N_UNSCRUBBED=$((N_UNSCRUBBED + 1))
      continue
    fi
    # SOURCING IT IS NOT ENOUGH IF SOMETHING RE-ARMS AFTERWARDS. The scrub is a
    # statement, not a property: a later `GIT_DIR=` assignment or `export GIT_DIR`
    # undoes it, and an arm keyed only on the sourcing site is POSITION-BLIND --
    # it acquits a file whose second line sources the seam and whose third line
    # re-exports GIT_DIR. Verified against this validator's own earlier cut: that
    # file reported `0 unscrubbed` while clobbering 757 -> 4. Not live today (0 of
    # 41), so this is a trap for the next author rather than a hole -- the same
    # status, and the same treatment, as the comment-form acquittal below.
    # A ONE-SHOT PREFIX IS NOT A RE-ARM, and the first cut of this arm could not
    # tell them apart. `GIT_DIR=x git ls-files` scopes the variable to that single
    # command and leaves the shell's environment alone; `GIT_DIR=x` on its own, or
    # `export GIT_DIR=x`, persists. Keyed loosely it flagged this validator's own
    # fixture, whose harness reads a victim index with exactly that prefix -- a
    # true match on a false subject, which is the false-positive path CLAUDE.md
    # requires measured before an arm ships. The assignment must END the command:
    # nothing after it but whitespace, a comment, or a `;`/`&&`/`||` separator.
    if grep -qE '^[[:space:]]*(export[[:space:]]+)?GIT_DIR=[^[:space:]]*[[:space:]]*(#.*)?$' "$ROOT/$f" \
       || grep -qE '^[[:space:]]*(export[[:space:]]+)?GIT_DIR=[^[:space:]]*[[:space:]]*(;|&&|\|\|)' "$ROOT/$f"; then
      UNSCRUBBED="${UNSCRUBBED} ${f}(re-arms)"
      N_UNSCRUBBED=$((N_UNSCRUBBED + 1))
    fi
    continue
  fi
  # A fixture may scrub inline instead. That is a different shape from the seam
  # and it is still a fix -- the property is the scrub, not which file carries it.
  #
  # THE EXEMPTION IS ANCHORED AT COLUMN 0 OF A COMMAND, AND THE FIRST CUT WAS NOT.
  # Written as an unanchored alternation it matched `env -i` ANYWHERE in the file,
  # including inside a comment -- so `# env -i` acquitted a fixture that scrubs
  # nothing. That is the exact whole-file-grep weakness that retired this entry's
  # original receipt, reintroduced inside the arm meant to replace it: an exemption
  # that acquits the arm's own subject is a mechanism defending its own defect.
  # Measured when it was fixed: 0 of the 27 were reaching this branch, so it
  # acquitted nothing live -- it was a trap for the next author, not a hole.
  # Each alternative is `^[[:space:]]*` anchored and the probe asserts the comment
  # form is NOT acquitted.
  #
  # AND IT IS KEYED ON POSITION, per the note at the top of this loop: the
  # exemption holds only where the scrub precedes the file's first init.
  scrub_ln="$(first_line_re "$ROOT/$f" "$SCRUB_RE")"
  [ -n "$scrub_ln" ] || scrub_ln="$(first_line_re "$ROOT/$f" "$ENVSCRUB_RE")"
  if [ -n "$scrub_ln" ]; then
    if [ "$scrub_ln" -lt "$init_ln" ]; then
      continue
    fi
    UNSCRUBBED="${UNSCRUBBED} ${f}(scrub-below-first-init)"
    N_UNSCRUBBED=$((N_UNSCRUBBED + 1))
    continue
  fi
  UNSCRUBBED="${UNSCRUBBED} ${f}"
  N_UNSCRUBBED=$((N_UNSCRUBBED + 1))
done

if [ "$N_UNSCRUBBED" -gt 0 ]; then
  echo "validate-fixture-git-env: ${N_UNSCRUBBED} of ${POP_N} fixture run.sh build a scratch repository"
  echo "  without scrubbing the inherited git environment. Run directly from a linked worktree"
  echo "  (\`bash core/fixtures/X/run.sh\`), each can redirect its git calls onto the caller's"
  echo "  repository and wipe that index while reporting PASS. Remedy: source the seam first --"
  echo "    . \"\$(cd \"\$(dirname \"\$0\")/../lib\" && pwd)/preamble.sh\""
  for f in $UNSCRUBBED; do echo "    ${f}"; done
fi

# THE RATCHET. The unscrubbed set is a backlog and does not fail on its own; what
# must not happen is GROWTH. A new fixture added without the seam is the same
# defect one instance larger and is invisible without a bound.
if [ -n "$MAX_UNSCRUBBED" ] && [ "$N_UNSCRUBBED" -gt "$MAX_UNSCRUBBED" ]; then
  echo "validate-fixture-git-env: FAIL — ${N_UNSCRUBBED} unscrubbed fixture(s), above the ceiling of" >&2
  echo "  ${MAX_UNSCRUBBED}. The ceiling only moves DOWN: source the seam in the new fixture, or lower" >&2
  echo "  the ceiling in the same change that removes one." >&2
  exit 1
fi

[ "$REPORT_ONLY" -eq 1 ] && exit 0

# Say what was judged, with its counts. A pass naming no population is
# indistinguishable from a pass that compared nothing.
echo "validate-fixture-git-env: ok — ${POP_N} fixture run.sh build a scratch repository, ${N_UNSCRUBBED} unscrubbed (ceiling ${MAX_UNSCRUBBED:-none})."
exit 0
