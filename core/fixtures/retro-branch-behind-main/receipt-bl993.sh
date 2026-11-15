#!/usr/bin/env bash
# receipt-bl993.sh [retro.md] [deploy-validate.md] -- the BL-993 receipt. Deploy-validate Step 2's
# record block writes the sprint PR number, its head and its squash sha to the sprint branch, and
# retro Step 1 reads that record instead of deriving the PR head. Each cell builds a world here,
# extracts the shipping blocks from the two step files and RUNS them (never a grep of the prose).
#
# Every world is the RE-POINTED shape: the sprint branch is reset onto its own squash and committed
# on afterwards, so no sprint tree equals a trunk tree and the tree match finds nothing. A gh stub on
# PATH logs every call and exits 97, so any retro that asks gh fails and the log shows it asked.
#
#   record     the deploy-validate block, run on the re-pointed sprint branch with PR #7, its head P
#              and squash M. PASS when it prints `RECORD: PR #7 ...committed at <path>` and the
#              sprint tip holds exactly `7 P M` at that path.
#   carry      retro Step 1 on that branch after three more commits. PASS on exactly
#              `CARRY: 4 commit(s) past PR head P (merged PR #7, from the sprint-merge record) ...`
#              (the record commit and the three) with the gh log empty.
#   norecord   the same world with the record block never run. PASS when Step 1 prints
#              `CARRY: HARD_BLOCK underivable` and the gh log is non-empty: the world cannot be
#              carried without the record, so the carry cell's pass is the record's doing.
#   badrecord  the same world with a hand-committed record whose squash is not on origin/main.
#              PASS when Step 1 prints `CARRY: HARD_BLOCK underivable — the sprint-merge record`
#              and the gh log is empty: a refused record is never overridden by a derivation.
#   statedir   record and carry with AI_DLC_STATE_DIR=state. PASS when the record is at
#              state/implementation-artifacts/s900/, absent at the default path, and Step 1 carries
#              from it with the gh log empty.
#
# Exit 0 when every cell PASSes, 1 when any FAILs, 9 when it cannot measure: no retro.md, no
# Step 1 block in it, no deploy-validate.md, or a world that did not build. The step files are $1
# and $2, else the ones found by walking up from this file in either layout. Invoked by run.sh.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY

HERE="$(cd "$(dirname "$0")" && pwd)"
RETRO="${1:-}"
DV="${2:-}"
d="$HERE"
while [ -n "$d" ] && [ "$d" != "/" ] && { [ -z "$RETRO" ] || [ -z "$DV" ]; }; do
  for l in core .claude; do
    [ -z "$RETRO" ] && [ -f "$d/$l/skills/ai-dlc/steps/retro.md" ] && RETRO="$d/$l/skills/ai-dlc/steps/retro.md"
    [ -z "$DV" ] && [ -f "$d/$l/skills/ai-dlc/steps/deploy-validate.md" ] && DV="$d/$l/skills/ai-dlc/steps/deploy-validate.md"
  done
  d="$(dirname "$d")"
done
[ -n "$RETRO" ] && [ -f "$RETRO" ] || { echo "receipt-bl993: no retro.md (given: ${1:-none}; none found above $HERE)" >&2; exit 9; }
[ -n "$DV" ] && [ -f "$DV" ] || { echo "receipt-bl993: no deploy-validate.md (given: ${2:-none}; none found above $HERE)" >&2; exit 9; }
grep -q '^# retro Step 1: cut the retro branch' "$RETRO" || { echo "receipt-bl993: $RETRO has no '# retro Step 1:' block" >&2; exit 9; }
command -v git >/dev/null 2>&1 || { echo "receipt-bl993: git not on PATH" >&2; exit 9; }

W="$(mktemp -d)" || exit 9
W="$(cd "$W" && pwd -P)"
trap 'rm -rf "$W"' EXIT
SB=ai-dlc/sprint-900
REC=_bmad-output/implementation-artifacts/s900/sprint-pr-merge.txt
fail=0
die() { echo "receipt-bl993: $1" >&2; exit 9; }
gi() { git -c init.defaultBranch=main init -q "$1" && cfg "$1"; }
cfg() { git -C "$1" config user.email r@example.com && git -C "$1" config user.name Receipt \
        && git -C "$1" config commit.gpgsign false; }
cm() { git -C "$1" add -A && git -C "$1" commit -q -m "$2"; }

mkdir -p "$W/gh" || exit 9
cat > "$W/gh/gh" <<'STUB'
#!/bin/bash
printf '%s\n' "$*" >> "$(dirname "$0")/calls"
exit 97
STUB
chmod +x "$W/gh/gh" || exit 9

awk '/^### 1\. Context Loading/{s=1} s && /^### 2\./{exit}
     s && /^# retro Step 1:/{on=1} on && /^```$/{exit} on{print}' "$RETRO" \
  | sed -e "s@<sprint-branch>@$SB@g" -e 's@<N>@900@g' > "$W/step1.sh"
[ -s "$W/step1.sh" ] || die "the Step 1 block did not extract from $RETRO"
awk '/^# deploy-validate Step 2: record the sprint-PR merge$/{on=1} on && /^```$/{exit} on{print}' "$DV" > "$W/record.tmpl"

# world <name> <none|block|bad> -> builds $W/<name>-c (the retro clone) and sets P, M, ROUT. A non-empty
# SD is the AI_DLC_STATE_DIR the record block and Step 1 run under; empty runs both on the default.
SD=""
world() {
  local n="$1" mode="$2" s="$W/$1-src" r="$W/$1-remote.git" dc="$W/$1-d"
  mkdir -p "$s/gl" || die "$n: mkdir"
  gi "$s" || die "$n: init"
  printf 'REVISION 1\n' > "$s/gl/log.md"; cm "$s" C1 || die "$n: C1"
  git -C "$s" checkout -q -b "$SB" || die "$n: branch"
  printf 'REVISION 1\nREVISION 2\n' > "$s/gl/log.md"; cm "$s" "PR head" || die "$n: P"
  P="$(git -C "$s" rev-parse HEAD)"
  git -C "$s" checkout -q main && git -C "$s" merge -q --squash "$SB" >/dev/null 2>&1 && cm "$s" "squash" || die "$n: squash"
  M="$(git -C "$s" rev-parse HEAD)"
  git clone -q --bare "$s" "$r" 2>/dev/null || die "$n: bare clone"
  git -C "$r" update-ref refs/keep/p "$P" || die "$n: keep ref"
  git clone -q "file://$r" "$dc" 2>/dev/null && cfg "$dc" || die "$n: deploy clone"
  git -C "$dc" checkout -q -b "$SB" "origin/$SB" && git -C "$dc" reset -q --hard "$M" || die "$n: re-point"
  ROUT=""
  case "$mode" in
    block)
      sed -e 's@<N>@900@g' -e 's@<pr-number>@7@g' -e "s@<pr-head>@$P@g" -e "s@<squash>@$M@g" \
        "$W/record.tmpl" > "$W/$n-record.sh" || die "$n: record block"
      ROUT="$( cd "$dc" && env ${SD:+AI_DLC_STATE_DIR="$SD"} bash "$W/$n-record.sh" 2>&1 )" ;;
    bad)
      mkdir -p "$dc/$(dirname "$REC")" && printf '7 %s %s\n' "$P" 0123456789abcdef0123456789abcdef01234567 > "$dc/$REC" \
        && cm "$dc" "hand-written record" || die "$n: bad record" ;;
  esac
  for k in 1 2 3; do echo "$k" > "$dc/post-$k.txt"; cm "$dc" "post-squash $k" || die "$n: post $k"; done
  git -C "$dc" push -q origin "+$SB" 2>/dev/null || die "$n: push sprint"
  git -C "$s" checkout -q main && echo t > "$s/t.txt" && cm "$s" "trunk after" || die "$n: trunk"
  git -C "$r" fetch -q "$s" +main:main 2>/dev/null || die "$n: remote advance"
  git clone -q "file://$r" "$W/$n-c" 2>/dev/null && cfg "$W/$n-c" || die "$n: retro clone"
  git -C "$W/$n-c" checkout -q -b "$SB" "origin/$SB" || die "$n: sprint checkout"
  git -C "$W/$n-c" fetch -q origin refs/keep/p 2>/dev/null && git -C "$W/$n-c" cat-file -e "$P^{commit}" || die "$n: PR head not local"
}
step1() { # <name> -> Step 1's output; the gh log is $W/gh/calls
  rm -f "$W/gh/calls"
  ( cd "$W/$1-c" && PATH="$W/gh:$PATH" env ${SD:+AI_DLC_STATE_DIR="$SD"} bash "$W/step1.sh" 2>&1 )
}
ghcalls() { if [ -s "$W/gh/calls" ]; then echo asked; else echo silent; fi; }

# ---- record + carry ---------------------------------------------------------------------------
if [ ! -s "$W/record.tmpl" ]; then
  echo "CELL record FAIL $DV has no '# deploy-validate Step 2: record the sprint-PR merge' block"; fail=1
  echo "CELL carry FAIL no record block to write the record retro Step 1 reads"; fail=1
else
  world rec block
  have="$(git -C "$W/rec-c" show "origin/$SB:$REC" 2>/dev/null)"
  if grep -qxF "RECORD: PR #7 head $P squash $M committed at $REC" <<<"$ROUT" && [ "$have" = "7 $P $M" ]; then
    echo "CELL record PASS the deploy-validate block committed '7 <head> <squash>' at $REC on the sprint branch"
  else
    echo "CELL record FAIL block printed [$(grep -m1 '^RECORD: ' <<<"$ROUT" || echo 'no RECORD line')], tip holds [${have:-nothing}]"; fail=1
  fi
  cout="$(step1 rec)"; g="$(ghcalls)"
  want="CARRY: 4 commit(s) past PR head $P (merged PR #7, from the sprint-merge record) carried onto the retro branch"
  if grep -qxF "$want" <<<"$cout" && [ "$g" = silent ]; then
    echo "CELL carry PASS Step 1 carried the record commit and 3 more from the PR head the record names, and never asked gh"
  else
    echo "CELL carry FAIL gh $g; $(grep -m1 '^CARRY: ' <<<"$cout" || echo 'no CARRY line')"; fail=1
  fi
fi

# ---- norecord ---------------------------------------------------------------------------------
world norec none
cout="$(step1 norec)"; g="$(ghcalls)"
if grep -q '^CARRY: HARD_BLOCK underivable' <<<"$cout" && [ "$g" = asked ]; then
  echo "CELL norecord PASS with no record the re-pointed branch is underivable and Step 1 asked gh"
else
  echo "CELL norecord FAIL gh $g; $(grep -m1 '^CARRY: ' <<<"$cout" || echo 'no CARRY line')"; fail=1
fi

# ---- badrecord --------------------------------------------------------------------------------
world bad bad
cout="$(step1 bad)"; g="$(ghcalls)"
if grep -q '^CARRY: HARD_BLOCK underivable — the sprint-merge record' <<<"$cout" && [ "$g" = silent ]; then
  echo "CELL badrecord PASS a record whose squash is not on origin/main is refused by name, and gh is never asked"
else
  echo "CELL badrecord FAIL gh $g; $(grep -m1 '^CARRY: ' <<<"$cout" || echo 'no CARRY line')"; fail=1
fi
# ---- statedir ---------------------------------------------------------------------------------
if [ -s "$W/record.tmpl" ]; then
  SD=state
  world sd block
  have="$(git -C "$W/sd-c" show "origin/$SB:state/implementation-artifacts/s900/sprint-pr-merge.txt" 2>/dev/null)"
  dflt="$(git -C "$W/sd-c" show "origin/$SB:$REC" 2>/dev/null)"
  cout="$(step1 sd)"; g="$(ghcalls)"
  SD=""
  want="CARRY: 4 commit(s) past PR head $P (merged PR #7, from the sprint-merge record) carried onto the retro branch"
  if [ "$have" = "7 $P $M" ] && [ -z "$dflt" ] && grep -qxF "$want" <<<"$cout" && [ "$g" = silent ]; then
    echo "CELL statedir PASS under AI_DLC_STATE_DIR=state the record is written and read at state/, never at the default"
  else
    echo "CELL statedir FAIL state/ holds [${have:-nothing}], default holds [${dflt:-nothing}], gh $g; $(grep -m1 '^CARRY: ' <<<"$cout" || echo 'no CARRY line')"; fail=1
  fi
else
  echo "CELL statedir FAIL no record block to run under a non-default AI_DLC_STATE_DIR"; fail=1
fi
exit "$fail"
