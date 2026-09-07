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
# population is every fixture run.sh containing `git init`. Of the eight driven,
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
POP="$(git -C "$ROOT" grep -l 'git init' -- 'core/fixtures/*/*.sh' 2>/dev/null \
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

UNSCRUBBED=""
N_UNSCRUBBED=0
for f in $POP; do
  # Key on the SOURCING SITE, not on a whole-file grep: a comment naming the
  # preamble satisfies `grep -qF` over the file and changes no behaviour.
  if grep -qE '^[[:space:]]*(\.|source)[[:space:]]+.*preamble\.sh' "$ROOT/$f"; then
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
  if grep -qE '^[[:space:]]*unset([[:space:]]+[A-Z_]+)*[[:space:]]+GIT_DIR([[:space:]]|$)' "$ROOT/$f" \
     || grep -qE '^[[:space:]]*env[[:space:]]+(-u[[:space:]]+GIT_DIR|-i)([[:space:]]|$)' "$ROOT/$f"; then
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
