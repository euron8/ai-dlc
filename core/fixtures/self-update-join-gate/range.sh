#!/usr/bin/env bash
# self-update-join-gate/range.sh -- the ONE derivation of the range this fixture drives the gate over. Run from the
# repository root (git.decl's `range @range.sh ...` runs it there once per push, and seed.sh runs the same file
# outside a sandbox), it prints `<base>..<theirs>`:
#   base    the parent of the NEWEST commit that adds a `<!-- CHECK_LOADED:` anchor to gate-validation.md AND has at
#           least four VERSION-touching commits after it (a release whose own squash adds an anchor leaves the
#           walk no candidate; that commit is skipped until releases accumulate); the newest anchor-adder when
#           none qualifies;
#   theirs  the FOURTH VERSION-touching commit after that commit, or HEAD when fewer than four exist yet.
# The bound keeps advise_safe_stop's walk at four candidates: taking HEAD made the range every release since the
# anchor-adder, one nested gate per release, and the fixture grew slower on its own with each release.
# Exit 1, printing nothing, when no commit adds an anchor or a git call fails: the hook reads that as a refusal.
set -uo pipefail
SUJG_SS_FLOOR=4
added="$(git log --format=%H -S'<!-- CHECK_LOADED:' --pickaxe-regex -- core/skills/ai-dlc/steps/gate-validation.md < /dev/null)" || exit 1
[ -n "$added" ] || exit 1
pick=""
for a in $added; do
  [ -n "$pick" ] || pick="$a"
  n="$(git rev-list --count "${a}..HEAD" -- VERSION < /dev/null)" || exit 1
  if [ "$n" -ge "$SUJG_SS_FLOOR" ]; then pick="$a"; break; fi
done
added="$pick"
base="$(git rev-parse -q --verify "${added}^" < /dev/null)" || exit 1
after="$(git rev-list --reverse "${added}..HEAD" -- VERSION < /dev/null)" || exit 1
theirs="$(printf '%s\n' "$after" | sed -n "${SUJG_SS_FLOOR}p")"
[ -n "$theirs" ] || theirs="$(git rev-parse -q --verify HEAD < /dev/null)" || exit 1
printf '%s..%s\n' "$base" "$theirs"
