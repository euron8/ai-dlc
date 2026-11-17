#!/usr/bin/env bash
# known-skills-extension/run.sh — prove the consumer known_skills extension point.
#
# WHY THIS EXISTS. known_skills in provenance-block.json is a CORE list. A consumer with its own
# party-persona skill (whose real invocation emits a provenance block citing it) had no
# layer-correct way to register the name — editing the core schema in place was the only option,
# which /ai-dlc-update now flags as HARD-UNREGISTERED-CORE-DRIFT (schemas are scanned). This proves
# extensions/known-skills.json is the additive, drift-free alternative.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="$(bash "$HERE/seed.sh")" || { echo "FIXTURE ERROR: seed failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT
# shellcheck source=/dev/null
. "$WORK/env.sh"
echo "HERMETIC-CONSUMED $VALIDATOR"

# IN PROCESS (BL-878). The validator is SOURCED ONCE (inproc_load: its guard returns after defining pb_main) and every
# cell asks pb_main in a subshell made to look like a fresh `bash validate-provenance-block.sh` (lib/inproc.sh). Its
# root walk starts from the function's own `${BASH_SOURCE[0]}`, the file it was defined in -- the same path the
# program run gets -- so the two resolve one schema. The two cli cells (cells.decl) run it as a program once per
# distinct CLI outcome and compare stdout, stderr and exit byte for byte with the in-process call. A CORE FIXTURE
# SHIPS AHEAD OF ITS SUBJECT: a subject with neither its `pb_main() {` line nor the column-0 source guard predates the
# wrap and reads SKIP (exit 0, never an ok); exactly one half is a respelled subject and FAILs; a subject grep cannot
# READ (exit 2) is FIXTURE ERROR.
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
wrap_gate "$VALIDATOR" pb_main; g_pb=$?
if [ "$g_pb" = 2 ]; then exit 2; fi
if [ "$g_pb" = 1 ]; then echo "known-skills-extension: 1 FAILED"; exit 1; fi
if [ "$g_pb" = 3 ]; then echo "SKIP: subject predates the in-process wrap"; exit 0; fi

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
# shellcheck source=/dev/null
. "$HERE/../lib/inproc.sh" 2>/dev/null || { echo "FIXTURE BROKEN: core/fixtures/lib/inproc.sh absent beside $HERE" >&2; exit 2; }
inproc_load "$VALIDATOR" || { echo "FIXTURE BROKEN: sourcing $VALIDATOR defined nothing" >&2; exit 2; }
declare -F pb_main >/dev/null || { echo "FIXTURE BROKEN: $VALIDATOR defined no pb_main when sourced" >&2; exit 2; }

# run_with <ext-path> -> sets RC. Empty ext-path = no extension (explicitly).
run_with() { AI_DLC_KNOWN_SKILLS_EXT="$1" inproc_run "$VALIDATOR" pb_main "$ARTIFACT" >/dev/null 2>&1; RC=$?; }

echo "known-skills-extension:"

# --- Assertion 0: SANITY — the skill is genuinely NOT core-known --------------
run_with ""
if [ "$RC" -eq 1 ]; then
  ok "without any extension, the block citing 'bmad-agent-tea-tea' FAILS (it is not a core skill — the negatives below mean something)"
else
  bad "FIXTURE BROKEN — the block passed (rc=$RC) with no extension; 'bmad-agent-tea-tea' must not be core-known"
  echo; echo "known-skills-extension: FIXTURE BROKEN" >&2; exit 2
fi

# --- Assertion 1: the extension (object form) registers the skill → PASS ------
run_with "$EXT"
[ "$RC" -eq 0 ] && ok "with extensions/known-skills.json ({known_skills:[…]}), the block PASSES (exit 0)" \
  || bad "the object-form extension did NOT register the skill (rc=$RC)"

# --- Assertion 2: bare-array form also works → PASS ---------------------------
run_with "$EXT_ARRAY"
[ "$RC" -eq 0 ] && ok "the bare-array extension form (['…']) also PASSES" \
  || bad "the array-form extension did NOT register the skill (rc=$RC)"

# --- Assertion 3: a malformed extension FAILS CLOSED --------------------------
run_with "$MALFORMED"
[ "$RC" -eq 1 ] && ok "a present-but-malformed extension FAILS closed (never silently degrades to the core-only list)" \
  || bad "a malformed extension did NOT fail closed (rc=$RC)"

# --- Assertion 4: a nonexistent path is 'no extension', not an error ----------
run_with "$WORK/does-not-exist.json"
[ "$RC" -eq 1 ] && ok "a nonexistent extension path is treated as absent (block still FAILS on the unknown skill, no crash)" \
  || bad "a nonexistent extension path did not behave as absent (rc=$RC)"

# --- the cli cells (cells.decl): the validator run as a PROGRAM once per distinct CLI outcome -----
# Each is compared with the in-process answer under the same extension: stdout, stderr and exit separately, byte for
# byte, and each asserts its own exit, so two runs that both printed nothing cannot read as equivalent.
EQ="$WORK/eq"; mkdir -p "$EQ" || exit 2
eqv() { # eqv <cell-id> <ext-path> -> $EQ/<id>.{ip,cl}.{out,err,rc}; 0 when the two answers are identical
  AI_DLC_KNOWN_SKILLS_EXT="$2" inproc_run "$VALIDATOR" pb_main "$ARTIFACT" > "$EQ/$1.ip.out" 2> "$EQ/$1.ip.err"; echo "$?" > "$EQ/$1.ip.rc"
  AI_DLC_KNOWN_SKILLS_EXT="$2" FXCELL="$1" bash "$VALIDATOR" "$ARTIFACT" > "$EQ/$1.cl.out" 2> "$EQ/$1.cl.err"; echo "$?" > "$EQ/$1.cl.rc"
  cmp -s "$EQ/$1.ip.out" "$EQ/$1.cl.out" && cmp -s "$EQ/$1.ip.err" "$EQ/$1.cl.err" && cmp -s "$EQ/$1.ip.rc" "$EQ/$1.cl.rc"
}
if eqv cli-pass "$EXT" && [ "$(cat "$EQ/cli-pass.cl.rc")" = 0 ] && grep -q '^VALIDATE-PROVENANCE-BLOCK: PASS' "$EQ/cli-pass.cl.out"; then
  ok "cli-pass: the program accepts the extension-registered skill exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-pass: the program and the in-process call differ, or the outcome is not exit 0 with a PASS line (program rc=$(cat "$EQ/cli-pass.cl.rc"), in-process rc=$(cat "$EQ/cli-pass.ip.rc"))"; fi
if eqv cli-fail "" && [ "$(cat "$EQ/cli-fail.cl.rc")" = 1 ] && grep -q 'bmad-agent-tea-tea' "$EQ/cli-fail.cl.out" "$EQ/cli-fail.cl.err"; then
  ok "cli-fail: the program refuses the unregistered skill exactly as the in-process call does (stdout, stderr, exit 1)"
else bad "cli-fail: the program and the in-process call differ, or the outcome is not exit 1 naming the skill (program rc=$(cat "$EQ/cli-fail.cl.rc"), in-process rc=$(cat "$EQ/cli-fail.ip.rc"))"; fi
if ! cmp -s "$EQ/cli-pass.cl.out" "$EQ/cli-fail.cl.out" && ! cmp -s "$EQ/cli-pass.cl.rc" "$EQ/cli-fail.cl.rc"; then
  ok "cli cells discriminate: the registered and the unregistered run give different stdout and exit"
else bad "cli cells do not discriminate: cli-pass and cli-fail gave the same stdout or exit"; fi

echo
report_end known-skills-extension
