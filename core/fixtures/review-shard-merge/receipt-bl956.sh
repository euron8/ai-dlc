#!/usr/bin/env bash
# BL-956 receipt (STORY-BIND binds the bare review index through the implementation view's row).
# Usage: bash receipt-bl956.sh <path to merge-review-shards.sh> [<project root>]
# Asks the subject IN PROCESS, `( . <subject> && mrs_main --check-serial ... )`, over a repository this receipt seeds in
# the real producer's shape, sprint 3 and epic 1, so the review's sprint and the story's epic are different numbers:
#   BASE: the sprint-3 stories directory and the implementation view (sprint: 3) listing story-3-1 only
#   F6:   story-1-6-x.md at status: review, and the row story-3-6 naming it   (record-only over BASE)
#   F7:   the same story, its row keyed story-3-7                              (record-only over BASE)
#   KB:   BASE plus a KEY-ONLY row story-3-6 (no file:, no story yet: it resolves to nothing there)
#   KF:   KB plus story-6-x.md, which that row resolves to by its stem         (record-only over KB)
# Cells, each a no-run PASS ('Canonical run: none, ...') under --check-serial --gate qa --story --range <base> <F>:
#   bare-6      s3/6-qa-validation.md over BASE..F6  -> 0 SERIAL-OK          (the bare index qa.md prescribes binds by the row)
#   lit-1-6     s3/1-6-qa-validation.md over BASE..F6 -> 0 SERIAL-OK         (control: the literal index binds as before)
#   key-7       s3/6-qa-validation.md over BASE..F7  -> 2 'is not story-6.md' (control: a row keyed under another index)
#   lit-keyonly s3/6-qa-validation.md over KB..KF, --story story-6-x.md -> 0 SERIAL-OK (the story's own key-only row,
#               which names no file at the base, is not a second story under the index; it bound before BL-956)
# On the no-run exemption claim STORY-BIND holds --story's pairs to the index from --base to frozen (the history's
# re-key check, which these cells' ranges never trip): a view version before --base is the lead's planning, and
# --story's own pairs there are not held to the index (other stories' values are still read from the creation).
# Prints `ok <cell>` or `FAIL <cell>: <got>` per cell. 0 = every cell held. 1 = a cell did not. 9 = the receipt could
# not run (bad usage, a seed that failed, a subject that defines no mrs_main, no qa.md under the project root).
set -uo pipefail
# fx_inproc (core/fixtures/lib/mutant.sh) logs this receipt's in-process passes under the fixture's counted run.
# mutant.sh refuses to load without ok() and bad(), so it is sourced behind stubs that are removed again, as
# lib/inproc.sh sources it.
case "${BASH_SOURCE[0]}" in */*) _rl="${BASH_SOURCE[0]%/*}/../lib" ;; *) _rl=../lib ;; esac
ok() { :; }; bad() { :; }
. "$_rl/mutant.sh" || { echo "FIXTURE BROKEN: cannot source $_rl/mutant.sh" >&2; exit 2; }
unset -f ok bad; unset _rl
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -ge 1 ] && [ "$#" -le 2 ] && [ -f "$1" ] && [ "$(basename "$1")" = merge-review-shards.sh ] \
  || { echo "REFUSED: usage: bash receipt-bl956.sh <path to merge-review-shards.sh> [<project root>]" >&2; exit 9; }
MRS="$(cd "$(dirname "$1")" && pwd)/merge-review-shards.sh"
# A pass is logged only for a subject at its own path (a core/scripts directory); a mutant script directory's
# copy is no pass of the subject.
case "${MRS%/*}" in */core/scripts) MRS_PASS=1 ;; *) MRS_PASS=0 ;; esac
# The project root: given, else the working directory (the tree root a `verify:` runs from); it must hold qa.md where
# the subject reads it.
ROOT="${2:-$PWD}"
[ -f "$ROOT/core/team-roles/qa.md" ] || [ -f "$ROOT/.claude/team-roles/qa.md" ] \
  || { echo "REFUSED: no qa.md under the project root $ROOT" >&2; exit 9; }
( set +u +o pipefail; . "$MRS" && declare -F mrs_main > /dev/null ) > /dev/null 2>&1 \
  || { echo "REFUSED: $MRS defines no mrs_main when sourced" >&2; exit 9; }
G() { git -c user.name=receipt -c user.email=receipt@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null -c maintenance.auto=false "$@"; }
R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl956.XXXXXX")" || exit 9
trap 'rm -rf "$R"' EXIT
T="$(cd -P "$R" && pwd -P)/repo"
SD=_bmad-output/planning-artifacts/s3/stories; V=_bmad-output/implementation-artifacts/sprint-status.yaml
ST="$SD/story-1-6-x.md"; SK="$SD/story-6-x.md"
view() { # [<key naming story-1-6-x.md>] [<key-only row>]
  printf 'sprint: 3\nstatus: in_progress\nstories:\n  story-3-1:\n    status: review\n    file: stories/story-1-1-a.md\n' > "$T/$V"
  [ -z "${1:-}" ] || printf '  %s:\n    status: review\n    file: stories/story-1-6-x.md\n' "$1" >> "$T/$V"
  [ -z "${2:-}" ] || printf '  %s:\n    status: review\n' "$2" >> "$T/$V"; }
mkdir -p "$T/$SD" "$T/${V%/*}" "$T/docs/reviews/s3" && G init -q "$T" \
  && printf -- '---\nstatus: review\n---\n# Story 1.1\n' > "$T/$SD/story-1-1-a.md" && view \
  && G -C "$T" add -A && G -C "$T" commit -q -m base && BASE="$(G -C "$T" rev-parse HEAD)" \
  && printf -- '---\nstatus: review\n---\n# Story 1.6\n' > "$T/$ST" && view story-3-6 \
  && G -C "$T" add -A && G -C "$T" commit -q -m f6 && F6="$(G -C "$T" rev-parse HEAD)" \
  && G -C "$T" checkout -q -b k7 "$BASE" && printf -- '---\nstatus: review\n---\n# Story 1.6\n' > "$T/$ST" && view story-3-7 \
  && G -C "$T" add -A && G -C "$T" commit -q -m f7 && F7="$(G -C "$T" rev-parse HEAD)" \
  && G -C "$T" checkout -q -b ko "$BASE" && view '' story-3-6 && G -C "$T" add -A && G -C "$T" commit -q -m kb && KB="$(G -C "$T" rev-parse HEAD)" \
  && printf -- '---\nstatus: review\n---\n# Story 6\n' > "$T/$SK" && G -C "$T" add -A && G -C "$T" commit -q -m kf && KF="$(G -C "$T" rev-parse HEAD)" \
  || { echo "REFUSED: the repository was not seeded" >&2; exit 9; }
[ "$(G -C "$T" diff --name-only "$BASE" "$F6" | tr '\n' ' ')" = "$V $ST " ] && [ "$(G -C "$T" diff --name-only "$BASE" "$F7" | tr '\n' ' ')" = "$V $ST " ] \
  && [ "$(G -C "$T" diff --name-only "$KB" "$KF")" = "$SK" ] && _kbv="$(G -C "$T" show "${KB}:$V")" && ! grep -qF 'file: stories/story-6' <<<"$_kbv" \
  && grep -qxF '  story-3-6:' <<<"$_kbv" \
  || { echo "REFUSED: BASE..F6 or BASE..F7 does not change exactly the view and the story, or KB..KF more than story-6-x.md" >&2; exit 9; }
review() { printf '# QA Validation: 1\n\nadvisor: called\n\n## Summary\nSerial.\n\nCanonical run: none, the diff is record-only (story, view)\n\n## Verdict\nPASS\n\n## Findings\n\n### Critical (must fix before PASS)\n\nNone.\n\n## Acceptance Criteria\n\n| AC | Result | Expected | Got |\n|---|---|---|---|\n| AC1 | PASS | x | y |\n' > "$1"; }
fails=0
cell() { # <name> <review basename> <story> <base> <frozen> <want rc> <want token>
  local f="$T/docs/reviews/s3/$2" o rc
  review "$f"
  o="$( cd "$T" && set +u +o pipefail && AI_DLC_PROJECT_ROOT="$ROOT"; export AI_DLC_PROJECT_ROOT; [ "$MRS_PASS" = 0 ] || fx_inproc "$MRS"; . "$MRS" && mrs_main --check-serial "$f" --gate qa --story "$3" --range "$4" "$5" 2>&1 < /dev/null )"; rc=$?
  rm -f "$f"
  if [ "$rc" = "$6" ] && case "$o" in *"$7"*) true ;; *) false ;; esac; then echo "ok $1"
  else echo "FAIL $1: rc=$rc ${o%%$'\n'*}"; fails=$((fails + 1)); fi
}
cell bare-6 6-qa-validation.md "$ST" "$BASE" "$F6" 0 "SERIAL-OK:"
cell lit-1-6 1-6-qa-validation.md "$ST" "$BASE" "$F6" 0 "SERIAL-OK:"
cell key-7 6-qa-validation.md "$ST" "$BASE" "$F7" 2 "is not story-6.md or story-6-*.md"
cell lit-keyonly 6-qa-validation.md "$SK" "$KB" "$KF" 0 "SERIAL-OK:"
[ "$fails" = 0 ] || exit 1
exit 0
