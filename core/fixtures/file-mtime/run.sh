#!/usr/bin/env bash
# file-mtime -- core/scripts/file-mtime.sh states a file's mtime as an epoch and an ISO UTC stamp.
#
# Usage: run.sh        Exit: 0 = every assertion holds, 1 = a regression, 2 = fixture broken.
#
# THE ORACLE IS A LITERAL. Files are seeded with `TZ=UTC touch -t 202610160459.42`, so the
# expected answer is the constant 2026-10-16T04:59:42Z / 1792126782 and nothing in this
# fixture computes it with the tool under test. It is asserted under TZ=America/New_York as
# well as TZ=UTC, because a local-time format agrees with UTC in exactly one of the two.
#
# THE NUMERIC-BASENAME WORLD. BSD `date -r` reads an all-digit argument as an epoch, so a
# file NAMED 1792126782 with a 2020 mtime must report 2020, not the time its name spells.
# The script is invoked with the bare relative name from inside the directory, because an
# absolute path is never all-digit and would not discriminate.
#
# THE STAT-SHAPE WORLD. A `stat` shim answers `-f` the way GNU does (filesystem text, exit
# 0) and `-c %Y` with the seeded epoch. Only a shape check passes; an exit-code probe takes
# the filesystem text as the epoch.
#
# Each mutant is a literal replace that must match exactly once, is guarded by cmp -s, and
# must be killed by its arm. A mutant that no arm can kill on this platform is reported
# SKIP with the reason, never counted as killed.
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
SUBJ=""
for c in "$HERE/../../scripts/file-mtime.sh" "$HERE/../../../scripts/ai-dlc/file-mtime.sh"; do
  [ -f "$c" ] && { SUBJ="$c"; break; }
done
[ -n "$SUBJ" ] || { echo "FIXTURE ERROR: cannot locate file-mtime.sh in either layout" >&2; exit 2; }
SUBJ="$(cd "$(dirname "$SUBJ")" && pwd)/$(basename "$SUBJ")"
echo "HERMETIC-CONSUMED $SUBJ"

WORK="$(mktemp -d)" || exit 2
trap 'rm -rf "$WORK"' EXIT
fails=0
ok()  { printf '   ok    %s\n' "$1"; }
bad() { printf '   FAIL  %s\n' "$1" >&2; fails=$((fails + 1)); }

W="$WORK/w"; N="$WORK/n"; SHIM="$WORK/shim"; MUT="$WORK/mut"
mkdir -p "$W" "$N" "$SHIM" "$MUT"
TZ=UTC touch -t 202610160459.42 "$W/rec.md"
TZ=UTC touch -t 202001020304.05 "$N/1792126782"

LIT_E=1792126782; LIT_I=2026-10-16T04:59:42Z
NUM_E=1577934245; NUM_I=2020-01-02T03:04:05Z

# A GNU-shaped stat: `-f` is --file-system (text, exit 0); `-c %Y` is the mtime.
cat > "$SHIM/stat" <<EOF
#!/bin/sh
case "\$1" in
  -f) echo "  File: \"\$3\""; echo "    ID: 0 Namelen: 255 Type: ext2/ext3"; exit 0 ;;
  -c) echo 1792126782; exit 0 ;;
esac
exit 1
EOF
chmod +x "$SHIM/stat"

# run <script> <tz> <dir> <args...> -> OUT, RC
run() {
  local s="$1" tz="$2" d="$3"; shift 3
  OUT="$(cd "$d" && TZ="$tz" bash "$s" "$@" 2>&1)"; RC=$?
}
run_shim() {
  local s="$1"
  OUT="$(cd "$W" && TZ=UTC PATH="$SHIM:$PATH" bash "$s" rec.md 2>&1)"; RC=$?
}
TAB="$(printf '\t')"

# --- arms, each a function of the script under test, so a mutant reuses it -----------
arm_utc()   { run "$1" UTC "$W" rec.md;                    [ "$RC" -eq 0 ] && [ "$OUT" = "rec.md${TAB}${LIT_E}${TAB}${LIT_I}" ]; }
arm_ny()    { run "$1" America/New_York "$W" rec.md;       [ "$RC" -eq 0 ] && [ "$OUT" = "rec.md${TAB}${LIT_E}${TAB}${LIT_I}" ]; }
arm_num()   { run "$1" America/New_York "$N" 1792126782;   [ "$RC" -eq 0 ] && [ "$OUT" = "1792126782${TAB}${NUM_E}${TAB}${NUM_I}" ]; }
arm_shape() { run_shim "$1";                               [ "$RC" -eq 0 ] && [ "$OUT" = "rec.md${TAB}${LIT_E}${TAB}${LIT_I}" ]; }
arm_miss()  {
  run "$1" UTC "$W" nope.md rec.md
  [ "$RC" -eq 1 ] && [ "$OUT" = "nope.md${TAB}MISSING
rec.md${TAB}${LIT_E}${TAB}${LIT_I}" ]
}
arm_noargs() { OUT="$(bash "$1" 2>&1)"; RC=$?; [ "$RC" -eq 2 ]; }

echo "== real script"
arm_utc   "$SUBJ" && ok "UTC: literal epoch and ISO stamp"                    || bad "UTC arm: rc=$RC out=[$OUT]"
arm_ny    "$SUBJ" && ok "America/New_York: same literal stamp"                 || bad "NY arm: rc=$RC out=[$OUT]"
arm_num   "$SUBJ" && ok "all-digit basename reports its mtime, not its name"   || bad "numeric-basename arm: rc=$RC out=[$OUT]"
arm_shape "$SUBJ" && ok "GNU-shaped stat -f (exit 0, text) is not taken as an epoch" || bad "stat-shape arm: rc=$RC out=[$OUT]"
arm_miss  "$SUBJ" && ok "MISSING path: reported, others still stated, exit 1"  || bad "MISSING arm: rc=$RC out=[$OUT]"
arm_noargs "$SUBJ" && ok "no arguments: exit 2"                                || bad "no-args arm: rc=$RC out=[$OUT]"

# --- mutants: literal replace, exactly once, cmp -s guarded, killed by its arm -------
# mutate <name> <old> <new> [<old> <new>] -> writes $MUT/<name>.sh or sets MUTFAIL
mutate() {
  local name="$1"; shift
  local f="$MUT/$name.sh"; cp "$SUBJ" "$f"
  while [ $# -ge 2 ]; do
    local o="$1" n="$2"; shift 2
    local cnt; cnt="$(grep -cF -- "$o" "$f")" || cnt=0
    if [ "$cnt" -ne 1 ]; then echo "FIXTURE ERROR: mutant $name: pattern matched $cnt times: $o" >&2; exit 2; fi
    local content out; content="$(cat "$f")"
    out=${content/"$o"/"$n"}   # assignment, not an expansion in double quotes: bash 3.2 keeps those quotes literal
    printf '%s\n' "$out" > "$f"
  done
  if cmp -s "$SUBJ" "$f"; then echo "FIXTURE ERROR: mutant $name is byte-identical to the subject" >&2; exit 2; fi
}
kill_by() { # <name> <arm> -- the arm must PASS on the subject (above) and FAIL here
  if "$2" "$MUT/$1.sh"; then bad "mutant $1 SURVIVED arm $2"; else ok "mutant $1 killed by $2"; fi
}

echo "== mutants"
mutate nolocal 'date -u -r "$1"' 'date -r "$1"' 'date -u -d "@$1"' 'date -d "@$1"'
kill_by nolocal arm_ny

mutate exitcode '_e="$(stat -f %m "$1" 2>/dev/null)"' '_e="$(stat -f %m "$1" 2>/dev/null)" && { printf "%s" "$_e"; return 0; }'
kill_by exitcode arm_shape

mutate missok 'exit "$rc"' 'exit 0'
kill_by missok arm_miss

mutate datepath 'ep="$(mtime_epoch "$p")"' 'ep="$(date -r "$p" +%s)"'
if [ "$(cd "$N" && date -r 1792126782 +%s 2>/dev/null)" = "1792126782" ]; then
  kill_by datepath arm_num
else
  echo "   SKIP  mutant datepath: this date does not read an all-digit path as an epoch, so no arm can kill it here"
fi

if [ "$fails" -gt 0 ]; then echo "file-mtime: $fails FAILED" >&2; exit 1; fi
echo "file-mtime: all arms ok"
exit 0
