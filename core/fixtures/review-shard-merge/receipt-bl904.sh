#!/usr/bin/env bash
# BL-904 receipt (story-base over a story deleted and re-added). Usage: bash receipt-bl904.sh <path to record-only-diff.sh>
# Asks the subject IN PROCESS, `( . <subject> && ro_main story-base ... )`, over a repository this receipt seeds:
#   ROOT -> LX (stories/x.md at status: review) -> LCODE (tests/test_a.py) -> LDEL (`git rm` x)
#   side (cut from ROOT, never holds x) -> M (merge of LDEL into side: x absent, TREESAME to side, so default
#   history simplification follows side and hides the deletion) -> FX (x re-added at review) -> NW (stories/new.md)
# Cells, each asserting the exit code AND a token (an rc=0 cell asserts that stdout and stderr are both empty):
#   story-base -C <T> stories/x.md LDEL FX    -> 1 'existed before'          (deleted, then re-added)
#   story-base -C <T> stories/x.md M FX       -> 1 'existed before'          (the deletion hidden behind a merge)
#   story-base -C <T> stories/x.md LX FX      -> 1 'already status: review'  (control: a blob at the base)
#   story-base -C <T> stories/new.md FX NW    -> 0                           (created after the base, never in history)
#   story-base -C <T> stories/x.md LDEL       -> 1 'existed before'          (the two-operand form, same test)
#   story-base -C <T> stories/new.md FX       -> 0                           (the two-operand form, never in history)
#   story-base -C <S> stories/new.md FX NW    -> 2 'shallow repository'      (a copy whose .git/shallow names LX)
#   story-base -C <T>/tests stories/x.md LDEL FX -> 1 'existed before'       (-C a subdirectory: the history pathspec is
#                                                                              the top's, never the -C directory's)
# Prints `ok <cell>` or `FAIL <cell>: <got>` per cell. 0 = every cell held. 1 = a cell did not. 9 = the receipt
# could not run (bad usage, a seed that failed or has the wrong shape, a subject that defines no ro_main).
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -eq 1 ] && [ -f "$1" ] && [ "$(basename "$1")" = record-only-diff.sh ] \
  || { echo "REFUSED: usage: bash receipt-bl904.sh <path to record-only-diff.sh>" >&2; exit 9; }
RO="$(cd "$(dirname "$1")" && pwd)/record-only-diff.sh"
( set +u +o pipefail; . "$RO" && declare -F ro_main > /dev/null ) > /dev/null 2>&1 \
  || { echo "REFUSED: $RO defines no ro_main when sourced" >&2; exit 9; }
G() { git -c user.name=receipt -c user.email=receipt@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null -c maintenance.auto=false "$@"; }
R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl904.XXXXXX")" || exit 9
trap 'rm -rf "$R"' EXIT
T="$(cd -P "$R" && pwd -P)/repo"; S="$(cd -P "$R" && pwd -P)/shallow"
REV='---\nstatus: review\n---\n# X\n'
mkdir -p "$T/stories" "$T/tests" && G init -q "$T" \
  && echo base > "$T/README" && G -C "$T" add -A && G -C "$T" commit -q -m root && ROOT="$(G -C "$T" rev-parse HEAD)" \
  && printf -- "$REV" > "$T/stories/x.md" && G -C "$T" add -A && G -C "$T" commit -q -m LX && LX="$(G -C "$T" rev-parse HEAD)" \
  && echo 'def test(): pass' > "$T/tests/test_a.py" && G -C "$T" add -A && G -C "$T" commit -q -m LCODE \
  && G -C "$T" rm -q stories/x.md && G -C "$T" commit -q -m LDEL && LDEL="$(G -C "$T" rev-parse HEAD)" \
  && G -C "$T" checkout -q -b side "$ROOT" && echo s > "$T/side" && G -C "$T" add -A && G -C "$T" commit -q -m side \
  && G -C "$T" merge -q --no-edit -m MERGE "$LDEL" > /dev/null 2>&1 && M="$(G -C "$T" rev-parse HEAD)" \
  && mkdir -p "$T/stories" && printf -- "$REV" > "$T/stories/x.md" && G -C "$T" add -A && G -C "$T" commit -q -m FX \
  && FX="$(G -C "$T" rev-parse HEAD)" \
  && printf -- '---\nstatus: ready\n---\n# N\n' > "$T/stories/new.md" && G -C "$T" add -A && G -C "$T" commit -q -m NW \
  && NW="$(G -C "$T" rev-parse HEAD)" \
  && cp -R "$T" "$S" && printf '%s\n' "$LX" > "$S/.git/shallow" \
  || { echo "REFUSED: the repository was not seeded" >&2; exit 9; }
# The seed's shape, so a cell's answer is about the subject and not about a world that drifted: x absent at LDEL and M,
# a blob at FX; M is a two-parent merge whose plain path history of x is EMPTY (the hiding the M cell needs) and whose
# --full-history is not; new.md absent everywhere before NW; the copy reads as shallow; from tests/ a bare pathspec walks
# no history of x (the cwd-relative path tests/stories/x.md never existed) and a top-anchored literal one does.
_pl="$(G -C "$T" rev-list -1 "$M" -- stories/x.md)" && _fh="$(G -C "$T" rev-list -1 --full-history "$M" -- stories/x.md)" \
  && [ -z "$_pl" ] && [ -n "$_fh" ] && [ "$(G -C "$T" rev-list --parents -n 1 "$M" | wc -w | tr -d ' ')" = 3 ] \
  && ! G -C "$T" cat-file -e "${LDEL}:stories/x.md" 2> /dev/null && ! G -C "$T" cat-file -e "${M}:stories/x.md" 2> /dev/null \
  && [ "$(G -C "$T" cat-file -t "${FX}:stories/x.md")" = blob ] && [ "$(G -C "$T" cat-file -t "${NW}:stories/new.md")" = blob ] \
  && [ -z "$(G -C "$T" rev-list -1 --full-history "$FX" -- stories/new.md)" ] \
  && [ -z "$(G -C "$T/tests" rev-list -1 --full-history "$LDEL" -- stories/x.md)" ] \
  && [ -n "$(G -C "$T/tests" rev-list -1 --full-history "$LDEL" -- ":(top,literal)stories/x.md")" ] \
  && [ "$(G -C "$S" rev-parse --is-shallow-repository)" = true ] && [ "$(G -C "$T" rev-parse --is-shallow-repository)" = false ] \
  || { echo "REFUSED: the seeded repository does not have the shape the cells assume" >&2; exit 9; }
fails=0; n=0
cell() { # <cell> <want rc> <stdout|stderr|silent> <token> <args to ro_main...>
  local c="$1" w="$2" ch="$3" t="$4" rc e held=0; shift 4
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
cell sh-ldel        1 stdout 'existed before'          story-base -C "$T" stories/x.md "$LDEL" "$FX"
cell sh-merge       1 stdout 'existed before'          story-base -C "$T" stories/x.md "$M" "$FX"
cell sh-lx          1 stdout 'already status: review'  story-base -C "$T" stories/x.md "$LX" "$FX"
cell sh-new         0 silent ''                        story-base -C "$T" stories/new.md "$FX" "$NW"
cell sh-twoarg-ldel 1 stdout 'existed before'          story-base -C "$T" stories/x.md "$LDEL"
cell sh-twoarg-new  0 silent ''                        story-base -C "$T" stories/new.md "$FX"
cell sh-shallow     2 stderr 'shallow repository'      story-base -C "$S" stories/new.md "$FX" "$NW"
cell sh-subdir      1 stdout 'existed before'          story-base -C "$T/tests" stories/x.md "$LDEL" "$FX"
[ "$n" = 8 ] || { echo "REFUSED: $n of 8 cells ran" >&2; exit 9; }
[ "$fails" -eq 0 ] || exit 1
exit 0
