#!/usr/bin/env bash
. "$(cd "$(dirname "$0")/../lib" && pwd)/preamble.sh" || { echo "FIXTURE BROKEN: cannot source lib/preamble.sh" >&2; exit 2; }
# Exercise the anchor-declaration checks in validate-layer-entries.sh: E7 (a `shadows:` anchor
# must FORWARD-match a heading), E8 (`reason:` required), E9 (`push_candidate:` required), and
# E3's widening to every comma-part of `shadows:`.
#
# TWO OF THESE ASSERTIONS EXIST BECAUSE THE FIRST DRAFT SHIPPED THE BUG:
#
#   1. The old code ran `sed 's/,.*//'` on `shadows:` and validated only the FIRST comma-part.
#      Measured on the reference consumer, one override declares five anchors and got one file
#      check and ZERO anchor checks. `multi` below is valid in part one and broken in part two, so
#      a first-part-only reader calls it clean.
#
#   2. The loop was written as `printf | tr | while`, and a pipeline runs its last stage in a
#      SUBSHELL — so every err() incremented a counter in a child process and threw it away. The
#      ERROR lines printed and the footer counted ONE of THREE: a validator that reports a real
#      violation and then exits zero. `count-matches-lines` is the guard, and it is not a style
#      check — loud and non-blocking is the worst of the two failure directions.
set -u
DIR="$(cd "$(dirname "$0")" && pwd)"

# Both layouts: distribution has the validator at core/scripts/, a consumer at scripts/ai-dlc/
# (install.sh relocates it, and fixtures move to tests/fixtures/, which is THREE levels up).
VLE=""; LOOKED=""
for cand in \
  "$DIR/../../scripts/validate-layer-entries.sh" \
  "$DIR/../../../core/scripts/validate-layer-entries.sh" \
  "$DIR/../../../scripts/ai-dlc/validate-layer-entries.sh"; do
  LOOKED="$LOOKED  $cand
"
  [ -f "$cand" ] && VLE="$cand" && break
done
[ -n "$VLE" ] || { printf 'FAIL: cannot locate validate-layer-entries.sh from %s. Looked in:\n%s' "$DIR" "$LOOKED"; exit 1; }

VLE_DIR="$(cd "$(dirname "$VLE")" && pwd)"
printf 'HERMETIC-CONSUMED %s/validate-layer-entries.sh\n' "$VLE_DIR"
[ -f "$VLE_DIR/artifact-path-config.sh" ] && printf 'HERMETIC-CONSUMED %s/artifact-path-config.sh\n' "$VLE_DIR"

# IN PROCESS (BL-878). The validator is SOURCED ONCE into this shell (its guard returns after defining vle_main), and
# every drive calls vle_main inside a subshell, so its `exit`, `set -u`, EXIT trap and function definitions stay there.
# It starts as a program only in the cli cell (cells.decl). A CORE FIXTURE SHIPS AHEAD OF ITS SUBJECT: a subject with
# neither its `vle_main() {` line nor the column-0 source guard predates the wrap and reads SKIP (exit 0, never an ok);
# exactly one half is a respelled subject and FAILs; a subject grep cannot READ (exit 2) is FIXTURE ERROR.
wrap_gate() { # wrap_gate <file> <entry> -> 0 wrapped, 3 predates the wrap, 1 one half only (FAIL printed), 2 unreadable
  local d g
  grep -q "^$2() {\$" "$1"; d=$?
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$1"; g=$?
  if [ "$d" -gt 1 ] || [ "$g" -gt 1 ]; then
    echo "FIXTURE ERROR: cannot read $1 (grep exit $d/$g), so the in-process wrap cannot be judged; nothing was asserted" >&2
    return 2
  fi
  [ "$d$g" = 00 ] && return 0
  [ "$d$g" = 11 ] && return 3
  if [ "$d" = 1 ]; then echo "  FAIL  $1 carries the column-0 source guard but no \`$2() {\` line -- a respelled subject this fixture cannot drive"
  else echo "  FAIL  $1 defines \`$2() {\` but carries no column-0 source guard -- a respelled subject; sourcing it would run $2 in this shell"; fi
  return 1
}
wrap_gate "$VLE" vle_main; g_vle=$?
[ "$g_vle" = 2 ] && exit 2
[ "$g_vle" = 1 ] && { echo "FAIL: 1 of 1 assertions wrong."; exit 1; }
[ "$g_vle" = 3 ] && { echo "SKIP: subject predates the in-process wrap"; exit 0; }

CONS="$(bash "$DIR/seed.sh")"
trap 'rm -rf "$(dirname "$CONS")"' EXIT

. "$DIR/../lib/mutant.sh" || { echo "FIXTURE ERROR: lib/mutant.sh not found" >&2; exit 2; }
fx_inproc "$VLE"
. "$VLE" || { echo "FIXTURE ERROR: sourcing $VLE failed" >&2; exit 2; }
declare -F vle_main > /dev/null || { echo "FIXTURE ERROR: sourcing $VLE defined no vle_main" >&2; exit 2; }

# One in-process run is the fixture's one state: its output feeds every row, its exit the counter guard.
OUT="$( ( fx_inproc "$VLE"; vle_main "$CONS" ) 2>&1)"; rc=$?

FAILURES=0
ASSERTIONS=0

# $1 entry-substring  $2 expected-substring in the row (or "CLEAN")  $3 why. Returns 1 when the row FAILs, so a
# caller may capture $?.
row() {
  local ent="$1" want="$2" why="$3" got
  ASSERTIONS=$((ASSERTIONS + 1))
  got="$(printf '%s\n' "$OUT" | grep -F "$ent" | grep '^ERROR' || true)"
  if [ "$want" = CLEAN ]; then
    if [ -z "$got" ]; then
      printf '  ok    %-26s no error  (%s)\n' "$ent" "$why"
    else
      FAILURES=$((FAILURES + 1))
      printf '  FAIL  %-26s errored but must not  (%s)\n' "$ent" "$why"
      printf '%s\n' "$got" | sed 's/^/          | /'
      return 1
    fi
  elif grep -qF "$want" <<<"$got"; then
    printf '  ok    %-26s %s  (%s)\n' "$ent" "$want" "$why"
  else
    FAILURES=$((FAILURES + 1))
    printf '  FAIL  %-26s wanted "%s"  (%s)\n' "$ent" "$want" "$why"
    printf '%s\n' "${got:-<no error row>}" | sed 's/^/          | /'
    return 1
  fi
}

echo "layer-anchor-declaration fixture"
echo

# THE DIFFERENTIAL. Same file, same kind of anchor, opposite verdicts — and the ONLY difference is
# which direction the containment resolves.
row "SKILL__Rule-8.md"                 CLEAN \
  "a heading CONTAINING the anchor is the legitimate id-prefix grain"
row "team-roles__tea__escalation.md"   "Escalation" \
  "E7 — an anchor CONTAINING the heading resolves only by the reverse arm and silently widens the shadow"

# The error must hand over the fix, not just the diagnosis: a consumer cannot act on "wrong" but
# can act on "write it as this".
ASSERTIONS=$((ASSERTIONS + 1))
if printf '%s\n' "$OUT" | grep -F 'team-roles__tea__escalation.md' | grep -q "Write the anchor as 'Escalation'"; then
  printf '  ok    %-26s names the exact heading to substitute\n' "remedy-is-actionable"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-26s reported the defect without the heading to replace it with\n' "remedy-is-actionable"
fi

row "steps__retro__ghost.md"           "matches no heading" \
  "E7 — an anchor matching nothing means the body never reaches the lead while checks report green"

# THE BLIND SPOT. Part one is valid; part two is not. A first-part-only reader sees nothing.
row "steps__retro__multi.md"           "Empirical gate validation" \
  "E3 — every comma-part is validated, not just the first"

# THE SECOND BLIND SPOT, inside the fix for the first. The per-part widening still computed the
# target per part, so a part that inherits its file computed an EMPTY one and was skipped before
# any anchor check ran. Measured on the reference consumer: 1 of 4 anchors checked, 3 skipped.
# The wanted substring is the ANCHOR arm's wording, not the anchor text. The target-less arm below
# quotes the whole part — `#No Such Inherited Heading` — so a bare anchor-text match is satisfied by
# an entry that resolved no file at all, and the assertion would pass while the fix was reverted.
# Mutation 3 caught exactly that.
row "steps__retro__inherit.md"         "Inherited Heading' matches no heading in steps/retro.md" \
  "E3 — a bare '#anchor' part inherits the file from the part before it and is still anchor-checked"
row "steps__retro__orphan.md"          "names no target file" \
  "E3 — a first part with no file has nothing to inherit, and silence there skips every check on the entry"

row "SKILL__Rule-9.md"                 "missing 'reason:'" \
  "E8 — reason: was declared by the contract and read by nothing"
row "no-flag.md"                       "missing 'push_candidate:'" \
  "E9 — push_candidate: was declared by the contract and read by nothing"
row "ok-extension.md"                  CLEAN \
  "a well-formed extension stays silent, so the two above are attributable"

# THE COUNTER GUARD. Every ERROR line must be counted, or the exit code does not match what the
# operator was just shown.
ASSERTIONS=$((ASSERTIONS + 1))
lines="$(printf '%s\n' "$OUT" | grep -c '^ERROR' || true)"
counted="$(printf '%s\n' "$OUT" | sed -n 's/^validate-layer-entries: \([0-9]*\) error(s).*/\1/p')"
if [ "$lines" = "$counted" ] && [ "$rc" -ne 0 ]; then
  printf '  ok    %-26s %s ERROR lines, footer says %s, exit %s\n' "count-matches-lines" "$lines" "$counted" "$rc"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-26s %s ERROR lines but footer says %s and exit is %s — a reported violation that does not block\n' "count-matches-lines" "$lines" "$counted" "$rc"
fi

# THE CLI CELL (cells.decl): the validator run as a PROGRAM once, for the one CLI outcome this fixture reads (exit 1 on
# the seeded consumer), compared byte for byte with an in-process call on the same input: stdout, stderr and exit.
ASSERTIONS=$((ASSERTIONS + 1))
EQ="$(dirname "$CONS")/eq"; mkdir -p "$EQ" || exit 2
( fx_inproc "$VLE"; vle_main "$CONS" ) > "$EQ/ip.out" 2> "$EQ/ip.err"; echo "$?" > "$EQ/ip.rc"
FXCELL=cli-fail bash "$VLE" "$CONS" > "$EQ/cl.out" 2> "$EQ/cl.err"; echo "$?" > "$EQ/cl.rc"
if cmp -s "$EQ/ip.out" "$EQ/cl.out" && cmp -s "$EQ/ip.err" "$EQ/cl.err" && cmp -s "$EQ/ip.rc" "$EQ/cl.rc" \
   && [ "$(cat "$EQ/cl.rc")" = 1 ] && grep -q '^ERROR' "$EQ/cl.out"; then
  printf '  ok    %-26s the program refuses the seed exactly as the in-process call does (stdout, stderr, exit 1)\n' "cli-fail"
else
  FAILURES=$((FAILURES + 1))
  printf '  FAIL  %-26s the program and the in-process call differ, or the outcome is not exit 1 with an ERROR: in-process rc=%s program rc=%s\n' "cli-fail" "$(cat "$EQ/ip.rc")" "$(cat "$EQ/cl.rc")"
fi
echo
if [ "$FAILURES" -gt 0 ]; then
  echo "FAIL: $FAILURES of $ASSERTIONS assertions wrong."
  exit 1
fi
echo "PASS: all $ASSERTIONS assertions correct."
exit 0
