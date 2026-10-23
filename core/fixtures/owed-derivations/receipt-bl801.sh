#!/usr/bin/env bash
# Receipt: in MUT mode the LIVING-sweep battery runs ONLY the worlds that hold a mutant's required arms,
# and every required arm's world (as one unit) DOES run.
# Usage: receipt-bl801.sh [<run.sh>]   (default: the run.sh beside this file)
# DRIVES the fixture's own code: it sources the lines between run.sh's `lw-harness: begin` and
# `lw-harness: end` markers (the world filter, the reader drivers and lw_all), builds the world -> arm
# map with one real pass, then runs lw_all in mut mode against a STUB reader that appends
# `<root basename> <mode>` per invocation to a log (mode: rd a record run, batch a --scope-batch run,
# lone the apply.sh-shaped copy). It asserts EXACT set equality of that log:
#   required S14 -> {ls14 rd}; required G1 -> {ls15 rd}; required S10 -> {ls1 batch, ls3 batch, ls1 lone}
# and that neither pass printed a FIXTURE BROKEN line.
# 0 = all three sets are exact | 1 = any set differs, or a BROKEN line | 9 = no verdict (no run.sh, no
#     marked block, or the scratch world could not be built).
set -uo pipefail
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done
HERE="$(cd "$(dirname "$0")" && pwd)"
SUBJ="${1:-$HERE/run.sh}"
[ -f "$SUBJ" ] || { echo "REFUSED: no run.sh at $SUBJ" >&2; exit 9; }
D="$(mktemp -d "${TMPDIR:-/tmp}/bl801rcpt.XXXXXX")" || { echo "REFUSED: mktemp" >&2; exit 9; }
trap '[ -n "$D" ] && [ -d "$D" ] && rm -rf "$D"' EXIT
_nb="$(grep -c '^# ---- lw-harness: begin' "$SUBJ")"; _ne="$(grep -c '^# ---- lw-harness: end' "$SUBJ")"
_lb="$(grep -n '^# ---- lw-harness: begin' "$SUBJ" | head -1 | cut -d: -f1)"; _le="$(grep -n '^# ---- lw-harness: end' "$SUBJ" | head -1 | cut -d: -f1)"
{ [ "$_nb" = 1 ] && [ "$_ne" = 1 ] && [ "$_lb" -lt "$_le" ]; } 2>/dev/null || { echo "REFUSED: run.sh must hold exactly one lw-harness begin and one end marker, begin first" >&2; exit 9; }
sed -n '/^# ---- lw-harness: begin/,/^# ---- lw-harness: end/p' "$SUBJ" > "$D/harness.sh"
grep -c '^lw_all() {' "$D/harness.sh" > "$D/n" 2>/dev/null
[ "$(cat "$D/n")" = 1 ] || { echo "REFUSED: run.sh carries no marked lw-harness block holding lw_all" >&2; exit 9; }

# The names the block reads from run.sh's seeding, given inert values: roots are named by their run.sh
# basename (LS4C -> ls4c), every key and command is a placeholder the stub never reads.
WORK="$D"; LIN="x"; LPRD="x"; LCMD="x"; LUNC="x"; C14="x"; TAB="$(printf '\t')"
for _n in $(grep -o 'LS[0-9A-Z]*' "$D/harness.sh" | sort -u); do
  printf -v "$_n" '%s' "$D/$(printf '%s' "$_n" | tr 'A-Z' 'a-z')"
done
for _n in $(grep -o 'K_[0-9A-Z_]*' "$D/harness.sh" | sort -u); do printf -v "$_n" '%s' "x:1"; done
: > "$D/core-paths.sh"; : > "$D/sprint-status.sh"; : > "$D/sprint-status.json"
COREPATHS="$D/core-paths.sh"; SPRINTSTATUS="$D/sprint-status.sh"; SSSCHEMA="$D/sprint-status.json"
write_stub() { : > "$1/sprint-status.sh"; }
open_count() { echo 0; }
BROKEN=0
ok() { :; }
bad() { case "$1" in *"FIXTURE BROKEN"*) BROKEN=$((BROKEN + 1)); printf 'BROKEN: %s\n' "$1" >&2 ;; esac; }
LOG="$D/inv.log"
STUB="$D/stub-reader.sh"
printf '#!/usr/bin/env bash\nm=rd\n[ "${1:-}" = --scope-batch ] && m=batch\ncase "$0" in */lone/*) m=lone ;; esac\nprintf "%%s %%s\\n" "${AI_DLC_PROJECT_ROOT##*/}" "$m" >> "%s"\nexit 0\n' "$LOG" > "$STUB" || exit 9
# shellcheck disable=SC1090
. "$D/harness.sh" || { echo "REFUSED: the lw-harness block did not source" >&2; exit 9; }

LW_MODE=real; lw_all "$STUB" real > /dev/null 2>&1
[ "$BROKEN" = 0 ] || { echo "FAIL: the real pass printed FIXTURE BROKEN" >&2; exit 1; }
LW_MODE=mut
fails=0
probe() { # <required set> <expected set, one entry per line>
  : > "$LOG"
  LW_REQ="$1"; LW_FAILED=""; LW_SEEN=" "; lw_all "$STUB" "p$((++_np))" > /dev/null 2>&1
  local got want
  got="$(LC_ALL=C sort -u "$LOG")"; want="$(printf '%s\n' "$2" | LC_ALL=C sort -u)"
  if [ "$got" = "$want" ]; then printf 'ok    required %s ran exactly: %s\n' "$1" "$(printf '%s' "$got" | tr '\n' ',')"
  else printf 'FAIL  required %s ran: %s (expected: %s)\n' "$1" "$(printf '%s' "$got" | tr '\n' ',')" "$(printf '%s' "$want" | tr '\n' ',')"; fails=$((fails + 1)); fi
}
_np=0
probe S14 "ls14 rd"
probe G1 "ls15 rd"
probe S10 "ls1 batch
ls3 batch
ls1 lone"
[ "$BROKEN" = 0 ] || { echo "FAIL: a mut pass printed FIXTURE BROKEN" >&2; fails=$((fails + 1)); }
[ "$fails" = 0 ] && exit 0
exit 1
