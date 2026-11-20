#!/usr/bin/env bash
# verdict-pass-content — assert verdict.sh's PASS line carries evidence of a run.
#
# Usage: run.sh
# Exit:  0 = every assertion holds, 1 = the check regressed, 2 = fixture broken.
#
# THE DEFECT THIS EXISTS TO CATCH.
#
# verdict.sh used to print exactly `PASS  <validator>` on success -- content-free,
# and therefore derivable from the command alone. gate-validation.md Check 14 asks
# the lead to "paste the validator's verdict line verbatim" into the gate log, and
# Check 15 rejects a cell that is `-` or "a restatement like 'budget OK'". Both
# were satisfiable by a string transcribed straight out of the instruction.
#
# Measured in the reference consumer at gate `story-20260722T014002Z`, the Check 14
# evidence cell read:
#
#     Budget validator: `PASS  validate-artifact-budget.sh` (exit 0).
#
# The snapshot it names measured 126% of budget at the commit before that gate and
# 212% at the commit after. The validator exits 1 at both, and at every commit
# between them. Every check that passed honestly at that same gate cited
# run-specific content -- `36 manifest ids / 36 anchors`, `digest=e1254177c37c8e23`,
# `1 block(s)`. Check 14's was the only requirement satisfiable without the run.
#
# The fix: surface the validator's own measurement line on PASS, the way failing
# lines are already surfaced on FAIL.

set -uo pipefail
# Clear every inherited AI_DLC_* tunable and CLAUDE_PROJECT_DIR so a bare run judges the code, not the caller environment.
for _v in $(env | sed -n 's/^\(AI_DLC_[A-Za-z0-9_]*\)=.*/\1/p'); do [ "$_v" = AI_DLC_PROJECT_ROOT ] || unset "$_v"; done
unset CLAUDE_PROJECT_DIR

HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." 2>/dev/null && pwd || true)"

# Two layouts, both derived from install.sh's mapping -- NOT guessed. install.sh
# maps `core/scripts/<x>` to `scripts/ai-dlc/<x>` at the project root (v0.126.0+).
if [ -n "$ROOT" ] && [ -f "$ROOT/core/scripts/verdict.sh" ]; then
  SCRIPTS="$ROOT/core/scripts"
elif [ -n "$ROOT" ] && [ -f "$ROOT/scripts/ai-dlc/verdict.sh" ]; then
  # The elif condition already checked scripts/ai-dlc/ — but SCRIPTS used to be set to
  # bare $ROOT/scripts, so VERDICT resolved to a non-existent path and this fixture
  # failed in every installed tree while passing in the distribution.
  SCRIPTS="$ROOT/scripts/ai-dlc"
else
  echo "FIXTURE ERROR: verdict.sh not found in either layout" >&2
  echo "  looked in: $ROOT/core/scripts/ (distribution), $ROOT/scripts/ai-dlc/ (consumer)" >&2
  exit 2
fi
VERDICT="$SCRIPTS/verdict.sh"
VALIDATOR="$SCRIPTS/validate-artifact-budget.sh"
[ -f "$VALIDATOR" ] || { echo "FIXTURE ERROR: validate-artifact-budget.sh missing" >&2; exit 2; }
echo "HERMETIC-CONSUMED core/scripts/verdict.sh"
echo "HERMETIC-CONSUMED core/scripts/validate-artifact-budget.sh"

WORK="$(mktemp -d 2>/dev/null)" || { echo "FIXTURE ERROR: mktemp failed" >&2; exit 2; }
WORK="$(cd "$WORK" && pwd)"
trap 'rm -rf "$WORK"' EXIT
mkdir -p "$WORK/_bmad-output" || exit 2

. "$HERE/../lib/report.sh" || { echo "FIXTURE BROKEN: cannot source lib/report.sh" >&2; exit 2; }
. "$HERE/../lib/layout.sh" || { echo "FIXTURE BROKEN: cannot source lib/layout.sh" >&2; exit 2; }

# IN PROCESS (BL-878). verdict.sh is loaded once and asked through vrd_drive (inproc_run -> vrd_main); the validator it
# starts (`bash "$target"`) runs as vab_main in a subshell through the `bash` shim below. A core fixture ships ahead of its
# subjects: a subject with neither the `<p>_main() {` line nor the column-0 source guard predates the wrap and SKIPs
# (FIXTURE BROKEN in the distribution); exactly one half FAILs; an unreadable subject is FIXTURE ERROR.
vp_halves() { # <file> <entry> -> "<def><guard>"
  local d=0 g=0 x
  grep -qxF "$2() {" "$1"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $1 (grep exit $x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$x" -ne 0 ] || d=1
  grep -qxF '[ "${BASH_SOURCE[0]}" = "$0" ] || return 0' "$1"; x=$?
  [ "$x" -le 1 ] || { echo "FIXTURE ERROR: cannot read $1 (grep exit $x) -- an unreadable subject is not one that predates the wrap" >&2; exit 2; }
  [ "$x" -ne 0 ] || g=1
  printf '%s%s' "$d" "$g"
}
vp_pre=""
for _s in "$VERDICT:vrd_main" "$VALIDATOR:vab_main"; do
  _h="$(vp_halves "${_s%%:*}" "${_s##*:}")" || exit 2
  case "$_h" in
    11) : ;;
    00) vp_pre="$vp_pre ${_s%%:*}" ;;
    *) bad "${_s%%:*} carries one half of the in-process wrap (${_s##*:} line, column-0 source guard: $_h) -- a respelled subject this fixture cannot drive"
       report_end verdict-pass-content ;;
  esac
done
if [ -n "$vp_pre" ]; then echo "SKIP: subject predates the in-process wrap:$vp_pre"; fx_skip_exit "$HERE"; fi

. "$HERE/../lib/inproc.sh" || { echo "FIXTURE ERROR: lib/inproc.sh not found" >&2; exit 2; }
export FX_VAB="$VALIDATOR" # exported: inproc_run keeps exported variables and drops the rest
bash() { # verdict.sh's own `bash "$target"` start of the budget validator runs vab_main in a fresh-options subshell; any other start is real
  if [ "${1:-}" = "$FX_VAB" ]; then
    shift
    ! declare -F fx_inproc >/dev/null 2>&1 || fx_inproc "$FX_VAB"; ( unset LINES SELF_DIR SCRIPTS_DIR WORST v target name out rc ok_hits hits _n; set +eufx +o pipefail; . "$FX_VAB" && vab_main "$@" )
  else command bash "$@"; fi
}
inproc_load "$VERDICT" || { echo "FIXTURE ERROR: $VERDICT defines no vrd_main (not loadable)" >&2; exit 2; }
# inproc_run strips every function the subject did not define; the shim is kept by naming it with the loaded set.
INPROC_FNS="${INPROC_FNS}bash "; INPROC_DEFS="$(declare -f $INPROC_FNS)"
vrd_drive() { inproc_run "$VERDICT" vrd_main "$@"; } # <verdict args> -> its answer, in process

# A snapshot small enough to pass the byte budget with room to spare. The PASS
# path is what this fixture measures, so every run below must actually pass.
{ printf '# Pipeline Snapshot\n\n'
  printf '## Pipeline Position\n- variant: carry-over\n\n'
  printf '## Sprint Context\n- sprint_id: 296\n\n'
  printf '## Recent Activity\n1. routed\n\n'
  printf '## Open Items\nnone\n\n'
  printf '## Locked Decisions\nnone\n\n'
  printf '## In-Flight Teammates\nnone\n\n'
  printf '## Context Reminders\n- context_reminders_sent: none\n\n'
} > "$WORK/_bmad-output/pipeline-snapshot.md"

EQ="$WORK/eq"; mkdir -p "$EQ"
# eqv <cell-id> <verdict args...>: the in-process answer (the arms read it) and the same input run as a PROGRAM
# (FXCELL=<id> bash verdict.sh, one start per distinct CLI outcome, see cells.decl); both land in $EQ/<id>.{ip,cl}.{out,err,rc}.
eqv() {
  local id="$1"; shift
  vrd_drive "$@" > "$EQ/$id.ip.out" 2> "$EQ/$id.ip.err"; echo "$?" > "$EQ/$id.ip.rc"
  FXCELL="$id" command bash "$VERDICT" "$@" > "$EQ/$id.cl.out" 2> "$EQ/$id.cl.err"; echo "$?" > "$EQ/$id.cl.rc"
}
same_cell() { cmp -s "$EQ/$1.ip.out" "$EQ/$1.cl.out" && cmp -s "$EQ/$1.ip.err" "$EQ/$1.cl.err" && cmp -s "$EQ/$1.ip.rc" "$EQ/$1.cl.rc"; }

echo "verdict-pass-content"

# --- 1. A passing run still exits 0 and still says PASS ------------------------
# The floor. Whatever else changes, callers read this line as the verdict.
eqv cli-pass "$VALIDATOR" --root "$WORK" --only pipeline-snapshot.md
status="$(cat "$EQ/cli-pass.ip.rc")"; cat "$EQ/cli-pass.ip.out" "$EQ/cli-pass.ip.err" > "$WORK/out.txt"
if [ "$status" = "0" ] && grep -q '^PASS  validate-artifact-budget.sh' "$WORK/out.txt"; then
  ok "a passing run exits 0 and prints the PASS verdict line"
else
  bad "exit $status / PASS line missing -- every caller reads this as the verdict"
fi

# --- 2. THE PASS OUTPUT CARRIES THE MEASUREMENT --------------------------------
# The assertion that matters. A token count cannot be transcribed out of the
# instruction; it exists only because the validator ran and measured a file.
if grep -qE '[0-9]+[[:space:]]+tok' "$WORK/out.txt"; then
  ok "  and it carries a token measurement (a number the instruction cannot supply)"
else
  bad "  PASS output carries no measurement -- the cell is forgeable again"
  sed 's/^/        /' "$WORK/out.txt"
fi

# --- 3. SILENCE IS STILL A PASS ------------------------------------------------
# A validator that prints nothing matchable -- or nothing at all -- still passed.
# Rendering that as an error, or as empty output, would break callers that have
# nothing to do with the budget. The measurement lines are additive, not required.
cat > "$WORK/silent.sh" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
vrd_drive "$WORK/silent.sh" >"$WORK/silent-out.txt" 2>&1
silent_status=$?
if [ "$silent_status" = "0" ] && grep -q '^PASS  silent.sh' "$WORK/silent-out.txt"; then
  ok "a validator that prints nothing still renders as PASS, exit 0"
else
  bad "a silent validator rendered as exit $silent_status -- a quiet PASS became an error"
  sed 's/^/        /' "$WORK/silent-out.txt"
fi

# --- 4. FAIL still surfaces the failing lines ----------------------------------
# The PASS branch sits directly above the FAIL branch. A regression that captured
# both would leave a failing gate with no reason attached, which is worse than the
# defect this change fixes.
head -c 40000 /dev/zero | tr '\0' 'x' >> "$WORK/_bmad-output/pipeline-snapshot.md"
eqv cli-fail "$VALIDATOR" --root "$WORK" --only pipeline-snapshot.md
fail_status="$(cat "$EQ/cli-fail.ip.rc")"; cat "$EQ/cli-fail.ip.out" "$EQ/cli-fail.ip.err" > "$WORK/out.txt"
if [ "$fail_status" = "1" ] && grep -q '^FAIL  validate-artifact-budget.sh' "$WORK/out.txt" \
   && grep -q 'OVER ' "$WORK/out.txt"; then
  ok "a failing run still exits 1 and still surfaces its failing lines"
else
  bad "exit $fail_status / FAIL detail missing -- the FAIL branch regressed"
fi

# --- 5. THE COMMAND-LINE RUN GIVES THE IN-PROCESS ANSWER ------------------------
# Each cli cell is compared on stdout, stderr and exit, and asserts its own outcome (a positive conjunct), so two runs
# that both printed nothing cannot read as equivalent; the pass and fail cells must differ.
if same_cell cli-pass && [ "$(cat "$EQ/cli-pass.cl.rc")" = 0 ] && grep -q '^PASS  validate-artifact-budget.sh' "$EQ/cli-pass.cl.out"; then
  ok "cli-pass: verdict.sh as a program matches the in-process answer (exit 0, PASS line)"
else bad "cli-pass: the program and the in-process call disagree"; fi
if same_cell cli-fail && [ "$(cat "$EQ/cli-fail.cl.rc")" = 1 ] && grep -q '^FAIL  validate-artifact-budget.sh' "$EQ/cli-fail.cl.out"; then
  ok "cli-fail: verdict.sh as a program matches the in-process answer (exit 1, FAIL line)"
else bad "cli-fail: the program and the in-process call disagree"; fi
if ! cmp -s "$EQ/cli-pass.cl.out" "$EQ/cli-fail.cl.out"; then ok "the pass and fail cells differ"; else bad "pass and fail cells are identical"; fi

echo ""
report_end verdict-pass-content
