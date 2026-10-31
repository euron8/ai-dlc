#!/usr/bin/env bash
# BL-885 receipt (story-base's third operand, <frozen>). Usage: bash receipt-bl885-frozen.sh <path to record-only-diff.sh>
# Asks the subject IN PROCESS, `( . <subject> && ro_main story-base ... )`, over a repository this receipt seeds. At the
# base B, stories/s.md is `status: review`; F (over B) adds stories/new.md, a story created after the base, and
# stories/later/n.md, so stories/later is absent at B and a tree at F. stories/typo.md
# exists at neither, `stories` is a directory and `.git/HEAD` is a path inside the git dir. Cells, each asserting the exit
# code AND a token (an rc=0 cell asserts that stdout and stderr are both empty):
#   story-base -C <T> stories/typo.md B F     -> 2 'is not a file at B or F'
#   story-base -C <T> <T>/.git/HEAD B F       -> 2 'is not a file at B or F'
#   story-base -C <T> .git/HEAD B F           -> 2 'is not a file at B or F'
#   story-base -C <T> stories B F             -> 2 'is not a file at B:'  (a tree at B, decided before <frozen> is read)
#   story-base -C <T> stories/later B F       -> 2 'is not a file at B or F'  (absent at B, a TREE at F: <frozen> must hold a blob)
#   story-base -C <T> stories/new.md B F      -> 0  (created after the base: absent at B, a blob at F)
#   story-base -C <T> stories/s.md B F        -> 1 'already status: review'  (a blob at B takes the read path)
#   story-base -C <T> stories/typo.md B       -> 0  (the two-operand form keeps the old reading: absent at B is 0)
# Prints `ok <cell>` or `FAIL <cell>: <got>` per cell. 0 = every cell held. 1 = a cell did not. 9 = the receipt
# could not run (bad usage, a seed that failed or has the wrong shape, a subject that defines no ro_main).
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -eq 1 ] && [ -f "$1" ] && [ "$(basename "$1")" = record-only-diff.sh ] \
  || { echo "REFUSED: usage: bash receipt-bl885-frozen.sh <path to record-only-diff.sh>" >&2; exit 9; }
RO="$(cd "$(dirname "$1")" && pwd)/record-only-diff.sh"
( set +u +o pipefail; . "$RO" && declare -F ro_main > /dev/null ) > /dev/null 2>&1 \
  || { echo "REFUSED: $RO defines no ro_main when sourced" >&2; exit 9; }
G() { git -c user.name=receipt -c user.email=receipt@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl885-frozen.XXXXXX")" || exit 9
trap 'rm -rf "$R"' EXIT
T="$(cd -P "$R" && pwd -P)/repo"
mkdir -p "$T/stories" && G init -q "$T" \
  && printf -- '---\nstatus: review\n---\n# S\n' > "$T/stories/s.md" && G -C "$T" add -A && G -C "$T" commit -q -m base \
  && B="$(G -C "$T" rev-parse HEAD)" \
  && printf -- '---\nstatus: review\n---\n# N\n' > "$T/stories/new.md" \
  && mkdir -p "$T/stories/later" && printf -- '# L\n' > "$T/stories/later/n.md" && G -C "$T" add -A && G -C "$T" commit -q -m created \
  && F="$(G -C "$T" rev-parse HEAD)" \
  || { echo "REFUSED: the repository was not seeded" >&2; exit 9; }
# The seed's shape, so a cell's answer is about the subject and not about a world that drifted.
! G -C "$T" cat-file -e "${B}:stories/typo.md" 2> /dev/null && ! G -C "$T" cat-file -e "${F}:stories/typo.md" 2> /dev/null \
  && [ "$(G -C "$T" cat-file -t "${B}:stories")" = tree ] \
  && ! G -C "$T" cat-file -e "${B}:stories/new.md" 2> /dev/null && [ "$(G -C "$T" cat-file -t "${F}:stories/new.md")" = blob ] \
  && ! G -C "$T" cat-file -e "${B}:stories/later" 2> /dev/null && [ "$(G -C "$T" cat-file -t "${F}:stories/later")" = tree ] \
  && S_AT_B="$(G -C "$T" show "${B}:stories/s.md")" && grep -qx 'status: review' <<<"$S_AT_B" && [ -f "$T/.git/HEAD" ] \
  || { echo "REFUSED: the seeded repository does not have the shape the cells assume" >&2; exit 9; }
fails=0; n=0
cell() { # <cell> <want rc> <stdout|stderr|silent> <token> <args to ro_main...>
  local c="$1" w="$2" ch="$3" t="$4" rc o e held=0; shift 4
  ( set +u +o pipefail; . "$RO" && ro_main "$@" ) > "$R/o" 2> "$R/e" < /dev/null; rc=$?
  n=$((n + 1))
  case "$ch" in
    stdout) [ "$rc" = "$w" ] && grep -qF -- "$t" "$R/o" && held=1 ;;
    stderr) [ "$rc" = "$w" ] && grep -qF -- "$t" "$R/e" && held=1 ;;
    silent) [ "$rc" = "$w" ] && [ ! -s "$R/o" ] && [ ! -s "$R/e" ] && held=1 ;;
  esac
  if [ "$held" = 1 ]; then echo "ok $c"
  else e="$(head -1 "$R/o" "$R/e" 2> /dev/null | grep -v '^==>' | grep . | head -1)"
    echo "FAIL $c: rc=$rc (want $w with '$t' on $ch): ${e:-<no output>}"; fails=$((fails + 1)); fi
}
cell sf-typo        2 stderr "is not a file at $B or $F" story-base -C "$T" stories/typo.md "$B" "$F"
cell sf-gitdir-abs  2 stderr "is not a file at $B or $F" story-base -C "$T" "$T/.git/HEAD" "$B" "$F"
cell sf-gitdir-rel  2 stderr "is not a file at $B or $F" story-base -C "$T" .git/HEAD "$B" "$F"
cell sf-dir         2 stderr "is not a file at $B:"      story-base -C "$T" stories "$B" "$F"
cell sf-later-tree  2 stderr "is not a file at $B or $F" story-base -C "$T" stories/later "$B" "$F"
cell sf-created     0 silent ''                          story-base -C "$T" stories/new.md "$B" "$F"
cell sf-review      1 stdout 'already status: review'    story-base -C "$T" stories/s.md "$B" "$F"
cell sf-twoarg-typo 0 silent ''                          story-base -C "$T" stories/typo.md "$B"
[ "$n" = 8 ] || { echo "REFUSED: $n of 8 cells ran" >&2; exit 9; }
[ "$fails" -eq 0 ] || exit 1
exit 0
