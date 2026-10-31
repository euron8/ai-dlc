#!/usr/bin/env bash
# BL-885 receipt (the story path record-only-diff.sh resolves). Usage: bash receipt-bl885.sh <path to record-only-diff.sh>
# Asks the subject IN PROCESS, `( . <subject> && ro_main <mode> ... )`, over a repository this receipt seeds under a
# physical directory P, with -C and every absolute story spelled through the receipt's OWN symlink L -> P, so the
# spelled top and the `pwd -P` top differ on every platform. The story stories/s.md is `status: review` at the base B,
# F changes only the story, and G (over F) also adds app.py. Cells, each asserting the exit code AND a token:
#   story-base -C <L top> <abs via L> B              -> 1 'already status: review'
#   story-base -C <L top> stories/s.md B              -> 1  (relative, unchanged)
#   story-base -C <L top> ./stories/s.md B            -> 1
#   story-base -C <L top> .//stories/s.md B           -> 1  (a leading ./ then a run of /)
#   story-base -C <L top> <abs via P> B               -> 1  (the physical spelling under a link-spelled -C)
#   story-base -C <L top> /etc/hosts B                -> 2 'UNEVALUABLE' (outside the repository)
#   story-base -C <L top> stories/./s.md B            -> 2 'UNEVALUABLE'
#   story-base -C <L top> stories//s.md B             -> 2 'UNEVALUABLE'  (an empty component)
#   story-base -C <L top> stories/../stories/s.md B   -> 2 'UNEVALUABLE'  (a .. component)
#   story-base -C <L top> '' B                       -> 2 'UNEVALUABLE'
#   paths -C <L top> <abs via L> B F                  -> 0 'RECORD-ONLY: 1 changed path(s)'
#   paths -C <L top> <abs via P> B F                  -> 0 'RECORD-ONLY: 1 changed path(s)'
#   paths -C <L top> <abs via L> B G                  -> 1 'first non-record path app.py'
#   paths -C <L top> /etc/hosts B F                   -> 2 'UNEVALUABLE'
# Prints `ok <cell>` or `FAIL <cell>: <got>` per cell. 0 = every cell held. 1 = a cell did not. 9 = the receipt
# could not run (bad usage, a seed that failed, a subject that defines no ro_main, or a link that did not diverge).
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -eq 1 ] && [ -f "$1" ] && [ "$(basename "$1")" = record-only-diff.sh ] \
  || { echo "REFUSED: usage: bash receipt-bl885.sh <path to record-only-diff.sh>" >&2; exit 9; }
RO="$(cd "$(dirname "$1")" && pwd)/record-only-diff.sh"
( set +u +o pipefail; . "$RO" && declare -F ro_main > /dev/null ) > /dev/null 2>&1 \
  || { echo "REFUSED: $RO defines no ro_main when sourced" >&2; exit 9; }
G() { git -c user.name=receipt -c user.email=receipt@example.invalid -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl885.XXXXXX")" || exit 9
trap 'rm -rf "$R"' EXIT
RP="$(cd -P "$R" && pwd -P)" && mkdir "$RP/phys" && ln -s "$RP/phys" "$RP/lnk" || { echo "REFUSED: the link was not built" >&2; exit 9; }
P="$RP/phys/repo"; T="$RP/lnk/repo"
mkdir -p "$P/stories" && G init -q "$P" \
  && printf -- '---\nstatus: review\n---\n# S\n' > "$P/stories/s.md" && G -C "$P" add -A && G -C "$P" commit -q -m base \
  && B="$(G -C "$P" rev-parse HEAD)" \
  && printf -- '---\nstatus: review\n---\n# S\nFull-collection run: none, record-only\n' > "$P/stories/s.md" \
  && G -C "$P" add -A && G -C "$P" commit -q -m rec && F="$(G -C "$P" rev-parse HEAD)" \
  && printf 'x = 1\n' > "$P/app.py" && G -C "$P" add -A && G -C "$P" commit -q -m code && GZ="$(G -C "$P" rev-parse HEAD)" \
  || { echo "REFUSED: the repository was not seeded" >&2; exit 9; }
TP="$(cd -P "$T" && pwd -P)" || { echo "REFUSED: $T does not resolve" >&2; exit 9; }
[ "$TP" != "$T" ] && [ "$TP" = "$(cd -P "$P" && pwd -P)" ] \
  || { echo "REFUSED: the spelled top $T and its physical top $TP do not differ, or do not name the seeded repository" >&2; exit 9; }
ABS_L="$T/stories/s.md"; ABS_P="$TP/stories/s.md"
fails=0; n=0
cell() { # <cell> <want rc> <stdout|stderr> <token> <mode> <args...>
  local c="$1" w="$2" ch="$3" t="$4" rc o e; shift 4
  ( set +u +o pipefail; . "$RO" && ro_main "$@" ) > "$R/o" 2> "$R/e" < /dev/null; rc=$?
  n=$((n + 1))
  if [ "$ch" = stdout ]; then o="$R/o"; else o="$R/e"; fi
  if [ "$rc" = "$w" ] && grep -qF -- "$t" "$o"; then echo "ok $c"
  else e="$(head -1 "$R/o" "$R/e" 2> /dev/null | grep -v '^==>' | grep . | head -1)"
    echo "FAIL $c: rc=$rc (want $w with '$t' on $ch): ${e:-<no output>}"; fails=$((fails + 1)); fi
}
cell sb-abs-link   1 stdout 'already status: review' story-base -C "$T" "$ABS_L" "$B"
cell sb-rel        1 stdout 'already status: review' story-base -C "$T" stories/s.md "$B"
cell sb-dot        1 stdout 'already status: review' story-base -C "$T" ./stories/s.md "$B"
cell sb-dotslash   1 stdout 'already status: review' story-base -C "$T" .//stories/s.md "$B"
cell sb-abs-phys   1 stdout 'already status: review' story-base -C "$T" "$ABS_P" "$B"
cell sb-hosts      2 stderr 'UNEVALUABLE' story-base -C "$T" /etc/hosts "$B"
cell sb-dotcomp    2 stderr 'UNEVALUABLE' story-base -C "$T" stories/./s.md "$B"
cell sb-dblslash   2 stderr 'UNEVALUABLE' story-base -C "$T" stories//s.md "$B"
cell sb-dotdot     2 stderr 'UNEVALUABLE' story-base -C "$T" stories/../stories/s.md "$B"
cell sb-empty      2 stderr 'UNEVALUABLE' story-base -C "$T" '' "$B"
cell paths-abs-link 0 stdout 'RECORD-ONLY: 1 changed path(s)' paths -C "$T" "$ABS_L" "$B" "$F"
cell paths-abs-phys 0 stdout 'RECORD-ONLY: 1 changed path(s)' paths -C "$T" "$ABS_P" "$B" "$F"
cell paths-code    1 stdout 'first non-record path app.py' paths -C "$T" "$ABS_L" "$B" "$GZ"
cell paths-hosts   2 stderr 'UNEVALUABLE' paths -C "$T" /etc/hosts "$B" "$F"
[ "$n" = 14 ] || { echo "REFUSED: $n of 14 cells ran" >&2; exit 9; }
[ "$fails" -eq 0 ] || exit 1
exit 0
