#!/usr/bin/env bash
# provenance-not-accessible — prove the tool_use_id NOT_ACCESSIBLE sentinel is accepted
# (retro.md mandates it when the Skill/Agent id is not retrievable), that it opens no hole
# (a fabricated id and a placeholder literal still FAIL).
#
# THE DEFECT THIS EXISTS TO CATCH. retro.md Step 2 tells authors to write
# `tool_use_id: NOT_ACCESSIBLE` rather than invent an id, yet the validator's toolu_ pattern
# rejected that exact literal — the doc mandated a value its own gate failed. A real retro
# after a compact could not pass without either forging an id or failing the gate.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

if   [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/validate-provenance-block.sh" ]; then
  VALIDATOR="$ROOT/core/scripts/validate-provenance-block.sh"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/validate-provenance-block.sh" ]; then
  VALIDATOR="$ROOT/scripts/ai-dlc/validate-provenance-block.sh"
else
  echo "FIXTURE ERROR: validate-provenance-block.sh not found in either layout" >&2
  exit 2
fi
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
if [ "$g_pb" = 1 ]; then echo "provenance-not-accessible: 1 FAILED"; exit 1; fi
if [ "$g_pb" = 3 ]; then echo "SKIP: subject predates the in-process wrap"; exit 0; fi

command -v python3 >/dev/null 2>&1 || { echo "FIXTURE ERROR: python3 not on PATH" >&2; exit 2; }
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$_v"; done

WORK="$(mktemp -d)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
trap 'rm -rf "$WORK"' EXIT

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
# shellcheck source=/dev/null
. "$HERE/../lib/inproc.sh" 2>/dev/null || { echo "FIXTURE BROKEN: core/fixtures/lib/inproc.sh absent beside $HERE" >&2; exit 2; }
inproc_load "$VALIDATOR" || { echo "FIXTURE BROKEN: sourcing $VALIDATOR defined nothing" >&2; exit 2; }
declare -F pb_main >/dev/null || { echo "FIXTURE BROKEN: $VALIDATOR defined no pb_main when sourced" >&2; exit 2; }

ART="$WORK/docs/eval.md"   # non-retro path: no retro-specific requirements
mkdir -p "$WORK/docs"

# write_block <tool_use_id>
write_block() {
  cat > "$ART" <<EOF
# Evaluation

<!-- SKILL_INVOCATION_PROVENANCE v1
skill: ai-dlc-adversary-review
invoked_at: 2026-01-01T00:00:00Z
tool_use_id: $1
mode: subagent
lead_role: gate-validation.md
findings_critical: 0
findings_major: 0
findings_minor: 1
SKILL_INVOCATION_PROVENANCE_END -->
EOF
}

echo "provenance-not-accessible"

# --- 1. NOT_ACCESSIBLE passes -------------------------------------------------
write_block "NOT_ACCESSIBLE"
inproc_run "$VALIDATOR" pb_main "$ART" >"$WORK/out.txt" 2>&1
rc=$?
if [ "$rc" = "0" ]; then
  ok "tool_use_id: NOT_ACCESSIBLE is accepted (sanctioned sentinel)"
else
  bad "NOT_ACCESSIBLE was rejected (exit $rc)"; sed 's/^/        /' "$WORK/out.txt"
fi

# --- 2. a fabricated id still fails the pattern -------------------------------
write_block "NOPE-not-a-real-id"
inproc_run "$VALIDATOR" pb_main "$ART" >"$WORK/out.txt" 2>&1
rc=$?
if [ "$rc" = "1" ] && grep -q 'tool_use_id' "$WORK/out.txt"; then
  ok "a fabricated id still FAILs the toolu_ pattern (sentinel opened no hole)"
else
  bad "a fabricated id did not fail (exit $rc)"; sed 's/^/        /' "$WORK/out.txt"
fi

# --- 3. a placeholder literal is still forbidden ------------------------------
write_block "toolu_PLACEHOLDER"
inproc_run "$VALIDATOR" pb_main "$ART" >"$WORK/out.txt" 2>&1
rc=$?
if [ "$rc" = "1" ] && grep -qi 'forbidden' "$WORK/out.txt"; then
  ok "a placeholder literal is still forbidden (not confused with the sentinel)"
else
  bad "a placeholder literal was not rejected (exit $rc)"; sed 's/^/        /' "$WORK/out.txt"
fi

# --- the cli cells (cells.decl): the validator run as a PROGRAM once per distinct CLI outcome -----
# Each is compared with the in-process answer on the same artifact: stdout, stderr and exit separately, byte for
# byte, and each asserts its own exit, so two runs that both printed nothing cannot read as equivalent.
EQ="$WORK/eq"; mkdir -p "$EQ" || exit 2
eqv() { # eqv <cell-id> <tool_use_id> -> $EQ/<id>.{ip,cl}.{out,err,rc}; 0 when the two answers are identical
  write_block "$2"
  inproc_run "$VALIDATOR" pb_main "$ART" > "$EQ/$1.ip.out" 2> "$EQ/$1.ip.err"; echo "$?" > "$EQ/$1.ip.rc"
  FXCELL="$1" bash "$VALIDATOR" "$ART" > "$EQ/$1.cl.out" 2> "$EQ/$1.cl.err"; echo "$?" > "$EQ/$1.cl.rc"
  cmp -s "$EQ/$1.ip.out" "$EQ/$1.cl.out" && cmp -s "$EQ/$1.ip.err" "$EQ/$1.cl.err" && cmp -s "$EQ/$1.ip.rc" "$EQ/$1.cl.rc"
}
if eqv cli-pass "NOT_ACCESSIBLE" && [ "$(cat "$EQ/cli-pass.cl.rc")" = 0 ] && grep -q '^VALIDATE-PROVENANCE-BLOCK: PASS' "$EQ/cli-pass.cl.out"; then
  ok "cli-pass: the program accepts the sentinel exactly as the in-process call does (stdout, stderr, exit 0)"
else bad "cli-pass: the program and the in-process call differ, or the outcome is not exit 0 with a PASS line (program rc=$(cat "$EQ/cli-pass.cl.rc"), in-process rc=$(cat "$EQ/cli-pass.ip.rc"))"; fi
if eqv cli-fail "NOPE-not-a-real-id" && [ "$(cat "$EQ/cli-fail.cl.rc")" = 1 ] && grep -q 'tool_use_id' "$EQ/cli-fail.cl.out" "$EQ/cli-fail.cl.err"; then
  ok "cli-fail: the program refuses a fabricated id exactly as the in-process call does (stdout, stderr, exit 1)"
else bad "cli-fail: the program and the in-process call differ, or the outcome is not exit 1 naming tool_use_id (program rc=$(cat "$EQ/cli-fail.cl.rc"), in-process rc=$(cat "$EQ/cli-fail.ip.rc"))"; fi
if ! cmp -s "$EQ/cli-pass.cl.out" "$EQ/cli-fail.cl.out" && ! cmp -s "$EQ/cli-pass.cl.rc" "$EQ/cli-fail.cl.rc"; then
  ok "cli cells discriminate: the accepted and the refused artifact give different stdout and exit"
else bad "cli cells do not discriminate: cli-pass and cli-fail gave the same stdout or exit"; fi

echo
report_end provenance-not-accessible
