#!/usr/bin/env bash
# file-mtime -- core/scripts/file-mtime.sh states a file's mtime as an epoch and an ISO UTC stamp.
#
# Usage: run.sh [--matrix]        Exit: 0 = every assertion holds, 1 = a regression, 2 = fixture broken.
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
#
# THE MUTANT MATRIX (mutant-battery rule). Every mutant could be scored on all six arms. PER PUSH a mutant scores
# only its DECIDING arm and its named TWIN (an arm it could plausibly co-trip and does not); with --matrix it
# scores every arm and prints one `MATRIX <mutant> <arm> KILLED|GREEN` row per pair. The block below is the one
# source: mx_cell reads it from this file, a plain run refuses a mutant with no row, and a cell whose result
# disagrees with its row is a failure. An arm token is the arm's base-pass flag name without the B_ prefix.
#
# RE-MEASURE whenever an arm or a mutant is added or changed. hermetic-run.sh runs a fixture under `env -i` and
# forwards no argument, so the matrix is NOT reached through it; run.sh is invoked directly from the repo root.
# MUTANT-MATRIX-REMEASURE bash core/fixtures/file-mtime/run.sh --matrix
# MUTANT-MATRIX nolocal decides=ny,num twins=utc
# MUTANT-MATRIX exitcode decides=shape twins=utc
# MUTANT-MATRIX missok decides=miss twins=utc
# MUTANT-MATRIX datepath decides=num twins=utc
#
# A MATRIX row is a measurement and not a second kill emission: its kill goes through mutant_killed behind the
# same base-pass flag the arm sets. The mutant name reaches mutant_killed as a variable:
# MUTANT-MATRIX-DYNAMIC mx_cell why=passes each of the four mutant names below as a variable and every name keeps its own row
set -uo pipefail
MATRIX=0
for _a in "$@"; do
  case "$_a" in
    --matrix) MATRIX=1 ;;
    *) echo "FIXTURE ERROR: unknown argument '$_a' (only --matrix)" >&2; exit 2 ;;
  esac
done
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
MUT_LIB="$(cd "$HERE/../lib" 2>/dev/null && pwd)/mutant.sh"
[ -f "$MUT_LIB" ] || { echo "FIXTURE ERROR: lib/mutant.sh not found beside $HERE" >&2; exit 2; }
. "$MUT_LIB"
echo "HERMETIC-CONSUMED core/fixtures/lib/mutant.sh"

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
# Each arm sets its B_<arm> flag only in its passing branch; the mutant that arm kills is scored on it.
if arm_utc "$SUBJ"; then ok "UTC: literal epoch and ISO stamp"; B_utc=1
else bad "UTC arm: rc=$RC out=[$OUT]"; fi
if arm_ny "$SUBJ"; then ok "America/New_York: same literal stamp"; B_ny=1
else bad "NY arm: rc=$RC out=[$OUT]"; fi
if arm_num "$SUBJ"; then ok "all-digit basename reports its mtime, not its name"; B_num=1
else bad "numeric-basename arm: rc=$RC out=[$OUT]"; fi
if arm_shape "$SUBJ"; then ok "GNU-shaped stat -f (exit 0, text) is not taken as an epoch"; B_shape=1
else bad "stat-shape arm: rc=$RC out=[$OUT]"; fi
if arm_miss "$SUBJ"; then ok "MISSING path: reported, others still stated, exit 1"; B_miss=1
else bad "MISSING arm: rc=$RC out=[$OUT]"; fi
if arm_noargs "$SUBJ"; then ok "no arguments: exit 2"; B_noargs=1
else bad "no-args arm: rc=$RC out=[$OUT]"; fi

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
MX_SRC="$HERE/run.sh"; MX_CELLS=0; MX_RUN=0; MX_SEEN=""
mx_row() { grep -m 1 -F -- "# MUTANT-MATRIX $1 decides=" "$MX_SRC"; } # no awk: the tool farm of this fixture does not declare it
mx_role() { # <mutant> <arm> -> D (decides), T (twin) or - (neither), read from the header block
  local line d tw; line="$(mx_row "$1")"
  [ -n "$line" ] || { echo -; return; }
  d="${line#*decides=}"; d="${d%% *}"; tw="${line#*twins=}"; tw="${tw%% *}"
  case ",$d," in *",$2,"*) echo D; return ;; esac
  case ",$tw," in *",$2,"*) echo T; return ;; esac
  echo -
}
mx_has_row() { [ -n "$(mx_row "$1")" ]; }
# mx_cell <mutant> <arm> <arm fn> <the arm's base-pass flag> -- score the mutant on one arm: the arm FAILING on the
# mutant is KILLED, holding is GREEN.
mx_cell() {
  local m="$1" t="$2" fn="$3" fl="$4" role
  case " $MX_SEEN " in
    *" $m "*) ;;
    *) MX_SEEN="$MX_SEEN $m"
       if [ "$MATRIX" != 1 ] && ! mx_has_row "$m"; then
         bad "mutant $m has no MUTANT-MATRIX row in $MX_SRC -- a per-push run cannot know its deciding arm or its twins"
       fi ;;
  esac
  role="$(mx_role "$m" "$t")"
  if [ "$MATRIX" != 1 ] && [ "$role" = - ]; then return 0; fi
  [ "$role" = - ] && MX_CELLS=$((MX_CELLS + 1))
  MX_RUN=$((MX_RUN + 1))
  if "$fn" "$MUT/$m.sh"; then
    ok "MATRIX $m $t GREEN"
    if [ "$MATRIX" != 1 ] && [ "$role" = D ]; then bad "mutant $m SURVIVED arm $t, which the header names as its deciding arm"; fi
  else
    mutant_killed "$fl" "$m" "MATRIX $m $t KILLED"
    if [ "$MATRIX" != 1 ] && [ "$role" = T ]; then bad "mutant $m failed arm $t, which the header names as its twin"; fi
  fi
  return 0
}
mx_all() { # <mutant> -- every arm, in arm order
  mx_cell "$1" utc    arm_utc    "${B_utc:-0}"
  mx_cell "$1" ny     arm_ny     "${B_ny:-0}"
  mx_cell "$1" num    arm_num    "${B_num:-0}"
  mx_cell "$1" shape  arm_shape  "${B_shape:-0}"
  mx_cell "$1" miss   arm_miss   "${B_miss:-0}"
  mx_cell "$1" noargs arm_noargs "${B_noargs:-0}"
}

echo "== mutants"
mutate nolocal 'date -u -r "$1"' 'date -r "$1"' 'date -u -d "@$1"' 'date -d "@$1"'
mx_all nolocal

mutate exitcode '_e="$(stat -f %m "$1" 2>/dev/null)"' '_e="$(stat -f %m "$1" 2>/dev/null)" && { printf "%s" "$_e"; return 0; }'
mx_all exitcode

mutate missok 'exit "$rc"' 'exit 0'
mx_all missok

mutate datepath 'ep="$(mtime_epoch "$p")"' 'ep="$(date -r "$p" +%s)"'
if [ "$(cd "$N" && date -r 1792126782 +%s 2>/dev/null)" = "1792126782" ]; then
  mx_all datepath
else
  echo "   SKIP  mutant datepath: this date does not read an all-digit path as an epoch, so no arm can kill it here"
fi

# MX0: a plain run executes no matrix-only cell; --matrix scores every cell and says how many.
if [ "$MATRIX" = 1 ]; then
  echo "MATRIX MODE: $MX_RUN cells"
  if [ "$MX_RUN" -gt 0 ]; then ok "MX0 matrix mode: $MX_RUN cells scored"; else bad "MX0 matrix mode: --matrix scored no cell"; fi
elif [ "$MX_CELLS" -eq 0 ]; then ok "MX0 per-push run: matrix-only cells run = 0 (cells scored: $MX_RUN)"
else bad "MX0 per-push run: $MX_CELLS matrix-only cell(s) ran"; fi

if [ "$fails" -gt 0 ]; then echo "file-mtime: $fails FAILED" >&2; exit 1; fi
echo "file-mtime: all arms ok"
exit 0
