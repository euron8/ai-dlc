#!/usr/bin/env bash
# core/fixtures/suite-dispatch-order/receipt-bl901.sh [<hook>] -- the BL-901 backlog receipt: a RED full pool run
# still leaves the pole line a measurement to print.
#
# Keyed on the PRINTED LINE, which is the entry's defect. It extracts the hook's FIXTURE_POOL block and
# `pole_info_step` (the way suite-pole-info/run.sh does), drives one `run_fixtures` over a stub world of ONE
# stub, `slow`, runs `pole_info_step` against the records that run left, and asserts the whole line
# `   pole slow <N>s loaded (no prior figure for it)`. One stub makes `slow` the pole by construction, at
# whatever whole seconds it measured (0 included), so no sleep and no load decides which unit is the pole.
# Two worlds:
#   RED    the stub fails. The line must be the pole line, not "(no suite run, no pole)"; and the merged
#          record must be byte-identical to the one seeded (a red pool merges nothing).
#   GREEN  the stub passes, and creates a fixture dir `old` during its run, so the merge keeps a seeded
#          `old 900` row that this run did not time. The line must still name `slow`: a `.last` copied
#          from the merged record instead of this run's own durations would print `pole old 900s`.
# Exit 0 when every assertion holds; 1 when any fails (each prints a FAIL line); 9 when the receipt cannot
# measure its subject (no hook, an empty block, no function, no fixture root, or a world that did not run).
#
# Behaviour only: no hook line is grepped, so any spelling that publishes `.last` on a red run passes.
set -uo pipefail
r901_seam() { # walk up from $1 for the git-env seam; never count hops
  local d="$1"
  while [ -n "$d" ] && [ "$d" != "/" ] && [ "$d" != "." ]; do
    if [ -f "$d/core/fixtures/lib/preamble.sh" ]; then printf '%s\n' "$d"; return 0; fi
    d="$(dirname "$d")"
  done
  return 1
}
ROOT="$(r901_seam "$(cd "$(dirname "$0")" && pwd)")" || ROOT=""
[ -n "$ROOT" ] || { echo "REFUSED: no core/fixtures/lib/preamble.sh above $0" >&2; exit 9; }
. "$ROOT/core/fixtures/lib/preamble.sh"
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
unset PREPUSH_POOL_DEPTH
HOOK="${1:-$ROOT/.githooks/pre-push}"
[ -f "$HOOK" ] || { echo "REFUSED: no hook at $HOOK" >&2; exit 9; }
T="$(mktemp -d "${TMPDIR:-/tmp}/bl901.XXXXXX")" || exit 9
[ -d "$T" ] || exit 9
trap 'rm -rf "$T"' EXIT
sed -n '/^# FIXTURE_POOL_BEGIN$/,/^# FIXTURE_POOL_END$/p' "$HOOK" > "$T/block.sh"
[ -s "$T/block.sh" ] || { echo "REFUSED: empty FIXTURE_POOL block in $HOOK" >&2; exit 9; }
awk '/^pole_info_step\(\) \{/{f=1} f{print} f&&/^\}/{exit}' "$HOOK" > "$T/pole.sh"
grep -q '^pole_info_step() {' "$T/pole.sh" || { echo "REFUSED: pole_info_step not extractable from $HOOK" >&2; exit 9; }
FXR="$(sed -n 's|^FXROOT="\([A-Za-z0-9_./-]*\)/"$|\1|p' "$T/block.sh" | sort -u)"
[ "$(printf '%s\n' "$FXR" | grep -c .)" -eq 1 ] || { echo "REFUSED: fixture root read as '$FXR', need exactly one" >&2; exit 9; }

# world <name> <stub exit code> <extra stub line> -> builds $T/<name>, drives one run_fixtures there,
# prints the pole_info_step output to $T/<name>.pole and leaves the pool's rc in $T/<name>.rc
world() {
  local n="$1" slow_rc="$2" extra="$3" W="$T/$1"
  mkdir -p "$W/$FXR/slow" || exit 9
  printf '#!/usr/bin/env bash\n%s\nexit %s\n' "$extra" "$slow_rc" > "$W/$FXR/slow/run.sh"
  ( cd "$W" && git init -q . && git add -A && git -c user.email=r@r -c user.name=r commit -qm seed ) > /dev/null 2>&1
  [ -d "$W/.git" ] || { echo "REFUSED: the $n world is not a repository" >&2; exit 9; }
  printf 'slow 5\nold 900\n' > "$W/.git/ai-dlc-fixture-durations"
  cp "$W/.git/ai-dlc-fixture-durations" "$T/$n.seed"
  ( cd "$W" && export AI_DLC_FIXTURE_JOBS=2 AI_DLC_READSET_LIVE_TRACE=0 AI_DLC_FIXTURE_NO_SKIP=1 \
      AI_DLC_VERDICT_STORE="$T/$n.store" R901_WORLD="$W" \
    && bash -c '. "$1" > /dev/null 2>&1; run_fixtures > "$2" 2>&1; echo $? > "$3"
                SUITE_STOPPED_EARLY=0; SUITE_SKIPPED=0; . "$4"; pole_info_step > "$5" 2>&1' \
         _ "$T/block.sh" "$T/$n.out" "$T/$n.rc" "$T/pole.sh" "$T/$n.pole" ) > /dev/null 2>&1
  [ -s "$T/$n.rc" ] && [ -f "$T/$n.pole" ] || { echo "REFUSED: the $n world did not run to a pole line" >&2; exit 9; }
}
world red 1 ':'
world green 0 'mkdir -p "$R901_WORLD/'"$FXR"'/old" && : > "$R901_WORLD/'"$FXR"'/old/run.sh"'

rc=0
[ "$(cat "$T/red.rc")" != 0 ] || { echo "REFUSED: the red world's pool came back green" >&2; exit 9; }
[ "$(cat "$T/green.rc")" = 0 ] || { echo "REFUSED: the green world's pool came back red" >&2; exit 9; }
[ -f "$T/green/$FXR/old/run.sh" ] || { echo "REFUSED: the green world's stub did not create old/run.sh" >&2; exit 9; }
WANT='^   pole slow [0-9]+s loaded \(no prior figure for it\)$'
if [ "$(grep -c . "$T/red.pole")" -eq 1 ] && grep -Eq "$WANT" "$T/red.pole"; then :; else
  rc=1; echo "FAIL: RED world pole line is '$(tr '\n' '|' < "$T/red.pole")', want the slow stub's pole line"
fi
cmp -s "$T/red.seed" "$T/red/.git/ai-dlc-fixture-durations" || { rc=1; echo "FAIL: TWIN a red pool changed the merged durations record"; }
if [ "$(grep -c . "$T/green.pole")" -eq 1 ] && grep -Eq "$WANT" "$T/green.pole"; then :; else
  rc=1; echo "FAIL: GREEN world pole line is '$(tr '\n' '|' < "$T/green.pole")', want the slow stub's pole line, not a row this run did not time"
fi
[ "$rc" = 0 ] && echo "PASS: a red pool leaves .last, the pole line names the unit this run timed, and the merged record is untouched"
exit "$rc"
