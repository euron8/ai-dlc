#!/usr/bin/env bash
# BL-815 receipt (a capture cited by a `./`, `../` or absolute spelling is judged or named, never skipped). Usage:
#   bash receipt-bl815.sh <path to validate-handoff-evidence.sh>
# Drives the validator over one scratch repository whose stories live under stories/, so a story-directory
# reading and the toplevel reading of a relative token name DIFFERENT paths: every relative token resolves
# from the TOPLEVEL (`./x` is `x`, `a/../b` is `b`, a leading `../` climbs out and is unresolvable). Every
# tracked capture below is in range and carries NO command line, so arm (a) refusing it `no-command` is the
# proof that it reached the arms; a WARN alone fails such a cell.
#   inner   `test-results/sub/../cn-in.txt`, tracked as test-results/cn-in.txt -> REFUSED no-command
#   abs     `<physical toplevel>/test-results/cn-abs.txt`, tracked       -> REFUSED no-command
#   alias   `<symlinked alias of the toplevel>/test-results/cn-al.txt`   -> REFUSED no-command
#   ctl     `test-results/cn-ctl.txt`, tracked, the toplevel spelling    -> REFUSED no-command (unchanged control)
#   dd      `../test-results/cn-dd.txt`; test-results/cn-dd.txt IS tracked, so the story-directory reading
#           would judge it -> WARN capture-unresolved, resolves outside the repository (cells dd, dd-reason)
#   ddtop   the toplevel path of dd                                     -> nothing (no no-command line)
#   ddred   `../test-results/cn-dd-mutation-red.txt`, RED, tracked at the story-dir reading -> REFUSED red-untracked
#   un      `evidence/cn-never.txt`, untracked, not ignored              -> WARN capture-unresolved, not tracked at <sha12>
#   ign     `test-results/cn-ignored.txt`, untracked, ignored by the frozen .gitignore -> nothing
#   ow      `<another worktree>/test-results/cn-ow.txt`                 -> WARN capture-unresolved, resolves outside
#   climb   `../../cn-climb.txt` (above the toplevel)                    -> WARN capture-unresolved, resolves outside
#   owred   `<another worktree>/cn-ow-mutation-red.txt`, RED             -> REFUSED red-untracked, naming the outside spelling
#   rc      a second story citing only `un` and `ign`, labels present   -> exit 0 (the WARN never changes the exit)
#   lc      --list-captures over the first story                         -> lists cn-abs, cn-al, cn-ctl, cn-in only
#   xr      CROSS-READER: a third story citing ONE token, `./test-results/cn-x.txt` (tracked, no command line).
#           --list-captures must list exactly test-results/cn-x.txt AND the handoff arms must print exactly
#           `REFUSED no-command test-results/cn-x.txt:` -- the two readers agree on the one spelling.
#   gu      story-2 again with a PATH shim whose `git ls-tree -r --name-only --full-tree` fails: the frozen
#           .gitignore set cannot be read -> exactly one `WARN gitignore-unreadable <sha12>: exemption set
#           unknown`, the set is treated as EMPTY (un AND ign both WARN not-tracked), exit still 0; the
#           unshimmed story-2 run prints no gitignore-unreadable line (the shim is what fired it).
# 0 = every cell answered as above. 1 = a cell did not (one `FAIL <cell>` line each). 9 = the receipt could not run.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
[ "$#" -eq 1 ] && [ -f "$1" ] \
  || { echo "REFUSED: usage: bash receipt-bl815.sh <path to validate-handoff-evidence.sh>" >&2; exit 9; }
HE="$1"
[ -f "$(dirname "$HE")/record-only-diff.sh" ] || { echo "REFUSED: no record-only-diff.sh beside $HE" >&2; exit 9; }
R="$(mktemp -d "${TMPDIR:-/tmp}/receipt-bl815.XXXXXX")" || exit 9
trap 'rm -rf "$R"' EXIT
R="$(cd -P "$R" && pwd -P)" || exit 9
W="$R/w"
g() { GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1 git -C "$W" -c user.name=r -c user.email=r@example.invalid \
  -c commit.gpgsign=false -c core.hooksPath=/dev/null "$@"; }
mkdir -p "$W/stories" "$W/test-results" "$R/other-wt/test-results" || exit 9
ln -s "$W" "$R/alias" || exit 9
g init -q || exit 9
printf 'test-results/cn-ignored.txt\n' > "$W/.gitignore"
LABELS='Full-collection run: `pytest -q` from the root, 1 passed.
Dependency setup: none, system pytest.'
printf -- '---\nstatus: review\n---\n# Story 1\n\n%s\n' "$LABELS" > "$W/stories/story-1.md"
cp "$W/stories/story-1.md" "$W/stories/story-2.md"
cp "$W/stories/story-1.md" "$W/stories/story-3.md"
g add -A && g commit -qm base || exit 9
B="$(g rev-parse HEAD)"
for n in cn-in cn-dd cn-abs cn-al cn-dd-mutation-red cn-ctl cn-x; do printf 'no command line here\n5 passed\n' > "$W/test-results/$n.txt"; done
{ printf -- '---\nstatus: review\n---\n# Story 1\n\n%s\n\n## Dev Agent Record\n\n' "$LABELS"
  printf -- '- inner: `test-results/sub/../cn-in.txt`\n- dd: `../test-results/cn-dd.txt`\n'
  printf -- '- abs: `%s/test-results/cn-abs.txt`\n- alias: `%s/test-results/cn-al.txt`\n' "$W" "$R/alias"
  printf -- '- ddred: `../test-results/cn-dd-mutation-red.txt`\n- ctl: `test-results/cn-ctl.txt`\n'
  printf -- '- un: `evidence/cn-never.txt`\n- ign: `test-results/cn-ignored.txt`\n'
  printf -- '- ow: `%s/test-results/cn-ow.txt`\n- climb: `../../cn-climb.txt`\n' "$R/other-wt"
  printf -- '- owred: `%s/cn-ow-mutation-red.txt`\n' "$R/other-wt"
} > "$W/stories/story-1.md"
printf -- '---\nstatus: review\n---\n# Story 2\n\n%s\n\nLocal: `evidence/cn-never.txt`, `test-results/cn-ignored.txt`.\n' "$LABELS" > "$W/stories/story-2.md"
printf -- '---\nstatus: review\n---\n# Story 3\n\n%s\n\nEvidence: `./test-results/cn-x.txt`.\n' "$LABELS" > "$W/stories/story-3.md"
printf 'local\n' > "$W/test-results/cn-ignored.txt"
g add -A && g commit -qm frozen || exit 9
T="$(g rev-parse HEAD)"
# Seed controls: the story-directory reading of every `../` token is NOT a tracked path, and its toplevel
# reading after the strip IS -- so the two readings name different files and the cells can tell them apart.
for p in test-results/cn-dd.txt test-results/cn-dd-mutation-red.txt test-results/cn-x.txt test-results/cn-in.txt; do
  g cat-file -e "${T}:$p" 2>/dev/null || { echo "REFUSED: seed $p is not tracked" >&2; exit 9; }
done
g cat-file -e "${T}:stories/test-results/cn-x.txt" 2>/dev/null && { echo "REFUSED: seed stories/test-results/cn-x.txt is tracked" >&2; exit 9; }
o="$(bash "$HE" -C "$W" stories/story-1.md "$B" "$T" 2>/dev/null)"
[ -n "$o" ] || { echo "REFUSED: the validator printed nothing for story-1" >&2; exit 9; }
fails=0
# cell <name> <token as printed> <want: the kinds of every REFUSED/WARN line naming that token, `-` for none>
cell() {
  local got
  got="$(awk -v t="$2" '($1 == "REFUSED" || $1 == "WARN") && index($0, " " t ":") {print $2}' <<<"$o" | sort | tr '\n' ',')"
  got="${got%,}"; [ -n "$got" ] || got=-
  [ "$got" = "$3" ] || { echo "FAIL $1: want [$3] got [$got]"; fails=$((fails + 1)); }
}
# The token as the line prints it: (a) prints the toplevel path, the WARN and (b) print the token.
cell inner test-results/cn-in.txt                 no-command
cell abs   test-results/cn-abs.txt                no-command
cell alias test-results/cn-al.txt                 no-command
cell ctl   test-results/cn-ctl.txt                no-command
cell dd    ../test-results/cn-dd.txt              capture-unresolved
cell ddtop test-results/cn-dd.txt                 -
cell ddred ../test-results/cn-dd-mutation-red.txt red-untracked
cell un    evidence/cn-never.txt                  capture-unresolved
cell ign   test-results/cn-ignored.txt            -
cell ow    "$R/other-wt/test-results/cn-ow.txt"   capture-unresolved
cell climb ../../cn-climb.txt                     capture-unresolved
cell owred "$R/other-wt/cn-ow-mutation-red.txt"   red-untracked
# Reasons, by exact line prefix.
grep -qxF "WARN capture-unresolved ../test-results/cn-dd.txt: resolves outside the repository" <<<"$o" \
  || { echo "FAIL dd-reason: no 'resolves outside the repository' line for the leading ../ token"; fails=$((fails + 1)); }
grep -qxF "WARN capture-unresolved evidence/cn-never.txt: not tracked at ${T:0:12}" <<<"$o" \
  || { echo "FAIL un-reason: no 'not tracked at ${T:0:12}' line"; fails=$((fails + 1)); }
grep -qxF "WARN capture-unresolved $R/other-wt/test-results/cn-ow.txt: resolves outside the repository" <<<"$o" \
  || { echo "FAIL ow-reason: no 'resolves outside the repository' line"; fails=$((fails + 1)); }
grep -qF "REFUSED red-untracked $R/other-wt/cn-ow-mutation-red.txt: cited as a mutation-RED capture by a spelling that resolves outside the repository" <<<"$o" \
  || { echo "FAIL owred-reason: the refusal does not name the outside spelling"; fails=$((fails + 1)); }
o2="$(bash "$HE" -C "$W" stories/story-2.md "$B" "$T" 2>/dev/null)"; rc=$?
{ [ "$rc" -eq 0 ] && grep -qxF "WARN capture-unresolved evidence/cn-never.txt: not tracked at ${T:0:12}" <<<"$o2"; } \
  || { echo "FAIL rc: want exit 0 with the un WARN, got exit $rc"; fails=$((fails + 1)); }
lc="$(bash "$HE" -C "$W" --list-captures stories/story-1.md "$T" 2>/dev/null | tr '\n' ' ')"
want='test-results/cn-abs.txt test-results/cn-al.txt test-results/cn-ctl.txt test-results/cn-in.txt '
[ "$lc" = "$want" ] || { echo "FAIL lc: want [$want] got [$lc]"; fails=$((fails + 1)); }
# xr: both readers over ONE story and ONE `./` token, each asserted as an exact value.
xl="$(bash "$HE" -C "$W" --list-captures stories/story-3.md "$T" 2>/dev/null | tr '\n' ' ')"
xh="$(bash "$HE" -C "$W" stories/story-3.md "$B" "$T" 2>/dev/null | awk '$1 == "REFUSED" || $1 == "WARN"' | cut -d: -f1 | tr '\n' ' ')"
[ "$xl|$xh" = "test-results/cn-x.txt |REFUSED no-command test-results/cn-x.txt " ] \
  || { echo "FAIL xr: the readers disagree on ./test-results/cn-x.txt: list-captures [$xl] handoff [$xh]"; fails=$((fails + 1)); }
# gu: a git shim refusing only the exemption reader's ls-tree spelling; every other git call passes through.
RG="$(command -v git)" || exit 9
mkdir -p "$R/shim" || exit 9
printf '#!/bin/sh\ncase " $* " in *" ls-tree -r --name-only --full-tree "*) echo "shim: ls-tree refused" >&2; exit 128 ;; esac\nexec "%s" "$@"\n' "$RG" > "$R/shim/git" \
  && chmod +x "$R/shim/git" || exit 9
gw="WARN gitignore-unreadable ${T:0:12}: exemption set unknown"
o3="$(PATH="$R/shim:$PATH" bash "$HE" -C "$W" stories/story-2.md "$B" "$T" 2>/dev/null)"; rc3=$?
gn="$(grep -cxF "$gw" <<<"$o3")" || gn=0
{ [ "$rc3" -eq 0 ] && [ "$gn" -eq 1 ] \
  && grep -qxF "WARN capture-unresolved evidence/cn-never.txt: not tracked at ${T:0:12}" <<<"$o3" \
  && grep -qxF "WARN capture-unresolved test-results/cn-ignored.txt: not tracked at ${T:0:12}" <<<"$o3" \
  && ! grep -q 'gitignore-unreadable' <<<"$o2"; } \
  || { echo "FAIL gu: want exit 0, one [$gw], un and ign WARN not-tracked, none unshimmed; got exit $rc3, $gn cause line(s): $(tr '\n' ' ' <<<"$o3")"; fails=$((fails + 1)); }
[ "$fails" -eq 0 ] || exit 1
exit 0
