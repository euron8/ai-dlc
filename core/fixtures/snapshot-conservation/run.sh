#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# snapshot-conservation/run.sh — prove Check 35 can tell a snapshot whose content
# was MOVED from one whose content was destroyed.
#
# THE DEFECT. Rule 25(a) says superseded snapshot content moves to a history file
# and is never deleted. Everything built around that rule measures the file's SIZE,
# and a file that got smaller looks identical whether the bytes were moved or
# dropped. Measured in the reference consumer over one sprint: 2,141 of 2,524
# substantive lines removed from the snapshot exist nowhere in the repository —
# gate dispositions, operator override citations, adversarial verdicts — while the
# byte budget passed throughout.
#
# THE ASSERTIONS THAT MATTER MOST are 2 and 7, both places where the comfortable
# reading fails OPEN:
#   2. Deleting content without moving it must FAIL. If this passes, the check is
#      decoration: every real eviction in the corpus that motivated it deleted.
#   7. A gate-metrics file that exists but cannot be parsed must exit 2, not 0.
#      Returning "nothing to compare" from a broken input is a clean line reporting
#      a verdict that was never computed.
#
# ASSERTION 1 IS NOT A FORMALITY. A conservation check that cannot go green wedges
# every sprint that legitimately trims, which is how a check gets turned off.
set -uo pipefail

# The pre-push gate inherits every AI_DLC_* tunable a consumer set in settings.json.
# A fixture that drives a validator while inheriting them tests the CONFIG, not the
# code.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"
printf 'HERMETIC-CONSUMED %s\n' "$VALIDATOR"

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }

# IN PROCESS (BL-878). The validator is loaded ONCE with lib/inproc.sh's inproc_load (its source guard returns after
# defining vsc_main) and every case asks vsc_main through inproc_run, in a subshell made to look like a fresh
# `bash validate-snapshot-conservation.sh`. The program runs only in the cli cells (cells.decl).
# A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT. A consumer can receive this file one pull before the wrapped validator, and
# sourcing a pre-wrap validator would run its whole body. So the shape is checked first, on its two halves: neither the
# `vsc_main() {` line nor the column-0 source guard is a validator that predates the wrap, which prints SKIP and exits 0
# (FIXTURE BROKEN in the distribution) -- never an ok. Exactly one half is a respelled validator this fixture cannot
# drive, which FAILS. An unreadable validator is FIXTURE ERROR.
vsc_def=0; vsc_guard=0
grep -qxF 'vsc_main() {' "$VALIDATOR"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $VALIDATOR (grep exit $_gx) -- an unreadable validator is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || vsc_def=1
grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$VALIDATOR"; _gx=$?
[ "$_gx" -le 1 ] || { echo "FIXTURE ERROR: cannot read $VALIDATOR (grep exit $_gx) -- an unreadable validator is not one that predates the wrap" >&2; exit 2; }
[ "$_gx" -ne 0 ] || vsc_guard=1
if [ "$vsc_def$vsc_guard" = 00 ]; then echo "SKIP: $VALIDATOR predates the in-process wrap"; fx_skip_exit "$HERE"; fi
if [ "$vsc_def$vsc_guard" != 11 ]; then
  bad "$VALIDATOR carries one half of the in-process wrap (vsc_main line: $vsc_def, column-0 source guard: $vsc_guard) -- a respelled validator this fixture cannot drive"
  report_end snapshot-conservation
fi
. "$HERE/../lib/inproc.sh" || { echo "FIXTURE BROKEN: cannot source lib/inproc.sh" >&2; exit 2; }
inproc_load "$VALIDATOR" || { echo "FIXTURE BROKEN: sourcing $VALIDATOR defined nothing" >&2; exit 2; }
declare -F vsc_main >/dev/null || { echo "FIXTURE BROKEN: sourcing $VALIDATOR defined no vsc_main" >&2; exit 2; }

LAST_OUT=""
# Each case gets its own copy of the seeded repository, so a working-tree edit in one
# case cannot leak into the next.
case_dir() {
  d="$WORK/case-$1"
  rm -rf "$d"
  cp -R "$PROJ" "$d" || return 1
  printf '%s' "$d"
}
# NOT a command substitution. Capturing the runner's output with `r=$(run_on ...)`
# puts it in a subshell, LAST_OUT never reaches the caller, and every message that
# quotes it prints an empty string -- which reads like the validator said nothing.
RC=""
run_on() {
  LAST_OUT="$(inproc_run "$VALIDATOR" vsc_main --root "$1" "${@:2}" 2>&1)"
  RC="$?"
}
field() { printf '%s\n' "$LAST_OUT" | sed -n "s/^$1 *: *\([^ ]*\).*/\1/p" | head -1; }

# Drop the last N of the 60 seeded OI lines out of the snapshot.
#
# The guard is not decoration. The first version of this matched on a date pattern
# that did not match what the seed writes, so it cut NOTHING -- and a fixture whose
# every case leaves the snapshot untouched reports the validator passing everything,
# which is indistinguishable from a validator with no teeth.
cut_lines() { # <dir> <count>
  d="$1"; n="$2"
  grep -- '^- OI-' "$d/_bmad-output/pipeline-snapshot.md" | tail -n "$n" > "$WORK/cut.txt"
  cut_n="$(wc -l < "$WORK/cut.txt" | tr -d ' ')"
  if [ "$cut_n" -ne "$n" ]; then
    bad "FIXTURE BROKEN: cut_lines was asked for $n lines and selected $cut_n — the case below would run against an unmodified snapshot"
    return 1
  fi
  grep -v -F -x -f "$WORK/cut.txt" "$d/_bmad-output/pipeline-snapshot.md" > "$d/snap.tmp"
  mv "$d/snap.tmp" "$d/_bmad-output/pipeline-snapshot.md"
  remaining="$(grep -c -- '^- OI-' "$d/_bmad-output/pipeline-snapshot.md" || true)"
  if [ "$remaining" -ne "$(( 60 - n ))" ]; then
    bad "FIXTURE BROKEN: after cutting $n lines the snapshot holds $remaining of the 60, not $(( 60 - n ))"
    return 1
  fi
  return 0
}

echo "snapshot-conservation:"

# --- Seed sanity: without this every assertion below compares against nothing -----
seeded="$(grep -c -- '- OI-' "$PROJ/_bmad-output/pipeline-snapshot.md" 2>/dev/null || echo 0)"
if [ "$seeded" -ne 60 ]; then
  bad "SEED BROKEN: expected 60 substantive snapshot lines, found $seeded"
  echo; echo "snapshot-conservation: $fails assertion(s) FAILED" >&2; exit 1
fi

# --- Assertion 1: content MOVED to the history file passes ----------------------
d="$(case_dir moved)"
cut_lines "$d" 50
cat "$WORK/cut.txt" >> "$d/_bmad-output/pipeline-snapshot-history.md"
run_on "$d"
r="$RC"
if [ "$r" = "0" ]; then
  ok "50 lines moved to pipeline-snapshot-history.md passes"
else
  bad "the conserved case did not pass (rc=$r) — a check that cannot go green wedges every legitimate trim: $LAST_OUT"
fi

# --- Assertion 2: content DELETED fails -----------------------------------------
# The whole release is this line. Every eviction in the corpus that motivated the
# check looked exactly like this one.
d="$(case_dir deleted)"
cut_lines "$d" 50
run_on "$d"
r="$RC"
if [ "$r" = "1" ]; then
  ok "50 lines deleted without moving them FAILS"
else
  bad "DELETION PASSED (rc=$r) — the check does not distinguish a move from a deletion, which is the only thing it exists to do: $LAST_OUT"
fi

# --- Assertion 3: the count it reports is the count that was destroyed -----------
if [ "$(field lines_destroyed)" = "50" ]; then
  ok "the deleted case reports lines_destroyed: 50"
else
  bad "expected lines_destroyed: 50, got '$(field lines_destroyed)' — the number in the message is not the number it measured"
fi

# --- Assertion 4: below the floor, destruction does not block -------------------
# Bounds the false-positive class. Rewording a handful of lines is indistinguishable
# from deleting them, and blocking on that is how a check gets switched off.
d="$(case_dir belowfloor)"
cut_lines "$d" 10
run_on "$d"
r="$RC"
if [ "$r" = "0" ]; then
  ok "10 destroyed lines stay below the floor of 40 and do not block"
else
  bad "the below-floor case blocked (rc=$r) — the floor is not bounding the false-positive class: $LAST_OUT"
fi

# --- Assertion 5: relocation WITHIN the snapshot is conservation -----------------
d="$(case_dir within)"
cut_lines "$d" 50
{ echo; echo "## Recent Activity"; cat "$WORK/cut.txt"; } >> "$d/_bmad-output/pipeline-snapshot.md"
run_on "$d"
r="$RC"
if [ "$r" = "0" ]; then
  ok "content moved to another section of the same snapshot is conserved"
else
  bad "relocation within the snapshot read as destruction (rc=$r) — the corpus excludes the file being measured: $LAST_OUT"
fi

# --- Assertion 6: a re-indented move is still a move ----------------------------
d="$(case_dir indent)"
cut_lines "$d" 50
sed 's/^/    /' "$WORK/cut.txt" >> "$d/_bmad-output/pipeline-snapshot-history.md"
run_on "$d"
r="$RC"
if [ "$r" = "0" ]; then
  ok "a move that re-indents the content is conserved"
else
  bad "re-indenting on the way to history read as destruction (rc=$r) — only one side of the comparison is normalised: $LAST_OUT"
fi

# --- Assertion 7: a metrics file that cannot be parsed is exit 2, not a pass -----
d="$(case_dir unparseable)"
printf 'not json at all\nstill not json\n' > "$d/_bmad-output/implementation-artifacts/gate-metrics.jsonl"
cut_lines "$d" 50
run_on "$d"
r="$RC"
if [ "$r" = "2" ]; then
  ok "gate-metrics.jsonl present but unparseable exits 2"
else
  bad "an unreadable metrics file returned rc=$r — a broken input must not produce a verdict: $LAST_OUT"
fi

# --- Assertion 8: no metrics file at all is NOT-APPLICABLE, and says so ----------
d="$(case_dir nometrics)"
rm -f "$d/_bmad-output/implementation-artifacts/gate-metrics.jsonl"
cut_lines "$d" 50
run_on "$d"
r="$RC"
if [ "$r" = "0" ] && grep -q 'NOT-APPLICABLE' <<<"$LAST_OUT"; then
  ok "a repository with no closed gate is NOT-APPLICABLE, not a silent pass"
else
  bad "expected rc=0 with an explicit NOT-APPLICABLE, got rc=$r: $LAST_OUT"
fi

# --- Assertion 9: the zero-control ----------------------------------------------
# `CLAUDE.md`: a run whose answer is an absence must say what it examined. Without
# these fields "nothing was destroyed" and "nothing was scanned" print the same line.
if grep -q '^base_sha' <<<"$LAST_OUT" && grep -q '^lines_destroyed' <<<"$LAST_OUT"; then
  ok "the NOT-APPLICABLE path still emits base_sha and lines_destroyed"
else
  bad "the NOT-APPLICABLE path printed no base_sha/lines_destroyed — an absence that does not report its scope"
fi

# --- Assertion 10: recorded shas that do not resolve are not an error ------------
# Measured in the reference consumer: only 10 of 34 recorded gate shas resolve. If
# an unresolvable newest sha were fatal, the check would be unrunnable at most gates.
d="$(case_dir unresolvable)"
printf '{"v":1,"sprint":300,"gate":"planning","sha":"%s","check":"14","verdict":"PASS"}\n' \
  "0000000000000000000000000000000000000000" > "$d/_bmad-output/implementation-artifacts/gate-metrics.jsonl"
cut_lines "$d" 50
run_on "$d"
r="$RC"
if [ "$r" = "0" ] && grep -q 'NOT-APPLICABLE' <<<"$LAST_OUT"; then
  ok "gate shas that resolve to nothing degrade to NOT-APPLICABLE"
else
  bad "an unresolvable gate sha returned rc=$r instead of NOT-APPLICABLE: $LAST_OUT"
fi

# --- Assertion 11: outside a git repository, exit 2 ------------------------------
d="$(case_dir nogit)"
rm -rf "$d/.git"
run_on "$d"
r="$RC"
if [ "$r" = "2" ]; then
  ok "outside a git repository the check exits 2 rather than reporting conservation"
else
  bad "a non-repository returned rc=$r — a git-derived join cannot have an opinion without history: $LAST_OUT"
fi

# --- Assertion 12: --floor is honoured ------------------------------------------
d="$(case_dir floorflag)"
cut_lines "$d" 10
run_on "$d" --floor 5
r="$RC"
if [ "$r" = "1" ]; then
  ok "--floor 5 makes the 10-line case block, so the floor is a real parameter"
else
  bad "--floor 5 did not change the verdict (rc=$r) — the floor is not wired to the comparison: $LAST_OUT"
fi

# --- The cli cells (cells.decl): the validator run as a PROGRAM once per distinct CLI outcome --
# Each `FXCELL=<id> bash` start is compared with the in-process call on the same case directory: stdout, stderr and
# exit separately, byte for byte. Outcomes: exit 0 conserved (cli-pass), exit 1 destroyed (cli-fail), exit 2 on an
# unparseable metrics file (cli-error). Each cell also asserts its own exit code, so two runs that both printed nothing
# cannot read as equivalent.
EQ="$WORK/eq"; mkdir -p "$EQ" || { echo "FIXTURE ERROR: mkdir eq" >&2; exit 2; }
eqv() { # <cell-id> <case dir> -> $EQ/<id>.{ip,cl}.{out,err,rc}
  inproc_run "$VALIDATOR" vsc_main --root "$2" > "$EQ/$1.ip.out" 2> "$EQ/$1.ip.err"; echo "$?" > "$EQ/$1.ip.rc"
  FXCELL="$1" bash "$VALIDATOR" --root "$2" > "$EQ/$1.cl.out" 2> "$EQ/$1.cl.err"; echo "$?" > "$EQ/$1.cl.rc"
  cmp -s "$EQ/$1.ip.out" "$EQ/$1.cl.out" && cmp -s "$EQ/$1.ip.err" "$EQ/$1.cl.err" && cmp -s "$EQ/$1.ip.rc" "$EQ/$1.cl.rc"
}
eq_twin() { printf 'in-process rc=%s out=[%s] err=[%s] / program rc=%s out=[%s] err=[%s]' "$(cat "$EQ/$1.ip.rc")" \
  "$(head -1 "$EQ/$1.ip.out")" "$(head -1 "$EQ/$1.ip.err")" "$(cat "$EQ/$1.cl.rc")" "$(head -1 "$EQ/$1.cl.out")" "$(head -1 "$EQ/$1.cl.err")"; }
for _cell in cli-pass:moved:0 cli-fail:deleted:1 cli-error:unparseable:2; do
  _id="${_cell%%:*}"; _rest="${_cell#*:}"; _case="${_rest%%:*}"; _want="${_rest#*:}"
  if eqv "$_id" "$WORK/case-$_case" && [ "$(cat "$EQ/$_id.cl.rc")" = "$_want" ] && { [ -s "$EQ/$_id.cl.out" ] || [ -s "$EQ/$_id.cl.err" ]; }; then
    ok "$_id: the program answers the $_case case exactly as the in-process call does (stdout, stderr, exit $_want)"
  else bad "$_id: the program and the in-process call differ on the $_case case, or the exit is not $_want ($(eq_twin "$_id"))"; fi
done

echo
report_end snapshot-conservation
