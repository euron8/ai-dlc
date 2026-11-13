#!/usr/bin/env bash
# receipt-bl997.sh [retro.md] -- the BL-997 receipt. Both landing sites in retro.md move the checkout
# onto main at origin/main: Step 1's carry block and 7a-post step 1's LAND block. A path origin/main
# tracks and HEAD does not, held on disk as an operator's IGNORED file, is overwritten by
# `git checkout main && git merge --ff-only origin/main` with exit 0. Each cell builds a world here,
# extracts the shipping block from retro.md and RUNS it (never a grep of the prose).
#
#   step1-ignored  Step 1 on a sprint branch already on origin/main, with `e.log`, `é.log` and
#                  `sub/x.log` ignored (`*.log`) and holding the operator's bytes, each force-added
#                  upstream. PASS when the block prints a `CARRY: HARD_BLOCK on-disk` line, names all
#                  three paths on `ON-DISK ` lines, all three files still hold the operator's bytes,
#                  and HEAD is still the sprint branch.
#   step1-clean    the same world with no file on disk: PASS on
#                  `CARRY: none — the sprint tip is already on origin/main` (the guard does not over-fire).
#   land-ignored   the LAND block on a retro branch, the same three ignored files. PASS when it prints
#                  a `LAND: HARD_BLOCK on-disk` line naming all three, exits non-zero, keeps the bytes,
#                  and leaves HEAD on the retro branch.
#   land-clean     the same world with no file on disk: PASS on `LAND: main at origin/main`.
#   land-untracked an UNTRACKED, non-ignored `u.txt` upstream adds: git itself refuses that one, so the
#                  control is that the bytes survive and the block does not report landing.
#
# FALSE-POSITIVE SET, by construction: the check prints only paths that a `git checkout main` or a fast-forward
# to origin/main would WRITE (tracked there, absent from HEAD) and that are on disk. For such a path git either
# overwrites the file (ignored) or refuses (untracked), so the only move the check stops that git would have
# allowed is the ignored overwrite, which is the defect. The clean twins are the measured side: no on-disk
# path, no refusal.
#
# Exit 0 when every cell PASSes, 1 when any FAILs, 9 when it cannot measure. The retro.md is $1, else
# the one found by walking up from this file in either layout. Invoked by run.sh.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

HERE="$(cd "$(dirname "$0")" && pwd)"
RETRO="${1:-}"
if [ -z "$RETRO" ]; then
  d="$HERE"
  while [ -n "$d" ] && [ "$d" != "/" ]; do
    for c in "$d/core/skills/ai-dlc/steps/retro.md" "$d/.claude/skills/ai-dlc/steps/retro.md"; do
      [ -f "$c" ] && { RETRO="$c"; break 2; }
    done
    d="$(dirname "$d")"
  done
fi
[ -n "$RETRO" ] && [ -f "$RETRO" ] || { echo "receipt-bl997: no retro.md (given: ${1:-none}; none found above $HERE)" >&2; exit 9; }
command -v git >/dev/null 2>&1 || { echo "receipt-bl997: git not on PATH" >&2; exit 9; }

W="$(mktemp -d)" || exit 9
W="$(cd "$W" && pwd -P)"
trap 'rm -rf "$W"' EXIT
SB=ai-dlc/sprint-900
RB=ai-dlc/retro/sprint-900
fail=0
die() { echo "receipt-bl997: $1" >&2; exit 9; }
gi() { git -c init.defaultBranch=main init -q "$1" && git -C "$1" config user.email r@example.com \
       && git -C "$1" config user.name Receipt && git -C "$1" config commit.gpgsign false; }
cm() { git -C "$1" add -A && git -C "$1" commit -q -m "$2"; }
LOGS='e.log é.log sub/x.log'

awk '/^### 1\. Context Loading/{s=1} s && /^### 2\./{exit}
     s && /^# retro Step 1:/{on=1} on && /^```$/{exit} on{print}' "$RETRO" \
  | sed -e "s@<sprint-branch>@$SB@g" -e 's@<N>@900@g' > "$W/step1.sh"
[ -s "$W/step1.sh" ] || die "the Step 1 block did not extract from $RETRO"
awk '/^# retro 7a-post step 1: land on the merged trunk$/{on=1} on && /^```$/{exit} on{print}' "$RETRO" > "$W/land.sh"
[ -s "$W/land.sh" ] || die "the 7a-post step 1 LAND block did not extract from $RETRO"

# world <name> <branch to stand on> <seed: logs|none|untracked> -> $W/<name>/c, a clone whose
# origin/main (after the block's own fetch) force-adds the three logs and adds u.txt.
world() {
  local n="$1" br="$2" seed="$3" s="$W/$1/src" c="$W/$1/c" p
  mkdir -p "$s" || exit 9
  gi "$s" || die "$n: init"
  printf '*.log\n' > "$s/.gitignore"; echo c1 > "$s/a.txt"; cm "$s" C1 || die "$n: C1"
  git -C "$s" branch "$SB" || die "$n: sprint branch"
  git clone -q --bare "$s" "$W/$n/remote.git" 2>/dev/null || die "$n: bare clone"
  git clone -q "file://$W/$n/remote.git" "$c" 2>/dev/null || die "$n: clone"
  git -C "$c" config user.email r@example.com; git -C "$c" config user.name Receipt; git -C "$c" config commit.gpgsign false
  case "$br" in
    sprint) git -C "$c" checkout -q -b "$SB" "origin/$SB" || die "$n: sprint checkout" ;;
    retro)  git -C "$c" checkout -q -b "$RB" && echo r > "$c/r.txt" && cm "$c" "retro work" || die "$n: retro branch" ;;
  esac
  # Upstream force-adds the ignored paths and adds a plain file, after the clone was taken.
  mkdir -p "$s/sub"
  for p in $LOGS; do printf 'UPSTREAM\n' > "$s/$p"; done
  echo upstream > "$s/u.txt"
  git -C "$s" add -f -- e.log é.log sub/x.log u.txt && git -C "$s" commit -q -m "force-add logs" || die "$n: upstream"
  git -C "$W/$n/remote.git" fetch -q "$s" +main:main 2>/dev/null || die "$n: remote advance"
  case "$seed" in
    logs) mkdir -p "$c/sub"; for p in $LOGS; do printf 'OPERATOR\n' > "$c/$p"; done
          for p in $LOGS; do git -C "$c" check-ignore -q -- "$p" || die "$n: $p is not ignored in the world"; done ;;
    untracked) echo operator > "$c/u.txt"
          git -C "$c" check-ignore -q -- u.txt && die "$n: u.txt is ignored in the world" ;;
  esac
}
kept() { # <clone> -> 0 when all three logs still hold the operator's bytes
  local p
  for p in $LOGS; do [ "$(cat "$1/$p" 2>/dev/null)" = OPERATOR ] || return 1; done
}
named() { # <output> -> 0 when every log is on an ON-DISK line
  local p
  for p in $LOGS; do grep -qxF "ON-DISK $p" <<<"$1" || return 1; done
}
cell() { if [ "$2" = 0 ]; then echo "CELL $1 PASS $3"; else echo "CELL $1 FAIL $4"; fail=1; fi; }

world s-ign sprint logs; world s-cln sprint none
world l-ign retro logs;  world l-cln retro none; world l-unt retro untracked

o="$( cd "$W/s-ign/c" && bash "$W/step1.sh" 2>&1 )"; hd="$(git -C "$W/s-ign/c" symbolic-ref -q --short HEAD)"
grep -q '^CARRY: HARD_BLOCK on-disk' <<<"$o" && named "$o" && kept "$W/s-ign/c" && [ "$hd" = "$SB" ]
cell step1-ignored $? "Step 1 refuses before the checkout, names e.log, é.log and sub/x.log, and the operator's bytes survive" \
  "head=$hd kept=$(kept "$W/s-ign/c" && echo y || echo n) $(grep -m1 '^CARRY: ' <<<"$o" || echo 'no CARRY line')"

o="$( cd "$W/s-cln/c" && bash "$W/step1.sh" 2>&1 )"
grep -qxF 'CARRY: none — the sprint tip is already on origin/main' <<<"$o"
cell step1-clean $? "with nothing on disk Step 1 lands and reports no carry" "$(grep -m1 '^CARRY: ' <<<"$o" || echo 'no CARRY line')"

o="$( cd "$W/l-ign/c" && bash "$W/land.sh" 2>&1 )"; rc=$?; hd="$(git -C "$W/l-ign/c" symbolic-ref -q --short HEAD)"
grep -q '^LAND: HARD_BLOCK on-disk' <<<"$o" && named "$o" && kept "$W/l-ign/c" && [ "$rc" != 0 ] && [ "$hd" = "$RB" ]
cell land-ignored $? "the LAND block refuses non-zero before the checkout, names all three paths, and the operator's bytes survive" \
  "rc=$rc head=$hd kept=$(kept "$W/l-ign/c" && echo y || echo n) $(grep -m1 '^LAND: ' <<<"$o" || echo 'no LAND line')"

o="$( cd "$W/l-cln/c" && bash "$W/land.sh" 2>&1 )"
grep -qxF 'LAND: main at origin/main' <<<"$o"
cell land-clean $? "with nothing on disk the LAND block lands on main" "$(grep -m1 '^LAND: ' <<<"$o" || echo 'no LAND line')"

o="$( cd "$W/l-unt/c" && bash "$W/land.sh" 2>&1 )"
[ "$(cat "$W/l-unt/c/u.txt")" = operator ] && ! grep -qxF 'LAND: main at origin/main' <<<"$o"
cell land-untracked $? "an untracked, non-ignored u.txt keeps its bytes and the block does not report landing" \
  "u.txt=$(cat "$W/l-unt/c/u.txt") $(grep -m1 '^LAND: ' <<<"$o" || echo 'no LAND line')"
exit "$fail"
