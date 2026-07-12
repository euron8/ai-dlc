#!/usr/bin/env bash
# verdict.sh -- run a validator, print ONE decisive line, exit with ITS code.
#
# WHY THIS EXISTS. The validators print their working: section headers, per-check
# PASS lines, remediation prose. That is right for a human reading a gate failure
# and wrong for a lead that needs a verdict. So the lead wraps them:
#
#     bash scripts/validate-artifact-budget.sh --only pipeline-snapshot.md 2>&1 \
#       | grep -E 'warn|OVER|PASS' | head -2
#
# Measured on the reference consumer's S289 implementation phase: 71 such calls,
# ~26k resident tokens of tool-call parameter spent hand-rolling output filters.
# Every one of them a fresh grep, none of them the same, several of them wrong.
#
# THE TRAP THIS CLOSES. `cmd | grep ...` takes the exit status of GREP, not of
# `cmd`. S289 shipped a fix for exactly this ("the harness could print FAIL and
# exit 0") -- a validator that failed loudly and reported success, because its
# status died in a pipe. This script NEVER pipes the validator. It captures the
# status directly, and the status it exits with is the validator's own.
#
# USAGE
#   scripts/verdict.sh <validator> [args...]
#   scripts/verdict.sh --all                  # every validator that needs no args
#
# OUTPUT
#   PASS  <validator>
#   FAIL  <validator>
#         <the failing lines, verbatim, up to AI_DLC_VERDICT_LINES>
#
# EXIT
#   The validator's own exit code, unmodified. 64 for a usage error here.
#
# ENV
#   AI_DLC_VERDICT_LINES   failing lines to echo on FAIL   (default 6)
#   AI_DLC_SCRIPTS_DIR     where validators live           (default: this dir)

set -u

LINES="${AI_DLC_VERDICT_LINES:-6}"
SELF_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="${AI_DLC_SCRIPTS_DIR:-$SELF_DIR}"

if [ $# -lt 1 ]; then
  echo "FAIL: usage: $0 <validator> [args...]   (or --all)" >&2
  exit 64
fi

# ---------------------------------------------------------------------------
# run_one <validator> [args...] -> prints one verdict line (+ failing lines),
# returns the validator's status.
# ---------------------------------------------------------------------------
run_one() {
  v="$1"; shift

  # Accept a bare name, a name.sh, or a path.
  case "$v" in
    */*) target="$v" ;;
    *.sh|*.js) target="${SCRIPTS_DIR}/${v}" ;;
    *)   target="${SCRIPTS_DIR}/${v}.sh" ;;
  esac

  if [ ! -f "$target" ]; then
    echo "FAIL  ${v}"
    echo "      no such validator: $target"
    return 64
  fi

  name="$(basename "$target")"
  out="$(mktemp)" || return 70

  # THE WHOLE POINT: status is taken from the command itself. No pipe, no
  # process substitution, no `| tee`. Anything that puts the validator on the
  # left of a `|` hands its status to the right-hand side and loses it.
  case "$target" in
    *.js) node "$target" "$@" >"$out" 2>&1 ;;
    *)    bash "$target" "$@" >"$out" 2>&1 ;;
  esac
  rc=$?

  if [ "$rc" -eq 0 ]; then
    echo "PASS  ${name}"
  else
    echo "FAIL  ${name}  (rc=${rc})"
    # Surface the lines that carry the failure, not the whole transcript. If the
    # validator names no FAIL line, show the tail rather than nothing -- a
    # non-zero status with no explanation must never render as silence.
    hits="$(grep -nE '^[[:space:]]*(FAIL|ERROR|OVER|WARN|warn)' "$out" 2>/dev/null | head -n "$LINES")"
    if [ -n "$hits" ]; then
      printf '%s\n' "$hits" | sed 's/^/      /'
    else
      tail -n "$LINES" "$out" 2>/dev/null | sed 's/^/      /'
    fi
  fi

  rm -f "$out" 2>/dev/null || true
  return "$rc"
}

# ---------------------------------------------------------------------------
if [ "$1" = "--all" ]; then
  # Only the validators that are meaningful with no arguments. The rest need a
  # sprint number, a transcript, or a target file, and guessing one would be a
  # check that cannot fail -- worse than no check at all.
  WORST=0
  for v in validate-artifact-budget.sh validate-compact-window.sh \
           validate-reattach-budget.sh validate-layer-entries.sh; do
    [ -f "${SCRIPTS_DIR}/${v}" ] || continue
    run_one "$v" || WORST=$?
  done
  exit "$WORST"
fi

run_one "$@"
exit $?
